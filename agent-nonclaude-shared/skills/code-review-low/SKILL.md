---
name: code-review-low
description: Fast, shallow, high-precision code review of a diff. One pass over the changed hunks, hunt runtime-correctness bugs only, at most 4 findings, no subagents. Use when asked to review a branch, PR, commit, or working-tree changes at low effort / quickly, or when no deeper review level is requested.
---

# Code review — low effort

**Contract:** one diff pass → hunk-local reasoning only → no subagents → **≤ 4 findings**.

Low effort means _shallow_, not _sloppy_. Two things are non-negotiable, and both were measured
failures in prior runs:

1. **100% of the diff gets read.** Never answer from a truncated page.
2. **Every reported line number is real.** Verify it (§4) — never report an offset into the patch.

Precision beats recall here. A wrong or unlocatable finding costs the reader more than a missed one.
If you are unsure, drop it.

**Budget:** ~4–8 tool calls total — one batched orientation call, one diff read (paged as needed),
≤ 1 line lookup per finding. No subagents, no full-file reads, no cross-file exploration, no web, no
writes, no edits.

---

## 1. Resolve the review target — one batched call

If the caller named a target (`<ref>`, `<base>..<head>`, a commit, a PR, "uncommitted"), use it and
skip to §2.

Otherwise run **one** command; it answers every question at once. A prior run burned a whole turn
discovering its first diff was empty:

```bash
{
  echo "== branch ==";   git rev-parse --abbrev-ref HEAD
  echo "== default ==";  git symbolic-ref -q --short refs/remotes/origin/HEAD || echo "(none)"
  echo "== log ==";      git log --oneline -5
  echo "== worktree =="; git diff HEAD --stat
  echo "== upstream =="; git diff @{upstream}...HEAD --stat
  echo "== tip ==";      git diff HEAD~1 --stat
} 2>&1
```

Pick the base by this precedence — the **first** that is non-empty:

| #   | Base                                         | When                                                                       |
| --- | -------------------------------------------- | -------------------------------------------------------------------------- |
| 1   | the caller's argument                        | always wins                                                                |
| 2   | `@{upstream}...HEAD` plus uncommitted `HEAD` | normal feature branch; review both, they compose                           |
| 3   | `<default-branch>...HEAD`                    | no upstream configured                                                     |
| 4   | `HEAD~1`                                     | branch already merged / no unique commits — the tip commit _is_ the change |

The default branch is whatever `origin/HEAD` says (`trunk`, `main`, `master`, …). **Never hardcode
`main`.** If you land on base 4, say so in the Scope line — you are reviewing one commit, not a
branch.

---

## 2. Read the diff — completely

```bash
git diff --no-ext-diff -M -U3 <base> -- . \
  ':(exclude)*/test/*' ':(exclude)*/tests/*' ':(exclude)*/spec/*' \
  ':(exclude)*/__tests__/*' ':(exclude)*.test.*' ':(exclude)*_test.*' \
  ':(exclude)*.spec.*' ':(exclude)*/fixtures/*' ':(exclude)*/testdata/*'
```

`-U3` and `-M` keep the payload small; `--no-ext-diff` stops a configured difftool from hijacking
the output. Test and fixture hunks are out of scope at this level.

Two git gotchas, both verified: `-U3` overrides `--stat`, so drop `-U3` when you want the file list;
and any option placed _after_ the `--`/pathspecs is parsed as a pathspec and silently ignored.

### Coverage discipline

The diff is often too big for one tool result. Whatever the harness does with it, **read to the
end**:

- **Truncation notice / partial page** → keep paging (`offset` / `limit`) to the last line. In the
  reference run, finding #2 lived in the final 24% of the patch; stopping at page 1 would have lost
  it.
- **No offset-capable reader** → write it out and page with the shell:
  ```bash
  git diff ... > /tmp/review.patch; wc -l /tmp/review.patch
  sed -n '1,800p' /tmp/review.patch      # then 801,1600p, …
  ```
