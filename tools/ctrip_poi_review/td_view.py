"""训练数据查看（工作台「数据查看」页）：直接从 MySQL 分页列出已生成的样本、看单条完整内容。

「训练数据」页的「处理记录」只是当前任务在内存里的最近 1000 条，服务重启 / 换任务后就没了；
生成的数据本身都在 MySQL 里，这里按和导出完全相同的筛选条件去查，所以「看到的」和「导出的」是同一批。

数据集：cs 智能客服对话（会话表 + 轮次表）、eval 讲解内容评价、narr 个性化讲解
筛选：method(llm_rewrite/llm_expand，仅 cs) city scenic review(ok/review) verdict(仅 eval) date_from date_to(会话日期，仅 cs)
      gen_date(生成日期) sid(样本 ID，逗号分隔)
"""
import json

import cs_synth
import db
import guide_synth

DATASETS = {"cs": "智能客服对话", "eval": "讲解内容评价", "narr": "个性化讲解"}
METHOD_NAME = {"llm_rewrite": "改写", "llm_expand": "扩展"}
FILTER_KEYS = ("method", "city", "scenic", "review", "verdict", "date_from", "date_to", "gen_date", "sid")


def _json(s):
    try:
        return json.loads(s or "{}")
    except ValueError:
        return {}


def _clip(s, n=90):
    s = " ".join(str(s or "").split())
    return s if len(s) <= n else s[:n] + "…"


def _dt(v):
    return cs_synth._fmt_dt(v)


# ---------------------------------------------------------------- 列表
def _cs_light(r):
    g = _json(r.get("source"))
    return dict(id=r["session_id"], travel_date=r["travel_date"], scenic_id=r["scenic_id"], scenic_name=r["scenic_name"],
                city=g.get("scenic_city") or g.get("city"), method=g.get("generate_method"),
                method_name=METHOD_NAME.get(g.get("generate_method"), g.get("generate_method") or "—"),
                topic=g.get("topic_name") or g.get("intent_type"), variant=g.get("variant"), channel=r["channel"],
                start_time=_dt(r["start_time"]), turns=r["turn_cnt"], end_type=r["end_type"], satisfaction=r["satisfaction_score"],
                preview=_clip(r.get("first_msg")), needs_review=bool(g.get("needs_review")), flags=g.get("check_flags") or [],
                generated_at=g.get("generated_at"), model=g.get("model"))


def _gd_light(task, r):
    rec = _json(r.get("record_json"))
    g = rec.get("source") or {}
    poi = rec.get("poi") or {}
    base = dict(id=r["eval_task_id" if task == "eval" else "request_id"], travel_date=r["travel_date"], scenic_id=r["scenic_id"],
                scenic_name=g.get("scenic_name") or poi.get("poi_name") or r.get("scenic_name"), city=r["city_name"],
                kb_kind=g.get("kb_name") or r.get("kb_kind"), variant=g.get("variant"), needs_review=bool(r["needs_review"]),
                flags=g.get("check_flags") or [], generated_at=g.get("generated_at") or _dt(r.get("created_at")), model=g.get("model"))
    if task == "eval":
        er = rec.get("eval_result") or {}
        clip = (rec.get("guide_clip") or {}).get("asr_text") or rec.get("guide_clip_txt") or ""
        return dict(base, spot=r.get("poi_name") or poi.get("poi_name"), verdict=r.get("verdict") or er.get("verdict"),
                    score=float(r["total_score"]) if r.get("total_score") is not None else None, issues=r.get("issue_cnt"),
                    category=g.get("category"), preview=_clip(clip))
    ref = rec.get("reference_narration") or {}
    return dict(base, spot=r.get("sub_poi_name") or poi.get("sub_poi_name"), visitor_group=r.get("visitor_group"),
                char_count=r.get("char_count"), char_limit=r.get("char_limit"), preview=_clip(ref.get("text")))


