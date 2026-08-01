# diff.test.sh — `git stack diff`

# The headline case: the parent (here trunk) gained commits after the branch
# forked. A naive `git diff main feat` drags those in; the fork-point diff can't.
test_diff_excludes_parent_commits_landed_after_fork() {
  make_repo
  linear_stack a
  git checkout --quiet main
  commit "someone else's work" other.txt
  git push --quiet origin main
  git checkout --quiet a

  run git diff --name-only main a            # naive: sees trunk's commit too
  assert_output_contains "other.txt"

  run git stack diff --name-only
  assert_success
  assert_output_contains "a.txt"
  assert_output_not_contains "other.txt"
}

test_diff_of_mid_stack_branch_is_against_its_parent_only() {
  make_repo
  linear_stack a b c
  git checkout --quiet b
  run git stack diff --name-only
  assert_success
  assert_output_contains "b.txt"
  assert_output_not_contains "a.txt"    # parent's work
  assert_output_not_contains "c.txt"    # child's work
}

test_diff_falls_back_to_trunk_when_no_parent_recorded() {
  make_repo
  git checkout --quiet -b loose         # no stack parent recorded
  commit "loose work"
  git checkout --quiet main
  commit "trunk moved on" other.txt
  git checkout --quiet loose

  run git stack diff --name-only
  assert_success
  assert_output_contains "loose.txt"
  assert_output_not_contains "other.txt"
}

test_diff_base_prints_the_fork_point_commit() {
  make_repo
  local forked; forked=$(git rev-parse HEAD)
  linear_stack a
  git checkout --quiet main
  commit "trunk moved on" other.txt
  git checkout --quiet a

  run git stack diff --base
  assert_success
  assert_eq "$output" "$forked" "fork point"
}

# Local parent ref stale (a fixup was pushed to origin/a and `a` rebased onto it
# elsewhere): the fork point comes from origin/a, so a's fixup stays out.
test_diff_uses_origin_parent_when_local_parent_ref_is_stale() {
  make_repo
  linear_stack a b
  git checkout --quiet a
  commit "review fixup on a"
  git push --quiet -u origin a
  git checkout --quiet b
  git rebase --quiet a >/dev/null 2>&1   # b now sits on a's fixup
  git update-ref refs/heads/a a~1        # local a rewound; origin/a has the fixup

  run git diff --name-only main b        # naive: a's whole branch shows up
  assert_output_contains "a.txt"

  run git stack diff --name-only
  assert_success
  assert_output_contains "b.txt"
  assert_output_not_contains "a.txt"
}

# After `git stack remove` drops a squash-merged parent, the child keeps a pinned
# fork base. Trunk doesn't have the squash commit yet, so only that pin can keep
# the removed parent's work out of the child's diff.
test_diff_honours_recorded_fork_base_after_parent_removed() {
  make_repo
  linear_stack a b
  git checkout --quiet b
  run git stack remove a
  assert_success
  assert_parent b main

  run git diff --name-only main b        # naive: a's work looks like b's
  assert_output_contains "a.txt"

  run git stack diff --name-only
  assert_success
  assert_output_contains "b.txt"
  assert_output_not_contains "a.txt"
}

# A rebase can strand the pinned fork base off the branch's history; it must be
# ignored then, rather than producing a bogus (or empty) diff.
test_diff_ignores_fork_base_that_is_not_an_ancestor() {
  make_repo
  linear_stack a
  git config branch.a.stackForkBase "$(git rev-parse main)"
  git checkout --quiet main
  commit "unrelated trunk work" other.txt
  git checkout --quiet a
  git config branch.a.stackForkBase "$(git rev-parse main)"   # not on a's history

  run git stack diff --name-only
  assert_success
  assert_output_contains "a.txt"
  assert_output_not_contains "other.txt"
}

test_diff_accepts_an_explicit_branch_argument() {
  make_repo
  linear_stack a b
  git checkout --quiet main
  run git stack diff b --name-only
  assert_success
  assert_output_contains "b.txt"
  assert_output_not_contains "a.txt"
}

test_diff_excludes_uncommitted_changes_unless_dirty() {
  make_repo
  linear_stack a
  echo scratch >>a.txt
  echo untracked >new.txt
  git add new.txt

  run git stack diff
  assert_success
  assert_output_not_contains "scratch"
  assert_output_not_contains "new.txt"

  run git stack diff --dirty
  assert_success
  assert_output_contains "scratch"
  assert_output_contains "new.txt"
}

test_diff_dirty_rejects_a_branch_that_is_not_checked_out() {
  make_repo
  linear_stack a b
  git checkout --quiet b
  run git stack diff a --dirty
  assert_failure
  assert_stderr_contains "--dirty only works on the checked-out branch"
}

test_diff_forwards_args_and_pathspecs_to_git_diff() {
  make_repo
  linear_stack a
  commit "second file" notes.txt

  run git stack diff --stat
  assert_success
  assert_output_contains "2 files changed"

  run git stack diff --name-only -- notes.txt
  assert_success
  assert_output_contains "notes.txt"
  assert_output_not_contains "a.txt"
}

test_diff_is_empty_when_the_branch_has_no_commits_of_its_own() {
  make_repo
  git stack new a >/dev/null 2>&1      # branched, nothing committed
  run git stack diff
  assert_success
  assert_eq "$output" "" "diff of an empty branch"
}

# Piped output must be diff and nothing else: review tools consume it verbatim.
test_diff_writes_no_header_when_stdout_is_not_a_tty() {
  make_repo
  linear_stack a
  run git stack diff
  assert_success
  assert_eq "$stderr" "" "stderr when piped"
  case "$output" in "diff --git"*) ;; *) _fail "stdout should start with the diff, got: $output" ;; esac
}

# On a terminal the summary goes to stderr, so it still can't pollute the diff.
test_diff_summarises_on_stderr_when_stdout_is_a_tty() {
  command -v expect >/dev/null 2>&1 || return 0
  make_repo
  linear_stack a
  run expect -c 'spawn -noecho git stack diff --stat; expect eof'
  assert_success
  assert_output_contains "a vs main"
  assert_output_contains "1 commit(s) from fork point"
}

test_diff_errors_on_trunk_and_detached_head() {
  make_repo                            # on main (trunk)
  run git stack diff
  assert_failure
  assert_stderr_contains "is the trunk"

  linear_stack a
  git checkout --quiet --detach
  run git stack diff
  assert_failure
  assert_stderr_contains "detached HEAD"
}
