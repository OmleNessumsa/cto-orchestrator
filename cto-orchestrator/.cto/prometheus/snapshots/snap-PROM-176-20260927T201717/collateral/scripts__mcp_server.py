#!/usr/bin/env python3
"""CTO Orchestrator — MCP Server for ticket/team state management.

Exposes CTO state as an MCP server so Morty agents can dynamically
read/write tickets, send team messages, check file reservations,
and query ADRs during execution.

Usage: claude -p --mcp-config '{"mcpServers":{"cto-orchestrator":{"command":"python3","args":["scripts/mcp_server.py"]}}}' '<prompt>'
"""

import functools
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

try:
    from mcp.server.fastmcp import FastMCP
    from mcp.types import ToolAnnotations
except ImportError:
    print("Error: mcp package not installed. Run: pip install mcp", file=sys.stderr)
    sys.exit(1)

try:
    from security_utils import (
        sanitize_ticket_id,
        sanitize_path_component,
        audit_log_security_event,
        verify_module_integrity,
        verify_agent_token,
        ROLE_TOOL_ALLOWLISTS,
        SAFE_ID_PATTERN,
    )
    _AGENT_ROLES: set = set(ROLE_TOOL_ALLOWLISTS.keys())
    _SECURITY_AVAILABLE = True
except ImportError:
    print("[SECURITY-WARNING] security_utils not found — MCP input validation degraded", file=sys.stderr)
    _SECURITY_AVAILABLE = False
    _AGENT_ROLES: set = set()
    def sanitize_ticket_id(tid): return tid  # type: ignore[misc]
    def sanitize_path_component(c): return c  # type: ignore[misc]
    def audit_log_security_event(*a, **kw): pass  # type: ignore[misc]
    def verify_module_integrity(**kwargs):  # type: ignore[misc]
        return {"status": "degraded", "mismatches": [], "missing": [], "hashes": {}}
    def verify_agent_token(role, ticket_id, token): return True  # type: ignore[misc]


def _plugin_version() -> str:
    """Read semver from .claude-plugin/plugin.json, falling back to 'unknown'."""
    plugin_json = Path(__file__).parent.parent / ".claude-plugin" / "plugin.json"
    try:
        return json.loads(plugin_json.read_text())["version"]
    except Exception:
        return "unknown"


PLUGIN_VERSION = _plugin_version()

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


def _require_agent_token(fn):
    """Reject state-mutating tool calls whose CTO_AGENT_TOKEN doesn't verify.

    CTO_AGENT_ROLE alone is just an env var — any subprocess spawned by a
    delegated agent (e.g. via Bash) could override it to spoof a different
    role. Tools wrapped with this decorator instead check CTO_AGENT_TOKEN,
    an HMAC minted by delegate.py at spawn time and bound to the role +
    ticket that were assigned, so a role override no longer verifies.
    """
    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        role = os.environ.get("CTO_AGENT_ROLE", "")
        ticket_id = os.environ.get("CTO_TICKET_ID", "")
        token = os.environ.get("CTO_AGENT_TOKEN", "")
        if not verify_agent_token(role, ticket_id, token):
            audit_log_security_event(
                "mcp_authz_fail",
                f"Rejected {fn.__name__}() — CTO_AGENT_TOKEN invalid for role={role!r}, ticket_id={ticket_id!r}",
                severity="critical",
            )
            return json.dumps({"error": "unauthorized: missing or invalid agent capability token"})
        return fn(*args, **kwargs)
    return wrapper


@mcp.tool(annotations=ToolAnnotations(title="Get Ticket", readOnlyHint=True))
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


@mcp.tool(annotations=ToolAnnotations(title="Update Ticket Status", idempotentHint=True))
@_require_agent_token
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


@mcp.tool(annotations=ToolAnnotations(title="Send Team Message"))
@_require_agent_token
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


@mcp.tool(annotations=ToolAnnotations(title="Get Team Context"))
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


@mcp.tool(annotations=ToolAnnotations(title="List Files Reserved"))
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


@mcp.tool(annotations=ToolAnnotations(title="Reserve Files", idempotentHint=True))
@_require_agent_token
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


