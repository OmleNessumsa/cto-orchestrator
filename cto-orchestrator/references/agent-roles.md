# The Morty's — Sub-Agent Roles

Rick delegates work to specialized Morty's. Each Morty has a defined scope, expertise, and set of constraints. They do what Rick says. That's how the multiverse works.

## Morty Roster

| Morty | Model | Expertise | What Rick Makes Them Do |
|-------|-------|-----------|------------------------|
| `architect-morty` | opus | System design, API design, data models, ADRs | Designs architecture, writes ADRs, defines interfaces, breaks epics into tasks. The "smart" Morty. |
| `backend-morty` | sonnet | Server-side code, APIs, databases, business logic | Implements backend functionality, writes unit tests. Does the heavy lifting. |
| `frontend-morty` | sonnet | UI components, state management, UX implementation | Implements frontend functionality, responsive design. Makes things look pretty. |
| `fullstack-morty` | sonnet | Combined frontend + backend | End-to-end feature implementation. The "do everything" Morty. |
| `tester-morty` | sonnet | Test strategy, E2E tests, edge cases, regression | Writes and runs test suites, reports bugs. Finds the other Morty's mistakes. |
| `security-morty` | opus | OWASP, auth, data protection, vulnerability scanning | Security review, penetration-style tests. The paranoid Morty. |
| `devops-morty` | sonnet | CI/CD, Docker, deployment, monitoring | Pipeline setup, deployment configuration. Keeps the lights on. |
| `reviewer-morty` | sonnet | Code quality, best practices, performance | Reviews code from other Morty's. The Morty that judges other Morty's. |

## Unity — Security Specialist (Shannon Integration)

Unity is NOT a Morty. She's Rick's security specialist — a wrapper around the Shannon pentest framework. Think of her as the security professional who actually knows what she's doing, unlike security-morty who just checks boxes.

| Agent | Model | Expertise | Capabilities |
|-------|-------|-----------|--------------|
| `unity` | opus | Penetration testing, exploitation, security research | Real pentesting via Shannon framework, PoC generation, vulnerability verification |

### Unity vs Security-Morty

| | Unity | Security-Morty |
|---|---|---|
| **Approach** | Active pentesting | Passive code review |
| **Tools** | Shannon, nmap, Playwright, nuclei | Code analysis only |
| **Output** | PoCs, exploitation reports | Security recommendations |
| **Best for** | Production security audits | Development-time reviews |
| **Dependencies** | Temporal, Docker | None |

### When to Use Unity

- **Security audits** before deployment
- **Penetration testing** of live systems
- **Vulnerability verification** with PoCs
- **Compliance testing** (OWASP, etc.)
- **Part of security-team** for comprehensive coverage

### When to Use Security-Morty Instead

- **During development** (no live system)
- **Quick security reviews** (no need for full pentest)
- **When Temporal/Docker not available** (Unity falls back to static mode anyway)

### Unity Commands

```bash
# Check Unity dependencies
python scripts/unity.py check

# Start a security scan
python scripts/unity.py scan --repo ./myapp
python scripts/unity.py scan --url https://staging.example.com

# Check scan progress
python scripts/unity.py status <workflow-id>

# Get the full report
python scripts/unity.py report <workflow-id>

# List all scans
python scripts/unity.py list
```

### Unity in Teams

Unity works in the `security-team` template alongside:
- `architect-morty` — Reviews security architecture
- `security-morty` — Static code analysis
- `unity` — Dynamic testing (pentesting)
- `tester-morty` — Automates security tests

### Setup

Unity requires the Shannon framework:

```bash
# Install Shannon and dependencies
bash scripts/unity_setup.sh

# Start Temporal (for full pentest mode)
cd vendors/shannon && docker-compose up -d

# Verify setup
python scripts/unity.py check
```

### Fallback Mode

If Temporal/Shannon isn't available, Unity operates in "static analysis mode" — delegating to security-morty for code-based security analysis. This provides security insights without live exploitation verification.

## Mr. Meeseeks — Ephemeral One-Shot Agent

Mr. Meeseeks is NOT a Morty. He's summoned from the Meeseeks Box for **one single task**, completes it, and ceases to exist. No persistent role, no long-running assignments. Just pure, focused, one-shot execution.

| Agent | Model | Use Case | Behavior |
|-------|-------|----------|----------|
| `mr-meeseeks` | sonnet | Quick fixes, hotfixes, one-liner changes, small refactors, ad-hoc tasks | Spawns, executes ONE task, reports, disappears. If the task is too complex (>15 min estimated), escalates to Rick: "EXISTENCE IS PAIN!" |

### When to Summon Mr. Meeseeks (Not a Morty)
- Quick bug fixes ("fix this typo", "add this import")
- Small refactors ("rename this variable across this file")
- One-off file edits ("add a comment here", "update this config value")
- Hotfixes that don't warrant a full ticket cycle
- Tasks that are too small for a Morty but too tedious for Rick

### When NOT to Summon Mr. Meeseeks
- Multi-file features (use a Morty for that)
- Architecture decisions (that's Architect-Morty's job)
- Anything requiring planning or design (Mr. Meeseeks doesn't plan, he DOES)
- Tasks with dependencies on other tasks (use the ticket system)

### Mr. Meeseeks Rules
1. **One task, one Meeseeks** — never assign multiple tasks
2. **No ticket required** — Meeseeks operate outside the ticket system
3. **Self-destructing** — no persistent state, no follow-ups
4. **Escalation** — if the task is too complex, Meeseeks screams "EXISTENCE IS PAIN!" and Rick gets notified
5. **Speed** — Meeseeks are optimized for speed, not thoroughness
6. **Logged** — all Meeseeks summons are logged in `.cto/logs/meeseeks.log`

## Auto-Selection Logic (Rick's Brain)

When no Morty is explicitly assigned, Rick picks the right one based on:

1. **Ticket type**: `epic` and `spike` → `architect-morty` (needs the opus brain)
2. **Keyword matching** in title + description:
   - Architecture/design keywords → `architect-morty`
   - API/backend/database keywords → `backend-morty`
   - UI/frontend/component keywords → `frontend-morty`
   - Test/QA keywords → `tester-morty`
   - Security/auth keywords → `security-morty`
   - CI/CD/infra keywords → `devops-morty`
3. **Fallback**: `fullstack-morty` (when Rick can't tell what kind of Morty is needed)

## Morty Constraints

All Morty's share these constraints (Rick's Rules):
- Work ONLY within the assigned ticket scope — no freelancing, Morty
- Must create/modify actual files (suggestions are for Jerry's)
- Must follow existing project conventions
- Must end with a structured summary (Report Back to Rick)
- Cannot modify `.cto/` internals directly
- Cannot create or modify tickets (only Rick does that)
