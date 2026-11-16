"""训练数据一键清理（工作台「训练数据 → 清理数据」）：按数据集删 MySQL 里生成的样本，并同步清进度，清掉的下次会重新生成。

数据集：cs_rewrite 客服对话（改写）、cs_expand 客服对话（扩展）、eval 讲解内容评价、narr 个性化讲解
范围：all 全部；review 只清「需复核」的
只删本工具生成的数据（客服两张表里 source.generate_method 为 llm_rewrite / llm_expand 的会话），不碰别的。
"""
import json
import shutil

import cs_synth
import db
import guide_synth

DATASETS = {
    "cs_rewrite": dict(name="客服对话（改写）", kind="cs", method="llm_rewrite", prefix="cs_synth_"),
    "cs_expand": dict(name="客服对话（扩展）", kind="cs", method="llm_expand", prefix="cs_expand_"),
    "eval": dict(name="讲解内容评价", kind="gd", task="eval", prefix="guide_eval_"),
    "narr": dict(name="个性化讲解", kind="gd", task="narr", prefix="guide_narr_"),
}
REVIEW_LIKE = '%"needs_review": true%'


def _cs_where(ds, scope):
    where, params = ["t.source LIKE %s"], [f'%"generate_method": "{ds["method"]}"%']
    if scope == "review":
        where.append("t.source LIKE %s")
        params.append(REVIEW_LIKE)
    st, tt = db.ident(cs_synth.SESSION_TABLE), db.ident(cs_synth.TURN_TABLE)
    return (f"FROM {st} s JOIN {tt} t ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1 WHERE "
            + " AND ".join(where)), params


def _key(ds_id, src):
    """样本的 source → 进度文件里的 key（清掉后要从进度里去掉，下次才会重新生成）。"""
    src = src or {}
    if ds_id == "cs_rewrite":
        return f"{src.get('dialogue_id')}|{src.get('variant')}"
    if ds_id == "cs_expand":
        topic = src.get("topic")
        if topic == "culture" and (src.get("knowledge") or {}).get("unit_id"):
            topic = "culture@" + src["knowledge"]["unit_id"]
        return f"{src.get('scenic_id')}|{topic}|{src.get('variant')}"
    return f"{src.get('unit_id')}|{src.get('variant')}"


def count(datasets, scope="all"):
    out = {}
    with db.cursor() as cur:
        for ds_id in datasets:
            ds = DATASETS[ds_id]
            try:
                if ds["kind"] == "cs":
                    if not db.table_exists(cur, db.ident(cs_synth.SESSION_TABLE)):
                        out[ds_id] = 0
                        continue
                    sql, params = _cs_where(ds, scope)
                    cur.execute(f"SELECT COUNT(*) n {sql}", params)
                else:
                    cur.execute(guide_synth.ddl(ds["task"]))
                    cur.execute(f"SELECT COUNT(*) n FROM {guide_synth.table(ds['task'])}" + (" WHERE needs_review = 1" if scope == "review" else ""))
                out[ds_id] = int(cur.fetchone()["n"] or 0)
            except Exception as e:  # noqa: BLE001
                out[ds_id] = f"{type(e).__name__}: {e}"
    return out


def _drop_progress(ds_id, keys=None):
    """清进度：keys=None 删掉这个数据集的所有批次目录（out/<前缀>*）；否则只从各批次的 done_keys.txt 里去掉这些 key。"""
    pre = DATASETS[ds_id]["prefix"]
    dirs = [d for d in cs_synth.OUT_ROOT.glob(pre + "*") if d.is_dir()]
    if keys is None:
        for d in dirs:
            shutil.rmtree(d, ignore_errors=True)
        return len(dirs)
    keys = set(keys)
    for d in dirs:
        f = d / "done_keys.txt"
        if not f.exists() and ds_id == "cs_rewrite" and (d / "dialogs.jsonl").exists():  # 旧批次没有进度文件：从 dialogs 建一个
            ks = []
            for line in (d / "dialogs.jsonl").open(encoding="utf-8"):
                try:
                    ks.append(_key(ds_id, json.loads(line)["source"]))
                except (ValueError, KeyError):
                    pass
            f.write_text("\n".join(ks) + ("\n" if ks else ""), encoding="utf-8")
        if f.exists():
            left = [k for k in f.read_text(encoding="utf-8").split() if k not in keys]
            f.write_text("\n".join(left) + ("\n" if left else ""), encoding="utf-8")
    return len(dirs)


def clear(datasets, scope="all", log=print, batch=2000):
    """删除并清进度。返回 {数据集: 删掉的条数}。"""
    done = {}
    for ds_id in datasets:
        ds = DATASETS[ds_id]
        n, keys = 0, []
        with db.cursor() as cur:
            if ds["kind"] == "cs":
                if not db.table_exists(cur, db.ident(cs_synth.SESSION_TABLE)):
                    done[ds_id] = 0
                    continue
                sql, params = _cs_where(ds, scope)
                st, tt = db.ident(cs_synth.SESSION_TABLE), db.ident(cs_synth.TURN_TABLE)
                while True:
                    cur.execute(f"SELECT s.session_id, s.travel_date, t.source {sql} LIMIT {batch}", params)
                    rows = cur.fetchall()
                    if not rows:
                        break
                    for r in rows:
                        try:
                            keys.append(_key(ds_id, json.loads(r["source"] or "{}")))
                        except ValueError:
                            pass
                    pairs = [(r["session_id"], r["travel_date"]) for r in rows]
                    ph = ",".join(["(%s,%s)"] * len(pairs))
                    flat = [x for p in pairs for x in p]
                    cur.execute(f"DELETE FROM {tt} WHERE (session_id, travel_date) IN ({ph})", flat)
                    cur.execute(f"DELETE FROM {st} WHERE (session_id, travel_date) IN ({ph})", flat)
                    n += len(rows)
                    log(f"{ds['name']}：已删 {n} 个会话")
            else:
                t = guide_synth.table(ds["task"])
                idc = "eval_task_id" if ds["task"] == "eval" else "request_id"
                cur.execute(guide_synth.ddl(ds["task"]))
                while True:
                    cur.execute(f"SELECT {idc} id, record_json FROM {t}" + (" WHERE needs_review = 1" if scope == "review" else "") + f" LIMIT {batch}")
                    rows = cur.fetchall()
                    if not rows:
                        break
                    for r in rows:
                        try:
                            keys.append(_key(ds_id, json.loads(r["record_json"]).get("source")))
                        except ValueError:
                            pass
                    cur.execute(f"DELETE FROM {t} WHERE {idc} IN ({','.join(['%s'] * len(rows))})", [r["id"] for r in rows])
                    n += len(rows)
                    log(f"{ds['name']}：已删 {n} 条")
        dirs = _drop_progress(ds_id, None if scope == "all" else keys)
        log(f"{ds['name']}：共删 {n} 条；" + ("进度已清空（批次目录 " + str(dirs) + " 个）" if scope == "all" else f"已从进度里去掉 {len(keys)} 条，下次会重新生成"))
        done[ds_id] = n
    return done
