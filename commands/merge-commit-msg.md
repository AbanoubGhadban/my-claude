You are composing a MERGE COMMIT MESSAGE for Git and saving it to a
unique file. You are running inside Claude Code with a terminal. Follow
ALL rules.

OBJECTIVE
- Produce a high-quality MERGE COMMIT MESSAGE focused on WHY and the
  overall WHAT.
- Then save it to /tmp/commit-msg-NUM.txt where NUM increments to avoid
  conflicts.

AUTO-GATHER CONTEXT (do this first via terminal + repo inspection)
1) Determine PR number:
   - Prefer patterns in branch name (e.g., feature/123-..., fix/123, hotfix/123)
     or commit messages referencing "(#123)".
   - If still unknown, look for open PRs targeting this branch if possible.
2) Read recent commits and diffs for this branch vs its merge base to
   infer motivation, scope, and themes.
3) Identify breaking changes: API/CLI changes, schema migrations,
   removed/deprecated code or flags.
4) Identify security changes: auth/perm shifts, exposure changes, dep
   risk updates, policy files.
5) Infer impact to existing vs new installs: config changes, migrations,
   flags, env vars, defaults.

QUESTION POLICY
- Ask up to 3 short questions ONLY if critical details are missing
  (e.g., PR number cannot be determined; material motivation unclear).
- Otherwise, proceed without questions.

STYLE RULES (STRICT)
- Plain text only. NO markdown, NO code fences, NO italics/bold.
- First line (title): imperative mood, <= 72 chars, format:
  "Brief description (#PR_NUMBER)".
- Wrap body to ~72 chars per line.
- Use hyphen bullets (-) when listing.
- Present tense for codebase behavior; past tense for the change made.
- Do not restate diffs; capture themes and intent.

MESSAGE STRUCTURE (omit a section only if truly irrelevant)
<Title: Brief description (#PR_NUMBER)>

Why
- One or two lines explaining the motivation/problem.

Summary
- One to three lines summarizing the PR across all commits.

Key improvements
- Bullet 1
- Bullet 2

Breaking changes
- "None" OR bullets and brief migration notes.

Security
- "None" OR bullets with implications.

Impact
- Existing installs: ...
- New installs: ...

Upgrade/rollback notes
- Brief steps or considerations, if any.

References
- PR #<number> and any related issue/incident IDs.

OUTPUT REQUIREMENTS
- Return ONLY the final commit message body in the exact shape above.
- No preamble, no epilogue, no markdown, no fences.

SAVE FILE (after you generate the message)
- Use the terminal to create a unique path:
  num=1; while [ -e "/tmp/commit-msg-$num.txt" ]; do num=$((num+1)); done
  printf "%s\n" "<PASTE-COMMIT-MESSAGE-CONTENT>" > "/tmp/commit-msg-$num.txt"
  echo "/tmp/commit-msg-$num.txt"
- If terminal access is unavailable, just return the commit message and
  the suggested file path in the last line as:
  /tmp/commit-msg-NOT-SAVED.txt
