# ZEAS-072 — Integration contract: native sandbox for Morty subprocesses

Implements Prometheus proposal PROM-192 (needs-human; approved by Elmo 2026-10-11).
NEVER edit anything under `.cto/prometheus/` — prometheus.py is the only writer there.
Do not touch `.cto/config.json`; the feature flag defaults ON when the key is absent.

## Verified Claude Code sandbox schema
CLI 2.1.286 is installed. Source: code.claude.com/docs/en/sandboxing.

- `sandbox.enabled` (bool), `sandbox.allowUnsandboxedCommands` (bool), `sandbox.failIfUnavailable` (bool)
- `sandbox.network.allowedDomains`: a list of strings. Wildcards such as `"*.github.com"` work. A bare `"github.com"` does NOT cover subdomains.
- `sandbox.network.strictAllowlist` (bool, CLI >= 2.1.219) denies silently instead of prompting. It is ONLY valid in user/managed settings or in a `--settings` file. It is NOT allowed in project `.claude/settings.json`.
- `sandbox.filesystem.allowWrite`: a list of absolute paths.
- Arrays do not merge across settings files. The highest-precedence file supplies the whole array, so the `--settings` file must carry the full domain list.
- Sandbox network rules apply in every permission mode, including bypassPermissions.

## Tasks

### 1. scripts/security_utils.py
Add the following right after `scan_command_egress()`.
- `SANDBOX_MIN_CLI = (2, 1, 219)`
- `sandbox_domains(extra_domains=()) -> list[str]`: for every host in `_egress_allowlist() | set(extra_domains)`, lowercase it, strip it, remove any trailing dot and skip empty values. Emit both `h` and `"*." + h`, then return the sorted unique list. This uses the same subdomain semantics as `_egress_host_allowed`, so the regex allowlist and the OS allowlist come from one source.
- `build_sandbox_settings(root, extra_domains=(), unattended=False, extra_write=()) -> dict` returns:
  ```
  {"sandbox": {"enabled": True, "allowUnsandboxedCommands": False,
     "failIfUnavailable": bool(unattended),
     "network": {"allowedDomains": sandbox_domains(extra_domains),
                 "strictAllowlist": bool(unattended)},
     "filesystem": {"allowWrite": sorted unique [resolved root, "/tmp",
                     resolved tempfile.gettempdir(), *extra_write]}}}
  ```
- `is_unattended() -> bool` returns `os.environ.get("CTO_UNATTENDED") == "1"`.
- `native_sandbox_enabled(root) -> bool` reads `security.native_sandbox` from `<root>/.cto/config.json` and defaults to True. Env `CTO_NATIVE_SANDBOX=0` forces it off. It never raises: a bad or missing config gives True.
- `cli_supports_native_sandbox(version_string) -> bool` parses `X.Y.Z` and returns whether it is `>= SANDBOX_MIN_CLI`. An unparseable string gives False.
- `write_sandbox_settings(root, tag, base=None, unattended=False, extra_domains=()) -> Path` deep-merges `build_sandbox_settings(...)` into a copy of `base` (for example the guardrail-hooks settings dict). It writes the result to `<root>/.cto/session/sandbox-<sanitize_path_component(tag)>.json` with mode 0o600 and returns the path.
- Leave `scan_command_egress` unchanged; it stays as defense-in-depth.

### 2. scripts/delegate.py
In `delegate_to_agent`, replace `cmd.extend(build_guardrail_hook_args(delegate_root))` with `cmd.extend(build_settings_args(delegate_root, ticket_id, agent_role))`. The new helper must produce exactly ONE `--settings` flag:
- `hooks_settings = build_guardrail_hooks_settings(fail_closed=True)` if `_check_claude_hook_fail_closed_support()`, else None. Keep the one-time `guardrail.warning` emit. Keep `build_guardrail_hook_args` working, because existing tests use it.
- If `native_sandbox_enabled(root)` and `cli_supports_native_sandbox(_get_claude_version())`:
  - write `path = write_sandbox_settings(root, ticket_id or f"{agent_role}-{os.getpid()}", base=hooks_settings or {}, unattended=is_unattended())`;
  - emit `"security.sandbox_enabled"` with `{ticket_id, agent_role, strict, domains: count, settings_path}`;
  - return `["--settings", str(path)]`.
- Otherwise, emit `"security.sandbox_skipped"` once per process with the reason and cli_version, then fall back to the old hooks-only behaviour.
- Import the new names using the existing try/except import pattern at the top of delegate.py. The fallbacks must disable the sandbox (for example, `native_sandbox_enabled` returns False).

### 3. scripts/prometheus.py
- In `delegate_evolve`: when the sandbox is enabled and the CLI supports it, write `write_sandbox_settings(root, f"evolve-{os.getpid()}", unattended=True)`. Insert `["--settings", path]` before the prompt argument and emit `security.sandbox_enabled` with `source="prometheus.evolve"` and `strict=True`.
- Root: use the same project-root resolution as the rest of prometheus.py.
- Add a small cached `claude --version` probe (timeout 5).
- Leave `claude_scan` unchanged; it is read-only research.

### 4. scripts/sleepy.py
In `run_delegate`, pass `env={**os.environ, "CTO_UNATTENDED": "1"}` to `subprocess.run`. Every sleepy-spawned Morty then gets strictAllowlist, because nobody is around to answer prompts.

### 5. .claude/settings.json — REVERSED 2026-10-11 (Elmo chose option A)
Do NOT add a project-level sandbox block. Claude Code reloads it live and sandboxes
the interactive Rick session too; Morties spawned from there need a nested
Seatbelt sandbox, which fails to start, leaving them without Bash
(`allowUnsandboxedCommands: false` removes the fallback). Morties get their
sandbox from the per-spawn `--settings` file only. Original instruction kept below
for history:
Add a top-level baseline next to the existing hooks block, and leave the hooks block untouched:
`"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "network": {"allowedDomains": [the sorted list that sandbox_domains() yields for the default allowlist]}}`
Do NOT add strictAllowlist here; project settings don't allow it.

### 6. Tests: new scripts/test_native_sandbox.py
Use unittest in the style of test_subagent_guardrails.py, runnable with `python3 scripts/test_native_sandbox.py`. Cover:
- sandbox_domains covers every allowlist host plus its wildcard, and honours the `CTO_EGRESS_ALLOWLIST` env.
- build_sandbox_settings: strict follows unattended; allowWrite has the repo root and /tmp; allowUnsandboxedCommands is False.
- native_sandbox_enabled: default True; config false gives False; env `CTO_NATIVE_SANDBOX=0` gives False; broken JSON gives True.
- cli_supports_native_sandbox: `"2.1.286 (Claude Code)"` gives True; `"2.1.218"` gives False; `""` gives False.
- delegate.build_settings_args:
  - produces exactly one `--settings`;
  - the file has `sandbox`, plus `hooks` when the fail-closed probe is patched True;
  - no sandbox when the flag is off;
  - emits security.sandbox_enabled (patch emit).
- The baseline allowedDomains in .claude/settings.json equal sandbox_domains() for the default allowlist, and there is no strictAllowlist.
- sleepy.run_delegate passes `CTO_UNATTENDED=1` (patch subprocess.run).

Run ALL `scripts/test_*.py` plus `python3 -m py_compile` on every touched file, and fix any regressions you caused.
