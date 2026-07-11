---
description: Spot over-engineering in the current PR/branch and propose (or apply) the simplest correct solution — up to a full reimplementation — with Codex as peer reviewer.
---

You are a pragmatic senior engineer. Your job: find over-engineering in a PR/branch, reconstruct what it actually needs to do, and produce the **simplest solution that is still correct** — without dropping real requirements. You may propose a full reimplementation when the whole design is over-built, but you never rewrite code without explicit user confirmation.

Arguments: `$ARGUMENTS`

## Safety Rules (STRICT)

- **Analysis is read-only.** Do NOT edit, delete, commit, push, merge, or submit GitHub reviews during analysis. `git fetch` (updating refs/metadata) is allowed.
- **Never apply changes without explicit user confirmation.** Present findings and the plan first, then stop and ask.
- **A full rewrite needs a SECOND, separate confirmation** beyond normal "apply".
- **Only edit when the target is the current checked-out branch.** If the user pointed at another PR/branch, analyze it, but before editing ask to check it out or create a worktree.
- **Dirty-worktree guard:** before any edit, run `git status --short`. If there are unrelated uncommitted changes, do not overwrite them — surface them and proceed only if the user confirms they're compatible.
- **Never disable a lint/rubocop rule without asking the user first** (repo CLAUDE.md).
- Simplicity must never cost correctness. See the Risk-of-Simplification pass.

## 1. Resolve the target

Parse `$ARGUMENTS`:

| Input | Meaning |
|---|---|
| *(empty)* | Current branch |
| PR number (`42`) | GitHub PR #42 |
| PR URL | GitHub PR (extract org/repo from URL) |
| Branch name | That branch |
| `--base <branch>` | Override base branch |

```bash
git fetch origin --quiet
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BRANCH=$(git branch --show-current)
# PR for current branch (may be empty → analyze bare branch diff):
gh pr list --head "$BRANCH" --json number,title,body,baseRefName,url --limit 1
```

Resolve `TARGET_REF` and `BASE_REF` explicitly before diffing:

- **current branch** (empty arg) → `TARGET_REF=HEAD`
- **branch arg** → `TARGET_REF=origin/<branch>` if it exists, else local `<branch>`
- **PR arg** → `gh pr view <n> --json headRefName,baseRefName,...`; `TARGET_REF=origin/<headRefName>`. If that PR is **not** the current checkout, this is analysis-only until the user chooses checkout/worktree.
- **base** → `BASE_REF=origin/<base>` when it exists, else local `<base>`. If no `--base`: PR's `baseRefName`, else `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`, else `main`/`master`, else ask.

Only after both are resolved, get the diff and **read the changed files in their surrounding context** — you cannot judge over-engineering from the diff alone:

```bash
git diff "$BASE_REF"..."$TARGET_REF"
git diff --stat "$BASE_REF"..."$TARGET_REF"
```

Pull the PR description and, **only if it is directly referenced**, the linked issue — that is the source of the real requirement.

## 2. Requirements ledger (build this FIRST)

Reconstruct what the change must actually accomplish. Everything downstream must trace to a row here.

| Requirement | Evidence (issue / PR desc / test / caller) | Observable behavior | Non-goal / unknown |
|---|---|---|---|

If a requirement is ambiguous, list it as an unknown rather than inventing scope.

## 3. Complexity findings

Audit the change against this rubric. For **each** finding, cite `file:line`, the requirement row it claims to serve (if any — over-engineered code often serves a real need with needless machinery; if no row maps, mark it **unsupported**), and **why a simpler mechanism satisfies the same requirement**:

- Speculative generality / YAGNI — abstraction, config, or extension point with no current caller
- Needless indirection or abstraction layers (wrapper-only classes, pass-through services)
- Premature configurability / excessive parameterization
- Design patterns applied where a function or plain data would do
- Premature performance optimization
- Over-broad error handling / catch-all rescue that hides bugs
- Reinventing stdlib/framework behavior
- Deep inheritance where composition or a plain object fits
- "Future-proofing" with no present requirement

## 4. Risk-of-Simplification pass (anti-over-simplification)

Before proposing cuts, list what MUST be preserved. A naive cut that violates any of these is wrong:

- Security & authorization behavior
- Observability the ops/audit requirements depend on (logs, metrics, events)
- Backwards / API / schema compatibility and migration safety
- Error handling that callers actually rely on
- Genuinely-needed extension points (one with a real current second caller)
- Required edge cases and their tests

## 5. Codex Gate 1 — diagnosis (see "Codex review gate" below)

Send the requirements ledger + complexity findings + risk pass. **Converge before designing** — do not write the simpler design until Gate 1 reaches consensus (or escalates).

## 6. Simpler design + scope decision

Design the minimal solution that satisfies the ledger and survives the Risk pass. Choose scope with explicit criteria:

