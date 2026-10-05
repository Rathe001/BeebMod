-- The journals' small notices (Josh 2026-10-05).
--
-- BIG FOR RANKS, SMALL FOR THE REST (Josh 2026-10-05: "I worry about
-- achievements being too spammy. Is there a minor achievement style we could
-- use for things outside of rank increases?"; the "Notices" board of the
-- Sister journals canvas). A new rank keeps the toast at the top of the
-- screen (Modules/Expedition/Toast.lua). A commendation or a mastery is said
-- on the journal's own row in the dock instead, for a few seconds, with no
-- sound, and the row goes back to your rank and points; a click on the row
-- while it says one opens it. Several at once are one notice ("3
-- commendations +35"). With the row not in the dock, a small bar at the top
-- of the screen says it. A unique kill, a note, a tag or a hundred more
-- characters is no notice at all: the points on the row go up, with the gain
-- beside them for a moment.
--
-- An owner is a journal's dock line (Modules/Expedition/Expedition.lua,
-- Modules/Ledger/Line.lua): a table with `frame`, `text`, `eta`, `badge`,
-- `Update()` and `colour`, and `book` for the bar's line. `Redraw()`, where
-- it has one, draws the row from what it last worked out, with no counting.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Notice.lua")

local Nt = {}
BT.Notice = Nt

-- how long a notice is said on the row, how long a gain stands by the
-- points, and how close together two must come to be said as one
Nt.HOLD, Nt.GAIN_HOLD, Nt.MERGE = 4, 2, 0.6
-- the row's band, brighter while it says something
Nt.FLASH_ALPHA = 0.30
local WORDS = "|cff8a9894%s|r"

local function after(seconds, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

-- a colour a little lighter, for "+10" on a band of the same colour
local function light(c)
	return ("|cff%02x%02x%02x"):format(math.floor((c[1] + (1 - c[1]) * 0.35) * 255 + 0.5),
		math.floor((c[2] + (1 - c[2]) * 0.35) * 255 + 0.5), math.floor((c[3] + (1 - c[3]) * 0.35) * 255 + 0.5))
end

-- the row drawn as itself again, as cheaply as the owner can
local function redraw(owner)
	if owner.Redraw then
		owner.Redraw()
	elseif owner.Update then
		owner.Update()
	end
end

local function state(owner)
	owner.notices = owner.notices or { queue = {}, pending = {} }
	return owner.notices
end

-- whether the row is where a notice would be seen
local function rowShown(owner)
	local f = owner.frame
	if not (f and f.IsShown and f:IsShown()) then
		return false
	end
	if f.IsVisible then
		return f:IsVisible() and true or false
	end
	return true
end

-- Two or more said together as one: "3 commendations", or "3 earned" when
-- they are of different kinds, with all their points
function Nt.Merge(items)
	if #items == 1 then
		return items[1]
	end
	-- (an item may be a merge already: "3 commendations" and one more are 4)
	local n, points, kind, same = 0, 0, items[1].kind, true
	for _, it in ipairs(items) do
		n = n + (it.merged or 1)
		points = points + (it.points or 0)
		same = same and it.kind ~= nil and it.kind == kind
	end
	local many = { commendation = "commendations", mastery = "masteries" }
	local name = same and many[kind] and ("%d %s"):format(n, many[kind]) or ("%d earned"):format(n)
	-- a click opens the first of them
	return { name = name, points = points, onClick = items[1].onClick, kind = same and kind or nil, merged = n }
end

local function paintBand(owner, on)
	local f, c = owner.frame, owner.colour
	if not f then
		return
	end
	local band = f.beebsBand
	-- A SLIM LINE HAS NO BAND (2026-10-05, audit): the journals' lines lost
	-- theirs when the meters went level-first, and a notice changed the words
	-- alone. The line gets a wash of its colour for the notice only.
	if not band then
		if not (on or f.beebsFlash) then
			return
		end
		if not f.beebsFlash then
			f.beebsFlash = f:CreateTexture(nil, "BACKGROUND")
			f.beebsFlash:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -1)
			f.beebsFlash:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 2)
		end
		if on and c then
			f.beebsFlash:SetColorTexture(c[1], c[2], c[3], Nt.FLASH_ALPHA)
			f.beebsFlash:Show()
		else
			f.beebsFlash:Hide()
		end
		return
	end
	if on and c then
		band:SetColorTexture(c[1], c[2], c[3], Nt.FLASH_ALPHA)
	elseif BT.Dock and BT.Dock.PaintBand then
		BT.Dock.PaintBand(f)
	end
end

local showNext

-- the row says `it`, then goes back
local function sayOnRow(owner, it)
	local st = state(owner)
	st.showing = it
	owner.noticeClick = it.onClick
	local c = owner.colour or { 1, 1, 1 }
	local what = it.what and WORDS:format(" · " .. it.what) or ""
	owner.text:SetText((it.name or "") .. what)
	owner.eta:SetText(it.points and (light(c) .. "+" .. tostring(it.points) .. "|r") or "")
	paintBand(owner, true)
	local token = {}
	st.token = token
	after(Nt.HOLD, function()
		if st.token ~= token then
			return
		end
		st.showing, st.token = nil, nil
		owner.noticeClick = nil
		paintBand(owner, false)
		redraw(owner)
		showNext(owner)
	end)
