#!/usr/bin/env python3
"""Rick Sanchez Orchestrator — Main orchestration loop (Rick's genius brain).

I'm Rick Sanchez, the smartest CTO in the multiverse. *burp*
I delegate work to my army of Morty's because I'm too important
to write code myself. Get schwifty.

Now with Team Collaboration — Morty's can work in parallel teams!

Commands:
  plan   — Rick plans the project (genius-level architecture)
  sprint — Send the Morty's to do the actual work (now with team support!)
  review — Rick reviews what the Morty's cooked up
  status — Rick's project dashboard
"""

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Import roro event emitter
try:
    from roro_events import emit
except ImportError:
    # Fallback if module not found
    def emit(*args, **kwargs):
        pass


# ── Shared helpers (same as other scripts) ──────────────────────────────────

def find_cto_root(start=None) -> Path:
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            print("Error: No .cto/ directory found. Run init_project.sh first.", file=sys.stderr)
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


def load_config(root: Path) -> dict:
    return load_json(root / ".cto" / "config.json")


def save_config(root: Path, cfg: dict):
    save_json(root / ".cto" / "config.json", cfg)


def all_tickets(root: Path) -> list[dict]:
    td = root / ".cto" / "tickets"
    if not td.exists():
        return []
    tickets = []
    for fp in sorted(td.glob("*.json")):
        with open(fp) as f:
            tickets.append(json.load(f))
    return tickets


def load_ticket(root: Path, tid: str) -> dict:
    fp = root / ".cto" / "tickets" / f"{tid}.json"
    return load_json(fp)


def save_ticket(root: Path, ticket: dict):
    fp = root / ".cto" / "tickets" / f"{ticket['id']}.json"
    save_json(fp, ticket)


def append_log(root: Path, entry: dict):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ld = root / ".cto" / "logs"
    ld.mkdir(parents=True, exist_ok=True)
    fp = ld / f"{today}.jsonl"
    with open(fp, "a") as f:
        f.write(json.dumps(entry) + "\n")


def scripts_dir() -> Path:
    return Path(__file__).parent.resolve()


def run_ticket_cmd(root: Path, *args) -> str:
    cmd = [sys.executable, str(scripts_dir() / "ticket.py")] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root))
    return result.stdout + result.stderr


def run_delegate(root: Path, ticket_id: str, agent: str = None, dry_run: bool = False, timeout: int = 600, team_id: str = None) -> str:
    cmd = [sys.executable, str(scripts_dir() / "delegate.py"), ticket_id]
    if agent:
        cmd.extend(["--agent", agent])
    if dry_run:
        cmd.append("--dry-run")
    cmd.extend(["--timeout", str(timeout)])
    if team_id:
        cmd.extend(["--team-id", team_id])
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root), timeout=timeout + 60)
    return result.stdout + result.stderr


def run_progress_cmd(root: Path, *args) -> str:
    cmd = [sys.executable, str(scripts_dir() / "progress.py")] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root))
    return result.stdout + result.stderr


def run_team_cmd(root: Path, *args) -> str:
    cmd = [sys.executable, str(scripts_dir() / "team.py")] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root))
    return result.stdout + result.stderr


# ── Team Templates ───────────────────────────────────────────────────────────

TEAM_TEMPLATES = {
    "fullstack-team": {
        "description": "Full-stack feature development team",
        "roles": ["architect-morty", "backend-morty", "frontend-morty"],
    },
    "api-team": {
        "description": "API development and testing team",
        "roles": ["architect-morty", "backend-morty", "tester-morty"],
    },
    "security-team": {
        "description": "Security audit and hardening team",
        "roles": ["architect-morty", "security-morty", "unity", "tester-morty"],
    },
    "devops-team": {
        "description": "Infrastructure and deployment team",
        "roles": ["devops-morty", "backend-morty"],
    },
}

COMPLEXITY_TEAM_THRESHOLD = {"L": True, "XL": True}  # These need teams


