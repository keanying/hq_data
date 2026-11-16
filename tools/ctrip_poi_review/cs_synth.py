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
import os
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
DATA_DIR = HERE / "data"  # 仓库里带的数据（客服对话包、景区表、讲解包、RedAttractionQA、对话数据集提取）；不填资料目录时用它
PROMPT_VERSION = "cs_rewrite_v3"
CHANNELS = ["小程序-在线客服", "APP-在线客服", "公众号-在线客服", "H5-在线客服", "PC官网-在线客服"]
PERSONAS = ["第一次来的外地游客，说话简短", "带小孩的家长，比较细心", "带老人出行的年轻人", "学生，预算有限", "着急的游客，会催促客服",
            "说话很口语化、喜欢用表情的年轻人", "常来的本地人", "公司团建的组织者"]
END_TYPES = ["用户主动结束", "客服结束", "超时自动结束", "静默离开", "转人工后结束", "用户不满中断"]
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
        cur.execute(f"""SELECT s.{db.C['id']} id, s.{db.C['name']} name, s.{db.C['city']} city, s.{db.C['province']} province,
                        s.{db.C['alias']} alias, s.{db.C['core_spots']} spots, s.{db.POI_INFO} info FROM {db.SCENIC_TABLE} s
                        WHERE COALESCE(s.{db.APPROVAL}, 0) = 1 AND s.{db.POI_INFO} IS NOT NULL AND s.{db.POI_INFO} <> '[]'""")
        poi2scenic = {}
        for r in cur.fetchall():
            pois = db._parse_info(r["info"])
            own = [r["name"]] + re.split(r"[,，、;；/]", r["alias"] or "") + re.split(r"[,，、;；/]", r["spots"] or "") + [p.get("poiName") for p in pois]
            sc = dict(scenic_id=r["id"], scenic_name=r["name"], city=r["city"], province=r["province"], own=[x.strip() for x in own if x and x.strip()])
            for p in pois:
                poi2scenic.setdefault(str(p.get("poiId")), []).append(sc)
    for biz, pois in biz2poi.items():
        hits = [s for p in pois for s in poi2scenic.get(p, [])]
        if hits:
            out[biz] = list({h["scenic_id"]: h for h in hits}.values())
    for p, hits in poi2scenic.items():  # 有的 attraction_id 本身就是 poiId
        out.setdefault(p, hits)
    log(f"可对到客户景区的携程景点：{len(out)} 个")
    return out


# ---------------------------------------------------------------- 提示词 / 生成
def build_prompt(src, scenic_name, persona, channel, plan=None):
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
3. 客服用官方客服口吻（「您好」「亲」等），把原始回答改写成客服回复，可以分几条说；游客第一条之后可以先由机器人（robot）接待，再由人工（human）回复，也可以全程机器人。
4. 如果原文里有明确的票种 / 价格，可以用一条 msg_type 为 card 的卡片消息表达，例如「[门票卡片] 成人票 ¥60」，内容必须是原文里的。
0. 你是「{scenic_name}」的客服，只回答和本景区有关的内容（门票、开放时间、预约、交通到本景区、园内设施和游玩、本景区周边吃住）。
   先判断原始问答是不是在问本景区：如果主要在问别的景点 / 别的城市，或者把本景区和别的景点放在一起比较、问住在哪儿两边都方便，就输出 {{"relevant": false, "reason": "原因"}}，不要改写。
   原文里顺带提到的其他景点信息一律删掉，不要以本景区客服的身份介绍别的景点。
5. 景区名写「{scenic_name}」{'' if same else f"，问的具体地方仍是「{spot}」（可以说「{scenic_name}的{spot}」），不要把{spot}的信息说成整个景区的"}；不要提「携程」「网友」「我们家去过」。
6. gap_sec 是这条消息距离上一条的秒数（游客 3～60 秒，客服 5～90 秒，第一条为 0）。

{plan_rules(plan) if plan else ""}

