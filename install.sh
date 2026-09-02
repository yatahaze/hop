#!/usr/bin/env bash
# Installs hop: a symlink on PATH, a seed bookmarks file, and the shell
# wrapper that lets `hop` change your current shell's directory.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hop"

command -v fzf >/dev/null || { echo "hop needs fzf on PATH" >&2; exit 1; }

mkdir -p "$HOME/bin" "$CONFIG_DIR"
ln -sf "$SRC/hop" "$HOME/bin/hop"
echo "linked ~/bin/hop -> $SRC/hop"

if [ ! -f "$CONFIG_DIR/bookmarks" ]; then
  cp "$SRC/bookmarks.example" "$CONFIG_DIR/bookmarks"
  echo "seeded $CONFIG_DIR/bookmarks"
else
  echo "kept existing $CONFIG_DIR/bookmarks"
fi

# A child process cannot cd its parent shell, so `hop` must be a function that
# cds to whatever the script prints. Both shells get the same contract.
add_bash() {
  local rc="$HOME/.bashrc"
  grep -q 'hop shell wrapper' "$rc" 2>/dev/null && { echo "bash wrapper already in $rc"; return; }
  cat >> "$rc" <<'WRAP'

# hop shell wrapper — the script prints a directory, we cd to it
hop() {
  local d
  d="$(command hop "$@")" || return $?
  [ -n "$d" ] && cd "$d"
}
WRAP
  echo "added bash wrapper to $rc"
}

add_fish() {
  local d="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions"
  [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/fish" ] || return
  mkdir -p "$d"
  cat > "$d/hop.fish" <<'WRAP'
# hop shell wrapper — the script prints a directory, we cd to it
function hop
    set -l d (command hop $argv); or return $status
    test -n "$d"; and cd $d
end
WRAP
  echo "wrote $d/hop.fish"
}

add_bash
add_fish

echo
echo "done — open a new shell (or: source ~/.bashrc) and run: hop"
