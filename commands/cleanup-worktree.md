---
description: Safely clean up a single worktree (current or specified)
---

Clean up a single git worktree, handling uncommitted changes and unpushed commits safely.

Arguments: $ARGUMENTS

## Argument Parsing

Parse the arguments to determine which worktree to clean up:

- No arguments: clean up the **current** worktree (must be a worktree, not the main working tree)
- Path: clean up the worktree at the given path (e.g. `.claude/worktrees/my-feature`)
- Branch name: find and clean up the worktree associated with that branch

## Safety Rules (STRICT)

- NEVER remove the main working tree
- NEVER discard uncommitted changes without explicit confirmation
- NEVER delete an unmerged branch without explicit confirmation
- NEVER force-delete a branch (`git branch -D`) — use `git branch -d` and ask if it fails
- If anything goes wrong unexpectedly, explain the problem and let me decide how to proceed

## Workflow

### 1. Identify the target worktree

1. List all worktrees:
   ```bash
   git worktree list --porcelain
   ```

2. Determine the target:
   - **No arguments:** use the current working directory. Verify it is a worktree (not the main working tree) by checking if `git rev-parse --path-format=absolute --git-common-dir` differs from `git rev-parse --path-format=absolute --git-dir`
   - **Path provided:** resolve to absolute path, find matching worktree
   - **Branch name provided:** find the worktree with that branch checked out

3. If no matching worktree is found, list available worktrees and ask me to clarify

4. Record the worktree path and its branch name for later steps

### 2. Check for uncommitted changes

1. Check for unstaged, staged, and untracked files:
   ```bash
   git -C <worktree-path> status --porcelain
   ```

2. If there are changes, show them and present options:
   - **Commit:** create a WIP commit with the changes
   - **Stash:** stash the changes (note: stash is global, not per-worktree)
   - **Discard:** discard all changes (requires explicit confirmation)
   - **Abort:** stop the cleanup

3. **Wait for my choice** before proceeding

### 3. Check for unpushed commits

1. Check for unpushed commits:
   ```bash
   git -C <worktree-path> log @{upstream}..HEAD --oneline 2>/dev/null
   ```
   - If no upstream is set, try:
     ```bash
     git -C <worktree-path> log origin/<branch>..HEAD --oneline 2>/dev/null
     ```
   - If neither works, check if the branch has any commits not on the default branch

2. If there are unpushed commits, show them and present options:
   - **Push:** push the branch to origin
   - **Continue:** proceed without pushing (commits will be lost if branch is deleted)
   - **Abort:** stop the cleanup

3. **Wait for my choice** before proceeding

### 4. Remove the worktree

1. Remove the worktree:
   ```bash
   git worktree remove <worktree-path>
   ```
   - If this fails (e.g. dirty tree), explain the error and ask how to proceed

### 5. Clean up the branch

1. Check if the branch is merged into the default branch:
   ```bash
   git branch --merged <default-branch> | grep -w <branch-name>
   ```

2. **If merged:** delete the branch:
   ```bash
   git branch -d <branch-name>
   ```

3. **If not merged:** inform me and ask whether to:
   - **Delete anyway** (will use `git branch -D` only with explicit confirmation)
   - **Keep the branch** for later use

4. **Wait for my choice** if the branch is not merged

### 6. Log removal in any tracked issue files

For every tracked-issue file under `~/.claude/issues/`, check if the just-removed worktree path appears in any session's `**Worktree:**` field or Work Log entries. For each match, follow the **Worktree Recording** idempotency rules from `commands/track-issue.md`:

1. Grep the current session's Work Log for `Worktree: Removed at <path>` (or `Subtask worktree: Removed at <path>`). If absent, append it.
2. If the removed path matches the current session's `**Worktree:**` field, replace that field with `(none)`.
3. Refresh the snapshot file for that issue:
   ```bash
   git -C <main-repo-path> worktree list --porcelain > ~/.claude/worktree-snapshots/<owner>-<repo>-<number>.txt
   ```

Skip silently if the path isn't referenced in any tracking file. Never duplicate an existing entry. Use `Subtask worktree:` prefix when the worktree was originally logged with that prefix.

### 7. Final cleanup

1. Prune stale worktree references:
   ```bash
   git worktree prune
   ```

2. Show a summary of what was done:
   - Worktree path removed
   - Branch deleted (or kept)
   - Any stashed/committed changes
   - Tracking files updated (if any)

## Important Notes

- Always confirm before any destructive action (discarding changes, deleting unmerged branches)
- If the current directory IS the worktree being removed, warn that the shell will be in a deleted directory after cleanup
- The default branch detection uses the same method as `rebase-branch.md`:
  - `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
  - Fallback: check for `main` or `master`
