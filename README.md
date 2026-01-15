# Claude Code Guardrails

**Your security team wants to control what Claude Code can do. Your developers don't want to be blocked. This solves both.**

Without guardrails:

- Claude runs `rm -rf /` and you have a bad day
- Every developer has different personal rules (or none)
- No audit trail when something goes wrong
- Security team has zero visibility

With guardrails:

- Dangerous commands get blocked or flagged before execution
- One decision table your whole team shares
- Security team edits rules in a spreadsheet UI—no JSON, no PRs
- Changes apply instantly, no restarts

---

## How it works

```
Claude Code → PreToolUse hook → Rulebricks API → allow / deny / ask
```

You edit a decision table like this:

<!-- TODO: Add screenshot here -->

Claude Code checks every tool call against your rules before executing.

---

## Setup (5 minutes)

### 1. Create your rules

1. Go to [rulebricks.com](https://rulebricks.com) and create an account
2. Fork one of these templates:
   - **Bash Command Guardrails** — control shell commands
   - **File Access Policy** — control file read/write/edit
   - **MCP Tool Governance** — control MCP server operations
3. Customize the rules for your team
4. Publish the rule
5. Copy your API key from Settings

### 2. Install

**Option A: Traditional**

```bash
git clone https://github.com/rulebricks/claude-code-guardrails
cd claude-code-guardrails
./install.sh
```

**Option B: Let Claude install itself** (yes, really)

```bash
git clone https://github.com/rulebricks/claude-code-guardrails
cd claude-code-guardrails
./install-with-claude.sh
```

Claude will detect your published rules and wire up the appropriate hooks.

### 3. Restart Claude Code

That's it.

---

## What gets checked

| Template                | Matcher             | What it controls |
| ----------------------- | ------------------- | ---------------- |
| Bash Command Guardrails | `Bash`              | Shell commands   |
| File Access Policy      | `Read\|Write\|Edit` | File operations  |
| MCP Tool Governance     | `mcp__*`            | MCP server calls |

---

## Configuration

Environment variables in `~/.claude/settings.json`:

```json
{
  "env": {
    "RULEBRICKS_API_KEY": "your-api-key",
    "RULEBRICKS_VERBOSE": "1"
  }
}
```

| Variable             | Description                           |
| -------------------- | ------------------------------------- |
| `RULEBRICKS_API_KEY` | Your Rulebricks API key (required)    |
| `RULEBRICKS_VERBOSE` | Set to `1` to log decisions to stderr |
| `RULEBRICKS_DRY_RUN` | Set to `1` to log without enforcing   |

---

## Updating rules

Edit your decision table at rulebricks.com. Changes apply immediately—no restart, no redeployment.

---

## Why not just use settings.json?

Claude Code has built-in `permissions.allow` and `permissions.deny`. Use those if:

- You're a solo developer
- Your rules never change
- You don't need audit trails

Use Rulebricks if:

- You have a team and need centralized policy
- Security/compliance needs visibility into what's being blocked
- You want to edit rules without touching config files
- You need the same rules across Claude Code + Cursor + other agents

---

## Uninstall

```bash
rm ~/.claude/hooks/guardrail*.py
# Remove the hooks.PreToolUse entry from ~/.claude/settings.json
```

---

## License

MIT
