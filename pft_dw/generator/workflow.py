# -*- coding: utf-8 -*-
"""调度工作流 + 数据质量检测：在 make_all 命名空间内 exec（依赖 tables / SCH / TB / BASE / ads_m / M）
- 任务依赖取自字段级血缘：一张表只等它真正读到的上游
- 每个表任务后挂一个质检节点（dq.<表名>）：强规则失败则阻断下游，弱规则只告警
- 下游任务依赖上游的质检节点，而不是上游任务本身
"""
import re, os, json, yaml
from collections import defaultdict, OrderedDict

WF_DIR = os.path.join(OUT, "workflow")
CORE = re.compile(r"(order|ticket|payment|verify|refund|trade|settle|fund_flow|frozen|account_balance)")

# ------------------------------------------------------------ 频率
def freq_of(t):
    s = t["short"]
    if t["rt"]:
        return "realtime"
    if s.endswith("_wk"):
        return "weekly"
    if s.endswith("_mo"):
        return "monthly"
    if s == "dim_opr_date_f":
        return "yearly"
    return "daily"

FLOWS = OrderedDict([
    ("daily", dict(name="日调度", cron="0 30 0 * * ?", when="每日 00:30 启动，处理 T-1（${bizdate}）数据", sla="ADS 07:30 前就绪")),
    ("weekly", dict(name="周调度", cron="0 0 8 ? * MON", when="每周一 08:00，等待日调度周日分区质检通过后启动", sla="周一 09:00 前")),
    ("monthly", dict(name="月调度", cron="0 0 8 1 * ?", when="每月 1 日 08:00，等待日调度上月末分区质检通过后启动", sla="1 日 10:00 前")),
    ("yearly", dict(name="年调度", cron="0 0 1 1 12 ?", when="每年 12 月 1 日生成下一年日期维度（节假日公布后可手工重跑）", sla="—")),
    ("realtime", dict(name="实时作业", cron="常驻", when="Flink 作业 7×24 运行，监控项每分钟采集", sla="端到端延迟 ≤ 1 分钟")),
])

# ------------------------------------------------------------ 依赖：表级血缘 + 字段引用
def table_deps(short):
    t = TB[short]
    deps = set(u for u in t["up"] if u in TB)
    for c in SCH[short]["cols"]:
        for a, b in c["r"]:
            if a in TB and a != short:
                deps.add(a)
    return deps

TASKS = {}
for t in tables:
    s = t["short"]
    TASKS[s] = dict(id=s, kind="task", table=s, layer=t["layer"], domain=t["domain"], cn=t["cn"], name=t["name"],
                    flow=freq_of(t), rt=t["rt"], deps=sorted(table_deps(s)))

# ------------------------------------------------------------ 环检测：同周期内互相引用的回填字段改为依赖上一周期（T-1）
CUT = []          # [下游, 上游, 原因]
def edge_weight(u, d):
    """u 依赖 d 的强度：表级血缘里的依赖不可切（权重大）；只因个别回填字段产生的依赖权重 = 引用字段数"""
    if d in TB[u]["up"]:
        return 1000
    return sum(1 for c in SCH[u]["cols"] if any(a == d for a, b in c["r"]))

def find_one_cycle(flow):
    ids = sorted(k for k, v in TASKS.items() if v["flow"] == flow)
    idset, color = set(ids), {}
    path = []
    def dfs(u):
        color[u] = 1
        path.append(u)
        for d in TASKS[u]["deps"]:
            if d not in idset:
                continue
            if color.get(d) == 1:
                return path[path.index(d):] + [d]
            if not color.get(d):
                r = dfs(d)
                if r:
                    return r
        color[u] = 2
        path.pop()
        return None
    for i in ids:
        if not color.get(i):
            r = dfs(i)
            if r:
                return r
    return None

for flow in ("daily", "realtime"):
    while True:
        cyc = find_one_cycle(flow)
        if not cyc:
            break
        edges = list(zip(cyc[:-1], cyc[1:]))
        u, d = min(edges, key=lambda e: edge_weight(*e))
        TASKS[u]["deps"].remove(d)
        TASKS[u].setdefault("cut", []).append(d)
        fs = [c["n"] for c in SCH[u]["cols"] if any(a == d for a, b in c["r"])]
        CUT.append([u, d, "回填字段 %s 读 %s 的上一周期分区（${bizdate} - 1），避免同周期互相等待" % ("、".join(fs) or "—", d)])

# 跨周期依赖：日任务依赖年维表、周/月任务依赖日任务 → 不画进本流程，改为“依赖已完成的最近周期”
for v in TASKS.values():
    keep, cross = [], []
    for d in v["deps"]:
        if TASKS[d]["flow"] == v["flow"]:
            keep.append(d)
        else:
            cross.append(d)
    v["deps"], v["cross"] = keep, cross

