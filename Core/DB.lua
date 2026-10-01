-- The database. Pure Lua on purpose: no WoW API is called at file scope or in
-- any function here, so tests/run.lua exercises the whole thing headless.
--
-- A record:
--   name  realm          as seen, for display; name is BOTH halves ("Beeb Bob")
--   given surname       the two halves split, so a search can match either
--   class race sex       CLASS is the token ("WARRIOR"), race the token too
--   level levelAt        the highest level we have ever seen, and when
--   guild guildAt        guild name ("" = unguilded) as of that moment
--   zone zoneAt          where, and when - the field that goes stale fastest
--   guilds               { { name, first, last }, ... } oldest first
--   faction              "Alliance" / "Horde" when we could tell
--   zone                 where we last saw them
--   first last seen      unix seconds, and how many times we wrote them down
--   note tags rating     yours: free text, { key = true }, 1-5
--
-- AT REST, A STRING (Josh 2026-09-24). A row in `players` is either that
-- table or the same row packed into one short string (Core/Pack.lua), which
-- is how most of the book sits in the saved file and in memory. So:
--
--   DB.Get(db, key)      the row as a table, unpacked on the spot if it was
--                        packed - and it stays a table for the session
--   DB.Each(db, full)    every row, for READING: a packed one comes as a
--                        borrowed table that the next row overwrites, so
--                        keep the key, never the row
--   DB.PackAll(db)       back into strings, at logout
--
-- Anything that walks `players` itself sees strings, and a string has no
-- fields: `row.note` is nil, `row.note = x` is an error.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/DB.lua")

local U, P = BT.Util, BT.Pack
local DB = {}
BT.DB = DB

-- Bumped by every write. The open window watches this instead of rebuilding
-- itself on a timer: sitting in a city, most seconds change nothing, and
-- re-sorting a few hundred rows twice a second for no reason is rude to a
-- machine that is also drawing a game (Josh 2026-09-18).
DB.rev = 0

-- WALKING PAST IS NOT WRITING (Josh 2026-09-19). DB.rev counts every write,
-- and standing in a city sees a few a second - each one a sighting nobody
-- asked for. That is the right signal for "re-sort the list", and the wrong
-- one for "the tooltip on screen is out of date": re-setting a unit tooltip
-- tears it down and builds it again, so following DB.rev made the tooltip
-- flicker and jump the whole time the Ledger window was open.
--
-- This one counts only the things a tooltip actually shows: a note, a tag, a
-- rating, a tag being created or deleted.
DB.noteRev = 0

local function touched(mine)
	DB.rev = DB.rev + 1
	if mine then
		DB.noteRev = DB.noteRev + 1
	end
end

-- The fields that no longer earn their place. Dropped from rows written by an
-- older version, once, on the login after this one (Josh 2026-09-20).
-- (Not the faction or the sex any more: both are kept again, see DB.Note.)
local DEAD_FIELDS = { "given", "surname", "srcName", "src" }

-- Returns how many rows it slimmed, which is what the login report prints.
-- (A packed row was slimmed on its way into the string.)
function DB.Slim(db)
	local done = 0
	for _, p in pairs(DB.Players(db)) do
		local touchedOne = false
		if type(p) ~= "table" then
			p = {}
		end
		for _, field in ipairs(DEAD_FIELDS) do
			if p[field] ~= nil then
				p[field] = nil
				touchedOne = true
			end
		end
		if touchedOne then
			done = done + 1
		end
	end
	return done
end

function DB.Players(db)
	db = db or BT.db
	return db and db.players or {}
end

-- WHO A GUID IS, THIS SESSION (Josh 2026-09-24). The book used to save a
-- second table of every GUID and its key - a megabyte of the file, and all of
-- it the same GUIDs the rows already carry. It is kept in memory now, for the
-- characters this session has met or looked at, which is who the damage meter
-- and a half-named sighting are ever about.
local guidIndex = setmetatable({}, { __mode = "k" })

function DB.Guids(db)
	local g = guidIndex[db]
	if not g then
		g = {}
		guidIndex[db] = g
	end
	return g
