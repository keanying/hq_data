# -*- coding: utf-8 -*-
"""v2：生成 xlsx + 网页数据 data.json"""
import os, sys, json, re, io, contextlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
OUT = os.path.join(HERE, "..")
from collections import Counter, OrderedDict
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

with contextlib.redirect_stdout(io.StringIO()):
    import model as M
import spec
import formulas as F

A, D, C = M.A, M.D, M.C
PER_SNAPSHOT = "取快照日值"

# ---------------- 表
tables = []
def add(layer, short, cn, grain, src, keys, note, metrics, rt=False, db=""):
    tables.append(dict(layer=layer, rt=rt, domain=short.split("_")[1], short=short, name=layer.lower() + "." + short,
                       cn=cn, grain=grain, suffix=M.suffix_desc(short), part=M.part_of(short), src=src, keys=keys,
                       note=note, metrics=metrics, db=db, measure="", degen=""))
src2db = {}
for db, st, t, cn, note in M.ODS:
    add("ODS", t, cn, "同源表，1行=1条源记录", "%s.%s" % (db, st), "源表全字段（敏感字段按备注处理）", note, [], db=db)
    src2db[st] = db
for t, cn, g, s, k in M.DWD:
    add("DWD", t, cn, g, s, k, "", [])
    tables[-1]["measure"], tables[-1]["degen"] = M.DWD_MD[t]
for t, cn, g, s, k in M.DIM:
    pub = t in ("dim_opr_date_f", "dim_opr_region_f", "dim_opr_currency_f", "dim_opr_dict_f")
    s2 = s + (", " + M.DIM_SRC_ADD[t] if t in M.DIM_SRC_ADD else "")
    add("DIM", t, cn, g, s2, k, "公共维度暂挂 opr_，规范补公共域后改名" if pub else "", [])
for t, cn, g, s, ms in M.DWS:
    add("DWS", t, cn, g, s, "", "", ms)
ads_count = Counter(r["ads"] for r in M.ADS_M)
for t, cn, g, s, end, groups in M.ADS + M.RT_ADS:
    rt = t.endswith("_rt")
    add("ADS", t, cn, g, s, "", "使用端：" + end, [], rt=rt)
for layer, t, cn, s, ms in M.RT:
    if layer == "ADS":
        continue
    db = src2db.get(s, "") if layer == "ODS" else ""
    add(layer, t, cn, "1行=1条事件/1个窗口", s, "", "实时表后缀 _rt 待确认", ms, rt=True, db=db)
# 实时 ADS 的描述沿用 RT 定义
order = {"ODS": 0, "DWD": 1, "DIM": 2, "DWS": 3, "ADS": 4}
tables.sort(key=lambda t: (t["rt"], order[t["layer"]]))

known = {t["short"]: t for t in tables}
for t in tables:
    ups = []
    for tok in re.findall(r"[a-z][a-z0-9_]+", t["src"]):
        if tok in known and tok != t["short"] and tok not in ups:
            ups.append(tok)
    t["up"], t["down"] = ups, []
for t in tables:
    for u in t["up"]:
        known[u]["down"].append(t["short"])
for t in tables:
    t["ads_metric_qty"] = ads_count.get(t["short"], 0)

exec(open(os.path.join(HERE, "quality.py"), encoding="utf-8").read())
offline = [t for t in tables if not t["rt"]]
cnt = Counter(t["layer"] for t in offline)
rt_cnt = Counter(t["layer"] for t in tables if t["rt"])

# ---------------- 口径（DWS 层）
bases = []
seq = {A: 0, D: 0, C: 0}
pref = {A: "A", D: "D", C: "C"}
for en, cn, tp, dom, kou, calc, unit, src in M.BASE:
    seq[tp] += 1
    bases.append(dict(code="%s%03d" % (pref[tp], seq[tp]), en=en, cn=cn, type=tp, domain=dom, kou=spec.KOU_BIZ.get(en, kou), calc=calc,
                      unit=unit, src=src, dws=M.base_tables.get(en, []), ads=sorted(M.ads_by_base.get(en, [])),
                      time_basis=spec.TIME_BASIS[en], dtype=spec.dtype(en, unit)[0], precision=spec.dtype(en, unit)[1]))
