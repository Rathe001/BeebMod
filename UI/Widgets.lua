-- The addon's own buttons (Josh 2026-09-19).
--
-- Everything was built on UIPanelButtonTemplate, which is Blizzard's red stone
-- button: fine in the character sheet, wrong in a panel that is otherwise flat
-- and dark, and nothing like the design. These are the design's: a dark fill, a
-- one-pixel rim, a label, and a pressed state that fills jade.
--
-- They are plain Buttons with our own textures, so nothing here can break when
-- a beta build renames a template.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Widgets.lua")

local W = {}
BT.Widgets = W

-- THE BUTTONS WEAR THE THEME (Josh 2026-09-21). These were locals copied at
-- the top of the file: two fixed grey-greens for a button at rest, and the
-- pressed and hover colours read from W.WASH, W.HOVER and W.ACCENT - which are
-- defined further DOWN, so all three were nil. A pressed button kept its idle
-- colours, and every button in the window was the same grey-green whatever
-- the theme was. They are read when a button is painted now, from tables the
-- theme writes into.
local IDLE_TEXT = { 0.70, 0.72, 0.72 }
local ON_TEXT = { 0.92, 0.94, 0.94 }
-- a ghost button has no block behind it: just the rim and the word
local CLEAR = { 0, 0, 0, 0 }

local function apply(b)
	local fill = b.pressed and W.WASH or (b.ghost and CLEAR or W.RAISED)
	local rim = b.pressed and W.ACCENT or (b.hovered and W.HOVER or W.RIM)
	local text = (b.pressed or b.hovered) and ON_TEXT or IDLE_TEXT
	-- through the panel, not at its textures: with a corner radius set, the
	-- shape a button is wearing is seven pieces and the flat one is hidden,
	-- so painting the flat one would lose the pressed state entirely
	BT.Pill.Recolour(b, fill, rim)
	if b.tint then
		b.label:SetTextColor(b.tint[1], b.tint[2], b.tint[3])
	else
		b.label:SetTextColor(text[1], text[2], text[3])
	end
end

function W.Button(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 80, height or 20)
	b.bg, b.rim = BT.Pill.Panel(b, W.RAISED, W.RIM)
	b.label = b:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	b.label:SetPoint("CENTER")
	b.label:SetText(text or "")

	b.SetLabel = function(self, t)
		self.label:SetText(t or "")
	end
	-- "pressed" is a state, not an animation: it means this tab is the one you
	-- are looking at, or this filter is the one that is on
	b.SetPressed = function(self, on)
		-- the same as it is: nothing to repaint (a page refresh presses every
		-- segment again, and each repaint rebuilt the button's whole shape)
		on = on and true or false
		if self.pressed == on then
			return
		end
		self.pressed = on
		apply(self)
	end
	b.SetTint = function(self, color)
		self.tint = color
		apply(self)
	end
	b:SetScript("OnEnter", function(self) self.hovered = true; apply(self) end)
	b:SetScript("OnLeave", function(self) self.hovered = false; apply(self) end)
	apply(b)
	return b
end

-- THE WAY OUT, DRAWN (Josh 2026-09-22). The close button was the letter x in a
-- rimmed box, which read as a stray key rather than a control. It is the cross
-- from the toolkit's own icon sheet now - the one a failed quest wears - with
-- no box round it: quiet at rest, the accent under the cursor.
local ICONS = "Interface\\AddOns\\BeebMod\\Art\\icons"
local QUIET = { 0.55, 0.63, 0.59, 1 }

function W.Close(parent, size)
	size = size or 18
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("CENTER")
	b.icon:SetSize(math.floor(size * 0.6 + 0.5), math.floor(size * 0.6 + 0.5))
	b.icon:SetTexture(ICONS)
	b.icon:SetTexCoord(0.75, 0.875, 0, 1)
	b.icon:SetVertexColor(QUIET[1], QUIET[2], QUIET[3], QUIET[4])
	b:SetScript("OnEnter", function(self)
		local a = W.ACCENT
		self.icon:SetVertexColor(a[1], a[2], a[3], 1)
	end)
	b:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(QUIET[1], QUIET[2], QUIET[3], QUIET[4])
	end)
	return b
end

-- A button that reads as the thing it does rather than as furniture: anything
-- that should not look like a tab.
function W.Ghost(parent, text, width, height)
	local b = W.Button(parent, text, width, height)
	b.ghost = true
	apply(b)
	return b
end

