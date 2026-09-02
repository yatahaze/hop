# Install

Needs `bash` and [`fzf`](https://github.com/junegunn/fzf).

## One machine

```bash
git clone https://github.com/yatahaze/hop.git ~/hop && ~/hop/install.sh
```

`install.sh`:

- symlinks `~/bin/hop`
- seeds `~/.config/hop/bookmarks` if you have none
- adds the shell function to `~/.bashrc`, and to fish if you use it

Open a new shell, run `hop`.

## Why a shell function

A program cannot change its parent shell's directory, nor activate a
virtualenv in it. So `hop` prints the directory on line 1 and, when it finds
one, a virtualenv activate script on line 2, and the function does both:

```bash
hop() {
  local out d v
  out="$(HOP_WRAPPED=1 command hop "$@")" || return $?
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
```

`install.sh` writes this between `# >>> hop >>>` markers, so re-running it
replaces the block rather than appending a second copy.

Every action the picker runs (editor, git, an agent) writes to `/dev/tty`
instead of stdout, so it never breaks that.

Install `hop` on `PATH` without the function and it will print a path and
leave you where you were. It notices, and says so on stderr, rather than
looking silently broken.

## By hand

```bash
sudo install -m755 hop /usr/local/bin/hop
```

Then put the function above in `/etc/profile.d/hop.sh` (system wide) or your
shell rc. For fish, use `~/.config/fish/functions/hop.fish`:

```fish
function hop
    set -l out (env HOP_WRAPPED=1 command hop $argv); or return $status
    test (count $out) -gt 0; or return 0
    cd $out[1]; or return $status
    if test (count $out) -ge 2
        set -l af (dirname $out[2])/activate.fish
        if set -q VIRTUAL_ENV; and functions -q deactivate
            deactivate
        end
        test -r $af; and source $af
    end
end
```

## Uninstall

```bash
rm -f ~/bin/hop                 # or: sudo rm -f /usr/local/bin/hop
```

Remove the `hop()` block from `~/.bashrc` and delete
`~/.config/fish/functions/hop.fish`. Bookmarks in `~/.config/hop/` are left
alone; delete that directory too if you want them gone.
