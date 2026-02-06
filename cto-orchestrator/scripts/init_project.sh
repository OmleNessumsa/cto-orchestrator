#!/usr/bin/env bash
# Rick Sanchez CTO Orchestrator — Initialize a new project workspace.
# *Burrrp* Usage: bash init_project.sh "ProjectName" "PREFIX"

set -euo pipefail

PROJECT_NAME="${1:?Usage: init_project.sh <ProjectName> <PREFIX>}"
PREFIX="${2:?Usage: init_project.sh <ProjectName> <PREFIX>}"

CTO_DIR=".cto"

if [ -d "$CTO_DIR" ]; then
    echo "*Burp* $CTO_DIR already exists. Re-initializing config, Morty."
fi

# Create directory structure
mkdir -p "$CTO_DIR/tickets"
mkdir -p "$CTO_DIR/logs"
mkdir -p "$CTO_DIR/decisions"

# Generate config.json
TIMESTAMP=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())")

cat > "$CTO_DIR/config.json" <<EOF
{
  "project_name": "$PROJECT_NAME",
  "ticket_prefix": "$PREFIX",
  "next_ticket_number": 1,
  "created_at": "$TIMESTAMP",
  "agents_used": [],
  "current_sprint": 1,
  "default_model": "sonnet"
}
EOF

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
