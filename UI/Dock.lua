-- The dock: the toolkit's only permanent presence on screen, and the thing you
-- actually use while playing (Josh 2026-09-19).
--
-- ONE PANEL, NOT THREE. It started as a bar; then the quest tracker turned up
-- with a panel of its own, in the same skin, floating a few hundred pixels
-- away. Two panels that look identical and move separately are two things to
-- arrange every time you touch your UI. So this is one: a row of cells along
-- the top, and under it whatever sections the modules have to show.
--
--   BT.Dock.Cell(key, w)         a cell on the row - a target, a dot, a way in
--   BT.Dock.Section(key, order)  a panel of your own underneath it
--
-- The dock owns where it sits, how big it is and what it is wearing; a module
-- owns what goes inside its own section and how tall that is. Nothing in here
-- knows what a quest is.
--
-- IT GROWS WITH WHAT YOU SWITCH ON. With everything off it is a small mark
-- that opens the window, and with everything on it is:
--
--   [class] [ who you are pointing at ]      [ ••• ] [cog]
--   [ what you wrote about them                          ]
--
-- A cell says which line it is on (`line`), which end it hangs from (`side`),
-- and whether it stretches across whatever is left (`stretch`).
--
-- Cells appear and disappear rather than text reflowing, so the dock changes in
-- steps you can predict instead of sliding about. A cell declares its own
-- width: asking a frame how wide it is before it has been drawn is how the
-- layout used to end up a pile on top of itself.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Dock.lua")

local U = BT.Util
local B = {}
BT.Dock = B

local ICONS = "Interface\\AddOns\\BeebMod\\Art\\icons"
-- the sheet is EIGHT slots wide; these pick one. Written out rather than
-- unpacked from a table: `unpack` is a global in the game's Lua and a member of
-- `table` in the one the headless tests run (Josh 2026-09-19).
function B.NoteCoord(tex) tex:SetTexCoord(0, 0.125, 0, 1) end
function B.ChartCoord(tex) tex:SetTexCoord(0.25, 0.375, 0, 1) end
function B.CheckCoord(tex) tex:SetTexCoord(0.375, 0.5, 0, 1) end
function B.CogCoord(tex) tex:SetTexCoord(0.5, 0.625, 0, 1) end
function B.CrossCoord(tex) tex:SetTexCoord(0.75, 0.875, 0, 1) end
function B.PencilCoord(tex) tex:SetTexCoord(0.875, 1, 0, 1) end
-- open points down, folded points up: one glyph, flipped
function B.ChevronCoord(tex, folded)
	if folded then
		tex:SetTexCoord(0.625, 0.75, 1, 0)
	else
		tex:SetTexCoord(0.625, 0.75, 0, 1)
	end
end
B.ICONS = ICONS

