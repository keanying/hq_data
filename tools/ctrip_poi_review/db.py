"""MySQL 读写：客户景区表（只读）+ 核对结果 / 进度 / 搜索缓存 / 离线候选。

连接与表名全部走环境变量，见 README.md。
"""
import json
import os
import re
from contextlib import contextmanager

import pymysql

ENV = os.environ.get
DB = dict(
    host=ENV("MYSQL_HOST", "192.168.110.113"),
    port=int(ENV("MYSQL_PORT", "3306")),
    user=ENV("MYSQL_USER", "opinionhub"),
    password=ENV("MYSQL_PASSWORD", "8drfEYnxAdcW5aP3"),
    database=ENV("MYSQL_DB", "opinionhub"),
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
    autocommit=True,
)
_IDENT = re.compile(r"^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)?$")


def ident(name):
    if not _IDENT.match(name):
        raise ValueError(f"非法表名/字段名: {name}")
    return ".".join(f"`{p}`" for p in name.split("."))


SCENIC_TABLE = ident(ENV("SCENIC_TABLE", "pft_ai_dim_prd_scenic_base_yr_f"))
CANDIDATE_TABLE = ident(ENV("CANDIDATE_TABLE", "scenic_ctrip_candidate"))
REVIEW_TABLE = ident(ENV("REVIEW_TABLE", "scenic_ctrip_poi_review"))
STATUS_TABLE = ident(ENV("STATUS_TABLE", "scenic_ctrip_review_status"))
CACHE_TABLE = ident(ENV("CACHE_TABLE", "scenic_ctrip_search_cache"))
COLS = {
    "id": "scenic_id", "name": "scenic_name", "alias": "scenic_alias",
    "province": "province_name", "city": "city_name", "district": "district_name",
    "address": "scenic_address", "lng": "scenic_lng", "lat": "scenic_lat",
    "grade": "scenic_grade_level", "core_spots": "scenic_core_spots",
}
COLS.update(json.loads(ENV("SCENIC_COLS", "{}")))
C = {k: ident(v) for k, v in COLS.items()}
DEFAULT_CITIES = [c for c in ENV("CITIES", "北京市,上海市,广州市,深圳市,杭州市,成都市,西安市").split(",") if c]
GRADE_ORDER = f"FIELD(s.{C['grade']},'5A','4A','3A','2A','1A')"

DDL = [
    f"""CREATE TABLE IF NOT EXISTS {REVIEW_TABLE} (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  scenic_id VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  ctrip_key VARCHAR(128) NOT NULL COMMENT '去重键：poi:<poiId> 或 biz:<businessId>',
  ctrip_poi_id VARCHAR(32) NULL COMMENT '携程 poiId',
  ctrip_business_id VARCHAR(32) NULL COMMENT '携程景点 businessId（url 中的数字）',
  ctrip_poi_name VARCHAR(255) NULL COMMENT '携程名称',
  ctrip_type VARCHAR(64) NULL COMMENT '携程搜索结果 type，如 sight',
  ctrip_city_name VARCHAR(64) NULL,
  ctrip_district_name VARCHAR(64) NULL,
  ctrip_lat DOUBLE NULL, ctrip_lng DOUBLE NULL,
  ctrip_url VARCHAR(512) NULL,
  source VARCHAR(16) NOT NULL COMMENT 'search=携程页面搜索 dom=下拉DOM candidate=离线候选',
  keyword VARCHAR(255) NULL COMMENT '搜索关键词',
  decision VARCHAR(8) NOT NULL COMMENT 'keep=保留 drop=不留',
  raw_json TEXT NULL COMMENT '携程返回的原始条目',
  reviewer VARCHAR(64) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_scenic_ctrip (scenic_id, ctrip_key),
  KEY idx_poi (ctrip_poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景区-携程POI 人工核对结果'""",
    f"""CREATE TABLE IF NOT EXISTS {STATUS_TABLE} (
  scenic_id VARCHAR(64) PRIMARY KEY,
  status VARCHAR(8) NOT NULL COMMENT 'done=已核对 skip=跳过',
  note VARCHAR(500) NULL,
  reviewer VARCHAR(64) NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COMMENT='景区核对进度'""",
    f"""CREATE TABLE IF NOT EXISTS {CACHE_TABLE} (
  keyword VARCHAR(255) PRIMARY KEY COMMENT '搜索关键词',
  item_qty INT NULL,
  capture VARCHAR(16) NULL COMMENT 'network=页面自身请求的返回 dom=下拉DOM',
  result_json MEDIUMTEXT NULL COMMENT '解析后的结果列表',
  searched_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COMMENT='携程页面搜索结果缓存（预抓取/实时搜索都会写）'""",
]


_NAME = re.compile(r"^[A-Za-z0-9_]+$")


