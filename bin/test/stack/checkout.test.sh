# checkout.test.sh — interactive `git stack checkout`, driven via a PTY (expect).

test_checkout_selects_existing_branch() {
  make_repo
  linear_stack a b c                 # menu order: a, b, c (+ new-branch entry)
  git checkout --quiet a             # highlight starts on a (index 0)
  menu_checkout_down 1               # move to b, Enter
  assert_success
  assert_head b
}

test_checkout_creates_new_branch_on_leaf() {
  make_repo
  linear_stack a b                   # leaf is b
  menu_checkout_new d
  assert_success
  assert_branch d
  assert_parent d b
  assert_head d
}

test_checkout_cancel_leaves_head_unchanged() {
  make_repo
  linear_stack a b
  git checkout --quiet a
  menu_checkout_cancel
  assert_failure                     # cancelling returns non-zero
  assert_head a
}

test_checkout_errors_on_trunk() {
  make_repo                          # on main — dies before reaching the menu
  run git stack checkout
  assert_failure
  assert_stderr_contains "you're on trunk"
}
