# harness.bash — shared helpers for the git-stack test suite.
#
# Sourced by run.sh (once) before each test file. Provides:
#   * per-test sandbox isolation (throwaway git repos + isolated git identity)
#   * repo/stack builders (make_repo, commit, linear_stack)
#   * fake-gh fixture writers (gh_add_pr, gh_set_state, gh_add_comment)
#   * a bats-style `run` capturing status/output/stderr
#   * assertions that accumulate failures into $_TEST_FAILED
#
# Deliberately does NOT `set -e`: assertions accumulate rather than abort, and a
# test body keeps running so every failing assertion is reported at once.

# Repo root: this file lives at $REPO/bin/test/lib/harness.bash.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
export REPO

# ---- sandbox -------------------------------------------------------------

# Fresh temp repo area + isolated git config for a single test.
sandbox_init() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/gitstack-test.XXXXXX")
  export SANDBOX

  # Isolate git identity/config from the real machine. Parent pointers and
  # stack.trunk still live in each repo's own .git/config, exactly as in prod.
  export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  export HOME="$SANDBOX"
  git config --global user.name  "Test User"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  git config --global protocol.file.allow always   # local clone/push over file://

  # Fake gh (fixtures/) must shadow the real gh; $REPO/bin puts the real
  # git-stack on PATH so `git stack …` resolves to the code under test.
  export PATH="$REPO/bin/test/fixtures:$REPO/bin:$PATH"

  # Fixture databases the fake gh reads (see fixtures/gh).
  export GH_PR_DB="$SANDBOX/gh-prs.tsv"
  export GH_COMMENTS_DB="$SANDBOX/gh-comments.tsv"
  export GH_COMMENT_LOG="$SANDBOX/gh-comment-log.tsv"
  export GH_GRAPHQL_LOG="$SANDBOX/gh-graphql-log.tsv"
  : >"$GH_PR_DB"; : >"$GH_COMMENTS_DB"; : >"$GH_COMMENT_LOG"; : >"$GH_GRAPHQL_LOG"

  _COMMIT_N=0
}

sandbox_cleanup() {
  if [[ "${KEEP_SANDBOX:-0}" == 1 ]]; then
    echo "    (kept sandbox: $SANDBOX)" >&2
  else
    rm -rf "$SANDBOX"
  fi
}

# ---- repo / stack builders ----------------------------------------------

# Standard starting point: a bare "origin" + a working clone on `main` with one
# commit pushed, origin/HEAD set. Leaves you cd'd into the working clone.
make_repo() {
  git init --quiet --bare "$SANDBOX/origin.git"
  git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/work" 2>/dev/null
  cd "$SANDBOX/work" || return 1
  git symbolic-ref HEAD refs/heads/main
  echo root >README.md
  git add README.md
  git commit --quiet -m "initial commit"
  git push --quiet -u origin main
  git remote set-head origin main
}

# One commit on the current branch. Writes to a per-branch file by default so
# sibling branches touch different paths (rebases stay conflict-free); pass an
# explicit file to force a conflict.
commit() {
  local msg="${1:-c}" branch file
  branch=$(git symbolic-ref --quiet --short HEAD || echo detached)
  file="${2:-$branch.txt}"
  _COMMIT_N=$((_COMMIT_N + 1))
  echo "$msg ($_COMMIT_N)" >>"$file"
  git add "$file"
  git commit --quiet -m "$msg"
}

# Build a linear stack off the current branch: `linear_stack a b c` yields
# trunk <- a <- b <- c, one commit each, leaving you on the leaf.
linear_stack() {
  local b
  for b in "$@"; do
    git stack new "$b" >/dev/null 2>&1 || { echo "linear_stack: 'git stack new $b' failed" >&2; return 1; }
    commit "work on $b"
  done
}

# ---- fake-gh fixture writers --------------------------------------------
# Rows are TAB-separated; see fixtures/gh for the column layout.

# gh_add_pr <branch> <base> [state=OPEN] [number] [additions] [deletions] [title]
gh_add_pr() {
  local branch="$1" base="$2" state="${3:-OPEN}" num="${4:-100}" \
        add="${5:-1}" del="${6:-0}" title="${7:-PR for $1}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$branch" "$base" "$state" "$num" "$add" "$del" "$title" >>"$GH_PR_DB"
}

