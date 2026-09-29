# BeebMod

Small utilities for WoW: Forever. You set them all in one window, and the cog
in the dock opens it.

    /bt            open the window
    /bt <name>     find someone
    /bt help       list every command, including each utility's own

## Features

BeebMod has six features, and each has one switch. On your first login it
asks which ones you want. It shows six cards, each with a picture and a line
on what the feature does. In the settings window each feature has a block of
tabs in its own colour, with the feature's switch on the block's heading.
Switch a feature off and everything in it goes off. Each part in it keeps its
own switch, and the setting stays as you left it while the feature is off. No
feature needs another.

The **core** is what every feature would otherwise build for itself: the
settings window, the dock's header, the look of a button and a pill, and
**General** (the colours of every panel; the typeface is Google Sans). The
dock's logo and cog are always on screen. With the Dock off, or every feature
off, they are all that BeebMod shows. Click the cog to get back to the
settings.

**Dock** is the panel at the side of the screen and what is in it.

| tab | what it is |
|---|---|
| **Dock** | The panel itself: its size, and the **Clock** in its header. The clock shows local or server time; click it to switch. |
| **Minimap** | The client's map, moved into the dock, and **Addon buttons**: other addons' minimap buttons in one line, a switch each. |
| **Progress** | **Experience** (the XP bar, and time to level at your current pace), **Reputation** (the watched faction, and your standing with it) and **PvP** (your PvP rank with its insignia, how far to the next, and this week's honor), a switch each. Each line starts with a shield: your level on it, a banner, or your rank. |
| **Metrics** | A grid of readouts, each with its own switch: gold and gold per hour, bag space and your class's reagents, durability, average item level, pick-pocket takings (rogues), movement speed, frame rate and latency. |
| **Quest tracker** | BeebMod hides the client's tracker and draws your quests in the dock, under their zones, lowest level first. |
| **Micro menu** | The game's menu buttons, in the dock. |

**Unit frames** are what you watch in a fight.

| tab | what it is |
|---|---|
| **Unit frames** | You at the top of the party column, even alone, and each member with a pet slot and their target beside them. Target, focus, raid, main tank and boss frames, and your own cast bar. Icons for resurrection, summons and master looter, your threat on the target, and a hunter pet's happiness. One Size setting covers them all. Shift-drag a block to move it, and Reset on the page puts every block back. Made-up people, on the Testing page, shows a made-up party or raid. Switch them off, or one kind off, and the game's own frames come back. |
| **Buffs** | Your buffs, debuffs and weapon enchants in a tray beside the dock, in two lines. The soonest to run out are at the left, and the permanent ones sit against the dock, A to Z. Switch it off and the game's buff bar comes back. |
| **Resource display** | Your own nameplate, flat, with combo points under it (rogues, cat druids). |
| **Damage meter** | The client's own meter, flat, with each row's amount per second and the fight's length. |

**Interface** is the game's own windows and menus, drawn to match BeebMod.

| tab | what it is |
|---|---|
| **Action bars**, **Bag window**, **Chat** | The client's own, flat like the rest of BeebMod. Every button still does what it did. You drag the bag window by its title and it stays where you leave it. Your four bag slots, the reagent bag's and the keyring sit in a row across the foot of the backpack. Drag a bag onto a slot to put it on, or off one to take it out. Its page has the switch that hides the game's bag bar. |
| **Character sheet** | Item level on every slot, short stat lists with sections that fold, and BeebMod's look. |
| **Menus** | The **Game menu** that Escape opens, and every **Dropdown menu**, a switch each. The game keeps some of its menu buttons from addons, so those keep the game's look. |
| **Tooltips** | Unit tooltips rebuilt into two lines, in BeebMod's look. Elites and rares get a gold or silver border. |

**Census** is a record of every character you see, with charts of the realm
by class, race, level, guild and zone, in a window of its own. Open it from
the dock's header, or type `/bt census`. BeebMod never shares it. It holds
only the people you saw.

**Ledger** keeps notes, tags and a rating on the people you meet. They show
on the person's tooltip and in the target row at the top of the dock. Its
page searches the people you wrote about, and with the Census on, everyone
the Census knows. The Ledger keeps what you write in its own book
(`BeebModDB.ledger`), so it doesn't need the Census.

**Nesingwary's Expedition** is a journal of every enemy you have
killed. Each has a card with its model, its lore from the Warcraft Wiki
and its mastery. On its page, a Model · Map switch shows the zone's map with
a dot for each place you killed it, or a dungeon's loading screen. Every unique kill and every commendation is worth points. The
points set your rank, from Greenhorn to Expedition Leader. A line in the
dock shows your points and rank. Click it to open the journal, or type
`/bt expedition`.

**Made-up data** is for screenshots. A switch on the Testing page, or
`/bt demo`, shows a made-up realm, notes, a journal and a party in every
feature at once. BeebMod saves none of it.

**The Testing page** is also where the debug tools are. Its buttons show a
sample mastery toast, print BeebMod's reports to chat (What loaded, Over-time
bars, The book), and write records for Claude into the saved file. Record
writes down how the game built each part you have on, and also the next menu
you open and your next fight. Clear takes the records out again. CPU use times
BeebMod for 10 seconds. Type `/reload` after a record to save it.

