---
description: Link current session to a GitHub issue for tracking work across sessions
---

Track work done in this Claude Code session against a GitHub issue. Creates a log file at `~/.claude/issues/` so you can find related sessions later.

Arguments: $ARGUMENTS

## Argument Parsing

Parse arguments to extract issue reference:
- `owner/repo#123` — full issue reference
- `#123` or `123` — issue number (uses current repo)
- `https://github.com/owner/repo/issues/123` — full URL

Extract owner, repo, and issue number. If only number provided, detect current repo:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
```

## Workflow

### 1. Validate and fetch issue

```bash
gh issue view <NUMBER> --repo <OWNER>/<REPO> --json number,title,state
```

If issue doesn't exist or is inaccessible, report error and stop.

### 2. Check for existing tracking

Read the current session's tracked issues from environment or session state.

If already tracking other issues in this session:
1. List currently tracked issues
2. Ask user: "Already tracking [issues]. Add this issue too? (Sessions will be cross-referenced in both files)"
3. If user declines, stop without changes

### 3. Set up tracking file

Create directory if needed:
```bash
mkdir -p ~/.claude/issues
```

File path: `~/.claude/issues/<owner>-<repo>-<number>.md`

### 4. Add session entry

Get current session info:
- Session ID: Use `$CLAUDE_SESSION_ID` environment variable or generate unique ID
- Timestamp: Current date/time
- Branch: `git branch --show-current`
- Initial description: "Session started — tracking issue #<number>"

If file exists, append new session entry. If not, create with header.

Also save the session-to-issue mapping for fork tracking:
```bash
mkdir -p ~/.claude/session-issues
echo "<owner>-<repo>-<number>" >> ~/.claude/session-issues/$CLAUDE_SESSION_ID
```

**File format:**
```markdown
# <owner>/<repo>#<number>: <issue-title>

Issue: https://github.com/<owner>/<repo>/issues/<number>

---

## Session: <session-id>
**Started:** <timestamp>
**Branch:** <branch-name>
**Commits:** (none yet)

### Work Log
- Session started — tracking issue #<number>

---
```

### 5. Cross-reference if multi-issue

If tracking multiple issues in this session, add a note to ALL tracked issue files:

```markdown
> **Note:** This session also worked on: owner/repo#X, owner/repo#Y
```

### 6. Confirm to user

Display:
- Issue: #<number> — <title>
- Tracking file: ~/.claude/issues/<owner>-<repo>-<number>.md
- Session ID: <id>
- Other tracked issues (if any)

Tell user: "I'll update the work log when we hit milestones (commits, plans, major findings). You can also ask me to update it anytime."

## Milestone Updates

Throughout the session, when the following occur, update the session's Work Log:

1. **After commits**: Add commit hash and one-line summary
2. **After finalizing a plan**: Add "Planned: <brief description>"
3. **After major investigation findings**: Add "Found: <brief description>"
4. **When user explicitly asks**: Update with whatever context is relevant

To update, read the tracking file, find the current session section, append to Work Log, write back.

**Update format:**
```markdown
- [<timestamp>] <type>: <description>
```

Example:
```markdown
### Work Log
- Session started — tracking issue #42
- [14:30] Commit: abc1234 - Fix null check in auth handler
- [14:45] Found: Bug caused by race condition in token refresh
- [15:00] Planned: Add mutex lock before token access
- [15:20] Commit: def5678 - Add mutex lock to prevent race condition
```

## Session End

When session ends or user switches to different work, add final entry:
```markdown
- [<timestamp>] Session ended
```

## Session Fork Tracking

To automatically track forked sessions, add this hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/track-issue-resume.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

When a session is forked/resumed, the hook reads which issues the parent session was tracking and adds the new session to those issue files automatically.

## Important Notes

- Always use absolute paths for the tracking file
- Preserve existing content when updating — only append or modify current session section
- If git commands fail (not in repo), still track but note "Branch: (not in git repo)"
- Session ID should be consistent if user runs /track-issue multiple times in same session
- Session-to-issue mappings stored at `~/.claude/session-issues/<session-id>`
