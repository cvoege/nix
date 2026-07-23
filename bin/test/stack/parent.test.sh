# parent.test.sh — `git stack parent [<parent>|--unset]`

test_parent_prints_none_when_unrecorded() {
  make_repo
  git checkout --quiet -b feat
  run git stack parent
  assert_success
  assert_output_contains "no parent recorded"
}

test_parent_set_records_config() {
  make_repo
  git checkout --quiet -b feat
  run git stack parent main
  assert_success
  assert_parent feat main
}

test_parent_prints_recorded_parent() {
  make_repo
  linear_stack a b          # trunk <- a <- b, now on b
  run git stack parent
  assert_success
  assert_output_contains "a"
}

test_parent_rejects_self() {
  make_repo
  git checkout --quiet -b feat
  run git stack parent feat
  assert_failure
  assert_stderr_contains "its own parent"
}

test_parent_rejects_missing_branch() {
  make_repo
  git checkout --quiet -b feat
  run git stack parent nope
  assert_failure
  assert_stderr_contains "no such branch"
}

test_parent_unset_reparents_children_and_untracks() {
  make_repo
  linear_stack a b c        # trunk <- a <- b <- c
  git checkout --quiet b
  run git stack parent --unset
  assert_success
  assert_no_parent b        # b no longer tracked
  assert_parent c a         # c reparented onto b's parent (a)
}
