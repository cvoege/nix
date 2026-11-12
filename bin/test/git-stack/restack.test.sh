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

# --- trunk is never moved --------------------------------------------------
# restack used to fast-forward local trunk with update-ref, which moves the ref
# out from under any worktree that has trunk checked out.

_push_from_other_clone() { # branch msg [file]
  [[ -d "$SANDBOX/other" ]] || git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/other" 2>/dev/null
  (
    cd "$SANDBOX/other" || exit 1
    git fetch --quiet origin
    git checkout --quiet -B "$1" "origin/$1"
    commit "$2" "${3:-}"
    git push --quiet origin "$1"
  )
}

test_restack_leaves_trunk_checked_out_elsewhere_untouched() {
  make_repo
  git stack new a >/dev/null 2>&1
  commit "work on a"
  git checkout --quiet main
  git worktree add --quiet "$SANDBOX/wt-a" a
  _push_from_other_clone main "landed on trunk"
  local main_before; main_before=$(git rev-parse main)
  cd "$SANDBOX/wt-a" || return 1
  run git stack restack --no-push
  assert_success
  assert_eq "$(git rev-parse main)" "$main_before" "local main unchanged"
  assert_eq "$(git -C "$SANDBOX/work" status --porcelain)" "" "main worktree status"
  git merge-base --is-ancestor origin/main a || _fail "a should sit on origin/main"
  assert_commit_count a origin/main 1
}

test_restack_onto_origin_trunk_when_local_trunk_stale() {
  make_repo
  git stack new a >/dev/null 2>&1
  commit "work on a"
  _push_from_other_clone main "landed on trunk"
  local main_before; main_before=$(git rev-parse main)
  run git stack restack --no-push
  assert_success
  assert_eq "$(git rev-parse main)" "$main_before" "local main unchanged"
  git merge-base --is-ancestor origin/main a || _fail "a should sit on origin/main"
  assert_commit_count a origin/main 1
  assert_linear a origin/main
  assert_output_not_contains "conflict"
}

# a already sits on a newer origin/main than local main. Replaying from local
# main's tip would re-apply the first trunk commit onto the second, which edits
# the same file, and conflict.
test_restack_branch_ahead_of_local_trunk_replays_only_own_commits() {
  make_repo
  _push_from_other_clone main "trunk v1" trunk.txt
  git fetch --quiet origin
  git checkout --quiet -b a origin/main
  git config branch.a.stackParent main
  commit "work on a"
  _push_from_other_clone main "trunk v2" trunk.txt
  local main_before; main_before=$(git rev-parse main)
  run git stack restack --no-push
  assert_success
  assert_no_restack_in_progress
  assert_eq "$(git rev-parse main)" "$main_before" "local main unchanged"
  git merge-base --is-ancestor origin/main a || _fail "a should sit on origin/main"
  assert_commit_count a origin/main 1
}

test_restack_offline_rebases_onto_local_trunk() {
  make_repo
  git stack new a >/dev/null 2>&1
  commit "work on a"
  _push_from_other_clone main "landed on trunk"
  git fetch --quiet origin
  git checkout --quiet main
  commit "local trunk work"
  git checkout --quiet a
  run git stack restack --offline
  assert_success
  git merge-base --is-ancestor main a || _fail "a should sit on local main"
  git merge-base --is-ancestor origin/main a && _fail "a should not be on origin/main when offline"
  assert_commit_count a main 1
}

test_restack_dry_run_shows_origin_trunk_target() {
  make_repo
  linear_stack a b
  run git stack restack --dry-run --no-push
  assert_success
  assert_output_contains "onto origin/main"
  assert_output_contains "onto a "
}

# A review fixup pushed to the checked-out branch used to be adopted with
# update-ref, leaving this worktree's index on the old commit.
test_restack_fast_forwards_current_branch_without_dirtying_worktree() {
  make_repo
  git stack new a >/dev/null 2>&1
  commit "work on a"
  git push --quiet -u origin a
  _push_from_other_clone a "review fixup"
  run git stack restack --no-push
  assert_success
  assert_stderr_contains "fast-forwarded a to origin/a"
  assert_eq "$(git status --porcelain)" "" "worktree status"
  assert_eq "$(git rev-parse a)" "$(git rev-parse origin/a)" "a adopted origin/a"
}

test_restack_abort_after_manual_rebase_continue_leaves_clean_tree() {
  _make_conflict
  local b_before; b_before=$(git rev-parse b)
  run git stack restack --offline
  assert_failure
  echo "resolved" >shared.txt
  git add shared.txt
  GIT_EDITOR=true git rebase --continue >/dev/null 2>&1
  run git stack restack --abort
  assert_success
  assert_eq "$(git rev-parse b)" "$b_before" "b restored"
  assert_head b
  assert_eq "$(git status --porcelain)" "" "worktree status"
}
