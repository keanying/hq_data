"""已交付训练数据的修正：智能客服对话（客服会话）/ 个性化讲解。

======================================================================== 完整命令
（在 tools/ctrip_poi_review 目录下执行；数据默认读 tools/q_data，不用 --in）

数据放法：tools/q_data/客服会话.json、tools/q_data/个性化讲解.json（解压出来的，优先用）
  或 tools/q_data/客服会话.zip、个性化讲解.zip（不用解压，压缩包里的中文文件名乱码也没关系）；
  .json（数组）/ .jsonl / .csv 都行：
  - JSON / JSONL：一行（一个元素）一条，字段和工作台导出的「完整 JSON」一致（含 source）
  - CSV：① 工作台导出的讲解 CSV（带 record_json 列）；② 客服的会话表 CSV + 轮次表 CSV（两张一起放）；
         ③ 一行一条、嵌套字段（turns / poi / source …）是 JSON 字符串的 CSV
  查找顺序：<名称>.json / .jsonl / .csv → <名称>/ 目录 → <名称>.zip。解压出来的大文件已在 .gitignore（超过 GitHub 100MB，别提交）。

  cd tools/ctrip_poi_review

  # 0. 查配置：方舟 Key 从哪来（打码）、模型、联网开没开，并试调一次
  python data_fix.py check
  python data_fix.py check --step enrich

  # 1. 只诊断、不调模型：每类问题多少条、要调多少次模型
  python data_fix.py scan --task cs
  python data_fix.py scan --task narr --rebalance-limits --relabel-scene

  # 2. 小批试跑（两份数据排队跑，各 200 条），抽查 out/fix_cs、out/fix_narr 里的 fixed.json 和 report.md
  python data_fix.py all --limit 200 --workers 8

  # 3. 全量排队：客服会话修正 → 个性化讲解修正（一份跑完再跑下一份，带进度条；中断后再执行同一条命令接着跑）
  python data_fix.py all --workers 32 --rebalance-limits --relabel-scene

  # 3'. 全量排队 + 讲解知识补充：客服会话修正 → 讲解知识补充（联网，带出处）→ 个性化讲解修正（用补充后的知识，含 500 字档）
  python data_fix.py all --workers 32 --enrich --rebalance-limits --relabel-scene

  # 指定模型（不填用工作台设置页的模型）、只跑一份
  python data_fix.py all --model <方舟模型ID或接入点ID> --tasks cs --workers 32
  python data_fix.py all --model <方舟模型ID或接入点ID> --tasks narr --enrich --workers 32

  # 单步（需要时）
  python data_fix.py run    --task cs   --workers 32
  python data_fix.py enrich --workers 32
  python data_fix.py run    --task narr --workers 32 --kb-ext out/fix_narr/kb_ext.jsonl --rebalance-limits --relabel-scene
  python data_fix.py merge  --task cs                     # 只重新合并导出（run / all 结束会自动合并）
  python data_fix.py run    --task cs --in D:/data/客服会话.zip   # 用别处的数据

  后台跑、把进度写进日志（Linux / Mac）：
  mkdir -p out && nohup python data_fix.py all --workers 32 --rebalance-limits --relabel-scene > out/fix_all.log 2>&1 &
  tail -f out/fix_all.log

======================================================================== 输出
  原始输入（tools/q_data 下的文件）不改。all 跑完把最终结果汇总到 out/final/：
    客服会话_修正后.json、个性化讲解_修正后.json   全量数据，结构和输入完全一致（含 source；没改的原样保留，剔除的不在里面）
    *_修正记录.jsonl                               每条改了什么（按 ID 对应，不写进数据本身）
    *_改动对照.jsonl                               抽样的原文 / 修正后并排（评估用）
    *_标注交付L1.jsonl、*_溯源sidecar.jsonl        标注交付用
    *_剔除.jsonl、*_修正报告.md、讲解知识补充.jsonl、总报告.md
  过程文件在 out/fix_cs/、out/fix_narr/（固定目录，断点续跑靠它；要从头来就删掉对应目录）：
    fixed.json           修好的全量数据，结构和输入一致（含 source）；合并时自动做结构检查，不一致的写 structure_diff.jsonl
    fix_log.jsonl        修正记录；compare.jsonl 改动对照
    fixed_l1.jsonl       标注交付 L1（不含答案 / 溯源）
    fixed_sidecar.jsonl  溯源 sidecar（同一个 ID 关联）
    dropped.jsonl        剔除的（带原因）；invalid.jsonl 输入里格式不对、跳过的
    report.md / .json    修正前后对比
    results.jsonl        调过模型的结果（断点续跑用，别删）；diagnose.jsonl / scan.json 诊断
    kb_ext.jsonl         （fix_narr）知识补充结果

======================================================================== 做什么
诊断每一条 → 规则能修的程序直接修 → 需要改写的交给火山方舟（只改有问题的消息 / 句子）
→ 用和生成时同一套质检（cs_expand.quality_flags、cs_synth.session_checks、guide_synth.narr_check）再查一遍
→ 不过关的带着问题再问一次 → 还不过：编造事实 / 订单状态、乱码、超字数这类剔除，其余标 needs_review 交给标注。
各类问题怎么修见 README 第 15 节。

======================================================================== 配置
方舟：和工作台、cs_expand / guide_synth 一样读工作台「设置 → AI 判断」（MySQL 表 hq_app_settings，
连不上库时读 .pw-profile-service/hq_prefs.json），没有再用环境变量 ARK_API_KEY。
--model 指定这次用的模型（不填：ARK_MODEL，再不填用设置页的）；ARK_BASE_URL 可覆盖接口地址。
联网搜索按步骤：修正默认关、知识补充默认开；--web-search on|off，或环境变量 DATA_FIX_WEB_SEARCH / DATA_FIX_ENRICH_WEB_SEARCH。
"""
import argparse
import copy
import hashlib
import json
import os
import re
import sys
import threading
import time
from collections import Counter
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime, timedelta
from pathlib import Path

import ai_judge
import cs_expand
import cs_synth
import guide_synth

FIX_VERSION = "data_fix_v1"
HERE = Path(__file__).resolve().parent


def _h(*parts):
    """稳定的 0~1 随机数（同一条数据每次一样，结果可复现）。"""
    return int(hashlib.md5("|".join(map(str, parts)).encode("utf-8")).hexdigest()[:8], 16) / 0xFFFFFFFF


# ================================================================ 客服会话
DEFLECT_RE = re.compile(r"以景区官方(?:公告|答复|通知|信息)?为准|以官方(?:公告|答复)为准|转人工|人工(?:客服)?(?:帮您|为您)?(?:确认|核实)|"
                        r"建议您?(?:拨打|致电|咨询)|不能随意答复|暂时没有(?:这方面的)?信息|没有收录")
LEAK_RE = re.compile(r"资料|数据表|知识库|携程|网友|参考对话")
# 客服说「查到了 / 已经办好了」这类订单结果（「预约成功后凭身份证入园」这种规则说明不算）
CLAIM_RE = re.compile(r"(?:帮您|为您|已)?查(?:询)?到(?:了)?(?:您的|您|这个|该)?(?:订单|预约|票)|您的(?:订单|预约|票)(?:已|状态|正常|有效|没问题)|"
                      r"已(?:经)?(?:为您)?(?:出票|核销|退款|退票|改期|改签|办理)(?!后|的话|规则|政策)|预约(?:已经?)?成功(?!后|的话)|出票成功(?!后|的话)|"
                      r"退款(?:成功|已到账)|改(?:期|签)成功(?!后)|已为您(?:办理|退|改)")
OVERCLAIM_RE = re.compile(r"退款(?:成功|已到账|已退回)|已(?:经)?(?:退款|退回)|改(?:期|签)成功|已(?:经)?(?:改好|改期|改签)(?!申请)|已(?:经)?退票成功")
ASCII_OK = re.compile(r"^(?:A+|APP|App|app|WIFI|WiFi|wifi|VIP|PC|H5|ETC|LED|VR|AR|KTV|SUV|GPS|ID|OK|ok|QQ|AAAA|AAAAA|CBD)$")
ASCII_WORD = re.compile(r"[A-Za-z]{3,}")
NON_FACT_KEYS = {"政策说明", "办理说明"}
TEMPLATE_RE = re.compile(r"以景区官方公告为准|以官方公告为准")
# 套话改写：资料回答不了时客服几乎都说「以景区官方公告为准」（原数据 6.4 万次）。默认把它改成自然、具体的引导，保留约 20% 原句。
DIVERSIFY = dict(on=True, keep=0.2)
OPTS = dict(keep_order_conflict=False)

# 游客问的关键词 → 能回答它的资料条目（cs_expand.LABELS 的中文名）
ASK_MAP = [
    (r"多少钱|票价|价格|几块|收费|免费|门票|优惠|学生票|儿童票|老人票|半价|联票|套票",
     ["成人票（平日）", "成人票（旺季）", "成人票（淡季）", "优惠票", "是否免费", "联票 / 套票", "景区交通票"]),
    (r"几点|开门|关门|开放|营业|入园|闭园|时间", ["旺季开门", "旺季关门", "淡季开门", "淡季关门", "最晚入园", "开放状态", "特殊开放规则"]),
    (r"预约|提前|买票|购票|线上|网上", ["可提前预约天数", "能否线上购票", "每日最大承载量"]),
    (r"停车|车位|自驾|开车", ["有无停车场", "停车位"]),
    (r"地址|在哪|怎么去|怎么走|导航|哪个区", ["地址", "区县"]),
    (r"电话|联系方式|投诉|热线", ["咨询电话", "投诉电话"]),
    (r"讲解|导游|语种|外语|英文", ["有无讲解服务", "讲解语种"]),
    (r"多久|几个小时|时长|半天|一天|安排", ["建议游玩时长"]),
    (r"季节|什么时候|几月|最好.{0,2}时候", ["最佳游玩季节"]),
    (r"景点|看什么|玩什么|好玩|特色|有啥|有什么|值得", ["主要景点", "特色", "景区简介", "景区类型"]),
    (r"几A|等级|几星|面积|占地", ["等级", "面积", "称号"]),
    (r"运营|管理|哪家", ["运营单位"]),
]
ASK_RE = [(re.compile(p), keys) for p, keys in ASK_MAP]

ORDER_STATUS = {  # 意图 → 订单卡片上的状态（订单本身是合成的，状态由程序定，客服只能照卡片说）
    "订单查询": ["已出票，待使用", "已出票，待使用", "出票中"],
    "订单异常": ["出票异常，待人工核查", "已出票，核销失败待核查"],
    "退票办理": ["已出票，待使用（可申请退票）"],
    "改期办理": ["已出票，待使用（可申请改期）"],
    "改签办理": ["已出票，待使用（可申请改签）"],
    "预约购票": ["预约成功，待使用"],
}


def cs_id(rec):
    return rec["session_id"]


def _plan(rec):
    return (rec.get("source") or {}).get("session_plan") or {}


def _facts(rec):
    return {k: v for k, v in ((rec.get("source") or {}).get("facts") or {}).items() if v not in (None, "")}


def _is_free(facts):
    return str(facts.get("是否免费") or "") == "是"


def cs_flags(rec):
    """和生成时同一套质检：资料里没有的金额 / 时间 / 电话 / 数字、提到参考对话的景区、消息条数、订单号、语音、指代、复读。"""
    src = rec.get("source") or {}
    sp = _plan(rec)
    facts = _facts(rec)
    row = {"_name": rec.get("scenic_name") or ""}
    refs = [dict(attraction_name=s.get("attraction_name"), city=None, names=[]) for s in src.get("style_refs") or []]
    order = sp.get("order")
    plan = dict(facts=facts, refs=refs, session=dict(order=order), unit=src.get("knowledge"))
    flags = cs_expand.quality_flags(row, plan, rec)
    p = dict(n=sp.get("target_msgs") or len(rec["turns"]), order=order, noise=sp.get("noise"), coref=sp.get("coref"))
    flags += cs_synth.session_checks(p, {"turns": rec["turns"]}, sp.get("coref_annotation"))
    if _is_free(facts):  # 免费景区说「¥0 / 0 元 / 免费」不算编造
        flags = [f for f in flags if not re.match(r"金额「(?:¥|￥)?\s*0(?:\.0+)?\s*元?」", f)]
    return sorted(set(flags))


