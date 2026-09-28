-- ---------------------------------------------------------------------------
-- The dock's tooltips
-- ---------------------------------------------------------------------------
--
-- ONE FRAME OF OUR OWN (Josh 2026-09-27: "rework most (or all) of the
-- tooltips on the dock. They currently read more as a data dump rather than
-- showing useful information. We need to do better with the design as well -
-- it is very flat right now", and of the mockup, "Let's build this"). Every
-- dock tooltip was the game's own, two columns of numbers. This is a panel of
-- the toolkit's: the raised colour, lighter at the top, a hairline rim, a
-- shadow, and a top edge in the colour of whoever owns it. What goes in it is
-- written in pieces, top to bottom:
--
--   Header    an icon, a name, a line under it, a pill for a state
--   Headline  the answer, large: a number, a rank, some money
--   Bar       progress, with ticks where something happens
--   Scale     the words under a bar, at its ends
--   Note      a sentence or two
--   Section   a hairline and a small heading, then its rows
--   Row       a label and a value, and a small bar under it if it has one
--   Stats     two or three small tiles side by side
--   Tags      coloured chips
--   Quote     a note in the lore face, and who wrote it
--   Foot      every click, as a key and what it does
--
-- The text in it follows docs/writing-style.md.
--
-- BT.Tip.Show(owner, { edge = colour, build = function(t) ... end }) shows
-- one; it goes away with the game's tooltip (every OnLeave already hides
-- that), when its owner hides, or when the pointer has left the owner.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Tip.lua")

local T = {}
BT.Tip = T

local WIDTH, PAD = 280, 12
T.NUMBER = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\FiraCode-Medium.ttf"
T.TITLE = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\JosefinSans-Bold.ttf"
T.LORE = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\Alegreya-Italic.ttf"

-- the colours a value can be in, besides the text's own
T.STATE = {
	good = { 0.37, 0.76, 0.55 },
	warn = { 0.89, 0.66, 0.29 },
	bad = { 0.89, 0.38, 0.35 },
	dim = { 0.49, 0.55, 0.53 },
	rested = { 0.55, 0.47, 0.96 },
}
local INK = { 0.91, 0.93, 0.92 }
local INK2 = { 0.73, 0.78, 0.76 }
local DIM = { 0.49, 0.55, 0.53 }
local FAINT = { 0.36, 0.41, 0.39 }

local N = function(v, fallback)
	return BT.Pill.Number(v, fallback)
end

local frame
-- the pieces, made once and handed out again each time
local pools = {}
local used = {}

local function colourOf(c)
	if type(c) == "string" then
		return T.STATE[c] or INK
	end
	return c or INK
end

local function take(kind, make)
	pools[kind] = pools[kind] or {}
	used[kind] = (used[kind] or 0) + 1
	local list = pools[kind]
	local p = list[used[kind]]
	if not p then
		p = make()
		list[used[kind]] = p
	end
	p:ClearAllPoints()
	p:Show()
	return p
end

local function text(size, face, layer)
	return take("text:" .. (face or "ui") .. ":" .. size, function()
		local fs = frame.body:CreateFontString(nil, layer or "OVERLAY", "BeebModFontHighlight")
		if face then
			pcall(fs.SetFont, fs, face, size, "")
		elseif BT.Fonts and BT.Fonts.Set then
			-- the face the player chose; a name in its heavier weight
			BT.Fonts.Set(fs, size >= 13 and "name" or "text", size)
		end
		fs:SetWordWrap(false)
		fs:SetJustifyH("LEFT")
		return fs
	end)
end

local function rect(layer, sub)
	return take("rect:" .. (layer or "ARTWORK") .. ":" .. (sub or 0), function()
		return frame.body:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	end)
end

local function place(region, x, y)
	region:SetPoint("TOPLEFT", frame.body, "TOPLEFT", x, -y)
end

local function width(fs, fallback)
	return N(fs.GetStringWidth and fs:GetStringWidth(), fallback or 0)
end

