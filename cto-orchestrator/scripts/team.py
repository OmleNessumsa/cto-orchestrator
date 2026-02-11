#!/usr/bin/env python3
"""CTO Orchestrator — Team Collaboration Management.

*Burrrp* — This is how we coordinate the Morty army, Morty. Multiple Morty's
working together on complex tasks. Like a hive mind, but dumber.

Teams enable:
- Parallel execution of multiple Morty's
- Inter-agent communication via message queue
- Shared context for coordinated work
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Import roro event emitter
try:
    from roro_events import emit
except ImportError:
    # Fallback if module not found
    def emit(*args, **kwargs):
        pass


def find_cto_root(start: Optional[str] = None) -> Path:
    """Walk up from *start* (default: cwd) until we find a .cto/ directory."""
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            print("Error: No .cto/ directory found. Run init_project.sh first.", file=sys.stderr)
            sys.exit(1)
        current = parent


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(fp: Path) -> dict:
    with open(fp) as f:
        return json.load(f)


def save_json(fp: Path, data: dict):
    fp.parent.mkdir(parents=True, exist_ok=True)
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


def load_config(root: Path) -> dict:
    return load_json(root / ".cto" / "config.json")


def save_config(root: Path, cfg: dict):
    save_json(root / ".cto" / "config.json", cfg)


def teams_dir(root: Path) -> Path:
    return root / ".cto" / "teams"


def active_teams_dir(root: Path) -> Path:
    return teams_dir(root) / "active"


def messages_dir(root: Path) -> Path:
    return teams_dir(root) / "messages"


def context_dir(root: Path) -> Path:
    return teams_dir(root) / "context"


def ensure_team_dirs(root: Path):
    """Ensure all team directories exist."""
    active_teams_dir(root).mkdir(parents=True, exist_ok=True)
    messages_dir(root).mkdir(parents=True, exist_ok=True)
    context_dir(root).mkdir(parents=True, exist_ok=True)


# ── Team Templates ───────────────────────────────────────────────────────────

TEAM_TEMPLATES = {
    "fullstack-team": {
        "description": "Full-stack feature development team",
        "roles": [
            {"role": "architect-morty", "focus": "architecture and interfaces"},
            {"role": "backend-morty", "focus": "backend implementation"},
            {"role": "frontend-morty", "focus": "frontend implementation"},
        ],
        "coordination": {"mode": "mixed", "lead": "architect-morty"},
    },
    "api-team": {
        "description": "API development and testing team",
        "roles": [
            {"role": "architect-morty", "focus": "API design and interfaces"},
            {"role": "backend-morty", "focus": "API implementation"},
            {"role": "tester-morty", "focus": "API testing and validation"},
        ],
        "coordination": {"mode": "sequential", "lead": "architect-morty"},
    },
    "security-team": {
        "description": "Security audit and hardening team",
        "roles": [
            {"role": "architect-morty", "focus": "security architecture review"},
            {"role": "security-morty", "focus": "vulnerability assessment"},
            {"role": "unity", "focus": "penetration testing (Shannon)"},
            {"role": "tester-morty", "focus": "security test automation"},
        ],
        "coordination": {"mode": "parallel", "lead": "security-morty"},
    },
    "devops-team": {
        "description": "Infrastructure and deployment team",
        "roles": [
            {"role": "devops-morty", "focus": "infrastructure and CI/CD"},
            {"role": "backend-morty", "focus": "service configuration"},
        ],
        "coordination": {"mode": "parallel", "lead": "devops-morty"},
    },
}


def get_template(name: str) -> Optional[dict]:
    """Get a team template by name."""
    return TEAM_TEMPLATES.get(name)


def list_templates() -> list[str]:
    """List all available team templates."""
    return list(TEAM_TEMPLATES.keys())


# ── Team Session Management ──────────────────────────────────────────────────

def next_team_id(root: Path) -> str:
    """Generate next team session ID."""
    cfg = load_config(root)
    num = cfg.get("next_team_number", 1)
    tid = f"TEAM-{num:03d}"
    cfg["next_team_number"] = num + 1
    save_config(root, cfg)
    return tid


def create_team_session(
    root: Path,
    parent_ticket: str,
    template_name: str,
    custom_roles: Optional[list] = None,
) -> dict:
    """Create a new team session.

    Args:
        root: Project root path
        parent_ticket: Ticket ID this team is working on
        template_name: Name of the team template to use
        custom_roles: Optional custom role definitions (overrides template)

    Returns:
        Created team session dict
    """
    ensure_team_dirs(root)

    team_id = next_team_id(root)
    template = get_template(template_name)

    if template is None and custom_roles is None:
        print(f"Error: Unknown template '{template_name}' and no custom roles provided.", file=sys.stderr)
        sys.exit(1)

    roles = custom_roles if custom_roles else template["roles"]
    coordination = template["coordination"] if template else {"mode": "parallel", "lead": roles[0]["role"]}

    # Create member entries with pending status
    members = []
    for i, role_def in enumerate(roles):
        # Generate sub-assignment ID
        assignment_suffix = chr(65 + i)  # A, B, C, ...
        members.append({
            "role": role_def["role"],
            "focus": role_def.get("focus", ""),
            "assignment": f"{parent_ticket}-{assignment_suffix}",
            "status": "pending",
            "started_at": None,
            "completed_at": None,
            "output_summary": None,
        })

    team = {
        "id": team_id,
        "parent_ticket": parent_ticket,
        "template": template_name,
        "status": "pending",
        "members": members,
        "coordination": coordination,
        "created_at": now_iso(),
        "started_at": None,
        "completed_at": None,
        "files_reserved": {},  # role -> [file paths] for conflict prevention
    }

    # Save team session
    fp = active_teams_dir(root) / f"{team_id}.json"
    save_json(fp, team)

    # Create team message directory
    (messages_dir(root) / team_id).mkdir(parents=True, exist_ok=True)

    # Create shared context file
    shared_context = {
        "team_id": team_id,
        "parent_ticket": parent_ticket,
        "decisions": [],
        "interfaces": [],
        "notes": [],
        "updated_at": now_iso(),
    }
    ctx_fp = context_dir(root) / f"{team_id}-shared.json"
    save_json(ctx_fp, shared_context)

    # Emit cto.team.created event
    emit("cto.team.created", {
        "team_id": team_id,
        "parent_ticket": parent_ticket,
        "template": template_name,
        "members": [{"role": m["role"], "focus": m.get("focus", "")} for m in members],
        "coordination_mode": coordination["mode"],
        "lead": coordination["lead"],
    }, role="rick", team_id=team_id)

    return team


def load_team(root: Path, team_id: str) -> dict:
    """Load a team session by ID."""
    fp = active_teams_dir(root) / f"{team_id}.json"
    if not fp.exists():
        print(f"Error: Team {team_id} not found.", file=sys.stderr)
        sys.exit(1)
    return load_json(fp)


def save_team(root: Path, team: dict):
    """Save a team session."""
    fp = active_teams_dir(root) / f"{team['id']}.json"
    save_json(fp, team)


def all_teams(root: Path) -> list[dict]:
    """Load all team sessions."""
    td = active_teams_dir(root)
    if not td.exists():
        return []
    teams = []
    for fp in sorted(td.glob("*.json")):
        teams.append(load_json(fp))
    return teams


def update_member_status(root: Path, team_id: str, role: str, status: str, output_summary: Optional[str] = None):
    """Update a team member's status."""
    team = load_team(root, team_id)
    old_member_status = None
    for member in team["members"]:
        if member["role"] == role:
            old_member_status = member["status"]
            member["status"] = status
            if status == "working" and member["started_at"] is None:
                member["started_at"] = now_iso()
            if status in ("completed", "blocked") and member["completed_at"] is None:
                member["completed_at"] = now_iso()
            if output_summary:
                member["output_summary"] = output_summary
            break

    # Update team status based on member statuses
    old_team_status = team["status"]
    statuses = [m["status"] for m in team["members"]]
    if all(s == "completed" for s in statuses):
        team["status"] = "completed"
        team["completed_at"] = now_iso()
    elif any(s == "blocked" for s in statuses):
        team["status"] = "blocked"
    elif any(s == "working" for s in statuses):
        team["status"] = "active"
        if team["started_at"] is None:
            team["started_at"] = now_iso()

    save_team(root, team)

    # Emit cto.team.member.status.changed event
    if old_member_status and old_member_status != status:
        emit("cto.team.member.status.changed", {
            "team_id": team_id,
            "role": role,
            "old_status": old_member_status,
            "new_status": status,
            "output_summary": output_summary[:100] if output_summary else None,
        }, role=role, team_id=team_id)

    # Emit cto.team.team.status.changed event
    if old_team_status != team["status"]:
        emit("cto.team.team.status.changed", {
            "team_id": team_id,
            "old_status": old_team_status,
            "new_status": team["status"],
            "parent_ticket": team.get("parent_ticket"),
        }, role="rick", team_id=team_id)

    return team


