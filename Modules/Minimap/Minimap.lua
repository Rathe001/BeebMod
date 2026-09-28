-- The minimap, in the panel with everything else (Josh 2026-09-21).
--
-- It sits in the top-right corner of the screen in a gold ring, with a zoom
-- pair, a clock, a world-map button and a tracking eye hung around its edge -
-- a piece of furniture from a different set to everything else the toolkit
-- draws, in the corner the toolkit's own panel already occupies.
--
-- SAME BARGAIN AS THE ACTION BARS. Nothing here is reimplemented: it is the
-- client's own Minimap, moved and undressed. The wheel still zooms, a click
-- still pings, a right-click still opens the tracking menu, and every blip on
-- it is drawn by the client exactly as before. What changes is where it is,
-- what shape it is, and what is drawn around it.
--
-- WHY IT IS SQUARE. The panel is a stack of rectangles; a circle in it leaves
-- four corners of world showing and reads as something resting on the panel
-- rather than part of it. The client draws the round edge with a mask, and a
-- mask is a texture - so a white one makes it square without touching a single
-- blip.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Minimap/Minimap.lua")

local U = BT.Util

local M = BT.Module({
	key = "minimap",
	feature = "dock",
	onPage = "map",
	title = "Minimap",
	blurb = "in the panel, with the rest",
	order = 5,
	-- on the right panel, so it has a tab on the rail (Josh 2026-09-22)
	dock = true,
})

local PAD = 4
-- THE PANEL'S WIDTH IS NOT THIS MODULE'S TO SET (Josh 2026-09-21). The dock is
-- as wide as its widest section, so a minimap asking for a width of its own is
-- a second opinion about how wide the panel should be - and two constants that
-- happen to agree today stop agreeing the moment either is touched, leaving a
-- strip of empty panel beside whichever section is narrower.
--
-- It takes the width it is given and squares the map to it. This is the floor
-- rather than the size: it only decides anything when the minimap is the only
-- section left in the dock.
local FLOOR = 160
-- the caption row above the map: zone name on the left, coordinates on the
-- right. Over the map they would be words lying on streets.
local ZONE_H = 14
-- room kept at the right of the caption row for the coordinates
local COORD_W = 64
-- the icons in the map's corners: big enough to read, small enough that four
-- of them do not become a second panel
local ICON = 18

-- THE CLIENT CAN BE ASKED TO SET A MASK BUT NOT TO NAME ONE (Josh 2026-09-21).
-- SetMaskTexture exists; GetMaskTexture does not, on this build - so there was
-- nothing to remember and switching the module off left the map square in the
-- corner. This is the client's own round one, which is the right answer when
-- we could not read what it had.
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- WHAT THE CLIENT HANGS ON IT. Each is art or a button belonging to the ring,
-- and each is put back exactly as it was when the module is switched off.
-- (The world map button is not one: it has the bottom-left corner - see WHERE.
-- It was on both lists, put away here and then taken back out for the corner
-- - Josh 2026-09-24.)
local CHROME = {
	"MinimapBorder", "MinimapBorderTop", "MinimapNorthTag",
	"MinimapZoomIn", "MinimapZoomOut",
	"MinimapCompassTexture", "MinimapBackdrop",
	"MiniMapMailBorder", "TimeManagerClockButton",
	-- THE ADDON COMPARTMENT (Josh 2026-09-22): the client's menu of addons,
	-- showing how many it holds - "0", on its own line, for someone with none.
	-- Addons that register in it have their buttons in the Addon buttons line.
	"AddonCompartmentFrame",
}

-- WHAT IS FURNITURE AND WHAT IS INFORMATION (Josh 2026-09-21). The first pass
-- swept the whole ring away, and took three things with it that were not
-- decoration at all: what you are tracking, what time of day it is, and where
-- you are. Those are the only parts of the client's minimap that TELL you
-- something, and losing them to make the corner tidy is a bad trade.
--
-- They are kept and moved rather than redrawn, so tracking still opens its
-- menu and the sun still opens the calendar. The zone name is the exception:
-- it is a line of text, and the caption row draws it (see Build).
local KEEP = {
	{ name = "MiniMapTracking", spot = "TOPLEFT", x = 3, y = -3, size = 20 },
	{ name = "MiniMapTrackingFrame", spot = "TOPLEFT", x = 3, y = -3, size = 20 },
	{ name = "GameTimeFrame", spot = "TOPRIGHT", x = -3, y = -3, size = 22 },
}

-- and the art hung on those, which is ring to match the ring
local KEEP_ART = {
	"MiniMapTrackingBorder", "MiniMapTrackingBackground",
	"MiniMapTrackingButtonBorder", "MiniMapTrackingIconOverlay",
	"GameTimeFrameBorder",
}

local ZONE = { "MinimapZoneTextButton", "MinimapZoneText" }

local hidden = setmetatable({}, { __mode = "k" })
local was = {}

local function opt(name, fallback)
	local s = BT.settings and BT.settings.minimap
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

-- ALWAYS SOLID (Josh 2026-09-22). The map was see-through for a while, as a
-- setting, and every value under 100% did the same thing: the client stops
-- drawing the terrain altogether and only the blips fade. The first black box
-- was that terrain gone with the panel's fill behind it; with a hole cut in
-- the fill, the ground simply vanished and the world showed where it should
-- be. There is no see-through minimap on this client, so there is no setting,
-- and a value an earlier version saved is ignored.
function M.Opacity()
	return 1
end

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.minimap = BT.settings.minimap or {}
	BT.settings.minimap[name] = value
	M.Apply()
end
M.SetOpt = setOpt

-- ---------------------------------------------------------------------------
-- The chrome
-- ---------------------------------------------------------------------------

-- AWAY MEANS UNDER A FRAME THAT IS NEVER SHOWN (Josh 2026-09-21). Alpha and
-- Hide both lose to the client: pointing at the map runs its own OnEnter,
-- which shows the zoom pair again, and they sat on the map in the screenshot.
-- A frame whose parent is hidden cannot be seen whatever it is told, so the
-- chrome is parented to one. Alpha as well, for the textures that stay put.
local hider = CreateFrame("Frame")
hider:Hide()

local function put(thing, away)
	if not thing then
		return false
	end
	if away then
		if hidden[thing] == nil then
			hidden[thing] = {
				alpha = (thing.GetAlpha and thing:GetAlpha()) or 1,
				parent = thing.GetParent and thing:GetParent(),
				-- whether the client had it showing: the mail icon with no
				-- mail is hidden, and giving it back is not showing it
				shown = (thing.IsShown and thing:IsShown()) and true or false,
			}
		end
		if thing.SetAlpha then
			pcall(thing.SetAlpha, thing, 0)
		end
		if thing.SetParent then
			pcall(thing.SetParent, thing, hider)
		end
		if thing.Hide and thing.SetShown then
			pcall(thing.Hide, thing)
		end
	else
		local h = hidden[thing] or {}
		if thing.SetParent and h.parent then
			pcall(thing.SetParent, thing, h.parent)
		end
		if thing.SetAlpha then
			pcall(thing.SetAlpha, thing, h.alpha or 1)
		end
		if h.shown == false and thing.Hide then
			pcall(thing.Hide, thing)
		elseif thing.Show then
			pcall(thing.Show, thing)
		end
		-- forgotten once given back, so the next time it goes away it is
		-- remembered from where it is then
		hidden[thing] = nil
	end
	return true
end

function M.Chrome(away)
	local n = 0
	for _, name in ipairs(CHROME) do
		if put(_G[name], away) then
			n = n + 1
		end
	end
	-- SWEEP THE REGIONS, DO NOT ONLY NAME THEM (Josh 2026-09-21). The ring is
	-- drawn in pieces whose names differ by build, so the cluster is asked
	-- what it is drawing and everything that is not ours goes with the rest.
	local cluster = _G.MinimapCluster
	if cluster and cluster.GetRegions then
		local ok, regions = pcall(function()
			return { cluster:GetRegions() }
		end)
		for _, r in ipairs(ok and regions or {}) do
			if type(r) == "table" and not r.beebs and r.GetObjectType
				and r:GetObjectType() == "Texture" then
				put(r, away)
				n = n + 1
			end
		end
	end
	return n
