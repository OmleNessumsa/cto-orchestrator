#!/usr/bin/env python3
"""Unit tests for the native Claude Code sandbox wiring (PROM-192).

Covers security_utils sandbox helpers, delegate.build_settings_args(),
prometheus.evolve_sandbox_args(), sleepy.run_delegate() and the absence of
a project-level sandbox block in .claude/settings.json.

Run with: python3 scripts/test_native_sandbox.py
"""

import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import delegate
import prometheus
import security_utils
import sleepy

REPO_ROOT = Path(__file__).resolve().parent.parent


def _clean_env(**extra):
    """Env without the sandbox/egress overrides, plus extra keys."""
    env = {k: v for k, v in os.environ.items()
           if k not in ("CTO_EGRESS_ALLOWLIST", "CTO_NATIVE_SANDBOX", "CTO_UNATTENDED")}
    env.update(extra)
    return env


class SandboxDomainsTest(unittest.TestCase):
    def test_every_allowlist_host_and_wildcard(self):
        with patch.dict(os.environ, _clean_env(), clear=True):
            domains = security_utils.sandbox_domains()
        for host in security_utils._DEFAULT_EGRESS_ALLOWLIST:
            self.assertIn(host, domains)
            self.assertIn("*." + host, domains)
        self.assertEqual(domains, sorted(set(domains)))

    def test_honours_env_allowlist_and_normalises(self):
        with patch.dict(os.environ, _clean_env(CTO_EGRESS_ALLOWLIST="Example.COM., ,internal.dev"), clear=True):
            domains = security_utils.sandbox_domains(extra_domains=["  Extra.io ", ""])
        self.assertEqual(domains, sorted([
            "example.com", "*.example.com", "internal.dev", "*.internal.dev",
            "extra.io", "*.extra.io",
        ]))
        self.assertNotIn("github.com", domains)


class BuildSandboxSettingsTest(unittest.TestCase):
    def test_strict_follows_unattended(self):
        with tempfile.TemporaryDirectory() as tmp:
            attended = security_utils.build_sandbox_settings(tmp)["sandbox"]
            unattended = security_utils.build_sandbox_settings(tmp, unattended=True)["sandbox"]
        self.assertFalse(attended["network"]["strictAllowlist"])
        self.assertFalse(attended["failIfUnavailable"])
        self.assertTrue(unattended["network"]["strictAllowlist"])
        self.assertTrue(unattended["failIfUnavailable"])

    def test_shape_and_write_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            sb = security_utils.build_sandbox_settings(tmp, extra_write=["/opt/cache"])["sandbox"]
            allow_write = sb["filesystem"]["allowWrite"]
            self.assertIn(str(Path(tmp).resolve()), allow_write)
        self.assertTrue(sb["enabled"])
        self.assertIs(sb["allowUnsandboxedCommands"], False)
        self.assertIn("/tmp", allow_write)
        self.assertIn("/opt/cache", allow_write)
        self.assertEqual(sb["network"]["allowedDomains"], security_utils.sandbox_domains())


class NativeSandboxFlagTest(unittest.TestCase):
    def _root(self, tmp, config_text=None):
        root = Path(tmp)
        (root / ".cto").mkdir()
        if config_text is not None:
            (root / ".cto" / "config.json").write_text(config_text)
        return root

    def test_default_true_without_config(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, _clean_env(), clear=True):
            self.assertTrue(security_utils.native_sandbox_enabled(self._root(tmp)))

    def test_config_false_disables(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, _clean_env(), clear=True):
            root = self._root(tmp, json.dumps({"security": {"native_sandbox": False}}))
            self.assertFalse(security_utils.native_sandbox_enabled(root))

    def test_env_zero_forces_off(self):
        with tempfile.TemporaryDirectory() as tmp, \
                patch.dict(os.environ, _clean_env(CTO_NATIVE_SANDBOX="0"), clear=True):
            root = self._root(tmp, json.dumps({"security": {"native_sandbox": True}}))
            self.assertFalse(security_utils.native_sandbox_enabled(root))

    def test_broken_json_keeps_default(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, _clean_env(), clear=True):
            self.assertTrue(security_utils.native_sandbox_enabled(self._root(tmp, "{not json")))


