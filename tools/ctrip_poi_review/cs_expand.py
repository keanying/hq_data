"""按景区真实数据「扩展」客服对话：事实取自客户景区表（pft_ai_dim_prd_scenic_base_yr_f 的票价、开放时间、地址、电话…），
游客怎么问、客服怎么接话参考包里的真实客服对话（只学问法，不用里面的事实）。每条都能追溯到用了景区表哪一行、哪些字段、参考了哪几通真实对话。

    python cs_expand.py --data-dir <解压后的包>/data --limit 50                       # 先试 50 条
    python cs_expand.py --data-dir ... --scenic-city 北京市 --topics ticket,hours --variants 3
    python cs_expand.py --data-dir ... --variants 8 --workers 32 --limit 0 --mysql    # 全量（约 100 万条，见 README）

规模 = 景区数 × 每个景区有资料的主题数 × 每个主题几版（--variants）。主题见 TOPICS：
    门票价格 / 预约购票 / 开放时间 / 交通停车 / 游玩建议 / 咨询投诉电话 / 讲解服务 / 景区介绍 / 综合咨询（随机 2～3 个主题）
    景点讲解（culture）：每条讲解资料一个单元，事实来自数据目录里的景区讲解包、RedAttractionQA（见 cs_sources.py）
景区表里某个主题的字段都是空的，这个景区就不生成这个主题（不编）。
问法参考：包里的真实客服对话 + 数据目录里的 RiSAWOZ / CrossWOZ 景点对话（只用 train；有就每条各取 1 通）。

输出（out/cs_expand_<日期>/，可断点续跑：out/ 下所有 cs_expand_* 批次的 done_keys.txt 里有的「景区 + 主题 + 第几版」都跳过，跨天也不重复）：
    dialogs.jsonl          生成的会话：目标格式 + source（generate_method=llm_expand、景区表名 / 行 ID / 用到的字段和值、参考的真实对话 ID、质检）
    scenic_extract.jsonl   用到的景区表行（整行，每个景区写一次）
    knowledge_extract.jsonl 用到的讲解资料（事实 + 出处网址，每条写一次）
    source_extract.jsonl   用到的参考对话（原表整行 + 逐轮发言，每通写一次）
    mapping.csv            session_id ↔ 景区 ↔ 主题 ↔ 参考对话 ↔ 质检
    rejected.jsonl         模型返回不合格 / 调用失败的
    --mysql 时和改写模式写同样的两张表（同一会话重跑会覆盖）。
"""
import argparse
import csv
import json
import re
import threading
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime
from pathlib import Path

import ai_judge
import cs_sources
import cs_synth
from cs_synth import CHANNELS, END_TYPES, MONEY_RE, PERSONAS, TIME_RE, _seeded

PROMPT_VERSION = "cs_expand_v2"
OUT_ROOT = cs_synth.OUT_ROOT

