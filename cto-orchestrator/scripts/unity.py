#!/usr/bin/env python3
"""Unity Security Agent — Shannon Pentest Framework Wrapper.

*Burrrp* — Unity is my security specialist, Morty. She's actually Shannon —
a Temporal-based pentest framework. Way more capable than security-morty
for actual penetration testing.

Unity provides:
- Automated penetration testing via Shannon workflows
- Progress tracking via Temporal queries
- Fallback to static analysis when Temporal isn't available
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def find_cto_root(start: Optional[str] = None) -> Path:
    """Walk up from *start* (default: cwd) until we find a .cto/ directory."""
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
    fp.parent.mkdir(parents=True, exist_ok=True)
    with open(fp, "w") as f:
        json.dump(data, f, indent=2)


def unity_dir(root: Path) -> Path:
    """Unity workflow and results directory."""
    return root / ".cto" / "unity"


def workflows_dir(root: Path) -> Path:
    return unity_dir(root) / "workflows"


def reports_dir(root: Path) -> Path:
    return unity_dir(root) / "reports"


def ensure_unity_dirs(root: Path):
    """Ensure Unity directories exist."""
    workflows_dir(root).mkdir(parents=True, exist_ok=True)
    reports_dir(root).mkdir(parents=True, exist_ok=True)


def append_log(root: Path, entry: dict):
    """Append to daily log file."""
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ld = root / ".cto" / "logs"
    ld.mkdir(parents=True, exist_ok=True)
    fp = ld / f"{today}.jsonl"
    with open(fp, "a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Shannon Integration ──────────────────────────────────────────────────────

SHANNON_PATH = Path(__file__).parent.parent.parent / "vendors" / "shannon"


class UnitySecurityAgent:
    """Shannon wrapper as Unity — Rick's security specialist.

    Unity wraps the Shannon pentest framework to provide automated security
    testing. When Temporal is available, it runs full penetration tests.
    Otherwise, it falls back to static analysis mode.
    """

    def __init__(self, root: Path):
        self.root = root
        self.temporal_available = self._check_temporal()
        self.shannon_available = self._check_shannon()
        ensure_unity_dirs(root)

    def _check_temporal(self) -> bool:
        """Check if Temporal is running and accessible."""
        try:
            result = subprocess.run(
                ["tctl", "cluster", "health"],
                capture_output=True,
                timeout=5,
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def _check_shannon(self) -> bool:
        """Check if Shannon is installed."""
        # Check if vendors/shannon exists
        if SHANNON_PATH.exists() and (SHANNON_PATH / "package.json").exists():
            return True
        # Check if shannon is in PATH
        try:
            result = subprocess.run(
                ["which", "shannon"],
                capture_output=True,
            )
            return result.returncode == 0
        except FileNotFoundError:
            return False

    def _generate_workflow_id(self) -> str:
        """Generate a unique workflow ID."""
        import uuid
        return f"unity-{uuid.uuid4().hex[:8]}"

    def start_pentest(
        self,
        target_url: Optional[str] = None,
        repo_path: Optional[str] = None,
        config_path: Optional[str] = None,
        scope: str = "full",  # full, quick, recon, exploit
    ) -> dict:
        """Start a penetration test.

        Args:
            target_url: URL to test (for live testing)
            repo_path: Path to repository (for code analysis)
            config_path: Path to custom Shannon config
            scope: Test scope (full, quick, recon, exploit)

        Returns:
            Workflow info dict with workflow_id and status
        """
        workflow_id = self._generate_workflow_id()

        workflow = {
            "id": workflow_id,
            "status": "pending",
            "target_url": target_url,
            "repo_path": repo_path,
            "config_path": config_path,
            "scope": scope,
            "mode": "temporal" if self.temporal_available and self.shannon_available else "static",
            "created_at": now_iso(),
            "started_at": None,
            "completed_at": None,
            "progress": 0,
            "current_phase": None,
            "findings": [],
            "error": None,
        }

        # Save workflow state
        fp = workflows_dir(self.root) / f"{workflow_id}.json"
        save_json(fp, workflow)

        # Log the start
        append_log(self.root, {
            "timestamp": now_iso(),
            "ticket_id": None,
            "agent": "unity",
            "action": "started",
            "message": f"Unity pentest started: {workflow_id} (mode: {workflow['mode']})",
            "files_changed": [],
        })

        # Start the actual test
        if workflow["mode"] == "temporal":
            return self._start_shannon_workflow(workflow)
        else:
            return self._start_static_analysis(workflow)

    def _start_shannon_workflow(self, workflow: dict) -> dict:
        """Start a Shannon workflow via Temporal."""
        workflow["status"] = "running"
        workflow["started_at"] = now_iso()
        workflow["current_phase"] = "initializing"

        # Build Shannon command
        shannon_cmd = ["npx", "shannon"]
        if workflow["target_url"]:
            shannon_cmd.extend(["--url", workflow["target_url"]])
        if workflow["repo_path"]:
            shannon_cmd.extend(["--repo", workflow["repo_path"]])
        if workflow["config_path"]:
            shannon_cmd.extend(["--config", workflow["config_path"]])
        shannon_cmd.extend(["--scope", workflow["scope"]])
        shannon_cmd.extend(["--output-json", str(reports_dir(self.root) / f"{workflow['id']}-report.json")])

        try:
            # Start Shannon as a background process
            process = subprocess.Popen(
                shannon_cmd,
                cwd=str(SHANNON_PATH) if SHANNON_PATH.exists() else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            workflow["pid"] = process.pid

        except Exception as e:
            workflow["status"] = "error"
            workflow["error"] = str(e)

        # Save updated workflow
        fp = workflows_dir(self.root) / f"{workflow['id']}.json"
        save_json(fp, workflow)

        return workflow

    def _start_static_analysis(self, workflow: dict) -> dict:
        """Fallback: Run static security analysis via security-morty.

        When Temporal/Shannon aren't available, we delegate to security-morty
        for static code analysis. This provides security insights without
        live exploitation/PoC verification.
        """
        workflow["status"] = "running"
        workflow["started_at"] = now_iso()
        workflow["current_phase"] = "static_analysis"

        # Build a security analysis prompt for security-morty
        repo_path = workflow.get("repo_path") or str(self.root)

        analysis_prompt = f"""You are Unity's static analysis mode. Perform a thorough security review of the codebase.

