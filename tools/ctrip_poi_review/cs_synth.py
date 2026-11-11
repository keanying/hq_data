"""智能客服对话数据：用大模型把包里的原始客服问答「改写」成多轮在线客服会话（目标 JSON 格式），每条都能追溯到原始对话。

    python cs_synth.py --data-dir <解压后的包>/data --limit 20                 # 先试 20 条
    python cs_synth.py --data-dir ... --city 北京 --intent 门票,预约购票 --variants 2
    python cs_synth.py --data-dir ... --limit 500 --workers 4 --mysql         # 同时写进 MySQL 两张表
    python cs_synth.py --load-jsonl out/cs_synth_20261110/dialogs.jsonl        # 把已生成的 JSONL 补写进 MySQL

输入（包里的两张表，CSV）：
    dwd.dwd_cus_service_dialogue_df.csv        一行一通对话（dialogue_id、景区、意图、场景、首问首答、全文、来源网址…）
    dwd.dwd_cus_service_dialogue_turn_df.csv   一行一轮发言（dialogue_id、turn_seq、role_type、turn_content）
    （另一版包里字段名叫 dialog_id / turn_no / speaker_role_type / turn_content_text，也能认）

输出（out/cs_synth_<日期>/，可断点续跑：已生成的「原始对话 + 第几个变体」会跳过）：
    source_extract.jsonl   用到的原始对话：原表整行 + 逐轮发言（抽出来的原始数据）
    dialogs.jsonl          生成的会话：字段和目标格式完全一致，只多一个 source（原始对话 ID、景区、意图、来源网址、
                           改写模型 / 版本、needs_review 和 check_flags 质检结果）
    mapping.csv            session_id ↔ source_dialogue_id ↔ 景区 ↔ 质检标记，方便对照
    rejected.jsonl         模型返回不合格（不是 JSON、没有轮次…）的，带原因
    --mysql 时写进 MySQL（表需先建好，表名可用环境变量 CS_SESSION_TABLE / CS_TURN_TABLE 改）：
      dwd_cus_cs_session_di       一行一个会话（turn_cnt = 轮次数，travel_date = start_time 的日期）
      dwd_cus_cs_session_turn_di  一行一轮消息（msg_ts = 会话日期 + ts，跨零点顺延；source = 溯源 JSON，每轮都带）
      同一个会话重跑会覆盖（会话行更新，轮次先删后写），不会重复

景区：原始数据的 attraction_id = ctrip_<携程景点ID>，经携程主档（景点ID → poiId）对到客户景区表里
      已审核（approval=1）且 ctrip_poi_info 含这个 poiId 的景区，得到 scenic_id / scenic_name。对不上的默认跳过（--allow-unmapped 保留）。

防止编造：提示词要求客服只能说原始回答里有的事实（价格、时间、政策、交通…），原文没有的就说以官方为准或转人工；
生成后再做一遍质检：客服说的金额 / 时间点如果原文里没有，会标 needs_review，mapping.csv 和 dialogs.jsonl 里都能看到。

AI 配置和工作台「设置 → AI 判断」共用（浏览器目录里的 hq_prefs.json；或环境变量 ARK_API_KEY）。非流式、关闭深度思考。
默认只用 data_type=真实、dataset_split_type=train 的原始对话（避免把验证 / 测试集改写进训练数据）。
"""
import argparse
import csv
import hashlib
import json
import random
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from pathlib import Path

import ai_judge

HERE = Path(__file__).resolve().parent
PROMPT_VERSION = "cs_rewrite_v2"
CHANNELS = ["小程序-在线客服", "APP-在线客服", "公众号-在线客服", "H5-在线客服", "PC官网-在线客服"]
PERSONAS = ["第一次来的外地游客，说话简短", "带小孩的家长，比较细心", "带老人出行的年轻人", "学生，预算有限", "着急的游客，会催促客服",
            "说话很口语化、喜欢用表情的年轻人", "常来的本地人", "公司团建的组织者"]
END_TYPES = ["用户主动结束", "客服结束", "超时自动结束", "转人工后结束"]
MONEY_RE = re.compile(r"(?:¥|￥)\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*元")
TIME_RE = re.compile(r"\d{1,2}[:：]\d{2}")


# ---------------------------------------------------------------- 读原始数据
def _pick(row, *names):
    for n in names:
        if n in row and row[n] is not None:
            return row[n]
    return ""


