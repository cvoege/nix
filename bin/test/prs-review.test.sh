# prs-review.test.sh — `git stack prs`, `prs list`, and `review [single]`

test_prs_tree_labels_with_pr_info() {
  make_repo
  linear_stack a b
  gh_add_pr a main OPEN 5 10 2 "Feat A"
  gh_add_pr b a    OPEN 6 3  1 "Feat B"
  git checkout --quiet b
  run git stack prs
  assert_success
  assert_output_contains "PR 5"
  assert_output_contains "Feat A"
}

test_prs_tree_falls_back_for_no_pr() {
  make_repo
  linear_stack a b                   # no PRs recorded
  run git stack prs
  assert_success
  assert_output_contains "no PR"
}

test_prs_list_flat_format() {
  make_repo
  linear_stack a b
  gh_add_pr a main OPEN 5 10 2 "Feat A"
  gh_add_pr b a    OPEN 6 3  1 "Feat B"
  git checkout --quiet b
  run git stack prs list
  assert_success
  assert_output_contains "trunk: main"
  assert_output_contains "PR #5"
  assert_output_contains "[current]"
}

test_review_hides_comments_and_requests_fresh() {
  make_repo
  linear_stack a b
  gh_add_pr a main OPEN
  gh_add_pr b a    OPEN
  gh_add_comment a 111 claude
  gh_add_comment a 222 claude
  git checkout --quiet b
  run git stack review
  assert_success
  # both stale claude comments hidden (graphql), fresh review posted to a and b
  assert_stderr_contains "hid 2 stale"
  grep -q "111" "$GH_GRAPHQL_LOG" || _fail "comment 111 not minimized"
  grep -q "222" "$GH_GRAPHQL_LOG" || _fail "comment 222 not minimized"
  grep -qP '^a\t@claude review once' "$GH_COMMENT_LOG" || _fail "no review trigger on a"
  grep -qP '^b\t@claude review once' "$GH_COMMENT_LOG" || _fail "no review trigger on b"
}

test_review_single_only_current_branch() {
  make_repo
  linear_stack a b
  gh_add_pr a main OPEN
  gh_add_pr b a    OPEN
  git checkout --quiet b
  run git stack review single
  assert_success
  grep -qP '^b\t' "$GH_COMMENT_LOG"  || _fail "no review trigger on current branch"
  grep -qP '^a\t' "$GH_COMMENT_LOG"  && _fail "review single should not touch a"
  return 0
}

test_review_skips_branch_without_pr() {
  make_repo
  linear_stack a b
  gh_add_pr a main OPEN              # b has no PR
  git checkout --quiet b
  run git stack review
  assert_success
  assert_stderr_contains "skip b"
  grep -qP '^b\t' "$GH_COMMENT_LOG" && _fail "should not comment on PR-less b"
  return 0
}
