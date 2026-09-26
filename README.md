# BeebMod

A set of small utilities for WoW: Forever, behind one window and one button.

    /bt            the window
    /bt <name>     find someone
    /bt help       every command, including the ones each utility adds

## The shape of it

The **core** owns the parts every utility would otherwise reinvent: the window
with the tabs down its left side, the dock, the look of a button and a
pill, and **the book** - every player this client has told us about, kept once
and shared.

A **module** is a utility. It registers a tab, perhaps some cells in the dock
and its own slash commands, and it can be switched off on its tab without the
rest noticing. The tabs down the window's left side come in three groups.

The settings window's rail is in four groups, by what things are for, after
**General** (the colours of every panel; the typeface is Google Sans).

**Dock** - the panel at the side of the screen, and what is in it:

| tab | what it is |
|---|---|
| **Dock** | the panel itself: its size, and the **Clock** (local or server time; click it to switch) and **Census** button in its header |
| **Minimap** | the client's map, moved into the dock, and **Addon buttons** - other addons' minimap buttons, gathered into a line (a switch each) |
| **Progress** | **Experience** (the XP bar, and time to level at your current pace), **Reputation** (the watched faction, and time to the next standing) and the **Menagerie** (every kind of mob you have killed, with a count and a model of each, filed by creature type; achievements are the score, and a line of the dock shows your points - click it for the journal), a switch each |
| **Metrics** | one grid of readouts, each switched on its own: gold and gold per hour, bag space and your class's reagents, durability, average item level, pick-pocket takings (rogues), movement speed, frame rate and latency |
| **Quest tracker** | the client's tracker is hidden and this one draws your quests in the dock, under their zones, lowest level first |
| **Micro menu** | the game's menu buttons, in the dock |

**Combat** - what you watch in a fight:

| tab | what it is |
|---|---|
| **Unit frames** | you at the top of the party column (alone too), each member with a pet slot and their target beside them; target, focus, raid, main tank and boss frames, and your own cast bar. Resurrection, summon and master looter icons, your threat on the target, a hunter pet's happiness; one Size setting for them all; shift-drag a block to move it; `/bt frames test` or `raid` previews a group. Switched off (or one kind switched off), the game's own frames come back |
| **Buffs** | your buffs and debuffs in a tray beside the dock, two lines: the soonest to run out at the left, the permanent ones against the dock, A to Z; weapon enchants too. Switched off, the game's buff bar is back |
| **Resource display** | your own nameplate, flat, with combo points under it (rogues, cat druids) |
| **Damage meter** | the client's own meter, flat, with each row's amount a second and the fight's length |

**Windows** - the game's own windows and menus, in the toolkit's clothes:

| tab | what it is |
|---|---|
| **Action bars**, **Bag window**, **Chat** | the client's own, flat like the rest of the toolkit; every button still does what it did. The bag window drags by its title and stays, and its page has the switch that puts the game's bag bar away |
| **Character sheet** | item level on every slot, compact stats with sections that fold, and the toolkit's look |
| **Menus** | the **Game menu** Escape opens (the game keeps some of its buttons from addons, so those stay its own) and every **Dropdown menu**, a switch each |
| **Tooltips** | unit tooltips rebuilt into two lines, in the toolkit's skin; elites and rares wear a gold or silver border |

**People** - the book:

| tab | what it is |
|---|---|
| **Ledger** | notes and tags on the people you meet, on their tooltip and in the target row at the top of the dock; the Find tab searches the book |
| **Census** | what the realm is made of - class, race, level and your tags - in a window of its own, opened from the dock's header |

The Ledger and the Census read the same book, which is why the book belongs to
the core: turning the Ledger off must not blind the Census, and turning the
Census off must not lose a note. With everything off the dock goes away - `/bt`
still opens the window - and it comes back a cell at a time as you switch
things on.

### Adding a utility

One file, one call, and it has a tab and a place on the bar:

