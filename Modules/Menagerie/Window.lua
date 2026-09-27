-- The Menagerie, in a window of its own (Josh 2026-09-25).
--
-- Opened from its line in the dock (or /bt menagerie), in the same surface as
-- the Census. Two views, and whose kills they count:
--
--   Compendium     a card for every kind of mob killed, with its portrait,
--                  filed by creature type; a click opens its popup, the whole
--                  model on a turntable. Every model is drawn by NPC id alone,
--                  which this client does from its creature cache even for a
--                  mob met sessions ago (MobProbe, 70009). Its key is still
--                  "bestiary", the name it had first: the settings keep it
--   Achievements   what the kinds themselves are worth, the masteries, and
--                  every milestone, earned or the distance to it
--
--   This character / All characters   the counts, and so the points, of the
--                  character you are on, or of every one added together
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Window.lua")

local U = BT.Util
local V = {}
BT.MenagerieWindow = V

local PAD, TITLE_H = 14, 40
local WIDTH, HEIGHT = 1180, 746
local CONTROLS_Y = TITLE_H + 10
local BODY_Y = TITLE_H + 40

local ACH_H, HEAD_ROW_H = 40, 24

local DIM = { 0.50, 0.55, 0.53 }
local WORDS = "|cff8a9894%s|r"
-- the rank's mark, the tooltip's colours: a gold elite, a silver rare
local RANK = {
	elite = { 1, 0.82, 0.30 },
	rare = { 0.78, 0.84, 0.90 },
	rareelite = { 0.85, 0.92, 1 },
	worldboss = { 1, 0.42, 0.32 },
}
local RANK_WORD = { elite = "Elite", rare = "Rare", rareelite = "Rare Elite", worldboss = "World Boss" }

local frame

-- what the window was left on, kept with the settings
local function ui()
	local s = BT.settings
	if not s then
		return { view = "bestiary", scope = "char", folded = {}, group = "type", sort = "name" }
	end
	s.menagerieUI = s.menagerieUI or {}
	local u = s.menagerieUI
	u.view = u.view or "bestiary"
	u.scope = u.scope or "char"
	u.folded = u.folded or {}
	-- the compendium's sections (type or zone) and their order (name or mastery)
	u.group = u.group or "type"
	u.sort = u.sort or "name"
	-- cards, or the list
	u.layout = u.layout or "cards"
	return u
end

-- 12,345
local function big(n)
	n = math.floor(n or 0)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, s = pcall(BreakUpLargeNumbers, n)
		if ok and type(s) == "string" then
			return s
		end
	end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
V.Big = big

local function level(m)
	if m.skull then
		return "Level ??"
	elseif m.lo and m.hi and m.lo ~= m.hi then
		return ("Level %d-%d"):format(m.lo, m.hi)
	elseif m.lo then
		return ("Level %d"):format(m.lo)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------

function V.Build()
	if frame then
		return frame
	end
	local W = BT.Widgets
	frame = CreateFrame("Frame", "BeebModMenagerie", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 40, -20)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	W.PixelDrag(frame)
	frame:SetClampedToScreen(true)
	W.Panel(frame, W.SOLID)
	tinsert(UISpecialFrames, "BeebModMenagerie") -- escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD + 4, -PAD)
	frame.title:SetText("Menagerie")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

	frame.close = W.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() V.Hide() end)
	W.Divider(frame, PAD, -TITLE_H)

	frame.views = W.Segmented(frame, { { "bestiary", "Compendium" }, { "achievements", "Achievements" } },
		function(key)
			ui().view = key
			V.Refresh()
		end, 100)
	frame.views:SetPoint("TOPLEFT", PAD, -CONTROLS_Y)
	frame.scopes = W.Segmented(frame, { { "char", "This character" }, { "account", "All characters" } },
		function(key)
			ui().scope = key
			V.Refresh()
		end, 110)
	frame.scopes:SetPoint("TOPRIGHT", -PAD, -CONTROLS_Y)

	V.BuildBestiary()
	V.BuildAchievements()
	frame:Hide()
	return frame
end

-- ---------------------------------------------------------------------------
-- Compendium: a card for every kind, and each one's own page
-- ---------------------------------------------------------------------------
--
-- CARDS (Josh 2026-09-25: "portrait icons for each of the mobs ... just show
-- cards in the main window, with maybe a button to view model"). A portrait
-- texture needs the unit in front of the client (SetPortraitTexture) and
-- cannot be kept, so each card's portrait is a model of its own, framed on
-- the face the way the client's own unit frames frame one (SetPortraitZoom).
-- A click opens the mob's page: the whole model on a turntable, and what we
-- know about it.
--
-- ONLY THE CARDS IN VIEW EXIST: the grid is arithmetic, and scrolling hands
-- the same few cards new mobs - a book of five hundred kinds costs what one
-- screenful does. Whole rows only: whether this client clips a model to the
-- frame it scrolls in is not known, so a row half out of view is not drawn
-- rather than drawn over the window's edge, and the wheel moves a row at a
-- time.

-- A RAIL, NOT HEADINGS (Josh 2026-09-26: "a rail on the left rather than sub
-- headings and accordions. We will have a ton of zones"). The types or zones
-- are a list down the left, "All" first, each with its count and points; the
-- grid shows the one picked. The rail scrolls on its own, so a hundred zones
-- are a hundred short rows, not a hundred headings between cards.
--
-- NEAR THE MOCKUP'S SIZE (Josh 2026-09-26: "cards are too small - the text is
-- very hard to read"). Five across at 140 put the words at eight points. The
-- window grew instead ("we can also make the main window larger"): WIDER, not
-- taller - the game's screen is 768 units high at a scale of one, and the
-- window is near that already - so five across are 179 wide, near the
-- mockup's 184, and two rows of them are in view.
local COLS, GAP = 5, 8
local RAIL_W, RAIL_ROW_H = 180, 34
local Card = BT.MenagerieCard
-- the Group and Sort bar over the cards
local TOOLBAR_Y, TOOLBAR_H = 8, 36
-- the grid's width: the window's, less the body's margins, the box's insets,
-- the rail and its gap, and the scroll gutter
local GRID_W = WIDTH - PAD * 2 - 16 - RAIL_W - 10 - 6
-- how much a card grows under the cursor
local ZOOM = 1.1
-- the list: three across, a slim row each - thirty in view where the cards
-- show ten
local LIST_COLS, LIST_H, LIST_GAP = 3, 46, 6
-- a margin inside the grid's edges: room for a card in the top row to be
-- lifted without the grid's edge clipping it (Josh 2026-09-26: "the hover
-- zoom seems to cut off the top of the cards")
local EDGE = 6
V.ALL = "__all"

function V.BuildBestiary()
	local W = BT.Widgets
	local b = CreateFrame("Frame", nil, frame)
	b:SetPoint("TOPLEFT", PAD, -BODY_Y)
	b:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	frame.bestiary = b

	local box = CreateFrame("Frame", nil, b)
	box:SetAllPoints()
	W.Panel(box, W.RAISED, W.HAIR)
	b.box = box

	-- how the cards are filed, and in what order (Josh 2026-09-25)
	local groupLabel = W.Label(box, "Group", "small", DIM[1], DIM[2], DIM[3])
	groupLabel:SetPoint("TOPLEFT", 10, -TOOLBAR_Y - 4)
	b.groups = W.Segmented(box, { { "type", "Type" }, { "zone", "Zone" } }, function(key)
		ui().group = key
		b.grid:ScrollTo(0)
		b.rail:ScrollTo(0)
		V.Refresh()
	end, 60)
	b.groups:SetPoint("LEFT", groupLabel, "RIGHT", 8, 0)
	local sortLabel = W.Label(box, "Sort", "small", DIM[1], DIM[2], DIM[3])
	sortLabel:SetPoint("LEFT", b.groups, "RIGHT", 18, 0)
	b.sorts = W.Segmented(box, { { "name", "A to Z" }, { "mastery", "Mastery" } }, function(key)
		ui().sort = key
		V.Refresh()
	end, 70)
	b.sorts:SetPoint("LEFT", sortLabel, "RIGHT", 8, 0)
	-- CARDS OR A LIST (Josh 2026-09-26: "a 'View' next to 'Sort'... Cards and
	-- List. List should be a list/grid so we can fit more on the screen")
	local viewLabel = W.Label(box, "View", "small", DIM[1], DIM[2], DIM[3])
	viewLabel:SetPoint("LEFT", b.sorts, "RIGHT", 18, 0)
	b.layouts = W.Segmented(box, { { "cards", "Cards" }, { "list", "List" } }, function(key)
		ui().layout = key
		b.grid:ScrollTo(0)
		V.Refresh()
	end, 60)
	b.layouts:SetPoint("LEFT", viewLabel, "RIGHT", 8, 0)
	W.Divider(box, 8, -TOOLBAR_H)

	-- the rail
	local railBox = CreateFrame("Frame", nil, box)
	railBox:SetPoint("TOPLEFT", 8, -TOOLBAR_H - 8)
	railBox:SetPoint("BOTTOMLEFT", 8, 8)
	railBox:SetWidth(RAIL_W)
	W.Panel(railBox, W.FILL, W.HAIR)
	b.rail = W.Scroller(railBox, 4)
	b.rail:SetPoint("TOPLEFT", 3, -3)
	b.rail:SetPoint("BOTTOMRIGHT", -3, 3)
	b.rail.step = RAIL_ROW_H * 3
	b.railRows = {}

	-- the grid
	b.grid = W.Scroller(box, 6)
	b.grid:SetPoint("TOPLEFT", railBox, "TOPRIGHT", 10, 0)
	b.grid:SetPoint("BOTTOMRIGHT", -8, 8)
	b.grid.step = Card.Height(math.floor((GRID_W - GAP * (COLS - 1)) / COLS)) + GAP
	-- every move of the strip deals the cards again
	local scrollTo = b.grid.ScrollTo
	b.grid.ScrollTo = function(self, y)
		local at = scrollTo(self, y)
		V.Deal()
		return at
	end
	b.cards = {}
	b.empty = W.Label(box, "Nothing in the Menagerie yet.\nEvery kind of mob you kill is written in here.",
		"small", DIM[1], DIM[2], DIM[3])
	b.empty:SetPoint("CENTER", b.grid, "CENTER")
	V.BuildPage(b)
end

-- ---------------------------------------------------------------------------
-- A MOB'S PAGE, IN A POPUP (Josh 2026-09-26: "Instead of a separate details
-- page, what do you think about having a modal popup? It would be smaller than
-- the parent window, and dim the background", and of the mockups, "I like
-- option B ... make sure the lore is scrollable"). The window dims under it
-- and the grid stays where it was; a click outside it closes it, Escape closes
-- it (the popup first, the window after), and the arrows - or the arrow keys
-- - step through the mobs the grid is showing. Top to bottom: the name and
-- what it is, the whole model in a plain box, three numbers, the
-- mastery ladder at this mob's rank, and the lore, every page of it, in a box
-- of its own that scrolls.
-- ---------------------------------------------------------------------------
local MODAL_W, MODAL_H, MODAL_PAD = 480, 700, 16
local STAGE_Y, STAGE_H = 62, 220
local TILE_H, LADDER_H, FOOT_H = 50, 76, 34
-- the popup's own ground
local MODAL_BG = { 0.05, 0.07, 0.06 }

local function tile(parent, word)
	local W = BT.Widgets
	local t = CreateFrame("Frame", nil, parent)
	W.Panel(t, W.FILL, W.HAIR)
	t.label = W.Label(t, word, "small", DIM[1], DIM[2], DIM[3])
	t.label:SetPoint("TOP", 0, -8)
	t.value = t:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	t.value:SetPoint("TOP", t.label, "BOTTOM", 0, -4)
	return t
end

-- THE LORE, SET OUT (Josh 2026-09-26: "The Warcraft Wiki credit can be
-- placed once, at the very end. We should have sub headings for the
-- additional subtype lores, and we should have an ornate divider between
-- sections"). The mob's best page first, bare; then each page it borrows
-- from - its race, its family, its type - and any quest under a heading of
-- its own, an ornament between each: a gem between two dots, and a line
-- either side of them that fades out toward the edges.
local ORNAMENT = { 0.72, 0.60, 0.36 }

local function ornament(parent)
	local d = CreateFrame("Frame", nil, parent)
	d:SetHeight(14)
	d.gem = d:CreateTexture(nil, "OVERLAY")
	d.gem:SetTexture(Card.TEX.gem)
	d.gem:SetSize(8, 14)
	d.gem:SetPoint("CENTER")
	d.gem:SetVertexColor(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3], 1)
	d.lines = {}
	for i, side in ipairs({ -1, 1 }) do
		local dot = d:CreateTexture(nil, "ARTWORK")
		dot:SetSize(3, 3)
		dot:SetPoint("CENTER", d, "CENTER", side * 13, 0)
		dot:SetColorTexture(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3], 0.9)
		local line = d:CreateTexture(nil, "ARTWORK")
		line:SetHeight(1)
		if side < 0 then
			line:SetPoint("LEFT", d, "LEFT", 24, 0)
			line:SetPoint("RIGHT", d, "CENTER", -20, 0)
		else
			line:SetPoint("LEFT", d, "CENTER", 20, 0)
			line:SetPoint("RIGHT", d, "RIGHT", -24, 0)
		end
		-- solid by the gem, nothing at the far end
		line:SetColorTexture(1, 1, 1, 1)
		local solid = CreateColor and CreateColor(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3], 0.8)
		local clear = CreateColor and CreateColor(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3], 0)
		local faded = CreateColor ~= nil and pcall(line.SetGradient, line, "HORIZONTAL",
			side < 0 and clear or solid, side < 0 and solid or clear)
		if not faded then
			line:SetColorTexture(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3], 0.5)
		end
		d.lines[i] = line
	end
	return d
