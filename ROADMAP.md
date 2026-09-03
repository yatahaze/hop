# Roadmap

## Windows: the rest of the picker

`hop.psm1` covers picking, `cd`, virtualenvs, the preview, ssh hosts, `tab`
and the `^a` `^e` `^u` `^p` actions, reading the same files. Missing: the
category column, `alt-N` and `^t` pinning.

All of these work in the bash version by fzf re-invoking the script as a
subprocess on every keypress, and `pwsh` takes a few hundred milliseconds to
start, which is too slow to sit under a key. `tab` got around it by
precomputing: every row list it can show is written to a temp file before
fzf starts, and a batch file steps a counter and `type`s the right one, so no
pwsh is in the loop. The same trick extends:

- **`alt-N`** is one more precomputed file per category and a bind each.
- **The column** could be pre-rendered per section the same way and shown in
  the preview pane, at the cost of the git preview, or left to the header
  strip as it is now that the column is off by default everywhere.
- **`^t`** needs a real process to write the pins file. Pinning is rare
  enough that a slow `pwsh -File` there would be tolerable.
- **Retire the bash version** for something that runs on both. Rejected for
  now: the spec is a 30-line parser, and two small implementations are less
  work than one portable one plus its runtime.

## Discovered bookmarks

Offer directories found by scanning (anything with a `.git`, say) rather
than only what is hand-listed. The parser is the seam: anything that
emits `category<TAB>name<TAB>path` merges in like any other source, so this
could be a generated drop-in rather than a change to the picker. The ssh
source is exactly that shape and is the template.

Deliberately not built yet: the hand-edited list is small and the scan differs
per machine, which is exactly the drift the merge order was designed to avoid.

## Hosts from an inventory

`hop --ssh-import` takes a whole config from the clipboard or a pipe, which
covers a generator you copy from. Pulling from an inventory's API directly
was considered and left out: it is one user's tool, and the import plus a
sync folder gets the same result on every machine without hop knowing
anything about where the file came from.
