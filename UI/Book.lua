-- The journals' window: one shape for the Expedition and the Ledger (Josh
-- 2026-10-05).
--
-- SISTER JOURNALS (Josh 2026-10-04: "Ledger and expedition should have
-- similar experiences ... Trying to make these like sister features, so the
-- learned familiarity of one will apply to both"; the canvas "Sister
-- journals", locked 2026-10-05: "Lock it in and start building"). Both
-- windows are this one, 760 wide, as the settings window is:
--
--   the header   the keeper's face, the book's name, what the keeper says to
--                you at your rank, and your rank in a box at the right - a
--                click on it opens Commendations
--   the tabs     under the header, left
--   each page    a rail down the left that picks what the page shows, a
--                toolbar over the column to its right, and the column
--
-- Commendations is the same page in both books (Bk.Commendations): the ten
-- ranks across the top, the groups and where the points come from on the
-- rail, and the commendations two across.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Book.lua")

local Bk = {}
BT.Book = Bk

-- "Expedition UI needs to be much smaller, and the expedition and ledger UI
-- should be the same width" (Josh 2026-10-04): 1180 x 746 and 640 x 500 came
-- to these
Bk.WIDTH, Bk.HEIGHT = 760, 640
Bk.PAD = 14
Bk.HEADER_H = 100
Bk.TABS_Y = 110
Bk.TAB_W = 104
-- the pages start under the tabs
Bk.BODY_Y = 142
Bk.RAIL_W = 150
Bk.GAP = 10
Bk.TOOL_H = 24
-- the column's left edge, and where it starts under the toolbar, on a page
Bk.COL_X = Bk.PAD + Bk.RAIL_W + Bk.GAP
Bk.COL_Y = Bk.TOOL_H + 8
Bk.RAIL_ROW_H = 26

local PAD = Bk.PAD
local PORTRAIT = 76
local DIM = { 0.50, 0.55, 0.53 }
local GOLD = { 1, 0.82, 0.30 }
local FONT_NAME = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\JosefinSans-Bold.ttf"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CHECK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
-- the keeper's words: lighter than a grey line, quieter than a title
local QUOTE = { 0.76, 0.82, 0.80 }

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
Bk.Big = big

-- ---------------------------------------------------------------------------
-- The keeper's face
-- ---------------------------------------------------------------------------
--
-- HEMET AND JORACH IN PERSON (Josh 2026-10-04: "I'd like to have a portrait
-- of Hemet Nesingwary and Baron Revilgaz respectively"; the Ledger's keeper
-- became Lord Jorach Ravenholdt on 2026-10-05). The game's own model of each,
-- framed on the face as the journal's cards frame an enemy's
-- (Modules/Expedition/Window.lua): asked for by NPC id, held still, and
-- asked for again a little later while the client is still sending for it.
local ASK_AGAIN = { 0.5, 1.5, 4 }

local function loaded(model)
	if type(model.GetModelFileID) ~= "function" then
		return true
	end
	local ok, id = pcall(model.GetModelFileID, model)
	return ok and type(id) == "number" and id > 0
end

local function frameFace(model)
	pcall(model.RefreshCamera, model)
	pcall(model.SetPortraitZoom, model, 1)
	pcall(model.SetPosition, model, 0, 0, 0)
	-- still, as the cards are (Josh 2026-09-25: "I want still portraits")
	if not pcall(model.FreezeAnimation, model, 0, 0, 0) then
		pcall(model.SetPaused, model, true)
	end
end

function Bk.Portrait(model)
	if not (model and model.npc) then
		return false
	end
	pcall(model.ClearModel, model)
	pcall(model.SetCreature, model, model.npc)
	frameFace(model)
	if C_Timer and C_Timer.After then
		for _, wait in ipairs(ASK_AGAIN) do
			C_Timer.After(wait, function()
				if not loaded(model) then
					pcall(model.SetCreature, model, model.npc)
				end
				frameFace(model)
			end)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

-- spec = { name, title, npc, colour, by, tabs = { { key, label } },
--          onTab(key), onRank(), point }
function Bk.Window(spec)
	local W = BT.Widgets
	local f = CreateFrame("Frame", spec.name, UIParent)
	f:SetSize(Bk.WIDTH, Bk.HEIGHT)
	f:SetPoint((table.unpack or unpack)(spec.point or { "CENTER", 0, 0 }))
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	W.PixelDrag(f)
	f:SetClampedToScreen(true)
	W.Panel(f, W.SOLID)
	if spec.name then
		tinsert(UISpecialFrames, spec.name) -- escape closes it
	end
	f.spec = spec
	local c = spec.colour or { 1, 1, 1 }

	-- the keeper
	local face = CreateFrame("Frame", nil, f)
	face:SetSize(PORTRAIT, PORTRAIT)
	face:SetPoint("TOPLEFT", PAD, -12)
	W.Panel(face, { 0.02, 0.03, 0.03, 1 }, { c[1], c[2], c[3], 0.7 })
	f.face = face
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, face)
	if ok and model then
		model:SetPoint("TOPLEFT", 1, -1)
		model:SetPoint("BOTTOMRIGHT", -1, 1)
		model.npc = spec.npc
		pcall(model.SetScript, model, "OnModelLoaded", frameFace)
		f.portrait = model
	end

	-- the book's name, and what it holds
	local textX = PAD + PORTRAIT + 14
	f.title = f:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	f.title:SetPoint("TOPLEFT", textX, -14)
	f.title:SetText(spec.title or "")
	f.subtitle = f:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 8, -1)
	f.subtitle:SetPoint("RIGHT", f, "LEFT", 490, 0)
	f.subtitle:SetJustifyH("LEFT")
	f.subtitle:SetWordWrap(false)

	-- WHAT THE KEEPER SAYS TO YOU (Josh 2026-10-04: "Maybe they could give an
	-- RP quoted line based on the player's current rank"): a line for each
	-- rank, and the keeper's name under it at the right, as the feature's
	-- page sets its quote (UI/Window.lua)
	f.quote = W.Label(f, "", "small", QUOTE[1], QUOTE[2], QUOTE[3])
	f.quote:SetPoint("TOPLEFT", textX, -38)
	f.quote:SetWidth(372)
	f.quote:SetJustifyH("LEFT")
	f.quote:SetWordWrap(true)
	if f.quote.SetMaxLines then
		pcall(f.quote.SetMaxLines, f.quote, 2)
	end
	f.by = W.Label(f, spec.by and ("- " .. spec.by) or "", "small", DIM[1], DIM[2], DIM[3])
	f.by:SetPoint("TOPRIGHT", f.quote, "BOTTOMRIGHT", 0, -3)
	f.by:SetJustifyH("RIGHT")

	-- YOUR RANK, IN A BOX OF ITS OWN: the badge, the title, which of ten and
	-- your points, the bar to the next and how far; a click opens
	-- Commendations
	local rb = CreateFrame("Button", nil, f)
	rb:SetSize(238, 56)
	rb:SetPoint("TOPLEFT", 496, -36)
	rb.bg, rb.rim = BT.Pill.Panel(rb, { c[1], c[2], c[3], 0.07 }, { c[1], c[2], c[3], 0.25 })
	rb.badge = rb:CreateTexture(nil, "ARTWORK")
	rb.badge:SetSize(62, 62)
	rb.badge:SetPoint("LEFT", rb, "LEFT", -4, 0)
	rb.name = rb:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(rb.name.SetFont, rb.name, FONT_NAME, 17, "")
	rb.name:SetPoint("TOPLEFT", rb, "TOPLEFT", 66, -6)
	rb.name:SetPoint("RIGHT", rb, "RIGHT", -10, 0)
	rb.name:SetJustifyH("LEFT")
	rb.name:SetWordWrap(false)
	rb.line = W.Label(rb, "", "small", DIM[1], DIM[2], DIM[3])
	rb.line:SetPoint("TOPLEFT", rb.name, "BOTTOMLEFT", 0, -3)
	rb.line:SetJustifyH("LEFT")
	rb.track = rb:CreateTexture(nil, "BORDER")
	rb.track:SetPoint("TOPLEFT", rb.line, "BOTTOMLEFT", 0, -4)
	rb.track:SetPoint("RIGHT", rb, "RIGHT", -10, 0)
	rb.track:SetHeight(4)
	rb.track:SetColorTexture(1, 1, 1, 0.07)
	rb.fill = rb:CreateTexture(nil, "ARTWORK")
	rb.fill:SetPoint("TOPLEFT", rb.track, "TOPLEFT", 0, 0)
	rb.fill:SetHeight(4)
	rb.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	rb.next = W.Label(rb, "", "small", DIM[1], DIM[2], DIM[3])
	rb.next:SetPoint("TOPLEFT", rb.track, "BOTTOMLEFT", 0, -3)
	rb.next:SetJustifyH("LEFT")
	rb:SetScript("OnClick", function()
		if spec.onRank then
			spec.onRank()
		end
	end)
	rb:SetScript("OnEnter", function(self)
		BT.Pill.Recolour(self, { c[1], c[2], c[3], 0.12 }, { c[1], c[2], c[3], 0.5 })
	end)
	rb:SetScript("OnLeave", function(self)
		BT.Pill.Recolour(self, { c[1], c[2], c[3], 0.07 }, { c[1], c[2], c[3], 0.25 })
	end)
	f.rank = rb

	f.close = W.Close(f, 20)
	f.close:SetPoint("TOPRIGHT", -12, -12)
	f.close:SetScript("OnClick", function() f:Hide() end)
	W.Divider(f, PAD, -Bk.HEADER_H)

	f.tabs = W.Segmented(f, spec.tabs or {}, function(key)
		if spec.onTab then
			spec.onTab(key)
		end
	end, Bk.TAB_W)
	f.tabs:SetPoint("TOPLEFT", PAD, -Bk.TABS_Y)

	f.pages = {}
	f:HookScript("OnShow", function(self)
		if self.portrait then
			Bk.Portrait(self.portrait)
		end
	end)
	f:Hide()
	return f
end

-- A page of the window: everything under the tabs. Shown by Bk.ShowPage.
function Bk.Page(f, key)
	local p = CreateFrame("Frame", nil, f)
	p:SetPoint("TOPLEFT", 0, -Bk.BODY_Y)
	p:SetPoint("BOTTOMRIGHT", 0, 0)
	p.key = key
	p:Hide()
	f.pages[key] = p
	return p
end

function Bk.ShowPage(f, key)
	for k, p in pairs(f.pages) do
		p:SetShown(k == key)
	end
	f.tabs:Select(key)
	f.page = key
end

-- The header for where you are: `h` = { subtitle, ranks = { { at, title } },
-- badge(n), points, quotes }. `points` may be a preview's.
function Bk.SetHeader(f, h)
	if h.subtitle then
		f.subtitle:SetText(h.subtitle)
	end
	local ranks = h.ranks
	if not ranks then
		return
	end
	local n = 1
	for i, r in ipairs(ranks) do
		if (h.points or 0) >= r[1] then
			n = i
		end
	end
	local here, nxt = ranks[n], ranks[n + 1]
	local rb = f.rank
	rb.badge:SetTexture(h.badge and h.badge(n) or nil)
	rb.name:SetText(here[2])
	-- A LONG TITLE A SIZE SMALLER: "Master of the Hunt" and "Eye of
	-- Ravenholdt" fit the box at 15 or 13 where 17 would cut them off
	for _, size in ipairs({ 17, 15, 13 }) do
		pcall(rb.name.SetFont, rb.name, FONT_NAME, size, "")
		local ok, w = pcall(rb.name.GetStringWidth, rb.name)
		if not (ok and type(w) == "number") or w <= 238 - 66 - 10 then
			break
		end
	end
	rb.line:SetText(("Rank %d of %d · |cffffffff%s pts|r"):format(n, #ranks, big(h.points)))
	-- the bar's width, or what it will be before the window is laid out
	local w = BT.Pill.Number(rb.track:GetWidth(), 0)
	if w < 2 then
		w = 238 - 66 - 10
	end
	if nxt then
		local share = math.min(1, ((h.points or 0) - here[1]) / math.max(1, nxt[1] - here[1]))
		rb.fill:SetShown(share > 0)
		rb.fill:SetWidth(math.max(1, w * share))
		rb.next:SetText(("%s to %s"):format(big(nxt[1] - (h.points or 0)), nxt[2]))
	else
		rb.fill:Show()
		rb.fill:SetWidth(w)
		rb.next:SetText("Highest rank")
	end
	f.quote:SetText(h.quotes and h.quotes[n] or "")
	f.rankShown = n
	return n
end

-- ---------------------------------------------------------------------------
-- A page's rail, toolbar and column
-- ---------------------------------------------------------------------------

-- The rail down a page's left, from `top` below the page's top to the foot.
-- `head` is its heading; `seg` = { options, onPick } puts a choice under it;
-- `foot` is room kept at the bottom for something of the caller's.
function Bk.Rail(page, top, opts)
	opts = opts or {}
	local W = BT.Widgets
	local rail = CreateFrame("Frame", nil, page)
	rail:SetPoint("TOPLEFT", PAD, -(top or 0))
	rail:SetPoint("BOTTOMLEFT", PAD, PAD)
	rail:SetWidth(Bk.RAIL_W)
	W.Panel(rail, W.FILL, W.HAIR)
	rail.head = W.Label(rail, string.upper(opts.head or ""), "small", DIM[1], DIM[2], DIM[3])
	rail.head:SetPoint("TOPLEFT", 10, -9)
	local listTop = 26
	if opts.seg then
		rail.seg = W.Segmented(rail, opts.seg[1], opts.seg[2], math.floor((Bk.RAIL_W - 12) / #opts.seg[1]) + 1)
		rail.seg:SetPoint("TOPLEFT", 6, -listTop)
		listTop = listTop + 26
	end
	rail.list = W.Scroller(rail, 4)
	rail.list:SetPoint("TOPLEFT", 4, -listTop)
	rail.list:SetPoint("BOTTOMRIGHT", -4, 4 + (opts.foot or 0))
	rail.list.step = Bk.RAIL_ROW_H * 3
	if opts.foot then
		rail.foot = CreateFrame("Frame", nil, rail)
		rail.foot:SetPoint("BOTTOMLEFT", 0, 0)
		rail.foot:SetPoint("BOTTOMRIGHT", 0, 0)
		rail.foot:SetHeight(opts.foot)
		local line = rail.foot:CreateTexture(nil, "ARTWORK")
		line:SetPoint("TOPLEFT", 8, 0)
		line:SetPoint("TOPRIGHT", -8, 0)
		line:SetHeight(1)
		W.Rule(line, nil, "h")
	end
	rail.rows = {}
	rail.onPick = opts.onPick
	return rail
end

local function railRow(rail, i)
	local r = rail.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Button", nil, rail.list.content)
	r:SetHeight(Bk.RAIL_ROW_H - 1)
	r.lit = r:CreateTexture(nil, "BACKGROUND")
	r.lit:SetAllPoints()
	r.lit:Hide()
	r.mark = r:CreateTexture(nil, "ARTWORK")
	r.mark:SetPoint("TOPLEFT", 0, -3)
	r.mark:SetPoint("BOTTOMLEFT", 0, 3)
	r.mark:SetWidth(3)
	W.Lit(r.mark)
	r.mark:Hide()
	r.dot = r:CreateTexture(nil, "ARTWORK")
	r.dot:SetSize(7, 7)
	r.dot:SetPoint("LEFT", 10, 0)
	r.dot:Hide()
	r.count = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.count:SetPoint("RIGHT", -6, 0)
	r.count:SetJustifyH("RIGHT")
	r.label = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.label:SetPoint("LEFT", 10, 0)
	r.label:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
	r.label:SetJustifyH("LEFT")
	r.label:SetWordWrap(false)
	r:SetScript("OnClick", function(self)
		if rail.onPick then
			rail.onPick(self.key)
		end
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
	rail.rows[i] = r
	return r
end

-- The rail's rows, top to bottom: `entries` = { { key, label, count, dot,
-- chosen } }; a dot is a colour, drawn before the label (a tag's)
function Bk.RailRows(rail, entries)
	local width = Bk.RAIL_W - 8 - 4
	for i, e in ipairs(entries) do
		local r = railRow(rail, i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", rail.list.content, "TOPLEFT", 0, -(i - 1) * Bk.RAIL_ROW_H)
		r:SetWidth(width)
		r.key = e.key
		r.chosen = e.chosen and true or false
		r.label:SetText(e.label or "")
		r.count:SetText(e.count ~= nil and tostring(e.count) or "")
		r.label:ClearAllPoints()
		if e.dot then
			r.dot:SetColorTexture(e.dot[1], e.dot[2], e.dot[3], 1)
			r.dot:Show()
			r.label:SetPoint("LEFT", r.dot, "RIGHT", 7, 0)
		else
			r.dot:Hide()
			r.label:SetPoint("LEFT", 10, 0)
		end
		r.label:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
		if r.chosen then
			local w = BT.Widgets.WASH
			r.lit:SetColorTexture(w[1], w[2], w[3], w[4])
			r.lit:Show()
			r.label:SetTextColor(0.92, 0.96, 0.94)
		else
			r.lit:Hide()
			r.label:SetTextColor(0.62, 0.68, 0.65)
		end
		r.mark:SetShown(r.chosen)
		r:Show()
	end
	for i = #entries + 1, #rail.rows do
		rail.rows[i]:Hide()
	end
	rail.list:SetContentHeight(#entries * Bk.RAIL_ROW_H)
end

-- the row over the column, where a page puts its controls
function Bk.Toolbar(page, top)
	local t = CreateFrame("Frame", nil, page)
	t:SetPoint("TOPLEFT", Bk.COL_X, -(top or 0))
	t:SetPoint("TOPRIGHT", -PAD, -(top or 0))
	t:SetHeight(Bk.TOOL_H)
	return t
end

-- the column, under the toolbar to the foot
function Bk.Column(page, top)
	local c = CreateFrame("Frame", nil, page)
	c:SetPoint("TOPLEFT", Bk.COL_X, -((top or 0) + Bk.COL_Y))
	c:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	return c
end

-- A label and a set of buttons, side by side in a toolbar, after `after` (or
-- at the toolbar's left): gives back the buttons
function Bk.Choice(bar, after, word, options, onPick, width)
	local W = BT.Widgets
	local label = W.Label(bar, word, "small", DIM[1], DIM[2], DIM[3])
	if after then
		label:SetPoint("LEFT", after, "RIGHT", 16, 0)
	else
		label:SetPoint("LEFT", bar, "LEFT", 2, 0)
	end
	local seg = W.Segmented(bar, options, onPick, width)
	seg:SetPoint("LEFT", label, "RIGHT", 8, 0)
	seg.word = label
	return seg
end

-- A SEARCH BOX (Josh 2026-09-27, the Field Journal's: "a search box ... We
-- should use lazy matching"): a word is one search, not one a letter, and
-- Escape or the cross empties it. `onText(text)` hears it settle.
function Bk.Search(parent, hint, width, onText)
	local W = BT.Widgets
	local search = CreateFrame("Frame", nil, parent)
	search:SetSize(width or 170, 22)
	W.Panel(search, W.FILL, W.HAIR)
	local edit = CreateFrame("EditBox", nil, search)
	edit:SetPoint("TOPLEFT", 8, 0)
	edit:SetPoint("BOTTOMRIGHT", -22, 0)
	edit:SetAutoFocus(false)
	pcall(edit.SetFontObject, edit, "BeebModFontHighlightSmall")
	search.edit = edit
	search.hint = W.Label(search, hint or "", "small", DIM[1], DIM[2], DIM[3])
	search.hint:SetPoint("LEFT", 8, 0)
	search.clear = W.Close(search, 14)
	search.clear:SetPoint("RIGHT", -4, 0)
	search.clear:Hide()
	local pending = false
	local function apply()
		pending = false
		local text = edit:GetText() or ""
		search.hint:SetShown(text == "")
		search.clear:SetShown(text ~= "")
		if onText then
			onText(text)
		end
	end
	search.Apply = apply
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
	return search
end

-- ---------------------------------------------------------------------------
-- Commendations: the same page in both books
-- ---------------------------------------------------------------------------
--
-- THE TEN RANKS ACROSS THE TOP (the Expedition's since 2026-09-29, both
-- books' now): a badge each, joined by a line that fills as far as your
-- points go; ranks behind you lit, yours with a gold glow, the ones ahead
-- grey. Under them the rail - All, then each group with its count - with
-- where the points come from at its foot; and the commendations two across,
-- earned ones lit and ticked with when they were earned.
Bk.STRIP_H = 96
Bk.STRIP_BADGE = 44
Bk.TILE_H, Bk.TILE_GAP, Bk.TILE_COLS = 72, 8, 2
Bk.HEAD_ROW_H = 24
Bk.POINTS_FOOT = 96

-- spec = { onPick(key), onShow(key), sums = { label, ... } }
function Bk.Commendations(f, key, spec)
	local W = BT.Widgets
	local page = Bk.Page(f, key)
	local a = page
	a.spec = spec

	-- the ranks
	local strip = CreateFrame("Frame", nil, page)
	strip:SetPoint("TOPLEFT", PAD, 0)
	strip:SetPoint("TOPRIGHT", -PAD, 0)
	strip:SetHeight(Bk.STRIP_H)
	W.Panel(strip, W.FILL, W.HAIR)
	a.strip = strip
	local count = 10
	local slot = (Bk.WIDTH - PAD * 2) / count
	strip.slot = slot
	local mid = -6 - Bk.STRIP_BADGE / 2
	strip.track = strip:CreateTexture(nil, "BORDER")
	strip.track:SetPoint("TOPLEFT", slot / 2, mid + 1)
	strip.track:SetSize(slot * (count - 1), 2)
	strip.track:SetColorTexture(1, 1, 1, 0.07)
	strip.fill = strip:CreateTexture(nil, "BORDER", nil, 1)
	strip.fill:SetPoint("TOPLEFT", strip.track, "TOPLEFT", 0, 0)
	strip.fill:SetHeight(2)
	strip.rungs = {}
	for i = 1, count do
		local r = CreateFrame("Button", nil, strip)
		r:SetSize(slot, Bk.STRIP_H - 4)
		r:SetPoint("TOPLEFT", (i - 1) * slot, -2)
		r.glow = r:CreateTexture(nil, "BACKGROUND")
		r.glow:SetSize(Bk.STRIP_BADGE + 10, Bk.STRIP_BADGE + 10)
		r.glow:SetPoint("TOP", r, "TOP", 0, 1)
		r.glow:SetTexture(DISC)
		r.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.22)
		r.badge = r:CreateTexture(nil, "ARTWORK")
		r.badge:SetSize(Bk.STRIP_BADGE, Bk.STRIP_BADGE)
		r.badge:SetPoint("TOP", r, "TOP", 0, -2)
		r.name = W.Label(r, "", "small")
		r.name:SetPoint("TOP", r.badge, "BOTTOM", 0, 1)
		r.name:SetWidth(slot - 4)
		r.name:SetJustifyH("CENTER")
		r.name:SetWordWrap(true)
		if r.name.SetMaxLines then
			pcall(r.name.SetMaxLines, r.name, 2)
		end
		r.points = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
		r.points:SetPoint("TOP", r.name, "BOTTOM", 0, -1)
		r.points:SetJustifyH("CENTER")
		r.rank = i
		r:SetScript("OnEnter", Bk.RankTip)
		r:SetScript("OnLeave", function()
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
		strip.rungs[i] = r
	end

	local top = Bk.STRIP_H + 8
	a.rail = Bk.Rail(page, top, { head = "Groups", foot = Bk.POINTS_FOOT, onPick = function(k)
		a.list:ScrollTo(0)
		if spec.onPick then
			spec.onPick(k)
		end
	end })
	-- where the points come from
	local foot = a.rail.foot
	foot.head = W.Label(foot, string.upper("Points"), "small", DIM[1], DIM[2], DIM[3])
	foot.head:SetPoint("TOPLEFT", 10, -8)
	foot.rows = {}
	for i = 1, 4 do
		local l = W.Label(foot, "", "small", DIM[1], DIM[2], DIM[3])
		local v = W.Label(foot, "", "small", 0.76, 0.82, 0.80)
		v:SetJustifyH("RIGHT")
		l:SetPoint("TOPLEFT", 10, -24 - (i - 1) * 17)
		v:SetPoint("TOPRIGHT", -10, -24 - (i - 1) * 17)
		foot.rows[i] = { label = l, value = v }
	end
	foot.rows[4].label:SetTextColor(1, 1, 1)
	foot.rows[4].value:SetTextColor(1, 1, 1)

	local bar = Bk.Toolbar(page, top)
	a.shows = Bk.Choice(bar, nil, "Show", { { "all", "All" }, { "done", "Earned" }, { "todo", "In progress" } },
		function(k)
			a.list:ScrollTo(0)
			if spec.onShow then
				spec.onShow(k)
			end
		end, 80)
	a.tally = W.Label(bar, "", "small", DIM[1], DIM[2], DIM[3])
	a.tally:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
	a.tally:SetJustifyH("RIGHT")

	local col = Bk.Column(page, top)
	a.list = W.Scroller(col, 6)
	a.list:SetAllPoints()
	a.list.step = (Bk.TILE_H + Bk.TILE_GAP) * 2
	a.rows, a.heads = {}, {}
	return a
end

-- what a rank takes, and how far you are from it
function Bk.RankTip(r)
	if not (GameTooltip and r) then
		return
	end
	local strip = r:GetParent()
	local ranks = strip.ranks
	if not ranks then
		return
	end
	local at, title = ranks[r.rank][1], ranks[r.rank][2]
	local points = strip.points or 0
	GameTooltip:SetOwner(r, "ANCHOR_TOP")
	GameTooltip:AddLine(title, 1, 1, 1)
	GameTooltip:AddLine(("Rank %d of %d · %s points"):format(r.rank, #ranks, big(at)), DIM[1], DIM[2], DIM[3])
	if points >= at then
		GameTooltip:AddLine(r.here and "Your rank" or "Reached", GOLD[1], GOLD[2], GOLD[3])
	else
		GameTooltip:AddLine(("%s points to go"):format(big(at - points)), DIM[1], DIM[2], DIM[3])
	end
	GameTooltip:Show()
end

-- the ranks at `points`: lit to yours, the rest faded, the line filled to it
function Bk.DrawStrip(strip, ranks, badge, points, colour)
	strip.ranks, strip.points = ranks, points
	local n = 1
	for i, r in ipairs(ranks) do
		if points >= r[1] then
			n = i
		end
	end
	for i, r in ipairs(strip.rungs) do
		local rank = ranks[i]
		r:SetShown(rank ~= nil)
		if rank then
			local reached = i <= n
			r.here = i == n
			r.badge:SetTexture(badge(i))
			r.badge:SetDesaturated(not reached)
			r.badge:SetVertexColor(reached and 1 or 0.55, reached and 1 or 0.55, reached and 1 or 0.55)
			r.badge:SetAlpha(reached and 1 or 0.45)
			r.glow:SetShown(r.here)
			r.name:SetText(rank[2])
			r.points:SetText(i == 1 and "Start" or big(rank[1]))
			if r.here then
				r.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
			elseif reached then
				r.name:SetTextColor(1, 1, 1)
			else
				r.name:SetTextColor(DIM[1], DIM[2], DIM[3])
			end
		end
	end
	local here, nxt = ranks[n], ranks[n + 1]
	local share = nxt and math.min(1, (points - here[1]) / math.max(1, nxt[1] - here[1])) or 0
	local span = ((n - 1) + share) * strip.slot
	local c = colour or BT.Widgets.ACCENT
	strip.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	strip.fill:SetShown(span > 0)
	strip.fill:SetWidth(math.max(1, span))
	return n
end

local function railCount(row)
	if row.of then
		return ("%d / %d"):format(row.done or 0, row.of)
	end
	return row.count or ""
end

-- a commendation's tile: its title and what it asks, its points, and either
-- how far along it is or when it was earned
local function tile(a, i)
	local r = a.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Frame", nil, a.list.content)
	r:SetHeight(Bk.TILE_H)
	BT.Pill.Panel(r, W.FILL, W.HAIR)
	r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 2)
	r.lit:SetAllPoints()
	r.points = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	pcall(r.points.SetFont, r.points, FONT_NAME, 15, "")
	r.points:SetPoint("TOPRIGHT", -10, -8)
	r.points:SetJustifyH("RIGHT")
	r.ptsLabel = W.Label(r, string.upper("Pts"), "small", DIM[1], DIM[2], DIM[3])
	r.ptsLabel:SetPoint("TOPRIGHT", r.points, "BOTTOMRIGHT", 0, -2)
	r.check = r:CreateTexture(nil, "OVERLAY")
	r.check:SetSize(13, 13)
	r.check:SetPoint("TOPLEFT", 9, -9)
	pcall(r.check.SetTexture, r.check, CHECK_TEX)
	r.title = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.title:SetPoint("TOPLEFT", 12, -9)
	r.title:SetPoint("RIGHT", r.points, "LEFT", -8, 0)
	r.title:SetJustifyH("LEFT")
	r.title:SetWordWrap(false)
	r.text = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.text:SetPoint("TOPLEFT", 12, -27)
	r.text:SetPoint("RIGHT", r, "RIGHT", -44, 0)
	r.text:SetJustifyH("LEFT")
	if r.text.SetWordWrap then
		r.text:SetWordWrap(true)
	end
	if r.text.SetMaxLines then
		pcall(r.text.SetMaxLines, r.text, 2)
	end
	r.right = W.Label(r, "", "small")
	r.right:SetPoint("BOTTOMLEFT", 12, 9)
	r.right:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.right:SetJustifyH("LEFT")
	r.right:SetWordWrap(false)
	r.track = r:CreateTexture(nil, "BORDER")
	r.track:SetPoint("BOTTOMLEFT", 12, 6)
	r.track:SetPoint("BOTTOMRIGHT", -10, 6)
	r.track:SetHeight(3)
	r.fill = r:CreateTexture(nil, "ARTWORK")
	r.fill:SetHeight(3)
	r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT", 0, 0)
	-- the one a notice was clicked for: a gold line round it
	r.focus = {}
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = r:CreateTexture(nil, "OVERLAY", nil, 2)
		t:SetPoint(side[1])
		t:SetPoint(side[2])
		if side[1] == "TOPLEFT" and side[2] == "BOTTOMLEFT" or side[1] == "TOPRIGHT" then
			t:SetWidth(2)
		else
			t:SetHeight(2)
		end
		t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.95)
		t:Hide()
		r.focus[#r.focus + 1] = t
	end
	a.rows[i] = r
	return r
end

local function head(a, i)
	local h = a.heads[i]
	if h then
		return h
	end
	h = CreateFrame("Frame", nil, a.list.content)
	h:SetHeight(Bk.HEAD_ROW_H)
	h.text = h:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	h.text:SetPoint("BOTTOMLEFT", 2, 5)
	BT.Widgets.TintText(h.text, 0.8)
	h.count = BT.Widgets.Label(h, "", "small", DIM[1], DIM[2], DIM[3])
	h.count:SetPoint("BOTTOMRIGHT", -4, 5)
	a.heads[i] = h
	return h
end

-- The page, drawn. `d` = {
--   ranks, badge(n), points (your own, or a preview's), colour,
--   groups = { { key, title, list = { item }, done, count } },
--   pick, show, sums = { { label, value } x4 }, earnedLine(item),
--   focus, scrollToFocus }
-- An item is { id, title, text, points, need, have, color, right, at }; a
-- group with a `count` is a tally (what each unique kill or note is worth),
-- not things to earn.
function Bk.DrawCommendations(a, d)
	local accent = BT.Widgets.ACCENT
	Bk.DrawStrip(a.strip, d.ranks, d.badge, d.points or 0, d.colour)
	a.shows:Select(d.show or "all")
	local earned, all = 0, 0
	for _, g in ipairs(d.groups) do
		if not g.count then
			earned, all = earned + (g.done or 0), all + #g.list
		end
	end
	a.tally:SetText(("%d of %d earned"):format(earned, all))

	-- the rail: All, then each group
	local pick = d.pick or "all"
	local entries = { { key = "all", label = "All", count = ("%d / %d"):format(earned, all), chosen = pick == "all" } }
	for _, g in ipairs(d.groups) do
		entries[#entries + 1] = { key = g.key, label = g.title, chosen = pick == g.key,
			count = railCount({ of = (not g.count) and #g.list or nil, done = g.done, count = g.count }) }
	end
	Bk.RailRows(a.rail, entries)
	for i, row in ipairs(a.rail.foot.rows) do
		local s = d.sums and d.sums[i]
		row.label:SetText(s and s[1] or "")
		row.value:SetText(s and big(s[2]) or "")
	end

	local width = BT.Pill.Number(a.list.content:GetWidth(), 0)
	if width < 100 then
		width = Bk.WIDTH - Bk.COL_X - PAD - 6
	end
	local cols = Bk.TILE_COLS
	local tileW = math.floor((width - Bk.TILE_GAP * (cols - 1)) / cols)
	local show = d.show or "all"
	local y, ri, hi = 0, 0, 0
	local focusY
	for _, g in ipairs(d.groups) do
		local list = {}
		if pick == "all" or pick == g.key then
			for _, it in ipairs(g.list) do
				local done = it.have >= it.need
				-- a tally is shown with All, and not as earned or to do
				if show == "all" or (not g.count and (show == "done") == done) then
					list[#list + 1] = it
				end
			end
		end
		if #list > 0 then
			hi = hi + 1
			local h = head(a, hi)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
			h:SetWidth(width)
			h.text:SetText(g.title:upper())
			h.count:SetText(g.count or ("%d / %d"):format(g.done or 0, #g.list))
			h:Show()
			y = y + Bk.HEAD_ROW_H
			for k, it in ipairs(list) do
				ri = ri + 1
				local col = (k - 1) % cols
				if k > 1 and col == 0 then
					y = y + Bk.TILE_H + Bk.TILE_GAP
				end
				local r = tile(a, ri)
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", col * (tileW + Bk.TILE_GAP), -y)
				r:SetWidth(tileW)
				local done = it.have >= it.need and not g.count
				r.points:SetText(tostring(it.points or ""))
				r.ptsLabel:SetShown(it.points ~= nil)
				r.title:SetText(it.title)
				r.text:SetText(it.text or "")
				r.lit:SetColorTexture(accent[1], accent[2], accent[3], 0.08)
				r.lit:SetShown(done)
				r.check:SetShown(done)
				r.title:ClearAllPoints()
				r.title:SetPoint("TOPLEFT", done and 27 or 12, -9)
				r.title:SetPoint("RIGHT", r.points, "LEFT", -8, 0)
				-- a mastery's name wears its metal
				local c = it.color
				if done then
					r.points:SetTextColor(accent[1], accent[2], accent[3])
					if c then
						r.title:SetTextColor(c[1], c[2], c[3])
					else
						r.title:SetTextColor(1, 1, 1)
					end
					r.right:SetText(it.right or (d.earnedLine and d.earnedLine(it)) or "Earned")
					r.right:SetTextColor(DIM[1], DIM[2], DIM[3])
					r.track:Hide()
					r.fill:Hide()
				elseif it.right or g.count then
					-- a tally, or a tier nobody has reached yet: a count, not a bar
					r.points:SetTextColor(DIM[1], DIM[2], DIM[3])
					if g.count then
						r.title:SetTextColor(1, 1, 1)
					else
						r.title:SetTextColor(0.62, 0.66, 0.64)
					end
					r.right:SetText(it.right or "")
					r.right:SetTextColor(0.75, 0.78, 0.77)
					r.track:Hide()
					r.fill:Hide()
				else
					r.points:SetTextColor(DIM[1], DIM[2], DIM[3])
					r.title:SetTextColor(0.62, 0.66, 0.64)
					r.right:SetText(("%s / %s"):format(big(it.have), big(it.need)))
					r.right:SetTextColor(0.75, 0.78, 0.77)
					r.track:SetColorTexture(1, 1, 1, 0.07)
					r.fill:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
					local share = math.min(1, it.have / math.max(1, it.need))
					r.track:Show()
					-- a texture of no width is drawn whole: an empty bar is no bar
					r.fill:SetShown(share > 0)
					r.fill:SetWidth(math.max(1, (tileW - 22) * share))
				end
				-- the bar under the count, so the two do not sit on each other
				r.right:ClearAllPoints()
				r.right:SetPoint("BOTTOMLEFT", 12, r.track:IsShown() and 13 or 9)
				r.right:SetPoint("RIGHT", r, "RIGHT", -10, 0)
				local focused = d.focus ~= nil and it.id == d.focus
				for _, t in ipairs(r.focus) do
					t:SetShown(focused)
				end
				if focused then
					focusY = y
				end
				r:Show()
			end
			y = y + Bk.TILE_H + Bk.TILE_GAP
		end
	end
	for i = ri + 1, #a.rows do
		a.rows[i]:Hide()
	end
	for i = hi + 1, #a.heads do
		a.heads[i]:Hide()
	end
	a.list:SetContentHeight(y + 6)
	-- opened for one commendation: its tile at the top, its heading above it
	if d.scrollToFocus then
		a.list:ScrollTo(focusY and math.max(0, focusY - Bk.HEAD_ROW_H) or 0)
	end
	return earned, all
end
