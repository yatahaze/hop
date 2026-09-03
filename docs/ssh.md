# SSH hosts

The hosts in your ssh config show up in the picker beside your bookmarks.
`enter` on one runs `ssh <alias>`, so the key, port, user and any jump host
come from the config exactly as they would from the shell. You never have to
remember that the Django box is `djangor`: the row shows `ryan@203.0.113.7`
next to the alias, and typing any part of that finds it.

```
 ssh/           djangor   ryan@203.0.113.7
 ssh/           cdn       root@198.51.100.4
 repos/         webapp    ~/src/webapp
```

`tab` switches between all, bookmarks and hosts. The preview pane shows who
you would land as and where, resolved by `ssh -G` without connecting, plus
the port if it is not 22, the key if the config names one, and the jump host
if there is one.

## Where the hosts come from

`~/.ssh/config`, the file ssh itself reads, with `Include` lines followed.
Nothing to configure. To read a different file, or none:

```ini
# ~/.config/hop/config   (%APPDATA%\hop\config on Windows)
ssh_config = ~/General/Settings/ssh/config
ssh_config = off
```

hop's settings file is per machine and not something you sync, so `off` is
the switch for a machine that is only ever the destination and should not
offer a list of places to ssh out to. A machine with no `ssh` on `PATH` gets
no hosts either way. `/etc/hop/config` sets it for everyone on a box.

Only concrete hosts are listed. `Host *`, `Host *.internal`, negated patterns
and `Match` blocks are rules, not places you can go, and are skipped. A
`Host` line with several aliases contributes the first.

## Grouping

An ssh config is flat, but ssh ignores comments and hop reads one particular
shape of them:

```
# [acme/web]
Host acme-web1
    HostName 198.51.100.10
    User deploy

Host acme-web2
    HostName 198.51.100.11
    User deploy

# [personal]
Host djangor
    HostName 203.0.113.7
    User ryan
```

Every host after a marker belongs to it until the next one. The category is
the marker under an `ssh/` prefix, so these are `ssh/acme/web` and
`ssh/personal`, and typing `ssh` still narrows to hosts while `acme` narrows
to that company. Hosts before the first marker are plain `ssh`. Use `/` to
nest as deep as you like; a category is only a filter prefix.

`Include` gives a second way to group. An included file with no markers of
its own takes its file name as the category, so `Include config.d/*` with
`acme.conf` and `homelab.conf` in it yields `ssh/acme` and `ssh/homelab`.
Markers inside an included file win over its name. The one exception is a
file called `config`, which is treated as a pointer (see below) and inherits
whatever category was current.

## Editing, and replacing wholesale

```
hop --ssh-edit
```

opens the config in `$EDITOR`. `edit` in a host's action menu does the
same. Neither asks you to remember where the file is.

If your `~/.ssh/config` is nothing but an `Include` of a file that lives
somewhere synced, hop opens that file, not the one-line pointer. The rule: a
config with no concrete hosts of its own and a single `Include` is a pointer.

```
hop --ssh-import              # from the clipboard
hop --ssh-import file         # from a file
some-generator | hop --ssh-import
```

replaces the whole file, for when something else generates it: a server
inventory that renders the config for you, say. Copy its output, run the
command, done. The same pointer rule applies, so the synced file is what gets
replaced and a sync tool carries it to your other machines.

Before anything is written the new text is checked with `ssh -G`, and a bad
option means nothing changes. The previous file is kept beside the new one
as `config.bak`, and the summary lists the aliases that appeared and
disappeared:

```
hop: wrote 19 hosts to ~/General/Settings/ssh/config (old copy in config.bak)
     + bugsink
     - sentry-old
```

The clipboard is read with whatever the machine has: `pbpaste`, `wl-paste`,
`xclip`, `xsel`, Termux's `termux-clipboard-get`, or PowerShell's
`Get-Clipboard` on Windows and under WSL. With none of those, pipe the file
in.

## For whatever generates your config

If a tool writes the file for you, have it emit:

- a `# [name]` marker line before each group, using lowercase letters,
  digits, `-`, `_` and `/`; groups and hosts in a stable order so successive
  versions diff cleanly
- one alias per `Host` line, `HostName` and `User` first in each block so
  hop can show them, then `Port`, `IdentityFile` and the rest
- wildcard blocks such as `Host *` at the end, after every group
- UTF-8, LF line endings, and `~/.ssh/...` rather than absolute paths for
  keys, if the file is shared between operating systems

## Overriding a host from a bookmarks file

Hosts merge like any other source, keyed by category and name, and the
bookmarks files are read after the ssh config. So a bookmarks file can pin
one:

```ini
[ssh/personal]
*djangor    ssh://ryan@203.0.113.7
```

`pin` in the picker's menu does the same without editing anything.

## Windows

The PowerShell module reads the same config from `%USERPROFILE%\.ssh\config`,
follows `Include` lines whether they use `\` or `/`, and `hop --ssh-import`
reads `Get-Clipboard`. `tab` switches sections there too. See
[Install](install.md#windows) for what the Windows port leaves out.
