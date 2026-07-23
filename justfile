# Task runner for this home-manager config. Run `just` to list targets.

# Run the test suite. With no args runs everything; pass files or dirs to
# scope it, e.g. `just test collapse.test.sh` or `just test bin/test/stack`.
test *ARGS:
    bash bin/test/run.sh {{ARGS}}

# Lint the shell scripts. The harness must be clean (SC1091 = dynamically
# sourced libs, unavoidable). git-stack/install.sh are advisory-only (they carry
# a few intentional bash idioms shellcheck flags) so they never block the target.
lint:
    shellcheck -x -e SC1091 bin/test/run.sh bin/test/lib/*.bash bin/test/fixtures/gh
    -shellcheck -x bin/git-stack bin/install.sh
