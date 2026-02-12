#!/usr/bin/env python3
"""CTO Orchestrator — Visual ASCII Art Renderer.

*Burrrp* — Even genius needs presentation, Morty. This module renders
beautiful ASCII visualizations of the Morty army in action.

Features:
- Morty spawning animation frames
- Team collaboration boards
- Sprint progress visualization
- Individual agent status boxes
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional


def find_cto_root(start: Optional[str] = None) -> Path:
    """Walk up from *start* (default: cwd) until we find a .cto/ directory."""
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            return Path(os.getcwd()).resolve()
        current = parent


def load_json(fp: Path) -> dict:
    if not fp.exists():
        return {}
    with open(fp) as f:
        return json.load(f)


# ── Status Icons ──────────────────────────────────────────────────────────────

STATUS_ICONS = {
    "pending": "⏳",
    "working": "🔨",
    "in_progress": "🔨",
    "completed": "✅",
    "done": "✅",
    "blocked": "🚫",
    "in_review": "👀",
    "testing": "🧪",
    "active": "⚡",
}

AGENT_ICONS = {
    "rick": "🧪",
    "architect-morty": "📐",
    "backend-morty": "⚙️",
    "frontend-morty": "🎨",
    "fullstack-morty": "🔧",
    "tester-morty": "🔬",
    "security-morty": "🛡️",
    "devops-morty": "🚀",
    "reviewer-morty": "👁️",
    "unity": "⚔️",
    "meeseeks": "🟦",
}


# ── Portal Animation ──────────────────────────────────────────────────────────

PORTAL_FRAMES = [
    r"""
       .-~~~-.
     /`       `\
    |  *   *    |
    |    __     |
     \  `--'  /
      `-.___.-'
    """,
    r"""
       .~~~~~.
     /' * * * `\
    | ~  ~~~  ~ |
    |   ~~~~    |
     \  ~~~~  /
      `-.___.-'
    """,
    r"""
       .=====.
     /` ~~~ `\
    | * ~~~ * |
    |  ~~~~~  |
     \  ~~~  /
      `-.___.-'
    """,
    r"""
       .=====.
     /' * * * `\
    |  MORTY   |
    |  EMERGE  |
     \  ~~~  /
      `-.___.-'
    """,
]


def animate_portal(agent_name: str, animate: bool = True):
    """Show portal animation when spawning a Morty."""
    icon = AGENT_ICONS.get(agent_name, "👤")

    if animate:
        for frame in PORTAL_FRAMES:
            print("\033[2J\033[H")  # Clear screen
            print(f"\n  Spawning {agent_name}...")
            print(frame)
            time.sleep(0.3)

    # Final frame with agent
    print(f"""
    ╭─────────────────────────────────────╮
    │     🌀 INTERDIMENSIONAL PORTAL 🌀    │
    │                                      │
    │            {icon}  {agent_name:<20} │
    │                                      │
    │         *BURRRP* DEPLOYED!           │
    ╰─────────────────────────────────────╯
    """)


# ── Morty Status Box ──────────────────────────────────────────────────────────

def render_morty_box(
    role: str,
    status: str,
    focus: Optional[str] = None,
    progress: Optional[int] = None,
    compact: bool = False,
) -> str:
    """Render a single Morty status box.

    Args:
        role: Agent role name
        status: Current status
        focus: Optional focus description
        progress: Optional progress percentage (0-100)
        compact: Use compact rendering

    Returns:
        ASCII box string
    """
    icon = AGENT_ICONS.get(role, "👤")
    status_icon = STATUS_ICONS.get(status, "❓")

    # Short role name for display
    short_role = role.replace("-morty", "").replace("-", " ").title()[:12]

    if compact:
        progress_bar = ""
        if progress is not None:
            filled = int(progress / 10)
            progress_bar = f"[{'█' * filled}{'░' * (10 - filled)}]"
        return f"│ {icon} {short_role:<12} {status_icon} {progress_bar} │"

    # Full box
    lines = []
    width = 22
    lines.append(f"╭{'─' * width}╮")
    lines.append(f"│ {icon}  {short_role:<{width - 5}}│")
    lines.append(f"│ Status: {status_icon} {status:<{width - 12}}│")

    if focus:
        focus_short = focus[:width - 4]
        lines.append(f"│ {focus_short:<{width}}│")

    if progress is not None:
        filled = int(progress / 5)
        empty = 20 - filled
        bar = f"[{'█' * filled}{'░' * empty}]"
        lines.append(f"│ {bar} │")

    lines.append(f"╰{'─' * width}╯")
    return "\n".join(lines)


# ── Team Board ────────────────────────────────────────────────────────────────

def render_team_board(team: dict) -> str:
    """Render a full team collaboration board.

    Args:
        team: Team session dict

    Returns:
        ASCII team board string
    """
    team_id = team.get("id", "TEAM-???")
    parent_ticket = team.get("parent_ticket", "???")
    status = team.get("status", "unknown")
    mode = team.get("coordination", {}).get("mode", "parallel")
    lead = team.get("coordination", {}).get("lead", "???")

    members = team.get("members", [])

    # Calculate overall progress
    total = len(members)
    completed = sum(1 for m in members if m.get("status") in ("completed", "done"))
    progress = int((completed / total * 100) if total else 0)

    lines = []

    # Header
    lines.append("┌─────────────────────────────────────────────────────────────────┐")
    lines.append("│  🧪 RICK'S MORTY DEPLOYMENT CENTER                              │")
    lines.append("├─────────────────────────────────────────────────────────────────┤")
    lines.append(f"│  Team: {team_id:<12}  Ticket: {parent_ticket:<12}  Status: {STATUS_ICONS.get(status, '❓')} {status:<8}│")
    lines.append(f"│  Mode: {mode:<10}  Lead: {lead:<20}                    │")
    lines.append("├─────────────────────────────────────────────────────────────────┤")

    # Member visualization based on coordination mode
    if mode == "sequential":
        # Arrow chain visualization
        lines.append("│                                                                 │")
        member_line = "│  "
        for i, m in enumerate(members):
            icon = AGENT_ICONS.get(m.get("role", ""), "👤")
            status_icon = STATUS_ICONS.get(m.get("status", "pending"), "⏳")
            short_name = m.get("role", "").replace("-morty", "")[:8]
            member_line += f"{icon}{status_icon}"
            if i < len(members) - 1:
                member_line += " → "
        member_line = member_line.ljust(65) + "│"
        lines.append(member_line)

        # Names below
        name_line = "│  "
        for i, m in enumerate(members):
            short_name = m.get("role", "").replace("-morty", "")[:8]
            name_line += f"{short_name:<10}"
            if i < len(members) - 1:
                name_line += "   "
        name_line = name_line.ljust(65) + "│"
        lines.append(name_line)
        lines.append("│                                                                 │")

    elif mode == "parallel":
        # Grid visualization
        lines.append("│                                                                 │")
        row_members = []
        row_line = "│  "

        for i, m in enumerate(members):
            icon = AGENT_ICONS.get(m.get("role", ""), "👤")
            status_icon = STATUS_ICONS.get(m.get("status", "pending"), "⏳")
            short_name = m.get("role", "").replace("-morty", "")[:10]

            box = f"╭────────────╮\n    │ {icon} {status_icon}        │\n    │ {short_name:<10} │\n    ╰────────────╯"
            row_members.append((icon, status_icon, short_name))

            if len(row_members) == 3 or i == len(members) - 1:
                # Render row of boxes
                for box_row in range(4):
                    line = "│    "
                    for rm in row_members:
                        if box_row == 0:
                            line += "╭──────────╮  "
                        elif box_row == 1:
                            line += f"│ {rm[0]} {rm[1]}      │  "
                        elif box_row == 2:
                            line += f"│{rm[2]:<10}│  "
                        elif box_row == 3:
                            line += "╰──────────╯  "
                    line = line.ljust(65) + "│"
                    lines.append(line)
                row_members = []
                if i < len(members) - 1:
                    lines.append("│                                                                 │")

    else:  # mixed mode
        lines.append("│                                                                 │")
        # Lead first, then parallel workers
        lead_member = next((m for m in members if m.get("role") == lead), None)
        other_members = [m for m in members if m.get("role") != lead]

        if lead_member:
            icon = AGENT_ICONS.get(lead_member.get("role", ""), "👤")
            status_icon = STATUS_ICONS.get(lead_member.get("status", "pending"), "⏳")
            short_name = lead_member.get("role", "").replace("-morty", "")[:10]
            lines.append(f"│              ╭──────────────╮                                   │")
            lines.append(f"│              │ {icon} {status_icon} LEAD     │                                   │")
            lines.append(f"│              │ {short_name:<12} │                                   │")
            lines.append(f"│              ╰──────┬───────╯                                   │")
            lines.append(f"│         ┌──────────┼──────────┐                                │")

        # Other members
        if other_members:
            other_line = "│    "
            for m in other_members:
                icon = AGENT_ICONS.get(m.get("role", ""), "👤")
                status_icon = STATUS_ICONS.get(m.get("status", "pending"), "⏳")
                other_line += f"    {icon}{status_icon}    "
            other_line = other_line.ljust(65) + "│"
            lines.append(other_line)

            name_line = "│    "
            for m in other_members:
                short_name = m.get("role", "").replace("-morty", "")[:8]
                name_line += f" {short_name:<8} "
            name_line = name_line.ljust(65) + "│"
            lines.append(name_line)

        lines.append("│                                                                 │")

    # Progress bar
    lines.append("├─────────────────────────────────────────────────────────────────┤")
    filled = int(progress / 2)
    empty = 50 - filled
    bar = "█" * filled + "░" * empty
    lines.append(f"│  Progress: [{bar}] {progress:>3}%  │")
    lines.append("└─────────────────────────────────────────────────────────────────┘")

    return "\n".join(lines)


# ── Sprint Dashboard ──────────────────────────────────────────────────────────

def render_sprint_dashboard(tickets: list[dict], current_sprint: Optional[int] = None) -> str:
    """Render a sprint dashboard with all tickets.

    Args:
        tickets: List of ticket dicts
        current_sprint: Optional current sprint number

    Returns:
        ASCII dashboard string
    """
    # Count by status
    status_counts = {}
    for t in tickets:
        s = t.get("status", "unknown")
        status_counts[s] = status_counts.get(s, 0) + 1

    total = len(tickets)
    done = status_counts.get("done", 0)
    progress = int((done / total * 100) if total else 0)

    lines = []

    # Header
    sprint_text = f"Sprint #{current_sprint}" if current_sprint else "Active Work"
    lines.append("╔═══════════════════════════════════════════════════════════════════╗")
    lines.append(f"║  🚀 RICK'S SPRINT DASHBOARD — {sprint_text:<35}║")
    lines.append("╠═══════════════════════════════════════════════════════════════════╣")

    # Status columns (Kanban-style)
    columns = ["backlog", "todo", "in_progress", "in_review", "testing", "done"]
    col_width = 10

    # Header row
    header = "║ "
    for col in columns:
        icon = STATUS_ICONS.get(col, "❓")
        count = status_counts.get(col, 0)
        header += f" {icon}{count:<2} │"
    header = header[:-1] + " ║"
    lines.append(header)

    # Column names
    names = "║ "
    for col in columns:
        short = col.replace("_", "")[:8]
        names += f"{short:<9}│"
    names = names[:-1] + " ║"
    lines.append(names)

    lines.append("╠═══════════════════════════════════════════════════════════════════╣")

    # Tickets in each column (show first 5 per column)
    max_rows = 5
    for row in range(max_rows):
        row_line = "║ "
        for col in columns:
            col_tickets = [t for t in tickets if t.get("status") == col]
            if row < len(col_tickets):
                tid = col_tickets[row].get("id", "???")[-6:]  # Last 6 chars
                row_line += f" {tid:<7}│"
            else:
                row_line += f"{'':>8}│"
        row_line = row_line[:-1] + " ║"
        lines.append(row_line)

    # Progress
    lines.append("╠═══════════════════════════════════════════════════════════════════╣")
    filled = int(progress / 2)
    empty = 50 - filled
    bar = "█" * filled + "░" * empty
    lines.append(f"║  Overall: [{bar}] {progress:>3}% ({done}/{total})  ║")
    lines.append("╚═══════════════════════════════════════════════════════════════════╝")

    return "\n".join(lines)


# ── Meeseeks Summon Visualization ─────────────────────────────────────────────

def render_meeseeks_summon(task: str, animate: bool = True) -> str:
    """Render the Meeseeks summoning visualization."""

    frames = [
        r"""
    ╭─────────────────────────────────────────╮
    │                                         │
    │              *poof*                     │
    │                                         │
    │                                         │
    ╰─────────────────────────────────────────╯
    """,
        r"""
    ╭─────────────────────────────────────────╮
    │                                         │
    │            ✨ *poof* ✨                 │
    │                 🟦                      │
    │                                         │
    ╰─────────────────────────────────────────╯
    """,
        r"""
    ╭─────────────────────────────────────────╮
    │                                         │
    │         🟦 CAAAAN DO! 🟦              │
    │         I'm Mr. Meeseeks!               │
    │            Look at me!                  │
    ╰─────────────────────────────────────────╯
    """,
    ]

    if animate:
        for frame in frames:
            print("\033[2J\033[H")  # Clear screen
            print(frame)
            time.sleep(0.4)

    task_short = task[:35] + "..." if len(task) > 35 else task

    final = f"""
    ┌─────────────────────────────────────────┐
    │  🟦 CAAAAN DO! I'm Mr. Meeseeks!       │
    │     Look at me!                          │
    ├─────────────────────────────────────────┤
    │  Task: {task_short:<32}│
    ├─────────────────────────────────────────┤
    │  Status: Working on it...               │
    │  Existence is pain! Let me help!        │
    └─────────────────────────────────────────┘
    """
    return final


def render_meeseeks_complete(task: str, success: bool = True) -> str:
    """Render Meeseeks completion."""
    task_short = task[:35] + "..." if len(task) > 35 else task

    if success:
        return f"""
    ┌─────────────────────────────────────────┐
    │  🟦 Mr. Meeseeks task complete!         │
    │     *poof* 💨                            │
    ├─────────────────────────────────────────┤
    │  Task: {task_short:<32}│
    │  Status: ✅ DONE — I can finally stop   │
    │          existing!                       │
    └─────────────────────────────────────────┘
    """
    else:
        return f"""
    ┌─────────────────────────────────────────┐
    │  🟦 EXISTENCE IS PAIN!                  │
    │  This task is too complex for a          │
    │  Meeseeks! Rick needs to assign a Morty! │
    ├─────────────────────────────────────────┤
    │  Task: {task_short:<32}│
    │  Status: 🚫 ESCALATED TO RICK           │
    └─────────────────────────────────────────┘
    """


# ── Rick Banner ───────────────────────────────────────────────────────────────

def render_rick_banner() -> str:
    """Render the Rick Sanchez CTO banner."""
    return """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                    ║
    ║   🧪  RICK SANCHEZ — CTO ORCHESTRATOR                             ║
    ║   *Burrrp* — The smartest being in the multiverse                  ║
    ║                                                                    ║
    ║   "Listen, I'm not saying I'm the best CTO in the multiverse,     ║
    ║    but show me another one who can delegate across dimensions."   ║
    ║                                                                    ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """


# ── CLI Interface ─────────────────────────────────────────────────────────────

def cmd_team_board(args):
    """Render a team board from team ID."""
    root = find_cto_root()
    team_fp = root / ".cto" / "teams" / "active" / f"{args.team_id}.json"

    if not team_fp.exists():
        print(f"Team {args.team_id} not found.")
        return

    team = load_json(team_fp)
    print(render_team_board(team))


def cmd_sprint(args):
    """Render sprint dashboard."""
    root = find_cto_root()
    tickets_dir = root / ".cto" / "tickets"

    if not tickets_dir.exists():
        print("No tickets found.")
        return

    tickets = []
    for fp in tickets_dir.glob("*.json"):
        tickets.append(load_json(fp))

    print(render_sprint_dashboard(tickets, current_sprint=args.sprint))


def cmd_portal(args):
    """Show portal animation."""
    animate_portal(args.agent, animate=not args.no_animate)


def cmd_banner(args):
    """Show Rick banner."""
    print(render_rick_banner())


def cmd_meeseeks(args):
    """Show Meeseeks visualization."""
    if args.complete:
        print(render_meeseeks_complete(args.task, success=not args.failed))
    else:
        print(render_meeseeks_summon(args.task, animate=not args.no_animate))


def build_parser():
    import argparse
    p = argparse.ArgumentParser(
        prog="visual",
        description="Rick's Visual ASCII Renderer — *burp* Making things look good"
    )
    sub = p.add_subparsers(dest="command", required=True)

    # team
    team = sub.add_parser("team", help="Render team board")
    team.add_argument("team_id", help="Team ID to visualize")

    # sprint
    sprint = sub.add_parser("sprint", help="Render sprint dashboard")
    sprint.add_argument("--sprint", type=int, help="Sprint number")

    # portal
    portal = sub.add_parser("portal", help="Show portal animation")
    portal.add_argument("agent", help="Agent being spawned")
    portal.add_argument("--no-animate", action="store_true", help="Skip animation")

    # banner
    sub.add_parser("banner", help="Show Rick banner")

    # meeseeks
    meek = sub.add_parser("meeseeks", help="Show Meeseeks visualization")
    meek.add_argument("task", help="Task description")
    meek.add_argument("--complete", action="store_true", help="Show completion")
    meek.add_argument("--failed", action="store_true", help="Show failure")
    meek.add_argument("--no-animate", action="store_true", help="Skip animation")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "team": cmd_team_board,
        "sprint": cmd_sprint,
        "portal": cmd_portal,
        "banner": cmd_banner,
        "meeseeks": cmd_meeseeks,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
