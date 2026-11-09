"""携程 POI 人工核对 —— 本地后端（Flask + MySQL）

读取 MySQL 中的客户景区表，把人工在浏览器里确认的「景区 ↔ 携程 POI」结果写回 MySQL。
前端是 Tampermonkey 脚本 ctrip_poi_review.user.js（运行在携程页面上，负责实时搜索）。

配置全部走环境变量，见 README.md。
"""
import csv
import io
import json
import os
import re
from contextlib import contextmanager

import pymysql
from flask import Flask, Response, jsonify, request

# ---------------------------------------------------------------- config
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
IDENT = re.compile(r"^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)?$")


def ident(name):
    if not IDENT.match(name):
        raise ValueError(f"非法表名/字段名: {name}")
    return ".".join(f"`{p}`" for p in name.split("."))


SCENIC_TABLE = ident(ENV("SCENIC_TABLE", "pft_ai_dim_prd_scenic_base_yr_f"))
CANDIDATE_TABLE = ident(ENV("CANDIDATE_TABLE", "scenic_ctrip_candidate"))
REVIEW_TABLE = ident(ENV("REVIEW_TABLE", "scenic_ctrip_poi_review"))
STATUS_TABLE = ident(ENV("STATUS_TABLE", "scenic_ctrip_review_status"))
# 客户景区表字段映射：逻辑名 -> 实际字段名；可用 SCENIC_COLS='{"name":"xxx"}' 覆盖
COLS = {
    "id": "scenic_id", "name": "scenic_name", "alias": "scenic_alias",
    "province": "province_name", "city": "city_name", "district": "district_name",
    "address": "scenic_address", "lng": "scenic_lng", "lat": "scenic_lat",
    "grade": "scenic_grade_level", "core_spots": "scenic_core_spots",
}
COLS.update(json.loads(ENV("SCENIC_COLS", "{}")))
C = {k: ident(v) for k, v in COLS.items()}
# 只核对这些城市（逗号分隔，空=全部）。默认 7 城
DEFAULT_CITIES = [c for c in ENV("CITIES", "北京市,上海市,广州市,深圳市,杭州市,成都市,西安市").split(",") if c]

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
  source VARCHAR(16) NOT NULL COMMENT 'search=携程实时搜索 candidate=离线候选',
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
]

app = Flask(__name__)


@contextmanager
def cursor():
    conn = pymysql.connect(**DB)
    try:
        with conn.cursor() as cur:
            yield cur
    finally:
        conn.close()


def table_exists(cur, quoted):
    name = quoted.replace("`", "").split(".")[-1]
    cur.execute("SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=%s", (name,))
    return cur.fetchone() is not None


@app.after_request
def cors(resp):
    origin = request.headers.get("Origin", "")
    if re.match(r"^https?://([a-z0-9-]+\.)*ctrip\.com$", origin) or origin.startswith("http://127.0.0.1") or origin.startswith("http://localhost"):
        resp.headers["Access-Control-Allow-Origin"] = origin
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        resp.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
        resp.headers["Access-Control-Allow-Private-Network"] = "true"
    return resp


@app.route("/api/<path:_>", methods=["OPTIONS"])
def preflight(_):
    return ("", 204)


def scenic_filters(args):
    where, params = [], []
    cities = [c for c in args.get("city", "").split(",") if c] or DEFAULT_CITIES
    if cities:
        where.append(f"s.{C['city']} IN ({','.join(['%s'] * len(cities))})"); params += cities
    if args.get("province"):
        where.append(f"s.{C['province']} = %s"); params.append(args["province"])
    if args.get("grade"):
        g = [x for x in args["grade"].split(",") if x]
        where.append(f"s.{C['grade']} IN ({','.join(['%s'] * len(g))})"); params += g
    st = args.get("status", "todo")
    if st == "todo":
        where.append("st.status IS NULL")
    elif st in ("done", "skip"):
        where.append("st.status = %s"); params.append(st)
    if args.get("q"):
        where.append(f"(s.{C['name']} LIKE %s OR s.{C['alias']} LIKE %s OR s.{C['id']} = %s)")
        params += [f"%{args['q']}%", f"%{args['q']}%", args["q"]]
    return ("WHERE " + " AND ".join(where)) if where else "", params


