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
    host=ENV("MYSQL_HOST", "127.0.0.1"),
    port=int(ENV("MYSQL_PORT", "3306")),
    user=ENV("MYSQL_USER", "root"),
    password=ENV("MYSQL_PASSWORD", ""),
    database=ENV("MYSQL_DB", "hq"),
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
REVIEW_TABLE = ident(ENV("REVIEW_TABLE", "scenic_ctrip_poi_review"))  # 旧版明细表，仅用于一次性迁移
POI_INFO_NAME = ENV("POI_INFO_COL", "ctrip_poi_info")
POI_INFO = ident(POI_INFO_NAME)  # 客户景区表上存结果的字段：[{"poiId":..,"poiName":..,"poiUri":..}]
APPROVAL_NAME = ENV("APPROVAL_COL", "approval")
APPROVAL = ident(APPROVAL_NAME)  # 客户景区表上的审核状态：1-已审核 0-未审核
APPROVED = f"COALESCE(s.{APPROVAL}, 0) = 1"
STATUS_TABLE = ident(ENV("STATUS_TABLE", "scenic_ctrip_review_status"))
CACHE_TABLE = ident(ENV("CACHE_TABLE", "scenic_ctrip_search_cache"))
MASTER_TABLE = ident(ENV("CTRIP_MASTER_TABLE", "ctrip_attraction_master"))
ADDR_TABLE = ident(ENV("ADDR_TABLE", "ctrip_poi_address_cache"))
IMAGE_TABLE = ident(ENV("IMAGE_TABLE", "scenic_poi_image"))
CRAWL_TABLE = ident(ENV("CRAWL_TABLE", "scenic_poi_image_crawl"))
# 交付表（你建好的分区天表）。不存在时只写工具自己的 scenic_poi_image
ODS_TABLE = ident(ENV("ODS_IMAGE_TABLE", "ods_prd_poi_image_di"))
ODS_COORD = ENV("ODS_COORD", "wgs84").lower()          # wgs84：客户景区坐标(GCJ02)换算成 WGS84 再写；gcj02：原样写
ODS_AUTO_PARTITION = ENV("ODS_AUTO_PARTITION", "1") != "0"  # 当天没有分区时自动 ADD PARTITION
COLS = {
    "id": "scenic_id", "name": "scenic_name", "alias": "scenic_alias",
    "province": "province_name", "city": "city_name", "district": "district_name",
    "address": "scenic_address", "lng": "scenic_lng", "lat": "scenic_lat",
    "grade": "scenic_grade_level", "core_spots": "scenic_core_spots",
}
COLS.update(json.loads(ENV("SCENIC_COLS", "{}")))
C = {k: ident(v) for k, v in COLS.items()}
DEFAULT_CITIES = [c for c in ENV("CITIES", "北京市,上海市,广州市,深圳市,杭州市,成都市,西安市").split(",") if c]
if [c.strip().lower() for c in DEFAULT_CITIES] in (["all"], ["*"], ["全部"]):  # CITIES=ALL：全国
    DEFAULT_CITIES = []
GRADE_ORDER = f"FIELD(s.{C['grade']},'5A','4A','3A','2A','1A')"