# ── Shared Context ───────────────────────────────────────────────────────────

def load_shared_context(root: Path, team_id: str) -> dict:
    """Load shared context for a team."""
    fp = context_dir(root) / f"{team_id}-shared.json"
    if not fp.exists():
        return {"team_id": team_id, "decisions": [], "interfaces": [], "notes": [], "updated_at": now_iso()}
    return load_json(fp)


def save_shared_context(root: Path, team_id: str, context: dict):
    """Save shared context for a team."""
    context["updated_at"] = now_iso()
    fp = context_dir(root) / f"{team_id}-shared.json"
    save_json(fp, context)


def add_decision(root: Path, team_id: str, decision: str, author: str):
    """Add a decision to shared context."""
    ctx = load_shared_context(root, team_id)
    ctx["decisions"].append({
        "decision": decision,
        "author": author,
        "timestamp": now_iso(),
    })
    save_shared_context(root, team_id, ctx)

    # Emit cto.team.decision.recorded event
    emit("cto.team.decision.recorded", {
        "team_id": team_id,
        "decision": decision[:200],
        "author": author,
    }, role=author, team_id=team_id)


def add_interface(root: Path, team_id: str, interface: dict, author: str):
    """Add an interface definition to shared context."""
    ctx = load_shared_context(root, team_id)
    ctx["interfaces"].append({
        "interface": interface,
        "author": author,
        "timestamp": now_iso(),
    })
    save_shared_context(root, team_id, ctx)

    # Emit cto.team.interface.defined event
    emit("cto.team.interface.defined", {
        "team_id": team_id,
        "interface": interface,
        "author": author,
    }, role=author, team_id=team_id)