end

-- ---------------------------------------------------------------------------
-- Where it lives
-- ---------------------------------------------------------------------------

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.Section("minimap", 5)
	M.frame.wantWidth = FLOOR
	-- THE DOCK STACKS BY wantHeight (Josh 2026-09-21). Setting the frame's
	-- own height is not the same thing: without this the section counted for
	-- nothing in the layout and the quest list was placed straight on top of
	-- the map.
	M.frame.wantHeight = FLOOR + ZONE_H
	-- and it squares itself to whatever width the dock hands it, whenever
	-- that changes - and when that changes the height it wants, the dock
	-- hears it (it kept stacking by the old one), once, a frame later. Not
	-- while the module is off: the map is the game's again then.
	local relaying = false
	M.frame:SetScript("OnSizeChanged", function()
		if not BT.Enabled("minimap") then
			return
		end
		if M.Fit() and not relaying and C_Timer and C_Timer.After then
			relaying = true
			C_Timer.After(0, function()
				relaying = false
				if BT.Enabled("minimap") then
					BT.Bar.Relayout()
				end
			end)
		end
	end)
	-- and it sits above the row rather than under it: the row is a strip of
	-- controls, and a picture belongs over it
	M.frame.above = true
	M.skin = BT.Pill.Surface(M.frame, "BACKGROUND", -6)

	-- THE CAPTION ROW IS OURS (Josh 2026-09-21, layout D). Six rounds went on
	-- finding the client's zone caption and coordinates and moving them here,
	-- and each round guessed wrong on something: the zone name ended up lying
	-- on the map over a button. The client's two lines of text are put away
	-- with the rest of the ring, and these two draw the same words.
	-- CENTRED IN THE ROW, NOT HUNG FROM ITS TOP (Josh 2026-09-22). The row
	-- runs from the section's top to the top of the map, PAD + ZONE_H; the
	-- text was hung PAD below the top, which sat it low, nearer the map than
	-- the line above. Each label is anchored on the row's middle instead.
	local mid = -(PAD + ZONE_H) / 2
	M.coordText = BT.Widgets.Label(M.frame, "", "small", 0.62, 0.68, 0.66)
	M.coordText:SetPoint("RIGHT", M.frame, "TOPRIGHT", -PAD, mid)
	M.coordText:SetWidth(COORD_W)
	M.coordText:SetJustifyH("RIGHT")
	M.zoneText = BT.Widgets.Label(M.frame, "", "small")
	M.zoneText:SetPoint("LEFT", M.frame, "TOPLEFT", PAD, mid)
	M.zoneText:SetPoint("RIGHT", M.frame, "TOPRIGHT", -(PAD + COORD_W + 4), mid)
	M.zoneText:SetJustifyH("LEFT")
	M.zoneText:SetWordWrap(false)
	return M.frame
end

-- the colours the client paints its own zone caption in, by who holds the
-- ground under you
local GROUND = {
	sanctuary = { 0.41, 0.80, 0.94 },
	arena = { 1.0, 0.1, 0.1 },
	combat = { 1.0, 0.1, 0.1 },
	hostile = { 1.0, 0.1, 0.1 },
	friendly = { 0.1, 1.0, 0.1 },
	contested = { 1.0, 0.7, 0.0 },
}

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if ok then
		return a, b
	end
	return nil
end

-- where you are standing, 0-100 on the zone map, or nil where there is none
-- (inside an instance, mostly)
local function whereStanding()
	local cmap = _G.C_Map
	if type(cmap) == "table" then
		local id = call(cmap.GetBestMapForUnit, "player")
		local pos = id and call(cmap.GetPlayerMapPosition, id, "player")
		if type(pos) == "table" and type(pos.GetXY) == "function" then
			local x, y = call(pos.GetXY, pos)
			if x and y then
				return x * 100, y * 100
			end
		end
	end
	local x, y = call(_G.GetPlayerMapPosition, "player")
	if x and y and (x > 0 or y > 0) then
		return x * 100, y * 100
	end
	return nil
end

function M.Caption()
	if not (M.zoneText and M.coordText) then
		return
	end
	-- (either can be left off - Josh 2026-09-24)
	M.zoneText:SetShown(opt("zoneName", true) and true or false)
	M.coordText:SetShown(opt("coords", true) and true or false)
	local zone = call(_G.GetMinimapZoneText) or call(_G.GetZoneText) or ""
	M.zoneText:SetText(zone)
	local c = GROUND[call(_G.GetZonePVPInfo) or ""] or { 1.0, 0.82, 0.0 }
	M.zoneText:SetTextColor(c[1], c[2], c[3])
	local x, y = whereStanding()
	M.coordText:SetText(x and ("%.1f, %.1f"):format(x, y) or "")
end

-- REMEMBERED PER MAP, NOT ONCE EVER (Josh 2026-09-21). Keying this on "have
-- we remembered anything" means a second Minimap - a client that rebuilds it,
-- or a test that makes its own - is put back where the FIRST one lived.
local function remember(map)
	if was.map == map then
		return
	end
	was = { map = map }
	was.parent = (map.GetParent and map:GetParent()) or UIParent
	if map.GetPoint then
		local ok, point, rel, relPoint, x, y = pcall(map.GetPoint, map, 1)
		if ok and point then
			was.at = { point, rel, relPoint, x, y }
		end
	end
	was.w = BT.Pill.Number(map.GetWidth and map:GetWidth(), nil)
	was.h = BT.Pill.Number(map.GetHeight and map:GetHeight(), nil)
	if map.GetMaskTexture then
		local ok, mask = pcall(map.GetMaskTexture, map)
		if ok then
			was.mask = mask
		end
	end
	was.mask = was.mask or ROUND
	was.alpha = BT.Pill.Number(map.GetAlpha and map:GetAlpha(), 1)
	if map.IsIgnoringParentAlpha then
		local ok, ignoring = pcall(map.IsIgnoringParentAlpha, map)
		was.ignoresParent = ok and ignoring == true
	end
end

-- Moving something of the client's, and being able to give it back. Each one
-- is remembered the first time it is touched, keyed on the frame itself.
local moved = setmetatable({}, { __mode = "k" })

local function move(thing, parent, spot, rel, relSpot, x, y, size)
	if not (thing and thing.SetParent and thing.ClearAllPoints) then
		return false
	end
	if not moved[thing] then
		local m = { parent = thing:GetParent() }
		if thing.GetPoint then
			local ok, point, r, rp, px, py = pcall(thing.GetPoint, thing, 1)
			if ok and point then
				m.at = { point, r, rp, px, py }
			end
		end
		m.w = BT.Pill.Number(thing.GetWidth and thing:GetWidth(), nil)
		m.h = BT.Pill.Number(thing.GetHeight and thing:GetHeight(), nil)
		m.shown = (thing.IsShown and thing:IsShown()) and true or false
		moved[thing] = m
	end
	if not parent then
		-- putting it back
		local m = moved[thing]
		pcall(thing.SetParent, thing, m.parent or UIParent)
		if m.at then
			pcall(thing.ClearAllPoints, thing)
			if m.at[2] then
				pcall(thing.SetPoint, thing, m.at[1], m.at[2], m.at[3], m.at[4], m.at[5])
			else
				pcall(thing.SetPoint, thing, m.at[1], m.at[4], m.at[5])
			end
		end
		if m.w and m.h and m.w > 0 and m.h > 0 and thing.SetSize then
			pcall(thing.SetSize, thing, m.w, m.h)
		end
		-- whether it shows is the client's: it shows the mail envelope when
		-- there is mail, and replaying what it was the first time we touched
		-- it hid mail that had come since (Josh 2026-09-23, audit)
		return true
	end
	-- WHAT ACTUALLY HAPPENED, NOT WHAT WAS ASKED (Josh 2026-09-21). Every one
	-- of these is a pcall, so a frame the client will not let us move fails
	-- silently and the piece stays in the corner looking untouched. The
	-- outcome is recorded and /bt minimap reports it.
	local okParent = pcall(thing.SetParent, thing, parent)
	pcall(thing.ClearAllPoints, thing)
	local okPoint = pcall(thing.SetPoint, thing, spot, rel, relSpot, x, y)
	moved[thing].took = okParent and okPoint
	moved[thing].landed = (thing.GetParent and thing:GetParent()) == parent
	if size and thing.SetSize then
		pcall(thing.SetSize, thing, size, size)
	end
	if thing.SetFrameLevel and parent.GetFrameLevel then
		pcall(thing.SetFrameLevel, thing, (parent:GetFrameLevel() or 1) + 6)
	end
	-- NOT SHOWN BY US (Josh 2026-09-23, audit): this ended with a Show, so an
	-- envelope sat in the corner with no mail, and came back after every zoom
	-- and zone change. Moving a frame does not change whether it shows; the
	-- client decides that for each of them.
	return true
