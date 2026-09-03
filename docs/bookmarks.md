# Bookmarks

## Format

```ini
[repos]
webapp          ~/src/webapp
api             ~/src/api

[configs]
webserver       /etc/nginx
~/.bashrc                       # name defaults to the basename
```

A `[category]` header, then one bookmark per line: a name and a path, or just
a path. `~` and `$HOME` expand. Nothing else does, because the files are
parsed, never `eval`d.

Categories are just a filter prefix. Typing `conf` narrows to `configs/`.
Invent whatever ones you want.

Hosts from your ssh config appear alongside, under `ssh/` categories, without
being listed here. See [SSH hosts](ssh.md).

Press `^t` in the picker to pin or unpin whatever is selected. It takes effect
immediately and survives restarts, kept in `~/.config/hop/pins` as a
category/name pair rather than a copy of the entry, so a pin never goes stale
when you edit the path.

You can also pin in the file itself, by prefixing a name with `*`:

```ini
[repos]
*webapp         ~/src/webapp
api             ~/src/api
```

Pinned entries sort first and keep their category. Because a later source
overrides an earlier one, a personal file can pin something a system file
defined, by repeating it with a `*`.

`^t` wins over both: it can unpin something a file pinned with `*`, including
a file you have no write access to.

A bookmark can point at a file. `go` takes you to its directory, `edit`
opens the file.

## Where lists live

Every file that exists is read, in this order:

| Source | Owner |
|---|---|
| `/etc/hop/bookmarks` | system wide |
| `/etc/hop/bookmarks.d/*.conf` | system wide, drop-ins |
| `~/.config/hop/bookmarks` | you |
| `~/.config/hop/bookmarks.d/*.conf` | you |

On Windows the same four, with `%ProgramData%\hop\` in place of `/etc/hop/`
and `%APPDATA%\hop\` in place of `~/.config/hop/`.

`hop --edit` opens your own file, creating it if needed.
`HOP_CONFIG=<file> hop` ignores all of them and reads just that file.

## How they merge

They combine rather than replace. You list only what is yours and still get
everything from the files above.

Repeating a category and name from an earlier source overrides that one entry,
in place, and leaves the rest alone. So a system wide list can define
`repos/webapp` and you can point it somewhere else without losing the other
fifty entries.

Without this, creating a personal file would hide the system one completely.

## Virtualenvs

Hopping to a bookmark activates a virtualenv if one is found, and deactivates
whatever was active first, so switching projects switches interpreters.

The search starts at the bookmark's directory and walks up, stopping at
`$HOME`. In each directory it looks for `venv/`, `.venv/`, then `env/`.
Nearest wins, which matters when a repo has its own `.venv` inside a tree that
also has one beside it.

```
~/src/webapp/.venv/bin/activate     <- bookmark ~/src/webapp uses this
~/src/venv/bin/activate                (not this)
```

Nothing to configure, and no venv means no activation. The preview pane names
the venv that would activate. On Windows the same search looks for
`Scripts\Activate.ps1` instead of `bin/activate`.

## Paths that do not exist

Hidden, and counted in the header:

```
enter · ^t pin
3 not here (--all)
```

`hop --all` shows them.

One list can therefore serve machines with different layouts.

## Settings

Optional, in `/etc/hop/config` then `~/.config/hop/config`, later file winning
— the same system-then-user shape as bookmarks. `key = value`, `#` comments.
Every key has a working default, so no file is fine. See
[config.example](../config.example).

| Key | Values | Does |
|---|---|---|
| `ssh_config` | a path, `off` | where hosts come from; default `~/.ssh/config` |
| `minimal` | `on`, `off` | strip the chrome: no hints, no counter |
| `column` | `off`, `auto`, `on` | the category column; off by default, `auto` fits it to the terminal |
| `header` | `on`, `off` | the section strip and key hints |
| `actions` | action names | the menu for a directory, in order; default `cd claude edit pull push` |
| `ssh_actions` | action names | the menu for a host, in order; default `ssh claude edit` |

`minimal = on` is shorthand for `header = off`, so it is a default rather
than a lock: set `header = on` alongside it and the hints come back.

With the column off the header strip still names the sections and
categories, as tabs with the active one lit, so you can see where you are
and what `tab` and `alt-1` will do. `minimal = on` drops that too — it
assumes you know.

## Keys

| Key | Does |
|---|---|
| `tab` / `shift-tab` | all, then bookmarks, then ssh hosts, lit in the strip; with only one kind, walks the categories instead |
| `alt-1`..`alt-9` | jump straight to a category (numbers shown in the column and the strip) |
| `^o` | show or hide the category column |
| type | filter, category names match too |
| `enter` | open the actions for the entry |
| `^t` | pin or unpin the selected entry |

`hop web` starts with `web` already typed.

## Actions

`enter` opens a small menu in the middle of the screen. The first row is the
default, so `enter` twice takes you there; `escape` goes back to the list.
Typing filters it like any other fzf list.

| Action | Directory | Host |
|---|---|---|
| `cd` / `ssh` | cd there, activating a virtualenv if one is found | `ssh <alias>` |
| `claude` | run `claude` there, then land there | connect and run `claude` on the far side |
| `edit` | open in `$EDITOR`, then land there | open the ssh config |
| `pull` | `git pull`, then land there | |
| `push` | `git push`, then land there | |

`pull` and `push` only appear for a git repository.

The `actions` and `ssh_actions` settings are the menus, in order, so the one
you reach for most can go first and the ones you never use can go:

```
actions = claude cd edit
```

puts `claude` on the first `enter` and drops `pull` and `push`.

On Windows, `^o` toggles the preview instead of the column, and `alt-1` and
`^t` do nothing; the `column` setting is ignored. See
[Install](install.md#windows) for why.
