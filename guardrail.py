#!/usr/bin/env python3
"""
Rulebricks guardrail hook for Claude Code.
Checks tool calls against your published decision tables.
"""

import json
import sys
import os

try:
    from rulebricks import Rulebricks
except ImportError:
    print("rulebricks not installed", file=sys.stderr)
    sys.exit(0)

API_KEY = os.environ.get("RULEBRICKS_API_KEY")
VERBOSE = os.environ.get("RULEBRICKS_VERBOSE") == "1"
DRY_RUN = os.environ.get("RULEBRICKS_DRY_RUN") == "1"

if not API_KEY:
    if VERBOSE:
        print("[guardrails] RULEBRICKS_API_KEY not set", file=sys.stderr)
    sys.exit(0)

client = Rulebricks(api_key=API_KEY)

# Rule slugs - set during install
BASH_RULE = os.environ.get("RULEBRICKS_BASH_RULE")
FILE_RULE = os.environ.get("RULEBRICKS_FILE_RULE")
MCP_RULE = os.environ.get("RULEBRICKS_MCP_RULE")


def log(msg: str):
    if VERBOSE:
        print(f"[guardrails] {msg}", file=sys.stderr)


def extract_bash_request(tool_input: dict) -> dict:
    cmd = tool_input.get("command", "")
    parts = cmd.split()
    return {
        "command": cmd,
        "target_path": next((p for p in parts[1:] if p.startswith(("/", "~", "."))), ""),
        "has_force_flag": any(f in cmd for f in ["--force", "-f", "-rf"]),
        "is_destructive": any(d in cmd for d in ["rm", "drop", "delete", "truncate"]),
        "is_network_call": any(n in parts[0] if parts else "" for n in ["curl", "wget", "ssh", "scp", "rsync"]),
    }


def extract_file_request(tool_name: str, tool_input: dict) -> dict:
    path = tool_input.get("file_path", "")
    return {
        "tool": tool_name,
        "path_pattern": path,
        "extension": os.path.splitext(path)[1],
    }


def extract_mcp_request(tool_name: str) -> dict:
    parts = tool_name.split("__")
    return {
        "mcp_server": f"mcp__{parts[1]}__*" if len(parts) > 1 else "",
        "operation_pattern": parts[2] if len(parts) > 2 else "",
    }


def evaluate(slug: str, request: dict, tool_desc: str) -> dict | None:
    try:
        result = client.rules.solve(slug=slug, request=request)
        decision = str(result.get("decision", "allow")).lower()
        reason = result.get("decision_reason") or result.get("reason", "")
        
        log(f"{tool_desc} → {decision}" + (f" ({reason})" if reason else ""))
        
        if DRY_RUN:
            return None
        
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": {"deny": "deny", "ask": "ask"}.get(decision, "allow"),
                "permissionDecisionReason": reason or f"{'Blocked' if decision == 'deny' else 'Allowed'} by policy"
            }
        }
    except Exception as e:
        log(f"API error: {e}")
        return None


def main():
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    
    result = None
    
    # Bash commands
    if tool_name == "Bash" and BASH_RULE:
        request = extract_bash_request(tool_input)
        result = evaluate(BASH_RULE, request, f"Bash: {tool_input.get('command', '')[:50]}")
    
    # File operations
    elif tool_name in ("Read", "Write", "Edit") and FILE_RULE:
        request = extract_file_request(tool_name, tool_input)
        result = evaluate(FILE_RULE, request, f"{tool_name}: {tool_input.get('file_path', '')}")
    
    # MCP tools
    elif tool_name.startswith("mcp__") and MCP_RULE:
        request = extract_mcp_request(tool_name)
        result = evaluate(MCP_RULE, request, f"MCP: {tool_name}")
    
    if result:
        print(json.dumps(result))


if __name__ == "__main__":
    main()
