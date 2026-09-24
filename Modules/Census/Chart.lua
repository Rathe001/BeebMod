-- The census view: one horizontal bar chart, four things it can count
-- (Josh 2026-09-18), in the Census window (UI/CensusWindow.lua).
--
-- Bars are sorted by size, except levels, which stay in level order - a
-- 1-10 .. 51-59, 60 chart shuffled by popularity cannot be read at all.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Census/Chart.lua")

local U = BT.Util
local C = {}
BT.Census = C

local ROWS, ROW_H, BAR_X, BAR_W = 12, 22, 150, 380
local COUNT_W = 78 -- the column the counts are right-aligned in

local MODES = {
	{ key = "class", label = "Class" },
	{ key = "race",  label = "Race" },
	{ key = "level", label = "Level" },
	{ key = "flag",  label = "Tags"  },
}
C.MODES = MODES

local function prettyClass(key)
	return (key:sub(1, 1) .. key:sub(2):lower():gsub("_", " "))
end

local function rowLabel(mode, key)
	if key == BT.Stats.UNKNOWN then
		return "Unknown"
	end
	if mode == "class" then
		return prettyClass(key)
	elseif mode == "flag" then
		local f = U.FlagByKey(key)
		return f and f.label or key
	end
	return key
end

local function rowColor(mode, key)
	if key == BT.Stats.UNKNOWN then
		return 0.42, 0.46, 0.44 -- grey: a gap in the book, not a category
	end
	if mode == "class" then
		local r, g, b = U.ClassColor(key)
		return r, g, b
	elseif mode == "flag" then
		local f = U.FlagByKey(key)
		if f and f.color then
			return f.color[1], f.color[2], f.color[3]
		end
	end
	return 0.18, 0.62, 0.48
end

-- Builds into a parent frame the Census window owns; returns a table with
-- Refresh. The helpers it used to be handed are part of the toolkit's UI kit
-- now, so it is built from the same pieces as every other page.
local label, paint = BT.Widgets.Label, BT.Widgets.Paint

