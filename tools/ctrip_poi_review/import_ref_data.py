"""参考资料入库：把 data/ 下生成训练数据用的参考资料建表并写进 MySQL（连接同工作台，MYSQL_* 环境变量）。

  cs     客服对话包 data/cs_package/：
           dim_prd_attraction_df              七城携程景点主档（一行一个景点）
           dwd_cus_service_dialogue_df        文旅客服对话（一行一通）
           dwd_cus_service_dialogue_turn_df   文旅客服对话逐轮（一行一句）
         字段、注释照数据包自带的 03_建表DDL.sql（Hive）转成 MySQL，分区字段 travel_date 变成普通列并进主键。
  guide  景区讲解包 data/guide/*/data_all/ 六表 dwd_prd_scenic_guide_{source,content,fact,content_source_rel,fact_source_rel,collect_task}_di
         表结构与讲解包自带的 data_2_database.py 的要求完全一致（建好后也能用它导入），数据用它的读取 / 校验逻辑。
  redqa  RedAttractionQA data/redqa/：dwd_ref_red_attraction_qa_df（train / validation / test 都入，split_type 区分）
  woz    RiSAWOZ / CrossWOZ 景点对话 data/woz/：dwd_ref_woz_dialogue_df（一行一通）+ dwd_ref_woz_dialogue_turn_df（一行一句）

客户景区表 pft_ai_dim_prd_scenic_base_yr_f 不在这里，用 python import_scenic.py。

用法（在 tools/ctrip_poi_review 目录下）：
  python import_ref_data.py --dry-run           只读文件、校验、报条数，不连库
  python import_ref_data.py --print-ddl         打印建表语句（也存在 schema_ref.sql）
  python import_ref_data.py                     全部：建表（已有不动）+ 写入，同主键的更新，可重复跑
  python import_ref_data.py --only cs,woz       只导这几组
  python import_ref_data.py --replace           覆盖：先删掉本次文件涉及的那批（同 travel_date / 同采集批次 / 同 split / 同数据集）再写，
                                                文件里删掉的行库里也会没；不影响别的批次

每张表一个事务，写完按批次核对库里条数和文件一致，不一致回滚。
"""
import argparse
import csv
import importlib.util
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
csv.field_size_limit(sys.maxsize)
GROUPS = ("cs", "guide", "redqa", "woz")


class Table:
    """一张表：建表语句 + 列 + 主键 + 行 + 覆盖范围（--replace 时先删哪些）。"""

    def __init__(self, name, comment, cols, pk, rows, scope_cols, extra_ddl=()):
        self.name, self.comment, self.cols, self.pk, self.rows = name, comment, cols, pk, rows
        self.scope_cols = scope_cols  # 按这些列的取值划分批次：--replace 删除 / 写完核对条数
        self.extra_ddl = list(extra_ddl or [])  # 额外的列（入库时间）、索引、CHECK：一项一行，不带逗号
        self.names = [c[0] for c in cols]

    def ddl(self, table_opts="DEFAULT CHARSET=utf8mb4"):
        lines = [f"  `{n}` {t}" + (f" COMMENT '{_q(c)}'" if c else "") for n, t, c in self.cols]
        lines += [f"  {x}" for x in self.extra_ddl]
        lines.append(f"  PRIMARY KEY ({', '.join(f'`{x}`' for x in self.pk)})")
        return f"CREATE TABLE IF NOT EXISTS `{self.name}` (\n" + ",\n".join(lines) + f"\n) ENGINE=InnoDB {table_opts} COMMENT='{_q(self.comment)}'"

    def scopes(self):
        return Counter(tuple(r[c] for c in self.scope_cols) for r in self.rows)


def _q(s):
    return str(s).replace("\\", "\\\\").replace("'", "''")


def _vlen(t):
    m = re.match(r"VARCHAR\((\d+)\)", t)
    return int(m.group(1)) if m else None


