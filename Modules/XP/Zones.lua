-- Questing zones for your level, in the XP tooltip, the way the dungeons are
-- (Josh 2026-10-04: "How about questing zones. Could we add those in a
-- similar way? There should be recommended level ranges for each zone").
--
-- THE GAME'S RANGES WHERE IT GIVES THEM. The client's own world map shows a
-- zone's range when you point at it, from C_Map.GetMapLevels (the map's
-- AreaLabelDataProvider), so a zone the game gives a range keeps the game's,
-- and a zone new to WoW: Forever comes with its own. The zones are the world
-- map's: every one under the fallback world map, or under the two continents
-- if that finds none. A zone with no range (a capital) is left out.
--
-- AND CLASSIC'S WHERE IT DOESN'T (the same day: "Granted I'm only level 4,
-- but I'm not seeing any dungeons or zones here"). A level 4 shaman in
-- Durotar saw no zones at all, so the game may give addons no ranges on this
-- client. Z.CLASSIC is the Classic zones by map ID (the IDs this client files
-- your kills under), with the ranges most Classic guides give; not checked
-- against this client. It also says whose zone a starting zone is, and the
-- zones after it: nothing in the game does. Every other zone is open to both.
local _, BT = ...

local Z = {}
BT.Zones = Z

Z.CLASSIC = {
	[1429] = { "Elwynn Forest", 1, 10, "Alliance" },
	[1426] = { "Dun Morogh", 1, 10, "Alliance" },
	[1438] = { "Teldrassil", 1, 10, "Alliance" },
	[1411] = { "Durotar", 1, 10, "Horde" },
	[1412] = { "Mulgore", 1, 10, "Horde" },
	[1420] = { "Tirisfal Glades", 1, 10, "Horde" },
	[1436] = { "Westfall", 10, 20, "Alliance" },
	[1432] = { "Loch Modan", 10, 20, "Alliance" },
	[1439] = { "Darkshore", 10, 20, "Alliance" },
	[1413] = { "The Barrens", 10, 25, "Horde" },
	[1421] = { "Silverpine Forest", 10, 20, "Horde" },
	[1433] = { "Redridge Mountains", 15, 25 },
	[1442] = { "Stonetalon Mountains", 15, 27 },
	[1440] = { "Ashenvale", 18, 30 },
	[1431] = { "Duskwood", 18, 30 },
	[1424] = { "Hillsbrad Foothills", 20, 30 },
	[1437] = { "Wetlands", 20, 30 },
	[1441] = { "Thousand Needles", 25, 35 },
	[1416] = { "Alterac Mountains", 30, 40 },
	[1417] = { "Arathi Highlands", 30, 40 },
	[1443] = { "Desolace", 30, 40 },
	[1434] = { "Stranglethorn Vale", 30, 45 },
	[1445] = { "Dustwallow Marsh", 35, 45 },
	[1418] = { "Badlands", 35, 45 },
	[1435] = { "Swamp of Sorrows", 35, 45 },
	[1444] = { "Feralas", 40, 50 },
	[1425] = { "The Hinterlands", 40, 50 },
	[1446] = { "Tanaris", 40, 50 },
	[1427] = { "Searing Gorge", 43, 50 },
	[1447] = { "Azshara", 45, 55 },
	[1419] = { "Blasted Lands", 45, 55 },
	[1449] = { "Un'Goro Crater", 48, 55 },
	[1448] = { "Felwood", 48, 55 },
	[1428] = { "Burning Steppes", 50, 58 },
	[1422] = { "Western Plaguelands", 51, 58 },
	[1423] = { "Eastern Plaguelands", 53, 60 },
	[1452] = { "Winterspring", 53, 60 },
	[1451] = { "Silithus", 55, 60 },
	[1430] = { "Deadwind Pass", 55, 60 },
	-- A ZONE NEW TO WOW: FOREVER (Josh 2026-11-26: "Riverglades is not
	-- showing here", at level 39). The game gave no range for it, and it was
	-- not written here, so it was left out. Map 2548 is the one his kills
	-- there are filed under, level 36 to 42. Guides give 36-44 or 35-45.
	[2548] = { "Riverglades", 36, 44 },
	-- THE OTHER THREE (the same day: "Lets add the other new zones as well").
	-- Zephras Isle is where a Skyborne starts, on either side, so it is
	-- listed for a Skyborne alone (the fifth field). Map 2521 from his kills.
	[2521] = { "Zephras Isle", 1, 12, nil, "Skyborne" },
}
-- Two more whose map number nobody here has seen. They go by name: the
-- game's own map of that name where the world map lists one, so the zone is
-- not listed twice. Ranges from guides; Shen'dralas is given as 40-45 or
-- 41-45, Mount Hyjal as 55-60.
Z.NAMED = {
	{ "Shen'dralas", 40, 45 },
	{ "Mount Hyjal", 55, 60 },
}
-- Kalimdor and the Eastern Kingdoms, should the world map list nothing
Z.CONTINENTS = { 1414, 1415 }

local function children(mapID)
	local zone = Enum and Enum.UIMapType and Enum.UIMapType.Zone
	if not (C_Map and C_Map.GetMapChildrenInfo and mapID and zone) then
		return {}
	end
	local ok, list = pcall(C_Map.GetMapChildrenInfo, mapID, zone, true)
	return ok and type(list) == "table" and list or {}
end

local function gameLevels(id)
	if not (C_Map and C_Map.GetMapLevels) then
		return nil
	end
	local ok, lo, hi = pcall(C_Map.GetMapLevels, id)
	if ok and type(lo) == "number" and type(hi) == "number" and lo > 0 and hi >= lo then
		return lo, hi
	end
	return nil
end

-- every zone with a range: the game's zones and Classic's, the game's range
-- first. Kept once the game has given a range; built again while it gives
-- none, since the map's data may not be there at the first look.
-- Z.fromGame counts the ranges the game gave.
function Z.All()
	if Z.list then
		return Z.list
	end
	local names, order = {}, {}
	local function add(id, name)
		if id and not names[id] then
			names[id] = name
			order[#order + 1] = id
		end
	end
	local top = C_Map and C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID()
	local found = children(top)
	if #found == 0 then
		for _, id in ipairs(Z.CONTINENTS) do
			for _, info in ipairs(children(id)) do
				found[#found + 1] = info
			end
		end
	end
	for _, info in ipairs(found) do
		add(info.mapID, info.name)
	end
	for id, z in pairs(Z.CLASSIC) do
		add(id, z[1])
	end
	-- a zone written by name: under the game's number for it, or its name
	local named = {}
	for _, z in ipairs(Z.NAMED) do
		local id = z[1]
		for _, info in ipairs(found) do
			if info.name == z[1] and info.mapID then
				id = info.mapID
				break
			end
		end
		named[id] = z
		add(id, z[1])
	end
	local list = {}
	Z.fromGame = 0
	for _, id in ipairs(order) do
		local z = Z.CLASSIC[id] or named[id]
		local lo, hi = gameLevels(id)
		if lo then
			Z.fromGame = Z.fromGame + 1
		elseif z then
			lo, hi = z[2], z[3]
		end
		if lo then
			list[#list + 1] = { id = id, name = names[id] or (z and z[1]) or ("#" .. id), lo = lo, hi = hi,
				side = z and z[4] or nil, race = z and z[5] or nil }
		end
	end
	if Z.fromGame > 0 then
		Z.list = list
	end
	return list
end

-- FIVE ZONES, NOT THREE (Josh 2026-11-07: "Not sure we're showing enough of
-- the zone leveling options here"). A level 16 saw Darkshore, Loch Modan and
-- Westfall, while Redridge Mountains and Stonetalon Mountains were also his
-- level.
-- THEN EVERY ONE (Josh 2026-11-10: "I think we should list all zones in my
-- range as well, not just the top 5"). From Classic's ranges the most at
-- any level is eight, at 43.

-- the zones for a level and a side, by the dungeons' sweet spot
-- A zone for one race is listed for that race alone; with the race not
-- known, it is left out.
function Z.For(level, side, limit)
	local name, token
	if UnitRace then
		local ok, a, b = pcall(UnitRace, "player")
		if ok then
			name, token = a, b
		end
	end
	local open = {}
	for _, z in ipairs(Z.All()) do
		if not z.race or z.race == name or z.race == token then
			open[#open + 1] = z
		end
	end
	return BT.Dungeons.Pick(open, level, side, limit)
end