-- a line of text's height, or a guess where the client will not say
local function height(fs, size, lines)
	local h = N(fs.GetStringHeight and fs:GetStringHeight(), 0)
	if h <= 0 then
		h = (size + 3) * (lines or 1)
	end
	return h
end

local function build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "BeebModTip", UIParent)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetClampedToScreen(true)
	frame:SetSize(WIDTH, 40)
	frame:Hide()
	local W = BT.Widgets
	W.Panel(frame, W.RAISED, W.RIM)
	W.Shadow(frame)
	-- lighter at the top, fading down: it sits above the world, not on it
	frame.sheen = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	frame.sheen:SetPoint("TOPLEFT", 1, -1)
	frame.sheen:SetPoint("TOPRIGHT", -1, -1)
	frame.sheen:SetHeight(60)
	frame.sheen:SetColorTexture(1, 1, 1, 1)
	local top = CreateColor and CreateColor(1, 1, 1, 0.05)
	local bottom = CreateColor and CreateColor(1, 1, 1, 0)
	if not (CreateColor and pcall(frame.sheen.SetGradient, frame.sheen, "VERTICAL", bottom, top)) then
		frame.sheen:SetColorTexture(1, 1, 1, 0.02)
	end
	-- the owner's colour along the top
	frame.edge = frame:CreateTexture(nil, "ARTWORK", nil, 3)
	frame.edge:SetPoint("TOPLEFT", 0, 0)
	frame.edge:SetPoint("TOPRIGHT", 0, 0)
	frame.edge:SetHeight(2)
	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetAllPoints()
	-- gone once the pointer has left what it is about, whatever else happens
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.check = (self.check or 0) + (elapsed or 0)
		if self.check < 0.2 then
			return
		end
		self.check = 0
		local owner = self.owner
		if not (owner and owner.IsVisible and owner:IsVisible()) then
			self:Hide()
		elseif owner.IsMouseOver and not owner:IsMouseOver() then
			self:Hide()
		end
	end)
	if GameTooltip and hooksecurefunc then
		pcall(hooksecurefunc, GameTooltip, "Hide", function()
			T.Hide()
		end)
	end
	return frame
end
T.Frame = function() return frame end

-- ---------------------------------------------------------------------------
-- The pieces
-- ---------------------------------------------------------------------------

local Builder = {}
Builder.__index = Builder

-- { icon, coords, name, sub, pill, pillState }
function Builder:Header(h)
	local edge = self.edge
	local x = PAD
	local y = 10
	-- a cell's own icon, unless another is given
	local own = self.owner and self.owner.icon
	if h.icon == nil and own and own.GetTexture then
		local ok, file = pcall(own.GetTexture, own)
		if ok and file then
			h.icon = file
			local okC, ulx, uly, llx, lly, urx = pcall(own.GetTexCoord, own)
			if okC and type(ulx) == "number" and type(urx) == "number" then
				h.coords = h.coords or { ulx, urx, uly, lly }
			end
			local okT, r, g, b = pcall(own.GetVertexColor, own)
			if okT and type(r) == "number" then
				h.tint = h.tint or { r, g, b }
			end
		end
	end
	if h.icon then
		local well = rect("ARTWORK", 1)
		well:SetSize(22, 22)
		place(well, x, y)
		well:SetColorTexture(edge[1], edge[2], edge[3], 0.16)
		local icon = rect("ARTWORK", 2)
		icon:SetSize(14, 14)
		icon:SetPoint("CENTER", well, "CENTER", 0, 0)
		icon:SetTexture(h.icon)
		if h.coords then
			icon:SetTexCoord(h.coords[1], h.coords[2], h.coords[3], h.coords[4])
		else
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		icon:SetVertexColor(1, 1, 1, 1)
		if h.tint then
			icon:SetVertexColor(h.tint[1], h.tint[2], h.tint[3], 1)
		end
		x = x + 30
	end
	local right = WIDTH - PAD
	if h.pill then
		local pc = colourOf(h.pillState or edge)
		local label = text(10)
		label:SetText(string.upper(h.pill))
		label:SetTextColor(pc[1], pc[2], pc[3])
		local lw = width(label, #h.pill * 6)
		local chip = rect("ARTWORK", 1)
		chip:SetSize(lw + 12, 16)
		chip:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, -(y + 3))
		chip:SetColorTexture(pc[1], pc[2], pc[3], 0.15)
		label:SetPoint("CENTER", chip, "CENTER", 0, 0)
		right = right - lw - 18
	end
	local name = text(13)
	name:SetText(h.name or "")
	name:SetTextColor(INK[1], INK[2], INK[3])
	place(name, x, h.sub and y + 1 or y + 5)
	name:SetWidth(math.max(40, right - x))
	if h.sub then
		local sub = text(11)
		sub:SetText(h.sub)
		sub:SetTextColor(DIM[1], DIM[2], DIM[3])
		place(sub, x, y + 15)
		sub:SetWidth(math.max(40, right - x))
	end
	self.y = y + 28
