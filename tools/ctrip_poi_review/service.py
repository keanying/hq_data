"""景区 POI 数据工作台 —— 常驻服务（网页 + 接口）。

    python service.py --channel chrome            # 默认 http://127.0.0.1:8800 ，浏览器打开即是工作台
    python service.py --cities 北京市,上海市 --port 8800   # 只看部分城市（默认全国）

- 网页：总览 / 核对 / 图片采集 / 数据预览 / 图片预览 / 任务中心（web/ 目录，React + Semi Design 本地副本，无需构建、不依赖 CDN）
- 核对：网页里的核对面板（与 panel.js 同一份代码），搜索由服务端浏览器在携程搜索框里输入、读下拉结果
- 任务队列：自动审核（auto_review）、点评图片采集（images）逐个执行；进度、日志、取消；遇到登录/验证停在「需要人工」
- 服务端浏览器两个标签页：一个给核对搜索，一个给后台任务，互不打断；浏览器目录和 `review.py run` 分开，可以同时开
"""
import argparse
import asyncio
import collections
import contextlib
import itertools
import re
import time
import traceback
from pathlib import Path
from types import SimpleNamespace

import uvicorn
from fastapi import Body, FastAPI, HTTPException
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse, HTMLResponse, Response
from fastapi.staticfiles import StaticFiles

import ai_judge
import crawler
import db
import review

HERE = Path(__file__).resolve().parent
WEB = HERE / "web"
JOB_TYPES = {"auto_review": "自动审核", "images": "采集点评图片"}


class Job:
    _ids = itertools.count(1)

    def __init__(self, type_, params):
        self.id = next(self._ids)
        self.type, self.params = type_, params
        self.status = "queued"  # queued / running / done / failed / cancelled / need_human
        self.done = self.total = 0
        self.created = time.strftime("%Y-%m-%d %H:%M:%S")
        self.started = self.finished = None
        self.result = self.error = None
        self.cancel = False
        self.log = collections.deque(maxlen=2000)

    def write(self, msg):
        self.log.append(f"{time.strftime('%H:%M:%S')} {msg}")

    def brief(self):
        return dict(id=self.id, type=self.type, type_name=JOB_TYPES.get(self.type, self.type), params=self.params,
                    status=self.status, done=self.done, total=self.total, created=self.created, started=self.started,
                    finished=self.finished, result=self.result, error=self.error, last=self.log[-1] if self.log else "")


