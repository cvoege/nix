#!/usr/bin/env bash
# git-stack-lib.sh — shared helpers for git-stack / git-restack.
# Sourced by the git-stack and git-restack subcommands. Not meant to be run directly.
#
# Stack model: every tracked branch records its *parent branch* in git config as
#   branch.<name>.stackParent
# The parent chain ends at the trunk (origin's default branch, configurable via
# `git config stack.trunk`). A stack is therefore a tree rooted at trunk; a plain
# linear stack (trunk <- a <- b <- c) is just the degenerate case.

set -euo pipefail

# ---- trunk ---------------------------------------------------------------

stack_trunk() {
  local t
  t=$(git config --get stack.trunk || true)
  if [[ -n "$t" ]]; then echo "$t"; return 0; fi
  # origin's default branch, e.g. refs/remotes/origin/HEAD -> origin/trunk
  t=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$t" ]]; then echo "${t#origin/}"; return 0; fi
  local c
  for c in trunk main master; do
    if git show-ref --verify --quiet "refs/heads/$c"; then echo "$c"; return 0; fi
  done
  echo "main"
}

# ---- branch / parent metadata -------------------------------------------

branch_exists() { git show-ref --verify --quiet "refs/heads/$1"; }

stack_parent() { git config --get "branch.$1.stackParent" || true; }

stack_set_parent() { git config "branch.$1.stackParent" "$2"; }

stack_unset_parent() { git config --unset "branch.$1.stackParent" 2>/dev/null || true; }

current_branch() { git symbolic-ref --quiet --short HEAD 2>/dev/null || true; }

# All local branches that have a recorded parent.
# git canonicalises config keys to lowercase (branch.<name>.stackparent), but
# preserves the case of the <name> subsection; each line is "<key> <value>".
stack_tracked_branches() {
  git config --get-regexp '^branch\..*\.stackParent$' 2>/dev/null \
    | sed -E 's/^branch\.(.*)\.stackparent .*$/\1/' || true
}

# Direct children of a branch (tracked branches whose parent == $1).
stack_children() {
  local target="$1" b
  while read -r b; do
    [[ -z "$b" ]] && continue
    [[ "$(stack_parent "$b")" == "$target" ]] && echo "$b"
  done < <(stack_tracked_branches)
}

# Walk parent pointers from $1 up to the root branch (the one whose parent is
# the trunk). Errors if a branch in the chain has no parent recorded.
stack_root() {
  local b="$1" trunk p guard=0
  trunk=$(stack_trunk)
  [[ "$b" == "$trunk" ]] && { echo "ERR:on-trunk"; return 1; }
  while :; do
    p=$(stack_parent "$b")
    if [[ -z "$p" ]]; then echo "ERR:no-parent:$b"; return 1; fi
    [[ "$p" == "$trunk" ]] && { echo "$b"; return 0; }
    b="$p"
    guard=$((guard + 1)); [[ $guard -gt 1000 ]] && { echo "ERR:cycle"; return 1; }
  done
}

# Topological list (parents before children) of every branch in the stack that
# $1 belongs to. Output: one branch name per line, trunk excluded.
stack_collect() {
  local start="$1" root
  root=$(stack_root "$start") || { echo "$root"; return 1; }
  # BFS from root over the children map; tree => parents always precede children.
  local queue=("$root") b child
  while [[ ${#queue[@]} -gt 0 ]]; do
    b="${queue[0]}"; queue=("${queue[@]:1}")
    echo "$b"
    while read -r child; do
      [[ -n "$child" ]] && queue+=("$child")
    done < <(stack_children "$b")
  done
}

# ---- misc ----------------------------------------------------------------

sha() { git rev-parse --verify --quiet "$1^{commit}"; }

# True if $1 is an ancestor of (or equal to) $2.
is_ancestor() { git merge-base --is-ancestor "$1" "$2" 2>/dev/null; }

# Count of commits in <upstream>..<branch>.
ahead_count() { git rev-list --count "$1..$2" 2>/dev/null || echo 0; }

rebase_in_progress() {
  local d
  d=$(git rev-parse --git-path rebase-merge); [[ -d "$d" ]] && return 0
  d=$(git rev-parse --git-path rebase-apply); [[ -d "$d" ]] && return 0
  return 1
}

die() { echo "git-stack: $*" >&2; exit 1; }
info() { echo "• $*" >&2; }
