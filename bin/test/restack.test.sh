# restack.test.sh — `git stack restack [--squash|--offline|--no-push|--dry-run]`
#                    plus the conflict --abort/--continue flow.

test_restack_rebases_onto_new_parent_without_duplication() {
  make_repo
  linear_stack a b                   # b stacked on a
  git checkout --quiet a
  commit "fixup on a"                # a advances; b's base is now stale
  git checkout --quiet b
  run git stack restack --offline
  assert_success
  git merge-base --is-ancestor a b || _fail "b should sit on the new tip of a"
  assert_commit_count b a 1          # b contributes only its own commit (no dup)
  assert_linear b main
}

test_restack_squash_collapses_each_branch_to_one_commit() {
  make_repo
  git stack new a >/dev/null 2>&1
  commit "a1"; commit "a2"; commit "a3"   # 3 commits on a
  run git stack restack --squash --offline
  assert_success
  assert_commit_count a main 1
}

test_restack_rejects_branch_in_other_worktree() {
  make_repo
  linear_stack a b                   # trunk <- a <- b
  git checkout --quiet b
  local before; before=$(git rev-parse b)
  git worktree add --quiet "$SANDBOX/wt-a" a   # a can't be rebased from here
  run git stack restack --offline
  assert_failure
  assert_stderr_contains "other worktrees"
  assert_no_restack_in_progress                # bailed before writing state
  assert_eq "$(git rev-parse b)" "$before" "b tip unchanged"
}

test_restack_dry_run_changes_nothing_and_clears_state() {
  make_repo
  linear_stack a b
  local before; before=$(git rev-parse b)
  run git stack restack --dry-run --offline
  assert_success
  assert_output_contains "would restack"
  assert_eq "$(git rev-parse b)" "$before" "b tip unchanged by dry-run"
  assert_no_restack_in_progress
}

test_restack_pushes_with_force_with_lease() {
  make_repo
  linear_stack a b
  git push --quiet -u origin a b
  git checkout --quiet a
  commit "fixup on a"                # rewrites what will be pushed
  git checkout --quiet b
  run git stack restack             # online: fetch + rebase + force-push
  assert_success
  assert_synced a
  assert_synced b
}

# --- conflict flow --------------------------------------------------------

# Build a stack that will conflict on restack: a and b both edit shared.txt,
# then a is rewritten so b's patch no longer applies cleanly.
_make_conflict() {
  make_repo
  git stack new a >/dev/null 2>&1
  echo "line A" >shared.txt; git add shared.txt; git commit --quiet -m "a: shared"
  git stack new b >/dev/null 2>&1
  echo "line B" >>shared.txt; git add shared.txt; git commit --quiet -m "b: shared"
  git checkout --quiet a
  echo "line A rewritten" >shared.txt; git add shared.txt; git commit --quiet -m "a: rewrite"
  git checkout --quiet b
}

test_restack_conflict_then_abort_restores_tips() {
  _make_conflict
  local b_before; b_before=$(git rev-parse b)
  run git stack restack --offline
  assert_failure
  assert_stderr_contains "conflict while rebasing"
  assert_restack_in_progress
  run git stack restack --abort
  assert_success
  assert_no_restack_in_progress
  assert_eq "$(git rev-parse b)" "$b_before" "b restored to pre-restack tip"
}

test_restack_conflict_then_continue_completes() {
  _make_conflict
  run git stack restack --offline
  assert_failure
  assert_restack_in_progress
  # Resolve the conflict by hand, then continue.
  echo "resolved" >shared.txt
  git add shared.txt
  run git stack restack --continue
  assert_success
  assert_no_restack_in_progress
  git merge-base --is-ancestor a b || _fail "b should end up on top of a"
}
