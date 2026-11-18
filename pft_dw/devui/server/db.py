"""SQLite 存储层。

前端仍按 localStorage 的键值读写（dataflow-*），后端把其中两类键拆成关系表：
  dataflow-projects-v1            -> project
  dataflow-ui-draft-v2[:项目ID]    -> folder / task / flow / flow_node / flow_edge / flow_group
其余键（定时运行配置、即席查询草稿等）存入 kv。
数仓元数据（表、字段、血缘、质量规则、调度节点）存入 dw_* 表，供开发页只读展示。
"""
import json
import sqlite3
import threading
from datetime import datetime

DEFAULT_PROJECT = "tourism-default"
PROJECTS_KEY = "dataflow-projects-v1"
DRAFT_KEY = "dataflow-ui-draft-v2"

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS project (
    id          TEXT PRIMARY KEY,           -- 项目ID
    name        TEXT NOT NULL,              -- 项目名称
    description TEXT NOT NULL DEFAULT '',   -- 项目说明
    owner       TEXT NOT NULL DEFAULT '',   -- 负责人
    created_at  TEXT NOT NULL DEFAULT '',   -- 创建时间
    sort_no     INTEGER NOT NULL DEFAULT 0, -- 列表顺序
    extra_json  TEXT NOT NULL DEFAULT '{}'  -- 前端其余字段，原样回传
);

CREATE TABLE IF NOT EXISTS project_draft (
    project_id  TEXT PRIMARY KEY REFERENCES project(id) ON DELETE CASCADE,
    version     INTEGER NOT NULL,           -- 草稿结构版本，当前为 2
    extra_json  TEXT NOT NULL DEFAULT '{}', -- 草稿顶层其余字段
    updated_at  TEXT NOT NULL               -- 最近保存时间
);

CREATE TABLE IF NOT EXISTS folder (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    id          TEXT NOT NULL,              -- 目录ID
    name        TEXT NOT NULL,              -- 目录名称
    parent_id   TEXT,                       -- 上级目录ID，根目录为空
    sort_no     INTEGER NOT NULL,           -- 同级顺序
    extra_json  TEXT NOT NULL DEFAULT '{}',
    PRIMARY KEY (project_id, id)
);

CREATE TABLE IF NOT EXISTS task (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    id          TEXT NOT NULL,              -- 任务ID
    name        TEXT NOT NULL,              -- 任务名称
    table_name  TEXT NOT NULL,              -- 任务标识（数仓任务即目标表名）
    layer       TEXT NOT NULL DEFAULT '',   -- 数据分层：ODS/DIM/DWD/DWS/ADS
    folder_id   TEXT NOT NULL,              -- 所在目录
    type        TEXT NOT NULL DEFAULT 'sql',-- 任务类型：sql/python/shell/spark_jar/flink_jar
    engine      TEXT NOT NULL DEFAULT '',   -- SQL 引擎：spark/flink/presto/starrocks/mysql
    mode        TEXT NOT NULL DEFAULT 'batch', -- 运行模式：batch-离线，streaming-实时
    code        TEXT NOT NULL DEFAULT '',   -- 任务代码
    jar_json    TEXT,                       -- JAR 任务配置
    sort_no     INTEGER NOT NULL,
    extra_json  TEXT NOT NULL DEFAULT '{}',
    PRIMARY KEY (project_id, id)
);
CREATE INDEX IF NOT EXISTS idx_task_table ON task(project_id, table_name);

CREATE TABLE IF NOT EXISTS flow (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    id          TEXT NOT NULL,              -- 工作流ID
    name        TEXT NOT NULL,              -- 工作流名称
    folder_id   TEXT,                       -- 所在目录
    sort_no     INTEGER NOT NULL,
    extra_json  TEXT NOT NULL DEFAULT '{}', -- 含 layout（泳道自动排布配置）
    PRIMARY KEY (project_id, id)
);

CREATE TABLE IF NOT EXISTS flow_node (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    flow_id     TEXT NOT NULL,
    task_id     TEXT NOT NULL,              -- 节点引用的任务
    x           REAL NOT NULL,              -- 画布坐标
    y           REAL NOT NULL,
    sort_no     INTEGER NOT NULL,
    extra_json  TEXT NOT NULL DEFAULT '{}',
    PRIMARY KEY (project_id, flow_id, task_id)
);

