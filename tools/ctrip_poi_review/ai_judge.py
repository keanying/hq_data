"""AI 辅助核对：规则判不了的景区，把客户景区信息和携程候选交给大模型，判断每个 POI 是否属于这个景区。

接口：火山方舟 Responses API（POST {ai_base_url}/responses），兼容 OpenAI Responses 格式的返回。
配置在工作台「设置」页（存在浏览器目录的 hq_prefs.json），API Key 也可以用环境变量 ARK_API_KEY：

    ai_enabled          是否启用（默认关）
    ai_base_url         默认 https://ark.cn-beijing.volces.com/api/v3
    ai_model            默认 glm-5-3-flash-260828
    ai_api_key          API Key（页面上只显示打码后的）；留空则用环境变量 ARK_API_KEY
    ai_web_search       是否让模型联网搜索（tools: web_search），默认关；ai_max_keyword 搜索关键词数上限
    ai_min_confidence   自动通过 / 自动保留需要的最低置信度，默认 0.8
    ai_auto_approve     AI 有把握时是否自动审核通过（备注以「AI审核：」开头，方便人最后复核）
    ai_timeout_s        单次请求超时（秒）

发送给模型的只有：景区名称 / 别名 / 省市区 / 地址 / 坐标 / 等级 / 核心景点，和携程候选的名称 / 类型 / 城市区县 / 地址 / 距离。
同一景区、同一组候选的结果会缓存在 MySQL（scenic_ai_judge），重复打开不重复调用。
"""
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request

import match

DEFAULTS = dict(ai_enabled=False, ai_base_url="https://ark.cn-beijing.volces.com/api/v3", ai_model="glm-5-3-flash-260828",
                ai_api_key="", ai_web_search=False, ai_max_keyword=3, ai_min_confidence=0.8, ai_auto_approve=True, ai_timeout_s=60)
MAX_ITEMS = 30  # 一次最多给模型看的候选数


def config(prefs):
    cfg = {k: (prefs.get(k) if prefs.get(k) not in (None, "") else v) for k, v in DEFAULTS.items()}
    cfg["ai_api_key"] = (prefs.get("ai_api_key") or os.environ.get("ARK_API_KEY") or "").strip()
    cfg["key_source"] = "设置页" if prefs.get("ai_api_key") else ("环境变量 ARK_API_KEY" if os.environ.get("ARK_API_KEY") else "")
    cfg["ai_base_url"] = str(cfg["ai_base_url"]).rstrip("/")
    return cfg


def mask(key):
    key = str(key or "")
    if not key:
        return ""
    return key[:4] + "****" + key[-4:] if len(key) > 10 else "****"


def ready(cfg):
    return bool(cfg.get("ai_enabled") and cfg.get("ai_api_key") and cfg.get("ai_model"))


# ---------------------------------------------------------------- 提示词
def _fmt_dist(m):
    if m is None:
        return "未知"
    return f"{m:.0f}m" if m < 1000 else f"{m / 1000:.1f}km"


def build_prompt(scenic, items, rule=None):
    rule = rule or {}
    flags = {}
    for name, keys in (("名称一致", rule.get("name_match")), ("子景点名", rule.get("sub_match")), ("地址相近", rule.get("similar")),
                       ("门牌一致", rule.get("door_match")), ("核心景点", rule.get("spot_match")), ("同名多个", rule.get("ambiguous"))):
        for k in keys or []:
            flags.setdefault(k, []).append(name)
    lines = []
    for n, it in enumerate(items, 1):
        d = match.distance_m(it.get("lat"), it.get("lng"), scenic.get("lat"), scenic.get("lng"))
        area = " / ".join(x for x in (it.get("city"), it.get("district")) if x) or "未知"
        hint = "、".join(flags.get(it.get("key"), [])) or "无"
        lines.append(f"{n}. {it.get('name') or ''} | 类型 {it.get('type') or '未知'} | {area} | 地址 {it.get('address') or '未知'}"
                     f" | 距客户坐标 {_fmt_dist(d)} | 规则提示 {hint}")
    spots = "、".join(match.core_spots(scenic)) or "无"
    return f"""你是旅游景区数据核对员。客户有一个景区，下面是在携程上搜到的 POI，请逐个判断它是否属于这个景区。

属于：就是这个景区本身（名称可能带省市区前缀、或「景区/旅游区/风景区/公园」等后缀差异），或者是这个景区里面的子景点、场馆、分区、游客中心。
不属于：同名但在别的城市/区县的、只是附近的酒店/餐馆/商店/停车场、名字相似但其实是另一个景点的。
请综合名称、别名、地址（路名、门牌、乡镇）、省/市/区县是否一致、坐标距离、核心景点来判断；地址和区县冲突时以地址和距离为准。

客户景区：
- 名称：{scenic.get('name') or ''}
- 别名：{scenic.get('alias') or '无'}
- 省市区：{' / '.join(x for x in (scenic.get('province'), scenic.get('city'), scenic.get('district')) if x) or '未知'}
- 地址：{scenic.get('address') or '未知'}
- 坐标（GCJ02 经度,纬度）：{scenic.get('lng') or '?'}, {scenic.get('lat') or '?'}
- 等级：{scenic.get('grade') or '未知'}
- 核心景点：{spots}

携程候选（编号. 名称 | 类型 | 城市/区县 | 地址 | 距客户坐标 | 规则提示）：
{chr(10).join(lines)}

只输出一个 JSON 对象，不要输出其他文字：
{{"decisions":[{{"n":编号,"keep":true或false,"relation":"本体|子景点|无关|同名别处","confidence":0到1的小数,"reason":"不超过30字"}}],
 "approve":true或false,"confidence":0到1的小数,"summary":"不超过40字的结论"}}
approve=true 表示：至少有一个 keep=true 且 relation=本体 的 POI，并且你有把握这个景区可以审核通过。"""