```lua
local M = BT.Module({
    key = "myutility", title = "My Utility", order = 30,
    blurb = "one line, shown on the tab and in Settings",
})
function M:BuildTab(parent) ... end    -- built once, the first time it is opened
function M:Cells() return { ... } end  -- what it adds to the dock
function M:OnBind(db) ... end          -- a book was bound: migrate, sweep
BT.Command("mycmd", function(rest) ... end, "what it does", "myutility")
```

A hook that walks the book and **removes** anything belongs to the module that
owns that meaning, never to the core: a utility you have switched off must not
be tidying away data it is not currently showing you. That is why migrating tags
lives in `Modules/Ledger`, and why the Census can be off for a month without
losing a mark.

## Files

    Core/Init.lua        the module registry, settings, and the book
    Core/Util.lua        names, keys, staleness, colours
    Core/Session.lua     "this session" for Currency, Experience, Reputation
                         and Pick Pocket: when one begins, its pace an hour
    Core/DB.lua          one row per character: read, write, merge, prune
    Core/Collect/        what the client tells us unasked
    Core/Slash.lua       /bt, and the toolkit's own commands
    UI/Window.lua        the window: one rail in four groups, a page per tab (some shared)
    UI/Settings.lua      General: the look, and the panel header's switches
    UI/Bar.lua           the dock: a row of cells, and sections under it
    UI/Pill.lua          the pill, and the one place a measurement is judged
    UI/Widgets.lua       buttons, switches, panels, and the rows and sections
                         every page of settings is built from
    UI/Ornament.lua      the Art Deco border an elite or a rare wears, on its
                         unit frame and its tooltip alike
    Core/Tooltip.lua     one hook on the unit tooltip, several participants
    Core/Furniture.lua   dressing the client's own frames by what each piece is
    Modules/Ledger/      tags, the Find tab, the notes on a tooltip
    Modules/Minimap/     the map in the dock; Modules/Buttons/ the addon buttons
    Modules/XP/, Rep/    the experience and reputation lines of the dock
    Modules/Metrics/     the readout grid; Gold/, Space/, Durability/,
                         ItemLevel/, Pickpocket/, Speed/ and Perf/ are its rows
    Modules/Clock/       the time in the dock's header
    Modules/Census/      the arithmetic and the charts
    Modules/Tips/        the compact tooltip, and its switches
    Modules/Tracker/     the quest tracker the dock draws (Quests.lua reads the log)
    Modules/Bars/, BagWindow/, Chat/, DamageMeter/, Menus/, Micro/
                         the client's own furniture, flat
    Modules/CharSheet/   the character window
    Modules/PRD/         the personal resource display
    Modules/Frames/      the unit frames: one secure button drawn from secret
                         values it never reads, the groups without snippets, and
                         auras in the client's own containers (Auras.lua) - an
                         addon may not read an aura in a fight on this client -
                         and your buffs' tray beside the dock (Buffs.lua)
    Modules/Menu/        the game menu Escape opens, restyled (look only)
    Core/UnitProbe.lua   /bt unitprobe: what the client tells a unit frame
    Core/Cpu.lua         /bt cpu: times what runs by itself (updates, events,
                         timers) by the file that made it; every file after it
                         takes CreateFrame and C_Timer from here, one line
    Core/Fonts.lua       the faces the toolkit can write in (a list: one line
                         a face), and its own font objects, cut in the chosen one
    Art/Fonts/           Google Sans, Google Sans Flex (static cuts) and Fira
                         Code, each under the SIL Open Font License beside it
    Art/Patterns/        a tileable texture a debuff type (magic sparks, curse
                         smoke, poison bubbles, disease spores, bleed drips), so
                         a dispel mark is told by shape as well as colour
    Art/Rank/            the Art Deco corner and crest round an elite or rare
                         mob's frame, gold or silver (scripts/make-rank.py)
    Core/Profile.lua     /bt mem and /bt prof

