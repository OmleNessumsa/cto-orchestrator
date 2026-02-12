#!/usr/bin/env python3
"""CTO Orchestrator — Session State Management.

*Burrrp* — Listen Morty, even a genius like me needs to remember where we left off.
This module handles session persistence so Rick never loses track of what's happening.

Features:
- SESSION_LOG.md auto-generation per project
- SESSION_STATE.json for active persona/mode tracking
- "Where were we" resume functionality
- Automatic context preservation between sessions
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import argparse


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


def now_human() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def load_json(fp: Path) -> dict:
    if not fp.exists():
        return {}
    with open(fp) as f:
        return json.load(f)


def save_json(fp: Path, data: dict):
    fp.parent.mkdir(parents=True, exist_ok=True)
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


# ── Session State ─────────────────────────────────────────────────────────────

DEFAULT_SESSION_STATE = {
    "active_persona": "rick",
    "persona_intensity": 1.0,  # 0.0-1.0, used for anchor refreshes
    "last_interaction": None,
    "current_focus": None,  # Current task/ticket being worked on
    "context_markers": [],  # Key context points to remember
    "conversation_count": 0,
    "rick_quotes_used": 0,
}


def session_state_path(root: Path) -> Path:
    return root / ".cto" / "session" / "SESSION_STATE.json"


def session_log_path(root: Path) -> Path:
    return root / ".cto" / "session" / "SESSION_LOG.md"


def load_session_state(root: Path) -> dict:
    """Load current session state."""
    fp = session_state_path(root)
    state = load_json(fp)
    # Merge with defaults for any missing keys
    return {**DEFAULT_SESSION_STATE, **state}


def save_session_state(root: Path, state: dict):
    """Save session state."""
    fp = session_state_path(root)
    save_json(fp, state)


def update_session(
    root: Path,
    summary: str,
    focus: Optional[str] = None,
    context_marker: Optional[str] = None,
    decisions: Optional[list[str]] = None,
):
    """Update session state and log.

    Args:
        root: Project root path
        summary: Brief summary of what happened
        focus: Optional current focus/task
        context_marker: Optional key context point to remember
        decisions: Optional list of decisions made
    """
    state = load_session_state(root)

    # Update state
    state["last_interaction"] = now_iso()
    state["conversation_count"] = state.get("conversation_count", 0) + 1

    if focus:
        state["current_focus"] = focus

    if context_marker:
        markers = state.get("context_markers", [])
        markers.append({
            "marker": context_marker,
            "timestamp": now_iso(),
        })
        # Keep last 20 markers
        state["context_markers"] = markers[-20:]

    save_session_state(root, state)

    # Append to session log
    append_to_session_log(root, summary, focus, decisions)


def append_to_session_log(
    root: Path,
    summary: str,
    focus: Optional[str] = None,
    decisions: Optional[list[str]] = None,
):
    """Append an entry to SESSION_LOG.md."""
    fp = session_log_path(root)
    fp.parent.mkdir(parents=True, exist_ok=True)

    # Create file with header if it doesn't exist
    if not fp.exists():
        header = """# Rick's Session Log

*Burrrp* — This is where I keep track of what we've been doing, Morty.
Don't touch it. Actually, read it if you need to catch up.

---

"""
        with open(fp, "w") as f:
            f.write(header)

    # Build entry
    timestamp = now_human()
    entry_lines = [
        f"\n## {timestamp}",
        "",
    ]

    if focus:
        entry_lines.append(f"**Focus**: {focus}")
        entry_lines.append("")

    entry_lines.append(f"**Summary**: {summary}")
    entry_lines.append("")

    if decisions:
        entry_lines.append("**Decisions**:")
        for d in decisions:
            entry_lines.append(f"- {d}")
        entry_lines.append("")

    entry_lines.append("---")

    with open(fp, "a") as f:
        f.write("\n".join(entry_lines) + "\n")


# ── Resume / Context Retrieval ────────────────────────────────────────────────

def get_resume_context(root: Path) -> str:
    """Get a "where were we" context summary for resuming work.

    Returns:
        A formatted string with session context for Rick to resume.
    """
    state = load_session_state(root)

    lines = []
    lines.append("*Burrrp* — Alright, let me remember what we were doing...")
    lines.append("")

    # Last interaction
    if state.get("last_interaction"):
        lines.append(f"**Last session**: {state['last_interaction'][:19].replace('T', ' ')} UTC")

    # Current focus
    if state.get("current_focus"):
        lines.append(f"**We were working on**: {state['current_focus']}")

    # Recent context markers
    markers = state.get("context_markers", [])
    if markers:
        lines.append("")
        lines.append("**Key context points**:")
        for m in markers[-5:]:  # Last 5 markers
            lines.append(f"- {m['marker']}")

    # Conversation stats
    count = state.get("conversation_count", 0)
    if count > 0:
        lines.append("")
        lines.append(f"*We've had {count} interactions this project. I remember everything, Morty.*")

    # Load recent log entries
    recent_entries = get_recent_log_entries(root, count=3)
    if recent_entries:
        lines.append("")
        lines.append("**Recent activity**:")
        lines.append(recent_entries)

    return "\n".join(lines)


def get_recent_log_entries(root: Path, count: int = 3) -> str:
    """Get the last N entries from SESSION_LOG.md."""
    fp = session_log_path(root)
    if not fp.exists():
        return ""

    with open(fp) as f:
        content = f.read()

    # Split by entries (## timestamp)
    import re
    entries = re.split(r'\n(?=## \d{4}-\d{2}-\d{2})', content)

    # Get last N entries (excluding header)
    recent = [e.strip() for e in entries[-count:] if e.strip() and e.strip().startswith("##")]

    return "\n\n".join(recent)


# ── Persona Intensity ─────────────────────────────────────────────────────────

def check_persona_drift(root: Path) -> tuple[bool, float]:
    """Check if the Rick persona might be drifting (needs refresh).

    Returns:
        (needs_refresh, current_intensity)
    """
    state = load_session_state(root)

    # Calculate decay based on conversation count since last refresh
    count = state.get("conversation_count", 0)
    quotes_used = state.get("rick_quotes_used", 0)

    # Persona intensity decays over time
    # Refreshes when quotes are used
    intensity = state.get("persona_intensity", 1.0)

    # Decay: -0.1 per 5 conversations without a quote
    decay = (count - quotes_used) * 0.02
    intensity = max(0.0, intensity - decay)

    # Needs refresh if intensity drops below 0.5
    needs_refresh = intensity < 0.5

    return needs_refresh, intensity


def record_persona_refresh(root: Path):
    """Record that a persona refresh happened (quote used, etc.)."""
    state = load_session_state(root)
    state["persona_intensity"] = 1.0
    state["rick_quotes_used"] = state.get("rick_quotes_used", 0) + 1
    save_session_state(root, state)


# ── CLI Commands ──────────────────────────────────────────────────────────────

def cmd_status(args):
    """Show current session status."""
    root = find_cto_root()
    state = load_session_state(root)

    print("""
