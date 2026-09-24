-- Tooltips: the same information, in two lines instead of seven
-- (Josh 2026-09-19).
--
-- The default unit tooltip spends a line each on the level, the race, the
-- class, the faction and an instruction about right-clicking, then hangs a
-- health bar under the lot. Pointing at somebody should cost a glance, not a
-- paragraph, and on a 1080-tall screen that box is a surprising amount of the
-- corner you were trying to look at.
--
--   Beeb Magus                8        name, in class colour, level on the right
--   Gnome Mage · <Nightwatch>          everything else, once
--
-- WHAT IT KEEPS. Everything you would actually act on: who, how tough, what
-- they are, who they run with. What it drops: the word "(Player)", the faction
-- you can already see on the nameplate unless it is the OTHER one, the
-- right-click instruction, and the health bar - all switchable, because every
-- one of those is somebody's favourite.
--
-- It rebuilds rather than hides: ClearLines and start again is the only way to
-- make the tooltip actually SHRINK. Blanking lines leaves their height behind,
-- which is a smaller tooltip with holes in it rather than a compact one.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Tips/Tips.lua")

local U = BT.Util

local M = BT.Module({
	key = "tips",
	group = "windows",
	title = "Tooltips",
	blurb = "compact unit tooltips",
	order = 30,
})

-- the compare tooltips' "Equipped" headers, dressed as furniture (see
-- dressHeader); none where the furniture kit is not loaded (the headless tests)
M.Headers = BT.Furniture and BT.Furniture.New({ panelAlpha = 0.96 }) or nil

local DIM = { 0.62, 0.68, 0.65 }

-- THE TOOLKIT'S OWN SKIN, ON THE TOOLTIP (Josh 2026-09-19). The compact
-- tooltip was the right shape in the wrong clothes: two tight lines inside
-- Blizzard's gold-and-stone frame, which is a heavier border than the thing
-- it now contains. This is the window's own panel - a flat near-black fill, a
-- one-pixel rim - and the spine down the left in whoever you are pointing
-- at's colour, which is the only bright thing on it and says class or
-- reaction before you have read a word.
--
-- The border is a NineSlice on this client: a child frame, so it draws OVER
-- anything we put on the tooltip itself. It has to be hidden rather than
-- covered, and put back the moment the module is switched off.
-- declared here because unskin() puts the fonts back and is written above the
-- place that knows what they were
local restoreFonts

-- three pixels rather than two: at tooltip scale a two-pixel rail reads as a
-- rim that got away rather than as a deliberate edge (Josh 2026-09-19)
local SPINE = 3
-- LESS ABOVE AND BELOW THAN AT THE SIDES (Josh 2026-09-19). Four all round
-- measures the same but does not read the same: the client already leaves
-- space above the first line and under the last, so four more on top of that
-- is twice the gap the sides have. Two matches what your eye sees.
--
-- AND THE SIDES GO NEGATIVE (Josh 2026-09-21). These are added to the client's
-- own inset, not used instead of it - about ten pixels before we say anything
-- - so a positive four put every line fourteen pixels from the edge, which on
-- a tooltip this compact is a margin wider than the text is tall. The same
-- trick the first line already uses to sit under its band works sideways: ask
-- for less than the client would leave. The name comes left and the level
-- goes right by the same amount, and every line under them follows, so the
-- body still lines up with the header.
local PAD_X, PAD_Y = -5, 2
-- BUT THE LEFT CLEARS THE SPINE (Josh 2026-09-22). The same negative number
-- on both sides put the words two pixels off the spine once the band went:
-- the right edge is a rim, the left edge is a rim AND a three-pixel spine, so
-- the left asks for that much more, and the same breath again.
local PAD_LEFT = PAD_X + SPINE + 2
-- AND THE BOTTOM GOES WITH THEM (Josh 2026-09-21). Same arithmetic as the
-- sides: this is added to the inset the client already leaves under the last
-- line, so a positive two still left a gap under the body twice the one the
-- header has above the name. It matches the sides, so the body sits in the
-- same margin on three edges and the header's own is left alone.
-- TWO MORE (Josh 2026-09-22). With the band gone the header's own air is
-- what the eye compares the bottom to, and at five the last line sat tight
-- against the rim.
local PAD_BOTTOM = -3
-- PULLING THE FIRST LINE UP (Josh 2026-09-20). Flush with the top edge, short,
-- and the name centred in it are three things the client's own twelve-pixel
-- inset will not allow at once - so the inset itself is what has to give. A
-- negative top padding asks the client to start its first line higher than it
-- otherwise would; if it refuses, nothing is worse than it was, and
-- /bt tips pad reports the inset it actually used.
local PAD_TOP = -6
-- THE HEADER'S RULE (Josh 2026-09-22). The name used to sit on a wash of its
-- class colour that faded out to the right - the one gradient in the addon,
-- a third statement of the class beside the spine and the words, and it
-- needed a drop shadow to keep the name legible on top of it. The header is
-- the name in its colour on the plain fill now, with a hairline this far
-- under the bottom of the line.
local RULE_DROP = 3

-- ONE WIDTH (Josh 2026-09-20). A tooltip sized to its own longest line is a
-- different shape for every person you point at - "Bixi Blimth / Gnome
-- Warrior" comes out half the width of somebody with a guild and two tags, and
-- the pair of them side by side look like two different addons.
--
-- A floor, not a fixed size: anything that genuinely needs more room still
-- gets it, and the quote above the tooltip follows the same number, so the
-- card and the tooltip under it stay the same width as each other.
local MIN_W = 200
-- and the most it will ask for to keep a long name on one line. Past this a
-- name really is too long and has to wrap somewhere (Josh 2026-09-20).
local MAX_W = 340
-- the air between the header and whatever the client says next: the rule
-- sits inside it, RULE_DROP down, with a breath under it
local HEADER_GAP = 7
-- five, not three: at tooltip scale three reads as a hairline that lost its
-- rim rather than as a bar with a level in it (Josh 2026-09-19)
local BAR_H = 5

-- WHAT THE HEALTH BAR WAS (Josh 2026-09-22). Compose sets its height to one
-- pixel or to BAR_H and paints it the accent, and switching the module off
-- only showed it again - a one-pixel sliver until the next /reload. Its own
-- height and colour are written down the first time it is touched.
local barWas
local function rememberBar(bar)
	if barWas or not bar then
		return
	end
	local ok, h = pcall(function() return bar:GetHeight() end)
	local okc, r, g, b = pcall(function() return bar:GetStatusBarColor() end)
	h = BT.Pill.Number(ok and h or nil, nil)
	barWas = {
		height = (h and h > 1) and h or 8,
		color = (okc and type(r) == "number") and { r, g, b } or nil,
	}
end

-- THE BOTTOM EDGE IS NOT THE TOP EDGE (Josh 2026-09-19). With the health bar
-- on, the bar lives inside the tooltip's bottom padding - so the bottom has to
-- carry the bar AND the same breath of space the top has, or the gap under the
-- last line reads as twice the gap above the first. With the bar off it is
-- just the same two pixels as everywhere else.
-- both declared here and written below, where opt() exists: skin() sits above
-- the settings reader and these are what it needs from it
local padBottom, repad

-- the same surface as every panel: a tooltip that is opaque while the window
-- behind it is not looks like it belongs to a different addon
local SKIN_FILL = BT.Widgets.FILL
local SKIN_RIM = BT.Widgets.RIM

-- WHAT IT IS, BEFORE YOU HAVE READ ANYTHING (Josh 2026-09-19). A rare or an
-- elite is the one thing about a mob you want to know while the cursor is
-- still moving, and it was a "+" or an "r" tacked onto the level - two
-- characters at the far end of the first line, which is the last place you
-- look. The whole edge of the tooltip carries it instead.
--
-- THE UNIT FRAMES' BORDER (Josh 2026-09-23: "can we use those same borders
-- for the same thing on tooltips?"). It was a thicker edge - a silver two for
-- a rare, a gold four for an elite. Now the tooltip keeps the hairline every
-- other panel wears, and an elite or a rare wears the ornate border outside
-- it, exactly as its unit frame does (UI/Ornament.lua): gold, silver, and a
-- crest on the elites. `rank` is the classification it shows.
local EDGE_PLAIN = { 1, SKIN_RIM }

local CLASSIFICATION_EDGE = {
	rare = { 1, SKIN_RIM, rank = "rare" },
	elite = { 1, SKIN_RIM, rank = "elite" },
	rareelite = { 1, SKIN_RIM, rank = "rareelite" },
	worldboss = { 1, SKIN_RIM, rank = "worldboss" },
}

-- Applied through the skin rather than set directly, because the tooltip is
-- re-dressed every time it shows itself: the edge it should wear is remembered
-- on the skin, or the next OnShow would put the hairline back.
local function applyEdge(tip, s)
	local edge = s.wantEdge or EDGE_PLAIN
	local w, colour = edge[1], edge[2]
	-- THE FILL IS PAINTED HERE, NOT WHERE IT WAS MADE (Josh 2026-09-21). The
	-- skin used to come from Widgets.Panel, which coloured it on the way out;
	-- its own surface does not, and nothing else did either, so the tooltip
	-- came up with the world showing through it.
	--
	-- The fill covers the tooltip and the ring is drawn over it: underneath,
	-- a gold elite edge came through the whole tooltip as a wash. The edge
	-- width is the rarity's, so it is passed rather than read from the theme.
	s.fill:ClearAllPoints()
	s.fill:SetAllPoints()
	-- OUTWARD (Josh 2026-09-22). A rare's two and an elite's four used to
	-- grow into the tooltip and eat its padding; the inner edge now stays
	-- where the hairline's is and the rest is drawn outside the frame
	BT.Pill.PaintSurface(s.surface, tip, SKIN_FILL, colour, w, true)
	-- THE SPINE IS THE LEFT EDGE (Josh 2026-09-22). On a plain edge the
	-- rim's left bar gives way to it: a hairline beside a three-pixel bar of
	-- colour read as a border with a stripe stuck on. A rare's silver and an
	-- elite's gold go all the way round, and the spine sits just inside.
	local base = (BT.Theme and BT.Theme.Thickness()) or 1
	s.plainEdge = w <= base
	s.accent:ClearAllPoints()
	if s.plainEdge then
		s.accent:SetPoint("TOPLEFT", 0, 0)
		s.accent:SetPoint("BOTTOMLEFT", 0, 0)
	else
		local inner = math.min(w, base)
		s.accent:SetPoint("TOPLEFT", inner, -inner)
		s.accent:SetPoint("BOTTOMLEFT", inner, inner)
	end
	M.LeftBar(s)
	-- the ornate border, made the first time a rank asks for one
	if edge.rank and not s.ornament and BT.Ornament then
		s.ornament = BT.Ornament.Build(tip, 2)
	end
	if s.ornament then
		BT.Ornament.Paint(s.ornament, edge.rank)
	end
end

-- the rim's left bar: hidden while the spine is standing in for it, shown
-- again the moment the spine goes or the edge is a rarity's
function M.LeftBar(s)
	local bar = s and s.rim and s.rim[3]
	if not (bar and bar.Hide and bar.Show) then
		return
	end
	local spine = s.accent and s.accent.IsShown and s.accent:IsShown()
	if spine and s.plainEdge then
		bar:Hide()
	else
		bar:Show()
	end