end

-- The three things on the client's ring that tell you something rather than
-- decorate it: what you are tracking, what time of day it is, where you are.
-- WHAT SOMETHING IS, NOT WHAT IT IS CALLED (Josh 2026-09-21). Naming these
-- got the tracking eye, the zone caption and the day/night dial wrong on this
-- build: they exist, under names this module had not heard of, so they were
-- neither moved nor hidden and sat in the corner on their own while the map
-- came into the panel. Asking the cluster what it is carrying finds them
-- whatever the build calls them.
--
-- Anything unrecognised is LEFT ALONE rather than hidden: a frame hanging off
-- the minimap that we do not know is most likely another addon's button, and
-- hiding those is not this module's business.
-- "ZoneText" IS NOT ENOUGH OF A NAME (Josh 2026-09-21). SubZoneTextFrame is
-- the big announcement across the middle of the screen when you walk into a
-- new district - nothing to do with the minimap - and matching "ZoneText"
-- caught it. It is a FadingFrame, so being shown outside its own fade left it
-- doing arithmetic on a start time it had never been given, once per frame,
-- forever.
--
-- Everything here now has to look like the MINIMAP's furniture, not just
-- furniture: either the name says Minimap, or it is one of the two the client
-- names after what it does rather than where it lives.
-- A FRAME'S NAME IS NOT ALWAYS A NAME (Josh 2026-09-21). Walking every frame
-- in the game reaches ones whose XML gave a child the parentKey "GetName" -
-- Blizzard's own damage meter entries do - and on those the method is shadowed
-- by a FontString. Calling it throws, and using what comes back as a string
-- throws a line later. Both are guarded here rather than at eight call sites.
local function nameOf(f)
	if type(f) ~= "table" or type(f.GetName) ~= "function" then
		return ""
	end
	local ok, n = pcall(f.GetName, f)
	if ok and type(n) == "string" then
		return n
	end
	return ""
end

-- MENTIONING THE MINIMAP IS NOT BEING THE MINIMAP (Josh 2026-09-21). The
-- settings panel is full of controls named for what they configure - "show
-- this on the minimap", "rotate the minimap" - and matching the word anywhere
-- in the name dragged their labels onto the map, on top of each other.
--
-- A frame found by walking the whole UI has to be NAMED for the minimap, not
-- named after it: the name starts with Minimap, or it is the one button the
-- client names for what it does. Inside the minimap's own tree the context
-- vouches for it and the looser match still applies.
local function isMinimapish(name)
	return name:match("^Mini[Mm]ap") ~= nil
end

-- and only frames: a sweep this wide reaches font strings and textures, and
-- moving a label is how you get somebody's words lying across the map
local FRAMEISH = {
	Frame = true, Button = true, CheckButton = true, StatusBar = true,
	PlayerModel = true, ScrollFrame = true, Slider = true, ["Minimap"] = true,
}

-- WORDS ARE NOT ENOUGH (Josh 2026-09-21). "Does this frame draw any text" put
-- a queue indicator in the caption row because one of its icons carries a
-- number on it. A caption is not "has letters in it" - it is a line of text
-- and nothing else.
--
-- So: what text does it draw, and does it draw anything BUT text?
local function wordsOf(f)
	if type(f) ~= "table" or type(f.GetRegions) ~= "function" then
		return nil
	end
	local ok, list = pcall(function()
		return { f:GetRegions() }
	end)
	local text, art = nil, false
	for _, r in ipairs(ok and list or {}) do
		local kind = type(r) == "table" and r.GetObjectType
			and select(2, pcall(r.GetObjectType, r))
		if kind == "FontString" then
			local okText, t = pcall(r.GetText, r)
			if okText and type(t) == "string" and t ~= "" then
				text = text or t
			end
		elseif kind == "Texture" and not r.beebs then
			art = true
		end
	end
	if art then
		-- something with a picture on it is an icon, whatever is written
		-- across it
		return nil
	end
	return text
end

-- whether it draws a picture of its own, rather than only holding things that do
local function hasArt(f)
	if type(f) ~= "table" or type(f.GetRegions) ~= "function" then
		return false
	end
	local ok, list = pcall(function()
		return { f:GetRegions() }
	end)
	for _, r in ipairs(ok and list or {}) do
		local kind = type(r) == "table" and r.GetObjectType
			and select(2, pcall(r.GetObjectType, r))
		if kind == "Texture" and not r.beebs then
			return true
		end
	end
	return false
end

-- A BORDER WITH NOTHING IN IT IS NOT AN ICON (Josh 2026-09-22). /bt minimap
-- showed the first icon in the bottom row was a button drawing only the nine
-- pieces of a frame - corners, edges, a centre, every one a "NineSlice" atlas -
-- and no picture at all. It took the bottom-left corner and pushed the
-- day/night dial one slot in, as a faint empty box beside it. A frame whose
-- every texture is a piece of a border is furniture, and is put away.
local onlyBorder
function onlyBorder(f)
	if type(f) ~= "table" or type(f.GetRegions) ~= "function" then
		return false
	end
	local pieces = 0
	local ok, list = pcall(function()
		return { f:GetRegions() }
	end)
	for _, r in ipairs(ok and list or {}) do
		local okKind, kind = pcall(r.GetObjectType, r)
		if okKind and kind == "Texture" and not r.beebs then
			local okA, atlas = pcall(function() return r.GetAtlas and r:GetAtlas() end)
			if not (okA and type(atlas) == "string" and atlas:find("NineSlice", 1, true)) then
				return false
			end
			pieces = pieces + 1
		end
	end
	if pieces == 0 then
		return false
	end
	-- a picture kept on a child makes it a real button after all
	local okK, kids = pcall(function() return { f:GetChildren() } end)
	for _, kid in ipairs(okK and kids or {}) do
		local okS, shown = pcall(kid.IsShown, kid)
		if okS and shown and hasArt(kid) and not onlyBorder(kid) then
			return false
		end
	end
	return true
end
M.OnlyBorder = onlyBorder

-- ASK THE GAME WHAT THE ZONE IS (Josh 2026-09-21). Every attempt to find the
-- zone caption by shape failed on something: by name, because it has none; by
-- "draws only text", because it draws a background too. There is an exact
-- answer available - GetMinimapZoneText() returns the words the client is
-- putting in it - so the frame that is showing those words IS the zone
-- caption, whatever it is called and whatever else it draws.
local function anyText(f)
	if type(f) ~= "table" or type(f.GetRegions) ~= "function" then
		return nil
	end
	local ok, list = pcall(function()
		return { f:GetRegions() }
	end)
	for _, r in ipairs(ok and list or {}) do
		local kind = type(r) == "table" and r.GetObjectType
			and select(2, pcall(r.GetObjectType, r))
		if kind == "FontString" then
			local okText, t = pcall(r.GetText, r)
			if okText and type(t) == "string" and t ~= "" then
				return t
			end
		end
	end
	return nil
end

local function isZone(text)
	if type(text) ~= "string" or text == "" then
		return false
	end
	for _, fn in ipairs({ "GetMinimapZoneText", "GetSubZoneText", "GetZoneText" }) do
		if type(_G[fn]) == "function" then
			local ok, said = pcall(_G[fn])
			if ok and type(said) == "string" and said ~= "" and said == text then
				return true
			end
		end
	end
	return false
end

