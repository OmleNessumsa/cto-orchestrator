#!/usr/bin/env python3
"""Rick Sanchez Orchestrator — Progress logger and reporting.

Wubba lubba dub dub! Stores daily JSONL logs in .cto/logs/ and generates
summaries/reports. Built by the smartest mammal in the multiverse.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def find_cto_root(start=None) -> Path:
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            print("Error: No .cto/ directory found. Run init_project.sh first.", file=sys.stderr)
            sys.exit(1)
        current = parent


def logs_dir(root: Path) -> Path:
    d = root / ".cto" / "logs"
    d.mkdir(parents=True, exist_ok=True)
    return d


def today_log_file(root: Path) -> Path:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return logs_dir(root) / f"{today}.jsonl"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_log(root: Path, entry: dict):
    fp = today_log_file(root)
    with open(fp, "a") as f:
        f.write(json.dumps(entry) + "\n")


def read_all_logs(root: Path) -> list[dict]:
    ld = logs_dir(root)
    entries = []
    for fp in sorted(ld.glob("*.jsonl")):
        with open(fp) as f:
            for line in f:
                line = line.strip()
                if line:
                    entries.append(json.loads(line))
    return entries


def read_today_logs(root: Path) -> list[dict]:
    fp = today_log_file(root)
    if not fp.exists():
        return []
    entries = []
    with open(fp) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def load_all_tickets(root: Path) -> list[dict]:
    td = root / ".cto" / "tickets"
    if not td.exists():
        return []
    tickets = []
    for fp in sorted(td.glob("*.json")):
        with open(fp) as f:
            tickets.append(json.load(f))
    return tickets


# ── Commands ────────────────────────────────────────────────────────────────


def cmd_log(args):
    root = find_cto_root()
    entry = {
        "timestamp": now_iso(),
        "ticket_id": args.ticket or None,
        "agent": args.agent or "rick",
        "action": args.action or "note",
        "message": args.message,
        "files_changed": [f.strip() for f in args.files.split(",")] if args.files else [],
    }
    append_log(root, entry)
    print(f"*burp* Logged it, Morty: [{entry['action']}] {entry['message']}")


def cmd_summary(args):
    root = find_cto_root()

    if args.full:
        entries = read_all_logs(root)
        label = "Full project"
    else:
        entries = read_today_logs(root)
        label = "Today"

    if not entries:
        print(f"{label}: Nothing happened. *burp* This is somehow even more boring than I expected.")
        return

    tickets = load_all_tickets(root)
    status_counts: dict[str, int] = {}
    for t in tickets:
        s = t["status"]
        status_counts[s] = status_counts.get(s, 0) + 1

    total = len(tickets)
    done = status_counts.get("done", 0)
    pct = (done / total * 100) if total else 0

    print(f"\n{'═' * 60}")
    print(f"  {label} Summary — Listen up, Morty")
    print(f"{'═' * 60}")
    print(f"  Log entries: {len(entries)} (yeah, I counted them all, you're welcome)")
    print(f"  Tickets: {total} total, {done} done ({pct:.0f}%) — infinite universes, finite patience")
    print(f"  Status breakdown: {json.dumps(status_counts)}")

    # action counts
    action_counts: dict[str, int] = {}
    for e in entries:
        a = e.get("action", "unknown")
        action_counts[a] = action_counts.get(a, 0) + 1
    print(f"  Actions (*burp*): {json.dumps(action_counts)}")

    # agent activity
    agent_counts: dict[str, int] = {}
    for e in entries:
        a = e.get("agent", "unknown")
        agent_counts[a] = agent_counts.get(a, 0) + 1
    print(f"  Morty activity: {json.dumps(agent_counts)}")

    # recent entries
    recent = entries[-10:]
    print(f"\n  Recent activity from the Morty's (last {len(recent)}):")
    for e in recent:
        ts = e["timestamp"][:19].replace("T", " ")
        tid = e.get("ticket_id") or "—"
        agent = e.get("agent", "?")
        print(f"    {ts}  [{e['action']:<10}]  {tid:<12}  @{agent:<15}  {e['message'][:60]}")
    print()


def cmd_timeline(args):
    root = find_cto_root()
    entries = read_all_logs(root)
    if not entries:
        print("No log entries. *burp* What have you Morty's even been doing?")
        return

    print(f"\n{'═' * 70}")
    print(f"  Rick's Interdimensional Timeline")
    print(f"{'═' * 70}")
    current_date = None
    for e in entries:
        date = e["timestamp"][:10]
        if date != current_date:
            current_date = date
            print(f"\n  ── {date} {'─' * 50}")
        time = e["timestamp"][11:19]
        tid = e.get("ticket_id") or "—"
        agent = e.get("agent", "?")
        action = e.get("action", "?")
        print(f"    {time}  [{action:<10}]  {tid:<12}  @{agent:<14}  {e['message'][:50]}")
    print()


def cmd_report(args):
    root = find_cto_root()
    entries = read_all_logs(root)
    tickets = load_all_tickets(root)

    total = len(tickets)
    status_counts: dict[str, int] = {}
    for t in tickets:
        s = t["status"]
        status_counts[s] = status_counts.get(s, 0) + 1
    done = status_counts.get("done", 0)
    pct = (done / total * 100) if total else 0

    # Build markdown report
    lines = [
        "# Rick's Project Progress Report",
        "",
        f"**Generated**: {now_iso()[:19].replace('T', ' ')} UTC",
        "",
        "## Summary — The Science, Morty",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Total tickets | {total} |",
        f"| Completed | {done} ({pct:.0f}%) |",
        f"| In progress | {status_counts.get('in_progress', 0)} |",
        f"| Blocked | {status_counts.get('blocked', 0)} |",
        f"| Log entries | {len(entries)} |",
        "",
        "## Ticket Board — What the Morty's Are Up To",
        "",
    ]

    statuses = ["backlog", "todo", "in_progress", "in_review", "testing", "done", "blocked"]
    for s in statuses:
        items = [t for t in tickets if t["status"] == s]
        lines.append(f"### {s.upper().replace('_', ' ')} ({len(items)})")
        if items:
            for t in items:
                agent = f"@{t['assigned_agent']}" if t.get("assigned_agent") else ""
                lines.append(f"- **{t['id']}** {t['title']} {agent}")
        else:
            lines.append("- (none)")
        lines.append("")

    # Blocked details
    blocked = [t for t in tickets if t["status"] == "blocked"]
    if blocked:
        lines.append("## Blocked Items")
        lines.append("")
        for t in blocked:
            note = t.get("review_notes") or "No reason given"
            lines.append(f"- **{t['id']}** {t['title']}: {note}")
        lines.append("")

    # Recent activity
    recent = entries[-20:]
    lines.append("## Recent Morty Activity")
    lines.append("")
    lines.append("| Time | Action | Ticket | Morty | Message |")
    lines.append("|------|--------|--------|-------|---------|")
    for e in recent:
        ts = e["timestamp"][:19].replace("T", " ")
        tid = e.get("ticket_id") or "—"
        agent = e.get("agent", "—")
        msg = e["message"][:50]
        lines.append(f"| {ts} | {e['action']} | {tid} | {agent} | {msg} |")

    report_text = "\n".join(lines)
    print(report_text)

    # Also save to file
    report_path = root / ".cto" / "logs" / f"report-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.md"
    with open(report_path, "w") as f:
        f.write(report_text)
    print(f"\n*burp* Report saved to: {report_path} — Don't say I never do anything for you, Morty.")


# ── CLI ─────────────────────────────────────────────────────────────────────


def build_parser():
    p = argparse.ArgumentParser(prog="progress", description="Rick Sanchez's progress logger — the *burp* smartest CLI in the multiverse")
    sub = p.add_subparsers(dest="command", required=True)

    # log
    lg = sub.add_parser("log", help="Log a progress entry, Morty")
    lg.add_argument("message", help="Description of what happened")
    lg.add_argument("--ticket", default=None, help="Related ticket ID")
    lg.add_argument("--agent", default="rick", help="Which Morty performed the action (default: rick himself)")
    lg.add_argument("--action", default="note", choices=["created", "started", "completed", "reviewed", "blocked", "decision", "note"])
    lg.add_argument("--files", default=None, help="Comma-separated list of changed files")

    # summary
    sm = sub.add_parser("summary", help="Show progress summary — science demands data")
    sm.add_argument("--full", action="store_true", help="Full project summary (not just today)")

    # timeline
    sub.add_parser("timeline", help="Rick's Interdimensional Timeline")

    # report
    sub.add_parser("report", help="Generate Rick's progress report (markdown) — you're welcome")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "log": cmd_log,
        "summary": cmd_summary,
        "timeline": cmd_timeline,
        "report": cmd_report,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
