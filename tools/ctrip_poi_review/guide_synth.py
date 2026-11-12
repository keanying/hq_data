"""讲解类训练数据：① 讲解内容评价（guide_eval） ② 子景点个性化讲解（guide_narr）。输出 = 需求方给的样例结构 + 标准答案 + source。

知识来源（--kb，逗号分隔，默认全部）：
    guide   景区讲解包：每条讲解（一个景点 / 主题）的事实，带出处（data/guide/）
    redqa   RedAttractionQA：能唯一对到景区的段落，每 5 条一组（data/redqa/）
    scenic  客户景区表的基础资料：简介、等级、称号、文保、主要景点、面积、山水、游玩时长、季节（景区本体）

① 讲解内容评价：模型按知识库写一段讲解员口述（guide_clip_txt，文字，不是录音），程序事先定好要故意放进几处问题
   （0～3 处：年代错误 / 数字错误 / 结构材质错误 / 无依据说法 / 夸大绝对化），模型逐字标出；
   eval_result（标准答案）= 错误清单 + 讲对了哪些 / 漏了哪些 + 口头禅统计 + 分数 + 结论，分数和结论由程序按固定规则算。
② 个性化讲解：程序合成一个前后一致的游客画像（标为合成）和任务参数，模型只用子景点知识写参考讲解词（reference_narration）。

    python guide_synth.py --task eval --limit 20
    python guide_synth.py --task narr --scenic-city 北京市 --variants 3 --limit 0 --mysql
    python guide_synth.py --task eval --preview

规模 = 知识单元数 × 每单元几版（--variants）。可断点续跑（out/guide_<task>_* 的 done_keys.txt）。
--mysql 写进 dwd_guide_eval_sample_di / dwd_guide_narration_sample_di（自动建表，表名可用环境变量 GUIDE_EVAL_TABLE / GUIDE_NARR_TABLE 改）。
"""
import argparse
import csv
import hashlib
import json
import re
import threading
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime, timedelta
from pathlib import Path

import ai_judge
import cs_expand
import cs_sources
import cs_synth
from cs_synth import _seeded

PROMPT_VERSION = {"eval": "guide_eval_v1", "narr": "guide_narr_v1"}
OUT_ROOT = cs_synth.OUT_ROOT
EVAL_TABLE = cs_synth._env("GUIDE_EVAL_TABLE", "dwd_guide_eval_sample_di")
NARR_TABLE = cs_synth._env("GUIDE_NARR_TABLE", "dwd_guide_narration_sample_di")
KB_SOURCES = ("guide", "redqa", "scenic")
KB_NAME = {"guide": "景区讲解包（公开资料整理，带出处）", "redqa": "RedAttractionQA（公开数据集）", "scenic": "客户景区基础表"}
TASK_NAME = {"eval": "讲解内容评价", "narr": "子景点个性化讲解生成"}

# ---------------------------------------------------------------- 知识单元
SCENIC_FACTS = [("scenic_desc", "景区简介"), ("scenic_grade_level", "等级"), ("scenic_national_title", "称号"), ("scenic_heritage_cert", "文保 / 遗产认定"),
                ("scenic_core_spots", "主要景点"), ("scenic_area_mu", "面积"), ("scenic_mountain_river", "山水资源"),
                ("suggest_duration_desc", "建议游玩时长"), ("best_season_desc", "最佳游玩季节"), ("scenic_main_type", "景区类型")]
COVERAGE_RULES = [
    ("历史沿革", r"始建|建于|年代|朝|世纪|年间|重建|重修|修复|沿革|历史|倒塌|改名|迁"),
    ("建筑形制", r"结构|建筑|形制|布局|屋顶|歇山|庑殿|层|面阔|进深|台基|砖|木构|石砌|琉璃|高\s*\d|通高"),
    ("文物藏品", r"文物|出土|藏品|馆藏|展品|舍利|铜|瓷|碑|造像|塑像|佛像|壁画"),
    ("文学传说", r"传说|故事|诗|文学|典故|相传"),
    ("功能用途", r"用途|功能|用于|寝宫|理政|祭|典礼|举行|居住"),
    ("人物事件", r"皇帝|帝|太后|王|将军|事件|战役|起义|会议|烈士|革命"),
    ("文化地位", r"地位|十景|遗产|保护单位|称号|等级|示范|基地|名录|A级|\dA"),
    ("自然景观", r"山峰|山体|山脉|湖泊|湖面|森林|植被|海拔|地貌|峡谷|瀑布|溪流|湿地|溶洞"),
    ("游览信息", r"开放|时长|游玩|季节|路线|小时"),
]


def _scenic_unit(row):
    facts = []
    for col, label in SCENIC_FACTS:
        v = cs_expand.fmt_value(col, row.get(col))
        if v:
            facts.append(dict(seq=len(facts) + 1, attr=label, value=v, source_ids=[f"{row['_id']}:{col}"]))
    if len(facts) < 4 or not any(f["attr"] == "景区简介" for f in facts):
        return None
    return dict(unit_id=f"scenic:{row['_id']}", kind="scenic", spot=row["_name"], relation="", topic="景区概况", title="", scope="", facts=facts,
                poi_id=None, version=str(row.get("update_time") or "")[:10] or None,
                sources=[dict(source_id=f"{row['_id']}", url=None, title=row["_name"], publisher="客户景区基础表", type="客户数据")])


def _kb(args):
    k = [x.strip() for x in (getattr(args, "kb", "") or "").split(",") if x.strip() in KB_SOURCES]
    return k or list(KB_SOURCES)


def load_units(args, rows, log=print):
    """选中景区的知识单元 {scenic_id: [单元]}。"""
    kb = _kb(args)
    units = {}
    if "guide" in kb:
        for sid, us in cs_sources.load_guide(args.data_dir, log).items():
            units.setdefault(sid, []).extend(us)
    if "redqa" in kb:
        cs_sources.build_cache(args.data_dir, cs_expand.REF_CACHE, log)
        for sid, us in cs_sources.map_redqa(cs_sources.load_redqa(cs_expand.REF_CACHE), rows, cs_synth._core).items():
            units.setdefault(sid, []).extend(us)
    ids = {r["_id"] for r in rows}
    units = {sid: us for sid, us in units.items() if sid in ids}
    if "scenic" in kb:
        for r in rows:
            u = _scenic_unit(r)
            if u:
                units.setdefault(r["_id"], []).append(u)
    return units