def scenic_select():
    return ", ".join(f"s.{v} AS `{k}`" for k, v in C.items())


GRADE_ORDER = f"FIELD(s.{C['grade']},'5A','4A','3A','2A','1A')"


@app.get("/api/health")
def health():
    with cursor() as cur:
        cur.execute(f"SELECT COUNT(*) n FROM {SCENIC_TABLE}")
        n = cur.fetchone()["n"]
        return jsonify(ok=True, scenic_rows=n, candidate_table=table_exists(cur, CANDIDATE_TABLE), cities=DEFAULT_CITIES)


@app.get("/api/cities")
def cities():
    with cursor() as cur:
        cur.execute(f"""SELECT s.{C['province']} province, s.{C['city']} city, COUNT(*) n,
                        SUM(st.status IS NOT NULL) reviewed
                        FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']}
                        GROUP BY 1,2 ORDER BY n DESC""")
        return jsonify(list(cur.fetchall()))


@app.get("/api/scenic")
def scenic_list():
    where, params = scenic_filters(request.args)
    offset = max(int(request.args.get("offset", 0)), 0)
    limit = min(max(int(request.args.get("limit", 50)), 1), 500)
    base = f"FROM {SCENIC_TABLE} s LEFT JOIN {STATUS_TABLE} st ON st.scenic_id = s.{C['id']} {where}"
    with cursor() as cur:
        cur.execute(f"SELECT COUNT(*) n {base}", params)
        total = cur.fetchone()["n"]
        cur.execute(f"""SELECT {scenic_select()}, st.status, st.note,
                        (SELECT COUNT(*) FROM {REVIEW_TABLE} r WHERE r.scenic_id=s.{C['id']} AND r.decision='keep') kept_qty
                        {base} ORDER BY s.{C['city']}, {GRADE_ORDER}, s.{C['id']} LIMIT %s OFFSET %s""",
                    params + [limit, offset])
        return jsonify(total=total, offset=offset, items=list(cur.fetchall()))


@app.get("/api/scenic/<sid>")
def scenic_detail(sid):
    with cursor() as cur:
        cur.execute(f"SELECT {scenic_select()} FROM {SCENIC_TABLE} s WHERE s.{C['id']}=%s", (sid,))
        s = cur.fetchone()
        if not s:
            return jsonify(error="not found"), 404
        cur.execute(f"SELECT status, note, reviewer, updated_at FROM {STATUS_TABLE} WHERE scenic_id=%s", (sid,))
        st = cur.fetchone()
        cands = []
        if table_exists(cur, CANDIDATE_TABLE):
            cur.execute(f"SELECT * FROM {CANDIDATE_TABLE} WHERE scenic_id=%s ORDER BY FIELD(confidence,'高','中','低'), image_qty DESC", (sid,))
            cands = list(cur.fetchall())
        cur.execute(f"""SELECT ctrip_key, ctrip_poi_id, ctrip_business_id, ctrip_poi_name, ctrip_type, ctrip_url,
                        source, keyword, decision, reviewer, updated_at FROM {REVIEW_TABLE} WHERE scenic_id=%s""", (sid,))
        decs = list(cur.fetchall())
    for row in [st] + cands + decs:
        if row:
            for k, v in row.items():
                if hasattr(v, "isoformat"):
                    row[k] = v.isoformat(sep=" ")
    return jsonify(scenic=s, status=st, candidates=cands, decisions=decs)


def ctrip_key(d):
    if d.get("ctrip_poi_id"):
        return f"poi:{d['ctrip_poi_id']}"
    if d.get("ctrip_business_id"):
        return f"biz:{d['ctrip_business_id']}"
    raise ValueError("需要 ctrip_poi_id 或 ctrip_business_id")


