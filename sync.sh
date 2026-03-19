#!/usr/bin/env bash
# sync.sh — Sync claude-config with the remote repo.
#
# Behavior:
#   - Local only ahead   → push to remote
#   - Remote only ahead  → fast-forward merge (no conflict possible)
#   - Diverged           → create a timestamped conflict branch, print AI
#                          reasoning prompt, suggest /sc:sync-config
#   - Already up to date → nothing to do
#
# Usage:
#   bash sync.sh          # sync in both directions
#   bash sync.sh --push   # push local changes only (skip pull)
#   bash sync.sh --pull   # pull remote changes only (skip push)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

PUSH_ONLY=false
PULL_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --push) PUSH_ONLY=true ;;
    --pull) PULL_ONLY=true ;;
  esac
done

# ── helpers ──────────────────────────────────────────────────────────────────
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

has_remote() {
  git remote get-url origin &>/dev/null
}

# ── preflight ────────────────────────────────────────────────────────────────
echo ""
echo "Claude Config Sync"
echo "══════════════════"

if ! has_remote; then
  die "No remote 'origin' configured. Add one with:\n  git remote add origin <repo-url>"
fi

# Stage any uncommitted local changes before we reason about them
if ! git diff --quiet || ! git diff --cached --quiet; then
  info "Uncommitted changes detected — staging and committing locally first..."
  git add -A
  STAMP=$(date '+%Y-%m-%d %H:%M:%S')
  git commit -m "auto-snapshot: local changes at $STAMP" \
    --author="Claude Code <noreply@anthropic.com>" || true
fi

# ── fetch remote ─────────────────────────────────────────────────────────────
info "Fetching remote..."
git fetch origin 2>&1 | sed 's/^/    /'

LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "")

if [ -z "$REMOTE_SHA" ]; then
  # No remote main/master — just push
  info "Remote branch not found. Pushing..."
  git push -u origin HEAD
  echo ""
  echo "✓ Pushed. Sync complete."
  exit 0
fi

# Determine relationship
MERGE_BASE=$(git merge-base HEAD "$REMOTE_SHA" 2>/dev/null || echo "")
AHEAD=$(git rev-list "$REMOTE_SHA"..HEAD --count 2>/dev/null || echo 0)
BEHIND=$(git rev-list HEAD.."$REMOTE_SHA" --count 2>/dev/null || echo 0)

echo ""
info "Status: local is $AHEAD commit(s) ahead, $BEHIND commit(s) behind remote."

# ── decision tree ─────────────────────────────────────────────────────────────
if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ]; then
  echo ""
  echo "✓ Already up to date."
  exit 0

elif [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -gt 0 ] && ! $PUSH_ONLY; then
  # Remote is strictly ahead — fast-forward safe
  echo ""
  info "Remote is ahead. Fast-forward merging..."
  git merge --ff-only origin/main 2>/dev/null || git merge --ff-only origin/master
  echo ""
  echo "✓ Merged. Local config updated."
  exit 0

elif [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -eq 0 ] && ! $PULL_ONLY; then
  # Local is strictly ahead — push
  echo ""
  info "Local is ahead. Pushing..."
  git push origin HEAD:main 2>/dev/null || git push origin HEAD:master
  echo ""
  echo "✓ Pushed. Remote updated."
  exit 0

else
  # Diverged — or both flags restricted to one direction
  echo ""
  echo "⚠  Diverged: both local and remote have changes."
  echo ""

  # Show the diff between merge-base and each side
  echo "── Changes on LOCAL (not on remote) ───────────────────────────"
  git diff --stat "$MERGE_BASE" HEAD 2>/dev/null | sed 's/^/  /'
  echo ""
  echo "── Changes on REMOTE (not on local) ───────────────────────────"
  git diff --stat "$MERGE_BASE" "$REMOTE_SHA" 2>/dev/null | sed 's/^/  /'
  echo ""

  # Create a conflict branch with local state
  BRANCH="config/sync-$(date '+%Y%m%d-%H%M%S')"
  git checkout -b "$BRANCH" 2>/dev/null
  info "Created branch: $BRANCH (holds your local state)"
  git checkout - 2>/dev/null
  echo ""

  # Print the AI reasoning prompt
  cat <<'PROMPT'
── AI Reasoning Prompt ─────────────────────────────────────────────────────────
Paste this into Claude Code (or run /sc:sync-config) to resolve the divergence:

  You are reconciling two diverged versions of a Claude Code config repo.
  Local branch: HEAD   |   Remote branch: origin/main

  PHASE 1 — INVENTORY
  Run these commands and record every changed file:
    git diff --name-status <merge-base> HEAD
    git diff --name-status <merge-base> origin/main
  Replace <merge-base> with: $(git merge-base HEAD origin/main)

  PHASE 2 — CLASSIFY each changed file using these rules:
    CLAUDE.md / settings*.json  → PREFER_LOCAL  (identity & permissions are device-specific)
    agents/*.md                 → PREFER_NEWER  (compare timestamps or content length; keep whichever is richer)
    commands/**                 → KEEP_BOTH     (union of both sides; no file should be deleted)
    core/*.md / modes/*.md      → PREFER_REMOTE (treat remote as canonical reference)
    memory/MEMORY.md            → MANUAL_MERGE  (line-level merge; never drop entries)
    memory/project_*.md         → KEEP_LOCAL    (device-specific, gitignored anyway)
    setup.sh / README.md / sync.sh → PREFER_REMOTE (infra files; remote is usually more up-to-date)

  PHASE 3 — DECIDE
  For each file, output exactly one line:
    KEEP_LOCAL   <filepath>   <reason>
    KEEP_REMOTE  <filepath>   <reason>
    MANUAL_MERGE <filepath>   <reason>

  PHASE 4 — EXECUTE
  Apply each decision:
    KEEP_LOCAL   → git checkout HEAD -- <file>
    KEEP_REMOTE  → git checkout origin/main -- <file>
    MANUAL_MERGE → open the file, apply a 3-way merge keeping all meaningful content
  Then: git add -A && git commit -m "resolve: merge local + remote config"
  Then: git push origin main

  CONSTRAINTS:
  - Never delete a memory entry — only add or update.
  - Never overwrite settings.local.json with the remote version.
  - If in doubt between two agent definitions, keep the longer/richer one.
  - Do not silently discard any command file from either side.
────────────────────────────────────────────────────────────────────────────────

Run /sc:sync-config in Claude Code to execute this reasoning interactively.
PROMPT

  echo ""
  echo "Your local state is safe in branch: $BRANCH"
  echo "Resolve with: /sc:sync-config   OR   follow the prompt above manually."
fi