def coverage(facts):
    text = " ".join(f"{f['attr']} {f['value']}" for f in facts)
    return [name for name, rx in COVERAGE_RULES if re.search(rx, text)]


def _main_poi(row):
    """景区的携程主 POI：已审核的 ctrip_poi_info 里和景区同名的，没有就第一个。"""
    import db
    pois = db._parse_info(row.get(db.POI_INFO_NAME)) if Number(row.get(db.APPROVAL_NAME)) == 1 else []
    if not pois:
        return None
    same = [p for p in pois if (p.get("poiName") or "") in (row["_name"] or "") or (row["_name"] or "") in (p.get("poiName") or "")]
    p = (same or pois)[0]
    return _int(p.get("poiId"))


def Number(v):  # noqa: N802
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 0


def _int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return v or None


def _place(row):
    return dict(province=row.get("province_name"), city=row.get("city_name"), district=row.get("district_name"))


def _sub_seq(u):
    m = re.search(r"_(\d{3})$", u["unit_id"])
    if m:
        return m.group(1)
    m = re.search(r"redqa:[^:]+:(\d+)$", u["unit_id"])
    return f"R{int(m.group(1)):02d}" if m else "000"


def _fid(prefix, key, rnd):
    day = datetime(2026, 1, 1) + timedelta(days=rnd.randint(0, 364))
    h = int(hashlib.sha1(key.encode()).hexdigest()[:12], 16) % 100000000
    return f"{prefix}_{day:%Y%m%d}_{h:08d}", day


# ---------------------------------------------------------------- ① 讲解内容评价
ERROR_TYPES = {
    "年代错误": (r"\d{3,4}\s*年|[一二三四五六七八九十]+年|朝|世纪|年间", "把这条里的年代 / 朝代说错（换成别的朝代或年份），说得像真的一样"),
    "数字错误": (r"\d+(?:\.\d+)?\s*(?:米|平方米|亩|层|间|件|座|尊|公里|万|个|位|株|级)", "把这条里的数字说错（明显偏大或偏小）"),
    "结构材质错误": (r"结构|砖|木|石|琉璃|形制|歇山|庑殿|楼阁|工字", "把这条里的结构 / 材质 / 形制说错"),
    "无依据说法": (None, "说一个知识库里没有的具体细节，当作事实讲（话题从你写的 gaps 里选一个）"),
    "夸大绝对化": (None, "用「一模一样」「全国唯一」「最古老」这类夸大 / 绝对化说法（知识库没有依据的）"),
}
SEVERITY = {"年代错误": "高", "数字错误": "高", "结构材质错误": "高", "无依据说法": "中", "夸大绝对化": "低"}
STYLE = [("口语很多，带「嗯」「呃」「那个」「啊」等口头禅和重复，像录音转写", 3), ("口语适中，偶尔有「嗯」「啊」", 2), ("比较流畅的口头讲解，几乎没有口头禅", 1)]
FILLER_RE = re.compile(r"嗯|呃|额|那个|这个呢|然后呢|对吧|啊[，。…]|哈[，。…]")


def plan_errors(u, rnd):
    """这一版放几处问题、放哪种、对哪条事实。"""
    n = rnd.choices([0, 1, 2, 3], weights=[20, 35, 30, 15])[0]
    cands = []
    for et, (rx, _) in ERROR_TYPES.items():
        if rx is None:
            cands.append((et, None))
            continue
        for f in u["facts"]:
            if re.search(rx, f["value"]):
                cands.append((et, f["attr"]))
    rnd.shuffle(cands)
    out, used = [], set()
    for et, attr in cands:
        if len(out) >= n:
            break
        if (attr and attr in used) or (et in ("无依据说法", "夸大绝对化") and any(x[0] == et for x in out)):
            continue
        out.append((et, attr))
        if attr:
            used.add(attr)
    return out


def eval_prompt(row, u, plan):
    facts = "\n".join(f"- {f['attr']}：{f['value']}" for f in u["facts"])
    if plan["errors"]:
        errs = "\n".join(f"   - {et}：" + (f"对「{attr}」这一条，" if attr else "") + ERROR_TYPES[et][1] for et, attr in plan["errors"])
        rule2 = f"2. 必须故意放进下面 {len(plan['errors'])} 处问题（全部放进去，且只放这些），并在 JSON 里逐字标出原话：\n{errs}"
    else:
        rule2 = "2. 这一版不放任何问题：所有内容都要和知识库一致，不要出现知识库以外的具体细节、数字、人名，也不要夸大；errors / unsupported / exaggerations 都输出空数组。"
    return f"""你在做「讲解内容评价」训练数据。下面是「{row['_name']}」里「{u['spot']}」的知识库条目。请写一段讲解员现场给游客讲解的文字（{plan['style'][0]}），按要求故意放进问题，并如实标注。

【知识库】（{KB_NAME[u['kind']]}）
{facts}

要求：
1. 讲解 {plan['len'][0]}～{plan['len'][1]} 字，像讲解员边走边说；讲到知识库里的 {plan['k']} 条左右内容，没讲的条目不要硬塞。
{rule2}
3. 除了故意放进去的问题，其他内容必须和知识库一致；不要出现知识库里没有的数字、年代、人名。
4. gaps：写 2 个游客可能会问、但这个知识库没有覆盖的具体话题（如「塔内电梯品牌」「各层壁画作者署名」），不能是知识库里已有的内容。
5. said 必须是 guide_text 里逐字连续的一段原话；correct 写知识库里的正确说法。covered_attrs 只写讲对了的条目名（用知识库里的条目名）。

只输出一个 JSON 对象：
{{"gaps":["",""],"guide_text":"讲解文字","errors":[{{"type":"年代错误/数字错误/结构材质错误","attr":"知识库条目名","said":"原话","correct":"正确说法"}}],
 "unsupported":[{{"said":"原话","topic":"对应话题"}}],"exaggerations":[{{"said":"原话"}}],"covered_attrs":["条目名"],"suggestions":["给讲解员的 1～2 条修改建议"]}}"""


def _nums(text):
    return set(re.findall(r"\d+(?:\.\d+)?", text or ""))