# ------------------------------------------------------------ 主键 / 外键
PK_OVERRIDE = {
    "dwd_ord_order_status_log_di": ["order_no", "change_time", "after_status"],
    "dwd_ord_ticket_status_log_di": ["ticket_no", "change_time", "after_status"],
    "dwd_ord_refund_ticket_di": ["refund_no", "ticket_no"],
    "dwd_trf_distribution_settle_di": ["payment_no"],
    "dwd_prd_sku_price_calendar_df": ["sku_id", "price_date", "price_channel_code", "ext_dim_desc"],
    "dwd_opr_device_status_log_di": ["device_id", "change_time"],
    "dwd_inv_pool_change_di": ["pool_id", "change_time"], "dwd_inv_unit_change_di": ["unit_id", "change_time"],
    "dwd_prd_price_point_log_di": ["price_point_id", "change_time"], "dwd_opr_blacklist_log_di": ["blacklist_id", "change_time"],
    "dim_opr_date_f": ["date_code"],
}
def pk_of(short):
    t = TB[short]
    if short in PK_OVERRIDE:
        return PK_OVERRIDE[short]
    cols = SCH[short]["cols"]
    if t["layer"] in ("DWS", "ADS"):
        return [c["n"] for c in cols if c["k"] == "粒度键"]
    if t["layer"] == "ODS":
        return ["id"] if short.endswith("_df") or short.endswith("_f") else []
    return [c["n"] for c in cols if c["k"] == "主键"][:1]

FK = {}
for col_, dim, key in [
    ("seller_tenant_id", "dim_sup_tenant_zip", "tenant_id"), ("supplier_tenant_id", "dim_sup_tenant_zip", "tenant_id"),
    ("distributor_tenant_id", "dim_sup_tenant_zip", "tenant_id"), ("payer_tenant_id", "dim_sup_tenant_zip", "tenant_id"),
    ("payee_tenant_id", "dim_sup_tenant_zip", "tenant_id"), ("register_tenant_id", "dim_sup_tenant_zip", "tenant_id"),
    ("bind_tenant_id", "dim_sup_tenant_zip", "tenant_id"), ("sku_id", "dim_prd_sku_zip", "sku_id"), ("spu_id", "dim_prd_spu_zip", "spu_id"),
    ("channel_id", "dim_trf_channel_df", "channel_id"), ("register_channel_id", "dim_trf_channel_df", "channel_id"),
    ("bind_channel_id", "dim_trf_channel_df", "channel_id"), ("buyer_customer_id", "dim_cus_customer_zip", "customer_id"),
    ("customer_id", "dim_cus_customer_zip", "customer_id"), ("verify_point_id", "dim_opr_verify_point_df", "verify_point_id"),
    ("device_id", "dim_opr_device_df", "device_id"), ("account_no", "dim_fin_account_df", "account_no"),
    ("payer_account_no", "dim_fin_account_df", "account_no"), ("payee_account_no", "dim_fin_account_df", "account_no"),
    ("rule_id", "dim_opr_risk_rule_df", "risk_rule_id"), ("package_id", "dim_opr_package_df", "package_id"),
    ("pool_no", "dim_inv_pool_df", "pool_no"), ("code_pool_id", "dim_opr_code_pool_df", "code_pool_id"),
    ("staff_id", "dim_sup_staff_zip", "staff_id"), ("bank_card_id", "dim_fin_bank_card_df", "bank_card_id"),
    ("template_id", "dim_opr_notify_template_df", "notify_template_id"), ("flow_id", "dim_opr_approval_flow_df", "approval_flow_id"),
    ("invoice_config_id", "dim_fin_invoice_config_df", "invoice_config_id"), ("relation_no", "dim_trf_distribution_relation_zip", "relation_no"),
]:
    if dim in SCH and any(c["n"] == key for c in SCH[dim]["cols"]):
        FK[col_] = (dim, key)

def dim_filter(dim, alias="d"):
    if dim.endswith("_zip"):
        return "%s.end_date = '9999-12-31'" % alias
    if dim.endswith("_f"):
        return "1 = 1"
    return "%s.travel_date = '${bizdate}'" % alias

# ------------------------------------------------------------ 质检规则
RULES = defaultdict(list)     # dq 节点 id -> [rule]
RULE_SEQ = [0]
def rule(node, code, name, level, sql, expect, desc, ref=None):
    RULE_SEQ[0] += 1
    RULES[node].append(dict(id="R%04d" % RULE_SEQ[0], code=code, name=name, level=level, sql=sql.strip(), expect=expect, desc=desc,
                            ref=ref or []))

def part(short, alias=""):
    t = TB[short]
    if "无分区" in t["part"]:
        return "1 = 1"
    return "%stravel_date = '${bizdate}'" % (alias + "." if alias else "")

def fq(short):
    return TB[short]["name"]

CODE_RE = re.compile(r"(?<![A-Za-z0-9_])([A-Z][A-Z0-9_]+)-")
NUM_RE = re.compile(r"(?<![0-9])(\d+)[-=]")
GROWTH = re.compile(r"_(dod|wow|mom|yoy)_|gross_profit|distribution_profit")
CAP100 = re.compile(r"share|sellout|sell_through|online|code_pool_usage|code_recycle|tenant_active|realname|person_link|face_register")
NEG_OK = re.compile(r"change|profit|diff|net_|before|after|_dod_|_wow_|_mom_")

def src_count_sql(short):
    t = TB[short]
    db, st = t["src"].split(".")[0], t["src"].split(".")[1].split("（")[0]
    names = {c[0] for c in S.SRC[st]["cols"]}
    if short.endswith("_di"):
        tcol = "update_time" if "update_time" in names else ("create_time" if "create_time" in names else None)
        if not tcol:
            return None
        return ("-- MySQL 源端（%s）\nSELECT COUNT(*) FROM `%s`.%s WHERE %s >= '${bizdate_begin}' AND %s < '${bizdate_end}';\n"
                "-- 数仓端\nSELECT COUNT(DISTINCT id) FROM %s WHERE travel_date = '${bizdate}';") % (db, db, st, tcol, tcol, fq(short))
    return ("-- MySQL 源端（%s，抽数时刻快照）\nSELECT COUNT(*) FROM `%s`.%s;\n-- 数仓端\nSELECT COUNT(*) FROM %s WHERE travel_date = '${bizdate}';"
            % (db, db, st, fq(short)))

