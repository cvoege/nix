---
name: breakout-pr-stack
description: Break out a single git branch into many PRs. Use when asked to split the work in one pull request into a stack of many.
---

# Break out a single git branch into a stack of PRs

Take one branch that holds a pile of work and split it into a stack of small,
stacked branches — one per coherent change — then open a PR for each.

**Requires**: `gh` authenticated, and the stack's parent pointers recorded (via
`git stack new` / `git stack parent`). The `git stack` utilities
must be on PATH.

## What makes a good split

Each PR should be **atomic, reviewable, and self-contained** — one complete idea
that lands on its own. Split by *coherent changes, not the order you happened to
write the code*. A stack should read the way you'd want someone to review the
work: foundations first (the refactor or helper everything else builds on), then
the features that depend on them, top to bottom.

Two hard constraints follow from how stacks work:

- **Each branch builds on its parent.** A change must be placed *after* anything
  it depends on, so every branch applies cleanly on top of the one below it.
- **No forward dependencies.** An earlier PR must never need code that only
  appears in a later one. Ideally each branch builds/compiles in sequence.

## How the stack is built

`git stack new <name>` just runs `git checkout -b <name>` from the current tip
and records the parent pointer — it does **not** move any commits. So you build
the stack from the **trunk upward**: branch off trunk, apply the first coherent
subset of the work and commit it; branch off *that* and apply the next subset;
and so on. The original branch is never modified — it stays intact as both a
recovery point and the baseline you verify against at the end.

## Process

### Step 0: Preconditions

```bash
git status --porcelain         # must be empty; if not, stop and have the user
                               # commit (use the /commit skill) or stash first
git branch --show-current      # the branch holding all the work — remember it
git rev-parse HEAD             # record this SHA; it's your recovery point
git stack trunk                # the trunk this work branches off of
```

Check if a stack already exists with `git stack list`. If there is and this branch 
PR is anywhere but the end of a stack, error out to the user.

The work to split must be **committed** on the current branch. Confirm there is
actually a stack of distinct changes to make — if `git diff <trunk>...HEAD` is
trivial, say so rather than manufacturing tiny PRs.

### Step 1: Understand the work

Read the full diff and history of the branch against trunk so the split reflects
what the work *is*, not the commit order:

```bash
git diff <trunk>...HEAD --stat
git diff <trunk>...HEAD
git log <trunk>..HEAD --oneline
```

### Step 2: Propose a split plan, then STOP for approval

Present a numbered plan, bottom → top. For each proposed PR give: a one-line
title, the files/areas it touches, and why it's a coherent standalone change.
Call out the dependency order explicitly.

**Do not create any branches until the user approves the plan.** This is the
human-in-the-loop gate; the split is a judgement call and the user owns it.

Example plan:

```
1. extract-config-loader   trunk      config/*.ts          pure refactor, no behavior change
2. add-retry-helper        #1         util/retry.ts        new helper, used by #3
3. wire-retries-into-api   #2         api/client.ts        uses the helper from #2
```

### Step 3: Build the stack bottom → top

Start from trunk, then for each planned PR in order:

1. Create the branch (the first off trunk, each subsequent one off the previous
   branch — `git stack new` records the parent automatically):

   ```bash
   git checkout <trunk>          # only for the first branch
   git stack new <branch-name>   # parent defaults to the current branch
   ```

2. Bring in **only this PR's subset** of the work from the original branch, then
   commit it. Pick the mechanism that fits how the split lines up:

   - **By whole files** — the subset is a clean set of paths:
     ```bash
     git checkout <original-branch> -- <path> [<path>...]
     git commit -m "<title>"
     ```
   - **By hunks within a file** — only part of a file belongs to this PR:
     ```bash
     git checkout -p <original-branch> -- <path>   # stage selected hunks
     git commit -m "<title>"
     ```
   - **By original commit** — the split lines up with commits as written:
     ```bash
     git cherry-pick <sha> [<sha>...]
     ```

3. Confirm the branch builds / the subset is self-contained before moving on.

Do these one branch at a time, bottom to top, so each builds on a parent that
already exists.

### Step 4: Verify nothing was lost or reordered

After the top branch is built, its tree must match the original branch exactly —
otherwise some change was dropped, duplicated, or split wrong:

```bash
git diff <top-branch> <original-branch>    # MUST be empty
git stack                                  # sanity-check the shape of the stack
```

If that diff is non-empty, the split is incomplete — reconcile it before
continuing. The original branch and the SHA from Step 0 are your fallback.

### Step 5: Open the PRs

Once every branch is created and verified, run the **`create-pr-stack` skill** to
open a pull request for each branch, each based on its stack parent.

## Critical rules

- **Never modify the original branch.** It's the recovery point and the
  verification baseline. Build the new branches *beside* it, off trunk.
- **Get plan approval before creating branches** (Step 2). The split is the
  user's call.
- **Bottom → top, dependencies first.** Each branch must apply cleanly on its
  parent, with no forward dependencies on a higher branch.
- **Verify the top branch's tree equals the original** (Step 4) before opening
  any PRs. An incomplete split is worse than no split.
- **Stop and hand back on any error or ambiguity** you can't resolve safely
  rather than guessing how to partition the work.
