# BeebMod

Small utilities for WoW: Forever. You set them all in one window. Click the
cog in the dock or type `/bt` to open it.

## Features

BeebMod is opinionated. It asks whether you want each part, and it decides
how each part looks. It has five features in two groups, and each feature has one
switch:

- **Interface:** the Dock, Unit frames and Game frames
- **Journals:** the Ravenholdt Ledger and Nesingwary's Expedition

On your first login BeebMod asks which features you want. Its window lists
the five under the same two headings, each with a few words on it and its
switch. Click a feature to see pictures of it, a line on what it does and
what it adds. The settings window's rail lists
General, then the features under their headings. Each feature has one page:
its switch at the top right, then a switch for each of its parts, a part of a
part indented under it. Switch a feature off and everything in it goes off.
Each part keeps its own switch, and the setting stays as you left it while
the feature is off. No feature needs another.

The window's title bar has a search box. Type a word, such as pets or gold,
and BeebMod lists every row with that word in its name or its line, under its
feature's name. Each row has its switch, the same one as on its page. A part
comes with the row it is a part of, and a feature's name brings its whole
page. Press Escape, click the cross in the box, or click a page on the rail
to go back.

The **core** is what every feature would otherwise build for itself: the
settings window, the dock's header, the look of a button and a pill, and
**General**. General holds the colours of every panel, one Size for every
panel (the dock, the frames, the buffs and the tooltips), and a Positions
button that puts the dock, the main tanks, the bag windows and the character
sheet back where they start. Shift-drag any of them to move it. The other
unit frames go where the game's Edit Mode puts the frames they replace: move
those in Edit Mode, and BeebMod's follow. The typeface
is Google Sans. The dock's logo and cog are always on screen. With the Dock
off, or every feature off, they are all that BeebMod shows. Click the cog to
get back to the settings.

**Dock** is the panel at the side of the screen and what is in it. Its page
lists the dock's rows from top to bottom, and dragging a row moves it in the
dock.

| row | what it is |
|---|---|
| **Clock** | In the dock's header. It shows local or server time; click it to switch. |
| **Minimap** | The client's map, square, moved into the dock. |
| **Addon buttons** | Other addons' minimap buttons, in one line. |
| **Experience** | The first and largest row: a shield with your level on it, the time to the next level at your XP per hour, the XP bar with rested XP ahead of it, and how much XP is left. Its tooltip lists zones and dungeons for your level. Right-click it for a new session. |
| **PvP**, **Reputation** | Slim lines under Experience: your PvP rank with its insignia and how far to the next, and your standing with the faction you watch. |
| **Expedition**, **Ledger** | Each journal's slim line: your rank's badge, your rank and your points. Click it to open the journal. |
| **Metrics** | A grid of readouts, three to a row, each with its own switch: gold, bag space and your class's reagents, durability, average item level, pick-pocket takings (rogues), movement speed, frame rate and latency. Right-click the gold for a new session, or Pick Pocket to clear its record. |
| **Quest tracker** | BeebMod hides the client's tracker and draws your quests in the dock, under their zones, lowest level first. |
| **Micro menu** | The game's menu buttons, in the dock. |

The Dock's page has one more switch. **Fade in combat** fades the dock to 70%
in a fight until you point at it.

**Unit frames** are what you watch in a fight.

| part | what it is |
|---|---|
| **Unit frames** | You at the top of the party column, even alone, and each member with a pet slot and their target beside them. Target, focus, raid, main tank and boss frames, and your own cast bar, with a switch each for party, raid, main tanks, bosses and your cast bar. Icons for resurrection, summons and master looter, your threat on the target, and a hunter pet's happiness. The target, focus and boss frames fade when none of your class's skills reaches them, such as a hunter's Auto Shot or Raptor Strike, and the party and raid fade when the game says they are out of range. Switch them off, or one type of frame off, and the game's own frames come back. |
| **Buffs** | Your buffs, debuffs and weapon enchants in a tray beside the dock, in two lines. The soonest to run out are at the left, and the permanent ones sit against the dock, A to Z. Switch it off and the game's buff bar comes back. |
| **Nameplates** | Enemy nameplates in BeebMod's look, with the enemy's level, name and health. A ring means it is attacking you, and a white outline marks your target; the others step back while you have one. Casts show under the plate with the spell's icon and name, and a red rim marks a cast the game says to interrupt. An enemy player's guild sits under their bar in green, out of the way while they cast. Your damage over time shows above the plate. Friendly nameplates show a name and no bar. A player's name is in class colour, with their level before it and their guild under it in green. An NPC's is smaller and green, with a picture for what it does, such as selling, training or flying you, and its title under it. Another player's pet has its owner's name under it, and totems have no name. Friendly nameplates, and pets and minions, have a switch each. The game has at most 40 plates out at once, so in a crowded city some players have none. |
| **Resource display** | Your own nameplate, flat, with combo points under it (rogues, cat druids). An icon to its left says how near your target is: green crossed swords in melee range, a green crosshair in reach of your ranged attack or spells (Throw or Shoot for a warrior or rogue, Auto Shot for a hunter, your furthest-reaching spell for a caster), a red no-action sign when it is too close to shoot and too far to hit, and a red crosshair out of reach. With no target it is a grey, faint crosshair. |
| **Damage meter** | The client's own meter, flat, with each row's amount per second and the fight's length. |

