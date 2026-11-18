# -*- coding: utf-8 -*-
"""组装全部 242 张表的字段清单 + DDL；在 make_all 命名空间内 exec（依赖 tables / bases / ads_m）"""
import re, os, json
import schema as S

SCH = {}          # short -> dict(cols=[...], ddl=str, engine=str)
TB = {t["short"]: t for t in tables}
BASE = {b["en"]: b for b in bases}

def hive_name(t):
    return "%s.%s" % (t["layer"].lower(), t["short"])

# ------------------------------------------------ ODS
ODS = {}
for t in tables:
    if t["layer"] != "ODS":
        continue
    st = t["src"].split(".")[-1]
    db = t["db"] or t["src"].split(".")[0]
    cols, tc = S.ods_cols(t["short"], db, st, t["rt"])
    ODS[t["short"]] = dict(st=st, cols=cols, cn=t["cn"])
    SCH[t["short"]] = dict(cols=cols)

def finish(short, cols):
    seen, out = set(), []
    for c in cols:
        if c["n"] in seen:
            continue
        seen.add(c["n"])
        out.append(c)
    SCH[short] = dict(cols=out)

# ------------------------------------------------ DWD（离线）
for short, sp in S.DWD.items():
    cols = S.derive(sp["base"], ODS, sp["entity"], **sp["kw"]) if sp["base"] else []
    ext = S.lines(sp["extra"])
    names = {c["n"] for c in cols}
    cols = cols + [c for c in ext if c["n"] not in names] + S.ETL()
    finish(short, cols)

# ------------------------------------------------ DIM
for short, sp in S.DIM.items():
    cols = S.derive(sp["base"], ODS, sp["entity"], **sp["kw"])
    names = {c["n"] for c in cols}
    cols += [c for c in S.lines(sp["extra"]) if c["n"] not in names]
    if short.endswith("_zip"):
        cols += S.ZIP()
    finish(short, cols + S.ETL())
finish("dim_opr_date_f", S.lines(S.DATE_DIM) + S.ETL())

# ------------------------------------------------ 实时 DWD：复用离线同名明细字段，上游改指 _rt
RT_DWD = {"dwd_ord_order_rt": "dwd_ord_order_di", "dwd_fin_payment_rt": "dwd_fin_payment_di", "dwd_ord_verify_rt": "dwd_ord_verify_di",
          "dwd_ord_refund_rt": "dwd_ord_refund_di", "dwd_inv_pool_change_rt": "dwd_inv_pool_change_di", "dwd_opr_risk_event_rt": "dwd_opr_risk_event_di"}
for rt, off in RT_DWD.items():
    up = set(TB[rt]["up"])
    cols = []
    for c in SCH[off]["cols"]:
        if c["k"] == "ETL":
            continue
        r2 = []
        for a, b in c["r"]:
            a2 = a[:-3] + "_rt" if a.endswith(("_di", "_df")) and a.startswith("ods_") else a
            if a2 in ODS or a2 in up or a.startswith("dim_"):
                r2.append([a2 if a2 in ODS else a, b])
            elif a.startswith("dwd_"):
                r2.append([a.replace("_di", "_rt"), b] if a.replace("_di", "_rt") in TB else [a, b])
        s = re.sub(r"\bods_([a-z_]+?)_d[if]\b", lambda m: "ods_%s_rt" % m.group(1) if "ods_%s_rt" % m.group(1) in ODS else m.group(0), c["s"])
        cols.append(dict(c, r=r2, s=s))
    main_ods = next(u for u in TB[rt]["up"] if u in ODS)
    for c in cols:  # 实时源表未声明的列（敏感列）不再引用
        c["r"] = [[a, b] for a, b in c["r"] if a not in ODS or any(x["n"] == b for x in ODS[a]["cols"])]
    ent = S.DWD[off]["entity"]
    is_event = "change" in rt
    dt_src = "change_time" if is_event else "create_time"
    cols.insert(0, S.col("travel_date", "STRING", "数据日期，格式 YYYYMMDD；取%s日期，保证同一主键始终落在同一分区" % ("变动时间" if is_event else "创建时间"),
                         "分区", "%s.%s 取日期" % (main_ods, "binlog_time" if is_event else "create_time"),
                         [[main_ods, "binlog_time" if is_event else "create_time"]]))
    cols.append(S.col("event_time", "STRING", "事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss", "ETL",
                      "%s.binlog_time" % main_ods, [[main_ods, "binlog_time"]]))
    finish(rt, cols)
    SCH[rt]["keys"] = ["travel_date", ent + "_id"] + (["change_time"] if is_event else [])

# ------------------------------------------------ DWS / ADS
def find_src(up_tables, name):
    """在上游表里找同名字段"""
    for u in up_tables:
        if u in SCH and any(c["n"] == name for c in SCH[u]["cols"]):
            return [u, name]
    return None

