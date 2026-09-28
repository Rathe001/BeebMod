# Handoff: rewriting the Expedition's mob descriptions

Written 2026-09-28 at the end of a long session, so a fresh one can pick up.
Delete this file once the work is done.

## The state of the repo

`main` is at `v0.1.0-beta.6` (released and pushed). A lot of work since then
is **not committed**. Josh commits only when he asks, and hasn't yet:

- the Dock tabs for the Expedition's line and the Ledger's row, and the
  faint grip on Dock tabs
- the rename of the Menagerie to **Nesingwary's Expedition** (players see
  "Expedition"; code, settings and saved data are still `menagerie`), its
  tabs Field Journal / Commendations, hunter ranks Greenhorn … Nesingwary's
  Equal
- the new dock tooltips: `UI/Tip.lua` (a shared frame) used by every dock
  cell's `M.Tip`, plus a tooltip on tracker quests
- a text pass over every player-facing string, following
  `docs/writing-style.md` (new), and `CLAUDE.md` (new)
- `CHANGELOG.md` has all of it under `## Unreleased`

Both test suites pass: `lua tests/run.lua` and `lua tests/load.lua` must
both end green before calling anything done. None of the above has been seen
in game yet; Josh checks in game after `/reload`.

A stash, `stash@{0}` "Tips: quest-line diagnostic", holds an old debugging
command Josh no longer needs. Leave it unless he says to drop it.

## The task

Review every description in the Expedition's journal so each one is plain,
Classic-only and has nothing unwanted for Forever. Josh approved the plan
below and chose the models to save tokens.

**The rules for the descriptions are in `docs/lore-rules.md`.** Hand that
file and `docs/writing-style.md` to every agent; they need nothing else.
Murloc keeps its opening cry; that is the only exception.

### The data

- `Modules/Menagerie/LoreData.lua` is generated; don't hand-edit it. It holds
  `P[n] = { kind, page title, text }` (7,983 pages: 7,180 `npc`, 400
  `group`, 275 `beast`, 110 `race`, 9 `family`, 9 `type`) and
  `BT.MenagerieLoreData[key] = P[n]` (8,330 lookup keys).
- `scripts/fetch-lore.ps1` builds it from `scripts/lore-cache.json` (the
  wiki's raw text, 6 sentences a page) through a vanilla filter (word lists
  `$LaterWords`/`$ThingWords`, `$SeasonTitle`). `-Rebuild` rebuilds from the
  cache with no network. Windows PowerShell: read JSON with
  `-Encoding UTF8`.
- The game looks descriptions up in `Modules/Menagerie/Journal.lua`
  (`J.WikiLore`): a mob's own page first, then tribe, race or animal, family,
  type. The popup credits "Warcraft Wiki: <titles> · CC BY-SA 3.0"; keep the
  credit, since a paraphrase is still an adaptation.

### Where the rewrites go

A new file, `scripts/lore-curated.json`, keyed by page title:
`{ "Hogger": { "status": "keep" | "rewrite" | "drop", "text": "...",
"checked": true } }`. `fetch-lore.ps1` applies it at build time after its
filter: `drop` leaves the page out, `rewrite` uses `text`, `keep` uses the
filtered wiki text. So a later fetch never overwrites the hand-made text,
and the game code doesn't change. This merge step still has to be written.

### The steps

1. **Export**: a script writes every page (title, kind, filtered text) to
   batch files, 100–200 entries each. No model.
2. **Sort** each entry keep / rewrite / drop. **Haiku 4.5, low effort.**
3. **Rewrite** the `rewrite` entries and all 803 broad pages (kinds `group`,
   `beast`, `race`, `family`, `type`). **Sonnet 5**: low effort for mob
   pages, medium for the broad pages.
4. **Check** every rewrite against its source (the three questions in
   `docs/lore-rules.md`). **Haiku 4.5, low effort.**
5. **Finish** (Opus): resolve the flags, write `lore-curated.json`, add the
   merge to `fetch-lore.ps1`, `-Rebuild`, run both test suites, and build a
   review page (an artifact) for Josh to read the 803 broad pages.

Stage the work: the 803 broad pages first, then the 7,180 mob pages in
batches, with Josh spot-checking a sample from each batch.