def add_note(root: Path, team_id: str, note: str, author: str):
    """Add a note to shared context."""
    ctx = load_shared_context(root, team_id)
    ctx["notes"].append({
        "note": note,
        "author": author,
        "timestamp": now_iso(),
    })
    save_shared_context(root, team_id, ctx)


# ── Inter-Agent Messages ─────────────────────────────────────────────────────

def next_message_id(root: Path, team_id: str) -> str:
    """Generate next message ID for a team."""
    msg_dir = messages_dir(root) / team_id
    existing = list(msg_dir.glob("msg-*.json"))
    num = len(existing) + 1
    return f"msg-{num:03d}"


def send_message(
    root: Path,
    team_id: str,
    from_role: str,
    to_role: str,  # Use "@*" for broadcast
    message: str,
    message_type: str = "info",  # info, question, decision, blocked
) -> dict:
    """Send a message between team members.

    Args:
        root: Project root
        team_id: Team session ID
        from_role: Sender role
        to_role: Recipient role ("@*" for broadcast to all)
        message: Message content
        message_type: Type of message (info, question, decision, blocked)

    Returns:
        Created message dict
    """
    msg_id = next_message_id(root, team_id)
    msg = {
        "id": msg_id,
        "team_id": team_id,
        "from": from_role,
        "to": to_role,
        "message": message,
        "type": message_type,
        "timestamp": now_iso(),
        "read_by": [],
    }

    fp = messages_dir(root) / team_id / f"{msg_id}.json"
    save_json(fp, msg)

    # Emit cto.team.message.sent event
    emit("cto.team.message.sent", {
        "team_id": team_id,
        "message_id": msg_id,
        "from": from_role,
        "to": to_role,
        "message_type": message_type,
        "message": message[:200],
    }, role=from_role, team_id=team_id)

    return msg


