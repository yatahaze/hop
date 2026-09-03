# Roadmap

## Windows

`hop.psm1` does most of it: picking, `cd`, virtualenvs, the preview, ssh
hosts, `tab`, the menu. Same files.

Missing: the category column, `alt-N`, `^t` pinning.

Why: those work by fzf re-running the script on every keypress. Starting
`pwsh` takes a few hundred milliseconds. Too slow under a key.

`tab` got around it. Every list it can show is written to a file up front.
A batch file swaps them. No `pwsh` in the loop. The same trick would do
`alt-N`. Pinning is rare enough that a slow `^t` would be fine.

One codebase for both was considered. Rejected. Two small scripts are less
work than one portable one plus its runtime.

## Discovered bookmarks

Scan for directories with a `.git` in them. Offer those too.

Anything that prints `category<TAB>name<TAB>path` merges in like any other
source. The ssh hosts already work that way. So this is a generated drop-in,
not a change to the picker.

Not built yet. The hand-written list is small, and a scan differs per
machine.

## Hosts from an inventory

`hop --ssh-import` takes a whole ssh config from the clipboard or a pipe.
Pulling from an inventory's API directly was left out. Import plus a sync
folder gets the same result on every machine.
