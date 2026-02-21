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

echo
echo "Done! Claude customizations are now symlinked from this repo."
