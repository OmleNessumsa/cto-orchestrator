#!/usr/bin/env python3
"""CTO Orchestrator — Hook Runner.

Loads hook definitions from .cto/config.json under a `hooks` key and executes
them at defined points in the delegation pipeline:

  pre_delegate   — before agent execution
  post_delegate  — after successful completion
  on_failure     — on agent failure
  on_review      — during review phase

Each hook entry is an object with:
  {"cmd": "shell command string"}        # shell hook
  {"callable": "module:function"}        # Python callable hook (dotted import)

Environment variables available to shell hooks:
  CTO_TICKET_ID, CTO_AGENT, CTO_STATUS, CTO_ROOT
"""

import importlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from rich.console import Console

console = Console()


def _load_hooks(root: Path, hook_point: str) -> list[dict]:
    """Return the list of hook definitions for hook_point, or []."""
    config_fp = root / ".cto" / "config.json"
    if not config_fp.exists():
        return []
    try:
        with open(config_fp) as f:
            config = json.load(f)
        return config.get("hooks", {}).get(hook_point, [])
    except Exception:
        return []


def _env_for_hook(ticket: dict, agent: str, extra: dict | None = None, root: Path | None = None) -> dict:
    env = dict(os.environ)
    env["CTO_TICKET_ID"] = ticket.get("id", "")
    env["CTO_AGENT"] = agent or ""
    env["CTO_STATUS"] = ticket.get("status", "")
    if root:
        env["CTO_ROOT"] = str(root)
    if extra:
        for k, v in extra.items():
            env[k] = str(v)
    return env


