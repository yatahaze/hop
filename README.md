# hop

Bookmarks for the directories you work in. Categories down the left, bookmarks
in the main area. `tab` walks the categories, arrows pick, `enter` lands you
there. Type to filter if you would rather.

![hop: a category column on the left listing repos, configs and notes with counts, and the bookmarks for the active category in the main area](docs/demo.png)

`enter` puts your shell in that directory, and activates the project's
virtualenv if it finds one. Other keys act on it in place: open in `$EDITOR`,
pull, push, start an agent.

Bash and `fzf`. No runtime, no build. Works over SSH.

## Narrow terminals

The layout adapts to width, dropping the widest thing first:

| Width | Layout |
|---|---|
| 76+ | category column, bookmark names and paths |
| 56-75 | category column, names only |
| under 56 | column collapses to a one-line strip, names only |

Switching category is one key rather than a typed query, which is what makes
it usable on a phone or in a thin split. `^o` toggles the column.

![the same picker at 44 columns: the category column collapsed to a single line of hotkeys, bookmark names only](docs/demo-narrow.png)

## Install

```bash
git clone https://github.com/yatahaze/hop.git ~/hop && ~/hop/install.sh
```

Open a new shell, run `hop`.

`install.sh` also adds a shell function, which is required. A program cannot
change its parent shell's directory, so `hop` on `PATH` alone would print a
path and leave you where you were.

## Docs

| | |
|---|---|
| [Install](docs/install.md) | manual install, why the shell function, uninstall |
| [Bookmarks](docs/bookmarks.md) | format, where lists live, how they merge |
| [Roadmap](ROADMAP.md) | Windows, auto-discovery |

MIT, see [LICENSE](LICENSE).
