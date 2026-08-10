---
name: create-pr-stack-full
description: Create GitHub PRs for an entire branch stack, one per branch, each targeting its stack parent as base. Use when opening PRs for a stacked set of branches (trunk <- a <- b <- c) managed with `git stack`
---

# Create PR Stack

Open a pull request for every branch in the current stack, processing one branch
at a time from the bottom (closest to trunk) upward. The critical invariant:
**each PR's base branch MUST be that branch's stack parent**, not trunk — so the
PRs review cleanly as a stack instead of each showing the whole cumulative diff.

**Requires**: `gh` authenticated, and the stack's parent pointers recorded (via
`git stack new` / `git stack parent`). The `git stack` utilities
must be on PATH.

## How the stack is defined

Each branch records its parent in git config (`branch.<name>.stackParent`); the
chain ends at the trunk. Get the stack as machine-readable `<branch><TAB><parent>`
lines, ordered bottom → top (parents before children):

```bash
git stack list
```

Example output:

```
colton/feat-a	trunk
colton/feat-b	colton/feat-a
colton/feat-c	colton/feat-b
```

Here the parent (second column) is exactly the `--base` to use for that branch's
PR. The root branch's parent is the trunk.

## Process

### Step 0: Preconditions

```bash
git stack list                 # must print at least one branch; if it errors,
                               # the current branch isn't a tracked stack — stop
                               # and tell the user to run `git stack parent <parent>`
git status --porcelain         # must be empty; if not, stop and have the user
                               # commit (use the /commit skill) or stash first
```

Remember the branch the user started on so you can return to it at the end:
`git branch --show-current`.

### Step 1: Walk the stack bottom → top

Iterate the `git stack list` lines **in order** (do NOT reorder — parents must be
processed and pushed before their children). For each `branch` with its `parent`:

1. **Check out and push** the branch so its head exists on the remote (required
   before any child PR can target it as a base):

   ```bash
   git checkout <branch>
   git push -u origin <branch>
   ```

2. **Does a PR already exist?**

   ```bash
   gh pr view <branch> --json number,baseRefName,title,body --jq '"\(.number)\t\(.baseRefName)\t\(.title)"'
   ```

   - **If it exists**: treat it as a PR to reconcile — do **not** create a
     duplicate. If the base branch doesn't equal `<parent>`, fix it:
        ```bash
        gh pr edit <branch> --base <parent>
        ```

3. **Create/update the PR** by following the **`create-pr-stack-single` skill** for this single
   branch (invoke that skill — it defines the required title format, scope,
   Linear issue, and body structure). Make sure to reference the linear ticket for
   additional info on the work that was meant to be completed. If the PR already 
   exists, it should be evaluated to see if the current title and description are
   accurate. 

   The create-pr-stack-single skill should be run with these stack-specific overrides:

   - Always pass **`--base <parent>`** and **`--head <branch>`** explicitly. The
     `<parent>` is the second column from `git stack list` for this branch.
   - Keep `--draft` (per create-pr-stack-single convention).
   - Analyze the diff for *this branch only* against its parent, not against
     trunk, so the description matches what the PR actually shows:

     ```bash
     git diff <parent>...<branch>
     git log <parent>..<branch> --oneline
     ```

Do these one branch at a time, top of loop to bottom of loop, before moving to
the next branch.

### Step 2: Return and report

```bash
git checkout <original-branch>   # the branch the user started on
```

Report which PRs were created, which already existed without changes, and any
whose base, title, or body you had to correct. Then report the full output of
`git stack prs`.

## Critical rules

- **Base = stack parent, every time.** A PR opened with the default base (trunk)
  will show the cumulative diff of the whole stack below it and is wrong. The
  whole point of this skill is getting `--base <parent>` right on each one.
- **Bottom → top order.** Never create a child's PR before its parent branch has
  been pushed; GitHub rejects a PR whose base branch doesn't exist on the remote.
- **Never create duplicates.** If `gh pr view <branch>` returns a PR, reconcile
  its base, title, and body — don't open another.
- **Don't touch trunk.** Trunk is only ever a base value, never gets its own PR.
- **Always print the PR URLs** - Always pring the PR URLs in your final response.

## Note on Linear auto-close

Per the `create-pr-stack-single` skill: a `Closes <ISSUE>` line only fires when the PR targets
the *default* branch (trunk). For every PR in the stack except the root (whose
base is trunk), the keyword is ignored until that PR is eventually retargeted to
trunk (after the lower PRs merge). Still include the correct `Closes`/`Refs` line
as create-pr-stack-single specifies — it becomes effective once the base becomes trunk. Don't
treat the stacked PRs as broken because the issue didn't move yet.
