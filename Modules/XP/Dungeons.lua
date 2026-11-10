-- Dungeons for your level, in the XP tooltip (Josh 2026-10-04: "adding a
-- recommended dungeon(s) section to the level tooltip that shows level
-- appropriate dungeons ... don't forget all of the existing dungeons - not
-- just the new ones").
--
-- WHERE THE RANGES COME FROM. The nine new ones: Blizzard's own list, posted
-- by Kaivax on 2026-09-15 (us.forums.blizzard.com/en/wow/t/2349672), which
-- put Krol'dok Stronghold at 40-45 after BlizzCon had shown 40-55. Which side
-- may use the two new ones near the capitals is from the BlizzCon coverage
-- (Warcraft Tavern, 2026-09-13): the Ruins of Lordaeron are the Horde's, the
-- Hall of Thanes under Ironforge the Alliance's. The Classic ones: the
-- original ranges as PC Games lists them (pcgames.de, "Classic Dungeons:
-- Level-Bereich"), the figures most guides give - except the Armory, which
-- PC Games prints as 35-45, the Cathedral's; 32-42 is the wing's usual
-- range. Guides disagree on a few. THE DEADMINES (2026-10-17, audit) is
-- 17-26, Blizzard's own Classic range, where guides give 15-22 to 18-23; at
-- 17-24 levels 24 and 25 never saw it. These ranges are used only where the
-- game's group finder doesn't give its own (D.FromFinder, 2026-11-06).
-- THE GAME'S OWN, WRITTEN DOWN (Josh 2026-11-10: "the OpenMap dungeon level
-- ranges are different and seem more precise ... I'm just not sure where
-- they came from"). Every range below is now the group finder's, from the
-- client's GroupFinderActivity table (MinLevel and MaxLevelSuggestion, build
-- 1.60.1.70888, read through wago.tools): the same numbers the game's Looking
-- For Group window shows. OpenMap's are a different number from the game's
-- tables (LFGDungeons' ContentTuning, the level a dungeon is tuned to), with
-- five levels added for the top: The Deadmines 16-21, where the finder says
-- 17-26. Dire Maul is its East wing's, the first of the three.
--
-- NOT YET WHICH HAVE QUESTS FOR YOU: nothing in the game or BeebMod's data
-- says which quests a dungeon holds.
local _, BT = ...

local D = {}
BT.Dungeons = D

-- in order of their lowest level; side is the only faction that can use one
D.LIST = {
	{ name = "Ragefire Chasm", lo = 13, hi = 18, side = "Horde" },
	{ name = "The Hall of Thanes", lo = 13, hi = 20, side = "Alliance" },
	{ name = "Ruins of Lordaeron", lo = 15, hi = 22, side = "Horde" },
	{ name = "Wailing Caverns", lo = 15, hi = 24 },
	{ name = "The Deadmines", lo = 17, hi = 26 },
	{ name = "Shadowfang Keep", lo = 20, hi = 30 },
	{ name = "The Stockade", lo = 24, hi = 32, side = "Alliance" },
	{ name = "Blackfathom Deeps", lo = 24, hi = 32 },
	{ name = "Excavation Site: Wetlands", lo = 26, hi = 33 },
	{ name = "City of Dalaran", lo = 28, hi = 35 },
	{ name = "Gnomeregan", lo = 29, hi = 38 },
	{ name = "Razorfen Kraul", lo = 29, hi = 38 },
	{ name = "Scarlet Monastery Graveyard", lo = 30, hi = 38 },
	{ name = "Scarlet Monastery Library", lo = 33, hi = 41 },
	{ name = "The Drowned City", lo = 35, hi = 42 },
	{ name = "Scarlet Monastery Armory", lo = 36, hi = 44 },
	{ name = "Razorfen Downs", lo = 37, hi = 46 },
	{ name = "Scarlet Monastery Cathedral", lo = 38, hi = 46 },
	{ name = "Krol'dok Stronghold", lo = 40, hi = 47 },
	{ name = "Uldaman", lo = 41, hi = 51 },
	{ name = "Zul'Farrak", lo = 44, hi = 54 },
	{ name = "Maraudon", lo = 46, hi = 55 },
	{ name = "Alcaz Prison", lo = 48, hi = 55 },
	{ name = "Temple of Atal'Hakkar", lo = 50, hi = 60 },
	{ name = "Blackrock Depths", lo = 52, hi = 60 },
	{ name = "Dire Maul", lo = 54, hi = 60 },
	{ name = "Blackmaw Hold", lo = 55, hi = 60 },
	{ name = "Lower Blackrock Spire", lo = 55, hi = 60 },
	{ name = "Shaper's Terrace", lo = 58, hi = 60 },
	{ name = "Stratholme", lo = 58, hi = 60 },
	{ name = "Scholomance", lo = 58, hi = 60 },
	{ name = "Upper Blackrock Spire", lo = 59, hi = 60 },
}

-- THE SWEET SPOT (Josh 2026-10-04: "Rather than starting closest to my
-- level, can we find the sweet spot of the dungeon? Just the average of the
-- min and max level").
-- EVERY ONE IN RANGE, NOT THREE (Josh 2026-11-10: "Dungeons should show all
-- dungeons that are in my range, not just the top 3"). A level 19 saw three
-- of its five. Counted from these ranges, the most at any level is nine, at
-- 59 and 60, and the most zones eight, at 43 (Zones.lua).

-- the middle of a dungeon's range
function D.Sweet(d)
	return (d.lo + d.hi) / 2
end

-- WHETHER A RANGE TAKES A LEVEL: its top level is the one you leave it at
-- (Josh 2026-10-04: a level 10 was sent back to the 1-10 starting zones,
-- whose middle is a hair nearer 10 than Westfall's). A range that ends at the
-- level cap keeps its last level, the cap having nowhere to go.
D.CAP = 60
function D.Takes(d, level)
	return level >= d.lo and (level < d.hi or d.hi >= D.CAP and level <= d.hi)
end

-- the entries of a list whose range takes in this level, for this side
-- (with no side known, every one), nearest their sweet spot first, and
-- `limit` at most where one is given; a tie goes to the lower one, then by
-- name, so the list holds still.
-- The zones use it too (Modules/XP/Zones.lua).
function D.Pick(list, level, side, limit)
	local out = {}
	if type(level) ~= "number" then
		return out
	end
	for _, d in ipairs(list or {}) do
		if D.Takes(d, level) and (not d.side or not side or d.side == side) then
			out[#out + 1] = d
		end
	end
	table.sort(out, function(a, b)
		local da, db = math.abs(level - D.Sweet(a)), math.abs(level - D.Sweet(b))
		if da ~= db then
			return da < db
		end
		if a.lo ~= b.lo then
			return a.lo < b.lo
		end
		return a.name < b.name
	end)
	for i = #out, (limit or #out) + 1, -1 do
		out[i] = nil
	end
	return out
end

-- HOW HARD, BY WHERE YOU ARE IN THE RANGE (Josh 2026-10-04: "I would
-- expect the hall of thanes to be orange for my level 14 rogue. 13-14 orange,
-- 15-16 yellow, 17-18 green"). The quest colours by the range's lowest level
-- called it yellow, and by its middle (Josh's first thought) yellow from 13 to
-- 17: a five-level range's middle is never three above you inside it. So the
-- range is cut in equal steps, each a colour: a dungeon in thirds - orange,
-- yellow, green - and a zone, which you start at its lowest level, in halves
-- - yellow, green. The colours are the quests' (Core/Util.lua).
D.STEPS = {
	dungeon = { "verydifficult", "difficult", "standard" },
	zone = { "difficult", "standard" },
}
function D.RangeColour(entry, level, kind)
	local steps = D.STEPS[kind] or D.STEPS.dungeon
	local span = entry.hi - entry.lo
	local at = span > 0 and (level - entry.lo) / span or 1
	local i = math.min(#steps, math.max(1, math.floor(at * #steps) + 1))
	return BT.Util.DIFFICULTY[steps[i]]
end

-- THE GROUP FINDER'S OWN RANGES (Josh 2026-11-06: "Our level ranges for
-- dungeons don't quite match the group finder ranges", The Hall of Thanes at
-- 13-20 in the game's Looking For Group window and 13-18 here). Forever has a
-- group finder now (Blizzard_GroupFinder_VanillaStyle), and each of its
-- activities carries the level range it suggests (C_LFGList,
-- minLevelSuggestion and maxLevelSuggestion: the numbers its window shows).
-- Those replace the ones written above, matched by name with "The" and the
-- punctuation left out, so "Hall of Thanes" is The Hall of Thanes and
-- "Scarlet Monastery - Graveyard" the Graveyard. A dungeon the finder doesn't
-- list for you - the other side's - keeps its written range. Read once the
-- finder answers, then not again this session.
-- FOUR GO BY ANOTHER NAME there (2026-11-10, the client's table), so they
-- kept the written range: the finder's name for them leads to ours.
D.FINDER_NAMES = {
	["Stormwind Stockades"] = "The Stockade",
	["Sunken Temple"] = "Temple of Atal'Hakkar",
	["Dire Maul (East)"] = "Dire Maul",
	["Stratholme (Main Gate)"] = "Stratholme",
}
-- THE RAIDS' GNOMEREGAN IS NOT THE DUNGEON. The finder lists Blackfathom
-- Deeps, Gnomeregan and the Sunken Temple twice: as dungeons, and as raids
-- for ten or twenty (Gnomeregan 40-49). Only an activity for five or fewer is
-- read, and the first a dungeon matches is kept.
D.PARTY = 5
function D.Key(name)
	if type(name) ~= "string" then
		return nil
	end
	local k = name:lower():gsub("^the%s+", ""):gsub("[^%w]", "")
	return k ~= "" and k or nil
end

function D.FromFinder()
	if D.fromFinder then
		return D.fromFinder
	end
	local L = rawget(_G, "C_LFGList")
	if not (type(L) == "table" and type(L.GetAvailableCategories) == "function"
		and type(L.GetAvailableActivities) == "function" and type(L.GetActivityInfoTable) == "function") then
		return 0
	end
	local byKey = {}
	for _, d in ipairs(D.LIST) do
		byKey[D.Key(d.name)] = d
	end
	local okC, cats = pcall(L.GetAvailableCategories)
	if not (okC and type(cats) == "table") then
		return 0
	end
	local n, seen = 0, {}
	for _, cat in ipairs(cats) do
		local okA, acts = pcall(L.GetAvailableActivities, cat)
		for _, id in ipairs((okA and type(acts) == "table") and acts or {}) do
			local okI, info = pcall(L.GetActivityInfoTable, id)
			if okI and type(info) == "table" then
				local lo, hi = tonumber(info.minLevelSuggestion), tonumber(info.maxLevelSuggestion)
				local group
				if type(L.GetActivityGroupInfo) == "function" and info.groupFinderActivityGroupID then
					local okG, g = pcall(L.GetActivityGroupInfo, info.groupFinderActivityGroupID)
					group = okG and type(g) == "string" and g or nil
				end
				local d
				for _, name in ipairs({ info.fullName, info.shortName,
					group and type(info.shortName) == "string" and (group .. " " .. info.shortName) or false }) do
					local named = type(name) == "string" and D.FINDER_NAMES[name]
					d = d or (named and byKey[D.Key(named)]) or (name and byKey[D.Key(name)])
				end
				local size = tonumber(info.maxNumPlayers)
				if size and size > D.PARTY then
					d = nil
				end
				if d and not seen[d] and lo and hi and lo > 0 and hi >= lo then
					seen[d] = true
					d.lo, d.hi, d.finder = lo, hi, true
					n = n + 1
				end
			end
		end
	end
	if n > 0 then
		D.fromFinder = n
	end
	return n
end

-- the dungeons for a level and a side
function D.For(level, side, limit)
	D.FromFinder()
	return D.Pick(D.LIST, level, side, limit)
end

-- NEXT, WHEN NONE IS YET (Josh 2026-10-04: "I am level 10 so I think I
-- should see 1 dungeon showing up right?"). The first starts at 13, so a
-- level 10 saw no dungeons at all. The dungeon that starts soonest above your
-- level, for your side, if it starts within D.SOON levels; two that start
-- at the same level both, by name.
D.SOON = 5
function D.Next(level, side, within)
	D.FromFinder()
	local out = {}
	if type(level) ~= "number" then
		return out
	end
	within = within or D.SOON
	local first
	for _, d in ipairs(D.LIST) do
		if d.lo > level and d.lo - level <= within and (not d.side or not side or d.side == side) then
			if not first or d.lo < first then
				first = d.lo
			end
		end
	end
	for _, d in ipairs(D.LIST) do
		if d.lo == first and (not d.side or not side or d.side == side) then
			out[#out + 1] = d
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
