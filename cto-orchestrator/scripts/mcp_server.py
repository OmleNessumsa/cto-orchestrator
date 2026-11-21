#!/usr/bin/env python3
"""CTO Orchestrator — MCP Server for ticket/team state management.

Exposes CTO state as an MCP server so Morty agents can dynamically
read/write tickets, send team messages, check file reservations,
and query ADRs during execution.

Usage: claude -p --mcp-config '{"mcpServers":{"cto-orchestrator":{"command":"python3","args":["scripts/mcp_server.py"]}}}' '<prompt>'
"""

import functools
import hashlib
import inspect
import json
import os
import signal
import subprocess
import sys
import uuid
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
        detect_injection_patterns,
        wrap_untrusted_content,
        SecurityViolationError,
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
    def detect_injection_patterns(text): return []  # type: ignore[misc]
    def wrap_untrusted_content(content, label="USER_INPUT"): return content  # type: ignore[misc]
    class SecurityViolationError(Exception):  # type: ignore[no-redef]
        patterns: list = []

from schemas import (
    BoardView,
    FileReservation,
    PendingApprovals,
    PrometheusStatus,
    ProjectStatus,
    SleepyQueue,
    SleepyStatus,
    TeamContext,
    TicketList,
    TicketView,
)


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


def _wrap_peer_text(text):
    """Wrap free text written by another agent so it is read as data, not instructions."""
    if not text or not isinstance(text, str):
        return text
    try:
        return wrap_untrusted_content(text, label="PEER_AGENT_CONTENT")
    except SecurityViolationError:
        audit_log_security_event(
            "peer_content_quarantined",
            "High-confidence injection pattern in peer-agent content; withheld from tool output",
            severity="critical",
        )
        return "[QUARANTINED: peer-agent content matched a prompt-injection pattern and was withheld]"


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
def get_ticket(ticket_id: str) -> TicketView:
    """Read ticket state and dependencies.

    Use when you need one ticket's full detail (description, acceptance
    criteria, agent output, dependency summaries). Not for browsing: use
    list_tickets or board to find IDs first.

    Args:
        ticket_id: The ticket ID (e.g. ZEAS-001)

    Returns:
        Structured ticket object with status, description, acceptance
        criteria, and resolved_dependencies. Free-text fields (description,
        agent_output) are wrapped as untrusted data. Unknown or invalid IDs
        return {"error": "..."}.
    """
    root = _find_cto_root()

    # Basic validation
    if not ticket_id or len(ticket_id) > 20:
        return {"error": f"Invalid ticket ID: {ticket_id}"}

    fp = root / ".cto" / "tickets" / f"{ticket_id}.json"
    if not fp.exists():
        return {"error": f"Ticket {ticket_id} not found"}

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
                "agent_output": _wrap_peer_text((dep.get("agent_output") or "")[:300]),
            })

    result = dict(ticket)
    for field in ("description", "agent_output"):
        if result.get(field):
            result[field] = _wrap_peer_text(result[field])
    result["resolved_dependencies"] = deps
    return result


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

    try:
        injection_hits = detect_injection_patterns(message)
    except SecurityViolationError as e:
        injection_hits = list(getattr(e, "patterns", None) or [str(e)])
    if injection_hits:
        sender = os.environ.get("CTO_AGENT_ROLE", "unknown")
        audit_log_security_event(
            "team_message_quarantined",
            f"team={team_id} from={sender} to={to}: {len(injection_hits)} injection pattern(s)",
            severity="critical",
        )
        # Subdirectory is outside the msg-*.json glob, so readers never see it
        qdir = msg_dir / "quarantine"
        qdir.mkdir(exist_ok=True)
        _save_json(qdir / f"q-{len(list(qdir.glob('q-*.json'))) + 1:03d}.json", {
            "team_id": team_id, "from": sender, "to": to,
            "message": message[:2000], "patterns": injection_hits,
            "timestamp": _now_iso(),
        })
        return json.dumps({"error": "Message rejected: matched prompt-injection patterns (quarantined)"})

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
def get_team_context(team_id: str) -> TeamContext:
    """Read shared team decisions and interfaces for a team session.

    Use at the start of teamwork and before relying on a teammate's
    interface. Not for sending messages: use send_team_message. Example
    argument: team_id="TEAM-001".

    Args:
        team_id: The team session ID

    Returns:
        Structured object with team members, shared decisions, interfaces,
        and recent_messages (message text wrapped as untrusted peer content).
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return {"error": f"Invalid team ID: {team_id}"}

    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return {"error": f"Team session {team_id} not found"}

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
                msg = dict(msg)
                msg["message"] = _wrap_peer_text(msg.get("message", ""))
                messages.append(msg)

    return {
        "team_id": team_id,
        "parent_ticket": team.get("parent_ticket"),
        "status": team.get("status"),
        "members": team.get("members", []),
        "coordination": team.get("coordination", {}),
        "decisions": (ctx.get("decisions") or [])[-10:],
        "interfaces": (ctx.get("interfaces") or [])[-5:],
        "recent_messages": messages,
    }


@mcp.tool(annotations=ToolAnnotations(title="List Files Reserved"))
def list_files_reserved(team_id: str) -> FileReservation:
    """List file reservations for a team session to check ownership.

    Use this before modifying files to avoid conflicts with teammates. To
    claim files, use reserve_files instead. Example argument: team_id="TEAM-001".

    Args:
        team_id: The team session ID

    Returns:
        Structured object with your_role, your_files, and all_reservations
        (agent role -> reserved file list).
    """
    root = _find_cto_root()

    if not team_id or len(team_id) > 20:
        return {"error": f"Invalid team ID: {team_id}"}

    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return {"error": f"Team session {team_id} not found"}

    team = _load_json(team_fp)
    reserved = team.get("files_reserved", {})
    agent_role = os.environ.get("CTO_AGENT_ROLE", "")

    return {
        "team_id": team_id,
        "your_role": agent_role,
        "your_files": reserved.get(agent_role, []),
        "all_reservations": reserved,
    }


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


# -------------------- MCP Tasks (io.modelcontextprotocol/tasks, 2026-07-28) --------------------
#
# When the client negotiated protocol 2026-07-28 with the tasks extension, the
# four long-running spawns return a task handle instead of a bare pid+log, and
# the caller drives it with tasks/get, tasks/update and tasks/cancel (the
# task_get / task_update / task_cancel functions below). Legacy clients — or
# MCP_PROTOCOL_NEGOTIATION=legacy — keep the plain detached JSON response.
# The pinned mcp SDK (1.x) cannot speak 2026-07-28 yet, so until the SDK is
# upgraded _tasks_negotiated() is False and the legacy path is always taken.

_TASKS_PROTOCOL = "2026-07-28"
_TASKS_EXTENSION = "io.modelcontextprotocol/tasks"
_TASK_TERMINAL = ("completed", "failed", "cancelled")
_TICKET_FAILED = ("blocked", "interrupted", "in_progress")


def _tasks_negotiated() -> bool:
    """True when the current client negotiated 2026-07-28 and the tasks extension."""
    if os.environ.get("MCP_PROTOCOL_NEGOTIATION", "").lower() == "legacy":
        return False
    try:
        params = mcp.get_context().request_context.session.client_params
        if str(params.protocolVersion) < _TASKS_PROTOCOL:
            return False
        caps = params.capabilities.model_dump()
        return _TASKS_EXTENSION in (caps.get("extensions") or {})
    except Exception:
        return False


def _tasks_dir() -> Path:
    return _find_cto_root() / ".cto" / "tasks"


def _task_path(task_id: str) -> Path:
    return _tasks_dir() / f"{sanitize_path_component(task_id)}.json"


def _emit_task_event(event: str, rec: dict):
    try:
        from roro_events import emit_task_event
        emit_task_event(event, rec["task_id"], rec["kind"], rec["status"], rec.get("ticket_id"))
    except Exception:
        pass


def _task_save(rec: dict, event: str = "updated"):
    rec["updated_at"] = _now_iso()
    _tasks_dir().mkdir(parents=True, exist_ok=True)
    _save_json(_task_path(rec["task_id"]), rec)
    _emit_task_event(event, rec)


def _pid_exit(pid: int) -> tuple[bool, int | None]:
    """Return (alive, exit_code); exit_code is only known for our own reaped children."""
    try:
        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            return False, os.waitstatus_to_exitcode(status)
        return True, None
    except ChildProcessError:
        pass
    try:
        os.kill(pid, 0)
        return True, None
    except ProcessLookupError:
        return False, None
    except PermissionError:
        return True, None


def _spawn_task(script: str, args: list[str], log_name: str, kind: str, ticket_id: str | None = None) -> dict:
    """Spawn detached; wrap in a task handle when the client negotiated Tasks."""
    spawned = _spawn_detached(script, args, log_name)
    if not spawned.get("ok") or not _tasks_negotiated():
        return spawned
    rec = {
        "task_id": uuid.uuid4().hex,
        "kind": kind,
        "status": "working",
        "pid": spawned["pid"],
        "log": spawned["log"],
        "ticket_id": ticket_id,
        "created_at": _now_iso(),
    }
    _task_save(rec, "created")
    return {"ok": True, "task": {"taskId": rec["task_id"], "status": "working"}, **spawned}


def _task_load(task_id: str) -> dict | None:
    try:
        fp = _task_path(task_id)
    except ValueError:
        return None
    return _load_json(fp) if fp.exists() else None


def _task_result(rec: dict, ticket: dict | None) -> str:
    """Morty report for ticket-backed tasks, else the tail of the log."""
    if ticket:
        return ticket.get("agent_output") or ticket.get("review_notes") or ""
    try:
        return (_find_cto_root() / rec["log"]).read_text(errors="replace")[-4000:]
    except OSError:
        return ""


def task_get(task_id: str) -> dict:
    """tasks/get — refresh and return the task: status, plus result or elicitation."""
    rec = _task_load(task_id)
    if rec is None:
        return {"error": f"unknown task: {task_id}"}
    ticket = None
    if rec.get("ticket_id"):
        try:
            tfp = _tickets_dir() / f"{sanitize_ticket_id(rec['ticket_id'])}.json"
            ticket = _load_json(tfp) if tfp.exists() else None
        except ValueError:
            ticket = None
    prev = rec["status"]
    if prev not in _TASK_TERMINAL:
        alive, code = _pid_exit(rec["pid"])
        tstatus = (ticket or {}).get("status")
        if tstatus == "awaiting_approval":
            rec["status"] = "input_required"
        elif alive:
            rec["status"] = "working"
        elif rec.get("cancel_requested"):
            rec["status"] = "cancelled"
        elif rec.get("resolution"):
            rec["status"] = "completed" if rec["resolution"] == "approved" else "failed"
        elif (ticket and tstatus in _TICKET_FAILED) or code:
            rec["status"] = "failed"
        else:
            rec["status"] = "completed"
        if rec["status"] != prev:
            _task_save(rec)
    out = {"taskId": rec["task_id"], "status": rec["status"], "kind": rec["kind"], "ticket_id": rec.get("ticket_id")}
    if rec["status"] == "input_required" and ticket:
        gate = ticket.get("approval_gate") or {}
        out["elicitation"] = {
            "message": f"Approve {ticket['id']} at {gate.get('phase')}? {gate.get('reason') or ''}".strip(),
            "requestedSchema": {
                "type": "object",
                "properties": {"approve": {"type": "boolean"}, "note": {"type": "string"}},
                "required": ["approve"],
            },
        }
    elif rec["status"] in _TASK_TERMINAL:
        out["result"] = _task_result(rec, ticket)
    return out


def task_update(task_id: str, answer: dict) -> dict:
    """tasks/update — map an elicitation answer ({approve, note}) onto approve_ticket()."""
    rec = _task_load(task_id)
    if rec is None:
        return {"error": f"unknown task: {task_id}"}
    if rec["status"] != "input_required" or not rec.get("ticket_id"):
        return {"error": f"task {task_id} is not awaiting input"}
    approve = bool((answer or {}).get("approve"))
    res = json.loads(approve_ticket(rec["ticket_id"], approve, str((answer or {}).get("note", ""))))
    if "error" in res:
        return res
    rec["resolution"] = "approved" if approve else "rejected"
    rec["status"] = "working"
    _task_save(rec)
    return task_get(task_id)


def task_cancel(task_id: str) -> dict:
    """tasks/cancel — SIGTERM the recorded pid; delegate.py parks the ticket as interrupted for requeue."""
    rec = _task_load(task_id)
    if rec is None:
        return {"error": f"unknown task: {task_id}"}
    if rec["status"] in _TASK_TERMINAL:
        return {"taskId": rec["task_id"], "status": rec["status"]}
    rec["cancel_requested"] = True
    try:
        os.kill(rec["pid"], signal.SIGTERM)
    except ProcessLookupError:
        pass
    rec["status"] = "cancelled"
    _task_save(rec)
    return {"taskId": rec["task_id"], "status": "cancelled"}


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
) -> TicketList:
    """List tickets in the current project, optionally filtered.

    Args:
        status: Filter by status (todo, in_progress, needs_review, blocked, completed). Empty = all.
        agent: Filter by assigned agent (e.g. backend-morty). Empty = all.
        limit: Max tickets to return per page (default 50).
        offset: Number of matching tickets to skip for pagination (default 0).
        response_format: 'concise' returns id/title/status/assignee only (default);
                         'detailed' returns all fields including priority, type, complexity, dependencies.

    Returns:
        Structured object with count, total, offset, and a tickets array.

    Use to find ticket IDs or filter by status/agent; for one ticket's full
    detail call get_ticket, for a grouped overview call board. Example
    arguments: status="blocked", limit=20.
    """
    td = _tickets_dir()
    if not td.exists():
        return {"tickets": [], "total": 0, "count": 0, "offset": offset,
                "note": "No tickets directory yet. Run init_project.sh."}
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
    return {"count": len(rows), "total": total, "offset": offset, "tickets": rows}


@mcp.tool(annotations=ToolAnnotations(title="Board", readOnlyHint=True))
def board(response_format: Literal["concise", "detailed"] = "concise") -> BoardView:
    """Kanban board view — tickets grouped by status.

    Args:
        response_format: 'concise' returns totals + ticket IDs per column only (default);
                         'detailed' returns totals + full card objects {id, title, agent, priority}.

    Returns:
        Structured object with totals and either ids (concise) or columns
        with card objects (detailed).

    Use for a quick who-is-doing-what overview; not for ticket detail
    (get_ticket). Example argument: response_format="detailed".
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
        return {"totals": totals, "columns": columns}
    return {"totals": totals, "ids": ids}


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