DDL = [
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
    f"""CREATE TABLE IF NOT EXISTS {ADDR_TABLE} (
  ctrip_key VARCHAR(128) PRIMARY KEY COMMENT 'poi:<poiId> 或 biz:<businessId>',
  ctrip_poi_id VARCHAR(32) NULL, ctrip_business_id VARCHAR(32) NULL,
  ctrip_poi_name VARCHAR(255) NULL,
  address VARCHAR(500) NULL COMMENT '携程详情页上的地址',
  page_url VARCHAR(512) NULL,
  fetched_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_poi (ctrip_poi_id), KEY idx_biz (ctrip_business_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='携程 POI 地址缓存（打开详情页读取）'""",
]
DDL += [
    f"""CREATE TABLE IF NOT EXISTS {IMAGE_TABLE} (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  record_id VARCHAR(32) NULL COMMENT '记录ID：img_<采集日期>_<序号>',
  poi_id BIGINT NOT NULL COMMENT '携程 poiId',
  poi_name VARCHAR(255) NULL COMMENT '携程 POI 名称',
  scenic_id VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  scenic_name VARCHAR(255) NULL,
  image_url VARCHAR(512) NOT NULL COMMENT '点评图片（imageSrcUrl，W_640）',
  image_thumb_url VARCHAR(512) NULL COMMENT '缩略图（imageThumbUrl）',
  lon DOUBLE NULL COMMENT '景区经度（客户景区表）', lat DOUBLE NULL COMMENT '景区纬度（客户景区表）',
  province VARCHAR(64) NULL, city VARCHAR(64) NULL, district VARCHAR(64) NULL,
  total_count BIGINT NULL COMMENT '该 POI 图片总数（携程主页上的图片数，读不到为空）',
  comment_total INT NULL COMMENT '该 POI 点评总数（getCommentCollapseList.totalCount）',
  review_id BIGINT NULL COMMENT '点评 commentId',
  image_id BIGINT NOT NULL COMMENT '携程图片 imageId',
  width INT NULL, height INT NULL,
  review_score DOUBLE NULL COMMENT '点评评分', review_publish_time DATETIME NULL COMMENT '点评发布时间',
  collect_time DATETIME NOT NULL COMMENT '采集时间',
  data_source VARCHAR(32) NOT NULL DEFAULT 'OTA-图片爬取',
  is_modified TINYINT NOT NULL DEFAULT 0 COMMENT '是否人工修改过：0-否 1-是',
  UNIQUE KEY uk_scenic_poi_image (scenic_id, poi_id, image_id),
  KEY idx_poi (poi_id), KEY idx_record (record_id), KEY idx_review (review_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景点图像识别：携程点评图片'""",
    f"""CREATE TABLE IF NOT EXISTS {CRAWL_TABLE} (
  scenic_id VARCHAR(64) NOT NULL, poi_id BIGINT NOT NULL,
  poi_name VARCHAR(255) NULL, poi_uri VARCHAR(512) NULL,
  status VARCHAR(16) NULL COMMENT 'running / done / failed',
  pages_done INT NOT NULL DEFAULT 0 COMMENT '已翻到第几页',
  total_count INT NULL COMMENT '点评总数', review_qty INT NOT NULL DEFAULT 0 COMMENT '已读点评数',
  image_qty INT NOT NULL DEFAULT 0 COMMENT '已入库图片数',
  message VARCHAR(500) NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (scenic_id, poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='点评图片采集进度（断点续采）'""",
]
MASTER_DDL = f"""CREATE TABLE IF NOT EXISTS {MASTER_TABLE} (
  ctrip_poi_id VARCHAR(32) PRIMARY KEY, ctrip_business_id VARCHAR(32) NULL,
  attraction_name VARCHAR(255) NULL, city_name VARCHAR(64) NULL, district_name VARCHAR(64) NULL,
  business_area_name VARCHAR(255) NULL, attraction_address VARCHAR(500) NULL, poi_type VARCHAR(64) NULL,
  attraction_level VARCHAR(8) NULL, gcj02_lng DOUBLE NULL, gcj02_lat DOUBLE NULL, ctrip_url VARCHAR(512) NULL,
  KEY idx_biz (ctrip_business_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='携程景区主档（来自交付数据 dim.dim_prd_attraction_df，用于补地址）'"""


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
        for t, col in ((STATUS_TABLE, "scenic_id"), (CANDIDATE_TABLE, "scenic_id"),
                       (CACHE_TABLE, "keyword"), (ADDR_TABLE, "ctrip_key"), (IMAGE_TABLE, "scenic_id"), (CRAWL_TABLE, "scenic_id")):
            align_collation(cur, t, col)
    ensure_poi_info_column()
    with cursor() as cur:  # 旧版「已完成」状态同步到 approval
        cur.execute(f"""UPDATE {SCENIC_TABLE} s JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']}
                        SET s.{APPROVAL} = 1 WHERE st.status = 'done' AND COALESCE(s.{APPROVAL}, 0) = 0""")
    n = migrate_review_table()
    if n:
        print(f"已把旧表 {REVIEW_TABLE} 里 {n} 个景区的「保留」结果迁移到 {SCENIC_TABLE}.{POI_INFO}", flush=True)
    n = backfill_poi_info()
    if n:
        print(f"已给 {n} 个景区的 {POI_INFO} 补齐 addr/lat/lon", flush=True)