end

showNext = function(owner)
	local st = state(owner)
	if st.showing then
		return
	end
	local it = table.remove(st.queue, 1)
	if not it then
		return
	end
	-- a queue that grew while one was said is said as one
	if #st.queue > 0 then
		local all = { it }
		for _, more in ipairs(st.queue) do
			all[#all + 1] = more
		end
		for i = #st.queue, 1, -1 do
			st.queue[i] = nil
		end
		it = Nt.Merge(all)
	end
	if rowShown(owner) then
		sayOnRow(owner, it)
	else
		Nt.Bar(owner, it)
		showNext(owner)
	end
end

-- Say `it` = { name, what, points, onClick, kind } on the owner's row: after
-- a beat, with whatever came with it, and after whatever it is saying now.
function Nt.Say(owner, it)
	if not (owner and it) then
		return false
	end
	local st = state(owner)
	st.pending[#st.pending + 1] = it
	if st.flushing then
		return true
	end
	st.flushing = true
	after(Nt.MERGE, function()
		st.flushing = nil
		local items = st.pending
		st.pending = {}
		if #items > 0 then
			st.queue[#st.queue + 1] = Nt.Merge(items)
			showNext(owner)
		end
	end)
	return true
end

-- whether the row is saying something now
function Nt.Saying(owner)
	return owner and owner.notices and owner.notices.showing ~= nil or false
end

-- "+3" beside the points for a moment (owner.gain, read by its Update)
function Nt.Gain(owner, n)
	if not (owner and n and n > 0) then
		return false
	end
	owner.gain = (owner.gain or 0) + n
	local token = {}
	owner.gainToken = token
	if not Nt.Saying(owner) then
		redraw(owner)
	end
	after(Nt.GAIN_HOLD, function()
		if owner.gainToken ~= token then
			return
		end
		owner.gain, owner.gainToken = nil, nil
		if not Nt.Saying(owner) then
			redraw(owner)
		end
	end)
	return true
end

-- the gain, as the row's right side starts it: "+3 " in the row's colour
function Nt.GainText(owner)
	if not (owner and owner.gain) then
		return ""
	end
	return light(owner.colour or { 1, 1, 1 }) .. "+" .. tostring(owner.gain) .. "|r  "
end

-- ---------------------------------------------------------------------------
-- The bar at the top of the screen, for a row that is not in the dock
-- ---------------------------------------------------------------------------

local bar

function Nt.BuildBar()
	if bar then
		return bar
	end
	local W = BT.Widgets
	bar = CreateFrame("Button", "BeebModNotice", UIParent)
	bar:SetSize(260, 26)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -104)
	bar:SetFrameStrata("DIALOG")
	BT.Pill.Panel(bar, { 0.035, 0.05, 0.05, 0.95 }, W.RIM)
	bar.badge = bar:CreateTexture(nil, "ARTWORK")
	bar.badge:SetSize(14, 19)
	bar.badge:SetPoint("LEFT", 8, 0)
	local c = BT.Dock and BT.Dock.LINE_ICON_CROP or { 0.25, 0.75, 0.2, 0.875 }
	bar.badge:SetTexCoord(c[1], c[2], c[3], c[4])
	bar.text = W.Label(bar, "", "small")
	bar.text:SetPoint("LEFT", bar.badge, "RIGHT", 7, 0)
	bar.text:SetJustifyH("LEFT")
	bar.text:SetWordWrap(false)
	bar:SetScript("OnClick", function(self)
		self:Hide()
		if self.onClick then
			self.onClick()
		end
	end)
	bar:SetScript("OnUpdate", function(self, elapsed)
		self.age = (self.age or 0) + (elapsed or 0)
		if self:IsMouseOver() then
			self.age = math.min(self.age, Nt.HOLD)
			self:SetAlpha(1)
		elseif self.age > Nt.HOLD + 0.6 then
			self:Hide()
		elseif self.age > Nt.HOLD then
			self:SetAlpha(1 - (self.age - Nt.HOLD) / 0.6)
		else
			self:SetAlpha(1)
		end
	end)
	bar:Hide()
	return bar
end

-- `it` on the bar: the owner's badge, the name, what it is, and the points
function Nt.Bar(owner, it)
	local b = Nt.BuildBar()
	local c = owner.colour or { 1, 1, 1 }
	BT.Pill.Recolour(b, nil, { c[1], c[2], c[3], 0.6 })
	b.badge:SetTexture(owner.badge and owner.badge.GetTexture and owner.badge:GetTexture() or nil)
	-- with no row to say whose it is, a commendation names its journal:
	-- "Fine Print  Ledger commendation  +10"
	local what = it.what
	if it.kind == "commendation" and it.merged == nil and owner.book then
		what = ("%s commendation"):format(owner.book)
	end
	b.text:SetText(("%s%s%s"):format(it.name or "", what and WORDS:format("  " .. what) or "",
		it.points and ("  " .. light(c) .. "+" .. tostring(it.points) .. "|r") or ""))
	local w = BT.Pill.Number(b.text.GetStringWidth and b.text:GetStringWidth(), 200)
	b:SetWidth(math.max(160, math.floor(w + 44)))
	b.onClick = it.onClick
	b.age = 0
	b:SetAlpha(1)
	b:Show()
	return b
end

