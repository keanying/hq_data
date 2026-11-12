#!/usr/bin/env python3
"""将景区讲解六表CSV导入MySQL 8.0.16+（Python 3.10+）。

输入：前面交付的六表落表CSV，不是全量元数据CSV或原始宽表CSV。
默认重复主键报错且整批回滚；--on-duplicate update显式启用更新。
所有SQL表名包含库名；密码读取MYSQL_PASSWORD或交互式隐藏输入。
"""
from __future__ import annotations

import argparse
import csv
import getpass
import os
import re
import ssl
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

PREFIX = "dwd_prd_scenic_guide_"

@dataclass(frozen=True)
class TableSpec:
    name: str
    columns: tuple[str, ...]
    primary_key: tuple[str, ...]


def spec(entity: str, columns: str, primary: str) -> TableSpec:
    return TableSpec(PREFIX + entity + "_di", tuple(columns.split()), tuple(primary.split()))


# 写入顺序：来源 -> 内容 -> 事实 -> 内容来源关联 -> 事实来源关联 -> 任务。
# ingest_time不从CSV读取，由MySQL默认值生成真实入库时间。
SPECS = (
    spec("source", "collect_batch_id source_id scenic_id scenic_name source_url source_title_name source_publisher_name source_type source_publish_date collect_time source_access_type source_evidence_flag travel_date", "collect_batch_id source_id travel_date"),
    spec("content", "collect_batch_id content_id scenic_id scenic_name province_name city_name district_name attraction_name attraction_relation_type poi_id poi_name poi_namespace_type poi_match_status guide_topic_name guide_title_name guide_content_text guide_content_type original_excerpt_text original_content_type excerpt_source_id guide_fact_qty scope_desc note_desc copyright_auth_status copyright_auth_desc collect_time travel_date", "collect_batch_id content_id travel_date"),
    spec("fact", "collect_batch_id content_id fact_seq_no scenic_id scenic_name attraction_name fact_attr_name fact_attr_value travel_date", "collect_batch_id content_id fact_seq_no travel_date"),
    spec("content_source_rel", "collect_batch_id content_id source_id scenic_id excerpt_source_flag travel_date", "collect_batch_id content_id source_id travel_date"),
    spec("fact_source_rel", "collect_batch_id content_id fact_seq_no source_id scenic_id travel_date", "collect_batch_id content_id fact_seq_no source_id travel_date"),
    spec("collect_task", "collect_batch_id scenic_id scenic_name province_name city_name district_name collect_status guide_content_qty source_page_qty guide_fact_qty note_desc travel_date", "collect_batch_id scenic_id travel_date"),
)
BY_NAME = {s.name: s for s in SPECS}
NULLABLE = {
    "province_name", "city_name", "district_name", "poi_id", "poi_name",
    "original_excerpt_text", "excerpt_source_id", "scope_desc", "note_desc",
    "copyright_auth_desc", "source_publish_date",
}
INTEGERS = {
    "attraction_relation_type", "poi_namespace_type", "poi_match_status",
    "guide_content_type", "original_content_type", "guide_fact_qty",
    "copyright_auth_status", "travel_date", "fact_seq_no", "source_type",
    "source_access_type", "source_evidence_flag", "excerpt_source_flag",
    "collect_status", "guide_content_qty", "source_page_qty",
}
ENUMS = {
    "attraction_relation_type": {1, 2, 3}, "poi_namespace_type": {0, 1, 2, 3},
    "poi_match_status": {0, 1, 2}, "guide_content_type": {1, 2, 3},
    "original_content_type": {0, 1, 2, 3}, "copyright_auth_status": {0, 1, 2, 3},
    "source_type": {1, 2, 3, 4, 5, 6, 7, 8, 9}, "source_access_type": {1, 2, 3, 4},
    "source_evidence_flag": {0, 1}, "excerpt_source_flag": {0, 1},
    "collect_status": {0, 1, 2, 3, 4},
}


class ValidationError(ValueError):
    """数据或目标表结构与导入约定不一致。"""


class CommitOutcomeUnknown(RuntimeError):
    """仅在COMMIT请求异常时提示可能已提交。"""


