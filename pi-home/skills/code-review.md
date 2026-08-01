---
name: code-review
description: Review the current branch's changes for bugs before they ship. Use when asked to code review, review my changes, or review this branch or PR.
---

# Code Review

One pass, in this context, no subagents. Phases in order. Hunt for defects — do
not summarize the change and do not fix anything unless asked.

## Phase 0 — Scope

```bash
git stack diff --dirty --stat
```

Read the stat before the diff, then pick a mode:

- **Under ~400 changed lines** — pull the whole diff and keep it in context.
- **Larger** — go one file at a time (`… -- <path>`), biggest first. Append each
  file's findings to `/tmp/review.md` as you finish it, then drop that file's
  diff from mind. Phase 2 reads `/tmp/review.md`, not the diff.

Skip test and fixture hunks unless the change is *to* the tests.

## Phase 1 — Find

Run the angles below over the diff you already have. Do not re-run the diff
command per angle. Two angles flagging the same line for different reasons is
fine — record both, dedup comes later.

Each candidate needs: `file:line`, a one-line summary, and the concrete failure
(inputs or state → wrong output or crash).

**A. Line by line.** Every hunk, every line. `read` the enclosing function for
each hunk — a bug on an *unchanged* line of a touched function is in scope. Per
line ask what input, state, timing, or platform makes it wrong. Inverted
condition, off-by-one, null deref, missing `await`, falsy-zero check,
wrong-variable copy-paste, error swallowed in a catch, unescaped regex chars.

**B. Removed behavior.** For each deleted or replaced line, name the invariant
it enforced, then find where the new code re-establishes it. If it doesn't,
that's a finding: dropped guard, narrowed validation, deleted error path.

**C. Callers.** `grep -rn` each changed function's name. Does the change break a
call site — new precondition, changed return shape, new exception, new ordering
requirement?

**D. Language pitfalls.** The classics for this language. JS: falsy-zero, `==`
coercion, closure-captured loop var. Python: mutable default args, late-binding
closures. Go: nil-map write, range-var capture. Bash: unquoted expansion, `set
-e` not applying inside `$(…)`, `local x=$(…)` swallowing the exit status.
Anywhere: SQL injection, float equality, timezone drift.

**E. Cleanup.** New code re-implementing a helper the repo already has (grep the
shared/utility modules before claiming it); redundant or derivable state; dead
code left behind; a special case bolted onto shared infrastructure where
generalizing the mechanism was the real fix.

**F. Conventions.** Read the AGENTS.md / CLAUDE.md files governing the changed
files — repo root, plus any in an ancestor directory of a changed file. Flag a
violation only when you can quote both the rule and the line breaking it.

## Phase 2 — Verify

Dedup first: same defect, same location, same reason → keep the one with the
most concrete failure scenario. Then grade each survivor against the code:

- **confirmed** — you can name the inputs that trigger it and the wrong result.
  Quote the line.
- **plausible** — mechanism is real, trigger is uncertain (timing, env, config).
  Say what would confirm it.
- **refuted** — drop it. Only refute when the code proves you wrong: the line
  doesn't say that, a type or constant makes it impossible, the diff already
  guards it, or it's style with no observable effect.

"Depends on runtime state" is not grounds to refute when the state is realistic
— races, nil on an error path, falsy-zero, off-by-one at a boundary the code
never excludes. Those stay plausible.

## Output

Up to 8 findings, most severe first. Correctness outranks cleanup and
conventions whenever the cap forces a cut.

```
1. `path/to/file.ext:123` — one-line statement of the defect. [confirmed]
   Fails when: concrete inputs or state → wrong output or crash
```

If nothing survives, say so in one line. Don't pad the list to look thorough.
