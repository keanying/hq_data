"""名称 / 地址比对与自动审核判定（面板和 `review.py auto` 共用）。

规则：至少有一条携程 POI「名称一致」，且「地址相近」或「同省市区」→ 自动审核通过；
保留：所有「地址相近」的 POI，以及与景区同省市区的「名称一致」POI 和「景区名-xx」子景点（name_keep）。

- 名称一致：去掉省/市/区县前缀、「景区/旅游区/风景区…」后缀后，与客户景区名或任一别名完全相同
  （子景点「xx景区-棠上人家」、分店「xx(某某店)」都不算）。
- 核心景点：携程名与客户表 scenic_core_spots 中某一项一致时标出来（只提示，不作为自动通过的条件）。
- 门牌一致：两边地址抽出「路/街/巷… + 门牌号」相同（如都是「虎坊路3号」），算地址相近。
- 同省市区：城市、区县都一致；区县判断不出来时，同城且坐标距离 ≤ 3km 也算。
- 地址相近：地址去掉省市前缀和标点后，字符二元组 Jaccard ≥ 0.4
  （与面板 panel.js 的 addrSim 同一算法、同一阈值）。
"""
import math
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


_CUT = ("街道", "区", "县", "市", "镇", "乡")


def door(a):
    """地址里的「路/街/巷/胡同 + 门牌号」，如「陶然亭街道虎坊路3号(虎坊桥路口西南)」→「虎坊路3号」。没有门牌返回 None。"""
    a = re.sub(r"[（(][^)）]*[)）]", "", str(a or ""))
    a = re.sub(r"\s", "", a)
    m = re.search(r"(\d+)(?:-\d+)?号", a)
    if not m:
        return None
    pre = a[:m.start()]
    cut = max((pre.rfind(c) + len(c) for c in _CUT if c in pre), default=0)
    road = pre[cut:][-8:]
    if len(road) < 2 or not re.search(r"(路|街|道|巷|胡同|弄|里|坊|桥|村|园)$", road):
        return None
    return f"{road}{m.group(1)}号"


def _num(v):
    try:
        f = float(v)
        return f if f == f else None
    except (TypeError, ValueError):
        return None


def distance_m(lat1, lng1, lat2, lng2):
    vals = [_num(x) for x in (lat1, lng1, lat2, lng2)]
    if any(v is None for v in vals):
        return None
    lat1, lng1, lat2, lng2 = map(math.radians, vals)
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lng2 - lng1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))


NEAR_M = 3000  # 区县判断不出来时，名称一致 + 同城 + 3km 内也算同一片区


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


def _short(v):
    return re.sub(r"(省|市|区|县|自治州|自治县|特别行政区)$", "", (v or "").strip())


def _strip_upper(d):
    """「浙江省西湖区」「北京市海淀区」→「西湖区」「海淀区」。"""
    return re.sub(r"^([^省]{2,7}省)?([^市]{2,7}市)?", "", (d or "").strip()) or (d or "").strip()


def same_area(it, scenic, near=False):
    """携程结果是否和景区同省、同市、同区县。
    市：看结果的 city 字段，没有就看地址；区县：看结果的区县（携程主档）或地址里是否含景区的区县名。判断不了算不同。"""
    city, dist = _short(scenic.get("city")), _short(scenic.get("district"))
    a = it.get("address") or ""
    c = _short(it.get("city"))
    d = _short(_strip_upper(it.get("district")))
    if c and city:
        city_ok = city in c or c in city
    else:
        city_ok = bool(a) and (city in a or (len(dist) >= 2 and dist in a))
    if near and not city_ok and not c:  # 结果既没城市字段、地址又没写城市，但就在旁边
        city_ok = True
    if not dist:  # 客户表没填区县，只比到市
        return city_ok
    dist_ok = (len(d) >= 2 and (dist in d or d in dist)) or (len(dist) >= 2 and dist in a) or near
    return city_ok and dist_ok


def judge(scenic, items):
    """items: [{key, name, address, poiId, city, district}]。
    返回 {approve, reason, similar, name_match, sub_match, spot_match, name_keep, hit}：
    - name_match：名称一致；sub_match：「景区名-xx / 景区名·xx」子景点（前半段与景区名/别名一致）
    - name_keep：名称一致或子景点，且同省市区 → 自动保留
    - door_match：路名+门牌号一致（算作地址相近）
    - approve：至少一条名称一致，且（地址相近/门牌一致 或 同省市区；区县判断不了时同城且 3km 内也算）"""
    pre = _prefixes(scenic)
    targets = scenic_names(scenic)
    spots = {norm_name(x, pre) for x in core_spots(scenic)} - targets
    similar, name_match, sub_match, spot_match, name_keep, door_match = [], [], [], [], [], []
    sdoor = door(scenic.get("address"))
    hit, hit_how = None, ""
    for it in items:
        key = it.get("key")
        if not key or not it.get("poiId"):
            continue
        s = addr_sim(it.get("address"), scenic.get("address"))
        is_door = bool(sdoor) and door(it.get("address")) == sdoor
        is_sim = (s is not None and s >= SIMILAR) or is_door  # 门牌一致也算地址相近
        if is_door and key not in door_match:
            door_match.append(key)
        dm = distance_m(it.get("lat"), it.get("lng"), scenic.get("lat"), scenic.get("lng"))
        name = str(it.get("name") or "")
        nn = norm_name(name, pre, strip_paren=False)
        is_name = nn in targets
        parts = re.split(r"\s*[-·•—–]\s*", name, maxsplit=1)
        is_sub = not is_name and len(parts) == 2 and len(parts[1]) >= 1 and norm_name(parts[0], pre) in targets
        area = is_door or same_area(it, scenic, near=dm is not None and dm <= NEAR_M)  # 门牌一致自然同一处
        if nn in spots and key not in spot_match:
            spot_match.append(key)
        if is_sim and key not in similar:
            similar.append(key)
        if is_name and key not in name_match:
            name_match.append(key)
        if is_sub and key not in sub_match:
            sub_match.append(key)
        if (is_name or is_sub) and area and key not in name_keep:  # 同一景区（本身或子景点）且同省市区 → 保留
            name_keep.append(key)
        if is_name and (is_sim or area) and (hit is None or (is_sim and hit_how != "地址相近")):
            hit, hit_how = it, ("门牌一致" if is_door else "地址相近" if is_sim else "同省市区")
    approve = hit is not None
    if approve:
        reason = (f"自动审核：名称「{hit.get('name')}」与景区名一致，{hit_how}"
                  f"（{hit.get('address') or hit.get('district') or hit.get('city') or ''}）")
    elif name_match:
        reason = "名称一致但不在同一区县、地址也不相近"
    elif similar:
        reason = "地址相近但名称不一致"
    else:
        reason = "没有名称一致的结果"
    return dict(approve=approve, reason=reason, similar=similar, name_match=name_match, sub_match=sub_match,
                spot_match=spot_match, name_keep=name_keep, door_match=door_match, hit=hit.get("key") if hit else None)