def identifier(value: str) -> str:
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", value):
        raise ValidationError("库名只能包含英文字母、数字和下划线，且不能以数字开头")
    return value


def qualified(database: str, table: str) -> str:
    identifier(database)
    if table not in BY_NAME:
        raise ValidationError("不允许写入六表白名单以外的表")
    return f"`{database}`.`{table}`"


def key(row: dict[str, Any], *fields: str) -> tuple:
    return tuple(row[f] for f in fields)


def convert(column: str, raw: str) -> Any:
    if raw is None:
        raise ValidationError(f"{column}缺少单元格值")
    stripped = raw.strip()
    if not stripped:
        if column in NULLABLE:
            return None
        raise ValidationError(f"必填字段{column}为空")
    if column in INTEGERS:
        if not re.fullmatch(r"\d+", stripped):
            raise ValidationError(f"{column}必须为非负整数，不能为中文状态或小数")
        number = int(stripped)
        maximum = 255 if column in ENUMS else 4294967295
        if number > maximum:
            raise ValidationError(f"{column}超出数据库字段范围")
        if column in ENUMS and number not in ENUMS[column]:
            extra = "；平台类型须与数据库CHECK约束一致" if column == "source_type" else ""
            raise ValidationError(f"{column}枚举值不在{sorted(ENUMS[column])}内{extra}")
        if column == "fact_seq_no" and number < 1:
            raise ValidationError("fact_seq_no必须从1开始")
        if column == "travel_date":
            if not re.fullmatch(r"\d{8}", stripped):
                raise ValidationError("travel_date必须为YYYYMMDD的8位数字")
            datetime.strptime(stripped, "%Y%m%d")
        return number
    if column == "source_publish_date":
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", stripped):
            raise ValidationError("source_publish_date必须为YYYY-MM-DD或空值")
        parsed = date.fromisoformat(stripped)
        if parsed.year < 1000:
            raise ValidationError("发布日期不在MySQL DATE有效范围内")
        return parsed
    if column == "collect_time":
        parsed = datetime.fromisoformat(stripped.replace("Z", "+00:00"))
        if parsed.tzinfo is not None:
            parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
        # 无时区CSV按此前约定视为UTC；拒绝静默丢失超过毫秒的精度。
        if parsed.year < 1000 or parsed.microsecond % 1000:
            raise ValidationError("collect_time须在MySQL有效范围内且最多保留毫秒精度")
        return parsed
    if column.endswith("_id"):
        return stripped
    # 正文、标题和摘录保留原始内容，包括单元格内的换行。
    return raw


def load_csvs(directory: Path) -> dict[str, list[dict[str, Any]]]:
    csv.field_size_limit(32 * 1024 * 1024)
    tables: dict[str, list[dict[str, Any]]] = {}
    for s in SPECS:
        path = directory / (s.name + ".csv")
        if not path.is_file():
            raise ValidationError(f"缺少{path.name}；请解压六表落表演示包，而非使用元数据或原始宽表CSV")
        rows = []
        seen = set()
        with path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            header = reader.fieldnames or []
            if len(header) != len(set(header)) or set(header) != set(s.columns):
                missing = sorted(set(s.columns) - set(header))
                extra = sorted(set(header) - set(s.columns))
                raise ValidationError(f"{path.name}表头不匹配：缺少{missing}，多出{extra}")
            for record_no, raw in enumerate(reader, 1):
                if None in raw:
                    raise ValidationError(f"{path.name}第{record_no}条记录列数超出表头；检查CSV引号")
                try:
                    row = {c: convert(c, raw[c]) for c in s.columns}
                except (ValueError, TypeError) as exc:
                    raise ValidationError(f"{path.name}第{record_no}条记录：{exc}") from None
                pk = key(row, *s.primary_key)
                if pk in seen:
                    raise ValidationError(f"{path.name}内存在重复主键，记录号{record_no}")
                seen.add(pk)
                rows.append(row)
        tables[s.name] = rows
    if not any(tables.values()):
        raise ValidationError("六份CSV均无数据，拒绝空导入")
    validate_relations(tables)
    return tables


