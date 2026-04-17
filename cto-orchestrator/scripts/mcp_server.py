#!/usr/bin/env python3
"""CTO Orchestrator — MCP Server for ticket/team state management.

Exposes CTO state as an MCP server so Morty agents can dynamically
read/write tickets, send team messages, check file reservations,
and query ADRs during execution.

Usage: claude -p --mcp-config '{"mcpServers":{"cto-orchestrator":{"command":"python3","args":["scripts/mcp_server.py"]}}}' '<prompt>'
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: mcp package not installed. Run: pip install mcp", file=sys.stderr)
    sys.exit(1)


mcp = FastMCP("cto-orchestrator")


def _find_cto_root() -> Path:
    """Find the project root containing .cto/ directory."""
    current = Path(os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            raise RuntimeError("No .cto/ directory found in any parent directory")
        current = parent


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_json(fp: Path) -> dict:
    with open(fp) as f:
        return json.load(f)


def _save_json(fp: Path, data: dict):
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


@mcp.tool()
def get_ticket(ticket_id: str) -> str:
    """Read ticket state and dependencies.

    Args:
        ticket_id: The ticket ID (e.g. ZEAS-001)

    Returns:
        JSON string with ticket data including status, description,
        acceptance criteria, and resolved dependency summaries.
    """
    root = _find_cto_root()

    # Basic validation
    if not ticket_id or len(ticket_id) > 20:
        return json.dumps({"error": f"Invalid ticket ID: {ticket_id}"})

    fp = root / ".cto" / "tickets" / f"{ticket_id}.json"
    if not fp.exists():
        return json.dumps({"error": f"Ticket {ticket_id} not found"})

    ticket = _load_json(fp)

    # Resolve dependency summaries
    deps = []
    for dep_id in (ticket.get("dependencies") or []):
        dep_fp = root / ".cto" / "tickets" / f"{dep_id}.json"
        if dep_fp.exists():
            dep = _load_json(dep_fp)
            deps.append({
                "id": dep_id,
                "title": dep.get("title"),
                "status": dep.get("status"),
                "agent_output": (dep.get("agent_output") or "")[:300],
            })

    result = dict(ticket)
    result["resolved_dependencies"] = deps
    return json.dumps(result, indent=2)


@mcp.tool()
def update_ticket_status(ticket_id: str, status: str, output: str = "") -> str:
    """Write a partial progress update to a ticket.

    Use this to report interim progress without marking the ticket as fully done.

    Args:
        ticket_id: The ticket ID (e.g. ZEAS-001)
        status: New status — one of: in_progress, needs_review, blocked, completed
        output: Optional progress description or partial output

    Returns:
        JSON string confirming the update or describing any error.
    """
    root = _find_cto_root()

    valid_statuses = {"in_progress", "needs_review", "blocked", "completed"}
    if status not in valid_statuses:
        return json.dumps({"error": f"Invalid status '{status}'. Must be one of: {sorted(valid_statuses)}"})

    if not ticket_id or len(ticket_id) > 20:
        return json.dumps({"error": f"Invalid ticket ID: {ticket_id}"})

    fp = root / ".cto" / "tickets" / f"{ticket_id}.json"
    if not fp.exists():
        return json.dumps({"error": f"Ticket {ticket_id} not found"})

    ticket = _load_json(fp)
    ticket["status"] = status
    ticket["updated_at"] = _now_iso()
    if output:
        ticket["agent_output"] = output[:5000]

    _save_json(fp, ticket)
    return json.dumps({"ok": True, "ticket_id": ticket_id, "status": status})


@mcp.tool()
def send_team_message(team_id: str, to: str, message: str, msg_type: str = "info") -> str:
    """Send a real-time message to another agent in the same team.

    Args:
        team_id: The team session ID
        to: Recipient role (e.g. backend-morty) or @* for broadcast
        message: The message content
        msg_type: Message type — one of: info, question, decision, blocked

    Returns:
        JSON string with the saved message ID or an error.
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return json.dumps({"error": f"Invalid team ID: {team_id}"})
    if not message or len(message) > 2000:
        return json.dumps({"error": "Message must be 1–2000 characters"})

    valid_types = {"info", "question", "decision", "blocked"}
    if msg_type not in valid_types:
        msg_type = "info"

    msg_dir = root / ".cto" / "teams" / "messages" / team_id
    msg_dir.mkdir(parents=True, exist_ok=True)

    existing = list(msg_dir.glob("msg-*.json"))
    msg_num = len(existing) + 1
    msg_id = f"msg-{msg_num:03d}"

    # Determine sender from environment (set by delegate.py when launching agent)
    sender = os.environ.get("CTO_AGENT_ROLE", "unknown")

    msg_data = {
        "id": msg_id,
        "team_id": team_id,
        "from": sender,
        "to": to,
        "message": message[:2000],
        "type": msg_type,
        "timestamp": _now_iso(),
        "read_by": [],
    }
    _save_json(msg_dir / f"{msg_id}.json", msg_data)
    return json.dumps({"ok": True, "message_id": msg_id, "to": to})