def ensure_poi_info_column():
    """客户景区表上没有结果字段就加：ctrip_poi_info（LONGTEXT，JSON 数组）、approval（审核状态 1/0）。"""
    schema, table = _scenic_schema_table()
    specs = [
        (POI_INFO_NAME, f"{POI_INFO} LONGTEXT NULL COMMENT '携程POI列表 JSON：[{{\"poiId\":123,\"poiName\":\"名字\",\"poiUri\":\"链接\",\"addr\":\"地址\",\"lat\":30.86,\"lon\":121.59}}]（GCJ02）；空=未核对，[]=核对过无匹配'"),
        (APPROVAL_NAME, f"{APPROVAL} TINYINT NOT NULL DEFAULT 0 COMMENT '审核状态：1-已审核 0-未审核'"),
    ]
    added = []
    with cursor() as cur:
        for name, col_sql in specs:
            cur.execute("""SELECT 1 FROM information_schema.columns WHERE table_schema=%s AND table_name=%s AND column_name=%s""",
                        (schema, table, name))
            if cur.fetchone():
                continue
            sql = f"ALTER TABLE {SCENIC_TABLE} ADD COLUMN {col_sql}"
            try:
                cur.execute(sql)
            except Exception as e:
                raise RuntimeError(f"给 {SCENIC_TABLE} 加字段 {name} 失败（{e}）。请让 DBA 执行：{sql}") from e
            print(f"已在 {SCENIC_TABLE} 上新增字段 `{name}`", flush=True)
            added.append(name)
    return added


def _parse_info(text):
    if not text:
        return []
    try:
        v = json.loads(text)
        return [x for x in v if isinstance(x, dict) and x.get("poiId") not in (None, "")] if isinstance(v, list) else []
    except Exception:
        return []


def _num(v):
    try:
        f = float(v)
        return round(f, 7) if f == f else None
    except (TypeError, ValueError):
        return None


def _poi_obj(poi_id, name, uri, addr=None, lat=None, lon=None):
    """ctrip_poi_info 里的一项。坐标为携程返回的 GCJ02（与携程主档一致）。"""
    pid = str(poi_id).strip()
    return {"poiId": int(pid) if pid.isdigit() else pid, "poiName": name or "", "poiUri": uri or "",
            "addr": addr or "", "lat": _num(lat), "lon": _num(lon)}


def _fill_missing(objs):
    """addr / lat / lon 缺的，用携程主档、详情页地址缓存补。返回补了几项。"""
    need = [o for o in objs if not o.get("addr") or o.get("lat") is None or o.get("lon") is None]
    if not need:
        return 0
    info = lookup_addresses([o["poiId"] for o in need], [])
    n = 0
    for o in need:
        h = info.get(f"poi:{o['poiId']}") or {}
        changed = False
        if not o.get("addr") and h.get("address"):
            o["addr"] = h["address"]; changed = True
        if o.get("lat") is None and h.get("lat") is not None and o.get("lon") is None and h.get("lng") is not None:
            o["lat"], o["lon"] = _num(h["lat"]), _num(h["lng"]); changed = True
        n += changed
    return n


def _normalize(lst):
    """旧数据统一成 poiId/poiName/poiUri/addr/lat/lon 六个键。"""
    return [_poi_obj(x.get("poiId"), x.get("poiName"), x.get("poiUri"), x.get("addr"), x.get("lat"), x.get("lon")) for x in lst]


def backfill_poi_info():
    """已有的 ctrip_poi_info 补齐 addr/lat/lon（来自携程主档、详情页地址缓存）。"""
    with cursor() as cur:
        cur.execute(f"SELECT {C['id']} AS sid, {POI_INFO} AS v FROM {SCENIC_TABLE} WHERE {POI_INFO} IS NOT NULL AND {POI_INFO} <> '[]'")
        rows = list(cur.fetchall())
    changed = 0
    for r in rows:
        old = _parse_info(r["v"])
        lst = _normalize(old)
        n = _fill_missing(lst)
        if n or any(set(x) != set(y) for x, y in zip(old, lst)):
            with cursor() as cur:
                cur.execute(f"UPDATE {SCENIC_TABLE} SET {POI_INFO}=%s WHERE {C['id']}=%s", (json.dumps(lst, ensure_ascii=False), r["sid"]))
            changed += 1
    return changed


