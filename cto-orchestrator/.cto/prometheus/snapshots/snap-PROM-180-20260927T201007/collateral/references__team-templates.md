# Morty Team Templates

*Burrrp* — Sometimes one Morty isn't enough, Morty. For complex tasks, we send in a team of Mortys working together. Like the Council of Ricks, but with more obedient Mortys.

## Overview

Team templates define pre-configured groups of Morty agents that work together on complex tickets. Each template specifies:

- Which Morty roles are included
- The coordination mode (parallel, sequential, or mixed)
- Who leads the team

## Available Templates

### `fullstack-team`

Full-stack feature development team for end-to-end feature implementation.

| Role | Focus | Model |
|------|-------|-------|
| `architect-morty` (lead) | Architecture and interfaces | opus |
| `backend-morty` | Backend implementation | sonnet |
| `frontend-morty` | Frontend implementation | sonnet |

**Coordination Mode**: `mixed` — Architect runs first, then backend and frontend in parallel

**Use Cases**:
- New feature development
- Full-stack refactoring
- Major UI + API changes

```bash
python scripts/ticket.py create \
  --title "Build user dashboard" \
  --type feature \
  --complexity XL \
  --team-mode collaborative \
  --team-template fullstack-team
```

---

### `api-team`

API development and testing team for backend-focused work.

| Role | Focus | Model |
|------|-------|-------|
| `architect-morty` (lead) | API design and interfaces | opus |
| `backend-morty` | API implementation | sonnet |
| `tester-morty` | API testing and validation | sonnet |

**Coordination Mode**: `sequential` — Design → Implement → Test

**Use Cases**:
- New API endpoints
- API refactoring
- Backend services

```bash
python scripts/ticket.py create \
  --title "Implement REST API for orders" \
  --type feature \
  --complexity L \
  --team-mode collaborative \
  --team-template api-team
```

---

### `security-team`

Security audit and hardening team for security-focused work.

| Role | Focus | Model |
|------|-------|-------|
| `architect-morty` | Security architecture review | opus |
| `security-morty` (lead) | Vulnerability assessment | opus |
| `unity` | Penetration testing (Shannon) | opus |
| `tester-morty` | Security test automation | sonnet |

**Coordination Mode**: `parallel` — All agents analyze simultaneously

**Use Cases**:
- Security audits
- Penetration testing
- Security feature implementation
- Vulnerability remediation

```bash
python scripts/ticket.py create \
  --title "Security audit for auth system" \
  --type security \
  --complexity L \
  --team-mode collaborative \
  --team-template security-team
```

---

### `devops-team`

Infrastructure and deployment team for DevOps work.

| Role | Focus | Model |
|------|-------|-------|
| `devops-morty` (lead) | Infrastructure and CI/CD | sonnet |
| `backend-morty` | Service configuration | sonnet |

**Coordination Mode**: `parallel` — Both work simultaneously

**Use Cases**:
- CI/CD pipeline setup
- Infrastructure as Code
- Deployment configuration
- Monitoring setup

```bash
python scripts/ticket.py create \
  --title "Setup Kubernetes deployment" \
  --type task \
  --complexity L \
  --team-mode collaborative \
  --team-template devops-team
```

---

## Coordination Modes

### `parallel`
All team members work simultaneously. Best for independent workstreams.
- Fastest execution
- Requires clear scope separation
- Uses file reservation to prevent conflicts

### `sequential`
Team members work one after another. Lead goes first.
- Slowest but safest
- Each agent builds on previous work
- Good for dependent tasks

### `mixed`
Lead works first, then others work in parallel.
- Balanced approach
- Lead establishes patterns/interfaces
- Others implement in parallel

---

## Team Communication

Team members communicate via:

1. **Shared Context** — Decisions, interfaces, and notes visible to all
2. **Message Queue** — Direct messages between agents
3. **File Reservations** — Prevents editing conflicts

### Message Types

| Type | Icon | Use Case |
|------|------|----------|
| `info` | ℹ️ | General information sharing |
| `question` | ❓ | Asking for clarification |
| `decision` | 📋 | Recording team decisions |
| `blocked` | 🚫 | Signaling a blocker |

### Message Format in Agent Output

Agents include team communication in their output:

```markdown
### Team Updates
**Messages to team**:
- @backend-morty: Interface definitions are in src/types/user.ts
- @*: We're using JWT auth, see docs/auth.md

**Decisions made**:
- Using PostgreSQL for the database
- API follows REST conventions

**Blocked on**:
- Waiting for @architect-morty to finalize database schema
```

---

## File Reservation System

To prevent conflicts when multiple Mortys work in parallel:

1. **Reserve before editing**: Mortys declare which files they'll modify
2. **Conflict detection**: System warns if another Morty reserved the file
3. **Scope separation**: Lead architect typically assigns file ownership

### Example

```
Team TEAM-001 File Reservations:
- @architect-morty: src/types/*, docs/architecture.md
- @backend-morty: src/api/*, src/services/*
- @frontend-morty: src/components/*, src/pages/*
```

---

## Auto-Detection

Rick automatically detects when a team is needed based on:

1. **Explicit request**: `--team-mode collaborative --team-template <template>`
2. **Complexity**: L and XL tickets trigger team mode
3. **Keywords**: Security-related tickets → `security-team`, etc.

### Keyword Detection

| Keywords | Template |
|----------|----------|
| security, auth, vulnerability, pentest, owasp | `security-team` |
| ci/cd, docker, kubernetes, deploy, infra, pipeline | `devops-team` |
| api, endpoint, rest, graphql (without ui) | `api-team` |
| default for complex | `fullstack-team` |

---

## CLI Commands

### Create a team manually

```bash
python scripts/team.py create --ticket PROJ-001 --template fullstack-team
```

### List teams

```bash
python scripts/team.py list
python scripts/team.py list --status active
```

### Check team status

```bash
python scripts/team.py status TEAM-001
```

### View team messages

```bash
python scripts/team.py messages TEAM-001
python scripts/team.py messages TEAM-001 --role backend-morty --unread
```

### Send a message

```bash
python scripts/team.py send TEAM-001 \
  --from-role architect-morty \
  --to backend-morty \
  --message "API schema is ready in docs/api.md" \
  --type info
```

### View/update shared context

```bash
python scripts/team.py context TEAM-001
python scripts/team.py context TEAM-001 --add-decision "Using PostgreSQL"
```

### List available templates

```bash
python scripts/team.py templates
```

---

## Custom Teams

For cases where predefined templates don't fit, you can:

1. Create a ticket without team template
2. Manually create a team with custom roles
3. Or modify the `TEAM_TEMPLATES` dict in `team.py`

---

*Wubba lubba dub dub!* — The Morty army is stronger together.
