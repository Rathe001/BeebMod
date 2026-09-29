-- One pill, drawn three ways (Josh 2026-09-19).
--
-- A tag looks the same wherever it appears: on a card, on a unit tooltip, and
-- on the button that sets it. That is one shape, so it is one file.
--
-- WoW draws rectangles; a rounded corner needs art. Art/pill.tga is a 32x32
-- rounded rectangle whose ALPHA carries the shape - a solid rim, a faint
-- interior - in white, so a single vertex colour tints the rim and the fill
-- together. It is sliced in three: the left cap, a stretched middle, the right
-- cap, which is what lets one 32-pixel texture be a pill of any width without
-- the corners smearing.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Pill.lua")

local P = {}
BT.Pill = P

-- ONE ADDON, ONE PATH (Josh 2026-09-19). This still said AddOns\\Ledger after the
-- toolkit absorbed it, and a texture path that does not exist renders as
-- nothing at all rather than as an error: every tag went on showing its
-- label with no pill behind it.
local TEX = "Interface\\AddOns\\BeebMod\\Art\\pill"
-- The texture is a stadium: each cap is a half-circle as tall as the whole
-- image. So a cap must be drawn HALF AS WIDE AS THE PILL IS TALL, or the curve
-- comes out squashed - which is what "the radius is not even horizontally and
-- vertically" looks like (Josh 2026-09-19).
local function capWidth(height)
	return math.max(4, (height or 18) / 2)
end

-- Turns a frame into a pill. Call once; colour it as often as you like.
function P.Skin(frame)
	if frame.pillLeft then
		return frame
	end
	local left = frame:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(TEX)
	left:SetTexCoord(0, 0.5, 0, 1)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(capWidth(18))

	local right = frame:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(TEX)
	right:SetTexCoord(0.5, 1, 0, 1)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(capWidth(18))

	-- the middle is a two-pixel column of the texture, stretched: straight
	-- edges top and bottom, no corners to smear
	local mid = frame:CreateTexture(nil, "BACKGROUND")
	mid:SetTexture(TEX)
	mid:SetTexCoord(15 / 32, 17 / 32, 0, 1)
	mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
	mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	frame.pillLeft, frame.pillMid, frame.pillRight = left, mid, right
	return frame
end

-- Size a pill: the caps follow the height, so the ends stay circular whatever
-- the label says. Use this instead of SetSize on anything skinned.
function P.Resize(frame, width, height)
	frame:SetSize(width, height)
	if frame.pillLeft then
		local cap = capWidth(height)
		frame.pillLeft:SetWidth(cap)
		frame.pillRight:SetWidth(cap)
	end
	return frame
end

