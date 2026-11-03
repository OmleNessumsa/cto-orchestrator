"""Regression: a queued sleepy ticket must not be re-picked (in_review), discard reverts it."""
import json
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import delegate  # noqa: E402
import sleepy  # noqa: E402


def _ticket(root, tid, status):
    d = root / ".cto" / "tickets"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{tid}.json").write_text(json.dumps({
        "id": tid, "title": "t", "status": status, "priority": "high",
        "type": "task", "dependencies": [],
    }))


class SleepyRequeueTest(unittest.TestCase):
    def test_in_review_not_picked_and_discard_reverts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _ticket(root, "JF-007", "todo")
            self.assertEqual(sleepy.pick_next_ticket(root)["id"], "JF-007")
            self.assertTrue(sleepy.set_ticket_status(root, "JF-007", "in_review"))
            self.assertIsNone(sleepy.pick_next_ticket(root))
            self.assertTrue(sleepy.set_ticket_status(root, "JF-007", "todo", only_from="in_review"))
            self.assertEqual(sleepy.pick_next_ticket(root)["id"], "JF-007")

    def test_only_from_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _ticket(root, "JF-008", "done")
            self.assertFalse(sleepy.set_ticket_status(root, "JF-008", "todo", only_from="in_review"))

    def test_run_delegate_resume_adds_flag_and_env(self):
        with mock.patch.object(sleepy.subprocess, "run") as run:
            run.return_value = mock.Mock(returncode=0, stdout="", stderr="")
            sleepy.run_delegate(Path("."), "JF-009", "fullstack-morty", 1000, resume=True)
            cmd, kwargs = run.call_args[0][0], run.call_args[1]
            self.assertIn("--resume", cmd)
            self.assertEqual(kwargs["env"]["CLAUDE_CODE_RESUME_INTERRUPTED_TURN"], "1")
            sleepy.run_delegate(Path("."), "JF-009", "fullstack-morty", 1000)
            self.assertNotIn("--resume", run.call_args[0][0])


class GracefulStopTest(unittest.TestCase):
    def test_sigint_handler_stopped_without_sigkill(self):
        script = textwrap.dedent("""
            import signal, sys, time
            signal.signal(signal.SIGINT, lambda *a: sys.exit(0))
            print("ready", flush=True)
            time.sleep(60)
        """)
        proc = subprocess.Popen([sys.executable, "-c", script], stdout=subprocess.PIPE,
                                text=True, start_new_session=True)
        proc.stdout.readline()
        start = time.time()
        delegate._graceful_stop(proc)
        self.assertEqual(proc.returncode, 0)  # clean exit via SIGINT, not -SIGKILL
        self.assertLess(time.time() - start, 10)


if __name__ == "__main__":
    unittest.main()
