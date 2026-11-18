# -*- coding: utf-8 -*-
"""从客户 6 份设计文档中提取表与字段（物理建表语句 + 领域模型），生成可阅览的表格
用法：python3 extract_source.py <文档目录>
输出：source/PFT2.0_源库表与字段.xlsx、source/source_tables.json
"""
import os, re, sys, json, glob
from collections import OrderedDict, defaultdict
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

SRC_DIR = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = OrderedDict([("database", "完整数据库设计"), ("core-models", "核心模型"), ("hld", "概要设计（HLD）"),
                    ("price-model", "价格体系模型 v2"), ("application", "应用架构"), ("命名规范", "数仓命名规范")])
def doc_of(path):
    n = os.path.basename(path)
    for k, v in DOCS.items():
        if k in n:
            return v
    return "数仓命名规范" if "____" in n else n
files = sorted(glob.glob(os.path.join(SRC_DIR, "*.md")))
TXT = {doc_of(f): open(f, encoding="utf-8").read() for f in files}

# ------------------------------------------------------------ 1 领域表清单（库 / 业务域 / 中文名）
DB = TXT["完整数据库设计"]
LIST = defaultdict(list)       # 表 -> [(业务域, 库, 说明, 状态)]
sec = None
for line in DB[DB.index("## 一、领域表清单"):DB.index("## 二、完整DDL")].splitlines():
    m = re.match(r"### \d+\.\s*(.+?)（(pft-[a-z-]+) 库(?:，([^）]*))?）", line)
    if m:
        sec = (m.group(1), m.group(2), m.group(3) or "")
        continue
    m = re.match(r"\|\s*(~~)?(t_[a-z0-9_]+)(~~)?\s*\|\s*(.+?)\s*\|\s*$", line)
    if m and sec:
        desc = re.sub(r"~~|\*\*", "", m.group(4)).strip()
        LIST[m.group(2)].append(dict(domain=sec[0], db=sec[1], phase=sec[2], desc=desc, deprecated=bool(m.group(1)) or "废弃" in desc))

# ------------------------------------------------------------ 2 建表语句（所有文档）
def heading_before(text, pos):
    hs = [(m.start(), m.group(1)) for m in re.finditer(r"^#{2,4} (.+)$", text, re.M) if m.start() < pos]
    return hs[-1][1].strip() if hs else ""

def parse_ddl(doc, text):
    out = []
    for m in re.finditer(r"CREATE TABLE (t_[a-z0-9_]+) \((.*?)\n\)\s*([^;]*);", text, re.S):
        name, body, tail = m.group(1), m.group(2), m.group(3)
        tc = re.search(r"COMMENT\s*=\s*'(.*?)'\s*$", tail.strip(), re.S)
        lines, cur, group = [], None, ""
        for raw in body.split("\n"):
            s_ = raw.strip()
            if not s_:
                continue
            if s_.startswith("--"):
                if cur: lines.append(cur); cur = None
                group = s_.lstrip("- ").strip()
                continue
            if re.match(r"^(PRIMARY|UNIQUE|KEY|INDEX|CONSTRAINT|FULLTEXT)\b", s_):
                if cur: lines.append(cur); cur = None
                lines.append(("key", s_, group))
                continue
            if re.match(r"^[a-z_0-9]+\s+[A-Z]", s_):
                if cur: lines.append(cur)
                cur = ("col", s_, group)
            elif cur:
                cur = (cur[0], cur[1] + " " + s_, cur[2])
        if cur: lines.append(cur)
        cols, keys = [], []
        for kind, s_, grp in lines:
            if kind == "key":
                km = re.match(r"(PRIMARY KEY|UNIQUE KEY|KEY|INDEX)\s*(\w*)\s*\(([^)]*)\)", s_)
                if km:
                    keys.append(dict(kind={"PRIMARY KEY": "主键", "UNIQUE KEY": "唯一键"}.get(km.group(1), "索引"), name=km.group(2) or "PRIMARY",
                                     cols=[x.strip().strip("`") for x in km.group(3).split(",")]))
                continue
            cm = re.match(r"([a-z_0-9]+)\s+([A-Z]+(?:\([0-9, ]+\))?(?:\s+UNSIGNED)?)\s*(.*)$", s_)
            if not cm:
                continue
            rest = cm.group(3).rstrip(",").strip()
            com = re.search(r"COMMENT\s+'(.*?)'\s*$", rest)
            comment = com.group(1) if com else ""
            attrs = rest[:com.start()] if com else rest
            dflt = re.search(r"DEFAULT\s+('(?:[^']*)'|CURRENT_TIMESTAMP(?:\(\d\))?|NULL|[-\w.]+)", attrs)
            cols.append(dict(name=cm.group(1), type=re.sub(r"\s+", " ", cm.group(2)),
                             nullable="否" if "NOT NULL" in attrs else "是",
                             default=(dflt.group(1) if dflt else ""), auto="自增" if "AUTO_INCREMENT" in attrs else ("更新时自动刷新" if "ON UPDATE" in attrs else ""),
                             comment=comment, group=grp))
        for c in cols:
            ks = [("PK" if k["kind"] == "主键" else "UK:" + k["name"] if k["kind"] == "唯一键" else "IDX:" + k["name"]) for k in keys if c["name"] in k["cols"]]
            c["keys"] = " ".join(ks)
        out.append(dict(name=name, doc=doc, section=heading_before(text, m.start()), comment=tc.group(1) if tc else "", cols=cols, keys=keys))
    return out

