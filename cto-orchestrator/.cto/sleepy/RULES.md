# Sleepy Rules — human-editable deny-list and scope hints

Edit this file BEFORE running `sleepy start`. Rick will not delegate
work that touches any of these paths. Lines starting with `#` are
ignored; everything else is treated as a glob pattern (gitignore syntax).

## deny
.env
.env.*
**/secrets/**
**/*.key
**/*.pem
**/credentials.json
.cto/config.json
.cto/sleepy/**

## scope hints (free text — Morty reads this as context)

- Prefer small incremental tickets over epics during sleepy runs.
- If a ticket requires external services or secrets, skip it.
- Never modify .cto/config.json or .cto/sleepy/ itself.