def eval_result(u, plan, js):
    """标准答案：程序核对模型的标注，按固定规则算分。返回 (eval_result, check_flags)。"""
    text = str(js.get("guide_text") or "")
    attrs = {f["attr"]: f["value"] for f in u["facts"]}
    flags = []
    errors = []
    for e in js.get("errors") or []:
        said = str(e.get("said") or "").strip()
        et = e.get("type") if e.get("type") in SEVERITY else "事实错误"
        if not said or said not in text:
            flags.append(f"标注的原话在讲解里找不到：{said[:20]}")
            continue
        attr = e.get("attr") if e.get("attr") in attrs else None
        if not attr:
            flags.append(f"错误标注的条目不在知识库：{e.get('attr')}")
        errors.append(dict(type=et, attr=attr, guide_said=said, kb_value=attrs.get(attr) or e.get("correct"), severity=SEVERITY.get(et, "高")))
    unsupported = [dict(guide_said=str(x.get("said")).strip(), topic=x.get("topic"), severity="中") for x in js.get("unsupported") or []
                   if str(x.get("said") or "").strip() in text and str(x.get("said") or "").strip()]
    exaggerations = [dict(guide_said=str(x.get("said")).strip(), severity="低") for x in js.get("exaggerations") or []
                     if str(x.get("said") or "").strip() in text and str(x.get("said") or "").strip()]
    for x in (js.get("unsupported") or []) + (js.get("exaggerations") or []):
        said = str(x.get("said") or "").strip()
        if said and said not in text:
            flags.append(f"标注的原话在讲解里找不到：{said[:20]}")
    want = len(plan["errors"])
    got = len(errors) + len(unsupported) + len(exaggerations)
    if got != want:
        flags.append(f"要求放 {want} 处问题，标出 {got} 处")
    marked = " ".join(x["guide_said"] for x in errors + unsupported + exaggerations)
    kb_text = " ".join(attrs.values())
    extra = sorted(n for n in _nums(text) - _nums(kb_text) if n not in _nums(marked))
    if extra:
        flags.append("讲解里有知识库没有、也没标出来的数字：" + "、".join(extra[:5]))
    covered = [a for a in js.get("covered_attrs") or [] if a in attrs and a not in {e["attr"] for e in errors}]
    missed = [a for a in attrs if a not in covered and a not in {e["attr"] for e in errors}]
    fillers = FILLER_RE.findall(text)
    acc = max(0, 100 - 25 * len(errors) - 15 * len(unsupported) - 10 * len(exaggerations))
    comp = round(100 * len(covered) / max(1, len(attrs)))
    expr = max(60, 100 - 3 * len(fillers))
    total = round(0.5 * acc + 0.3 * comp + 0.2 * expr, 1)
    high = any(e["severity"] == "高" for e in errors)
    verdict = "不合格" if (acc < 70 or high) else ("合格" if (not errors and not unsupported and not exaggerations and total >= 75) else "需改进")
    res = dict(verdict=verdict, scores=dict(准确性=acc, 完整性=comp, 表达=expr, 总分=total),
               errors=errors, unsupported=unsupported, exaggerations=exaggerations, covered_facts=covered, missed_facts=missed,
               disfluency=dict(filler_count=len(fillers), examples=sorted(set(fillers))[:6]),
               suggestions=[str(x) for x in (js.get("suggestions") or [])][:3],
               scoring_rule="准确性 = 100 − 25×事实错误 − 15×无依据 − 10×夸大；完整性 = 讲对的条目 / 全部条目；表达 = 100 − 3×口头禅（不低于 60）；"
                            "总分 = 0.5×准确 + 0.3×完整 + 0.2×表达；有高严重度错误或准确性 < 70 为不合格，无问题且总分 ≥ 75 为合格，其余需改进")
    return res, flags


# ---------------------------------------------------------------- ② 个性化讲解
GROUPS = [("G01", "亲子家庭", (28, 45)), ("G02", "情侣出游", (22, 35)), ("G03", "朋友结伴", (20, 35)), ("G04", "银发出游", (60, 75)),
          ("G05", "独自旅行", (22, 45)), ("G06", "商务差旅", (26, 50)), ("G07", "研学学生", (12, 17)), ("G08", "三代同堂", (30, 50))]
CITIES = [("北京市", "北京市", "一线"), ("上海市", "上海市", "一线"), ("广东省", "广州市", "一线"), ("广东省", "深圳市", "一线"), ("四川省", "成都市", "新一线"),
          ("浙江省", "杭州市", "新一线"), ("湖北省", "武汉市", "新一线"), ("陕西省", "西安市", "新一线"), ("江苏省", "南京市", "新一线"),
          ("重庆市", "重庆市", "新一线"), ("天津市", "天津市", "新一线"), ("湖南省", "长沙市", "新一线"), ("河南省", "郑州市", "新一线"),
          ("山东省", "青岛市", "新一线"), ("江苏省", "苏州市", "新一线"), ("福建省", "厦门市", "二线"), ("辽宁省", "大连市", "二线"),
          ("云南省", "昆明市", "二线"), ("山东省", "济南市", "二线"), ("黑龙江省", "哈尔滨市", "二线"), ("江西省", "南昌市", "二线"),
          ("广西壮族自治区", "南宁市", "二线"), ("河北省", "石家庄市", "二线"), ("安徽省", "芜湖市", "三线"), ("广东省", "汕头市", "三线"),
          ("江苏省", "扬州市", "三线"), ("湖南省", "岳阳市", "三线"), ("河南省", "洛阳市", "三线"), ("甘肃省", "天水市", "四线"), ("四川省", "乐山市", "四线")]
CATS = ["人文景观", "博物馆", "历史遗迹", "自然风光", "主题乐园", "红色旅游", "宗教文化", "城市地标", "古镇古村", "动植物园"]
INTERESTS = ["宫廷史", "建筑美学", "摄影", "历史故事", "民俗文化", "亲子科普", "红色文化", "书画艺术", "宗教文化", "自然科普", "诗词文学", "考古", "文创"]
TABOO_BASE = ["不得编造具体数字（如未收录的面积、数量、年份）", "不得渲染野史传闻"]


def age_band(a):
    for hi, b in ((17, "≤17"), (25, "18-25"), (35, "26-35"), (45, "36-45"), (55, "46-55"), (65, "56-65")):
        if a <= hi:
            return b
    return "66+"