## Target
Repository: {repo_path}

## Analysis Scope: {workflow['scope']}

## Instructions
1. Scan for OWASP Top 10 vulnerabilities
2. Check authentication and authorization patterns
3. Look for injection vulnerabilities (SQL, XSS, Command)
4. Review secrets and sensitive data handling
5. Check dependency vulnerabilities (if package files exist)
6. Review API security (if applicable)
7. Check for insecure configurations

## Output Format
Return findings as a JSON array:
```json
{{
  "findings": [
    {{
      "severity": "critical|high|medium|low|info",
      "category": "OWASP category or custom",
      "title": "Brief title",
      "description": "Detailed description",
      "file": "path/to/file.py",
      "line": 42,
      "recommendation": "How to fix"
    }}
  ],
  "summary": {{
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "info": 0
  }}
}}
```

Analyze the codebase now:"""

        # Store the prompt for later execution
        workflow["static_prompt"] = analysis_prompt
        workflow["progress"] = 10

        # Save workflow
        fp = workflows_dir(self.root) / f"{workflow['id']}.json"
        save_json(fp, workflow)

        # Execute via security-morty (or directly via claude)
        try:
            scripts_dir = Path(__file__).parent
            delegate_script = scripts_dir / "delegate.py"

            # For static analysis, we run claude directly with the prompt
            result = subprocess.run(
                ["claude", "-p", "--model", "opus", analysis_prompt],
                capture_output=True,
                text=True,
                timeout=600,
                cwd=repo_path,
            )

            workflow["progress"] = 100
            workflow["current_phase"] = "completed"

            # Try to parse findings from output
            output = result.stdout
            try:
                import re
                json_match = re.search(r'\{[\s\S]*"findings"[\s\S]*\}', output)
                if json_match:
                    findings_data = json.loads(json_match.group(0))
                    workflow["findings"] = findings_data.get("findings", [])
                    workflow["summary"] = findings_data.get("summary", {})
            except (json.JSONDecodeError, AttributeError):
                # Store raw output if JSON parsing fails
                workflow["raw_output"] = output[:5000]

            workflow["status"] = "completed"
            workflow["completed_at"] = now_iso()

        except subprocess.TimeoutExpired:
            workflow["status"] = "error"
            workflow["error"] = "Static analysis timed out"
        except Exception as e:
            workflow["status"] = "error"
            workflow["error"] = str(e)

        # Save final workflow state
        fp = workflows_dir(self.root) / f"{workflow['id']}.json"
        save_json(fp, workflow)

        # Generate report
        if workflow["status"] == "completed":
            self._generate_report(workflow)

        return workflow

    def get_progress(self, workflow_id: str) -> dict:
        """Get the progress of a workflow.

        Args:
            workflow_id: The workflow ID

        Returns:
            Progress dict with status, progress %, and current phase
        """
        fp = workflows_dir(self.root) / f"{workflow_id}.json"
        if not fp.exists():
            return {"error": f"Workflow {workflow_id} not found"}

        workflow = load_json(fp)

        # If running via Temporal, query for latest status
        if workflow["mode"] == "temporal" and workflow["status"] == "running":
            # Query Temporal for workflow status
            try:
                result = subprocess.run(
                    ["tctl", "workflow", "describe", "-w", workflow_id],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if "COMPLETED" in result.stdout:
                    workflow["status"] = "completed"
                    workflow["progress"] = 100
                    workflow["completed_at"] = now_iso()
                    save_json(fp, workflow)
                elif "FAILED" in result.stdout:
                    workflow["status"] = "error"
                    workflow["error"] = "Temporal workflow failed"
                    save_json(fp, workflow)
            except Exception:
                pass  # Keep existing status

        return {
            "id": workflow["id"],
            "status": workflow["status"],
            "progress": workflow.get("progress", 0),
            "current_phase": workflow.get("current_phase"),
            "mode": workflow["mode"],
            "started_at": workflow.get("started_at"),
            "completed_at": workflow.get("completed_at"),
            "error": workflow.get("error"),
        }

    def get_report(self, workflow_id: str) -> dict:
        """Get the final report for a completed workflow.

        Args:
            workflow_id: The workflow ID

        Returns:
            Report dict with findings and summary
        """
        # Check for generated report
        report_fp = reports_dir(self.root) / f"{workflow_id}-report.json"
        if report_fp.exists():
            return load_json(report_fp)

        # Fall back to workflow findings
        fp = workflows_dir(self.root) / f"{workflow_id}.json"
        if not fp.exists():
            return {"error": f"Workflow {workflow_id} not found"}

        workflow = load_json(fp)

        if workflow["status"] != "completed":
            return {"error": f"Workflow not completed. Status: {workflow['status']}"}

        return {
            "id": workflow_id,
            "mode": workflow["mode"],
            "target_url": workflow.get("target_url"),
            "repo_path": workflow.get("repo_path"),
            "scope": workflow.get("scope"),
            "completed_at": workflow.get("completed_at"),
            "findings": workflow.get("findings", []),
            "summary": workflow.get("summary", {}),
            "raw_output": workflow.get("raw_output"),
        }

    def _generate_report(self, workflow: dict):
        """Generate a formatted report file."""
        report = {
            "id": workflow["id"],
            "mode": workflow["mode"],
            "target_url": workflow.get("target_url"),
            "repo_path": workflow.get("repo_path"),
            "scope": workflow.get("scope"),
            "created_at": workflow.get("created_at"),
            "completed_at": workflow.get("completed_at"),
            "findings": workflow.get("findings", []),
            "summary": workflow.get("summary", {}),
        }

        report_fp = reports_dir(self.root) / f"{workflow['id']}-report.json"
        save_json(report_fp, report)

        # Also generate markdown report
        md_fp = reports_dir(self.root) / f"{workflow['id']}-report.md"
        self._generate_markdown_report(report, md_fp)

    def _generate_markdown_report(self, report: dict, output_path: Path):
        """Generate a human-readable markdown report."""
        findings = report.get("findings", [])
        summary = report.get("summary", {})

        # Count by severity if not provided
        if not summary:
            summary = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}
            for f in findings:
                sev = f.get("severity", "info").lower()
                summary[sev] = summary.get(sev, 0) + 1

        md = f"""# Unity Security Report

