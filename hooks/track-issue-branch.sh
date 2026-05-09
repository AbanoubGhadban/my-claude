#!/usr/bin/env bash
#
# Hook: Inject tracking marker when /branch command detected
# Fires on UserPromptSubmit, checks for /branch pattern
#
# If current session is tracking issues, injects marker into conversation
# so the branched session inherits it and Claude can update tracking.

set -euo pipefail

SESSION_ISSUES_DIR="$HOME/.claude/session-issues"

# Parse input
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Check if this is a /branch command
if [[ ! "$PROMPT" =~ ^/branch ]]; then
  exit 0
fi

# Check if current session is tracking any issues
if [[ -z "$SESSION_ID" ]] || [[ ! -f "$SESSION_ISSUES_DIR/$SESSION_ID" ]]; then
  exit 0
fi

# Read tracked issues
TRACKED_ISSUES=$(cat "$SESSION_ISSUES_DIR/$SESSION_ID" | tr '\n' ',' | sed 's/,$//')

if [[ -z "$TRACKED_ISSUES" ]]; then
  exit 0
fi

# Inject marker into conversation
jq -n --arg parent "$SESSION_ID" --arg issues "$TRACKED_ISSUES" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "<branch-tracking-inherit parent=\"\($parent)\" issues=\"\($issues)\"/>"
  }
}'

exit 0
