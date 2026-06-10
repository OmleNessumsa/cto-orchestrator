#!/usr/bin/env python3
"""Background workers — auto-triggered maintenance daemon (lite).

Rick's self-maintaining infrastructure. Wires up maintenance tasks driven by
.cto/workers.json (per-worker interval_hours + last_run). Run via cron or a
sleepy hook.

Commands:
  run     — execute any worker whose interval has elapsed
  list    — show all workers and their status
  enable  — enable a worker
  disable — disable a worker
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from orchestrate import find_cto_root
except ImportError:
    def find_cto_root(start=None) -> Path:
        current = Path(start or os.getcwd()).resolve()
        while True:
            if (current / ".cto").is_dir():
                return current
            parent = current.parent
            if parent == current:
                print("Error: No .cto/ directory found.", file=sys.stderr)
                sys.exit(1)
            current = parent


# ── Workers ──────────────────────────────────────────────────────────────────

def run_stale_ticket_worker(root: Path) -> dict:
    tickets_dir = root / ".cto" / "tickets"
    if not tickets_dir.exists():
        return {"flagged": 0, "checked": 0}

    now = datetime.now(timezone.utc)
    checked = 0
    flagged = 0
    log_lines = []

    for fp in sorted(tickets_dir.glob("*.json")):
        try:
            with open(fp) as f:
                ticket = json.load(f)
        except Exception:
            continue

        if ticket.get("status") != "in_progress":
            continue

        checked += 1
        ts_str = ticket.get("updated_at") or ticket.get("created_at")
        if not ts_str:
            continue

        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            age_hours = (now - ts).total_seconds() / 3600
        except ValueError:
            continue

        if age_hours >= 48:
            flagged += 1
            ticket_id = ticket.get("id", fp.stem)
            title = ticket.get("title", "")[:60]
            log_lines.append(
                f"{now.isoformat()} STALE {ticket_id} {title!r} {age_hours:.1f}h\n"
            )

    if log_lines:
        log_path = root / ".cto" / "logs" / "stale_tickets.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with open(log_path, "a") as f:
            f.writelines(log_lines)

    return {"flagged": flagged, "checked": checked}


def run_persona_drift_worker(root: Path) -> dict:
    persona_script = root / "scripts" / "persona.py"
    try:
        proc = subprocess.run(
            [sys.executable, str(persona_script), "check"],
            capture_output=True,
            timeout=30,
            check=False,
        )
        return {
            "returncode": proc.returncode,
            "stdout": proc.stdout.decode(errors="replace")[:200],
        }
    except subprocess.TimeoutExpired:
        return {"returncode": -1, "stdout": "timeout after 30s"}
    except Exception as exc:
        return {"returncode": -1, "stdout": str(exc)[:200]}


def run_prometheus_idle_worker(root: Path) -> dict:
    prometheus_script = root / "scripts" / "prometheus.py"
    try:
        proc = subprocess.run(
            [sys.executable, str(prometheus_script), "scan"],
            capture_output=True,
            timeout=300,
            check=False,
        )
        return {
            "returncode": proc.returncode,
            "output_tail": proc.stdout.decode(errors="replace")[-300:],
        }
    except subprocess.TimeoutExpired:
        return {"returncode": -1, "output_tail": "timeout after 300s"}
    except Exception as exc:
        return {"returncode": -1, "output_tail": str(exc)[:300]}


WORKER_REGISTRY: dict = {
    "stale_ticket": (run_stale_ticket_worker, 24),
    "persona_drift": (run_persona_drift_worker, 12),
    "prometheus_idle": (run_prometheus_idle_worker, 24),
}


# ── Schedule helpers ──────────────────────────────────────────────────────────

def _schedule_path(root: Path) -> Path:
    return root / ".cto" / "workers.json"


def load_schedule(root: Path) -> dict:
    path = _schedule_path(root)
    if path.exists():
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            pass
    sched = {
        name: {"interval_hours": default, "last_run": None, "enabled": True}
        for name, (_, default) in WORKER_REGISTRY.items()
    }
    save_schedule(root, sched)
    return sched


def save_schedule(root: Path, sched: dict) -> None:
    path = _schedule_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(sched, f, indent=2)


def is_due(entry: dict) -> bool:
    if not entry.get("enabled", True):
        return False
    if entry.get("last_run") is None:
        return True
    try:
        parsed = datetime.fromisoformat(entry["last_run"].replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        elapsed_h = (datetime.now(timezone.utc) - parsed).total_seconds() / 3600
        return elapsed_h >= entry["interval_hours"]
    except (ValueError, KeyError):
        return True


def hours_until_next(entry: dict) -> float:
    if entry.get("last_run") is None:
        return 0.0
    try:
        parsed = datetime.fromisoformat(entry["last_run"].replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        elapsed_h = (datetime.now(timezone.utc) - parsed).total_seconds() / 3600
        return max(0.0, entry["interval_hours"] - elapsed_h)
    except (ValueError, KeyError):
        return 0.0


# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_run(args) -> None:
    root = find_cto_root()
    sched = load_schedule(root)
    ran = 0
    total = 0

    for name, entry in sched.items():
        if name not in WORKER_REGISTRY:
            continue
        if args.worker and args.worker != name:
            continue
        total += 1

        if not is_due(entry):
            remaining = hours_until_next(entry)
            print(f"  {name}: skip (next in {remaining:.1f}h)")
            continue

        fn, _ = WORKER_REGISTRY[name]
        print(f"  {name}: running...")
        try:
            result = fn(root)
        except Exception as exc:
            result = {"error": str(exc)[:200]}

        entry["last_run"] = datetime.now(timezone.utc).isoformat()
        entry["last_result"] = str(result)[:200]
        save_schedule(root, sched)
        print(f"  {name}: done -> {result}")
        ran += 1

    print(f"\n{ran}/{total} workers ran.")


def cmd_list(args) -> None:
    root = find_cto_root()
    sched = load_schedule(root)

    col_w = [20, 10, 28, 6, 40]
    header = (
        f"{'NAME':<{col_w[0]}} {'INTERVAL':>{col_w[1]}} "
        f"{'LAST_RUN':<{col_w[2]}} {'DUE?':<{col_w[3]}} LAST_RESULT"
    )
    print(header)
    print("-" * (sum(col_w) + 4))

    for name, entry in sched.items():
        interval = f"{entry.get('interval_hours', '?')}h"
        last_run = entry.get("last_run") or "never"
        due = "yes" if is_due(entry) else "no"
        last_result = (entry.get("last_result") or "")[:40]
        if not entry.get("enabled", True):
            due = "off"
        print(
            f"{name:<{col_w[0]}} {interval:>{col_w[1]}} "
            f"{last_run:<{col_w[2]}} {due:<{col_w[3]}} {last_result}"
        )


def cmd_enable(args) -> None:
    root = find_cto_root()
    sched = load_schedule(root)
    if args.worker not in sched:
        print(f"Unknown worker: {args.worker}", file=sys.stderr)
        sys.exit(1)
    sched[args.worker]["enabled"] = True
    save_schedule(root, sched)
    print(f"  {args.worker}: enabled")


def cmd_disable(args) -> None:
    root = find_cto_root()
    sched = load_schedule(root)
    if args.worker not in sched:
        print(f"Unknown worker: {args.worker}", file=sys.stderr)
        sys.exit(1)
    sched[args.worker]["enabled"] = False
    save_schedule(root, sched)
    print(f"  {args.worker}: disabled")


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Background workers — auto-triggered maintenance daemon"
    )
    sub = parser.add_subparsers(dest="command")
    sub.required = True

    p_run = sub.add_parser("run", help="Run due workers")
    p_run.add_argument("--worker", metavar="NAME", help="Run a single worker by name")
    p_run.set_defaults(func=cmd_run)

    p_list = sub.add_parser("list", help="List workers and their status")
    p_list.set_defaults(func=cmd_list)

    p_enable = sub.add_parser("enable", help="Enable a worker")
    p_enable.add_argument("worker", metavar="NAME")
    p_enable.set_defaults(func=cmd_enable)

    p_disable = sub.add_parser("disable", help="Disable a worker")
    p_disable.add_argument("worker", metavar="NAME")
    p_disable.set_defaults(func=cmd_disable)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