gh_set_state() { # branch newstate
  local tmp="$GH_PR_DB.tmp"
  awk -F'\t' -v b="$1" -v s="$2" 'BEGIN{OFS="\t"} $1==b{$3=s} {print}' \
    "$GH_PR_DB" >"$tmp" && mv "$tmp" "$GH_PR_DB"
}

gh_add_comment() { # branch id [author=claude]
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-claude}" >>"$GH_COMMENTS_DB"
}

# ---- run + assertions ----------------------------------------------------

# run <cmd...> — capture into $status / $output / $stderr. Never aborts.
run() {
  local _o _e
  _o=$(mktemp); _e=$(mktemp)
  "$@" >"$_o" 2>"$_e"
  status=$?
  output=$(cat "$_o"); stderr=$(cat "$_e")
  rm -f "$_o" "$_e"
  return 0
}

_fail() {
  _TEST_FAILED=1
  echo "    ✗ ${FUNCNAME[1]}: $*" >&2
}

_dump_output() {
  echo "      --- stdout ---" >&2; printf '%s\n' "$output" | sed 's/^/      /' >&2
  echo "      --- stderr ---" >&2; printf '%s\n' "$stderr" | sed 's/^/      /' >&2
}

assert_success() {
  [[ "$status" -eq 0 ]] || { _fail "expected success, got status $status"; _dump_output; }
}
assert_failure() {
  [[ "$status" -ne 0 ]] || { _fail "expected failure, got status 0"; _dump_output; }
}
assert_status() {
  [[ "$status" -eq "$1" ]] || { _fail "expected status $1, got $status"; _dump_output; }
}

assert_output_contains() {
  case "$output" in *"$1"*) ;; *) _fail "stdout missing: '$1'"; _dump_output ;; esac
}
assert_output_not_contains() {
  case "$output" in *"$1"*) _fail "stdout should not contain: '$1'"; _dump_output ;; esac
}
assert_stderr_contains() {
  case "$stderr" in *"$1"*) ;; *) _fail "stderr missing: '$1'"; _dump_output ;; esac
}

assert_eq() {
  [[ "$1" == "$2" ]] || _fail "${3:-values differ}: expected '$2', got '$1'"
}

assert_parent() { # branch expected
  local got; got=$(git config --get "branch.$1.stackParent" 2>/dev/null || true)
  [[ "$got" == "$2" ]] || _fail "parent of '$1': expected '$2', got '$got'"
}
assert_no_parent() { # branch
  local got; got=$(git config --get "branch.$1.stackParent" 2>/dev/null || true)
  [[ -z "$got" ]] || _fail "'$1' should have no parent, got '$got'"
}

assert_branch()    { git show-ref --verify --quiet "refs/heads/$1" || _fail "branch '$1' should exist"; }
assert_no_branch() { git show-ref --verify --quiet "refs/heads/$1" && _fail "branch '$1' should not exist"; return 0; }
assert_head()      { local h; h=$(git symbolic-ref --quiet --short HEAD || echo detached); [[ "$h" == "$1" ]] || _fail "HEAD: expected '$1', got '$h'"; }

# Local branch tip equals its origin counterpart (pushed & up to date).
assert_synced() {
  local l r; l=$(git rev-parse --verify --quiet "$1^{commit}"); r=$(git rev-parse --verify --quiet "origin/$1^{commit}" 2>/dev/null || true)
  [[ -n "$r" && "$l" == "$r" ]] || _fail "'$1' not synced with origin/$1 (local=$l origin=${r:-<none>})"
}

# Number of commits in <upstream>..<branch>.
assert_commit_count() { # branch upstream expected
  local n; n=$(git rev-list --count "$2..$1" 2>/dev/null || echo -1)
  [[ "$n" -eq "$3" ]] || _fail "commit count $2..$1: expected $3, got $n"
}

# No merge commits in <upstream>..<branch> (history is linear).
assert_linear() { # branch upstream
  local m; m=$(git rev-list --merges --count "$2..$1" 2>/dev/null || echo -1)
  [[ "$m" -eq 0 ]] || _fail "history $2..$1 is not linear ($m merge commit(s))"
}

# A restack state file exists / is gone.
assert_restack_in_progress()  { [[ -f "$(git rev-parse --git-dir)/stack-restack-state" ]] || _fail "expected a restack in progress"; }
assert_no_restack_in_progress() { [[ ! -f "$(git rev-parse --git-dir)/stack-restack-state" ]] || _fail "restack state should be cleared"; }
