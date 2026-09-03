# hop

Bookmarks for the directories you work in, and the hosts you ssh to, in one
picker. Arrows pick, `enter` lands you there: a `cd` for a directory, an
`ssh` for a host. Type to filter. `tab` switches between bookmarks and hosts.

![hop: a category column on the left listing repos, configs and notes with counts, repos highlighted as the active one, and its five bookmarks listed in the main area](docs/demo.png)

`enter` puts your shell in that directory, and activates the project's
virtualenv if it finds one. Other keys act on it in place: open in `$EDITOR`,
pull, push, start an agent.

Hosts come from `~/.ssh/config`, so there is nothing to maintain twice. The
row shows `user@host` beside the alias, so you can find the box by its IP
when you have forgotten what you called it. `# [name]` comments in the config
group hosts by company or cluster. See [SSH hosts](docs/ssh.md).

Bash and `fzf`. No runtime, no build. Works over SSH. On Windows it is a
PowerShell module and `fzf`, reading the same bookmarks file.

## Narrow terminals

The layout adapts to width, dropping the widest thing first. The category
column is off by default; `^o` shows it, or `column = auto` in the settings
fits it to the terminal:

| Width | Layout |
|---|---|
| 76+ | column with counts and a status line, names and paths |
| 56-75 | column with counts, names only |
| 40-55 | narrow column, names only, status line dropped |
| under 40 | column collapses to a one-line strip |

Switching section is one key rather than a typed query, which is what makes
it usable on a phone or in a thin split.

![the same picker at 44 columns: the category column still present but narrowed, with the active category filtered to bookmark names only](docs/demo-narrow.png)

## Install

```bash
git clone https://github.com/yatahaze/hop.git ~/hop && ~/hop/install.sh
```

Open a new shell, run `hop`.

`install.sh` also adds a shell function, which is required. A program cannot
change its parent shell's directory, so `hop` on `PATH` alone would print a
path and leave you where you were.

On Windows, from PowerShell 7:

```powershell
git clone https://github.com/yatahaze/hop.git $HOME\hop; & $HOME\hop\install.ps1
```

That installs `fzf` with winget if you lack it and imports the module from
your profile. Open a new PowerShell, run `hop`. The Windows port has no
category column or `alt-N`; `tab` and typing still narrow. See
[Install](docs/install.md#windows).

## Docs

| | |
|---|---|
| [Install](docs/install.md) | manual install, why the shell function, Windows, uninstall |
| [Bookmarks](docs/bookmarks.md) | format, where lists live, how they merge, settings |
| [SSH hosts](docs/ssh.md) | hosts from your ssh config, grouping them, editing or replacing the file |
| [Roadmap](ROADMAP.md) | auto-discovery, the rest of the Windows port |
| [tools/screenshot](tools/screenshot) | regenerate the images above |

MIT, see [LICENSE](LICENSE).
