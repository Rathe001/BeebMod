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
--   note flags rating    yours: free text, { key = true }, 1-5
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/DB.lua")

local U = BT.Util
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
local DEAD_FIELDS = { "given", "surname", "srcName", "src", "faction", "sex" }

-- Returns how many rows it slimmed, which is what the login report prints.
function DB.Slim(db)
	local done = 0
	for _, p in pairs(DB.Players(db)) do
		local touchedOne = false
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

function DB.Migrate(db)
	db.schema = db.schema or BT.SCHEMA
	-- future schema bumps land here; version 1 is the first shape
end

function DB.Players(db)
	db = db or BT.db
	return db and db.players or {}
end

function DB.Get(db, key)
	return key and DB.Players(db)[key] or nil
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
	for _, f in ipairs({ "class", "race", "guid", "vouch" }) do
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
	if from.flags then
		to.flags = to.flags or {}
		for k in pairs(from.flags) do to.flags[k] = true end
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
		db.guids[from.guid] = toKey
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
	db.players, db.guids = db.players or {}, db.guids or {}
	local added, folded = 0, 0
	for key, p in pairs(from.players) do
		if db.players[key] then
			absorb(db.players[key], p)
			folded = folded + 1
		else
			db.players[key] = p
			added = added + 1
		end
		local row = db.players[key]
		if row.guid then
			db.guids[row.guid] = key
		end
	end
	db.stats = db.stats or { sightings = 0 }
	db.stats.sightings = (db.stats.sightings or 0) + ((from.stats and from.stats.sightings) or 0)
	touched()
	return added, folded
end

-- ONE BOOK, ONE REALM (Josh 2026-09-19). The realm was renamed from "Classic
-- Beta PvE" to "Classic Beta PvE 2" between builds, and 308 characters stayed
-- filed under the old spelling: the same people, counted twice in the census
-- and found twice in a search. A book belongs to one realm, so a row keyed to
-- a name that is this realm's name with something added or taken off the end
-- IS this realm's row, and the two become one.
--
-- Deliberately narrow: only a name that contains the other as a prefix, and
-- only when there is enough of it to mean something. "Whitemane" and
-- "Faerlina" are two realms and always will be.
local function sameRealm(a, b)
	if not (a and b) then
		return false
	end
	if a == b then
		return true
	end
	local long, short = a, b
	if #short > #long then
		long, short = short, long
	end
	return #short >= 6 and long:sub(1, #short) == short
end

function DB.FoldRealms(db, realm)
	db = db or BT.db
	if not (db and realm and realm ~= "" and db.players) then
		return 0
	end
	-- collect first, then edit: re-keying the table you are walking is an
	-- "invalid key to next" error, not a warning
	local rekey = {}
	for key in pairs(db.players) do
		local name, r = key:match("^(.*)@(.*)$")
		if name and r and r ~= realm and sameRealm(r, realm) then
			rekey[key] = name .. "@" .. realm
		end
	end
	local moved = 0
	for from, to in pairs(rekey) do
		local p = db.players[from]
		db.players[from] = nil
		if db.players[to] then
			absorb(db.players[to], p)
		else
			p.realm = realm
			db.players[to] = p
		end
		local row = db.players[to]
		if row.guid then
			db.guids[row.guid] = to
		end
		moved = moved + 1
	end
	for guid, key in pairs(db.guids or {}) do
		if rekey[key] then
			db.guids[guid] = rekey[key]
		end
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
	db.guids = db.guids or {}
	-- the same character under a shorter name: file this sighting on the row
	-- that already exists, and let the fuller name own it
	local guid = info.guid
	if guid then
		local known = db.guids[guid]
		if known and known ~= key and db.players[known] then
			local mineHasSurname = U.HasSurname(short)
			local theirsHasSurname = U.HasSurname(db.players[known].name or "")
			if theirsHasSurname and not mineHasSurname then
				key, short, rname = known, db.players[known].name, db.players[known].realm
			elseif mineHasSurname and not theirsHasSurname then
				db.players[key] = db.players[key] or {}
				DB.Merge(db, known, key)
			else
				key, short, rname = known, db.players[known].name, db.players[known].realm
			end
		end
		db.guids[guid] = key
	end
	local p = db.players[key]
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
	p.given, p.surname = nil, nil
	p.srcName, p.src, p.faction, p.sex = nil, nil, nil, nil
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
	-- and not `sex` or `faction`, however the caller came by them: the two
	-- lines above have just taken those off the row, and copying them back in
	-- here put them on every row again, one sighting at a time
	for _, f in ipairs({ "class", "race", "guid" }) do
		if info[f] ~= nil then
			p[f] = info[f]
		end
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

function DB.SetNote(db, key, text)
	local p = DB.Get(db, key)
	if not p then
		return nil
	end
	text = text and text:match("^%s*(.-)%s*$") or ""
	p.note = text ~= "" and text or nil
	p.noted = p.note and U.Now() or nil
	-- and by whom: every character on this realm and side writes in the same
	-- book, so a note without a name on it is a note from nobody
	p.notedBy = p.note and U.Me() or nil
	touched(true)
	BT.KeepRow(key, p)
	return p
end

