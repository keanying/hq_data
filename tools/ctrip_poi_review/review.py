"""携程 POI 人工核对：用 Playwright 打开真实浏览器，模拟人在携程搜索框里输入景区名，
读取页面下拉框的结果，在右侧面板里人工确认保留哪些携程 POI，结果写回 MySQL。

不自己调用携程接口：搜索请求都是携程页面在你输入后自己发出的，
本工具只是旁路读取该请求的返回（读不到时退回读下拉框 DOM）。

用法：
    python review.py run                 # 交互核对（默认）
    python review.py prefetch --grade 5A,4A   # 批量预搜索，结果进缓存表，核对时秒开
    python review.py export -o mapping.csv    # 导出 scenic_id -> ctrip_poi_id 列表
"""
import argparse
import asyncio
import csv
import json
import random
import re
import sys
import time
from pathlib import Path

from playwright.async_api import async_playwright

import db

HERE = Path(__file__).resolve().parent
DEFAULT_START_URL = "https://you.ctrip.com/"
DEFAULT_PATTERNS = ["/restapi/soa2/30668/search"]
# 携程页面改版时可能变化；都找不到时会自动挑页面顶部最宽的输入框，或在面板里「定位搜索框」手动点一下
DEFAULT_INPUT_SELECTORS = [
    "#_allSearchKeyword",
    "input[placeholder*='搜索']",
    "input[placeholder*='目的地']",
    "input[placeholder*='景点']",
    "header input[type='text']",
    "input[type='search']",
]


# ---------------------------------------------------------------- 解析
def _num(v):
    try:
        f = float(v)
        return f if f == f else None
    except (TypeError, ValueError):
        return None


def _find_list(o, depth=0):
    if not isinstance(o, dict) or depth > 4:
        return None
    for v in o.values():
        if isinstance(v, list) and v and isinstance(v[0], dict) and ({"word", "name", "poiId"} & set(v[0])):
            return v
    for v in o.values():
        r = _find_list(v, depth + 1)
        if r:
            return r
    return None


SIGHT_URL = re.compile(r"/sight/[^/]+/(\d+)\.html", re.I)


def parse_items(js):
    """携程搜索返回：{"data":[{"id":758,"word":"上海野生动物园","type":"sight","url":".../758.html","poiId":75624,...}], "total":15}"""
    arr = js.get("data") if isinstance(js.get("data"), list) else (_find_list(js) or [])
    out = []
    for i, it in enumerate(arr, 1):
        url = re.sub(r"^http://", "https://", str(it.get("url") or it.get("jumpUrl") or ""))
        m = SIGHT_URL.search(url)
        biz = m.group(1) if m else (str(it["id"]) if it.get("type") == "sight" and it.get("id") is not None else None)
        poi = str(it["poiId"]) if it.get("poiId") not in (None, 0, "", "0") else None
        out.append(dict(
            idx=i, name=re.sub(r"<[^>]+>", "", str(it.get("word") or it.get("name") or it.get("title") or "")),
            type=it.get("type") or "", childType=it.get("childType") or "",
            poiId=poi, businessId=biz, url=url,
            lat=_num(it.get("lat")), lng=_num(it.get("lon", it.get("lng"))),
            cityName=it.get("cityName") or "", districtName=it.get("districtName") or "",
            isSight=(it.get("type") == "sight") or bool(m),
            key=f"poi:{poi}" if poi else (f"biz:{biz}" if biz else None),
            raw=it,
        ))
    return out


def dom_to_items(dom):
    out = []
    for i, d in enumerate(dom, 1):
        m = SIGHT_URL.search(d.get("href") or "")
        biz = m.group(1) if m else None
        out.append(dict(idx=i, name=d.get("text", ""), type="dom", childType="", poiId=None, businessId=biz,
                        url=(d.get("href") or "").replace("http://", "https://"), lat=None, lng=None,
                        cityName="", districtName="", isSight=bool(m), key=f"biz:{biz}" if biz else None,
                        raw=d))
    return out