**Game frames** are the game's own windows and menus, drawn to match BeebMod.

| part | what it is |
|---|---|
| **Action bars**, **Bag window**, **Chat** | The client's own, flat like the rest of BeebMod. Every button works as before. You drag the bag window by its title and it stays where you leave it. Your four bag slots, the reagent bag's and the keyring sit in a row along the bottom of the backpack. Drag a bag onto a slot to equip it, or off one to take it out. The game's bag bar is hidden while the bag window or the Bags readout is on. The chat window sits flush in the bottom-left corner. Move it in Edit Mode and it stays where you leave it; let go of it near the corner and it goes flush into it. In chat, guild names such as <New Horizon> are green. Click one to put its /who in the chat box. Click a web address to copy it. The expand mark in a chat window's corner opens that window's chat in a large window, where Select text lets you copy lines. |
| **Character sheet** | Item level on every slot, and BeebMod's look. |
| **Tooltips** | Unit tooltips rebuilt in BeebMod's look: the name and level, then small tags for what they are and what state they are in, then a row each for a quest objective, your kills of an enemy, and your note. Elites and rares get a gold or silver border. Item tooltips, and the Equipped tooltips beside them, are written again in the spell tooltips' look: the item's icon beside its name, its DPS or armor at the right with its item level (ilvl) under it, how it binds (BoE, BoP, Soulbound) and whether it is unique as small tags under its kind, a row of cells for its damage, speed and the level it needs, then its stats and effects as plain lines, and durability as a bar beside the sell price. A potion's cells say what it restores and its cooldown. An item with none of those has no cells. |
| **Game menu**, **Dropdown menus** | The menu Escape opens, and every dropdown and right-click menu. The game doesn't let addons restyle some menu buttons, so those keep the game's look. |

**The journals** are the Ledger and the Expedition. Their windows are the
same shape. The top row has the journal's name and its tabs. Under it is your
rank, with a bar to the next one and three numbers for the journal; click it
to see the commendations. Each tab has a list on the left that picks what the
page shows. A new rank shows a
toast with its badge, and a sound. A commendation or a mastery shows
on the journal's line in the dock for a few seconds; with the line off, a
small bar at the top of the screen shows it. Several at once are one notice.
Rank toasts and their sound have a switch each on the journal's page.

**The Ravenholdt Ledger** (the Ledger, for short) keeps a record of everyone
you see, and notes, tags and a rating on the people you meet. Its window has
three tabs. **Charts** shows your
realm by class, race, level, guild and zone; pick the chart on the left.
Tiles across the top show the faction, gender and level split, and a click on
any part of one narrows every chart to it. **Find people** searches by name,
guild or a word you wrote, and the list on the left shows everyone, your
notes, or the people with one tag. **Commendations** lists what the Ledger
rewards: characters recorded, notes, tags, groups and duels. Every 100 characters you record is
worth 1 point, a note 2 and a tag 1, and each commendation its own. The
points set your rank, from Fledgling to Eye of Ravenholdt, and your
characters on one realm share it. Open the window from the Ledger's line in
the dock. BeebMod never shares any of it. It holds only the people you saw, in one book for
each realm, and so for each ruleset, with both factions in it.
Recording everyone you see is a part with its own switch. Your notes,
tags and ratings are kept in a book of their own (`BeebModDB.ledger`), so
they work with it off. To write them, right-click a player's frame, or their
name in chat or a list, and point at **Ledger** at the foot of the menu. Tick
a tag, or choose **Write a note**, which opens a small box under the frame.
A click on **Ledger** itself opens the same box, with every tag in it.
Your note and tags show on the person's tooltip, and as a mark at the top
right of the target frame. The Ledger also remembers the people you grouped
with: a group counts once you've been together 5 minutes, or straight away in
a dungeon. It keeps your duel scores too: how many duels you won and lost
against each player.