**Workflow ID:** {report['id']}
**Mode:** {report['mode']}
**Target:** {report.get('target_url') or report.get('repo_path') or 'N/A'}
**Scope:** {report.get('scope', 'full')}
**Completed:** {report.get('completed_at', 'N/A')}

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | {summary.get('critical', 0)} |
| 🟠 High | {summary.get('high', 0)} |
| 🟡 Medium | {summary.get('medium', 0)} |
| 🟢 Low | {summary.get('low', 0)} |
| ℹ️ Info | {summary.get('info', 0)} |

## Findings

"""
        severity_icons = {
            "critical": "🔴",
            "high": "🟠",
            "medium": "🟡",
            "low": "🟢",
            "info": "ℹ️",
        }

        for i, finding in enumerate(findings, 1):
            icon = severity_icons.get(finding.get("severity", "info").lower(), "❓")
            md += f"""### {i}. {icon} {finding.get('title', 'Untitled')}

**Severity:** {finding.get('severity', 'unknown')}
**Category:** {finding.get('category', 'N/A')}
**File:** {finding.get('file', 'N/A')}:{finding.get('line', '?')}

{finding.get('description', 'No description')}

**Recommendation:** {finding.get('recommendation', 'N/A')}

---

"""

        if not findings:
            md += "*No security issues found. Either the code is secure or Unity needs a drink.*\n"

        md += """