end

-- the answer, large: `value` in figures and `unit` after it, or a word
-- (`title`) in the title face
function Builder:Headline(value, unit, state, title)
	local y = self.y + 6
	local big = title and text(19, T.TITLE) or text(20, T.NUMBER)
	big:SetText(tostring(value or ""))
	local c = colourOf(state)
	big:SetTextColor(c[1], c[2], c[3])
	place(big, PAD, y)
	if unit then
		local u = text(12)
		u:SetText(unit)
		u:SetTextColor(INK2[1], INK2[2], INK2[3])
		u:SetPoint("BOTTOMLEFT", big, "BOTTOMRIGHT", 8, 2)
	end
	self.y = y + (title and 21 or 22)
end

function Builder:Title(word, unit)
	return self:Headline(word, unit, nil, true)
end

-- a bar of `value` (0 to 1): `color`, `ticks` ({ at, color }), and a second,
-- striped stretch after the fill (`extra` = { size, color }) for rested XP
function Builder:Bar(value, color, ticks, extra)
	local y = self.y + 7
	local w = WIDTH - PAD * 2
	local track = rect("ARTWORK", 1)
	place(track, PAD, y)
	track:SetSize(w, 6)
	track:SetColorTexture(1, 1, 1, 0.07)
	local v = math.max(0, math.min(1, value or 0))
	local c = colourOf(color or BT.Widgets.ACCENT)
	if v > 0 then
		local fill = rect("ARTWORK", 2)
		place(fill, PAD, y)
		fill:SetSize(math.max(1, math.floor(w * v + 0.5)), 6)
		fill:SetColorTexture(c[1], c[2], c[3], 1)
	end
	if extra and (extra[1] or 0) > 0 and v < 1 then
		local ec = colourOf(extra[2] or "rested")
		local ew = math.min(1 - v, extra[1])
		local more = rect("ARTWORK", 2)
		place(more, PAD + math.floor(w * v + 0.5), y)
		more:SetSize(math.max(1, math.floor(w * ew + 0.5)), 6)
		more:SetColorTexture(ec[1], ec[2], ec[3], 0.45)
	end
	for _, tick in ipairs(ticks or {}) do
		local tc = colourOf(tick[2] or FAINT)
		local t = rect("OVERLAY", 1)
		place(t, PAD + math.floor(w * tick[1] + 0.5) - 1, y - 3)
		t:SetSize(2, 12)
		t:SetColorTexture(tc[1], tc[2], tc[3], 1)
	end
	self.y = y + 6
end

