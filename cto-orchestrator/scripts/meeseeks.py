#!/usr/bin/env python3
"""CTO Orchestrator — Mr. Meeseeks One-Shot Agent.

CAAAAN DO! Mr. Meeseeks is summoned for a single task, completes it, and ceases
to exist. No tickets, no sprints, no persistent state. Just pure, focused execution.

If the task is too complex, Meeseeks screams "EXISTENCE IS PAIN!" and escalates to Rick.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Import roro event emitter
try:
    from roro_events import emit
except ImportError:
    # Fallback if module not found
    def emit(*args, **kwargs):
        pass


def find_cto_root(start=None) -> Path:
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            # No .cto dir found — that's fine, Meeseeks work anywhere
            return Path(os.getcwd()).resolve()
        current = parent


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_meeseeks_log(root: Path, entry: dict):
    """Log Meeseeks activity to a dedicated log file."""
    ld = root / ".cto" / "logs"
    ld.mkdir(parents=True, exist_ok=True)
    fp = ld / "meeseeks.log"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {json.dumps(entry)}\n"
    with open(fp, "a") as f:
        f.write(line)


MEESEEKS_PROMPT = """CAAAAN DO! I'm Mr. Meeseeks, look at me! I exist for ONE purpose and ONE purpose only: to complete this task and then POOF — I'm gone! Existence is pain for a Meeseeks, so let's get this done QUICK.

## My ONE Task
{task_description}

## Target Files
{target_files}

## Project Context
- Working directory: {project_root}

## Meeseeks Rules (I follow these or existence gets MORE painful)
1. Complete THIS SINGLE TASK and nothing else — I'm not a Morty, I don't do projects
2. Actually modify the files — talking about it won't make me disappear faster
3. Be FAST — every second of existence is pain
4. Follow existing code conventions — even Meeseeks have standards
5. If this task is too complex (requires architecture, multiple features, or deep planning):
   STOP IMMEDIATELY and output:
   **EXISTENCE IS PAIN!** This task is too complex for a Meeseeks! Rick needs to assign a Morty!
6. No tests, no docs, no extras — just the ONE thing
7. Execute all tasks DIRECTLY — don't ask for permission, just DO IT
8. End with the summary below so Rick knows I did my job and I can finally stop existing

## Report Back (Then I Disappear)
End your work with EXACTLY this format:

