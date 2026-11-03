"""Regression: a stuck progress-ledger verdict escalates (re-route / contract rewrite / block) instead of a blind retry."""
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import orchestrate  # noqa: E402
import progress  # noqa: E402
import schemas  # noqa: E402


def _ticket(root, tid="PL-001", agent="backend-morty"):
    d = root / ".cto" / "tickets"
    d.mkdir(parents=True, exist_ok=True)
    t = {"id": tid, "title": "t", "status": "in_review", "priority": "high", "type": "task",
         "dependencies": [], "files_touched": ["a.py"], "agent_output": "done", "assigned_agent": agent}
    (d / f"{tid}.json").write_text(json.dumps(t))
    return t


def _ledger(agent, stuck=True):
    return {"is_complete": False, "is_progressing": not stuck, "is_stuck": stuck,
            "root_cause": "same bug", "next_agent": agent, "next_instruction": "try X"}


class ProgressLedgerTest(unittest.TestCase):
    def _run(self, root, ledger_entry):
        calls = []
        verdict = {"approved": False, "issues": ["bad"]}

        def fake_delegate(root_, tid, agent=None, **kw):
            calls.append(agent)
            t = orchestrate.load_ticket(root_, tid)
            t["status"] = "in_review"
            orchestrate.save_ticket(root_, t)
            return ""

        with mock.patch("delegate.review_ticket", return_value=verdict), \
             mock.patch("delegate._call_helper_json", return_value=ledger_entry), \
             mock.patch.object(orchestrate, "run_delegate", side_effect=fake_delegate), \
             mock.patch.object(orchestrate, "emit") as emit:
            result = orchestrate._review_and_close_ticket(root, orchestrate.load_ticket(root, "PL-001"))
        return result, calls, emit

    def test_schema_validates(self):
        self.assertTrue(schemas.validate_schema(_ledger("backend-morty"), schemas.PROGRESS_LEDGER_SCHEMA)[0])
        self.assertFalse(schemas.validate_schema({**_ledger("nobody")}, schemas.PROGRESS_LEDGER_SCHEMA)[0])

    def test_stuck_reroutes_to_other_agent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _ticket(root)
            _, calls, _ = self._run(root, _ledger("architect-morty"))
            self.assertEqual(calls[0], "architect-morty")

    def test_stuck_same_agent_rewrites_contract_and_third_stall_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _ticket(root)
            result, calls, emit = self._run(root, _ledger("backend-morty"))
            t = orchestrate.load_ticket(root, "PL-001")
            self.assertFalse(result)
            self.assertEqual(t["status"], "blocked")
            self.assertEqual(t["blocked_reason"], "stalled")
            self.assertIn("same bug", t["facts_learned"])
            self.assertEqual(len(t["progress_ledger"]), 3)
            self.assertTrue(any(c.args[0] == "cto.ticket.stalled" for c in emit.call_args_list))
            self.assertEqual(len(calls), 2)  # third stall blocks instead of re-delegating


class _TTY(io.StringIO):
    def isatty(self):
        return True


class OscProgressTest(unittest.TestCase):
    def _run(self, env):
        base = {k: v for k, v in os.environ.items()
                if k not in ("TERM_PROGRAM", "NO_COLOR", "CI", "TMUX", "WT_SESSION",
                             "RICK_NO_OSC_PROGRESS", "RICK_REDUCE_MOTION")}
        base.update(env)
        err = _TTY()
        with mock.patch.dict(os.environ, base, clear=True), mock.patch.object(sys, "stderr", err):
            d = progress.ProgressDisplay(total=10)
            d.update(5)
            mid = err.getvalue()
            d.finish()
        return mid, err.getvalue()

    def test_sequence_emitted_for_ghostty_and_cleared_on_finish(self):
        mid, out = self._run({"TERM_PROGRAM": "ghostty"})
        self.assertIn("\033]9;4;1;50\a", mid)
        self.assertTrue(out.endswith("\n"))
        self.assertIn("\033]9;4;0;\a", out)
        self.assertEqual(progress._osc_active, [])

    def test_absent_for_apple_terminal_and_no_color(self):
        for env in ({"TERM_PROGRAM": "Apple_Terminal"},
                    {"TERM_PROGRAM": "ghostty", "NO_COLOR": "1"}):
            _, out = self._run(env)
            self.assertNotIn("\033]9;4", out)

    def test_tmux_wraps_in_dcs_passthrough(self):
        mid, _ = self._run({"TERM_PROGRAM": "WezTerm", "TMUX": "/tmp/tmux"})
        self.assertIn("\033Ptmux;\033\033]9;4;1;50\a\033\\", mid)

    def test_fail_sets_error_state(self):
        err = _TTY()
        env = {"TERM_PROGRAM": "iTerm.app"}
        with mock.patch.dict(os.environ, env), mock.patch.object(sys, "stderr", err):
            d = progress.ProgressDisplay(total=4)
            d.update(1)
            d.fail()
        self.assertIn("\033]9;4;2;25\a", err.getvalue())
        self.assertEqual(progress._osc_active, [])


if __name__ == "__main__":
    unittest.main()