# 主题：用到景区表哪些字段、至少要有哪个字段才生成、参考真实对话的哪些意图、游客情境（让同一景区同一主题的几版不重样）
TOPICS = {
    "ticket": dict(name="门票价格", intent="门票价格", scene="售前咨询",
                   fields=["is_free_flag", "ticket_adult_weekday_amt", "ticket_adult_peak_amt", "ticket_adult_low_amt", "ticket_preferential_amt",
                           "ticket_transit_amt", "ticket_combo_amt", "has_online_ticket_flag"],
                   need=["is_free_flag", "ticket_adult_weekday_amt", "ticket_adult_peak_amt"], refs=["门票价格", "门票"],
                   situations=["一家人周末去，想知道一共要花多少", "带老人和小孩，想问有没有优惠", "学生，想问学生能不能便宜", "想问旺季淡季价格差多少",
                               "问网上买票和现场买票是不是一个价", "问门票里包不包含园内交通", "朋友推荐来的，先问问票价"]),
    "booking": dict(name="预约购票", intent="预约购票", scene="预订购票",
                    fields=["has_online_ticket_flag", "ticket_advance_days_qty", "is_free_flag", "daily_capacity_max_qty", "scenic_official_appid",
                            "scenic_website_url"],
                    need=["has_online_ticket_flag", "ticket_advance_days_qty"], refs=["预约购票", "预约"],
                    situations=["第一次去，不知道要不要提前预约", "下周想去，问最早能提前几天约", "节假日去，担心约不上", "问在哪里能买票 / 预约",
                                "不会用手机，问现场能不能买", "问免费景区还用不用预约"]),
    "hours": dict(name="开放时间", intent="开放时间", scene="售前咨询",
                  fields=["open_status_type", "open_time_peak", "close_time_peak", "open_time_low", "close_time_low", "last_entry_time", "special_open_rule_desc"],
                  need=["open_time_peak", "special_open_rule_desc"], refs=["开放时间"],
                  situations=["下午才到，担心进不去", "冬天去，问开放时间有没有变", "想一早去，问几点开门", "问最晚几点入园", "问下雨天 / 恶劣天气开不开",
                              "节假日去，问会不会调整时间"]),
    "traffic": dict(name="交通停车", intent="交通", scene="售前咨询",
                    fields=["province_name", "city_name", "district_name", "scenic_address", "has_parking_flag", "parking_space_qty"],
                    need=["scenic_address"], refs=["交通"],
                    situations=["自驾过去，问能不能停车", "导航找不到，问具体地址", "外地来的，问景区在哪个区", "问停车位多不多、好不好停",
                                "打车过去，问报哪个地址"]),
    "plan": dict(name="游玩建议", intent="游玩建议", scene="售前咨询",
                 fields=["suggest_duration_desc", "best_season_desc", "scenic_core_spots", "scenic_feature_tags", "scenic_main_type", "scenic_sub_type"],
                 need=["suggest_duration_desc", "scenic_core_spots"], refs=["游玩建议"],
                 situations=["只有半天时间，问怎么安排", "第一次来，问必看的地方", "问什么季节来最好", "带孩子去，问玩多久合适", "问景区主要是看什么的"]),
    "contact": dict(name="咨询投诉电话", intent="其他", scene="售后服务",
                    fields=["scenic_tel_consult", "scenic_tel_complaint", "scenic_operator_name"],
                    need=["scenic_tel_consult", "scenic_tel_complaint"], refs=["其他"],
                    situations=["想打电话问问，要咨询电话", "游玩时体验不好，想投诉", "问景区是哪家单位在运营", "团队出行，想电话沟通一下"]),
    "guide": dict(name="讲解服务", intent="游玩建议", scene="售前咨询",
                  fields=["has_guide_flag", "guide_language_type"], need=["has_guide_flag"], refs=["游玩建议", "其他"],
                  situations=["带外国朋友去，问有没有外语讲解", "想听讲解，问有没有讲解服务", "带孩子去，想找讲解了解历史"]),
    "intro": dict(name="景区介绍", intent="游玩建议", scene="售前咨询",
                  fields=["scenic_desc", "scenic_grade_level", "scenic_national_title", "scenic_heritage_cert", "scenic_area_mu", "scenic_mountain_river"],
                  need=["scenic_desc"], refs=["游玩建议", "其他"],
                  situations=["还没决定去不去，先了解一下景区", "问景区是几A级", "问景区大不大", "问景区有什么特色 / 来历"]),
}
MIXED = dict(name="综合咨询", intent="其他", scene="售前咨询", situations=["出发前一次把想问的都问了", "边问边做攻略", "帮家里人问的，问得比较细"])
# 景点讲解 / 历史文化：事实来自景区讲解包（每条讲解一个单元）或 RedAttractionQA（能唯一对到景区的，每 5 条一个单元）
CULTURE = dict(name="景点讲解", intent="游玩建议", scene="售前咨询", refs=["游玩建议", "其他"],
               situations=["参观前想先了解一下这个地方", "带孩子来研学，想让孩子听懂", "听说很有名，想知道为什么", "到了现场，想知道有什么看点",
                           "对历史感兴趣，问得比较细", "带老人来，老人想多了解些过去的事", "想拍照打卡，顺便了解来历"])
ALL_TOPICS = list(TOPICS) + ["mixed", "culture"]
REF_CACHE = cs_synth.OUT_ROOT / "cs_refs_cache"

LABELS = dict(is_free_flag="是否免费", ticket_adult_weekday_amt="成人票（平日）", ticket_adult_peak_amt="成人票（旺季）", ticket_adult_low_amt="成人票（淡季）",
              ticket_preferential_amt="优惠票", ticket_transit_amt="景区交通票", ticket_combo_amt="联票 / 套票", has_online_ticket_flag="能否线上购票",
              ticket_advance_days_qty="可提前预约天数", daily_capacity_max_qty="每日最大承载量", scenic_official_appid="官方小程序", scenic_website_url="官网",
              open_status_type="开放状态", open_time_peak="旺季开门", close_time_peak="旺季关门", open_time_low="淡季开门", close_time_low="淡季关门",
              last_entry_time="最晚入园", special_open_rule_desc="特殊开放规则", province_name="省份", city_name="城市", district_name="区县",
              scenic_address="地址", has_parking_flag="有无停车场", parking_space_qty="停车位", suggest_duration_desc="建议游玩时长",
              best_season_desc="最佳游玩季节", scenic_core_spots="主要景点", scenic_feature_tags="特色", scenic_main_type="景区类型", scenic_sub_type="细分类型",
              scenic_tel_consult="咨询电话", scenic_tel_complaint="投诉电话", scenic_operator_name="运营单位", has_guide_flag="有无讲解服务",
              guide_language_type="讲解语种", scenic_desc="景区简介", scenic_grade_level="等级", scenic_national_title="称号", scenic_heritage_cert="文保 / 遗产认定",
              scenic_area_mu="面积", scenic_mountain_river="山水资源")
STATUS = dict(all="正常开放", seasonal="季节性开放", closed="暂停开放")
PRICE_FIELDS = {"ticket_adult_weekday_amt", "ticket_adult_peak_amt", "ticket_adult_low_amt", "ticket_preferential_amt"}


# ---------------------------------------------------------------- 景区资料
def _blank(v):
    return v is None or str(v).strip() in ("", "NULL", "null", "\\N", "None", "nan")


def _num(v):
    s = str(v).strip()
    return s[:-2] if s.endswith(".0") else s


