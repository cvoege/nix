# show-list.test.sh — `git stack show`, `list`, `list-stacks`, `trunk`

test_show_marks_synced_and_local() {
  make_repo
  linear_stack a b
  git push --quiet -u origin a       # a is on origin; b is not
  git checkout --quiet b
  run git stack show
  assert_success
  assert_output_contains "main"
  assert_output_contains "[synced]"  # a
  assert_output_contains "[local]"   # b
}

test_show_errors_on_trunk() {
  make_repo                          # on main (trunk)
  run git stack show
  assert_failure
  assert_stderr_contains "checkout a stack branch"
}

test_list_prints_branch_parent_pairs() {
  make_repo
  linear_stack a b
  run git stack list
  assert_success
  assert_output_contains "$(printf 'a\tmain')"
  assert_output_contains "$(printf 'b\ta')"
}

test_list_stacks_shows_multiple_trees_and_orphans() {
  make_repo
  linear_stack a b                   # stack 1: main <- a <- b
  git checkout --quiet main
  git stack new x >/dev/null 2>&1    # stack 2: main <- x
  git branch orph main               # orphan: parent chain never reaches trunk
  git config branch.orph.stackParent ghost
  run git stack list-stacks
  assert_success
  assert_output_contains "a"
  assert_output_contains "x"
  assert_output_contains "orph"
}

test_trunk_prints_and_sets() {
  make_repo
  run git stack trunk
  assert_success
  assert_output_contains "main"
  run git stack trunk custom-trunk
  assert_success
  run git stack trunk
  assert_output_contains "custom-trunk"
}
