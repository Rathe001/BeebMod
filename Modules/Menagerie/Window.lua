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
-- EVERY MOB'S CATEGORY, SHOWN (Josh 2026-09-27: "Make sure we are labeling
-- every mob with the correct new category"): the word is the journal's
-- (J.CATEGORIES), the colour the tooltips' for the ranks the client draws, a
-- boss's its own, and the everyday ones quiet
V.CATEGORY = {
	worldboss = { 1, 0.42, 0.32 },
	raidboss = { 0.80, 0.52, 1 },
	dungeonboss = { 1, 0.58, 0.26 },
	rareelite = { 0.85, 0.92, 1 },
	rare = { 0.78, 0.84, 0.90 },
	elite = { 1, 0.82, 0.30 },
	dungeonelite = { 0.90, 0.72, 0.40 },
	normal = { 0.58, 0.55, 0.48 },
	critter = { 0.50, 0.55, 0.53 },
}

-- a mob's category: its key, its word and its colour
function V.CategoryOf(m)
	local J = BT.Menagerie
	local key = J.Category(m)
	return key, J.CATEGORIES[key].word, V.CATEGORY[key]
end

-- the word in its colour, for a line of text
local function inColour(word, c)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5), word)
end

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
	frame.title:SetText("Nesingwary's Expedition")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

	frame.close = W.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() V.Hide() end)
	W.Divider(frame, PAD, -TITLE_H)

	frame.views = W.Segmented(frame, { { "bestiary", "Field Journal" }, { "achievements", "Commendations" } },
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
-- screenful does. The strip scrolls smoothly and a row part in view is drawn,
-- clipped at the grid's edge, its model with it (V.Deal, V.Crop).

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
-- FOUR ACROSS, WITH ROOM FOR THE BORDERS (Josh 2026-09-27: "The borders we
-- built are being cut off. I think we could do 4 per row, increase the
-- spacing between them a bit, and increase the size a bit"). The crest, the
-- corners and the pendant reach past the card (Card.Reach); the gaps and the
-- grid's margins are wide enough to hold them, so a card neither runs into
-- its neighbour nor is clipped at the grid's edge.
local COLS, GAP, ROW_GAP = 4, 30, 56
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
-- how far a card under the cursor rises (V.Zoom)
local LIFT = 4
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
	-- SEARCH (Josh 2026-09-27: "a search box that switches the filter to 'All'
	-- and does a search through all data. We should use lazy matching"): at
	-- the toolbar's right end; what it matches is J.Match's. A word is one
	-- search, not one a letter (the Ledger's lesson), and Escape or the cross
	-- empties it. Kept for the session, not saved.
	local search = CreateFrame("Frame", nil, box)
	search:SetSize(230, 22)
	search:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -6)
	W.Panel(search, W.FILL, W.HAIR)
	b.search = search
	local edit = CreateFrame("EditBox", nil, search)
	edit:SetPoint("TOPLEFT", 8, 0)
	edit:SetPoint("BOTTOMRIGHT", -22, 0)
	edit:SetAutoFocus(false)
	pcall(edit.SetFontObject, edit, "BeebModFontHighlightSmall")
	search.edit = edit
	search.hint = W.Label(search, "Search every mob", "small", DIM[1], DIM[2], DIM[3])
	search.hint:SetPoint("LEFT", 8, 0)
	search.clear = W.Close(search, 14)
	search.clear:SetPoint("RIGHT", -4, 0)
	search.clear:Hide()
	local pending = false
	local function apply()
		pending = false
		local text = edit:GetText() or ""
		V.query = text:find("%S") and text or nil
		search.hint:SetShown(text == "")
		search.clear:SetShown(text ~= "")
		b.grid:ScrollTo(0)
		V.Refresh()
	end
	edit:SetScript("OnTextChanged", function()
		if not (C_Timer and C_Timer.After) then
			apply()
			return
		end
		if not pending then
			pending = true
			C_Timer.After(0.12, apply)
		end
	end)
	edit:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	edit:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	search.clear:SetScript("OnClick", function()
		edit:SetText("")
		edit:ClearFocus()
	end)
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
	b.grid.step = Card.Height(math.floor((GRID_W - GAP * (COLS - 1)) / COLS)) + ROW_GAP
	-- every move of the strip deals the cards again
	local scrollTo = b.grid.ScrollTo
	b.grid.ScrollTo = function(self, y)
		local at = scrollTo(self, y)
		V.Deal()
		return at
	end
	-- GLIDING, AND AT REST ON A ROW (Josh 2026-09-27: "Scrolling gets into a
	-- state where only 1 row renders portraits"). A face part out of view was
	-- held back then, and a strip stopped anywhere had one whole row of
	-- faces between two half ones. So the strip moves smoothly but comes to
	-- rest with a row at its top: the wheel glides a row a notch, and a drag
	-- or a click in the gutter glides to the nearest row when it lets go.
	local GLIDE = 0.18
	function b.grid:Pitch()
		local L = b.layout
		return L and (L.h + L.rowGap) or self.step
	end
	function b.grid:Glide(to)
		to = math.max(0, math.min(self:Max(), to))
		local from, t = self.offset, 0
		self.gliding = to
		if not self.SetScript or math.abs(to - from) < 1 then
			self.gliding = nil
			self:ScrollTo(to)
			return
		end
		self:SetScript("OnUpdate", function(s, elapsed)
			t = t + (elapsed or 0)
			local k = math.min(1, t / GLIDE)
			k = 1 - (1 - k) ^ 3
			s:ScrollTo(from + (to - from) * k)
			if k >= 1 then
				s.gliding = nil
				s:SetScript("OnUpdate", nil)
			end
		end)
	end
	-- the row the strip is nearest, or would be after `rows` more
	function b.grid:RowOffset(rows)
		local p = math.max(1, self:Pitch())
		local at = self.gliding or self.offset
		return (math.floor(at / p + 0.5) + (rows or 0)) * p
	end
	b.grid:SetScript("OnMouseWheel", function(self, delta)
		self:Glide(self:RowOffset(-(delta or 0)))
	end)
	function b.grid:Settle()
		self:Glide(self:RowOffset(0))
	end
	b.cards = {}
	b.empty = W.Label(box, "No kills yet.\nEach new kind of mob you kill gets a card here.",
		"small", DIM[1], DIM[2], DIM[3])
	b.empty:SetPoint("CENTER", b.grid, "CENTER")
	-- a search that finds nothing says so, where the cards would be
	b.noMatch = W.Label(box, "", "small", DIM[1], DIM[2], DIM[3])
	b.noMatch:SetPoint("CENTER", b.grid, "CENTER")
	b.noMatch:Hide()
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
-- what it is, the whole model in a plain box with three numbers stacked
-- beside it, the mastery ladder at this mob's rank, and the lore, every page
-- of it, in a box of its own that scrolls.
-- ---------------------------------------------------------------------------
local MODAL_W, MODAL_H, MODAL_PAD = 480, 700, 16
local STAGE_Y, STAGE_H = 62, 220
-- THE NUMBERS BESIDE THE MOB (Josh 2026-09-27: "make the model area less
-- wide, and place the kills, points, and mastery vertically to the right of
-- it"): a column of three tiles as tall as the stage, and the row they took
-- under it goes to the lore
local STATS_W, TILE_GAP = 128, 8
local TILE_H = (STAGE_H - 2 * TILE_GAP) / 3
local LADDER_H, FOOT_H = 76, 34
-- the popup's own ground
local MODAL_BG = { 0.05, 0.07, 0.06 }

local function tile(parent, word)
	local W = BT.Widgets
	local t = CreateFrame("Frame", nil, parent)
	W.Panel(t, W.FILL, W.HAIR)
	t.label = W.Label(t, string.upper(word), "small", DIM[1], DIM[2], DIM[3])
	-- the word and its number, the pair in the middle of the tile
	t.label:SetPoint("TOP", 0, -math.max(8, math.floor((TILE_H - 34) / 2)))
	t.value = t:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	t.value:SetPoint("TOP", t.label, "BOTTOM", 0, -4)
	return t
end

-- THE LORE, SET OUT (Josh 2026-09-26: "We should have sub headings for the
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
	stage:SetSize(inner - STATS_W - TILE_GAP, STAGE_H)
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

	page.hint = W.Label(page, WORDS:format("Drag: turn · Right-drag: move · Wheel: zoom"), "small")
	page.hint:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -8)
	-- at the popup's right edge, under the numbers: the narrower stage has no
	-- room for the hint and the button side by side
	page.reset = W.Button(page, "Reset view", 84, 18)
	page.reset:SetPoint("TOPRIGHT", page, "TOPRIGHT", -MODAL_PAD, -(STAGE_Y + STAGE_H + 5))
	page.reset:SetScript("OnClick", function()
		V.ResetView(page.model)
	end)

	-- three numbers down the stage's right: its kills, what it is worth, the
	-- metal it has reached
	page.tiles = {}
	for i, word in ipairs({ "Kills", "Points", "Mastery" }) do
		local t = tile(page, word)
		t:SetSize(STATS_W, TILE_H)
		t:SetPoint("TOPRIGHT", page, "TOPRIGHT", -MODAL_PAD, -(STAGE_Y + (i - 1) * (TILE_H + TILE_GAP)))
		page.tiles[i] = t
	end
	page.kills, page.points, page.mastery = page.tiles[1], page.tiles[2], page.tiles[3]

	-- the ladder: the four metals at this mob's rank, the way to the next
	local ladderY = STAGE_Y + STAGE_H + 34
	local ladder = CreateFrame("Frame", nil, page)
	ladder:SetSize(inner, LADDER_H)
	ladder:SetPoint("TOPLEFT", MODAL_PAD, -ladderY)
	W.Panel(ladder, W.FILL, W.HAIR)
	page.ladder = ladder
	ladder.head = W.Label(ladder, string.upper("Mastery"), "small", DIM[1], DIM[2], DIM[3])
	ladder.head:SetPoint("TOPLEFT", 12, -9)
	-- NO "TO GO" (Josh 2026-09-27: "Remove this"): the ticks and the names
	-- under them say where the next metal is
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
		local x = 12 + rungW * (i - 0.5)
		local name = W.Label(ladder, "", "small")
		name:SetPoint("TOP", ladder, "TOPLEFT", x, -42)
		local need = W.Label(ladder, "", "small", DIM[1], DIM[2], DIM[3])
		need:SetPoint("TOP", name, "BOTTOM", 0, -2)
		-- A TICK WHERE EACH METAL IS (Josh 2026-09-27: "put ticks on the
		-- mastery bar where the different ranks are"): over the name, standing
		-- a little proud of the track on both sides, in the metal's colour
		local tick = ladder:CreateTexture(nil, "OVERLAY", nil, 2)
		tick:SetSize(2, 11)
		tick:SetPoint("CENTER", ladder.track, "LEFT", x - 12, 0)
		ladder.rungs[i] = { name = name, need = need, tick = tick }
	end

	-- the lore in full, in a place that scrolls: its own page, a tribe, a
	-- race and a type can run well past the popup's foot between them. No
	-- heading over it (Josh 2026-09-26: "Let's remove the "Lore" heading")
	local loreY = ladderY + LADDER_H + 12
	page.loreBox = W.Scroller(page, 6)
	page.loreBox:SetPoint("TOPLEFT", MODAL_PAD, -loreY)
	page.loreBox:SetPoint("BOTTOMRIGHT", -MODAL_PAD, FOOT_H + 6)
	page.loreBox.step = 48
	-- its pieces are made as a mob needs them (V.LorePiece)
	-- THE CREDIT ON THE SETTINGS PAGE (Josh 2026-09-28: "Let's move the credit
	-- line to the expedition's setting page. Should clean things up a bit").
	-- The Warcraft Wiki is credited once, on the Expedition's page
	-- (Modules/Menagerie/Menagerie.lua), not under every mob.
	page.loreBody = page.loreBox.content
	page.lorePieces = {}

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
	-- of it, under the quest's.
	-- The wiki's item links come through as "[Fel Moss]": the brackets go.
	f.loreLine = J.LoreLine(m)
	f.lore = {}
	for _, e in ipairs(J.WikiLore(m)) do
		-- a page borrowed from a mob with the same body is taken as fact
		-- (Josh 2026-09-26: "We should just assume it is a harpy if the
		-- model is the same"), headed like any other
		-- A HEADING WITHOUT THE WIKI'S TAG (Josh 2026-09-28, on "Timber Wolf
		-- (mob)"): the wiki tells its pages apart with "(mob)" or
		-- "(Darkshore)"; the heading is the name
		local head = #f.lore > 0 and (e.title:gsub("%s*%b()$", "")) or nil
		f.lore[#f.lore + 1] = { head = head, text = (e.text:gsub("%[(.-)%]", "%1")) }
	end
	local q = type(m.lore) == "table" and m.lore or nil
	if q and q.text then
		f.lore[#f.lore + 1] = { head = ("From the quest \"%s\""):format(q.quest or "?"), text = q.text }
	end
	if #f.lore == 0 then
		f.lore[1] = { text = f.loreLine }
	end
	-- EVERY PART, NOT UP TO THE FIRST GAP (Josh 2026-09-27: "The details dont
	-- have any indicator if the mob is rare or elite"). The parts were walked
	-- with ipairs, which stops at the first nil: a mob with no beast family -
	-- Mor'Ladim, any humanoid - lost its level, its rank and its zone. The rank
	-- wears the tooltips' colour, as it does in the list.
	-- the category now (J.Category), which says the rank and more
	local _, catWord, catColor = V.CategoryOf(m)
	local meta = {}
	-- a critter is not said to be a critter twice (Josh 2026-09-28, on a
	-- Sickly Deer: "Critter · Level 5 · Critter"), as in the list
	local cat = catWord ~= J.KindOf(m) and inColour(catWord, catColor) or nil
	local parts = { J.KindOf(m), m.family, level(m), cat, m.zone }
	for i = 1, 5 do
		if parts[i] then
			meta[#meta + 1] = parts[i]
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
-- `width` is the grid's whole width; the margins are the layout's own: the
-- list's plain EDGE, the cards' as far as their borders reach (and the lift
-- over the top)
function V.Layout(mobs, width, list)
	local cols = list and LIST_COLS or COLS
	local gap = list and LIST_GAP or GAP
	local rowGap = list and LIST_GAP or ROW_GAP
	local left, top, foot = EDGE, EDGE, EDGE
	if not list then
		-- the reach of a card as wide as the plain margin allows, which is no
		-- narrower than the one the wider margin leaves
		local reachTop, reachSide, reachFoot = Card.Reach(math.floor((width - 2 * EDGE - gap * (cols - 1)) / cols))
		left = math.max(EDGE, reachSide + 2)
		top = math.max(EDGE, reachTop + LIFT)
		foot = math.max(EDGE, reachFoot + 2)
	end
	local w = math.floor((width - 2 * left - gap * (cols - 1)) / cols)
	local ch = list and LIST_H or Card.Height(w)
	local rows, y = {}, top
	for i = 1, #mobs, cols do
		local items = {}
		for j = i, math.min(i + cols - 1, #mobs) do
			items[#items + 1] = mobs[j]
		end
		rows[#rows + 1] = { items = items, y = y, h = ch }
		y = y + ch + rowGap
	end
	return { rows = rows, w = w, h = ch, gap = gap, rowGap = rowGap, list = list, left = left, top = top,
		foot = foot, height = math.max(0, y - rowGap + foot) }
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
		-- a section picked is the end of a search, which is of All
		V.query = nil
		if b.search then
			b.search.edit:SetText("")
			b.search.edit:ClearFocus()
		end
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

-- FRAMED AGAIN ONCE IT HAS SETTLED (Josh 2026-09-27: "With the demo enabled,
-- most of the portraits are not loading"). The popup drew the same mobs whole,
-- so the models came; the faces were empty. The ones drawn were mobs met
-- lately, whose models the client already had and framed at once. A model
-- that arrives later is framed as it arrives, and on this client that does
-- not hold - so it is framed again a frame later and a moment after that,
-- while it is still the same mob.
local SETTLE = { 0, 0.3 }

-- THE MOB ASKED FOR, NOT THE ONE BEFORE (Josh 2026-09-27: "Some appear to be
-- using the wrong model" - Ragnaros's card wore the spider it had held). A
-- card is handed another mob as the strip scrolls, and a creature the client
-- has not loaded yet leaves the frame showing whatever it had. So the old
-- model is cleared first, and the mob asked for again a little later while
-- nothing has come - a creature the client had to send for arrives on a
-- later asking. `after` is run each time it is asked (the framing).
local ASK_AGAIN = { 0.5, 1.5, 4 }

local function loaded(model)
	if type(model.GetModelFileID) ~= "function" then
		return true
	end
	local ok, id = pcall(model.GetModelFileID, model)
	return ok and type(id) == "number" and id > 0
end

function V.Creature(model, npc, after)
	model.npc = npc
	pcall(model.ClearModel, model)
	pcall(model.SetCreature, model, npc)
	if not (C_Timer and C_Timer.After) then
		return
	end
	for _, t in ipairs(ASK_AGAIN) do
		C_Timer.After(t, function()
			if model.npc == npc and not loaded(model) then
				pcall(model.SetCreature, model, npc)
				if after then
					after(model)
				end
			end
		end)
	end
end

local function settle(model)
	frameFace(model)
	if not (C_Timer and C_Timer.After) then
		return
	end
	local npc = model.npc
	for _, t in ipairs(SETTLE) do
		C_Timer.After(t, function()
			if model.npc == npc and model:IsShown() then
				frameFace(model)
			end
		end)
	end
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
		settle(model)
	end
end

-- A FACE AT THE GRID'S EDGE (Josh 2026-09-27: "Can we render 3 rows instead
-- of 2 so the models don't flash in?"). Cut to the view with SetViewInsets,
-- a face did not lose its outside part: the client fitted the whole face into
-- what was left ("Scrolling causes the bottom row to resize strangely"). So
-- a face part out of view was held back until it was wholly in.
-- DRAWN WHOLE, THE GRID CLIPS IT (Josh 2026-09-28, when that became the only
-- way: "We need the portrait functionality back... portraits go missing on
-- scroll again"). A face with any of itself in view is drawn whole, and the
-- grid's edge clips it, as the "show" setting did on this client. `over` and
-- `under` are how much of a face `tall` high is above and below the view.
-- Whether it is to be shown.
function V.Crop(model, over, under, tall)
	return over + under < tall
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
		settle(self)
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
		V.Creature(c.portrait, e.npc, settle)
		settle(c.portrait)
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
	local _, catWord, catColor = V.CategoryOf(e.m)
	Card.Dress(c, {
		npc = e.npc, name = e.m.name or ("#" .. e.npc), rank = e.m.rank,
		kind = V.TypeLine(e.m), category = catWord, categoryColor = catColor, lore = J.LoreLine(e.m),
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
		settle(self)
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
	r.pointsLabel = W.Label(r, string.upper("Pts"), "small", DIM[1], DIM[2], DIM[3])
	r.pointsLabel:SetPoint("TOP", r.points, "BOTTOM", 0, -3)
	r.kills = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(r.kills.SetFont, r.kills, Card.FONT_NAME, 13, "")
	r.kills:SetPoint("TOPRIGHT", r, "TOPRIGHT", -52, -7)
	r.tier = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(r.tier.SetFont, r.tier, Card.FONT_TYPE, 11, "")
	r.tier:SetPoint("TOPRIGHT", r.kills, "BOTTOMRIGHT", 0, -3)
	r.name:SetPoint("RIGHT", r.kills, "LEFT", -10, 0)
	-- the type line stops short of the mastery word under the kills, which is
	-- wider than the number ("World BossPLATINUM", Josh 2026-09-27)
	r.kind:SetPoint("RIGHT", r.tier, "LEFT", -8, 0)
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
		V.Creature(r.face, e.npc, settle)
		settle(r.face)
		learnBody(r.face)
	end
	r.name:SetText(e.m.name or ("#" .. e.npc))
	-- the rank in words as well as the edge (Josh 2026-09-26: "List view
	-- doesn't show rare/elite mob indicators"), in the tooltip's colour
	-- THE CATEGORY FIRST (Josh 2026-09-27): a long type line is cut at the
	-- row's end, and the category is what matters most, so it leads - and a
	-- critter is not said to be a critter twice
	local line = V.TypeLine(e.m)
	local catKey, catWord, catColor = V.CategoryOf(e.m)
	if catKey == "critter" then
		line = line:gsub("^Critter · ", "")
	end
	r.kind:SetText(("%s · %s"):format(inColour(catWord, catColor), line))
	r.kills:SetText(big(e.n))
	r.points:SetText(big(J.MobPoints(e.m, e.n)))
	local tier = J.Mastery(e.n, e.m)
	local metal = Card.TIERS[tier]
	local mc = metal.color
	r.tier:SetText(string.upper(tier == 0 and "Kills" or metal.name))
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
	for _, c in pairs(b and b.cards or {}) do
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
	-- A STRIP THAT SCROLLS (Josh 2026-09-27: "Rather than actually scrolling a
	-- rendered list of items, it seems to only ever show 2 rows at a time").
	-- Every row with any of itself in view is drawn, and the grid's edge clips
	-- the card and the face on it (V.Crop). A face wholly out of view is put
	-- away until it comes back in, and framed again when it does.
	-- Each row of the strip keeps the same cards for as long as it is in view
	-- - a card is its row's place in a ring of rows, not its place on the
	-- screen - so scrolling moves models rather than loading them afresh.
	local ring = math.floor(room / math.max(1, L.h + L.rowGap)) + 2
	local cols = L.list and LIST_COLS or COLS
	local faceTop, faceH
	if L.list then
		faceTop, faceH = (LIST_H - LIST_FACE) / 2, LIST_FACE
	else
		local _, wy, _, wh = Card.Window(L.w)
		faceTop, faceH = wy, wh
	end
	local used, n = {}, 0
	for ri, row in ipairs(L.rows) do
		if row.y + row.h + L.foot > top and row.y - L.top < bottom then
			-- how much of the face is above the view and below it
			local over = math.max(0, math.floor(top - (row.y + faceTop) + 0.5))
			local under = math.max(0, math.floor(row.y + faceTop + faceH - bottom + 0.5))
			local function place(model)
				return V.Crop(model, over, under, faceH)
			end
			for col, e in ipairs(row.items) do
				local ci = ((ri - 1) % ring) * cols + col
				used[ci] = true
				n = n + 1
				local x = L.left + (col - 1) * (L.w + L.gap)
				if L.list then
					local r = listRow(ci)
					bindRow(r, e, L.w)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", grid.content, "TOPLEFT", x, -row.y)
					r:Show()
					-- where it is decides whether it is behind the popup
					cover(r.face, not place(r.face) or (open and V.UnderStage(r.face)))
				else
					local c = card(ci)
					bind(c, e, L.w)
					c.entry = e
					c.slotX = x + L.w / 2
					c.slotY = row.y + L.h / 2
					V.PlaceCard(c)
					c:Show()
					cover(c.portrait, not place(c.portrait) or (open and V.UnderStage(c.portrait)))
				end
			end
		end
	end
	-- the other kind put away entirely, and what is left of this one (the
	-- ring can leave gaps in the pools, so every one is walked)
	for i, c in pairs(b.cards) do
		if L.list or not used[i] then
			c:Hide()
		end
	end
	for i, r in pairs(b.rows or {}) do
		if not L.list or not used[i] then
			r:Hide()
		end
	end
	return n
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
	-- a search is of every mob: the rail goes to All while there is one
	local query = V.query
	if query then
		u.pick = u.pick or {}
		u.pick[u.group] = V.ALL
	end
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
	-- the matches, the best first
	if query then
		mobs = J.Search(mobs, query)
	end
	b.noMatch:SetText(query and ("No mob matches \"%s\"."):format(query) or "")
	b.noMatch:SetShown(query ~= nil and #mobs == 0 and #pages > 0)
	-- the popup steps through these
	V.mobs, V.picked = mobs, picked
	b.layout = V.Layout(mobs, GRID_W, u.layout == "list")
	-- a row of whichever it is: the wheel glides a row a notch (b.grid.Glide),
	-- and a click in the gutter goes a window's height less this
	b.grid.step = b.layout.h + b.layout.rowGap
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
		V.Creature(page.model, npc, V.Stand)
		learnBody(page.model)
		-- a new mob opens on the client's own framing
		V.ResetView(page.model)
	end
	page.name:SetText(f.name)
	local c = f.color or { 1, 1, 1 }
	page.name:SetTextColor(c[1], c[2], c[3])
	page.meta:SetText(f.meta)

	page.kills.value:SetText(big(f.n))
	page.kills.label:SetText(string.upper(f.allN > f.n and ("Kills · %s in all"):format(big(f.allN)) or "Kills"))
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
		-- a metal reached is a bright tick, one ahead a dim one
		rung.tick:SetColorTexture(m.color[1], m.color[2], m.color[3], i <= f.tier and 1 or 0.45)
		rung.tick:Show()
	end
	local track = MODAL_W - 2 * MODAL_PAD - 24
	local nxt = f.nxt
	local k = V.LadderShare(f.tier, f.n, here and here.n, nxt and nxt.n, #L.rungs)
	local fc = (here or nxt).color
	L.fill:SetWidth(math.max(1, math.floor(track * k + 0.5)))
	L.fill:SetColorTexture(fc[1], fc[2], fc[3], 1)
	L.fill:SetShown(k > 0)

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

-- THE WHOLE LADDER, NOT THE NEXT RUNG (Josh 2026-09-27: "The mastery progress
-- bar doesn't seem to be working"). It measured from the metal reached to the
-- next, so a mob that had just reached Gold showed an empty bar under a lit
-- Gold. Now it runs under the four names: filled to the middle of each metal
-- earned, and on toward the next by the share of the kills between them.
-- `tier` metals reached of `rungs`, `n` kills, `from` the kills the last
-- reached took (nil for none), `to` the next one's (nil when all are earned).
-- A share of the track, 0 to 1.
function V.LadderShare(tier, n, from, to, rungs)
	rungs = rungs or 4
	if not to then
		return 1
	end
	local at = tier > 0 and (tier - 0.5) / rungs or 0
	local nextAt = (tier + 0.5) / rungs
	local k = (n - (from or 0)) / math.max(1, to - (from or 0))
	return at + math.max(0, math.min(1, k)) * (nextAt - at)
end

-- a mob's popup, from its card (or a toast); a card lifted under the
-- cursor is set down first, or it would stand over the dimming
function V.Open(npc)
	V.open = npc
	ui().view = "bestiary"
	for _, c in pairs(frame and frame.bestiary.cards or {}) do
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
	-- ALL, EARNED OR STILL TO DO (Josh 2026-09-27: "We might actually need a
	-- 'Complete' and 'Incomplete' and 'All' tab"), and how many are earned
	local showLabel = W.Label(a, "Show", "small", DIM[1], DIM[2], DIM[3])
	showLabel:SetPoint("TOPLEFT", 10, -TOOLBAR_Y - 4)
	a.shows = W.Segmented(a, { { "all", "All" }, { "done", "Earned" }, { "todo", "In progress" } }, function(key)
		ui().achShow = key
		a.list:ScrollTo(0)
		V.Refresh()
	end, 80)
	a.shows:SetPoint("LEFT", showLabel, "RIGHT", 8, 0)
	a.tally = W.Label(a, "", "small", DIM[1], DIM[2], DIM[3])
	a.tally:SetPoint("LEFT", a.shows, "RIGHT", 18, 0)
	W.Divider(a, 8, -TOOLBAR_H)
	a.list = W.Scroller(a, 6)
	a.list:SetPoint("TOPLEFT", 6, -TOOLBAR_H - 6)
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
	-- EARNED, AT A GLANCE (Josh 2026-09-27: "make the achievements I already
	-- earned more apparent"): an earned row is lit, with the accent down its
	-- left edge and a tick by its points
	r.lit = r:CreateTexture(nil, "BACKGROUND")
	r.lit:SetAllPoints()
	r.edge = r:CreateTexture(nil, "ARTWORK")
	r.edge:SetPoint("TOPLEFT", 0, -1)
	r.edge:SetPoint("BOTTOMLEFT", 0, 0)
	r.edge:SetWidth(3)
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
	-- the tick, before the date it was earned
	r.check = r:CreateTexture(nil, "OVERLAY")
	r.check:SetSize(14, 14)
	r.check:SetPoint("RIGHT", r.right, "LEFT", -5, 0)
	pcall(r.check.SetTexture, r.check, "Interface\\RaidFrame\\ReadyCheck-Ready")
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
			text = ("%s kills of one normal mob, %s of an elite, %s of a rare or %s of a world boss, worth %d points each")
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
			text = ("Kill it %s times"):format(big(nx.need)),
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
	local show = ui().achShow or "all"
	a.shows:Select(show)
	local groups = V.Groups(kills, feats, account)
	-- the milestones earned of all there are (the kinds and the masteries'
	-- summaries are tallies, not things to earn)
	local earned, all = 0, 0
	for _, g in ipairs(groups) do
		if not g.count then
			earned, all = earned + g.done, all + #g.list
		end
	end
	a.tally:SetText(("%d of %d commendations earned"):format(earned, all))
	local y, ri, hi = 0, 0, 0
	for _, g in ipairs(groups) do
		-- what this view keeps of the group; a group left empty is not headed
		local list = {}
		for _, it in ipairs(g.list) do
			local done = it.have >= it.need
			if show == "all" or (show == "done") == done then
				list[#list + 1] = it
			end
		end
		if #list > 0 then
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
			for _, it in ipairs(list) do
				ri = ri + 1
				local r = achRow(ri)
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
				r:SetWidth(width)
				local done = it.have >= it.need
				r.points:SetText(tostring(it.points))
				r.title:SetText(it.title)
				r.text:SetText(it.text)
				-- earned: lit, edged and ticked
				r.lit:SetColorTexture(accent[1], accent[2], accent[3], 0.07)
				r.lit:SetShown(done)
				r.edge:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
				r.edge:SetShown(done)
				r.check:SetShown(done)
				-- a mastery's name wears its metal
				local c = it.color
				if done then
					r.points:SetTextColor(accent[1], accent[2], accent[3])
					if c then
						r.title:SetTextColor(c[1], c[2], c[3])
					else
						r.title:SetTextColor(1, 1, 1)
					end
					r.right:SetText(it.right or (it.at and U.ShortDate(it.at)) or "Earned")
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
	frame.subtitle:SetText(("%s · %s · %s %s · %s %s · %s %s"):format(
		u.scope == "account" and "All characters" or ((U.Me and U.Me()) or "This character"),
		title, big(st.kinds), st.kinds == 1 and "kind" or "kinds", big(st.total), st.total == 1 and "kill" or "kills",
		big(points), points == 1 and "point" or "points"))
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
