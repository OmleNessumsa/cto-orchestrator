#!/usr/bin/env python3
"""CTO Orchestrator — Prometheus Self-Evolution Engine.

*Burrrp* — Rick doesn't stay static. Project Prometheus scans the internet for
improvements, evaluates proposals autonomously, and applies upgrades via Morty
sub-agents. Everything is logged with rollback capability.

Because unlike you people, Rick improves himself. Constantly.

Commands:
  scan     — Scan internet for improvement proposals
  evolve   — Apply pending proposals via Morty delegation
  status   — Prometheus dashboard (pending/applied/rejected)
  history  — Evolution ledger (chronological)
  rollback — Restore files from pre-upgrade snapshot
"""

import argparse
import json
import os
import py_compile
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Import roro event emitter
try:
    from roro_events import emit
except ImportError:
    def emit(*args, **kwargs):
        pass

# Import security utilities
try:
    from security_utils import sanitize_prompt_content, sanitize_text_input
except ImportError:
    def sanitize_prompt_content(content):
        return (content or "")[:10000].replace('\x00', '')
    def sanitize_text_input(text, max_length=5000):
        return (text or "")[:max_length].replace('\x00', '')


# ── Self-protection ──────────────────────────────────────────────────────────

SELF_PROTECTED_FILES = {"prometheus.py"}

# ── Safety limits ────────────────────────────────────────────────────────────

MAX_PROPOSALS_PER_CATEGORY = 5
MAX_AUTO_APPLIES_PER_RUN = 3

# ── Scan categories ──────────────────────────────────────────────────────────

SCAN_CATEGORIES = {
    "agent-patterns": "Multi-agent orchestration patterns (crew.ai, autogen, langgraph, swarm frameworks)",
    "prompt-engineering": "System prompt design, chain-of-thought techniques, structured output patterns",
    "ui-ux": "SwiftUI best practices, terminal UX patterns, macOS HIG, Rick Terminal design improvements",
    "security": "OWASP updates, prompt injection prevention, supply chain security, LLM security",
    "tooling": "Claude Code features, MCP tool patterns, plugin architectures, developer tooling",
    "claude-features": "Anthropic API updates, model capabilities, Claude best practices, new features",
}


# ── Shared helpers (same patterns as delegate.py / orchestrate.py) ───────────

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


def save_json(fp: Path, data: dict | list):
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


def append_log(root: Path, entry: dict):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ld = root / ".cto" / "logs"
    ld.mkdir(parents=True, exist_ok=True)
    fp = ld / f"{today}.jsonl"
    with open(fp, "a") as f:
        f.write(json.dumps(entry) + "\n")


def scripts_dir() -> Path:
    return Path(__file__).parent.resolve()


# ── Prometheus directory management ──────────────────────────────────────────

def ensure_prometheus_dirs(root: Path) -> dict[str, Path]:
    """Create and return all Prometheus data directories."""
    base = root / ".cto" / "prometheus"
    dirs = {
        "base": base,
        "proposals": base / "proposals",
        "applied": base / "applied",
        "rejected": base / "rejected",
        "snapshots": base / "snapshots",
    }
    for d in dirs.values():
        d.mkdir(parents=True, exist_ok=True)

    # Ensure ledger exists
    ledger = base / "ledger.json"
    if not ledger.exists():
        save_json(ledger, [])

    return dirs


def load_ledger(root: Path) -> list:
    fp = root / ".cto" / "prometheus" / "ledger.json"
    if not fp.exists():
        return []
    return json.loads(fp.read_text())


def append_ledger(root: Path, entry: dict):
    ledger = load_ledger(root)
    ledger.append(entry)
    save_json(root / ".cto" / "prometheus" / "ledger.json", ledger)


# ── Proposal ID generation ───────────────────────────────────────────────────

def next_proposal_id(dirs: dict[str, Path]) -> str:
    """Generate next PROM-NNN ID based on existing proposals across all dirs."""
    max_num = 0
    for subdir in ("proposals", "applied", "rejected"):
        d = dirs[subdir]
        for fp in d.glob("PROM-*.json"):
            match = re.match(r"PROM-(\d+)", fp.stem)
            if match:
                max_num = max(max_num, int(match.group(1)))
    return f"PROM-{max_num + 1:03d}"