### Adding a utility

A utility is one file and one call, which give it a tab and a place on the
bar.

```lua
local M = BT.Module({
    key = "myutility", title = "My Utility", order = 30,
    feature = "dock",   -- the feature it belongs to; its switch covers this too
    blurb = "One line, shown on the tab and in Settings",
})
function M:BuildTab(parent) ... end    -- built once, the first time it opens
function M:Cells() return { ... } end  -- what it adds to the dock
function M:OnBind(db) ... end          -- the settings are bound: migrate, sweep
BT.Command("mycmd", function(rest) ... end, "what it does", "myutility")
BT.Record("myutilityDump", M.Dump, "myutility")  -- a record for the Testing page
```

A command is for something you type, such as a name or a number of days. A
debug tool is a button on the Testing page instead. A dump of the game's
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
                         and Pick Pocket: when one starts, and its pace an hour
    Core/DB.lua          one row per character: read, write, merge, prune
    Core/Collect/        what the client tells BeebMod without being asked
    Core/Slash.lua       /bt, /bt help, and What loaded for the Testing page
    Core/Boot.lua        the core's own login: the settings, the dock, then BT.OnWorld
    Core/Demo.lua        made-up data for screenshots: one switch, each feature's own
    UI/Window.lua        the window: a block per feature down the side, a page per tab
    UI/Welcome.lua       the first login's six cards, a switch per feature
    UI/Settings.lua      General: the look, and the panel header's switches
    UI/Dock.lua          the dock: a row of cells, and sections under it
    UI/Pill.lua          the pill, and the one place a measurement is judged
                         good or bad
    UI/Tip.lua           the tooltip frame every cell in the dock shares
    UI/Widgets.lua       buttons, switches, panels, and the rows and sections
                         every settings page is built from
    UI/Ornament.lua      the Art Deco border an elite or a rare gets, on its
                         unit frame and on its tooltip
    Core/Tooltip.lua     one hook on the unit tooltip, shared by several modules
    Core/Furniture.lua   restyles the client's own frames by what each one is
    Modules/Ledger/      its own book of notes (Store.lua), tags, the Find tab,
                         the notes on a tooltip
    Modules/Minimap/     the map in the dock; Modules/Buttons/ the addon buttons
    Modules/XP/, Rep/, PvP/
                         the experience, reputation and PvP lines of the dock
    Modules/Metrics/     the readout grid; Currency/, Bags/, Durability/,
                         ItemLevel/, Pickpocket/, Speed/ and Performance/ are
                         its rows
    Modules/Clock/       the time in the dock's header
    Modules/Census/      the counting and the charts
    Modules/Tooltips/    the compact tooltip, and its switches
    Modules/Tracker/     the quest tracker in the dock (Quests.lua reads the log)
    Modules/Bars/, BagWindow/, Chat/, DamageMeter/, Dropdowns/, Micro/
                         the client's own frames, drawn flat
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
                         a banner and swords (the same script)
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
                         mob's frame, gold or silver (scripts/make-rank.py)

## Tests

    lua tests/run.lua     the pure-Lua half: keys, the book, modules, migrations
    lua tests/load.lua    loads every file in TOC order with WoW stubbed, then
                          opens the window, clicks the switches and the bar

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

- **GitHub Releases**, always.
- **CurseForge**, once it is set up. Create the project, put its id in
  `BeebMod.toc` as `## X-Curse-Project-ID: <id>`, and add a CurseForge API
  token as the repository secret `CF_API_KEY`. Until then the packager skips
  it. A tag with `beta` in it goes up as a beta file.

`.github/workflows/tests.yml` runs both suites on every push to `main`.

## The unit tooltip has one hook

Two modules change it. **Tooltips** rebuilds it in a compact form, and the
**Ledger** adds your note and your tags. If each hooked `GameTooltip` on its
own, they would run in whatever order the files loaded, and the rebuild would
wipe out the Ledger's lines. So `Core/Tooltip.lua` hooks it once and calls
each module in a fixed order (compose at 0, decorate at 20). It skips any
module that is switched off, so you can switch either one off and the other
works as before.