def validate_relations(tables: dict[str, list[dict[str, Any]]]) -> None:
    def table(entity):
        return tables[PREFIX + entity + "_di"]
    scope = ("collect_batch_id", "travel_date")
    scene_fields = (*scope, "scenic_id")
    cfields = (*scope, "content_id")
    sfields = (*scope, "source_id")
    ffields = (*cfields, "fact_seq_no")
    contents = {key(r, *cfields): r for r in table("content")}
    sources = {key(r, *sfields): r for r in table("source")}
    facts = {key(r, *ffields): r for r in table("fact")}
    tasks = {key(r, *scene_fields): r for r in table("collect_task")}
    content_sources = set()
    content_source_qty = Counter()
    fact_source_qty = Counter()
    excerpt_flags = Counter()
    fact_qty = Counter(key(r, *cfields) for r in facts.values())
    content_qty = Counter(key(r, *scene_fields) for r in contents.values())
    source_qty = Counter(key(r, *scene_fields) for r in sources.values())
    scenic_fact_qty = Counter(key(r, *scene_fields) for r in facts.values())

    for entity in ("content", "source", "fact", "content_source_rel", "fact_source_rel"):
        for r in table(entity):
            if key(r, *scene_fields) not in tasks:
                raise ValidationError(f"{entity}中的景区在同批次同分区没有任务记录")
    for r in facts.values():
        parent = contents.get(key(r, *cfields))
        if not parent or parent["scenic_id"] != r["scenic_id"] or parent["attraction_name"] != r["attraction_name"]:
            raise ValidationError("事实的内容ID、景区或景点与主表不一致")
    for r in table("content_source_rel"):
        ck = key(r, *cfields)
        parent = contents.get(ck)
        src = sources.get(key(r, *sfields))
        if not parent or not src or not (parent["scenic_id"] == src["scenic_id"] == r["scenic_id"]):
            raise ValidationError("内容来源关联缺少对应主记录或景区不一致")
        content_sources.add((*ck, r["source_id"]))
        content_source_qty[ck] += 1
        if r["excerpt_source_flag"]:
            if r["source_id"] != parent["excerpt_source_id"]:
                raise ValidationError("摘录标志与内容主表excerpt_source_id不一致")
            excerpt_flags[ck] += 1
    for r in table("fact_source_rel"):
        fk = key(r, *ffields)
        parent = facts.get(fk)
        src = sources.get(key(r, *sfields))
        if not parent or not src or not (parent["scenic_id"] == src["scenic_id"] == r["scenic_id"]):
            raise ValidationError("事实来源关联缺少对应记录或景区不一致")
        if (*key(r, *cfields), r["source_id"]) not in content_sources:
            raise ValidationError("事实来源不在所属内容的来源集合中")
        fact_source_qty[fk] += 1
    for fk in facts:
        if not fact_source_qty[fk]:
            raise ValidationError("存在没有来源关联的事实")
    for ck, r in contents.items():
        if r["guide_fact_qty"] != fact_qty[ck] or not content_source_qty[ck]:
            raise ValidationError("内容事实数量不一致或内容没有来源")
        if r["original_content_type"] == 0:
            if r["original_excerpt_text"] is not None or r["excerpt_source_id"] is not None or excerpt_flags[ck]:
                raise ValidationError("原文类型为0时摘录及其来源应为空")
        else:
            if not r["original_excerpt_text"] or not r["excerpt_source_id"] or excerpt_flags[ck] != 1:
                raise ValidationError("有原文摘录时必须恰有一个有效摘录来源")
        if r["poi_id"] is None:
            if r["poi_namespace_type"] != 0 or r["poi_match_status"] != 0 or r["poi_name"] is not None:
                raise ValidationError("无POI编码时POI命名空间、匹配状态或名称不一致")
        elif r["poi_namespace_type"] == 0 or r["poi_match_status"] == 0:
            raise ValidationError("有POI编码时必须标明命名空间和匹配状态")
    for sk, r in tasks.items():
        actual = (content_qty[sk], source_qty[sk], scenic_fact_qty[sk])
        declared = (r["guide_content_qty"], r["source_page_qty"], r["guide_fact_qty"])
        if actual != declared:
            raise ValidationError(f"景区任务声明的内容/来源/事实数量不一致：声明{declared}，实际{actual}")
        if r["collect_status"] == 0 and not actual[0]:
            raise ValidationError("没有正文产出时不能标记正文采集成功")


