#!/usr/bin/env bash
#
# Symlinks Claude customization files from this repo into ~/.claude/
# Run this after cloning on a new machine.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/commands"

link_file() {
  local src="$1"
  local dest="$2"

  if [ -L "$dest" ]; then
    echo "  Updating symlink: $dest -> $src"
    ln -sf "$src" "$dest"
  elif [ -e "$dest" ]; then
    echo "  Backing up existing: $dest -> ${dest}.bak"
    mv "$dest" "${dest}.bak"
    ln -s "$src" "$dest"
  else
    echo "  Linking: $dest -> $src"
    ln -s "$src" "$dest"
  fi
}

echo "Installing Claude customizations..."
echo

# Link top-level config files
for file in CLAUDE.md settings.json; do
  if [ -f "$REPO_DIR/$file" ]; then
    link_file "$REPO_DIR/$file" "$CLAUDE_DIR/$file"
  fi
done

# Link command files
for file in "$REPO_DIR"/commands/*.md; do
  [ -f "$file" ] || continue
  basename="$(basename "$file")"
  link_file "$file" "$CLAUDE_DIR/commands/$basename"
done

# Link shell helper scripts (codex-loop-helper.sh etc)
for file in "$REPO_DIR"/commands/*.sh; do
  [ -f "$file" ] || continue
  basename="$(basename "$file")"
  link_file "$file" "$CLAUDE_DIR/commands/$basename"
done

# Link bin scripts to ~/.local/bin for PATH access
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
for file in "$REPO_DIR"/bin/*; do
  [ -f "$file" ] || continue
  basename="$(basename "$file")"
  link_file "$file" "$LOCAL_BIN/$basename"
done

# Link hook scripts
mkdir -p "$CLAUDE_DIR/hooks"
for file in "$REPO_DIR"/hooks/*.sh; do
  [ -f "$file" ] || continue
  basename="$(basename "$file")"
  link_file "$file" "$CLAUDE_DIR/hooks/$basename"
done

# Create directories for issue tracking
mkdir -p "$CLAUDE_DIR/issues"
mkdir -p "$CLAUDE_DIR/session-issues"

echo
echo "Done! Claude customizations are now symlinked from this repo."
echo
echo "Notes:"
echo "  - Make sure ~/.local/bin is in your PATH for claude-oldest, claude-middle, claude-sota commands."
echo "    Add to shell config: export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
echo "  - To enable session fork tracking for /track-issue, add to ~/.claude/settings.json:"
echo '    "hooks": { "SessionStart": [{ "matcher": "resume", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/track-issue-resume.sh", "timeout": 5 }] }] }'
echo
echo "  - For a manual sweep of tracking-file completeness during a session, run /audit-tracking."