def fmt_value(col, v):
    """景区表原值 → 给模型看的文字（不改数字，只加单位 / 把 0/1 变成是 / 否）。空值返回 None。"""
    if _blank(v):
        return None
    s = str(v).strip()
    if col.endswith("_flag"):
        return {"1": "是", "0": "否"}.get(_num(s), s)
    if col.endswith("_amt"):
        return f"{_num(s)} 元"
    if col in ("open_time_peak", "close_time_peak", "open_time_low", "close_time_low", "last_entry_time"):
        m = re.match(r"^(\d{1,2}):(\d{2})(?::00)?$", s)
        return f"{int(m.group(1))}:{m.group(2)}" if m else s
    if col == "open_status_type":
        return STATUS.get(s, s)
    if col.endswith("_qty") and _num(s) in ("0", "0.00"):  # 数量为 0 = 没填，不当事实
        return None
    if col == "ticket_advance_days_qty":
        return f"{_num(s)} 天"
    if col == "daily_capacity_max_qty":
        return f"{_num(s)} 人"
    if col == "parking_space_qty":
        return f"{_num(s)} 个"
    if col == "scenic_area_mu":
        return f"{_num(s)} 亩"
    if col == "scenic_website_url" and s.startswith("{"):
        try:
            return json.loads(s).get("link") or s
        except ValueError:
            return s
    return s


def topic_facts(row, topic):
    """某个景区某个主题的资料 {字段: 文字}；必需字段全空 → None（这个景区不生成这个主题）。"""
    t = TOPICS[topic]
    if all(_blank(row.get(c)) for c in t["need"]):
        return None
    free = fmt_value("is_free_flag", row.get("is_free_flag")) == "是"
    out = {}
    for c in t["fields"]:
        if free and c in PRICE_FIELDS:  # 免费景区不给门票价，免得自相矛盾
            continue
        v = fmt_value(c, row.get(c))
        if v is not None:
            out[c] = v
    return out or None


def available(row, topics, ctx=None):
    """这个景区能生成哪些主题（综合咨询要有至少 2 个主题有资料；景点讲解每条讲解资料一个，记作 culture@<单元ID>）。"""
    have = [t for t in topics if t in TOPICS and topic_facts(row, t)]
    if "mixed" in topics and len([t for t in TOPICS if topic_facts(row, t)]) >= 2:
        have.append("mixed")
    if "culture" in topics and ctx:
        have += [f"culture@{u['unit_id']}" for u in ctx["units"].get(row["_id"], [])]
    return have


def load_context(args, rows, log=print):
    """真实问法（包里客服对话 + RiSAWOZ / CrossWOZ 景点轮次）和讲解资料（景区讲解包 + RedAttractionQA）。"""
    pool = ref_pool(args.data_dir, log)
    cs_sources.build_cache(args.data_dir, REF_CACHE, log)
    woz = {}
    for r in cs_sources.load_woz_refs(REF_CACHE):
        r.update(attraction_name="", intent=r["dataset"], city="")
        for t in r["topics"] or ["plan"]:
            woz.setdefault(t, []).append(r)
    red = cs_sources.load_redqa(REF_CACHE)
    units = {}
    if "culture" in _topics(args):
        units = cs_sources.load_guide(args.data_dir, log)
        n_guide = sum(len(v) for v in units.values())
        for sid, us in cs_sources.map_redqa(red, rows, cs_synth._core).items():
            units.setdefault(sid, []).extend(us)
        n_red = sum(len(v) for v in units.values()) - n_guide
        if n_red:
            log(f"RedAttractionQA：能唯一对到景区的资料整理成 {n_red} 个讲解单元")
    by_id = {u["unit_id"]: u for us in units.values() for u in us}
    return dict(pool=pool, woz=woz, red_q=[x["q"] for x in red if x["q"] and not re.match(r"^(该|此|这|其)", x["q"])], units=units, by_id=by_id,
                stats=dict(woz={k: len(v) for k, v in woz.items()}, red=len(red), guide_units=sum(1 for u in by_id.values() if u["kind"] == "guide"),
                           red_units=sum(1 for u in by_id.values() if u["kind"] == "redqa"), culture_scenics=len(units)))


def load_scenics(args, log=print):
    """从 MySQL 客户景区表读景区（整行）。scenic：ID 或名称，逗号分隔；scenic_city：城市；grade：等级；only_approved：只要已审核的。"""
    import db
    where, params = [], []
    only = [x.strip() for x in (getattr(args, "scenic", "") or "").split(",") if x.strip()]
    if only:
        where.append(f"({db.C['id']} IN ({','.join(['%s'] * len(only))}) OR {db.C['name']} IN ({','.join(['%s'] * len(only))}))")
        params += only + only
    cities = [x.strip() for x in (getattr(args, "scenic_city", "") or "").split(",") if x.strip()]
    if cities:
        where.append(f"{db.C['city']} IN ({','.join(['%s'] * len(cities))})")
        params += cities
    grades = [x.strip() for x in (getattr(args, "grade", "") or "").split(",") if x.strip()]
    if grades:
        where.append(f"{db.C['grade']} IN ({','.join(['%s'] * len(grades))})")
        params += grades
    if getattr(args, "only_approved", False):
        where.append(f"COALESCE({db.APPROVAL}, 0) = 1")
    with db.cursor() as cur:
        cur.execute(f"SELECT * FROM {db.SCENIC_TABLE}" + (" WHERE " + " AND ".join(where) if where else "") + f" ORDER BY {db.C['id']}", params)
        rows = cur.fetchall()
    for r in rows:
        r["_id"], r["_name"], r["_city"] = str(r.get(db.C["id"].strip("`"))), r.get(db.C["name"].strip("`")), r.get(db.C["city"].strip("`"))
    log(f"景区表 {db.SCENIC_TABLE.strip('`')}：按条件取到 {len(rows)} 个景区")
    return rows


