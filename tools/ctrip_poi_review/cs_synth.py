"""智能客服对话数据：用大模型把包里的原始客服问答「改写」成多轮在线客服会话（目标 JSON 格式），每条都能追溯到原始对话。

    python cs_synth.py --data-dir <解压后的包>/data --limit 20                 # 先试 20 条
    python cs_synth.py --data-dir ... --city 北京 --intent 门票,预约购票 --variants 2
    python cs_synth.py --data-dir ... --limit 500 --workers 4 --mysql         # 同时写进 MySQL

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
    --mysql 时另写表 cs_dialog_synth（session_id 主键，含 source_dialogue_id 和完整 JSON）

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


def load_source(data_dir):
    d = Path(data_dir)
    def find(*names):
        for n in names:
            for p in [d / n, *d.rglob(n)]:
                if p.exists():
                    return p
        raise SystemExit(f"在 {d} 下没找到 {names[0]}（请用 --data-dir 指向解压后包含这两张 CSV 的目录）")
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
    print(f"原始对话 {len(out)} 通（{dlg_file.name}），逐轮发言 {sum(len(v) for v in turns.values())} 条（{turn_file.name}）", flush=True)
    return out


def scenic_map():
    """携程景点ID（businessId）→ [{scenic_id, scenic_name, city}]：经携程主档对到已审核的客户景区。"""
    import db
    out = {}
    with db.cursor() as cur:
        cur.execute(f"SELECT ctrip_poi_id, ctrip_business_id FROM {db.MASTER_TABLE} WHERE ctrip_business_id IS NOT NULL")
        biz2poi = {}
        for r in cur.fetchall():
            biz2poi.setdefault(str(r["ctrip_business_id"]), set()).add(str(r["ctrip_poi_id"]))
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
    print(f"可对到客户景区的携程景点：{len(out)} 个", flush=True)
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


# ---------------------------------------------------------------- 主流程
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", required=True, help="解压后的数据目录（含 dwd.dwd_cus_service_dialogue_df.csv 等）")
    ap.add_argument("--out", default="", help="输出目录，默认 out/cs_synth_<今天>")
    ap.add_argument("--data-type", default="真实", help="用哪类原始对话，逗号分隔：真实 / 合成 / 改写；默认 真实")
    ap.add_argument("--split", default="train", help="数据集划分，默认 train（不要把 dev / test 改写进训练数据）；all = 不限")
    ap.add_argument("--city", default="", help="城市，逗号分隔，如 北京,上海")
    ap.add_argument("--intent", default="", help="意图，逗号分隔，如 门票,预约购票,退改规则")
    ap.add_argument("--limit", type=int, default=20, help="最多用几通原始对话（0=不限），默认 20")
    ap.add_argument("--variants", type=int, default=1, help="每通原始对话改写几个版本，默认 1")
    ap.add_argument("--workers", type=int, default=3, help="并发请求数，默认 3")
    ap.add_argument("--allow-unmapped", action="store_true", help="对不到客户景区的也生成（scenic_id 为空，景区名用原始的）")
    ap.add_argument("--no-db", action="store_true", help="不连 MySQL（不对景区，等同 --allow-unmapped）")
    ap.add_argument("--mysql", action="store_true", help="生成结果同时写进 MySQL 表 cs_dialog_synth")
    ap.add_argument("--profile", default=str(HERE / ".pw-profile-service"), help="读 AI 设置的浏览器目录（和工作台共用），默认服务的")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    import review  # 只为读设置文件
    cfg = ai_judge.config(review.Prefs(Path(args.profile) / "hq_prefs.json"))
    if not cfg.get("ai_api_key"):
        raise SystemExit("没有 AI 的 API Key：在工作台「设置 → AI 判断」里填，或设置环境变量 ARK_API_KEY")
    print(f"模型 {cfg['ai_model']}（{cfg['ai_base_url']}，非流式，深度思考{'开' if cfg.get('ai_thinking') else '关'}）", flush=True)

    src_all = load_source(args.data_dir)
    want = lambda v, x: not v or (x or "") in v.split(",")  # noqa: E731
    src = [s for s in src_all if want(args.data_type, s["data_type"]) and (args.split == "all" or want(args.split, s["split"]))
           and want(args.city, s["city"]) and want(args.intent, s["intent"]) and (s["turns"] or s["full"])]
    smap = {} if args.no_db else scenic_map()
    picked = []
    for s in src:
        biz = (s["attraction_id"] or "").replace("ctrip_", "")
        hits = smap.get(biz) or []
        if not hits and not (args.allow_unmapped or args.no_db):
            continue
        picked.append((s, hits[0] if hits else None, hits))
    random.Random(args.seed).shuffle(picked)
    if args.limit:
        picked = picked[: args.limit]
    print(f"筛选后可用 {len(src)} 通，其中能对到客户景区 {sum(1 for _ in picked)} 通（本次取 {len(picked)} 通 × {args.variants} 个版本）", flush=True)

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
        with db.cursor() as cur:
            cur.execute("""CREATE TABLE IF NOT EXISTS cs_dialog_synth (
  session_id VARCHAR(64) NOT NULL PRIMARY KEY, source_dialogue_id VARCHAR(64) NOT NULL, variant INT NOT NULL DEFAULT 1,
  scenic_id VARCHAR(64) NULL, scenic_name VARCHAR(255) NULL, intent_type VARCHAR(32) NULL, scene_type VARCHAR(32) NULL,
  needs_review TINYINT NOT NULL DEFAULT 0, check_flags VARCHAR(500) NULL, model VARCHAR(128) NULL, payload JSON NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, KEY idx_src (source_dialogue_id), KEY idx_scenic (scenic_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='智能客服对话：大模型改写的会话（source_dialogue_id 指回原始对话）'""")
        sql = db

    jobs = [(s, sc, hits, v) for s, sc, hits in picked for v in range(1, args.variants + 1) if (s["id"], v) not in done]
    print(f"待生成 {len(jobs)} 条（已生成的 {len(done)} 条跳过），输出到 {out}", flush=True)
    stats = dict(ok=0, review=0, rejected=0, failed=0)

    def one(s, sc, hits, v):
        rnd = _seeded(args.seed, s["id"], v)
        channel, persona = rnd.choice(CHANNELS), rnd.choice(PERSONAS)
        name = sc["scenic_name"] if sc else s["attraction_name"]
        t0 = time.time()
        try:
            text, elapsed, meta = ai_judge.call(cfg, build_prompt(s, name, persona, channel))
        except ai_judge.AIError as e:
            return ("failed", s, v, dict(error=str(e), http_status=e.http_status, request_id=e.request_id), None)
        try:
            js = ai_judge.parse(text)
            rec = assemble(s, sc, v, js, cfg, rnd)
            rec["channel"] = channel
            rec = {k: rec[k] for k in ["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns",
                                       "end_type", "satisfaction_score", "session_duration_sec", "source"]}
            rec["source"].update(persona=persona, elapsed=round(time.time() - t0, 1), request_id=meta.get("request_id"))
            if len(hits) > 1:
                rec["source"]["other_scenic_ids"] = [h["scenic_id"] for h in hits[1:]]
            return ("ok", s, v, rec, None)
        except Exception as e:  # noqa: BLE001
            return ("rejected", s, v, dict(error=f"{type(e).__name__}: {e}", raw=text[:2000]), None)

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = [ex.submit(one, *j) for j in jobs]
        for n, fut in enumerate(as_completed(futs), 1):
            kind, s, v, rec, _ = fut.result()
            with lock:
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
                        with sql.cursor() as cur:
                            cur.execute("""INSERT INTO cs_dialog_synth (session_id, source_dialogue_id, variant, scenic_id, scenic_name, intent_type, scene_type,
                                           needs_review, check_flags, model, payload) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                                           ON DUPLICATE KEY UPDATE payload=VALUES(payload), needs_review=VALUES(needs_review), check_flags=VALUES(check_flags)""",
                                        (rec["session_id"], s["id"], v, rec["scenic_id"], rec["scenic_name"], s["intent"], s["scene"], int(g["needs_review"]),
                                         "；".join(g["check_flags"])[:500] or None, g["model"], json.dumps(rec, ensure_ascii=False)))
                    stats["ok"] += 1
                    stats["review"] += int(g["needs_review"])
                else:
                    with f_rej.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(source_dialogue_id=s["id"], variant=v, kind=kind, **rec), ensure_ascii=False) + "\n")
                    stats[kind] += 1
                    print(f"  [{n}/{len(jobs)}] {s['id']} 第 {v} 版 {'调用失败' if kind == 'failed' else '不合格'}：{rec.get('error')}", flush=True)
                if n % 10 == 0 or n == len(jobs):
                    print(f"  进度 {n}/{len(jobs)}：成功 {stats['ok']}（需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}", flush=True)
    fm.close()
    print(f"完成：成功 {stats['ok']}（其中需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}。\n"
          f"  生成：{f_dlg}\n  原始：{f_src}\n  对照：{f_map}" + (f"\n  不合格 / 失败：{f_rej}" if stats["rejected"] or stats["failed"] else ""))
    return 0 if stats["ok"] or not jobs else 1


if __name__ == "__main__":
    sys.exit(main())
