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
--     realms = { ["Whitemane|Alliance"] = { people = { [key] = row } } },
--   }
--   row = { name, realm, class, race, level, guild, guid, last,
--           note, noted, notedBy, rating, tags = { [tag] = true } }
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
end
N.Touched = touched

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

-- this realm and side's people, or another book's by its scope key
function N.People(scopeKey)
	-- the made-up notes stand in for this book while they are shown
	-- (Modules/Ledger/Demo.lua); never for a book asked for by name
	if N.demo and not scopeKey then
		return N.demo
	end
	local root = N.Root()
	scopeKey = scopeKey or (BT.scope and BT.scope.key)
	if not (root and scopeKey) then
		return nil
	end
	local book = root.realms[scopeKey]
	if type(book) ~= "table" then
		book = { people = {} }
		root.realms[scopeKey] = book
	end
	book.people = book.people or {}
	return book.people
end

-- anything of yours on it: a row with none of these is not kept
function N.IsMine(p)
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

-- what a row keeps of who they are, whoever is telling us
local FACE = { "name", "realm", "class", "race", "level", "guild", "guid" }

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
	return key, info
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

function N.SetNote(key, text, info)
	local p = N.Open(key, info)
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
local function caseless(text)
	return (text:gsub("%a", function(c) return ("[%s%s]"):format(c:lower(), c:upper()) end)
		:gsub("[%(%)%.%%%+%-%*%?%^%$]", "%%%0"))
end

-- The people written on, found: a prefix of either half of the name, or the
-- words anywhere in a guild or a note, as the census's search reads them.
-- query = { text, class, guild, tag, minLevel, maxLevel, limit }
-- Returns { { key, p } }, the latest written first.
function N.Search(query)
	query = query or {}
	local text = (type(query.text) == "string" and query.text ~= "") and query.text:lower() or nil
	local given = text and ("^" .. caseless(text))
	local surname = text and ("^%S+%s+" .. caseless(text))
	local found = {}
	for key, p in N.Each() do
		local name = p.name or key
		local ok = true
		if text then
			ok = name:find(given) ~= nil or name:find(surname) ~= nil
				or (p.guild ~= nil and p.guild ~= "" and p.guild:lower():find(text, 1, true) ~= nil)
				or (p.note ~= nil and p.note:lower():find(text, 1, true) ~= nil)
		end
		if ok and query.class and p.class ~= query.class then ok = false end
		if ok and query.tag and not (p.tags and p.tags[query.tag]) then ok = false end
		if ok and query.guild and p.guild ~= query.guild then ok = false end
		if ok and query.minLevel and (p.level or 0) < query.minLevel then ok = false end
		if ok and query.maxLevel and (p.level or 0) > query.maxLevel then ok = false end
		if ok then
			found[#found + 1] = { key = key, p = p }
		end
	end
	table.sort(found, function(a, b)
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

-- ---------------------------------------------------------------------------
-- NAMES FROM A COMMAND
-- ---------------------------------------------------------------------------

-- your target, when it is a player: its key, its name and what it says
function N.Target()
	local key, info = N.Face("target")
	if not key then
		return nil
	end
	return key, info.name, info
end

-- someone this book or the census knows by `key`
local function known(key)
	return key and (N.Get(key) or census(key)) and true or false
end

-- Pulls a character off the front of a command (Josh 2026-09-18). Names have
-- two parts here, so "note Beeb Bob solid tank" has to read as Beeb Bob and
-- "solid tank", not as Beeb and "Bob solid tank". The longest thing that is
-- someone you know wins, then your target - which is how you use this
-- anyway, right after meeting someone.
--   /bt note "Beeb Bob" text     quotes win outright
--   /bt note Beeb Bob text       two words, when Beeb Bob is known
--   /bt note Beeb text           one word, when Beeb is known
--   /bt note text                your target
-- Returns key, the rest, the name, and what the target said (for a new row).
function N.WhoAndRest(rest)
	local quoted, qtail = rest:match('^"([^"]+)"%s*(.*)$')
	if quoted then
		local key, full = U.Key(quoted)
		if key then
			return key, qtail, full
		end
	end
	local w1, w2, tail2 = rest:match("^(%S+)%s+(%S+)%s*(.*)$")
	if w1 and w2 then
		local key, full = U.Key(w1 .. " " .. w2)
		if known(key) then
			return key, tail2, full
		end
	end
	local w, tail = rest:match("^(%S+)%s*(.*)$")
	if w then
		local key, full = U.Key(w)
		if known(key) then
			return key, tail, full
		end
	end
	local key, tname, info = N.Target()
	if key then
		return key, rest, tname, info
	end
	return nil
end
