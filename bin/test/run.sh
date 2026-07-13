#!/usr/bin/env bash
# run.sh — discover and run the git-stack test suite.
#
#   bash bin/test/run.sh                 # run every *.test.sh
#   bash bin/test/run.sh foo.test.sh …   # run only the named file(s)
#   FILTER=collapse bash bin/test/run.sh # run only tests whose name matches
#   KEEP_SANDBOX=1 …                     # leave each test's temp repo on disk
#
# Each `test_*` function in a file runs in its own subshell with a fresh sandbox
# (sandbox_init/cleanup). Optional per-file `setup`/`teardown` functions run
# inside that subshell around each test. Output is TAP-ish; exit is non-zero if
# any test failed.

set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/harness.bash
source "$HERE/lib/harness.bash"
# shellcheck source=lib/tty.bash
source "$HERE/lib/tty.bash"

# Files to run: explicit args (relative or absolute) or all *.test.sh.
declare -a FILES=()
if [[ $# -gt 0 ]]; then
  for a in "$@"; do
    [[ -f "$a" ]] && FILES+=("$a") || FILES+=("$HERE/$a")
  done
else
  for f in "$HERE"/*.test.sh; do FILES+=("$f"); done
fi

COUNT=$(mktemp); echo 0 >"$COUNT"
FAILS=$(mktemp)
trap 'rm -f "$COUNT" "$FAILS"' EXIT

run_one() { # file test
  local file="$1" test="$2" rc n
  (
    sandbox_init
    _TEST_FAILED=0
    if declare -F setup   >/dev/null 2>&1; then setup;   fi
    "$test"
    rc=$_TEST_FAILED
    if declare -F teardown >/dev/null 2>&1; then teardown; fi
    sandbox_cleanup
    exit "$rc"
  )
  rc=$?
  n=$(( $(cat "$COUNT") + 1 )); echo "$n" >"$COUNT"
  if [[ $rc -eq 0 ]]; then
    echo "ok $n - ${file##*/} :: $test"
  else
    echo "not ok $n - ${file##*/} :: $test"
    echo x >>"$FAILS"
  fi
}

for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || { echo "run.sh: no such file: $file" >&2; echo x >>"$FAILS"; continue; }
  (
    # shellcheck source=/dev/null
    source "$file"
    mapfile -t tests < <(declare -F | awk '{print $3}' | grep '^test_' | sort)
    for t in "${tests[@]}"; do
      [[ -n "${FILTER:-}" && "$t" != *"$FILTER"* ]] && continue
      run_one "$file" "$t"
    done
  )
done

total=$(cat "$COUNT")
failed=$(wc -l <"$FAILS" | tr -d ' ')
echo "1..$total"
echo "# $((total - failed)) passed, $failed failed"
[[ "$failed" -eq 0 ]]