-- ONE SURFACE, EVERYWHERE (Josh 2026-09-19). The window, the dock, the note
-- panel and the tooltip each carried their own near-black with their own
-- alpha, which drifted apart every time one of them was touched. They share
-- these now, so "slightly transparent" is one number rather than five.
--
-- 0.88 is deliberate: enough that the world moves under a panel and it reads
-- as part of the game rather than a window pasted on top, and not so much that
-- a grey stone floor eats a grey line of text.
W.FILL = { 0.04, 0.06, 0.05, 0.88 }
W.RIM = { 0.16, 0.24, 0.21, 0.95 }
-- and the lit one: the tab you are on, the switch that is on, the glyph on the
-- dock. Mutated in place like the other two, so anything holding it keeps up.
W.ACCENT = { 0.31, 0.71, 0.55, 1 }
-- THE HIGHLIGHTS ARE THE ACCENT TOO (Josh 2026-09-21). The rail tab you are
-- on, the button that is pressed, the rim under the cursor and the knob of a
-- switch were four more greens written in by hand - so with a violet theme the
-- settings panel came up violet with green selections in it. They are all the
-- accent at different strengths now: a wash of it behind a selection, most of
-- it on a hover rim, and a pale version for the knob.
W.WASH = { 0.12, 0.22, 0.18, 0.95 }
W.HOVER = { 0.40, 0.62, 0.53, 1 }
W.KNOB = { 0.80, 0.96, 0.88, 1 }
-- a button at rest: the panel's own fill, lifted a step so it reads as
-- something you can press rather than a hole in the panel
W.RAISED = { 0.08, 0.11, 0.10, 0.95 }
-- THE WINDOW IS FOR READING (Josh 2026-09-23). 0.88 lets the world move
-- under the dock, which is the point of the dock; under a page of settings it
-- put nameplates behind the text. The window wears the same fill, nearly
-- solid. And the groups of rows inside it are rimmed with a quieter rim.
W.SOLID = { 0.04, 0.06, 0.05, 0.96 }
W.HAIR = { 0.16, 0.24, 0.21, 0.45 }

-- WHAT IS WEARING IT (Josh 2026-09-21). Most of these are set once, where the
-- texture is made, so a colour that can change later needs to know who took a
-- copy. Seventeen places had the toolkit's green written into them by hand and
-- every one of them stayed green when the theme moved on.
local tinted = setmetatable({}, { __mode = "k" })

-- AND EITHER SHAPE IS ACCEPTED (Josh 2026-09-21). A panel's rim is four bars
-- in a table now, so callers holding "the rim" hold a list. Taking both here
-- means a caller cannot pick the wrong one and find out in game.
local function eachTexture(target, fn)
	if type(target) ~= "table" then
		return 0
	end
	if target.SetColorTexture or target.SetVertexColor then
		fn(target)
		return 1
	end
	local n = 0
	for _, t in ipairs(target) do
		if type(t) == "table" and (t.SetColorTexture or t.SetVertexColor) then
			fn(t)
			n = n + 1
		end
	end
	return n
end

-- a glyph, coloured through its own art
-- off the theme's list: a texture that shows something else now
function W.Untint(tex)
	tinted[tex] = nil
end

function W.Tint(tex, alpha)
	if not (tex and tex.SetVertexColor) then
		return tex
	end
	tinted[tex] = { how = "vertex", alpha = alpha or 1 }
	tex:SetVertexColor(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], alpha or 1)
	return tex
end

-- which way a rule runs, by the one-unit side it was given. Asked again
-- until there is an answer: a texture made before its frame is laid out
-- reports no size at all, and the rule under the readout grid stayed a
-- smeared unit because it was asked only then.
local function near1(v)
	return type(v) == "number" and math.abs(v - 1) < 0.01
end

local function axisOf(tex)
	if tex.GetHeight and near1(tex:GetHeight()) then
		return "h"
	elseif tex.GetWidth and near1(tex:GetWidth()) then
		return "v"
	end
	return nil
end

-- A HAIRLINE IN THE RIM'S COLOUR (Josh 2026-09-21). The rules between a
-- header and what it heads were a grey-green written in by hand in five
-- places, and stayed that colour whatever the theme said.
-- `axis` ("h" or "v") says which way it runs; without it, it is worked out
-- from the side that is one unit.
function W.Rule(tex, alpha, axis)
	if not (tex and tex.SetColorTexture) then
		return tex
	end
	-- already a hairline: its size is no longer 1 to tell by
	axis = axis or (tinted[tex] and tinted[tex].axis) or axisOf(tex)
	tinted[tex] = { how = "rule", alpha = alpha or 0.9, axis = axis }
	tex:SetColorTexture(W.RIM[1], W.RIM[2], W.RIM[3], alpha or 0.9)
	W.Hairline(tex)
	return tex
end

-- ONE SCREEN PIXEL, NOT ONE UNIT (Josh 2026-09-22). With the interface scaled
-- by anything but a whole number, a line one unit thick is a pixel and a half
-- on screen, and the client smears it across two - a rule that reads as a
-- double line. Sized to exactly one physical pixel at the scale it is drawn
-- at, it is one crisp line. Done again whenever the panel lays out, since the
-- scale can change under it.
function W.Hairline(tex)
	local t = tinted[tex]
	if t and t.how == "rule" and not t.axis then
		t.axis = axisOf(tex)
	end
	local axis = t and t.axis
	if not (axis and tex.GetEffectiveScale) then
		return tex
	end
	-- one screen pixel, as the borders measure it (UI/Pill.lua, P.Px)
	local px = BT.Pill.Px(tex, 1)
	if px and px > 0 and (BT.Pill.PixelOf(tex) or (PixelUtil and PixelUtil.GetNearestPixelSize)) then
		if axis == "h" then
			tex:SetHeight(px)
		else
			tex:SetWidth(px)
		end
		BT.Pill.Snap(tex)
	end
	return tex
end