@mcp.tool(annotations=ToolAnnotations(title="List Pending Approvals", readOnlyHint=True))
def list_pending_approvals() -> PendingApprovals:
    """List tickets parked at an approval gate, waiting for a human decision.

    Use before approve_ticket to see what is waiting. Takes no arguments.

    Returns:
        Structured object with count and a pending array of {ticket_id,
        title, phase, reason, requested_at, diff_summary}.
    """
    from ticket import pending_approvals
    items = []
    for t in pending_approvals(_find_cto_root()):
        gate = t.get("approval_gate") or {}
        items.append({
            "ticket_id": t["id"],
            "title": t.get("title"),
            "phase": gate.get("phase"),
            "reason": gate.get("reason"),
            "requested_at": gate.get("requested_at"),
            "diff_summary": gate.get("diff_summary"),
        })
    return {"count": len(items), "pending": items}


@mcp.tool(annotations=ToolAnnotations(title="Approve Ticket", destructiveHint=True))
def approve_ticket(ticket_id: str, approve: bool = True, note: str = "") -> str:
    """Approve or reject a ticket waiting at an approval gate (human only).

    Approving a pre_delegate gate requeues the ticket as todo; approving a
    pre_merge gate resumes it at review/merge. Rejecting blocks the ticket.
    Refused when called from inside a delegated agent session.

    Args:
        ticket_id: Ticket awaiting approval.
        approve: True to approve, False to reject.
        note: Optional comment stored on the approval gate.

    Returns:
        JSON with the ticket's new status, or an error.
    """
    if os.environ.get("CTO_AGENT_ROLE") or os.environ.get("CTO_AGENT_TOKEN"):
        audit_log_security_event(
            "mcp_authz_fail",
            f"Rejected approve_ticket({ticket_id}) — agents cannot approve gated tickets",
            severity="critical",
        )
        return json.dumps({"error": "unauthorized: delegated agents cannot approve tickets"})
    if not ticket_id or len(ticket_id) > 20:
        return json.dumps({"error": f"invalid ticket id: {ticket_id}"})
    from ticket import resolve_approval
    try:
        t = resolve_approval(_find_cto_root(), ticket_id, approve, note[:1000])
    except (ValueError, SystemExit) as e:
        return json.dumps({"error": str(e)})
    return json.dumps({"ok": True, "ticket_id": ticket_id, "status": t["status"]})