# ---------------------------------------------------------------- 页面内 JS
JS_PICK_INPUT = """() => {
  const vis = (el) => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el);
    return r.width > 80 && r.height > 14 && s.visibility !== 'hidden' && s.display !== 'none'; };
  const ins = [...document.querySelectorAll('input')].filter((el) =>
    ['text', 'search', ''].includes((el.getAttribute('type') || '').toLowerCase()) && vis(el) && el.getBoundingClientRect().top < 260);
  ins.sort((a, b) => b.getBoundingClientRect().width - a.getBoundingClientRect().width);
  if (!ins.length) return null;
  const el = ins[0];
  el.setAttribute('data-hq-search', '1');
  return '[data-hq-search="1"]';
}"""

JS_CSS_PATH = """(el) => {
  if (el.id) return '#' + CSS.escape(el.id);
  const parts = [];
  while (el && el.nodeType === 1 && el !== document.body) {
    let s = el.tagName.toLowerCase();
    if (el.id) { parts.unshift('#' + CSS.escape(el.id)); break; }
    const sib = [...el.parentNode.children].filter((x) => x.tagName === el.tagName);
    if (sib.length > 1) s += ':nth-of-type(' + (sib.indexOf(el) + 1) + ')';
    parts.unshift(s); el = el.parentNode;
  }
  return parts.join(' > ');
}"""

JS_WAIT_CLICK = """() => new Promise((resolve) => {
  const h = (e) => {
    const el = e.target.closest('input,textarea');
    if (!el) return;
    document.removeEventListener('click', h, true);
    resolve(el.id ? '#' + CSS.escape(el.id) : null);
    window.__hqPicked = el;
  };
  document.addEventListener('click', h, true);
})"""

JS_DOM_DROPDOWN = """(sel) => {
  const inp = document.querySelector(sel); if (!inp) return [];
  const ir = inp.getBoundingClientRect();
  const out = [], seen = new Set();
  for (const el of document.querySelectorAll('a, li, [role=option]')) {
    const r = el.getBoundingClientRect();
    if (r.width < 40 || r.height < 12 || r.height > 140) continue;
    if (r.top < ir.bottom - 2 || r.top > ir.bottom + 900) continue;
    if (r.left < ir.left - 120 || r.left > ir.right + 120) continue;
    const s = getComputedStyle(el); if (s.visibility === 'hidden' || s.display === 'none') continue;
    const text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
    if (!text || text.length > 120) continue;
    const a = el.tagName === 'A' ? el : el.querySelector('a[href]');
    const href = a ? a.href : '';
    const k = text + '|' + href; if (seen.has(k)) continue; seen.add(k);
    out.push({ text, href });
    if (out.length >= 40) break;
  }
  return out;
}"""


