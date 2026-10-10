#!/usr/bin/env python3
"""Tests for the Prometheus batch scan. Run: python3 scripts/test_prometheus_batch.py"""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace as NS
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prometheus as pm


def usage(i=0, o=0, cc=0, cr=0, searches=None):
    stu = None if searches is None else NS(web_search_requests=searches)
    return NS(input_tokens=i, output_tokens=o, cache_creation_input_tokens=cc,
              cache_read_input_tokens=cr, server_tool_use=stu)


def proposal_json(title):
    return json.dumps([{"title": title, "impact_score": 7, "risk_score": 2,
                        "effort_score": 3, "target_files": ["scripts/foo.py"]}])


def ok_result(cid, blocks, model="claude-opus-5-5", stop="end_turn", u=None):
    content = [NS(type="text", text=t) if k == "text" else NS(type=k) for k, t in blocks]
    msg = NS(model=model, content=content, stop_reason=stop,
             usage=u or usage(1000, 500, searches=2))
    return NS(custom_id=cid, result=NS(type="succeeded", message=msg))


class FakeBatches:
    def __init__(self, results, statuses=("ended",)):
        self._results = results
        self._statuses = list(statuses)
        self.create_calls = []
        self.retrieve_calls = 0

    def create(self, requests):
        self.create_calls.append(requests)
        return NS(id="msgbatch_test1")

    def retrieve(self, batch_id):
        i = min(self.retrieve_calls, len(self._statuses) - 1)
        self.retrieve_calls += 1
        return NS(id=batch_id, processing_status=self._statuses[i],
                  request_counts=NS(processing=1, succeeded=0, errored=0,
                                    canceled=0, expired=0))

    def results(self, batch_id):
        return iter(self._results)


def fake_client(results, statuses=("ended",)):
    return NS(messages=NS(batches=FakeBatches(results, statuses)))


class BatchTestBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / ".cto").mkdir()
        self.dirs = pm.ensure_prometheus_dirs(self.root)
        self._patches = [
            mock.patch.object(pm, "emit"),
            mock.patch.object(pm, "build_scan_prompt", lambda c, r: f"prompt for {c}"),
        ]
        self.emit = self._patches[0].start()
        self._patches[1].start()

    def tearDown(self):
        for p in self._patches:
            p.stop()
        self._tmp.cleanup()

    def state(self, bid="msgbatch_test1"):
        return json.loads((self.dirs["batches"] / f"{bid}.json").read_text())

    def ledger(self):
        return pm.load_ledger(self.root)


class RequestTests(BatchTestBase):
    def test_one_request_per_category(self):
        reqs = pm.build_batch_requests(["tooling", "security"], self.root, "opus")
        self.assertEqual([r["custom_id"] for r in reqs], ["tooling", "security"])
        p = reqs[0]["params"]
        self.assertEqual(p["model"], "claude-opus-5-5")
        self.assertEqual(p["tools"][0]["type"], "web_search_20260209")
        self.assertEqual(p["tools"][0]["name"], "web_search")
        self.assertEqual(p["messages"][0]["content"], "prompt for tooling")
        self.assertNotIn("thinking", p)
        self.assertNotIn("tool_choice", p)

    def test_alias_mapping(self):
        sonnet = pm.build_batch_requests(["tooling"], self.root, "sonnet")[0]["params"]
        haiku = pm.build_batch_requests(["tooling"], self.root, "haiku")[0]["params"]
        self.assertEqual(sonnet["model"], "claude-sonnet-5-5")
        self.assertEqual(sonnet["tools"][0]["type"], "web_search_20260209")
        self.assertEqual(haiku["model"], "claude-haiku-4-5")
        self.assertEqual(haiku["tools"][0]["type"], "web_search_20250305")


class CostTests(unittest.TestCase):
    def test_cost_hand_computed(self):
        totals = {"claude-opus-5-5": {
            "input_tokens": 1_000_000, "output_tokens": 100_000,
            "cache_creation_input_tokens": 200_000,
            "cache_read_input_tokens": 500_000, "web_search_requests": 10}}
        # tokens: (1.2M*4 + 0.5M*4*0.1 + 0.1M*20)/1M = 4.8+0.2+2.0 = 7.0 -> *0.5 = 3.5
        # search: 10/1000*10 = 0.10 (undiscounted)
        self.assertEqual(pm.batch_cost_usd(totals), 3.6)

    def test_unknown_model(self):
        totals = {"mystery": {"input_tokens": 5_000_000, "web_search_requests": 100}}
        self.assertEqual(pm.batch_cost_usd(totals), 1.0)  # search fees only
        self.assertTrue(pm.batch_cost_warnings(totals))

    def test_empty(self):
        self.assertEqual(pm.batch_cost_usd({}), 0.0)