IDENT = re.compile(r"[a-z][a-z0-9_]*")
def calc_fields(calc, table):
    names = {c["n"] for c in SCH.get(table, {}).get("cols", [])}
    out = []
    for tk in IDENT.findall(calc or ""):
        if tk in names and tk not in out:
            out.append(tk)
    return out

def unit_txt(b, en=""):
    u = b.get("unit") or ""
    if en.endswith("_rate"):
        return "，单位：%（百分数数值，已乘 100，保留 6 位小数）"
    return "，单位：" + u if u and u not in ("—", "-", "日期") else ""

def metric_col(en, dtype, cn, kou, unit, refs, how):
    return S.col(en, dtype, "%s：%s%s" % (cn, (kou or "").rstrip("。；; "), unit), "指标", how, refs)

def dws_metric_refs(short, b):
    up = TB[short]["up"]
    if b["type"] == "原子指标":
        if b["src"] in up or b["src"] not in TB:
            src = b["src"]
            fs = calc_fields(b["calc"], src)
            if fs:
                return [[src, f] for f in fs], "%s：%s" % (src, b["calc"])
            if src in up:
                return [[src, (SCH[src]["cols"][0]["n"] if src in SCH else "")]], "%s：%s" % (src, b["calc"])
        hit = find_src([u for u in up if u.startswith("dws_")], b["en"])
        if hit:
            return [hit], "%s.%s 汇总" % tuple(hit)
        fs = calc_fields(b["calc"], b["src"])
        return [[b["src"], f] for f in fs] or [[b["src"], ""]], "%s：%s" % (b["src"], b["calc"])
    # 计算 / 派生：依赖本表或上游的其它指标
    deps = base_deps(b)
    refs = []
    for d in deps:
        h = find_src([u for u in up if u.startswith("dws_")], d)
        refs.append(h or [short, d])
    if not refs:
        fs = calc_fields(b["calc"], b["src"])
        refs = [[b["src"], f] for f in fs]
    return refs, b["calc"]

def grain_refs(cols, up):
    for c in cols:
        if c["k"] != "粒度键" or c["r"]:
            continue
        refs = []
        for u in up:
            if u not in SCH:
                continue
            names = {x["n"] for x in SCH[u]["cols"]}
            for cand in S.GALIAS.get(c["n"], [c["n"]]):
                if cand in names:
                    refs.append([u, cand])
                    break
        if refs:
            c["r"] = refs
            c["s"] = "、".join("%s.%s" % tuple(h) for h in refs)
    return cols

def base_deps(b):
    out = []
    for x in IDENT.findall(b.get("calc") or ""):
        x2 = x if x in BASE else re.sub(r"_(t|m)$", "", x)
        if x2 in BASE and x2 != b["en"] and x2 not in out:
            out.append(x2)
    return out

def resolve(up, b, en):
    """指标列上游：同名指标 → 依赖指标 → 口径中引用的上游字段"""
    h = find_src(up, en)
    if h:
        return [h]
    refs = [find_src(up, d) for d in base_deps(b)] if b else []
    refs = [r for r in refs if r]
    if refs:
        return refs
    out = []
    for tk in IDENT.findall((b or {}).get("calc") or ""):
        hh = find_src(up, tk)
        if hh and hh not in out:
            out.append(hh)
    return out

ADS_BY_TABLE = {}
for r in ads_m:
    ADS_BY_TABLE.setdefault(r["ads"], []).append(r)

def period_of(short):
    return "wk" if short.endswith("_wk") else ("mo" if short.endswith("_mo") else "")

for layer in ("DWS", "ADS"):
    for t in tables:
        if t["layer"] != layer:
            continue
        short = t["short"]
        cols = S.grain_cols(short, t["grain"], t["rt"], period_of(short))
        grain_refs(cols, t["up"])
        if layer == "ADS":  # 业务可读：补维度名称
            extra = []
            for c in cols:
                if c["n"] in S.NAME_COL:
                    n, cn, dim, f = S.NAME_COL[c["n"]]
                    extra.append(S.col(n, "STRING", cn, "维度属性", "%s.%s 按 %s 关联" % (dim, f, c["n"]), [[dim, f]]))
            cols += extra
        if layer == "DWS":
            for en in t["metrics"]:
                b = BASE.get(en)
                if not b:
                    continue
                refs, how = dws_metric_refs(short, b)
                cols.append(metric_col(en, b["dtype"], b["cn"], b["kou"], unit_txt(b, en), refs, how))
        else:
            for r in ADS_BY_TABLE.get(short, []):
                b = BASE.get(r["base"])
                refs = resolve(t["up"], b, r["base"]) or [[t["up"][0], r["base"]]]
                c = metric_col(r["en"], r["dtype"], r["cn"], r["kou"], unit_txt(r, r["en"]), refs, r["formula"])
                cols.append(c)
        if t["rt"]:
            cols.append(S.col("update_time", "STRING", "最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss", "ETL", "Flink 写入"))
        else:
            cols += S.ETL()
        finish(short, cols)

