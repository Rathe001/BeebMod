# Changelog

BeebMod is built against the WoW: Forever beta client, and is a beta itself
until that client is released. Versions are `MAJOR.MINOR.PATCH-beta.N`: the
beta number goes up with each build handed to anyone, and the rest once the
game and the addon settle.

## Unreleased

- **A tooltip's pill sits in its chip.** The Expedition's "RANK 1 / 10"
  started at the chip's left edge and ran into the title. Text in a tooltip
  no longer keeps the width it had in the tooltip shown before.
- **Time to level comes from how fast you level while you play.** It used to
  be the XP gained since login over the time since login, so time spent
  installing, setting up or standing in town counted as levelling. After a
  few kills it could say 81 hours. Now only the time between one XP gain and
  the next counts, and a gap longer than 5 minutes counts as 5. BeebMod keeps
  your last hour of play for each character, so the estimate is there as
  soon as you log in.
- **Right-click the XP line to start again.** It clears the pace and the
  session, as the Reset button on the Progress page does.
- **Pick Pocket's best find shows the item's name.** It read "item 5364".
  The name now comes the same way the price does, and an item the game
  hasn't loaded yet is loaded and named a moment later. The average item
  level's worst piece and the tooltips' item colours read items the same way.
- **A mastery toast shows the mob's whole name.** The heading says the
  mastery and the kills, "Bronze mastery · 10 kills", and the line under it
  is the mob's name alone. A name too long for the line is drawn smaller,
  and one still too long goes onto a second line instead of being cut off.

## 0.1.0-beta.9

- **Unit frames have no dark border.** The health and power bars reach the
  frame's edge. The dark background used to show round them.
- **The Warcraft Wiki is credited once, on the Expedition's settings page.**
  A mob's card no longer ends with a credit line.

## 0.1.0-beta.8

- **Debug tools are buttons on the Testing page, not commands.** BeebMod had
  64 commands, and 48 of them are gone. The Testing page shows a sample
  mastery toast. Its Show buttons print What loaded, Over-time bars and The
  book to chat, which were `/bt debug`, `/bt timers` and `/bt stats`. Record
  writes the records for Claude into the saved file, which the `/bt ...dump`
  commands and `/bt unitprobe` did. Clear takes them out again.
  CPU use times BeebMod for 10 seconds, as `/bt cpu` did. Type `/reload` after
  a record to save it.
- **Resets are Reset buttons on their own pages.** The Bag window and
  Character sheet pages put the windows back where the game puts them. The
  Progress page starts a new XP session. The Metrics page starts a new gold
  session and clears the Pick Pocket record. The Unit frames page already had
  its Reset.
- **What is left takes typed input.** Those commands are `/bt note`, `flag`,
  `tag`, `rate`, `find`, `prune`, `autopurge`, `cap`, `books`, `adopt`,
  `demo`, `setup`, `census`, `expedition` and `help`. Commands that only
  printed a number, such as `/bt gold` or `/bt speed`, are gone, since the
  dock shows the number. Commands that repeated a setting, such as `/bt tips`
  or `/bt frames test`, are gone too. Type `/bt` and a module's name, such as
  `/bt gold`, to open its settings page.

- **A card shows only the lore that is about its mob.** It used to match
  words of a mob's name. Sethir the Ancient, a satyr, showed the page for
  Ancients, and a Frostmane Troll Whelp showed three pages about Frostmane
  trolls. Now a mob's own page is the one titled with its whole name. After
  it come the page for the model the card draws, such as Harpy, Trogg or
  Deer, then its beast family and its creature type.
- **29 new descriptions for kinds of creature.** A card can now name what
  its model is for satyrs, furbolgs, night elves, goblins, banshees, ghosts,
  ghouls, imps, voidwalkers, succubi, infernals, doomguard, felhounds,
  wisps, bog beasts, lashers, oozes, zombies, skeletons, liches, gargoyles,
  dragonspawn, drakes, dragon whelps, golems and the four kinds of
  elemental. Each is one to three sentences, written from the wiki's page
  with everything after Classic left out.
- **Portraits at the edge of the Field Journal stay on screen while you
  scroll.** A portrait partly out of view is drawn whole, and the grid's edge
  cuts it off. It used to disappear until the whole card was in view.
- **Headings under a card leave off the wiki's tags.** "Timber Wolf (mob)" is
  "Timber Wolf". The credit at the bottom keeps the page's full title.
