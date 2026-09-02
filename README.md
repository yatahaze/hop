# hop

A bookmark list for the places you work — repos, app checkouts, tool configs —
that runs anywhere you have a terminal. Type to filter, arrow to pick, enter to
land there.

```
hop > web
  repos/   webapp          ~/src/webapp        ┌────────────────────────┐
▌ repos/   webapp-docs     ~/src/webapp-docs   │ ~/src/webapp           │
  configs/ webserver       /etc/nginx          │ ## main...origin/main  │
                                               │  M src/settings.py     │
  enter hop · ctrl-a claude · ctrl-e edit      │ 3f9a1c2 fix pagination │
  ctrl-u pull · ctrl-p push                    └────────────────────────┘
```

Needs `bash` and `fzf`. Nothing else — no runtime, no build, works over SSH
on an old server as well as on the desktop.

## Install

```bash
git clone <repo> ~/hop && ~/hop/install.sh
```

That symlinks `~/bin/hop`, seeds `~/.config/hop/bookmarks`, and adds a shell
wrapper to `.bashrc` and fish. The wrapper matters: a program can't change its
parent shell's directory, so `hop` the script *prints* a directory and `hop`
the shell function `cd`s to it.

## Bookmarks

Bookmarks **merge** from every source that exists, in order:

| Source | Owner |
|---|---|
| `/etc/hop/bookmarks` | local admin |
| `/etc/hop/bookmarks.d/*.conf` | config management (fleet defaults) |
| `~/.config/hop/bookmarks` | you |
| `~/.config/hop/bookmarks.d/*.conf` | you |

```ini
[repos]
webapp          ~/src/webapp

[configs]
claude          ~/.claude
~/.bashrc                       # name defaults to the basename
```

`~` and `$HOME` expand; nothing else does — the files are parsed, never
`eval`d. `hop --edit` opens *your* file; you only list what is yours, because
the fleet entries are still merged in. Repeating a category/name from an
earlier source overrides that one entry and leaves the rest alone.
`HOP_CONFIG=<file>` bypasses the whole stack.

Because the same list is meant to serve every machine, bookmarks whose path
doesn't exist here are hidden and counted in the header. `hop --all` shows
them.

## Keys

| Key | Does |
|---|---|
| type | filter — the category matches too, so `conf` narrows to `configs/` |
| `enter` | hop there |
| `ctrl-a` | run `claude` there, then land there |
| `ctrl-e` | open in `$EDITOR` |
| `ctrl-u` / `ctrl-p` | `git pull` / `git push` |

`hop web` starts with `web` already typed. A bookmark pointing at a file hops to
its directory (and `ctrl-e` opens the file itself).

## Fleet install

`install.sh` is the single-user path (`~/bin`, your shell rc). For many
machines, a configuration-management state that drops `/usr/local/bin/hop`,
the profile.d wrapper and a `/etc/hop/bookmarks.d/*.conf` file on each host
gives you the same thing everywhere, updated in one push. The merge order
above is what makes that safe to combine with a personal list.

## Roadmap

Windows support and auto-discovery: see [ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).
