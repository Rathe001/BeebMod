# Changelog

BeebMod is built against the WoW: Forever beta client, and is a beta itself
until that client is released. Versions are `MAJOR.MINOR.PATCH-beta.N`: the
beta number goes up with each build handed to anyone, and the rest once the
game and the addon settle.

## Unreleased

- **The Menagerie**: a journal of every kind of mob you have killed, rares
  and elites among them, as a card each, five across. A rail down the left
  files them by creature type or by the zone you first met them in - All
  first, then each with its count and points - and they sort A to Z or the
  most killed first, as cards or as a list (three slim rows across, thirty in
  view). A card lifts over its shadow under the cursor. The mob looks
  out through a stepped Art Deco arch, over the patch of the zone's map where
  you first killed it. **The arch is its rank**, in the tooltips' gold and
  silver: a plain line for an ordinary mob, silver and doubled with a diamond
  on each step for a rare, gold with brackets at its foot for an elite, rays
  over the keystone for a world boss, and a gem at the top of the arch for
  all but the ordinary. Under it: its name (smaller when it is long), what it is,
  its kills, its mastery and its points - the lore is on its page. **The card's border
  is its mastery**, and grows more ornate as the mastery climbs: a bare iron
  line, then bronze, silver, gold, and platinum with a crest, wings, a
  pendant and a sheen that sweeps across it. The lore comes from the Warcraft
  Wiki (CC BY-SA 3.0, credited): the most specific page a mob matches - its
  own, its tribe or clan, its race, its beast family - or else a quest line
  that names it, or else a line of what the journal knows. Click a card and
  the mob opens in a popup over the dimmed grid: its whole model in a plain
  box, to turn (drag), move (right-drag) and zoom (the wheel); its
  kills, points and mastery; the mastery ladder at its rank; and its lore
  in a box that scrolls - the best page first, then each page it borrows
  (its race, family, type) and any quest under a heading of its own, with an
  ornament between each and the wiki's credit once at the end. A mob whose
  name and pages never say what it is (this realm's own named mobs) borrows
  the race of another mob drawn from the same model: Witchmother Arysa
  has the harpy's body, so she has the Harpy page. The lore covers every
  mob of every Classic zone, dungeon and raid ahead of the first kill, and
  the kinds of animal they are (a Darkshore Thresher is a threshadon);
  `/bt menagerie lore` lists each mob's page and how it was found. The arrows beside
  it (or the arrow keys) step through the mobs the grid is showing, and
  Escape or a click outside closes it, leaving the window open. There is no list of the
  game's mobs behind it: a new kind is a new page the first time you kill
  it, so this realm's own creatures are in it too. **Points are the score.**
  Every kind is worth points of its own: 1, or 3 for an elite, 5 for a
  rare, 8 for a rare elite and 15 for a world boss.
  - **Masteries**: Bronze, Silver, Gold and Platinum at 10, 50, 150 and 500
    kills of one mob, worth 2, 3, 5 and 10 points, each earned on the way
    to the next. The rarer kinds take fewer: an elite 5, 25, 75 and 250; a
    rare or rare elite 2, 5, 10 and 20; a world boss 1, 2, 3 and 5. A
    card's border is its metal, and "Mastery" order puts the highest first.
  - Achievements: milestones for how many kinds and how many kills; each
    creature type, beast families, rares, elites, world bosses and zones;
    a mob five levels above you, or one whose level is a skull.
  - Masteries and achievements toast in the game's own achievement art.

  **Points make a rank**, ten of them: Novice, Scribbler, Observer,
  Chronicler, Scholar, Lorekeeper, Taxonomist, Loresage, Savant and
  Polymath. A line in the dock shows your rank - "Scholar (5/10)" - and your
  points (or your kills), and its bar fills toward the next rank; reaching one is a toast of
  its own. Click the line for the journal. The journal counts
  this character's kills or all your characters' together. It has a tab of
  its own in the Dock group - drag it to move its line in the dock - with
  switches for the toasts, their sound, and a toast for every new kind. The
  settings window is a tab taller to make room for it.
- Without the combat log, a kill is a mob you tagged and fought that dies in
  view. When the kill happens out of sight, the experience line or the loot
  window counts it instead. A mob somebody else tagged is not yours, and
  each kill is counted once however many of these see it, a `/reload`
  included. `/bt menagerie debug` says what saw each one.

## 0.1.0-beta.4

- A party frame's right-click menu no longer raises "Use of function
  'CreateTexture' is disallowed". The client keeps such a menu locked for as
  long as it is open, so nothing is made on it: the toolkit's surface goes
  on a frame of its own just behind the menu, and only what is already
  there is recoloured or put away. The lock is recognised without touching
  anything forbidden.

## 0.1.0-beta.3

- **The census is shared** with everyone who has BeebMod, over the hidden
  channel. Only news goes out - somebody new, somebody seen for the first
  time today, a new level or guild - never the book as it stands. News waits
  a random half a minute to two minutes and is dropped if another copy says
  it first, and the channel has one budget (about two messages a second)
  shared between everyone sending, so it is as busy as the realm is big,
  not as the addon is popular. What arrives is filed as "heard": never a
  sighting of yours, never over a guild you saw more recently, never passed
  on. A switch on the Census page turns it off both ways; `/bt share` says
  how it is going.
- The chat window's menu button no longer raises "Use of function
  'CreateTexture' is disallowed": a menu opened from our own code is dressed
  a frame later, once the client has built it.
- Four switches that could never be turned off now can: the Census's header
  button and "Up to date while open", the bag window's rings and the buff
  tray's time text.
- **A first-login choice: how much should it change?** A fresh install asks
  once, in a small window: **Full** (everything), **Just the dock** (the
  dock, the census and your notes; the game keeps its own frames, bars,
  bags, chat and tooltips) or **Census and notes** (the game's interface
  untouched, the census and the Ledger quietly running). Each is only a set
  of module switches, so anything can be changed one at a time later. An
  install that has already set its switches is not asked; `/bt setup` or
  "Choose again" on the General page asks again.
- **BeebMod users find each other.** After the loading screen, out of
  combat, every copy joins a hidden channel (out of every chat window, its
  notices filtered away) and says one hello on it; whoever hears it answers
  by whisper, a few seconds later and never more than a few a minute, and a
  short daily burst measures how much gets through. Nobody without BeebMod
  sees anything, and nothing is printed - except, once, that someone has a
  newer build. The ground the census will be shared on, with everyone who
  has the addon (notes will be friends-only, once this client's friends list
  works). `/bt comms friends` lists who answered, `/bt comms log` shows
  everything, and a switch on the Testing page turns it off; the commands
  for trying things by hand are still there.
- **The book's size cap drops low levels first.** Past the cap, characters
  on file at level 1-10 (bank alts, throwaways) go before anyone else, the
  longest unseen of them first; only then the rest, oldest "last seen"
  first. A character with no level on file counts as one of the rest, and
  anyone you have written on always stays.

## 0.1.0-beta.2

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
