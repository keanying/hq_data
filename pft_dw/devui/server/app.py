"""数据开发平台后端（Python 标准库 + SQLite，无第三方依赖）。

    python server/app.py                # http://127.0.0.1:4180
    python server/app.py --port 8080 --host 0.0.0.0
    python server/app.py --reseed       # 用最新的数仓生成结果重建 PFT 2.0 项目

接口：
    GET    /api/health
    GET    /api/kv                 前端全部存储键（项目列表、各项目开发草稿、定时运行、查询草稿）
    PUT    /api/kv/<key>           写入一个键（项目列表与开发草稿拆表存储）
    DELETE /api/kv/<key>
    GET    /api/meta/summary       数仓元数据概况
    GET    /api/meta/task/<任务标识> 任务对应的表 DDL、字段血缘、质量规则、调度上下游
    POST   /api/jars?name=x.jar    上传 JAR（≤50 MB），返回 201
    GET    /api/jars/<id>          下载 JAR
"""
import argparse
import hashlib
import json
import mimetypes
import re
import sys
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
DATA = ROOT / "data"
sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import DEFAULT_PROJECT, Store  # noqa: E402

MAX_JAR = 50 * 1024 * 1024
MAX_BODY = 64 * 1024 * 1024
KEY_RE = re.compile(r"^dataflow-[A-Za-z0-9_\-]+(:[A-Za-z0-9_\-]+)?$")
mimetypes.add_type("text/javascript", ".mjs")
mimetypes.add_type("application/wasm", ".wasm")


class Handler(SimpleHTTPRequestHandler):
    store: Store = None
    server_version = "pft-devui/1.0"

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(WEB), **kw)

    def log_message(self, fmt, *args):
        if "/api/" in (args[0] if args else ""):
            sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    # ---------- 工具 ----------
    def json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def error_json(self, status, msg):
        self.json({"error": msg}, status)

    def body(self, limit=MAX_BODY):
        n = int(self.headers.get("Content-Length") or 0)
        if n > limit:
            raise ValueError("请求体过大")
        return self.rfile.read(n)

    # ---------- 路由 ----------
    def do_GET(self):
        u = urlparse(self.path)
        p = unquote(u.path)
        if not p.startswith("/api/"):
            return super().do_GET()
        try:
            if p == "/api/health":
                return self.json({"ok": True, "db": str(self.store.path)})
            if p == "/api/kv":
                return self.json({"kv": self.store.all_kv(), "defaultProject": DEFAULT_PROJECT})
            if p == "/api/meta/summary":
                return self.json(self.store.meta_summary())
            m = re.fullmatch(r"/api/meta/task/([A-Za-z0-9_.]+)", p)
            if m:
                meta = self.store.task_meta(m.group(1))
                return self.json(meta) if meta else self.error_json(404, "该任务没有数仓元数据")
            m = re.fullmatch(r"/api/jars/([0-9a-f]{16})", p)
            if m:
                r = self.store.jar(m.group(1))
                if not r or not Path(r["path"]).exists():
                    return self.error_json(404, "程序包不存在")
                data = Path(r["path"]).read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "application/java-archive")
                self.send_header("Content-Disposition", "attachment; filename*=UTF-8''" + quote(r["name"]))
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                return self.wfile.write(data)
            return self.error_json(404, "接口不存在")
        except Exception as e:  # noqa: BLE001
            return self.error_json(500, str(e))

    def do_PUT(self):
        p = unquote(urlparse(self.path).path)
        m = re.fullmatch(r"/api/kv/(.+)", p)
        if not m or not KEY_RE.match(m.group(1)):
            return self.error_json(404, "接口不存在")
        try:
            value = self.body().decode("utf-8")
            self.store.put_kv(m.group(1), value)
            return self.json({"ok": True})
        except (ValueError, KeyError, TypeError) as e:
            return self.error_json(400, "数据无效：" + str(e))

    def do_DELETE(self):
        p = unquote(urlparse(self.path).path)
        m = re.fullmatch(r"/api/kv/(.+)", p)
        if not m or not KEY_RE.match(m.group(1)):
            return self.error_json(404, "接口不存在")
        self.store.delete_kv(m.group(1))
        return self.json({"ok": True})

    def do_POST(self):
        u = urlparse(self.path)
        if u.path != "/api/jars":
            return self.error_json(404, "接口不存在")
        name = (parse_qs(u.query).get("name") or [""])[0]
        name = Path(name).name
        if not name.lower().endswith(".jar"):
            return self.error_json(400, "请选择 .jar 文件")
        try:
            data = self.body(MAX_JAR)
        except ValueError:
            return self.error_json(413, "文件不能超过 50 MB")
        if not data:
            return self.error_json(400, "文件不能为空")
        jid = hashlib.sha256(data).hexdigest()[:16]
        folder = DATA / "jars"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / f"{jid}_{re.sub(r'[^A-Za-z0-9_.-]', '_', name)}"
        path.write_bytes(data)
        self.store.add_jar(jid, name, len(data), str(path))
        return self.json({"id": jid, "name": name, "size": len(data), "url": f"/api/jars/{jid}"}, HTTPStatus.CREATED)


def main():
    ap = argparse.ArgumentParser(description="数据开发平台后端")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=4180)
    ap.add_argument("--db", default=str(DATA / "devui.db"))
    ap.add_argument("--reseed", action="store_true", help="重建 PFT 2.0 数仓项目（覆盖该项目的开发草稿与定时配置）")
    args = ap.parse_args()
    Path(args.db).parent.mkdir(parents=True, exist_ok=True)
    store = Store(args.db)
    import seed_pft
    seed_pft.ensure(store, force=args.reseed)
    Handler.store = store
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"数据开发平台：http://{args.host}:{args.port}   数据库：{args.db}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