function C.Build(parent)
	local view = CreateFrame("Frame", nil, parent)
	view:SetAllPoints()
	view.mode = "class"

	-- LEVEL BRACKETS, EACH ITS OWN SWITCH (Josh 2026-09-19). On a realm this
	-- young the starting zones drown every chart; turning 1-10 off is the
	-- difference between "what does the realm look like" and "what does the
	-- realm that matters to me look like". There is no "all" button: every
	-- bracket lit already means all of them.
	view.bands = {}
	view.bandButtons = {}
	local bx = 0
	local bandLabel = label(view, "LEVELS", "small", 0.42, 0.47, 0.45)
	bandLabel:SetPoint("TOPLEFT", 0, -3)
	bx = 52
	for _, band in ipairs(BT.Stats.BANDS) do
		local b = BT.Widgets.Button(view, band.key, band.key == "60" and 36 or 54, 20)
		b:SetPoint("TOPLEFT", bx, 0)
		b:SetScript("OnClick", function()
			view.bands[band.key] = not view.bands[band.key]
			C.Refresh(view)
		end)
		view.bandButtons[band.key] = b
		bx = bx + (band.key == "60" and 40 or 58)
	end

	-- THE CHARTS THE TOOLKIT CAN ACTUALLY DRAW (Josh 2026-09-19). Tags are the
	-- Ledger's vocabulary; with the Ledger switched off there is nothing to
	-- chart and the button would be a promise we cannot keep, so it goes.
	view.modeButtons = {}
	for _, m in ipairs(MODES) do
		local b = BT.Widgets.Button(view, m.label, 80, 22)
		b:SetScript("OnClick", function()
			view.mode = m.key
			C.Refresh(view)
		end)
		b.modeKey = m.key
		b.needsLedger = m.key == "flag"
		view.modeButtons[m.key] = b
	end

	-- A LINE OF ITS OWN (Josh 2026-09-19). The caption sat to the right of the
	-- chart buttons, in whatever space they happened to leave, and "2043 of
	-- 2527 characters; 484 have no level on file" ran off the end of the
	-- window. It is a sentence about the whole chart, so it gets the width of
	-- the whole chart.
	view.subtitle = label(view, "", "small", 0.55, 0.6, 0.58)
	view.subtitle:SetJustifyH("LEFT")
	view.subtitle:SetWordWrap(true)

	view.rows = {}
	for i = 1, ROWS do
		-- A ROW IS AS WIDE AS THE PANEL (Josh 2026-09-19). Rows were a fixed
		-- 560 with the count hung 538 pixels along, which ran off the edge of
		-- the window and took the percentage with it. The count is pinned to
		-- the right instead, and the bar stretches to meet it.
		local row = CreateFrame("Frame", nil, view)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 0, -72 - (i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", 0, -72 - (i - 1) * ROW_H)
		row.name = label(row, "", "small")
		row.name:SetPoint("LEFT", 4, 0)
		row.name:SetWidth(BAR_X - 12)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.track = row:CreateTexture(nil, "BACKGROUND")
		row.track:SetPoint("LEFT", BAR_X, 0)
		row.track:SetPoint("RIGHT", row, "RIGHT", -COUNT_W, 0)
		row.track:SetHeight(12)
		row.track:SetColorTexture(1, 1, 1, 0.05)
		row.bar = row:CreateTexture(nil, "ARTWORK")
		row.bar:SetPoint("LEFT", BAR_X, 0)
		row.bar:SetSize(1, 12)
		row.count = label(row, "", "small", 0.65, 0.7, 0.67)
		row.count:SetPoint("RIGHT", -2, 0)
		row.count:SetWidth(COUNT_W - 8)
		row.count:SetJustifyH("RIGHT")
		row.count:SetWordWrap(false)
		view.rows[i] = row
	end

	view.footer = label(view, "", "small", 0.5, 0.55, 0.52)
	view.footer:SetPoint("TOPLEFT", 4, -78 - ROWS * ROW_H)
	return view
end

-- nothing selected means no filter at all, which is the same as everything
-- selected and one less state to explain
local function bandFilter(view)
	local any = false
	for _, on in pairs(view.bands) do
		if on then
			any = true
			break
		end
	end
	return any and view.bands or nil
end

-- `census`, when given, is one already counted (the window's job, counted a
-- slice a frame - see UI/CensusWindow.lua); otherwise it is counted now
-- the brackets a view is counting, for a census counted elsewhere
function C.Filter(view)
	return bandFilter(view)
end

function C.Refresh(view, census)
	if not (view and BT.db) then
		return
	end
	local filter = bandFilter(view)
	census = census or BT.Stats.Census(BT.db, nil, filter)
	view.census = census
	-- lay the mode buttons out around whichever of them belong here today
	local x = 0
	for _, m in ipairs(MODES) do
		local b = view.modeButtons[m.key]
		if b.needsLedger and not BT.Enabled("ledger") then
			b:Hide()
			if view.mode == m.key then
				view.mode = "class"
			end
		else
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", x, -26)
			b:Show()
			x = x + 84
		end
	end
	view.subtitle:ClearAllPoints()
	view.subtitle:SetPoint("TOPLEFT", 1, -52)
	view.subtitle:SetPoint("TOPRIGHT", -4, -52)
	for key, b in pairs(view.modeButtons) do
		b:SetPressed(key == view.mode)
	end
	for key, b in pairs(view.bandButtons) do
		-- with no filter every bracket counts, so every button reads as on
		b:SetPressed(filter == nil or view.bands[key] == true)
	end
	local rows = census[view.mode] or {}
	-- on the level chart the brackets are a highlight, not a filter
	if view.mode == "level" and filter then
		for _, r in ipairs(rows) do
			r.muted = not view.bands[r.key]
		end
	end
	local top = 0
	for _, r in ipairs(rows) do
		if r.n > top then top = r.n end
	end
	local counted = 0
	for _, r in ipairs(rows) do
		counted = counted + r.n
	end
	for i, row in ipairs(view.rows) do
		local r = rows[i]
		if r then
			row.name:SetText(rowLabel(view.mode, r.key))
			-- the track stretches with the panel, so the bar is a fraction of
			-- whatever it actually came out as
			local track = BT.Pill.Number(row.track.GetWidth and row.track:GetWidth(), BAR_W)
			-- not laid out yet (the window opened this frame): nothing is
			-- one pixel wide, whatever the measure says
			if track < 2 then
				track = BAR_W
			end
			row.bar:SetWidth(math.max(1, track * (top > 0 and r.n / top or 0)))
			if r.muted then
				row.bar:SetColorTexture(0.35, 0.4, 0.38, 0.5)
				row.name:SetTextColor(0.42, 0.47, 0.45)
			else
				row.bar:SetColorTexture(rowColor(view.mode, r.key))
				row.name:SetTextColor(0.91, 0.93, 0.92)
			end
			-- share of everyone counted in THIS chart, not of the whole book:
			-- percentages that do not add to 100 are worse than no percentages
			local pct = counted > 0 and math.floor(r.n / counted * 100 + 0.5) or 0
			row.count:SetText(("%d  |cff6e7b75%d%%|r"):format(r.n, pct))
			row:Show()
		else
			row:Hide()
		end
	end
	view.subtitle:SetText(BT.Stats.Subtitle(view.mode, census, counted))
	view.footer:SetText(BT.Stats.AgeLine(census))
end