def _turn_facts_hit(text, facts, keys):
    """客服这条回复里有没有用到这些资料条目的值（值本身、值里两位以上的数字；是 / 否类看条目名的关键词）。"""
    for k in keys:
        v = str(facts.get(k) or "").strip()
        if not v:
            continue
        if v in ("是", "否"):
            core = re.sub(r"^(?:有无|是否|能否)", "", k)
            if core and core[:2] in text:
                return True
            continue
        if v in text:
            return True
        nums = [n for n in re.findall(r"\d+(?:\.\d+)?", v) if len(n) >= 2]
        if nums and any(n in text for n in nums):
            return True
        parts = [x for x in re.split(r"[,，、；;]", v) if len(x) >= 2]
        if len(parts) >= 2 and sum(x in text for x in parts) >= 1:
            return True
    return False


def unneeded_deflections(rec):
    """客服说「以官方为准 / 转人工」，但游客上一条问的东西资料里其实有、客服附近也没说出来 → 疑似没必要的推脱（交给模型判断要不要改）。"""
    facts = _facts(rec)
    fact_keys = set(facts) - NON_FACT_KEYS
    turns = rec["turns"]
    out = []
    for i, t in enumerate(turns):
        if t["role"] != "agent" or not DEFLECT_RE.search(t["text"]):
            continue
        q = next((turns[j]["text"] for j in range(i - 1, -1, -1) if turns[j]["role"] == "user"), "")
        keys = [k for rx, ks in ASK_RE if rx.search(q) for k in ks
                if k in fact_keys and str(facts[k]).strip() not in ("是", "否") and not re.fullmatch(r"0(?:\.0+)?\s*元?", str(facts[k]).strip())]
        if not keys:  # 只对上「是 / 否」或 0 元这类条目的，资料回答不了具体问题，不算
            continue
        near = " ".join(turns[j]["text"] for j in range(0, min(len(turns), i + 2)) if turns[j]["role"] == "agent")  # 前面已经说过也算
        if not _turn_facts_hit(near, facts, keys):
            out.append(dict(turn=t["turn"], keys=keys[:6]))
    return out


URL_RE = re.compile(r"(?:https?://|www\.)[\w./?=&%#:+~-]+|[\w-]+(?:\.[\w-]+)*\.(?:com|cn|net|org|gov|edu)(?:\.cn)?[\w./?=&%#-]*", re.I)


def _bad_ascii(text, allowed=""):
    """夹英文：去掉网址、资料 / 景区名里原有的英文（如 DIY、SPA）后，还有 3 个字母以上的英文词。"""
    t = URL_RE.sub(" ", text or "")
    return [w for w in ASCII_WORD.findall(t) if not ASCII_OK.match(w) and w.lower() not in allowed.lower()]


def _allowed_ascii(rec):
    return " ".join(str(v) for v in _facts(rec).values()) + " " + str(rec.get("scenic_name") or "")


def cs_diagnose(rec):
    """→ (问题列表 [{code, ...}], 要不要调模型)。code：
    COUNT 消息条数和设定不符（规则：设定改成实际条数） · VOICE 设定有语音但没有（规则：设定改为无）
    FACT 客服说了资料里没有的金额 / 时间 / 电话 / 数字 · OTHER 提到参考对话里的景区 · REPEAT 复读
    ORDERCONFLICT 景区不支持线上购票却有线上订单（规则：剔除） · COREF 设定要指代但没做到 · ORDERID 游客没说出订单号 · ORDER 客服无依据地说订单状态 / 办理结果
    DEFLECT 疑似没必要的推脱 · TEMPLATE 套话「以景区官方公告为准」（改成自然引导） · LEAK 客服提到「资料 / 数据表 / 携程」 · ENG 客服消息夹英文"""
    flags = cs_flags(rec)
    issues = []
    for f in flags:
        if f.startswith("消息条数"):
            issues.append(dict(code="COUNT", detail=f))
        elif f.startswith("设定有语音"):
            issues.append(dict(code="VOICE", detail=f))
        elif re.match(r"(金额|时间|电话|数字)「", f):
            issues.append(dict(code="FACT", detail=f))
        elif f.startswith("提到了参考对话"):
            issues.append(dict(code="OTHER", detail=f))
        elif "复读" in f:
            issues.append(dict(code="REPEAT", detail=f))
        elif "指代" in f:
            issues.append(dict(code="COREF", detail=f))
        elif "订单号" in f:
            issues.append(dict(code="ORDERID", detail=f))
    sp = _plan(rec)
    if rec.get("related_order_id") and str(_facts(rec).get("能否线上购票") or "") == "否":
        issues.append(dict(code="ORDERCONFLICT", detail="景区不支持线上购票，会话里却有线上订单（事实矛盾）"))
    has_card = any(t["msg_type"] == "card" and "[订单信息]" in t["text"] for t in rec["turns"])
    claims = [t["turn"] for t in rec["turns"] if t["role"] == "agent" and t["msg_type"] != "card" and CLAIM_RE.search(t["text"])]
    if claims and not has_card:
        issues.append(dict(code="ORDER", turns=claims, has_order=bool(sp.get("order"))))
    defl = unneeded_deflections(rec)
    for d in defl:
        issues.append(dict(code="DEFLECT", **d))
    if DIVERSIFY["on"]:
        skip = {d["turn"] for d in defl}
        for t in rec["turns"]:
            if t["role"] == "agent" and t["turn"] not in skip and TEMPLATE_RE.search(t["text"]) and _h(rec["session_id"], t["turn"], "keep") >= DIVERSIFY["keep"]:
                issues.append(dict(code="TEMPLATE", turn=t["turn"]))
    allowed = _allowed_ascii(rec)
    for t in rec["turns"]:
        if t["role"] != "agent":
            continue
        if LEAK_RE.search(t["text"]):
            issues.append(dict(code="LEAK", turn=t["turn"], word=LEAK_RE.search(t["text"]).group(0)))
        if _bad_ascii(t["text"], allowed):
            issues.append(dict(code="ENG", turn=t["turn"], words=_bad_ascii(t["text"], allowed)[:3]))
    need_llm = any(i["code"] not in ("COUNT", "VOICE", "ORDERCONFLICT") for i in issues)
    return issues, need_llm


def _ts_add(ts, sec):
    try:
        t = datetime.strptime(ts, "%H:%M:%S") + timedelta(seconds=sec)
        return t.strftime("%H:%M:%S")
    except (TypeError, ValueError):
        return ts


def _renumber(rec, inserted_at=None):
    for i, t in enumerate(rec["turns"], 1):
        t["turn"] = i
    if inserted_at is not None:
        sp = _plan(rec)
        for c in sp.get("coref_annotation") or []:
            for k in ("turn", "ref_turn"):
                try:
                    if int(c.get(k)) >= inserted_at:
                        c[k] = int(c[k]) + 1
                except (TypeError, ValueError):
                    pass


def cs_order_card(rec, issue):
    """订单类：在客服第一次说订单状态之前插一张「订单信息」卡片（相当于系统查询结果），状态由程序按意图定。"""
    sp = _plan(rec)
    o = sp.get("order")
    if not o:
        return None
    src = rec["source"]
    intent = src.get("intent_type") or ""
    opts = ORDER_STATUS.get(intent) or ["已出票，待使用"]
    status = opts[int(_h(rec["session_id"], "status") * len(opts)) % len(opts)]
    text = f"[订单信息] 订单号 {o['order_id']}｜{o.get('ticket') or '门票'} × {o.get('qty') or 1}｜游玩日期 {o.get('visit_date') or '—'}｜状态：{status}"
    first = min(issue["turns"])
    idx = next(i for i, t in enumerate(rec["turns"]) if t["turn"] == first)  # 卡片插在客服第一次说订单结果之前
    nxt = rec["turns"][idx]
    prev_ts = rec["turns"][idx - 1]["ts"] if idx > 0 else nxt["ts"]
    card = dict(turn=0, role="agent", msg_type="card", text=text, ts=_ts_add(prev_ts, 3) if _ts_add(prev_ts, 3) <= nxt["ts"] else nxt["ts"],
                agent_id=nxt.get("agent_id") or "ROBOT")
    rec["turns"].insert(idx, card)
    _renumber(rec, inserted_at=first)
    sp["target_msgs"] = (sp.get("target_msgs") or len(rec["turns"]) - 1) + 1
    return dict(card_turn=first, status=status)


def cs_prepare(rec, ctx):
    """规则修 + 订单卡片插入（确定性的，合并时重放结果一样）。→ (rec2, issues, need_llm, log)"""
    r = copy.deepcopy(rec)
    issues, need_llm = cs_diagnose(r)
    log = []
    sp = _plan(r)
    if any(i["code"] == "ORDERCONFLICT" for i in issues):
        if not OPTS["keep_order_conflict"]:
            r["_drop"] = ["景区不支持线上购票，会话里却有线上订单（事实矛盾）"]
            return r, issues, False, ["规则：剔除（订单与「不支持线上购票」矛盾）"]
        log.append("保留：订单与「不支持线上购票」矛盾（--keep-order-conflict），标需复核")
    for i in issues:
        if i["code"] == "VOICE":
            sp["noise"] = None
            log.append("规则：设定的语音消息没写出来，设定改为无")
    for i in issues:
        if i["code"] == "ORDER" and i["has_order"]:
            c = cs_order_card(r, i)
            if c:
                at = c["card_turn"]
                for j in issues:  # 插了一条，后面的序号都要往后挪
                    if "turn" in j and j["turn"] >= at:
                        j["turn"] += 1
                    if j.get("turns"):
                        j["turns"] = [x + 1 if x >= at else x for x in j["turns"]]
                i.update(c)
                log.append(f"规则：第 {at} 条插入订单信息卡片（状态：{c['status']}）")
            break
    if any(i["code"] == "COUNT" for i in issues) or any(i["code"] == "ORDER" and i.get("card_turn") for i in issues):
        if abs(len(r["turns"]) - (sp.get("target_msgs") or 0)) > 2:
            log.append(f"规则：设定消息条数 {sp.get('target_msgs')} → 实际 {len(r['turns'])}")
            sp["target_msgs"] = len(r["turns"])
    return r, issues, need_llm, log


def _dialog_text(rec):
    lines = []
    for t in rec["turns"]:
        who = "游客" if t["role"] == "user" else ("客服·机器人" if t.get("agent_id") == "ROBOT" else "客服·人工")
        lines.append(f"[{t['turn']}] {who}（{t['msg_type']}）：{t['text']}")
    return "\n".join(lines)


