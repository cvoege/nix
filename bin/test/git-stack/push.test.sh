# push.test.sh — `git stack push` / `git stack pufl`

test_push_pushes_whole_stack_with_upstreams() {
  make_repo
  linear_stack a b c
  git checkout --quiet b              # from the middle: still pushes all of it
  run git stack push
  assert_success
  assert_synced a
  assert_synced b
  assert_synced c
  assert_eq "$(git rev-parse --abbrev-ref a@{upstream})" "origin/a" "a upstream set"
}

test_push_skips_other_stacks() {
  make_repo
  linear_stack a
  git checkout --quiet main
  linear_stack x
  git checkout --quiet a
  run git stack push
  assert_success
  assert_synced a
  git rev-parse --verify --quiet origin/x >/dev/null && _fail "x is in another stack; should not be pushed"
  return 0
}

test_push_rejects_rewritten_history() {
  make_repo
  linear_stack a
  git push --quiet -u origin a
  git commit --quiet --amend -m "rewritten"
  run git stack push
  assert_failure
}

test_pufl_force_pushes_rewritten_history() {
  make_repo
  linear_stack a b
  git push --quiet -u origin a b
  git checkout --quiet a
  git commit --quiet --amend -m "rewritten a"
  git checkout --quiet b
  git rebase --quiet --onto a a@{1} b
  run git stack pufl
  assert_success
  assert_synced a
  assert_synced b
}

test_pufl_lease_refuses_unseen_remote_work() {
  make_repo
  linear_stack a
  git push --quiet -u origin a
  git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/other" 2>/dev/null
  ( cd "$SANDBOX/other" && git checkout --quiet a && commit "someone else" && git push --quiet origin a )
  local remote; remote=$(git ls-remote origin refs/heads/a | cut -f1)
  git commit --quiet --amend -m "rewritten"
  run git stack pufl
  assert_failure
  assert_eq "$(git ls-remote origin refs/heads/a | cut -f1)" "$remote" "remote a untouched"
}

test_push_forwards_flags_to_git_push() {
  make_repo
  linear_stack a
  run git stack push --dry-run
  assert_success
  git ls-remote --exit-code origin refs/heads/a >/dev/null && _fail "--dry-run should not push"
  return 0
}

test_push_on_trunk_fails() {
  make_repo
  run git stack push
  assert_failure
  assert_stderr_contains "on trunk"
}
