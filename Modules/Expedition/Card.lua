-- An Expedition card (Josh 2026-09-26, chosen from the mockup, round four).
--
-- The enemy looks out through a stepped Deco arch; the rank is the gem at the
-- top of the arch; the name, what it is, and its kills,
-- mastery and points run underneath. THE BORDER IS THE MASTERY, and it gathers
-- ornament as the mastery climbs:
--
--   unmastered  one thin iron line, a plain arch
--   bronze      a double line, a stepped corner
--   silver      the toolkit's diamond on each corner, a double arch
--   gold        a fan behind each corner, the crest on the top edge, studs on
--               the sides, a fan under the name
--   platinum    a third line, a sunburst crest with wings, stepped side
--               ornaments, a pendant at the foot, gems, and a sheen that
--               sweeps across it
--
-- The ornaments are white art (Art/Cards, drawn by scripts/make-cards.lua)
-- tinted the tier's metal. Everything is placed in the mockup's DESIGN UNITS
-- - its card was 184 wide - and scaled to the card's real width, so the art
-- and the lines drawn here meet where the art expects them.
--
-- A model cannot be clipped to an arch, so the arch is a MOUNT: blocks of the
-- card's own colour laid over the model's top corners, as a picture framer
-- would cut one.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Expedition/Card.lua")

local Card = {}
BT.ExpeditionCard = Card

-- the art, each file named in full (tests/load.lua checks every one is here)
local TEX = {
	corner = {
		"Interface\\AddOns\\BeebMod\\Art\\Cards\\corner1", "Interface\\AddOns\\BeebMod\\Art\\Cards\\corner2",
		"Interface\\AddOns\\BeebMod\\Art\\Cards\\corner3", "Interface\\AddOns\\BeebMod\\Art\\Cards\\corner4",
	},
	crest = { [3] = "Interface\\AddOns\\BeebMod\\Art\\Cards\\crest3", [4] = "Interface\\AddOns\\BeebMod\\Art\\Cards\\crest4" },
	side = { [3] = "Interface\\AddOns\\BeebMod\\Art\\Cards\\side3", [4] = "Interface\\AddOns\\BeebMod\\Art\\Cards\\side4" },
	pendant = "Interface\\AddOns\\BeebMod\\Art\\Cards\\pendant4",
	fan = "Interface\\AddOns\\BeebMod\\Art\\Cards\\fan",
	gem = "Interface\\AddOns\\BeebMod\\Art\\Cards\\gem",
	sheen = "Interface\\AddOns\\BeebMod\\Art\\Cards\\sheen",
}
Card.TEX = TEX
Card.FONT_NAME = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\JosefinSans-Bold.ttf"
Card.FONT_TYPE = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\PoiretOne-Regular.ttf"
Card.FONT_LORE = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\Alegreya-Italic.ttf"