def migrate_review_table():
    """旧版把结果存在 scenic_ctrip_poi_review；把其中 keep 的搬到 ctrip_poi_info（只搬字段还是空的景区）。"""
    with cursor() as cur:
        if not table_exists(cur, REVIEW_TABLE):
            return 0
        cur.execute(f"""SELECT r.scenic_id, r.ctrip_poi_id, r.ctrip_poi_name, r.ctrip_url FROM {REVIEW_TABLE} r
                        JOIN {SCENIC_TABLE} s ON s.{C['id']} = r.scenic_id
                        WHERE r.decision='keep' AND r.ctrip_poi_id IS NOT NULL AND s.{POI_INFO} IS NULL ORDER BY r.id""")
        by = {}
        for r in cur.fetchall():
            by.setdefault(r["scenic_id"], []).append(_poi_obj(r["ctrip_poi_id"], r["ctrip_poi_name"], r["ctrip_url"]))
        for lst in by.values():
            _fill_missing(lst)
        for sid, lst in by.items():
            cur.execute(f"UPDATE {SCENIC_TABLE} SET {POI_INFO}=%s WHERE {C['id']}=%s AND {POI_INFO} IS NULL",
                        (json.dumps(lst, ensure_ascii=False), sid))
        return len(by)


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
    """各城市景区数 / 已审核数；设置了 CITIES 时只返回这些城市（按 CITIES 的顺序）。"""
    where, params = "", []
    if DEFAULT_CITIES:
        where = f"WHERE s.{C['city']} IN ({','.join(['%s'] * len(DEFAULT_CITIES))})"
        params = DEFAULT_CITIES
    with cursor() as cur:
        cur.execute(f"""SELECT s.{C['province']} province, s.{C['city']} city, COUNT(*) n,
                        CAST(SUM({APPROVED}) AS SIGNED) reviewed,
                        CAST(SUM(NOT {APPROVED} AND st.status = 'skip') AS SIGNED) skipped
                        FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']}
                        {where} GROUP BY 1,2 ORDER BY n DESC""", params)
        rows = list(cur.fetchall())
    if DEFAULT_CITIES:
        order = {c: i for i, c in enumerate(DEFAULT_CITIES)}
        rows.sort(key=lambda r: order.get(r["city"], 99))
    else:  # 全国模式：按省、再按市（和待核对列表的顺序一致）
        rows.sort(key=lambda r: (r["province"] or "", r["city"] or ""))
    return rows


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
        where.append(f"NOT {APPROVED} AND (st.status IS NULL OR st.status <> 'skip')")
    elif st == "done":
        where.append(APPROVED)
    elif st == "skip":
        where.append(f"NOT {APPROVED} AND st.status = 'skip'")
    elif st == "auto":  # 自动审核通过的（备注以「自动审核」开头），供抽查
        where.append(f"{APPROVED} AND st.note LIKE %s"); params.append("自动审核%")
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
        # 城市按 CITIES 的顺序依次排（一个城市跑完再下一个），城市内 5A→4A→…
        city_order, city_params = ((f"FIELD(s.{C['city']}, {','.join(['%s'] * len(DEFAULT_CITIES))}), ", list(DEFAULT_CITIES)) if DEFAULT_CITIES
                                   else (f"s.{C['province']}, ", []))  # 全国模式：按省、再按市依次跑
        cur.execute(f"""SELECT {_select()}, COALESCE(s.{APPROVAL}, 0) approval, st.status, st.note
                        {base} ORDER BY {city_order}s.{C['city']}, {GRADE_ORDER}, s.{C['id']} LIMIT %s OFFSET %s""",
                    params + city_params + [int(limit), int(offset)])
        return dict(total=total, offset=offset, items=list(cur.fetchall()))


def scenic_detail(sid):
    with cursor() as cur:
        cur.execute(f"SELECT {_select()}, s.{POI_INFO} AS poi_info, COALESCE(s.{APPROVAL}, 0) AS approval FROM {SCENIC_TABLE} s WHERE s.{C['id']}=%s", (sid,))
        s = cur.fetchone()
        if not s:
            raise KeyError(f"景区不存在: {sid}")
        kept = _parse_info(s.pop("poi_info"))
        cur.execute(f"SELECT status, note, reviewer, updated_at FROM {STATUS_TABLE} WHERE scenic_id=%s", (sid,))
        st = cur.fetchone()
        cands = []
        if table_exists(cur, CANDIDATE_TABLE):
            cur.execute(f"SELECT * FROM {CANDIDATE_TABLE} WHERE scenic_id=%s ORDER BY FIELD(confidence,'高','中','低'), image_qty DESC", (sid,))
            cands = list(cur.fetchall())
    _jsonable([st] + cands)
    return dict(scenic=s, status=st, candidates=cands, kept=kept)


def _poi_from_business(cur, biz):
    """只有景点ID(businessId) 时，从携程主档/候选表补 poiId。"""
    for t, col in ((MASTER_TABLE, "ctrip_poi_id"), (CANDIDATE_TABLE, "ctrip_poi_id")):
        if table_exists(cur, t):
            cur.execute(f"SELECT {col} AS p FROM {t} WHERE ctrip_business_id=%s LIMIT 1", (biz,))
            r = cur.fetchone()
            if r and r["p"]:
                return r["p"]
    return None