**Nesingwary's Expedition** is a journal of every enemy you have
killed. Each has a card with its model, its
lore from the Warcraft Wiki and its mastery. On its page, a Model · Map switch shows the zone's map with
a dot for each place you killed it, or a dungeon's loading screen. The page also lists
the enemy's abilities, from the VMaNGOS database. Every unique kill and every commendation is worth points. The
points set your rank, from Greenhorn to Expedition Leader. A line in the
dock shows your points and rank. Click it to open the journal.

**Made-up data** is for screenshots, and its switch is on the Testing page.
It shows a made-up realm, notes, a journal and a party in every feature at
once. BeebMod saves none of it. **Made-up people** on the same page shows the
unit frames as a party or a raid.

**The Testing page** is also where the debug tools are. Its buttons show
sample notices and rank toasts, print BeebMod's reports to chat (What loaded, Over-time
bars, Saved characters), move another book's characters into this realm's
book, and write records for Claude into the saved file. Record
writes down how the game built each part you have on, and also the next menu
you open and your next fight. Clear takes the records out again. CPU use times
BeebMod for 10 seconds. Type `/reload` after a record to save it.

The Testing page shows only when BeebMod runs from this folder. In
`Core/Init.lua`, `BT.DEV = true` sits between `--@debug@` and
`--@end-debug@`. The packager that builds the release zip turns those lines
into a comment, so a player's copy has no Testing page. `tests/run.lua`
checks that it stays so.

### Adding a utility

A utility is one file and one call, which give it a row on its feature's
page and, if it wants one, a section of the dock. The words on its row are in
`BT.Window.LABELS`, and its feature's page lists it in
`BT.Window.PAGE_MODULES` (the Dock's lists every module that stands in the
dock).

```lua
local M = BT.Module({
    key = "myutility", title = "My Utility", order = 30,
    feature = "dock",   -- the feature it belongs to; its switch covers this too
})
function M:Parts() return { ... } end  -- switches under its row: label, get, set
local section = BT.Dock.Section("myutility", 50)  -- its own part of the dock
function M:OnBind(db) ... end          -- the settings are bound: migrate, sweep
BT.Record("myutilityDump", M.Dump, "myutility")  -- a record for the Testing page
```

BeebMod has no commands after `/bt`, which opens the window. A debug tool is
a button or a switch on the Testing page. A dump of the game's
frames is a function that writes into `BeebModDB` under its own key and
returns how many lines it wrote. `BT.Record` registers it, so the page's
Record button runs it and its Clear button takes it out.

A utility is named after its title. "Resource display" has the key
`resourcedisplay`, lives in `Modules/ResourceDisplay/ResourceDisplay.lua`,
keeps its options in `settings.resourcedisplay` and writes its record as
`resourcedisplayDump`. To rename one, change all of these and add the old and
new names as a step in `Core/Rename.lua`, which moves the saved values across
at the next login.

A hook that goes through saved data and removes anything belongs to the
module that owns that data, never to the core. A utility you have switched
off must not delete data it isn't showing you. That is why the tag migration
lives in `Modules/Ledger`.