def _scenic_schema_table():
    parts = SCENIC_TABLE.replace("`", "").split(".")
    return (parts[0], parts[1]) if len(parts) == 2 else (DB["database"], parts[0])


def scenic_charset(cur):
    """客户景区表 scenic_id 字段的字符集/排序规则；自建表跟它保持一致，避免关联时报 1267 Illegal mix of collations。"""
    schema, table = _scenic_schema_table()
    cur.execute("""SELECT character_set_name AS cs, collation_name AS co FROM information_schema.columns
                   WHERE table_schema=%s AND table_name=%s AND column_name=%s""", (schema, table, COLS["id"]))
    r = cur.fetchone()
    if r and r["cs"] and r["co"] and _NAME.match(r["cs"]) and _NAME.match(r["co"]):
        return r["cs"], r["co"]
    return "utf8mb4", None


def charset_clause(cur):
    cs, co = scenic_charset(cur)
    return f"DEFAULT CHARSET={cs}" + (f" COLLATE={co}" if co else "")


def align_collation(cur, quoted_table, column="scenic_id"):
    """已存在的自建表排序规则和客户景区表不一致时，整表转换（表都很小）。"""
    cs, co = scenic_charset(cur)
    if not co or not table_exists(cur, quoted_table):
        return False
    name = quoted_table.replace("`", "").split(".")
    schema, table = (name[0], name[1]) if len(name) == 2 else (DB["database"], name[0])
    cur.execute("""SELECT collation_name AS co FROM information_schema.columns
                   WHERE table_schema=%s AND table_name=%s AND column_name=%s""", (schema, table, column))
    r = cur.fetchone()
    if r and r["co"] and r["co"] != co:
        cur.execute(f"ALTER TABLE {quoted_table} CONVERT TO CHARACTER SET {cs} COLLATE {co}")
        print(f"已把 {quoted_table} 的排序规则从 {r['co']} 转为 {co}（与客户景区表一致）", flush=True)
        return True
    return False


@contextmanager
def cursor():
    conn = pymysql.connect(**DB)
    try:
        with conn.cursor() as cur:
            yield cur
    finally:
        conn.close()


def _jsonable(rows):
    for row in rows:
        if row:
            for k, v in row.items():
                if hasattr(v, "isoformat"):
                    row[k] = v.isoformat(sep=" ")
    return rows


def init_db():
    with cursor() as cur:
        clause = charset_clause(cur)
        for ddl in DDL:
            cur.execute(ddl.replace("DEFAULT CHARSET=utf8mb4", clause))
        for t, col in ((REVIEW_TABLE, "scenic_id"), (STATUS_TABLE, "scenic_id"), (CANDIDATE_TABLE, "scenic_id"), (CACHE_TABLE, "keyword")):
            align_collation(cur, t, col)


def table_exists(cur, quoted):
    name = quoted.replace("`", "").split(".")[-1]
    cur.execute("SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=%s", (name,))
    return cur.fetchone() is not None


def preflight():
    """启动前自检：连得上、客户景区表存在、字段都在。返回问题列表（空 = 正常）。"""
    problems = []
    try:
        conn = pymysql.connect(**DB)
    except Exception as e:
        return [f"连不上 MySQL（{DB['user']}@{DB['host']}:{DB['port']}/{DB['database']}）：{e}"]
    try:
        with conn.cursor() as cur:
            schema, table = _scenic_schema_table()
            cur.execute("SELECT column_name AS c FROM information_schema.columns WHERE table_schema=%s AND table_name=%s", (schema, table))
            cols = {r["c"].lower() for r in cur.fetchall()}
            if not cols:
                cur.execute("""SELECT CONCAT(table_schema, '.', table_name) t FROM information_schema.tables
                               WHERE (table_name LIKE %s OR table_name LIKE %s) AND table_name NOT LIKE %s
                               AND table_schema NOT IN ('information_schema','mysql','performance_schema','sys')
                               ORDER BY 1 LIMIT 20""", ("%scenic%", "%dim_prd%", "scenic\\_ctrip\\_%"))
                similar = [r["t"] for r in cur.fetchall()]
                problems.append(f"找不到客户景区表 {schema}.{table}。请设置环境变量 SCENIC_TABLE=库.表"
                                + (f"；库里相近的表：{', '.join(similar)}" if similar else ""))
            else:
                missing = [f"{k}={v}" for k, v in COLS.items() if v.lower() not in cols]
                if missing:
                    problems.append(f"客户景区表 {schema}.{table} 缺少字段：{', '.join(missing)}。"
                                    "字段名不同请用 SCENIC_COLS='{\"name\":\"实际字段\"}' 覆盖")
    finally:
        conn.close()
    return problems