# ── Validation ───────────────────────────────────────────────────────────────

def validate_python_syntax(filepath: str) -> bool:
    """Validate Python file syntax without executing."""
    try:
        py_compile.compile(filepath, doraise=True)
        return True
    except py_compile.PyCompileError as e:
        print(f"  Syntax error in {filepath}: {e}", file=sys.stderr)
        return False


def is_self_protected(target_files: list[str]) -> bool:
    """Check if any target files are self-protected."""
    for tf in target_files:
        basename = os.path.basename(tf)
        if basename in SELF_PROTECTED_FILES:
            return True
    return False


# ── Snapshot management ──────────────────────────────────────────────────────

def create_snapshot(root: Path, dirs: dict[str, Path], proposal_id: str,
                    target_files: list[str]) -> Path | None:
    """Create a pre-upgrade snapshot of target files.

    Returns the snapshot directory path, or None if no files to snapshot.
    """
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    snap_dir = dirs["snapshots"] / f"snap-{proposal_id}-{timestamp}"
    snap_dir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "proposal_id": proposal_id,
        "created_at": now_iso(),
        "files": {},
    }

    found_files = False
    for rel_path in target_files:
        full_path = root / rel_path
        if full_path.exists():
            # Encode path as safe filename: scripts/delegate.py -> scripts__delegate.py
            safe_name = rel_path.replace("/", "__").replace("\\", "__")
            shutil.copy2(full_path, snap_dir / safe_name)
            manifest["files"][rel_path] = {
                "snapshot_name": safe_name,
                "original_size": full_path.stat().st_size,
            }
            found_files = True

    if not found_files:
        shutil.rmtree(snap_dir)
        return None

    save_json(snap_dir / "manifest.json", manifest)
    return snap_dir


def restore_snapshot(root: Path, snap_dir: Path) -> list[str]:
    """Restore files from a snapshot. Returns list of restored file paths."""
    manifest_fp = snap_dir / "manifest.json"
    if not manifest_fp.exists():
        print(f"Error: No manifest found in {snap_dir}", file=sys.stderr)
        return []

    manifest = load_json(manifest_fp)
    restored = []

    for rel_path, info in manifest["files"].items():
        safe_name = info["snapshot_name"]
        snapshot_file = snap_dir / safe_name
        target_file = root / rel_path

        if snapshot_file.exists():
            # Ensure target directory exists
            target_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(snapshot_file, target_file)
            restored.append(rel_path)
            print(f"  Restored: {rel_path}")
        else:
            print(f"  Warning: Snapshot file missing: {safe_name}", file=sys.stderr)

    return restored


# ── Scan prompt builder ──────────────────────────────────────────────────────

def build_scan_prompt(category: str, root: Path) -> str:
    """Build the scan prompt for a specific category."""
    category_desc = SCAN_CATEGORIES.get(category, category)

    # Read existing script files to provide context
    scripts = []
    for fp in sorted((root / "scripts").glob("*.py")):
        scripts.append(fp.name)
    scripts_list = ", ".join(scripts) if scripts else "(none)"

    return f"""You are a research analyst for an AI-powered CTO orchestration system called "CTO Orchestrator" (Rick Sanchez themed). Your task is to scan for the latest improvements and best practices in a specific category.

## Category: {category}
{category_desc}

## Current System Context
The CTO Orchestrator is a Python-based multi-agent system that:
- Uses `claude -p` subprocesses to delegate work to specialized agents (Morty's)
- Has a ticket-based workflow (plan → sprint → delegate → review)
- Includes a Rick Terminal (SwiftUI macOS app) for visualization
- Scripts: {scripts_list}
- Uses roro event emission for real-time observability

## Your Task
Search the web for the latest improvements, patterns, and best practices relevant to this category that could improve the CTO Orchestrator system.

For each improvement found, create a proposal with a specific, actionable description.

## Output Format
Return a JSON array of proposals (max {MAX_PROPOSALS_PER_CATEGORY}). Each proposal MUST have exactly these fields:
```json
[
  {{
    "title": "Short descriptive title",
    "category": "{category}",
    "source": "URL or search description where you found this",
    "description": "What to improve and why",
    "impact_score": 8,
    "risk_score": 3,
    "effort_score": 4,
    "target_files": ["scripts/delegate.py"],
    "proposed_changes": "Specific description of what code changes to make"
  }}
]
```

Scoring guide:
- impact_score (1-10): How much this improves the system. 10 = transformative.
- risk_score (1-10): How likely this breaks something. 10 = very risky.
- effort_score (1-10): How much work to implement. 10 = massive effort.

Rules:
- Be SPECIFIC about what files to modify and what changes to make
- Focus on practical, implementable improvements (not theoretical)
- Target files must be relative paths from the project root
- Return ONLY the JSON array, no other text
- Max {MAX_PROPOSALS_PER_CATEGORY} proposals per scan"""


