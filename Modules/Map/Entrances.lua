-- Dungeon entrances on the world map (Josh 2026-11-05: "Would it be possible
-- to add dungeon enterance locations to the map?", then, of the map's filter
-- menu, "Would we be able to add it as a filter here?").
--
-- WHY OUR OWN. The game's map has entrance pins of its own
-- (DungeonEntranceDataProvider, the "showDungeonEntrancesOnMap" setting), fed
-- by the dungeon journal. Forever hides that filter, the journal does not load
-- here, and C_EncounterJournal.GetDungeonEntrancesForMap answered an empty list
-- in Dun Morogh with the setting on. So BeebMod carries the list.
--
-- WHERE THE POSITIONS COME FROM (Josh 2026-11-10: "BeebMod doesn't seem to
-- have dungeon locations in the right place. I have OpenMap installed which
-- also shows the locations, and they are different. Can we use the same
-- locations?"). The Stockade sat about 160 yards from OpenMap's.
-- The classic dungeons: the game's own entrance, as OpenMap places them. The
-- client's Map table gives each instance the spot your corpse is moved to when
-- you die inside (Corpse_0 and Corpse_1, in world yards; build 1.60.1.70888,
-- read through wago.tools). Each zone's corners in world yards are in its
-- UiMapAssignment row, which turns that into the zone map's numbers. Six of
-- Questie's spots, used here before, were 7 to 19 points away: the
-- Stockade, Gnomeregan, the Deadmines, Uldaman, the Temple of Atal'Hakkar and
-- Blackrock Mountain. The game's spot is the portal itself, which can be deep
-- in a cave or a mountain: the Deadmines' is down the mine from Moonbrook. The
-- table has one spot each, so Uldaman's back door and Stratholme's service
-- gate are still Questie's. Blackrock Mountain has two spots, one for the
-- Depths and one for the Spire, at their two portals.
-- Forever's nine have no spot in the table. Five are where OpenMap puts them,
-- placed by its makers against Leatrix Maps: the Hall of Thanes, the Ruins of
-- Lordaeron, the Excavation Site, the City of Dalaran (shown in Alterac too)
-- and the Drowned City. The other four are from Warcraft Tavern's guides
-- (warcrafttavern.com/forever/guides/, read 2026-11-05), as before: Blackmaw
-- Hold has the tunnel's mouth in Azshara as well as the portal in Winterspring,
-- and Alcaz Prison's was given in whole numbers.
--
-- HOW IT IS DRAWN. Not as one of the map's own pins: those are made and
-- sorted inside the map's secure code. A layer of ours on the map's canvas,
-- at the level the game keeps for entrance pins, so quests, the flight
-- points and your own arrow stay above them. The canvas grows as you zoom, so
-- each pin is shrunk by as much to stay the same size on the screen.
local _, BT = ...
local CreateFrame, _, hooksecurefunc = BT.Cpu.For("Modules/Map/Entrances.lua")

local M = BT.Module({
	key = "entrances",
	feature = "interface",
	title = "Dungeon entrances",
	order = 99,
})

-- the line in the map's filter menu, worded like the game's own
M.FILTER = "Dungeon Entrances"
M.FILTER_TIP = "Where each dungeon's entrance is, with its level range. Added by BeebMod."
M.MENU = "MENU_WORLD_MAP_TRACKING"

-- the pin, on the screen
M.SIZE = 20
M.ATLAS = "Dungeon"
M.FALLBACK = "Interface\\COMMON\\Indicator-Yellow"
-- the game's level for its own entrance pins, when it can't be asked
M.LEVEL_TYPE = "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE"
M.LEVEL = 2000
-- two spots of one place closer than this on a bigger map are drawn once
-- (Blackrock Spire from Searing Gorge and from the Burning Steppes)
M.NEAR = 0.03
-- a continent or anything smaller; not the whole world
M.CONTINENT = 2

-- { name, map, x, y }; `wings` for a place that holds several dungeons. The
-- names are the XP tooltip's (Modules/XP/Dungeons.lua), which has the levels.
local SM = { "Scarlet Monastery Graveyard", "Scarlet Monastery Library",
	"Scarlet Monastery Armory", "Scarlet Monastery Cathedral" }
local BRS = { "Lower Blackrock Spire", "Upper Blackrock Spire" }
M.SPOTS = {
	{ "Ragefire Chasm", 1454, 53.0, 48.9 },
	{ "Wailing Caverns", 1413, 47.7, 35.0 },
	{ "The Deadmines", 1436, 38.2, 77.5 },
	{ "Shadowfang Keep", 1421, 44.7, 67.8 },
	{ "The Stockade", 1453, 50.4, 66.2 },
	{ "Blackfathom Deeps", 1440, 16.5, 11.0 },
	{ "Gnomeregan", 1426, 17.7, 39.2 },
	{ "Scarlet Monastery", 1420, 85.1, 31.4, wings = SM },
	{ "Razorfen Kraul", 1413, 42.3, 89.9 },
	{ "Razorfen Downs", 1413, 50.9, 92.9 },
	{ "Uldaman", 1418, 35.2, 10.3 },
	{ "Uldaman", 1418, 65.2, 43.5 },
	{ "Zul'Farrak", 1446, 38.7, 19.9 },
	{ "Maraudon", 1443, 29.1, 62.9 },
	{ "Temple of Atal'Hakkar", 1435, 77.3, 35.9 },
	{ "Blackrock Depths", 1427, 27.1, 72.5 },
	{ "Blackrock Depths", 1428, 22.6, 7.5 },
	{ "Blackrock Spire", 1427, 40.8, 95.6, wings = BRS },
	{ "Blackrock Spire", 1428, 33.0, 25.2, wings = BRS },
	{ "Dire Maul", 1444, 62.0, 33.3 },
	{ "Stratholme", 1423, 26.1, 10.4 },
	{ "Stratholme", 1423, 47.9, 23.9 },
	{ "Scholomance", 1422, 69.1, 73.0 },
	-- Forever's own
	{ "The Hall of Thanes", 1455, 27.7, 47.9 },
	{ "Ruins of Lordaeron", 1458, 72.5, 11.4 },
	{ "Excavation Site: Wetlands", 1437, 47.8, 56.2 },
	{ "City of Dalaran", 1421, 69.3, 45.6 },
	{ "City of Dalaran", 1416, 8.5, 59.3 },
	{ "The Drowned City", 1434, 21.3, 27.8 },
	{ "Krol'dok Stronghold", 2548, 37.5, 37.5 },
	{ "Alcaz Prison", 1445, 75.0, 15.0 },
	{ "Blackmaw Hold", 1447, 38.7, 33.4 },
	{ "Blackmaw Hold", 1452, 66.6, 84.4 },
	{ "Shaper's Terrace", 1449, 48.1, 6.1 },
}

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then
		return a, b, c, d
	end
	return nil
end

local function cmap()
	return rawget(_G, "C_Map")
end

-- the dungeons a spot leads to, from the XP tooltip's list, in its order
function M.Dungeons(spot)
	if BT.Dungeons and BT.Dungeons.FromFinder then
		BT.Dungeons.FromFinder()
	end
	local list = BT.Dungeons and BT.Dungeons.LIST or {}
	local wanted = {}
	for _, name in ipairs(spot.wings or { spot[1] }) do
		wanted[name] = true
	end
	local out = {}
	for _, d in ipairs(list) do
		if wanted[d.name] then
			out[#out + 1] = d
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Where on a map
-- ---------------------------------------------------------------------------

local function info(mapID)
	local C = cmap()
	local i = C and call(C.GetMapInfo, mapID)
	return type(i) == "table" and i or nil
end

-- whether `top` is the map `id` sits in, or a map above that
function M.Above(top, id)
	local seen = 0
	local i = info(id)
	while i and seen < 10 do
		local parent = i.parentMapID
		if parent == top then
			return true
		end
		if not parent or parent == 0 then
			return false
		end
		i = info(parent)
		seen = seen + 1
	end
	return false
end

-- a spot's place on `mapID`, from 0 to 1 each way, or nil if it isn't on it
function M.On(spot, mapID)
	local x, y = spot[3] / 100, spot[4] / 100
	if spot[2] == mapID then
		return x, y
	end
	if not M.Above(mapID, spot[2]) then
		return nil
	end
	local C = cmap()
	local left, right, top, bottom = call(C and C.GetMapRectOnMap, spot[2], mapID)
	if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number"
		or right <= left or bottom <= top then
		return nil
	end
	return left + x * (right - left), top + y * (bottom - top)
end

-- every spot shown on `mapID`: { spot, x, y }
function M.SpotsFor(mapID)
	local out = {}
	if type(mapID) ~= "number" then
		return out
	end
	local i = info(mapID)
	if i and type(i.mapType) == "number" and i.mapType < M.CONTINENT then
		return out
	end
	for _, spot in ipairs(M.SPOTS) do
		local x, y = M.On(spot, mapID)
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			local twin = false
			for _, had in ipairs(out) do
				if had.spot[1] == spot[1] and math.abs(had.x - x) < M.NEAR and math.abs(had.y - y) < M.NEAR then
					twin = true
					break
				end
			end
			if not twin then
				out[#out + 1] = { spot = spot, x = x, y = y }
			end
		end
	end
	return out
end

-- WORKED OUT ONCE A MAP (2026-11-11, audit): the map tells us of every step
-- of a zoom, and each one asked the game where all 35 spots were again. A
-- map's spots do not move, so the answer is kept, and a zoom only places the
-- pins. Forgotten when the module comes on (M.OnEnable), in case the game had
-- not answered yet.
M.kept = {}
function M.SpotsKept(mapID)
	if type(mapID) ~= "number" then
		return M.SpotsFor(mapID)
	end
	local list = M.kept[mapID]
	if not list then
		list = M.SpotsFor(mapID)
		M.kept[mapID] = list
	end
	return list
end

-- ---------------------------------------------------------------------------
-- The pins
-- ---------------------------------------------------------------------------

M.pins = {}

local function map()
	local f = rawget(_G, "WorldMapFrame")
	return type(f) == "table" and f or nil
end

local function canvas(f)
	local c = call(f.GetCanvas, f)
	if not c and f.ScrollContainer then
		c = f.ScrollContainer.Child
	end
	return c
end

function M.Layer()
	if M.layer then
		return M.layer
	end
	local f = map()
	local c = f and canvas(f)
	if not c then
		return nil
	end
	local layer = CreateFrame("Frame", nil, c)
	layer:SetAllPoints(c)
	local level = M.LEVEL
	local levels = call(f.GetPinFrameLevelsManager, f)
	if levels then
		level = call(levels.GetValidFrameLevel, levels, M.LEVEL_TYPE) or level
	end
	layer:SetFrameLevel(level)
	M.layer = layer
	return layer
end

-- a level's colour on a dungeon, the XP tooltip's way: by where you are in
-- its range, or by its first level while it's still ahead of you
function M.Colour(d)
	local D = BT.Dungeons
	local level = call(_G.UnitLevel, "player")
	if not (D and type(level) == "number") then
		return nil
	end
	if D.Takes(d, level) then
		return D.RangeColour(d, level, "dungeon")
	end
	return BT.Util.LevelColour and BT.Util.LevelColour(d.lo) or nil
end

function M.Sub(d)
	local s = ("Levels %d-%d"):format(d.lo, d.hi)
	if d.side then
		s = s .. (" · %s only"):format(d.side)
	end
	return s
end

function M.Tip(pin)
	local spot = pin and pin.spot
	if not (spot and BT.Tip) then
		return
	end
	-- NO PICTURE ON THE CARD (Josh 2026-11-05, a green smudge beside
	-- "Scholomance"). The card takes the hovered frame's `icon`, and the pin's
	-- is a piece of an atlas: the card drew the wrong piece of the sheet.
	BT.Tip.Show(pin, { near = true, build = function(t)
		local list = M.Dungeons(spot)
		if #list == 1 then
			t:Header({ name = list[1].name, sub = M.Sub(list[1]), icon = false })
			return
		end
		t:Header({ name = spot[1], sub = #list > 1 and ("%d dungeons"):format(#list) or nil, icon = false })
		for _, d in ipairs(list) do
			t:ListRow(d.name, ("%d-%d"):format(d.lo, d.hi), nil, M.Colour(d))
		end
	end })
end

local function makePin(layer)
	local pin = CreateFrame("Frame", nil, layer)
	pin:SetSize(M.SIZE, M.SIZE)
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints(pin)
	-- an atlas the client lacks is no error: SetAtlas answers false
	local ok, took = false, false
	if pin.icon.SetAtlas then
		ok, took = pcall(pin.icon.SetAtlas, pin.icon, M.ATLAS)
	end
	if not (ok and took ~= false) then
		pin.icon:SetTexture(M.FALLBACK)
	end
	pin:EnableMouse(true)
	-- a click goes on to the map, which zooms; only the pointer stops here
	call(pin.SetMouseClickEnabled, pin, false)
	pin:SetScript("OnEnter", function(self)
		local ok, err = pcall(M.Tip, self)
		if not ok then
			BT.Err("entrances.tip: " .. tostring(err))
		end
	end)
	pin:SetScript("OnLeave", function()
		if BT.Tip then
			BT.Tip.Hide()
		end
	end)
	return pin
end

-- every pin where it belongs on the map now open, the same size on screen
-- however far in you have zoomed
function M.Draw()
	local f = map()
	local layer = M.Layer()
	if not (f and layer) then
		return 0
	end
	local shown = {}
	if BT.Enabled("entrances") then
		shown = M.SpotsKept(call(f.GetMapID, f))
	end
	local c = canvas(f)
	local w, h = call(c.GetWidth, c), call(c.GetHeight, c)
	local scale = tonumber(call(f.GetCanvasScale, f)) or 1
	if scale <= 0 then
		scale = 1
	end
	local s = 1 / scale
	for i, at in ipairs(shown) do
		local pin = M.pins[i] or makePin(layer)
		M.pins[i] = pin
		pin.spot = at.spot
		pin:SetScale(s)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", layer, "TOPLEFT", at.x * (w or 0) / s, -at.y * (h or 0) / s)
		pin:Show()
	end
	for i = #shown + 1, #M.pins do
		M.pins[i]:Hide()
		M.pins[i].spot = nil
	end
	return #shown
end

function M.Redraw()
	local ok, err = pcall(M.Draw)
	if not ok then
		BT.Err("entrances: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------------------
-- The map and its filter menu
-- ---------------------------------------------------------------------------

function M.HookMap()
	if M.mapHooked then
		return true
	end
	local f = map()
	if not (f and hooksecurefunc) then
		return false
	end
	M.mapHooked = true
	for _, name in ipairs({ "OnMapChanged", "OnCanvasScaleChanged", "OnCanvasSizeChanged" }) do
		if type(f[name]) == "function" then
			pcall(hooksecurefunc, f, name, M.Redraw)
		end
	end
	if f.HookScript then
		pcall(f.HookScript, f, "OnShow", M.Redraw)
	end
	return true
end

-- the line in the map's filter menu: on and off for the module itself
function M.AddFilter(_, root)
	if not (root and root.CreateCheckbox) then
		return
	end
	-- A SWITCH IN BEEBMOD'S WINDOW TOO (2026-11-06, audit): the pins are a part
	-- of Interface. With Interface off they are gone, and so is this line,
	-- which would show a tick for pins that aren't there.
	if not BT.FeatureOn(BT.FeatureOf("entrances") or "interface") then
		return
	end
	local box = root:CreateCheckbox(M.FILTER,
		function() return BT.Switched("entrances") end,
		function() BT.SetEnabled("entrances", not BT.Switched("entrances")) end)
	if box and box.SetOnEnter and GameTooltip then
		box:SetOnEnter(function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(M.FILTER)
			GameTooltip:AddLine(M.FILTER_TIP, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		box:SetOnLeave(function()
			GameTooltip:Hide()
		end)
	end
end

function M.HookMenu()
	if M.menuHooked then
		return true
	end
	local Menu = rawget(_G, "Menu")
	if not (type(Menu) == "table" and type(Menu.ModifyMenu) == "function") then
		return false
	end
	M.menuHooked = pcall(Menu.ModifyMenu, M.MENU, function(owner, root)
		local ok, err = pcall(M.AddFilter, owner, root)
		if not ok then
			BT.Err("entrances.menu: " .. tostring(err))
		end
	end)
	return M.menuHooked
end

function M.Hook()
	M.HookMenu()
	M.HookMap()
end

-- the map may be loaded after us
M.events = CreateFrame("Frame")
pcall(M.events.RegisterEvent, M.events, "ADDON_LOADED")
M.events:SetScript("OnEvent", function(_, _, name)
	if type(name) == "string" and name:find("^Blizzard_WorldMap") then
		M.Hook()
		M.Redraw()
	end
end)
-- the filter is there even while the pins are off, to turn them back on
M.HookMenu()

function M:OnEnable()
	M.kept = {}
	M.Hook()
	M.Redraw()
end

M.OnBind = M.OnEnable

function M:OnDisable()
	M.Redraw()
end
