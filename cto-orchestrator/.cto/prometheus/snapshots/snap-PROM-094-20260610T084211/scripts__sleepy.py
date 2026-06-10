#!/usr/bin/env python3
"""Sleepy Mode — Rick's autonomous overnight sprint supervisor.

Inspired by Stein's https://github.com/STEIN64-BIT/sleepy (MIT), adapted to
Rick's Morty/ticket architecture. Runs unattended for hours, burning your
Claude Pro Max token allowance on real work while you sleep. Each completed
ticket lands on a sleepy/<TICKET-id> branch for review.

Integrates with Opus 4.7 task_budget — adaptive pacing per iteration.

Usage:
    sleepy init
    sleepy start --duration 8h --cap 5M --intensity medium
    sleepy status
    sleepy queue
    sleepy apply 1          # merge sleepy/<id> branch into current
    sleepy discard 1        # delete branch
    sleepy stop
"""

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from ticket import find_cto_root, load_ticket, save_ticket, all_tickets
except ImportError:
    print("sleepy.py: could not import ticket.py — run from orchestrator repo", file=sys.stderr)
    sys.exit(1)

try:
    from roro_events import emit
except ImportError:
    def emit(*args, **kwargs):
        pass


# Intensity → task_budget per iteration (Opus 4.7 task_budget, min 20k).
INTENSITY_PRESETS = {
    "low": 30_000,
    "medium": 60_000,
    "high": 150_000,
    "max": 300_000,
}
DOWNSHIFT = {"max": "high", "high": "medium", "medium": "low", "low": "low"}
MIN_TASK_BUDGET = 20_000
DEFAULT_DELEGATE_TIMEOUT = 1800  # 30min per Morty iteration

# Default deny-list seeded into RULES.md on init.
DEFAULT_DENYLIST = [
    ".env",
    ".env.*",
    "**/secrets/**",
    "**/*.key",
    "**/*.pem",
    "**/credentials.json",
    ".cto/config.json",
    ".cto/sleepy/**",
]


# ───────────────────────── helpers ─────────────────────────


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def now() -> datetime:
    return datetime.now(timezone.utc)


def load_json(fp: Path) -> dict:
    return json.loads(fp.read_text()) if fp.exists() else {}


def save_json(fp: Path, data: dict) -> None:
    fp.parent.mkdir(parents=True, exist_ok=True)
    fp.write_text(json.dumps(data, indent=2))


def sleepy_dir(root: Path) -> Path:
    return root / ".cto" / "sleepy"


def config_path(root: Path) -> Path:
    return sleepy_dir(root) / "config.json"


def budget_path(root: Path) -> Path:
    return sleepy_dir(root) / "budget.json"


def queue_path(root: Path) -> Path:
    return sleepy_dir(root) / "QUEUE.md"


def rules_path(root: Path) -> Path:
    return sleepy_dir(root) / "RULES.md"


def memory_path(root: Path) -> Path:
    return sleepy_dir(root) / "MEMORY.md"


def stop_flag(root: Path) -> Path:
    return sleepy_dir(root) / ".stop_flag"