end
local skins = {}

-- EVERY TEXTURE, OR NONE OF THE PASS (Josh 2026-09-21). The skin builder is
-- wrapped in a pcall by its only caller, so one frame that will not make a
-- texture took the whole pass down silently - surface, edge, padding and all.
-- A texture that draws nothing keeps the rest running.
local function tex(tip, ...)
	local t = tip.CreateTexture and tip:CreateTexture(...)
	return t or BT.Pill.NOWHERE
end

local function skin(tip, force, ours)
	if not (tip and tip.CreateTexture) then
		return nil
	end
	local s = skins[tip]
	if not s then
		s = {}
		-- ITS OWN SURFACE, NOT A THEMED PANEL (Josh 2026-09-21). A tooltip's
		-- edge width is the rarity's, not the setting's - a silver two for a
		-- rare, a gold four for an elite - so it carries the shared fill and
		-- ring but sets their width itself in applyEdge.
		local skin = BT.Pill.Surface(tip, "BACKGROUND", 0)
		s.fill, s.rim = skin.fill, skin.rim
		s.surface = skin
		-- THE SPINE (Josh 2026-09-19). The accent used to be a lid across the
		-- top. Down the left edge, full height, it reads as something holding
		-- the block together, and it answers the question you are actually
		-- asking as you hover: on a person, what are they and are they
		-- hostile; on an item, is this worth picking up. One texture, two
		-- tooltips, and the rules it replaces are two lines of height back.
		--
		-- It sits inside the rim at x=1. The client's own text starts about
		-- ten pixels in, so nothing has to move to make room for it.
		s.accent = tex(tip, nil, "ARTWORK")
		s.accent:SetPoint("TOPLEFT", 1, -1)
		s.accent:SetPoint("BOTTOMLEFT", 1, 1)
		s.accent:SetWidth(SPINE)
		local a = BT.Widgets.ACCENT
		s.accent:SetColorTexture(a[1], a[2], a[3], 1)

		-- the hairline under the header (see RULE_DROP), hung where the first
		-- line is measured to end by M.HeaderRule
		s.rule = tex(tip, nil, "ARTWORK")
		s.rule:SetHeight(1)
		s.rule:SetColorTexture(SKIN_RIM[1], SKIN_RIM[2], SKIN_RIM[3], 0.95)
		s.rule:Hide()
		skins[tip] = s
	end
	-- THE CLIENT HAS TWO WAYS OF DRAWING A TOOLTIP (Josh 2026-09-19). The one
	-- you hover uses a NineSlice, which hides. The compare tooltips use the
	-- older backdrop - a fill and a border drawn by the frame itself - and
	-- hiding a NineSlice it does not have left the client's own dark blue
	-- sitting under our translucent surface, which is why one tooltip looked
	-- bluer and more heavily bordered than the one beside it.
	--
	-- The backdrop's own colours are remembered the first time and put back
	-- when the module is switched off; both are simply made invisible, which
	-- leaves ours as the only thing drawn.
	-- a frame, or nothing: some tooltips answer this with something that is
	-- not a frame at all, and indexing it throws inside the pcall that wraps
	-- this whole builder
	--
	-- AND SEE-THROUGH, NOT ONLY HIDDEN (Josh 2026-09-24: "Equipped and
	-- Equipped With tooltips still seem to have the blizzard default
	-- border"). The client lays a compare tooltip's border out again after it
	-- is shown, which shows it; a border with no alpha stays gone whoever
	-- shows it.
	if type(tip.NineSlice) == "table" and tip.NineSlice.Hide then
		pcall(tip.NineSlice.Hide, tip.NineSlice)
		pcall(tip.NineSlice.SetAlpha, tip.NineSlice, 0)
	end
	if tip.SetBackdropColor and tip.GetBackdropColor and not s.backdrop then
		local ok, r, g, b, a = pcall(tip.GetBackdropColor, tip)
		if ok and r then
			s.backdrop = { r, g, b, a }
		end
		local okb, br, bg2, bb, ba = pcall(tip.GetBackdropBorderColor, tip)
		if okb and br then
			s.backdropBorder = { br, bg2, bb, ba }
		end
	end
	if tip.SetBackdropColor then
		pcall(tip.SetBackdropColor, tip, 0, 0, 0, 0)
	end
	if tip.SetBackdropBorderColor then
		pcall(tip.SetBackdropBorderColor, tip, 0, 0, 0, 0)
	end
	-- CLEAR IT, DO NOT JUST MAKE IT INVISIBLE (Josh 2026-09-21). Zeroing the
	-- backdrop's two colours left the "Equipped" compare tooltip wearing a
	-- second, heavier edge that the tooltip beside it did not have: the edge
	-- file is drawn from its own art, and an alpha of nothing on the tint does
	-- not reach it. Taking the backdrop away entirely does, and the whole
	-- table is remembered so switching the module off gives it back.
	if tip.GetBackdrop and tip.SetBackdrop and s.hadBackdrop == nil then
		local ok, was = pcall(tip.GetBackdrop, tip)
		s.hadBackdrop = (ok and was) or false
	end
	if tip.SetBackdrop and s.hadBackdrop then
		pcall(tip.SetBackdrop, tip, nil)
	end

	if ours then
		s.ours = true
	end
	repad(tip, s, force)
	applyEdge(tip, s)
	BT.Pill.ShowSurface(s.surface, true)
	-- A SHADOW UNDER IT (Josh 2026-09-22), so it stands off whatever it is
	-- over - the panel most of all, which is the same dark as the tooltip
	BT.Widgets.Shadow(tip)
	BT.Widgets.ShowShadow(tip, true)
	return s
end

-- A BIGGER FONT STARTS FURTHER IN (Josh 2026-09-21). The name is set at
-- fourteen point and the lines under it at twelve, and a glyph's left side
-- bearing grows with its size - so with both anchored to the same inset, the
-- header's ink sits a couple of pixels right of the body's. Padding cannot fix
-- it: padding moves the anchor, and the anchor is already the same. The body
-- comes across to meet the header.
local BODY_INDENT = 2

local function indentBody(tip)
	local lines = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
	for i = 2, lines do
		BT.UnitTip.Indent(tip, i, BODY_INDENT)
		BT.UnitTip.Indent(tip, i, -BODY_INDENT, "TextRight")
	end
end

-- What edge this unit earns. Players never get one: a rare tag on somebody's
-- character would mean nothing.
--
-- Three answers, not two (Josh 2026-09-19). "Elite", "ordinary", and I COULD
-- NOT TELL - this client hands back secret values for things it does not want
-- an addon reading, and a secret string used as a table key simply misses, so
-- an unreadable classification looked exactly like an ordinary mob and the
-- gold edge came and went. When the answer is unreadable the tooltip keeps the
-- edge it already had rather than being told it is nothing special.
local UNKNOWN_EDGE = {}
M.UNKNOWN_EDGE = UNKNOWN_EDGE

M.lastClassification = "none yet"

local function edgeFor(unit, isPlayer)
	if isPlayer or not UnitClassification then
		M.lastClassification = isPlayer and "player" or "no API"
		return nil
	end
	local ok, class = pcall(UnitClassification, unit)
	if not ok then
		M.lastClassification = "the call failed"
		return UNKNOWN_EDGE
	end
	if type(class) ~= "string" or (issecretvalue and issecretvalue(class)) then
		M.lastClassification = ("unreadable (%s)"):format(type(class))
		return UNKNOWN_EDGE
	end
	M.lastClassification = class
	return CLASSIFICATION_EDGE[class]
end
M.EdgeFor = edgeFor

local function unskin(tip)
	local s = skins[tip]
	if s then
		BT.Pill.ShowSurface(s.surface, false)
		BT.Widgets.ShowShadow(tip, false)
		s.accent:Hide()
		if s.ornament then
			BT.Ornament.Paint(s.ornament, nil)
		end
		-- the client's own backdrop, exactly as it was before we hid it
		if s.backdrop and tip.SetBackdropColor then
			pcall(tip.SetBackdropColor, tip, s.backdrop[1], s.backdrop[2],
				s.backdrop[3], s.backdrop[4])
		end
		if s.hadBackdrop and tip.SetBackdrop then
			pcall(tip.SetBackdrop, tip, s.hadBackdrop)
		end
		if s.backdropBorder and tip.SetBackdropBorderColor then
			pcall(tip.SetBackdropBorderColor, tip, s.backdropBorder[1],
				s.backdropBorder[2], s.backdropBorder[3], s.backdropBorder[4])
		end
	end
	restoreFonts(tip)
	-- ONLY WHAT WAS SKINNED (Josh 2026-09-23, audit): OnDisable walks every
	-- tooltip we hooked, and one never skinned had its border shown and its
	-- padding zeroed by a switch that had done nothing to it
	if not s then
		return
	end
	-- the same guard skin() has: some tooltips answer this with something
	-- that is not a frame
	if tip and type(tip.NineSlice) == "table" and tip.NineSlice.Show then
		pcall(tip.NineSlice.SetAlpha, tip.NineSlice, 1)
		pcall(tip.NineSlice.Show, tip.NineSlice)
	end
	if tip and tip.SetPadding then
		pcall(tip.SetPadding, tip, 0, 0, 0, 0)
		s.padded = nil
	end
	-- and the width a unit tooltip was held to, handed back
	if tip and tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
end
local REACTION = {
	[1] = { 0.90, 0.35, 0.35 }, [2] = { 0.90, 0.35, 0.35 }, [3] = { 0.95, 0.70, 0.25 },
	[4] = { 0.95, 0.85, 0.30 }, [5] = { 0.35, 0.82, 0.45 }, [6] = { 0.35, 0.82, 0.45 },
	[7] = { 0.35, 0.82, 0.45 }, [8] = { 0.35, 0.82, 0.45 },
}

-- FOUR THINGS, NOT FOUR LINES (Josh 2026-09-19). Everything on the tooltip
-- was the same size in a different colour, which is a list rather than a
-- hierarchy: your eye has to read all of it to find the part it wanted. These
-- are the four roles it actually has, and each one is told apart by size and
-- weight before colour is spent on anything:
--
--   HEADER      the name, biggest, in class colour, with the level opposite
--   ---------   a hairline, so the name reads as a heading
--   subheader   what they are, small and grey: read it if you care
--   body        your note, the warm one, the reason you looked
--   footer      the tags, smaller again, along the bottom
--
-- The lines are Blizzard's own FontStrings and are shared with every other
-- tooltip, so anything set here is put back the moment this one goes away.
local HEADER, LEVEL, SUB, FOOT = 14, 12, 10, 10

local lineOf = function(tip, i, side) return BT.UnitTip.LineOf(tip, i, side) end
local sizeLine = function(tip, i, size, side) return BT.UnitTip.SizeLine(tip, i, size, side) end
restoreFonts = function(tip) return BT.UnitTip.RestoreFonts(tip) end

local function opt(name, fallback)
	local s = BT.settings and BT.settings.tips
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

-- the tests look at the edge a tooltip is wearing
function M.Skins()
	return skins
end

padBottom = function()
	if opt("healthBar", false) then
		return BAR_H + PAD_BOTTOM
	end
	return PAD_BOTTOM
end

-- what the module asked for, so a test can check the client kept it rather
-- than checking a number written down twice
function M.Padding()
	return PAD_X, PAD_BOTTOM, PAD_Y, PAD_TOP, PAD_LEFT
end

-- ONLY WHEN IT CHANGES (Josh 2026-09-19). SetPadding re-lays-out the tooltip,
-- and this runs on every OnShow and every rebuild - which on a mouseover that
-- re-sets itself each frame is a re-layout each frame, and that is what "the
-- tooltip jumps around" is.
--
-- But it cannot be set once and forgotten either: the client sets the padding
-- ITSELF when it inserts the health bar - that is how it reserves room for one
-- - so ours is replaced by a tall bottom edge and the band of empty space
-- under the last line comes back. Reading it first means we re-apply exactly
-- when the client has changed it underneath us.
--
-- AND IT HAS TO RUN LAST. Show() on a tooltip makes the client lay it out
-- again, bar and all, so a pass that ran before the Show was undone by it -
-- which is why the band survived three goes at this.
repad = function(tip, s, force)
	if not (tip and tip.SetPadding) then
		return
	end
	-- THE TIGHT PADDING IS THE ONES WE BUILD, NOT EVERY TOOLTIP (Josh
	-- 2026-09-21). Negative padding asks for a frame SMALLER than the client
	-- would draw. On a unit tooltip that is safe, because we write every line
	-- in it and it is measured afterwards. On one we only dress - an item, a
	-- quest pin - the client measured the text against its own inset before we
	-- said anything, so taking five pixels off each side leaves the frame ten
	-- pixels narrower than the words in it: the text runs past the edge and
	-- the last line falls out of the bottom.
	--
	-- This is the same trap as resizing an item's name to header size, which
	-- made it wider than the client had measured for.
	local ours = s and s.ours
	local right, left = ours and PAD_X or 0, ours and PAD_LEFT or 0
	-- the bar needs its room on ANY tooltip the client puts one in; only how
	-- tight the rest is depends on whether we wrote the lines
	local base = ours and PAD_BOTTOM or PAD_Y
	local bottom = opt("healthBar", false) and (BAR_H + base) or base
	local top = (s and s.wantTop) or PAD_Y
	local want = true
	if tip.GetPadding then
		local ok, r, b, l, t = pcall(tip.GetPadding, tip)
		if ok then
			local N = BT.Pill.Number
			want = N(r, -1) ~= right or N(b, -1) ~= bottom
				or N(l, -1) ~= left or N(t, -1) ~= top
		end
	elseif s and s.padded and not force then
		-- no way to ask: `force` is the rebuild, once per SetUnit, rather than
		-- once per frame
		want = false
	end
	if want then
		pcall(tip.SetPadding, tip, right, bottom, left, top)
		if s then
			s.padded = true
		end
	end
end
M.Repad = repad

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.tips = BT.settings.tips or {}
	BT.settings.tips[name] = value
end
M.SetOpt = setOpt

-- How hard this thing is, in as few characters as it can be said: a level, and
-- one mark for anything that is not an ordinary mob.
local function levelText(unit, isPlayer)
	local level = UnitLevel and UnitLevel(unit) or 0
	-- guarded like every other question we ask about a unit: this client
	-- refuses some of them, and an unguarded refusal here took the whole
	-- rebuild down inside a pcall, leaving the client's own tooltip (Josh
	-- 2026-09-19)
	local okc, class = pcall(function()
		return UnitClassification and UnitClassification(unit) or "normal"
	end)
	-- a secret answer is a string that cannot be compared: read as ordinary
	if not okc or type(class) ~= "string" or (issecretvalue and issecretvalue(class)) then
		class = "normal"
	end
	local text
	if level and level > 0 then
		text = tostring(level)
	else
		text = "??" -- a boss, or something too far above you to read
	end
	if class == "elite" or class == "rareelite" then
		text = text .. "+"
	end
	if class == "rare" or class == "rareelite" then
		text = text .. "r"
	end
	if class == "worldboss" then
		text = text .. "B"
	end
	local r, g, b = 0.85, 0.85, 0.85
	-- THE COLOUR MEANS "HOW HARD" (Josh 2026-09-22), which is a question
	-- about a mob. On a player a grey eleven read as "unimportant", so a
	-- player's level is plain text.
	if GetQuestDifficultyColor and level and level > 0 and not isPlayer then
		local c = GetQuestDifficultyColor(level)
		if c and c.r then
			r, g, b = c.r, c.g, c.b
		end
	end
	return text, r, g, b
