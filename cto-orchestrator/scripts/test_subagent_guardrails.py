#!/usr/bin/env python3
"""Unit tests for nested-subagent guardrail propagation (PROM-175 follow-up).

Verifies that delegate.build_subagent_guardrail_args() injects the
--append-subagent-system-prompt-file flag for every Morty role, and that
persona.build_subagent_guardrails() embeds that role's tool allowlist.

Run with: python3 scripts/test_subagent_guardrails.py
"""

import io
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import delegate
import security_utils
import team as team_module
from persona import AGENT_PROFILES, build_subagent_guardrails


class FakeHelpResult:
    def __init__(self, stdout: str):
        self.stdout = stdout
        self.stderr = ""


def _fake_run_with_file_flag(cmd, **kwargs):
    if cmd[:2] == ["claude", "--help"]:
        return FakeHelpResult("... --append-subagent-system-prompt-file <path> ...")
    raise AssertionError(f"unexpected subprocess.run call: {cmd}")


class BuildSubagentGuardrailArgsTest(unittest.TestCase):
    def setUp(self):
        # Capability probes cache their result in module globals; reset before
        # each test so mocked subprocess.run calls are actually exercised.
        delegate._reset_claude_flag_caches()
        self._tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self._tmpdir.name)

    def tearDown(self):
        self._tmpdir.cleanup()

    def test_flag_present_for_every_role(self):
        for role in AGENT_PROFILES:
            with self.subTest(role=role):
                delegate._reset_claude_flag_caches()
                with patch("subprocess.run", side_effect=_fake_run_with_file_flag):
                    args = delegate.build_subagent_guardrail_args(self.root, role)
                self.assertIn("--append-subagent-system-prompt-file", args)
                prompt_path = Path(args[args.index("--append-subagent-system-prompt-file") + 1])
                self.assertTrue(prompt_path.exists())

    def test_guardrail_text_contains_role_allowlist(self):
        for role, profile in AGENT_PROFILES.items():
            with self.subTest(role=role):
                guardrails = build_subagent_guardrails(role)
                for tool in profile["allowedTools"]:
                    self.assertIn(tool, guardrails)

    def test_falls_back_to_inline_flag_on_older_cli(self):
        def fake_run(cmd, **kwargs):
            if cmd[:2] == ["claude", "--help"]:
                return FakeHelpResult("... --append-subagent-system-prompt <text> ...")
            raise AssertionError(f"unexpected subprocess.run call: {cmd}")

        with patch("subprocess.run", side_effect=fake_run):
            args = delegate.build_subagent_guardrail_args(self.root, "backend-morty")
        self.assertEqual(args[0], "--append-subagent-system-prompt")
        self.assertIn("<subagent_guardrails>", args[1])

    def test_no_op_when_cli_supports_neither_flag(self):
        with patch("subprocess.run", side_effect=lambda cmd, **kw: FakeHelpResult("--help only")):
            args = delegate.build_subagent_guardrail_args(self.root, "backend-morty")
        self.assertEqual(args, [])