class Service:
    def __init__(self, args):
        self.args = args
        self.jobs: dict[int, Job] = {}
        self.queue: asyncio.Queue = asyncio.Queue()
        profile = Path(args.profile)
        profile.mkdir(parents=True, exist_ok=True)
        self.prefs = review.Prefs(profile / "hq_prefs.json")
        self.browser = review.LazyBrowser(args, prefs=self.prefs)
        self.current: Job | None = None
        self.review_searcher = None
        self._rs_lock = asyncio.Lock()
        self._rpc = review.make_rpc(self.get_review_searcher, self.prefs, export_url="/api/export.csv")
        # 边核对边采集：审核通过的景区排进采图队列，用单独的标签页在后台采
        self.follow_q: asyncio.Queue = asyncio.Queue()
        self.follow_pending: list[str] = []
        self.follow = dict(paused=False, current=None, done=0, images=0, failed=0, message="")
        self.follow_log = collections.deque(maxlen=300)
        self.follow_page = None
        # 正在采集的 POI（follow = 边核对边采集，job = 任务中心的采集任务），用于展示进度和「下一个 POI」
        self.active: dict[str, dict] = {}

    def track(self, source, c, target, job_id=None):
        if c is None:
            self.active.pop(source, None)
            return
        info = dict(source=source, job_id=job_id, scenic_id=target["scenic"]["id"], scenic_name=target["scenic"].get("name"),
                    poi_id=target["poi"].get("poiId"), poi_name=target["poi"].get("poiName"), poi_uri=target["poi"].get("poiUri"),
                    pages=0, images=0, empty_run=0, max_pages=c.max_pages, empty_limit=c.empty_limit,
                    started=time.strftime("%H:%M:%S"), crawler=c)

        def on_progress(stat):
            info.update(pages=stat["pages"], images=stat["images"], empty_run=stat["empty_run"])
        c.on_progress = on_progress
        self.active[source] = info

    def active_brief(self):
        return [{k: v for k, v in a.items() if k != "crawler"} for a in self.active.values()]

    def empty_limit(self):
        v = self.prefs.get("collect_empty_pages")
        return 10 if v in (None, "") else int(v)

    async def rpc(self, method, payload):
        res = await self._rpc(method, payload)
        if method == "status" and (payload or {}).get("status") == "done":
            self.enqueue_follow(payload.get("scenic_id"))
        return res

    def follow_enabled(self):
        return self.prefs.get("auto_collect", True) is not False

    def enqueue_follow(self, scenic_id):
        if scenic_id and self.follow_enabled() and scenic_id not in self.follow_pending:
            self.follow_pending.append(scenic_id)
            self.follow_q.put_nowait(scenic_id)

    def flog(self, msg):
        self.follow_log.append(f"{time.strftime('%H:%M:%S')} {msg}")

    async def follow_worker(self):
        while True:
            sid = await self.follow_q.get()
            while self.follow["paused"]:
                await asyncio.sleep(2)
            try:
                if sid in self.follow_pending:
                    self.follow_pending.remove(sid)
                st0 = {}
                targets = db.crawl_targets(dict(scenic_id=sid), stats=st0)
                if not targets:
                    if st0.get("skipped"):
                        self.flog(f"{sid}：保留的 {st0['skipped']} 个 POI 之前都采过，跳过")
                    continue
                if self.follow_page is None:
                    self.follow_page = await self.browser.new_page()
                mp = int(self.prefs.get("collect_max_pages") or 20)
                mi = int(self.prefs.get("collect_max_images") if self.prefs.get("collect_max_images") is not None else 300)
                for t in targets:
                    name = f"{t['scenic']['name']} / {t['poi'].get('poiName')}"
                    self.follow["current"] = name
                    c = crawler.CommentImageCrawler(self.follow_page, max_pages=mp, max_images=mi, log=self.flog,
                                                    empty_limit=self.empty_limit())
                    self.track("follow", c, t)
                    try:
                        st = await c.crawl(t)
                    finally:
                        self.track("follow", None, None)
                    self.follow["images"] += st["images"]
                    self.flog(f"{name}：{st['pages']} 页，新增图片 {st['images']}；{st['stop']}")
                self.follow["done"] += 1
            except crawler.NeedHuman as e:
                self.follow.update(paused=True, message=str(e))
                self.flog(f"暂停：{e}")
                self.follow_pending.insert(0, sid)
                self.follow_q.put_nowait(sid)
            except Exception as e:  # noqa: BLE001
                self.follow["failed"] += 1
                self.flog(f"{sid} 采集失败：{type(e).__name__}: {e}")
            finally:
                self.follow["current"] = None

    async def get_review_searcher(self):
        """核对用的搜索：服务端浏览器里单独一个标签页，不和后台任务抢。"""
        async with self._rs_lock:
            if self.review_searcher is None:
                page = await self.browser.new_page()
                self.review_searcher = review.CtripSearcher(page, self.prefs, self.args.start_url, self.args.pattern)
                await page.goto(self.args.start_url, wait_until="domcontentloaded")
                await page.wait_for_timeout(1500)
            return self.review_searcher

    async def worker(self):
        while True:
            job = await self.queue.get()
            if job.cancel:
                job.status = "cancelled"
                continue
            self.current = job
            job.status, job.started = "running", time.strftime("%Y-%m-%d %H:%M:%S")
            try:
                job.result = await self.run(job)
                job.status = "cancelled" if job.cancel else "done"
            except crawler.NeedHuman as e:
                job.status, job.error = "need_human", str(e)
                job.write(f"需要人工：{e}")
            except Exception as e:  # noqa: BLE001
                job.status, job.error = "failed", f"{type(e).__name__}: {e}"
                job.write(traceback.format_exc(limit=3))
            finally:
                job.finished = time.strftime("%Y-%m-%d %H:%M:%S")
                self.current = None

    async def run(self, job):
        p = job.params
        stop = lambda: job.cancel  # noqa: E731

        def progress(done, total):
            job.done, job.total = done, total

        if job.type == "auto_review":
            on_ok = self.enqueue_follow if not p.get("dry_run") else (lambda sid: None)
            ns = SimpleNamespace(city=p.get("city") or "", grade=p.get("grade") or "", q=p.get("q") or "",
                                 limit=int(p.get("limit") or 0), no_alias=bool(p.get("no_alias")), spots=bool(p.get("spots")),
                                 max_extra=int(p.get("max_extra") or 8), cache_only=bool(p.get("cache_only")),
                                 dry_run=bool(p.get("dry_run")), verbose=bool(p.get("verbose", True)),
                                 reviewer=p.get("reviewer") or "auto", max_fail=5)
            ai_cfg = ai_judge.config(self.prefs) if p.get("use_ai", True) else None
            return await review.auto_review(ns, self.browser.get_searcher, log=job.write, should_stop=stop, progress=progress,
                                            on_approved=on_ok, ai_cfg=ai_cfg)
        if job.type == "images":
            f = dict(city=p.get("city") or "", grade=p.get("grade") or "", q=p.get("q") or "")
            return await crawler.crawl_all(self.browser.get_page, f, max_pages=int(p.get("max_pages") or 20),
                                           max_images=int(p.get("max_images") if p.get("max_images") not in (None, "") else 300),
                                           limit=int(p.get("limit") or 0), refresh=bool(p.get("refresh")),
                                           log=job.write, should_stop=stop, progress=progress,
                                           empty_limit=int(p["empty_pages"]) if p.get("empty_pages") not in (None, "") else self.empty_limit(),
                                           on_crawler=lambda c, t: self.track("job", c, t, job.id))
        raise ValueError(f"未知任务类型 {job.type}")