for short, task in TASKS.items():
    t = TB[short]
    if t["rt"]:
        continue
    node = "dq." + short
    cols = SCH[short]["cols"]
    names = {c["n"] for c in cols}
    core = bool(CORE.search(short))
    lay = t["layer"]
    has_part = "无分区" not in t["part"]
    # 1 完整性：分区有数
    rule(node, "完整性", "当日分区有数据", "强" if core or lay in ("DWS", "ADS") and core else "弱",
         "SELECT COUNT(*) AS cnt FROM %s WHERE %s;" % (fq(short), part(short)), "cnt > 0",
         "核心交易表空分区直接阻断下游；非交易表（投诉、审批等）允许当天无数据，只告警" if core else "允许当天无业务发生，只告警")
    # 2 ODS 源端对账
    if lay == "ODS":
        sq = src_count_sql(short)
        if sq:
            rule(node, "一致性", "与业务库行数对账", "强" if core else "弱", sq,
                 "|数仓 − 源端| / 源端 ≤ 0.1%" if short.endswith("_di") else "数仓 = 源端",
                 "增量表按更新时间落在 T-1 的源记录数，对比 ODS 当日分区去重主键数；全量表比对总行数")
    # 3 唯一性
    pk = pk_of(short)
    if pk and not (lay == "ODS" and short.endswith("_di")):
        flt = "end_date = '9999-12-31'" if short.endswith("_zip") else part(short)
        rule(node, "唯一性", "主键/粒度唯一（%s）" % " + ".join(pk), "强",
             "SELECT COUNT(*) AS dup_cnt FROM (\n  SELECT %s, COUNT(*) AS c FROM %s WHERE %s GROUP BY %s HAVING COUNT(*) > 1\n) x;" % (
                 ", ".join(pk), fq(short), flt, ", ".join(pk)), "dup_cnt = 0",
             "重复会让下游汇总翻倍" + ("；拉链表只校验当前有效记录" if short.endswith("_zip") else ""))
        rule(node, "完整性", "主键/粒度键非空", "强",
             "SELECT COUNT(*) AS null_cnt FROM %s WHERE %s AND (%s);" % (fq(short), part(short) if not short.endswith("_zip") else "end_date = '9999-12-31'",
                                                                     " OR ".join("%s IS NULL" % k for k in pk)), "null_cnt = 0", "")
    # 4 拉链连续性
    if short.endswith("_zip"):
        k = pk[0]
        rule(node, "一致性", "拉链区间不重叠", "强",
             ("SELECT COUNT(*) AS overlap_cnt FROM (\n  SELECT %s, start_date, end_date,\n         LEAD(start_date) OVER (PARTITION BY %s ORDER BY start_date) AS next_start\n"
              "  FROM %s\n) x WHERE next_start IS NOT NULL AND next_start <= end_date;") % (k, k, fq(short)), "overlap_cnt = 0",
             "同一主键的有效区间首尾相接、不重叠")
        rule(node, "一致性", "每个主键恰有 1 条当前有效记录", "强",
             ("SELECT COUNT(*) AS bad_cnt FROM (\n  SELECT %s, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur\n"
              "  FROM %s GROUP BY %s\n) x WHERE cur <> 1;") % (k, fq(short), k), "bad_cnt = 0", "")
    if lay in ("DWD", "DWS"):
        # 5 参照完整性
        for c in cols:
            if c["n"] in FK and c["k"] in ("外键", "粒度键") and FK[c["n"]][0] != short:
                dim, key = FK[c["n"]]
                rule(node, "一致性", "%s 能关联到 %s" % (c["n"], dim), "弱",
                     ("SELECT SUM(CASE WHEN d.%s IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt\nFROM %s f\n"
                      "LEFT JOIN %s d ON f.%s = d.%s AND %s\nWHERE %s AND f.%s IS NOT NULL AND CAST(f.%s AS STRING) NOT IN ('0', '');") % (
                         key, fq(short), TB[dim]["name"], c["n"], key, dim_filter(dim), part(short, "f"), c["n"], c["n"]),
                     "miss_cnt / total_cnt ≤ 0.1%", "关联不上会在报表里落成“未知”；常见原因是维表晚到或源端脏数据", [[dim, key]])
                task.setdefault("dq_deps", set()).add(dim)
    if lay in ("DWD", "DIM", "DWS"):
        # 6 枚举合法
        for c in cols:
            if not c["n"].endswith(("_status", "_type")) or c["k"] not in ("状态类型", "粒度键"):
                continue
            if c["t"] == "STRING":
                vals = list(dict.fromkeys(CODE_RE.findall(c["c"])))
                if len(vals) >= 2:
                    rule(node, "有效性", "%s 取值在枚举内" % c["n"], "弱",
                         "SELECT %s, COUNT(*) AS cnt FROM %s WHERE %s AND %s IS NOT NULL\n  AND %s NOT IN (%s)\nGROUP BY %s;" % (
                             c["n"], fq(short), part(short), c["n"], c["n"], ", ".join("'%s'" % v for v in vals), c["n"]),
                         "无返回行", "取值清单来自字段注释；出现新值说明源系统新增了枚举，需同步码表与口径")
            else:
                vals = list(dict.fromkeys(NUM_RE.findall(c["c"])))
                if len(vals) >= 2:
                    rule(node, "有效性", "%s 取值在枚举内" % c["n"], "弱",
                         "SELECT %s, COUNT(*) AS cnt FROM %s WHERE %s AND %s NOT IN (%s) GROUP BY %s;" % (
                             c["n"], fq(short), part(short), c["n"], ", ".join(vals), c["n"]), "无返回行", "")
    # 7 值域
    if lay in ("DWD", "DWS", "ADS"):
        neg = [c["n"] for c in cols if c["n"].endswith(("_amt", "_qty")) and c["k"] in ("度量", "指标") and not NEG_OK.search(c["n"])]
        if neg:
            rule(node, "有效性", "金额/数量非负（%d 个字段）" % len(neg), "弱",
                 "SELECT\n%s\nFROM %s WHERE %s;" % (",\n".join("  SUM(CASE WHEN %s < 0 THEN 1 ELSE 0 END) AS %s_neg" % (n, n) for n in neg[:40]), fq(short), part(short)),
                 "全部为 0", "变动额、利润、净额类字段允许为负，已排除")
        rates = [c["n"] for c in cols if c["n"].endswith("_rate") and not GROWTH.search(c["n"])]
        if rates:
            cap = [r for r in rates if CAP100.search(r)]
            rule(node, "有效性", "比率值域（%d 个字段）" % len(rates), "弱",
                 "SELECT\n%s\nFROM %s WHERE %s;" % (",\n".join(
                     "  SUM(CASE WHEN %s < 0%s THEN 1 ELSE 0 END) AS %s_bad" % (r, " OR %s > 100" % r if r in cap else "", r) for r in rates[:40]), fq(short), part(short)),
                 "全部为 0", "比率存百分数数值；占比、售罄、在线类不超过 100，转化/退款类因跨期可能超过 100，只校验非负；环比、毛利率不校验")
    # 8 波动
    if lay in ("DWD", "DWS", "ADS") and has_part and not short.endswith(("_wk", "_mo")):
        amt = [c["n"] for c in cols if c["k"] in ("度量", "指标") and re.search(r"^(pay|order|verify|refund)_.*(amt|qty)$", c["n"])][:1]
        expr = "COUNT(*)" if not amt else "SUM(%s)" % amt[0]
        rule(node, "及时性/波动", "%s 与近 7 日均值相比波动 ≤ 50%%" % ("行数" if not amt else amt[0]), "弱",
             ("WITH d AS (\n  SELECT travel_date, %s AS v FROM %s\n  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date\n)\n"
              "SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,\n       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7\nFROM d;") % (expr, fq(short)),
             "avg7 = 0 或 |cur / avg7 − 1| ≤ 50%", "节假日首日、大促日会触发，告警人确认后放行")