-- A ROUNDED RECTANGLE (Josh 2026-09-21). WoW draws squares. The cross
-- between the four corners is three plain bars, and at radius 0 nothing
-- rounded is built at all, because most of this addon does not want rounding
-- and should not pay for it.
--
-- CORNERS DRAWN IN PIXELS, NOT FROM A PICTURE (Josh 2026-09-23: "the images
-- we use for the border radius still flicker"). Each corner was a quarter of
-- a disc image (Art/corner.tga) stretched to the radius. A picture that lands
-- between two screen pixels is resampled, and resampled differently at every
-- step as a window moves, so the arcs shimmered while the flat edges beside
-- them - plain colour, which the screen either covers or does not - held
-- still. Each corner is now drawn the way the edges are: a stack of rows one
-- screen pixel high, each as long as the circle is wide at that height, with
-- one part-coloured pixel at its end for the curve's smoothing. The corner's
-- box is an invisible square the rows hang off; the radius is a whole number
-- of screen pixels, so the rows and the straight edges meet exactly.
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local function roundLayer(frame, layer, sub)
	local o = { corners = {}, rows = {}, bars = {}, frame = frame, layer = layer, sub = sub }
	for _, name in ipairs(CORNERS) do
		-- the box: never drawn, only hung from
		local t = frame:CreateTexture(nil, layer, nil, sub)
		t.beebs = true
		t:Hide()
		o.corners[name] = t
		o.rows[name] = {}
	end
	for i = 1, 3 do
		local t = frame:CreateTexture(nil, layer, nil, sub)
		t.beebs = true
		o.bars[i] = t
	end
	return o
end

-- the n-th row texture of a corner, made the first time it is wanted
local function rowTexture(o, name, n)
	local list = o.rows[name]
	if not list[n] then
		local t = o.frame:CreateTexture(nil, o.layer, nil, o.sub)
		t.beebs = true
		list[n] = t
	end
	return list[n]
end

-- One corner's rows, for a circle `R` screen pixels across, each pixel `px`
-- units. The rows run from the corner's outer edge inward; each is anchored
-- on the side of the box that faces into the panel, and the circle's centre
-- is the box's inner corner.
local function drawCorner(o, name, box, R, px, r, g, b, a)
	local top = name == "TOPLEFT" or name == "TOPRIGHT"
	local left = name == "TOPLEFT" or name == "BOTTOMLEFT"
	local point = (top and "TOP" or "BOTTOM") .. (left and "RIGHT" or "LEFT")
	local sv, sh = top and -1 or 1, left and -1 or 1
	local n = 0
	for j = 0, R - 1 do
		local dy = R - (j + 0.5)
		local w = math.sqrt(math.max(0, R * R - dy * dy))
		local whole = math.floor(w)
		local part = w - whole
		if whole > 0 then
			n = n + 1
			local t = rowTexture(o, name, n)
			t:ClearAllPoints()
			t:SetPoint(point, box, point, 0, sv * j * px)
			t:SetSize(whole * px, px)
			t:SetColorTexture(r, g, b, a)
			P.Snap(t)
			t:Show()
		end
		if part > 0.02 then
			n = n + 1
			local t = rowTexture(o, name, n)
			t:ClearAllPoints()
			t:SetPoint(point, box, point, sh * whole * px, sv * j * px)
			t:SetSize(px, px)
			t:SetColorTexture(r, g, b, a * part)
			P.Snap(t)
			t:Show()
		end
	end
	local list = o.rows[name]
	for k = n + 1, #list do
		list[k]:Hide()
	end
	-- how many this corner draws, for showing them again (P.ShowSurface)
	o.used = o.used or {}
	o.used[name] = n
end

-- a rounded layer's drawn rows shown again after a hide, without redrawing
local function showRows(o)
	if not (o and o.rows) then
		return
	end
	for name, list in pairs(o.rows) do
		for k = 1, (o.used and o.used[name]) or 0 do
			if list[k] then
				list[k]:Show()
			end
		end
	end
end

-- inset: how far in from the frame's edge this layer starts. radius: how round.
local function placeRound(o, frame, inset, radius, c)
	local r, g, b, a = c[1], c[2], c[3], c[4] or 1
	local px = P.Px(frame, 1) or 1
	local R = math.max(1, math.floor(radius / px + 0.5))
	for name, t in pairs(o.corners) do
		t:ClearAllPoints()
		local x = (name == "TOPLEFT" or name == "BOTTOMLEFT") and inset or -inset
		local y = (name == "TOPLEFT" or name == "TOPRIGHT") and -inset or inset
		t:SetPoint(name, frame, name, x, y)
		t:SetSize(radius, radius)
		drawCorner(o, name, t, R, px, r, g, b, a)
	end
	-- the upright bar between the left and right corners, then the two side
	-- bars between the top and bottom ones
	local mid, left, right = o.bars[1], o.bars[2], o.bars[3]
	mid:ClearAllPoints()
	mid:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + radius, -inset)
	mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + radius), inset)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + radius))
	-- AND THEY STOP SHORT OF THE BOTTOM CORNERS TOO (Josh 2026-09-21). Running
	-- them to `inset` left each side bar lying ON the bottom corner piece, so
	-- the two drew over each other: a square of double-strength fill where a
	-- quarter-circle should have been. The top was right because the bar
	-- already started below the top corner; only the bottom end was missing.
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", inset + radius, inset + radius)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + radius))
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -(inset + radius), inset + radius)
	for _, t in ipairs(o.bars) do
		t:SetColorTexture(r, g, b, a)
		P.Snap(t)
		t:Show()
	end
end

local function hideRound(o)
	if not o then
		return
	end
	for _, t in pairs(o.corners) do
		t:Hide()
	end
	for _, list in pairs(o.rows or {}) do
		for _, t in ipairs(list) do
			t:Hide()
		end
	end
	for _, t in ipairs(o.bars) do
		t:Hide()
	end
end