- **Very large diff (> ~3000 lines)** → page per file instead: get the list with
  `git diff --stat <base> -- . <exclusions>`, then `git diff <base> -- <path>` per file, largest
  first. Same rule — every file gets one pass.
- **Skimmable but still counted:** binary blobs, lockfiles, generated/minified output, vendored
  trees. Name them in Scope. A hunk you did not reason about is a hunk you disclose.

### Scope honesty

Use **exactly** the exclusions above. Adding your own is acceptable only if the Scope line names it
— a prior run silently dropped a 391-line `docs/` file, 23% of the change's insertions. Docs and
markdown stay in scope: prose yields no findings, but embedded scripts and commands do.

---

## 3. Hunt — runtime correctness, from the hunk alone

Walk each hunk once. For every `+` line ask: _what input makes this behave wrong?_

**Flag these:**

| Class                           | What it looks like                                                                                            |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Inverted / wrong condition      | `!` added or dropped, `&&`/`\|\|` swapped, comparison reversed                                                |
| Off-by-one                      | `<` vs `<=`, `length` vs `length - 1`, slice/index bounds                                                     |
| Null / undefined deref          | field accessed where adjacent lines show it can be absent                                                     |
| Removed or missing guard        | a validation the surrounding block performs for its siblings but not this value                               |
| Falsy-zero / empty-string check | `if (x)` where `0`, `""`, or `false` is a legitimate value                                                    |
| Missing `await`                 | promise used as a value, unhandled rejection, fire-and-forget write                                           |
| Wrong-variable copy-paste       | near-duplicate block still referencing the source block's variable                                            |
| Swallowed error                 | `catch` that logs or returns a default where the caller must know it failed                                   |
| Unvalidated external input      | env var / arg / response field coerced (`Number()`, `JSON.parse`) with no check, poisoning a later comparison |
| Duplicated helper               | new code reimplementing a helper **visible in the diff context**                                              |
| Dead code                       | unreachable branch, no-op condition, leftover the change stranded                                             |

**Do not flag:** style, naming, formatting, performance, missing tests, architecture, "consider
extracting", TODOs, anything requiring a file you have not read, anything requiring a caller you
have not seen. Silence on those is correct behavior, not laziness.

### Precision gate — a finding ships only if all four hold

1. **Anchored.** You can quote the offending text verbatim from a `+` line (or from a context line
   whose meaning this hunk changed).
2. **Concrete.** You can state _input/state → wrong output_ in one sentence. "Could be fragile" is
   not a finding.
3. **Unrefuted.** Nothing in the same hunk already handles it — check for the guard three lines up,
   the default parameter, the early return.
4. **In scope.** It is one of the classes above and does not depend on unseen code.

Fail any one → drop it. Two verified findings beat six guesses.

---

## 4. Line numbers — verify, never estimate

**The single largest defect in the reference run: 0 of 2 line numbers were correct** — it reported
`reap-plan.mjs:1204` for a 157-line file, because it cited its offset into the patch text.

**Step A — derive from the hunk header.** For `@@ -12,7 +28,15 @@`, the new file side starts at
line **28**. Walking down the hunk body, ` ` (context) and `+` lines each consume one new-file line;
`-` lines consume none. So:

```
target line = <new-side start> + (count of ' ' and '+' body lines strictly before your line)
```

**Step B — confirm it.** One cheap, line-scoped lookup per finding. This is not a full-file read; it
returns a line or two:

```bash
grep -n 'exact snippet' path/to/file.ext
# head not checked out (reviewing A..B where B isn't HEAD):
git grep -n 'exact snippet' <head-ref> -- path/to/file.ext
```

Reconcile:

- one hit → use it.
- several hits → the one nearest your Step-A number.
- **zero hits** → the text you were about to quote does not exist. Re-quote from the diff, or drop
  the finding. A finding you cannot locate is a finding you cannot ship.
- Sanity-check against `wc -l` whenever a number looks large for the file.

Cite a range when the defect spans lines: `path/to/file.ext:28-29`.

---

## 5. Rank