# ------------------------------------------------ 本表内派生字段：引用同表字段
for short, v in SCH.items():
    names = {c["n"] for c in v["cols"]}
    for c in v["cols"]:
        if not c["r"] and c["k"] not in ("ETL", "拉链"):
            c["r"] = [[short, tk] for tk in dict.fromkeys(IDENT.findall(c["s"])) if tk in names and tk != c["n"]]

# ------------------------------------------------ 字段类别细化：主键/业务主键
for short, v in SCH.items():
    t = TB[short]
    for c in v["cols"]:
        if t["layer"] in ("DWD", "DIM") and c["k"] in ("外键", "退化维度"):
            ent = None
            for sp in (S.DWD.get(short), S.DIM.get(short)):
                if sp:
                    ent = sp["entity"]
            if ent and c["n"] == ent + "_id":
                c["k"] = "主键"

# ------------------------------------------------ 粒度描述与字段名对齐（粒度 token → 规范字段名）
def norm_grain(short, g):
    g = S.RT_GRAIN.get(short, g)
    return re.sub(r"[a-z][a-z_0-9]*", lambda m: S.GCOL[m.group(0)][0] if m.group(0) in S.GCOL else m.group(0), g)
for t in tables:
    if t["layer"] in ("DWS", "ADS"):
        t["grain"] = norm_grain(t["short"], t["grain"])
for r in ads_m:
    r["grain"] = TB[r["ads"]]["grain"]

# ------------------------------------------------ 实时链路说明：Flink CDC 直读 binlog，不经 Kafka
for t in tables:
    if not t["rt"]:
        continue
    if t["layer"] == "ODS":
        st_ = ODS[t["short"]]["st"]
        t["src"] = "%s.%s（Flink CDC 读 binlog）" % (t["db"], st_)
        t["part"] = "不落地：Flink CDC 源表，作业内直读 binlog"
        t["grain"] = "同源表，1行=1条源记录（CDC 变更流）"
    else:
        t["part"] = "StarRocks 按 travel_date 分区"
        if t["layer"] == "DWD":
            t["grain"] = TB[RT_DWD[t["short"]]]["grain"]

# ------------------------------------------------ DDL
RT_SERVER_ID = {}
for i, t in enumerate([t for t in tables if t["rt"] and t["layer"] == "ODS"]):
    RT_SERVER_ID[t["short"]] = "%d-%d" % (5401 + i * 4, 5404 + i * 4)
for short, v in SCH.items():
    t = TB[short]
    cols = v["cols"]
    name = hive_name(t)
    cn = "%s（%s）" % (t["cn"], t["grain"])
    if not t["rt"]:
        part = "无分区" not in t["part"]
        v["ddl"] = S.ddl_hive(name, cn, cols, part)
        v["engine"] = "Hive（ORC）"
    elif t["layer"] == "ODS":
        db, st = t["db"], ODS[short]["st"]
        v["ddl"] = S.ddl_flink_cdc(name, cn, cols, db, st, RT_SERVER_ID[short])
        v["engine"] = "Flink CDC（mysql-cdc 源表）"
    else:
        keys = v.get("keys") or [c["n"] for c in cols if c["k"] == "粒度键"]
        # 主键列必须排在最前
        cols2 = [c for c in cols if c["n"] in keys] + [c for c in cols if c["n"] not in keys]
        v["cols"] = cols2
        v["ddl"] = S.ddl_starrocks(name, cn, cols2, keys)
        v["engine"] = "StarRocks 主键模型"

# ------------------------------------------------ 字段级下游（被谁引用）
for short, v in SCH.items():
    for c in v["cols"]:
        for a, b in c["r"]:
            if a in SCH:
                for c2 in SCH[a]["cols"]:
                    if c2["n"] == b:
                        c2.setdefault("d", [])
                        if [short, c["n"]] not in c2["d"]:
                            c2["d"].append([short, c["n"]])

# ------------------------------------------------ 校验
SCHEMA_CHECK = dict(
    tables=len(SCH), cols=sum(len(v["cols"]) for v in SCH.values()),
    missing=[t["short"] for t in tables if t["short"] not in SCH],
    no_comment=[(k, c["n"]) for k, v in SCH.items() for c in v["cols"] if not c["c"]],
    bad_ref=[(k, c["n"], a, b) for k, v in SCH.items() for c in v["cols"] for a, b in c["r"]
             if a in SCH and b and not any(x["n"] == b for x in SCH[a]["cols"])],
    no_ref=[(k, c["n"]) for k, v in SCH.items() if TB[k]["layer"] != "ODS" for c in v["cols"]
            if not c["r"] and c["k"] not in ("ETL", "拉链") and k != "dim_opr_date_f" and "常量" not in c["s"]],
    bad_name=[(k, c["n"]) for k, v in SCH.items() if TB[k]["layer"] != "ODS" for c in v["cols"]
              if c["k"] in ("状态类型",) and not c["n"].endswith(("_type", "_status"))],
)