-- A WINDOW THAT HOLDS STILL AS IT MOVES (Josh 2026-09-23: "all the buttons
-- as well as hex colors and opacity is jumping around as I move the panel").
--
-- At an interface scale of 0.8 one unit is a pixel and a quarter, so anything
-- placed an even-but-not-fourth number of units into a panel - 2, 6, 10 -
-- lands exactly half way between two screen pixels. Half way is a tie, and
-- which way a tie breaks is decided by the last digit of a float: text (which
-- the client always puts on whole pixels) and edges jumped a pixel one way or
-- the other at each step of a drag, each on its own.
--
-- Moving the window a whole pixel at a time keeps every piece's fraction the
-- same, but a whole pixel exactly (the first attempt at this) keeps the ties
-- too, and made it worse. So the window sits an eighth of a pixel past a whole
-- one: every fraction a unit can land on - 0, a quarter, a half, three
-- quarters - is then an eighth clear of a tie, and rounds the same way at
-- every step. The same place is taken when the window opens and when it is
-- let go, so it holds still at rest too.
W.PIXEL_BIAS = 0.125

-- The window's top left corner an eighth past a whole screen pixel: where it
-- is, or at `left`, `top` (in its own units, from the screen's bottom left).
function W.SettleOnPixels(frame, left, top)
	local num = BT.Pill.Number
	local px = BT.Pill.PixelOf(frame)
	left = left or num(frame:GetLeft(), nil)
	top = top or num(frame:GetTop(), nil)
	if not (px and left and top) then
		return false
	end
	-- kept on the screen, as SetClampedToScreen would
	local s = num(frame:GetEffectiveScale(), 1)
	local ui = num(UIParent:GetEffectiveScale(), 1)
	local w, h = num(frame:GetWidth(), 0), num(frame:GetHeight(), 0)
	local screenW = num(UIParent:GetWidth(), 0) * ui / s
	local screenH = num(UIParent:GetHeight(), 0) * ui / s
	if screenW > w and screenH > h then
		left = math.max(0, math.min(left, screenW - w))
		top = math.max(h, math.min(top, screenH))
	end
	local function settle(v)
		return (math.floor(v / px) + W.PIXEL_BIAS) * px
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settle(left), settle(top))
	return true
end

-- Dragged by `handle` (the window itself by default), a pixel at a time.
local dragger
function W.PixelDrag(frame, handle)
	handle = handle or frame
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		local num = BT.Pill.Number
		local ok, cx, cy = pcall(GetCursorPosition)
		local s = num(frame:GetEffectiveScale(), 0)
		local left, top = num(frame:GetLeft(), nil), num(frame:GetTop(), nil)
		if not (ok and tonumber(cx) and tonumber(cy) and s > 0 and left and top and BT.Pill.PixelOf(frame)) then
			-- nothing to measure with: the client moves it, and it is settled
			-- when it lands
			frame.bmNativeDrag = true
			frame:StartMoving()
			return
		end
		local dx, dy = cx / s - left, cy / s - top
		dragger = dragger or CreateFrame("Frame")
		W.dragger = dragger
		dragger.frame = frame
		local lastX, lastY
		dragger:SetScript("OnUpdate", function(self)
			-- the window closed, or the button let go somewhere the client
			-- never told us about: the drag is over
			local held = type(IsMouseButtonDown) ~= "function" or IsMouseButtonDown("LeftButton")
			if not frame:IsShown() or not held then
				self:SetScript("OnUpdate", nil)
				self.frame = nil
				W.SettleOnPixels(frame)
				return
			end
			local ok2, x, y = pcall(GetCursorPosition)
			-- and nothing moved while the cursor did not
			if ok2 and tonumber(x) and tonumber(y) and (x ~= lastX or y ~= lastY) then
				lastX, lastY = x, y
				W.SettleOnPixels(frame, x / s - dx, y / s - dy)
			end
		end)
	end)
	handle:SetScript("OnDragStop", function()
		if frame.bmNativeDrag then
			frame.bmNativeDrag = nil
			frame:StopMovingOrSizing()
		end
		if dragger and dragger.frame == frame then
			dragger:SetScript("OnUpdate", nil)
			dragger.frame = nil
		end
		W.SettleOnPixels(frame)
		-- and kept where it was left, as a window the client moved is
		if frame.SetUserPlaced then
			pcall(frame.SetUserPlaced, frame, true)
		end
	end)
	-- settled whenever it opens: its first place is a centre, which lands
	-- wherever the window's size puts it
	if frame.HookScript then
		frame:HookScript("OnShow", function(self)
			W.SettleOnPixels(self)
		end)
	end
end

-- A NEW SCALE IS A NEW PIXEL: every border and rule is measured again when
-- the interface scale or the screen changes, a frame later, once the client
-- has settled the new scale
do
	local watch = CreateFrame("Frame")
	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		pcall(watch.RegisterEvent, watch, event)
	end
	-- EVERYTHING, ONCE (Josh 2026-09-23, audit): only the panels were
	-- repainted, so the skins on the action bars, bags and sheet slots kept
	-- the old pixel's thickness; and a resize fires a burst of these, each of
	-- which repainted it all. The theme's own pass repaints every panel and
	-- has every module restyle what it dressed - once, a frame after the last.
	local queued = false
	local function redo()
		queued = false
		if BT.Theme and BT.Theme.Apply then
			pcall(BT.Theme.Apply)
		else
			BT.Pill.RepaintAll()
		end
		W.Hairlines()
	end
	watch:SetScript("OnEvent", function()
		if queued then
			return
		end
		if C_Timer and C_Timer.After then
			queued = true
			C_Timer.After(0, redo)
		else
			redo()
		end
	end)
	W.scaleWatch = watch