@mcp.tool(annotations=ToolAnnotations(title="Project Status", readOnlyHint=True))
def project_status(response_format: Literal["concise", "detailed"] = "concise") -> ProjectStatus:
    """Overall project dashboard — config, ticket counts by status, sprint.

    Args:
        response_format: 'concise' returns project_name, ticket_prefix, and ticket_counts only (default);
                         'detailed' adds current_sprint, default_model, next_ticket_number, last_activity.

    Use for a one-call health check; for per-ticket rows use list_tickets.
    Example argument: response_format="detailed".

    Returns:
        Structured snapshot of project state at the requested detail level.
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
        return {
            "project_name": cfg.get("project_name"),
            "ticket_prefix": cfg.get("ticket_prefix"),
            "current_sprint": cfg.get("current_sprint"),
            "default_model": cfg.get("default_model"),
            "next_ticket_number": cfg.get("next_ticket_number"),
            "ticket_counts": counts,
            "last_activity": last_updated,
        }
    return {
        "project_name": cfg.get("project_name"),
        "ticket_prefix": cfg.get("ticket_prefix"),
        "ticket_counts": counts,
    }


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
def sleepy_status() -> SleepyStatus:
    """Sleepy Mode dashboard — budget, iteration count, queue depth, state.

    Use to check whether an unattended run is active; for the branches
    awaiting review use sleepy_queue. Takes no arguments.

    Returns:
        Structured object with initialized, state (running/idle, budget
        usage, iterations, current ticket) and queue_depth.
    """
    root = _find_cto_root()
    sdir = root / ".cto" / "sleepy"
    if not sdir.exists():
        return {"initialized": False, "hint": "Run sleepy.py init to scaffold .cto/sleepy/"}

    state_fp = sdir / "state.json"
    state = _load_json(state_fp) if state_fp.exists() else {}

    queue_fp = sdir / "QUEUE.md"
    queue_depth = 0
    if queue_fp.exists():
        for ln in queue_fp.read_text().splitlines():
            if ln.strip().startswith("- [ ]") or ln.strip().startswith("- sleepy/"):
                queue_depth += 1

    return {
        "initialized": True,
        "state": state,
        "queue_depth": queue_depth,
    }


@mcp.tool(annotations=ToolAnnotations(title="Sleepy Queue"))
def sleepy_queue() -> SleepyQueue:
    """Pending sleepy review branches awaiting apply/discard.

    Use after sleepy_status shows queue_depth > 0. Takes no arguments.

    Returns:
        Structured object whose queue field holds the Markdown contents of
        .cto/sleepy/QUEUE.md (truncated to 8000 chars), or an empty queue with a note.
    """
    root = _find_cto_root()
    q = root / ".cto" / "sleepy" / "QUEUE.md"
    if not q.exists():
        return {"queue": "", "note": "no sleepy queue yet"}
    return {"queue": q.read_text()[:8000]}


# -------------------- Prometheus self-evolution --------------------

@mcp.tool(annotations=ToolAnnotations(title="Prometheus Status", readOnlyHint=True))
def prometheus_status() -> PrometheusStatus:
    """Prometheus dashboard — pending/applied/rejected proposals + ledger tail.

    Use to see self-evolution progress; starting a scan is prometheus_scan.
    Takes no arguments.

    Returns:
        Structured object with counts per status and the most recent 10
        ledger entries (ledger_tail).
    """
    root = _find_cto_root()
    pdir = root / ".cto" / "prometheus"
    if not pdir.exists():
        # Fall back to the orchestrator's own prometheus dir if project has none.
        pdir = _scripts_dir().parent / ".cto" / "prometheus"
    if not pdir.exists():
        return {"initialized": False}

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

    return {
        "initialized": True,
        "counts": counts,
        "ledger_tail": tail,
    }


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
        model: Model to use instead of the config default.
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
        return json.dumps(_spawn_task("delegate.py", args, f"delegate-{safe_ticket}-{_now_iso().replace(':', '-')}.log", "delegate", ticket_id))
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
        return json.dumps(_spawn_task("meeseeks.py", args, f"meeseeks-{_now_iso().replace(':', '-')}.log", "meeseeks"))
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
    return json.dumps(_spawn_task("prometheus.py", args, f"prometheus-scan-{_now_iso().replace(':', '-')}.log", "prometheus_scan"))


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
    return json.dumps(_spawn_task("unity.py", args, f"unity-scan-{_now_iso().replace(':', '-')}.log", "unity_scan"))


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


def _tool_definitions() -> dict:
    """Map each registered tool name to (sha256, docstring) over name + docstring + signature."""
    defs = {}
    for tool in mcp._tool_manager.list_tools():
        doc = inspect.getdoc(tool.fn) or ""
        sig = str(inspect.signature(tool.fn))
        digest = hashlib.sha256(
            json.dumps({"name": tool.name, "docstring": doc, "signature": sig}, sort_keys=True).encode()
        ).hexdigest()
        defs[tool.name] = (digest, doc)
    return defs


def _manifest_path() -> Path:
    return _find_cto_root() / ".cto" / "security" / "mcp_tool_manifest.json"


def _emit_drift_event(details: dict):
    try:
        from roro_events import emit
        emit("security.mcp_tool_drift", details, role="security")
    except Exception:
        pass


def _verify_tool_manifest(repin: bool = False):
    """Pin tool metadata hashes; abort on drift or poisoned docstrings unless overridden."""
    defs = _tool_definitions()
    current = {name: d for name, (d, _) in defs.items()}
    fp = _manifest_path()

    if repin or not fp.exists():
        fp.parent.mkdir(parents=True, exist_ok=True)
        _save_json(fp, {"generated_at": _now_iso(), "tools": current})
        print(f"[SECURITY] MCP tool manifest pinned: {fp} ({len(current)} tools)", file=sys.stderr)
        if repin:
            return

    problems = {}
    pinned = _load_json(fp).get("tools", {})
    drift = {
        "added": sorted(set(current) - set(pinned)),
        "removed": sorted(set(pinned) - set(current)),
        "changed": sorted(n for n in set(current) & set(pinned) if current[n] != pinned[n]),
    }
    if any(drift.values()):
        problems["drift"] = drift

    poisoned = {}
    for name, (_, doc) in defs.items():
        try:
            hits = detect_injection_patterns(doc)
        except SecurityViolationError as e:
            hits = list(getattr(e, "patterns", None) or [str(e)])
        if hits:
            poisoned[name] = hits
    if poisoned:
        problems["poisoned_docstrings"] = sorted(poisoned)

    if not problems:
        return
    details = json.dumps(problems)
    audit_log_security_event("mcp_tool_drift", details, severity="critical")
    _emit_drift_event(problems)
    print(f"[SECURITY-WARNING] cto-orchestrator MCP tool metadata check failed — {details}", file=sys.stderr)
    if os.environ.get("CTO_ACCEPT_MCP_DRIFT") != "1":
        print(
            "[SECURITY-CRITICAL] Aborting MCP server startup. Review the tool changes, then run "
            "`python3 scripts/mcp_server.py --repin` or set CTO_ACCEPT_MCP_DRIFT=1.",
            file=sys.stderr,
        )
        sys.exit(1)
    print("[SECURITY-WARNING] CTO_ACCEPT_MCP_DRIFT=1 — starting despite drift.", file=sys.stderr)


@mcp.tool(annotations=ToolAnnotations(title="Plugin Info"))
def plugin_info() -> dict:
    """Return plugin name and semver version from .claude-plugin/plugin.json."""
    return {"name": "cto-orchestrator", "version": PLUGIN_VERSION}


if __name__ == "__main__":
    _run_integrity_check()
    _verify_tool_manifest(repin="--repin" in sys.argv[1:])
    if "--repin" in sys.argv[1:]:
        sys.exit(0)
    mcp.run()