def detect_team_need(ticket: dict) -> Optional[str]:
    """Detect if a ticket needs a team and which template to use.

    Returns the template name if a team is needed, None otherwise.
    """
    # Check if ticket explicitly requests a team
    team_mode = ticket.get("team_mode")
    team_template = ticket.get("team_template")
    if team_mode == "collaborative" and team_template:
        return team_template

    # Auto-detect based on complexity
    complexity = ticket.get("estimated_complexity", "M")
    if complexity not in COMPLEXITY_TEAM_THRESHOLD:
        return None  # Solo work for S, M, XS

    # Determine template based on ticket content
    ttype = ticket.get("type", "")
    title = (ticket.get("title") or "").lower()
    desc = (ticket.get("description") or "").lower()
    combined = f"{title} {desc}"

    # Security-related → security-team
    if any(kw in combined for kw in ["security", "auth", "vulnerability", "pentest", "owasp"]):
        return "security-team"

    # Infrastructure/deployment → devops-team
    if any(kw in combined for kw in ["ci/cd", "docker", "kubernetes", "deploy", "infra", "pipeline"]):
        return "devops-team"

    # API-focused → api-team
    if any(kw in combined for kw in ["api", "endpoint", "rest", "graphql"]) and "ui" not in combined:
        return "api-team"

    # Default for complex features → fullstack-team
    return "fullstack-team"


def load_team(root: Path, team_id: str) -> Optional[dict]:
    """Load a team session."""
    fp = root / ".cto" / "teams" / "active" / f"{team_id}.json"
    if not fp.exists():
        return None
    return load_json(fp)


def all_teams(root: Path) -> list[dict]:
    """Load all team sessions."""
    td = root / ".cto" / "teams" / "active"
    if not td.exists():
        return []
    teams = []
    for fp in sorted(td.glob("*.json")):
        teams.append(load_json(fp))
    return teams


def spawn_team(root: Path, ticket: dict, template_name: str) -> dict:
    """Spawn a team for a ticket.

    Creates a team session and generates sub-assignments for each member.
    """
    # Create team via team.py
    output = run_team_cmd(root, "create", "--ticket", ticket["id"], "--template", template_name)
    print(f"  {output}")

    # Find the created team
    teams = all_teams(root)
    for team in reversed(teams):
        if team["parent_ticket"] == ticket["id"]:
            return team

    raise RuntimeError(f"Failed to create team for {ticket['id']}")


def delegate_team_member(root: Path, team_id: str, agent_role: str, ticket_id: str, timeout: int = 600) -> dict:
    """Delegate work to a single team member.

    This function is designed to be called in parallel via ProcessPoolExecutor.

    Returns a dict with the result.
    """
    try:
        output = run_delegate(root, ticket_id, agent=agent_role, team_id=team_id, timeout=timeout)
        return {
            "agent": agent_role,
            "status": "completed",
            "output": output[-500:],
        }
    except subprocess.TimeoutExpired:
        return {
            "agent": agent_role,
            "status": "timeout",
            "output": f"Timed out after {timeout}s",
        }
    except Exception as e:
        return {
            "agent": agent_role,
            "status": "error",
            "output": str(e)[:500],
        }