## Tests

    lua tests/run.lua     the pure-Lua half: keys, the book, modules, migrations
    lua tests/load.lua    loads every file in TOC order with WoW stubbed, then
                          opens the window, clicks the switches and the bar

Both must be green before anything is installed. `load.lua` answers only real
widget methods, so a typo fails there rather than in front of you.

## Releasing

A version is `MAJOR.MINOR.PATCH-beta.N` while the client is in beta, and
`CHANGELOG.md` keeps what has changed since the last one under
`## Unreleased`. To cut one, with everything committed:

    powershell -ExecutionPolicy Bypass -File scripts\cut-release.ps1 -Version 0.1.0-beta.2
    git push origin main v0.1.0-beta.2

The script refuses a dirty tree or a red test, writes the version into the
TOC and `Core/Init.lua`, turns `## Unreleased` into `## 0.1.0-beta.2`, commits
and tags. Pushing the tag runs `.github/workflows/release.yml`: the tests
again, a check that the tag and the TOC agree, then the BigWigs packager,
which zips the addon without its tests, scripts and docs (`.pkgmeta`) and
publishes it with that version's changelog section as its notes.

Where it lands:

- **GitHub Releases**, always.
- **CurseForge**, once it is set up: create the project, put its id in
  `BeebMod.toc` as `## X-Curse-Project-ID: <id>`, and add a CurseForge API
  token as the repository secret `CF_API_KEY`. Until then the packager skips
  it. A tag with `beta` in it goes up as a beta file.

`.github/workflows/tests.yml` runs both suites on every push to `main`.

## The unit tooltip has one hook

Two modules want a say in it: **Tooltips** rebuilds it compactly, the **Ledger**
adds your note and your tags. Left alone they would each hook `GameTooltip` in
whatever order the files loaded, and the one that rebuilds would wipe the one
that decorates. So `Core/Tooltip.lua` hooks it once and hands it round in a
known order - compose at 0, decorate at 20 - skipping any contributor whose
module is switched off. That is why either can be turned off and the other
carries on exactly as before.

Tooltips **rebuilds** rather than hides: `ClearLines` and start again is the
only way to make a tooltip actually shrink, because blanking a line leaves its
height behind.

It reads as four things rather than four lines: a **header** (the name, biggest,
in class colour, with the level opposite), a hairline, a **subheader** (what they
are, small and grey), the **body** (your note, quoted and a shade warmer - there
is no italic face in this client, so the quotes carry it), and a **footer** (the
tags, smaller again, under a second hairline). The sizes are set on Blizzard's
own FontStrings, which are shared with every other tooltip in the game, so
`Core/Tooltip.lua` hands them all back the moment the tooltip goes away.

It also wears the window's skin - the same flat fill and one-pixel rim - with
the spine down the left in the class or reaction colour of whoever you are
pointing at, and a hairline under the name. The client's border is a `NineSlice`, a child frame that draws
over anything put on the tooltip itself, so it is hidden rather than covered,
and shown again the moment the module is switched off. Every tooltip gets the
skin, because a border hidden with nothing in its place is a floating block of
text; only unit tooltips get the accent.

## One panel

There is one thing on screen: the **dock**.

    [class] Beeb Magus                  [tags] [cog]
    "held the door while I ran back"
    ------------------------------------------------
    QUESTS  4
    ...

Two lines at the top - who you are pointing at, then their tags and your note -
and under them whatever **sections** the modules have to show. The quest tracker
is a section; anything else wanting permanent space on screen is a section too.

The second line is the note itself, in words rather than an icon you have to
hover to read, and it keeps its height whether or not anything is on it. A dock that
grows a row when you happen to point at somebody you have written about is a
dock that shoves the quest log down the screen while you are reading it.

