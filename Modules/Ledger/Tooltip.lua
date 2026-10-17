-- Your notes, on the tooltip. Two APIs, because this client line carries the
-- modern tooltip system but a beta build is allowed to move: when
-- TooltipDataProcessor is there we use it, otherwise the old OnTooltipSetUnit
-- hook still works (Josh 2026-09-18).
--
-- WHAT YOU KNOW, AS ROWS (Josh 2026-10-17, the tooltip canvas "C, everything
-- as tags"). Your note, your tags, your rating, the times you grouped and
-- your duels are one row each under what the game knows, each led by a
-- small picture in the Ledger's violet (Core/Tooltip.lua, T.Row).
--
-- THE NOTE CAME BACK INSIDE. Since 2026-09-19 it floated above the tooltip as
-- a large quotation, because four lines of it inside were a third of the
-- tooltip. As a row it is two lines at most, in the italic the Expedition's
-- lore is set in, cut short with "..." when there is more: the whole note is
-- in the Ledger, a click away.
local _, BT = ...

local U = BT.Util
local T = {}
BT.Tooltip = T

local function tagsOn(p)
	local out = {}
	for _, f in ipairs(BT.AllTags()) do
		if p.tags and p.tags[f.key] then
			out[#out + 1] = f
		end
	end
	return out
end

-- the Ledger's colour, for the rows' pictures (the feature's own, Core/Init.lua)
T.VIOLET = { 0.61, 0.50, 0.82 }
local function violet()
	local feature = BT.Feature and BT.Feature("ledger")
	return feature and feature.color or T.VIOLET
end

-- the note: its size, its ink, and how many lines it may take
T.NOTE_SIZE, T.NOTE_LINES = 12, 2
T.NOTE_INK = { 0.94, 0.92, 0.84 }
-- the other rows' words: what you wrote in ink, what happened in a quieter one
local INK2 = { 0.73, 0.78, 0.76 }

-- TAGS AS ROWS, NOT PILLS (Josh 2026-09-19). Everywhere in the toolkit a tag
-- of yours is a square of its colour with its name beside it: the note panel,
-- the cards, and here. The squares are laid over the gaps the line keeps for
-- them (Core/Tooltip.lua owns that) and the words are plain ink, because a
-- colour picked for a square is a poor colour for words.
local function hidePills()
	BT.UnitTip.HideSwatches()
end
T.HidePills = hidePills

-- Adds a row for each thing you wrote or that happened between you, and
-- nothing for a stranger you have never written on.
function T.Fill(tip, unit)
	if not (BT.settings and BT.settings.tooltip and tip and unit and UnitIsPlayer(unit)) then
		-- A SWATCH OUTLIVING ITS TOOLTIP (Josh 2026-09-19). The squares are
		-- laid OVER tooltip lines rather than being part of them, so returning
		-- early without putting them away leaves the last character's tag
		-- colours sitting on somebody else's tooltip.
		hidePills()
		return
	end
	-- the SAME name resolution the collector uses: UnitName gives only the
	-- given name on this client, so looking up "Beeb" would never find the
	-- record filed under "Beeb Bob" (Josh 2026-09-18)
	local name, realm = BT.Util.UnitFullName(unit)
	local key = name and U.Key(name, realm)
	-- what YOU wrote, from the Ledger's own book (Modules/Ledger/Store.lua)
	local p = key and BT.Notes.Get(key)
	if not p then
		hidePills()
		return
	end
	-- someone you wrote on, in front of you: their face brought up to date
	local _, info = BT.Notes.Face(unit)
	BT.Notes.Seen(key, info)
	local Tip = BT.UnitTip
	local tint = violet()

	if p.note then
		local i = Tip.Row(tip, "note", tint, p.note, T.NOTE_INK, nil, nil, true)
		Tip.SizeLine(tip, i, T.NOTE_SIZE, nil, "quote")
		Tip.MaxLines(tip, i, T.NOTE_LINES)
	end

	-- ONE ROW, NOT TWO COLUMNS (Josh 2026-09-20). Two tags to a line put the
	-- second one at the far right of the tooltip, so three tags read as a
	-- little table with a hole in it. Packed along a single line with an even
	-- gap between them they read as what they are: a row of marks.
	--
	-- A tooltip line cannot measure a substring of itself, so the words before
	-- each square are measured off-screen and the squares are laid at those
	-- offsets - see Core/Tooltip.lua's ruler. The row's picture comes first,
	-- and is as wide as Tip.ICON_SIZE.
	local tags = tagsOn(p)
	if #tags > 0 then
		local LEAD, GAP = "    ", "   "
		local text, offsets, colours = "  ", {}, {}
		for i, f in ipairs(tags) do
			offsets[i] = Tip.ICON_SIZE + Tip.Measure(text, Tip.ROW) + 1
			colours[i] = f.color or { 0.6, 0.65, 0.62 }
			text = text .. LEAD .. f.label
			if i < #tags then
				text = text .. GAP
			end
		end
		local line = Tip.Row(tip, "tags", tint, text:sub(3), Tip.INK)
		Tip.SwatchesOnLine(tip, colours, line, offsets)
	else
		hidePills()
	end

	if p.rating then
		Tip.Row(tip, "rating", tint, ("Rated %d/5"):format(p.rating), Tip.INK)
	end
	-- how often you grouped with them, and the last time and place
	local grouped = BT.LedgerGroups and BT.LedgerGroups.Line(p)
	if grouped then
		Tip.Row(tip, "grouped", tint, grouped, INK2)
	end
	-- and your duels with them (Modules/Ledger/Duels.lua)
	local duels = BT.LedgerDuels and BT.LedgerDuels.Line(p)
	if duels then
		Tip.Row(tip, "duels", tint, duels, INK2)
	end

	-- the box is measured when it is shown, and everything above was added
	-- after the last time anybody showed it
	if tip.Show then
		tip:Show()
	end
	-- No "seen N times" line. The unit in front of you already tells the
	-- tooltip its level and guild, and a running tally of how often you have
	-- walked past somebody is not worth a line on every mouseover (Josh
	-- 2026-09-18). The search window still keeps the count.
end

-- THE CORE OWNS THE HOOK (Josh 2026-09-19). This used to hook GameTooltip
-- itself. Then the Tooltips module arrived, which REBUILDS the tooltip, and
-- two hooks in file order means whichever rebuilt last wiped the other. Now
-- the core hands the tooltip round in a known order and this decorates
-- whatever composed it, compact or not.
BT.OnUnitTooltip("ledger", 20, function(tip, unit)
	T.Fill(tip, unit)
end)

-- the squares belong to whatever the tooltip is showing NOW, so they go away
-- with it rather than hanging over the next thing you point at
BT.OnUnitTooltipHide(hidePills)

-- kept so the rest of the Ledger can say "redraw that" without knowing who
-- else has a say in it
T.Restack = function()
	return BT.UnitTip.Restack()
end