---
*Generated by Unity — Rick's security specialist (Shannon pentest framework wrapper)*
"""

        with open(output_path, "w") as f:
            f.write(md)

    def list_workflows(self, status: Optional[str] = None) -> list[dict]:
        """List all workflows, optionally filtered by status."""
        workflows = []
        wd = workflows_dir(self.root)
        if not wd.exists():
            return []

        for fp in sorted(wd.glob("*.json")):
            w = load_json(fp)
            if status and w.get("status") != status:
                continue
            workflows.append({
                "id": w["id"],
                "status": w["status"],
                "mode": w["mode"],
                "target": w.get("target_url") or w.get("repo_path"),
                "created_at": w["created_at"],
                "completed_at": w.get("completed_at"),
            })

        return workflows


# ── CLI Commands ─────────────────────────────────────────────────────────────

def cmd_scan(args):
    """Start a security scan."""
    root = find_cto_root()
    unity = UnitySecurityAgent(root)

    print(f"*Burrrp* Unity's on the case. Time to find some vulnerabilities, Morty.")
    print(f"  Mode: {'Temporal/Shannon' if unity.temporal_available and unity.shannon_available else 'Static Analysis'}")

    workflow = unity.start_pentest(
        target_url=args.url,
        repo_path=args.repo or str(root),
        config_path=args.config,
        scope=args.scope,
    )

    print(f"\n  Workflow ID: {workflow['id']}")
    print(f"  Status: {workflow['status']}")
    print(f"  Mode: {workflow['mode']}")

    if workflow["status"] == "completed":
        print(f"\n  Scan completed!")
        findings = workflow.get("findings", [])
        if findings:
            print(f"  Found {len(findings)} issues:")
            for f in findings[:5]:
                print(f"    - [{f.get('severity', '?')}] {f.get('title', 'Untitled')}")
            if len(findings) > 5:
                print(f"    ... and {len(findings) - 5} more")
        print(f"\n  Run `python unity.py report {workflow['id']}` for full report")
    elif workflow["status"] == "running":
        print(f"\n  Scan running in background.")
        print(f"  Run `python unity.py status {workflow['id']}` to check progress")
    else:
        print(f"\n  Error: {workflow.get('error', 'Unknown error')}")


def cmd_status(args):
    """Check workflow status."""
    root = find_cto_root()
    unity = UnitySecurityAgent(root)

    progress = unity.get_progress(args.workflow_id)

    if "error" in progress and progress.get("status") != "error":
        print(f"Error: {progress['error']}")
        return

    status_icons = {
        "pending": "⏳",
        "running": "🔄",
        "completed": "✅",
        "error": "❌",
    }

    icon = status_icons.get(progress["status"], "❓")

    print(f"""