DDL = []
for doc, text in TXT.items():
    DDL += parse_ddl(doc, text)
MAIN = OrderedDict((t["name"], t) for t in DDL if t["doc"] == "完整数据库设计")
OTHER = [t for t in DDL if t["doc"] != "完整数据库设计"]

# ------------------------------------------------------------ 3 领域模型（代码块里的模型树：实体 + 字段）
ENT_RE = re.compile(r"^([A-Z][A-Za-z]+)(\[\])?\s*(?:（([^）]*)）)?")
ALIAS = {"Person": "t_ticket_person"}
def snake(n):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", n).lower()
def phys(ent):
    return ALIAS.get(ent, "t_" + snake(ent))
MODEL = []
for doc, text in TXT.items():
    for blk in re.finditer(r"```[a-z]*\n(.*?)```", text, re.S):
        body = blk.group(1)
        if "├──" not in body and "└──" not in body:
            continue
        section = heading_before(text, blk.start())
        start = len(MODEL)
        stack = []           # (indent, entity)
        for raw in body.split("\n"):
            line = raw.rstrip()
            if not line.strip() or set(line.strip()) <= set("│ ═─"):
                continue
            tm = re.match(r"^([\s│]*)([├└]──\s*)?(.*)$", line)
            indent = len(tm.group(1)) if tm.group(2) else -1
            item = tm.group(3).strip()
            if not tm.group(2):          # 顶层行：实体标题
                em = ENT_RE.match(item)
                if em and not item.startswith(("【", "═")):
                    stack = [(-1, dict(entity=em.group(1), cn=em.group(3) or "", parent="", doc=doc, section=section))]
                    MODEL.append(stack[-1][1] | {"field": None})
                continue
            while stack and stack[-1][0] >= indent:
                stack.pop()
            if not stack:
                continue
            ent = stack[-1][1]
            em = ENT_RE.match(item)
            if em and (em.group(3) or em.group(2)) and not re.match(r"^[A-Z][A-Za-z]+\s*[:：]", item):
                child = dict(entity=em.group(1), cn=em.group(3) or "", parent=ent["entity"], doc=doc, section=section)
                stack.append((indent, child))
                MODEL.append(child | {"field": None})
                continue
            note = ""
            if "◄──" in item:
                item, note = item.split("◄──", 1)
            fm = re.match(r"^([A-Za-z_][\w./ \[\]]*?)\s*(?:[:：]\s*|//\s*|\s{2,}|\s*$)(.*)$", item.strip())
            if not fm:
                continue
            fname, desc = fm.group(1).strip(), (fm.group(2).strip().lstrip("/").strip() + (" ◄ " + note.strip() if note.strip() else "")).strip()
            if re.match(r"^[A-Z]", fname) and " " not in fname and not desc:
                continue
            MODEL.append(dict(entity=ent["entity"], cn=ent["cn"], parent=ent["parent"], doc=doc, section=section, field=fname, desc=desc))
        # 同一实体字段重复出现 = 举例的数据实例（不是模型定义），整段跳过
        seen = set()
        for r in MODEL[start:]:
            if r["field"] and (r["entity"], r["field"]) in seen:
                del MODEL[start:]
                break
            seen.add((r["entity"], r["field"]))
# 去掉没有字段的标题（状态机、架构图）和全大写的状态名
_nf = defaultdict(int)
for r in MODEL:
    if r["field"]:
        _nf[(r["entity"], r["doc"], r["section"])] += 1
MODEL = [r for r in MODEL if _nf[(r["entity"], r["doc"], r["section"])] and not r["entity"].isupper()]

