#!/usr/bin/env bash
# install.sh — install the `git stack` utility for non-Nix users.
#
# Symlinks git-stack (and its lib) into a directory on your PATH so git picks it
# up as the `git stack` subcommand. Nix/home-manager users don't need this —
# home.nix already wires the scripts into ~/.bin.
#
#   ./install.sh                 # install into ~/.local/bin
#   BINDIR=~/bin ./install.sh    # install somewhere else
#
# Re-running is safe; it refreshes the symlinks.

set -euo pipefail

SRC_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR="${BINDIR:-$HOME/.local/bin}"

# ---- dependency check ----------------------------------------------------
missing=()
for dep in git gh jq; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "warning: missing required tool(s): ${missing[*]}" >&2
  echo "         git stack needs: git, gh (GitHub CLI), jq" >&2
  echo "         install them, then re-run, or proceed anyway." >&2
fi

# ---- link the scripts ----------------------------------------------------
mkdir -p "$BINDIR"
for f in git-stack; do
  ln -sf "$SRC_DIR/$f" "$BINDIR/$f"
  echo "linked $BINDIR/$f -> $SRC_DIR/$f"
done

# ---- PATH guidance -------------------------------------------------------
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    echo
    echo "note: $BINDIR is not on your PATH. Add this to your shell rc:"
    echo "      export PATH=\"$BINDIR:\$PATH\""
    ;;
esac

echo
echo "Done. Try: git stack --help"
echo "Optional shell aliases:"
echo "      alias gstk='git stack'"
echo "      alias restack='git stack restack'"
