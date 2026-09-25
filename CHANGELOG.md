# Changelog

BeebMod is built against the WoW: Forever beta client, and is a beta itself
until that client is released. Versions are `MAJOR.MINOR.PATCH-beta.N`: the
beta number goes up with each build handed to anyone, and the rest once the
game and the addon settle.

## Unreleased

- **A release pipeline.** Pushing a version tag packages the addon and
  publishes it to GitHub Releases (and to CurseForge once its project and
  API key are set up), with that version's notes from this file;
  `scripts/cut-release.ps1` bumps the version, closes this section, commits
  and tags. The tests run on GitHub on every push.
- **A Testing page**, under General on the settings rail: the made-up
  people (party or raid) and made-up auras moved there from the Unit frames
  and Buffs pages, and buttons that print `/bt debug`, `/bt timers` and
  `/bt stats` to chat. The settings window is 20 taller to fit the tab.
- The target frame is wider (220, from a party cell's 160), so its level,
  a long name and your threat fit on one line; its target and the focus
  move out with it.
- **The dock has one width.** It was as wide as its widest part, so turning
  the quest tracker on made it wider and off made it so narrow the XP line
  and the Ledger's prompt were cut off. It is 230 now whatever is in it,
  with a "Dock width" setting (200-320) on the Dock page, and the quest list
  follows it.
- Party cells, yours included, show the level before the name, in the
  game's difficulty colours, as the target does. Raid cells are too narrow.
- **Heals and damage over time, as bars.** A thin bar along the top of the
  health for your HoT on a friend (party, raid, main tanks, a friendly
  target) - one per class: Rejuvenation, Renew or Riptide - and each of your
  DoTs on an enemy, up to four: on your target they stack over the
  personal resource display's bars, where your eyes are while you cast (over
  the target frame when the Resource display module is off); on the focus
  and bosses, above the frame. Thicker than the heal's and a little
  see-through (bosses sit a few pixels further apart to make room), in an
  order you set on the Resource display page so the ones you always keep up
  sit nearest the bars. A lane and a colour per spell, run down by the
  client; in its last five seconds the part that has run out flashes red
  under what is left, faster as it goes - drawn by the client, since it
  will not run addon code on its aura buttons. "Blink as it runs out" is a
  switch for heals (Unit frames page) and for damage (Resource display
  page); `/bt timers` says how far each lane got.
- **The Census on its own.** With every module off but the Census, the dock
  disappeared; it now stays as the name, the Census icon and the cog, and is
  always at least as wide as its header (it had shrunk to a 34-pixel sliver
  with the name and icons hanging off it).
- **Heals past the end of the bar.** On party, player and target frames an
  incoming heal bigger than the health missing runs past the end of the
  health bar as a ghost, up to 8% of its width, and stops there.
- **The book, packed.** A character at rest is one short string instead of a
  table of named fields: classes, races, guilds, zones and GUID servers are
  kept once each as word lists on the book, times are minutes or hours since
  2026, and a character is unpacked into a table only when something reads
  it (and packed again at logout). On the real book: 16,601 of 16,608
  characters pack, the saved book goes from 7.6 MB to under 1 MB, and memory
  from about 13 MB to 3 MB. Characters you have written on stay as they are.
- A character of the book's own realm is keyed by name alone ("Beeb Bob",
  not "Beeb Bob@ClassicBetaPvE2"); the first login moves every book across.
- The GUID index is no longer saved (it was a megabyte of the file); it is
  kept in memory for the characters met this session.
- Zones keep no time of their own at rest, so a tooltip shows a zone only
  for characters seen since the last reload.
- **The book has a size:** past 150,000 characters (`/bt cap`), the ones seen
  longest ago go at login, whole days at a time; yours always stay. `/bt
  stats` says how many are packed and what the limit is.
- **The census, narrowed.** A row of *Seen* buttons (Today, Week, Month, All)
  counts only the characters seen that recently, on every chart. Clicking a
  bar - a class, race, guild, zone or tag - narrows every other chart to it
  ("what races are the hunters", "what levels is this guild"); the bar's own
  chart stays whole with it lit, and a button over the charts puts it back.
  Two new charts: **Guild** (the ten largest, the rest summed, then those seen
  with no guild) and **Zone** (where each character was last seen). All of it
  is worked out from what the book already keeps, so the saved file is no
  larger.
- **Saved variables load the ordinary way.** Build 1.60.1.70009 fixed the
  beta bug that kept the client from reading saved variables back, so the
  `Data\Live` workaround is gone: the TOC no longer loads the last save as an
  addon file, and anyone else installing the addon no longer gets an error
  for a file only this machine had. The book is unchanged - it was already in
  the client's own saved file.
- Dropdown menus are dressed once the client has built them (a menu dressed
  during its build raised "Use of function 'CreateTexture' is disallowed").

## 0.1.0-beta.1

The first version kept in git: everything up to here, in one.

- **The dock** - the panel at the side of the screen: the minimap and other
  addons' buttons, experience and reputation, a grid of readouts (gold, bags,
  durability, item level, pick-pocket takings, speed, performance), the quest
  tracker under its zones, the micro menu, and a header with the clock and the
  census.
- **Combat** - unit frames for you and your group, the raid, main tanks,
  target, focus and bosses, with auras drawn by the client's own containers;
  a buff tray; the personal resource display with combo points; the damage
  meter restyled, with amounts a second and the fight's length.
- **Windows** - the action bars, bag window, character sheet, chat, game
  menu, dropdown menus and tooltips, in the toolkit's look; every button still
  the game's.
- **People** - the Ledger (notes and tags on the people you meet) and the
  Census (the realm's charts), from a book of every character seen.
- **Settings** - one window, its rail in four groups (Dock, Combat, Windows,
  People), a switch per module and finer settings on each page.