# ------------------------------------------------------------ 4 入仓情况（来自数仓模型）
dw = json.load(open(os.path.join(HERE, "..", "web", "data.json"), encoding="utf-8"))
ODS_OF = defaultdict(list)
for t in dw["tables"]:
    if t["layer"] == "ODS":
        st = t["src"].split("（")[0].split(".")[-1]
        ODS_OF[st].append(t["name"] + ("（实时）" if t["rt"] else ""))
NOT_IN = {"t_staff_credential": "不接入：员工密码 / MFA 密钥，合规排除", "t_access_endpoint": "不接入：已废弃，功能并入 t_channel"}

# ------------------------------------------------------------ 5 文档间差异（同名表在其他文档里的定义 vs 完整数据库设计）
DIFF = []
for t in OTHER:
    m = MAIN.get(t["name"])
    if not m:
        DIFF.append([t["name"], t["doc"], "—", "整表", "仅在「%s」有建表语句，完整数据库设计中没有" % t["doc"], "", ""])
        continue
    a = {c["name"]: c for c in m["cols"]}
    b = {c["name"]: c for c in t["cols"]}
    for n in b:
        if n not in a:
            DIFF.append([t["name"], t["doc"], n, "字段", "仅在「%s」中有" % t["doc"], "", b[n]["type"] + " " + b[n]["comment"]])
    for n in a:
        if n not in b:
            DIFF.append([t["name"], t["doc"], n, "字段", "仅在「完整数据库设计」中有", a[n]["type"] + " " + a[n]["comment"], ""])
    for n in a:
        if n in b:
            for k, cn in (("type", "类型"), ("nullable", "可空"), ("default", "默认值"), ("comment", "注释")):
                if a[n][k] != b[n][k]:
                    DIFF.append([t["name"], t["doc"], n, cn, "%s不同" % cn, a[n][k], b[n][k]])

# ------------------------------------------------------------ 6 写表格
wb = Workbook()
HF, HFILL = Font(bold=True, color="FFFFFF"), PatternFill("solid", fgColor="2F4A6D")
def sheet(ws, head, rows, widths, wrap=()):
    ws.append(head)
    for c in ws[1]:
        c.font, c.fill, c.alignment = HF, HFILL, Alignment(vertical="center")
    for r in rows:
        ws.append(r)
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w
    for col in wrap:
        for cell in ws.iter_cols(min_col=col, max_col=col, min_row=2):
            for c in cell:
                c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions

tables_rows, cols_rows = [], []
all_names = list(MAIN) + sorted({t["name"] for t in OTHER} - set(MAIN))
for i, name in enumerate(all_names, 1):
    t = MAIN.get(name) or next(x for x in OTHER if x["name"] == name)
    ls = LIST.get(name, [])
    dbs = "、".join(dict.fromkeys(x["db"] for x in ls)) or "—"
    dom = "、".join(dict.fromkeys(x["domain"] for x in ls)) or "—"
    cn = ls[0]["desc"].split("（")[0] if ls else (t["comment"].split("：")[0].split(":")[0][:20] if t["comment"] else "")
    pk = "、".join(",".join(k["cols"]) for k in t["keys"] if k["kind"] == "主键")
    uk = "；".join("%s(%s)" % (k["name"], ",".join(k["cols"])) for k in t["keys"] if k["kind"] == "唯一键")
    idx = sum(1 for k in t["keys"] if k["kind"] == "索引")
    also = sorted({x["doc"] for x in OTHER if x["name"] == name})
    status = NOT_IN.get(name) or ("、".join(ODS_OF[name]) if ODS_OF.get(name) else "未入仓")
    flags = []
    if any(x["deprecated"] for x in ls):
        flags.append("已废弃")
    if any(x["phase"] for x in ls):
        flags.append("、".join(dict.fromkeys(x["phase"] for x in ls if x["phase"])))
    tables_rows.append([i, dbs, dom, name, cn, t["comment"], len(t["cols"]), pk, uk, idx, t["doc"] + ("；另见：" + "、".join(also) if also else ""),
                        "、".join(flags), status])
    for j, c in enumerate(t["cols"], 1):
        cols_rows.append([dbs, name, cn, j, c["group"], c["name"], c["type"], c["nullable"], c["default"], c["auto"], c["keys"], c["comment"], t["doc"]])

ws = wb.active; ws.title = "表清单"
sheet(ws, ["序号", "库", "业务域", "表名", "中文名", "表注释", "字段数", "主键", "唯一键", "普通索引数", "定义来源", "标记", "数仓入仓（ODS 表）"], tables_rows,
      [6, 20, 12, 30, 18, 60, 7, 10, 34, 9, 30, 10, 44], wrap=(6, 9, 13))
