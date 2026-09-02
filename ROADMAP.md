# Roadmap

## Windows

Unsupported today. The script is bash, and the install targets it assumes
(`/usr/local/bin`, `/etc/profile.d`) do not exist.

Notes for whoever picks this up:

- **The cd problem is easier there, not harder.** A PowerShell function can
  call `Set-Location` in the caller's session directly, so there is no
  print-a-path-and-wrap dance. The wrapper *is* the whole program.
- **fzf runs on Windows**, and `PSFzf` wraps it. Worth checking whether calling
  `fzf.exe` directly keeps the code closer to the bash version than adopting
  the module.
- **The bookmarks format should not fork.** Same `[category]` / `name path`
  file, same merge order, with `%ProgramData%\hop\bookmarks.d\` and
  `%APPDATA%\hop\bookmarks.d\` standing in for `/etc` and `~/.config`. Path
  separators are the only real difference; `~` expansion becomes `$HOME`.

Open question worth settling first: whether this is a second implementation of
the same spec, or whether the picker moves to something that already runs on
both and the bash version retires.

## Discovered bookmarks

Offer directories found by scanning (anything with a `.git`, say) rather
than only what is hand-listed. The parser is the seam: anything that
emits `category<TAB>name<TAB>path` merges in like any other source, so this
could be a generated drop-in rather than a change to the picker.

Deliberately not built yet: the hand-edited list is small and the scan differs
per machine, which is exactly the drift the merge order was designed to avoid.