# ---------------------------------------------------------------- 搜索（模拟人工输入）
class CtripSearcher:
    def __init__(self, page, prefs, start_url, patterns, timeout_s=10.0):
        self.page, self.prefs, self.start_url, self.patterns, self.timeout_s = page, prefs, start_url, patterns, timeout_s
        self.lock = asyncio.Lock()
        self.last_at = 0.0

    async def _input(self):
        page = self.page
        cands = ([self.prefs["input_selector"]] if self.prefs.get("input_selector") else []) + DEFAULT_INPUT_SELECTORS
        for sel in cands:
            try:
                loc = page.locator(sel).first
                if await loc.count() and await loc.is_visible():
                    return sel
            except Exception:
                pass
        sel = await page.evaluate(JS_PICK_INPUT)
        if sel:
            return sel
        if not page.url.startswith(self.start_url.rstrip("/")):
            await page.goto(self.start_url, wait_until="domcontentloaded")
            await page.wait_for_timeout(1500)
            return await self._input()
        raise RuntimeError("页面上找不到搜索框：请在面板 ⚙ 里点「定位搜索框」，再点一下携程的搜索框")

    async def locate_input(self):
        """让用户在页面上点一下搜索框，记住它的选择器。"""
        sel = await self.page.evaluate(JS_WAIT_CLICK)
        if not sel:
            sel = await self.page.evaluate("() => (" + JS_CSS_PATH + ")(window.__hqPicked)")
        self.prefs["input_selector"] = sel
        return sel

    async def search(self, kw):
        kw = kw.strip()
        async with self.lock:
            gap = self.prefs.get("throttle_ms", 2500) / 1000 * random.uniform(1.0, 1.4)
            wait = self.last_at + gap - time.monotonic()
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                return await self._search(kw)
            finally:
                self.last_at = time.monotonic()

    async def _search(self, kw):
        page = self.page
        sel = await self._input()
        captured = []

        def on_resp(resp):
            if any(p in resp.url for p in self.patterns):
                captured.append(resp)

        page.on("response", on_resp)
        try:
            inp = page.locator(sel).first
            await inp.scroll_into_view_if_needed()
            try:
                await inp.click(timeout=3000)
            except Exception:  # 被面板等元素挡住时退回聚焦
                await inp.focus()
            for attempt in range(2):
                await self._type(inp, kw)
                if (await inp.input_value()).strip() == kw:
                    break
                captured.clear()  # 输入被打断（比如中途点了别处），清空重输一次
            best, fallback, checked = None, None, set()
            deadline = time.monotonic() + self.timeout_s
            while time.monotonic() < deadline and best is None:
                for resp in reversed(captured):
                    if id(resp) in checked:
                        continue
                    checked.add(id(resp))
                    try:
                        js = await resp.json()
                    except Exception:
                        continue
                    fallback = fallback or js
                    if self._matches(js, resp.request.post_data, kw):
                        best = js
                        break
                if best is None:
                    await asyncio.sleep(0.2)
            await page.wait_for_timeout(400)  # 等下拉框渲染完
            dom = await page.evaluate(JS_DOM_DROPDOWN, sel)
        finally:
            page.remove_listener("response", on_resp)
            try:
                await page.evaluate("() => document.activeElement && document.activeElement.blur()")
            except Exception:
                pass
        js = best or fallback
        items = parse_items(js) if js else []
        capture = "network" if best else ("network?" if fallback else "dom")
        if not items and dom:
            items = dom_to_items(dom)
        return dict(keyword=kw, capture=capture, total=(js or {}).get("total"), items=items, dom=dom,
                    searched_at=time.strftime("%Y-%m-%d %H:%M:%S"))

    async def _type(self, inp, kw):
        page = self.page
        await page.keyboard.press("ControlOrMeta+A")
        await page.keyboard.press("Backspace")
        await page.wait_for_timeout(random.randint(150, 350))
        for ch in kw:  # 一个字一个字敲，节奏接近人工；焦点被抢走时先点回搜索框
            if not await inp.evaluate("(el) => document.activeElement === el"):
                await inp.focus()
            await page.keyboard.type(ch)
            await asyncio.sleep(random.uniform(0.08, 0.22))

    @staticmethod
    def _matches(js, post_data, kw):
        nlp = (js.get("nlpResult") or {}).get("keyword") if isinstance(js, dict) else None
        if nlp is not None:
            return nlp == kw
        if post_data:
            try:
                return kw in json.dumps(json.loads(post_data), ensure_ascii=False)
            except Exception:
                return kw in post_data
        return False


# ---------------------------------------------------------------- 偏好设置
class Prefs(dict):
    def __init__(self, path):
        super().__init__(reviewer="", throttle_ms=2500, sight_only=False, auto_search=True, input_selector="",
                         filters=dict(city="", grade="", status="todo", q=""))
        self.path = path
        if path.exists():
            self.update(json.loads(path.read_text(encoding="utf-8")))

    def save(self):
        self.path.write_text(json.dumps(self, ensure_ascii=False, indent=2), encoding="utf-8")


# ---------------------------------------------------------------- 浏览器
def check_db():
    problems = db.preflight()
    if problems:
        print("MySQL 自检没通过：", file=sys.stderr)
        for p in problems:
            print("  - " + p, file=sys.stderr)
        raise SystemExit(1)
    db.init_db()
    h = db.health()
    try:  # 关联查询也跑一遍，排序规则/权限之类的问题在启动时就暴露
        db.cities()
        db.scenic_list({}, 0, 1)
    except Exception as e:
        print(f"MySQL 自检没通过：关联查询出错 {type(e).__name__}: {e}", file=sys.stderr)
        raise SystemExit(1)
    print(f"MySQL 正常：客户景区表 {db.SCENIC_TABLE} 共 {h['scenic_rows']} 行；默认城市 {','.join(h['cities']) or '全部'}；"
          f"离线候选表{'已导入' if h['candidate_table'] else '未导入（可选）'}", flush=True)