-- the mockup's card, and its shape
Card.DESIGN_W = 184
-- TALLER, FOR THE LORE (Josh 2026-09-26: "we can make the cards larger to fit
-- more text"): four lines of it under the name, where the first cards had two
Card.RATIO = 1.62

-- the card's own colour: the ground, and the mount over the model's corners
local GROUND = { 0.071, 0.055, 0.043 }

-- the metals, by tier: the lines and ornaments, the darker third line of
-- platinum, and the tier's word
Card.TIERS = {
	[0] = { name = "", color = { 0.49, 0.45, 0.40 } },
	{ name = "Bronze", color = { 0.79, 0.54, 0.32 } },
	{ name = "Silver", color = { 0.80, 0.83, 0.86 } },
	{ name = "Gold", color = { 0.89, 0.74, 0.35 } },
	{ name = "Platinum", color = { 0.75, 0.90, 0.95 }, lo = { 0.42, 0.56, 0.63 } },
}

-- the keystone: gold for an elite, silver for a rare, pale gold for a rare
-- elite, red for a world boss; an ordinary enemy has none
Card.GEMS = {
	elite = { 1, 0.78, 0.25 },
	rare = { 0.82, 0.87, 0.94 },
	rareelite = { 0.95, 0.90, 0.72 },
	worldboss = { 0.92, 0.28, 0.16 },
}
local PLATINUM_GEM = { 0.90, 0.83, 1 }

-- the arch, by rank: its lines, its ornaments, and how many of them - 1 a
-- double line and a diamond on each step, 2 brackets on the window's foot as
-- well, 3 rays over the keystone too. The gold and silver are the tooltips'
-- (UI/Ornament.lua), so an elite is the same gold wherever it is shown.
local RANK_GOLD, RANK_SILVER = { 1.00, 0.82, 0.40 }, { 0.84, 0.88, 0.95 }
Card.RANK_STYLE = {
	normal = { line = { 0.42, 0.38, 0.33 }, alpha = 0.9, level = 0 },
	rare = { line = RANK_SILVER, level = 1 },
	elite = { line = RANK_GOLD, level = 2 },
	rareelite = { line = RANK_SILVER, ornament = RANK_GOLD, level = 2 },
	worldboss = { line = RANK_GOLD, level = 3 },
}

-- where things sit, in design units
-- SMALLER, WITHOUT THE LORE (Josh 2026-09-26: "the card view is too large to
-- be of any value. Let's hide the lore on the cards, and collapse that space"):
-- the card is only as tall as what is on it - the window, the name, the type,
-- room for gold's fan - and the lore is on the enemy's page
local PAD_X, PAD_TOP, PAD_FOOT = 10, 10, 8
local NAME_GAP, NAME_H, TYPE_H, FAN_ROOM = 5, 16.5, 15.5, 8
-- the category's line under the type (Josh 2026-09-27: "make the cards slightly
-- taller, and put the category under the enemy type and level")
local CAT_H = 14
local WIN_PAD = 3
local OUTER, INNER, THIRD = 0, 4.5, 6.4        -- the border's lines, in from the edge
local OUTER_RUN, INNER_RUN, THIRD_RUN = 11, 13, 15 -- where they leave the corner art
-- DEEPER SHOULDERS (Josh 2026-09-26: "adjust the portrait borders so the
-- kills and points fit there a bit better"): the outer step is wide and deep
-- enough to hold a number and its word, clear of the lines
local ARCH_A, ARCH_B = 0.30, 0.13               -- the arch's steps, as shares of the window
local ARCH_X1, ARCH_X2 = 0.21, 0.32

-- ---------------------------------------------------------------------------
-- Pieces
-- ---------------------------------------------------------------------------

local function tex(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	t:Hide()
	return t
end

-- a line, one pixel through, set by Place
local function rule(parent, sub)
	local t = tex(parent, "ARTWORK", sub)
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

local function text(parent, path, fallbackObject)
	local fs = parent:CreateFontString(nil, "OVERLAY", fallbackObject or "BeebModFontHighlightSmall")
	fs.fontPath = path
	fs:SetWordWrap(false)
	return fs
end

-- the face, at a size; the toolkit's own face where the file will not load
local function setFont(fs, size)
	if fs.fontSize == size then
		return
	end
	fs.fontSize = size
	-- the client says false, not an error, for a file it will not load: a
	-- string with no font draws nothing at all
	local ok, took = pcall(fs.SetFont, fs, fs.fontPath, size, "")
	if not ok or took == false then
		pcall(fs.SetFont, fs, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
	end
end

function Card.New(parent)
	local c = CreateFrame("Button", nil, parent)
	local level = c:GetFrameLevel() or 1
	-- THE GROUND FOLLOWS THE NOTCH (Josh 2026-09-26: "are we able to mask the
	-- black background so it doesn't show in the 4 corners"). Where the corner
	-- art steps the border in, a square of the card's dark stood out beyond it;
	-- the ground is three strips that leave those squares clear (Card.Notch).
	c.ground = {}
	for i = 1, 3 do
		c.ground[i] = tex(c, "BACKGROUND")
		c.ground[i]:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], 1)
		c.ground[i]:Show()
	end

	-- the window: the map behind the enemy, and the shades over the map
	c.box = CreateFrame("Frame", nil, c)
	c.box:SetFrameLevel(level + 1)
	c.tiles = {}
	for i = 1, 4 do
		c.tiles[i] = tex(c.box, "BORDER")
	end
	local function shade(edge)
		local t = tex(c.box, "ARTWORK")
		t:SetPoint(edge .. "LEFT", c.box, edge .. "LEFT", 0, 0)
		t:SetPoint(edge .. "RIGHT", c.box, edge .. "RIGHT", 0, 0)
		t:SetColorTexture(0, 0, 0, 1)
		t.edge = edge
		return t
	end
	c.shade, c.topShade = shade("BOTTOM"), shade("TOP")
	c.portrait = CreateFrame("PlayerModel", nil, c.box)
	c.portrait:SetAllPoints(c.box)
	c.portrait:SetFrameLevel(level + 2)

	-- everything over the model: the mount, the lines, the ornaments, the words
	local o = CreateFrame("Frame", nil, c)
	o:SetAllPoints()
	o:SetFrameLevel(level + 4)
	c.over = o
	c.mount = {}
	for i = 1, 4 do
		c.mount[i] = tex(o, "BACKGROUND")
		c.mount[i]:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], 1)
	end
	c.arch, c.archIn = {}, {}
	for i = 1, 12 do
		c.arch[i] = rule(o, 1)
		c.archIn[i] = rule(o, 1)
	end
	-- THE RAYS BREAK THE BORDER (Josh 2026-09-27: "World boss portrait frame
	-- is getting cut off"). Between the keystone and the card's top there is
	-- no room clear of the border's inner lines, and the rays were drawn under
	-- them. A patch of the card's own dark takes the two inner lines away over
	-- the keystone, the outer line capping it, and the rays stand in it.
	c.rayGround = tex(o, "ARTWORK", 3)
	c.rayGround:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], 1)
	c.rays = {}
	for i = 1, 3 do
		c.rays[i] = tex(o, "OVERLAY", 5)
		c.rays[i]:SetColorTexture(1, 1, 1, 1)
	end
	-- the rank's ornaments on the arch: a diamond at each of its four steps,
	-- and a bracket on each of the window's bottom corners
	c.archGems, c.brackets = {}, {}
	for i = 1, 4 do
		c.archGems[i] = tex(o, "ARTWORK", 2)
		c.archGems[i]:SetTexture(TEX.side[3])
	end
	for i = 1, 2 do
		c.brackets[i] = tex(o, "ARTWORK", 2)
		c.brackets[i]:SetTexture(TEX.corner[2])
	end
	-- the border's three lines, four sides each
	c.lines = {}
	for n = 1, 3 do
		c.lines[n] = {}
		for s = 1, 4 do
			c.lines[n][s] = rule(o, 2)
		end
	end
	c.corners = {}
	for i = 1, 4 do
		c.corners[i] = tex(o, "ARTWORK", 3)
	end
	c.cornerGems = {}
	for i = 1, 4 do
		c.cornerGems[i] = tex(o, "ARTWORK", 5)
		c.cornerGems[i]:SetTexture(TEX.gem)
	end
	c.crest = tex(o, "ARTWORK", 4)
	c.crestGem = tex(o, "ARTWORK", 5)
	c.crestGem:SetTexture(TEX.gem)
	c.sides = { tex(o, "ARTWORK", 3), tex(o, "ARTWORK", 3) }
	c.pendant = tex(o, "ARTWORK", 4)
	c.keystone = tex(o, "OVERLAY", 6)
	c.keystone:SetTexture(TEX.gem)
	c.fan = tex(o, "ARTWORK")
	c.fan:SetTexture(TEX.fan)

	c.name = text(o, Card.FONT_NAME)
	c.name:SetJustifyH("CENTER")
	c.kind = text(o, Card.FONT_TYPE)
	c.kind:SetJustifyH("CENTER")
	c.cat = text(o, Card.FONT_TYPE)
	c.cat:SetJustifyH("CENTER")
	c.lore = text(o, Card.FONT_LORE)
	c.lore:SetJustifyH("CENTER")
	c.lore:SetJustifyV("TOP")
	c.lore:SetWordWrap(true)
	pcall(c.lore.SetMaxLines, c.lore, 4)
	c.kills = text(o, Card.FONT_NAME)
	c.killsLabel = text(o, Card.FONT_NAME)
	c.tier = text(o, Card.FONT_TYPE)
	c.points = text(o, Card.FONT_NAME)
	c.pointsLabel = text(o, Card.FONT_NAME)

	-- under the cursor, a touch of light
	c.lit = {}
	for i = 1, 3 do
		c.lit[i] = tex(o, "BACKGROUND", 1)
		c.lit[i]:SetColorTexture(1, 1, 1, 0.05)
	end

	-- the platinum sheen, in a frame that clips it to the card
	local clip = CreateFrame("Frame", nil, c)
	clip:SetAllPoints()
	clip:SetFrameLevel(level + 5)
	pcall(clip.SetClipsChildren, clip, true)
	c.sheenClip = clip
	c.sheen = tex(clip, "OVERLAY")
	c.sheen:SetTexture(TEX.sheen)
	pcall(c.sheen.SetBlendMode, c.sheen, "ADD")
	c.sheen:SetAlpha(0.35)
	return c
end

-- ---------------------------------------------------------------------------
-- Layout: every piece placed for a card `w` wide, once per width
-- ---------------------------------------------------------------------------

-- as tall as what is on it: the window, the name and type under it, and room
-- for gold's fan
function Card.Height(w)
	local k = w / Card.DESIGN_W
	local function D(v)
		return math.floor(v * k + 0.5)
	end
	local _, wy, _, wh = Card.Window(w)
	return wy + wh + D(NAME_GAP) + math.max(12, D(NAME_H)) + math.max(12, D(TYPE_H)) + math.max(11, D(CAT_H))
		+ D(FAN_ROOM) + D(PAD_FOOT)
end

-- HOW FAR THE BORDER REACHES PAST THE CARD (Josh 2026-09-27: "The borders
-- we built are being cut off"): platinum's crest stands 32 over the top edge,
-- the corners 12 past each side, the pendant 21 under the foot. In pixels at
-- this width, for the grid to leave room: top, side, foot.
function Card.Reach(w)
	local k = w / Card.DESIGN_W
	return math.ceil(32 * k), math.ceil(12 * k), math.ceil(21 * k)
end

-- where the enemy's window is, in the card: left, top, width, height
function Card.Window(w)
	local k = w / Card.DESIGN_W
	local x = math.floor((PAD_X + WIN_PAD) * k + 0.5)
	local y = math.floor((PAD_TOP + WIN_PAD) * k + 0.5)
	local ww = w - 2 * x
	-- wider than tall: the face, and room for three rows of cards in view
	return x, y, ww, math.floor(ww * 90 / 136 + 0.5)
end

local function place(t, parent, x, y, w, h)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	t:SetSize(math.max(1, w), math.max(1, h))
end

-- the arch's outline through a window w x h, `d` in from its edge: twelve runs
local function archRuns(w, h, d)
	local a, b = math.floor(ARCH_A * h + 0.5), math.floor(ARCH_B * h + 0.5)
	local x1, x2 = math.floor(ARCH_X1 * w + 0.5), math.floor(ARCH_X2 * w + 0.5)
	local l, r, t, bot = d, w - d - 1, d, h - d - 1
	local xa, xb, xc, xd = x1 + d, x2 + d, w - x2 - d - 1, w - x1 - d - 1
	local ya, yb = a + d, b + d
	-- { x, y, width, height }
	return {
		{ l, ya, xa - l + 1, 1 }, { xa, yb, xb - xa + 1, 1 }, { xb, t, xc - xb + 1, 1 },
		{ xc, yb, xd - xc + 1, 1 }, { xd, ya, r - xd + 1, 1 }, { l, bot, r - l + 1, 1 },
		{ l, ya, 1, bot - ya + 1 }, { xa, yb, 1, ya - yb + 1 }, { xb, t, 1, yb - t + 1 },
		{ xc, t, 1, yb - t + 1 }, { xd, yb, 1, ya - yb + 1 }, { r, ya, 1, bot - ya + 1 },
	}
end
Card.ArchRuns = archRuns

function Card.Layout(c, w)
	if c.laidW == w then
		return
	end
	c.laidW = w
	local h = Card.Height(w)
	local k = w / Card.DESIGN_W
	local function D(v)
		return math.floor(v * k + 0.5)
	end
	c:SetSize(w, h)
	c.k = k

	-- the window, and the map and shades in it
	local wx, wy, ww, wh = Card.Window(w)
	c.box:ClearAllPoints()
	c.box:SetPoint("TOPLEFT", c, "TOPLEFT", wx, -wy)
	c.box:SetSize(ww, wh)
	c.winW, c.winH = ww, wh
	c.shade:SetHeight(math.floor(wh * 0.4 + 0.5))
	c.topShade:SetHeight(math.floor(wh * 0.3 + 0.5))
	for _, s in ipairs({ { c.shade, 0.7 }, { c.topShade, 0.45 } }) do
		local t, alpha = s[1], s[2]
		local dark = CreateColor and CreateColor(0, 0, 0, alpha)
		local clear = CreateColor and CreateColor(0, 0, 0, 0)
		local graded = CreateColor ~= nil and pcall(t.SetGradient, t, "VERTICAL",
			t.edge == "BOTTOM" and dark or clear, t.edge == "BOTTOM" and clear or dark)
		if not graded then
			t:SetColorTexture(0, 0, 0, alpha / 2)
		end
	end

	-- the mount over the model's top corners: the arch's two steps each side
	local a, b = math.floor(ARCH_A * wh + 0.5), math.floor(ARCH_B * wh + 0.5)
	local x1, x2 = math.floor(ARCH_X1 * ww + 0.5), math.floor(ARCH_X2 * ww + 0.5)
	place(c.mount[1], c, wx, wy, x2, b)
	place(c.mount[2], c, wx, wy + b, x1, a - b)
	place(c.mount[3], c, wx + ww - x2, wy, x2, b)
	place(c.mount[4], c, wx + ww - x1, wy + b, x1, a - b)
	for _, m in ipairs(c.mount) do
		m:Show()
	end
	-- A RANK'S SECOND LINE GOES OUTSIDE (Josh 2026-09-26: "a little bleed
	-- through on the top"). Drawn inside the window, the second line left a
	-- strip of the enemy showing between the two; outside, over the card's own
	-- dark, the pair frames the portrait with nothing between them. The
	-- outline's own arithmetic takes a negative inset as outward.
	local outer, inner = archRuns(ww, wh, 0), archRuns(ww, wh, -math.max(2, D(3)))
	for i = 1, 12 do
		local r, q = outer[i], inner[i]
		place(c.arch[i], c, wx + r[1], wy + r[2], r[3], r[4])
		place(c.archIn[i], c, wx + q[1], wy + q[2], q[3], q[4])
	end
	-- the rank's diamonds, on the arch's four steps
	for i, p in ipairs({ { x1, a }, { x2, b }, { ww - 1 - x1, a }, { ww - 1 - x2, b } }) do
		local g = c.archGems[i]
		g:ClearAllPoints()
		g:SetSize(D(8), D(16))
		g:SetPoint("CENTER", c, "TOPLEFT", wx + p[1] + 0.5, -(wy + p[2] + 0.5))
	end
	-- and its brackets, on the window's bottom corners: the corner piece,
	-- half size, turned to point out and down
	local bs = D(20)
	local bp = math.floor(bs * 12 / 32 + 0.5)
	c.brackets[1]:ClearAllPoints()
	c.brackets[1]:SetSize(bs, bs)
	c.brackets[1]:SetPoint("BOTTOMLEFT", c, "TOPLEFT", wx - bp, -(wy + wh + bp))
	c.brackets[1]:SetTexCoord(0, 1, 1, 0)
	c.brackets[2]:ClearAllPoints()
	c.brackets[2]:SetSize(bs, bs)
	c.brackets[2]:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", wx + ww + bp, -(wy + wh + bp))
	c.brackets[2]:SetTexCoord(1, 0, 1, 0)
	-- the keystone, on the arch's top line; the world boss's rays above it
	local g = D(13)
	c.keystone:ClearAllPoints()
	c.keystone:SetPoint("CENTER", c, "TOPLEFT", w / 2, -(wy + 1))
	c.keystone:SetSize(g, g)
	-- the notch they stand in: from under the outer line to the keystone
	local notchTop = D(OUTER) + 1
	c.rayGround:ClearAllPoints()
	c.rayGround:SetPoint("TOPLEFT", c, "TOPLEFT", math.floor(w / 2 - D(13) + 0.5), -notchTop)
	c.rayGround:SetSize(D(26), math.max(1, wy - D(4) - notchTop))
	for i, ray in ipairs(c.rays) do
		ray:ClearAllPoints()
		ray:SetSize(1, D(7))
		local off = (i - 2) * D(7)
		ray:SetPoint("BOTTOM", c, "TOPLEFT", w / 2 + off, -(wy - D(5)))
		pcall(ray.SetRotation, ray, (i - 2) * -0.55)
	end

	-- the border's lines: in from the edge, and short of the corners
	local function sides(set, inset, run)
		local i, r = D(inset), D(run)
		-- top, bottom, left, right
		place(set[1], c, r, i, w - 2 * r, 1)
		place(set[2], c, r, h - i - 1, w - 2 * r, 1)
		place(set[3], c, i, r, 1, h - 2 * r)
		place(set[4], c, w - i - 1, r, 1, h - 2 * r)
	end
	c.sides_ = sides
	c.notchUnit = D(6)
	sides(c.lines[1], OUTER, OUTER_RUN)
	sides(c.lines[2], INNER, INNER_RUN)
	sides(c.lines[3], THIRD, THIRD_RUN)

	-- the corners: one piece, mirrored; its (12, 12) on the card's corner
	local cs = D(32)
	local off = D(12)
	for i, cn in ipairs({
		{ "TOPLEFT", -off, off, 0, 1, 0, 1 }, { "TOPRIGHT", off, off, 1, 0, 0, 1 },
		{ "BOTTOMLEFT", -off, -off, 0, 1, 1, 0 }, { "BOTTOMRIGHT", off, -off, 1, 0, 1, 0 },
	}) do
		local t = c.corners[i]
		t:ClearAllPoints()
		t:SetSize(cs, cs)
		t:SetPoint(cn[1], c, cn[1], cn[2], cn[3])
		t:SetTexCoord(cn[4], cn[5], cn[6], cn[7])
		local gem = c.cornerGems[i]
		gem:ClearAllPoints()
		gem:SetSize(D(6), D(6))
		local sx = (cn[1]:find("LEFT") and 0 or w)
		local sy = (cn[1]:find("TOP") and 0 or -h)
		gem:SetPoint("CENTER", c, "TOPLEFT", sx, sy)
	end
	-- the crests: gold's (64 x 32, its base (32, 28) 10 in from the top) and
	-- platinum's (128 x 64, its base (64, 40) 8 in)
	c.crestSizes = {
		[3] = { D(64), D(32), D(32), D(28 - 10) },
		[4] = { D(128), D(64), D(64), D(40 - 8) },
	}
	c.crestGem:ClearAllPoints()
	c.crestGem:SetSize(D(5), D(5))
	c.crestGem:SetPoint("CENTER", c, "TOPLEFT", w / 2, D(26 - 8))
	-- the sides: (8, 16) on the edge, half way down
	for i, s in ipairs(c.sides) do
		s:ClearAllPoints()
		s:SetSize(D(16), D(32))
		if i == 1 then
			s:SetPoint("CENTER", c, "LEFT", 0, 0)
		else
			s:SetPoint("CENTER", c, "RIGHT", 0, 0)
			s:SetTexCoord(1, 0, 0, 1)
		end
	end
	-- the pendant: its line (32, 6) five in from the foot
	c.pendant:ClearAllPoints()
	c.pendant:SetSize(D(64), D(32))
	c.pendant:SetPoint("TOPLEFT", c, "BOTTOM", -D(32), D(6 + 5))

	-- the words under the window
	local y = wy + wh + D(NAME_GAP)
	local inset = D(PAD_X)
	-- LARGER WORDS (Josh 2026-09-26: "increase font size since we made the
	-- cards larger... they are pretty hard to read still")
	c.nameSize = math.max(10, D(14))
	c.nameAvail = w - 2 * inset
	setFont(c.name, c.nameSize)
	c.name:ClearAllPoints()
	c.name:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -y)
	c.name:SetPoint("TOPRIGHT", c, "TOPRIGHT", -inset, -y)
	y = y + math.max(12, D(NAME_H))
	setFont(c.kind, math.max(9.5, D(12.5)))
	c.kind:ClearAllPoints()
	c.kind:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -y)
	c.kind:SetPoint("TOPRIGHT", c, "TOPRIGHT", -inset, -y)
	y = y + math.max(12, D(TYPE_H))
	setFont(c.cat, math.max(9, D(11.5)))
	c.cat:ClearAllPoints()
	c.cat:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -y)
	c.cat:SetPoint("TOPRIGHT", c, "TOPRIGHT", -inset, -y)
	y = y + math.max(11, D(CAT_H))
	-- gold's fan, in the room left for it between the category and the foot
	c.fanY = y
	c.fan:ClearAllPoints()
	c.fan:SetSize(D(128), D(16))
	c.fan:SetPoint("TOP", c, "TOPLEFT", w / 2, -y)
	-- the lore is the enemy's page's now, not the card's
	c.lore:Hide()

	-- KILLS AND POINTS IN THE ARCH'S SHOULDERS (Josh 2026-09-26: "the space in
	-- the upper left and right would be perfect to show the kills and points
	-- ... then we could make the cards even shorter"). The number sits in
	-- the band above the window's top step, its word in the step below it,
	-- clear of the arch's lines; the foot they stood in is gone. The mastery
	-- word went with it: the border says the mastery already.
	local labelSize = math.max(7, D(7.5))
	for _, s in ipairs({ { c.kills, c.killsLabel, D(25) }, { c.points, c.pointsLabel, w - D(25) } }) do
		local value, label, x = s[1], s[2], s[3]
		setFont(value, math.max(10, D(14)))
		setFont(label, labelSize)
		value:ClearAllPoints()
		label:ClearAllPoints()
		value:SetPoint("TOP", c, "TOPLEFT", x, -D(12))
		label:SetPoint("TOP", value, "BOTTOM", 0, -D(2))
	end
	c.tier:Hide()

	-- the sheen: a band the height of the card, swept across it
	c.sheen:ClearAllPoints()
	c.sheen:SetSize(math.floor(w * 0.9), math.floor(h * 1.3))
	c.sheen:SetPoint("LEFT", c.sheenClip, "LEFT", -math.floor(w * 0.9), 0)
	if c.sweep then
		c.sweep:Stop()
		c.sweep = nil
	end
