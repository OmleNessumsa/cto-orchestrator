# RickTerminal

Managed by Rick Sanchez, the smartest CTO in the multiverse. *Burrrp*

## Quick Start

```bash
# View project status (Rick's command center)
python scripts/orchestrate.py status

# Plan the project (let Rick's genius brain work)
python scripts/orchestrate.py plan "Description of what to build"

# Run a sprint (send the Morty's to work)
python scripts/orchestrate.py sprint

# View ticket board
python scripts/ticket.py board
```

## Security

Agent Bash commands are checked against a network egress allowlist by the
PreToolUse guardrail hook (`scripts/hooks.py`, `scripts/security_utils.py`),
blocking exfiltration to unapproved hosts via curl/wget, git remotes,
pip/npm index flags, and raw nc/netcat.

- `CTO_EGRESS_ALLOWLIST` — comma-separated hostnames agents may reach
  (subdomains of a listed host are also allowed). Defaults to
  `github.com, pypi.org, files.pythonhosted.org, registry.npmjs.org, anthropic.com`.
- `CTO_EGRESS_MODE` — `warn` (default) logs denied egress and lets the
  command proceed; `block` denies the tool call outright.
