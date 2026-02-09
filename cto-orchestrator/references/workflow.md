# Rick's End-to-End Project Workflow

## Overview

Rick's Orchestrator follows a genius-level workflow: **Init → Plan → Sprint (Adventure) → Review → Done**. It's not rocket science. Well, it IS rocket science. I built a spaceship in my garage, Morty.

Now with **Team Collaboration** — Morty's can work together on complex tasks with parallel execution!

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

### Team Collaboration (New!)

For complex tickets (L, XL complexity), Rick can spawn a team of Morty's to work together:

```bash
# Create a ticket with team mode
python scripts/ticket.py create \
  --title "Build user dashboard with auth" \
  --type feature \
  --complexity XL \
  --team-mode collaborative \
  --team-template fullstack-team
```

The sprint will automatically:
1. Detect team-eligible tickets
2. Spawn the appropriate team
3. Run agents in parallel (based on coordination mode)
4. Collect and merge results

See `references/team-templates.md` for available templates.

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

## Team Collaboration Workflow

For complex tasks, Rick assembles teams of Morty's that work together.

### Team Sprint Flow

```
+---------------------------------------------------+
|  1. Rick detects team-worthy ticket (L/XL)        |
|  2. Spawns team from template                     |
|  3. Creates shared context file                   |
|  4. Runs agents based on coordination mode:       |
|     - parallel: all at once                       |
|     - sequential: one by one                      |
|     - mixed: lead first, then others parallel    |
|  5. Agents communicate via message queue          |
|  6. Results merged into ticket                    |
|  7. Team marked complete                          |
+---------------------------------------------------+
```

### Team Templates

| Template | Roles | Use Case |
|----------|-------|----------|
| `fullstack-team` | architect + backend + frontend | Feature development |
| `api-team` | architect + backend + tester | API work |
| `security-team` | architect + security + unity + tester | Security features |
| `devops-team` | devops + backend | Infrastructure |

### Team Commands

```bash
# Create team manually
python scripts/team.py create --ticket PROJ-001 --template fullstack-team

# Check team status
python scripts/team.py status TEAM-001

# View team messages
python scripts/team.py messages TEAM-001

# View shared context
python scripts/team.py context TEAM-001
```

### Disabling Teams

To run in solo mode (original behavior):

```bash
python scripts/orchestrate.py sprint --no-teams
```

## Unity Security Integration

Unity is Rick's security specialist — a wrapper around the Shannon pentest framework.

### Unity Workflow

```
+---------------------------------------------------+
|  1. Start scan (manual or via security-team)      |
|  2. Unity checks if Temporal/Shannon available    |
|  3. If yes: runs full Shannon pentest workflow    |
|     If no: falls back to static analysis          |
|  4. Tracks progress via workflow ID               |
|  5. Generates report (JSON + Markdown)            |
+---------------------------------------------------+
```

### Unity Commands

```bash
# Check dependencies
python scripts/unity.py check

# Start a scan
python scripts/unity.py scan --repo ./myapp
python scripts/unity.py scan --url https://staging.example.com

# Check progress
python scripts/unity.py status <workflow-id>

# Get report
python scripts/unity.py report <workflow-id>
```

### Unity in Security Team

When using the `security-team` template, Unity works alongside:
- `architect-morty`: Security architecture review
- `security-morty`: Static code analysis
- `unity`: Dynamic penetration testing
- `tester-morty`: Security test automation

### Setting Up Unity

```bash
# Install Shannon framework
bash scripts/unity_setup.sh

# Start Temporal (optional, for full pentest mode)
cd vendors/shannon && docker-compose up -d

# Verify
python scripts/unity.py check
```

## Directory Structure

After team and Unity features, the `.cto/` directory includes:

```
.cto/
├── config.json
├── tickets/
│   └── PROJ-001.json
├── logs/
│   └── 2024-01-15.jsonl
├── decisions/
│   └── ADR-001.md
├── teams/                  # NEW - Team collaboration
│   ├── active/
│   │   └── TEAM-001.json
│   ├── messages/
│   │   └── TEAM-001/
│   │       └── msg-001.json
│   └── context/
│       └── TEAM-001-shared.json
└── unity/                  # NEW - Unity security
    ├── workflows/
    │   └── unity-abc123.json
    └── reports/
        ├── unity-abc123-report.json
        └── unity-abc123-report.md
```
