---
description: Manually review the current session's tracking file for missed worktree events, milestones, PRs, and other Work Log gaps
---

A user-triggered sanity check. Walks the active session's tracking file, compares it to what actually happened in the conversation and on disk, and fills in anything missing — without ever inventing entries that didn't happen.

Arguments: $ARGUMENTS

## When to run this

- Long session, want to make sure nothing slipped through.
- After a flurry of activity (worktrees created, PRs opened, fixes landed) and you're not sure each one was logged.
- Before ending a session, as a final pass.

The user invokes this manually. There is no hook, no marker, no scheduled trigger.

## Argument Parsing

- No arguments: audit **every** issue this session is currently tracking (entries in `~/.claude/session-issues/$CLAUDE_CODE_SESSION_ID`).
- `<owner>/<repo>#<n>` or `#<n>` or `<n>`: audit only that issue's tracking file (must be tracked by current session).

## Workflow

### 1. Identify which tracking file(s) to audit

```bash
SESSION_FILE=~/.claude/session-issues/$CLAUDE_CODE_SESSION_ID
```

If `SESSION_FILE` does not exist, this session is not tracking any issue. Tell the user: "This session is not tracking any issue. Run `/track-issue <ref>` first." Stop.

Otherwise read the file — each line is an `<owner>-<repo>-<number>` reference. Resolve to `~/.claude/issues/<ref>.md`. If an argument was provided, narrow to just that one.

### 2. Locate the current session's block in the tracking file

For each tracking file:

1. Read the file.
2. Find the `## Session: $CLAUDE_CODE_SESSION_ID` block. If absent, treat the session as unregistered for this issue and skip with a note (do not invent a block).
3. Note the existing Work Log entries — these are the **already-recorded** events. Anything you add must not duplicate them.

### 3. Cross-check against actual session activity

Walk these signals and identify what *did* happen since the session started but is *not* in the Work Log:

#### Worktree state
- Run `git worktree list --porcelain` from the repo root.
- Compare its paths to:
  - The session's `**Worktree:**` field
  - Every `Worktree: Created at <path>` / `Worktree: Removed at <path>` / `Subtask worktree: …` Work Log line
- Identify:
  - Worktrees present on disk that match this issue (branch starts with `<number>-` or path matches the session's worktree) but have no `Created` log line in this session's block → candidate for backfill.
  - Worktrees previously logged as `Created` here that are no longer on disk and have no matching `Removed` line → candidate for backfill.

#### PRs opened
- Scan the conversation for tool calls / outputs that opened a PR (`gh pr create` outputs, PR URLs in Bash results).
- For each PR URL, check the Work Log for `PR: #<number>` entry. If absent → candidate.

#### Commits
- `git log --since="<session start ts>" --oneline` from the relevant repo path.
- Use this for context only. Do **not** auto-add a Work Log line per commit — routine commits aren't supposed to be logged. Use it to cross-reference fixes that the user described as hard-won, milestones, etc.

#### Milestones, hard fixes, workarounds, plans, findings
- These don't have a mechanical signal — they require re-reading the conversation.
- Look at the messages in **this session** since the most recent Work Log entry's timestamp (or session start, if none).
- Identify any of: planning decisions agreed with user, root causes found, workarounds applied, significant refactors completed.
- For each candidate, check the Work Log for an existing entry covering it.

### 4. Apply the Worktree Recording rules from /track-issue

For any worktree-related gap, follow the **Worktree Recording** section of `commands/track-issue.md` exactly. Idempotency rules from that section apply: grep before append, never duplicate, use the `Subtask worktree:` prefix where appropriate.

### 5. Apply Milestone Update rules from /track-issue

For any non-worktree gap (PRs, milestones, fixes, findings), follow the **Milestone Updates** section of `commands/track-issue.md`. Use the `[<HH:MM>] <type>: <description>` format already established. Never invent a milestone — only log what is verifiable from the conversation or git/gh state.

### 6. Report

Produce a short summary for the user:

```
Audit of <owner>/<repo>#<n>:
  Worktrees:
    + Logged Created at <path>
    - (no missing entries)
  PRs:
    + Logged PR: #<n> <url>
  Milestones / fixes / findings:
    + Logged Plan: <…>
    + (none missing)
  Already complete: 4 entries verified.
```

If the audit added nothing, just say: `Audit of <ref>: tracking file is up to date (N entries verified).`

### 7. Stop

This command does **not** create branches, worktrees, PRs, or any new state. It only **reads** the world and **records** what it observes into the tracking file. If during the audit you notice something the user might want to *do* (e.g. open a missing PR, clean a stale worktree), surface it as a suggestion at the end — do not act on it.

## Important Notes

- Never invent log entries. Every appended line must correspond to a real, verifiable event.
- Always use the existing log formats from `commands/track-issue.md`. Do not introduce new formats.
- This is a manual command — running it twice in a row should produce no second-pass changes (idempotency).
- If the session is forked/branched and the resume hook has already created a session block, audit *that* block — not the parent's.
- **Context-window limits:** the audit can only see what is currently in the conversation context. In long sessions, earlier turns may have been compacted or summarized — events from those turns are no longer directly recoverable. Treat absence-from-context as "uncertain", not "did not happen". Worktree state and `gh`/`git` outputs run *during* the audit are authoritative; conversation memory of earlier work is best-effort.