# ---------------------------------------------------------------- 参考对话（真实问法）
def ref_pool(data_dir, log=print):
    """包里的真实客服对话（只用 真实 + train），按意图分组；问机票 / 火车票之类的不要。"""
    src = cs_synth.load_source(data_dir, log)
    pool = {}
    for s in src:
        if s["data_type"] != "真实" or s["split"] != "train" or not s["turns"] or cs_synth.off_topic(s, None):
            continue
        s["dataset"] = "客服对话包"
        pool.setdefault(s["intent"] or "其他", []).append(s)
    log("参考对话（真实 · train）按意图：" + "、".join(f"{k} {len(v)}" for k, v in sorted(pool.items(), key=lambda x: -len(x[1]))))
    return pool


def pick_refs(pool, intents, rnd, n=2, woz=None, topics=()):
    """参考对话：有 RiSAWOZ / CrossWOZ 时 1 通包里的真实客服对话 + 1 通对应主题的景点对话，没有就 2 通包里的。"""
    cands = [s for i in intents for s in pool.get(i, [])] or [s for v in pool.values() for s in v]
    wc = [r for t in topics for r in (woz or {}).get(t, [])]
    if wc and cands and n >= 2:
        return rnd.sample(cands, 1) + rnd.sample(wc, 1)
    return rnd.sample(cands, min(n, len(cands))) if cands else []


def _ref_text(s, max_turns=6, max_len=120):
    lines = []
    for t in s["turns"][:max_turns]:
        who = "游客" if t["role"] == "游客" else "客服"
        txt = re.sub(r"\s+", " ", t["text"] or "")
        lines.append(f"{who}：{txt[:max_len]}{'…' if len(txt) > max_len else ''}")
    return "\n".join(lines)


# ---------------------------------------------------------------- 提示词 / 质检
def plan_job(row, topic, variant, ctx, seed):
    """确定这一条用哪些资料、哪个人设 / 渠道 / 情境、参考哪几通真实对话（同一 key 每次都一样，可复现）。"""
    rnd = _seeded(seed, "expand", row["_id"], topic, variant)
    pool, woz = ctx["pool"], ctx.get("woz")
    if topic.startswith("culture@"):
        u = ctx["by_id"][topic.split("@", 1)[1]]
        facts, seen = {}, {}
        for f in u["facts"]:
            k = f["attr"] or "资料"
            seen[k] = seen.get(k, 0) + 1
            facts[k if seen[k] == 1 else f"{k}（{seen[k]}）"] = f["value"]
        meta = dict(CULTURE, name=f"景点讲解（{u['spot']}）")
        qs = rnd.sample(ctx["red_q"], min(3, len(ctx["red_q"]))) if ctx.get("red_q") else []
        return dict(rnd=rnd, topic=topic, parts=["culture"], meta=meta, facts=facts, unit=u, persona=rnd.choice(PERSONAS), channel=rnd.choice(CHANNELS),
                    situation=rnd.choice(CULTURE["situations"]), refs=pick_refs(pool, CULTURE["refs"], rnd, 2), red_q=qs)  # 讲解类不用 RiSAWOZ / CrossWOZ（那些是推荐 / 查询类对话）
    if topic == "mixed":
        have = [t for t in TOPICS if topic_facts(row, t)]
        parts = rnd.sample(have, min(len(have), rnd.choice([2, 2, 3])))
        meta = dict(MIXED, name="综合咨询（" + "、".join(TOPICS[p]["name"] for p in parts) + "）")
        facts = {}
        for p in parts:
            facts.update(topic_facts(row, p))
        refs_intents = [i for p in parts for i in TOPICS[p]["refs"]]
    else:
        parts, meta = [topic], TOPICS[topic]
        facts = topic_facts(row, topic)
        refs_intents = meta["refs"]
    return dict(rnd=rnd, topic=topic, parts=parts, meta=meta, facts=facts, persona=rnd.choice(PERSONAS), channel=rnd.choice(CHANNELS),
                situation=rnd.choice(meta["situations"]), refs=pick_refs(pool, refs_intents, rnd, 2, woz, parts))