-- a short bar for each of several things side by side (a bag each):
-- { { share, color }, ... }
function Builder:Segments(list)
	local y = self.y + 7
	local n = #list
	if n == 0 then
		return
	end
	local gap = 3
	local w = (WIDTH - PAD * 2 - gap * (n - 1)) / n
	for i, s in ipairs(list) do
		local x = PAD + math.floor((i - 1) * (w + gap) + 0.5)
		local track = rect("ARTWORK", 1)
		place(track, x, y)
		track:SetSize(math.max(1, math.floor(w)), 8)
		track:SetColorTexture(1, 1, 1, 0.07)
		local share = math.max(0, math.min(1, s[1] or 0))
		if share > 0 then
			local c = colourOf(s[2] or BT.Widgets.ACCENT)
			local fill = rect("ARTWORK", 2)
			place(fill, x, y)
			fill:SetSize(math.max(1, math.floor(w * share + 0.5)), 8)
			fill:SetColorTexture(c[1], c[2], c[3], 0.9)
		end
	end
	self.y = y + 8
end

-- the words under a bar: at the left, at the right
function Builder:Scale(left, right, rightState)
	local y = self.y + 5
	if left then
		local l = text(11)
		l:SetText(left)
		l:SetTextColor(DIM[1], DIM[2], DIM[3])
		place(l, PAD, y)
	end
	if right then
		local r = text(11)
		r:SetText(right)
		local c = rightState and colourOf(rightState) or DIM
		r:SetTextColor(c[1], c[2], c[3])
		r:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, -y)
		r:SetJustifyH("RIGHT")
	end
	self.y = y + 13
end