@app.post("/api/decision")
def decision():
    d = request.get_json(force=True)
    if not d.get("scenic_id"):
        return jsonify(error="scenic_id 必填"), 400
    try:
        key = ctrip_key(d)
    except ValueError as e:
        return jsonify(error=str(e)), 400
    with cursor() as cur:
        if d.get("decision") in (None, "", "clear"):
            cur.execute(f"DELETE FROM {REVIEW_TABLE} WHERE scenic_id=%s AND ctrip_key=%s", (d["scenic_id"], key))
            return jsonify(ok=True, cleared=True, ctrip_key=key)
        if d["decision"] not in ("keep", "drop"):
            return jsonify(error="decision 只能是 keep/drop"), 400
        raw = d.get("raw_json")
        if raw is not None and not isinstance(raw, str):
            raw = json.dumps(raw, ensure_ascii=False)
        cols = ["scenic_id", "ctrip_key", "ctrip_poi_id", "ctrip_business_id", "ctrip_poi_name", "ctrip_type",
                "ctrip_city_name", "ctrip_district_name", "ctrip_lat", "ctrip_lng", "ctrip_url", "source",
                "keyword", "decision", "raw_json", "reviewer"]
        vals = [d["scenic_id"], key] + [d.get(c) for c in cols[2:14]] + [raw, d.get("reviewer")]
        vals = [None if v == "" else v for v in vals]
        upd = ", ".join(f"{c}=VALUES({c})" for c in cols[2:] if c not in ("source", "keyword") ) + \
            ", source=COALESCE(source, VALUES(source)), keyword=COALESCE(VALUES(keyword), keyword)"
        cur.execute(f"INSERT INTO {REVIEW_TABLE} ({','.join(cols)}) VALUES ({','.join(['%s'] * len(cols))}) "
                    f"ON DUPLICATE KEY UPDATE {upd}", vals)
    return jsonify(ok=True, ctrip_key=key)


@app.post("/api/status")
def status():
    d = request.get_json(force=True)
    if not d.get("scenic_id"):
        return jsonify(error="scenic_id 必填"), 400
    with cursor() as cur:
        if d.get("status") in (None, "", "todo"):
            cur.execute(f"DELETE FROM {STATUS_TABLE} WHERE scenic_id=%s", (d["scenic_id"],))
        elif d["status"] in ("done", "skip"):
            cur.execute(f"""INSERT INTO {STATUS_TABLE} (scenic_id, status, note, reviewer) VALUES (%s,%s,%s,%s)
                            ON DUPLICATE KEY UPDATE status=VALUES(status), note=VALUES(note), reviewer=VALUES(reviewer)""",
                        (d["scenic_id"], d["status"], d.get("note"), d.get("reviewer")))
        else:
            return jsonify(error="status 只能是 done/skip/todo"), 400
    return jsonify(ok=True)


@app.get("/api/export.csv")
def export():
    """最终结果：每个景区一行，ctrip_poi_id 列表（| 分隔），只含 decision=keep。"""
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
        rows = cur.fetchall()
    buf = io.StringIO()
    buf.write("﻿")
    w = csv.DictWriter(buf, fieldnames=["scenic_id", "scenic_name", "city_name", "status", "kept_qty",
                                        "ctrip_poi_id_list", "ctrip_business_id_list", "ctrip_poi_name_list"])
    w.writeheader(); w.writerows(rows)
    return Response(buf.getvalue(), mimetype="text/csv; charset=utf-8",
                    headers={"Content-Disposition": "attachment; filename=scenic_ctrip_poi_mapping.csv"})


def init_db():
    with cursor() as cur:
        for ddl in DDL:
            cur.execute(ddl)


if __name__ == "__main__":
    init_db()
    app.run(host=ENV("HOST", "127.0.0.1"), port=int(ENV("PORT", "8765")), debug=False)