- **A critter's card says "Critter" once.** It read "Critter · Level 5 ·
  Critter".

## 0.1.0-beta.7

- **The Menagerie is now Nesingwary's Expedition.** "Menagerie" sounded like
  pets, and you hunt these mobs. The window's two tabs are **Field Journal**,
  the cards, and **Commendations**, the achievements. The ranks are named for
  hunters and take the same points as before. They are Greenhorn, Tracker,
  Trapper, Stalker, Pathfinder, Huntsman, Big-Game Hunter, Trophy Hunter,
  Master of the Hunt and Nesingwary's Equal. The commendation for 1,000 kinds
  of mob is The Green Hills of Azeroth. Type `/bt expedition` to open the
  window; `/bt menagerie` still works. Your journal carries over unchanged.
- **You can move the Expedition's line and the Ledger's row in the dock.**
  Each has its own tab under Dock in the settings, in the same place as its
  row in the dock. Drag the tab and the row moves with it. The Expedition's tab
  picks points or kills for the line. The Ledger's tab holds the switch for its
  target row. A tab hides while its module is off.
- **The Dock's tabs show a grip before you point at them.** The grip is faint
  and gets brighter under the pointer. The Dock's page says that the tabs are
  in the same order as the dock.
- **New tooltips for everything in the dock.** Each one starts with what you
  pointed at: your money and whether it went up, how many bag slots are free,
  your rank and the points to the next. Under that come one or two short
  lists, worst or nearest first, such as the gear that needs repair or the
  masteries you're closest to. The clicks are at the bottom. BeebMod
  draws the tooltips, with a coloured top edge for the feature they belong to.
- **Quests in the tracker have a tooltip.** It shows the zone, the level and
  each objective's progress.
- **All of BeebMod's text is rewritten to be plainer.** Settings, notes,
  tooltips, chat lines and the README follow one style, windowpane prose,
  written down in `docs/writing-style.md`. A few lines were out of date and now
  match what the dock shows, such as the Gold, Durability and Pick Pocket
  notes. The frame rate and latency page gives the numbers where the colours
  change.
- **The census footer says why nobody is counted.** It used to say "Nobody in
  the book yet" whenever it had no one to count. Now it says so only when the
  book is empty. When the Seen filter or a picked bar leaves nobody, the
  footer says that instead.
- **Every description in the Field Journal was read and checked.** The wiki
  describes the world as it is now, so many pages talked about Outland,
  Pandaria or the Cataclysm's changes to the old zones. Pages about things
  that were never in Classic are gone. The rest keep only what is true for
  Classic, in one to three plain sentences. The journal has about 5,800
  descriptions, down from about 8,000. The wiki's notes about itself ("...
  redirect here", "This section concerns...") and its quest levels ("[14]")
  no longer show.
- **A mob's card no longer borrows a page for a place.** A Sickly Deer
  "located in Olsen's Farthing" showed the page of a priest named Farthing.
  The card now reads only the part of a page that says what a mob is.

## 0.1.0-beta.6

- **Nine kinds of mob, scored by how hard they are and how often you meet
  one.** The Menagerie no longer goes by the client's rank alone: a mob is a
  **Critter**, **Normal**, **Elite**, **Dungeon Elite**, **Rare**, **Rare
  Elite**, **Dungeon Boss**, **Raid Boss** or **World Boss**. A kill now notes
  whether it was in a dungeon or a raid, and a boss is known by the client or
  by the boss fight won; a kind already in your journal is placed by its zone
  until its next kill. A first kill is worth 1 (critters and ordinary mobs) to
  20 (world bosses), and each metal's kills are set so it takes about as long
  whatever the mob - Platinum is 1,000 critters, 500 ordinary mobs, 250 of a
  dungeon's trash, 100 of an open-world elite, 15 rares, 25 of a dungeon boss,
  12 of a raid boss or 5 of a world boss. Grey kills count, so a level 60 can
  go back for the mobs they missed.
- **Every mob says what it is**: its category under its type on the card
  (a line taller for it), leading the line in the list, and in the popup - in
  the tooltips' gold and silver, orange for a dungeon's boss, purple for a
  raid's, red for a world boss. The popup's line had also been losing the
  level, rank and zone of any mob without a beast family.
