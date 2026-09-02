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

A bookmark can point at a file. `enter` takes you to its directory, `ctrl-e`
opens the file.

## Where lists live

Every file that exists is read, in this order:

| Source | Owner |
|---|---|
| `/etc/hop/bookmarks` | system wide |
| `/etc/hop/bookmarks.d/*.conf` | system wide, drop-ins |
| `~/.config/hop/bookmarks` | you |
| `~/.config/hop/bookmarks.d/*.conf` | you |

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
the venv that would activate.

## Paths that do not exist

Hidden, and counted in the header:

```
enter hop · ctrl-a claude · ctrl-e edit · 3 not on this machine (--all)
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
| `minimal` | `on`, `off` | strip the chrome: no column, no hints, no counter |
| `column` | `auto`, `on`, `off` | the category column; `auto` fits it to the terminal |
| `header` | `on`, `off` | the category strip and key hints |

`minimal = on` is shorthand for the other two off, so it is a default rather
than a lock: set `column = on` alongside it and the column comes back.

`column = off` still shows the hotkey strip, so you can see what `tab` and
`alt-1` will do. `minimal = on` does not — it assumes you know.

## Keys

| Key | Does |
|---|---|
| `tab` / `shift-tab` | next / previous category, then back to all |
| `alt-1`..`alt-9` | jump straight to a category (numbers shown in the column) |
| `^o` | show or hide the category column |
| type | filter, category names match too |
| `enter` | cd there |
| `^t` | pin or unpin the selected bookmark |
| `^e` | open in `$EDITOR` |
| `^a` | run `claude` there, then land there |
| `^u` | `git pull` |
| `^p` | `git push` |

`hop web` starts with `web` already typed.