**Cost rules Josh asked for**: use fresh agents with a tight brief (never
forks of a long session), pass files not pasted text, batch many entries per
call, and skip entries the sort marks `keep`. The mob-page stage needs about
70–80 agent calls; that scale needs Josh to ask for it explicitly ("use a
workflow") before running a Workflow.

## Progress (2026-09-28, second session)

The broad-page stage is done and waiting for Josh's read:

- `scripts/export-lore.lua` wrote the batches to `scripts/lore-work/export/`
  (`broad-01..07`, 115 each; `npc-01..48`, 150 each). The work folder is
  git-ignored; `LoreData.before.lua` there is the file before any curation.
- Sonnet rewrote the 7 broad batches (`lore-work/rewrite/`), Haiku checked
  them (`lore-work/check/`). Haiku flagged 1 of 247; Opus's own read found
  about 30 more (later content, wrongly dropped Classic pages such as Demon
  and Dragonkin). Those fixes are in `lore-work/opus-overrides.json`, which
  `lore-work/curate.js` applies last. For the mob stage, expect the Haiku
  check to catch little; budget an Opus read of every rewrite and drop.
- `scripts/lore-curated.json` holds 799 titles (250 rewrite, 149 keep, 400
  drop). `fetch-lore.ps1` applies it; `-Rebuild` gives 7,590 pages, and
  both test suites pass.
- Review page for Josh: https://claude.ai/artifact/EgJaVv8ZWzQdwzaUe6AMpD
  (flags copy to the clipboard; paste them into the session).
- Two new mob pages surfaced once broad pages freed their keys ("Bloodworm
  (mob)" and one other); re-run the export before the mob stage so they are
  in a batch.
- Not fixed, flagged to Josh: `fetch-lore.ps1` picks among titles with a
  qualifier in hash order, so "Azuregos (Anniversary)" and "(tactics)" swap
  between builds, and a curated title can miss.

Mob pages, round 1 (`npc-01..08`, A to Cr) is done. Josh chose to replace
the Haiku sort: one Sonnet agent per batch sorts and rewrites together
(brief in the round-1 prompts: lists only rewrites and drops, names the
Cataclysm remakes to watch for). Opus then reads every change and every kept
page (`lore-work/readnpc.js npc-NN` and `... keeps`) and writes
`lore-work/ov-npc-NN.json`, merged by `addov.js`. Sonnet still keeps about
15 later pages a batch and wrongly drops a few Classic ones (the Silithus
wind stones, the Scourge Invasion, the elemental invasions): all Classic.
Then `curate.js` over every batch done, `fetch-lore.ps1 -Rebuild`, tests.

Filter fixes made on the way (fetch-lore.ps1): hatnotes ("... redirect
here", "This section concerns ..."), quest level tags, "prior to the
Shattering", "rare mob", and later events by name (Heritage of ..., War of
the Thorns, Nightmare Incursions, Radiant Echoes, Brewfest, Call to Arms).
Journal.lua: "what its page says it is" reads only what follows "is/are",
not the place (the Farthing bug), with a test.

After round 1 the unread mob pages were exported again (the filter had
changed them) as `export/npcb-01..42` (`lore-work/rebatch.js`; round 1's
`npc-01..08` kept in `export/`). Round 2 (`npcb-01..08`) done. From round 3
the brief tells Sonnet to look doubtful mobs up on Wowhead Classic: the
agent that did so on its own (npcb-01) left 1 miss where the others left
about 25, for about 2.5 times the tokens. fetch-lore.ps1 now writes the
same file every build (pages in sorted order).

Rounds 2 and 3 (`npcb-01..16`) done. The mob brief is `lore-work/brief-npc.txt`
(BATCH = the batch name); round 4 (`npcb-17..24`) was started with it.

## DONE (2026-09-28): every page reviewed

All rounds are in. `scripts/lore-curated.json` holds 7,802 titles (845
rewrite, 4,952 keep, 2,005 drop); `-Rebuild` gives 5,788 pages, and every
one of them is in the curated file (`lore-work/unreviewed.lua` then
`unreviewed.js` checks this). Both test suites pass. CHANGELOG has the
entry under Unreleased.

Things that happened on the way, in case they matter later:
- The stale `export/npc-46..48` files (from the first export) doubled about
  420 W-Z pages into `npcb-39..42`; `lore-work/dedupe.js` removed the copies,
  keeping the first review of each title.
- `npcb-43` is the 21 pages that only became reachable after others were
  dropped; Opus reviewed those by hand.
- The filter's `$SeasonTitle` now also rejects titles qualified as a later
  version ("(alternate universe)", "(BC Classic)", "(Anniversary)", ...), and
  `$ThingWords` names later events and places that kept recurring.

Left for Josh: read the review page (it has every page now), check in
game, then delete this file, the memory note and, if wanted,
`scripts/lore-work/` (git-ignored).

## Things to know about working here

- Player-facing text follows `docs/writing-style.md`: windowpane prose (the
  reader sees the subject, not the sentence; no pitch, no dash asides, no
  "not X but Y", no colon reveals). This applies to what you write to Josh
  too.
- Code comments have a house style: a heading in capitals, Josh's words and
  the date where he made a decision, then plain prose on why.
- Bash heredocs in this environment mangle backslashes; write scripts to a
  file with the Write tool and run them, or use the Edit tool.
- `BeebMod.toc` uses `\` paths; the load test reads it to find files.
