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
	local list = {}
	Z.fromGame = 0
	for _, id in ipairs(order) do
		local z = Z.CLASSIC[id]
		local lo, hi = gameLevels(id)
		if lo then
			Z.fromGame = Z.fromGame + 1
		elseif z then
			lo, hi = z[2], z[3]
		end
		if lo then
			list[#list + 1] = { id = id, name = names[id] or (z and z[1]) or ("#" .. id), lo = lo, hi = hi,
				side = z and z[4] or nil }
		end
	end
	if Z.fromGame > 0 then
		Z.list = list
	end
	return list
end

-- the zones for a level and a side, by the dungeons' sweet spot
function Z.For(level, side, limit)
	return BT.Dungeons.Pick(Z.All(), level, side, limit)
end