function DB.SetFlag(db, key, flag, on)
	local p = DB.Get(db, key)
	if not (p and U.FlagByKey(flag)) then
		return nil
	end
	p.flags = p.flags or {}
	p.flags[flag] = on and true or nil
	if not next(p.flags) then
		p.flags = nil
	end
	touched(true)
	BT.KeepRow(key, p)
	return p
end

function DB.ToggleFlag(db, key, flag)
	local p = DB.Get(db, key)
	if not p then
		return nil
	end
	local on = not (p.flags and p.flags[flag])
	return DB.SetFlag(db, key, flag, on), on
end

function DB.SetRating(db, key, rating)
	local p = DB.Get(db, key)
	if not p then
		return nil
	end
	rating = tonumber(rating)
	p.rating = (rating and rating >= 1 and rating <= 5) and math.floor(rating) or nil
	touched(true)
	BT.KeepRow(key, p)
	return p
end

-- A record is YOURS once you have written on it; those are never pruned and
-- always sort first in a search.
function DB.IsMine(p)
	return (p.note ~= nil) or (p.flags ~= nil) or (p.rating ~= nil)
end

-- query = { text, class, guild, surname, flag, minLevel, maxLevel, mineOnly, limit }
-- Matching is case-insensitive and by prefix on name, substring on guild and
-- note, which is what you want when you half-remember a name.
-- THE LOWERCASE OF EVERY NAME, ONCE (Josh 2026-09-19). Searching used to call
-- :lower() on four fields of every character on every keystroke - about nine
-- thousand strings per letter typed with a book this size, all of them garbage
-- a moment later. They are cached beside the row instead, in a weak table so
-- it cannot keep a deleted character alive, and rebuilt for one row only when
-- that row's own text has changed.
--
-- Not stored ON the row: everything on a row is written to the saved file, and
-- doubling the file to save a microsecond is the wrong trade.
local folded = setmetatable({}, { __mode = "k" })

local function lower(p)
	local e = folded[p]
	if e and e.name == p.name and e.guild == p.guild and e.note == p.note then
		return e
	end
	-- the two halves are worked out here rather than kept on the row: this
	-- table is already being built, and it is the only place they are wanted
	local given, surname = U.SplitName(p.name)
	e = {
		name = p.name, guild = p.guild, note = p.note,
		given = (given or p.name or ""):lower(),
		surname = surname and surname:lower() or nil,
		lguild = (p.guild and p.guild ~= "") and p.guild:lower() or nil,
		lnote = p.note and p.note:lower() or nil,
	}
	folded[p] = e
	return e
end

function DB.Search(db, query)
	query = query or {}
	local text = (type(query.text) == "string" and query.text ~= "") and query.text:lower() or nil
	local rows = {}
	for key, p in pairs(DB.Players(db)) do
		local ok = true
		if query.mineOnly and not DB.IsMine(p) then
			ok = false
		end
		if ok and text then
			-- a prefix of EITHER half of the name: people remember a surname
			-- as readily as a given name, and "bob" should find "Beeb Bob"
			local f = lower(p)
			ok = f.given:sub(1, #text) == text
				or (f.surname ~= nil and f.surname:sub(1, #text) == text)
				or (f.lguild ~= nil and f.lguild:find(text, 1, true) ~= nil)
				or (f.lnote ~= nil and f.lnote:find(text, 1, true) ~= nil)
		end
		if ok and query.class and p.class ~= query.class then ok = false end
		if ok and query.flag and not (p.flags and p.flags[query.flag]) then ok = false end
		if ok and query.guild and p.guild ~= query.guild then ok = false end
		-- its own lookup: `f` above belongs to the text branch, and the
		-- surname filter can be asked for on its own
		if ok and query.surname and lower(p).surname ~= query.surname:lower() then
			ok = false
		end
		if ok and query.minLevel and (p.level or 0) < query.minLevel then ok = false end
		if ok and query.maxLevel and (p.level or 0) > query.maxLevel then ok = false end
		if ok then
			rows[#rows + 1] = { key = key, p = p }
		end
	end
	table.sort(rows, function(a, b)
		local am, bm = DB.IsMine(a.p), DB.IsMine(b.p)
		if am ~= bm then
			return am
		end
		if (a.p.last or 0) ~= (b.p.last or 0) then
			return (a.p.last or 0) > (b.p.last or 0)
		end
		return a.p.name < b.p.name
	end)
	if query.limit and #rows > query.limit then
		for i = #rows, query.limit + 1, -1 do
			rows[i] = nil
		end
	end
	return rows
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
	for key, p in pairs(DB.Players(db)) do
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
			if p.guid and db.guids then
				db.guids[p.guid] = nil
			end
			gone = gone + 1
		end
	end
	if gone > 0 then
		touched()
	end
	return gone
end

-- Someone you saw once in Ironforge two months ago and never wrote on is
-- noise. Never touches a record you have written on. Returns how many went.
function DB.Prune(db, days, now)
	db = db or BT.db
	if not (db and days and days > 0) then
		return 0
	end
	now = now or U.Now()
	local cutoff = now - days * 86400
	local gone = 0
	for key, p in pairs(DB.Players(db)) do
		if not DB.IsMine(p) and (p.last or 0) < cutoff then
			db.players[key] = nil
			if p.guid and db.guids then db.guids[p.guid] = nil end
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
	for _, p in pairs(DB.Players(db)) do
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