end

-- /bt pixels: what the borders were measured with, to check the sums in game;
-- /bt pixels snap on|off to compare the borders with and without the grid
BT.Command("pixels", function(arg)
	local P = BT.Pill
	local want = tostring(arg or ""):match("^%s*snap%s+(%a+)")
	if want == "on" or want == "off" then
		P.snapping = want == "on"
		P.RepaintAll()
		W.Hairlines()
		BT.Util.Print(("Pixels: snapping borders to the pixel grid is %s until you reload."):format(want))
		return
	end
	local ok, w, h = pcall(GetPhysicalScreenSize or error)
	local ui = P.Number(UIParent:GetEffectiveScale(), 0)
	BT.Util.Print(("Pixels: screen %s x %s · interface scale %.4f · PixelUtil %s"):format(tostring(ok and w), tostring(ok and h),
		ui, (PixelUtil and PixelUtil.GetNearestPixelSize) and "yes" or "no"))
	local px = P.PixelOf(UIParent)
	local pu = "none"
	if PixelUtil and PixelUtil.GetNearestPixelSize then
		local okP, v = pcall(PixelUtil.GetNearestPixelSize, 1, ui, 1)
		pu = okP and tostring(v) or "error"
	end
	BT.Util.Print(("Pixels: 1 screen pixel is %s units by the screen's height and %s by PixelUtil. A border of 1 is %s."):format(
		px and ("%.4f"):format(px) or "unknown", pu, tostring(P.Px(UIParent, 1))))
	BT.Util.Print("Pixels: snapping to the grid is " .. (P.snapping and "on" or "off") .. ".")
	for _, name in ipairs({ "BeebModWindow", "BeebModCensus", "GameTooltip" }) do
		local f = _G[name]
		if f and f.IsShown and f:IsShown() then
			local fpx = P.PixelOf(f)
			local l, t = P.Number(f:GetLeft(), nil), P.Number(f:GetTop(), nil)
			if fpx and l and t then
				BT.Util.Print(("%s: scale %.4f · corner at %.2f, %.2f screen pixels"):format(name,
					P.Number(f:GetEffectiveScale(), 0), l / fpx, t / fpx))
			end
		end
	end
	local okC, cx, cy = pcall(GetCursorPosition)
	if okC then
		BT.Util.Print(("Pixels: cursor at %s, %s"):format(tostring(cx), tostring(cy)))
	end
end, "pixels - show how borders are measured on this screen")

function W.Hairlines()
	for tex in pairs(tinted) do
		W.Hairline(tex)
	end
end

-- a flat block of the accent
--
-- NOT "Paint" (Josh 2026-09-21). There is already a W.Paint further down that
-- takes a FRAME and makes a texture on it; defining a second one with the same
-- name and a different signature meant the later definition simply replaced
-- this one, and every call here reached the wrong function - Window.lua handed
-- it a Texture and got "attempt to call a nil value" on CreateTexture. The
-- test harness could not see it: its stub answers every method, so calling
-- CreateTexture on a texture quietly worked.
function W.Lit(tex, alpha)
	local painted = eachTexture(tex, function(t)
		if t.SetColorTexture then
			tinted[t] = { how = "colour", alpha = alpha or 1 }
			t:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], alpha or 1)
		end
	end)
	return tex
end

-- a piece of text in the accent: a group heading on a page of settings
function W.TintText(fs, alpha)
	if not (fs and fs.SetTextColor) then
		return fs
	end
	tinted[fs] = { how = "text", alpha = alpha or 1 }
	fs:SetTextColor(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], alpha or 1)
	return fs
end

function W.Retint()
	local n = 0
	for tex, how in pairs(tinted) do
		local fn = (how.how == "vertex") and tex.SetVertexColor
			or (how.how == "text") and tex.SetTextColor or tex.SetColorTexture
		local c = (how.how == "rule") and W.RIM or W.ACCENT
		if fn then
			pcall(fn, tex, c[1], c[2], c[3], how.alpha)
			n = n + 1
		end
	end
	return n
end

-- the tests want to know what is on the list
function W.Tinted()
	return tinted
end

-- One dark panel with a rim, for the window and anything inside it.
function W.Panel(frame, fill, rim)
	return BT.Pill.Panel(frame, fill or W.FILL, rim or W.RIM)
end

-- A hairline, for separating a header from what it heads.
function W.Divider(frame, inset, y)
	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", inset or 0, y or 0)
	line:SetPoint("TOPRIGHT", -(inset or 0), y or 0)
	line:SetHeight(1)
	W.Rule(line, nil, "h")
	return line
end

