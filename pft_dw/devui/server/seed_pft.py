"""把 PFT 2.0 数仓（pft_dw/web/*.json）装配成数据开发平台里的一个项目，写入 SQLite。

目录：工作流 / ODS / DIM / DWD / DWS / ADS（按数据域分子目录）/ 数据质量 / 实时 / 调度控制
工作流：
  日调度主流程   源库就绪 → ODS → DWD → DWS → ADS → 发布；DIM 作为分支（ODS → DIM → DWD/DWS/ADS）
                 每个“分层 × 数据域”一个分组，任务与其质检节点成对放在组内，默认折叠
  实时作业       ODS(CDC) → DWD → DWS → ADS，离线维表作为 lookup 分支
  周 / 月 / 年调度
"""
import json
import math
import os
from pathlib import Path

from codegen import Gen

PID = "pft-dw"
PROJECT = dict(id=PID, name="PFT 2.0 数仓项目", description="票付通 2.0 离线 + 实时数仓：ODS→DWD→DWS→ADS，DIM 分支，含数据质量与对账",
               owner="数仓组", createdAt="2026-11-18")
_HERE = Path(__file__).resolve().parent
# 数仓生成结果所在目录：环境变量 PFT_SEED_DIR > 本项目 seed/ > 数仓仓库 pft_dw/web/
WEB = next(p for p in [Path(os.environ["PFT_SEED_DIR"]) if os.environ.get("PFT_SEED_DIR") else None,
                       _HERE.parent / "seed", _HERE.parents[1] / "web"] if p and (p / "schema.json").exists())
LAYERS = ["ODS", "DIM", "DWD", "DWS", "ADS"]
TASK_W, TASK_H = 192, 96
PAIR_DX, PITCH_X, PITCH_Y = 222, 470, 128
COL_GAP, ROW_GAP, BRANCH_GAP = 150, 40, 150
PARAM_DESC = {
    "bizdate": "业务日期（YYYYMMDD），调度日前一天；分区 travel_date 取此值",
    "bizdate_dash": "业务日期（yyyy-MM-dd），用于拉链表 start_date/end_date",
    "bizdate_prev": "业务日期前一天（YYYYMMDD），读取前一日快照/拉链分区",
    "bizdate_prev_dash": "业务日期前一天（yyyy-MM-dd），拉链闭链日期",
    "bizdate_minus_7": "业务日期前 7 天（YYYYMMDD），质量规则的环比基线",
    "bizdate_begin": "业务日期 00:00:00，增量抽取的起始时间（含）",
    "bizdate_end": "调度日 00:00:00，增量抽取的截止时间（不含）",
}
LAYOUT_VERSION = 6   # 排布结构版本：变化时启动会升级已有 PFT 项目的工作流排布（不动任务代码）


def load():
    S = json.loads((WEB / "schema.json").read_text(encoding="utf-8"))
    D = json.loads((WEB / "data.json").read_text(encoding="utf-8"))
    W = json.loads((WEB / "workflow.json").read_text(encoding="utf-8"))
    return S, D, W


def task_key(node):
    i = node["id"]
    if node["kind"] == "task":
        return i
    if node["kind"] == "ext":
        return node["table"]
    if node["kind"] == "dq":
        return "dq_" + node["table"] if node.get("table") else "monitor_" + node["job"]
    if node["kind"] == "recon":
        return "recon_" + node["table"]
    return i.replace(".", "_")    # start_daily / end_daily


# ---------- 泳道排布（与前端 web/model.mjs 的 relayout 同一算法） ----------
def _box(flow, g, seen):
    if g["id"] in seen:
        return None
    seen.add(g["id"])
    kids = [c for c in flow["groups"] if c.get("parent") == g["id"]]
    in_kid = {i for c in kids for i in c["ids"]}
    rects = [(n["x"], n["y"], 192, 96) for n in flow["nodes"] if n["taskId"] in g["ids"] and n["taskId"] not in in_kid]
    for c in kids:
        b = _box(flow, c, seen)
        if b:
            rects.append((b[0], b[1], 240, 82) if c.get("collapsed") else b)
    if not rects:
        return None
    x = min(r[0] for r in rects) - 18
    y = min(r[1] for r in rects) - 47
    return x, y, max(r[0] + r[2] for r in rects) + 18 - x, max(r[1] + r[3] for r in rects) + 17 - y