def _read_csv(p):
    with open(p, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


# ---------------------------------------------------------------- cs：客服对话包（Hive DDL → MySQL）
CS_FILES = {"dim_prd_attraction_df": "dim.dim_prd_attraction_df.csv", "dwd_cus_service_dialogue_df": "dwd.dwd_cus_service_dialogue_df.csv",
            "dwd_cus_service_dialogue_turn_df": "dwd.dwd_cus_service_dialogue_turn_df.csv"}
CS_PK = {"dim_prd_attraction_df": ("ctrip_poi_id", "travel_date"), "dwd_cus_service_dialogue_df": ("dialogue_id", "travel_date"),
         "dwd_cus_service_dialogue_turn_df": ("dialogue_id", "turn_seq", "travel_date")}
CS_INDEX = {"dim_prd_attraction_df": ["KEY `idx_business` (`ctrip_business_id`)", "KEY `idx_city` (`city_name`)"],
            "dwd_cus_service_dialogue_df": ["KEY `idx_attraction` (`attraction_id`)", "KEY `idx_type` (`data_type`, `dataset_split_type`)"],
            "dwd_cus_service_dialogue_turn_df": []}
INGEST = "`ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间'"
CS_TEXT = {"ticket_desc", "open_time_recent_desc", "open_time_detail_desc", "attraction_brief_desc", "first_question_content", "first_answer_content",
           "turn_content", "tool_args_content"}
CS_MEDIUM = {"dialogue_content"}
CS_KEYS = {"ctrip_poi_id", "ctrip_business_id", "dialogue_id", "attraction_id"}


def _cs_type(col, hive):
    if hive == "INT":
        return "INT NULL"
    if col in CS_MEDIUM:
        return "MEDIUMTEXT NULL"
    if col in CS_TEXT:
        return "TEXT NULL"
    if col in CS_KEYS:
        return "VARCHAR(64) NULL"
    if col.endswith("_url"):
        return "VARCHAR(1024) NULL"
    if col in ("knowledge_ref_codes", "attraction_address", "tag_names", "rank_list_name", "feature_desc", "contact_phone"):
        return "VARCHAR(500) NULL"
    return "VARCHAR(255) NULL"


def parse_hive_ddl(path):
    """03_建表DDL.sql → {表名: (表注释, [(列, Hive类型, 注释)], 分区列注释)}。"""
    out = {}
    text = Path(path).read_text(encoding="utf-8")
    for m in re.finditer(r"CREATE TABLE IF NOT EXISTS \w+\.(\w+) \((.*?)\n\) COMMENT '([^']*)'\s*PARTITIONED BY \(`(\w+)` \w+ COMMENT '([^']*)'\)", text, re.S):
        cols = re.findall(r"`(\w+)` (\w+) COMMENT '([^']*)'", m.group(2))
        out[m.group(1)] = (m.group(3), cols, (m.group(4), m.group(5)))
    return out


def load_cs(data_dir):
    d = Path(data_dir) / "cs_package"
    hive = parse_hive_ddl(d / "03_建表DDL.sql")
    tables = []
    for name, fn in CS_FILES.items():
        comment, cols, (pcol, pcomment) = hive[name]
        raw = _read_csv(d / fn)
        mcols = [(c, _cs_type(c, t), cm) for c, t, cm in cols] + [(pcol, "INT NOT NULL", pcomment)]
        mcols = [(c, re.sub(r"(?<!NOT) NULL$", " NOT NULL", t) if c in CS_PK[name] else t, cm) for c, t, cm in mcols]
        miss = [c for c, _, _ in mcols if raw and c not in raw[0]]
        if miss:
            raise SystemExit(f"{fn} 缺少列 {miss}")
        ints = {c for c, t, _ in mcols if t.startswith("INT")}
        rows = []
        for i, r in enumerate(raw, 2):
            row = {}
            for c, t, _ in mcols:
                v = (r.get(c) or "").strip() if c in ints or c in CS_PK[name] else r.get(c)
                if v in ("", None):
                    if c in CS_PK[name]:
                        raise SystemExit(f"{fn} 第 {i} 行 {c} 为空（主键不能为空）")
                    row[c] = None  # 空串存 NULL（Hive 里的「空」）
                elif c in ints:
                    if not re.fullmatch(r"-?\d+", v):
                        raise SystemExit(f"{fn} 第 {i} 行 {c}={v!r} 不是整数")
                    row[c] = int(v)
                else:
                    row[c] = v
            rows.append(row)
        tables.append(Table(name, comment, mcols, CS_PK[name], rows, ("travel_date",), [INGEST] + CS_INDEX[name]))
    return tables


# ---------------------------------------------------------------- guide：讲解包六表（结构 = data_2_database.py 的要求）
GUIDE_COMMENT = {
    "source": "景区讲解来源页面（一行一个来源网页）", "content": "景区讲解正文（一行一条讲解）", "fact": "讲解事实（一条讲解拆出的属性-值）",
    "content_source_rel": "讲解正文-来源关联", "fact_source_rel": "讲解事实-来源关联", "collect_task": "讲解采集任务（一行一个景区一个批次）",
}
GUIDE_COL_COMMENT = {
    "collect_batch_id": "采集批次", "source_id": "来源ID", "content_id": "讲解ID", "fact_seq_no": "事实序号（从1开始）", "scenic_id": "客户景区ID",
    "source_type": "来源类型：1-景区运营官网 2-政府 3-博物馆文物机构 4-UNESCO 5-其他可靠机构媒体学术 6-OTA平台 7-旅游社区 8-公开公众号文章 9-公开音视频讲解文字",
    "original_content_type": "原文摘录类型：0-无摘录 1-景点文物介绍短摘录 2-真实公开讲解词短摘录 3-真实字幕转写短摘录",
    "guide_content_type": "讲解正文类型：1-依据公开资料整理", "guide_content_text": "讲解正文", "fact_attr_name": "事实属性", "fact_attr_value": "事实值",
    "collect_time": "采集时间（UTC）", "travel_date": "数据日期 YYYYMMDD", "ingest_time": "入库时间",
}
GUIDE_VARCHAR = {"source_url": 2048, "source_title_name": 500, "source_publisher_name": 255, "guide_topic_name": 255, "guide_title_name": 500}


def _guide_module(pkg_dir):
    p = Path(pkg_dir) / "data_2_database.py"
    spec = importlib.util.spec_from_file_location("guide_data_2_database", p)
    m = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = m  # dataclass 需要模块已注册
    spec.loader.exec_module(m)
    return m


def guide_dir(data_dir):
    ds = sorted((Path(data_dir) / "guide").glob("*/data_all"))
    if not ds:
        raise SystemExit(f"{data_dir}/guide 下没有 */data_all 目录")
    return ds[-1]


def load_guide(data_dir):
    d = guide_dir(data_dir)
    g = _guide_module(d.parent)
    data = g.load_csvs(d)  # 讲解包自己的读取 + 类型转换 + 关联校验
    tables = []
    for s in g.SPECS:
        entity = s.name[len(g.PREFIX):-3]
        cols, checks = [], []
        for c in s.columns:
            t = g.expected_sql_type(c)
            if t == "tinyint":
                typ = "TINYINT UNSIGNED"
                checks.append(f"CONSTRAINT `ck_guide_{entity}_{c}` CHECK (`{c}` IN ({','.join(map(str, sorted(g.ENUMS[c])))}))")
            elif t == "int":
                typ = "INT UNSIGNED"
            elif t == "datetime":
                typ = "DATETIME(3)"
            elif t in ("date", "text", "mediumtext"):
                typ = t.upper()
            else:
                typ = f"VARCHAR({GUIDE_VARCHAR.get(c, 64 if c.endswith('_id') else 255)})"
            cols.append((c, typ + (" NULL" if c in g.NULLABLE else " NOT NULL"), GUIDE_COL_COMMENT.get(c, "")))
        extra = ["`ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间'"] + checks
        tables.append(Table(s.name, GUIDE_COMMENT.get(entity, s.name), cols, s.primary_key, data[s.name], ("collect_batch_id", "travel_date"), extra))
    return tables


# ---------------------------------------------------------------- redqa / woz
def load_redqa(data_dir):
    rows = []
    for p in sorted((Path(data_dir) / "redqa").glob("RedAttractionQA_*.json")):
        split = p.stem.split("_", 1)[1]
        t = p.read_text(encoding="utf-8").strip()
        try:
            items = json.loads(t)
        except ValueError:
            items = [json.loads(x) for x in t.splitlines() if x.strip()]
        for i, x in enumerate(items):
            ps = x.get("passages") or []
            p0 = ps[0] if ps else {}
            # qa_id 和生成数据 source 里引用的一致（cs_sources：RedAttractionQA:train:<序号>）
            rows.append(dict(qa_id=f"RedAttractionQA:{split}:{i}", split_type=split, item_seq=i, question_content=x.get("q") or "",
                             answer_content=p0.get("answer"), passage_content=p0.get("passage"), passage_qty=len(ps),
                             passages_json=json.dumps(ps, ensure_ascii=False) if len(ps) > 1 else None, source_file_name=p.name))
    cols = [("qa_id", "VARCHAR(64) NOT NULL", "问答ID：RedAttractionQA:<split>:<序号>，与生成数据 source 里的引用一致"),
            ("split_type", "VARCHAR(16) NOT NULL", "数据集划分：train / validation / test（生成只用 train）"), ("item_seq", "INT NOT NULL", "文件内序号（从0开始）"),
            ("question_content", "TEXT NOT NULL", "问题"), ("answer_content", "TEXT NULL", "答案"), ("passage_content", "TEXT NULL", "段落（第一段）"),
            ("passage_qty", "INT NOT NULL", "段落数"), ("passages_json", "MEDIUMTEXT NULL", "多段时的全部段落 JSON（只有一段时为空）"),
            ("source_file_name", "VARCHAR(128) NOT NULL", "来源文件")]
    return [Table("dwd_ref_red_attraction_qa_df", "RedAttractionQA 红色景点阅读理解问答（公开研究数据集，景点讲解事实 / 问法参考）", cols, ("qa_id",), rows,
                  ("split_type",), [INGEST, "KEY `idx_split` (`split_type`, `item_seq`)"])]


def load_woz(data_dir):
    dl, tl = [], []
    for p in sorted((Path(data_dir) / "woz").glob("*.jsonl")):
        with p.open(encoding="utf-8") as fh:
            for line in fh:
                if not line.strip():
                    continue
                x = json.loads(line)
                turns = x.get("turns") or []
                dl.append(dict(dialogue_id=x["id"], dataset_name=x.get("dataset") or "", turn_qty=len(turns), attraction_names="|".join(x.get("names") or []) or None,
                               topic_names="|".join(x.get("topics") or []) or None,
                               first_question_content=next((t["text"] for t in turns if t.get("role") == "游客"), None),
                               dialogue_content="\n".join(f"{t.get('role')}：{t.get('text')}" for t in turns), source_file_name=p.name))
                tl += [dict(dialogue_id=x["id"], dataset_name=x.get("dataset") or "", turn_seq=i, role_type=t.get("role"), turn_content=t.get("text") or "")
                       for i, t in enumerate(turns, 1)]
    dcols = [("dialogue_id", "VARCHAR(128) NOT NULL", "对话ID：<数据集>:<原ID>，与生成数据 source.style_refs 里的一致"),
             ("dataset_name", "VARCHAR(32) NOT NULL", "数据集：RiSAWOZ（苏州）/ CrossWOZ（北京），均取 train 的景点领域"), ("turn_qty", "INT NOT NULL", "发言条数"),
             ("attraction_names", "VARCHAR(1000) NULL", "对话里的景点名，多值用|分隔"),
             ("topic_names", "VARCHAR(255) NULL", "话题：ticket-门票 hours-开放时间 traffic-交通 plan-游玩建议 等，多值用|分隔"),
             ("first_question_content", "TEXT NULL", "游客首问"), ("dialogue_content", "MEDIUMTEXT NOT NULL", "对话全文（角色：内容，一行一句）"),
             ("source_file_name", "VARCHAR(128) NOT NULL", "来源文件")]
    tcols = [("dialogue_id", "VARCHAR(128) NOT NULL", "对话ID，对应 dwd_ref_woz_dialogue_df.dialogue_id"), ("dataset_name", "VARCHAR(32) NOT NULL", "数据集"),
             ("turn_seq", "INT NOT NULL", "发言序号（从1开始）"), ("role_type", "VARCHAR(16) NULL", "角色：游客 / 客服"), ("turn_content", "TEXT NOT NULL", "发言内容")]
    return [Table("dwd_ref_woz_dialogue_df", "RiSAWOZ / CrossWOZ 景点领域对话（公开研究数据集，问法参考，一行一通）", dcols, ("dialogue_id",), dl, ("dataset_name",),
                  [INGEST, "KEY `idx_dataset` (`dataset_name`)"]),
            Table("dwd_ref_woz_dialogue_turn_df", "RiSAWOZ / CrossWOZ 景点领域对话逐轮（一行一句）", tcols, ("dialogue_id", "turn_seq"), tl, ("dataset_name",), [INGEST])]


LOADERS = dict(cs=load_cs, guide=load_guide, redqa=load_redqa, woz=load_woz)


def check_rows(t):
    """主键不重复、必填不为空、VARCHAR 不超长（不靠数据库截断）。"""
    seen = Counter(tuple(r[c] for c in t.pk) for r in t.rows)
    dup = [k for k, n in seen.items() if n > 1]
    if dup:
        raise SystemExit(f"{t.name}：主键重复 {len(dup)} 个，如 {dup[:3]}")
    for c, typ, _ in t.cols:
        n = _vlen(typ)
        for r in t.rows:
            v = r.get(c)
            if v is None and "NOT NULL" in typ:
                raise SystemExit(f"{t.name}.{c} 不能为空：{[r[k] for k in t.pk]}")
            if n and isinstance(v, str) and len(v) > n:
                raise SystemExit(f"{t.name}.{c} 超长（{len(v)} > {n}）：{[r[k] for k in t.pk]}")


# ---------------------------------------------------------------- 写库
def table_opts(cur):
    """utf8mb4；客户景区表也是 utf8mb4 时排序规则跟它一致（关联查询不报 Illegal mix of collations）。"""
    import db
    try:
        cs, co = db.scenic_charset(cur)
    except Exception:  # noqa: BLE001  景区表不存在等
        cs, co = None, None
    return "DEFAULT CHARSET=utf8mb4" + (f" COLLATE={co}" if cs == "utf8mb4" and co else "")


def existing_cols(cur, name):
    import db
    cur.execute("SELECT COLUMN_NAME c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s", (db.DB["database"], name))
    return {r["c"] for r in cur.fetchall()}


def write(conn, t, replace, batch, log):
    names = ", ".join(f"`{c}`" for c in t.names)
    upd = ", ".join(f"`{c}`=VALUES(`{c}`)" for c in t.names if c not in t.pk)
    sql = f"INSERT INTO `{t.name}` ({names}) VALUES ({', '.join(['%s'] * len(t.names))})" + (f" ON DUPLICATE KEY UPDATE {upd}" if upd else "")
    scopes = t.scopes()
    swhere = " AND ".join(f"`{c}` = %s" for c in t.scope_cols)
    try:
        with conn.cursor() as cur:
            cur.execute(t.ddl(table_opts(cur)))
            have = existing_cols(cur, t.name)
            if have and not set(t.names) <= have:
                raise SystemExit(f"库里已有 {t.name}，但缺少列 {sorted(set(t.names) - have)}；先核对表结构（SHOW CREATE TABLE），不要直接删表")
            if replace:
                gone = 0
                for sc in scopes:
                    gone += cur.execute(f"DELETE FROM `{t.name}` WHERE {swhere}", list(sc)) or 0
                log(f"  {t.name}：覆盖模式，先删掉同批次 {gone:,} 行")
            for i in range(0, len(t.rows), batch):
                cur.executemany(sql, [[r[c] for c in t.names] for r in t.rows[i:i + batch]])
            bad = []
            for sc, n in scopes.items():
                cur.execute(f"SELECT COUNT(*) n FROM `{t.name}` WHERE {swhere}", list(sc))
                got = cur.fetchone()["n"]
                if got != n and (replace or got < n):  # 追加模式库里可以比文件多（以前导过、文件后来删了行）
                    bad.append(f"{dict(zip(t.scope_cols, sc))} 库里 {got} / 文件 {n}")
            if bad:
                raise RuntimeError("写完核对条数不一致：" + "；".join(bad))
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    log(f"  {t.name}：写入 {len(t.rows):,} 行（{', '.join(f'{dict(zip(t.scope_cols, k))}={v:,}' for k, v in scopes.items())}）")


def main(argv=None):
    ap = argparse.ArgumentParser(description="参考资料（客服对话包 / 讲解包 / RedAttractionQA / RiSAWOZ+CrossWOZ）建表入库")
    ap.add_argument("--data-dir", default=str(DATA), help="参考资料目录，默认仓库里的 data/")
    ap.add_argument("--only", default="", help=f"只导这几组，逗号分隔：{','.join(GROUPS)}（默认全部）")
    ap.add_argument("--dry-run", action="store_true", help="只读文件、校验、报条数，不连库")
    ap.add_argument("--print-ddl", action="store_true", help="打印建表语句后退出")
    ap.add_argument("--replace", action="store_true", help="先删掉本次文件涉及的批次再写（文件里删掉的行库里也删）")
    ap.add_argument("--batch", type=int, default=1000)
    a = ap.parse_args(argv)
    groups = [x.strip() for x in a.only.split(",") if x.strip()] or list(GROUPS)
    bad = [x for x in groups if x not in GROUPS]
    if bad:
        ap.error(f"--only 只能是 {GROUPS}，不认识 {bad}")
    log = lambda s: print(s, flush=True)  # noqa: E731
    tables = []
    for gname in groups:
        ts = LOADERS[gname](a.data_dir)
        for t in ts:
            check_rows(t)
        tables += ts
        if not a.print_ddl:
            log(f"[{gname}] 文件校验通过：" + "，".join(f"{t.name} {len(t.rows):,} 行" for t in ts))
    if a.print_ddl:
        print(";\n\n".join(t.ddl() for t in tables) + ";")
        return 0
    if a.dry_run:
        log("dry-run：没有连库")
        return 0
    import pymysql
    import db
    log(f"连接 {db.DB['user']}@{db.DB['host']}:{db.DB['port']}/{db.DB['database']}")
    conn = pymysql.connect(**{**db.DB, "autocommit": False})
    t0 = time.time()
    try:
        for t in tables:
            write(conn, t, a.replace, a.batch, log)
    finally:
        conn.close()
    log(f"完成：{len(tables)} 张表，{sum(len(t.rows) for t in tables):,} 行，用时 {time.time() - t0:.0f} 秒")
    return 0


if __name__ == "__main__":
    sys.exit(main())