-- A RIM IS A RING, NOT A RECTANGLE UNDER THE FILL (Josh 2026-09-21).
--
-- Every surface in the addon drew the rim at full size and laid the fill on
-- top of it, one pixel in. That works only while the rim is near-black: the
-- fill is deliberately translucent, so twelve percent of whatever the rim is
-- painted with shows through the WHOLE panel, not just its edge. Set the
-- border to red and the background went red - the border colour was quietly
-- also a background tint, on every panel, bar, button and chat window.
--
-- So the fill covers the frame and the rim is four bars drawn OVER it. There
-- is nothing behind the fill any more, and the two colours are independent.
-- something shaped like a texture that draws nothing, for a frame that will
-- not give us one
P.NOWHERE = setmetatable({}, { __index = function()
	return function() end
end })

function P.Ring(frame, layer, sub)
	local bars = {}
	for i = 1, 4 do
		local t = frame.CreateTexture and frame:CreateTexture(nil, layer, nil, sub)
		if t then
			t.beebs = true
		end
		bars[i] = t or P.NOWHERE
	end
	return bars
end

-- WHOLE SCREEN PIXELS (Josh 2026-09-22). With the interface scaled by
-- anything but a whole number, a border one unit thick is a pixel and a bit
-- on screen, and each edge rounds its own way depending on where it falls:
-- the left and bottom of the panel and the tooltips came out two pixels
-- wide against one along the top and right. A thickness is turned into the
-- nearest whole number of screen pixels at the scale the frame is drawn at,
-- and every bar is snapped to the grid, so all four edges agree.
--
-- AND WHERE THE CLIENT HAS NO PixelUtil (Josh 2026-09-23), the thickness is
-- worked out from the screen's own height - the sum the dock snaps with
-- (UI/Dock.lua, B.Snap) - rather than left as units, which at a small scale
-- is less than a pixel and comes and goes on the grid.
function P.PixelOf(frame)
	if type(GetPhysicalScreenSize) ~= "function" or not (frame and frame.GetEffectiveScale) then
		return nil
	end
	local ok, _, h = pcall(GetPhysicalScreenSize)
	local s = P.Number(frame:GetEffectiveScale(), 0)
	if not (ok and tonumber(h) and h > 0 and s > 0) then
		return nil
	end
	return 768 / h / s
end

function P.Px(frame, units)
	if not (units and units > 0 and frame and frame.GetEffectiveScale) then
		return units
	end
	if PixelUtil and PixelUtil.GetNearestPixelSize then
		local ok, v = pcall(PixelUtil.GetNearestPixelSize, units, frame:GetEffectiveScale(), 1)
		if ok and type(v) == "number" and v > 0 then
			return v
		end
	end
	local px = P.PixelOf(frame)
	if px then
		return math.max(1, math.floor(units / px + 0.5)) * px
	end
	return units
end

-- SNAPPED TO THE GRID, OR NOT (Josh 2026-09-23). Snapping was meant to make
-- the four edges agree; it was also what made edges come and go as a window
-- moved. Compared on the screen that showed it (`/bt pixels snap off`), the
-- borders held steadier unsnapped: a plain-coloured line exactly one pixel
-- thick covers exactly one row of pixels wherever it lands. So off it is.
P.snapping = false

function P.Snap(t)
	if t and t.SetSnapToPixelGrid then
		pcall(t.SetSnapToPixelGrid, t, P.snapping)
		pcall(t.SetTexelSnappingBias, t, 0)
	end
end
local snap = P.Snap

-- radius: how far in from each corner the side bars stop, leaving room for a
-- corner piece. Zero for a square panel, which is most of them.
function P.PlaceRing(bars, frame, inset, thick, radius)
	local r = radius or 0
	thick = P.Px(frame, thick)
	for _, t in ipairs(bars) do
		snap(t)
	end
	local top, bottom, left, right = bars[1], bars[2], bars[3], bars[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + r, -inset)
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + r), -inset)
	top:SetHeight(thick)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + r, inset)
	bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + r), inset)
	bottom:SetHeight(thick)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + r))
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + r)
	left:SetWidth(thick)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + r))
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + r)
	right:SetWidth(thick)
end

function P.PaintRing(bars, c, alpha)
	for _, t in ipairs(bars) do
		t:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
		t:Show()
	end
end

