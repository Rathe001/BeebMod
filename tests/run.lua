-- Headless tests for the parts that are pure Lua: names and keys, sightings,
-- guild history, notes and flags, search and prune.
--   lua tests/run.lua
local failures = 0
local function check(ok, what)
	print((ok and "ok   " or "FAIL ") .. what)
	if not ok then failures = failures + 1 end
end

-- the few globals these files touch
_G.CreateFrame = function()
	return setmetatable({}, { __index = function() return function() return nil end end })
end
_G.GetRealmName = function() return "Whitemane" end
_G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.time = os.time
_G.date = os.date
_G.GetAddOnMetadata = function() return "0.1.0" end

local BT = {}
-- the pure-Lua half of the toolkit: the core's book, and the two modules'
-- arithmetic. No frames, so no UI files.
for _, f in ipairs({ "Core/Init.lua", "Core/Cpu.lua", "Core/Util.lua", "Core/Session.lua", "Core/Pack.lua", "Core/DB.lua",
	-- the widget kit comes along for the surface it defines; it draws nothing
	-- until something asks it to
	"UI/Pill.lua", "UI/Widgets.lua",
	"Modules/Ledger/Tags.lua", "Modules/Census/Stats.lua",
	-- the modules themselves: they register the hooks that do the migrating,
	-- and a sweep that only runs for an enabled module has to be tested with
	-- one actually registered
	-- Core/Tooltip.lua comes with them: it is where a module says it wants a
	-- say in the tooltip, and two of them do that as they load
	"Core/Tooltip.lua",
	"Modules/Ledger/Ledger.lua", "Modules/Census/Census.lua", "Modules/Tips/Tips.lua",
	"Modules/Tracker/Quests.lua", "Modules/Tracker/Tracker.lua" }) do
	assert(loadfile(f), "cannot load " .. f)("BeebMod", BT)
end
local U, DB = BT.Util, BT.DB

-- a fresh book, the way BT.Bind builds one for a realm and faction
local function newdb()
	_G.BeebModDB = nil
	-- and the second variable with it: what you wrote is put back into an
	-- empty book at login, so a "fresh" one that still has it is not fresh
	_G.BeebModKeep = nil
	_G.BeebModChar = nil
	BT.boot = nil -- a fresh login takes a fresh witness
	return BT.Bind("Whitemane", "Alliance")
end

-- 1. Two-part names (Josh 2026-09-18). "Beeb Bob" is one character: the space
-- is part of the name, and the realm is what follows the LAST hyphen - but
-- only when that tail is a realm we have actually met.
do
	U.realm = nil
	U.realms = nil
	local a = U.Key("Beeb Bob")
	local b = U.Key("Beeb Bob", "Whitemane")
	local typed = U.Key("Beeb-Bob")
	check(a == "Beeb Bob" and a == b, ("a full name keys once (%s / %s)"):format(a, b))
	check(typed == a, ("a name typed with a hyphen is the same character (%s)"):format(typed))
	U.LearnRealm("Whitemane")
	U.LearnRealm("Faerlina")
	check(U.Key("Beeb Bob-Whitemane") == a, "the realm suffix of a known realm is stripped")
	check(U.Key("Beeb Bob-Faerlina") == "Beeb Bob@Faerlina", "a character from another realm is another row")
	local given, surname = U.SplitName("Beeb Bob")
	check(given == "Beeb" and surname == "Bob", "a name splits into its two halves")
	local only = select(2, U.SplitName("Beeb"))
	check(only == nil, "a one-word name has no surname")
	check(U.Key("") == nil and U.Key(nil) == nil, "an empty name is not a character")
	check(U.Key("Beeb Bob", "White mane") == a, "a realm written with a space keys the same")
end

-- 2. A sighting merges: what we know now never erases what we knew.
do
	local db = newdb()
	DB.Note(db, "Beeb Bob", nil, { class = "WARRIOR", level = 60, guild = "Nightwatch" }, 1000)
	-- a unit sighting hands over faction and sex as well, and neither may land
	-- on the row: DB.Note used to strip them and then copy them straight back
	DB.Note(db, "Beeb Bob", nil, { zone = "Orgrimmar", faction = "Alliance", sex = 2 }, 2000)
	local p = DB.Get(db, "Beeb Bob")
	check(p.class == "WARRIOR" and p.level == 60 and p.guild == "Nightwatch",
		"a bare sighting does not erase class, level or guild")
	check(p.zone == "Orgrimmar" and p.seen == 2 and p.last == 2000 and p.first == 1000,
		"...but it does move the zone, the count and the clock")
	-- WHAT IS NOT STORED (Josh 2026-09-20). Both halves of the name were kept
	-- on the row, and they are `name` split on a space - a hundred and twenty
	-- kilobytes of the file saying again what another field already said. The
	-- row carries the name; the search index splits it.
	check(p.given == nil and p.surname == nil, "the halves are not stored on the row")
	check(p.srcName == nil and p.src == nil, "nor which handler wrote it")
	check(p.faction == nil, "nor the faction, which the whole book shares")
	check(p.sex == nil, "nor anything nothing has ever shown")
	check(U.SplitName(p.name) == "Beeb", "the name still splits when it is asked to")

	-- and rows written by an older version are slimmed once, on the login
	-- after this one: six hundred kilobytes of a file this client will not
	-- read back if it is too big (Josh 2026-09-20)
	p.given, p.surname, p.srcName = "Beeb", "Bob", "Beeb Bob"
	p.src, p.faction, p.sex = "unit:target", "Alliance", 2
	check(DB.Slim(db) == 1, "an old row is found")
	check(p.given == nil and p.srcName == nil and p.faction == nil and p.sex == nil,
		"and stripped of every one of them")
	check(p.name == "Beeb Bob" and p.class == "WARRIOR",
		"while everything that says something is left alone")
	check(DB.Slim(db) == 0, "and it only happens once")
	DB.Note(db, "Beeb Bob", nil, { level = 12 }, 3000)
	check(DB.Get(db, "Beeb Bob").level == 60, "a stale level never walks a character backwards")
end

