# claude-config

Personal Claude Code configuration, synced across devices via symlinks.

## What's here

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Global Claude Code instructions (identity, rules, agent roster) |
| `settings.json` | Claude Code permissions and hooks |
| `settings.local.json` | Local Bash permission allowlist |
| `agents/` | 27 specialist agent definitions (`@agent-name`) |
| `commands/sc/` | 31 `/sc:*` slash commands |
| `core/` | Operational principles: `RULES.md`, `FLAGS.md`, `PRINCIPLES.md`, etc. |
| `modes/` | Behavioral mode definitions (brainstorming, orchestration, etc.) |
| `memory/` | Persistent memory store (`MEMORY.md` index + per-topic files) |

## Setup on a new device

```bash
git clone git@github.com:<your-username>/claude-config.git ~/claude-config
cd ~/claude-config
bash setup.sh
```

`setup.sh` will:
1. Back up any existing `~/.claude` files/dirs to `~/.claude.bak/`
2. Create symlinks from `~/.claude/` pointing into this repo
3. Wire up the memory path at `~/.claude/projects/-Users-<USER>/memory/`

After running, start a new Claude Code session — config loads automatically.

## Keeping in sync

Changes made anywhere (in-session or direct edits) are reflected immediately since both sides point to the same files. To push updates:

```bash
cd ~/claude-config
git add -A
git commit -m "Update config"
git push
```

## What's NOT tracked

See `.gitignore`. Excluded intentionally:
- Runtime dirs: `plugins/`, `sessions/`, `cache/`, `backups/`, etc.
- Private files: `commands/ftc.md`, `memory/project_ftc_agent.md`
- Session artifacts: `history.jsonl`, `activity.log`, `todo.md`
