"""Regression: sleepy runtime state (.cto/sleepy/**) must never be committed onto a ticket branch."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import sleepy  # noqa: E402


def _git(root, *args):
    return subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True, check=True
    ).stdout


def _init_repo(root):
    _git(root, "init", "-q", "-b", "main")
    _git(root, "config", "user.email", "t@example.com")
    _git(root, "config", "user.name", "t")
    (root / "README.md").write_text("hi\n")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "init")
    _git(root, "checkout", "-q", "-b", "sleepy/T-1")


def _write_state(root):
    d = root / ".cto" / "sleepy"
    d.mkdir(parents=True, exist_ok=True)
    (d / "config.json").write_text('{"iteration": 1}')
    (d / "budget.json").write_text('{"spent_tokens": 0}')
    return d


class SleepyStateIsolationTest(unittest.TestCase):
    def test_only_sleepy_state_dirty_is_clean_and_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _init_repo(root)
            d = _write_state(root)
            head = _git(root, "rev-parse", "HEAD")
            self.assertEqual(sleepy.sanitize_worktree(root, "T-1"), "clean")
            self.assertEqual(_git(root, "rev-parse", "HEAD"), head)  # nothing committed
            self.assertTrue((d / "config.json").exists())
            self.assertTrue((d / "budget.json").exists())

    def test_real_changes_committed_without_sleepy_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _init_repo(root)
            _write_state(root)
            (root / "work.py").write_text("x = 1\n")
            self.assertEqual(sleepy.sanitize_worktree(root, "T-1"), "committed")
            files = _git(root, "show", "--name-only", "--pretty=format:", "HEAD").split()
            self.assertIn("work.py", files)
            self.assertFalse([f for f in files if f.startswith(".cto/sleepy")])
            self.assertTrue((root / ".cto" / "sleepy" / "config.json").exists())

    def test_discard_path_preserves_sleepy_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _init_repo(root)
            d = _write_state(root)
            (root / "junk.txt").write_text("junk\n")
            # Force the commit to fail so sanitize_worktree falls into the discard path.
            hook = root / ".git" / "hooks" / "pre-commit"
            hook.write_text("#!/bin/sh\nexit 1\n")
            hook.chmod(0o755)
            self.assertEqual(sleepy.sanitize_worktree(root, "T-1"), "discarded")
            self.assertFalse((root / "junk.txt").exists())
            self.assertTrue((d / "config.json").exists())
            self.assertTrue((d / "budget.json").exists())

    def test_load_json_missing_state_yields_empty_dict(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = sleepy.load_json(Path(tmp) / "nope.json")
            self.assertEqual(cfg, {})
            self.assertEqual(cfg.get("iteration", 0) + 1, 1)  # no KeyError


if __name__ == "__main__":
    unittest.main()