Tooltips rebuilds the tooltip instead of hiding lines. Calling `ClearLines`
and starting again is the only way to make a tooltip shrink, because a blank
line still takes up its height.

It has four parts:

- a **header**: the name, biggest, in class colour, with the level opposite,
  and a hairline under it
- a **subheader**: what they are, small and grey
- the **body**: your note, in quotes and a shade warmer (this client has no
  italic face, so the quotes mark it)
- a **footer**: the tags, smaller again, under a second hairline

BeebMod sets the sizes on Blizzard's own FontStrings, which every other
tooltip in the game shares, so `Core/Tooltip.lua` puts them all back as soon
as the tooltip hides.

It also has the window's look: the same flat fill and one-pixel rim, with the
spine down the left in the class or reaction colour of whoever you are
pointing at. The client's border is a `NineSlice`, a child frame that draws
over anything put on the tooltip itself. So BeebMod hides it instead of
covering it, and shows it again when you switch the module off. Every tooltip
gets the look, because a hidden border with nothing in its place leaves text
floating on the screen. Only unit tooltips get the coloured spine.

## One panel

BeebMod puts one thing on screen, the **dock**.

    [class] Beeb Magus                  [tags] [cog]
    "held the door while I ran back"
    ------------------------------------------------
    QUESTS  4
    ...

At the top are two lines. The first says who you are pointing at, and the
second shows their tags and your note. Under them are whatever **sections**
the modules have to show. The quest tracker is a section. Anything else that
needs space on screen all the time is a section too.

The second line shows the note itself, in words, so you don't have to hover
over an icon to read it. It keeps its height whether or not it has anything on
it. If the dock grew a row whenever you pointed at somebody you had written
about, it would push the quest log down the screen while you were reading it.

The first slot is BeebMod's glyph until you target a player. Then it shows
their **class**. It can't show their spec, because nothing on this client
shows a stranger's talents; the census has no spec chart for the same reason.
The cog sits at the right end, apart from the other cells, because it opens
the settings, and you need to find it with everything else switched off.

    BT.Dock.Cell(key, width)      a cell on the row
    BT.Dock.Section(key, order)   a panel of your own underneath it
    BT.Dock.MakeHandle(child)     let something in it drag the whole dock

Everything in the dock takes mouse clicks. The row is cells you click and the
tracker is quests you click, so no bare part of the panel is left to drag. The
mark and the tracker's QUESTS line are the drag handles. The dock starts under
the minimap and stays wherever you drag it.

The dock decides where it sits, how big it is and how it looks. A module
decides what goes in its section and how tall that comes out (`wantHeight`,
`wantWidth`, then `BT.Dock.Relayout()`). With the top row switched off, the
dock stays for the sections. With nothing in it at all, it hides.

The dock never runs off the bottom of the screen. It has the room from its top
edge down. When its sections want more than that, a section marked `shrinks`
gives up the difference, never going below its `minHeight`, and `Fit(height)`
tells it the height it got. Only the quest list shrinks. It scrolls under a
fixed QUESTS line, with a scroll bar at the right edge.

## The spine

Tooltips and the quest tracker both have a two-pixel edge down the left side,
coloured by the thing you are asking about. On a person it is their class, or
red when they are hostile. On an item it is its quality (grey, white, green,
blue, purple). On the tracker it is BeebMod's jade. It replaced a bar across
the top and two hairlines, and saves five pixels of height on every tooltip in
the game.

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
needs them targeted and in range. The fourth chart shows your own tags
instead, and it hides when the Ledger is switched off.

The charts show what BeebMod doesn't know. The class chart has "Unknown" as
its own grey row, so it counts every character in the book and shows how much
of the realm you have identified. The race and level charts leave those
characters out, because an unknown bar in all three would count the same
people three times. Each of them says so, for example "125 of 195 characters;
70 have no race on file".

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

Built against build 1.60.1.70009 (`wow_classic_beta`). The TOC says
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
`Data/Baked.lua`. `BT.Adopt` and `BT.linked` in `Core/Init.lua` stay in case a
later build loses the book again. While the book loads normally they do
nothing.

`scripts/backup-book.ps1` copies the save into `LedgerBackups`.
`scripts/restore-book.ps1` puts one back. It refuses while the game is running,
because the game's next save would overwrite it.

## Later

- Sharing notes with guild members, opt-in, most likely as export and import
  strings before anything live.
- Seen-online history, so the book can answer "when is this person usually on".
- More utilities. Each new one is a file and a `BT.Module` call instead of
  another addon to install.
