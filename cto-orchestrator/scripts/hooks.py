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

The PreToolUse guardrail hook additionally enforces a network egress
allowlist on Bash commands (see security_utils.scan_command_egress):
  CTO_EGRESS_ALLOWLIST — comma-separated hostnames agents may reach.
                         Defaults to github.com, pypi.org,
                         files.pythonhosted.org, registry.npmjs.org,
                         anthropic.com (subdomains included).
  CTO_EGRESS_MODE       — 'warn' (default): log denied egress and continue.
                         'block': deny the tool call (exit 2).
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


def _emit_package_blocked(event_data: dict) -> None:
    """Fire-and-forget security.package_blocked event to roro (best-effort)."""
    try:
        from roro_events import emit
        emit("security.package_blocked", event_data)
    except Exception:
        pass


def _emit_egress_denied(event_data: dict) -> None:
    """Fire-and-forget egress.denied event to roro (best-effort)."""
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from roro_events import emit
        emit("egress.denied", event_data)
    except Exception:
        pass


# Roles that implement code and so must not rewrite the checks that grade them.
# tester-morty (and reviewers) author tests and are exempt.
_IMPLEMENTER_ROLES = ("backend-morty", "frontend-morty", "fullstack-morty", "devops-morty")


def _protected_test_paths(root: Path, ticket_id: str) -> set[str]:
    """Repo-relative paths a ticket marks read-only: protected_tests plus files named in verify."""
    if not ticket_id or not all(c.isalnum() or c in "-_" for c in ticket_id):
        return set()
    try:
        ticket = json.loads((root / ".cto" / "tickets" / f"{ticket_id}.json").read_text())
    except Exception:
        return set()
    paths = {str(p).lstrip("./") for p in (ticket.get("protected_tests") or []) if p}
    verify = ticket.get("verify") or []
    if isinstance(verify, (str, dict)):
        verify = [verify]
    for entry in verify:
        cmd = entry.get("command", "") if isinstance(entry, dict) else str(entry)
        for tok in cmd.split():
            tok = tok.split("::")[0].strip("\"'")
            if "/" in tok or "." in tok:
                paths.add(tok.lstrip("./"))
    return paths


# Seconds a blocking guardrail hook may run before the CLI treats it as failed.
# Explicit so a slow hook is not cut off by a short default and, with
# onFailure="block", turned into a spurious denial.
GUARDRAIL_HOOK_TIMEOUT = 30

# PreToolUse matchers that enforce security policy (protected-file guard,
# package-install guard, path/sandbox checks). Observability-only hooks (roro
# emitters, progress) are deliberately not listed here and stay fail-open.
_GUARDRAIL_HOOK_MATCHERS = ("Edit|Write|MultiEdit", "Bash")


def build_guardrail_hooks_settings(fail_closed: bool = True) -> dict:
    """Return a Claude Code settings payload wiring the PreToolUse guardrail hook.

    With fail_closed, each enforcement hook carries ``"onFailure": "block"`` so a
    crash, timeout or unstartable command (missing python, bad path) denies the
    tool call instead of silently skipping the check. Callers gate this on CLI
    support (>= 2.1.295). The command uses an absolute script path so it does
    not depend on $CLAUDE_PROJECT_DIR resolving.
    """
    hook_cmd = f'python3 "{Path(__file__).resolve()}"'
    entries = []
    for matcher in _GUARDRAIL_HOOK_MATCHERS:
        hook: dict[str, Any] = {
            "type": "command",
            "command": hook_cmd,
            "timeout": GUARDRAIL_HOOK_TIMEOUT,
        }
        if fail_closed:
            hook["onFailure"] = "block"
        entries.append({"matcher": matcher, "hooks": [hook]})
    return {"hooks": {"PreToolUse": entries}}


