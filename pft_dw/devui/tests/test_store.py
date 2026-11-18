"""python -m unittest discover -s tests   （在 pft_dw/devui 目录下运行）"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
from db import Store  # noqa: E402
import seed_pft  # noqa: E402


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.store = Store(Path(self.dir.name) / "t.db")

    def tearDown(self):
        self.store.conn.close()
        self.dir.cleanup()

    def test_seed_and_roundtrip(self):
        draft = seed_pft.ensure(self.store)
        got = self.store.draft(seed_pft.PID)
        self.assertEqual(json.dumps(got, sort_keys=True, ensure_ascii=False), json.dumps(draft, sort_keys=True, ensure_ascii=False))
        names = [p["id"] for p in self.store.projects()]
        self.assertIn("tourism-default", names)
        self.assertIn(seed_pft.PID, names)

    def test_flows_cover_workflow(self):
        draft = seed_pft.ensure(self.store)
        ids = {t["id"] for t in draft["tasks"]}
        for f in draft["flows"]:
            nodes = {n["taskId"] for n in f["nodes"]}
            self.assertTrue(nodes <= ids, f["name"])
            for a, b in f["edges"]:
                self.assertIn(a, nodes); self.assertIn(b, nodes)
            for g in f["groups"]:
                self.assertTrue(set(g["ids"]) <= nodes)
        daily = next(f for f in draft["flows"] if f["id"] == "flow_daily")
        self.assertEqual(len(daily["nodes"]), 444)

    def test_kv_routing(self):
        seed_pft.ensure(self.store)
        self.store.put_kv("dataflow-query-drafts:pft-dw", json.dumps({"tabs": []}))
        kv = self.store.all_kv()
        self.assertIn("dataflow-ui-draft-v2:pft-dw", kv)
        self.assertIn("dataflow-query-drafts:pft-dw", kv)
        projects = json.loads(kv["dataflow-projects-v1"])
        projects = [p for p in projects if p["id"] != "tourism-default"]
        self.store.put_kv("dataflow-projects-v1", json.dumps(projects))
        self.assertNotIn("tourism-default", [p["id"] for p in self.store.projects()])
        seed_pft.ensure(self.store)          # 重启不恢复已删除项目
        self.assertNotIn("tourism-default", [p["id"] for p in self.store.projects()])

    def test_meta(self):
        seed_pft.ensure(self.store)
        m = self.store.task_meta("dwd_ord_order_di")
        self.assertEqual(m["table"]["db"], "dwd")
        self.assertTrue(m["columns"] and m["rules"] and m["upstream"])
        self.assertTrue(self.store.task_meta("monitor_flink_job_fin_account_fund")["rules"])
        self.assertIsNone(self.store.task_meta("no_such_task"))


if __name__ == "__main__":
    unittest.main()
