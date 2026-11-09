"""把离线匹配得到的候选（CSV）导入 MySQL，供核对面板展示。

用法：
    python import_candidates.py scenic_ctrip_candidate.csv
连接配置与 review.py 相同（MYSQL_HOST/PORT/USER/PASSWORD/DB，CANDIDATE_TABLE）。
会先清空候选表再导入（核对结果在另一张表，不受影响）。
"""
import csv
import sys

import pymysql

import db

COLS = ["scenic_id", "scenic_name", "city_name", "relation_type", "confidence", "match_evidence", "triage_result",
        "ctrip_poi_id", "ctrip_business_id", "ctrip_poi_name", "ctrip_district_name", "dist_to_anchor_m",
        "image_qty", "ctrip_url", "also_in_scenic_ids"]
T = db.CANDIDATE_TABLE
DDL = f"""CREATE TABLE IF NOT EXISTS {T} (
  scenic_id VARCHAR(64) NOT NULL, scenic_name VARCHAR(255), city_name VARCHAR(64),
  relation_type VARCHAR(64), confidence VARCHAR(8), match_evidence VARCHAR(255), triage_result VARCHAR(16),
  ctrip_poi_id VARCHAR(32) NOT NULL, ctrip_business_id VARCHAR(32), ctrip_poi_name VARCHAR(255),
  ctrip_district_name VARCHAR(64), dist_to_anchor_m INT, image_qty INT, ctrip_url VARCHAR(512),
  also_in_scenic_ids VARCHAR(500),
  PRIMARY KEY (scenic_id, ctrip_poi_id), KEY idx_poi (ctrip_poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景区-携程POI 离线候选（规则匹配）'"""


def main(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    missing = [c for c in COLS if c not in rows[0]]
    if missing:
        sys.exit(f"CSV 缺少列: {missing}")
    data = [[(r[c] if r[c] != "" else None) for c in COLS] for r in rows]
    conn = pymysql.connect(**{**db.DB, "autocommit": False})
    with conn.cursor() as cur:
        cur.execute(DDL)
        cur.execute(f"DELETE FROM {T}")
        cur.executemany(f"INSERT INTO {T} ({','.join(COLS)}) VALUES ({','.join(['%s'] * len(COLS))})", data)
    conn.commit(); conn.close()
    print(f"导入 {len(data)} 行 -> {T}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
