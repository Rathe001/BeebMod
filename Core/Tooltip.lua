-- ONE HOOK ON THE UNIT TOOLTIP, SEVERAL PARTICIPANTS (Josh 2026-09-19).
--
-- Two modules want a say in what a unit tooltip looks like: Tooltips rebuilds
-- it compactly, and the Ledger adds your note and your tags. Left to
-- themselves they would each hook it, in whatever order the files happened to
-- load, and the one that rebuilds would wipe the one that decorates.
--
-- So the core hooks it once and hands it round in a known order: whoever
-- composes the base lines first, whoever decorates after. A contributor
-- belonging to a switched-off module is skipped, which is how turning either
-- of them off leaves the other working exactly as before.
--
-- Two APIs, because this client line carries the modern tooltip system but a
-- beta build is allowed to move: when TooltipDataProcessor is there we use it,
-- otherwise the old OnTooltipSetUnit hook still works.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Tooltip.lua")

local T = {}
BT.UnitTip = T

local parts, items, hiders = {}, {}, {}

-- `order` is the running order: compose low, decorate high.
function BT.OnUnitTooltip(moduleKey, order, fn)
	parts[#parts + 1] = { module = moduleKey, order = order or 50, fn = fn }
	table.sort(parts, function(a, b) return a.order < b.order end)
end

-- The same again for ITEM tooltips. They are a different data type to the
-- client and a different shape to us, but the rule about who goes first is
-- the same: the Tooltips module writes an item again as a card (order 0),
-- and whoever comes after adds to that card.
function BT.OnItemTooltip(moduleKey, order, fn)
	items[#items + 1] = { module = moduleKey, order = order or 50, fn = fn }
	table.sort(items, function(a, b) return a.order < b.order end)
end

-- a spell's or a buff's: `fn(tip, data, kind)`, kind "spell" or "aura"
local spells = {}
function BT.OnSpellTooltip(moduleKey, order, fn)
	spells[#spells + 1] = { module = moduleKey, order = order or 50, fn = fn }
	table.sort(spells, function(a, b) return a.order < b.order end)
end

-- Called when the tooltip goes away, for anything drawn OVER it rather than
-- in it: those frames belong to whatever the tooltip was showing, and have to
-- leave with it rather than hang over the next thing you point at.
function BT.OnUnitTooltipHide(fn)
	hiders[#hiders + 1] = fn
end

-- THE LINES ARE SHARED (Josh 2026-09-19). GameTooltipTextLeft3 is the same
-- FontString whether it is holding a race, a note, or the third line of an
-- item tooltip five seconds later. Any contributor may size the line it just
-- wrote - that is how the tooltip gets a hierarchy at all - but every one of
-- them is put back the moment the tooltip goes away.
function T.LineOf(tip, i, side)
	local name = tip and tip.GetName and tip:GetName()
	if not name then
		return nil
	end
	return _G[name .. (side or "TextLeft") .. i]
end

-- WHAT THE LINE LOOKED LIKE BEFORE WE TOUCHED IT (Josh 2026-09-19). Putting a
-- line back used to mean handing it GameTooltipText and hoping that global
-- exists on this client - and when it does not, nothing is restored and the
-- next tooltip inherits our sizes. With the Tooltips module switched off that
-- showed as the client's own tooltip drawing "Priest" in nine-point type.
--
-- So each line's real font and alignment are written down the first time we
-- change them, and handed straight back when the tooltip goes away. Weak keys:
-- a FontString the client throws away takes its entry with it.
local before = setmetatable({}, { __mode = "k" })

-- `tip` is whose line it is: each tooltip's lines go back when that tooltip
-- goes, and not when another one beside it does (a comparison tooltip is up
-- while the item tooltip it sits beside is written again)
local function remember(fs, tip)
	if before[fs] ~= nil then
		return
	end
	local face, size, flags = fs:GetFont()
	-- AND THE FONT OBJECT IT FOLLOWS (2026-10-17, audit): a line given its
	-- face back with SetFont stops following GameTooltipText, so an addon
	-- that changes that font no longer reached the lines we had touched
	local object = nil
	if fs.GetFontObject then
		local ok, o = pcall(fs.GetFontObject, fs)
		object = ok and o or nil
	end
	local was = {
		face = face, size = size, flags = flags, object = object,
		justify = fs.GetJustifyH and fs:GetJustifyH() or nil,
		-- how many lines it may wrap to (T.MaxLines)
		maxLines = fs.GetMaxLines and fs:GetMaxLines() or nil,
		owner = tip,
	}
	-- the shadow too, so a line we gave one to gives it back
	if fs.GetShadowColor then
		local ok, r, g, b, a = pcall(fs.GetShadowColor, fs)
		if ok and r then
			was.shadow = { r, g, b, a }
		end
	end
	if fs.GetShadowOffset then
		local ok, x, y = pcall(fs.GetShadowOffset, fs)
		if ok and x then
			was.shadowAt = { x, y }
		end
	end
	-- and where it sits, for anything that nudges a line sideways
	if fs.GetPoint then
		local ok, point, rel, relPoint, x, y = pcall(fs.GetPoint, fs, 1)
		if ok and point then
			was.at = { point, rel, relPoint, x or 0, y or 0 }
		end
	end
	before[fs] = was
end

-- A BIGGER FONT STARTS FURTHER IN (Josh 2026-09-21). The name is set at
-- fourteen point and the lines under it at twelve, and a glyph's left side
-- bearing grows with its size - so with both anchored to the same inset, the
-- ink of the header sits a couple of pixels right of the ink below it. There
-- is no padding that fixes this: padding moves the anchor, and the anchor is
-- already the same. The body is nudged to meet the header instead.
-- `dy` moves it down (negative) or up as well, and every line under it with
-- it: each is hung off the one above
function T.Indent(tip, i, dx, side, dy)
	local fs = T.LineOf(tip, i, side)
	if not (fs and fs.SetPoint and fs.ClearAllPoints) then
		return nil
	end
	remember(fs, tip)
	local was = before[fs]
	if not (was and was.at) then
		return fs
	end
	local at = was.at
	pcall(fs.ClearAllPoints, fs)
	if at[2] then
		pcall(fs.SetPoint, fs, at[1], at[2], at[3], at[4] + dx, at[5] + (dy or 0))
	else
		pcall(fs.SetPoint, fs, at[1], at[4] + dx, at[5] + (dy or 0))
	end
	return fs
end

-- `role` ("name" or "text") names the face outright; without it, the first
-- line on the left is the name and the rest are text
function T.SizeLine(tip, i, size, side, role)
	local fs = T.LineOf(tip, i, side)
	if not (fs and fs.GetFont and fs.SetFont) then
		return nil
	end
	remember(fs, tip)
	local face, _, flags = fs:GetFont()
	-- THE TOOLKIT'S FACE WHILE IT IS OURS (Josh 2026-09-23): the first line
	-- is the name, in the heavier weight; remember() has the game's face, and
	-- it goes back when the tooltip does. Sizes are the game's, moved by the
	-- face in use (Core/Fonts.lua).
	role = role or ((i == 1 and side ~= "TextRight") and "name" or "text")
	-- a note is somebody's words, in the italic the Expedition's lore is set in
	if role == "quote" then
		face = T.QUOTE_FACE
	elseif role == "number" then
		-- a figure, in the numbers' face the dock and the tiles use
		face = (BT.Tip and BT.Tip.NUMBER) or (BT.Fonts and BT.Fonts.Face("text")) or face
	else
		face = (BT.Fonts and BT.Fonts.Face(role)) or face
	end
	size = BT.Fonts and BT.Fonts.Size(size) or size
	if face then
		pcall(fs.SetFont, fs, face, size, flags)
	end
	return fs
end

-- A TITLE ON A COLOURED BAND NEEDS ITS OWN EDGE (Josh 2026-09-21). The name
-- sits on a wash of the unit's class colour and an item's on its quality
-- spine, so the one thing a tooltip title can never count on is a dark
-- background - a rogue's yellow name on a yellow band is the worst case, and
-- there is no text colour that fixes it. A shadow does: it is drawn from the
-- letter's own shape, so it works whatever is behind it.
function T.Shadow(tip, i, side)
	local fs = T.LineOf(tip, i, side)
	if not (fs and fs.SetShadowColor) then
		return nil
	end
	remember(fs, tip)
	pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.85)
	if fs.SetShadowOffset then
		pcall(fs.SetShadowOffset, fs, 1, -1)
	end
	return fs
end

-- Where a line sits across the tooltip. The note reads as a quotation -
-- centred - and its source sits under the right-hand end of it, the way a
-- source does.
function T.Justify(tip, i, how, side)
	local fs = T.LineOf(tip, i, side)
	if fs and fs.SetJustifyH then
		remember(fs, tip)
		pcall(fs.SetJustifyH, fs, how or "LEFT")
	end
	return fs
end

function T.Center(tip, i, side)
	return T.Justify(tip, i, "CENTER", side)
end

-- how many lines a wrapped line may take before it ends in "..."
function T.MaxLines(tip, i, n, side)
	local fs = T.LineOf(tip, i, side)
	if fs and fs.SetMaxLines then
		remember(fs, tip)
		pcall(fs.SetMaxLines, fs, n)
	end
	return fs
end

-- A line put back on the font object it followed, so it follows it again;
-- false where it would not take it. The object's own face is set after it
-- where the line still wears ours, in case handing a line the object it
-- already has changes nothing.
local function putObject(fs, object)
	if not pcall(fs.SetFontObject, fs, object) then
		return false
	end
	if object.GetFont then
		local ok, face, size, flags = pcall(object.GetFont, object)
		local nowFace, nowSize = fs:GetFont()
		if ok and face and size and (nowFace ~= face or nowSize ~= size) then
			pcall(fs.SetFont, fs, face, size, flags)
		end
	end
	return true
end

-- Every line we touched, back the way it was. Not "the way we assume tooltip
-- lines look": the way THAT line actually was, measured before we changed it.
-- `tip`: only that tooltip's lines; nothing: every tooltip's
function T.RestoreFonts(tip)
	for fs, was in pairs(before) do
		if not tip or was.owner == tip then
			if not (was.object and fs.SetFontObject and putObject(fs, was.object)) and was.face and was.size
				and fs.SetFont then
				pcall(fs.SetFont, fs, was.face, was.size, was.flags)
			end
			if was.justify and fs.SetJustifyH then
				pcall(fs.SetJustifyH, fs, was.justify)
			end
			if was.maxLines and fs.SetMaxLines then
				pcall(fs.SetMaxLines, fs, was.maxLines)
			end
			if was.shadow and fs.SetShadowColor then
				pcall(fs.SetShadowColor, fs, was.shadow[1], was.shadow[2],
					was.shadow[3], was.shadow[4])
			end
			if was.shadowAt and fs.SetShadowOffset then
				pcall(fs.SetShadowOffset, fs, was.shadowAt[1], was.shadowAt[2])
			end
			if was.at and fs.SetPoint and fs.ClearAllPoints then
				pcall(fs.ClearAllPoints, fs)
				if was.at[2] then
					pcall(fs.SetPoint, fs, was.at[1], was.at[2], was.at[3],
						was.at[4], was.at[5])
				else
					pcall(fs.SetPoint, fs, was.at[1], was.at[4], was.at[5])
				end
			end
			before[fs] = nil
		end
	end
end

-- how many lines are still wearing something of ours, for the tests
function T.Touched()
	local n = 0
	for _ in pairs(before) do
		n = n + 1
	end
	return n
end

-- SQUARES DOWN THE LEFT OF THE LINES (Josh 2026-09-19). A tooltip is text and
-- nothing else, so a tag's colour can only be the colour of its name - and the
-- colours were chosen to sit inside a pill, not to be read as words. The
-- squares are frames laid over the tooltip, in the gap left by the spaces each
-- line starts with, which is the same trick the note's tags use. A pool for
-- each side ("TextLeft" or "TextRight"), so a tooltip can carry two columns.
local swatches, holder = { TextLeft = {}, TextRight = {} }, nil

-- A RULER (Josh 2026-09-20). To put several swatches along ONE line we have
-- to know how wide the words before each of them are, and a tooltip line will
-- not measure a substring of itself. This one is off-screen and measures
-- anything at any size.
local ruler
-- `role`: the face it will be drawn in ("text" unless said)
function T.Measure(text, size, role)
	if not ruler then
		ruler = UIParent:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		ruler:Hide()
	end
	local face, _, flags = ruler:GetFont()
	-- measured in the face it will be drawn in
	face = (BT.Fonts and BT.Fonts.Face(role or "text")) or face
	size = BT.Fonts and BT.Fonts.Size(size) or size
	if face and size then
		pcall(ruler.SetFont, ruler, face, size, flags)
	end
	ruler:SetText(text or "")
	return BT.Pill.Number(ruler.GetStringWidth and ruler:GetStringWidth(),
		#(text or "") * ((size or 10) * 0.5))
end

-- Several swatches along one line, each at its own offset from the line's
-- start. `offsets` and `colours` run together.
function T.SwatchesOnLine(tip, colours, line, offsets, side)
	if not (tip and tip.CreateTexture and colours) then
		return 0
	end
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		-- ours, not a tooltip's tab (Tooltips.lua, restyleTab)
		holder.beebs = true
		holder:SetFrameStrata("TOOLTIP")
	end
	holder:SetParent(tip)
	holder:ClearAllPoints()
	holder:SetAllPoints(tip)
	holder:Show()
	local pool = swatches[side or "TextLeft"]
	local fs = T.LineOf(tip, line, side)
	local drawn = 0
	for i, colour in ipairs(colours) do
		local sw = pool[i]
		if not sw then
			sw = holder:CreateTexture(nil, "OVERLAY")
			sw:SetSize(7, 7)
			pool[i] = sw
		end
		if fs and colour then
			sw:SetColorTexture(colour[1], colour[2], colour[3], 1)
			sw:ClearAllPoints()
			sw:SetPoint("LEFT", fs, "LEFT", offsets[i] or 0, 0)
			sw:Show()
			drawn = drawn + 1
		else
			sw:Hide()
		end
	end
	for i = drawn + 1, #pool do
		pool[i]:Hide()
	end
	return drawn
end

-- the tests look at where the squares landed
function T.SwatchPool(side)
	return swatches[side or "TextLeft"]
end

function T.HideSwatches()
	for _, pool in pairs(swatches) do
		for _, sw in ipairs(pool) do
			sw:Hide()
		end
	end
	if holder then
		holder:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- THE BODY: TAGS AND ROWS (Josh 2026-10-17, the tooltip canvas "C, everything
-- as tags": "let's proceed with the important tag colors")
-- ---------------------------------------------------------------------------
--
-- Under the name, what a unit is and what state it is in, as small tags: a
-- word in capitals on a box of colour. Most are grey. Only the ones that
-- change what you do next have a colour of their own (T.TAG). Under the tags
-- is one row for each thing worth knowing, such as an objective, your kills
-- of it or your note, led by a small picture in its owner's colour.
--
-- A tooltip line is one run of text in one size, so a tag cannot be part of
-- one. The tags are boxes and words of our own, laid over a line the tooltip
-- keeps for them, the way the Ledger's tag squares are laid over theirs. A
-- row's picture is a texture inside its line's text.

-- a note is set in the italic the Expedition's lore is (Expedition/Card.lua)
T.QUOTE_FACE = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\Alegreya-Italic.ttf"
T.INK = { 0.91, 0.93, 0.92 }

-- the rows' pictures, one sheet of eight (scripts/make-tip-icons.py)
T.ICONS = "Interface\\AddOns\\BeebMod\\Art\\tipicons"
T.ICON = { quest = 0, kills = 1, note = 2, tags = 3, grouped = 4, rating = 5, duels = 6, guild = 7 }
T.ICON_SIZE = 11
-- a row's words, and the breath before the first row
T.ROW, T.GAP = 10.5, 4

-- a picture inside a line's text, tinted `colour`; "blank" is the room one
-- takes with nothing in it (a corner of the sheet with no ink)
function T.Icon(name, colour)
	if name == "blank" then
		return ("|T%s:%d:%d:0:0:256:32:0:1:0:1|t"):format(T.ICONS, T.ICON_SIZE, T.ICON_SIZE)
	end
	local slot = T.ICON[name]
	if not slot then
		return ""
	end
	local c = colour or T.INK
	local function byte(v)
		return math.floor((v or 1) * 255 + 0.5)
	end
	return ("|T%s:%d:%d:0:0:256:32:%d:%d:0:32:%d:%d:%d|t"):format(T.ICONS, T.ICON_SIZE, T.ICON_SIZE,
		slot * 32, slot * 32 + 32, byte(c[1]), byte(c[2]), byte(c[3]))
end

-- THE BODY'S BREATH: one blank line a few points tall, before the first row
-- of a tooltip (T.Row), whoever adds it, and only before that one
function T.Gap(tip)
	if T.gapped == tip then
		return
	end
	T.gapped = tip
	tip:AddLine(" ")
	T.SizeLine(tip, BT.Pill.Number(tip:NumLines(), 1), T.GAP)
end

-- One row: its picture in `tint`, its words in `rgb`, and what it says on the
-- right in `rightRgb`; `wrap` lets long words take more than one line.
-- Returns the line it went on.
function T.Row(tip, icon, tint, text, rgb, right, rightRgb, wrap)
	T.Gap(tip)
	rgb = rgb or T.INK
	local left = T.Icon(icon, tint) .. "  " .. (text or "")
	if right then
		rightRgb = rightRgb or rgb
		tip:AddDoubleLine(left, right, rgb[1], rgb[2], rgb[3], rightRgb[1], rightRgb[2], rightRgb[3])
	else
		tip:AddLine(left, rgb[1], rgb[2], rgb[3], wrap and true or nil)
	end
	local i = BT.Pill.Number(tip:NumLines(), 1)
	T.SizeLine(tip, i, T.ROW, nil, "text")
	if right then
		T.SizeLine(tip, i, T.ROW, "TextRight", "text")
	end
	-- in line with the tags and the name's ink, on a tooltip the Tooltips
	-- module wrote (its indentBody); on the client's own, with its lines
	if BT.Enabled and BT.Enabled("tooltips") then
		T.Indent(tip, i, T.BODY_INDENT)
		if right then
			T.Indent(tip, i, -T.BODY_INDENT, "TextRight")
		end
	end
	return i
end
T.BODY_INDENT = 2

-- the tags' words, how far a box reaches past them, how tall it is, the gap
-- between two, and the size of the blank line a row of them sits on
-- (TIGHTER, Josh 2026-10-17: "reduce the padding and margin on the tags a
-- bit and push them a bit tighter against the title". Smaller words went
-- too far: "The tags are also so small they don't really read as tags
-- anymore", so the words and the box are back to their size, with the
-- tighter padding kept.)
T.TAG_SIZE, T.TAG_PAD, T.TAG_H, T.TAG_GAP, T.TAG_LINE = 8.5, 3, 12, 3, 10
-- the line a row of tags sits on is a no-break space: blank to the eye, and
-- not a blank line the tooltip's tail squeezes away (Tooltips.lua)
T.TAG_BLANK = "\194\160"

-- THE COLOURS THAT MEAN SOMETHING (Josh 2026-10-17: "let's proceed with the
-- important tag colors"). Grey for what a unit is; a colour only where it
-- changes what you do next. Each tag also says it in words, for anyone who
-- can't tell the colours apart.
T.TAG = {
	plain = { fg = { 0.74, 0.79, 0.77 }, bg = { 0.78, 0.84, 0.82, 0.15 } },
	quiet = { fg = { 0.56, 0.61, 0.58 }, bg = { 0.49, 0.55, 0.53, 0.18 } },
	pvp = { fg = { 0.92, 0.52, 0.50 }, bg = { 0.90, 0.38, 0.35, 0.16 } },
	skin = { fg = { 0.84, 0.70, 0.47 }, bg = { 0.84, 0.70, 0.47, 0.16 } },
	elite = { fg = { 0.89, 0.75, 0.38 }, bg = { 0.85, 0.70, 0.25, 0.18 } },
	rare = { fg = { 0.80, 0.84, 0.88 }, bg = { 0.78, 0.82, 0.86, 0.16 } },
	-- AN ITEM'S BINDING, OUTLINED (Josh 2026-10-17: Soulbound "should probably
	-- look different than the tags under it"): a state of your copy, drawn as
	-- an edge where what the item is has a fill
	bound = { fg = { 0.64, 0.69, 0.67 }, edge = { 0.47, 0.53, 0.51, 0.9 } },
}
-- AN ITEM YOU CANNOT USE (Josh 2026-10-23: "we are not showing the tag for
-- items the player cannot use"), in the red the client warns with
T.TAG.warn = T.TAG.pvp

-- `tags` = { { words, kind } }, in rows no wider than `width`
function T.TagRows(tags, width)
	local rows, row, used = {}, nil, 0
	for _, tag in ipairs(tags or {}) do
		local w = T.TagWidth(tag[1], tag.keepCase)
		if row and used + T.TAG_GAP + w > width then
			row = nil
		end
		if not row then
			row, used = {}, -T.TAG_GAP
			rows[#rows + 1] = row
		end
		row[#row + 1] = tag
		used = used + T.TAG_GAP + w
	end
	return rows
end

-- THEIR OWN CARRIER, ONE FOR EACH TOOLTIP: putting the Ledger's squares away
-- leaves them be, and the tags of a comparison tooltip stay where they are
-- while the item tooltip beside it is written again (Josh 2026-10-17: "Make
-- sure we use this for the "equipped" compairson tooltip as well")
local tagSets = setmetatable({}, { __mode = "k" })

local function tagSet(tip)
	local set = tagSets[tip]
	if not set then
		set = { pool = {}, used = 0 }
		set.holder = CreateFrame("Frame", nil, tip)
		-- ours, not a tooltip's tab: the comparison tooltip's tab is looked for
		-- among its children, and a frame with words and art on it was taken
		-- for it (Tooltips.lua, restyleTab)
		set.holder.beebs = true
		set.holder:SetFrameStrata("TOOLTIP")
		set.holder:SetAllPoints(tip)
		tagSets[tip] = set
	end
	return set
end

local function tagFrame(set, i)
	local t = set.pool[i]
	if t then
		return t
	end
	local holder = set.holder
	t = {}
	t.bg = holder:CreateTexture(nil, "ARTWORK")
	t.text = holder:CreateFontString(nil, "OVERLAY")
	if BT.Fonts and BT.Fonts.Set then
		BT.Fonts.Set(t.text, "name", T.TAG_SIZE)
	elseif _G.GameFontHighlightSmall then
		pcall(t.text.SetFontObject, t.text, _G.GameFontHighlightSmall)
	end
	t.text:SetPoint("CENTER", t.bg, "CENTER", 0, 0)
	-- the four sides of an outlined one (T.TAG.bound)
	t.edges = {}
	for e = 1, 4 do
		t.edges[e] = holder:CreateTexture(nil, "ARTWORK")
	end
	t.edges[1]:SetPoint("TOPLEFT", t.bg, "TOPLEFT")
	t.edges[1]:SetPoint("TOPRIGHT", t.bg, "TOPRIGHT")
	t.edges[1]:SetHeight(1)
	t.edges[2]:SetPoint("BOTTOMLEFT", t.bg, "BOTTOMLEFT")
	t.edges[2]:SetPoint("BOTTOMRIGHT", t.bg, "BOTTOMRIGHT")
	t.edges[2]:SetHeight(1)
	t.edges[3]:SetPoint("TOPLEFT", t.bg, "TOPLEFT")
	t.edges[3]:SetPoint("BOTTOMLEFT", t.bg, "BOTTOMLEFT")
	t.edges[3]:SetWidth(1)
	t.edges[4]:SetPoint("TOPRIGHT", t.bg, "TOPRIGHT")
	t.edges[4]:SetPoint("BOTTOMRIGHT", t.bg, "BOTTOMRIGHT")
	t.edges[4]:SetWidth(1)
	set.pool[i] = t
	return t
end

-- a tag's words as drawn: in capitals, unless the tag keeps its own case
-- ("BoE" is how players write it; tag.keepCase)
local function tagWords(tag)
	local words = tostring(tag[1] or "")
	return tag.keepCase and words or words:upper()
end

function T.TagWidth(text, keepCase)
	return T.Measure(tagWords({ text, keepCase = keepCase }), T.TAG_SIZE, "name") + T.TAG_PAD * 2
end

-- One tag, its box's left edge `x` from the left of line `line` on `side`
-- (or from its right, with `from` "RIGHT"); `point` "TOPLEFT" hangs it from
-- the line's top rather than its middle. Returns how wide it is.
function T.PlaceTag(tip, line, x, tag, side, from, point)
	local fs = T.LineOf(tip, line, side)
	if not (fs and tip.CreateTexture) then
		return 0
	end
	local set = tagSet(tip)
	set.holder:Show()
	set.used = set.used + 1
	T.lastTagTip = tip
	local t = tagFrame(set, set.used)
	local look = T.TAG[tag[2] or "plain"] or T.TAG.plain
	local w = T.TagWidth(tag[1], tag.keepCase)
	local bg = look.bg or { 0, 0, 0, 0 }
	t.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
	t.bg:ClearAllPoints()
	if point == "TOPLEFT" then
		t.bg:SetPoint("TOPLEFT", fs, "TOPLEFT", x, 0)
	else
		t.bg:SetPoint("LEFT", fs, from or "LEFT", x, 0)
	end
	t.bg:SetSize(w, T.TAG_H)
	for _, e in ipairs(t.edges) do
		if look.edge then
			e:SetColorTexture(look.edge[1], look.edge[2], look.edge[3], look.edge[4])
			e:Show()
		else
			e:Hide()
		end
	end
	t.text:SetText(tagWords(tag))
	t.text:SetTextColor(look.fg[1], look.fg[2], look.fg[3])
	t.tag = tag
	t.bg:Show()
	t.text:Show()
	return w
end

-- a row of them along `line`, from its left (from its top-left with `point`
-- "TOPLEFT"); returns how wide
function T.TagsOnLine(tip, line, row, point)
	local x = 0
	for i, tag in ipairs(row or {}) do
		x = x + T.PlaceTag(tip, line, x, tag, nil, nil, point) + (i < #row and T.TAG_GAP or 0)
	end
	return x
end

-- `tip`'s tags put away, or every tooltip's
function T.HideTags(tip)
	for owner, set in pairs(tagSets) do
		if not tip or owner == tip then
			for _, t in ipairs(set.pool) do
				t.bg:Hide()
				t.text:Hide()
				for _, e in ipairs(t.edges) do
					e:Hide()
				end
				t.tag = nil
			end
			set.used = 0
			set.holder:Hide()
		end
	end
end

-- the tests look at what was laid where: `tip`'s, or the last tooltip's to
-- have one laid
function T.TagPool(tip)
	local set = tagSets[tip or T.lastTagTip]
	if not set then
		return {}, 0
	end
	return set.pool, set.used
end

-- ---------------------------------------------------------------------------
-- WHEN A TOOLTIP GOES
-- ---------------------------------------------------------------------------
--
-- Everything of ours on a tooltip - a line's size, its tags, an item's icon
-- and tiles - belongs to what it is showing now, and goes when it hides or
-- is cleared for something else. GameTooltip has its hooks below; the
-- comparison tooltips are watched the first time one is filled (T.Watch).
local goneFns = {}
function T.OnGone(fn)
	goneFns[#goneFns + 1] = fn
end

local function gone(tip)
	T.RestoreFonts(tip)
	T.HideTags(tip)
	for _, fn in ipairs(goneFns) do
		pcall(fn, tip)
	end
end
T.TipGone = gone

local watched = setmetatable({}, { __mode = "k" })
function T.Watch(tip)
	if not (tip and tip.HookScript) or watched[tip] or tip == GameTooltip then
		return false
	end
	watched[tip] = true
	tip:HookScript("OnHide", gone)
	tip:HookScript("OnTooltipCleared", gone)
	return true
end

BT.OnUnitTooltipHide(function()
	T.HideSwatches()
	gone(GameTooltip)
end)

local function run(list, tip, arg)
	for _, part in ipairs(list) do
		if not part.module or BT.Enabled(part.module) then
			local ok, err = pcall(part.fn, tip, arg)
			if not ok then
				BT.Err(("tooltip/%s: %s"):format(tostring(part.module), tostring(err)))
			end
		end
	end
end

-- WHICH HOOK IS ACTUALLY LIVE (Josh 2026-09-19). Two of these counters and a
-- name is the whole answer to "the tooltip options do nothing": either the
-- unit hook is firing and the item one is not, or neither is, and those are
-- different bugs. What loaded, on the Testing page, prints it.
T.path, T.fills, T.itemFills = "none", 0, 0

function T.Fill(tip, unit)
	if not (tip and unit and UnitExists and UnitExists(unit)) then
		return
	end
	T.fills = T.fills + 1
	-- kept before anybody clears it, for T.ShownUnit
	if tip == GameTooltip then
		T.unit = unit
	end
	T.filling = true
	-- each fill has its own breath before its body (T.Gap)
	T.gapped = nil
	run(parts, tip, unit)
	T.filling = false
end

-- THE ITEM TOOLTIPS WE WRITE: the one you point with, and the two that open
-- beside it to compare what you have on (Josh 2026-10-17: "Make sure we use
-- this for the "equipped" compairson tooltip as well")
-- AND THE ONE A CHAT LINK OPENS (Josh 2026-10-17: "Is there any way to look up
-- item icons so linked items also get them?"), with its own two beside it:
-- they were left as the client draws them, icon and all
function T.ItemTip(tip)
	return tip ~= nil and (tip == GameTooltip or tip == _G.ShoppingTooltip1 or tip == _G.ShoppingTooltip2
		or tip == _G.ItemRefTooltip or tip == _G.ItemRefShoppingTooltip1 or tip == _G.ItemRefShoppingTooltip2)
end

-- THE SPELL AND BUFF TOOLTIPS WE WRITE (Josh 2026-10-17: "Yes, spell and buff
-- tooltips should get the same look"): the one you point with, and a linked
-- spell's
function T.SpellTip(tip)
	return tip ~= nil and (tip == GameTooltip or tip == _G.ItemRefTooltip)
end

-- `data` is the client's own account of the tooltip, where the hook has it:
-- each line's kind, and the tooltip line it went on (Tooltips.lua, M.ItemLines)
function T.FillItem(tip, data)
	if not tip then
		return
	end
	T.itemFills = T.itemFills + 1
	run(items, tip, data)
end

-- `kind` is "spell" or "aura"
T.spellFills = 0
function T.FillSpell(tip, data, kind)
	if not tip then
		return
	end
	T.spellFills = T.spellFills + 1
	for _, part in ipairs(spells) do
		if not part.module or BT.Enabled(part.module) then
			local ok, err = pcall(part.fn, tip, data, kind)
			if not ok then
				BT.Err(("tooltip/%s: %s"):format(tostring(part.module), tostring(err)))
			end
		end
	end
end

-- A TOOLTIP IS DRAWN ONCE (Josh 2026-09-19). Tag somebody while their tooltip
-- is up and it keeps showing what it showed a second ago, which reads as the
-- addon disagreeing with itself. Asking the tooltip for the same unit again
-- rebuilds it, and everyone's lines go on during that rebuild.
function T.Restack()
	if not (GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()) then
		return false
	end
	local unit = T.ShownUnit()
	if not unit then
		return false
	end
	GameTooltip:SetUnit(unit)
	return true
end

if GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnHide", function()
		if T.Gone then
			T.Gone()
		end
		for _, fn in ipairs(hiders) do
			pcall(fn)
		end
	end)
	-- AND WHEN IT IS WRITTEN AGAIN WITHOUT HIDING (Josh 2026-09-23, audit):
	-- from a player straight to a mailbox or an item the tooltip never
	-- hides, so the player's note card, tag squares and line sizes stayed on
	-- the next tooltip. The client clears it first whatever comes next, and
	-- the unit contributors run after that and put back what the new unit
	-- needs.
	GameTooltip:HookScript("OnTooltipCleared", function()
		-- the game clearing it for whatever comes next: the unit it was for is
		-- not this one's (T.ShownUnit). Our own rebuild clears it too, and that
		-- is still the same unit.
		if not T.filling then
			T.guid, T.unit = nil, nil
		end
		for _, fn in ipairs(hiders) do
			pcall(fn)
		end
	end)
end

-- THE TWO HOOKS ARE CHOSEN SEPARATELY (Josh 2026-09-19). They used to be one
-- if/else: with the data processor present but no Item type on it, the whole
-- else branch was skipped and item tooltips got no hook at all - which reads
-- in game as "the tooltip settings do nothing", because half of them did.
local processor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	and Enum and Enum.TooltipDataType

-- THE QUEST ITEM'S LINE (Josh 2026-10-01: "it just isn't showing the line
-- '2/10 Fine Moonstalker Pelt'... The kill count quests work"). An objective
-- that names an item is written once the game knows the item's name, and
-- until then the line is missing; when the name arrives the game sends
-- TOOLTIP_DATA_UPDATE and draws the tooltip again. But the Tooltips module
-- rebuilds a unit tooltip with ClearLines, and clearing GameTooltip makes it
-- forget what it was showing, so the update found nothing to draw again and
-- the line never came. The data's id is kept here instead, and an update
-- for it asks for the unit again (T.Restack), a frame later.
local REDRAWS = 5 -- for one tooltip: an update that keeps coming is not chased
local function plainID(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then
		return nil
	end
	return v
end

-- WHO IT WAS FOR (Josh 2026-10-03: a Kobold Miner's tooltip with no "0/8
-- Large Candle"). The redraw above never happened. Clearing the tooltip makes
-- the game forget its data, and the game's TooltipUtil.GetDisplayedUnit reads
-- the unit from that data, so after the Tooltips module's rebuild there was no
-- unit to ask for, and T.Restack quietly gave up. That was every redraw of a
-- rebuilt tooltip, not only this one: a note or a tag written while the
-- tooltip was up, a tooltip setting changed, the module switched on or off.
-- So the unit is kept here as it is drawn: its GUID from the data, and the
-- token T.Fill was handed. The game's answer still comes first.
function T.ShownUnit()
	local unit
	if TooltipUtil and TooltipUtil.GetDisplayedUnit then
		local ok, _, u = pcall(TooltipUtil.GetDisplayedUnit, GameTooltip)
		unit = ok and plainID(u) or nil
	elseif GameTooltip and GameTooltip.GetUnit then
		local ok, _, u = pcall(GameTooltip.GetUnit, GameTooltip)
		unit = ok and plainID(u) or nil
	end
	if not unit and T.guid and UnitTokenFromGUID then
		local ok, u = pcall(UnitTokenFromGUID, T.guid)
		unit = ok and plainID(u) or nil
	end
	if not unit and T.unit then
		-- the token we were handed, while it is still the same one
		local guid = T.guid and UnitGUID and plainID(UnitGUID(T.unit))
		if not (guid and guid ~= T.guid) then
			unit = T.unit
		end
	end
	if not (type(unit) == "string" and UnitExists and UnitExists(unit)) then
		return nil
	end
	return unit
end

-- a unit drawn: its data's id and GUID, and a fresh count of redraws unless
-- this is one of them
function T.Drawn(data)
	local id = plainID(type(data) == "table" and data.dataInstanceID or nil)
	if T.redrawn then
		T.redrawn = false
	elseif id ~= T.dataID then
		T.redraws = 0
	end
	T.dataID = id
	T.guid = plainID(type(data) == "table" and data.guid or nil)
end

function T.DataUpdated(id)
	id = plainID(id)
	if not (T.dataID and id == T.dataID) or T.redrawing or (T.redraws or 0) >= REDRAWS then
		return false
	end
	-- only a tooltip the Tooltips module rebuilt has forgotten its data; the
	-- client draws its own again
	if not BT.Enabled("tooltips") then
		return false
	end
	T.redrawing = true
	T.redraws = (T.redraws or 0) + 1
	local function again()
		T.redrawing = false
		T.redrawn = true
		if not T.Restack() then
			T.redrawn = false
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, again)
	else
		again()
	end
	return true
end

-- gone from the screen: nothing of it to draw again (GameTooltip's OnHide,
-- above). Not when it is only cleared: the rebuild clears it, and that is
-- what this is for.
function T.Gone()
	T.dataID, T.redraws, T.redrawn = nil, 0, false
	T.guid, T.unit = nil, nil
end

if processor and Enum.TooltipDataType.Unit then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip, data)
		if tip ~= GameTooltip then
			return
		end
		T.Drawn(data)
		local _, unit = TooltipUtil.GetDisplayedUnit(tip)
		T.Fill(tip, unit)
	end)
	local updates = CreateFrame("Frame")
	if pcall(updates.RegisterEvent, updates, "TOOLTIP_DATA_UPDATE") then
		updates:SetScript("OnEvent", function(_, _, id)
			T.DataUpdated(id)
		end)
	end
	T.path = "processor"
elseif GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipSetUnit", function(tip)
		local _, unit = tip:GetUnit()
		T.Fill(tip, unit)
	end)
	T.path = "script"
end

if processor and Enum.TooltipDataType.Item then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
		if not T.ItemTip(tip) then
			return
		end
		T.Watch(tip)
		T.FillItem(tip, data)
	end)
	T.itemPath = "processor"
elseif GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipSetItem", function(tip)
		T.FillItem(tip)
	end)
	T.itemPath = "script"
else
	T.itemPath = "none"
end

-- a spell (an action button, the spellbook, a linked spell) and a buff or
-- debuff (the buff frame, a unit frame's auras): the data processor only;
-- a client without it keeps its own
-- AND A MACRO (Josh 2026-10-17: "the tooltip isnt working for Backstab for
-- some reason?"): a macro on an action button shows its spell's tooltip,
-- but the client says it is a macro's, so it never came here
T.spellPath = "none"
if processor then
	for kind, name in pairs({ spell = "Spell", aura = "UnitAura", macro = "Macro" }) do
		local dataType = Enum.TooltipDataType[name]
		if dataType then
			TooltipDataProcessor.AddTooltipPostCall(dataType, function(tip, data)
				if not T.SpellTip(tip) then
					return
				end
				T.Watch(tip)
				T.FillSpell(tip, data, kind)
			end)
			T.spellPath = "processor"
		end
	end
end