def bounds(flow, g):
    """与前端 groupBounds 一致：嵌套分组按子分组（收起时为卡片）与直属任务求外框"""
    b = _box(flow, g, set())
    if not b:
        return None
    return (b[0], b[1], 240, 82) if g.get("collapsed") else b


# ---------- 分层排布（按依赖层级，与 web/model.mjs 的 levelsOf / layered / layoutGroupInner 一致） ----------
def levels_of(ids, edges):
    idx = {x: i for i, x in enumerate(ids)}
    succ, preds, indeg, seen = {x: [] for x in ids}, {x: [] for x in ids}, {x: 0 for x in ids}, set()
    for a, b in edges:
        if a not in idx or b not in idx or a == b or (a, b) in seen:
            continue
        seen.add((a, b))
        succ[a].append(b)
        preds[b].append(a)
        indeg[b] += 1
    level = {x: 0 for x in ids}
    queue = [x for x in ids if not indeg[x]]
    q = 0
    while q < len(queue):
        x = queue[q]
        q += 1
        for y in succ[x]:
            level[y] = max(level[y], level[x] + 1)
            indeg[y] -= 1
            if not indeg[y]:
                queue.append(y)
    return level, preds, idx


def layered(items, edges, gap_a, gap_c):
    """items: [{id, la, lc}] -> {id: (a, c)}"""
    ids = [i["id"] for i in items]
    level, preds, idx = levels_of(ids, edges)
    L = {}
    for x in ids:
        L.setdefault(level[x], []).append(x)
    order = {}
    for l in range(max(L) + 1 if L else 0):
        lv = L.get(l)
        if not lv:
            continue
        if l > 0:
            key = {}
            for i, x in enumerate(lv):
                ps = [p for p in preds[x] if p in order]
                key[x] = sum(order[p] for p in ps) / len(ps) if ps else i
            lv.sort(key=lambda x: (key[x], idx[x]))
        for i, x in enumerate(lv):
            order[x] = i
    out, a = {}, 0
    for l in range(max(L) + 1 if L else 0):
        lv = L.get(l)
        if not lv:
            continue
        c, m = 0, 0
        for x in lv:
            it = items[idx[x]]
            out[x] = (a, c)
            c += it["lc"] + gap_c
            m = max(m, it["la"])
        a += m + gap_a
    return out


def layout_group_inner(flow, g, TB=False):
    """组内内容（直属任务与子分组）按依赖层级排列，组的左上角位置不变"""
    kids = [c for c in flow["groups"] if c.get("parent") == g["id"]]
    in_kid = {i: k["id"] for k in kids for i in k["ids"]}
    for k in kids:
        if not k.get("collapsed"):
            layout_group_inner(flow, k, TB)
    before = bounds(flow, dict(g, collapsed=False))
    if not before:
        return
    pos = {n["taskId"]: n for n in flow["nodes"]}
    unit = lambda i: in_kid.get(i, i)
    items, have = [], set()
    for i in g["ids"]:
        if i not in pos or unit(i) in have:
            continue
        u = unit(i)
        have.add(u)
        if u == i:
            items.append({"id": i, "la": 96 if TB else 192, "lc": 192 if TB else 96})
        else:
            b = bounds(flow, next(k for k in kids if k["id"] == u))
            if b:
                items.append({"id": u, "la": b[3] if TB else b[2], "lc": b[2] if TB else b[3], "b": b})
    at = layered(items, [[unit(a), unit(b)] for a, b in flow["edges"]], 50 if TB else 60, 30 if TB else 24)
    ox, oy = before[0] + 18, before[1] + 47
    for it in items:
        oa, oc = at[it["id"]]
        x, y = ox + (oc if TB else oa), oy + (oa if TB else oc)
        if "b" in it:
            dx, dy = x - it["b"][0], y - it["b"][1]
            for i in next(k for k in kids if k["id"] == it["id"])["ids"]:
                if i in pos:
                    pos[i]["x"] += dx
                    pos[i]["y"] += dy
        else:
            pos[it["id"]]["x"], pos[it["id"]]["y"] = x, y


