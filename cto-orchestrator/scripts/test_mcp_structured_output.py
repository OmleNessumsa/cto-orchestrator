"""Read-only MCP tools return structuredContent that validates against their outputSchema."""
import asyncio
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import jsonschema  # noqa: E402
from mcp.shared.memory import create_connected_server_and_client_session  # noqa: E402
import mcp_server  # noqa: E402

TEAM = "TEAM-001"


def _write(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data))


def _seed(root: Path):
    cto = root / ".cto"
    _write(cto / "config.json", {"project_name": "demo", "ticket_prefix": "DEMO", "next_ticket_number": 3})
    _write(cto / "tickets" / "DEMO-001.json", {
        "id": "DEMO-001", "title": "First", "status": "todo", "priority": "high", "type": "task",
        "assigned_agent": "backend-morty", "description": "do the thing", "dependencies": ["DEMO-002"],
        "agent_output": "done", "files_touched": ["a.py"], "updated_at": "2026-01-01T00:00:00Z",
    })
    _write(cto / "tickets" / "DEMO-002.json", {
        "id": "DEMO-002", "title": "Second", "status": "completed", "priority": "low", "type": "task",
        "agent_output": "ok",
    })
    _write(cto / "teams" / "active" / f"{TEAM}.json", {
        "team_id": TEAM, "parent_ticket": "DEMO-001", "status": "active",
        "members": [{"role": "backend-morty"}], "coordination": {"mode": "parallel"},
        "files_reserved": {"backend-morty": ["a.py"]},
    })
    _write(cto / "teams" / "context" / f"{TEAM}-shared.json", {"decisions": ["use json"], "interfaces": []})
    _write(cto / "teams" / "messages" / TEAM / "msg-001.json", {
        "id": "msg-001", "team_id": TEAM, "from": "backend-morty", "to": "@*",
        "message": "hello team", "type": "info", "timestamp": "2026-01-01T00:00:00Z", "read_by": [],
    })
    (cto / "sleepy").mkdir(parents=True)
    (cto / "sleepy" / "QUEUE.md").write_text("- [ ] sleepy/DEMO-001\n")
    _write(cto / "sleepy" / "state.json", {"state": "idle"})
    _write(cto / "prometheus" / "proposals" / "PROM-1.json", {"status": "applied"})
    _write(cto / "prometheus" / "ledger.json", {"entries": [{"id": "PROM-1"}]})
    # A pending approval gate
    _write(cto / "tickets" / "DEMO-003.json", {
        "id": "DEMO-003", "title": "Gated", "status": "needs_approval", "priority": "high", "type": "task",
        "approval_gate": {"phase": "pre_delegate", "reason": "risky", "requested_at": "2026-01-01T00:00:00Z"},
    })


CALLS = [
    ("get_ticket", {"ticket_id": "DEMO-001"}),
    ("get_ticket", {"ticket_id": "NOPE-999"}),
    ("list_tickets", {}),
    ("list_tickets", {"response_format": "detailed"}),
    ("board", {}),
    ("board", {"response_format": "detailed"}),
    ("project_status", {}),
    ("project_status", {"response_format": "detailed"}),
    ("list_pending_approvals", {}),
    ("get_team_context", {"team_id": TEAM}),
    ("get_team_context", {"team_id": "TEAM-404"}),
    ("list_files_reserved", {"team_id": TEAM}),
    ("sleepy_status", {}),
    ("sleepy_queue", {}),
    ("prometheus_status", {}),
]


class StructuredOutputTest(unittest.TestCase):
    def test_structured_content_matches_output_schema(self):
        async def run(root: Path):
            results = []
            async with create_connected_server_and_client_session(mcp_server.mcp._mcp_server) as client:
                tools = {t.name: t for t in (await client.list_tools()).tools}
                for name, args in CALLS:
                    res = await client.call_tool(name, args)
                    results.append((name, args, tools[name], res))
            return results

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            _seed(root)
            old = os.getcwd()
            os.chdir(root)
            try:
                with mock.patch.dict(os.environ, {"CTO_AGENT_ROLE": "backend-morty"}):
                    results = asyncio.run(run(root))
            finally:
                os.chdir(old)

        for name, args, tool, res in results:
            with self.subTest(tool=name, args=args):
                self.assertFalse(res.isError, res.content)
                self.assertIsNotNone(tool.outputSchema, f"{name} advertises no outputSchema")
                self.assertIsNotNone(res.structuredContent, f"{name} returned no structuredContent")
                jsonschema.validate(res.structuredContent, tool.outputSchema)
                # text fallback keeps the original payload; structuredContent only adds
                # nulls for top-level keys the tool did not set
                text = json.loads(res.content[0].text)
                self.assertEqual(text, {k: res.structuredContent[k] for k in text})
                self.assertTrue(all(v is None for k, v in res.structuredContent.items() if k not in text))

        by_key = {(n, json.dumps(a, sort_keys=True)): r for n, a, _, r in results}
        ticket = by_key[("get_ticket", json.dumps({"ticket_id": "DEMO-001"}))].structuredContent
        self.assertEqual(ticket["resolved_dependencies"][0]["id"], "DEMO-002")
        # injection wrapping survives inside the structured object
        self.assertNotEqual(ticket["description"], "do the thing")
        self.assertIn("do the thing", ticket["description"])
        ctx = by_key[("get_team_context", json.dumps({"team_id": TEAM}))].structuredContent
        self.assertIn("hello team", ctx["recent_messages"][0]["message"])
        self.assertEqual(ctx["recent_messages"][0]["from"], "backend-morty")
        self.assertIn("error", by_key[("get_ticket", json.dumps({"ticket_id": "NOPE-999"}))].structuredContent)


if __name__ == "__main__":
    unittest.main()