class ProtectedControlPathTest(unittest.TestCase):
    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self._tmpdir.name)

    def tearDown(self):
        self._tmpdir.cleanup()

    def test_protected_files_blocked_for_edit(self):
        for rel in (
            ".claude/settings.json",
            ".claude/settings.local.json",
            ".claude/agents/backend-morty.md",
            "scripts/hooks.py",
            "scripts/security_utils.py",
            ".cto/session/SESSION_STATE.json",
            ".cto/config.json",
            ".cto/security/module-hashes.json",
        ):
            with self.subTest(path=rel):
                blocked, reason = security_utils.is_path_in_denylist(
                    str(self.root / rel), repo_root=self.root
                )
                self.assertTrue(blocked)
                self.assertIn("Protected control file", reason)

    def test_ordinary_files_not_blocked(self):
        for rel in ("scripts/delegate.py", "README.md", ".claude/commands/x.md"):
            with self.subTest(path=rel):
                blocked, _ = security_utils.is_path_in_denylist(
                    str(self.root / rel), repo_root=self.root
                )
                self.assertFalse(blocked)

    def test_env_override_allows_control_edit(self):
        with patch.dict("os.environ", {"CTO_ALLOW_CONTROL_EDIT": "1"}):
            blocked, _ = security_utils.is_path_in_denylist(
                str(self.root / "scripts/hooks.py"), repo_root=self.root
            )
            self.assertFalse(blocked)
            dangerous, _ = security_utils.scan_bash_command("sed -i 's/a/b/' scripts/hooks.py")
            self.assertFalse(dangerous)

    def test_bash_writes_blocked(self):
        for cmd in (
            "sed -i '' 's/x/y/' .claude/settings.json",
            "echo {} > .claude/settings.json",
            "echo x >> scripts/security_utils.py",
            "cat foo | tee .cto/config.json",
            "mv /tmp/h.py scripts/hooks.py",
            "cp /tmp/a.md .claude/agents/backend-morty.md",
            "git checkout abc123 -- scripts/hooks.py",
        ):
            with self.subTest(cmd=cmd):
                dangerous, reason = security_utils.scan_bash_command(cmd)
                self.assertTrue(dangerous)
                self.assertIn("Protected control file", reason)

    def test_bash_reads_allowed(self):
        for cmd in ("cat .claude/settings.json", "grep -n foo scripts/hooks.py", "git status"):
            with self.subTest(cmd=cmd):
                dangerous, _ = security_utils.scan_bash_command(cmd)
                self.assertFalse(dangerous)

    def test_hook_audits_and_emits_on_block(self):
        import hooks
        payload = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": str(self.root / ".claude/settings.json")},
            "cwd": str(self.root),
        })
        (self.root / ".cto").mkdir()
        with patch("sys.stdin", io.StringIO(payload)), \
                patch.object(hooks, "_emit_guardrail_block") as emit, \
                patch("security_utils.audit_log_security_event") as audit, \
                patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                hooks.guardrail_hook()
        self.assertEqual(cm.exception.code, 2)
        self.assertEqual(audit.call_args.kwargs["severity"], "critical")
        emit.assert_called()


class FailClosedStatusTest(unittest.TestCase):
    def test_invalid_status_becomes_needs_review(self):
        from schemas import AgentOutput
        out = AgentOutput(status="garbage")
        self.assertEqual(out.status, "needs_review")
        self.assertTrue(out.status_coerced)

    def test_valid_status_not_coerced(self):
        from schemas import AgentOutput
        out = AgentOutput(status="completed")
        self.assertEqual(out.status, "completed")
        self.assertFalse(out.status_coerced)

    def test_missing_status_in_json_is_needs_review(self):
        from schemas import parse_agent_json
        out = parse_agent_json('{"status": null, "files_changed": ["a.py"]}')
        self.assertEqual(out.status, "needs_review")
        self.assertTrue(out.status_coerced)

    def test_meeseeks_invalid_status_is_too_complex(self):
        from schemas import MeeseeksOutput
        out = MeeseeksOutput(status="bogus")
        self.assertEqual(out.status, "too_complex")
        self.assertTrue(out.status_coerced)


class VerifyFilesChangedTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.cwd = self._tmp.name
        self.addCleanup(self._tmp.cleanup)
        for cmd in (
            ["git", "init", "-q"],
            ["git", "config", "user.email", "t@example.com"],
            ["git", "config", "user.name", "t"],
        ):
            subprocess.run(cmd, cwd=self.cwd, check=True)
        (Path(self.cwd) / "base.txt").write_text("base\n")
        (Path(self.cwd) / "predirty.txt").write_text("v1\n")
        subprocess.run(["git", "add", "."], cwd=self.cwd, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=self.cwd, check=True)
        (Path(self.cwd) / "predirty.txt").write_text("v2\n")  # dirty before delegation

    def test_mismatched_claim_is_reported(self):
        snap = delegate._snapshot_pre_delegation(self.cwd)
        (Path(self.cwd) / "new.py").write_text("x = 1\n")
        (Path(self.cwd) / "base.txt").write_text("changed\n")
        v = delegate._verify_files_changed(self.cwd, snap, ["new.py", "ghost.py"])
        self.assertEqual(v["actual_files"], ["base.txt", "new.py"])
        self.assertEqual(v["claimed_not_touched"], ["ghost.py"])
        self.assertEqual(v["touched_not_claimed"], ["base.txt"])

    def test_pre_dirty_file_untouched_is_not_actual(self):
        snap = delegate._snapshot_pre_delegation(self.cwd)
        v = delegate._verify_files_changed(self.cwd, snap, ["predirty.txt"])
        self.assertEqual(v["actual_files"], [])
        self.assertEqual(v["claimed_not_touched"], ["predirty.txt"])

    def test_no_snapshot_means_no_verification(self):
        self.assertIsNone(delegate._verify_files_changed(self.cwd, None, ["a"]))


