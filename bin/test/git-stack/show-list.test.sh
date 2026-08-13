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

# Parent pointers are resolved through an in-process "<branch>\t<parent>" map, so
# a branch name that is a strict prefix of another must not match its neighbour.
test_list_distinguishes_prefix_branch_names() {
  make_repo
  linear_stack feat feat-1 feat-1-x
  run git stack list
  assert_success
  assert_output_contains "$(printf 'feat\tmain')"
  assert_output_contains "$(printf 'feat-1\tfeat')"
  assert_output_contains "$(printf 'feat-1-x\tfeat-1')"
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

# Parent/ref lookups must not degrade as the repo grows: a linear-scan or
# string-slicing implementation looks fine on a toy stack and takes minutes —
# indistinguishable from a hang — in a repo tracking a few hundred branches.
test_list_stacks_scales_to_many_tracked_branches() {
  make_repo
  linear_stack a b
  many_tracked_branches 200
  git checkout --quiet b
  local -a runner=()
  command -v timeout >/dev/null 2>&1 && runner=(timeout 60)
  run ${runner[@]+"${runner[@]}"} git stack list-stacks
  assert_success                        # status 124 = timed out
  assert_output_contains "201 stacks on main"
  assert_output_contains "perf-200"
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