The first slot is the toolkit's glyph until you target a player, and then it is
their **class** - not their spec: nothing reveals a stranger's talents on this
client, which is the same reason the census has no spec chart. The cog is
right-aligned, because it is the way out of everything rather than one more
cell in the queue.

    BT.Bar.Cell(key, width)      a cell on the row
    BT.Bar.Section(key, order)   a panel of your own underneath it
    BT.Bar.MakeHandle(child)     let something in it drag the whole dock

Everything in the dock takes the mouse - the row is cells you click, the
tracker is quests you click - so there is no bare panel left to grab. The mark
and the tracker's QUESTS line are drag handles instead. It opens under the
minimap and remembers wherever you drag it.

The dock owns where it sits, how big it is and what it is wearing; a module
owns what goes in its section and how tall that comes out (`wantHeight`,
`wantWidth`, then `BT.Bar.Relayout()`). Switching the top row off leaves the
dock there for the sections; with nothing in it at all, it goes.

The dock never runs off the bottom of the screen. It has the room from its top
edge down, and when its sections want more than that, a section marked
`shrinks` gives up the difference (never going below its `minHeight`) and is
told what it got through `Fit(height)`. Only the quest list shrinks: it scrolls
under a fixed QUESTS line, with a thumb at the right edge.

## The spine

One idea across both tooltips and the quest tracker: a two-pixel edge down the
left side, coloured by the thing you are actually asking about. On a person it
is their class, or red when they are hostile. On an item it is its quality -
grey, white, green, blue, purple. On the tracker it is the toolkit's jade. It
replaced a lid across the top and two hairlines, which is five pixels of height
back on every tooltip in the game.

## The quest tracker is ours

The first version restyled the client's. It came out looking like the client's
tracker in a dark coat - the orange titles, the round map icons, two collapsing
headers, and a panel the height of the screen whether it held four quests or
none. Styling cannot fix a layout.

So the client's is hidden and this draws it, one column, in the toolkit's type:

    * [7] Evershine              the mark, the level, the name
        Get a cask of Evershine
        1/1 Sunhammer's Rifle    done: struck through, still readable

The mark at the start of a quest is the client's own "which one am I doing":
click it and the map points at that quest. A dot in progress, jade when it is
the one you are following, a green check when it is ready to hand in. Click the
quest itself to open the log at it, shift-click to stop following it.

A quest that hands you something to use gets a secure button for it at the
right end of its title: picture, charges, cooldown, tooltip, click to use.
Which item the button holds can only change out of combat, so a row whose item
changed mid-fight puts the button away and catches up when the fight ends.
This client's tracker has no progress bars, and the day they arrive that is
the thing to revisit. `Modules/Tracker/Quests.lua`
holds the reading half and has no frames in it at all: it tries `C_QuestLog`
first and the vanilla globals second, so a whole quest log can be read in the
headless tests.

## Where the names come from

| Source | What it gives |
|---|---|
| Damage meter sessions | updates characters already known, from the fight that just ended |
| Your target's target, your mouseover's target, your group's targets | full unit data for players you never clicked |
| `/who` answers **you** ran | level, guild, zone, class and race, up to ~49 at a time |
| Friends list | name, level, class and where, whenever it refreshes |
| Battleground scoreboard | forty players with class, race and faction in one table |
| Mail senders, channel lists (after a `/chatlist`) | names you would otherwise never meet |
| Chat (say, yell, channels, guild, party, whispers) | name and GUID for everyone talking |
| Nameplates, mouseover, target, party and raid | class, race, level and guild — the full record |
| Guild roster | your own guild, including offline members |

**A GUID identifies its owner.** A chat event carries the sender's name and GUID but no class or race — except that `GetPlayerInfoByGUID` will tell you both, which is how the chat frame knows to paint a sender's name in class colour. Every chat sighting is resolved that way as it arrives, and `/bt identify` (also run once at login) walks anyone already in the book who has a GUID but no class. Level is the one thing this cannot give you: only seeing someone, or a `/who` row you run yourself, carries a level.

