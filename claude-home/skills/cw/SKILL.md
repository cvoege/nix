---
name: cw
description: Spin up parallel coding workspaces with `cw` — each one a pooled git worktree on its own branch, opened in a new Herdr tab (or tmux window) running its own agent. Use when the user asks to hand work off to a new workspace/worktree/agent, run tasks in parallel, kick off a review, start Linear tickets, or close workspaces with `cw`.
---

# cw — parallel agent workspaces

`cw` opens a git worktree (via `ct`, the worktree pool) on a branch, then opens a
new multiplexer tab in it with an agent running and, optionally, a prompt
already sent. Use it to hand self-contained tasks to separate agents that work
in parallel with you.

Run `cw --help` or `cw <command> --help` for the exact flags; the source is
`bin/cw` in the home-manager repo.

## Before running anything

- **Be inside the target repo.** `cw` runs `ct`/`git stack` in the current
  directory, so `cd` into the repo (the main checkout or any of its worktrees)
  first.
- **Check the multiplexer.** `CW_MULTIPLEXER` defaults to `herdr`, which
  requires running inside Herdr:

  ```bash
  test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_WORKSPACE_ID:-}"
  ```

  If this fails and `CW_MULTIPLEXER` isn't `tmux`, tell the user `cw` can't open
  tabs from here and stop.
- **One branch, one worktree.** A branch already checked out in another
  worktree can't be opened again; `cw` will fail. Pick a new branch name or ask.

## Writing the prompt

The spawned agent starts in a fresh worktree with **none of your context**.
Write the `--prompt` as a complete brief: the goal, the relevant files, any
decisions already made, and what "done" looks like. Quote it carefully for the
shell — use single quotes, or a heredoc into a variable, when it contains `$`,
backticks or quotes.

## Commands

Always pass the prompt with `-p/--prompt`; the branch is the only positional.

| Command | What it does |
| --- | --- |
| `cw create [-b BASE] [-p PROMPT] [-g] <branch>` | Open a workspace with an interactive agent, optionally prompted. Focuses the new tab unless `-g/--background`. Aliases: `start`, `c`. |
| `cw quick [-b BASE] -p PROMPT <branch>` | Background workspace: do the prompt, commit, push, then `/create-pr-stack`. |
| `cw full [-b BASE] [-e EFFORT] -p PROMPT <branch>` | Like `quick`, but also self-reviews with `/code-review <effort> --fix` before pushing. Effort defaults to `max`. |
| `cw linear [-b BASE] <ticket>...` | One `quick` workspace per Linear ticket: assigns it, moves it to In Progress, completes it. Tickets may be ids (`ACT-123`), Linear branch names, or issue URLs. Branch is `$USER/<ticket-id>`. |
| `cw review [-e EFFORT] <branch>` | Background interactive workspace on an existing branch that runs `/code-review` and prints findings. |
| `cw review-oneshot [-e EFFORT] <branch>` | Headless review that posts findings as PR comments, then closes itself. |
| `cw oneshot [-b BASE] -p PROMPT <branch>` | Headless agent (`claude -p`) in a background tab; output is logged, and the workspace closes itself when done. |
| `cw closex [-f] [-r] <workspace>...` | Close the named workspaces (branch, worktree path, or `ct-worktree-N`) and their tabs. Herdr only. |
| `cw close-all [-f] [-r]` | Close every busy `ct` workspace in the repo. Herdr only. |
| `cw close [-f] [-r]` | Close the workspace **you are currently in**. |

Close flags: `-f/--force` discards uncommitted and untracked changes; `-r/--remove`
deletes the worktree instead of parking it for reuse. Without `-f`, closing
refuses when there's work that would be lost — report that to the user rather
than retrying with `-f`.

## Branches and bases

- A **new** branch is created from `--base` (default: the trunk, `git stack
  trunk`) and recorded as stacked on it, so `git stack` sees it. To stack work
  on another in-flight branch, pass `-b <that-branch>`.
- An **existing** branch (local or on origin) is reopened as-is and
  fast-forwarded to origin; `--base` is rejected unless it's the trunk.
- Follow the user's naming convention: `colton/act-123-short-title` for ticket
  work. Such branches get a tab named after the ticket (`ACT-123`); others get
  the branch lowercased with `/` turned into `-`.
- Several independent tasks should each get their own branch off the trunk
  (siblings), not a chain — only stack them with `-b` when one genuinely
  depends on another.

## Rules for agents

- **Default to `-g/--background`** with `cw create` so you don't steal the
  user's focus, unless they asked to switch to the new workspace. `quick`,
  `full`, `review`, `linear` and `oneshot` are already background.
- **Never run `cw close` yourself** unless the user explicitly asks: it closes
  the workspace and tab you are running in. Use `cw closex <branch>` to close
  a different one.
- Don't close workspaces (`closex`, `close-all`) the user didn't ask you to;
  each holds another agent's in-progress work.
- `cw` returns as soon as the workspace is open — it does not wait for the
  spawned agent. Report the branch and tab you opened, then carry on.

## Checking on one-shot runs

`oneshot` and `review-oneshot` log to `${CW_LOG_DIR:-~/.cw/logs}/<tab-name>-<timestamp>.log`
(the path is printed when it starts). The log streams the agent's
`stream-json` output, and its last line is `cw: oneshot exit <status>` once the
run has finished — absent while it's still running.

```bash
ls -t ~/.cw/logs/ACT-123-*.log | head -1     # newest log for a tab
tail -n 1 "$log"                             # "cw: oneshot exit 0" when done
```

## Environment

- `CW_AGENT` — `claude` (default) or `opencode`.
- `CW_MULTIPLEXER` — `herdr` (default) or `tmux`. Under tmux, `closex` and
  `close-all` aren't implemented; close tmux workspaces from inside with
  `cw close`, or tell the user.
- `CW_LOG_DIR` — where one-shot logs go (default `~/.cw/logs`).
