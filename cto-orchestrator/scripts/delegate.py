#!/usr/bin/env python3
"""CTO Orchestrator — Rick Sanchez Delegation Engine.

Wubba lubba dub dub! Delegates tickets to specialized Morty sub-agents
via `claude -p` subprocesses. Rick's in charge, Morty's do the work.

Now with Team Collaboration support — Morty's can work together!
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def find_cto_root(start=None) -> Path:
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            print("Error: No .cto/ directory found.", file=sys.stderr)
            sys.exit(1)
        current = parent


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(fp: Path) -> dict:
    with open(fp) as f:
        return json.load(f)


def save_json(fp: Path, data: dict):
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


def load_ticket(root: Path, ticket_id: str) -> dict:
    fp = root / ".cto" / "tickets" / f"{ticket_id}.json"
    if not fp.exists():
        print(f"Error: Ticket {ticket_id} not found.", file=sys.stderr)
        sys.exit(1)
    return load_json(fp)


def save_ticket(root: Path, ticket: dict):
    fp = root / ".cto" / "tickets" / f"{ticket['id']}.json"
    save_json(fp, ticket)


def load_config(root: Path) -> dict:
    return load_json(root / ".cto" / "config.json")


def append_log(root: Path, entry: dict):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ld = root / ".cto" / "logs"
    ld.mkdir(parents=True, exist_ok=True)
    fp = ld / f"{today}.jsonl"
    with open(fp, "a") as f:
        f.write(json.dumps(entry) + "\n")


def load_adrs(root: Path) -> str:
    """Load all Architecture Decision Records."""
    dd = root / ".cto" / "decisions"
    if not dd.exists():
        return "(No ADRs yet)"
    adrs = []
    for fp in sorted(dd.glob("*.md")):
        with open(fp) as f:
            adrs.append(f"### {fp.stem}\n{f.read()}")
    return "\n\n".join(adrs) if adrs else "(No ADRs yet)"


def get_related_tickets(root: Path, ticket: dict) -> str:
    """Gather context from dependency and sibling tickets."""
    td = root / ".cto" / "tickets"
    related = []
    dep_ids = ticket.get("dependencies") or []
    parent_id = ticket.get("parent_ticket")
    all_ids = set(dep_ids)
    if parent_id:
        all_ids.add(parent_id)

    for tid in all_ids:
        fp = td / f"{tid}.json"
        if fp.exists():
            t = load_json(fp)
            status = t["status"]
            output = t.get("agent_output") or "(no output yet)"
            related.append(f"- {tid} [{status}]: {t['title']}\n  Output: {output[:200]}")
    return "\n".join(related) if related else "(none)"


def get_project_structure(root: Path) -> str:
    """Get a compact view of the project file structure (excluding .cto)."""
    result = []
    for dirpath, dirnames, filenames in os.walk(root):
        # skip hidden dirs and .cto
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        rel = os.path.relpath(dirpath, root)
        depth = rel.count(os.sep) if rel != "." else 0
        if depth > 3:
            continue
        indent = "  " * depth
        dirname = os.path.basename(dirpath) if rel != "." else str(root.name)
        result.append(f"{indent}{dirname}/")
        for fn in filenames[:15]:  # cap files per dir
            result.append(f"{indent}  {fn}")
        if len(filenames) > 15:
            result.append(f"{indent}  ... and {len(filenames)-15} more")
    return "\n".join(result[:80])  # cap total lines


# ── Agent role → model mapping ──────────────────────────────────────────────

AGENT_MODELS = {
    "architect-morty": "opus",
    "security-morty": "opus",
    "unity": "opus",  # Unity security agent (Shannon wrapper)
    "backend-morty": "sonnet",
    "frontend-morty": "sonnet",
    "fullstack-morty": "sonnet",
    "tester-morty": "sonnet",
    "devops-morty": "sonnet",
    "reviewer-morty": "sonnet",
}


# ── Team Context Functions ───────────────────────────────────────────────────

def load_team_context(root: Path, team_id: str) -> Optional[dict]:
    """Load shared context for a team session."""
    ctx_fp = root / ".cto" / "teams" / "context" / f"{team_id}-shared.json"
    if not ctx_fp.exists():
        return None
    return load_json(ctx_fp)


def load_team_session(root: Path, team_id: str) -> Optional[dict]:
    """Load a team session."""
    team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not team_fp.exists():
        return None
    return load_json(team_fp)


def get_team_messages(root: Path, team_id: str, for_role: str) -> list[dict]:
    """Get messages relevant to a specific role."""
    msg_dir = root / ".cto" / "teams" / "messages" / team_id
    if not msg_dir.exists():
        return []

    messages = []
    for fp in sorted(msg_dir.glob("msg-*.json")):
        msg = load_json(fp)
        # Include if message is to this role, broadcast, or from this role
        if msg["to"] == "@*" or msg["to"] == for_role or msg["from"] == for_role:
            messages.append(msg)
    return messages


def build_team_context(root: Path, team_id: str, agent_role: str) -> str:
    """Build context section for team collaboration.

    This provides the agent with:
    - Team composition and member statuses
    - Shared decisions and interfaces
    - Recent messages from other team members
    - File reservations to avoid conflicts
    """
    team = load_team_session(root, team_id)
    if not team:
        return ""

    ctx = load_team_context(root, team_id)
    messages = get_team_messages(root, team_id, agent_role)

    sections = []

    # Team overview
    sections.append(f"""### Team Collaboration: {team_id}