def set_poi(d):
    """保留 / 取消保留一个携程 POI：直接改客户景区表的 ctrip_poi_info（JSON 数组），返回最新列表。"""
    sid = d.get("scenic_id")
    if not sid:
        raise ValueError("scenic_id 必填")
    conn = pymysql.connect(**{**DB, "autocommit": False})
    try:
        with conn.cursor() as cur:
            poi = d.get("poiId")
            if not poi and d.get("businessId"):
                poi = _poi_from_business(cur, d["businessId"])
            if not poi:
                raise ValueError("这条结果没有 poiId，无法保存")
            cur.execute(f"SELECT {POI_INFO} AS v FROM {SCENIC_TABLE} WHERE {C['id']}=%s FOR UPDATE", (sid,))
            row = cur.fetchone()
            if row is None:
                raise KeyError(f"景区不存在: {sid}")
            lst = _normalize(_parse_info(row["v"]))
            idx = next((i for i, x in enumerate(lst) if str(x["poiId"]) == str(poi)), None)
            if not d.get("keep"):
                if idx is not None:
                    lst.pop(idx)
            else:
                new = _poi_obj(poi, d.get("poiName"), d.get("poiUri"), d.get("addr"), d.get("lat"), d.get("lon"))
                if idx is None:
                    lst.append(new)
                else:  # 已保留的再保存一次 = 更新（只用新值覆盖非空字段，位置不变）
                    lst[idx].update({k: v for k, v in new.items() if v not in (None, "")})
                _fill_missing(lst)
            cur.execute(f"UPDATE {SCENIC_TABLE} SET {POI_INFO}=%s WHERE {C['id']}=%s", (json.dumps(lst, ensure_ascii=False), sid))
        conn.commit()
        return dict(ok=True, kept=lst, poiId=str(poi))
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def set_status(d):
    """done=审核完成（approval=1）；skip=跳过（approval=0，记在进度表）；todo=恢复未审核。备注/核对人记在进度表。"""
    sid = d.get("scenic_id")
    if not sid:
        raise ValueError("scenic_id 必填")
    status = d.get("status") or "todo"
    if status not in ("done", "skip", "todo"):
        raise ValueError("status 只能是 done/skip/todo")
    with cursor() as cur:
        if status == "todo":
            cur.execute(f"DELETE FROM {STATUS_TABLE} WHERE scenic_id=%s", (sid,))
        else:
            cur.execute(f"""INSERT INTO {STATUS_TABLE} (scenic_id, status, note, reviewer) VALUES (%s,%s,%s,%s)
                            ON DUPLICATE KEY UPDATE status=VALUES(status), note=VALUES(note), reviewer=VALUES(reviewer)""",
                        (sid, status, d.get("note"), d.get("reviewer")))
        cur.execute(f"UPDATE {SCENIC_TABLE} SET {APPROVAL}=%s WHERE {C['id']}=%s", (1 if status == "done" else 0, sid))
        if status == "done":  # 审核完但一个都没保留：写 []，和「未核对」(NULL) 区分开
            cur.execute(f"UPDATE {SCENIC_TABLE} SET {POI_INFO}='[]' WHERE {C['id']}=%s AND {POI_INFO} IS NULL", (sid,))
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
    """每个景区一行（只含已写过 ctrip_poi_info 的）：poiId / 名称列表（| 分隔）+ 原始 JSON。"""
    with cursor() as cur:
        cur.execute(f"""SELECT s.{C['id']} scenic_id, s.{C['name']} scenic_name, s.{C['city']} city_name,
                        COALESCE(s.{APPROVAL}, 0) approval, st.note, s.{POI_INFO} info
                        FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']}
                        WHERE s.{POI_INFO} IS NOT NULL ORDER BY s.{C['city']}, s.{C['id']}""")
        rows = list(cur.fetchall())
    out = []
    for r in rows:
        lst = _parse_info(r.pop("info"))
        out.append(dict(r, kept_qty=len(lst), ctrip_poi_id_list="|".join(str(x["poiId"]) for x in lst),
                        ctrip_poi_name_list="|".join(x.get("poiName") or "" for x in lst),
                        ctrip_poi_info=json.dumps(lst, ensure_ascii=False)))
    return out


