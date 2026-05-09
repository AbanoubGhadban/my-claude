#!/usr/bin/env bash
#
# UserPromptSubmit hook: emit a worktree audit marker when, for any tracked
# issue, BOTH gates pass:
#   1. >= 30 min since Last-Audit recorded in tracking file
#   2. Current `git worktree list` differs from cached snapshot
#
# Stays silent (zero output) otherwise. On most prompts: cheap file reads only.
#
# When emitting a marker, refreshes the snapshot atomically. Claude only needs
# to update the tracking file (work log + Last-Audit), not re-run worktree-list.

set -euo pipefail

ISSUES_DIR="$HOME/.claude/issues"
SESSION_ISSUES_DIR="$HOME/.claude/session-issues"
SNAPSHOT_DIR="$HOME/.claude/worktree-snapshots"
INTERVAL_MIN=30

# Cross-platform date parser (BSD/macOS + GNU/Linux). Echoes epoch seconds.
parse_date_to_epoch() {
  local input="$1"
  local out
  out=$(date -d "$input" +%s 2>/dev/null) && { echo "$out"; return 0; }
  out=$(date -j -f '%Y-%m-%d %H:%M' "$input" +%s 2>/dev/null) && { echo "$out"; return 0; }
  echo 0
}

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[[ -z "$SESSION_ID" ]] && exit 0
SESSION_FILE="$SESSION_ISSUES_DIR/$SESSION_ID"
[[ ! -f "$SESSION_FILE" ]] && exit 0

mkdir -p "$SNAPSHOT_DIR"
NOW_EPOCH=$(date +%s)

MARKERS=""

while IFS= read -r issue_ref; do
  [[ -z "$issue_ref" ]] && continue
  FILE="$ISSUES_DIR/$issue_ref.md"
  [[ ! -f "$FILE" ]] && continue

  # Gate 1: time since last audit
  LAST_AUDIT=$(grep -m1 '^Last-Audit:' "$FILE" 2>/dev/null | sed 's/^Last-Audit:[[:space:]]*//')
  if [[ -n "$LAST_AUDIT" ]]; then
    LAST_EPOCH=$(parse_date_to_epoch "$LAST_AUDIT")
    DIFF_MIN=$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))
    [[ $DIFF_MIN -lt $INTERVAL_MIN ]] && continue
  fi

  # Resolve repo path from tracking file
  REPO_PATH=$(grep -m1 '^Repo-Path:' "$FILE" 2>/dev/null | sed 's/^Repo-Path:[[:space:]]*//')
  [[ -z "$REPO_PATH" ]] && continue
  if [[ ! -e "$REPO_PATH/.git" ]]; then
    continue
  fi

  # Gate 2: worktree list change
  CURRENT=$(git -C "$REPO_PATH" worktree list --porcelain 2>/dev/null || true)
  [[ -z "$CURRENT" ]] && continue

  SNAPSHOT_FILE="$SNAPSHOT_DIR/$issue_ref.txt"
  PREV=""
  [[ -f "$SNAPSHOT_FILE" ]] && PREV=$(cat "$SNAPSHOT_FILE")

  if [[ "$CURRENT" == "$PREV" ]]; then
    continue
  fi

  # Compute path-level diff
  CURRENT_PATHS=$(echo "$CURRENT" | awk '/^worktree /{print $2}' | sort -u)
  PREV_PATHS=$(echo "$PREV" | awk '/^worktree /{print $2}' | sort -u)
  ADDED=$(comm -23 <(echo "$CURRENT_PATHS") <(echo "$PREV_PATHS") | awk 'NF' | tr '\n' ',' | sed 's/,$//')
  REMOVED=$(comm -13 <(echo "$CURRENT_PATHS") <(echo "$PREV_PATHS") | awk 'NF' | tr '\n' ',' | sed 's/,$//')

  if [[ -z "$ADDED" && -z "$REMOVED" ]]; then
    # Paths identical, only metadata (HEAD/branch) shifted — refresh silently.
    echo "$CURRENT" > "$SNAPSHOT_FILE"
    continue
  fi

  # Refresh snapshot atomically before emitting marker so Claude won't see
  # the same diff again on the next prompt.
  echo "$CURRENT" > "$SNAPSHOT_FILE"

  MARKERS+="<track-issue-worktree-audit file=\"$issue_ref.md\" added=\"$ADDED\" removed=\"$REMOVED\"/>"$'\n'
done < "$SESSION_FILE"

[[ -z "$MARKERS" ]] && exit 0

jq -n --arg ctx "$MARKERS" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $ctx
  }
}'

exit 0
