# tty.bash — expect-based drivers for git-stack's interactive `checkout` menu.
# Requires `expect` (present on the system). Each helper runs under `run`, so
# afterwards $status/$output are set and you can assert on the resulting HEAD.

_MENU_EXP="$REPO/bin/test/fixtures/menu.exp"

# Move the selection down <n> entries from the current-branch highlight, Enter.
menu_checkout_down() { run expect "$_MENU_EXP" down "${1:-0}"; }

# Select the trailing "＋ new branch" entry and type <name> at the prompt.
menu_checkout_new() { run expect "$_MENU_EXP" new "$1"; }

# Cancel the menu with `q` (expected to exit non-zero, HEAD unchanged).
menu_checkout_cancel() { run expect "$_MENU_EXP" cancel; }