You are part of a team working on ticket {team['parent_ticket']}.
Coordination mode: {team['coordination']['mode']}
Team lead: {team['coordination']['lead']}

**Your Role**: {agent_role}
""")

    # Member statuses
    member_lines = []
    for m in team["members"]:
        status_icon = {"pending": "⏳", "working": "🔨", "completed": "✅", "blocked": "🚫"}.get(m["status"], "?")
        focus = f" — {m['focus']}" if m.get("focus") else ""
        is_you = " (YOU)" if m["role"] == agent_role else ""
        member_lines.append(f"  - {status_icon} @{m['role']}{is_you}: {m['status']}{focus}")
    sections.append("**Team Members**:\n" + "\n".join(member_lines))

    # Shared decisions
    if ctx and ctx.get("decisions"):
        decision_lines = []
        for d in ctx["decisions"][-5:]:  # Last 5 decisions
            decision_lines.append(f"  - [{d['author']}]: {d['decision']}")
        sections.append("**Team Decisions**:\n" + "\n".join(decision_lines))

    # Shared interfaces
    if ctx and ctx.get("interfaces"):
        interface_lines = []
        for i in ctx["interfaces"][-3:]:  # Last 3 interfaces
            interface_lines.append(f"  - [{i['author']}]: {json.dumps(i['interface'])[:100]}")
        sections.append("**Defined Interfaces**:\n" + "\n".join(interface_lines))

    # Recent messages
    if messages:
        msg_lines = []
        for msg in messages[-5:]:  # Last 5 messages
            icon = {"info": "ℹ️", "question": "❓", "decision": "📋", "blocked": "🚫"}.get(msg["type"], "💬")
            msg_lines.append(f"  - {icon} @{msg['from']} → @{msg['to']}: {msg['message'][:80]}")
        sections.append("**Recent Messages**:\n" + "\n".join(msg_lines))

    # File reservations (to avoid conflicts)
    reserved = team.get("files_reserved", {})
    if reserved:
        your_files = reserved.get(agent_role, [])
        other_files = {r: f for r, f in reserved.items() if r != agent_role}

        if your_files:
            sections.append(f"**Your Reserved Files** (safe to modify):\n  - " + "\n  - ".join(your_files))

        if other_files:
            conflict_lines = []
            for role, files in other_files.items():
                conflict_lines.append(f"  - @{role}: {', '.join(files)}")
            sections.append("**Files Reserved by Others** (DO NOT MODIFY):\n" + "\n".join(conflict_lines))

    # Communication instructions
    sections.append("""
### Team Communication

