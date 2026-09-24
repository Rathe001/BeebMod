-- Your notes, on the tooltip. Two APIs, because this client line carries the
-- modern tooltip system but a beta build is allowed to move: when
-- TooltipDataProcessor is there we use it, otherwise the old OnTooltipSetUnit
-- hook still works (Josh 2026-09-18).
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Tooltip.lua")

local U, DB = BT.Util, BT.DB
local T = {}
BT.Tooltip = T

local function flagsOn(p)
	local out = {}
	for _, f in ipairs(BT.AllFlags()) do
		if p.flags and p.flags[f.key] then
			out[#out + 1] = f
		end
	end
	return out
end

-- TAGS AS ROWS, NOT PILLS (Josh 2026-09-19). They were drawn as pills laid
-- over blank lines reserved in the tooltip - the same shape they wear on a
-- card. Everywhere else in the toolkit a tag is now a square of its colour
-- with its name beside it: the note panel, the dock. The tooltip was the last
-- place still rounding them off.
--
-- The tags on one line at the foot of the tooltip. The squares are laid over
-- the gap the line starts with - Core/Tooltip.lua owns that - and the text is
-- plain ink, because a colour picked for a swatch is a poor colour for words.
local TAG_SIZE = 11

local function hidePills()
	BT.UnitTip.HideSwatches()
	T.HideNote()
end

-- nothing lays swatches over tooltip lines any more - the tags live on the
-- card - but the pool is still emptied on the way out, in case a tooltip from
-- an older session is still carrying some (Josh 2026-09-19)

-- THE NOTE FLOATS (Josh 2026-09-19). It was four lines inside the tooltip -
-- a spacer, the quote, who said it, another spacer - which is a third of the
-- height of everything else put together, for a thing that is not a fact about
-- the unit at all. It is a thing YOU wrote, about them.
--
-- So it sits above the tooltip instead, as its own card: the same surface the
-- panels wear, the same quotation, and a shadow under it so it reads against
-- whatever is behind it. The tooltip goes back to being what the client knows;
-- this is what you know.
-- NOTE_GAP is zero: the card sits ON the tooltip, sharing its top edge, so
-- the two read as one object rather than as a label that happens to be
-- floating nearby (Josh 2026-09-19).
local NOTE_GAP, SHADOW = 0, 4
-- a breath between the words and whatever they are sitting on
local QUOTE_GAP = 5

-- AN INSCRIPTION, NOT A CAPTION (Josh 2026-09-20). The quote is the whole
-- reason the tooltip is worth looking at, and at tooltip size it read as one
-- more line of interface. Set a size above everything around it, with the
-- credit left small underneath, it reads the way a quotation does - the words
-- first, the source after.
local QUOTE_SIZE = 15

-- the haze behind the quote: how far it reaches past the words (up and down),
-- how long its ends fade, and how dark its middle is
local SCRIM = {
	{ pad = 7, fade = 26, alpha = 0.22 },
	{ pad = 2, fade = 12, alpha = 0.30 },
}

local note

local function buildNote()
	if note then
		return note
	end
	-- PARENTED TO THE TOOLTIP, NOT TO THE SCREEN (Josh 2026-09-19). The client
	-- fades a tooltip out rather than snapping it off, and a card sitting on
	-- UIParent had no part in that: the tooltip dissolved and the note stayed
	-- solid above it for as long as the fade lasted. A child inherits its
	-- parent's alpha, so it fades with it for free - and it goes when the
	-- tooltip goes, without anything having to notice.
	--
	-- The parent is set again on every show: the card belongs to whichever
	-- tooltip it is sitting on.
	note = CreateFrame("Frame", "BeebModNote", UIParent)
	note:SetFrameStrata("TOOLTIP")
	note:Hide()

	-- A SHADOW, NOT A BORDER (Josh 2026-09-19). There is no blur in this
	-- client, so it is built the way a drop shadow was built before there was
	-- one: three rectangles, each a pixel further out and a little fainter.
	-- Close enough at this size, and it costs three textures.
	note.shadow = {}
	for i = 1, SHADOW do
		local t = note:CreateTexture(nil, "BACKGROUND", nil, -i)
		t:SetPoint("TOPLEFT", -i, i)
		t:SetPoint("BOTTOMRIGHT", i, -i - 1)
		t:SetColorTexture(0, 0, 0, 0.16 - (i - 1) * 0.035)
		note.shadow[i] = t
	end

	-- no rim: a border around a strip this thin is most of the strip
	note.fill = note:CreateTexture(nil, "BACKGROUND")
	note.fill:SetAllPoints()
	note.fill:SetColorTexture(BT.Widgets.FILL[1], BT.Widgets.FILL[2],
		BT.Widgets.FILL[3], BT.Widgets.FILL[4])

	-- THE QUOTE HAS NO PANEL (Josh 2026-09-19). A surface behind it made it
	-- another box in a stack of boxes; it is somebody's words, and words on
	-- the world read as words rather than as another piece of interface. Its
	-- own frame, no fill and no rim, sitting above whatever is below it -
	-- carried entirely by the shadow on the letters, which is what makes light
	-- text legible over snow or stone.
	note.quote = CreateFrame("Frame", nil, note)
	note.quote:SetFrameStrata("TOOLTIP")

	note.text = note.quote:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	note.text:SetPoint("TOPLEFT", 0, 0)
	note.text:SetPoint("TOPRIGHT", 0, 0)
	note.text:SetJustifyH("CENTER")
	note.text:SetWordWrap(true)
	note.text:SetTextColor(0.94, 0.92, 0.84)
	note.text:SetShadowColor(0, 0, 0, 1)
	note.text:SetShadowOffset(1, -1)
	do
		local face, _, flags = note.text:GetFont()
		if face then
			pcall(note.text.SetFont, note.text, face, QUOTE_SIZE, flags)
		end
	end


	note.credit = note.quote:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	note.credit:SetPoint("TOPRIGHT", note.text, "BOTTOMRIGHT", 0, -2)
	note.credit:SetJustifyH("RIGHT")
	note.credit:SetTextColor(0.62, 0.66, 0.64)
	note.credit:SetShadowColor(0, 0, 0, 1)
	note.credit:SetShadowOffset(1, -1)

	-- A SCRIM, NOT A PANEL (Josh 2026-09-22). The letter shadow carries the
	-- quote over snow or stone, but over the panel - light text, a busy list
	-- of quests in the same light text - it had nothing to stand on. So a
	-- soft dark haze sits behind the words: two layers, each solid in the
	-- middle and fading out at both ends, the outer one wider and fainter.
	-- Over the open world it is barely there; over the panel it is what
	-- makes the words read as words and not as another line of the list.
	note.scrim = {}
	for i, layer in ipairs(SCRIM) do
		local mid = note.quote:CreateTexture(nil, "BACKGROUND", nil, i)
		mid:SetColorTexture(0, 0, 0, layer.alpha)
		local left = BT.Widgets.Fade(note.quote:CreateTexture(nil, "BACKGROUND", nil, i), 0, layer.alpha)
		local right = BT.Widgets.Fade(note.quote:CreateTexture(nil, "BACKGROUND", nil, i), layer.alpha, 0)
		left:SetPoint("TOPRIGHT", mid, "TOPLEFT")
		left:SetPoint("BOTTOMRIGHT", mid, "BOTTOMLEFT")
		left:SetWidth(layer.fade)
		right:SetPoint("TOPLEFT", mid, "TOPRIGHT")
		right:SetPoint("BOTTOMLEFT", mid, "BOTTOMRIGHT")
		right:SetWidth(layer.fade)
		note.scrim[i] = { mid = mid, pad = layer.pad, fade = layer.fade }
	end
	-- the tags belong up here with the note: they are the other half of what
	-- YOU know about somebody, and down in the tooltip they were mixed in with
	-- what the client knows (Josh 2026-09-19)
	note.tags = {}
	return note
end


function T.HideNote()
	if note then
		note:Hide()
		note.quote:Hide()
		note.forTip, note.forPlayer = nil, nil
	end
end

-- MEASURED AGAIN ONCE THE TOOLTIP HAS ITS WIDTH (Josh 2026-09-23, audit). The
-- card is drawn while the tooltip is still being written: the lines after it
-- (a former guild, the tags) and the client's own layout can widen it
-- afterwards, and the quote kept wrapping to the narrower width it was
-- measured against. A tooltip that changes size redraws the card on it.
local following = setmetatable({}, { __mode = "k" })
local function followWidth(tip)
	if following[tip] or not tip.HookScript then
		return
	end
	following[tip] = true
	tip:HookScript("OnSizeChanged", function(self, w)
		local n = note
		if not (n and n.forTip == self and n.forPlayer and n:IsShown()) then
			return
		end
		local width = math.max(200, BT.Pill.Number(w, 0))
		if math.abs(width - (n.measured or 0)) >= 1 then
			T.ShowNote(self, n.forPlayer)
		end
	end)
end

-- Draws the card above `tip`, or hides it when there is nothing to say.
function T.ShowNote(tip, p)
	if not (tip and p and p.note) then
		T.HideNote()
		return nil
	end
	local n = buildNote()
	n.forTip, n.forPlayer = tip, p
	followWidth(tip)
	-- AS WIDE AS WHAT IT SITS ON (Josh 2026-09-20). Half as wide again was an
	-- attempt to stop a long note wrapping, and it sent the quote off the edge
	-- of the screen on a tooltip that was already near it. The tooltip anchors
	-- itself somewhere it fits; anything wider than the tooltip does not.
	-- the same floor the tooltip itself keeps, so the card and the tooltip
	-- under it are the same width as each other whatever was said
	local width = math.max(200, BT.Pill.Number(tip.GetWidth and tip:GetWidth(), 220))
	n.measured = width
	n:SetWidth(width)
	-- the quote's width BEFORE the text is measured: the text wraps to the
	-- quote, and measuring it against the previous tooltip's width gave a
	-- two-line note a one-line card
	n.quote:SetWidth(width)
	n.text:SetText(p.note and ('"%s"'):format(p.note) or "")
	n.text:SetShown(p.note ~= nil)
	local credit = p.note and U.Credit(p) or nil
	n.credit:SetText(credit or "")
	n.credit:SetShown(credit ~= nil)

	-- as tall as what it holds, measured rather than assumed
	local textH = p.note
		and BT.Pill.Number(n.text.GetStringHeight and n.text:GetStringHeight(), 14)
		or 0
	local creditH = credit
		and (BT.Pill.Number(n.credit.GetStringHeight and n.credit:GetStringHeight(), 10) + 2)
		or 0

	-- THE TAGS WENT BACK INSIDE (Josh 2026-09-20). They sat on a strip of
	-- their own between the quote and the tooltip, which made three stacked
	-- objects out of one unit. A tag is a fact about somebody, so it belongs
	-- with the other facts; the quote is the only thing here that is yours,
	-- and it is the only thing left floating.
	if n:GetParent() ~= tip then
		n:SetParent(tip)
		n:SetFrameStrata("TOOLTIP")
	end
	local level = BT.Pill.Number(tip.GetFrameLevel and tip:GetFrameLevel(), 10) + 5
	-- the frame that used to be the tag strip is now only a carrier for the
	-- quote: nothing is drawn on it at all
	n:SetHeight(1)
	n:SetWidth(1)
	n:ClearAllPoints()
	n:SetPoint("BOTTOM", tip, "TOP", 0, NOTE_GAP)
	n:SetFrameLevel(level)
	-- NOTHING AT ALL MEANS THE SHADOW TOO (Josh 2026-09-21). The fill was put
	-- away when the tags moved back inside, but the three rectangles that
	-- stood in for a drop shadow were not - and a shadow drawn around a
	-- one-pixel carrier is three overlapping grey bars sitting above the
	-- tooltip with nothing to cast them.
	n.fill:Hide()
	for _, t in ipairs(n.shadow or {}) do
		t:Hide()
	end
	n:Show()

	-- the quote rides on whatever is under it: the tag panel when there is
	-- one, the tooltip itself when there is not
	local q = n.quote
	q:SetWidth(width)
	q:SetHeight(math.max(1, textH + creditH))
	q:ClearAllPoints()
	q:SetPoint("BOTTOM", tip, "TOP", 0, QUOTE_GAP)
	q:SetFrameLevel(level + 1)
	-- the haze is as wide as the longest line, not the card: a short quote
	-- gets a short one
	local inkW = math.max(BT.Pill.Number(n.text.GetStringWidth and n.text:GetStringWidth(), width),
		BT.Pill.Number(n.credit.GetStringWidth and n.credit:GetStringWidth(), 0))
	inkW = math.min(width, inkW)
	for _, layer in ipairs(n.scrim or {}) do
		layer.mid:ClearAllPoints()
		layer.mid:SetPoint("CENTER", q, "CENTER", 0, 0)
		layer.mid:SetSize(math.max(1, inkW - layer.fade + 8), math.max(1, textH + creditH + layer.pad * 2))
	end
	q:Show()

	return n
end

-- the tests want at it without going through a tooltip
function T.NoteFrame()
	return note
end

-- the words themselves, which have no panel of their own
function T.QuoteFrame()
	return note and note.quote
end
T.HidePills = hidePills

-- Adds at most four lines, and only lines that say something: silence is the
-- correct output for a stranger you have never written on.
function T.Fill(tip, unit)
	local db = BT.db
	if not (db and BT.settings and BT.settings.tooltip and tip and unit and UnitIsPlayer(unit)) then
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
	local name, realm = BT.Collect.UnitFullName(unit)
	local key = name and U.Key(name, realm)
	local p = key and DB.Get(db, key)
	if not p then
		hidePills()
		return
	end
	local flags = flagsOn(p)
	-- A THIN LINE, NOT A BLANK ONE (Josh 2026-09-19). The note wanted air above
	-- and below it. A blank tooltip line is ten pixels, which is a gap rather
	-- than a breath - so the spacer is a line sized down to four.
	local function spacer(px)
		tip:AddLine(" ")
		if tip.NumLines then
			BT.UnitTip.SizeLine(tip, tip:NumLines(), px or 4)
		end
	end
	if p.rating then
		tip:AddLine(("Rated %d/5"):format(p.rating), 1, 0.82, 0.25)
	end
	-- the note AND the tags are a card above the tooltip now. They are the two
	-- things on there that you wrote rather than the client; keeping them
	-- together and out of the tooltip leaves the tooltip saying only what the
	-- game knows (Josh 2026-09-19).
	T.ShowNote(tip, p)
	if BT.settings.tooltipGuild then
		local former, when = DB.FormerGuild(p)
		if former then
			tip:AddLine(("Was in %s, %s"):format(former, U.Since(when)), 0.6, 0.65, 0.7)
		end
	end
	-- ONE ROW, NOT TWO COLUMNS (Josh 2026-09-20). Two tags to a line put the
	-- second one at the far right of the tooltip, so three tags read as a
	-- little table with a hole in it. Packed along a single line with an even
	-- gap between them they read as what they are: a row of marks.
	--
	-- A tooltip line cannot measure a substring of itself, so the words before
	-- each swatch are measured off-screen and the squares are laid at those
	-- offsets - see Core/Tooltip.lua's ruler.
	if #flags > 0 then
		local LEAD, GAP = "    ", "   "
		local text, offsets, colours = "", {}, {}
		for i, f in ipairs(flags) do
			offsets[i] = BT.UnitTip.Measure(text, TAG_SIZE) + 1
			colours[i] = f.color or { 0.6, 0.65, 0.62 }
			text = text .. LEAD .. f.label
			if i < #flags then
				text = text .. GAP
			end
		end
		tip:AddLine(text, 0.87, 0.92, 0.89)
		local line = BT.Pill.Number(tip.NumLines and tip:NumLines(), 0)
		BT.UnitTip.SizeLine(tip, line, TAG_SIZE)
		BT.UnitTip.SwatchesOnLine(tip, colours, line, offsets)
	else
		BT.UnitTip.HideSwatches()
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

-- the pills belong to whatever the tooltip is showing NOW, so they go away
-- with it rather than hanging over the next thing you point at
BT.OnUnitTooltipHide(hidePills)

-- kept so the rest of the Ledger can say "redraw that" without knowing who
-- else has a say in it
T.Restack = function()
	return BT.UnitTip.Restack()
end