-- a sentence or two, wrapped
function Builder:Note(words, color)
	local y = self.y + 6
	local fs = text(12)
	fs:SetWordWrap(true)
	fs:SetWidth(WIDTH - PAD * 2)
	fs:SetText(words or "")
	local c = colourOf(color or DIM)
	fs:SetTextColor(c[1], c[2], c[3])
	place(fs, PAD, y)
	local lines = math.max(1, math.ceil(#(words or "") * 6 / (WIDTH - PAD * 2)))
	self.y = y + height(fs, 12, lines)
end

-- a hairline across, and a small heading under it (or none)
function Builder:Section(title)
	local y = self.y + 10
	local line = rect("ARTWORK", 1)
	place(line, 0, y)
	line:SetSize(WIDTH, 1)
	local h = BT.Widgets.HAIR
	line:SetColorTexture(h[1], h[2], h[3], h[4] or 0.6)
	y = y + 1
	if title then
		local head = text(9.5)
		head:SetText(string.upper(title))
		head:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
		place(head, PAD, y + 8)
		y = y + 20
	else
		y = y + 4
	end
	self.y = y
end

-- a label and a value; `state` colours the value; `bar` = { value, color }
-- draws a thin bar under the pair
function Builder:Row(label, value, state, bar, labelColor)
	local y = self.y + 3
	local v = text(12, T.NUMBER)
	v:SetText(tostring(value or ""))
	local c = colourOf(state)
	v:SetTextColor(c[1], c[2], c[3])
	v:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, -y)
	v:SetJustifyH("RIGHT")
	local k = text(12)
	k:SetText(label or "")
	local lc = labelColor and colourOf(labelColor) or INK2
	k:SetTextColor(lc[1], lc[2], lc[3])
	place(k, PAD, y)
	k:SetWidth(math.max(40, WIDTH - PAD * 2 - width(v, 60) - 10))
	y = y + 15
	if bar then
		local w = WIDTH - PAD * 2
		local track = rect("ARTWORK", 1)
		place(track, PAD, y + 1)
		track:SetSize(w, 3)
		track:SetColorTexture(1, 1, 1, 0.07)
		local share = math.max(0, math.min(1, bar[1] or 0))
		if share > 0 then
			local bc = colourOf(bar[2] or BT.Widgets.ACCENT)
			local fill = rect("ARTWORK", 2)
			place(fill, PAD, y + 1)
			fill:SetSize(math.max(1, math.floor(w * share + 0.5)), 3)
			fill:SetColorTexture(bc[1], bc[2], bc[3], 1)
		end
		y = y + 6
	end
	self.y = y
end

-- two or three tiles side by side: { { value, label, state, on }, ... }; a
-- tile `on` is lit in the owner's colour
function Builder:Stats(tiles, valueSize)
	local y = self.y + 6
	local n = #tiles
	local gap = 6
	local w = math.floor((WIDTH - PAD * 2 - gap * (n - 1)) / n)
	local size = valueSize or 15
	local edge = self.edge
	for i, tile in ipairs(tiles) do
		local x = PAD + (i - 1) * (w + gap)
		local bg = rect("ARTWORK", 1)
		place(bg, x, y)
		bg:SetSize(w, size + 22)
		if tile[4] then
			bg:SetColorTexture(edge[1], edge[2], edge[3], 0.12)
		else
			bg:SetColorTexture(1, 1, 1, 0.035)
		end
		local v = text(size, T.NUMBER)
		v:SetText(tostring(tile[1] or ""))
		local c = colourOf(tile[3])
		v:SetTextColor(c[1], c[2], c[3])
		place(v, x + 7, y + 6)
		local k = text(10)
		k:SetText(tile[2] or "")
		k:SetTextColor(DIM[1], DIM[2], DIM[3])
		place(k, x + 7, y + size + 9)
		k:SetWidth(w - 10)
	end
	self.y = y + size + 22
end

-- coloured chips, wrapping: { { text, color }, ... }
function Builder:Tags(tags)
	local y = self.y + 6
	local x = PAD
	local rowH = 18
	for _, tag in ipairs(tags) do
		local c = colourOf(tag[2])
		local label = text(11)
		label:SetText(tag[1])
		label:SetTextColor(c[1], c[2], c[3])
		local lw = width(label, #tag[1] * 6) + 14
		if x + lw > WIDTH - PAD and x > PAD then
			x = PAD
			y = y + rowH + 4
		end
		local chip = rect("ARTWORK", 1)
		place(chip, x, y)
		chip:SetSize(lw, rowH)
		chip:SetColorTexture(c[1], c[2], c[3], 0.14)
		label:SetPoint("CENTER", chip, "CENTER", 0, 0)
		x = x + lw + 5
	end
	self.y = y + rowH
end

-- a note in the lore face, and who wrote it and when
function Builder:Quote(words, credit)
	local y = self.y + 8
	local fs = text(14, T.LORE)
	fs:SetWordWrap(true)
	fs:SetWidth(WIDTH - PAD * 2)
	fs:SetText(("\"%s\""):format(words or ""))
	fs:SetTextColor(0.92, 0.87, 0.77)
	place(fs, PAD, y)
	local lines = math.max(1, math.ceil(#(words or "") * 6.5 / (WIDTH - PAD * 2)))
	y = y + height(fs, 14, lines)
	if credit then
		local cr = text(11)
		cr:SetText(credit)
		cr:SetTextColor(DIM[1], DIM[2], DIM[3])
		cr:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, -(y + 4))
		cr:SetJustifyH("RIGHT")
		y = y + 17
	end
	self.y = y
end

-- every click: { { "Click", "open your bags" }, ... }
function Builder:Foot(clicks)
	if not (clicks and #clicks > 0) then
		return
	end
	local y = self.y + 10
	local band = rect("BACKGROUND", 3)
	place(band, 1, y)
	band:SetSize(WIDTH - 2, #clicks * 17 + 10)
	band:SetColorTexture(0, 0, 0, 0.22)
	local line = rect("ARTWORK", 1)
	place(line, 0, y)
	line:SetSize(WIDTH, 1)
	local h = BT.Widgets.HAIR
	line:SetColorTexture(h[1], h[2], h[3], h[4] or 0.6)
	y = y + 6
	for _, c in ipairs(clicks) do
		local key = text(9.5)
		key:SetText(string.upper(c[1]))
		key:SetTextColor(INK2[1], INK2[2], INK2[3])
		local kw = width(key, #c[1] * 6) + 10
		local cap = rect("ARTWORK", 1)
		place(cap, PAD, y)
		cap:SetSize(kw, 14)
		local r = BT.Widgets.RIM
		cap:SetColorTexture(r[1], r[2], r[3], 0.9)
		key:SetPoint("CENTER", cap, "CENTER", 0, 0)
		local what = text(11)
		what:SetText(c[2])
		what:SetTextColor(DIM[1], DIM[2], DIM[3])
		what:SetPoint("LEFT", cap, "RIGHT", 6, 0)
		y = y + 17
	end
	self.y = y + 3
	self.footed = true
end

-- ---------------------------------------------------------------------------
-- Showing one
-- ---------------------------------------------------------------------------

-- BESIDE THE DOCK, AT THE HEIGHT OF WHAT IS POINTED AT: on its side toward
-- the middle of the screen, so it never covers the dock itself
-- a frame's measurement, or nil where it has none to give
local function ask(f, method, fallback)
	if not (f and type(f[method]) == "function") then
		return fallback
	end
	local ok, v = pcall(f[method], f)
	return ok and N(v, fallback) or fallback
end

local function anchor(owner)
	frame:ClearAllPoints()
	local bar = BT.Bar and BT.Bar.Frame and BT.Bar.Frame()
	local screenW = ask(UIParent, "GetWidth", 0)
	local bl, br = ask(bar, "GetLeft"), ask(bar, "GetRight")
	local ol, or_ = ask(owner, "GetLeft"), ask(owner, "GetRight")
	local bs, os = ask(bar, "GetEffectiveScale", 1), ask(owner, "GetEffectiveScale", 1)
	local fs = ask(frame, "GetEffectiveScale", 1)
	if bl and br and ol and or_ and fs > 0 then
		local onRight = ((bl + br) / 2) * bs / ask(UIParent, "GetEffectiveScale", 1) > screenW / 2
		if onRight then
			local gap = (ol * os - bl * bs) / fs + 8
			frame:SetPoint("TOPRIGHT", owner, "TOPLEFT", -gap, 0)
		else
			local gap = (br * bs - or_ * os) / fs + 8
			frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 0)
		end
		return
	end
	frame:SetPoint("TOP", owner, "BOTTOM", 0, -6)
end

-- `spec` = { edge = colour, build = function(t) ... end }
function T.Show(owner, spec)
	if not (owner and spec and spec.build) then
		return nil
	end
	build()
	if GameTooltip and GameTooltip.Hide then
		GameTooltip:Hide()
	end
	for kind, list in pairs(pools) do
		for _, p in ipairs(list) do
			p:Hide()
		end
		used[kind] = 0
	end
	local edge = colourOf(spec.edge or BT.Widgets.ACCENT)
	frame.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
	local t = setmetatable({ y = 0, edge = edge, owner = owner }, Builder)
	local ok, err = pcall(spec.build, t)
	-- kept for the tests, which open every tooltip and ask whether one broke
	T.lastError = not ok and tostring(err) or nil
	if not ok then
		BT.Util.Print("Tooltip error: " .. tostring(err))
	end
	frame:SetHeight(t.y + (t.footed and 0 or 12))
	frame.owner = owner
	-- the dock's size, whatever the screen's
	local bar = BT.Bar and BT.Bar.Frame and BT.Bar.Frame()
	local scale = ask(bar, "GetEffectiveScale", 1) / ask(UIParent, "GetEffectiveScale", 1)
	frame:SetScale(scale > 0 and scale or 1)
	anchor(owner)
	frame.check = 0
	frame:Show()
	T.last = t
	return t
end

function T.Hide()
	if frame and frame:IsShown() then
		frame:Hide()
		frame.owner = nil
	end
end

function T.IsShown()
	return frame ~= nil and frame:IsShown()
end

-- what the last one said, for the tests: every piece of text in it, in order
function T.Texts()
	local out = {}
	for kind, list in pairs(pools) do
		if kind:find("^text:") then
			for i = 1, used[kind] or 0 do
				local fs = list[i]
				out[#out + 1] = fs:GetText()
			end
		end
	end
	return out
end

-- does the last one say `words` anywhere
function T.Says(words)
	for _, s in ipairs(T.Texts()) do
		if type(s) == "string" and s:find(words, 1, true) then
			return true
		end
	end
	return false
end
