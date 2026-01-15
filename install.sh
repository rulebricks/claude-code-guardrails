#!/bin/bash
set -e

echo "Claude Code Guardrails"
echo "======================"
echo ""
echo "Prerequisites:"
echo "  1. Create account at rulebricks.com"
echo "  2. Fork and publish a guardrail template"
echo "  3. Have your API key ready"
echo ""

read -p "Rulebricks API key: " -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    exit 1
fi

echo ""
echo "Enter rule slugs (leave blank to skip):"
read -p "  Bash Command Guardrails slug: " BASH_RULE
read -p "  File Access Policy slug: " FILE_RULE
read -p "  MCP Tool Governance slug: " MCP_RULE

if [ -z "$BASH_RULE" ] && [ -z "$FILE_RULE" ] && [ -z "$MCP_RULE" ]; then
    echo "Error: At least one rule slug required"
    exit 1
fi

echo ""
echo "Installing..."

# Install SDK
pip install rulebricks -q

# Create hooks directory
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

# Copy guardrail script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/guardrail.py" "$HOOKS_DIR/guardrail.py"
chmod +x "$HOOKS_DIR/guardrail.py"

# Build matcher based on which rules are configured
MATCHERS=""
[ -n "$BASH_RULE" ] && MATCHERS="Bash"
[ -n "$FILE_RULE" ] && MATCHERS="${MATCHERS:+$MATCHERS|}Read|Write|Edit"
[ -n "$MCP_RULE" ] && MATCHERS="${MATCHERS:+$MATCHERS|}mcp__*"

# Update settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"

python3 << EOF
import json
import os

settings_path = "$SETTINGS_FILE"
settings = {}

if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        try:
            settings = json.load(f)
        except:
            pass

# Set environment variables
settings.setdefault("env", {})
settings["env"]["RULEBRICKS_API_KEY"] = "$API_KEY"
if "$BASH_RULE":
    settings["env"]["RULEBRICKS_BASH_RULE"] = "$BASH_RULE"
if "$FILE_RULE":
    settings["env"]["RULEBRICKS_FILE_RULE"] = "$FILE_RULE"
if "$MCP_RULE":
    settings["env"]["RULEBRICKS_MCP_RULE"] = "$MCP_RULE"

# Set up hook
settings.setdefault("hooks", {})
settings["hooks"]["PreToolUse"] = [{
    "matcher": "$MATCHERS",
    "hooks": [{
        "type": "command",
        "command": "$HOOKS_DIR/guardrail.py"
    }]
}]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
EOF

echo ""
echo "✓ Installed guardrail.py to $HOOKS_DIR"
echo "✓ Updated $SETTINGS_FILE"
echo ""
echo "Rules configured:"
[ -n "$BASH_RULE" ] && echo "  • Bash: $BASH_RULE"
[ -n "$FILE_RULE" ] && echo "  • File: $FILE_RULE"
[ -n "$MCP_RULE" ] && echo "  • MCP: $MCP_RULE"
echo ""
echo "Restart Claude Code to activate."