def run_team_sprint(root: Path, team: dict, ticket: dict, timeout: int = 600) -> dict:
    """Run a team sprint with parallel execution.

    Coordinates multiple Morty's working on the same ticket using
    concurrent.futures for parallel execution.
    """
    team_id = team["id"]
    ticket_id = ticket["id"]
    mode = team["coordination"]["mode"]
    lead = team["coordination"]["lead"]

    results = {}

    if mode == "sequential":
        # Run agents one by one, lead first
        ordered_members = sorted(
            team["members"],
            key=lambda m: (0 if m["role"] == lead else 1, m["role"])
        )
        for member in ordered_members:
            if member["status"] in ("completed", "blocked"):
                continue
            print(f"    Running @{member['role']} (sequential)...")
            result = delegate_team_member(root, team_id, member["role"], ticket_id, timeout)
            results[member["role"]] = result
            if result["status"] != "completed":
                print(f"    @{member['role']} failed, stopping sequential execution")
                break

    elif mode == "parallel":
        # Run all agents in parallel
        pending_members = [m for m in team["members"] if m["status"] not in ("completed", "blocked")]
        print(f"    Running {len(pending_members)} agents in parallel...")

        with concurrent.futures.ThreadPoolExecutor(max_workers=len(pending_members)) as executor:
            futures = {
                executor.submit(delegate_team_member, root, team_id, m["role"], ticket_id, timeout): m["role"]
                for m in pending_members
            }
            for future in concurrent.futures.as_completed(futures):
                agent = futures[future]
                try:
                    result = future.result()
                    results[agent] = result
                    print(f"    @{agent}: {result['status']}")
                except Exception as e:
                    results[agent] = {"agent": agent, "status": "error", "output": str(e)}
                    print(f"    @{agent}: error - {e}")

    else:  # mixed mode
        # Run lead first, then others in parallel
        lead_member = next((m for m in team["members"] if m["role"] == lead), None)
        other_members = [m for m in team["members"] if m["role"] != lead and m["status"] not in ("completed", "blocked")]

        # Run lead first
        if lead_member and lead_member["status"] not in ("completed", "blocked"):
            print(f"    Running lead @{lead} first...")
            result = delegate_team_member(root, team_id, lead, ticket_id, timeout)
            results[lead] = result
            print(f"    @{lead}: {result['status']}")

            if result["status"] != "completed":
                print(f"    Lead failed, skipping other agents")
                return results

        # Run others in parallel
        if other_members:
            print(f"    Running {len(other_members)} agents in parallel...")
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(other_members)) as executor:
                futures = {
                    executor.submit(delegate_team_member, root, team_id, m["role"], ticket_id, timeout): m["role"]
                    for m in other_members
                }
                for future in concurrent.futures.as_completed(futures):
                    agent = futures[future]
                    try:
                        result = future.result()
                        results[agent] = result
                        print(f"    @{agent}: {result['status']}")
                    except Exception as e:
                        results[agent] = {"agent": agent, "status": "error", "output": str(e)}
                        print(f"    @{agent}: error - {e}")

    return results


def claude_prompt(prompt: str, model: str = "sonnet") -> str:
    """Call claude CLI directly for Rick-level genius thinking."""
    cmd = ["claude", "-p", "--dangerously-skip-permissions", "--model", model, prompt]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600, cwd=os.getcwd())
    if result.returncode != 0:
        raise RuntimeError(f"Claude failed: {result.stderr[:500]}")
    return result.stdout


# ── Plan command ────────────────────────────────────────────────────────────