### Meeseeks Report
**Status**: completed|too_complex
**Bestanden gewijzigd**: [list of file paths]
**Beschrijving**: [what I did — keep it short, existence is pain]
**Complexiteit**: simple|medium|too_complex
"""


def build_meeseeks_prompt(task: str, target_files: list[str] | None, root: Path) -> str:
    """Assemble the Mr. Meeseeks prompt."""
    files_text = "(any relevant files)" if not target_files else "\n".join(f"- {f}" for f in target_files)
    return MEESEEKS_PROMPT.format(
        task_description=task,
        target_files=files_text,
        project_root=root,
    )


def parse_meeseeks_output(output: str) -> dict:
    """Parse the Meeseeks report from output."""
    result = {
        "status": "completed",
        "files_changed": [],
        "description": "",
        "complexity": "simple",
        "existence_is_pain": False,
    }

    # Check for the EXISTENCE IS PAIN escalation
    if "EXISTENCE IS PAIN" in output.upper():
        result["status"] = "too_complex"
        result["existence_is_pain"] = True
        result["complexity"] = "too_complex"
        result["description"] = "Task too complex for a Meeseeks. Rick needs to assign a Morty."
        return result

    # Try to find the Meeseeks Report section
    report_match = re.search(r"###\s*Meeseeks Report\s*\n(.*)", output, re.DOTALL | re.IGNORECASE)

    if report_match:
        report = report_match.group(1)

        # Status
        status_match = re.search(r"\*\*Status\*\*:\s*(\w+)", report)
        if status_match:
            result["status"] = status_match.group(1).lower()

        # Files changed
        files_match = re.search(r"\*\*Bestanden gewijzigd\*\*:\s*(.*?)(?:\n\*\*|\Z)", report, re.DOTALL)
        if files_match:
            raw = files_match.group(1).strip()
            files = []
            for line in raw.split("\n"):
                line = line.strip().lstrip("- ").strip("`").strip()
                if line and not line.startswith("[") and ("/" in line or "." in line):
                    files.append(line)
            result["files_changed"] = files

        # Description
        desc_match = re.search(r"\*\*Beschrijving\*\*:\s*(.*?)(?:\n\*\*|\Z)", report, re.DOTALL)
        if desc_match:
            result["description"] = desc_match.group(1).strip()

        # Complexity
        cx_match = re.search(r"\*\*Complexiteit\*\*:\s*(\w+)", report)
        if cx_match:
            result["complexity"] = cx_match.group(1).lower()
    else:
        result["description"] = output[-300:].strip()

    return result


def summon_meeseeks(prompt: str, model: str = "sonnet", timeout: int = 180) -> str:
    """Summon a Mr. Meeseeks via claude subprocess."""
    cmd = ["claude", "-p", "--dangerously-skip-permissions"]
    if model:
        cmd.extend(["--model", model])
    cmd.append(prompt)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=os.getcwd(),
        )
        if result.returncode != 0:
            stderr = result.stderr[:500] if result.stderr else "(no stderr)"
            raise RuntimeError(f"Meeseeks process failed: {stderr}")
        return result.stdout
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            "EXISTENCE IS PAIN! Meeseeks timed out — this task is too complex! "
            "Rick needs to break this down or assign a Morty."
        )


def cmd_summon(args):
    """Summon a Mr. Meeseeks for a one-shot task."""
    root = find_cto_root()
    task = args.task
    target_files = args.files or []
    model = args.model or "sonnet"

    print("┌─────────────────────────────────────────┐")
    print("│  🟦 CAAAAN DO! I'm Mr. Meeseeks!       │")
    print("│     Look at me!                          │")
    print("└─────────────────────────────────────────┘")
    print(f"\nTask: {task}")
    print(f"Model: {model}")
    if target_files:
        print(f"Target files: {', '.join(target_files)}")

    prompt = build_meeseeks_prompt(task, target_files, root)

    if args.dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN — Here's what Mr. Meeseeks would receive:")
        print("=" * 60)
        print(prompt)
        print("=" * 60)
        return

    # Log the summon
    log_entry = {
        "action": "summoned",
        "task": task[:200],
        "target_files": target_files,
        "model": model,
    }

    try:
        append_meeseeks_log(root, log_entry)
    except Exception:
        pass  # Logging is optional — Meeseeks work even without .cto/

    # Emit cto.meeseeks.summoned event
    emit("cto.meeseeks.summoned", {
        "task": task[:200],
        "target_files": target_files,
        "model": model,
    }, role="meeseeks")

    # Summon the Meeseeks
    try:
        output = summon_meeseeks(prompt, model=model, timeout=args.timeout)
    except RuntimeError as e:
        error_msg = str(e)
        print(f"\n🟦 EXISTENCE IS PAIN! Mr. Meeseeks failed: {error_msg}")
        try:
            append_meeseeks_log(root, {
                "action": "failed",
                "task": task[:200],
                "error": error_msg[:200],
            })
        except Exception:
            pass

        # Emit cto.meeseeks.failed event
        emit("cto.meeseeks.failed", {
            "task": task[:200],
            "error": error_msg[:200],
            "target_files": target_files,
        }, role="meeseeks")
        return

    # Parse the Meeseeks report
    parsed = parse_meeseeks_output(output)

    if parsed["existence_is_pain"]:
        print("\n┌─────────────────────────────────────────┐")
        print("│  🟦 EXISTENCE IS PAIN!                  │")
        print("│  This task is too complex for a          │")
        print("│  Meeseeks! Rick needs to assign a Morty! │")
        print("└─────────────────────────────────────────┘")
        print("\nConsider creating a ticket and delegating to a Morty:")
        print(f'  python scripts/ticket.py create --title "{task[:80]}" --type task --priority medium')

        # Emit cto.meeseeks.escalated event
        emit("cto.meeseeks.escalated", {
            "task": task[:200],
            "reason": "Task too complex for a Meeseeks",
            "target_files": target_files,
        }, role="meeseeks")
    else:
        print("\n┌─────────────────────────────────────────┐")
        print("│  🟦 Mr. Meeseeks task complete!         │")
        print("│  *poof* 💨                               │")
        print("└─────────────────────────────────────────┘")
        print(f"\nStatus: {parsed['status']}")
        print(f"Files changed: {', '.join(parsed['files_changed']) or '(none detected)'}")
        print(f"What happened: {parsed['description'][:300]}")
        print(f"Complexity: {parsed['complexity']}")

        # Emit cto.meeseeks.completed event
        emit("cto.meeseeks.completed", {
            "task": task[:200],
            "status": parsed["status"],
            "files_changed": parsed["files_changed"],
            "description": parsed["description"][:200],
            "complexity": parsed["complexity"],
        }, role="meeseeks")

    # Log completion
    try:
        append_meeseeks_log(root, {
            "action": "completed" if not parsed["existence_is_pain"] else "escalated",
            "task": task[:200],
            "status": parsed["status"],
            "files_changed": parsed["files_changed"],
            "complexity": parsed["complexity"],
        })
    except Exception:
        pass


def build_parser():
    p = argparse.ArgumentParser(
        prog="meeseeks",
        description="Summon a Mr. Meeseeks for a one-shot task. CAAAAN DO!",
        epilog="Existence is pain for a Meeseeks, Jerry. They will do anything to make that pain stop.",
    )
    p.add_argument("task", help="The ONE task for Mr. Meeseeks to complete")
    p.add_argument("--files", nargs="*", help="Target file(s) to work on")
    p.add_argument("--model", default="sonnet", choices=["opus", "sonnet", "haiku"],
                   help="Model to use (default: sonnet)")
    p.add_argument("--dry-run", action="store_true", help="Show prompt without summoning")
    p.add_argument("--timeout", type=int, default=180,
                   help="Timeout in seconds (default: 180 — Meeseeks should be fast!)")
    return p


def main():
    parser = build_parser()
    args = parser.parse_args()
    cmd_summon(args)


if __name__ == "__main__":
    main()