def relayout(flow):
    """网格：泳道（分层）沿流向排列，行=数据域，同一泳道里互相依赖的数据域按层级分子列；
    dir=LR 从左到右，TB 从上到下；分支贴在锚定泳道一侧的网格外，按依赖层级排布。"""
    L = flow.get("layout")
    if not L or not L.get("lanes"):
        return False
    TB = L.get("dir") == "TB"
    pos = {n["taskId"]: n for n in flow["nodes"]}
    G = {g["id"]: g for g in flow["groups"]}

    def ext(gid):
        g = G.get(gid)
        b = g and bounds(flow, g)
        if not b:
            return None
        return b, (b[3] if TB else b[2]), (b[2] if TB else b[3])

    def put(gid, a, c):
        e = ext(gid)
        if not e:
            return
        x, y = (c, a) if TB else (a, c)
        dx, dy = x - e[0][0], y - e[0][1]
        for i in G[gid]["ids"]:
            if i in pos:
                pos[i]["x"] += dx
                pos[i]["y"] += dy

    lane_gap, row_gap, sub_gap = L.get("laneGap", 150), L.get("rowGap", 40), L.get("subGap", 60)
    A0, C0, base = L.get("a0", 380), L.get("c0", 160), L.get("rows", [])
    extra = []        # 不属于数据域的格子（如对账）排在数据域行之后
    for lane in L["lanes"]:
        for r in L["cells"].get(lane, {}):
            if r not in base and r not in extra:
                extra.append(r)
    rows = base + extra
    ri = lambda r: rows.index(r) if r in rows else 0
    cell_of = {}
    for lane in L["lanes"]:
        for gid in L["cells"].get(lane, {}).values():
            for i in G.get(gid, {}).get("ids", []):
                cell_of[i] = gid
    for gid in (L.get("branch") or {}).get("groups", []):
        for i in G.get(gid, {}).get("ids", []):
            cell_of[i] = gid
    cell_edges = [[cell_of[a], cell_of[b]] for a, b in flow["edges"] if a in cell_of and b in cell_of and cell_of[a] != cell_of[b]]
    LG = L.get("laneGroups", {})
    folded = lambda lane: bool(G.get(LG.get(lane), {}).get("collapsed"))
    in_lane = lambda lane, gid: bool(LG.get(lane)) and G.get(gid, {}).get("parent") == LG[lane]
    pad = lambda lane: (47 if TB else 18) if LG.get(lane) and not folded(lane) else 0
    pad_size = lambda lane: (64 if TB else 36) if LG.get(lane) and not folded(lane) else 0
    lane_size = [0] * len(L["lanes"])
    row_size = [0] * max(1, len(rows))
    subs = []
    for i, lane in enumerate(L["lanes"]):
        f = folded(lane)
        cells = [(r, gid) for r, gid in L["cells"].get(lane, {}).items() if not (f and in_lane(lane, gid)) and ext(gid)]
        lv = levels_of([gid for _, gid in cells], cell_edges)[0]
        sub = {}
        for r, gid in cells:
            e = ext(gid)
            sub[lv[gid]] = max(sub.get(lv[gid], 0), e[1])
            row_size[ri(r)] = max(row_size[ri(r)], e[2])
        so, acc = {}, 0
        for k in range(max(sub) + 1 if sub else 0):
            so[k] = acc
            if sub.get(k):
                acc += sub[k] + sub_gap
        subs.append((lv, so))
        size = acc - sub_gap if sub else 0
        if f:
            e = ext(LG[lane])
            if e:
                size = max(size, e[1])
                row_size[0] = max(row_size[0], e[2])
        elif size:
            size += pad_size(lane)
        lane_size[i] = size
    lane_pos, a = [], A0
    for s in lane_size:
        lane_pos.append(a)
        if s:
            a += s + lane_gap
    row_pos, c = [], C0
    for s in row_size:
        row_pos.append(c)
        if s:
            c += s + row_gap
    for i, lane in enumerate(L["lanes"]):
        f = folded(lane)
        if f:
            put(LG[lane], lane_pos[i], row_pos[0])
        lv, so = subs[i]
        for r, gid in L["cells"].get(lane, {}).items():
            if f and in_lane(lane, gid):
                continue
            put(gid, lane_pos[i] + pad(lane) + so.get(lv.get(gid, 0), 0), row_pos[ri(r)])
    B = L.get("branch")
    ai = L["lanes"].index(B["anchor"]) if B and B.get("anchor") in L["lanes"] else 0
    bc = c - row_gap + (B.get("gap", 150) if B else 150)
    if B and G.get(B.get("group"), {}).get("collapsed"):
        put(B["group"], lane_pos[ai], bc)
    elif B:
        items = []
        for gid in B["groups"]:
            e = ext(gid)
            if e:
                items.append({"id": gid, "la": e[1], "lc": e[2]})
        at = layered(items, cell_edges, 90, row_gap)
        for it in items:
            oa, oc = at[it["id"]]
            put(it["id"], lane_pos[ai] + oa, bc + oc)

    def node(i, na, nc):
        if i in pos:
            pos[i]["x"], pos[i]["y"] = (nc, na) if TB else (na, nc)

    if L.get("start"):
        node(L["start"], A0 - (96 if TB else 192) - lane_gap, C0)
    if L.get("end"):
        node(L["end"], a, C0)
    # 记录排布时的泳道几何：连线按它走通道，拖动单张卡片不会改变其他连线
    NA = 96 if TB else 192
    c0 = None
    for lane in L["lanes"]:
        ids = [LG[lane]] if (folded(lane) or LG.get(lane)) else list(L["cells"].get(lane, {}).values())
        for gid in ids:
            e = ext(gid)
            if e:
                v = e[0][0] if TB else e[0][1]
                c0 = v if c0 is None else min(c0, v)
    L["geo"] = {"dir": "TB" if TB else "LR", "lanes": [[p, p + lane_size[i]] for i, p in enumerate(lane_pos)],
                "start": [A0 - NA - lane_gap, A0 - lane_gap], "end": [a, a + NA], "c0": C0 if c0 is None else c0}
    return True