Most severe first:

1. Silent wrong behavior, data loss, or a security hole on a path that runs in production
2. Crash / hard failure
3. Wrong behavior only under misconfiguration, rare input, or a plausible future edit
4. Dead or redundant logic with no behavioral effect today

Ties break on blast radius. **Consistency check before writing:** a finding your own explanation
calls cosmetic cannot outrank one you described as a real failure mode. The reference run got this
backwards — it led with a no-op `always()` above a bug that silently disabled a nightly cleanup job.

Keep the top 4. If you cut anything, say so on the Scope line.

---

## 6. Output

Prose. Short. No preamble, no re-listing of the diff, no praise, no summary of what the change does.

```
Scope: <base> — <n> files, tests excluded[, other exclusions][, top 4 of N findings].

- path/to/file.ext:123 — what's wrong and the concrete failure it causes.
- path/to/file.ext:45-46 — what's wrong and the concrete failure it causes.

Nothing else in the hunks qualifies as a runtime-correctness bug.
```

Rules:

- One line per finding, with defect **and** consequence in the same sentence.
- Nothing qualifies → output exactly `(none)` after the Scope line.
- Close with the explicit negative, scoped to _this level_: "nothing else in the hunks qualifies",
  never "the change is clean". You read hunks, not the system.
- A one-clause fix suggestion inline is welcome. Do not apply fixes unless asked.
- Do **not** call `ReportFindings` or any structured-findings tool at this level. If the harness
  demands structured output, map the same fields (file, line, summary, failure scenario) and keep
  the cap of 4.

---

## Worked example

From the reference run — a new 157-line file, so one hunk headed `@@ -0,0 +1,157 @@`. Body lines
28–29 (elision shown):

```diff
@@ -0,0 +1,157 @@
+#!/usr/bin/env node
...
+const closedGraceDays = Number(process.env.CLOSED_GRACE_DAYS);
+const idleDays = Number(process.env.IDLE_DAYS);
+
+if (!owner || !repo || !token) {
+  console.error('REPO (owner/name) and GH_TOKEN must be set');
+  process.exit(2);
+}
```

- **Class:** unvalidated external input / missing guard — the guard just below validates three
  values and skips these two.
- **Gate:** anchored (quoted `+` lines) · concrete (unset env → `NaN` → every `x >= NaN` is false →
  reaper deletes nothing, exits 0 green, forever) · unrefuted (no check anywhere in the hunk) · in
  scope.
- **Line, Step A:** new side starts at 1; 27 body lines precede it → 28.
- **Line, Step B:** `grep -n 'CLOSED_GRACE_DAYS' scripts/preview/reap-plan.mjs` → `28`. Confirmed.
  Do this even when Step A feels certain — the reference run skipped it and said `1204`.
- **Rank:** tier 1 — silent wrong behavior in a scheduled production job.

```
- scripts/preview/reap-plan.mjs:28-29 — CLOSED_GRACE_DAYS/IDLE_DAYS go through Number() with no validation; one typo in the workflow env makes both NaN, every comparison false, and the nightly reaper silently deletes nothing forever while still exiting green. Fold Number.isFinite checks into the guard below.
```

---

## Failure modes to avoid (all observed)

| Failure                                                    | Guard                                             |
| ---------------------------------------------------------- | ------------------------------------------------- |
| Reporting patch offsets as file lines                      | §4 Step B — grep every finding                    |
| Stopping at a truncated first page                         | §2 — page to the last line                        |
| `git diff main...HEAD` where the default branch is `trunk` | §1 — read `origin/HEAD`                           |
| Empty diff → giving up, or reviewing nothing               | §1 base 4 — fall back to `HEAD~1`                 |
| Silently narrowing scope                                   | §2 — exclusions are fixed; disclose any deviation |
| Cosmetic finding ranked first                              | §5 — consistency check                            |
| Padding to the cap with style nits                         | §3 — forbidden classes plus the precision gate    |
| Serial one-fact-per-call tool use                          | §1 — one batched orientation call                 |