def build_prompt(row, plan):
    name = row["_name"]
    place = []
    for x in [row.get("province_name"), row.get("city_name"), row.get("district_name")]:
        if not _blank(x) and str(x) not in place:  # 直辖市省 = 市，不重复
            place.append(str(x))
    place = "".join(place)
    facts = "\n".join(f"- {LABELS.get(k, k)}：{v}" for k, v in plan["facts"].items())
    refs = "\n\n".join(f"参考 {i}（{s.get('dataset') or ''} · {s['intent'] or '其他'}）：\n{_ref_text(s)}" for i, s in enumerate(plan["refs"], 1)) or "（无）"
    u = plan.get("unit")
    if u:
        head = f"本次主题：讲解「{u['spot']}」" + (f"（{u['relation']}）" if u.get("relation") else "") + (f"——{u['title'] or u['topic']}" if (u.get("title") or u.get("topic")) else "")
        facts_hd = "【讲解资料】（整理自官网、博物馆、政府等公开资料，客服回答只能用这里的信息）"
        extra = (f"\n范围说明：{u['scope']}" if u.get("scope") else "") + (
            "\n\n【游客可能这样问】（其他景点的真实提问，只学问法）\n" + "\n".join(f"- {q}" for q in plan.get("red_q") or []) if plan.get("red_q") else "")
        rule8 = ("\n8. 这是讲解类咨询：客服用自己的话把资料讲清楚、讲生动，可以分几条说；不要说「据某某文章 / 官网 / 报道」这类出处话术；"
                 "资料里的口径（「约」「五百多」「相传」）原样保留，不要改成确数，不要补充资料外的年代、尺寸、人物。")
    else:
        head, facts_hd, extra, rule8 = f"本次主题：{plan['meta']['name']}", "【景区资料】（来自景区基础数据表，客服回答只能用这里的信息）", "", ""
    return f"""你在做「景区在线客服对话」训练数据。请为「{name}」（{place}）生成一通在线客服会话。

渠道：{plan['channel']}
{head}
游客人设：{plan['persona']}
游客情境：{plan['situation']}

{facts_hd}
{facts}{extra}

【参考对话】（其他景区的真实客服对话，只学游客怎么问、怎么追问，客服怎么接话；里面的景区名、价格、时间、政策一律不能用）
{refs}

要求：
1. 客服说的每个事实（价格、时间、电话、地址、政策、设施、景点名、年代、尺寸…）都必须来自上面的资料，数字原样使用；资料里没有的，客服说「这个以景区官方公告为准」或「帮您转人工确认」，不要编。
2. 游客的问题围绕本次主题，主要问资料能回答的；最多有 1 个追问是资料里没有的。不要问别的景区。
3. 游客口语化、贴合人设和情境，可以拆成多条消息、追问、催促（如「在吗」）、发表情；不要照抄参考对话的原句。
4. 客服用官方客服口吻（「您好」「亲」等），可以分几条说；第一条可以是机器人（robot）自动接待，之后由人工（human）回复，也可以全程机器人。
5. 资料里有票价时可以用一条 msg_type 为 card 的卡片消息，如「[门票卡片] 成人票 ¥60」，内容必须是资料里的。
6. 4～10 条消息；景区名写「{name}」；不要提「携程」「网友」「资料」「数据表」。
7. gap_sec 是这条消息距离上一条的秒数（游客 3～60 秒，客服 5～90 秒，第一条为 0）。{rule8}

只输出一个 JSON 对象，不要其他文字：
{{"turns":[{{"role":"user或agent","agent_type":"robot或human（仅 agent 填）","msg_type":"text或card","text":"内容","gap_sec":整数}}],
 "end_type":"{'/'.join(END_TYPES)} 之一","satisfaction_score":null或1到5的整数,"is_resolved":true或false}}"""


NUM_UNIT_RE = re.compile(r"\d+(?:\.\d+)?\s*(?:年|米|平方米|平方公里|亩|公里|千米|件|座|尊|层|窟|间|万|余|多)")
PHONE_RE = re.compile(r"\d{3,4}-?\d{7,8}|1\d{10}|400-?\d{3}-?\d{4}")


def quality_flags(row, plan, rec):
    """客服说的金额 / 时间 / 电话，景区资料里没有 → 可能是编的；提到参考对话里的景区名 → 串了别的景区。"""
    facts_text = " ".join(str(v) for v in plan["facts"].values()) + " " + " ".join(str(row.get(c) or "") for c in plan["facts"])
    norm = lambda s: re.sub(r"\s|¥|￥|元", "", s)  # noqa: E731
    nums = set(re.findall(r"\d+(?:\.\d+)?", facts_text))
    times = {m.replace("：", ":") for m in TIME_RE.findall(facts_text)}
    flags = []
    own = (row["_name"] or "") + " " + " ".join(str(v) for v in plan["facts"].values())
    others = {(s["attraction_name"], cs_synth._short(s.get("city"))) for s in plan["refs"]
              if s["attraction_name"] and s["attraction_name"] not in own}
    others |= {(n, "") for s in plan["refs"] for n in s.get("names") or [] if n and n not in own}
    for t in rec["turns"]:
        for o, city in others:  # 游客、客服都不该提别的景区
            for core in {cs_synth._core(o), cs_synth._core(o, (city,))}:  # 「上海欢乐谷」也查「欢乐谷」
                if len(core) >= 3 and core in t["text"] and core not in own:
                    flags.append(f"提到了参考对话里的「{o}」")
        if t["role"] != "agent":
            continue
        for m in MONEY_RE.findall(t["text"]):
            if norm(m) not in nums:
                flags.append(f"金额「{m.strip()}」资料里没有")
        for m in TIME_RE.findall(t["text"]):
            mm = m.replace("：", ":")
            if mm not in times and mm.lstrip("0") not in times:
                flags.append(f"时间「{m}」资料里没有")
        for m in PHONE_RE.findall(t["text"]):
            if m.replace("-", "") not in facts_text.replace("-", ""):
                flags.append(f"电话「{m}」资料里没有")
        if plan.get("unit"):  # 讲解类：年代、尺寸、数量这些数字也要在资料里
            for m in NUM_UNIT_RE.findall(t["text"]):
                num = re.match(r"\d+(?:\.\d+)?", m).group(0)
                if num not in nums:
                    flags.append(f"数字「{m}」资料里没有")
    return sorted(set(flags))