def cs_prompt(rec, issues, feedback=None):
    facts = _facts(rec)
    fx = "\n".join(f"- {k}：{v}" for k, v in facts.items()) or "（无）"
    sp = _plan(rec)
    todo, user_ok = [], set()
    for i in issues:
        c = i["code"]
        if c == "FACT":
            todo.append(f"- {i['detail']}：把客服这句改成只用【景区资料】里的数字；资料里没有的就不要给具体数，换成引导（见规则 3）。")
        elif c == "OTHER":
            todo.append(f"- {i['detail']}：去掉别的景区名，游客和客服都只谈「{rec['scenic_name']}」。")
        elif c == "REPEAT":
            todo.append(f"- {i['detail']}：去掉重复的片段。")
        elif c == "DEFLECT":
            todo.append(f"- 第 {i['turn']} 条客服推脱了，但游客上一条问的内容资料里可能有（相关条目：{'、'.join(i['keys'])}）："
                        "资料能回答就直接用资料回答；资料确实回答不了，就保留引导，但换一种自然说法。")
        elif c == "TEMPLATE":
            todo.append(f"- 第 {i['turn']} 条客服用了套话「以景区官方公告为准」：资料能回答就直接回答；回答不了就换一种自然、具体的引导"
                        "（资料里有咨询电话 / 官网 / 官方小程序的可以给出来；没有就说到现场问工作人员、出发前电话确认、帮您记录转同事核实等），不要再用这句套话。")
        elif c == "LEAK":
            todo.append(f"- 第 {i['turn']} 条客服说了「{i['word']}」：客服不能提「资料 / 数据表 / 知识库 / 携程 / 网友」，改成客服自然的说法（如「目前没有查到这方面的公告」）。")
        elif c == "ENG":
            todo.append(f"- 第 {i['turn']} 条客服消息夹了英文（{'、'.join(i['words'])}），改成中文。")
        elif c == "ORDER":
            if i.get("card_turn"):
                todo.append(f"- 第 {i['card_turn']} 条是系统查出的【订单信息卡片】（原样保留，不要改）。客服后面说订单状态只能照卡片说（{i['status']}）；"
                            "退票 / 改期 / 改签类只能说「已帮您提交申请」或「请在订单页操作」，结果以订单页面为准，不承诺退款到账、手续费、时限。")
            else:
                todo.append(f"- 第 {'、'.join(map(str, i['turns']))} 条客服说了订单状态 / 办理结果，但这通会话没有订单信息：改成请游客提供订单号或到订单页查看，不要说查到了什么。")
        elif c == "COREF":
            far = sp.get("coref") == "far"
            todo.append("- 设定要求游客用指代 / 省略" + ("，而且被指的东西要在至少 3 条消息之前出现" if far else "")
                        + "：改写 1 条游客消息（第 2 条游客消息以后），用「那个 / 这个 / 那边 / 它」等指代前面出现过的东西，让人必须回看前文才懂；"
                        "需要的话顺手调整紧接着的客服回复。在 coref 里标出。")
            user_ok |= {t["turn"] for t in rec["turns"] if t["role"] == "user"}
        elif c == "ORDERID":
            o = sp.get("order") or {}
            todo.append(f"- 游客没说出订单号：在游客某条消息里自然地说出订单号 {o.get('order_id')}（票种「{o.get('ticket')}」{o.get('qty')} 张、游玩日期 {o.get('visit_date')}）。")
            user_ok |= {t["turn"] for t in rec["turns"] if t["role"] == "user"}
        if c == "OTHER":
            user_ok |= {t["turn"] for t in rec["turns"] if t["role"] == "user"}
    fb = ("\n\n【上一次改完仍不合格，原因】\n" + "\n".join(f"- {x}" for x in feedback)) if feedback else ""
    who = "游客消息不能改。" if not user_ok else "除上面明确要求的那 1～2 条，游客消息不要改。"
    return f"""你在修正「景区在线客服对话」训练数据。下面是一通「{rec['scenic_name']}」的会话，按【要修的问题】改，其余保持原样。

【景区资料】（客服说的事实只能来自这里，数字原样）
{fx}

【会话】
{_dialog_text(rec)}

【要修的问题】
{chr(10).join(todo)}{fb}

规则：
1. 只改有问题的消息，其余原样；不要增删消息、不要改消息顺序、角色和类型；{who}卡片消息（msg_type 为 card）不要改。
2. 客服说的价格、时间、电话、地址、政策、设施、景点名都必须来自【景区资料】；不要编。
3. 资料确实回答不了时客服可以引导，但要说得自然、每次说法不同，例如「目前没有查到这方面的公告，建议出发前电话确认」「这个需要现场工作人员确认」「帮您记录下来转给同事核实」；不要每条都说「以景区官方公告为准」。
4. 改后的话要和上下文接得上（游客后面的话、结束方式不变），口吻和原来一致。
5. 不要提「携程」「资料」「数据表」「知识库」「网友」。

只输出一个 JSON 对象（字符串里需要引号时用「」，不要用英文双引号）：
{{"edits":[{{"turn":消息序号,"text":"改后的完整内容"}}],"coref":[{{"turn":用指代的消息序号,"ref_turn":被指的东西第一次出现的消息序号,"expr":"指代原话"}}]}}
没有指代任务时 coref 给 []。"""


def cs_apply(rec, issues, js):
    """把模型的 edits 套到会话上（只允许改有问题的那些消息；越权的忽略并记下）。"""
    r = copy.deepcopy(rec)
    codes = {i["code"] for i in issues}
    allow = set()
    for i in issues:
        if "turn" in i:
            allow.add(i["turn"])
        allow |= set(i.get("turns") or [])
    if codes & {"FACT", "OTHER", "REPEAT"}:  # 这几类质检只给了原话，没给序号：客服消息都允许改
        allow |= {t["turn"] for t in r["turns"] if t["role"] == "agent"}
    if "OTHER" in codes or "COREF" in codes or "ORDERID" in codes:
        allow |= {t["turn"] for t in r["turns"] if t["role"] == "user"}
    if "COREF" in codes or "ORDER" in codes or "DEFLECT" in codes:  # 指代、订单、推脱：紧接着的客服回复可能要跟着改
        allow |= {t["turn"] for t in r["turns"] if t["role"] == "agent"}
    by_turn = {t["turn"]: t for t in r["turns"]}
    notes, changed = [], []
    for e in js.get("edits") or []:
        try:
            n = int(e.get("turn"))
        except (TypeError, ValueError):
            continue
        txt = str(e.get("text") or "").strip()
        t = by_turn.get(n)
        if not t or not txt or txt == t["text"]:
            continue
        if t["msg_type"] == "card" or n not in allow:
            notes.append(f"模型改了不该改的第 {n} 条，已忽略")
            continue
        t["text"] = txt
        changed.append(n)
    if "COREF" in codes:
        _plan(r)["coref_annotation"] = [c for c in js.get("coref") or [] if isinstance(c, dict)]
    return r, changed, notes


def cs_validate(before, after, issues):
    """修完的会话还剩哪些问题 → (硬问题, 软问题)。硬问题再不过就剔除；软问题标需复核。"""
    hard, soft = [], []
    flags = cs_flags(after)
    for f in flags:
        if re.match(r"(金额|时间|电话|数字)「", f) or f.startswith("提到了参考对话"):
            hard.append(f)
        elif "指代" in f:
            soft.append(f)
        elif f.startswith("消息条数"):
            pass  # 条数设定在合并时按实际条数改
        else:
            soft.append(f)
    has_card = any(t["msg_type"] == "card" and "[订单信息]" in t["text"] for t in after["turns"])
    for t in after["turns"]:
        if t["role"] != "agent" or t["msg_type"] == "card":
            continue
        if not has_card and CLAIM_RE.search(t["text"]):
            hard.append(f"第 {t['turn']} 条客服仍在没有订单信息时说订单状态")
        if has_card and OVERCLAIM_RE.search(t["text"]):
            hard.append(f"第 {t['turn']} 条客服承诺了卡片上没有的办理结果")
        if LEAK_RE.search(t["text"]):
            hard.append(f"第 {t['turn']} 条客服仍提到「{LEAK_RE.search(t['text']).group(0)}」")
        if _bad_ascii(t["text"], _allowed_ascii(after)):
            hard.append(f"第 {t['turn']} 条客服仍夹英文")
    if [t["role"] for t in after["turns"]] != [t["role"] for t in before["turns"]]:
        hard.append("消息角色顺序变了")
    tpl = [i["turn"] for i in issues if i["code"] == "TEMPLATE"]
    still = [n for n in tpl if TEMPLATE_RE.search(next((t["text"] for t in after["turns"] if t["turn"] == n), ""))]
    if still:
        soft.append(f"第 {'、'.join(map(str, still))} 条仍是套话")
    left = {d["turn"] for d in unneeded_deflections(after)}
    asked = {i["turn"] for i in issues if i["code"] == "DEFLECT"}
    if left & asked:
        soft.append(f"第 {'、'.join(map(str, sorted(left & asked)))} 条仍是推脱（模型判断资料回答不了）")
    return hard, [x for x in soft if not re.search(r"仍是(?:推脱|套话)", x)]  # 推脱 / 套话没改掉不算问题（资料确实回答不了），只记日志


# ================================================================ 知识补充（大模型联网）
# 原知识多半来自客户景区基础表（简介、等级、游玩时长……），中位数约 312 字，讲解写不深。
# enrich：每个讲解对象（景区 / 子景点）调一次方舟（开联网搜索），补 4～8 条稳定的事实（历史、建筑、文物、典故、自然地理），
# 每条必须带出处网址；程序过滤掉运营信息（票价 / 时间 / 交通）、宣传话术、OTA / 社交平台出处、和已有知识重复的。
# 补充的事实单独标记（source=大模型联网补充，verified=false），标注时抽查出处；不覆盖原知识。
EXT_SOURCE = "大模型联网补充（待核）"
EXT_BAD_DOMAIN = re.compile(r"ctrip|trip\.com|tripadvisor|mafengwo|dianping|meituan|qunar|tuniu|ly\.com|fliggy|xiaohongshu|xhslink|douyin|kuaishou|weibo|"
                            r"bilibili|zhihu\.com/question|tieba|douban", re.I)
EXT_OPS = re.compile(r"票价|门票|\d+\s*元|开放时间|营业时间|几点|电话|优惠|公交|地铁|自驾|停车|预约|购票|开园|闭园|门票")
EXT_PROMO = re.compile(r"必去|绝美|网红|打卡|圣地|最美|第一|唯一|首屈一指|无与伦比|不可错过|值得一去")


def kb_unit(rec):
    """一条讲解 / 讲解评价数据 → (单元 key, 景区, 讲解对象, 地点, 已有 facts)。"""
    poi = rec.get("poi") or {}
    k = rec.get("sub_poi_knowledge") or rec.get("kb_entry") or {}
    spot = poi.get("sub_poi_name") or poi.get("poi_name")
    key = f"{poi.get('scenic_id')}|{spot}"
    place = "".join(dict.fromkeys(x for x in (poi.get("province"), poi.get("city"), poi.get("district")) if x))
    return key, poi.get("poi_name"), spot, place, k.get("facts") or []


def enrich_prompt(name, spot, place, facts):
    have = "\n".join(f"- {f['attr']}：{f['value']}" for f in facts) or "（无）"
    obj = name if spot == name else f"{name}·{spot}"
    return f"""你在为景区讲解知识库补充事实。讲解对象：「{obj}」（{place}）。

【已有知识】
{have}

请联网搜索，补充 4～8 条【已有知识】里没有的、稳定的事实，优先：历史沿革（始建 / 重建年代、重要事件）、建筑形制与材质、重要文物或景观、
人物典故与文化地位、自然地理（海拔、面积、地质成因、动植物）、园内主要景点各自的看点。

要求：
1. 每条都要来自你搜到的可靠来源（政府 / 文旅部门、景区或博物馆官网、权威百科、主流媒体），给出 source_name 和 source_url；找不到可靠来源的不要写，宁缺毋滥。
2. 不写票价、开放时间、交通、停车、预约、电话、优惠等会变的运营信息；不写「必去」「绝美」「网红」这类评价和宣传。
3. 和已有知识矛盾的不要写；已有知识里已经说过的不要重复。同名但不是这个地方的（别的省市的同名景点）不要用。
4. 传说类写明「相传」；数字、年代按来源原样写，来源说「约」就写「约」。
5. value 用自己的话写，一条一个事实，20～120 字；attr 是 2～8 字的条目名（如「始建年代」「建筑形制」「镇馆之宝」）。

只输出一个 JSON 对象（字符串里需要引号时用「」，不要用英文双引号）：
{{"facts":[{{"attr":"条目名","value":"事实","source_name":"来源名称","source_url":"https://…"}}]}}
搜不到可靠来源就输出 {{"facts":[]}}。"""


def enrich_filter(facts, js):
    have_attr = {f["attr"] for f in facts}
    have_text = " ".join(str(f.get("value") or "") for f in facts)
    ok, bad = [], []
    for f in js.get("facts") or []:
        if not isinstance(f, dict):
            continue
        attr, val = str(f.get("attr") or "").strip(), str(f.get("value") or "").strip()
        url, sname = str(f.get("source_url") or "").strip(), str(f.get("source_name") or "").strip()
        why = None
        if not attr or len(attr) > 12 or not (8 <= len(val) <= 200):
            why = "条目名 / 长度不合格"
        elif not re.match(r"^https?://[^\s/]+\.[^\s/]+", url):
            why = "没有出处网址"
        elif EXT_BAD_DOMAIN.search(url):
            why = "出处是 OTA / 社交平台"
        elif EXT_OPS.search(attr + val):
            why = "运营信息（票价 / 时间 / 交通…）"
        elif EXT_PROMO.search(val):
            why = "宣传 / 绝对化说法"
        elif re.search(r"据说|网传|野史", val) or (re.search(r"传说", val) and "相传" not in val and "传说" not in attr):
            why = "传闻没有标明「相传」"
        elif attr in have_attr or val in have_text:
            why = "和已有知识重复"
        elif bad_ascii_in(val):
            why = "夹英文"
        if why:
            bad.append(dict(attr=attr, value=val, source_url=url, reason=why))
            continue
        ok.append(dict(attr=attr, value=val, source=EXT_SOURCE, source_name=sname, source_url=url, verified=False))
        have_attr.add(attr)
        have_text += " " + val
    return ok[:8], bad


