"""景点图像识别数据：进入已审核 POI 的携程主页，在「用户点评」里一页页点「下一页」，
旁路读取页面自己发出的 getCommentCollapseList 返回，把点评图片写进 MySQL（scenic_poi_image）。

不自己调接口：翻页都是点页面上的「下一页」，请求由携程页面发出，这里只读返回。
"""
import asyncio
import random
import re
import time
from datetime import datetime, timedelta, timezone

import db

COMMENT_API = "getCommentCollapseList"
DATA_SOURCE = "OTA-图片爬取"
CN_TZ = timezone(timedelta(hours=8))


class NeedHuman(RuntimeError):
    """页面要求登录/验证，需要人处理后再继续。"""


def _num(v):
    try:
        f = float(v)
        return f if f == f else None
    except (TypeError, ValueError):
        return None


def parse_ms_date(v):
    """'/Date(1731476439000+0800)/' → '2024-11-13 13:40:39'（北京时间）。"""
    m = re.search(r"(\d{10,13})", str(v or ""))
    if not m:
        return None
    ts = int(m.group(1))
    if ts > 1e12:
        ts /= 1000
    return datetime.fromtimestamp(ts, CN_TZ).strftime("%Y-%m-%d %H:%M:%S")


def comment_result(js):
    """getCommentCollapseList 返回 → (items, totalCount)。"""
    res = (js or {}).get("result") or {}
    return res.get("items") or [], res.get("totalCount")


def rows_from_items(items, total, scenic, poi, collect_time, image_total=None):
    rows = []
    for it in items:
        for im in it.get("images") or []:
            if not im.get("imageSrcUrl"):
                continue
            rows.append(dict(
                poi_id=int(poi["poiId"]), poi_name=poi.get("poiName"),
                scenic_id=scenic["id"], scenic_name=scenic.get("name"),
                image_url=im.get("imageSrcUrl"), image_thumb_url=im.get("imageThumbUrl"),
                lon=_num(scenic.get("lng")), lat=_num(scenic.get("lat")),
                province=scenic.get("province"), city=scenic.get("city"), district=scenic.get("district"),
                total_count=image_total, comment_total=total, review_id=it.get("commentId"), ctrip_image_id=im.get("imageId"),
                # image_id / record_id 在 db.images_insert 里由图片链接算出
                width=im.get("width"), height=im.get("height"),
                review_score=_num(it.get("score")), review_publish_time=parse_ms_date(it.get("publishTime")),
                review_content=(it.get("content") or None), review_url=(it.get("jumpH5Url") or None),
                tourist_type=(it.get("touristTypeDisplay") or None),
                collect_time=collect_time, data_source=DATA_SOURCE, is_modified=0,
            ))
    return rows


# POI 主页上的图片总数（如「全部图片(105685)」「105685张图片」）。真实页面结构以 dump_page.py 抓到的为准，必要时在这里加规则
JS_IMAGE_TOTAL = """() => {
  const t = (document.body && document.body.innerText || '').replace(/\\s+/g, ' ');
  const pats = [/全部图片\\s*[（(]?\\s*(\\d[\\d,]*)/, /(\\d[\\d,]*)\\s*张图片/, /图片\\s*[（(]\\s*(\\d[\\d,]*)\\s*[)）]/,
                /相册\\s*[（(]?\\s*(\\d[\\d,]*)/, /查看全部\\s*(\\d[\\d,]*)\\s*张/];
  for (const p of pats) { const m = t.match(p); if (m) return parseInt(m[1].replace(/,/g, ''), 10); }
  return null;
}"""