-- A pair of numbers with a comma between them is where you are standing.
local function isCoords(text)
	return type(text) == "string"
		and text:match("^%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*$") ~= nil
end

local function isFrame(f)
	if type(f) ~= "table" or type(f.GetObjectType) ~= "function" then
		return false
	end
	local ok, kind = pcall(f.GetObjectType, f)
	return ok and FRAMEISH[kind] == true
end

local function whatIs(f, ours)
	if not isFrame(f) then
		return nil
	end
	local name = nameOf(f)
	local near = isMinimapish(name)
	-- THE CLOCK IS NOT THE DIAL (Josh 2026-09-21). GameTimeFrame is the sun
	-- and moon you asked to keep; TimeManagerClockButton is the digital clock
	-- in its own gold ring, which is furniture - it came onto the map reading
	-- 7:51 when the two were treated as one thing.
	if name == "GameTimeFrame" then
		return "time"
	end
	if not (near or ours) then
		return nil
	end
	if name:find("Tracking") then
		return "track"
	elseif name:find("ZoneText") and near then
		return "zone"
	elseif name:find("Mail") then
		return "mail"
	elseif name:find("WorldMap") then
		return "worldmap"
	elseif name:find("InstanceDifficulty") or name:find("Difficulty") then
		return "difficulty"
	elseif name:find("Clock") or name:find("TimeManager") then
		return "clock"
	elseif name:find("Zoom") or name:find("Border") or name:find("North")
		or name:find("Compass") or name:find("Backdrop") then
		return "chrome"
	end
	return nil
end

-- EVERYTHING THE RING CARRIED, GIVEN A PLACE (Josh 2026-09-21). The first
-- passes hid what they could not identify, which ended with a bare map and
-- none of the things the client's corner actually does. Each one has a corner
-- of its own now: what you are tracking and where you are at the top, what you
-- can open at the bottom, and the clock beside the zone name.
-- THE CORNERS, ON HOVER (Josh 2026-09-21, chosen from the mockup). Six goes
-- at this were six RULES - text goes left, unless it is coordinates, unless it
-- has a picture on it - each one fixing the last screenshot and breaking
-- something else. That is a pile of exceptions rather than a design.
--
-- The layout: four corners of the map, one job each, faded out until the
-- cursor is over the panel. At rest it is a map and two lines of text; point
-- at it and the controls are where they always are. The chat window already
-- hides its scroll buttons this way, so the toolkit behaves the same twice.
local WHERE = {
	track = { spot = "TOPLEFT", x = 3, y = -3, size = ICON, hover = true },
	time = { spot = "TOPRIGHT", x = -3, y = -3, size = ICON, hover = true },
	worldmap = { spot = "BOTTOMLEFT", x = 3, y = 3, size = ICON, hover = true },
	-- MAIL IS THE EXCEPTION, and it is the whole point of mail: something you
	-- have not read yet is no use at all if you have to go looking for it. It
	-- stays up.
	mail = { spot = "BOTTOMRIGHT", x = -3, y = 3, size = ICON },
	difficulty = { spot = "TOP", x = 0, y = -3, size = ICON },
}

-- the ones this build hangs off the cluster under a key rather than a name
local BY_KEY = {
	{ obj = "MinimapCluster", key = "Tracking", kind = "track" },
	{ obj = "MinimapCluster", key = "TrackingFrame", kind = "track" },
	{ obj = "MinimapCluster", key = "ZoneTextButton", kind = "zone" },
	{ obj = "MinimapCluster", key = "MailFrame", kind = "mail" },
	{ obj = "MinimapCluster", key = "IndicatorFrame", kind = "mail" },
	{ obj = "MinimapCluster", key = "InstanceDifficulty", kind = "difficulty" },
	{ obj = "Minimap", key = "ZoomIn", kind = "chrome" },
	{ obj = "Minimap", key = "ZoomOut", kind = "chrome" },
}