-- 3. Guild history, which is the thing a census knows that an armory does not.
do
	local db = newdb()
	DB.Note(db, "Astralux Vane", nil, { guild = "First" }, 1000)
	DB.Note(db, "Astralux Vane", nil, { guild = "First" }, 2000)
	DB.Note(db, "Astralux Vane", nil, { guild = "Second" }, 3000)
	local p = DB.Get(db, "Astralux Vane")
	check(#p.guilds == 2 and p.guild == "Second", "a guild change adds a row, a repeat does not")
	local former, when = DB.FormerGuild(p)
	check(former == "First" and when == 2000, ("the tooltip can say where they were (%s)"):format(tostring(former)))
	DB.Note(db, "Astralux Vane", nil, { guild = "" }, 4000)
	check(p.guild == "" and DB.FormerGuild(p) == "Second",
		"leaving a guild is recorded, and the last guild is still nameable")
end

-- 4. Your half: notes, flags, ratings.
do
	local db = newdb()
	local key = "Grimshade Ash"
	DB.Note(db, "Grimshade Ash", nil, {}, 1000)
	check(not DB.IsMine(DB.Get(db, key)), "a stranger is not yours")
	DB.SetNote(db, key, "  good healer, slow to res  ")
	check(DB.Get(db, key).note == "good healer, slow to res", "a note is trimmed and kept")
	local _, on = DB.ToggleFlag(db, key, "bad")
	check(on and DB.Get(db, key).flags.bad, "a flag toggles on")
	local _, off = DB.ToggleFlag(db, key, "bad")
	check(not off and DB.Get(db, key).flags == nil, "...and off again, leaving nothing behind")
	check(DB.SetFlag(db, key, "nonsense", true) == nil, "an unknown flag is refused")
	DB.SetRating(db, key, 4)
	DB.SetRating(db, key, 9)
	check(DB.Get(db, key).rating == nil, "a rating outside 1-5 clears rather than lies")
	DB.SetNote(db, key, "")
	check(not DB.IsMine(DB.Get(db, key)), "clearing the note gives the record back")
end

-- 5. Search: a prefix of EITHER half of the name, substrings in guilds and
-- notes, and anything you have written on first.
do
	local db = newdb()
	DB.Note(db, "Beeb Bob", nil, { class = "WARRIOR", level = 60, guild = "Nightwatch" }, 1000)
	DB.Note(db, "Beebles Ann", nil, { class = "MAGE", level = 42 }, 3000)
	DB.Note(db, "Corwin Bob", nil, { class = "MAGE", level = 60, guild = "Nightwatch" }, 2000)
	DB.SetNote(db, "Beeb Bob", "tanked Molten Core")
	DB.SetFlag(db, "Beeb Bob", "troll", true)
	local r = DB.Search(db, { text = "beeb" })
	check(#r == 2 and r[1].key == "Beeb Bob",
		("a given-name prefix finds both Beebs, the noted one first (%d)"):format(#r))
	local s = DB.Search(db, { text = "bob" })
	check(#s == 2, ("a surname is searchable on its own (%d)"):format(#s))
	check(#DB.Search(db, { surname = "Bob" }) == 2, "and filterable, so a family reads as a family")
	check(#DB.Search(db, { text = "nightwatch" }) == 2, "a guild name is searchable")
	check(#DB.Search(db, { text = "molten" }) == 1, "so is the text of your own note")
	check(#DB.Search(db, { class = "MAGE" }) == 2 and #DB.Search(db, { flag = "troll" }) == 1,
		"class and flag filters")
	check(#DB.Search(db, { minLevel = 60 }) == 2 and #DB.Search(db, { mineOnly = true }) == 1,
		"level range and only-mine")
	check(#DB.Search(db, { limit = 1 }) == 1, "a limit truncates")
	local all = DB.Search(db, {})
	check(all[1].key == "Beeb Bob" and all[2].key == "Beebles Ann",
		"yours first, then most recently seen")
end

-- 6. Prune drops noise and never touches what you wrote.
do
	local db = newdb()
	local now = 10 * 86400
	DB.Note(db, "Stranger One", nil, {}, now - 9 * 86400)
	DB.Note(db, "Friend Two", nil, {}, now - 9 * 86400)
	DB.Note(db, "Recent Three", nil, {}, now - 86400)
	DB.SetNote(db, "Friend Two", "shared a dungeon")
	check(DB.Prune(db, 7, now) == 1, "one stale stranger dropped")
	check(DB.Get(db, "Friend Two") and DB.Get(db, "Recent Three")
		and not DB.Get(db, "Stranger One"),
		"the noted one and the recent one stay")
	check(DB.Prune(db, 0, now) == 0, "pruning is off at zero days")
end

-- 6b. Nothing refreshes an observation but meeting the character again, so
-- every field carries its age and the display decides what is still true.
do
	local db = newdb()
	local t0 = 1000000
	DB.Note(db, "Kalles Kalleborg", nil, { level = 3, guild = "Inner Sanctum", zone = "Teldrassil" }, t0)
	local p = DB.Get(db, "Kalles Kalleborg")
	check(p.levelAt == t0 and p.guildAt == t0 and p.zoneAt == t0, "each observed field stamps its own moment")
	check(U.LevelText(p, t0) == "3" and U.ZoneText(p, t0) == "Teldrassil" and U.GuildText(p, t0) == "Inner Sanctum",
		"fresh: say it plainly")
	check(U.ZoneText(p, t0 + 3600) == nil, "an hour later the zone is not worth repeating")
	check(U.LevelText(p, t0 + 2 * 86400) == "3+", "a day-old level is a floor, not a fact")
	local g = U.GuildText(p, t0 + 3 * 86400)
	check(g == "Inner Sanctum (as of 3 days ago)", ("an old guild says how old it is (%s)"):format(tostring(g)))
	DB.Note(db, "Kalles Kalleborg", nil, { level = 9 }, t0 + 4 * 86400)
	check(U.LevelText(p, t0 + 4 * 86400) == "9", "meeting them again is the only refresh there is")
end

-- 6c. One character, one row: a source that gives only "Arch" and one that
-- gives "Arch Droob" are the same person, and the GUID proves it.
do
	local db = newdb()
	-- a half-named row as older versions left behind: written straight in,
	-- because DB.Note will not create one any more
	db.players["Arch"] = { name = "Arch", realm = "Whitemane", given = "Arch",
		guid = "Player-70-0001", class = "ROGUE", seen = 1, first = 1000, last = 1000 }
	DB.Guids(db)["Player-70-0001"] = "Arch"
	DB.SetNote(db, "Arch", "ganked me in Ashenvale")
	DB.Note(db, "Arch Droob", nil, { guid = "Player-70-0001", level = 12 }, 2000)
	check(DB.Get(db, "Arch") == nil, "the half-named row is gone")
	local p = DB.Get(db, "Arch Droob")
	check(p and p.note == "ganked me in Ashenvale" and p.class == "ROGUE" and p.level == 12 and p.seen >= 2,
		"the full name keeps the note, the class, the level and the count")
	-- and the short name from then on lands on the same row
	local before = DB.Get(db, "Arch Droob").seen
	DB.Note(db, "Arch", nil, { guid = "Player-70-0001" }, 3000)
	check(DB.Get(db, "Arch") == nil and DB.Get(db, "Arch Droob").seen > before,
		"a later short-named sighting files itself under the full name")
	-- two different characters who share a given name stay apart
	DB.Note(db, "Arch Vale", nil, { guid = "Player-70-0002" }, 4000)
	check(DB.Get(db, "Arch Vale") and DB.Get(db, "Arch Droob"),
		"a different GUID is a different character")
end

-- 6d. One book per realm and faction (Josh 2026-09-18). Every character on
-- the same side of the same realm shares what you wrote; another realm or the
-- other side is a different population and a different book.
do
	_G.BeebModDB = nil
	local ally = BT.Bind("Whitemane", "Alliance")
	DB.Note(ally, "Beeb Straffe", nil, { class = "DRUID" }, 1000)
	DB.SetNote(ally, "Beeb Straffe", "my main")
	-- an alt on the same realm and side opens the same book
	local alt = BT.Bind("Whitemane", "Alliance")
	check(alt == ally and DB.Get(alt, "Beeb Straffe").note == "my main",
		"an alt on the same realm and faction reads the same notes")
	-- the other faction, and another realm, do not
	local horde = BT.Bind("Whitemane", "Horde")
	check(DB.Get(horde, "Beeb Straffe") == nil, "the other faction keeps its own book")
	local other = BT.Bind("Faerlina", "Alliance")
	check(DB.Get(other, "Beeb Straffe") == nil, "so does another realm")
	check(#BT.OtherBooks() == 2, ("the books you are not in are listed (%d)"):format(#BT.OtherBooks()))
	-- settings are account-wide, not per book
	BT.settings.collect = false
	BT.Bind("Whitemane", "Alliance")
	check(BT.settings.collect == false, "settings follow the account, not the book")
	BT.settings.collect = true
end

-- 6e2. WHAT YOU WROTE SURVIVES A BOOK THAT DOES NOT (Josh 2026-09-20).
--
-- This client hands the addon its saved variables back only sometimes. A
-- sighting is replaceable - walk past the same person tomorrow and it is back
-- - but a note is not, so every note, tag and rating is mirrored into a second
-- variable holding nothing else, and put back into an empty book at login.
do
	local db = newdb()
	DB.Note(db, "Kept One", nil, { class = "MAGE", level = 12 })
	DB.Note(db, "Lost Two", nil, { class = "ROGUE", level = 9 })
	DB.SetNote(db, "Kept One", "held the door")
	DB.SetFlag(db, "Kept One", "good", true)

	local keep = _G.BeebModKeep
	check(type(keep) == "table" and type(keep.realms) == "table",
		"writing a note fills the second variable")
	local rows = keep.realms["Whitemane|Alliance"].players
	check(rows["Kept One"] ~= nil, "the one you wrote on is in it")
	check(rows["Lost Two"] == nil, "and the one you only walked past is not")

	-- the book fails to come back; the small variable does
	_G.BeebModDB = nil
	BT.boot = nil
	local fresh = BT.Bind("Whitemane", "Alliance")
	check(DB.Stats(fresh).total == 1, "an empty book is filled from what you wrote")
	local back = DB.Get(fresh, "Kept One")
	check(back and back.note == "held the door", "the note came back")
	check(back and back.flags and back.flags.good, "and the tag with it")
	check(DB.Get(fresh, "Lost Two") == nil,
		"a sighting is replaceable and is not kept")

	-- THREE CHANNELS, ONE QUESTION (Josh 2026-09-20). The same rows go into a
	-- per-character variable as well: a different file, written by different
	-- code in the client, and the one channel that has not been ruled out.
	check(type(_G.BeebModChar) == "table",
		"the per-character variable is written too")
	local charRows = _G.BeebModChar.realms["Whitemane|Alliance"].players
	check(charRows["Kept One"] ~= nil, "with the same rows in it")

	-- and it is preferred on the way back in, because if it works at all it is
	-- the one THIS character wrote
	_G.BeebModDB, _G.BeebModKeep = nil, nil
	BT.boot = nil
	local only = BT.Bind("Whitemane", "Alliance")
	check(DB.Stats(only).total == 1 and DB.Get(only, "Kept One").note == "held the door",
		"the per-character variable alone puts the note back")

	-- and clearing a note takes the row out again, rather than leaving a
	-- ghost that reappears next login
	DB.SetNote(fresh, "Kept One", "")
	DB.SetFlag(fresh, "Kept One", "good", false)
	check(_G.BeebModKeep.realms["Whitemane|Alliance"].players["Kept One"] == nil,
		"nothing of yours left on it, nothing kept")
end

-- 6e3. THE WHOLE BOOK, IN THE ONE CHANNEL THAT HAS COME BACK (Josh 2026-09-21).
--
-- The account file is written perfectly and the client hands back nothing at
-- load; the per-character file has come back. So the book is stashed there at
-- logout, and taken from there when the account one brings nothing.
do
	local db = newdb()
	DB.Note(db, "Horde One", nil, { class = "SHAMAN", level = 12 })
	DB.Note(db, "Horde Two", nil, { class = "WARLOCK", level = 9 })
	-- THE SETTINGS WERE STASHED AND NEVER TAKEN BACK (Josh 2026-09-21).
	-- Logout wrote them into the per-character file along with the book, which
	-- is the one channel this client hands back - and then nothing read them.
	-- Every choice on the Settings tab survived to disk and died at the next
	-- login: the theme reverted and switched-off modules came back on.
	BT.settings.theme = { preset = "custom", rim = { 0.8, 0.2, 0.2, 1 }, radius = 6 }
	BT.settings.modules = BT.settings.modules or {}
	BT.settings.modules.chat = false

	check(BT.StashBook() == 2, "logging out stashes the whole book")
	check(type(_G.BeebModChar.book) == "table", "in the per-character file")
	check(_G.BeebModChar.settings == nil,
		"but not the settings: a copy goes stale the moment you change one")

	-- the account file brings nothing, the way it does
	_G.BeebModDB = nil
	BT.boot = nil
	local revBefore = DB.rev
	local fresh = BT.Bind("Whitemane", "Alliance")
	-- THE CACHES KEY OFF THE REVISION (Josh 2026-09-21). Rows put back go
	-- straight into the table rather than through DB.SetNote, so nothing
	-- bumped the counter the census caches its answers against - the window
	-- opened on a book it had already decided the shape of, and it read as
	-- "the data is there but the panel is a tab behind".
	check(DB.Stats(fresh).total == 2, "and the book comes back whole")
	check(DB.rev > revBefore, "with the revision moved, so the caches know")
	check(DB.Get(fresh, "Horde One") ~= nil, "every character in it")
	check(BT.Stats.Census(fresh).total == 2,
		"and the census counts them without being asked twice")

	-- A STALE COPY NEVER BEATS THE REAL ONE (Josh 2026-09-22). A snapshot of
	-- the settings rode along with every note, and at login it filled in
	-- every module with no answer - which was every module switched ON, since
	-- on used to be written as no answer at all. Metrics, switched on, came
	-- back off after every reload.
	_G.BeebModChar.settings = { modules = { metrics = false, chat = false } }
	_G.BeebModKeep = { realms = {}, settings = { modules = { metrics = false } } }
	_G.BeebModDB.settings.modules = { metrics = true }
	BT.boot = nil
	BT.boot = BT.BootReport()
	BT.Bind("Whitemane", "Alliance")
	check(BT.settings.modules.metrics == true,
		"a module switched on stays on, whatever an older copy says")
	check(BT.settings.modules.chat == nil, "and the old copy fills nothing in")
	check(_G.BeebModChar.settings == nil and _G.BeebModKeep.settings == nil,
		"and is dropped, so it cannot do it on a later login")

	-- and when the account file DOES arrive, it wins
	local kept = BT.db
	BT.boot = nil
	local again = BT.Bind("Whitemane", "Alliance")
	check(again == kept and DB.Stats(again).total == 2,
		"a book that arrived is the truth, not the stash")
end

-- 6e4. THE OLD NAME'S BOOK (Josh 2026-09-22). BeebsToolkit became BeebMod. The
-- saved file of the old name still sits beside the new one and is loaded first,
-- so a book written under the old name is adopted once and saved under the new.
do
	_G.BeebModDB = nil
	_G.BeebsToolkitDB = { realms = { ["Whitemane:Alliance"] = { players = { ["Old One"] = {
		name = "Old One", realm = "Whitemane", level = 12,
	} } } }, settings = { modules = {} } }
	check(BT.Adopt() == true, "a book under the old name is adopted")
	check(_G.BeebModDB == _G.BeebsToolkitDB, "and is the book from then on")

	-- once there is a book under the new name, the old one is only history
	_G.BeebModDB = { realms = { ["Whitemane:Alliance"] = { players = { ["New One"] = {
		name = "New One", realm = "Whitemane", level = 3,
	} } } }, settings = {} }
	local keep = _G.BeebModDB
	check(BT.Adopt() == false, "the new name's book is not replaced by the old one")
	check(_G.BeebModDB == keep, "whatever the old file still holds")
	_G.BeebsToolkitDB = nil
end

-- 6f. The census charts, and how old the book is.
do
	local db = newdb()
	local now = 100 * 86400
	DB.Note(db, "Ally One", nil, { class = "WARRIOR", race = "NightElf", level = 7 }, now - 3600)
	DB.Note(db, "Ally Two", nil, { class = "WARRIOR", race = "Dwarf", level = 24 }, now - 2 * 86400)
	DB.Note(db, "Ally Three", nil, { class = "MAGE", race = "Dwarf", level = 60 }, now - 40 * 86400)
	DB.Note(db, "Ally Four", nil, {}, now - 40 * 86400) -- class and level unknown
	DB.SetFlag(db, "Ally One", "troll", true)
	local c = BT.Stats.Census(db, now)
	check(c.total == 4 and c.class[1].key == "WARRIOR" and c.class[1].n == 2,
		"the commonest class leads the class chart")
	-- the chat-only characters are a row of their own, always last
	local lastClass = c.class[#c.class]
	check(lastClass.key == BT.Stats.UNKNOWN and lastClass.n == 1,
		"the unidentified are a visible row on the class chart, at the end")
	local classCounted = 0
	for _, r in ipairs(c.class) do classCounted = classCounted + r.n end
	check(classCounted == c.total, "so the class chart accounts for every character in the book")
	check(c.unknown.class == 1 and c.unknown.level == 1 and c.unknown.race == 1,
		"what we could not see is counted, not guessed")
	for _, r in ipairs(c.race) do
		check(r.key ~= BT.Stats.UNKNOWN, "race has no unknown row - those characters are simply not in it")
		break
	end
	check(c.race[1].key == "Dwarf" and c.race[1].n == 2, "races count the same way")
	check(#c.level == 7 and c.level[1].key == "1-10" and c.level[1].n == 1 and c.level[3].n == 1,
		"level bands stay in level order, not popularity order")
	-- max level is its own band: "51-60" hides how many are actually done
	check(c.level[6].key == "51-59" and c.level[7].key == "60" and c.level[7].n == 1,
		("sixty stands alone (%s = %d)"):format(c.level[7].key, c.level[7].n))
	DB.Note(db, "Ally Five", nil, { level = 58 }, now - 3600)
	local c2 = BT.Stats.Census(db, now)
	check(c2.level[6].n == 1 and c2.level[7].n == 1, "a fifty-eight is not a sixty")
	check(c.flag[1].key == "troll" and c.flag[1].n == 1, "your flags are the fourth chart")
	check(c.age.buckets[1].key == "today" and c.age.buckets[1].n == 1
		and c.age.buckets[2].n == 1 and c.age.buckets[3].n == 0 and c.age.buckets[4].n == 2,
		"sightings fall into today, this week, this month, older")
	check(BT.Stats.AgeLine(c):find("median", 1, true) ~= nil, "the age line reads as a sentence")
	-- the subtitle says what the chart covers, and mentions the unidentified
	-- only when there are some
	check(BT.Stats.Subtitle("class", c, 4) == "all 4 · 1 unknown",
		"the class chart owns up to its gap")
	check(BT.Stats.Subtitle("race", c, 3) == "3 of 4 · 1 no race",
		"a chart that leaves people out says how many")
	local clean = { total = 9, unknown = { class = 0, race = 0, level = 0, flag = 0 } }
	check(BT.Stats.Subtitle("class", clean, 9) == "all 9",
		"and with nothing unidentified, there is no caveat at all")
	check(BT.Stats.Subtitle("flag", clean, 2) == "2 of 9 tagged", "tags read their own way")

	-- with brackets switched off, the chart says what it is leaving out
	local db2 = newdb()
	DB.Note(db2, "Low One", nil, { class = "MAGE", level = 4 }, 1000)
	DB.Note(db2, "High Two", nil, { class = "DRUID", level = 60 }, 1000)
	DB.Note(db2, "No Level", nil, { class = "ROGUE" }, 1000)
	local only60 = BT.Stats.Census(db2, 1000, { bands = { ["60"] = true } })
	check(only60.class[1].key == "DRUID" and #only60.class == 1,
		"a bracket filter narrows the class chart to those levels")
	check(only60.level[7].n == 1 and only60.level[1].n == 1,
		"but the level chart still counts everybody, filter or no filter")
	check(only60.filtered and BT.Stats.Subtitle("class", only60, 1):find("in these levels", 1, true),
		("and says so (%s)"):format(BT.Stats.Subtitle("class", only60, 1)))
	check(BT.Stats.Subtitle("class", only60, 1):find("1 no level", 1, true) ~= nil,
		"including who has no level to filter by")
	check(BT.Stats.AgeLine(BT.Stats.Census(newdb(), now)) == "nothing yet",
		"an empty book says so")
end

-- 6g. Auto-purge is on by default and never touches what you wrote.
do
	check(BT.settings.pruneDays == 90, "auto-purge defaults to 90 days")
	local db = newdb()
	local now = 200 * 86400
	DB.Note(db, "Ghost One", nil, {}, now - 120 * 86400)
	DB.Note(db, "Kept Two", nil, {}, now - 120 * 86400)
	DB.SetFlag(db, "Kept Two", "troll", true)
	check(DB.Prune(db, BT.settings.pruneDays, now) == 1 and DB.Get(db, "Kept Two"),
		"the stranger goes, the flagged one stays")
end

-- 6i. Every write bumps a revision, which is what the open window watches.
do
	local db = newdb()
	local before = DB.rev
	DB.Note(db, "Watched One", nil, {}, 1000)
	check(DB.rev > before, "a sighting counts as a change")
	local afterNote = DB.rev
	DB.SetNote(db, "Watched One", "hello")
	check(DB.rev > afterNote, "so does writing a note")
	local afterFlag = DB.rev
	DB.SetFlag(db, "Watched One", "troll", true)
	check(DB.rev > afterFlag, "and a flag")
	local afterRead = DB.rev
	DB.Search(db, { text = "watched" })
	DB.Stats(db)
	check(DB.rev == afterRead, "reading the book changes nothing")
end

-- 6j. Cleanup: the residue of the lineID bug is a name and nothing else.
do
	local db = newdb()
	DB.Note(db, "Only Name", nil, {}, 1000)                                  -- goes
	DB.Note(db, "Known Class", nil, { class = "MAGE" }, 1000)                  -- stays
	DB.Note(db, "Guid Haver", nil, { guid = "Player-70-0004" }, 1000)          -- stays: askable
	DB.Note(db, "Noted Stranger", nil, {}, 1000)
	DB.SetNote(db, "Noted Stranger", "the one who ninja'd the belt") -- stays: yours
	db.players["Nature"] = { name = "Nature", realm = "Whitemane", seen = 1, last = 1000 }
	check(DB.Cleanup(db) == 2, "the nameless row and the pet go")
	check(DB.Get(db, "Only Name") == nil
		and DB.Get(db, "Paws") == nil
		and DB.Get(db, "Known Class")
		and DB.Get(db, "Guid Haver")
		and DB.Get(db, "Noted Stranger"),
		"a two-part name, a GUID or a note each save a record")
	-- text a parser mistook for a person goes, vouched or not
	DB.Note(db, "[1. General - Teldrassil] [3. LocalDefense - Teldrassil]", nil,
		{ vouch = true, src = "channel" }, 1000)
	check(DB.Cleanup(db) == 1, "a line of channel names is not a character")
	check(U.LooksLikeName("Beeb Straffe") and U.LooksLikeName("Totem")
		and not U.LooksLikeName("1. General - Teldrassil")
		and not U.LooksLikeName("Three Word Name") and not U.LooksLikeName("x"),
		"a name is one or two words of letters, and nothing else")

	-- a one-word name is half a name, whatever vouches for it: you cannot
	-- create a character without a surname, so nobody is called just "Totem"
	check(DB.Note(db, "Totem", nil, { guid = "Player-4620-0068DFC4", class = "SHAMAN" }, 1000) == nil,
		"a half-named sighting cannot create a character")
	check(DB.Get(db, "Totem") == nil, "so no such row appears")
	-- but it can still update the right person, found by GUID
	DB.Note(db, "Totem Caller", nil, { guid = "Player-4620-0068DFC4" }, 1000)
	local before = DB.Get(db, "Totem Caller").seen
	DB.Note(db, "Totem", nil, { guid = "Player-4620-0068DFC4", class = "SHAMAN" }, 2000)
	local p = DB.Get(db, "Totem Caller")
	check(p.seen > before and p.class == "SHAMAN",
		"half a name still updates the row its GUID belongs to")
	check(DB.Cleanup(db) == 0, "and a clean book cleans to nothing")
end

-- 6k. The upgrade to schema 3 runs that cleanup once, by itself.
do
	_G.BeebModDB = {
		schema = 2,
		settings = { collect = true },
		realms = { ["Whitemane|Alliance"] = {
			players = {
				["Ghost Name"] = { name = "Ghost Name", realm = "Whitemane", seen = 2, last = 10 },
				["Real One"] = { name = "Real One", realm = "Whitemane", class = "DRUID", seen = 1, last = 10 },
			},
			guids = {}, stats = { sightings = 3 },
		} },
	}
	local db = BT.Bind("Whitemane", "Alliance")
	check(DB.Get(db, "Ghost Name") == nil and DB.Get(db, "Real One"),
		"logging in after the upgrade sweeps the nameless out")
	check(BT.cleanedOnLoad == 1 and _G.BeebModDB.schema == BT.SCHEMA, "and says how many it took")
	BT.cleanedOnLoad = nil
end

-- 6l. A name may gain a surname, never lose one. Sources disagree about how
-- much of a name they know, and the fullest spelling is the true one.
do
	local db = newdb()
	DB.Note(db, "Apol Winterbrew", nil, { guid = "Player-70-0100", class = "SHAMAN" }, 1000)
	-- the same character, from a source that only knows the given name
	DB.Note(db, "Apol", nil, { guid = "Player-70-0100" }, 2000)
	check(DB.Get(db, "Apol Winterbrew") and DB.Get(db, "Apol Winterbrew").name == "Apol Winterbrew",
		"a half-named sighting does not cut the record down")
	check(DB.Get(db, "Apol") == nil, "and does not open a second row")
	check(U.HasSurname("Apol Winterbrew") and not U.HasSurname("Apol"), "one name is half a name")
end

-- 6m. Three flags are built in; the rest are yours (Josh 2026-09-19).
do
	local db = newdb()
	local keys = {}
	for _, flag in ipairs(BT.FLAGS) do keys[#keys + 1] = flag.key end
	check(table.concat(keys, ",") == "good,bad,troll",
		("three built in, and no more (%s)"):format(table.concat(keys, ",")))
	local labels = {}
	for _, flag in ipairs(BT.FLAGS) do labels[#labels + 1] = flag.label end
	check(table.concat(labels, ",") == "Good,Bad,Troll",
		("one word each, so a pill stays a pill (%s)"):format(table.concat(labels, ",")))

	local tag, why = BT.AddTag("Ninja", 5)
	check(tag and tag.key and tag.label == "Ninja", ("a tag of your own (%s)"):format(tostring(why)))
	check(#BT.AllFlags() == 4, "which joins the three on every list")
	check(select(2, BT.AddTag("ninja")) ~= nil, "the same name twice is refused")
	check(select(2, BT.AddTag("   ")) ~= nil, "and so is no name at all")

	DB.Note(db, "Sticky Fingers", nil, {}, 1000)
	DB.SetFlag(db, "Sticky Fingers", tag.key, true)
	check(DB.Get(db, "Sticky Fingers").flags[tag.key], "it marks a character like any other")
	check(#DB.Search(db, { flag = tag.key }) == 1, "and filters like any other")

	-- deleting a tag takes it off everybody: a mark you cannot see or filter
	-- by is worse than no mark
	check(BT.RemoveTag("Ninja") == true, "a tag can be deleted by name")
	check(DB.Get(db, "Sticky Fingers").flags == nil, "and it leaves every character it was on")
	check(#BT.AllFlags() == 3, "leaving the built-ins")
end

-- 6n. The upgrade: the old built-ins move where they still mean something,
-- and the ones I retired become tags rather than being thrown away.
do
	_G.BeebModDB = {
		schema = 8,
		settings = { collect = true },
		realms = { ["Whitemane|Alliance"] = {
			players = {
				["Old Note"] = { name = "Old Note", realm = "Whitemane", seen = 1, last = 10,
					class = "DRUID", flags = { great = true, terrible = true, watch = true,
						friendly = true, tank = true, avoid = true, tag7 = true } },
			},
			guids = {}, stats = { sightings = 1 },
		} },
	}
	local db = BT.Bind("Whitemane", "Alliance")
	local f = DB.Get(db, "Old Note").flags
	check(f.good and f.bad and f.troll,
		"very good becomes Good player, terrible becomes Bad player, keep-an-eye becomes Troll")
	check(f.friendly and U.FlagByKey("friendly") and U.FlagByKey("friendly").label == "Good company",
		"a retired flag you used survives as a tag of your own")
	check(f.tank and U.FlagByKey("tank"), "even the roles, rather than deleting what you judged")
	-- except the ones dropped outright, which leave the book entirely
	check(BT.FLAG_DROPPED.avoid and not U.FlagByKey("avoid"), "a dropped flag is not a tag either")
	check(not f.great and not f.terrible and not f.watch, "and the old keys are gone")
	check(not f.avoid, "and a dropped flag leaves the characters it was on")
	-- A TAG WHOSE DEFINITION IS MISSING KEEPS ITS MARKS (the audit): it used to
	-- be swept off every character, for good
	check(f.tag7, "a mark of a tag the settings have lost is kept, not swept away")
end

-- 6o. The panel opens into whichever corner has the room (Josh 2026-09-19).
do
	-- the real rule, not a copy of it: a copy in a test proves the copy
	local place = U.Placement
	local W, H, PW, PH = 1920, 1080, 430, 200

	-- bar near the bottom left: the panel goes up, aligned left
	local p1 = place({ top = 120, bottom = 94, left = 40, right = 240 }, PW, PH, W, H)
	check(p1 == "BOTTOMLEFT", ("bottom left corner opens upward (%s)"):format(p1))

	-- bar at the very top: there is no room above, so it opens downward
	local p2 = place({ top = 1070, bottom = 1044, left = 40, right = 240 }, PW, PH, W, H)
	check(p2 == "TOPLEFT", ("top of the screen opens downward (%s)"):format(p2))

	-- bar at the right edge: the panel hangs from the bar's right edge
	local p3 = place({ top = 120, bottom = 94, left = 1700, right = 1900 }, PW, PH, W, H)
	check(p3 == "BOTTOMRIGHT", ("right edge lines up right (%s)"):format(p3))

	-- top right: both, at once
	local p4 = place({ top = 1070, bottom = 1044, left = 1700, right = 1900 }, PW, PH, W, H)
	check(p4 == "TOPRIGHT", ("top right does both (%s)"):format(p4))

	-- a bar wider than the panel at the left edge still aligns left
	local p5 = place({ top = 500, bottom = 474, left = 0, right = 200 }, PW, PH, W, H)
	check(p5 == "BOTTOMLEFT", ("hard against the left edge stays left (%s)"):format(p5))
end

-- 7. The sighting throttle: one write per player per window.
do
	local pass = U.Throttle(60)
	check(pass("a", 100) and not pass("a", 130) and pass("b", 130), "a repeat inside the window is skipped")
	check(pass("a", 200), "the window reopens")
end

-- 8. Ago, which is the only thing the tooltip says about time.
do
	check(U.Ago(1000, 1030) == "just now" and U.Ago(1000, 2200) == "20 min"
		and U.Ago(1000, 8200) == "2 hours" and U.Ago(1000, 1000 + 86400) == "1 day"
		and U.Ago(nil) == "never", "every span reads in two words")
	-- the live tooltip said "last just now ago" (Josh 2026-09-18)
	check(U.Since(1000, 1030) == "just now" and U.Since(1000, 2200) == "20 min ago"
		and U.Since(nil) == "never", "and reads as a sentence with 'ago' only where it belongs")
end

-- 9. THE MORNING THE BOOK WAS EMPTY (Josh 2026-09-19). A session saved 1,913
-- characters; the next login showed eleven, and the file on disk was intact.
-- Whatever did that, the addon has to be able to SAY what it was handed, and
-- to get the characters back without meeting them all again.
do
	-- a file that holds a book under a key this character does not bind to
	_G.BeebModDB = {
		schema = BT.SCHEMA,
		settings = {},
		realms = {
			["OldRealm|Alliance"] = {
				players = {
					["Beeb Bob@OldRealm"] = { name = "Beeb Bob", first = 10, last = 20, seen = 3,
						class = "WARRIOR", guid = "Player-1-AAA", note = "held the door" },
					["Arch Droob@OldRealm"] = { name = "Arch Droob", first = 11, last = 21, seen = 1 },
				},
				guids = { ["Player-1-AAA"] = "Beeb Bob@OldRealm" },
				stats = { sightings = 40 },
			},
		},
	}
	-- what the FILE held, and nothing carried in from the second variable
	_G.BeebModKeep = nil
	_G.BeebModChar = nil
	BT.boot = nil
	local db = BT.Bind("Whitemane", "Alliance")
	check(BT.boot.type == "table" and BT.boot.total == 2 and #BT.boot.books == 1,
		"the witness reports what the file held, before we touched it")
	check(BT.boot.bound == "Whitemane|Alliance" and BT.boot.boundCount == 0,
		"and that this login bound an empty book")

	local books = BT.Books()
	check(#books == 2 and books[1].mine and books[1].n == 0 and books[2].key == "OldRealm|Alliance",
		"both books are listed, this character's first")

	-- something of our own in the new book, to prove adopting does not trample it
	DB.Note(db, "Beeb Bob", "Whitemane", { guid = "Player-1-BBB" }, 100)
	DB.SetNote(db, "Beeb Bob", "met again")

	local done = BT.AdoptBook("OldRealm Alliance")
	check(done and done.added == 2 and done.folded == 0,
		"adopting brings the characters across under the name you were shown")
	check(DB.Get(db, "Beeb Bob@OldRealm") and DB.Get(db, "Arch Droob@OldRealm"), "and they are in this book now")
	check(DB.ByGuid(db, "Player-1-AAA") == "Beeb Bob@OldRealm", "with their GUIDs indexed here")
	check(DB.Get(db, "Beeb Bob").note == "met again", "and what was already here is untouched")
	check(db.stats.sightings >= 40, "the sightings count carries over too")
	check(BT.AdoptBook("no such book") == nil, "a book that is not there is not adopted")

	-- the same character in both books: one row, both halves of what we know
	local other = { players = { ["Arch Droob@OldRealm"] = { name = "Arch Droob", first = 5, last = 500,
		seen = 2, class = "MAGE", note = "ninja" } } }
	local added, folded = DB.Adopt(db, other)
	check(added == 0 and folded == 1, "a character in both books is folded, not duplicated")
	local arch = DB.Get(db, "Arch Droob@OldRealm")
	check(arch.first == 5 and arch.last == 500 and arch.seen == 3 and arch.class == "MAGE",
		"the better informed half of each field wins")
	check(arch.note == "ninja", "and the note comes with it")

	-- THE BOOK THAT TURNS UP LATE. The client handed the addon nothing at
	-- ADDON_LOADED and the probes that sort after it got theirs, so the addon
	-- has to be able to take delivery afterwards instead of writing the rest
	-- of the session into an orphan.
	_G.BeebModDB = nil
	BT.boot = nil
	local empty = BT.Bind("Whitemane", "Alliance")
	DB.Note(empty, "Seen Whilewaiting", "Whitemane", { guid = "Player-1-CCC" }, 200)
	check(BT.AcceptLateBook() == false, "nothing has arrived, so there is nothing to take")
	-- the client delivers, late, straight over the global
	_G.BeebModDB = {
		schema = BT.SCHEMA,
		settings = {},
		realms = { ["Whitemane|Alliance"] = {
			players = { ["Old Timer"] = { name = "Old Timer", first = 1, last = 2, seen = 9 } },
			guids = {},
			stats = { sightings = 99 },
		} },
	}
	check(BT.AcceptLateBook() == true, "a book that lands late is taken")
	check(DB.Get(BT.db, "Old Timer"), "its characters are the ones we write in now")
	check(DB.Get(BT.db, "Seen Whilewaiting"), "and what we saw while waiting is kept")
	check(BT.db == _G.BeebModDB.realms["Whitemane|Alliance"], "and we write into the delivered table, not a copy")
	check(BT.AcceptLateBook() == false, "taking it twice does nothing")

	-- THE BAKED BOOK. When the client hands over nothing, the history is read
	-- from the addon's own file instead - including the tags, because a flag
	-- whose tag is missing gets swept off every character it was on.
	BT.baked = {
		settings = {
			nextTag = 4,
			tags = { { key = "tag3", label = "Friendly", short = "Friendly",
				color = { 0.31, 0.82, 0.48 } } },
			barPos = { point = "TOPLEFT", rel = "TOPLEFT", x = 12, y = -300 },
			modules = { census = false },
			tips = { scale = 0.8 },
		},
		realms = { ["Whitemane|Alliance"] = {
			players = {
				["Baked Bread"] = { name = "Baked Bread", first = 1, last = 2, seen = 4,
					class = "ROGUE", guid = "Player-1-DDD", flags = { tag3 = true }, note = "shared a quest" },
				["Baked Beans"] = { name = "Baked Beans", first = 1, last = 2, seen = 1 },
			},
			guids = { ["Player-1-DDD"] = "Baked Bread" },
			stats = { sightings = 12 },
		} },
	}
	_G.BeebModDB = nil
	BT.boot = nil
	local fresh = BT.Bind("Whitemane", "Alliance")
	check(BT.bakedTaken == 2, ("the baked book is taken when nothing arrived (%s)"):format(tostring(BT.bakedTaken)))
	check(DB.Get(fresh, "Baked Bread") and DB.Get(fresh, "Baked Beans"),
		"its characters are in the book we write in")
	check(fresh.guids == nil, "and no GUID index is saved in the book any more")
	check(DB.Get(fresh, "Baked Bread").flags.tag3 == true,
		"a custom tag survives, because its definition came across first")
	check(BT.Util.FlagByKey("tag3") ~= nil, "and the tag itself is a tag again")

	-- AND THE SETTINGS WITH IT. The login that hands back two thousand
	-- characters has to hand back where you put the dock and what you switched
	-- off, or the addon is factory-fresh every morning with a full book in it.
	check(BT.settings.barPos and BT.settings.barPos.point == "TOPLEFT",
		"where the dock was dragged to comes back")
	check(BT.settings.modules and BT.settings.modules.census == false,
		"and a utility you switched off stays off")
	check(BT.settings.tips and BT.settings.tips.scale == 0.8, "and a module's own options")

	-- and the settings the file DID bring win over the baked ones
	_G.BeebModDB = { schema = BT.SCHEMA, settings = { barPos = { point = "CENTER" } }, realms = {} }
	BT.boot = nil
	BT.bakedSettings = nil
	BT.Bind("Whitemane", "Alliance")
	check(BT.settings.barPos and BT.settings.barPos.point == "CENTER" and not BT.bakedSettings,
		"settings that arrived in the file are never overwritten by the baked ones")

	-- THE SAVE ARRIVED, SO THE BAKED FILE ONLY FILLS GAPS (Josh 2026-09-22):
	-- a character the book has is left exactly as it is, and one only the
	-- baked file knows is handed over whole
	BT.bakedTaken = nil
	_G.BeebModDB = { schema = BT.SCHEMA, settings = {}, realms = { ["Whitemane|Alliance"] = {
		players = { ["Real Person"] = { name = "Real Person", first = 1, last = 2, seen = 1 } },
		guids = {}, stats = { sightings = 1 } } } }
	BT.boot = nil
	local live = BT.Bind("Whitemane", "Alliance")
	check(BT.bakedTaken == 2, ("a book that arrived gets only what it lacks (%s)"):format(tostring(BT.bakedTaken)))
	check(DB.Get(live, "Real Person").seen == 1, "and what it has is left exactly as it is")
	check(DB.Get(live, "Baked Bread") ~= nil and DB.Get(live, "Baked Bread").guid == "Player-1-DDD",
		"with the missing ones whole")
	check(BT.settings.barPos and BT.settings.barPos.point ~= "TOPLEFT" or not BT.bakedSettings,
		"and the baked settings never override the book's")
	BT.baked = nil

	-- THE REALM THAT GREW A "2". Same people, two spellings, counted twice.
	_G.BeebModDB = nil
	BT.boot = nil
	BT.baked = nil
	local two = BT.Bind("ClassicBetaPvE2", "Alliance")
	two.players = {
		["Ola Bard@ClassicBetaPvE"] = { name = "Ola Bard", first = 5, last = 50, seen = 2,
			class = "MAGE", guid = "Player-9-AAA", note = "good healer" },
		["Ola Bard@ClassicBetaPvE2"] = { name = "Ola Bard", first = 80, last = 90, seen = 1, level = 32 },
		["Solo Act@ClassicBetaPvE"] = { name = "Solo Act", first = 1, last = 2, seen = 1 },
		["Far Away@Faerlina"] = { name = "Far Away", first = 1, last = 2, seen = 1 },
	}
	-- the old spelling AND this realm's own name come off the key: a
	-- character of the book's realm is keyed by name alone (Josh 2026-09-24)
	check(DB.FoldRealms(two, "ClassicBetaPvE2") == 3, "every row of this realm, either spelling, is folded")
	check(DB.Get(two, "Ola Bard@ClassicBetaPvE") == nil and DB.Get(two, "Ola Bard@ClassicBetaPvE2") == nil,
		"the old keys are gone")
	local ola = DB.Get(two, "Ola Bard")
	check(ola and ola.seen == 3 and ola.first == 5 and ola.last == 90 and ola.level == 32
		and ola.note == "good healer" and ola.class == "MAGE",
		"and the two halves of what we knew are one character, under the name alone")
	check(DB.Get(two, "Solo Act"), "a row with nothing to merge into just moves")
	check(DB.Get(two, "Solo Act").realm == "ClassicBetaPvE2", "and is told where it lives")
	check(DB.Get(two, "Far Away@Faerlina"), "another realm entirely is left alone")
	check(two.realm == "ClassicBetaPvE2", "and the book knows its realm")
	check(DB.FoldRealms(two, "ClassicBetaPvE2") == 0, "and running it again does nothing")

	-- nothing arrived at all: the witness says so rather than shrugging
	_G.BeebModDB = nil
	BT.boot = nil
	BT.Bind("Whitemane", "Alliance")
	check(BT.boot.type == "nil" and BT.boot.total == 0, "an empty login is reported as an empty login")
end

-- 10. THE TOOLKIT ITSELF: modules, and what switching one off is allowed to
-- do. The Ledger owning the tag sweep is the load-bearing part - a utility you
-- have switched off must not be walking your book removing marks from it.
do
	_G.BeebModDB = nil
	BT.boot = nil
	BT.baked = nil
	local db = BT.Bind("Whitemane", "Alliance")

	local keys = {}
	for _, m in ipairs(BT.Modules()) do
		keys[#keys + 1] = m.key
	end
	check(table.concat(keys, ",") == "ledger,census,tips,tracker", ("tabs come in module order (%s)"):format(table.concat(keys, ",")))
	check(BT.Enabled("ledger") and BT.Enabled("census"), "a new module arrives switched on")
	check(BT.Enabled("nonesuch") == false, "and something that is not a module is not enabled")

	BT.SetEnabled("census", false)
	check(not BT.Enabled("census"), "switching one off takes")
	local live = {}
	for _, m in ipairs(BT.Live()) do
		live[#live + 1] = m.key
	end
	check(table.concat(live, ",") == "ledger,tips,tracker", "and it leaves the tab order")
	BT.SetEnabled("census", true)
	check(#BT.Live() == 4, "and back on again")

	-- a command belonging to something switched off says so rather than running
	local said = {}
	local realPrint = BT.Util.Print
	BT.Util.Print = function(text) said[#said + 1] = text end
	local ran = false
	BT.Command("selftest", function() ran = true end, "a test", "census")
	BT.SetEnabled("census", false)
	check(BT.RunCommand("selftest", "") == true and ran == false,
		"a command of a switched-off module is refused, not ignored")
	check(#said == 1 and said[1]:find("switched off", 1, true), "and it says why")
	BT.SetEnabled("census", true)
	check(BT.RunCommand("selftest", "") and ran, "and runs once it is back on")
	BT.Util.Print = realPrint

	-- THE SWEEP. "tank" is a retired flag: with the Ledger on it becomes a tag
	-- of your own, and with the Ledger off nothing touches it at all.
	DB.Note(db, "Tagged Person", "Whitemane", {}, 100)
	-- written straight onto the row: "tank" is retired, so DB.SetFlag rightly
	-- refuses it, and what we are testing is what happens to a mark that is
	-- already in a book written by an older version
	DB.Get(db, "Tagged Person").flags = { tank = true }
	BT.SetEnabled("ledger", false)
	BT.Bind("Whitemane", "Alliance")
	check(DB.Get(BT.db, "Tagged Person").flags.tank == true,
		"a switched-off Ledger does not sweep the marks it is not showing")
	BT.SetEnabled("ledger", true)
	BT.Bind("Whitemane", "Alliance")
	local p = DB.Get(BT.db, "Tagged Person")
	check(p.flags.tank == true and BT.Util.FlagByKey("tank") ~= nil,
		"and with it back on, the retired flag becomes a tag of your own")

	-- the census reads the book whatever the ledger is doing
	BT.SetEnabled("ledger", false)
	check(BT.Stats.Census(BT.db).total > 0, "the Census still counts a book the Ledger is not watching")
	BT.SetEnabled("ledger", true)
end

-- 11. SEARCHING A BIG BOOK. The lowercase of every name is cached beside the
-- row, so the answers have to stay right when the row changes underneath it.
do
	_G.BeebModDB = nil
	BT.boot = nil
	BT.baked = nil
	local db = BT.Bind("Whitemane", "Alliance")
	DB.Note(db, "Searcher One", "Whitemane", { class = "MAGE" }, 100)
	DB.SetGuild(DB.Get(db, "Searcher One"), "Old Guard", 100)
	DB.SetNote(db, "Searcher One", "ninja looter")

	local function find(text)
		return #DB.Search(db, { text = text })
	end
	check(find("searcher") == 1, "a given name matches by prefix")
	check(find("one") == 1, "and so does a surname")
	check(find("old guard") == 1, "a guild matches anywhere in it")
	check(find("ninja") == 1, "and so does a note")
	check(find("nobody") == 0, "and nothing matches nothing")

	-- the cache has to notice each of those changing
	DB.SetNote(db, "Searcher One", "actually fine")
	check(find("ninja") == 0 and find("actually") == 1, "an edited note is searched as edited")
	DB.SetGuild(DB.Get(db, "Searcher One"), "New Guard", 200)
	check(find("old guard") == 0 and find("new guard") == 1, "and a guild they have left is not searched")

	-- and the counts are cached the same way, by revision
	local before = DB.Stats(db).total
	DB.Note(db, "Searcher Two", "Whitemane", {}, 100)
	check(DB.Stats(db).total == before + 1, "a new character is counted straight away")
end

-- 12. READING THE QUEST LOG. The tracker draws what this says, so this is the
-- half worth testing without a single frame: the words on the left, the count
-- on the right, and only the quests you are actually following.
do
	local words, have, need = BT.Quests.SplitObjective("Stoneanvil's Rifle: 0/1")
	check(words == "Stoneanvil's Rifle" and have == 0 and need == 1,
		("a count is split off the words (%s %s/%s)"):format(tostring(words), tostring(have), tostring(need)))
	-- the other shape this build writes: the count in FRONT, and no colon
	local lw, lh, ln = BT.Quests.SplitObjective("0/6 Ice Claw Bear slain")
	check(lw == "Ice Claw Bear slain" and lh == 0 and ln == 6,
		("a leading count is taken off the words too (%s %s/%s)")
			:format(tostring(lw), tostring(lh), tostring(ln)))
	check(BT.Quests.SplitObjective("0/6 Ice Claw Bear slain", 0, 6) == "Ice Claw Bear slain",
		"and when the client already gave us the numbers")
	check(BT.Quests.SplitObjective("Explore Frostmane Hold") == "Explore Frostmane Hold",
		"an objective with no count is left alone")
	local w2, h2, n2 = BT.Quests.SplitObjective("Rifle: 2/4", 2, 4)
	check(w2 == "Rifle" and h2 == 2 and n2 == 4, "and the newer API's numbers win when it has them")

	-- the vanilla globals, which is what this client answers to
	_G.GetNumQuestLogEntries = function() return 4 end
	_G.GetQuestLogTitle = function(i)
		if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
		if i == 2 then return "Treacherous Cold", 8, nil, false, nil, nil, nil, 1234 end
		if i == 3 then return "Not followed", 9, nil, false, nil, nil, nil, 5678 end
		return "Camping 101", 6, nil, false, nil, nil, nil, 91011
	end
	_G.IsQuestWatched = function(i) return i == 2 or i == 4 end
	_G.GetNumQuestLeaderBoards = function(i) return i == 2 and 2 or 1 end
	_G.GetQuestLogLeaderBoard = function(j, i)
		if i == 2 and j == 1 then return "Stoneanvil's Rifle: 0/1", "item", false end
		if i == 2 then return "Sunhammer's Rifle: 1/1", "item", true end
		return "Raise your herbalism skill to 20", "event", false
	end

	local quests = BT.Quests.Watched()
	check(#quests == 2, ("only the quests you follow (%d)"):format(#quests))
	check(quests[1].title == "Treacherous Cold" and quests[1].level == 8, "with their titles and levels")
	check(quests[1].zone == "Dun Morogh", "and the zone header they sit under")
	check(#quests[1].objectives == 2 and quests[1].objectives[1].text == "Stoneanvil's Rifle",
		"objectives, with the count taken off the words")
	check(quests[1].objectives[2].done == true, "and a finished one knows it is finished")
	check(quests[2].title == "Camping 101" and #quests[2].objectives == 1, "each quest reads its own")

	_G.GetNumQuestLogEntries, _G.GetQuestLogTitle = nil, nil
	_G.IsQuestWatched, _G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard = nil, nil, nil
end

-- 13. A FAILED QUEST IS NOT AN UNFINISHED ONE, and a tag has to be readable.
do
	_G.GetNumQuestLogEntries = function() return 2 end
	_G.GetQuestLogTitle = function(i)
		if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
		-- the seventh return is the vanilla client's way of saying it: 1 for
		-- complete, -1 for failed
		return "Escort the Drunk", 12, nil, false, nil, nil, -1, 4242
	end
	_G.IsQuestWatched = function() return true end
	_G.GetNumQuestLeaderBoards = function() return 1 end
	_G.GetQuestLogLeaderBoard = function() return "Keep him alive: 0/1", "event", false end

	local quests = BT.Quests.Watched()
	check(#quests == 1 and quests[1].failed == true, "a failed quest knows it failed")
	check(quests[1].complete == false, "and is not mistaken for a finished one")
	_G.GetQuestLogTitle = function(i)
		if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
		return "Escort the Drunk", 12, nil, false, nil, nil, 1, 4242
	end
	check(BT.Quests.Watched()[1].failed == false, "and a finished one has not failed")
	_G.GetNumQuestLogEntries, _G.GetQuestLogTitle = nil, nil
end

-- THE QUEST'S ITEM (Josh 2026-09-22): read with the quest, and held back
-- until the quest is complete when it is only for handing in.
do
	_G.GetNumQuestLogEntries = function() return 2 end
	_G.GetQuestLogTitle = function(i)
		if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
		return "Treacherous Cold", 8, nil, false, nil, nil, nil, 1234
	end
	_G.IsQuestWatched = function(i) return i == 2 end
	_G.GetNumQuestLeaderBoards = function() return 0 end
	_G.GetQuestLogSpecialItemInfo = function(i)
		if i == 2 then return "item:6948", 134414, 3, false end
	end
	local q = BT.Quests.Watched()[1]
	check(q.item and q.item.link == "item:6948" and q.item.charges == 3 and q.item.index == 2,
		"a quest reads its item, its charges and where it is in the log")
	_G.GetQuestLogSpecialItemInfo = function(i)
		if i == 2 then return "item:6948", 134414, 1, true end
	end
	check(BT.Quests.Watched()[1].item == nil, "an item for handing in is held back while the quest is unfinished")
	_G.GetQuestLogTitle = function(i)
		if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
		return "Treacherous Cold", 8, nil, false, nil, nil, 1, 1234
	end
	check(BT.Quests.Watched()[1].item ~= nil, "and handed over once it is complete")
	_G.GetQuestLogSpecialItemInfo = nil
	check(BT.Quests.Watched()[1].item == nil, "a client without the call has no items")
	_G.GetNumQuestLogEntries, _G.GetQuestLogTitle = nil, nil
	_G.IsQuestWatched, _G.GetNumQuestLeaderBoards = nil, nil
	_G.IsQuestWatched, _G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard = nil, nil, nil

	-- a tag colour chosen for a tinted pill can be unreadable as plain text
	local r, g, b = BT.Util.Bright({ 0.20, 0.10, 0.30 })
	check(math.max(r, g, b) > 0.8, "a dark tag colour is lifted until it reads")
	check(r < g * 10 and b > r, "and keeps the hue it was picked for")
	local br, bg, bb = BT.Util.Bright({ 1, 0.83, 0.25 })
	check(br == 1 and bg == 0.83, "a colour that already reads is left alone")
end

-- 14. ONE SURFACE. The window, the dock, the note panel and the tooltip used
-- to carry four near-blacks with four alphas, which drifted apart every time
-- one of them was touched.
do
	local fill = BT.Widgets and BT.Widgets.FILL
	check(type(fill) == "table" and fill[4] and fill[4] < 1,
		"the shared surface is see-through")
	check(fill[4] > 0.7, "but not so much that text on it stops reading")
end

-- 15. A NOTE IS SOMEBODY'S. The book is shared by every character on the realm
-- and the side, so a note without a name on it is a note from nobody.
do
	_G.GetUnitName = function(unit) return unit == "player" and "Beeb Magus" or nil end
	local db = newdb()
	DB.Note(db, "Told About", "Whitemane", {}, 100)
	DB.SetNote(db, "Told About", "solid tank")
	local p = DB.Get(db, "Told About")
	check(p.notedBy == "Beeb Magus", ("the note remembers who wrote it (%s)"):format(tostring(p.notedBy)))
	check((p.noted or 0) > 0, "and when")

	-- a different character writing over it takes the note over with it
	_G.GetUnitName = function(unit) return unit == "player" and "Beeb Straffe" or nil end
	DB.SetNote(db, "Told About", "actually a rogue")
	check(DB.Get(db, "Told About").notedBy == "Beeb Straffe", "whoever wrote it last owns it")

	-- clearing a note clears its source with it
	DB.SetNote(db, "Told About", "")
	check(DB.Get(db, "Told About").notedBy == nil, "and an empty note is nobody's")

	check(BT.Util.ShortDate(1789828852):find("%d+/%d+/%d+") ~= nil,
		("a short date reads as a date (%s)"):format(tostring(BT.Util.ShortDate(1789828852))))
	_G.GetUnitName = nil
end

-- THE LIVE SAVE, AS ADDON CODE (Josh 2026-09-22). The client never reads
-- saved variables back, so the TOC runs the save itself as its first file.
-- Init.lua holds whatever that set, and puts it back if the client's loader
-- clears the global before ADDON_LOADED.
do
	local held = BT.linked
	BT.linked = { schema = BT.SCHEMA, settings = {}, realms = { ["Whitemane|Alliance"] = {
		players = { ["Linked Friend"] = { name = "Linked Friend", first = 1, last = 2, seen = 1 } },
		guids = {}, stats = { sightings = 1 } } } }
	_G.BeebModDB = nil
	BT.linkedRestored = nil
	-- what the loader does at ADDON_LOADED, run by hand
	if type(_G.BeebModDB) ~= "table" and BT.linked then
		_G.BeebModDB = BT.linked
		BT.linkedRestored = true
	end
	BT.boot = nil
	local db = BT.Bind("Whitemane", "Alliance")
	check(BT.linkedRestored and DB.Get(db, "Linked Friend") ~= nil,
		"a book the live file set is put back and bound")
	BT.linked = held
	BT.linkedRestored = nil
end

-- THE AUDIT (Josh 2026-09-23): listed is not seen; a guild seen again is the
-- same stretch in it; the only guild someone left still shows.
do
	local db = newdb()
	DB.Note(db, "Guild Mate", nil, { guild = "Nightwatch" }, 1000)
	local p = DB.Get(db, "Guild Mate")
	local seen, last = p.seen, p.last
	DB.Note(db, "Guild Mate", nil, { guild = "Nightwatch", listed = true }, 5000)
	check(p.seen == seen and p.last == last, "an offline member listed by the roster is not a sighting")
	DB.SetGuild(p, "", 6000)
	DB.SetGuild(p, "Nightwatch", 7000)
	check(#p.guilds == 1 and p.guilds[1].last == 7000, "the same guild again is the same stretch, not a new row")
	DB.SetGuild(p, "", 8000)
	check(DB.FormerGuild(p) == "Nightwatch", "someone who left their only guild was in it")
end

-- SESSIONS, ONCE (Josh 2026-09-24): the rules Currency, Experience, Reputation
-- and Pick Pocket share (Core/Session.lua)
do
	local S = BT.Session
	local now = 100000
	local s = { start = now - 30, last = now - 30 }
	check(S.CarriesOn(s, false, true, now), "a reload carries the session on")
	check(not S.CarriesOn(s, true, false, now), "a login starts a new one")
	check(not S.CarriesOn(s, false, false, now), "and so does a loading screen the client says is neither")
	check(S.CarriesOn(s, nil, nil, now), "untold, one touched half a minute ago carries on")
	check(not S.CarriesOn({ last = now - 600 }, nil, nil, now), "one ten minutes old does not")
	check(not S.CarriesOn(nil, false, true, now), "and there is nothing to carry without one")
	check(S.Rate(500, now - 30, now) == nil, "no pace in the first minute")
	check(math.abs(S.Rate(500, now - 1800, now) - 1000) < 1e-6, "500 in half an hour is 1000 an hour")
	check(S.Duration(20) == "<1m" and S.Duration(25 * 60) == "25m" and S.Duration(125 * 60) == "2h 05m",
		"times read the same everywhere: " .. S.Duration(125 * 60))
	-- this character's, moved from an older bare-name entry
	local hadKey, hadMe = U.MeKey, U.Me
	U.MeKey = function() return "Beeb Bob@Whitemane" end
	U.Me = function() return "Beeb Bob" end
	local all = { ["Beeb Bob"] = { start = 1, last = 1 } }
	local mine = S.Mine(all)
	check(mine and all["Beeb Bob@Whitemane"] == mine and all["Beeb Bob"] == nil,
		"an entry filed under the name alone comes across")
	local fresh = S.Open(all, true, false, function(t) return { start = t, n = 0 } end)
	check(fresh ~= mine and all["Beeb Bob@Whitemane"] == fresh and fresh.last == fresh.start,
		"a login opens a fresh one in its place")
	U.MeKey, U.Me = hadKey, hadMe
end

-- A CENSUS A SLICE AT A TIME (Josh 2026-09-24) counts exactly what one in a
-- go counts
do
	local db = newdb()
	for i = 1, 25 do
		DB.Note(db, "Walker " .. string.char(64 + i) .. "x", nil,
			{ class = (i % 2 == 0) and "MAGE" or "ROGUE", level = i * 2 }, 1000 + i)
	end
	local S = BT.Stats
	local whole = S.Census(db, 5000)
	local step, census, calls = S.CensusJob(db, 5000, nil, 4), nil, 0
	repeat
		census = step()
		calls = calls + 1
	until census or calls > 100
	check(census and calls > 1, "counted over several steps: " .. calls .. " of " .. tostring(whole.total))
	check(census.total == whole.total and census.age.median == whole.age.median
		and #census.class == #whole.class and census.class[1].n == whole.class[1].n,
		"and the same charts as counting it in one go")
	-- and the same filter, counted in slices
	local filter = { seen = "today", pick = { mode = "class", key = "MAGE" } }
	local picked = S.Census(db, 1030, filter)
	step, census, calls = S.CensusJob(db, 1030, filter, 4), nil, 0
	repeat
		census = step()
		calls = calls + 1
	until census or calls > 100
	check(census and census.matched == picked.matched and census.total == picked.total
		and census.level[1].n == picked.level[1].n, "a filtered job counts what the filter says")
end

-- SEEN WITHIN, CLICK A BAR, GUILD AND ZONE (Josh 2026-09-24): the census
-- narrowed to who is about lately, and to one bar of another chart
do
	local db = newdb()
	local S, DAY = BT.Stats, 86400
	local now = 100 * DAY
	local function put(name, p)
		db.players[name] = p
		p.name = name
		p.first = p.first or 0
	end
	put("Ann Arrow", { class = "HUNTER", race = "Dwarf", level = 60, guild = "Vanguard", zone = "Ironforge", last = now - 3600 })
	put("Bob Bow", { class = "HUNTER", race = "Night Elf", level = 30, guild = "", zone = "Darnassus", last = now - 2 * DAY })
	put("Cal Cast", { class = "MAGE", race = "Gnome", level = 60, guild = "Vanguard", zone = "Ironforge", last = now - 3600 })
	put("Dee Dusk", { class = "MAGE", race = "Human", level = 12, last = now - 40 * DAY })
	put("Eve Edge", { class = "ROGUE", race = "Human", level = 60, guild = "Vanguard", last = now - 3600,
		flags = { healer = true } })
	put("Fay Fog", { class = "HUNTER", level = 5 }) -- never seen: has no `last`

	local all = S.Census(db, now)
	check(all.book == 6 and all.total == 6 and all.matched == 6, "with no filter, everybody counts")
	local today = S.Census(db, now, { seen = "today" })
	check(today.book == 6 and today.total == 3, "seen today counts the three seen in the last day")
	check(S.Subtitle("class", today, 3):find("seen today", 1, true) ~= nil,
		("and the caption says so (%s)"):format(S.Subtitle("class", today, 3)))
	local week = S.Census(db, now, { seen = "week" })
	check(week.total == 4, "this week adds the one seen two days ago")
	check(S.Census(db, now, { seen = "month" }).total == 4, "the month leaves out forty days ago and never")
	check(S.Census(db, now, { seen = "nonsense" }).total == 6, "a seen that is not one of ours is no filter")

	-- the guild chart: guilds, then the unguilded; the never-seen are a caveat
	check(all.guild[1].key == "Vanguard" and all.guild[1].n == 3, "the largest guild first")
	check(all.guild[#all.guild].key == S.UNGUILDED and all.guild[#all.guild].n == 1,
		"then those seen with no guild, last")
	check(all.unknown.guild == 2, "and no guild line at all is not the same as no guild")
	check(S.Subtitle("guild", all, 4) == "4 of 6 · 2 no guild on file",
		("the guild chart says who it left out (%s)"):format(S.Subtitle("guild", all, 4)))
	check(all.zone[1].key == "Ironforge" and all.zone[1].n == 2 and all.unknown.zone == 3,
		"the zone chart counts where each was last seen")

	-- a long guild chart keeps its top and sums the rest
	local long = newdb()
	for i = 1, S.TOP + 5 do
		long.players["Guild Member" .. i] = { name = "Guild Member" .. i, guild = "Guild " .. i, last = now }
	end
	long.players["Lone Wolf"] = { name = "Lone Wolf", guild = "", last = now }
	local lc = S.Census(long, now)
	check(#lc.guild == S.TOP + 2 and lc.guild[S.TOP + 1].key == S.OTHER and lc.guild[S.TOP + 1].n == 5
		and lc.guild[S.TOP + 2].key == S.UNGUILDED, "the top guilds, the other guilds summed, then no guild")

	-- a bar picked: every other chart counts only what it picked
	local hunters = S.Census(db, now, { pick = { mode = "class", key = "HUNTER" } })
	check(hunters.matched == 3 and hunters.total == 6, "three hunters out of six")
	local classes = 0
	for _, r in ipairs(hunters.class) do classes = classes + 1 end
	check(classes == 3, "the class chart it was picked on still counts every class")
	local races = {}
	for _, r in ipairs(hunters.race) do races[r.key] = r.n end
	check(races.Dwarf == 1 and races["Night Elf"] == 1 and races.Gnome == nil and races.Human == nil,
		"the race chart counts only the hunters")
	check(hunters.unknown.race == 1, "and the hunter with no race is its caveat")
	check(S.Subtitle("race", hunters, 2) == "2 of 3 · 1 no race",
		("out of the hunters, not the realm (%s)"):format(S.Subtitle("race", hunters, 2)))
	check(hunters.level[7].n == 1 and hunters.level[1].n == 1 and hunters.level[3].n == 1,
		"the level chart counts only the hunters")

	local unguilded = S.Census(db, now, { pick = { mode = "guild", key = S.UNGUILDED } })
	check(unguilded.matched == 1 and unguilded.class[1].key == "HUNTER", "no guild can be picked like a guild")
	local healers = S.Census(db, now, { pick = { mode = "flag", key = "healer" } })
	check(healers.matched == 1 and healers.class[1].key == "ROGUE", "and so can a tag")
	local zoned = S.Census(db, now, { pick = { mode = "zone", key = "Ironforge" } })
	check(zoned.matched == 2 and #zoned.race == 2, "and so can a zone")
	check(S.Census(db, now, { pick = { mode = "level", key = "60" } }).matched == 6,
		"the level chart has its brackets, not a pick")

	-- all three at once: brackets, seen and a pick
	local both = S.Census(db, now, { bands = { ["60"] = true }, seen = "today",
		pick = { mode = "guild", key = "Vanguard" } })
	check(both.total == 3 and both.matched == 3 and #both.class == 3, "they stack")
end

-- THE BOOK, PACKED (Josh 2026-09-24): a character at rest is one short
-- string, and comes back the same character (Core/Pack.lua)
do
	local db = newdb()
	local P = BT.Pack
	local T = P.EPOCH + 200 * 86400 + 3 * 3600 + 17 * 60 + 42 -- mid-July, 03:17:42
	DB.Note(db, "Drae Moreweth", nil, { guid = "Player-4620-007246A3", class = "WARLOCK", race = "Gnome",
		level = 20, guild = "House Fortemps", zone = "Stormwind City", vouch = true }, T - 5 * 86400)
	DB.Note(db, "Drae Moreweth", nil, { guild = "Night Watch", level = 24 }, T)
	DB.Note(db, "Far Away", "Faerlina", { class = "MAGE" }, T)
	DB.Note(db, "Lone Wolf", nil, { class = "ROGUE", guild = "" }, T)
	DB.Note(db, "Old Timer", nil, { class = "DRUID" }, 1000) -- before 2026: cannot be said
	DB.Note(db, "Noted Person", nil, { class = "PRIEST" }, T)
	DB.SetNote(db, "Noted Person", "kind")
	DB.Note(db, "Odd Field", nil, { class = "PRIEST" }, T)
	DB.Get(db, "Odd Field").someday = 1
	local before = BT.Stats.Census(db, T + 60)

	local n = DB.PackAll(db)
	check(n == 3, "three rows pack: " .. n)
	local s = db.players["Drae Moreweth"]
	check(type(s) == "string" and #s == P.HEAD + 2 * P.STINT,
		("a character is a %d-letter string, and two guild stints"):format(type(s) == "string" and #s or -1))
	check(type(db.players["Old Timer"]) == "table", "a time before 2026 stays a table")
	check(type(db.players["Noted Person"]) == "table", "so does a character you wrote on")
	check(type(db.players["Odd Field"]) == "table", "and one with a field the packing does not know")
	check(type(db.players["Far Away@Faerlina"]) == "string", "a visitor from another realm packs too")
	local guilds = table.concat(db.words and db.words.guild or {}, ",")
	check(#db.words.guild == 2 and guilds:find("House Fortemps", 1, true) and guilds:find("Night Watch", 1, true),
		"the words are listed once, on the book: " .. guilds)

	-- the same census, read straight out of the strings
	local after = BT.Stats.Census(db, T + 60)
	check(after.total == before.total and after.class[1].n == before.class[1].n
		and #after.guild == #before.guild and after.zone[1].key == "Stormwind City",
		"the census reads a packed book the same")

	-- and back into a table when somebody asks
	local p = DB.Get(db, "Drae Moreweth")
	check(type(db.players["Drae Moreweth"]) == "table" and p == db.players["Drae Moreweth"],
		"asked for, it is unpacked and stays unpacked")
	check(p.name == "Drae Moreweth" and p.realm == "Whitemane" and p.class == "WARLOCK" and p.race == "Gnome"
		and p.level == 24 and p.guild == "Night Watch" and p.zone == "Stormwind City" and p.vouch == true
		and p.seen == 2 and p.guid == "Player-4620-007246A3", "every field comes back")
	check(p.last == T - 42 and p.first == T - 5 * 86400 - 17 * 60 - 42 and p.levelAt == T - 17 * 60 - 42,
		"the last sighting to the minute, the rest to the hour")
	check(p.guilds and #p.guilds == 2 and p.guilds[1].name == "House Fortemps" and p.guilds[2].name == "Night Watch",
		"and the guild history, in order")
	check(p.zoneAt == nil, "a zone keeps no time of its own")
	check(DB.ByGuid(db, "Player-4620-007246A3") == "Drae Moreweth", "and its GUID is known this session")
	check(P.Pack(db, "Drae Moreweth", p) == s, "packed again, it is the same string")
	local far = DB.Get(db, "Far Away@Faerlina")
	check(far.name == "Far Away" and far.realm == "Faerlina", "the visitor keeps their realm")
	local lone = DB.Get(db, "Lone Wolf")
	check(lone.guild == "" and lone.guilds == nil, "no guild is not an unknown guild")

	-- a sighting of a packed character lands on the same row
	DB.PackAll(db)
	DB.Note(db, "Drae Moreweth", nil, { level = 25 }, T + 3600)
	check(type(db.players["Drae Moreweth"]) == "table" and DB.Get(db, "Drae Moreweth").seen == 3
		and DB.Get(db, "Drae Moreweth").level == 25, "a sighting of a packed character unpacks it and counts")

	-- walking the book reads a packed row without unpacking it
	DB.PackAll(db)
	local seenNames = {}
	for key, row in DB.Each(db) do
		seenNames[#seenNames + 1] = row.name
	end
	check(#seenNames == 6 and type(db.players["Drae Moreweth"]) == "string", "a walk leaves the strings as they are")

	-- search: either half of the name, any case, a guild; only what is shown
	-- is unpacked
	local hits = DB.Search(db, { text = "MORE" })
	check(#hits == 1 and hits[1].key == "Drae Moreweth" and hits[1].p.class == "WARLOCK",
		"a surname finds a packed character, whatever the case")
	check(#DB.Search(db, { text = "night w" }) == 1, "and so does their guild")
	check(#DB.Search(db, { text = "o" }) == 2, "a given name too")
	check(#DB.Search(db, { text = "[" }) == 0, "and a pattern character is only a character")
	check(#DB.Search(db, { surname = "moreweth" }) == 1, "the family filter matches the whole surname")

	-- a row with a broken GUID is left a table, not guessed at
	local odd = { name = "Bad Guid", realm = "Whitemane", guid = "Player-1-abc", first = T, last = T, seen = 1 }
	check(P.Pack(db, "Bad Guid", odd) == nil, "a GUID that would not come back the same stays a table")

	-- THE BOOK HAS A SIZE: past the cap, whole days go, oldest first, and
	-- what you wrote on stays
	local capped = newdb()
	for i = 1, 10 do
		DB.Note(capped, "Day" .. i .. " Person", nil, { class = "MAGE" }, T - i * 86400)
	end
	DB.Note(capped, "Ancient Friend", nil, { class = "MAGE" }, T - 400 * 86400)
	DB.SetNote(capped, "Ancient Friend", "old pal")
	DB.PackAll(capped)
	check(DB.Cap(capped, 20) == 0, "under the cap, nothing goes")
	local gone, lowGone, from = DB.Cap(capped, 6)
	check(gone == 5 and lowGone == 0 and DB.Get(capped, "Day5 Person") and not DB.Get(capped, "Day6 Person"),
		("the five seen longest ago go (%s)"):format(tostring(gone)))
	check(DB.Get(capped, "Ancient Friend") ~= nil, "and someone you wrote on stays, whatever their age")
	check(from and from <= T - 5 * 86400 and from > T - 6 * 86400, "and it says from which day it kept")

	-- LOW LEVELS FIRST (Josh 2026-09-25): bank alts and throwaways go before
	-- anyone else, however recently seen; then the oldest of the rest
	local alts = newdb()
	for i = 1, 4 do
		DB.Note(alts, "Bank Alt" .. string.char(64 + i), nil, { class = "ROGUE", level = i + 1 }, T - i * 3600)
	end
	for i = 1, 4 do
		DB.Note(alts, "Real Main" .. string.char(64 + i), nil, { class = "MAGE", level = 50 + i }, T - i * 86400)
	end
	DB.Note(alts, "Chat Only", nil, { class = "PRIEST" }, T - 30 * 86400)
	DB.PackAll(alts)
	local g, lowG = DB.Cap(alts, 7)
	check(g == 2 and lowG == 2 and not DB.Get(alts, "Bank AltD") and not DB.Get(alts, "Bank AltC")
		and DB.Get(alts, "Bank AltA") and DB.Get(alts, "Chat Only"),
		("two over: the two least recently seen low levels go, not the old main (%s, %s)"):format(tostring(g), tostring(lowG)))
	g, lowG = DB.Cap(alts, 3)
	check(lowG == 2 and not DB.Get(alts, "Bank AltA") and not DB.Get(alts, "Chat Only")
		and not DB.Get(alts, "Real MainD") and DB.Get(alts, "Real MainA") and DB.Get(alts, "Real MainC"),
		"the low levels all gone, the rest go oldest first - no level on file is one of the rest")

	-- a packed row crosses to another book as the character it is, words and all
	local other = newdb()
	DB.Note(other, "Zed Zoo", "OldRealm", { class = "HUNTER", guild = "Far Guild" }, T)
	other.realm = "OldRealm"
	DB.FoldRealms(other, "OldRealm")
	DB.PackAll(other)
	check(type(other.players["Zed Zoo"]) == "string", "the other book's row is packed, under its name alone")
	local into = newdb()
	into.realm = "Whitemane"
	DB.Note(into, "Some One", nil, { class = "PRIEST", guild = "Home Guild" }, T)
	DB.PackAll(into)
	local added = DB.Adopt(into, other)
	local zed = DB.Get(into, "Zed Zoo@OldRealm")
	check(added == 1 and zed and zed.class == "HUNTER" and zed.guild == "Far Guild" and zed.realm == "OldRealm",
		"adopted, it keeps its class and guild, and its realm goes back on its key")
	check(DB.Get(into, "Some One").guild == "Home Guild", "and this book's own words are untouched")
end

print("")
if failures == 0 then
	print("ALL TESTS PASSED")
else
	print(failures .. " FAILURES")
	os.exit(1)
end
