"""按字段血缘生成任务代码骨架。

输入为数仓生成器的产物（web/schema.json、web/data.json、web/workflow.json），
为每张表生成一段可直接阅读、改造后可运行的 SQL：
  离线 ODS   Spark SQL：JDBC 读业务库 -> INSERT OVERWRITE 分区
  离线 DIM/DWD  主表 + 关联表，逐字段按口径翻译；拉链表生成闭链/开链模板
  离线 DWS   每个来源一段聚合 CTE，UNION ALL 后按粒度汇总，再关联维度属性
  离线 ADS   以 DWS 字段为基数，按统计周期（1d/7d/30d/mtd/ytd…）开窗求和后组合派生指标
  实时 ODS   Flink CDC 源表定义
  实时 DWD/DWS/ADS  Flink SQL：临时视图 + StarRocks 结果表
无法从口径文字确定的字段写成 CAST(NULL …) 并以 "TODO 口径" 注释标出，统计在 TODO 计数里。
"""
import re
from collections import OrderedDict

ETL_EXPR = "DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyy-MM-dd HH:mm:ss')"
GENERIC_KEYS = {"id", "tenant_id", "create_time", "update_time", "create_by", "update_by", "deleted", "etl_time",
                "travel_date", "binlog_time", "binlog_op_type", "proc_time", "remark", "status", "version", "sort_no",
                "start_date", "end_date", "event_time", "description", "name", "currency", "currency_code"}
LAYER_DB = {"ODS": "ods", "DIM": "dim", "DWD": "dwd", "DWS": "dws", "ADS": "ads"}


def suffix(name):
    return name.rsplit("_", 1)[1]


def entity(name):
    """ods_ord_order_group_di -> order_group"""
    parts = name.split("_")
    return "_".join(parts[2:-1])


def db_of(name):
    return name.split("_", 1)[0]


def pad(rows, comment_col=56):
    """rows: [(sql, comment)] -> 对齐的多行文本"""
    out = []
    for i, (sql, cm) in enumerate(rows):
        sep = "," if i < len(rows) - 1 else ""
        line = "    " + sql + sep
        if cm:
            line = line.ljust(comment_col) + "  -- " + cm
        out.append(line)
    return "\n".join(out)


def window_of(col):
    """字段名中的统计周期 -> (标识, 中文)"""
    n = col
    for pat, w in [(r"_today(_|$)", "today"), (r"_ytd(_|$)", "ytd"), (r"_mtd(_|$)", "mtd"), (r"_td(_|$)", "td"),
                   (r"_1m(_|$)", "1m"), (r"_1w(_|$)", "1w"), (r"_(\d+)d(_|$)", None)]:
        m = re.search(pat, n)
        if m:
            return w or (m.group(1) + "d")
    return None