def health():
    with cursor() as cur:
        cur.execute(f"SELECT COUNT(*) n FROM {SCENIC_TABLE}")
        n = cur.fetchone()["n"]
        return dict(ok=True, scenic_rows=n, candidate_table=table_exists(cur, CANDIDATE_TABLE), cities=DEFAULT_CITIES)


def cities():
    with cursor() as cur:
        cur.execute(f"""SELECT s.{C['province']} province, s.{C['city']} city, COUNT(*) n,
                        CAST(SUM(st.status IS NOT NULL) AS SIGNED) reviewed
                        FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']}
                        GROUP BY 1,2 ORDER BY n DESC""")
        return list(cur.fetchall())


def _filters(f):
    where, params = [], []
    cities_ = [c for c in (f.get("city") or "").split(",") if c] or DEFAULT_CITIES
    if cities_:
        where.append(f"s.{C['city']} IN ({','.join(['%s'] * len(cities_))})"); params += cities_
    if f.get("province"):
        where.append(f"s.{C['province']} = %s"); params.append(f["province"])
    if f.get("grade"):
        g = [x for x in f["grade"].split(",") if x]
        where.append(f"s.{C['grade']} IN ({','.join(['%s'] * len(g))})"); params += g
    st = f.get("status") or "todo"
    if st == "todo":
        where.append("st.status IS NULL")
    elif st in ("done", "skip"):
        where.append("st.status = %s"); params.append(st)
    if f.get("q"):
        where.append(f"(s.{C['name']} LIKE %s OR s.{C['alias']} LIKE %s OR s.{C['id']} = %s)")
        params += [f"%{f['q']}%", f"%{f['q']}%", f["q"]]
    return ("WHERE " + " AND ".join(where)) if where else "", params


def _select():
    return ", ".join(f"s.{v} AS `{k}`" for k, v in C.items())


def scenic_list(f, offset=0, limit=200):
    where, params = _filters(f)
    base = f"FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']} {where}"
    with cursor() as cur:
        cur.execute(f"SELECT COUNT(*) n {base}", params)
        total = cur.fetchone()["n"]
        cur.execute(f"""SELECT {_select()}, st.status, st.note
                        {base} ORDER BY s.{C['city']}, {GRADE_ORDER}, s.{C['id']} LIMIT %s OFFSET %s""",
                    params + [int(limit), int(offset)])
        return dict(total=total, offset=offset, items=list(cur.fetchall()))


def scenic_detail(sid):
    with cursor() as cur:
        cur.execute(f"SELECT {_select()} FROM {SCENIC_TABLE} s WHERE s.{C['id']}=%s", (sid,))
        s = cur.fetchone()
        if not s:
            raise KeyError(f"景区不存在: {sid}")
        cur.execute(f"SELECT status, note, reviewer, updated_at FROM {STATUS_TABLE} WHERE scenic_id=%s", (sid,))
        st = cur.fetchone()
        cands = []
        if table_exists(cur, CANDIDATE_TABLE):
            cur.execute(f"SELECT * FROM {CANDIDATE_TABLE} WHERE scenic_id=%s ORDER BY FIELD(confidence,'高','中','低'), image_qty DESC", (sid,))
            cands = list(cur.fetchall())
        cur.execute(f"""SELECT ctrip_key, ctrip_poi_id, ctrip_business_id, ctrip_poi_name, ctrip_type, ctrip_url,
                        source, keyword, decision, reviewer, updated_at FROM {REVIEW_TABLE} WHERE scenic_id=%s""", (sid,))
        decs = list(cur.fetchall())
    _jsonable([st] + cands + decs)
    return dict(scenic=s, status=st, candidates=cands, decisions=decs)


def _poi_from_business(cur, biz):
    """下拉 DOM 只有景点ID(businessId) 时，尽量从候选表/历史判定里补 poiId，避免同一 POI 两个键。"""
    if table_exists(cur, CANDIDATE_TABLE):
        cur.execute(f"SELECT ctrip_poi_id FROM {CANDIDATE_TABLE} WHERE ctrip_business_id=%s LIMIT 1", (biz,))
        r = cur.fetchone()
        if r:
            return r["ctrip_poi_id"]
    cur.execute(f"SELECT ctrip_poi_id FROM {REVIEW_TABLE} WHERE ctrip_business_id=%s AND ctrip_poi_id IS NOT NULL LIMIT 1", (biz,))
    r = cur.fetchone()
    return r["ctrip_poi_id"] if r else None