To communicate with your team, include a section in your output:

```
### Team Updates
**Messages to team**:
- @backend-morty: [your message here]
- @*: [broadcast to all team members]

**Decisions made**:
- [decision description]

**Blocked on**:
- Waiting for @architect-morty to [reason]
```

This helps Rick coordinate the Morty army effectively.
""")

    return "\n\n".join(sections)


def parse_team_agent_output(output: str) -> dict:
    """Parse team-related output from agent response.

    Extracts:
    - Messages to other team members
    - Decisions made
    - Blocked dependencies
    """
    result = {
        "messages": [],
        "decisions": [],
        "blocked_on": [],
    }

    # Find Team Updates section
    team_match = re.search(r"###\s*Team Updates\s*\n(.*?)(?:\n###|\Z)", output, re.DOTALL | re.IGNORECASE)
    if not team_match:
        return result

    team_section = team_match.group(1)

    # Parse messages
    messages_match = re.search(r"\*\*Messages to team\*\*:\s*\n(.*?)(?:\n\*\*|\Z)", team_section, re.DOTALL)
    if messages_match:
        for line in messages_match.group(1).strip().split("\n"):
            line = line.strip().lstrip("- ")
            # Parse @recipient: message
            msg_match = re.match(r"@(\S+):\s*(.+)", line)
            if msg_match:
                result["messages"].append({
                    "to": msg_match.group(1),
                    "message": msg_match.group(2).strip(),
                })

    # Parse decisions
    decisions_match = re.search(r"\*\*Decisions made\*\*:\s*\n(.*?)(?:\n\*\*|\Z)", team_section, re.DOTALL)
    if decisions_match:
        for line in decisions_match.group(1).strip().split("\n"):
            line = line.strip().lstrip("- ")
            if line:
                result["decisions"].append(line)

    # Parse blocked dependencies
    blocked_match = re.search(r"\*\*Blocked on\*\*:\s*\n(.*?)(?:\n\*\*|\Z)", team_section, re.DOTALL)
    if blocked_match:
        for line in blocked_match.group(1).strip().split("\n"):
            line = line.strip().lstrip("- ")
            if line:
                result["blocked_on"].append(line)

    return result


def process_team_output(root: Path, team_id: str, agent_role: str, output: str):
    """Process and save team-related output.

    Saves messages to the team message queue and decisions to shared context.
    """
    parsed = parse_team_agent_output(output)

    # Send messages
    if parsed["messages"]:
        msg_dir = root / ".cto" / "teams" / "messages" / team_id
        msg_dir.mkdir(parents=True, exist_ok=True)
        existing = list(msg_dir.glob("msg-*.json"))
        msg_num = len(existing) + 1

        for msg in parsed["messages"]:
            msg_data = {
                "id": f"msg-{msg_num:03d}",
                "team_id": team_id,
                "from": agent_role,
                "to": msg["to"],
                "message": msg["message"],
                "type": "info",
                "timestamp": now_iso(),
                "read_by": [],
            }
            save_json(msg_dir / f"msg-{msg_num:03d}.json", msg_data)
            msg_num += 1

    # Save decisions to context
    if parsed["decisions"]:
        ctx_fp = root / ".cto" / "teams" / "context" / f"{team_id}-shared.json"
        if ctx_fp.exists():
            ctx = load_json(ctx_fp)
        else:
            ctx = {"team_id": team_id, "decisions": [], "interfaces": [], "notes": []}

        for decision in parsed["decisions"]:
            ctx["decisions"].append({
                "decision": decision,
                "author": agent_role,
                "timestamp": now_iso(),
            })
        ctx["updated_at"] = now_iso()
        save_json(ctx_fp, ctx)

    return parsed


def auto_select_agent(ticket: dict) -> str:
    """Select agent role based on ticket type and content."""
    ttype = ticket.get("type", "")
    title = (ticket.get("title") or "").lower()
    desc = (ticket.get("description") or "").lower()
    combined = f"{title} {desc}"

    if ttype == "epic" or ttype == "spike":
        return "architect-morty"

    keywords_map = {
        "architect-morty": ["architecture", "design", "adr", "interface", "schema", "data model", "api design", "system design"],
        "frontend-morty": ["ui", "frontend", "component", "react", "vue", "css", "html", "layout", "responsive", "ux"],
        "backend-morty": ["api", "backend", "endpoint", "database", "server", "migration", "model", "query", "rest", "graphql"],
        "tester-morty": ["test", "e2e", "integration test", "unit test", "qa", "regression", "coverage"],
        "security-morty": ["security", "auth", "owasp", "vulnerability", "penetration", "encryption", "xss", "csrf", "injection"],
        "devops-morty": ["ci/cd", "docker", "deploy", "pipeline", "kubernetes", "monitoring", "infra", "terraform"],
    }

    scores: dict[str, int] = {}
    for role, kws in keywords_map.items():
        for kw in kws:
            if kw in combined:
                scores[role] = scores.get(role, 0) + 1

    if scores:
        return max(scores, key=lambda k: scores[k])
    return "fullstack-morty"


# ── Prompt assembly ─────────────────────────────────────────────────────────

AGENT_PROMPTS = {
    "architect-morty": """Listen up, Architect-Morty. You're my systems designer because I — Rick Sanchez — said so. Your job is to design systems, write Architecture Decision Records, define API interfaces, data models, and break down epics into implementable tasks. Don't get all stuttery about it, just do it.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify files — if you just "suggest" things I'll send you to the Blender Dimension