-- A SWITCH, NOT A CHECKBOX (Josh 2026-09-19). Settings here are "is this
-- utility on", which is a state you flip, and a switch says that where a tick
-- says "have you agreed". Built from the same pill as the tags, so the window
-- has one shape in it rather than three.
function W.Switch(parent, onChange)
	local s = CreateFrame("Button", nil, parent)
	BT.Pill.Skin(s)
	-- Resize, not SetSize: the caps are half the height and are only worked
	-- out in here. A switch that skips it keeps whatever cap width the skin
	-- guessed, which is how you get a track with square ends (Josh 2026-09-19).
	BT.Pill.Resize(s, 34, 18)
	s.knob = BT.Pill.Skin(CreateFrame("Frame", nil, s))
	BT.Pill.Resize(s.knob, 12, 12)
	s.knob:SetPoint("LEFT", 3, 0)

	-- OFF IS A WELL, NOT A DIMMER ON (Josh 2026-09-23). Off was the accent's
	-- shape in a muted grey-green, which on an olive theme was the same olive
	-- a step darker: four switches in a column could not be told apart at a
	-- glance. Off is a dark well now with a grey knob, on is the accent with a
	-- pale one, and the knob's side says it as well as the colour.
	s.Paint = function(self)
		local on = self.on
		BT.Pill.Color(self, on and W.ACCENT or { 0.13, 0.15, 0.14 }, true)
		BT.Pill.Color(self.knob, on and W.KNOB or { 0.46, 0.50, 0.48 }, true)
		self.knob:ClearAllPoints()
		if on then
			self.knob:SetPoint("RIGHT", -3, 0)
		else
			self.knob:SetPoint("LEFT", 3, 0)
		end
	end
	s.SetOn = function(self, on)
		self.on = on and true or false
		self:Paint()
	end
	s.IsOn = function(self)
		return self.on and true or false
	end
	s:SetScript("OnClick", function(self)
		self:SetOn(not self.on)
		if onChange then
			onChange(self.on)
		end
	end)
	s:SetOn(false)
	return s
end

-- Two one-liners every panel in the toolkit was writing for itself: a piece of
-- text, and a flat block of colour.
function W.Label(parent, text, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY",
		size == "small" and "BeebModFontHighlightSmall" or "BeebModFontNormal")
	fs:SetText(text or "")
	if r then
		fs:SetTextColor(r, g, b)
	end
	return fs
end

function W.Paint(frame, r, g, b, a)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

-- A DROP SHADOW (Josh 2026-09-22). There is no blur in this client, so it is
-- built the way one was built before there was: rings a pixel further out
-- and fainter each time. Only the rings are drawn - four strips each, all
-- outside the frame - so a see-through surface is not darkened from behind.
-- Lower rings are a touch heavier than upper ones: light from above.
local SHADOW = { 0.30, 0.18, 0.10, 0.05 }

function W.Shadow(frame)
	if frame.bmShadow then
		return frame.bmShadow
	end
	local strips = {}
	local function strip(a)
		local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		-- ours: the furniture dresser takes pieces it does not know for the
		-- client's art and fades them (the meter lost its shadow that way)
		t.beebs = true
		t:SetColorTexture(0, 0, 0, a)
		strips[#strips + 1] = t
		return t
	end
	for i, a in ipairs(SHADOW) do
		local top = strip(a * 0.6)
		top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -(i - 1), i - 1)
		top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", i - 1, i - 1)
		top:SetHeight(1)
		local bottom = strip(a)
		bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -(i - 1), -(i - 1))
		bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", i - 1, -(i - 1))
		bottom:SetHeight(1)
		local left = strip(a * 0.8)
		left:SetPoint("TOPRIGHT", frame, "TOPLEFT", -(i - 1), i - 1)
		left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -(i - 1), -(i - 1))
		left:SetWidth(1)
		local right = strip(a * 0.8)
		right:SetPoint("TOPLEFT", frame, "TOPRIGHT", i - 1, i - 1)
		right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", i - 1, -(i - 1))
		right:SetWidth(1)
	end
	frame.bmShadow = strips
	return strips
end

function W.ShowShadow(frame, on)
	for _, t in ipairs(frame.bmShadow or {}) do
		t:SetShown(on)
	end
end

-- black fading from `from` to `to` alpha, left to right; flat at the
-- average on a build with no gradients
function W.Fade(tex, from, to)
	-- white underneath: the gradient is a tint, and multiplies what is there
	tex:SetColorTexture(1, 1, 1, 1)
	local ok = false
	if tex.SetGradient and CreateColor then
		ok = pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(0, 0, 0, from), CreateColor(0, 0, 0, to))
	end
	if not ok and tex.SetGradientAlpha then
		ok = pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", 0, 0, 0, from, 0, 0, 0, to)
	end
	if not ok then
		tex:SetColorTexture(0, 0, 0, (from + to) / 2)
	end
	return tex
end

-- ---------------------------------------------------------------------------
-- A PAGE OF SETTINGS (Josh 2026-09-23)
--
-- Six modules each carried their own copy of the same fifteen lines - a
-- frame, a label, a grey line under it, a switch at the right - and each copy
-- had drifted: gold labels in one, white in the next, the switch two pixels
-- lower in a third. These are the one copy.
--
--   local page = W.Stack(parent)
--   local look = page:Section("Look")
--   W.SwitchRow(look, "Hotkeys", "the binding in the corner", get, set)
--   page:Layout()
--
-- A section is a small heading in the accent and a rimmed group under it, a
-- hairline between its rows. A row is its label, one grey line saying what it
-- does, and a control in the column down the right.
-- ---------------------------------------------------------------------------
W.ROW_H, W.ROW_SHORT = 40, 30
-- the width of a page of the settings window, for anything measured before
-- the client has laid the page out (see UI/Window.lua)
W.PAGE_W = 566
local SUB = { 0.50, 0.55, 0.53 }
local HEAD_H, SECTION_GAP, CONTROL_W = 18, 14, 150