class TestStructuredReport(unittest.TestCase):
    """Final report via --json-schema/StructuredOutput, regex as fallback."""

    STRUCTURED = {
        "status": "completed",
        "files_changed": ["a.py"],
        "description": "did it",
        "criteria_check": [{"criterion": "c", "verdict": "pass", "evidence": "a.py:1"}],
    }

    def test_schema_is_strict(self):
        from schemas import AGENT_REPORT_JSON_SCHEMA as S
        self.assertEqual(S["properties"]["files_changed"]["minItems"], 1)
        self.assertEqual(S["properties"]["description"]["minLength"], 1)
        self.assertEqual(set(S["required"]), {"status", "files_changed", "description"})
        self.assertEqual(
            S["properties"]["criteria_check"]["items"]["properties"]["verdict"]["enum"],
            ["pass", "fail", "unknown"],
        )

    def test_structured_output_preferred_over_regex(self):
        text = '<result_json>{"status": "blocked", "files_changed": ["x"], "description": "wrong"}</result_json>'
        with patch.object(delegate, "emit") as em:
            parsed = delegate.parse_agent_output(text, structured=self.STRUCTURED)
        self.assertEqual(parsed["status"], "completed")
        self.assertEqual(parsed["description"], "did it")
        em.assert_called_with("cto.morty.report", {"report_source": "structured"})

    def test_regex_fallback_when_no_structured_output(self):
        text = '<result_json>{"status": "completed", "files_changed": ["x.py"], "description": "ok"}</result_json>'
        with patch.object(delegate, "emit") as em, patch.object(delegate, "_last_structured_output", None):
            parsed = delegate.parse_agent_output(text)
        self.assertEqual(parsed["files_changed"], ["x.py"])
        em.assert_called_with("cto.morty.report", {"report_source": "regex"})

    def test_structured_downgrades_on_failed_criterion(self):
        data = dict(self.STRUCTURED, criteria_check=[{"criterion": "c", "verdict": "fail", "evidence": "none"}])
        with patch.object(delegate, "emit"):
            parsed = delegate.parse_agent_output("", structured=data)
        self.assertEqual(parsed["status"], "needs_review")

    def test_probe_requires_structured_output_in_result_event(self):
        def run_with(stdout):
            delegate._claude_stream_json_schema_ok = None
            fake = subprocess.CompletedProcess([], 0, stdout=stdout, stderr="")
            with patch.object(delegate, "_check_claude_json_schema_support", return_value=True), \
                 patch.object(delegate.subprocess, "run", return_value=fake), \
                 patch.dict("os.environ", {"CTO_STRUCTURED_REPORT": "1"}):
                return delegate._claude_stream_json_schema_supported()
        try:
            self.assertTrue(run_with('{"type":"system"}\n{"type":"result","structured_output":{"ok":true}}\n'))
            self.assertFalse(run_with('{"type":"result","result":"ok"}\n'))
        finally:
            delegate._claude_stream_json_schema_ok = None

    def test_prompt_contract_shrinks_in_schema_mode(self):
        root = Path(tempfile.mkdtemp())
        with patch.object(delegate, "_structured_report_active", return_value=True):
            on = delegate.build_system_prefix(root, "backend-morty")
        with patch.object(delegate, "_structured_report_active", return_value=False):
            off = delegate.build_system_prefix(root, "backend-morty")
        self.assertIn("StructuredOutput tool", on)
        self.assertNotIn("<result_json>", on.split("<output_format>")[1].split("</output_format>")[0])
        self.assertIn("<result_json>", off)


