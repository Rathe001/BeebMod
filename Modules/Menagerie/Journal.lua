-- The Menagerie's book: every kind of mob you have killed (Josh 2026-09-25).
--
-- NO LIST OF MOBS. Every creature's GUID carries its NPC id, so the first kill
-- of an id is a new page - this client's mobs are its own (ids around 250000
-- on Zephras Isle), and no list of the old game's would have had them. What
-- the page says about the mob - its name, type, family and rank - is read off
-- the living unit (Kills.lua) and kept once, for every character.
--
--   menagerie.mobs[npc]    what a mob is: name, kind (the creature type),
--                          family, rank, levels, the zone it was first met in
--   menagerie.chars[who]   one character's: kills[npc], first[npc], feats,
--                          earned[achievement id] = when it was earned, and
--                          the last few GUIDs counted, so a reload and a
--                          corpse looted after it are one kill, not two
--
-- ACHIEVEMENTS ARE THE SCORE (Josh 2026-09-25: "base the score off
-- achievement points rather than completion"). Without a list of every mob
-- there is no "73% complete" to show, but there is always a next milestone.
-- Points are worked out from the kills every time they are asked for, so a
-- character's points and the account's are the same arithmetic on different
-- counts, and changing a milestone here changes everyone's score at once.
-- `earned` only remembers WHEN, and which toasts have been shown.
--
-- Pure Lua - no frames - so the headless tests load it as it is.
local _, BT = ...

local U = BT.Util
local J = {}
BT.Menagerie = J

-- the kill records, per mob: the toast KillTrack made famous
J.RECORDS = {
	{ n = 100, points = 5 },
	{ n = 500, points = 10 },
	{ n = 1000, points = 20 },
}

-- the creature types the client names, in the order the journal lists them;
-- a type this list does not know (another language, a new one) is added after
J.TYPES = { "Beast", "Humanoid", "Undead", "Demon", "Dragonkin", "Elemental", "Giant", "Mechanical", "Critter" }
-- no type at all, or the client's word for none: filed together at the end
J.UNTYPED = "Other"

-- how many counted GUIDs a character remembers across a reload
local RECENT = 200

-- ---------------------------------------------------------------------------
-- The store
-- ---------------------------------------------------------------------------

function J.Store()
	if not BT.settings then
		return nil
	end
	local s = BT.settings.menagerie
	if type(s) ~= "table" then
		s = {}
		BT.settings.menagerie = s
	end
	s.mobs = s.mobs or {}
	s.chars = s.chars or {}
	return s
end

local function fresh(c)
	c.kills = c.kills or {}
	c.first = c.first or {}
	c.earned = c.earned or {}
	c.feats = c.feats or {}
	c.recent = c.recent or {}
	return c
end

-- this character's page, under name and realm (Core/Session.lua)
function J.Mine()
	local s = J.Store()
	if not s then
		return nil
	end
	local c, who = BT.Session.Mine(s.chars)
	if not c then
		c = {}
		s.chars[who] = c
	end
	return fresh(c), who
end

-- the type a mob is filed under
function J.KindOf(m)
	local k = m and m.kind
	if type(k) ~= "string" or k == "" or k == "Not specified" then
		return J.UNTYPED
	end
	return k
end

function J.IsRare(rank)
	return rank == "rare" or rank == "rareelite"
end

function J.IsElite(rank)
	return rank == "elite" or rank == "rareelite" or rank == "worldboss"
end

-- ---------------------------------------------------------------------------
-- A kill
-- ---------------------------------------------------------------------------

-- What a mob is, from whatever the living unit said. Each field is taken when
-- it is known and kept when it is not: a rank the client hid mid-fight is not
-- "normal", it is the rank we read last time (or nothing yet).
function J.Learn(info, now)
	local s = J.Store()
	if not (s and info and info.npc) then
		return nil
	end
	local m = s.mobs[info.npc]
	if not m then
		m = {}
		s.mobs[info.npc] = m
	end
	for _, field in ipairs({ "name", "kind", "family", "rank" }) do
		local v = info[field]
		if type(v) == "string" and v ~= "" then
			m[field] = v
		end
	end
	local lvl = tonumber(info.level)
	if lvl then
		-- -1 is the skull: above anything, and kept apart from the numbers
		if lvl < 0 then
			m.skull = true
		else
			m.lo = math.min(m.lo or lvl, lvl)
			m.hi = math.max(m.hi or lvl, lvl)
		end
	end
	if not m.zone and type(info.zone) == "string" and info.zone ~= "" then
		m.zone = info.zone
	end
	m.seen = now or U.Now()
	return m
end

-- a GUID counted, remembered past a reload; the oldest goes first
function J.Remember(c, guid)
	if not (c and guid) then
		return
	end
	local r = c.recent
	r[#r + 1] = guid
	while #r > RECENT do
		table.remove(r, 1)
	end
end

-- One kill, of `info` = { npc, name, kind, family, rank, level, zone,
-- myLevel, guid }. Returns whether it was a new kind, and whatever was
-- earned by it - achievements and kill records - for the toasts.
function J.Kill(info, now)
	local c = J.Mine()
	if not (c and info and info.npc) then
		return false, {}
	end
	now = now or U.Now()
	J.Learn(info, now)
	local npc = info.npc
	local was = c.kills[npc] or 0
	c.kills[npc] = was + 1
	if was == 0 then
		c.first[npc] = now
	end
	c.last = { npc = npc, at = now }
	J.Remember(c, info.guid)
	-- the feats are about the moment, so they are decided now
	local lvl, mine = tonumber(info.level), tonumber(info.myLevel)
	if lvl and mine then
		if lvl < 0 then
			c.feats.skull = c.feats.skull or now
		elseif lvl - mine >= 5 then
			c.feats.up5 = c.feats.up5 or now
		end
	end
	J.rev = (J.rev or 0) + 1
	return was == 0, J.Check(c, now, npc, was)
end

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

-- kills[npc] and feats for "char" (this character) or "account" (every
-- character added together; a feat counts once anyone has done it)
function J.Counts(scope)
	local s = J.Store()
	if not s then
		return {}, {}
	end
	if scope ~= "account" then
		local c = J.Mine()
		return c.kills, c.feats, c
	end
	local kills, feats = {}, {}
	for _, c in pairs(s.chars) do
		for npc, n in pairs(c.kills or {}) do
			kills[npc] = (kills[npc] or 0) + n
		end
		for k, v in pairs(c.feats or {}) do
			feats[k] = math.min(feats[k] or v, v)
		end
	end
	return kills, feats
end

-- everything the achievements are measured against, from one set of counts
function J.Stats(kills, feats)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local st = {
		kinds = 0, total = 0, byType = {}, families = 0, rares = 0, elites = 0, bosses = 0, zones = 0,
		feats = feats or {},
	}
	local fam, zone = {}, {}
	for npc, n in pairs(kills or {}) do
		st.kinds = st.kinds + 1
		st.total = st.total + n
		local m = mobs[npc] or {}
		local kind = J.KindOf(m)
		st.byType[kind] = (st.byType[kind] or 0) + 1
		if m.family and not fam[m.family] then
			fam[m.family] = true
			st.families = st.families + 1
		end
		if J.IsRare(m.rank) then
			st.rares = st.rares + 1
		end
		if J.IsElite(m.rank) then
			st.elites = st.elites + 1
		end
		if m.rank == "worldboss" then
			st.bosses = st.bosses + 1
		end
		if m.zone and not zone[m.zone] then
			zone[m.zone] = true
			st.zones = st.zones + 1
		end
	end
	return st
end

-- the types to list and to have achievements for: the client's usual ones,
-- then any other it has named, then the untyped
function J.Types(st)
	local out, have = {}, {}
	for _, k in ipairs(J.TYPES) do
		out[#out + 1] = k
		have[k] = true
	end
	local extra = {}
	for k in pairs(st and st.byType or {}) do
		if not have[k] and k ~= J.UNTYPED then
			extra[#extra + 1] = k
		end
	end
	table.sort(extra)
	for _, k in ipairs(extra) do
		out[#out + 1] = k
	end
	return out
end

-- ---------------------------------------------------------------------------
-- The achievements
-- ---------------------------------------------------------------------------

J.GROUPS = {
	{ key = "discover", title = "Discovery" },
	{ key = "slaughter", title = "Slaughter" },
	{ key = "types", title = "Creature types" },
	{ key = "rank", title = "Rare and elite" },
	{ key = "world", title = "Far and wide" },
	{ key = "records", title = "Kill records" },
}

-- { need, points, title }
local DISCOVER = {
	{ 10, 5, "First Pages" }, { 25, 5, "Field Notes" }, { 50, 10, "Naturalist" },
	{ 100, 10, "Collector" }, { 200, 15, "Zoologist" }, { 350, 20, "Curator" },
	{ 500, 25, "Bestiarian" }, { 750, 25, "Keeper of Beasts" }, { 1000, 50, "The Menagerie" },
}
local SLAUGHTER = {
	{ 100, 5, "Blooded" }, { 500, 5, "Hunter" }, { 1000, 10, "Slayer" }, { 5000, 15, "Reaper" },
	{ 10000, 20, "Scourge of the Wilds" }, { 25000, 25, "Extinction Event" }, { 50000, 50, "Nothing Left Standing" },
}
local TYPE_TIERS = { { 5, 5, "I" }, { 15, 10, "II" }, { 40, 15, "III" } }
local FAMILIES = { { 5, 5, "Tracker" }, { 10, 10, "Trapper" }, { 20, 20, "Beastmaster" } }
local RARES = { { 1, 10, "Rare Find" }, { 5, 10, "Rare Hunter" }, { 15, 20, "Rare Collector" }, { 30, 40, "Silver Standard" } }
local ELITES = { { 10, 5, "Elite Slayer" }, { 50, 10, "Elite Hunter" }, { 150, 20, "Elite Nemesis" } }
local ZONES = { { 5, 5, "Wanderer" }, { 15, 10, "Well Travelled" }, { 30, 20, "Everywhere at Once" } }

local function tiers(out, group, id, have, list, text)
	for _, t in ipairs(list) do
		out[#out + 1] = {
			id = id .. ":" .. t[1], group = group, title = t[3], points = t[2],
			need = t[1], have = have, text = text:format(t[1]),
		}
	end
end

local function plural(n, one, many)
	return n == 1 and one or many
end

-- Every achievement there is, measured against `st`. The type ones are made
-- for whatever types are in the list, so a type this client adds has its own.
function J.List(st)
	st = st or J.Stats()
	local out = {}
	tiers(out, "discover", "kinds", st.kinds, DISCOVER, "kill %d different kinds of mob")
	tiers(out, "slaughter", "total", st.total, SLAUGHTER, "kill %d mobs")
	for _, kind in ipairs(J.Types(st)) do
		for _, t in ipairs(TYPE_TIERS) do
			out[#out + 1] = {
				id = "type:" .. kind .. ":" .. t[1], group = "types", kind = kind,
				title = ("%s Hunter %s"):format(kind, t[3]), points = t[2], need = t[1],
				have = st.byType[kind] or 0,
				text = ("kill %d different kinds of %s"):format(t[1], kind:lower()),
			}
		end
	end
	tiers(out, "types", "family", st.families, FAMILIES, "kill beasts of %d different families")
	for _, t in ipairs(RARES) do
		out[#out + 1] = {
			id = "rare:" .. t[1], group = "rank", title = t[3], points = t[2], need = t[1], have = st.rares,
			text = ("kill %d %s"):format(t[1], plural(t[1], "rare", "different rares")),
		}
	end
	tiers(out, "rank", "elite", st.elites, ELITES, "kill %d different kinds of elite")
	out[#out + 1] = {
		id = "boss:1", group = "rank", title = "Worldbreaker", points = 25, need = 1, have = st.bosses,
		text = "kill a world boss",
	}
	tiers(out, "world", "zones", st.zones, ZONES, "meet your kills in %d different zones")
	out[#out + 1] = {
		id = "feat:up5", group = "world", title = "Punching Up", points = 10, need = 1,
		have = st.feats.up5 and 1 or 0, text = "kill a mob five or more levels above you",
	}
	out[#out + 1] = {
		id = "feat:skull", group = "world", title = "Skull and Bones", points = 25, need = 1,
		have = st.feats.skull and 1 or 0, text = "kill a mob whose level is a skull",
	}
	return out
end

-- The kill records a set of counts has earned, and the next one for each mob
-- that has a next one.
function J.Records(kills)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local earned, next = {}, {}
	for npc, n in pairs(kills or {}) do
		local name = (mobs[npc] and mobs[npc].name) or ("#" .. npc)
		for _, r in ipairs(J.RECORDS) do
			local rec = {
				id = ("rec:%d:%d"):format(npc, r.n), group = "records", npc = npc, need = r.n, have = n,
				points = r.points, title = ("%d kills on %s"):format(r.n, name),
				text = ("kill %s %d times"):format(name, r.n),
			}
			if n >= r.n then
				earned[#earned + 1] = rec
			else
				next[#next + 1] = rec
				break
			end
		end
	end
	return earned, next
end

-- points, and how many achievements, for a set of counts
function J.Points(kills, feats)
	local st = J.Stats(kills, feats)
	local points, count = 0, 0
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need then
			points = points + a.points
			count = count + 1
		end
	end
	local recs = J.Records(kills)
	for _, r in ipairs(recs) do
		points = points + r.points
		count = count + 1
	end
	return points, count, st
end

-- The score for "char" or "account", with the stats it came from.
function J.Score(scope)
	local kills, feats = J.Counts(scope)
	return J.Points(kills, feats)
end

-- What this character has just earned: every achievement now met that has no
-- date yet (dated now, and handed back for a toast), and every kill record
-- this one kill of `npc` crossed.
function J.Check(c, now, npc, was)
	local news = {}
	local st = J.Stats(c.kills, c.feats)
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need and not c.earned[a.id] then
			c.earned[a.id] = now
			news[#news + 1] = a
		end
	end
	if npc then
		local n = c.kills[npc] or 0
		local earned = J.Records({ [npc] = n })
		for _, r in ipairs(earned) do
			if (was or 0) < r.need and not c.earned[r.id] then
				c.earned[r.id] = now
				r.record = true
				news[#news + 1] = r
			end
		end
	end
	return news
end

-- the next discovery milestone: the last one passed, and the one ahead
function J.NextDiscovery(kinds)
	local prev = 0
	for _, t in ipairs(DISCOVER) do
		if kinds < t[1] then
			return prev, t[1], t[3]
		end
		prev = t[1]
	end
	return prev, nil, nil
end

-- the kill record after `n` kills, or nil past the last
function J.NextRecord(n)
	for _, r in ipairs(J.RECORDS) do
		if (n or 0) < r.n then
			return r.n
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The journal's list
-- ---------------------------------------------------------------------------

-- Every mob the counts have, filed by type in the journal's order and by name
-- within it: { { kind, mobs = { { npc, n, m } ... } } ... }
function J.Pages(kills)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local byKind = {}
	for npc, n in pairs(kills or {}) do
		local m = mobs[npc] or {}
		local kind = J.KindOf(m)
		byKind[kind] = byKind[kind] or {}
		local list = byKind[kind]
		list[#list + 1] = { npc = npc, n = n, m = m }
	end
	local out = {}
	local order = J.Types({ byType = byKind })
	order[#order + 1] = J.UNTYPED
	for _, kind in ipairs(order) do
		local list = byKind[kind]
		if list then
			table.sort(list, function(a, b)
				local an, bn = a.m.name or "", b.m.name or ""
				if an ~= bn then
					return an < bn
				end
				return a.npc < b.npc
			end)
			out[#out + 1] = { kind = kind, mobs = list }
		end
	end
	return out
end

-- the GUIDs this character counted lately, as a set
function J.Counted()
	local c = J.Mine()
	local set = {}
	for _, guid in ipairs(c and c.recent or {}) do
		set[guid] = true
	end
	return set
end
