-- Tooltips: unit, item, spell and buff tooltips in BeebMod's own layout
-- (Josh 2026-09-19; the unit tooltip as tags and rows, and items, spells and
-- buffs as cards, 2026-10-17).
--
-- The default unit tooltip spends a line each on the level, the race, the
-- class, the faction and an instruction about right-clicking, then hangs a
-- health bar under the lot. Pointing at somebody should cost a glance, not a
-- paragraph, and on a 1080-tall screen that box is a surprising amount of the
-- corner you were trying to look at.
--
--   Beeb Magus                8        name, in class colour, level on the right
--   [Gnome] [PvP]                      tags: race or type, and states
--   <Nightwatch>                       guild or job, in the guild green
--
-- WHAT IT KEEPS. Everything you would actually act on: who, how tough, what
-- they are, who they run with. What it drops: the word "(Player)", the faction
-- you can already see on the nameplate unless it is the OTHER one, the
-- right-click instruction, and the client's health bar (a thin line of
-- BeebMod's own takes its place). None of them is a switch any more (the
-- settings canvas, Josh 2026-10-04).
--
-- It rebuilds rather than hides: ClearLines and start again is the only way to
-- make the tooltip actually SHRINK. Blanking lines leaves their height behind,
-- which is a smaller tooltip with holes in it rather than a compact one.
local _, BT = ...
local CreateFrame, C_Timer, hooksecurefunc = BT.Cpu.For("Modules/Tooltips/Tooltips.lua")

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

local DIM = BT.TEXT.quiet

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
-- A CARD'S NAME NEVER WRAPS (Josh 2026-11-09: "Overlapping text"): Edged
-- Bastard Sword of the Monkey and its DPS beside it needed a little more than
-- MAX_W, so the name ran under the figure. A card's header asks for what it
-- needs, up to this.
local HEAD_MAX_W = 420
M.HEAD_MAX_W = HEAD_MAX_W

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
-- the last edge read, and whose (M.Compose)
M.lastEdge = { guid = nil, edge = nil }

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
M.DEAD_INK = BT.TEXT.muted

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

local QUEST_TITLE = BT.TEXT.goldSoft
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
		-- a line the client keeps secret is not compared with anything
		if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
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
-- NOT FOR OUR OWN CLEAR (2026-10-17, audit). A rebuild clears the tooltip
-- too, and its clear set off this and M.UnitTooltipHidden again, each with
-- its own repaint of the edge, while the rebuild dresses the tooltip itself
-- straight after. M.clearing says the clear is ours (M.ClearLines).
function M.ClearLines(tip)
	M.clearing = true
	local ok, err = pcall(tip.ClearLines, tip)
	M.clearing = false
	if not ok then
		error(err, 0)
	end
end

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
	-- else about the tooltip changed; the plain edge is painted in it
	M.Dress(tip, true)
	return s
end

-- THE LOG READ ONCE (2026-10-17, audit): every quest's title, kept until the
-- log changes. A unit's tooltip is written again several times a second
-- while you point at it, and each time it walked the whole quest log.
local questTitles = nil
-- and the item objectives still open, the same way (M.WithItemQuests)
local itemObjectives = nil
function M.ForgetQuests()
	questTitles = nil
	itemObjectives = nil
end
if CreateFrame then
	M.questWatch = CreateFrame("Frame")
	pcall(M.questWatch.RegisterEvent, M.questWatch, "QUEST_LOG_UPDATE")
	M.questWatch:SetScript("OnEvent", M.ForgetQuests)
end