def insert_sql(database: str, s: TableSpec, mode: str) -> str:
    columns = ", ".join(f"`{c}`" for c in s.columns)
    values = ", ".join(["%s"] * len(s.columns))
    sql = f"INSERT INTO {qualified(database, s.name)} ({columns}) VALUES ({values})"
    if mode == "update":
        # VALUES(col)在MySQL 8中仍兼容，但部分版本会提示弃用；不忽略数据错误。
        updates = [f"`{c}`=VALUES(`{c}`)" for c in s.columns if c not in s.primary_key]
        sql += " ON DUPLICATE KEY UPDATE " + ", ".join(updates)
    elif mode != "error":
        raise ValidationError("不支持的重复主键处理模式")
    return sql


def expected_sql_type(field: str) -> str:
    if field in ENUMS:
        return "tinyint"
    if field in INTEGERS:
        return "int"
    if field in {"collect_time", "ingest_time"}:
        return "datetime"
    if field == "source_publish_date":
        return "date"
    if field == "guide_content_text":
        return "mediumtext"
    if field in {"original_excerpt_text", "scope_desc", "note_desc", "copyright_auth_desc", "fact_attr_value"}:
        return "text"
    return "varchar"


def check_database(cursor, database: str, tables) -> None:
    cursor.execute("SELECT VERSION() AS server_version")
    version = str(cursor.fetchone()["server_version"])
    m = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    if "mariadb" in version.lower() or not m or tuple(map(int, m.groups())) < (8, 0, 16):
        raise ValidationError("本DDL和导入程序要求MySQL 8.0.16+；当前服务器版本不匹配")
    for s in SPECS:
        cursor.execute("SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s", (database, s.name))
        record = cursor.fetchone()
        if not record:
            raise ValidationError(f"目标{database}.{s.name}未找到或当前账号不可见；请确认六张表已建在{database}库，并检查账号权限。本次尚未执行INSERT")
        if str(record["ENGINE"]).upper() != "INNODB":
            raise ValidationError(f"目标{database}.{s.name}存在，但引擎为{record['ENGINE']}，要求InnoDB；请先检查SHOW CREATE TABLE，不要直接删表。本次尚未执行INSERT")
        cursor.execute("SELECT COLUMN_NAME, IS_NULLABLE, DATA_TYPE, COLUMN_TYPE, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, CHARACTER_SET_NAME, DATETIME_PRECISION, COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s", (database, s.name))
        columns = {r["COLUMN_NAME"]: r for r in cursor.fetchall()}
        if set(columns) != set(s.columns) | {"ingest_time"}:
            raise ValidationError(f"{database}.{s.name}字段与已交付DDL不一致，请先核对表结构")
        cursor.execute("SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s AND CONSTRAINT_NAME='PRIMARY' ORDER BY ORDINAL_POSITION", (database, s.name))
        pk = tuple(r["COLUMN_NAME"] for r in cursor.fetchall())
        if pk != s.primary_key:
            raise ValidationError(f"{database}.{s.name}主键与DDL不一致")
        cursor.execute("SELECT INDEX_NAME, COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s AND NON_UNIQUE=0", (database, s.name))
        if any(index["INDEX_NAME"] != "PRIMARY" for index in cursor.fetchall()):
            raise ValidationError(f"{database}.{s.name}有DDL之外的唯一索引，可能导致upsert更新错主键，拒绝导入")
        for field, column in columns.items():
            expected = expected_sql_type(field)
            if str(column["DATA_TYPE"]).lower() != expected:
                raise ValidationError(f"{database}.{s.name}.{field}字段类型不符，要求{expected}")
            expected_nullable = "YES" if field in NULLABLE else "NO"
            if column["IS_NULLABLE"] != expected_nullable:
                raise ValidationError(f"{database}.{s.name}.{field}可空约束与DDL不一致")
            if field in INTEGERS and "unsigned" not in str(column["COLUMN_TYPE"]).lower():
                raise ValidationError(f"{database}.{s.name}.{field}必须是UNSIGNED")
            if expected == "datetime" and column["DATETIME_PRECISION"] != 3:
                raise ValidationError(f"{database}.{s.name}.{field}必须为DATETIME(3)，不能丢失毫秒")
            if expected in {"varchar", "text", "mediumtext"} and column["CHARACTER_SET_NAME"] != "utf8mb4":
                raise ValidationError(f"{database}.{s.name}.{field}必须使用utf8mb4字符集")
        if str(columns["ingest_time"]["COLUMN_DEFAULT"]).lower().replace(" ", "") != "current_timestamp(3)":
            raise ValidationError(f"{database}.{s.name}.ingest_time默认值必须为CURRENT_TIMESTAMP(3)")
        for row in tables[s.name]:
            for field, value in row.items():
                column = columns[field]
                if value is None and column["IS_NULLABLE"] != "YES":
                    raise ValidationError(f"{database}.{s.name}.{field}不接受NULL")
                if isinstance(value, str) and column["CHARACTER_MAXIMUM_LENGTH"] is not None:
                    is_text = column["DATA_TYPE"] in ("text", "mediumtext", "longtext", "tinytext")
                    limit = int(column["CHARACTER_OCTET_LENGTH"] if is_text else column["CHARACTER_MAXIMUM_LENGTH"])
                    length = len(value.encode("utf-8")) if is_text else len(value)
                    if length > limit:
                        raise ValidationError(f"{database}.{s.name}.{field}文本长度超限，拒绝静默截断")


