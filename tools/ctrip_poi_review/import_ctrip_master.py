"""把交付数据里的携程景区主档（dim.dim_prd_attraction_df.csv）导入 MySQL，用于给搜索结果补地址/等级。

用法：
    python import_ctrip_master.py dim.dim_prd_attraction_df.csv
连接配置与 review.py 相同（MYSQL_*，CTRIP_MASTER_TABLE）。会先清空主档表再导入。
两个交付包（规范命名版 / A·B 包）的主档字段名在这里用到的列上一致，都能直接导。
"""
import csv
import sys

import pymysql

import db

COLS = ["ctrip_poi_id", "ctrip_business_id", "attraction_name", "city_name", "district_name", "business_area_name",
        "attraction_address", "poi_type", "attraction_level", "gcj02_lng", "gcj02_lat", "ctrip_url"]


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    missing = [c for c in COLS if c not in rows[0]]
    if missing:
        sys.exit(f"CSV 缺少列: {missing}")
    data, seen = [], set()
    for r in rows:
        pid = (r["ctrip_poi_id"] or "").strip()
        if not pid or pid in seen:
            continue
        seen.add(pid)
        vals = [(r[c].strip() or None) if isinstance(r[c], str) else r[c] for c in COLS]
        vals[COLS.index("gcj02_lng")] = _num(r["gcj02_lng"])
        vals[COLS.index("gcj02_lat")] = _num(r["gcj02_lat"])
        data.append(vals)
    conn = pymysql.connect(**{**db.DB, "autocommit": False})
    with conn.cursor() as cur:
        cur.execute(db.MASTER_DDL.replace("DEFAULT CHARSET=utf8mb4", db.charset_clause(cur)))
        db.align_collation(cur, db.MASTER_TABLE, "ctrip_poi_id")
        cur.execute(f"DELETE FROM {db.MASTER_TABLE}")
        cur.executemany(f"INSERT INTO {db.MASTER_TABLE} ({','.join(COLS)}) VALUES ({','.join(['%s'] * len(COLS))})", data)
    conn.commit(); conn.close()
    print(f"导入 {len(data)} 行 -> {db.MASTER_TABLE}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