async def launch(pw, args):
    profile = Path(args.profile).resolve()
    profile.mkdir(parents=True, exist_ok=True)
    kw = dict(headless=args.headless, locale="zh-CN", timezone_id="Asia/Shanghai")
    if args.channel:
        kw["channel"] = args.channel
    if args.executable_path:
        kw["executable_path"] = args.executable_path
    if args.headless:
        kw["viewport"] = {"width": 1600, "height": 1000}
    else:
        kw["no_viewport"] = True
        kw["args"] = ["--start-maximized"]
    ctx = await pw.chromium.launch_persistent_context(str(profile), **kw)
    page = ctx.pages[0] if ctx.pages else await ctx.new_page()
    return ctx, page, Prefs(profile / "hq_prefs.json")


async def setup_run(pw, args):
    """打开浏览器、注入核对面板，返回 (context, page)。"""
    check_db()
    ctx, page, prefs = await launch(pw, args)
    searcher = CtripSearcher(page, prefs, args.start_url, args.pattern)

    async def handler(source, method, payload=None):
        payload = payload or {}
        try:
            if method == "hello":
                if source["page"] is not page or source["frame"] is not page.main_frame:
                    return dict(main=False)
                res = dict(main=True, prefs=dict(prefs), health=db.health(), cities=db.cities())
                print(f"[hq] 面板已加载：{page.url}（右下角点「POI核对」）", flush=True)
                return res
            if method == "list":
                return db.scenic_list(payload.get("filters") or {}, payload.get("offset", 0), payload.get("limit", 200))
            if method == "detail":
                return db.scenic_detail(payload["scenic_id"])
            if method == "decision":
                return db.set_decision(payload)
            if method == "status":
                return db.set_status(payload)
            if method == "prefs":
                prefs.update({k: v for k, v in payload.items() if k in prefs})
                prefs.save()
                return dict(prefs)
            if method == "locate_input":
                sel = await searcher.locate_input()
                prefs.save()
                return dict(selector=sel)
            if method == "search":
                kwd = payload["keyword"].strip()
                if not payload.get("force"):
                    hit = db.cache_get(kwd)
                    if hit and hit.get("result"):
                        return dict(hit["result"], cached=True, searched_at=hit["searched_at"])
                res = await searcher.search(kwd)
                db.cache_put(kwd, res)
                return res
            if method == "export":
                out = HERE / f"scenic_ctrip_poi_mapping_{time.strftime('%Y%m%d_%H%M%S')}.csv"
                write_csv(out, db.export_rows())
                return dict(path=str(out))
            raise ValueError(f"未知方法 {method}")
        except Exception as e:  # 错误回传到面板显示，同时打印到终端
            print(f"[面板调用 {method} 出错] {type(e).__name__}: {e}", file=sys.stderr, flush=True)
            return dict(error=f"{type(e).__name__}: {e}")

    await ctx.expose_binding("hqCall", handler)
    await ctx.add_init_script(script=(HERE / "panel.js").read_text(encoding="utf-8"))
    page.on("console", lambda m: print(m.text, flush=True) if m.text.startswith("[hq]") else None)
    await page.goto(args.start_url, wait_until="domcontentloaded")
    return ctx, page


async def cmd_run(args):
    async with async_playwright() as pw:
        ctx, page = await setup_run(pw, args)
        print(f"浏览器已打开 {args.start_url} ，在右下角点「POI核对」开始。关闭浏览器窗口即退出。")
        await page.wait_for_event("close", timeout=0)
        await ctx.close()