# ------------------------------------------------------------ 勾稽（同一行内的计算关系）与跨层对账
def comp_parts(calc):
    m = re.match(r"^\s*([a-z][a-z0-9_]*)\s*-\s*([a-z][a-z0-9_]*)\s*$", calc or "")
    if m:
        return "-", m.group(1), m.group(2)
    m = re.match(r"^\s*([a-z][a-z0-9_]*)\s*/\s*([a-z][a-z0-9_]*)\s*$", calc or "")
    if m:
        return "/", m.group(1), m.group(2)
    return None

for t in tables:
    if t["rt"] or t["layer"] not in ("DWS", "ADS"):
        continue
    short, node = t["short"], "dq." + t["short"]
    names = {c["n"] for c in SCH[short]["cols"]}
    pairs = []
    if t["layer"] == "DWS":
        for en in t["metrics"]:
            b = BASE.get(en)
            p = b and b["type"] != "原子指标" and comp_parts(b["calc"])
            if p and p[1] in names and p[2] in names:
                pairs.append((en, p))
    else:
        grp = defaultdict(dict)
        for r in ads_m:
            if r["ads"] == short and r["mod"] == "—":
                grp[r["period"]][r["base"]] = r["en"]
        for per, mp in grp.items():
            for bn, en in mp.items():
                b = BASE.get(bn)
                p = b and b["type"] != "原子指标" and comp_parts(b["calc"])
                if p and p[1] in mp and p[2] in mp:
                    pairs.append((en, (p[0], mp[p[1]], mp[p[2]])))
    for en, (op, a, b_) in pairs[:12]:
        if op == "-":
            rule(node, "一致性", "勾稽：%s = %s − %s" % (en, a, b_), "强",
                 "SELECT COUNT(*) AS bad_cnt FROM %s WHERE %s AND ABS(COALESCE(%s, 0) - (COALESCE(%s, 0) - COALESCE(%s, 0))) > 0.01;" % (fq(short), part(short), en, a, b_),
                 "bad_cnt = 0", "同一行内的计算关系必须成立")
        else:
            rule(node, "一致性", "勾稽：%s = %s × 100 / %s" % (en, a, b_), "弱",
                 ("SELECT COUNT(*) AS bad_cnt FROM %s WHERE %s AND %s <> 0\n  AND ABS(%s - ROUND(%s * 100 / %s, 6)) > 0.000001;") % (fq(short), part(short), b_, en, a, b_),
                 "bad_cnt = 0", "分母为 0 时比率应为 NULL")