# ── Claude subprocess ────────────────────────────────────────────────────────

def claude_scan(prompt: str, model: str = "opus", timeout: int = 300) -> str:
    """Run a Claude scan with web search capability.

    Uses `claude -p --model opus` for scanning.
    """
    safe_prompt = sanitize_prompt_content(prompt)
    cmd = ["claude", "-p", "--model", model, safe_prompt]

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
            raise RuntimeError(f"Claude scan failed: {stderr}")
        return result.stdout
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Scan timed out after {timeout}s")


def delegate_evolve(prompt: str, model: str = "sonnet", timeout: int = 300) -> str:
    """Delegate an evolution task to a Morty via claude subprocess."""
    safe_prompt = sanitize_prompt_content(prompt)
    cmd = ["claude", "-p", "--model", model, safe_prompt]

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
            raise RuntimeError(f"Evolve delegation failed: {stderr}")
        return result.stdout
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Evolve timed out after {timeout}s")


# ── Command: scan ────────────────────────────────────────────────────────────

def cmd_scan(args):
    """Scan for improvement proposals across categories."""
    root = find_cto_root()
    dirs = ensure_prometheus_dirs(root)

    # Determine categories to scan
    if args.categories:
        categories = [c.strip() for c in args.categories.split(",")]
        invalid = [c for c in categories if c not in SCAN_CATEGORIES]
        if invalid:
            print(f"Error: Unknown categories: {', '.join(invalid)}", file=sys.stderr)
            print(f"Valid: {', '.join(SCAN_CATEGORIES.keys())}", file=sys.stderr)
            sys.exit(1)
    else:
        categories = list(SCAN_CATEGORIES.keys())

    model = args.model or "opus"
    total_proposals = 0

    print(f"*Burrrp* Prometheus scanning {len(categories)} categories... (model: {model})")
    print(f"Categories: {', '.join(categories)}")

    emit("cto.prometheus.scan.started", {
        "categories": categories,
        "model": model,
    }, role="rick")

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": None,
        "agent": "prometheus",
        "action": "scan_started",
        "message": f"Scanning {len(categories)} categories: {', '.join(categories)}",
        "files_changed": [],
    })

    for category in categories:
        print(f"\n{'─' * 50}")
        print(f"  Scanning: {category}")
        print(f"{'─' * 50}")

        prompt = build_scan_prompt(category, root)

        if args.dry_run:
            print(f"  [DRY RUN] Would scan with {len(prompt)} char prompt")
            continue

        try:
            output = claude_scan(prompt, model=model, timeout=args.timeout)
        except RuntimeError as e:
            print(f"  Scan failed for {category}: {e}")
            continue

        # Parse JSON proposals from output
        json_match = re.search(r"\[.*\]", output, re.DOTALL)
        if not json_match:
            print(f"  No valid JSON proposals found for {category}")
            continue

        try:
            proposals_raw = json.loads(json_match.group(0))
        except json.JSONDecodeError as e:
            print(f"  JSON parse error for {category}: {e}")
            continue

        if not isinstance(proposals_raw, list):
            print(f"  Invalid response for {category}: expected list")
            continue

        # Limit proposals per category
        proposals_raw = proposals_raw[:MAX_PROPOSALS_PER_CATEGORY]

        for item in proposals_raw:
            prom_id = next_proposal_id(dirs)
            target_files = item.get("target_files", [])
            impact = item.get("impact_score", 5)
            risk = item.get("risk_score", 5)
            effort = item.get("effort_score", 5)

            proposal = {
                "id": prom_id,
                "title": sanitize_text_input(item.get("title", "Untitled"), max_length=200),
                "category": category,
                "source": sanitize_text_input(item.get("source", "unknown"), max_length=500),
                "description": sanitize_text_input(item.get("description", ""), max_length=2000),
                "impact_score": max(1, min(10, int(impact))),
                "risk_score": max(1, min(10, int(risk))),
                "effort_score": max(1, min(10, int(effort))),
                "target_files": target_files[:10],
                "proposed_changes": sanitize_text_input(
                    item.get("proposed_changes", ""), max_length=3000
                ),
                "status": "pending",
                "created_at": now_iso(),
                "applied_at": None,
                "rollback_snapshot": None,
            }

            # Self-protection: auto-reject proposals targeting prometheus.py
            if is_self_protected(target_files):
                proposal["status"] = "rejected"
                proposal["reject_reason"] = "Self-protection: cannot modify Prometheus engine"
                save_json(dirs["rejected"] / f"{prom_id}.json", proposal)
                print(f"  {prom_id}: REJECTED (self-protection) — {proposal['title']}")
                append_ledger(root, {
                    "timestamp": now_iso(),
                    "proposal_id": prom_id,
                    "action": "rejected",
                    "reason": "self-protection",
                })
                continue

            # Auto-reject low-value proposals (impact < 5 AND effort > 7)
            if impact < 5 and effort > 7:
                proposal["status"] = "rejected"
                proposal["reject_reason"] = f"Auto-rejected: low impact ({impact}) with high effort ({effort})"
                save_json(dirs["rejected"] / f"{prom_id}.json", proposal)
                print(f"  {prom_id}: REJECTED (low value) — {proposal['title']}")
                append_ledger(root, {
                    "timestamp": now_iso(),
                    "proposal_id": prom_id,
                    "action": "rejected",
                    "reason": f"low-value (impact={impact}, effort={effort})",
                })
                continue

            # Save as pending
            save_json(dirs["proposals"] / f"{prom_id}.json", proposal)
            total_proposals += 1
            print(f"  {prom_id}: {proposal['title']} (impact={impact} risk={risk} effort={effort})")

            emit("cto.prometheus.proposal.created", {
                "proposal_id": prom_id,
                "title": proposal["title"],
                "category": category,
                "impact_score": impact,
                "risk_score": risk,
                "effort_score": effort,
            }, role="rick")

            append_ledger(root, {
                "timestamp": now_iso(),
                "proposal_id": prom_id,
                "action": "created",
                "title": proposal["title"],
                "category": category,
            })

    emit("cto.prometheus.scan.completed", {
        "categories": categories,
        "proposals_created": total_proposals,
    }, role="rick")

    append_log(root, {
        "timestamp": now_iso(),
        "ticket_id": None,
        "agent": "prometheus",
        "action": "scan_completed",
        "message": f"Scan complete: {total_proposals} proposals created",
        "files_changed": [],
    })

    print(f"\nScan complete. {total_proposals} new proposals pending review.")
    if total_proposals:
        print("Run `python scripts/prometheus.py evolve` to apply improvements.")


