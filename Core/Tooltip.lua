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
-- client and a different shape to us - nobody rebuilds an item tooltip, they
-- only mark it up - but the rule about who goes first is the same.
function BT.OnItemTooltip(moduleKey, order, fn)
	items[#items + 1] = { module = moduleKey, order = order or 50, fn = fn }
	table.sort(items, function(a, b) return a.order < b.order end)
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

local function remember(fs)
	if before[fs] ~= nil then
		return
	end
	local face, size, flags = fs:GetFont()
	local was = {
		face = face, size = size, flags = flags,
		justify = fs.GetJustifyH and fs:GetJustifyH() or nil,
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
function T.Indent(tip, i, dx, side)
	local fs = T.LineOf(tip, i, side)
	if not (fs and fs.SetPoint and fs.ClearAllPoints) then
		return nil
	end
	remember(fs)
	local was = before[fs]
	if not (was and was.at) then
		return fs
	end
	local at = was.at
	pcall(fs.ClearAllPoints, fs)
	if at[2] then
		pcall(fs.SetPoint, fs, at[1], at[2], at[3], at[4] + dx, at[5])
	else
		pcall(fs.SetPoint, fs, at[1], at[4] + dx, at[5])
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
	remember(fs)
	local face, _, flags = fs:GetFont()
	-- THE TOOLKIT'S FACE WHILE IT IS OURS (Josh 2026-09-23): the first line
	-- is the name, in the heavier weight; remember() has the game's face, and
	-- it goes back when the tooltip does. Sizes are the game's, moved by the
	-- face in use (Core/Fonts.lua).
	role = role or ((i == 1 and side ~= "TextRight") and "name" or "text")
	face = (BT.Fonts and BT.Fonts.Face(role)) or face
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
	remember(fs)
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
		remember(fs)
		pcall(fs.SetJustifyH, fs, how or "LEFT")
	end
	return fs
end

function T.Center(tip, i, side)
	return T.Justify(tip, i, "CENTER", side)
end

-- Every line we touched, back the way it was. Not "the way we assume tooltip
-- lines look": the way THAT line actually was, measured before we changed it.
function T.RestoreFonts()
	for fs, was in pairs(before) do
		if was.face and was.size and fs.SetFont then
			pcall(fs.SetFont, fs, was.face, was.size, was.flags)
		end
		if was.justify and fs.SetJustifyH then
			pcall(fs.SetJustifyH, fs, was.justify)
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

BT.OnUnitTooltipHide(function()
	T.RestoreFonts(GameTooltip)
	T.HideSwatches()
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
	run(parts, tip, unit)
end

function T.FillItem(tip)
	if not tip then
		return
	end
	T.itemFills = T.itemFills + 1
	run(items, tip)
end

-- A TOOLTIP IS DRAWN ONCE (Josh 2026-09-19). Tag somebody while their tooltip
-- is up and it keeps showing what it showed a second ago, which reads as the
-- addon disagreeing with itself. Asking the tooltip for the same unit again
-- rebuilds it, and everyone's lines go on during that rebuild.
function T.Restack()
	if not (GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()) then
		return false
	end
	local unit
	if TooltipUtil and TooltipUtil.GetDisplayedUnit then
		unit = select(2, TooltipUtil.GetDisplayedUnit(GameTooltip))
	elseif GameTooltip.GetUnit then
		unit = select(2, GameTooltip:GetUnit())
	end
	if not (unit and UnitExists and UnitExists(unit)) then
		return false
	end
	GameTooltip:SetUnit(unit)
	return true
end

if GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnHide", function()
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

if processor and Enum.TooltipDataType.Unit then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip)
		if tip ~= GameTooltip then
			return
		end
		local _, unit = TooltipUtil.GetDisplayedUnit(tip)
		T.Fill(tip, unit)
	end)
	T.path = "processor"
elseif GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipSetUnit", function(tip)
		local _, unit = tip:GetUnit()
		T.Fill(tip, unit)
	end)
	T.path = "script"
end

if processor and Enum.TooltipDataType.Item then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
		if tip ~= GameTooltip then
			return
		end
		T.FillItem(tip)
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