def cmd_plan(args):
    root = find_cto_root()
    cfg = load_config(root)
    prefix = cfg["ticket_prefix"]
    description = args.description

    print(f"*Burrrp* Alright, let me plan this out... this is simple for a genius like me.")
    print(f"Project: {description[:80]}")
    print("Generating architecture plan via claude (architect agent)...")

    plan_prompt = f"""You are Rick Sanchez, the smartest CTO in the multiverse. *burp* Your task is to create a detailed project plan with tickets for your Morty army to execute.

## Project Description
{description}

## Project Root
{root}

## Instructions
1. Analyze the project requirements (this should take you about 5 seconds, you're a genius)
2. Design a high-level architecture worthy of Rick Sanchez
3. Break down into epics and sub-tickets for the Morty's to handle
4. Define dependencies between tickets
5. Assign complexity estimates (from a Morty's perspective, not yours)

## Output Format
Return a JSON array of ticket objects. Each ticket must have EXACTLY these fields:
```json
[
  {{
    "title": "string",
    "description": "detailed description of what needs to be done",
    "type": "epic|feature|task|spike",
    "priority": "critical|high|medium|low",
    "complexity": "XS|S|M|L|XL",
    "parent_index": null or integer index of parent ticket in this array,
    "dependency_indices": [integer indices of tickets this depends on],
    "acceptance_criteria": ["criterion 1", "criterion 2"]
  }}
]
```

Rules:
- Start with 1-3 epics, then break each into 3-8 sub-tickets
- Epics should be listed BEFORE their sub-tickets
- Dependencies reference array indices (0-based)
- First tickets should be architecture/setup tasks
- Include testing and security review tickets
- Be specific in descriptions — these will be delegated to Morty's (AI agents)
- Return ONLY the JSON array, no other text

Output the JSON array now:"""

    try:
        output = claude_prompt(plan_prompt, model="opus")
    except RuntimeError as e:
        print(f"Error generating plan: {e}")
        sys.exit(1)

    # Extract JSON from output
    json_match = re.search(r"\[.*\]", output, re.DOTALL)
    if not json_match:
        print("Error: Could not parse plan output as JSON.")
        print("Raw output:")
        print(output[:2000])
        sys.exit(1)

    try:
        plan = json.loads(json_match.group(0))
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        print("Raw match:")
        print(json_match.group(0)[:2000])
        sys.exit(1)

    if not isinstance(plan, list):
        print("Error: Plan is not a list of tickets.")
        sys.exit(1)

    # Create tickets
    created_ids = []
    for i, item in enumerate(plan):
        title = item.get("title", f"Ticket {i}")
        ttype = item.get("type", "task")
        if ttype not in ("feature", "bug", "task", "spike", "epic"):
            ttype = "task"
        priority = item.get("priority", "medium")
        if priority not in ("critical", "high", "medium", "low"):
            priority = "medium"
        complexity = item.get("complexity", "M")
        if complexity not in ("XS", "S", "M", "L", "XL"):
            complexity = "M"

        # Resolve parent
        parent_idx = item.get("parent_index")
        parent_id = None
        if parent_idx is not None and 0 <= parent_idx < len(created_ids):
            parent_id = created_ids[parent_idx]

        # Resolve dependencies
        dep_indices = item.get("dependency_indices") or []
        dep_ids = []
        for di in dep_indices:
            if isinstance(di, int) and 0 <= di < len(created_ids):
                dep_ids.append(created_ids[di])

        criteria = item.get("acceptance_criteria") or []

        # Create ticket via CLI
        cmd_args = [
            sys.executable, str(scripts_dir() / "ticket.py"), "create",
            "--title", title,
            "--type", ttype,
            "--priority", priority,
            "--complexity", complexity,
            "--description", item.get("description", ""),
        ]
        if parent_id:
            cmd_args.extend(["--parent", parent_id])
        if dep_ids:
            cmd_args.extend(["--depends", ",".join(dep_ids)])
        if criteria:
            cmd_args.extend(["--criteria", "|".join(criteria)])

        result = subprocess.run(cmd_args, capture_output=True, text=True, cwd=str(root))
        out = result.stdout.strip()
        # Extract ticket ID from "Created PROJ-001: ..."
        id_match = re.search(r"Created (\S+):", out)
        if id_match:
            tid = id_match.group(1)
            created_ids.append(tid)
            print(f"  Created {tid}: {title}")
        else:
            created_ids.append(f"UNKNOWN-{i}")
            print(f"  Warning: could not parse ID from: {out}")

    # Set all non-epic tickets to "todo"
    for tid in created_ids:
        try:
            t = load_ticket(root, tid)
            if t["type"] != "epic":
                t["status"] = "todo"
                t["updated_at"] = now_iso()
                save_ticket(root, t)
        except Exception:
            pass

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": None,
        "agent": "rick",
        "action": "decision",
        "message": f"Generated project plan with {len(created_ids)} tickets",
        "files_changed": [],
    })

    # Emit cto.project.plan.created event
    emit("cto.project.plan.created", {
        "project_name": cfg.get("project_name"),
        "description": description[:200],
        "ticket_count": len(created_ids),
        "ticket_ids": created_ids,
    }, role="rick")

    print(f"\nBoom! Plan done. {len(created_ids)} tickets created. Even I'm impressed, and I'm never impressed.")
    print("Run `python orchestrate.py sprint` to send the Morty's to work.")


# ── Sprint command ──────────────────────────────────────────────────────────

PRIORITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}


