#!/usr/bin/env python3
"""Unit tests for per-Morty --agents definitions (build_agent_definition).

Asserts the generated --agents JSON matches the tool allowlist enforced by the
--allowedTools flag path, and that the CLI version gate and resume env work.

Run with: python3 scripts/test_agent_definitions.py
"""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import delegate
from persona import AGENT_PROFILES


class AgentDefinitionTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / ".cto").mkdir()
        delegate._claude_agents_flag_supported = None

    def tearDown(self):
        delegate._claude_agents_flag_supported = None

    def test_tools_match_flag_allowlist_for_every_role(self):
        for role in AGENT_PROFILES:
            spec = delegate.build_agent_definition(role, {"id": "T-1"}, root=self.root)
            self.assertEqual(list(spec), [role])
            self.assertEqual(spec[role]["tools"], delegate.resolve_role_allowed_tools(self.root, role), role)
            self.assertEqual(spec[role]["disallowedTools"],
                             list(AGENT_PROFILES[role].get("disallowedTools", [])), role)
            json.dumps(spec)  # serialisable

    def test_compact_window_scales_with_ticket_size(self):
        role = next(iter(AGENT_PROFILES))
        win = lambda t: delegate.build_agent_definition(role, t, root=self.root)[role]["autoCompactWindow"]
        self.assertLess(win({"estimated_complexity": "XL"}), win({"estimated_complexity": "S"}))
        self.assertLess(win({"type": "epic"}), win({"estimated_complexity": "M"}))
        self.assertEqual(win({"estimated_complexity": "M"}), delegate._AUTO_COMPACT_WINDOW_DEFAULT)

    def test_version_gate(self):
        for version, expected in (("2.1.295 (Claude Code)", False), ("2.1.296 (Claude Code)", True), ("", False)):
            delegate._claude_agents_flag_supported = None
            with patch.object(delegate, "_get_claude_version", return_value=version):
                self.assertEqual(delegate._check_claude_agents_flag_support(), expected, version)
                args = delegate.agents_flag_args(self.root, "backend-morty")
                self.assertEqual(bool(args), expected)
                if expected:
                    self.assertEqual(args[0], "--agents")
                    self.assertIn("backend-morty", json.loads(args[1]))
                    self.assertEqual(args[2:], ["--agent", "backend-morty"])


if __name__ == "__main__":
    unittest.main()