-- TWO LINES, BOTH ALWAYS THERE (Josh 2026-09-19). Who you are pointing at is
-- one line; their tags and your note are the line under it. That second line
-- keeps its height whether or not anything is on it, because a dock that grows
-- a row when you happen to point at somebody you have written about is a dock
-- that shoves the quest log down the screen while you are reading it.
-- TIGHT (Josh 2026-09-19). Every one of these came down once the dock had two
-- lines in it: a header that is mostly air reads as a widget, and this is
-- meant to read as part of the tracker under it.
local BAR_H, MARKS_H, PAD = 22, 14, 5
-- THE ROW HAS EDGES (Josh 2026-09-19). Cells started at x=0, which is where
-- the spine is: the class icon was jammed against the border with all its air
-- on the other side. Everything on the row sits this far in from both ends.
local INSET = 5
-- tall enough for a name and a cog, and no taller: this is a title, not a
-- toolbar (Josh 2026-09-21)
local HEADER_H = 20
-- CENTRED ON THE GAP, NOT ON THE BAND (Josh 2026-09-19). Both lines were
-- centred in their own band, which is not the same thing as looking centred:
-- the name is 12px of text in a 22px band and the note is 10px in a 14px one,
-- so the air between them came to seven pixels and the air under the note to
-- two. The second line rides up by this much, and the two gaps even out.
local LINE2_LIFT = 3
local savePosition -- MakeHandle needs it, and it is written further down
B.PAD = PAD
local MIN_W = 34
-- ONE WIDTH, WHATEVER IS IN IT (Josh 2026-09-24: "quest log seems to make
-- the right panel wider"). The dock was as wide as its widest part, so the
-- quest list's 230 made it jump when the tracker came and went - and without
-- it the dock shrank until the XP line and the Ledger's prompt were cut off.
-- It is a width of its own now, a setting, and everything in it follows.
-- Never under 200: the narrowest the XP line, the readouts and the prompt
-- all fit.
B.WIDTH, B.WIDTH_MIN, B.WIDTH_MAX, B.WIDTH_STEP = 230, 200, 320, 10
local dock, cells, row, sections, ordered, rowWidth

function B.SetCellWidth(c, w)
	c.cellWidth = w
	c:SetWidth(w)
end

-- Every cell is the same shape: a frame, a hairline on its left, and whatever
-- it holds. Building them this way is what makes the layout a loop rather than
-- a pile of anchors.
-- No dividers between cells. They were there when the row was six cells long
-- and read as one strip; with a class icon, a name and a cog they were a line
-- between a picture and the name of the thing in it (Josh 2026-09-19).
local function cell(key, width)
	local c = CreateFrame("Frame", nil, row)
	c:SetHeight(BAR_H - 2)
	B.SetCellWidth(c, width or 20)
	c.cellKey = key
	return c
end
B.Cell = cell

-- An icon cell that opens the window on one tab: the two ways in that modules
-- keep asking for, made once.
function B.WayIn(key, coord, view, tip)
	local c = cell(key, 22)
	c.button = CreateFrame("Button", nil, c)
	c.button:SetAllPoints()
	c.icon = c.button:CreateTexture(nil, "ARTWORK")
	c.icon:SetPoint("CENTER")
	c.icon:SetSize(12, 12)
	c.icon:SetTexture(ICONS)
	coord(c.icon)
	c.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
	c.button:SetScript("OnClick", function()
		BT.Window.Show(view)
	end)
	c.button:SetScript("OnEnter", function()
		-- lit by hand, not through W.Tint: that REGISTERS the glyph, and the
		-- next theme change would repaint it lit while nobody was pointing at it
		local a = BT.Widgets.ACCENT
		c.icon:SetVertexColor(a[1], a[2], a[3], 1)
		-- the dock's own tooltip (Josh 2026-09-27): its name, and its click
		if tip and BT.Tip then
			BT.Tip.Show(c, { build = function(t)
				t:Header({ icon = false, name = tip })
				t:Foot({ { "Click", ("open the %s"):format(tip:lower()) } })
			end })
		end
	end)
	c.button:SetScript("OnLeave", function()
		c.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	c.wanted = true
	return c
end

-- EVERYTHING IN THE DOCK TAKES THE MOUSE (Josh 2026-09-19). The row is cells
-- you click and the tracker is quests you click, so there is no bare panel
-- left to grab: the dock could only be dragged from a few pixels of edge.
-- Anything can be a handle for it instead, and the mark and the tracker's own
-- header both are.
--
-- IT SHRINKS AS IT GOES DOWN (Josh 2026-09-23). The dock is held on the screen,
-- and since it fills the room under its top edge exactly, its bottom already
-- touches the screen's: the client refused to let it be dragged any lower at
-- all. While it is being dragged it is laid out again as it moves, so the
-- quests give up the room and scroll.
--
-- AND ONLY THE BOTTOM GIVES (the same evening). Letting it off the screen
-- altogether let it off every edge - it slid off the right and read as a
-- dock getting narrower. The client's clamp takes an inset per edge, so the
-- top and both sides stay held while it is dragged, and only the bottom may
-- pass the screen's edge, by the whole of the dock, for the layout to take
-- back. Let go, the insets are nothing again.
local DRAG_STEP = 0.05

-- LOCKED WHERE IT IS (Josh 2026-09-24): a drag that means to move a quest or
-- scroll the list no longer takes the whole dock with it
function B.Locked()
	return BT.settings and BT.settings.dockLocked == true or false
end

function B.BeginDrag()
	if not (dock and dock.StartMoving) or B.Locked() then
		return
	end
	local h = BT.Pill.Number(dock:GetHeight(), 0)
	if dock.SetClampRectInsets then
		dock:SetClampRectInsets(0, 0, 0, math.max(0, h))
	end
	dock:SetClampedToScreen(true)
	dock:StartMoving()
	-- ONLY WHEN THE ROOM CHANGED (Josh 2026-09-23, audit): moving sideways
	-- changes nothing the layout depends on, and it was laid out twenty times
	-- a second all the same - every cell, every quest row, every rule
	local since, room = 0, B.Room()
	dock:SetScript("OnUpdate", function(_, elapsed)
		since = since + (elapsed or 0)
		if since >= DRAG_STEP then
			since = 0
			local now = B.Room()
			if now ~= room then
				room = now
				B.Relayout()
			end
		end
	end)
	dock.dragging = true
end

function B.EndDrag()
	if not dock or B.Locked() then
		return
	end
	dock:SetScript("OnUpdate", nil)
	dock:StopMovingOrSizing()
	dock.dragging = false
	savePosition()
	-- a new top edge is a new amount of room under it
	B.Relayout()
	if dock.SetClampRectInsets then
		dock:SetClampRectInsets(0, 0, 0, 0)
	end
	dock:SetClampedToScreen(true)
end

function B.MakeHandle(child)
	if not (child and child.RegisterForDrag) then
		return child
	end
	child:RegisterForDrag("LeftButton")
	child:SetScript("OnDragStart", function()
		B.BeginDrag()
	end)
	child:SetScript("OnDragStop", function()
		B.EndDrag()
	end)
	return child
end

-- WHOEVER YOU ARE POINTING AT, IN THE FIRST SLOT (Josh 2026-09-19). The mark
-- is the toolkit's own glyph until you target a player, and then it is their
-- class - the one thing about a stranger this client will actually tell us.
-- Not their spec: nothing reveals a stranger's talents here, which is the same
-- reason the census has no spec chart.
function B.SetMark(texture, coords, tint)
	if not (dock and dock.mark and dock.mark.icon) then
		return
	end
	local icon = dock.mark.icon
	if texture then
		-- not the theme's any more: its accent is for the toolkit's glyph,
		-- and a class icon tinted with it was the wrong class colour
		BT.Widgets.Untint(icon)
		icon:SetTexture(texture)
		if coords then
			icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
		local t = tint or { 1, 1, 1, 1 }
		icon:SetVertexColor(t[1], t[2], t[3], t[4] or 1)
	else
		icon:SetTexture(ICONS)
		B.NoteCoord(icon)
		BT.Widgets.Tint(icon)
	end
end

function B.Tip(frame, build)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
	GameTooltip:ClearLines()
	build()
	GameTooltip:Show()
end

-- Lay out whichever cells have something to say, left to right, and remember
-- how wide that came out: the dock is as wide as its widest part, and asking a
-- frame its width before it has been drawn is not arithmetic.
-- Has any MODULE asked for a place on the row? The mark and the cog belong to
-- the core and are not a reason to draw a row: with the Ledger switched off
-- they were a glyph and a cog sitting in a band of their own above the quest
-- list, which is chrome for nothing.
local function moduleCells()
	for _, c in ipairs(cells) do
		if c ~= dock.mark and c ~= dock.cog and c.wanted then
			return true
		end
	end
	return false
end

-- And does anything want the second line? With nothing that could ever go on
-- it, reserving its height is reserving room for nobody.
local function wantsMarks()
	for _, c in ipairs(cells) do
		if c.line == 2 then
			return true
		end
	end
	return false
end

local function layout()
	local top, marks, right = INSET, INSET, INSET
	-- the right-hand end first, and backwards: the last cell in the list is
	-- the one furthest right, so the cog stays at the end whatever a module
	-- hangs beside it
	for i = #cells, 1, -1 do
		local c = cells[i]
		if c == dock.cog then
			-- placed by Relayout, in the header: it takes no room on the row.
			-- Counting its width here left a cog-sized gap at the right end of
			-- the row and a dock that much wider than its content
		elseif c.side == "right" and c.wanted then
			c:ClearAllPoints()
			c:SetPoint("TOPRIGHT", row, "TOPRIGHT", -right, -1)
			c:SetHeight(BAR_H - 2)
			c:Show()
			right = right + (c.cellWidth or 0)
		end
	end
	for _, c in ipairs(cells) do
		if c.side == "right" then
			if not c.wanted then
				c:Hide()
			end
		elseif c.wanted then
			local second = c.line == 2
			c:ClearAllPoints()
			c:SetHeight((second and MARKS_H or BAR_H) - 2)
			if c.stretch then
				-- across whatever is left, and counting for nothing in the
				-- width: a note is as long as it is and must not decide how
				-- wide the dock gets. `indent` lets it start under something
				-- on the line above rather than at the panel's edge.
				local x = second and (c.indent or INSET) or top
				local y = second and -(BAR_H - LINE2_LIFT) or -1
				c:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
				c:SetPoint("TOPRIGHT", row, "TOPRIGHT", -INSET, y)
			else
				c:SetPoint("TOPLEFT", row, "TOPLEFT", second and marks or top,
					second and -(BAR_H - LINE2_LIFT) or -1)
				if second then
					marks = marks + (c.cellWidth or 0)
				else
					top = top + (c.cellWidth or 0)
				end
			end
			c:Show()
		else
			c:Hide()
		end
	end
	rowWidth = math.max(MIN_W, top + right + 2, marks + INSET)
	B.Relayout()
end

-- EACH BAND IN ITS OWN ROW'S COLOUR (Josh 2026-09-26: "you added the same
-- background color to all of these. Can we make them look different so they
-- are easier to find at a glance?"). A meter says the colour of its bar -
-- Experience the accent, Reputation its standing, the Expedition its ink -
-- and its band is a faint wash of the same, so each row is known by colour
-- before it is read. No colour said, a faint lightening.
local BAND_ALPHA, PLAIN_ALPHA = 0.11, 0.045

function B.PaintBand(f)
	local band = f and f.beebsBand
	if not band then
		return
	end
	local c = f.beebsBandColor
	if c then
		band:SetColorTexture(c[1], c[2], c[3], BAND_ALPHA)
	else
		band:SetColorTexture(1, 1, 1, PLAIN_ALPHA)
	end
end

-- A SHIELD AT THE START OF EACH LINE (Josh 2026-09-29): the Expedition's
-- rank badge, and to line up with it a shield for Level, with your level on
-- it, and one for reputation, with a banner. Only the shield is drawn: the
-- art leaves room round it for the higher ranks' antlers and tusks. It
-- reaches from the text's top to the bar's foot; the text and the bar start
-- after it (B.LineAfter).
B.LINE_ICON_W, B.LINE_ICON_H, B.LINE_ICON_GAP = 17, 23, 6
B.LINE_ICON_CROP = { 0.25, 0.75, 0.2, 0.875 }
B.SHIELD_FIELD = "Interface\\AddOns\\BeebMod\\Art\\Dock\\field"
B.SHIELD_RIM = "Interface\\AddOns\\BeebMod\\Art\\Dock\\rim"
B.SHIELD_BANNER = "Interface\\AddOns\\BeebMod\\Art\\Dock\\banner"
B.SHIELD_SWORDS = "Interface\\AddOns\\BeebMod\\Art\\Dock\\swords"

-- one layer of a line's shield, at the line's top left; `sub` orders layers
function B.LineIcon(f, inset, sub, file)
	local t = f:CreateTexture(nil, "ARTWORK", nil, sub or 0)
	t:SetSize(B.LINE_ICON_W, B.LINE_ICON_H)
	t:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -3)
	local c = B.LINE_ICON_CROP
	t:SetTexCoord(c[1], c[2], c[3], c[4])
	if file then
		t:SetTexture(file)
	end
	return t
end

-- a shield of the dock's own, the field tinted by the caller: the field, the
-- rim over it, and a mark over that if one is given
function B.LineShield(f, inset, mark)
	local s = {}
	s.field = B.LineIcon(f, inset, 1, B.SHIELD_FIELD)
	s.rim = B.LineIcon(f, inset, 2, B.SHIELD_RIM)
	if mark then
		s.mark = B.LineIcon(f, inset, 3, mark)
	end
	s.icon = s.field
	return s
end

-- a number on a line's shield, such as your level (Josh 2026-09-29: "put the
-- number level inside the icon - it would save some room")
B.SHIELD_FONT = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\JosefinSans-Bold.ttf"
function B.LineNumber(f, s)
	local n = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	pcall(n.SetFont, n, B.SHIELD_FONT, 10, "")
	n:SetPoint("CENTER", s.icon, "CENTER", 0, 1)
	n:SetJustifyH("CENTER")
	n:SetTextColor(1, 1, 1)
	if n.SetShadowColor then
		n:SetShadowColor(0, 0, 0, 0.9)
		n:SetShadowOffset(1, -1)
	end
	s.number = n
	return n
end

-- where a line's text and bar start, once a shield is at its left
function B.LineAfter(icon, text, track, textH)
	text:SetPoint("TOPLEFT", icon, "TOPRIGHT", B.LINE_ICON_GAP, 0)
	track:SetPoint("TOPLEFT", icon, "TOPRIGHT", B.LINE_ICON_GAP, -textH)
end

-- how wide a line's bar is, with a shield at its left
function B.LineBarWidth(f, inset)
	return BT.Pill.Number(f:GetWidth(), 0) - inset * 2 - B.LINE_ICON_W - B.LINE_ICON_GAP
end

-- a meter's colour, whenever its bar is painted
function B.BandColor(f, c)
	if not f then
		return
	end
	local was = f.beebsBandColor
	if was and c and was[1] == c[1] and was[2] == c[2] and was[3] == c[3] then
		return
	end
	f.beebsBandColor = c and { c[1], c[2], c[3] } or nil
	B.PaintBand(f)
end

-- THE DOCK AT ITS SMALLEST (Josh 2026-09-27: "the bare minimum, if every
-- module is disabled, should be the dock with logo and options cog. You
-- should not be able to turn off that minimum state. Turning off the dock
-- would turn off everything EXCEPT the logo and options cog"). With the Dock
-- switched off nothing else sits in it - no row, no section, no readout, no
-- Census icon, whatever feature it belongs to - and the header stays.
function B.DockOn()
	return not BT.FeatureOn or BT.FeatureOn("dock")
end

function B.RowWanted()
	if not (dock and cells) then
		return false
	end
	return B.DockOn() and (not (BT.settings and BT.settings.targetRow == false)) and moduleCells()
end

-- A PANEL OF YOUR OWN, UNDER THE ROW. Give it the height and width it would
-- like in `wantHeight` and `wantWidth`, show or hide it, and call Relayout.
function B.Section(key, order)
	B.Create()
	local s = sections[key]
	if not s then
		s = { key = key, order = order or 50, frame = CreateFrame("Frame", nil, dock) }
		s.frame.key = key
		s.frame:Hide()
		sections[key] = s
		ordered[#ordered + 1] = s
		table.sort(ordered, function(a, b) return a.order < b.order end)
	end
	return s.frame
end

-- Stack the row and whatever sections are showing, and make the dock the size
-- of the result. The row hides when the target row is switched off; the dock itself
-- goes only when there is nothing left in it at all.
-- THE DOCK IN YOUR ORDER (Josh 2026-09-22). A section belongs to the module of
-- the same key, and the modules are in whatever order you dragged the tabs
-- into - so the sections stack in that order too. A section with no module
-- behind it keeps the number it asked for, after the ones that have one.
local function sortSections()
	local rank = {}
	for i, m in ipairs((BT.Modules and BT.Modules()) or {}) do
		rank[m.key] = i
	end
	table.sort(ordered, function(a, b)
		local ra = rank[a.key] or (1000 + a.order)
		local rb = rank[b.key] or (1000 + b.order)
		if ra ~= rb then
			return ra < rb
		end
		return a.order < b.order
	end)
end

-- ---------------------------------------------------------------------------
-- Readouts (Josh 2026-09-22, the panel redesign: "B, readout grid")
-- ---------------------------------------------------------------------------
--
-- THREE KINDS OF THING. The panel holds panels (the map, the quests, the
-- row), meters (a name, a bar, a time) and readouts - one small number each:
-- gold, bag space, durability, frame rate, latency, a rogue's pockets, a
-- class's reagents. Each readout used to take a full-width line of its own,
-- with its own way of saying label and value; four of them cost more height
-- than both bars together.
--
-- A readout is a CELL now: an icon, a value, and a state - plain, "warn"
-- (soon) or "alert" (now) - with its module's hover and click. The dock lays
-- every wanted cell out three across in one group, in module order, and puts
-- the group where the first of those modules is in your order.
local chips, chipIndex = {}, {}
local CHIP_H, COLS = 18, 3
-- THREE ACROSS, OR TWO (Josh 2026-09-24): two gives each readout room to
-- breathe on a narrow dock
function B.Cols()
	return (BT.settings and BT.settings.metricsCols == 2) and 2 or COLS
end
-- a row is its cell and the one-pixel line under it; the column lines stop
-- this far short of the lines above and below the grid
local ROW_H, COLUMN_GAP = CHIP_H + 1, 2
local CHIP_TEXT = { 0.86, 0.88, 0.92 }
local CHIP_STATE = { warn = { 0.95, 0.78, 0.35 }, alert = { 0.95, 0.40, 0.35 } }

-- what a cell shows, as one comparable string; nil when it cannot be said
-- (a secret in it), in which case the cell is simply painted
function B.SpecKey(s)
	if type(s) ~= "table" then
		return nil
	end
	local text = s.text
	if issecretvalue and issecretvalue(text) then
		return nil
	end
	local t, c = s.tint, s.coords
	return table.concat({
		tostring(s.icon), tostring(text), tostring(s.state),
		t and ("%s,%s,%s,%s"):format(t[1], t[2], t[3], tostring(t[4])) or "-",
		c and ("%s,%s,%s,%s"):format(c[1], c[2], c[3], c[4]) or "-",
	}, "|")
end

local function paintChip(c)
	local s = c.spec or {}
	-- A PIXEL LOW (Josh 2026-09-24): a line of figures has no descenders, and
	-- centred by its box it read a pixel high in every row of the grid
	local drop = -(BT.Pill.PixelOf(c) or 1)
	if s.icon then
		c.icon:SetTexture(s.icon)
		if s.coords then
			c.icon:SetTexCoord(s.coords[1], s.coords[2], s.coords[3], s.coords[4])
		else
			-- a game icon's own border cropped off, so it reads at twelve pixels
			c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local t = s.tint
		if t then
			c.icon:SetVertexColor(t[1], t[2], t[3], t[4] or 1)
		else
			c.icon:SetVertexColor(1, 1, 1, 1)
		end
		c.icon:Show()
		c.text:ClearAllPoints()
		c.text:SetPoint("LEFT", c.icon, "RIGHT", 4, drop)
	else
		c.icon:Hide()
		c.text:ClearAllPoints()
		c.text:SetPoint("LEFT", c, "LEFT", 1, drop)
	end
	c.text:SetPoint("RIGHT", c, "RIGHT", -2, drop)
	c.text:SetText(s.text or "")
	local col = CHIP_STATE[s.state or ""] or CHIP_TEXT
	c.text:SetTextColor(col[1], col[2], col[3])
end

-- A readout cell, one per (module, id): made once, filled in with :Set.
-- `order` places it among its own module's cells. A WIDE one (Josh
-- 2026-09-29: "The performance/latency metrics should be grouped together
-- instead of individual cells") has a row of its own, under the others.
function B.Chip(owner, id, order, wide)
	B.Create()
	local key = owner .. ":" .. tostring(id)
	if chipIndex[key] then
		return chipIndex[key]
	end
	local grid = B.Section("readouts", 50)
	local c = CreateFrame("Button", nil, grid)
	c:SetHeight(CHIP_H)
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(12, 12)
	c.icon:SetPoint("LEFT", c, "LEFT", 1, 0)
	c.text = BT.Widgets.Label(c, "", "small")
	c.text:SetJustifyH("LEFT")
	c.text:SetWordWrap(false)
	c.owner, c.id, c.order = owner, id, order or 0
	c.wide = wide and true or false
	c.wanted = false
	c:Hide()
	-- spec = { icon, coords, tint, text, state }
	-- ONLY WHEN SOMETHING CHANGED (Josh 2026-09-23, audit): the tickers set
	-- the same speed, the same gold, the same frame rate over and over, and
	-- each Set re-anchored and re-coloured the cell
	c.Set = function(self, spec)
		self.spec = spec
		local key = B.SpecKey(spec)
		if key and key == self.painted then
			return
		end
		self.painted = key
		paintChip(self)
	end
	-- whether it has anything to say: a cell nobody wants takes no place
	c.Want = function(self, on)
		on = on and true or false
		if on ~= self.wanted then
			self.wanted = on
			if dock then
				B.Relayout()
			end
		end
	end
	chips[#chips + 1] = c
	chipIndex[key] = c
	-- the whole panel drags by anything in it, the cells included
	B.MakeHandle(c)
	return c
end

-- where the cells go, three across; returns the rank the group sits at
local function layoutChips(width, rank)
	local COLS = B.Cols()
	local s = sections and sections.readouts
	if not s then
		return nil
	end
	local grid = s.frame
	local shown = {}
	for _, c in ipairs(chips) do
		if c.wanted and B.DockOn() and BT.Enabled(c.owner) and BT.ClassFits(BT.GetModule(c.owner)) then
			shown[#shown + 1] = c
		else
			c:Hide()
		end
	end
	-- a part of Metrics goes where Metrics is; among themselves, in module
	-- order, and a module's own cells in the order it gave them
	local function groupRank(owner)
		local m = BT.GetModule(owner)
		return rank[(m and m.part) or owner] or 999
	end
	table.sort(shown, function(a, b)
		local ga, gb = groupRank(a.owner), groupRank(b.owner)
		if ga ~= gb then
			return ga < gb
		end
		-- parts keep a fixed order: they have no tabs to drag
		local ma, mb = BT.GetModule(a.owner), BT.GetModule(b.owner)
		local ra = (ma and ma.part) and ma.order or rank[a.owner] or 999
		local rb = (mb and mb.part) and mb.order or rank[b.owner] or 999
		if ra ~= rb then
			return ra < rb
		end
		return a.order < b.order
	end)
	if #shown == 0 then
		grid:Hide()
		return nil
	end
	grid:Show()
	-- EVERY ROW THE SAME (Josh 2026-09-24). The cells began two units down and
	-- the lines ran along their edges, so the first row had two units more
	-- above its text than the others and the last two more below it, over the
	-- dock's own line - the frame rate and latency read high. A row is now
	-- its cell and the line under it (the last row's is the dock's), and every
	-- edge is on a whole screen pixel, so no line is smeared across two.
	local px = BT.Pill.PixelOf(grid) or 1
	local function edge(n)
		return B.Snap(n * ROW_H)
	end
	local cw = (width - INSET * 2) / COLS
	-- the cells three across, then each wide one on a row of its own
	local narrow, wide = {}, {}
	for _, c in ipairs(shown) do
		local into = c.wide and wide or narrow
		into[#into + 1] = c
	end
	for i, c in ipairs(narrow) do
		local col, rowN = (i - 1) % COLS, math.floor((i - 1) / COLS)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", grid, "TOPLEFT", INSET + col * cw, -edge(rowN))
		c:SetWidth(cw - 2)
		c:SetHeight(edge(rowN + 1) - px - edge(rowN))
		c:Show()
	end
	local narrowRows = math.ceil(#narrow / COLS)
	for i, c in ipairs(wide) do
		local rowN = narrowRows + i - 1
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", grid, "TOPLEFT", INSET, -edge(rowN))
		c:SetWidth(width - INSET * 2 - 2)
		c:SetHeight(edge(rowN + 1) - px - edge(rowN))
		c:Show()
	end
	local rows = narrowRows + #wide
	grid.wantHeight = edge(rows)
	grid:SetHeight(grid.wantHeight)
	-- A GRID YOU CAN SEE (Josh 2026-09-22). The dividers were there at half
	-- the rule's strength, which on this fill is nothing at all. They are the
	-- same rule every section ends on now: one between columns, as tall as
	-- the rows that are there, and one between rows.
	grid.lines = grid.lines or {}
	for n = 1, COLS - 1 do
		local line = grid.lines[n]
		if not line then
			line = grid:CreateTexture(nil, "ARTWORK")
			line:SetWidth(1)
			BT.Widgets.Rule(line, nil, "v")
			grid.lines[n] = line
		end
		line:ClearAllPoints()
		local gap = B.Snap(COLUMN_GAP)
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", math.floor(INSET + n * cw - 4), -gap)
		-- only as far down as the rows of three go
		line:SetHeight(math.max(1, edge(narrowRows) - px - gap * 2))
		line:SetShown(#narrow > n)
	end
	grid.rowLines = grid.rowLines or {}
	for r = 1, math.max(rows - 1, #grid.rowLines) do
		local line = grid.rowLines[r]
		if not line then
			line = grid:CreateTexture(nil, "ARTWORK")
			line:SetHeight(1)
			BT.Widgets.Rule(line, nil, "h")
			grid.rowLines[r] = line
		end
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", 4, -(edge(r) - px))
		line:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -4, -(edge(r) - px))
		line:SetShown(r < rows)
	end
	-- the group sits where the first of its modules is in your order
	local first = 999
	for _, c in ipairs(shown) do
		first = math.min(first, groupRank(c.owner))
	end
	return first
end

-- Something a module puts in the header, right to left from its right edge:
-- the clock.
function B.HeaderItem(frame)
	B.Create()
	dock.headerItems = dock.headerItems or {}
	for _, f in ipairs(dock.headerItems) do
		if f == frame then
			return frame
		end
	end
	frame:SetParent(dock.header)
	dock.headerItems[#dock.headerItems + 1] = frame
	return frame
end

-- the Census icon is in the header while the Census is on, unless you left
-- it out (its charts are still at /bt census and on its page)
local function censusInHeader()
	return BT.Enabled and BT.Enabled("census") and B.DockOn() and not (BT.settings and BT.settings.censusButton == false)
		or false
end

-- HOW WIDE THE HEADER NEEDS TO BE (Josh 2026-09-24). The dock was as wide as
-- its row or its widest section, and never less than a sliver; with the
-- Census alone there is neither, and the panel shrank to 34 pixels behind
-- "Beeb" while "Mod", the icon and the cog hung off it over the world. The
-- name, what sits beside it and whatever is at the right-hand end all fit.
local function headerNeed()
	local title = BT.Pill.Number(dock.header.title:GetStringWidth(), 52)
	local w = INSET + 1 + title + 4
	if dock.census and censusInHeader() then
		w = w + 22
	end
	if dock.cog then
		w = w + (dock.cog.cellWidth or 22)
	end
	for _, f in ipairs(dock.headerItems or {}) do
		if f:IsShown() then
			w = w + 4 + BT.Pill.Number(f:GetWidth(), 0)
		end
	end
	return math.ceil(w + INSET)
end

function B.Relayout()
	if not dock then
		return
	end
	sortSections()
	local wantRow = B.RowWanted()
	-- the dock's own width; only a row or a header that could not fit in it
	-- (a setting narrower than its cells) makes it wider
	local width, live = math.max(B.Width(), rowWidth or MIN_W, MIN_W), false
	local dockOn = B.DockOn()
	for _, s in ipairs(ordered) do
		-- the Dock off: every section away, whoever's it is
		if not dockOn and s.key ~= "readouts" then
			s.frame:Hide()
		end
		if s.frame:IsShown() and s.key ~= "readouts" then
			live = true
		end
	end
	width = math.max(width, headerNeed())
	local chipRank
	do
		local rank = {}
		for i, m in ipairs((BT.Modules and BT.Modules()) or {}) do
			rank[m.key] = i
		end
		chipRank = layoutChips(width, rank)
		if chipRank then
			live = true
		end
	end
	local y = 0
	local rowTall = BAR_H + (wantsMarks() and MARKS_H or 0)

	-- the header is the top of the stack, above everything, always
	dock.header:ClearAllPoints()
	dock.header:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
	dock.header:SetWidth(width)
	dock.header:Show()
	y = y + HEADER_H

	-- EVERYTHING UNDER THE HEADER IN YOUR ORDER (Josh 2026-09-22). The minimap
	-- used to sit above the row whatever the tabs said, and the row itself was
	-- pinned second, so dragging either tab moved nothing. The row is the
	-- Ledger's - its cells are who you are pointing at and what you wrote - so
	-- it takes the Ledger's place, and every section takes its module's.
	local rank = {}
	for i, m in ipairs((BT.Modules and BT.Modules()) or {}) do
		rank[m.key] = i
	end
	local stack = {}
	if wantRow then
		stack[#stack + 1] = { row = true, rank = rank.ledger or 0 }
	end
	for i, s in ipairs(ordered) do
		if s.frame:IsShown() then
			local r = rank[s.key] or (1000 + s.order)
			if s.key == "readouts" then
				r = chipRank or r
			end
			stack[#stack + 1] = { s = s, rank = r, i = i, kind = s.frame.kind }
		end
	end
	table.sort(stack, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return (a.i or 0) < (b.i or 0)
	end)

	-- HOW TALL EACH PIECE WANTS TO BE, and then what it gets. The row keeps
	-- its height; a section keeps what it asked for, unless the whole dock
	-- would run off the bottom of the screen (see B.Room).
	for _, item in ipairs(stack) do
		item.tall = item.row and rowTall or (item.s.frame.wantHeight or 0)
	end
	B.Squeeze(stack, HEADER_H, B.Room())

	row:SetShown(wantRow)
	-- A LINE UNDER EACH, EXCEPT THE LAST (Josh 2026-09-22). Each section used
	-- to draw its own, so the quests had none and the frame rate kept one even
	-- at the bottom of the panel. The dock knows which is last; it draws them.
	for n, item in ipairs(stack) do
		local f, rule
		local tall = item.tall
		if item.row then
			f, rule = row, dock.marksRule
		else
			f = item.s.frame
			if not f.beebsRule then
				f.beebsRule = f:CreateTexture(nil, "ARTWORK")
				f.beebsRule:SetHeight(1)
				f.beebsRule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 0)
				f.beebsRule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 0)
				BT.Widgets.Rule(f.beebsRule, nil, "h")
			end
			rule = f.beebsRule
		end
		f:ClearAllPoints()
		-- on whole screen pixels, top and bottom, so the line at its bottom
		-- is one pixel and not a unit smeared across two
		local top, bottom = B.Snap(y), B.Snap(y + tall)
		f:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, -top)
		f:SetWidth(width)
		-- as tall as the room it was given, so its line is at its bottom
		f:SetHeight(bottom - top)
		item.y = y
		y = y + tall
		-- a line under every section but the last; the two meters were once
		-- left without one between them, and read as one bar with two labels
		if rule then
			rule:SetShown(n < #stack)
		end
		-- A BAND BEHIND EACH METER (Josh 2026-09-26: "anything we can do to
		-- make these rows look more distinct? Maybe a subtle background?").
		-- Experience, Reputation and the Expedition sat flush on one fill, the
		-- hairline between them too fine to part them; each now sits on a
		-- faint lightened strip, inset from the panel's edge and from the
		-- line under it, so three rows read as three.
		if f and not item.row then
			if item.kind == "meter" and not f.beebsBand then
				f.beebsBand = f:CreateTexture(nil, "BACKGROUND")
				f.beebsBand:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -1)
				f.beebsBand:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 2)
				B.PaintBand(f)
			end
			if f.beebsBand then
				f.beebsBand:SetShown(item.kind == "meter")
			end
		end
	end
	B.stack = stack
	-- a section that was given less than it asked for is told how much it
	-- got, so it can scroll what no longer fits. It must not lay the dock
	-- out again from in here.
	for _, item in ipairs(stack) do
		local f = item.s and item.s.frame
		if f and f.Fit then
			pcall(f.Fit, f, item.tall)
		end
	end
	-- (not every rule in the addon, measured again on every layout, as it
	-- was: a rule is measured when it is made, and again when the scale
	-- changes - see the watcher in UI/Widgets.lua and B.SetScale)
	-- A HOLE UNDER A SEE-THROUGH MAP (Josh 2026-09-22). A section can ask for
	-- the dock's background to leave a rectangle clear (`hole`, in its own
	-- coordinates) - the minimap does while it is faded, so the world shows
	-- through it rather than the panel's own dark fill.
	local hole
	for _, item in ipairs(stack) do
		local want = item.s and item.s.frame.hole
		if want then
			hole = {
				left = want.x,
				top = item.y + want.y,
				right = width - want.x - want.w,
				bottom = item.y + want.y + want.h,
			}
		end
	end
	BT.Pill.SetHole(dock, hole)
	-- THE HEADER (Josh 2026-09-22): the name, then the Census icon when it is
	-- on and the cog, left to right beside it; whatever a module puts in the
	-- header (the clock) sits at the right edge. The cog used to hold that
	-- edge, but a time reads best where the eye ends a line, and the ways in
	-- belong with the name that says whose panel this is.
	local prev = dock.header.title
	if dock.census then
		dock.census:ClearAllPoints()
		dock.census:SetPoint("LEFT", prev, "RIGHT", 4, 0)
		-- its button can be left out of the header, the charts kept (Josh
		-- 2026-09-24): /bt census and the Census page still open them
		local on = censusInHeader()
		dock.census:SetShown(on)
		if on then
			prev = dock.census
		end
	end
	if dock.cog then
		dock.cog:ClearAllPoints()
		dock.cog:SetParent(dock.header)
		dock.cog:SetPoint("LEFT", prev, "RIGHT", prev == dock.header.title and 4 or 0, 0)
		dock.cog:Show()
	end
	local right
	for _, f in ipairs(dock.headerItems or {}) do
		if not dockOn then
			f:Hide()
		end
		if f:IsShown() then
			f:ClearAllPoints()
			if right then
				f:SetPoint("RIGHT", right, "LEFT", -4, 0)
			else
				f:SetPoint("RIGHT", dock.header, "RIGHT", -INSET, 0)
			end
			right = f
		end
	end
	if dock.mark then
		dock.mark:SetShown(wantRow)
	end
	dock:SetSize(B.Snap(width), B.Snap(math.max(BAR_H, y)))
	if dock.marksRule and not wantRow then
		dock.marksRule:Hide()
	end
	-- a clock or the census icon in the header is something to show too:
	-- the dock went with the last panel module, clock and all, and with it
	-- the cog that is the way into the settings (Josh 2026-09-23, audit)
	-- THE CENSUS ON ITS OWN (Josh 2026-09-24): its icon is a way in as much
	-- as the clock is, and the census alone is a way to use the addon - the
	-- name, the icon and the cog, and nothing under them
	-- ALWAYS THERE (Josh 2026-09-27): the logo and the cog are the way back
	-- in, whatever is switched off, and nothing switches them off
	dock:Show()
end

-- THE DOCK STOPS AT THE BOTTOM OF THE SCREEN (Josh 2026-09-23). It grows
-- downwards from its top edge, and with a long quest list and a map it ran
-- off the bottom of the screen - where the client then shoved the whole dock
-- UP to keep it on, so the top you had placed it at was no longer its top.
--
-- The room is the distance from the dock's top edge to the bottom of the
-- screen. GetTop is in the dock's own units, the same units as every height
-- here, so no scale arithmetic is needed; the screen's height stands in
-- before the dock has been placed.
--
-- ALL THE WAY DOWN (Josh 2026-09-23): there was a four-unit gap left under
-- it, which on a dock dragged to the bottom corner was a strip of world
-- showing beneath the panel. The dock stops at the screen's edge itself.
local BOTTOM_GAP = 0

function B.Room()
	if not dock then
		return nil
	end
	local top = BT.Pill.Number(dock.GetTop and dock:GetTop(), nil)
	if not top or top <= 0 then
		top = BT.Pill.Number(UIParent and UIParent.GetHeight and UIParent:GetHeight(), nil)
	end
	if not top or top <= 0 then
		return nil
	end
	return math.max(HEADER_H + BAR_H, top - BOTTOM_GAP)
end


-- Take what does not fit out of the sections that can scroll (`shrinks`),
-- first in the stack first, never below the `minHeight` each one names.
-- Everything else keeps its height: a map or a row of readouts cut short is
-- a map or a row of readouts with a piece missing. Pure arithmetic on the
-- stack's `tall`, so the tests can drive it.
function B.Squeeze(stack, above, room)
	if not room then
		return 0
	end
	local total = above or 0
	for _, item in ipairs(stack) do
		total = total + (item.tall or 0)
	end
	local excess = total - room
	if excess <= 0 then
		return 0
	end
	local given = 0
	for _, item in ipairs(stack) do
		local f = item.s and item.s.frame
		if excess <= 0 then
			break
		end
		if f and f.shrinks then
			local floor = math.min(item.tall, f.minHeight or 0)
			local give = math.min(excess, item.tall - floor)
			if give > 0 then
				item.tall = item.tall - give
				excess = excess - give
				given = given + give
			end
		end
	end
	return given
end

-- Ask every enabled module what it wants on the dock, in module order. Called
-- again whenever a module is switched on or off, so the dock is never showing a
-- cell belonging to something that is no longer running.
function B.Rebuild()
	if not dock then
		return
	end
	for _, c in ipairs(cells) do
		c:Hide()
		c.wanted = false
	end
	cells = { dock.mark }
	for _, m in ipairs(BT.Live()) do
		if m.Cells then
			local ok, list = pcall(m.Cells, m)
			if ok and type(list) == "table" then
				for _, c in ipairs(list) do
					cells[#cells + 1] = c
				end
			end
		end
	end
	cells[#cells + 1] = dock.cog -- always last: it is the way out of everything
	B.Update()
end

function B.Update()
	if not dock then
		return
	end
	for _, c in ipairs(cells) do
		if c.Update then
			c:Update()
		end
	end
	layout()
end

-- ANCHORED BY ITS TOP, ALWAYS (Josh 2026-09-19). Dragging a frame leaves it
-- anchored by whichever corner the client felt like, and half the time that is
-- a BOTTOM one - so folding the quest list away made the dock shorter and the
-- whole thing slid DOWN the screen, because the bottom is what was pinned.
-- The top-left corner is worked out in the screen's own coordinates and saved
-- as a TOPLEFT anchor, so growing and shrinking only ever moves the bottom.
-- ON THE PIXEL GRID (Josh 2026-09-22). A border one screen pixel wide is
-- snapped edge by edge, so on a panel that starts halfway between two screen
-- pixels its left side came out two wide while the others were one. The
-- panel's corner and size are rounded to whole screen pixels, which puts all
-- four edges on the grid. `v` is in the panel's own units.
function B.Snap(v)
	if not (v and dock and dock.GetEffectiveScale and type(GetPhysicalScreenSize) == "function") then
		return v
	end
	local ok, _, h = pcall(GetPhysicalScreenSize)
	local scale = BT.Pill.Number(dock:GetEffectiveScale(), 0)
	if not (ok and tonumber(h) and h > 0 and scale > 0) then
		return v
	end
	local pixel = 768 / h / scale
	return math.floor(v / pixel + 0.5) * pixel
end

function savePosition()
	if not (dock and BT.settings) then
		return
	end
	local num = BT.Pill.Number
	local scale = num(dock.GetEffectiveScale and dock:GetEffectiveScale(), 1)
	local parent = num(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale(), 1)
	local left = num(dock.GetLeft and dock:GetLeft(), nil)
	local topEdge = num(dock.GetTop and dock:GetTop(), nil)
	local parentTop = num(UIParent.GetTop and UIParent:GetTop(), nil)
	if not (left and topEdge and parentTop and scale > 0) then
		-- no geometry to work with: keep whatever the client says it is on
		local point, _, rel, x, y = dock:GetPoint()
		if point then
			BT.settings.dockPos = { point = point, rel = rel, x = x, y = y }
		end
		return
	end
	BT.settings.dockPos = {
		point = "TOPLEFT",
		rel = "TOPLEFT",
		x = B.Snap(left),
		y = B.Snap((topEdge * scale - parentTop * parent) / scale),
	}
	dock:ClearAllPoints()
	dock:SetPoint("TOPLEFT", UIParent, "TOPLEFT", BT.settings.dockPos.x, BT.settings.dockPos.y)
end

local function restorePosition()
	-- THE CLIENT ALREADY PUT IT BACK (Josh 2026-09-21). A dragged frame with a
	-- name is written into the client's own layout data, and that is read back
	-- at every login - Logs/AccountData.log shows BeebModDock in it, at
	-- exactly where it was left. Saved variables are what this client fails to
	-- load, and dockPos lives in them: it came from a stale baked copy and put
	-- the panel back where it had been two days earlier, over the top of the
	-- client's correct answer. When the client has placed it, that stands.
	if dock.IsUserPlaced and dock:IsUserPlaced() and dock:GetPoint() then
		savePosition()
		return
	end
	local pos = BT.settings and BT.settings.dockPos
	-- a position saved by an older build may be anchored by a BOTTOM corner,
	-- which is the bug this fixed; rather than restore it and have the dock
	-- slide about once more, it goes back to the default and the next drag
	-- writes a top anchor
	if pos and pos.point and not pos.point:find("TOP") then
		pos = nil
	end
	dock:ClearAllPoints()
	if pos and pos.point then
		dock:SetPoint(pos.point, UIParent, pos.rel or pos.point, B.Snap(pos.x or 0), B.Snap(pos.y or 0))
	else
		-- under the minimap, hard against the right edge: where a tracker has
		-- lived in every version of this game, and where there is nothing else
		-- to fight with. Drag it anywhere and that is remembered instead.
		dock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -285)
	end
end

function B.Create()
	if dock then
		return dock
	end
	dock = CreateFrame("Button", "BeebModDock", UIParent)
	dock:SetSize(120, BAR_H)
	dock:SetFrameStrata("MEDIUM")
	dock:SetMovable(true)
	dock:EnableMouse(true)
	B.WatchFade()
	dock:RegisterForDrag("LeftButton")
	dock:RegisterForClicks("AnyUp")
	dock:SetClampedToScreen(true)
	cells, sections, ordered, rowWidth = {}, {}, {}, MIN_W
	row = CreateFrame("Frame", nil, dock)
	row:SetPoint("TOPLEFT")
	row:SetSize(MIN_W, BAR_H + MARKS_H)
	-- a hairline under the two lines, so the dock reads as a header over
	-- whatever sections are beneath it
	dock.marksRule = dock:CreateTexture(nil, "ARTWORK")
	dock.marksRule:SetHeight(1)
	dock.marksRule:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 4, 0)
	dock.marksRule:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", -4, 0)
	BT.Widgets.Rule(dock.marksRule, nil, "h")

	-- THE PANEL SAYS WHOSE IT IS (Josh 2026-09-21). The dock had no header:
	-- it began with a row of target cells, so the first thing you read was a
	-- piece of the Ledger rather than the panel itself. A header gives the
	-- stack a top, gives the cog somewhere that is not a corner, and gives
	-- the whole thing a handle that does not disappear when the row is
	-- switched off - which is what left a lone cog floating before.
	dock.header = CreateFrame("Button", nil, dock)
	dock.header:SetHeight(HEADER_H)
	dock.header:RegisterForDrag("LeftButton")
	B.MakeHandle(dock.header)
	dock.header.title = dock.header:CreateFontString(nil, "OVERLAY", "BeebModFontNormal")
	dock.header.title:SetPoint("LEFT", INSET + 1, 0)
	-- the same name the window wears
	dock.header.title:SetText("|cff74c0fcBeeb|rMod")
	dock.headerRule = dock:CreateTexture(nil, "ARTWORK")
	dock.headerRule:SetHeight(1)
	dock.headerRule:SetPoint("TOPLEFT", dock.header, "BOTTOMLEFT", 4, 0)
	dock.headerRule:SetPoint("TOPRIGHT", dock.header, "BOTTOMRIGHT", -4, 0)
	BT.Widgets.Rule(dock.headerRule, nil, "h")

	BT.Widgets.Panel(dock)
	-- the tooltip's drop shadow, so the panel stands off the world the same
	-- way (Josh 2026-09-22)
	BT.Widgets.Shadow(dock)
	-- THE ACCENT IS GONE (Josh 2026-09-21). A three-pixel stripe ran down the
	-- dock's left edge, written when the toolkit's green was the only colour
	-- it had. Painting it the border colour was not enough: it is four pixels
	-- of border on one side of a panel whose other three are one, which reads
	-- as a panel drawn wrong rather than as an accent. The border is a
	-- setting now and it is the same the whole way round.

	-- the mark, which is the whole dock when nothing else is switched on
	local mark = cell("mark", 20)
	mark.wanted = true
	mark.button = CreateFrame("Button", nil, mark)
	mark.button:SetAllPoints()
	mark.icon = mark.button:CreateTexture(nil, "ARTWORK")
	mark.icon:SetPoint("CENTER", 1, 0)
	mark.icon:SetSize(13, 13)
	mark.icon:SetTexture(ICONS)
	B.NoteCoord(mark.icon)
	BT.Widgets.Tint(mark.icon)
	mark.button:SetScript("OnClick", function() BT.Window.Toggle() end)
	mark.Update = function(self) self.wanted = true end
	B.MakeHandle(mark.button)
	dock.mark = mark

	-- ONE WAY IN, NOT THREE (Josh 2026-09-19). The row used to carry a
	-- magnifier and a chart, one per module, which meant every new utility
	-- wanted its own icon and the bar grew a toolbar. The window has tabs for
	-- that. What belongs out here is the way to the settings.
	dock.cog = B.WayIn("cog", B.CogCoord, "settings", "Settings")
	dock.cog.side = "right" -- the way out of everything lives at the end
	dock.cog.inHeader = true
	-- parented to the DOCK rather than to the row, because it outlives it: with
	-- every utility that puts cells on the row switched off, the row goes and
	-- the cog moves to the corner (Josh 2026-09-19)
	dock.cog:SetParent(dock)

	-- THE CENSUS, FROM THE HEADER (Josh 2026-09-22). It left the window's rail
	-- for a window of its own, and this is the way into it: the chart glyph,
	-- beside the cog, drawn and lit the same way. Only while it is switched on.
	dock.census = CreateFrame("Button", nil, dock.header)
	dock.census:SetSize(22, 22)
	dock.census.icon = dock.census:CreateTexture(nil, "ARTWORK")
	dock.census.icon:SetPoint("CENTER")
	dock.census.icon:SetSize(12, 12)
	dock.census.icon:SetTexture(ICONS)
	B.ChartCoord(dock.census.icon)
	dock.census.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
	dock.census:SetScript("OnClick", function()
		if BT.CensusWindow then
			BT.CensusWindow.Toggle()
		end
	end)
	dock.census:SetScript("OnEnter", function(self)
		local a = BT.Widgets.ACCENT
		self.icon:SetVertexColor(a[1], a[2], a[3], 1)
		if BT.Tip then
			local census = BT.Feature and BT.Feature("census")
			BT.Tip.Show(self, { edge = census and census.color, build = function(t)
				t:Header({ icon = false, name = "Census", sub = "Everyone you have seen on this realm" })
				t:Foot({ { "Click", "open the census" } })
			end })
		end
	end)
	dock.census:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	dock:SetScript("OnDragStart", function()
		B.BeginDrag()
	end)
	dock:SetScript("OnDragStop", function()
		B.EndDrag()
	end)
	-- and a new screen size or interface scale is a new amount of room too
	dock.screen = CreateFrame("Frame")
	for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
		pcall(dock.screen.RegisterEvent, dock.screen, event)
	end
	dock.screen:SetScript("OnEvent", function()
		B.Relayout()
	end)
	dock:SetScript("OnClick", function(_, click)
		if click == "RightButton" then
			BT.Window.Toggle("settings")
		end
	end)

	restorePosition()
	if BT.settings and BT.settings.dockScale then
		dock:SetScale(BT.settings.dockScale)
	end
	-- the border is whole screen pixels at the scale it is drawn at
	BT.Pill.RepaintAll()
	B.Rebuild()
	B.Relayout()
	return dock
end

-- The Target row switch hides the row only: the dock stays for whatever else is in it.
function B.SetShown(show)
	if not dock then
		return
	end
	if BT.settings then
		BT.settings.targetRow = show and true or false
	end
	B.Relayout()
end

function B.SetScale(n)
	BT.EnsureBound()
	BT.settings.dockScale = n
	if dock then
		-- THE CORNER STAYS PUT (Josh 2026-09-23, audit): a position is in the
		-- dock's own scaled units, so a new scale slid it across the screen
		-- by a twentieth of its distance from the edge at every click
		local num = BT.Pill.Number
		local e0 = num(dock:GetEffectiveScale(), 0)
		local l, t = num(dock:GetLeft(), nil), num(dock:GetTop(), nil)
		dock:SetScale(n)
		local e1 = num(dock:GetEffectiveScale(), 0)
		if l and t and e0 > 0 and e1 > 0 then
			dock:ClearAllPoints()
			dock:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * e0 / e1, t * e0 / e1)
			savePosition()
		end
		-- its rules and its border are screen pixels at the old scale
		BT.Pill.RepaintAll()
		BT.Widgets.Hairlines()
		B.Relayout()
	end
end

-- how wide the dock is, as a setting (B.WIDTH)
function B.Width()
	local w = BT.settings and tonumber(BT.settings.dockWidth)
	if not w then
		return B.WIDTH
	end
	return math.max(B.WIDTH_MIN, math.min(B.WIDTH_MAX, w))
end

function B.SetWidth(n)
	BT.EnsureBound()
	n = math.max(B.WIDTH_MIN, math.min(B.WIDTH_MAX, math.floor(n + 0.5)))
	BT.settings.dockWidth = n ~= B.WIDTH and n or nil
	B.Relayout()
	return n
end

function B.Scale()
	return (BT.settings and BT.settings.dockScale) or 1
end

function B.Frame() return dock end

function B.Row() return row end
function B.Header() return dock and dock.header end
function B.Cog() return dock and dock.cog end
function B.Sections() return ordered or {} end
function B.Cells() return cells end

-- ---------------------------------------------------------------------------
-- Tooltips, clear of the dock
-- ---------------------------------------------------------------------------
--
-- THE CORNER IS OURS (Josh 2026-09-24: "it is pretty difficult to see
-- tooltips over top of the right bar"). A tooltip with nowhere of its own to
-- go - a unit in the world, most of the time - goes to the client's default
-- spot, the bottom-right corner, which is where the dock stands: its words
-- over the quest list's. Placed there by the client, it is moved left until
-- its right edge is clear of the dock, at the height the client chose.
B.TIP_GAP = 8

-- AND ONLY WHEN IT WOULD BE ON THE DOCK (Josh 2026-09-24: "tooltip positions
-- are still adjusted if I collapse the quests"). A tooltip grows up from the
-- corner, so whether it meets the dock depends on how tall the dock reaches
-- and how tall the tooltip is - which is known when it shows, not when it is
-- placed. Where the client put it is kept, and the move is decided again on
-- show and whenever it changes size, from that same starting point.
local N = function(v, f) return BT.Pill.Number(v, f) end

-- the dock's box on the screen, in pixels, or nil
local function dockBox()
	if not (dock and dock:IsShown()) then
		return nil
	end
	local bs = N(dock:GetEffectiveScale(), 1)
	local left, top, bottom = N(dock:GetLeft(), nil), N(dock:GetTop(), nil), N(dock:GetBottom(), nil)
	if not (left and top and bottom) then
		return nil
	end
	return left * bs, top * bs, bottom * bs
end

function B.ClearOfDock(tip)
	local base = tip and tip.beebsDefault
	if not (base and tip.SetPoint) then
		return false
	end
	local ts = N(tip:GetEffectiveScale(), 1)
	local shift = 0
	local left, top, bottom = dockBox()
	if left and ts > 0 then
		local tall = N(tip:GetHeight(), 0) * ts
		-- beside the dock, and reaching into its height
		if base.right > left and base.bottom < top and base.bottom + tall > bottom then
			shift = (base.right - left) / ts + B.TIP_GAP
		end
	end
	if tip.beebsShift == shift then
		return shift > 0
	end
	tip.beebsShift = shift
	tip:ClearAllPoints()
	tip:SetPoint(base.point, base.rel, base.relPoint, base.x - shift, base.y)
	return shift > 0
end

-- where the client put a tooltip that had nowhere of its own to go
function B.NoteDefault(tip)
	if not (tip and tip.GetPoint and tip.GetRight) then
		return false
	end
	local point, rel, relPoint, x, y = tip:GetPoint(1)
	local ts = N(tip:GetEffectiveScale(), 1)
	local right, bottom = N(tip:GetRight(), nil), N(tip:GetBottom(), nil)
	if not (point and right and bottom) then
		tip.beebsDefault = nil
		return false
	end
	tip.beebsDefault = { point = point, rel = rel, relPoint = relPoint, x = N(x, 0), y = N(y, 0),
		right = right * ts, bottom = bottom * ts }
	tip.beebsShift = 0
	return B.ClearOfDock(tip)
end

local function guarded(fn)
	return function(tip)
		local ok, err = pcall(fn, tip)
		if not ok then
			BT.Err("dock.tooltip: " .. tostring(err))
		end
	end
end

if type(hooksecurefunc) == "function" and type(_G.GameTooltip_SetDefaultAnchor) == "function" then
	hooksecurefunc("GameTooltip_SetDefaultAnchor", guarded(B.NoteDefault))
end
local tipFrame = _G.GameTooltip
if type(tipFrame) == "table" and tipFrame.HookScript then
	-- anchored anywhere else, it is no longer ours to move
	if type(hooksecurefunc) == "function" and type(tipFrame.SetOwner) == "function" then
		hooksecurefunc(tipFrame, "SetOwner", function(self)
			self.beebsDefault = nil
		end)
	end
	tipFrame:HookScript("OnShow", guarded(B.ClearOfDock))
	tipFrame:HookScript("OnSizeChanged", guarded(B.ClearOfDock))
end

-- ---------------------------------------------------------------------------
-- Quieter in a fight
-- ---------------------------------------------------------------------------
--
-- FADED IN COMBAT (Josh 2026-09-24): the dock at seventy or forty percent while
-- you fight, and whole again under the pointer and when the fight is over.
-- Off, it is left alone.
B.FADES = { off = 1, soft = 0.7, strong = 0.4 }

function B.FadeLevel()
	local key = BT.settings and BT.settings.dockFade or "off"
	return B.FADES[key] or 1
end

function B.Fade()
	if not dock then
		return 1
	end
	local fighting = InCombatLockdown and InCombatLockdown()
	local a = 1
	if fighting and not (dock.IsMouseOver and dock:IsMouseOver()) then
		a = B.FadeLevel()
	end
	dock:SetAlpha(a)
	return a
end

function B.WatchFade()
	if B.fader or not CreateFrame then
		return B.fader
	end
	local f = CreateFrame("Frame")
	B.fader = f
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(self, event)
		-- in a fight, the pointer is looked for a few times a second
		if event == "PLAYER_REGEN_DISABLED" and B.FadeLevel() < 1 then
			local since = 0
			self:SetScript("OnUpdate", function(_, elapsed)
				since = since + (elapsed or 0)
				if since >= 0.15 then
					since = 0
					B.Fade()
				end
			end)
		else
			self:SetScript("OnUpdate", nil)
		end
		B.Fade()
	end)
	return f
end

function B.SetFade(key)
	BT.EnsureBound()
	BT.settings.dockFade = B.FADES[key] and key or "off"
	B.Fade()
end