def assemble(row, plan, variant, js, cfg, table):
    meta = plan["meta"]
    need_order = meta["scene"] == "预订购票" and plan["rnd"].random() < 0.5
    rec = cs_synth.build_session(js, plan["rnd"], f"expand|{row['_id']}|{plan['topic']}|{variant}", need_order, row["_id"], row["_name"], id_digits=10)
    flags = quality_flags(row, plan, rec)
    rec["source"] = dict(generate_method="llm_expand", scenic_table=table, scenic_id=row["_id"], scenic_name=row["_name"], scenic_city=row["_city"],
                         scenic_update_time=str(row.get("update_time") or "") or None, topic=plan["topic"], topic_name=meta["name"],
                         intent_type=meta["intent"], scene_type=meta["scene"], fact_fields=list(plan["facts"]),
                         facts={LABELS.get(k, k): v for k, v in plan["facts"].items()},
                         style_refs=[dict(dialogue_id=s["id"], dataset=s.get("dataset"), attraction_name=s["attraction_name"] or None,
                                          intent_type=s["intent"]) for s in plan["refs"]],
                         situation=plan["situation"], variant=variant, model=cfg.get("ai_model"), prompt_version=PROMPT_VERSION,
                         generated_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"), is_resolved=bool(js.get("is_resolved")),
                         needs_review=bool(flags), check_flags=flags)
    u = plan.get("unit")
    if u:  # 讲解类：用的是哪条讲解资料、哪几条事实、出处网址
        rec["source"].update(topic="culture", fact_fields=[f["seq"] for f in u["facts"]],
                             knowledge=dict(kind={"guide": "景区讲解包", "redqa": "RedAttractionQA"}[u["kind"]], unit_id=u["unit_id"], batch=u.get("batch"),
                                            spot=u["spot"], relation=u.get("relation"), title=u.get("title"), guide_topic=u.get("topic"),
                                            sources=u["sources"]),
                             example_questions=plan.get("red_q") or [])
    return rec


# ---------------------------------------------------------------- 预估 / 运行
def _topics(args):
    t = [x.strip() for x in (getattr(args, "topics", "") or "").split(",") if x.strip() in ALL_TOPICS]
    return t or ALL_TOPICS


def preview(args, log=print):
    """不调模型：多少景区、每个主题多少景区有资料（景点讲解为讲解资料条数）、按每主题几版一共能生成多少。"""
    rows = load_scenics(args, log)
    topics = _topics(args)
    ctx = load_context(args, rows, log)
    per = {t: 0 for t in topics}
    for r in rows:
        for t in available(r, topics, ctx):
            per[t.split("@")[0]] += 1
    pairs = sum(per.values())
    v = max(1, int(getattr(args, "variants", 1) or 1))
    total = pairs * v
    sample = None
    for r in rows:
        have = [t for t in available(r, topics, ctx) if not t.startswith("culture@")]
        if len(have) >= 3:
            sample = dict(scenic_id=r["_id"], scenic_name=r["_name"], city=r["_city"],
                          topics={TOPICS[t]["name"]: {LABELS.get(k, k): x for k, x in topic_facts(r, t).items()} for t in have if t != "mixed"})
            break
    lim = int(getattr(args, "limit", 0) or 0)
    names = dict({k: x["name"] for k, x in TOPICS.items()}, mixed=MIXED["name"], culture="景点讲解（讲解资料条数）")
    return dict(mode="expand", scenics=len(rows), by_topic=[dict(topic=t, name=names[t], scenics=per[t]) for t in topics],
                pairs=pairs, variants=v, total=total, this_run=min(total, lim) if lim else total, sample=sample, sources=ctx["stats"])


def _done_keys(out):
    """已生成的「景区|主题|版」：本次输出目录 + out/ 下所有 cs_expand_* 批次（跨天续跑不重复）。"""
    keys = set()
    for d in {out, *OUT_ROOT.glob("cs_expand_*")}:
        f = d / "done_keys.txt"
        if f.exists():
            keys.update(f.read_text(encoding="utf-8").split())
    return keys


