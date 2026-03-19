# /sc:sync-config — Claude Config Sync with AI Reasoning

Sync `~/claude-config` with the remote repo. When diverged, reason through each changed file to decide: merge, keep local, or keep remote.

---

## Execution

You are Claude Code. Execute the following reasoning chain to sync the config repo.

### Setup

```bash
cd ~/claude-config
```

Confirm this is a git repo with a remote:
```bash
git remote -v
git status
```

---

### PHASE 0 — SNAPSHOT

Commit any pending local changes before doing anything:

```bash
git add -A
git diff --cached --stat
# If anything staged:
git commit -m "snapshot: pre-sync local state $(date '+%Y-%m-%d %H:%M')"
```

---

### PHASE 1 — FETCH AND ASSESS

```bash
git fetch origin
```

Determine the relationship between local HEAD and remote:

```bash
MERGE_BASE=$(git merge-base HEAD origin/main)
AHEAD=$(git rev-list origin/main..HEAD --count)
BEHIND=$(git rev-list HEAD..origin/main --count)
echo "Ahead: $AHEAD | Behind: $BEHIND | Merge base: $MERGE_BASE"
```

**Decision tree — reason aloud before acting:**

- If `AHEAD=0, BEHIND=0` → already in sync, done.
- If `AHEAD=0, BEHIND>0` → remote only has new changes; `git merge --ff-only origin/main` is safe. Do it.
- If `AHEAD>0, BEHIND=0` → local only has new changes; `git push` is safe. Do it.
- If `AHEAD>0, BEHIND>0` → **diverged**. Continue to Phase 2.

---

### PHASE 2 — INVENTORY CHANGES (diverged only)

List every file changed on each side since the merge base:

```bash
echo "=== LOCAL changes (not on remote) ==="
git diff --name-status $MERGE_BASE HEAD

echo "=== REMOTE changes (not on local) ==="
git diff --name-status $MERGE_BASE origin/main
```

For each file that appears on BOTH sides (true conflict), also run:
```bash
git diff $MERGE_BASE HEAD -- <filepath>       # what local did
git diff $MERGE_BASE origin/main -- <filepath> # what remote did
```

Read and understand both diffs before classifying.

---

### PHASE 3 — CLASSIFY AND REASON

For each changed file, classify it using the rules below. **Write out your reasoning before assigning a verdict.**

#### Classification Rules

| File pattern | Default verdict | Rationale |
|---|---|---|
| `CLAUDE.md` | PREFER_LOCAL | Identity & rules are customized per user |
| `settings.json` | PREFER_LOCAL | Permissions reflect local tool setup |
| `settings.local.json` | ALWAYS_LOCAL | Never overwrite — device-specific allowlist |
| `agents/*.md` | PREFER_NEWER | Keep the richer/longer definition |
| `commands/sc/*.md` | KEEP_BOTH | Union both sides; never drop a command |
| `commands/ftc.md` | ALWAYS_LOCAL | Gitignored, sensitive — ignore remote |
| `core/*.md` | PREFER_REMOTE | Canonical reference docs |
| `modes/*.md` | PREFER_REMOTE | Canonical mode definitions |
| `memory/MEMORY.md` | MANUAL_MERGE | Never drop entries; union all index lines |
| `memory/project_*.md` | ALWAYS_LOCAL | Gitignored, device-specific |
| `setup.sh` | PREFER_REMOTE | Infra file; remote is usually ahead |
| `sync.sh` | PREFER_REMOTE | Infra file; remote is usually ahead |
| `README.md` | PREFER_REMOTE | Docs; remote is canonical |
| `.gitignore` | PREFER_REMOTE | Remote may have added new exclusions |

#### Override conditions

- If local has **more content** than remote for an `PREFER_REMOTE` file → escalate to `MANUAL_MERGE`
- If remote **deletes** a file that local has changes to → always keep local, log the conflict
- If a file only changed on one side (not a true conflict) → apply that side's change, no reasoning needed

#### Output format

For each file, write:
```
[VERDICT] path/to/file
  Local: <1-line summary of what local changed>
  Remote: <1-line summary of what remote changed>
  Reason: <why this verdict>
```

---

### PHASE 4 — EXECUTE RESOLUTIONS

Apply each verdict:

```bash
# KEEP_LOCAL / ALWAYS_LOCAL:
git checkout HEAD -- <filepath>

# KEEP_REMOTE / PREFER_REMOTE (when remote wins):
git checkout origin/main -- <filepath>

# MANUAL_MERGE (memory/MEMORY.md and similar):
# 1. Open the file
# 2. Read both versions: git show HEAD:<file> and git show origin/main:<file>
# 3. Produce a merged result that keeps ALL entries from both sides
# 4. Write the merged content back
# 5. git add <filepath>

# KEEP_BOTH (commands/):
# 1. Check out remote version to a temp path
# 2. Copy any files that exist on remote but not local into the working tree
# 3. Never delete local files
```

After all resolutions:

```bash
git add -A
git diff --cached --stat   # review what you're committing
git commit -m "resolve: merge local + remote config [ai-reasoned]"
git push origin main
```

---

### PHASE 5 — VERIFY

```bash
git log --oneline -5
git status   # should be clean
cat ~/.claude/CLAUDE.md | head -5   # symlink still resolves
```

Confirm symlinks are intact:
```bash
ls -la ~/.claude/CLAUDE.md ~/.claude/agents ~/.claude/commands
```

If any symlink is broken, run `bash ~/claude-config/setup.sh` to restore.

---

### Abort / Safety Net

If anything looks wrong, stop and create a safety branch before proceeding:
```bash
git checkout -b config/safe-$(date '+%Y%m%d-%H%M%S')
git push origin HEAD
```
This preserves your local state. You can always return to it.
