# collapse.test.sh — `git stack collapse [--no-push] [--dry-run] [<start> [<end>]]`

test_collapse_whole_linear_stack() {
  make_repo
  linear_stack a b c                 # main <- a <- b <- c, one commit each
  run git stack collapse --no-push
  assert_success
  assert_branch a
  assert_no_branch b
  assert_no_branch c
  assert_parent a main
  assert_commit_count a main 3       # a now holds a+b+c
}

test_collapse_pushes_result() {
  make_repo
  linear_stack a b c
  run git stack collapse            # default: push
  assert_success
  assert_synced a
}

test_collapse_range_folds_and_reparents() {
  make_repo
  linear_stack a b c d e             # main <- a <- b <- c <- d <- e
  run git stack collapse --no-push b d
  assert_success
  assert_branch a
  assert_branch b
  assert_no_branch c
  assert_no_branch d
  assert_branch e
  assert_parent b a
  assert_parent e b                  # e reparented onto the collapse target
  assert_commit_count b a 3          # b holds b+c+d
}

test_collapse_dry_run_changes_nothing() {
  make_repo
  linear_stack a b c
  run git stack collapse --dry-run
  assert_success
  assert_output_contains "would collapse"
  assert_branch b                    # untouched
  assert_branch c
  assert_commit_count a main 1
}

test_collapse_refuses_nonlinear() {
  make_repo
  linear_stack a b                   # main <- a <- b
  git checkout --quiet a
  git stack new c >/dev/null 2>&1    # a now has two children: b and c
  git checkout --quiet b
  run git stack collapse --no-push
  assert_failure
  assert_stderr_contains "not linear"
}

test_collapse_refuses_dirty_tree() {
  make_repo
  linear_stack a b
  echo dirt >>a.txt                  # uncommitted change
  run git stack collapse --no-push
  assert_failure
  assert_stderr_contains "working tree is dirty"
}

test_collapse_errors_on_divergence() {
  make_repo
  linear_stack a b                   # b stacked on a
  git checkout --quiet a
  commit "extra on a"                # a moves ahead; b can no longer ff a
  git checkout --quiet b
  run git stack collapse --no-push
  assert_failure
  assert_stderr_contains "fast-forward"
}