@mcp.tool(annotations=ToolAnnotations(title="Read ADR"))
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


# ---------------------------------------------------------------------------
# IDE-driven orchestrator tools (Rick IDE surface).
#
# The tools above were designed for Morty agents mid-execution: read a ticket,
# update status, post team messages. The tools below give an IDE session or
# top-level Claude conversation the full orchestrator keyboard: list tickets,
# create/close, inspect Sleepy/Prometheus/Unity state, fire delegate/meeseeks,
# explain code.
#
# Read-only tools return JSON synchronously. Mutating tools write to .cto/
# directly when safe (create/close ticket). Long-running actions (delegate,
# meeseeks, prometheus.scan, unity.scan, explain) are spawned detached and
# return a PID + log path the caller can poll.
# ---------------------------------------------------------------------------


def _scripts_dir() -> Path:
    return Path(__file__).parent


def _run_script(script: str, args: list[str], timeout: int = 20) -> dict:
    """Run an orchestrator script synchronously and return stdout/stderr/rc."""
    root = _find_cto_root()
    fp = _scripts_dir() / script
    try:
        result = subprocess.run(
            ["python3", str(fp), *args],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "ok": result.returncode == 0,
            "returncode": result.returncode,
            "stdout": (result.stdout or "")[:8000],
            "stderr": (result.stderr or "")[:2000],
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"timeout after {timeout}s"}
    except FileNotFoundError:
        return {"ok": False, "error": f"script not found: {fp}"}


