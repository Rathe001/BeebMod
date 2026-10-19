-- The page's stage as a map (Josh 2026-09-28: "are we able to show a little
-- map where these were killed on the details modal?" - "Yes, build it with
-- the stage switch").
--
-- The stage holds the enemy's model; a switch in its corner, Model · Map, puts
-- the map of the zone it was first killed in there instead: the whole zone,
-- fitted to the stage, and a dot for each kill (J.Spots), all one size. The
-- choice is kept, so the next enemy opens the same way.
--
-- ZOOMED AND MOVED LIKE THE MODEL ("if we could zoom and pan the map here,
-- that would be awesome"): the wheel comes closer to where the pointer is, a
-- drag moves the map about once it is bigger than the stage, and Reset view
-- shows the whole zone again. The dots keep their size, so coming closer
-- pulls a camp's dots apart. Each enemy opens on its whole zone.
--
-- A DUNGEON HAS NO MAP ON THIS CLIENT ("I don't think there are dungeon maps
-- in Forever"): an enemy met in a dungeon or a raid shows that dungeon's loading
-- screen instead, by its name, or the game's own dungeon or raid screen for
-- one the list does not know - Forever's own among them.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Expedition/Stage.lua")

local V = BT.ExpeditionWindow
local J = BT.Expedition
local W = BT.Widgets

local ST = {}
V.Stage = ST

-- the dots: the journal's own warm gold, on a dark ring so they read on any map
local DOT = { 1.00, 0.78, 0.30 }
-- ROUND AND SEE-THROUGH (Josh 2026-09-28: "I also think circle would be
-- better, and slightly transparent"). A disc - the client's round portrait
-- mask, white, tinted - with the map showing through it.
-- ONE SIZE (Josh 2026-10-03: "All the map pins should be the same size"):
-- they shrank as there were more of them, and the first kill's was drawn
-- larger than the rest. Each is ST.DOT across now, on a ring a unit wider.
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
ST.DOT = 6
local DOT_ALPHA, RING_ALPHA = 0.75, 0.55
-- how close the map comes, and how much a notch of the wheel moves it
ST.ZOOM_MAX, ST.ZOOM_STEP = 8, 1.25

-- which the stage shows, kept with the window's other choices
function ST.Mode()
	local u = BT.settings and BT.settings.expeditionUI
	return (u and u.stage == "map") and "map" or "model"
end

function ST.SetMode(mode)
	if BT.settings then
		BT.settings.expeditionUI = BT.settings.expeditionUI or {}
		BT.settings.expeditionUI.stage = (mode == "map") and "map" or nil
	end
end

-- ---------------------------------------------------------------------------
-- The zone, fitted and zoomed: pure arithmetic, for the tests
-- ---------------------------------------------------------------------------

-- The map at `zoom` (1 = the whole zone, as big as the box allows, its shape
-- kept) in a box `pw` by `ph`: how many box units to a unit of map art (k),
-- the map's size (w, h), and where its top left corner sits in the box (x,
-- y). `x` and `y` are asked for; they are kept where they leave no gap at an
-- edge a bigger map could fill, and a map smaller than the box is centred.
function ST.Layout(a, pw, ph, zoom, x, y)
	if not (a and a.lw and a.lh and a.lw > 0 and a.lh > 0 and pw > 0 and ph > 0) then
		return nil
	end
	zoom = math.max(1, math.min(ST.ZOOM_MAX, zoom or 1))
	local k = math.min(pw / a.lw, ph / a.lh) * zoom
	local w, h = a.lw * k, a.lh * k
	local function keep(v, box, size)
		if size <= box then
			return (box - size) / 2
		end
		return math.max(box - size, math.min(0, v or (box - size) / 2))
	end
	return { k = k, w = w, h = h, zoom = zoom, x = keep(x, pw, w), y = keep(y, ph, h), pw = pw, ph = ph }
end

-- The same map `f` zoomed by `by` about the point (px, py) of the box: what
-- was under the point stays under it.
function ST.ZoomAt(a, f, by, px, py)
	local zoom = math.max(1, math.min(ST.ZOOM_MAX, f.zoom * by))
	local fx, fy = (px - f.x) / f.w, (py - f.y) / f.h
	local g = ST.Layout(a, f.pw, f.ph, zoom)
	return ST.Layout(a, f.pw, f.ph, zoom, px - fx * g.w, py - fy * g.h)
end

-- The map `f` moved by (dx, dy) box units, kept in the box.
function ST.Move(a, f, dx, dy)
	return ST.Layout(a, f.pw, f.ph, f.zoom, f.x + dx, f.y + dy)
end

-- Each tile of map art `a` at `k` box units to a unit: its file, the part of
-- it that is map (the last row and column are part empty), and where it
-- goes, from the map's own top left corner.
function ST.Tiles(a, k)
	local out = {}
	local rows = math.ceil(a.lh / a.th)
	for row = 0, rows - 1 do
		for col = 0, a.cols - 1 do
			local file = a.files[row * a.cols + col + 1]
			if file then
				local w = math.min(a.tw, a.lw - col * a.tw)
				local h = math.min(a.th, a.lh - row * a.th)
				out[#out + 1] = {
					file = file, l = 0, r = w / a.tw, t = 0, b = h / a.th,
					x = col * a.tw * k, y = row * a.th * k, w = w * k, h = h * k,
				}
			end
		end
	end
	return out
end

-- where a spot (0 to 1 across the map) falls on a map laid out as `f`,
-- from the map's own top left corner
function ST.Place(f, x, y)
	return x * f.w, y * f.h
end

-- ---------------------------------------------------------------------------
-- A dungeon's loading screen
-- ---------------------------------------------------------------------------

local SCREENS = "Interface\\Glues\\LoadingScreens\\"
-- by the dungeon's name as the game gives it, "The" left off
local BY_NAME = {
	["deadmines"] = "LoadScreenDeadmines",
	["wailing caverns"] = "LoadScreenWailingCaverns",
	["shadowfang keep"] = "LoadScreenShadowfangKeep",
	["blackfathom deeps"] = "LoadScreenBlackfathomDeeps",
	["stockade"] = "LoadScreenStormwindStockade",
	["stormwind stockade"] = "LoadScreenStormwindStockade",
	["gnomeregan"] = "LoadScreenGnomeregan",
	["razorfen kraul"] = "LoadScreenRazorfenKraul",
	["razorfen downs"] = "LoadScreenRazorfenDowns",
	["scarlet monastery"] = "LoadScreenMonastery",
	["uldaman"] = "LoadScreenUldaman",
	["zul'farrak"] = "LoadScreenZulFarrak",
	["maraudon"] = "LoadScreenMaraudon",
	["temple of atal'hakkar"] = "LoadScreenSunkenTemple",
	["sunken temple"] = "LoadScreenSunkenTemple",
	["blackrock depths"] = "LoadScreenBlackrockDepths",
	["blackrock spire"] = "LoadScreenBlackrockSpire",
	["lower blackrock spire"] = "LoadScreenBlackrockSpire",
	["upper blackrock spire"] = "LoadScreenBlackrockSpire",
	["dire maul"] = "LoadScreenDireMaul",
	["scholomance"] = "LoadScreenScholomance",
	["stratholme"] = "LoadScreenStrathome",
	["ragefire chasm"] = "LoadScreenRagefireChasm",
	["molten core"] = "LoadScreenMoltenCore",
	["blackwing lair"] = "LoadScreenBlackwingLair",
	["zul'gurub"] = "LoadScreenZulGurub",
	["ruins of ahn'qiraj"] = "LoadScreenAhnQiraj20man",
	["temple of ahn'qiraj"] = "LoadScreenAhnQiraj40man",
	["ahn'qiraj temple"] = "LoadScreenAhnQiraj40man",
	["naxxramas"] = "LoadScreenNaxxramas",
}

-- the loading screen for an enemy met in a dungeon or a raid, or nil for one
-- met in the open world. BY ITS ZONE TOO (2026-10-17, audit), as its
-- category is (J.InstanceOf): an enemy killed before kills noted where they
-- were had the open world's empty map.
function ST.LoadScreen(m)
	local inst = J.InstanceOf(m)
	if not inst then
		return nil
	end
	local name = type(m.zone) == "string" and m.zone:lower():gsub("^the ", "") or ""
	local file = BY_NAME[name] or (inst == "raid" and "LoadScreenRaid" or "LoadScreenDungeon")
	return SCREENS .. file
end

-- ---------------------------------------------------------------------------
-- The view
-- ---------------------------------------------------------------------------

local function cursor(map)
	local cx, cy = GetCursorPosition()
	local scale = (map.GetEffectiveScale and map:GetEffectiveScale()) or 1
	cx, cy = (cx or 0) / scale, (cy or 0) / scale
	local left, top = map:GetLeft() or 0, map:GetTop() or 0
	return cx - left, top - cy
end

-- the map laid where `map.fit` says, and its dots on it
local function place(map)
	local f = map.fit
	if not f then
		return
	end
	map.canvas:ClearAllPoints()
	map.canvas:SetPoint("TOPLEFT", map, "TOPLEFT", f.x, -f.y)
	map.canvas:SetSize(math.max(1, f.w), math.max(1, f.h))
	for i, p in ipairs(ST.Tiles(map.art, f.k)) do
		local t = map.tiles[i]
		if t then
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", map.canvas, "TOPLEFT", p.x, -p.y)
			t:SetSize(math.max(1, p.w), math.max(1, p.h))
		end
	end
	for i, sp in ipairs(map.spots or {}) do
		local x, y = ST.Place(f, sp.x, sp.y)
		for _, d in ipairs({ map.dots[i * 2 - 1], map.dots[i * 2] }) do
			d:ClearAllPoints()
			d:SetPoint("CENTER", map.canvas, "TOPLEFT", x, -y)
		end
	end
end
ST.Placed = place

-- the whole zone again
function ST.Reset(page)
	local map = page and page.map
	if map and map.art and map.fit then
		map.fit = ST.Layout(map.art, map.fit.pw, map.fit.ph, 1)
		place(map)
	end
end

-- the map's frame on the stage, and the switch in the stage's corner
function ST.Build(page, stage, model)
	local map = CreateFrame("Frame", nil, stage)
	map:SetPoint("TOPLEFT", 1, -1)
	map:SetPoint("BOTTOMRIGHT", -1, 1)
	-- the map is bigger than the stage when zoomed: the stage's edge cuts it
	if map.SetClipsChildren then
		map:SetClipsChildren(true)
	end
	map.canvas = CreateFrame("Frame", nil, map)
	map.tiles, map.dots = {}, {}
	map.screen = map:CreateTexture(nil, "BACKGROUND")
	map.screen:SetAllPoints()
	map.screen:Hide()
	map.note = W.Label(map, "", "small")
	map.note:SetPoint("CENTER", map, "CENTER", 0, 0)
	map.note:SetWidth(240)
	map.note:SetJustifyH("CENTER")
	if map.note.SetWordWrap then
		map.note:SetWordWrap(true)
	end
	-- the wheel comes closer to the pointer; a drag moves the map
	map:EnableMouse(true)
	if map.EnableMouseWheel then
		map:EnableMouseWheel(true)
	end
	map:SetScript("OnMouseWheel", function(self, delta)
		if not (self.art and self.fit) then
			return
		end
		local px, py = cursor(self)
		local by = (delta or 0) > 0 and ST.ZOOM_STEP or 1 / ST.ZOOM_STEP
		self.fit = ST.ZoomAt(self.art, self.fit, by, px, py)
		place(self)
	end)
	-- the drag follows the pointer every frame, and only while the button is
	-- down (Josh 2026-09-30, review: it ran every frame the popup was open)
	local function drag(self)
		local d = self.dragging
		if not (d and self.art and self.fit) then
			self:SetScript("OnUpdate", nil)
			return
		end
		local px, py = cursor(self)
		self.fit = ST.Move(self.art, self.fit, px - d[1], py - d[2])
		d[1], d[2] = px, py
		place(self)
	end
	map:SetScript("OnMouseDown", function(self)
		if self.art and self.fit then
			self.dragging = { cursor(self) }
			self:SetScript("OnUpdate", drag)
		end
	end)
	map:SetScript("OnMouseUp", function(self)
		self.dragging = nil
		self:SetScript("OnUpdate", nil)
	end)
	map:Hide()
	page.map = map
	-- the model's own hint, for when the model is back
	page.modelHint = page.hint and page.hint:GetText() or nil

	local view = W.Segmented(stage, { { "model", "Model" }, { "map", "Map" } }, function(key)
		ST.SetMode(key)
		ST.Paint(page, page.enemy)
	end, 50)
	view:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -6, -6)
	-- over the model and the map, which both take the mouse
	if view.SetFrameLevel and model.GetFrameLevel then
		view:SetFrameLevel((model:GetFrameLevel() or 1) + 5)
	end
	page.view = view
	return map
end

local function texture(list, i, parent, layer)
	local t = list[i]
	if not t then
		t = parent:CreateTexture(nil, layer)
		list[i] = t
	end
	return t
end

-- the stage for enemy `m`: its model, or its map or loading screen
function ST.Paint(page, m)
	local map = page and page.map
	if not map then
		return nil
	end
	local mode = ST.Mode()
	if page.view and page.view.Select then
		page.view:Select(mode)
	end
	local onMap = mode == "map"
	page.model:SetShown(not onMap)
	map:SetShown(onMap)
	-- the man-or-woman marks belong to the model (Window.lua, V.PaintLooks)
	if V.PaintLooks then
		V.PaintLooks(page)
	end
	if page.reset then
		page.reset:Show()
	end
	if not onMap then
		if page.hint then
			page.hint:SetText(page.modelHint or "")
		end
		return "model"
	end
	for _, t in ipairs(map.tiles) do
		t:Hide()
	end
	for _, d in ipairs(map.dots) do
		d:Hide()
	end
	map.screen:Hide()
	map.note:SetText("")
	map.art, map.fit, map.spots, map.dragging = nil, nil, nil, nil

	-- a dungeon: its loading screen, the middle of it
	local screen = ST.LoadScreen(m)
	if screen then
		map.screen:SetTexture(screen)
		map.screen:SetTexCoord(0, 1, 0.12, 0.88)
		map.screen:Show()
		if page.reset then
			page.reset:Hide()
		end
		if page.hint then
			page.hint:SetText(J.InstanceOf(m) == "raid" and "Killed in a raid. Raids have no map."
				or "Killed in a dungeon. Dungeons have no map.")
		end
		return "screen"
	end

	local pw = (map.GetWidth and map:GetWidth()) or 0
	local ph = (map.GetHeight and map:GetHeight()) or 0
	local a = m and m.map and V.MapArt(m.map)
	local spots = J.Spots(m)
	if not a or #spots == 0 or pw <= 0 or ph <= 0 then
		map.note:SetText(#spots == 0 and "No kills marked yet. Kill one to mark the map."
			or "The game has no map of this zone.")
		if page.reset then
			page.reset:Hide()
		end
		if page.hint then
			page.hint:SetText("")
		end
		return "none"
	end
	map.art, map.spots = a, spots
	map.fit = ST.Layout(a, pw, ph, 1)
	local pieces = ST.Tiles(a, map.fit.k)
	for i, p in ipairs(pieces) do
		local t = texture(map.tiles, i, map.canvas, "ARTWORK")
		t:SetTexture(p.file)
		t:SetTexCoord(p.l, p.r, p.t, p.b)
		t:Show()
	end
	for i = 1, #spots do
		local size = ST.DOT
		local ring = texture(map.dots, i * 2 - 1, map.canvas, "OVERLAY")
		local dot = texture(map.dots, i * 2, map.canvas, "OVERLAY")
		ring:SetSize(size + 2, size + 2)
		ring:SetTexture(DISC)
		ring:SetVertexColor(0, 0, 0, RING_ALPHA)
		dot:SetSize(size, size)
		dot:SetTexture(DISC)
		dot:SetVertexColor(DOT[1], DOT[2], DOT[3], DOT_ALPHA)
		-- THE DOT OVER ITS RING (Josh 2026-09-28: "I just see a single black
		-- square"): textures on one layer draw in no promised order, so the
		-- rings have a sublevel and the dots the one above it
		ring:SetDrawLayer("OVERLAY", 1)
		dot:SetDrawLayer("OVERLAY", 2)
		ring:Show()
		dot:Show()
	end
	place(map)
	if page.hint then
		-- short: Reset view shares the line. The clicks on a line of their
		-- own and set apart by space, not joined by the dot, which is for data
		-- (2026-10-17, audit); under the stage is room for two lines, not three
		page.hint:SetText((#spots == 1 and "1 kill marked." or
			("%d kills marked."):format(#spots)) .. "\nWheel: zoom    Drag: move")
	end
	return "map", #pieces, #spots
end
