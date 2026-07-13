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