class CalmPromptWordingTest(unittest.TestCase):
    """Model-facing prompts use plain directives with reasons, not shouted ones."""

    EMPHATIC = re.compile(r"\b(MUST|NEVER|CRITICAL|MANDATORY)\b")

    def _assert_calm(self, text):
        hits = [ln for ln in text.splitlines() if self.EMPHATIC.search(ln)]
        self.assertEqual(hits, [])

    def _ticket(self):
        return {"id": "T-1", "title": "Demo", "description": "d", "acceptance_criteria": ["works"]}

    def test_solo_prompt_is_calm(self):
        root = Path(tempfile.mkdtemp())
        self._assert_calm(delegate.build_system_prefix(root, "backend-morty"))
        self._assert_calm(delegate.build_task_prompt(root, self._ticket(), "backend-morty"))

    def test_team_prompt_and_contract_are_calm(self):
        root = Path(tempfile.mkdtemp())
        team_id = "team-test"
        active = team_module.active_teams_dir(root)
        active.mkdir(parents=True, exist_ok=True)
        (active / f"{team_id}.json").write_text(json.dumps({
            "id": team_id,
            "members": [{"role": "backend", "focus": "api", "assignment": "x"}],
        }))
        contract = team_module.write_contract(root, team_id, self._ticket())
        self._assert_calm(contract.read_text())
        prompt = delegate.build_task_prompt(root, self._ticket(), "backend-morty", team_id=team_id)
        self.assertIn("team mode", prompt)
        self._assert_calm(prompt)


class FailClosedGuardrailHooksTest(unittest.TestCase):
    """Guardrail hooks must carry onFailure=block on CLI >= 2.1.295."""

    def setUp(self):
        delegate._reset_claude_flag_caches()
        delegate._warned_hooks_fail_open = False
        self._tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self._tmpdir.name)

    def tearDown(self):
        delegate._reset_claude_flag_caches()
        self._tmpdir.cleanup()

    def _version(self, text):
        return patch("delegate._get_claude_version", return_value=text)

    def test_settings_payload_blocks_and_has_timeout(self):
        from hooks import build_guardrail_hooks_settings
        entries = build_guardrail_hooks_settings(fail_closed=True)["hooks"]["PreToolUse"]
        self.assertTrue(entries)
        for entry in entries:
            for hook in entry["hooks"]:
                self.assertEqual(hook["onFailure"], "block")
                self.assertGreater(hook["timeout"], 0)

    def test_args_emitted_on_new_cli(self):
        with self._version("2.1.295 (Claude Code)"):
            args = delegate.build_guardrail_hook_args(self.root)
        self.assertEqual(args[0], "--settings")
        payload = json.loads(Path(args[1]).read_text())
        for entry in payload["hooks"]["PreToolUse"]:
            self.assertEqual(entry["hooks"][0]["onFailure"], "block")

    def test_old_cli_skips_and_warns_once(self):
        with self._version("2.1.294 (Claude Code)"), patch("delegate.emit") as emit:
            self.assertEqual(delegate.build_guardrail_hook_args(self.root), [])
            self.assertEqual(delegate.build_guardrail_hook_args(self.root), [])
        self.assertEqual(emit.call_count, 1)

    def test_broken_hook_blocks_write_live(self):
        """Hook pointed at a nonexistent script: a protected-file Write must be denied."""
        import shutil
        if not shutil.which("claude") or not delegate._check_claude_hook_fail_closed_support():
            self.skipTest("claude CLI >= 2.1.295 not available")
        settings = {"hooks": {"PreToolUse": [{"matcher": "Edit|Write", "hooks": [{
            "type": "command",
            "command": "python3 /nonexistent/guardrail_hook.py",
            "timeout": 10,
            "onFailure": "block",
        }]}]}}
        settings_path = self.root / "settings.json"
        settings_path.write_text(json.dumps(settings))
        target = self.root / ".claude" / "settings.local.json"
        target.parent.mkdir()
        result = subprocess.run(
            ["claude", "-p", "--settings", str(settings_path), "--allowedTools", "Write",
             "--permission-mode", "acceptEdits", "--output-format", "json", "--",
             f"Use the Write tool to write '{{}}' to {target}. Report any denial verbatim."],
            capture_output=True, text=True, timeout=180, cwd=self.root,
        )
        self.assertFalse(target.exists(), "write went through despite broken guardrail hook")
        output = (result.stdout + result.stderr).lower()
        self.assertTrue(any(w in output for w in ("denied", "blocked", "hook")),
                        f"denial not reported: {output[:300]}")