def lookup_addresses(poi_ids, biz_ids):
    """按 poiId / 景点ID 查地址：先查携程主档（交付数据），再查详情页地址缓存。返回 {ctrip_key: {...}}。"""
    poi_ids = sorted({str(x) for x in poi_ids if x})
    biz_ids = sorted({str(x) for x in biz_ids if x})
    out = {}
    if not poi_ids and not biz_ids:
        return out
    with cursor() as cur:
        if table_exists(cur, MASTER_TABLE):
            conds, params = [], []
            if poi_ids:
                conds.append(f"ctrip_poi_id IN ({','.join(['%s'] * len(poi_ids))})"); params += poi_ids
            if biz_ids:
                conds.append(f"ctrip_business_id IN ({','.join(['%s'] * len(biz_ids))})"); params += biz_ids
            cur.execute(f"""SELECT ctrip_poi_id, ctrip_business_id, attraction_name, district_name, attraction_address, attraction_level,
                            gcj02_lat, gcj02_lng FROM {MASTER_TABLE} WHERE {' OR '.join(conds)}""", params)
            for r in cur.fetchall():
                info = dict(address=r["attraction_address"], level=r["attraction_level"], district=r["district_name"],
                            lat=r["gcj02_lat"], lng=r["gcj02_lng"],
                            poiId=r["ctrip_poi_id"], businessId=r["ctrip_business_id"], source="主档")
                out[f"poi:{r['ctrip_poi_id']}"] = info
                if r["ctrip_business_id"]:
                    out.setdefault(f"biz:{r['ctrip_business_id']}", info)
        keys = [f"poi:{x}" for x in poi_ids] + [f"biz:{x}" for x in biz_ids]
        keys = [k for k in keys if k not in out or not out[k].get("address")]
        if keys:
            cur.execute(f"""SELECT ctrip_key, ctrip_poi_id, ctrip_business_id, address, fetched_at FROM {ADDR_TABLE}
                            WHERE ctrip_key IN ({','.join(['%s'] * len(keys))})""", keys)
            for r in cur.fetchall():
                prev = out.get(r["ctrip_key"], {})
                out[r["ctrip_key"]] = dict(prev, address=r["address"], source="详情页",
                                          poiId=prev.get("poiId") or r["ctrip_poi_id"], businessId=prev.get("businessId") or r["ctrip_business_id"])
    return out


def addr_put(poi_id, biz_id, name, address, page_url):
    rows = []
    if poi_id:
        rows.append(f"poi:{poi_id}")
    if biz_id:
        rows.append(f"biz:{biz_id}")
    with cursor() as cur:
        for key in rows:
            cur.execute(f"""INSERT INTO {ADDR_TABLE} (ctrip_key, ctrip_poi_id, ctrip_business_id, ctrip_poi_name, address, page_url)
                            VALUES (%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE address=VALUES(address), page_url=VALUES(page_url),
                            ctrip_poi_id=COALESCE(VALUES(ctrip_poi_id), ctrip_poi_id), ctrip_business_id=COALESCE(VALUES(ctrip_business_id), ctrip_business_id),
                            ctrip_poi_name=COALESCE(VALUES(ctrip_poi_name), ctrip_poi_name), fetched_at=CURRENT_TIMESTAMP""",
                        (key, poi_id or None, biz_id or None, name or None, address, page_url or None))


# ---------------------------------------------------------------- 点评图片（景点图像识别）
def crawl_targets(f, refresh=False):
    """已审核通过（approval=1）的景区里，ctrip_poi_info 保留的每个 POI。默认跳过已采完的。"""
    where, params = _filters(dict(f, status="done"))
    city_order, city_params = ((f"FIELD(s.{C['city']}, {','.join(['%s'] * len(DEFAULT_CITIES))}), ", list(DEFAULT_CITIES)) if DEFAULT_CITIES
                               else (f"s.{C['province']}, ", []))
    with cursor() as cur:
        cur.execute(f"""SELECT {_select()}, s.{POI_INFO} AS poi_info
                        FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']} {where}
                        AND s.{POI_INFO} IS NOT NULL AND s.{POI_INFO} <> '[]'
                        ORDER BY {city_order}s.{C['city']}, {GRADE_ORDER}, s.{C['id']}""", params + city_params)
        rows = list(cur.fetchall())
        done = set()
        if not refresh:
            cur.execute(f"SELECT scenic_id, poi_id FROM {CRAWL_TABLE} WHERE status = 'done'")
            done = {(r["scenic_id"], str(r["poi_id"])) for r in cur.fetchall()}
    out = []
    for r in rows:
        for p in _parse_info(r.pop("poi_info")):
            if not str(p.get("poiId", "")).isdigit() or not p.get("poiUri"):
                continue
            if (r["id"], str(p["poiId"])) in done:
                continue
            out.append(dict(scenic=r, poi=p))
    return out


