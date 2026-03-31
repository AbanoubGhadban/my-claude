---
description: Scan all worktrees and batch clean up merged ones
---

Scan ALL worktrees, auto-remove merged+clean ones, prompt for merged+dirty ones, and skip unmerged ones.

Arguments: $ARGUMENTS

## Safety Rules (STRICT)

- NEVER remove the main working tree
- NEVER auto-remove a worktree with uncommitted changes or unpushed commits — always ask first
- NEVER delete an unmerged branch without explicit confirmation
- NEVER force-delete a branch (`git branch -D`) — use `git branch -d` and ask if it fails
- ALWAYS present a scan summary and wait for confirmation before removing anything
- If anything goes wrong unexpectedly, explain the problem and let me decide how to proceed

## Workflow

### 1. Detect the default branch

1. Detect the repo's default branch:
   - Run: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
   - If that fails, check if `main` or `master` exists locally: `git rev-parse --verify main 2>/dev/null || git rev-parse --verify master 2>/dev/null`
   - If neither is found, ask me which branch to use

2. Fetch latest from origin:
   ```bash
   git fetch origin
   ```

### 2. Scan all worktrees

1. List all worktrees:
   ```bash
   git worktree list --porcelain
   ```

2. Identify the main working tree (the first entry — where `.git` is a directory, not a file) and exclude it from processing

3. For each remaining worktree, gather:
   - **Worktree path**
   - **Branch name** (from the `branch` field, strip `refs/heads/` prefix)
   - **Detached HEAD** (if `HEAD` is detached, flag it)

### 3. Classify each worktree

For each worktree (excluding main), determine its state:

#### Merge detection

A branch is considered "merged" if **either** condition is true:

1. **Ancestor check** — the branch tip is an ancestor of the default branch:
   ```bash
   git merge-base --is-ancestor <branch> origin/<default-branch>
   ```

2. **Empty diff heuristic** (catches squash merges) — no diff between the branch and the default branch:
   ```bash
   git diff origin/<default-branch>...<branch> --quiet
   ```

#### Dirty state checks

Run these inside the worktree:

1. **Uncommitted changes** (unstaged, staged, untracked):
   ```bash
   git -C <worktree-path> status --porcelain
   ```

2. **Unpushed commits:**
   ```bash
   git -C <worktree-path> log @{upstream}..HEAD --oneline 2>/dev/null
   ```
   - If no upstream is set, fall back to:
     ```bash
     git -C <worktree-path> log origin/<default-branch>..HEAD --oneline 2>/dev/null
     ```

#### Classification

- **Merged + Clean** — merged and no dirty state → auto-remove candidate
- **Merged + Dirty** — merged but has uncommitted changes or unpushed commits → prompt per worktree
- **Not merged** — not merged regardless of dirty state → skip, report only
- **Detached HEAD** — HEAD is detached → skip, report only

### 4. Present scan summary

Display a summary table before taking any action:

```
Worktree Scan Results
=====================

Auto-remove (merged + clean):
  - .claude/worktrees/42-fix-login (branch: 42-fix-login-bug)
  - .claude/worktrees/15-update-docs (branch: 15-update-docs)

Needs confirmation (merged + dirty):
  - .claude/worktrees/33-refactor-api (branch: 33-refactor-api)
    Dirty: 2 uncommitted files, 1 unpushed commit

Skipped (not merged):
  - .claude/worktrees/50-new-feature (branch: 50-new-feature) — 3 commits ahead

Skipped (detached HEAD):
  - .claude/worktrees/experiment (HEAD detached at abc1234)
```

**Wait for my confirmation** before proceeding with removals.

### 5. Auto-remove merged + clean worktrees

For each merged+clean worktree:

1. Remove the worktree:
   ```bash
   git worktree remove <worktree-path>
   ```

2. Delete the branch:
   ```bash
   git branch -d <branch-name>
   ```

3. Report each removal as it happens

### 6. Handle merged + dirty worktrees

For each merged+dirty worktree, show the dirty details:

1. Show uncommitted changes:
   ```bash
   git -C <worktree-path> status --short
   ```

2. Show unpushed commits (if any):
   ```bash
   git -C <worktree-path> log @{upstream}..HEAD --oneline 2>/dev/null
   ```

3. Present options for this worktree:
   - **Remove anyway** — discard changes and remove
   - **Stash first** — stash changes, then remove worktree and branch
   - **Skip** — leave this worktree alone

4. **Wait for my choice** before proceeding to the next dirty worktree

### 7. Final cleanup

1. Prune stale worktree references:
   ```bash
   git worktree prune
   ```

2. Show a final summary:
   - Number of worktrees removed
   - Number of branches deleted
   - Number of worktrees skipped (and why)
   - Any worktrees that remain

## Important Notes

- Always present the full scan summary before removing anything
- Process auto-removals first, then prompt for dirty worktrees one by one
- If a worktree removal fails, report the error and continue with the rest
- If the current directory is one of the worktrees being removed, warn about it before proceeding
- The empty-diff heuristic for squash merges may have false positives on branches with no commits — handle gracefully