# ── Command: evolve ──────────────────────────────────────────────────────────

def cmd_evolve(args):
    """Apply pending proposals autonomously via Morty delegation."""
    root = find_cto_root()
    dirs = ensure_prometheus_dirs(root)
    max_applies = args.max_applies or MAX_AUTO_APPLIES_PER_RUN
    model = args.model or "sonnet"

    # Load pending proposals sorted by impact (highest first)
    pending = []
    for fp in dirs["proposals"].glob("PROM-*.json"):
        proposal = load_json(fp)
        if proposal.get("status") == "pending":
            pending.append(proposal)

    pending.sort(key=lambda p: p.get("impact_score", 0), reverse=True)

    if not pending:
        print("No pending proposals. Run `python scripts/prometheus.py scan` first.")
        return

    print(f"*Burrrp* Prometheus evolving... {len(pending)} pending, applying up to {max_applies}")

    emit("cto.prometheus.evolve.started", {
        "pending_count": len(pending),
        "max_applies": max_applies,
        "model": model,
    }, role="rick")

    applied_count = 0

    for proposal in pending[:max_applies]:
        prom_id = proposal["id"]
        print(f"\n{'─' * 50}")
        print(f"  Applying {prom_id}: {proposal['title']}")
        print(f"  Impact: {proposal['impact_score']} | Risk: {proposal['risk_score']} | Effort: {proposal['effort_score']}")
        print(f"  Targets: {', '.join(proposal['target_files'])}")
        print(f"{'─' * 50}")

        if args.dry_run:
            print(f"  [DRY RUN] Would apply {prom_id}")
            continue

        # Double-check self-protection
        if is_self_protected(proposal.get("target_files", [])):
            proposal["status"] = "rejected"
            proposal["reject_reason"] = "Self-protection: cannot modify Prometheus engine"
            save_json(dirs["rejected"] / f"{prom_id}.json", proposal)
            # Remove from proposals
            prop_fp = dirs["proposals"] / f"{prom_id}.json"
            if prop_fp.exists():
                prop_fp.unlink()
            print(f"  REJECTED (self-protection)")
            continue

        # Create pre-upgrade snapshot
        target_files = proposal.get("target_files", [])
        snap_dir = create_snapshot(root, dirs, prom_id, target_files)
        if snap_dir:
            print(f"  Snapshot created: {snap_dir.name}")
            proposal["rollback_snapshot"] = str(snap_dir)

        # Build evolve prompt for Morty delegation
        evolve_prompt = f"""You are a code improvement agent. Apply the following upgrade to the codebase.

## Proposal: {proposal['title']}

### Description
{proposal.get('description', '')}

### Proposed Changes
{proposal.get('proposed_changes', '')}

### Target Files
{chr(10).join('- ' + f for f in target_files)}

### Project Root
{root}

### Rules
1. Apply ONLY the changes described in the proposal
2. Follow existing code conventions
3. Do NOT modify any file named prometheus.py
4. Make minimal, focused changes
5. Preserve existing functionality
6. Execute changes DIRECTLY — modify the actual files

### Report
End with:
### Upgrade Report
**Status**: completed|failed
**Files changed**: [list of files]
**Description**: [what was changed]
"""

        try:
            output = delegate_evolve(evolve_prompt, model=model, timeout=args.timeout)
        except RuntimeError as e:
            print(f"  Evolution failed for {prom_id}: {e}")

            # Rollback if snapshot exists
            if snap_dir and snap_dir.exists():
                print(f"  Rolling back from snapshot...")
                restore_snapshot(root, snap_dir)

            proposal["status"] = "rejected"
            proposal["reject_reason"] = f"Apply failed: {str(e)[:200]}"
            save_json(dirs["rejected"] / f"{prom_id}.json", proposal)
            prop_fp = dirs["proposals"] / f"{prom_id}.json"
            if prop_fp.exists():
                prop_fp.unlink()

            emit("cto.prometheus.evolve.failed", {
                "proposal_id": prom_id,
                "error": str(e)[:200],
            }, role="rick")

            append_ledger(root, {
                "timestamp": now_iso(),
                "proposal_id": prom_id,
                "action": "failed",
                "reason": str(e)[:200],
            })
            continue

        # Validate Python syntax for any .py target files
        syntax_ok = True
        for tf in target_files:
            if tf.endswith(".py"):
                full_path = root / tf
                if full_path.exists():
                    if not validate_python_syntax(str(full_path)):
                        syntax_ok = False
                        print(f"  Syntax validation FAILED for {tf}")
                        break

        if not syntax_ok:
            # Rollback on syntax error
            if snap_dir and snap_dir.exists():
                print(f"  Rolling back due to syntax error...")
                restore_snapshot(root, snap_dir)

            proposal["status"] = "rejected"
            proposal["reject_reason"] = "Syntax validation failed after apply"
            save_json(dirs["rejected"] / f"{prom_id}.json", proposal)
            prop_fp = dirs["proposals"] / f"{prom_id}.json"
            if prop_fp.exists():
                prop_fp.unlink()

            emit("cto.prometheus.evolve.failed", {
                "proposal_id": prom_id,
                "error": "Syntax validation failed",
            }, role="rick")

            append_ledger(root, {
                "timestamp": now_iso(),
                "proposal_id": prom_id,
                "action": "failed",
                "reason": "syntax validation failed",
            })
            continue

        # Mark as applied
        proposal["status"] = "applied"
        proposal["applied_at"] = now_iso()
        save_json(dirs["applied"] / f"{prom_id}.json", proposal)
        prop_fp = dirs["proposals"] / f"{prom_id}.json"
        if prop_fp.exists():
            prop_fp.unlink()

        applied_count += 1
        print(f"  Applied successfully!")

        emit("cto.prometheus.evolve.applied", {
            "proposal_id": prom_id,
            "title": proposal["title"],
            "target_files": target_files,
        }, role="rick")

        append_ledger(root, {
            "timestamp": now_iso(),
            "proposal_id": prom_id,
            "action": "applied",
            "title": proposal["title"],
            "target_files": target_files,
        })

        append_log(root, {
            "timestamp": now_iso(),
            "ticket_id": None,
            "agent": "prometheus",
            "action": "evolved",
            "message": f"Applied {prom_id}: {proposal['title']}",
            "files_changed": target_files,
        })

    print(f"\nEvolution complete. {applied_count}/{min(len(pending), max_applies)} proposals applied.")


