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
    bases.append(dict(code="%s%03d" % (pref[tp], seq[tp]), en=en, cn=cn, type=tp, domain=dom, kou=kou, calc=calc,
                      unit=unit, src=src, dws=M.base_tables.get(en, []), ads=sorted(M.ads_by_base.get(en, []))))
code_of = {b["en"]: b["code"] for b in bases}

ads_m = []
for r in M.ADS_M:
    r = dict(r)
    if r["period"] == "截至当日" and r["type"] == A:
        r["formula"] = "取 DWS 原子口径 %s 的快照日值（%s）" % (r["base"], M.BNAME[r["base"]][5])
    r["base_code"] = code_of[r["base"]]
    ads_m.append(r)

issues = [dict(no=r[0], cat=r[1], q=r[2], a=r[3], impact=r[4]) for r in M.ISSUES]
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
data = dict(tables=tables, bases=bases, ads=ads_m, issues=issues, quality=build_quality(tables, bases, ads_m), bus=BUS,
            domains=[dict(k=k, v=v) for k, v in M.DOMAIN.items()],
            dbs=[dict(db=k, tables=v) for k, v in dbs.items()], summary=summary,
            mods=M.MOD_DESC)
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

ws = wb.create_sheet("DWS口径")
rows = [[b["code"], b["en"], b["cn"], b["type"], b["domain"], b["kou"], b["calc"], b["unit"], b["src"],
         "、".join(b["dws"]), "、".join(b["ads"])] for b in bases]
sheet(ws, ["口径编码", "英文名", "中文名", "口径类型", "业务域", "业务口径", "计算逻辑", "单位", "来源明细表", "落地 DWS 表", "被哪些 ADS 表使用"],
      rows, [9, 30, 22, 10, 7, 46, 46, 7, 32, 44, 50], wrap=(6, 7, 10, 11))

ws = wb.create_sheet("ADS业务指标")
rows = [[r["code"], r["mode"], r["ads"], r["ads_cn"], r["cn"], r["en"], r["period"], r["mod"], r["base_code"] + " " + r["base_cn"],
         r["type"], r["formula"], r["unit"], r["grain"], r["src"], r["end"]] for r in ads_m]
sheet(ws, ["指标编码", "离线/实时", "ADS表", "ADS表中文名", "业务指标名", "字段名", "统计周期", "修饰词", "基础口径", "口径类型",
           "计算公式", "单位", "分析粒度", "来源 DWS", "使用端"], rows,
      [9, 8, 34, 20, 30, 34, 10, 22, 26, 10, 56, 7, 34, 40, 14], wrap=(5, 11, 13, 14))

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