def bad_ascii_in(text):
    return [w for w in ASCII_WORD.findall(text) if not ASCII_OK.match(w)]


def load_kb_ext(path):
    out = {}
    if path and Path(path).exists():
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    x = json.loads(line)
                except ValueError:
                    continue
                if x.get("status") == "ok":
                    out[x["key"]] = x["facts"]
    return out


def cmd_enrich(args):
    records = get_records(args)
    d = out_dir(args)
    path = Path(args.kb_ext) if args.kb_ext else d / "kb_ext.jsonl"
    done = set()
    if path.exists():
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    x = json.loads(line)
                except ValueError:
                    continue
                if x.get("status") != "failed":
                    done.add(x["key"])
    units = {}
    for r in records:
        key, name, spot, place, facts = kb_unit(r)
        if key not in done and key not in units:
            units[key] = (name, spot, place, facts)
    todo = list(units.items())[: args.limit or None]
    cfg = ark_cfg(args, "enrich")
    if not cfg["ai_api_key"]:
        sys.exit(NO_KEY)
    if not cfg["ai_web_search"]:
        print("[enrich] 注意：联网搜索关着，模型只能凭记忆补，出处没法保证；没有出处的条目照样会被丢掉")
    print(f"[enrich] 讲解对象 {len(units) + len(done)} 个，待补 {len(todo)} 个（已完成 {len(done)}），联网搜索 {'开' if cfg['ai_web_search'] else '关'}，写到 {path}")
    lock, cnt = threading.Lock(), Counter()
    bar = Progress(len(todo), "[知识补充]", "个")
    bar_cn = ENRICH_CN
    fout = open(path, "a", encoding="utf-8")

    def work(item):
        key, (name, spot, place, facts) = item
        try:
            js, meta = call_model(cfg, enrich_prompt(name, spot, place, facts))
            ok, bad = enrich_filter(facts, js)
            res = dict(key=key, status="ok", facts=ok, rejected=bad, request_id=meta.get("request_id"))
        except Exception as e:  # noqa: BLE001
            res = dict(key=key, status="failed", error=f"{type(e).__name__}: {e}")
        res.update(model=cfg["ai_model"], at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        with lock:
            fout.write(json.dumps(res, ensure_ascii=False) + "\n")
            fout.flush()
            cnt[res["status"]] += 1
            cnt["facts"] += len(res.get("facts") or [])
            bar.update(cnt["ok"] + cnt["failed"], {bar_cn.get(k, k): v for k, v in cnt.items()})

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        list(ex.map(work, todo))
    fout.close()
    print(f"[enrich] 完成 {dict(cnt)}；用法：run --task narr --kb-ext {path}")
    return dict(units=len(units) + len(done), done_now=dict(cnt), kb_ext=str(path))


# ================================================================ 个性化讲解
NARR_SCENE_WHOLE = "景区个性化讲解生成"


def narr_id(rec):
    return rec["request_id"]


def _narr_u_plan(rec):
    k = rec["sub_poi_knowledge"]
    u = dict(facts=k.get("facts") or [])
    plan = dict(task_params=rec["task_params"], visit_rules=k.get("visit_rules") or [], taboos=k.get("taboos") or [])
    return u, plan


def _nlen(text):
    return len(re.sub(r"\s", "", text or ""))


def narr_flags(rec):
    """生成时同一套质检（guide_synth.narr_check）+ 乱码 / 截断 / 过短 / 个性化说明对不上。"""
    rn = rec["reference_narration"]
    u, plan = _narr_u_plan(rec)
    try:
        _, flags = guide_synth.narr_check(u, plan, dict(text=rn.get("text"), used_attrs=rn.get("used_facts"), personalization=rn.get("personalization"),
                                                        style=rn.get("style")))
    except ValueError:
        flags = ["没有讲解词"]
    rules = " ".join(plan["visit_rules"])
    flags = [f for f in flags if not (f.startswith("疑似推销") and re.search(r"「(.+)」", f).group(1) in rules)]  # 参观须知里原有的「门票」等不算推销
    text = rn.get("text") or ""
    limit = int(rec["task_params"]["字数上限"])
    bad = _bad_ascii(text)
    if bad:
        flags.append("夹英文 / 乱码：" + "、".join(bad[:3]))
    if re.search(r"(?:…|\.\.\.)\s*$", text):
        flags.append("讲解词被截断（以省略号结尾）")
    if _nlen(text) < max(40, int(limit * 0.35)):
        flags.append(f"讲解词过短（{_nlen(text)} 字，上限 {limit}）")
    miss = [q for p in rn.get("personalization") or [] for q in re.findall("「(.+?)」", str(p)) if q not in text]
    if miss:
        flags.append("个性化说明引用的话讲解词里没有：" + "、".join(miss[:3]))
    return sorted(set(flags))


def _kb_chars(facts):
    return sum(len(str(f.get("value") or "")) for f in facts)


def narr_ctx(records, args):
    """全局：--kb-ext 补充的知识；--rebalance-limits 时挑约 10% 补充后知识 ≥ 600 字的（原上限 200 / 300）改成 500 字档并扩写。
    没补知识时不做 500 字档：原知识中位数约 312 字，写 500 字只能编。"""
    ext = load_kb_ext(getattr(args, "kb_ext", None))
    ctx = dict(ext=ext, to500=set())
    if ext and args.rebalance_limits:
        cands = []
        for r in records:
            key, _, _, _, facts = kb_unit(r)
            if r["task_params"]["字数上限"] in (200, 300) and _kb_chars(facts) + _kb_chars(ext.get(key) or []) >= 600:
                cands.append((_h(narr_id(r), "to500"), narr_id(r)))
        cands.sort()
        ctx["to500"] = {i for _, i in cands[:int(len(records) * 0.10)]}
    return ctx


def narr_diagnose(rec, ctx=None, args=None):
    """code：CNT 字数统计不对（规则） · SCENE 不是子景点、场景改名（规则，--relabel-scene） · LIMIT100 字数上限 120→100（--rebalance-limits）
    GARBLED 夹英文 / 乱码 / 截断 / 过短（模型重写） · OVER 超字数（模型压缩） · ABS 绝对化 · NUM 知识没有的数字 · LEGEND 知识没有的传说
    SALES 疑似推销 · PERS 个性化说明对不上（模型改）"""
    rn = rec["reference_narration"]
    issues = []
    if rn.get("char_count") != _nlen(rn.get("text")):
        issues.append(dict(code="CNT"))
    if args is not None and args.relabel_scene and rec["poi"].get("sub_poi_name") == rec["poi"].get("poi_name") and rec.get("scene") != NARR_SCENE_WHOLE:
        issues.append(dict(code="SCENE"))
    lim = int(rec["task_params"]["字数上限"])
    if args is not None and args.rebalance_limits and lim == 120:
        issues.append(dict(code="LIMIT100"))
    if ctx and ctx.get("ext") and ctx["ext"].get(kb_unit(rec)[0]):
        issues.append(dict(code="KBEXT", n=len(ctx["ext"][kb_unit(rec)[0]])))
    if ctx and narr_id(rec) in ctx.get("to500", ()):
        issues.append(dict(code="LIMIT500"))
    for f in narr_flags(rec):
        code = ("GARBLED" if re.match(r"夹英文|讲解词被截断|讲解词过短|没有讲解词", f) else "OVER" if f.startswith("超出字数") else
                "ABS" if f.startswith("绝对化") else "NUM" if f.startswith("讲解词里有知识没有的数字") else "LEGEND" if "传说" in f else
                "SALES" if f.startswith("疑似推销") else "PERS" if f.startswith("个性化说明") else "OTHER")
        issues.append(dict(code=code, detail=f))
    need_llm = any(i["code"] not in ("CNT", "SCENE", "LIMIT100", "KBEXT") for i in issues)
    return issues, need_llm


def narr_prepare(rec, ctx, args):
    r = copy.deepcopy(rec)
    issues, need_llm = narr_diagnose(r, ctx, args)
    log = []
    rn = r["reference_narration"]
    for i in issues:
        if i["code"] == "CNT":
            log.append(f"规则：char_count {rn.get('char_count')} → {_nlen(rn.get('text'))}")
            rn["char_count"] = _nlen(rn.get("text"))
        elif i["code"] == "SCENE":
            log.append(f"规则：子景点就是景区本身，scene「{r['scene']}」→「{NARR_SCENE_WHOLE}」")
            r["scene"] = NARR_SCENE_WHOLE
        elif i["code"] == "LIMIT100":
            r["task_params"]["字数上限"] = 100
            log.append("规则：字数上限 120 → 100（配比）")
        elif i["code"] == "KBEXT":  # 保持原结构：facts 仍是 {attr, value}；出处按原格式追加进 source.fact_sources
            k = r["sub_poi_knowledge"]
            have = {f["attr"] for f in k["facts"]}
            fs = (r.get("source") or {}).get("fact_sources")
            for f in ctx["ext"][kb_unit(rec)[0]]:
                attr = f["attr"] + ("（补充）" if f["attr"] in have else "")
                have.add(attr)
                k["facts"].append(dict(attr=attr, value=f["value"]))
                if isinstance(fs, list):
                    fs.append(dict(source_id=f"ext:{attr}", url=f.get("source_url"), title=f.get("source_name") or attr,
                                   publisher=f.get("source_name"), type=EXT_SOURCE))
            log.append(f"规则：知识补充 {i['n']} 条（{EXT_SOURCE}；出处在 source.fact_sources，source_id 为 ext:条目名）")
        elif i["code"] == "LIMIT500":
            log.append(f"规则：字数上限 {r['task_params']['字数上限']} → 500（配比；补充后知识够多）")
            r["task_params"]["字数上限"] = 500
    if any(i["code"] == "LIMIT100" for i in issues) and _nlen(rn.get("text")) > 100:
        issues.append(dict(code="OVER", detail=f"超出字数上限（{_nlen(rn.get('text'))} > 100）"))
        need_llm = True
    return r, issues, need_llm, log


def _profile_line(p):
    return (f"{p['性别']}，{p['年龄']}岁，{p['出游客群名称']}（{p['同行结构描述']}）" + (f"，孩子 {p['儿童年龄']} 岁" if p.get("同行儿童数") and p.get("出游客群名称") != "研学学生" else "")
            + f"；来自{p['客源城市']}；兴趣：{'、'.join(p.get('兴趣标签') or []) or '无'}；偏好：{'、'.join(p.get('偏好景区类别Top3') or [])}")


def narr_mode(issues):
    codes = {i["code"] for i in issues}
    if "GARBLED" in codes:
        return "rewrite"
    if "LIMIT500" in codes:
        return "expand"
    if codes <= {"PERS", "CNT", "SCENE", "LIMIT100", "KBEXT"}:
        return "pers"
    return "edit"


def narr_prompt(rec, issues, feedback=None):
    k, tp, rn = rec["sub_poi_knowledge"], rec["task_params"], rec["reference_narration"]
    facts = "\n".join(f"- {f['attr']}：{f['value']}" for f in k.get("facts") or [])
    rules = "\n".join(f"- {x}" for x in k.get("visit_rules") or []) or "（无）"
    lim = int(tp["字数上限"])
    mode = narr_mode(issues)
    probs = "\n".join(f"- {i['detail']}" for i in issues if i.get("detail"))
    task = {
        "rewrite": f"原讲解词有乱码 / 夹英文 / 被截断 / 太短，不能用。请按要求重新写一段，{int(lim * 0.7)}～{int(lim * 0.9)} 字。",
        "expand": f"字数上限改成了 {lim} 字。在原讲解词基础上扩写到 {int(lim * 0.7)}～{int(lim * 0.9)} 字：多用【知识】里还没讲到的条目（包括补充的条目），不要加知识以外的内容。",
        "pers": "讲解词本身不用改（text 原样返回），只把 personalization 重写成和讲解词一致的 1～3 条说明；引用讲解词原话时必须一字不差。",
        "edit": f"只改有问题的句子，其余原样；改完不超过 {lim} 字（超字数就只删不增）。",
    }[mode]
    fb = ("\n\n【上一次改完仍不合格，原因】\n" + "\n".join(f"- {x}" for x in feedback)) if feedback else ""
    return f"""你在修正「个性化讲解」训练数据。

景区：{rec['poi']['poi_name']}；讲解对象：{rec['poi']['sub_poi_name']}；游客当前位置：{tp.get('当前所处位置') or '未知'}
【知识】（讲解词里的事实只能来自这里，数字、年代原样）
{facts}
【禁忌】{'；'.join(k.get('taboos') or [])}
【参观须知】
{rules}
【游客画像】{_profile_line(rec['visitor_profile'])}
【任务参数】字数上限 {lim} 字（正文含标点、不含空格）；风格：{tp.get('讲解风格') or '未指定'}；禁止：{'、'.join(tp.get('禁止事项') or [])}

【原讲解词】（{_nlen(rn.get('text'))} 字）
{rn.get('text')}

【原个性化说明】{json.dumps(rn.get('personalization') or [], ensure_ascii=False)}

【问题】
{probs or '（见任务）'}

【任务】{task}{fb}

要求：
1. 只用【知识】里的事实；不加知识里没有的数字、年代、人物、传说（知识里有「相传」的可以保留并说明是传说）。
2. 不用「最」「唯一」「第一」「绝对」「顶级」等绝对化说法（知识原话除外），不推销门票、商品、服务；全文中文，不夹英文。
3. 结合画像：称呼、语气贴合客群，兴趣相关的先讲；风格已指定就照风格。
4. personalization 写 1～3 条「针对画像做了什么」，引用讲解词原话时用「」且一字不差。

只输出一个 JSON 对象（字符串里需要引号时用「」，不要用英文双引号）：
{{"text":"讲解词","used_attrs":["用到的知识条目名"],"personalization":["…"],"style":"实际采用的风格"}}"""


def narr_apply(rec, issues, js):
    r = copy.deepcopy(rec)
    rn = r["reference_narration"]
    old = rn.get("text") or ""
    text = str(js.get("text") or "").strip() or old
    if narr_mode(issues) == "pers":
        text = old
    attrs = {f["attr"] for f in r["sub_poi_knowledge"].get("facts") or []}
    used = [a for a in js.get("used_attrs") or [] if a in attrs] or rn.get("used_facts") or []
    pers = [str(x) for x in (js.get("personalization") or [])][:3] or rn.get("personalization") or []
    for k, v in dict(text=text, char_count=_nlen(text), used_facts=used, personalization=pers, style=js.get("style") or rn.get("style")).items():
        if k in rn or k == "text":  # 只更新原来就有的字段，保持原结构
            rn[k] = v
    return r, (["text"] if text != old else []) + ["personalization"], []


def narr_validate(before, after, issues):
    hard, soft = [], []
    lim = int(after["task_params"]["字数上限"])
    if any(i["code"] == "LIMIT500" for i in issues) and _nlen(after["reference_narration"]["text"]) < int(lim * 0.6):
        hard.append(f"扩写后只有 {_nlen(after['reference_narration']['text'])} 字，不到 {int(lim * 0.6)}")
    for f in narr_flags(after):
        if re.match(r"夹英文|讲解词被截断|讲解词过短|没有讲解词|超出字数|讲解词里有知识没有的数字|讲了知识里没有的传说", f):
            hard.append(f)
        else:
            soft.append(f)
    return hard, soft


# ================================================================ 通用：任务表
TASKS = {
    "cs": dict(name="智能客服对话", id=cs_id, ctx=lambda recs, args: {}, prepare=lambda r, ctx, args: cs_prepare(r, ctx), prompt=cs_prompt,
               apply=cs_apply, validate=cs_validate, diagnose=lambda r, ctx, args: cs_diagnose(r),
               l1=["session_id", "channel", "visitor_id", "scenic_id", "scenic_name", "start_time", "related_order_id", "turns", "session_duration_sec"],
               sidecar=["end_type", "satisfaction_score", "source"], drop_on_hard=True),
    "narr": dict(name="个性化讲解", id=narr_id, ctx=narr_ctx, prepare=narr_prepare, prompt=narr_prompt, apply=narr_apply, validate=narr_validate,
                 diagnose=narr_diagnose,
                 l1=["request_id", "scene", "request_time", "poi", "sub_poi_knowledge", "visitor_profile", "task_params"],
                 sidecar=["reference_narration", "source"], drop_on_hard=True),
}


Q_DATA = HERE.parent / "q_data"  # 客户交付数据默认放这里（tools/q_data）
Q_NAMES = {"cs": "客服会话", "narr": "个性化讲解"}


def default_input(task):
    """没给 --in 时找 tools/q_data 下的数据，优先用解压出来的文件：<名称>.json / .jsonl / .csv → <名称>/ 目录 → <名称>.zip。"""
    name = Q_NAMES[task]
    found = [Q_DATA / f"{name}{ext}" for ext in (".json", ".jsonl", ".csv") if (Q_DATA / f"{name}{ext}").exists()]
    if not found and (Q_DATA / name).is_dir():
        found = [Q_DATA / name]
    if not found and (Q_DATA / f"{name}.zip").exists():
        found = [Q_DATA / f"{name}.zip"]
    if not found:
        sys.exit(f"找不到 {name} 的数据：放 {Q_DATA / (name + '.json')}（或 .jsonl / .csv / .zip），或用 --in 指定")
    z = Q_DATA / f"{name}.zip"
    if found[0] != z and z.exists():
        print(f"[读取] {name}：用解压出来的 {found[0].name}（同目录的 {z.name} 不用；要用 zip 就 --in {z}）", flush=True)
    return found[0]


def _decode(b):
    for enc in ("utf-8-sig", "gb18030"):  # Excel 另存的 CSV 可能是 GBK
        try:
            return b.decode(enc)
        except UnicodeDecodeError:
            continue
    return b.decode("utf-8", "replace")


def _parse_json_text(text):
    t = text.lstrip()
    if t.startswith("["):
        return json.loads(t)
    return [json.loads(line) for line in t.splitlines() if line.strip()]


def _cell(v):
    """CSV 单元格：空 / null → None；看起来是 JSON 的（[…] / {…}）解析成对象；其余原样。"""
    if v is None:
        return None
    t = v.strip()
    if t == "" or t.lower() in ("null", "none", "nan"):
        return None
    if t[0] in "[{":
        try:
            return json.loads(t)
        except ValueError:
            pass
    return v


INT_FIELDS = {"satisfaction_score", "session_duration_sec", "turn", "turn_no"}


def _int(v):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return v


def _records_from_csv(tables):
    """CSV → 记录。支持三种：① 有 record_json 列（工作台讲解 / 评价导出的 CSV）；② 会话表 CSV + 轮次表 CSV（工作台客服导出的两张表）；
    ③ 一行一条、嵌套字段（turns / poi / source…）是 JSON 字符串的通用 CSV。"""
    import csv
    tables = [(n, rows) for n, rows in tables if rows]
    for n, rows in tables:
        if "record_json" in rows[0]:
            return [json.loads(r["record_json"]) for r in rows if (r.get("record_json") or "").strip()]
    sess = next((rows for n, rows in tables if {"session_id", "channel"} <= set(rows[0]) and "msg_text" not in rows[0] and "turns" not in rows[0]), None)
    turns = next((rows for n, rows in tables if {"session_id", "msg_text"} <= set(rows[0])), None)
    if sess is not None and turns is not None:
        by = {}
        for t in turns:
            by.setdefault(t["session_id"], []).append(t)
        out = []
        for r in sess:
            tl = []
            for t in sorted(by.get(r["session_id"], []), key=lambda t: _int(t.get("turn_no")) or 0):
                d = dict(turn=_int(t.get("turn_no")), role=t.get("role"), msg_type=t.get("msg_type") or "text", text=t.get("msg_text") or "",
                         ts=str(t.get("msg_ts") or "")[-8:])
                if (t.get("agent_id") or "").strip():
                    d["agent_id"] = t["agent_id"].strip()
                tl.append(d)
            out.append(dict(session_id=r["session_id"], channel=r.get("channel"), visitor_id=r.get("visitor_id"), scenic_id=r.get("scenic_id"),
                            scenic_name=r.get("scenic_name"), start_time=r.get("start_time"), related_order_id=_cell(r.get("related_order_id")),
                            turns=tl, end_type=_cell(r.get("end_type")), satisfaction_score=_int(_cell(r.get("satisfaction_score"))),
                            session_duration_sec=_int(_cell(r.get("session_duration_sec"))), source=_cell(r.get("source")) or {}))
        return out
    if sess is None and turns is not None:
        sys.exit("只有轮次表 CSV（session_id / msg_text），缺会话表 CSV（session_id / channel / source…），两张一起放进 zip")
    n, rows = max(tables, key=lambda x: len(x[1]))
    return [{k: (_int(_cell(v)) if k in INT_FIELDS else _cell(v)) for k, v in r.items() if k} for r in rows]


def load_records(path):
    """读输入：.json（数组）/ .jsonl / .csv，或 zip（里面放这些，中文文件名乱码也没关系），或一个目录。
    同一个 zip / 目录里有 json 就用最大的那个 json；只有 csv 就按 CSV 规则读（见 _records_from_csv）。"""
    import csv
    import io
    import zipfile
    csv.field_size_limit(2 ** 31 - 1)
    p = Path(path)
    t0 = time.time()
    print(f"[读取] {p} …", flush=True)
    files = []  # (文件名, 读字节的函数, 大小)
    if p.is_dir():
        files = [(str(f), f.read_bytes, f.stat().st_size) for f in sorted(p.iterdir()) if f.is_file()]
        z = None
    elif p.suffix.lower() == ".zip":
        z = zipfile.ZipFile(p)
        files = [(m.filename, (lambda m=m: z.read(m)), m.file_size) for m in z.infolist() if not m.is_dir()]
    else:
        z = None
        files = [(str(p), p.read_bytes, p.stat().st_size)]
    files = [f for f in files if not Path(f[0]).name.startswith(".") and "__MACOSX" not in Path(f[0]).parts]  # Mac 压缩带的隐藏文件
    js = [f for f in files if re.search(r"\.jsonl?$", f[0], re.I)]
    cs_ = [f for f in files if re.search(r"\.csv$", f[0], re.I)]
    if js:
        name, read, _ = max(js, key=lambda f: f[2])
        recs = _parse_json_text(_decode(read()))
        how = f"JSON（{Path(name).name}）"
    elif cs_:
        tables = [(name, list(csv.DictReader(io.StringIO(_decode(read()))))) for name, read, _ in cs_]
        recs = _records_from_csv(tables)
        how = "CSV（" + "、".join(f"{Path(n).name} {len(r)} 行" for n, r in tables) + "）"
    else:
        sys.exit(f"{p} 里没有 .json / .jsonl / .csv")
    if z is not None:
        z.close()
    print(f"[读取] {len(recs)} 条，{how}，用时 {time.time() - t0:.0f} 秒", flush=True)
    return recs


REQUIRED = {"cs": ["session_id", "scenic_name", "turns", "source"],
            "narr": ["request_id", "poi", "sub_poi_knowledge", "visitor_profile", "task_params", "reference_narration"]}


def validate_input(task, recs, d=None):
    """检查字段：大部分缺必需字段 → 直接退出说明缺什么；少数缺的跳过，写 invalid.jsonl。"""
    def why(r):
        miss = [k for k in REQUIRED[task] if not r.get(k)]
        if miss:
            return "缺字段：" + "、".join(miss)
        if task == "cs" and not (isinstance(r["turns"], list) and all(isinstance(t, dict) and "role" in t and "text" in t for t in r["turns"])):
            return "turns 不是 [{role, text, …}] 列表"
        if task == "narr" and not isinstance((r.get("reference_narration") or {}).get("text"), str):
            return "reference_narration.text 不是文字"
        return None
    good, bad = [], []
    for r in recs:
        w = why(r) if isinstance(r, dict) else "不是 JSON 对象"
        (bad if w else good).append((r, w))
    if recs and len(bad) > len(recs) / 2:
        sys.exit(f"[读取] {len(bad)}/{len(recs)} 条格式不对，例：{bad[0][1]}。{Q_NAMES[task]}需要字段 {REQUIRED[task]}"
                 + ("；客服会话的景区资料在 source.facts（没有的话事实核对做不了）" if task == "cs" else ""))
    if bad:
        print(f"[读取] 跳过 {len(bad)} 条格式不对的（{Counter(w for _, w in bad).most_common(1)[0][0]} 等），写在 invalid.jsonl", flush=True)
        if d is not None:
            with open(Path(d) / "invalid.jsonl", "w", encoding="utf-8") as f:
                for r, w in bad:
                    f.write(json.dumps(dict(reason=w, record=r), ensure_ascii=False, default=str) + "\n")
    if task == "cs":
        nofacts = sum(1 for r, _ in good if not (r["source"] or {}).get("facts"))
        if nofacts:
            print(f"[读取] 注意：{nofacts} 通会话的 source.facts 是空的，这些只能做格式类修正，事实核对做不了", flush=True)
    return [r for r, _ in good]


def get_records(args):
    return validate_input(args.task, load_records(args.input), out_dir(args))


# ================================================================ 进度条
STATUS_CN = dict(fixed="模型修好", review="需复核", dropped="剔除", failed="调用失败", rule="规则修好", ok="无需修改", pending="还没调模型",
                 returning_visitors_set="设为回头客")
ENRICH_CN = dict(ok="补完", failed="调用失败", facts="条知识")


def _hms(sec):
    if sec is None:
        return "--:--"
    sec = int(sec)
    return f"{sec // 3600}:{sec % 3600 // 60:02d}:{sec % 60:02d}" if sec >= 3600 else f"{sec // 60:02d}:{sec % 60:02d}"


class Progress:
    """终端里一行刷新的进度条（不依赖 tqdm）；输出被重定向到文件 / 日志时每 30 秒打一行。"""

    def __init__(self, total, label, unit="条"):
        self.total, self.label, self.unit = total, label, unit
        self.t0, self.last, self.width = time.time(), 0.0, 0
        self.tty = sys.stdout.isatty()

    def update(self, done, counts=None, force=False):
        now = time.time()
        end = done >= self.total
        if not force and not end and now - self.last < (0.5 if self.tty else 30):
            return
        self.last = now
        pct = done / self.total if self.total else 1.0
        n = int(pct * 28)
        el = now - self.t0
        rate = done / el if el > 0 else 0
        eta = (self.total - done) / rate if rate > 0 else None
        cs = " ".join(f"{STATUS_CN.get(k, k)} {v}" for k, v in (counts or {}).items() if v)  # 已经是中文的原样显示
        line = (f"{self.label} [{'█' * n}{'░' * (28 - n)}] {pct * 100:5.1f}%  {done}/{self.total}  "
                f"{rate * 60:.0f} {self.unit}/分  已用 {_hms(el)}  剩余 {_hms(eta)}" + (f"  | {cs}" if cs else ""))
        if self.tty:
            pad = max(0, self.width - len(line))
            sys.stdout.write("\r" + line + " " * pad)
            self.width = len(line)
            if end:
                sys.stdout.write("\n")
            sys.stdout.flush()
        else:
            print(line, flush=True)


# 联网搜索默认值（按步骤）：修正只许用数据里给的资料 / 知识，开联网反而会带进外部事实，默认关；知识补充要找出处，默认开。
WEB_SEARCH_DEFAULT = {"fix": False, "enrich": True}
WEB_SEARCH_ENV = {"fix": "DATA_FIX_WEB_SEARCH", "enrich": "DATA_FIX_ENRICH_WEB_SEARCH"}


def _on(v):
    return str(v).strip().lower() in ("1", "on", "true", "yes", "y", "开")


def ark_cfg(args, step="fix", quiet=False):
    """方舟配置，和 cs_synth / cs_expand / guide_synth 同一来源：
    API Key、接口地址、默认模型、超时 → 工作台「设置 → AI 判断」（MySQL 表 hq_app_settings；连不上数据库时读 <profile>/hq_prefs.json）→ 环境变量 ARK_API_KEY；
    模型：--model > 环境变量 ARK_MODEL > 设置页；接口地址：环境变量 ARK_BASE_URL > 设置页；
    联网搜索：--web-search on|off > 环境变量 DATA_FIX_WEB_SEARCH（修正）/ DATA_FIX_ENRICH_WEB_SEARCH（知识补充）> 默认（修正关、补充开）。
    设置页上的「联网搜索」开关是给 POI 核对用的，这里不跟它走。"""
    prefs, where = {}, "无"
    try:
        import review
        prefs = review.DbPrefs(Path(args.profile) / "hq_prefs.json", readonly=True)
        where = getattr(prefs, "storage", "") or "文件"
    except Exception as e:  # noqa: BLE001  没装 pymysql / 数据库连不上：直接读浏览器目录里的设置文件
        f = Path(args.profile) / "hq_prefs.json"
        try:
            prefs, where = json.loads(f.read_text(encoding="utf-8")), f"文件 {f}"
        except (OSError, ValueError):
            if not _WARNED.get("prefs"):
                print(f"[ark] 读工作台设置失败（{type(e).__name__}: {e}），也没有 {f}，只用环境变量", flush=True)
                _WARNED["prefs"] = True
    cfg = ai_judge.config(prefs)
    if cfg.get("key_source") == "设置页":
        cfg["key_source"] = f"工作台设置页（{where}）"
    if os.environ.get("ARK_BASE_URL"):
        cfg["ai_base_url"] = os.environ["ARK_BASE_URL"].rstrip("/")
    cfg["ai_model"] = (args.model or os.environ.get("ARK_MODEL") or cfg.get("ai_model") or ai_judge.DEFAULTS["ai_model"]).strip()
    cfg["ai_timeout_s"] = max(float(cfg.get("ai_timeout_s") or 60), float(args.timeout))
    cfg["ai_thinking"] = False
    ws = args.web_search if args.web_search is not None else os.environ.get(WEB_SEARCH_ENV[step])
    cfg["ai_web_search"] = WEB_SEARCH_DEFAULT[step] if ws in (None, "") else _on(ws)
    cfg["ai_max_keyword"] = int(args.max_keyword or cfg.get("ai_max_keyword") or 3)
    if not quiet:
        print(f"[ark] Key：{ai_judge.mask(cfg.get('ai_api_key')) or '没有'}（来自 {cfg.get('key_source') or '—'}）；接口 {cfg['ai_base_url']}；"
              f"模型 {cfg['ai_model']}；联网搜索 {'开' if cfg['ai_web_search'] else '关'}"
              + (f"（最多 {cfg['ai_max_keyword']} 个关键词）" if cfg["ai_web_search"] else "") + f"；超时 {cfg['ai_timeout_s']:.0f} 秒", flush=True)
    return cfg


_WARNED = {}
NO_KEY = "没有方舟 API Key：在工作台「设置 → AI 判断」里填（存 MySQL 表 hq_app_settings），或 export ARK_API_KEY=…；--profile 指向工作台用的浏览器目录"


def cmd_check(args):
    """看配置从哪来、试调一次。"""
    cfg = ark_cfg(args, "enrich" if args.step == "enrich" else "fix")
    if not cfg.get("ai_api_key"):
        sys.exit(NO_KEY)
    try:
        r = ai_judge.ping(cfg)
        print(f"[ark] 连接正常：{r['elapsed']} 秒，request_id {r.get('request_id')}，返回 {r['text'][:60]}")
    except ai_judge.AIError as e:
        sys.exit(f"[ark] 调用失败：{e}")


RETRY = dict(n=3)  # 调用失败最多重试几次（--retries）
FATAL_HTTP = {400, 401, 403, 404}  # Key 不对、没权限、模型名 / 地址不对：重试也没用，直接报


def call_model(cfg, prompt, tries=None):
    """调方舟一次，失败（网络 / 超时 / 限流 429 / 5xx / 返回不是 JSON）最多重试 RETRY 次，间隔 3、6、12… 秒（限流再翻倍）。
    返回 (js, meta)；meta.retries = 重试了几次。重试完还失败就抛出，这条记为「调用失败」，下次 run 自动再试。"""
    n = RETRY["n"] if tries is None else tries
    last = None
    for k in range(n + 1):
        try:
            raw, elapsed, meta, js = ai_judge.call_json(cfg, prompt, retries=0)
            return js, dict(elapsed=elapsed, request_id=meta.get("request_id"), usage=meta.get("usage"), retries=k)
        except ai_judge.AIError as e:
            last = e
            if e.http_status in FATAL_HTTP:
                raise
            if k < n:
                time.sleep(3 * (2 ** k) * (2 if e.http_status == 429 else 1))
    raise ai_judge.AIError(f"重试 {n} 次仍失败：{last}", getattr(last, "http_status", None), getattr(last, "request_id", None))


def fix_one(task, rec, ctx, args, cfg):
    """一条：准备（规则修）→ 调模型 → 复检 → 不过带原因再问一次 → 结果。"""
    T = TASKS[task]
    prep, issues, need_llm, log = T["prepare"](rec, ctx, args)
    if prep.get("_drop"):
        return dict(status="dropped", reason=prep["_drop"], log=log)
    if not need_llm:
        return dict(status="rule", record=prep, log=log)
    feedback, cur, calls, usage = None, prep, [], Counter()
    hard = soft = []
    for attempt in range(1, args.attempts + 1):
        js, meta = call_model(cfg, T["prompt"](prep, issues, feedback))
        calls.append(meta.get("request_id"))
        if meta.get("retries"):
            log.append(f"调用重试 {meta['retries']} 次后成功")
        for kk, vv in (meta.get("usage") or {}).items():
            if isinstance(vv, (int, float)):
                usage[kk] += vv
        cur, changed, notes = T["apply"](prep, issues, js)
        log += [f"模型第 {attempt} 次：改了 {changed}"] + notes
        hard, soft = T["validate"](prep, cur, issues)
        if not hard:
            break
        feedback = hard + soft
    if hard and task == "narr" and all(h.startswith("扩写后") for h in hard):  # 扩写不够长：退回原上限、原讲解词，不剔除
        cur = copy.deepcopy(prep)
        cur["task_params"]["字数上限"] = rec["task_params"]["字数上限"]
        cur["reference_narration"] = copy.deepcopy(rec["reference_narration"])
        log.append("扩写到 500 字没成功，退回原字数上限和原讲解词")
        hard, soft = T["validate"](prep, cur, [i for i in issues if i["code"] != "LIMIT500"])
    if hard and T["drop_on_hard"]:
        return dict(status="dropped", reason=hard, log=log, calls=calls, usage=dict(usage))
    if task == "cs" and any("指代" in s for s in soft):  # 指代改不出来：把设定改成没有指代（如实），不再标需复核
        sp = _plan(cur)
        log.append(f"规则：指代设定 {sp.get('coref')} 没做到，改为无")
        sp["coref"], sp["coref_annotation"] = None, []
        soft = [s for s in soft if "指代" not in s]
    return dict(status="fixed" if not soft else "review", record=cur, remaining=soft, log=log, calls=calls, usage=dict(usage))


# ================================================================ 全局（合并时）
def cs_returning_visitors(records, rate, fixlog=None):
    """回头客：约 rate 的会话复用同城更早会话的 visitor_id（规则手册：老客约 40%）。确定性。改动记在 fixlog（不写进记录）。"""
    if not rate:
        return 0
    order = sorted(range(len(records)), key=lambda i: records[i]["start_time"])
    seen, n = {}, 0
    for i in order:
        r = records[i]
        city = (r.get("source") or {}).get("scenic_city") or ""
        pool = seen.setdefault(city, [])
        if pool and _h(r["session_id"], "returning") < rate:
            new = pool[int(_h(r["session_id"], "pick") * len(pool)) % len(pool)]
            if fixlog is not None:
                e = fixlog.setdefault(r["session_id"], dict(id=r["session_id"], status="rule", actions=[]))
                e["actions"].append(f"规则：设为回头客，visitor_id {r['visitor_id']} → {new}（复用同城更早会话的）")
            r["visitor_id"] = new
            n += 1
        else:
            pool.append(r["visitor_id"])
            if len(pool) > 5000:
                pool.pop(0)
    return n


def cs_duration(r):
    ts = [t["ts"] for t in r["turns"] if t.get("ts")]
    try:
        a, b = datetime.strptime(ts[0], "%H:%M:%S"), datetime.strptime(ts[-1], "%H:%M:%S")
        d = int((b - a).total_seconds())
        return d + 86400 if d < 0 else d
    except (IndexError, ValueError):
        return r.get("session_duration_sec")


def stats(task, records):
    s = Counter()
    s["total"] = len(records)
    for r in records:
        src = r.get("source") or {}
        s["needs_review"] += bool(src.get("needs_review"))
        if task == "cs":
            ag = [t for t in r["turns"] if t["role"] == "agent"]
            s["sessions_with_deflection"] += any(DEFLECT_RE.search(t["text"]) for t in ag)
            s["agent_msgs"] += len(ag)
            s["agent_deflect_msgs"] += sum(1 for t in ag if DEFLECT_RE.search(t["text"]))
            s["coref_sessions"] += bool(_plan(r).get("coref"))
            s["order_sessions"] += bool(r.get("related_order_id"))
            s["order_card_sessions"] += any(t["msg_type"] == "card" and "[订单信息]" in t["text"] for t in r["turns"])
        else:
            s[f"limit_{r['task_params']['字数上限']}"] += 1
            s[f"scene_{r['scene']}"] += 1
    if task == "cs":
        s["visitors_distinct"] = len({r["visitor_id"] for r in records})
    return dict(s)


# ================================================================ 命令
def out_dir(args):
    d = Path(args.out_dir) if args.out_dir else HERE / "out" / f"fix_{args.task}"  # 固定目录：隔天接着跑也能断点续上
    d.mkdir(parents=True, exist_ok=True)
    return d


def cmd_scan(args, records=None):
    T = TASKS[args.task]
    records = records if records is not None else get_records(args)
    ctx = T["ctx"](records, args)
    d = out_dir(args)
    by_code, need = Counter(), 0
    with open(d / "diagnose.jsonl", "w", encoding="utf-8") as f:
        for r in records:
            _, issues, need_llm, _ = T["prepare"](r, ctx, args)
            need += need_llm
            for c in {i["code"] for i in issues}:
                by_code[c] += 1
            f.write(json.dumps(dict(id=T["id"](r), need_llm=need_llm, issues=issues), ensure_ascii=False) + "\n")
    rep = dict(task=args.task, total=len(records), need_llm=need, by_code=dict(by_code.most_common()), before=stats(args.task, records))
    (d / "scan.json").write_text(json.dumps(rep, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    print(f"诊断写在 {d / 'diagnose.jsonl'}")
    return rep


def _done(d):
    done = {}
    p = d / "results.jsonl"
    if p.exists():
        with open(p, encoding="utf-8") as f:
            for line in f:
                try:
                    x = json.loads(line)
                except ValueError:
                    continue
                if x.get("status") != "failed":
                    done[x["id"]] = x
    return done


def cmd_run(args):
    T = TASKS[args.task]
    records = get_records(args)
    ctx = T["ctx"](records, args)
    d = out_dir(args)
    cfg = ark_cfg(args, "fix")
    if not cfg["ai_api_key"]:
        sys.exit(NO_KEY)
    done = _done(d)
    todo = []
    for r in records:
        rid = T["id"](r)
        if rid in done:
            continue
        _, _, need_llm, _ = T["prepare"](r, ctx, args)
        if need_llm:
            todo.append(r)
    if args.limit:
        todo = todo[:args.limit]
    print(f"[fix] {T['name']}：共 {len(records)} 条，要调模型 {len(todo)} 条（已完成 {len(done)}），模型 {cfg['ai_model']}，并发 {args.workers}")
    lock = threading.Lock()
    cnt = Counter()
    bar = Progress(len(todo), f"[{T['name']}]")
    fout = open(d / "results.jsonl", "a", encoding="utf-8")

    def work(r):
        try:
            res = fix_one(args.task, r, ctx, args, cfg)
        except Exception as e:  # noqa: BLE001  调用失败：记下来，下次重跑
            res = dict(status="failed", error=f"{type(e).__name__}: {e}")
        res["id"] = T["id"](r)
        res["at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with lock:
            fout.write(json.dumps(res, ensure_ascii=False) + "\n")
            fout.flush()
            cnt[res["status"]] += 1
            bar.update(sum(cnt.values()), cnt)

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        pending = set()
        it = iter(todo)
        for r in it:
            pending.add(ex.submit(work, r))
            if len(pending) >= args.workers * 4:
                _, pending = wait(pending, return_when=FIRST_COMPLETED)
        wait(pending)
    fout.close()
    if not todo:
        print("[fix] 没有要调模型的（都修过了）")
    print(f"[fix] 本次 {dict(cnt)}；失败的下次 run 会重试")
    if not args.no_merge:
        return cmd_merge(args, records)
    return dict(outcome=dict(cnt))


def structure_diff(a, b, path=""):
    """原记录 a 和修正后 b 的结构差异（字段名 / 顺序 / 类型 / 列表元素的字段），值的变化不算。空列表 = 结构一致。"""
    out = []
    if isinstance(a, dict) and isinstance(b, dict):
        if list(a) != list(b):
            add, rem = [k for k in b if k not in a], [k for k in a if k not in b]
            out.append(f"{path or '/'} 字段" + (f" 多了 {add}" if add else "") + (f" 少了 {rem}" if rem else "") + ("" if add or rem else " 顺序变了"))
        for k in a:
            if k in b:
                out += structure_diff(a[k], b[k], f"{path}.{k}")
    elif isinstance(a, list) and isinstance(b, list):
        sa = {tuple(x) for x in a if isinstance(x, dict)}
        sb = {tuple(x) for x in b if isinstance(x, dict)}
        if sa and sb - sa:
            out.append(f"{path}[] 元素字段变了：{[list(x) for x in sb - sa][:2]}")
    elif a is not None and b is not None and type(a) is not type(b) and not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
        out.append(f"{path} 类型 {type(a).__name__} → {type(b).__name__}")
    return out


def _set_existing(d, key, value):
    """只更新原来就有的字段（原记录没有这个字段就不加，保持原结构）。"""
    if isinstance(d, dict) and key in d:
        d[key] = value


def cmd_merge(args, records=None):
    T = TASKS[args.task]
    records = records if records is not None else get_records(args)
    ctx = T["ctx"](records, args)
    d = out_dir(args)
    done = _done(d)
    before = stats(args.task, records)
    out, dropped, fixlog = [], [], {}
    st = Counter()
    pend = 0
    orig_by_id = {}
    for r in records:
        rid = T["id"](r)
        prep, issues, need_llm, log = T["prepare"](r, ctx, args)
        res = done.get(rid)
        if prep.get("_drop"):
            dropped.append(dict(id=rid, reason=prep["_drop"], log=log))
            st["dropped"] += 1
            continue
        if need_llm and not res:  # 还没调模型：原样输出（不带规则改动，免得订单卡片和客服话术对不上），标需复核
            pend += 1
            rec, status, log = copy.deepcopy(r), "pending", []
            remaining = [i.get("detail") or i["code"] for i in issues if i["code"] not in ("COUNT", "VOICE", "CNT", "SCENE", "LIMIT100", "KBEXT", "LIMIT500")]
        elif res and res["status"] == "dropped":
            dropped.append(dict(id=rid, reason=res.get("reason"), log=res.get("log")))
            st["dropped"] += 1
            continue
        elif res:
            rec, status, remaining, log = res["record"], res["status"], res.get("remaining") or [], res.get("log") or log
        else:
            rec, status, remaining = prep, ("rule" if log else "ok"), []
        src = rec.get("source") if isinstance(rec.get("source"), dict) else {}
        if args.task == "cs":
            sp = src.get("session_plan") if isinstance(src.get("session_plan"), dict) else {}
            if "target_msgs" in sp and abs(len(rec["turns"]) - (sp.get("target_msgs") or 0)) > 2:
                sp["target_msgs"] = len(rec["turns"])
            if "session_duration_sec" in rec:
                rec["session_duration_sec"] = cs_duration(rec)
            flags = cs_flags(rec)
            if any(i["code"] == "ORDERCONFLICT" for i in issues):
                remaining = remaining + ["订单与「不支持线上购票」矛盾"]
        else:
            flags = narr_flags(rec)
        new_flags = sorted(set(flags + remaining))
        old_flags = src.get("check_flags")
        _set_existing(src, "check_flags", new_flags)  # 按现在的质检重算（例如免费景区的「¥0」不再算编造）；原来没有这个字段就不加
        _set_existing(src, "needs_review", bool(new_flags) or status in ("review", "pending"))
        if status != "ok" or new_flags != sorted(old_flags or []):
            fixlog[rid] = dict(id=rid, status=status, actions=list(log), remaining=remaining, check_flags_before=old_flags, check_flags_after=new_flags,
                               fixed_at=(res or {}).get("at") or datetime.now().strftime("%Y-%m-%d %H:%M:%S"), version=FIX_VERSION)
        if status in ("fixed", "review"):
            orig_by_id[rid] = r
        st[status] += 1
        out.append(rec)
    if args.task == "cs":
        st["returning_visitors_set"] = cs_returning_visitors(out, args.returning_rate, fixlog)
    # 结构检查：修正后每条和输入比，字段名 / 顺序 / 类型 / 列表元素字段都要一致
    src_by_id = {T["id"](r): r for r in records}
    bad = []
    for r in out:
        df = structure_diff(src_by_id[T["id"](r)], r)
        if df:
            bad.append(dict(id=T["id"](r), diffs=df))
    st["structure_mismatch"] = len(bad)
    after = stats(args.task, out)
    with open(d / "fixed.json", "w", encoding="utf-8") as f:
        f.write("[\n")
        for i, r in enumerate(out):
            f.write(json.dumps(r, ensure_ascii=False) + (",\n" if i < len(out) - 1 else "\n"))
        f.write("]\n")
    key = T["l1"][0]
    with open(d / "fixed_l1.jsonl", "w", encoding="utf-8") as f1, open(d / "fixed_sidecar.jsonl", "w", encoding="utf-8") as f2:
        for r in out:
            f1.write(json.dumps({k: r.get(k) for k in T["l1"] if k in r}, ensure_ascii=False) + "\n")
            f2.write(json.dumps({key: r[key], **{k: r.get(k) for k in T["sidecar"] if k in r}}, ensure_ascii=False) + "\n")
    with open(d / "dropped.jsonl", "w", encoding="utf-8") as f:
        for x in dropped:
            f.write(json.dumps(x, ensure_ascii=False) + "\n")
    with open(d / "fix_log.jsonl", "w", encoding="utf-8") as f:
        for x in fixlog.values():
            f.write(json.dumps(x, ensure_ascii=False) + "\n")
    with open(d / "structure_diff.jsonl", "w", encoding="utf-8") as f:
        for x in bad:
            f.write(json.dumps(x, ensure_ascii=False) + "\n")
    # 改动对照：调模型改过的，原文 / 修正后并排（每种状态均匀抽，最多 --sample 条），方便抽查
    by_status = {}
    final_by_id = {T["id"](r): r for r in out}
    for rid in orig_by_id:
        by_status.setdefault(fixlog.get(rid, {}).get("status", "fixed"), []).append(rid)
    pick = []
    for stt, ids in sorted(by_status.items()):
        ids.sort(key=lambda i: _h(i, "sample"))
        pick += ids[: max(1, args.sample * len(ids) // max(1, len(orig_by_id)))]
    with open(d / "compare.jsonl", "w", encoding="utf-8") as f:
        for rid in pick[: args.sample]:
            f.write(json.dumps(dict(id=rid, status=fixlog.get(rid, {}).get("status"), actions=fixlog.get(rid, {}).get("actions"),
                                    remaining=fixlog.get(rid, {}).get("remaining"), before=orig_by_id[rid], after=final_by_id[rid]), ensure_ascii=False) + "\n")
        for x in dropped[: max(20, args.sample // 10)]:
            f.write(json.dumps(dict(id=x["id"], status="dropped", actions=x.get("log"), remaining=x.get("reason"), before=src_by_id.get(x["id"]), after=None),
                               ensure_ascii=False) + "\n")
    rep = dict(task=args.task, fix_version=FIX_VERSION, input=str(args.input), outcome=dict(st), pending_llm=pend, before=before, after=after,
               dropped_reasons=dict(Counter(re.sub(r"\d+", "N", x) for d_ in dropped for x in (d_["reason"] or [])).most_common(15)),
               structure=dict(mismatch=len(bad), examples=bad[:3]))
    (d / "report.json").write_text(json.dumps(rep, ensure_ascii=False, indent=1), encoding="utf-8")
    (d / "report.md").write_text(report_md(rep), encoding="utf-8")
    print(report_md(rep))
    if bad:
        print(f"[结构检查] ⚠ {len(bad)} 条和输入结构不一致，明细在 {d / 'structure_diff.jsonl'}，例：{bad[0]['diffs'][:2]}")
    else:
        print("[结构检查] 全部和输入结构一致（字段名、顺序、类型、列表元素字段，含 source）")
    print(f"输出在 {d}")
    return rep


def cmd_all(args):
    """排队跑：客服会话修正 → （--enrich）讲解知识补充 → 个性化讲解修正。一步跑完再跑下一步；某一步出错记下来，接着跑后面的。
    每一步都能断点续跑：中途停了，再执行同一条命令会从没做完的地方接着做。"""
    tasks = [t.strip() for t in (args.tasks or "cs,narr").split(",") if t.strip()]
    for t in tasks:
        if t not in TASKS:
            sys.exit(f"--tasks 只能是 cs / narr：{t}")
    steps = []
    if "cs" in tasks:
        steps.append(("cs", "run", "客服会话修正"))
    if "narr" in tasks:
        if args.enrich:
            steps.append(("narr", "enrich", "讲解知识补充（联网）"))
        steps.append(("narr", "run", "个性化讲解修正"))
    if not ark_cfg(args, "fix", quiet=True).get("ai_api_key"):  # 先查一次，别跑到一半才发现没 Key
        sys.exit(NO_KEY)
    base = dict(vars(args))
    results = []
    t_all = time.time()
    for i, (task, cmd, title) in enumerate(steps, 1):
        print(f"\n{'=' * 18} 第 {i}/{len(steps)} 步：{title} {'=' * 18}", flush=True)
        a = argparse.Namespace(**base)
        a.task = task
        a.input = base.get("input") if len(tasks) == 1 and base.get("input") else default_input(task)
        a.out_dir = None
        if task == "narr" and not a.kb_ext:
            ext = HERE / "out" / "fix_narr" / "kb_ext.jsonl"
            if args.enrich or ext.exists():
                a.kb_ext = str(ext)
                print(f"[queue] 知识补充文件：{ext}" + ("" if ext.exists() or cmd == "enrich" else "（还没有）"), flush=True)
        t0 = time.time()
        try:
            rep = (cmd_enrich if cmd == "enrich" else cmd_run)(a)
            results.append((title, "完成", time.time() - t0, rep))
        except SystemExit as e:
            results.append((title, f"中止：{e}", time.time() - t0, None))
        except Exception as e:  # noqa: BLE001
            results.append((title, f"出错：{type(e).__name__}: {e}", time.time() - t0, None))
    print(f"\n{'=' * 18} 全部结束（{_hms(time.time() - t_all)}）{'=' * 18}")
    for title, st, el, rep in results:
        extra = ""
        if rep and rep.get("outcome"):
            extra = "  " + " ".join(f"{STATUS_CN.get(k, k)} {v}" for k, v in rep["outcome"].items() if isinstance(v, int) and v)
        elif rep and rep.get("done_now"):
            extra = "  " + " ".join(f"{ENRICH_CN.get(k, k)} {v}" for k, v in rep["done_now"].items() if v)
        print(f"- {title}：{st}（{_hms(el)}）{extra}")
    final = collect_final(results)
    print(f"\n最终结果都在 {final}：")
    for f in sorted(final.iterdir()):
        print(f"  {f.name:<28} {f.stat().st_size / 1e6:8.1f} MB")


FINAL_NAMES = {  # out/final 下的文件名：(来源目录, 来源文件) → 名称
    ("fix_cs", "fixed.json"): "客服会话_修正后.json", ("fix_cs", "fixed_l1.jsonl"): "客服会话_标注交付L1.jsonl",
    ("fix_cs", "fixed_sidecar.jsonl"): "客服会话_溯源sidecar.jsonl", ("fix_cs", "dropped.jsonl"): "客服会话_剔除.jsonl",
    ("fix_cs", "report.md"): "客服会话_修正报告.md",
    ("fix_narr", "fixed.json"): "个性化讲解_修正后.json", ("fix_narr", "fixed_l1.jsonl"): "个性化讲解_标注交付L1.jsonl",
    ("fix_narr", "fixed_sidecar.jsonl"): "个性化讲解_溯源sidecar.jsonl", ("fix_narr", "dropped.jsonl"): "个性化讲解_剔除.jsonl",
    ("fix_narr", "report.md"): "个性化讲解_修正报告.md", ("fix_narr", "kb_ext.jsonl"): "讲解知识补充.jsonl",
    ("fix_cs", "fix_log.jsonl"): "客服会话_修正记录.jsonl", ("fix_narr", "fix_log.jsonl"): "个性化讲解_修正记录.jsonl",
    ("fix_cs", "compare.jsonl"): "客服会话_改动对照.jsonl", ("fix_narr", "compare.jsonl"): "个性化讲解_改动对照.jsonl",
}


def collect_final(results=None):
    """把两份最终数据汇总到 out/final/（中文文件名；同一磁盘用硬链接，不多占空间），再写一份总报告。原始输入不动。"""
    import shutil
    final = HERE / "out" / "final"
    final.mkdir(parents=True, exist_ok=True)
    for (sub, fn), name in FINAL_NAMES.items():
        src, dst = HERE / "out" / sub / fn, final / name
        if not src.exists():
            continue
        if dst.exists():
            dst.unlink()
        try:
            os.link(src, dst)
        except OSError:
            shutil.copy2(src, dst)
    lines = [f"# 数据修正总报告（{FIX_VERSION}，{datetime.now():%Y-%m-%d %H:%M}）", ""]
    for title, st, el, rep in results or []:
        lines.append(f"- {title}：{st}，用时 {_hms(el)}")
    lines.append("")
    for sub, name in (("fix_cs", "客服会话"), ("fix_narr", "个性化讲解")):
        f = HERE / "out" / sub / "report.md"
        if f.exists():
            lines += [f.read_text(encoding="utf-8").replace("# 修正报告：", "## "), ""]
    ext = HERE / "out" / "fix_narr" / "kb_ext.jsonl"
    if ext.exists():
        n_units = n_facts = 0
        with open(ext, encoding="utf-8") as fh:
            for line in fh:
                x = json.loads(line)
                if x.get("status") == "ok":
                    n_units += 1
                    n_facts += len(x.get("facts") or [])
        lines += ["## 讲解知识补充", "", f"补过的讲解对象 {n_units} 个，补充事实 {n_facts} 条（标注时按 source_url 抽查）", ""]
    lines += ["## 文件", "", "- `*_修正后.json`：全量数据，结构和输入完全一致（含 source；没改的原样保留，剔除的不在里面）",
              "- `*_修正记录.jsonl`：每条改了什么（按 ID 对应，不写进数据本身）；`*_改动对照.jsonl`：抽样的原文 / 修正后并排，评估用",
              "- `*_标注交付L1.jsonl` / `*_溯源sidecar.jsonl`：标注交付用（同一个 ID 关联）",
              "- `*_剔除.jsonl`：剔除的和原因；`*_修正报告.md`：修正前后对比；`讲解知识补充.jsonl`：补充的知识和出处", ""]
    (final / "总报告.md").write_text("\n".join(lines), encoding="utf-8")
    return final


def report_md(rep):
    b, a = rep["before"], rep["after"]
    keys = [k for k in b if k in a] + [k for k in a if k not in b]
    lines = [f"# 修正报告：{TASKS[rep['task']]['name']}（{rep['fix_version']}）", "",
             f"结果：{json.dumps(rep['outcome'], ensure_ascii=False)}；还没调模型的：{rep['pending_llm']}", "",
             "| 指标 | 修正前 | 修正后 |", "|---|---|---|"]
    for k in keys:
        lines.append(f"| {k} | {b.get(k, '')} | {a.get(k, '')} |")
    if rep.get("dropped_reasons"):
        lines += ["", "剔除原因：", ""] + [f"- {k}：{v}" for k, v in rep["dropped_reasons"].items()]
    sm = (rep.get("structure") or {}).get("mismatch")
    if sm is not None:
        lines += ["", "结构检查：" + ("全部和输入一致（字段名、顺序、类型、列表元素字段，含 source）" if not sm else f"⚠ {sm} 条不一致，见 structure_diff.jsonl")]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="已交付训练数据修正（客服会话 / 个性化讲解），模型用火山方舟。数据默认读 tools/q_data。",
                                 epilog=__doc__.split("======================================================================== 输出")[0].split("完整命令", 1)[1],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["all", "check", "scan", "run", "merge", "enrich"],
                    help="all = 排队把两份数据都处理完（推荐）；其余是单步")
    ap.add_argument("--task", choices=list(TASKS), help="scan / run / merge 必填；enrich 不用")
    ap.add_argument("--tasks", default="cs,narr", help="all：处理哪些，默认 cs,narr（客服会话、个性化讲解）")
    ap.add_argument("--enrich", action="store_true", help="all：个性化讲解修正前先做知识补充（联网，带出处）")
    ap.add_argument("--in", dest="input", help="输入：JSON 数组或 JSONL（客户交付的 客服会话.json / 个性化讲解.json）")
    ap.add_argument("--out-dir")
    ap.add_argument("--model", help="方舟模型 ID / 推理接入点 ID（不填：环境变量 ARK_MODEL，再不填用工作台设置页的模型）")
    ap.add_argument("--profile", default=str(HERE / ".pw-profile-service"), help="工作台用的浏览器目录（读里面的设置；默认和工作台服务一样）")
    ap.add_argument("--web-search", choices=["on", "off"], help="这次调用开不开联网搜索（不填：修正默认关、知识补充默认开；也可用环境变量）")
    ap.add_argument("--max-keyword", type=int, help="联网搜索每次最多几个关键词（默认用设置页的，再默认 3）")
    ap.add_argument("--step", choices=["fix", "enrich"], default="fix", help="check 时按哪一步的配置测试")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--limit", type=int, default=0, help="这次最多修几条（0 = 全部；先小批试跑）")
    ap.add_argument("--attempts", type=int, default=2, help="每条最多问模型几次（第 2 次带上没过的原因）")
    ap.add_argument("--sample", type=int, default=300, help="改动对照（compare.jsonl）最多抽几条")
    ap.add_argument("--retries", type=int, default=3, help="调用失败（网络 / 超时 / 限流 / 5xx / 返回不是 JSON）最多重试几次，默认 3")
    ap.add_argument("--timeout", type=float, default=120)
    ap.add_argument("--no-merge", action="store_true", help="run 完不合并导出")
    ap.add_argument("--keep-template", type=float, default=0.2, help="客服：套话「以景区官方公告为准」保留多少（其余改成自然引导）")
    ap.add_argument("--no-diversify", action="store_true", help="客服：不改套话")
    ap.add_argument("--keep-order-conflict", action="store_true", help="客服：订单和「不支持线上购票」矛盾的会话保留（标需复核），默认剔除")
    ap.add_argument("--returning-rate", type=float, default=0.4, help="客服：回头客比例（复用同城 visitor_id），0 = 不改")
    ap.add_argument("--rebalance-limits", action="store_true",
                    help="讲解：字数上限 120 → 手册的 100（超的模型压缩）；有 --kb-ext 时再挑约 10%% 知识够多的改 500 字并扩写")
    ap.add_argument("--kb-ext", help="enrich 的输出 kb_ext.jsonl：run / merge 时把补充的知识并进 sub_poi_knowledge.facts")
    ap.add_argument("--relabel-scene", action="store_true", help="讲解：讲的是景区本身（不是子景点）的，scene 改成「景区个性化讲解生成」")
    args = ap.parse_args()
    DIVERSIFY.update(on=not args.no_diversify, keep=args.keep_template)
    OPTS.update(keep_order_conflict=args.keep_order_conflict)
    RETRY.update(n=max(0, args.retries))
    if args.cmd in ("scan", "run", "merge") and not args.task:
        ap.error("scan / run / merge 要 --task cs 或 narr")
    if args.cmd in ("enrich", "check"):
        args.task = args.task or "narr"
    if args.cmd in ("scan", "run", "merge", "enrich") and not args.input:
        args.input = default_input(args.task)  # 默认读 tools/q_data 下的数据
    {"all": cmd_all, "check": cmd_check, "scan": cmd_scan, "run": cmd_run, "merge": cmd_merge, "enrich": cmd_enrich}[args.cmd](args)


if __name__ == "__main__":
    main()
