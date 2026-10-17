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
--   Gnome Mage <Nightwatch>            everything else, once (the guild green)
--
-- WHAT IT KEEPS. Everything you would actually act on: who, how tough, what
-- they are, who they run with. What it drops: the word "(Player)", the faction
-- you can already see on the nameplate unless it is the OTHER one, the
-- right-click instruction, and the health bar. None of them is a switch any
-- more (the settings canvas, Josh 2026-10-04).
--
-- It rebuilds rather than hides: ClearLines and start again is the only way to
-- make the tooltip actually SHRINK. Blanking lines leaves their height behind,
-- which is a smaller tooltip with holes in it rather than a compact one.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Tooltips/Tooltips.lua")

local U = BT.Util

local M = BT.Module({
	key = "tooltips",
	group = "windows",
	title = "Tooltips",
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
-- otherwise would; if it refuses, nothing is worse than it was.
-- THREE BACK (Josh 2026-10-17: "Add a bit more padding above the title"):
-- with the tags tight under the name, the name sat hard against the rim.
local PAD_TOP = -3
-- THE HEADER'S RULE WENT (Josh 2026-10-17, the tooltip canvas "C, everything
-- as tags"). The name sat on a wash of its class colour once, then over a
-- hairline; the tags under it are what set it off from the body now.

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

-- WHAT THE HEALTH BAR WAS (Josh 2026-09-22). Compose sets its height to one
-- pixel and hides it, and switching the module off only showed it again - a
-- one-pixel sliver until the next /reload. Its own height and colour are
-- written down the first time it is touched.
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

-- declared here and written below: skin() sits above it and calls it
local repad

-- the same surface as every panel: a tooltip that is opaque while the window
-- behind it is not looks like it belongs to a different addon
-- NEARLY SOLID (Josh 2026-10-17: "Tooltips need to be less transparent so
-- they are easier to read"): the panels' colour, at the tooltips' own alpha
-- (UI/Widgets.lua, W.TIP), so the world does not show through the words
local SKIN_FILL = BT.Widgets.TIP
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
		if s.crest then
			s.crest:Hide()
		end
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
--   tags        what they are and what state they are in, small capitals on
--               boxes; grey, unless the state is one you act on
--   rows        one thing each - an objective, your kills, your note - led by
--               a picture in its owner's colour (Core/Tooltip.lua, T.Row)
--   footer      anything the client said that is too long for a tag
--
-- (Josh 2026-10-17, the tooltip canvas "C, everything as tags": the grey line
-- under the name and the hairline above it went; the tags took their place.)
--
-- The lines are Blizzard's own FontStrings and are shared with every other
-- tooltip, so anything set here is put back the moment this one goes away.
local HEADER, LEVEL, SUB, FOOT = 14, 13, 10, 10

local lineOf = function(tip, i, side) return BT.UnitTip.LineOf(tip, i, side) end
local sizeLine = function(tip, i, size, side) return BT.UnitTip.SizeLine(tip, i, size, side) end
restoreFonts = function(tip) return BT.UnitTip.RestoreFonts(tip) end

-- FIXED, NOT ASKED (the settings canvas, Josh 2026-10-04: "This addon is
-- supposed to be an opinionated solution, not fully customizable"). What
-- each of the page's switches said by default is what the tooltips do: the
-- guild and another faction shown, the sell price small, an item's level,
-- in the corner; no health bar, no targeting line, not hidden in a fight.
-- (2026-10-05, cleanup) Nothing reads the old switches now, so the code for
-- their other answers is gone: the health bar, the targeting line, the
-- tooltip at the pointer and the tooltip put away in a fight.

-- the tests look at the edge a tooltip is wearing
function M.Skins()
	return skins
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
	-- THE CHAT LINK'S CLOSE BUTTON. Its tooltip has an X in the top right
	-- corner, and the client keeps sixteen pixels for it when the name would
	-- run under it (ItemRefTooltipMixin:ItemRefSetHyperlink). One written
	-- again keeps them always, or the next pass here would take them back.
	if tip == _G.ItemRefTooltip then
		right = math.max(right, M.CLOSE_ROOM)
	end
	-- how tight the bottom is depends on whether we wrote the lines
	local bottom = (ours and PAD_BOTTOM or PAD_Y) + ((s and s.extraBottom) or 0)
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
M.CLOSE_ROOM = 16

-- How hard this thing is: its level, in the colour of how hard it is for you.
-- ELITE, RARE AND BOSS ARE A TAG BESIDE IT (Josh 2026-10-17, the tooltip
-- canvas), not a "+", an "r" or a "B" after it.
M.RANK_TAG = {
	elite = { "Elite", "elite" }, rareelite = { "Rare elite", "elite" },
	rare = { "Rare", "rare" }, worldboss = { "Boss", "elite" },
}
-- a dead unit's name and level, greyed
M.DEAD_INK = { 0.56, 0.61, 0.58 }

-- the classification, or "normal" when the client will not say
local function classOf(unit)
	-- guarded like every other question we ask about a unit: this client
	-- refuses some of them, and an unguarded refusal here took the whole
	-- rebuild down inside a pcall, leaving the client's own tooltip (Josh
	-- 2026-09-19)
	local okc, class = pcall(function()
		return UnitClassification and UnitClassification(unit) or "normal"
	end)
	-- a secret answer is a string that cannot be compared: read as ordinary
	if not okc or type(class) ~= "string" or (issecretvalue and issecretvalue(class)) then
		return "normal"
	end
	return class
end

local function levelText(unit, isPlayer, dead)
	local level = UnitLevel and UnitLevel(unit) or 0
	local text
	if level and level > 0 then
		text = tostring(level)
	else
		text = "??" -- a boss, or something too far above you to read
	end
	local r, g, b = 0.85, 0.85, 0.85
	-- THE COLOUR MEANS "HOW HARD" (Josh 2026-09-22), which is a question
	-- about a mob. On a player a grey eleven read as "unimportant", so a
	-- player's level is plain text.
	-- by the shared rule (Core/Util.lua, U.LevelColour): the client's own
	-- answer is the modern game's on this build
	if dead then
		r, g, b = M.DEAD_INK[1], M.DEAD_INK[2], M.DEAD_INK[3]
	elseif not isPlayer then
		local c = U.LevelColour(level)
		if c then
			r, g, b = c[1], c[2], c[3]
		end
	end
	return text, r, g, b
end

local function reactionColor(unit)
	local n = UnitReaction and UnitReaction(unit, "player")
	local c = n and REACTION[n]
	return c or { 0.85, 0.85, 0.85 }
end

-- THE GUILD IN GREEN (Josh 2026-09-29: "Instead of the middle dot and guild
-- name, can we remove the dot and make <guild name> green?"): the guild
-- chat's green, in angle brackets, on a line of its own under the tags
-- (Josh 2026-10-17: "Guild name should be below that in the old green
-- style"). Chat links write the name in it too (Modules/Chat/Links.lua).
M.GUILD = "|cff40ff40%s|r"

-- a string the client will let us read, or nil
local function plainText(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if ok and type(v) == "string" and v ~= "" and not (issecretvalue and issecretvalue(v)) then
		return v
	end
	return nil
end

-- a yes or no the client will let us read; a secret or a refusal is no
local function plainYes(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok, v = pcall(fn, ...)
	if not ok or (issecretvalue and issecretvalue(v)) then
		return false
	end
	return v and true or false
end
M.PlainYes = plainYes

-- one tag on the list, once
local function addTag(tags, words, kind)
	if type(words) ~= "string" or words == "" then
		return
	end
	for _, t in ipairs(tags) do
		if t[1] == words then
			return
		end
	end
	tags[#tags + 1] = { words, kind or "plain" }
end

-- WHAT THEY ARE, AS TAGS (Josh 2026-10-17, the tooltip canvas "C, everything
-- as tags"). A player: race and class. Anything else: its type and its
-- family. Each tag is { words, kind } for Core/Tooltip.lua's T.TAG.
-- TWO OR THREE, NOT FIVE (Josh, the same day: "I think we are tagging too
-- much stuff now. I think we should only have 2-3 tags per tooltip on
-- average"). What a unit is, and the states you act on, are tags. Who it is
-- with is a line under them in the guild's green - a player's <guild>, an
-- NPC's <job> (`about.guild`, `about.title`) - and the rest (a reputation
-- faction, a faction not yours, Tameable) is small print (M.Compose).
--
-- `spoken` is everything these speak for, whether a tag says it or it was
-- left out on purpose (your own faction): the client's own lines that say
-- the same are not said again (clientLines). `about` keeps the race and
-- class for the client's own longer race line (M.Compose).
function M.Identity(unit, isPlayer)
	local tags, spoken, about = {}, {}, {}
	local function say(words)
		if type(words) == "string" then
			spoken[words] = true
		end
	end
	if isPlayer then
		local race, class = plainText(UnitRace, unit), plainText(UnitClass, unit)
		about.race, about.class = race, class
		say(race)
		say(class)
		if race and class then
			say(race .. " " .. class)
		end
		addTag(tags, race)
		addTag(tags, class)
		local guild = plainText(GetGuildInfo, unit)
		if guild then
			say(guild)
			say("<" .. guild .. ">")
			about.guild = guild
		end
		-- the faction only when it is the one you are not: yours is not news
		local theirs, mine = plainText(UnitFactionGroup, unit), plainText(UnitFactionGroup, "player")
		for _, f in ipairs({ theirs or false, mine or false }) do
			if f then
				say(f)
				say(_G["FACTION_" .. f:upper()] or f)
			end
		end
		if theirs and mine and theirs ~= mine and theirs ~= "Neutral" then
			about.faction = _G["FACTION_" .. theirs:upper()] or theirs
		end
	else
		-- read off the tooltip's own second line: UnitPVPName returns the name
		-- with the title folded in, never the title on its own (Core/Util.lua,
		-- U.NpcTitle)
		local title = nil
		if _G.GameTooltipTextLeft2 then
			title = U.NpcTitle(_G.GameTooltipTextLeft2:GetText())
		end
		if title and title ~= "" then
			say(title)
			say("<" .. title .. ">")
			about.title = title
		end
		-- the type and the family both: whichever the client wrote on a line
		-- of its own is said by these
		local kind, family = plainText(UnitCreatureType, unit), plainText(UnitCreatureFamily, unit)
		say(kind)
		say(family)
		addTag(tags, kind)
		addTag(tags, family)
	end
	return tags, spoken, about
end

-- WHAT STATE IT IS IN, FROM THE CLIENT'S OWN WORDS. Skinning (or herbs, ore
-- and salvage) and PvP reach an addon only as lines the client wrote; dead
-- is asked (UnitIsDead), so its "Corpse" line is already said.
local SKIN_WORDS = { "UNIT_SKINNABLE_LEATHER", "UNIT_SKINNABLE_HERB", "UNIT_SKINNABLE_ROCK", "UNIT_SKINNABLE_BOLTS" }
function M.StateOf(line)
	for _, key in ipairs(SKIN_WORDS) do
		if _G[key] and _G[key] == line then
			return "skin", line
		end
	end
	if line == "Skinnable" then
		return "skin", line
	end
	if line == "PvP" or (_G.PVP and line == _G.PVP) then
		return "pvp", line
	end
	if line == "Corpse" or (_G.CORPSE and line == _G.CORPSE) then
		return "dead", line
	end
	return nil
end

-- the longest a line of the client's may be and still share a line with
-- others (a faction, "Tameable"); longer, or with a number in it, it has a
-- line of its own
M.TAG_MOST = 24
-- A class's icon as markup inside the name's text, the client's own
-- (GetClassAtlas, Blizzard_SharedXML/SharedConstants.lua), or nil where this
-- client has no such picture. The space after it is the gap before the name.
M.CLASS_ICON = 14
function M.ClassIcon(classFile)
	if type(classFile) ~= "string" or classFile == "" then
		return nil
	end
	local atlas = ("classicon-%s"):format(classFile:lower())
	if C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
		if not (ok and info) then
			return nil
		end
	end
	return ("|A:%s:%d:%d|a "):format(atlas, M.CLASS_ICON, M.CLASS_ICON)
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
local QUEST_DONE = { 0.36, 0.70, 0.48 }

-- EVERYTHING ELSE THE CLIENT SAID (Josh 2026-09-19). Rebuilding a tooltip
-- means every line the client wrote is gone unless we put it back, and the
-- client writes more than the name and the level: tapped, tameable, skinnable,
-- PvP, "Looking for group", a summon that will not work, whatever the next
-- patch adds. Listing them all would be a list that goes stale.
--
-- So the rule is the other way round: anything the client wrote that we have
-- not SAID OURSELVES comes across, as a tag or as small print (M.Compose).
-- M.Identity reports what it speaks for - including what it deliberately left
-- out, like your own faction - and the name, the level line and the quest
-- block are accounted for here.
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
		s.extraBottom = nil
		s.ours = nil
		if s.accent then
			s.accent:Hide()
		end
		if s.crest then
			s.crest:Hide()
		end
	end
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
				out[#out + 1] = { text = words, have = have, need = need, done = done }
			end
		end
	end
	return out, used
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
local function squeezeBlankTail(tip)
	if not tip.NumLines then
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

-- THE QUESTS IT COUNTS FOR, AS ROWS (Josh 2026-10-17, the tooltip canvas):
-- each objective led by the quest's mark, its count on the right, green once
-- it is done. The quest's own name only when there is more than one quest to
-- tell apart, with its objectives under it.
function M.QuestRows(tip, quests)
	local T = BT.UnitTip
	local titles = 0
	for _, q in ipairs(quests or {}) do
		if q.title then
			titles = titles + 1
		end
	end
	local n = 0
	for _, q in ipairs(quests or {}) do
		if q.title then
			if titles > 1 then
				T.Row(tip, "quest", QUEST_TITLE, q.text, QUEST_TITLE)
				n = n + 1
			end
		else
			local count = (q.have and q.need) and ("%d/%d"):format(q.have, q.need) or nil
			T.Row(tip, titles > 1 and "blank" or "quest", QUEST_TITLE, q.text, T.INK, count,
				q.done and QUEST_DONE or QUEST_TITLE)
			n = n + 1
		end
	end
	return n
end

-- YOUR KILLS OF IT (Josh 2026-10-17, the tooltip canvas): how many of this
-- enemy the Expedition has from this character, and how far it is to its next
-- mastery, in that mastery's metal. Only for something you can attack, and
-- only while the Expedition is on.
M.EXPEDITION = { 0.44, 0.64, 0.80 }
M.NO_KILLS = { 0.62, 0.68, 0.65 }
function M.KillsRow(tip, unit)
	local J = BT.Expedition
	if not (J and J.GuidNpc and J.Store and BT.Enabled("expedition")) then
		return nil
	end
	if plainYes(UnitIsPlayer, unit) or not plainYes(UnitCanAttack, "player", unit) then
		return nil
	end
	local guid = nil
	if type(UnitGUID) == "function" then
		local ok, g = pcall(UnitGUID, unit)
		guid = (ok and not (issecretvalue and issecretvalue(g))) and g or nil
	end
	local npc = J.GuidNpc(guid)
	local s, c = J.Store(), npc and J.Mine()
	if not (npc and s and c and c.kills) then
		return nil
	end
	-- an enemy of a name the journal has is that page's (J.PageOf)
	local to = s.same and s.same[npc]
	if to and s.enemies[to] then
		npc = to
	end
	local have = c.kills[npc] or 0
	local _, reached, nextOne = J.Mastery(have, s.enemies[npc])
	local words
	if have == 0 then
		words = "No kills yet"
	elseif have == 1 then
		words = "1 kill"
	else
		words = ("%s kills"):format(U.Commas(have))
	end
	local right, rc = nil, nil
	if nextOne then
		right, rc = ("%s %d/%d"):format(nextOne.name, have, nextOne.n), nextOne.color
	elseif reached then
		right, rc = reached.name, reached.color
	end
	local feature = BT.Feature and BT.Feature("expedition")
	return BT.UnitTip.Row(tip, "kills", feature and feature.color or M.EXPEDITION, words,
		have == 0 and M.NO_KILLS or BT.UnitTip.INK, right, rc)
end

-- THE HEALTH, AS A LINE (Josh 2026-10-17, the tooltip canvas): two pixels
-- along the bottom edge of something you can fight, filled as far as its
-- health. The client keeps the number from addons, but a bar may be handed it
-- as it is, the unit frames' way. So the bar is ours, asked ten times a
-- second, and the client's own bar under the tooltip stays put away (it
-- recolours itself on every change, and is the client's code to run).
M.HEALTH_H = 2
M.HEALTH = { 0.31, 0.78, 0.42 }
local health

local function paintHealth(bar)
	local unit = bar.unit
	if not unit then
		return
	end
	if type(UnitHealthMax) == "function" then
		local ok, most = pcall(UnitHealthMax, unit)
		if ok then
			pcall(bar.SetMinMaxValues, bar, 0, most)
		end
	end
	if type(UnitHealth) == "function" then
		local ok, now = pcall(UnitHealth, unit)
		if ok then
			pcall(bar.SetValue, bar, now)
		end
	end
end

-- along the bottom of `tip` for `unit`, or put away for nil
function M.HealthLine(tip, unit)
	if not unit then
		if health then
			health:Hide()
			health.unit = nil
		end
		return nil
	end
	if not health then
		health = CreateFrame("StatusBar", nil, tip)
		health.beebs = true
		health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		health:SetStatusBarColor(M.HEALTH[1], M.HEALTH[2], M.HEALTH[3], 1)
		health.wait = 0
		health:SetScript("OnUpdate", function(self, elapsed)
			self.wait = self.wait - (elapsed or 0)
			if self.wait <= 0 then
				self.wait = 0.1
				paintHealth(self)
			end
		end)
	end
	health:SetParent(tip)
	health:ClearAllPoints()
	health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1 + SPINE, 1)
	health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1, 1)
	health:SetHeight(M.HEALTH_H)
	pcall(health.SetFrameLevel, health, BT.Pill.Number(tip.GetFrameLevel and tip:GetFrameLevel(), 1) + 4)
	health.unit = unit
	paintHealth(health)
	health:Show()
	return health
end

-- the tests want it without a tooltip in front of them
function M.HealthFrame()
	return health
end

-- a unit's line goes with its tooltip, whatever comes next
BT.OnUnitTooltipHide(function()
	M.HealthLine(nil, nil)
end)

-- the gap between the level and the Elite tag beside it, and how much
-- narrower than the tooltip a row of tags is kept
local RANK_GAP, TAG_INSET = 5, 18
-- how much lower than the name's own line the tags hang
M.TAG_DROP = 2

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
	local dead = plainYes(UnitIsDead, unit) or plainYes(UnitIsGhost, unit)

	-- the spine keeps who they are; the name of a dead one goes grey
	local sr, sg, sb
	local classFile = nil
	if isPlayer then
		local _, class = UnitClass(unit)
		classFile = not (issecretvalue and issecretvalue(class)) and class or nil
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		sr, sg, sb = (c and c.r) or 0.9, (c and c.g) or 0.9, (c and c.b) or 0.9
	else
		local c = reactionColor(unit)
		sr, sg, sb = c[1], c[2], c[3]
	end
	local nr, ng, nb = sr, sg, sb
	if dead then
		nr, ng, nb = M.DEAD_INK[1], M.DEAD_INK[2], M.DEAD_INK[3]
	end

	-- READ BEFORE CLEARING (Josh 2026-09-19). An NPC's title only exists as a
	-- line the client already wrote - <Innkeeper> is on the tooltip, not in an
	-- API - so it has to be picked up while it is still there.
	local tags, spoken, about = M.Identity(unit, isPlayer)
	local quests, usedByQuests = questBlock(tip)
	for line in pairs(usedByQuests or {}) do
		spoken[line] = true
	end
	-- the name may be secret (the width below is not measured for one), and a
	-- secret is never compared: the client's lines are matched against it only
	-- when it is plain
	local plainName = not (issecretvalue and issecretvalue(name)) and name or nil
	local extra = clientLines(tip, spoken, plainName)
	-- WHAT THE CLIENT SAID THAT WE DID NOT: a state it is in (a tag), a race
	-- it says better than ours, or small print - the short ones on one line
	-- between dots, a long one on a line of its own
	local states, small, facts = {}, {}, {}
	if about.faction then
		facts[#facts + 1] = about.faction
	end
	for _, line in ipairs(extra or {}) do
		local kind, words = M.StateOf(line)
		local class = about.class
		if kind then
			states[kind] = words
		elseif class and #line > #class + 1 and line:sub(-(#class + 1)) == " " .. class then
			-- THE CLIENT'S RACE LINE, SAID BY OUR TAG (Josh 2026-10-17:
			-- "Instead of "High order skyborne" is it possible to just say
			-- "Skyborne"?"). It writes "High Order Skyborne Druid" where the
			-- race is Skyborne; the tag keeps the race's own name. (It used to
			-- take the client's longer one, 2026-09-20.)
		elseif #line <= M.TAG_MOST and not line:find("%d") then
			facts[#facts + 1] = line
		else
			small[#small + 1] = line
		end
	end
	-- and what state it is in, after what it is
	if dead then
		addTag(tags, "Dead", "quiet")
	elseif plainYes(UnitIsTapDenied, unit) then
		addTag(tags, "Tapped", "quiet")
	end
	if states.skin then
		addTag(tags, states.skin, "skin")
	end
	if states.pvp or (isPlayer and plainYes(UnitIsPVP, unit)) then
		addTag(tags, "PvP", "pvp")
	end

	local level, lr, lg, lb = levelText(unit, isPlayer, dead)
	local rank = (not isPlayer) and M.RANK_TAG[classOf(unit)] or nil

	-- THE CLASS AS A PICTURE (Josh 2026-10-17: "Maybe for race and class we
	-- could use icons instead of tags?"): the client's own class icon before
	-- a player's name, in place of the class's tag. The race stays a word:
	-- its icons are small faces, one for each sex, and a race of this game's
	-- own may have none. A name the client keeps secret is left as it came.
	local icon = classFile and not (issecretvalue and issecretvalue(name)) and M.ClassIcon(classFile) or nil
	if icon then
		for i = #tags, 1, -1 do
			if tags[i][1] == about.class then
				table.remove(tags, i)
			end
		end
		name = icon .. name
	end

	-- ONE WIDTH, UNLESS THE NAME NEEDS MORE (Josh 2026-09-20). A header that
	-- wraps is the worst line on a tooltip: it is the biggest text there, so
	-- two ragged halves of a name are the first thing you see. The floor is
	-- raised to whatever the name, its level and an Elite tag beside it
	-- measure, up to a point - past that a name is genuinely too long and has
	-- to break somewhere. Worked out first: the tags are laid in rows this
	-- wide. A name the client keeps secret cannot be measured.
	local width = MIN_W
	local rankW = rank and (BT.UnitTip.TagWidth(rank[1]) + RANK_GAP) or 0
	if not (issecretvalue and issecretvalue(name)) then
		local needs = BT.UnitTip.Measure(name, HEADER, "name") + BT.UnitTip.Measure("    " .. level, LEVEL, "name")
			+ rankW + PAD_X + PAD_LEFT + 14
		width = math.max(MIN_W, math.min(MAX_W, math.floor(needs)))
	end

	tip:ClearLines()
	-- the last unit's tags go with its lines (GameTooltip's clearing says so
	-- too; a tooltip of another name does not)
	BT.UnitTip.HideTags(tip)
	tip:AddDoubleLine(name, level, nr, ng, nb, lr, lg, lb)
	sizeLine(tip, 1, HEADER)
	BT.UnitTip.SizeLine(tip, 1, LEVEL, "TextRight", "name")

	-- THE TAGS (Josh 2026-10-17): what it is and what state it is in, in rows
	-- as wide as the tooltip, each row laid over a line kept for it, straight
	-- under the name ("push them a bit tighter against the title")
	local firstTags = nil
	if #tags > 0 then
		for _, row in ipairs(BT.UnitTip.TagRows(tags, width - TAG_INSET)) do
			tip:AddLine(BT.UnitTip.TAG_BLANK)
			local i = BT.Pill.Number(tip:NumLines(), 2)
			firstTags = firstTags or i
			BT.UnitTip.SizeLine(tip, i, BT.UnitTip.TAG_LINE, nil, "text")
			BT.UnitTip.TagsOnLine(tip, i, row)
		end
	end
	-- who they are with, under them, in the guild's own green: a player's
	-- guild, or an NPC's job (Josh 2026-10-17: "Maybe we should have the NPC
	-- <Banker> line in the same style as a guild name for players?")
	local with = about.guild or about.title
	if with then
		tip:AddLine(M.GUILD:format("<" .. with .. ">"))
		sizeLine(tip, BT.Pill.Number(tip:NumLines(), 2), BT.UnitTip.ROW)
	end
	-- whatever else the client had to say, as small print under them
	if #facts > 0 then
		tip:AddLine(table.concat(facts, " · "), DIM[1], DIM[2], DIM[3])
		sizeLine(tip, BT.Pill.Number(tip:NumLines(), 2), FOOT)
	end
	for _, line in ipairs(small) do
		tip:AddLine(line, DIM[1], DIM[2], DIM[3])
		sizeLine(tip, BT.Pill.Number(tip:NumLines(), 2), FOOT)
	end
	indentBody(tip)
	-- TWO PIXELS MORE ABOVE THE TAGS (Josh 2026-10-17: "Can I get like 2px
	-- more margin above the tags?"): their first line hung that much lower
	-- off the name, and everything under it with it. No spacer line does it:
	-- one that small is one the client may write words into at a size too
	-- small to read.
	if firstTags then
		BT.UnitTip.Indent(tip, firstTags, BODY_INDENT, nil, -M.TAG_DROP)
	end

	-- the rows: the quests it counts for, then your kills of it
	M.QuestRows(tip, quests)
	M.KillsRow(tip, unit)

	-- Elite, Rare or Boss, as a tag just before the level
	if rank then
		local levelW = BT.UnitTip.Measure(level, LEVEL, "name")
		BT.UnitTip.PlaceTag(tip, 1, -(levelW + RANK_GAP + BT.UnitTip.TagWidth(rank[1])), { rank[1], rank[2] },
			"TextRight", "RIGHT")
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
		-- HIDDEN IS NOT GONE (Josh 2026-09-19). The client sizes the tooltip
		-- with room for this bar before we get to it, so hiding it left its
		-- height behind as a band of empty space under the last line. Nothing
		-- can be drawn in one pixel.
		if GameTooltipStatusBar.SetHeight then
			GameTooltipStatusBar:SetHeight(1)
		end
		GameTooltipStatusBar:Hide()
	end
	-- our own line instead, on something alive you can fight
	local fighting = (not isPlayer) and (not dead) and plainYes(UnitCanAttack, "player", unit)
	M.HealthLine(tip, fighting and unit or nil)
	-- the pull-up belongs to a unit tooltip: we wrote every line in it, so
	-- the header may sit as close to the rim as the body does to the sides
	if skins[tip] then
		skins[tip].wantTop = PAD_TOP
		-- and this one is OURS: we wrote every line in it, so it may be
		-- measured tighter than the client would have
		skins[tip].ours = true
		-- and room along the bottom for the health line, when there is one
		-- and the two pixels the tags were dropped by, which the client does
		-- not count when it measures the lines
		local room = (fighting and (M.HEALTH_H + 1) or 0) + (firstTags and M.TAG_DROP or 0)
		skins[tip].extraBottom = room > 0 and room or nil
	end
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, width)
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

	-- A SECOND CHANCE AT THE SKIN (Josh 2026-09-20). The skin is built inside
	-- a pcall: if anything in that build throws - a texture the client is not
	-- ready to hand out on the very first tooltip of a session - `skins[tip]`
	-- is never set and Dress returns nothing. Asking again costs nothing when
	-- the first ask worked.
	worn = skins[tip]
	if not (worn and worn.accent) then
		M.Dress(tip, true)
		worn = skins[tip]
	end
	if worn and worn.accent then
		-- THE SPINE SAYS WHO (Josh 2026-09-22). Class colour for a player,
		-- reaction colour for anything else: the same two-pixel edge the item
		-- tooltip and the quest tracker wear, in the colour of the thing you
		-- are asking about (see the README, "The spine"). Painted here, after
		-- the second chance at the skin, so the first tooltip of a session
		-- gets it too. A dead one keeps its colour here; only its name greys.
		worn.accent:SetColorTexture(sr, sg, sb, 0.9)
		-- NOT ON A RANKED MOB (Josh 2026-09-23): only an NPC is rare or elite,
		-- and the border round it already says what it is; a stripe of its
		-- reaction colour beside the border was two things saying one. The
		-- edge's own left bar comes back in its place (M.LeftBar).
		local ranked = worn.ornament and worn.ornament.style ~= nil
		worn.accent:SetShown(not ranked)
		M.LeftBar(worn)
	end
	-- the side a player is on, behind the words, now the tooltip has a height
	local side = isPlayer and plainText(UnitFactionGroup, unit) or nil
	if not M.Crest(tip, side) and worn and worn.crest then
		worn.crest:Hide()
	end
end

-- THE SIDE THEY ARE ON, BEHIND THE WORDS (Josh 2026-10-17: "Might be cool if
-- we have an Alliance or Horde watermark background on the tooltip").
-- ADDED TO THE FILL, NOT LAID ON IT ("I think the faction icons are behind
-- the background... cant see it"): laid on at 9%, dark art came out as
-- near-black on near-black. Added, it can only lighten what is under it.
-- RED OR BLUE, AND HALF THE CARD ("We should be able to clearly see if it is
-- red or blue (horde or alliance). I think we could also enlarge it quite a
-- bit so it covers like half the card background"). It was the unit frame's
-- PvP badge, greyed, at most 64 pixels. Now it is the side's own logo, the
-- one this client's Inspect window draws 256 pixels wide behind a character
-- (Blizzard_InspectUI/Camelot), greyed and tinted in the side's colour: as
-- big as half the card, centred on its height, with a little of it past the
-- right edge.
M.CREST_FILE = "Interface\\Timer\\%s-Logo"
-- EACH SIDE AS STRONG AS THE OTHER (Josh 2026-10-17: "the Alliance logo is
-- too visible compared to the horde logo"). Greyed and tinted alike at 40%,
-- the Alliance's added about five times the colour the Horde's did, read
-- off his screenshots: the lion is pale silver and the Horde's mark dark red,
-- so greyed the one is light and the other near black, and the blue tint
-- carries more light than the red. So each side has its own: the Alliance's
-- greyed and tinted blue; the Horde's keeps its own red, which greying threw
-- away.
-- SUBTLE, AND EVEN ("Faction logos are way too bright now. The intent here is
-- to just add a subtle background for some design flair... the horde icon is
-- much brighter than the alliance now"). At 30% and 65%, read off his next
-- two screenshots, the brightest tenth of the Alliance's lion stood about 22
-- levels of 255 above the fill and the Horde's mark about 78: its red is
-- bright in thin strokes, so at much the same colour overall it peaks far
-- higher. Both were set for about 9 at that brightest tenth.
-- BY EYE, NOT BY THE NUMBER ("Horde background logo is too dim now...
-- alliance looked fine"). Red that faint hardly shows on the fill's
-- green-grey, so the Horde's is nearly doubled; the Alliance's stays.
M.CREST_LOOK = {
	Alliance = { tint = { 0.25, 0.52, 1.00 }, alpha = 0.12, grey = true },
	Horde = { tint = { 1.00, 0.30, 0.22 }, alpha = 0.15, grey = false },
}
-- how big against the card's height and width (the smaller wins); how much
-- of it runs past the right edge
M.CREST_TALL, M.CREST_WIDE, M.CREST_BLEED = 1.25, 0.62, 0.12
-- what the last player's tooltip got, for What loaded (M.Status)
M.crestSaid = "none yet"

-- for What loaded on the Testing page
function M.Status()
	return ("last crest: %s"):format(M.crestSaid)
end

-- Lays `faction`'s crest on `tip`; returns it, or nil where there is none
function M.Crest(tip, faction)
	local s = skins[tip]
	if s then
		s.crestSide = nil
	end
	local look = faction and M.CREST_LOOK[faction]
	if not (s and look) then
		return nil
	end
	if not s.crest then
		-- over the fill and under the words
		s.crest = tex(tip, nil, "BORDER")
		s.crest.beebs = true
		-- laid again whenever the card changes size: the rows other parts
		-- add under it after this make it taller
		if tip.HookScript then
			tip:HookScript("OnSizeChanged", function(self)
				local worn = skins[self]
				if worn and worn.crestSide and worn.crest:IsShown() then
					M.LayCrest(self)
				end
			end)
		end
	end
	local c = s.crest
	local file = M.CREST_FILE:format(faction)
	local set, took = pcall(c.SetTexture, c, file)
	if not set or took == false then
		M.crestSaid = ("%s would not load"):format(file)
		return nil
	end
	pcall(c.SetDesaturated, c, look.grey)
	pcall(c.SetBlendMode, c, "ADD")
	c:SetVertexColor(look.tint[1], look.tint[2], look.tint[3])
	c:SetAlpha(look.alpha)
	s.crestSide = faction
	if not M.LayCrest(tip) then
		s.crestSide = nil
		return nil
	end
	c:Show()
	return c
end

-- The crest cut to the card. A texture is not clipped by the frame it is
-- on, so the part past the card's edges is cut off by the texture's own
-- coordinates. Returns false for a card too small to carry one.
function M.LayCrest(tip)
	local s = skins[tip]
	local c = s and s.crest
	if not c then
		return false
	end
	local N = BT.Pill.Number
	local w, h = N(tip.GetWidth and tip:GetWidth(), 0), N(tip.GetHeight and tip:GetHeight(), 0)
	local size = math.min(h * M.CREST_TALL, w * M.CREST_WIDE)
	if size < 24 then
		M.crestSaid = "tooltip too small"
		c:Hide()
		return false
	end
	local left = w - size * (1 - M.CREST_BLEED)
	local top = (h - size) / 2
	-- inside the rim
	local vl, vr = math.max(left, 1), math.min(left + size, w - 1)
	local vt, vb = math.max(top, 1), math.min(top + size, h - 1)
	c:SetTexCoord((vl - left) / size, (vr - left) / size, (vt - top) / size, (vb - top) / size)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", tip, "TOPLEFT", vl, -vt)
	c:SetSize(vr - vl, vb - vt)
	M.crestSaid = ("%s, %d px"):format(tostring(s.crestSide), math.floor(size + 0.5))
	return true
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
	if quality == nil then
		quality = select(3, BT.Util.ItemInfo(link))
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
		-- the one size (UI/Settings.lua), a little under the panels'
		local want = 0.95 * (BT.Scale and BT.Scale() or 1)
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
	local itemlevel = BT.GetModule("itemlevel")
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if not (itemLink and itemlevel and itemlevel.LevelOf and type(info) == "function") then
		return nil
	end
	local ok, _, _, _, _, _, _, _, _, equipLoc = pcall(info, itemLink)
	if not ok or equipLoc == nil or NOT_WORN[equipLoc] then
		return nil
	end
	local lvl = itemlevel.LevelOf(itemLink)
	return lvl and ("|cff8a9894ilvl|r %d"):format(lvl) or nil
end

local function itemLevel(tip)
	if not tip.GetItem then
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
	-- SMALL PRINT BESIDE THE NAME (Josh 2026-10-17: "Make the ilvl much
	-- smaller"): it was the name's own size
	BT.UnitTip.SizeLine(tip, 1, M.ILVL_SIZE, "TextRight", "text")
	right:Show()
	return right
end
M.ItemLevel = itemLevel
M.ILVL_SIZE = 10

-- ---------------------------------------------------------------------------
-- AN ITEM IN THE UNIT TOOLTIP'S STYLE (Josh 2026-10-17: "Could we use the same
-- style for item tooltips? Currently the text kind of all looks the same",
-- then "Rebuild directly")
-- ---------------------------------------------------------------------------
--
-- Not rebuilt: the client writes an item tooltip in more shapes than a list
-- could follow (a recipe with an item inside it, sets, sockets), so each of
-- its lines is restyled where it is. The client says what kind of line each
-- one is, and which tooltip line it went on (tooltipData.lines[i].type and
-- .lineIndex, Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua):
--
--   binding, "Unique"            an outlined tag: a state of your copy, not
--                                what the item is ("should probably look
--                                different than the tags under it"), with
--                                room under it
--   the slot and its type        two grey tags ("Main Hand", "Mace")
--   damage, stats, effects       the rows' size, in the colours the game gave
--                                them (green effects, red requirements)
--   damage per second,           small grey print
--   durability
--   flavour text                 the note's italic
--
-- The name stays as the client drew it (see below), and the sell price and
-- the F6 line are quietened after (quietFooter).

-- what the client wrote, where it may be read
local function plainLine(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then
		return nil
	end
	return v
end

-- the client's own sentence as a pattern, its "%s" or "%d" any words
local function sentence(global, fallback)
	local form = type(_G[global]) == "string" and _G[global] or fallback
	local escaped = form:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. escaped:gsub("%%[sd]", ".+") .. "$"
end
M.DPS_LINE = sentence("DPS_TEMPLATE", "(%s damage per second)")
M.DURABILITY_LINE = sentence("DURABILITY_TEMPLATE", "Durability %d / %d")

-- a line made a row of tags: its words go, the tags are laid where they were;
-- `size` makes the line taller, and `point` hangs them from its top
M.BOUND_LINE = 13
local function tagLine(tip, i, tags, size, point)
	local T = BT.UnitTip
	local fs = lineOf(tip, i)
	if not (fs and fs.SetText) or #tags == 0 then
		return false
	end
	pcall(fs.SetText, fs, T.TAG_BLANK)
	local right = lineOf(tip, i, "TextRight")
	if right and right.SetText then
		pcall(right.SetText, right, "")
	end
	T.SizeLine(tip, i, size or T.TAG_LINE, nil, "text")
	T.TagsOnLine(tip, i, tags, point)
	return true
end

-- Restyles the lines `data` names; returns how many
function M.ItemLines(tip, data)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return 0
	end
	local T = BT.UnitTip
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	T.HideTags(tip)
	local n = 0
	for _, line in ipairs(data.lines) do
		local i = plainLine(type(line) == "table" and line.lineIndex or nil)
		local kind = plainLine(type(line) == "table" and line.type or nil)
		local left = plainLine(type(line) == "table" and line.leftText or nil)
		local right = plainLine(type(line) == "table" and line.rightText or nil)
		left = type(left) == "string" and left ~= "" and left or nil
		right = type(right) == "string" and right ~= "" and right or nil
		if type(i) == "number" and i > 1 then
			local fs = lineOf(tip, i)
			if (kind ~= nil and kind == LT.ItemBinding) or (left and left == _G.ITEM_UNIQUE) then
				-- its line taller than a row of tags, and the tag at the top of
				-- it: the room falls under it (Josh 2026-10-17: "Soulbound
				-- needs some margin under it"), and no line is moved
				tagLine(tip, i, { { left, "bound" } }, M.BOUND_LINE, "TOPLEFT")
			elseif kind ~= nil and kind == LT.EquipSlot then
				local tags = {}
				for _, words in ipairs({ left or false, right or false }) do
					if words then
						tags[#tags + 1] = { words }
					end
				end
				tagLine(tip, i, tags)
			elseif kind ~= nil and kind == LT.FlavorText then
				T.SizeLine(tip, i, T.ROW + 1, nil, "quote")
			elseif left and (left:find(M.DPS_LINE) or left:find(M.DURABILITY_LINE)) then
				T.SizeLine(tip, i, FOOT, nil, "text")
				if fs and fs.SetTextColor then
					fs:SetTextColor(DIM[1], DIM[2], DIM[3])
				end
			else
				T.SizeLine(tip, i, T.ROW, nil, "text")
				if right then
					T.SizeLine(tip, i, T.ROW, "TextRight", "text")
				end
			end
			n = n + 1
		end
	end
	return n
end

-- ---------------------------------------------------------------------------
-- AN ITEM, WRITTEN AGAIN (Josh 2026-10-17: option C of the item tooltip
-- canvas, then "Yes, build option C. Make sure we use this for the
-- "equipped" compairson tooltip as well")
-- ---------------------------------------------------------------------------
--
--   [icon] the name, in its quality's colour
--          type · slot · ilvl 63
--   [BoE]                                  Requires Level 58
--   ── DAMAGE   three tiles: per second, a hit, speed (ARMOR on armour)
--   ── STATS    +13 Stamina
--   ── EQUIP    the effects, under what sets each off (Use, Chance on hit,
--               Enchant), in the game's green
--   anything else the client said, in its own colours
--   the flavour text, in the lore's italic
--   [a short bar] 61/120                    the sell price, in coins
--   Made by Lorelei
--
-- Written from the client's own account of each line (M.ReadItem), so no
-- line is placed by guessing where it sat. A tooltip in a shape this does not
-- know - a recipe with an item inside it, a gem socket, the cost of a repair
-- - is restyled where it is instead (M.ItemLines). The icon, the tiles, the
-- rules over the headings and the bar are ours, laid over lines kept for
-- them, on each tooltip its own (M.ItemBits).

-- the sizes, in the game's points (Core/Fonts.lua moves them for the face)
M.ITEM = {
	NAME = 13.5, SUB = 10, HEAD = 8, ROW = 10.5, FLAVOUR = 12, FOOT = 9, MAKER = 9.5,
	ICON = 26, ICON_GAP = 7, TILE_VALUE = 12.5, TILE_LABEL = 7.5, TILE_PAD = 3, TILE_SPLIT = 1,
	TILE_GAP = 3, TILE_IN = 5, TILE_LEAST = 8, TILE_LABEL_LEAST = 6, TILE_TINT = 0.16,
	HEADLINE = 12, FIG_SMALL = 10, FIG_LABEL = 7.5, FIG_GAP = 4, CELL_PAD = 6, CELL_PAD_Y = 2, QUIET = 9.5,
	BAR_H = 3, BAR_W = 44, BAR_GAP = 5, MIN_W = 240, PLAIN_W = 180, INSET = 20, SPACER = 4,
}

-- A TILE AS TALL AS WHAT IS IN IT (Josh 2026-10-17: "Line height issues on
-- the damage numbers"). It was a fixed 24 pixels, and the face in use draws
-- the number and its label bigger than their sizes say (Core/Fonts.lua), so
-- the label rode up into the number and the tile hung into the line under
-- it. Now: the number, its label under it, room round both, at the sizes
-- they are drawn at; and the line kept for the tiles is that tall.
function M.TileHeight()
	local I, size = M.ITEM, BT.Fonts.Size
	return I.TILE_PAD * 2 + I.TILE_SPLIT + size(I.TILE_VALUE) + size(I.TILE_LABEL)
end

-- the size to give a line for it to come out `px` tall (T.SizeLine moves
-- every size by the face's own amount)
local function lineFor(px)
	return px - (BT.Fonts.Size(px) - px)
end
local ITEM_INK = { 0.91, 0.93, 0.92 }
local ITEM_SUB = { 0.65, 0.71, 0.68 }
local ITEM_HEAD = { 0.49, 0.55, 0.53 }
local ITEM_GREEN = { 0.12, 1, 0 }
local ITEM_MAKER = { 0.37, 0.68, 0.37 }
-- a spell's description, kept where it says more than its figures: quieter
local ITEM_QUIET = { 0.58, 0.63, 0.61 }

-- the client's own sentence as a pattern, its "%s" and "%d" captured
local function capturing(global, fallback)
	local form = type(_G[global]) == "string" and _G[global] or fallback
	local escaped = form:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. escaped:gsub("%%[sd]", "(.-)") .. "$"
end
M.ITEM_LINES = {
	dps = capturing("DPS_TEMPLATE", "(%s damage per second)"),
	damage = capturing("DAMAGE_TEMPLATE", "%s - %s Damage"),
	armor = capturing("ARMOR_TEMPLATE", "%s Armor"),
	block = capturing("SHIELD_BLOCK_TEMPLATE", "%d Block"),
	level = capturing("ITEM_MIN_LEVEL", "Requires Level %d"),
	durability = capturing("DURABILITY_TEMPLATE", "Durability %d / %d"),
	maker = capturing("ITEM_CREATED_BY", "<Made by %s>"),
	setBonus = capturing("ITEM_SET_BONUS", "Set: %s"),
	setBonusGrey = capturing("ITEM_SET_BONUS_GRAY", "(%d) Set: %s"),
}

-- BOE, NOT "BINDS WHEN EQUIPPED" (Josh 2026-10-17: "can we shorted "binds
-- when equipped" and "binds on pickup" to just BoE and BoP?"), in the case
-- players write them in. "Soulbound" stays a word: the item is already bound.
function M.BindShort(text)
	if type(text) ~= "string" then
		return nil
	end
	local short = {
		[_G.ITEM_BIND_ON_EQUIP or "Binds when equipped"] = "BoE",
		[_G.ITEM_BIND_ON_PICKUP or "Binds when picked up"] = "BoP",
		[_G.ITEM_BIND_ON_USE or "Binds when used"] = "BoU",
		[_G.ITEM_BIND_TO_ACCOUNT or "Binds to account"] = "BoA",
		["Binds on pickup"] = "BoP", ["Binds on equip"] = "BoE",
	}
	return short[text]
end

-- what sets an effect off, from the words the client starts its line with
local TRIGGERS = {
	{ "ITEM_SPELL_TRIGGER_ONEQUIP", "Equip:", "Equip" },
	{ "ITEM_SPELL_TRIGGER_ONUSE", "Use:", "Use" },
	{ "ITEM_SPELL_TRIGGER_ONPROC", "Chance on hit:", "Chance on hit" },
}
local function trigger(text)
	for _, t in ipairs(TRIGGERS) do
		local word = type(_G[t[1]]) == "string" and _G[t[1]] or t[2]
		if text:sub(1, #word) == word then
			return t[3], (text:sub(#word + 1):gsub("^%s+", ""))
		end
	end
	return nil, text
end

-- a line's colour as three numbers, where the client lets us read it
local function colourOf(c)
	if type(c) ~= "table" then
		return nil
	end
	local r, g, b = plainLine(c.r), plainLine(c.g), plainLine(c.b)
	if type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return { r, g, b }
	end
	return nil
end
local function isGreen(c)
	return c ~= nil and c[2] > 0.8 and c[1] < 0.35 and c[3] < 0.35
end

-- lines this rebuild does not know how to place: the tooltip is restyled
-- where it is instead
local ODD = { "NestedBlock", "GemSocket", "GemSocketEnchantment", "LearnableSpell", "AzeriteEssenceSlot",
	"AzeriteEssencePower", "AzeriteItemPowerDescription", "RuneforgeLegendaryPowerDescription", "ItemUpgradeLevel",
	"ToyName", "ToyText", "ToyEffect", "ToyDuration", "ToyDescription", "ToySource" }

-- The client's lines, sorted into what the tooltip shows; nil for a shape
-- this does not know. `shopping`: a comparison tooltip, which has no price.
function M.ReadItem(data, shopping)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	local odd = {}
	for _, name in ipairs(ODD) do
		if LT[name] ~= nil then
			odd[LT[name]] = true
		end
	end
	local P = M.ITEM_LINES
	local item = { stats = {}, effects = {}, rest = {}, notes = {}, extraDamage = {} }
	for _, line in ipairs(data.lines) do
		local shown = type(line) == "table" and plainLine(line.lineIndex)
		if shown then
			local kind = plainLine(line.type)
			if kind ~= nil and odd[kind] then
				return nil
			end
			local left = plainLine(line.leftText)
			local right = plainLine(line.rightText)
			left = type(left) == "string" and left ~= "" and left or nil
			right = type(right) == "string" and right ~= "" and right or nil
			local lc, rc = colourOf(line.leftColor), colourOf(line.rightColor)
			if not item.name then
				if not left then
					return nil
				end
				item.name, item.quality = left, lc
			elseif kind ~= nil and kind == LT.ItemBinding then
				item.bind = left
			elseif left and (left == _G.ITEM_UNIQUE or left == "Unique" or left == _G.ITEM_UNIQUE_EQUIPPABLE) then
				item.unique = left
			elseif kind ~= nil and kind == LT.EquipSlot then
				item.slot, item.kind = left, right
			elseif kind ~= nil and kind == LT.SellPrice then
				local price = plainLine(line.price)
				if not shopping and type(price) == "number" and price > 0 then
					item.price = price
				end
			elseif kind ~= nil and kind == LT.FlavorText then
				item.flavour, item.flavourRgb = left, lc
			elseif kind ~= nil and kind == LT.ItemLevel and left and left:match("(%d+)%s*$") then
				-- the client's own "Item Level 10": said beside the kind
				item.level = left:match("(%d+)%s*$")
			elseif not left then
				-- a blank the client spaced with: our own spacing stands in
			elseif kind ~= nil and kind == LT.ItemEnchantmentPermanent then
				item.effects[#item.effects + 1] = { head = "Enchant", text = left, rgb = lc }
			elseif left:find(P.dps) then
				item.dps = left:match(P.dps)
			elseif right and left:find(P.damage) and right:find("%d") then
				local lo, hi = left:match(P.damage)
				-- "41 - 77 Shadow Damage": the school comes off the top number
				local top, school = hi:match("^([%d%.,]+)%s+(.+)$")
				item.damage, item.speed = ("%s–%s"):format(lo, top or hi), right:match("([%d%.,]+)")
				item.school = school
			elseif left:find(P.damage) then
				item.extraDamage[#item.extraDamage + 1] = { text = left, rgb = lc }
			elseif left:find(P.armor) then
				item.armor = left:match(P.armor)
			elseif left:find(P.block) then
				item.block = left:match(P.block)
			elseif left:find(P.level) then
				item.require = { text = left, rgb = lc }
			elseif left:find(P.durability) then
				local now, most = left:match(P.durability)
				item.durability = { now = tonumber(now), most = tonumber(most), text = now .. "/" .. most }
			elseif left:find(P.maker) then
				item.maker = left:match(P.maker)
			elseif left:find(P.setBonus) or left:find(P.setBonusGrey) then
				-- a set's bonus stays with the set's name and pieces above it,
				-- in the client's order: green as it is, it is not an enchant
				item.rest[#item.rest + 1] = { text = left, rgb = lc, wrap = true }
			elseif isFootnote(left) then
				item.notes[#item.notes + 1] = left
			else
				local head, text = trigger(left)
				if head then
					item.effects[#item.effects + 1] = { head = head, text = text, rgb = lc }
				elseif left:find("^[%+%-]%d") and not isGreen(lc) then
					item.stats[#item.stats + 1] = { text = left, rgb = lc }
				elseif isGreen(lc) and not left:find("^%(") then
					-- a green line nothing else names: an enchant laid on for a
					-- while (Rockbiter)
					item.effects[#item.effects + 1] = { head = "Enchant", text = left, rgb = lc }
				else
					item.rest[#item.rest + 1] = { text = left, rgb = lc, right = right, rrgb = rc,
						wrap = plainLine(line.wrapText) and true or nil }
				end
			end
		end
	end
	if not item.name then
		return nil
	end
	return item
end

-- WHAT A POTION, BANDAGE OR DRINK DOES, AS A FIGURE (Josh 2026-10-17, choosing
-- "Give potions, food and bandages the spell figures"): from its Use line, as
-- a spell's from its description. One that works over time, a second of it
-- ("Heals 66 damage over 6 sec": 11.0 HPS); one that does it at once, the
-- middle of what it does ("Restores 140 to 180 health": 160 HEALING). Nil
-- where it says no amount.
function M.UseFigures(item)
	for _, e in ipairs(item.effects or {}) do
		if e.head == "Use" then
			local label, _, amount, over = M.SpellAmount(e.text)
			if label and amount then
				local word, ink = M.PerSecond(label)
				if type(over) == "number" and over > 0 then
					return { { M.Figure(amount / over), word, ink } }
				elseif not over then
					return { { M.Middle(amount), label, ink } }
				end
			end
		end
	end
	return nil
end

-- an item's icon, by its id
function M.ItemIcon(id)
	id = plainLine(id)
	if type(id) ~= "number" then
		return nil
	end
	for _, fn in ipairs({ C_Item and C_Item.GetItemIconByID or false, _G.GetItemIcon or false }) do
		if fn then
			local ok, icon = pcall(fn, id)
			if ok and icon and not (issecretvalue and issecretvalue(icon)) then
				return icon
			end
		end
	end
	return nil
end

-- what kind of thing an item is, in the client's words, for one with no slot
-- line: its class and subclass ("Consumable", "Bandage"), once where they are
-- the same word; nil where the client will not say
function M.ItemClass(id)
	id = plainLine(id)
	local get = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
	if type(id) ~= "number" or type(get) ~= "function" then
		return nil
	end
	local ok, _, kind, sub = pcall(get, id)
	if not ok then
		return nil
	end
	local out = {}
	for _, words in ipairs({ plainLine(kind) or false, plainLine(sub) or false }) do
		if type(words) == "string" and words ~= "" and words ~= out[1] then
			out[#out + 1] = words
		end
	end
	return #out > 0 and out or nil
end

-- the price in the game's own coins
function M.Coins(price)
	local C = C_CurrencyInfo
	if C and C.GetCoinTextureString then
		local ok, text = pcall(C.GetCoinTextureString, price, 10)
		if ok and type(text) == "string" then
			return text
		end
	end
	local g, s, c = math.floor(price / 10000), math.floor(price / 100) % 100, price % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

-- ours on each tooltip: the icon and its edge, the tiles, the rules and the
-- bar, made the first time an item is written on it
local bitsOf = setmetatable({}, { __mode = "k" })
function M.ItemBits(tip)
	local b = bitsOf[tip]
	if b then
		return b
	end
	b = { tiles = {}, rules = {} }
	b.holder = CreateFrame("Frame", nil, tip)
	-- ours: the comparison tooltip's tab is looked for among its children
	-- (restyleTab), and this is not it
	b.holder.beebs = true
	b.holder:SetFrameStrata("TOOLTIP")
	b.holder:SetAllPoints(tip)
	b.edge = b.holder:CreateTexture(nil, "BORDER")
	b.icon = b.holder:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.edge:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, -1)
	b.barBg = b.holder:CreateTexture(nil, "ARTWORK")
	b.bar = b.holder:CreateTexture(nil, "OVERLAY")
	b.bar:SetPoint("TOPLEFT", b.barBg, "TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT", b.barBg, "BOTTOMLEFT")
	-- the durability's numbers, beside the bar (M.WriteItem, the foot)
	b.worn = b.holder:CreateFontString(nil, "OVERLAY")
	b.worn:SetPoint("LEFT", b.barBg, "RIGHT", M.ITEM.BAR_GAP, 0)
	-- a spell's two figures at the right of its name and rank, each a number
	-- and its label; and its facts' cells, made as they are wanted
	b.figs = {}
	for i = 1, 2 do
		b.figs[i] = { num = b.holder:CreateFontString(nil, "OVERLAY"), label = b.holder:CreateFontString(nil, "OVERLAY") }
	end
	b.cellText, b.cellLines = {}, {}
	bitsOf[tip] = b
	return b
end

-- everything of ours off `tip`
function M.HideItemBits(tip)
	local b = bitsOf[tip]
	if not b then
		return
	end
	b.icon:Hide()
	b.edge:Hide()
	b.barBg:Hide()
	b.bar:Hide()
	b.worn:Hide()
	for _, f in ipairs(b.figs) do
		f.num:Hide()
		f.label:Hide()
	end
	for _, t in ipairs(b.cellText) do
		t:Hide()
	end
	for _, t in ipairs(b.cellLines) do
		t:Hide()
	end
	if b.deltaRule then
		b.deltaRule:Hide()
	end
	for _, t in ipairs(b.tiles) do
		t.bg:Hide()
		t.value:Hide()
		t.label:Hide()
	end
	for _, r in ipairs(b.rules) do
		r:Hide()
	end
	b.holder:Hide()
end
BT.UnitTip.OnGone(M.HideItemBits)

local function tile(b, i)
	local t = b.tiles[i]
	if t then
		return t
	end
	t = {}
	t.bg = b.holder:CreateTexture(nil, "ARTWORK")
	t.value = b.holder:CreateFontString(nil, "OVERLAY")
	t.label = b.holder:CreateFontString(nil, "OVERLAY")
	local I = M.ITEM
	local number = BT.Tip and BT.Tip.NUMBER
	if number then
		pcall(t.value.SetFont, t.value, number, BT.Fonts.Size(I.TILE_VALUE), "")
	else
		BT.Fonts.Set(t.value, "text", I.TILE_VALUE)
	end
	BT.Fonts.Set(t.label, "name", I.TILE_LABEL)
	-- the number's own font, to go back to after one too wide was set smaller
	t.font = { t.value:GetFont() }
	t.labelFont = { t.label:GetFont() }
	t.value:SetPoint("TOPLEFT", t.bg, "TOPLEFT", I.TILE_IN, -I.TILE_PAD)
	-- hung from the number, so the two never meet whatever the face
	t.label:SetPoint("TOPLEFT", t.value, "BOTTOMLEFT", 0, -I.TILE_SPLIT)
	b.tiles[i] = t
	return t
end

-- THE PIECES EVERY CARD IS WRITTEN WITH (Josh 2026-10-17: "I'd like a
-- cohesive tooltip look across the board", then "Yes, spell and buff
-- tooltips should get the same look"). An item, a spell and a buff are
-- written alike: the name with a line under it beside the icon, small
-- headings over rules, tiles, rows, laid on `tip` from its first line.
local function card(tip)
	local T, I = BT.UnitTip, M.ITEM
	local b = M.ItemBits(tip)
	tip:ClearLines()
	T.HideTags(tip)
	M.HideItemBits(tip)
	b.holder:Show()
	local c = { b = b, heads = {}, tileLines = {}, tileH = M.TileHeight(), off = 0 }
	function c.last()
		return BT.Pill.Number(tip:NumLines(), 1)
	end
	function c.spacer()
		tip:AddLine(" ")
		T.SizeLine(tip, c.last(), I.SPACER, nil, "text")
	end
	function c.section(title)
		c.spacer()
		tip:AddLine(title:upper(), ITEM_HEAD[1], ITEM_HEAD[2], ITEM_HEAD[3])
		T.SizeLine(tip, c.last(), I.HEAD, nil, "name")
		c.heads[#c.heads + 1] = c.last()
	end
	-- Facts in cells, in rows no wider than `inner`, on a line kept for
	-- them as tall as the rows; each item { shown words, plain words }
	function c.cells(items, inner)
		local rows, row, used = {}, {}, 0
		for _, it in ipairs(items) do
			local w = math.ceil(T.Measure(it[2], I.SUB, "text")) + 2 * I.CELL_PAD + 1
			if #row > 0 and used + w > inner then
				rows[#rows + 1] = row
				row, used = {}, 0
			end
			row[#row + 1] = { text = it[1], w = w }
			used = used + w
		end
		if #row > 0 then
			rows[#rows + 1] = row
		end
		local h = math.ceil(BT.Fonts.Size(I.SUB)) + 2 * I.CELL_PAD_Y + 1
		tip:AddLine(T.TAG_BLANK)
		T.SizeLine(tip, c.last(), lineFor(#rows * h + 1), nil, "text")
		c.cellRows = { line = c.last(), rows = rows, h = h }
	end
	-- `list`: { value, label } each; a missing value leaves no tile
	function c.tiles(list)
		tip:AddLine(T.TAG_BLANK)
		T.SizeLine(tip, c.last(), lineFor(c.tileH), nil, "text")
		c.tileLines[#c.tileLines + 1] = { line = c.last(), list = list }
	end
	function c.row(text, rgb, right, rrgb, wrap)
		rgb = rgb or ITEM_INK
		if right then
			rrgb = rrgb or rgb
			tip:AddDoubleLine(text, right, rgb[1], rgb[2], rgb[3], rrgb[1], rrgb[2], rrgb[3])
			T.SizeLine(tip, c.last(), I.ROW, "TextRight", "text")
		else
			tip:AddLine(text, rgb[1], rgb[2], rgb[3], wrap and true or nil)
		end
		T.SizeLine(tip, c.last(), I.ROW, nil, "text")
	end
	-- The name, and the line under it, beside `icon` (in an edge of `edge`).
	-- ALWAYS A SECOND LINE BESIDE THE ICON (Josh 2026-10-17: ""use" tag has
	-- overlap with the icon. Crafting reagents as well"): with only the name
	-- beside it, the next line ran under the icon, so the line is kept even
	-- with nothing to say.
	-- `figs`, where given, are a figure for the right of the name and one for
	-- the right of the line under it, each { number, label, ink }; either may
	-- be missing. The lines keep a blank at their right, as tall as the line,
	-- for the figures to be laid against (c.finish).
	function c.header(name, rgb, icon, sub, edge, figs)
		c.off = icon and (I.ICON + I.ICON_GAP) or 0
		local said = type(sub) == "string" and sub ~= ""
		if figs then
			tip:AddDoubleLine(name, T.TAG_BLANK, rgb[1], rgb[2], rgb[3], 1, 1, 1, false, c.off)
			T.SizeLine(tip, 1, I.NAME, nil, "name")
			T.SizeLine(tip, 1, I.NAME, "TextRight", "text")
			tip:AddDoubleLine(said and sub or " ", T.TAG_BLANK, ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3], 1, 1, 1, false, c.off)
			T.SizeLine(tip, 2, I.SUB, nil, "text")
			T.SizeLine(tip, 2, I.SUB, "TextRight", "text")
			c.figs = figs
		else
			tip:AddLine(name, rgb[1], rgb[2], rgb[3], false, c.off)
			T.SizeLine(tip, 1, I.NAME, nil, "name")
			if said or icon then
				tip:AddLine(said and sub or " ", ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3], false, c.off)
				T.SizeLine(tip, 2, I.SUB, nil, "text")
			end
		end
		if icon then
			local fs = T.LineOf(tip, 1)
			local e = edge or rgb
			b.icon:SetTexture(icon)
			b.icon:ClearAllPoints()
			b.icon:SetPoint("TOPLEFT", fs, "TOPLEFT", -c.off, 1)
			b.icon:SetSize(I.ICON, I.ICON)
			b.edge:SetColorTexture(e[1], e[2], e[3], 0.9)
			b.icon:SetShown(fs ~= nil)
			b.edge:SetShown(fs ~= nil)
		end
	end
	-- As wide as `needs`, never narrower than `floor`; shown, so it has a
	-- width; then the rules and tiles laid by that width. Returns it.
	function c.finish(floor, needs)
		if tip.SetMinimumWidth then
			pcall(tip.SetMinimumWidth, tip, math.max(floor, math.min(MAX_W, math.floor(needs))))
		end
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
		local inner = BT.Pill.Number(tip.GetWidth and tip:GetWidth(), floor) - I.INSET
		inner = math.max(floor - I.INSET, inner)
		for i, line in ipairs(c.heads) do
			local fs = T.LineOf(tip, line)
			local r = b.rules[i]
			if not r then
				r = b.holder:CreateTexture(nil, "ARTWORK")
				b.rules[i] = r
			end
			if fs then
				r:ClearAllPoints()
				r:SetPoint("BOTTOMLEFT", fs, "TOPLEFT", 0, 3)
				r:SetSize(inner, 1)
				r:SetColorTexture(SKIN_RIM[1], SKIN_RIM[2], SKIN_RIM[3], 0.9)
				r:Show()
			end
		end
		-- three to a row, or as many as there are past three (a spell's cost,
		-- range, cast and cooldown)
		local n = 0
		for _, at in ipairs(c.tileLines) do
			local fs = T.LineOf(tip, at.line)
			local shown = 0
			for _, t in ipairs(at.list) do
				if t[1] then
					shown = shown + 1
				end
			end
			local slots = math.max(3, shown)
			local tileW = math.floor((inner - (slots - 1) * I.TILE_GAP) / slots)
			local x = 0
			for _, t in ipairs(at.list) do
				if t[1] and fs then
					n = n + 1
					local it = tile(b, n)
					it.bg:ClearAllPoints()
					it.bg:SetPoint("TOPLEFT", fs, "TOPLEFT", x, 0)
					it.bg:SetSize(tileW, c.tileH)
					-- faintly its own colour where it has one (a DPS tile red),
					-- or the plain wash
					local tint = t[4]
					if tint then
						it.bg:SetColorTexture(tint[1], tint[2], tint[3], I.TILE_TINT)
					else
						it.bg:SetColorTexture(1, 1, 1, 0.045)
					end
					-- in its own colour where the client gave it one (a cost you
					-- cannot pay, in red)
					local ink = t[3] or ITEM_INK
					local f = it.font
					if f and f[1] and f[2] then
						pcall(it.value.SetFont, it.value, f[1], f[2], f[3])
					end
					it.value:SetText(t[1])
					it.value:SetTextColor(ink[1], ink[2], ink[3])
					-- A NUMBER NEVER RUNS OUT OF ITS TILE (Josh 2026-10-17: "The
					-- spell stat lines "Instant" goes out of the box"): one wider
					-- than its tile is set smaller until it fits
					local wide = BT.Pill.Number(it.value.GetStringWidth and it.value:GetStringWidth(), 0)
					local room = tileW - 2 * I.TILE_IN
					if f and f[1] and f[2] and wide > room then
						pcall(it.value.SetFont, it.value, f[1], math.max(I.TILE_LEAST, f[2] * room / wide), f[3])
					end
					-- and the label likewise, never under its least
					local lf = it.labelFont
					if lf and lf[1] and lf[2] then
						pcall(it.label.SetFont, it.label, lf[1], lf[2], lf[3])
					end
					it.label:SetText(t[2]:upper())
					local lw = BT.Pill.Number(it.label.GetStringWidth and it.label:GetStringWidth(), 0)
					if lf and lf[1] and lf[2] and lw > room then
						pcall(it.label.SetFont, it.label, lf[1], math.max(I.TILE_LABEL_LEAST, lf[2] * room / lw), lf[3])
					end
					it.label:SetTextColor(ITEM_HEAD[1], ITEM_HEAD[2], ITEM_HEAD[3])
					it.bg:Show()
					it.value:Show()
					it.label:Show()
					x = x + tileW + I.TILE_GAP
				end
			end
		end
		-- THE FIGURES, PLAIN AND RIGHT-ALIGNED (Josh 2026-10-17, picking D of
		-- the spell canvas's redesign: "Can we remove the borders from the
		-- dps/hps and per resource, and then right align those 2 lines?"): a
		-- number in its colour, its label small after it, against the right
		-- of the name's line and the rank's; the label sat on the number's foot
		local number = BT.Tip and BT.Tip.NUMBER
		for i = 1, 2 do
			local f = c.figs and c.figs[i]
			local at, g = T.LineOf(tip, i, "TextRight"), b.figs[i]
			if f and at and g then
				local size = BT.Fonts.Size(i == 1 and I.HEADLINE or I.FIG_SMALL)
				if not (number and pcall(g.num.SetFont, g.num, number, size, "")) then
					BT.Fonts.Set(g.num, "text", i == 1 and I.HEADLINE or I.FIG_SMALL)
				end
				BT.Fonts.Set(g.label, "name", I.FIG_LABEL)
				g.num:SetText(f[1])
				g.num:SetTextColor(f[3][1], f[3][2], f[3][3])
				g.label:SetText(f[2]:upper())
				g.label:SetTextColor(ITEM_HEAD[1], ITEM_HEAD[2], ITEM_HEAD[3])
				g.label:ClearAllPoints()
				g.label:SetPoint("RIGHT", at, "RIGHT", 0, -math.floor((size - BT.Fonts.Size(I.FIG_LABEL)) / 2))
				g.num:ClearAllPoints()
				g.num:SetPoint("BOTTOMRIGHT", g.label, "BOTTOMLEFT", -I.FIG_GAP, -1)
				g.num:Show()
				g.label:Show()
			end
		end
		-- THE FACTS IN CELLS, lines between them in the rim's colour ("I like
		-- D with the borders"): each row's cells share out what is left of
		-- the width, so a row runs edge to edge
		local cr = c.cellRows
		local at = cr and T.LineOf(tip, cr.line)
		if at then
			local nLine, nText = 0, 0
			local function rule(x, y, w, h)
				nLine = nLine + 1
				local t = b.cellLines[nLine]
				if not t then
					t = b.holder:CreateTexture(nil, "ARTWORK")
					b.cellLines[nLine] = t
				end
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", at, "TOPLEFT", x, -y)
				t:SetSize(w, h)
				t:SetColorTexture(SKIN_RIM[1], SKIN_RIM[2], SKIN_RIM[3], 0.9)
				t:Show()
			end
			for r, row in ipairs(cr.rows) do
				local y = (r - 1) * cr.h
				rule(0, y, inner, 1)
				local natural = 0
				for _, cell in ipairs(row) do
					natural = natural + cell.w
				end
				local extra = math.max(0, inner - natural) / #row
				local x = 0
				for k, cell in ipairs(row) do
					local left = math.floor(x + 0.5)
					if k > 1 then
						rule(left, y, 1, cr.h + 1)
					end
					nText = nText + 1
					local t = b.cellText[nText]
					if not t then
						t = b.holder:CreateFontString(nil, "OVERLAY")
						b.cellText[nText] = t
					end
					BT.Fonts.Set(t, "text", I.SUB)
					t:SetText(cell.text)
					t:SetTextColor(ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3])
					t:ClearAllPoints()
					t:SetPoint("LEFT", at, "TOPLEFT", left + 1 + I.CELL_PAD, -(y + (cr.h + 1) / 2))
					t:Show()
					x = x + cell.w + extra
				end
			end
			local tall = #cr.rows * cr.h
			rule(0, tall, inner, 1)
			rule(0, 0, 1, tall + 1)
			rule(inner - 1, 0, 1, tall + 1)
		end
		return inner
	end
	return c
end
M.Card = card

-- Writes `item` on `tip` (from M.ReadItem); `icon` its picture, `level` its
-- item level. Returns true.
function M.WriteItem(tip, item, icon, level)
	local T, I = BT.UnitTip, M.ITEM
	local c = card(tip)
	local b = c.b
	local spacer, section, tiles, row = c.spacer, c.section, c.tiles, c.row

	-- the name, and what it is, beside its icon: its kind, slot and level, or
	-- for something with no slot what kind of thing it is ("Trade Goods")
	local q = item.quality or ITEM_INK
	level = level or item.level
	local sub = {}
	for _, words in ipairs({ item.kind or false, item.slot or false, level and ("ilvl " .. level) or false }) do
		if words then
			sub[#sub + 1] = words
		end
	end
	if #sub == 0 then
		for _, words in ipairs(item.class or {}) do
			sub[#sub + 1] = words
		end
	end
	c.header(item.name, q, icon, table.concat(sub, " · "), nil, M.UseFigures(item))

	-- how it binds, and what it asks of you
	local tagsHere = {}
	if item.bind then
		local short = M.BindShort(item.bind)
		tagsHere[#tagsHere + 1] = { short or item.bind, "bound", keepCase = short ~= nil }
	end
	if item.unique then
		tagsHere[#tagsHere + 1] = { item.unique, "bound" }
	end
	if #tagsHere > 0 or item.require then
		spacer()
		local need = item.require
		local nr = (need and need.rgb) or ITEM_SUB
		tip:AddDoubleLine(T.TAG_BLANK, need and need.text or " ", 1, 1, 1, nr[1], nr[2], nr[3])
		T.SizeLine(tip, c.last(), T.TAG_LINE, nil, "text")
		T.SizeLine(tip, c.last(), I.SUB, "TextRight", "text")
		T.TagsOnLine(tip, c.last(), tagsHere)
	end

	-- what it does in a fight
	if item.dps or item.damage or item.speed then
		section("Damage")
		-- a wand's hit names its school ("Shadow, a hit"), and the tile keeps
		-- only the numbers
		-- DPS, red, as a spell's is (Josh 2026-10-17: "The dps box should be
		-- red")
		tiles({ { item.dps, "DPS", nil, M.TILE_TINTS.dps },
			{ item.damage, item.school and (item.school .. ", a hit") or "A hit" }, { item.speed, "Speed" } })
		for _, d in ipairs(item.extraDamage) do
			row(d.text, d.rgb)
		end
	end
	if item.armor or item.block then
		section("Armor")
		tiles({ { item.armor, "Armor" }, { item.block, "Block" } })
	end
	if #item.stats > 0 then
		section("Stats")
		for _, s in ipairs(item.stats) do
			row(s.text, s.rgb)
		end
	end
	-- the effects, under what sets each off, in the order they came
	local order, byHead = {}, {}
	for _, e in ipairs(item.effects) do
		if not byHead[e.head] then
			byHead[e.head] = {}
			order[#order + 1] = e.head
		end
		table.insert(byHead[e.head], e)
	end
	for _, head in ipairs(order) do
		section(head)
		for _, e in ipairs(byHead[head]) do
			row(e.text, e.rgb or ITEM_GREEN, nil, nil, true)
		end
	end
	-- whatever else the client said, as it said it
	if #item.rest > 0 then
		spacer()
		for _, r in ipairs(item.rest) do
			row(r.text, r.rgb, r.right, r.rrgb, r.wrap)
		end
	end
	if item.flavour then
		spacer()
		local f = item.flavourRgb or { 1, 0.82, 0 }
		tip:AddLine(item.flavour, f[1], f[2], f[3], true)
		T.SizeLine(tip, c.last(), I.FLAVOUR, nil, "quote")
	end

	-- THE FOOT, AS OPTION A HAD IT (Josh 2026-10-17: "I actually prefer the
	-- durability and vendor price of option A"): a short bar of how worn it
	-- is with the numbers beside it, and what it sells for, on one line; who
	-- made it under them.
	-- THE NUMBERS ARE OURS, BESIDE THE BAR (Josh 2026-10-17: "Durability has
	-- text overlap issues"). The line used to keep room for the bar with a
	-- blank picture as wide as it, and the client drew that picture narrower
	-- than it was asked to, so the bar lay over the first figure. Now the
	-- line keeps no words of its own on the left, and the numbers hang off
	-- the bar's end.
	local footLine, hasBar = nil, false
	if item.durability or item.price then
		spacer()
		local d = item.durability
		hasBar = d ~= nil and d.most ~= nil and d.most > 0
		local worn = " "
		if d then
			worn = hasBar and T.TAG_BLANK or d.text
		end
		tip:AddDoubleLine(worn, item.price and M.Coins(item.price) or " ", ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3],
			ITEM_INK[1], ITEM_INK[2], ITEM_INK[3])
		footLine = c.last()
		T.SizeLine(tip, footLine, I.FOOT, nil, "text")
		T.SizeLine(tip, footLine, I.FOOT, "TextRight", "text")
	end
	if item.maker then
		tip:AddLine(("Made by %s"):format(item.maker), ITEM_MAKER[1], ITEM_MAKER[2], ITEM_MAKER[3])
		T.SizeLine(tip, c.last(), I.MAKER, nil, "text")
	end
	for _, note in ipairs(item.notes) do
		tip:AddLine(note)
	end

	-- as wide as the name and its icon need, and never narrower than three
	-- tiles do; a bolt of cloth with no tiles is let be narrower
	local floor = #c.tileLines > 0 and I.MIN_W or I.PLAIN_W
	local needs = BT.UnitTip.Measure(item.name, I.NAME, "name") + c.off + 24
	-- and its figure at the right of its name
	local figs = M.UseFigures(item)
	if figs then
		needs = needs + BT.UnitTip.Measure(figs[1][1], I.HEADLINE, "text") + I.FIG_GAP
			+ BT.UnitTip.Measure(figs[1][2]:upper(), I.FIG_LABEL, "name") + 12
	end
	-- and the foot, whose left side the client cannot measure: the bar and
	-- its numbers are ours
	if hasBar then
		needs = math.max(needs, I.BAR_W + I.BAR_GAP + BT.UnitTip.Measure(item.durability.text, I.FOOT, "text")
			+ (item.price and BT.UnitTip.Measure(M.Coins(item.price), I.FOOT, "text") or 0) + 24 + I.INSET)
	end
	c.finish(floor, needs)

	if hasBar then
		local fs = T.LineOf(tip, footLine)
		local d = item.durability
		local share = math.max(0, math.min(1, (d.now or 0) / d.most))
		local col = share > 0.5 and { 0.31, 0.78, 0.42 } or share > 0.25 and { 0.89, 0.75, 0.30 } or { 0.89, 0.38, 0.35 }
		if fs then
			b.barBg:ClearAllPoints()
			b.barBg:SetPoint("LEFT", fs, "LEFT", 0, 0)
			b.barBg:SetSize(I.BAR_W, I.BAR_H)
			b.barBg:SetColorTexture(0.12, 0.17, 0.15, 1)
			b.bar:SetWidth(math.max(1, math.floor(I.BAR_W * share + 0.5)))
			b.bar:SetColorTexture(col[1], col[2], col[3], 1)
			b.barBg:Show()
			b.bar:SetShown(share > 0)
			BT.Fonts.Set(b.worn, "text", I.FOOT)
			b.worn:SetText(d.text)
			b.worn:SetTextColor(ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3])
			b.worn:Show()
		end
	end
	return true
end

-- the item's level, for the line under its name: on things you wear only
local function levelOf(tip)
	if not tip.GetItem then
		return nil
	end
	local ok, _, link = pcall(tip.GetItem, tip)
	local text = ok and M.ItemLevelText(link)
	return text and text:match("(%d+)%s*$") or nil
end

-- Rebuilds `tip` from `data` where it can: true when it did, false where the
-- shape is one it leaves to the restyle, "failed" when it broke part way
function M.RebuildItem(tip, data)
	if not (tip and tip.ClearLines and tip.AddLine) then
		return false
	end
	-- a repair's cost is written after us, and an item inside a recipe is a
	-- tooltip of its own: both left as the client draws them
	if (_G.InRepairMode and _G.InRepairMode()) or (type(tip.ItemTooltip) == "table" and tip.ItemTooltip.IsShown
		and tip.ItemTooltip:IsShown()) then
		return false
	end
	local item = M.ReadItem(data, tip.isShopping and true or false)
	if not item then
		return false
	end
	local id = type(data) == "table" and data.id or nil
	item.class = M.ItemClass(id)
	-- THE "EQUIPPED" LABEL OVER A COMPARISON TOOLTIP: the client hides it
	-- whenever the tooltip is cleared (ShoppingTooltipTemplate), and the
	-- rebuild clears it, so it is put back as it was
	local header = type(tip.CompareHeader) == "table" and tip.CompareHeader or nil
	local headed = header and header.IsShown and header:IsShown()
	local ok, err = pcall(M.WriteItem, tip, item, M.ItemIcon(id), levelOf(tip))
	if headed and header.Show then
		pcall(header.Show, header)
	end
	if not ok then
		-- cleared already: the client's lines are gone, so there is nothing
		-- left to restyle in their place
		BT.Err("tooltips.item: " .. tostring(err))
		return "failed"
	end
	return true
end

function M.ComposeItem(tip, data)
	-- an item is not a rare, and it is not a person: whatever edge the last
	-- unit left, goes
	if skins[tip] then
		skins[tip].wantEdge = nil
	end
	if skins[tip] then
		skins[tip].wantTop = nil
		skins[tip].extraBottom = nil
		skins[tip].ours = nil
	end
	-- AN ITEM IS NOT A UNIT. GameTooltip is one frame the whole client shares,
	-- so the floor a unit asked for would sit under the next item tooltip too
	-- and stretch a one-line reagent to two hundred pixels.
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	-- the quality read before anything is cleared: a comparison tooltip
	-- forgets what it is showing when it is (ClearHandlerInfo)
	local r, g, b = itemQuality(tip)
	if not r and type(data) == "table" and type(data.lines) == "table" and type(data.lines[1]) == "table" then
		-- or the colour the client gave its name
		local c = colourOf(data.lines[1].leftColor)
		if c then
			r, g, b = c[1], c[2], c[3]
		end
	end
	local function spine()
		local s = M.Dress(tip, true)
		if s then
			s.accent:SetColorTexture(r or WHITE[1], g or WHITE[2], b or WHITE[3], 0.9)
			s.accent:Show()
			M.LeftBar(s)
		end
	end
	spine()
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
	-- WRITTEN AGAIN IN OPTION C'S SHAPE (M.RebuildItem), or, for a shape that
	-- does not know, its lines in the unit tooltip's style where they are;
	-- then the footnotes quiet
	M.Seen("item", data)
	local rebuilt = M.RebuildItem(tip, data)
	if rebuilt == false then
		M.ItemLines(tip, data)
	else
		-- DRESSED AGAIN AFTER THE REBUILD (Josh 2026-10-17: "Looks like we
		-- lost the left border that indicates item rarity"). The rebuild
		-- clears the tooltip, and a clear takes the spine off (M.DressPlain)
		-- and gives a comparison tooltip the client's own background back
		-- (GameTooltip_ClearStyle).
		spine()
	end
	quietFooter(tip)
	shadowTitle(tip)
	-- before the Show below, which measures the tooltip with it in; a rebuilt
	-- one says its level under its name
	if not rebuilt then
		itemLevel(tip)
	end
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

BT.OnItemTooltip("tooltips", 0, M.ComposeItem)

-- WHAT SWAPPING WOULD CHANGE, AS PART OF THE CARD (Josh 2026-10-17, choosing
-- "Fold the Equipped tooltip's "If you replace this item..." lines into the
-- card"). The client writes those lines after the card is written, so they
-- came out in its own style under ours. Once it has, the line that heads them
-- is set as a heading of the card's, "If replaced", over a rule, and the
-- changes under it at the rows' size, in the colours the client gave them.
M.DELTA_HEAD = "If replaced"
local function isDeltaHead(text)
	if type(text) ~= "string" then
		return false
	end
	for _, key in ipairs({ "ITEM_DELTA_DESCRIPTION", "ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION" }) do
		if type(_G[key]) == "string" and text == _G[key] then
			return true
		end
	end
	return text:find("^If you replace this item") ~= nil
end

-- Folds the stat changes on a comparison tooltip the card was written on;
-- returns the line that heads them, or nil
function M.FoldDelta(tip)
	local b = bitsOf[tip]
	if not (b and tip.NumLines) then
		return nil
	end
	local T, I = BT.UnitTip, M.ITEM
	local n = BT.Pill.Number(tip:NumLines(), 0)
	local head = nil
	for i = 2, n do
		local fs = T.LineOf(tip, i)
		if fs and isDeltaHead(fs:GetText()) then
			head = i
			break
		end
	end
	if not head then
		return nil
	end
	local function blank(text)
		return type(text) ~= "string" or text:find("^%s*$") ~= nil
	end
	local above = T.LineOf(tip, head - 1)
	if above and blank(above:GetText()) then
		T.SizeLine(tip, head - 1, I.SPACER, nil, "text")
	end
	local fs = T.LineOf(tip, head)
	fs:SetText(M.DELTA_HEAD:upper())
	fs:SetTextColor(ITEM_HEAD[1], ITEM_HEAD[2], ITEM_HEAD[3])
	T.SizeLine(tip, head, I.HEAD, nil, "name")
	for i = head + 1, n do
		local line = T.LineOf(tip, i)
		T.SizeLine(tip, i, (line and blank(line:GetText())) and I.SPACER or I.ROW, nil, "text")
	end
	M.composing = true
	pcall(tip.Show, tip)
	M.composing = false
	-- its rule, as wide as the card's others
	if not b.deltaRule then
		b.deltaRule = b.holder:CreateTexture(nil, "ARTWORK")
	end
	local inner = math.max(I.PLAIN_W, BT.Pill.Number(tip.GetWidth and tip:GetWidth(), I.PLAIN_W)) - I.INSET
	b.deltaRule:ClearAllPoints()
	b.deltaRule:SetPoint("BOTTOMLEFT", fs, "TOPLEFT", 0, 3)
	b.deltaRule:SetSize(inner, 1)
	b.deltaRule:SetColorTexture(SKIN_RIM[1], SKIN_RIM[2], SKIN_RIM[3], 0.9)
	b.deltaRule:Show()
	return head
end

if TooltipComparisonManager and TooltipComparisonManager.SetItemTooltip and hooksecurefunc then
	hooksecurefunc(TooltipComparisonManager, "SetItemTooltip", function(self, primary)
		if not BT.Enabled("tooltips") then
			return
		end
		local tips = type(self.tooltip) == "table" and self.tooltip.shoppingTooltips
		local tip = type(tips) == "table" and tips[primary and 1 or 2]
		if tip then
			local ok, err = pcall(M.FoldDelta, tip)
			if not ok then
				BT.Err("tooltips.delta: " .. tostring(err))
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- A SPELL OR A BUFF, WRITTEN AGAIN (Josh 2026-10-17: "Yes, spell and buff
-- tooltips should get the same look")
-- ---------------------------------------------------------------------------
--
--   [icon] the spell's name
--          Rank 3                       a buff's: Magic · 29 min remaining
--   [30 MANA] [35 yd RANGE] [2.5 sec CAST] [8 sec COOLDOWN]
--   Requires Cat Form                   anything else, in the client's colours
--   what it does, in the body's ink
--
-- The client writes a spell's numbers as plain lines in two halves, "30 Mana"
-- on the left and "35 yd range" on the right, with nothing to say which is
-- which. So each half is read by its words. A line with a half that nothing
-- here knows stays a row, as the client wrote it.

-- the client's own sentence as a pattern: its numbers ("%d", "%.3g", "%s")
-- captured, a plural ("|4sec:secs;") any word
local function shape(global, fallback)
	local form = type(_G[global]) == "string" and _G[global] or fallback
	local holes = form:gsub("%%%%", "\2"):gsub("%%[%-%d%.]*[sdfg]", "\1"):gsub("|4[^;]*;", "\3")
	local escaped = holes:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	local pattern = escaped:gsub("\1", "(.-)"):gsub("\2", "%%%%"):gsub("\3", "%%a+")
	return "^" .. pattern .. "$"
end
M.Shape = shape

-- each kind of half: the patterns it is written in, its tile's label, and
-- what follows the number in the tile
M.SPELL_HALVES = {
	{ "Range", { { shape("SPELL_RANGE", "%s yd range"), " yd" } } },
	{ "Cast", { { shape("SPELL_CAST_TIME_SEC", "%s sec cast"), " sec" },
		{ shape("SPELL_CAST_TIME_MIN", "%s min cast"), " min" } } },
	{ "Cooldown", { { shape("SPELL_RECAST_TIME_SEC", "%s sec cooldown"), " sec" },
		{ shape("SPELL_RECAST_TIME_MIN", "%s min cooldown"), " min" },
		{ shape("SPELL_RECAST_TIME_HOURS", "%s hrs cooldown"), " hrs" },
		{ shape("SPELL_RECAST_TIME_DAYS", "%s days cooldown"), " days" } } },
}
-- halves that are a word, not a number
local function spellWords()
	return {
		[_G.SPELL_CAST_TIME_INSTANT or "Instant"] = { "Cast", "Instant" },
		[_G.SPELL_CAST_TIME_INSTANT_NO_MANA or "Instant"] = { "Cast", "Instant" },
		["Instant cast"] = { "Cast", "Instant" },
		[_G.SPELL_CAST_CHANNELED or "Channeled"] = { "Cast", "Channeled" },
		[_G.SPELL_ON_NEXT_SWING or "Next melee"] = { "Cast", "Next melee" },
		[_G.SPELL_ON_NEXT_RANGED or "Next ranged"] = { "Cast", "Next ranged" },
		[_G.MELEE_RANGE or "Melee Range"] = { "Range", "Melee" },
		[_G.SPELL_RANGE_UNLIMITED or "Unlimited range"] = { "Range", "Unlimited" },
	}
end
-- what a spell may cost, in the client's words
local function powerWords()
	local out = {}
	for _, pair in ipairs({ { "MANA", "Mana" }, { "RAGE", "Rage" }, { "ENERGY", "Energy" }, { "FOCUS", "Focus" },
		{ "HEALTH", "Health" }, { "RUNIC_POWER", "Runic Power" }, { "COMBO_POINTS", "Combo Points" } }) do
		local word = type(_G[pair[1]]) == "string" and _G[pair[1]] or pair[2]
		out[word:lower()] = word
		out[pair[2]:lower()] = pair[2]
	end
	return out
end

-- Reads one half of a line: its tile's label and value, or nil
function M.SpellHalf(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local word = spellWords()[text]
	if word then
		return word[1], word[2]
	end
	for _, kind in ipairs(M.SPELL_HALVES) do
		for _, p in ipairs(kind[2]) do
			local n = text:match(p[1])
			if n and n ~= "" then
				return kind[1], n .. p[2]
			end
		end
	end
	-- a cost: "30 Mana", or "12% of base mana"
	local n, what = text:match("^([%d,%.]+)%s+(.+)$")
	local powers = powerWords()
	if n and powers[what:lower()] then
		return powers[what:lower()], n
	end
	n, what = text:match("^([%d%.]+%%) of base (.+)$")
	if n and powers[what:lower()] then
		return powers[what:lower()], n
	end
	return nil
end

-- how long a buff has left, in the client's words ("29 min remaining")
local function isRemaining(text)
	if type(text) ~= "string" then
		return false
	end
	for _, key in ipairs({ "SPELL_TIME_REMAINING_SEC", "SPELL_TIME_REMAINING_MIN", "SPELL_TIME_REMAINING_HOURS",
		"SPELL_TIME_REMAINING_DAYS" }) do
		if type(_G[key]) == "string" and text:find(shape(key, "")) then
			return true
		end
	end
	return text:find(" remaining$") ~= nil
end

-- some words in a colour of their own, inside a line of another
local function hex(rgb, words)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5),
		math.floor(rgb[3] * 255 + 0.5), words)
end

-- the game's gold, which a spell's description is written in
local function isGold(c)
	return c ~= nil and c[1] > 0.95 and c[2] > 0.7 and c[2] < 0.9 and c[3] < 0.2
end

-- a number as the client writes it, its thousands marked ("1,234")
local function number(s)
	return type(s) == "string" and tonumber((s:gsub(",", ""))) or nil
end

-- The client's lines, sorted into what the tooltip shows; nil for a shape
-- this does not know. `kind`: "spell" or "aura". `fresh`: lines fetched,
-- not drawn, so none says which tooltip line it went on; all are shown.
function M.ReadSpell(data, kind, fresh)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	local spell = { tiles = {}, rows = {}, sub = {}, facts = {} }
	local labels = {}
	for _, line in ipairs(data.lines) do
		local shown = type(line) == "table" and (fresh or plainLine(line.lineIndex))
		if shown then
			local k = plainLine(line.type)
			if k ~= nil and (k == LT.NestedBlock or k == LT.LearnableSpell) then
				return nil
			end
			local left, right = plainLine(line.leftText), plainLine(line.rightText)
			left = type(left) == "string" and left ~= "" and left or nil
			right = type(right) == "string" and right ~= "" and right or nil
			local lc, rc = colourOf(line.leftColor), colourOf(line.rightColor)
			if not spell.name then
				if not left then
					return nil
				end
				-- a spell's rank on the right of its name; a debuff's kind
				spell.name, spell.nameRgb = left, lc
				if right then
					spell.sub[#spell.sub + 1] = right
					spell.dispel = kind == "aura" and right or nil
				end
			elseif not (left or right) then
				-- a blank the client spaced with: ours stands in
			elseif (k ~= nil and k == LT.SpellPassive) or left == _G.SPELL_PASSIVE then
				spell.sub[#spell.sub + 1] = left
			elseif kind == "aura" and left and not right and isRemaining(left) then
				spell.remaining = left
			else
				local la, lv = M.SpellHalf(left)
				local ra, rv = M.SpellHalf(right)
				if la and (not right or ra) and not labels[la] and not (ra and labels[ra]) then
					-- RANGE UNDER THE NAME, NOT IN A TILE (Josh 2026-10-17:
					-- ""Range" is not a really important stat"): the tiles go to
					-- what it does and what it costs
					local function add(label, value, c, text)
						labels[label] = true
						if label == "Range" then
							spell.range = value
						else
							local tile = { value, label, (c and not isGold(c) and c[2] < 0.5) and c or nil }
							spell.tiles[#spell.tiles + 1] = tile
							-- and as the client said it, for the line of plain facts
							local fact = { text = text, rgb = tile[3], lower = true }
							spell.facts[#spell.facts + 1] = fact
							if label == "Cast" then
								spell.cast = value
							elseif label ~= "Cooldown" then
								spell.cost = tile
							end
						end
					end
					add(la, lv, lc, left)
					if ra then
						add(ra, rv, rc, right)
					end
				else
					local desc = (k ~= nil and k == LT.SpellDescription) or plainLine(line.wrapText) and true or false
					-- the description in the body's ink, not the game's gold;
					-- anything coloured on purpose (red, green) keeps it
					spell.rows[#spell.rows + 1] = { text = left or " ", rgb = (lc == nil or isGold(lc)) and ITEM_INK or lc,
						right = right, rrgb = rc, wrap = desc or nil, desc = desc }
				end
			end
		end
	end
	if not spell.name then
		return nil
	end
	if spell.range then
		spell.sub[#spell.sub + 1] = spell.range
	end
	-- WHAT IT DOES, AND WHAT THAT COMES TO (Josh 2026-10-17: "It would be
	-- better if we could show damage/healing/absorb", then on a "Damage per
	-- mana" and a dps stat, "Yes, build it"). The amount is read off its
	-- description.
	-- ONLY WHAT IT COMES TO IN THE TILES ("I think the "per mana" and "per
	-- second" stats are actually far more important. Maybe we should only
	-- have those stats in the boxes, the other stats (healing, cast time,
	-- cost, etc) should be moved to plain text at the top"): the amount, the
	-- cost, the cast and the cooldown are a line of plain facts under the
	-- name, and the tiles are the figures worked out from them.
	-- AND WHAT IT TAKES (picked the same day: "Resource spent per second",
	-- "Casts from full mana"), in one row of four: per mana, DPS or HPS
	-- ("I think we can use "HPS" for healing and absorbs per second, and
	-- "DPS" for damage per second. Should save a little room"), mana a
	-- second, and casts from full. Each tile is faintly its own colour: DPS
	-- red, HPS green, and what is about the resource in the resource's
	-- ("The resource related boxes should be colored blue, yellow, or red
	-- (different shade) depending on resource").
	-- A BUFF AS WELL (Josh 2026-10-17, choosing "Give buffs a facts row"):
	-- what it does and how long it has left, in the same cells, and what it
	-- comes to a second where it works over time; it costs nothing, so has
	-- no per mana
	do
		local label, value, amount, over, weapon, after, bonus
		local found = nil
		for _, r in ipairs(spell.rows) do
			label, value, amount, over, weapon, after, bonus = M.SpellAmount(r.text)
			if label then
				found = r
				break
			end
		end
		-- THE MIDDLE, NOT THE RANGE ("To simplify the tooltip, maybe we should
		-- just use an "average" damage number rather than the range... Instead
		-- of 25-32, we'd use 28.5"): the figures were worked out on the middle
		-- already. And how long it lasts, where it works over time, so the
		-- description can go when it says no more than this.
		-- ONLY WHAT IT ADDS, ON YOUR NEXT SWING (Josh 2026-10-17, choosing
		-- "Make Heroic Strike's and Maul's DPS honest"): Heroic Strike and Maul
		-- take the place of a swing you would have made anyway, so what they
		-- do over it is their bonus, "+11 damage", and their DPS and per rage
		-- are worked out on that
		local adds = false
		if bonus and M.IsNextSwing(spell.cast) then
			amount, value, weapon, adds = bonus, "+" .. bonus, false, true
		end
		if label then
			spell.amount = { value, label }
			local said = amount and ((adds and "+" or "") .. M.Middle(amount)) or value
			table.insert(spell.facts, 1, { text = ("%s %s%s%s"):format(said, label:lower(),
				type(over) == "number" and (" over " .. M.Lasting(over)) or "", weapon and " with your weapon" or "") })
			-- A DESCRIPTION THAT SAYS NO MORE GOES (Josh 2026-10-17: "Let's go
			-- with your recommendation for hidin the paragraph descriptions"):
			-- one sentence, and after its amount nothing but how long
			if found.desc and M.SaysNoMore(found.text, after) then
				found.hidden = true
			end
		end
		local cost = spell.cost and number(spell.cost[1])
		local power = spell.cost and spell.cost[2]
		local secs = M.CastSeconds(spell.cast)
		-- a channel's seconds are the ones it says it lasts
		if not secs and spell.cast == (_G.SPELL_CAST_CHANNELED or "Channeled") and type(over) == "number" then
			secs = over
		end
		local gcd = M.GcdFor(power)
		-- DPS OR HPS AT THE TOP RIGHT (Josh 2026-10-17, choosing option B of the
		-- spell tooltip canvas: "if we don't have the boxes like in option A, I
		-- think we can get rid of "Throughput" and move "HPS" or "DPS" down"):
		-- per second of casting, an instant counting the global cooldown; for
		-- one that works over time, per second of the time it lasts ("DoTs
		-- seem to be missing the dps box"): Shadow Word: Pain's 30 over 18 sec
		-- is 1.7
		-- BY WHAT RUNS OUT FIRST (Josh 2026-10-17: "Backstab would have higher
		-- burst, but is is really the best in the course of an entire fight,
		-- given the 15 additional energy cost?", then "Yeah let's build that").
		-- A rogue cannot press an ability every global cooldown: two Sinister
		-- Strikes empty the bar, and then energy coming back is the limit. So
		-- an energy ability's DPS is its damage per energy times the energy
		-- you get back a second (the client's own figure, so talents and
		-- Adrenaline Rush count). A caster can cast every cast, until the mana
		-- runs out, so theirs stays per second of casting.
		-- AND RAGE THE SAME WAY (Josh 2026-10-17: "I dont really like the rage
		-- update... let's add dps back in so warriors and bears have something
		-- to look at"). Rage comes at no steady rate, so it was left without:
		-- per second of the global cooldown it is again, and an ability on
		-- your next swing (Heroic Strike, Maul) per second of the swing.
		local each = nil
		local resource = M.PowerKind(power)
		if not secs then
			secs = M.SwingSeconds(spell.cast)
		end
		if resource == "energy" then
			each = amount and cost and cost > 0 and amount / cost * M.EnergyRegen() or nil
		elseif amount and type(over) == "number" and over > 0 then
			each = amount / over
		elseif amount and secs and not over then
			each = amount / math.max(secs, gcd)
		end
		-- BOTH FIGURES AT THE TOP RIGHT (Josh 2026-10-17: "I'm also not 100%
		-- sold on the healing per mana and casts to empty line... Just go ahead
		-- and build it"): DPS or HPS beside the name, in red or green, and
		-- what it comes to for each point it costs beside the rank, in the
		-- resource's colour ("I think I prefer the old "damage per energy""),
		-- energy's as well as mana's and rage's. The casts to empty are gone
		-- ("I think we should just remove the total number of casts as well...
		-- not really valuable").
		local figs = {}
		if each then
			local word, ink = M.PerSecond(label)
			figs[1] = { M.Figure(each), word, ink }
		end
		if amount and cost and cost > 0 then
			figs[2] = { ("%.2f"):format(math.floor(amount / cost * 100 + 0.5) / 100), "per " .. power:lower(),
				M.FIGURE_INK[resource] or ITEM_INK }
		end
		if figs[1] or figs[2] then
			spell.figs = figs
		end
		if spell.remaining then
			spell.facts[#spell.facts + 1] = { text = spell.remaining }
		end
	end
	return spell
end

-- per second of an amount, as its figure says it: HPS for a heal or an
-- absorb, MPS for mana, DPS for damage; and the colour it is in
function M.PerSecond(label)
	if label == "Healing" or label == "Absorb" then
		return "HPS", M.FIGURE_INK.hps
	elseif label == "Mana" then
		return "MPS", M.FIGURE_INK.mana
	end
	return "DPS", M.FIGURE_INK.dps
end

-- how long, as the line of facts says it: "18 sec", "1 min"
function M.Lasting(secs)
	if secs >= 60 and secs % 60 == 0 then
		return ("%d min"):format(secs / 60)
	end
	return ("%d sec"):format(secs)
end

-- words that say a spell reaches more than its target: a description with
-- one of these says something the line of facts does not. Whole words, so
-- a fiery "ball" is not "all".
M.SCOPE_WORDS = { "yards?", "all", "party", "raid", "nearby", "targets", "enemies", "allies", "up to", "jumps?",
	"chain", "bounces?", "each enemy", "each target" }

-- Whether a description says no more than its amount (and how long): one
-- sentence, nothing after the amount but a length of time, and no word
-- that it reaches anybody else. `after` is the text after its amount.
function M.SaysNoMore(text, after)
	if type(text) ~= "string" or type(after) ~= "string" then
		return false
	end
	-- a second sentence
	if text:find("%.%s+%S") then
		return false
	end
	local lower = text:lower()
	for _, word in ipairs(M.SCOPE_WORDS) do
		if lower:find("%f[%a]" .. word .. "%f[%A]") then
			return false
		end
	end
	-- ("absorbs 47 damage", "47 physical damage"): the word the amount is in
	local rest = after:gsub("^%s*%a*%s*damage%f[%A]", ""):gsub("^%s*%a*%s*over %d+ %a+", "")
		:gsub("^%s*%a*%s*each second for %d+ sec", "")
		:gsub("^%s*%a*%s*every %d+ sec%.? for %d+ sec", "")
	return rest:find("^%s*%.?%s*$") ~= nil
end

-- the global cooldown, which an instant spell still takes; an energy
-- ability's is a second
M.GCD, M.GCD_ENERGY = 1.5, 1.0
function M.GcdFor(power)
	if type(power) == "string" and power:lower() == (_G.ENERGY or "Energy"):lower() then
		return M.GCD_ENERGY
	end
	return M.GCD
end

-- an amount's middle as the line of facts says it: 28.5, or 51 where it is
-- whole
function M.Middle(n)
	n = M.Tenths(n)
	if n == math.floor(n) then
		return ("%d"):format(n)
	end
	return ("%.1f"):format(n)
end

-- to the nearest tenth, a half always up (the C library's own rounding of
-- "%.1f" sends an exact half to the even tenth: 95.25 to 95.2)
function M.Tenths(n)
	return math.floor(n * 10 + 0.5) / 10
end

-- a worked-out figure as a tile shows it: one place under a hundred
function M.Figure(n)
	if n < 100 then
		return ("%.1f"):format(M.Tenths(n))
	end
	return ("%d"):format(math.floor(n + 0.5))
end

-- a figure's own colour at the top right of a spell
M.FIGURE_INK = {
	dps = { 1.00, 0.54, 0.48 }, hps = { 0.50, 0.91, 0.60 },
	mana = { 0.56, 0.71, 1.00 }, energy = { 1.00, 0.88, 0.48 }, rage = { 1.00, 0.44, 0.53 },
}

-- the faint colour behind a tile
M.TILE_TINTS = {
	dps = { 1.00, 0.32, 0.24 }, hps = { 0.30, 0.85, 0.42 },
	mana = { 0.30, 0.55, 1.00 }, energy = { 1.00, 0.84, 0.22 }, rage = { 0.72, 0.10, 0.18 },
}
-- the resource's, by the word the client wrote its cost in, or nil
-- which of mana, energy and rage the word the client wrote a cost in is,
-- or nil
function M.PowerKind(power)
	if type(power) ~= "string" then
		return nil
	end
	local word = power:lower()
	for key, global in pairs({ mana = "MANA", energy = "ENERGY", rage = "RAGE" }) do
		if word == key or word == (type(_G[global]) == "string" and _G[global]:lower()) then
			return key
		end
	end
	return nil
end

-- whether an ability lands on your next swing ("Next melee", "Next ranged")
function M.IsNextSwing(cast)
	return cast ~= nil and (cast == (_G.SPELL_ON_NEXT_SWING or "Next melee") or cast == (_G.SPELL_ON_NEXT_RANGED or "Next ranged"))
end

-- the seconds of your swing, for an ability on your next one ("Next melee",
-- "Next ranged"); nil for anything else or a speed the client will not say
function M.SwingSeconds(cast)
	local ranged = cast == (_G.SPELL_ON_NEXT_RANGED or "Next ranged")
	if not M.IsNextSwing(cast) then
		return nil
	end
	local fn = ranged and _G.UnitRangedDamage or _G.UnitAttackSpeed
	if type(fn) ~= "function" then
		return nil
	end
	local ok, speed = pcall(fn, "player")
	speed = ok and plainLine(speed) or nil
	return type(speed) == "number" and speed > 0 and speed or nil
end

-- the energy you get back a second: the client's own figure while energy
-- is what you use, the game's usual 10 otherwise (a warrior reading a
-- linked Sinister Strike)
M.ENERGY_REGEN = 10
local function usesEnergy()
	local energy = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3
	if type(UnitPowerType) ~= "function" then
		return nil
	end
	local ok, kind = pcall(UnitPowerType, "player")
	return ok and plainLine(kind) == energy and energy or nil
end
function M.EnergyRegen()
	if usesEnergy() and type(GetPowerRegen) == "function" then
		local ok, _, active = pcall(GetPowerRegen)
		active = ok and plainLine(active) or nil
		if type(active) == "number" and active > 0 then
			return active
		end
	end
	return M.ENERGY_REGEN
end
-- a cast tile's value in seconds ("2.5 sec", "Instant"), or nil for one
-- that is not a time (Channeled, Next melee)
function M.CastSeconds(value)
	if type(value) ~= "string" then
		return nil
	end
	if value == "Instant" then
		return 0
	end
	local n, unit = value:match("^([%d%.]+) (%a+)$")
	n = tonumber(n)
	if not n then
		return nil
	end
	return unit == "min" and n * 60 or n
end

-- WHAT A SPELL DOES, IN NUMBERS: the client says it only in its description,
-- in words ("absorbing 47 damage", "causes 56 to 73 Fire damage", "Heals 66
-- damage over 6 sec"). Read in this order, because an absorb and a heal are
-- also written with the word "damage". Each is a pattern with the amount, or
-- the lowest and the highest, in its captures.
M.AMOUNTS = {
	{ "Absorb", { "[Aa]bsorbing ([%d,]+)", "[Aa]bsorbs? ([%d,]+)" } },
	{ "Healing", { "[Hh]eal[sing]* [^%.]-for ([%d,]+) to ([%d,]+)", "[Hh]eal[sing]* [^%.]-for ([%d,]+)",
		"[Hh]eals? ([%d,]+)", "[Rr]estores ([%d,]+) to ([%d,]+) health", "[Rr]estores ([%d,]+) health" } },
	-- a drink, or a mana potion
	{ "Mana", { "[Rr]estores ([%d,]+) to ([%d,]+) mana", "[Rr]estores ([%d,]+) mana" } },
	{ "Damage", { "([%d,]+) to ([%d,]+) [%a ]-damage", "([%d,]+) %a* ?damage" } },
}

-- A MELEE OR RANGED ABILITY ADDS TO YOUR WEAPON (Josh 2026-10-17, picking
-- "Count weapon damage"). "Causes 3 damage in addition to your normal weapon
-- damage" is the weapon's hit and 3, so the weapon's own damage - the
-- character sheet's, from UnitDamage - is added in; without it a Sinister
-- Strike's per energy was worked out on 3. Read before the spells' patterns,
-- which would take the 3 alone. Each: the pattern, and what it adds to -
-- "plus" the weapon and the number, "share" a share of the weapon and the
-- number, "weapon" the weapon alone.
M.WEAPON_AMOUNTS = {
	{ "([%d,]+) damage in addition to your normal weapon damage", "plus" },
	{ "([%d,]+)%% weapon damage plus ([%d,]+)", "share" },
	{ "weapon damage plus ([%d,]+)", "plus" },
	{ "[Ii]ncreases ranged damage by ([%d,]+)", "plus", ranged = true },
	{ "[Ii]ncreases melee damage by ([%d,]+)", "plus" },
	{ "[Nn]ext attack by ([%d,]+) damage", "plus" },
	{ "([%d,]+)%% weapon damage", "share" },
	{ "causing weapon damage", "weapon" },
	{ "deals weapon damage", "weapon" },
}

-- your weapon's lowest and highest hit, as the character sheet says them;
-- nil where the client will not say
function M.WeaponDamage(ranged)
	local fn = ranged and _G.UnitRangedDamage or _G.UnitDamage
	if type(fn) ~= "function" then
		return nil
	end
	local said = { pcall(fn, "player") }
	if not said[1] then
		return nil
	end
	-- the ranged one says its speed first
	local lo, hi = plainLine(said[ranged and 3 or 2]), plainLine(said[ranged and 4 or 3])
	if type(lo) ~= "number" or type(hi) ~= "number" or hi <= 0 then
		return nil
	end
	return lo, hi
end

local function weaponAmount(text)
	for _, w in ipairs(M.WEAPON_AMOUNTS) do
		local _, last, a, b = text:find(w[1])
		if last then
			local share, plus = 1, 0
			if w[2] == "plus" then
				plus = number(a) or 0
			elseif w[2] == "share" then
				share, plus = (number(a) or 100) / 100, b and number(b) or 0
			end
			-- what it adds to a whole hit of the weapon, for an ability that takes
			-- the place of a swing (M.ReadSpell)
			local bonus = (share == 1 and plus > 0) and plus or nil
			local lo, hi = M.WeaponDamage(w.ranged)
			if not lo then
				-- the weapon unknown: what it adds, and no figures
				return "Damage", plus > 0 and ("+" .. plus) or "weapon", nil, false, false, text:sub(last + 1), bonus
			end
			-- the range in whole numbers, the middle from the weapon's own
			-- (Josh 2026-10-17: "Are we using real spell calculations? Like
			-- backstab says it does 150% weapon damage plus 30"): the middle of
			-- the rounded ends was up to half a point under the sum
			local l, h = math.floor(lo * share + plus), math.floor(hi * share + plus + 0.5)
			return "Damage", l == h and tostring(l) or (l .. "–" .. h), (lo + hi) / 2 * share + plus, false, true,
				text:sub(last + 1), bonus
		end
	end
	return nil
end

-- Reads what a description does: its tile's label and value ("56–73"), the
-- amount in one number (the middle of a range), whether it works over time
-- (for how many seconds, where it says, or true), whether your weapon's
-- damage is in it, what follows the amount, and what it adds to a plain
-- hit of the weapon where that is a number. Nil where it says no amount.
-- An amount each second, or every few, for so long is the whole of it: "26
-- Arcane damage each second for 3 sec" is 78.
function M.SpellAmount(text)
	if type(text) ~= "string" then
		return nil
	end
	local wl, wv, wa, wo, ww, wafter, wbonus = weaponAmount(text)
	if wl then
		return wl, wv, wa, wo, ww, wafter, wbonus
	end
	for _, kind in ipairs(M.AMOUNTS) do
		for _, p in ipairs(kind[2]) do
			local _, last, lo, hi = text:find(p)
			if lo then
				local after = text:sub(last + 1)
				-- how many times it lands, and for how long, where the words say
				local times, lasts = 1, nil
				local each = after:match("^%s*%a*%s*each second for (%d+) sec")
				if each then
					times, lasts = tonumber(each), tonumber(each)
				else
					local every, long = after:match("^%s*%a*%s*every (%d+) sec%.? for (%d+) sec")
					if every and tonumber(every) > 0 then
						times, lasts = math.floor(tonumber(long) / tonumber(every)), tonumber(long)
					end
				end
				if not lasts then
					local n, unit = after:match("^%s*%a*%s*over (%d+) (%a+)")
					if n then
						lasts = tonumber(n) * (unit:find("^min") and 60 or 1)
					end
				end
				-- over time: for how many seconds, or only that it is
				local over = lasts or (times > 1 or after:find("^%s*%a*%s*each second") ~= nil
					or after:find("^%s*%a*%s*every ") ~= nil)
				local a, b = number(lo), hi and number(hi)
				if not (a and (not hi or b)) then
					return nil
				end
				local value
				if times > 1 then
					value = b and (a * times .. "–" .. b * times) or tostring(a * times)
				else
					value = (hi and hi ~= lo) and (lo .. "–" .. hi) or lo
				end
				return kind[1], value, ((a + (b or a)) / 2) * times, over, false, after
			end
		end
	end
	return nil
end

-- a spell's icon, by its id
function M.SpellIcon(id)
	id = plainLine(id)
	if type(id) ~= "number" then
		return nil
	end
	for _, fn in ipairs({ C_Spell and C_Spell.GetSpellTexture or false, _G.GetSpellTexture or false }) do
		if fn then
			local ok, icon = pcall(fn, id)
			if ok and icon and not (issecretvalue and issecretvalue(icon)) then
				return icon
			end
		end
	end
	return nil
end

-- a spell's icon, by its name (a macro's tooltip, whose id is the macro's)
function M.SpellIconByName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, name)
		local icon = ok and type(info) == "table" and plainLine(info.iconID) or nil
		if icon then
			return icon
		end
	end
	if _G.GetSpellTexture then
		local ok, icon = pcall(_G.GetSpellTexture, name)
		if ok and icon and not (issecretvalue and issecretvalue(icon)) then
			return icon
		end
	end
	return nil
end

-- the spell a tooltip is showing: its data's id, or the tooltip's answer
local function spellOf(tip, data)
	local id = plainLine(type(data) == "table" and data.id or nil)
	if type(id) == "number" then
		return id
	end
	if tip.GetSpell then
		local ok, _, found = pcall(tip.GetSpell, tip)
		found = ok and plainLine(found) or nil
		if type(found) == "number" then
			return found
		end
	end
	return nil
end

-- the spine and the icon's edge: the theme's accent, or a debuff's own
-- colour (blue magic, purple curse) where the client names its kind
local function spellColour(spell)
	local d = spell and spell.dispel and _G.DebuffTypeColor and _G.DebuffTypeColor[spell.dispel]
	if type(d) == "table" and type(d.r) == "number" then
		return { d.r, d.g, d.b }
	end
	local a = BT.Widgets.ACCENT
	return { a[1], a[2], a[3] }
end

-- Writes `spell` on `tip` (from M.ReadSpell). Returns true.
function M.WriteSpell(tip, spell, icon)
	local I = M.ITEM
	local c = card(tip)
	c.header(spell.name, spell.nameRgb or ITEM_INK, icon, table.concat(spell.sub, " · "), spellColour(spell),
		spell.figs)
	-- as wide as the name and the line under it, each with its figure, need
	local Measure = BT.UnitTip.Measure
	local floor = spell.figs and I.MIN_W or I.PLAIN_W
	local needs = Measure(spell.name, I.NAME, "name") + c.off + 24
	if spell.figs then
		local function fig(i, size)
			local f = spell.figs[i]
			return f and (Measure(f[1], size, "text") + I.FIG_GAP + Measure(f[2]:upper(), I.FIG_LABEL, "name")) or 0
		end
		needs = math.max(Measure(spell.name, I.NAME, "name") + fig(1, I.HEADLINE),
			Measure(table.concat(spell.sub, " · "), I.SUB, "text") + fig(2, I.FIG_SMALL)) + c.off + 24 + 12
	end
	needs = math.min(MAX_W, needs)
	-- the plain facts - what it does, what it costs, how long it takes - in
	-- cells, their numbers brighter than their words, a cost you cannot pay
	-- in the client's red, in rows as wide as the card
	if #spell.facts > 0 then
		local items = {}
		for _, f in ipairs(spell.facts) do
			local words = f.text
			if f.lower then
				words = words:lower()
			end
			local shown = words
			if f.rgb then
				shown = hex(f.rgb, words)
			else
				local n, rest = words:match("^(%+?[%d%.,–]+)(.*)$")
				if n then
					shown = hex(ITEM_INK, n) .. rest
				end
			end
			items[#items + 1] = { shown, words }
		end
		c.spacer()
		c.cells(items, math.max(floor, needs) - I.INSET)
	end
	-- what it asks of you, then what it does, then anything after: each run
	-- with a little room before it; a description that says no more than
	-- the line of facts is left out
	local was = nil
	for _, r in ipairs(spell.rows) do
		if not r.hidden then
			if r.desc ~= was then
				c.spacer()
				was = r.desc
			end
			-- what it does, beyond the figures, a little smaller and quieter
			-- than they are
			c.row(r.text, r.desc and ITEM_QUIET or r.rgb, r.right, r.rrgb, r.wrap)
			if r.desc then
				BT.UnitTip.SizeLine(tip, c.last(), I.QUIET, nil, "text")
			end
		end
	end
	c.finish(floor, needs)
	return true
end

-- WHAT THE CLIENT WROTE, FOR CLAUDE (the Testing page's Record button). The
-- spell and buff tooltips were built from the client's strings without one
-- in hand, so the last few of each kind are kept as they came, and written
-- into the saved file on Record.
M.SEEN_MOST = 6
M.seen = { item = {}, spell = {}, aura = {}, macro = {} }
function M.Seen(kind, data)
	local list = M.seen[kind]
	if not (list and type(data) == "table" and type(data.lines) == "table") then
		return
	end
	local first = type(data.lines[1]) == "table" and plainLine(data.lines[1].leftText) or nil
	for i = #list, 1, -1 do
		if list[i].first == first then
			table.remove(list, i)
		end
	end
	table.insert(list, 1, { first = first, data = data })
	while #list > M.SEEN_MOST do
		table.remove(list)
	end
end

function M.Dump()
	local out = { at = U.Now(), build = (GetBuildInfo and select(1, GetBuildInfo())) or "?" }
	local n = 0
	for kind, list in pairs(M.seen) do
		out[kind] = {}
		for _, seen in ipairs(list) do
			local lines = {}
			for _, line in ipairs(seen.data.lines) do
				if type(line) == "table" then
					lines[#lines + 1] = {
						type = plainLine(line.type), shown = plainLine(line.lineIndex),
						-- what a macro's line names, where it names something
						tooltipType = plainLine(line.tooltipType), tooltipID = plainLine(line.tooltipID),
						left = plainLine(line.leftText), right = plainLine(line.rightText),
						leftColor = colourOf(line.leftColor), rightColor = colourOf(line.rightColor),
						wrap = plainLine(line.wrapText),
					}
				end
			end
			out[kind][#out[kind] + 1] = { id = plainLine(seen.data.id), type = plainLine(seen.data.type), lines = lines }
			n = n + 1
		end
	end
	BT.EnsureBound()
	BeebModDB.tooltipsDump = out
	return n
end
BT.Record("tooltipsDump", M.Dump, "tooltips")

function M.ComposeSpell(tip, data, kind)
	-- whatever a unit left on the tooltip goes, as for an item
	local s = skins[tip]
	if s then
		s.wantEdge, s.wantTop, s.extraBottom, s.ours = nil, nil, nil, nil
	end
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	M.Seen(kind, data)
	-- A MACRO SHOWING A SPELL is written as the spell; one showing an item,
	-- or only its own name, is left as the client drew it. Its data's id is
	-- the macro's, not the spell's, so its picture is found by the spell's
	-- name.
	-- NAMED, NOT WRITTEN (Josh 2026-10-17: "The macro tooltip #showtooltip is
	-- still not using our tooltip"): the client's data for a macro may only
	-- name what it shows, as its first line's tooltipType and tooltipID; a
	-- spell named so is read from the spell's own tooltip, whose lines say
	-- nothing of where they were drawn (`fresh`)
	local byName, fresh, id = false, false, nil
	if kind == "macro" then
		local LT = (Enum and Enum.TooltipDataLineType) or {}
		local DT = (Enum and Enum.TooltipDataType) or {}
		local lines = type(data) == "table" and type(data.lines) == "table" and data.lines or {}
		local head = type(lines[1]) == "table" and lines[1] or {}
		local namedType, namedID = plainLine(head.tooltipType), plainLine(head.tooltipID)
		local first = plainLine(head.type)
		if namedType ~= nil and DT.Spell ~= nil and namedType == DT.Spell and type(namedID) == "number"
			and C_TooltipInfo and C_TooltipInfo.GetSpellByID then
			local ok, own = pcall(C_TooltipInfo.GetSpellByID, namedID)
			if not (ok and type(own) == "table") then
				return
			end
			data, fresh, id = own, true, namedID
		elseif (namedType ~= nil and namedType ~= DT.Spell) or #lines < 2 or (first ~= nil and first == LT.ItemName) then
			-- an item, or only the macro's own name: the client's
			return
		else
			byName = true
		end
		kind = "spell"
	end
	local spell = M.ReadSpell(data, kind, fresh)
	if spell and tip.ClearLines and tip.AddLine then
		local icon = (id and M.SpellIcon(id)) or (byName and M.SpellIconByName(spell.name))
			or M.SpellIcon(spellOf(tip, data))
		local ok, err = pcall(M.WriteSpell, tip, spell, icon)
		if not ok then
			BT.Err("tooltips.spell: " .. tostring(err))
		end
	end
	-- dressed after the rebuild: its clearing took the spine off
	s = M.Dress(tip, true)
	if s then
		local a = spellColour(spell)
		s.accent:SetColorTexture(a[1], a[2], a[3], 0.9)
		s.accent:Show()
		M.LeftBar(s)
	end
	quietFooter(tip)
	shadowTitle(tip)
	if tip.Show then
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
	end
	repad(tip, skins[tip], true)
end

BT.OnSpellTooltip("tooltips", 0, M.ComposeSpell)

function M:OnEnable()
	M.Dress(GameTooltip)
	-- some of these are created by the client the first time they are needed,
	-- so this is worth another go whenever the module comes back on (a slice
	-- a frame: this runs on every loading screen, see M.HookOthers)
	M.HookOthers(false, true)
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
		if BT.Enabled("tooltips") then
			rememberBar(bar)
			if bar.SetHeight then
				bar:SetHeight(1)
			end
			bar:Hide()
		end
	end)
end

BT.OnUnitTooltip("tooltips", 0, M.Compose)

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
		-- NOT OUR OWN FRAMES (Josh 2026-10-17: "The compare tooltip is broken.
		-- Looks like the content is under the background?"). The tags and the
		-- item's tiles sit on frames of ours over the whole tooltip, with words
		-- and art on them: taken for the tab, each was given a surface, and
		-- that surface lay over every line the client wrote.
		if holder.GetRegions and not holder.beebs then
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
			BT.Err("tooltips.header: " .. tostring(err))
		end
	end
end

local function dressOther(tip)
	if not (tip and BT.Enabled("tooltips")) then
		return
	end
	dressHeader(tip)
	if skins[tip] then
		skins[tip].wantEdge = nil
	end
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
	quietFooter(tip)
	shadowTitle(tip)
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
-- and the reason is on What loaded, rather than taking the panel down with it.
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
--
-- A SLICE A FRAME AFTER A LOADING SCREEN TOO (Josh 2026-09-30, review). The
-- module comes on again with every loading screen, and a panel loaded the
-- first time it opens sets off the watcher below: each walked every frame in
-- the game in one go, a hitch half a second after the screen came up or the
-- auction house opened. With `sliced` the same walk is spread over frames.
-- Only the walk at load, before anything is on screen, is done at once.
local lastSweep = 0
function M.HookOthers(cheap, sliced)
	for _, name in ipairs(OTHER_TOOLTIPS) do
		hook(_G[name], name)
	end
	local now = U.Now()
	if not cheap then
		lastSweep = now
		if sliced then
			M.SweepSoon()
		else
			M.SweepTooltips()
		end
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
		if not BT.Enabled("tooltips") or queued then
			return
		end
		if C_Timer and C_Timer.After then
			queued = true
			C_Timer.After(0.5, function()
				queued = false
				if BT.Enabled("tooltips") then
					M.HookOthers(false, true)
				end
			end)
		else
			M.HookOthers(false, true)
		end
	end)
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
		if BT.Enabled("tooltips") then
			-- an error here comes out of whatever was writing the tooltip
			local ok, err = pcall(M.DressPlain, tip)
			if not ok then
				BT.Err("tooltips.cleared: " .. tostring(err))
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
		if BT.Enabled("tooltips") then
			local ok, err = pcall(shown, tip)
			if not ok then
				BT.Err("tooltips.shown: " .. tostring(err))
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
-- OFF STAYS OFF (Josh 2026-09-30, review). Painting the plain edge back
-- shows our fill and rim, so with the module switched off every hover put
-- them back under the client's own border. What the unit asked for is still
-- forgotten; only the painting waits for the module to be on.
function M.UnitTooltipHidden()
	local s = skins[GameTooltip]
	if s then
		s.accent:Hide()
		if s.crest then
			s.crest:Hide()
		end
		s.wantEdge = nil
		s.wantTop = nil
		s.extraBottom = nil
		s.ours = nil
		if BT.Enabled("tooltips") then
			applyEdge(GameTooltip, s)
		end
	end
end
BT.OnUnitTooltipHide(M.UnitTooltipHidden)

