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

Changes are live immediately (symlinks). To sync with the remote:

```bash
bash ~/claude-config/sync.sh
```

`sync.sh` handles all three cases automatically:

| State | Action |
|-------|--------|
| Local ahead of remote | Pushes |
| Remote ahead of local | Fast-forward merge |
| Diverged (both have changes) | Creates a `config/sync-<timestamp>` branch, prints an AI reasoning prompt, suggests `/sc:sync-config` |

### Resolving diverged state

When `sync.sh` detects divergence it prints a structured prompt. Run `/sc:sync-config` in Claude Code to execute a 5-phase reasoning chain:

1. **Snapshot** — commit any pending local changes
2. **Fetch & assess** — determine ahead/behind counts
3. **Inventory** — list every file changed on each side
4. **Classify & reason** — apply per-file rules (local identity files, agent defs, commands union, memory merge, infra prefers remote); write reasoning before each verdict
5. **Execute** — apply resolutions, commit, push

The classification rules ensure:
- `settings.local.json` is **never** overwritten by remote
- `memory/MEMORY.md` entries are **always** unioned (nothing dropped)
- `commands/sc/` files from both sides are **always** kept
- Agent definitions keep the **richer** version

## What's NOT tracked

See `.gitignore`. Excluded intentionally:
- Runtime dirs: `plugins/`, `sessions/`, `cache/`, `backups/`, etc.
- Private files: `commands/ftc.md`, `memory/project_ftc_agent.md`
- Session artifacts: `history.jsonl`, `activity.log`, `todo.md`