# ── Command: rollback ────────────────────────────────────────────────────────

def cmd_rollback(args):
    """Rollback a specific proposal by restoring its snapshot."""
    root = find_cto_root()
    dirs = ensure_prometheus_dirs(root)
    prom_id = args.proposal_id

    # Validate proposal ID format
    if not re.match(r'^PROM-\d{3,}$', prom_id):
        print(f"Error: Invalid proposal ID format: {prom_id}", file=sys.stderr)
        print("Expected format: PROM-001", file=sys.stderr)
        sys.exit(1)

    # Find the proposal (check applied first, then rejected)
    proposal = None
    proposal_fp = None
    for subdir in ("applied", "rejected", "proposals"):
        fp = dirs[subdir] / f"{prom_id}.json"
        if fp.exists():
            proposal = load_json(fp)
            proposal_fp = fp
            break

    if not proposal:
        print(f"Error: Proposal {prom_id} not found.", file=sys.stderr)
        sys.exit(1)

    snap_path = proposal.get("rollback_snapshot")
    if not snap_path:
        print(f"Error: No snapshot available for {prom_id}.", file=sys.stderr)
        sys.exit(1)

    snap_dir = Path(snap_path)
    if not snap_dir.exists():
        print(f"Error: Snapshot directory not found: {snap_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Rolling back {prom_id}: {proposal.get('title', 'unknown')}")
    restored = restore_snapshot(root, snap_dir)

    if restored:
        # Update proposal status
        proposal["status"] = "rolled_back"
        proposal["rolled_back_at"] = now_iso()
        save_json(proposal_fp, proposal)

        emit("cto.prometheus.rollback", {
            "proposal_id": prom_id,
            "title": proposal.get("title"),
            "files_restored": restored,
        }, role="rick")

        append_ledger(root, {
            "timestamp": now_iso(),
            "proposal_id": prom_id,
            "action": "rolled_back",
            "files_restored": restored,
        })

        append_log(root, {
            "timestamp": now_iso(),
            "ticket_id": None,
            "agent": "prometheus",
            "action": "rollback",
            "message": f"Rolled back {prom_id}: {', '.join(restored)}",
            "files_changed": restored,
        })

        print(f"Rollback complete. {len(restored)} files restored.")
    else:
        print("No files were restored.")


