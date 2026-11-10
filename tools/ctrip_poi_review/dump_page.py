"""抓取携程 POI 主页的结构，打包发给开发，用来核对/调整采集规则。

    python dump_page.py https://you.ctrip.com/sight/beijing1/229.html --channel chrome

会打开浏览器 → 慢慢往下滚到「用户点评」→ 点一次「下一页」，然后保存到 debug/page_dump_<时间>.zip：
  page.html            滚动后的整页 HTML
  page.png             整页截图
  text.txt             页面文字（找「图片总数」等文字用）
  network.json         期间页面发出的 xhr/fetch 请求（URL、方法、请求体）和返回（JSON 截断）
  comment_api/*.json   getCommentCollapseList 的完整请求体和返回（翻页前后各一份）
  pager.html           含「下一页」的元素及其父级 HTML
  image_total.txt      页面上看起来像「图片总数」的片段
  next_data.json       __NEXT_DATA__ 摘要：poiId、图片总数 imageCount、点评总数、第一页点评数（采集规则就靠这些）
不会保存请求头和 Cookie；请求体里 auth / token / ticket 之类的字段会打码。
"""
import argparse
import asyncio
import json
import re
import shutil
import time
from pathlib import Path

from playwright.async_api import async_playwright

import review

HERE = Path(__file__).resolve().parent
SECRET_KEYS = re.compile(r"(auth|token|ticket|cookie|sign|session|password|pwd)", re.I)


def redact(o):
    if isinstance(o, dict):
        return {k: ("***" if SECRET_KEYS.search(str(k)) else redact(v)) for k, v in o.items()}
    if isinstance(o, list):
        return [redact(v) for v in o]
    return o


def redact_body(text):
    if not text:
        return text
    try:
        return redact(json.loads(text))
    except Exception:
        return re.sub(r"((?:auth|token|ticket|sign)[^=&]*=)[^&]*", r"\1***", text, flags=re.I)


JS_PAGER = """() => {
  const out = [];
  for (const el of document.querySelectorAll('*')) {
    if (el.children.length === 0 && (el.textContent || '').trim() === '下一页') {
      const box = el.closest('ul,div,nav') || el.parentElement;
      out.push('<!-- 元素 -->\\n' + el.outerHTML + '\\n<!-- 父级 -->\\n' + (box ? box.outerHTML : ''));
    }
  }
  return out.join('\\n\\n');
}"""

JS_IMAGE_TOTAL = """() => {
  const t = (document.body.innerText || '');
  const hits = [];
  const re = /.{0,20}(图片|相册|照片).{0,20}/g; let m;
  while ((m = re.exec(t)) && hits.length < 80) { if (/\\d/.test(m[0])) hits.push(m[0].replace(/\\s+/g, ' ')); }
  const els = [...document.querySelectorAll('*')].filter((e) => e.children.length === 0 && /(图片|相册|照片)/.test(e.textContent || '') && /\\d/.test(e.textContent || ''))
    .slice(0, 40).map((e) => (e.parentElement || e).outerHTML.slice(0, 600));
  return hits.join('\\n') + '\\n\\n===== 元素 =====\\n' + els.join('\\n\\n');
}"""


async def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("url", help="POI 主页，如 https://you.ctrip.com/sight/beijing1/229.html")
    ap.add_argument("--profile", default=str(HERE / ".pw-profile"))
    ap.add_argument("--channel", default="")
    ap.add_argument("--executable-path", default="")
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()
    args.start_url, args.pattern = review.DEFAULT_START_URL, review.DEFAULT_PATTERNS

    out = HERE / "debug" / f"page_dump_{time.strftime('%Y%m%d_%H%M%S')}"
    (out / "comment_api").mkdir(parents=True, exist_ok=True)
    net, comment_n = [], 0

    async with async_playwright() as pw:
        ctx, page, _ = await review.launch(pw, args)

        async def on_resp(resp):
            nonlocal comment_n
            rt = resp.request.resource_type
            if rt not in ("xhr", "fetch"):
                return
            try:
                body = await resp.text()
            except Exception:
                body = None
            entry = dict(url=re.sub(r"((?:auth|token|ticket|sign)[^=&]*=)[^&]*", r"\1***", resp.url, flags=re.I),
                         method=resp.request.method, status=resp.status, request_body=redact_body(resp.request.post_data),
                         response=(body or "")[:20000])
            net.append(entry)
            if "getCommentCollapseList" in resp.url and body:
                comment_n += 1
                try:
                    full = redact(json.loads(body))
                except Exception:
                    full = body
                (out / "comment_api" / f"{comment_n:02d}.json").write_text(json.dumps(
                    dict(url=entry["url"], request_body=entry["request_body"], response=full), ensure_ascii=False, indent=1), encoding="utf-8")

        page.on("response", lambda r: asyncio.ensure_future(on_resp(r)))
        print("打开页面…", flush=True)
        await page.goto(args.url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)
        print("往下滚动到点评区…", flush=True)
        for _ in range(25):
            await page.mouse.wheel(0, 800)
            await page.wait_for_timeout(500)
        await page.wait_for_timeout(2000)
        pager = await page.evaluate(JS_PAGER)
        (out / "pager.html").write_text(pager or "（没找到「下一页」）", encoding="utf-8")
        nxt = page.get_by_text("下一页", exact=True)
        if await nxt.count():
            print("点一次「下一页」…", flush=True)
            try:
                el = nxt.last
                await el.scroll_into_view_if_needed()
                await el.click(timeout=5000)
                await page.wait_for_timeout(3000)
            except Exception as e:
                print(f"点击「下一页」失败：{e}", flush=True)
        else:
            print("没找到「下一页」", flush=True)
        (out / "image_total.txt").write_text(await page.evaluate(JS_IMAGE_TOTAL), encoding="utf-8")
        import crawler
        try:
            ssr = await page.evaluate(crawler.JS_SSR)
        except Exception as e:
            ssr = {"error": str(e)}
        if ssr and isinstance(ssr.get("items"), list):
            ssr = dict(ssr, items=f"{len(ssr['items'])} 条，图片 {sum(len(i.get('images') or []) for i in ssr['items'])} 张")
        (out / "next_data.json").write_text(json.dumps(ssr, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"__NEXT_DATA__：{ssr}", flush=True)
        (out / "text.txt").write_text(await page.evaluate("() => document.body.innerText"), encoding="utf-8")
        (out / "page.html").write_text(await page.content(), encoding="utf-8")
        await page.screenshot(path=str(out / "page.png"), full_page=True)
        (out / "network.json").write_text(json.dumps(net, ensure_ascii=False, indent=1), encoding="utf-8")
        await ctx.close()

    zip_path = shutil.make_archive(str(out), "zip", out)
    print(f"完成：点评接口返回 {comment_n} 次，xhr/fetch 共 {len(net)} 个。\n请把这个文件发给开发：{zip_path}")


if __name__ == "__main__":
    asyncio.run(main())