@mcp.tool()
def get_team_context(team_id: str) -> str:
    """Read shared team decisions and interfaces for a team session.

    Args:
        team_id: The team session ID

    Returns:
        JSON string with team members, shared decisions, interfaces, and notes.
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return json.dumps({"error": f"Invalid team ID: {team_id}"})

    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return json.dumps({"error": f"Team session {team_id} not found"})

    team = _load_json(team_fp)

    ctx_fp = root / ".cto" / "teams" / "context" / f"{team_id}-shared.json"
    ctx = _load_json(ctx_fp) if ctx_fp.exists() else {}

    # Recent messages for current agent
    agent_role = os.environ.get("CTO_AGENT_ROLE", "")
    msg_dir = root / ".cto" / "teams" / "messages" / team_id
    messages = []
    if msg_dir.exists():
        for fp in sorted(msg_dir.glob("msg-*.json"))[-10:]:
            msg = _load_json(fp)
            if msg["to"] == "@*" or msg["to"] == agent_role or msg["from"] == agent_role:
                messages.append(msg)

    return json.dumps({
        "team_id": team_id,
        "parent_ticket": team.get("parent_ticket"),
        "status": team.get("status"),
        "members": team.get("members", []),
        "coordination": team.get("coordination", {}),
        "decisions": (ctx.get("decisions") or [])[-10:],
        "interfaces": (ctx.get("interfaces") or [])[-5:],
        "recent_messages": messages,
    }, indent=2)


@mcp.tool()
def list_files_reserved(team_id: str) -> str:
    """List file reservations for a team session to check ownership.

    Use this before modifying files to avoid conflicts with teammates.

    Args:
        team_id: The team session ID

    Returns:
        JSON string mapping agent roles to their reserved file lists.
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return json.dumps({"error": f"Invalid team ID: {team_id}"})

    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return json.dumps({"error": f"Team session {team_id} not found"})

    team = _load_json(team_fp)
    reserved = team.get("files_reserved", {})
    agent_role = os.environ.get("CTO_AGENT_ROLE", "")

    return json.dumps({
        "team_id": team_id,
        "your_role": agent_role,
        "your_files": reserved.get(agent_role, []),
        "all_reservations": reserved,
    }, indent=2)


@mcp.tool()
def reserve_files(team_id: str, files: list[str]) -> str:
    """Reserve files for the calling agent to prevent conflicts with teammates.

    Call this before modifying files so other agents know not to touch them.

    Args:
        team_id: The team session ID
        files: List of file paths to reserve (relative to project root)

    Returns:
        JSON string confirming the reservation or describing any conflicts.
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return json.dumps({"error": f"Invalid team ID: {team_id}"})
    if not files or len(files) > 50:
        return json.dumps({"error": "files must be a non-empty list of at most 50 paths"})

    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return json.dumps({"error": f"Team session {team_id} not found"})

    agent_role = os.environ.get("CTO_AGENT_ROLE", "unknown")
    team = _load_json(team_fp)

    reserved = team.get("files_reserved", {})

    # Detect conflicts with other roles
    conflicts = []
    for path in files:
        for role, role_files in reserved.items():
            if role != agent_role and path in role_files:
                conflicts.append({"file": path, "reserved_by": role})

    # Add (or update) this agent's reservations
    existing = set(reserved.get(agent_role, []))
    existing.update(files)
    reserved[agent_role] = sorted(existing)
    team["files_reserved"] = reserved

    _save_json(team_fp, team)

    return json.dumps({
        "ok": True,
        "reserved_for": agent_role,
        "files": sorted(existing),
        "conflicts": conflicts,
    }, indent=2)


@mcp.tool()
def read_adr(name: str) -> str:
    """Read an Architecture Decision Record by name.

    Args:
        name: ADR filename without extension (e.g. 'api-versioning')
              or pass '*' to list all available ADRs.

    Returns:
        The ADR content as a string, or a list of available ADR names.
    """
    root = _find_cto_root()
    dd = root / ".cto" / "decisions"

    if not dd.exists():
        return "No ADR directory found. No architecture decisions recorded yet."

    if name == "*":
        adrs = [fp.stem for fp in sorted(dd.glob("*.md"))]
        if not adrs:
            return "No ADRs found."
        return "Available ADRs:\n" + "\n".join(f"- {a}" for a in adrs)

    # Prevent path traversal
    safe_name = Path(name).name
    fp = dd / f"{safe_name}.md"
    if not fp.exists():
        # Try without extension in case caller passed full name
        fp = dd / safe_name
    if not fp.exists():
        available = [p.stem for p in sorted(dd.glob("*.md"))]
        return f"ADR '{name}' not found. Available: {available}"

    return fp.read_text()


if __name__ == "__main__":
    mcp.run()
