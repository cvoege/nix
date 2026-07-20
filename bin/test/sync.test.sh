# sync.test.sh — `git stack sync` / `sync-all` (drop merged branches, restack rest)

test_sync_drops_branch_merged_by_ancestry() {
  make_repo
  linear_stack a b                   # main <- a <- b
  git checkout --quiet main
  git merge --quiet --ff-only a      # main now contains a's commit
  git push --quiet origin main       # origin/main is a's ancestor => a "merged"
  git checkout --quiet b
  run git stack sync
  assert_success
  assert_no_branch a
  assert_parent b main               # b reparented onto trunk and restacked
}

test_sync_drops_branch_merged_by_pr_state() {
  make_repo
  linear_stack a b
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet b
  run git stack sync --offline
  assert_success
  assert_no_branch a
  assert_parent b main
}

test_sync_whole_stack_merged() {
  make_repo
  linear_stack a
  gh_add_pr a main MERGED
  run git stack sync --offline
  assert_success
  assert_no_branch a
  assert_head main                   # moved off the merged branch
  assert_stderr_contains "nothing left to restack"
}

test_sync_moves_off_current_merged_branch() {
  make_repo
  linear_stack a b
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet a             # sitting on the branch about to be dropped
  run git stack sync --offline
  assert_success
  assert_no_branch a
  assert_head b
  assert_parent b main
}

test_sync_dry_run_changes_nothing() {
  make_repo
  linear_stack a b
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet b
  run git stack sync --dry-run
  assert_success
  assert_output_contains "would drop merged"
  assert_branch a
}

# A real squash-merge: `a` has two commits to one file, and GitHub collapses
# them into a single commit on trunk whose SHA/history differs from a's. Dropping
# `a` and restacking `b` must replay only b's own commits — replaying a's
# originals onto the squashed trunk would conflict.
test_sync_after_squash_merge_replays_only_survivors_commits() {
  make_repo
  git stack new a >/dev/null 2>&1
  echo v1 >f.txt; git add f.txt; git commit --quiet -m "a1"
  echo v2 >f.txt; git add f.txt; git commit --quiet -m "a2"   # a: 2 commits, same file
  git stack new b >/dev/null 2>&1
  commit "work on b"                                          # b's own work (b.txt)
  # Simulate a GitHub squash-merge of a: one new commit on trunk with a's tree.
  git checkout --quiet main
  git checkout a -- f.txt; git add f.txt
  git commit --quiet -m "squashed a (#1)"
  git push --quiet origin main
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet b
  run git stack sync --offline
  assert_success
  assert_no_branch a
  assert_parent b main
  assert_commit_count b main 1        # only b's own commit on top of trunk
  assert_linear b main
  # the one-shot fork-base override is consumed by the restack, not left behind
  assert_eq "$(git config --get branch.b.stackForkBase 2>/dev/null || true)" "" \
    "fork-base override should be cleared after a successful sync"
}

# Two consecutive squash-merged branches (a then b), only c survives. Each
# removal must pin the next branch's fork point, so c restacks with only its
# own commit.
test_sync_after_consecutive_squash_merges() {
  make_repo
  git stack new a >/dev/null 2>&1
  echo a1 >fa.txt; git add fa.txt; git commit --quiet -m "a1"
  echo a2 >fa.txt; git add fa.txt; git commit --quiet -m "a2"
  git stack new b >/dev/null 2>&1
  echo b1 >fb.txt; git add fb.txt; git commit --quiet -m "b1"
  echo b2 >fb.txt; git add fb.txt; git commit --quiet -m "b2"
  git stack new c >/dev/null 2>&1
  commit "work on c"
  # Squash-merge a and b together onto trunk as one commit with both trees.
  git checkout --quiet main
  git checkout b -- fa.txt fb.txt; git add fa.txt fb.txt
  git commit --quiet -m "squashed a+b (#1)"
  git push --quiet origin main
  gh_add_pr a main MERGED
  gh_add_pr b a MERGED
  gh_add_pr c b OPEN
  git checkout --quiet c
  run git stack sync --offline
  assert_success
  assert_no_branch a
  assert_no_branch b
  assert_parent c main
  assert_commit_count c main 1        # only c's own commit on top of trunk
  assert_linear c main
}

test_sync_all_processes_every_stack() {
  make_repo
  linear_stack a b                   # stack 1
  git checkout --quiet main
  git stack new x >/dev/null 2>&1    # stack 2
  commit "work on x"
  gh_add_pr a main MERGED            # only stack 1 has a merged branch
  gh_add_pr b a OPEN
  run git stack sync-all --offline
  assert_success
  assert_no_branch a                 # stack 1's merged branch dropped
  assert_branch b
  assert_branch x                    # stack 2 untouched structurally
}

# --- worktree preflight ---------------------------------------------------
# A branch checked out in another worktree can be neither deleted (git branch -D)
# nor rebased (git rebase). sync must bail BEFORE mutating any metadata; the old
# behaviour reparented-then-failed, collapsing the stack toward trunk.

test_sync_blocked_when_survivor_in_other_worktree() {
  make_repo
  linear_stack a b c                 # trunk <- a <- b <- c
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  gh_add_pr c b OPEN
  git checkout --quiet c
  git worktree add --quiet "$SANDBOX/wt-b" b   # survivor b held elsewhere
  run git stack sync --offline
  assert_failure
  assert_stderr_contains "other worktrees"
  # nothing mutated: the merged branch survives and every parent pointer is intact
  assert_branch a
  assert_parent a main
  assert_parent b a
  assert_parent c b
  assert_no_restack_in_progress
}

test_sync_blocked_when_merged_branch_in_other_worktree() {
  make_repo
  linear_stack a b                   # trunk <- a <- b
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet b
  git worktree add --quiet "$SANDBOX/wt-a" a   # the merged branch itself
  run git stack sync --offline
  assert_failure
  assert_stderr_contains "other worktrees"
  assert_branch a                    # not deleted
  assert_parent a main               # config not unset (the buggy path cleared it)
  assert_parent b a                  # b not reparented onto trunk
}

test_sync_unrelated_worktree_does_not_block() {
  make_repo
  linear_stack a b
  git checkout --quiet main
  git branch other main
  git worktree add --quiet "$SANDBOX/wt-o" other   # not part of the stack
  gh_add_pr a main MERGED
  gh_add_pr b a OPEN
  git checkout --quiet b
  run git stack sync --offline
  assert_success
  assert_no_branch a                 # merged branch dropped as usual
  assert_parent b main
}