def get_messages(
    root: Path,
    team_id: str,
    for_role: Optional[str] = None,
    unread_only: bool = False,
) -> list[dict]:
    """Get messages for a team, optionally filtered for a specific role.

    Args:
        root: Project root
        team_id: Team session ID
        for_role: If set, only messages to this role or broadcast
        unread_only: If True, only unread messages

    Returns:
        List of message dicts
    """
    msg_dir = messages_dir(root) / team_id
    if not msg_dir.exists():
        return []

    messages = []
    for fp in sorted(msg_dir.glob("msg-*.json")):
        msg = load_json(fp)

        # Filter by recipient if specified
        if for_role:
            if msg["to"] != "@*" and msg["to"] != for_role and msg["from"] != for_role:
                continue

        # Filter unread if specified
        if unread_only and for_role and for_role in msg.get("read_by", []):
            continue

        messages.append(msg)

    return messages


def mark_messages_read(root: Path, team_id: str, role: str, message_ids: Optional[list] = None):
    """Mark messages as read by a role.

    Args:
        root: Project root
        team_id: Team session ID
        role: Role that read the messages
        message_ids: Specific message IDs to mark, or None for all
    """
    msg_dir = messages_dir(root) / team_id
    if not msg_dir.exists():
        return

    for fp in msg_dir.glob("msg-*.json"):
        msg = load_json(fp)
        if message_ids and msg["id"] not in message_ids:
            continue
        if role not in msg.get("read_by", []):
            msg.setdefault("read_by", []).append(role)
            save_json(fp, msg)


# ── File Reservation (Conflict Prevention) ───────────────────────────────────

def reserve_files(root: Path, team_id: str, role: str, file_paths: list[str]) -> bool:
    """Reserve files for a role to prevent conflicts.

    Args:
        root: Project root
        team_id: Team session ID
        role: Role reserving the files
        file_paths: List of file paths to reserve

    Returns:
        True if reservation successful, False if conflict
    """
    team = load_team(root, team_id)
    reserved = team.get("files_reserved", {})

    # Check for conflicts
    conflicts = []
    for path in file_paths:
        for other_role, other_paths in reserved.items():
            if other_role != role and path in other_paths:
                conflicts.append((path, other_role))

    if conflicts:
        print(f"File conflict detected:", file=sys.stderr)
        for path, other_role in conflicts:
            print(f"  {path} already reserved by {other_role}", file=sys.stderr)
        return False

    # Reserve files
    if role not in reserved:
        reserved[role] = []
    reserved[role].extend(file_paths)
    reserved[role] = list(set(reserved[role]))  # Dedupe
    team["files_reserved"] = reserved
    save_team(root, team)
    return True


def release_files(root: Path, team_id: str, role: str):
    """Release all file reservations for a role."""
    team = load_team(root, team_id)
    if role in team.get("files_reserved", {}):
        del team["files_reserved"][role]
        save_team(root, team)


def get_reserved_files(root: Path, team_id: str) -> dict[str, list[str]]:
    """Get all file reservations for a team."""
    team = load_team(root, team_id)
    return team.get("files_reserved", {})