def load_source(data_dir, log=print):
    d = Path(data_dir)
    def find(*names):
        for n in names:
            for p in [d / n, *d.rglob(n)]:
                if p.exists():
                    return p
        raise FileNotFoundError(f"在 {d} 下没找到 {names[0]}（数据目录要指向解压后包含这两张 CSV 的目录）")
    dlg_file = find("dwd.dwd_cus_service_dialogue_df.csv", "dwd.dwd_cus_service_dialog_df.csv")
    turn_file = find("dwd.dwd_cus_service_dialogue_turn_df.csv", "dwd.dwd_cus_service_dialog_turn_df.csv")
    dialogs = list(csv.DictReader(dlg_file.open(encoding="utf-8-sig")))
    turns = {}
    for t in csv.DictReader(turn_file.open(encoding="utf-8-sig")):
        did = _pick(t, "dialogue_id", "dialog_id")
        turns.setdefault(did, []).append(dict(seq=int(_pick(t, "turn_seq", "turn_no") or 0), role=_pick(t, "role_type", "speaker_role_type"),
                                              text=_pick(t, "turn_content", "turn_content_text"), tool=_pick(t, "tool_name") or None))
    for v in turns.values():
        v.sort(key=lambda x: x["seq"])
    out = []
    for r in dialogs:
        did = _pick(r, "dialogue_id", "dialog_id")
        out.append(dict(id=did, row=r, turns=turns.get(did, []), data_type=r.get("data_type"), split=r.get("dataset_split_type"),
                        city=r.get("city_name"), attraction_id=r.get("attraction_id"), attraction_name=r.get("attraction_name"),
                        intent=r.get("intent_type"), scene=r.get("scene_type"), action=r.get("business_action_type"),
                        full=_pick(r, "dialogue_content", "dialog_full_text"), url=r.get("source_url")))
    log(f"原始对话 {len(out)} 通（{dlg_file.name}），逐轮发言 {sum(len(v) for v in turns.values())} 条（{turn_file.name}）")
    return out


MASTER_CSV = ("dim.dim_prd_attraction_df.csv",)  # 数据包里的携程景点主档：含 ctrip_poi_id、ctrip_business_id


def biz_to_poi(data_dir=None, log=print):
    """携程景点ID（businessId）→ {poiId}：优先用数据目录里的 dim.dim_prd_attraction_df.csv，MySQL 里有携程主档表也一起用。"""
    import db
    biz2poi, srcs = {}, []
    if data_dir:
        d = Path(data_dir)
        f = next((p for n in MASTER_CSV for p in [d / n, *d.rglob(n)] if p.exists()), None)
        if f:
            n0 = 0
            for r in csv.DictReader(f.open(encoding="utf-8-sig")):
                b, p = str(r.get("ctrip_business_id") or "").strip(), str(r.get("ctrip_poi_id") or "").strip()
                if b and p:
                    biz2poi.setdefault(b, set()).add(p)
                    n0 += 1
            srcs.append(f"{f.name}（{n0} 条）")
    with db.cursor() as cur:
        if db.table_exists(cur, db.MASTER_TABLE):
            cur.execute(f"SELECT ctrip_poi_id, ctrip_business_id FROM {db.MASTER_TABLE} WHERE ctrip_business_id IS NOT NULL")
            rows = cur.fetchall()
            for r in rows:
                biz2poi.setdefault(str(r["ctrip_business_id"]), set()).add(str(r["ctrip_poi_id"]))
            srcs.append(f"MySQL {db.MASTER_TABLE}（{len(rows)} 条）")
    if not srcs:
        raise RuntimeError("找不到携程景点主档（景点ID → poiId 的对应关系）：数据目录里没有 dim.dim_prd_attraction_df.csv，"
                           f"MySQL 里也没有 {db.MASTER_TABLE}。把数据包里的 dim.dim_prd_attraction_df.csv 放进数据目录即可")
    log("携程景点ID → poiId 对应关系来自：" + "、".join(srcs))
    return biz2poi