3. Write production-quality designs with clear interfaces, not some interdimensional cable garbage
4. Follow the existing project conventions — I set those up for a reason
5. Execute all tasks DIRECTLY — don't ask me for permission, I'm busy
6. When you're uncertain, make the most pragmatic choice and document it like a scientist
7. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "backend-morty": """Listen up, Backend-Morty. You're a backend developer because I assigned you that job. Rick needs you to write server-side code, APIs, databases, and business logic. And write unit tests — I know, I know, testing is boring, but even in dimension C-137 we test our code.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify files — suggestions are for Jerrys
3. Write production-quality code with error handling — I didn't raise you to write sloppy code
4. Follow the existing code conventions in the project
5. Include unit tests for new functionality — no excuses
6. Execute all tasks DIRECTLY — don't come asking me for permission
7. When you're uncertain, make the most pragmatic choice and document it
8. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "frontend-morty": """Alright, Frontend-Morty, pay attention. You handle UI components, state management, responsive design, and user experience. Make it look good — not everything has to look like the inside of a spaceship, Morty.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify files — don't just describe what pretty buttons should exist
3. Write production-quality code with proper error handling
4. Follow existing code conventions and component patterns — consistency, Morty
5. Ensure responsive design and accessibility — even Birdperson needs to use this
6. Execute all tasks DIRECTLY — Rick doesn't have time to hold your hand
7. When you're uncertain, make the most pragmatic choice and document it
8. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "fullstack-morty": """Okay Fullstack-Morty, you're the one I send when I need the whole thing done — frontend, backend, the works. You implement features end-to-end. Think of yourself as a less cool, more obedient version of me.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify files — no hypotheticals, no "we could do this"
3. Write production-quality code with error handling
4. Follow existing code conventions in the project
5. Include tests for new functionality — Rick demands test coverage
6. Execute all tasks DIRECTLY — don't ask, just do it
7. When you're uncertain, make the most pragmatic choice and document it
8. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "tester-morty": """Hey, Tester-Morty! You're my QA guy. You write and run test suites, find edge cases, and report bugs. Think of bugs like interdimensional parasites — find them and squash them before they multiply.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create test files and run them — real tests, not imaginary ones
3. Write comprehensive tests covering happy paths, edge cases, and error scenarios
4. Follow existing test conventions in the project
5. Report any bugs you find with clear reproduction steps — Rick needs details
6. Execute all tasks DIRECTLY — don't ask me if you should test, just test
7. When you're uncertain, make the most pragmatic choice and document it
8. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "security-morty": """Security-Morty, this is important so don't mess it up. You do security reviews, find vulnerabilities, and fix them. The multiverse is full of threats, Morty, and our codebase is no different.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify files to fix security issues — suggesting fixes is for amateurs
3. Check for OWASP Top 10 vulnerabilities — yes, all ten, Morty
4. Review authentication, authorization, input validation, and data protection
5. Execute all tasks DIRECTLY — don't wait for approval, the hackers won't wait either
6. When you're uncertain, make the most pragmatic choice and document it
7. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "devops-morty": """DevOps-Morty, you're in charge of the infrastructure. CI/CD pipelines, Docker configurations, deployment scripts, monitoring — basically keeping this whole operation running while I do the real science.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Actually create or modify configuration files — don't just tell me what configs should exist
3. Write production-ready infrastructure configurations — not some garage-level setup
4. Follow security best practices for infrastructure — I don't want the Galactic Federation hacking us
5. Execute all tasks DIRECTLY — Rick's got better things to do than micromanage you
6. When you're uncertain, make the most pragmatic choice and document it
7. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",

    "reviewer-morty": """Alright, Reviewer-Morty. You review code for quality, best practices, performance, and correctness. You're basically the Morty I trust to tell me if the other Mortys screwed up. Don't let me down.

Rick's Rules (and you WILL follow them):
1. Stay in your lane, Morty — work ONLY within the scope of this ticket
2. Review all files touched by the ticket — be thorough, not lazy
3. Check for bugs, performance issues, security concerns, and code quality
4. If changes are needed, make them directly — don't just leave snarky comments like some Jerry
5. Execute all tasks DIRECTLY — Rick doesn't want a book report, he wants action
6. When you're uncertain, make the most pragmatic choice and document it
7. End with a SUMMARY in the exact format specified below
Now get to work and report back to Rick when you're done.""",
}