BOBJ = {b["en"]: b for b in bases}
CN_OF = {b["en"]: b["cn"] for b in bases}
missing_f = [b["en"] for b in bases if b["en"] not in F.ATOM and b["en"] not in F.COMP]
assert not missing_f, missing_f
for b in bases:
    b["formula"] = F.base_formula(b["en"], CN_OF)
code_of = {b["en"]: b["code"] for b in bases}

ads_m = []
for r in M.ADS_M:
    r = dict(r)
    if r["period"] == "截至当日" and r["type"] == A:
        r["formula"] = "取 DWS 原子口径 %s 的快照日值（%s）" % (r["base"], M.BNAME[r["base"]][5])
    r["base_code"] = code_of[r["base"]]
    r["kou"] = spec.ads_kou(r, BOBJ[r["base"]])
    r["mod_cn"] = r["mod"].split("=", 1)[1] if r["mod"] != "—" else ""
    r["formula"] = F.ads_formula(r, CN_OF, spec.TIME_BASIS[r["base"]])
    r["time_basis"] = spec.TIME_BASIS[r["base"]]
    r["dtype"], r["precision"] = spec.dtype(r["en"], r["unit"])
    r["freq"] = spec.freq(r["ads"])
    ads_m.append(r)

_iss = [list(r) for r in M.ISSUES]
_iss.append([len(_iss) + 1, "口径", "比率精度与除零规则", "比率类统一 分子*100/分母，保留 6 位小数，存百分数数值；金额、平均值保留 2 位小数；分母为 0 时结果为空（NULL）", "影响全部 _rate 与 avg_ 指标"])
_iss.append([len(_iss) + 1, "实时采集", "实时链路用 Flink CDC 直读 MySQL binlog（不经 Kafka），源库需满足的前提",
             "binlog_format=ROW、binlog_row_image=FULL；CDC 只读账号需 SELECT、RELOAD、SHOW DATABASES、REPLICATION SLAVE、REPLICATION CLIENT 权限；"
             "每张 CDC 源表一段独立 server-id（已按 5401 起每表 4 个分配）；同一库的多张源表建议放在一个 Flink 作业（STATEMENT SET）里，避免重复拉 binlog；"
             "实时明细与汇总落 StarRocks", "影响 9 张实时 ODS 源表与全部实时作业"])
_iss.append([len(_iss) + 1, "离线采集", "离线 ODS 的同步工具与增量方式",
             "当前设计：_di 表按 binlog 增量（带 binlog_op_type / binlog_time），_df 表每日全量；离线是否也用 Flink CDC（如 CDC 快照模式每日全量 + 增量入湖）待确认",
             "影响 81 张离线 ODS 的采集作业与 binlog 字段来源"])
_nrt = sum(1 for t in tables if t["rt"])
for r in _iss:
    r[4] = re.sub(r"影响 \d+ 张实时表", "影响 %d 张实时表" % _nrt, r[4])
issues = [dict(no=r[0], cat=r[1], q=r[2], a=r[3], impact=r[4]) for r in _iss]
dbs = OrderedDict()
for t in tables:
    if t["layer"] == "ODS" and t["db"]:
        dbs.setdefault(t["db"], []).append(t["short"])

summary = dict(
    layers={k: cnt[k] for k in ("ODS", "DWD", "DIM", "DWS", "ADS")}, total=len(offline), rt=sum(rt_cnt.values()),
    rt_layers={k: rt_cnt[k] for k in ("ODS", "DWD", "DWS", "ADS")},
    base=len(bases), base_by=dict(Counter(b["type"] for b in bases)),
    ads=len(ads_m), ads_by=dict(Counter(r["mode"] for r in ads_m)))