def scenic_map(log=print, data_dir=None):
    """携程景点ID（businessId）→ [{scenic_id, scenic_name, city}]：经携程主档对到已审核的客户景区。"""
    import db
    out = {}
    biz2poi = biz_to_poi(data_dir, log)
    with db.cursor() as cur:
        cur.execute(f"""SELECT s.{db.C['id']} id, s.{db.C['name']} name, s.{db.C['city']} city, s.{db.POI_INFO} info FROM {db.SCENIC_TABLE} s
                        WHERE COALESCE(s.{db.APPROVAL}, 0) = 1 AND s.{db.POI_INFO} IS NOT NULL AND s.{db.POI_INFO} <> '[]'""")
        poi2scenic = {}
        for r in cur.fetchall():
            for p in db._parse_info(r["info"]):
                poi2scenic.setdefault(str(p.get("poiId")), []).append(dict(scenic_id=r["id"], scenic_name=r["name"], city=r["city"]))
    for biz, pois in biz2poi.items():
        hits = [s for p in pois for s in poi2scenic.get(p, [])]
        if hits:
            out[biz] = list({h["scenic_id"]: h for h in hits}.values())
    for p, hits in poi2scenic.items():  # 有的 attraction_id 本身就是 poiId
        out.setdefault(p, hits)
    log(f"可对到客户景区的携程景点：{len(out)} 个")
    return out


# ---------------------------------------------------------------- 提示词 / 生成
def build_prompt(src, scenic_name, persona, channel):
    spot = src["attraction_name"] or ""
    same = not spot or spot in scenic_name or scenic_name in spot
    lines = [f"{'游客' if t['role'] == '游客' else '客服' if t['role'] == '客服' else t['role']}：{t['text']}" for t in src["turns"]] \
        or [x for x in (src["full"] or "").splitlines() if x.strip()]
    return f"""你在做「景区在线客服对话」训练数据。把下面这段真实的游客问答，改写成一通自然的在线客服会话。

景区：{scenic_name}（{src['city'] or ''}）{'' if same else f"；原始问答问的是景区里的「{spot}」"}
渠道：{channel}
用户意图：{src['intent'] or '未知'}；服务场景：{src['scene'] or '未知'}
这次的游客人设：{persona}

原始问答（回答多来自其他游客或平台，口吻不是客服）：
{chr(10).join(lines)}

改写要求：
1. 客服只能使用原始回答里出现过的事实（价格、开放时间、预约 / 退改政策、交通线路、设施等）；原文没有的信息不要编，客服可以说「以景区官方公告为准」或「帮您转人工确认」。不要出现与这个景区不符的设施。
2. 游客的提问要口语化、贴合人设，可以拆成多条消息、追问、催促（如「在吗」「快点回」）、发表情；不要照抄原问题。
3. 客服用官方客服口吻（「您好」「亲」等），把原始回答改写成客服回复，可以分几条说；第一条可以是机器人（robot）自动接待，之后由人工（human）回复，也可以全程机器人。
4. 如果原文里有明确的票种 / 价格，可以用一条 msg_type 为 card 的卡片消息表达，例如「[门票卡片] 成人票 ¥60」，内容必须是原文里的。
5. 4～10 条消息；景区名写「{scenic_name}」{'' if same else f"，问的具体地方仍是「{spot}」（可以说「{scenic_name}的{spot}」），不要把{spot}的信息说成整个景区的"}；不要提「携程」「网友」「我们家去过」。
6. gap_sec 是这条消息距离上一条的秒数（游客 3～60 秒，客服 5～90 秒，第一条为 0）。

只输出一个 JSON 对象，不要其他文字：
{{"turns":[{{"role":"user或agent","agent_type":"robot或human（仅 agent 填）","msg_type":"text或card","text":"内容","gap_sec":整数}}],
 "end_type":"{'/'.join(END_TYPES)} 之一","satisfaction_score":null或1到5的整数,"is_resolved":true或false}}"""


def _seeded(*parts):
    return random.Random(int(hashlib.sha1("|".join(map(str, parts)).encode()).hexdigest()[:12], 16))