def list_page(ds, f, offset=0, limit=50):
    """按条件分页列出（新的在前）。返回 {total, items}；cs 另给 turns（总消息条数）。"""
    f = {k: f.get(k) or "" for k in FILTER_KEYS}
    offset, limit = max(0, int(offset or 0)), max(1, min(int(limit or 50), 200))
    if ds == "cs":
        cs_synth.mysql_check()
        sql, params = cs_synth._export_sql(f)
        with db.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) n, SUM(s.turn_cnt) turns {sql}", params)
            c = cur.fetchone()
            cur.execute(f"""SELECT s.session_id, s.scenic_id, s.scenic_name, s.channel, s.start_time, s.turn_cnt, s.end_type, s.satisfaction_score,
                                   s.travel_date, t.msg_text first_msg, t.source {sql}
                            ORDER BY s.travel_date DESC, s.session_id DESC LIMIT %s OFFSET %s""", params + [limit, offset])
            rows = cur.fetchall()
        return dict(total=int(c["n"] or 0), turns=int(c["turns"] or 0), items=[_cs_light(r) for r in rows])
    task = "eval" if ds == "eval" else "narr"
    where, params = guide_synth._export_where(task, f)
    key = "eval_task_id" if task == "eval" else "request_id"
    with db.cursor() as cur:
        cur.execute(guide_synth.ddl(task))
        cur.execute(f"SELECT COUNT(*) n FROM {guide_synth.table(task)}{where}", params)
        total = int(cur.fetchone()["n"] or 0)
        cur.execute(f"SELECT * FROM {guide_synth.table(task)}{where} ORDER BY created_at DESC, {key} DESC LIMIT %s OFFSET %s", params + [limit, offset])
        rows = cur.fetchall()
    return dict(total=total, items=[_gd_light(task, r) for r in rows])


# ---------------------------------------------------------------- 单条
def get_record(ds, rid, travel_date=None):
    """一条样本的完整 JSON（和导出的「完整 JSONL」那一行一样）。没有返回 None。"""
    if ds == "cs":
        cs_synth.mysql_check()
        st, tt = db.ident(cs_synth.SESSION_TABLE), db.ident(cs_synth.TURN_TABLE)
        td = int(travel_date) if str(travel_date or "").isdigit() else None
        with db.cursor() as cur:
            cur.execute(f"SELECT s.* FROM {st} s WHERE s.session_id = %s" + (" AND s.travel_date = %s" if td else "") + " ORDER BY s.travel_date DESC LIMIT 1",
                        [rid] + ([td] if td else []))
            r = cur.fetchone()
            if not r:
                return None
            cur.execute(f"""SELECT session_id, turn_no, role, msg_type, msg_text, agent_id, msg_ts, travel_date, source FROM {tt}
                            WHERE session_id = %s AND travel_date = %s ORDER BY turn_no""", (r["session_id"], r["travel_date"]))
            ts = cur.fetchall()
        r = dict(r, source=next((t["source"] for t in ts if t["turn_no"] == 1), ts[0]["source"] if ts else None))
        return cs_synth.session_record(r, ts)
    task = "eval" if ds == "eval" else "narr"
    key = "eval_task_id" if task == "eval" else "request_id"
    with db.cursor() as cur:
        cur.execute(guide_synth.ddl(task))
        cur.execute(f"SELECT record_json FROM {guide_synth.table(task)} WHERE {key} = %s", (rid,))
        r = cur.fetchone()
    return _json(r["record_json"]) if r else None


# ---------------------------------------------------------------- 各数据集总数（页签上的数字）
def summary():
    out = {}
    for ds in DATASETS:
        try:
            if ds == "cs":
                cs_synth.mysql_check()
                out[ds] = dict(total=cs_synth.export_count({})["sessions"], review=cs_synth.export_count(dict(review="review"))["sessions"],
                               rewrite=cs_synth.export_count(dict(method="llm_rewrite"))["sessions"],
                               expand=cs_synth.export_count(dict(method="llm_expand"))["sessions"])
            else:
                out[ds] = dict(total=guide_synth.export_count(ds, {})["rows"], review=guide_synth.export_count(ds, dict(review="review"))["rows"])
        except Exception as e:  # noqa: BLE001  一个数据集的表没建好，不影响别的
            out[ds] = dict(total=None, error=f"{type(e).__name__}: {e}" if not isinstance(e, RuntimeError) else str(e))
    return out
