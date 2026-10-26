---
name: git-stack
description: Manage stacks of dependent git branches/PRs with `git stack` — view a stack and its PRs, create or remove branches in it, record parent pointers, diff a branch against its parent, restack (rebase the whole stack) after changes, sync after PRs merge, infer a stack from GitHub, and re-trigger Claude reviews. Use whenever the user mentions a branch stack, stacked PRs, restacking, or `git stack`.
---

# git stack — stacked branch utilities

`git stack` tracks a stack of branches by recording each branch's **parent** in
git config (`branch.<name>.stackParent`). A stack is a tree rooted on trunk:

```
trunk <- a <- b <- c
```

Each branch's PR should target its stack parent as its base. Everything else
(restack, sync, collapse, the PR views) is derived from these parent pointers.

Run `git stack help` for the full command list; the source is `bin/git-stack`
in the home-manager repo.

## Ground rules

- **Look before mutating.** Start with `git stack` (or `git stack list` for
  machine-readable output) to see the stack shape. If the current branch isn't
  tracked, the command says so — don't guess parents; ask, or use
  `git stack infer` when the branches have PRs.
- **Prefer `--dry-run`.** `restack`, `sync`, `sync-all`, `collapse` and `infer`
  all accept `--dry-run`. Use it first whenever the outcome isn't obvious, and
  check the plan matches what the user asked for.
- **Pushing is the default.** `restack`, `sync`, `sync-all` and `collapse`
  force-push (`--force-with-lease`) every branch they touch. Pass `--no-push`
  (or `--offline`, which also skips fetching) when the user hasn't asked for
  changes to reach GitHub.
- **Clean working tree.** Mutating commands refuse to run with uncommitted
  changes. Commit them (or ask the user) — never `git stash`.
- **Other worktrees.** Branches checked out in another worktree can't be
  rebased or deleted; commands fail up front listing them. Report that to the
  user rather than removing worktrees yourself.
- **Never edit `branch.*.stackParent` config by hand** — use `git stack parent`.
- If a command errors or needs a human decision, stop and hand back to the user.

## Viewing

| Command | Output |
| --- | --- |
| `git stack` | Tree of the current stack: each branch with `+ahead/-behind vs parent` and `[synced]`/`[unpushed]`/`[local]` |
| `git stack list` | `<branch>\t<parent>` per line, bottom → top. Best for scripting/parsing. No network. |
| `git stack prs list` | One line per branch with its PR number, state, size, title and URL. Best for reading PR info. |
| `git stack prs` | Tree view labelled with PRs |
| `git stack list-stacks` | Every tracked stack in the repo, plus orphaned branches whose parent chain is broken |
| `git stack parent` | The current branch's parent |
| `git stack trunk` | The trunk branch (default: origin's HEAD) |

## Diffing a branch's own work

```bash
git stack diff [<branch>] [--stat|--name-only|...] [-- <path>...]
```

Diffs a branch against its stack parent **from the fork point**, so commits the
parent gained since the last rebase don't show up. Use this — not
`git diff main` or `git diff <parent>` — when reviewing or describing what a
single branch in a stack changes. `--dirty` includes uncommitted changes (current
branch only); `--base` prints just the fork-point commit. Unknown flags are
passed through to `git diff`. Output is pure diff when piped.

## Building a stack

- `git stack new <name> [<parent>]` — create and check out a branch stacked on
  `<parent>` (default: the current branch). Use this rather than
  `git checkout -b` so the parent is recorded.
- `git stack parent <parent>` — record/change the current branch's parent
  (e.g. adopting an existing branch into a stack, or moving it onto another
  branch; follow with a restack to actually rebase it).
- `git stack parent --unset` — stop tracking the current branch; its children
  move onto its parent.
- `git stack remove <name>` — delete a branch (not the checked-out one) and
  reparent its children onto its parent. Pins the children's fork point so the
  next restack replays only their own commits.
- `git stack infer [--dry-run]` — rebuild parent pointers from GitHub PR base
  branches (needs an open PR on the current branch). Fetches any missing
  branches. Use when the user checked out someone's stack or lost the metadata.
- `git stack checkout` is an interactive menu — don't run it; use
  `git checkout <branch>` directly.

## Rewriting the stack

### restack — rebase everything after a change

```bash
git stack restack [--squash] [--no-push] [--offline] [--dry-run]
```

Run from any branch in the stack after amending/adding commits to a lower
branch, pulling new trunk, or changing a parent. It fetches, fast-forwards
branches whose remote is strictly ahead, rebases bottom → top onto each
parent's new tip, force-pushes, and returns to the starting branch. `--squash`
collapses each branch to one commit. It stops hard if a local branch has
diverged from its remote — surface that to the user.

**On conflict**, restack stops mid-rebase and prints instructions:

1. Resolve the conflicted files and `git add` them.
2. `git stack restack --continue` (it also works if `git rebase --continue` was
   already run by hand).
3. Or `git stack restack --abort` to restore every branch to its pre-restack tip.

Resolve conflicts yourself only when the right resolution is clear; otherwise
show the user the conflict and ask. Never start a new restack while one is in
progress.

### sync — after PRs merge

```bash
git stack sync [--no-push] [--offline] [--dry-run]
git stack sync-all [...]      # every tracked stack in turn
```

Drops branches whose PR is merged (or whose tip is in `origin/<trunk>`),
reparents their children, then restacks the rest. Use when the user says a PR
in the stack landed. After it runs, the PR of any branch that moved onto a new
parent still targets the deleted branch on GitHub; retarget it:

```bash
gh pr edit <branch> --base <new-parent>
```

Then confirm with `git stack prs list` that each PR's base matches its parent.

### collapse — fold branches together

```bash
git stack collapse [--no-push] [--dry-run] [<start> [<end>]]
```

Fast-forward-merges a linear range into `<start>` and deletes the folded
branches (whole stack into its root if no range). For the full workflow
including PR updates, use the `collapse-pr-stack` skill.

## PRs and reviews

- Opening PRs: use the `create-pr-stack` skill (one branch) or
  `create-pr-stack-full` (whole stack). Splitting one branch into a stack:
  `breakout-pr-stack`.
- `git stack review` — hides the Claude bot's stale review comments and posts
  `@claude review once` on every PR in the stack; `git stack review single` does
  only the current branch. This posts to GitHub, so only run it when asked.
