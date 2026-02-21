---
description: Rebase current branch over another branch, resolving conflicts with human guidance
---

Rebase the current branch onto another branch. When conflicts arise, analyze them and ask for guidance before resolving.

Arguments: $ARGUMENTS

## Argument Parsing

Parse the arguments to determine the rebase mode. Examples:

**Simple rebase (onto a branch):**
- No arguments: detect the default branch (`main` or `master`) and rebase onto it
- `origin`: fetch origin, rebase onto `origin/<default-branch>`
- `origin/<branch>`: fetch origin, rebase onto `origin/<branch>`
- `<branch>`: rebase onto local `<branch>`
- `<source> onto <target>`: checkout `<source>` first, then rebase onto `<target>`

**Rebase --onto (transplant commits):**
- `--onto <newbase> <upstream>`: run `git rebase --onto <newbase> <upstream>`
- `--onto <newbase> <upstream> <branch>`: run `git rebase --onto <newbase> <upstream> <branch>`
- Any argument containing `--onto` should be passed through to git rebase as-is

**Detecting the default branch:**
- Run: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
- If that fails, check if `main` or `master` exists locally: `git rev-parse --verify main 2>/dev/null || git rev-parse --verify master 2>/dev/null`
- If neither is found, ask me which branch to use

## Safety Rules (STRICT)

- NEVER run `git reset --hard`, `git checkout .`, `git clean -f`, or any destructive command
- NEVER use `git commit --amend`
- NEVER force push unless I explicitly ask for it
- ALWAYS create a backup branch before starting
- If anything goes wrong unexpectedly, do NOT automatically abort — explain the problem and let me decide how to proceed

## Workflow

### 1. Pre-flight checks

1. Run `git status --porcelain` to check for uncommitted changes
   - If there are changes, stash them: `git stash push -m "rebase-auto-stash"`
   - Remember to pop the stash after rebase completes
2. Record the current branch name
3. Create a backup branch: `git branch backup/<current-branch>-pre-rebase`
4. Tell me the backup branch name

### 2. Gather context

1. Parse the arguments to determine the target branch
2. If fetching is needed, run `git fetch <remote>`
3. Show me a brief summary:
   - Current branch
   - Target branch
   - Number of commits to replay: `git rev-list --count <target>..HEAD`
4. Check if diff3 conflict style is enabled: `git config merge.conflictstyle`
   - If not diff3, temporarily set it: `git config merge.conflictstyle diff3`
   - Remember to restore the original value after rebase

### 3. Start the rebase

- Simple rebase: `git rebase <target>`
- Onto rebase: `git rebase --onto <newbase> <upstream>` (with optional `<branch>`)
- If a source branch was specified (e.g. `<source> onto <target>`), checkout `<source>` first

### 4. Handle conflicts

If the rebase stops due to conflicts:

#### For each conflicted file:

1. **Identify the conflict type** by reading the file:
   - Whitespace-only conflict (indentation, line endings, trailing spaces)
   - Content conflict (actual code changes)

2. **Whitespace-only conflicts**: resolve automatically, stage the file, and mention what you did.

3. **All other conflicts** (even if they seem simple): **STOP and present to me**:
   - Show the conflicting file path and line range
   - Find the merge base: `git merge-base HEAD <target>`
   - Show what **our branch** changed in this file since the merge base: `git diff <merge-base> HEAD -- <file>`
   - Show what **the target branch** changed in this file since the merge base: `git diff <merge-base> <target> -- <file>`
   - Run `git log -p -n 3 <target> -- <file>` to understand the intent behind recent target branch changes
   - Show the conflict markers with surrounding context (at least 10 lines above and below)
   - Summarize clearly: what our branch intended vs what the target branch intended, and where they clash
   - Suggest a resolution with your reasoning
   - **Wait for my confirmation or alternative instructions before touching the file**

4. After I confirm a resolution:
   - Apply the resolution
   - Verify no conflict markers remain in the file: search for `<<<<<<<`
   - Stage the file with `git add <file>`

5. After ALL conflicts in the current commit are resolved:
   - Run `git rebase --continue`
   - If new conflicts arise, repeat step 4

### 5. Post-rebase

1. Run `git status` to confirm clean state
2. Show `git log --oneline -10` to confirm the history looks correct
3. If changes were stashed, run `git stash pop`
4. If diff3 was temporarily set, restore the original conflict style
5. Summarize:
   - Number of commits replayed
   - Number of conflicts resolved
   - Files that had conflicts
   - The backup branch name (in case I need to recover)

### 6. If rebase fails or gets stuck

- Do NOT automatically run `git rebase --abort`
- Explain clearly what went wrong and why the rebase is stuck
- Show any relevant error output
- Present my options (e.g. fix the issue and retry, skip this commit with `git rebase --skip`, or abort with `git rebase --abort`)
- **Wait for my decision** before taking any action
- If I choose to abort, run `git rebase --abort`, confirm the branch is back to its original state, and remind me the backup branch is available

## Important Notes

- Work through conflicts ONE COMMIT at a time as git rebase presents them
- NEVER resolve a non-trivial conflict without my explicit approval
- NEVER skip a conflict or silently pick one side
- If you are unsure about anything, ask before acting
- After the rebase is done, do NOT push unless I ask