function P.HideRing(bars)
	for _, t in ipairs(bars or {}) do
		t:Hide()
	end
end

-- The whole surface at once, for anything dressing a frame the client made:
-- a fill across the frame and a ring over it. One call, one shape, and the
-- bleed above cannot come back one module at a time.
--
-- AND ONE SHAPE ROUTINE, NOT TWO (Josh 2026-09-21). Corner radius was written
-- into P.Panel only, so it rounded the window and did nothing at all to the
-- action bars, the chat window, the bags or the micro menu - which are the
-- frames a radius is most visible on. Both go through applyShape now.
function P.Surface(frame, layer, sub)
	local s = { frame = frame, layer = layer, sub = sub or 0 }
	-- A FRAME THAT WILL NOT MAKE A TEXTURE (Josh 2026-09-21). This threw, and
	-- every caller wraps the skin in a pcall - so the failure was silent and
	-- took the WHOLE pass with it: no surface, and no padding either, because
	-- repad runs after this. Better to come out with a surface that draws
	-- nothing than to lose everything that happens afterwards.
	s.fill = frame.CreateTexture and frame:CreateTexture(nil, layer, nil, s.sub)
	if s.fill then
		s.fill.beebs = true
		if s.fill.SetAllPoints then
			s.fill:SetAllPoints()
		end
	else
		s.fill = P.NOWHERE
	end
	s.rim = P.Ring(frame, layer, s.sub + 2)
	return s
end

-- anchor: what the shape hangs off. Usually the frame; the chat window passes
-- its own fill, which is stretched past the frame's edges on purpose.
local function applyShape(h, anchor, fill, edge, ownThick, outward)
	-- ownThick: for anything whose edge width is not the setting's. A
	-- tooltip's is the rarity's - silver two for a rare, gold four for an
	-- elite - and has nothing to do with how heavy you like your borders.
	local thick = P.Px(anchor, ownThick or (BT.Theme and BT.Theme.Thickness()) or 1)
	local radius = (BT.Theme and BT.Theme.Radius()) or 0
	-- a whole number of screen pixels, so the corners' rows and the straight
	-- edges meet exactly (see placeRound)
	if radius > 0 then
		radius = P.Px(anchor, radius)
	end
	local one = P.Px(anchor, 1) or 1
	local layer, sub = h.layer or "BORDER", h.sub or 0
	-- OUTWARD (Josh 2026-09-22). An edge wider than the hairline used to grow
	-- into the frame, so an elite's gold four took three pixels of padding
	-- off every side of its tooltip. With `outward` the inner edge stays
	-- where the hairline's is and the extra width is drawn outside the frame.
	local out = 0
	if outward then
		local base = P.Px(anchor, (BT.Theme and BT.Theme.Thickness()) or 1)
		out = math.max(0, thick - base)
	end
	-- a frame that will not make a texture (see P.Surface) gets the flat
	-- shape, which draws through NOWHERE; the rounded one would call
	-- CreateTexture and take the rest of the caller's pass down with it
	if not h.frame.CreateTexture then
		radius = 0
	end

	if radius <= 0 then
		hideRound(h.roundFill)
		hideRound(h.roundEdge)
		h.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
		h.fill:Show()
	else
		-- the square fill steps aside for the rounded one, and the arcs
		-- are the border's corners with the fill's own, one size smaller,
		-- laid back over them
		h.fill:Hide()
		h.roundFill = h.roundFill or roundLayer(h.frame, layer, sub + 1)
		-- AN EDGE NOBODY CAN SEE IS NOT BUILT (Josh 2026-09-23, audit): the
		-- unit frames ask for a clear one, and each cell of a raid drew its
		-- corner rows and its ring anyway, all of them see-through
		h.noEdge = (edge[4] or 1) <= 0
		if h.noEdge then
			hideRound(h.roundEdge)
		else
			h.roundEdge = h.roundEdge or roundLayer(h.frame, layer, sub)
			placeRound(h.roundEdge, anchor, -out, radius, edge)
			-- the three bars of the border layer are what used to sit under
			-- the fill; with the ring drawing the edges they are not wanted
			for _, t in ipairs(h.roundEdge.bars) do
				t:Hide()
			end
		end
		placeRound(h.roundFill, anchor, thick - out, math.max(one, radius - thick), fill)
	end

	-- A HOLE WHERE SOMETHING SHOULD SHOW THROUGH (Josh 2026-09-22). The dock's
	-- background ran under the minimap at 88%, so fading the map faded it into
	-- a dark box rather than into the world. A surface with a hole draws its
	-- middle as four strips around it instead of one piece across it. The
	-- hole is always well inside the corners, so only the middle piece - the
	-- flat fill, or the upright bar of the rounded one - is ever affected.
	--
	-- hole = { left, top, right, bottom }: left and right in from the anchor's
	-- sides, top and bottom down from its top.
	local body, bx, by
	if radius <= 0 then
		body, bx, by = h.fill, 0, 0
	else
		body = h.roundFill.bars[1]
		bx, by = thick - out + math.max(one, radius - thick), thick - out
	end
	if h.hole then
		body:Hide()
		h.holeStrips = h.holeStrips or {}
		local subAt = radius <= 0 and sub or sub + 1
		for i = 1, 4 do
			if not h.holeStrips[i] then
				local t = h.frame:CreateTexture(nil, layer, nil, subAt)
				t.beebs = true
				h.holeStrips[i] = t
			end
		end
		local o = h.hole
		local function strip(t, p1, x1, y1, p2, x2, y2)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", anchor, p1, x1, y1)
			t:SetPoint("BOTTOMRIGHT", anchor, p2, x2, y2)
			t:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
			t:Show()
		end
		local s = h.holeStrips
		strip(s[1], "TOPLEFT", bx, -by, "TOPRIGHT", -bx, -o.top)
		strip(s[2], "TOPLEFT", bx, -o.bottom, "BOTTOMRIGHT", -bx, by)
		strip(s[3], "TOPLEFT", bx, -o.top, "TOPLEFT", o.left, -o.bottom)
		strip(s[4], "TOPRIGHT", -o.right, -o.top, "TOPRIGHT", -bx, -o.bottom)
	elseif h.holeStrips then
		for _, t in ipairs(h.holeStrips) do
			t:Hide()
		end
	end

	P.PlaceRing(h.rim, anchor, -out, thick, radius)
	if (edge[4] or 1) <= 0 then
		P.HideRing(h.rim)
	else
		P.PaintRing(h.rim, edge)
	end
