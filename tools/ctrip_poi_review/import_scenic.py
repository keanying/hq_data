"""把仓库里带的客户景区表 CSV（data/scenic/pft_ai_dim_prd_scenic_base_yr_f.csv）导进 MySQL。用于新环境 / 空库。

    python import_scenic.py                 # 表不存在就建表，然后只插入表里还没有的景区（按 scenic_id）
    python import_scenic.py --dry-run       # 只看会插入多少条

已有的景区一行都不改（核对结果 approval / ctrip_poi_info 等不会被覆盖）。表名用环境变量 SCENIC_TABLE（默认 pft_ai_dim_prd_scenic_base_yr_f），
连接参数同工作台（MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD / MYSQL_DB）。导入后启动工作台会自动补上核对用的字段。
"""
import argparse
import csv
from pathlib import Path

import db

HERE = Path(__file__).resolve().parent
DEFAULT_CSV = HERE / "data" / "scenic" / "pft_ai_dim_prd_scenic_base_yr_f.csv"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", default=str(DEFAULT_CSV), help="景区表 CSV，默认仓库里的 data/scenic/…")
    ap.add_argument("--dry-run", action="store_true", help="只统计，不写库")
    args = ap.parse_args()
    with open(args.csv, encoding="utf-8-sig", newline="") as fh:
        rd = csv.DictReader(fh)
        cols = [c for c in rd.fieldnames if c]
        rows = list(rd)
    id_col = db.COLS["id"]
    if id_col not in cols:
        raise SystemExit(f"CSV 里没有 {id_col} 列")
    with db.cursor() as cur:
        exists = db.table_exists(cur, db.SCENIC_TABLE)
        have = set()
        if exists:
            cur.execute(f"SELECT {db.ident(id_col)} id FROM {db.SCENIC_TABLE}")
            have = {str(r["id"]) for r in cur.fetchall()}
        todo = [r for r in rows if r[id_col] and r[id_col] not in have]
        print(f"CSV {len(rows)} 个景区；表{'已存在，已有 ' + str(len(have)) + ' 个' if exists else '不存在，会新建'}；要插入 {len(todo)} 个")
        if args.dry_run or not todo:
            return 0
        if not exists:
            defs = ",\n  ".join(f"{db.ident(c)} {'VARCHAR(64) NOT NULL' if c == id_col else 'TEXT NULL'}" for c in cols)
            cur.execute(f"CREATE TABLE {db.SCENIC_TABLE} (\n  {defs},\n  PRIMARY KEY ({db.ident(id_col)})\n) DEFAULT CHARSET=utf8mb4 COMMENT='客户景区表'")
        else:
            cur.execute(f"SHOW COLUMNS FROM {db.SCENIC_TABLE}")
            table_cols = {r["Field"] for r in cur.fetchall()}
            cols = [c for c in cols if c in table_cols]
        sql = f"INSERT IGNORE INTO {db.SCENIC_TABLE} ({', '.join(db.ident(c) for c in cols)}) VALUES ({', '.join(['%s'] * len(cols))})"
        for i in range(0, len(todo), 1000):
            cur.executemany(sql, [[(r.get(c) if r.get(c) not in ("", None) else None) for c in cols] for r in todo[i:i + 1000]])
        print(f"已插入 {len(todo)} 个景区到 {db.SCENIC_TABLE.strip('`')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