end

-- ---------------------------------------------------------------------------
-- Dressing: an enemy on the card
-- ---------------------------------------------------------------------------

-- The sheen sweeps across once every few seconds, by the client's own
-- animation, so it costs nothing a frame; where the client will not animate,
-- there is no sheen rather than a stuck one.
local SWEEP, SWEEP_REST = 3.2, 2.4

-- NOT ALL AT ONCE (Josh 2026-09-27: "stagger the platinum shine effect so it
-- isn't in sync on all platinum cards"). Each card's loop starts at its own
-- point in the cycle - the enemy's, by its number, so an enemy keeps its moment
-- from one opening to the next. The sheen waits off the card's left edge,
-- clipped from view, until then.
function Card.SweepDelay(npc)
	local seed = tonumber(npc) or 0
	return ((seed * 0.6180339887) % 1) * (SWEEP + SWEEP_REST)
end

local function sweep(c, on)
	if not on then
		if c.sweep then
			c.sweep:Stop()
		end
		c.sweepAt = nil
		c.sheen:Hide()
		return
	end
	if not c.sweep then
		local ok, group = pcall(c.sheen.CreateAnimationGroup, c.sheen)
		if not (ok and group) then
			c.sheen:Hide()
			return
		end
		local move = group:CreateAnimation("Translation")
		move:SetOffset(math.floor((c.laidW or 140) * 1.9), 0)
		move:SetDuration(SWEEP)
		pcall(move.SetSmoothing, move, "IN_OUT")
		pcall(move.SetEndDelay, move, SWEEP_REST)
		group:SetLooping("REPEAT")
		c.sweep = group
	end
	c.sheen:Show()
	if c.sweep:IsPlaying() or c.sweepAt then
		return
	end
	local delay = Card.SweepDelay(c.npc)
	if delay < 0.05 or not (C_Timer and C_Timer.After) then
		c.sweep:Play()
		return
	end
	-- a token for this wait: stopped and started again meanwhile, it is
	-- the later start's
	local token = {}
	c.sweepAt = token
	C_Timer.After(delay, function()
		if c.sweepAt == token then
			c.sweepAt = nil
			if c.sheen:IsShown() and not c.sweep:IsPlaying() then
				c.sweep:Play()
			end
		end
	end)
end
Card.Sweep = sweep

-- one enemy: { npc, name, kind (the type line), kills, points, tier (0 to 4),
-- rank, nameColor }
function Card.Dress(c, d)
	local t = d.tier or 0
	local metal = Card.TIERS[t]
	local mc = metal.color

	local function tint(tx, col, alpha)
		tx:SetVertexColor(col[1], col[2], col[3], alpha or 1)
	end
	-- the lines: one for none, two from bronze, three at platinum
	for n = 1, 3 do
		local want = (n == 1) or (n == 2 and t >= 1) or (n == 3 and t >= 4)
		for _, line in ipairs(c.lines[n]) do
			line:SetShown(want)
			if want then
				local col = n == 3 and metal.lo or mc
				line:SetColorTexture(col[1], col[2], col[3], n == 3 and 0.9 or 1)
			end
		end
	end
	-- with no corner art the plain line runs right into the corner
	if c.sides_ then
		c.sides_(c.lines[1], OUTER, t == 0 and 0 or OUTER_RUN)
	end
	for i, corner in ipairs(c.corners) do
		if t >= 1 then
			corner:SetTexture(TEX.corner[t])
			tint(corner, mc)
			corner:Show()
		else
			corner:Hide()
		end
		c.cornerGems[i]:SetShown(t >= 4)
		tint(c.cornerGems[i], PLATINUM_GEM)
	end
	-- the ground, notched where the corner art steps the border in
	Card.Notch(c, t >= 1 and (c.notchUnit or 0) or 0)
	-- THE ARCH IS THE RANK (Josh 2026-09-26: "differentiate rares and elites
	-- somehow, without confusing the mastery metal border. Maybe the inner
	-- stepped border around the portrait should become more ornate
	-- silver/gold?"). The border outside is the mastery; the arch round the
	-- enemy is what it is, in the tooltips' own gold and silver.
	local rs = Card.RANK_STYLE[d.rank] or Card.RANK_STYLE.normal
	local line, orn = rs.line, rs.ornament or rs.line
	for i = 1, 12 do
		c.arch[i]:SetColorTexture(line[1], line[2], line[3], rs.alpha or 1)
		c.arch[i]:Show()
		c.archIn[i]:SetColorTexture(line[1], line[2], line[3], 0.65)
		c.archIn[i]:SetShown(rs.level >= 1)
	end
	for _, g in ipairs(c.archGems) do
		tint(g, orn)
		g:SetShown(rs.level >= 1)
	end
	for _, b in ipairs(c.brackets) do
		tint(b, orn)
		b:SetShown(rs.level >= 2)
	end
	-- the crest, the sides, the pendant
	local cs = c.crestSizes and c.crestSizes[t]
	-- the rays, in their notch - unless gold's or platinum's crest stands
	-- over the keystone, where they would only be lines through it
	local rays = rs.level >= 3 and not cs
	for _, ray in ipairs(c.rays) do
		ray:SetColorTexture(orn[1], orn[2], orn[3], 1)
		ray:SetShown(rays)
	end
	c.rayGround:SetShown(rays)
	if cs then
		c.crest:SetTexture(TEX.crest[t])
		c.crest:ClearAllPoints()
		c.crest:SetSize(cs[1], cs[2])
		c.crest:SetPoint("TOPLEFT", c, "TOP", -cs[3], cs[4])
		tint(c.crest, mc)
		c.crest:Show()
	else
		c.crest:Hide()
	end
	c.crestGem:SetShown(t >= 4)
	tint(c.crestGem, PLATINUM_GEM)
	for _, s in ipairs(c.sides) do
		if t >= 3 then
			s:SetTexture(TEX.side[t])
			tint(s, mc)
			s:Show()
		else
			s:Hide()
		end
	end
	if t >= 4 then
		c.pendant:SetTexture(TEX.pendant)
		tint(c.pendant, mc)
	end
	c.pendant:SetShown(t >= 4)
	-- the rank, at the top of the arch
	local gem = Card.GEMS[d.rank]
	c.keystone:SetShown(gem ~= nil)
	if gem then
		tint(c.keystone, gem)
	end

	-- the words, and the fan under the name from gold
	c.name:SetText((d.name or ""):upper())
	Card.FitName(c)
	local nc = d.nameColor or { 0.95, 0.90, 0.80 }
	c.name:SetTextColor(nc[1], nc[2], nc[3])
	c.kind:SetText(d.kind or "")
	c.kind:SetTextColor(0.79, 0.72, 0.58)
	-- its category, in the category's colour (the window's V.CATEGORY)
	c.cat:SetText((d.category or ""):upper())
	local cc = d.categoryColor or { 0.62, 0.58, 0.50 }
	c.cat:SetTextColor(cc[1], cc[2], cc[3])
	c.cat:SetShown(d.category ~= nil)
	c.fan:SetShown(t >= 3)
	tint(c.fan, mc)
	c.kills:SetText(d.kills or "")
	c.killsLabel:SetText(string.upper("Kills"))
	c.points:SetText(d.points or "")
	c.pointsLabel:SetText(string.upper("Pts"))
	for _, fs in ipairs({ c.kills, c.points }) do
		fs:SetTextColor(0.95, 0.90, 0.80)
	end
	for _, fs in ipairs({ c.killsLabel, c.pointsLabel }) do
		fs:SetTextColor(0.66, 0.59, 0.49)
	end
	c.tier:SetText(t == 0 and "" or metal.name:upper())
	c.tier:SetTextColor(mc[1], mc[2], mc[3])
	c.dressedTier = t
	sweep(c, t >= 4)
	Card.Rewrite(c)
end

-- WRITTEN TWICE (Josh 2026-09-26: the lore line never showed on a card, and
-- a card's kill count was missing until the grid was scrolled). A face the
-- client has not drawn at a size before can draw nothing the first time its
-- text is set - the page, drawing the same lore in the same face, was fine,
-- because it was not the first. So a card's words are set again a frame
-- after it is dressed, once the face is there.
local TEXTS = { "name", "kind", "cat", "kills", "killsLabel", "tier", "points", "pointsLabel" }
function Card.Rewrite(c)
	if c.rewriting or not (C_Timer and C_Timer.After) then
		return
	end
	c.rewriting = true
	C_Timer.After(0, function()
		c.rewriting = nil
		for _, key in ipairs(TEXTS) do
			local fs = c[key]
			local words = fs and fs:GetText()
			if words and words ~= "" then
				fs:SetText("")
				fs:SetText(words)
				if key == "name" then
					Card.FitName(c)
				end
			end
		end
	end)
end

-- A LONG NAME, SMALLER (Josh 2026-09-26: "I don't really like seeing the
-- truncated text... resize the longer text smaller so more can fit to a
-- minimum"). The name steps down half a point at a time until it fits the
-- card, to seven tenths of its size and never under eight points; past that
-- it is cut short, as before. Measured again when the words are written the
-- second time, in case the face was not there to measure the first.
local NAME_FLOOR = 8
function Card.FitName(c)
	local base, room = c.nameSize, c.nameAvail
	if not (base and room) then
		return
	end
	local floor = math.max(NAME_FLOOR, base * 0.7)
	local size = base
	setFont(c.name, size)
	while size - 0.5 >= floor do
		local ok, width = pcall(c.name.GetStringWidth, c.name)
		if not ok or type(width) ~= "number" or width <= room then
			break
		end
		size = size - 0.5
		setFont(c.name, size)
	end
	c.nameFitted = size
	return size
end

-- A SHADOW UNDER A CARD PICKED UP (Josh 2026-09-26: "a drop shadow to the
-- card when hovered"). The toolkit's own is a tight edge for panels that sit
-- flat; a card lifted off the table throws a softer, deeper one, dropped a
-- little below it: rings a pixel further out and fainter each time, the
-- light from above.
local SHADOW_RINGS, SHADOW_DROP = 10, 4
local function shadow(c)
	if c.shadow then
		return c.shadow
	end
	local strips = {}
	for i = 1, SHADOW_RINGS do
		local a = 0.30 * (1 - (i - 1) / SHADOW_RINGS) ^ 2
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do
			local t = c:CreateTexture(nil, "BACKGROUND", nil, -8)
			t:SetColorTexture(0, 0, 0, side == "top" and a * 0.5 or a)
			t.side, t.ring = side, i - 1
			t:Hide()
			strips[#strips + 1] = t
		end
	end
	c.shadow = strips
	return strips
end

-- THE SHADOW HAS THE CARD'S SHAPE (Josh 2026-09-26: "it looks like there is
-- a solid background under the border that is taking the drop shadow"). A
-- square shadow under a card with its corners stepped in showed a square
-- card that was not there; the rings stop short of the corners by the same
-- notch the ground leaves clear (Card.Notch).
local function placeShadow(c)
	local n = c.notched or 0
	for _, t in ipairs(shadow(c)) do
		local o, d = t.ring, SHADOW_DROP
		t:ClearAllPoints()
		if t.side == "top" then
			t:SetPoint("BOTTOMLEFT", c, "TOPLEFT", n - o, o - d)
			t:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", -n + o, o - d)
			t:SetHeight(1)
		elseif t.side == "bottom" then
			t:SetPoint("TOPLEFT", c, "BOTTOMLEFT", n - o, -o - d)
			t:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", -n + o, -o - d)
			t:SetHeight(1)
		elseif t.side == "left" then
			t:SetPoint("TOPRIGHT", c, "TOPLEFT", -o, -n + o - d)
			t:SetPoint("BOTTOMRIGHT", c, "BOTTOMLEFT", -o, n - o - d)
			t:SetWidth(1)
		else
			t:SetPoint("TOPLEFT", c, "TOPRIGHT", o, -n + o - d)
			t:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", o, n - o - d)
			t:SetWidth(1)
		end
	end
end

function Card.Hover(c, on)
	c.hovered = on and true or false
	if c.hovered then
		placeShadow(c)
	end
	for _, t in ipairs(shadow(c)) do
		t:SetShown(c.hovered)
	end
	local sides = (c.notched or 0) > 0
	c.lit[1]:SetShown(c.hovered)
	c.lit[2]:SetShown(c.hovered and sides)
	c.lit[3]:SetShown(c.hovered and sides)
end

-- The ground (and the light under the cursor) as three strips: the middle
-- the card's full height, and the two sides short by `n` at the top and the
-- foot - so a square `n` on a side is left clear at each corner, where the
-- corner art steps the border in. With no corner art, `n` is 0: one whole
-- rectangle, square to its plain line.
function Card.Notch(c, n)
	local w, h = c.laidW or 0, Card.Height(c.laidW or 0)
	for _, set in ipairs({ c.ground, c.lit }) do
		place(set[1], c, n, 0, w - 2 * n, h)
		place(set[2], c, 0, n, n, h - 2 * n)
		place(set[3], c, w - n, n, n, h - 2 * n)
	end
	c.notched = n
	c.ground[1]:Show()
	c.ground[2]:SetShown(n > 0)
	c.ground[3]:SetShown(n > 0)
	Card.Hover(c, c.hovered)
end