# ── CLI Commands ─────────────────────────────────────────────────────────────

def cmd_create(args):
    """Create a new team session."""
    root = find_cto_root()

    team = create_team_session(
        root,
        parent_ticket=args.ticket,
        template_name=args.template,
    )

    print(f"*Burrrp* Team assembled! {team['id']} for ticket {args.ticket}")
    print(f"  Template: {args.template}")
    print(f"  Members:")
    for m in team["members"]:
        print(f"    - {m['role']}: {m['focus']} (assignment: {m['assignment']})")
    print(f"\nCoordination mode: {team['coordination']['mode']}, lead: {team['coordination']['lead']}")


def cmd_list(args):
    """List all teams."""
    root = find_cto_root()
    teams = all_teams(root)

    if not teams:
        print("No teams assembled. The Morty's are working solo like losers.")
        return

    if args.status:
        teams = [t for t in teams if t["status"] == args.status]

    print(f"{'ID':<12} {'Status':<12} {'Ticket':<12} {'Template':<16} Members")
    print("─" * 70)
    for t in teams:
        members = ", ".join(m["role"] for m in t["members"])
        print(f"{t['id']:<12} {t['status']:<12} {t['parent_ticket']:<12} {t['template']:<16} {members}")


def cmd_status(args):
    """Show detailed status of a team."""
    root = find_cto_root()
    team = load_team(root, args.team_id)

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  TEAM: {team['id']:<54}║
╠══════════════════════════════════════════════════════════════╣
║  Ticket: {team['parent_ticket']:<52}║
║  Template: {team['template']:<50}║
║  Status: {team['status']:<52}║
║  Mode: {team['coordination']['mode']:<54}║
║  Lead: {team['coordination']['lead']:<54}║
╠══════════════════════════════════════════════════════════════╣
║  MEMBERS                                                     ║
╠══════════════════════════════════════════════════════════════╣""")

    for m in team["members"]:
        status_icon = {"pending": "⏳", "working": "🔨", "completed": "✅", "blocked": "🚫"}.get(m["status"], "?")
        print(f"║  {status_icon} {m['role']:<18} [{m['status']:<10}] {m['assignment']:<14}║")
        if m.get("focus"):
            print(f"║     Focus: {m['focus']:<49}║")
        if m.get("output_summary"):
            summary = m["output_summary"][:45] + "..." if len(m.get("output_summary", "")) > 45 else m.get("output_summary", "")
            print(f"║     Output: {summary:<48}║")

    # Show file reservations
    reserved = team.get("files_reserved", {})
    if reserved:
        print("╠══════════════════════════════════════════════════════════════╣")
        print("║  FILE RESERVATIONS                                           ║")
        for role, files in reserved.items():
            print(f"║  {role}: {', '.join(files)[:50]:<50}║")

    print("╚══════════════════════════════════════════════════════════════╝")

    # Show recent messages
    messages = get_messages(root, team["id"])
    if messages:
        print("\nRecent messages:")
        for msg in messages[-5:]:
            icon = {"info": "ℹ️", "question": "❓", "decision": "📋", "blocked": "🚫"}.get(msg["type"], "💬")
            print(f"  {icon} [{msg['from']} → {msg['to']}]: {msg['message'][:50]}")


def cmd_messages(args):
    """Show messages for a team."""
    root = find_cto_root()
    messages = get_messages(root, args.team_id, for_role=args.role, unread_only=args.unread)

    if not messages:
        print("No messages. The Morty's aren't communicating. Typical.")
        return

    print(f"Messages for team {args.team_id}:")
    print("─" * 60)
    for msg in messages:
        icon = {"info": "ℹ️", "question": "❓", "decision": "📋", "blocked": "🚫"}.get(msg["type"], "💬")
        timestamp = msg["timestamp"][:19]
        read_status = f"[read by: {', '.join(msg.get('read_by', []))}]" if msg.get("read_by") else "[unread]"
        print(f"\n{icon} {msg['id']} — {timestamp}")
        print(f"   From: {msg['from']} → To: {msg['to']} {read_status}")
        print(f"   {msg['message']}")


def cmd_send(args):
    """Send a message to team members."""
    root = find_cto_root()

    msg = send_message(
        root,
        team_id=args.team_id,
        from_role=args.from_role,
        to_role=args.to,
        message=args.message,
        message_type=args.type,
    )

    print(f"Message sent: {msg['id']}")
    print(f"  {args.from_role} → {args.to}: {args.message[:50]}")


def cmd_context(args):
    """Show or update shared context."""
    root = find_cto_root()
    ctx = load_shared_context(root, args.team_id)

    if args.add_decision:
        add_decision(root, args.team_id, args.add_decision, args.author or "rick")
        print(f"Decision added to {args.team_id}")
        return

    if args.add_note:
        add_note(root, args.team_id, args.add_note, args.author or "rick")
        print(f"Note added to {args.team_id}")
        return

    # Show context
    print(f"Shared context for {args.team_id}:")
    print("─" * 50)

    print("\nDecisions:")
    for d in ctx.get("decisions", []):
        print(f"  • [{d['author']}] {d['decision']}")

    print("\nInterfaces:")
    for i in ctx.get("interfaces", []):
        print(f"  • [{i['author']}] {json.dumps(i['interface'])[:60]}")

    print("\nNotes:")
    for n in ctx.get("notes", []):
        print(f"  • [{n['author']}] {n['note']}")


def cmd_templates(args):
    """List available team templates."""
    print("Available team templates:")
    print("─" * 50)
    for name, template in TEAM_TEMPLATES.items():
        roles = ", ".join(r["role"] for r in template["roles"])
        print(f"\n{name}:")
        print(f"  {template['description']}")
        print(f"  Roles: {roles}")
        print(f"  Mode: {template['coordination']['mode']}, Lead: {template['coordination']['lead']}")


# ── CLI Parser ───────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(prog="team", description="Rick's Morty Team Management — *burp* coordinate the Morty army")
    sub = p.add_subparsers(dest="command", required=True)

    # create
    c = sub.add_parser("create", help="Create a new team session")
    c.add_argument("--ticket", required=True, help="Parent ticket ID")
    c.add_argument("--template", required=True, choices=list(TEAM_TEMPLATES.keys()), help="Team template")

    # list
    ls = sub.add_parser("list", help="List all teams")
    ls.add_argument("--status", choices=["pending", "active", "completed", "blocked"])

    # status
    st = sub.add_parser("status", help="Show team status")
    st.add_argument("team_id", help="Team ID")

    # messages
    msg = sub.add_parser("messages", help="Show team messages")
    msg.add_argument("team_id", help="Team ID")
    msg.add_argument("--role", help="Filter for specific role")
    msg.add_argument("--unread", action="store_true", help="Only unread messages")

    # send
    snd = sub.add_parser("send", help="Send a message")
    snd.add_argument("team_id", help="Team ID")
    snd.add_argument("--from-role", required=True, help="Sender role")
    snd.add_argument("--to", required=True, help="Recipient role (or @* for broadcast)")
    snd.add_argument("--message", required=True, help="Message content")
    snd.add_argument("--type", default="info", choices=["info", "question", "decision", "blocked"])

    # context
    ctx = sub.add_parser("context", help="Show or update shared context")
    ctx.add_argument("team_id", help="Team ID")
    ctx.add_argument("--add-decision", help="Add a decision")
    ctx.add_argument("--add-note", help="Add a note")
    ctx.add_argument("--author", help="Author of the addition")

    # templates
    sub.add_parser("templates", help="List available team templates")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "create": cmd_create,
        "list": cmd_list,
        "status": cmd_status,
        "messages": cmd_messages,
        "send": cmd_send,
        "context": cmd_context,
        "templates": cmd_templates,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