def create_app(args):
    svc = Service(args)
    @contextlib.asynccontextmanager
    async def lifespan(_app):
        loop = asyncio.get_running_loop()
        loop.create_task(svc.worker())
        loop.create_task(svc.follow_worker())
        url = f"http://{args.host}:{args.port}"
        loop.call_later(0.5, lambda: print(f"服务已就绪：{url}  （浏览器打开即是工作台；Ctrl+C 停止）", flush=True))
        yield
        await svc.browser.close()

    app = FastAPI(title="携程 POI 核对 / 景点图像采集服务", lifespan=lifespan)
    app.add_middleware(GZipMiddleware, minimum_size=2048)  # web/vendor 里的前端库较大，压缩后传输

    @app.get("/", response_class=HTMLResponse)
    def index():
        # 给页面里引用的 css/js 加上版本号（文件修改时间），升级后浏览器不会用旧缓存
        def ver(m):
            f = WEB / m.group(2) if m.group(1) == "/web/" else HERE / m.group(2)
            try:
                return f"{m.group(1)}{m.group(2)}?v={int(f.stat().st_mtime)}"
            except OSError:
                return m.group(0)
        page = re.sub(r"(/web/|/)((?:vendor/)?[\w.-]+\.(?:css|js))(?=\")", ver, (WEB / "index.html").read_text(encoding="utf-8"))
        return HTMLResponse(page, headers={"Cache-Control": "no-cache"})

    @app.get("/panel.js")
    def panel_js():
        return FileResponse(HERE / "panel.js", media_type="application/javascript", headers={"Cache-Control": "no-cache"})

    @app.middleware("http")
    async def no_stale_assets(request, call_next):
        """网页文件每次都向服务确认是否有更新（没变会返回 304，不重复下载），避免升级后浏览器用旧的 app.js。"""
        resp = await call_next(request)
        if request.url.path.startswith("/web/"):
            resp.headers["Cache-Control"] = "no-cache"
        return resp

    app.mount("/web", StaticFiles(directory=WEB), name="web")

    @app.get("/api/health")
    def health():
        return dict(db.health(), current_job=svc.current.id if svc.current else None, queued=svc.queue.qsize(),
                    need_human=sum(1 for j in svc.jobs.values() if j.status == "need_human"), reviewer=svc.prefs.get("reviewer") or "")

    @app.post("/api/rpc/{method}")
    async def rpc(method: str, payload: dict = Body(default={})):
        """核对面板的后端方法（hello / list / detail / search / poi / status / prefs / fetch_address / locate_input / export）。"""
        try:
            return await svc.rpc(method, payload)
        except Exception as e:  # noqa: BLE001  错误以 {error} 返回给面板显示
            return dict(error=f"{type(e).__name__}: {e}")

    @app.get("/api/follow")
    def follow_state():
        return dict(svc.follow, enabled=svc.follow_enabled(), pending=len(svc.follow_pending), log=list(svc.follow_log)[-50:],
                    active=svc.active_brief())

    @app.post("/api/follow")
    def follow_set(payload: dict = Body(default={})):
        if "enabled" in payload:
            svc.prefs["auto_collect"] = bool(payload["enabled"])
            svc.prefs.save()
        if payload.get("resume"):
            svc.follow.update(paused=False, message="")
        if payload.get("pause"):
            svc.follow["paused"] = True
        return follow_state()

    # ---------------- 设置（AI 配置 + 核对 / 采集开关）
    SETTING_KEYS = ["reviewer", "throttle_ms", "auto_search", "auto_keep_similar", "auto_approve", "auto_approve_delay_ms", "idle_skip",
                    "idle_skip_sec", "search_more", "search_core_spots", "max_extra", "auto_address", "auto_collect", "collect_max_pages",
                    "collect_max_images", "collect_empty_pages"] + [k for k in ai_judge.DEFAULTS if k != "ai_api_key"]

    @app.get("/api/settings")
    def get_settings():
        cfg = ai_judge.config(svc.prefs)
        return dict(review.public_prefs(svc.prefs), ai_key_source=cfg["key_source"], ai_defaults=ai_judge.DEFAULTS)

    @app.post("/api/settings")
    def set_settings(payload: dict = Body(default={})):
        for k in SETTING_KEYS:
            if k in payload:
                svc.prefs[k] = payload[k]
        key = payload.get("ai_api_key")
        if key == "__clear__":
            svc.prefs["ai_api_key"] = ""
        elif isinstance(key, str) and key.strip() and "****" not in key:  # 打码的原样回传时不改
            svc.prefs["ai_api_key"] = key.strip()
        svc.prefs.save()
        return get_settings()

    @app.post("/api/ai/test")
    async def ai_test(payload: dict = Body(default={})):
        """用当前设置（或页面上还没保存的设置）发一个很短的请求，看能不能连通。"""
        prefs = dict(svc.prefs)
        prefs.update({k: v for k, v in payload.items() if k in ai_judge.DEFAULTS and k != "ai_api_key"})
        if isinstance(payload.get("ai_api_key"), str) and payload["ai_api_key"].strip() and "****" not in payload["ai_api_key"]:
            prefs["ai_api_key"] = payload["ai_api_key"].strip()
        cfg = ai_judge.config(prefs)
        try:
            return await asyncio.to_thread(ai_judge.ping, cfg)
        except Exception as e:  # noqa: BLE001
            return dict(ok=False, error=str(e))

    @app.get("/api/crawl")
    def crawl_state():
        """正在采集的 POI：来源、景区、POI、已翻页数、新增图片、连续无新图页数。"""
        return dict(active=svc.active_brief())

    @app.post("/api/crawl/skip")
    def crawl_skip(payload: dict = Body(default={})):
        """手动跳到下一个 POI。source = follow / job，不传则全部正在采集的都跳。"""
        src = payload.get("source")
        hit = [a for k, a in svc.active.items() if not src or k == src]
        for a in hit:
            a["crawler"].skip()
            line = f"手动跳过：{a['scenic_name']} / {a['poi_name']}（已翻 {a['pages']} 页）"
            if a["source"] == "follow":
                svc.flog(line)
            elif a.get("job_id") in svc.jobs:
                svc.jobs[a["job_id"]].write(line)
        return dict(skipped=len(hit), active=svc.active_brief())

    @app.get("/api/overview")
    def overview():
        return db.overview()

    @app.get("/api/stats")
    def stats():
        return dict(cities=db.cities(), images=db.image_stats())

    @app.get("/api/scenic_table")
    def scenic_table(city: str = "", grade: str = "", status: str = "all", q: str = "", limit: int = 50, offset: int = 0):
        return db.scenic_table(dict(city=city, grade=grade, status=status, q=q), max(offset, 0), min(max(limit, 1), 200))

    @app.get("/api/export.csv")
    def export_csv():
        import csv
        import io
        rows = db.export_rows()
        buf = io.StringIO()
        buf.write("\ufeff")
        cols = ["scenic_id", "scenic_name", "city_name", "approval", "kept_qty", "ctrip_poi_id_list", "ctrip_poi_name_list", "ctrip_poi_info", "note"]
        w = csv.DictWriter(buf, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
        return Response(buf.getvalue(), media_type="text/csv; charset=utf-8",
                        headers={"Content-Disposition": f"attachment; filename=scenic_ctrip_poi_mapping_{time.strftime('%Y%m%d')}.csv"})

    @app.post("/api/jobs")
    async def submit(payload: dict = Body(...)):
        t = payload.get("type")
        if t not in JOB_TYPES:
            raise HTTPException(400, f"type 只能是 {list(JOB_TYPES)}")
        job = Job(t, payload.get("params") or {})
        svc.jobs[job.id] = job
        job.write(f"已加入队列：{JOB_TYPES[t]} {job.params}")
        await svc.queue.put(job)
        return job.brief()

    @app.get("/api/jobs")
    def jobs():
        return [j.brief() for j in sorted(svc.jobs.values(), key=lambda j: -j.id)]

    @app.get("/api/jobs/{job_id}")
    def job(job_id: int, tail: int = 300):
        j = svc.jobs.get(job_id)
        if not j:
            raise HTTPException(404, "任务不存在")
        return dict(j.brief(), log=list(j.log)[-tail:])

    @app.post("/api/jobs/{job_id}/cancel")
    def cancel(job_id: int):
        j = svc.jobs.get(job_id)
        if not j:
            raise HTTPException(404, "任务不存在")
        j.cancel = True
        if j.status == "queued":
            j.status = "cancelled"
        j.write("已请求取消（当前景区/POI 处理完后停止）")
        return j.brief()

    @app.get("/api/images")
    def images(scenic_id: str = "", poi_id: str = "", city: str = "", q: str = "", score_min: str = "", sort: str = "collect",
               limit: int = 60, offset: int = 0):
        return db.images_query(scenic_id or None, poi_id or None, min(max(limit, 1), 500), max(offset, 0), city or None, q or None,
                               score_min or None, sort)

    @app.get("/api/image_facets")
    def image_facets(city: str = "", scenic_id: str = "", q: str = ""):
        """图片预览的下拉选项：有图片的城市、景区（带图片数），选了景区再给它的 POI。"""
        return db.image_facets(city or None, scenic_id or None, q or None)

    @app.get("/api/crawl_records")
    def crawl_records(status: str = "", q: str = "", limit: int = 50, offset: int = 0):
        return db.crawl_query(status or None, q or None, max(offset, 0), min(max(limit, 1), 200))

    @app.get("/api/scenic/{scenic_id}")
    def scenic(scenic_id: str):
        try:
            d = db.scenic_detail(scenic_id)
        except KeyError as e:
            raise HTTPException(404, str(e)) from e
        return dict(scenic=d["scenic"], status=d["status"], kept=d["kept"])

    return app


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1", help="监听地址，默认只本机可访问")
    ap.add_argument("--port", type=int, default=8800)
    ap.add_argument("--profile", default=str(HERE / ".pw-profile-service"), help="服务用的浏览器目录（和 review.py run 分开）")
    ap.add_argument("--channel", default="", help="chrome / msedge：用本机浏览器")
    ap.add_argument("--executable-path", default="")
    ap.add_argument("--headless", action="store_true", help="无界面（遇到验证码没法人工处理，不建议）")
    ap.add_argument("--start-url", default=review.DEFAULT_START_URL)
    ap.add_argument("--throttle-ms", type=int, default=0, help="两次搜索最小间隔（毫秒），默认 2500")
    ap.add_argument("--cities", default="", help="只看这些城市（逗号分隔，按顺序依次跑），如 北京市,上海市；默认全国")
    ap.add_argument("--all-cities", action="store_true", help="全国（现在默认就是全国，保留兼容）")
    args = ap.parse_args()
    args.pattern = review.DEFAULT_PATTERNS
    if args.cities:
        db.DEFAULT_CITIES = [c.strip() for c in args.cities.split(",") if c.strip()]
    if args.all_cities:
        db.DEFAULT_CITIES = []
    print("检查 MySQL（第一次升级到新版本时会顺带升级数据，表大时要等一会，进度会打印在下面）…", flush=True)
    review.check_db()
    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