# ---------------------------------------------------------------- 调用
class AIError(RuntimeError):
    pass


def _extract_text(js):
    if isinstance(js, dict):
        if isinstance(js.get("output_text"), str) and js["output_text"].strip():
            return js["output_text"]
        out = []
        for item in js.get("output") or []:
            if isinstance(item, dict) and item.get("type") in ("message", None):
                for c in item.get("content") or []:
                    if isinstance(c, dict) and c.get("type") in ("output_text", "text") and c.get("text"):
                        out.append(c["text"])
        if out:
            return "\n".join(out)
        for ch in js.get("choices") or []:  # 兼容 chat/completions 风格
            msg = (ch or {}).get("message") or {}
            if msg.get("content"):
                return msg["content"]
    raise AIError("模型没有返回文字结果：" + json.dumps(js, ensure_ascii=False)[:300])


def call(cfg, text):
    if not cfg.get("ai_api_key"):
        raise AIError("没有配置 API Key（设置页填写，或设置环境变量 ARK_API_KEY）")
    body = dict(model=cfg["ai_model"], stream=False,
                input=[dict(role="user", content=[dict(type="input_text", text=text)])])
    if cfg.get("ai_web_search"):
        body["tools"] = [dict(type="web_search", max_keyword=int(cfg.get("ai_max_keyword") or 3))]
    req = urllib.request.Request(cfg["ai_base_url"] + "/responses", data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
                                 headers={"Authorization": f"Bearer {cfg['ai_api_key']}", "Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=float(cfg.get("ai_timeout_s") or 60)) as r:
            js = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        raise AIError(f"接口返回 HTTP {e.code}：{detail}") from e
    except urllib.error.URLError as e:
        raise AIError(f"连不上 AI 接口：{e.reason}") from e
    except TimeoutError as e:
        raise AIError(f"AI 接口超时（{cfg.get('ai_timeout_s')} 秒）") from e
    return _extract_text(js), round(time.time() - t0, 1)


def parse(text):
    t = text.strip()
    t = re.sub(r"^```(?:json)?\s*|\s*```$", "", t)
    a, b = t.find("{"), t.rfind("}")
    if a < 0 or b <= a:
        raise AIError("模型返回的不是 JSON：" + text[:200])
    try:
        js = json.loads(t[a:b + 1])
    except json.JSONDecodeError as e:
        raise AIError(f"模型返回的 JSON 解析失败：{e}；{text[:200]}") from e
    return js


def _num(v, default=0.0):
    try:
        return max(0.0, min(1.0, float(v)))
    except (TypeError, ValueError):
        return default


def judge(cfg, scenic, items, rule=None, cache_get=None, cache_put=None):
    """items: [{key, name, type, city, district, address, lat, lng}]（带 poiId 的）。
    返回 {decisions: {key: {keep, relation, confidence, reason}}, approve, confidence, summary, model, elapsed, cached}"""
    items = [it for it in items if it.get("key")][:MAX_ITEMS]
    if not items:
        return dict(decisions={}, approve=False, confidence=0.0, summary="没有可判断的携程候选", model=cfg.get("ai_model"), elapsed=0, cached=False)
    sig = hashlib.sha1(json.dumps([cfg.get("ai_model"), bool(cfg.get("ai_web_search")), sorted(str(it["key"]) for it in items)],
                                  ensure_ascii=False).encode("utf-8")).hexdigest()
    if cache_get:
        hit = cache_get(scenic["id"], sig)
        if hit:
            return dict(hit, cached=True)
    text, elapsed = call(cfg, build_prompt(scenic, items, rule))
    js = parse(text)
    dec = {}
    for d in js.get("decisions") or []:
        try:
            n = int(d.get("n"))
        except (TypeError, ValueError):
            continue
        if 1 <= n <= len(items):
            dec[items[n - 1]["key"]] = dict(keep=bool(d.get("keep")), relation=str(d.get("relation") or ""),
                                            confidence=_num(d.get("confidence")), reason=str(d.get("reason") or "")[:80])
    res = dict(decisions=dec, approve=bool(js.get("approve")) and any(v["keep"] for v in dec.values()),
               confidence=_num(js.get("confidence")), summary=str(js.get("summary") or "")[:120], model=cfg.get("ai_model"),
               elapsed=elapsed, cached=False)
    if cache_put:
        cache_put(scenic["id"], sig, res)
    return res


def ping(cfg):
    text, elapsed = call(cfg, '只回复 JSON：{"ok":true}')
    return dict(ok=True, text=text[:200], elapsed=elapsed, model=cfg.get("ai_model"), web_search=bool(cfg.get("ai_web_search")))