def build():
    S, D, W = load()
    T = {t["short"]: t for t in D["tables"]}
    nodes = W["nodes"]
    byid = {n["id"]: n for n in nodes}
    tnode = {n["table"]: n for n in nodes if n["kind"] == "task"}
    gen = Gen(S, T, tnode, W["jobs"])
    short = {"ord": "订单域", "fin": "财务域", "prd": "产品域", "inv": "库存域", "cus": "用户域", "sup": "供应商域",
             "trf": "流量渠道域", "opr": "运营域", "mkt": "营销域"}
    dom_cn = {d["k"]: short.get(d["k"], d["v"].split("（")[0]) for d in D["domains"]}

    # ---------- 目录 ----------
    folders = [{"id": "root", "name": PROJECT["name"], "parentId": None}]

    def folder(fid, name, parent):
        if not any(f["id"] == fid for f in folders):
            folders.append({"id": fid, "name": name, "parentId": parent})
        return fid

    folder("wf", "工作流", "root")
    for l in LAYERS:
        folder("L_" + l, l, "root")
    folder("dq", "数据质量", "root")
    folder("rt", "实时作业", "root")
    folder("ctl", "调度控制", "root")
    dom_order = [d["k"] for d in D["domains"]]
    used = {(T[n["table"]]["layer"], T[n["table"]]["domain"]) for n in nodes if n["kind"] == "task" and not n["table"].endswith("_rt")}
    for l in LAYERS:          # 预建数据域子目录，保证目录顺序与数据域清单一致
        for dom in dom_order:
            if (l, dom) in used:
                folder(f"L_{l}_{dom}", f"{short.get(dom, dom)} · {dom}", "L_" + l)

    def dom_folder(base, layer, dom):
        return folder(f"{base}_{layer}_{dom}", f"{dom_cn.get(dom, dom)} · {dom}", base if base != "L" else "L_" + layer)

    # ---------- 任务 ----------
    tasks = {}

    def add_task(key, **kw):
        if key in tasks:
            return tasks[key]
        t = {"id": key, "table": key, **kw}
        t.setdefault("parameters", [])
        tasks[key] = t
        return t

    for n in sorted(nodes, key=lambda n: (n["flow"] != "daily", n.get("level", 0), n["id"])):
        k = task_key(n)
        if n["kind"] in ("task", "ext"):
            t = n["table"]
            info = T[t]
            rt = t.endswith("_rt")
            if rt:
                fid = folder("rt_" + info["layer"], info["layer"], "rt")
            else:
                fid = dom_folder("L", info["layer"], info["domain"])
            add_task(k, name=info["cn"], layer=info["layer"], folderId=fid, type="sql",
                     engine="flink" if rt else "spark", mode="streaming" if rt else "batch", code=gen.code(t))
        elif n["kind"] == "dq" and not n.get("table"):
            add_task(k, name="监控·Flink 作业 " + n["job"].replace("flink_job_", ""), layer="", folderId=folder("dq_作业监控", "作业监控", "dq"),
                     type="sql", engine="flink", mode="batch", code=gen.dq(n))
        elif n["kind"] in ("dq", "recon"):
            t = n["table"]
            rt = t.endswith("_rt") and n["kind"] == "dq"
            sub = "对账" if n["kind"] == "recon" else ("实时监控" if rt else n["layer"])
            fid = folder("dq_" + sub, sub, "dq")
            add_task(k, name=("对账·" if n["kind"] == "recon" else "监控·" if rt else "质检·") + T[t]["cn"],
                     layer=n["layer"], folderId=fid, type="sql",
                     engine="presto" if n["kind"] == "recon" else ("starrocks" if rt else "spark"), mode="batch", code=gen.dq(n))
        else:
            add_task(k, name=n["cn"] + "（" + {"daily": "日", "weekly": "周", "monthly": "月", "yearly": "年", "realtime": "实时"}[n["flow"]] + "）",
                     layer="", folderId="ctl", type="shell", engine="", mode="batch", code=gen.control(n, n["flow"]))

    # ---------- 工作流 ----------
    flows = []
    fmeta = {f["id"]: f for f in W["flows"]}
    params = [dict(p, desc=PARAM_DESC[p["name"]]) for p in [
        {"name": "bizdate", "type": "expression", "value": "$[yyyyMMdd-1]"},
        {"name": "bizdate_dash", "type": "expression", "value": "$[yyyy-MM-dd-1]"},
        {"name": "bizdate_prev", "type": "expression", "value": "$[yyyyMMdd-2]"},
        {"name": "bizdate_prev_dash", "type": "expression", "value": "$[yyyy-MM-dd-2]"},
        {"name": "bizdate_minus_7", "type": "expression", "value": "$[yyyyMMdd-8]"},
        {"name": "bizdate_begin", "type": "expression", "value": "$[yyyy-MM-dd-1] 00:00:00"},
        {"name": "bizdate_end", "type": "expression", "value": "$[yyyy-MM-dd] 00:00:00"}]]

    def edges_of(fnodes, ids):
        out, seen = [], set()
        for n in fnodes:
            for d in n.get("deps", []):
                if d in byid:
                    a, b = task_key(byid[d]), task_key(n)
                    if a in ids and b in ids and (a, b) not in seen and a != b:
                        seen.add((a, b))
                        out.append([a, b])
        return out

    def lane_flow(fid, name, fnodes, columns_spec, branch_spec=None, extra_groups=()):
        """columns_spec: [(列名, [节点…])] 每列内部再按数据域分组"""
        flow = {"id": "flow_" + fid, "name": name, "folderId": "wf", "nodes": [], "edges": [], "groups": [],
                "parameters": params if fid != "realtime" else [], "env": ""}
        flow["env"] = "\n".join(p["name"] + "=" + p["value"] for p in flow["parameters"])
        layout = {"v": LAYOUT_VERSION, "dir": "LR", "a0": 380, "c0": 160, "laneGap": COL_GAP, "rowGap": ROW_GAP,
                  "lanes": [], "rows": [], "cells": {}}
        placed = set()

        def make_group(gid, gname, items):
            # items: [(task节点, 质检节点或 None)]，按层级、名称排序后网格摆放
            items = sorted(items, key=lambda p: (p[0].get("level", 0), p[0]["id"]))
            n = len(items)
            per_col = n if n <= 6 else math.ceil(n / (2 if n <= 16 else 3))
            ids = []
            for i, (a, b) in enumerate(items):
                cx, cy = (i // per_col) * PITCH_X, (i % per_col) * PITCH_Y
                for node, dx in ((a, 0), (b, PAIR_DX)):
                    if node is None:
                        continue
                    k = task_key(node)
                    if k in placed:
                        continue
                    placed.add(k)
                    flow["nodes"].append({"taskId": k, "x": cx + dx, "y": cy})
                    ids.append(k)
            if ids:
                flow["groups"].append({"id": gid, "name": gname, "ids": ids, "collapsed": True})
                return gid
            return None

        def wrap(gid, name, kids):
            """外层分组：包含子分组的全部任务，插在子分组之前（先画外框）"""
            ids = [i for k in kids for i in next(g for g in flow["groups"] if g["id"] == k)["ids"]]
            at = min(i for i, g in enumerate(flow["groups"]) if g["id"] in kids)
            for g in flow["groups"]:
                if g["id"] in kids:
                    g["parent"] = gid
            flow["groups"].insert(at, {"id": gid, "name": name, "ids": ids, "collapsed": False})

        dq_of = {n["table"]: n for n in fnodes if n["kind"] == "dq"}
        doms = set()
        for cname, cnodes, by_domain in columns_spec:
            layout["lanes"].append(cname)
            cells = layout["cells"].setdefault(cname, {})
            if not by_domain:       # 整列一个分组（如对账）
                items = [(n, None) for n in cnodes]
                g = make_group(f"g_{fid}_{cname}", cname, items)
                if g:
                    cells["_"] = g
                continue
            by_dom = {}
            for n in cnodes:
                by_dom.setdefault(n.get("domain", ""), []).append(n)
            for dom in sorted(by_dom, key=lambda d: dom_order.index(d) if d in dom_order else 99):
                items = [(n, dq_of.get(n.get("table")) if n["kind"] == "task" else None) for n in by_dom[dom]]
                label = f"{cname} · {dom_cn.get(dom, dom)}" if dom else cname
                g = make_group(f"g_{fid}_{cname}_{dom or 'x'}", label, items)
                if g:
                    cells[dom] = g
                    doms.add(dom)
            wrap(f"g_{fid}_L_{cname}", cname, list(cells.values()))
            layout.setdefault("laneGroups", {})[cname] = f"g_{fid}_L_{cname}"
        layout["rows"] = [d for d in dom_order if d in doms] + sorted(d for d in doms if d not in dom_order)
        if branch_spec:
            anchor, bname, bnodes = branch_spec
            by_dom = {}
            for n in bnodes:
                by_dom.setdefault(n.get("domain", ""), []).append(n)
            gids = []
            for dom in sorted(by_dom, key=lambda d: dom_order.index(d) if d in dom_order else 99):
                items = [(n, dq_of.get(n.get("table")) if n["kind"] == "task" else None) for n in by_dom[dom]]
                g = make_group(f"g_{fid}_{bname}_{dom}", f"{bname} · {dom_cn.get(dom, dom)}", items)
                if g:
                    gids.append(g)
            wrap(f"g_{fid}_B_{bname}", f"{bname}（分支）", gids)
            layout["branch"] = {"anchor": anchor, "groups": gids, "group": f"g_{fid}_B_{bname}", "label": bname,
                                "cols": 2, "gap": BRANCH_GAP}
        for n in fnodes:
            if n["kind"] in ("start", "end"):
                k = task_key(n)
                flow["nodes"].append({"taskId": k, "x": 0, "y": 0})
                layout["start" if n["kind"] == "start" else "end"] = k
        flow["layout"] = layout
        ids = {n["taskId"] for n in flow["nodes"]}
        flow["edges"] = edges_of(fnodes, ids)
        wrappers = set(layout.get("laneGroups", {}).values()) | ({layout["branch"]["group"]} if layout.get("branch") else set())
        for g in flow["groups"]:            # 组内任务按依赖层级排好（展开时即为分层视图）
            if g["id"] not in wrappers and not any(c.get("parent") == g["id"] for c in flow["groups"]):
                layout_group_inner(flow, g)
        relayout(flow)
        flows.append(flow)
        return flow

    daily = [n for n in nodes if n["flow"] == "daily"]
    L = lambda layer: [n for n in daily if n["kind"] == "task" and n["layer"] == layer]
    recon = [n for n in daily if n["kind"] == "recon"]
    lane_flow("daily", "日调度 · 主流程", daily,
              [("ODS", L("ODS"), True), ("DWD", L("DWD"), True), ("DWS", L("DWS"), True), ("ADS", L("ADS"), True)] +
              ([("实时/离线对账", recon, False)] if recon else []),
              branch_spec=("ODS", "DIM", L("DIM")))
    # 对账只依赖 DWS，与 ADS 并列：放进 ADS 泳道（在 ADS 外框之外），DWS→对账 与 DWS→ADS 都是相邻一跳
    fl = flows[-1]["layout"]
    if "实时/离线对账" in fl["lanes"]:
        fl["lanes"].remove("实时/离线对账")
        fl["cells"]["ADS"]["对账"] = fl["cells"].pop("实时/离线对账")["_"]
        relayout(flows[-1])

    rtn = [n for n in nodes if n["flow"] == "realtime"]
    R = lambda layer: [n for n in rtn if n["kind"] == "task" and n["layer"] == layer]
    lane_flow("realtime", "实时 · Flink 作业", rtn,
              [("ODS 实时", R("ODS"), True), ("DWD 实时", R("DWD"), True), ("DWS 实时", R("DWS"), True), ("ADS 实时", R("ADS"), True),
               ("Flink 作业监控", [n for n in rtn if n["kind"] == "dq" and not n.get("table")], False)],
              branch_spec=("DWD 实时", "离线维表 lookup", [n for n in rtn if n["kind"] == "ext"]))

    for fid, nm in (("weekly", "周调度"), ("monthly", "月调度"), ("yearly", "年调度")):
        fn = [n for n in nodes if n["flow"] == fid]
        flow = {"id": "flow_" + fid, "name": nm, "folderId": "wf", "nodes": [], "edges": [],
                "groups": [], "parameters": params, "env": "\n".join(p["name"] + "=" + p["value"] for p in params)}
        lv = {}
        for n in sorted(fn, key=lambda n: (n.get("level", 0), n["id"])):
            lvl = n.get("level", 0) if n["kind"] != "end" else 99
            lv.setdefault(lvl, []).append(n)
        for i, lvl in enumerate(sorted(lv)):
            for j, n in enumerate(lv[lvl]):
                flow["nodes"].append({"taskId": task_key(n), "x": 80 + i * 280, "y": 140 + j * 150})
        flow["edges"] = edges_of(fn, {n["taskId"] for n in flow["nodes"]})
        flows.append(flow)

    # 任务排序：目录顺序
    forder = {f["id"]: i for i, f in enumerate(folders)}
    task_list = sorted(tasks.values(), key=lambda t: (forder.get(t["folderId"], 999), t["id"]))
    draft = {"version": 2, "folders": folders, "tasks": task_list, "flows": flows}

    schedules = []
    for fid, cyc, clock, extra, cron in (("daily", "daily", "00:30", {}, "30 0 * * *"),
                                         ("weekly", "weekly", "08:00", {"weekday": 1}, "0 8 * * 1"),
                                         ("monthly", "monthly", "08:00", {"monthday": 1}, "0 8 1 * *"),
                                         ("yearly", "cron", "01:00", {}, "0 1 1 12 *")):
        f = next(x for x in flows if x["id"] == "flow_" + fid)
        schedules.append({"id": "sch_" + fid, "name": f["name"], "target": f["id"], "cycle": cyc, "clock": clock, "minute": 0,
                          "weekday": extra.get("weekday", 1), "monthday": extra.get("monthday", 1), "timezone": "Asia/Shanghai",
                          "cron": cron, "start": "", "end": "", "retries": 2, "retryMinutes": 10, "timeout": 240,
                          "concurrency": "skip", "enabled": True, "time": cron + " · Asia/Shanghai",
                          "updatedAt": "2026-11-18T00:00:00.000Z", "sla": fmeta[fid]["sla"]})
    ops = {"schedules": schedules, "instances": [], "baselines": []}
    return draft, ops, (S, D, W), gen.todo


def write_meta(store, S, D, W):
    T = {t["short"]: t for t in D["tables"]}
    c = store.conn
    with store.lock, c:
        for t in ("dw_table", "dw_column", "dw_flow", "dw_node", "dw_rule"):
            c.execute(f"DELETE FROM {t}")
        for name, sch in S.items():
            info = T.get(name, {})
            keep = {k: info[k] for k in ("suffix", "part", "keys", "note", "metrics", "up", "down", "dims", "lookup") if k in info}
            c.execute("INSERT INTO dw_table VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                      (name, name.split("_")[0], info.get("layer", ""), info.get("domain", ""), info.get("cn", ""),
                       1 if name.endswith("_rt") else 0, sch.get("engine", ""), info.get("grain", ""), info.get("src", ""),
                       sch.get("ddl", ""), json.dumps(keep, ensure_ascii=False)))
            c.executemany("INSERT INTO dw_column VALUES(?,?,?,?,?,?,?,?,?)", [
                (name, i, col["n"], col["t"], col["c"], col["k"], col["s"], json.dumps(col.get("r", []), ensure_ascii=False),
                 json.dumps(col.get("d", []), ensure_ascii=False)) for i, col in enumerate(sch["cols"])])
        for f in W["flows"]:
            c.execute("INSERT INTO dw_flow VALUES(?,?,?,?)", (f["id"], f["name"], f["cron"],
                      json.dumps({k: f[k] for k in ("when", "sla", "nodes", "tasks", "dq", "rules", "depth") if k in f}, ensure_ascii=False)))
        for n in W["nodes"]:
            info = {k: n[k] for k in ("deps", "desc", "stage", "engine", "retries", "timeout_min", "priority", "cmd", "level",
                                      "cut", "cross", "block", "strong", "weak", "job", "monitor", "layer", "domain") if k in n}
            c.execute("INSERT INTO dw_node VALUES(?,?,?,?,?,?,?)",
                      (n["id"], task_key(n), n["flow"], n["kind"], n.get("table"), n.get("cn", ""), json.dumps(info, ensure_ascii=False)))
            for r in n.get("rules", []):
                c.execute("INSERT OR REPLACE INTO dw_rule VALUES(?,?,?,?,?,?,?,?,?)",
                          (r["id"], n["id"], n.get("table"), r["code"], r["name"], r["level"], r["sql"], r["expect"], r.get("desc", "")))


