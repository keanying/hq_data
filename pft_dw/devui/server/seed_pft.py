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
def bounds(flow, g):
    ns = [n for n in flow["nodes"] if n["taskId"] in g["ids"]]
    if not ns:
        return None
    x = min(n["x"] for n in ns) - 18
    y = min(n["y"] for n in ns) - 47
    if g.get("collapsed"):
        return x, y, 240, 82
    return x, y, max(n["x"] for n in ns) + 210 - x, max(n["y"] for n in ns) + 113 - y


def relayout(flow):
    """网格：泳道（分层）沿流向排列，行=数据域；dir=LR 从左到右，TB 从上到下；分支贴在锚定泳道一侧的网格外。"""
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

    lane_gap, row_gap = L.get("laneGap", 150), L.get("rowGap", 40)
    A0, C0, rows = L.get("a0", 380), L.get("c0", 160), L.get("rows", [])
    ri = lambda r: rows.index(r) if r in rows else 0
    lane_size = [0] * len(L["lanes"])
    row_size = [0] * max(1, len(rows))
    for i, lane in enumerate(L["lanes"]):
        for r, gid in L["cells"].get(lane, {}).items():
            e = ext(gid)
            if e:
                lane_size[i] = max(lane_size[i], e[1])
                row_size[ri(r)] = max(row_size[ri(r)], e[2])
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
        for r, gid in L["cells"].get(lane, {}).items():
            put(gid, lane_pos[i], row_pos[ri(r)])
    B = L.get("branch")
    if B:
        cols = B.get("cols", 2)
        ai = L["lanes"].index(B["anchor"]) if B.get("anchor") in L["lanes"] else 0
        es = [ext(g) for g in B["groups"]]
        sub, brow = [0] * cols, {}
        for i, e in enumerate(es):
            if e:
                sub[i % cols] = max(sub[i % cols], e[1])
                brow[i // cols] = max(brow.get(i // cols, 0), e[2])
        sub_pos, sa = [], lane_pos[ai]
        for s in sub:
            sub_pos.append(sa)
            sa += s + 90
        b_pos, bc = {}, c - row_gap + B.get("gap", 150)
        for r in sorted(brow):
            b_pos[r] = bc
            bc += brow[r] + row_gap
        for i, gid in enumerate(B["groups"]):
            put(gid, sub_pos[i % cols], b_pos.get(i // cols, bc))

    def node(i, na, nc):
        if i in pos:
            pos[i]["x"], pos[i]["y"] = (nc, na) if TB else (na, nc)

    if L.get("start"):
        node(L["start"], A0 - (96 if TB else 192) - lane_gap, C0)
    if L.get("end"):
        node(L["end"], a, C0)
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
    params = [{"name": "bizdate", "type": "expression", "value": "$[yyyyMMdd-1]"},
              {"name": "bizdate_dash", "type": "expression", "value": "$[yyyy-MM-dd-1]"},
              {"name": "bizdate_prev", "type": "expression", "value": "$[yyyyMMdd-2]"},
              {"name": "bizdate_prev_dash", "type": "expression", "value": "$[yyyy-MM-dd-2]"},
              {"name": "bizdate_minus_7", "type": "expression", "value": "$[yyyyMMdd-8]"},
              {"name": "bizdate_begin", "type": "expression", "value": "$[yyyy-MM-dd-1] 00:00:00"},
              {"name": "bizdate_end", "type": "expression", "value": "$[yyyy-MM-dd] 00:00:00"}]

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
        layout = {"dir": "LR", "a0": 380, "c0": 160, "laneGap": COL_GAP, "rowGap": ROW_GAP,
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
            layout["branch"] = {"anchor": anchor, "groups": gids, "label": bname, "cols": 2, "gap": BRANCH_GAP}
        for n in fnodes:
            if n["kind"] in ("start", "end"):
                k = task_key(n)
                flow["nodes"].append({"taskId": k, "x": 0, "y": 0})
                layout["start" if n["kind"] == "start" else "end"] = k
        flow["layout"] = layout
        ids = {n["taskId"] for n in flow["nodes"]}
        flow["edges"] = edges_of(fnodes, ids)
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
    if force or not store.flag("seeded"):
        store.ensure_project(PID, PROJECT["name"], PROJECT["description"], PROJECT["owner"], PROJECT["createdAt"])
        store.save_draft(PID, draft)
        store.put_kv("dataflow-project-ops:" + PID, json.dumps(ops, ensure_ascii=False))
        store.flag("seeded", "1")
        print(f"已写入 {PROJECT['name']}：{len(draft['tasks'])} 个任务，{len(draft['flows'])} 个工作流，代码中待补口径 {todo} 处（已标 TODO）")
    return draft


if __name__ == "__main__":
    d, o, raw, todo = build()
    print(len(d["tasks"]), "tasks", len(d["flows"]), "flows", "TODO", todo)
    for f in d["flows"]:
        print(f["name"], len(f["nodes"]), "nodes", len(f["edges"]), "edges", len(f["groups"]), "groups")