async def cmd_prefetch(args):
    check_db()
    filters = dict(city=args.city or "", grade=args.grade or "", status=args.status, q=args.q or "")
    async with async_playwright() as pw:
        ctx, page, prefs = await launch(pw, args)
        if args.throttle_ms:
            prefs["throttle_ms"] = args.throttle_ms
        searcher = CtripSearcher(page, prefs, args.start_url, args.pattern)
        await page.goto(args.start_url, wait_until="domcontentloaded")
        await page.wait_for_timeout(2000)
        offset, done, skipped, failed, streak = 0, 0, 0, 0, 0
        try:
            while True:
                r = db.scenic_list(filters, offset, 200)
                if not r["items"]:
                    break
                for s in r["items"]:
                    if args.limit and done >= args.limit:
                        break
                    kws = [s["name"]] + ([a.strip() for a in re.split(r"[,，、;；/]", s.get("alias") or "") if a.strip()] if args.alias else [])
                    for kwd in dict.fromkeys(kws):
                        if not args.refresh and db.cache_get(kwd):
                            skipped += 1
                            continue
                        try:
                            res = await searcher.search(kwd)
                            db.cache_put(kwd, res)
                            done += 1
                            streak = 0
                            print(f"[{done + skipped + failed}/{r['total']}] {s['id']} {kwd} -> {len(res['items'])} 条 ({res['capture']})", flush=True)
                        except Exception as e:
                            failed += 1
                            streak += 1
                            print(f"[失败] {s['id']} {kwd}: {e}", flush=True)
                            if streak >= args.max_fail:
                                raise SystemExit(f"连续失败 {streak} 次，停止。可能被限流或出现验证码，请在浏览器里处理后重跑。")
                offset += len(r["items"])
                if args.limit and done >= args.limit:
                    break
        finally:
            print(f"完成：新搜索 {done}，已有缓存跳过 {skipped}，失败 {failed}")
            await ctx.close()


def write_csv(path, rows):
    cols = ["scenic_id", "scenic_name", "city_name", "status", "kept_qty", "ctrip_poi_id_list", "ctrip_business_id_list", "ctrip_poi_name_list"]
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)


def cmd_export(args):
    rows = db.export_rows()
    write_csv(args.output, rows)
    print(f"导出 {len(rows)} 个景区 -> {args.output}")


def build_parser():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")

    def browser_opts(p):
        p.add_argument("--profile", default=str(HERE / ".pw-profile"), help="浏览器用户目录（保存携程登录态）")
        p.add_argument("--channel", default="", help="用本机浏览器：chrome / msedge；留空用 Playwright 自带 Chromium")
        p.add_argument("--executable-path", default="", help="指定浏览器可执行文件路径")
        p.add_argument("--headless", action="store_true", help="无界面运行（不建议，携程更容易弹验证）")
        p.add_argument("--start-url", default=DEFAULT_START_URL)
        p.add_argument("--pattern", action="append", default=None, help="要旁路读取的携程搜索请求 URL 片段，可多次指定")

    p = sub.add_parser("run", help="交互核对（默认）")
    browser_opts(p)
    p = sub.add_parser("prefetch", help="批量预搜索，结果写入缓存表")
    browser_opts(p)
    p.add_argument("--city", help="城市，逗号分隔；默认 CITIES 环境变量的 7 城")
    p.add_argument("--grade", help="等级，如 5A,4A")
    p.add_argument("--status", default="todo", choices=["todo", "done", "skip", "all"])
    p.add_argument("--q", help="景区名/ID 过滤")
    p.add_argument("--alias", action="store_true", help="别名也搜一遍")
    p.add_argument("--refresh", action="store_true", help="已有缓存也重新搜")
    p.add_argument("--limit", type=int, default=0, help="最多新搜索多少次（0=不限）")
    p.add_argument("--throttle-ms", type=int, default=0, help="两次搜索最小间隔（毫秒），默认读设置 2500")
    p.add_argument("--max-fail", type=int, default=5, help="连续失败多少次就停止（可能被限流/出验证码）")
    p = sub.add_parser("export", help="导出最终映射 CSV")
    p.add_argument("-o", "--output", default="scenic_ctrip_poi_mapping.csv")
    return ap


def main(argv=None):
    ap = build_parser()
    argv = sys.argv[1:] if argv is None else argv
    if not argv or (argv[0].startswith("-") and argv[0] not in ("-h", "--help")):
        argv = ["run"] + list(argv)
    args = ap.parse_args(argv)
    if getattr(args, "pattern", "x") is None:
        args.pattern = DEFAULT_PATTERNS
    if args.cmd == "export":
        cmd_export(args)
    elif args.cmd == "prefetch":
        asyncio.run(cmd_prefetch(args))
    else:
        asyncio.run(cmd_run(args))


if __name__ == "__main__":
    main()