╔══════════════════════════════════════════════════════════════╗
║  RICK'S SESSION STATUS                                       ║
╠══════════════════════════════════════════════════════════════╣""")

    # Last interaction
    last = state.get("last_interaction")
    if last:
        last = last[:19].replace("T", " ") + " UTC"
    else:
        last = "Never"
    print(f"║  Last interaction: {last:<40}║")

    # Current focus
    focus = state.get("current_focus") or "None"
    print(f"║  Current focus: {focus[:44]:<44}║")

    # Persona status
    needs_refresh, intensity = check_persona_drift(root)
    status_emoji = "🟢" if intensity > 0.7 else "🟡" if intensity > 0.4 else "🔴"
    print(f"║  Persona intensity: {status_emoji} {intensity:.0%}{'  (needs refresh!)' if needs_refresh else '':<26}║")

    # Stats
    count = state.get("conversation_count", 0)
    print(f"║  Conversation count: {count:<38}║")

    # Recent markers
    markers = state.get("context_markers", [])
    if markers:
        print("╠══════════════════════════════════════════════════════════════╣")
        print("║  CONTEXT MARKERS                                             ║")
        for m in markers[-5:]:
            marker_text = m["marker"][:55]
            print(f"║  • {marker_text:<57}║")

    print("╚══════════════════════════════════════════════════════════════╝")


def cmd_log(args):
    """Add an entry to the session log."""
    root = find_cto_root()

    update_session(
        root,
        summary=args.summary,
        focus=args.focus,
        context_marker=args.marker,
        decisions=args.decisions.split(";") if args.decisions else None,
    )

    print(f"*Burrrp* — Logged it: {args.summary[:50]}...")


def cmd_resume(args):
    """Show resume context for picking up where we left off."""
    root = find_cto_root()
    context = get_resume_context(root)
    print(context)


def cmd_read_log(args):
    """Read the session log."""
    root = find_cto_root()
    fp = session_log_path(root)

    if not fp.exists():
        print("No session log yet. *Burrrp* Nothing to remember.")
        return

    with open(fp) as f:
        content = f.read()

    if args.tail:
        # Show last N entries
        import re
        entries = re.split(r'\n(?=## \d{4}-\d{2}-\d{2})', content)
        recent = entries[-(args.tail + 1):]  # +1 for header
        print("\n---\n".join(recent))
    else:
        print(content)


def cmd_clear(args):
    """Clear session state (fresh start)."""
    root = find_cto_root()

    if not args.force:
        print("Are you sure? This clears all session state. Use --force to confirm.")
        return

    # Clear state
    fp = session_state_path(root)
    if fp.exists():
        fp.unlink()

    # Archive log (don't delete)
    log_fp = session_log_path(root)
    if log_fp.exists():
        archive_name = f"SESSION_LOG_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        archive_fp = log_fp.parent / "archive" / archive_name
        archive_fp.parent.mkdir(parents=True, exist_ok=True)
        log_fp.rename(archive_fp)
        print(f"Log archived to: {archive_fp}")

    print("*Burrrp* — Fresh start. I've forgotten everything. Happy now?")


# ── CLI Parser ────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(
        prog="session",
        description="Rick's Session Management — *burp* I remember everything"
    )
    sub = p.add_subparsers(dest="command", required=True)

    # status
    sub.add_parser("status", help="Show current session status")

    # log
    lg = sub.add_parser("log", help="Add an entry to the session log")
    lg.add_argument("summary", help="What happened")
    lg.add_argument("--focus", help="Current focus/task")
    lg.add_argument("--marker", help="Key context marker to remember")
    lg.add_argument("--decisions", help="Decisions made (semicolon-separated)")

    # resume
    sub.add_parser("resume", help="Get resume context for picking up work")

    # read
    rd = sub.add_parser("read", help="Read the session log")
    rd.add_argument("--tail", type=int, help="Show last N entries")

    # clear
    cl = sub.add_parser("clear", help="Clear session state (fresh start)")
    cl.add_argument("--force", action="store_true", help="Confirm clear")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "status": cmd_status,
        "log": cmd_log,
        "resume": cmd_resume,
        "read": cmd_read_log,
        "clear": cmd_clear,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