CREATE TABLE IF NOT EXISTS flow_edge (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    flow_id     TEXT NOT NULL,
    from_task   TEXT NOT NULL,              -- 上游任务
    to_task     TEXT NOT NULL,              -- 下游任务
    sort_no     INTEGER NOT NULL,
    PRIMARY KEY (project_id, flow_id, from_task, to_task)
);

CREATE TABLE IF NOT EXISTS flow_group (
    project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    flow_id     TEXT NOT NULL,
    id          TEXT NOT NULL,              -- 分组ID
    name        TEXT NOT NULL,              -- 分组名称
    ids_json    TEXT NOT NULL,              -- 组内任务ID列表
    collapsed   INTEGER NOT NULL DEFAULT 0, -- 是否折叠：1-折叠，0-展开
    sort_no     INTEGER NOT NULL,
    extra_json  TEXT NOT NULL DEFAULT '{}',
    PRIMARY KEY (project_id, flow_id, id)
);

CREATE TABLE IF NOT EXISTS app_meta (
    key         TEXT PRIMARY KEY,           -- 后端内部标记（如初始化版本），不下发前端
    value       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kv (
    key         TEXT PRIMARY KEY,           -- 前端存储键
    value       TEXT NOT NULL,              -- JSON 文本
    updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS jar_file (
    id          TEXT PRIMARY KEY,           -- 程序包ID（sha256 前 16 位）
    name        TEXT NOT NULL,              -- 原文件名
    size        INTEGER NOT NULL,           -- 字节数
    path        TEXT NOT NULL,              -- 服务器存储路径
    uploaded_at TEXT NOT NULL
);

-- 数仓元数据（由 seed_pft.py 从生成器输出导入，只读）
CREATE TABLE IF NOT EXISTS dw_table (
    name        TEXT PRIMARY KEY,           -- 表名（不含库名）
    db_name     TEXT NOT NULL,              -- 库名 ods/dim/dwd/dws/ads
    layer       TEXT NOT NULL,
    domain      TEXT NOT NULL,              -- 数据域
    cn          TEXT NOT NULL,              -- 中文名
    rt          INTEGER NOT NULL,           -- 是否实时表：1-实时，0-离线
    engine      TEXT NOT NULL,              -- 存储/计算引擎
    grain       TEXT NOT NULL DEFAULT '',   -- 粒度
    src         TEXT NOT NULL DEFAULT '',   -- 来源
    ddl         TEXT NOT NULL,              -- 建表语句
    info_json   TEXT NOT NULL DEFAULT '{}'  -- 其余属性
);
CREATE TABLE IF NOT EXISTS dw_column (
    table_name  TEXT NOT NULL,
    seq         INTEGER NOT NULL,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL,
    comment     TEXT NOT NULL,
    kind        TEXT NOT NULL,              -- 字段角色：主键/外键/指标/维度属性…
    source      TEXT NOT NULL,              -- 加工口径
    refs_json   TEXT NOT NULL,              -- 上游字段 [[表,字段]]
    downs_json  TEXT NOT NULL,              -- 下游字段 [[表,字段]]
    PRIMARY KEY (table_name, seq)
);
CREATE TABLE IF NOT EXISTS dw_flow (
    id          TEXT PRIMARY KEY,           -- daily/weekly/monthly/yearly/realtime
    name        TEXT NOT NULL,
    cron        TEXT NOT NULL,
    info_json   TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dw_node (
    id          TEXT PRIMARY KEY,           -- 调度节点ID
    task_key    TEXT NOT NULL,              -- 对应开发任务标识
    flow_id     TEXT NOT NULL,
    kind        TEXT NOT NULL,              -- start/task/dq/recon/ext/end
    table_name  TEXT,
    cn          TEXT NOT NULL,
    info_json   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_node_task ON dw_node(task_key);
CREATE TABLE IF NOT EXISTS dw_rule (
    id          TEXT PRIMARY KEY,           -- 规则编号
    node_id     TEXT NOT NULL,              -- 所属质检节点
    table_name  TEXT,
    code        TEXT NOT NULL,              -- 规则类别：完整性/一致性/唯一性/有效性/及时性/波动
    name        TEXT NOT NULL,
    level       TEXT NOT NULL,              -- 强-阻断下游，弱-告警
    sql_text    TEXT NOT NULL,
    expect      TEXT NOT NULL,
    descr       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rule_table ON dw_rule(table_name);
"""


def now():
    return datetime.now().isoformat(timespec="seconds")


def _num(v):
    return int(v) if float(v).is_integer() else v


def _extra(obj, known):
    return json.dumps({k: v for k, v in obj.items() if k not in known}, ensure_ascii=False)


class Store:
    def __init__(self, path):
        self.path = str(path)
        self.lock = threading.RLock()
        self.conn = sqlite3.connect(self.path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(SCHEMA)

    # ---------- 项目 ----------
    def projects(self):
        rows = self.conn.execute("SELECT * FROM project ORDER BY sort_no, created_at").fetchall()
        out = []
        for r in rows:
            p = json.loads(r["extra_json"])
            p.update(id=r["id"], name=r["name"], description=r["description"], owner=r["owner"], createdAt=r["created_at"])
            out.append(p)
        return out

    def save_projects(self, items):
        known = {"id", "name", "description", "owner", "createdAt"}
        with self.lock, self.conn:
            ids = [p["id"] for p in items]
            for i, p in enumerate(items):
                self.conn.execute(
                    """INSERT INTO project(id,name,description,owner,created_at,sort_no,extra_json) VALUES(?,?,?,?,?,?,?)
                       ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,owner=excluded.owner,
                       created_at=excluded.created_at,sort_no=excluded.sort_no,extra_json=excluded.extra_json""",
                    (p["id"], p.get("name", ""), p.get("description", ""), p.get("owner", ""), p.get("createdAt", ""), i, _extra(p, known)))
            q = ",".join("?" * len(ids)) or "''"
            self.conn.execute(f"DELETE FROM project WHERE id NOT IN ({q})", ids)

    def ensure_project(self, pid, name, description="", owner="", created_at=""):
        with self.lock, self.conn:
            n = self.conn.execute("SELECT COUNT(*) FROM project").fetchone()[0]
            self.conn.execute(
                "INSERT OR IGNORE INTO project(id,name,description,owner,created_at,sort_no) VALUES(?,?,?,?,?,?)",
                (pid, name, description, owner, created_at or now()[:10], n))

    # ---------- 开发草稿（规范化存储） ----------
    def draft(self, pid):
        c = self.conn
        head = c.execute("SELECT * FROM project_draft WHERE project_id=?", (pid,)).fetchone()
        if not head:
            return None
        d = json.loads(head["extra_json"])
        d["version"] = head["version"]
        d["folders"] = []
        for r in c.execute("SELECT * FROM folder WHERE project_id=? ORDER BY sort_no", (pid,)):
            f = json.loads(r["extra_json"]); f.update(id=r["id"], name=r["name"], parentId=r["parent_id"]); d["folders"].append(f)
        d["tasks"] = []
        for r in c.execute("SELECT * FROM task WHERE project_id=? ORDER BY sort_no", (pid,)):
            t = json.loads(r["extra_json"])
            t.update(id=r["id"], name=r["name"], table=r["table_name"], layer=r["layer"], folderId=r["folder_id"],
                     type=r["type"], engine=r["engine"], mode=r["mode"], code=r["code"])
            if r["jar_json"] is not None:
                t["jar"] = json.loads(r["jar_json"])
            d["tasks"].append(t)
        flows = {}
        d["flows"] = []
        for r in c.execute("SELECT * FROM flow WHERE project_id=? ORDER BY sort_no", (pid,)):
            w = json.loads(r["extra_json"]); w.update(id=r["id"], name=r["name"], folderId=r["folder_id"], nodes=[], edges=[], groups=[])
            flows[r["id"]] = w; d["flows"].append(w)
        for r in c.execute("SELECT * FROM flow_node WHERE project_id=? ORDER BY flow_id, sort_no", (pid,)):
            if r["flow_id"] in flows:
                n = json.loads(r["extra_json"]); n.update(taskId=r["task_id"], x=_num(r["x"]), y=_num(r["y"])); flows[r["flow_id"]]["nodes"].append(n)
        for r in c.execute("SELECT * FROM flow_edge WHERE project_id=? ORDER BY flow_id, sort_no", (pid,)):
            if r["flow_id"] in flows:
                flows[r["flow_id"]]["edges"].append([r["from_task"], r["to_task"]])
        for r in c.execute("SELECT * FROM flow_group WHERE project_id=? ORDER BY flow_id, sort_no", (pid,)):
            if r["flow_id"] in flows:
                g = json.loads(r["extra_json"]); g.update(id=r["id"], name=r["name"], ids=json.loads(r["ids_json"]), collapsed=bool(r["collapsed"]))
                flows[r["flow_id"]]["groups"].append(g)
        return d

    def save_draft(self, pid, d):
        if not isinstance(d, dict) or not isinstance(d.get("folders"), list) or not isinstance(d.get("tasks"), list) or not isinstance(d.get("flows"), list):
            raise ValueError("草稿结构无效：需要 folders / tasks / flows")
        c = self.conn
        with self.lock, c:
            if not c.execute("SELECT 1 FROM project WHERE id=?", (pid,)).fetchone():
                self.ensure_project(pid, "项目" if pid != DEFAULT_PROJECT else "文旅数据项目")
            for t in ("folder", "task", "flow", "flow_node", "flow_edge", "flow_group"):
                c.execute(f"DELETE FROM {t} WHERE project_id=?", (pid,))
            c.execute("INSERT OR REPLACE INTO project_draft(project_id,version,extra_json,updated_at) VALUES(?,?,?,?)",
                      (pid, int(d.get("version", 2)), _extra(d, {"version", "folders", "tasks", "flows"}), now()))
            c.executemany("INSERT INTO folder VALUES(?,?,?,?,?,?)", [
                (pid, f["id"], f.get("name", ""), f.get("parentId"), i, _extra(f, {"id", "name", "parentId"}))
                for i, f in enumerate(d["folders"])])
            c.executemany("INSERT OR REPLACE INTO task VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)", [
                (pid, t["id"], t.get("name", ""), t.get("table", ""), t.get("layer", "") or "", t.get("folderId", ""),
                 t.get("type", "sql"), t.get("engine", "") or "", t.get("mode", "batch"), t.get("code", "") or "",
                 json.dumps(t["jar"], ensure_ascii=False) if t.get("jar") is not None else None, i,
                 _extra(t, {"id", "name", "table", "layer", "folderId", "type", "engine", "mode", "code", "jar"}))
                for i, t in enumerate(d["tasks"])])
            for i, w in enumerate(d["flows"]):
                c.execute("INSERT OR REPLACE INTO flow VALUES(?,?,?,?,?,?)",
                          (pid, w["id"], w.get("name", ""), w.get("folderId"), i, _extra(w, {"id", "name", "folderId", "nodes", "edges", "groups"})))
                c.executemany("INSERT OR REPLACE INTO flow_node VALUES(?,?,?,?,?,?,?)", [
                    (pid, w["id"], n["taskId"], float(n.get("x", 0)), float(n.get("y", 0)), j, _extra(n, {"taskId", "x", "y"}))
                    for j, n in enumerate(w.get("nodes", []))])
                c.executemany("INSERT OR IGNORE INTO flow_edge VALUES(?,?,?,?,?)", [
                    (pid, w["id"], e[0], e[1], j) for j, e in enumerate(w.get("edges", []))])
                c.executemany("INSERT OR REPLACE INTO flow_group VALUES(?,?,?,?,?,?,?,?)", [
                    (pid, w["id"], g["id"], g.get("name", ""), json.dumps(g.get("ids", []), ensure_ascii=False), 1 if g.get("collapsed") else 0, j,
                     _extra(g, {"id", "name", "ids", "collapsed"}))
                    for j, g in enumerate(w.get("groups", []))])

    def delete_draft(self, pid):
        with self.lock, self.conn:
            for t in ("folder", "task", "flow", "flow_node", "flow_edge", "flow_group", "project_draft"):
                self.conn.execute(f"DELETE FROM {t} WHERE project_id=?", (pid,))

    def flag(self, key, value=None):
        if value is None:
            r = self.conn.execute("SELECT value FROM app_meta WHERE key=?", (key,)).fetchone()
            return r["value"] if r else None
        with self.lock, self.conn:
            self.conn.execute("INSERT OR REPLACE INTO app_meta VALUES(?,?)", (key, value))

    # ---------- 键值（前端 dataflow-* 键） ----------
    @staticmethod
    def split_key(key):
        base, _, pid = key.partition(":")
        return base, (pid or DEFAULT_PROJECT)

    def all_kv(self):
        out = {}
        projects = self.projects()
        if projects:
            out[PROJECTS_KEY] = json.dumps(projects, ensure_ascii=False)
        for p in projects:
            d = self.draft(p["id"])
            if d is not None:
                key = DRAFT_KEY if p["id"] == DEFAULT_PROJECT else DRAFT_KEY + ":" + p["id"]
                out[key] = json.dumps(d, ensure_ascii=False)
        for r in self.conn.execute("SELECT key, value FROM kv"):
            out[r["key"]] = r["value"]
        return out

    def put_kv(self, key, value):
        base, pid = self.split_key(key)
        if key == PROJECTS_KEY:
            self.save_projects(json.loads(value))
        elif base == DRAFT_KEY:
            self.save_draft(pid, json.loads(value))
        else:
            json.loads(value)  # 只接受 JSON
            with self.lock, self.conn:
                self.conn.execute("INSERT OR REPLACE INTO kv VALUES(?,?,?)", (key, value, now()))

    def delete_kv(self, key):
        base, pid = self.split_key(key)
        if base == DRAFT_KEY:
            self.delete_draft(pid)
        elif key != PROJECTS_KEY:
            with self.lock, self.conn:
                self.conn.execute("DELETE FROM kv WHERE key=?", (key,))

    # ---------- 程序包 ----------
    def add_jar(self, jid, name, size, path):
        with self.lock, self.conn:
            self.conn.execute("INSERT OR REPLACE INTO jar_file VALUES(?,?,?,?,?)", (jid, name, size, path, now()))

    def jar(self, jid):
        return self.conn.execute("SELECT * FROM jar_file WHERE id=?", (jid,)).fetchone()

    # ---------- 数仓元数据 ----------
    def task_meta(self, key):
        c = self.conn
        node = c.execute("SELECT * FROM dw_node WHERE task_key=? ORDER BY CASE kind WHEN 'task' THEN 0 ELSE 1 END LIMIT 1", (key,)).fetchone()
        table = key
        if node and node["table_name"]:
            table = node["table_name"]
        t = c.execute("SELECT * FROM dw_table WHERE name=?", (table,)).fetchone()
        if not node and not t:
            return None
        out = {"task": key}
        if t:
            info = json.loads(t["info_json"])
            out["table"] = {"name": t["name"], "db": t["db_name"], "layer": t["layer"], "domain": t["domain"], "cn": t["cn"],
                            "rt": bool(t["rt"]), "engine": t["engine"], "grain": t["grain"], "src": t["src"], "ddl": t["ddl"], **info}
            out["columns"] = [{"name": r["name"], "type": r["type"], "comment": r["comment"], "kind": r["kind"], "source": r["source"],
                               "refs": json.loads(r["refs_json"]), "downs": json.loads(r["downs_json"])}
                              for r in c.execute("SELECT * FROM dw_column WHERE table_name=? ORDER BY seq", (table,))]
        if node:
            info = json.loads(node["info_json"])
            flow = c.execute("SELECT * FROM dw_flow WHERE id=?", (node["flow_id"],)).fetchone()
            out["node"] = {"id": node["id"], "kind": node["kind"], "flow": node["flow_id"], "cn": node["cn"], **info}
            if flow:
                out["flow"] = {"id": flow["id"], "name": flow["name"], "cron": flow["cron"], **json.loads(flow["info_json"])}
            # 上下游调度节点 -> 任务标识
            ids = info.get("deps", [])
            ups = [dict(r) for r in c.execute(f"SELECT id, task_key, kind, cn FROM dw_node WHERE id IN ({','.join('?'*len(ids)) or "''"})", ids)]
            downs = [dict(r) for r in c.execute("SELECT id, task_key, kind, cn, info_json FROM dw_node WHERE flow_id=?", (node["flow_id"],))
                     if node["id"] in json.loads(r["info_json"]).get("deps", [])]
            for d in downs:
                d.pop("info_json", None)
            out["upstream"], out["downstream"] = ups, downs
        node_ids = [r["id"] for r in c.execute("SELECT id FROM dw_node WHERE (table_name=? OR task_key=?) AND kind IN ('dq','recon')", (table, key))]
        if node_ids:
            q = ",".join("?" * len(node_ids)) or "''"
            out["rules"] = [{"id": r["id"], "node": r["node_id"], "code": r["code"], "name": r["name"], "level": r["level"],
                             "sql": r["sql_text"], "expect": r["expect"], "desc": r["descr"]}
                            for r in c.execute(f"SELECT * FROM dw_rule WHERE node_id IN ({q}) ORDER BY id", node_ids)]
        return out

    def meta_summary(self):
        c = self.conn
        return {
            "tables": c.execute("SELECT COUNT(*) FROM dw_table").fetchone()[0],
            "columns": c.execute("SELECT COUNT(*) FROM dw_column").fetchone()[0],
            "rules": c.execute("SELECT COUNT(*) FROM dw_rule").fetchone()[0],
            "nodes": c.execute("SELECT COUNT(*) FROM dw_node").fetchone()[0],
            "flows": [dict(id=r["id"], name=r["name"], cron=r["cron"]) for r in c.execute("SELECT * FROM dw_flow")],
        }