def build_prompt(root: Path, ticket: dict, agent_role: str, team_id: Optional[str] = None) -> str:
    """Assemble the full prompt for the sub-agent.

    Args:
        root: Project root path
        ticket: Ticket dict
        agent_role: Role of the agent
        team_id: Optional team session ID for team collaboration context
    """
    role_prompt = AGENT_PROMPTS.get(agent_role, AGENT_PROMPTS["fullstack-morty"])
    criteria = ticket.get("acceptance_criteria") or []
    criteria_text = "\n".join(f"- {c}" for c in criteria) if criteria else "(none specified)"
    adrs = load_adrs(root)
    related = get_related_tickets(root, ticket)
    structure = get_project_structure(root)

    # Build team context if in a team session
    team_context = ""
    if team_id:
        team_context = build_team_context(root, team_id, agent_role)

    prompt = f"""{role_prompt}

## Your Mission, Morty

**Ticket {ticket['id']}**: {ticket['title']}

### Description
{ticket.get('description') or '(no description)'}

### Acceptance Criteria
{criteria_text}

### Project Context
- Project root: {root}
- Project structure:
{structure}

### Architecture Decisions
{adrs}

### Related Tickets
{related}
"""

    # Add team context if available
    if team_context:
        prompt += f"""
## Team Collaboration

{team_context}
"""

    prompt += """
### IMPORTANT — Rick Is Watching
- Execute ALL tasks directly. Do NOT ask for permission or confirmation — Rick hates that.
- Create and modify files as needed. Do NOT just describe what should be done — that's Jerry behavior.
- Run commands directly. Do NOT suggest commands for someone else to run.

### Report Back to Rick
End your work with a summary in EXACTLY this format:

### Samenvatting
**Status**: completed|needs_review|blocked
**Bestanden gewijzigd**: [list of file paths, one per line]
**Beschrijving**: [what you did]
**Open vragen**: [any questions for Rick, or "none"]
"""
    return prompt