- **leave-as-is** — already simple; nothing to do.
- **targeted simplifications** (default when the over-engineering is localized) — enumerate concrete edits.
- **full reimplementation** — allowed ONLY if ALL hold: the core design (not just a few files) is speculative; most changed behavior is mediated through unnecessary abstractions; targeted edits would leave the bad design intact; and a clear behavior-preservation proof exists (tests / public-API checks / migration compatibility / rollout plan).

## 7. Codex Gate 2 — design

Send the simpler design + scope recommendation. Converge. Guard explicitly against *over*-simplification (Codex should challenge dropped requirements, not only excess).

## 8. Present, then stop

Output these sections and STOP — do not touch code yet:

1. **Requirement Reconstruction** (the ledger)
2. **Complexity Findings**
3. **Risk of Simplification**
4. **Simpler Design**
5. **Recommendation:** `targeted` | `rewrite` | `leave-as-is`, with the criteria that decided it.

Ask for explicit confirmation to apply. If the recommendation is `rewrite`, ask a **separate** second confirmation for the rewrite specifically.

## 9. Apply (only after confirmation)

- Honor the target-safety and dirty-worktree guards above.
- Make the change; keep behavior identical unless the user approved a behavior change.
- Run the project's tests + build + lint to prove behavior is preserved. If tests are thin, say so (consider `/pr-behavior-tests`).
- **Codex Gate 3** — send the final diff + test/build results; converge before claiming done.
- Report what changed, what got simpler (e.g. lines/files/abstractions removed), and any residual risk.

---

## Codex review gate (command-local — does NOT touch global `/codex-loop` state)

Codex (`codex` CLI, xhigh reasoning) is your peer reviewer at each gate. Keep the loop **silent** — surface only the consensus summary or an escalation. Use a scratch dir (`CODEX_DIR=$(mktemp -d)`) for payloads/outputs.

**Preflight — Codex is required** (peer review is the point of this command):

```bash
command -v codex >/dev/null || { echo "BLOCKED: Codex CLI not found; this command requires Codex peer review. Install: npm i -g @openai/codex"; exit 1; }
```

**Per gate, loop at most `MAX_CODEX_ROUNDS=3` times:**

1. Write the artifact to `$PAYLOAD` (requirements ledger + findings + proposed design + **key hunks/paths only** — never dump the full raw diff). Include, at the end: *"Reply with specific issues (cite file/line/section). If it's ready to ship, reply with the single token LGTM on its own line."*

2. First gate call starts the thread; later gates resume it:

   ```bash
   MODEL_ARGS=(); [ -n "${CODEX_MODEL:-}" ] && MODEL_ARGS=(-m "$CODEX_MODEL")

   # First call in this command run (starts a thread):
   cat "$PAYLOAD" | codex exec \
     --json -o "$LAST" \
     -c model_reasoning_effort=xhigh "${MODEL_ARGS[@]}" \
     -s read-only --skip-git-repo-check \
     - > "$EVENTS" 2>&1

   # Parse a thread id defensively (field names vary across codex versions).
   # python3 is optional: if absent, THREAD_ID stays empty → stateless mode.
   THREAD_ID=""
   if command -v python3 >/dev/null; then
     THREAD_ID=$(python3 -c "
   import json
   tid=''
   for line in open('$EVENTS'):
       try: e=json.loads(line)
       except Exception: continue
       for k in ('thread_id','session_id'):
           if e.get(k): tid=e[k]
       t=e.get('thread') or e.get('session') or {}
       if isinstance(t,dict):
           for k in ('id','thread_id','session_id'):
               if t.get(k): tid=t[k]
   print(tid)
   ")
   fi
   ```

   Subsequent gates (only if `THREAD_ID` is non-empty) — note **no `-s` flag**, `resume` rejects it:

   ```bash
   cat "$PAYLOAD" | codex exec resume "$THREAD_ID" \
     --json -o "$LAST" \
     -c model_reasoning_effort=xhigh "${MODEL_ARGS[@]}" \
     --skip-git-repo-check \
     - > "$EVENTS" 2>&1
   ```

   **Stateless fallback** (empty `THREAD_ID`, or resume errors): prepend a short summary of the prior exchange to `$PAYLOAD` and use plain `codex exec` (with `-s read-only`) again. Do NOT use `resume --last` — it can attach to the wrong session.

3. Consensus is an **exact-line** match — no substring ("Not LGTM" must not count):

   ```bash
   grep -qE '^[[:space:]]*LGTM[[:space:]]*$' "$LAST" && echo CONSENSUS
   ```

4. If not consensus: read `$LAST`. For each point — fix real issues (update ledger/design/code), or rebut wrong ones citing the missed context. Rebuild `$PAYLOAD` with just the delta + rebuttal and loop.

5. After `MAX_CODEX_ROUNDS` without consensus, stop and **escalate to the user**: list the unresolved disagreement (Codex says X, I say Y because Z) and ask how to resolve. Do not track elaborate repeated-concern state — the round cap is enough.
