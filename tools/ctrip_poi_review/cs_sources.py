"""客服数据扩展用的「外部资料」：放进数据目录（任意子目录）就会被自动找到，第一次用时整理成小的缓存（out/cs_refs_cache/），之后直接读缓存。

事实来源（客服回答只能用这些）：
  景区讲解包    dwd_prd_scenic_guide_{content,fact,fact_source_rel,source}_di.csv（多个目录里都有时按 content_id 去重）
                每条讲解 = 一个景点 / 主题 + 若干条带出处的事实；只用来源不全是 OTA / 旅游社区（source_type 6、7）的事实
  RedAttractionQA_train.json   红色景点问答（passage + 问题 + 答案）：passage 里点名的景点能唯一对到我们景区表的，当这个景区的事实

问法参考（只学游客怎么问、客服怎么接，里面的景点名、价格、电话一律不用）：
  RiSAWOZ 类  train*.json（列表，每通有 dialogue_id / dialogue[].user_utterance / system_utterance）：只取「旅游景点」领域的轮次
  CrossWOZ 类 train*.json（字典，每通有 sys-usr / messages[].role / content / dialog_act）：只取「景点」领域的轮次
  RedAttractionQA_train.json   的问题：历史文化类主题的问法参考
只用训练集（文件名含 train）；dev / test / val 不用，免得和评测数据重叠。
RiSAWOZ / CrossWOZ 原文件很大（180 MB / 370 MB），仓库里放的是提取好的景点对话 *_attraction_refs_train.jsonl（data/woz/），效果一样；
要从原文件重新提取：python cs_sources.py export-refs <放原文件的目录> data/woz
"""
import ast
import csv
import hashlib
import json
import re
from pathlib import Path

CACHE_VER = 2
LOW_AUTHORITY = {"6", "7"}  # OTA 平台、旅游内容社区
RELATION = {"1": "", "2": "景区内景点", "3": "组成部分（范围见说明）"}  # attraction_relation_type：1 景区本体 2 景区内景点 3 遗产组成点等
SOURCE_TYPE_NAME = {"1": "景区运营方官网", "2": "政府网站", "3": "博物馆或文物机构", "4": "UNESCO官网", "5": "其他机构媒体学术",
                    "6": "OTA平台", "7": "旅游内容社区", "8": "公开公众号文章", "9": "公开音视频讲解文字"}

# 问法参考按主题归类（看游客说了什么）
TOPIC_WORDS = {
    "ticket": r"门票|票价|多少钱|价格|免费|收费|优惠|半价",
    "booking": r"预约|预订|订票|买票|购票|网上买",
    "hours": r"开放时间|几点|营业时间|开门|关门|闭馆|入园时间|游玩时间",
    "traffic": r"地址|在哪|地铁|公交|怎么去|怎么走|交通|停车|打车|直达|出租",
    "contact": r"电话|联系方式|号码",
    "plan": r"推荐|好玩|游玩|玩多久|时长|评分|适合|值得|特点",
    "guide": r"讲解|导游|导览",
    "intro": r"介绍|特点|特色|历史|有什么",
    "culture": r"历史|建于|年代|为什么|故事|文物|由来|朝代|纪念",
}


def _sig(paths):
    h = hashlib.sha1(str(CACHE_VER).encode())
    for p in sorted(paths, key=str):
        st = p.stat()
        h.update(f"{p}|{st.st_size}|{int(st.st_mtime)}".encode())
    return h.hexdigest()[:16]


def _head(p, n=4096):
    with p.open("rb") as f:
        return f.read(n).decode("utf-8", "ignore")


def find(data_dir):
    """在数据目录里找各类资料文件。"""
    d = Path(data_dir) if data_dir else None
    out = dict(guide={}, risawoz=[], crosswoz=[], redqa=[], prebuilt=[])
    if not d or not d.exists():
        return out
    for t in ("content", "fact", "fact_source_rel", "source"):
        out["guide"][t] = sorted(d.rglob(f"dwd_prd_scenic_guide_{t}_di.csv"), key=lambda p: ("data_all" not in str(p), str(p)))
    out["prebuilt"] = sorted(p for p in d.rglob("*_attraction_refs_*.jsonl") if "train" in p.name)
    for p in d.rglob("*.json"):
        name = p.name.lower()
        if "redattractionqa" in name:
            if "train" in name:
                out["redqa"].append(p)
            continue
        if "train" not in name:
            continue
        h = _head(p)
        if '"dialogue_id"' in h and '"user_utterance"' in h:
            out["risawoz"].append(p)
        elif '"sys-usr"' in h or ('"messages"' in h and '"goal"' in h):
            out["crosswoz"].append(p)
    return out


