#!/usr/bin/env bash
# CTO Orchestrator — install the MCP server into Claude Code's user config.
# Idempotent: re-running is safe (removes existing, re-adds).
#
# Usage:
#   bash scripts/install_mcp.sh            # install at user scope (~/.claude.json)
#   bash scripts/install_mcp.sh --project  # install at project scope (.mcp.json)
#   bash scripts/install_mcp.sh --remove   # uninstall
#
# After install, any Claude Code session (CLI or Rick IDE) can call the
# 23 orchestrator tools (list_tickets, board, create_ticket, delegate,
# meeseeks, sleepy_status, prometheus_status, unity_scan, explain_code, ...).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_SERVER="${SCRIPT_DIR}/mcp_server.py"
SERVER_NAME="cto-orchestrator"

SCOPE="user"
REMOVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project"; shift ;;
    --local)   SCOPE="local"; shift ;;
    --user)    SCOPE="user"; shift ;;
    --remove)  REMOVE=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v claude >/dev/null 2>&1 || {
  echo "Error: 'claude' CLI not found. Install from https://docs.anthropic.com/claude-code" >&2
  exit 1
}

if [[ $REMOVE -eq 1 ]]; then
  echo "Removing MCP server '${SERVER_NAME}' (scope: ${SCOPE})..."
  claude mcp remove "${SERVER_NAME}" -s "${SCOPE}" 2>/dev/null || true
  echo "Done."
  exit 0
fi

[[ -f "${MCP_SERVER}" ]] || { echo "Error: mcp_server.py not found at ${MCP_SERVER}" >&2; exit 1; }

python3 -c "import mcp" 2>/dev/null || {
  echo "Warning: 'mcp' Python package not installed. Install with: pip3 install --user mcp" >&2
  echo "Continuing anyway — server will fail at runtime until mcp is installed." >&2
}

echo "Installing MCP server '${SERVER_NAME}' (scope: ${SCOPE})..."
echo "  command: python3 ${MCP_SERVER}"

# Remove any existing registration first so re-runs don't bail with "already exists".
claude mcp remove "${SERVER_NAME}" -s "${SCOPE}" 2>/dev/null || true

claude mcp add "${SERVER_NAME}" -s "${SCOPE}" -- python3 "${MCP_SERVER}"

echo ""
echo "Verifying..."
claude mcp list 2>/dev/null | grep -E "^${SERVER_NAME}" || {
  echo "Install succeeded but server isn't showing in 'claude mcp list'. Check claude.json manually." >&2
  exit 1
}

echo ""
echo "*Burrrp.* CTO orchestrator MCP server registered."
echo "Available tools include:"
echo "  Read:    list_tickets, board, project_status, sleepy_status, prometheus_status, unity_list"
echo "  Write:   create_ticket, close_ticket, update_ticket_status"
echo "  Spawn:   delegate, meeseeks, prometheus_scan, unity_scan"
echo "  Explain: explain_code, explain_concept"
echo ""
echo "Next Claude session in this or any directory with a .cto/ will have the full orchestrator toolbelt."
