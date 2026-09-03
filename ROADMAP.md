# Roadmap

## Windows: the rest of the picker

`hop.psm1` covers picking, `cd`, virtualenvs, the preview and the `^a` `^e`
`^u` `^p` actions, reading the same bookmarks files. Missing: the category
column, `tab` cycling, `alt-N` and `^t` pinning.

All four work by fzf re-invoking the script as a subprocess on every
keypress, and `pwsh` takes a few hundred milliseconds to start, which is too
slow to sit under a key. Options, roughly in order of appeal:

- **Precompute.** The per-category row lists are known before fzf starts.
  Write each to a temp file and bind `tab` to `reload(type <file>)` through
  `cmd.exe`, with the index carried in a file the same way the bash version
  does. No pwsh in the loop. The column pane could be pre-rendered per index
  the same way. `^t` still needs a real process, but pinning is rare enough
  that a slow `pwsh -File` there would be tolerable.
- **fzf `transform` actions** (0.45+) can carry state without a subprocess
  for the cycle itself, but rendering rows still needs one.
- **Retire the bash version** for something that runs on both. Rejected for
  now: the spec is a 30-line parser, and two small implementations are less
  work than one portable one plus its runtime.

## Discovered bookmarks

Offer directories found by scanning (anything with a `.git`, say) rather
than only what is hand-listed. The parser is the seam: anything that
emits `category<TAB>name<TAB>path` merges in like any other source, so this
could be a generated drop-in rather than a change to the picker.

Deliberately not built yet: the hand-edited list is small and the scan differs
per machine, which is exactly the drift the merge order was designed to avoid.
