---
description: "Multi-angle code review at a tunable effort level. Usage: /colton-code-review [low|medium|high|xhigh|max|ultra] [--fix] [--comment] [target]"
argument-hint: "[low|medium|high|xhigh|max|ultra] [--fix] [--comment] [<target>]"
---

Parse `$ARGUMENTS` yourself, then run the **max-code-review** skill with the
parsed values. Do not ask the user to confirm any of this — the arguments are
the answer.

**Effort level** — the first token, if it is one of `low`, `medium`, `high`,
`xhigh`, `max`, `ultra`. Accept unambiguous prefixes (`lo`, `med`, `hi`, `xh`,
`ma`, `ul`). If the first token is a flag or a target instead, the level
defaults to `high`. If the first token looks like a level but isn't one, say
`(Ignoring unrecognized effort "<token>"; valid: low, medium, high, xhigh, max,
ultra. Using high.)` and continue.

`ultra` maps to the skill's local ultra tier. Mention once, in one line, that
the genuine cloud version is `/code-review ultra` — user-triggered and billed,
so you can't launch it — and then get on with the local review.

**Flags** — anywhere in the arguments, stripped before target parsing:

- `--fix` — after producing the findings list, apply them to the working tree.
  Follow the skill's `--fix` section: fix correctness bugs and cleanups alike;
  skip anything that would change intended behavior, reach well outside the
  reviewed diff, or that you judge a false positive, and note the skip rather
  than arguing with it.
- `--comment` — after producing the findings list, post each finding as an
  inline PR comment. Follow the skill's `--comment` section.

Both may be passed together. If neither is passed, stop at the report and offer
to fix as a follow-up — don't edit files.

**Target** — everything left after removing the level and the flags. A PR
number, branch, ref range, path, or free-form scope instruction ("only
`src/foo.ts`", "focus on error handling", "skip the test files"). Pass it
through **verbatim** to the skill; it rides along to every finder, verifier and
sweep agent as scope guidance.

If the target is empty, use the skill's Phase 0 default: the current branch
diff, including uncommitted changes. In a `git stack` repo, prefer the stack
parent over `@{upstream}`.

Now run the max-code-review skill end to end with those values.