end

function DB.ByGuid(db, guid)
	db = db or BT.db
	return db and type(guid) == "string" and DB.Guids(db)[guid] or nil
end

function DB.Get(db, key)
	db = db or BT.db
	local players = DB.Players(db)
	local p = key and players[key]
	if type(p) == "string" then
		p = P.Unpack(db, key, p)
		players[key] = p
		if p.guid then
			DB.Guids(db)[p.guid] = key
		end
	end
	return p or nil
end

-- A row to read, however it is kept. Packed, it is unpacked into one of two
-- borrowed tables, the next packed row overwrites it, and `full` is only for
-- a walk that needs the GUID and the guild history as well.
local lightView, fullView = {}, {}

function DB.View(db, key, row, full)
	if type(row) ~= "string" then
		return row
	end
	if full then
		return P.Unpack(db, key, row, fullView)
	end
	return P.Unpack(db, key, row, lightView, true)
end

function DB.Each(db, full)
	db = db or BT.db
	local players, key = DB.Players(db), nil
	return function()
		local row
		key, row = next(players, key)
		if key == nil then
			return nil
		end
		return key, DB.View(db, key, row, full)
	end
end

-- Every table row that can be said as a string, said as one. Returns how many.
function DB.PackAll(db)
	db = db or BT.db
	if not db then
		return 0
	end
	local players, packed = DB.Players(db), 0
	for key, p in pairs(players) do
		if type(p) == "table" then
			local s = P.Pack(db, key, p)
			if s then
				players[key] = s
				packed = packed + 1
			end
		end
	end
	return packed
end

-- How many rows, and how many of them are packed.
function DB.Count(db)
	local n, packed = 0, 0
	for _, p in pairs(DB.Players(db)) do
		n = n + 1
		if type(p) == "string" then
			packed = packed + 1
		end
	end
	return n, packed
end

-- ONE CHARACTER, ONE ROW (Josh 2026-09-18). Some sources hand over the full
-- name ("Arch Droob") and some only the given name ("Arch"), which put the
-- same person in the ledger twice. The GUID is the same either way, so it is
-- the identity: when a sighting carries a GUID we have already filed under
-- another name, the two records become one, and the fuller name wins.
-- Fold one record into another: the better informed of the two wins, field by
-- field, and nothing you wrote yourself is ever lost.
local function absorb(to, from)
	-- observations: keep whichever is better informed, oldest first seen
	to.first = math.min(to.first or from.first or 0, from.first or to.first or 0)
	to.last = math.max(to.last or 0, from.last or 0)
	to.seen = (to.seen or 0) + (from.seen or 0)
	for _, f in ipairs({ "class", "race", "guid", "vouch", "faction", "sex" }) do
		if to[f] == nil then to[f] = from[f] end
	end
	if (from.level or 0) > (to.level or 0) then
		to.level, to.levelAt = from.level, from.levelAt
	end
	if (from.zoneAt or 0) > (to.zoneAt or 0) then
		to.zone, to.zoneAt = from.zone, from.zoneAt
	end
	if (from.guildAt or 0) > (to.guildAt or 0) and from.guild ~= nil then
		to.guild, to.guildAt = from.guild, from.guildAt
	end
	if from.guilds and not to.guilds then
		to.guilds = from.guilds
	end
	-- yours: never dropped on the floor. Two notes become one.
	if from.note and from.note ~= "" then
		to.note = (to.note and to.note ~= "" and to.note ~= from.note)
			and (to.note .. " / " .. from.note) or from.note
	end
	if from.tags then
		to.tags = to.tags or {}
		for k in pairs(from.tags) do to.tags[k] = true end
	end
	to.rating = to.rating or from.rating
	return to
end

function DB.Merge(db, fromKey, toKey)
	local from, to = DB.Get(db, fromKey), DB.Get(db, toKey)
	if not (from and to and fromKey ~= toKey) then
		return to or from
	end
	absorb(to, from)
	db.players[fromKey] = nil
	if from.guid then
		DB.Guids(db)[from.guid] = toKey
	end
	return to