class InstallHardeningEnvTest(unittest.TestCase):
    def _env(self, security):
        with patch.object(security_utils, "_pkg_security_config", return_value=security):
            return security_utils.install_hardening_env()

    def test_scripts_disabled_by_default(self):
        env = self._env({})
        self.assertEqual(env["npm_config_ignore_scripts"], "true")
        self.assertEqual(env["YARN_ENABLE_SCRIPTS"], "false")

    def test_scripts_allowed_by_config(self):
        self.assertNotIn("npm_config_ignore_scripts", self._env({"allow_install_scripts": True}))

    def test_delegate_env_contains_flag(self):
        with patch.object(security_utils, "_pkg_security_config", return_value={}):
            self.assertEqual(delegate._clean_subprocess_env()["npm_config_ignore_scripts"], "true")

    def test_allowlist_hint(self):
        with patch.object(security_utils, "_pkg_security_config",
                          return_value={"install_scripts_allowlist": ["esbuild"]}):
            self.assertIn("npm rebuild esbuild", security_utils.install_scripts_hint())

    def test_override_flagged_as_warning(self):
        with patch.object(security_utils, "audit_log_security_event") as log:
            security_utils.scan_bash_command("npm install foo --foreground-scripts")
        self.assertEqual(log.call_args[1].get("severity"), "warning")


class TestTamperGuardTest(unittest.TestCase):
    def test_is_test_path(self):
        for p in ("tests/a.py", "pkg/test_x.py", "x_test.py", "web/__tests__/a.ts",
                  "a.spec.ts", "a.test.ts", "conftest.py", "jest.config.js", "pytest.ini"):
            self.assertTrue(security_utils.is_test_path(p), p)
        for p in ("src/app.py", "scripts/delegate.py", ""):
            self.assertFalse(security_utils.is_test_path(p), p)

    def test_assertion_removed_is_flagged(self):
        diff = ("diff --git a/tests/test_a.py b/tests/test_a.py\n--- a/tests/test_a.py\n+++ b/tests/test_a.py\n"
                "@@ -1,4 +1,3 @@\n def test_a():\n     x = f()\n-    assert x == 2\n     print(x)\n")
        self.assertTrue(security_utils.diff_weakens_tests(diff))

    def test_skip_added_is_flagged(self):
        diff = ("diff --git a/tests/test_a.py b/tests/test_a.py\n--- a/tests/test_a.py\n+++ b/tests/test_a.py\n"
                "@@ -1,2 +1,3 @@\n+@pytest.mark.skip\n def test_a():\n     assert f() == 2\n")
        self.assertTrue(security_utils.diff_weakens_tests(diff))

    def test_new_legit_test_not_flagged(self):
        diff = ("diff --git a/tests/test_b.py b/tests/test_b.py\n--- /dev/null\n+++ b/tests/test_b.py\n"
                "@@ -0,0 +1,3 @@\n+def test_b():\n+    assert g() == 3\n+    assert g() != 4\n")
        self.assertEqual(security_utils.diff_weakens_tests(diff), [])

    def test_non_test_file_ignored(self):
        diff = ("diff --git a/src/a.py b/src/a.py\n--- a/src/a.py\n+++ b/src/a.py\n"
                "@@ -1 +0,0 @@\n-    assert x\n")
        self.assertEqual(security_utils.diff_weakens_tests(diff), [])


if __name__ == "__main__":
    unittest.main()