# ── Command: status ──────────────────────────────────────────────────────────

def cmd_status(args):
    """Show Prometheus dashboard."""
    root = find_cto_root()
    dirs = ensure_prometheus_dirs(root)

    pending = list(dirs["proposals"].glob("PROM-*.json"))
    applied = list(dirs["applied"].glob("PROM-*.json"))
    rejected = list(dirs["rejected"].glob("PROM-*.json"))

    # Count rolled back from applied
    rolled_back = 0
    for fp in applied:
        p = load_json(fp)
        if p.get("status") == "rolled_back":
            rolled_back += 1

    # Get last ledger entry
    ledger = load_ledger(root)
    last_activity = "No activity yet"
    if ledger:
        last = ledger[-1]
        last_activity = f"{last.get('timestamp', '?')[:19]} — {last.get('action', '?')}: {last.get('proposal_id', '?')}"

    # Category breakdown of pending
    cat_counts: dict[str, int] = {}
    for fp in pending:
        p = load_json(fp)
        cat = p.get("category", "unknown")
        cat_counts[cat] = cat_counts.get(cat, 0) + 1

    print(f"""
+====================================================+
|         PROMETHEUS — Self-Evolution Engine          |
+====================================================+
|  Pending:     {len(pending):<5} | Applied:    {len(applied):<5}        |
|  Rejected:    {len(rejected):<5} | Rolled Back: {rolled_back:<4}       |
+----------------------------------------------------+
|  Last: {last_activity:<43}|
+====================================================+""")

    if cat_counts:
        print("\n  Pending by category:")
        for cat, count in sorted(cat_counts.items()):
            print(f"    {cat:<25} {count}")

    if pending:
        print("\n  Top pending proposals:")
        proposals = []
        for fp in pending:
            proposals.append(load_json(fp))
        proposals.sort(key=lambda p: p.get("impact_score", 0), reverse=True)
        for p in proposals[:5]:
            impact = p.get("impact_score", "?")
            print(f"    {p['id']}: [{impact}/10] {p.get('title', 'untitled')[:50]}")

    print()