end

-- the i-th section's pieces: an ornament over it, a heading, and its words
function V.LorePiece(page, i)
	local p = page.lorePieces[i]
	if p then
		return p
	end
	local body = page.loreBody
	p = { rule = ornament(body) }
	p.head = body:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(p.head.SetFont, p.head, Card.FONT_NAME, 12, "")
	p.head:SetJustifyH("LEFT")
	p.head:SetTextColor(ORNAMENT[1], ORNAMENT[2], ORNAMENT[3])
	p.text = body:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(p.text.SetFont, p.text, Card.FONT_LORE, 15, "")
	p.text:SetJustifyH("LEFT")
	p.text:SetJustifyV("TOP")
	p.text:SetWordWrap(true)
	p.text:SetTextColor(0.80, 0.73, 0.60)
	page.lorePieces[i] = p
	return p
end

function V.BuildPage(b)
	local W = BT.Widgets
	local inner = MODAL_W - 2 * MODAL_PAD
	-- the dimming, over the whole window: a click on it is a click outside
	local dim = CreateFrame("Frame", nil, frame)
	dim:SetAllPoints(frame)
	dim:SetFrameStrata("FULLSCREEN")
	dim:EnableMouse(true)
	dim.shade = dim:CreateTexture(nil, "BACKGROUND")
	dim.shade:SetAllPoints()
	dim.shade:SetColorTexture(0, 0, 0, 0.62)
	dim:SetScript("OnMouseDown", function() V.Close() end)
	dim:Hide()
	b.dim = dim

	local page = CreateFrame("Frame", nil, dim)
	page:SetSize(MODAL_W, MODAL_H)
	page:SetPoint("CENTER", dim, "CENTER", 0, 0)
	page:EnableMouse(true)
	W.Panel(page, { MODAL_BG[1], MODAL_BG[2], MODAL_BG[3], 1 }, W.RIM)
	b.page = page
	-- ESCAPE CLOSES THE POPUP, NOT THE WINDOW, and the arrow keys step; every
	-- other key goes on to the game. Where the client will not let a frame
	-- change which keys it keeps (in combat), Escape closes both, as before.
	pcall(page.EnableKeyboard, page, true)
	pcall(page.SetPropagateKeyboardInput, page, true)
	page:SetScript("OnKeyDown", function(self, key)
		local ours = key == "ESCAPE" or key == "LEFT" or key == "RIGHT"
		pcall(self.SetPropagateKeyboardInput, self, not ours)
		if key == "ESCAPE" then
			V.Close()
		elseif ours then
			V.Step(key == "LEFT" and -1 or 1)
		end
	end)

	-- the way to the mob before and after, outside the popup's sides
	page.prev = W.Button(dim, "<", 34, 60)
	page.prev:SetPoint("RIGHT", page, "LEFT", -12, 0)
	page.prev:SetScript("OnClick", function() V.Step(-1) end)
	page.next = W.Button(dim, ">", 34, 60)
	page.next:SetPoint("LEFT", page, "RIGHT", 12, 0)
	page.next:SetScript("OnClick", function() V.Step(1) end)

	page.close = W.Close(page, 20)
	page.close:SetPoint("TOPRIGHT", -10, -10)
	page.close:SetScript("OnClick", function() V.Close() end)
	page.name = page:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	page.name:SetPoint("TOPLEFT", MODAL_PAD, -MODAL_PAD)
	page.name:SetPoint("RIGHT", page.close, "LEFT", -8, 0)
	page.name:SetJustifyH("LEFT")
	page.meta = W.Label(page, "", "small", DIM[1], DIM[2], DIM[3])
	page.meta:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -5)
	page.meta:SetPoint("RIGHT", page, "RIGHT", -MODAL_PAD, 0)
	page.meta:SetJustifyH("LEFT")

	-- the stage: the model in a plain box, as the tiles under it are (Josh
	-- 2026-09-26: "The model border doesn't really work here... let's just
	-- use a regular rectangle box"). The card's arch cut the whole model's
	-- head and shoulders away; the rank is in the name's colour
	local stage = CreateFrame("Frame", nil, page)
	stage:SetSize(inner, STAGE_H)
	stage:SetPoint("TOPLEFT", MODAL_PAD, -STAGE_Y)
	W.Panel(stage, { 0.02, 0.03, 0.03, 1 }, W.HAIR)
	page.stage = stage
	local model = CreateFrame("PlayerModel", nil, stage)
	model:SetPoint("TOPLEFT", 1, -1)
	model:SetPoint("BOTTOMRIGHT", -1, 1)

	-- YOURS TO FRAME (Josh 2026-09-26: "Camera still seems centered on the
	-- hips. Maybe it would be easier if we let the user pan/zoom here as
	-- well?"). The client frames a creature on its origin, which is its hips,
	-- and placing it by the middle of its bounds instead changed nothing on
	-- 70009 - so the view is handed over: drag to turn it, right-drag to move
	-- it about the frame, the wheel to come closer or stand back, and Reset
	-- view for the client's own framing. Each mob opens on that framing.
	local ZOOM_MIN, ZOOM_MAX = 0.3, 3
	-- model units a pixel of dragging moves it, at the client's own distance
	local PAN = 0.01
	V.Stand = function(m)
		pcall(m.SetFacing, m, m.facing or 0)
		pcall(m.SetPosition, m, 0, m.panY or 0, m.panZ or 0)
		pcall(m.SetCamDistanceScale, m, m.zoom or 1)
	end
	V.ResetView = function(m)
		m.facing, m.panY, m.panZ, m.zoom = 0, 0, 0, 1
		V.Stand(m)
	end
	model:EnableMouse(true)
	model:EnableMouseWheel(true)
	model.facing, model.panY, model.panZ, model.zoom = 0, 0, 0, 1
	model:SetScript("OnMouseDown", function(self, button)
		local x, y = GetCursorPosition()
		if button == "RightButton" then
			self.panning = { x, y }
		else
			self.turning = x
		end
	end)
	model:SetScript("OnMouseUp", function(self)
		self.turning, self.panning = nil, nil
	end)
	model:SetScript("OnUpdate", function(self)
		if not (self.turning or self.panning) then
			return
		end
		local x, y = GetCursorPosition()
		if self.turning then
			self.facing = self.facing + (x - self.turning) * 0.012
			self.turning = x
			pcall(self.SetFacing, self, self.facing)
		end
		if self.panning then
			-- the further back the camera, the further a pixel carries it
			local k = PAN * (self.zoom or 1)
			self.panY = self.panY + (x - self.panning[1]) * k
			self.panZ = self.panZ + (y - self.panning[2]) * k
			self.panning[1], self.panning[2] = x, y
			pcall(self.SetPosition, self, 0, self.panY, self.panZ)
		end
	end)
	model:SetScript("OnMouseWheel", function(self, delta)
		self.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, (self.zoom or 1) * ((delta or 0) > 0 and 0.88 or 1.14)))
		pcall(self.SetCamDistanceScale, self, self.zoom)
	end)
	-- the client puts its framing back when the model loads: ours over it
	pcall(model.SetScript, model, "OnModelLoaded", function(self)
		V.Stand(self)
		-- through V: learnBody is a local further down this file
		V.LearnBody(self)
	end)
	page.model = model

	page.hint = W.Label(page, WORDS:format("drag to turn · right-drag to move · wheel to zoom"), "small")
	page.hint:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -8)
	page.reset = W.Button(page, "Reset view", 84, 18)
	page.reset:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -5)
	page.reset:SetScript("OnClick", function()
		V.ResetView(page.model)
	end)

	-- three numbers: its kills, what it is worth, the metal it has reached
	local tileW = math.floor((inner - 16) / 3)
	local tileY = STAGE_Y + STAGE_H + 34
	page.tiles = {}
	for i, word in ipairs({ "KILLS", "POINTS", "MASTERY" }) do
		local t = tile(page, word)
		t:SetSize(i == 3 and inner - 2 * (tileW + 8) or tileW, TILE_H)
		t:SetPoint("TOPLEFT", MODAL_PAD + (i - 1) * (tileW + 8), -tileY)
		page.tiles[i] = t
	end
	page.kills, page.points, page.mastery = page.tiles[1], page.tiles[2], page.tiles[3]

	-- the ladder: the four metals at this mob's rank, the way to the next
	local ladder = CreateFrame("Frame", nil, page)
	ladder:SetSize(inner, LADDER_H)
	ladder:SetPoint("TOPLEFT", MODAL_PAD, -(tileY + TILE_H + 10))
	W.Panel(ladder, W.FILL, W.HAIR)
	page.ladder = ladder
	ladder.head = W.Label(ladder, "MASTERY", "small", DIM[1], DIM[2], DIM[3])
	ladder.head:SetPoint("TOPLEFT", 12, -9)
	ladder.togo = W.Label(ladder, "", "small", DIM[1], DIM[2], DIM[3])
	ladder.togo:SetPoint("TOPRIGHT", -12, -9)
	ladder.togo:SetJustifyH("RIGHT")
	ladder.track = ladder:CreateTexture(nil, "ARTWORK")
	ladder.track:SetPoint("TOPLEFT", 12, -28)
	ladder.track:SetSize(inner - 24, 5)
	ladder.track:SetColorTexture(0.12, 0.15, 0.14, 1)
	ladder.fill = ladder:CreateTexture(nil, "OVERLAY")
	ladder.fill:SetPoint("TOPLEFT", ladder.track, "TOPLEFT", 0, 0)
	ladder.fill:SetHeight(5)
	ladder.rungs = {}
	local rungW = (inner - 24) / 4
	for i = 1, 4 do
		local name = W.Label(ladder, "", "small")
		name:SetPoint("TOP", ladder, "TOPLEFT", 12 + rungW * (i - 0.5), -42)
		local need = W.Label(ladder, "", "small", DIM[1], DIM[2], DIM[3])
		need:SetPoint("TOP", name, "BOTTOM", 0, -2)
		ladder.rungs[i] = { name = name, need = need }
	end

	-- the lore in full, in a place that scrolls: its own page, a tribe, a
	-- race and a type can run well past the popup's foot between them. No
	-- heading over it (Josh 2026-09-26: "Let's remove the "Lore" heading")
	local loreY = tileY + TILE_H + 10 + LADDER_H + 12
	page.loreBox = W.Scroller(page, 6)
	page.loreBox:SetPoint("TOPLEFT", MODAL_PAD, -loreY)
	page.loreBox:SetPoint("BOTTOMRIGHT", -MODAL_PAD, FOOT_H + 6)
	page.loreBox.step = 48
	-- its pieces are made as a mob needs them (V.LorePiece); the credit,
	-- once, under them all
	page.loreBody = page.loreBox.content
	page.lorePieces = {}
	page.loreFrom = W.Label(page.loreBody, "", "small", DIM[1], DIM[2], DIM[3])
	page.loreFrom:SetJustifyH("LEFT")

	-- the foot: when it was first killed, and where this mob is in the grid's
	W.Divider(page, MODAL_PAD, -(MODAL_H - FOOT_H))
	page.first = W.Label(page, "", "small", DIM[1], DIM[2], DIM[3])
	page.first:SetPoint("BOTTOMLEFT", MODAL_PAD, 12)
	page.count = W.Label(page, "", "small", DIM[1], DIM[2], DIM[3])
	page.count:SetPoint("BOTTOMRIGHT", -MODAL_PAD, 12)
	page.count:SetJustifyH("RIGHT")
