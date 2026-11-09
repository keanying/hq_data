"""携程 POI 人工核对：用 Playwright 打开真实浏览器，模拟人在携程搜索框里输入景区名，
读取页面下拉框的结果，在右侧面板里人工确认保留哪些携程 POI，结果写回 MySQL。

不自己调用携程接口：搜索请求都是携程页面在你输入后自己发出的，
本工具只是旁路读取该请求的返回（读不到时退回读下拉框 DOM）。

用法：
    python review.py run                 # 交互核对（默认）
    python review.py prefetch --grade 5A,4A   # 批量预搜索，结果进缓存表，核对时秒开
    python review.py auto --grade 5A,4A       # 批量自动审核：名称一致且地址相近的直接通过
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
import match

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


NAME_KEYS = ("word", "name", "poiName", "title", "displayName", "keyword", "text")
SKIP_KEYS = {"ResponseStatus", "nlpResult", "jumpInfo", "extendInfo", "highLights", "head"}
SIGHT_URL = re.compile(r"/sight/[^/]+/(\d+)\.html", re.I)
POI_TYPES = {"sight", "shop", "shopping", "play", "entertainment", "restaurant", "food", "poi", "scenic",
             "景点", "购物", "玩乐", "娱乐", "美食"}


def _looks_item(d):
    return isinstance(d, dict) and any(isinstance(d.get(k), str) and d.get(k).strip() for k in NAME_KEYS)


def _collect_lists(o, out, depth=0):
    if depth > 6:
        return
    if isinstance(o, dict):
        for k, v in o.items():
            if k not in SKIP_KEYS:
                _collect_lists(v, out, depth + 1)
    elif isinstance(o, list):
        items = [x for x in o if _looks_item(x)]
        if items and len(items) * 2 >= len(o):
            out.append(items)  # 认定为结果列表，不再往条目内部找
            return
        for v in o:
            _collect_lists(v, out, depth + 1)


def find_items(js):
    """找出返回里的结果条目：优先 data[]，否则收集所有「像结果」的列表（兼容按类型分组的结构）。"""
    if isinstance(js, dict) and isinstance(js.get("data"), list) and any(_looks_item(x) for x in js["data"]):
        return [x for x in js["data"] if _looks_item(x)]
    lists = []
    _collect_lists(js, lists)
    seen, flat = set(), []
    for lst in lists:
        for x in lst:
            if id(x) not in seen:
                seen.add(id(x))
                flat.append(x)
    return flat


def parse_body(text):
    """JSON 或 JSONP（callback({...})）。"""
    t = (text or "").strip()
    if not t or t[0] not in "{[" and "(" not in t[:200]:
        return None
    try:
        return json.loads(t)
    except Exception:
        pass
    m = re.match(r"^[\w$.\[\]'\"]+\s*\(\s*([\s\S]*)\)\s*;?\s*$", t)
    if m:
        try:
            return json.loads(m.group(1))
        except Exception:
            return None
    return None


def parse_items(js):
    """携程搜索返回示例：{"data":[{"id":758,"word":"上海野生动物园","type":"sight","url":".../758.html","poiId":75624,...}], "total":15}"""
    out = []
    for i, it in enumerate(find_items(js), 1):
        url = str(it.get("url") or it.get("jumpUrl") or it.get("h5Url") or it.get("pcUrl") or "")
        url = re.sub(r"^//", "https://", url)
        url = re.sub(r"^http://(?=([a-z0-9-]+\.)*ctrip\.com)", "https://", url)
        m = SIGHT_URL.search(url)
        typ = str(it.get("type") or it.get("typeName") or it.get("category") or "")
        is_sight = typ.lower() in ("sight", "poi", "scenic", "景点") or bool(m)
        biz = m.group(1) if m else None
        biz = biz or next((str(it[k]) for k in ("businessId", "sightId") if it.get(k) not in (None, 0, "", "0")), None)
        if not biz and is_sight and it.get("id") not in (None, 0, "", "0"):
            biz = str(it["id"])
        poi = next((str(it[k]) for k in ("poiId", "poiid", "poi_id") if it.get(k) not in (None, 0, "", "0")), None)
        name = next((str(it[k]) for k in NAME_KEYS if isinstance(it.get(k), str) and it.get(k).strip()), "")
        out.append(dict(
            idx=i, name=re.sub(r"<[^>]+>", "", name),
            type=typ, childType=it.get("childType") or "",
            poiId=poi, businessId=biz, url=url,
            lat=_num(it.get("lat")), lng=_num(it.get("lon", it.get("lng"))),
            cityName=it.get("cityName") or "", districtName=it.get("districtName") or "",
            isSight=is_sight,
            isPoi=bool(poi) or is_sight or typ.lower() in POI_TYPES,  # 景点/购物/玩乐等都算 POI，参与核对
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


JS_DETAIL_ADDRESS = """() => {
  const t = (document.body && document.body.innerText) || '';
  const m = t.match(/(?:^|\\n)\\s*地址\\s*[:：]?\\s*\\n?\\s*([^\\n]{4,120})/);
  return { address: m ? m[1].trim() : null, title: document.title };
}"""

ADDR_KEYS = ("address", "addr", "poiAddress", "locationName", "location")


def item_address(it):
    raw = it.get("raw") or {}
    for k in ADDR_KEYS:
        v = raw.get(k)
        if isinstance(v, str) and len(v.strip()) >= 4:
            return v.strip()
    return None


def enrich(items, poi_key="poiId", biz_key="businessId"):
    """给结果补地址/等级：搜索返回里自带的优先，其次携程主档，再次详情页地址缓存。"""
    info = db.lookup_addresses([it.get(poi_key) for it in items], [it.get(biz_key) for it in items])
    for it in items:
        a = item_address(it) if "raw" in it else None
        hit = info.get(f"poi:{it.get(poi_key)}") or info.get(f"biz:{it.get(biz_key)}") or {}
        it["address"] = a or hit.get("address")
        it["addressSource"] = "搜索结果" if a else hit.get("source")
        it["level"] = hit.get("level")
        if it.get("lat") is None and hit.get("lat") is not None:
            it["lat"], it["lng"] = hit["lat"], hit.get("lng")
        if not it.get(poi_key) and hit.get("poiId"):
            it[poi_key] = hit["poiId"]
            if "key" in it:
                it["key"] = f"poi:{hit['poiId']}"
    return items


def judge_scenic(detail, items):
    """detail = db.scenic_detail()（候选已 enrich）；items = 已 enrich 的搜索结果。"""
    pool = [dict(key=it.get("key"), poiId=it.get("poiId"), name=it.get("name"), address=it.get("address")) for it in items]
    pool += [dict(key=f"poi:{c['ctrip_poi_id']}", poiId=c["ctrip_poi_id"], name=c.get("ctrip_poi_name"), address=c.get("address"))
             for c in detail.get("candidates") or []]
    return match.judge(detail["scenic"], pool)


# ---------------------------------------------------------------- 搜索（模拟人工输入）
class CtripSearcher:
    def __init__(self, page, prefs, start_url, patterns, timeout_s=10.0):
        self.page, self.prefs, self.start_url, self.patterns, self.timeout_s = page, prefs, start_url, patterns, timeout_s
        self.lock = asyncio.Lock()
        self.last_at = 0.0
        self.addr_lock = asyncio.Lock()
        self.addr_last = 0.0

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

    async def fetch_address(self, url):
        """在后台新标签页打开携程详情页，读出页面上「地址」一栏。"""
        if not url or not url.startswith("http"):
            raise ValueError("这条结果没有详情页链接")
        async with self.addr_lock:
            wait = self.addr_last + random.uniform(1.5, 2.5) - time.monotonic()
            if wait > 0:
                await asyncio.sleep(wait)
            p = await self.page.context.new_page()
            try:
                await p.goto(url, wait_until="domcontentloaded", timeout=25000)
                res = None
                for _ in range(10):  # 页面是前端渲染的，地址可能晚一点出来
                    await p.wait_for_timeout(500)
                    res = await p.evaluate(JS_DETAIL_ADDRESS)
                    if res.get("address"):
                        break
                return res
            finally:
                self.addr_last = time.monotonic()
                await p.close()
                try:
                    await self.page.bring_to_front()
                except Exception:
                    pass

    def _score(self, js, text, kw, url):
        """响应里必须出现完整关键词；按：命中常用接口、带结果列表、nlpResult.keyword 完全一致 加分。"""
        if kw not in text and json.dumps(kw)[1:-1] not in text and kw not in json.dumps(js, ensure_ascii=False):
            return -1, 0
        n = len(find_items(js))
        sc = (100 if any(p in url for p in self.patterns) else 0) + (50 + min(n, 20) if n else 0)
        if isinstance(js, dict) and (js.get("nlpResult") or {}).get("keyword") == kw:
            sc += 30
        return sc, n

    async def _search(self, kw):
        page = self.page
        sel = await self._input()
        captured = []

        def on_resp(resp):
            rt = resp.request.resource_type
            u = resp.url.lower()
            if rt in ("xhr", "fetch") or (rt == "script" and re.search(r"callback=|jsonp|cb=", u)) or any(p in resp.url for p in self.patterns):
                captured.append(resp)

        page.on("response", on_resp)
        entries, best = [], None
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
            typed_at, grace_at, done = time.monotonic(), None, 0
            while time.monotonic() < typed_at + self.timeout_s:
                while done < len(captured):
                    resp = captured[done]
                    done += 1
                    try:
                        text = await resp.text()
                    except Exception:
                        continue
                    js = parse_body(text)
                    entry = dict(url=resp.url, status=resp.status, type=resp.request.resource_type, size=len(text))
                    if js is not None:
                        sc, n = self._score(js, text, kw, resp.url)
                        entry.update(score=sc, items=n)
                        if sc >= 0 and (best is None or sc >= best[0]):
                            best = (sc, n, js, resp.url)
                    entry["body"] = text[:4000]
                    entries.append(entry)
                if best and best[1] and time.monotonic() - typed_at > 1.0:
                    grace_at = grace_at or time.monotonic()
                    if time.monotonic() - grace_at > 0.6:  # 拿到带结果的返回后再等一小会儿，取最新的
                        break
                await asyncio.sleep(0.15)
            await page.wait_for_timeout(300)  # 等下拉框渲染完
            dom = await page.evaluate(JS_DOM_DROPDOWN, sel)
        finally:
            page.remove_listener("response", on_resp)
            try:
                await page.evaluate("() => document.activeElement && document.activeElement.blur()")
            except Exception:
                pass
        self._dump(kw, entries, best, dom)
        js = best[2] if best else None
        items = parse_items(js) if js else []
        capture = "network" if items else ("network?" if best else "dom")
        if not items and dom:
            items = dom_to_items(dom)
        if best:
            print(f"[hq] 「{kw}」采用 {best[3][:120]} → {len(items)} 条", flush=True)
        else:
            print(f"[hq] 「{kw}」没找到含关键词的接口返回（收到 {len(entries)} 个响应），只读到下拉框文字；详情见 debug/last_search.json", flush=True)
        total = js.get("total") if isinstance(js, dict) else None
        return dict(keyword=kw, capture=capture, total=total, items=items, dom=dom, source_url=best[3] if best else None,
                    searched_at=time.strftime("%Y-%m-%d %H:%M:%S"))

    def _dump(self, kw, entries, best, dom):
        """把这次搜索收到的响应写到 debug/last_search.json，方便排查。"""
        try:
            d = HERE / "debug"
            d.mkdir(exist_ok=True)
            (d / "last_search.json").write_text(json.dumps(dict(
                keyword=kw, page_url=self.page.url, chosen=best[3] if best else None, dom=dom,
                responses=sorted(entries, key=lambda e: -e.get("score", -9))), ensure_ascii=False, indent=1), encoding="utf-8")
        except Exception as e:
            print(f"[hq] 写 debug 文件失败：{e}", flush=True)

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


# ---------------------------------------------------------------- 偏好设置
class Prefs(dict):
    def __init__(self, path):
        super().__init__(reviewer="", throttle_ms=2500, sight_only=False, auto_search=True, input_selector="",
                         panel_width=560, push_page=False, auto_address=False, auto_keep_similar=True, auto_approve=True, auto_approve_delay_ms=2000, search_more=True, search_core_spots=False, max_extra=8, idle_skip=True, idle_skip_sec=10,
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
    try:
        db.init_db()
    except RuntimeError as e:
        print(f"MySQL 自检没通过：{e}", file=sys.stderr)
        raise SystemExit(1)
    h = db.health()
    try:  # 关联查询也跑一遍，排序规则/权限之类的问题在启动时就暴露
        db.cities()
        db.scenic_list({}, 0, 1)
    except Exception as e:
        print(f"MySQL 自检没通过：查询出错 {type(e).__name__}: {e}", file=sys.stderr)
        raise SystemExit(1)
    print(f"MySQL 正常：客户景区表 {db.SCENIC_TABLE} 共 {h['scenic_rows']} 行；默认城市 {','.join(h['cities']) or '全部'}；"
          f"离线候选表{'已导入' if h['candidate_table'] else '未导入（可选）'}", flush=True)


async def launch(pw, args):
    profile = Path(args.profile).resolve()
    profile.mkdir(parents=True, exist_ok=True)
    kw = dict(headless=args.headless, locale="zh-CN", timezone_id="Asia/Shanghai",
              chromium_sandbox=sys.platform in ("win32", "darwin"))  # 去掉 Windows/Mac 上的 --no-sandbox 提示条
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
                d = db.scenic_detail(payload["scenic_id"])
                enrich(d["candidates"], "ctrip_poi_id", "ctrip_business_id")
                d["spots"] = match.core_spots(d["scenic"])
                return d
            if method == "fetch_address":
                res = await searcher.fetch_address(payload.get("url"))
                if not res or not res.get("address"):
                    raise ValueError(f"详情页里没找到地址（页面标题：{(res or {}).get('title')}；可能要登录或验证）")
                db.addr_put(payload.get("poiId"), payload.get("businessId"), payload.get("name"), res["address"], payload.get("url"))
                return dict(address=res["address"], addressSource="详情页")
            if method == "poi":
                return db.set_poi(payload)
            if method == "cities":
                return db.cities()
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
                hit = None if payload.get("force") else db.cache_get(kwd)
                if hit and hit.get("result") and hit["result"].get("capture") != "dom":
                    res = dict(hit["result"], cached=True, searched_at=hit["searched_at"])
                else:
                    res = await searcher.search(kwd)
                    if res["capture"] != "dom":  # 只读到下拉文字（没有ID）的不缓存，下次重新搜
                        db.cache_put(kwd, res)
                enrich(res["items"])
                if payload.get("scenic_id"):
                    d = db.scenic_detail(payload["scenic_id"])
                    enrich(d["candidates"], "ctrip_poi_id", "ctrip_business_id")
                    res["judge"] = judge_scenic(d, res["items"])
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
                        hit = None if args.refresh else db.cache_get(kwd)
                        if hit and (hit.get("result") or {}).get("capture") != "dom":
                            skipped += 1
                            continue
                        try:
                            res = await searcher.search(kwd)
                            if res["capture"] == "dom":
                                raise RuntimeError("没读到接口返回（只有下拉框文字），见 debug/last_search.json")
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


async def cmd_auto(args):
    """批量自动审核：名称一致且地址相近的景区直接通过（approval=1），其余留给人工。
    搜索结果优先用缓存；需要现搜时才打开浏览器。"""
    check_db()
    filters = dict(city=args.city or "", grade=args.grade or "", status="todo", q=args.q or "")
    stats = dict(approved=0, pending=0, searched=0, failed=0)
    pw = ctx = searcher = None
    try:
        async def get_items(kwd):
            nonlocal pw, ctx, searcher
            hit = db.cache_get(kwd)
            if hit and hit.get("result") and hit["result"].get("capture") != "dom":
                return hit["result"]["items"]
            if args.cache_only:
                return None
            if searcher is None:
                pw = await async_playwright().start()
                ctx, page, prefs = await launch(pw, args)
                if args.throttle_ms:
                    prefs["throttle_ms"] = args.throttle_ms
                searcher = CtripSearcher(page, prefs, args.start_url, args.pattern)
                await page.goto(args.start_url, wait_until="domcontentloaded")
                await page.wait_for_timeout(2000)
            res = await searcher.search(kwd)
            stats["searched"] += 1
            if res["capture"] == "dom":
                raise RuntimeError("没读到接口返回（只有下拉框文字）")
            db.cache_put(kwd, res)
            return res["items"]

        r = db.scenic_list(filters, 0, 100000)
        total = len(r["items"])
        for i, s in enumerate(r["items"], 1):
            if args.limit and i > args.limit:
                break
            d = db.scenic_detail(s["id"])
            enrich(d["candidates"], "ctrip_poi_id", "ctrip_business_id")
            kws = [s["name"]] + ([a.strip() for a in re.split(r"[,，、;；/]", s.get("alias") or "") if a.strip()] if not args.no_alias else [])
            kws += match.core_spots(s) if args.spots else []
            kws = list(dict.fromkeys(kws))[: 1 + args.max_extra]
            items, j = [], None
            try:
                for kwd in dict.fromkeys(kws):
                    got = await get_items(kwd)
                    if got is None:
                        continue
                    items += enrich(got)
                    j = judge_scenic(d, items)
                    if j["approve"]:
                        break
            except Exception as e:
                stats["failed"] += 1
                print(f"[{i}/{total}] {s['id']} {s['name']}：搜索失败 {e}", flush=True)
                continue
            if not j or not j["approve"]:
                stats["pending"] += 1
                if args.verbose:
                    print(f"[{i}/{total}] {s['id']} {s['name']}：留给人工（{j['reason'] if j else '无缓存'}）", flush=True)
                continue
            keep = [it for it in items if it.get("key") in j["similar"]]
            keep += [dict(poiId=c["ctrip_poi_id"], name=c["ctrip_poi_name"], url=c.get("ctrip_url"), address=c.get("address"),
                          lat=c.get("lat"), lng=c.get("lng"), key=f"poi:{c['ctrip_poi_id']}")
                     for c in d["candidates"] if f"poi:{c['ctrip_poi_id']}" in j["similar"]]
            names, seen = [], set()
            for it in keep:
                if it["key"] in seen:
                    continue
                seen.add(it["key"])
                names.append(it.get("name"))
                if not args.dry_run:
                    db.set_poi(dict(scenic_id=s["id"], keep=True, poiId=it.get("poiId"), businessId=it.get("businessId"),
                                    poiName=it.get("name"), poiUri=it.get("url"), addr=it.get("address"), lat=it.get("lat"), lon=it.get("lng")))
            if not args.dry_run:
                db.set_status(dict(scenic_id=s["id"], status="done", note=j["reason"], reviewer=args.reviewer))
            stats["approved"] += 1
            print(f"[{i}/{total}] {s['id']} {s['name']}：{'(试运行) ' if args.dry_run else ''}自动通过，保留 {len(set(k['key'] for k in keep))} 个 {'、'.join(names)}", flush=True)
    finally:
        if ctx:
            await ctx.close()
        if pw:
            await pw.stop()
        print(f"完成：自动通过 {stats['approved']}，留给人工 {stats['pending']}，现搜 {stats['searched']} 次，失败 {stats['failed']}"
              + ("（试运行，未写库）" if args.dry_run else ""))


def write_csv(path, rows):
    cols = ["scenic_id", "scenic_name", "city_name", "approval", "kept_qty", "ctrip_poi_id_list", "ctrip_poi_name_list", "ctrip_poi_info", "note"]
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
    p = sub.add_parser("auto", help="批量自动审核：名称一致且地址相近的直接通过，其余留给人工")
    browser_opts(p)
    p.add_argument("--city", help="城市，逗号分隔；默认 CITIES 环境变量的 7 城")
    p.add_argument("--grade", help="等级，如 5A,4A")
    p.add_argument("--q", help="景区名/ID 过滤")
    p.add_argument("--no-alias", action="store_true", help="景区名没通过时不再用别名搜（默认会搜）")
    p.add_argument("--spots", action="store_true", help="别名也没通过时，再用核心景点搜（跳过大雄宝殿之类通用名）")
    p.add_argument("--max-extra", type=int, default=8, help="每个景区除景区名外最多再搜几个词，默认 8")
    p.add_argument("--cache-only", action="store_true", help="只用已缓存的搜索结果，不开浏览器")
    p.add_argument("--dry-run", action="store_true", help="只打印判定结果，不写库")
    p.add_argument("--limit", type=int, default=0, help="最多处理多少个景区（0=不限）")
    p.add_argument("--throttle-ms", type=int, default=0, help="两次搜索最小间隔（毫秒），默认 2500")
    p.add_argument("--reviewer", default="auto", help="写入进度表的核对人，默认 auto")
    p.add_argument("-v", "--verbose", action="store_true", help="也打印留给人工的景区和原因")
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
    elif args.cmd == "auto":
        asyncio.run(cmd_auto(args))
    else:
        asyncio.run(cmd_run(args))


if __name__ == "__main__":
    main()