def verify_database_counts(cursor, database: str, tables) -> None:
    scopes = sorted({(r["collect_batch_id"], r["travel_date"]) for rows in tables.values() for r in rows})
    for s in SPECS:
        expected = Counter((r["collect_batch_id"], r["travel_date"]) for r in tables[s.name])
        for batch, day in scopes:
            cursor.execute(f"SELECT COUNT(*) AS row_qty FROM {qualified(database, s.name)} WHERE collect_batch_id=%s AND travel_date=%s", (batch, day))
            actual = int(cursor.fetchone()["row_qty"])
            if actual != expected[(batch, day)]:
                raise ValidationError(f"{database}.{s.name}批次/分区数量不符：CSV {expected[(batch, day)]}，数据库 {actual}；输入必须为该批次完整六表数据，更新模式不会删除旧记录")


def write_transaction(connection, database: str, tables, batch_size: int, mode: str) -> None:
    # Schema checks precede writes. Nothing in this function creates or drops tables.
    with connection.cursor() as cursor:
        check_database(cursor, database, tables)
    connection.begin()
    try:
        with connection.cursor() as cursor:
            for s in SPECS:
                rows = tables[s.name]
                sql = insert_sql(database, s, mode)
                for start in range(0, len(rows), batch_size):
                    batch = [tuple(r[c] for c in s.columns) for r in rows[start:start + batch_size]]
                    cursor.executemany(sql, batch)
                print(f"已提交到事务（尚未COMMIT）：{database}.{s.name}，CSV {len(rows)}行")
            verify_database_counts(cursor, database, tables)
        try:
            connection.commit()
        except BaseException as exc:
            raise CommitOutcomeUnknown("COMMIT请求异常，实际提交结果需要核对") from exc
    except BaseException:
        try:
            connection.rollback()
        except Exception:
            print("连接已不可用，未能确认ROLLBACK；请核对该批次数据库状态后再重试。", file=sys.stderr)
        raise


def make_connection(args):
    # dry-run无需安装PyMySQL，也不读取密码或尝试网络连接。
    try:
        import pymysql
    except ImportError:
        raise ValidationError("请先执行：python -m pip install 'PyMySQL>=1.1.1,<2' 'cryptography>=42'") from None
    password = os.environ.get("MYSQL_PASSWORD")
    if password is None:
        if not sys.stdin.isatty():
            raise ValidationError("非交互环境请设置MYSQL_PASSWORD；程序不接受命令行明文密码")
        password = getpass.getpass("MySQL密码（隐藏输入）：")
    tls = ssl.create_default_context(cafile=str(args.ssl_ca)) if args.ssl_ca else (ssl.create_default_context() if args.ssl else None)
    return pymysql.connect(
        host=args.host, port=args.port, user=args.user, password=password,
        database=args.database, charset="utf8mb4", autocommit=False,
        connect_timeout=10, read_timeout=args.timeout, write_timeout=args.timeout,
        cursorclass=pymysql.cursors.DictCursor, ssl=tls,
        init_command="SET time_zone = '+00:00'",
    )


