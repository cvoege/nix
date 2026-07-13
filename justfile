# Task runner for this home-manager config. Run `just` to list targets.

# Run the full git-stack test suite.
test:
    bash bin/test/run.sh

# Run one (or more) test files, e.g. `just test-one collapse.test.sh`.
test-one +FILES:
    bash bin/test/run.sh {{FILES}}

# Lint the shell scripts. The harness must be clean (SC1091 = dynamically
# sourced libs, unavoidable). git-stack/install.sh are advisory-only (they carry
# a few intentional bash idioms shellcheck flags) so they never block the target.
lint:
    shellcheck -x -e SC1091 bin/test/run.sh bin/test/lib/*.bash bin/test/fixtures/gh
    -shellcheck -x bin/git-stack bin/install.sh
