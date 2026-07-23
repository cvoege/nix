# infer.test.sh — `git stack infer [--dry-run]` (rebuild parents from PR bases)

# Build a linear chain of *untracked* branches (no stackParent config) pushed to
# origin, with PRs describing the base graph. infer should recover the parents.
_make_pr_chain() {
  make_repo
  git checkout --quiet -b a main; commit "a"
  git checkout --quiet -b b a;    commit "b"
  git checkout --quiet -b c b;    commit "c"
  git push --quiet -u origin a b c
  gh_add_pr a main OPEN
  gh_add_pr b a    OPEN
  gh_add_pr c b    OPEN
}

test_infer_records_parents_from_pr_bases() {
  _make_pr_chain
  git checkout --quiet b
  run git stack infer
  assert_success
  assert_parent a main
  assert_parent b a
  assert_parent c b
}

test_infer_fetches_missing_branch_from_origin() {
  _make_pr_chain
  git checkout --quiet b
  git branch -D c                    # gone locally, still on origin + has a PR
  run git stack infer
  assert_success
  assert_branch c                    # recreated from origin/c
  assert_parent c b
}

test_infer_dry_run_records_nothing() {
  _make_pr_chain
  git checkout --quiet b
  run git stack infer --dry-run
  assert_success
  assert_stderr_contains "dry run"
  assert_no_parent a                 # nothing written
  assert_no_parent b
}

test_infer_errors_without_pr() {
  make_repo
  git checkout --quiet -b lonely main   # no PR in the fixture db
  run git stack infer
  assert_failure
  assert_stderr_contains "no open PR found"
}