def _topics(text):
    return [k for k, rx in TOPIC_WORDS.items() if re.search(rx, text or "")]


def _names_from_acts(acts):
    names = set()
    for a in acts or []:
        if isinstance(a, (list, tuple)) and len(a) >= 4 and a[2] == "名称" and a[3]:
            names.add(str(a[3]).replace(" ", ""))
    return names


def _load_risawoz(p):
    out = []
    for dlg in json.load(p.open(encoding="utf-8")):
        turns, names = [], set()
        for t in dlg.get("dialogue") or []:
            if "旅游景点" not in str(t.get("turn_domain")):
                continue
            u, s = (t.get("user_utterance") or "").strip(), (t.get("system_utterance") or "").strip()
            if u:
                turns.append(dict(role="游客", text=u))
            if s:
                turns.append(dict(role="客服", text=s))
            for k in ("system_actions", "user_actions"):
                try:
                    names |= _names_from_acts(eval_list(t.get(k)))
                except ValueError:
                    pass
        if len(turns) >= 2:
            user = " ".join(x["text"] for x in turns if x["role"] == "游客")
            out.append(dict(id=f"RiSAWOZ:{dlg.get('dialogue_id')}", dataset="RiSAWOZ", turns=turns[:10], names=sorted(names), topics=_topics(user)))
    return out


def eval_list(v):
    """RiSAWOZ 里动作字段是 Python 字面量字符串（如 "[['Recommend', '旅游景点', '名称', '周庄 古镇']]"）。"""
    if isinstance(v, list):
        return v
    s = str(v or "").strip()
    if not s:
        return []
    try:
        v = ast.literal_eval(s)  # 只解析字面量，不执行代码
    except (ValueError, SyntaxError) as e:
        raise ValueError("unparsable") from e
    return v if isinstance(v, list) else []


def _load_crosswoz(p):
    out = []
    data = json.load(p.open(encoding="utf-8"))
    for did, dlg in (data.items() if isinstance(data, dict) else enumerate(data)):
        msgs = dlg.get("messages") or []
        turns, names = [], set()
        for i, m in enumerate(msgs):
            acts = m.get("dialog_act") or []
            if m.get("role") != "usr" or not any(len(a) > 1 and a[1] == "景点" for a in acts):
                continue
            turns.append(dict(role="游客", text=m.get("content") or ""))
            names |= _names_from_acts(acts)
            if i + 1 < len(msgs) and msgs[i + 1].get("role") == "sys":
                turns.append(dict(role="客服", text=msgs[i + 1].get("content") or ""))
                names |= _names_from_acts(msgs[i + 1].get("dialog_act"))
        turns = [t for t in turns if t["text"].strip()]
        if len(turns) >= 2:
            user = " ".join(x["text"] for x in turns if x["role"] == "游客")
            out.append(dict(id=f"CrossWOZ:{did}", dataset="CrossWOZ", turns=turns[:10], names=sorted(names), topics=_topics(user)))
    return out


def _load_redqa(p):
    t = p.read_text(encoding="utf-8").strip()
    try:
        items = json.loads(t)
    except ValueError:  # 一行一个
        items = [json.loads(x) for x in t.splitlines() if x.strip()]
    out = []
    for i, x in enumerate(items):
        ps = x.get("passages") or []
        if not ps:
            continue
        out.append(dict(id=f"RedAttractionQA:train:{i}", q=x.get("q") or "", answer=ps[0].get("answer") or "", passage=ps[0].get("passage") or ""))
    return out


