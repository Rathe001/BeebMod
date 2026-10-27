# BeebMod

A WoW: Forever addon, written in Lua. The game is in
`C:\Program Files (x86)\World of Warcraft\_forever_`.

- **Anything a player reads** (tooltips, settings, notes, toasts, empty states,
  chat lines, the journal's descriptions, README, changelog) follows
  `docs/writing-style.md`: windowpane prose. Read it before writing or
  changing such text.
- **Replies to Josh** (answers, reports, summaries) follow the same guide; its
  section "Writing to Josh" covers them.
- Run `lua tests/run.lua` and `lua tests/load.lua` before calling a change
  done; both must end green.