# DWS ↔ DWD：纯 SUM 口径对账
for t in tables:
    if t["rt"] or t["layer"] != "DWS":
        continue
    short = t["short"]
    for en in t["metrics"]:
        b = BASE.get(en)
        m = b and re.match(r"^sum\(([a-z_]+)\)$", b["calc"].strip())
        if not m or b["src"] not in TB or TB[b["src"]]["layer"] != "DWD" or b["src"] not in t["up"]:
            continue
        f = m.group(1)
        if not any(c["n"] == f for c in SCH[b["src"]]["cols"]):
            continue
        rule("dq." + short, "一致性", "对账：%s 与 %s.%s 合计一致" % (en, b["src"], f), "弱",
             "SELECT (SELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}') AS dws_v,\n       (SELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}') AS dwd_v;" % (
                 en, fq(short), f, TB[b["src"]]["name"]), "|dws_v − dwd_v| ≤ 0.01", "汇总层不丢不重", [[b["src"], f]])

# ADS ↔ DWS：当日、无修饰词的原子指标合计一致
for r in ads_m:
    if r["mode"] != "离线" or r["period"] != "当日" or r["mod"] != "—":
        continue
    b = BASE.get(r["base"])
    if not b or b["type"] != "原子指标" or not r["en"].endswith(("_amt", "_qty")):
        continue
    c = next((x for x in SCH[r["ads"]]["cols"] if x["n"] == r["en"]), None)
    if not c or len(c["r"]) != 1 or c["r"][0][1] != r["base"] or not c["r"][0][0].startswith("dws_"):
        continue
    dws = c["r"][0][0]
    if dws.endswith("_df"):
        continue
    rule("dq." + r["ads"], "一致性", "对账：%s 与 %s.%s 合计一致" % (r["en"], dws, r["base"]), "弱",
         "SELECT (SELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}') AS ads_v,\n       (SELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}') AS dws_v;" % (
             r["en"], TB[r["ads"]]["name"], r["base"], TB[dws]["name"]), "|ads_v − dws_v| ≤ 0.01", "报表与汇总层同口径同数", [[dws, r["base"]]])

# ------------------------------------------------------------ 实时 vs 离线 对账（日调度里执行）
RECON = [
    ("dws_ord_tenant_sku_trade_rt", "pay_amt", "dws_sup_tenant_trade_di", "pay_amt"),
    ("dws_ord_tenant_sku_trade_rt", "pay_order_qty", "dws_sup_tenant_trade_di", "pay_order_qty"),
    ("dws_ord_tenant_sku_trade_rt", "refund_amt", "dws_sup_tenant_trade_di", "refund_amt"),
    ("dws_ord_verify_point_flow_rt", "verify_person_qty", "dws_ord_verify_point_flow_hrs", "verify_person_qty"),
    ("dws_opr_risk_rule_hit_rt", "risk_hit_qty", "dws_opr_risk_rule_hit_di", "risk_hit_qty"),
]
RECON_NODES = {}
for rt_t, rt_c, off_t, off_c in RECON:
    if rt_t not in SCH or off_t not in SCH:
        continue
    if not any(c["n"] == rt_c for c in SCH[rt_t]["cols"]) or not any(c["n"] == off_c for c in SCH[off_t]["cols"]):
        continue
    nid = "dq.recon." + rt_t
    RECON_NODES.setdefault(nid, dict(rt=rt_t, off=set()))["off"].add(off_t)
    rule(nid, "一致性", "实时 %s.%s 与离线 %s.%s 对账" % (rt_t, rt_c, off_t, off_c), "弱",
         ("-- StarRocks 实时\nSELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}';\n-- Hive 离线\nSELECT SUM(%s) FROM %s WHERE travel_date = '${bizdate}';") % (
             rt_c, TB[rt_t]["name"], off_c, TB[off_t]["name"]),
         "|实时 − 离线| / 离线 ≤ 0.5%", "实时口径以离线为准；超阈值说明 CDC 丢数、乱序或窗口迟到数据未处理", [[rt_t, rt_c], [off_t, off_c]])