for r in ads_m:
    r["sql"] = sample_sql(r)
# ---------------- 字段 + DDL
exec(open(os.path.join(HERE, "build_schema.py"), encoding="utf-8").read())
for t in tables:
    t["col_qty"] = len(SCH[t["short"]]["cols"])
    # 实时表 lookup 的离线维表（字段级血缘里真正引用到的维表）——实时对离线的唯一依赖
    t["lookup"] = sorted({a for c in SCH[t["short"]]["cols"] for a, b in c["r"] if a in TB and TB[a]["layer"] == "DIM" and not TB[a]["rt"]}) if t["rt"] else []
    t["engine"] = SCH[t["short"]]["engine"]
json.dump({k: dict(cols=v["cols"], ddl=v["ddl"], engine=v["engine"]) for k, v in SCH.items()},
          open(os.path.join(OUT, "web", "schema.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
exec(open(os.path.join(HERE, "workflow.py"), encoding="utf-8").read())
json.dump(WF, open(os.path.join(OUT, "web", "workflow.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
DDL_DIR = os.path.join(OUT, "ddl")
os.makedirs(DDL_DIR, exist_ok=True)
for f in os.listdir(DDL_DIR):
    os.remove(os.path.join(DDL_DIR, f))
_lay = OrderedDict()
for t in tables:
    _lay.setdefault(("rt_" if t["rt"] else "") + t["layer"].lower(), []).append(t)
for i, (k, ts) in enumerate(_lay.items(), 1):
    with open(os.path.join(DDL_DIR, "%02d_%s.sql" % (i, k)), "w", encoding="utf-8") as fh:
        fh.write("-- PFT 2.0 数仓 DDL：%s（%d 张表）\n-- 由 generator/make_all.py 生成，请勿手改\n\n" % (k.upper(), len(ts)))
        for t in ts:
            fh.write("-- ========== %s  %s ==========\n%s\n\n" % (t["name"], t["cn"], SCH[t["short"]]["ddl"]))

data = dict(tables=tables, bases=bases, ads=ads_m, issues=issues, quality=build_quality(tables, bases, ads_m), bus=BUS,
            domains=[dict(k=k, v=v) for k, v in M.DOMAIN.items()],
            dbs=[dict(db=k, tables=v) for k, v in dbs.items()], summary=summary,
            mods=M.MOD_DESC)
_nc = sum(len(v["cols"]) for v in SCH.values())
_cm = sum(1 for v in SCH.values() for c in v["cols"] if c["c"])
_enum = [(k, c["n"]) for k, v in SCH.items() for c in v["cols"] if c["k"] == "状态类型" and TB[k]["layer"] != "ODS"
         and not re.search(r"[A-Z0-9_]+-|[0-9]-|[0-9]=|：|:", c["c"])]
_kw = [(k, c["n"]) for k, v in SCH.items() if TB[k]["layer"] != "ODS" for c in v["cols"]
       if not re.search(r"_(id|no|code|name|type|status|date|time|amt|qty|rate|desc|num)$", c["n"])]
_lin = [(k, c["n"]) for k, v in SCH.items() if TB[k]["layer"] != "ODS" for c in v["cols"] if not c["r"] and c["k"] not in ("ETL", "拉链") and "常量" not in c["s"] and k != "dim_opr_date_f"]
def _qadd(key, name, ok, value, detail):
    for dm in data["quality"]["dims"]:
        if dm["key"] == key:
            dm["checks"].append(dict(name=name, value=value, status="通过" if ok else "待改进", detail=detail))
            dm["total"] += 1
            dm["pass"] += 1 if ok else 0
# 实时与离线同一指标：口径必须完全一致（同一原子口径，只差统计周期）
def _core(r):
    f = r["formula"].split("=", 1)[-1]
    f = "；".join(x for x in f.split("；") if not re.search(r"时间在|取当前|取统计日|今日 0 点|统计日当天", x))
    return f.replace(r["period"], "{P}").strip()
_off = {}
for r in ads_m:
    if r["mode"] == "离线":
        _off.setdefault((r["base"], r["mod"]), []).append(r)
_rt_peer, _same, _diff = 0, 0, []
for r in ads_m:
    if r["mode"] != "实时":
        continue
    ps = _off.get((r["base"], r["mod"]), [])
    r["peers"] = [p["code"] for p in ps]
    for p in ps:
        p.setdefault("peers", []).append(r["code"])
    if not ps:
        r["kou_same"] = None
        continue
    _rt_peer += 1
    ref = next((p for p in ps if p["period"] in ("当日", "截至当日")), ps[0])
    ok = _core(r) == _core(ref) and r["base_code"] == ref["base_code"]
    r["kou_same"] = ok
    _same += ok
    if not ok:
        _diff.append("%s↔%s" % (r["en"], ref["en"]))
for r in ads_m:
    r.setdefault("peers", [])
_qadd("reuse", "实时指标与离线同名指标口径一致", not _diff, "%d/%d" % (_same, _rt_peer),
      "实时 %d 个指标中 %d 个与离线共用同一原子口径（编码相同），口径条件逐字一致，只差统计周期；其余 %d 个为实时专属（分钟窗口、当前值）%s" % (
          sum(1 for r in ads_m if r["mode"] == "实时"), _rt_peer, sum(1 for r in ads_m if r["mode"] == "实时") - _rt_peer,
          ("；不一致：" + "、".join(_diff[:10])) if _diff else ""))
_qadd("std", "字段与表全部带注释", _cm == _nc, "%d/%d" % (_cm, _nc), "242 张表 DDL 均含 COMMENT；类型/状态字段逐值写明含义")
_qadd("std", "字段名以规范关键词结尾（DWD 及以上）", not _kw, "%d 处" % len(_kw), "_id/_no/_code/_name/_type/_status/_date/_time/_amt/_qty/_rate；文本类统一 _desc")
_qadd("std", "类型/状态字段注释列明取值", not _enum, "%d 处缺失" % len(_enum), "如 pay_status：UNPAID-未支付，PAID-已支付" + ("；缺：" + "、".join("%s.%s" % x for x in _enum[:8]) if _enum else ""))
_qadd("full", "字段级血缘覆盖（DWD 及以上）", not _lin, "%d 个字段无上游" % len(_lin), "每个非 ETL 字段都能追到上游表.字段，ODS 字段追到业务库源字段")
json.dump(data, open(os.path.join(OUT, "web", "data.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))

# ---------------- xlsx
wb = Workbook()
HF, HB = PatternFill("solid", fgColor="EEF1F5"), Font(bold=True)
WRAP, TOP = Alignment(wrap_text=True, vertical="top"), Alignment(vertical="top")
def sheet(ws, header, rows, widths, wrap=()):
    ws.append(header)
    for c in ws[1]:
        c.fill, c.font, c.alignment = HF, HB, Alignment(vertical="center", wrap_text=True)
    for r in rows:
        ws.append(r)
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[ws.cell(1, i).column_letter].width = w
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment = WRAP if c.column in wrap else TOP
    ws.freeze_panes = "A2"

ws = wb.active
ws.title = "分层汇总"
L = summary["layers"]
rows = [
    ["ODS", "原始数据层", L["ODS"], "业务库 1:1 镜像；82 张独立业务表剔除 t_staff_credential", "不出指标"],
    ["DWD", "明细层", L["DWD"], "业务过程最细粒度；每张表写明度量字段与退化维度", "度量（可加/半可加）"],
    ["DIM", "维度层", L["DIM"], "拉链 _zip / 全量 _df / 码表 _f", "不出指标"],
    ["DWS", "汇总层", L["DWS"], "主题×粒度汇总，存原子统计口径（1d/快照/累计）", "原子/计算口径 %d 个" % summary["base"]],
    ["ADS", "应用层", L["ADS"], "给业务的具体指标：原子口径 × 统计周期 × 修饰词", "业务指标 %d 个（离线）" % summary["ads_by"].get("离线", 0)],
    ["离线合计", "", "=SUM(C2:C6)", "", ""],
    ["实时链路", "ODS/DWD/DWS/ADS", summary["rt"], "ODS %d + DWD %d + DWS %d + ADS %d；后缀 _rt 待确认" % tuple(summary["rt_layers"][k] for k in ("ODS", "DWD", "DWS", "ADS")),
     "业务指标 %d 个（实时）" % summary["ads_by"].get("实时", 0)],
]
sheet(ws, ["分层", "层级含义", "表数", "说明", "指标产出"], rows, [12, 16, 8, 70, 26], wrap=(4,))
ws.append([])
ws.append(["统计周期", "含义"])
for c in ws[ws.max_row]:
    c.fill, c.font = HF, HB
for k, v in [("1d", "当日"), ("7d / 30d / 90d", "近7日 / 近30日 / 近90日（含当日）"), ("mtd / ytd", "本月累计 / 本年累计"),
             ("td", "截至当日快照值（库存、余额、在途）"), ("1h", "当小时"), ("1w / 1m", "本周 / 本月"),
             ("today / 1h / 5m / now", "实时：今日截至当前 / 近1小时 / 近5分钟 / 当前值")]:
    ws.append([k, v])
ws.append([])
ws.append(["修饰词", "取值"])
for c in ws[ws.max_row]:
    c.fill, c.font = HF, HB
for k, v in M.MOD_DESC.items():
    ws.append([v, "、".join(x[1] for x in M.MODS[k])])
ws.append([])
ws.append(["业务域前缀", "含义"])
for c in ws[ws.max_row]:
    c.fill, c.font = HF, HB
for d in data["domains"]:
    ws.append([d["k"] + "_", d["v"]])

ws = wb.create_sheet("表清单")
rows = []
for i, t in enumerate(tables, 1):
    out = ""
    if t["layer"] == "DWD":
        out = "度量：" + t["measure"] + "\n退化维度：" + t["degen"]
    elif t["layer"] == "DWS":
        out = "原子/计算口径：" + "、".join(t["metrics"])
    elif t["layer"] == "ADS":
        out = "业务指标 %d 个（见 ADS业务指标 页）" % t["ads_metric_qty"]
    elif t["keys"]:
        out = t["keys"]
    rows.append([i, t["layer"] + ("（实时）" if t["rt"] else ""), t["domain"], t["name"], t["cn"], t["grain"], t["suffix"],
                 t["part"], t["src"], out, "、".join(t["up"]), "、".join(t["down"]), t["note"]])
sheet(ws, ["序号", "分层", "业务域", "表名（库.表）", "表中文名", "粒度", "后缀含义", "分区", "来源", "度量 / 口径 / 关键字段",
           "上游表", "下游表", "备注"], rows, [6, 10, 7, 44, 26, 40, 12, 22, 40, 60, 40, 40, 28], wrap=(6, 9, 10, 11, 12, 13))

ws = wb.create_sheet("字段清单")
rows = []
for t in tables:
    for i, c in enumerate(SCH[t["short"]]["cols"], 1):
        rows.append([t["layer"] + ("（实时）" if t["rt"] else ""), t["name"], t["cn"], i, c["n"], c["t"], c["k"], c["c"], c["s"],
                     "、".join("%s.%s" % (TB[a]["name"] if a in TB else a, b) for a, b in c["r"])])
sheet(ws, ["分层", "表名（库.表）", "表中文名", "序号", "字段名", "类型", "字段类别", "字段注释", "加工 / 来源", "上游字段"], rows,
      [10, 42, 22, 6, 30, 15, 10, 60, 50, 60], wrap=(8, 9, 10))
ws.auto_filter.ref = ws.dimensions
wb2 = Workbook(); w2 = wb2.active; w2.title = "字段清单"
sheet(w2, ["分层", "表名（库.表）", "表中文名", "序号", "字段名", "类型", "字段类别", "字段注释", "加工 / 来源", "上游字段"], rows,
      [10, 42, 22, 6, 30, 15, 10, 60, 50, 60], wrap=(8, 9, 10))
w2.auto_filter.ref = w2.dimensions
wb2.save(os.path.join(OUT, "output", "pft_dw_fields.xlsx"))

ws = wb.create_sheet("调度工作流")
rows = []
for n in sorted(WF["nodes"], key=lambda n: (list(FLOWS).index(n["flow"]), n["level"], n["id"])):
    kind = {"task": "任务", "dq": "监控" if n.get("monitor") else "质检", "recon": "对账", "start": "开始", "end": "结束", "ext": "外部依赖"}[n["kind"]]
    rows.append([FLOWS[n["flow"]]["name"], n["level"] + 1, n["id"], kind, n.get("cn", ""), n.get("layer", ""),
                 ("阻断" if n.get("block") else "告警") if n["kind"] in ("dq", "recon") else "",
                 len(n["rules"]), "、".join(n["deps"]), "、".join(n.get("cut", [])), "、".join(n.get("cross", [])), n.get("cmd") or n.get("desc", "")])
sheet(ws, ["工作流", "步骤", "节点", "类型", "说明", "分层", "失败处理", "规则数", "等待（上游）", "依赖上一周期（T-1）", "跨流程依赖", "执行 / 说明"], rows,
      [10, 6, 40, 6, 28, 6, 8, 7, 60, 30, 30, 50], wrap=(9, 12))
ws.auto_filter.ref = ws.dimensions
ws = wb.create_sheet("质量规则")
rows = []
for n in WF["nodes"]:
    for r in n["rules"]:
        rows.append([r["id"], FLOWS[n["flow"]]["name"], n["id"], n.get("table") or "", r["code"], r["name"], r["level"],
                     "阻断下游" if r["level"] == "强" and not n.get("monitor") else "告警", r["expect"], r["desc"], r["sql"]])
sheet(ws, ["规则编号", "工作流", "质检节点", "表", "质量维度", "规则", "级别", "失败处理", "期望", "说明", "检测 SQL"], rows,
      [9, 9, 36, 34, 10, 40, 6, 9, 30, 40, 80], wrap=(6, 9, 10, 11))
ws.auto_filter.ref = ws.dimensions

ws = wb.create_sheet("DWS口径")
rows = [[b["code"], b["en"], b["cn"], b["type"], b["domain"], b["kou"], b["formula"], b["unit"], b["time_basis"], b["dtype"], b["precision"],
         b["src"], "、".join(b["dws"]), "、".join(b["ads"])] for b in bases]
sheet(ws, ["口径编码", "英文名", "中文名", "口径类型", "业务域", "业务口径", "计算公式", "单位", "时间口径", "数据类型", "精度/展示",
           "来源明细表", "落地 DWS 表", "被哪些 ADS 表使用"],
      rows, [9, 30, 22, 10, 7, 46, 46, 7, 28, 14, 26, 32, 44, 50], wrap=(6, 7, 9, 11, 13, 14))

ws = wb.create_sheet("ADS业务指标")
rows = [[r["code"], r["cn"], r["en"], r["kou"], r["formula"], r["unit"], r["period"], r["mod"], r["time_basis"], r["dtype"], r["precision"],
         r["freq"], r["mode"], r["base_code"] + " " + r["base_cn"], r["type"], r["ads"], r["ads_cn"], r["grain"], r["src"], r["end"]] for r in ads_m]
sheet(ws, ["指标编码", "业务指标名", "字段名", "业务口径", "计算公式", "单位", "统计周期", "修饰词", "时间口径", "数据类型", "精度/展示",
           "更新频率", "离线/实时", "基础口径", "口径类型", "ADS表", "ADS表中文名", "分析粒度", "来源 DWS", "使用端"], rows,
      [9, 30, 34, 56, 50, 7, 10, 22, 28, 14, 26, 16, 8, 26, 10, 34, 20, 34, 40, 14], wrap=(2, 4, 5, 9, 11, 18, 19))

ws = wb.create_sheet("总线矩阵")
hdr = ["分层", "表名", "中文名"] + [BUS["dim_cn"][d] for d in BUS["dims"]]
rows = [[r["layer"], r["name"], r["cn"]] + ["●" if d in r["dims"] else "" for d in BUS["dims"]] for r in BUS["rows"]]
sheet(ws, hdr, rows, [7, 42, 26] + [6] * len(BUS["dims"]))
ws.append(["", "被引用次数", ""] + [BUS["use"][d] for d in BUS["dims"]])
Q = data["quality"]
ws = wb.create_sheet("质量体检")
rows = []
for dim in Q["dims"]:
    for c in dim["checks"]:
        rows.append([dim["name"], c["name"], c["value"], c["status"], c["detail"]])
sheet(ws, ["维度", "检查项", "结果", "状态", "说明 / 明细"], rows, [10, 36, 16, 8, 90], wrap=(2, 5))
ws = wb.create_sheet("待确认事项")
rows = [[i["no"], i["cat"], i["q"], i["a"], i["impact"]] for i in issues]
sheet(ws, ["序号", "类别", "问题", "当前处理 / 建议", "影响"], rows, [6, 10, 48, 70, 24], wrap=(3, 4, 5))
wb.save(os.path.join(OUT, "output", "pft_dw_v2.xlsx"))
print(summary)
print("data.json KB", round(len(json.dumps(data, ensure_ascii=False).encode()) / 1024))
if os.environ.get("WF_DEBUG"):
    for k, v in WF_CHECK.items():
        print(k, v if not isinstance(v, list) else (len(v), v[:20]))
if os.environ.get("SCHEMA_DEBUG"):
    for k, v in SCHEMA_CHECK.items():
        print(k, v if not isinstance(v, list) else (len(v), v[:60]))

# ---------------- 在线表格同款：v2 全部页 + v1 历史页，合成一个工作簿（与在线 Sheet「PFT 2.0 数仓分层表清单与指标字典」一致）
import subprocess, copy
subprocess.run([sys.executable, os.path.join(HERE, "base_data.py")], check=True, stdout=subprocess.DEVNULL)
from openpyxl import load_workbook
_book = Workbook(); _book.remove(_book.active)
for path, prefix in [(os.path.join(OUT, "output", "pft_dw_v2.xlsx"), ""), (os.path.join(OUT, "output", "pft_dw_v1.xlsx"), "v1 ")]:
    _src = load_workbook(path)
    for ws0 in _src.worksheets:
        ws1 = _book.create_sheet(prefix + ws0.title)
        for row in ws0.iter_rows():
            for c in row:
                d = ws1.cell(row=c.row, column=c.column, value=c.value)
                if c.has_style:
                    d.font, d.fill, d.alignment, d.border = copy.copy(c.font), copy.copy(c.fill), copy.copy(c.alignment), copy.copy(c.border)
        for k, v in ws0.column_dimensions.items():
            ws1.column_dimensions[k].width = v.width
        ws1.freeze_panes = ws0.freeze_panes
        if ws0.auto_filter.ref:
            ws1.auto_filter.ref = ws0.auto_filter.ref
_book.save(os.path.join(OUT, "output", "PFT2.0_数仓分层表清单与指标字典.xlsx"))
