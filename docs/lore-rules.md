# Rules for the Expedition's mob descriptions

For anyone sorting, rewriting or checking the descriptions in the
Expedition's field journal (`Modules/Menagerie/LoreData.lua`). Read this and
`docs/writing-style.md`; nothing else is needed.

## What a description is

A few sentences shown on a mob's page: what it is, where it lives, anything
notable about it. Most are one or two sentences. They come from the opening
lines of Warcraft Wiki pages (CC BY-SA 3.0).

## The rules

1. **Classic only.** BeebMod runs on WoW: Forever, which is Classic (patch
   1.12 era). A description says nothing that happens or exists only after
   that: no Outland, Northrend, Pandaria, Cataclysm changes, Dragon Isles,
   Legion, Shadowlands, Season of Discovery, Hardcore, pet battles,
   garrisons, heroic or mythic modes, later races or zones. Vanilla things
   with later-sounding names stay: the Burning Legion, the black
   dragonflight, the Emerald Dream, Dalaran, Gilneas as a kingdom.
2. **No new facts.** A rewrite may say less than the source, never more.
   Don't add a location, a relationship, a level, a quest or a motive the
   source doesn't state. If the source is wrong for Classic, cut the wrong
   part; don't replace it with something you believe.
3. **Plain words**, as `docs/writing-style.md` describes: what it is, said
   plainly, one idea per sentence, no pitch, no drama, no dashes as asides.
   Present tense for what a mob is ("Hogger is a gnoll in Elwynn Forest").
4. **Short.** One to three sentences. The page shows the mob's model above
   it; the text doesn't need to describe how it looks unless that's the
   point.
5. **Keep names as the game writes them** (Mor'Ladim, Zul'Farrak, the
   Defias Brotherhood). Keep item names in square brackets only if the
   source has them.
6. **The one exception:** the Murloc page keeps its opening cry,
   "Aaaaaughibbrgubugbugrguburgle!". Nothing else keeps a joke opening.

## Sorting (keep / rewrite / drop)

- **keep**: already plain, Classic-only, one to three sentences. Most short
  mob pages are like this ("Aarux is a bone spider in Razorfen Downs.").
- **rewrite**: true for Classic but wordy, garbled, cut off mid-thought, or
  carrying a clause about later content that can be removed.
- **drop**: the page is about something that isn't in Classic at all (a
  later-expansion creature, a Season of Discovery version), or nothing
  Classic is left once the later content is removed.

## Checking a rewrite

Compare the rewrite with its source and answer three questions:
1. Does the rewrite state anything the source doesn't? (a new fact)
2. Does it still mention anything after Classic?
3. Does it break `docs/writing-style.md`?

Any "yes" is a flag, with the words that caused it.
