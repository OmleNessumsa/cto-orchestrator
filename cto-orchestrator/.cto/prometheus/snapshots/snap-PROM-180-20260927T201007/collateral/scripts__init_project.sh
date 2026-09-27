#!/usr/bin/env bash
# Rick Sanchez CTO Orchestrator — Initialize a new project workspace.
# *Burrrp* Usage: bash init_project.sh "ProjectName" "PREFIX"

set -euo pipefail

PROJECT_NAME="${1:?Usage: init_project.sh <ProjectName> <PREFIX>}"
PREFIX="${2:?Usage: init_project.sh <ProjectName> <PREFIX>}"

# SECURITY: Validate input to prevent command injection
# Only allow alphanumeric, spaces, hyphens, and underscores in project name
if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9\ _-]+$ ]]; then
    echo "Error: Project name contains invalid characters. Use only alphanumeric, space, hyphen, underscore." >&2
    exit 1
fi

# Validate prefix - only alphanumeric and hyphen
if [[ ! "$PREFIX" =~ ^[A-Z0-9-]+$ ]]; then
    echo "Error: Prefix must be uppercase alphanumeric with optional hyphens (e.g., PROJ, MY-APP)." >&2
    exit 1
fi

# Limit lengths to prevent buffer issues
if [ ${#PROJECT_NAME} -gt 100 ]; then
    echo "Error: Project name too long (max 100 characters)." >&2
    exit 1
fi

if [ ${#PREFIX} -gt 10 ]; then
    echo "Error: Prefix too long (max 10 characters)." >&2
    exit 1
fi

CTO_DIR=".cto"

if [ -d "$CTO_DIR" ]; then
    echo "*Burp* $CTO_DIR already exists. Re-initializing config, Morty."
fi

# Create directory structure
mkdir -p "$CTO_DIR/tickets"
mkdir -p "$CTO_DIR/logs"
mkdir -p "$CTO_DIR/decisions"

# Generate config.json using Python for proper JSON escaping
# SECURITY: This ensures all values are properly JSON-escaped
python3 << PYEOF
import json
from datetime import datetime, timezone

config = {
    "project_name": """$PROJECT_NAME""",
    "ticket_prefix": """$PREFIX""",
    "next_ticket_number": 1,
    "created_at": datetime.now(timezone.utc).isoformat(),
    "agents_used": [],
    "current_sprint": 1,
    "default_model": "sonnet",
    "roro": {
        "enabled": True,
        "endpoint": "http://localhost:3067/hooks/agent-event",
        "timeout": 2.0,
        "verbose": False
    }
}

with open("$CTO_DIR/config.json", "w") as f:
    json.dump(config, f, indent=2)
PYEOF

TIMESTAMP=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())")

# Create README if it doesn't exist
if [ ! -f "README.md" ]; then
    cat > "README.md" <<EOF
# $PROJECT_NAME

Managed by Rick Sanchez, the smartest CTO in the multiverse. *Burrrp*

## Quick Start

\`\`\`bash
# View project status (Rick's command center)
python scripts/orchestrate.py status

# Plan the project (let Rick's genius brain work)
python scripts/orchestrate.py plan "Description of what to build"

# Run a sprint (send the Morty's to work)
python scripts/orchestrate.py sprint

# View ticket board
python scripts/ticket.py board
\`\`\`
EOF
fi

# Log initialization
TODAY=$(date -u +%Y-%m-%d)
LOG_FILE="$CTO_DIR/logs/$TODAY.jsonl"
echo "{\"timestamp\":\"$TIMESTAMP\",\"ticket_id\":null,\"agent\":\"rick\",\"action\":\"created\",\"message\":\"*Burrrp* Project '$PROJECT_NAME' initialized. Wubba lubba dub dub!\",\"files_changed\":[\".cto/config.json\"]}" > "$LOG_FILE"

echo "*Burrrp* Project '$PROJECT_NAME' initialized. Let's get schwifty."
echo "  Ticket prefix: $PREFIX"
echo "  Config: $CTO_DIR/config.json"
echo "  Tickets: $CTO_DIR/tickets/"
echo "  Logs:    $CTO_DIR/logs/"
echo "  Decisions: $CTO_DIR/decisions/"
echo "  Now go plan something, Morty."