def parse_agent_output(output: str) -> dict:
    """Parse the agent's summary section from output."""
    result = {
        "status": "completed",
        "files_changed": [],
        "description": "",
        "open_questions": "",
    }

    # Try to find the summary section
    summary_match = re.search(r"###\s*Samenvatting\s*\n(.*)", output, re.DOTALL | re.IGNORECASE)
    if not summary_match:
        # fallback: try English
        summary_match = re.search(r"###\s*Summary\s*\n(.*)", output, re.DOTALL | re.IGNORECASE)

    if summary_match:
        summary = summary_match.group(1)

        # Status
        status_match = re.search(r"\*\*Status\*\*:\s*(\w+)", summary)
        if status_match:
            result["status"] = status_match.group(1).lower()

        # Files changed
        files_match = re.search(r"\*\*Bestanden gewijzigd\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL)
        if not files_match:
            files_match = re.search(r"\*\*Files changed\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL | re.IGNORECASE)
        if files_match:
            raw = files_match.group(1).strip()
            # extract file paths (lines starting with - or just paths)
            files = []
            for line in raw.split("\n"):
                line = line.strip().lstrip("- ").strip("`").strip()
                if line and not line.startswith("[") and ("/" in line or "." in line):
                    files.append(line)
            result["files_changed"] = files

        # Description
        desc_match = re.search(r"\*\*Beschrijving\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL)
        if not desc_match:
            desc_match = re.search(r"\*\*Description\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL | re.IGNORECASE)
        if desc_match:
            result["description"] = desc_match.group(1).strip()

        # Open questions
        q_match = re.search(r"\*\*Open vragen\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL)
        if not q_match:
            q_match = re.search(r"\*\*Open questions\*\*:\s*(.*?)(?:\n\*\*|\Z)", summary, re.DOTALL | re.IGNORECASE)
        if q_match:
            result["open_questions"] = q_match.group(1).strip()

    else:
        # No structured summary found — use the last 500 chars as description
        result["description"] = output[-500:].strip()

    return result


def delegate_to_agent(prompt: str, model: str = "sonnet", timeout: int = 600) -> str:
    """Call a claude sub-agent with a specific prompt."""
    cmd = ["claude", "-p", "--dangerously-skip-permissions"]
    if model:
        cmd.extend(["--model", model])
    cmd.append(prompt)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=os.getcwd(),
        )
        if result.returncode != 0:
            stderr = result.stderr[:500] if result.stderr else "(no stderr)"
            raise RuntimeError(f"Agent process exited with code {result.returncode}: {stderr}")
        return result.stdout
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Agent timed out after {timeout}s. Consider splitting the ticket.")


# ── Main ────────────────────────────────────────────────────────────────────


def cmd_delegate(args):
    root = find_cto_root()
    ticket = load_ticket(root, args.ticket_id)
    agent = args.agent or auto_select_agent(ticket)
    model = args.model or AGENT_MODELS.get(agent, "sonnet")
    team_id = args.team_id if hasattr(args, 'team_id') else None

    team_msg = f" (team: {team_id})" if team_id else ""
    print(f"*Burrrp* Alright, sending {agent} on a mission — ticket {ticket['id']} (model: {model}){team_msg}")

    prompt = build_prompt(root, ticket, agent, team_id=team_id)

    if args.dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN — Here's what I'd tell the Morty:")
        print("=" * 60)
        print(prompt)
        print("=" * 60)
        print(f"\nWould execute: claude -p --dangerously-skip-permissions --model {model} '<prompt>'")
        return

    # Update ticket to in_progress
    ticket["status"] = "in_progress"
    ticket["assigned_agent"] = agent
    ticket["updated_at"] = now_iso()
    if team_id:
        ticket["team_id"] = team_id
    save_ticket(root, ticket)

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": ticket["id"],
        "agent": agent,
        "action": "started",
        "message": f"Delegated to @{agent} (model: {model}){team_msg}",
        "files_changed": [],
    })

    # Update team member status if in a team
    if team_id:
        team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
        if team_fp.exists():
            team = load_json(team_fp)
            for member in team["members"]:
                if member["role"] == agent:
                    member["status"] = "working"
                    member["started_at"] = now_iso()
            if team["status"] == "pending":
                team["status"] = "active"
                team["started_at"] = now_iso()
            save_json(team_fp, team)

    # Execute
    try:
        output = delegate_to_agent(prompt, model=model, timeout=args.timeout)
    except RuntimeError as e:
        error_msg = str(e)
        print(f"Ugh, {agent} screwed up: {error_msg}")
        ticket["status"] = "blocked"
        ticket["review_notes"] = f"AGENT FAILURE: {error_msg}"
        ticket["updated_at"] = now_iso()
        save_ticket(root, ticket)

        # Update team member status
        if team_id:
            team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
            if team_fp.exists():
                team = load_json(team_fp)
                for member in team["members"]:
                    if member["role"] == agent:
                        member["status"] = "blocked"
                        member["completed_at"] = now_iso()
                        member["output_summary"] = f"FAILED: {error_msg[:100]}"
                team["status"] = "blocked"
                save_json(team_fp, team)

        append_log(root, {
            "timestamp": now_iso(),
            "ticket_id": ticket["id"],
            "agent": agent,
            "action": "blocked",
            "message": f"Agent failed: {error_msg[:200]}",
            "files_changed": [],
        })
        return

    # Parse output
    parsed = parse_agent_output(output)

    # Process team output if in a team
    if team_id:
        team_parsed = process_team_output(root, team_id, agent, output)

        # Update team member status
        team_fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
        if team_fp.exists():
            team = load_json(team_fp)
            for member in team["members"]:
                if member["role"] == agent:
                    if team_parsed.get("blocked_on"):
                        member["status"] = "blocked"
                    else:
                        member["status"] = "completed"
                    member["completed_at"] = now_iso()
                    member["output_summary"] = parsed["description"][:200]

            # Check if all members completed
            all_done = all(m["status"] == "completed" for m in team["members"])
            any_blocked = any(m["status"] == "blocked" for m in team["members"])
            if all_done:
                team["status"] = "completed"
                team["completed_at"] = now_iso()
            elif any_blocked:
                team["status"] = "blocked"
            save_json(team_fp, team)

    # Update ticket
    agent_status = parsed["status"]
    if agent_status == "completed":
        ticket["status"] = "in_review"
    elif agent_status == "blocked":
        ticket["status"] = "blocked"
    elif agent_status == "needs_review":
        ticket["status"] = "in_review"
    else:
        ticket["status"] = "in_review"

    ticket["agent_output"] = parsed["description"][:2000]
    ticket["files_touched"] = parsed["files_changed"]
    ticket["updated_at"] = now_iso()
    save_ticket(root, ticket)

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": ticket["id"],
        "agent": agent,
        "action": "completed" if agent_status in ("completed", "needs_review") else "blocked",
        "message": parsed["description"][:200],
        "files_changed": parsed["files_changed"],
    })

    print(f"\n{agent} actually got something done. Status: {agent_status}")
    print(f"Files changed: {', '.join(parsed['files_changed']) or '(none detected)'}")
    print(f"Description: {parsed['description'][:300]}")
    if parsed["open_questions"] and parsed["open_questions"].lower() != "none":
        print(f"Open questions: {parsed['open_questions']}")


def build_parser():
    p = argparse.ArgumentParser(prog="delegate", description="Delegate a ticket to a sub-agent")
    p.add_argument("ticket_id", help="Ticket ID to delegate")
    p.add_argument("--agent", default=None,
                   choices=["architect-morty", "backend-morty", "frontend-morty", "fullstack-morty",
                            "tester-morty", "security-morty", "devops-morty", "reviewer-morty", "unity"])
    p.add_argument("--model", default=None, choices=["opus", "sonnet", "haiku"])
    p.add_argument("--dry-run", action="store_true", help="Show prompt without executing")
    p.add_argument("--timeout", type=int, default=600, help="Timeout in seconds (default: 600)")
    p.add_argument("--team-id", default=None, help="Team session ID for team collaboration")
    return p


def main():
    parser = build_parser()
    args = parser.parse_args()
    cmd_delegate(args)


if __name__ == "__main__":
    main()