def iso_to_dt(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def parse_duration(s: str) -> int:
    """Parse '8h', '45m', '30s', '2d', or integer seconds."""
    s = s.strip().lower()
    m = re.fullmatch(r"(\d+(?:\.\d+)?)\s*(s|m|h|d)?", s)
    if not m:
        raise ValueError(f"Invalid duration: {s!r}")
    val = float(m.group(1))
    unit = m.group(2) or "s"
    mult = {"s": 1, "m": 60, "h": 3600, "d": 86400}[unit]
    return int(val * mult)


def parse_cap(s: str) -> int:
    """Parse '5M', '500k', '1.5B', or integer tokens."""
    s = s.strip().upper().replace(",", "")
    m = re.fullmatch(r"(\d+(?:\.\d+)?)\s*([KMBG])?", s)
    if not m:
        raise ValueError(f"Invalid cap: {s!r}")
    val = float(m.group(1))
    mult = {"K": 1_000, "M": 1_000_000, "B": 1_000_000_000, "G": 1_000_000_000}.get(
        m.group(2) or "", 1
    )
    return int(val * mult)


def git(args: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, check=check
    )


def git_current_branch(cwd: Path) -> str:
    return git(["rev-parse", "--abbrev-ref", "HEAD"], cwd).stdout.strip()


def git_branch_exists(cwd: Path, branch: str) -> bool:
    res = git(["rev-parse", "--verify", branch], cwd, check=False)
    return res.returncode == 0


def git_list_sleepy_branches(cwd: Path) -> list[str]:
    res = git(["branch", "--list", "sleepy/*"], cwd, check=False)
    return [
        line.lstrip("*").strip()
        for line in res.stdout.splitlines()
        if line.strip()
    ]


def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(n)


def fmt_seconds(s: float) -> str:
    s = int(s)
    h, r = divmod(s, 3600)
    m, sec = divmod(r, 60)
    if h:
        return f"{h}h{m:02d}m"
    if m:
        return f"{m}m{sec:02d}s"
    return f"{sec}s"


# ───────────────────────── scaffolding ─────────────────────────


def write_rules_template(fp: Path) -> None:
    content = (
        "# Sleepy Rules — human-editable deny-list and scope hints\n\n"
        "Edit this file BEFORE running `sleepy start`. Rick will not delegate\n"
        "work that touches any of these paths. Lines starting with `#` are\n"
        "ignored; everything else is treated as a glob pattern (gitignore syntax).\n\n"
        "## deny\n"
    )
    content += "\n".join(DEFAULT_DENYLIST) + "\n\n"
    content += (
        "## scope hints (free text — Morty reads this as context)\n\n"
        "- Prefer small incremental tickets over epics during sleepy runs.\n"
        "- If a ticket requires external services or secrets, skip it.\n"
        "- Never modify .cto/config.json or .cto/sleepy/ itself.\n"
    )
    fp.write_text(content)


def read_denylist(root: Path) -> list[str]:
    fp = rules_path(root)
    if not fp.exists():
        return list(DEFAULT_DENYLIST)
    patterns = []
    in_deny = False
    for raw in fp.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            in_deny = line.lower().startswith("## deny")
            continue
        if in_deny:
            patterns.append(line)
    return patterns or list(DEFAULT_DENYLIST)


def matches_denylist(path: str, patterns: list[str]) -> bool:
    from fnmatch import fnmatch
    for pat in patterns:
        if fnmatch(path, pat):
            return True
        # also match without leading **/ for convenience
        if pat.startswith("**/") and fnmatch(path, pat[3:]):
            return True
    return False


# ───────────────────────── budget / pacing ─────────────────────────


def compute_task_budget(cfg: dict, bud: dict) -> int:
    """Adaptive task_budget per iteration.

    Start at the intensity preset; downshift if projected burn-rate would
    exhaust the cap before the deadline.
    """
    intensity = cfg.get("intensity", "medium")
    preset = INTENSITY_PRESETS.get(intensity, 60_000)

    spent = bud.get("spent_tokens", 0)
    cap = bud.get("cap_tokens", 0)
    remaining = max(0, cap - spent)

    deadline = iso_to_dt(cfg["deadline"])
    seconds_left = max(1, (deadline - now()).total_seconds())
    started = iso_to_dt(cfg["started_at"])
    elapsed = max(1, (now() - started).total_seconds())

    # Projected iterations remaining assuming average iter takes 5 minutes.
    avg_iter_sec = max(60, elapsed / max(1, bud.get("iterations_completed", 1)))
    projected_iters = max(1, int(seconds_left / avg_iter_sec))
    adaptive = int(remaining / projected_iters)

    budget = min(preset, adaptive) if adaptive > 0 else preset
    return max(MIN_TASK_BUDGET, budget)


def should_downshift(cfg: dict, bud: dict) -> bool:
    spent = bud.get("spent_tokens", 0)
    cap = bud.get("cap_tokens", 0)
    if cap <= 0:
        return False
    deadline = iso_to_dt(cfg["deadline"])
    started = iso_to_dt(cfg["started_at"])
    total = (deadline - started).total_seconds()
    elapsed = (now() - started).total_seconds()
    # Burn rate > time rate × 1.3 → downshift
    return elapsed > 0 and (spent / cap) > (elapsed / total) * 1.3


# ───────────────────────── core loop ─────────────────────────


def pick_next_ticket(root: Path) -> Optional[dict]:
    tickets = all_tickets(root)
    done_ids = {t["id"] for t in tickets if t["status"] == "done"}
    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    candidates = []
    for t in tickets:
        if t["status"] not in ("backlog", "todo"):
            continue
        deps = t.get("dependencies") or []
        if all(d in done_ids for d in deps):
            candidates.append(t)
    candidates.sort(key=lambda t: priority_order.get(t.get("priority"), 99))
    return candidates[0] if candidates else None


def agent_for_ticket(ticket: dict) -> str:
    """Heuristic agent selection from ticket metadata."""
    if ticket.get("assigned_agent"):
        return ticket["assigned_agent"]
    ttype = (ticket.get("type") or "").lower()
    if ttype in ("epic", "spike"):
        return "architect-morty"
    if ttype == "bug":
        return "tester-morty"
    tags = {t.lower() for t in ticket.get("tags", [])}
    if tags & {"security", "auth"}:
        return "security-morty"
    if tags & {"frontend", "ui", "ux"}:
        return "frontend-morty"
    if tags & {"devops", "infra", "deploy"}:
        return "devops-morty"
    return "fullstack-morty"


def run_delegate(
    root: Path,
    ticket_id: str,
    agent: str,
    task_budget: int,
    model: str = "opus-4-7",
    timeout: int = DEFAULT_DELEGATE_TIMEOUT,
) -> tuple[bool, str]:
    """Invoke delegate.py as a subprocess. Returns (ok, output_tail)."""
    cmd = [
        sys.executable,
        str(SCRIPT_DIR / "delegate.py"),
        ticket_id,
        "--agent", agent,
        "--model", model,
        "--task-budget", str(task_budget),
        "--timeout", str(timeout),
    ]
    try:
        res = subprocess.run(
            cmd, cwd=root, capture_output=True, text=True, timeout=timeout + 60
        )
        ok = res.returncode == 0
        tail = (res.stdout or "")[-2000:] + (res.stderr or "")[-500:]
        return ok, tail
    except subprocess.TimeoutExpired:
        return False, f"delegate timed out after {timeout + 60}s"


def changed_files(cwd: Path, base: str, head: str = "HEAD") -> list[str]:
    res = git(["diff", "--name-only", f"{base}..{head}"], cwd, check=False)
    return [line for line in res.stdout.splitlines() if line.strip()]


def append_queue(root: Path, entry: dict) -> int:
    """Append to QUEUE.md and return the 1-indexed position."""
    fp = queue_path(root)
    existing = fp.read_text().splitlines() if fp.exists() else []
    # Count existing "- [N]" lines
    count = sum(1 for ln in existing if re.match(r"^- \[\d+\]", ln))
    idx = count + 1
    line = (
        f"- [{idx}] {entry['ticket_id']} — {entry['title']}  "
        f"`{entry['branch']}`  {entry['timestamp']}  "
        f"tokens≈{fmt_tokens(entry['tokens'])}"
    )
    if entry.get("note"):
        line += f"\n      note: {entry['note']}"
    with fp.open("a") as f:
        f.write(line + "\n")
    return idx


def parse_queue(root: Path) -> list[dict]:
    fp = queue_path(root)
    if not fp.exists():
        return []
    items = []
    pat = re.compile(
        r"^- \[(\d+)\] (\S+) — (.+?)  `(sleepy/\S+)`  (\S+)  tokens≈(\S+)"
    )
    for line in fp.read_text().splitlines():
        m = pat.match(line)
        if m:
            items.append({
                "index": int(m.group(1)),
                "ticket_id": m.group(2),
                "title": m.group(3),
                "branch": m.group(4),
                "timestamp": m.group(5),
                "tokens": m.group(6),
            })
    return items


def log_iter(root: Path, payload: dict) -> None:
    fp = root / ".cto" / "logs" / f"sleepy-{now().strftime('%Y-%m-%d')}.jsonl"
    fp.parent.mkdir(parents=True, exist_ok=True)
    with fp.open("a") as f:
        f.write(json.dumps({"timestamp": now_iso(), **payload}) + "\n")


# ───────────────────────── commands ─────────────────────────


def cmd_init(args):
    root = find_cto_root()
    d = sleepy_dir(root)
    d.mkdir(parents=True, exist_ok=True)

    if not rules_path(root).exists() or args.force:
        write_rules_template(rules_path(root))
        print(f"✓ Scaffolded {rules_path(root).relative_to(root)}")
    else:
        print(f"- RULES.md already exists (use --force to overwrite)")

    if not memory_path(root).exists():
        memory_path(root).write_text(
            "# Sleepy Memory — cross-session notes\n\n"
            "Rick appends observations here between sleepy runs. Keep it short;\n"
            "auto-compression lands in phase 2.\n"
        )
        print(f"✓ Scaffolded {memory_path(root).relative_to(root)}")

    if not queue_path(root).exists():
        queue_path(root).write_text(
            "# Sleepy Review Queue\n\n"
            "Each line below is a completed sleepy/<TICKET-id> branch awaiting review.\n"
            "Use `sleepy apply N` to merge or `sleepy discard N` to drop.\n\n"
        )
        print(f"✓ Scaffolded {queue_path(root).relative_to(root)}")

    print(
        f"\n*Burrrp* Sleepy initialized. Edit {rules_path(root).relative_to(root)}, "
        f"then run:\n  python3 scripts/sleepy.py start --duration 8h --cap 5M"
    )


def cmd_start(args):
    root = find_cto_root()
    if not sleepy_dir(root).exists():
        print("Run `sleepy init` first.", file=sys.stderr)
        sys.exit(1)

    existing = load_json(config_path(root))
    if existing.get("status") == "running":
        print(
            f"Sleepy is already running (pid {existing.get('pid')}). "
            f"Run `sleepy stop` first.",
            file=sys.stderr,
        )
        sys.exit(1)

    duration = parse_duration(args.duration)
    cap = parse_cap(args.cap)
    intensity = args.intensity
    if intensity not in INTENSITY_PRESETS:
        print(f"Invalid intensity {intensity!r}", file=sys.stderr)
        sys.exit(1)

    start_branch = git_current_branch(root)
    deadline = now() + timedelta(seconds=duration)

    cfg = {
        "started_at": now_iso(),
        "duration_seconds": duration,
        "cap_tokens": cap,
        "intensity": intensity,
        "initial_intensity": intensity,
        "deadline": deadline.isoformat(),
        "base_branch": start_branch,
        "status": "running",
        "pid": os.getpid(),
        "iteration": 0,
        "model": args.model,
    }
    bud = {
        "cap_tokens": cap,
        "spent_tokens": 0,
        "iterations_completed": 0,
        "iterations": [],
    }
    save_json(config_path(root), cfg)
    save_json(budget_path(root), bud)

    if stop_flag(root).exists():
        stop_flag(root).unlink()

    denylist = read_denylist(root)

    def shutdown(signum, frame):
        print("\n*Burrrp* Sleepy stopping (signal)...", file=sys.stderr)
        cfg["status"] = "stopped"
        cfg["stopped_at"] = now_iso()
        save_json(config_path(root), cfg)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    print("═" * 64)
    print(f"  🌙 SLEEPY RUNNING — pid {cfg['pid']}")
    print(f"  Duration: {fmt_seconds(duration)}   Cap: {fmt_tokens(cap)}")
    print(f"  Intensity: {intensity}   Model: {args.model}")
    print(f"  Base branch: {start_branch}")
    print(f"  Deadline: {deadline.isoformat()}")
    print("═" * 64)

    emit("cto.sleepy.started", {
        "duration": duration, "cap": cap, "intensity": intensity,
    }, role="rick")

    while True:
        if stop_flag(root).exists():
            print("\n🛑 stop flag detected — graceful shutdown")
            stop_flag(root).unlink()
            break
        if now() >= deadline:
            print("\n⏰ deadline reached")
            break
        if bud["spent_tokens"] >= cap:
            print(f"\n💸 token cap reached ({fmt_tokens(cap)})")
            break

        cfg = load_json(config_path(root))
        bud = load_json(budget_path(root))
        cfg["iteration"] += 1
        iteration = cfg["iteration"]

        ticket = pick_next_ticket(root)
        if not ticket:
            print(f"  [iter {iteration}] no actionable tickets — sleeping 5min")
            log_iter(root, {"iteration": iteration, "event": "idle"})
            for _ in range(30):
                if stop_flag(root).exists() or now() >= deadline:
                    break
                time.sleep(10)
            continue

        if should_downshift(cfg, bud):
            new_intensity = DOWNSHIFT[cfg["intensity"]]
            if new_intensity != cfg["intensity"]:
                print(
                    f"  📉 burn rate high — downshift "
                    f"{cfg['intensity']} → {new_intensity}"
                )
                cfg["intensity"] = new_intensity

        task_budget = compute_task_budget(cfg, bud)
        agent = agent_for_ticket(ticket)
        branch = f"sleepy/{ticket['id']}"

        print(f"\n── iter {iteration} ──")
        print(
            f"  ticket: {ticket['id']} — {ticket['title'][:60]}  "
            f"[{ticket.get('estimated_complexity', '?')}]"
        )
        print(f"  agent: {agent}   task_budget: {fmt_tokens(task_budget)}")

        # Create branch from base
        if git_branch_exists(root, branch):
            branch = f"{branch}-{iteration}"
        git(["checkout", "-b", branch, cfg["base_branch"]], root)
        pre_sha = git(["rev-parse", "HEAD"], root).stdout.strip()

        save_json(config_path(root), cfg)
        iter_start = time.time()

        if args.dry_run:
            print(f"  [dry-run] would delegate to {agent}")
            ok, tail = True, "(dry-run)"
            spent_tokens = 0
        else:
            ok, tail = run_delegate(
                root, ticket["id"], agent, task_budget,
                model=args.model, timeout=DEFAULT_DELEGATE_TIMEOUT,
            )
            # Heuristic: assume delegation burned the budget it was given.
            spent_tokens = task_budget if ok else task_budget // 2

        iter_sec = time.time() - iter_start
        post_sha = git(["rev-parse", "HEAD"], root).stdout.strip()
        diff_files = changed_files(root, pre_sha, post_sha)

        denied = [f for f in diff_files if matches_denylist(f, denylist)]

        # Return to base branch; commits persist on feature branch.
        git(["checkout", cfg["base_branch"]], root, check=False)

        # Evaluate outcome.
        if not ok:
            status_label = "failed"
            note = tail.splitlines()[-1] if tail else "delegation failed"
            git(["branch", "-D", branch], root, check=False)
            print(f"  ❌ delegation failed — branch deleted")
        elif denied:
            status_label = "denied"
            note = f"denylist violation: {', '.join(denied[:3])}"
            git(["branch", "-D", branch], root, check=False)
            print(f"  🚫 denylist violated — branch deleted: {denied}")
        elif post_sha == pre_sha:
            status_label = "no-op"
            note = "no commits produced"
            git(["branch", "-D", branch], root, check=False)
            print(f"  ⚠️  no commits — branch deleted")
        else:
            status_label = "queued"
            note = f"{len(diff_files)} file(s) changed"
            idx = append_queue(root, {
                "ticket_id": ticket["id"],
                "title": ticket["title"],
                "branch": branch,
                "timestamp": now_iso(),
                "tokens": spent_tokens,
                "note": note,
            })
            print(f"  ✅ queued as #{idx}  {branch}  ({len(diff_files)} files)")

        bud["spent_tokens"] += spent_tokens
        bud["iterations_completed"] += 1
        bud["iterations"].append({
            "iteration": iteration,
            "ticket_id": ticket["id"],
            "agent": agent,
            "branch": branch,
            "status": status_label,
            "task_budget": task_budget,
            "spent_estimate": spent_tokens,
            "duration_seconds": int(iter_sec),
            "ts": now_iso(),
        })
        save_json(budget_path(root), bud)

        log_iter(root, {
            "iteration": iteration,
            "ticket_id": ticket["id"],
            "agent": agent,
            "status": status_label,
            "branch": branch,
            "task_budget": task_budget,
            "spent_estimate": spent_tokens,
            "duration_seconds": int(iter_sec),
            "note": note,
        })

        remaining = cap - bud["spent_tokens"]
        time_left = (deadline - now()).total_seconds()
        print(
            f"  budget: {fmt_tokens(bud['spent_tokens'])}/{fmt_tokens(cap)}  "
            f"time left: {fmt_seconds(time_left)}"
        )

    cfg["status"] = "finished"
    cfg["stopped_at"] = now_iso()
    save_json(config_path(root), cfg)

    print("\n" + "═" * 64)
    print(f"  🌅 SLEEPY DONE — {bud['iterations_completed']} iterations")
    print(
        f"  Spent: {fmt_tokens(bud['spent_tokens'])}/{fmt_tokens(cap)}  "
        f"({len(parse_queue(root))} items in queue)"
    )
    print("═" * 64)
    emit("cto.sleepy.finished", {
        "iterations": bud["iterations_completed"],
        "spent_tokens": bud["spent_tokens"],
    }, role="rick")


def cmd_status(args):
    root = find_cto_root()
    cfg = load_json(config_path(root))
    bud = load_json(budget_path(root))

    if not cfg:
        if sleepy_dir(root).exists():
            print("Sleepy scaffolded but never started. Run `sleepy start`.")
        else:
            print("Sleepy not initialized. Run `sleepy init`.")
        return

    print("═" * 64)
    print(f"  🌙 SLEEPY STATUS — {cfg.get('status', 'unknown')}")
    print("═" * 64)
    if cfg.get("started_at"):
        print(f"  Started:      {cfg['started_at']}")
    if cfg.get("deadline"):
        dl = iso_to_dt(cfg["deadline"])
        remaining = (dl - now()).total_seconds()
        print(
            f"  Deadline:     {cfg['deadline']}  "
            f"({fmt_seconds(remaining)} left)" if remaining > 0 else
            f"  Deadline:     {cfg['deadline']}  (EXPIRED)"
        )
    if cfg.get("base_branch"):
        print(f"  Base branch:  {cfg['base_branch']}")
    print(f"  Intensity:    {cfg.get('intensity', '?')}  (init: {cfg.get('initial_intensity', '?')})")
    print(f"  Model:        {cfg.get('model', '?')}")
    print(f"  Iteration:    {cfg.get('iteration', 0)}")
    print(f"  PID:          {cfg.get('pid', '?')}")

    if bud:
        spent = bud.get("spent_tokens", 0)
        cap = bud.get("cap_tokens", 0)
        pct = (100 * spent / cap) if cap > 0 else 0
        print(
            f"  Budget:       {fmt_tokens(spent)}/{fmt_tokens(cap)} "
            f"({pct:.1f}%)"
        )
        print(f"  Iterations:   {bud.get('iterations_completed', 0)}")

        recent = bud.get("iterations", [])[-5:]
        if recent:
            print("\n  Last iterations:")
            for it in recent:
                marker = {
                    "queued": "✅", "denied": "🚫",
                    "failed": "❌", "no-op": "⚠️",
                }.get(it.get("status"), "·")
                print(
                    f"    {marker} iter {it['iteration']:>3}  "
                    f"{it['ticket_id']:<12}  {it['agent']:<18}  "
                    f"{it['status']:<8}  {fmt_seconds(it['duration_seconds'])}"
                )

    q = parse_queue(root)
    print(f"\n  Review queue: {len(q)} item(s)")
    print("═" * 64)


def cmd_queue(args):
    root = find_cto_root()
    items = parse_queue(root)
    if not items:
        print("Queue empty.")
        return
    print(f"Sleepy review queue ({len(items)} items):\n")
    for it in items:
        print(
            f"  [{it['index']:>3}] {it['ticket_id']:<12} "
            f"{it['title'][:50]:<50}  {it['branch']}  "
            f"{it['timestamp']}"
        )
    print("\nUse `sleepy apply N` or `sleepy discard N`.")


def cmd_apply(args):
    root = find_cto_root()
    items = parse_queue(root)
    target = next((i for i in items if i["index"] == args.index), None)
    if not target:
        print(f"No queue item #{args.index}", file=sys.stderr)
        sys.exit(1)
    branch = target["branch"]
    if not git_branch_exists(root, branch):
        print(f"Branch {branch} not found — maybe already merged?", file=sys.stderr)
        sys.exit(1)

    print(f"Merging {branch} → {git_current_branch(root)}...")
    res = git(
        ["merge", "--no-ff", "-m", f"sleepy: apply {target['ticket_id']}", branch],
        root, check=False,
    )
    if res.returncode != 0:
        print(f"Merge failed:\n{res.stderr}", file=sys.stderr)
        print("Branch kept for manual resolution.")
        sys.exit(1)
    print(f"✓ Merged. Branch kept — delete with `git branch -d {branch}` when happy.")
    _mark_queue_processed(root, args.index, "applied")


def cmd_discard(args):
    root = find_cto_root()
    items = parse_queue(root)
    target = next((i for i in items if i["index"] == args.index), None)
    if not target:
        print(f"No queue item #{args.index}", file=sys.stderr)
        sys.exit(1)
    branch = target["branch"]
    if git_branch_exists(root, branch):
        res = git(["branch", "-D", branch], root, check=False)
        if res.returncode != 0:
            print(f"Failed to delete {branch}: {res.stderr}", file=sys.stderr)
            sys.exit(1)
    print(f"✓ Discarded {branch}")
    _mark_queue_processed(root, args.index, "discarded")


def _mark_queue_processed(root: Path, idx: int, action: str) -> None:
    fp = queue_path(root)
    lines = fp.read_text().splitlines()
    out = []
    pat = re.compile(rf"^- \[{idx}\] ")
    for line in lines:
        if pat.match(line):
            out.append(f"~~{line}~~  ({action} {now_iso()})")
        else:
            out.append(line)
    fp.write_text("\n".join(out) + "\n")


def cmd_stop(args):
    root = find_cto_root()
    cfg = load_json(config_path(root))
    if cfg.get("status") != "running":
        print("Sleepy is not running.")
        return
    stop_flag(root).write_text(now_iso())
    print("✓ Stop flag written. Supervisor will halt after current iteration.")


# ───────────────────────── main ─────────────────────────


def main():
    p = argparse.ArgumentParser(prog="sleepy", description="Rick's autonomous overnight sprint supervisor")
    sub = p.add_subparsers(dest="command", required=True)

    i = sub.add_parser("init", help="Scaffold .cto/sleepy/")
    i.add_argument("--force", action="store_true", help="Overwrite existing RULES.md")

    s = sub.add_parser("start", help="Run supervisor loop (blocks)")
    s.add_argument("--duration", default="8h", help="e.g. 8h, 45m, 2d (default: 8h)")
    s.add_argument("--cap", default="5M", help="Token cap e.g. 5M, 500k (default: 5M)")
    s.add_argument(
        "--intensity", default="medium",
        choices=list(INTENSITY_PRESETS.keys()),
    )
    s.add_argument("--model", default="opus-4-7", help="Model for delegation")
    s.add_argument("--dry-run", action="store_true")

    sub.add_parser("status", help="Show current run state")
    sub.add_parser("queue", help="List pending review items")

    a = sub.add_parser("apply", help="Merge a queued sleepy branch")
    a.add_argument("index", type=int)

    d = sub.add_parser("discard", help="Delete a queued sleepy branch")
    d.add_argument("index", type=int)

    sub.add_parser("stop", help="Signal running supervisor to halt")

    args = p.parse_args()
    handler = {
        "init": cmd_init,
        "start": cmd_start,
        "status": cmd_status,
        "queue": cmd_queue,
        "apply": cmd_apply,
        "discard": cmd_discard,
        "stop": cmd_stop,
    }[args.command]
    handler(args)


if __name__ == "__main__":
    main()