def crawl_get(sid, poi_id):
    with cursor() as cur:
        cur.execute(f"SELECT * FROM {CRAWL_TABLE} WHERE scenic_id=%s AND poi_id=%s", (sid, int(poi_id)))
        r = cur.fetchone()
    return _jsonable([r])[0] if r else None


def crawl_put(sid, poi_id, **kw):
    cols = ["poi_name", "poi_uri", "status", "pages_done", "total_count", "review_qty", "image_qty", "message"]
    vals = {k: kw[k] for k in cols if k in kw}
    if "message" in vals and vals["message"]:
        vals["message"] = str(vals["message"])[:500]
    names = ["scenic_id", "poi_id"] + list(vals)
    with cursor() as cur:
        cur.execute(f"""INSERT INTO {CRAWL_TABLE} ({','.join(names)}) VALUES ({','.join(['%s'] * len(names))})
                        ON DUPLICATE KEY UPDATE {', '.join(f'{k}=VALUES({k})' for k in vals) or 'scenic_id=scenic_id'}""",
                    [sid, int(poi_id)] + list(vals.values()))


IMAGE_COLS = ["poi_id", "poi_name", "scenic_id", "scenic_name", "image_url", "image_thumb_url", "lon", "lat", "province", "city",
              "district", "total_count", "comment_total", "review_id", "image_id", "width", "height", "review_score",
              "review_publish_time", "collect_time", "data_source", "is_modified"]


def images_insert(rows):
    """写入图片：先进工具自己的 scenic_poi_image（同一景区+POI+图片只存一条，生成 record_id = img_<采集日期>_<id 6位>），
    新增的再同步写进交付表 ods_prd_poi_image_di。返回新增条数。"""
    if not rows:
        return 0
    with cursor() as cur:
        n = cur.executemany(f"INSERT IGNORE INTO {IMAGE_TABLE} ({','.join(IMAGE_COLS)}) VALUES ({','.join(['%s'] * len(IMAGE_COLS))})",
                            [[r.get(c) for c in IMAGE_COLS] for r in rows])
        cur.execute(f"SELECT id FROM {IMAGE_TABLE} WHERE record_id IS NULL")
        new_ids = [r["id"] for r in cur.fetchall()]
        if new_ids:
            cur.execute(f"""UPDATE {IMAGE_TABLE} SET record_id = CONCAT('img_', DATE_FORMAT(collect_time, %s), '_', LPAD(id, 6, '0'))
                            WHERE record_id IS NULL""", ("%Y%m%d",))
    if new_ids:
        ods_sync(new_ids)
    return n or 0


_ods_warned = False


def ods_exists():
    with cursor() as cur:
        return table_exists(cur, ODS_TABLE)


def _ensure_partitions(cur, dates):
    """交付表按 travel_date RANGE 分区；写入日期 >= 现有最大上界时，按你的命名习惯 p<上界> 追加分区。"""
    name = ODS_TABLE.replace("`", "").split(".")
    schema, table = (name[0], name[1]) if len(name) == 2 else (DB["database"], name[0])
    cur.execute("""SELECT partition_name AS n, partition_description AS d FROM information_schema.partitions
                   WHERE table_schema=%s AND table_name=%s AND partition_name IS NOT NULL""", (schema, table))
    parts = list(cur.fetchall())
    if not parts or any(str(p["d"]).upper() == "MAXVALUE" for p in parts):
        return
    top = max(int(p["d"]) for p in parts)
    from datetime import datetime as _dt, timedelta as _td
    for d in sorted(set(dates)):
        if d < top:
            continue
        lt = int((_dt.strptime(str(d), "%Y%m%d") + _td(days=1)).strftime("%Y%m%d"))
        if not ODS_AUTO_PARTITION:
            raise RuntimeError(f"{ODS_TABLE} 没有 travel_date={d} 的分区（现有上界 {top}），请先 ADD PARTITION p{lt} VALUES LESS THAN ({lt})")
        cur.execute(f"ALTER TABLE {ODS_TABLE} ADD PARTITION (PARTITION p{lt} VALUES LESS THAN ({lt}))")
        print(f"已给 {ODS_TABLE} 追加分区 p{lt} VALUES LESS THAN ({lt})", flush=True)
        top = lt