-- ONE LEVEL DOWN WAS NOT FAR ENOUGH (Josh 2026-09-21). The tracking eye and
-- the day/night dial are not children of the cluster on this build - they hang
-- off something that hangs off it - so a sweep of the cluster's own children
-- found neither and both stayed in the corner above the panel.
--
-- Bounded rather than open: three levels reaches everything the client hangs
-- on its minimap, and a frame tree with a loop in it cannot take the session
-- down with it.
local function children(of, into, depth)
	into = into or {}
	depth = depth or 0
	if depth > 3 or not (of and of.GetChildren) then
		return into
	end
	local ok, list = pcall(function()
		return { of:GetChildren() }
	end)
	for _, f in ipairs(ok and list or {}) do
		if type(f) == "table" and not f.beebs then
			into[#into + 1] = f
			children(f, into, depth + 1)
		end
	end
	return into
end

M.found = {}

-- THE PICTURE IS NOT ALWAYS INSIDE THE BUTTON (Josh 2026-09-21). The client
-- hangs the day/night sun off its frame at an offset, drawn for a round ring:
-- the frame went in the corner and the sun sat a thumb's width inside the map.
-- So what the button actually DRAWS is measured - every shown texture on it
-- and on its children - and the button is shifted until that is in the corner.
local function artBox(f)
	local l, r, t, b
	local function take(region)
		if not (region and region.GetLeft and region.IsShown) then
			return
		end
		local okShown, shown = pcall(region.IsShown, region)
		if not (okShown and shown) then
			return
		end
		-- art the client has faded out is still "shown", and a ring faded to
		-- nothing would stretch the box past the picture you can see
		local okAlpha, alpha = pcall(region.GetAlpha, region)
		if okAlpha and type(alpha) == "number" and alpha <= 0 then
			return
		end
		local ok, rl, rr, rt, rb = pcall(function()
			return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
		end)
		if not (ok and type(rl) == "number" and type(rr) == "number"
			and type(rt) == "number" and type(rb) == "number") then
			return
		end
		l, r = math.min(l or rl, rl), math.max(r or rr, rr)
		t, b = math.max(t or rt, rt), math.min(b or rb, rb)
	end
	local function walk(frame, depth)
		local ok, list = pcall(function()
			return { frame:GetRegions() }
		end)
		for _, region in ipairs(ok and list or {}) do
			local okKind, kind = pcall(region.GetObjectType, region)
			if okKind and kind == "Texture" and not region.beebs then
				take(region)
			end
		end
		if depth < 2 and frame.GetChildren then
			local okKids, kids = pcall(function()
				return { frame:GetChildren() }
			end)
			for _, kid in ipairs(okKids and kids or {}) do
				local okShown, shown = pcall(kid.IsShown, kid)
				if okShown and shown then
					walk(kid, depth + 1)
				end
			end
		end
	end
	if type(f.GetRegions) == "function" then
		walk(f, 0)
	end
	return l, r, t, b
end

M.corners = setmetatable({}, { __mode = "k" })

function M.Snap(f, map, w)
	M.corners[f] = w
	if type(map.GetLeft) ~= "function" then
		return false
	end
	local l, r, t, b = artBox(f)
	local ok, ml, mr, mt, mb = pcall(function()
		return map:GetLeft(), map:GetRight(), map:GetTop(), map:GetBottom()
	end)
	if not (l and ok and type(ml) == "number" and type(mb) == "number") then
		-- /bt minimap says so, rather than the icon silently staying put
		f.beebsSnap = l and "the map has no position yet" or "nothing measurable drawn"
		return false
	end
	f.beebsSnap = ("art at %d,%d-%d,%d, map at %d,%d-%d,%d"):format(
		l, b, r, t, ml, mb, mr, mt)
	local dx, dy = 0, 0
	if w.spot:find("LEFT") then
		dx = (ml + w.x) - l
	elseif w.spot:find("RIGHT") then
		dx = (mr + w.x) - r
	end
	if w.spot:find("TOP") then
		dy = (mt + w.y) - t
	elseif w.spot:find("BOTTOM") then
		dy = (mb + w.y) - b
	end
	if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
		return false
	end
	-- added to whatever shift it already had: measuring again after a snap
	-- measures from where the snap left it
	local shift = f.beebsShift or { 0, 0 }
	f.beebsShift = { shift[1] + dx, shift[2] + dy }
	pcall(f.ClearAllPoints, f)
	pcall(f.SetPoint, f, w.spot, map, w.spot, w.x + f.beebsShift[1], w.y + f.beebsShift[2])
	return true
end

function M.Keepers(frame, map, plain)
	local n, seen, leftover, placed = 0, {}, {}, {}
	-- what was faded last time and is not in this pass (taken by the addon
	-- buttons' line, say) is given its alpha back at the end, or it stays
	-- invisible wherever it went (Josh 2026-09-23, audit)
	local before = M.hovering or {}
	M.hovering = setmetatable({}, { __mode = "k" })
	-- WHERE SOMETHING CAME FROM DECIDES WHAT AN UNNAMED ONE IS (Josh
	-- 2026-09-21). The empty bar behind the zone name and the ring round the
	-- day/night dial have no names to match on this build. Inside the
	-- minimap's own tree that is enough to go on - the client's furniture is
	-- the only thing hanging there - but a nameless frame found anywhere else
	-- could be anybody's, and is left alone.
	local pool = {}
	local function gather(list, ours)
		for _, f in ipairs(list) do
			pool[#pool + 1] = { f = f, ours = ours }
		end
	end
	-- FOUND BY KEY FIRST (Josh 2026-09-21). The zoom pair hangs off the map
	-- under a key and nothing else; walked to first as an unnamed child, it
	-- was filed as "something we do not know" before the key could say it
	-- was chrome, and the + sat in the icon row.
	for _, k in ipairs(BY_KEY) do
		local owner = _G[k.obj]
		local f = owner and owner[k.key]
		if type(f) == "table" then
			pool[#pool + 1] = { f = f, ours = true, kind = k.kind }
		end
	end
	gather(children(_G.MinimapCluster), true)
	gather(children(map), true)
	gather(children(_G.MinimapBackdrop), true)

	-- NOT IN THE MINIMAP'S TREE AT ALL (Josh 2026-09-21). Three goes at this
	-- assumed the tracking eye and the day/night dial hang off the minimap
	-- somewhere - first its children, then three levels of them, then the
	-- backdrop's. They do not. On this build they are parented somewhere else
	-- entirely, and no amount of digging under the minimap was ever going to
	-- reach them.
	--
	-- So the question is asked of the whole UI, the way it is for tooltips:
	-- EnumerateFrames walks every frame there is. It runs only while
	-- something is still missing, and what it finds is kept - so this is a
	-- walk once at login, not one per zone change.
	-- FOUND BY KEY, NOT BY NAME (Josh 2026-09-21). The client stopped naming
	-- these globally: they hang off the cluster under a parentKey, which is a
	-- direct question with a direct answer and none of the guesswork a name
	-- match needs.

	local wanted = { track = true, time = true, zone = true }
	local missing = false
	for kind in pairs(wanted) do
		if not M.found[kind] then
			missing = true
		end
	end
	-- ONCE (Josh 2026-09-22): Keepers runs on every zoom step and every
	-- cluster layout, and a kind this build simply has not got made it walk
	-- the whole UI each time
	if missing and not M.swept and type(_G.EnumerateFrames) == "function" then
		M.swept = true
		local f, guard = nil, 0
		repeat
			local ok, nxt = pcall(_G.EnumerateFrames, f)
			if not ok then
				break
			end
			f = nxt
			guard = guard + 1
			if type(f) == "table" and not f.beebs and f ~= map then
				pool[#pool + 1] = { f = f, ours = false }
			end
		until not f or guard > 20000
	end
	-- and the ones this module has always known by name, for a build that
	-- parents them somewhere else entirely
	for _, k in ipairs(KEEP) do
		gather({ _G[k.name] }, true)
	end
	for _, name in ipairs(ZONE) do
		gather({ _G[name] }, true)
	end

	for _, entry in ipairs(pool) do
		local f = entry.f
		if type(f) == "table" and f ~= map and not seen[f] and not f.beebs then
			seen[f] = true
			local kind = whatIs(f, entry.ours)
			-- A NAMELESS FRAME IS NOT AUTOMATICALLY FURNITURE (Josh
			-- 2026-09-21). Hiding every unnamed frame under the minimap took
			-- the tracking eye, the zone caption and the mail flag with it -
			-- on this build those are anonymous, reached through a parentKey
			-- rather than a global. Art is swept as REGIONS, which is a
			-- question with a real answer; an unnamed FRAME is left alone and
			-- found by key below instead.
			kind = kind or entry.kind
			if kind and kind ~= "chrome" then
				-- remembered, so the walk above is not repeated once the
				-- three things we were looking for have been found
				M.found[kind] = f
			end
			if not kind then
				leftover[f] = true
			else
				placed[f] = true
			end
			if kind == "chrome" or kind == "clock" or kind == "zone" then
				-- the clock is not in layout D, and the zone caption is drawn
				-- by this module in the row above the map
				put(f, not plain)
				n = n + 1
			elseif kind and WHERE[kind] then
				local w = WHERE[kind]
				if plain then
					move(f)
				else
					move(f, map, w.spot, map, w.spot, w.x, w.y, w.size)
					-- placed afresh, so no shift yet
					f.beebsShift = nil
					M.Snap(f, map, w)
					if w.hover then
						M.hovering[f] = true
					end
				end
				n = n + 1
			end
		end
	end

	-- WHAT IS LEFT ON THE CLUSTER IS THE MINIMAP'S, WHATEVER IT IS CALLED
	-- (Josh 2026-09-21). Five goes at naming these got the tracking eye, the
	-- day/night dial and the coordinates wrong in five different ways. There
	-- is a question that does not need a name: the MAP has been taken out of
	-- MinimapCluster, so anything still hanging there is a piece of the
	-- minimap's furniture by definition.
	--
	-- What cannot be inferred is which is which, so they are not guessed at:
	-- they go in a row along the bottom of the map, in the order the client
	-- keeps them. Everything is visible and attached, and nothing is hidden
	-- for want of a name.
	-- WORDS ARE NOT ICONS (Josh 2026-09-21). Putting everything that was left
	-- into one row along the bottom of the map attached it all, which was the
	-- point, and looked like a jumble sale: the zone name and the coordinates
	-- squeezed into eighteen pixels beside a sun dial, on top of each other.
	--
	-- A frame that has words in it is a caption and goes in the caption row; a
	-- frame that does not is an icon and goes in the icon row. That is a
	-- question the frame can answer - does it draw a FontString with anything
	-- in it - and it does not need a name either.
	if not plain then
		-- A FRAME THAT DRAWS NOTHING BUT TEXT IS A CAPTION (Josh 2026-09-21).
		-- Narrowing this to "only if it looks like coordinates" sent the zone
		-- name down into the icon row, where it lay across the sun dial. The
		-- picture test above already keeps indicators out; what is left with
		-- words and no art is a line of text, and there are two of those: the
		-- place you are in and the spot you are standing on.
		-- A BUTTON IS ONE ICON, NOT ITS PIECES (Josh 2026-09-21). The walk
		-- goes three levels deep to FIND things, and every level came back as
		-- an icon of its own: the tracking button's inner button sat in the
		-- row while its holder sat in the corner, the difficulty banner's
		-- skulls took a slot each, and holders that draw nothing took slots
		-- of empty space, so the row wrapped with gaps in it.
		--
		-- So a piece travels with whatever it hangs off. It is an icon of its
		-- own only when nothing above it has been placed, hidden, or is an
		-- icon already - and only if it draws something itself. A holder that
		-- draws nothing is skipped, and what it holds is considered instead.
		local candidate = {}
		for _, entry in ipairs(pool) do
			local f = entry.f
			-- an addon's minimap button belongs to the Addon buttons line
			-- while that is on, not to the row along the bottom of the map
			local claimed = BT.MapButtons and BT.MapButtons.Claims(f)
			if entry.ours and leftover[f] and isFrame(f) and not claimed
				and f.IsShown and f:IsShown() then
				candidate[f] = true
			end
		end
		local function carried(f)
			local p = f.GetParent and f:GetParent()
			for _ = 1, 8 do
				if not p or p == frame or p == map or p == UIParent then
					return false
				end
				if placed[p] or p == hider or (candidate[p] and hasArt(p)) then
					return true
				end
				p = p.GetParent and p:GetParent()
			end
			return false
		end
		-- the walk can reach one frame by two routes; it gets one slot
		local icons, done = {}, {}
		for _, entry in ipairs(pool) do
			local f = entry.f
			if candidate[f] and not done[f] and not carried(f) then
				done[f] = true
				-- A LINE OF TEXT IS THE CLIENT'S CAPTION, AND OURS REPLACES IT
				-- (Josh 2026-09-21, layout D). The zone name and the
				-- coordinates are drawn in the row above the map by this
				-- module, so a client frame showing either is put away rather
				-- than moved: moving them is what put the zone name on the map.
				local said = anyText(f)
				local quiet = wordsOf(f)
				if isZone(said) or isCoords(said) or quiet or onlyBorder(f) then
					put(f, true)
				elseif hasArt(f) then
					icons[#icons + 1] = f
				end
			end
		end
		-- WHAT HAS NO CORNER OF ITS OWN runs along the bottom edge, between
		-- the two bottom corners, and wraps upward when it runs out of map.
		-- Queue and battleground indicators stay up, like the mail: they only
		-- appear when there is something to tell you. Anything else - another
		-- addon's button, mostly - fades with the corners.
		local wide = BT.Pill.Number(map.GetWidth and map:GetWidth(), 0)
		if wide <= 0 then
			wide = frame.wantWidth or FLOOR
		end
		-- THE CORNER, WHEN NOTHING HAS IT (Josh 2026-09-22). The row began a
		-- slot in, leaving the bottom-left corner to a world map button this
		-- build does not have - so the day/night dial, first in the row, sat
		-- a slot inside the map beside an empty corner.
		local wm = M.found.worldmap
		local cornerTaken = wm and wm.IsShown and wm:IsShown() and wm:GetParent() == map
		local first = cornerTaken and (3 + ICON + 2) or 3
		local room = wide - PAD * 2 - (ICON + 2) - (first - 3)
		local perRow = math.max(1, math.floor(room / (ICON + 2)))
		-- kept for /bt minimap, which says what each one draws
		M.rowIcons = icons
		for i, f in ipairs(icons) do
			local col = (i - 1) % perRow
			local rowN = math.floor((i - 1) / perRow)
			local slot = { spot = "BOTTOMLEFT", x = first + col * (ICON + 2),
				y = 3 + rowN * (ICON + 2), size = ICON }
			move(f, map, slot.spot, map, slot.spot, slot.x, slot.y, ICON)
			-- and by what it draws, like the corners: the dial's picture hangs
			-- off its button at an offset, so the button's slot is not where
			-- the sun is
			f.beebsShift = nil
			M.Snap(f, map, slot)
			local name = nameOf(f)
			if not (name:find("Queue") or name:find("LFG")
				or name:find("Battlefield") or name:find("PvP")) then
				M.hovering[f] = true
				if f.HookScript and not f.beebsLeaves then
					f.beebsLeaves = true
					pcall(f.HookScript, f, "OnLeave", function()
						if M.Leave then
							M.Leave()
						end
					end)
				end
			end
			n = n + 1
		end
	end

	-- the ring hung on the ones we keep is ring like any other
	for _, name in ipairs(KEEP_ART) do
		put(_G[name], not plain)
	end
	for f in pairs(before) do
		if not M.hovering[f] and f.SetAlpha then
			pcall(f.SetAlpha, f, 1)
		end
	end
	-- and whatever was placed this pass shows as the rest do
	if M.revealed ~= nil and not plain then
		M.Reveal(M.revealed)
	end
	return n
end

-- the tests need to watch it meet a map it has never seen
function M.Forget()
	was = {}
end

-- PUT BACK WHAT WE TOUCHED, NOT WHAT WE CAN STILL FIND (Josh 2026-09-21).
-- Switching the module off used to run the same sweep again and undo whatever
-- it turned up. That only ever restores the pieces the sweep still recognises
-- - and the sweep had just moved a dozen frames it could not name, so those
-- stayed where we put them and the minimap came back with holes in it.
--
-- Everything moved is remembered when it is moved. Undoing is walking that
-- list, not searching again.
function M.Restore()
	local n = 0
	for thing in pairs(moved) do
		move(thing)
		n = n + 1
	end
	for thing in pairs(hidden) do
		put(thing, false)
		n = n + 1
	end
	-- anything we faded for the hover goes back to full: it was never hidden,
	-- only made invisible, and that has to be undone by hand
	for thing in pairs(M.hovering or {}) do
		if thing.SetAlpha then
			pcall(thing.SetAlpha, thing, 1)
		end
		n = n + 1
	end
	return n
end

-- SHOWN WHEN YOU POINT AT IT (Josh 2026-09-21). Alpha rather than Hide: these
-- are the client's own buttons and it shows them again on its own schedule, so
-- hiding them is a race we lose - the same lesson the action bars taught. At
-- zero alpha they are invisible and still clickable, which is exactly what a
-- control that appears under the cursor should be.
function M.Reveal(on)
	-- ALWAYS, IF YOU LIKE (Josh 2026-09-24): the corners up whether or not the
	-- pointer is on the map
	if opt("controls", "hover") == "always" then
		on = true
	end
	local a = on and 1 or 0
	for f in pairs(M.hovering or {}) do
		if f.SetAlpha then
			pcall(f.SetAlpha, f, a)
		end
	end
	M.revealed = on and true or false
	return a
end

-- THE CURSOR MOVES ONTO A CHILD AND THE PARENT SAYS IT LEFT (Josh 2026-09-21).
-- Pointing at the map means pointing at one of the buttons a moment later, and
-- a plain OnLeave hides them the instant you reach for one. So leaving asks
-- again, a frame later, whether the cursor is anywhere over the panel at all.
function M.WatchHover(frame, map)
	local function over()
		for _, f in ipairs({ frame, map }) do
			if f and f.IsMouseOver and select(2, pcall(f.IsMouseOver, f)) then
				return true
			end
		end
		for f in pairs(M.hovering or {}) do
			if f.IsMouseOver and select(2, pcall(f.IsMouseOver, f)) then
				return true
			end
		end
		return false
	end
	M.MouseIsOver = over

	local function leave()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if BT.Enabled("minimap") and not over() then
					M.Reveal(false)
				end
			end)
		elseif not over() then
			M.Reveal(false)
		end
	end
	-- the corner icons say so too (see M.Keepers): leaving straight off one
	-- of them, past the panel's edge, was heard by nothing
	M.Leave = leave

	for _, f in ipairs({ frame, map }) do
		if f and f.HookScript and not f.beebsHover then
			f.beebsHover = true
			if f.EnableMouse and f ~= map then
				pcall(f.EnableMouse, f, true)
			end
			f:HookScript("OnEnter", function()
				if BT.Enabled("minimap") then
					M.Reveal(true)
				end
			end)
			f:HookScript("OnLeave", leave)
		end
	end
	return true
end

function M.Apply(plain)
	local map = _G.Minimap
	if not (map and map.SetParent) then
		return false
	end
	remember(map)

	if plain then
		if M.ticker then
			M.ticker:Cancel()
			M.ticker = nil
		end
		M.Chrome(false)
		M.Restore()
		pcall(map.SetParent, map, was.parent or UIParent)
		if was.at then
			pcall(map.ClearAllPoints, map)
			if was.at[2] then
				pcall(map.SetPoint, map, was.at[1], was.at[2], was.at[3], was.at[4], was.at[5])
			else
				pcall(map.SetPoint, map, was.at[1], was.at[4], was.at[5])
			end
		end
		-- ONLY IF IT IS A SIZE (Josh 2026-09-21). A frame the client has not
		-- laid out yet measures zero, and putting zero back is how something
		-- comes out of this invisible rather than where it started.
		if was.w and was.h and was.w > 0 and was.h > 0 then
			pcall(map.SetSize, map, was.w, was.h)
		end
		if map.SetMaskTexture and was.mask then
			pcall(map.SetMaskTexture, map, was.mask)
		end
		if map.SetAlpha then
			pcall(map.SetAlpha, map, was.alpha or 1)
		end
		if map.SetIgnoreParentAlpha then
			pcall(map.SetIgnoreParentAlpha, map, was.ignoresParent or false)
		end
		if M.skin then
			BT.Pill.ShowSurface(M.skin, false)
		end
		if M.frame then
			M.frame:Hide()
			BT.Bar.Relayout()
		end
		return true
	end

	local frame = M.Build()
	frame:Show()

	pcall(map.SetParent, map, frame)
	pcall(map.ClearAllPoints, map)
	pcall(map.SetPoint, map, "TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + ZONE_H))
	M.Fit()
	-- a white mask is no mask at all, which is what makes it square
	if map.SetMaskTexture then
		pcall(map.SetMaskTexture, map, "Interface\\Buttons\\WHITE8X8")
	end

	-- SOLID, AND NOW WE KNOW WHY (Josh 2026-09-22). The map's alpha was tried
	-- again as a setting, with a hole cut in the panel's fill under it: at any
	-- value below 1 the client stops drawing the terrain and only the blips
	-- fade. That was the black ground all along. See M.Opacity.
	--
	-- On the panel's own layer, not the one the client gave it: a map left a
	-- layer below the panel is drawn under the panel's fill.
	if map.SetAlpha then
		pcall(map.SetAlpha, map, M.Opacity())
	end
	-- NOT THE DOCK'S FADE EITHER (Josh 2026-09-27: a minimap all black, the
	-- cause not seen). The client reads the alpha a frame is drawn at - its
	-- own times every parent's - so the dock faded in a fight took the
	-- terrain with it just as the setting had. The map keeps its own alpha,
	-- solid, whatever the dock is at.
	if map.SetIgnoreParentAlpha then
		pcall(map.SetIgnoreParentAlpha, map, true)
	end
	if type(frame.GetFrameStrata) == "function" and map.SetFrameStrata then
		local ok, strata = pcall(frame.GetFrameStrata, frame)
		if ok and strata then
			pcall(map.SetFrameStrata, map, strata)
		end
	end
	if map.SetFrameLevel and frame.GetFrameLevel then
		pcall(map.SetFrameLevel, map, (frame:GetFrameLevel() or 1) + 2)
	end

	M.Chrome(true)
	M.Keepers(frame, map, false)
	M.WatchHover(frame, map)
	M.Caption()
	-- the coordinates change as you walk, so they are read a few times a
	-- second while the map is in the panel
	if not M.ticker and C_Timer and C_Timer.NewTicker then
		M.ticker = C_Timer.NewTicker(0.25, function()
			if BT.Enabled("minimap") then
				M.Caption()
			end
		end)
	end
	-- at rest unless the cursor is already on it
	M.Reveal(M.MouseIsOver and M.MouseIsOver() or false)
	-- NO SECOND BACKGROUND (Josh 2026-09-22). The section painted the panel's
	-- fill again on top of the dock's own, so under a faded map there were two
	-- layers of 88% dark between you and the world - a black box. The dock's
	-- background is enough, and its dividers are the dock's to draw now.
	BT.Pill.ShowSurface(M.skin, false)
	-- laid out, then squared to the width that came back, then laid out again
	-- with the height that produced
	BT.Bar.Relayout()
	if M.Fit() then
		BT.Bar.Relayout()
	end
	-- MEASURED ONCE IT HAS BEEN LAID OUT (Josh 2026-09-21). The corners are
	-- placed before the dock has stacked and sized the panel, and a map with
	-- no position yet measures nothing, so the sun never moved. Measured again
	-- now, and again a frame later for anything the client lays out lazily.
	M.SnapAll()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if BT.Enabled("minimap") then
				M.SnapAll()
			end
		end)
	end
	return true
end

-- ITS OWN ECHO IS NOT NEWS (Josh 2026-09-23, /bt cpu: MINIMAP_UPDATE_ZOOM 56
-- times a second, a third of a second of work every second, and the client's
-- zoom settings written with it - four CVAR_UPDATEs a time, which set the
-- resource display and the status bars going as well). Laying the map out
-- sizes it and sets its mask, and on this client that makes the map say its
-- zoom changed; that event laid it out again, and so on without end. A zoom
-- is still followed (the wheel resets pieces the layout owns), but not one
-- arriving while the layout runs or in the quarter second after it: that one
-- is the layout's own.
local applyNow = M.Apply
function M.Apply(plain)
	M.applying = true
	local ok, r = pcall(applyNow, plain)
	M.applying = false
	M.quietUntil = ((type(GetTime) == "function" and GetTime()) or 0) + 0.25
	if not ok then
		error(r, 0)
	end
	return r
end

-- whether a zoom event is the layout's own echo
function M.Echo()
	if M.applying then
		return true
	end
	local now = (type(GetTime) == "function" and GetTime()) or 0
	return now < (M.quietUntil or 0)
end

function M.SnapAll()
	local map = _G.Minimap
	if not map then
		return 0
	end
	local n = 0
	for f, w in pairs(M.corners or {}) do
		if f.GetParent and f:GetParent() == map then
			if M.Snap(f, map, w) then
				n = n + 1
			end
		end
	end
	return n
end

-- SQUARE TO WHATEVER WIDTH THE DOCK GIVES IT. Returns true when the height it
-- wants has changed, which is the only case the dock has to hear about again.
local fitting = false
function M.Fit()
	local frame, map = M.frame, _G.Minimap
	if fitting or not (frame and map and map.SetSize) then
		return false
	end
	fitting = true
	local w = BT.Pill.Number(frame.GetWidth and frame:GetWidth(), 0)
	if w <= 0 then
		w = frame.wantWidth or FLOOR
	end
	local size = math.max(60, w - PAD * 2)
	local before = BT.Pill.Number(map.GetWidth and map:GetWidth(), 0)
	pcall(map.SetSize, map, size, size)
	-- where the map is in this section, for the dock to leave clear under it
	-- while it is see-through; a solid map needs no hole
	if M.Opacity() < 1 then
		frame.hole = { x = PAD, y = PAD + ZONE_H, w = size, h = size }
	else
		frame.hole = nil
	end
	-- A RESIZED MAP KEEPS THE PICTURE IT HAD (Josh 2026-09-21). The client
	-- draws the ground again when the zoom changes, not when the size does,
	-- so a step in and back out makes it draw at the new size.
	if before ~= size and type(map.GetZoom) == "function"
		and type(map.SetZoom) == "function" then
		local ok, z = pcall(map.GetZoom, map)
		if ok and type(z) == "number" then
			pcall(map.SetZoom, map, z > 0 and z - 1 or z + 1)
			pcall(map.SetZoom, map, z)
			-- our own step, not the wheel: its zoom events are an echo too
			-- when the dock resized the map outside M.Apply
			local now = (type(GetTime) == "function" and GetTime()) or 0
			M.quietUntil = math.max(M.quietUntil or 0, now + 0.25)
		end
	end
	local tall = size + ZONE_H + PAD * 2
	local changed = frame.wantHeight ~= tall
	frame.wantHeight = tall
	frame:SetHeight(tall)
	fitting = false
	return changed
end

function M.StyleAll(plain)
	return M.Apply(plain)
end

-- THE CLIENT PUTS IT BACK (Josh 2026-09-21). Zoning, the Edit Mode closing and
-- a scale change all re-anchor the minimap and re-show the ring, so this goes
-- on again after those rather than once at login.
function M.Watch()
	-- THE CLUSTER LAYS ITSELF OUT AGAIN (Josh 2026-09-21). MinimapCluster is
	-- a layout frame: it re-anchors what it holds whenever it is shown, sized
	-- or told to. Moving its pieces once at login is the same losing race the
	-- health bar and the chat window both taught - the client sets them back
	-- and ours was the only pass that ever ran. This goes on again after it.
	if not M.laidOut and _G.MinimapCluster and hooksecurefunc then
		local cluster = _G.MinimapCluster
		for _, fn in ipairs({ "Layout", "SetHeaderUnderneath", "UpdateRotateMinimapButton" }) do
			if type(cluster[fn]) == "function" then
				M.laidOut = true
				pcall(hooksecurefunc, cluster, fn, function()
					if BT.Enabled("minimap") and not M.placing and M.frame then
						M.placing = true
						pcall(M.Keepers, M.frame, _G.Minimap, false)
						M.placing = false
					end
				end)
			end
		end
	end
	if not M.events then
		M.events = CreateFrame("Frame")
		for _, event in ipairs({
			"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
			"MINIMAP_UPDATE_ZOOM", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
			-- walking into a new district changes the caption and nothing else
			"ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
		}) do
			pcall(M.events.RegisterEvent, M.events, event)
		end
		M.events:SetScript("OnEvent", function(_, event)
			if not BT.Enabled("minimap") then
				return
			end
			if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
				M.Caption()
			elseif event == "MINIMAP_UPDATE_ZOOM" and M.Echo() then
				return
			else
				M.Apply()
			end
		end)
	end
	return M.events
end

function M:OnEnable()
	M.Watch()
	M.Apply()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.Apply(true)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the client's own map, moved into the panel · the wheel still zooms and a right-click still opens tracking")
	page:Note("square, because a circle in a stack of rectangles leaves four corners of world showing", true)
	-- WHAT IT SAYS AND WHEN (Josh 2026-09-24)
	local show = page:Section("Show")
	BT.Widgets.SwitchRow(show, "Zone name", "over the map, in the colour of the ground you stand on",
		function() return opt("zoneName", true) and true or false end,
		function(on) setOpt("zoneName", on) end)
	BT.Widgets.SwitchRow(show, "Coordinates", "where you are standing, beside the zone",
		function() return opt("coords", true) and true or false end,
		function(on) setOpt("coords", on) end)
	local corners = BT.Widgets.Row(show, "Corner buttons", "tracking, the day and night, the world map")
	self.controlsSeg = corners:SetControl(BT.Widgets.Segmented(corners, {
		{ "hover", "On hover" }, { "always", "Always" },
	}, function(key)
		setOpt("controls", key)
		M.Reveal(M.MouseIsOver and M.MouseIsOver() or false)
	end, 70))
	page:Layout()
end

function M:RefreshTab()
	if self.controlsSeg then
		self.controlsSeg:Select(opt("controls", "hover"))
	end
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- WHAT IT FOUND AND WHERE IT WENT (Josh 2026-09-21). Four rounds of this
-- module were spent guessing which frame was which and whether a move had
-- taken. Measuring beats guessing: this says what was found, under what name,
-- and whether it is actually sitting in the panel now.
BT.Command("minimap", function()
	M.Apply()
	local frame = M.frame
	U.Print(("minimap: panel %s, map %s"):format(
		frame and frame:IsShown() and "up" or "down",
		(_G.Minimap and _G.Minimap.GetParent and _G.Minimap:GetParent() == frame)
			and "in it" or "NOT in it"))
	local any = false
	for kind, f in pairs(M.found or {}) do
		any = true
		local where = "?"
		if f.GetParent then
			local p = f:GetParent()
			if p == frame or p == _G.Minimap then
				where = "in the panel"
			else
				local pn = (p and p.GetName and p:GetName()) or "somewhere else"
				where = "still on " .. tostring(pn)
			end
		end
		local m = moved[f]
		U.Print(("  %s: %s - %s%s"):format(kind,
			(f.GetName and f:GetName()) or "(no name)", where,
			(m and m.took == false) and " (the client refused the move)" or ""))
		if f.beebsSnap then
			U.Print("    corner: " .. f.beebsSnap)
		end
	end
	if not any then
		U.Print("  nothing found: the client keeps these somewhere new again")
	end
	-- THE ROW ALONG THE BOTTOM, PIECE BY PIECE (Josh 2026-09-22). The
	-- day/night dial is in it and has been placed wrong twice, so this says
	-- what each icon actually draws - every texture, its size and where it
	-- sits against the map - rather than leaving the next fix to a guess.
	local map = _G.Minimap
	local ml, mb = map and map.GetLeft and map:GetLeft(), map and map.GetBottom and map:GetBottom()
	for i, f in ipairs(M.rowIcons or {}) do
		local name = (f.GetName and f:GetName()) or "(no name)"
		local fl, fb = f.GetLeft and f:GetLeft(), f.GetBottom and f:GetBottom()
		U.Print(("  row %d: %s, frame at %s,%s size %sx%s%s"):format(i, name,
			fl and ml and ("%.0f"):format(fl - ml) or "?", fb and mb and ("%.0f"):format(fb - mb) or "?",
			("%.0f"):format(BT.Pill.Number(f.GetWidth and f:GetWidth(), 0)),
			("%.0f"):format(BT.Pill.Number(f.GetHeight and f:GetHeight(), 0)),
			f.beebsSnap and (" · " .. f.beebsSnap) or ""))
		local function regions(frame, depth)
			local ok, list = pcall(function() return { frame:GetRegions() } end)
			for _, r in ipairs(ok and list or {}) do
				local okKind, kind = pcall(r.GetObjectType, r)
				if okKind and kind == "Texture" then
					local what = (r.GetAtlas and r:GetAtlas()) or (r.GetTexture and tostring(r:GetTexture())) or "?"
					local rl, rb = r.GetLeft and r:GetLeft(), r.GetBottom and r:GetBottom()
					U.Print(("    %s%s: %s at %s,%s size %.0fx%.0f alpha %.2f%s"):format(
						string.rep("  ", depth), (function()
							local okN, dn = pcall(r.GetDebugName, r)
							return (okN and type(dn) == "string" and dn:match("[^%.]+$")) or "tex"
						end)(),
						tostring(what), rl and ml and ("%.0f"):format(rl - ml) or "?",
						rb and mb and ("%.0f"):format(rb - mb) or "?",
						BT.Pill.Number(r.GetWidth and r:GetWidth(), 0), BT.Pill.Number(r.GetHeight and r:GetHeight(), 0),
						BT.Pill.Number(r.GetAlpha and r:GetAlpha(), 1), (r.IsShown and not r:IsShown()) and " (hidden)" or ""))
				end
			end
			if depth < 1 and frame.GetChildren then
				local okK, kids = pcall(function() return { frame:GetChildren() } end)
				for _, kid in ipairs(okK and kids or {}) do
					regions(kid, depth + 1)
				end
			end
		end
		regions(f, 0)
	end
end, "put the minimap back in the panel, and say what it found", "minimap")

-- STOP GUESSING WHAT THEY ARE CALLED (Josh 2026-09-21). Four rounds of this
-- module were spent naming frames that turned out to be called something else
-- on this build. This prints what is ACTUALLY hanging off the minimap - every
-- child and every key that holds a frame - so the next change is made against
-- what is there rather than against what usually is.
BT.Command("minimapdump", function()
	local function say(label, f, key)
		local name = (type(f) == "table" and type(f.GetName) == "function")
			and select(2, pcall(f.GetName, f)) or nil
		local kind = (type(f) == "table" and type(f.GetObjectType) == "function")
			and select(2, pcall(f.GetObjectType, f)) or "?"
		local shown = (type(f) == "table" and f.IsShown and f:IsShown()) and "shown" or "hidden"
		U.Print(("  %s %s = %s <%s, %s>"):format(label, tostring(key),
			tostring(name or "(no name)"), tostring(kind), shown))
	end

	for _, owner in ipairs({ "MinimapCluster", "Minimap", "MinimapBackdrop" }) do
		local o = _G[owner]
		if type(o) == "table" then
			U.Print(owner .. ":")
			if o.GetChildren then
				local ok, list = pcall(function()
					return { o:GetChildren() }
				end)
				for i, f in ipairs(ok and list or {}) do
					say("child", f, i)
				end
			end
			-- the keys the client hangs things on, which is how anonymous
			-- frames are reached at all
			for k, v in pairs(o) do
				if type(v) == "table" and type(k) == "string"
					and type(v.GetObjectType) == "function" then
					say("key", v, k)
				end
			end
		else
			U.Print(owner .. ": not here")
		end
	end
end, "list what is hanging off the minimap", "minimap")
