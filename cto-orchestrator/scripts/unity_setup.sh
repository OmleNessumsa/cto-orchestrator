#!/bin/bash
# Unity Setup Script — Shannon Pentest Framework Installer
#
# *Burrrp* — This script sets up Shannon for Unity, Morty.
# Shannon is a Temporal-based pentest framework that Unity wraps.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENDORS_DIR="$PROJECT_ROOT/vendors"
SHANNON_DIR="$VENDORS_DIR/shannon"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Unity Setup — Shannon Pentest Framework                     ║"
echo "║  *Burrrp* Let's get this security show on the road, Morty    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ "$2" = "ok" ]; then
        echo "  ✅ $1"
    elif [ "$2" = "warn" ]; then
        echo "  ⚠️  $1"
    else
        echo "  ❌ $1"
    fi
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

PREREQS_OK=true

# Node.js
if command_exists node; then
    NODE_VERSION=$(node --version)
    print_status "Node.js $NODE_VERSION" "ok"
else
    print_status "Node.js not found (required)" "fail"
    PREREQS_OK=false
fi

# npm
if command_exists npm; then
    NPM_VERSION=$(npm --version)
    print_status "npm $NPM_VERSION" "ok"
else
    print_status "npm not found (required)" "fail"
    PREREQS_OK=false
fi

# Docker
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_status "Docker $DOCKER_VERSION" "ok"
else
    print_status "Docker not found (required for Temporal)" "warn"
fi

# Docker Compose
if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
    print_status "Docker Compose" "ok"
else
    print_status "Docker Compose not found (required for Temporal)" "warn"
fi

# Git
if command_exists git; then
    print_status "Git" "ok"
else
    print_status "Git not found (required)" "fail"
    PREREQS_OK=false
fi

# Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status "Python $PYTHON_VERSION" "ok"
else
    print_status "Python 3 not found (required)" "fail"
    PREREQS_OK=false
fi

echo ""

# Optional security tools
echo "Checking optional security tools..."
echo ""

# nmap
if command_exists nmap; then
    print_status "nmap" "ok"
else
    print_status "nmap not found (optional, for network scanning)" "warn"
fi

# subfinder
if command_exists subfinder; then
    print_status "subfinder" "ok"
else
    print_status "subfinder not found (optional, for subdomain enumeration)" "warn"
fi

# whatweb
if command_exists whatweb; then
    print_status "whatweb" "ok"
else
    print_status "whatweb not found (optional, for web fingerprinting)" "warn"
fi

# nuclei
if command_exists nuclei; then
    print_status "nuclei" "ok"
else
    print_status "nuclei not found (optional, for vulnerability scanning)" "warn"
fi

echo ""

if [ "$PREREQS_OK" = false ]; then
    echo "❌ Missing required prerequisites. Please install them first."
    echo ""
    echo "Install Node.js: https://nodejs.org/"
    echo "Install Git: https://git-scm.com/"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Create vendors directory
echo "Creating vendors directory..."
mkdir -p "$VENDORS_DIR"

# Clone or update Shannon
echo ""
if [ -d "$SHANNON_DIR" ]; then
    echo "Shannon already exists at $SHANNON_DIR"
    echo "Updating..."
    cd "$SHANNON_DIR"
    git pull origin main || git pull origin master || echo "Could not update (may be detached or no remote)"
else
    echo "Cloning Shannon repository..."
    echo "(Note: Using placeholder URL - replace with actual Shannon repo)"

    # Try to clone Shannon - if it doesn't exist yet, create a placeholder
    if git clone https://github.com/KeygraphHQ/shannon.git "$SHANNON_DIR" 2>/dev/null; then
        echo "Shannon cloned successfully!"
    else
        echo "Shannon repository not available. Creating placeholder structure..."
        mkdir -p "$SHANNON_DIR"

        # Create a minimal package.json for the placeholder
        cat > "$SHANNON_DIR/package.json" << 'EOF'
{
  "name": "shannon-placeholder",
  "version": "0.1.0",
  "description": "Placeholder for Shannon pentest framework",
  "main": "index.js",
  "scripts": {
    "start": "echo 'Shannon not yet configured'",
    "test": "echo 'Shannon placeholder'"
  },
  "dependencies": {
    "@temporalio/client": "^1.8.0",
    "@temporalio/worker": "^1.8.0",
    "playwright": "^1.40.0"
  }
}
EOF

        # Create placeholder index.js
        cat > "$SHANNON_DIR/index.js" << 'EOF'
