---
description: Show every session recorded for one tracked issue, with branch, worktree, and Work Log per session
---

Render a session-by-session view of one issue's tracking file. Read-only; never edits.

Arguments: $ARGUMENTS

## Argument Parsing

Accept any of:

- `<owner>/<repo>#<num>` — full issue reference
- `#<num>` or `<num>` — issue number (uses current repo, detected via `gh repo view --json nameWithOwner`)
- `https://github.com/<owner>/<repo>/issues/<num>` — full URL

If only a number is given but the cwd is not inside a git repo (or `gh` cannot resolve it), ask the user to provide the full `<owner>/<repo>#<num>` form and stop.

## Workflow

### 1. Resolve to a tracking file

Construct path: `~/.claude/issues/<owner>-<repo>-<num>.md`.

If the file does not exist:

- Tell the user: "No tracking file for `<owner>/<repo>#<num>`."
- Suggest: "Run `/track-issue <ref>` to start tracking, or `/list-issues` to see what is tracked."
- Stop.

### 2. Fetch current GitHub state (best-effort)

```bash
gh issue view <num> --repo <owner>/<repo> --json state,title -q '"\(.state) \(.title)"'
```

If this fails (offline, auth error, deleted issue), continue without state — show `?` in the header and proceed using only on-disk data.

### 3. Parse the tracking file

Read the file. Extract:

- **Header**: `# <owner>/<repo>#<num>: <title>` and the `Issue:` URL line.
- **Sessions**: every `## Session:` block. For each:
  - **Session ID** from the heading; note any parenthesized origin like `(forked from ...)` or `(branched from ...)`.
  - **Started** (`**Started:**` value)
  - **Branch** (`**Branch:**` value)
  - **Worktree** (`**Worktree:**` value if present, else `(unknown)`)
  - **Commits** (`**Commits:**` line if present, else `(none yet)`)
  - **Work Log entries** — every bullet under the session's `### Work Log` heading, until the next `---` or `## Session:` boundary.

A session block ends at the next `---` divider, the next `## Session:` heading, or end-of-file — whichever comes first.

### 4. Render output

Print, in order:

```
<owner>/<repo>#<num>: <title> [<state>]
Issue: <url>
Tracking file: ~/.claude/issues/<owner>-<repo>-<num>.md

<N> session(s):
```

Then, for each session, sorted by `**Started:**` ascending (oldest first):

```
[<index>] <session-id-short> — <Started> <origin>
        Branch:   <branch>
        Worktree: <worktree>
        Commits:  <commits>
        Work log:
          - Session started — tracking issue #<num>
          - [14:45] Found: ...
          - [16:30] PR: #156 https://...
```

Format notes:

- `<session-id-short>` = first 8 chars of the session ID, a visual aid only — print the full ID once at the top of the block: `[<index>] Session <full-id>`.
- `<origin>` = `(forked from <short-parent>)` or `(branched from <short-parent>)` if applicable, else empty.
- Indent Work Log entries under their session for readability.
- If the Work Log is empty, print `Work log: (empty)`.

### 5. Footer

After the last session:

- If the issue is closed and the most recent Work Log entry doesn't include `Session ended`, note this is open-ended.
- Suggest `/list-issues` if the user wants to find related issues. One short line.

## Important Notes

- **Read-only.** Never modify the tracking file.
- **Display fidelity**: render Work Log entries verbatim. Do not paraphrase or merge.
- **Long Work Logs**: if a session has more than ~30 entries, render all of them anyway — truncation hides the value of this command. The user asked for sessions; show them.
- **Cross-session ordering**: oldest session first by default. The user can scroll up to see history; the most recent session is at the bottom and visually closest to the prompt.
- **Forks/branches**: when a session has a parent, print the parent's short ID inline so the lineage is clear without forcing the reader to scan IDs.
- **Time zones**: timestamps are rendered as written in the file. No conversion.
