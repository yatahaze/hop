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

# A child process cannot cd its parent shell, nor activate a virtualenv in it,
# so both have to happen out here. hop prints the directory on line 1 and an
# optional virtualenv activate script on line 2.
#
# Delimited so re-running this replaces the block instead of appending a second
# copy, and so removing it is a clean sed.
add_bash() {
  local rc="$HOME/.bashrc" tmp
  if grep -q '^# >>> hop >>>' "$rc" 2>/dev/null; then
    tmp="$(mktemp)"
    sed '/^# >>> hop >>>$/,/^# <<< hop <<<$/d' "$rc" > "$tmp" && cat "$tmp" > "$rc" && rm -f "$tmp"
    echo "replaced existing bash wrapper in $rc"
  else
    # tidy up the pre-marker wrapper shipped by earlier versions
    if grep -q '^# hop shell wrapper' "$rc" 2>/dev/null; then
      tmp="$(mktemp)"
      sed '/^# hop shell wrapper/,/^}$/d' "$rc" > "$tmp" && cat "$tmp" > "$rc" && rm -f "$tmp"
      echo "removed pre-marker wrapper from $rc"
    fi
    echo "added bash wrapper to $rc"
  fi
  # The script is called by absolute path, not through PATH. ~/bin reaches PATH
  # via ~/.profile on Debian, guarded on the directory existing at LOGIN, so a
  # fresh install is not on PATH in the session that ran it -- and sourcing
  # .bashrc does not re-read .profile. Baking the path in sidesteps every
  # distro's PATH convention.
  local blk; blk="$(mktemp)"
  cat > "$blk" <<'WRAP'
# >>> hop >>>
hop() {
  local out d v
  out="$(HOP_WRAPPED=1 @HOP_BIN@ "$@")" || return $?
  [ -n "$out" ] || return 0
  d="${out%%$'\n'*}"
  v="${out#*$'\n'}"; [ "$v" = "$out" ] && v=""
  [ -n "$d" ] || return 0
  cd "$d" || return $?
  if [ -n "$v" ] && [ -r "$v" ]; then
    if [ -n "${VIRTUAL_ENV:-}" ] && command -v deactivate >/dev/null 2>&1; then deactivate; fi
    . "$v"
  fi
}
# <<< hop <<<
WRAP
  sed -i "s|@HOP_BIN@|$SRC/hop|" "$blk"
  cat "$blk" >> "$rc"
  rm -f "$blk"
}

add_fish() {
  local d="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions"
  [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/fish" ] || return 0
  mkdir -p "$d"
  cat > "$d/hop.fish" <<'WRAP'
function hop
    set -l out (env HOP_WRAPPED=1 @HOP_BIN@ $argv); or return $status
    test (count $out) -gt 0; or return 0
    cd $out[1]; or return $status
    if test (count $out) -ge 2
        # fish needs its own activate script, not the POSIX one
        set -l af (dirname $out[2])/activate.fish
        if set -q VIRTUAL_ENV; and functions -q deactivate
            deactivate
        end
        test -r $af; and source $af
    end
end
WRAP
  sed -i "s|@HOP_BIN@|$SRC/hop|" "$d/hop.fish"
  echo "wrote $d/hop.fish"
}

add_bash
add_fish

case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) echo
     echo "note: ~/bin is not on your PATH, so the bare \`hop\` command (e.g."
     echo "      \`hop --list\`) will not resolve until your next login. The"
     echo "      shell function works regardless -- it calls the script directly." ;;
esac

echo
echo "done. Open a new shell (or: source ~/.bashrc) and run: hop"