def _run_shell_hook(cmd: str, env: dict, hook_point: str) -> bool:
    """Run a shell command hook. Returns True on success."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            console.print(
                f"[yellow]Hook [{hook_point}] exited {result.returncode}: {result.stderr.strip()[:200]}[/yellow]"
            )
            return False
        if result.stdout.strip():
            console.print(f"[dim]Hook [{hook_point}]: {result.stdout.strip()[:200]}[/dim]")
        return True
    except subprocess.TimeoutExpired:
        console.print(f"[yellow]Hook [{hook_point}] timed out[/yellow]")
        return False
    except Exception as e:
        console.print(f"[yellow]Hook [{hook_point}] error: {e}[/yellow]")
        return False


def _run_callable_hook(ref: str, ticket: dict, agent: str, output: Optional[str], hook_point: str) -> bool:
    """Run a Python callable hook (module:function). Returns True on success."""
    try:
        module_name, func_name = ref.rsplit(":", 1)
        module = importlib.import_module(module_name)
        func = getattr(module, func_name)
        func(ticket=ticket, agent=agent, output=output)
        return True
    except Exception as e:
        console.print(f"[yellow]Hook [{hook_point}] callable '{ref}' error: {e}[/yellow]")
        return False


def run_hooks(
    hook_point: str,
    ticket: dict,
    agent: str,
    output: Optional[str] = None,
    root: Optional[Path] = None,
) -> bool:
    """Execute all hooks registered for hook_point.

    Returns True if all hooks succeeded (or there were none), False if any failed.
    Hook failures are non-fatal — they are logged but never block delegation.
    """
    if root is None:
        root = Path(__file__).parent.parent
    hooks = _load_hooks(root, hook_point)
    if not hooks:
        return True

    env = _env_for_hook(ticket, agent, root=root)
    all_ok = True
    for hook in hooks:
        if "cmd" in hook:
            ok = _run_shell_hook(hook["cmd"], env, hook_point)
        elif "callable" in hook:
            ok = _run_callable_hook(hook["callable"], ticket, agent, output, hook_point)
        else:
            console.print(f"[yellow]Hook [{hook_point}] unknown type: {hook}[/yellow]")
            ok = False
        all_ok = all_ok and ok

    return all_ok


# ── Claude Code PreToolUse Guardrail Hook ─────────────────────────────────────

def _find_repo_root(cwd: str) -> Path:
    """Walk up from cwd to find the project root (.git or .cto directory)."""
    p = Path(cwd).resolve()
    while True:
        if (p / ".git").is_dir() or (p / ".cto").is_dir():
            return p
        parent = p.parent
        if parent == p:
            return Path(cwd).resolve()
        p = parent


def _load_all_reservations(root: Path) -> dict[str, list[str]]:
    """Return merged role -> [absolute_file_paths] from all active team files."""
    reservations: dict[str, list[str]] = {}
    teams_dir = root / ".cto" / "teams" / "active"
    if not teams_dir.is_dir():
        return reservations
    for team_file in teams_dir.glob("*.json"):
        try:
            with open(team_file) as f:
                team = json.load(f)
            for role, paths in team.get("files_reserved", {}).items():
                existing = reservations.setdefault(role, [])
                for p in paths:
                    abs_p = (
                        str((root / p).resolve())
                        if not os.path.isabs(p)
                        else str(Path(p).resolve())
                    )
                    if abs_p not in existing:
                        existing.append(abs_p)
        except Exception:
            pass
    return reservations


def _emit_guardrail_block(event_data: dict) -> None:
    """Fire-and-forget guardrail.block event to roro (best-effort)."""
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from roro_events import emit
        emit("guardrail.block", event_data)
    except Exception:
        pass


def guardrail_hook() -> None:
    """Claude Code PreToolUse hook entry point.

    Reads the hook JSON payload from stdin and enforces:
    - Sensitive-path denylist for Edit/Write (blocks .env, keys, escaping root)
    - File-reservation enforcement for Edit/Write (blocks cross-Morty conflicts)
    - Dangerous-command scanner for Bash

    Exits 0 to allow; exits 2 to block (reason written to stderr so Claude
    receives it as feedback).
    """
    sys.path.insert(0, str(Path(__file__).parent))

    try:
        from security_utils import is_path_in_denylist, scan_bash_command
    except ImportError:
        sys.exit(0)  # fail open if security_utils unavailable

    try:
        raw = sys.stdin.read()
        hook_input = json.loads(raw) if raw.strip() else {}
    except Exception:
        sys.exit(0)  # malformed stdin — fail open

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    cwd = hook_input.get("cwd", os.getcwd())
    session_id = hook_input.get("session_id", "")

    root = _find_repo_root(cwd)
    caller_role = os.environ.get("CTO_AGENT_ROLE", "")

    def block(reason: str, context: dict | None = None) -> None:
        _emit_guardrail_block({
            "tool_name": tool_name,
            "reason": reason,
            "session_id": session_id,
            "caller_role": caller_role,
            **(context or {}),
        })
        print(reason, file=sys.stderr)
        sys.exit(2)

    if tool_name in ("Edit", "Write"):
        file_path = tool_input.get("file_path") or tool_input.get("path", "")
        if not file_path:
            sys.exit(0)

        abs_path = (
            str((root / file_path).resolve())
            if not os.path.isabs(file_path)
            else str(Path(file_path).resolve())
        )

        # Security denylist: .env, keys, paths outside repo root
        blocked, reason = is_path_in_denylist(abs_path, repo_root=root)
        if blocked:
            block(f"GUARDRAIL: {reason}", {"file_path": file_path})

        # File reservation: block cross-Morty writes when a role is identified
        if caller_role:
            for owner_role, reserved_paths in _load_all_reservations(root).items():
                if owner_role == caller_role:
                    continue
                for rp in reserved_paths:
                    if abs_path == rp or abs_path.startswith(rp + os.sep):
                        block(
                            f"GUARDRAIL: '{file_path}' is reserved by '{owner_role}'. "
                            f"You are '{caller_role}'. Coordinate via reserve_files() or wait.",
                            {"file_path": file_path, "owner_role": owner_role},
                        )

    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        dangerous, reason = scan_bash_command(command)
        if dangerous:
            block(f"GUARDRAIL: {reason}", {"command": command[:200]})

    sys.exit(0)


if __name__ == "__main__":
    guardrail_hook()