def make_profile(rnd, row, req_day):
    """合成一个前后一致的游客画像（字段和样例一致；标为合成）。"""
    code, gname, (lo, hi) = rnd.choice(GROUPS)
    age = rnd.randint(lo, hi)
    adults, kids, elders, kid_ages, desc = 1, 0, 0, None, "单人出行"
    if code == "G01":
        adults, kids = rnd.choice([1, 2]), rnd.choice([1, 1, 2])
        kid_ages = sorted(rnd.randint(3, 12) for _ in range(kids))
        desc = ("父母" if adults == 2 else "单亲") + f"带{kids}个孩子"
    elif code == "G02":
        adults, desc = 2, "情侣二人"
    elif code == "G03":
        adults = rnd.randint(3, 5)
        desc = f"朋友{adults}人"
    elif code == "G04":
        adults, elders, desc = 0, 2, "老年夫妻二人"
    elif code == "G06":
        adults = rnd.choice([1, 2])
        desc = "单人出差顺路游览" if adults == 1 else "同事二人"
    elif code == "G07":  # 游客本人是学生（算 1 个儿童），带队老师同行
        adults, kids, kid_ages, desc = 1, 1, [age], "学校 / 机构研学团（带队老师同行）"
    elif code == "G08":
        adults, kids, elders = 2, 1, 2
        kid_ages = [rnd.randint(4, 12)]
        desc = "三代同堂（父母、孩子、老人）"
    prov, city, tier = rnd.choice(CITIES)
    income = "无" if code == "G07" else rnd.choice(["中", "中高", "高"] if tier in ("一线", "新一线") else ["低", "中", "中", "中高"])
    sens = {"无": "高", "低": "高", "中": rnd.choice(["中", "高"]), "中高": rnd.choice(["中", "低"]), "高": "低"}[income]
    stype = str(row.get("scenic_main_type") or "")
    cats = (["博物馆", "人文景观", "历史遗迹"] if re.search(r"文化|历史|场馆", stype) else ["自然风光", "人文景观"]) + CATS
    top3 = []
    for c in cats if rnd.random() < 0.7 else rnd.sample(CATS, len(CATS)):
        if c not in top3:
            top3.append(c)
        if len(top3) == 3:
            break
    pool = INTERESTS[:]
    if code in ("G01", "G08"):
        pool += ["亲子科普"] * 2
    if code == "G07":
        pool += ["历史故事", "考古"]
    tags = []
    for t in rnd.sample(pool, len(pool)):
        if t not in tags:
            tags.append(t)
        if len(tags) == rnd.choice([2, 3]):
            break
    sex = rnd.choice(["男", "女"])
    return {"visitor_id": f"V{rnd.randint(10000000, 99999999)}", "性别": sex, "年龄": age, "年龄段": age_band(age),
            "客源省份": prov, "客源城市": city, "客源城市等级": tier, "出游客群编码": code, "出游客群名称": gname,
            "同行结构描述": desc, "同行成人数": adults, "同行儿童数": kids, "同行长者数": elders, "儿童年龄": (kid_ages[0] if kid_ages and len(kid_ages) == 1 else kid_ages),
            "收入水平": income, "价格敏感度": sens, "会员等级": f"V{rnd.randint(0, 5)}",
            "首选购票渠道": rnd.choice(["现场购票", "公众号", "小程序"] if code == "G04" else ["小程序", "APP", "OTA平台", "公众号", "小程序"]),
            "提前预订习惯": rnd.choice(["当天", "提前1-2天", "提前3-7天", "提前一周以上"]), "年出游次数": rnd.randint(1, 12),
            "偏好景区类别Top3": top3, "兴趣标签": tags, "客户价值分层": rnd.choice(["高价值", "中价值", "中价值", "低价值", "新客"]),
            "最近到访日期": req_day.strftime("%Y-%m-%d")}


def taboos_for(u, row):
    text = " ".join(f["value"] for f in u["facts"]) + " " + str(row.get("scenic_main_type") or "")
    t = list(TABOO_BASE)
    if re.search(r"传说|相传|故事", text):
        t.append("传说内容须说明是传说，不得当作史实")
    if re.search(r"革命|烈士|战役|起义|红军|抗日|纪念馆", text) or u["kind"] == "redqa":
        t.append("不得戏说、调侃革命历史和英烈")
    if re.search(r"寺|佛|道观|宗教|庙|教堂|清真", text):
        t.append("不得评论宗教信仰")
    return t


def visit_rules_for(row):
    """只用景区表里真实有的：最晚入园、特殊开放规则（没有就空）。"""
    r = []
    t = cs_expand.fmt_value("last_entry_time", row.get("last_entry_time"))
    if t:
        r.append(f"最晚入园时间 {t}")
    s = cs_expand.fmt_value("special_open_rule_desc", row.get("special_open_rule_desc"))
    if s:
        r.append(s if len(s) <= 80 else s[:78] + "…")
    return r


def narr_prompt(row, u, plan):
    p, tp = plan["profile"], plan["task_params"]
    facts = "\n".join(f"- {f['attr']}：{f['value']}" for f in u["facts"])
    prof = (f"{p['性别']}，{p['年龄']}岁，{p['出游客群名称']}（{p['同行结构描述']}）" + (f"，孩子 {p['儿童年龄']} 岁" if p["同行儿童数"] else "")
            + f"；来自{p['客源城市']}；兴趣：{'、'.join(p['兴趣标签'])}；偏好：{'、'.join(p['偏好景区类别Top3'])}；年出游 {p['年出游次数']} 次")
    style = tp["讲解风格"] or "未指定（按画像选合适的风格）"
    rules = "\n".join(f"- {x}" for x in plan["visit_rules"]) or "（无）"
    return f"""你在做「子景点个性化讲解」训练数据。请为下面这位游客写一段讲解词。

景区：{row['_name']}；子景点：{u['spot']}；游客当前位置：{tp['当前所处位置']}

【子景点知识】（只能用这里的事实）
{facts}

【禁忌】{'；'.join(plan['taboos'])}
【参观须知】
{rules}
【游客画像】{prof}
【任务】字数上限 {tp['字数上限']} 字；风格：{style}；语言：{tp['输出语言']}；禁止：{'、'.join(tp['禁止事项'])}

要求：
1. 只用【子景点知识】里的事实，数字、年代原样；用不完可以不说；不要补充知识以外的细节、传说、数字。
2. 结合画像：先讲和兴趣相关的内容，语气、称呼贴合客群（独自旅行、亲子、银发……）；有孩子要说得孩子听得懂；风格未指定时自己选并写进 style。
3. 从当前位置自然开场；参观须知里和眼前有关的，可以温和提醒一句（没有就不提）。
4. 不用「最」「唯一」「第一」「绝对」等绝对化说法（知识里原话除外），不推销门票、商品、服务。
5. 正文不超过 {tp['字数上限']} 字。

只输出一个 JSON 对象：
{{"text":"讲解词","used_attrs":["用到的知识条目名"],"personalization":["针对画像做了哪些调整，1～3 条"],"style":"实际采用的风格"}}"""