console.log('Shannon pentest framework placeholder');
console.log('Replace this with actual Shannon installation');
console.log('See: https://github.com/KeygraphHQ/shannon');
EOF

        # Create docker-compose for Temporal
        cat > "$SHANNON_DIR/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  temporal:
    image: temporalio/auto-setup:latest
    ports:
      - "7233:7233"
    environment:
      - DB=postgresql
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=temporal
      - POSTGRES_SEEDS=postgresql
    depends_on:
      - postgresql

  postgresql:
    image: postgres:13
    environment:
      POSTGRES_USER: temporal
      POSTGRES_PASSWORD: temporal
    ports:
      - "5432:5432"

  temporal-ui:
    image: temporalio/ui:latest
    ports:
      - "8080:8080"
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
    depends_on:
      - temporal
EOF

        echo "Placeholder created. Replace with actual Shannon when available."
    fi
fi

# Install dependencies
echo ""
echo "Installing Node.js dependencies..."
cd "$SHANNON_DIR"
if [ -f "package.json" ]; then
    npm install || echo "npm install failed (may be placeholder)"
fi

# Install Playwright browsers (if playwright is a dependency)
if grep -q "playwright" package.json 2>/dev/null; then
    echo ""
    echo "Installing Playwright browsers..."
    npx playwright install chromium || echo "Playwright browser install skipped"
fi

# Create Unity config template
echo ""
echo "Creating Unity config template..."
UNITY_CONFIG_DIR="$PROJECT_ROOT/cto-orchestrator/agents/unity"
mkdir -p "$UNITY_CONFIG_DIR"

cat > "$UNITY_CONFIG_DIR/config-template.yaml" << 'EOF'
# Unity (Shannon) Configuration Template
# Copy this to config.yaml and customize for your project

# Target configuration
target:
  # Base URL for live testing (optional)
  url: null
  # Repository path for code analysis
  repo: "."
  # Scope of testing
  scope: "full"  # full, quick, recon, exploit

# Authentication (if needed)
auth:
  # Bearer token
  token: null
  # Cookie-based auth
  cookies: null
  # Basic auth
  basic:
    username: null
    password: null

# Scanning options
scan:
  # Enable/disable specific scan types
  enabled:
    - sast          # Static Application Security Testing
    - dast          # Dynamic Application Security Testing
    - secrets       # Secret detection
    - dependencies  # Dependency vulnerability scanning
    - config        # Configuration security

  # Exclude patterns
  exclude:
    paths:
      - "node_modules/**"
      - "vendor/**"
      - ".git/**"
      - "*.min.js"
    rules:
      - "info-*"  # Exclude informational findings

# Severity threshold (only report >= this level)
severity_threshold: "low"  # critical, high, medium, low, info

# Output configuration
output:
  # Report formats
  formats:
    - json
    - markdown
  # Output directory
  directory: ".cto/unity/reports"

# Temporal configuration (for async workflows)
temporal:
  # Temporal server address
  address: "localhost:7233"
  # Namespace
  namespace: "default"
  # Task queue
  task_queue: "unity-security"

# Rate limiting
rate_limit:
  # Requests per second
  rps: 10
  # Concurrent connections
  concurrency: 5

# Timeouts (in seconds)
timeouts:
  # Per-request timeout
  request: 30
  # Total scan timeout
  total: 3600  # 1 hour
EOF

echo "  Created: $UNITY_CONFIG_DIR/config-template.yaml"

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Unity Setup Complete!                                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Shannon location: $SHANNON_DIR"
echo ""
echo "Next steps:"
echo ""
echo "1. Start Temporal (for full pentest mode):"
echo "   cd $SHANNON_DIR && docker-compose up -d"
echo ""
echo "2. Verify Unity setup:"
echo "   python3 $SCRIPT_DIR/unity.py check"
echo ""
echo "3. Run a security scan:"
echo "   python3 $SCRIPT_DIR/unity.py scan --repo ."
echo ""
echo "*Burrrp* — Unity is ready to find vulnerabilities, Morty!"
