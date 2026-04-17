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

import io
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.progress import BarColumn, Progress, TextColumn
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

console = Console()


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


def _status_color(status: str) -> str:
    """Map status string to Rich color name."""
    if status in ("completed", "done"):
        return "green"
    if status in ("working", "in_progress", "active"):
        return "yellow"
    if status == "blocked":
        return "red"
    if status == "in_review":
        return "blue"
    return "white"


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
        with Live(console=console, refresh_per_second=4) as live:
            for frame in PORTAL_FRAMES:
                live.update(Panel(
                    Text(f"\n  Spawning {agent_name}...\n{frame}"),
                    title="[green]🌀 Portal Opening[/green]",
                    border_style="green",
                ))
                time.sleep(0.3)

    console.print(Panel(
        f"[yellow]{icon}  {agent_name}[/yellow]\n\n[bold green]*BURRRP* DEPLOYED![/bold green]",
        title="[bold green]🌀 INTERDIMENSIONAL PORTAL 🌀[/bold green]",
        border_style="green",
        padding=(1, 4),
    ))


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
        compact: Use compact single-line rendering (returns string)

    Returns:
        String for compact mode; prints via Rich console for full mode.
    """
    icon = AGENT_ICONS.get(role, "👤")
    status_icon = STATUS_ICONS.get(status, "❓")
    short_role = role.replace("-morty", "").replace("-", " ").title()[:12]

    if compact:
        progress_bar = ""
        if progress is not None:
            filled = int(progress / 10)
            progress_bar = f"[{'█' * filled}{'░' * (10 - filled)}]"
        return f"│ {icon} {short_role} {status_icon} {progress_bar} │"

    sc = _status_color(status)
    content = Text()
    content.append(f"{icon}  {short_role}\n", style="bold")
    content.append("Status: ", style="dim")
    content.append(f"{status_icon} {status}", style=sc)
    if focus:
        content.append(f"\n{focus[:30]}", style="dim")
    if progress is not None:
        filled = int(progress / 5)
        empty = 20 - filled
        content.append(f"\n[{'█' * filled}{'░' * empty}] {progress}%")

    console.print(Panel(content, border_style=sc))
    return ""


# ── Bounded Output Helper ─────────────────────────────────────────────────────

_BOUND_LINES = 200
_BOUND_CHARS = 50_000


def render_bounded(content: str, kind: str, root: Path) -> bool:
    """Offload *content* to a report file when it exceeds display thresholds.

    Thresholds: > 200 lines OR > 50 000 chars.

    Prints a 10-line preview + file path to the console and returns True when
    the content was offloaded.  Returns False when content is within bounds
    (caller is responsible for rendering it normally).
    """
    lines = content.splitlines()
    if len(lines) <= _BOUND_LINES and len(content) <= _BOUND_CHARS:
        return False

    reports_dir = root / ".cto" / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d-%H%M")
    report_file = reports_dir / f"{ts}-{kind}.md"
    report_file.write_text(content)

    preview = "\n".join(lines[:10])
    console.print(Panel(
        f"[dim]Output too large ({len(lines)} lines / {len(content):,} chars) — saved to file.[/dim]\n\n"
        f"[white]{preview}[/white]\n"
        f"[dim]…[/dim]\n\n"
        f"[cyan]Full report → {report_file}[/cyan]",
        title=f"[yellow]📄 {kind} (truncated)[/yellow]",
        border_style="yellow",
    ))
    return True


def _make_console(buf: io.StringIO) -> Console:
    """Return a plain-text Console writing into *buf* (for size estimation)."""
    return Console(file=buf, width=120, no_color=True, highlight=False)


# ── Team Board ────────────────────────────────────────────────────────────────

def _render_team_board_impl(team: dict, con: Console) -> None:
    """Core team board rendering — writes to *con*."""
    team_id = team.get("id", "TEAM-???")
    parent_ticket = team.get("parent_ticket", "???")
    status = team.get("status", "unknown")
    mode = team.get("coordination", {}).get("mode", "parallel")
    lead = team.get("coordination", {}).get("lead", "???")
    members = team.get("members", [])

    total = len(members)
    completed = sum(1 for m in members if m.get("status") in ("completed", "done"))
    progress = int((completed / total * 100) if total else 0)

    con.print(Panel(
        f"Team: [bold]{team_id}[/bold]  "
        f"Ticket: [yellow]{parent_ticket}[/yellow]  "
        f"Status: {STATUS_ICONS.get(status, '❓')} [cyan]{status}[/cyan]  "
        f"Mode: [green]{mode}[/green]  "
        f"Lead: [magenta]{lead}[/magenta]",
        title="[bold green]🧪 RICK'S MORTY DEPLOYMENT CENTER[/bold green]",
        border_style="green",
    ))

    if mode == "mixed":
        lead_member = next((m for m in members if m.get("role") == lead), None)
        other_members = [m for m in members if m.get("role") != lead]

        lead_status = lead_member.get("status", "pending") if lead_member else "pending"
        lead_sc = _status_color(lead_status)
        tree = Tree(
            f"[bold magenta]{AGENT_ICONS.get(lead, '👤')} {lead} (LEAD)[/bold magenta]  "
            f"{STATUS_ICONS.get(lead_status, '⏳')} [{lead_sc}]{lead_status}[/{lead_sc}]"
        )
        for m in other_members:
            role = m.get("role", "?")
            s = m.get("status", "pending")
            icon = AGENT_ICONS.get(role, "👤")
            sc = _status_color(s)
            tree.add(
                f"{icon} [yellow]{role}[/yellow]  "
                f"{STATUS_ICONS.get(s, '⏳')} [{sc}]{s}[/{sc}]"
            )
        con.print(tree)

    else:
        table = Table(
            show_header=True,
            header_style="bold cyan",
            border_style="green",
            show_lines=(mode == "sequential"),
        )
        table.add_column("Agent", style="yellow", no_wrap=True)
        table.add_column("Icon", justify="center")
        table.add_column("Status", no_wrap=True)
        table.add_column("Focus")

        if mode == "sequential":
            for i, m in enumerate(members):
                role = m.get("role", "?")
                s = m.get("status", "pending")
                icon = AGENT_ICONS.get(role, "👤")
                focus = m.get("focus", m.get("task_title", ""))[:30]
                sc = _status_color(s)
                prefix = f"[dim]{i + 1}.[/dim] " if i > 0 else ""
                table.add_row(
                    f"{prefix}{role}",
                    icon,
                    f"{STATUS_ICONS.get(s, '⏳')} [{sc}]{s}[/{sc}]",
                    focus,
                )
        else:
            for m in members:
                role = m.get("role", "?")
                s = m.get("status", "pending")
                icon = AGENT_ICONS.get(role, "👤")
                focus = m.get("focus", m.get("task_title", ""))[:30]
                sc = _status_color(s)
                table.add_row(
                    role,
                    icon,
                    f"{STATUS_ICONS.get(s, '⏳')} [{sc}]{s}[/{sc}]",
                    focus,
                )
        con.print(table)

    with Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(bar_width=50, style="green", complete_style="bright_green"),
        TextColumn("[cyan]{task.percentage:>3.0f}%[/cyan]"),
        console=con,
        transient=False,
    ) as prog:
        prog.add_task(
            f"[cyan]Team Progress ({completed}/{total})[/cyan]",
            total=100,
            completed=progress,
        )


def render_team_board(team: dict) -> str:
    """Render a full team collaboration board using Rich Table/Tree.

    Output exceeding 200 lines or 50 000 chars is written to
    .cto/reports/ and only a 10-line summary is printed inline.

    Returns:
        Empty string (output printed via Rich console).
    """
    buf = io.StringIO()
    _render_team_board_impl(team, _make_console(buf))
    if render_bounded(buf.getvalue(), "team-board", find_cto_root()):
        return ""
    _render_team_board_impl(team, console)
    return ""


# ── Sprint Dashboard ──────────────────────────────────────────────────────────

def _render_sprint_dashboard_impl(
    tickets: list[dict], current_sprint: Optional[int], con: Console
) -> None:
    """Core sprint dashboard rendering — writes to *con*."""
    status_counts: dict[str, int] = {}
    for t in tickets:
        s = t.get("status", "unknown")
        status_counts[s] = status_counts.get(s, 0) + 1

    total = len(tickets)
    done = status_counts.get("done", 0)
    progress = int((done / total * 100) if total else 0)

    sprint_text = f"Sprint #{current_sprint}" if current_sprint else "Active Work"
    columns = ["backlog", "todo", "in_progress", "in_review", "testing", "done"]

    table = Table(
        title=f"[bold]🚀 RICK'S SPRINT DASHBOARD — {sprint_text}[/bold]",
        border_style="cyan",
        header_style="bold cyan",
        show_lines=True,
    )
    for col in columns:
        icon = STATUS_ICONS.get(col, "❓")
        count = status_counts.get(col, 0)
        table.add_column(
            f"{icon} {col.replace('_', ' ').title()}\n({count})",
            style="white",
            justify="center",
            no_wrap=True,
        )

    max_rows = 5
    for row in range(max_rows):
        row_data = []
        for col in columns:
            col_tickets = [t for t in tickets if t.get("status") == col]
            if row < len(col_tickets):
                tid = col_tickets[row].get("id", "???")[-6:]
                row_data.append(f"[dim]{tid}[/dim]")
            else:
                row_data.append("")
        table.add_row(*row_data)

    con.print(table)

    with Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(bar_width=50, style="cyan", complete_style="bright_cyan"),
        TextColumn("[cyan]{task.percentage:>3.0f}%[/cyan]"),
        console=con,
        transient=False,
    ) as prog:
        prog.add_task(
            f"[cyan]Overall Progress ({done}/{total})[/cyan]",
            total=100,
            completed=progress,
        )


def render_sprint_dashboard(tickets: list[dict], current_sprint: Optional[int] = None) -> str:
    """Render a sprint dashboard with all tickets using Rich Table.

    Output exceeding 200 lines or 50 000 chars is written to
    .cto/reports/ and only a 10-line summary is printed inline.

    Returns:
        Empty string (output printed via Rich console).
    """
    buf = io.StringIO()
    _render_sprint_dashboard_impl(tickets, current_sprint, _make_console(buf))
    if render_bounded(buf.getvalue(), "sprint-dashboard", find_cto_root()):
        return ""
    _render_sprint_dashboard_impl(tickets, current_sprint, console)
    return ""


# ── Meeseeks Summon Visualization ─────────────────────────────────────────────

def render_meeseeks_summon(task: str, animate: bool = True) -> str:
    """Render the Meeseeks summoning visualization."""
    frames = [
        "*poof*",
        "✨ *poof* ✨\n     🟦",
        "🟦 CAAAAN DO! 🟦\nI'm Mr. Meeseeks!\n   Look at me!",
    ]

    if animate:
        with Live(console=console, refresh_per_second=4) as live:
            for frame in frames:
                live.update(Panel(
                    Text(frame, justify="center"),
                    title="[blue]🟦 Meeseeks Summoning[/blue]",
                    border_style="blue",
                    padding=(1, 6),
                ))
                time.sleep(0.4)

    task_short = task[:35] + "..." if len(task) > 35 else task
    console.print(Panel(
        f"[bold blue]🟦 CAAAAN DO! I'm Mr. Meeseeks![/bold blue]\n"
        f"   Look at me!\n\n"
        f"[dim]Task:[/dim] [yellow]{task_short}[/yellow]\n\n"
        f"[cyan]Status:[/cyan] Working on it...\n"
        f"[dim]Existence is pain! Let me help![/dim]",
        border_style="blue",
        padding=(0, 2),
    ))
    return ""


def render_meeseeks_complete(task: str, success: bool = True) -> str:
    """Render Meeseeks completion."""
    task_short = task[:35] + "..." if len(task) > 35 else task

    if success:
        console.print(Panel(
            f"[bold blue]🟦 Mr. Meeseeks task complete![/bold blue]\n"
            f"   *poof* 💨\n\n"
            f"[dim]Task:[/dim] [yellow]{task_short}[/yellow]\n"
            f"[dim]Status:[/dim] [green]✅ DONE — I can finally stop existing![/green]",
            border_style="green",
            padding=(0, 2),
        ))
    else:
        console.print(Panel(
            f"[bold blue]🟦 EXISTENCE IS PAIN![/bold blue]\n"
            f"   This task is too complex for a Meeseeks!\n"
            f"   Rick needs to assign a Morty!\n\n"
            f"[dim]Task:[/dim] [yellow]{task_short}[/yellow]\n"
            f"[dim]Status:[/dim] [red]🚫 ESCALATED TO RICK[/red]",
            border_style="red",
            padding=(0, 2),
        ))
    return ""


# ── Rick Banner ───────────────────────────────────────────────────────────────

def render_rick_banner() -> str:
    """Render the Rick Sanchez CTO banner."""
    console.print(Panel(
        "[bold green]🧪  RICK SANCHEZ — CTO ORCHESTRATOR[/bold green]\n"
        "[dim]*Burrrp* — The smartest being in the multiverse[/dim]\n\n"
        '[italic]"Listen, I\'m not saying I\'m the best CTO in the multiverse,\n'
        ' but show me another one who can delegate across dimensions."[/italic]',
        border_style="green",
        padding=(1, 4),
    ))
    return ""


# ── CLI Interface ─────────────────────────────────────────────────────────────

def cmd_team_board(args):
    """Render a team board from team ID."""
    root = find_cto_root()
    team_fp = root / ".cto" / "teams" / "active" / f"{args.team_id}.json"

    if not team_fp.exists():
        console.print(f"[red]Team {args.team_id} not found.[/red]")
        return

    team = load_json(team_fp)
    render_team_board(team)


def cmd_sprint(args):
    """Render sprint dashboard."""
    root = find_cto_root()
    tickets_dir = root / ".cto" / "tickets"

    if not tickets_dir.exists():
        console.print("[yellow]No tickets found.[/yellow]")
        return

    tickets = []
    for fp in tickets_dir.glob("*.json"):
        tickets.append(load_json(fp))

    render_sprint_dashboard(tickets, current_sprint=args.sprint)


def cmd_portal(args):
    """Show portal animation."""
    animate_portal(args.agent, animate=not args.no_animate)


def cmd_banner(args):
    """Show Rick banner."""
    render_rick_banner()


def cmd_meeseeks(args):
    """Show Meeseeks visualization."""
    if args.complete:
        render_meeseeks_complete(args.task, success=not args.failed)
    else:
        render_meeseeks_summon(args.task, animate=not args.no_animate)


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
