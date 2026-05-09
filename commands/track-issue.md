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
- Session ID: Use `$CLAUDE_CODE_SESSION_ID` environment variable or generate unique ID
- Timestamp: Current date/time
- Branch: `git branch --show-current`
- Worktree path: if cwd is inside a worktree (not the main working tree), record absolute path of that worktree; otherwise `(none)` (the Worktree Recording section below keeps this in sync)
- Initial description: "Session started — tracking issue #<number>"

If file exists, append new session entry. If not, create with header.

Also save the session-to-issue mapping for fork tracking:
```bash
mkdir -p ~/.claude/session-issues
echo "<owner>-<repo>-<number>" >> ~/.claude/session-issues/$CLAUDE_CODE_SESSION_ID
```

**File format (new file):**
```markdown
# <owner>/<repo>#<number>: <issue-title>

Issue: https://github.com/<owner>/<repo>/issues/<number>

---

## Session: <session-id>
**Started:** <timestamp>
**Branch:** <branch-name>
**Worktree:** <absolute-path or "(none)">
**Commits:** (none yet)

### Work Log
- Session started — tracking issue #<number>

---
```

**File format (existing file, new session appended):** keep the file header as-is. Only add a new `## Session:` block at the bottom.

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

Tell user: "I'll update the work log for significant events only — milestones, hard-won fixes, workarounds, major findings. Not routine commits. Ask me anytime to log something specific."

## Worktree Recording

Throughout the session, keep the tracking file in sync with worktree state for this issue. Apply these rules whenever a worktree is created, removed, or noticed — whether the action came from `/start-issue`, `/start-subtask-worktree`, `/cleanup-worktree*`, raw `git worktree` invocations, IDE tooling, or direct user commands.

### Scope (this is the canonical record-keeper)

This section is the single source of truth for worktree event recording. Other commands (`/start-issue`, `/start-subtask-worktree`, `/cleanup-worktree`, `/cleanup-worktrees`) delegate here — they do not write tracking files or know log formats. If you are reading those commands and they say "follow `/track-issue` Worktree Recording", they mean this section.

Conversely, `/track-issue` does **not** create, remove, or move worktrees. Those are owned by `/start-issue`, `/start-subtask-worktree`, and `/cleanup-worktree*`. If at setup time the user wants a worktree and none exists, suggest `/start-issue <number>` (or `/start-subtask-worktree`) — do not execute `git worktree add` from here. Likewise, do not run `git worktree remove`; defer to `/cleanup-worktree`.

Rule of thumb: this section **observes and records**. Worktree-mutating commands **act and delegate the recording back here**.

### Idempotency (mandatory — never duplicate entries)

Before writing anything, check the file:

1. **Session header `**Worktree:**` field**: only update if it is missing, `(none)`, or different from the path you intend to record. If it already matches, do nothing.
2. **Work Log lines**: only append a `Worktree: Created at <path>` or `Worktree: Removed at <path>` entry if no existing line in the current session's Work Log mentions that exact path with that exact action. Use a literal-string grep against the file before appending.

If another command (e.g. `/start-issue`) already updated the field and log entry, your job here is done — verify and move on. Never re-log the same event.

### Trigger points

Record/update at every one of these moments:

- At `/track-issue` setup time (this command), after step 4: scan `git worktree list --porcelain` for a worktree whose branch starts with `<issue-number>-` or whose path equals current cwd. If found, populate the session's `**Worktree:**` field. If the worktree was created in this session and not yet logged, append a `Worktree: Created at <path>` entry.
- When the user mentions creating, moving, or removing a worktree.
- When you observe (via tool output) a `git worktree add|remove|move` command run.
- When the user runs `/audit-tracking`, which forces a full review of the tracking file against the current session's activity.

### Log entry format

```markdown
- [<HH:MM>] Worktree: Created at <absolute-path>
- [<HH:MM>] Worktree: Removed at <absolute-path>
- [<HH:MM>] Worktree: Moved from <old-path> to <new-path>
```

For subtask worktrees (created via `/start-subtask-worktree`), use the `Subtask worktree:` prefix instead of `Worktree:` so the main issue worktree stays distinguishable in the log.

## Milestone Updates

Throughout the session, update the Work Log **only for significant events** — not routine commits.

**What to log:**
1. **Milestones**: Major feature complete, significant refactor done, important decision made
2. **Hard-won fixes**: Bugs that took significant debugging time to solve
3. **Workarounds/patches**: Temporary fixes for critical issues (even in external libraries/frameworks we maintain)
4. **Major investigation findings**: Root cause discovered, unexpected behavior explained
5. **Plans finalized**: Architecture decisions, implementation strategy agreed
6. **PRs opened**: When creating a PR, log PR number and URL
7. **Worktree events**: Created / removed / moved (see Worktree Recording section above)
8. **User explicitly asks**: Whatever context they want recorded

**What NOT to log:**
- Routine commits (typo fixes, small adjustments, incremental progress)
- Standard implementation steps
- Every file change

To update, read the tracking file, find the current session section, append to Work Log, write back.

**Update format:**
```markdown
- [<timestamp>] <type>: <description>
```

Example:
```markdown
### Work Log
- Session started — tracking issue #42
- [14:45] Found: Race condition in token refresh — tokens invalidated mid-request when concurrent refresh triggered
- [15:00] Planned: Add mutex lock + token versioning to handle concurrent refreshes
- [15:20] Fixed: abc1234 - Took 2h to trace; symptom was intermittent 401s only under load
- [16:00] Workaround: Patched redis-client@3.2.1 connection pooling bug (upstream PR pending)
- [16:30] PR: #156 https://github.com/owner/repo/pull/156
```

## Session End

When session ends or user switches to different work, add final entry:
```markdown
- [<timestamp>] Session ended
```

## Session Branch/Fork Tracking

When a session is branched via `/branch`, the parent session's issue tracking should carry over to the new session.

### How it works

1. A `UserPromptSubmit` hook detects `/branch` commands
2. If parent session was tracking issues, hook injects marker: `<branch-tracking-inherit parent="..." issues="..."/>`
3. Branched session inherits this marker in conversation context
4. Claude detects marker and registers new session

### Handling the marker

**On EVERY response**, check conversation context for `<branch-tracking-inherit>` marker. If found AND current session not yet registered:

1. Parse parent session ID and issues list from marker
2. Create session-issues mapping:
   ```bash
   mkdir -p ~/.claude/session-issues
   echo "<issues>" | tr ',' '\n' > ~/.claude/session-issues/$CLAUDE_CODE_SESSION_ID
   ```
3. Append to each issue's tracking file:
   ```markdown
   ---

   ## Session: <current-session-id> (branched from <parent-session-id>)
   **Started:** <timestamp>
   **Branch:** <branch-name>
   **Commits:** (none yet)

   ### Work Log
   - Session branched from <parent-session-id>
   ```
4. Do this silently — don't mention it to user unless asked

### Hook setup

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/track-issue-branch.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Important Notes

- Always use absolute paths for the tracking file
- Preserve existing content when updating — only append or modify current session section
- If git commands fail (not in repo), still track but note "Branch: (not in git repo)"
- Session ID should be consistent if user runs /track-issue multiple times in same session
- Session-to-issue mappings stored at `~/.claude/session-issues/<session-id>`
- For a manual sweep that catches anything missed during the session (worktrees, milestones, PRs, fixes), the user can run `/audit-tracking`
