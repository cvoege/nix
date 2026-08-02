---
name: code-review-low
description: Experimental. Use only when specifically called.
---

# Code Review — low effort

`1 diff pass → no verify → ≤4 findings`

A cheap smoke check, not an audit. Hunt for defects; do not summarize the change
and do not fix anything unless asked.

Budget, non-negotiable at this level:

- **One read of the diff.** No `--stat` warm-up call — it costs a round trip and
  tells you nothing the diff won't.
- **No full-file reads**, no `grep` for callers, no repo exploration.
- **No subagents, no delegation.** Do the whole review in this context.
- **No verification pass.** Your first judgment is the output.

## Step 1 — read the diff

One command. Pick the first form that fits:

1. A target was passed as an argument (a branch, a ref range, a PR) → diff that agaiinst that
   ```

Resolve the trunk name from the repo using `git stack trunk` if needed.

Skip test and fixture hunks — `test/`, `spec/`, `__tests__/`, `*_test.*`,
`*.test.*`, `fixtures/`, `testdata/`. Test changes are not reviewed at this
level.

If the diff is too large to hold (very roughly >1500 lines), review the largest
non-test files first and **say in the output which files you did not read**. A
silently truncated review reads as a clean one.

## Step 2 — findings

Flag runtime-correctness bugs visible **from the hunk alone**:

- inverted or wrong condition, off-by-one
- null/undefined deref where adjacent lines show the value can be absent
- a guard, validation, or error path the diff removed and never re-established
- falsy-zero / empty-string check
- missing `await` (or unhandled promise, unchecked error return)
- wrong-variable copy-paste
- error swallowed in a `catch` that should propagate
- a type assertion or cast that launders a value the same hunk shows can be
  `null`/absent

Also in scope, still from the hunk alone: new code duplicating a helper that is
visible in the diff context, and dead code the diff leaves behind.

**Do not flag** style, naming, performance, missing tests, or anything you'd
have to open another file to judge.

Line numbers come from the hunk header: `@@ -a,b +c,d @@` means the first line
of that hunk is line `c` in the new file — count forward from there, don't
eyeball it. (Off-by-a-few line numbers are the characteristic failure of this
effort level; you are not allowed to open the file to check.)

## Output

Plain text. Do not call a findings-reporting tool even if one exists.

At most **4 findings**, most severe first, one line each:

```
path/to/file.ext:123 — what's wrong and the concrete failure
```

The failure half is required: name the inputs or state that trigger it and the
wrong result, not just the smell.

If nothing qualifies, output exactly:

```
(none)
```

You may then add up to **2 lower-confidence notes**, under a literal
`Notes (lower confidence):` heading, in the same one-line format. Use this slot
for things you'd want a human to glance at but can't stand behind from the hunk
alone — that is what it is for, so don't smuggle them into the findings list and
don't break format to mention them. Attach the qualification to the note itself
("matches the behavior of the code it replaces", "fine if the wiring is
intentionally staged").

Don't pad either list, and don't close with a verdict on the change as a whole —
this pass read one diff, skipped the tests, never opened a file, and verified
nothing. Absence of findings here means only that.