# 携程 POI 主页是 Next.js 服务端渲染：第一页点评、图片总数都在 __NEXT_DATA__ 里（第一页不会发接口请求）
#   props.pageProps.initialState.commentList            第一页点评（结构同接口 result.items）
#   props.pageProps.initialState.commentTotalCount      点评总数（同接口 totalCount）
#   props.pageProps.initialState.poiDetail.poiId        页面对应的 poiId
#   props.pageProps.initialState.poiDetail.imageInfo.imageCount   POI 图片总数 → total_count
JS_SSR = """() => {
  const el = document.getElementById('__NEXT_DATA__');
  if (!el) return null;
  try {
    const st = JSON.parse(el.textContent).props.pageProps.initialState || {};
    const pd = st.poiDetail || {};
    return { poiId: pd.poiId ?? null, poiName: pd.poiName ?? null, imageCount: (pd.imageInfo || {}).imageCount ?? null,
             commentTotal: st.commentTotalCount ?? null, commentCount: pd.commentCount ?? null, items: st.commentList || null };
  } catch (e) { return null; }
}"""

JS_NEXT_STATE = """(el) => {
  const dis = (e) => e && ((e.className || '').toString().toLowerCase().includes('disabled') || e.getAttribute('aria-disabled') === 'true' || e.disabled);
  return { disabled: dis(el) || dis(el.parentElement) || dis(el.closest('li')), visible: !!(el.offsetWidth || el.offsetHeight) };
}"""


SKIP_MSG = "手动跳到下一个 POI"
NO_DATA_MSG = "该 POI 没有图片数据"