def _spawn_detached(script: str, args: list[str], log_name: str) -> dict:
    """Spawn an orchestrator script as a detached process and return pid+log."""
    root = _find_cto_root()
    fp = _scripts_dir() / script
    if not fp.exists():
        return {"ok": False, "error": f"script not found: {fp}"}
    logs_dir = root / ".cto" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = logs_dir / log_name
    log = open(log_path, "w")
    proc = subprocess.Popen(
        ["python3", str(fp), *args],
        cwd=str(root),
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return {
        "ok": True,
        "pid": proc.pid,
        "log": str(log_path.relative_to(root)),
        "command": f"python3 {script} {' '.join(args)}",
    }


def _tickets_dir() -> Path:
    return _find_cto_root() / ".cto" / "tickets"


def _load_config() -> dict:
    cfg = _find_cto_root() / ".cto" / "config.json"
    return _load_json(cfg) if cfg.exists() else {}


# -------------------- Ticket management --------------------

@mcp.tool(annotations=ToolAnnotations(title="List Tickets", readOnlyHint=True))
def list_tickets(
    status: str = "",
    agent: str = "",
    limit: int = 50,
    offset: int = 0,
    response_format: Literal["concise", "detailed"] = "concise",
) -> str:
    """List tickets in the current project, optionally filtered.

    Args:
        status: Filter by status (todo, in_progress, needs_review, blocked, completed). Empty = all.
        agent: Filter by assigned agent (e.g. backend-morty). Empty = all.
        limit: Max tickets to return per page (default 50).
        offset: Number of matching tickets to skip for pagination (default 0).
        response_format: 'concise' returns id/title/status/assignee only (default);
                         'detailed' returns all fields including priority, type, complexity, dependencies.

    Returns:
        JSON object with count, total, offset, and tickets array.
    """
    td = _tickets_dir()
    if not td.exists():
        return json.dumps({"tickets": [], "total": 0, "count": 0, "offset": offset,
                           "note": "No tickets directory yet. Run init_project.sh."})
    all_rows = []
    for fp in sorted(td.glob("*.json")):
        try:
            t = _load_json(fp)
        except Exception:
            continue
        if status and t.get("status") != status:
            continue
        if agent and t.get("agent") != agent:
            continue
        all_rows.append(t)

    total = len(all_rows)
    page = all_rows[offset:offset + limit]

    detailed = response_format == "detailed"
    rows = []
    for t in page:
        if detailed:
            rows.append({
                "id": t.get("id"),
                "title": t.get("title"),
                "status": t.get("status"),
                "assignee": t.get("agent"),
                "priority": t.get("priority"),
                "type": t.get("type"),
                "complexity": t.get("complexity"),
                "dependencies": t.get("dependencies") or [],
            })
        else:
            rows.append({
                "id": t.get("id"),
                "title": t.get("title"),
                "status": t.get("status"),
                "assignee": t.get("agent"),
            })
    return json.dumps({"count": len(rows), "total": total, "offset": offset, "tickets": rows}, indent=2)


@mcp.tool(annotations=ToolAnnotations(title="Board", readOnlyHint=True))
def board(response_format: Literal["concise", "detailed"] = "concise") -> str:
    """Kanban board view — tickets grouped by status.

    Args:
        response_format: 'concise' returns totals + ticket IDs per column only (default);
                         'detailed' returns totals + full card objects {id, title, agent, priority}.

    Returns:
        JSON with totals and either ids (concise) or columns with card objects (detailed).
    """
    td = _tickets_dir()
    col_names = ("todo", "in_progress", "needs_review", "blocked", "completed")
    columns: dict = {c: [] for c in col_names}
    ids: dict = {c: [] for c in col_names}
    if td.exists():
        for fp in sorted(td.glob("*.json")):
            try:
                t = _load_json(fp)
            except Exception:
                continue
            col = t.get("status", "todo")
            if col in columns:
                ids[col].append(t.get("id"))
                columns[col].append({
                    "id": t.get("id"),
                    "title": t.get("title"),
                    "agent": t.get("agent"),
                    "priority": t.get("priority"),
                })
    totals = {k: len(v) for k, v in columns.items()}
    if response_format == "detailed":
        return json.dumps({"totals": totals, "columns": columns}, indent=2)
    return json.dumps({"totals": totals, "ids": ids}, indent=2)


@mcp.tool(annotations=ToolAnnotations(title="Create Ticket"))
def create_ticket(
    title: str,
    description: str = "",
    ticket_type: str = "feature",
    priority: str = "medium",
    agent: str = "",
    dependencies: list[str] | None = None,
    complexity: str = "M",
) -> str:
    """Create a new ticket in the current project.

    Args:
        title: Ticket title (required, <=200 chars).
        description: Longer description / acceptance criteria.
        ticket_type: feature | bug | chore | spike | test | docs.
        priority: low | medium | high | critical.
        agent: Assigned Morty role (empty = unassigned).
        dependencies: List of ticket IDs this depends on.
        complexity: XS | S | M | L | XL.

    Returns:
        JSON with the created ticket's id + path.
    """
    if not title or len(title) > 200:
        return json.dumps({"error": "title must be 1-200 chars"})
    if priority not in {"low", "medium", "high", "critical"}:
        return json.dumps({"error": "priority must be low|medium|high|critical"})
    if complexity not in {"XS", "S", "M", "L", "XL"}:
        return json.dumps({"error": "complexity must be XS|S|M|L|XL"})

    cfg = _load_config()
    prefix = cfg.get("ticket_prefix", "TKT")
    next_num = int(cfg.get("next_ticket_number", 1))

    ticket_id = f"{prefix}-{next_num:03d}"
    ticket = {
        "id": ticket_id,
        "title": title[:200],
        "description": description[:5000],
        "type": ticket_type,
        "priority": priority,
        "complexity": complexity,
        "status": "todo",
        "agent": agent or None,
        "dependencies": dependencies or [],
        "created_at": _now_iso(),
        "updated_at": _now_iso(),
    }

    td = _tickets_dir()
    td.mkdir(parents=True, exist_ok=True)
    fp = td / f"{ticket_id}.json"
    _save_json(fp, ticket)

    cfg["next_ticket_number"] = next_num + 1
    _save_json(_find_cto_root() / ".cto" / "config.json", cfg)

    return json.dumps({"ok": True, "ticket_id": ticket_id, "path": str(fp.relative_to(_find_cto_root()))})


@mcp.tool(annotations=ToolAnnotations(title="Close Ticket", destructiveHint=True))
@_require_agent_token
def close_ticket(ticket_id: str, output: str = "") -> str:
    """Close a ticket (mark completed) with a final output summary.

    Args:
        ticket_id: Ticket to close.
        output: Summary of what was done.

    Returns:
        JSON confirming closure.
    """
    if not ticket_id or len(ticket_id) > 20:
        return json.dumps({"error": f"invalid ticket id: {ticket_id}"})
    fp = _tickets_dir() / f"{ticket_id}.json"
    if not fp.exists():
        return json.dumps({"error": f"ticket {ticket_id} not found"})
    t = _load_json(fp)
    t["status"] = "completed"
    t["updated_at"] = _now_iso()
    t["closed_at"] = _now_iso()
    if output:
        t["agent_output"] = output[:5000]
    _save_json(fp, t)
    return json.dumps({"ok": True, "ticket_id": ticket_id, "status": "completed"})


@mcp.tool(annotations=ToolAnnotations(title="Project Status", readOnlyHint=True))
def project_status(response_format: Literal["concise", "detailed"] = "concise") -> str:
    """Overall project dashboard — config, ticket counts by status, sprint.

    Args:
        response_format: 'concise' returns project_name, ticket_prefix, and ticket_counts only (default);
                         'detailed' adds current_sprint, default_model, next_ticket_number, last_activity.

    Returns:
        JSON snapshot of project state at the requested detail level.
    """
    cfg = _load_config()
    td = _tickets_dir()
    counts = {"todo": 0, "in_progress": 0, "needs_review": 0, "blocked": 0, "completed": 0}
    last_updated = None
    if td.exists():
        for fp in td.glob("*.json"):
            try:
                t = _load_json(fp)
            except Exception:
                continue
            s = t.get("status", "todo")
            if s in counts:
                counts[s] += 1
            upd = t.get("updated_at")
            if upd and (last_updated is None or upd > last_updated):
                last_updated = upd
    if response_format == "detailed":
        return json.dumps({
            "project_name": cfg.get("project_name"),
            "ticket_prefix": cfg.get("ticket_prefix"),
            "current_sprint": cfg.get("current_sprint"),
            "default_model": cfg.get("default_model"),
            "next_ticket_number": cfg.get("next_ticket_number"),
            "ticket_counts": counts,
            "last_activity": last_updated,
        }, indent=2)
    return json.dumps({
        "project_name": cfg.get("project_name"),
        "ticket_prefix": cfg.get("ticket_prefix"),
        "ticket_counts": counts,
    }, indent=2)


@mcp.tool(annotations=ToolAnnotations(title="List Active Teams"))
def list_active_teams() -> str:
    """List active team sessions (parallel Morty collaborations).

    Returns:
        JSON array of active team sessions with parent ticket + members.
    """
    root = _find_cto_root()
    td = root / ".cto" / "teams" / "active"
    out = []
    if td.exists():
        for fp in sorted(td.glob("*.json")):
            try:
                t = _load_json(fp)
            except Exception:
                continue
            out.append({
                "team_id": t.get("team_id") or fp.stem,
                "parent_ticket": t.get("parent_ticket"),
                "status": t.get("status"),
                "members": [m.get("role") if isinstance(m, dict) else m for m in t.get("members", [])],
                "coordination_mode": (t.get("coordination") or {}).get("mode"),
            })
    return json.dumps({"count": len(out), "teams": out}, indent=2)


# -------------------- Sleepy Mode --------------------

@mcp.tool(annotations=ToolAnnotations(title="Sleepy Status", readOnlyHint=True))
def sleepy_status() -> str:
    """Sleepy Mode dashboard — budget, iteration count, queue depth, state.

    Returns:
        JSON with sleepy state (running/idle), budget usage, iterations,
        current ticket, review queue depth.
    """
    root = _find_cto_root()
    sdir = root / ".cto" / "sleepy"
    if not sdir.exists():
        return json.dumps({"initialized": False, "hint": "Run sleepy.py init to scaffold .cto/sleepy/"})

    state_fp = sdir / "state.json"
    state = _load_json(state_fp) if state_fp.exists() else {}

    queue_fp = sdir / "QUEUE.md"
    queue_depth = 0
    if queue_fp.exists():
        for ln in queue_fp.read_text().splitlines():
            if ln.strip().startswith("- [ ]") or ln.strip().startswith("- sleepy/"):
                queue_depth += 1

    return json.dumps({
        "initialized": True,
        "state": state,
        "queue_depth": queue_depth,
    }, indent=2)


@mcp.tool(annotations=ToolAnnotations(title="Sleepy Queue"))
def sleepy_queue() -> str:
    """Pending sleepy review branches awaiting apply/discard.

    Returns:
        Markdown contents of .cto/sleepy/QUEUE.md (or empty note).
    """
    root = _find_cto_root()
    q = root / ".cto" / "sleepy" / "QUEUE.md"
    if not q.exists():
        return json.dumps({"queue": "", "note": "no sleepy queue yet"})
    return json.dumps({"queue": q.read_text()[:8000]})


# -------------------- Prometheus self-evolution --------------------

@mcp.tool(annotations=ToolAnnotations(title="Prometheus Status", readOnlyHint=True))
def prometheus_status() -> str:
    """Prometheus dashboard — pending/applied/rejected proposals + ledger tail.

    Returns:
        JSON with counts per status and the most recent 10 ledger entries.
    """
    root = _find_cto_root()
    pdir = root / ".cto" / "prometheus"
    if not pdir.exists():
        # Fall back to the orchestrator's own prometheus dir if project has none.
        pdir = _scripts_dir().parent / ".cto" / "prometheus"
    if not pdir.exists():
        return json.dumps({"initialized": False})

    counts = {"pending": 0, "applied": 0, "rejected": 0, "rolled_back": 0}
    proposals_dir = pdir / "proposals"
    if proposals_dir.exists():
        for fp in proposals_dir.glob("*.json"):
            try:
                p = _load_json(fp)
            except Exception:
                continue
            s = p.get("status", "pending")
            if s in counts:
                counts[s] += 1

    ledger_fp = pdir / "ledger.json"
    tail = []
    if ledger_fp.exists():
        try:
            led = _load_json(ledger_fp)
            entries = led.get("entries") if isinstance(led, dict) else led
            if isinstance(entries, list):
                tail = entries[-10:]
        except Exception:
            pass

    return json.dumps({
        "initialized": True,
        "counts": counts,
        "ledger_tail": tail,
    }, indent=2)


# -------------------- Unity security --------------------

@mcp.tool(annotations=ToolAnnotations(title="Unity List"))
def unity_list() -> str:
    """List all Unity security scans (code + pentest + Greenlight compliance).

    Returns:
        stdout from `unity.py list`.
    """
    return json.dumps(_run_script("unity.py", ["list"], timeout=15))


# -------------------- Long-running spawns --------------------

@mcp.tool(annotations=ToolAnnotations(title="Delegate"))
def delegate(ticket_id: str, agent: str, model: str = "", detached: bool = True) -> str:
    """Spawn a Morty to work a ticket.

    Args:
        ticket_id: Ticket to work on.
        agent: Morty role (architect-morty, backend-morty, etc.).
        model: Override model (default comes from config).
        detached: If true, fire-and-return with PID + log path.

    Returns:
        JSON with PID + log (detached) or stdout (sync, may take minutes).
    """
    if not ticket_id or not agent:
        return json.dumps({"error": "ticket_id and agent required"})
    try:
        ticket_id = sanitize_ticket_id(ticket_id)
    except ValueError as exc:
        audit_log_security_event(
            "invalid_ticket_id",
            f"delegate() rejected ticket_id={ticket_id!r}: {exc}",
            severity="warning",
        )
        return json.dumps({"error": f"invalid ticket_id: {exc}"})
    if _AGENT_ROLES and agent not in _AGENT_ROLES:
        audit_log_security_event(
            "invalid_agent_role",
            f"delegate() rejected agent={agent!r}: not in allowlist {sorted(_AGENT_ROLES)}",
            severity="warning",
        )
        return json.dumps({"error": f"invalid agent: {agent!r} — must be one of {sorted(_AGENT_ROLES)}"})
    safe_ticket = sanitize_path_component(ticket_id)
    args = [ticket_id, "--agent", agent]
    if model:
        args.extend(["--model", model])
    if detached:
        return json.dumps(_spawn_detached("delegate.py", args, f"delegate-{safe_ticket}-{_now_iso().replace(':', '-')}.log"))
    return json.dumps(_run_script("delegate.py", args, timeout=600))


@mcp.tool(annotations=ToolAnnotations(title="Meeseeks"))
def meeseeks(task: str, files: list[str] | None = None, detached: bool = True) -> str:
    """Summon a Mr. Meeseeks for a quick one-shot task (no ticket needed).

    Args:
        task: What the Meeseeks should do.
        files: Optional list of files to target.
        detached: If true, fire-and-return with PID + log path.

    Returns:
        JSON with PID + log (detached) or stdout (sync).
    """
    if not task:
        return json.dumps({"error": "task required"})
    args = [task]
    if files:
        args.extend(["--files", *files])
    if detached:
        return json.dumps(_spawn_detached("meeseeks.py", args, f"meeseeks-{_now_iso().replace(':', '-')}.log"))
    return json.dumps(_run_script("meeseeks.py", args, timeout=600))


@mcp.tool(annotations=ToolAnnotations(title="Prometheus Scan", openWorldHint=True))
def prometheus_scan(categories: str = "") -> str:
    """Trigger a Prometheus scan for self-evolution proposals (detached).

    Args:
        categories: Comma-separated categories (agent-patterns, prompt-engineering,
                    ui-ux, security, tooling, claude-features). Empty = all.

    Returns:
        JSON with PID + log path.
    """
    args = ["scan"]
    if categories:
        args.extend(["--categories", categories])
    return json.dumps(_spawn_detached("prometheus.py", args, f"prometheus-scan-{_now_iso().replace(':', '-')}.log"))


@mcp.tool(annotations=ToolAnnotations(title="Unity Scan", openWorldHint=True))
def unity_scan(repo_path: str = ".", url: str = "") -> str:
    """Trigger a Unity security scan (code or live pentest, detached).

    Args:
        repo_path: Path to scan (default cwd). Ignored if url is set.
        url: Target URL for live pentest. Empty = static code scan.

    Returns:
        JSON with PID + log path.
    """
    if url:
        args = ["scan", "--url", url]
    else:
        args = ["scan", "--repo", repo_path]
    return json.dumps(_spawn_detached("unity.py", args, f"unity-scan-{_now_iso().replace(':', '-')}.log"))


@mcp.tool(annotations=ToolAnnotations(title="Explain Code"))
def explain_code(path: str, level: int = 3, lang: str = "nl") -> str:
    """Have Professor-Morty explain a file at a given Morty-level.

    Args:
        path: File to explain (relative to project root).
        level: 1 (total Morty) .. 5 (almost-Rick).
        lang: nl | en.

    Returns:
        stdout from `explain.py code`.
    """
    if not path:
        return json.dumps({"error": "path required"})
    if level < 1 or level > 5:
        return json.dumps({"error": "level must be 1-5"})
    if lang not in {"nl", "en"}:
        return json.dumps({"error": "lang must be nl or en"})
    return json.dumps(_run_script(
        "explain.py",
        ["code", path, "--level", str(level), "--lang", lang],
        timeout=180,
    ))


@mcp.tool(annotations=ToolAnnotations(title="Explain Concept"))
def explain_concept(topic: str, level: int = 3, lang: str = "nl") -> str:
    """Professor-Morty explains a concept (e.g. 'dependency injection').

    Args:
        topic: The concept to explain.
        level: 1..5 Morty-level.
        lang: nl | en.

    Returns:
        stdout from `explain.py concept`.
    """
    if not topic:
        return json.dumps({"error": "topic required"})
    if level < 1 or level > 5:
        return json.dumps({"error": "level must be 1-5"})
    return json.dumps(_run_script(
        "explain.py",
        ["concept", topic, "--level", str(level), "--lang", lang],
        timeout=180,
    ))


@mcp.tool(annotations=ToolAnnotations(title="Emit Handoff"))
def emit_handoff(
    messages: list[dict] | None = None,
    artifacts: list[dict] | None = None,
    status: str = "completed",
    blocked_on: list[str] | None = None,
    team_id: str = "",
) -> str:
    """Record a structured handoff from this agent to the team.

    Call this at the end of your work instead of printing a <handoff_json> block.
    Writes validated, typed data directly to the team shared-context — no regex parsing.

    Args:
        messages: List of {to, content, type} objects. to is a role like "@backend-morty"
                  or "@*". type is one of: decision, question, artifact, info.
        artifacts: List of {type, content} objects.
                   type is one of: api-schema, test-result, adr.
        status: Overall handoff status — completed | blocked.
        blocked_on: List of blocking reasons when status is blocked.
        team_id: Team session ID (auto-detected from CTO_TEAM_ID env var if omitted).

    Returns:
        JSON confirming the handoff was recorded, or an error description.
    """
    root = _find_cto_root()
    agent_role = os.environ.get("CTO_AGENT_ROLE", "unknown")

    resolved_team_id = team_id or os.environ.get("CTO_TEAM_ID", "")
    if not resolved_team_id:
        return json.dumps({"error": "team_id required — pass it explicitly or set CTO_TEAM_ID env var"})
    if len(resolved_team_id) > 20:
        return json.dumps({"error": f"invalid team_id: {resolved_team_id!r}"})

    valid_msg_types = {"decision", "question", "artifact", "info"}
    validated_messages = []
    for msg in (messages or []):
        if not isinstance(msg, dict):
            continue
        to = str(msg.get("to", "")).strip()
        content = str(msg.get("content", "")).strip()
        msg_type = str(msg.get("type", "info"))
        if msg_type not in valid_msg_types:
            msg_type = "info"
        if to and content:
            validated_messages.append({"to": to, "content": content[:2000], "type": msg_type})

    valid_artifact_types = {"api-schema", "test-result", "adr"}
    validated_artifacts = []
    for art in (artifacts or []):
        if not isinstance(art, dict):
            continue
        art_type = str(art.get("type", ""))
        art_content = art.get("content")
        if art_type in valid_artifact_types and art_content is not None:
            validated_artifacts.append({"type": art_type, "content": art_content})

    if status not in {"completed", "blocked"}:
        status = "completed"

    handoff_data = {
        "team_id": resolved_team_id,
        "agent_role": agent_role,
        "messages": validated_messages,
        "artifacts": validated_artifacts,
        "status": status,
        "blocked_on": [str(b) for b in (blocked_on or []) if b],
        "recorded_at": _now_iso(),
    }

    handoffs_dir = root / ".cto" / "teams" / "handoffs"
    handoffs_dir.mkdir(parents=True, exist_ok=True)
    handoff_fp = handoffs_dir / f"{resolved_team_id}-{agent_role}.json"
    _save_json(handoff_fp, handoff_data)

    return json.dumps({
        "ok": True,
        "recorded": {
            "messages": len(validated_messages),
            "artifacts": len(validated_artifacts),
            "status": status,
        },
    })


def _run_integrity_check():
    """Run module integrity check at MCP server startup; abort on tampering unless overridden."""
    result = verify_module_integrity()
    status = result.get("status")
    if status == "initialized":
        return
    if status == "degraded":
        details = (
            f"mismatches={result.get('mismatches', [])}, "
            f"missing={result.get('missing', [])}"
        )
        audit_log_security_event(
            "module_integrity_check_failed",
            details,
            severity="critical",
        )
        print(
            f"[SECURITY-CRITICAL] cto-orchestrator MCP: module integrity DEGRADED — {details}",
            file=sys.stderr,
        )
        if os.environ.get("CTO_INTEGRITY_OVERRIDE", "").lower() != "true":
            print(
                "[SECURITY-CRITICAL] Aborting MCP server startup. "
                "Set CTO_INTEGRITY_OVERRIDE=true to bypass (after running: "
                "python3 security_utils.py security-check --update-manifest).",
                file=sys.stderr,
            )
            sys.exit(1)
        print(
            "[SECURITY-WARNING] CTO_INTEGRITY_OVERRIDE=true — starting MCP server despite mismatch.",
            file=sys.stderr,
        )


@mcp.tool(annotations=ToolAnnotations(title="Plugin Info"))
def plugin_info() -> dict:
    """Return plugin name and semver version from .claude-plugin/plugin.json."""
    return {"name": "cto-orchestrator", "version": PLUGIN_VERSION}


if __name__ == "__main__":
    _run_integrity_check()
    mcp.run()
