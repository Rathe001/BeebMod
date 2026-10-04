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
-- range. Guides disagree on a few (The Deadmines is 15-22 in one, 17-24 in
-- most). The client's group finder (C_LFGList) can carry Blizzard's own
-- suggested levels, but this client has no group finder of its own, and it
-- was not checked.
--
-- NOT YET WHICH HAVE QUESTS FOR YOU: nothing in the game or BeebMod's data
-- says which quests a dungeon holds.
local _, BT = ...

local D = {}
BT.Dungeons = D

-- in order of their lowest level; side is the only faction that can use one
D.LIST = {
	{ name = "Ragefire Chasm", lo = 13, hi = 18, side = "Horde" },
	{ name = "The Hall of Thanes", lo = 13, hi = 18, side = "Alliance" },
	{ name = "Ruins of Lordaeron", lo = 15, hi = 20, side = "Horde" },
	{ name = "Wailing Caverns", lo = 17, hi = 24 },
	{ name = "The Deadmines", lo = 17, hi = 24 },
	{ name = "Shadowfang Keep", lo = 22, hi = 30 },
	{ name = "The Stockade", lo = 24, hi = 31, side = "Alliance" },
	{ name = "Blackfathom Deeps", lo = 24, hi = 32 },
	{ name = "Excavation Site: Wetlands", lo = 24, hi = 29 },
	{ name = "Gnomeregan", lo = 26, hi = 38 },
	{ name = "Scarlet Monastery Graveyard", lo = 26, hi = 36 },
	{ name = "City of Dalaran", lo = 28, hi = 33 },
	{ name = "Razorfen Kraul", lo = 29, hi = 38 },
	{ name = "Scarlet Monastery Library", lo = 29, hi = 39 },
	{ name = "Scarlet Monastery Armory", lo = 32, hi = 42 },
	{ name = "Scarlet Monastery Cathedral", lo = 35, hi = 45 },
	{ name = "The Drowned City", lo = 35, hi = 40 },
	{ name = "Razorfen Downs", lo = 37, hi = 46 },
	{ name = "Krol'dok Stronghold", lo = 40, hi = 45 },
	{ name = "Uldaman", lo = 41, hi = 51 },
	{ name = "Zul'Farrak", lo = 44, hi = 54 },
	{ name = "Maraudon", lo = 46, hi = 55 },
	{ name = "Alcaz Prison", lo = 48, hi = 53 },
	{ name = "Temple of Atal'Hakkar", lo = 50, hi = 60 },
	{ name = "Blackrock Depths", lo = 52, hi = 60 },
	{ name = "Blackmaw Hold", lo = 55, hi = 60 },
	{ name = "Lower Blackrock Spire", lo = 55, hi = 60 },
	{ name = "Dire Maul", lo = 55, hi = 60 },
	{ name = "Shaper's Terrace", lo = 58, hi = 60 },
	{ name = "Upper Blackrock Spire", lo = 58, hi = 60 },
	{ name = "Stratholme", lo = 58, hi = 60 },
	{ name = "Scholomance", lo = 58, hi = 60 },
}

-- THE SWEET SPOT, AND THREE OF THEM (Josh 2026-10-04: "Rather than
-- starting closest to my level, can we find the sweet spot of the dungeon?
-- Just the average of the min and max level. We can probably cap it to 3").
-- A level 59 saw nine, from Temple of Atal'Hakkar down.
D.SHOW = 3

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
-- (with no side known, every one), nearest their sweet spot first, D.SHOW at
-- most; a tie goes to the lower one, then by name, so the list holds still.
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
	for i = #out, (limit or D.SHOW) + 1, -1 do
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

-- the dungeons for a level and a side
function D.For(level, side, limit)
	return D.Pick(D.LIST, level, side, limit)
end

-- NEXT, WHEN NONE IS YET (Josh 2026-10-04: "I am level 10 so I think I
-- should see 1 dungeon showing up right?"). The first starts at 13, so a
-- level 10 saw no dungeons at all. The dungeon that starts soonest above your
-- level, for your side, if it starts within D.SOON levels; two that start
-- at the same level both, by name.
D.SOON = 5
function D.Next(level, side, within)
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
	for i = #out, D.SHOW + 1, -1 do
		out[i] = nil
	end
	return out
end
