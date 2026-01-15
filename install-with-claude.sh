#!/bin/bash
set -e

echo "Claude Code Guardrails (Auto-Setup)"
echo "===================================="
echo ""
echo "Claude will detect your published rules and install the appropriate hooks."
echo ""

read -p "Rulebricks API key: " -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "Error: API key required"
    exit 1
fi

pip install rulebricks -q

HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/guardrail.py" "$HOOKS_DIR/guardrail.py"
chmod +x "$HOOKS_DIR/guardrail.py"

echo ""
echo "Detecting your published rules..."
echo ""

claude --print "
You have access to the rulebricks Python SDK. Using API key: $API_KEY

Do the following:

1. Initialize the client:
   from rulebricks import Rulebricks
   client = Rulebricks(api_key='$API_KEY')

2. List all rules:
   rules = client.assets.rules.list()

3. For each rule, get its details and check the request schema fields to detect the rule type:
   - If schema has 'command' and 'has_force_flag' → Bash guardrail, matcher = 'Bash'
   - If schema has 'tool' and 'path_pattern' and 'extension' → File guardrail, matcher = 'Read|Write|Edit'
   - If schema has 'mcp_server' and 'operation_pattern' → MCP guardrail, matcher = 'mcp__*'

4. For each detected guardrail rule, note its slug and type.

5. Update ~/.claude/settings.json:
   - Read existing settings (or start with {})
   - Set env.RULEBRICKS_API_KEY = '$API_KEY'
   - For each detected rule, set the appropriate env var:
     - Bash → env.RULEBRICKS_BASH_RULE = slug
     - File → env.RULEBRICKS_FILE_RULE = slug  
     - MCP → env.RULEBRICKS_MCP_RULE = slug
   - Build the matcher string by joining matchers with '|'
   - Set hooks.PreToolUse = [{
       'matcher': combined_matcher,
       'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/guardrail.py'}]
     }]
   - Write the settings back

6. Print a summary:
   - Which rules were detected (name, slug, type)
   - What matchers were configured
   - Remind to restart Claude Code

If no guardrail rules are found, tell the user to:
1. Go to rulebricks.com/templates
2. Fork one of: Bash Command Guardrails, File Access Policy, MCP Tool Governance
3. Publish the rule
4. Run this script again
"

echo ""
echo "Done. Restart Claude Code to activate."