ABS_RE = re.compile(r"最[一-鿿]{1,2}|唯一|第一|绝对|顶级|无与伦比")
SALES_RE = re.compile(r"购买|下单|优惠|折扣|买票|门票|会员|特价|套餐|文创店|商店|扫码")


def narr_check(u, plan, js):
    text = str(js.get("text") or "").strip()
    kb_text = " ".join(f["value"] for f in u["facts"])
    flags = []
    n = len(re.sub(r"\s", "", text))
    if not text:
        raise ValueError("没有讲解词")
    if n > plan["task_params"]["字数上限"]:
        flags.append(f"超出字数上限（{n} > {plan['task_params']['字数上限']}）")
    extra = sorted(_nums(text) - _nums(kb_text) - _nums(" ".join(plan["visit_rules"])))
    if extra:
        flags.append("讲解词里有知识没有的数字：" + "、".join(extra[:5]))
    for m in set(ABS_RE.findall(text)):
        if m not in kb_text:
            flags.append(f"绝对化表述「{m}」")
    for m in set(SALES_RE.findall(text)):
        flags.append(f"疑似推销「{m}」")
    if re.search(r"相传|传说|据说|野史", text) and not re.search(r"相传|传说|据说", kb_text):
        flags.append("讲了知识里没有的传说 / 据说")
    attrs = {f["attr"] for f in u["facts"]}
    used = [a for a in js.get("used_attrs") or [] if a in attrs]
    ref = dict(text=text, char_count=n, used_facts=used, personalization=[str(x) for x in (js.get("personalization") or [])][:3],
               style=js.get("style") or plan["task_params"]["讲解风格"])
    return ref, sorted(set(flags))


# ---------------------------------------------------------------- 组装
def plan_item(task, row, u, v, seed):
    rnd = _seeded(seed, "guide", task, row["_id"], u["unit_id"], v)
    if task == "eval":
        style = rnd.choice(STYLE)
        k = min(len(u["facts"]), rnd.randint(3, 5))
        return dict(rnd=rnd, errors=plan_errors(u, rnd), style=style, k=k, len=rnd.choice([(150, 220), (200, 300), (250, 350)]))
    day_rnd = _seeded(seed, "guide-day", task, row["_id"], u["unit_id"], v)
    req_id, day = _fid("nar", f"narr|{row['_id']}|{u['unit_id']}|{v}", day_rnd)
    req_time = day.replace(hour=rnd.randint(8, 18), minute=rnd.randint(0, 59), second=rnd.randint(0, 59))
    profile = make_profile(rnd, row, day)
    style = rnd.choice([None, None, "亲切口语", "专业严谨", "故事化"] + (["童趣易懂"] if profile["同行儿童数"] or profile["出游客群编码"] == "G07" else []))
    tp = {"字数上限": rnd.choice([120, 150, 200, 200, 300]), "讲解风格": style, "输出语言": "zh-CN",
          "禁止事项": ["编造未收录事实", "绝对化表述", "商业推销"], "当前所处位置": f"{u['spot']}{rnd.choice(['门前', '入口处', '附近'])}"}
    return dict(rnd=rnd, request_id=req_id, request_time=req_time, profile=profile, task_params=tp, taboos=taboos_for(u, row), visit_rules=visit_rules_for(row))


def kb_id(u):
    return {"guide": u["unit_id"], "redqa": u["unit_id"].replace("redqa:", "RQA_").replace(":", "_"), "scenic": u["unit_id"].replace("scenic:", "SCN_")}[u["kind"]]


def kb_version(u):
    v = str(u.get("version") or "")
    return f"{v[:4]}-{v[4:6]}-{v[6:8]}" if re.fullmatch(r"\d{8}", v) else (v or None)


def _scenic_table():
    import db
    return db.SCENIC_TABLE.strip("`")