class CliSupportTest(unittest.TestCase):
    def test_versions(self):
        self.assertTrue(security_utils.cli_supports_native_sandbox("2.1.286 (Claude Code)"))
        self.assertTrue(security_utils.cli_supports_native_sandbox("2.1.219"))
        self.assertFalse(security_utils.cli_supports_native_sandbox("2.1.218"))
        self.assertFalse(security_utils.cli_supports_native_sandbox(""))
        self.assertFalse(security_utils.cli_supports_native_sandbox("garbage"))


class WriteSandboxSettingsTest(unittest.TestCase):
    def test_merges_base_and_is_private(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = {"hooks": {"PreToolUse": [{"matcher": "Bash"}]}}
            path = security_utils.write_sandbox_settings(tmp, "../PROM-1", base=base, unattended=True)
            data = json.loads(path.read_text())
            # separators are stripped, so a traversal tag stays inside .cto/session
            self.assertEqual(path.resolve().parent, (Path(tmp) / ".cto" / "session").resolve())
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(data["hooks"], base["hooks"])
        self.assertTrue(data["sandbox"]["network"]["strictAllowlist"])
        self.assertNotIn("sandbox", base)  # caller's dict is not mutated


class BuildSettingsArgsTest(unittest.TestCase):
    def setUp(self):
        delegate._claude_version_string = "2.1.300 (Claude Code)"
        delegate._claude_hook_fail_closed_supported = None
        delegate._warned_sandbox_skipped = False
        delegate._warned_hooks_fail_open = False
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / ".cto").mkdir()

    def tearDown(self):
        self._tmp.cleanup()
        delegate._claude_version_string = None
        delegate._claude_hook_fail_closed_supported = None

    def _run(self, **env):
        with patch.dict(os.environ, _clean_env(**env), clear=True), \
                patch.object(delegate, "emit") as emit:
            args = delegate.build_settings_args(self.root, "PROM-192", "backend-morty")
        return args, emit

    def test_single_settings_flag_with_sandbox_and_hooks(self):
        with patch.object(delegate, "_check_claude_hook_fail_closed_support", return_value=True):
            args, emit = self._run()
        self.assertEqual(args.count("--settings"), 1)
        data = json.loads(Path(args[1]).read_text())
        self.assertIn("sandbox", data)
        self.assertIn("hooks", data)
        self.assertFalse(data["sandbox"]["network"]["strictAllowlist"])
        events = [c.args[0] for c in emit.call_args_list]
        self.assertIn("security.sandbox_enabled", events)
        payload = next(c.args[1] for c in emit.call_args_list if c.args[0] == "security.sandbox_enabled")
        self.assertEqual(payload["ticket_id"], "PROM-192")
        self.assertEqual(payload["settings_path"], args[1])
        self.assertGreater(payload["domains"], 0)

    def test_unattended_is_strict_and_hooks_absent_on_old_cli(self):
        with patch.object(delegate, "_check_claude_hook_fail_closed_support", return_value=False):
            args, emit = self._run(CTO_UNATTENDED="1")
        self.assertEqual(args.count("--settings"), 1)
        data = json.loads(Path(args[1]).read_text())
        self.assertNotIn("hooks", data)
        self.assertTrue(data["sandbox"]["network"]["strictAllowlist"])
        self.assertIn("guardrail.warning", [c.args[0] for c in emit.call_args_list])

    def test_flag_off_disables_sandbox(self):
        with patch.object(delegate, "_check_claude_hook_fail_closed_support", return_value=True):
            args, emit = self._run(CTO_NATIVE_SANDBOX="0")
        self.assertEqual(args.count("--settings"), 1)  # hooks-only fallback
        self.assertNotIn("sandbox", json.loads(Path(args[1]).read_text()))
        events = [c.args[0] for c in emit.call_args_list]
        self.assertIn("security.sandbox_skipped", events)
        self.assertNotIn("security.sandbox_enabled", events)

    def test_unsupported_cli_disables_sandbox(self):
        delegate._claude_version_string = "2.1.100"
        args, emit = self._run()
        self.assertEqual(args, [])  # old CLI: no sandbox, no fail-closed hooks
        self.assertIn("security.sandbox_skipped", [c.args[0] for c in emit.call_args_list])


class PrometheusEvolveSandboxTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / ".cto").mkdir()
        prometheus._claude_version_string = "2.1.286 (Claude Code)"

    def tearDown(self):
        self._tmp.cleanup()
        prometheus._claude_version_string = None

    def test_delegate_evolve_passes_strict_settings_before_prompt(self):
        captured = {}

        class Result:
            returncode = 0
            stdout = "ok"
            stderr = ""

        def fake_run(cmd, **kwargs):
            captured["cmd"] = cmd
            return Result()

        with patch.dict(os.environ, _clean_env(), clear=True), \
                patch.object(prometheus, "find_cto_root", return_value=self.root), \
                patch.object(prometheus, "emit") as emit, \
                patch.object(prometheus.subprocess, "run", side_effect=fake_run):
            prometheus.delegate_evolve("do the thing", model="sonnet", timeout=5)
        cmd = captured["cmd"]
        self.assertEqual(cmd.count("--settings"), 1)
        idx = cmd.index("--settings")
        self.assertEqual(cmd[-1], "do the thing")
        self.assertLess(idx, len(cmd) - 2)
        data = json.loads(Path(cmd[idx + 1]).read_text())
        self.assertTrue(data["sandbox"]["network"]["strictAllowlist"])
        payload = next(c.args[1] for c in emit.call_args_list if c.args[0] == "security.sandbox_enabled")
        self.assertEqual(payload["source"], "prometheus.evolve")
        self.assertTrue(payload["strict"])

    def test_flag_off_no_settings(self):
        with patch.dict(os.environ, _clean_env(CTO_NATIVE_SANDBOX="0"), clear=True), \
                patch.object(prometheus, "find_cto_root", return_value=self.root), \
                patch.object(prometheus, "emit"):
            self.assertEqual(prometheus.evolve_sandbox_args(), [])

    def test_unsupported_cli_no_settings(self):
        prometheus._claude_version_string = "2.1.0"
        with patch.dict(os.environ, _clean_env(), clear=True), \
                patch.object(prometheus, "find_cto_root", return_value=self.root), \
                patch.object(prometheus, "emit"):
            self.assertEqual(prometheus.evolve_sandbox_args(), [])


class ProjectSettingsNoBaselineTest(unittest.TestCase):
    def test_project_settings_have_no_sandbox_block(self):
        # A project-level sandbox also sandboxes interactive Rick sessions; a
        # Morty spawned from there then needs a nested Seatbelt sandbox, which
        # fails to start and leaves the Morty without Bash. Morties get their
        # sandbox via the per-spawn --settings file instead (ZEAS-072).
        settings = json.loads((REPO_ROOT / ".claude" / "settings.json").read_text())
        self.assertNotIn("sandbox", settings)
        self.assertIn("hooks", settings)


class SleepyUnattendedTest(unittest.TestCase):
    def test_run_delegate_sets_unattended_env(self):
        class Result:
            returncode = 0
            stdout = "done"
            stderr = ""

        with tempfile.TemporaryDirectory() as tmp, \
                patch.object(sleepy.subprocess, "run", return_value=Result()) as run:
            ok, _ = sleepy.run_delegate(Path(tmp), "PROM-192", "backend-morty", 60000)
        self.assertTrue(ok)
        env = run.call_args.kwargs["env"]
        self.assertEqual(env["CTO_UNATTENDED"], "1")
        self.assertIn("PATH", env)  # inherits the parent environment


if __name__ == "__main__":
    unittest.main()
