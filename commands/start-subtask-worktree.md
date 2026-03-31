---
description: Create a temporary branch and worktree for an isolated subtask of an issue
---

Create a **temporary branch + worktree** for a specific subtask of a GitHub issue. The branch is based on the current HEAD of the issue's branch (not main). Use this when the subtask needs isolated file changes that shouldn't interfere with the main issue work.

Arguments: $ARGUMENTS

## Argument Parsing

Parse the arguments to extract the issue number, subtask name, and optional `--fork` flag. Examples:

- `42 db-migration` — issue number + subtask name
- `42 refactor-auth --fork` — with fork flag
- `https://github.com/org/repo/issues/42 schema-update` — issue URL + subtask name

The subtask name should be a short hyphenated slug (e.g. `db-migration`, `refactor-auth`, `add-tests`).

If a full GitHub URL is provided, extract the org/repo from the URL. Otherwise, detect the current repo:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## Safety Rules (STRICT)

- NEVER start coding or making changes automatically — always wait for user instructions after setup
- NEVER delete or overwrite an existing branch without explicit confirmation
- NEVER force push or run destructive git commands
- The temporary branch is based on the **issue branch's HEAD**, NOT on main/master
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

### 3. Find the existing issue worktree

1. List all worktrees:
   ```bash
   git worktree list --porcelain
   ```

2. Find the worktree whose branch starts with `<issue-number>-` (strip `refs/heads/` from the `branch` field)

3. If no matching worktree is found:
   - Show an error: "No worktree found for issue #\<number\>. Run `/start-issue <number>` first to create one."
   - **STOP** — do not proceed

4. Record the issue worktree path and its branch name (this is the **parent branch**)

### 4. Build subtask context

1. Tokenize the subtask name into keywords (split on hyphens):
   - e.g. `db-migration` → `db`, `migration`

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

### 5. Create the subtask branch

1. Get the current HEAD of the issue branch:
   ```bash
   git -C <issue-worktree-path> rev-parse HEAD
   ```

2. Generate the subtask branch name: `<issue-number>-<subtask-name>`
   - Example: issue #42, subtask `db-migration` → `42-db-migration`

3. Check if a branch with this name already exists:
   ```bash
   git rev-parse --verify <subtask-branch> 2>/dev/null
   git rev-parse --verify origin/<subtask-branch> 2>/dev/null
   ```
   - If it exists, ask me how to proceed: use the existing branch, choose a different name, or abort
   - **Wait for my choice** before proceeding

4. Create the branch from the issue branch's HEAD:
   ```bash
   git branch <subtask-branch> <issue-branch-HEAD-commit>
   ```

### 6. Enter the worktree

1. Enter the worktree using the `EnterWorktree` tool with the subtask branch name

2. Inside the worktree, checkout the subtask branch:
   ```bash
   git checkout <subtask-branch>
   ```

### 7. Name the session

If `--fork` was NOT used (session was not already named by the fork):
```
/rename issue-<number>-<subtask-name>
```

For example: `/rename issue-42-db-migration`

### 8. Present summary

Display a clear summary:

- **Issue:** #\<number\> — \<title\>
- **Subtask:** \<subtask-name\>
- **Parent branch:** \<issue-branch\> (from `/start-issue`)
- **Subtask branch:** \<subtask-branch\> (new, based on parent HEAD)
- **Worktree path:** \<new-worktree-path\>
- **Session name:** issue-\<number\>-\<subtask-name\>
- **Subtask Context:** show the extracted context (or note that none was found)

### 9. Wait for instructions

**STOP here.** Do NOT auto-start coding. Wait for me to tell you what to do with this subtask.

## Important Notes

- The subtask branch is based on the **issue branch's HEAD**, not on main/master — this ensures the subtask starts with all the issue work done so far
- Use `/cleanup-worktree` to clean up the subtask worktree when done
- If the subtask changes need to be merged back into the issue branch, that's a separate step (e.g. cherry-pick or merge)
- If `gh` CLI is not authenticated or the issue doesn't exist, explain the error clearly
- The subtask branch name is deterministic: `<issue-number>-<subtask-name>`