def build_record(task, row, u, v, plan, js, cfg):
    facts = [dict(attr=f["attr"], value=f["value"]) for f in u["facts"]]
    src = dict(generate_method=f"llm_{task}", kb_kind=u["kind"], kb_name=KB_NAME[u["kind"]], unit_id=u["unit_id"],
               fact_seq_nos=[f["seq"] for f in u["facts"]], fact_sources=u["sources"], scenic_table=_scenic_table(),
               variant=v, model=cfg.get("ai_model"), prompt_version=PROMPT_VERSION[task], generated_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    if task == "eval":
        res, flags = eval_result(u, plan, js)
        gaps = [str(g) for g in (js.get("gaps") or []) if str(g).strip() and str(g) not in " ".join(f["value"] for f in u["facts"])][:3]
        eid, _ = _fid("ge", f"eval|{row['_id']}|{u['unit_id']}|{v}", _seeded(0, "ge-day", row["_id"], u["unit_id"], v))
        poi_id = _int(u.get("poi_id")) or (_main_poi(row) if u["kind"] == "scenic" or u["spot"] == row["_name"] else None)
        rec = {"eval_task_id": eid,
               "poi": dict(poi_id=poi_id, poi_name=u["spot"], scenic_id=row["_id"], **_place(row)),
               "kb_entry": dict(kb_id=kb_id(u), kb_version=kb_version(u), source=KB_NAME[u["kind"]], facts=facts, coverage=coverage(u["facts"]), gaps=gaps),
               "guide_clip_txt": str(js.get("guide_text") or "").strip(),
               "eval_result": res}
        src.update(text_type="模型生成的讲解员口述文字（非录音、非 ASR）", style=plan["style"][0],
                   planned_issues=[dict(type=et, attr=attr) for et, attr in plan["errors"]], needs_review=bool(flags), check_flags=flags)
        if not rec["guide_clip_txt"]:
            raise ValueError("没有讲解文字")
    else:
        ref, flags = narr_check(u, plan, js)
        rec = {"request_id": plan["request_id"], "scene": TASK_NAME["narr"], "request_time": plan["request_time"].strftime("%Y-%m-%d %H:%M:%S"),
               "poi": dict(poi_id=_main_poi(row), poi_name=row["_name"], scenic_id=row["_id"], sub_poi_id=f"{row['_id']}_{_sub_seq(u)}",
                           sub_poi_name=u["spot"], **_place(row)),
               "sub_poi_knowledge": dict(kb_id=kb_id(u), kb_version=kb_version(u), facts=facts, taboos=plan["taboos"], visit_rules=plan["visit_rules"]),
               "visitor_profile": plan["profile"], "task_params": plan["task_params"], "reference_narration": ref}
        src.update(visitor_profile_type="合成（按客群、年龄、客源地等字段一致性规则生成，非真实游客）", needs_review=bool(flags), check_flags=flags)
    rec["source"] = src
    return rec


# ---------------------------------------------------------------- MySQL
def ddl(task):
    if task == "eval":
        return f"""CREATE TABLE IF NOT EXISTS {EVAL_TABLE} (
  eval_task_id VARCHAR(64) NOT NULL, scenic_id VARCHAR(64) NULL, scenic_name VARCHAR(255) NULL, poi_name VARCHAR(255) NULL, city_name VARCHAR(64) NULL,
  kb_id VARCHAR(128) NULL, kb_kind VARCHAR(16) NULL COMMENT 'guide 讲解包 / redqa / scenic 景区表', issue_cnt INT NULL COMMENT '放进的问题数',
  verdict VARCHAR(16) NULL COMMENT '合格 / 需改进 / 不合格', total_score DECIMAL(5,1) NULL, needs_review TINYINT NULL,
  record_json LONGTEXT NOT NULL COMMENT '完整样本：poi + kb_entry + guide_clip_txt + eval_result + source', travel_date INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (eval_task_id), KEY idx_scenic (scenic_id), KEY idx_date (travel_date)
) DEFAULT CHARSET=utf8mb4 COMMENT='讲解内容评价样本（输入 + 标准答案）'"""
    return f"""CREATE TABLE IF NOT EXISTS {NARR_TABLE} (
  request_id VARCHAR(64) NOT NULL, scenic_id VARCHAR(64) NULL, scenic_name VARCHAR(255) NULL, sub_poi_name VARCHAR(255) NULL, city_name VARCHAR(64) NULL,
  kb_id VARCHAR(128) NULL, kb_kind VARCHAR(16) NULL, visitor_group VARCHAR(32) NULL, char_limit INT NULL, char_count INT NULL, needs_review TINYINT NULL,
  record_json LONGTEXT NOT NULL COMMENT '完整样本：请求 + reference_narration + source', travel_date INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (request_id), KEY idx_scenic (scenic_id), KEY idx_date (travel_date)
) DEFAULT CHARSET=utf8mb4 COMMENT='子景点个性化讲解样本（请求 + 参考讲解词）'"""


def mysql_write(cur, task, rec):
    import db
    js = json.dumps(rec, ensure_ascii=False)
    g = rec["source"]
    if task == "eval":
        t = db.ident(EVAL_TABLE)
        d = int(rec["eval_task_id"].split("_")[1])
        cur.execute(f"""REPLACE INTO {t} (eval_task_id, scenic_id, scenic_name, poi_name, city_name, kb_id, kb_kind, issue_cnt, verdict, total_score, needs_review,
                        record_json, travel_date) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    (rec["eval_task_id"], rec["poi"]["scenic_id"], g.get("scenic_name"), rec["poi"]["poi_name"], rec["poi"]["city"], rec["kb_entry"]["kb_id"],
                     g["kb_kind"], len(g["planned_issues"]), rec["eval_result"]["verdict"], rec["eval_result"]["scores"]["总分"], int(g["needs_review"]), js, d))
    else:
        t = db.ident(NARR_TABLE)
        d = int(rec["request_id"].split("_")[1])
        cur.execute(f"""REPLACE INTO {t} (request_id, scenic_id, scenic_name, sub_poi_name, city_name, kb_id, kb_kind, visitor_group, char_limit, char_count,
                        needs_review, record_json, travel_date) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    (rec["request_id"], rec["poi"]["scenic_id"], rec["poi"]["poi_name"], rec["poi"]["sub_poi_name"], rec["poi"]["city"],
                     rec["sub_poi_knowledge"]["kb_id"], g["kb_kind"], rec["visitor_profile"]["出游客群名称"], rec["task_params"]["字数上限"],
                     rec["reference_narration"]["char_count"], int(g["needs_review"]), js, d))


def load_jsonl(task, path, log=print, should_stop=lambda: False, progress=lambda done, total: None):
    """把批次文件补写进 MySQL（同一 ID 覆盖，不重复）。"""
    import db
    with db.cursor() as cur:
        cur.execute(ddl(task))
    lines = [x for x in Path(path).read_text(encoding="utf-8").splitlines() if x.strip()]
    n = 0
    with db.cursor() as cur:
        for i, line in enumerate(lines, 1):
            if should_stop():
                log("已停止")
                break
            mysql_write(cur, task, json.loads(line))
            n += 1
            if i % 200 == 0 or i == len(lines):
                progress(i, len(lines))
    log(f"已写入 {n} 条到 {table(task).strip('`')}")
    return dict(written=n, total=len(lines))


def table(task):
    import db
    return db.ident(EVAL_TABLE if task == "eval" else NARR_TABLE)


def export_count(task, f):
    import db
    sql, params = _export_where(task, f)
    with db.cursor() as cur:
        cur.execute(ddl(task))
        cur.execute(f"SELECT COUNT(*) n FROM {table(task)}{sql}", params)
        return dict(rows=int(cur.fetchone()["n"] or 0))


def _export_where(task, f):
    where, params = [], []
    if f.get("city"):
        where.append("city_name = %s")
        params.append(f["city"])
    if f.get("scenic"):
        names = [x.strip() for x in re.split(r"[,，]", f["scenic"]) if x.strip()]
        if names:
            where.append("(" + " OR ".join(["scenic_id = %s OR scenic_name LIKE %s"] * len(names)) + ")")
            for x in names:
                params += [x, f"%{x}%"]
    if f.get("review") in ("ok", "review"):
        where.append("needs_review = %s")
        params.append(1 if f["review"] == "review" else 0)
    if task == "eval" and f.get("verdict"):
        where.append("verdict = %s")
        params.append(f["verdict"])
    return (" WHERE " + " AND ".join(where) if where else ""), params


def export_iter(task, f, fmt="jsonl"):
    import io
    import pymysql
    import db
    sql, params = _export_where(task, f)
    lim = int(f.get("limit") or 0)
    conn = pymysql.connect(**{**db.DB, "cursorclass": pymysql.cursors.SSDictCursor})
    key = "eval_task_id" if task == "eval" else "request_id"
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT * FROM {table(task)}{sql} ORDER BY travel_date, {key}" + (f" LIMIT {lim}" if lim else ""), params)
            first = True
            if fmt == "json":
                yield "[\n"
            elif fmt == "csv":
                cols = [c[0] for c in cur.description if c[0] not in ("created_at",)]
                buf = io.StringIO()
                csv.writer(buf).writerow(cols)
                yield "﻿" + buf.getvalue()
            while True:
                rows = cur.fetchmany(500)
                if not rows:
                    break
                out = []
                for r in rows:
                    if fmt == "csv":
                        buf = io.StringIO()
                        csv.writer(buf).writerow([r[c] for c in cols])
                        out.append(buf.getvalue())
                    elif fmt == "json":
                        out.append(("" if first else ",\n") + r["record_json"])
                        first = False
                    else:
                        out.append(r["record_json"] + "\n")
                yield "".join(out)
            if fmt == "json":
                yield "\n]\n"
    finally:
        conn.close()


# ---------------------------------------------------------------- 预估 / 运行
def _task(args):
    return "narr" if getattr(args, "mode", "") in ("guide_narr", "narr") or getattr(args, "task", "") == "narr" else "eval"


def preview(args, log=print):
    task = _task(args)
    rows = cs_expand.load_scenics(args, log)
    units = load_units(args, rows, log)
    by = {}
    for us in units.values():
        for u in us:
            by[u["kind"]] = by.get(u["kind"], 0) + 1
    n = sum(by.values())
    v = max(1, int(getattr(args, "variants", 1) or 1))
    lim = int(getattr(args, "limit", 0) or 0)
    sample = None
    for sid, us in units.items():
        g = [u for u in us if u["kind"] == "guide"]
        if g:
            u = g[0]
            sample = dict(scenic_id=sid, spot=u["spot"], kind=KB_NAME[u["kind"]], facts=[f"{f['attr']}：{f['value']}" for f in u["facts"]][:6])
            break
    return dict(mode="guide_" + task, task=task, task_name=TASK_NAME[task], scenics=len(units), units=n,
                by_kb=[dict(kb=k, name=KB_NAME[k], units=by.get(k, 0)) for k in KB_SOURCES if k in _kb(args)],
                variants=v, total=n * v, this_run=min(n * v, lim) if lim else n * v, sample=sample)


def _done_keys(task, out):
    keys = set()
    for d in {out, *OUT_ROOT.glob(f"guide_{task}_*")}:
        f = d / "done_keys.txt"
        if f.exists():
            keys.update(f.read_text(encoding="utf-8").split())
    return keys


def run(args, cfg, log=print, should_stop=lambda: False, progress=lambda done, total: None, on_item=lambda item: None):
    task = _task(args)
    rows = cs_expand.load_scenics(args, log)
    byid = {r["_id"]: r for r in rows}
    units = load_units(args, rows, log)
    variants = max(1, int(args.variants or 1))
    out = Path(args.out) if args.out else OUT_ROOT / f"guide_{task}_{time.strftime('%Y%m%d')}"
    out.mkdir(parents=True, exist_ok=True)
    done = _done_keys(task, out)
    order = sorted(units)
    _seeded(args.seed, "order", task).shuffle(order)
    plan_keys = [(sid, u, v) for v in range(1, variants + 1) for sid in order for u in units[sid]]
    todo = [(sid, u, v) for sid, u, v in plan_keys if f"{u['unit_id']}|{v}" not in done]
    n_left = len(todo)
    if args.limit:
        todo = todo[: args.limit]
    log(f"{TASK_NAME[task]}：知识单元 {sum(len(x) for x in units.values())} 个（{len(units)} 个景区）× {variants} 版 = {len(plan_keys)} 条，"
        f"已生成 {len(plan_keys) - n_left} 条，本次 {len(todo)} 条，并发 {args.workers}，输出到 {out}")
    f_dlg, f_rej, f_done, f_kn = out / "dialogs.jsonl", out / "rejected.jsonl", out / "done_keys.txt", out / "knowledge_extract.jsonl"
    f_map = out / "mapping.csv"
    have_kn = {json.loads(x)["unit_id"] for x in f_kn.read_text(encoding="utf-8").splitlines() if x.strip()} if f_kn.exists() else set()
    new_map = not f_map.exists()
    fm = f_map.open("a", encoding="utf-8-sig" if new_map else "utf-8", newline="")
    mw = csv.writer(fm)
    if new_map:
        mw.writerow(["id", "scenic_id", "scenic_name", "spot", "kb_kind", "unit_id", "variant", "summary", "needs_review", "check_flags", "model", "generated_at"])
    conn = None
    if args.mysql:
        import db
        with db.cursor() as cur:
            cur.execute(ddl(task))

    def write_mysql(rec):
        nonlocal conn
        import pymysql
        import db
        for attempt in (1, 2):
            try:
                if conn is None:
                    conn = pymysql.connect(**db.DB)
                with conn.cursor() as cur:
                    mysql_write(cur, task, rec)
                return None
            except Exception as e:  # noqa: BLE001
                conn = None
                if attempt == 2:
                    return f"{type(e).__name__}: {e}"

    stats = dict(ok=0, review=0, rejected=0, failed=0, cancelled=0, total=len(todo), out=str(out), mode="guide_" + task)
    progress(0, len(todo))

    def one(sid, u, v):
        if should_stop():
            return ("cancelled", sid, u, v, None, dict(error="已停止"), None)
        row = byid[sid]
        plan = plan_item(task, row, u, v, args.seed)
        prompt = eval_prompt(row, u, plan) if task == "eval" else narr_prompt(row, u, plan)
        ex_ = dict(prompt=prompt, started=time.strftime("%H:%M:%S"),
                   persona=(plan["style"][0] if task == "eval" else f"{plan['profile']['出游客群名称']} · {plan['profile']['年龄']}岁"),
                   channel=TASK_NAME[task], situation=("计划放入：" + ("、".join(f"{et}{'（' + a + '）' if a else ''}" for et, a in plan["errors"]) or "无问题"))
                   if task == "eval" else f"字数上限 {plan['task_params']['字数上限']} · 风格 {plan['task_params']['讲解风格'] or '未指定'}")
        t0 = time.time()
        try:
            text, elapsed, meta = ai_judge.call(cfg, prompt)
        except ai_judge.AIError as e:
            return ("failed", sid, u, v, plan, dict(error=str(e), http_status=e.http_status, request_id=e.request_id), dict(ex_, elapsed=round(time.time() - t0, 1)))
        ex_.update(response=text, elapsed=elapsed, request_id=meta.get("request_id"))
        try:
            rec = build_record(task, row, u, v, plan, ai_judge.parse(text), cfg)
            rec["source"].update(scenic_name=row["_name"], elapsed=round(time.time() - t0, 1), request_id_llm=meta.get("request_id"))
            return ("ok", sid, u, v, plan, rec, ex_)
        except Exception as e:  # noqa: BLE001
            return ("rejected", sid, u, v, plan, dict(error=f"{type(e).__name__}: {e}", raw=text[:2000]), ex_)

    def handle(n, res):
        kind, sid, u, v, plan, rec, ex_ = res
        if kind == "cancelled":
            stats["cancelled"] += 1
            return
        row = byid[sid]
        key = f"{u['unit_id']}|{v}"
        if kind == "ok":
            if u["unit_id"] not in have_kn:
                with f_kn.open("a", encoding="utf-8") as f:
                    f.write(json.dumps(dict(u, scenic_id=sid), ensure_ascii=False) + "\n")
                have_kn.add(u["unit_id"])
            with f_dlg.open("a", encoding="utf-8") as f:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            g = rec["source"]
            rid = rec.get("eval_task_id") or rec.get("request_id")
            summary = (f"{rec['eval_result']['verdict']} {rec['eval_result']['scores']['总分']}" if task == "eval"
                       else f"{rec['visitor_profile']['出游客群名称']} {rec['reference_narration']['char_count']}字")
            mw.writerow([rid, sid, row["_name"], u["spot"], u["kind"], u["unit_id"], v, summary, int(g["needs_review"]), "；".join(g["check_flags"]),
                         g["model"], g["generated_at"]])
            fm.flush()
            with f_done.open("a", encoding="utf-8") as f:
                f.write(key + "\n")
            if args.mysql:
                err = write_mysql(rec)
                if err:
                    log(f"  写 MySQL 失败 {rid}：{err}（JSONL 已保存）")
            stats["ok"] += 1
            stats["review"] += int(g["needs_review"])
        else:
            with f_rej.open("a", encoding="utf-8") as f:
                f.write(json.dumps(dict(key=key, scenic_id=sid, unit_id=u["unit_id"], variant=v, kind=kind, **rec), ensure_ascii=False) + "\n")
            stats[kind] += 1
            log(f"  [{n}/{len(todo)}] {row['_name']} {u['spot']} 第 {v} 版 {'调用失败' if kind == 'failed' else '不合格'}：{rec.get('error')}")
        facts = {f["attr"] if list(x["attr"] for x in u["facts"]).count(f["attr"]) == 1 else f"{f['attr']}（{f['seq']}）": f["value"] for f in u["facts"]}
        src_view = dict(mode="guide_" + task, scenic_id=sid, scenic_name=row["_name"], city=row["_city"], topic=u["kind"], topic_name=f"{TASK_NAME[task]} · {u['spot']}",
                        facts=facts, refs=[], knowledge=dict(spot=u["spot"], title=u.get("title"), sources=u["sources"]),
                        profile=(plan["profile"] if plan and task == "narr" else None), dialogue_id=u["unit_id"], attraction_name=u["spot"],
                        intent=KB_NAME[u["kind"]].split("（")[0])
        on_item(dict(kind=kind, variant=v, source=src_view, exchange=ex_, record=rec if kind == "ok" else None,
                     error=None if kind == "ok" else rec.get("error"), mysql=bool(args.mysql)))

    workers = max(1, int(args.workers or 1))
    it = iter(todo)
    n = 0
    lock = threading.Lock()
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
                        cs_expand.write_stats(out, stats)
                    if n % 50 == 0:
                        log(f"  进度 {n}/{len(todo)}：成功 {stats['ok']}（需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}")
            fill()
    stats["cancelled"] += len(todo) - n
    fm.close()
    if conn is not None:
        conn.close()
    cs_expand.write_stats(out, stats)
    log(f"完成：成功 {stats['ok']}（其中需复核 {stats['review']}），不合格 {stats['rejected']}，调用失败 {stats['failed']}"
        + (f"，停止前未处理 {stats['cancelled']}" if stats["cancelled"] else "") + f"。\n  输出：{out}")
    return stats


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--task", choices=["eval", "narr"], required=True, help="eval = 讲解内容评价；narr = 子景点个性化讲解")
    ap.add_argument("--data-dir", default=str(cs_synth.DATA_DIR), help="资料目录，默认仓库里的 data/")
    ap.add_argument("--kb", default="", help="知识来源，逗号分隔：guide,redqa,scenic；默认全部")
    ap.add_argument("--out", default="")
    ap.add_argument("--scenic", default="")
    ap.add_argument("--scenic-city", default="")
    ap.add_argument("--grade", default="")
    ap.add_argument("--only-approved", action="store_true")
    ap.add_argument("--variants", type=int, default=1, help="每个知识单元生成几版（讲解评价：不同问题组合；个性化：不同游客）")
    ap.add_argument("--limit", type=int, default=20, help="本次最多几条（0 = 不限）")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--mysql", action="store_true", help=f"同时写进 MySQL（{EVAL_TABLE} / {NARR_TABLE}，自动建表）")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--profile", default=str(cs_synth.HERE / ".pw-profile-service"))
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
