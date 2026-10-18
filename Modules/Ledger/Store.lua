-- The Ledger's own book (Josh 2026-09-26).
--
-- WHAT YOU WROTE IS THE LEDGER'S, NOT THE CENSUS'S. Notes, tags and ratings
-- used to be fields on the census's rows, so a ledger without a census had
-- nowhere to write, and the census's pruning had to step around them. They
-- live here now: one row for each person you have written on, per realm and
-- side as the census's books are, keyed the same way (U.Key) - with the name,
-- class, race, level and guild they had when you last wrote or saw them, so a
-- note still has a face without a census to ask.
--
--   BeebModDB.ledger = {
--     moved = 1,                                   the census rows' notes taken
--     realms = { ["Whitemane|All"] = { people = { [key] = row } } },
--   }
--   row = { name, realm, class, race, level, guild, guid, faction, last,
--           note, noted, notedBy, rating, tags = { [tag] = true },
--           grouped, groupedAt, groupedWhere          (Groups.lua)
--           duelsWon, duelsLost, duelAt }             (Duels.lua)
--
-- (It is filed inside BeebModDB until the Ledger is an addon of its own,
-- which takes it into a saved variable of its own once.)
local _, BT = ...

local U = BT.Util
local N = {}
BT.Notes = N

-- bumped on every change: rev for anything, noteRev for what a tooltip shows
N.rev, N.noteRev = 0, 0

local function touched(note)
	N.rev = N.rev + 1
	if note then
		N.noteRev = N.noteRev + 1
	end
	-- the Ledger's ranks hear of it: a note or a tag is points
	-- (Modules/Ledger/Ranks.lua)
	if N.onTouched then
		N.onTouched(note)
	end
	-- and anything else that shows what is written (N.Listen): the mark on
	-- the target frame (Modules/Ledger/Menu.lua)
	for _, fn in ipairs(N.listeners) do
		pcall(fn, note)
	end