只输出一个 JSON 对象，不要其他文字；字符串里需要引号时用「」，不要用英文双引号（不是在问本景区时只输出 {{"relevant": false, "reason": "原因"}}）：
{{"relevant":true,{SESSION_JSON[1:]}"""


def _seeded(*parts):
    return random.Random(int(hashlib.sha1("|".join(map(str, parts)).encode()).hexdigest()[:12], 16))


def assemble(src, scenic, variant, js, cfg, rnd, plan=None):
    """模型给的轮次 + 程序生成的会话外壳（ID、时间、订单号等）→ 目标格式。"""
    if js.get("relevant") is False:
        raise NotRelevant(f"模型判断原始问答不是在问「{scenic['scenic_name'] if scenic else src['attraction_name']}」：{js.get('reason') or ''}")
    need_order = (src["scene"] in ("预订购票", "订单售后")) or (src["action"] not in (None, "", "none"))
    rec = build_session(js, rnd, "%s|%s" % (src["id"], variant), need_order, scenic["scenic_id"] if scenic else None,
                        scenic["scenic_name"] if scenic else src["attraction_name"], plan=plan)
    flags = quality_flags(src, rec) + (session_checks(plan, rec, js.get("coref")) if plan else [])
    # 输出 = 目标格式的字段 + 一个 source：指回原始对话，以及改写方式 / 质检结果
    rec["source"] = dict(dialogue_id=src["id"], data_type=src["data_type"], dataset_split_type=src["split"], attraction_id=src["attraction_id"],
                         attraction_name=src["attraction_name"], city=src["city"], intent_type=src["intent"], scene_type=src["scene"],
                         source_url=src["url"], variant=variant, generate_method="llm_rewrite", model=cfg.get("ai_model"),
                         prompt_version=PROMPT_VERSION, generated_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                         is_resolved=(plan["resolved"] if plan else bool(js.get("is_resolved"))), needs_review=bool(flags), check_flags=flags)
    if plan:
        rec["source"]["session_plan"] = plan_meta(plan, js.get("coref"))
    return rec


def plan_meta(p, coref=None):
    """会话设定写进 source（只给数据侧 / 质检看）。"""
    return dict(target_msgs=p["n"], end_type=p["end_type"], satisfaction=p["score"], resolved=p["resolved"], coref=p["coref"],
                coref_annotation=coref or [], order=p["order"], noise=p["noise"])


# ---------------------------------------------------------------- 会话设定（程序事先定好，模型照着写；校验报告 P0-2 / P1-2 / P1-5 / P2-1 / P2-3 / P2-6）
END_PLAN = [("用户主动结束", 45), ("客服结束", 15), ("超时自动结束", 15), ("静默离开", 10), ("转人工后结束", 10), ("用户不满中断", 5)]
END_DESC = {"用户主动结束": "游客说「好的 / 谢谢」之类后结束", "客服结束": "客服确认游客没有别的问题后礼貌结束",
            "超时自动结束": "最后一条是客服的追问，游客之后不再回复", "静默离开": "客服答完后游客没再说话，最后一条是客服",
            "转人工后结束": "机器人处理不了，转人工，人工接手说明后结束", "用户不满中断": "游客对答复不满意，抱怨一句后不再回复"}
SCORE_PLAN = [(None, 35), (5, 16), (4, 23), (3, 16), (2, 6), (1, 4)]  # 已评价的约 5 分 25%、4 分 35%、3 分 25%、2 分 9%、1 分 6%
LEN_PLAN = [(3, 4), (4, 8), (5, 10), (6, 12), (7, 12), (8, 11), (9, 9), (10, 8), (11, 6), (12, 5), (13, 4), (14, 3), (15, 2), (16, 2),
            (17, 1), (18, 1), (19, 1), (20, 1)]  # 消息条数长尾分布（3～20）
COREF_RE = re.compile(r"那个|这个|那边|这边|那里|这里|它|那家|那张|那种|这种|那.{0,6}呢|呢[？?]?$|那.{0,4}(?:能|可以|要|怎么|是|多少|几|还)")
REPEAT_RE = re.compile(r"([\u4e00-\u9fff]{4,}?)[～~，,。！!、 ]*\1")


def date_window(lo=None):
    """会话日期范围：不晚于截止日前一天（环境变量 CS_DATE_END=YYYY-MM-DD，默认今天），不早于 lo（如景区资料更新日的次日），最多往前一年。"""
    import os
    end = os.environ.get("CS_DATE_END")
    cutoff = datetime.strptime(end, "%Y-%m-%d") if end else datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    hi = cutoff - timedelta(days=1)
    start = hi - timedelta(days=364)
    if lo and lo > start:
        start = min(lo, hi)
    return start, hi


def _parse_day(v):
    m = re.match(r"(\d{4})-?(\d{2})-?(\d{2})", str(v or ""))
    return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None


def plan_session(rnd, need_order=False, facts_after=None, tickets=None, coref_rate=0.21):
    """一通会话的设定：开始时间、条数、结束方式、满意度、是否解决、指代、订单、语音 / 错别字 / 无标点。"""
    lo = _parse_day(facts_after) + timedelta(days=1) if _parse_day(facts_after) else None
    a, b = date_window(lo)
    day = a + timedelta(days=rnd.randint(0, max(0, (b - a).days)))
    start = day.replace(hour=rnd.randint(8, 21), minute=rnd.randint(0, 59), second=rnd.randint(0, 59))
    pick = lambda plan: rnd.choices([x for x, _ in plan], weights=[w for _, w in plan])[0]  # noqa: E731
    end_type = pick(END_PLAN)
    score = pick(SCORE_PLAN)
    if end_type == "用户不满中断":
        score = rnd.choice([None, 1, 2])
    elif end_type in ("超时自动结束", "静默离开") and rnd.random() < 0.6:
        score = None
    resolved = {"用户不满中断": False, "转人工后结束": False}.get(end_type, rnd.random() < (0.5 if end_type in ("超时自动结束", "静默离开") else 0.92))
    n = max(3, pick(LEN_PLAN))
    if end_type == "转人工后结束":
        n = max(n, 5)
    r = rnd.random()
    coref = "far" if r < coref_rate / 3 else "near" if r < coref_rate else None
    if coref == "far":
        n = max(n, 8)
    elif coref == "near":
        n = max(n, 5)
    order = None
    if need_order:
        t = rnd.choice(tickets or ["门票"])
        visit = day + timedelta(days=rnd.randint(1, 10))
        order = dict(order_id=f"DD{(day - timedelta(days=rnd.randint(0, 5))):%Y%m%d}{rnd.randint(0, 999999):06d}", ticket=t,
                     qty=rnd.choice([1, 1, 2, 2, 3, 4]), visit_date=f"{visit:%Y-%m-%d}")
    r = rnd.random()
    noise = "voice" if r < 0.08 else "typo" if r < 0.13 else "nopunct" if r < 0.18 else None
    return dict(start=start, n=n, end_type=end_type, score=score, resolved=resolved, coref=coref, order=order, noise=noise)


def plan_rules(p):
    """会话设定 → 提示词里的规则段。"""
    lines = [f"- 一共 {p['n']} 条消息（可以多或少 1 条）；第一条必须是游客发的（机器人接待语放在游客第一条之后）。",
             f"- 结束方式：{p['end_type']}（{END_DESC[p['end_type']]}）；"
             + ("游客没有评价" if p["score"] is None else f"满意度 {p['score']} 分（" + ("明显不满意" if p["score"] <= 2 else "一般" if p["score"] == 3 else "满意") + "）")
             + f"；问题{'已解决' if p['resolved'] else '没有完全解决'}，对话内容要和这些一致。"]
    if p["coref"]:
        lines.append("- 游客后面的提问要用指代或省略（如「那个能退吗」「小孩呢」「那边几点关门」），所指的东西在前面出现过"
                     + ("，而且要隔开至少 3 条消息（例如第 2 条提到、第 6 条以后才用「那个」指它）" if p["coref"] == "far" else "") + "；在 JSON 的 coref 里标出来。")
    if p["order"]:
        o = p["order"]
        lines.append(f"- 这是带订单的咨询：游客要在消息里明确说出订单号 {o['order_id']}、票种「{o['ticket']}」、{o['qty']} 张、游玩日期 {o['visit_date']}"
                     "（可以分几条说）；客服核对时复述订单号。")
    if p["noise"] == "voice":
        lines.append("- 游客有 1～2 条是语音消息：msg_type 写 voice，text 写语音转出来的文字（口语、没有标点、可能有一两个同音错字）。")
    elif p["noise"] == "typo":
        lines.append("- 游客有 1～2 条消息带错别字或同音字（如「门票」打成「门漂」），客服照常理解。")
    elif p["noise"] == "nopunct":
        lines.append("- 游客打字不带标点（整条消息没有逗号句号问号）。")
    return "会话设定（必须遵守）：\n" + "\n".join(lines)


SESSION_JSON = ('{"turns":[{"role":"user或agent","agent_type":"robot或human（仅 agent 填）","msg_type":"text / card / voice","text":"内容","gap_sec":整数}],'
                '\n "coref":[{"turn":用指代的消息序号,"ref_turn":被指的东西第一次出现的消息序号,"expr":"指代原话"}]}')


def session_checks(p, rec, coref_ann=None):
    """会话是否照设定写了（不合的标需复核）。"""
    flags = list(rec.pop("_notes", []))
    turns = rec["turns"]
    if abs(len(turns) - p["n"]) > 2:
        flags.append(f"消息条数 {len(turns)}，设定 {p['n']}")
    users = [t for t in turns if t["role"] == "user"]
    if p["order"] and not any(p["order"]["order_id"] in t["text"] for t in users):
        flags.append("游客消息里没有说出订单号")
    if p["noise"] == "voice" and not any(t.get("msg_type") == "voice" for t in users):
        flags.append("设定有语音消息，但没有 voice")
    if p["coref"]:
        ok = []
        for c in coref_ann or []:
            try:
                ti, ri = int(c.get("turn")), int(c.get("ref_turn"))
            except (TypeError, ValueError):
                continue
            if 1 <= ti <= len(turns) and turns[ti - 1]["role"] == "user" and str(c.get("expr") or "") and str(c.get("expr")) in turns[ti - 1]["text"] and ri < ti:
                ok.append(ti - ri)
        if not ok and not any(COREF_RE.search(t["text"]) for t in users[1:]):
            flags.append("设定要指代 / 省略，没找到")
        elif p["coref"] == "far" and not any(d >= 3 for d in ok):
            flags.append("设定要跨 3 条以上的指代，标注里没有")
    for t in turns:
        m = REPEAT_RE.search(t["text"])
        if m:
            flags.append(f"第 {t['turn']} 条疑似复读「{m.group(1)}」")
    return flags


def build_session(js, rnd, key, need_order, scenic_id, scenic_name, id_digits=6, plan=None):
    """模型给的轮次 → 会话外壳（session_id、访客、开始时间、每轮 ts、订单号、结束方式、时长），不含 source。
    key 决定 session_id（同一 key 重跑得到同一个 ID，写库时覆盖而不是重复）。"""
    raw_turns = [t for t in js.get("turns") or [] if isinstance(t, dict) and str(t.get("text") or "").strip()]
    notes = []
    if plan is not None:
        lead = 0
        while lead < len(raw_turns) and raw_turns[lead].get("role") != "user":
            lead += 1
        if lead:  # 首条必须是游客：去掉开头的客服 / 机器人消息
            raw_turns = raw_turns[lead:]
            notes.append(f"去掉了开头 {lead} 条客服消息（首条须为游客）")
    if len(raw_turns) < 2 or not any(t.get("role") == "user" for t in raw_turns) or not any(t.get("role") == "agent" for t in raw_turns):
        raise ValueError("轮次太少，或缺少游客 / 客服发言")
    if plan is not None:
        start = plan["start"]
        day = start.replace(hour=0, minute=0, second=0)
    else:
        day = datetime(2026, 1, 1) + timedelta(days=rnd.randint(0, 364))
        start = day.replace(hour=rnd.randint(8, 21), minute=rnd.randint(0, 59), second=rnd.randint(0, 59))
    human_id = f"A{rnd.randint(1000, 1999)}"
    t, turns = start, []
    for i, x in enumerate(raw_turns, 1):
        gap = int(x.get("gap_sec") or 0) if i > 1 else 0
        t = t + timedelta(seconds=max(0, min(gap, 600)))
        role = "user" if x.get("role") == "user" else "agent"
        mt = x.get("msg_type") if x.get("msg_type") in ("card", "voice") else "text"
        if mt == "voice" and role != "user":
            mt = "text"
        turn = dict(turn=i, role=role, msg_type=mt, text=str(x["text"]).strip(), ts=t.strftime("%H:%M:%S"))
        if role == "agent":
            turn["agent_id"] = "ROBOT" if x.get("agent_type") == "robot" else human_id
        turns.append(turn)
    if plan is not None:  # 结束方式、满意度、订单由设定决定（不让模型自己挑，避免分布失真）
        order = plan["order"]["order_id"] if plan["order"] else None
        score, end_type = plan["score"], plan["end_type"]
    else:
        order = f"DD{(day - timedelta(days=rnd.randint(1, 10))).strftime('%Y%m%d')}{rnd.randint(0, 999999):06d}" if need_order else None
        score = js.get("satisfaction_score")
        score = int(score) if isinstance(score, (int, float)) and 1 <= int(score) <= 5 else None
        end_type = js.get("end_type") if js.get("end_type") in END_TYPES else "用户主动结束"
    h = int(hashlib.sha1(key.encode()).hexdigest()[:8 if id_digits <= 6 else 15], 16) % (10 ** id_digits)  # 6 位：和旧版同一算法，重跑仍覆盖
    sid = "cs_%s_%0*d" % (start.strftime("%Y%m%d"), id_digits, h)
    rec = dict(session_id=sid, channel=None, visitor_id=f"V{rnd.randint(10000000, 99999999)}", scenic_id=scenic_id, scenic_name=scenic_name,
               start_time=start.strftime("%Y-%m-%d %H:%M:%S"), related_order_id=order, turns=turns, end_type=end_type,
               satisfaction_score=score, session_duration_sec=int((t - start).total_seconds()))
    if notes:
        rec["_notes"] = notes
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
BATCH_PREFIXES = ("cs_synth_", "cs_expand_", "guide_eval_", "guide_narr_")
BATCH_FILES = ["dialogs.jsonl", "mapping.csv", "source_extract.jsonl", "scenic_extract.jsonl", "knowledge_extract.jsonl", "rejected.jsonl"]
_count_cache = {}


def _count_lines(p):
    """文件行数（按 大小 + 修改时间 缓存；大文件按字节数数换行，不解析）。"""
    st = p.stat()
    k = (str(p), st.st_size, st.st_mtime)
    if k not in _count_cache:
        n = 0
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                n += chunk.count(b"\n")
        _count_cache[k] = n
    return _count_cache[k]


def _review_count(d):
    """需复核条数：生成时写的 _stats.json 优先；没有时小文件现数，大文件不数（返回 None）。"""
    sf = d / "_stats.json"
    if sf.exists():
        try:
            return json.loads(sf.read_text(encoding="utf-8")).get("review")
        except ValueError:
            pass
    p = d / "dialogs.jsonl"
    if not p.exists():
        return 0
    if p.stat().st_size > 50 * 1024 * 1024:
        return None
    k = ("review", str(p), p.stat().st_size, p.stat().st_mtime)
    if k not in _count_cache:
        n = 0
        for line in p.open(encoding="utf-8"):
            n += '"needs_review": true' in line
        _count_cache[k] = n
    return _count_cache[k]


def batches():
    """out/ 下已有的生成批次（目录），带各文件条数，给页面导出用。改写 = cs_synth_*，按景区数据扩展 = cs_expand_*。"""
    res = []
    dirs = [d for pre in BATCH_PREFIXES for d in OUT_ROOT.glob(pre + "*") if d.is_dir()]
    for d in sorted(dirs, key=lambda x: x.stat().st_mtime, reverse=True):
        info = dict(name=d.name, mode=next((m for p, m in (("cs_expand_", "expand"), ("guide_eval_", "guide_eval"), ("guide_narr_", "guide_narr"))
                                            if d.name.startswith(p)), "rewrite"), files={})
        for f in BATCH_FILES:
            p = d / f
            if p.exists():
                n = _count_lines(p)
                info["files"][f] = max(0, n - 1) if f.endswith(".csv") else n
        info["review"] = _review_count(d)
        info["mtime"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(d.stat().st_mtime))
        res.append(info)
    return res


def batch_dir(name):
    d = (OUT_ROOT / name).resolve()
    if d.parent != OUT_ROOT.resolve() or not d.name.startswith(BATCH_PREFIXES) or not d.is_dir():
        raise FileNotFoundError(f"没有这个批次：{name}")
    return d


# ---------------------------------------------------------------- 从 MySQL 导出（页面「导出」→「从 MySQL」）
EXPORT_FORMATS = {"l1_jsonl": "标注交付 L1 JSONL（不含答案 / 标签，给标注员）", "prov_jsonl": "溯源 sidecar JSONL（source + 结束方式 + 满意度，仅数据侧 / QC）",
                  "jsonl": "完整 JSONL（L1 + source，内部用）", "json": "完整 JSON 数组（内部用）", "csv_sessions": "会话表 CSV", "csv_turns": "轮次表 CSV"}

# 交付拆分（校验报告 T2 P0-1 / T3「反标注泄漏」）：标注员只拿 L1；答案、标签、生成参考、质检结论放 provenance sidecar
L1_KEYS = {
    "cs": ["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns", "session_duration_sec"],
    "eval": ["eval_task_id", "poi", "kb_entry", "guide_clip"],
    "narr": ["request_id", "scene", "request_time", "poi", "sub_poi_knowledge", "visitor_profile", "task_params"],
}
PROV_EXTRA = {"cs": ["end_type", "satisfaction_score"], "eval": ["eval_result"], "narr": ["reference_narration"]}
ID_KEY = {"cs": "session_id", "eval": "eval_task_id", "narr": "request_id"}


def rec_kind(rec):
    return "eval" if "eval_task_id" in rec else "narr" if "request_id" in rec and "scene" in rec else "cs"


def split_delivery(rec):
    """一条样本 → (L1 标注文件那一行, provenance sidecar 那一行)。两边用同一个 ID 关联。"""
    k = rec_kind(rec)
    l1 = {key: rec.get(key) for key in L1_KEYS[k] if key in rec}
    prov = {ID_KEY[k]: rec.get(ID_KEY[k])}
    for key in PROV_EXTRA[k]:
        if key in rec:
            prov[key] = rec[key]
    prov["source"] = rec.get("source")
    return l1, prov


def _export_sql(f):
    """筛选条件 → (FROM ... WHERE ..., 参数)。f：method(llm_rewrite/llm_expand) scenic city review(ok/review) date_from date_to。"""
    import db
    st, tt = db.ident(SESSION_TABLE), db.ident(TURN_TABLE)
    sql = f"FROM {st} s JOIN {tt} t ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1"
    where, params = [], []
    if f.get("city"):  # 先查这个城市的景区 ID 再过滤（不 JOIN：两张表排序规则不同时 JOIN 会报 Illegal mix of collations）
        with db.cursor() as cur:
            cur.execute(f"SELECT {db.C['id']} id FROM {db.SCENIC_TABLE} WHERE {db.C['city']} = %s", (f["city"],))
            ids = [str(r["id"]) for r in cur.fetchall()]
        where.append(f"s.scenic_id IN ({','.join(['%s'] * len(ids))})" if ids else "1 = 0")
        params += ids
    if f.get("method") in ("llm_rewrite", "llm_expand"):
        where.append("t.source LIKE %s")
        params.append(f'%"generate_method": "{f["method"]}"%')
    if f.get("review") in ("ok", "review"):
        where.append("t.source LIKE %s")
        params.append(f'%"needs_review": {"true" if f["review"] == "review" else "false"}%')
    if f.get("scenic"):
        names = [x.strip() for x in re.split(r"[,，]", f["scenic"]) if x.strip()]
        if names:
            where.append("(" + " OR ".join(["s.scenic_id = %s OR s.scenic_name LIKE %s"] * len(names)) + ")")
            for x in names:
                params += [x, f"%{x}%"]
    for k, op in (("date_from", ">="), ("date_to", "<=")):
        v = re.sub(r"\D", "", str(f.get(k) or ""))[:8]
        if len(v) == 8:
            where.append(f"s.travel_date {op} %s")
            params.append(int(v))
    return sql + (" WHERE " + " AND ".join(where) if where else ""), params


def export_count(f):
    import db
    sql, params = _export_sql(f)
    with db.cursor() as cur:
        mysql_check()
        cur.execute(f"SELECT COUNT(*) n, SUM(s.turn_cnt) turns {sql}", params)
        r = cur.fetchone()
    return dict(sessions=int(r["n"] or 0), turns=int(r["turns"] or 0))


def _fmt_dt(v):
    return v.strftime("%Y-%m-%d %H:%M:%S") if hasattr(v, "strftime") else (str(v) if v is not None else None)


def export_iter(f, fmt="jsonl", batch=500):
    """按条件从两张表流式导出（不一次读进内存，百万条也行）。产出字符串片段。"""
    import io
    import pymysql
    import db
    sql, params = _export_sql(f)
    limit = int(f.get("limit") or 0)
    head = dict(csv_sessions=["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "end_type",
                              "satisfaction_score", "session_duration_sec", "turn_cnt", "travel_date", "generate_method", "intent_type", "topic_name",
                              "needs_review", "check_flags", "source"],
                csv_turns=["session_id", "turn_no", "role", "msg_type", "msg_text", "agent_id", "msg_ts", "travel_date", "source"])

    def csv_line(row):
        buf = io.StringIO()
        csv.writer(buf).writerow(row)
        return buf.getvalue()
    if fmt in head:
        yield "\ufeff" + csv_line(head[fmt])  # 带 BOM，Excel 直接打开不乱码
    elif fmt == "json":
        yield "[\n"
    first = True
    sconn = pymysql.connect(**{**db.DB, "cursorclass": pymysql.cursors.SSDictCursor})
    tconn = pymysql.connect(**db.DB)
    try:
        with sconn.cursor() as scur:
            scur.execute(f"SELECT s.*, t.source {sql} ORDER BY s.travel_date, s.session_id" + (f" LIMIT {limit}" if limit else ""), params)
            while True:
                rows = scur.fetchmany(batch)
                if not rows:
                    break
                if fmt == "csv_sessions":
                    out = []
                    for r in rows:
                        try:
                            g = json.loads(r["source"] or "{}")
                        except ValueError:
                            g = {}
                        out.append(csv_line([r["session_id"], r["channel"], r["visitor_id"], r["scenic_id"], r["scenic_name"], _fmt_dt(r["start_time"]),
                                             r["related_order_id"], r["end_type"], r["satisfaction_score"], r["session_duration_sec"], r["turn_cnt"],
                                             r["travel_date"], g.get("generate_method"), g.get("intent_type"), g.get("topic_name"),
                                             int(bool(g.get("needs_review"))), "；".join(g.get("check_flags") or []), r["source"]]))
                    yield "".join(out)
                    continue
                with tconn.cursor() as tcur:
                    tcur.execute(f"""SELECT session_id, turn_no, role, msg_type, msg_text, agent_id, msg_ts, travel_date, source FROM {db.ident(TURN_TABLE)}
                                     WHERE session_id IN ({','.join(['%s'] * len(rows))}) ORDER BY session_id, turn_no""", [r["session_id"] for r in rows])
                    turns = {}
                    for t in tcur.fetchall():
                        turns.setdefault((t["session_id"], t["travel_date"]), []).append(t)
                out = []
                for r in rows:
                    ts = turns.get((r["session_id"], r["travel_date"]), [])
                    if fmt == "csv_turns":
                        out += [csv_line([t["session_id"], t["turn_no"], t["role"], t["msg_type"], t["msg_text"], t["agent_id"], _fmt_dt(t["msg_ts"]),
                                          t["travel_date"], t["source"] if t["turn_no"] == 1 else ""]) for t in ts]
                        continue
                    try:
                        g = json.loads(r["source"] or "{}")
                    except ValueError:
                        g = {"raw": r["source"]}
                    rec = dict(session_id=r["session_id"], channel=r["channel"], visitor_id=r["visitor_id"], scenic_id=r["scenic_id"],
                               scenic_name=r["scenic_name"], start_time=_fmt_dt(r["start_time"]), related_order_id=r["related_order_id"],
                               turns=[{k: v for k, v in dict(turn=t["turn_no"], role=t["role"], msg_type=t["msg_type"], text=t["msg_text"],
                                                             ts=t["msg_ts"].strftime("%H:%M:%S") if hasattr(t["msg_ts"], "strftime") else t["msg_ts"],
                                                             agent_id=t["agent_id"]).items() if not (k == "agent_id" and v is None)} for t in ts],
                               end_type=r["end_type"], satisfaction_score=r["satisfaction_score"], session_duration_sec=r["session_duration_sec"], source=g)
                    if fmt in ("l1_jsonl", "prov_jsonl"):
                        out.append(json.dumps(split_delivery(rec)[0 if fmt == "l1_jsonl" else 1], ensure_ascii=False) + "\n")
                        continue
                    line = json.dumps(rec, ensure_ascii=False)
                    if fmt == "json":
                        out.append(("" if first else ",\n") + line)
                        first = False
                    else:
                        out.append(line + "\n")
                yield "".join(out)
    finally:
        sconn.close()
        tconn.close()
    if fmt == "json":
        yield "\n]\n"


# ---------------------------------------------------------------- 主流程
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", default=str(DATA_DIR), help="数据目录（含 dwd.dwd_cus_service_dialogue_df.csv 等），默认仓库里的 data/")
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
    cfg = ai_judge.config(review.DbPrefs(Path(args.profile) / "hq_prefs.json", readonly=True))
    if not cfg.get("ai_api_key"):
        raise SystemExit("没有 AI 的 API Key：在工作台「设置 → AI 判断」里填，或设置环境变量 ARK_API_KEY")
    print(f"模型 {cfg['ai_model']}（{cfg['ai_base_url']}，非流式，深度思考{'开' if cfg.get('ai_thinking') else '关'}）", flush=True)

    stats = run(args, cfg, log=lambda m: print(m, flush=True))
    return 0 if stats["ok"] or not stats["total"] else 1


SUFFIX_RE = re.compile(r"(风景名胜区|旅游景区|旅游区|风景区|景区|景点)$")
GENERIC = {"博物馆", "纪念馆", "动物园", "植物园", "游乐园", "公园", "广场", "古镇", "步行街", "美术馆", "科技馆", "图书馆", "体育馆",
           "海洋馆", "水族馆", "游客中心", "停车场", "售票处", "服务中心", "度假区", "森林公园", "湿地公园", "文化馆", "大剧院"}


def _short(v):
    return re.sub(r"(省|市|自治区|壮族|回族|维吾尔|特别行政区)+$", "", (v or "").strip())


def _core(name, prefixes=()):
    """景点名的「核心」：去掉括号、省市前缀、景区 / 旅游区之类后缀，用来在问题里找。"""
    n = re.sub(r"[（(].*?[)）]", "", name or "").strip()
    for pre in prefixes:
        if pre and n.startswith(pre) and len(n) - len(pre) >= 3:
            n = n[len(pre):]
    n2 = SUFFIX_RE.sub("", n)
    return n2 if len(n2) >= 3 else n


def name_index(data_dir, log=print):
    """同城景点名字典（判断原始问题是不是在问别的景区）：数据包携程主档 + 我们的客户景区表。按城市（去掉「市」）分组。"""
    import db
    idx = {}
    d = Path(data_dir)
    f = next((p for n in MASTER_CSV for p in [d / n, *d.rglob(n)] if p.exists()), None)
    if f:
        for r in csv.DictReader(f.open(encoding="utf-8-sig")):
            idx.setdefault(_short(r.get("city_name")), set()).add((r.get("attraction_name") or "").strip())
    try:
        with db.cursor() as cur:
            cur.execute(f"SELECT s.{db.C['name']} name, s.{db.C['city']} city FROM {db.SCENIC_TABLE} s")
            for r in cur.fetchall():
                idx.setdefault(_short(r["city"]), set()).add((r["name"] or "").strip())
    except Exception as e:  # noqa: BLE001
        log(f"读客户景区名失败（只用数据包里的景点名判断）：{e}")
    out = {}
    for city, names in idx.items():
        cores = {}
        for n in names:
            c = _core(n, (city,))
            if len(c) >= 3 and c not in GENERIC:
                cores.setdefault(c, n)
        out[city] = cores
    return out


def other_place(src, scenic, idx):
    """原始问题里点名了同城别的景点（不是我们这个景区本身、别名、核心景点、保留的 POI）→ 返回那个景点名；没有返回 None。"""
    if not scenic:
        return None
    q = " ".join(t["text"] for t in src["turns"] if t["role"] == "游客") or (src["row"].get("first_question_content")
                                                                           or src["row"].get("first_question_text") or "")
    if not q:
        return None
    city = _short(scenic.get("city"))
    pre = (_short(scenic.get("province")), city)
    own = {_core(x, pre) for x in (scenic.get("own") or []) + [src["attraction_name"] or ""] if x}
    own = {o for o in own if len(o) >= 2}
    mentions_own = any(o in q for o in own if len(o) >= 2)
    for core, full in (idx.get(city) or {}).items():
        if core in q and not any(core in o or o in core for o in own):
            # 「从春熙路怎么去金沙」这种：别的地方只是出发点、问的是怎么到本景区 → 不算问别的景区
            if mentions_own and re.search(re.escape(core) + r".{0,10}?(去|到|过去|过来|出发|坐车|打车|怎么走)", q) \
                    and re.search(r"从\s*\S{0,6}" + re.escape(core), q):
                continue
            return full
    return None


# 原始问题问的是机票 / 火车票这类别的业务（携程问答里常挂在景点下面）。我们只按真实问答改写，
# 换成景区的问题就得编答案，所以调模型之前先排除，省调用。问题里同时提到本景区名的不算（如「下飞机怎么去故宫」）。
# 词表故意收得窄（「回酒店退房」是问能否出园再进，千岛湖的「航班」是船班），拿不准的交给模型判断。
OFF_TOPIC_RE = re.compile(r"(机票|航空公司|登机|值机|行李托运|火车票|高铁票|动车票|12306)")


def off_topic(src, scenic):
    """原始问题问的是机票 / 火车票等别的业务 → 返回命中的词；否则 None。"""
    q = " ".join(t["text"] for t in src["turns"] if t["role"] == "游客") or (src["row"].get("first_question_content")
                                                                           or src["row"].get("first_question_text") or "")
    m = OFF_TOPIC_RE.search(q or "")
    if not m:
        return None
    pre = (_short((scenic or {}).get("province")), _short((scenic or {}).get("city")))
    own = {_core(x, pre) for x in ((scenic or {}).get("own") or []) + [src["attraction_name"] or ""] if x}
    return None if any(len(o) >= 2 and o in q for o in own) else m.group(1)


class NotRelevant(ValueError):
    """模型判断原始问答不是在问这个景区：跳过，不算不合格。"""


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
    picked, excluded = [], []
    idx = name_index(args.data_dir, log) if smap and not getattr(args, "keep_other_place", False) else {}
    for s in src:
        hits = smap.get((s["attraction_id"] or "").replace("ctrip_", "")) or []
        if only or scity:
            hits = [h for h in hits if (not only or h["scenic_id"] in only or h["scenic_name"] in only) and (not scity or h["city"] in scity)]
            if not hits:
                continue
        if not hits and not (args.allow_unmapped or args.no_db):
            continue
        other = other_place(s, hits[0], idx) if idx and hits else None
        if other:  # 问的是（或连带问了）同城别的景点：不适合当这个景区的客服对话
            excluded.append(dict(dialogue_id=s["id"], scenic_name=hits[0]["scenic_name"], other=other,
                                 question=(" ".join(t["text"] for t in s["turns"] if t["role"] == "游客") or s["full"] or "")[:80]))
            continue
        word = off_topic(s, hits[0] if hits else None)
        if word:  # 问的是机票 / 火车票等别的业务
            excluded.append(dict(dialogue_id=s["id"], scenic_name=hits[0]["scenic_name"] if hits else s["attraction_name"], other=word, kind="off_topic",
                                 question=(" ".join(t["text"] for t in s["turns"] if t["role"] == "游客") or s["full"] or "")[:80]))
            continue
        picked.append((s, hits[0] if hits else None, hits))
    n_off = sum(1 for x in excluded if x.get("kind") == "off_topic")
    if len(excluded) > n_off:
        log(f"原始问题点名了同城别的景点（不是在问这个景区），排除 {len(excluded) - n_off} 通，例如："
            + "；".join(f"{x['scenic_name']} ← 问到「{x['other']}」" for x in [y for y in excluded if y.get("kind") != "off_topic"][:3]))
    if n_off:
        log(f"原始问题问的是机票 / 火车票等别的业务，排除 {n_off} 通")
    select.excluded = excluded
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
    exc = getattr(select, "excluded", []) or []
    return dict(source_total=len(src), usable=len(picked), scenics=len([r for r in rows if r["scenic_id"]]), by_scenic=rows[:300],
                excluded_other=len([x for x in exc if x.get("kind") != "off_topic"]), excluded_offtopic=len([x for x in exc if x.get("kind") == "off_topic"]),
                excluded_examples=[x for x in exc if x.get("kind") != "off_topic"][:20],
                offtopic_examples=[x for x in exc if x.get("kind") == "off_topic"][:20],
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
    f_done = out / "done_keys.txt"
    files = getattr(args, "files", True) or not args.mysql  # 只写库模式（工作台默认）：不写 dialogs / mapping / source_extract 文件
    done = set()
    if f_dlg.exists() and not f_done.exists():  # 旧批次：先从 dialogs.jsonl 建进度文件，之后以进度文件为准（清理数据时只改它）
        ks = []
        for line in f_dlg.read_text(encoding="utf-8").splitlines():
            try:
                r = json.loads(line)
                ks.append(f"{r['source']['dialogue_id']}|{r['source']['variant']}")
            except (ValueError, KeyError):
                pass
        f_done.write_text("\n".join(ks) + ("\n" if ks else ""), encoding="utf-8")
    if f_rej.exists():  # 模型已判断「不是在问这个景区」的不再重复调用
        for line in f_rej.read_text(encoding="utf-8").splitlines():
            try:
                r = json.loads(line)
                if r.get("kind") == "skipped":
                    done.add((r["source_dialogue_id"], r["variant"]))
            except (ValueError, KeyError):
                pass
    have_src = set()
    if f_src.exists():
        for line in f_src.read_text(encoding="utf-8").splitlines():
            try:
                have_src.add(json.loads(line)["dialogue_id"])
            except (ValueError, KeyError):
                pass
    for d in {out, *OUT_ROOT.glob("cs_synth_*")}:  # 进度：所有改写批次的 done_keys（跨天续跑不重复）
        fd = d / "done_keys.txt"
        if fd.exists():
            for k in fd.read_text(encoding="utf-8").split():
                a, _, b = k.rpartition("|")
                if b.isdigit():
                    done.add((a, int(b)))
    new_map = not f_map.exists()
    lock = threading.Lock()
    fm = f_map.open("a", encoding="utf-8-sig" if new_map else "utf-8", newline="") if files else open(os.devnull, "w")
    mw = csv.writer(fm)
    if new_map and files:
        mw.writerow(["session_id", "source_dialogue_id", "variant", "scenic_id", "scenic_name", "source_attraction_id", "source_attraction_name",
                     "intent_type", "scene_type", "turns", "needs_review", "check_flags", "model", "generated_at"])
    sql = None
    if args.mysql:
        import db
        mysql_check()
        sql = db

    jobs = [(s, sc, hits, v) for s, sc, hits in picked for v in range(1, args.variants + 1) if (s["id"], v) not in done]
    log(f"待生成 {len(jobs)} 条（已生成的 {len(done)} 条跳过），输出到 {out}")
    stats = dict(ok=0, review=0, skipped=0, rejected=0, failed=0, cancelled=0, total=len(jobs), out=str(out))
    progress(0, len(jobs))

    def one(s, sc, hits, v):
        if should_stop():
            return ("cancelled", s, v, dict(error="已停止"), None)
        rnd = _seeded(args.seed, s["id"], v)
        channel, persona = rnd.choice(CHANNELS), rnd.choice(PERSONAS)
        name = sc["scenic_name"] if sc else s["attraction_name"]
        need_order = (s["scene"] in ("预订购票", "订单售后")) or (s["action"] not in (None, "", "none"))
        plan = plan_session(_seeded(args.seed, "plan", s["id"], v), need_order)
        prompt = build_prompt(s, name, persona, channel, plan)
        ex_ = dict(prompt=prompt, persona=persona, channel=channel, started=time.strftime("%H:%M:%S"))
        t0 = time.time()
        try:
            text, elapsed, meta = ai_judge.call(cfg, prompt)
        except ai_judge.AIError as e:
            return ("failed", s, v, dict(error=str(e), http_status=e.http_status, request_id=e.request_id), dict(ex_, elapsed=round(time.time() - t0, 1)))
        ex_.update(response=text, elapsed=elapsed, request_id=meta.get("request_id"))
        try:
            js = ai_judge.parse(text)
            rec = assemble(s, sc, v, js, cfg, rnd, plan)
            rec["channel"] = channel
            rec = {k: rec[k] for k in ["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns",
                                       "end_type", "satisfaction_score", "session_duration_sec", "source"]}
            rec["source"].update(persona=persona, elapsed=round(time.time() - t0, 1), request_id=meta.get("request_id"))
            if len(hits) > 1:
                rec["source"]["other_scenic_ids"] = [h["scenic_id"] for h in hits[1:]]
            return ("ok", s, v, rec, ex_)
        except NotRelevant as e:
            return ("skipped", s, v, dict(error=str(e), raw=text[:2000]), ex_)
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
                if kind == "ok" and sql:  # 先写库；只写库模式下写库失败算调用失败，下次重跑
                    try:
                        with sql.cursor() as cur:
                            mysql_write(cur, rec)
                    except Exception as e:  # noqa: BLE001
                        log(f"  写 MySQL 失败 {rec['session_id']}：{type(e).__name__}: {e}")
                        if not files:
                            kind, rec = "failed", dict(error=f"写 MySQL 失败：{type(e).__name__}: {e}")
                if files and s["id"] not in have_src:  # 原始数据：原表整行 + 逐轮发言，每通只写一次
                    with f_src.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(dialogue_id=s["id"], row=s["row"], turns=s["turns"]), ensure_ascii=False) + "\n")
                    have_src.add(s["id"])
                if kind == "ok":
                    with f_done.open("a", encoding="utf-8") as f:  # 进度（断点续跑用）
                        f.write(f"{s['id']}|{v}\n")
                if kind == "ok" and files:
                    with f_dlg.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    g = rec["source"]
                    mw.writerow([rec["session_id"], s["id"], v, rec["scenic_id"] or "", rec["scenic_name"], s["attraction_id"], s["attraction_name"],
                                 s["intent"], s["scene"], len(rec["turns"]), int(g["needs_review"]), "；".join(g["check_flags"]), g["model"], g["generated_at"]])
                    fm.flush()
                if kind == "ok":
                    g = rec["source"]
                    stats["ok"] += 1
                    stats["review"] += int(g["needs_review"])
                else:
                    with f_rej.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(source_dialogue_id=s["id"], variant=v, kind=kind, **rec), ensure_ascii=False) + "\n")
                    stats[kind] += 1
                    log(f"  [{n}/{len(jobs)}] {s['id']} 第 {v} 版 {dict(failed='调用失败', skipped='跳过（不是在问这个景区）').get(kind, '不合格')}：{rec.get('error')}")
                src_view = dict(dialogue_id=s["id"], data_type=s["data_type"], split=s["split"], city=s["city"], attraction_id=s["attraction_id"],
                                attraction_name=s["attraction_name"], intent=s["intent"], scene=s["scene"], url=s["url"], turns=s["turns"], full=s["full"])
                on_item(dict(kind=kind, variant=v, source=src_view, exchange=ex_, record=rec if kind == "ok" else None,
                             error=None if kind == "ok" else rec.get("error"), mysql=bool(sql)))
                progress(n, len(jobs))
                if n % 10 == 0 or n == len(jobs):
                    log(f"  进度 {n}/{len(jobs)}：成功 {stats['ok']}（需复核 {stats['review']}），跳过 {stats['skipped']}，不合格 {stats['rejected']}，调用失败 {stats['failed']}")
    fm.close()
    log(f"完成：成功 {stats['ok']}（其中需复核 {stats['review']}），非本景区跳过 {stats['skipped']}，不合格 {stats['rejected']}，调用失败 {stats['failed']}"
        + (f"，停止前未处理 {stats['cancelled']}" if stats["cancelled"] else "") + "。\n"
          f"  生成：{f_dlg}\n  原始：{f_src}\n  对照：{f_map}" + (f"\n  不合格 / 失败：{f_rej}" if stats["rejected"] or stats["failed"] else ""))
    return stats


if __name__ == "__main__":
    sys.exit(main())
