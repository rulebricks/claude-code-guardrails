# Claude Code Guardrails

![Example Table](example.png)

`settings.json` works if:

- You're fine editing JSON and killing Claude Code sessions every time policy changes
- Your security team is comfortable making PRs
- You don't need to know what got blocked, when, or for whom
- Basic pattern matching like `Bash(rm:*)` covers your use cases

Use this if:

- Policy changes need to apply instantly across your team—no git pull, no restart
- Security/compliance needs a clear audit trail of every blocked command
- You need conditional logic: "allow `rm -rf` on `node_modules`, deny everywhere else"
- Non-engineers need to edit rules without touching config files

##### Rulebricks gives you instant governance from one hook.

```
Claude Code → PreToolUse hook → Rulebricks API → allow / deny / ask
```

## Setup (5 minutes)

### 1. Create your rules

1. Go to [rulebricks.com](https://rulebricks.com) and create an account
2. Fork one of these templates from the "AI Agents" category:
   - **Claude – Bash Guardrails** — control shell commands
   - **Claude – File Access Policy** — control file read/write/edit
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

You're done.

## What gets checked

| Template                | Matcher             | What it controls |
| ----------------------- | ------------------- | ---------------- |
| Bash Command Guardrails | `Bash`              | Shell commands   |
| File Access Policy      | `Read\|Write\|Edit` | File operations  |
| MCP Tool Governance     | `mcp__*`            | MCP server calls |

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

## Updating rules

Edit your decision table at rulebricks.com. Changes apply immediately—no restart, no redeployment.

## Uninstall

```bash
rm ~/.claude/hooks/guardrail*.py
# Remove the hooks.PreToolUse entry from ~/.claude/settings.json
```