end

-- ADOPTING A BOOK (Josh 2026-09-19). A book is keyed by realm and faction, so
-- if either of those ever reads differently - a realm renamed between builds,
-- a faction the client had not answered yet at login - the addon binds a NEW
-- book and everything you collected looks gone. It is not gone: it is in the
-- same file under the old key. This moves it across, character by character,
-- rather than asking you to meet 1,900 people again.
function DB.Adopt(db, from)
	db = db or BT.db
	if not (db and type(from) == "table" and type(from.players) == "table") then
		return 0, 0
	end
	db.players = db.players or {}
	local added, folded = 0, 0
	-- keys first: unpacking a row of `from` below is an edit of it
	local keys = {}
	for key in pairs(from.players) do
		keys[#keys + 1] = key
	end
	for _, fromKey in ipairs(keys) do
		-- a packed row is only readable with its OWN book's words, so it
		-- crosses as the table it stands for
		local p = DB.Get(from, fromKey)
		-- under its name alone, as every key now is (U.Key), and of this
		-- book's realm, or it could not be packed again
		local key = (P.Split(from, fromKey))
		if DB.Get(db, key) then
			absorb(db.players[key], p)
			folded = folded + 1
		else
			p.realm = db.realm or p.realm
			db.players[key] = p
			added = added + 1
		end
		local row = db.players[key]
		if row.guid then
			DB.Guids(db)[row.guid] = key
		end
	end
	db.stats = db.stats or { sightings = 0 }
	db.stats.sightings = (db.stats.sightings or 0) + ((from.stats and from.stats.sightings) or 0)
	touched()
	return added, folded
end

-- THE FACTION OF THE ROWS ALREADY ON FILE (Josh 2026-09-30), from the race,
-- for the eight that belong to one side. A Skyborne is played on both, so it
-- waits for a sighting of its own. Once, on the login after this was added.
-- Returns how many rows it gave one.
DB.SIDE_OF_RACE = {
	Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
	Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde",
}
function DB.BackfillFaction(db)
	if not (db and db.players) then
		return 0
	end
	local n = 0
	for key, row in pairs(db.players) do
		if type(row) == "string" then
			local side = not P.Faction(row) and DB.SIDE_OF_RACE[P.Race(db, row) or ""]
			if side then
				db.players[key] = P.WithFaction(row, side)
				n = n + 1
			end
		elseif type(row) == "table" and not row.faction and DB.SIDE_OF_RACE[row.race or ""] then
			row.faction = DB.SIDE_OF_RACE[row.race]
			n = n + 1
		end
	end
	return n
end

-- A ROW THAT STILL SAYS NO SIDE, THE SIDE OF THE BOOK IT WAS IN (Josh
-- 2026-09-30: "combine the alliance and horde books"). A book was one side's,
-- and every way into it but a unit you saw - /who, the guild, friends, a
-- channel - lists only your own side; of the 20,103 rows of the 2026-09-29
-- Alliance book whose race says a side, 5 were the Horde's. So before the two
-- books become one, a row with no side takes its book's: a Skyborne above all,
-- who is played on both. Returns how many it gave one.
function DB.FillFaction(db, side)
	if not (db and db.players and (side == "Alliance" or side == "Horde")) then
		return 0
	end
	local n = 0
	for key, row in pairs(db.players) do
		if type(row) == "string" then
			if not P.Faction(row) then
				db.players[key] = P.WithFaction(row, side)
				n = n + 1
			end
		elseif type(row) == "table" and not row.faction then
			row.faction = side
			n = n + 1
		end
	end
	return n
end

-- ONE BOOK, ONE REALM (Josh 2026-09-19). The realm was renamed from "Classic
-- Beta PvE" to "Classic Beta PvE 2" between builds, and 308 characters stayed
-- filed under the old spelling: the same people, counted twice.
--
-- AND THE REALM COMES OFF THE KEY (Josh 2026-09-24): a character of the
-- book's own realm is keyed by name alone (U.Key), so "Beeb Bob@Whitemane" in
-- the Whitemane book becomes "Beeb Bob" here too.
--
-- EVERY REALM, NOW (Josh 2026-09-30: "There should just be a single realm,
-- and if not, we need to just combine them (keep rulesets separate
-- though)"). A book is a ruleset's one realm, and no key carries a realm at
-- all: every "Name@Anything" folds into "Name", at every login. Returns how
-- many rows it folded.
function DB.FoldRealms(db, realm)
	db = db or BT.db
	if not (db and realm and realm ~= "" and db.players) then
		return 0
	end
	db.realm = realm
	-- collect first, then edit: re-keying the table you are walking is an
	-- "invalid key to next" error, not a warning
	local rekey = {}
	for key, row in pairs(db.players) do
		-- a row in a table says the book's realm, or it cannot be packed (a
		-- string's realm is its book's already)
		if type(row) == "table" and row.realm ~= realm then
			row.realm = realm
		end
		if key:find("@", 1, true) then
			local name, r = key:match("^(.*)@(.*)$")
			-- EVERY ONE, NOW (Josh 2026-09-30: "There should just be a single
			-- realm, and if not, we need to just combine them"): one book a
			-- realm, and no realm in a key (U.Key)
			if name and r then
				rekey[key] = name
			end
		end
	end
	local moved = 0
	for from, to in pairs(rekey) do
		-- a string row names nobody (the key does), so only a table has a
		-- name and a realm to put right
		local p = db.players[from]
		if type(p) == "table" then
			p.realm = realm
		end
		db.players[from] = nil
		if db.players[to] then
			absorb(DB.Get(db, to), type(p) == "table" and p or P.Unpack(db, to, p))
		else
			db.players[to] = p
		end
		moved = moved + 1
	end
	if moved > 0 then
		touched()
	end
	return moved
end

-- Write down what we just saw. `info` carries only what the caller actually
-- knows - a combat log line knows a name and a faction, a unit you moused over
-- knows everything - and a field that is nil never overwrites a field we have.
-- Returns the record.
function DB.Note(db, name, realm, info, now)
	db = db or BT.db
	if not db then
		return nil
	end
	local key, short, rname = U.Key(name, realm)
	if not key then
		return nil
	end
	now = now or U.Now()
	info = info or {}
	local guids = DB.Guids(db)
	-- the same character under a shorter name: file this sighting on the row
	-- that already exists, and let the fuller name own it
	local guid = info.guid
	if guid then
		local known = guids[guid]
		local them = known and known ~= key and DB.Get(db, known)
		if them then
			local mineHasSurname = U.HasSurname(short)
			local theirsHasSurname = U.HasSurname(them.name or "")
			if theirsHasSurname and not mineHasSurname then
				key, short, rname = known, them.name, them.realm
			elseif mineHasSurname and not theirsHasSurname then
				db.players[key] = DB.Get(db, key) or {}
				DB.Merge(db, known, key)
			else
				key, short, rname = known, them.name, them.realm
			end
		end
		guids[guid] = key
	end
	local p = DB.Get(db, key)
	if not p then
		-- NO HALF NAMES, EVER (Josh 2026-09-19). Character creation requires
		-- both a given name and a surname, so a one-word name is never a whole
		-- character: it is the damage meter naming a combat source, a pet, or
		-- some other source that only knows half. Such a sighting may UPDATE a
		-- row that already exists (the GUID path finds it), but it may not
		-- create one - the same player arrives properly named the moment they
		-- speak or are seen.
		if not U.HasSurname(short) then
			return nil
		end
		p = { name = short, realm = rname, first = now, seen = 0 }
		db.players[key] = p
	end
	-- ONLY WHAT YOU SAW (Josh 2026-09-26: "kill the whole census sharing
	-- concept. Players will only see census data for what they collect").
	-- A row heard from another copy of BeebMod is gone at login
	-- (DB.DropHeard); a mark left on one is wiped by your own sighting.
	p.heard = nil
	-- a name may gain a surname, never lose one: whatever the source, the
	-- fuller spelling of a character is the true one
	if not (p.name and U.HasSurname(p.name) and not U.HasSurname(short)) then
		p.name = short
	end
	p.realm = rname
	-- WHAT IS NOT STORED (Josh 2026-09-20). This client hands a saved variable
	-- back only if it is small enough, and at twenty-one fields a character
	-- the book was a megabyte and a half - past whatever that limit is, so it
	-- came back as nothing at all, every login.
	--
	-- Six of those fields said nothing a seventh did not:
	--
	--   given, surname   both halves of `name`, split again on demand
	--   srcName          the same string as `name`
	--   src              which handler wrote the row; a debugging breadcrumb
	--   faction          the book is PER FACTION; every row said the same word
	--   sex              nothing has ever shown it
	--
	-- Together they were four hundred kilobytes of the file, and the field
	-- names themselves another two hundred. Dropping them is not a feature
	-- being removed: `given` and `surname` are computed where they are wanted,
	-- which is the search index, and that was already being built.
	-- THE FACTION AND THE SEX COME BACK (Josh 2026-09-30: "Let's also store
	-- faction so we can work with it in the future", "Are we able to track
	-- gender as well?"). The faction went because a book was one side's, and
	-- the sex because nothing showed it; one book holds both sides now, and
	-- packed, the two cost no letter (Core/Pack.lua).
	p.given, p.surname = nil, nil
	p.srcName, p.src = nil, nil
	-- a list the client only builds for real characters (a /who answer, the
	-- friends list, a battleground scoreboard) vouches for a row that has no
	-- GUID to prove itself with
	if info.vouch then
		p.vouch = true
	end
	-- EVERY observed field carries the moment we observed it (Josh 2026-09-18).
	-- Without a /who sweep we cannot refresh anybody, so the honest thing is to
	-- say how old each answer is and let the display decide what is still worth
	-- showing: a zone is worthless within the hour, a guild holds for weeks, and
	-- a level is a FLOOR that only ever rises.
	if type(info.level) == "number" and info.level > 0 and info.level > (p.level or 0) then
		p.level, p.levelAt = info.level, now
	end
	for _, f in ipairs({ "class", "race", "guid" }) do
		if info[f] ~= nil then
			p[f] = info[f]
		end
	end
	if P.FACTION_CODE[info.faction or ""] then
		p.faction = info.faction
	end
	-- the game's own numbers: 2 male, 3 female (1 is "not known")
	if info.sex == 2 or info.sex == 3 then
		p.sex = info.sex
	end
	if info.zone ~= nil then
		p.zone, p.zoneAt = info.zone, now
	end
	if info.guild ~= nil then
		DB.SetGuild(p, info.guild, now)
	end
	-- LISTED IS NOT SEEN (Josh 2026-09-23, audit): the guild roster names
	-- offline members too, and marking them seen every minute kept them from
	-- ever ageing out, and counted a sighting of the whole guild each pass. A
	-- listed row takes what it is told and keeps its last sighting.
	if not info.listed or not p.last then
		p.last = now
	end
	if not info.listed then
		p.seen = (p.seen or 0) + 1
		db.stats.sightings = (db.stats.sightings or 0) + 1
	end
	touched()
	return p
end

-- Guild changes are the most useful thing a census knows that an armory does
-- not, so every change keeps its own row rather than overwriting the last.
function DB.SetGuild(p, guild, now)
	guild = guild or ""
	now = now or U.Now()
	if p.guild == guild then
		p.guildAt = now
		local h = p.guilds and p.guilds[#p.guilds]
		if h then
			h.last = now
		end
		return
	end
	p.guild, p.guildAt = guild, now
	if guild ~= "" then
		p.guilds = p.guilds or {}
		-- back in the guild the history last showed (a blank in between that
		-- was the client not having said yet): the same stretch, not a new
		-- one - the history grew a row every time and called the current
		-- guild the former one (Josh 2026-09-23, audit)
		local last = p.guilds[#p.guilds]
		if last and last.name == guild then
			last.last = now
		else
			p.guilds[#p.guilds + 1] = { name = guild, first = now, last = now }
		end
	end
end

-- The previous guild, for the tooltip line. nil when we never saw a change.
function DB.FormerGuild(p)
	local h = p and p.guilds
	-- unguilded now: the last guild on file, even if it was the only one
	if p and p.guild == "" and h and #h >= 1 then
		return h[#h].name, h[#h].last
	end
	if not (h and #h >= 2) then
		return nil
	end
	local prev = h[#h - 1]
	-- when the current guild is the last row, the one before it is the answer;
	-- when they are unguilded now, the last row is
	if p.guild == "" then
		return h[#h].name, h[#h].last
	end
	return prev.name, prev.last
end

-- WHAT YOU WRITE IS THE LEDGER'S (Josh 2026-09-26): notes, tags and ratings
-- are kept in its own book (Modules/Ledger/Store.lua), and moved off these
-- rows once. A row that still carries one - written by an older version and
-- not yet moved - is still yours, and nothing here drops it.
function DB.IsMine(p)
	return (p.note ~= nil) or (p.tags ~= nil) or (p.rating ~= nil)
end

-- query = { text, class, guild, surname, tag, minLevel, maxLevel, mineOnly, limit }
-- Matching is case-insensitive and by prefix on name, substring on guild and
-- note, which is what you want when you half-remember a name.
--
-- NO LOWERCASE COPIES (Josh 2026-09-24). Searching used to :lower() every
-- name, guild and note, first on every keystroke and then once each into a
-- cache beside the row (Josh 2026-09-19) - a second copy of every name in the
-- book, and nothing to hang it on once a row is a string. A name is matched
-- by a pattern that is its own caseless spelling ("bob" -> "[bB][oO][bB]"),
-- which makes nothing; the guilds, which are few, are lowercased once each.
local function caseless(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		:gsub("%a", function(c) return "[" .. c:lower() .. c:upper() .. "]" end))
end

local guildLower = {}
local function lowGuild(g)
	local l = guildLower[g]
	if not l then
		l = g:lower()
		guildLower[g] = l
	end
	return l
end

function DB.Search(db, query)
	db = db or BT.db
	query = query or {}
	local text = (type(query.text) == "string" and query.text ~= "") and query.text:lower() or nil
	-- a prefix of EITHER half of the name: people remember a surname as
	-- readily as a given name, and "bob" should find "Beeb Bob"
	local given = text and ("^" .. caseless(text))
	local surname = text and ("^%S+%s+" .. caseless(text))
	local family = type(query.surname) == "string"
		and ("^%S+%s+" .. caseless(query.surname:lower()) .. "$") or nil
	local found = {}
	for key, p in DB.Each(db) do
		local ok = true
		if query.mineOnly and not DB.IsMine(p) then
			ok = false
		end
		local name = p.name or ""
		if ok and text then
			ok = name:find(given) ~= nil or name:find(surname) ~= nil
				or (p.guild ~= nil and p.guild ~= "" and lowGuild(p.guild):find(text, 1, true) ~= nil)
				or (p.note ~= nil and p.note:lower():find(text, 1, true) ~= nil)
		end
		if ok and query.class and p.class ~= query.class then ok = false end
		if ok and query.tag and not (p.tags and p.tags[query.tag]) then ok = false end
		if ok and query.guild and p.guild ~= query.guild then ok = false end
		if ok and family and not name:find(family) then ok = false end
		if ok and query.minLevel and (p.level or 0) < query.minLevel then ok = false end
		if ok and query.maxLevel and (p.level or 0) > query.maxLevel then ok = false end
		if ok then
			-- the key and what the order needs, not the row: a packed row is
			-- a borrowed table the next one overwrites
			found[#found + 1] = { key = key, mine = DB.IsMine(p), last = p.last or 0, name = name }
		end
	end
	table.sort(found, function(a, b)
		if a.mine ~= b.mine then
			return a.mine
		end
		if a.last ~= b.last then
			return a.last > b.last
		end
		return a.name < b.name
	end)
	if query.limit and #found > query.limit then
		for i = #found, query.limit + 1, -1 do
			found[i] = nil
		end
	end
	-- only what is shown is unpacked
	for _, r in ipairs(found) do
		r.p = DB.Get(db, r.key)
		r.mine, r.last, r.name = nil, nil, nil
	end
	return found
end

-- Two kinds of row are not characters, and both are cleared out here. Nothing
-- you have written on is ever touched, whatever state it is in.
--
--   1. a name and nothing else: the lineID bug filed chat sightings with a
--      line number in place of a GUID, so there is no class and nothing to ask
--      the client about - and meeting them again files them properly anyway
--   2. ONE-WORD NAMES. Character creation demands a given name and a surname,
--      so "Totem" is never a whole character however convincing it looks: a
--      player GUID and a class only prove the damage meter was looking at a
--      real person while it reported half their name (Josh 2026-09-19, after
--      Josh checked what character creation actually allows).
--   3. text a parser mistook for a person, like a line of channel names
function DB.Cleanup(db)
	db = db or BT.db
	if not db then
		return 0
	end
	local gone = 0
	for key, p in DB.Each(db, true) do
		-- junk a parser produced is junk however it was vouched for
		local junk = not U.LooksLikeName(p.name)
		-- and half a name is not a character, whatever vouches for it: every
		-- character in this game is created with two
		local half = not U.HasSurname(p.name)
		local nameless = not p.class and not p.guid and not p.vouch
		-- read the NAME, not the stored surname field: a record written before
		-- that field existed has no surname and is still a person
		local _, surname = U.SplitName(p.name)
		local notAPerson = surname == nil and not p.guid and not p.class and not p.vouch
		if not DB.IsMine(p) and (nameless or notAPerson or junk or half) then
			db.players[key] = nil
			if p.guid then
				DB.Guids(db)[p.guid] = nil
			end
			gone = gone + 1
		end
	end
	if gone > 0 then
		touched()
	end
	return gone
end

-- NOTHING HEARD (Josh 2026-09-26: "kill the whole census sharing concept.
-- Players will only see census data for what they collect"; "Delete heard
-- rows"). Every row, in every book, that another copy of BeebMod told us of
-- and we never saw ourselves - never one written on. What a heard sighting
-- added to a row we had seen carries no mark and stays: a class, a newer
-- guild. Returns how many went.
function DB.DropHeard(realms)
	local gone = 0
	for _, book in pairs(realms or {}) do
		local players = type(book) == "table" and book.players
		for key, p in pairs(players or {}) do
			local heard
			if type(p) == "string" then
				heard = #p >= 24 and BT.Pack.Heard(p)
			elseif type(p) == "table" then
				heard = p.heard == true and not DB.IsMine(p)
			end
			if heard then
				players[key] = nil
				gone = gone + 1
			end
		end
	end
	if gone > 0 then
		touched()
	end
	return gone
end

-- a row's last sighting, read straight off a packed one
local function lastOf(p)
	if type(p) == "string" then
		return P.Last(p) or 0
	end
	return p.last or 0
end

-- Someone you saw once in Ironforge two months ago and never wrote on is
-- noise. Never touches a record you have written on. Returns how many went.
-- (Only the last sighting is wanted, so a packed row is never unpacked: a
-- string cannot carry a note, a tag or a rating, so it is never yours.)
function DB.Prune(db, days, now)
	db = db or BT.db
	if not (db and days and days > 0) then
		return 0
	end
	now = now or U.Now()
	local cutoff = now - days * 86400
	local gone = 0
	local players = DB.Players(db)
	for key, p in pairs(players) do
		if not (type(p) == "table" and DB.IsMine(p)) and lastOf(p) < cutoff then
			players[key] = nil
			gone = gone + 1
		end
	end
	if gone > 0 then
		touched()
	end
	return gone
end

-- Counted once per change, not once per caller: a single repaint asked for
-- this three times, and each answer walked every character in the book.
local statsCache = {}

function DB.Stats(db)
	db = db or BT.db
	if statsCache.db == db and statsCache.rev == DB.rev then
		return statsCache.out
	end
	local total, mine, guilded, maxLevel = 0, 0, 0, 0
	local byClass = {}
	for _, p in DB.Each(db) do
		total = total + 1
		if DB.IsMine(p) then mine = mine + 1 end
		if p.guild and p.guild ~= "" then guilded = guilded + 1 end
		if (p.level or 0) > maxLevel then maxLevel = p.level end
		if p.class then byClass[p.class] = (byClass[p.class] or 0) + 1 end
	end
	statsCache.db, statsCache.rev = db, DB.rev
	statsCache.out = { total = total, mine = mine, guilded = guilded,
		maxLevel = maxLevel, byClass = byClass }
	return statsCache.out
end

-- THE BOOK HAS A SIZE (Josh 2026-09-24). A character is small packed, but a
-- book that only ever grows still ends up as big as the realm. Past `max`
-- characters some have to go - whole days at a time, so what is left always
-- covers "everybody seen since" some day - and anything you have written on
-- stays, whatever its age.
local DAY = 86400

-- LOW LEVELS FIRST (Josh 2026-09-25: "level 1-10 are typically bank alts,
-- and throwaway toons. After that, I think it makes sense to remove the
-- oldest last seen"). A character on file at 1-10 goes before anyone else,
-- the longest unseen of them first; only when there are not enough of them
-- does the book start on the rest, oldest first. A character with no level on
-- file is one of the rest: chat names a level-60 main as readily as an alt.
DB.CAP_LOW = 10
local HOUR = 3600

local function levelOf(p)
	if type(p) == "string" then
		return P.Level(p)
	end
	return p.level
end

-- whole buckets (days, or hours for the low levels), oldest first, until at
-- least `need` are counted; returns the first bucket NOT to remove (every one
-- before it goes), and how many that is
local function oldestDays(perDay, need)
	local days = {}
	for d in pairs(perDay) do
		days[#days + 1] = d
	end
	table.sort(days)
	local taken, upTo = 0, -math.huge
	for _, d in ipairs(days) do
		if taken >= need then
			break
		end
		taken = taken + perDay[d]
		upTo = d + 1
	end
	return upTo, taken
end

-- Returns how many went, how many of them were low levels, and the oldest
-- day kept of the rest (unix seconds), when any of the rest had to go.
function DB.Cap(db, max)
	db = db or BT.db
	if not (db and type(max) == "number" and max > 0) then
		return 0
	end
	local players = DB.Players(db)
	local total, low, rest = 0, {}, {}
	local lowCount = 0
	for _, p in pairs(players) do
		total = total + 1
		if not (type(p) == "table" and DB.IsMine(p)) then
			local lv = levelOf(p)
			if type(lv) == "number" and lv <= DB.CAP_LOW then
				-- by the hour: which of them goes need not be whole days
				local h = math.floor(lastOf(p) / HOUR)
				low[h] = (low[h] or 0) + 1
				lowCount = lowCount + 1
			else
				local d = math.floor(lastOf(p) / DAY)
				rest[d] = (rest[d] or 0) + 1
			end
		end
	end
	local over = total - max
	if over <= 0 then
		return 0
	end
	-- the low levels, oldest days first, as many days as it takes
	local lowUpTo = -math.huge
	local restUpTo = -math.huge
	if lowCount >= over then
		lowUpTo = oldestDays(low, over)
	else
		lowUpTo = math.huge
		restUpTo = oldestDays(rest, over - lowCount)
	end
	local gone, lowGone = 0, 0
	for key, p in pairs(players) do
		if not (type(p) == "table" and DB.IsMine(p)) then
			local lv = levelOf(p)
			local isLow = type(lv) == "number" and lv <= DB.CAP_LOW
			local t = lastOf(p)
			if (isLow and math.floor(t / HOUR) < lowUpTo) or (not isLow and math.floor(t / DAY) < restUpTo) then
				players[key] = nil
				gone = gone + 1
				if isLow then
					lowGone = lowGone + 1
				end
			end
		end
	end
	if gone > 0 then
		touched()
	end
	return gone, lowGone, restUpTo > -math.huge and restUpTo * DAY or nil
end