class CommentImageCrawler:
    def __init__(self, page, max_pages=20, max_images=300, page_delay=(1.5, 3.0), timeout_s=15.0, log=print,
                 empty_limit=10, on_progress=None):
        self.page, self.max_pages, self.max_images = page, max_pages, max_images
        self.page_delay, self.timeout_s, self.log = page_delay, timeout_s, log
        self.empty_limit = empty_limit  # 连续这么多页没有新图片就换下一个 POI（0 = 不限）
        self.on_progress = on_progress or (lambda stat: None)
        self.skipped = False

    def skip(self):
        """手动跳到下一个 POI：当前页处理完（或等待中）立即结束这个 POI。"""
        self.skipped = True

    async def _sleep(self, sec):
        end = time.monotonic() + sec
        while not self.skipped and time.monotonic() < end:
            await asyncio.sleep(min(0.2, max(0.0, end - time.monotonic())))

    async def _check_blocked(self):
        url = self.page.url.lower()
        title = (await self.page.title()) or ""
        if any(k in url for k in ("verify", "captcha", "passport.ctrip.com", "/login")) or any(k in title for k in ("验证", "登录")):
            raise NeedHuman(f"页面要求登录或验证（{self.page.url}），请在浏览器里处理后重新开始")

    async def _wait_new(self, captured, seen_n):
        """等到有新的 getCommentCollapseList 返回（可解析且带 result），返回其 JSON。"""
        deadline = time.monotonic() + self.timeout_s
        while time.monotonic() < deadline and not self.skipped:
            while seen_n[0] < len(captured):
                resp = captured[seen_n[0]]
                seen_n[0] += 1
                try:
                    js = await resp.json()
                except Exception:
                    continue
                # 接口返回了就算数：result 为空 / items 为空 → 上层判定「没有数据」立即换下一个 POI，不再干等
                if isinstance(js, dict) and ("result" in js or "items" in js):
                    return js if "result" in js else {"result": js}
            await asyncio.sleep(0.2)
        return None

    async def _next_button(self):
        for loc in (self.page.get_by_text("下一页", exact=True), self.page.locator("text=下一页")):
            n = await loc.count()
            for i in range(n - 1, -1, -1):  # 一般页面上只有一个；有多个时取最后一个（在点评区底部）
                el = loc.nth(i)
                try:
                    st = await el.evaluate(JS_NEXT_STATE)
                except Exception:
                    continue
                if st["visible"]:
                    return el, st["disabled"]
        return None, True

    async def crawl(self, target, should_stop=lambda: False):
        """target = {scenic: {...}, poi: {poiId, poiName, poiUri, ...}}；返回统计。"""
        scenic, poi = target["scenic"], target["poi"]
        sid, pid = scenic["id"], int(poi["poiId"])
        page = self.page
        captured, seen_n = [], [0]
        on_resp = lambda r: captured.append(r) if COMMENT_API in r.url else None  # noqa: E731
        page.on("response", on_resp)
        stat = dict(pages=0, reviews=0, images=0, total=None, stop="", empty_run=0)
        self.skipped = False
        db.crawl_put(sid, pid, poi_name=poi.get("poiName"), poi_uri=poi.get("poiUri"), status="running", message=None)
        try:
            resp = await page.goto(poi["poiUri"], wait_until="domcontentloaded", timeout=30000)
            await self._check_blocked()
            if resp is not None and resp.status >= 400:
                stat["stop"] = f"页面打不开（HTTP {resp.status}），换下一个 POI"
                return stat
            if self.skipped:
                stat["stop"] = SKIP_MSG
                return stat
            # 第一页：优先读服务端渲染的 __NEXT_DATA__；没有时退回「滚到点评区等接口返回」
            ssr = None
            try:
                ssr = await page.evaluate(JS_SSR)
            except Exception:
                pass
            if ssr and ssr.get("poiId") and str(ssr["poiId"]) != str(pid):
                stat["stop"] = f"页面上的 poiId={ssr['poiId']}（{ssr.get('poiName')}）与预期 {pid} 不符，未采集（poiUri 可能指向了别的 POI）"
                return stat
            # 页面数据里明确没有图片 / 没有点评：不翻页，立即换下一个 POI
            if ssr and ssr.get("imageCount") == 0:
                stat["image_total"] = 0
                stat["stop"] = NO_DATA_MSG + "（页面图片总数 0），换下一个 POI"
                return stat
            if ssr and (ssr.get("commentTotal") == 0 or ssr.get("items") == []):
                stat["stop"] = NO_DATA_MSG + "（页面没有点评），换下一个 POI"
                return stat
            js = None
            if ssr and ssr.get("items") is not None:
                js = {"result": {"items": ssr["items"], "totalCount": ssr.get("commentTotal")}}
            else:
                # 页面里没有 __NEXT_DATA__ 点评：滚几下等接口返回，约 5 秒没有就放弃（不再长时间等待）
                for _ in range(8):
                    js = await self._wait_new(captured, seen_n) if captured[seen_n[0]:] else None
                    if js or self.skipped:
                        break
                    await page.mouse.wheel(0, random.randint(600, 1000))
                    await page.wait_for_timeout(random.randint(300, 500))
                if not js and not self.skipped:
                    old_t, self.timeout_s = self.timeout_s, 2.0
                    try:
                        js = await self._wait_new(captured, seen_n)
                    finally:
                        self.timeout_s = old_t
            if self.skipped:
                stat["stop"] = SKIP_MSG
                return stat
            if not js:
                stat["stop"] = "没读到第一页点评：页面没有返回点评数据，换下一个 POI（若很多 POI 都这样，可能是页面结构变了：用 dump_page.py 抓页面结构）"
                return stat
            last_ids = None
            collect_time = datetime.now(CN_TZ).strftime("%Y-%m-%d %H:%M:%S")
            image_total = (ssr or {}).get("imageCount")
            if image_total is None:
                try:
                    image_total = await page.evaluate(JS_IMAGE_TOTAL)
                except Exception:
                    image_total = None
            stat["image_total"] = image_total
            while True:
                items, total = comment_result(js)
                ids = [it.get("commentId") for it in items]
                if not items:
                    stat["stop"] = (NO_DATA_MSG + "（接口返回 items 为空），换下一个 POI") if stat["pages"] == 0 \
                        else "没有更多点评（接口返回 items 为空）"
                    break
                if ids == last_ids:
                    stat["stop"] = "翻页后内容没变，停止"
                    break
                last_ids = ids
                stat["pages"] += 1
                stat["reviews"] += len(items)
                stat["total"] = total
                new = db.images_insert(rows_from_items(items, total, scenic, poi, collect_time, image_total))
                stat["images"] += new
                stat["empty_run"] = 0 if new else stat["empty_run"] + 1
                db.crawl_put(sid, pid, pages_done=stat["pages"], total_count=total, review_qty=stat["reviews"], image_qty=stat["images"])
                self.on_progress(stat)
                if self.skipped:
                    stat["stop"] = SKIP_MSG
                    break
                if self.empty_limit and stat["empty_run"] >= self.empty_limit:
                    stat["stop"] = f"连续 {self.empty_limit} 页没有新图片，换下一个 POI"
                    break
                if stat["pages"] >= self.max_pages:
                    stat["stop"] = f"到达最大页数 {self.max_pages}"
                    break
                if self.max_images and stat["images"] >= self.max_images:
                    stat["stop"] = f"到达最大图片数 {self.max_images}"
                    break
                if should_stop():
                    stat["stop"] = "已取消"
                    break
                btn, disabled = await self._next_button()
                if btn is None or disabled:
                    stat["stop"] = "已是最后一页"
                    break
                await self._sleep(random.uniform(*self.page_delay))
                if self.skipped:
                    stat["stop"] = SKIP_MSG
                    break
                await btn.scroll_into_view_if_needed()
                await btn.click()
                js = await self._wait_new(captured, seen_n)
                if self.skipped and not js:
                    stat["stop"] = SKIP_MSG
                    break
                if not js:
                    await self._check_blocked()
                    stat["stop"] = "点「下一页」后没等到点评返回"
                    break
            return stat
        finally:
            page.remove_listener("response", on_resp)
            ok = stat["stop"] and not stat["stop"].startswith(("没读到", "点「下一页」后", "已取消", "页面上的 poiId", "页面打不开"))
            db.crawl_put(sid, pid, status="done" if ok else ("failed" if stat["pages"] == 0 else "partial"),
                         message=stat["stop"] or "中断")