-- a value the client handed over, where it may be read
local function known(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then
		return nil
	end
	return v
end

-- an objective's words, its count and whether it is done; `done` is the
-- client's own word where it gave one
local function objective(trimmed, done)
	-- with or without the client's leading dash
	local body = trimmed:match("^%-%s*(.+)$") or trimmed
	local words, have, need = BT.Quests.SplitObjective(body)
	if done == nil then
		done = (have and need and have >= need) or false
	end
	return { text = words, have = have, need = need, done = done }
end

-- ONLY YOURS (Josh 2026-11-10: "in dungeons it is used for every group
-- member's quest objectives, which reads quite spammy"). In a group the
-- client writes, under a quest's name, your objectives and then each other
-- member's: their name on a line, their objectives under it. The data the
-- client draws the tooltip from says which line is which (TooltipDataLineType
-- QuestTitle, QuestPlayer, QuestObjective), so the rows are read from it
-- where it has them. A member's name and objectives are used up, so they
-- don't come back as small print. Returns nil where the data has no quest
-- lines; then the words are read instead (questBlock).
function M.TypedQuests(data)
	local lines = type(data) == "table" and type(data.lines) == "table" and data.lines or nil
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	if not (lines and LT.QuestTitle and LT.QuestObjective) then
		return nil
	end
	local any = false
	for _, line in ipairs(lines) do
		local kind = type(line) == "table" and known(line.type) or nil
		if kind ~= nil and (kind == LT.QuestTitle or kind == LT.QuestObjective) then
			any = true
			break
		end
	end
	if not any then
		return nil
	end
	local out, used, mine = nil, {}, true
	for _, line in ipairs(lines) do
		local kind = type(line) == "table" and known(line.type) or nil
		local text = type(line) == "table" and known(line.leftText) or nil
		local trimmed = type(text) == "string" and text:match("^%s*(.-)%s*$") or nil
		if trimmed == "" then
			trimmed = nil
		end
		if kind == nil then
			-- nothing to go by
		elseif kind == LT.QuestTitle then
			mine = true
			if trimmed then
				out = out or {}
				out[#out + 1] = { text = trimmed, title = true }
				used[trimmed] = true
			end
		elseif LT.QuestPlayer and kind == LT.QuestPlayer then
			mine = false
			if trimmed then
				used[trimmed] = true
			end
		elseif kind == LT.QuestObjective and trimmed then
			used[trimmed] = true
			if mine then
				local done = known(line.completed)
				out = out or {}
				out[#out + 1] = objective(trimmed, type(done) == "boolean" and (done or nil) or nil)
			end
		end
	end
	return out, used
end

-- the others in your group, by name: whose objectives are not yours
function M.GroupNames()
	local names = {}
	local n = GetNumGroupMembers and known(GetNumGroupMembers()) or 0
	if type(n) ~= "number" or n <= 0 or not UnitName then
		return names
	end
	local me = known(UnitName("player"))
	local raid = IsInRaid and IsInRaid()
	for i = 1, raid and 40 or 4 do
		local unit = (raid and "raid" or "party") .. i
		local name = (not UnitExists or UnitExists(unit)) and known(UnitName(unit)) or nil
		if type(name) == "string" and name ~= "" and name ~= me then
			names[name] = true
		end
	end
	return names
end

-- Returns the block, and the set of raw lines it used up so the sweep above
-- does not carry them over a second time. `spoken` is what the tooltip says
-- for the unit itself (M.Identity).
--
-- NOT THE NPC'S OWN TITLE (Josh 2026-11-10, Protector Dorana: her "Level
-- 30", "Stormwind" and "PvP" were quest rows). Her title line reads "The
-- People's Militia", which is also the name of a Westfall quest in the log,
-- so every line under it was read as an objective. A line the tooltip already
-- says for the unit never begins a quest.
local function questBlock(tip, spoken)
	local used = {}
	if not (tip.NumLines and BT.Quests and BT.Quests.Watched) then
		return nil, used
	end
	local typed, typedUsed = M.TypedQuests(BT.UnitTip and BT.UnitTip.data)
	if typedUsed then
		return typed, typedUsed
	end
	-- every quest in the log, not only the followed ones: a mob can count
	-- towards one you are not tracking, and the client still says so
	if not questTitles then
		local ok, all = pcall(BT.Quests.All)
		if not (ok and all) then
			return nil, used
		end
		questTitles = {}
		for _, title in ipairs(all) do
			questTitles[title] = true
		end
	end
	local titles = questTitles
	if not next(titles) then
		return nil, used
	end
	local others = M.GroupNames()
	-- inBlock: false, "mine", or "theirs" under a group member's name
	local out, inBlock = nil, false
	for i = 2, BT.Pill.Number(tip:NumLines(), 0) do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and fs:GetText()
		-- a line the client keeps secret is read as no line
		if issecretvalue and issecretvalue(text) then
			text = nil
		end
		-- THE THREAT LINE ENDS IT TOO (Josh 2026-11-07: "Threat is showing in
		-- the quest highlight"). In a fight the client writes "100% Threat"
		-- under the quest lines, and it was read as one more objective. No
		-- objective begins with a percentage.
		local chrome = type(text) == "string" and text:match("^%s*%d+%%") ~= nil
		if type(text) == "string" and not chrome then
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
			if spoken and spoken[trimmed] then
				inBlock = false
			elseif titles[trimmed] then
				out = out or {}
				out[#out + 1] = { text = trimmed, title = true }
				used[trimmed] = true
				inBlock = "mine"
			elseif inBlock and others[trimmed] then
				used[trimmed] = true
				inBlock = "theirs"
			elseif inBlock then
				used[trimmed] = true
				if inBlock == "mine" then
					out[#out + 1] = objective(trimmed)
				end
			end
		end
	end
	return out, used
end
M.QuestBlock = questBlock

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
-- each objective led by a mark, its count on the right, green once it is
-- done. The quest's own name only when there is more than one quest to tell
-- apart, with its objectives under it.
-- A BOX, TICKED WHEN DONE (Josh 2026-11-10: the "!" "makes it look like the
-- NPC has a quest"; he chose the box). An objective is an empty box in gold,
-- and a ticked box in green once done. A quest's name has no mark: a box
-- before it would read as one more thing to do.
-- THE NAME AT THE EDGE, ITS OBJECTIVES UNDER IT (Josh 2026-11-10: "Maybe the
-- quest name should be left aligned, and the objectives should be indented
-- under them? Also quest name should be slightly larger or a different
-- color"). With two quests or more, a name starts at the rows' left edge, a
-- size up from its objectives, in gold; its objectives are set in by
-- M.QUEST_INDENT, white. One quest has no name, so its objectives are not set
-- in.
M.QUEST_TITLE_SIZE = 13
M.QUEST_INDENT = 8
--
-- LARGER, ON A BAND OF GOLD (Josh 2026-11-07: "Are we able to highlight or
-- make larger the quest part of tooltips? It still blends in a bit too
-- much... that is the primary thing I am looking for on these"). The rows
-- are a size and a half up from the others, and a faint gold band lies
-- behind them from the tooltip's left to its right.
M.QUEST_SIZE = 12
M.BAND_INK = { 1.00, 0.82, 0.25, 0.10 }
-- how far the band reaches left of the words and in from the right edge
M.BAND_LEFT, M.BAND_RIGHT = 4, 2

-- A BAND A LINE, TILED. A texture can't take its top from one line and its
-- right from the tooltip, so each line has its own: its left from the line,
-- its right from the tooltip, as the kills rule is laid. The client leaves
-- 2 pixels between lines; each band covers its line and 1 above and below,
-- so they meet. The first and the last reach 2 further, for air.
function M.QuestBand(tip, lines)
	local pool = tip and tip.beebsQuestBands
	if pool then
		for _, b in ipairs(pool) do
			b:Hide()
		end
	end
	if not (tip and tip.CreateTexture and lines and #lines > 0) then
		return 0
	end
	if not pool then
		pool = {}
		tip.beebsQuestBands = pool
	end
	local shown = 0
	for n, i in ipairs(lines) do
		local fs = BT.UnitTip.LineOf(tip, i)
		if fs then
			local b = pool[n]
			if not b then
				local ok, made = pcall(tip.CreateTexture, tip, nil, "BACKGROUND", nil, 3)
				if not (ok and type(made) == "table" and made.SetColorTexture) then
					return shown
				end
				b = made
				pool[n] = b
			end
			local c = M.BAND_INK
			b:SetColorTexture(c[1], c[2], c[3], c[4])
			local okH, h = pcall(fs.GetHeight, fs)
			-- a line's height is secret when its text is (taint log, 2026-11-07)
			h = okH and BT.Pill.Number(h, 0) or 0
			h = h > 0 and h or M.QUEST_SIZE
			local above = n == 1 and 3 or 1
			local below = n == #lines and 3 or 1
			b:ClearAllPoints()
			b:SetPoint("LEFT", fs, "LEFT", -M.BAND_LEFT, (above - below) / 2)
			b:SetPoint("RIGHT", tip, "RIGHT", -M.BAND_RIGHT, 0)
			b:SetHeight(h + above + below)
			b:Show()
			shown = shown + 1
		end
	end
	return shown
end

function M.QuestRows(tip, quests)
	local T = BT.UnitTip
	local lines = {}
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
				lines[#lines + 1] = T.Row(tip, "none", QUEST_TITLE, q.text, QUEST_TITLE,
					nil, nil, nil, M.QUEST_TITLE_SIZE)
				n = n + 1
			end
		else
			local count = (q.have and q.need) and ("%d/%d"):format(q.have, q.need) or nil
			local mark, tint = "quest", QUEST_TITLE
			if q.done then
				mark, tint = "questdone", QUEST_DONE
			end
			lines[#lines + 1] = T.Row(tip, mark, tint, q.text, T.INK, count,
				q.done and QUEST_DONE or QUEST_TITLE, nil, M.QUEST_SIZE, titles > 1 and M.QUEST_INDENT or nil)
			n = n + 1
		end
	end
	M.QuestBand(tip, lines)
	return n
end

-- ITEMS A QUEST ASKS FOR THAT THE CLIENT DOES NOT TIE TO AN ENEMY (Josh
-- 2026-11-04: "Small spider leg should be showing as a quest item on this
-- spider's tooltip"). The client writes a quest line on a tooltip only for a
-- quest-only item; a reagent a quest wants, like Small Spider Leg, has none.
-- Josh chose two ways to tell, either one enough: the item's name shares a
-- word with the enemy's name or family ("Small Spider Leg" on a Spider,
-- "Webwood Venom Sac" on a Webwood Lurker), or you have looted that item from
-- that enemy before. The first may now and then put a row on an enemy that
-- does not drop it. Only an enemy you can attack, and never a player.

-- an NPC's number from its GUID ("Creature-0-…-<npc>-…")
local function npcOf(guid)
	if type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then
		return nil
	end
	local kind, npc = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
	if kind ~= "Creature" and kind ~= "Vehicle" then
		return nil
	end
	return tonumber(npc)
end
M.NpcOf = npcOf

-- the words worth matching: four letters or more, in lower case, without "'s"
local function wordsOf(text, into)
	into = into or {}
	if type(text) ~= "string" then
		return into
	end
	for word in text:lower():gmatch("[%a']+") do
		word = word:gsub("'s$", ""):gsub("'", "")
		if #word >= 4 then
			into[word] = true
		end
	end
	return into
end

-- A QUEST-ONLY ITEM IS THE CLIENT'S TO TIE. The client writes a line for one
-- on every enemy that drops it, so one with no line there is not dropped by
-- it: the Webwood Egg comes from a nest, not a Webwood spider. The name is
-- not matched for such an item. Only an item the client has seen can be
-- asked about by name; one it has not is matched as any other.
M.QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
local function questOnly(name)
	local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
	if type(instant) == "function" then
		local ok, id, _, _, _, _, class = pcall(instant, name)
		if ok and id then
			return class == M.QUEST_CLASS
		end
	end
	return false
end

-- WHO DROPS IT, FROM THE DATABASE (Josh 2026-11-09: "This quest is showing
-- all crabs dropping the quest item in the tooltip"). The word "crab" in
-- Fine Crab Chunks matched every crab. QuestDropData.lua lists the enemies
-- that drop each Classic quest item (scripts/make-quest-drops.py): Reef
-- Crawlers and Encrusted Tide Crawlers. For an item it lists, only those
-- enemies get the row, plus any you have looted it from yourself. An item
-- it doesn't list, such as one from a quest new to Forever, is still
-- matched by name. The lists become sets the first time each is asked for.
local knownSets = {}
function M.KnownDrops(name)
	if type(name) ~= "string" or not BT.QuestDrops then
		return nil
	end
	local key = name:lower()
	local set = knownSets[key]
	if set == nil then
		local list = BT.QuestDrops[key]
		set = false
		if list then
			set = {}
			for _, id in ipairs(list) do
				set[id] = true
			end
		end
		knownSets[key] = set
	end
	return set or nil
end

-- what you have looted that a quest wanted, by enemy: { [npc] = { [item] = true } }
-- for the account, since every character's spiders drop the same legs
function M.Drops()
	local s = BT.settings
	if not s then
		return nil
	end
	if type(s.questDrops) ~= "table" then
		s.questDrops = {}
	end
	return s.questDrops
end

-- A GUESS BY THE KIND OF ENEMY GIVES WAY TO WHAT ITS CORPSES HELD (Josh
-- 2026-11-17, a Highland Scytheclaw with a "Thicket Raptor Hide 0/4" row:
-- "Ive been killing these raptors for a while. I don't think they drop the
-- ticket raptor hides"). The item is new to this game, so the database has
-- no list for it and it was matched by name: "raptor" is in the item's
-- name, and a Scytheclaw is a raptor by family, so every raptor got the
-- row. The enemy's own name shares no word with the item.
--
-- So each corpse you loot is counted. For every enemy in the loot window
-- and every item a quest still wants, a corpse without the item is one
-- miss, kept by enemy and item (M.Misses). An item matched only by the
-- enemy's family, not by its name, loses its row on that enemy after
-- M.MISSES corpses without it. Looting it there once brings the row back
-- for good (M.Drops), and a match by the enemy's own name is kept whatever
-- the count: "Webwood Venom Sac" stays on a Webwood Lurker.
-- A corpse with nothing on it opens no loot window and is not counted.
M.MISSES = 6
function M.Misses()
	local s = BT.settings
	if not s then
		return nil
	end
	if type(s.questMisses) ~= "table" then
		s.questMisses = {}
	end
	return s.questMisses
end
-- the corpses counted this session, so one looted twice is one miss
local counted, countedN = {}, 0

-- the loot window open: each item a quest still wants, under every enemy it
-- came from. Nothing else is kept.
function M.LearnDrops()
	if not (type(GetNumLootItems) == "function" and type(GetLootSlotInfo) == "function"
		and type(GetLootSourceInfo) == "function" and BT.Quests and BT.Quests.ItemObjectives) then
		return 0
	end
	local ok, objectives = pcall(BT.Quests.ItemObjectives)
	if not (ok and objectives and #objectives > 0) then
		return 0
	end
	local wanted = {}
	for _, o in ipairs(objectives) do
		wanted[o.text] = true
	end
	local drops = M.Drops()
	if not drops then
		return 0
	end
	local n = 0
	-- every corpse in the window, and which wanted items each held
	local corpses = {}
	local okN, count = pcall(GetNumLootItems)
	for slot = 1, (okN and tonumber(count)) or 0 do
		local okI, _, name = pcall(GetLootSlotInfo, slot)
		local plain = okI and type(name) == "string" and not (issecretvalue and issecretvalue(name))
		local r = { pcall(GetLootSourceInfo, slot) }
		-- guid, quantity, guid, quantity, ...
		for i = 2, #r, 2 do
			local guid = r[1] and r[i] or nil
			local npc = guid and npcOf(guid)
			if npc and not (issecretvalue and issecretvalue(guid)) then
				corpses[guid] = corpses[guid] or { npc = npc, held = {} }
				if plain and wanted[name] then
					corpses[guid].held[name] = true
					drops[npc] = drops[npc] or {}
					if not drops[npc][name] then
						drops[npc][name] = true
						n = n + 1
					end
				end
			end
		end
	end
	-- a corpse without a wanted item is a miss for it, once a corpse
	local misses = M.Misses()
	if misses then
		for guid, corpse in pairs(corpses) do
			if not counted[guid] then
				counted[guid] = true
				countedN = countedN + 1
				for name in pairs(wanted) do
					if not corpse.held[name] and not (drops[corpse.npc] and drops[corpse.npc][name]) then
						misses[corpse.npc] = misses[corpse.npc] or {}
						misses[corpse.npc][name] = math.min(99, (misses[corpse.npc][name] or 0) + 1)
					end
				end
			end
		end
		if countedN > 500 then
			counted, countedN = {}, 0
		end
	end
	return n
end
if CreateFrame then
	M.lootWatch = CreateFrame("Frame")
	pcall(M.lootWatch.RegisterEvent, M.lootWatch, "LOOT_READY")
	M.lootWatch:SetScript("OnEvent", function()
		if BT.Enabled("tooltips") then
			M.LearnDrops()
		end
	end)
end

-- `quests` as questBlock gave it (or nil), with the item objectives this
-- enemy counts towards that the client left out, each under its quest's name
function M.WithItemQuests(unit, quests)
	if not (BT.Quests and BT.Quests.ItemObjectives) then
		return quests
	end
	if plainYes(UnitIsPlayer, unit) or not plainYes(UnitCanAttack, "player", unit) then
		return quests
	end
	if not itemObjectives then
		local ok, list = pcall(BT.Quests.ItemObjectives)
		itemObjectives = ok and list or {}
	end
	if #itemObjectives == 0 then
		return quests
	end
	local said = {}
	for _, q in ipairs(quests or {}) do
		if not q.title then
			said[q.text] = true
		end
	end
	local npc = npcOf(plainText(UnitGUID, unit))
	local learnt = npc and M.Drops() and M.Drops()[npc] or nil
	-- its own name's words, and its family's: a match by the name is kept,
	-- one by the family alone gives way to the corpses' count (M.MISSES)
	local named = wordsOf(plainText(UnitName, unit))
	local family = wordsOf(plainText(UnitCreatureFamily, unit))
	local missed = npc and M.Misses() and M.Misses()[npc] or nil
	for _, o in ipairs(itemObjectives) do
		local match = learnt and learnt[o.text]
		local known = M.KnownDrops(o.text)
		if not match and known then
			match = npc ~= nil and known[npc] or false
		elseif not match and not questOnly(o.text) then
			local byFamily = false
			for word in pairs(wordsOf(o.text)) do
				if named[word] then
					match = true
					break
				elseif family[word] then
					byFamily = true
				end
			end
			if not match and byFamily then
				match = not (missed and (missed[o.text] or 0) >= M.MISSES)
			end
		end
		if match and not said[o.text] then
			said[o.text] = true
			quests = quests or {}
			local row = { text = o.text, have = o.have, need = o.need, done = false }
			-- under its quest's name when the client already wrote that quest
			local at = nil
			for i, q in ipairs(quests) do
				if q.title and q.text == o.title then
					at = i
				end
			end
			if at then
				local j = at + 1
				while quests[j] and not quests[j].title do
					j = j + 1
				end
				table.insert(quests, j, row)
			else
				quests[#quests + 1] = { text = o.title, title = true }
				quests[#quests + 1] = row
			end
		end
	end
	return quests
end

-- YOUR KILLS OF IT (Josh 2026-10-17, the tooltip canvas): how many of this
-- enemy the Expedition has from this character, and how far it is to its next
-- mastery, in that mastery's metal. Only for something you can attack, and
-- only while the Expedition is on.
-- QUIETER THAN THE QUESTS (Josh 2026-11-05: "The mastery is secondary
-- content, so I don't want to make users think they have to complete it").
-- The quest rows are in the tooltip's bright ink. This row is in grey, its
-- paw and its metal toned down by M.HUSH, and a row with no kills greyer still.
M.EXPEDITION = { 0.44, 0.64, 0.80 }
M.KILLS_INK = BT.TEXT.quiet
M.NO_KILLS = BT.TEXT.dim
M.HUSH = 0.7

-- AND SMALLER, SET APART (Josh 2026-11-05: "Maybe make the text slightly
-- smaller, and put some margin or a divider above it to separate it from the
-- quest text?"). A point smaller than the quest rows, and under quest rows a
-- short blank line with a faint rule across its middle. With no quest rows
-- above it, the gap under the tags already sets it apart.
M.KILLS_SIZE = 9.5
M.RULE_LINE = 7
M.RULE_INK = { 1, 1, 1, 0.10 }
M.RULE_INSET = 10
-- CENTRED BY EYE (Josh 2026-11-05: "can you vertically center it?"). The
-- middle of the blank line sat low: in his screenshot the quest's letters
-- ended at row 88, the rule was at 96 and the kills began at 101, so 7 rows
-- above it and 4 below. Lifted to the middle.
M.RULE_LIFT = 1.5
-- NEARER THE BOTTOM (Josh 2026-11-05: "Maybe move it closer to the bottom of
-- the tooltip"). Under "2 kills" there were 11 empty rows to the health line,
-- more than the gap above it. As the last line, its margin under it is this
-- much smaller. Its line is as tall as the paw, taller than its words, so the
-- words keep room under them.
M.KILLS_TUCK = 4

-- the faint rule across line `i` of `tip`, or put away for nil
function M.KillsRule(tip, i)
	local rule = tip and tip.beebsKillsRule
	if not i then
		if rule then
			rule:Hide()
		end
		return nil
	end
	local fs = BT.UnitTip.LineOf(tip, i)
	if not fs then
		return nil
	end
	if not rule then
		local ok, made = pcall(tip.CreateTexture, tip, nil, "ARTWORK")
		if not (ok and type(made) == "table" and made.SetColorTexture) then
			return nil
		end
		rule = made
		rule:SetColorTexture(M.RULE_INK[1], M.RULE_INK[2], M.RULE_INK[3], M.RULE_INK[4])
		tip.beebsKillsRule = rule
	end
	rule:ClearAllPoints()
	rule:SetPoint("LEFT", fs, "LEFT", 0, M.RULE_LIFT)
	rule:SetPoint("RIGHT", tip, "RIGHT", -M.RULE_INSET, 0)
	rule:SetHeight(1)
	rule:Show()
	return rule
end

-- `c` toned down toward the tooltip's dark: each part scaled by M.HUSH
function M.Hushed(c)
	if type(c) ~= "table" then
		return c
	end
	return { (c[1] or 1) * M.HUSH, (c[2] or 1) * M.HUSH, (c[3] or 1) * M.HUSH }
end
function M.KillsRow(tip, unit, apart)
	M.KillsRule(tip, nil)
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
	if apart then
		tip:AddLine(" ")
		local gap = BT.Pill.Number(tip:NumLines(), 1)
		BT.UnitTip.SizeLine(tip, gap, M.RULE_LINE)
		M.KillsRule(tip, gap)
	end
	local i = BT.UnitTip.Row(tip, "kills", M.Hushed(feature and feature.color or M.EXPEDITION), words,
		have == 0 and M.NO_KILLS or M.KILLS_INK, right, M.Hushed(rc))
	BT.UnitTip.SizeLine(tip, i, M.KILLS_SIZE, nil, "text")
	if right then
		BT.UnitTip.SizeLine(tip, i, M.KILLS_SIZE, "TextRight", "text")
	end
	return i
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
	if M.TILES_LOOK and M.UNIT then
		-- in the foot's strip, with room at each end and over and under it
		-- (M.UnitLook)
		local U2 = M.UNIT
		local lift = 1 + math.floor((U2.STRIP_H - U2.BAR_H) / 2)
		health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1 + SPINE + U2.BAR_INSET, lift)
		health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1 - U2.BAR_INSET, lift)
		health:SetHeight(U2.BAR_H)
	else
		health:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1 + SPINE, 1)
		health:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1, 1)
		health:SetHeight(M.HEALTH_H)
	end
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
BT.OnUnitTooltipHide(function(tip)
	M.HealthLine(nil, nil)
	M.KillsRule(tip or _G.GameTooltip, nil)
	M.QuestBand(tip or _G.GameTooltip, nil)
end)

-- A UNIT'S TOOLTIP IN THE ITEM CARD'S LOOK (Josh 2026-11-17, with the item
-- and recipe cards in place: "I think we can proceed with the remaining
-- tooltips"; the look is the canvas's "B, chosen" board, which he picked on
-- 2026-11-16). What a unit's tooltip says and in what order is as it was.
-- What changes is how it is dressed:
--   a band behind who it is (the name, its tags, its guild or job), in the
--     class's colour for a player and the reaction's for anything else
--   the level large at the right, with LEVEL under it
--   a darker strip along the foot of something you can fight, with its
--     health as a bar inside it, where the bar had been two pixels on the
--     tooltip's edge
-- The pieces are the tooltip's own, one set a tooltip, put away when it
-- hides or is cleared for something else.
M.UNIT = { NAME = 15, LEVEL = 19, BAND_UNDER = 6, STRIP_H = 14, BAR_H = 4, BAR_INSET = 9, GAP = 7 }
local unitBits = setmetatable({}, { __mode = "k" })
function M.HideUnitBits(tip)
	local u = tip and unitBits[tip]
	if u then
		for _, part in pairs(u) do
			if type(part) == "table" and part.Hide then
				part:Hide()
			end
		end
		-- and a row of tiles another module asked for (M.UnitTiles)
		for _, f in ipairs(u.tb and u.tb.tileBacks or {}) do
			f:Hide()
		end
		u.tiles = nil
	end
end
-- the band from the tooltip's top to under line `last`; false where the
-- game will not say where they are
local function layUnitBand(tip, u, last)
	local top = BT.Pill.Number(tip.GetTop and tip:GetTop(), nil)
	local fs = last and BT.UnitTip.LineOf(tip, last)
	local low = fs and BT.Pill.Number(fs.GetBottom and fs:GetBottom(), nil)
	if not (top and low and top > low) then
		return false
	end
	u.band:ClearAllPoints()
	u.band:SetPoint("TOPLEFT", tip, "TOPLEFT", 1, -1)
	u.band:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -1, -1)
	u.band:SetHeight(top - low + M.UNIT.BAND_UNDER)
	u.band:Show()
	return true
end

-- `colour`: the band's; `last`: the last line of who it is; `level`: true
-- where the level is said; `fighting`: true where the health bar is shown
function M.UnitLook(tip, colour, last, level, fighting)
	if not (M.TILES_LOOK and tip and tip.CreateTexture) then
		return nil
	end
	local T, U2 = BT.UnitTip, M.UNIT
	local u = unitBits[tip]
	if not u then
		-- (a tooltip that will not make them goes without)
		local okBand, band = pcall(tip.CreateTexture, tip, nil, "BORDER")
		local okStrip, strip = pcall(tip.CreateTexture, tip, nil, "BORDER")
		local okCap, cap = pcall(tip.CreateFontString, tip, nil, "OVERLAY")
		if not (okBand and okStrip and okCap and type(band) == "table" and type(strip) == "table" and type(cap) == "table"
			and band.SetColorTexture and cap.SetText) then
			return nil
		end
		u = { band = band, strip = strip, cap = cap }
		unitBits[tip] = u
	end
	u.band:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or M.B.BAND)
	u.whole = nil
	if not layUnitBand(tip, u, last) then
		u.band:Hide()
	end
	local right = level and T.LineOf(tip, 1, "TextRight")
	if right then
		BT.Fonts.Set(u.cap, "name", M.ITEM.FIG_LABEL)
		u.cap:SetText("LEVEL")
		u.cap:SetTextColor(BT.TEXT.dim[1], BT.TEXT.dim[2], BT.TEXT.dim[3])
		u.cap:ClearAllPoints()
		u.cap:SetPoint("TOPRIGHT", right, "BOTTOMRIGHT", 0, -1)
		u.cap:Show()
	else
		u.cap:Hide()
	end
	-- for M.UnitLookEnd, once every module has written its rows
	u.identityEnd, u.fighting = last, fighting and true or false
	-- (the last unit's tiles go: whoever wants a row asks again, M.UnitTiles)
	for _, f in ipairs(u.tb and u.tb.tileBacks or {}) do
		f:Hide()
	end
	u.tiles = nil
	if fighting then
		u.strip:ClearAllPoints()
		u.strip:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1, 1)
		u.strip:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1, 1)
		u.strip:SetHeight(U2.STRIP_H)
		u.strip:SetColorTexture(0, 0, 0, M.B.STRIP)
		u.strip:Show()
	else
		u.strip:Hide()
	end
	return u
end
BT.UnitTip.OnGone(M.HideUnitBits)

-- WITH NOTHING UNDER WHO IT IS, THE BAND IS THE WHOLE TOOLTIP (Josh
-- 2026-11-17, a player with no rows: "Players have a black bar on the bottom
-- now"). The gap under the band (M.UNIT.GAP) is for the rows that follow.
-- On a tooltip with none it was a strip of the plain dark fill under the
-- band. So after every module has had its turn at the tooltip, a tooltip
-- whose last line is still that gap has its band run to the bottom, or to
-- the top of the foot's strip where there is one.
function M.UnitLookEnd(tip)
	local u = tip and unitBits[tip]
	if not (M.TILES_LOOK and u and u.band and u.identityEnd) then
		return false
	end
	local lines = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
	if lines > u.identityEnd + 1 then
		return false
	end
	u.band:ClearAllPoints()
	u.band:SetPoint("TOPLEFT", tip, "TOPLEFT", 1, -1)
	u.band:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1, u.fighting and (M.UNIT.STRIP_H + 1) or 1)
	u.band:Show()
	u.whole = true
	return true
end

-- LINES WRITTEN LATER END THE WHOLE BAND (Josh 2026-11-17, an NPC whose
-- quest, "[24] Digging Through the Ooze", lay on the band: "the quests
-- should go into a content area as well"). That row is another addon's. It
-- was written after every module here had had its turn, when the tooltip
-- had nothing under who it is and the band had been run to the bottom. The
-- band then grew with the tooltip and lay behind the row. So when the
-- tooltip changes size, a band over the whole of it is looked at again. If
-- lines now follow, it ends under who it is.
function M.UnitLookAgain(tip)
	local u = tip and unitBits[tip]
	if not (u and u.whole and u.identityEnd and u.band.IsShown and u.band:IsShown()) then
		return false
	end
	local lines = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
	if lines <= u.identityEnd + 1 then
		return false
	end
	if layUnitBand(tip, u, u.identityEnd) then
		u.whole = nil
		return true
	end
	return false
end

-- A QUEST YOU CAN HAND IN HAS THE GAME'S YELLOW MARK (Josh 2026-11-17, an NPC
-- under a yellow "?" whose tooltip row had a pale one: "Can you make the "?"
-- in the tooltip the same yellow as the game world one? Only for completed
-- quests"). The row is Questie's. It draws the "?" as a picture tinted by
-- how hard the quest is for your level, which for an old quest is grey. On a
-- row that says the quest is complete, the tint is changed to the yellow of
-- the mark over the NPC's head. Any other row is left as Questie wrote it.
-- (English only: the row is known by Questie's word "Complete".)
M.QUEST_MARK = "255:209:0"
function M.QuestMarkText(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		return nil
	end
	if not (text:find("tooltip_complete.png", 1, true) and text:find("Complete)", 1, true)) then
		return nil
	end
	local out, n = text:gsub("(tooltip_complete%.png:[%d:]-):%d+:%d+:%d+|t", "%1:" .. M.QUEST_MARK .. "|t", 1)
	return (n > 0 and out ~= text) and out or nil
end
function M.QuestMarks(tip)
	local n = 0
	if not (M.TILES_LOOK and tip and tip.NumLines and BT.Enabled("tooltips")) then
		return n
	end
	for i = 2, BT.Pill.Number(tip:NumLines(), 0) do
		local fs = BT.UnitTip.LineOf(tip, i)
		local ok, text = pcall(function() return fs and fs.GetText and fs:GetText() end)
		local yellow = ok and M.QuestMarkText(text) or nil
		if yellow then
			fs:SetText(yellow)
			n = n + 1
		end
	end
	return n
end

if GameTooltip and GameTooltip.HookScript then
	pcall(GameTooltip.HookScript, GameTooltip, "OnSizeChanged", function(tip)
		local ok, err = pcall(M.UnitLookAgain, tip)
		if not ok then
			BT.Err("tooltips.band: " .. tostring(err))
		end
		ok, err = pcall(M.QuestMarks, tip)
		if not ok then
			BT.Err("tooltips.mark: " .. tostring(err))
		end
	end)
end
BT.OnUnitTooltip("tooltips", 99, function(tip)
	M.UnitLookEnd(tip)
	if M.LayUnitTiles then
		M.LayUnitTiles(tip)
	end
end)

-- A WORLD OBJECT'S BAND (Josh 2026-11-17, screenshots of Tin Vein and Solid
-- Chest in the plain look beside the new cards). An object is written by
-- M.ComposeObject, below, which rebuilds one a quest wants and leaves any
-- other as the game drew it. Either way it now has the band: behind its
-- name and the words under it where quest rows follow, and over the whole
-- tooltip where nothing does. `identityEnd`: its last line before the
-- quest's rows, or nil for all of it.
--
-- DARK AMBER, NOT GREY (Josh 2026-11-17, Bruiseweed with "Requires
-- Herbalism" in the game's red: "gray has poor contrast with the red"). The
-- band was a grey wash, which lifted the ground under the red words to a
-- mid grey. It is now the gold of the object's name, thin enough that the
-- ground stays dark: the red reads on it as it does on a plain tooltip.
M.OBJECT_BAND = { 1, 0.82, 0, 0.12 }
function M.ObjectLook(tip, identityEnd)
	if not (M.TILES_LOOK and tip and tip == rawget(_G, "GameTooltip")) then
		return false
	end
	local lines = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
	if lines < 1 then
		return false
	end
	local u = M.UnitLook(tip, M.OBJECT_BAND, identityEnd or lines, false, false)
	if not u then
		return false
	end
	if not identityEnd then
		-- all of it: as a unit with nothing under who it is (M.UnitLookEnd)
		u.identityEnd = lines
		M.UnitLookEnd(tip)
	end
	return true
end

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
		-- a secret class is no key (2026-10-17, audit)
		local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
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
	-- a player counts towards none of your quests: their lines are not
	-- looked through for one (2026-10-17, audit)
	local quests, usedByQuests = nil, nil
	if not isPlayer then
		quests, usedByQuests = questBlock(tip, spoken)
	end
	for line in pairs(usedByQuests or {}) do
		spoken[line] = true
	end
	-- and the items a quest wants that the client did not tie to it
	if not isPlayer then
		quests = M.WithItemQuests(unit, quests)
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
	-- (the item card's sizes in its look: M.UNIT)
	local HEADER, LEVEL = HEADER, LEVEL
	if M.TILES_LOOK then
		HEADER, LEVEL = M.UNIT.NAME, M.UNIT.LEVEL
	end
	-- A LONG NAME IS SET SMALLER BEFORE THE TOOLTIP IS MADE WIDER (Josh
	-- 2026-11-17, Highlord Bolvar Fordragon's tooltip half as wide again as a
	-- player's: "Are we able to scale player/npc names similarly to the
	-- items, so tooltips don't increase in width? I'd like to have a
	-- consistent, or at least mostly consistent tooltip width"). As on an
	-- item's card: the name goes down half a point at a time, to
	-- M.B.NAME_LEAST, until it fits the usual width. Only a name still too
	-- long at that size widens the tooltip. What the smaller name gives up
	-- in height is put back below (`lost`), so the tags and the rows stay
	-- where they are on any other unit.
	local lost = 0
	if not (issecretvalue and issecretvalue(name)) then
		local beside = BT.UnitTip.Measure("    " .. level, LEVEL, "name") + rankW + PAD_X + PAD_LEFT + 14
		if M.TILES_LOOK then
			local full = HEADER
			while HEADER > M.B.NAME_LEAST and BT.UnitTip.Measure(name, HEADER, "name") + beside > MIN_W do
				HEADER = math.max(M.B.NAME_LEAST, HEADER - 0.5)
			end
			lost = math.max(0, BT.Fonts.Size(full) - BT.Fonts.Size(HEADER))
		end
		local needs = BT.UnitTip.Measure(name, HEADER, "name") + beside
		width = math.max(MIN_W, math.min(MAX_W, math.floor(needs)))
	end

	M.ClearLines(tip)
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
	-- A PLAYER'S GUILD UNDER THE BAND, NOT ON IT (Josh 2026-11-17: "Thinking
	-- the guild name on player tooltips should be moved into the body instead
	-- of header, so it matches the other tooltips a bit better"). On the band
	-- it was a line of bright green on the class's colour. In the look a
	-- player's band has the name and the tags, and the guild is the first
	-- line under it. (An NPC's job stayed on its band until later that day.)
	-- AND AN NPC'S (Josh 2026-11-17, a hunter's pet with "<Zeheva
	-- Dragonslayer's Pet>" on its band: "The green tag should be moved to the
	-- content area, same as guild names for players"). An NPC's job and a
	-- pet's owner are written by the game the way a guild is, so they go
	-- under the band as well.
	local with = about.guild or about.title
	local guildBelow = M.TILES_LOOK and with ~= nil
	if with and not guildBelow then
		tip:AddLine(M.GUILD:format("<" .. with .. ">"))
		sizeLine(tip, BT.Pill.Number(tip:NumLines(), 2), BT.UnitTip.ROW)
	end
	-- whatever else the client had to say, as small print under them
	-- UNDER THE BAND AS WELL, IN THE LOOK (Josh 2026-11-17, an NPC with
	-- "Ironforge" on its band: "I think "Ironforge" and the quests should go
	-- into a content area as well"). The band is the name and the tags. What
	-- the game says besides, such as the faction an NPC belongs to, is
	-- written after the gap, under the guild or job.
	local function smallPrint(below)
		local function one(text)
			tip:AddLine(text, DIM[1], DIM[2], DIM[3])
			local at = BT.Pill.Number(tip:NumLines(), 2)
			sizeLine(tip, at, FOOT)
			if below then
				BT.UnitTip.Indent(tip, at, BODY_INDENT)
			end
		end
		if #facts > 0 then
			one(table.concat(facts, " · "))
		end
		for _, line in ipairs(small) do
			one(line)
		end
	end
	if not M.TILES_LOOK then
		smallPrint(false)
	end
	indentBody(tip)
	-- the last line of who it is: the band ends under it (M.UnitLook)
	local identityEnd = BT.Pill.Number(tip:NumLines(), 1)
	-- ROOM UNDER THE BAND (Josh 2026-11-17, a Giant Wetlands Crocolisk with
	-- its kills row hard under the band and hard over the foot's strip: "This
	-- tooltip looks a bit weird"). The rows began on the line after the tags,
	-- so the band's lower edge ran along the top of the first row's words.
	-- A short blank line parts them, and the kills row is no longer pulled
	-- down toward the foot where the strip is (M.KILLS_TUCK, below).
	-- (a no-break space: a plain blank at the tooltip's end is taken down
	-- to a pixel, squeezeBlankTail, and the Ledger's rows are written under
	-- this one after that has run)
	if M.TILES_LOOK then
		tip:AddLine(BT.UnitTip.TAG_BLANK)
		BT.UnitTip.SizeLine(tip, BT.Pill.Number(tip:NumLines(), 1), M.UNIT.GAP, nil, "text")
	end
	if guildBelow then
		tip:AddLine(M.GUILD:format("<" .. with .. ">"))
		local at = BT.Pill.Number(tip:NumLines(), 2)
		sizeLine(tip, at, BT.UnitTip.ROW)
		BT.UnitTip.Indent(tip, at, BODY_INDENT)
	end
	if M.TILES_LOOK then
		smallPrint(true)
	end
	-- TWO PIXELS MORE ABOVE THE TAGS (Josh 2026-10-17: "Can I get like 2px
	-- more margin above the tags?"): their first line hung that much lower
	-- off the name, and everything under it with it. No spacer line does it:
	-- one that small is one the client may write words into at a size too
	-- small to read.
	if firstTags then
		BT.UnitTip.Indent(tip, firstTags, BODY_INDENT, nil, -M.TAG_DROP)
	end
	-- A SMALLER NAME IN THE SAME ROOM (see `lost`, above): the name half of
	-- what it lost lower, in the middle of its old room; the level beside
	-- it lifted back to where it always is; the line under the name the
	-- other half lower, and every line after it with it.
	if lost > 0 then
		local drop = lost / 2
		BT.UnitTip.Indent(tip, 1, 0, nil, -drop)
		BT.UnitTip.Indent(tip, 1, 0, "TextRight", drop)
		if BT.Pill.Number(tip:NumLines(), 1) >= 2 then
			BT.UnitTip.Indent(tip, 2, BODY_INDENT, nil, -drop - (firstTags == 2 and M.TAG_DROP or 0))
		end
	end

	-- the rows: the quests it counts for, then your kills of it
	local beforeQuests = BT.Pill.Number(tip:NumLines(), 0)
	M.QuestRows(tip, quests)
	local killsAt = M.KillsRow(tip, unit, BT.Pill.Number(tip:NumLines(), 0) > beforeQuests)

	-- Elite, Rare or Boss, as a tag just before the level
	if rank then
		local levelW = BT.UnitTip.Measure(level, LEVEL, "name")
		BT.UnitTip.PlaceTag(tip, 1, -(levelW + RANK_GAP + BT.UnitTip.TagWidth(rank[1])), { rank[1], rank[2] },
			"TextRight", "RIGHT")
	end

	-- the skin, and the spine in whoever's colour this is
	-- set before dressing: the skin applies whatever edge is remembered on it,
	-- so a rare's silver survives the tooltip showing itself again
	-- AN UNREADABLE ANSWER KEEPS THIS UNIT'S LAST EDGE (2026-10-17, audit).
	-- The client clears the tooltip before every refresh, and the clear
	-- forgets the edge (M.DressPlain), so the edge is kept here by the unit's
	-- GUID instead: the same unit keeps it, the next one does not.
	local edge = edgeFor(unit, isPlayer)
	local guid = plainText(UnitGUID, unit)
	if edge == UNKNOWN_EDGE then
		edge = (guid and M.lastEdge.guid == guid) and M.lastEdge.edge or nil
	else
		M.lastEdge.guid, M.lastEdge.edge = guid, edge
	end
	local worn = skins[tip]
	if worn then
		worn.wantEdge = edge
	end
	local s = M.Dress(tip, true, true)
	if s then
		s.wantEdge = edge
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
		-- (and what a smaller name lost, which the client does not count either)
		room = room + lost
		if M.TILES_LOOK and fighting then
			-- (the strip in place of the two pixel line)
			room = room - (M.HEALTH_H + 1) + M.UNIT.STRIP_H + 2
		end
		-- and the kills row, when it is the last line, nearer the bottom
		if killsAt and killsAt == BT.Pill.Number(tip:NumLines(), 0) and not (M.TILES_LOOK and fighting) then
			room = room - M.KILLS_TUCK
		end
		skins[tip].extraBottom = room ~= 0 and room or nil
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
	-- the band, the level's caption and the foot's strip, now the lines are
	-- where they will be
	M.UnitLook(tip, { sr, sg, sb }, identityEnd, true, fighting)
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
	local line = ("last crest: %s; card parts left over: %d"):format(M.crestSaid, M.leftovers)
	-- comparison cards left as the game filled them, and those written a
	-- frame late (M.Spared, M.SettleSpared)
	line = line .. ("; comparison fills left unwritten: %d, written late: %d"):format(M.spared, M.settled)
	return line
end

-- (The timing of each item tooltip's write, built on 2026-11-16 to find
-- why the frame rate fell with a tooltip open, came out on 2026-11-17. It
-- found that the game fills each comparison tooltip several times a redraw,
-- with or without addons. What it led to is M.Spared.)
M.spared, M.settled = 0, 0

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
-- An item tooltip is written again as a card (M.RebuildItem, below), the
-- comparison ones too. One in a shape the card does not know, such as a
-- recipe, is restyled where it is (M.ItemLines). Either way, two things are
-- done to it as well.
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
	local quality
	-- THE LINK, NOT THE NAME (2026-10-17, audit): GetDisplayedItem answers
	-- name, link and id, as GetItem does, and the quality was asked of the
	-- name; shownItem (below) reads the link from either
	local link = M.ShownItem(tip)
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
				BT.Ink(fs, "ghost") -- nearly gone; it is not about the item
			else
				BT.Ink(fs, "muted")
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
	return lvl and ("|cff8a9894ILVL|r %d"):format(lvl) or nil
end

-- THE ITEM A TOOLTIP SHOWS, ON EVERY KIND (2026-10-17, audit): the
-- comparison tooltips have no GetItem (ShoppingTooltipTemplate is the
-- client's TooltipDataHandlerMixin), so the client's TooltipUtil is asked
-- first. Its link, or nil; ask before a rebuild clears the tooltip.
function M.ShownItem(tip)
	if TooltipUtil and TooltipUtil.GetDisplayedItem then
		local ok, _, link = pcall(TooltipUtil.GetDisplayedItem, tip)
		if ok and link then
			return link
		end
	end
	if tip.GetItem then
		local ok, _, link = pcall(tip.GetItem, tip)
		if ok and link then
			return link
		end
	end
	return nil
end
local shownItem = M.ShownItem

local function itemLevel(tip)
	local itemLink = shownItem(tip)
	local text = itemLink and M.ItemLevelText(itemLink)
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

-- some words without the colours written into them ("|cff00ff00...|r")
function M.Bare(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- the client's own sentence as a pattern: its numbers ("%d", "%.3g", "%s")
-- captured, a plural ("|4sec:secs;") any word
-- AND NOT ITS COLOURS (2026-10-17, audit): ITEM_CREATED_BY is written in
-- green, "|cff00ff00<Made by %s>|r", and a line that came without them did
-- not match; lines are matched bare too (M.ReadItem). The items' patterns
-- are made here as well, so "(%.1f damage per second)" is read.
local function shape(global, fallback)
	local form = M.Bare(type(_G[global]) == "string" and _G[global] or fallback)
	local holes = form:gsub("%%%%", "\2"):gsub("%%[%-%d%.]*[sdfg]", "\1"):gsub("|4[^;]*;", "\3")
	local escaped = holes:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	local pattern = escaped:gsub("\1", "(.-)"):gsub("\2", "%%%%"):gsub("\3", "%%a+")
	return "^" .. pattern .. "$"
end
M.Shape = shape
M.DPS_LINE = shape("DPS_TEMPLATE", "(%s damage per second)")
M.DURABILITY_LINE = shape("DURABILITY_TEMPLATE", "Durability %d / %d")

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
			-- NO TAGS ON A TOOLTIP THAT IS NOT A CARD (Josh 2026-11-16, of a
			-- tailoring pattern: "Other tooltips look a bit strange, especially
			-- the tags"). A recipe, with the item it makes inside it, is not
			-- written again as a card: its lines stay where the game put them
			-- and are restyled here. This put "BoP" and, for the item inside,
			-- "HEAD" and "CLOTH" over those lines as tags. On the new card tags
			-- sit in the band beside the icon; with no band they hung in the
			-- middle of the text. In the new look these lines stay the game's
			-- own words, in the card's sizes.
			local tagged = not M.TILES_LOOK
			if tagged and ((kind ~= nil and kind == LT.ItemBinding) or (left and left == _G.ITEM_UNIQUE)) then
				-- its line taller than a row of tags, and the tag at the top of
				-- it: the room falls under it (Josh 2026-10-17: "Soulbound
				-- needs some margin under it"), and no line is moved; "BoP" as
				-- on a card (M.BindShort; 2026-10-17, audit)
				local short = M.BindShort(left)
				tagLine(tip, i, { { short or left, "bound", keepCase = short ~= nil } }, M.BOUND_LINE, "TOPLEFT")
			elseif tagged and kind ~= nil and kind == LT.EquipSlot then
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
-- AN ITEM, WRITTEN AS A SPELL IS (Josh 2026-10-18: the item tooltips "don't
-- match the spell tooltips. Might need to rework these so they match spell
-- tooltips", then "Option 1 for the item tooltips. Instead of "Item Level"
-- we can just use "ilvl"")
-- ---------------------------------------------------------------------------
--
--   [icon] the name, in its quality's colour              53.8 DPS
--          Axe · Two-Hand                                    63 ilvl
--   [153–256 damage] [3.80 speed] [BoE] [requires level 58]
--   +13 Stamina
--   Equip: +62 Attack Power.            the effects as the client wrote
--                                       them, in the game's green
--   anything else the client said, in its own colours
--   the flavour text, in the lore's italic
--   [a short bar] 61/120                    the sell price, in coins
--   Made by Lorelei
--
-- The two figures and the cells are the spell card's own (c.header,
-- c.cells): armour has its armor where a weapon has its DPS, and a potion
-- what its Use line comes to (M.ItemFigures); a potion's cells are its
-- amount and cooldown (M.ItemFacts). Written from the client's own account
-- of each line (M.ReadItem), so no line is placed by guessing where it sat.
-- A tooltip in a shape this does not know - a recipe with an item inside
-- it, a gem socket, the cost of a repair - is restyled where it is instead
-- (M.ItemLines). The icon, the figures, the cells and the bar are ours,
-- laid over lines kept for them, on each tooltip its own (M.ItemBits).

-- the sizes, in the game's points (Core/Fonts.lua moves them for the face)
M.ITEM = {
	NAME = 13.5, SUB = 10, HEAD = 8, ROW = 10.5, FLAVOUR = 12, FOOT = 9, MAKER = 9.5,
	ICON = 26, ICON_GAP = 7, ICON_TALL = 40,
	HEADLINE = 12, FIG_SMALL = 10, FIG_LABEL = 7.5, FIG_GAP = 4, CELL_PAD = 6, CELL_PAD_Y = 2, QUIET = 9.5,
	BAR_H = 3, BAR_W = 44, BAR_GAP = 5, MIN_W = 240, PLAIN_W = 180, INSET = 20, SPACER = 4,
}

-- the size to give a line for it to come out `px` tall (T.SizeLine moves
-- every size by the face's own amount)
local function lineFor(px)
	return px - (BT.Fonts.Size(px) - px)
end
local ITEM_INK = BT.TEXT.ink
local ITEM_SUB = BT.TEXT.quiet
local ITEM_HEAD = BT.TEXT.dim
local ITEM_GREEN = { 0.12, 1, 0 }
local ITEM_MAKER = { 0.37, 0.68, 0.37 }
-- a spell's description, kept where it says more than its figures: quieter
local ITEM_QUIET = BT.TEXT.muted

-- some words in a colour of their own, inside a line of another
local function hex(rgb, words)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5),
		math.floor(rgb[3] * 255 + 0.5), words)
end

-- the colour the client gave a line where it warns (a cost you cannot pay,
-- a level you have not reached, in red), or nil
local function warning(c)
	return (c ~= nil and c[2] < 0.5) and c or nil
end

-- THE FACTS AS THEIR CELLS SAY THEM, a spell's and an item's alike. Each
-- fact { text, rgb, lower }: its words, in small letters where `lower`
-- (the client's "Requires Level 58" as "requires level 58"); all of it in
-- `rgb` where the client warned with a colour, else its number brighter
-- than its words, wherever in them it is. Returns c.cells' items.
function M.FactCells(facts)
	local items = {}
	for _, f in ipairs(facts) do
		local words = f.lower and f.text:lower() or f.text
		local shown = words
		if f.rgb then
			shown = hex(f.rgb, words)
		else
			local before, n, after = words:match("^(%D-)(%+?%d[%d%.,–]*)(.*)$")
			if n then
				shown = before .. hex(ITEM_INK, n) .. after
			end
		end
		items[#items + 1] = { shown, words }
	end
	return items
end

-- the client's own sentences as patterns, their numbers captured (shape)
M.ITEM_LINES = {
	dps = shape("DPS_TEMPLATE", "(%s damage per second)"),
	damage = shape("DAMAGE_TEMPLATE", "%s - %s Damage"),
	armor = shape("ARMOR_TEMPLATE", "%s Armor"),
	block = shape("SHIELD_BLOCK_TEMPLATE", "%d Block"),
	level = shape("ITEM_MIN_LEVEL", "Requires Level %d"),
	durability = shape("DURABILITY_TEMPLATE", "Durability %d / %d"),
	maker = shape("ITEM_CREATED_BY", "<Made by %s>"),
	setBonus = shape("ITEM_SET_BONUS", "Set: %s"),
	setBonusGrey = shape("ITEM_SET_BONUS_GRAY", "(%d) Set: %s"),
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
	-- the colour itself can be secret, and then not even its fields may be
	-- read (taint log, 2026-11-07: 46 lines)
	if type(c) ~= "table" or (issecretvalue and issecretvalue(c)) then
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
-- the client's red on what you cannot use: a slot or weapon kind you have no
-- skill in, a level, class or profession you do not have
local function isRed(c)
	return c ~= nil and c[1] > 0.8 and c[2] < 0.35 and c[3] < 0.35
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
			-- the words matched against the client's sentences, without colours
			local bare = left and M.Bare(left)
			if not item.name then
				if not left then
					return nil
				end
				item.name, item.quality = left, lc
			elseif kind ~= nil and kind == LT.ItemBinding then
				item.bind = left
			elseif left and (left == _G.ITEM_UNIQUE or left == "Unique" or left == _G.ITEM_UNIQUE_EQUIPPABLE
				or left:find("^Unique %(%d+%)$")) then
				item.unique = left
			elseif kind ~= nil and kind == LT.EquipSlot then
				-- with their colours: a rogue's "Two-Hand" and "Mace" are red
				item.slot, item.kind = left, right
				item.slotRgb, item.kindRgb = lc, rc
				item.unusable = item.unusable or isRed(lc) or isRed(rc)
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
			elseif M.TILES_LOOK and not item.set and lc and lc[1] > 0.9 and lc[2] > 0.7 and lc[3] < 0.3
				and bare:match("^.+ %(%d+/%d+%)$") then
				-- A SET, KEPT TOGETHER (Josh 2026-11-17, working down what was
				-- left of the redesign: "Proceed step 6", gems and set pieces).
				-- The game writes a set as its name with a count in gold, "Defias
				-- Leather (2/5)", its pieces under it a little way in, grey
				-- where you do not wear one, then each bonus, grey until you
				-- wear enough. They were read as lines of no kind and came out
				-- in the grey box with other addons' lines. In the look they
				-- are a box of their own (M.WriteItemB). The look before keeps
				-- them where the game put them.
				local name, have, need = bare:match("^(.+) %((%d+)/(%d+)%)$")
				item.set = { name = name, have = tonumber(have), need = tonumber(need), pieces = {}, bonuses = {} }
			elseif item.set and #item.set.bonuses == 0 and left:find("^%s+%S") then
				-- (looked for before the facts: "  Blackened Defias Armor" would
				-- read as an armor figure)
				item.set.pieces[#item.set.pieces + 1] = { text = bare:match("^%s*(.-)%s*$"), worn = lc ~= nil and lc[1] > 0.8 }
			elseif bare:find(P.dps) then
				item.dps = bare:match(P.dps)
			elseif right and bare:find(P.damage) and right:find("%d") then
				local lo, hi = bare:match(P.damage)
				-- "41 - 77 Shadow Damage": the school comes off the top number
				local top, school = hi:match("^([%d%.,]+)%s+(.+)$")
				item.damage, item.speed = ("%s–%s"):format(lo, top or hi), right:match("([%d%.,]+)")
				item.school = school
			elseif bare:find(P.damage) then
				item.extraDamage[#item.extraDamage + 1] = { text = left, rgb = lc }
			elseif bare:find(P.armor) then
				item.armor = bare:match(P.armor)
			elseif bare:find(P.block) then
				item.block = bare:match(P.block)
			elseif bare:find(P.level) then
				item.require = { text = left, rgb = lc }
				item.unusable = item.unusable or isRed(lc)
			elseif bare:find(P.durability) then
				local now, most = bare:match(P.durability)
				item.durability = { now = tonumber(now), most = tonumber(most), text = now .. "/" .. most }
			elseif bare:find(P.maker) then
				item.maker = bare:match(P.maker)
			elseif item.set and (bare:find(P.setBonus) or bare:find(P.setBonusGrey)) then
				item.set.bonuses[#item.set.bonuses + 1] = { text = bare, active = isGreen(lc) }
			elseif bare:find(P.setBonus) or bare:find(P.setBonusGrey) then
				-- a set's bonus stays with the set's name and pieces above it,
				-- in the client's order: green as it is, it is not an enchant
				item.rest[#item.rest + 1] = { text = left, rgb = lc, wrap = true }
			elseif isFootnote(left) then
				item.notes[#item.notes + 1] = left
			else
				local head, text = trigger(left)
				if head then
					-- what sets it off, and the line whole, "Equip:" and all, as the
					-- card writes it with no headings now
					item.effects[#item.effects + 1] = { head = head, text = text, rgb = lc, line = left }
				elseif left:find("^[%+%-]%d") and not isGreen(lc) then
					item.stats[#item.stats + 1] = { text = left, rgb = lc }
				elseif isGreen(lc) and not left:find("^%(") then
					-- a green line nothing else names: an enchant laid on for a
					-- while (Rockbiter)
					item.effects[#item.effects + 1] = { head = "Enchant", text = left, rgb = lc }
				else
					item.rest[#item.rest + 1] = { text = left, rgb = lc, right = right, rrgb = rc,
						wrap = plainLine(line.wrapText) and true or nil }
					-- "Classes: Priest", "Requires Leatherworking (200)"
					item.unusable = item.unusable or isRed(lc)
				end
			end
		end
	end
	if not item.name then
		return nil
	end
	return item
end

-- A RECIPE, AND THE ITEM IT MAKES INSIDE IT (Josh 2026-11-17, of the mockup
-- with a "Makes" box: "Looks great. Proceed."). As this client sends one
-- (his record of Pattern: Filigreed Pristine Circlet and Plans: Iron Shield
-- Spike, 2026-11-17):
--   the recipe's name, and how the recipe itself binds
--   a NestedBlock line: tooltipType 0 (an item), tooltipID the made item's id
--   the made item's own lines, its name first with a line break before it
--   "Use: Teaches you how to craft ..." (ItemSpellTriggerLearn)
--   the materials on one line: "Bolt of Silk Cloth (8), Fine Thread (4)"
--   "Requires Tailoring (125)" (UsageRequirement), red where you fall short
--   "Already known", where you know it; the price
-- Read into the recipe as an item (M.ReadItem, of its own lines) with
-- `recipe` on it: { made = the made item as M.ReadItem reads it, id = its id,
-- profession, skill, short = the requirement was red, known, materials =
-- { { name, need }, ... } }. Nil for anything that is not this shape.
function M.ReadRecipe(data, shopping)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	if LT.NestedBlock == nil then
		return nil
	end
	local block, teach, madeId = nil, nil, nil
	for i, line in ipairs(data.lines) do
		if type(line) == "table" then
			local kind, left = plainLine(line.type), plainLine(line.leftText)
			if not block then
				if kind == LT.NestedBlock and type(plainLine(line.tooltipID)) == "number"
					and (plainLine(line.tooltipType) or 0) == 0 then
					block, madeId = i, plainLine(line.tooltipID)
				end
			elseif (LT.ItemSpellTriggerLearn ~= nil and kind == LT.ItemSpellTriggerLearn)
				or (type(left) == "string" and M.Bare(left):find("^Use: Teaches you")) then
				teach = i
				break
			end
		end
	end
	if not (block and teach and teach > block + 1) then
		return nil
	end
	local own, inner = {}, {}
	for i = 1, block - 1 do
		own[#own + 1] = data.lines[i]
	end
	for i = block + 1, teach - 1 do
		local line = data.lines[i]
		if type(line) == "table" and #inner == 0 then
			-- the made item's name comes with a line break before it
			local left = plainLine(line.leftText)
			if type(left) == "string" then
				local copy = {}
				for k, v in pairs(line) do
					copy[k] = v
				end
				copy.leftText = left:gsub("^%s+", "")
				line = copy
			end
		end
		inner[#inner + 1] = line
	end
	local r = { id = madeId, materials = {} }
	local known = rawget(_G, "ITEM_SPELL_KNOWN") or "Already known"
	for i = teach + 1, #data.lines do
		local line = data.lines[i]
		local kind = type(line) == "table" and plainLine(line.type)
		local left = type(line) == "table" and plainLine(line.leftText)
		local bare = type(left) == "string" and left ~= "" and M.Bare(left) or nil
		if kind ~= nil and kind == LT.SellPrice then
			own[#own + 1] = line
		elseif not bare then
			-- a blank
		elseif bare == known or bare == "Already known" then
			r.known = true
		elseif bare:find("^Requires .+ %(%d+%)$") and (LT.UsageRequirement == nil or kind == LT.UsageRequirement) then
			local profession, skill = bare:match("^Requires (.+) %((%d+)%)$")
			r.profession, r.skill, r.short = profession, tonumber(skill), isRed(colourOf(line.leftColor))
		elseif #r.materials == 0 and not bare:find("^Requires ") then
			for part in (bare .. ", "):gmatch("(.-), ") do
				local name, need = part:match("^(.-) %((%d+)%)$")
				name = (name or part):gsub("^%s+", ""):gsub("%s+$", "")
				if name ~= "" then
					r.materials[#r.materials + 1] = { name, tonumber(need) or 1 }
				end
			end
		else
			own[#own + 1] = line
		end
	end
	local made = M.ReadItem({ lines = inner }, true)
	local item = M.ReadItem({ lines = own }, shopping)
	if not (made and item) then
		return nil
	end
	made.id = madeId
	r.made = made
	-- (a trainer's: M.TrainerRecipe)
	if type(data.taught) == "string" then
		r.profession, r.trainer = data.taught, true
	end
	item.recipe = r
	return item
end

-- A RECIPE AT A TRAINER (Josh 2026-11-18, of a tailoring trainer's list: "It
-- looks like our tooltips are not showing in the crafting UI"). The trainer
-- shows a recipe as a spell with the made item inside it, and a spell with
-- anything inside it was left as the game wrote it. As this client sends
-- one (his record of Tailoring: Soft-soled Linen Boots, the same day):
--   "Tailoring: Soft-soled Linen Boots", in the game's gold
--   a blank
--   "Reagents: |nBolt of Linen Cloth (5), Light Leather (2), Fine Thread",
--     each one you are short of in red
--   a NestedBlock line: tooltipType 0 (an item), tooltipID the made item's id
--   the made item's own lines, its name first with a line break before it
-- That is a recipe's card with its parts in another order. So the lines are
-- put in the order a recipe item has them (M.ReadRecipe) and the card is
-- written as one. The name takes the made item's colour, for the band. What
-- a trainer's recipe does not say is left off: the skill it needs, and
-- whether you can learn it. Nil for anything that is not this shape.
function M.TrainerRecipe(data)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	if LT.NestedBlock == nil then
		return nil
	end
	local block = nil
	for i, line in ipairs(data.lines) do
		if type(line) == "table" and plainLine(line.type) == LT.NestedBlock and type(plainLine(line.tooltipID)) == "number"
			and (plainLine(line.tooltipType) or 0) == 0 then
			block = i
			break
		end
	end
	local head = type(data.lines[1]) == "table" and data.lines[1] or nil
	local made = block and type(data.lines[block + 1]) == "table" and data.lines[block + 1] or nil
	local name = head and plainLine(head.leftText)
	if not (block and block > 1 and made and type(name) == "string" and name ~= "") then
		return nil
	end
	local lines = {}
	local first = {}
	for k, v in pairs(head) do
		first[k] = v
	end
	first.leftColor = made.leftColor or head.leftColor
	lines[1] = first
	-- what it is made of: the one line before the item with a list in it
	local materials = nil
	for i = 2, block - 1 do
		local left = type(data.lines[i]) == "table" and plainLine(data.lines[i].leftText)
		if type(left) == "string" and left:find("|n", 1, true) then
			materials = M.Bare((left:gsub("^.-|n", ""))):gsub("^%s+", "")
		end
	end
	for i = block, #data.lines do
		lines[#lines + 1] = data.lines[i]
	end
	lines[#lines + 1] = { type = LT.ItemSpellTriggerLearn, leftText = "Use: Teaches you" }
	if materials and materials ~= "" then
		lines[#lines + 1] = { leftText = materials }
	end
	local out = {}
	for k, v in pairs(data) do
		out[k] = v
	end
	out.lines = lines
	out.id = plainLine(data.lines[block].tooltipID)
	-- ("Tailoring: Soft-soled Linen Boots": the profession is before the colon)
	out.taught = name:match("^(.-):%s") or ""
	return out
end

-- Your rank in a profession, by its name, and whether the game could be
-- asked at all. Nil and true: asked, and you do not have it.
function M.ProfessionRank(name)
	local count, info = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
	if type(count) ~= "function" or type(info) ~= "function" then
		return nil, false
	end
	local ok, n = pcall(count)
	n = ok and plainLine(n) or nil
	for i = 1, type(n) == "number" and n or 0 do
		local okLine, skill, header, _, rank = pcall(info, i)
		if okLine and plainLine(skill) == name and not plainLine(header) then
			return plainLine(rank), true
		end
	end
	return nil, true
end

-- What a recipe's one tag says, and whether you have its profession:
-- "Already known", "Can learn", or why you cannot.
function M.RecipeState(r)
	-- (a trainer's recipe says nothing of whether you can learn it)
	if r.trainer then
		return nil, true
	end
	local rank, asked = nil, false
	if r.profession then
		rank, asked = M.ProfessionRank(r.profession)
	end
	local have = type(rank) == "number" or (not asked and not r.short)
	if r.known then
		return { "Already known", "quiet" }, true
	elseif not r.short and have then
		return { "Can learn", "good" }, true
	elseif r.profession and asked and type(rank) ~= "number" then
		return { "Needs " .. r.profession, "warn" }, false
	elseif r.profession then
		return { ("Needs %s %s"):format(r.profession, tostring(r.skill or "")):gsub("%s+$", ""), "warn" }, have
	end
	return nil, have
end

-- how many of an item are in your bags, by its name; nil where the game
-- will not say
function M.Carried(name)
	local get = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
	if type(get) ~= "function" then
		return nil
	end
	local ok, n = pcall(get, name)
	n = ok and plainLine(n) or nil
	return type(n) == "number" and n or nil
end

-- a line's text colour as three numbers, where the client lets us read it
local function inkOf(fs)
	if not (fs and fs.GetTextColor) then
		return nil
	end
	local ok, r, g, b = pcall(fs.GetTextColor, fs)
	r, g, b = ok and plainLine(r), ok and plainLine(g), ok and plainLine(b)
	if type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return { r, g, b }
	end
	return nil
end

-- OTHER ADDONS' LINES COME ALONG (2026-10-17, audit). An addon that loaded
-- before BeebMod adds its lines (an auction price) in its own post call,
-- which runs before ours, and the rebuild's clear took them away. They are
-- the lines after the last one the client's data drew, read before the
-- clear, each { text, rgb, right, rrgb } in its own colours; nil for none.
function M.OthersLines(tip, data)
	if not (tip and tip.NumLines and type(data) == "table" and type(data.lines) == "table") then
		return nil
	end
	local most = 0
	for _, line in ipairs(data.lines) do
		local i = type(line) == "table" and plainLine(line.lineIndex) or nil
		if type(i) == "number" and i > most then
			most = i
		end
	end
	-- data that says nothing of where its lines went says nothing of these
	if most == 0 then
		return nil
	end
	local out = nil
	for i = most + 1, BT.Pill.Number(tip:NumLines(), 0) do
		local left, right = lineOf(tip, i), lineOf(tip, i, "TextRight")
		local text = left and left.GetText and plainLine(left:GetText())
		if type(text) == "string" and text:find("%S") and text ~= BT.UnitTip.TAG_BLANK then
			local row = { text = text, rgb = inkOf(left) }
			local said = right and right.IsShown and right:IsShown() and right.GetText and plainLine(right:GetText())
			if type(said) == "string" and said:find("%S") then
				row.right, row.rrgb = said, inkOf(right)
			end
			out = out or {}
			out[#out + 1] = row
		end
	end
	return out
end

-- WHAT A POTION, BANDAGE OR DRINK DOES, AS A FIGURE (Josh 2026-10-17, choosing
-- "Give potions, food and bandages the spell figures"): from its Use line, as
-- a spell's from its description. One that works over time, a second of it
-- ("Heals 66 damage over 6 sec": 11.0 HPS); one that does it at once, the
-- middle of what it does ("Restores 140 to 180 health": 160 HEALING). Nil
-- where it says no amount.
function M.UseFigures(item)
	local use = M.UseAmount(item)
	if use then
		local word, ink = M.PerSecond(use.label)
		if type(use.over) == "number" and use.over > 0 then
			return { { M.Figure(use.amount / use.over), word, ink } }
		elseif not use.over then
			return { { M.Middle(use.amount), use.label, ink } }
		end
	end
	return nil
end

-- A USE LINE'S COOLDOWN, as the client adds it to the line: "(2 Min
-- Cooldown)" (ITEM_COOLDOWN_TOTAL), the words in it captured
function M.CooldownPattern()
	local form = M.Bare(type(_G.ITEM_COOLDOWN_TOTAL) == "string" and _G.ITEM_COOLDOWN_TOTAL or "(%s Cooldown)")
	local holes = form:gsub("%%[%-%d%.]*[sd]", "\1")
	local escaped = holes:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return "%s*" .. escaped:gsub("\1", "([^()]-)") .. "%s*$"
end

-- A Use line without its cooldown, and the cooldown's words ("2 Min"), or
-- nil for none
function M.WithoutCooldown(text)
	local p = M.CooldownPattern()
	local said = text:match(p)
	if not said then
		return text, nil
	end
	return (text:gsub(p, "")), said
end

-- What the first Use line that says an amount does, as M.SpellAmount reads
-- it, without its cooldown: { effect, label, value, amount, over, after },
-- or nil where none says one
function M.UseAmount(item)
	for _, e in ipairs(item.effects or {}) do
		if e.head == "Use" then
			local text = M.WithoutCooldown(e.text)
			local label, value, amount, over, _, after = M.SpellAmount(text)
			if label and amount then
				return { effect = e, text = text, label = label, value = value, amount = amount, over = over, after = after }
			end
		end
	end
	return nil
end

-- THE TWO FIGURES AT THE RIGHT, AS A SPELL'S (Josh 2026-10-18, picking
-- option 1: "Instead of "Item Level" we can just use "ilvl""): beside the
-- name, a weapon's DPS in red, armour's armor in the body's ink, or what a
-- potion's Use line comes to (M.UseFigures); beside the line under it, the
-- item level. Only what the item has: figures for c.header, or nil for
-- neither.
-- IN CAPITALS, AS ITS NEIGHBOURS (Josh 2026-10-18: "Let's go with ILVL"):
-- it was "ilvl", as players write it, beside DPS and ARMOR.
function M.ItemFigures(item, level)
	local figs = {}
	if item.dps then
		figs[1] = { item.dps, "DPS", M.FIGURE_INK.dps }
	elseif item.armor then
		figs[1] = { item.armor, "Armor", ITEM_INK }
	else
		local use = M.UseFigures(item)
		figs[1] = use and use[1] or nil
	end
	if level then
		figs[2] = { tostring(level), "ilvl", M.FIGURE_INK.level }
	end
	if figs[1] or figs[2] then
		return figs
	end
	return nil
end

-- what an amount is of, in a potion's cell: "70–90 health", as its line
-- says; anything else as a spell's cell says it ("47 absorb")
local USE_WORDS = { Healing = "health" }

-- a number as the cells write it: thousands marked, a decimal left be
local function commas(value)
	if value:find("%.") then
		return value
	end
	return (value:gsub(",", ""):gsub("%d+", U.Commas))
end

-- THE FACTS IN CELLS, AS A SPELL'S (option 1): what it does in a fight, a
-- weapon's damage and speed, or a potion's amount and cooldown; then how it
-- binds (BoE and BoP as players write them, "soulbound" as a word) and the
-- level it asks for. Only what the item has. Returns the facts for
-- M.FactCells, the Use line the cells say all of (or nil), and the Use
-- line whose cooldown is in a cell (or nil).
function M.ItemFacts(item)
	local facts = {}
	local function add(text, rgb, lower)
		facts[#facts + 1] = { text = text, rgb = rgb, lower = lower }
	end
	if item.damage then
		-- a wand's names its school: "17–32 fire damage"
		add(("%s %sdamage"):format(item.damage, item.school and (item.school:lower() .. " ") or ""))
	end
	if item.speed then
		add(item.speed .. " speed")
	end
	-- armor on a weapon, whose figure is its DPS; a shield's block
	if item.armor and item.dps then
		add(item.armor .. " armor")
	end
	if item.block then
		add(item.block .. " block")
	end
	local said = nil
	local use = M.UseAmount(item)
	if use then
		add(("%s %s%s"):format(commas(use.value), USE_WORDS[use.label] or use.label:lower(),
			type(use.over) == "number" and (" over " .. M.Lasting(use.over)) or ""))
		-- A USE LINE THAT SAYS NO MORE GOES, as a spell's description does
		-- (M.SaysNoMore): "Restores 70 to 90 health." is all in the cells
		if M.SaysNoMore(use.text, use.after) then
			said = use.effect
		end
	end
	local timed = nil
	for _, e in ipairs(item.effects) do
		local cooldown = e.head == "Use" and select(2, M.WithoutCooldown(e.text))
		if cooldown then
			add(cooldown .. " cooldown", nil, true)
			timed = e
			break
		end
	end
	if item.require then
		add(M.Bare(item.require.text), warning(item.require.rgb), true)
	end
	return facts, said, timed
end

-- HOW IT BINDS, AS A TAG UNDER WHAT IT IS (Josh 2026-10-18: ""Soulbound",
-- "BoE" and "BoP" should be moved out of the grid somehow, and placed as a
-- tag under the item type. Maybe increase the icon size a bit so everything
-- lines up... This will allow us to remove the grid on non equipment items").
-- An apple's only cell was "soulbound". The binding (BoE, BoP as players
-- write them; Soulbound a word) and whether it is unique are outlined tags
-- on a line of their own under the kind and slot, and the icon grows to the
-- three lines. Each { words, look, keepCase } for T.TagsOnLine.
M.CANT_USE = "Can't use"
function M.ItemTags(item)
	local tags = {}
	-- FIRST, IN RED, WHERE THE CLIENT SAID SO IN RED (Josh 2026-10-23: "we
	-- are not showing the tag for items the player cannot use... I cannot use
	-- two handed maces as a rogue")
	if item.unusable then
		tags[#tags + 1] = { M.CANT_USE, "warn" }
	end
	if item.bind then
		local short = M.BindShort(item.bind)
		tags[#tags + 1] = { short or item.bind, "bound", keepCase = short ~= nil }
	end
	if item.unique then
		tags[#tags + 1] = { item.unique, "bound" }
	end
	return tags
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
-- line; nil where the client will not say.
-- THE SUBCLASS ALONE (Josh 2026-10-18, picking option 1, whose potion says
-- "Potion"): a weapon's line says "Axe", not "Weapon · Axe", so a potion's
-- says "Potion" and a bandage's "Bandage"; the class where there is no
-- subclass
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
	for _, words in ipairs({ plainLine(sub) or false, plainLine(kind) or false }) do
		if type(words) == "string" and words ~= "" then
			return { words }
		end
	end
	return nil
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

-- ours on each tooltip: the icon and its edge, the figures, the cells and
-- the bar, made the first time a card is written on it
local bitsOf = setmetatable({}, { __mode = "k" })

-- THE PARTS GO WITH THEIR CARD (Josh 2026-10-23: the tooltips were "showing
-- the previous hovered item instead of the current. The icon was also moved
-- to the left of the tooltip frame"; his screenshot had an epic item's icon
-- beside a Gnarlpine Defender's tooltip, outside its edge). The parts are
-- hidden when the tooltip is cleared or hides, and one time that night they
-- were not: they stayed over the next thing shown, and the icon, hung off a
-- name line that was no longer moved in to make room for it, sat outside
-- the card. So they look for themselves, each frame they are shown: while
-- the tooltip's first line is not the name their card wrote, they go.
-- true while `tip` still shows the card its parts `b` were laid for
function M.CardShown(tip, b)
	if not (b and b.name and tip and tip.NumLines and BT.Pill.Number(tip:NumLines(), 0) > 0) then
		return false
	end
	local fs = BT.UnitTip.LineOf(tip, 1)
	if not (fs and fs.GetText) or (fs.IsShown and not fs:IsShown()) then
		return false
	end
	local text = fs:GetText()
	if issecretvalue and issecretvalue(text) then
		return false
	end
	return text == b.name
end
-- how many times the parts outlived their card and were taken off by the
-- watch, not by the clear or the hide (What loaded, M.Status)
M.leftovers = 0
function M.WatchParts(holder)
	local tip = holder.tip
	if tip and not M.CardShown(tip, bitsOf[tip]) then
		M.leftovers = M.leftovers + 1
		M.HideItemBits(tip)
	end
end

function M.ItemBits(tip)
	local b = bitsOf[tip]
	if b then
		return b
	end
	b = {}
	b.holder = CreateFrame("Frame", nil, tip)
	-- ours: the comparison tooltip's tab is looked for among its children
	-- (restyleTab), and this is not it
	b.holder.beebs = true
	b.holder.tip = tip
	-- only while it is shown, so only while a card is up
	b.holder:SetScript("OnUpdate", M.WatchParts)
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
	-- the two figures at the right of the name and the line under it, each a
	-- number and its label; and the facts' cells, made as they are wanted
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
	if M.HideTilesBits then
		M.HideTilesBits(b)
	end
	b.holder:Hide()
end
BT.UnitTip.OnGone(M.HideItemBits)

-- a figure's label as it is drawn: in capitals, or as written where it
-- keeps its case
local function figLabel(f)
	return f.keepCase and f[2] or f[2]:upper()
end

-- THE PIECES EVERY CARD IS WRITTEN WITH (Josh 2026-10-17: "I'd like a
-- cohesive tooltip look across the board", then "Yes, spell and buff
-- tooltips should get the same look"). An item, a spell and a buff are
-- written alike: the name with a line under it beside the icon, two
-- figures at their right, the facts in cells, then rows, laid on `tip`
-- from its first line.
-- NO HEADINGS AND NO TILES ANY MORE (Josh 2026-10-18, picking option 1 for
-- the items: the spell card's look): the items were the last to use them.
local function card(tip)
	local T, I = BT.UnitTip, M.ITEM
	local b = M.ItemBits(tip)
	M.ClearLines(tip)
	T.HideTags(tip)
	M.HideItemBits(tip)
	-- the name this card writes, once its header does (M.CardShown)
	b.name = nil
	b.holder:Show()
	local c = { b = b, off = 0 }
	function c.last()
		return BT.Pill.Number(tip:NumLines(), 1)
	end
	function c.spacer()
		tip:AddLine(" ")
		T.SizeLine(tip, c.last(), I.SPACER, nil, "text")
	end
	-- Facts in cells, in rows no wider than `inner`, on a line kept for
	-- them as tall as the rows; each item { shown words, plain words }
	function c.cells(items, inner)
		local rows, row, used = {}, {}, 0
		for _, it in ipairs(items) do
			local w = math.ceil(T.Measure(it[2], I.SUB, "text")) + 2 * I.CELL_PAD + 1
			-- `newRow` on an item starts a row whatever room is left
			if #row > 0 and (used + w > inner or it.newRow) then
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
	-- the right of the line under it, each { number, label, ink, keepCase };
	-- either may be missing. The lines keep a blank at their right, as tall
	-- as the line, for the figures to be laid against (c.finish).
	-- `tags`, where there are any, are a row of tags on a third line, under
	-- the line under the name, and the icon is as tall as the three (M.ItemTags)
	function c.header(name, rgb, icon, sub, edge, figs, tags)
		b.name = name
		c.tags = (tags and #tags > 0) and tags or nil
		local size = (c.tags or c.tall) and I.ICON_TALL or I.ICON
		c.off = icon and (size + I.ICON_GAP) or 0
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
			if said or icon or c.tags then
				tip:AddLine(said and sub or " ", ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3], false, c.off)
				T.SizeLine(tip, 2, I.SUB, nil, "text")
			end
		end
		if c.tags then
			tip:AddLine(T.TAG_BLANK, 1, 1, 1, false, c.off)
			c.tagLine = c.last()
			T.SizeLine(tip, c.tagLine, T.TAG_LINE + 2, nil, "text")
			T.TagsOnLine(tip, c.tagLine, c.tags)
		end
		if icon then
			local fs = T.LineOf(tip, 1)
			local e = edge or rgb
			b.icon:SetTexture(icon)
			b.icon:ClearAllPoints()
			b.icon:SetPoint("TOPLEFT", fs, "TOPLEFT", -c.off, 1)
			b.icon:SetSize(size, size)
			b.edge:SetColorTexture(e[1], e[2], e[3], 0.9)
			b.icon:SetShown(fs ~= nil)
			b.edge:SetShown(fs ~= nil)
		end
	end
	-- How wide the name and the line under it need the card, each with its
	-- figure at its right (after c.header, which sets the icon's room)
	function c.needs(name, sub, figs)
		local Measure = T.Measure
		-- the tags' row, if there is one, wants its room too
		local tagsW = 0
		for i, tag in ipairs(c.tags or {}) do
			tagsW = tagsW + T.TagWidth(tag[1], tag.keepCase) + (i > 1 and T.TAG_GAP or 0)
		end
		if not figs then
			c.headNeeds = math.max(Measure(name, I.NAME, "name"), tagsW) + c.off + 24
			return c.headNeeds
		end
		local function fig(i, size)
			local f = figs[i]
			return f and (Measure(f[1], size, "text") + I.FIG_GAP + Measure(figLabel(f), I.FIG_LABEL, "name")) or 0
		end
		c.headNeeds = math.max(Measure(name, I.NAME, "name") + fig(1, I.HEADLINE),
			Measure(sub or "", I.SUB, "text") + fig(2, I.FIG_SMALL), tagsW) + c.off + 24 + 12
		return c.headNeeds
	end
	-- As wide as `needs`, never narrower than `floor`; shown, so it has a
	-- width; then the figures and cells laid by that width. Returns it.
	function c.finish(floor, needs)
		if tip.SetMinimumWidth then
			-- the rest wraps at MAX_W; the header, which cannot, up to HEAD_MAX_W
			local head = math.min(HEAD_MAX_W, c.headNeeds or 0)
			pcall(tip.SetMinimumWidth, tip, math.floor(math.max(floor, math.min(MAX_W, needs), head)))
		end
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
		local inner = BT.Pill.Number(tip.GetWidth and tip:GetWidth(), floor) - I.INSET
		inner = math.max(floor - I.INSET, inner)
		-- the tall icon from the name's top to the tags' foot, where the client
		-- says where they are, within a few points of the room kept for it
		if c.tagLine and b.icon:IsShown() then
			local top, foot = T.LineOf(tip, 1), T.LineOf(tip, c.tagLine)
			local t = top and top.GetTop and BT.Pill.Number(top:GetTop(), nil)
			local f = foot and foot.GetBottom and BT.Pill.Number(foot:GetBottom(), nil)
			if t and f and t > f then
				local s = math.max(I.ICON, math.min(I.ICON_TALL + 2, math.floor(t - f + 1.5)))
				b.icon:SetSize(s, s)
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
				g.label:SetText(figLabel(f))
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
			-- ONE SCREEN PIXEL, NOT ONE UNIT (Josh 2026-10-18: "the bottom
			-- border of the first row of the grid looks like it is 2px. Can we
			-- make sure the border is a uniform 1px on all cells?"): at a scale
			-- where a unit is a little more than a pixel, a line one unit thick
			-- covered two rows of pixels wherever it landed across them. Every
			-- line is one pixel at the scale the tooltip is drawn at, as the
			-- panels' rims are (UI/Pill.lua, P.Px).
			local one = BT.Pill.Px(b.holder, 1) or 1
			local nLine, nText = 0, 0
			local function rule(x, y, w, h)
				nLine = nLine + 1
				local t = b.cellLines[nLine]
				if not t then
					t = b.holder:CreateTexture(nil, "ARTWORK")
					BT.Pill.Snap(t)
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
				rule(0, y, inner, one)
				local natural = 0
				for _, cell in ipairs(row) do
					natural = natural + cell.w
				end
				local extra = math.max(0, inner - natural) / #row
				local x = 0
				for k, cell in ipairs(row) do
					local left = math.floor(x + 0.5)
					if k > 1 then
						rule(left, y, one, cr.h + one)
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
			rule(0, tall, inner, one)
			rule(0, 0, one, tall + one)
			rule(inner - one, 0, one, tall + one)
		end
		return inner
	end
	return c
end
M.Card = card

-- ---------------------------------------------------------------------------
-- THE ITEM CARD, DRAWN AGAIN FROM NOTHING (Josh 2026-11-16: "I would like to
-- completely redesign our tooltips from scratch... We've added quite a bit to
-- the tooltips, and the UX has become a bit bad and hard to follow... We can
-- disregard any previous rules and work related to the tooltips"; of the
-- canvas's three directions, "I like option B").
--
-- Every tooltip reads in five zones, top to bottom:
--   1. what it is     a band in its quality's colour: icon, name, kind and
--                     slot, and its item level large at the right
--   2. the answer     tiles: another addon's numbers for it (BeebMod:
--                     Upgrades' tank, healer and DPS), one row of tiles for
--                     each piece it could replace
--   3. the facts      its stats, two to a row. An Equip line that only
--                     adds stats is a stat here and not a sentence (his "ok")
--   4. the words      what it does beyond stats, and its flavour
--   5. the foot       a darker strip: how worn, how it binds, what it sells
--                     for. Other addons' lines sit over it in the quiet ink,
--                     without their own colours (his "ok")
--
-- The old card (M.WriteItem) stays under it: if this one fails part way the
-- old one is written, so a fault here costs the look and not the tooltip.
M.TILES_LOOK = true
-- NEARER THE MOCKUP (Josh 2026-11-16, of the first build beside the canvas:
-- "Looks a bit off from the mockups"): the icon as tall as the band, the
-- level and the tiles' numbers in the bold face and larger, more air
-- between the zones, and the band and the foot strip no taller than they
-- should be (both had covered the whole tooltip: M.LayBand, M.LayStrip).
-- AND AGAIN (Josh 2026-11-16, of the second build: "Better, but some font
-- sizes, border radius, and spacing still seems off", and "we arent showing
-- item tags, like soulbound, binds when equipped"): the name and the line
-- under it larger, the tiles with the toolkit's rounded corners (M.TileBack),
-- a line more between the zones, and how it binds back as a tag under what
-- it is, where the eye looks for it, and out of the foot.
M.B = { TILE_H = 40, TILE_H2 = 56, TILE_GAP = 5, STAT_H = 17, GRID_H = 14, COL_GAP = 14, LEVEL = 19, BIG = 15,
	ROW = 11.5, HEAD_GAP = 14, BAND = 0.24, STRIP = 0.38, NAME = 15, SUB = 11, TILE_FILL = { 1, 1, 1, 0.055 },
	CAP = 300, CAP_WORN = 270, NAME_LEAST = 11, HEAD_GAP_BARE = 30, BOX_PAD = 5,
	-- THE FOOT, NEARER THE MOCKUP (Josh 2026-11-16: "can you adjust the
	-- spacing/padding in the footer so it looks more like the mock?"): its
	-- words a size larger, the bar a pixel thicker, and the strip with room
	-- over and under them where it had hugged them
	FOOT = 10, FOOT_UNDER = 0, STRIP_PAD = 5, BAR_H = 4, NAME_WORN = 15, FOOT_TRIM = -5, BAND_H = 60, UNDER_H = 12,
	-- a recipe's made item: its name, its picture beside it, and a tile's
	-- fill where the tile sits in the box (darker, as the box has the tiles'
	-- own fill)
	MADE_NAME = 12.5, MADE_ICON = 14, TILE_FILL_IN = { 0, 0, 0, 0.32 } }

-- A tile's back: a frame of its own with the toolkit's one shape on it (its
-- rounded corners), or a flat square where that cannot be made
function M.TileBack(b, i)
	b.tileBacks = b.tileBacks or {}
	local f = b.tileBacks[i]
	if not f then
		f = CreateFrame("Frame", nil, b.holder)
		f.beebs = true
		local ok, surface = pcall(BT.Pill.Surface, f, "BACKGROUND", 0)
		f.surface = ok and surface or nil
		if not f.surface then
			f.flat = f:CreateTexture(nil, "BACKGROUND")
			f.flat:SetAllPoints(f)
		end
		b.tileBacks[i] = f
	end
	f:ClearAllPoints()
	f:Show()
	return f
end
function M.PaintTileBack(f, fill)
	if f.surface and pcall(BT.Pill.PaintSurface, f.surface, f, fill, { 0, 0, 0, 0 }) then
		return
	end
	if not f.flat then
		f.flat = f:CreateTexture(nil, "BACKGROUND")
		f.flat:SetAllPoints(f)
	end
	f.flat:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
	f.flat:Show()
end

-- A ROW OF TILES ON A UNIT'S TOOLTIP, FOR ANOTHER MODULE (Josh 2026-11-17,
-- working down what was left of the redesign: the canvas's player has the
-- Ledger's rating, groups and duels as three tiles, and they were still
-- rows). A module asks for the row as it writes its part of the tooltip;
-- the tiles are laid once every module has had its turn and the tooltip
-- has its width (the hook at order 99, with M.UnitLookEnd).
--   tiles = { { value = "4 / 5", label = "Rating", rgb = nil }, ... }
-- Returns the line kept for them, or nil where the look is off or the
-- tooltip has no pieces of ours (then the module writes its rows).
M.UNIT_TILES_INSET = 10
function M.UnitTiles(tip, tiles)
	local u = tip and unitBits[tip]
	if not (M.TILES_LOOK and u and type(tiles) == "table" and #tiles > 0 and tip.AddLine and BT.Enabled("tooltips")) then
		return nil
	end
	local T = BT.UnitTip
	tip:AddLine(T.TAG_BLANK)
	local line = BT.Pill.Number(tip:NumLines(), 1)
	T.SizeLine(tip, line, lineFor(M.B.TILE_H), nil, "text")
	u.tiles = { line = line, list = tiles }
	return line
end
function M.LayUnitTiles(tip)
	local u = tip and unitBits[tip]
	local set = u and u.tiles
	if not set then
		return 0
	end
	local T, B, I = BT.UnitTip, M.B, M.ITEM
	local at = T.LineOf(tip, set.line)
	if not at then
		return 0
	end
	local left = BT.Pill.Number(at.GetLeft and at:GetLeft(), nil)
	local right = BT.Pill.Number(tip.GetRight and tip:GetRight(), nil)
	local inner = (left and right and right - left > 60) and (right - left - M.UNIT_TILES_INSET) or 180
	u.tb = u.tb or { holder = tip }
	local n = #set.list
	local w = (inner - B.TILE_GAP * (n - 1)) / n
	for i, t in ipairs(set.list) do
		local bg = M.TileBack(u.tb, i)
		bg:SetPoint("TOPLEFT", at, "TOPLEFT", math.floor((i - 1) * (w + B.TILE_GAP) + 0.5), 0)
		bg:SetSize(math.floor(w), B.TILE_H - 2)
		M.PaintTileBack(bg, B.TILE_FILL)
		bg.num = bg.num or bg:CreateFontString(nil, "OVERLAY")
		bg.cap = bg.cap or bg:CreateFontString(nil, "OVERLAY")
		local ink = t.rgb or ITEM_INK
		BT.Fonts.Set(bg.num, "name", B.BIG)
		bg.num:SetText(tostring(t.value or ""))
		bg.num:SetTextColor(ink[1], ink[2], ink[3])
		bg.num:ClearAllPoints()
		bg.num:SetPoint("TOP", bg, "TOP", 0, -7)
		BT.Fonts.Set(bg.cap, "name", I.FIG_LABEL)
		bg.cap:SetText(tostring(t.label or ""):upper())
		bg.cap:SetTextColor(ITEM_HEAD[1], ITEM_HEAD[2], ITEM_HEAD[3])
		bg.cap:ClearAllPoints()
		bg.cap:SetPoint("TOP", bg.num, "BOTTOM", 0, -3)
	end
	for i = n + 1, #(u.tb.tileBacks or {}) do
		u.tb.tileBacks[i]:Hide()
	end
	return n
end

-- THE BAND AND THE STRIP, EACH A HEIGHT AND NOT THREE ANCHORS. They were
-- pinned to the tooltip's top left, its right middle and a line's bottom,
-- which is one anchor too many: the client made each as tall as the whole
-- tooltip, and the card came out one flat tint. Now each hangs from two
-- corners and is given the height measured between them.
-- THE SAME SPACE UNDER THE TAGS ON EVERY CARD (Josh 2026-11-16, of two cards
-- side by side: "The item tags don't have consistent spacing under them").
-- The band ended a fixed distance under the icon. The icon is at most 42
-- tall, and a name at full size with the line under it and the tags is
-- taller than that, so on such a card the tags ran to the band's edge, while
-- a card whose long name was set smaller had room to spare. The band now
-- ends the same distance under whichever is lower, the icon or `foot2` (the
-- tags' line).
function M.LayBand(tip, b, q, foot, foot2)
	if not tip.CreateTexture then
		return
	end
	b.band = b.band or tip:CreateTexture(nil, "BORDER")
	local top = BT.Pill.Number(tip.GetTop and tip:GetTop(), nil)
	local low = foot and BT.Pill.Number(foot.GetBottom and foot:GetBottom(), nil)
	local low2 = foot2 and BT.Pill.Number(foot2.GetBottom and foot2:GetBottom(), nil)
	if low and low2 then
		low = math.min(low, low2)
	else
		low = low or low2
	end
	-- ONE HEIGHT, MEASURED FROM NOTHING (Josh 2026-11-16, a third time of
	-- three cards side by side: "Headers still don't have a consistent
	-- height"). The band's height was worked out on each card from where its
	-- icon and its tags had come to rest, and the icon's own size from where
	-- its lines had (c.finish), each rounded to a pixel: a card could come
	-- out a pixel or two off its neighbour. The band is M.B.BAND_H tall on
	-- every card now, with tags or without, and the icon one size.
	local h = M.B.BAND_H or ((top and low and top > low) and (top - low + 7) or (M.ITEM.ICON_TALL + 14))
	b.band:ClearAllPoints()
	b.band:SetPoint("TOPLEFT", tip, "TOPLEFT", 1, -1)
	b.band:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -1, -1)
	b.band:SetHeight(h)
	b.band:SetColorTexture(q[1], q[2], q[3], M.B.BAND)
	b.band:Show()
end
-- from just above `from` down to the tooltip's foot, or to just above `till`
function M.LayStrip(tip, b, from, till)
	if not (tip.CreateTexture and from) then
		return
	end
	b.strip = b.strip or tip:CreateTexture(nil, "BORDER")
	b.stripFrom = from
	local foot = BT.Pill.Number(tip.GetBottom and tip:GetBottom(), nil)
	local top = BT.Pill.Number(from.GetTop and from:GetTop(), nil)
	local stop = till and BT.Pill.Number(till.GetTop and till:GetTop(), nil)
	if not (foot and top and top > foot) then
		b.strip:Hide()
		return
	end
	local low = stop and (stop + 5 - foot) or 1
	b.strip:ClearAllPoints()
	b.strip:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1, low)
	b.strip:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -1, low)
	b.strip:SetHeight(math.max(1, top + M.B.STRIP_PAD - foot - low))
	b.strip:SetColorTexture(0, 0, 0, M.B.STRIP)
	b.strip:Show()
end

-- a texture or some words of the card's own, handed out again each time
local function bTex(b)
	b.nTex = (b.nTex or 0) + 1
	b.bTex = b.bTex or {}
	local t = b.bTex[b.nTex]
	if not t then
		t = b.holder:CreateTexture(nil, "ARTWORK")
		if BT.Pill and BT.Pill.Snap then
			BT.Pill.Snap(t)
		end
		b.bTex[b.nTex] = t
	end
	t:ClearAllPoints()
	t:Show()
	return t
end
local function bSay(b, text, rgb, size, number, role)
	b.nFs = (b.nFs or 0) + 1
	b.bFs = b.bFs or {}
	local fs = b.bFs[b.nFs]
	if not fs then
		fs = b.holder:CreateFontString(nil, "OVERLAY")
		b.bFs[b.nFs] = fs
	end
	local face = number and BT.Tip and BT.Tip.NUMBER
	if not (face and pcall(fs.SetFont, fs, face, BT.Fonts.Size(size), "")) then
		BT.Fonts.Set(fs, role or "text", size)
	end
	fs:SetText(text)
	fs:SetTextColor(rgb[1], rgb[2], rgb[3])
	fs:ClearAllPoints()
	fs:Show()
	return fs
end
-- all of them off (M.HideItemBits)
function M.HideTilesBits(b)
	for _, t in ipairs(b.bTex or {}) do
		t:Hide()
	end
	for _, fs in ipairs(b.bFs or {}) do
		fs:Hide()
	end
	b.nTex, b.nFs = 0, 0
	for _, f in ipairs(b.tileBacks or {}) do
		f:Hide()
	end
	b.nBack = 0
	if b.band then
		b.band:Hide()
	end
	if b.strip then
		b.strip:Hide()
	end
end

local UP_INK, DOWN_INK = { 0.44, 0.86, 0.55 }, { 1, 0.54, 0.40 }

-- the slot a piece goes in, where there is only one it could
local ONE_SLOT = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16, INVTYPE_2HWEAPON = 16, INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17,
	INVTYPE_WEAPONOFFHAND = 17, INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}
-- what you wear where `link` would go; nil for a ring or trinket (two
-- places), for the piece itself, and for what is not worn at all
function M.WornFor(link)
	if type(link) ~= "string" or not (C_Item and C_Item.GetItemInfoInstant and GetInventoryItemLink) then
		return nil
	end
	local ok, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, link)
	local slot = ok and ONE_SLOT[loc]
	local worn = slot and GetInventoryItemLink("player", slot)
	if type(worn) ~= "string" or worn == link then
		return nil
	end
	return worn
end

local STAT_ORDER = { "RESISTANCE0_NAME", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT" }
local STAT_PRIMARY = {}
for _, k in ipairs(STAT_ORDER) do
	STAT_PRIMARY[k] = true
end
local STAT_SKIP = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = true }

local function plainNumber(v)
	return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end
local function amount(v, plus)
	local s = v == math.floor(v) and ("%d"):format(v) or ("%.1f"):format(v)
	return (plus and v > 0) and ("+" .. s) or s
end

-- THE FACTS, AS NUMBERS WITH A WORD: weapon DPS, damage, speed, block, what
-- a Use gives, then the stats the game lists for the item (C_Item.
-- GetItemStats). Where the game lists none, the client's own
-- stat lines are split into number and word. Also returns the Use line the
-- facts say all of, the Use line whose cooldown is a fact, and the Equip
-- lines that are stats and nothing else.
function M.StatList(item)
	local list = {}
	local function add(num, label, key)
		list[#list + 1] = { num = num, label = label or "", key = key }
		return list[#list]
	end
	local used = {}
	if item.dps then
		add(tostring(item.dps), "DPS")
	end
	local facts, said, timed = M.ItemFacts(item)
	local need = item.require and M.Bare(item.require.text) or nil
	for _, f in ipairs(facts) do
		if f.text ~= need then
			local text = f.lower and f.text:lower() or f.text
			local num, label = text:match("^(%S+)%s+(.+)$")
			if num then
				if label:lower() == "armor" then
					used.RESISTANCE0_NAME = true
				end
				add(num, label:sub(1, 1):upper() .. label:sub(2))
			else
				add(text, "")
			end
		end
	end
	local ok, stats = false, nil
	if type(item.link) == "string" and C_Item and C_Item.GetItemStats then
		ok, stats = pcall(C_Item.GetItemStats, item.link)
	end
	local values, isStats = {}, {}
	if ok and type(stats) == "table" and next(stats) ~= nil then
		-- THE ITEM'S OWN STATS AND NOTHING BESIDE THEM (Josh 2026-11-16: "On
		-- second thought, I think we should just show the item stats, not the
		-- comparison numbers. We can just use the 3 tiles (tank, healer, dps)
		-- for the quick comparison"). Each stat had its change against the
		-- worn piece at its right, and a grey 0 for a stat only the worn piece
		-- has. Both are gone: the tiles are the comparison.
		local delta = nil
		local keys, seen = {}, {}
		for _, k in ipairs(STAT_ORDER) do
			keys[#keys + 1], seen[k] = k, true
		end
		local others = {}
		for k in pairs(stats) do
			if type(k) == "string" and not seen[k] then
				others[#others + 1] = k
			end
		end
		for k in pairs(delta or {}) do
			if type(k) == "string" and not seen[k] and stats[k] == nil then
				others[#others + 1] = k
			end
		end
		table.sort(others)
		for _, k in ipairs(others) do
			keys[#keys + 1] = k
		end
		for _, k in ipairs(keys) do
			local v, dv = stats[k], delta and delta[k]
			if not STAT_SKIP[k] and not used[k] then
				local name = type(_G[k]) == "string" and _G[k] or k
				if plainNumber(v) and v ~= 0 then
					local e = add(amount(v, k ~= "RESISTANCE0_NAME"), name, k)
					e.delta = plainNumber(dv) and dv ~= 0 and dv or nil
					if not STAT_PRIMARY[k] then
						values[amount(v)] = true
					end
				elseif plainNumber(dv) and dv ~= 0 then
					local e = add("0", name, k)
					e.dim, e.delta = true, dv
				end
			end
		end
		-- an Equip line every number of which is one of those stats
		for _, e in ipairs(item.effects) do
			if e.head == "Equip" and type(e.text) == "string" then
				local words = e.text:gsub("per 5 sec", ""):gsub(",", "")
				local any, all = false, true
				for n in words:gmatch("%d[%d%.]*") do
					n = n:gsub("%.$", "")
					any = true
					all = all and values[n] == true
				end
				if any and all then
					isStats[e] = true
				end
			end
		end
	else
		if item.armor and not item.dps then
			add(tostring(item.armor), "Armor")
		end
		for _, s in ipairs(item.stats) do
			local num, label = tostring(s.text):match("^([%+%-]?[%d%.,]+)%s+(.+)$")
			add(num or tostring(s.text), label)
		end
	end
	return list, said, timed, isStats
end

-- Writes `item` on `tip` in the new look. Returns true.
M.VENDOR_POUCH = "|TInterface\\GossipFrame\\VendorGossipIcon:11:11:0:0|t "
function M.WriteItemB(tip, item, icon, level)
	local T, I, B = BT.UnitTip, M.ITEM, M.B
	local c = card(tip)
	local b = c.b
	M.HideTilesBits(b)
	local spacer, row = c.spacer, c.row
	local q = item.quality or ITEM_INK
	level = level or item.level
	-- A RECIPE'S LARGE NUMBER IS THE SKILL IT NEEDS (the recipe mockup,
	-- 2026-11-17), with the profession's name under it
	local recipe = item.recipe
	local levelLabel = "ITEM LEVEL"
	local recipeTag, hasProfession = nil, false
	if recipe then
		-- ("SKILL", not the profession's name: Josh's screenshots of
		-- 2026-11-17 had "LEATHERWORKING" under the number, wide enough to
		-- cut the name beside it to "Pattern: Pilferer'...". The line under
		-- the name says the profession.)
		level, levelLabel = recipe.skill, "SKILL"
		recipeTag, hasProfession = M.RecipeState(recipe)
	end

	-- 1. WHAT IT IS
	-- NO RED WORDS ON THE BAND (Josh 2026-11-17, Knight's Lance with "Polearm
	-- - Two-Hand" in red on an uncommon item's green band: "Red text on green
	-- background is difficult to read"). A kind you cannot use was written
	-- in the game's red, which reads on a plain tooltip and not on a band of
	-- a quality's colour. The CAN'T USE tag beside it says the same on a
	-- dark fill of its own, so the words keep the line's quiet colour.
	local sub = {}
	for _, part in ipairs({ item.kind, item.slot }) do
		if part then
			sub[#sub + 1] = part
		end
	end
	if #sub == 0 then
		for _, words in ipairs(item.class or {}) do
			sub[#sub + 1] = words
		end
	end
	sub = table.concat(sub, " · ")
	if recipe and recipe.profession then
		sub = recipe.profession .. " recipe"
	end
	-- (a spell's card says its own: M.WriteSpellB)
	if type(item.subText) == "string" then
		sub = item.subText
	end
	-- (an empty list of figures keeps a blank at the right of both lines,
	-- for the level to be laid against)
	-- NO WIDER THAN ITS CAP, WHATEVER IT IS CALLED (Josh's screenshots,
	-- 2026-11-16: "Seeing an overlap here", then "Still seeing overlap").
	-- Hovering a two-hander puts three cards side by side. At 320 each they
	-- were 938 wide in the 880 left of his bags; the game holds the first at
	-- the screen's edge and it lies under the next. The game's own three were
	-- about 250 each. So a card for a worn piece is capped at B.CAP_WORN and
	-- the hovered one at B.CAP, and the name is made to fit the room left
	-- beside the icon and the level: set smaller, down to B.NAME_LEAST, and
	-- cut short with three dots if it still will not go.
	local cap = item.comparing and B.CAP_WORN or B.CAP
	local off = icon and (I.ICON_TALL + I.ICON_GAP) or 0
	-- ONE SIZE FOR A NAME, AND CUT ONLY WHEN IT TRULY DOES NOT FIT (Josh
	-- 2026-11-16, of three cards side by side: "Truncating and resizing seems
	-- to be off on the headers"). A long name was set smaller, down to 11,
	-- and then cut, by a guess at the room that was some 30 pixels short. So
	-- "Battleforge Shield..." was small and cut with space to spare, while
	-- "Searing Blade" beside it was large. Now every hovered card's name is
	-- B.NAME and every worn card's B.NAME_WORN, nothing is set smaller, and
	-- the room is what is really left: the card, less its padding, the icon,
	-- and the level's own width.
	-- (THE SAME SIZE ON BOTH, Josh 2026-11-16: "Title resizing is pushing the
	-- content down, so the headers are different heights". A worn card's name
	-- was 13.5 and a hovered one's 15, so the hovered header was taller. Both
	-- are 15 now, and the worn cards a little wider for it.)
	local size = item.comparing and B.NAME_WORN or B.NAME
	local levelWide = 0
	if level then
		levelWide = math.max(T.Measure(tostring(level), B.LEVEL, "name"), T.Measure(levelLabel, I.FIG_LABEL, "name")) + 10
	end
	local room = cap - I.INSET - off - levelWide
	local shown = item.name
	-- A NAME IS NEVER CUT (Josh 2026-11-17, "Archmage Antonidas: The U...":
	-- "We can't truncate since there is no way to see the full title. We can
	-- adjust the font size, but if we do that it should not change the space
	-- the title takes up. The header should always be the same height").
	-- A name too long for its room is set smaller, half a point at a time,
	-- down to B.NAME_LEAST. If it is still too long the card is made wider
	-- than its cap, as wide as the name needs. What the smaller name gives
	-- up in height is put back (`drop`, below), so the icon, the line under
	-- the name, the tags and everything after them stay where they are on
	-- any other card.
	local full = size
	while size > B.NAME_LEAST and T.Measure(shown, size, "name") > room do
		size = math.max(B.NAME_LEAST, size - 0.5)
	end
	local lost = math.max(0, BT.Fonts.Size(full) - BT.Fonts.Size(size))
	local drop = lost / 2
	-- how it binds, whether it is unique, and "Can't use", as tags on a third
	-- line beside the icon (M.ItemTags)
	c.tall = true
	local tags = M.ItemTags(item)
	if recipeTag then
		table.insert(tags, 1, recipeTag)
	end
	-- (in the band's own tag colours, which read on any quality's band:
	-- T.TAG.bandwarn and the rest, Core/Tooltip.lua)
	for _, tag in ipairs(tags) do
		if T.TAG["band" .. tostring(tag[2])] then
			tag[2] = "band" .. tag[2]
		end
	end
	c.header(shown, q, icon, sub, item.edgeRgb, {}, tags)
	T.SizeLine(tip, 1, size, nil, "name")
	T.SizeLine(tip, 2, B.SUB, nil, "text")
	if lost > 0 then
		-- THE SMALLER NAME IN THE SAME ROOM: the blank at its right is as
		-- small, so the line is no taller than the name. The name sits half
		-- of what it lost lower, in the middle of its old room. The line
		-- under it sits the other half lower, where it always is. The icon
		-- hangs off the name, so it is lifted back by as much.
		T.SizeLine(tip, 1, size, "TextRight", "text")
		T.Indent(tip, 1, 0, nil, -drop)
		T.Indent(tip, 2, 0, nil, -drop)
		local l1 = T.LineOf(tip, 1)
		if icon and l1 and b.icon.ClearAllPoints then
			b.icon:ClearAllPoints()
			b.icon:SetPoint("TOPLEFT", l1, "TOPLEFT", -c.off, 1 + drop)
		end
	end
	local floor = math.min(I.MIN_W, cap)
	-- (no wider than the cap for anything but the name itself, at the size
	-- it was given: that much is needed whatever the cap)
	local needs = math.max(math.min(cap, c.needs(shown, sub, {}) + levelWide),
		T.Measure(shown, size, "name") + off + levelWide + I.INSET + 2)
	c.headNeeds = needs

	-- the rest of the icon's height, the band's foot and some air
	-- (Josh's Strong Fishing Pole, 2026-11-16: "Spacing seems off here". With
	-- no tags there are two lines beside a 40 pixel icon, not three, so the
	-- band ran down to the tiles' top edge. The gap is larger then.)
	-- (and what a smaller name lost, so the card is as tall as any other;
	-- the line after this one is lifted by as much, further down)
	tip:AddLine(" ")
	T.SizeLine(tip, c.last(), lineFor((c.tagLine and B.HEAD_GAP or B.HEAD_GAP_BARE) + lost), nil, "text")
	-- (the last line of the head: a card with nothing written after it has
	-- no body, see ROOM BEFORE THE FOOT below)
	local headEnd = c.last()

	local laid = {}
	local function keep(h, what)
		tip:AddLine(T.TAG_BLANK)
		T.SizeLine(tip, c.last(), lineFor(h), nil, "text")
		what.line, what.h = c.last(), h
		laid[#laid + 1] = what
	end
	local function heading(words)
		row(tostring(words):upper(), ITEM_HEAD)
		T.SizeLine(tip, c.last(), I.FIG_LABEL + 0.5, nil, "name")
	end

	-- 2. THE ANSWER
	-- the facts of an item, as the game lists them (see 3 AND 4 below); a
	-- recipe's made item is listed by it too
	local function facts(item)
	if item.damage then
		local school = item.school and (" " .. item.school) or ""
		row(("%s%s Damage"):format(item.damage, school), ITEM_INK, item.speed and ("Speed " .. item.speed) or nil, ITEM_INK)
	elseif item.speed then
		row("Speed " .. item.speed, ITEM_INK)
	end
	if item.dps then
		row(("(%s damage per second)"):format(tostring(item.dps)), ITEM_INK)
	end
	if item.armor then
		row(("%s Armor"):format(tostring(item.armor)), ITEM_INK)
	end
	if item.block then
		row(("%s Block"):format(tostring(item.block)), ITEM_INK)
	end
	for _, x in ipairs(item.extraDamage) do
		row(x.text, x.rgb or ITEM_INK)
	end
	for _, st in ipairs(item.stats) do
		row(st.text, ITEM_INK)
	end
	for _, e in ipairs(item.effects) do
		row(e.line or e.text, e.rgb or ITEM_GREEN, nil, nil, true)
	end
	end
	local more = item.more or {}
	-- `inBox`: the tiles sit in a recipe's box, and take the darker fill
	local function tilesOf(more, inBox)
	for _, group in ipairs(type(more.tiles) == "table" and more.tiles or {}) do
		if type(group) == "table" and #group > 0 then
			if type(group.head) == "string" then
				heading(group.head)
			end
			-- (2026-11-16, later: a tile is now the role's one number, and
			-- with Shift held its parts are listed under it, a line each)
			local under = 0
			for _, t in ipairs(group) do
				if type(t) == "table" then
					under = math.max(under, type(t.parts) == "table" and #t.parts or (t.second and 1 or 0))
				end
			end
			-- THE SECOND FIGURE UNDER ITS TILE, OUTSIDE IT (Josh 2026-11-16,
			-- of a row where only the tank's tile had "threat +34.4%" in it:
			-- "Can we leave tank, healer, and dps in the boxes by themselves?
			-- The sub-stats (threat, etc) could be a line under it, outside of
			-- the boxes. This way we won't have a lot of empty space in the
			-- boxes"). One second figure made all three tiles tall. Every tile
			-- is B.TILE_H now, and the second figures are a line of small
			-- print under the row, each centred under its own tile.
			keep(B.TILE_H, { kind = "tiles", tiles = group, inBox = inBox })
			for k = 1, under do
				keep(B.UNDER_H, { kind = "under", tiles = group, nth = k })
			end
			spacer()
		end
	end
	end

	-- A RECIPE: WHAT IT MAKES, IN A BOX OF ITS OWN, THEN ITS MATERIALS (Josh
	-- 2026-11-17, of the mockup: "Looks great. Proceed."). The made item's
	-- name in its quality's colour with its picture and level, what it is,
	-- the three role numbers for it against what you wear (other modules'
	-- tiles, asked for the made item in M.RebuildItem), then its facts as
	-- any item's. The materials say how many you carry of how many it needs
	-- where the profession is yours, and the amounts alone where it is not.
	local boxes = {}
	if recipe then
		local made = recipe.made
		local from = nil
		heading("Makes")
		from = c.last()
		local mq = made.quality or ITEM_INK
		local picture = M.ItemIcon(recipe.id)
		local name = (picture and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t "):format(tostring(picture), B.MADE_ICON, B.MADE_ICON) or "")
			.. tostring(made.name)
		row(name, mq, recipe.madeLevel and ("ilvl " .. tostring(recipe.madeLevel)) or nil, ITEM_SUB)
		T.SizeLine(tip, c.last(), B.MADE_NAME, nil, "name")
		T.SizeLine(tip, c.last(), I.FOOT, "TextRight", "text")
		local what = {}
		for _, part in ipairs({ { made.slot, made.slotRgb }, { made.kind, made.kindRgb } }) do
			if part[1] then
				what[#what + 1] = isRed(part[2]) and hex(part[2], part[1]) or part[1]
			end
		end
		if #what == 0 then
			for _, words in ipairs(M.ItemClass(recipe.id) or {}) do
				what[#what + 1] = words
			end
		end
		if made.bind then
			what[#what + 1] = made.bind
		end
		if #what > 0 then
			row(table.concat(what, " · "), ITEM_SUB)
			T.SizeLine(tip, c.last(), B.SUB, nil, "text")
		end
		spacer()
		tilesOf(made.more or {}, true)
		local shortOf = made.require and warning(made.require.rgb) or nil
		if shortOf then
			row(M.Bare(made.require.text), shortOf, nil, nil, true)
		end
		facts(made)
		for _, r in ipairs(made.rest) do
			-- (a requirement you meet is not said, as on any card)
			if not (M.Bare(r.text):find("^Requires ") ~= nil and not isRed(r.rgb)) then
				row(M.Bare(r.text), isRed(r.rgb) and r.rgb or ITEM_SUB, r.right and M.Bare(r.right) or nil, ITEM_SUB, r.wrap)
			end
		end
		boxes[#boxes + 1] = { from = from, to = c.last() }
		spacer()
		spacer()
		spacer()
		if #recipe.materials > 0 then
			heading("Materials")
			for _, m in ipairs(recipe.materials) do
				local carried = hasProfession and M.Carried(m[1]) or nil
				if carried then
					row(m[1], ITEM_INK, ("%d / %d"):format(carried, m[2]), carried >= m[2] and UP_INK or DOWN_INK)
				else
					row(m[1], ITEM_INK, tostring(m[2]), ITEM_SUB)
				end
			end
			spacer()
		end
	end
	tilesOf(more)
	for _, grid in ipairs(type(more.grids) == "table" and more.grids or {}) do
		if type(grid) == "table" and type(grid.rows) == "table" and #grid.rows > 0 then
			if type(grid.head) == "string" then
				heading(grid.head)
			end
			keep(#grid.rows * B.GRID_H + 2, { kind = "grid", rows = grid.rows })
			spacer()
		end
	end
	-- what it asks of you, in the warning's colour where you fall short
	-- ONLY WHERE YOU FALL SHORT (his Death Speaker Scepter read "Requires
	-- Level 28" to a level 28): a requirement you meet is not said
	local short = item.require and warning(item.require.rgb) or nil
	if short then
		row(M.Bare(item.require.text), short, nil, nil, true)
		spacer()
	end

	-- 3 AND 4. THE FACTS AND THE WORDS, AS THE GAME LISTS THEM (Josh
	-- 2026-11-16, beside a screenshot of the game's own tooltips: "I'm not a
	-- fan of the stats being in 2 columns. Can we make that part look more
	-- like the default tooltip?"). One to a line, in the game's order and the
	-- game's words: damage with speed at its right, damage per second, armor,
	-- block, the stats in white, then each effect as its sentence in the
	-- game's green. This takes back two things the mockup had: stats as a
	-- number and a word two to a row, and Equip lines that only add stats
	-- turned into stat rows (M.StatList, not called now).
	facts(item)
	-- rows of its own, as they come (a spell's requirements and what it
	-- does: M.WriteSpellB)
	for _, r in ipairs(item.rows or {}) do
		if r.gap then
			spacer()
		end
		row(r.text, r.rgb or ITEM_INK, r.right, r.rrgb, r.wrap)
		if r.small then
			T.SizeLine(tip, c.last(), I.QUIET, nil, "text")
		end
	end
	-- THE SET IT BELONGS TO, IN A BOX OF ITS OWN (M.ReadItem): the set's
	-- name with how many you wear at its right, its pieces (the ones you
	-- wear bright, the rest quiet), then each bonus, green once it counts
	if item.set then
		local set = item.set
		spacer()
		spacer()
		row(set.name, { 1, 0.82, 0 }, ("%d / %d"):format(set.have or 0, set.need or 0), ITEM_SUB)
		local from = c.last()
		T.SizeLine(tip, c.last(), I.FOOT, "TextRight", "text")
		for _, piece in ipairs(set.pieces) do
			row("  " .. piece.text, piece.worn and ITEM_INK or ITEM_SUB)
			T.SizeLine(tip, c.last(), I.FOOT, nil, "text")
		end
		for _, bonus in ipairs(set.bonuses) do
			row(bonus.text, bonus.active and ITEM_GREEN or ITEM_SUB, nil, nil, true)
			T.SizeLine(tip, c.last(), I.FOOT, nil, "text")
		end
		boxes[#boxes + 1] = { from = from, to = c.last() }
		spacer()
	end
	if item.flavour then
		-- EVEN ROOM OVER AND UNDER IT (Josh 2026-11-17, a book whose card is
		-- its head, its quote and the other addons' box: "less padding on the
		-- rp quote. It is also slightly off from being vertically centered").
		-- The line before it parts it from the facts above. Where it is the
		-- first thing under the head, the head's own gap is that room, and
		-- the line made the room over the quote larger than the room under.
		if c.last() > headEnd then
			spacer()
		end
		local f = item.flavourRgb or { 1, 0.82, 0 }
		tip:AddLine(item.flavour, f[1], f[2], f[3], true)
		T.SizeLine(tip, c.last(), I.FLAVOUR, nil, "quote")
	end

	-- 5. OTHER ADDONS' LINES, THEN THE FOOT (Josh 2026-11-16: "Any way we can
	-- have our durability and vendor value on the footer bar, and the other
	-- addon info in a new container above that?"). The strip had started at
	-- the first of the other addons' rows, so the foot read as theirs as much
	-- as ours. Their rows now sit in a box of their own, in the tiles' fill,
	-- and the strip is the durability and the price alone.
	-- ROOM BEFORE THE FOOT ONLY WHERE THERE IS ONE (Josh 2026-11-17, of
	-- Hammer of Justice's card, which has no foot: "now we have too much
	-- blank space at the bottom"). Two blank lines were always added here,
	-- to part the facts from the other addons' rows and the foot. A spell's
	-- card has neither, and the two lines were left under its last words.
	-- NOR WHERE NOTHING IS ABOVE IT (Josh 2026-11-17, Copper Ore, whose card
	-- is its head and then other lines: "Can we collapse the gap ... if there
	-- is nothing to put there?"). An item with no facts, tiles or words had
	-- the head's gap and then these two lines, with nothing between them.
	if c.last() > headEnd
		and (#item.rest > 0 or item.durability or item.price or item.footText or item.maker or #item.notes > 0) then
		spacer()
		spacer()
	end
	local stripFrom = nil
	local boxFrom, boxTo = nil, nil
	if #item.rest > 0 then
		for _, r in ipairs(item.rest) do
			-- (another addon's "Vendor" price is the foot's own price again)
			-- (nor is a requirement you meet, such as "Requires Fishing (10)":
			-- one you fall short of is red and is kept)
			local met = M.Bare(r.text):find("^Requires ") ~= nil and not isRed(r.rgb)
			if not met and not (item.price and M.Bare(r.text) == "Vendor") then
				row(M.Bare(r.text), ITEM_SUB, r.right and M.Bare(r.right) or nil, ITEM_SUB, r.wrap)
				T.SizeLine(tip, c.last(), I.FOOT, nil, "text")
				if r.right then
					T.SizeLine(tip, c.last(), I.FOOT, "TextRight", "text")
				end
				boxFrom = boxFrom or c.last()
				boxTo = c.last()
			end
		end
		-- ROOM UNDER THE BOX ONLY WHERE THE FOOT FOLLOWS (Josh 2026-11-17, the
		-- same book, which has no price: "Footer can be collapsed since there
		-- is no content"). These lines part the box from the foot's strip.
		-- With no foot they were an empty strip's worth of room at the bottom.
		if boxFrom and (item.durability or item.price or item.footText or item.maker or #item.notes > 0) then
			spacer()
			spacer()
			spacer()
		end
	end
	local d = item.durability
	local hasBar = d ~= nil and d.most ~= nil and d.most > 0
	local right = {}
	if item.price then
		right[#right + 1] = M.Coins(item.price)
	end
	local footLine = nil
	if d or #right > 0 or item.footText then
		local worn = item.footText or " "
		if d then
			worn = hasBar and T.TAG_BLANK or d.text
		end
		-- THE VENDOR'S POUCH BEFORE THE PRICE (Josh 2026-11-17, Tin Ore with an
		-- auction price in the box above and the vendor's in the foot: "Can
		-- we add the vendor icon (pouch) before the vendor price on item
		-- tooltips?"). The picture the game puts over a vendor's head, so the
		-- foot's coins read as what a vendor pays.
		local pouch = item.price and M.VENDOR_POUCH or ""
		tip:AddDoubleLine(worn, #right > 0 and (pouch .. table.concat(right, " · ")) or " ", ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3],
			ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3])
		footLine = c.last()
		T.SizeLine(tip, footLine, B.FOOT, nil, "text")
		T.SizeLine(tip, footLine, B.FOOT, "TextRight", "text")
		stripFrom = stripFrom or footLine
		if item.footText then
			needs = math.max(needs, T.Measure(M.Bare(item.footText), B.FOOT, "text") + I.INSET + 4)
		end
		needs = math.max(needs, (hasBar and (I.BAR_W + I.BAR_GAP + T.Measure(d.text, B.FOOT, "text")) or 0)
			+ T.Measure(table.concat(right, " · "), B.FOOT, "text") + 24 + I.INSET + (item.price and 14 or 0))
	end
	if item.maker then
		tip:AddLine(("Made by %s"):format(item.maker), ITEM_MAKER[1], ITEM_MAKER[2], ITEM_MAKER[3])
		T.SizeLine(tip, c.last(), I.MAKER, nil, "text")
		stripFrom = stripFrom or c.last()
	end
	for _, note in ipairs(item.notes) do
		tip:AddLine(note)
	end
	-- NO LINE UNDER THE FOOT (Josh 2026-11-16: "Footer is too tall. Text should
	-- be vertically centered, and there should be a good bit less top and
	-- bottom padding"). A blank line was added under it for room, and the
	-- smallest line the tooltip makes is far taller than the 3 asked for. The
	-- tooltip's own padding is the room under the words, and the strip starts
	-- about as far above them (B.STRIP_PAD).
	if stripFrom and B.FOOT_UNDER > 0 then
		tip:AddLine(" ")
		T.SizeLine(tip, c.last(), B.FOOT_UNDER, nil, "text")
	end

	-- (a smaller name: the head's gap was made taller by what the name lost,
	-- to keep the card's height, and the body starts where it always does)
	if lost > 0 and c.last() > headEnd then
		T.Indent(tip, headEnd + 1, 0, nil, lost)
	end
	local inner = c.finish(floor, math.max(math.min(cap, needs), c.headNeeds or 0))
	-- LESS UNDER THE FOOT (Josh 2026-11-16: "Need less padding on the bottom
	-- of the footer"). The room under the foot's words is the tooltip's own
	-- lower padding, which the card does not draw. So where there is a foot,
	-- the tooltip is asked for B.FOOT_TRIM less of it, and shown again so
	-- that the strip below is measured against where the edge now is.
	if stripFrom and skins[tip] and M.Repad then
		skins[tip].extraBottom = B.FOOT_TRIM
		M.Repad(tip, skins[tip], true)
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
	end
	local one = BT.Pill.Px(b.holder, 1) or 1

	-- the band behind the name and the line under it, in the quality's colour
	local l1, l2 = T.LineOf(tip, 1), T.LineOf(tip, 2)
	if icon and b.icon:IsShown() then
		b.icon:SetSize(I.ICON_TALL, I.ICON_TALL)
	end
	if l1 and l2 then
		M.LayBand(tip, b, item.bandRgb or q, (icon and b.icon:IsShown()) and b.icon or l2, c.tagLine and T.LineOf(tip, c.tagLine) or l2)
	end
	-- its level, large, with its two words under it
	local r1, r2 = T.LineOf(tip, 1, "TextRight"), T.LineOf(tip, 2, "TextRight")
	if level and r1 and r2 then
		local num = bSay(b, tostring(level), ITEM_INK, B.LEVEL, false, "name")
		num:SetPoint("TOPRIGHT", r1, "TOPRIGHT", 0, 2 + drop)
		local cap = bSay(b, levelLabel, ITEM_HEAD, I.FIG_LABEL, false, "name")
		cap:SetPoint("TOPRIGHT", num, "BOTTOMRIGHT", 0, -3)
	end

	for _, L in ipairs(laid) do
		local at = T.LineOf(tip, L.line)
		if at and L.kind == "tiles" then
			local n = #L.tiles
			local w = (inner - B.TILE_GAP * (n - 1)) / n
			for i, t in ipairs(L.tiles) do
				local x = math.floor((i - 1) * (w + B.TILE_GAP) + 0.5)
				b.nBack = (b.nBack or 0) + 1
				local bg = M.TileBack(b, b.nBack)
				bg:SetPoint("TOPLEFT", at, "TOPLEFT", x, 0)
				bg:SetSize(math.floor(w), L.h - 2)
				M.PaintTileBack(bg, L.inBox and B.TILE_FILL_IN or B.TILE_FILL)
				-- (over the box it sits in: these frames are made once and used
				-- again, so the level is set each time)
				if bg.SetFrameLevel and b.holder.GetFrameLevel then
					pcall(bg.SetFrameLevel, bg, (b.holder:GetFrameLevel() or 0) + (L.inBox and 2 or 1))
				end
				local num = bSay(b, tostring(t.value or ""), t.rgb or ITEM_INK, B.BIG, false, "name")
				num:SetPoint("TOP", bg, "TOP", 0, -7)
				local cap = bSay(b, tostring(t.label or ""):upper(), ITEM_HEAD, I.FIG_LABEL, false, "name")
				cap:SetPoint("TOP", num, "BOTTOM", 0, -3)
			end
		elseif at and L.kind == "under" then
			local n = #L.tiles
			local w = (inner - B.TILE_GAP * (n - 1)) / n
			for i, t in ipairs(L.tiles) do
				local part = type(t.parts) == "table" and t.parts[L.nth] or (L.nth == 1 and t.second) or nil
				if type(part) == "table" then
					local x = math.floor((i - 1) * (w + B.TILE_GAP) + w / 2 + 0.5)
					local second = bSay(b, tostring(part[1]) .. " " .. hex(part[3] or ITEM_INK, tostring(part[2])),
						ITEM_SUB, I.FOOT)
					second:SetPoint("TOP", at, "TOPLEFT", x, 0)
				end
			end
		elseif at and L.kind == "stats" then
			local w = (inner - B.COL_GAP) / 2
			for i, s in ipairs(L.stats) do
				local x = ((i - 1) % 2) * (w + B.COL_GAP)
				local y = math.floor((i - 1) / 2) * B.STAT_H
				local num = bSay(b, s.num, s.dim and ITEM_SUB or ITEM_INK, B.ROW, false, "name")
				num:SetPoint("TOPLEFT", at, "TOPLEFT", math.floor(x + 0.5), -y)
				if s.label ~= "" then
					local label = bSay(b, s.label, ITEM_SUB, B.ROW)
					label:SetPoint("LEFT", num, "RIGHT", 5, 0)
				end
				if s.delta then
					local delta = bSay(b, amount(s.delta, true), s.delta < 0 and DOWN_INK or UP_INK, I.FOOT)
					delta:SetPoint("TOPRIGHT", at, "TOPLEFT", math.floor(x + w + 0.5), -y - 1)
				end
			end
		elseif at and L.kind == "grid" then
			local first = inner * 0.4
			local w = (inner - first) / 3
			for r, cells in ipairs(L.rows) do
				local y = (r - 1) * B.GRID_H
				local label = bSay(b, tostring(cells[1] or ""), ITEM_SUB, I.FOOT + 0.5)
				label:SetPoint("TOPLEFT", at, "TOPLEFT", 0, -y)
				for k = 1, 3 do
					local v = cells[k + 1]
					if type(v) == "table" and v[1] then
						local fs = bSay(b, tostring(v[1]), v[2] or ITEM_HEAD, I.FOOT + 0.5)
						fs:SetPoint("TOP", at, "TOPLEFT", math.floor(first + (k - 0.5) * w + 0.5), -y)
					end
				end
			end
		end
	end

	-- the foot's darker strip, to the bottom of the tooltip
	M.LayStrip(tip, b, stripFrom and T.LineOf(tip, stripFrom) or nil, nil)
	-- the other addons' box, from their first row to their last
	-- (and a recipe's box, around what it makes)
	if boxFrom then
		boxes[#boxes + 1] = { from = boxFrom, to = boxTo }
	end
	for _, one in ipairs(boxes) do
		local first, last = one.from and T.LineOf(tip, one.from), one.to and T.LineOf(tip, one.to)
		local boxTop = first and BT.Pill.Number(first.GetTop and first:GetTop(), nil)
		local boxFoot = last and BT.Pill.Number(last.GetBottom and last:GetBottom(), nil)
		if boxTop and boxFoot and boxTop > boxFoot then
			b.nBack = (b.nBack or 0) + 1
			local box = M.TileBack(b, b.nBack)
			box:SetPoint("TOPLEFT", first, "TOPLEFT", -B.BOX_PAD, B.BOX_PAD - 1)
			box:SetSize(math.floor(inner + 2 * B.BOX_PAD), math.floor(boxTop - boxFoot + 2 * B.BOX_PAD - 1))
			M.PaintTileBack(box, B.TILE_FILL)
			if box.SetFrameLevel and b.holder.GetFrameLevel then
				pcall(box.SetFrameLevel, box, (b.holder:GetFrameLevel() or 0) + 1)
			end
		end
	end
	if hasBar then
		local fs = T.LineOf(tip, footLine)
		local share = math.max(0, math.min(1, (d.now or 0) / d.most))
		local col = share > 0.5 and { 0.31, 0.78, 0.42 } or share > 0.25 and { 0.89, 0.75, 0.30 } or { 0.89, 0.38, 0.35 }
		if fs then
			b.barBg:ClearAllPoints()
			b.barBg:SetPoint("LEFT", fs, "LEFT", 0, 0)
			b.barBg:SetSize(I.BAR_W, B.BAR_H)
			b.barBg:SetColorTexture(0.12, 0.17, 0.15, 1)
			b.bar:SetWidth(math.max(1, math.floor(I.BAR_W * share + 0.5)))
			b.bar:SetColorTexture(col[1], col[2], col[3], 1)
			b.barBg:Show()
			b.bar:SetShown(share > 0)
			BT.Fonts.Set(b.worn, "text", B.FOOT)
			b.worn:SetText(d.text)
			b.worn:SetTextColor(ITEM_SUB[1], ITEM_SUB[2], ITEM_SUB[3])
			b.worn:Show()
		end
	end
	return true
end

-- Writes `item` on `tip` (from M.ReadItem); `icon` its picture, `level` its
-- item level. Returns true.
function M.WriteItem(tip, item, icon, level)
	local T, I = BT.UnitTip, M.ITEM
	local c = card(tip)
	local b = c.b
	local spacer, row = c.spacer, c.row

	-- the name, and what it is, beside its icon: its kind and slot ("Axe ·
	-- Two-Hand"), or for something with no slot what kind of thing it is
	-- ("Trade Goods"). Its level is a figure at the right now, not words in
	-- this line.
	local q = item.quality or ITEM_INK
	level = level or item.level
	-- the words the client made red stay red
	local sub = {}
	for _, part in ipairs({ { item.kind, item.kindRgb }, { item.slot, item.slotRgb } }) do
		local words, rgb = part[1], part[2]
		if words then
			sub[#sub + 1] = isRed(rgb) and hex(rgb, words) or words
		end
	end
	if #sub == 0 then
		for _, words in ipairs(item.class or {}) do
			sub[#sub + 1] = words
		end
	end
	sub = table.concat(sub, " · ")
	local figs = M.ItemFigures(item, level)
	c.header(item.name, q, icon, sub, nil, figs, M.ItemTags(item))

	-- as wide as the name and the line under it need, each with its figure,
	-- as a spell's card is; and the foot, whose left side the client cannot
	-- measure: the bar and its numbers are ours. A bolt of cloth with no
	-- figures is let be narrower.
	local floor = figs and I.MIN_W or I.PLAIN_W
	local needs = c.needs(item.name, sub, figs)
	local d = item.durability
	local hasBar = d ~= nil and d.most ~= nil and d.most > 0
	if hasBar then
		needs = math.max(needs, I.BAR_W + I.BAR_GAP + T.Measure(d.text, I.FOOT, "text")
			+ (item.price and T.Measure(M.Coins(item.price), I.FOOT, "text") or 0) + 24 + I.INSET)
	end
	-- WIDE ENOUGH FOR ANOTHER ADDON'S CELLS IN ONE ROW (Josh 2026-11-16, of
	-- Corpsemaker's card: "the DPS box is on the second grid row"): a narrow
	-- card broke the three Upgrades cells across two rows
	-- (the widest of their rows: a cell with `newRow` starts one)
	local moreWidth, rowWidth = 0, 0
	for _, cell in ipairs(item.more or {}) do
		if cell.newRow then
			rowWidth = 0
		end
		rowWidth = rowWidth + math.ceil(T.Measure(cell[2], I.SUB, "text")) + 2 * I.CELL_PAD + 1
		moreWidth = math.max(moreWidth, rowWidth)
	end
	if moreWidth > 0 then
		needs = math.max(needs, moreWidth + I.INSET + 2)
	end
	needs = math.min(MAX_W, needs)

	-- what it does in a fight and what it asks of you, in cells
	local facts, said, timed = M.ItemFacts(item)
	-- A ROW TO THEMSELVES (Josh 2026-11-16, of the Upgrades cells: "Sometimes
	-- there are other items on the row also... it should only ever be those 3
	-- stats"): the item's own facts start the next row.
	local cells = M.FactCells(facts)
	local more = item.more or {}
	if #more > 0 and cells[1] then
		cells[1].newRow = true
	end
	for i, cell in ipairs(more) do
		table.insert(cells, i, cell)
	end
	if #cells > 0 then
		spacer()
		c.cells(cells, math.max(floor, needs) - I.INSET)
	end
	-- another addon's rows, under the cells (BT.OnItemCells)
	if more.rows and #more.rows > 0 then
		spacer()
		for _, r in ipairs(more.rows) do
			row(r[1], r.quiet and ITEM_QUIET or ITEM_INK, type(r[2]) == "string" and r[2] or nil)
		end
	end

	-- then its stats and what it does beyond them, as plain lines with no
	-- headings over them: the effects as the client wrote them ("Equip: +62
	-- Attack Power."), in the game's green, in the order they came. A Use
	-- line the cells say all of is left out, and a cooldown in a cell is
	-- not said again.
	local body = {}
	for _, x in ipairs(item.extraDamage) do
		body[#body + 1] = { x.text, x.rgb }
	end
	for _, s in ipairs(item.stats) do
		body[#body + 1] = { s.text, s.rgb }
	end
	for _, e in ipairs(item.effects) do
		if e ~= said then
			local text = e.line or e.text
			if e == timed then
				text = M.WithoutCooldown(text)
			end
			body[#body + 1] = { text, e.rgb or ITEM_GREEN, true }
		end
	end
	if #body > 0 then
		spacer()
		for _, r in ipairs(body) do
			row(r[1], r[2], nil, nil, r[3])
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
	local footLine = nil
	if d or item.price then
		spacer()
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

	c.finish(floor, needs)

	if hasBar then
		local fs = T.LineOf(tip, footLine)
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

-- the item's level, for its figure beside the line under its name: on
-- things you wear only
local function levelOf(tip)
	local link = shownItem(tip)
	local text = link and M.ItemLevelText(link)
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
	-- (a recipe first, in the new look: M.ReadItem leaves one, with its
	-- block inside it, to the restyle)
	local item = (M.TILES_LOOK and M.ReadRecipe(data, tip.isShopping and true or false))
		or M.ReadItem(data, tip.isShopping and true or false)
	if not item then
		return false
	end
	-- another addon's lines, with the client's other lines after the effects
	-- (M.OthersLines); a footnote among them stays a footnote
	-- NOT THE PRICE TWICE (Josh's screenshots, 2026-10-18): the client adds its
	-- own "Sell Price:" line after its data, and the card already says the
	-- price in its footer, so that one is not carried
	for _, row in ipairs(M.OthersLines(tip, data) or {}) do
		local note = isFootnote(row.text)
		if note == "price" then
			-- (the footer's coins say it)
		elseif note then
			item.notes[#item.notes + 1] = row.text
		else
			item.rest[#item.rest + 1] = row
		end
	end
	local id = type(data) == "table" and data.id or nil
	item.class = M.ItemClass(id)
	-- cells another addon has for this item (BT.OnItemCells), asked before
	-- the clear, while the tooltip still knows what it shows
	item.more = BT.UnitTip.MoreItemCells and BT.UnitTip.MoreItemCells(tip, data, tip.isShopping and true or false)
	-- a recipe: the cells are for the item it makes, by that item's link,
	-- and its level is asked for by the same
	if item.recipe then
		item.more = nil
		local get = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
		local okLink, _, link = false, nil, nil
		if type(get) == "function" then
			okLink, _, link = pcall(get, item.recipe.id)
		end
		link = okLink and plainLine(link) or nil
		if type(link) == "string" then
			item.recipe.made.more = BT.UnitTip.MoreItemCells
				and BT.UnitTip.MoreItemCells(tip, { hyperlink = link, id = item.recipe.id }, tip.isShopping and true or false)
			local text = M.ItemLevelText(link)
			item.recipe.madeLevel = text and text:match("(%d+)%s*$") or nil
		end
	end
	-- the item itself and what you wear in its place, for its stats and
	-- their change (M.StatList); not on the comparison tooltips, which show
	-- the worn piece
	item.link = shownItem(tip)
	local comparing = tip.isShopping or tip == rawget(_G, "ShoppingTooltip1") or tip == rawget(_G, "ShoppingTooltip2")
		or tip == rawget(_G, "ItemRefShoppingTooltip1") or tip == rawget(_G, "ItemRefShoppingTooltip2")
	item.wornLink = not comparing and M.WornFor and M.WornFor(item.link) or nil
	item.comparing = comparing and true or false
	-- THE "EQUIPPED" LABEL OVER A COMPARISON TOOLTIP: the client hides it
	-- whenever the tooltip is cleared (ShoppingTooltipTemplate), and the
	-- rebuild clears it, so it is put back as it was
	local header = type(tip.CompareHeader) == "table" and tip.CompareHeader or nil
	local headed = header and header.IsShown and header:IsShown()
	-- THE NEW LOOK FIRST, THE OLD ONE IF IT FAILS (M.WriteItemB): a fault in
	-- the new card is said on the Testing page and the old card is written
	local level = levelOf(tip)
	local ok, err = false, nil
	if M.TILES_LOOK and M.WriteItemB then
		ok, err = pcall(M.WriteItemB, tip, item, M.ItemIcon(id), level)
		if not ok then
			BT.Err("tooltips.WriteItemB: " .. tostring(err))
		end
	end
	if not ok then
		ok, err = pcall(M.WriteItem, tip, item, M.ItemIcon(id), level)
	end
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
	-- WRITTEN AGAIN AS A SPELL'S CARD IS (M.RebuildItem), or, for a shape
	-- that does not know, its lines in the unit tooltip's style where they
	-- are; then the footnotes quiet
	M.Seen("item", data)
	local rebuilt = M.RebuildItem(tip, data)
	if rebuilt == false then
		-- the client's lines restyled where they are: no card, so none of a
		-- card's parts (M.CardShown)
		M.HideItemBits(tip)
		M.ItemLines(tip, data)
	else
		-- DRESSED AGAIN AFTER THE REBUILD (Josh 2026-10-17: "Looks like we
		-- lost the left border that indicates item rarity"). The rebuild
		-- clears the tooltip, and a clear gives a comparison tooltip the
		-- client's own background back (GameTooltip_ClearStyle).
		spine()
	end
	quietFooter(tip)
	shadowTitle(tip)
	-- before the Show below, which measures the tooltip with it in; a rebuilt
	-- one has its level as a figure (M.ItemFigures)
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

-- A COMPARISON CARD WRITTEN ONCE A REDRAW, NOT FOUR TIMES (Josh 2026-11-16:
-- "Tooltip performance issues. 70 fps with no tooltip open... 61 after I
-- open it"; his readings: in 5 seconds GameTooltip written 25 times, each
-- "Equipped" tooltip 100 times, 2.1 ms a write, no one stretch of a write
-- the slow one).
--
-- While the mouse rests on a bag item the game sets its tooltip again five
-- times a second, and each time it fills the comparison tooltips more than
-- once: when the item is set (TooltipDataRules.FinalizeItemTooltip) and
-- again two lines on (ContainerFrameItemButtonMixin:OnUpdate). Four times,
-- as he measured it. Each fill cleared the tooltip and the card was written
-- on it again, and only the last of them is ever seen.
--
-- So the fills are counted. All the fills of one redraw happen within one
-- frame, where GetTime() does not move. Once a redraw of this item on this
-- tooltip has been seen to take N fills, the next redraw's first N - 1 are
-- left as the game filled them and the card is written on the Nth: the one
-- the game then puts its "If you replace" lines under and places the
-- tooltips by, as before.
--
-- If a redraw stops short of N, the tooltip would be left as the game's.
-- GameTooltip's own OnUpdate, which is what began the redraw, is hooked,
-- and after it the card is written on any tooltip still owed one
-- (M.SettleSpared). That redraw's count is the next one's N.
--
-- Only GameTooltip's two comparison tooltips. A hover's first redraw, or a
-- different item, is written every time, as it was.
local spare = setmetatable({}, { __mode = "k" })
M.SPARE_FORGET = 0.6 -- sec with no fill: the hover ended, nothing is assumed
function M.Spared(tip, data)
	if not M.TILES_LOOK or (tip ~= rawget(_G, "ShoppingTooltip1") and tip ~= rawget(_G, "ShoppingTooltip2")) then
		return false
	end
	local key = type(data) == "table" and (data.guid or data.hyperlink or data.id) or nil
	local t = type(GetTime) == "function" and GetTime() or nil
	if key == nil or t == nil or (issecretvalue and issecretvalue(key)) then
		spare[tip] = nil
		return false
	end
	local c = spare[tip]
	if not c or c.key ~= key or t - c.at > M.SPARE_FORGET then
		spare[tip] = { key = key, at = t, n = 1, written = true }
		return false
	end
	if c.at ~= t then
		-- a new redraw: the last one's count is what this one is taken to be
		c.expect, c.at, c.n, c.written, c.owed = c.n, t, 0, false, nil
	end
	c.n = c.n + 1
	if c.expect and c.n < c.expect then
		c.owed = data
		return true
	end
	c.written, c.owed = true, nil
	return false
end
-- true where the last fill of `tip` was left as the game's (M.Spared)
function M.IsSpared(tip)
	local c = spare[tip]
	return c ~= nil and c.owed ~= nil
end
function M.SettleSpared()
	for tip, c in pairs(spare) do
		if c.owed and not c.written then
			local data = c.owed
			c.owed, c.written = nil, true
			if tip.IsShown and tip:IsShown() and BT.Enabled("tooltips") then
				local ok, err = pcall(M.ComposeItem, tip, data)
				if not ok then
					BT.Err("tooltips.spared: " .. tostring(err))
				end
				M.settled = M.settled + 1
			end
		end
	end
end
-- THE LIST IS LOOKED FOR EVERY FRAME, NOT ONLY WHEN THE GAME WRITES IT (Josh
-- 2026-11-17, after it was to be hidden: ""If you replace this item" is still
-- shown, but everything else looks good"). It was hidden from a hook that
-- runs as the game fills a comparison tooltip, and only on a fill the card
-- was written on. In the look the card is not written on every fill
-- (M.Spared), and his screenshots had the list untouched under the card. So
-- while a comparison tooltip shows, its lines are looked through each frame
-- and the list is emptied wherever it is found (M.FoldDelta, which finds
-- nothing once it has).
function M.HideDeltaShown()
	if not M.HidesDelta() then
		return 0
	end
	local n = 0
	for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
		local tip = rawget(_G, name)
		if tip and tip.IsShown and tip:IsShown() then
			local ok, head = pcall(M.FoldDelta, tip)
			if not ok then
				BT.Err("tooltips.delta: " .. tostring(head))
			elseif head then
				n = n + 1
			end
		end
	end
	return n
end
if GameTooltip and GameTooltip.HookScript then
	pcall(GameTooltip.HookScript, GameTooltip, "OnUpdate", function()
		if next(spare) then
			M.SettleSpared()
		end
		M.HideDeltaShown()
	end)
end

BT.OnItemTooltip("tooltips", 0, function(tip, data)
	if M.Spared(tip, data) then
		M.spared = M.spared + 1
		return
	end
	M.ComposeItem(tip, data)
end)

-- WHAT SWAPPING WOULD CHANGE, AS PART OF THE CARD (Josh 2026-10-17, choosing
-- "Fold the Equipped tooltip's "If you replace this item..." lines into the
-- card"). The client writes those lines after the card is written, so they
-- came out in its own style under ours. Once it has, the line that heads them
-- is set as a small heading, "If replaced", over a rule, and the changes
-- under it at the rows' size, in the colours the client gave them. It is the
-- one heading a card still has (2026-10-18): what is under it is the
-- client's, written after the card, not part of the item.
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

-- HIDDEN WHERE UPGRADES SAYS IT (Josh 2026-11-17, asked whether to keep the
-- list now that the three role numbers do its job: "Hide it"). Where the
-- Upgrades module is on and covers your class, the list is emptied: the
-- game's lines cannot be taken off a tooltip, so each is left with no words
-- at the smallest size, and the game squeezes blank lines at a tooltip's
-- end. Anywhere else (the module off, a class it does not cover yet) the
-- list is all there is, and it is folded into the card as before.
function M.HidesDelta()
	local up = BT.Upgrades
	return M.TILES_LOOK and BT.Enabled("upgrades") and type(up) == "table" and type(up.Covers) == "function"
		and up.Covers() == true
end

-- Folds the stat changes on a comparison tooltip the card was written on;
-- returns the line that heads them, or nil
function M.FoldDelta(tip)
	local b = bitsOf[tip]
	if not tip.NumLines then
		return nil
	end
	local T, I = BT.UnitTip, M.ITEM
	local n = BT.Pill.Number(tip:NumLines(), 0)
	local head = nil
	for i = 2, n do
		local fs = T.LineOf(tip, i)
		-- (words the game keeps secret are not the heading)
		local ok, text = pcall(function() return fs and fs:GetText() end)
		if ok and type(text) == "string" and not (issecretvalue and issecretvalue(text)) and isDeltaHead(text) then
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
	if M.HidesDelta() then
		local from = (above and blank(above:GetText())) and head - 1 or head
		for i = from, n do
			for _, side in ipairs({ "TextLeft", "TextRight" }) do
				local line = T.LineOf(tip, i, side)
				if line and line.SetText then
					line:SetText("")
				end
			end
			T.SizeLine(tip, i, 1, nil, "text")
		end
		if b and b.deltaRule then
			b.deltaRule:Hide()
		end
		M.composing = true
		pcall(tip.Show, tip)
		M.composing = false
		return head
	end
	-- (the fold is drawn with the card's own parts: no card, nothing folded)
	if not b then
		return nil
	end
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
	-- the new card's foot strip ends above these lines, which the client
	-- wrote under the foot (M.WriteItemB)
	if b.strip and b.strip.IsShown and b.strip:IsShown() and b.stripFrom then
		M.LayStrip(tip, b, b.stripFrom, fs)
	end
	return head
end

if TooltipComparisonManager and TooltipComparisonManager.SetItemTooltip and hooksecurefunc then
	hooksecurefunc(TooltipComparisonManager, "SetItemTooltip", function(self, primary)
		if not BT.Enabled("tooltips") then
			return
		end
		local tips = type(self.tooltip) == "table" and self.tooltip.shoppingTooltips
		local tip = type(tips) == "table" and tips[primary and 1 or 2]
		-- (not on a fill left as the game's: there is no card to fold into)
		if tip and not M.IsSpared(tip) then
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

-- (the client's sentences are made patterns by `shape`, by the items' own)

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

-- (`hex` is with the items' colours, by M.FactCells, which writes both
-- cards' cells)

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
-- `enemy`: an enemy's ability, whose DPS goes by its cooldown.
-- `head`: the name, its colour, what goes under it and any rows before the
-- spell's own, where the tooltip wrote them above the spell's lines
-- (M.AppendedHead); the spell's first line is then not its name.
function M.ReadSpell(data, kind, fresh, enemy, head)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local LT = (Enum and Enum.TooltipDataLineType) or {}
	local spell = { tiles = {}, rows = {}, sub = {}, facts = {} }
	if head then
		spell.name, spell.nameRgb = head.name, head.rgb
		for _, s in ipairs(head.sub or {}) do
			spell.sub[#spell.sub + 1] = s
		end
		for _, r in ipairs(head.rows or {}) do
			spell.rows[#spell.rows + 1] = r
		end
	end
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
							-- (and as the client said it: M.WriteSpellB)
							spell.rangeText = text
						else
							local tile = { value, label, (c and not isGold(c) and c[2] < 0.5) and c or nil }
							spell.tiles[#spell.tiles + 1] = tile
							-- and as the client said it, for the line of plain facts
							local fact = { text = text, rgb = tile[3], lower = true, label = label }
							spell.facts[#spell.facts + 1] = fact
							if label == "Cast" then
								spell.cast = value
							elseif label == "Cooldown" then
								spell.cooldown = value
							else
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
		local label, value, amount, over, weapon, after, bonus, hit, points
		local found = nil
		for _, r in ipairs(spell.rows) do
			label, value, amount, over, weapon, after, bonus, hit, points = M.SpellAmount(r.text, M.IsShot(spell.range))
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
			-- (a finishing move's, with how many combo points it is for)
			table.insert(spell.facts, 1, { text = ("%s %s%s%s%s"):format(said, label:lower(),
				type(over) == "number" and (" over " .. M.Lasting(over)) or "", weapon and " with your weapon" or "",
				points and (" at %d point%s"):format(points, points == 1 and "" or "s") or ""),
				amount = true })
			-- A DESCRIPTION THAT SAYS NO MORE GOES (Josh 2026-10-17: "Let's go
			-- with your recommendation for hidin the paragraph descriptions"):
			-- one sentence, and after its amount nothing but how long
			if found.desc and not points and M.SaysNoMore(found.text, after) then
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
		local gcd = M.GCD
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
			-- A BLEED IS NO FASTER THAN IT TICKS (2026-10-17, audit): energy
			-- would let you put Garrote's 144 over 18 sec on every 5 sec, but
			-- one bleed does 8 a second, so the slower of the two
			if each and type(over) == "number" and over > 0 then
				each = math.min(each, amount / over)
			end
		elseif amount and type(over) == "number" and over > 0 then
			each = amount / over
		elseif amount and secs and not over then
			each = amount / math.max(secs, gcd)
		end
		-- AN ENEMY'S NO FASTER THAN ITS COOLDOWN (Josh 2026-10-18: "yes, use the
		-- cooldown for enemy abilities"): Stitches's Aura of Rot does its 38
		-- once every 3 sec, 12.7 a second, not 25.3 by the global cooldown. A
		-- spell of yours keeps the figure for casting it as fast as you can.
		local cd = enemy and M.CastSeconds(spell.cooldown)
		if each and cd and cd > 0 then
			each = math.min(each, amount / cd)
		end
		-- BOTH FIGURES AT THE TOP RIGHT (Josh 2026-10-17: "I'm also not 100%
		-- sold on the healing per mana and casts to empty line... Just go ahead
		-- and build it"): DPS or HPS beside the name, in red or green, and
		-- what it comes to for each point it costs beside the rank, in the
		-- resource's colour ("I think I prefer the old "damage per energy""),
		-- energy's as well as mana's and rage's. The casts to empty are gone
		-- ("I think we should just remove the total number of casts as well...
		-- not really valuable").
		-- NEITHER FOR DAMAGE ON A HIT (Josh 2026-10-18: "I'm not sure the 'per
		-- mana' makes sense here though, since it is a buff"): Thorns does its
		-- 3 on each of many hits, so it has no DPS and no per mana
		-- (M.ON_A_HIT). With no figures, the name and rank are written as for
		-- a spell that says no amount, with no room kept at their right.
		local figs = {}
		if each and not hit then
			local word, ink = M.PerSecond(label)
			figs[1] = { M.Figure(each), word, ink }
		end
		if amount and cost and cost > 0 and not hit then
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

-- the global cooldown, which an instant spell still takes (an energy
-- ability's DPS goes by the energy coming back instead)
M.GCD = 1.5

-- an amount's middle as the line of facts says it: 28.5, or 51 where it is
-- whole; a whole one with its thousands marked, "1,400" (2026-10-17, audit)
function M.Middle(n)
	n = M.Tenths(n)
	if n == math.floor(n) then
		return U.Commas(n)
	end
	return ("%.1f"):format(n)
end

-- to the nearest tenth, a half always up (the C library's own rounding of
-- "%.1f" sends an exact half to the even tenth: 95.25 to 95.2)
function M.Tenths(n)
	return math.floor(n * 10 + 0.5) / 10
end

-- a worked-out figure as a tile shows it: one place under a hundred, and
-- whole with its thousands marked above
function M.Figure(n)
	if n < 100 then
		return ("%.1f"):format(M.Tenths(n))
	end
	return U.Commas(math.floor(n + 0.5))
end

-- a figure's own colour at the top right of a card; an item's level a
-- quiet grey, under its DPS or armor
M.FIGURE_INK = {
	dps = { 1.00, 0.54, 0.48 }, hps = { 0.50, 0.91, 0.60 },
	mana = { 0.56, 0.71, 1.00 }, energy = { 1.00, 0.88, 0.48 }, rage = { 1.00, 0.44, 0.53 },
	level = BT.TEXT.soft,
}

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
	-- (a cooldown may be hours or days)
	local scale = { min = 60, hrs = 3600, days = 86400 }
	return n * (scale[unit] or 1)
end

-- WHAT A SPELL DOES, IN NUMBERS: the client says it only in its description,
-- in words ("absorbing 47 damage", "causes 56 to 73 Fire damage", "Heals 66
-- damage over 6 sec"). Read in this order, because an absorb and a heal are
-- also written with the word "damage". Each is a pattern with the amount, or
-- the lowest and the highest, in its captures.
-- ALSO "OF", "LIFE", "6-11" AND "TRANSFERS" (2026-10-17, audit): Renew's
-- first rank "Heals the target of 45 damage", a Healthstone's "restores 100
-- life", a finishing move's "1 point: 6-11 damage" (its middle, not the 11)
-- and Drain Life's "Transfers 10 health". A number standing alone starts
-- where no other number does, so the 5 of "2.5 additional damage" is not one.
-- EVERY CLASS'S SPELLS, AS THIS GAME WORDS THEM (Josh 2026-11-17: "Was this
-- only paladin? What about all the other classes?"; his record of 1,938
-- class spells, each beside what was read from it). What was missed or
-- misread, and is read now:
--   "Healed for 250 to 269" (Holy Shock), "to be healed for 49" (Judgement
--     of Light, Devour Magic)
--   "Heals your pet 116 health every second" (Mend Pet), "Gives 89 health
--     to the caster's pet" (Health Funnel), "recovering 1,930 health"
--     (Consume Shadows), "restore 1,440 health" (Create Healthstone)
--   "deals 52 Frost Damage", with a capital (Frozen Orb)
--   a percent is not an amount: "healing you for 10% of your maximum
--     health" read 10 and hid Victory Rush's 44 damage; so did "absorbing
--     15% of the amount healed" and five more (M.NOT_AMOUNTS)
--   nor is "1 Shadow damage for each point of Mana" (Feedback), nor
--     "Restores 5 mana per 5 sec"
--   "281 to 318, then jumps" (Chain Heal) kept its comma: "281–318,"
--   the amount said first is the spell's, whichever kind it is: Holy Nova
--     "causing 179 to 206 Holy damage ... and healing all party members ...
--     for 295 to 342" read as a heal, because heals were looked for before
--     damage (M.SpellAmount)
M.AMOUNTS = {
	{ "Absorb", { "[Aa]bsorbing ([%d,]+)", "[Aa]bsorbs? ([%d,]+)", "[Ss]hields up to ([%d,]+)" } },
	{ "Healing", { "[Hh]eal[singed]* [^%.]-for ([%d,]+) to ([%d,]+)", "[Hh]eal[singed]* [^%.]-for ([%d,]+)",
		"[Hh]eals? ([%d,]+)", "[Hh]eals? [^%.]-of ([%d,]+)", "[Rr]estores? ([%d,]+) to ([%d,]+) health",
		"[Rr]estores? ([%d,]+) health", "[Rr]estores ([%d,]+) to ([%d,]+) life", "[Rr]estores ([%d,]+) life",
		"[Hh]eals [%a ]-([%d,]+) health", "[Gg]ives ([%d,]+) health", "[Rr]ecover[sing]* ([%d,]+) health" } },
	-- a drink, or a mana potion
	{ "Mana", { "[Rr]estores ([%d,]+) to ([%d,]+) mana", "[Rr]estores ([%d,]+) mana" } },
	{ "Damage", { "%f[%d%.,]([%d,]+) to ([%d,]+) [%a ]-[Dd]amage", "%f[%d%.,]([%d,]+)%-([%d,]+) [%a ]-[Dd]amage",
		"%f[%d%.,]([%d,]+) %a* ?[Dd]amage", "[Tt]ransfers ([%d,]+) health" } },
}

-- NOT AN AMOUNT (2026-10-17, audit): a number followed by a length of time
-- or a distance, or by the rest of a decimal. Healing Stream Totem lasts
-- "for 1 min that heals ... for 6": the 1 is how long, and the 6 is the heal.
-- NOR A PERCENT, NOR ONE "FOR EACH POINT" OR "PER" SOMETHING (2026-11-17, the
-- record of every class's spells; see M.AMOUNTS)
M.NOT_AMOUNTS = { "^%.%d", "^%s*sec", "^%s*min", "^%s*hours?%f[%A]", "^%s*yards?%f[%A]", "^%s*yd%f[%A]",
	"^%%", "^%s*for each point", "^%s*per %d" }
local function notAnAmount(after)
	for _, p in ipairs(M.NOT_AMOUNTS) do
		if after:find(p) then
			return true
		end
	end
	return false
end

-- How long a description says it lasts, in seconds: the first "for 15 sec",
-- "Lasts 5 sec" or "for 1 min" in it; nil where it says none
function M.LastsFor(text)
	local best, at = nil, nil
	for _, p in ipairs({ "()for (%d+) (%a+)", "()[Ll]asts (%d+) (%a+)" }) do
		for pos, n, unit in text:gmatch(p) do
			if unit:find("^sec") or unit:find("^min") then
				if not at or pos < at then
					best, at = tonumber(n) * (unit:find("^min") and 60 or 1), pos
				end
				break
			end
		end
	end
	return best
end

-- AT NO RATE YOU SET (2026-10-17, audit): a totem that attacks as often as
-- it likes (Searing Totem). It works over time at a rate the words do not
-- give, so it has no DPS.
-- NOR PER MANA (2026-10-18, as Thorns): its 10 is one attack of the dozen
-- or so it makes for the mana, so 0.40 per mana said a twelfth of it.
M.NO_RATE = { "repeatedly" }

-- ON A HIT, NO RATE AT ALL (Josh 2026-10-18: "I'm not sure the 'per mana'
-- makes sense here though, since it is a buff"). Thorns does its 3 each
-- time an enemy strikes the target, so 3 for 35 mana counts one hit of
-- many, and its 10 minutes say nothing of how often. Damage to whoever
-- strikes you (Lightning Shield, Retribution Aura, Fire Shield,
-- Shadowguard), on a block (Holy Shield) and on each swing of your weapon
-- (Seal of Righteousness, Flametongue Weapon) is the same. Such a spell
-- keeps its amount, what one hit does, and has no DPS and no per mana.
-- It is read by the words, so every rank is covered. "A hammer that
-- strikes an enemy" is a hit of your own, and Overpower's "cannot be
-- blocked" and Revenge's "must follow a block" are not damage on a block.
M.ON_A_HIT = { "when hit", "when struck", "attackers?", "any %a+ that strikes", "who strikes", "attacks? blocked",
	"each melee attack", "each hit" }

-- whether `text` has one of `words` in it, each a whole word or words
local function says(text, words)
	local lower = text:lower()
	for _, word in ipairs(words) do
		if lower:find("%f[%a]" .. word .. "%f[%A]") then
			return true
		end
	end
	return false
end

-- A MELEE OR RANGED ABILITY ADDS TO YOUR WEAPON (Josh 2026-10-17, picking
-- "Count weapon damage"). "Causes 3 damage in addition to your normal weapon
-- damage" is the weapon's hit and 3, so the weapon's own damage - the
-- character sheet's, from UnitDamage - is added in; without it a Sinister
-- Strike's per energy was worked out on 3. Read before the spells' patterns,
-- which would take the 3 alone. Each: the pattern, and what it adds to -
-- "plus" the weapon and the number, "share" a share of the weapon and the
-- number, "weapon" the weapon alone.
--
-- A SHARE WITH A POINT IN IT, AND A RANGE ADDED (Josh 2026-11-16, two
-- screenshots: "I think somehow the rank tooltips are reversed... rank 1
-- should be the weakest"). Holy Strike rank 1, "causes 30% weapon damage
-- plus an additional 9 to 12 as Holy damage", read 61; rank 4, "43.2%
-- weapon damage plus an additional 19 to 22", read 4.1. The share was read
-- from digits alone, so 43.2% was taken as 2%. The "additional 9 to 12" was
-- not read at all. Now a share may have a point, and the range is added.
M.WEAPON_AMOUNTS = {
	{ "([%d,]+) damage in addition to your normal weapon damage", "plus" },
	{ "(%d[%d,%.]*)%% weapon damage plus an additional ([%d,]+) to ([%d,]+)", "share" },
	{ "(%d[%d,%.]*)%% weapon damage plus an additional ([%d,]+)", "share" },
	{ "(%d[%d,%.]*)%% weapon damage plus ([%d,]+)", "share" },
	{ "weapon damage plus ([%d,]+)", "plus" },
	{ "[Ii]ncreases ranged damage by ([%d,]+)", "plus", ranged = true },
	{ "[Ii]ncreases melee damage by ([%d,]+)", "plus" },
	{ "[Nn]ext attack by ([%d,]+) damage", "plus" },
	{ "(%d[%d,%.]*)%% weapon damage", "share" },
	-- Seal of Command, "Holy damage equal to 70% of normal weapon damage"
	-- (the spellbook as recorded 2026-11-16: its Judgement's 80 to 85 was
	-- shown as the seal's)
	{ "(%d[%d,%.]*)%% of normal weapon damage", "share" },
	-- Divine Storm, "causes 110% of weapon damage" (the record of every
	-- class's spells, 2026-11-17)
	{ "(%d[%d,%.]*)%% of weapon damage", "share" },
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

-- A HUNTER'S SHOT IS THE RANGED WEAPON'S (Josh 2026-11-17, of Chimera Shot
-- and Kill Shot worked out from the melee weapon: "Can we fix the hunter
-- spells as well?"). "You deal 135% weapon damage" does not say which
-- weapon. The spell's range does: a hunter's ability that reaches past
-- M.SHOT_FROM yards is a shot, and one at melee range (Raptor Strike, Carve,
-- Mongoose Bite) is a strike. Only for a hunter: a rogue's Shadowstrike
-- reaches 20 yards and hits with the weapon in hand.
-- `range`: the spell's range as its tooltip says it ("8-35 yd range").
M.SHOT_FROM = 10
function M.IsShot(range)
	if type(range) ~= "string" or type(UnitClass) ~= "function" then
		return false
	end
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or plainLine(class) ~= "HUNTER" then
		return false
	end
	local far = 0
	for n in range:gmatch("%d+") do
		far = math.max(far, tonumber(n) or 0)
	end
	return far > M.SHOT_FROM
end

local function weaponAmount(text, shot)
	for _, w in ipairs(M.WEAPON_AMOUNTS) do
		local _, last, a, b, c = text:find(w[1])
		-- (not a share for each of something: Lacerate bleeds "for 20 damage
		-- over 15 sec plus 10% weapon damage per existing application", and
		-- was read as a hit for 10% of the weapon; 2026-11-17)
		if last and text:find("^ per ", last + 1) then
			last = nil
		end
		if last then
			-- plus: the least it adds; top: the most, where it says a range
			local share, plus = 1, 0
			if w[2] == "plus" then
				plus = number(a) or 0
			elseif w[2] == "share" then
				share, plus = (number(a) or 100) / 100, b and number(b) or 0
			end
			local top = c and number(c) or plus
			-- what it adds to a whole hit of the weapon, for an ability that takes
			-- the place of a swing (M.ReadSpell)
			local bonus = (share == 1 and plus > 0) and plus or nil
			local lo, hi = M.WeaponDamage(w.ranged or shot)
			if not lo then
				-- the weapon unknown: what it adds, and no figures
				return "Damage", plus > 0 and ("+" .. plus) or "weapon", nil, false, false, text:sub(last + 1), bonus
			end
			-- the range in whole numbers, the middle from the weapon's own
			-- (Josh 2026-10-17: "Are we using real spell calculations? Like
			-- backstab says it does 150% weapon damage plus 30"): the middle of
			-- the rounded ends was up to half a point under the sum
			local l, h = math.floor(lo * share + plus), math.floor(hi * share + top + 0.5)
			return "Damage", l == h and tostring(l) or (l .. "–" .. h), (lo + hi) / 2 * share + (plus + top) / 2, false, true,
				text:sub(last + 1), bonus
		end
	end
	return nil
end

-- One amount M.SpellAmount found, as it returns it. An amount each second,
-- or every few, for so long is the whole of it: "26 Arcane damage each
-- second for 3 sec" is 78.
-- EVERY FEW SECONDS, HOWEVER IT SAYS HOW LONG (2026-10-17, audit): "every 1
-- sec. Lasts 15 sec." (Hellfire), "every 1 sec, and ... Lasts 10 sec."
-- (Hurricane), "every 1 second for 6 sec" (Volley), and a totem's "for 1 min
-- that heals ... for 6 every 2 seconds", which says how long before it.
local function amountOf(label, text, lo, hi, after)
	-- how many times it lands, and for how long, where the words say
	local times, lasts = 1, nil
	local each = after:match("^%s*%a*%s*each second for (%d+) sec")
	local every, rest = after:match("^[^%.]-every (%d+) sec%a*%.?(.*)$")
	-- "every second" is every 1 sec (Drain Life, as the Classic database
	-- words it: 2026-10-18)
	if not every then
		rest = after:match("^[^%.]-every second%.?(.*)$")
		every = rest and 1 or nil
	end
	every = tonumber(every)
	if each then
		times, lasts = tonumber(each), tonumber(each)
	elseif every and every > 0 then
		local long = M.LastsFor(rest) or M.LastsFor(text)
		if long then
			times, lasts = math.floor(long / every), long
		end
	end
	if not lasts then
		local n, unit = after:match("^%s*%a*%s*over (%d+) (%a+)")
		if n then
			lasts = tonumber(n) * (unit:find("^min") and 60 or 1)
		end
	end
	-- over time: for how many seconds, or only that it is (M.NO_RATE,
	-- M.ON_A_HIT)
	local hit = says(text, M.ON_A_HIT) or says(text, M.NO_RATE)
	local over = lasts
		or (times > 1 or after:find("^%s*%a*%s*each second") ~= nil or every ~= nil or hit)
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
	return label, value, ((a + (b or a)) / 2) * times, over, false, after, nil, hit
end

-- Reads what a description does: its tile's label and value ("56–73"), the
-- amount in one number (the middle of a range), whether it works over time
-- (for how many seconds, where it says, or true), whether your weapon's
-- damage is in it, what follows the amount, what it adds to a plain hit of
-- the weapon where that is a number, and whether it lands on a hit, so has
-- no rate (M.ON_A_HIT). Nil where it says no amount.
-- A FINISHING MOVE AT ITS MOST POINTS (Josh 2026-11-17, working down what
-- was left: "Proceed"). A finishing move lists what it does at each number
-- of combo points:
--     1 point  : 6-10 damage
--     ...
--     5 points: 26-30 damage
-- The first amount in the words was taken, so Eviscerate's card said what
-- it does at 1 point, which is how it is used least. The line with the
-- most points is read now, and the card says how many points that is.
-- A line with a percent in it is not such a list (Death Mark's "60% stored,
-- 1,605 damage cap"), and is left to be read as before.
-- Returns how many points, and that line's words; nil where there is no list.
function M.FinisherLine(text)
	local most, words = nil, nil
	for points, rest in text:gmatch("(%d) points?%s*:%s*([^\n]*)") do
		points = tonumber(points)
		if rest:find("%%") then
			return nil
		end
		if points and (not most or points > most) then
			most, words = points, rest
		end
	end
	return most, words
end

-- `shot`: the weapon in it is the ranged one (M.IsShot).
-- For a finishing move, a ninth answer: how many combo points the amount
-- is for (M.FinisherLine).
function M.SpellAmount(text, shot)
	if type(text) ~= "string" then
		return nil
	end
	local points, line = M.FinisherLine(text)
	if points and line and not line:find("%d points?%s*:") then
		local label, value, amount, over, weapon, after, bonus, hit = M.SpellAmount(line, shot)
		if label then
			return label, value, amount, over, weapon, after, bonus, hit, points
		end
	end
	local wl, wv, wa, wo, ww, wafter, wbonus = weaponAmount(text, shot)
	if wl then
		return wl, wv, wa, wo, ww, wafter, wbonus, says(text, M.ON_A_HIT)
	end
	-- AND WHICHEVER KIND IT IS (2026-11-17, Holy Nova: see M.AMOUNTS). Where
	-- two kinds start at the same number, "Heals 66 damage", the kind
	-- listed first has it, as before.
	local best
	for _, kind in ipairs(M.AMOUNTS) do
		-- THE AMOUNT SAID FIRST, WHICHEVER PATTERN FINDS IT (the spellbook as
		-- recorded 2026-11-16). Seal of Fury: "melee attacks ... deal an
		-- additional 11 Holy damage ... Unleashing this Seal's energy inflicts
		-- 54 to 57 Holy damage". The patterns were tried in turn over the
		-- whole description, so the range, which is its Judgement's, was
		-- taken before the 11, which is the seal's. Seal of Righteousness
		-- says a range first and was read as the seal. Now each pattern's
		-- first amount is found and the one that comes first in the words is
		-- kept; where two start at the same place, the earlier pattern's.
		for _, p in ipairs(kind[2]) do
			-- a pattern's first match that is an amount; one that is a length
			-- of time or a distance is passed over (M.NOT_AMOUNTS)
			local from = 1
			while true do
				local first, last, lo, hi = text:find(p, from)
				if not first then
					break
				end
				local after = text:sub(last + 1)
				-- (a comma alone is no amount: "the friendly target, reducing
				-- damage" in Blessing of Sanctuary, 2026-10-18)
				if lo and lo:find("%d") and not notAnAmount(after) then
					-- where the amount itself starts, not the words before it
					local at = text:find(lo, first, true) or first
					if not best or at < best.at then
						-- (without the comma a list goes on with: "281 to 318, then")
						best = { at = at, lo = lo:gsub(",+$", ""), hi = hi and hi:gsub(",+$", ""), after = after, kind = kind[1] }
					end
					break
				end
				from = first + 1
			end
		end
	end
	do
		if best then
			local label, value, amount, over, weapon, after, bonus, hit = amountOf(best.kind, text, best.lo, best.hi, best.after)
			-- AND WHAT THE FIRST FEW ENEMIES TAKE BESIDES (the same record).
			-- Consecration: "doing 16 Holy damage over 8 sec to enemies who
			-- enter the area. The first 4 enemies who enter the area will take
			-- an additional 50 damage over 8 sec." It read 16. One enemy takes
			-- 66, so the 50 is added.
			local more = label == "Damage" and type(amount) == "number" and not best.hi
				and number(best.after:match("[Tt]he first %d+ enemies [^%.]-an additional ([%d,]+) damage"))
			if more then
				amount = amount + more
				value = amount == math.floor(amount) and ("%d"):format(amount) or tostring(amount)
			end
			return label, value, amount, over, weapon, after, bonus, hit
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
	local sub = table.concat(spell.sub, " · ")
	c.header(spell.name, spell.nameRgb or ITEM_INK, icon, sub, spellColour(spell), spell.figs)
	-- as wide as the name and the line under it, each with its figure, need
	local floor = spell.figs and I.MIN_W or I.PLAIN_W
	local needs = math.min(MAX_W, c.needs(spell.name, sub, spell.figs))
	-- the plain facts - what it does, what it costs, how long it takes - in
	-- cells, their numbers brighter than their words, a cost you cannot pay
	-- in the client's red, in rows as wide as the card (M.FactCells, which
	-- an item's cells are written by too)
	if #spell.facts > 0 then
		c.spacer()
		c.cells(M.FactCells(spell.facts), math.max(floor, needs) - I.INSET)
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

-- A SPELL OR A BUFF IN THE ITEM CARD'S LOOK (Josh 2026-11-17: "I think we
-- can proceed with the remaining tooltips"; the canvas's "B, chosen" boards
-- have Holy Light and Blessing of Might). Written by the item's card
-- (M.WriteItemB), handed the spell as that card takes things:
--   the band in the spell's colour (a debuff's kind, or the accent), with
--     its picture, its name and the line under it
--   its two figures (damage or healing a second, and per mana) as tiles
--   what it asks of you and what it does, as lines
--   what it costs, how long it takes and how far it reaches, in the foot,
--     where they had been a grid of cells
-- M.WriteSpell is the card before, and is written if this one fails.
-- LAID OUT AS THE GAME'S OWN, AND NO WIDER (Josh 2026-11-17, six
-- screenshots beside the game's Holy Strike: "Some tooltips seem way too
-- wide. Also not sure how I feel about the footer. I think maybe spells
-- content should be arranged more like the default tooltip"). The cost, the
-- cast time, the cooldown and the damage had been one line in the foot,
-- "97.1 damage with your weapon · 13 mana · instant · 10 sec cooldown", and
-- that line made Holy Strike's card 400 wide. The foot is gone from a
-- spell's card. Under the tiles its facts are two to a line as the game
-- has them, in the game's words:
--     13 Mana                 Melee Range
--     Instant              10 sec cooldown
-- then what it comes to ("97.1 damage with your weapon"), then what it
-- does. The range is on its line again and out from under the name.
function M.WriteSpellB(tip, spell, icon)
	local colour = spellColour(spell)
	local sub = {}
	for _, words in ipairs(spell.sub) do
		if not (spell.rangeText and words == spell.range) then
			sub[#sub + 1] = words
		end
	end
	local item = { name = spell.name, quality = spell.nameRgb or ITEM_INK, bandRgb = colour, edgeRgb = colour,
		subText = table.concat(sub, " · "), stats = {}, effects = {}, rest = {}, notes = {}, extraDamage = {},
		rows = {} }
	local group = {}
	for i = 1, 2 do
		local f = spell.figs and spell.figs[i]
		if type(f) == "table" and f[1] then
			group[#group + 1] = { value = f[1], label = f[2], rgb = f[3] }
		end
	end
	if #group > 0 then
		item.more = { tiles = { group } }
	end
	-- the facts in the game's order: what it costs and how far it reaches,
	-- how long it takes and how long until it can be cast again, then any
	-- other (a buff's time left)
	local cost, cast, cooldown, amount, others = nil, nil, nil, nil, {}
	for _, f in ipairs(spell.facts) do
		if f.amount then
			amount = f
		elseif f.label == "Cast" then
			cast = f
		elseif f.label == "Cooldown" then
			cooldown = f
		elseif f.label and not cost then
			cost = f
		else
			others[#others + 1] = f
		end
	end
	local halves = {}
	for _, f in ipairs({ cost or false, spell.rangeText and { text = spell.rangeText } or false, cast or false,
		cooldown or false }) do
		if f then
			halves[#halves + 1] = f
		end
	end
	for _, f in ipairs(others) do
		halves[#halves + 1] = f
	end
	for i = 1, #halves, 2 do
		local left, right = halves[i], halves[i + 1]
		item.rows[#item.rows + 1] = { text = left.text, rgb = left.rgb or ITEM_INK, right = right and right.text or nil,
			rrgb = right and (right.rgb or ITEM_INK) or nil }
	end
	local gap = #item.rows > 0
	if amount then
		item.rows[#item.rows + 1] = { text = amount.text, rgb = ITEM_INK, gap = gap }
		gap = false
	end
	local first = true
	for _, r in ipairs(spell.rows) do
		if not r.hidden then
			item.rows[#item.rows + 1] = { text = r.text, rgb = r.desc and ITEM_QUIET or r.rgb, right = r.right, rrgb = r.rrgb,
				wrap = r.wrap, small = r.desc, gap = first and (gap or amount ~= nil) }
			first = false
		end
	end
	return M.WriteItemB(tip, item, icon, nil)
end

-- WHAT THE CLIENT WROTE, FOR CLAUDE (the Testing page's Record button). The
-- spell and buff tooltips were built from the client's strings without one
-- in hand, so the last few of each kind are kept as they came, and written
-- into the saved file on Record.
M.SEEN_MOST = 6
M.seen = { item = {}, spell = {}, aura = {}, macro = {}, object = {} }
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

-- EVERY SPELL IN YOUR SPELLBOOK, AND WHAT WAS READ FROM IT (Josh 2026-11-16,
-- after Holy Strike's "43.2% weapon damage" was read as 2%: "Are you sure all
-- the other spells are working, or will we find similar bugs?"). The reader
-- was written from other games' wordings, and this game words some spells
-- its own way. So Record also writes each spell's name, rank and words as
-- the client gives them, beside the label, value and amount M.SpellAmount
-- took from them, for the two to be compared out of the game. It goes in
-- the tooltips' own record, as `book` (a module has one record).
function M.BookRead()
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo
		and C_Spell and C_Spell.GetSpellDescription) then
		return nil
	end
	local out = { spells = {} }
	local lo, hi = M.WeaponDamage()
	out.weapon = lo and { lo, hi } or nil
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if type(info) == "table" then
			local first = (info.itemIndexOffset or 0) + 1
			for index = first, first + (info.numSpellBookItems or 0) - 1 do
				local ok, item = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
				local id = ok and type(item) == "table" and plainLine(item.actionID or item.spellID) or nil
				if type(id) == "number" then
					local okText, text = pcall(C_Spell.GetSpellDescription, id)
					text = okText and plainLine(text) or nil
					local one = { id = id, name = plainLine(item.name), rank = plainLine(item.subName),
						passive = plainLine(item.isPassive), words = text }
					if type(text) == "string" then
						local okRead, label, value, amount, over, weapon = pcall(M.SpellAmount, text)
						if okRead then
							one.label, one.value, one.amount, one.over, one.weapon = label, value, amount, over, weapon
						else
							one.err = tostring(label)
						end
					end
					out.spells[#out.spells + 1] = one
				end
			end
		end
	end
	return out
end

-- AND EVERY OTHER CLASS'S (Josh 2026-11-16: "Was this only paladin? What
-- about all the other classes?"). The game describes any spell by its id,
-- whoever asks. BT.ClassSpells (ClassSpellData.lua, made from the client's
-- own tables) has the id of every spell in every class's skill lines, so
-- one character's Record writes them all: each skill line's spells with
-- their words and what M.SpellAmount took from them.
--
-- The game has not always got a spell's words ready the first time it is
-- asked. Those are asked for and counted in `waiting`; a second Record a few
-- seconds later has them.
--
-- THE LIST OF IDS IS NOT SHIPPED (2026-11-17, the check done). It is 35 KB
-- that a player has no use for. With no BT.ClassSpells this does nothing.
-- To run the check again, after a patch that rewords spells: make the list
-- with scripts/make-class-spells.py and add Modules\Tooltips\ClassSpellData.lua
-- to BeebMod.toc above this file, for as long as the check takes.
--
-- A SPELL WITH NO WORDS IS NOT ONE TO WAIT FOR (Josh 2026-11-17, a screenshot
-- of six Records: "1937 class spells read, 1619 not ready", then 1997 and
-- 1559, then 1937 and 1619 again: "Not sure this is working"). About 1,600
-- of the ids are spells the game has and describes with nothing: passives,
-- hidden parts of other spells. Every one with a name and no words was
-- counted as not ready, so the count could never reach 0. Now the game is
-- asked whether it has the spell's data (C_Spell.IsSpellDataCached). With
-- the data and no words, the spell is counted in `wordless` and not waited
-- for.
function M.ClassesRead()
	if not (BT.ClassSpells and C_Spell and C_Spell.GetSpellDescription) then
		return nil
	end
	local out = { lines = {}, waiting = 0, spells = 0, wordless = 0 }
	for _, line in ipairs(BT.ClassSpells) do
		local list = {}
		for _, id in ipairs(line[2]) do
			local okText, text = pcall(C_Spell.GetSpellDescription, id)
			text = okText and plainLine(text) or nil
			local okName, name = pcall(C_Spell.GetSpellName or tostring, id)
			name = okName and plainLine(name) or nil
			if type(text) == "string" and text ~= "" then
				local one = { id = id, name = name, words = text }
				if C_Spell.GetSpellSubtext then
					local okRank, rank = pcall(C_Spell.GetSpellSubtext, id)
					one.rank = okRank and plainLine(rank) or nil
				end
				local okRead, label, value, amount, over, weapon = pcall(M.SpellAmount, text)
				if okRead then
					one.label, one.value, one.amount, one.over, one.weapon = label, value, amount, over, weapon
				else
					one.err = tostring(label)
				end
				list[#list + 1] = one
				out.spells = out.spells + 1
			elseif name then
				local okHas, has = false, nil
				if C_Spell.IsSpellDataCached then
					okHas, has = pcall(C_Spell.IsSpellDataCached, id)
				end
				if okHas and plainLine(has) == true then
					-- the game has all it has of this spell, and no words
					out.wordless = out.wordless + 1
				elseif C_Spell.RequestLoadSpellData then
					-- a spell the game has, its words not ready
					pcall(C_Spell.RequestLoadSpellData, id)
					out.waiting = out.waiting + 1
				end
			end
		end
		out.lines[#out.lines + 1] = { name = line[1], spells = list }
	end
	return out
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
	local okBook, book = pcall(M.BookRead)
	out.book = okBook and book or nil
	local okClasses, classes = pcall(M.ClassesRead)
	out.classes = okClasses and classes or nil
	if out.classes then
		U.Print(("Records: %d class spells read, %d with no description, %d not ready. %s"):format(classes.spells,
			classes.wordless, classes.waiting,
			classes.waiting > 0 and "Press Record again in a few seconds." or "That is all of them."))
	end
	BT.EnsureBound()
	BeebModDB.tooltipsDump = out
	return n
end
BT.Record("tooltipsDump", M.Dump, "tooltips")

-- A WORLD OBJECT'S TOOLTIP, KEPT FOR THE RECORD as the others are. The game
-- hands an object's tooltip to addons under a type of its own.
do
	local DT = Enum and Enum.TooltipDataType
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and DT and DT.Object ~= nil then
		pcall(TooltipDataProcessor.AddTooltipPostCall, DT.Object, function(_, data)
			if BT.Enabled("tooltips") then
				pcall(M.Seen, "object", data)
			end
		end)
	end
end

-- Whether the tooltip shows an enemy's ability: the Expedition's enemy pages
-- mark their ability icons so (Modules/Expedition/Window.lua, V.SpellIcons)
function M.ShowsEnemyAbility(tip)
	if not tip.GetOwner then
		return false
	end
	local ok, owner = pcall(tip.GetOwner, tip)
	return ok and type(owner) == "table" and owner.beebEnemyAbility == true
end

-- A TALENT'S NAME (Josh 2026-11-10: "Seem to be missing skill names on some
-- talent tooltips", Seal of Command named "60 Mana"). The talent window
-- writes a talent's name and rank itself, then adds the spell's lines under
-- them (Blizzard_TalentDisplay.lua, AppendInfo "GetTraitEntry"). The spell's
-- lines start with its cost, so the card took the cost for the name. When a
-- spell's first line is not the tooltip's first, the lines above it are read
-- off the tooltip: the first is the name, a rank goes under it, and any
-- other line comes before the spell's rows.
-- Returns the head for M.ReadSpell; false when the spell's lines come first;
-- nil when the lines above cannot be read.
M.RANK_LINES = { shape("TALENT_BUTTON_TOOLTIP_RANK_FORMAT", "Rank %s/%s"),
	shape("TALENT_BUTTON_TOOLTIP_RANK_NO_MAX_FORMAT", "Rank %s"), "^Rank %d+/%d+$", "^Rank %d+$" }
function M.AppendedHead(tip, data)
	local first = nil
	for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
		local i = type(line) == "table" and plainLine(line.lineIndex) or nil
		if type(i) == "number" then
			first = i
			break
		end
	end
	if not first or first <= 1 then
		return false
	end
	local head = { sub = {}, rows = {} }
	for i = 1, first - 1 do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and known(fs:GetText())
		local words = type(text) == "string" and M.Bare(text):match("^%s*(.-)%s*$") or ""
		if words ~= "" then
			local rgb = nil
			if fs.GetTextColor then
				local ok, r, g, b = pcall(fs.GetTextColor, fs)
				rgb = ok and colourOf({ r = r, g = g, b = b }) or nil
			end
			local rank = false
			for _, p in ipairs(M.RANK_LINES) do
				rank = rank or words:find(p) ~= nil
			end
			if not head.name then
				head.name, head.rgb = words, rgb
			elseif rank then
				head.sub[#head.sub + 1] = words
			else
				head.rows[#head.rows + 1] = { text = words, rgb = (rgb == nil or isGold(rgb)) and ITEM_INK or rgb,
					wrap = true, desc = false }
			end
		end
	end
	return head.name and head or nil
end

function M.ComposeSpell(tip, data, kind)
	-- appended under lines the tooltip already had (a talent): read their
	-- name. A second block the same tooltip adds ("Next rank:") is left as
	-- the client wrote it, under the card.
	local head = nil
	-- a trainer's recipe, with the made item inside it: a recipe's card
	if kind == "spell" and M.TILES_LOOK then
		local recipe = M.TrainerRecipe(data)
		if recipe and M.ReadRecipe(recipe, false) then
			M.ComposeItem(tip, recipe)
			return
		end
	end
	if kind == "spell" then
		head = M.AppendedHead(tip, data)
		if head == nil or (head and tip.beebsSpellCard) then
			return
		end
		head = head or nil
	end
	-- whatever a unit left on the tooltip goes, as for an item
	local s = skins[tip]
	if s then
		s.wantEdge, s.wantTop, s.extraBottom, s.ours = nil, nil, nil, nil
	end
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	M.Seen(kind, data)
	-- another addon's lines, read off the lines the data drew before a macro's
	-- data is swapped for its spell's (M.OthersLines)
	local others = M.OthersLines(tip, data)
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
	local spell = M.ReadSpell(data, kind, fresh, M.ShowsEnemyAbility(tip), head)
	if spell then
		for _, row in ipairs(others or {}) do
			spell.rows[#spell.rows + 1] = { text = row.text, rgb = row.rgb or ITEM_INK, right = row.right, rrgb = row.rrgb,
				desc = false }
		end
	end
	if spell and tip.ClearLines and tip.AddLine then
		local icon = (id and M.SpellIcon(id)) or (byName and M.SpellIconByName(spell.name))
			or M.SpellIcon(spellOf(tip, data))
		-- the new look first, the card before if it fails (as an item's)
		local ok, err = false, nil
		if M.TILES_LOOK then
			ok, err = pcall(M.WriteSpellB, tip, spell, icon)
			if not ok then
				BT.Err("tooltips.WriteSpellB: " .. tostring(err))
			end
		end
		if not ok then
			ok, err = pcall(M.WriteSpell, tip, spell, icon)
		end
		if not ok then
			BT.Err("tooltips.spell: " .. tostring(err))
		end
		-- until the tooltip is cleared for something else
		if head then
			tip.beebsSpellCard = true
		end
	end
	-- dressed after the rebuild, as an item is (M.ComposeItem)
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

-- A QUEST OBJECT IN THE WORLD, IN THE SAME ROWS (Josh 2026-11-10: "regular
-- quest item tooltips don't seem to share the same style", a Sack of Oats
-- reading "Poor Old Blanchy" and "6/8 Handful of Oats" in the client's
-- plain lines). A sack, a crate or a flower is neither a unit nor an item:
-- the client draws it from data of its own kind (TooltipDataType Object),
-- and nothing of ours rebuilt it. When it counts for a quest, it is written
-- again as a unit is: its name as the client drew it, any other line it had,
-- then the quest rows (M.QuestRows). One with no quest is left alone.
function M.ComposeObject(tip, data)
	if tip == nil or tip ~= rawget(_G, "GameTooltip") or M.objecting or not BT.Enabled("tooltips") then
		return 0
	end
	local T = BT.UnitTip
	local first = lineOf(tip, 1)
	local name = first and first.GetText and known(first:GetText())
	if type(name) ~= "string" or name == "" then
		return 0
	end
	T.data = data
	local ok, quests, used = pcall(questBlock, tip, { [name] = true })
	T.data = nil
	if not (ok and type(quests) == "table") then
		return 0
	end
	local objectives = 0
	for _, q in ipairs(quests) do
		if not q.title then
			objectives = objectives + 1
		end
	end
	if objectives == 0 then
		return 0
	end
	local function colour(fs)
		if not (fs and fs.GetTextColor) then
			return 1, 1, 1
		end
		local okC, r, g, b = pcall(fs.GetTextColor, fs)
		r, g, b = okC and known(r), okC and known(g), okC and known(b)
		if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
			return 1, 1, 1
		end
		return r, g, b
	end
	local nr, ng, nb = colour(first)
	local rest = {}
	for i = 2, BT.Pill.Number(tip:NumLines(), 0) do
		local fs = lineOf(tip, i)
		local text = fs and fs.GetText and known(fs:GetText())
		local trimmed = type(text) == "string" and text:match("^%s*(.-)%s*$") or nil
		if trimmed and trimmed ~= "" and not (used or {})[trimmed] then
			local r, g, b = colour(fs)
			rest[#rest + 1] = { trimmed, r, g, b }
		end
	end
	M.objecting = true
	local built, err = pcall(function()
		M.ClearLines(tip)
		tip:AddLine(name, nr, ng, nb)
		for _, l in ipairs(rest) do
			tip:AddLine(l[1], l[2], l[3], l[4], true)
		end
		-- (in the look: a gap under them, where the band ends: M.ObjectLook)
		if M.TILES_LOOK then
			tip:AddLine(T.TAG_BLANK)
			T.SizeLine(tip, BT.Pill.Number(tip:NumLines(), 1), M.UNIT.GAP, nil, "text")
		end
		T.gapped = nil
		M.QuestRows(tip, quests)
		if tip.Show then
			tip:Show()
		end
		M.ObjectLook(tip, 1 + #rest)
	end)
	M.objecting = false
	if not built then
		BT.Err("tooltips.object: " .. tostring(err))
		return 0
	end
	return objectives
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
	and Enum.TooltipDataType.Object then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tip, data)
		-- one no quest wants is left as the game drew it, with the band
		-- over all of it
		if M.ComposeObject(tip, data) == 0 and BT.Enabled("tooltips") and not M.objecting then
			pcall(M.ObjectLook, tip, nil)
		end
	end)
end

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
-- size and the quality spine here. An item or a spell on one is written again
-- as a card (M.ComposeItem, M.ComposeSpell), the compare included.
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
local TAB_TEXT = BT.TEXT.muted

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
		-- NOR THE "EQUIPPED" HEADER (2026-10-17, audit): it is dressed as
		-- furniture (dressHeader), and a second surface here took its colours
		-- down after the furniture had changed them, so switching the module
		-- off put the furniture's colour back over the client's gold.
		if holder.GetRegions and not holder.beebs and holder ~= tip.CompareHeader then
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
-- new thing needs a moment later. Not for a rebuild's own clear (M.ClearLines).
if GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipCleared", function(tip)
		if not M.clearing then
			tip.beebsSpellCard = nil
		end
		if BT.Enabled("tooltips") and not M.clearing then
			-- an error here comes out of whatever was writing the tooltip
			local ok, err = pcall(M.DressPlain, tip)
			if not ok then
				BT.Err("tooltips.cleared: " .. tostring(err))
			end
		end
	end)
end

-- THE CHAT LINK'S WINDOW IS WRITTEN AGAIN IN PLACE TOO (2026-10-17, audit).
-- Click a quest link while an item's card is open in it, and the quest came
-- up held to the card's width with the item's quality down its left: the
-- window stays open, so it never shows itself again (dressOther). Its clear
-- lets the width go and takes the spine off; a card written on it next puts
-- both back.
function M.RefCleared(tip)
	if tip.SetMinimumWidth then
		pcall(tip.SetMinimumWidth, tip, 0)
	end
	local s = skins[tip]
	if s and s.accent then
		s.accent:Hide()
		M.LeftBar(s)
	end
end
if _G.ItemRefTooltip and _G.ItemRefTooltip.HookScript then
	_G.ItemRefTooltip:HookScript("OnTooltipCleared", function(tip)
		if BT.Enabled("tooltips") and not M.clearing then
			local ok, err = pcall(M.RefCleared, tip)
			if not ok then
				BT.Err("tooltips.refcleared: " .. tostring(err))
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
		-- a secret unit (inside an instance) cannot be asked about: it is
		-- drawn as the game gives it, plainly dressed (T.Fill)
		if unit ~= nil and issecretvalue and issecretvalue(unit) then
			unit = nil
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
	-- ONE LOOK A FRAME (2026-11-11, audit): the tooltip is shown several
	-- times while one card is written, and across a bag dozens of times a
	-- second, and each show set a timer of its own for the same look
	local lateQueued = false
	local function late()
		lateQueued = false
		M.HookOthers(true)
	end
	GameTooltip:HookScript("OnShow", function(tip)
		if BT.Enabled("tooltips") then
			local ok, err = pcall(shown, tip)
			if not ok then
				BT.Err("tooltips.shown: " .. tostring(err))
			end
			if C_Timer and C_Timer.After then
				if not lateQueued then
					lateQueued = true
					C_Timer.After(0, late)
				end
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
	-- (a rebuild's own clear is not the tooltip going: M.ClearLines)
	if s and not M.clearing then
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

