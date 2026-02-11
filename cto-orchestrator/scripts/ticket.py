#!/usr/bin/env python3
"""CTO Orchestrator — Ticket management CLI.

Rick Sanchez's *burp* ticket management system. The Morty's do the work,
Rick tells them what to do. Manages tickets as individual JSON files in
.cto/tickets/ because even genius needs a filing system, Morty.
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


def tickets_dir(root: Path) -> Path:
    return root / ".cto" / "tickets"


def config_path(root: Path) -> Path:
    return root / ".cto" / "config.json"


def load_config(root: Path) -> dict:
    cp = config_path(root)
    if not cp.exists():
        print(f"Error: {cp} not found.", file=sys.stderr)
        sys.exit(1)
    with open(cp) as f:
        return json.load(f)


def save_config(root: Path, cfg: dict):
    with open(config_path(root), "w") as f:
        json.dump(cfg, f, indent=2)


def next_ticket_id(root: Path) -> str:
    cfg = load_config(root)
    prefix = cfg["ticket_prefix"]
    num = cfg.get("next_ticket_number", 1)
    tid = f"{prefix}-{num:03d}"
    cfg["next_ticket_number"] = num + 1
    save_config(root, cfg)
    return tid


def load_ticket(root: Path, ticket_id: str) -> dict:
    fp = tickets_dir(root) / f"{ticket_id}.json"
    if not fp.exists():
        print(f"Error: Ticket {ticket_id} not found.", file=sys.stderr)
        sys.exit(1)
    with open(fp) as f:
        return json.load(f)


def save_ticket(root: Path, ticket: dict):
    td = tickets_dir(root)
    td.mkdir(parents=True, exist_ok=True)
    fp = td / f"{ticket['id']}.json"
    with open(fp, "w") as f:
        json.dump(ticket, f, indent=2)


def all_tickets(root: Path) -> list[dict]:
    td = tickets_dir(root)
    if not td.exists():
        return []
    tickets = []
    for fp in sorted(td.glob("*.json")):
        with open(fp) as f:
            tickets.append(json.load(f))
    return tickets


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# Maps old-style agent names to their Morty equivalents for display
MORTY_NAMES = {
    "architect": "architect-morty",
    "backend-dev": "backend-morty",
    "frontend-dev": "frontend-morty",
    "fullstack-dev": "fullstack-morty",
    "tester": "tester-morty",
    "security": "security-morty",
    "devops": "devops-morty",
    "code-reviewer": "reviewer-morty",
}


def morty_display(agent: Optional[str]) -> str:
    """Return the Morty display name for an agent, or '—' if unassigned."""
    if not agent:
        return "—"
    return MORTY_NAMES.get(agent, agent)


# ── Commands ────────────────────────────────────────────────────────────────


TEAM_TEMPLATES = ["fullstack-team", "api-team", "security-team", "devops-team"]


def cmd_create(args):
    root = find_cto_root()
    tid = next_ticket_id(root)

    # Handle team mode
    team_mode = getattr(args, 'team_mode', None) or "solo"
    team_template = getattr(args, 'team_template', None)

    # Validate team template
    if team_template and team_template not in TEAM_TEMPLATES:
        print(f"Warning: Unknown team template '{team_template}'. Using solo mode.")
        team_mode = "solo"
        team_template = None

    # Auto-suggest team mode for complex tickets
    if team_mode == "solo" and args.complexity in ("L", "XL"):
        print(f"  Hint: This is a {args.complexity} ticket. Consider using --team-mode collaborative")

    ticket = {
        "id": tid,
        "title": args.title,
        "description": args.description or "",
        "type": args.type,
        "status": "backlog",
        "priority": args.priority,
        "assigned_agent": None,
        "parent_ticket": args.parent or None,
        "dependencies": [d.strip() for d in args.depends.split(",")] if args.depends else [],
        "acceptance_criteria": [c.strip() for c in args.criteria.split("|")] if args.criteria else [],
        "estimated_complexity": args.complexity or "M",
        # Team collaboration fields
        "team_mode": team_mode,
        "team_template": team_template,
        "team_id": None,  # Set when team is spawned
        # Timestamps
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "completed_at": None,
        "agent_output": None,
        "review_notes": None,
        "files_touched": [],
    }
    save_ticket(root, ticket)

    # Emit cto.ticket.created event
    emit("cto.ticket.created", {
        "ticket_id": tid,
        "title": args.title,
        "type": args.type,
        "priority": args.priority,
        "complexity": args.complexity or "M",
        "team_mode": team_mode,
        "team_template": team_template,
        "parent_ticket": args.parent,
    }, role="rick")

    team_msg = f" (team: {team_template})" if team_mode == "collaborative" else ""
    print(f"*Burrrp* Created {tid}: {args.title}{team_msg}. Now get to work, Morty.")
    return tid


def cmd_list(args):
    root = find_cto_root()
    tickets = all_tickets(root)
    if args.status:
        tickets = [t for t in tickets if t["status"] == args.status]
    if args.agent:
        tickets = [t for t in tickets if t.get("assigned_agent") == args.agent]
    if args.type:
        tickets = [t for t in tickets if t["type"] == args.type]
    if not tickets:
        print("No tickets found, Morty. The board is emptier than your brain.")
        return
    # table header
    print(f"{'ID':<12} {'Status':<14} {'Pri':<10} {'Type':<10} {'Morty':<15} {'Title'}")
    print("─" * 90)
    for t in tickets:
        agent = morty_display(t.get("assigned_agent"))
        print(f"{t['id']:<12} {t['status']:<14} {t['priority']:<10} {t['type']:<10} {agent:<15} {t['title']}")


def cmd_update(args):
    root = find_cto_root()
    ticket = load_ticket(root, args.ticket_id)
    changed = []
    for field in ["status", "assigned_agent", "priority", "title", "description", "complexity", "parent", "depends", "criteria"]:
        val = getattr(args, field, None)
        if val is not None:
            if field == "depends":
                ticket["dependencies"] = [d.strip() for d in val.split(",")]
            elif field == "criteria":
                ticket["acceptance_criteria"] = [c.strip() for c in val.split("|")]
            elif field == "parent":
                ticket["parent_ticket"] = val
            elif field == "complexity":
                ticket["estimated_complexity"] = val
            else:
                ticket[field] = val
            changed.append(field)
    ticket["updated_at"] = now_iso()
    save_ticket(root, ticket)

    # Emit events for specific field changes
    if "status" in changed:
        emit("cto.ticket.status.changed", {
            "ticket_id": args.ticket_id,
            "new_status": ticket["status"],
            "title": ticket.get("title"),
        }, role="rick")

    if "assigned_agent" in changed:
        emit("cto.ticket.assigned", {
            "ticket_id": args.ticket_id,
            "assigned_agent": ticket.get("assigned_agent"),
            "title": ticket.get("title"),
        }, role="rick")

    print(f"Fine, updated {args.ticket_id}: {', '.join(changed)}. Happy now, Morty?")


def cmd_show(args):
    root = find_cto_root()
    t = load_ticket(root, args.ticket_id)
    print(json.dumps(t, indent=2))


def cmd_breakdown(args):
    root = find_cto_root()
    parent = load_ticket(root, args.ticket_id)
    children = [t for t in all_tickets(root) if t.get("parent_ticket") == args.ticket_id]
    print(f"Epic: {parent['id']} — {parent['title']}  [{parent['status']}]")
    print(f"  {parent['description']}")
    if not children:
        print("  (no sub-tickets)")
    else:
        print(f"\n  Sub-tickets ({len(children)}):")
        for c in children:
            agent = morty_display(c.get("assigned_agent"))
            print(f"    {c['id']}  [{c['status']:<14}]  {c['priority']:<8}  @{agent:<14}  {c['title']}")


def cmd_board(args):
    root = find_cto_root()
    tickets = all_tickets(root)
    statuses = ["backlog", "todo", "in_progress", "in_review", "testing", "done", "blocked"]
    board: dict[str, list] = {s: [] for s in statuses}
    for t in tickets:
        s = t["status"]
        if s not in board:
            board[s] = []
        board[s].append(t)

    rick_board_comments = {
        "backlog": "The pile of stuff nobody wants to deal with",
        "todo": "Ugh, things the Morty's still haven't started",
        "in_progress": "Someone's actually doing something for once",
        "in_review": "Let's see how badly they screwed this up",
        "testing": "Poking it with a stick to see if it breaks",
        "done": "Miracles do happen, Morty",
        "blocked": "Stuck. Like your brain during math class, Morty",
    }
    for status in statuses:
        items = board[status]
        label = status.upper().replace("_", " ")
        comment = rick_board_comments.get(status, "")
        print(f"\n{'═' * 50}")
        print(f"  {label} ({len(items)}) — {comment}")
        print(f"{'═' * 50}")
        if not items:
            print("  (empty)")
        for t in items:
            agent = f"@{morty_display(t.get('assigned_agent'))}" if t.get("assigned_agent") else ""
            pri = t["priority"][0].upper()
            print(f"  [{pri}] {t['id']}  {t['title']}  {agent}")


def cmd_next(args):
    """Determine next ticket to work on based on priority and dependency readiness."""
    root = find_cto_root()
    tickets = all_tickets(root)
    done_ids = {t["id"] for t in tickets if t["status"] == "done"}
    actionable_statuses = {"backlog", "todo"}

    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}

    candidates = []
    for t in tickets:
        if t["status"] not in actionable_statuses:
            continue
        deps = t.get("dependencies") or []
        if all(d in done_ids for d in deps):
            candidates.append(t)

    candidates.sort(key=lambda t: priority_order.get(t["priority"], 99))

    if not candidates:
        print("Nothing to do. Go watch interdimensional cable or something.")
        return
    t = candidates[0]
    print(f"Alright Morty, here's your next mission: {t['id']} — {t['title']}")
    print(f"  Priority: {t['priority']}  Type: {t['type']}  Complexity: {t.get('estimated_complexity', '?')}")
    if t.get("dependencies"):
        print(f"  Dependencies (all met): {', '.join(t['dependencies'])}")
    return t["id"]


def cmd_close(args):
    root = find_cto_root()
    ticket = load_ticket(root, args.ticket_id)
    ticket["status"] = "done"
    ticket["completed_at"] = now_iso()
    if args.output:
        ticket["agent_output"] = args.output
    ticket["updated_at"] = now_iso()
    save_ticket(root, ticket)

    # Emit cto.ticket.completed event
    emit("cto.ticket.completed", {
        "ticket_id": args.ticket_id,
        "title": ticket.get("title"),
        "type": ticket.get("type"),
        "assigned_agent": ticket.get("assigned_agent"),
        "files_touched": ticket.get("files_touched", []),
    }, role="rick")

    print(f"About time. Closed {args.ticket_id}. Wubba lubba dub dub!")


def cmd_blocked(args):
    root = find_cto_root()
    ticket = load_ticket(root, args.ticket_id)
    ticket["status"] = "blocked"
    ticket["review_notes"] = f"BLOCKED: {args.reason}"
    ticket["updated_at"] = now_iso()
    save_ticket(root, ticket)

    # Emit cto.ticket.blocked event
    emit("cto.ticket.blocked", {
        "ticket_id": args.ticket_id,
        "title": ticket.get("title"),
        "reason": args.reason,
        "assigned_agent": ticket.get("assigned_agent"),
    }, role="rick")

    print(f"Great, another roadblock. Blocked {args.ticket_id}: {args.reason}")


# ── CLI ─────────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(prog="ticket", description="Rick Sanchez's CTO Orchestrator — *burp* ticket management for the Morty's")
    sub = p.add_subparsers(dest="command", required=True)

    # create
    c = sub.add_parser("create", help="Create a new ticket")
    c.add_argument("--title", required=True)
    c.add_argument("--type", required=True, choices=["feature", "bug", "task", "spike", "epic", "security"])
    c.add_argument("--priority", default="medium", choices=["critical", "high", "medium", "low"])
    c.add_argument("--description", default="")
    c.add_argument("--parent", default=None, help="Parent ticket ID for sub-tickets")
    c.add_argument("--depends", default=None, help="Comma-separated dependency ticket IDs")
    c.add_argument("--criteria", default=None, help="Pipe-separated acceptance criteria")
    c.add_argument("--complexity", default="M", choices=["XS", "S", "M", "L", "XL"])
    # Team collaboration options
    c.add_argument("--team-mode", default="solo", choices=["solo", "collaborative"],
                   help="Work mode: solo (single agent) or collaborative (team)")
    c.add_argument("--team-template", default=None,
                   choices=["fullstack-team", "api-team", "security-team", "devops-team"],
                   help="Team template for collaborative mode")

    # list
    ls = sub.add_parser("list", help="List tickets")
    ls.add_argument("--status", default=None)
    ls.add_argument("--agent", default=None)
    ls.add_argument("--type", default=None)

    # update
    u = sub.add_parser("update", help="Update a ticket")
    u.add_argument("ticket_id")
    u.add_argument("--status", choices=["backlog", "todo", "in_progress", "in_review", "testing", "done", "blocked"])
    u.add_argument("--assigned_agent")
    u.add_argument("--priority", choices=["critical", "high", "medium", "low"])
    u.add_argument("--title")
    u.add_argument("--description")
    u.add_argument("--complexity", choices=["XS", "S", "M", "L", "XL"])
    u.add_argument("--parent")
    u.add_argument("--depends")
    u.add_argument("--criteria")

    # show
    s = sub.add_parser("show", help="Show ticket details")
    s.add_argument("ticket_id")

    # breakdown
    b = sub.add_parser("breakdown", help="Show epic with sub-tickets")
    b.add_argument("ticket_id")

    # board
    sub.add_parser("board", help="Kanban board view")

    # next
    sub.add_parser("next", help="Show next actionable ticket")

    # close
    cl = sub.add_parser("close", help="Close a ticket")
    cl.add_argument("ticket_id")
    cl.add_argument("--output", default=None, help="Summary of deliverables")

    # blocked
    bl = sub.add_parser("blocked", help="Mark ticket as blocked")
    bl.add_argument("ticket_id")
    bl.add_argument("--reason", required=True)

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "create": cmd_create,
        "list": cmd_list,
        "update": cmd_update,
        "show": cmd_show,
        "breakdown": cmd_breakdown,
        "board": cmd_board,
        "next": cmd_next,
        "close": cmd_close,
        "blocked": cmd_blocked,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
