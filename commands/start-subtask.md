---
description: Start a subtask session in the existing issue worktree (same branch)
---

Open a new session focused on a specific subtask of a GitHub issue, working in the **same worktree and branch** that was created by `/start-issue`. Fetches the issue and extracts context relevant to the subtask.

Arguments: $ARGUMENTS

## Argument Parsing

Parse the arguments to extract the issue number, subtask name, and optional `--fork` flag. Examples:

- `42 api-validation` — issue number + subtask name
- `42 write-tests --fork` — with fork flag
- `https://github.com/org/repo/issues/42 db-migration` — issue URL + subtask name

The subtask name should be a short hyphenated slug (e.g. `api-validation`, `write-tests`, `fix-styling`).

If a full GitHub URL is provided, extract the org/repo from the URL. Otherwise, detect the current repo:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## Safety Rules (STRICT)

- NEVER create a new branch — this command reuses the existing issue branch
- NEVER create a new worktree — this command reuses the existing issue worktree
- NEVER start coding or making changes automatically — always wait for user instructions after setup
- If anything goes wrong unexpectedly, explain the problem and let me decide how to proceed

## Workflow

### 1. Parse arguments and handle fork

1. Extract the issue number (or URL), subtask name, and `--fork` flag from the arguments
2. If `--fork` is present:
   - Run `/fork issue-<number>-<subtask-name>` to fork the current session and name it
   - This makes the session independent from the original — proceed with the rest of the workflow

### 2. Fetch issue details

1. Fetch issue details:
   ```bash
   gh issue view <NUMBER> --json number,title,body,labels,assignees,state,comments
   ```
2. If the issue doesn't exist or `gh` fails, explain the error clearly

### 3. Find the existing worktree

1. List all worktrees:
   ```bash
   git worktree list --porcelain
   ```

2. Find the worktree whose branch starts with `<issue-number>-` (strip `refs/heads/` from the `branch` field)

3. If no matching worktree is found:
   - Show an error: "No worktree found for issue #\<number\>. Run `/start-issue <number>` first to create one."
   - **STOP** — do not proceed

4. Record the worktree path and branch name

### 4. Build subtask context

1. Tokenize the subtask name into keywords (split on hyphens):
   - e.g. `api-validation` → `api`, `validation`

2. Search the issue body for relevant content:
   - Look for paragraphs, bullet points, or checklist items containing any of the keywords
   - Look for markdown headings/sections that match
   - Extract matching content with 2-3 lines of surrounding context

3. Search the issue comments for relevant content:
   - Same keyword matching as above
   - Include the comment author for context

4. If matches are found:
   - Compile them into a **"Subtask Context"** section
   - Group by source (issue body vs. specific comments)

5. If no specific matches are found:
   - Note: "No specific context found for subtask '\<subtask-name\>' in the issue"
   - Show the full issue body so the user has all available context

### 5. Move to the worktree

1. Change the working directory to the worktree path:
   ```bash
   cd <worktree-path>
   ```

### 6. Name the session

If `--fork` was NOT used (session was not already named by the fork):
```
/rename issue-<number>-<subtask-name>
```

For example: `/rename issue-42-api-validation`

### 7. Present summary

Display a clear summary:

- **Issue:** #\<number\> — \<title\>
- **Subtask:** \<subtask-name\>
- **Branch:** \<branch-name\> (shared with main issue session)
- **Worktree path:** \<path\>
- **Session name:** issue-\<number\>-\<subtask-name\>
- **Subtask Context:** show the extracted context (or note that none was found)

### 8. Wait for instructions

**STOP here.** Do NOT auto-start coding. Wait for me to tell you what to do with this subtask.

## Important Notes

- This command does NOT create branches or worktrees — it reuses what `/start-issue` created
- Multiple subtask sessions can work in the same worktree simultaneously (on different files)
- Be careful about file conflicts when multiple sessions share the same worktree
- The subtask name is used for session naming only — it does not affect the branch name
- If `gh` CLI is not authenticated or the issue doesn't exist, explain the error clearly