def ensure(store, force=False):
    """首次启动（或 --reseed）时写入示例项目与 PFT 项目；元数据每次启动都按最新生成结果刷新。
    用户删除项目后不会在重启时被重新创建。"""
    draft, ops, raw, todo = build()
    write_meta(store, *raw)
    if not store.flag("seeded"):
        store.ensure_project("tourism-default", "文旅数据项目", "景区经营、游客洞察与文旅数据开发", "林", "2026-10-07")
    if not force and store.flag("seeded"):
        upgrade_layout(store, draft)
    if force or not store.flag("seeded"):
        store.ensure_project(PID, PROJECT["name"], PROJECT["description"], PROJECT["owner"], PROJECT["createdAt"])
        store.save_draft(PID, draft)
        store.put_kv("dataflow-project-ops:" + PID, json.dumps(ops, ensure_ascii=False))
        store.flag("seeded", "1")
        print(f"已写入 {PROJECT['name']}：{len(draft['tasks'])} 个任务，{len(draft['flows'])} 个工作流，代码中待补口径 {todo} 处（已标 TODO）")
    return draft


def upgrade_layout(store, fresh):
    """已有 PFT 项目的泳道工作流若排布版本较旧：替换分组、排布与节点坐标，保留任务代码、连线和用户新增的节点。"""
    cur = store.draft(PID)
    if not cur:
        return
    new_flows = {f["id"]: f for f in fresh["flows"] if f.get("layout")}
    changed = []
    for f in cur["flows"]:
        nf = new_flows.get(f["id"])
        if not nf or (f.get("layout") or {}).get("v") == LAYOUT_VERSION:
            continue
        dir_ = (f.get("layout") or {}).get("dir", "LR")
        pos = {n["taskId"]: n for n in nf["nodes"]}
        for n in f["nodes"]:
            if n["taskId"] in pos:
                n["x"], n["y"] = pos[n["taskId"]]["x"], pos[n["taskId"]]["y"]
        have = {n["taskId"] for n in f["nodes"]}
        was = {g["id"]: g.get("collapsed") for g in f.get("groups", [])}   # 保留用户的展开/收起状态
        f["groups"] = [dict(g, ids=[i for i in g["ids"] if i in have], collapsed=was.get(g["id"], g.get("collapsed")))
                       for g in nf["groups"]]
        f["groups"] = [g for g in f["groups"] if g["ids"]]
        f["layout"] = dict(nf["layout"], dir=dir_)
        relayout(f)
        changed.append(f["name"])
    for f in cur["flows"]:            # 补全参数描述（不覆盖用户填写的）
        for prm in f.get("parameters") or []:
            if not prm.get("desc") and prm.get("name") in PARAM_DESC:
                prm["desc"] = PARAM_DESC[prm["name"]]
                if f["name"] not in changed:
                    changed.append(f["name"])
    if changed:
        store.save_draft(PID, cur)
        print("已升级工作流排布：" + "、".join(changed))


if __name__ == "__main__":
    d, o, raw, todo = build()
    print(len(d["tasks"]), "tasks", len(d["flows"]), "flows", "TODO", todo)
    for f in d["flows"]:
        print(f["name"], len(f["nodes"]), "nodes", len(f["edges"]), "edges", len(f["groups"]), "groups")