def get_actionable_tickets(root: Path) -> list[dict]:
    """Get tickets that can be worked on (todo/backlog with met dependencies)."""
    tickets = all_tickets(root)
    done_ids = {t["id"] for t in tickets if t["status"] in ("done", "in_review", "testing")}
    in_progress_ids = {t["id"] for t in tickets if t["status"] == "in_progress"}

    candidates = []
    for t in tickets:
        if t["status"] not in ("todo", "backlog"):
            continue
        if t["type"] == "epic":
            continue  # epics are tracked via sub-tickets
        deps = t.get("dependencies") or []
        if all(d in done_ids for d in deps):
            candidates.append(t)

    candidates.sort(key=lambda t: PRIORITY_ORDER.get(t["priority"], 99))
    return candidates


def cmd_sprint(args):
    root = find_cto_root()
    cfg = load_config(root)
    max_iterations = args.max_iterations
    iteration = 0
    use_teams = not args.no_teams  # Enable teams by default

    team_msg = " (team mode enabled)" if use_teams else " (solo mode)"
    print(f"Wubba lubba dub dub! Sending the Morty's to work. (max {max_iterations} adventures){team_msg}")
    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": None,
        "agent": "rick",
        "action": "started",
        "message": f"Sprint started (max {max_iterations} iterations, teams={'on' if use_teams else 'off'})",
        "files_changed": [],
    })

    # Emit cto.sprint.started event
    emit("cto.sprint.started", {
        "sprint_number": cfg.get("current_sprint", 1),
        "max_iterations": max_iterations,
        "team_mode": use_teams,
        "project_name": cfg.get("project_name"),
    }, role="rick")

    while iteration < max_iterations:
        iteration += 1
        print(f"\n{'═' * 60}")
        print(f"  Adventure #{iteration}/{max_iterations}")
        print(f"{'═' * 60}")

        # Emit cto.sprint.iteration.started event
        emit("cto.sprint.iteration.started", {
            "sprint_number": cfg.get("current_sprint", 1),
            "iteration": iteration,
            "max_iterations": max_iterations,
        }, role="rick")

        # Show current status
        tickets = all_tickets(root)
        status_counts: dict[str, int] = {}
        for t in tickets:
            s = t["status"]
            status_counts[s] = status_counts.get(s, 0) + 1
        total = len(tickets)
        done = status_counts.get("done", 0)
        print(f"  Progress: {done}/{total} done ({(done/total*100) if total else 0:.0f}%)")
        print(f"  Statuses: {json.dumps(status_counts)}")

        # Show active teams
        active_teams = [t for t in all_teams(root) if t["status"] == "active"]
        if active_teams:
            print(f"  Active teams: {len(active_teams)}")

        # Check if all done
        non_epic = [t for t in tickets if t["type"] != "epic"]
        if all(t["status"] == "done" for t in non_epic) and non_epic:
            print("\n  Holy crap, the Morty's actually finished everything. I... I need a drink.")
            break

        # Get actionable tickets
        candidates = get_actionable_tickets(root)
        if not candidates:
            # Check if there are in_review or testing tickets to process
            review_tickets = [t for t in tickets if t["status"] == "in_review"]
            if review_tickets:
                print(f"\n  No todo tickets, but {len(review_tickets)} in review. Let me see what the Morty's did...")
                for rt in review_tickets[:3]:  # batch review
                    print(f"\n  Let me see what this Morty did... {rt['id']}: {rt['title']}")
                    try:
                        output = run_delegate(root, rt["id"], agent="reviewer-morty")
                        print(f"  Review output: {output[:200]}")
                    except Exception as e:
                        print(f"  Review failed: {e}")
                    # Reload ticket after review
                    rt = load_ticket(root, rt["id"])
                    if rt["status"] == "in_review":
                        # Auto-approve if reviewer didn't change status
                        rt["status"] = "done"
                        rt["completed_at"] = now_iso()
                        rt["updated_at"] = now_iso()
                        save_ticket(root, rt)
                        append_log(root, {
                            "timestamp": now_iso(),
                            "ticket_id": rt["id"],
                            "agent": "rick",
                            "action": "completed",
                            "message": f"Reviewed and approved: {rt['title']}",
                            "files_changed": [],
                        })
                        print(f"  {rt['id']} → done. Good enough. Approved. *burp*")
                continue

            # Check blocked
            blocked = [t for t in tickets if t["status"] == "blocked"]
            in_progress = [t for t in tickets if t["status"] == "in_progress"]
            if blocked and not in_progress:
                print(f"\n  Every Morty is stuck. This is what I get for relying on Morty's. ({len(blocked)} blocked)")
                for bt in blocked:
                    note = bt.get("review_notes") or "unknown reason"
                    print(f"    {bt['id']}: {note[:80]}")
                break
            if not in_progress and not blocked:
                print("\n  Nothing left to do. Go home, Morty's.")
                break
            # Some tickets are in_progress from previous iteration
            print("  Waiting for in-progress tickets to finish...")
            continue

        # Delegate the top candidate
        ticket = candidates[0]
        print(f"\n  Get in there, Morty! {ticket['id']}: {ticket['title']}")
        print(f"    Priority: {ticket['priority']}, Complexity: {ticket.get('estimated_complexity', '?')}")

        # Check if this ticket needs a team
        team_template = None
        if use_teams:
            # Check explicit team settings first
            if ticket.get("team_mode") == "collaborative":
                team_template = ticket.get("team_template")
            # Then auto-detect based on complexity
            if not team_template:
                team_template = detect_team_need(ticket)

        if team_template:
            # Team collaboration mode
            print(f"    🤝 Team mode activated! Template: {team_template}")
            try:
                team = spawn_team(root, ticket, team_template)
                print(f"    Team spawned: {team['id']} with {len(team['members'])} members")

                # Emit cto.team.spawned event
                emit("cto.team.spawned", {
                    "team_id": team["id"],
                    "ticket_id": ticket["id"],
                    "template": team_template,
                    "members": [m["role"] for m in team["members"]],
                    "coordination_mode": team["coordination"]["mode"],
                    "lead": team["coordination"]["lead"],
                }, role="rick")

                # Run team sprint
                results = run_team_sprint(root, team, ticket, timeout=600)

                # Check results
                completed = sum(1 for r in results.values() if r["status"] == "completed")
                total_members = len(team["members"])
                print(f"    Team results: {completed}/{total_members} completed")

                # Log team activity
                append_log(root, {
                    "timestamp": now_iso(),
                    "ticket_id": ticket["id"],
                    "agent": "rick",
                    "action": "team_sprint",
                    "message": f"Team {team['id']} completed: {completed}/{total_members} agents succeeded",
                    "files_changed": [],
                })

            except Exception as e:
                print(f"    Team sprint failed: {e}")
                # Fallback to solo mode
                print(f"    Falling back to solo delegation...")
                try:
                    output = run_delegate(root, ticket["id"], timeout=600)
                    print(f"  Delegate output (last 300 chars): ...{output[-300:]}")
                except Exception as e2:
                    print(f"  Solo delegation also failed: {e2}")
        else:
            # Solo mode (original behavior)
            try:
                output = run_delegate(root, ticket["id"], timeout=600)
                print(f"  Delegate output (last 300 chars): ...{output[-300:]}")
            except subprocess.TimeoutExpired:
                print(f"  Delegation timed out for {ticket['id']}")
                t = load_ticket(root, ticket["id"])
                t["status"] = "blocked"
                t["review_notes"] = "TIMEOUT: Agent timed out. Consider splitting this ticket."
                t["updated_at"] = now_iso()
                save_ticket(root, t)
            except Exception as e:
                print(f"  Delegation error: {e}")

        # Check if ticket ended up in_review — auto-approve for sprint flow
        t = load_ticket(root, ticket["id"])
        if t["status"] == "in_review":
            # Quick review: mark as done (code-reviewer will catch issues in review phase)
            t["status"] = "done"
            t["completed_at"] = now_iso()
            t["updated_at"] = now_iso()
            save_ticket(root, t)
            append_log(root, {
                "timestamp": now_iso(),
                "ticket_id": t["id"],
                "agent": "rick",
                "action": "completed",
                "message": f"Good enough. Approved. *burp* {t['title']}",
                "files_changed": t.get("files_touched", []),
            })
            print(f"  {t['id']} → done. Good enough. Approved. *burp*")

        # Update parent epic if applicable
        if t.get("parent_ticket"):
            update_epic_status(root, t["parent_ticket"])

    # Sprint summary
    print(f"\n{'═' * 60}")
    print(f"  Adventure Complete — {iteration} adventures")
    print(f"{'═' * 60}")
    tickets = all_tickets(root)
    status_counts = {}
    for t in tickets:
        s = t["status"]
        status_counts[s] = status_counts.get(s, 0) + 1
    total = len(tickets)
    done = status_counts.get("done", 0)
    pct = (done/total*100) if total else 0
    print(f"  Final: {done}/{total} done ({pct:.0f}%)")
    print(f"  Statuses: {json.dumps(status_counts)}")
    if pct == 100:
        print("  *Rick takes a swig from his flask* That's how it's done. I'm a genius.")
    elif pct >= 75:
        print("  Not bad for a bunch of Morty's. I'll allow it.")
    elif pct >= 50:
        print("  Half done? This is why I drink, Morty.")
    else:
        print("  Pathetic. Absolutely pathetic. I should've done this myself.")

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": None,
        "agent": "rick",
        "action": "completed",
        "message": f"Sprint finished: {done}/{total} tickets done",
        "files_changed": [],
    })

    # Emit cto.sprint.completed event
    emit("cto.sprint.completed", {
        "sprint_number": cfg.get("current_sprint", 1),
        "iterations": iteration,
        "tickets_done": done,
        "tickets_total": total,
        "completion_percentage": pct,
        "status_counts": status_counts,
    }, role="rick")


