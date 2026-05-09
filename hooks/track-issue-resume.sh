#!/usr/bin/env bash
#
# Hook: Add resumed session to issue tracking files
# Fires on SessionStart when session is resumed (includes forks)
#
# Input (JSON via stdin):
#   session_id, transcript_path, cwd, etc.
#
# Reads tracked issues from ~/.claude/session-issues/<old-session-id>
# and adds new session entry to each issue's tracking file.

set -euo pipefail

ISSUES_DIR="$HOME/.claude/issues"
SESSION_ISSUES_DIR="$HOME/.claude/session-issues"

# Parse input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Try to find parent session from transcript path
# Format: ~/.claude/sessions/<session-id>/transcript.json
if [[ -n "$TRANSCRIPT_PATH" && "$TRANSCRIPT_PATH" =~ sessions/([^/]+)/ ]]; then
  PARENT_SESSION="${BASH_REMATCH[1]}"
else
  exit 0
fi

# Check if parent session was tracking any issues
PARENT_ISSUES_FILE="$SESSION_ISSUES_DIR/$PARENT_SESSION"
if [[ ! -f "$PARENT_ISSUES_FILE" ]]; then
  exit 0
fi

# Read tracked issues from parent
TRACKED_ISSUES=$(cat "$PARENT_ISSUES_FILE")
if [[ -z "$TRACKED_ISSUES" ]]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
BRANCH=$(git branch --show-current 2>/dev/null || echo "(not in git repo)")

# Copy issue tracking to new session
mkdir -p "$SESSION_ISSUES_DIR"
echo "$TRACKED_ISSUES" > "$SESSION_ISSUES_DIR/$SESSION_ID"

# Add new session entry to each issue's tracking file
while IFS= read -r issue_ref; do
  [[ -z "$issue_ref" ]] && continue

  # issue_ref format: owner-repo-number
  ISSUE_FILE="$ISSUES_DIR/$issue_ref.md"

  if [[ -f "$ISSUE_FILE" ]]; then
    # Add new session section
    cat >> "$ISSUE_FILE" << EOF

---

## Session: $SESSION_ID (forked from $PARENT_SESSION)
**Started:** $TIMESTAMP
**Branch:** $BRANCH
**Commits:** (none yet)

### Work Log
- Session forked from $PARENT_SESSION

EOF
  fi
done <<< "$TRACKED_ISSUES"
