# Rick's End-to-End Project Workflow

## Overview

Rick's Orchestrator follows a genius-level workflow: **Init → Plan → Sprint (Adventure) → Review → Done**. It's not rocket science. Well, it IS rocket science. I built a spaceship in my garage, Morty.

## Phase 1: Initialize

```bash
bash scripts/init_project.sh "ProjectName" "PROJ"
```

Creates the `.cto/` workspace with config, ticket store, logs, and decisions directories. Even a Morty could run this command.

## Phase 2: Plan

```bash
python scripts/orchestrate.py plan "Build a REST API for user management with auth, CRUD, and admin dashboard"
```

Rick's genius brain (architect-morty, opus model) will:
1. Analyze the project description
2. Design a high-level architecture
3. Create epic tickets for major components
4. Break epics into implementable sub-tickets for the Morty's
5. Map dependencies between tickets
6. Assign complexity estimates

Output: A populated ticket board ready for the Morty's to execute.

## Phase 3: Sprint (Adventure)

```bash
python scripts/orchestrate.py sprint
```

The adventure loop runs automatically:

```
+---------------------------------------------+
|  1. Rick checks the board                   |
|  2. Finds next ticket a Morty can handle    |
|     (todo + dependencies met)               |
|  3. Picks the right Morty for the job       |
|  4. Sends the Morty via claude -p           |
|  5. Parses what the Morty did               |
|  6. Updates ticket status                   |
|  7. Logs progress                           |
|  8. Repeat until done or all Morty's stuck  |
+---------------------------------------------+
```

### Morty Selection
- Architecture/design → `architect-morty` (opus)
- Backend code → `backend-morty` (sonnet)
- Frontend code → `frontend-morty` (sonnet)
- Full-stack → `fullstack-morty` (sonnet)
- Tests → `tester-morty` (sonnet)
- Security → `security-morty` (opus)
- Infrastructure → `devops-morty` (sonnet)

### Failure Handling
- Morty timeout → ticket marked `blocked`, suggest splitting
- Morty error → retry once with adjusted prompt, then `blocked`
- All Morty's stuck → sprint stops, Rick reports the damage

## Phase 4: Review

```bash
python scripts/orchestrate.py review
```

All `in_review` tickets are sent to `reviewer-morty`:
- Approved → `done` ("Not terrible, Morty")
- Needs changes → back to `todo` ("This is garbage, do it again")

## Phase 5: Monitor

```bash
python scripts/orchestrate.py status     # Rick's dashboard
python scripts/progress.py summary       # Today's summary
python scripts/progress.py report        # Rick's progress report
python scripts/ticket.py board           # Kanban view
```

## Mr. Meeseeks — Quick One-Shot Tasks

Not everything needs a full sprint cycle. For quick fixes, hotfixes, and small tasks, summon a Mr. Meeseeks:

```bash
# Summon a Meeseeks for a quick task
python scripts/meeseeks.py "Fix the typo in README.md line 42"

# Target specific files
python scripts/meeseeks.py "Add error handling to the login function" --files src/auth.py

# Dry run (see the prompt without executing)
python scripts/meeseeks.py "Rename userId to user_id" --files src/models.py --dry-run
```

### How Meeseeks Work

```
+-----------------------------------------------+
|  1. User summons Mr. Meeseeks with a task     |
|  2. Meeseeks spawns (claude -p subprocess)    |
|  3. Meeseeks executes the ONE task            |
|  4. Meeseeks reports back                      |
|  5. *poof* — Meeseeks ceases to exist         |
+-----------------------------------------------+
```

### Meeseeks vs Morty's

| | Mr. Meeseeks | Morty's |
|---|---|---|
| Scope | One task | Full ticket |
| Lifetime | Ephemeral (spawns & dies) | Persistent role |
| Ticket required? | No | Yes |
| Planning? | No | Yes (via Rick) |
| Best for | Quick fixes, hotfixes | Features, architecture |
| Timeout | 3 min (default) | 10 min (default) |
| Escalation | "EXISTENCE IS PAIN!" → Rick | Blocked → Rick reviews |

### Meeseeks Escalation

If a task is too complex, Meeseeks will scream "EXISTENCE IS PAIN!" and Rick gets notified. The suggested next step is to create a ticket and assign a proper Morty:

```bash
# Meeseeks escalated? Create a ticket instead:
python scripts/ticket.py create --title "The complex task" --type task --priority medium
python scripts/delegate.py PROJ-XXX --agent backend-morty
```

All Meeseeks activity is logged in `.cto/logs/meeseeks.log`.

## Manual Intervention

Rick can manually manage tickets at any point:

```bash
# Create a ticket manually
python scripts/ticket.py create --title "Fix login bug" --type bug --priority critical

# Block a ticket
python scripts/ticket.py blocked PROJ-005 --reason "Waiting for API spec"

# Close a ticket manually
python scripts/ticket.py close PROJ-003 --output "Implemented and tested"

# Send a specific Morty on a mission
python scripts/delegate.py PROJ-007 --agent backend-morty

# Dry-run delegation (see the Morty's instructions without sending them)
python scripts/delegate.py PROJ-007 --agent backend-morty --dry-run
```

## Architecture Decision Records

ADRs are stored in `.cto/decisions/` as markdown files. The architect-morty creates them during planning. Format:

```markdown
# ADR-001: Choice of database

## Status: Accepted (Rick approved it)

## Context
[Why this decision was needed]

## Decision
[What Rick decided]

## Consequences
[What follows from Rick's genius decision]
```
