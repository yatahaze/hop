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

## Paths that do not exist

Hidden, and counted in the header:

```
enter hop · ctrl-a claude · ctrl-e edit · 3 not on this machine (--all)
```

`hop --all` shows them.

One list can therefore serve machines with different layouts.

## Keys

| Key | Does |
|---|---|
| type | filter, category names match too |
| `enter` | hop there |
| `ctrl-a` | run `claude` there, then land there |
| `ctrl-e` | open in `$EDITOR` |
| `ctrl-u` | `git pull` |
| `ctrl-p` | `git push` |

`hop web` starts with `web` already typed.