class Gen:
    def __init__(self, schema, tables, nodes, jobs):
        self.S = schema
        self.T = tables
        self.N = nodes
        self.job_of = {}
        for j in jobs:
            for t in j["sources"] + j["sinks"]:
                self.job_of[t] = j["id"]
        self.todo = 0

    # ---------- 公共 ----------
    def cols(self, t):
        return [c["n"] for c in self.S.get(t, {}).get("cols", [])]

    def pk(self, t):
        for c in self.S.get(t, {}).get("cols", []):
            if c["k"] == "主键":
                return c["n"]
        return "id" if "id" in self.cols(t) else None

    def rt(self, t):
        return t.endswith("_rt")

    def fq(self, t, rt_ctx=False):
        if rt_ctx:
            if t.endswith("_rt"):
                return t if t.startswith("ods_") else "v_" + t
            return "hive." + db_of(t) + "." + t      # 实时作业 lookup 离线维表（Hive Catalog）
        return db_of(t) + "." + t

    def todo_expr(self, col, why):
        self.todo += 1
        return f"CAST(NULL AS {self.ftype(col['t'])})", "TODO 口径：" + why

    @staticmethod
    def ftype(t):
        t = t.upper()
        if t.startswith(("VARCHAR", "CHAR")) or t in ("DATETIME", "DATE", "JSON", "TEXT"):
            return "STRING"
        if t.startswith("TINYINT"):
            return "INT"
        return t

    def header(self, t, kind, extra=()):
        info = self.T.get(t, {})
        node = self.N.get(t, {})
        lines = [
            "-- " + "=" * 74,
            f"-- 任务：{self.fq(t)}  {info.get('cn', '')}",
            f"-- 分层：{info.get('layer', '')} · {info.get('domain', '')}    {kind}",
        ]
        if info.get("grain"):
            lines.append(f"-- 粒度：{info['grain']}")
        if node.get("job"):
            lines.append(f"-- 所属 Flink 作业：{node['job']}（同作业任务以 STATEMENT SET 一并提交）")
        ups = [d for d in node.get("deps", [])]
        if ups:
            lines.append("-- 调度依赖：" + "、".join(ups[:8]) + (" 等 %d 个" % len(ups) if len(ups) > 8 else ""))
        for c in node.get("cut", []) or []:
            lines.append("-- 跨周期依赖：" + (c if isinstance(c, str) else " ".join(map(str, c))))
        lines += list(extra)
        lines.append("-- 代码由字段血缘自动生成；标“TODO 口径”的字段需按注释补全")
        lines.append("-- " + "=" * 74)
        return "\n".join(lines) + "\n"

    # ---------- 字段口径 -> 表达式 ----------
    def translate(self, col, ctx):
        """ctx: dict(main, alias(fn), rt, local(dict name->expr))"""
        s = (col.get("s") or "").strip()
        rt = ctx["rt"]
        name = col["n"]
        if col["k"] == "ETL" and ("调度写入" in s or not s):
            return ETL_EXPR, "ETL 加载时间"
        if s.startswith("常量"):
            return s.replace("常量", "").strip() or "1", s
        if s == "拉链计算":
            return None, "拉链"
        m = re.match(r"^(\w+)\.(\w+)(.*)$", s)
        if m and m.group(1) in self.S:
            src, f, rest = m.group(1), m.group(2), m.group(3).strip(" ，,")
            if src == ctx["self"]:  # 引用本表字段
                base = ctx["local"].get(f)
                if base is None:
                    return self.todo_expr(col, s)
            else:
                hint = None
                hm = re.search(r"按\s*([\w+=]+)", rest)
                if hm and not re.search(r"按\s*[\w+]+\s*(计数|汇总|聚合)", rest):
                    hint = hm.group(1)
                if "按下单时间取拉链" in rest:
                    hint = None
                agg = re.search(r"按\s*([\w+]+)\s*(汇总|计数)", rest)
                if agg:
                    a = ctx["agg"](src, f, agg.group(1), "SUM" if agg.group(2) == "汇总" else "COUNT")
                    if a is None:
                        return self.todo_expr(col, s)
                    return a, s
                fm = re.search(r"取\s*(\w+)\s*=\s*(\w+)", rest)
                alias = ctx["alias"](src, hint, (fm.group(1), fm.group(2)) if fm else None)
                if alias is None:
                    return self.todo_expr(col, s + "（关联键无法推断）")
                base = f"{alias}.{f}"
            expr = base
            note = rest
            mm = re.search(r"[×*]\s*(\w+)\.(\w+)", rest)
            if mm and mm.group(1) in self.S:
                a2 = ctx["alias"](mm.group(1), None) if mm.group(1) != ctx["main"] else ctx["main_alias"]
                expr = f"{base} * {a2}.{mm.group(2)}"
            mm = re.search(r"([+\-÷/])\s*(\w+)\.(\w+)", rest)
            if mm and mm.group(2) in self.S and mm.group(1) in "+-÷/":
                a2 = ctx["alias"](mm.group(2), None) if mm.group(2) != ctx["main"] else ctx["main_alias"]
                op = "/" if mm.group(1) in "÷/" else mm.group(1)
                expr = f"({expr} {op} {'NULLIF(' + a2 + '.' + mm.group(3) + ', 0)' if op == '/' else a2 + '.' + mm.group(3)})"
            if "÷100" in rest:
                expr = f"CAST({expr} / 100 AS DECIMAL(18,2))"
            if "取日期" in rest:
                fmt = "yyyyMMdd" if (name == "travel_date" or "YYYYMMDD" in col["c"]) else "yyyy-MM-dd"
                expr = f"DATE_FORMAT({expr}, '{fmt}')"
            elif "取小时" in rest:
                expr = f"HOUR({expr})"
            em = re.search(r"展开\s*(\w+)", rest)
            if em:
                key = em.group(1)
                expr = (f"JSON_VALUE({base}, '$.{key}')" if rt else f"GET_JSON_OBJECT({base}, '$.{key}')")
                if "计数" in rest:
                    expr = (f"CARDINALITY(JSON_QUERY({base}, '$.{key}' RETURNING ARRAY<STRING>))" if rt
                            else f"SIZE(FROM_JSON(GET_JSON_OBJECT({base}, '$.{key}'), 'array<string>'))")
            if "脱敏" in rest:
                expr = self.mask(name, base)
            if "截取后 4 位" in rest:
                expr = f"SUBSTR({base}, -4)"
            if re.search(r"变为|镜像|前后差|递归|相邻|聚合|映射|判定|昨日快照|今日快照|计算|或", rest) and "÷100" not in rest:
                self.todo += 1
                return f"{expr}", "TODO 口径：" + s
            return expr, (note if note not in ("，改名", "改名", "冗余") else "")
        # 本表字段运算
        m = re.match(r"^(\w+)\s+与\s+(\w+)\s+相减$", s)
        if m and m.group(1) in ctx["local"] and m.group(2) in ctx["local"]:
            a, b = ctx["local"][m.group(1)], ctx["local"][m.group(2)]
            return self.diff(name, a, b, rt), s
        m = re.match(r"^(\w+)\s*-\s*(\w+)$", s)
        if m and m.group(1) in ctx["local"] and m.group(2) in ctx["local"]:
            a, b = ctx["local"][m.group(1)], ctx["local"][m.group(2)]
            return self.diff(name, a, b, rt), s
        m = re.match(r"^(\w+)\s+取小时$", s)
        if m and m.group(1) in ctx["local"]:
            return f"HOUR({ctx['local'][m.group(1)]})", s
        if col["k"] == "分区":
            return "DATE_FORMAT(m.create_time, 'yyyyMMdd')", s
        return self.todo_expr(col, s or "未提供")

    @staticmethod
    def diff(name, a, b, rt):
        if name.endswith("_day_qty"):
            return f"TIMESTAMPDIFF(DAY, CAST({b} AS TIMESTAMP), CAST({a} AS TIMESTAMP))" if rt else f"DATEDIFF({a}, {b})"
        unit = 60 if "minute" in name else 3600 if "hour" in name else 1
        if rt:
            u = {60: "MINUTE", 3600: "HOUR", 1: "SECOND"}[unit]
            return f"TIMESTAMPDIFF({u}, CAST({b} AS TIMESTAMP), CAST({a} AS TIMESTAMP))"
        return f"(UNIX_TIMESTAMP({a}) - UNIX_TIMESTAMP({b})) / {unit}" if unit > 1 else f"({a} - {b})"

    @staticmethod
    def mask(name, base):
        if "phone" in name or "mobile" in name:
            return f"CONCAT(SUBSTR({base}, 1, 3), '****', SUBSTR({base}, -4))"
        if "id_card" in name or "cert" in name or "card_no" in name:
            return f"CONCAT(SUBSTR({base}, 1, 6), '********', SUBSTR({base}, -4))"
        if "name" in name:
            return f"CONCAT(SUBSTR({base}, 1, 1), '**')"
        return f"SHA2({base}, 256)"

    # ---------- 关联键推断 ----------
    def join_on(self, main, ma, other, oa, hint):
        mc, oc = set(self.cols(main)), set(self.cols(other))
        conds = []
        if hint:
            for part in hint.split("+"):
                if "=" in part:
                    l, r = part.split("=", 1)
                    conds.append(f"{ma}.{l} = {oa}.{r}")
                    continue
                k = part
                if k in mc and k in oc:
                    conds.append(f"{ma}.{k} = {oa}.{k}")
                elif k in mc:
                    p = self.pk(other)
                    if not p:
                        return None
                    conds.append(f"{ma}.{k} = {oa}.{p}")
                elif k in oc:
                    cand = [c for c in mc if c.endswith(k) or k.endswith(c) and c not in GENERIC_KEYS]
                    if not cand:
                        return None
                    conds.append(f"{ma}.{cand[0]} = {oa}.{k}")
                else:
                    return None
            return " AND ".join(conds)
        common = [c for c in mc & oc if c not in GENERIC_KEYS]
        for suf in ("_no", "_id", "_code"):
            cs = sorted(c for c in common if c.endswith(suf))
            if cs:
                return f"{ma}.{cs[0]} = {oa}.{cs[0]}"
        mp, me = self.pk(main), entity(main)
        mw = me.split("_")
        for i in range(len(mw)):
            k = "_".join(mw[i:]) + "_id"
            if k in oc and mp:
                return f"{ma}.{mp} = {oa}.{k}"
        ent = entity(other)
        p = self.pk(other)
        words = ent.split("_")
        for i in range(len(words)):
            k = "_".join(words[i:]) + "_id"
            if k in mc and p:
                return f"{ma}.{k} = {oa}.{p}"
            k2 = "_".join(words[i:]) + "_no"
            if k2 in mc and k2 in oc:
                return f"{ma}.{k2} = {oa}.{k2}"
        return None

    def part_filter(self, t, a, rt_ctx):
        if rt_ctx:
            return None
        sfx = suffix(t)
        if sfx == "f":
            return None
        if sfx == "zip":
            return f"{a}.travel_date = '${{bizdate}}' AND {a}.end_date = '9999-12-31'"
        return f"{a}.travel_date = '${{bizdate}}'"

    # ---------- 选择列表构建（DIM/DWD 与实时 DWD） ----------
    def select_body(self, t, rt):
        cols = self.S[t]["cols"]
        cnt = {}
        for c in cols:
            for r in c["r"]:
                if r[0] != t and r[0] in self.S:
                    cnt[r[0]] = cnt.get(r[0], 0) + 1
        ups = [u for u in self.T.get(t, {}).get("up", []) if u in self.S]
        main = max(cnt, key=lambda k: (cnt[k], k.startswith("ods"), -ups.index(k) if k in ups else -99)) if cnt else (ups[0] if ups else None)
        joins = OrderedDict()   # table -> (alias, on, kind)
        ctes = OrderedDict()
        dims_n, oth_n = [0], [0]

        def alias(src, hint, filt=None):
            if src == main and not filt:
                return "m"
            key = src + ("|%s=%s" % filt if filt else "")
            if key in joins:
                return joins[key][0]
            if src.startswith("dim_"):
                dims_n[0] += 1
                a = f"d{dims_n[0]}"
            else:
                oth_n[0] += 1
                a = f"o{oth_n[0]}"
            on = self.join_on(main, "m", src, a, hint)
            if on is None:     # 主表上没有关联键：尝试经已关联的表链式关联
                for k2, (a2, _) in list(joins.items()):
                    t2 = k2.split("|")[0]
                    if t2.startswith("__") or t2 == src:
                        continue
                    on = self.join_on(t2, a2, src, a, hint)
                    if on:
                        break
            if on is None:
                on = "1 = 0 /* TODO 关联键 */"
                self.todo += 1
            if filt:
                on += f" AND {a}.{filt[0]} = '{filt[1]}'"
            joins[key] = (a, on)
            return a

        def agg(src, f, key, fn):
            a = f"a{len(ctes) + 1}"
            mc = self.cols(main)
            if key not in mc or key not in self.cols(src):
                return None
            filt = self.part_filter(src, "x", rt)
            ctes[a] = (f"SELECT {key}, {fn}({f}) AS {f}_{fn.lower()}\n    FROM {self.fq(src, rt)} x" +
                       (f"\n    WHERE {filt}" if filt else "") + f"\n    GROUP BY {key}")
            joins["__" + a] = (a, f"m.{key} = {a}.{key}")
            return f"COALESCE({a}.{f}_{fn.lower()}, 0)"

        local = {}
        ctx = dict(main=main, main_alias="m", alias=alias, agg=agg, rt=rt, self=t, local=local)
        rows = []
        zip_cols = []
        for c in cols:
            if not rt and c["n"] == "travel_date":
                continue
            expr, note = self.translate(c, ctx)
            if expr is None:
                zip_cols.append(c["n"])
                continue
            local[c["n"]] = expr
            rows.append((f"{expr} AS {c['n']}", note or c["c"][:28]))
        return main, joins, ctes, rows, zip_cols

    def from_clause(self, main, joins, rt):
        out = [f"FROM {self.fq(main, rt)} m"]
        for key, (a, on) in joins.items():
            src = key.split("|")[0]
            if src.startswith("__"):
                out.append(f"LEFT JOIN {a} ON {on}")
                continue
            if rt and not src.endswith("_rt"):
                out.append(f"LEFT JOIN {self.fq(src, True)} /*+ OPTIONS('lookup.join.cache.ttl'='1 h') */\n"
                           f"    FOR SYSTEM_TIME AS OF m.proc_time AS {a}\n    ON {on}")
            else:
                f = self.part_filter(src, a, rt)
                out.append(f"LEFT JOIN {self.fq(src, rt)} {a}\n    ON {on}" + (f"\n   AND {f}" if f else ""))
        return "\n".join(out)

    # ---------- 各层 ----------
    def ods(self, t):
        info = self.T[t]
        src = info.get("src", "")
        dbn, _, tbl = src.partition(".")
        cols = self.S[t]["cols"]
        srccols = []
        rows = []
        for c in cols:
            m = re.match(r"^[\w-]+\.\w+\.(\w+)(.*)$", c["s"])
            if m:
                f, rest = m.group(1), m.group(2)
                srccols.append(f)
                e = self.mask(c["n"], f) if "脱敏" in rest else (f"SUBSTR({f}, -4)" if "截取后 4 位" in rest else f)
                rows.append((f"{e} AS {c['n']}" if e != c["n"] else c["n"], c["c"][:30]))
            elif c["n"] == "binlog_op_type":
                rows.append(("'SNAPSHOT' AS binlog_op_type", "JDBC 批量抽取无 binlog，固定 SNAPSHOT"))
            elif c["n"] == "binlog_time":
                rows.append(("CAST(NULL AS STRING) AS binlog_time", "JDBC 批量抽取无 binlog 时间"))
            elif c["k"] == "ETL":
                rows.append((f"{ETL_EXPR} AS {c['n']}", "ETL 加载时间"))
            else:
                rows.append(self.todo_expr(c, c["s"]))
                rows[-1] = (rows[-1][0] + f" AS {c['n']}", rows[-1][1])
        inc = suffix(t) == "di"
        tcol = "update_time" if "update_time" in srccols else "create_time"
        where = (f" WHERE {tcol} >= ''${{bizdate_begin}}'' AND {tcol} < ''${{bizdate_end}}''" if inc else "")
        view = "src_" + tbl
        body = (f"CREATE OR REPLACE TEMPORARY VIEW {view}\nUSING org.apache.spark.sql.jdbc\nOPTIONS (\n"
                f"    url       '${{jdbc.{dbn}.url}}',\n"
                f"    dbtable   '(SELECT * FROM `{tbl}`{where}) t',\n"
                f"    user      '${{jdbc.{dbn}.user}}',\n    password  '${{jdbc.{dbn}.password}}',\n"
                f"    fetchsize '10000'\n);\n\n"
                f"INSERT OVERWRITE TABLE {self.fq(t)} PARTITION (travel_date = '${{bizdate}}')\nSELECT\n{pad(rows)}\nFROM {view};\n")
        mode = "增量：按 %s 抽取当日变更" % tcol if inc else "全量：每日快照"
        return self.header(t, "Spark SQL → Hive(ORC)", [f"-- 来源：{src}（{mode}）",
                                                         "-- 参数：${bizdate}=YYYYMMDD；${bizdate_begin}/${bizdate_end}=当日 00:00:00 / 次日 00:00:00"]) + "\n" + body

    def dim_dwd(self, t):
        rt = False
        main, joins, ctes, rows, zip_cols = self.select_body(t, rt)
        if not main:
            return self.header(t, "Spark SQL → Hive(ORC)") + "\n-- TODO：未找到来源表\n"
        where = [f for f in [self.part_filter(main, "m", rt)] if f]
        if "deleted" in self.cols(main):
            where.append("m.deleted = 0")
        cte = ""
        if ctes:
            cte = "WITH " + ",\n".join(f"{a} AS (\n    {sql}\n)" for a, sql in ctes.items()) + "\n"
        select = f"SELECT\n{pad(rows)}\n{self.from_clause(main, joins, rt)}" + (f"\nWHERE " + "\n  AND ".join(where) if where else "")
        tgt = self.fq(t)
        part = "" if suffix(t) == "f" else " PARTITION (travel_date = '${bizdate}')"
        if suffix(t) == "zip":
            pk = self.pk(t)
            cols = [c["n"] for c in self.S[t]["cols"] if c["n"] not in ("start_date", "end_date", "etl_time", "travel_date")]
            if "update_time" in self.cols(main):
                select += f"\n  AND m.update_time >= '${{bizdate_begin}}'   -- 只取当日新增或变更的记录"
            today = ("today AS (\n" + select.replace("\n", "\n    ").replace("SELECT", "    SELECT", 1) + "\n),\n")
            body = ((cte.rstrip("\n") + ",\n" if cte else "WITH ") + today +
                    f"prev AS (\n    SELECT * FROM {tgt} WHERE travel_date = '${{bizdate_prev}}'\n)\n"
                    f"INSERT OVERWRITE TABLE {tgt}{part}\n"
                    f"-- ① 历史链：当日有变化的有效记录闭链\nSELECT\n" +
                    pad([(f"p.{c}", "") for c in cols] + [("p.start_date", ""),
                        ("CASE WHEN t.%s IS NOT NULL AND p.end_date = '9999-12-31' THEN '${bizdate_prev_dash}' ELSE p.end_date END AS end_date" % pk, "变化则闭链"),
                        (f"{ETL_EXPR} AS etl_time", "")]) +
                    f"\nFROM prev p\nLEFT JOIN today t ON p.{pk} = t.{pk}\nUNION ALL\n"
                    f"-- ② 新链：当日新增或变化的记录开链\nSELECT\n" +
                    pad([(f"t.{c}", "") for c in cols] + [("'${bizdate_dash}' AS start_date", ""), ("'9999-12-31' AS end_date", ""),
                                                         (f"{ETL_EXPR} AS etl_time", "")]) + "\nFROM today t;\n")
            return self.header(t, "Spark SQL → Hive(ORC) · 拉链表",
                               ["-- 拉链：start_date/end_date，9999-12-31 为当前有效；${bizdate_prev} 为前一日分区"]) + "\n" + body
        body = cte + f"INSERT OVERWRITE TABLE {tgt}{part}\n" + select + ";\n"
        return self.header(t, "Spark SQL → Hive(ORC)") + "\n" + body

    def sink_ddl(self, t):
        ddl = self.S[t]["ddl"]
        pk = re.search(r"PRIMARY KEY \(([^)]*)\)", ddl)
        pkc = pk.group(1).replace("`", "") if pk else ""
        rows = [(f"`{c['n']}` {self.ftype(c['t'])}", "") for c in self.S[t]["cols"]]
        if pkc:
            rows.append((f"PRIMARY KEY ({pkc}) NOT ENFORCED", ""))
        return (f"CREATE TEMPORARY TABLE sink_{t} (\n{pad(rows)}\n) WITH (\n"
                f"    'connector' = 'starrocks',\n    'jdbc-url' = '${{starrocks.jdbc_url}}',\n    'load-url' = '${{starrocks.load_url}}',\n"
                f"    'database-name' = '{db_of(t)}',\n    'table-name' = '{t}',\n"
                f"    'username' = '${{starrocks.user}}',\n    'password' = '${{starrocks.password}}',\n"
                f"    'sink.properties.format' = 'json',\n    'sink.properties.strip_outer_array' = 'true',\n"
                f"    'sink.buffer-flush.interval-ms' = '5000'\n);\n")

    def dwd_rt(self, t):
        main, joins, ctes, rows, _ = self.select_body(t, True)
        where = ["m.deleted = 0"] if "deleted" in self.cols(main) else []
        view = (f"CREATE TEMPORARY VIEW v_{t} AS\nSELECT\n{pad(rows)}\n{self.from_clause(main, joins, True)}" +
                (f"\nWHERE " + "\n  AND ".join(where) if where else "") + ";\n")
        return (self.header(t, "Flink SQL → StarRocks 主键模型",
                            ["-- 来源：同作业内 Flink CDC 源表（见 ODS 实时任务），维度按主键 lookup 离线 Hive 维表"]) +
                "\n" + self.sink_ddl(t) + "\n" + view + f"\nINSERT INTO sink_{t} SELECT * FROM v_{t};\n")

    # ---------- 汇总层 ----------
    def parse_metric(self, s, srccols):
        """'dwd_x：count(distinct a) where cond（注）' -> (src, sql, note) ；无法解析返回 (src, None, s)"""
        notes = re.findall(r"（([^（）]*)）", s)
        s2 = re.sub(r"（[^（）]*）", "", s).strip()
        m = re.match(r"^(\w+)\.(\w+)\s*汇总", s2)
        if m and m.group(1) in self.S:
            return m.group(1), f"SUM({m.group(2)})", "；".join(notes)
        m = re.match(r"^(\w+)[：:]\s*(.+)$", s2)
        if not m or m.group(1) not in self.S:
            return None, None, s
        src, f = m.group(1), m.group(2).strip()
        cols = set(self.cols(src))
        parts = re.split(r"\s+where\s+", f, flags=re.I)
        aggp, cond = parts[0], (parts[1] if len(parts) > 1 else None)

        def col(tok):
            for c in (tok, tok.replace("amount", "amt"), tok + "_amt", tok + "_qty", tok.replace("_count", "_qty")):
                if c in cols:
                    return c
            return None

        am = re.match(r"^(count|sum|max|min|avg)\s*\(\s*(distinct\s+)?([\w.]+)\s*\)\s*(.*)$", aggp, re.I)
        if am:
            fn, dist, arg, tail = am.group(1).upper(), bool(am.group(2)), am.group(3), am.group(4).strip()
            c = col(arg)
            if not c:
                return src, None, s
            if tail == "/100" and c.endswith("_amt"):
                tail = ""
            if tail and not re.fullmatch(r"[/*]\s*\d+", tail):
                return src, None, s
            cs = None
            if cond:
                cs = self.cond(cond, src)
                if cs is None:
                    return src, None, s
            if cs:
                inner = f"CASE WHEN {cs} THEN {c} END"
            else:
                inner = c
            sql = f"{fn}({'DISTINCT ' if dist else ''}{inner})" + (f" {tail}" if tail else "")
            return src, sql, "；".join(notes)
        em = re.match(r"^(\w+)\s*(/100)?$", aggp)
        if em and col(em.group(1)) and not cond:
            c = col(em.group(1))
            tail = "" if c.endswith("_amt") else (" / 100" if em.group(2) else "")
            return src, f"SUM({c}{tail})", "；".join(notes)
        return src, None, s

    def cond(self, cond, src):
        cond = cond.strip()
        if re.search(r"[一-鿿]", cond):
            return None
        if re.search(r"[=<>]|\bin\b|\bis\b|\blike\b", cond, re.I):
            bare = re.sub(r"'[^']*'", "", cond)
            idents = {w for w in re.findall(r"\b[a-z_][a-z0-9_]*\b", bare)} - {"and", "or", "not", "in", "is", "null", "like", "between"}
            if idents - set(self.cols(src)):
                return None
            return cond
        words = re.findall(r"[A-Z][A-Z_]+", cond)
        if words and re.fullmatch(r"[A-Z_ ,/]+", cond):
            cols = self.S[src]["cols"]
            outs = []
            for w in words:
                hit = [c["n"] for c in cols if c["k"] == "状态类型" and w in c["c"]]
                if not hit:
                    return None
                outs.append(f"{hit[0]} = '{w}'")
            return " OR ".join(outs) if len(outs) > 1 else outs[0]
        return None

    def src_filter(self, t, src, rt):
        if rt:
            return "travel_date = DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')" if src.endswith("_rt") else None
        if suffix(src) == "f":
            return None
        if suffix(t) == "df" and suffix(src) in ("di", "hrs"):
            return "travel_date <= '${bizdate}'"
        if suffix(src) == "zip":
            return "travel_date = '${bizdate}' AND end_date = '9999-12-31'"
        return "travel_date = '${bizdate}'"

    def dim_attr_joins(self, t, cols, grain, rt, alias_base="a"):
        """维度属性：X.f 按 key 关联 -> LEFT JOIN 维表"""
        joins = OrderedDict()
        rows = {}
        for c in cols:
            m = re.match(r"^(dim_\w+)\.(\w+)(.*)$", c["s"])
            if not m or m.group(1) not in self.S:
                continue
            d, f, rest = m.groups()
            if d not in joins:
                hm = re.search(r"按\s*(\w+)", rest)
                key = hm.group(1) if hm else None
                if not key:
                    cand = [g for g in grain if g in self.cols(d) and g not in GENERIC_KEYS]
                    key = cand[0] if cand else None
                if key and key in grain:
                    right = key if key in self.cols(d) else self.pk(d)
                    joins[d] = (f"j{len(joins) + 1}", f"{alias_base}.{key} = j{len(joins) + 1}.{right}")
                else:
                    joins[d] = (f"j{len(joins) + 1}", None)
            a, on = joins[d]
            rows[c["n"]] = f"{a}.{f}" if on else None
        out = []
        for d, (a, on) in joins.items():
            if not on:
                continue
            if rt:
                out.append(f"LEFT JOIN {self.fq(d, True)} {a} ON {on}")
            else:
                f = self.part_filter(d, a, rt)
                out.append(f"LEFT JOIN {self.fq(d)} {a}\n    ON {on}" + (f"\n   AND {f}" if f else ""))
        return rows, out

    def dws(self, t):
        rt = self.rt(t)
        cols = self.S[t]["cols"]
        grain = [c for c in cols if c["k"] == "粒度键" and c["n"] != "travel_date"]
        gnames = [c["n"] for c in grain]
        metrics = OrderedDict()   # src -> [(col, sql, note)]
        finals = []               # (col, expr, note) 在汇总结果上计算
        for c in cols:
            if c["k"] not in ("指标", "度量"):
                continue
            src, sql, note = self.parse_metric(c["s"], None)
            if src and sql:
                metrics.setdefault(src, []).append((c, sql, note))
            else:
                finals.append(c)
        if not metrics:
            for c in grain:
                for r in c["r"]:
                    if r[0] in self.S and r[0] != t:
                        metrics.setdefault(r[0], [])
                        break
        mnames = [c["n"] for v in metrics.values() for c, _, _ in v]
        ctes = []
        for i, (src, ms) in enumerate(metrics.items(), 1):
            sc = set(self.cols(src))
            keys = []
            for g in grain:
                f = next((r[1] for r in g["r"] if r[0] == src), None)
                if f is None and g["n"] in sc:
                    f = g["n"]
                if f is None:
                    m = re.match(r"^(\w+)\.(\w+)", g["s"])
                    f = None
                keys.append((f"{f} AS {g['n']}" if f and f != g["n"] else (g["n"] if f else f"CAST(NULL AS {self.ftype(g['t'])}) AS {g['n']}"), f))
            if rt:   # 实时窗口粒度：按事件时间取整到分钟作为窗口键（分组聚合 + 主键模型 upsert）
                ts = "CAST(event_time AS TIMESTAMP(3))" if "event_time" in sc else "CAST(update_time AS TIMESTAMP(3))"
                fl = f"FLOOR({ts} TO MINUTE)"
                for i2, (k, f) in enumerate(keys):
                    if k.endswith(" AS window_start_time") or k == "window_start_time":
                        keys[i2] = (f"DATE_FORMAT({fl}, 'yyyy-MM-dd HH:mm:ss') AS window_start_time", fl)
                    elif k.endswith(" AS window_end_time") or k == "window_end_time":
                        keys[i2] = (f"DATE_FORMAT(TIMESTAMPADD(MINUTE, 1, {fl}), 'yyyy-MM-dd HH:mm:ss') AS window_end_time", fl)
            sel = [(k, "1 分钟窗口" if "FLOOR(" in k else "") for k, _ in keys]
            for n in mnames:
                hit = next(((sql, note) for c, sql, note in ms if c["n"] == n), None)
                if hit:
                    sel.append((f"{hit[0]} AS {n}", hit[1][:40]))
                else:
                    sel.append((f"CAST(NULL AS {self.ftype(next(c['t'] for c in cols if c['n'] == n))}) AS {n}", ""))
            filt = self.src_filter(t, src, rt)
            gb = [k for k, f in keys if f]
            gbx = [re.sub(r"\s+AS\s+\w+$", "", k) for k in gb]
            ctes.append((f"s{i}", src, sel, filt, gbx))
        # 汇总
        name = lambda a: (f"v_{t}__{a}" if rt else a)
        parts = []
        for a, src, sel, filt, gbx in ctes:
            parts.append(f"{name(a)} AS (\n    -- 来源：{src}\n    SELECT\n" + pad(sel).replace("\n    ", "\n        ").replace("    ", "        ", 1) +
                         f"\n    FROM {self.fq(src, rt)}" + (f"\n    WHERE {filt}" if filt else "") +
                         (f"\n    GROUP BY {', '.join(gbx)}" if gbx else "") + "\n)")
        union = "\n    UNION ALL\n".join(f"    SELECT * FROM {name(a)}" for a, *_ in ctes)
        agg_rows = [(g, "") for g in gnames] + [(f"SUM({n}) AS {n}", "") for n in mnames]
        agg = (f"{name('agg')} AS (\n    SELECT\n" + pad(agg_rows).replace("\n    ", "\n        ").replace("    ", "        ", 1) +
               f"\n    FROM (\n{union}\n    ) u" + (f"\n    GROUP BY {', '.join(gnames)}" if gnames else "") + "\n)")
        dim_rows, dim_joins = self.dim_attr_joins(t, cols, gnames, rt)
        local = {n: f"a.{n}" for n in gnames + mnames}
        out_rows = []
        for c in cols:
            n = c["n"]
            if n == "travel_date":
                if rt:
                    out_rows.append(("DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd') AS travel_date", "实时：当日"))
                continue
            if n in local:
                out_rows.append((f"{local[n]} AS {n}", c["c"][:30]))
            elif c["k"] == "ETL":
                out_rows.append((f"{ETL_EXPR} AS {n}", "ETL 加载时间"))
            elif dim_rows.get(n):
                out_rows.append((f"{dim_rows[n]} AS {n}", c["s"][:40]))
            else:
                e = re.sub(r"\b(" + "|".join(map(re.escape, gnames + mnames)) + r")\b", r"a.\1", c["s"]) if (gnames + mnames) else c["s"]
                if re.match(r"^\s*case when .+ end\s*$", c["s"], re.I):
                    out_rows.append((f"{e} AS {n}", "派生"))
                else:
                    ex, note = self.todo_expr(c, c["s"])
                    out_rows.append((f"{ex} AS {n}", note))
        sel = f"SELECT\n{pad(out_rows)}\nFROM {name('agg')} a" + ("\n" + "\n".join(dim_joins) if dim_joins else "")
        if rt:
            body = "\n\n".join("CREATE TEMPORARY VIEW " + p.replace(" AS (\n", " AS\n", 1).rstrip(")").rstrip() + ";" for p in parts + [agg])
            body += f"\n\nCREATE TEMPORARY VIEW v_{t} AS\n{sel};\n\nINSERT INTO sink_{t} SELECT * FROM v_{t};\n"
            return (self.header(t, "Flink SQL → StarRocks 主键模型", ["-- 流式分组聚合（retract → upsert），按 travel_date 当日累计"]) +
                    "\n" + self.sink_ddl(t) + "\n" + body)
        part = " PARTITION (travel_date = '${bizdate}')"
        body = "WITH " + ",\n".join(parts + [agg]) + f"\nINSERT OVERWRITE TABLE {self.fq(t)}{part}\n{sel};\n"
        return self.header(t, "Spark SQL → Hive(ORC)") + "\n" + body

    def ads(self, t):
        rt = self.rt(t)
        cols = self.S[t]["cols"]
        grain = [c for c in cols if c["k"] == "粒度键" and c["n"] != "travel_date"]
        gnames = [c["n"] for c in grain]
        bases = OrderedDict()   # (src, field, window) -> base name
        finals = OrderedDict()  # col -> (expr template with {b}, note)
        sfx = suffix(t)
        default_w = {"wk": "1w", "mo": "1m", "rt": "today", "hrs": "1d"}.get(sfx, "1d")

        def base(src, f, w):
            k = (src, f, w)
            if k not in bases:
                bases[k] = f"b{len(bases) + 1}"
            return bases[k]

        for c in cols:
            if c["k"] not in ("指标", "度量"):
                continue
            refs = []
            for r in c["r"]:
                if r[0] in self.S and r[1] and tuple(r) not in refs:
                    refs.append(tuple(r))
            w = window_of(c["n"]) or default_w
            s = c["s"]
            dec = re.search(r"保留\s*(\d)\s*位", s)
            nd = int(dec.group(1)) if dec else (6 if "rate" in c["n"] else 2)
            note = ""
            if w not in ("1d", "td", "today") and re.search(r"(buyer|customer|tenant|distributor|staff|tourist|user|point)_?\w*_qty$", refs[0][1] if refs else ""):
                note = "TODO 口径：去重人数跨天不可加，需回溯 DWD 明细去重"
                self.todo += 1
            if len(refs) == 1:
                b = base(refs[0][0], refs[0][1], w)
                finals[c["n"]] = (f"x.{b}", note or s[:40])
            elif len(refs) == 2:
                b1, b2 = base(refs[0][0], refs[0][1], w), base(refs[1][0], refs[1][1], w)
                rhs = s.split("=", 1)[1] if "=" in s else s
                if "*100" in rhs or "×100" in rhs:
                    e = f"ROUND(x.{b1} * 100 / NULLIF(x.{b2}, 0), {nd})"
                elif re.search(r"[)）\w]\s*-\s*", rhs) and "/" not in rhs:
                    e = f"ROUND(COALESCE(x.{b1}, 0) - COALESCE(x.{b2}, 0), {nd})"
                elif "/" in rhs or "÷" in rhs or "rate" in c["n"] or "avg" in c["n"]:
                    e = f"ROUND(x.{b1} / NULLIF(x.{b2}, 0), {nd})"
                else:
                    e = f"COALESCE(x.{b1}, 0) + COALESCE(x.{b2}, 0)"
                finals[c["n"]] = (e, note or s[:40])
            else:
                finals[c["n"]] = None
        # 同一来源字段 × 周期被多个指标共用 -> 这些指标还有业务条件（如发起方、渠道），DWS 粒度不足以区分
        users = {}
        for n, v in finals.items():
            if v and re.fullmatch(r"x\.b\d+", v[0]):
                users.setdefault(v[0], []).append(n)
        for b, ns in users.items():
            if len(ns) > 1:
                for n in ns:
                    c = next(c for c in cols if c["n"] == n)
                    conds = [x for x in re.split(r"[；;]", c["s"].split("条件：", 1)[-1]) if x and not re.search(
                        r"时间在|日期在|统计日|今日|本月|本年|当天|当日|截至|日终|保留|小时", x)] if "条件：" in c["s"] else []
                    self.todo += 1
                    finals[n] = (f"CAST(NULL AS {self.ftype(c['t'])})",
                                 "TODO 口径：需按条件拆分（" + "；".join(conds)[:40] + "），DWS 需带该维度或改读 DWD")
        # 来源 CTE：每个来源表一个，按粒度开窗求和
        by_src = OrderedDict()
        for (src, f, w), b in bases.items():
            by_src.setdefault(src, []).append((f, w, b))
        wexpr = self.window_cond(rt)
        ctes = []
        for i, (src, items) in enumerate(by_src.items(), 1):
            keys = []
            for g in grain:
                f = next((r[1] for r in g["r"] if r[0] == src), None)
                if f is None and g["n"] in self.cols(src):
                    f = g["n"]
                keys.append((f, g))
            sel = [((f"{f} AS {g['n']}" if f != g["n"] else f) if f else f"CAST(NULL AS {self.ftype(g['t'])}) AS {g['n']}", "") for f, g in keys]
            for (s2, f, w), b in bases.items():
                if s2 == src:
                    if w == "td":
                        sel.append((f"SUM(CASE WHEN travel_date = {wexpr('1d')} THEN {f} END) AS {b}", f"{f} · 日终值"))
                    else:
                        sel.append((f"SUM(CASE WHEN travel_date >= {wexpr(w)} THEN {f} END) AS {b}", f"{f} · {w}"))
                else:
                    sel.append((f"CAST(NULL AS DECIMAL(20,6)) AS {b}", ""))
            ws = [w for (_, _, w), _ in [(k, v) for k, v in bases.items() if k[0] == src]]
            lo = self.lookback(ws, rt)
            filt = (f"travel_date >= {lo} AND travel_date <= {wexpr('1d')}" if lo else f"travel_date = {wexpr('1d')}")
            gb = [f for f, g in keys if f]
            ctes.append((f"s{i}", src, sel, filt, gb))
        name = lambda a: (f"v_{t}__{a}" if rt else a)
        parts = [f"{name(a)} AS (\n    -- 来源：{src}\n    SELECT\n" + pad(sel).replace("\n    ", "\n        ").replace("    ", "        ", 1) +
                 f"\n    FROM {self.fq(src, rt)}\n    WHERE {filt}" + (f"\n    GROUP BY {', '.join(gb)}" if gb else "") + "\n)"
                 for a, src, sel, filt, gb in ctes]
        if not ctes:
            return self.header(t, "Spark SQL") + "\n-- TODO：未解析到来源指标\n"
        union = "\n    UNION ALL\n".join(f"    SELECT * FROM {name(a)}" for a, *_ in ctes)
        agg_rows = [(g, "") for g in gnames] + [(f"SUM({b}) AS {b}", "") for b in bases.values()]
        agg = (f"{name('agg')} AS (\n    SELECT\n" + pad(agg_rows).replace("\n    ", "\n        ").replace("    ", "        ", 1) +
               f"\n    FROM (\n{union}\n    ) u" + (f"\n    GROUP BY {', '.join(gnames)}" if gnames else "") + "\n)")
        dim_rows, dim_joins = self.dim_attr_joins(t, cols, gnames, rt, "x")
        out = []
        for c in cols:
            n = c["n"]
            if n == "travel_date":
                if rt:
                    out.append(("DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd') AS travel_date", "实时：当日"))
                continue
            if n in gnames:
                out.append((f"x.{n}", c["c"][:30]))
            elif n in finals and finals[n]:
                out.append((f"{finals[n][0]} AS {n}", finals[n][1]))
            elif c["k"] == "ETL":
                out.append((f"{ETL_EXPR} AS {n}", "ETL 加载时间"))
            elif dim_rows.get(n):
                out.append((f"{dim_rows[n]} AS {n}", c["s"][:40]))
            else:
                ex, note = self.todo_expr(c, c["s"])
                out.append((f"{ex} AS {n}", note))
        sel = f"SELECT\n{pad(out)}\nFROM {name('agg')} x" + ("\n" + "\n".join(dim_joins) if dim_joins else "")
        extra = ["-- 统计周期：字段名中的 1d/7d/30d/mtd/ytd/td 等，对 DWS 日分区开窗求和后组合为派生指标"]
        if rt:
            body = "\n\n".join("CREATE TEMPORARY VIEW " + p.replace(" AS (\n", " AS\n", 1).rstrip(")").rstrip() + ";" for p in parts + [agg])
            body += f"\n\nCREATE TEMPORARY VIEW v_{t} AS\n{sel};\n\nINSERT INTO sink_{t} SELECT * FROM v_{t};\n"
            return self.header(t, "Flink SQL → StarRocks 主键模型", extra) + "\n" + self.sink_ddl(t) + "\n" + body
        body = "WITH " + ",\n".join(parts + [agg]) + f"\nINSERT OVERWRITE TABLE {self.fq(t)} PARTITION (travel_date = '${{bizdate}}')\n{sel};\n"
        return self.header(t, "Spark SQL → Hive(ORC)", extra) + "\n" + body

    @staticmethod
    def window_cond(rt):
        def f(w):
            if rt or w == "today":
                return "DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyyMMdd')"
            d = "TO_DATE('${bizdate}', 'yyyyMMdd')"
            if w in ("1d", "td"):
                return "'${bizdate}'"
            if w == "mtd" or w == "1m":
                return "CONCAT(SUBSTR('${bizdate}', 1, 6), '01')"
            if w == "ytd":
                return "CONCAT(SUBSTR('${bizdate}', 1, 4), '0101')"
            n = 7 if w == "1w" else int(w[:-1])
            return f"DATE_FORMAT(DATE_SUB({d}, {n - 1}), 'yyyyMMdd')"
        return f

    def lookback(self, ws, rt):
        if rt:
            return None
        f = self.window_cond(False)
        ws = [w for w in ws if w not in ("1d", "td", "today")]
        if not ws:
            return None
        if "ytd" in ws:
            return f("ytd")
        exprs = sorted({f(w) for w in ws})
        return exprs[0] if len(exprs) == 1 else "LEAST(" + ", ".join(exprs) + ")"

    # ---------- 质检 / 控制节点 ----------
    def dq(self, node):
        strong = sum(1 for r in node["rules"] if r["level"] == "强")
        weak = len(node["rules"]) - strong
        kind = "对账" if node["kind"] == "recon" else ("监控" if node.get("monitor") else "质检")
        lines = ["-- " + "=" * 74, f"-- {kind}：{node['cn']}",
                 f"-- 对象：{node.get('table', '')}    规则 {len(node['rules'])} 条（强 {strong}：失败阻断下游；弱 {weak}：只告警）"]
        if node.get("desc"):
            lines.append("-- 说明：" + node["desc"])
        lines += ["-- 执行：逐条运行，结果与“期望”比对；任一强规则不满足则本节点失败", "-- " + "=" * 74, ""]
        for r in node["rules"]:
            lines.append(f"-- [{r['id']}] {r['code']} · {r['level']} · {r['name']}")
            lines.append(f"-- 期望：{r['expect']}")
            if r.get("desc"):
                lines.append(f"-- 说明：{r['desc']}")
            lines.append(r["sql"].rstrip())
            lines.append("")
        return "\n".join(lines)

    def control(self, node, flow):
        cn, desc = node["cn"], node.get("desc", "")
        if node["kind"] == "start":
            body = ("set -euo pipefail\nBIZDATE=\"${bizdate}\"\n\n"
                    "# 1. 检查各业务库同步位点已越过 ${bizdate_end}\n"
                    "# 2. 检查源库主从延迟 < 60 秒\n"
                    "# 3. 不满足时退出码非 0，调度按重试策略等待\n"
                    "python3 bin/check_source_ready.py --bizdate \"$BIZDATE\" --max-lag-seconds 60\n")
        else:
            body = ("set -euo pipefail\nBIZDATE=\"${bizdate}\"\n\n"
                    "# 全部强校验已通过（本节点的上游即各质检节点）\n"
                    "hdfs dfs -touchz \"/warehouse/_ready/" + flow + "/${bizdate}/_SUCCESS\"\n"
                    "python3 bin/publish_ready.py --flow " + flow + " --bizdate \"$BIZDATE\"   # 写就绪表、刷新报表缓存、通知下游订阅\n")
        return f"#!/usr/bin/env bash\n# {cn}\n# {desc}\n\n{body}"

    def ext(self, node):
        return (f"-- 外部依赖：{node['name']}\n-- {node['desc']}\n-- 本节点引用离线日调度任务，实时作业通过 Hive Catalog 按主键 lookup。\n")

    # ---------- 入口 ----------
    def code(self, t):
        layer = self.T[t]["layer"]
        rt = self.rt(t)
        if layer == "ODS":
            return self.S[t]["ddl"] if rt else self.ods(t)
        if layer in ("DIM", "DWD"):
            return self.dwd_rt(t) if rt else self.dim_dwd(t)
        if layer == "DWS":
            return self.dws(t)
        if layer == "ADS":
            return self.ads(t)
        return self.header(t, "")