ws = wb.create_sheet("字段清单")
sheet(ws, ["库", "表名", "表中文名", "序号", "字段分组", "字段名", "类型", "可空", "默认值", "自增/自动刷新", "所在键", "注释", "来源文档"], cols_rows,
      [18, 30, 16, 6, 22, 26, 16, 6, 22, 12, 30, 70, 14], wrap=(12,))
ws = wb.create_sheet("文档间差异")
sheet(ws, ["表名", "对比文档", "字段", "差异项", "说明", "完整数据库设计中的值", "对比文档中的值"], DIFF, [28, 16, 24, 8, 30, 50, 50], wrap=(6, 7))
mrows = []
phys_cols = {n: {c["name"] for c in t["cols"]} for n, t in MAIN.items()}
for r in MODEL:
    tn = phys(r["entity"])
    has = tn in MAIN
    if r["field"] is None:
        mrows.append([r["doc"], r["section"], r["entity"], r["cn"], r["parent"], "（实体）", "", tn if has else "无对应建表语句", ""])
    else:
        fs = [snake(x.strip()) for x in re.split(r"\s*/\s*", r["field"].replace("[]", ""))]
        inphys = "—" if not has else ("有" if all(f in phys_cols[tn] or f + "_id" in phys_cols[tn] or f.replace("_at", "_time") in phys_cols[tn] for f in fs) else "物理表无同名字段")
        mrows.append([r["doc"], r["section"], r["entity"], r["cn"], r["parent"], r["field"], r["desc"], tn if has else "无对应建表语句", inphys])
ws = wb.create_sheet("领域模型字段")
sheet(ws, ["来源文档", "章节", "实体", "实体中文名", "上级实体", "字段", "说明", "对应物理表", "物理表是否有同名字段"], mrows,
      [14, 26, 22, 18, 16, 26, 60, 26, 16], wrap=(7,))
# 说明页
ws = wb.create_sheet("说明", 0)
ents = {r["entity"] for r in MODEL}
no_ddl = sorted({r["entity"] for r in MODEL if phys(r["entity"]) not in MAIN})
info = [
    ["来源", "客户提供的 6 份文档：%s" % "、".join(TXT.keys())],
    ["物理表", "%d 张（「完整数据库设计」%d 张建表语句%s），%d 个字段" % (len(all_names), len(MAIN),
               "，另有 %d 张只在其他文档出现" % (len(all_names) - len(MAIN)) if len(all_names) > len(MAIN) else "", len(cols_rows))],
    ["其他文档中的建表语句", "%d 段（核心模型 %d、HLD %d），与完整数据库设计逐字段比对，差异 %d 处，见「文档间差异」" % (
        len(OTHER), sum(t["doc"] == "核心模型" for t in OTHER), sum(t["doc"] == "概要设计（HLD）" for t in OTHER), len(DIFF))],
    ["领域模型", "代码块中的模型树 %d 个实体、%d 个字段；其中 %d 个实体没有对应建表语句：%s" % (
        len(ents), sum(1 for r in MODEL if r["field"]), len(no_ddl), "、".join(no_ddl))],
    ["表清单", "一行一张表：库、业务域、中文名、主键 / 唯一键、字段数、定义来源、数仓入仓情况"],
    ["字段清单", "一行一个字段：按建表顺序，含字段分组（建表语句中的 -- 注释）、类型、可空、默认值、所在键、注释"],
    ["文档间差异", "同一张表在核心模型 / HLD 中的建表语句与完整数据库设计的不同，以完整数据库设计为准"],
    ["领域模型字段", "文档里 OrderGroup / PricePoint / RiskRule 等模型树的字段（驼峰命名的领域对象），并对应到物理表"],
]
for r in info:
    ws.append(r)
ws.column_dimensions["A"].width = 18; ws.column_dimensions["B"].width = 120
for c in ws["A"]:
    c.font = Font(bold=True)
for c in ws["B"]:
    c.alignment = Alignment(wrap_text=True, vertical="top")
out = os.path.join(HERE, "PFT2.0_源库表与字段.xlsx")
wb.save(out)
json.dump(dict(tables=tables_rows, columns=cols_rows, diff=DIFF, model=mrows), open(os.path.join(HERE, "source_tables.json"), "w", encoding="utf-8"), ensure_ascii=False)
print("tables", len(all_names), "main", len(MAIN), "cols", len(cols_rows), "other_ddl", len(OTHER), "diff", len(DIFF), "model_entities", len(ents),
      "model_fields", sum(1 for r in MODEL if r["field"]), "no_ddl", no_ddl)