end
P.ApplyShape = applyShape

-- outward: an edge wider than the hairline grows out of the frame rather than
-- into it (see applyShape)
function P.PaintSurface(s, anchor, fill, rim, ownThick, outward)
	applyShape(s, anchor or s.frame, fill, rim, ownThick, outward)
end

-- ONLY ONE OF THE TWO SHAPES IS EVER UP (Josh 2026-09-21). Showing the flat
-- fill unconditionally put it back over the rounded one that had just been
-- drawn, so a rounded surface came out square again - which is what "radius
-- does nothing on the bars" was, after the shape itself was shared.
function P.ShowSurface(s, on)
	-- ONLY IF THERE IS A ROUNDED ONE TO SHOW INSTEAD (Josh 2026-09-21).
	-- Hiding the flat fill on the strength of the setting alone left any
	-- surface that had not built a rounded shape with no background at all -
	-- which is how the tooltip came up see-through the moment a radius was
	-- set on it.
	local rounded = ((BT.Theme and BT.Theme.Radius()) or 0) > 0 and s.roundFill ~= nil
	s.fill:SetShown(on and not rounded)
	for _, t in ipairs(s.rim) do
		t:SetShown(on and not s.noEdge)
	end
	if not on or not rounded then
		hideRound(s.roundFill)
		hideRound(s.roundEdge)
	else
		-- AND THE ROUNDED PIECES COME BACK TOO (Josh 2026-09-22). Hiding a
		-- surface hid its rounded pieces, and showing it again only put the
		-- square fill back - which a rounded surface keeps hidden. The chat
		-- box opened with no background at all once the corners went to 3.
		-- The fill's corner rows and bars, and the edge's corner rows (its
		-- bars stay down: the ring draws the edges). The corner boxes are
		-- never drawn - only hung from - so they stay hidden (Josh 2026-09-23,
		-- audit: showing only the boxes left a notch at every corner).
		showRows(s.roundFill)
		for i, t in ipairs(s.roundFill.bars) do
			-- the middle bar stays down while a hole's strips stand in for it
			t:SetShown(not (i == 1 and s.hole))
		end
		if not s.noEdge then
			showRows(s.roundEdge)
		end
	end
	for _, t in ipairs(s.holeStrips or {}) do
		t:SetShown(on and s.hole ~= nil)
	end