## Files

    Core/Init.lua        the module registry, the settings and the book
    Core/Rename.lua      moves saved settings from a module's old name to its
                         new one, once, at login
    Core/Util.lua        names, keys, how old a record is, colours
    Core/Session.lua     "this session" for Currency, Experience, Reputation
                         and Pick Pocket: when one starts, and the rate per hour
    Core/DB.lua          one row per character: read, write, merge, prune
    Core/Collect/        what the client tells BeebMod without being asked
    Core/Slash.lua       /bt, which opens the window, and What loaded for the
                         Testing page
    Core/Boot.lua        the core's own login: the settings, the dock, then BT.OnWorld
    Core/Demo.lua        made-up data for screenshots: one switch, each feature's own
    UI/Window.lua        the window: General, the features under two headings
                         and Testing down the side, a page per feature, and
                         the search in the title bar
    UI/Welcome.lua       the first login's window: the features in a list, a
                         switch each, and pictures of the one you click
    UI/Settings.lua      General: the colours, one size, and positions
    UI/CensusWindow.lua  the Ledger's window: Charts, Find people and
                         Commendations
    UI/Dock.lua          the dock: a header, and sections under it
    UI/Pill.lua          the pill, and the one place a measurement is judged
                         good or bad
    UI/Tip.lua           the tooltip every part of the dock shares
    UI/Widgets.lua       buttons, switches, panels, and the rows and sections
                         every settings page is built from
    UI/Ornament.lua      the Art Deco border an elite or a rare gets, on its
                         unit frame and on its tooltip
    Core/Tooltip.lua     one hook on the unit tooltip, shared by several modules
    Core/Reach.lua       how far your class's skills reach a unit, asked of the
                         game spell by spell, for the frames' fade and the
                         resource display's crosshair
    Core/Gamepad.lua     tells the game's controller navigation when one of
                         BeebMod's windows opens and closes
    Core/Furniture.lua   restyles the client's own frames by what each one is
    Modules/Ledger/      its own book of notes (Store.lua), tags, the Find tab
                         (Find.lua, in the Ledger's window), its entry in
                         the right-click menu on a player (Menu.lua),
                         the notes on a tooltip, the people you grouped with
                         (Groups.lua) and your duel scores (Duels.lua)
    Modules/Minimap/     the map in the dock; Modules/Buttons/ the addon buttons
    Modules/XP/, Rep/, PvP/
                         the experience, reputation and PvP lines of the dock
    Modules/Metrics/     the readout grid; Currency/, Bags/, Durability/,
                         ItemLevel/, Pickpocket/, Speed/ and Performance/ are
                         its rows
    Modules/Clock/       the time in the dock's header
    Modules/Census/      the counting and the charts, a part of the Ledger
    Modules/Tooltips/    the compact tooltip
    Modules/Tracker/     the quest tracker in the dock (Quests.lua reads the log)
    Modules/Bars/, BagWindow/, Chat/, DamageMeter/, Dropdowns/, Micro/
                         the client's own frames, drawn flat. Chat/ also has
                         the guild names and web links in a line (Links.lua)
                         and the large chat window (Reader.lua)
    Modules/CharSheet/   the character window
    Modules/ResourceDisplay/
                         the personal resource display
    Modules/UnitFrames/  the unit frames: one secure button drawn from secret
                         values it never reads, the groups without snippets,
                         and auras in the client's own containers (Auras.lua),
                         because this client doesn't let an addon read an aura
                         in a fight. Also your buffs' tray beside the dock
                         (Buffs.lua)
    Modules/GameMenu/    the game menu Escape opens, restyled (look only)
    Core/UnitProbe.lua   what the client tells a unit frame, written down by
                         Record on the Testing page
    Core/Cpu.lua         CPU use on the Testing page: times what runs on its
                         own (updates, events, timers) by the file that made
                         it; every file after it takes CreateFrame and C_Timer
                         from here, one line
    Core/Fonts.lua       the typefaces BeebMod can use (a list, one line a
                         face), and its own font objects, set in the chosen one
    Art/Fonts/           Google Sans, Google Sans Flex (static cuts), Fira Code,
                         and the Expedition card's Josefin Sans, Poiret One and
                         Alegreya Italic, each with the SIL Open Font License
                         beside it
    Art/Cards/           the Expedition card's ornaments, white and tinted for
                         each mastery metal (scripts/make-cards.lua, in Lua)
    Art/Ranks/           the ten Expedition rank badges, drawn in
                         scripts/rank-badges.html and cut into textures by
                         scripts/make-badges.py (headless Edge and Pillow)
    Art/Dock/            the shields at the start of the Level, reputation and
                         PvP lines, in layers: a field the game tints, a rim,
                         a banner and swords, and a rim for each ten-level
                         bracket (level1 to level7; the same script)
    Modules/Expedition/LoreData.lua
                         the cards' lore: short descriptions from Warcraft Wiki
                         pages (https://warcraft.wiki.gg) on every enemy of every
                         Classic zone, dungeon and raid, and on the races,
                         animals, beast families and creature types they are.
                         A card shows the page titled with the enemy's whole
                         name, then its model's page, its family's and its
                         type's. Text under CC BY-SA 3.0,
                         credited on the Expedition's settings page. scripts/fetch-lore.ps1
                         writes it. The script keeps what it fetched and asks
                         the wiki only for what is new; -Rebuild writes the
                         file again from what it kept, asking only for enemies met
                         since. scripts/lore-curated.json holds the text checked
                         by hand against docs/lore-rules.md, and the script
                         uses it in place of the wiki's. An entry there with a
                         "kind" is a whole page written by hand, such as Satyr
    Modules/Expedition/BodyData.lua
                         what each model file is, by its folder in the
                         community listfile: creature/harpy is a harpy.
                         Written by scripts/make-bodies.lua, which says how to
                         get the listfile
    Art/Patterns/        a tiling texture for each debuff type (magic sparks,
                         curse smoke, poison bubbles, disease spores, bleed
                         drips), so you can tell a dispel mark by its shape as
                         well as its colour
    Art/Rank/            the Art Deco corner and crest round an elite or rare
                         enemy's frame, gold or silver (scripts/make-rank.py)
    Art/icon.tga         BeebMod's picture in the AddOn list
                         (scripts/make-addon-icon.ps1)
    Art/crosshair.tga    the resource display's crosshair, white, tinted green,
                         red or dim (scripts/make-crosshair.py)
    Art/reach-melee.tga  its crossed swords and no-action sign, white, tinted
    Art/reach-close.tga  (scripts/make-reach-icons.lua)
    Art/tipicons.tga     the unit tooltip's row pictures: a quest mark, a paw,
                         a quotation mark, a tag, two people, a star, crossed
                         swords and a banner (scripts/make-tip-icons.py)

## Tests

    lua tests/run.lua     the pure-Lua half: keys, the book, modules, migrations
    lua tests/load.lua    loads every file in TOC order with WoW stubbed, then
                          opens the window, clicks the switches and the dock

Both must pass before anything is installed. `load.lua` answers only real
widget methods, so a typo fails there and not in the game.

## Releasing

A version is `MAJOR.MINOR.PATCH-beta.N` while the client is in beta.
`CHANGELOG.md` keeps what has changed since the last one under
`## Unreleased`. To cut one, with everything committed:

    powershell -ExecutionPolicy Bypass -File scripts\cut-release.ps1 -Version 0.1.0-beta.2
    git push origin main v0.1.0-beta.2

The script refuses a dirty tree or a failing test. It writes the version into
the TOC and `Core/Init.lua`, turns `## Unreleased` into `## 0.1.0-beta.2`,
commits and tags. Pushing the tag runs `.github/workflows/release.yml`. That
runs the tests again, checks that the tag and the TOC agree, then runs the
BigWigs packager. The packager zips the addon without its tests, scripts and
docs (`.pkgmeta`) and publishes it with that version's changelog section as
its notes.

It goes to:

- **GitHub Releases**.
- **CurseForge**, project 1711982. The packager finds the project by the
  `## X-Curse-Project-ID` line in `BeebMod.toc`, and signs in with the
  repository secret `CF_API_KEY`. A tag with `beta` in it goes up as a beta
  file.

`.github/workflows/tests.yml` runs both suites on every push to `main`.

## The unit tooltip has one hook

Three modules change it. **Tooltips** rebuilds it in a compact form, the
**Ledger** adds your note and your tags, and the census adds the guild someone
was in before. If each hooked `GameTooltip` on its own, they would run in
whatever order the files loaded, and the rebuild would wipe out the others'
lines. So `Core/Tooltip.lua` hooks it once and calls each module in a fixed
order (Tooltips at 0, the Ledger at 20, the census at 30). It skips any module
that is switched off, so you can switch any one off and the others work as
before.

Tooltips rebuilds the tooltip instead of hiding lines. Calling `ClearLines`
and starting again is the only way to make a tooltip shrink, because a blank
line still takes up its height.

It has five parts, from the tooltip canvas Josh picked on 2026-10-17
("C, everything as tags"):

- a **header**: the name, biggest, in class colour, with the level opposite.
  Elite, Rare or Boss is a gold or silver tag before the level.
- **tags**, straight under the name: what they are in grey (a player's race,
  or a creature's type and family) and what state they are in, two or three
  in all on most tooltips (Josh: "I think we should only have 2-3 tags per
  tooltip on average"). Only the states you act on have a colour: PvP red,
  Skinnable tan; Dead and Tapped are a quieter grey. A tag is a box and a
  word of BeebMod's own, laid over a line the tooltip keeps for it, because
  a tooltip line is one size of text. A player's class is the client's own
  class icon before their name (`classicon-<class>`, as markup in the name's
  text), and a class tag only where the client has no such icon. The race
  is the word `UnitRace` gives, "Skyborne", and not the client's longer
  "High Order Skyborne" (Josh: "is it possible to just say "Skyborne"?").
- **who they are with**: a player's guild or an NPC's job, in guild green, as
  `<Codex>` or `<Banker>`, on a line under the tags.
- **rows**: one thing each, led by a small picture in its owner's colour
  (`Art/tipicons.tga`): a quest objective with its count (the quest's name
  only when there are two quests), your kills of an enemy and its next
  mastery, and the Ledger's note (two lines at most, in italics), tags,
  rating, groups, duels and former guild.
- **small print**: anything else the client said, such as a reputation
  faction or Tameable, the short ones on one line between dots.

Something alive you can attack also gets its health as a two-pixel line
along the bottom. The client keeps the number from addons, so the line is a
bar of BeebMod's own that is handed the secret value as it comes. A player's
tooltip has their side's crest behind its right half: the client's own logo
(`Interface\Timer\Horde-Logo`, `Alliance-Logo`, which this client's Inspect
window draws 256 pixels wide), added to the fill, so it can only lighten it.
It is meant as a faint background. Each side has its own
strength (`M.CREST_LOOK`), because the art is not alike: the Alliance's pale
lion is greyed, tinted blue and added at 12%; the Horde's dark mark keeps its
own red, which is bright in thin strokes, and is added at 15%. Measured from
screenshots, the two came out about even at 12% and 8%, but faint red hardly
shows on the fill's green-grey, so the Horde's was raised by eye. It is as big as half the card and
runs a little past the right edge. A texture is not clipped by the frame it
sits on, so the part past the card's edges is cut off with its texture
coordinates, and laid again whenever the card changes size.

Items, spells and buffs are written again as cards of one shape (`card` in
`Modules/Tooltips/Tooltips.lua`): the icon with the name and a line under
it, two figures at their right, the facts in cells, then rows. The client hands each line
with its kind (`tooltipData.lines[i].type`), but a spell's cost, range, cast
time and cooldown come as plain lines of two halves, so each half is read by
the client's own sentence for it (`SPELL_RANGE`, `SPELL_CAST_TIME_SEC`, …). A
line nothing reads stays a row, as the client wrote it. A spell's amount is
only in its description's words, so it is read with patterns (`M.AMOUNTS`:
absorb, then heal, then damage, since all three can say "damage").

A spell's card follows option D of the spell canvas's redesign, as Josh
chose it: the icon, the name and the rank and range as before; DPS or HPS
and what it does per point of its cost at the right of the name and the
rank, plain and right-aligned, each a number in its colour
(`M.FIGURE_INK`) and a small label, in FontStrings of BeebMod's own laid
against a blank kept at the right of those two lines; and the facts (the
amount, cost, cast and cooldown) in cells with lines between them in the
rim's colour, drawn by BeebMod over a line kept as tall as their rows
(`c.cells`, wrapped by `T.Measure` before the tooltip is shown). A macro's
tooltip is written as its spell's when its first line is not an item's;
where its first line only names the spell (`tooltipType`, `tooltipID`), the
spell's own tooltip is fetched and read. A buff's card has the same
cells, with the time it has left as a fact. An item's card has the same
figures and cells, as Josh chose them on 2026-10-18 (`M.ItemFigures`,
`M.ItemFacts`, and `M.FactCells` for both kinds): a weapon's DPS or
armour's armor beside the name, the item level beside the line under it,
and the damage, speed, binding and level needed in cells. An item with a
Use line that says an amount (a bandage, a potion, food or drink) has that
line's figure where a weapon has its DPS (`M.UseFigures`), its amount and
cooldown in cells, and no Use line when the line says no more than the
cells (`M.SaysNoMore`). On an Equipped tooltip, the client's
"If you replace this item..." lines, written after the card, are folded
into it afterwards by a hook on `TooltipComparisonManager.SetItemTooltip`
(`M.FoldDelta`). A next-swing ability (Heroic Strike, Maul) counts only
its bonus over the swing it replaces. DPS goes by what runs out first. A mana spell's
is the middle of its range divided by the cast time, an instant taking the
1.5 sec global cooldown; where the words straight after the amount say it
works over time ("over 18 sec", "each second for 3 sec"), it is over that
time instead, and a channel's seconds are that time too. "Every 3 sec" with
no length gets none. An energy ability's is its damage per energy times the
energy coming back a second (`GetPowerRegen` while the player uses energy,
else 10), with its damage per energy beside the rank. A rage ability's is per second of the global
cooldown, as a mana spell's, and keeps its damage per rage beside the rank;
one on the next swing ("Next melee", "Next ranged") is per second of the
swing (`UnitAttackSpeed`, `UnitRangedDamage`). An attack that adds to your weapon ("3 damage in
addition to your normal weapon damage", "150% weapon damage plus 15") has
the weapon's own hit from `UnitDamage` added in (`M.WEAPON_AMOUNTS`): the
character sheet's damage, attack power and buffs included, before crits,
talents and armour. Its middle is worked out from the weapon's own figures,
not from the rounded ends of the range. A description is
left out when it says no more than the line (`M.SaysNoMore`: one sentence,
nothing after the amount but a length of time, and none of the words that
say it reaches more than its target, such as "yards" or "party"). The
Testing page's Record keeps the last six of each kind as the client sent
them, under `tooltipsDump`.

The tags, the cards' figures and cells, and the health line sit on frames of BeebMod's
own over the tooltip. Each is marked `beebs`, because the Equipped tooltip's
tab is found by looking for a child frame with words and art on it, and a
BeebMod frame taken for the tab was given a fill over every line.

BeebMod sets the sizes on Blizzard's own FontStrings, which every other
tooltip in the game shares, so `Core/Tooltip.lua` puts them all back as soon
as the tooltip hides.

It also has the window's look: the same flat fill and one-pixel rim, with the
spine down the left in the class or reaction colour of whoever you are
pointing at. The client's border is a `NineSlice`, a child frame that draws
over anything put on the tooltip itself. So BeebMod hides it instead of
covering it, and shows it again when you switch the module off. Every tooltip
gets the look, because a hidden border with nothing in its place leaves text
floating on the screen. The spine's colour comes from what the tooltip shows:
a unit's class or reaction, an item's quality, a debuff's type.

## One panel

BeebMod puts one thing on screen, the **dock**.

    BeebMod [cog]                              1:33pm
    ------------------------------------------------
    [10] Level 10                        1h 17m to 11
    ...
    QUESTS  4
    ...

At the top is the header: BeebMod's name, the cog beside it, and the clock at
the right end. The cog opens the settings. It stays when everything else is
switched off, so you can always find your way back in. Under the header are
whatever **sections** the modules have to show. The quest tracker is a
section. Anything else that needs space on screen all the time is a section
too.

    BT.Dock.Section(key, order)   a panel of your own under the header
    BT.Dock.MakeHandle(child)     let something in it drag the whole dock
    BT.Dock.HeaderItem(frame)     something small at the header's right end

Everything in the dock takes mouse clicks, so no bare part of the panel is
left to drag. To move it, hold Shift and drag the header, a meter's line, a
readout or a zone heading in the quest list. A plain drag scrolls the
quests. The dock starts
under the minimap and stays wherever you drag it.

The dock decides where it sits, how big it is and how it looks. A module
decides what goes in its section and how tall that comes out (`wantHeight`,
`wantWidth`, then `BT.Dock.Relayout()`). With nothing else in it, the dock is
its header.

The dock never runs off the bottom of the screen. It has the room from its top
edge down. When its sections want more than that, a section marked `shrinks`
gives up the difference, never going below its `minHeight`, and `Fit(height)`
tells it the height it got. Only the quest list shrinks. It scrolls under a
fixed QUESTS line, with a scroll bar at the right edge.

## The spine

Tooltips have a three-pixel edge down the left side, coloured by the thing
you are asking about. On a person it is their class, or red when they are
hostile. On an item it is its quality (grey, white, green, blue, purple), and
on a debuff its type. It replaced a bar across the top and two hairlines, and
saves five pixels of height on every tooltip in the game.

## BeebMod draws its own quest tracker

The first version restyled the client's tracker. It still looked like the
client's tracker, only darker. It had orange titles, round map icons, two
collapsing headers, and a panel the height of the screen whether it held four
quests or none. Restyling can't fix a layout.

So BeebMod hides the client's tracker and draws the quests itself, in one
column, in its own typeface.

    * [7] Evershine              the mark, the level, the name
        Get a cask of Evershine
        1/1 Sunhammer's Rifle    done: struck through, still readable

The mark at the start of a quest is the client's own marker for the quest you
are following. Click it and the map points at that quest. It is a dot while
the quest is in progress, jade when it is the one you are following, and a
green check when it is ready to hand in. Click the quest itself to open the
log at it. Shift-click it to stop following it.

A quest that gives you an item to use gets a secure button for it at the
right end of its title, with the item's picture, charges, cooldown and
tooltip. Click the button to use the item. The game lets addons change a
button's item only out of combat. If a row's item changes in a fight, BeebMod
hides the button and puts it back when the fight ends. This client's tracker
has no progress bars. If a later build adds them, the tracker needs work to
show them.

`Modules/Tracker/Quests.lua` reads the quest log and has no frames in it. It
tries `C_QuestLog` first and the vanilla globals second, so the headless tests
can read a whole quest log.

## Where the names come from

| Source | What it gives |
|---|---|
| Damage meter sessions | updates characters already known, from the fight that just ended |
| Your target's target, your mouseover's target, your group's targets | full unit data for players you never clicked |
| Answers to a `/who` you typed | level, guild, zone, class and race, up to about 49 at a time |
| Friends list | name, level, class and where, whenever it refreshes |
| Battleground scoreboard | forty players with class, race and faction in one table |
| Mail senders, channel lists (after a `/chatlist`) | names you might not see anywhere else |
| Chat (say, yell, channels, guild, party, whispers) | name and GUID for everyone talking |
| Nameplates, mouseover, target, party and raid | class, race, level and guild: the full record |
| Guild roster | your own guild, including offline members |

A chat event carries the sender's name and GUID, but no class or race.
`GetPlayerInfoByGUID` gives both from the GUID, which is how the chat frame
colours a sender's name by class. BeebMod looks up every chat sighting that
way as it arrives. Once a session, soon after login, BeebMod also looks up
anyone already in the book who has a GUID but no class. This can't give a
level. Only seeing someone, or a `/who` row you ran yourself, gives a level.

There is no combat log source. This client doesn't let addons register
`COMBAT_LOG_EVENT_UNFILTERED`. Registering it raises `ADDON_ACTION_FORBIDDEN`
and the "blocked from an action only available to the Blizzard UI" popup.
Instead, BeebMod reads names and classes from `C_DamageMeter`'s combat
sessions when combat ends. That finds fewer people, only the players the meter
counted, but it causes no popup and no taint.

BeebMod never sends `/who`. A `/who` goes to the server, which limits how
often you can ask, and sending it automatically is the one part of an addon
like this that can get you in trouble. This client blocks the call anyway
(see below). A `/who` you type yourself fills a list the client already
holds, and BeebMod reads that like any other.

BeebMod writes a player down at most once a minute, so a fight with forty
players costs one table lookup per meter row instead of one write.

## What ages, and how BeebMod shows it

Only meeting a character again updates what BeebMod knows about them. So
every field keeps the time it was seen. A level more than half a day old
shows as a floor ("3+"). The tooltip never repeats level or guild, because
the unit in front of you already shows those.

There is no spec chart. Nothing shows a stranger's talents, and inspecting
needs them targeted and in range. The last chart shows your own tags
instead, and it hides when the Ledger is switched off.

The charts show what BeebMod doesn't know. The class chart has "Unknown" as
its own grey row, so it counts every character in the book and shows how much
of the realm you have identified. The race and level charts leave those
characters out, because an unknown bar in all three would count the same
people three times. Each of them says so under its bars, for example "70
with no race on file".

## No /who

`C_FriendList.SendWho` is protected on this client. Calling it raises
ADDON_ACTION_BLOCKED ("Interface action failed because of an AddOn") and no
query goes out. Nothing in BeebMod sends one. The book holds only what the
client tells BeebMod without being asked, and that includes the answer to a
`/who` you ran by hand (`WHO_LIST_UPDATE`, read in
`Core/Collect/Rosters.lua`).

So a character heard only in chat stays a name with no class, race or level
until you see them. The census charts show that gap.

## Notes on the client

Built against the beta's builds from 1.60.1.70009 to 1.60.1.70450
(`wow_classic_beta`). The TOC says
`## Interface: 16001`, checked in the game with
`/dump select(4, GetBuildInfo())` on build 1.60.1.69893. The client writes
1.60.1 as 1-60-01, not 11600. A beta build can change it. If the addon ever
shows as out of date, check it again. The tooltip hook works with either the
newer `TooltipDataProcessor` or the old `OnTooltipSetUnit`, whichever the build
has.

## Saved variables, and the beta bug that lost them

**Fixed in build 1.60.1.70009 (2026-09-24).** Up to that build the client
wrote `SavedVariables` on every logout and `/reload` and never read them back,
for every addon ([forever-bugs #34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34),
and `docs/beta-bug-savedvariables.md`). On 70009 a test addon got its table
back on a fresh launch and on a `/reload`. So the book now loads the normal
way, and none of the workaround is left in the addon.

**The workaround, for the record (2026-09-22 to 09-24).** `Data/Live` was a
directory junction to `WTF/Account/<account>/SavedVariables`, and the TOC
listed `Data\Live\BeebMod.lua` first, so the client ran its own last save as
an addon file. [ForeverSVFix](https://github.com/nobewayo/ForeverSVFix) does
the same. Before that (09-19 to 09-22) BeebMod kept the book in a generated
`Data/Baked.lua`. The code for both was removed on 2026-10-17.

**At launch the beta's records go.** The census, the Ledger, the
Expedition and every record kept for one character file what they keep
under the realm's name, and every beta realm has "Beta" in its name
("Classic Beta PvE 2"). A launch client in its own game folder starts with
an empty saved file, but a player can copy the old `WTF` folder across. So
the first time you log in to a realm without "Beta" in its name,
`BT.DropBeta` in `Core/Init.lua` drops everything filed under a beta realm:
the characters seen, the notes and tags on them, every kill, both journals'
ranks and commendations, and each beta character's XP, reputation, gold,
clock, PvP and pickpocket records. An enemy stays only if a character on a
launch realm has killed it. Settings stay, and so do the tags you created. On a beta realm, or on a client where `IsBetaBuild()` is true,
nothing is dropped. What loaded, on the Testing page, says which way it went.

`scripts/backup-book.ps1` copies the save into `LedgerBackups`.
`scripts/restore-book.ps1` puts one back. It refuses while the game is running,
because the game's next save would overwrite it.

## Later

- Sharing notes with guild members, opt-in, most likely as export and import
  strings before anything live.
- Seen-online history, so the book can answer "when is this person usually on".
- More utilities. Each new one is a file and a `BT.Module` call instead of
  another addon to install.