async def crawl_all(get_page, f, max_pages=20, max_images=300, limit=0, refresh=False, poi_delay=(2.0, 4.0),
                    log=print, should_stop=lambda: False, progress=lambda done, total: None,
                    empty_limit=10, on_crawler=None):
    """对筛选范围内已审核的景区，逐个 POI 采集点评图片。get_page 为 async 函数，返回可用的 Playwright page。"""
    st0 = {}
    targets = db.crawl_targets(f, refresh=refresh, stats=st0)
    if limit:
        targets = targets[:limit]
    total = len(targets)
    skipped = st0.get("skipped") or 0
    log(f"待采集 POI：{total} 个（每个最多 {max_pages} 页 / {max_images} 张）"
        + (f"；{skipped} 个之前采过，跳过（要重采请勾「重采」/ --refresh）" if skipped else ""))
    stats = dict(pois=0, images=0, failed=0)
    page = None
    for i, t in enumerate(targets, 1):
        if should_stop():
            log("已取消")
            break
        page = page or await get_page()
        crawler = CommentImageCrawler(page, max_pages=max_pages, max_images=max_images, log=log, empty_limit=empty_limit)
        if on_crawler:
            on_crawler(crawler, t)
        name = f"{t['scenic']['name']} / {t['poi'].get('poiName')}（poiId {t['poi']['poiId']}）"
        try:
            st = await crawler.crawl(t, should_stop)
            stats["pois"] += 1
            stats["images"] += st["images"]
            log(f"[{i}/{total}] {name}：{st['pages']} 页，点评 {st['reviews']}/{st['total']}，新增图片 {st['images']}"
                f"（主页图片总数 {st.get('image_total') if st.get('image_total') is not None else '未读到'}）；{st['stop']}")
        except NeedHuman as e:
            log(f"[{i}/{total}] {name}：{e}")
            raise
        except Exception as e:
            stats["failed"] += 1
            log(f"[{i}/{total}] {name}：失败 {type(e).__name__}: {e}")
        finally:
            if on_crawler:
                on_crawler(None, None)
        progress(i, total)
        await asyncio.sleep(random.uniform(*poi_delay))
    log(f"完成：POI {stats['pois']} 个，新增图片 {stats['images']} 张，失败 {stats['failed']}")
    return stats


__all__ = ["CommentImageCrawler", "crawl_all", "rows_from_items", "comment_result", "parse_ms_date", "NeedHuman"]
