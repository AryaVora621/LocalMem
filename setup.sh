#!/usr/bin/env bash
# setup.sh — Bootstrap Claude Code config symlinks on a new device.
# Run once after cloning: bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BAK_DIR="$HOME/.claude.bak"

echo "Repo: $REPO_DIR"
echo "Claude dir: $CLAUDE_DIR"

# Backup helper: move existing file/dir to .claude.bak if it exists and isn't already a symlink
backup_and_remove() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p "$BAK_DIR"
    local name
    name=$(basename "$target")
    echo "  Backing up $target -> $BAK_DIR/$name"
    mv "$target" "$BAK_DIR/$name"
  elif [ -L "$target" ]; then
    echo "  Removing existing symlink $target"
    rm "$target"
  fi
}

# Symlink helper
link() {
  local src="$1"   # repo path (source of truth)
  local dst="$2"   # ~/.claude/... path
  backup_and_remove "$dst"
  ln -s "$src" "$dst"
  echo "  Linked: $dst -> $src"
}

mkdir -p "$CLAUDE_DIR"

echo ""
echo "Creating symlinks..."
link "$REPO_DIR/CLAUDE.md"          "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/settings.json"      "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/settings.local.json" "$CLAUDE_DIR/settings.local.json"
link "$REPO_DIR/agents"             "$CLAUDE_DIR/agents"
link "$REPO_DIR/commands"           "$CLAUDE_DIR/commands"
link "$REPO_DIR/core"               "$CLAUDE_DIR/core"
link "$REPO_DIR/modes"              "$CLAUDE_DIR/modes"

# Memory symlink: path encodes username as -Users-<USER>
# e.g. /Users/Arya -> -Users-Arya
HOME_ENCODED=$(echo "$HOME" | sed 's|/|-|g')
MEMORY_PARENT="$CLAUDE_DIR/projects/${HOME_ENCODED}"
mkdir -p "$MEMORY_PARENT"
link "$REPO_DIR/memory" "$MEMORY_PARENT/memory"

echo ""
echo "Done. Verifying..."
ls -la "$CLAUDE_DIR/CLAUDE.md"
ls -la "$CLAUDE_DIR/agents"
echo ""
echo "Claude Code config is live. Start a new Claude Code session to confirm."