def set_decision(d):
    if not d.get("scenic_id"):
        raise ValueError("scenic_id 必填")
    with cursor() as cur:
        if not d.get("ctrip_poi_id") and d.get("ctrip_business_id"):
            d["ctrip_poi_id"] = _poi_from_business(cur, d["ctrip_business_id"])
        if d.get("ctrip_poi_id"):
            key = f"poi:{d['ctrip_poi_id']}"
        elif d.get("ctrip_business_id"):
            key = f"biz:{d['ctrip_business_id']}"
        else:
            raise ValueError("需要 poiId 或 景点ID")
        if d.get("decision") in (None, "", "clear"):
            cur.execute(f"DELETE FROM {REVIEW_TABLE} WHERE scenic_id=%s AND ctrip_key=%s", (d["scenic_id"], key))
            return dict(ok=True, cleared=True, ctrip_key=key)
        if d["decision"] not in ("keep", "drop"):
            raise ValueError("decision 只能是 keep/drop")
        raw = d.get("raw_json")
        if raw is not None and not isinstance(raw, str):
            raw = json.dumps(raw, ensure_ascii=False)
        cols = ["scenic_id", "ctrip_key", "ctrip_poi_id", "ctrip_business_id", "ctrip_poi_name", "ctrip_type",
                "ctrip_city_name", "ctrip_district_name", "ctrip_lat", "ctrip_lng", "ctrip_url", "source",
                "keyword", "decision", "raw_json", "reviewer"]
        vals = [d["scenic_id"], key] + [d.get(c) for c in cols[2:14]] + [raw, d.get("reviewer")]
        vals = [None if v == "" else v for v in vals]
        upd = ", ".join(f"{c}=VALUES({c})" for c in cols[2:] if c not in ("source", "keyword")) + \
            ", source=COALESCE(source, VALUES(source)), keyword=COALESCE(VALUES(keyword), keyword)"
        cur.execute(f"INSERT INTO {REVIEW_TABLE} ({','.join(cols)}) VALUES ({','.join(['%s'] * len(cols))}) "
                    f"ON DUPLICATE KEY UPDATE {upd}", vals)
    return dict(ok=True, ctrip_key=key)


def set_status(d):
    if not d.get("scenic_id"):
        raise ValueError("scenic_id 必填")
    with cursor() as cur:
        if d.get("status") in (None, "", "todo"):
            cur.execute(f"DELETE FROM {STATUS_TABLE} WHERE scenic_id=%s", (d["scenic_id"],))
        elif d["status"] in ("done", "skip"):
            cur.execute(f"""INSERT INTO {STATUS_TABLE} (scenic_id, status, note, reviewer) VALUES (%s,%s,%s,%s)
                            ON DUPLICATE KEY UPDATE status=VALUES(status), note=VALUES(note), reviewer=VALUES(reviewer)""",
                        (d["scenic_id"], d["status"], d.get("note"), d.get("reviewer")))
        else:
            raise ValueError("status 只能是 done/skip/todo")
    return dict(ok=True)


def cache_get(keyword):
    with cursor() as cur:
        cur.execute(f"SELECT keyword, item_qty, capture, result_json, searched_at FROM {CACHE_TABLE} WHERE keyword=%s", (keyword,))
        r = cur.fetchone()
    if not r:
        return None
    _jsonable([r])
    r["result"] = json.loads(r.pop("result_json") or "null")
    return r


def cache_put(keyword, result):
    with cursor() as cur:
        cur.execute(f"""INSERT INTO {CACHE_TABLE} (keyword, item_qty, capture, result_json) VALUES (%s,%s,%s,%s)
                        ON DUPLICATE KEY UPDATE item_qty=VALUES(item_qty), capture=VALUES(capture),
                        result_json=VALUES(result_json), searched_at=CURRENT_TIMESTAMP""",
                    (keyword, len(result.get("items") or []), result.get("capture"), json.dumps(result, ensure_ascii=False)))


def export_rows():
    """每个景区一行：保留的携程 POI 列表（| 分隔）。"""
    with cursor() as cur:
        cur.execute("SET SESSION group_concat_max_len = 1000000")
        cur.execute(f"""SELECT r.scenic_id, s.{C['name']} scenic_name, s.{C['city']} city_name, st.status,
                        COUNT(*) kept_qty,
                        GROUP_CONCAT(COALESCE(r.ctrip_poi_id,'') ORDER BY r.id SEPARATOR '|') ctrip_poi_id_list,
                        GROUP_CONCAT(COALESCE(r.ctrip_business_id,'') ORDER BY r.id SEPARATOR '|') ctrip_business_id_list,
                        GROUP_CONCAT(COALESCE(r.ctrip_poi_name,'') ORDER BY r.id SEPARATOR '|') ctrip_poi_name_list
                        FROM {REVIEW_TABLE} r
                        LEFT JOIN {SCENIC_TABLE} s ON s.{C['id']} = r.scenic_id
                        LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = r.scenic_id
                        WHERE r.decision='keep' GROUP BY r.scenic_id, s.{C['name']}, s.{C['city']}, st.status
                        ORDER BY s.{C['city']}, r.scenic_id""")
        return list(cur.fetchall())