- **Search the Menagerie.** A box at the right of the toolbar looks through
  every mob - its name, category, type, family, zone, level and lore - and
  switches the rail to All while it does. It is forgiving: capitals and
  apostrophes don't matter, a word can be the start of one, one letter can be
  wrong ("ragnoros"), and letters in order will do ("rgnrs").
- **Larger cards, four across**, far enough apart that the borders, crests
  and pendants are never cut off. A world boss's rays break through the top
  of the frame instead of hiding under it, and the platinum sheen no longer
  sweeps every card at once.
- **Scrolling glides and comes to rest on a row**, so there are always two
  whole rows of portraits in view; a row part in view is drawn, its portrait
  waiting until it is whole (`/bt menagerie edge` tries drawing it whole).
  **Scroll bars can be dragged** - here and in the settings - and a click in
  the gutter goes a page.
- **Portraits**: each is framed again once its model has settled, so late
  models no longer come up empty, and a card handed a new mob never shows the
  one before while the new one loads.
- **The mob's popup**: kills, points and mastery stand beside a narrower
  model; the mastery bar runs under all four metals with a tick at each and
  fills to the ones earned (a mob just at Gold used to show an empty bar); and
  "Bronze at 10 · 4 to go" is gone.
- **Achievements you have earned stand out** - lit, edged and ticked - and
  **Show: All, Earned or In progress** filters them, with how many are earned.
- **A toast for every new kind of mob, on by default.** A new mob gives way
  to an achievement or a rank when the toasts back up.
- **The lore is Classic's.** Opening lines that went on to Outland, Northrend
  and everything after are cut back to the part that is true in 1.12, or left
  out - Tallstriders are birds of Kalimdor and the Swamp of Sorrows, not of
  Darkmoon Island and the Dragon Isles - and pages written for Season of
  Discovery are not used.
- **The minimap stays drawn when the dock fades in a fight.** At anything
  under full the client stops drawing the terrain, and the map went black.

## 0.1.0-beta.5

- **Six features, each one switch.** Everything BeebMod does is now one of
  six features - the **Dock**, **Unit frames**, **Interface**, the
  **Census**, the **Ledger** and the **Menagerie** - and none needs another.
  Switching a feature off takes everything in it with it, and switching it
  back on brings back exactly what you had inside it. The settings rail is a
  block for each feature in its own colour, its switch on its heading and its
  tabs folded away while it is off; the heading opens the feature's own page,
  with its picture and a switch and a way in for each of its parts.
- **The first login asks which features you want**: six cards, each with a
  picture and a line on what it does, and All, None and Start. It replaces
  the three presets (full, just the dock, census and notes), and asks once
  more on an install from before it, its cards set to what you already have
  on. "Choose again" on the General page, or `/bt setup`, asks again.
- **The dock is never less than its logo and cog.** With the Dock switched
  off - or everything off - the dock is its header alone, the way back into
  the settings, and nothing switches that off. (It used to disappear once
  nothing was left in it.)
- The Menagerie watches for Pick Pocket itself, so a picked pocket's loot is
  never taken for a kill with the Dock off.
- **The census is no longer shared.** It holds only the characters you see
  yourself. The hidden channel, the hellos to other BeebMod users, the
  newer-build notice, "Share with other BeebMod users" and `/bt share` and
  `/bt comms` are gone. On the first login after this version, every
  character that was only heard from another copy - never seen by you, never
  written on - leaves the book, and so do the sharing's settings and log.
  The friends list is still asked for at login, so friends reach the book.
- **The Ledger keeps its own book.** Notes, tags and ratings are no longer
  written on the census's rows: each person you write on has a row of the
  Ledger's own, with the class, level and guild they had when you last
  wrote or saw them. The first login after this version moves everything
  you wrote across, once, from every realm and side. The Ledger no longer
  needs the census: a first note on a stranger is written from your target,
  and Find searches the people you wrote on - and, with the census on,
  everyone else it knows, as before. The census collects only while it is
  switched on, and says "Was in <guild>" on the tooltip itself.
- **Made-up data, for screenshots.** A switch on the Testing page (or `/bt
  demo`) shows a made-up world in every feature at once: fifteen hundred
  characters in the census, notes and tags on a dozen of them (and on you)
  in the ledger, a menagerie of real Classic mobs at every rank and mastery,
  and a party on the unit frames. Nothing of it is saved, and it is off again
  after a reload.
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
