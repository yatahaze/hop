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

A program cannot change its parent shell's directory. So `hop` prints a
directory and nothing else, and the function `cd`s to what it printed:

```bash
hop() {
  local d
  d="$(command hop "$@")" || return $?
  [ -n "$d" ] && cd "$d"
}
```

Every action the picker runs (editor, git, an agent) writes to `/dev/tty`
instead of stdout, so it never breaks that.

Install `hop` on `PATH` without the function and it will print a path and
leave you where you were.

## By hand

```bash
sudo install -m755 hop /usr/local/bin/hop
```

Then put the function above in `/etc/profile.d/hop.sh` (system wide) or your
shell rc. For fish, use `~/.config/fish/functions/hop.fish`:

```fish
function hop
    set -l d (command hop $argv); or return $status
    test -n "$d"; and cd $d
end
```

## Many machines

With config management (salt, ansible, chef), install per host:

| Path | What |
|---|---|
| `/usr/local/bin/hop` | the script, mode 0755 |
| `/etc/profile.d/hop.sh` | the shell function |
| `/etc/fish/conf.d/hop.fish` | same, where fish exists |
| `/etc/hop/bookmarks.d/00-fleet.conf` | your shared bookmark list |
| package `fzf` | the picker |

Ship the shared list as a drop-in under `bookmarks.d/`, not as
`/etc/hop/bookmarks`. Bookmarks merge, so a drop-in leaves both
`/etc/hop/bookmarks` free for a local admin and `~/.config/hop/` free for each
user, and neither fights your tooling. See [Bookmarks](bookmarks.md).

Updating every host is then one push of the shared list plus one apply.

Windows hosts have no `/usr/local/bin` or `/etc/profile.d`, so exclude them.
See the [roadmap](../ROADMAP.md).

## Uninstall

```bash
rm -f ~/bin/hop                 # or: sudo rm -f /usr/local/bin/hop
```

Remove the `hop()` block from `~/.bashrc` and delete
`~/.config/fish/functions/hop.fish`. Bookmarks in `~/.config/hop/` are left
alone; delete that directory too if you want them gone.