# ── Command: history ─────────────────────────────────────────────────────────

def cmd_history(args):
    """Show evolution ledger (chronological)."""
    root = find_cto_root()
    ensure_prometheus_dirs(root)
    ledger = load_ledger(root)

    if not ledger:
        print("No evolution history yet. Run `python scripts/prometheus.py scan` to start.")
        return

    limit = args.limit or 20
    entries = ledger[-limit:]

    print(f"Prometheus Evolution History (last {len(entries)} of {len(ledger)} entries)")
    print(f"{'─' * 60}")

    action_icons = {
        "created": "+",
        "applied": "^",
        "rejected": "x",
        "failed": "!",
        "rolled_back": "<",
    }

    for entry in entries:
        ts = entry.get("timestamp", "?")[:19]
        action = entry.get("action", "?")
        prom_id = entry.get("proposal_id", "?")
        icon = action_icons.get(action, "?")
        extra = ""
        if action == "rejected":
            extra = f" ({entry.get('reason', '?')})"
        elif action == "applied":
            extra = f" ({entry.get('title', '')[:30]})"
        elif action == "created":
            extra = f" [{entry.get('category', '?')}] {entry.get('title', '')[:30]}"
        elif action == "rolled_back":
            files = entry.get("files_restored", [])
            extra = f" ({len(files)} files restored)"

        print(f"  [{icon}] {ts}  {prom_id:<10} {action:<12}{extra}")

    print(f"{'─' * 60}")


# ── CLI ──────────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(
        prog="prometheus",
        description="Prometheus Self-Evolution Engine — Rick improves himself. *burp*",
    )
    sub = p.add_subparsers(dest="command", required=True)

    # scan
    sc = sub.add_parser("scan", help="Scan for improvement proposals")
    sc.add_argument("--categories", default=None,
                    help=f"Comma-separated categories ({', '.join(SCAN_CATEGORIES.keys())})")
    sc.add_argument("--model", default="opus", choices=["opus", "sonnet", "haiku"],
                    help="Model for scanning (default: opus)")
    sc.add_argument("--dry-run", action="store_true", help="Preview without scanning")
    sc.add_argument("--timeout", type=int, default=300, help="Timeout per category (default: 300s)")

    # evolve
    ev = sub.add_parser("evolve", help="Apply pending proposals")
    ev.add_argument("--max-applies", type=int, default=MAX_AUTO_APPLIES_PER_RUN,
                    help=f"Max proposals to apply (default: {MAX_AUTO_APPLIES_PER_RUN})")
    ev.add_argument("--model", default="sonnet", choices=["opus", "sonnet", "haiku"],
                    help="Model for applying (default: sonnet)")
    ev.add_argument("--dry-run", action="store_true", help="Preview without applying")
    ev.add_argument("--timeout", type=int, default=300, help="Timeout per apply (default: 300s)")

    # status
    sub.add_parser("status", help="Prometheus dashboard")

    # history
    hi = sub.add_parser("history", help="Evolution ledger")
    hi.add_argument("--limit", type=int, default=20, help="Number of entries (default: 20)")

    # rollback
    rb = sub.add_parser("rollback", help="Rollback a proposal")
    rb.add_argument("proposal_id", help="Proposal ID to rollback (e.g., PROM-001)")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "scan": cmd_scan,
        "evolve": cmd_evolve,
        "status": cmd_status,
        "history": cmd_history,
        "rollback": cmd_rollback,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
