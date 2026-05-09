---
description: List GitHub issues this machine has tracking files for, with filters by activity date, state, and recency
---

Walk `~/.claude/issues/` and produce a table of every tracked issue, optionally filtered by recency or state. Reads tracking files only — no writes.

Arguments: $ARGUMENTS

## Argument Parsing

Single filter flag, plus optional `--repo <owner>/<repo>` to narrow to one repository. Filters are mutually exclusive — if more than one is supplied, ask the user which they want and stop.

| Flag | Meaning |
|------|---------|
| (none) | All tracked issues |
| `--active` | At least one session within the last 7 days |
| `--completed` | The GitHub issue is closed (state=CLOSED) |
| `--today` | At least one session whose `**Started:**` date is today |
| `--yesterday` | At least one session whose `**Started:**` date is yesterday |
| `--since <YYYY-MM-DD>` | At least one session on or after the given date |
| `--period <START> <END>` | At least one session whose date falls in `[START, END]` inclusive (both `YYYY-MM-DD`) |
| `--repo <owner>/<repo>` | Restrict to one repo. Combinable with any of the above. |

If a date is malformed, surface a clear error and stop.

## Workflow

### 1. Enumerate tracking files

```bash
ls ~/.claude/issues/*.md 2>/dev/null
```

If there are no files, tell the user "No tracked issues on this machine." and stop.

If `--repo <owner>/<repo>` is set, restrict to files whose names start with `<owner>-<repo>-`.

### 2. Parse each file

For each file, extract:

- **Issue ref**: from the filename (`<owner>-<repo>-<num>.md` → `<owner>/<repo>#<num>`)
- **Title**: from the first `# ` heading line (strip the `<owner>/<repo>#<num>: ` prefix)
- **Issue URL**: from the `Issue:` line in the header
- **Sessions**: every `## Session:` block. For each, capture the `**Started:**` value as a timestamp.
- **Last session date**: the most recent session's `**Started:**` date (`YYYY-MM-DD`).
- **Session count**: total number of `## Session:` blocks in the file.

If a file has zero sessions or is malformed, include it in output but mark `last: (none)` and `0 sessions`.

### 3. Apply the filter

#### Activity-based filters (`--active`, `--today`, `--yesterday`, `--since`, `--period`)

These filter on session-start dates. Compute today's date once; derive yesterday and the 7-day window from it. An issue passes the filter if **any** of its session timestamps satisfies the rule.

#### State-based filters (`--completed`)

For each candidate file, fetch state from GitHub:

```bash
gh issue view <num> --repo <owner>/<repo> --json state -q .state
```

Run these in parallel (background subshells) when there are many files, to avoid serial latency. If `gh` fails (network, auth, deleted issue), mark state as `?` and exclude from `--completed` results (do not falsely include).

#### `--active`

A passing issue must satisfy **both**: session within the last 7 days AND state is `OPEN`. Closed issues with recent activity are excluded — `--completed` is the right filter for those.

### 4. Render output

Sort the resulting issues by **most recent session date, descending**. Issues with no sessions go last.

For each row print:

```
#<num>  <owner>/<repo>   <state>   <N> session<s>   last: <YYYY-MM-DD>   <title>
```

- `<state>` is `open`, `closed`, or `?` if unfetched.
- Truncate `<title>` to keep the row readable (~80 chars total before title).
- Use a fixed-width layout — the human will paste this into a terminal.

Add a one-line header summarizing the filter:

```
Tracked issues (filter: --active, repo: AbanoubGhadban/my-claude) — N matches
```

If zero matches, say so and exit cleanly.

### 5. After-output hint

If the user wants to drill into one of these, suggest `/issue-sessions <ref>` for a session-by-session breakdown. One short line, only when there are matches.

## Important Notes

- **Read-only.** Never modify a tracking file.
- **No `gh` calls unless required by the active filter** (i.e. only fetch state when `--active` or `--completed` is set, or when state is part of the requested output for some other reason). Default listing shows state as `?` to avoid burning API quota on a routine ls-style command.
- **Time zone**: all date arithmetic uses the local machine's clock. Sessions are assumed to be in the same local time as the user invoking the command.
- **Missing fields tolerated**: a tracking file written before the format included a particular field still parses — just leave the field unknown.
- **Do not fabricate session counts**: if parsing is ambiguous, prefer reporting `?` over guessing.
