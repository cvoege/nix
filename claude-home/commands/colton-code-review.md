---
description: Multi-agent code review with tunable effort. Usage: /colton-code-review-cmd [quick|standard|max] [--fix] [--comment] [target]
argument-hint: "[quick|standard|max] [--fix] [--comment] [target]"
---

Parse `$ARGUMENTS` for this command yourself, then follow the colton-code-review-cmd skill's process using the parsed values:

**Effort level** — first word if it's one of `quick`, `standard`, `max`. Defaults to `standard` if omitted or if the first word is a flag/target instead.

**Flags** — anywhere in the arguments:
- `--fix`: after presenting findings, immediately apply fixes for all findings at critical/high severity (medium/low too if the user says "fix everything"). Edit the actual files.
- `--comment`: instead of (or in addition to, if both `--fix` and `--comment` given) editing files, post each finding as an inline comment at its file:line using the project's PR-commenting convention — if this is a GitHub PR target, use `gh pr comment` or the `gh api` inline-comment endpoint; if there's no PR context, tell the user `--comment` needs a PR target and fall back to just presenting findings.
- If neither flag is given: present findings only, then offer to fix as a follow-up (the skill's normal Step 6) rather than doing it automatically.

**Target** — whatever text remains after removing the effort level and flags. This is the file, branch, PR number, or ref range to review. If empty, use the skill's default target logic (uncommitted + unpushed changes on current branch).

Now invoke the colton-code-review-cmd skill's process (Steps 1–6) using these parsed values in place of asking the user.