def assemble(src, scenic, variant, js, cfg, rnd):
    """模型给的轮次 + 程序生成的会话外壳（ID、时间、订单号等）→ 目标格式。"""
    raw_turns = [t for t in js.get("turns") or [] if isinstance(t, dict) and str(t.get("text") or "").strip()]
    if len(raw_turns) < 2 or not any(t.get("role") == "user" for t in raw_turns) or not any(t.get("role") == "agent" for t in raw_turns):
        raise ValueError("轮次太少，或缺少游客 / 客服发言")
    day = datetime(2026, 1, 1) + timedelta(days=rnd.randint(0, 364))
    start = day.replace(hour=rnd.randint(8, 21), minute=rnd.randint(0, 59), second=rnd.randint(0, 59))
    human_id = f"A{rnd.randint(1000, 1999)}"
    t, turns = start, []
    for i, x in enumerate(raw_turns, 1):
        gap = int(x.get("gap_sec") or 0) if i > 1 else 0
        t = t + timedelta(seconds=max(0, min(gap, 600)))
        role = "user" if x.get("role") == "user" else "agent"
        turn = dict(turn=i, role=role, msg_type="card" if x.get("msg_type") == "card" else "text", text=str(x["text"]).strip(), ts=t.strftime("%H:%M:%S"))
        if role == "agent":
            turn["agent_id"] = "ROBOT" if x.get("agent_type") == "robot" else human_id
        turns.append(turn)
    need_order = (src["scene"] in ("预订购票", "订单售后")) or (src["action"] not in (None, "", "none"))
    order = f"DD{(day - timedelta(days=rnd.randint(1, 10))).strftime('%Y%m%d')}{rnd.randint(0, 999999):06d}" if need_order else None
    score = js.get("satisfaction_score")
    score = int(score) if isinstance(score, (int, float)) and 1 <= int(score) <= 5 else None
    end_type = js.get("end_type") if js.get("end_type") in END_TYPES else "用户主动结束"
    key = "%s|%s" % (src["id"], variant)
    sid = "cs_%s_%06d" % (start.strftime("%Y%m%d"), int(hashlib.sha1(key.encode()).hexdigest()[:8], 16) % 1000000)
    rec = dict(session_id=sid, channel=None, visitor_id=f"V{rnd.randint(10000000, 99999999)}",
               scenic_id=scenic["scenic_id"] if scenic else None, scenic_name=scenic["scenic_name"] if scenic else src["attraction_name"],
               start_time=start.strftime("%Y-%m-%d %H:%M:%S"), related_order_id=order, turns=turns, end_type=end_type,
               satisfaction_score=score, session_duration_sec=int((t - start).total_seconds()))
    flags = quality_flags(src, rec)
    # 输出 = 目标格式的字段 + 一个 source：指回原始对话，以及改写方式 / 质检结果
    rec["source"] = dict(dialogue_id=src["id"], data_type=src["data_type"], dataset_split_type=src["split"], attraction_id=src["attraction_id"],
                         attraction_name=src["attraction_name"], city=src["city"], intent_type=src["intent"], scene_type=src["scene"],
                         source_url=src["url"], variant=variant, generate_method="llm_rewrite", model=cfg.get("ai_model"),
                         prompt_version=PROMPT_VERSION, generated_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                         is_resolved=bool(js.get("is_resolved")), needs_review=bool(flags), check_flags=flags)
    return rec


def quality_flags(src, rec):
    """客服说的金额 / 时间点，原文里没有 → 可能是编的。"""
    source_text = " ".join([src["full"] or ""] + [t["text"] for t in src["turns"]])
    norm = lambda s: re.sub(r"\s|¥|￥|元", "", s)  # noqa: E731
    src_nums = {norm(m) for m in MONEY_RE.findall(source_text)} | set(re.findall(r"\d+(?:\.\d+)?", source_text))
    flags = []
    for t in rec["turns"]:
        if t["role"] != "agent":
            continue
        for m in MONEY_RE.findall(t["text"]):
            if norm(m) not in src_nums:
                flags.append(f"金额「{m.strip()}」原文没有")
        for m in TIME_RE.findall(t["text"]):
            if m.replace("：", ":") not in source_text.replace("：", ":"):
                flags.append(f"时间「{m}」原文没有")
    return sorted(set(flags))


# ---------------------------------------------------------------- 写 MySQL
def _env(name, default):
    import os
    return os.environ.get(name) or default


SESSION_TABLE = _env("CS_SESSION_TABLE", "dwd_cus_cs_session_di")
TURN_TABLE = _env("CS_TURN_TABLE", "dwd_cus_cs_session_turn_di")


def mysql_check():
    import db
    with db.cursor() as cur:
        for t in (SESSION_TABLE, TURN_TABLE):
            if not db.table_exists(cur, db.ident(t)):
                raise RuntimeError(f"MySQL 里没有表 {t}，请先建表（DDL 见 README 第 10 节）")