end

-- EVERY PANEL, REPAINTABLE (Josh 2026-09-21). The colours are a setting now,
-- so a panel drawn at login has to be able to change later. They are held
-- weakly: a frame the client throws away takes its entry with it.
local panels = setmetatable({}, { __mode = "k" })

-- A panel with a RIM: the fill covers the frame and the rim is a ring over
-- it. An "edge" texture laid over the fill is not an edge, it is a wash, which
-- is what turned the Ledger button brown (Josh 2026-09-19); a rim UNDER the
-- fill is not an edge either, it is a background tint (Josh 2026-09-21).
function P.Panel(frame, fill, edge)
	local h = panels[frame]
	if not h then
		h = P.Surface(frame, "BACKGROUND", 0)
		panels[frame] = h
	end
	h.fillColour = fill or (BT.Widgets and BT.Widgets.FILL)
	h.edgeColour = edge or (BT.Widgets and BT.Widgets.RIM)
	P.Repaint(h)
	return h.fill, h.rim
end

-- New colours for a panel already drawn - a button going from idle to pressed,
-- a tab lighting up. Goes through the shape, so it lands on whichever of the
-- two shapes the current radius is using.
-- Cut a hole in a panel's background, or close it again with nil. Only
-- repaints when the hole has actually moved: the dock lays itself out often.
function P.SetHole(frame, hole)
	local h = panels[frame]
	if not h then
		return false
	end
	local was = h.hole
	local same = (hole == nil and was == nil) or (hole ~= nil and was ~= nil
		and hole.left == was.left and hole.top == was.top
		and hole.right == was.right and hole.bottom == was.bottom)
	if same then
		return false
	end
	h.hole = hole
	P.Repaint(h)
	return true
end

function P.Recolour(frame, fill, edge)
	local h = panels[frame]
	if not h then
		return false
	end
	h.fillColour, h.edgeColour = fill or h.fillColour, edge or h.edgeColour
	return P.Repaint(h)
end

function P.Repaint(h)
	if not (h and h.frame and h.fillColour and h.edgeColour) then
		return false
	end
	applyShape(h, h.frame, h.fillColour, h.edgeColour)
	return true
end

function P.RepaintAll()
	local n = 0
	for _, h in pairs(panels) do
		if P.Repaint(h) then
			n = n + 1
		end
	end
	return n
end

-- the tests want to see what a frame is wearing
function P.Panels()
	return panels
end

-- A TAG KEEPS ITS COLOUR WHEN IT IS OFF (Josh 2026-09-19). The unset state
-- used to paint every pill the same grey, so a tag you had just made in green
-- looked as though the colour had not saved. Off is the same colour, dimmed:
-- you can see what you chose, and still tell at a glance who carries it.
function P.Color(frame, color, lit)
	if not frame.pillLeft then
		return
	end
	local r, g, b = 0.42, 0.48, 0.45
	local a = 0.85
	if color then
		if lit then
			r, g, b, a = color[1], color[2], color[3], 1
		else
			r, g, b, a = color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, 0.8
		end
	end
	for _, t in ipairs({ frame.pillLeft, frame.pillMid, frame.pillRight }) do
		t:SetVertexColor(r, g, b, a)
	end
end

-- A NUMBER YOU ARE ALLOWED TO USE (Josh 2026-09-19). On this client a widget
-- measurement can come back SECRET once execution is tainted - it is a number,
-- and arithmetic on it throws "attempt to perform arithmetic on a secret
-- number value". Every measurement in the addon goes through here, and a
-- secret one is treated as no measurement at all.
function P.Number(v, fallback)
	if type(v) ~= "number" then
		return fallback
	end
	if issecretvalue and issecretvalue(v) then
		return fallback
	end
	return v
end

-- How wide a pill has to be to hold this label. Falls back to counting
-- characters, which is close enough for a tag and never throws.
function P.Width(fontString, label, padding)
	local measured = fontString and fontString.GetStringWidth and fontString:GetStringWidth()
	local text = P.Number(measured, #(label or "") * 6)
	return text + (padding or 10) * 2
end