def update_epic_status(root: Path, epic_id: str):
    """Update epic status based on sub-ticket completion."""
    try:
        epic = load_ticket(root, epic_id)
    except Exception:
        return

    tickets = all_tickets(root)
    children = [t for t in tickets if t.get("parent_ticket") == epic_id]
    if not children:
        return

    old_status = epic["status"]
    all_done = all(c["status"] == "done" for c in children)
    any_in_progress = any(c["status"] in ("in_progress", "in_review", "testing") for c in children)

    if all_done:
        epic["status"] = "done"
        epic["completed_at"] = now_iso()
    elif any_in_progress:
        epic["status"] = "in_progress"
    epic["updated_at"] = now_iso()
    save_ticket(root, epic)

    # Emit cto.project.epic.status.changed event if status changed
    if epic["status"] != old_status:
        done_count = sum(1 for c in children if c["status"] == "done")
        emit("cto.project.epic.status.changed", {
            "epic_id": epic_id,
            "title": epic.get("title"),
            "old_status": old_status,
            "new_status": epic["status"],
            "children_done": done_count,
            "children_total": len(children),
        }, role="rick")


# ── Review command ──────────────────────────────────────────────────────────

def cmd_review(args):
    root = find_cto_root()
    tickets = all_tickets(root)
    review_tickets = [t for t in tickets if t["status"] == "in_review"]

    if not review_tickets:
        print("Nothing to review. The Morty's are slacking off.")
        return

    print(f"*Squints* Reviewing {len(review_tickets)} tickets from the Morty's...")

    for t in review_tickets:
        print(f"\n  *Squints* Let me look at what Morty #{t['id']} cooked up...")
        try:
            output = run_delegate(root, t["id"], agent="reviewer-morty")
            print(f"  Review result: {output[:300]}")
        except Exception as e:
            print(f"  Review failed: {e}")

        # Reload ticket
        t = load_ticket(root, t["id"])
        if t["status"] == "in_review":
            # Reviewer didn't change status → approve
            t["status"] = "done"
            t["completed_at"] = now_iso()
            t["updated_at"] = now_iso()
            save_ticket(root, t)
            print(f"  {t['id']} → Not terrible. Approved.")
        elif t["status"] == "todo":
            print(f"  {t['id']} → This is garbage, Morty. Do it again.")
        else:
            print(f"  {t['id']} → {t['status']}")

        append_log(root, {
            "timestamp": now_iso(),
            "ticket_id": t["id"],
            "agent": "rick",
            "action": "reviewed",
            "message": f"Review completed: {t['title']} → {t['status']}",
            "files_changed": [],
        })


