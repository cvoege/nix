# new-remove.test.sh — `git stack new` and `git stack remove`

test_new_creates_branch_off_current() {
  make_repo                         # on main
  run git stack new feat
  assert_success
  assert_branch feat
  assert_head feat
  assert_parent feat main
}

test_new_creates_branch_off_explicit_parent() {
  make_repo
  linear_stack a                    # trunk <- a, on a
  git checkout --quiet main
  run git stack new b a             # explicit parent a, though HEAD is main
  assert_success
  assert_parent b a
}

test_new_rejects_missing_name() {
  make_repo
  run git stack new
  assert_failure
  assert_stderr_contains "usage: git stack new"
}

test_new_rejects_missing_parent() {
  make_repo
  run git stack new b ghost
  assert_failure
  assert_stderr_contains "does not exist"
}

test_remove_reparents_children_and_deletes() {
  make_repo
  linear_stack a b c                # trunk <- a <- b <- c
  git checkout --quiet a            # can't remove the current branch
  run git stack remove b
  assert_success
  assert_no_branch b
  assert_parent c a                 # c reparented onto b's parent
}

test_remove_rejects_current_branch() {
  make_repo
  linear_stack a b
  git checkout --quiet b
  run git stack remove b
  assert_failure
  assert_stderr_contains "currently checked-out"
  assert_branch b
}

test_remove_rejects_missing_branch() {
  make_repo
  linear_stack a
  run git stack remove ghost
  assert_failure
  assert_stderr_contains "no such branch"
}

test_remove_rejects_untracked_branch() {
  make_repo
  git checkout --quiet -b loose main   # no recorded parent
  git checkout --quiet main
  run git stack remove loose
  assert_failure
  assert_stderr_contains "no stack parent recorded"
}
