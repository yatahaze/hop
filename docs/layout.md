# Layout

The category column is off by default. `^o` shows it. `column = auto` in
the [settings](bookmarks.md#settings) fits it to the terminal.

As the terminal narrows, the widest thing goes first:

| Width | Layout |
|---|---|
| 76+ | column with counts and a status line, names and paths |
| 56-75 | column with counts, names only |
| 40-55 | narrow column, names only, no status line |
| under 40 | the column becomes a one-line strip |

![the picker at 44 columns: a narrower column, names only](demo-narrow.png)

Switching category is one key, not a typed query. That is what makes it
usable on a phone, or in a thin split.
