#!/usr/bin/env python3
"""Unit tests for nested-subagent guardrail propagation (PROM-175 follow-up).

Verifies that delegate.build_subagent_guardrail_args() injects the
--append-subagent-system-prompt-file flag for every Morty role, and that
persona.build_subagent_guardrails() embeds that role's tool allowlist.

Run with: python3 scripts/test_subagent_guardrails.py
"""

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import delegate
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


if __name__ == "__main__":
    unittest.main()
