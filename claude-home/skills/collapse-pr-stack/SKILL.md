---
name: collapse-pr-stack
description: Collapse a git branch stack, or a range of it, into a single PR. Use when asked to collapse a stack of pull requests into a single one, or to squash a few adjacent PRs in a stack together.
---

# Collapse a stack of git branches to a single PR

**Requires**: `gh` authenticated, and the stack's parent pointers recorded (via
`git stack new` / `git stack parent`). The `git stack` utilities
must be on PATH.

If any command in this series errors, or requires user intervention, pass control back to the user.

## Scope: whole stack or a range

`git stack collapse` takes an optional range, so this skill does too:

- **No range given** — collapse the entire current stack into its root branch
  (the one whose parent is trunk). This is the default when the user just says
  "collapse the stack".
- **`<start>`** — fold everything above `<start>` into `<start>`; branches below
  it are untouched.
- **`<start> <end>`** — fold only `<start>..<end>` into `<start>`. Branches above
  `<end>` survive and reparent onto `<start>`, so the stack keeps going.

Work out which case you're in from the user's request before running anything —
"collapse the top two PRs", "squash ACT-322 and ACT-323 together", or a pair of
branch names all mean a range. If the request is ambiguous about where the range
starts or ends, ask rather than guessing: collapsing the wrong branches rewrites
PRs the user didn't intend to touch.

Throughout the steps below, `<range>` means the range args you settled on (empty
for a whole-stack collapse).

## Process

1. Run this command to get an overview of the current stack and all the PRs attached:

  ```bash
  git stack prs list
  ```

  Take special note of every linear ticket (e.g. ACT-323) of every PR **in the
  range being collapsed** — for a whole-stack collapse that's every PR in the
  stack. In the end, when we create the final PR, we will want to include each
  one in both the title and the description. Tickets from branches outside the
  range keep their own PRs and must not be pulled into the collapsed one.

2. Run the following command to ensure the entire stack is up to date and ready to be fast forwarded. If this command errors, stop and tell the user.

  ```bash
  git stack restack
  ```

3. Confirm the collapse does what you expect before mutating anything — this
  prints the branches that will be folded together and what happens to the ones
  above them, without touching the repo:

  ```bash
  git stack collapse --dry-run <range>
  ```

  Check the printed plan against the range the user asked for. If it doesn't
  match, stop and tell the user rather than adjusting the range yourself.

4. Run the following to collapse. It merges all the changes into `<start>` (the
  branch in the range closest to the main/trunk branch), pushes it, and deletes
  the folded-in branches, reparenting anything above the range onto `<start>`.
  If this command errors, stop and tell the user.

  ```bash
  git stack collapse <range>
  ```

5. We should now be on the collapsed branch. It should already have a PR on Github, but we need to update that PR now that it has all the changes. Run the create-pr-stack skill to create a PR, or update the existing PR with all the new changes. Make sure the description and title are updated to encompass the full changeset — every linear ticket from step 1 in both the title and the description. Remove the draft status from the PR.

6. **Only when branches survived above the range.** The collapse reparented them
  onto the collapsed branch locally, but their PRs on GitHub still point at a
  branch that no longer exists in the stack. Re-run `git stack prs list` to see
  the new shape, then retarget the PR of each direct child of the collapsed
  branch:

  ```bash
  gh pr edit <child-branch> --base <collapsed-branch>
  ```

  Then re-check `git stack prs list` and confirm every remaining PR's base
  matches its recorded stack parent.