end
N.Touched = touched
N.listeners = {}
function N.Listen(fn)
	N.listeners[#N.listeners + 1] = fn
end

-- the whole store, made on first use
function N.Root()
	if type(BeebModDB) ~= "table" then
		return nil
	end
	local root = BeebModDB.ledger
	if type(root) ~= "table" then
		root = { realms = {} }
		BeebModDB.ledger = root
	end
	root.realms = root.realms or {}
	return root
end

-- this realm's book: its people, and what else the Ledger keeps for the
-- realm (the commendations' dates, Modules/Ledger/Ranks.lua)
function N.Book(scopeKey)
	local root = N.Root()
	scopeKey = scopeKey or (BT.scope and BT.scope.key)
	if not (root and scopeKey) then
		return nil
	end
	-- one book for both sides (BT.ScopeKey): a key that names a side is the
	-- realm's book all the same
	if BT.ALL_SIDES then
		scopeKey = scopeKey:gsub("|[^|]*$", "|" .. BT.ALL_SIDES)
	end
	local book = root.realms[scopeKey]
	if type(book) ~= "table" then
		book = { people = {} }
		root.realms[scopeKey] = book
	end
	book.people = book.people or {}
	return book
end

-- this realm and side's people, or another book's by its scope key
function N.People(scopeKey)
	-- the made-up notes stand in for this book while they are shown
	-- (Modules/Ledger/Demo.lua); never for a book asked for by name
	if N.demo and not scopeKey then
		return N.demo
	end
	local book = N.Book(scopeKey)
	return book and book.people or nil
end

-- anything of yours on it: a row with none of these is not kept
-- A GROUP IS YOURS TOO (Josh 2026-09-29, the people you grouped with,
-- Modules/Ledger/Groups.lua): a row that holds only how often you grouped
-- with someone is kept, and not swept away as an empty one
-- AND SO IS A DUEL (Josh 2026-09-30, Modules/Ledger/Duels.lua)
function N.IsMine(p)
	return p ~= nil and (p.note ~= nil or p.tags ~= nil or p.rating ~= nil or p.grouped ~= nil
		or p.duelsWon ~= nil or p.duelsLost ~= nil)
end

-- WRITTEN ON, NOT ONLY GROUPED WITH (Josh 2026-09-30, review): a note, a tag
-- or a rating. A row that holds only how often you grouped with someone is
-- kept (IsMine), but "My notes" and "you've noted" are about what you wrote,
-- and they listed and counted everyone you had grouped with.
function N.Noted(p)
	return p ~= nil and (p.note ~= nil or p.tags ~= nil or p.rating ~= nil)
end

function N.Get(key)
	local people = key and N.People()
	return people and people[key] or nil
end

-- every person written on, in this book: for key, row in N.Each() do
function N.Each()
	return pairs(N.People() or {})
end

function N.Count()
	local n = 0
	for _ in N.Each() do
		n = n + 1
	end
	return n
end

-- the people you wrote a note, a tag or a rating on (N.Noted)
function N.CountNoted()
	local n = 0
	for _, p in N.Each() do
		if N.Noted(p) then
			n = n + 1
		end
	end
	return n
end

-- what a row keeps of who they are, whoever is telling us
local FACE = { "name", "realm", "class", "race", "level", "guild", "guid", "faction", "sex" }

-- A row for `key`, made if there is none, its face brought up to date from
-- `info` (a census row, or what a unit says). A level only rises.
function N.Ensure(key, info)
	local people = key and N.People()
	if not people then
		return nil
	end
	local p = people[key]
	if not p then
		p = {}
		people[key] = p
	end
	for _, f in ipairs(FACE) do
		local v = info and info[f]
		if v ~= nil and not (f == "level" and (p.level or 0) > v) then
			p[f] = v
		end
	end
	if not p.name then
		p.name = key:match("^(.-)@") or key
	end
	return p
end

-- a row made to be written on and then left empty is not kept
local function settle(key, p)
	if not N.IsMine(p) then
		local people = N.People()
		if people and people[key] == p then
			people[key] = nil
		end
	end
end

-- What a unit says about who it is, for N.Ensure; nil for anyone who is not
-- a player you can name.
function N.Face(unit)
	if not (UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then
		return nil
	end
	local name, realm = U.UnitFullName(unit)
	if not name then
		return nil
	end
	local key, full = U.Key(name, realm)
	if not key then
		return nil
	end
	local info = { name = full or name, realm = realm }
	local ok, _, class = pcall(UnitClass, unit)
	info.class = ok and class or nil
	-- the race's own word, not the shown one, as the census files it
	local okR, _, race = pcall(UnitRace, unit)
	info.race = okR and race or nil
	local okL, level = pcall(UnitLevel, unit)
	info.level = okL and type(level) == "number" and level > 0 and level or nil
	-- a guild, when there is one: a unit whose guild has not arrived reads as
	-- unguilded, so a unit never says anyone left one (as the census reads it)
	local okG, guild = pcall(GetGuildInfo, unit)
	info.guild = okG and guild or nil
	local okU, guid = pcall(UnitGUID, unit)
	info.guid = okU and guid or nil
	info.faction = BT.Collect and BT.Collect.Side and BT.Collect.Side(unit) or nil
	info.sex = BT.Collect and BT.Collect.Sex and BT.Collect.Sex(unit) or nil
	return key, info
end

-- TWO ROWS FOR ONE PERSON BECOME ONE (Josh 2026-09-30): counts added, tags
-- joined, notes joined as the census joins them, the latest times kept.
local COUNTS = { "grouped", "duelsWon", "duelsLost" }
local LATEST = { "groupedAt", "duelAt", "last", "noted" }
function N.Fold(to, from)
	for _, f in ipairs(COUNTS) do
		if from[f] then
			to[f] = (to[f] or 0) + from[f]
		end
	end
	for _, f in ipairs(LATEST) do
		if from[f] and (to[f] or 0) < from[f] then
			to[f] = from[f]
			if f == "groupedAt" then
				to.groupedWhere = from.groupedWhere
			end
		end
	end
	if from.note and from.note ~= "" then
		to.note = (to.note and to.note ~= "" and to.note ~= from.note)
			and (to.note .. " / " .. from.note) or from.note
	end
	if from.tags then
		to.tags = to.tags or {}
		for k in pairs(from.tags) do
			to.tags[k] = true
		end
	end
	for f, v in pairs(from) do
		if to[f] == nil then
			to[f] = v
		end
	end
	return to
end

-- ONE BOOK A REALM, AND NO REALM IN A KEY (Josh 2026-09-30, U.Key): the
-- people of this realm's books keyed "Name@Realm", whatever the realm,
-- folded back under the name alone. At every login, as the census's are.
-- Returns how many it folded.
-- ONE BOOK FOR BOTH SIDES (Josh 2026-09-30, BT.JoinSides): the people of a
-- book of one side folded into the realm's one book. Returns how many.
function N.Join(fromScope, toScope)
	local root = N.Root()
	local from = root and root.realms[fromScope]
	if not (from and fromScope ~= toScope) then
		return 0
	end
	root.realms[fromScope] = nil
	local into = N.People(toScope)
	local n = 0
	for key, p in pairs(type(from.people) == "table" and from.people or {}) do
		if type(p) == "table" then
			if into[key] then
				N.Fold(into[key], p)
			else
				into[key] = p
			end
			n = n + 1
		end
	end
	if n > 0 then
		touched(true)
	end
	return n
end

function N.FoldRealms(realm)
	local root = N.Root()
	if not (root and realm) then
		return 0
	end
	realm = realm:gsub("%s+", "")
	local n = 0
	for scopeKey, book in pairs(root.realms) do
		local r = type(scopeKey) == "string" and scopeKey:match("^(.-)|")
		local people = type(book) == "table" and book.people
		if r == realm and type(people) == "table" then
			local moves = {}
			for key in pairs(people) do
				local name = key:match("^(.*)@.*$")
				if name then
					moves[key] = name
				end
			end
			for from, to in pairs(moves) do
				local p = people[from]
				people[from] = nil
				p.realm = realm
				if people[to] then
					N.Fold(people[to], p)
				else
					people[to] = p
				end
				n = n + 1
			end
		end
	end
	if n > 0 then
		touched(true)
	end
	return n
end

-- THE BETA'S BOOKS GO AT LAUNCH (Josh 2026-10-17, BT.DropBeta in
-- Core/Init.lua): every realm's book that `gone` names, with its notes, tags,
-- commendations and rank, and the group in progress if it was a beta
-- character's. The revisions move so nothing shows a cached answer, but
-- nothing is told of a change: there are no points to announce. Returns how
-- many books went and how many people were in them.
function N.DropRealms(gone)
	local root = type(BeebModDB) == "table" and BeebModDB.ledger
	if not (type(root) == "table" and type(root.realms) == "table" and type(gone) == "function") then
		return 0, 0
	end
	local books, people = 0, 0
	for scopeKey, book in pairs(root.realms) do
		if gone(type(scopeKey) == "string" and scopeKey:match("^(.-)|") or scopeKey) then
			for _ in pairs(type(book) == "table" and type(book.people) == "table" and book.people or {}) do
				people = people + 1
			end
			root.realms[scopeKey] = nil
			books = books + 1
		end
	end
	local group = root.group
	if type(group) == "table" and type(group.me) == "string" and gone(group.me:match("@(.+)$")) then
		root.group = nil
	end
	if books > 0 then
		N.rev, N.noteRev = N.rev + 1, N.noteRev + 1
	end
	return books, people
end

-- A person seen again (the tooltip, the target): the face on their row
-- brought up to date, when there is a row. Nothing is made.
function N.Seen(key, info)
	local p = N.Get(key)
	if p and info then
		N.Ensure(key, info)
		p.last = U.Now()
	end
	return p
end

-- the census's row, when there is a census, for a face to start from
local function census(key)
	return BT.DB and BT.db and BT.DB.Get(BT.db, key) or nil
end

-- A row to write on: this one, or one made from the census's, or from
-- `info`. `info` wins where it says something.
function N.Open(key, info)
	local p = N.Get(key)
	if p then
		if info then
			N.Ensure(key, info)
		end
		return p
	end
	local from = census(key)
	if not (from or info) then
		return nil
	end
	p = N.Ensure(key, from)
	if info then
		N.Ensure(key, info)
	end
	return p
end

-- A NOTE IS A FEW LINES (Josh 2026-09-29: "we still need to have some kind of
-- character limit on the notes"). 140 characters is about five lines on the
-- card over a tooltip; a longer one covered the screen above it. A note
-- written before the limit keeps its length: it can be shortened, and
-- opening it and pressing Enter doesn't cut it.
N.MAX_NOTE = 140

-- characters, not bytes: an accented letter is two bytes and one letter
-- AND "||" IS ONE (2026-10-17, audit): the game hands back a "|" typed in a
-- box as two, and the reader sees one
function N.Length(text)
	if type(text) ~= "string" then
		return 0
	end
	return #(text:gsub("[\128-\191]", ""):gsub("||", "|"))
end

-- the most a note on this row may hold: the limit, or the old note's length
function N.Room(p)
	return math.max(N.MAX_NOTE, N.Length(p and p.note))
end

-- `text` cut to `most` characters, never through the middle of one
-- NOR BETWEEN THE TWO HALVES OF "||" (2026-10-17, audit): a cut there left
-- a lone "|", which the game reads as the start of a code
function N.Clip(text, most)
	if N.Length(text) <= most then
		return text
	end
	local n, i, len = 0, 1, #text
	while i <= len do
		local b = text:byte(i)
		if b < 128 or b >= 192 then
			n = n + 1
			if n > most then
				return text:sub(1, i - 1)
			end
		end
		-- "||" is one letter, two bytes long
		i = i + ((b == 124 and text:byte(i + 1) == 124) and 2 or 1)
	end
	return text
end

function N.SetNote(key, text, info)
	local p = N.Open(key, info)
	if not p then
		return nil
	end
	text = text and text:match("^%s*(.-)%s*$") or ""
	text = N.Clip(text, N.Room(p)):match("^(.-)%s*$")
	p.note = text ~= "" and text or nil
	p.noted = p.note and U.Now() or nil
	-- and by whom: every character on this realm and side writes in the same
	-- book, so a note without a name on it is a note from nobody
	p.notedBy = p.note and U.Me() or nil
	touched(true)
	settle(key, p)
	return p
end

function N.SetTag(key, tag, on, info)
	if not U.TagByKey(tag) then
		return nil
	end
	local p = N.Open(key, info)
	if not p then
		return nil
	end
	p.tags = p.tags or {}
	p.tags[tag] = on and true or nil
	if not next(p.tags) then
		p.tags = nil
	end
	touched(true)
	settle(key, p)
	return p
end

function N.ToggleTag(key, tag, info)
	local p = N.Get(key)
	local on = not (p and p.tags and p.tags[tag])
	return N.SetTag(key, tag, on, info), on
end

function N.SetRating(key, rating, info)
	local p = N.Open(key, info)
	if not p then
		return nil
	end
	rating = tonumber(rating)
	p.rating = (rating and rating >= 1 and rating <= 5) and math.floor(rating) or nil
	touched(true)
	settle(key, p)
	return p
end

-- a name, caseless, for matching: "bob" -> "[bB][oO][bB]"
-- ESCAPED FIRST (Josh 2026-09-30, review). The letters were mapped first, and
-- a bracket typed in the search was never escaped. Typing "[" in the
-- Ledger's search made a malformed pattern and a Lua error, and "b[o"
-- matched the wrong names. Everything that means something to a pattern is
-- escaped first, brackets too, and then the letters are mapped, as
-- Core/DB.lua does.
local function caseless(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		:gsub("%a", function(c) return "[" .. c:lower() .. c:upper() .. "]" end))
end
N.Caseless = caseless

-- The people written on, found: a prefix of either half of the name, or the
-- words anywhere in a guild or a note, as the census's search reads them.
-- query = { text, class, guild, tag, mineOnly, limit, minLevel, maxLevel }
-- (mineOnly: only the people you wrote on, not the ones you only grouped with)
-- Returns { { key, p, named } }, a name match first, then the latest written.
function N.Search(query)
	query = query or {}
	local text = (type(query.text) == "string" and query.text ~= "") and query.text:lower() or nil
	local given = text and ("^" .. caseless(text))
	local surname = text and ("^%S+%s+" .. caseless(text))
	local found = {}
	for key, p in N.Each() do
		local name = p.name or key
		local ok, named = true, true
		if text then
			named = name:find(given) ~= nil or name:find(surname) ~= nil
			ok = named
				or (p.guild ~= nil and p.guild ~= "" and p.guild:lower():find(text, 1, true) ~= nil)
				or (p.note ~= nil and p.note:lower():find(text, 1, true) ~= nil)
		end
		if ok and query.mineOnly and not N.Noted(p) then ok = false end
		if ok and query.class and p.class ~= query.class then ok = false end
		if ok and query.tag and not (p.tags and p.tags[query.tag]) then ok = false end
		if ok and query.guild and p.guild ~= query.guild then ok = false end
		if ok and query.minLevel and (p.level or 0) < query.minLevel then ok = false end
		if ok and query.maxLevel and (p.level or 0) > query.maxLevel then ok = false end
		if ok then
			found[#found + 1] = { key = key, p = p, named = named }
		end
	end
	-- the ones whose name the words begin first, as the census's search
	-- (Core/DB.lua, DB.Search)
	table.sort(found, function(a, b)
		if a.named ~= b.named then
			return a.named
		end
		local an, bn = a.p.noted or a.p.last or 0, b.p.noted or b.p.last or 0
		if an ~= bn then
			return an > bn
		end
		return (a.p.name or a.key) < (b.p.name or b.key)
	end)
	if query.limit and #found > query.limit then
		for i = #found, query.limit + 1, -1 do
			found[i] = nil
		end
	end
	return found
end

-- ---------------------------------------------------------------------------
-- THE MOVE (once): what you wrote on the census's rows, into the Ledger
-- ---------------------------------------------------------------------------

local MINE = { "note", "noted", "notedBy", "rating", "tags" }

local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = copy(v)
	end
	return out
end

-- one row of yours into `people`: what is already there and newer stays
local function take(people, key, from)
	local have = people[key]
	if have and N.IsMine(have) and (have.noted or 0) >= (from.noted or 0) then
		return false
	end
	local p = have or {}
	for _, f in ipairs(FACE) do
		if p[f] == nil then
			p[f] = from[f]
		end
	end
	p.name = p.name or key:match("^(.-)@") or key
	p.last = p.last or from.last
	for _, f in ipairs(MINE) do
		p[f] = copy(from[f])
	end
	people[key] = p
	return true
end

-- Every note, tag and rating on the census's rows, in every book, moved into
-- the Ledger - and off the census's rows, so there is one of each. Then any
-- the keep (BeebModKeep, the copy kept while this client lost saved files)
-- has that neither had. Once: BeebModDB.ledger.moved says it is done.
-- Returns how many rows came across.
function N.Move()
	local root = N.Root()
	if not root or root.moved then
		return 0
	end
	local moved = 0
	for scopeKey, book in pairs(BeebModDB.realms or {}) do
		if type(book) == "table" and type(book.players) == "table" then
			local people = N.People(scopeKey)
			for key, p in pairs(book.players) do
				-- a packed row is never one you wrote on (Core/Pack.lua)
				if type(p) == "table" and N.IsMine(p) then
					if take(people, key, p) then
						moved = moved + 1
					end
					for _, f in ipairs(MINE) do
						p[f] = nil
					end
				end
			end
		end
	end
	local keep = type(BeebModKeep) == "table" and BeebModKeep.realms
	for scopeKey, book in pairs(type(keep) == "table" and keep or {}) do
		if type(book) == "table" and type(book.players) == "table" then
			local people = N.People(scopeKey)
			for key, row in pairs(book.players) do
				if type(row) == "table" and N.IsMine(row) and not N.IsMine(people[key]) then
					take(people, key, row)
					moved = moved + 1
				end
			end
		end
	end
	root.moved = 1
	if moved > 0 then
		touched(true)
		if BT.DB then
			BT.DB.rev = (BT.DB.rev or 0) + 1
		end
	end
	N.movedOnLoad = moved > 0 and moved or nil
	return moved
end