**There is no combat log source.** This client forbids addons `COMBAT_LOG_EVENT_UNFILTERED`: registering it raises `ADDON_ACTION_FORBIDDEN` and the "blocked from an action only available to the Blizzard UI" popup. `C_DamageMeter`'s combat sessions carry the names and classes instead, read when combat drops — a smaller net (only players the meter counted) but no popup and no taint.

`/who` is never **sent** by the addon. It asks the server, it is rate limited, and automating it is the one part of an addon like this that can get you in trouble - and on this client the call is blocked outright (see below). The answer to a `/who` you typed yourself is a list the client is already holding, and that is read like any other.

A player is written down at most once a minute, so a forty-player fight costs one table lookup per meter row rather than one database write.

## What ages, and how it says so

Nothing refreshes an observation but meeting the character again, so every field carries the moment it was observed and the display tells you how stale it is: the zone is dropped after 30 minutes, a level over half a day old shows as a floor ("3+"), and a guild older than a day says "as of 3 days ago". The tooltip never repeats level or guild — the unit in front of you is already telling you those.

There is no spec chart and cannot be: nothing reveals a stranger's talents, and inspecting needs them targeted and in range. Your own tags are the fourth chart instead, and it hides itself when the Ledger is switched off.

**Unknowns are visible, not hidden.** The class chart carries "Unknown" as its own grey row, so it accounts for every character in the book and shows how much of the realm you have actually identified. The race and level charts leave those characters out — an unknown bar in all three would be the same people counted three times — and each says so: "125 of 195 characters; 70 have no race on file".

## No /who

`C_FriendList.SendWho` is protected on this client: calling it raises ADDON_ACTION_BLOCKED ("Interface action failed because of an AddOn") and no query goes out. Nothing in the addon sends one — the book is built from what the client tells us unasked, which includes the answer to a `/who` you ran by hand (`WHO_LIST_UPDATE`, read in `Core/Collect/Rosters.lua`).

The consequence is that a character heard only in chat stays a name with no class, race or level until you actually see them. That gap is shown rather than hidden: see the census charts.

## Notes on the client

Built against build 1.60.1.70009 (`wow_classic_beta`). The TOC says `## Interface: 16001`, confirmed in-game with `/dump select(4, GetBuildInfo())` on build 1.60.1.69893 (the client packs 1.60.1 as 1-60-01, not 11600). A beta build can move it; if the addon ever shows as out of date, check it again. The tooltip hook works with either the modern `TooltipDataProcessor` or the old `OnTooltipSetUnit`, whichever the build has.

## Saved variables, and the beta bug that lost them

**Fixed in build 1.60.1.70009 (2026-09-24).** Up to that build the client
wrote `SavedVariables` correctly on every logout and `/reload` and never read
them back - for every addon ([forever-bugs #34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34),
and `docs/beta-bug-savedvariables.md`). On 70009 a probe addon got its table
back on a fresh launch and on a `/reload`, so the book now loads the ordinary
way and nothing of the workaround is left in the addon.

**The workaround, for the record (2026-09-22 to 09-24):** `Data/Live` was a
directory junction to `WTF/Account/<account>/SavedVariables`, and the TOC
listed `Data\Live\BeebMod.lua` first, so the client ran its own last save as
an addon file - the technique [ForeverSVFix](https://github.com/nobewayo/ForeverSVFix)
uses. Before that (09-19 to 09-22) the book rode in a generated
`Data/Baked.lua`. `BT.Adopt` and `BT.linked` in `Core/Init.lua` are left as a
net should a later build lose the book again; with the book arriving normally
they do nothing.

`scripts/backup-book.ps1` copies the save into `LedgerBackups`;
`scripts/restore-book.ps1` puts one back, and refuses while the game is running
because the next save would overwrite it.

## Later

- Sharing notes with guild members, opt-in, most likely as export/import
  strings before anything live.
- Seen-online history, so the book can answer "when is this person usually on".
- More utilities: the toolkit exists so the next one is a file and a
  `BT.Module` call, not another addon to install.