-- every switch row that knows how to read its own setting, so a page can be
-- brought up to date in one call when it is shown
local syncing = setmetatable({}, { __mode = "k" })

function W.Row(parent, title, blurb, opts)
	opts = opts or {}
	local holder = parent.group or parent
	local r = CreateFrame("Frame", nil, holder)
	local short = not blurb or blurb == ""
	r:SetHeight(short and W.ROW_SHORT or W.ROW_H)
	local x = 10 + (opts.indent or 0)
	-- white, always: W.Label's default is the client's gold, which is how
	-- three rows of the Settings tab came out a different colour from the
	-- four above them
	r.label = r:CreateFontString(nil, "OVERLAY", opts.indent and "BeebModFontHighlightSmall" or "BeebModFontHighlight")
	r.label:SetJustifyH("LEFT")
	r.label:SetText(title or "")
	r.blurb = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	r.blurb:SetJustifyH("LEFT")
	r.blurb:SetTextColor(SUB[1], SUB[2], SUB[3])
	r.blurb:SetWordWrap(false)
	r.blurb:SetText(blurb or "")
	if short then
		r.label:SetPoint("LEFT", x, 0)
	else
		r.label:SetPoint("TOPLEFT", x, -7)
		r.blurb:SetPoint("TOPLEFT", x, -23)
		r.blurb:SetPoint("TOPRIGHT", -CONTROL_W, -23)
	end
	-- the hairline above every row but a section's first
	r.hair = r:CreateTexture(nil, "ARTWORK")
	r.hair:SetPoint("TOPLEFT", 1, 0)
	r.hair:SetPoint("TOPRIGHT", -1, 0)
	r.hair:SetHeight(1)
	W.Rule(r.hair, 0.5, "h")
	r.SetControl = function(self, control)
		control:SetParent(self)
		control:ClearAllPoints()
		control:SetPoint("RIGHT", self, "RIGHT", -10, 0)
		self.control = control
		return control
	end
	if parent.Add then
		parent:Add(r)
	end
	return r
end

-- a row with a switch; `get` reads the setting, `set` is handed the new state
function W.SwitchRow(parent, title, blurb, get, set, opts)
	local r = W.Row(parent, title, blurb, opts)
	r.switch = r:SetControl(W.Switch(r, function(on)
		if set then
			set(on)
		end
	end))
	r.get = get
	if get then
		syncing[r] = true
		local ok, on = pcall(get)
		r.switch:SetOn(ok and on)
	end
	return r
end

-- every switch row back in step with what it switches
function W.SyncRows()
	for r in pairs(syncing) do
		local ok, on = pcall(r.get)
		if ok then
			r.switch:SetOn(on)
		end
	end
end

