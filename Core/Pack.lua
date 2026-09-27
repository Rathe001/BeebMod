-- THE BOOK, PACKED (Josh 2026-09-24). A character was a table of up to twenty
-- named fields - about 430 bytes of the saved file and 800 of memory, most of
-- it field names, quotes and ten-digit timestamps. At rest a character is one
-- short string instead, keyed by name:
--
--   ["Drae Moreweth"] = "IFU..."
--
-- and the moment anything wants to READ it as a character (a tooltip, a note,
-- a sighting), DB.Get unpacks it into the table it always was. So the book is
-- mostly strings, plus the few hundred characters this session has touched;
-- PLAYER_LOGOUT packs those back.
--
-- Words are not spelled out on every row: classes, races, guilds, zones and
-- the server a GUID names are each a list on the book, and a row carries the
-- place in the list. The lists only ever grow, so a place never changes
-- meaning.
--
-- Pure Lua, so tests/run.lua exercises all of it headless.
--
-- THE LAYOUT, fixed width, in a 64-letter alphabet (0 = nothing on file):
--
--   pos  len  field
--    1    1   class          a place in words.class
--    2    1   race           ...words.race
--    3    1   level
--    4    3   guild          1 = seen with no guild, n+1 = words.guild[n]
--    7    2   zone           words.zone; where they were LAST seen (no time)
--    9    4   last           minutes since 2026-01-01
--   13    3   first          hours since 2026-01-01
--   16    3   levelAt        hours
--   19    3   guildAt        hours
--   22    2   seen           capped at 4095
--   24    1   bits           1 = vouched for by a list the client builds,
--                             2 = heard from another copy, not seen yourself
--                                 (the census is no longer shared: read only
--                                 so DB.DropHeard can find such a row)
--   25    1   server         the realm number in the GUID, words.server
--   26    6   guid           the rest of the GUID, as a number
--   32    9n  guild history  guild 3, first 3 (hours), last 3 (hours) each
--
-- Times come back to the minute (last) and the hour (the rest): "seen 3 hours
-- ago" is the question, not the second. A row this cannot say otherwise - a
-- note, a tag, a field it does not know, a time before 2026 - is left a
-- table. Nothing else is lost by packing: it only happens when it can be
-- undone.
local _, BT = ...

local P = {}
BT.Pack = P

local byte, sub, floor, concat = string.byte, string.sub, math.floor, table.concat

local DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE, CHAR = {}, {}
for i = 1, 64 do
	CHAR[i - 1] = DIGITS:sub(i, i)
	VALUE[DIGITS:byte(i)] = i - 1
end

P.EPOCH = 1767225600 -- 2026-01-01 00:00 UTC
P.HEAD = 31
P.STINT = 9