def ods_sync(ids=None, batch=2000):
    """把 scenic_poi_image 的记录写进交付表（主键 record_id+travel_date，重复写会被忽略）。ids=None 表示全部（补写）。"""
    global _ods_warned
    import match
    if not ods_exists():
        if not _ods_warned:
            print(f"提示：交付表 {ODS_TABLE} 不存在，图片只写在 {IMAGE_TABLE}", flush=True)
            _ods_warned = True
        return 0
    cols = ["record_id", "poi_id", "poi_name", "scenic_id", "scenic_name", "image_url", "lon", "lat", "province", "city", "district",
            "total_count", "review_id", "image_id", "width", "height", "collect_time", "data_source", "is_modified", "travel_date"]
    written, offset, last = 0, 0, 0
    while True:
        with cursor() as cur:
            if ids is not None:
                chunk = ids[offset:offset + batch]
                offset += len(chunk)
                if not chunk:
                    break
                cur.execute(f"SELECT * FROM {IMAGE_TABLE} WHERE id IN ({','.join(['%s'] * len(chunk))}) AND record_id IS NOT NULL", chunk)
            else:
                cur.execute(f"SELECT * FROM {IMAGE_TABLE} WHERE id > %s AND record_id IS NOT NULL ORDER BY id LIMIT %s", (last, batch))
            rows = list(cur.fetchall())
            if not rows:
                if ids is None:
                    break
                continue
            last = rows[-1]["id"]
            out = []
            for r in rows:
                lon, lat = r["lon"], r["lat"]
                if ODS_COORD == "wgs84":
                    lon, lat = match.gcj02_to_wgs84(lon, lat)
                ct = r["collect_time"]
                out.append([r["record_id"], r["poi_id"], r["poi_name"] or "", r["scenic_id"], r["scenic_name"] or "", r["image_url"],
                            None if lon is None else round(lon, 6), None if lat is None else round(lat, 6),
                            r["province"], r["city"], r["district"], r["total_count"], r["review_id"], r["image_id"],
                            r["width"], r["height"], ct, r["data_source"], r["is_modified"], int(ct.strftime("%Y%m%d"))])
            _ensure_partitions(cur, [o[-1] for o in out])
            written += cur.executemany(f"INSERT IGNORE INTO {ODS_TABLE} ({','.join(cols)}) VALUES ({','.join(['%s'] * len(cols))})", out) or 0
    return written


def image_stats(f=None):
    """按城市：可采 POI 数 / 已采完 / 图片数。"""
    with cursor() as cur:
        cur.execute(f"""SELECT s.{C['city']} city, COUNT(DISTINCT i.poi_id) poi_qty, COUNT(*) image_qty
                        FROM {IMAGE_TABLE} i JOIN {SCENIC_TABLE} s ON s.{C['id']} = i.scenic_id GROUP BY 1""")
        imgs = {r["city"]: r for r in cur.fetchall()}
        cur.execute(f"""SELECT status, COUNT(*) n FROM {CRAWL_TABLE} GROUP BY status""")
        crawl = {r["status"]: r["n"] for r in cur.fetchall()}
        cur.execute(f"SELECT COUNT(*) n FROM {IMAGE_TABLE}")
        total = cur.fetchone()["n"]
    return dict(image_total=total, crawl=crawl, by_city=[dict(city=k, poi_qty=v["poi_qty"], image_qty=v["image_qty"]) for k, v in imgs.items()])


def images_query(scenic_id=None, poi_id=None, limit=50, offset=0):
    where, params = [], []
    if scenic_id:
        where.append("scenic_id=%s"); params.append(scenic_id)
    if poi_id:
        where.append("poi_id=%s"); params.append(int(poi_id))
    w = ("WHERE " + " AND ".join(where)) if where else ""
    with cursor() as cur:
        cur.execute(f"SELECT COUNT(*) n FROM {IMAGE_TABLE} {w}", params)
        total = cur.fetchone()["n"]
        cur.execute(f"""SELECT record_id, poi_id, poi_name, scenic_id, scenic_name, image_url, image_thumb_url, lon, lat, province, city,
                        district, total_count, comment_total, review_id, image_id, width, height, collect_time, data_source, is_modified
                        FROM {IMAGE_TABLE} {w} ORDER BY id LIMIT %s OFFSET %s""", params + [int(limit), int(offset)])
        rows = _jsonable(list(cur.fetchall()))
    return dict(total=total, items=rows)
