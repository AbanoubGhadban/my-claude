---
description: Create a branch and worktree from a GitHub issue for parallel development
---

Given a GitHub issue number or URL, create a branch + worktree and show issue context. Smart enough to detect the correct base branch.

Arguments: $ARGUMENTS

## Argument Parsing

Parse the arguments to extract the issue number and optional base branch override. Examples:

- `42` — issue number
- `https://github.com/org/repo/issues/42` — issue URL (extract org/repo and issue number)
- `42 --base develop` — issue number with explicit base branch
- `42 --base origin/release-2.0` — issue number with explicit remote base branch

If a full GitHub URL is provided, extract the org/repo from the URL. Otherwise, detect the current repo:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## Safety Rules (STRICT)

- NEVER start coding or making changes automatically — always wait for user instructions after setup
- NEVER delete or overwrite an existing branch without explicit confirmation
- NEVER force push or run destructive git commands
- If anything goes wrong unexpectedly, explain the problem and let me decide how to proceed

## Workflow

### 1. Fetch issue details

1. Parse the arguments to extract the issue number (and optional `--base <branch>`)
2. Fetch issue details:
   ```bash
   gh issue view <NUMBER> --json number,title,body,labels,assignees,state,comments
   ```
3. If the issue is closed, warn me and ask whether to proceed

### 2. Determine the base branch

**If `--base <branch>` was provided**, use it directly — skip to step 3.

**Otherwise**, gather candidate branches:

1. **Detect the repo's default branch:**
   - Run: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`
   - If that fails, check if `main` or `master` exists locally: `git rev-parse --verify main 2>/dev/null || git rev-parse --verify master 2>/dev/null`
   - If neither is found, ask me which branch to use

2. **Scan issue body and comments** for branch references:
   - Look for patterns like "merge into `develop`", "target: `release-2.0`", "base branch: `staging`", "branch: `feature-x`"
   - Look for backtick-wrapped or quoted branch names near keywords: target, base, merge, branch, into

3. **Check if the issue references any PRs:**
   - Use GitHub's rendered HTML to extract PR references reliably (GitHub auto-links `#<number>` and tags PRs with `data-hovercard-type="pull_request"`):
     ```bash
     gh api -H "Accept: application/vnd.github.html+json" repos/<REPO>/issues/<NUMBER> \
       --jq '.body_html' \
       | grep -oE 'data-hovercard-type="pull_request"[^>]*href="[^"]*/(pull|issues)/([0-9]+)"' \
       | grep -oE '[0-9]+$' | sort -u
     ```
   - For each referenced PR number, fetch its base and head branches:
     ```bash
     gh pr view <PR_NUMBER> --repo <REPO> --json baseRefName,headRefName -q '{base: .baseRefName, head: .headRefName}'
     ```
   - Add both the PR base branch and PR head branch as candidates

4. **Choose the base branch:**
   - If only the default branch was found (no PR references, no branch mentions), use it without asking
   - If multiple candidates were found, present all discovered branches as options and ask me to pick one
   - List each candidate with context on where it was found (e.g. "default branch", "mentioned in issue body", "PR #123 base branch")

### 3. Set up the branch and worktree

1. Fetch latest from origin:
   ```bash
   git fetch origin
   ```

2. Generate branch name: `<issue-number>-<slugified-title>`
   - Slugify: lowercase, replace spaces/special chars with hyphens, collapse multiple hyphens, trim to reasonable length (max ~50 chars), strip trailing hyphens
   - Example: issue #42 "Fix Login Bug" → `42-fix-login-bug`

3. Check if a branch with this name already exists (local or remote):
   ```bash
   git rev-parse --verify <branch-name> 2>/dev/null
   git rev-parse --verify origin/<branch-name> 2>/dev/null
   ```
   - If it exists, ask me how to proceed: use the existing branch, choose a different name, or abort

4. Create the branch from `origin/<base-branch>`:
   ```bash
   git branch <branch-name> origin/<base-branch>
   ```

5. Enter the worktree using the `EnterWorktree` tool with the branch name

6. Inside the worktree, checkout the new branch:
   ```bash
   git checkout <branch-name>
   ```

### 4. Present issue summary

Display a clear summary:

- **Issue:** #\<number\> — \<title\>
- **State:** \<open/closed\>
- **Labels:** \<labels or "none"\>
- **Assignees:** \<assignees or "unassigned"\>
- **Base branch:** \<base-branch\>
- **New branch:** \<branch-name\>
- **Worktree path:** \<path\>
- **Body:** show the issue body (truncated if very long)

### 5. Name the session

Rename the current Claude Code session so it's easy to find later with `claude --resume`:

```
/rename issue-<number>-<short-slug>
```

For example: `/rename issue-42-fix-login-bug`

### 6. Wait for instructions

**STOP here.** Do NOT auto-start coding. Wait for me to tell you what to do with this issue.

## Important Notes

- Work through each step sequentially — do not skip ahead
- If `gh` CLI is not authenticated or the issue doesn't exist, explain the error clearly
- If the issue is from a different repo than the current one (URL-based), make sure to use the correct repo for `gh` commands
- The branch name should be deterministic from the issue — same issue always produces the same branch name