def guardrail_hook() -> None:
    """Claude Code PreToolUse hook entry point.

    Reads the hook JSON payload from stdin and enforces:
    - Sensitive-path denylist for Edit/Write (blocks .env, keys, escaping root,
      and protected guardrail/agent-config files unless CTO_ALLOW_CONTROL_EDIT=1)
    - File-reservation enforcement for Edit/Write (blocks cross-Morty conflicts)
    - Dangerous-command scanner for Bash

    Exits 0 to allow; exits 2 to block (reason written to stderr so Claude
    receives it as feedback).
    """
    sys.path.insert(0, str(Path(__file__).parent))

    try:
        from security_utils import (
            CONTROL_BLOCK_PREFIX,
            audit_log_security_event,
            is_path_in_denylist,
            is_test_path,
            scan_bash_command,
            scan_command_egress,
            scan_package_install,
        )
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
        if CONTROL_BLOCK_PREFIX in reason:
            audit_log_security_event(
                "control_file_tamper_blocked",
                f"{reason} — {tool_name} {json.dumps(context or {})[:200]}",
                severity="critical",
                log_dir=root / ".cto" / "logs",
            )
            _emit_guardrail_block({
                "tool_name": tool_name,
                "reason": reason,
                "session_id": session_id,
                "caller_role": caller_role,
                "severity": "critical",
                "category": "control_file_tamper",
                **(context or {}),
            })
            print(reason, file=sys.stderr)
            sys.exit(2)
        _emit_guardrail_block({
            "tool_name": tool_name,
            "reason": reason,
            "session_id": session_id,
            "caller_role": caller_role,
            **(context or {}),
        })
        print(reason, file=sys.stderr)
        sys.exit(2)

    if tool_name in ("Edit", "Write", "MultiEdit"):
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

        # Test-tamper guard: implementers may not edit tests that grade their ticket
        if caller_role in _IMPLEMENTER_ROLES:
            try:
                rel = Path(abs_path).relative_to(root.resolve()).as_posix()
            except ValueError:
                rel = ""
            if rel and is_test_path(rel):
                protected = _protected_test_paths(root, os.environ.get("CTO_TICKET_ID", ""))
                if rel in protected or any(rel.endswith("/" + p) for p in protected):
                    block(
                        f"GUARDRAIL: '{file_path}' is a protected test/verify file for this ticket; "
                        f"'{caller_role}' may not modify it. Fix the code, not the test.",
                        {"file_path": file_path, "category": "test_tamper"},
                    )
                audit_log_security_event(
                    "test_edit_warning",
                    f"{caller_role} edited unlisted test file {rel}",
                    severity="warning",
                    log_dir=root / ".cto" / "logs",
                )
                print(f"WARNING: editing test file '{file_path}'; changes are flagged to the reviewer.",
                      file=sys.stderr)

    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        dangerous, reason = scan_bash_command(command)
        if dangerous:
            block(f"GUARDRAIL: {reason}", {"command": command[:200]})

        pkg_blocked, pkg_reason = scan_package_install(command, repo_root=root)
        if pkg_blocked:
            audit_log_security_event(
                "package_blocked",
                f"{pkg_reason} — command: {command[:200]}",
                severity="warning",
                log_dir=root / ".cto" / "logs",
            )
            _emit_package_blocked({
                "tool_name": tool_name,
                "reason": pkg_reason,
                "session_id": session_id,
                "caller_role": caller_role,
                "command": command[:200],
            })
            block(f"GUARDRAIL: {pkg_reason}", {"command": command[:200]})

        denied, egress_reason = scan_command_egress(command)
        if denied:
            egress_mode = os.environ.get("CTO_EGRESS_MODE", "warn").lower().strip()
            if egress_mode == "block":
                block(f"GUARDRAIL: {egress_reason}", {"command": command[:200]})
            else:
                audit_log_security_event(
                    "egress_denied",
                    f"{egress_reason} — command: {command[:200]}",
                    severity="warning",
                    log_dir=root / ".cto" / "logs",
                )
                _emit_egress_denied({
                    "tool_name": tool_name,
                    "reason": egress_reason,
                    "session_id": session_id,
                    "caller_role": caller_role,
                    "command": command[:200],
                })

    sys.exit(0)


if __name__ == "__main__":
    guardrail_hook()