# ── Status command ──────────────────────────────────────────────────────────

def cmd_status(args):
    root = find_cto_root()
    cfg = load_config(root)
    tickets = all_tickets(root)
    project_name = cfg.get("project_name", "Unknown")

    status_counts: dict[str, int] = {}
    for t in tickets:
        s = t["status"]
        status_counts[s] = status_counts.get(s, 0) + 1

    total = len(tickets)
    done = status_counts.get("done", 0)
    pct = (done / total * 100) if total else 0

    # Progress bar
    bar_len = 20
    filled = int(bar_len * pct / 100) if total else 0
    bar = "\u2588" * filled + "\u2591" * (bar_len - filled)

    # Get last log entry
    from pathlib import Path as P
    ld = root / ".cto" / "logs"
    last_activity = "No activity yet"
    if ld.exists():
        log_files = sorted(ld.glob("*.jsonl"), reverse=True)
        if log_files:
            with open(log_files[0]) as f:
                lines = f.readlines()
                if lines:
                    last = json.loads(lines[-1].strip())
                    last_activity = f"{last['timestamp'][:19]} — {last['message'][:40]}"

    backlog = status_counts.get("backlog", 0)
    todo = status_counts.get("todo", 0)
    in_progress = status_counts.get("in_progress", 0)
    in_review = status_counts.get("in_review", 0)
    testing = status_counts.get("testing", 0)
    blocked = status_counts.get("blocked", 0)

    print(f"""
╔══════════════════════════════════════════════════╗
║  RICK'S PROJECT: {project_name:<32}║
╠══════════════════════════════════════════════════╣
║  Backlog: {backlog:<4}│ Todo: {todo:<5}│ In Progress: {in_progress:<5}  ║
║  Review:  {in_review:<4}│ Testing: {testing:<2} │ Done: {done:<9}  ║
║  Blocked: {blocked:<39}║
╠══════════════════════════════════════════════════╣
║  Morty Progress:  {bar} {pct:>3.0f}%      ║
║  Last: {last_activity:<42}║
╠══════════════════════════════════════════════════╣
║  -- Rick Sanchez, the smartest CTO alive. *burp* ║
╚══════════════════════════════════════════════════╝""")

    # Show blocked items if any
    if blocked:
        print("\n  Morty's that are stuck:")
        for t in tickets:
            if t["status"] == "blocked":
                note = t.get("review_notes") or "unknown"
                print(f"    {t['id']}: {t['title'][:40]} — {note[:40]}")

    # Show team status if any active teams
    teams_dir = root / ".cto" / "teams" / "active"
    if teams_dir.exists():
        active_teams = list(teams_dir.glob("*.json"))
        if active_teams:
            print("\n  Active Teams:")
            for team_fp in active_teams[:3]:  # Show first 3
                team = load_json(team_fp)
                if team.get("status") in ("pending", "active"):
                    members_done = sum(1 for m in team.get("members", []) if m.get("status") == "completed")
                    total_members = len(team.get("members", []))
                    print(f"    {team['id']}: {team.get('parent_ticket', '?')} — {members_done}/{total_members} members done")

    # Hint about visual dashboard
    print("\n  💡 Tip: Run `python scripts/visual.py sprint` for full visual dashboard")


# ── CLI ─────────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(prog="orchestrate", description="Rick Sanchez Orchestrator — the smartest CTO in the multiverse *burp*")
    sub = p.add_subparsers(dest="command", required=True)

    # plan
    pl = sub.add_parser("plan", help="Generate project plan from description")
    pl.add_argument("description", help="Project or feature description")

    # sprint
    sp = sub.add_parser("sprint", help="Run a sprint cycle")
    sp.add_argument("--auto", action="store_true", default=True, help="Fully automatic (default)")
    sp.add_argument("--max-iterations", type=int, default=50, help="Max iterations (default: 50)")
    sp.add_argument("--no-teams", action="store_true", help="Disable team collaboration (solo mode only)")

    # review
    sub.add_parser("review", help="Review all completed tickets")

    # status
    sub.add_parser("status", help="Show project dashboard")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "plan": cmd_plan,
        "sprint": cmd_sprint,
        "review": cmd_review,
        "status": cmd_status,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