def arguments(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--data-dir", type=Path, default=Path(__file__).resolve().parent / "data", help="含6张dwd_*.csv的目录，默认脚本旁的data目录")
    p.add_argument("--host", default=os.environ.get("MYSQL_HOST", "127.0.0.1"))
    p.add_argument("--port", type=int, default=os.environ.get("MYSQL_PORT", "3306"))
    p.add_argument("--user", default=os.environ.get("MYSQL_USER", "scenic_writer"))
    p.add_argument("--database", default=os.environ.get("MYSQL_DATABASE", "dwd"))
    p.add_argument("--batch-size", type=int, default=200, help="每次executemany行数，不是提交频率；全部六表同一事务")
    p.add_argument("--timeout", type=int, default=120, help="MySQL读写超时秒数")
    p.add_argument("--on-duplicate", choices=("error", "update"), default="error", help="error=重复时报错并回滚；update=显式更新非主键字段，保留初次ingest_time")
    p.add_argument("--dry-run", action="store_true", help="仅离线验证六份CSV，不连接MySQL")
    p.add_argument("--test-connection", action="store_true", help="仅测试连接并查询服务器版本，不写数据，不要求CSV")
    p.add_argument("--ssl", action="store_true", help="启用TLS，使用系统CA验证证书和主机名")
    p.add_argument("--ssl-ca", type=Path, help="启用TLS并指定可信CA证书文件")
    args = p.parse_args(argv)
    identifier(args.database)
    if not 1 <= args.port <= 65535 or args.batch_size < 1 or args.timeout < 1:
        raise ValidationError("port、batch-size或timeout参数无效")
    if args.dry_run and args.test_connection:
        raise ValidationError("--dry-run与--test-connection不能同时使用")
    return args


def main(argv=None) -> int:
    connection = None
    try:
        args = arguments(argv)
        if args.test_connection:
            connection = make_connection(args)
            with connection.cursor() as cursor:
                cursor.execute("SELECT VERSION() AS server_version, DATABASE() AS database_name")
                print("连接成功：", cursor.fetchone())
            return 0
        tables = load_csvs(args.data_dir)
        for s in SPECS:
            print(f"CSV校验通过：{s.name}，{len(tables[s.name])}行")
        if args.dry_run:
            print("离线校验通过：字段、类型、日期、主键、来源关联及数量一致；未连接数据库。")
            return 0
        connection = make_connection(args)
        with connection.cursor() as cursor:
            cursor.execute("SELECT @@SESSION.sql_mode AS sql_mode")
            modes = set(str(cursor.fetchone()["sql_mode"] or "").split(",")) - {""}
            modes.update({"STRICT_ALL_TABLES", "NO_ZERO_DATE", "NO_ZERO_IN_DATE"})
            cursor.execute("SET SESSION sql_mode=%s", (",".join(sorted(modes)),))
        write_transaction(connection, args.database, tables, args.batch_size, args.on_duplicate)
        print("六表导入已COMMIT成功。各批次/分区行数已核对；未删除记录，未创建或修改表结构。")
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        # 不打印密码、SQL参数或正文；连接提交中断时以数据库实际状态为准。
        errno = exc.args[0] if getattr(exc, "args", ()) and isinstance(exc.args[0], int) else None
        if isinstance(exc, CommitOutcomeUnknown):
            print("COMMIT阶段出现异常；提交结果可能不确定，请先核对批次数据库状态，再决定是否重试。", file=sys.stderr)
        elif errno == 1062:
            print("导入失败：重复主键，写入事务已尝试回滚。确认需更新后使用--on-duplicate update。", file=sys.stderr)
        elif isinstance(exc, ValidationError):
            print(f"校验失败：{exc}", file=sys.stderr)
        elif errno:
            print(f"MySQL操作失败，错误码{errno}；请检查连接、权限、表结构或字段约束。", file=sys.stderr)
        else:
            print(f"操作失败：{type(exc).__name__}；请检查文件编码/日期格式、连接或服务状态。", file=sys.stderr)
        return 1
    finally:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