# ------------------------------------------------------------ 实时作业：按连通分量划分 Flink 作业，挂监控
rt_ids = [k for k, v in TASKS.items() if v["flow"] == "realtime"]
parent = {k: k for k in rt_ids}
def fnd(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x
for k in rt_ids:
    for d in TASKS[k]["deps"]:
        if d in parent and TB[d]["layer"] != "ODS" or (d in parent and TB[k]["layer"] == "DWD"):
            parent[fnd(k)] = fnd(d)
groups = defaultdict(list)
for k in rt_ids:
    if TB[k]["layer"] != "ODS":
        groups[fnd(k)].append(k)
JOBS = []
for i, (g, members) in enumerate(sorted(groups.items(), key=lambda x: x[0]), 1):
    srcs = sorted({d for m in members for d in TASKS[m]["deps"] if TB.get(d, {}).get("layer") == "ODS"})
    sinks = sorted(members)
    ads = [m for m in sinks if TB[m]["layer"] == "ADS"]
    jid = "flink_job_%s" % (ads[0].replace("ads_", "").replace("_rt", "") if ads else sinks[-1])
    JOBS.append(dict(id=jid, sources=srcs, sinks=sinks))
    for m in members:
        TASKS[m]["job"] = jid
    for s_ in srcs:
        TASKS[s_].setdefault("jobs", []).append(jid)
for s_ in [k for k in rt_ids if TB[k]["layer"] == "ODS"]:
    node = "dq." + s_
    rule(node, "及时性", "CDC 采集延迟 ≤ 60 秒", "强",
         "Flink 指标：currentFetchEventTimeLag（毫秒），按作业 %s 的源算子 %s 采集" % ("、".join(TASKS[s_].get("jobs", [])), s_),
         "连续 3 分钟 > 60000 告警并电话通知", "binlog 堆积、源库主从切换、server-id 冲突都会体现为延迟上升")
    rule(node, "完整性", "CDC 全量快照完成且进入增量", "强", "Flink 指标：isSnapshotSplitFinished / sourceIdleTime", "启动后 30 分钟内进入增量阶段", "")
for k in rt_ids:
    if TB[k]["layer"] == "ODS":
        continue
    node = "dq." + k
    tcol = "event_time" if TB[k]["layer"] == "DWD" else "update_time"
    rule(node, "及时性", "数据新鲜度 ≤ 5 分钟", "强",
         "SELECT TIMESTAMPDIFF(SECOND, MAX(%s), NOW()) AS lag_s FROM %s WHERE travel_date = DATE_FORMAT(NOW(), '%%Y%%m%%d');" % (tcol, TB[k]["name"]),
         "lag_s ≤ 300（营业时间 08:00–22:00）", "StarRocks 侧每分钟巡检")
    pk = SCH[k].get("keys") or [c["n"] for c in SCH[k]["cols"] if c["k"] == "粒度键"]
    if TB[k]["layer"] != "DWD":
        rule(node, "有效性", "金额/数量非负", "弱",
             "SELECT COUNT(*) FROM %s WHERE travel_date = DATE_FORMAT(NOW(), '%%Y%%m%%d') AND (%s);" % (
                 TB[k]["name"], " OR ".join("%s < 0" % c["n"] for c in SCH[k]["cols"] if c["k"] == "指标" and c["n"].endswith(("_amt", "_qty")) and not NEG_OK.search(c["n"])) or "1 = 0"),
             "0", "")
for j in JOBS:
    rule("dq." + j["id"], "及时性", "Checkpoint 成功", "强", "Flink 指标：numberOfFailedCheckpoints、lastCheckpointDuration",
         "连续 3 次失败或单次 > 5 分钟告警", "")
    rule("dq." + j["id"], "及时性", "无持续反压", "弱", "Flink 指标：backPressuredTimeMsPerSecond", "任一算子 > 500 持续 5 分钟告警", "")

# ------------------------------------------------------------ 组装节点
NODES = OrderedDict()
def add_node(**kw):
    NODES[kw["id"]] = kw

STAGE = {"ODS": "ODS 同步", "DIM": "DIM 维度", "DWD": "DWD 明细", "DWS": "DWS 汇总", "ADS": "ADS 应用"}
def dep_target(d):
    return "dq." + d if "dq." + d in RULES else d

for fl in FLOWS:
    if fl == "realtime":
        continue
    fl_tasks = [v for v in TASKS.values() if v["flow"] == fl]
    if not fl_tasks:
        continue
    start = "start." + fl
    if fl == "daily":
        add_node(id=start, kind="start", flow=fl, cn="源库就绪检查",
                 desc="检查 18 个业务库 T-1 数据已完结：增量同步位点越过 ${bizdate_end}，源库主从延迟 < 60 秒", deps=[])
    else:
        ups = sorted({d for v in fl_tasks for d in v["cross"] if TASKS[d]["flow"] == "daily"})
        add_node(id=start, kind="start", flow=fl, cn="等待日调度完成",
                 desc="依赖日调度中以下质检节点在%s通过：%s" % ("周日分区" if fl == "weekly" else ("上月末分区" if fl == "monthly" else "最近一次"), "、".join(ups) or "无"),
                 deps=[], cross=["dq." + u for u in ups])
    for v in fl_tasks:
        deps = [dep_target(d) for d in v["deps"]] or [start]
        dq_extra = sorted(d for d in v.get("dq_deps", set()) if TASKS[d]["flow"] == fl and d not in v["deps"])
        t = TB[v["id"]]
        add_node(id=v["id"], kind="task", flow=fl, table=v["id"], layer=v["layer"], domain=v["domain"], cn=v["cn"], name=v["name"],
                 stage=STAGE[v["layer"]], deps=deps, cut=["dq." + c if "dq." + c in RULES else c for c in v.get("cut", [])],
                 cross=["dq." + c if "dq." + c in RULES else c for c in v["cross"]],
                 engine=SCH[v["id"]]["engine"], retries=3 if v["layer"] == "ODS" else 2, timeout_min=60 if v["layer"] in ("ODS", "DWD") else 40,
                 priority="高" if CORE.search(v["id"]) else "中",
                 cmd=("sync/ods/%s.json  # 源 %s → %s" % (v["id"], t["src"], v["name"])) if v["layer"] == "ODS" else "sql/%s/%s.sql" % (v["layer"].lower(), v["id"]))
        if "dq." + v["id"] in RULES:
            rs = RULES["dq." + v["id"]]
            add_node(id="dq." + v["id"], kind="dq", flow=fl, table=v["id"], layer=v["layer"], domain=v["domain"], cn=v["cn"] + " 质检",
                     deps=[v["id"]] + ["dq." + d if "dq." + d in RULES else d for d in dq_extra],
                     block=any(r["level"] == "强" for r in rs), strong=sum(r["level"] == "强" for r in rs), weak=sum(r["level"] == "弱" for r in rs))
    if fl == "daily":
        for nid, rc in RECON_NODES.items():
            add_node(id=nid, kind="recon", flow=fl, cn="实时/离线对账：" + TB[rc["rt"]]["cn"], table=rc["rt"], layer="DWS", domain=TB[rc["rt"]]["domain"],
                     deps=sorted("dq." + o for o in rc["off"]), block=False, strong=0, weak=len(RULES[nid]))
    # 结束节点：本流程所有末端
    has_down = {d for n in NODES.values() if n["flow"] == fl for d in n["deps"]}
    ends = [n["id"] for n in NODES.values() if n["flow"] == fl and n["id"] not in has_down and n["kind"] != "start"]
    add_node(id="end." + fl, kind="end", flow=fl, cn="数据就绪 · 发布",
             desc="写就绪标记（_SUCCESS / 元数据就绪表），触发报表缓存刷新与下游订阅；任一强校验失败则不发布并电话告警", deps=sorted(ends))

# 实时
for v in TASKS.values():
    if v["flow"] != "realtime":
        continue
    deps = [dep_target(d) if d in TASKS and TASKS[d]["flow"] == "realtime" else d for d in v["deps"]] or []
    add_node(id=v["id"], kind="task", flow="realtime", table=v["id"], layer=v["layer"], domain=v["domain"], cn=v["cn"], name=v["name"],
             stage=STAGE[v["layer"]], deps=deps, cut=[], cross=[], engine=SCH[v["id"]]["engine"], job=v.get("job") or "、".join(v.get("jobs", [])),
             priority="高", retries=0, timeout_min=0,
             cmd=("Flink CDC 源表，由作业 %s 读取" % "、".join(v.get("jobs", []))) if v["layer"] == "ODS" else "Flink 作业 %s 写入 StarRocks" % v.get("job"))
    rs = RULES.get("dq." + v["id"], [])
    if rs:
        add_node(id="dq." + v["id"], kind="dq", flow="realtime", table=v["id"], layer=v["layer"], domain=v["domain"], cn=v["cn"] + " 监控",
                 deps=[v["id"]], block=False, monitor=True, strong=sum(r["level"] == "强" for r in rs), weak=sum(r["level"] == "弱" for r in rs))
for j in JOBS:
    add_node(id="dq." + j["id"], kind="dq", flow="realtime", table=None, layer="DWS", domain=TB[j["sinks"][0]]["domain"],
             cn="作业 %s 运行监控" % j["id"], deps=[], job=j["id"], block=False, monitor=True,
             strong=sum(r["level"] == "强" for r in RULES["dq." + j["id"]]), weak=sum(r["level"] == "弱" for r in RULES["dq." + j["id"]]),
             desc="Flink 作业：读 %s；写 %s" % ("、".join(j["sources"]), "、".join(j["sinks"])))

for nid, n in NODES.items():
    n["rules"] = RULES.get(nid, [])

# ------------------------------------------------------------ 拓扑层级（最长路径），并校验无环
def levels(flow):
    ids = [k for k, n in NODES.items() if n["flow"] == flow]
    idset = set(ids)
    lv, visiting = {}, set()
    def L(x):
        if x in lv:
            return lv[x]
        if x in visiting:
            raise RuntimeError("cycle at " + x)
        visiting.add(x)
        ds = [d for d in NODES[x]["deps"] if d in idset]
        lv[x] = 0 if not ds else 1 + max(L(d) for d in ds)
        visiting.discard(x)
        return lv[x]
    for i in ids:
        L(i)
    return lv
for fl in FLOWS:
    for k, l in levels(fl).items():
        NODES[k]["level"] = l

# 关键路径（日调度）：按层级最深的链
def crit(flow):
    lv = {k: n["level"] for k, n in NODES.items() if n["flow"] == flow}
    if not lv:
        return []
    cur = max(lv, key=lambda k: (lv[k], k))
    path = [cur]
    while True:
        ds = [d for d in NODES[cur]["deps"] if d in lv]
        if not ds:
            break
        cur = max(ds, key=lambda d: (lv[d], d))
        path.append(cur)
    return path[::-1]

WF = dict(
    flows=[dict(id=k, **v, nodes=sum(1 for n in NODES.values() if n["flow"] == k),
                tasks=sum(1 for n in NODES.values() if n["flow"] == k and n["kind"] == "task"),
                dq=sum(1 for n in NODES.values() if n["flow"] == k and n["kind"] in ("dq", "recon")),
                rules=sum(len(n["rules"]) for n in NODES.values() if n["flow"] == k),
                depth=1 + max([n["level"] for n in NODES.values() if n["flow"] == k] or [0]),
                critical=crit(k) if k == "daily" else []) for k, v in FLOWS.items()],
    nodes=list(NODES.values()), cut=CUT, jobs=JOBS,
    rule_stats=dict(total=sum(len(v) for v in RULES.values()), strong=sum(r["level"] == "强" for v in RULES.values() for r in v),
                    weak=sum(r["level"] == "弱" for v in RULES.values() for r in v),
                    by_code=dict(__import__("collections").Counter(r["code"] for v in RULES.values() for r in v))),
)
for n in WF["nodes"]:
    for k in ("cut", "cross"):
        n.setdefault(k, [])

# ------------------------------------------------------------ 输出：调度定义 YAML + 质检 SQL
os.makedirs(WF_DIR, exist_ok=True)
for f in os.listdir(WF_DIR):
    if f.endswith((".yaml", ".sql", ".md")):
        os.remove(os.path.join(WF_DIR, f))

class _D(yaml.SafeDumper):
    pass
def _str(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|" if "\n" in data else None)
_D.add_representer(str, _str)
_D.add_representer(OrderedDict, lambda dumper, data: dumper.represent_dict(data.items()))

for i, (fl, meta) in enumerate(FLOWS.items(), 1):
    ns = [n for n in NODES.values() if n["flow"] == fl]
    ns.sort(key=lambda n: (n["level"], n["id"]))
    doc = OrderedDict()
    doc["workflow"] = "pft_dw_" + fl
    doc["name"] = "PFT 2.0 数仓 · " + meta["name"]
    doc["schedule"] = dict(cron=meta["cron"], timezone="Asia/Shanghai", description=meta["when"], sla=meta["sla"])
    if fl != "realtime":
        doc["params"] = dict(bizdate="${yyyyMMdd-1}  # 业务日期 T-1，格式 YYYYMMDD", bizdate_begin="${yyyy-MM-dd-1} 00:00:00",
                             bizdate_end="${yyyy-MM-dd} 00:00:00", bizdate_minus_7="${yyyyMMdd-8}")
        doc["policy"] = dict(dq_strong_fail="阻断：质检节点失败，下游不启动，电话 + 群告警", dq_weak_fail="告警：质检节点成功，推送告警到数据群，24 小时内处理",
                             task_retry="ODS 重试 3 次、其余 2 次，间隔 5 分钟", backfill="补数按依赖顺序重跑，质检同样执行")
    doc["tasks"] = []
    for n in ns:
        d = OrderedDict(name=n["id"], type={"task": "SQL" if n.get("layer") != "ODS" else "SYNC", "dq": "DATA_QUALITY", "recon": "DATA_QUALITY",
                                             "start": "CHECK", "end": "NOTIFY"}[n["kind"]])
        if fl == "realtime" and n["kind"] == "task":
            d["type"] = "FLINK_CDC_SOURCE" if n["layer"] == "ODS" else "FLINK_SINK"
        if fl == "realtime" and n["kind"] == "dq":
            d["type"] = "MONITOR"
        d["desc"] = n.get("cn", "") + ("：" + n["desc"] if n.get("desc") else "")
        if n.get("cmd"):
            d["command"] = n["cmd"]
        if n["deps"]:
            d["depends_on"] = n["deps"]
        if n.get("cut"):
            d["depends_on_previous_cycle"] = n["cut"]
        if n.get("cross"):
            d["depends_on_other_workflow"] = n["cross"]
        if n["kind"] == "task" and fl != "realtime":
            d["retries"], d["timeout_minutes"], d["priority"] = n["retries"], n["timeout_min"], n["priority"]
        if n["rules"]:
            d["on_fail"] = "阻断下游" if n.get("block") else "告警"
            d["rules"] = [OrderedDict(id=r["id"], dimension=r["code"], name=r["name"], level=r["level"], expect=r["expect"], sql=r["sql"]) for r in n["rules"]]
        doc["tasks"].append(d)
    with open(os.path.join(WF_DIR, "%02d_pft_dw_%s.yaml" % (i, fl)), "w", encoding="utf-8") as fh:
        fh.write("# 由 generator/make_all.py 生成，请勿手改。调度器无关的工作流定义，可转 DolphinScheduler / Airflow / Azkaban\n")
        yaml.dump(dict(doc), fh, Dumper=_D, allow_unicode=True, sort_keys=False, width=200)

with open(os.path.join(WF_DIR, "dq_rules.sql"), "w", encoding="utf-8") as fh:
    fh.write("-- PFT 2.0 数仓数据质量规则（%d 条：强 %d / 弱 %d）\n-- 强：失败阻断下游；弱：只告警。${bizdate} 为 T-1，格式 YYYYMMDD\n\n" % (
        WF["rule_stats"]["total"], WF["rule_stats"]["strong"], WF["rule_stats"]["weak"]))
    for n in NODES.values():
        if not n["rules"]:
            continue
        fh.write("-- ==================== %s  %s ====================\n" % (n["id"], n.get("cn", "")))
        for r in n["rules"]:
            fh.write("-- %s [%s][%s] %s；期望：%s\n%s\n\n" % (r["id"], r["level"], r["code"], r["name"], r["expect"], r["sql"]))

WF_CHECK = dict(
    nodes=len(NODES), tasks=sum(n["kind"] == "task" for n in NODES.values()), dq=sum(n["kind"] in ("dq", "recon") for n in NODES.values()),
    rules=WF["rule_stats"], cut=CUT,
    no_dq=[k for k, n in NODES.items() if n["kind"] == "task" and "dq." + k not in NODES],
    dangling=[(k, d) for k, n in NODES.items() for d in n["deps"] if d not in NODES],
    depth={f["id"]: f["depth"] for f in WF["flows"]},
)