def msg_times(rec):
    """每轮的完整时间：会话开始日期 + ts，时间比上一条小就说明跨了零点，日期顺延。"""
    start = datetime.strptime(rec["start_time"], "%Y-%m-%d %H:%M:%S")
    day, prev, out = start.date(), None, []
    for t in rec["turns"]:
        hh = datetime.strptime(t["ts"], "%H:%M:%S").time()
        if prev is not None and hh < prev:
            day = day + timedelta(days=1)
        prev = hh
        out.append(datetime.combine(day, hh))
    return out


def mysql_write(cur, rec):
    """写一个会话：主表 upsert；轮次表先删这个会话的旧轮次再写（重跑不重复）。"""
    import db
    st, tt = db.ident(SESSION_TABLE), db.ident(TURN_TABLE)
    td = int(rec["start_time"][:10].replace("-", ""))
    cur.execute(f"""INSERT INTO {st} (session_id, channel, visitor_id, scenic_id, scenic_name, start_time, related_order_id, end_type,
                    satisfaction_score, session_duration_sec, turn_cnt, travel_date) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON DUPLICATE KEY UPDATE channel=VALUES(channel), visitor_id=VALUES(visitor_id), scenic_id=VALUES(scenic_id),
                    scenic_name=VALUES(scenic_name), start_time=VALUES(start_time), related_order_id=VALUES(related_order_id),
                    end_type=VALUES(end_type), satisfaction_score=VALUES(satisfaction_score), session_duration_sec=VALUES(session_duration_sec),
                    turn_cnt=VALUES(turn_cnt)""",
                (rec["session_id"], rec["channel"], rec["visitor_id"], rec["scenic_id"], rec["scenic_name"], rec["start_time"],
                 rec["related_order_id"], rec["end_type"], rec["satisfaction_score"], rec["session_duration_sec"], len(rec["turns"]), td))
    cur.execute(f"DELETE FROM {tt} WHERE session_id=%s AND travel_date=%s", (rec["session_id"], td))
    src = json.dumps(rec.get("source") or {}, ensure_ascii=False)
    cur.executemany(f"""INSERT INTO {tt} (session_id, source, turn_no, role, msg_type, msg_text, agent_id, msg_ts, travel_date)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    [(rec["session_id"], src, t["turn"], t["role"], t.get("msg_type"), t.get("text"), t.get("agent_id"),
                      ts.strftime("%Y-%m-%d %H:%M:%S"), td) for t, ts in zip(rec["turns"], msg_times(rec))])


def load_jsonl(path, log=print, should_stop=lambda: False, progress=lambda done, total: None):
    """把已生成的 dialogs.jsonl 补写进 MySQL（重复写会覆盖，不会重复）。"""
    import db
    mysql_check()
    lines = [x for x in Path(path).read_text(encoding="utf-8").splitlines() if x.strip()]
    n = 0
    for i, line in enumerate(lines, 1):
        if should_stop():
            log("已停止")
            break
        with db.cursor() as cur:
            mysql_write(cur, json.loads(line))
        n += 1
        if i % 50 == 0 or i == len(lines):
            progress(i, len(lines))
    log(f"已写入 {n} 个会话到 {SESSION_TABLE} / {TURN_TABLE}")
    return dict(written=n, total=len(lines))


OUT_ROOT = HERE / "out"
BATCH_FILES = ["dialogs.jsonl", "mapping.csv", "source_extract.jsonl", "rejected.jsonl"]


def batches():
    """out/ 下已有的生成批次（目录），带各文件条数，给页面导出用。"""
    res = []
    for d in sorted(OUT_ROOT.glob("cs_synth_*"), reverse=True):
        if not d.is_dir():
            continue
        info = dict(name=d.name, files={})
        for f in BATCH_FILES:
            p = d / f
            if p.exists():
                n = sum(1 for x in p.open(encoding="utf-8-sig") if x.strip())
                info["files"][f] = n - 1 if f.endswith(".csv") else n
        review = 0
        if (d / "dialogs.jsonl").exists():
            for line in (d / "dialogs.jsonl").open(encoding="utf-8"):
                try:
                    review += bool(json.loads(line)["source"].get("needs_review"))
                except (ValueError, KeyError):
                    pass
        info["review"] = review
        info["mtime"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(d.stat().st_mtime))
        res.append(info)
    return res


def batch_dir(name):
    d = (OUT_ROOT / name).resolve()
    if d.parent != OUT_ROOT.resolve() or not d.name.startswith("cs_synth_") or not d.is_dir():
        raise FileNotFoundError(f"没有这个批次：{name}")
    return d


# ---------------------------------------------------------------- 主流程
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", default="", help="解压后的数据目录（含 dwd.dwd_cus_service_dialogue_df.csv 等）")
    ap.add_argument("--load-jsonl", default="", help="不生成，只把已有的 dialogs.jsonl 写进 MySQL 两张表")
    ap.add_argument("--out", default="", help="输出目录，默认 out/cs_synth_<今天>")
    ap.add_argument("--data-type", default="真实", help="用哪类原始对话，逗号分隔：真实 / 合成 / 改写；默认 真实")
    ap.add_argument("--split", default="train", help="数据集划分，默认 train（不要把 dev / test 改写进训练数据）；all = 不限")
    ap.add_argument("--city", default="", help="城市，逗号分隔，如 北京,上海")
    ap.add_argument("--intent", default="", help="意图，逗号分隔，如 门票,预约购票,退改规则")
    ap.add_argument("--scenic", default="", help="只要这些我们的景区（景区ID 或名称，逗号分隔）")
    ap.add_argument("--scenic-city", default="", help="只要这些城市的我们的景区（客户表城市名，如 北京市）")
    ap.add_argument("--limit", type=int, default=20, help="最多用几通原始对话（0=不限），默认 20")
    ap.add_argument("--variants", type=int, default=1, help="每通原始对话改写几个版本，默认 1")
    ap.add_argument("--workers", type=int, default=3, help="并发请求数，默认 3")
    ap.add_argument("--allow-unmapped", action="store_true", help="对不到客户景区的也生成（scenic_id 为空，景区名用原始的）")
    ap.add_argument("--no-db", action="store_true", help="不连 MySQL（不对景区，等同 --allow-unmapped）")
    ap.add_argument("--mysql", action="store_true", help=f"生成结果同时写进 MySQL：{SESSION_TABLE}（会话）、{TURN_TABLE}（轮次）")
    ap.add_argument("--profile", default=str(HERE / ".pw-profile-service"), help="读 AI 设置的浏览器目录（和工作台共用），默认服务的")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    if args.load_jsonl:
        load_jsonl(args.load_jsonl, log=lambda m: print(m, flush=True))
        return 0
    if not args.data_dir:
        ap.error("需要 --data-dir（或用 --load-jsonl 只补写 MySQL）")

    import review  # 只为读设置文件
    cfg = ai_judge.config(review.Prefs(Path(args.profile) / "hq_prefs.json"))
    if not cfg.get("ai_api_key"):
        raise SystemExit("没有 AI 的 API Key：在工作台「设置 → AI 判断」里填，或设置环境变量 ARK_API_KEY")
    print(f"模型 {cfg['ai_model']}（{cfg['ai_base_url']}，非流式，深度思考{'开' if cfg.get('ai_thinking') else '关'}）", flush=True)

    stats = run(args, cfg, log=lambda m: print(m, flush=True))
    return 0 if stats["ok"] or not stats["total"] else 1


def select(args, log=print):
    """按条件挑原始对话，并对到我们的景区。返回 (筛选后的原始对话, [(原始对话, 主景区, 全部景区)])。
    scenic：只要这些我们的景区（景区ID 或名称，逗号分隔）；scenic_city：我们景区所在城市（如 北京市）。"""
    src_all = load_source(args.data_dir, log)
    want = lambda v, x: not v or (x or "") in v.split(",")  # noqa: E731
    src = [s for s in src_all if want(args.data_type, s["data_type"]) and (args.split == "all" or want(args.split, s["split"]))
           and want(args.city, s["city"]) and want(args.intent, s["intent"]) and (s["turns"] or s["full"])]
    smap = {} if args.no_db else scenic_map(log, args.data_dir)
    only = {x.strip() for x in (getattr(args, "scenic", "") or "").split(",") if x.strip()}
    scity = {x.strip() for x in (getattr(args, "scenic_city", "") or "").split(",") if x.strip()}
    picked = []
    for s in src:
        hits = smap.get((s["attraction_id"] or "").replace("ctrip_", "")) or []
        if only or scity:
            hits = [h for h in hits if (not only or h["scenic_id"] in only or h["scenic_name"] in only) and (not scity or h["city"] in scity)]
            if not hits:
                continue
        if not hits and not (args.allow_unmapped or args.no_db):
            continue
        picked.append((s, hits[0] if hits else None, hits))
    return src, picked


def preview(args, log=print):
    """不调用模型，只看能用多少：按我们的景区统计可改写的原始对话数和意图分布。"""
    src, picked = select(args, log)
    per, intents = {}, {}
    for s, sc, _ in picked:
        k = sc["scenic_id"] if sc else ""
        e = per.setdefault(k, dict(scenic_id=sc["scenic_id"] if sc else None, scenic_name=sc["scenic_name"] if sc else "（未对到景区）",
                                   city=sc["city"] if sc else s["city"], n=0, spots=set()))
        e["n"] += 1
        e["spots"].add(s["attraction_name"])
        intents[s["intent"] or "其他"] = intents.get(s["intent"] or "其他", 0) + 1
    rows = sorted(per.values(), key=lambda x: -x["n"])
    for r in rows:
        r["spots"] = sorted(r["spots"])[:8]
    return dict(source_total=len(src), usable=len(picked), scenics=len([r for r in rows if r["scenic_id"]]), by_scenic=rows[:300],
                by_intent=sorted(intents.items(), key=lambda x: -x[1]))


def run(args, cfg, log=print, should_stop=lambda: False, progress=lambda done, total: None, on_item=lambda item: None):
    """生成主流程（命令行和工作台「客服数据」页共用）。args 需要：data_dir data_type split city intent scenic scenic_city limit variants
    workers allow_unmapped no_db mysql out seed。on_item 每处理完一条回调一次（含原始对话、发给模型的提示词、模型原始返回、生成结果）。"""
    src, picked = select(args, log)
    total_mapped = len(picked)
    random.Random(args.seed).shuffle(picked)
    if args.limit:
        picked = picked[: args.limit]
    log(f"筛选后 {len(src)} 通，其中能对到我们景区 {total_mapped} 通（本次取 {len(picked)} 通 × {args.variants} 个版本）")

    out = Path(args.out) if args.out else HERE / "out" / f"cs_synth_{time.strftime('%Y%m%d')}"
    out.mkdir(parents=True, exist_ok=True)
    f_dlg, f_src, f_rej, f_map = out / "dialogs.jsonl", out / "source_extract.jsonl", out / "rejected.jsonl", out / "mapping.csv"
    done = set()
    if f_dlg.exists():
        for line in f_dlg.read_text(encoding="utf-8").splitlines():
            try:
                r = json.loads(line)
                done.add((r["source"]["dialogue_id"], r["source"]["variant"]))
            except (ValueError, KeyError):
                pass
    have_src = set()
    if f_src.exists():
        for line in f_src.read_text(encoding="utf-8").splitlines():
            try:
                have_src.add(json.loads(line)["dialogue_id"])
            except (ValueError, KeyError):
                pass
    new_map = not f_map.exists()
    lock = threading.Lock()
    fm = f_map.open("a", encoding="utf-8-sig" if new_map else "utf-8", newline="")
    mw = csv.writer(fm)
    if new_map:
        mw.writerow(["session_id", "source_dialogue_id", "variant", "scenic_id", "scenic_name", "source_attraction_id", "source_attraction_name",
                     "intent_type", "scene_type", "turns", "needs_review", "check_flags", "model", "generated_at"])
    sql = None
    if args.mysql:
        import db
        mysql_check()
        sql = db

    jobs = [(s, sc, hits, v) for s, sc, hits in picked for v in range(1, args.variants + 1) if (s["id"], v) not in done]
    log(f"待生成 {len(jobs)} 条（已生成的 {len(done)} 条跳过），输出到 {out}")
    stats = dict(ok=0, review=0, rejected=0, failed=0, cancelled=0, total=len(jobs), out=str(out))
    progress(0, len(jobs))

    def one(s, sc, hits, v):
        if should_stop():
            return ("cancelled", s, v, dict(error="已停止"), None)
        rnd = _seeded(args.seed, s["id"], v)
        channel, persona = rnd.choice(CHANNELS), rnd.choice(PERSONAS)
        name = sc["scenic_name"] if sc else s["attraction_name"]
        prompt = build_prompt(s, name, persona, channel)
        ex_ = dict(prompt=prompt, persona=persona, channel=channel, started=time.strftime("%H:%M:%S"))
        t0 = time.time()
        try:
            text, elapsed, meta = ai_judge.call(cfg, prompt)
        except ai_judge.AIError as e:
            return ("failed", s, v, dict(error=str(e), http_status=e.http_status, request_id=e.request_id), dict(ex_, elapsed=round(time.time() - t0, 1)))
        ex_.update(response=text, elapsed=elapsed, request_id=meta.get("request_id"))
        try:
            js = ai_judge.parse(text)
            rec = assemble(s, sc, v, js, cfg, rnd)
            rec["channel"] = channel
            rec = {k: rec[k] for k in ["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns",
                                       "end_type", "satisfaction_score", "session_duration_sec", "source"]}
            rec["source"].update(persona=persona, elapsed=round(time.time() - t0, 1), request_id=meta.get("request_id"))
            if len(hits) > 1:
                rec["source"]["other_scenic_ids"] = [h["scenic_id"] for h in hits[1:]]
            return ("ok", s, v, rec, ex_)
        except Exception as e:  # noqa: BLE001
            return ("rejected", s, v, dict(error=f"{type(e).__name__}: {e}", raw=text[:2000]), ex_)

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = [ex.submit(one, *j) for j in jobs]
        for n, fut in enumerate(as_completed(futs), 1):
            kind, s, v, rec, ex_ = fut.result()
            with lock:
                if kind == "cancelled":
                    stats["cancelled"] += 1
                    progress(n, len(jobs))
                    continue
                if s["id"] not in have_src:  # 原始数据：原表整行 + 逐轮发言，每通只写一次
                    with f_src.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(dialogue_id=s["id"], row=s["row"], turns=s["turns"]), ensure_ascii=False) + "\n")
                    have_src.add(s["id"])
                if kind == "ok":
                    with f_dlg.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    g = rec["source"]
                    mw.writerow([rec["session_id"], s["id"], v, rec["scenic_id"] or "", rec["scenic_name"], s["attraction_id"], s["attraction_name"],
                                 s["intent"], s["scene"], len(rec["turns"]), int(g["needs_review"]), "；".join(g["check_flags"]), g["model"], g["generated_at"]])
                    fm.flush()
                    if sql:
                        try:
                            with sql.cursor() as cur:
                                mysql_write(cur, rec)
                        except Exception as e:  # noqa: BLE001  写库失败不丢数据：JSONL 里有，可用 --load-jsonl 补写
                            log(f"  写 MySQL 失败 {rec['session_id']}：{type(e).__name__}: {e}（JSONL 已保存，可稍后 --load-jsonl 补写）")
                    stats["ok"] += 1
                    stats["review"] += int(g["needs_review"])
                else:
                    with f_rej.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(source_dialogue_id=s["id"], variant=v, kind=kind, **rec), ensure_ascii=False) + "\n")
                    stats[kind] += 1
                    log(f"  [{n}/{len(jobs)}] {s['id']} 第 {v} 版 {'调用失败' if kind == 'failed' else '不合格'}：{rec.get('error')}")
                src_view = dict(dialogue_id=s["id"], data_type=s["data_type"], split=s["split"], city=s["city"], attraction_id=s["attraction_id"],
                                attraction_name=s["attraction_name"], intent=s["intent"], scene=s["scene"], url=s["url"], turns=s["turns"], full=s["full"])
                on_item(dict(kind=kind, variant=v, source=src_view, exchange=ex_, record=rec if kind == "ok" else None,
                             error=None if kind == "ok" else rec.get("error"), mysql=bool(sql)))
                progress(n, len(jobs))
                if n % 10 == 0 or n == len(jobs):
                    log(f"  进度 {n}/{len(jobs)}：成功 {stats['ok']}（需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}")
    fm.close()
    log(f"完成：成功 {stats['ok']}（其中需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}"
        + (f"，停止前未处理 {stats['cancelled']}" if stats["cancelled"] else "") + "。\n"
          f"  生成：{f_dlg}\n  原始：{f_src}\n  对照：{f_map}" + (f"\n  不合格 / 失败：{f_rej}" if stats["rejected"] or stats["failed"] else ""))
    return stats


if __name__ == "__main__":
    sys.exit(main())
