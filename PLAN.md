# Claude Code Productivity Plan

A plan for commands, hooks, and strategies to implement for my Claude Code setup.

---

## Commands to Implement

### 1. `/await-edits` — Collaborative Editing Cycle

**Priority:** High
**Status:** Design finalized

**Purpose:** Let the user manually edit files Claude wrote, then have Claude detect and address those changes — without touching git state.

**Flow:**
1. Claude edits files during normal conversation
2. User runs `/await-edits` — Claude snapshots all files it edited to `.claude/snapshots/`
3. User makes manual changes in their editor (rewrite sections, change values, add TODOs, delete code)
4. User comes back and says "done" (or "check my edits", "I'm done", etc.)
5. Claude diffs snapshots vs current files, shows exactly what the user changed, and addresses them

**Design decisions:**
- **No hooks required** — just a slash command. Claude knows which files it edited from conversation context
- **No git impact** — snapshots are plain file copies in a temp directory (`.claude/snapshots/`)
- **User controls timing** — snapshot happens when the user says, not automatically
- **No annotation syntax** — user edits text directly (change "optional" to "required", rewrite sentences, delete sections). Claude detects changes via file diff, not by scanning for special markers
- **Single invocation** — user runs the command once, edits, then tells Claude they're done. No need to run the command twice

**Snapshot strategy:**
- Store snapshots in `.claude/snapshots/<relative-path>` (mirroring project structure)
- Use `git diff --no-index` or plain `diff` to compare snapshot vs current file
- Clean up snapshots after Claude has processed the diffs
- If conversation gets compacted and Claude forgets which files it edited, the snapshot directory itself still has the files to diff against

**Edge cases to handle:**
- User deletes a file Claude wrote → snapshot exists but current file is gone → report deletion
- User creates a new file → no snapshot exists → report as new file
- User edits a file Claude didn't touch → no snapshot → ignore or report
- Binary files → report as changed but skip diff display
- Multiple `/await-edits` rounds in one session → clean up previous snapshots before creating new ones

---

### 2. `/investigate` — Deep Parallel Research

**Priority:** High
**Status:** Concept only

**Purpose:** Automates the "ultra deep search and think" pattern the user frequently uses. Launches parallel subagents to research a question from multiple angles, protecting the main context window from excessive search results.

**Intended behavior:**
- Parse the user's question/topic
- Launch 3-5 parallel Explore subagents, each searching from a different angle (code search, git history, documentation, related files, test coverage)
- Collect and synthesize findings into a concise summary
- Present findings with file references and line numbers
- Optionally write findings to a `research.md` file

**Why needed:** The user frequently types "ultra deep search and think" as a prompt prefix. This command formalizes that pattern with parallel execution and context protection.

---

### 3. `/catchup` — Session Recovery

**Priority:** High
**Status:** Concept only

**Purpose:** Instant context recovery after `/clear` or starting a new session. Reads all changed files on the current branch to rebuild understanding.

**Intended behavior:**
- Detect the base branch (main/master)
- Run `git diff --name-only <base>...HEAD` to find all changed files
- Read each changed file and the diff
- Read PR description if a PR exists
- Read any TODO.md, PLAN.md, or HANDOFF.md in the project
- Summarize: what branch this is, what it's doing, what's done, what's left

**Inspiration:** Shrivu Shankar's `/catchup` command from the community.

---

### 4. `/handoff` — Session Summary for Continuity

**Priority:** High
**Status:** Concept only

**Purpose:** Auto-generates a session summary (like HANDOFF.md) capturing decisions, progress, and next steps for cross-session continuity.

**Intended behavior:**
- Summarize what was discussed and decided in this session
- List files created/modified with brief descriptions
- Capture design decisions and their reasoning
- List explicit next steps (not started)
- Write to `HANDOFF.md` in the project root
- Optionally save key points to Claude's memory system

**Why needed:** The user already uses HANDOFF.md manually. This automates the pattern.

---

### 5. `/next` — Task Continuity with TODO.md

**Priority:** Medium
**Status:** Concept only

**Purpose:** Reads TODO.md, finds the first unchecked task, and starts working on it. Enables task continuity across sessions.

**Intended behavior:**
- Read `TODO.md` from project root
- Find the first `- [ ]` item
- Mark it as `- [x]` in progress
- Start working on it
- If no TODO.md exists, ask the user what to work on and create one

**Inspiration:** Eddie Ajau's `/next` + TODO.md system.

---

### 6. `/pr-ready` — Pre-PR Checklist