end

-- ---------------------------------------------------------------------------
-- What there is to say about one mob, for its page and its card's hover
-- ---------------------------------------------------------------------------

function V.Facts(npc, kills, all)
	local J = BT.Menagerie
	local s = J.Store()
	local m = npc and s and s.mobs[npc]
	if not m then
		return nil
	end
	local f = { name = m.name or ("#" .. npc), color = RANK[m.rank], rank = m.rank }
	-- THE LORE IN FULL (Josh 2026-09-26: "include the full text on the
	-- details"): every wiki page that speaks of the mob, most specific first,
	-- the first bare and the rest under their titles; then what a quest said
	-- of it, under the quest's; and the pages credited once, at the end.
	-- The wiki's item links come through as "[Fel Moss]": the brackets go.
	f.loreLine = J.LoreLine(m)
	f.lore = {}
	local titles = {}
	for _, e in ipairs(J.WikiLore(m)) do
		-- a page borrowed from a mob with the same body is taken as fact
		-- (Josh 2026-09-26: "We should just assume it is a harpy if the
		-- model is the same"), headed like any other
		f.lore[#f.lore + 1] = { head = #f.lore > 0 and e.title or nil, text = (e.text:gsub("%[(.-)%]", "%1")) }
		titles[#titles + 1] = e.title
	end
	local q = type(m.lore) == "table" and m.lore or nil
	if q and q.text then
		f.lore[#f.lore + 1] = { head = ("From the quest \"%s\""):format(q.quest or "?"), text = q.text }
	end
	if #f.lore == 0 then
		f.lore[1] = { text = f.loreLine }
	end
	f.loreFrom = #titles > 0
		and ("Warcraft Wiki: %s · CC BY-SA 3.0"):format(table.concat(titles, ", ")) or nil
	local meta = {}
	for _, part in ipairs({ J.KindOf(m), m.family, level(m), RANK_WORD[m.rank], m.zone }) do
		if part then
			meta[#meta + 1] = part
		end
	end
	f.meta = table.concat(meta, " · ")

	-- its kills (and every character's, when they are more), its worth, and
	-- its mastery on the ladder of its rank
	local account = ui().scope == "account"
	f.n = kills[npc] or 0
	f.allN = account and f.n or (all[npc] or 0)
	f.points = J.MobPoints(m, f.n)
	f.ladder = J.Ladder(m)
	f.tier, f.here, f.nxt = J.Mastery(f.n, m)

	-- first killed: this character's, or the earliest of any
	local mine = J.Mine()
	local first
	for _, ch in pairs(s.chars) do
		local at = ch.first and ch.first[npc]
		if at and (account or ch == mine) and (not first or at < first) then
			first = at
		end
	end
	local when = first and U.ShortDate(first)
	if when then
		f.first = ("First killed %s"):format(when) .. (m.zone and (" in %s"):format(m.zone) or "")
	end
	return f
end

-- ---------------------------------------------------------------------------
-- The grid
-- ---------------------------------------------------------------------------

-- The grid as rows: a heading per type, then its mobs five to a row unless
-- the type is folded. Each row knows how far down the strip it starts.
-- a section's name: a type is many of them ("Beasts"), a zone is itself
function V.Label(key)
	if key == V.ALL then
		return "All"
	end
	if ui().group == "zone" then
		return key
	end
	return BT.Menagerie.Plural(key)
end

-- the section the rail has picked, for the grouping in use ("All" unless
-- something else was, and still is there)
function V.Picked(pages)
	local u = ui()
	u.pick = u.pick or {}
	local key = u.pick[u.group]
	for _, p in ipairs(pages) do
		if p.kind == key then
			return key
		end
	end
	return V.ALL
end

-- what the section is worth: its kinds, and their masteries
local function worth(mobs)
	local points = 0
	for _, e in ipairs(mobs) do
		points = points + BT.Menagerie.MobPoints(e.m, e.n)
	end
	return points
end

-- The grid as rows of cards, each row knowing how far down the strip it
-- starts.
-- `list` lays the mobs out as the list's rows rather than as cards
function V.Layout(mobs, width, list)
	local cols = list and LIST_COLS or COLS
	local gap = list and LIST_GAP or GAP
	local w = math.floor((width - gap * (cols - 1)) / cols)
	local ch = list and LIST_H or Card.Height(w)
	local rows, y = {}, EDGE
	for i = 1, #mobs, cols do
		local items = {}
		for j = i, math.min(i + cols - 1, #mobs) do
			items[#items + 1] = mobs[j]
		end
		rows[#rows + 1] = { items = items, y = y, h = ch }
		y = y + ch + gap
	end
	return { rows = rows, w = w, h = ch, gap = gap, list = list, height = math.max(0, y - gap + EDGE) }
end

local function railRow(i)
	local b = frame.bestiary
	local r = b.railRows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Button", nil, b.rail.content)
	r:SetHeight(RAIL_ROW_H)
	r.lit = r:CreateTexture(nil, "BACKGROUND")
	r.lit:SetAllPoints()
	r.lit:Hide()
	r.text = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.text:SetPoint("TOPLEFT", 10, -5)
	r.text:SetPoint("RIGHT", r, "RIGHT", -8, 0)
	r.text:SetJustifyH("LEFT")
	r.text:SetWordWrap(false)
	r.sub = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -2)
	r.sub:SetJustifyH("LEFT")
	r:SetScript("OnClick", function(self)
		local u = ui()
		u.pick = u.pick or {}
		u.pick[u.group] = self.key
		b.grid:ScrollTo(0)
		V.Refresh()
	end)
	r:SetScript("OnEnter", function(self)
		if not self.chosen then
			self.lit:SetColorTexture(1, 1, 1, 0.05)
			self.lit:Show()
		end
	end)
	r:SetScript("OnLeave", function(self)
		if not self.chosen then
			self.lit:Hide()
		end
	end)
	b.railRows[i] = r
	return r
end

-- the rail: All, then every section, each with its count and points
function V.DrawRail(pages, picked)
	local b = frame.bestiary
	local entries = {}
	local all, allPoints = 0, 0
	for _, p in ipairs(pages) do
		p.points = worth(p.mobs)
		all = all + #p.mobs
		allPoints = allPoints + p.points
	end
	entries[1] = { kind = V.ALL, n = all, points = allPoints }
	for _, p in ipairs(pages) do
		entries[#entries + 1] = { kind = p.kind, n = #p.mobs, points = p.points }
	end
	local width = RAIL_W - 6 - 4
	for i, e in ipairs(entries) do
		local r = railRow(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", b.rail.content, "TOPLEFT", 0, -(i - 1) * RAIL_ROW_H)
		r:SetWidth(width)
		r.key = e.kind
		r.chosen = e.kind == picked
		r.text:SetText(("%s |cff8a9894(%d)|r"):format(V.Label(e.kind), e.n))
		r.sub:SetText(("%s %s"):format(big(e.points), e.points == 1 and "point" or "points"))
		if r.chosen then
			local w = BT.Widgets.WASH
			r.lit:SetColorTexture(w[1], w[2], w[3], w[4])
			r.lit:Show()
		else
			r.lit:Hide()
		end
		r:Show()
	end
	for i = #entries + 1, #b.railRows do
		b.railRows[i]:Hide()
	end
	b.rail:SetContentHeight(#entries * RAIL_ROW_H)
	return entries
end

-- STILL, NOT BREATHING (Josh 2026-09-25: "all of the card portraits are
-- still animating. I want still portraits"). A grid of idling models is a
-- grid of things fidgeting. Each is held on the first frame of its standing
-- pose, by whichever call this client has - FreezeAnimation holds a frame,
-- SetPaused stops the clock - and held again when the model loads, since a
-- load starts it idling afresh. /bt menagerie debug says which one it was.
local STAND = 0
local FREEZES = {
	{ "FreezeAnimation", function(m) return m:FreezeAnimation(STAND, 0, 0) end },
	{ "SetPaused", function(m) return m:SetPaused(true) end },
}

-- EVERY ONE, NOT THE FIRST (Josh 2026-09-26: "the models are still, but I'm
-- still seeing animated visual effects. The lightning guy has animated
-- lightning"). FreezeAnimation holds the skeleton and nothing else; the
-- lightning is the model's effects, on a clock of their own, which SetPaused
-- may stop. So every call there is is made.
local function freeze(model)
	local used = {}
	for _, f in ipairs(FREEZES) do
		if type(model[f[1]]) == "function" and pcall(f[2], model) then
			used[#used + 1] = f[1]
		end
	end
	-- whether the effects could be switched off instead, should pausing
	-- not be enough - asked, not done: a mob made of lightning is not much
	-- without it
	V.canHideEffects = type(model.SetParticlesEnabled) == "function"
	if #used > 0 then
		V.freezeWith = table.concat(used, " + ")
		return true
	end
	V.freezeWith = V.freezeWith or false
	return false
end
V.Freeze = freeze

-- which model file a portrait drew, kept with its mob (J.Body): a mob with
-- no page of its own can borrow the race of another with the same body.
-- Drawn again when that changes what the journal says.
local function learnBody(model)
	local npc = model.npc
	if not npc or not model.GetModelFileID then
		return
	end
	local ok, id = pcall(model.GetModelFileID, model)
	if ok and BT.Menagerie.Body(npc, id) then
		V.Changed()
	end
end
V.LearnBody = learnBody

local function frameFace(model)
	-- the camera worked out again for the frame's size as it is now, then
	-- brought in to the face
	pcall(model.RefreshCamera, model)
	pcall(model.SetPortraitZoom, model, 1)
	pcall(model.SetPosition, model, 0, 0, 0)
	freeze(model)
end

-- NO PORTRAITS UNDER THE POPUP'S MODEL (Josh 2026-09-26: "Seeing a black
-- silhouette of the harpy portrait on top of the details"). A model in a
-- lower strata still wins the depth test against the popup's model where
-- they overlap, cutting its shape out of the mob in front, so a portrait
-- behind the popup's model is put away while it is up - and framed again when
-- it comes back, since a model shown again forgets its zoom. Only those:
-- the rest stay, dimmed (Josh: "All portraits on the list view disappear
-- when the details modal is opened").
local function rect(f)
	local l, t = f:GetLeft(), f:GetTop()
	local w, h = f:GetWidth(), f:GetHeight()
	for _, v in ipairs({ l, t, w, h }) do
		if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then
			return nil
		end
	end
	return l, t - h, l + w, t
end

-- whether a portrait stands behind the popup's model; not knowing where
-- either is, as if it did
function V.UnderStage(model)
	local stage = frame.bestiary.page.stage
	local l1, b1, r1, t1 = rect(model)
	local l2, b2, r2, t2 = rect(stage)
	if not (l1 and l2) then
		return true
	end
	return l1 < r2 and r1 > l2 and b1 < t2 and t1 > b2
end

local function cover(model, covered)
	if covered then
		model:Hide()
		model.covered = true
	elseif model.covered then
		model.covered = nil
		model:Show()
		frameFace(model)
	end
end

-- ---------------------------------------------------------------------------
-- The map behind the portrait
-- ---------------------------------------------------------------------------
--
-- THE PATCH WHERE YOU MET IT (Josh 2026-09-26: "the correct zone render as
-- the portrait background"). A zone's world map is a grid of tiles the client
-- hands to anyone who asks (C_Map.GetMapArtLayerTextures), its own zones'
-- included; the spot a mob was first killed is kept with it (Kills.Where). A
-- card shows the window of that map around the spot - a patch no wider than
-- one tile, so at most four tiles meet in it - dimmed so the portrait stands
-- out in front.

-- how much of the zone's map a card shows, and how dim it is
-- MOB IN FRONT, MAP BEHIND (Josh 2026-09-26: "the model kind of blends into
-- it too much"). The parchment is the same mid tones as the mobs, so it is
-- drained of its colour, darkened, and cooled to the loading screens' ink
-- blue: the colour on the card is the mob's.
local ART_ZOOM = 0.28
local ART_TINT = { 0.30, 0.36, 0.44 }

local arts = {}

-- a map's art: its size, its tiles' size, how many across, and the tiles
function V.MapArt(map)
	if arts[map] ~= nil then
		return arts[map] or nil
	end
	arts[map] = false
	if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then
		return nil
	end
	local ok, layers = pcall(C_Map.GetMapArtLayers, map)
	local L = ok and type(layers) == "table" and layers[1]
	if not (L and L.layerWidth and L.tileWidth and L.tileWidth > 0 and L.tileHeight > 0) then
		return nil
	end
	local okF, files = pcall(C_Map.GetMapArtLayerTextures, map, 1)
	if not (okF and type(files) == "table" and #files > 0) then
		return nil
	end
	arts[map] = {
		lw = L.layerWidth, lh = L.layerHeight, tw = L.tileWidth, th = L.tileHeight,
		cols = math.ceil(L.layerWidth / L.tileWidth), files = files,
	}
	return arts[map]
end

-- The pieces of the map a card of `pw` by `ph` shows around (mx, my): for
-- each tile it touches, the file, the part of it (texture coordinates), and
-- where on the card that part goes. Pure arithmetic, for the tests.
function V.ArtPieces(a, mx, my, pw, ph)
	if not (a and mx and my and pw > 0 and ph > 0) then
		return {}
	end
	-- the window: the card's shape, a share of the map's width, never more
	-- than a tile either way
	local ww = math.min(a.tw, a.lw * ART_ZOOM)
	local wh = ww * ph / pw
	if wh > a.th then
		wh = a.th
		ww = wh * pw / ph
	end
	local function clamp(v, lo, hi)
		return math.max(lo, math.min(hi, v))
	end
	local x0 = clamp(mx * a.lw - ww / 2, 0, math.max(0, a.lw - ww))
	local y0 = clamp(my * a.lh - wh / 2, 0, math.max(0, a.lh - wh))
	local out = {}
	for row = math.floor(y0 / a.th), math.floor((y0 + wh - 0.001) / a.th) do
		for col = math.floor(x0 / a.tw), math.floor((x0 + ww - 0.001) / a.tw) do
			local file = a.files[row * a.cols + col + 1]
			if file then
				local tx, ty = col * a.tw, row * a.th
				local ix0, iy0 = math.max(x0, tx), math.max(y0, ty)
				local ix1, iy1 = math.min(x0 + ww, tx + a.tw), math.min(y0 + wh, ty + a.th)
				out[#out + 1] = {
					file = file,
					l = (ix0 - tx) / a.tw, r = (ix1 - tx) / a.tw, t = (iy0 - ty) / a.th, b = (iy1 - ty) / a.th,
					x = (ix0 - x0) * pw / ww, y = (iy0 - y0) * ph / wh,
					w = (ix1 - ix0) * pw / ww, h = (iy1 - iy0) * ph / wh,
				}
			end
		end
	end
	return out
end

-- a card's background: the patch of its mob's map in the card's window, or
-- nothing
function V.PaintArt(c, m)
	local pw, ph = c.winW or 0, c.winH or 0
	local a = m and m.map and V.MapArt(m.map)
	local pieces = a and V.ArtPieces(a, m.mx, m.my, pw, ph) or {}
	for i, tex in ipairs(c.tiles) do
		local p = pieces[i]
		if p then
			tex:ClearAllPoints()
			tex:SetPoint("TOPLEFT", c.box, "TOPLEFT", p.x, -p.y)
			tex:SetSize(math.max(1, p.w), math.max(1, p.h))
			tex:SetTexture(p.file)
			tex:SetTexCoord(p.l, p.r, p.t, p.b)
			pcall(tex.SetDesaturated, tex, true)
			tex:SetVertexColor(ART_TINT[1], ART_TINT[2], ART_TINT[3])
			tex:Show()
		else
			tex:Hide()
		end
	end
	c.shade:SetShown(#pieces > 0)
	c.topShade:SetShown(#pieces > 0)
	return #pieces
end

local function card(i)
	local b = frame.bestiary
	local c = b.cards[i]
	if c then
		return c
	end
	c = Card.New(b.grid.content)
	-- the client loads a model a beat after it is asked for, and forgets the
	-- zoom when it does: framed again when it arrives
	pcall(c.portrait.SetScript, c.portrait, "OnModelLoaded", function(self)
		frameFace(self)
		V.LearnBody(self)
	end)
	c:SetScript("OnClick", function(self)
		V.Open(self.npc)
	end)
	-- NO TOOLTIP (Josh 2026-09-26: "I don't think we need the tooltip at
	-- all"): the card grows instead, and a click is its page
	c:SetScript("OnEnter", function(self)
		-- the card held up over it carries the light and the shadow
		V.Zoom(self, true)
	end)
	c:SetScript("OnLeave", function(self)
		V.Zoom(self, false)
	end)
	b.cards[i] = c
	return c
end

-- one card, dealt one mob
local function bind(c, e, w)
	local J = BT.Menagerie
	Card.Layout(c, w)
	if c.npc ~= e.npc then
		c.npc = e.npc
		c.portrait.npc = e.npc
		pcall(c.portrait.SetCreature, c.portrait, e.npc)
		frameFace(c.portrait)
		-- a model the client already had loads at once, with no event
		learnBody(c.portrait)
	end
	-- the map, painted again when the mob, its spot or the card's width moves
	local artKey = ("%s:%s:%s:%s"):format(tostring(e.m.map), tostring(e.m.mx), tostring(e.m.my), tostring(w))
	if c.artKey ~= artKey then
		c.artKey = artKey
		V.PaintArt(c, e.m)
	end
	local tier = J.Mastery(e.n, e.m)
	Card.Dress(c, {
		npc = e.npc, name = e.m.name or ("#" .. e.npc), rank = e.m.rank,
		kind = V.TypeLine(e.m), lore = J.LoreLine(e.m),
		kills = big(e.n), points = big(J.MobPoints(e.m, e.n)), tier = tier,
	})
end

-- ---------------------------------------------------------------------------
-- The list: a slim row a mob
-- ---------------------------------------------------------------------------
--
-- A face, the name, what it is, and on the right its kills with its mastery
-- in its metal and its points. A thin edge down the left in the tooltips'
-- gold or silver for an elite or a rare. A click is its page, as a card's is.

local LIST_FACE = 38

local function listRow(i)
	local b = frame.bestiary
	b.rows = b.rows or {}
	local r = b.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Button", nil, b.grid.content)
	r:SetHeight(LIST_H)
	BT.Pill.Panel(r, W.FILL, W.HAIR)
	r.edge = r:CreateTexture(nil, "ARTWORK")
	r.edge:SetPoint("TOPLEFT", 1, -1)
	r.edge:SetPoint("BOTTOMLEFT", 1, 1)
	r.edge:SetWidth(2)
	r.face = CreateFrame("PlayerModel", nil, r)
	r.face:SetSize(LIST_FACE, LIST_FACE)
	r.face:SetPoint("LEFT", 6, 0)
	pcall(r.face.SetScript, r.face, "OnModelLoaded", function(self)
		frameFace(self)
		V.LearnBody(self)
	end)
	r.name = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(r.name.SetFont, r.name, Card.FONT_NAME, 13, "")
	r.name:SetPoint("TOPLEFT", r.face, "TOPRIGHT", 9, -3)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.kind = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(r.kind.SetFont, r.kind, Card.FONT_TYPE, 12, "")
	r.kind:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.kind:SetJustifyH("LEFT")
	r.kind:SetWordWrap(false)
	r.kind:SetTextColor(0.79, 0.72, 0.58)
	-- the right: kills over the mastery word, and the points beside them
	r.points = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(r.points.SetFont, r.points, Card.FONT_NAME, 13, "")
	r.points:SetPoint("TOPRIGHT", -10, -7)
	r.pointsLabel = W.Label(r, "PTS", "small", DIM[1], DIM[2], DIM[3])
	r.pointsLabel:SetPoint("TOP", r.points, "BOTTOM", 0, -3)
	r.kills = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(r.kills.SetFont, r.kills, Card.FONT_NAME, 13, "")
	r.kills:SetPoint("TOPRIGHT", r, "TOPRIGHT", -52, -7)
	r.tier = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(r.tier.SetFont, r.tier, Card.FONT_TYPE, 11, "")
	r.tier:SetPoint("TOPRIGHT", r.kills, "BOTTOMRIGHT", 0, -3)
	r.name:SetPoint("RIGHT", r.kills, "LEFT", -10, 0)
	r.kind:SetPoint("RIGHT", r.kills, "LEFT", -10, 0)
	r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 1)
	r.lit:SetAllPoints()
	r.lit:SetColorTexture(1, 1, 1, 0.05)
	r.lit:Hide()
	r:SetScript("OnClick", function(self)
		V.Open(self.npc)
	end)
	r:SetScript("OnEnter", function(self)
		self.lit:Show()
	end)
	r:SetScript("OnLeave", function(self)
		self.lit:Hide()
	end)
	b.rows[i] = r
	return r
end

-- one row, dealt one mob
local function bindRow(r, e, w)
	local J = BT.Menagerie
	r:SetWidth(w)
	if r.npc ~= e.npc then
		r.npc = e.npc
		r.face.npc = e.npc
		pcall(r.face.SetCreature, r.face, e.npc)
		frameFace(r.face)
		learnBody(r.face)
	end
	r.name:SetText(e.m.name or ("#" .. e.npc))
	-- the rank in words as well as the edge (Josh 2026-09-26: "List view
	-- doesn't show rare/elite mob indicators"), in the tooltip's colour
	local line, word, rc = V.TypeLine(e.m), RANK_WORD[e.m.rank], RANK[e.m.rank]
	if word and rc then
		line = ("%s · |cff%02x%02x%02x%s|r"):format(line, math.floor(rc[1] * 255 + 0.5),
			math.floor(rc[2] * 255 + 0.5), math.floor(rc[3] * 255 + 0.5), word)
	end
	r.kind:SetText(line)
	r.kills:SetText(big(e.n))
	r.points:SetText(big(J.MobPoints(e.m, e.n)))
	local tier = J.Mastery(e.n, e.m)
	local metal = Card.TIERS[tier]
	local mc = metal.color
	r.tier:SetText(tier == 0 and "KILLS" or metal.name:upper())
	if tier == 0 then
		r.tier:SetTextColor(DIM[1], DIM[2], DIM[3])
	else
		r.tier:SetTextColor(mc[1], mc[2], mc[3])
	end
	-- the rank, as the tooltips wear it
	local rs = Card.RANK_STYLE[e.m.rank]
	local edge = rs and rs.level >= 1 and (rs.ornament or rs.line)
	r.edge:SetShown(edge and true or false)
	if edge then
		r.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
	end
end

-- what a card says it is: "Beast · Cat · Lv 5-6"
function V.TypeLine(m)
	local parts = { BT.Menagerie.KindOf(m) }
	if m.family then
		parts[#parts + 1] = m.family
	end
	local lv = level(m)
	if lv then
		parts[#parts + 1] = (lv:gsub("^Level", "Lv"))
	end
	return table.concat(parts, " · ")
end

-- A CARD GROWS UNDER THE CURSOR (Josh 2026-09-26: "on hover we should zoom
-- the cards a bit so they can be read easier"). It is placed by its centre,
-- so growing keeps it where it was; and it rises above the cards round it.
-- A point's offset is in the card's own scale, so it is divided by it.
-- PICKED UP, NOT TILTED OR GROWN (Josh 2026-09-26). The card under the cursor
-- is lifted a few units over its shadow and brightened, and rises above the
-- cards round it.
--
-- It does not grow. Grown by scale, its model framed itself afresh and
-- showed the mob's middle; grown as a larger copy, the copy's model framed
-- itself closer than a card's does ("the zoom is still distorted") - on this
-- client a model's portrait framing turns on its frame's size in ways the
-- addon cannot see. A card lifted keeps its model exactly as it was. The
-- cards themselves were made larger instead, for the words.
local LIFT = 4

function V.PlaceCard(c)
	local y = c.slotY - (c.lifted and LIFT or 0)
	c:ClearAllPoints()
	c:SetPoint("CENTER", frame.bestiary.grid.content, "TOPLEFT", c.slotX, -y)
end

function V.Zoom(c, on)
	c.lifted = on and true or false
	pcall(c.SetFrameStrata, c, on and "DIALOG" or (frame:GetFrameStrata() or "HIGH"))
	Card.Hover(c, on)
	V.PlaceCard(c)
end

-- Deal the cards: every row in view gets its cards, and whatever is left
-- over is put away.
function V.Deal()
	local b = frame and frame.bestiary
	local L = b and b.layout
	-- whatever was lifted is someone else's card now
	for _, c in ipairs(b and b.cards or {}) do
		if c.lifted then
			V.Zoom(c, false)
		end
	end
	if not L then
		return 0
	end
	local grid = b.grid
	local top = grid.offset or 0
	local room = grid:Room()
	if room <= 0 then
		room = HEIGHT - BODY_Y - PAD - 16 - TOOLBAR_H
	end
	local bottom = top + room
	local open = V.open ~= nil
	local ci = 0
	for _, row in ipairs(L.rows) do
		if row.y >= top - 1 and row.y + row.h <= bottom + 1 then
			for col, e in ipairs(row.items) do
				ci = ci + 1
				local x = EDGE + (col - 1) * (L.w + L.gap)
				if L.list then
					local r = listRow(ci)
					bindRow(r, e, L.w)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", grid.content, "TOPLEFT", x, -row.y)
					r:Show()
					-- where it is decides whether it is behind the popup
					cover(r.face, open and V.UnderStage(r.face))
				else
					local c = card(ci)
					bind(c, e, L.w)
					c.entry = e
					c.slotX = x + L.w / 2
					c.slotY = row.y + L.h / 2
					V.PlaceCard(c)
					c:Show()
					cover(c.portrait, open and V.UnderStage(c.portrait))
				end
			end
		end
	end
	-- the other kind put away entirely, and what is left of this one
	for i = (L.list and 1 or ci + 1), #b.cards do
		b.cards[i]:Hide()
	end
	for i = (L.list and ci + 1 or 1), #(b.rows or {}) do
		b.rows[i]:Hide()
	end
	return ci
end

function V.DrawBestiary(kills, all)
	local J = BT.Menagerie
	local b = frame.bestiary
	V.kills, V.all = kills, all
	local u = ui()
	-- the mobs of the zone we stand in borrow its map until a kill gives them a spot
	local zone = (GetRealZoneText and GetRealZoneText()) or nil
	local map = BT.MenagerieKills.Where()
	J.GuessSpots(zone, map)
	local pages = J.Pages(kills, u.group, u.sort)
	b.groups:Select(u.group)
	b.sorts:Select(u.sort)
	b.layouts:Select(u.layout)
	-- a page for a mob these counts do not have (the other scope's) closes
	if V.open and not kills[V.open] then
		V.open = nil
	end
	b.empty:SetShown(#pages == 0)
	local picked = V.Picked(pages)
	V.DrawRail(pages, picked)
	-- the cards of the section picked, or of all of them in one order
	local mobs = {}
	for _, p in ipairs(pages) do
		if picked == V.ALL or p.kind == picked then
			for _, e in ipairs(p.mobs) do
				mobs[#mobs + 1] = e
			end
		end
	end
	if picked == V.ALL then
		J.SortMobs(mobs, u.sort)
	end
	-- the popup steps through these
	V.mobs, V.picked = mobs, picked
	b.layout = V.Layout(mobs, GRID_W - 2 * EDGE, u.layout == "list")
	-- the wheel moves a row of whichever it is: three list rows, one row of cards
	b.grid.step = b.layout.list and (b.layout.h + b.layout.gap) * 3 or (b.layout.h + b.layout.gap)
	b.grid:SetContentHeight(b.layout.height)
	-- the open mob's popup, over the grid: shown before its model is set,
	-- since a model loaded in a hidden frame is framed wrongly, and before
	-- the grid is dealt, which asks where the popup's model stands
	b.dim:SetShown(V.open ~= nil)
	V.Deal()
	if V.open then
		V.DrawPage(V.open, kills, all)
	end
end

-- the popup of one mob
function V.DrawPage(npc, kills, all)
	local page = frame.bestiary.page
	local f = V.Facts(npc, kills, all)
	if not f then
		return
	end
	if page.model.npc ~= npc then
		page.model.npc = npc
		pcall(page.model.SetCreature, page.model, npc)
		learnBody(page.model)
		-- a new mob opens on the client's own framing
		V.ResetView(page.model)
	end
	page.name:SetText(f.name)
	local c = f.color or { 1, 1, 1 }
	page.name:SetTextColor(c[1], c[2], c[3])
	page.meta:SetText(f.meta)

	page.kills.value:SetText(big(f.n))
	page.kills.label:SetText(f.allN > f.n and ("KILLS · %s IN ALL"):format(big(f.allN)) or "KILLS")
	page.points.value:SetText(big(f.points))
	local here = f.here
	page.mastery.value:SetText(here and here.name or "None")
	local hc = here and here.color or DIM
	page.mastery.value:SetTextColor(hc[1], hc[2], hc[3])

	-- the ladder at this mob's rank, the metals reached lit
	local L = page.ladder
	for i, rung in ipairs(L.rungs) do
		local m = f.ladder[i]
		rung.name:SetText(m.name)
		rung.name:SetTextColor(m.color[1], m.color[2], m.color[3])
		rung.name:SetAlpha(i <= f.tier and 1 or 0.45)
		rung.need:SetText(("%s %s"):format(big(m.n), m.n == 1 and "kill" or "kills"))
	end
	local track = MODAL_W - 2 * MODAL_PAD - 24
	local nxt = f.nxt
	if nxt then
		L.togo:SetText(("%s at %s · %s to go"):format(nxt.name, big(nxt.n), big(nxt.n - f.n)))
		local from = here and here.n or 0
		local k = (f.n - from) / math.max(1, nxt.n - from)
		L.fill:SetWidth(math.max(1, math.floor(track * k + 0.5)))
		L.fill:SetColorTexture(nxt.color[1], nxt.color[2], nxt.color[3], 1)
		L.fill:SetShown(k > 0)
	else
		L.togo:SetText("every mastery earned")
		L.fill:SetWidth(track)
		L.fill:SetColorTexture(here.color[1], here.color[2], here.color[3], 1)
		L.fill:Show()
	end

	-- the lore, piece under piece, as tall as it measures
	local body, prev, tall = page.loreBody, nil, 0
	local function put(region, gap)
		region:ClearAllPoints()
		if prev then
			region:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
		else
			region:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
			gap = 0
		end
		region:SetPoint("RIGHT", body, "RIGHT", 0, 0)
		region:Show()
		prev = region
		local h = region.GetStringHeight and region:GetStringHeight() or region:GetHeight()
		tall = tall + gap + BT.Pill.Number(h, 0)
	end
	for i, sec in ipairs(f.lore) do
		local p = V.LorePiece(page, i)
		p.rule:SetShown(i > 1)
		if i > 1 then
			put(p.rule, 12)
		end
		p.head:SetShown(sec.head ~= nil)
		if sec.head then
			p.head:SetText(sec.head:upper())
			put(p.head, 10)
		end
		p.text:SetText(sec.text or "")
		put(p.text, sec.head and 5 or 10)
	end
	for i = #f.lore + 1, #page.lorePieces do
		local p = page.lorePieces[i]
		p.rule:Hide()
		p.head:Hide()
		p.text:Hide()
	end
	page.loreFrom:SetShown(f.loreFrom ~= nil)
	if f.loreFrom then
		page.loreFrom:SetText(f.loreFrom)
		put(page.loreFrom, 14)
	end
	page.loreBox:SetContentHeight(tall + 6)
	if page.loreFor ~= npc then
		page.loreFor = npc
		page.loreBox:ScrollTo(0)
	end

	-- the foot, and the way to the mobs either side while there are any
	page.first:SetText(f.first or "")
	local list, at = V.mobs or {}, V.Place(npc)
	page.count:SetText(at and ("%d of %d · %s"):format(at, #list, V.Label(V.picked or V.ALL)) or "")
	page.prev:SetShown(at ~= nil and #list > 1)
	page.next:SetShown(at ~= nil and #list > 1)
end

-- where a mob is among those the grid is showing
function V.Place(npc)
	for i, e in ipairs(V.mobs or {}) do
		if e.npc == npc then
			return i
		end
	end
end

-- the mob before (-1) or after (1) the open one, round from the last to the first
function V.Step(d)
	local list, at = V.mobs or {}, V.Place(V.open)
	if not at or #list < 2 then
		return false
	end
	V.Open(list[(at - 1 + d) % #list + 1].npc)
	return true
end

function V.Close()
	V.open = nil
	V.Refresh()
end

-- WHERE THE CAMERA LOOKS (Josh 2026-09-26: "center the camera on the body's
-- midsection? Right now it is on the absolute center of the model, so really
-- long tails make camera rotation act strange"). The model turns about its
-- origin while the camera aims at the middle of everything, tail and all.
-- Which calls this client has for moving either one is not written down
-- anywhere, so it is asked: every camera, position and bounds call a model
-- answers to, and what each says about the model on the open page.
local ASK = { "Camera", "Position", "Bound", "Center", "Transform", "Scale", "Facing", "Target", "Distance", "Pitch", "Yaw",
	"File", "Display" }

function V.ModelReport()
	local model = frame and frame.bestiary and frame.bestiary.page.model
	if not (model and V.open) then
		return nil
	end
	local out = { ("model of NPC %d, facing %s"):format(V.open, tostring(model.facing)) }
	local names = {}
	local mt = getmetatable(model)
	local index = mt and mt.__index
	if type(index) == "table" then
		for name, fn in pairs(index) do
			if type(fn) == "function" then
				for _, word in ipairs(ASK) do
					if name:find(word) then
						names[#names + 1] = name
						break
					end
				end
			end
		end
	end
	table.sort(names)
	out[#out + 1] = "calls: " .. table.concat(names, " ")
	-- and what the ones that read something say now
	for _, name in ipairs(names) do
		if name:match("^Get") or name:match("^Is") then
			local r = { pcall(model[name], model) }
			if r[1] then
				local vals = {}
				for i = 2, math.max(#r, 2) do
					local v = r[i]
					vals[#vals + 1] = type(v) == "number" and ("%.3f"):format(v) or tostring(v)
				end
				out[#out + 1] = ("%s = %s"):format(name, table.concat(vals, ", "))
			end
		end
	end
	return out
end

-- a mob's popup, from its card (or a toast); a card lifted under the
-- cursor is set down first, or it would stand over the dimming
function V.Open(npc)
	V.open = npc
	ui().view = "bestiary"
	for _, c in ipairs(frame and frame.bestiary.cards or {}) do
		if c.lifted then
			V.Zoom(c, false)
		end
	end
	V.Refresh()
end

-- ---------------------------------------------------------------------------
-- Achievements
-- ---------------------------------------------------------------------------

function V.BuildAchievements()
	local W = BT.Widgets
	local a = CreateFrame("Frame", nil, frame)
	a:SetPoint("TOPLEFT", PAD, -BODY_Y)
	a:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	W.Panel(a, W.RAISED, W.HAIR)
	a.list = W.Scroller(a, 6)
	a.list:SetPoint("TOPLEFT", 6, -6)
	a.list:SetPoint("BOTTOMRIGHT", -6, 6)
	a.list.step = ACH_H * 2
	a.rows, a.heads = {}, {}
	frame.achievements = a
	a:Hide()
end

local function achRow(i)
	local a = frame.achievements
	local r = a.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Frame", nil, a.list.content)
	r:SetHeight(ACH_H)
	r.points = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.points:SetPoint("LEFT", 6, 0)
	r.points:SetWidth(34)
	r.points:SetJustifyH("CENTER")
	r.title = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.title:SetPoint("TOPLEFT", 50, -6)
	r.title:SetJustifyH("LEFT")
	r.text = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.text:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
	r.text:SetJustifyH("LEFT")
	r.right = W.Label(r, "", "small")
	r.right:SetPoint("TOPRIGHT", -8, -8)
	r.right:SetJustifyH("RIGHT")
	r.track = r:CreateTexture(nil, "BORDER")
	r.track:SetSize(90, 3)
	r.track:SetPoint("TOPRIGHT", r.right, "BOTTOMRIGHT", 0, -6)
	r.fill = r:CreateTexture(nil, "ARTWORK")
	r.fill:SetHeight(3)
	r.fill:SetPoint("LEFT", r.track, "LEFT", 0, 0)
	r.hair = r:CreateTexture(nil, "BORDER")
	r.hair:SetPoint("TOPLEFT", 0, 0)
	r.hair:SetPoint("TOPRIGHT", 0, 0)
	r.hair:SetHeight(1)
	BT.Widgets.Hairline(r.hair)
	a.rows[i] = r
	return r
end

local function achHead(i)
	local a = frame.achievements
	local h = a.heads[i]
	if h then
		return h
	end
	h = CreateFrame("Frame", nil, a.list.content)
	h:SetHeight(HEAD_ROW_H)
	h.text = h:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	h.text:SetPoint("BOTTOMLEFT", 6, 5)
	BT.Widgets.TintText(h.text, 0.8)
	h.count = BT.Widgets.Label(h, "", "small", DIM[1], DIM[2], DIM[3])
	h.count:SetPoint("BOTTOMRIGHT", -8, 5)
	a.heads[i] = h
	return h
end

-- when an achievement was earned: this character's date, or the earliest of any
local function earnedAt(id, account)
	local J = BT.Menagerie
	local s = J.Store()
	if not account then
		local c = J.Mine()
		return c and c.earned[id]
	end
	local best
	for _, c in pairs(s and s.chars or {}) do
		local at = c.earned and c.earned[id]
		if at and (not best or at < best) then
			best = at
		end
	end
	return best
end

-- The masteries: a line per tier, the highest first - how many mobs are at it
-- and what the tier has been worth - then the five mobs nearest their next.
function V.MasteryRows(kills)
	local J = BT.Menagerie
	local s = J.Store()
	local total, byTier = J.Masteries(kills)
	local rows = {}
	for i = #J.MASTERY, 1, -1 do
		local m, t = J.MASTERY[i], byTier[i]
		rows[#rows + 1] = {
			id = "mastery:" .. m.name, title = m.name, color = m.color, points = t.points,
			need = 1, have = t.mobs > 0 and 1 or 0,
			text = ("%s kills of one mob, %s of an elite, %s of a rare, %s of a world boss · %d points each")
				:format(big(m.n), big(J.MASTERY_AT.elite[i]), big(J.MASTERY_AT.rare[i]),
					big(J.MASTERY_AT.worldboss[i]), m.points),
			right = ("%s %s"):format(big(t.mobs), t.mobs == 1 and "mob" or "mobs"),
		}
	end
	for _, nx in ipairs(J.NextMasteries(kills, 5)) do
		local mob = s and s.mobs[nx.npc]
		local m = J.Ladder(mob)[nx.tier]
		local name = (mob and mob.name) or ("#" .. nx.npc)
		rows[#rows + 1] = {
			id = ("next:%d"):format(nx.npc), title = ("%s %s"):format(name, WORDS:format("· " .. m.name)),
			points = m.points, need = nx.need, have = nx.have,
			text = ("kill it %s times"):format(big(nx.need)),
		}
	end
	return rows, total
end

-- The achievements, grouped: what the kinds are worth, the masteries, then
-- each group of milestones.
function V.Groups(kills, feats, account)
	local J = BT.Menagerie
	local st = J.Stats(kills, feats)
	local byGroup = {}
	for _, g in ipairs(J.GROUPS) do
		byGroup[g.key] = {}
	end
	for _, a in ipairs(J.List(st)) do
		a.at = earnedAt(a.id, account)
		local list = byGroup[a.group]
		list[#list + 1] = a
	end
	local out = {}
	-- first, what the kinds themselves are worth, a line per rank
	local kindTotal, byRank = J.KindPoints(kills)
	local kinds = {}
	for _, rank in ipairs(J.KIND_ORDER) do
		local r = byRank[rank]
		if r then
			local each = J.KIND_POINTS[rank] or 1
			kinds[#kinds + 1] = {
				id = "kinds:" .. rank, title = J.KIND_WORDS[rank], points = r.points, need = 1, have = 1,
				text = ("%d %s for each kind"):format(each, each == 1 and "point" or "points"),
				right = ("%s %s"):format(big(r.kinds), r.kinds == 1 and "kind" or "kinds"),
			}
		end
	end
	if #kinds > 0 then
		out[#out + 1] = { title = "Every kind", list = kinds, key = "kinds",
			count = ("%s points"):format(big(kindTotal)) }
		local masteries, masteryTotal = V.MasteryRows(kills)
		out[#out + 1] = { title = "Masteries", list = masteries, key = "mastery",
			count = ("%s points"):format(big(masteryTotal)) }
	end
	for _, g in ipairs(J.GROUPS) do
		local list = byGroup[g.key]
		if #list > 0 then
			local done = 0
			for _, a in ipairs(list) do
				if a.have >= a.need then
					done = done + 1
				end
			end
			out[#out + 1] = { title = g.title, list = list, done = done, key = g.key }
		end
	end
	return out
end

function V.DrawAchievements(kills, feats)
	local a = frame.achievements
	local account = ui().scope == "account"
	local accent = BT.Widgets.ACCENT
	local width = BT.Pill.Number(a.list.content:GetWidth(), WIDTH - PAD * 2 - 20)
	local y, ri, hi = 0, 0, 0
	for _, g in ipairs(V.Groups(kills, feats, account)) do
		hi = hi + 1
		local h = achHead(hi)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
		h:SetWidth(width)
		h.text:SetText(g.title:upper())
		-- the kinds and the masteries have no end to them: they say their points
		if g.count then
			h.count:SetText(g.count)
		else
			h.count:SetText(("%d / %d"):format(g.done, #g.list))
		end
		h:Show()
		y = y + HEAD_ROW_H
		for _, it in ipairs(g.list) do
			ri = ri + 1
			local r = achRow(ri)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
			r:SetWidth(width)
			local done = it.have >= it.need
			r.points:SetText(tostring(it.points))
			r.title:SetText(it.title)
			r.text:SetText(it.text)
			-- a mastery's name wears its metal
			local c = it.color
			if done then
				r.points:SetTextColor(accent[1], accent[2], accent[3])
				if c then
					r.title:SetTextColor(c[1], c[2], c[3])
				else
					r.title:SetTextColor(1, 1, 1)
				end
				r.right:SetText(it.right or (it.at and U.ShortDate(it.at)) or "earned")
				r.right:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.track:Hide()
				r.fill:Hide()
			elseif it.right then
				-- a tier nobody has reached yet: a count, not a bar
				r.points:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.title:SetTextColor(0.62, 0.66, 0.64)
				r.right:SetText(it.right)
				r.right:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.track:Hide()
				r.fill:Hide()
			else
				r.points:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.title:SetTextColor(0.62, 0.66, 0.64)
				r.right:SetText(("%s / %s"):format(big(it.have), big(it.need)))
				r.right:SetTextColor(0.75, 0.78, 0.77)
				r.track:SetColorTexture(1, 1, 1, 0.07)
				r.fill:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
				local share = math.min(1, it.have / it.need)
				r.track:Show()
				-- a texture of no width is drawn whole: an empty bar is no bar
				r.fill:SetShown(share > 0)
				r.fill:SetWidth(math.max(1, 90 * share))
			end
			r:Show()
			y = y + ACH_H
		end
	end
	for i = ri + 1, #a.rows do
		a.rows[i]:Hide()
	end
	for i = hi + 1, #a.heads do
		a.heads[i]:Hide()
	end
	a.list:SetContentHeight(y + 6)
end

-- ---------------------------------------------------------------------------
-- Drawing, opening, closing
-- ---------------------------------------------------------------------------

function V.Refresh()
	if not (frame and frame:IsShown()) then
		return false
	end
	local J = BT.Menagerie
	if not J.Store() then
		return false
	end
	local u = ui()
	frame.views:Select(u.view)
	frame.scopes:Select(u.scope)
	local kills, feats = J.Counts(u.scope)
	local all = u.scope == "account" and kills or J.Counts("account")
	local points, _, st = J.Points(kills, feats)
	local _, title = J.Rank(points)
	frame.subtitle:SetText(("%s · %s · %s kinds · %s kills · %s points"):format(
		u.scope == "account" and "all characters" or ((U.Me and U.Me()) or "this character"),
		title, big(st.kinds), big(st.total), big(points)))
	local bestiary = u.view ~= "achievements"
	frame.bestiary:SetShown(bestiary)
	frame.achievements:SetShown(not bestiary)
	frame.bestiary.dim:SetShown(bestiary and V.open ~= nil)
	if bestiary then
		V.DrawBestiary(kills, all)
	else
		V.DrawAchievements(kills, feats)
	end
	return true
end

-- a kill while it is open: drawn once for a burst of them, not once each
function V.Changed()
	if not (frame and frame:IsShown()) or V.pending then
		return
	end
	V.pending = true
	local function go()
		V.pending = nil
		V.Refresh()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, go)
	else
		go()
	end
end

-- open, on a mob or a view if one is named
function V.Show(npc, view)
	if not BT.Enabled("menagerie") then
		return false
	end
	BT.EnsureBound()
	V.Build()
	-- opened on a mob, its page; opened plainly, the cards, not whatever page
	-- was up when it was closed
	V.open = npc
	if npc then
		ui().view = "bestiary"
	elseif view then
		ui().view = view
	end
	frame:Show()
	frame:Raise()
	V.Refresh()
	return true
end

function V.Hide()
	if frame then
		frame:Hide()
	end
end

function V.IsShown()
	return frame and frame:IsShown() and true or false
end

function V.Toggle()
	if V.IsShown() then
		V.Hide()
		return false
	end
	return V.Show()
end

-- the tests reach in here
function V.Frame() return frame end