Unity Workflow Status
─────────────────────
  ID: {progress['id']}
  Status: {icon} {progress['status']}
  Progress: {progress['progress']}%
  Phase: {progress.get('current_phase', 'N/A')}
  Mode: {progress['mode']}
  Started: {progress.get('started_at', 'N/A')}
  Completed: {progress.get('completed_at', 'N/A')}
""")

    if progress.get("error"):
        print(f"  Error: {progress['error']}")


def cmd_report(args):
    """Get the full report."""
    root = find_cto_root()
    unity = UnitySecurityAgent(root)

    report = unity.get_report(args.workflow_id)

    if "error" in report:
        print(f"Error: {report['error']}")
        return

    # Check if markdown report exists
    md_fp = reports_dir(root) / f"{args.workflow_id}-report.md"
    if md_fp.exists() and not args.json:
        with open(md_fp) as f:
            print(f.read())
    else:
        print(json.dumps(report, indent=2))


def cmd_list(args):
    """List all workflows."""
    root = find_cto_root()
    unity = UnitySecurityAgent(root)

    workflows = unity.list_workflows(status=args.status)

    if not workflows:
        print("No Unity workflows found. Go scan something, Morty!")
        return

    print(f"{'ID':<20} {'Status':<12} {'Mode':<10} {'Target':<30}")
    print("─" * 75)
    for w in workflows:
        target = (w.get("target") or "")[:28]
        print(f"{w['id']:<20} {w['status']:<12} {w['mode']:<10} {target:<30}")


def cmd_check(args):
    """Check Unity dependencies."""
    root = find_cto_root()
    unity = UnitySecurityAgent(root)

    print("Unity Dependency Check")
    print("─" * 40)
    print(f"  Temporal available: {'✅ Yes' if unity.temporal_available else '❌ No'}")
    print(f"  Shannon available:  {'✅ Yes' if unity.shannon_available else '❌ No'}")
    print(f"  Shannon path:       {SHANNON_PATH}")

    if unity.temporal_available and unity.shannon_available:
        print("\n  ✅ Full pentest mode available!")
    else:
        print("\n  ⚠️  Running in static analysis fallback mode")
        if not unity.shannon_available:
            print("     Run `bash scripts/unity_setup.sh` to install Shannon")
        if not unity.temporal_available:
            print("     Start Temporal: `docker-compose up -d` in vendors/shannon/")


# ── CLI Parser ───────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(prog="unity", description="Unity Security Agent — Shannon pentest wrapper *burp*")
    sub = p.add_subparsers(dest="command", required=True)

    # scan
    sc = sub.add_parser("scan", help="Start a security scan")
    sc.add_argument("--url", help="Target URL for live testing")
    sc.add_argument("--repo", help="Repository path for code analysis")
    sc.add_argument("--config", help="Path to custom Shannon config")
    sc.add_argument("--scope", default="full", choices=["full", "quick", "recon", "exploit"])

    # status
    st = sub.add_parser("status", help="Check workflow status")
    st.add_argument("workflow_id", help="Workflow ID")

    # report
    rp = sub.add_parser("report", help="Get the full report")
    rp.add_argument("workflow_id", help="Workflow ID")
    rp.add_argument("--json", action="store_true", help="Output as JSON")

    # list
    ls = sub.add_parser("list", help="List all workflows")
    ls.add_argument("--status", choices=["pending", "running", "completed", "error"])

    # check
    sub.add_parser("check", help="Check Unity dependencies")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "scan": cmd_scan,
        "status": cmd_status,
        "report": cmd_report,
        "list": cmd_list,
        "check": cmd_check,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