local function enc(n, width, out)
	for i = width - 1, 0, -1 do
		local unit = 64 ^ i
		local d = floor(n / unit)
		out[#out + 1] = CHAR[d]
		n = n - d * unit
	end
end

local function dec(s, at, width)
	local n = 0
	for i = at, at + width - 1 do
		n = n * 64 + VALUE[byte(s, i)]
	end
	return n
end

-- a time as whole minutes or hours since the epoch, plus one (0 = none);
-- nil when it cannot be said in `width` letters
local function when(t, unit, width)
	if t == nil then
		return 0
	end
	if type(t) ~= "number" or t < P.EPOCH then
		return nil
	end
	local n = floor((t - P.EPOCH) / unit) + 1
	return n < 64 ^ width and n or nil
end

local function at(n, unit)
	return n > 0 and (P.EPOCH + (n - 1) * unit) or nil
end

-- THE WORDS. Saved on the book as plain lists; the way back from a word to
-- its place is built in memory the first time it is wanted.
local KINDS = { class = 63, race = 63, zone = 4095, guild = 262142, server = 63 }
P.KINDS = KINDS
local places = setmetatable({}, { __mode = "k" })

function P.Words(db)
	db.words = db.words or {}
	local w = db.words
	for kind in pairs(KINDS) do
		w[kind] = w[kind] or {}
	end
	local ix = places[w]
	if not ix then
		ix = {}
		for kind in pairs(KINDS) do
			ix[kind] = {}
			for i, word in ipairs(w[kind]) do
				ix[kind][word] = i
			end
		end
		places[w] = ix
	end
	return w, ix
end

-- its place in the list, added if it is new; nil when the list is full
local function place(db, kind, word)
	local w, ix = P.Words(db)
	local i = ix[kind][word]
	if i then
		return i
	end
	local list = w[kind]
	if #list >= KINDS[kind] then
		return nil
	end
	list[#list + 1] = word
	ix[kind][word] = #list
	return #list
end

-- The name and realm a key stands for: "Beeb Bob" is this book's realm,
-- "Beeb Bob@Faerlina" says its own.
function P.Split(db, key)
	local name, realm = key:match("^(.*)@(.*)$")
	if name then
		return name, realm
	end
	return key, db.realm
end

local PACKED = {
	name = true, realm = true, class = true, race = true, level = true, levelAt = true,
	guild = true, guildAt = true, guilds = true, zone = true, zoneAt = true,
	first = true, last = true, seen = true, vouch = true, guid = true, heard = true,
}
-- written by older versions, and dropped rather than kept
local DEAD = { given = true, surname = true, srcName = true, src = true, faction = true, sex = true }

local function guildCode(db, g)
	if g == nil then
		return 0
	elseif g == "" then
		return 1
	end
	local i = type(g) == "string" and place(db, "guild", g)
	return i and i + 1 or nil
end

local function word(db, kind, v)
	if v == nil then
		return 0
	end
	return type(v) == "string" and place(db, kind, v) or nil
end

-- The string for a row, or nil if the row has anything a string cannot say.
function P.Pack(db, key, p)
	if type(p) ~= "table" then
		return nil
	end
	for k in pairs(p) do
		if not (PACKED[k] or DEAD[k]) then
			return nil -- a note, a tag, a rating, or a field this has not met
		end
	end
	local name, realm = P.Split(db, key)
	if p.name ~= name or p.realm ~= realm or not (p.vouch == nil or p.vouch == true)
		or not (p.heard == nil or p.heard == true) then
		return nil
	end
	local level = p.level
	if level ~= nil and not (type(level) == "number" and level >= 1 and level <= 63 and level % 1 == 0) then
		return nil
	end
	local seen = p.seen or 0
	if type(seen) ~= "number" or seen < 0 or seen % 1 ~= 0 then
		return nil
	end
	local server, id = 0, 0
	if p.guid ~= nil then
		if type(p.guid) ~= "string" then
			return nil
		end
		local s, hex = p.guid:match("^Player%-(%d+)%-(%x+)$")
		-- only a GUID that comes back spelled exactly the same
		if not (s and #hex == 8 and ("%08X"):format(tonumber(hex, 16)) == hex) then
			return nil
		end
		server, id = word(db, "server", s), tonumber(hex, 16)
	end
	local fields = {
		{ word(db, "class", p.class), 1 },
		{ word(db, "race", p.race), 1 },
		{ level or 0, 1 },
		{ guildCode(db, p.guild), 3 },
		{ word(db, "zone", p.zone), 2 },
		{ when(p.last, 60, 4), 4 },
		{ when(p.first, 3600, 3), 3 },
		{ when(p.levelAt, 3600, 3), 3 },
		{ when(p.guildAt, 3600, 3), 3 },
		{ math.min(seen, 4095), 2 },
		{ (p.vouch and 1 or 0) + (p.heard and 2 or 0), 1 },
		{ server, 1 },
		{ id, 6 },
	}
	local out = {}
	for _, f in ipairs(fields) do
		if f[1] == nil then
			return nil
		end
		enc(f[1], f[2], out)
	end
	if p.guilds ~= nil then
		if type(p.guilds) ~= "table" then
			return nil
		end
		for i, h in ipairs(p.guilds) do
			local g = type(h) == "table" and type(h.name) == "string" and h.name ~= ""
				and guildCode(db, h.name)
			local a, b = type(h) == "table" and when(h.first, 3600, 3), type(h) == "table" and when(h.last, 3600, 3)
			if not (g and a and b) then
				return nil
			end
			for k in pairs(h) do
				if k ~= "name" and k ~= "first" and k ~= "last" then
					return nil
				end
			end
			enc(g, 3, out)
			enc(a, 3, out)
			enc(b, 3, out)
		end
		-- a history with holes in it would come back shorter
		local n = 0
		for _ in pairs(p.guilds) do
			n = n + 1
		end
		if n ~= #p.guilds then
			return nil
		end
	end
	return concat(out)
end

local function guildWord(w, n)
	if n == 0 then
		return nil
	elseif n == 1 then
		return ""
	end
	return w.guild[n - 1]
end

local function wordAt(list, n)
	return n > 0 and list[n] or nil
end

-- Fill `into` with the row a string says. `light` leaves out the GUID and the
-- guild history: a census walk wants neither, and making the GUID's string
-- for every character in the book is fourteen thousand strings of garbage.
-- Every field is written, present or not, so the same table can be handed
-- one row after another.
function P.Unpack(db, key, s, into, light)
	into = into or {}
	local w = P.Words(db)
	into.name, into.realm = P.Split(db, key)
	into.class = wordAt(w.class, VALUE[byte(s, 1)])
	into.race = wordAt(w.race, VALUE[byte(s, 2)])
	local level = VALUE[byte(s, 3)]
	into.level = level > 0 and level or nil
	into.guild = guildWord(w, dec(s, 4, 3))
	into.zone = wordAt(w.zone, dec(s, 7, 2))
	into.zoneAt = nil
	into.last = at(dec(s, 9, 4), 60)
	into.first = at(dec(s, 13, 3), 3600)
	into.levelAt = at(dec(s, 16, 3), 3600)
	into.guildAt = at(dec(s, 19, 3), 3600)
	into.seen = dec(s, 22, 2)
	local bits = VALUE[byte(s, 24)]
	into.vouch = bits % 2 == 1 or nil
	into.heard = math.floor(bits / 2) % 2 == 1 or nil
	into.guid, into.guilds = nil, nil
	if light then
		into.light = true
		return into
	end
	into.light = nil
	local server = VALUE[byte(s, 25)]
	if server > 0 then
		into.guid = ("Player-%s-%08X"):format(w.server[server] or "0", dec(s, 26, 6))
	end
	if #s > P.HEAD then
		local h = {}
		for i = P.HEAD + 1, #s, P.STINT do
			h[#h + 1] = {
				name = guildWord(w, dec(s, i, 3)),
				first = at(dec(s, i + 3, 3), 3600),
				last = at(dec(s, i + 6, 3), 3600),
			}
		end
		into.guilds = h
	end
	return into
end

-- Just the last sighting, for sorting the book by age without unpacking it.
function P.Last(s)
	return at(dec(s, 9, 4), 60)
end

-- whether a packed row was heard from another copy of BeebMod, not seen
function P.Heard(s)
	return math.floor(VALUE[byte(s, 24)] / 2) % 2 == 1
end

-- and the level, for the same reason (nil when none is on file)
function P.Level(s)
	local level = VALUE[byte(s, 3)]
	return level > 0 and level or nil
end
