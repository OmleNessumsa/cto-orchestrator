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