def write_stats(out, stats):
    try:
        (out / "_stats.json").write_text(json.dumps(stats, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass


def run(args, cfg, log=print, should_stop=lambda: False, progress=lambda done, total: None, on_item=lambda item: None):
    import db
    table = db.SCENIC_TABLE.strip("`")
    rows = load_scenics(args, log)
    topics = _topics(args)
    ctx = load_context(args, rows, log)
    variants = max(1, int(args.variants or 1))
    out = Path(args.out) if args.out else OUT_ROOT / f"cs_expand_{time.strftime('%Y%m%d')}"
    out.mkdir(parents=True, exist_ok=True)
    done = _done_keys(out)
    rnd0 = _seeded(args.seed, "order")
    rows = rows[:]
    rnd0.shuffle(rows)  # 限量时也能分散到各个景区
    avail = [(r, available(r, topics, ctx)) for r in rows]
    # 先每个（景区, 主题）各出第 1 版，再出第 2 版……：随时停下，覆盖面都是最广的
    plan_keys = [(r, t, v) for v in range(1, variants + 1) for r, have in avail for t in have]
    todo = [(r, t, v) for r, t, v in plan_keys if f"{r['_id']}|{t}|{v}" not in done]
    n_left = len(todo)
    if args.limit:
        todo = todo[: args.limit]
    log(f"可生成 {len(plan_keys)} 条（{len(rows)} 个景区 × 有资料的主题 × {variants} 版），已生成 {len(plan_keys) - n_left} 条，"
        f"本次 {len(todo)} 条，并发 {args.workers}，输出到 {out}")

    f_dlg, f_map, f_rej = out / "dialogs.jsonl", out / "mapping.csv", out / "rejected.jsonl"
    f_sc, f_src, f_done = out / "scenic_extract.jsonl", out / "source_extract.jsonl", out / "done_keys.txt"
    f_kn = out / "knowledge_extract.jsonl"
    have_kn = {json.loads(x)["unit_id"] for x in f_kn.read_text(encoding="utf-8").splitlines() if x.strip()} if f_kn.exists() else set()
    have_sc = {json.loads(x)["scenic_id"] for x in f_sc.read_text(encoding="utf-8").splitlines() if x.strip()} if f_sc.exists() else set()
    have_src = {json.loads(x)["dialogue_id"] for x in f_src.read_text(encoding="utf-8").splitlines() if x.strip()} if f_src.exists() else set()
    new_map = not f_map.exists()
    fm = f_map.open("a", encoding="utf-8-sig" if new_map else "utf-8", newline="")
    mw = csv.writer(fm)
    if new_map:
        mw.writerow(["session_id", "scenic_id", "scenic_name", "topic", "variant", "style_ref_ids", "turns", "needs_review", "check_flags", "model", "generated_at"])
    conn = None
    if args.mysql:
        cs_synth.mysql_check()

    def write_mysql(rec):
        nonlocal conn
        import pymysql
        for attempt in (1, 2):
            try:
                if conn is None:
                    conn = pymysql.connect(**db.DB)
                with conn.cursor() as cur:
                    cs_synth.mysql_write(cur, rec)
                return None
            except Exception as e:  # noqa: BLE001
                conn = None
                if attempt == 2:
                    return f"{type(e).__name__}: {e}"

    stats = dict(ok=0, review=0, rejected=0, failed=0, cancelled=0, total=len(todo), out=str(out), mode="expand")
    progress(0, len(todo))
    lock = threading.Lock()

    def one(row, topic, v):
        if should_stop():
            return ("cancelled", row, topic, v, None, dict(error="已停止"), None)
        plan = plan_job(row, topic, v, ctx, args.seed)
        prompt = build_prompt(row, plan)
        ex_ = dict(prompt=prompt, persona=plan["persona"], channel=plan["channel"], situation=plan["situation"], started=time.strftime("%H:%M:%S"))
        t0 = time.time()
        try:
            text, elapsed, meta = ai_judge.call(cfg, prompt)
        except ai_judge.AIError as e:
            return ("failed", row, topic, v, plan, dict(error=str(e), http_status=e.http_status, request_id=e.request_id), dict(ex_, elapsed=round(time.time() - t0, 1)))
        ex_.update(response=text, elapsed=elapsed, request_id=meta.get("request_id"))
        try:
            rec = assemble(row, plan, v, ai_judge.parse(text), cfg, table)
            rec["channel"] = plan["channel"]
            rec = {k: rec[k] for k in ["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns",
                                       "end_type", "satisfaction_score", "session_duration_sec", "source"]}
            rec["source"].update(persona=plan["persona"], elapsed=round(time.time() - t0, 1), request_id=meta.get("request_id"))
            return ("ok", row, topic, v, plan, rec, ex_)
        except Exception as e:  # noqa: BLE001
            return ("rejected", row, topic, v, plan, dict(error=f"{type(e).__name__}: {e}", raw=text[:2000]), ex_)

    def handle(n, res):
        kind, row, topic, v, plan, rec, ex_ = res
        if kind == "cancelled":
            stats["cancelled"] += 1
            return
        key = f"{row['_id']}|{topic}|{v}"
        if kind == "ok":
            if row["_id"] not in have_sc:  # 用到的景区表整行，每个景区写一次
                with f_sc.open("a", encoding="utf-8") as f:
                    f.write(json.dumps(dict(scenic_id=row["_id"], table=table, row={k: (str(x) if x is not None else None) for k, x in row.items()
                                                                                       if not k.startswith("_")}), ensure_ascii=False) + "\n")
                have_sc.add(row["_id"])
            for s in plan["refs"]:  # 参考的真实对话，每通写一次
                if s["id"] not in have_src:
                    with f_src.open("a", encoding="utf-8") as f:
                        f.write(json.dumps(dict(dialogue_id=s["id"], dataset=s.get("dataset"), row=s.get("row"), turns=s["turns"]), ensure_ascii=False) + "\n")
                    have_src.add(s["id"])
            u = plan.get("unit")
            if u and u["unit_id"] not in have_kn:  # 用到的讲解资料（事实 + 出处），每条写一次
                with f_kn.open("a", encoding="utf-8") as f:
                    f.write(json.dumps(dict(u, scenic_id=row["_id"]), ensure_ascii=False) + "\n")
                have_kn.add(u["unit_id"])
            with f_dlg.open("a", encoding="utf-8") as f:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            g = rec["source"]
            mw.writerow([rec["session_id"], rec["scenic_id"], rec["scenic_name"], g["topic_name"], v, ",".join(x["dialogue_id"] for x in g["style_refs"]),
                         len(rec["turns"]), int(g["needs_review"]), "；".join(g["check_flags"]), g["model"], g["generated_at"]])
            fm.flush()
            with f_done.open("a", encoding="utf-8") as f:
                f.write(key + "\n")
            if args.mysql:
                err = write_mysql(rec)
                if err:
                    log(f"  写 MySQL 失败 {rec['session_id']}：{err}（JSONL 已保存，可稍后「写入 MySQL」补写）")
            stats["ok"] += 1
            stats["review"] += int(g["needs_review"])
        else:
            with f_rej.open("a", encoding="utf-8") as f:
                f.write(json.dumps(dict(key=key, scenic_id=row["_id"], topic=topic, variant=v, kind=kind, **rec), ensure_ascii=False) + "\n")
            stats[kind] += 1
            log(f"  [{n}/{len(todo)}] {row['_name']} {topic} 第 {v} 版 {'调用失败' if kind == 'failed' else '不合格'}：{rec.get('error')}")
        src_view = dict(mode="expand", scenic_id=row["_id"], scenic_name=row["_name"], city=row["_city"], topic=topic,
                        topic_name=plan["meta"]["name"] if plan else topic, facts={LABELS.get(k, k): x for k, x in (plan["facts"] if plan else {}).items()},
                        refs=[dict(dialogue_id=s["id"], attraction_name=s["attraction_name"] or s.get("dataset"), intent=s["intent"], turns=s["turns"][:8])
                              for s in (plan["refs"] if plan else [])],
                        knowledge=(dict(spot=plan["unit"]["spot"], title=plan["unit"].get("title"), sources=plan["unit"]["sources"])
                                   if plan and plan.get("unit") else None),
                        red_q=(plan.get("red_q") if plan else None),
                        dialogue_id=row["_id"], attraction_name=row["_name"], intent=plan["meta"]["name"] if plan else topic)
        on_item(dict(kind=kind, variant=v, source=src_view, exchange=ex_, record=rec if kind == "ok" else None,
                     error=None if kind == "ok" else rec.get("error"), mysql=bool(args.mysql)))

    workers = max(1, int(args.workers or 1))
    it = iter(todo)
    n = 0
    with ThreadPoolExecutor(max_workers=workers) as ex:
        pending = set()

        def fill():
            while len(pending) < workers * 2 and not should_stop():
                j = next(it, None)
                if j is None:
                    return
                pending.add(ex.submit(one, *j))
        fill()
        while pending:
            finished, pending = wait(pending, return_when=FIRST_COMPLETED)
            for fut in finished:
                n += 1
                with lock:
                    handle(n, fut.result())
                    progress(n, len(todo))
                    if n % 20 == 0 or n == len(todo):
                        write_stats(out, stats)
                    if n % 50 == 0:
                        log(f"  进度 {n}/{len(todo)}：成功 {stats['ok']}（需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}")
            fill()
    stats["cancelled"] += len(todo) - n
    fm.close()
    if conn is not None:
        conn.close()
    write_stats(out, stats)
    log(f"完成：成功 {stats['ok']}（其中需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}"
        + (f"，停止前未处理 {stats['cancelled']}" if stats["cancelled"] else "") + f"。\n  输出：{out}")
    return stats


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", default=str(cs_synth.DATA_DIR), help="资料目录（客服对话包、讲解包、RedAttractionQA、对话数据集提取），默认仓库里的 data/")
    ap.add_argument("--out", default="", help="输出目录，默认 out/cs_expand_<今天>（断点续跑要用同一个目录）")
    ap.add_argument("--topics", default="", help="主题，逗号分隔：" + ",".join(ALL_TOPICS) + "；默认全部")
    ap.add_argument("--scenic", default="", help="只要这些景区（景区ID 或名称，逗号分隔）")
    ap.add_argument("--scenic-city", default="", help="只要这些城市的景区（如 北京市）")
    ap.add_argument("--grade", default="", help="只要这些等级（如 5A,4A）")
    ap.add_argument("--only-approved", action="store_true", help="只要已审核（approval=1）的景区")
    ap.add_argument("--variants", type=int, default=1, help="每个景区每个主题生成几版，默认 1")
    ap.add_argument("--limit", type=int, default=20, help="本次最多生成几条（0 = 不限），默认 20")
    ap.add_argument("--workers", type=int, default=3, help="并发请求数，默认 3")
    ap.add_argument("--mysql", action="store_true", help=f"同时写进 MySQL：{cs_synth.SESSION_TABLE} / {cs_synth.TURN_TABLE}")
    ap.add_argument("--preview", action="store_true", help="只预估能生成多少，不调模型")
    ap.add_argument("--profile", default=str(cs_synth.HERE / ".pw-profile-service"), help="读 AI 设置的浏览器目录（数据库里有设置时以数据库为准）")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    if args.preview:
        import sys
        print(json.dumps(preview(args, log=lambda m: print(m, file=sys.stderr)), ensure_ascii=False, indent=2))
        return 0
    import review
    cfg = ai_judge.config(review.DbPrefs(Path(args.profile) / "hq_prefs.json", readonly=True))
    if not cfg.get("ai_api_key"):
        raise SystemExit("没有 AI 的 API Key：在工作台「设置 → AI 判断」里填，或设置环境变量 ARK_API_KEY")
    stats = run(args, cfg, log=lambda m: print(m, flush=True))
    return 0 if stats["ok"] or not stats["total"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