-- every switch row there is, for the tests to find one by what it switches
function W.Rows()
	local out = {}
	for r in pairs(syncing) do
		out[#out + 1] = r
	end
	return out
end

-- two buttons and a value between them: a size, a scale
function W.Stepper(parent, onStep)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(96, 20)
	f.minus = W.Button(f, "-", 22, 20)
	f.minus:SetPoint("LEFT", 0, 0)
	f.plus = W.Button(f, "+", 22, 20)
	f.plus:SetPoint("RIGHT", 0, 0)
	f.value = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	f.value:SetPoint("CENTER")
	f.minus:SetScript("OnClick", function() onStep(-1) end)
	f.plus:SetScript("OnClick", function() onStep(1) end)
	f.Say = function(self, text)
		self.value:SetText(text or "")
	end
	return f
end

-- Buttons joined into one control, one of them chosen. Each button keeps its
-- key, and `Select` presses the one that matches.
function W.Segmented(parent, options, onPick, width)
	local seg = CreateFrame("Frame", nil, parent)
	width = width or 62
	seg:SetSize(#options * (width - 1) + 1, 20)
	seg.buttons = {}
	for i, o in ipairs(options) do
		local b = W.Button(seg, o[2], width, 20)
		-- one unit of overlap, so two rims make one line between them
		b:SetPoint("LEFT", seg, "LEFT", (i - 1) * (width - 1), 0)
		b.key = o[1]
		b:SetScript("OnClick", function(self)
			seg:Select(self.key)
			if onPick then
				onPick(self.key)
			end
		end)
		seg.buttons[#seg.buttons + 1] = b
	end
	seg.Select = function(self, key)
		for _, b in ipairs(self.buttons) do
			b:SetPressed(b.key == key)
		end
	end
	return seg
end

-- A heading and a group of rows. Rows are laid out top to bottom in the order
-- they were added; a hidden row takes no room, so a section can put away rows
-- that do not apply (a rogue's line, a setting under a switch that is off).
function W.Section(parent, title)
	local s = CreateFrame("Frame", nil, parent)
	s.head = s:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	s.head:SetPoint("TOPLEFT", 2, 0)
	s.head:SetText(string.upper(title or ""))
	W.TintText(s.head, 0.8)
	s.group = CreateFrame("Frame", nil, s)
	s.group:SetPoint("TOPLEFT", 0, -HEAD_H)
	s.group:SetPoint("TOPRIGHT", 0, -HEAD_H)
	BT.Pill.Panel(s.group, W.RAISED, W.HAIR)
	s.rows = {}
	s.Add = function(self, row)
		self.rows[#self.rows + 1] = row
		return row
	end
	s.Layout = function(self)
		local y, first = 0, true
		for _, r in ipairs(self.rows) do
			if r:IsShown() then
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", self.group, "TOPLEFT", 0, -y)
				r:SetPoint("TOPRIGHT", self.group, "TOPRIGHT", 0, -y)
				r.hair:SetShown(not first)
				first = false
				y = y + BT.Pill.Number(r:GetHeight(), W.ROW_H)
			end
		end
		self.group:SetHeight(math.max(y, 1))
		self:SetShown(y > 0)
		local h = y > 0 and (HEAD_H + y) or 0
		self:SetHeight(math.max(h, 1))
		return h
	end
	return s
end

-- A line or two of plain words on a page: what a utility is, where it lives.
function W.Note(parent, text, quiet)
	local f = CreateFrame("Frame", nil, parent)
	f.text = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	f.text:SetPoint("TOPLEFT", 2, 0)
	f.text:SetPoint("TOPRIGHT", -2, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(true)
	f.text:SetText(text or "")
	local c = quiet and SUB or { 0.68, 0.73, 0.71 }
	f.text:SetTextColor(c[1], c[2], c[3])
	-- MEASURED AGAINST THE PAGE, NOT THE LAYOUT (Josh 2026-09-23). A page is
	-- laid out when it is built, before the client has given it a width, and a
	-- string with no width to wrap in measures one line tall - so a two-line
	-- note had the next thing on the page drawn over its second line. The
	-- lines are counted from the page's width instead (the window's, when the
	-- page has none yet) and the unwrapped width of the words.
	f.Measure = function(self)
		local num = BT.Pill.Number
		local width = num(parent:GetWidth(), 0)
		if width <= 0 then
			width = W.PAGE_W
		end
		local words = num(self.text:GetStringWidth(), 0)
		-- a line breaks at a word, not at the last letter that fits, so a
		-- line holds less than its width: a tenth more, or a note at just
		-- under two widths wrapped to three lines and was measured as two
		-- (Josh 2026-09-23, audit)
		local lines = math.max(1, math.ceil(words * 1.1 / math.max(1, width - 4)))
		local lineH = 12
		local _, size = self.text:GetFont()
		size = num(size, nil)
		if size and size > 0 then
			lineH = size + 2
		end
		local h = lines * lineH
		self:SetHeight(h)
		return h
	end
	return f
end

-- Sections and notes down a page, one under the other.
-- ---------------------------------------------------------------------------
-- A place that scrolls
-- ---------------------------------------------------------------------------
--
-- MORE THAN FITS, A WHEEL AWAY (Josh 2026-09-24: "add scrolling to both the
-- left rail and content of the settings panel"). A window onto a taller
-- strip: `view` clips, `view.content` is what things are built into, and the
-- wheel moves the strip. A hairline thumb at the edge shows where you are,
-- and only while there is more than fits. A strip shorter than the window is
-- the window's height, so what is pinned to its foot stays at the foot.
function W.Scroller(parent, gutter)
	local view = CreateFrame("Frame", nil, parent)
	pcall(view.SetClipsChildren, view, true)
	local content = CreateFrame("Frame", nil, view)
	content:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
	content:SetPoint("TOPRIGHT", view, "TOPRIGHT", -(gutter or 0), 0)
	content:SetHeight(1)
	content.beebsScroller = view
	view.content = content
	view.offset, view.wanted, view.step = 0, 0, 40
	view.thumb = view:CreateTexture(nil, "OVERLAY")
	view.thumb:SetWidth(2)
	view.thumb:Hide()
	W.Lit(view.thumb, 0.55)
	-- A THUMB TO TAKE HOLD OF (Josh 2026-09-27: "not able to drag the scroll
	-- bar"). The hairline stays a hairline; over it, a strip wider than it
	-- takes the pointer: drag it and the strip follows, and it brightens and
	-- thickens while the pointer is on it. A click in the gutter above or below
	-- it goes a window's height that way.
	local grip = CreateFrame("Button", nil, view)
	grip:SetPoint("TOPRIGHT", view.thumb, "TOPRIGHT", 0, 0)
	grip:SetPoint("BOTTOMRIGHT", view.thumb, "BOTTOMRIGHT", 0, 0)
	grip:SetWidth(math.max(8, gutter or 0))
	grip:SetFrameLevel(view:GetFrameLevel() + 20)
	grip:Hide()
	view.grip = grip
	local function cursorY()
		local ok, _, y = pcall(GetCursorPosition)
		local scale = BT.Pill.Number(view.GetEffectiveScale and view:GetEffectiveScale(), 1)
		return (ok and BT.Pill.Number(y, 0) or 0) / (scale > 0 and scale or 1)
	end
	local function lit(on)
		view.thumb:SetWidth(on and 4 or 2)
		W.Lit(view.thumb, on and 0.85 or 0.55)
	end
	grip:SetScript("OnEnter", function() lit(true) end)
	grip:SetScript("OnLeave", function(self)
		if not self.dragging then
			lit(false)
		end
	end)
	grip:SetScript("OnMouseDown", function(self)
		self.dragging = { y = cursorY(), offset = view.offset }
	end)
	grip:SetScript("OnMouseUp", function(self)
		self.dragging = nil
		lit(self.IsMouseOver and self:IsMouseOver() or false)
		-- a strip that rests only in certain places goes to the nearest
		if view.Settle then
			view:Settle()
		end
	end)
	grip:SetScript("OnUpdate", function(self)
		local d = self.dragging
		if not d then
			return
		end
		-- the thumb's travel is the strip's: a pixel of one is this much of the other
		local room, max = view:Room(), view:Max()
		local travel = room - BT.Pill.Number(view.thumb:GetHeight(), 0)
		if max <= 0 or travel <= 0 then
			return
		end
		view:ScrollTo(d.offset + (d.y - cursorY()) * max / travel)
	end)
	-- the gutter: a click above the thumb goes up a window, below it down one
	local track = CreateFrame("Button", nil, view)
	track:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", 0, 0)
	track:SetWidth(math.max(8, gutter or 0))
	track:SetFrameLevel(view:GetFrameLevel() + 19)
	track:Hide()
	view.track = track
	track:SetScript("OnMouseDown", function()
		local top = BT.Pill.Number(view.thumb:GetTop(), nil)
		local y = cursorY()
		if not top then
			return
		end
		local page = math.max(view.step or 40, view:Room() - (view.step or 40))
		view:ScrollBy(y > top and -page or page)
		if view.Settle then
			view:Settle()
		end
	end)

	function view:Room()
		return BT.Pill.Number(self:GetHeight(), 0)
	end
	-- how far down it can go
	function view:Max()
		return math.max(0, (self.wanted or 0) - self:Room())
	end
	function view:ScrollTo(y)
		y = math.max(0, math.min(self:Max(), math.floor((y or 0) + 0.5)))
		self.offset = y
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
		content:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(gutter or 0), y)
		local room, max = self:Room(), self:Max()
		if max > 0 and room > 0 then
			local share = room / (room + max)
			local h = math.max(12, math.floor(room * share))
			self.thumb:SetHeight(h)
			self.thumb:ClearAllPoints()
			self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -math.floor((room - h) * (y / max)))
			self.thumb:Show()
			self.grip:Show()
			self.track:Show()
		else
			self.thumb:Hide()
			self.grip:Hide()
			self.track:Hide()
		end
		return y
	end
	function view:ScrollBy(dy)
		return self:ScrollTo(self.offset + dy)
	end
	-- the strip's height: what it holds, and never less than the window
	function view:SetContentHeight(h)
		self.wanted = math.max(0, h or 0)
		content:SetHeight(math.max(1, self.wanted, self:Room()))
		return self:ScrollTo(self.offset)
	end
	-- measured, for what was not laid out by a Stack: how far below the top of
	-- the strip the lowest thing in it reaches
	function view:Fit()
		local top = BT.Pill.Number(content:GetTop(), nil)
		if not top then
			return nil
		end
		local low = top
		local function reach(f)
			local b = BT.Pill.Number(f.GetBottom and f:GetBottom(), nil)
			if b and b < low and f.IsShown and f:IsShown() then
				low = b
			end
		end
		local okK, kids = pcall(function() return { content:GetChildren() } end)
		for _, k in ipairs(okK and kids or {}) do
			reach(k)
		end
		local okR, regions = pcall(function() return { content:GetRegions() } end)
		for _, r in ipairs(okR and regions or {}) do
			reach(r)
		end
		local h = math.ceil(top - low + 8)
		self:SetContentHeight(h)
		return h
	end
	view:EnableMouseWheel(true)
	view:SetScript("OnMouseWheel", function(self, delta)
		self:ScrollBy(-(delta or 0) * self.step)
	end)
	view:HookScript("OnSizeChanged", function(self)
		self:SetContentHeight(self.wanted)
	end)
	return view
end

function W.Stack(parent)
	local st = { parent = parent, items = {} }
	st.Section = function(self, title)
		local s = W.Section(parent, title)
		self.items[#self.items + 1] = s
		return s
	end
	st.Note = function(self, text, quiet)
		local n = W.Note(parent, text, quiet)
		self.items[#self.items + 1] = n
		return n
	end
	-- anything else with a height of its own: a preview, a list
	st.Add = function(self, frame)
		self.items[#self.items + 1] = frame
		return frame
	end
	st.Layout = function(self)
		local y, last = 0, nil
		for _, item in ipairs(self.items) do
			local h
			if item.Layout then
				h = item:Layout()
			elseif item.Measure then
				h = item:Measure()
			else
				h = BT.Pill.Number(item:GetHeight(), 0)
			end
			if item:IsShown() and h > 0 then
				-- a note under a note is the same paragraph going on
				if last then
					y = y + ((item.Measure and last.Measure) and 4 or SECTION_GAP)
				end
				item:ClearAllPoints()
				item:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
				item:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
				y = y + h
				last = item
			end
		end
		self.height = y
		parent.beebsStackHeight = y
		-- built into a place that scrolls: it is told how tall the page is
		if parent.beebsScroller then
			parent.beebsScroller.stacked = true
			parent.beebsScroller:SetContentHeight(y + 12)
		end
		return y
	end
	return st
end
