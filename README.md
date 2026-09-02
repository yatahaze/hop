# hop

Bookmarks for the directories you work in. Type to filter, enter to land there.

```
hop > web
  repos/   webapp          ~/src/webapp        ┌────────────────────────┐
▌ repos/   webapp-docs     ~/src/webapp-docs   │ ~/src/webapp           │
  configs/ webserver       /etc/nginx          │ ## main...origin/main  │
                                               │  M src/settings.py     │
  enter hop · ctrl-a claude · ctrl-e edit      │ 3f9a1c2 fix pagination │
  ctrl-u pull · ctrl-p push                    └────────────────────────┘
```

`enter` puts your shell in that directory. Other keys act on it in place: open
in `$EDITOR`, pull, push, start an agent.

Bash and `fzf`. No runtime, no build. Works over SSH.

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