class RunBatchTests(BatchTestBase):
    def test_happy_path_out_of_order_multiblock(self):
        results = [
            ok_result("security", [("text", proposal_json("Sec fix"))]),
            ok_result("tooling", [("text", "Here you go: ["),
                                  ("server_tool_use", ""),
                                  ("text", json.dumps({"title": "Tool fix", "impact_score": 8,
                                                       "target_files": ["a.py"]})),
                                  ("text", "]")]),
        ]
        client = fake_client(results)
        n = pm.run_batch_scan(self.root, self.dirs, ["tooling", "security"], "opus",
                              poll_interval=0, client=client)
        self.assertEqual(n, 2)
        self.assertEqual(len(list(self.dirs["proposals"].glob("*.json"))), 2)
        entries = [e for e in self.ledger() if e["action"] == "batch-scan"]
        self.assertEqual(len(entries), 1)
        e = entries[0]
        self.assertEqual(e["batch_id"], "msgbatch_test1")
        self.assertEqual(e["failed"], [])
        self.assertEqual(e["pricing"], "batch-50%")
        self.assertIsNone(e["proposal_id"])
        # 2 msgs x (1000 in, 500 out, 2 searches): (4000/1e6*... ) computed below
        expect = pm.batch_cost_usd({"claude-opus-5-5": {
            "input_tokens": 2000, "output_tokens": 1000, "web_search_requests": 4}})
        self.assertEqual(e["cost_usd"], expect)
        self.assertEqual(expect, 0.054)  # (2000*4+1000*20)/1e6*.5 + 4 searches*0.01
        st = self.state()
        self.assertEqual(st["status"], "collected")
        self.assertEqual(st["proposals_created"], 2)
        self.assertIn("collected_at", st)
        self.assertEqual(len(client.messages.batches.create_calls), 1)

    def test_missing_server_tool_use(self):
        r = ok_result("tooling", [("text", proposal_json("X"))], u=usage(10, 10))
        client = fake_client([r])
        n = pm.run_batch_scan(self.root, self.dirs, ["tooling"], "opus",
                              poll_interval=0, client=client)
        self.assertEqual(n, 1)

    def test_errored_and_expired(self):
        results = [
            ok_result("tooling", [("text", proposal_json("Fine"))]),
            NS(custom_id="security", result=NS(type="errored",
                                               error=NS(error=NS(message="boom")))),
            NS(custom_id="ui-ux", result=NS(type="expired")),
            NS(custom_id="bogus", result=NS(type="canceled")),
        ]
        client = fake_client(results)
        n = pm.run_batch_scan(self.root, self.dirs, ["tooling", "security", "ui-ux"],
                              "opus", poll_interval=0, client=client)
        self.assertEqual(n, 1)
        e = [x for x in self.ledger() if x["action"] == "batch-scan"][0]
        self.assertEqual(sorted(e["failed"]), ["security", "ui-ux"])
        self.assertEqual(e["succeeded"], 1)

    def test_resume_does_not_create(self):
        pm.save_json(self.dirs["batches"] / "msgbatch_old.json", {
            "batch_id": "msgbatch_old", "model": "haiku", "categories": ["tooling"],
            "submitted_at": pm.now_iso(), "status": "submitted"})
        client = fake_client([ok_result("tooling", [("text", proposal_json("R"))],
                                        model="claude-haiku-4-5")])
        n = pm.run_batch_scan(self.root, self.dirs, ["security"], "opus",
                              resume_id="msgbatch_old", poll_interval=0, client=client)
        self.assertEqual(n, 1)
        self.assertEqual(client.messages.batches.create_calls, [])
        self.assertEqual(self.state("msgbatch_old")["status"], "collected")
        e = [x for x in self.ledger() if x["action"] == "batch-scan"][0]
        self.assertEqual(e["model"], "haiku")

    def test_resume_rejects_bad_id(self):
        with self.assertRaises(ValueError):
            pm.run_batch_scan(self.root, self.dirs, ["tooling"], "opus",
                              resume_id="../evil", poll_interval=0,
                              client=fake_client([]))

    def test_timeout_returns_zero_and_stays_submitted(self):
        client = fake_client([], statuses=("in_progress",))
        n = pm.run_batch_scan(self.root, self.dirs, ["tooling"], "opus",
                              poll_interval=0, max_wait=0, client=client)
        self.assertEqual(n, 0)
        self.assertEqual(self.state()["status"], "submitted")
        self.assertEqual([x for x in self.ledger() if x["action"] == "batch-scan"], [])

    def test_polls_until_ended(self):
        client = fake_client([ok_result("tooling", [("text", proposal_json("P"))])],
                             statuses=("in_progress", "in_progress", "ended"))
        n = pm.run_batch_scan(self.root, self.dirs, ["tooling"], "opus",
                              poll_interval=0, client=client)
        self.assertEqual(n, 1)
        self.assertEqual(client.messages.batches.retrieve_calls, 3)


class ClientTests(unittest.TestCase):
    def test_unavailable_without_credentials(self):
        env = {k: v for k, v in os.environ.items()
               if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
        with mock.patch.dict(os.environ, env, clear=True):
            with self.assertRaises(pm.BatchUnavailable):
                pm.get_batch_client()


class ParserTests(unittest.TestCase):
    def test_batch_flags(self):
        a = pm.build_parser().parse_args(["scan", "--batch"])
        self.assertTrue(a.batch)
        self.assertIsNone(a.resume)
        self.assertEqual(a.poll_interval, pm.BATCH_POLL_INTERVAL)

    def test_resume_flag(self):
        a = pm.build_parser().parse_args(["scan", "--resume", "msgbatch_X", "--poll-interval", "5"])
        self.assertEqual(a.resume, "msgbatch_X")
        self.assertEqual(a.poll_interval, 5)

    def test_plain_scan_unchanged(self):
        a = pm.build_parser().parse_args(["scan"])
        self.assertFalse(a.batch)


class ExtractTests(unittest.TestCase):
    def test_extract(self):
        self.assertEqual(pm.extract_proposals_json('x [{"a": 1}] y'), [{"a": 1}])
        self.assertIsNone(pm.extract_proposals_json("nothing"))
        self.assertIsNone(pm.extract_proposals_json("[not json]"))


if __name__ == "__main__":
    unittest.main()