end

local function reactionColor(unit)
	local n = UnitReaction and UnitReaction(unit, "player")
	local c = n and REACTION[n]
	return c or { 0.85, 0.85, 0.85 }
end

-- The second line: what they are, and who they run with, joined by a dot so it
-- reads as one fact rather than a list.
local function detailLine(unit, isPlayer)
	local bits = {}
	-- everything this line SPEAKS FOR, whether it printed it or deliberately
	-- left it out: the sweep that carries the client's remaining lines over
	-- needs to know which ones are already said (Josh 2026-09-19)
	local spoken = {}
	if isPlayer then
		local race = UnitRace and UnitRace(unit)
		local class = UnitClass and UnitClass(unit)
		local both = ((race or "") .. " " .. (class or "")):match("^%s*(.-)%s*$")
		if both ~= "" then
			bits[#bits + 1] = both
		end
		local guild = GetGuildInfo and GetGuildInfo(unit)
		if guild then
			spoken["<" .. guild .. ">"] = true
			spoken[guild] = true
			if opt("guild", true) then
				bits[#bits + 1] = "<" .. guild .. ">"
			end
		end
		-- the faction only when it is the one you are not: yours is not news
		local theirs = UnitFactionGroup and UnitFactionGroup(unit)
		local mine = UnitFactionGroup and UnitFactionGroup("player")
		if theirs then
			spoken[theirs] = true
			spoken[_G["FACTION_" .. theirs:upper()] or theirs] = true
		end
		if mine then
			spoken[mine] = true
			spoken[_G["FACTION_" .. mine:upper()] or mine] = true
		end
		if opt("faction", true) and theirs and mine and theirs ~= mine and theirs ~= "Neutral" then
			bits[#bits + 1] = theirs
		end
	else
		-- a title says more than a creature type: <Innkeeper> is why you
		-- clicked, "Humanoid" is not
		-- read off the tooltip's own second line: UnitPVPName returns the
		-- name with the title folded in, never the title on its own
		local title = nil
		if _G.GameTooltipTextLeft2 then
			local second = _G.GameTooltipTextLeft2:GetText()
			if second and second:find("^<") then
				title = second:match("^<(.*)>$")
			end
		end
		if title and title ~= "" then
			spoken["<" .. title .. ">"] = true
			bits[#bits + 1] = "<" .. title .. ">"
		end
		-- the family and the type both: whichever one the client wrote on its
		-- own line is already said by this one
		local family = UnitCreatureFamily and UnitCreatureFamily(unit)
		local kind = UnitCreatureType and UnitCreatureType(unit)
		spoken[family or ""] = true
		spoken[kind or ""] = true
		if (not title or title == "") and (family or kind) then
			bits[#bits + 1] = family or kind
		end
		if UnitIsDead and UnitIsDead(unit) then
			bits[#bits + 1] = "Dead"
		end
	end
	for _, b in ipairs(bits) do
		spoken[b] = true
	end
	return table.concat(bits, " · "), spoken
end

-- THE REWRITE. Runs before every other contributor, because everything after
-- it adds lines to what this leaves behind.
-- THE CLIENT'S OWN FOOTNOTE, AND WHY IT STAYS (Josh 2026-09-19). Hover a unit
-- FRAME and Blizzard appends "<Right click for Frame Settings>" AFTER the
-- tooltip has been set - after every hook we have - so ClearLines never sees
-- it and nothing we do during a rebuild can refuse it.
--
-- It was unwritten a frame later instead, and that was worse than the line:
--
--   the text was blanked and the line sized to a pixel, but the FONT is the
--   client's own FontString and it survives. The next time the client wrote
--   that line it wrote it into a one-point font - the tiny text along the
--   bottom edge - and because our pass changed the tooltip's height a frame
--   after it was drawn, the whole tooltip grew and shrank once per frame.
--
-- So it stays. A line of small print at the bottom of a tooltip is a fair
-- price for one that does not flicker, and the alternative is a race against
-- the client that we lose every frame.

-- WHY YOU ARE HITTING IT (Josh 2026-09-19). The client writes the quests a
-- creature counts towards onto its tooltip - the quest's name, then each
-- objective with its count - and rebuilding the tooltip threw all of it away.
-- That is the one thing on a mob's tooltip you actually read.
--
-- There is no API for it on this build: the lines exist only as text the
-- client already wrote, so they have to be lifted before ClearLines, the same
-- way an NPC's <Innkeeper> title is. Guessing which lines they are from their
-- shape is fragile, so they are matched against your own quest log instead: a
-- line whose text is the title of a quest you are on begins the block, and
-- everything under it until the next known title or the end is its objectives.
-- What ENDS a quest block. The client's own footnotes sit under the quest
-- lines, so without these the "Press F6" line gets copied back in as if it
-- were an objective (Josh 2026-09-19).
local NOT_A_QUEST = { "Press F6", "Right click", "Frame Settings" }

local QUEST_TITLE = { 1.00, 0.83, 0.25 }
local QUEST_LINE = { 0.58, 0.65, 0.62 }
local QUEST_DONE = { 0.36, 0.70, 0.48 }

-- EVERYTHING ELSE THE CLIENT SAID (Josh 2026-09-19). Rebuilding a tooltip
-- means every line the client wrote is gone unless we put it back, and the
-- client writes more than the name and the level: tapped, tameable, skinnable,
-- PvP, "Looking for group", a summon that will not work, whatever the next
-- patch adds. Listing them all would be a list that goes stale.
--
-- So the rule is the other way round: anything the client wrote that we have
-- not SAID OURSELVES comes across as a footnote. detailLine reports what it
-- speaks for - including what it deliberately left out, like your own faction
-- - and the name, the level line and the quest block are accounted for here.
local function clientLines(tip, spoken, name)
	if not tip.NumLines then
		return nil
	end
	local levelWord = _G.LEVEL
	local out = nil
	for i = 2, BT.Pill.Number(tip:NumLines(), 0) do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" then
			local trimmed = text:match("^%s*(.-)%s*$")
			local skip = trimmed == "" or trimmed == name or spoken[trimmed]
			-- "Level 8 Elite", in whatever this client calls a level
			if not skip and levelWord and trimmed:find(levelWord, 1, true) == 1 then
				skip = true
			end
			if not skip then
				for _, needle in ipairs(NOT_A_QUEST) do
					if trimmed:find(needle, 1, true) then
						skip = true
						break
					end
				end
			end
			if not skip then
				out = out or {}
				out[#out + 1] = trimmed
			end
		end
	end
	return out
end

-- The hairline under the header, hung where the first line actually ends.
-- Measured rather than assumed: the client insets its first line by its own
-- ten pixels plus whatever padding we asked for, scales the whole tooltip,
-- and a rule at a hard-coded height is a rule that misses (Josh 2026-09-20,
-- learnt on the band this replaced; the arithmetic is the same).
function M.HeaderRule(tip, s)
	if not (s and s.rule) then
		return nil
	end
	local fs = lineOf(tip, 1)
	local N = BT.Pill.Number
	local tipTop = N(tip.GetTop and tip:GetTop(), nil)
	local lineBottom = N(fs and fs.GetBottom and fs:GetBottom(), nil)
	local drop = nil
	if tipTop and lineBottom and tipTop > lineBottom then
		drop = tipTop - lineBottom
	end
	-- A NUMBER IS NOT AN ANSWER. Two coordinates from different frames
	-- subtract to nonsense, and the guard cannot catch that; an unmeasured
	-- line is assumed to sit where the client's inset and our pull-up put it.
	if not drop or drop < HEADER or drop > HEADER * 4 then
		drop = (PAD_Y + 10 + PAD_TOP) + HEADER + 2
	end
	drop = drop + RULE_DROP
	s.rule:ClearAllPoints()
	-- from the spine to the rim, so the two read as one frame round the name
	s.rule:SetPoint("TOPLEFT", tip, "TOPLEFT", 1 + SPINE, -drop)
	s.rule:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -1, -drop)
	s.rule:SetColorTexture(SKIN_RIM[1], SKIN_RIM[2], SKIN_RIM[3], 0.95)
	s.rule:Show()
	return s.rule
end

-- EVERYTHING A UNIT LEFT BEHIND (Josh 2026-09-21). A quest object in the
-- world, a herb node, a mailbox: the client shows these on GameTooltip and
-- they are neither a unit nor an item, so NEITHER of our rebuilds runs on
-- them. Whatever the tooltip was wearing a moment ago is what they get.
--
-- That is why the same quest item looked right on its own, lost its skin after
-- hovering yourself, and wore an NPC's nameplate after hovering one: three
-- different sets of leftovers.
--
-- So anything that is not a unit is stripped back to the plain surface first,
-- and ComposeItem adds the item things on top if it turns out to be an item.
function M.DressPlain(tip)
	local s = skins[tip]
	if s then
		s.wantEdge = nil
		s.wantTop = nil
		s.ours = nil
		if s.accent then
			s.accent:Hide()
		end
	end
	M.HideRule(tip)
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	-- force: the padding a unit asked for has to come off even though nothing
	-- else about the tooltip changed
	M.Dress(tip, true)
	if s then
		applyEdge(tip, s)
	end
	return s
end

function M.HideRule(tip)
	local s = skins[tip]
	if s and s.rule then
		s.rule:Hide()
	end
end

-- Returns the block, and the set of raw lines it used up so the sweep above
-- does not carry them over a second time.
local function questBlock(tip)
	local used = {}
	if not (tip.NumLines and BT.Quests and BT.Quests.Watched) then
		return nil, used
	end
	-- every quest in the log, not only the followed ones: a mob can count
	-- towards one you are not tracking, and the client still says so
	local titles = {}
	local ok, all = pcall(BT.Quests.All)
	if not (ok and all) then
		return nil, used
	end
	for _, title in ipairs(all) do
		titles[title] = true
	end
	if not next(titles) then
		return nil, used
	end
	local out, inBlock = nil, false
	for i = 2, BT.Pill.Number(tip:NumLines(), 0) do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		local chrome = false
		if type(text) == "string" then
			for _, needle in ipairs(NOT_A_QUEST) do
				if text:find(needle, 1, true) then
					chrome = true
					break
				end
			end
		end
		if chrome or text == "" then
			inBlock = false
		elseif type(text) == "string" then
			local trimmed = text:match("^%s*(.-)%s*$")
			if titles[trimmed] then
				out = out or {}
				out[#out + 1] = { text = trimmed, title = true }
				used[trimmed] = true
				inBlock = true
			elseif inBlock then
				used[trimmed] = true
				-- an objective, with or without the client's leading dash
				local body = trimmed:match("^%-%s*(.+)$") or trimmed
				local words, have, need = BT.Quests.SplitObjective(body)
				local done = (have and need and have >= need) or false
				out[#out + 1] = {
					text = (have and need) and ("%d/%d  %s"):format(have, need, words) or words,
					done = done,
				}
			end
		end
	end
	return out, used
end

-- A READ-ONLY LOOK AT WHAT THE TOOLTIP ACTUALLY IS: every line with its size,
-- the padding, the height, and the health bar's own geometry. Kept rather than
-- printed, because a tooltip is gone by the time you have typed anything.
M.snaps = {}

function M.Snapshot(tip, when)
	if not (tip and tip.NumLines) then
		return
	end
	local N = BT.Pill.Number
	local snap = { when = when, lines = {} }
	local ok, n = pcall(tip.NumLines, tip)
	n = ok and N(n, 0) or 0
	for i = 1, n do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		local size = fs and fs.GetFont and select(2, fs:GetFont())
		snap.lines[i] = ("%d [%s] %s"):format(i, tostring(N(size, 0)),
			(type(text) == "string") and ("'" .. text .. "'") or tostring(text))
	end
	if tip.GetPadding then
		local okp, r, b, l, t = pcall(tip.GetPadding, tip)
		snap.padding = okp
			and ("r%s b%s l%s t%s"):format(N(r, -1), N(b, -1), N(l, -1), N(t, -1))
			or "unreadable"
	else
		snap.padding = "no GetPadding on this client"
	end
	snap.height = N(tip.GetHeight and tip:GetHeight(), -1)
	-- THE BAND, IN NUMBERS (Josh 2026-09-20). Three goes at seating the name
	-- in its own wash by reasoning about where the client puts a tooltip line.
	-- These are the four values the answer is made of.
	local fs1 = lineOf(tip, 1)
	local sk = skins[tip]
	snap.band = ("tip top %s · line1 top %s bottom %s height %s · rule top %s · scale %s")
		:format(N(tip.GetTop and tip:GetTop(), -1),
			N(fs1 and fs1.GetTop and fs1:GetTop(), -1),
			N(fs1 and fs1.GetBottom and fs1:GetBottom(), -1),
			N(fs1 and fs1.GetHeight and fs1:GetHeight(), -1),
			N(sk and sk.rule and sk.rule.GetTop and sk.rule:GetTop(), -1),
			N(tip.GetEffectiveScale and tip:GetEffectiveScale(), -1))
	local bar = GameTooltipStatusBar
	if bar then
		snap.bar = ("%s h%s"):format(bar:IsShown() and "shown" or "hidden",
			N(bar.GetHeight and bar:GetHeight(), -1))
		if bar.GetNumPoints and bar.GetPoint then
			local pts = {}
			for i = 1, N(bar:GetNumPoints(), 0) do
				local pt, _, rel, x, y = bar:GetPoint(i)
				pts[#pts + 1] = ("%s->%s %s,%s")
					:format(tostring(pt), tostring(rel), N(x, 0), N(y, 0))
			end
			snap.bar = snap.bar .. " · " .. table.concat(pts, " | ")
		end
	else
		snap.bar = "no status bar"
	end
	M.snaps[when] = snap
end

-- THE BAND IS A LINE (Josh 2026-09-19). Measured, finally, rather than
-- reasoned about: the padding was ours all along (r4 b2 l4 t2) and the tooltip
-- simply had a fifth line on it reading " " at ten point. The client reserves
-- room for its health bar by adding a BLANK LINE, and it puts that line back
-- when the tooltip lays itself out - which our own Show() at the end of the
-- rebuild asks it to do.
--
-- Shrinking it is safe in a way that shrinking the "Press F6" line was not:
-- that line has words in it, so when the client rewrote it the words came back
-- in a one-point font. This one is a space. Rewritten or not, a space at one
-- point looks the same as no line at all.
--
-- With the bar switched on the line is left alone: that space is where the bar
-- goes, which is the whole reason the client reserved it.
local function squeezeBlankTail(tip)
	if opt("healthBar", false) or not tip.NumLines then
		return 0
	end
	local ok, n = pcall(tip.NumLines, tip)
	n = ok and BT.Pill.Number(n, 0) or 0
	local squeezed = 0
	for i = n, 2, -1 do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and text:match("^%s*$") then
			sizeLine(tip, i, 1)
			squeezed = squeezed + 1
		else
			break
		end
	end
	return squeezed
end
M.SqueezeBlankTail = squeezeBlankTail

function M.Compose(tip, unit)
	if not (tip.ClearLines and tip.AddDoubleLine) then
		return
	end
	-- THIS ONE IS OURS (Josh 2026-09-21). Marked here rather than deep in the
	-- nameplate code, because it is true of every tooltip we rebuild whether
	-- or not it ends up with a band on it - and it is what says the tight
	-- padding is safe: we write every line, so the client measures the frame
	-- after we are done rather than before.
	if skins[tip] then
		skins[tip].ours = true
	end
	local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
	local name
	if isPlayer and BT.Collect and BT.Collect.UnitFullName then
		name = BT.Collect.UnitFullName(unit)
	end
	name = name or (GetUnitName and GetUnitName(unit, false)) or (UnitName and UnitName(unit)) or "?"

	local nr, ng, nb
	if isPlayer then
		local _, class = UnitClass(unit)
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		nr, ng, nb = (c and c.r) or 0.9, (c and c.g) or 0.9, (c and c.b) or 0.9
	else
		local c = reactionColor(unit)
		nr, ng, nb = c[1], c[2], c[3]
	end

	-- READ BEFORE CLEARING (Josh 2026-09-19). An NPC's title only exists as a
	-- line the client already wrote - <Innkeeper> is on the tooltip, not in an
	-- API - so it has to be picked up while it is still there.
	local detail, spoken = detailLine(unit, isPlayer)
	local quests, usedByQuests = questBlock(tip)
	for line in pairs(usedByQuests or {}) do
		spoken[line] = true
	end
	local extra = clientLines(tip, spoken, name)
	-- ONE OF THEM SAYS IT BETTER (Josh 2026-09-20). Ours is built from
	-- UnitRace and UnitClass; the client's is whatever it knows, and on this
	-- build it can be either longer or shorter than ours:
	--
	--   ours "Druid"         theirs "High Order Skyborne Druid"  - keep theirs
	--   ours "Gnome Warlock" theirs "Warlock"                    - keep ours
	--
	-- The first case was fixed and the second was not, which is why the
	-- warlock still read "Gnome Warlock / Warlock". Whichever line contains
	-- the other is the one that survives; neither is written twice.
	if detail ~= "" and extra then
		local keep = {}
		for _, line in ipairs(extra) do
			if line == detail then
				-- the same words exactly: ours is already going on
			elseif line:find(detail, 1, true) then
				detail = "" -- theirs says everything ours does, and more
				keep[#keep + 1] = line
			elseif detail:find(line, 1, true) then
				-- ours says everything theirs does: theirs is dropped
			else
				keep[#keep + 1] = line
			end
		end
		extra = (#keep > 0) and keep or nil
	end

	local level, lr, lg, lb = levelText(unit, isPlayer)

	tip:ClearLines()
	tip:AddDoubleLine(name, level, nr, ng, nb, lr, lg, lb)
	-- A BREATH UNDER THE HEADER (Josh 2026-09-20). Whatever comes next used
	-- to sit hard against the bottom of the header - "Gnome Warlock" tight
	-- under the name - because a tooltip line has no margin of its own. This
	-- is the same trick the note used: a line with nothing on it, sized down
	-- to the gap we actually want; the rule sits inside it.
	tip:AddLine(" ")
	local spacer = BT.Pill.Number(tip.NumLines and tip:NumLines(), 2)
	sizeLine(tip, spacer, HEADER_GAP)

	if detail ~= "" then
		tip:AddLine(detail, DIM[1], DIM[2], DIM[3])
	end

	-- the header is a heading, the line under it is small print
	sizeLine(tip, 1, HEADER)
	sizeLine(tip, 1, LEVEL, "TextRight")
	indentBody(tip)
	if detail ~= "" then
		-- the line after the spacer, not line 2: line 2 IS the spacer, and
		-- sizing it left the small print at the client's full size
		sizeLine(tip, spacer + 1, SUB)
	end

	-- whatever else the client had to say - tapped, tameable, skinnable, a
	-- status we have never heard of - as small print under the name
	if extra then
		local from = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0) + 1
		for _, line in ipairs(extra) do
			tip:AddLine(line, DIM[1], DIM[2], DIM[3])
		end
		for i = from, BT.Pill.Number(tip.NumLines and tip:NumLines(), 0) do
			sizeLine(tip, i, FOOT)
		end
	end

	-- WHO IT IS POINTING AT (Josh 2026-09-24), when asked for: a line of small
	-- print. The name may be secret; the client joins it for us.
	if opt("targetLine", false) then
		local t = tostring(unit or "") .. "target"
		local okE, exists = pcall(UnitExists, t)
		if okE and exists == true then
			local okN, who = pcall(UnitName, t)
			if okN and who ~= nil then
				local ok, line = pcall(function() return "Targeting " .. who end)
				if ok then
					tip:AddLine(line, DIM[1], DIM[2], DIM[3])
					sizeLine(tip, BT.Pill.Number(tip.NumLines and tip:NumLines(), 0), SUB)
				end
			end
		end
	end

	-- and the quests this one counts towards, put back in our own sizes: the
	-- quest's name as a small heading, its objectives under it as footnotes
	if quests then
		local first = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0) + 1
		for _, q in ipairs(quests) do
			local c = q.title and QUEST_TITLE or (q.done and QUEST_DONE or QUEST_LINE)
			tip:AddLine((q.title and "" or "    ") .. q.text, c[1], c[2], c[3])
		end
		for i = first, BT.Pill.Number(tip.NumLines and tip:NumLines(), 0) do
			sizeLine(tip, i, SUB)
		end
	end

	-- the skin, and the spine in whoever's colour this is
	-- set before dressing: the skin applies whatever edge is remembered on it,
	-- so a rare's silver survives the tooltip showing itself again
	local edge = edgeFor(unit, isPlayer)
	local worn = skins[tip]
	if worn and edge ~= UNKNOWN_EDGE then
		worn.wantEdge = edge
	end
	local s = M.Dress(tip, true, true)
	if s then
		if edge ~= UNKNOWN_EDGE then
			s.wantEdge = edge
		end
		applyEdge(tip, s)
	end

	if GameTooltipStatusBar then
		rememberBar(GameTooltipStatusBar)
		if opt("healthBar", false) then
			-- flat and thin, like every other bar in the toolkit, rather than
			-- the client's raised green pill
			GameTooltipStatusBar:SetHeight(BAR_H)
			if GameTooltipStatusBar.SetStatusBarColor then
				local a = BT.Widgets.ACCENT
				GameTooltipStatusBar:SetStatusBarColor(a[1], a[2], a[3])
			end
			GameTooltipStatusBar:Show()
		else
			-- HIDDEN IS NOT GONE (Josh 2026-09-19). The client sizes the
			-- tooltip with room for this bar before we get to it, so hiding it
			-- left its height behind as a band of empty space under the last
			-- line. Nothing can be drawn in one pixel.
			if GameTooltipStatusBar.SetHeight then
				GameTooltipStatusBar:SetHeight(1)
			end
			GameTooltipStatusBar:Hide()
		end
	end
	-- the pull-up belongs to a unit tooltip: we wrote every line in it, so
	-- the header may sit as close to the rim as the body does to the sides
	if skins[tip] then
		skins[tip].wantTop = PAD_TOP
		-- and this one is OURS: we wrote every line in it, so it may be
		-- measured tighter than the client would have
		skins[tip].ours = true
	end
	-- ONE WIDTH, UNLESS THE NAME NEEDS MORE (Josh 2026-09-20). A header that
	-- wraps is the worst line on a tooltip: it is the biggest text there, so
	-- two ragged halves of a name are the first thing you see, and on a unit
	-- the band behind it was sized for one line.
	--
	-- The floor is raised to whatever the name and its level actually measure,
	-- up to a point - past that a name is genuinely too long and has to break
	-- somewhere. The ruler is the same one the tag row uses.
	-- the name in the face it is drawn in, the heavier one (it was measured
	-- in the lighter, and a long name came out short and wrapped); a name
	-- the client keeps secret cannot be measured, and is left to the client
	if tip.SetMinimumWidth and not (issecretvalue and issecretvalue(name)) then
		local needs = BT.UnitTip.Measure(name, HEADER, "name") + BT.UnitTip.Measure("    " .. level, HEADER)
			+ PAD_X + PAD_LEFT + 14
		pcall(tip.SetMinimumWidth, tip,
			math.max(MIN_W, math.min(MAX_W, math.floor(needs))))
	end
	-- the rebuild changed how many lines there are, so the box has to be
	-- measured again or it keeps the height of what it used to say (and
	-- our own Show is not a new tooltip: see M.composing)
	M.composing = true
	pcall(tip.Show, tip)
	M.composing = false
	-- the blank line the client reserves for its health bar, taken down to a
	-- pixel when there is no bar to put in it. Twice: laying the tooltip out is
	-- what adds the line, so the second pass catches one added by the first.
	if squeezeBlankTail(tip) > 0 then
		tip:Show()
		squeezeBlankTail(tip)
	end

	-- and the padding goes on LAST of all: every one of those layouts is the
	-- client putting its room for the health bar back
	repad(tip, skins[tip], true)

	-- THE RULE GOES ON LAST OF ALL (Josh 2026-09-20). It is measured from
	-- where the client actually put the first line, and the client moves that
	-- line every time the tooltip lays itself out - which the padding above
	-- makes it do.
	-- A SECOND CHANCE AT THE SKIN (Josh 2026-09-20). The skin is built inside
	-- a pcall: if anything in that build throws - a texture the client is not
	-- ready to hand out on the very first tooltip of a session - `skins[tip]`
	-- is never set and Dress returns nothing. Asking again costs nothing when
	-- the first ask worked.
	worn = skins[tip]
	if not (worn and worn.rule) then
		M.Dress(tip, true)
		worn = skins[tip]
	end
	if worn and worn.rule then
		M.HeaderRule(tip, worn)
		-- THE SPINE SAYS WHO (Josh 2026-09-22). Class colour for a player,
		-- reaction colour for anything else: the same two-pixel edge the item
		-- tooltip and the quest tracker wear, in the colour of the thing you
		-- are asking about (see the README, "The spine"). Painted here, after
		-- the second chance at the skin, so the first tooltip of a session
		-- gets it too.
		worn.accent:SetColorTexture(nr, ng, nb, 0.9)
		-- NOT ON A RANKED MOB (Josh 2026-09-23): only an NPC is rare or elite,
		-- and the border round it already says what it is; a stripe of its
		-- reaction colour beside the border was two things saying one. The
		-- edge's own left bar comes back in its place (M.LeftBar).
		local ranked = worn.ornament and worn.ornament.style ~= nil
		worn.accent:SetShown(not ranked)
		M.LeftBar(worn)
	end

	-- OFF UNLESS ASKED (Josh 2026-09-19). Read-only either way, but scheduling
	-- anything at all against a tooltip is the shape of bug that produced the
	-- tiny text and the flicker, so the default path schedules nothing.
	-- /bt tips pad on turns it on for as long as it takes to measure.
	if M.measuring then
		M.Snapshot(tip, "after the rebuild")
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function() M.Snapshot(tip, "one frame later") end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- ITEM TOOLTIPS
--
-- Nobody rebuilds an item tooltip: the client knows what a recipe says and we
-- do not. Two things are done to it instead.
--
-- THE SPINE, IN THE ITEM'S QUALITY. Grey, white, green, blue, purple - the
-- same edge the unit tooltip wears, answering the same kind of question one
-- glance earlier than reading the name in its colour does.
--
-- THE QUIET FOOTER. "Sell Price: 37" and "Press F6 to submit an issue for
-- this Item" arrive in the same size and a louder colour than what the item
-- actually does. They are footnotes, so they are sized and coloured as
-- footnotes, in place - the lines cannot be moved, but they can stop
-- shouting.
-- ---------------------------------------------------------------------------
local WHITE = { 1, 1, 1 }

-- THE CLIENT'S OWN HELPER THROWS ON ITS OWN TOOLTIPS (Josh 2026-09-21).
-- Sweeping for every frame that says it is a GameTooltip found some the
-- client never puts items in - SettingsTooltip among them - and asking
-- TooltipUtil what item is displayed on one of those dies inside Blizzard's
-- code, not ours. Both ways of asking go through a pcall now: "what item is
-- this" is a question a tooltip is allowed to have no answer to.
local function itemQuality(tip)
	local link, quality
	if TooltipUtil and TooltipUtil.GetDisplayedItem then
		local ok, found = pcall(TooltipUtil.GetDisplayedItem, tip)
		link = ok and found or nil
	end
	if not link and tip.GetItem then
		local ok, _, found = pcall(tip.GetItem, tip)
		link = ok and found or nil
	end
	if not link then
		return nil
	end
	if C_Item and C_Item.GetItemQualityByID then
		local ok, q = pcall(C_Item.GetItemQualityByID, link)
		quality = ok and q or nil
	end
	if quality == nil and GetItemInfo then
		quality = select(3, GetItemInfo(link))
	end
	if quality == nil then
		return nil
	end
	local get = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
	if not get then
		return nil
	end
	local ok, r, g, b = pcall(get, quality)
	if ok and type(r) == "number" then
		return r, g, b
	end
	return nil
end

-- A line that is a footnote rather than a fact about the item.
local function isFootnote(text)
	if not text or text == "" then
		return nil
	end
	if SELL_PRICE and text:find(SELL_PRICE, 1, true) then
		return "price"
	end
	if text:find("Sell Price", 1, true) then
		return "price"
	end
	-- the beta client's own line, on every item in the game
	if text:find("submit an issue", 1, true) or text:find("F6", 1, true) then
		return "beta"
	end
	return nil
end

-- an item's name sits on its quality spine, so it gets the same edge the unit
-- name gets on its class band
local function shadowTitle(tip)
	BT.UnitTip.Shadow(tip, 1)
	BT.UnitTip.Shadow(tip, 1, "TextRight")
end

local function quietFooter(tip)
	-- through the guard like every other measurement: this now runs on
	-- tooltips we did not build, and one of them answering NumLines with
	-- something that is not a number would take the whole pass down
	local lines = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
	for i = 2, lines do
		local fs = BT.UnitTip.LineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		local kind = isFootnote(text)
		if kind and fs.SetTextColor then
			BT.UnitTip.SizeLine(tip, i, FOOT)
			if kind == "beta" then
				fs:SetTextColor(0.34, 0.39, 0.37) -- nearly gone; it is not about the item
			else
				fs:SetTextColor(0.55, 0.60, 0.58)
			end
		end
	end
end

-- ONE PLACE THAT DRESSES A TOOLTIP (Josh 2026-09-19). The skin and the size
-- belong to every tooltip this module is responsible for, not only to the unit
-- one it rebuilds - the item tooltip staying at the client's size while the
-- panel said 70% is what "the options do nothing" looked like. The skin is
-- guarded: a client that will not take a texture on its tooltip still gets the
-- size, rather than losing both to one error.
-- `force` says this is a rebuild rather than a tooltip merely showing itself:
-- the padding is re-asserted even on a client that will not tell us what it is.
-- `ours` says we are about to write every line in this tooltip, which is what
-- makes the tight padding safe. It has to be known BEFORE repad runs, not set
-- afterwards: repad is inside here, and a flag set after it only takes effect
-- on the next tooltip (Josh 2026-09-21).
function M.Dress(tip, force, ours)
	if not tip then
		return nil
	end
	local ok, s = pcall(skin, tip, force, ours)
	-- likewise: SetScale re-anchors and re-measures, so it is worth doing only
	-- when the number is actually different
	if tip.SetScale then
		local want = opt("scale", 0.95)
		local now = BT.Pill.Number(tip.GetScale and tip:GetScale(), -1)
		if math.abs(now - want) > 0.001 then
			tip:SetScale(want)
		end
	end
	return ok and s or nil
end

-- ITEM LEVEL, BESIDE THE NAME (Josh 2026-09-22). This client knows every
-- item's level and never says it. It goes on the right of the name line, the
-- way a spell's rank does, so the tooltip gains a number and not a line - and
-- only on things you wear: a reagent's level means nothing to anybody.
local NOT_WORN = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true,
	INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true, INVTYPE_BODY = true,
	INVTYPE_TABARD = true }

function M.ItemLevelText(itemLink)
	local ilevel = BT.GetModule("ilevel")
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if not (itemLink and ilevel and ilevel.LevelOf and type(info) == "function") then
		return nil
	end
	local ok, _, _, _, _, _, _, _, _, equipLoc = pcall(info, itemLink)
	if not ok or equipLoc == nil or NOT_WORN[equipLoc] then
		return nil
	end
	local lvl = ilevel.LevelOf(itemLink)
	return lvl and ("|cff8a9894ilvl|r %d"):format(lvl) or nil
end

local function itemLevel(tip)
	if not (opt("itemLevel", true) and tip.GetItem) then
		return nil
	end
	local ok, _, itemLink = pcall(tip.GetItem, tip)
	local text = ok and M.ItemLevelText(itemLink)
	local right = text and BT.UnitTip.LineOf(tip, 1, "TextRight")
	-- the client's own right-hand text on the name line, if it has any, wins
	if not right or (right.IsShown and right:IsShown() and (right:GetText() or "") ~= "") then
		return nil
	end
	right:SetText(text)
	right:SetTextColor(1, 1, 1)
	right:Show()
	return right
end
M.ItemLevel = itemLevel

function M.ComposeItem(tip)
	-- an item is not a rare, and it is not a person: whatever edge and
	-- whatever header rule the last unit left, go
	if skins[tip] then
		skins[tip].wantEdge = nil
	end
	M.HideRule(tip)
	if skins[tip] then
		skins[tip].wantTop = nil
		skins[tip].ours = nil
	end
	-- AN ITEM IS NOT A UNIT. GameTooltip is one frame the whole client shares,
	-- so the floor a unit asked for would sit under the next item tooltip too
	-- and stretch a one-line reagent to two hundred pixels.
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	local s = M.Dress(tip, true)
	if s then
		local r, g, b = itemQuality(tip)
		s.accent:SetColorTexture(r or WHITE[1], g or WHITE[2], b or WHITE[3], 0.9)
		s.accent:Show()
		M.LeftBar(s)
	end
	-- THE ITEM'S NAME IS LEFT ALONE (Josh 2026-09-20). It used to be blown up
	-- to header size, on the grounds that the first line of a tooltip is its
	-- heading. On a unit that is true and we rebuild the whole thing around
	-- it. On an item it is not ours to do: the client laid the tooltip out at
	-- the size it wrote, and making one line bigger afterwards makes it wider
	-- than the box it was measured for - so a name that fitted breaks across
	-- two lines, and a quest title under it looks like a second heading.
	--
	-- An item name already says what it is by its quality colour. It does not
	-- need to be bigger as well.
	if opt("footer", true) then
		quietFooter(tip)
		shadowTitle(tip)
	end
	-- before the Show below, which measures the tooltip with it in
	itemLevel(tip)
	-- NOT HERE (Josh 2026-09-21). Re-anchoring a line the client laid out
	-- detaches it from the layout it was measured in, which is the other half
	-- of how an item tooltip came out with its words outside its own panel.
	-- The two-pixel difference between a header's ink and the body's is worth
	-- less than a tooltip that fits.
	if tip.Show then
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
	end
	repad(tip, skins[tip], true)
end

BT.OnItemTooltip("tips", 0, M.ComposeItem)

function M:OnEnable()
	M.Dress(GameTooltip)
	-- some of these are created by the client the first time they are needed,
	-- so this is worth another go whenever the module comes back on
	M.HookOthers()
	BT.UnitTip.Restack()
end

-- AND AT LOGIN (Josh 2026-09-20). OnEnable fires on the off-to-on transition,
-- which never happens to a module that was already on. Everything here is
-- idempotent, so the login pass costs nothing and means the first tooltip of
-- the session is already dressed rather than being dressed as it appears.
function M:OnBind()
	M:OnEnable()
end

-- Put it back the way the client had it: a module you switch off has to leave
-- nothing behind, and a tooltip stuck at 0.95 scale with no health bar would
-- be exactly the kind of leftover that makes people uninstall addons.
function M:OnDisable()
	if M.Headers then
		M.Headers:Undress()
	end
	unskin(GameTooltip)
	for _, tip in pairs(M.dressed or {}) do
		unskin(tip)
		if tip.SetScale then
			tip:SetScale(1)
		end
	end
	BT.UnitTip.RestoreFonts()
	if GameTooltip and GameTooltip.SetScale then
		GameTooltip:SetScale(1)
	end
	if GameTooltipStatusBar then
		if barWas then
			pcall(GameTooltipStatusBar.SetHeight, GameTooltipStatusBar, barWas.height)
			if barWas.color and GameTooltipStatusBar.SetStatusBarColor then
				pcall(GameTooltipStatusBar.SetStatusBarColor, GameTooltipStatusBar,
					barWas.color[1], barWas.color[2], barWas.color[3])
			end
		end
		GameTooltipStatusBar:Show()
	end
	M.UnstyleTabs()
	BT.UnitTip.Restack()
end

-- THE BAR PUTS ITSELF BACK (Josh 2026-09-19). Hiding the health bar once per
-- rebuild is a race we lose: the client shows it again as part of setting the
-- unit, and on a mouseover that re-sets itself the bar is visible for the
-- frame between the two - a green block flickering at the bottom-left corner
-- of the tooltip. It is told no at the moment it asks instead.
if GameTooltipStatusBar and GameTooltipStatusBar.HookScript then
	GameTooltipStatusBar:HookScript("OnShow", function(bar)
		if BT.Enabled("tips") and not opt("healthBar", false) then
			rememberBar(bar)
			if bar.SetHeight then
				bar:SetHeight(1)
			end
			bar:Hide()
		end
	end)
end

BT.OnUnitTooltip("tips", 0, M.Compose)

-- EVERY tooltip wears the skin, not just the unit ones: the border belongs to
-- the whole frame, and an item tooltip with its border hidden and nothing in
-- its place would be a floating block of text. The accent is the exception -
-- it means "this is who you are pointing at", so it only shows on those.
--
-- AND NOT ONLY GameTooltip (Josh 2026-09-19). The one you hover is the one you
-- notice, but the client has a dozen of them, and a compare tooltip in the
-- client's own skin next to one in ours looks like two addons arguing. These
-- are the ones a player actually sees:
--
--   ShoppingTooltip1/2            what you have equipped, beside what you found
--   ItemRefTooltip                an item link clicked in chat
--   ItemRefShoppingTooltip1/2     the compare on one of those
--   EmbeddedItemTooltip           a quest reward inside another tooltip
--   FriendsTooltip                the friends list
--
-- Any that this build does not have are simply skipped. They get the skin, the
-- size and the quality spine; they are not rebuilt, because the client's own
-- layout is the point of a compare.
local OTHER_TOOLTIPS = {
	"ShoppingTooltip1", "ShoppingTooltip2",
	"ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
	"EmbeddedItemTooltip", "FriendsTooltip",
}

M.dressed = {}

-- THE "Equipped" TAB (Josh 2026-09-19). The compare tooltip carries a label
-- above it saying which of the two you already have on, and the client draws
-- it as a gold Blizzard tab - which is the one piece of the old skin left
-- sitting on top of ours.
--
-- It has no documented name, so it is found rather than named: it is a
-- FontString on the tooltip (or on a frame parented to it) that is NOT one of
-- the tooltip's own numbered lines. Those are all called <name>TextLeftN or
-- <name>TextRightN, so anything else with words in it is chrome. The art
-- behind it goes, our own surface takes its place, and the words are set in
-- the same quiet green as every other label in the toolkit.
local TAB_TEXT = { 0.55, 0.63, 0.59 }

local function isOwnLine(fs, tipName)
	if not (tipName and fs.GetName) then
		return false
	end
	local n = fs:GetName()
	return type(n) == "string" and n:find(tipName, 1, true) == 1
		and (n:find("TextLeft", 1, true) or n:find("TextRight", 1, true)) ~= nil
end

-- ONE LEVEL DOWN WAS NOT FAR ENOUGH (Josh 2026-09-21). The tab carrying
-- "Equipped" is not always a child of the compare tooltip: on this build it
-- hangs off something that hangs off it, so a scan of the tooltip's own
-- children never saw it and the gold stayed on.
local function holdersOf(tip)
	local holders = { tip }
	local function add(f, depth)
		if depth > 2 or not (f and f.GetChildren) then
			return
		end
		local ok, list = pcall(function()
			return { f:GetChildren() }
		end)
		for _, child in ipairs(ok and list or {}) do
			holders[#holders + 1] = child
			add(child, depth + 1)
		end
	end
	add(tip, 0)
	return holders
end

local function restyleTab(tip)
	local tipName = tip.GetName and tip:GetName()
	local holders = holdersOf(tip)
	M.tabsDressed = M.tabsDressed or 0
	for _, holder in ipairs(holders) do
		if holder.GetRegions then
			local label, art = nil, {}
			for _, region in ipairs({ holder:GetRegions() }) do
				local kind = region.GetObjectType and region:GetObjectType()
				if kind == "FontString" then
					local text = region.GetText and region:GetText()
					if type(text) == "string" and text ~= "" and not isOwnLine(region, tipName) then
						label = region
					end
				elseif kind == "Texture" and not region.beebs then
					art[#art + 1] = region
				end
			end
			-- a holder with a stray label on it and art behind it is the tab;
			-- the tooltip itself has dozens of lines and is never mistaken for
			-- one, because all of its FontStrings are its own numbered lines
			if label and holder ~= tip then
				-- what it was, so OnDisable can give it back
				if not holder.beebsTab then
					local face, size, flags = nil, nil, nil
					if label.GetFont then
						face, size, flags = label:GetFont()
					end
					local r, g, b = 1, 1, 1
					if label.GetTextColor then
						local ok, tr, tg, tb = pcall(label.GetTextColor, label)
						if ok and tr then
							r, g, b = tr, tg, tb
						end
					end
					holder.beebsTab = { art = art, label = label,
						font = { face, size, flags }, color = { r, g, b } }
				end
				M.tabHolders = M.tabHolders or {}
				M.tabHolders[holder] = true
				for _, t in ipairs(art) do
					t:Hide()
				end
				if not holder.beebsSkin then
					holder.beebsSkin = BT.Pill.Surface(holder, "BACKGROUND", 0)
				end
				-- painted every pass, not only when it is built: the colours
				-- are a setting now
				BT.Pill.PaintSurface(holder.beebsSkin, holder, SKIN_FILL, SKIN_RIM)
				BT.Pill.ShowSurface(holder.beebsSkin, true)
				M.tabsDressed = M.tabsDressed + 1
				if label.SetTextColor then
					label:SetTextColor(TAB_TEXT[1], TAB_TEXT[2], TAB_TEXT[3])
				end
				if label.GetFont and label.SetFont then
					local face, _, flags = label:GetFont()
					if face then
						pcall(label.SetFont, label, face, SUB, flags)
					end
				end
			end
		end
	end
end
M.RestyleTab = restyleTab

-- and back: the client's art shown, our surface hidden, the label as it was
function M.UnstyleTabs()
	local n = 0
	for holder in pairs(M.tabHolders or {}) do
		local was = holder.beebsTab
		if was then
			for _, t in ipairs(was.art or {}) do
				pcall(t.Show, t)
			end
			if holder.beebsSkin then
				BT.Pill.ShowSurface(holder.beebsSkin, false)
			end
			local label = was.label
			if label then
				if label.SetTextColor then
					pcall(label.SetTextColor, label, was.color[1], was.color[2], was.color[3])
				end
				if label.SetFont and was.font[1] and was.font[2] then
					pcall(label.SetFont, label, was.font[1], was.font[2], was.font[3])
				end
			end
			holder.beebsTab = nil
			n = n + 1
		end
	end
	M.tabHolders = nil
	return n
end

-- THE "EQUIPPED" TAB (Josh 2026-09-24). A compare tooltip carries a little
-- header of its own above it - "Equipped", "Equipped With" - in the client's
-- art. It is dressed like the client's other furniture: the art off, our
-- surface on, and all of it given back when the module goes off (M.Headers,
-- made at the top of the file).
local function dressHeader(tip)
	local headers = M.Headers
	local h = tip and tip.CompareHeader
	if headers and type(h) == "table" and h.GetRegions and h.CreateTexture then
		local ok, err = pcall(headers.DressRoot, headers, h)
		if not ok then
			BT.Err("tips.header: " .. tostring(err))
		end
	end
end

local function dressOther(tip)
	if not (tip and BT.Enabled("tips")) then
		return
	end
	dressHeader(tip)
	if skins[tip] then
		skins[tip].wantEdge = nil
	end
	M.HideRule(tip)
	local s = M.Dress(tip, true)
	if s then
		-- the spine in the item's own quality, the same edge the item tooltip
		-- wears: on a compare it answers "is this better" a glance early
		local r, g, b = itemQuality(tip)
		if r then
			s.accent:SetColorTexture(r, g, b, 0.9)
			s.accent:Show()
		else
			s.accent:Hide()
		end
		M.LeftBar(s)
	end
	if opt("footer", true) then
		quietFooter(tip)
		shadowTitle(tip)
	end
	-- NOT HERE (Josh 2026-09-21). Re-anchoring a line the client laid out
	-- detaches it from the layout it was measured in, which is the other half
	-- of how an item tooltip came out with its words outside its own panel.
	-- The two-pixel difference between a header's ink and the body's is worth
	-- less than a tooltip that fits.
	pcall(restyleTab, tip)
end
M.DressOther = dressOther

-- ASK THE UI WHAT IS A TOOLTIP, DO NOT LIST THEM (Josh 2026-09-21). The names
-- above are the ones anybody could think of, and the guild roster's was not
-- among them - hovering a member in Guild & Communities gave you the client's
-- own tooltip sitting beside ours, which is the same "two addons arguing" the
-- compare tooltips used to be. Naming them one at a time is a list that is
-- wrong again the next time a panel is opened for the first time.
--
-- Every tooltip in the game answers "GameTooltip" when asked what it is, and
-- EnumerateFrames walks every frame there is, so the question can be asked
-- rather than guessed. The named list stays as the fast path; the sweep is
-- what catches the ones nobody listed.
-- AND IT CANNOT THROW INTO THE CLIENT (Josh 2026-09-21). This is hooked onto
-- OnShow, so an error here comes out of whatever was showing the tooltip - a
-- Blizzard settings control, in the first case that hit. We are now dressing
-- frames nobody named and nobody has seen, so one of them being unlike the
-- rest has to be survivable: it wears the client's own skin for the session
-- and the reason is on /bt debug, rather than taking the panel down with it.
local function hook(tip, key)
	if not (tip and tip.HookScript) or M.dressed[key] then
		return false
	end
	M.dressed[key] = tip
	tip:HookScript("OnShow", function(self)
		local ok, err = pcall(dressOther, self)
		if not ok then
			BT.Err(("tips.dress %s: %s"):format(tostring(key), tostring(err)))
		end
	end)
	return true
end

-- one frame of the walk: 1 if it was a tooltip nobody had hooked yet
local function sweepOne(f)
	if f ~= GameTooltip and f.GetObjectType then
		local okType, kind = pcall(f.GetObjectType, f)
		if okType and kind == "GameTooltip" then
			local name = (f.GetName and f:GetName()) or f
			if hook(f, name) then
				return 1
			end
		end
	end
	return 0
end

-- a walk of every frame in the game, so it is bounded: a client that never
-- returns nil must not take the session with it
local SWEEP_MAX = 20000

function M.SweepTooltips()
	if type(_G.EnumerateFrames) ~= "function" then
		return 0
	end
	local found, f, guard = 0, nil, 0
	repeat
		local ok, nxt = pcall(_G.EnumerateFrames, f)
		if not ok then
			break
		end
		f = nxt
		guard = guard + 1
		if f then
			found = found + sweepOne(f)
		end
	until not f or guard > SWEEP_MAX
	return found
end

-- A FEW HUNDRED FRAMES AT A TIME (Josh 2026-09-24, /bt cpu: the half-minute
-- sweep was one 16 ms frame, landing in the middle of a hover). The same
-- walk, a slice a frame until it is done; nothing waits on its answer. The
-- client never throws a frame away, so where the walk had got to is still
-- there the frame after.
M.SWEEP_SLICE = 400
local slicer

function M.SweepSoon()
	if type(_G.EnumerateFrames) ~= "function" then
		return false
	end
	if not CreateFrame then
		M.SweepTooltips()
		return true
	end
	slicer = slicer or CreateFrame("Frame")
	if slicer.walking then
		return false
	end
	slicer.walking = true
	local f, guard = nil, 0
	local function done(self)
		self:SetScript("OnUpdate", nil)
		self.walking = false
	end
	slicer:SetScript("OnUpdate", function(self)
		for _ = 1, M.SWEEP_SLICE do
			local ok, nxt = pcall(_G.EnumerateFrames, f)
			guard = guard + 1
			if not (ok and nxt) or guard > SWEEP_MAX then
				done(self)
				return
			end
			f = nxt
			sweepOne(f)
		end
	end)
	return true
end
M.Slicer = function() return slicer end

-- Some of these the client builds the first time they are needed, so this is
-- worth another go now and then rather than only at load.
--
-- NOW AND THEN IS NOT EVERY TOOLTIP (Josh 2026-09-22). The named ones are a
-- handful of lookups; the sweep walks every frame in the UI, and it was run
-- from GameTooltip's OnShow - dozens of times a second across a bag. With
-- `cheap` it sweeps at most once every half minute, spread over frames.
local lastSweep = 0
function M.HookOthers(cheap)
	for _, name in ipairs(OTHER_TOOLTIPS) do
		hook(_G[name], name)
	end
	local now = U.Now()
	if not cheap then
		lastSweep = now
		M.SweepTooltips()
	elseif now - lastSweep >= 30 then
		lastSweep = now
		M.SweepSoon()
	end
	return M.dressed
end

M.HookOthers()

-- AND AGAIN WHEN THERE IS MORE UI THAN THERE WAS (Josh 2026-09-21). The guild
-- panel, the collections journal and the encounter journal are all loaded the
-- first time you open them, and their tooltips do not exist until then.
if CreateFrame then
	M.watcher = CreateFrame("Frame")
	for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD" }) do
		pcall(M.watcher.RegisterEvent, M.watcher, event)
	end
	-- ONE SWEEP FOR A BURST (Josh 2026-09-23, audit): addons load one after
	-- another at login, dozens of ADDON_LOADEDs, and each one walked every
	-- frame in the game. Half a second after the last, once.
	local queued = false
	M.watcher:SetScript("OnEvent", function()
		if not BT.Enabled("tips") or queued then
			return
		end
		if C_Timer and C_Timer.After then
			queued = true
			C_Timer.After(0.5, function()
				queued = false
				if BT.Enabled("tips") then
					M.HookOthers()
				end
			end)
		else
			M.HookOthers()
		end
	end)
end

-- AT THE POINTER, IF YOU LIKE (Josh 2026-09-24): a tooltip the client would
-- put in its corner follows the pointer instead. (The dock's own hook moves
-- the corner one clear of the dock first; the new owner undoes that - see
-- UI/Bar.lua.)
function M.AnchorDefault(tip, parent)
	if not (BT.Enabled("tips") and opt("anchor", "dock") == "cursor") then
		return false
	end
	if tip and tip.SetOwner then
		pcall(tip.SetOwner, tip, parent or UIParent, "ANCHOR_CURSOR")
		return true
	end
	return false
end
if type(hooksecurefunc) == "function" and type(_G.GameTooltip_SetDefaultAnchor) == "function" then
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip, parent)
		pcall(M.AnchorDefault, tip, parent)
	end)
end

-- NOT IN A FIGHT, IF YOU LIKE (Josh 2026-09-24): a unit's tooltip is put away
-- as it shows while you are in combat; items and spells are not units
function M.CombatHidden(tip, unit)
	if not (opt("combatHide", false) and InCombatLockdown and InCombatLockdown()) then
		return false
	end
	if not (unit and UnitExists and UnitExists(unit)) then
		return false
	end
	if tip and tip.Hide then
		tip:Hide()
	end
	return true
end

-- CLEARED, NOT SHOWN (Josh 2026-09-21). Moving the cursor from a mob to a
-- quest item lying in the snow does not HIDE the tooltip - it is written again
-- in place - so OnShow never fires and the leftovers survive. The client
-- clears the tooltip before it writes anything new, whatever the new thing is,
-- and that is the moment the last one's styling stops being true.
--
-- Everything is taken off here; Compose and ComposeItem put back whatever the
-- new thing needs a moment later.
if GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipCleared", function(tip)
		if BT.Enabled("tips") then
			-- an error here comes out of whatever was writing the tooltip
			local ok, err = pcall(M.DressPlain, tip)
			if not ok then
				BT.Err("tips.cleared: " .. tostring(err))
			end
		end
	end)
end

if GameTooltip and GameTooltip.HookScript then
	local function shown(tip)
		-- THE BAND BELONGS TO A UNIT, AND ONLY WHILE IT IS ON SCREEN
		-- (Josh 2026-09-20). It was taken off when the tooltip HID, which
		-- is not the same thing: go from a mob straight to an item in your
		-- bag and the tooltip never hides, it is just written again - so
		-- the mob's nameplate stayed behind the item's name, sized for the
		-- mob's. That is the band "not expanding to fit the header": it
		-- was never that header's band.
		--
		-- Anything that is not a unit loses it here, and Compose puts it
		-- back for whoever is.
		local unit = nil
		if TooltipUtil and TooltipUtil.GetDisplayedUnit then
			local ok, _, u = pcall(TooltipUtil.GetDisplayedUnit, tip)
			unit = ok and u or nil
		elseif tip.GetUnit then
			local ok, _, u = pcall(tip.GetUnit, tip)
			unit = ok and u or nil
		end
		if M.CombatHidden(tip, unit) then
			return
		end
		-- (not while one of ours is showing it: Compose and ComposeItem
		-- have just dressed it, and a plain pass took an item's spine off)
		if not M.composing and not (unit and UnitExists and UnitExists(unit)) then
			M.DressPlain(tip)
		end
		M.Dress(tip)
	end
	-- the late-built tooltips, looked for a frame later rather than in the
	-- middle of this one being shown
	local function late()
		M.HookOthers(true)
	end
	GameTooltip:HookScript("OnShow", function(tip)
		if BT.Enabled("tips") then
			local ok, err = pcall(shown, tip)
			if not ok then
				BT.Err("tips.shown: " .. tostring(err))
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(0, late)
			else
				late()
			end
		end
	end)
end
-- THE EDGE BELONGS TO THE UNIT, NOT THE TOOLTIP (Josh 2026-09-19). GameTooltip
-- is one frame the whole client shares: hover an elite, then a quest pin on
-- the map, and the pin's tooltip came up wearing the elite's gold border,
-- because the edge was remembered on the skin and nothing ever took it off.
-- It goes when the tooltip does; a unit puts it back on the way in.
BT.OnUnitTooltipHide(function()
	local s = skins[GameTooltip]
	if s then
		s.accent:Hide()
		s.wantEdge = nil
		s.wantTop = nil
		s.ours = nil
		applyEdge(GameTooltip, s)
		M.HideRule(GameTooltip)
	end
end)

-- ---------------------------------------------------------------------------
-- The tab: the switches, and a picture of what they do
-- ---------------------------------------------------------------------------
local function preview(panel, y)
	local box = CreateFrame("Frame", nil, panel)
	box:SetPoint("TOPLEFT", 0, y)
	box:SetSize(300, 72)
	BT.Widgets.Panel(box)
	box.name = BT.Widgets.Label(box, "Beeb Magus", nil, 0.41, 0.80, 0.94)
	box.name:SetPoint("TOPLEFT", 10, -9)
	box.level = BT.Widgets.Label(box, "8", "small", 0.35, 0.82, 0.45)
	box.level:SetPoint("TOPRIGHT", -10, -10)
	box.detail = BT.Widgets.Label(box, "Gnome Mage · <Nightwatch>", "small", DIM[1], DIM[2], DIM[3])
	box.detail:SetPoint("TOPLEFT", 10, -30)
	-- the tab shows the thing rather than describing it, spine and all
	box.note = BT.Widgets.Label(box, '"held the door while I ran back"', nil, 0.90, 0.88, 0.80)
	box.note:SetPoint("TOPLEFT", 10, -46)
	local spine = box:CreateTexture(nil, "ARTWORK")
	spine:SetPoint("TOPLEFT", 1, -1)
	spine:SetPoint("BOTTOMLEFT", 1, 1)
	spine:SetWidth(2)
	spine:SetColorTexture(0.41, 0.80, 0.94, 0.9)
	return box
end

function M:BuildTab(panel)
	-- the title, the blurb and the line under them belong to the panel now:
	-- the switch they sit beside is what governs everything here
	local page = BT.Widgets.Stack(panel)
	-- the page shows the thing rather than describing it, spine and all
	local top = CreateFrame("Frame", nil, panel)
	top:SetHeight(94)
	self.preview = preview(top, 0)
	local caption = BT.Widgets.Label(top, "two lines, not seven", "small", 0.50, 0.55, 0.53)
	caption:SetPoint("TOPLEFT", 2, -80)
	page:Add(top)

	self.rows = {}
	local show = page:Section("Show")
	local function row(title, blurb, name, default)
		local r = BT.Widgets.SwitchRow(show, title, blurb,
			function() return opt(name, default) and true or false end,
			function(on)
				setOpt(name, on)
				M:RefreshPreview()
				BT.UnitTip.Restack()
			end)
		r.optName, r.default = name, default
		self.rows[#self.rows + 1] = r
	end
	row("Guild", "in angle brackets", "guild", true)
	row("Other faction", "only when it is not yours", "faction", true)
	row("Health bar", "the client's bar under a unit's tooltip", "healthBar", false)
	row("Quiet item footers", "an item's sell price and the lines under it, smaller and grey", "footer", true)
	row("Item level", "beside the name, on anything you can wear", "itemLevel", true)
	row("Who it targets", "a line saying who a unit is pointing at", "targetLine", false)

	-- WHERE AND WHEN (Josh 2026-09-24)
	local place = page:Section("Place")
	local where = BT.Widgets.Row(place, "Position", "a tooltip with no place of its own: in the corner, or at the pointer")
	self.anchorSeg = where:SetControl(BT.Widgets.Segmented(where, {
		{ "dock", "Corner" }, { "cursor", "Pointer" },
	}, function(key)
		setOpt("anchor", key)
	end, 70))
	local quiet = BT.Widgets.SwitchRow(place, "Hide in combat", "a unit's tooltip, while you fight · items and spells still show",
		function() return opt("combatHide", false) and true or false end,
		function(on) setOpt("combatHide", on) end)
	quiet.optName, quiet.default = "combatHide", false
	self.rows[#self.rows + 1] = quiet

	local function nudge(by)
		local now = math.floor((opt("scale", 0.95) + by) * 100 + 0.5) / 100
		setOpt("scale", math.max(0.7, math.min(1.2, now)))
		M:RefreshPreview()
		BT.UnitTip.Restack()
	end
	local size = BT.Widgets.Row(page:Section("Size"), "Tooltip size")
	local step = size:SetControl(BT.Widgets.Stepper(size, function(dir) nudge(dir * 0.05) end))
	self.scaleText = step.value
	page:Layout()
end

function M:RefreshPreview()
	if self.anchorSeg then
		self.anchorSeg:Select(opt("anchor", "dock"))
	end
	for _, r in ipairs(self.rows or {}) do
		r.switch:SetOn(opt(r.optName, r.default) and true or false)
	end
	if self.scaleText then
		self.scaleText:SetText(("%d%%"):format(math.floor(opt("scale", 0.95) * 100 + 0.5)))
	end
	if self.preview then
		local bits = { "Gnome Mage" }
		if opt("guild", true) then
			bits[#bits + 1] = "<Nightwatch>"
		end
		if opt("faction", true) then
			bits[#bits + 1] = "Alliance"
		end
		self.preview.detail:SetText(table.concat(bits, " · "))
	end
end

function M:ShowTab()
	self:RefreshPreview()
end

function M:Refresh()
	self:RefreshPreview()
end

BT.Command("tips", function(rest)
	-- MEASURING, NOT GUESSING (Josh 2026-09-19). The band of empty space under
	-- the last line has survived three fixes, each aimed at a mechanism I had
	-- reasoned my way to. This prints what the tooltip actually is.
	if rest == "pad on" or rest == "pad off" then
		M.measuring = (rest == "pad on")
		U.Print("tooltip measuring " .. (M.measuring and "on - hover a unit, then /bt tips pad" or "off"))
		return
	end
	if rest == "skin" then
		-- the same lesson as the band under the last line: look at what the
		-- frame IS rather than reason about what it should be (Josh 2026-09-19)
		local tip = _G.ShoppingTooltip1
		if not tip then
			U.Print("no compare tooltip on this client")
			return
		end
		local N = BT.Pill.Number
		local function dump(frame, label)
			U.Print(("|cff74c0fc%s|r %s"):format(label, tostring(frame.GetName and frame:GetName())))
			for _, region in ipairs({ frame:GetRegions() }) do
				local kind = region.GetObjectType and region:GetObjectType()
				local what = tostring(region.GetName and region:GetName())
				if kind == "FontString" then
					what = what .. " '" .. tostring(region.GetText and region:GetText()) .. "'"
				elseif kind == "Texture" then
					what = what .. " tex=" .. tostring(region.GetTexture and region:GetTexture())
						.. " atlas=" .. tostring(region.GetAtlas and region:GetAtlas())
				end
				U.Print(("   %s %s %s h%s"):format(tostring(kind),
					region:IsShown() and "shown" or "hidden", what,
					N(region.GetHeight and region:GetHeight(), -1)))
			end
		end
		dump(tip, "compare")
		for i, child in ipairs({ tip:GetChildren() }) do
			dump(child, "child " .. i)
		end
		return
	end
	if rest == "pad" then
		if not M.measuring then
			U.Print("nothing measured · /bt tips pad on, then hover a unit")
			return
		end
		for _, when in ipairs({ "after the rebuild", "one frame later" }) do
			local snap = M.snaps[when]
			if snap then
				U.Print(("|cff74c0fc%s|r · height %s · padding %s"):format(when, snap.height, snap.padding))
				U.Print("   band " .. tostring(snap.band))
				U.Print("   bar " .. tostring(snap.bar))
				for _, line in ipairs(snap.lines) do
					U.Print("   " .. line)
				end
			end
		end
		return
	end
	local n = tonumber(rest)
	if n then
		setOpt("scale", math.max(0.7, math.min(1.2, n)))
		BT.UnitTip.Restack()
	end
	U.Print(("tooltips %d%% · guild %s · faction %s · health bar %s")
		:format(math.floor(opt("scale", 0.95) * 100 + 0.5),
			opt("guild", true) and "on" or "off",
			opt("faction", true) and "on" or "off",
			opt("healthBar", false) and "on" or "off"))
	U.Print("last unit classification · " .. tostring(M.lastClassification))
	local T = BT.UnitTip
	U.Print(("hooks · unit %s (%d fired) · item %s (%d fired)")
		:format(tostring(T.path), T.fills or 0, tostring(T.itemPath), T.itemFills or 0))
end, "tips [0.7-1.2] | tips pad on|off|pad | tips skin", "tips")
