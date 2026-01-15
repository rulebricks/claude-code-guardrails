#!/bin/bash
set -e

echo "Claude Code Guardrails (Auto-Setup)"
echo "===================================="
echo ""

read -p "Rulebricks API key: " -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq required. Install with: brew install jq"
    exit 1
fi

HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/guardrail.py" "$HOOKS_DIR/guardrail.py"
chmod +x "$HOOKS_DIR/guardrail.py"

echo ""
echo "Detecting your published rules..."

RULES_RESPONSE=$(curl -s -H "x-api-key: $API_KEY" "https://rulebricks.com/api/v1/admin/rules/list")

if echo "$RULES_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "Error: $(echo "$RULES_RESPONSE" | jq -r '.error')"
    exit 1
fi

BASH_RULE=$(echo "$RULES_RESPONSE" | jq -r '.[] | select(.request_schema | map(.key) | contains(["command", "has_force_flag"])) | .slug' | head -1)
FILE_RULE=$(echo "$RULES_RESPONSE" | jq -r '.[] | select(.request_schema | map(.key) | contains(["tool", "path_pattern", "extension"])) | .slug' | head -1)
MCP_RULE=$(echo "$RULES_RESPONSE" | jq -r '.[] | select(.request_schema | map(.key) | contains(["mcp_server", "operation_pattern"])) | .slug' | head -1)

[ -n "$BASH_RULE" ] && echo "  ✓ Bash guardrail: $BASH_RULE"
[ -n "$FILE_RULE" ] && echo "  ✓ File guardrail: $FILE_RULE"
[ -n "$MCP_RULE" ] && echo "  ✓ MCP guardrail: $MCP_RULE"

if [ -z "$BASH_RULE" ] && [ -z "$FILE_RULE" ] && [ -z "$MCP_RULE" ]; then
    echo ""
    echo "No guardrail rules detected."
    echo ""
    echo "To get started:"
    echo "  1. Go to rulebricks.com/templates"
    echo "  2. Fork: Bash Command Guardrails, File Access Policy, or MCP Tool Governance"
    echo "  3. Publish the rule"
    echo "  4. Run this script again"
    exit 1
fi

MATCHERS=""
[ -n "$BASH_RULE" ] && MATCHERS="Bash"
[ -n "$FILE_RULE" ] && MATCHERS="${MATCHERS:+$MATCHERS|}Read|Write|Edit"
[ -n "$MCP_RULE" ] && MATCHERS="${MATCHERS:+$MATCHERS|}mcp__*"

SETTINGS_FILE="$HOME/.claude/settings.json"

python3 << EOF
import json
import os

path = "$SETTINGS_FILE"
s = json.load(open(path)) if os.path.exists(path) else {}

s.setdefault("env", {})["RULEBRICKS_API_KEY"] = "$API_KEY"
if "$BASH_RULE": s["env"]["RULEBRICKS_BASH_RULE"] = "$BASH_RULE"
if "$FILE_RULE": s["env"]["RULEBRICKS_FILE_RULE"] = "$FILE_RULE"
if "$MCP_RULE": s["env"]["RULEBRICKS_MCP_RULE"] = "$MCP_RULE"

s.setdefault("hooks", {})["PreToolUse"] = [{
    "matcher": "$MATCHERS",
    "hooks": [{"type": "command", "command": "$HOOKS_DIR/guardrail.py"}]
}]

json.dump(s, open(path, "w"), indent=2)
EOF

echo ""
echo "✓ Installed to $HOOKS_DIR/guardrail.py"
echo "✓ Updated $SETTINGS_FILE"
echo "✓ Matchers: $MATCHERS"
echo ""
echo "Restart Claude Code to activate."