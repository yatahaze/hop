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
replaces the block rather than appending a second copy, and it bakes the
script's absolute path into the function rather than looking it up on `PATH`.

That last part matters more than it sounds. Debian and Ubuntu put `~/bin` on
`PATH` from `~/.profile`, guarded on the directory existing **at login** — so
right after a fresh install `~/bin` is not on `PATH` in the shell you
installed from, and `source ~/.bashrc` does not re-read `.profile`. Calling
the script directly sidesteps every distro's `PATH` convention.

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

## Windows

Needs PowerShell 7 and `fzf`. From PowerShell:

```powershell
git clone https://github.com/yatahaze/hop.git $HOME\hop; & $HOME\hop\install.ps1
```

`install.ps1`:

- installs `fzf` with winget if it is not on `PATH`
- seeds `%APPDATA%\hop\bookmarks` if you have none
- adds an `Import-Module` line for `hop.psm1` to your `$PROFILE`, between
  `# >>> hop >>>` markers so re-running replaces it

Open a new PowerShell, run `hop`.

There is no print-a-path dance on Windows. A PowerShell function runs in the
caller's session and can call `Set-Location` and dot-source a virtualenv's
`Scripts\Activate.ps1` directly, so `hop.psm1` is the whole program and
nothing goes on `PATH`. The module is imported by absolute path, so it does
not depend on `PSModulePath` either.

Same bookmarks format, same merge order, with `%ProgramData%\hop` standing in
for `/etc/hop` and `%APPDATA%\hop` for `~/.config/hop`. Paths may use `/` or
`\`. `~` and `$HOME` expand to your user directory.

Not ported: the category column, `alt-N` and `^t` pinning. All three work
by fzf re-invoking the script on every keypress, and starting `pwsh` costs a
few hundred milliseconds each time. The category is a filterable prefix
instead, so `hop web` and typing `conf` still narrow. `*` in the file still
pins. `tab` does work: the lists it switches between are written to temp
files before fzf starts and a batch file cycles them, so no `pwsh` sits under
the key. The preview pane is there (`^o`), driven by `git` and `ssh -G`
through `cmd.exe` so it stays quick.

Hosts come from `%USERPROFILE%\.ssh\config` as on Linux, and
`hop --ssh-import` reads the clipboard with `Get-Clipboard`. See
[SSH hosts](ssh.md).

## Uninstall

```bash
rm -f ~/bin/hop                 # or: sudo rm -f /usr/local/bin/hop
```

Remove the `hop()` block from `~/.bashrc` and delete
`~/.config/fish/functions/hop.fish`. Bookmarks in `~/.config/hop/` are left
alone; delete that directory too if you want them gone.

On Windows, remove the `# >>> hop >>>` block from `$PROFILE` and delete the
clone. Bookmarks in `%APPDATA%\hop` are left alone.
