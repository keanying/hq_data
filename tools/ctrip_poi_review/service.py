"""携程 POI 核对 / 景点图像采集 —— 常驻服务。

    python service.py --channel chrome            # 默认 http://127.0.0.1:8800 ，浏览器打开控制台
    python service.py --all-cities --port 8800

- 任务队列：自动审核（auto_review）、点评图片采集（images）按提交顺序逐个执行（共用一个浏览器，避免并发被限流）
- 每个任务有进度、日志、可取消；遇到登录/验证会停在「需要人工」，浏览器窗口保持打开，处理后重新提交即可
- 人工核对仍用 `python review.py run`（带面板的浏览器）；服务用独立的浏览器目录，两者可以同时开
"""
import argparse
import asyncio
import collections
import itertools
import time
import traceback
from pathlib import Path
from types import SimpleNamespace

import uvicorn
from fastapi import Body, FastAPI, HTTPException
from fastapi.responses import HTMLResponse

import crawler
import db
import review

HERE = Path(__file__).resolve().parent
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
        self.browser = review.LazyBrowser(args)
        self.current: Job | None = None

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
            ns = SimpleNamespace(city=p.get("city") or "", grade=p.get("grade") or "", q=p.get("q") or "",
                                 limit=int(p.get("limit") or 0), no_alias=bool(p.get("no_alias")), spots=bool(p.get("spots")),
                                 max_extra=int(p.get("max_extra") or 8), cache_only=bool(p.get("cache_only")),
                                 dry_run=bool(p.get("dry_run")), verbose=bool(p.get("verbose", True)),
                                 reviewer=p.get("reviewer") or "auto", max_fail=5)
            return await review.auto_review(ns, self.browser.get_searcher, log=job.write, should_stop=stop, progress=progress)
        if job.type == "images":
            f = dict(city=p.get("city") or "", grade=p.get("grade") or "", q=p.get("q") or "")
            return await crawler.crawl_all(self.browser.get_page, f, max_pages=int(p.get("max_pages") or 20),
                                           max_images=int(p.get("max_images") if p.get("max_images") not in (None, "") else 300),
                                           limit=int(p.get("limit") or 0), refresh=bool(p.get("refresh")),
                                           log=job.write, should_stop=stop, progress=progress)
        raise ValueError(f"未知任务类型 {job.type}")


def create_app(args):
    svc = Service(args)
    app = FastAPI(title="携程 POI 核对 / 景点图像采集服务")

    @app.on_event("startup")
    async def _start():
        review.check_db()
        asyncio.get_running_loop().create_task(svc.worker())

    @app.on_event("shutdown")
    async def _stop():
        await svc.browser.close()

    @app.get("/", response_class=HTMLResponse)
    def dashboard():
        return (HERE / "dashboard.html").read_text(encoding="utf-8")

    @app.get("/api/health")
    def health():
        return dict(db.health(), current_job=svc.current.id if svc.current else None, queued=svc.queue.qsize())

    @app.get("/api/stats")
    def stats():
        return dict(cities=db.cities(), images=db.image_stats())

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
    def images(scenic_id: str = "", poi_id: str = "", limit: int = 60, offset: int = 0):
        return db.images_query(scenic_id or None, poi_id or None, min(max(limit, 1), 500), max(offset, 0))

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
    ap.add_argument("--all-cities", action="store_true", help="全国所有城市（默认只 CITIES 的 7 城）")
    args = ap.parse_args()
    args.pattern = review.DEFAULT_PATTERNS
    if args.all_cities:
        db.DEFAULT_CITIES = []
    print(f"服务启动：http://{args.host}:{args.port}  （浏览器打开即是控制台）", flush=True)
    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
