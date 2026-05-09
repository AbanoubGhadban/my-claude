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
- Repo path: `git rev-parse --show-toplevel` (absolute path to current repo's main working tree)
- Worktree path: if cwd is inside a worktree (not the main working tree), record absolute path of that worktree; otherwise leave blank for now (the Worktree Recording section below fills it in)
- Initial description: "Session started — tracking issue #<number>"

If file exists, append new session entry. If not, create with header.

The header carries two fields used by the worktree audit hook:
- `Repo-Path:` — absolute path to the repo (set once on first creation; do not overwrite on subsequent sessions in the same file)
- `Last-Audit:` — timestamp of the last worktree audit (set to the current timestamp on file creation; updated by Claude when handling audit markers)

Also save the session-to-issue mapping for fork tracking:
```bash
mkdir -p ~/.claude/session-issues
echo "<owner>-<repo>-<number>" >> ~/.claude/session-issues/$CLAUDE_CODE_SESSION_ID
```

Initialize the worktree snapshot for the audit hook (so the first audit doesn't report all existing worktrees as "added"):
```bash
mkdir -p ~/.claude/worktree-snapshots
git -C <repo-path> worktree list --porcelain > ~/.claude/worktree-snapshots/<owner>-<repo>-<number>.txt
```

**File format (new file):**
```markdown
# <owner>/<repo>#<number>: <issue-title>

Issue: https://github.com/<owner>/<repo>/issues/<number>
Repo-Path: <absolute-path-to-repo>
Last-Audit: <timestamp>

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

**File format (existing file, new session appended):** keep header as-is. Only add a new `## Session:` block. Do **not** overwrite `Repo-Path:` or pre-existing `Last-Audit:` (the hook and audit handler manage `Last-Audit:`).

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

This section is the single source of truth for worktree event recording. Other commands (`/start-issue`, `/start-subtask-worktree`, `/cleanup-worktree`, `/cleanup-worktrees`) delegate here — they do not write tracking files, manage snapshots, or know log formats. If you are reading those commands and they say "follow `/track-issue` Worktree Recording", they mean this section.

Conversely, `/track-issue` does **not** create, remove, or move worktrees. Those are owned by `/start-issue`, `/start-subtask-worktree`, and `/cleanup-worktree*`. If at setup time the user wants a worktree and none exists, suggest `/start-issue <number>` (or `/start-subtask-worktree`) — do not execute `git worktree add` from here. Likewise, do not run `git worktree remove`; defer to `/cleanup-worktree`.

Rule of thumb: this section **observes and records**. Worktree-mutating commands **act and delegate the recording back here**.

### Idempotency (mandatory — never duplicate entries)

Before writing anything, check the file:

1. **Session header `**Worktree:**` field**: only update if it is missing, `(none)`, or different from the path you intend to record. If it already matches, do nothing.
2. **Work Log lines**: only append a `Worktree: Created at <path>` or `Worktree: Removed at <path>` entry if no existing line in the current session's Work Log mentions that exact path with that exact action. Use a literal-string grep against the file before appending.
3. **Snapshot file** (`~/.claude/worktree-snapshots/<owner>-<repo>-<number>.txt`): refresh by overwriting with the current `git -C <repo-path> worktree list --porcelain` output after any logged change. This prevents the audit hook from re-reporting the same event on the next prompt.

If another command (e.g. `/start-issue`) already updated the field, log entry, and snapshot, your job here is done — verify and move on. Never re-log the same event.

### Trigger points

Record/update at every one of these moments:

- At `/track-issue` setup time (this command), after step 4: scan `git worktree list --porcelain` for a worktree whose branch starts with `<issue-number>-` or whose path equals current cwd. If found, populate the session's `**Worktree:**` field. If the worktree was created in this session and not yet logged, append a `Worktree: Created at <path>` entry.
- When the user mentions creating, moving, or removing a worktree.
- When you observe (via tool output) a `git worktree add|remove|move` command run.
- When handling a `<track-issue-worktree-audit/>` marker (see Audit Marker Handling below).

### Log entry format

```markdown
- [<HH:MM>] Worktree: Created at <absolute-path>
- [<HH:MM>] Worktree: Removed at <absolute-path>
- [<HH:MM>] Worktree: Moved from <old-path> to <new-path>
```

For subtask worktrees (created via `/start-subtask-worktree`), use the `Subtask worktree:` prefix instead of `Worktree:` so the main issue worktree stays distinguishable in the log.

## Audit Marker Handling

The hook `~/.claude/hooks/worktree-audit.sh` runs on every `UserPromptSubmit`. It stays silent unless **both** gates pass for some tracked issue: ≥30 minutes since `Last-Audit:` AND the current `git worktree list` differs from the cached snapshot. When both pass it injects a marker:

```
<track-issue-worktree-audit file="<owner>-<repo>-<number>.md" added="<csv>" removed="<csv>"/>
```

`added` and `removed` are comma-separated absolute paths (either may be empty). When you see this marker in conversation context, before responding to the user's actual request:

1. Read the tracking file `~/.claude/issues/<file>`.
2. For each path in `added`: append `[<HH:MM>] Worktree: Created at <path>` to the **current session's** Work Log — but only if no existing line already records this creation (idempotency rule above).
3. For each path in `removed`: append `[<HH:MM>] Worktree: Removed at <path>` — same idempotency rule.
4. If a newly added worktree's path matches the current session (cwd resolves to one of the added paths), update that session's `**Worktree:**` field.
5. Update the header `Last-Audit: <current-timestamp>` (replace, don't duplicate).
6. The hook has already refreshed the snapshot file — do NOT rewrite it.
7. Stay silent unless something was actually appended. If you logged anything, emit one short line: `Logged worktree changes for #<number>.` Then proceed with the user's request.

If the marker shows up but every entry is already in the log (because another command or earlier handler beat you to it), only update `Last-Audit:` and stay silent.

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
- If git commands fail (not in repo), still track but note "Branch: (not in git repo)" and skip the snapshot init step
- Session ID should be consistent if user runs /track-issue multiple times in same session
- Session-to-issue mappings stored at `~/.claude/session-issues/<session-id>`
- Worktree snapshots stored at `~/.claude/worktree-snapshots/<owner>-<repo>-<number>.txt` (managed by the audit hook + worktree-touching commands; do not hand-edit unless re-syncing)