**Priority:** Medium
**Status:** Concept only

**Purpose:** Runs a comprehensive pre-PR checklist before opening a pull request.

**Intended behavior:**
- Run linters (rubocop for Ruby, eslint for JS/TS)
- Check for debug artifacts: `binding.pry`, `console.log`, `debugger`, `byebug`, `puts` used for debugging
- Check for focused/skipped tests: `fit`, `fdescribe`, `xit`, `xdescribe`, `.only`
- Check for TODO/FIXME/HACK comments in changed files
- Check for large files or accidental binary commits
- Check for .env files or secrets in the diff
- Run the test suite
- Report pass/fail with actionable items

---

### 7. `/daily-standup` — Auto-generate Standup Notes

**Priority:** Medium
**Status:** Concept only

**Purpose:** Generates standup notes from git history across all branches/worktrees.

**Intended behavior:**
- Run `git log --all --author=<user> --since="yesterday"` across all worktrees
- Group by branch/issue
- Format as: what was done, what's in progress, blockers
- Output in a copy-pasteable format

**Inspiration:** wshobson's `/standup-notes` command.

---

### 8. `/debug-async` — Async/Threading Issue Investigator

**Priority:** Low
**Status:** Concept only

**Purpose:** Specialized investigator for async, threading, and race condition issues. Traces execution flow across async boundaries.

---

### 9. `/context-snapshot` — Save/Restore Session State

**Priority:** Low
**Status:** Concept only

**Purpose:** Save current session context to Claude's memory system for restoration in a future session. More structured than `/handoff`.

---

### 10. `/sync-worktrees` — Worktree Status Dashboard

**Priority:** Low
**Status:** Concept only

**Purpose:** Show status of all active worktrees — which branches, clean/dirty, ahead/behind, linked issues.

---

## Hooks to Set Up

### 1. Desktop Notifications (Notification hook)

**Priority:** High

**Purpose:** Get a `notify-send` desktop notification when Claude needs attention (finished a long task, asking a question, hit an error).

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.message // \"Claude needs your attention\"' | xargs -I{} notify-send 'Claude Code' '{}'"
          }
        ]
      }
    ]
  }
}
```

---

### 2. Post-Compact Context Re-injection

**Priority:** High

**Purpose:** After conversation compaction, automatically re-inject critical context (current task, branch name, key decisions) so Claude doesn't lose its bearings.

Would use a `PostCompact` or `SessionStart` hook with a `"compact"` matcher to read a context file and inject it.

---

### 3. Block Edits to Protected Files (PreToolUse)

**Priority:** Medium

**Purpose:** Prevent Claude from editing sensitive files like `.env`, credentials, lock files.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // empty' | grep -qE '\\.(env|pem|key)$|secrets|credentials|\\.lock$' && echo '{\"decision\": \"block\", \"reason\": \"Protected file — cannot edit\"}' || exit 0"
          }
        ]
      }
    ]
  }
}
```

---

### 4. Auto-format After Edits (PostToolUse)

**Priority:** Medium

**Purpose:** Run rubocop/prettier on files Claude edits to maintain consistent formatting.

---

## Strategies to Adopt

### 1. Annotation Cycle (Boris Tane)

Use for complex features. The cycle:
1. Research — "Read this folder in depth, write findings in research.md"
2. Plan — "Write detailed plan.md. Don't implement yet."
3. Review iterations — Open plan.md, make edits, tell Claude to address them (this is where `/await-edits` fits)
4. Todo — "Add detailed todo list with all phases"
5. Implement — "Implement it all. Mark completed in plan."

### 2. Document & Clear

Before running `/clear`, dump progress to HANDOFF.md (automate with `/handoff` command).

### 3. Named Sessions

Use `/rename` on every session for easy `/resume` later.

### 4. Subagents for Investigation

Use parallel subagents to protect main context during deep searches (formalize with `/investigate` command).

### 5. Plan Mode (Shift+Tab)

Use for all non-trivial work before implementation.

### 6. Writer/Reviewer Pattern

For important features, use two parallel sessions — one writes code, the other reviews.

---

## Implementation Order

1. **`/await-edits`** — Design is finalized, implement first
2. **Desktop notifications hook** — Quick win, high value
3. **Protected files hook** — Quick win, prevents accidents
4. **`/investigate`** — Formalizes a frequent pattern
5. **`/catchup`** — Session recovery
6. **`/handoff`** — Session persistence
7. **`/pr-ready`** — Pre-PR safety net
8. Everything else as needed