def build_cache(data_dir, cache_dir, log=print):
    """整理问法参考和 RedAttractionQA（大文件只解析一次），返回缓存目录里的内容。"""
    f = find(data_dir)
    files = f["risawoz"] + f["crosswoz"] + f["redqa"] + f["prebuilt"]
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    sig = _sig(files)
    man = cache_dir / "manifest.json"
    if man.exists():
        try:
            m = json.loads(man.read_text(encoding="utf-8"))
            if m.get("sig") == sig:
                return m
        except ValueError:
            pass
    refs, red = [], []
    seen = set()
    for p in f["prebuilt"]:  # 已提取好的景点对话（仓库 data/woz/ 里的）
        with p.open(encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    r = json.loads(line)
                    if r["id"] not in seen:
                        seen.add(r["id"])
                        refs.append(r)
    for p in f["risawoz"]:
        log(f"整理问法参考 {p.name}（RiSAWOZ 类，只取景点领域）…")
        refs += [r for r in _load_risawoz(p) if r["id"] not in seen]
    for p in f["crosswoz"]:
        log(f"整理问法参考 {p.name}（CrossWOZ 类，只取景点领域；文件大，第一次要等一会）…")
        refs += [r for r in _load_crosswoz(p) if r["id"] not in seen]
    for p in f["redqa"]:
        red += _load_redqa(p)
    with (cache_dir / "woz_refs.jsonl").open("w", encoding="utf-8") as fh:
        for r in refs:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    with (cache_dir / "redqa.jsonl").open("w", encoding="utf-8") as fh:
        for r in red:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    m = dict(sig=sig, files=[str(p) for p in files], woz_refs=len(refs), redqa=len(red),
             by_dataset={k: sum(1 for r in refs if r["dataset"] == k) for k in ("RiSAWOZ", "CrossWOZ")})
    man.write_text(json.dumps(m, ensure_ascii=False, indent=1), encoding="utf-8")
    log(f"问法参考缓存：RiSAWOZ {m['by_dataset']['RiSAWOZ']} 通、CrossWOZ {m['by_dataset']['CrossWOZ']} 通；RedAttractionQA {len(red)} 条")
    return m


def load_woz_refs(cache_dir):
    p = Path(cache_dir) / "woz_refs.jsonl"
    return [json.loads(x) for x in p.open(encoding="utf-8")] if p.exists() else []


def load_redqa(cache_dir):
    p = Path(cache_dir) / "redqa.jsonl"
    return [json.loads(x) for x in p.open(encoding="utf-8")] if p.exists() else []


def _read_csv(paths):
    for p in paths:
        with p.open(encoding="utf-8-sig") as fh:
            yield from csv.DictReader(fh)


def load_guide(data_dir, log=print):
    """景区讲解包 → {scenic_id: [讲解单元]}。讲解单元 = 一条讲解（景点 / 主题）+ 它的事实（只留有非 OTA / 社区出处的）+ 出处。"""
    f = find(data_dir)["guide"]
    if not f.get("content") or not f.get("fact"):
        return {}
    src = {}
    for r in _read_csv(f.get("source") or []):
        src.setdefault(r["source_id"], r)
    rel = {}
    for r in _read_csv(f.get("fact_source_rel") or []):
        rel.setdefault((r["content_id"], str(r["fact_seq_no"])), set()).add(r["source_id"])
    facts = {}
    seen_fact = set()
    for r in _read_csv(f["fact"]):
        k = (r["content_id"], str(r["fact_seq_no"]))
        if k in seen_fact:
            continue
        seen_fact.add(k)
        facts.setdefault(r["content_id"], []).append(r)
    units, seen, dropped = {}, set(), 0
    for c in _read_csv(f["content"]):
        cid = c["content_id"]
        if cid in seen:
            continue
        seen.add(cid)
        keep = []
        for x in sorted(facts.get(cid, []), key=lambda r: int(r["fact_seq_no"] or 0)):
            sids = rel.get((cid, str(x["fact_seq_no"])), set())
            types = {str(src.get(s, {}).get("source_type", "")) for s in sids}
            if sids and types and types <= LOW_AUTHORITY:
                dropped += 1
                continue
            keep.append(dict(seq=x["fact_seq_no"], attr=x["fact_attr_name"], value=x["fact_attr_value"], source_ids=sorted(sids)))
        if len(keep) < 2:
            continue
        sids = sorted({s for k in keep for s in k["source_ids"]})
        units.setdefault(c["scenic_id"], []).append(dict(
            unit_id=cid, kind="guide", batch=c.get("collect_batch_id"), spot=c.get("attraction_name") or c.get("scenic_name"),
            poi_id=(c.get("poi_id") or None), version=c.get("travel_date") or None,
            relation=RELATION.get(str(c.get("attraction_relation_type")), c.get("attraction_relation_type") or ""), topic=c.get("guide_topic_name"), title=c.get("guide_title_name"),
            scope=c.get("scope_desc"), facts=keep,
            sources=[dict(source_id=s, url=src.get(s, {}).get("source_url"), title=src.get(s, {}).get("source_title_name"),
                          publisher=src.get(s, {}).get("source_publisher_name"),
                          type=SOURCE_TYPE_NAME.get(str(src.get(s, {}).get("source_type")), src.get(s, {}).get("source_type"))) for s in sids]))
    n = sum(len(v) for v in units.values())
    log(f"景区讲解包：{n} 条讲解（{len(units)} 个景区）可用；去掉只有 OTA / 社区出处的事实 {dropped} 条")
    return units


def _place(v):
    return re.sub(r"(特别行政区|自治区|自治州|地区|盟|省|市|县|区|旗)$", "", str(v or "").strip())


GENERIC_NAME = re.compile(r"(革命|人民|抗日|红军|烈士)?(烈士陵园|烈士纪念碑|纪念碑|纪念馆|纪念园|纪念塔|博物馆|陈列馆|陵园|公园|旧址|故居|广场|遗址)")


def map_redqa(red, scenics, core):
    """RedAttractionQA 的 passage / 问题里点名的景点 → 唯一对到我们景区表的，按景区分组，每 5 条一个讲解单元。
    防串：名称短于 6 个字的（如「烈士陵园」「徐向前故居」）要求文字里出现这个景区的市或区县；文字里出现了别的城市、没出现本市的，不要。"""
    names, info = {}, {}
    for r in scenics:
        info[r["_id"]] = (_place(r.get("city_name") or r.get("_city")), _place(r.get("district_name")))
        for n in [r.get("_name") or ""] + re.split(r"[,，、;；/]", str(r.get("scenic_alias") or "")):
            c = core(n.strip())
            if len(c) >= 4:
                names.setdefault(c, set()).add(r["_id"])
    index = {}  # 名称按前两个字分桶：每段文字只查以它的每个双字开头的名称，不用逐个名称扫
    for c in names:
        index.setdefault(c[:2], []).append(c)
    cities = {c for c, _ in info.values() if len(c) >= 2}
    dists = {d for _, d in info.values() if len(d) >= 2}
    by = {}
    for x in red:
        if not x["passage"] or (x["answer"] and x["answer"] not in x["passage"]):
            continue
        txt = x["q"] + x["passage"]
        hits = {c for i in range(len(txt) - 1) for c in index.get(txt[i:i + 2], ()) if txt.startswith(c, i)}
        if not hits:
            continue
        best = max(hits, key=lambda c: (len(c), c))  # 一样长时按字排，每次结果一致
        if GENERIC_NAME.fullmatch(best):  # 「烈士陵园」「革命纪念馆」这种通用名对不准是哪一个
            continue
        ids = names[best]
        if len(ids) != 1:  # 同名景区不止一个（如多个城市都有的纪念馆）：对不准，不用
            continue
        sid = next(iter(ids))
        city, dist = info[sid]
        local = (len(city) >= 2 and city in txt) or (len(dist) >= 2 and dist in txt)
        if len(best) < 6 and not local:
            continue
        if not local and any(c in txt for c in (cities | dists) - {city, dist} if c not in best):
            continue
        by.setdefault(sid, []).append(dict(x, matched=best))
    units = {}
    for sid, xs in by.items():
        for k in range(0, len(xs), 5):
            part = xs[k:k + 5]
            units.setdefault(sid, []).append(dict(
                unit_id=f"redqa:{sid}:{k // 5 + 1}", kind="redqa", spot=part[0]["matched"], relation="", topic="红色文化 / 场馆历史",
                title="", scope="", facts=[dict(seq=i + 1, attr="资料", value=p["passage"], source_ids=[p["id"]]) for i, p in enumerate(part)],
                sources=[dict(source_id=p["id"], url=None, title=p["q"], publisher="RedAttractionQA", type="公开数据集") for p in part]))
    return units


def export_refs(src_dir, out_dir, log=print):
    """从 RiSAWOZ / CrossWOZ 原文件（train）提取景点对话，写成 <数据集>_attraction_refs_train.jsonl（仓库 data/woz/ 用这个，不放原文件）。"""
    f = find(src_dir)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, files, fn in (("risawoz", f["risawoz"], _load_risawoz), ("crosswoz", f["crosswoz"], _load_crosswoz)):
        rows = [r for p in files for r in fn(p)]
        if not rows:
            continue
        with (out / f"{name}_attraction_refs_train.jsonl").open("w", encoding="utf-8", newline="\n") as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")
        log(f"{name}: {len(rows)} 通景点对话 → {out / f'{name}_attraction_refs_train.jsonl'}")


if __name__ == "__main__":
    import sys
    if len(sys.argv) == 4 and sys.argv[1] == "export-refs":
        export_refs(sys.argv[2], sys.argv[3])
    else:
        print("用法：python cs_sources.py export-refs <放 RiSAWOZ / CrossWOZ train.json 的目录> <输出目录，如 data/woz>")
