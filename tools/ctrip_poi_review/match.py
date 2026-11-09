"""名称 / 地址比对与自动审核判定（面板和 `review.py auto` 共用）。

规则：至少有一条携程 POI「名称一致」且「地址相近」→ 自动审核通过；
通过时保留所有「地址相近」的 POI。

- 名称一致：去掉省/市/区县前缀、「景区/旅游区/风景区…」后缀后，与客户景区名或任一别名完全相同
  （子景点「xx景区-棠上人家」、分店「xx(某某店)」都不算）。
- 核心景点：携程名与客户表 scenic_core_spots 中某一项一致时标出来（只提示，不作为自动通过的条件）。
- 地址相近：地址去掉省市前缀和标点后，字符二元组 Jaccard ≥ 0.4
  （与面板 panel.js 的 addrSim 同一算法、同一阈值）。
"""
import re

SIMILAR = 0.4
_SUFFIXES = sorted(["国家级旅游度假区", "国家旅游度假区", "旅游度假区", "风景名胜区", "旅游风景区", "自然风景区",
                    "生态旅游区", "文化旅游区", "旅游景区", "风景区", "旅游区", "景区", "度假区", "景点"], key=len, reverse=True)


def norm_addr(a):
    a = re.sub(r"[（(][^)）]*[)）]", "", str(a or ""))
    a = re.sub(r"^中国", "", a)
    a = re.sub(r"^[^省]{2,8}省", "", a)
    a = re.sub(r"^(北京|上海|天津|重庆)市", "", a)
    a = re.sub(r"^[^市]{2,8}市", "", a)
    return re.sub(r"[\s,，。·\-—]", "", a)


def addr_sim(a, b):
    a, b = norm_addr(a), norm_addr(b)
    if len(a) < 2 or len(b) < 2:
        return None
    A = {a[i:i + 2] for i in range(len(a) - 1)}
    B = {b[i:i + 2] for i in range(len(b) - 1)}
    inter = len(A & B)
    return inter / (len(A) + len(B) - inter or 1)


def _prefixes(scenic):
    out = {"中国"}
    for k in ("province", "city", "district"):
        v = (scenic.get(k) or "").strip()
        if v:
            out.add(v)
            short = re.sub(r"(省|市|区|县|自治州|自治县|特别行政区)$", "", v)
            if len(short) >= 2:
                out.add(short)
    return sorted(out, key=len, reverse=True)


def norm_name(name, prefixes, strip_paren=True):
    """携程名里的括号多是分店/门店（「xx(某某店)」），所以携程名不去括号，只有客户景区名去。"""
    n = str(name or "")
    if strip_paren:
        n = re.sub(r"[（(【\[].*?[）)】\]]", "", n)
    n = re.sub(r"[\s·•]", "", n)
    for _ in range(3):  # 「上海市崇明区xx」这种多层前缀
        for p in prefixes:
            if n.startswith(p) and len(n) - len(p) >= 2:
                n = n[len(p):]
                break
        else:
            break
    for suf in _SUFFIXES:
        if n.endswith(suf) and len(n) - len(suf) >= 2:
            n = n[:-len(suf)]
            break
    return n


def scenic_names(scenic):
    names = [scenic.get("name") or ""] + re.split(r"[,，、;；/]", scenic.get("alias") or "")
    pre = _prefixes(scenic)
    return {x for x in (norm_name(n, pre) for n in names if n and n.strip()) if len(x) >= 2}


# 各地都有、拿去搜没有区分度的核心景点名
GENERIC_SPOTS = {"大雄宝殿", "天王殿", "观音殿", "藏经阁", "钟楼", "鼓楼", "山门", "牌坊", "停车场", "游客中心", "游客服务中心",
                 "售票处", "广场", "观景台", "观景平台", "步道", "栈道", "码头", "索道", "厕所", "餐厅", "商业街", "入口", "出口"}


def core_spots(scenic):
    """客户表的核心景点（去重、去掉通用名和与景区名/别名重复的）。"""
    names = {scenic.get("name") or ""} | {x.strip() for x in re.split(r"[,，、;；/]", scenic.get("alias") or "")}
    out = []
    for x in re.split(r"[,，、;；/]", scenic.get("core_spots") or ""):
        x = re.sub(r"[（(].*?[）)]", "", x).strip()
        if len(x) >= 2 and x not in GENERIC_SPOTS and x not in names and x not in out:
            out.append(x)
    return out


def judge(scenic, items):
    """items: [{key, name, address, poiId}]。返回 {approve, reason, similar, name_match, hit}。"""
    pre = _prefixes(scenic)
    targets = scenic_names(scenic)
    spots = {norm_name(x, pre) for x in core_spots(scenic)} - targets
    similar, name_match, spot_match, hit = [], [], [], None
    for it in items:
        key = it.get("key")
        if not key or not it.get("poiId"):
            continue
        s = addr_sim(it.get("address"), scenic.get("address"))
        is_sim = s is not None and s >= SIMILAR
        nn = norm_name(it.get("name"), pre, strip_paren=False)
        is_name = nn in targets
        if nn in spots and key not in spot_match:
            spot_match.append(key)
        if is_sim and key not in similar:
            similar.append(key)
        if is_name and key not in name_match:
            name_match.append(key)
        if is_sim and is_name and hit is None:
            hit = it
    approve = hit is not None
    reason = (f"自动审核：名称「{hit.get('name')}」与景区名一致，地址相近（{hit.get('address')}）" if approve
              else ("名称一致但地址不相近" if name_match else ("地址相近但名称不一致" if similar else "没有名称一致且地址相近的结果")))
    return dict(approve=approve, reason=reason, similar=similar, name_match=name_match, spot_match=spot_match,
                hit=hit.get("key") if hit else None)
