-- The census view: one horizontal bar chart, six things it can count
-- (Josh 2026-09-18; guild and zone 2026-09-24), on the Ledger window's
-- Charts page (UI/CensusWindow.lua).
--
-- Bars are sorted by size, except levels, which stay in level order - a
-- 1-10 .. 51-59, 60 chart shuffled by popularity cannot be read at all.
--
-- IN THE JOURNALS' WINDOW (Josh 2026-10-05, the "Sister journals" canvas):
-- the six charts are the rail down the page's left, where the Field
-- Journal's types are, and Seen is on the toolbar over the tiles.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Census/Chart.lua")

local U = BT.Util
local C = {}
BT.Census = C

-- AS MANY ROWS AS THE WINDOW HAS ROOM FOR (Josh 2026-11-12: "extend the height
-- to the window height for all charts"). The window is a fixed height and
-- the charts stopped at twelve rows, with a third of it empty under them.
-- ROWS is the least a chart shows; MAX_ROWS are made, and C.Fit says how many
-- of them the column holds today (fewer under the chips' line).
local ROWS, ROW_H, MAX_ROWS = 12, 22, 24
-- under the last row: a gap, and the line of the footer
local FOOT_H = 26
-- the tiles, the chips of the filters that are on, then the bars
local TILE_H = 62
local CAP_Y = -(TILE_H + 10)
local ROWS_Y = CAP_Y - 28
-- where the bars start with no filter on: the chips' line is not needed
local ROWS_BARE = -(TILE_H + 12)
-- where a bar starts, the count's column and the share's, and a bar's room
-- before the window has been laid out (UI/Book.lua: the column, 572 wide)
local BAR_X, COUNT_W, PCT_W = 140, 58, 38
local BAR_W = 572 - BAR_X - COUNT_W - PCT_W

local MODES = {
	{ key = "class", label = "Class" },
	{ key = "race",  label = "Race" },
	{ key = "level", label = "Level" },
	{ key = "guild", label = "Guild" },
	{ key = "zone",  label = "Zone"  },
	{ key = "tag",   label = "Tags",  ledger = true },
	-- the people you grouped with, a row each (C.Grouped): the Ledger's too
	{ key = "grouped", label = "Grouped", ledger = true },
}
C.MODES = MODES

-- the search box's width, and what was typed as the words to look for: lower
-- case, no spaces at the ends
C.SEARCH_W = 120
function C.Words(text)
	if type(text) ~= "string" then
		return ""
	end
	return (text:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

local function prettyClass(key)
	return (key:sub(1, 1) .. key:sub(2):lower():gsub("_", " "))
end

local function rowLabel(mode, key)
	local S = BT.Stats
	if key == S.UNKNOWN then
		return "Unknown"
	elseif key == S.UNGUILDED then
		return "No guild"
	elseif key == S.OTHER then
		return (mode == "guild" and "Other guilds") or (mode == "tag" and "Other tags") or "Elsewhere"
	end
	if mode == "class" then
		return prettyClass(key)
	elseif mode == "race" then
		return C.RaceName(key)
	elseif mode == "tag" then
		local f = U.TagByKey(key)
		return f and f.label or key
	end
	return key
end

-- A RACE BY THE NAME PLAYERS USE (Josh 2026-09-29: "Any idea how scourge and
-- tauren show up on the census?"): the book keeps the game's own word for a
-- race, which runs words together and calls the Undead "Scourge"; the chart
-- says "Night Elf" and "Undead"
local RACE_NAMES = { Scourge = "Undead" }
function C.RaceName(key)
	if type(key) ~= "string" then
		return key
	end
	return RACE_NAMES[key] or (key:gsub("(%l)(%u)", "%1 %2"))
end

-- THE BARS IN THE ACCENT (2026-11-06, audit): a fixed green, so with the
-- class colour as accent the chart stayed green while every other panel
-- changed. A bar is the accent a little darker, as the green was; the bar
-- you picked is the accent itself.
local BAR_SHADE = 0.8
local function barColour()
	local a = BT.Widgets.ACCENT
	return a[1] * BAR_SHADE, a[2] * BAR_SHADE, a[3] * BAR_SHADE
end

local function rowColor(mode, key)
	local S = BT.Stats
	if key == S.UNKNOWN or key == S.UNGUILDED or key == S.OTHER then
		return 0.42, 0.46, 0.44 -- grey: a gap in the book, or a pile, not a category
	end
	if mode == "class" then
		local r, g, b = U.ClassColor(key)
		return r, g, b
	elseif mode == "tag" then
		local f = U.TagByKey(key)
		if f and f.color then
			return f.color[1], f.color[2], f.color[3]
		end
	end
	return barColour()
end

-- Builds into a parent frame the Census window owns; returns a table with
-- Refresh. The helpers it used to be handed are part of the toolkit's UI kit
-- now, so it is built from the same pieces as every other page.
local label, paint = BT.Widgets.Label, BT.Widgets.Paint

-- THE SUMMARY THAT FILTERS (Josh 2026-09-30: "I really like the summary with
-- filters"). Four rows of buttons said nothing until they were pressed. Four
-- tiles across the top say who is in the book first - how many, which side,
-- which sex, which levels - and each is the filter for what it shows: a click
-- on Alliance, on female, on a level's column narrows every chart, and the
-- filters that are on line up as chips beside the count, each with its x.
-- Seen sits at the end of the chart's tabs, and the bars' hover card says
-- what a click on one does.
local SIDE_COLOUR = { Alliance = { 0.25, 0.50, 0.88 }, Horde = { 0.79, 0.26, 0.23 } }
local SEX_COLOUR = { [2] = { 0.42, 0.62, 0.84 }, [3] = { 0.83, 0.50, 0.69 } }
local NONE = { 0.30, 0.31, 0.30 }
local TILE_W, TILE_GAP = { 119, 137, 137, 155 }, 8
C.SEX_WORD = { [2] = "Male", [3] = "Female" }

local function tile(view, i, title)
	local x = 0
	for k = 1, i - 1 do
		x = x + TILE_W[k] + TILE_GAP
	end
	local t = CreateFrame("Frame", nil, view)
	t:SetPoint("TOPLEFT", x, 0)
	t:SetSize(TILE_W[i], TILE_H)
	BT.Pill.Panel(t, BT.Widgets.RAISED, BT.Widgets.RIM)
	t.cap = label(t, string.upper(title), "small", 0.42, 0.47, 0.45)
	t.cap:SetPoint("TOPLEFT", 9, -7)
	t.w = TILE_W[i]
	return t
end

-- how wide a label's words are, or nil when the client won't say plainly
local function width(fs)
	local ok, w = pcall(fs.GetStringWidth, fs)
	if not ok or type(w) ~= "number" or (issecretvalue and issecretvalue(w)) then
		return nil
	end
	return w
end

-- a bar of shares, and the words under its two ends; each half of the tile
-- is the click for its side
local function splitTile(view, i, title, keys, colours, onPick)
	local t = tile(view, i, title)
	t.keys = keys
	t.track = t:CreateTexture(nil, "ARTWORK")
	t.track:SetPoint("TOPLEFT", 9, -24)
	t.track:SetSize(t.w - 18, 10)
	t.track:SetColorTexture(NONE[1], NONE[2], NONE[3], 0.6)
	t.parts, t.buttons = {}, {}
	for n, k in ipairs(keys) do
		local c = colours[k]
		local part = t:CreateTexture(nil, "ARTWORK", nil, 1)
		part:SetHeight(10)
		part:SetColorTexture(c[1], c[2], c[3], 1)
		t.parts[k] = part
		local b = CreateFrame("Button", nil, t)
		b:SetSize(t.w / 2, TILE_H - 18)
		b:SetPoint(n == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
		b.key = k
		b.words = label(b, "", "small", 0.72, 0.76, 0.74)
		b.words:SetPoint(n == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", n == 1 and 9 or -9, 8)
		b.words:SetJustifyH(n == 1 and "LEFT" or "RIGHT")
		b:SetScript("OnClick", function(self)
			if self.live then
				onPick(self.key)
			end
		end)
		b:SetScript("OnEnter", function(self)
			self.hovered = true
			if t.paint then t.paint() end
			if BT.Tip and t.tip then
				BT.Tip.Show(self, { near = true, build = function(card) t.tip(card, self.key) end })
			end
		end)
		b:SetScript("OnLeave", function(self)
			self.hovered = false
			if t.paint then t.paint() end
			if BT.Tip then BT.Tip.Hide() end
		end)
		t.buttons[k] = b
	end
	t.none = label(t, "Not seen yet", "small", 0.42, 0.47, 0.45)
	t.none:SetPoint("BOTTOMLEFT", 9, 8)
	t.none:Hide()
	return t
end

-- `shell` is the page's rail and toolbar (UI/Book.lua): the charts are the
-- rail's rows, and Seen sits on the toolbar
function C.Build(parent, shell)
	shell = shell or {}
	local view = CreateFrame("Frame", nil, parent)
	view:SetAllPoints()
	view.mode = "class"
	view.seen, view.faction, view.sex = "all", "all", "all"
	view.bands = {}

	-- THE TILES
	local count = tile(view, 1, "Characters")
	count.num = count:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	count.num:SetPoint("TOPLEFT", 9, -22)
	count.sub = label(count, "", "small", 0.55, 0.6, 0.58)
	count.sub:SetPoint("BOTTOMLEFT", 9, 8)
	view.countTile = count

	-- a side, or a sex: a click picks it, and a click on the one picked lets go
	view.sideTile = splitTile(view, 2, "Faction", { "Alliance", "Horde" }, SIDE_COLOUR, function(k)
		view.faction = view.faction == k and "all" or k
		C.Refresh(view)
	end)
	view.factionButtons = view.sideTile.buttons
	view.sexTile = splitTile(view, 3, "Gender", { 2, 3 }, SEX_COLOUR, function(k)
		view.sex = view.sex == k and "all" or k
		C.Refresh(view)
	end)
	view.sexButtons = view.sexTile.buttons

	-- LEVEL BRACKETS, EACH ITS OWN SWITCH (Josh 2026-09-19), as a column each
	-- of how many are in it: none lit is every level, as it always was
	local levels = tile(view, 4, "Level")
	view.levelTile = levels
	view.bandButtons = {}
	local n = #BT.Stats.BANDS
	local colW = (levels.w - 18 - (n - 1) * 3) / n
	for i, band in ipairs(BT.Stats.BANDS) do
		local b = CreateFrame("Button", nil, levels)
		b:SetSize(colW, 36)
		b:SetPoint("BOTTOMLEFT", 9 + (i - 1) * (colW + 3), 4)
		b.key = band.key
		b.bar = b:CreateTexture(nil, "ARTWORK")
		b.bar:SetPoint("BOTTOM", b, "BOTTOM", 0, 12)
		b.bar:SetWidth(colW)
		b.bar:SetHeight(2)
		b.num = label(b, tostring(band.min), "small", 0.42, 0.47, 0.45)
		b.num:SetPoint("BOTTOM", 0, 0)
		b:SetScript("OnClick", function(self)
			if self.live then
				view.bands[self.key] = not view.bands[self.key] or nil
				C.Refresh(view)
			end
		end)
		b:SetScript("OnEnter", function(self)
			if BT.Tip and self.n then
				BT.Tip.Show(self, { near = true, build = function(t)
					t:Header({ name = "Level " .. self.key:gsub("%-", "–"), sub = U.Commas(self.n) })
					if self.live then
						t:Foot({ { "Click", view.bands[self.key] and "show all levels" or "show only these levels" } })
					end
				end })
			end
		end)
		b:SetScript("OnLeave", function()
			if BT.Tip then BT.Tip.Hide() end
		end)
		view.bandButtons[band.key] = b
	end

	-- THE CHARTS THE TOOLKIT CAN ACTUALLY DRAW (Josh 2026-09-19), as the
	-- rail's rows: Tags are the Ledger's, so with the Ledger off there is no
	-- Tags row (C.PaintModes). Each chart's row, by its key, for the tests.
	view.rail = shell.rail
	view.modeButtons = {}
	if view.rail then
		view.rail.onPick = function(key)
			-- a new chart starts at its top
			if key ~= view.mode and view.groupScroll then
				view.painting = true
				view.groupScroll:ScrollTo(0)
				view.painting = nil
			end
			-- and with no search (Josh 2026-11-12: "When switching the chart, we
			-- should clear out the text search"): words typed for a guild
			-- find nothing among the classes
			if key ~= view.mode and view.searchBox and view.search ~= "" then
				view.search = ""
				view.searchBox.edit:SetText("")
				view.searchBox.edit:ClearFocus()
				view.searchBox.Apply()
			end
			view.mode = key
			C.Refresh(view)
		end
		C.PaintModes(view)
	end

	-- SEEN WITHIN (Josh 2026-09-24), on the toolbar's right
	local seenOptions = {}
	for _, s in ipairs(BT.Stats.SEEN) do
		seenOptions[#seenOptions + 1] = { s.key, s.short or s.label }
	end
	local bar = shell.toolbar or view
	-- a dropdown (Josh 2026-11-12): eight choices are too many for a row of buttons
	view.seenControl = BT.Widgets.Dropdown(bar, seenOptions, function(k)
		view.seen = k
		C.Refresh(view)
	end, 96)
	view.seenControl:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	view.seenWord = label(bar, "Seen", "small", 0.50, 0.55, 0.53)
	view.seenWord:SetPoint("RIGHT", view.seenControl, "LEFT", -8, 0)
	view.seenButtons = {}
	for _, b in ipairs(view.seenControl.buttons) do
		view.seenButtons[b.key] = b
	end

	-- A SEARCH (Josh 2026-11-12: "I want to be able to search 'Olympus' for
	-- example, to see all the guilds with olympus in their names"). It narrows
	-- the rows of the chart you are on to the ones with the words in their
	-- name, and on Guild, Zone and Tags it looks through all of them and not
	-- only the ten largest. Nothing is counted again: the tiles and the
	-- shares stay as they were.
	view.search = ""
	if BT.Book and BT.Book.Search then
		view.searchBox = BT.Book.Search(bar, "Search", C.SEARCH_W, function(text)
			text = C.Words(text)
			if text ~= view.search then
				view.search = text
				view.groupScroll:ScrollTo(0)
				C.Refresh(view)
			end
		end)
		view.searchBox:SetPoint("RIGHT", view.seenWord, "LEFT", -12, 0)
	end

	-- every filter that is on, a chip with its x, on a line of their own
	-- above the bars. NO COUNT BESIDE THEM (Josh 2026-10-01: "I think we can
	-- just remove this line"): the tiles say how many there are.
	view.chips = {}

	-- MORE PEOPLE THAN ROWS (Josh 2026-11-12, the Grouped chart: "Scrolling
	-- list is good"). The other charts are twelve rows at most; the people
	-- you grouped with can be hundreds. The twelve rows stay where they are
	-- and show a different twelve: this scroller, under them, takes the wheel
	-- and draws the thumb, and the rows are painted from wherever it stands.
	view.groupScroll = BT.Widgets.Scroller(view, 8)
	view.groupScroll.step = ROW_H * 3
	view.groupScroll:Hide()
	do
		local sc = view.groupScroll
		local scrollTo = sc.ScrollTo
		function sc:ScrollTo(y)
			local at = scrollTo(self, y)
			if view.scrolls and not view.painting then
				C.Refresh(view)
			end
			return at
		end
	end
	local rowLevel = (view.GetFrameLevel and view:GetFrameLevel() or 1) + 3

	view.rows = {}
	view.fit = ROWS
	for i = 1, MAX_ROWS do
		-- A ROW IS AS WIDE AS THE PANEL (Josh 2026-09-19): the count and its
		-- share pinned to the right, and the bar stretching to meet them
		local row = CreateFrame("Button", nil, view)
		pcall(row.SetFrameLevel, row, rowLevel)
		-- the wheel over a row is the scroller's, whichever of them the
		-- client hands it to
		pcall(row.EnableMouseWheel, row, true)
		row:SetScript("OnMouseWheel", function(_, delta)
			if view.scrolls then
				view.groupScroll:ScrollBy(-(delta or 0) * view.groupScroll.step)
			end
		end)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 0, ROWS_Y - (i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", 0, ROWS_Y - (i - 1) * ROW_H)
		row.hover = row:CreateTexture(nil, "BACKGROUND")
		row.hover:SetAllPoints()
		row.hover:SetColorTexture(1, 1, 1, 0.04)
		row.hover:Hide()
		-- the bar picked: lit, with an edge
		row.pickBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.pickBg:SetAllPoints()
		row.pickEdge = row:CreateTexture(nil, "ARTWORK", nil, 2)
		row.pickEdge:SetPoint("TOPLEFT")
		row.pickEdge:SetPoint("BOTTOMLEFT")
		row.pickEdge:SetWidth(2)
		row:SetScript("OnEnter", function(self)
			if self.pickable then
				self.hover:Show()
			end
			if BT.Tip and self.n then
				BT.Tip.Show(self, { near = true, build = function(t)
					-- a person: how often, and the last time and place
					local who = self.person
					if who then
						local what = who.class and prettyClass(who.class) or nil
						if what and who.level then
							what = ("Level %d %s"):format(who.level, what)
						end
						t:Header({ name = who.name, sub = what })
						t:Note(BT.LedgerGroups and BT.LedgerGroups.Line({ grouped = who.n, groupedAt = who.at,
							groupedWhere = who.where }) or U.Commas(who.n))
						return
					end
					t:Header({ name = self.name:GetText(), sub = U.Commas(self.n) })
					t:Note(("%d%% of the %s in this chart."):format(self.share or 0, U.Commas(self.of or 0)))
					if self.pickable then
						t:Foot({ { "Click", self.picked and "show everyone" or "show only these" } })
					end
				end })
			end
		end)
		row:SetScript("OnLeave", function(self)
			self.hover:Hide()
			if BT.Tip then BT.Tip.Hide() end
		end)
		row:SetScript("OnClick", function(self)
			if not self.pickable then
				return
			end
			local p = view.pick
			if p and p.mode == view.mode and p.key == self.key then
				view.pick = nil
			else
				view.pick = { mode = view.mode, key = self.key }
			end
			C.Refresh(view)
		end)
		row.name = label(row, "", "small")
		row.name:SetPoint("LEFT", 8, 0)
		row.name:SetWidth(BAR_X - 16)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.track = row:CreateTexture(nil, "BACKGROUND", nil, 2)
		row.track:SetPoint("LEFT", BAR_X, 0)
		row.track:SetPoint("RIGHT", row, "RIGHT", -(COUNT_W + PCT_W), 0)
		row.track:SetHeight(12)
		row.track:SetColorTexture(1, 1, 1, 0.05)
		row.bar = row:CreateTexture(nil, "ARTWORK")
		row.bar:SetPoint("LEFT", BAR_X, 0)
		row.bar:SetSize(1, 12)
		row.count = label(row, "", "small", 0.86, 0.89, 0.87)
		row.count:SetPoint("RIGHT", -PCT_W, 0)
		row.count:SetWidth(COUNT_W - 6)
		row.count:SetJustifyH("RIGHT")
		row.count:SetWordWrap(false)
		row.pct = label(row, "", "small", 0.43, 0.48, 0.46)
		row.pct:SetPoint("RIGHT", -4, 0)
		row.pct:SetWidth(PCT_W - 6)
		row.pct:SetJustifyH("RIGHT")
		view.rows[i] = row
	end

	view.footer = label(view, "", "small", 0.5, 0.55, 0.52)
	view.footer:SetPoint("TOPLEFT", 4, ROWS_Y - 8 - ROWS * ROW_H)
	view.note = label(view, "", "small", 0.42, 0.47, 0.45)
	view.note:SetPoint("TOPRIGHT", view, "TOPRIGHT", -4, ROWS_Y - 8 - ROWS * ROW_H)
	view.note:SetJustifyH("RIGHT")
	-- the window opens before it has a height, and the rows that fit are
	-- counted from it: drawn again once it is known
	view:SetScript("OnSizeChanged", function(self)
		if self.census and not self.painting and self.fit ~= C.Fit(self, self.rowsTop or ROWS_BARE) then
			C.Refresh(self)
		end
	end)
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

-- what a view is counting - brackets, how recently, the bar picked - for a
-- census counted elsewhere (BT.Stats.Census has the shape)
function C.Filter(view)
	-- a pick on a chart that is not there today (tags, with the Ledger off)
	-- is a filter nobody can see or undo; so is one on a tag since deleted,
	-- which stayed as a chip named "tag5" over an empty chart (2026-10-17,
	-- audit)
	local pick = view.pick
	if pick and pick.mode == "tag" and not (BT.Enabled("ledger") and U.TagByKey(pick.key)) then
		view.pick, pick = nil, nil
	end
	return { bands = bandFilter(view), seen = view.seen, pick = pick,
		faction = view.faction ~= "all" and view.faction or nil,
		sex = view.sex ~= "all" and view.sex or nil }
end

-- what a filter is, as one string: two censuses of the same one are
-- interchangeable
function C.FilterKey(want)
	local bands = {}
	for k, on in pairs(want.bands or {}) do
		if on then
			bands[#bands + 1] = tostring(k)
		end
	end
	table.sort(bands)
	local p = want.pick
	return table.concat({ p and (tostring(p.mode) .. ":" .. tostring(p.key)) or "-",
		want.seen or "all", table.concat(bands, ","), want.faction or "all", tostring(want.sex or "all") }, "|")
end

-- NO LONG FRAME ON OPENING (Josh 2026-09-29: "I notice when I open the census
-- the game lags"). A census of 22,600 characters is a tenth of a second in
-- one go - a stutter you feel. A book more than two slices big is counted a
-- slice a frame instead, the charts on screen staying until the new ones
-- are ready; a small one is counted at once, which is quicker than waiting.
local runner
function C.Runner()
	return runner
end

-- A FEW MILLISECONDS A FRAME, NOT A SLICE (Josh 2026-09-29, /bt cpu: a slice
-- of 2,000 characters was 30 to 49 ms in the game, four times the desktop's
-- figure). Each frame counts until this much time has gone, then stops.
C.BUDGET = 4

-- NOTHING UNTIL IT IS READY (Josh 2026-09-29: "Maybe we should add a loading
-- spinner and not show anything until we finish"): while a count you asked
-- for runs, the charts are put away and three dots pulse over how far it has
-- got. The window's own recount, every ten seconds while it is open, keeps
-- the charts up and swaps them when it is done.
local DOTS = 3
function C.Loading(view, on, share, size)
	local l = view.loading
	if not l then
		l = CreateFrame("Frame", nil, view)
		l:SetSize(220, 40)
		l:SetPoint("TOP", view, "TOP", 0, ROWS_Y - 40)
		l.dots = {}
		local accent = BT.Widgets.ACCENT
		for i = 1, DOTS do
			local d = l:CreateTexture(nil, "ARTWORK")
			d:SetSize(6, 6)
			d:SetPoint("TOP", l, "TOP", (i - 2) * 12, 0)
			d:SetColorTexture(accent[1], accent[2], accent[3], 1)
			l.dots[i] = d
		end
		l.label = label(l, "", "small", 0.55, 0.6, 0.58)
		l.label:SetPoint("TOP", l, "TOP", 0, -14)
		l.t = 0
		l:SetScript("OnUpdate", function(self, elapsed)
			self.t = self.t + (elapsed or 0)
			for i, d in ipairs(self.dots) do
				local wave = math.sin(self.t * 6 - i * 0.9)
				d:SetAlpha(0.25 + 0.75 * math.max(0, wave))
			end
		end)
		view.loading = l
	end
	l:SetShown(on and true or false)
	if on then
		local n = size and U.Commas(size) or "the"
		l.label:SetText(("Counting %s characters · %d%%"):format(n, math.floor((share or 0) * 100)))
		for _, row in ipairs(view.rows or {}) do
			row:Hide()
		end
		if view.footer then
			view.footer:Hide()
			view.note:Hide()
		end
	elseif view.footer then
		view.footer:Show()
		view.note:Show()
	end
end

local function countSliced(view, step, key, size)
	runner = runner or CreateFrame("Frame")
	view.counting = key
	C.Loading(view, true, 0, size)
	runner:SetScript("OnUpdate", function(self)
		local census, share = step(C.BUDGET)
		if census then
			self:SetScript("OnUpdate", nil)
			view.counting = nil
			census.key = key
			C.Loading(view, false)
			C.Refresh(view, census)
		else
			C.Loading(view, true, share, size)
		end
	end)
end

-- THE WINDOW SHUT (2026-10-17, audit): the count stops, and forgets what it
-- was counting, so opening the window again counts afresh rather than
-- waiting on a count that is no longer running
function C.Stop(view)
	if runner then
		runner:SetScript("OnUpdate", nil)
	end
	if view then
		view.counting = nil
	end
end

-- `census`, when given, is one already counted (a slice a frame - here, or
-- the window's own job in UI/CensusWindow.lua); otherwise the view's last one
-- is used if it counted the same thing and the book has not moved since, and
-- only then is the book counted again.
function C.Refresh(view, census)
	if not (view and BT.db) then
		return
	end
	local want = C.Filter(view)
	local filter = want.bands
	local key = C.FilterKey(want)
	-- counted a slice at a time before a click changed what to count: that
	-- census is of the wrong thing, so count the right one
	if census then
		if census.key and census.key ~= key then
			census = nil
		elseif not census.key and (census.pick ~= want.pick or (census.seen or "all") ~= (want.seen or "all")
			or want.faction or want.sex) then
			census = nil
		end
	end
	-- ANOTHER CHART OF THE SAME COUNT (Class, Race, Level...): one census
	-- holds every chart, so changing chart counts nothing
	if not census and view.census and view.censusKey == key and not view.stale then
		census = view.census
	end
	if not census then
		-- ALREADY BEING COUNTED (Josh 2026-09-30, review). A click on Race or
		-- Level while the count you were waiting for ran started it again
		-- from nothing. It is left to finish, and it draws whichever chart is
		-- picked when it does.
		if view.counting == key then
			C.PaintModes(view)
			return
		end
		local per = BT.Stats.JOB_SLICE
		local step, size = BT.Stats.CensusJob(BT.db, nil, want, per)
		if CreateFrame and (size or 0) > per * 2 then
			countSliced(view, step, key, size)
			return
		end
		repeat
			census = step()
		until census
		census.key = key
	end
	view.census, view.censusKey, view.stale = census, key, nil
	-- a slower count of something no longer wanted is stopped
	if view.counting and view.counting ~= key then
		view.counting = nil
		if runner then
			runner:SetScript("OnUpdate", nil)
		end
	end
	-- A CHART DRAWN IS A COUNT DONE (Josh 2026-09-30: "If I quickly switch
	-- filters, the loading indicator and 'Counting...' aren't removed"). Only
	-- a count that finished put the dots away, so going back to a filter
	-- already counted, while another count ran, drew its chart under dots
	-- frozen at that count's last share.
	if view.loading and view.loading:IsShown() then
		C.Loading(view, false)
	end
	-- the rail: the charts there are today
	C.PaintModes(view)
	view.seenControl:Select(view.seen or "all")

	C.PaintTiles(view, census)
	-- the bars under the chips while a filter is on, and in their place when not
	-- (not `top`: that name is the biggest bar's count further down, and the
	-- window was once made as tall as 4,738 less the rows: negative, with no
	-- background and its top above the screen)
	local chips = C.PaintChips(view)
	local rowsTop = chips > 0 and ROWS_Y or ROWS_BARE
	-- the people you grouped with: every one of them, twelve at a time from
	-- where the scroller stands
	local grouped = view.mode == "grouped"
	local rows, first = BT.Stats.LongRows(census, view.mode), 0
	-- everyone the chart counts, whatever the search leaves of it
	local counted = 0
	for _, r in ipairs(rows) do
		counted = counted + r.n
	end
	if grouped then
		rows = C.Grouped(view, want, key, census)
	end
	local words = view.search or ""
	if words ~= "" then
		rows = C.Search(view, census, rows, words)
	end
	-- EVERY CHART SCROLLS (Josh 2026-11-12): as many rows as fit, from wherever
	-- the scroller stands, and its thumb only when there are more than fit
	view.scrolls = true
	view.rowsTop = rowsTop
	local fit = C.Fit(view, rowsTop)
	first =C.GroupedFirst(view, #rows, rowsTop)
	-- room for the thumb when there is one
	local inset = #rows > fit and -12 or 0
	for i, row in ipairs(view.rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, rowsTop - (i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", inset, rowsTop - (i - 1) * ROW_H)
	end

	local pick = view.pick
	-- On the level chart the brackets are a highlight, not a filter; on the
	-- chart a bar was picked from, every bar but that one is quiet.
	local function muted(r)
		if view.mode == "level" and filter then
			return not view.bands[r.key]
		end
		return pick ~= nil and pick.mode == view.mode and pick.key ~= r.key
	end
	local pickable = BT.Stats.PICKABLE[view.mode]
	-- THE BARS ARE MEASURED AGAINST THE BIGGEST NAMED ROW (Josh 2026-11-12:
	-- "fix the no guild and other guilds"). No guild and Other guilds were
	-- 37% and 57% of the chart, so the largest guild, at 1%, was a sliver and
	-- no two guilds could be told apart. The grey rows (a gap in the book, a
	-- pile of the rest) are not what the chart compares: they are drawn full
	-- when they are bigger than every named row, and their numbers say by how
	-- much. A chart of nothing but grey rows measures against those.
	local S = BT.Stats
	local top, greyTop = 0, 0
	for _, r in ipairs(rows) do
		if r.key == S.UNKNOWN or r.key == S.UNGUILDED or r.key == S.OTHER then
			if r.n > greyTop then greyTop = r.n end
		elseif r.n > top then
			top = r.n
		end
	end
	if top == 0 then
		top = greyTop
	end
	local accent = BT.Widgets.ACCENT
	local shown = 0
	for i, row in ipairs(view.rows) do
		local r = i <= fit and rows[i + first] or nil
		if r then
			shown = shown + 1
			row.person = grouped and r or nil
			row.name:SetText(grouped and r.name or rowLabel(view.mode, r.key))
			-- the track stretches with the panel, so the bar is a fraction of
			-- whatever it actually came out as
			local track = BT.Pill.Number(row.track.GetWidth and row.track:GetWidth(), BAR_W)
			-- not laid out yet (the window opened this frame): nothing is
			-- one pixel wide, whatever the measure says
			if track < 2 then
				track = BAR_W
			end
			row.bar:SetWidth(math.max(1, track * (top > 0 and math.min(1, r.n / top) or 0)))
			-- the pile of the rest is not one thing, so it cannot be picked
			row.key = r.key
			row.pickable = pickable and r.key ~= BT.Stats.OTHER
			row.picked = pick ~= nil and pick.mode == view.mode and pick.key == r.key
			row.pickBg:SetColorTexture(accent[1], accent[2], accent[3], 0.10)
			row.pickEdge:SetColorTexture(accent[1], accent[2], accent[3], 1)
			row.pickBg:SetShown(row.picked)
			row.pickEdge:SetShown(row.picked)
			if muted(r) then
				row.bar:SetColorTexture(0.35, 0.4, 0.38, 0.5)
				BT.Ink(row.name, "faint")
			else
				-- a person's bar is their class's colour
				row.bar:SetColorTexture(rowColor(grouped and "class" or view.mode,
					grouped and (r.class or BT.Stats.UNKNOWN) or r.key))
				BT.Ink(row.name, "ink")
			end
			-- share of everyone counted in THIS chart, not of the whole book:
			-- percentages that do not add to 100 are worse than no percentages
			local pct = counted > 0 and math.floor(r.n / counted * 100 + 0.5) or 0
			row.n, row.share, row.of = r.n, pct, counted
			row.count:SetText(U.Commas(r.n))
			-- a share of all your groups says nothing about one person
			row.pct:SetText(grouped and "" or (pct .. "%"))
			row:Show()
		else
			row.key, row.pickable, row.picked, row.n, row.person = nil, nil, nil, nil, nil
			row:Hide()
		end
	end
	-- THE WINDOW AS TALL AS ITS ROWS (the census redesign): the footer under
	-- the last bar, and the window told how tall that makes it
	local bottom = rowsTop - math.max(shown, 1) * ROW_H - 8
	view.footer:ClearAllPoints()
	view.footer:SetPoint("TOPLEFT", 4, bottom)
	-- HOW MANY (Josh 2026-11-12: "we need to show the number of results
	-- somewhere, especially if the text search is used"): first on the line
	-- under the rows, before how old the book is
	local howMany = C.CountLine(view.mode, words ~= "" and #rows or C.Named(census, view.mode, rows), words)
	if #rows == 0 and words ~= "" then
		view.footer:SetText(howMany)
	elseif grouped then
		view.footer:SetText(#rows > 0 and howMany or C.GroupedLine(#rows, chips > 0))
	elseif howMany then
		view.footer:SetText(howMany .. " · " .. BT.Stats.AgeLine(census))
	else
		view.footer:SetText(BT.Stats.AgeLine(census))
	end
	view.note:ClearAllPoints()
	view.note:SetPoint("TOPRIGHT", view, "TOPRIGHT", -4, bottom)
	local unknown = census.unknown and census.unknown[view.mode] or 0
	view.note:SetText(unknown > 0 and C.NOTE[view.mode]
		and ("%s unknown for %s"):format(C.NOTE[view.mode], U.Commas(unknown)) or "")
	view.height = -bottom + 16
	if view.onHeight then
		view.onHeight(view.height)
	end
end

-- The people you grouped with, for the filter that is on (BT.Stats.Grouped):
-- read again when the filter, the Ledger's book or the census changes, and
-- not on every notch of the wheel
function C.Grouped(view, want, key, census)
	local N = BT.Notes
	local stamp = key .. "#" .. tostring(N and N.rev or 0)
	if view.grouped and view.groupedStamp == stamp and view.groupedFor == census then
		return view.grouped
	end
	view.grouped = BT.Stats.Grouped(N and N.People and N.People() or nil, BT.db, nil, want)
	view.groupedStamp, view.groupedFor = stamp, census
	return view.grouped
end

-- The rows of a chart with `words` in their name, largest first. On Guild,
-- Zone and Tags it is every one of them (BT.Stats.AllRows); on the Grouped
-- chart, the people (`rows`). The pile of the rest has no name to match.
-- Kept for the census and the words, so the wheel does not search again.
function C.Search(view, census, rows, words)
	local mode = view.mode
	local s = view.searched
	if s and s.census == census and s.mode == mode and s.words == words and s.from == rows then
		return s.rows
	end
	local from = mode == "grouped" and rows or BT.Stats.AllRows(census, mode)
	local out = {}
	for _, r in ipairs(from) do
		if r.key ~= BT.Stats.OTHER then
			local name = mode == "grouped" and r.name or rowLabel(mode, r.key)
			if type(name) == "string" and name:lower():find(words, 1, true) then
				out[#out + 1] = r
			end
		end
	end
	view.searched = { census = census, mode = mode, words = words, from = rows, rows = out }
	return out
end

-- The scroller laid behind the rows and told how many people there are; gives
-- back how many of them are above the first row. It rests on whole rows.
function C.GroupedFirst(view, n, rowsTop)
	local sc = view.groupScroll
	view.painting = true
	sc:ClearAllPoints()
	sc:SetPoint("TOPLEFT", 0, rowsTop)
	sc:SetPoint("TOPRIGHT", 0, rowsTop)
	local fit = view.fit or ROWS
	sc:SetHeight(fit * ROW_H)
	sc:Show()
	sc:SetContentHeight(n * ROW_H)
	view.painting = nil
	return math.max(0, math.min(n - fit, math.floor((sc.offset or 0) / ROW_H + 0.5)))
end

-- How many rows the column holds from `rowsTop` down, leaving the footer its
-- line: never fewer than ROWS (a window not laid out yet has no height), nor
-- more than were made.
function C.Fit(view, rowsTop)
	local h = BT.Pill.Number(view.GetHeight and view:GetHeight(), 0)
	local n = math.floor((h + rowsTop - FOOT_H) / ROW_H)
	view.fit = math.max(ROWS, math.min(MAX_ROWS, n))
	return view.fit
end

-- What a chart's rows are, one and many; the short charts have no count
-- worth saying until you search them
local NOUN = {
	class = { "class", "classes" }, race = { "race", "races" }, level = { "level range", "level ranges" },
	guild = { "guild", "guilds", true }, zone = { "zone", "zones", true }, tag = { "tag", "tags", true },
	grouped = { "person", "people", true },
}

-- how many guilds, zones or tags a chart has by name: not the pile of the
-- rest, nor the rows for a gap in the book. Counted once for a census.
function C.Named(census, mode, rows)
	if mode == "grouped" then
		return #rows
	end
	local counts = census.counts and census.counts[mode]
	if not counts then
		return #rows
	end
	census.named = census.named or {}
	if not census.named[mode] then
		local S, n = BT.Stats, 0
		for key in pairs(counts) do
			if key ~= S.UNGUILDED and key ~= S.UNKNOWN and key ~= S.OTHER then
				n = n + 1
			end
		end
		census.named[mode] = n
	end
	return census.named[mode]
end

-- "1,204 guilds", or with a search `5 guilds match "olympus"`; nil when there
-- is nothing to say
function C.CountLine(mode, n, words)
	local noun = NOUN[mode]
	if not noun then
		return nil
	end
	if words and words ~= "" then
		if n == 0 then
			return ('Nothing matches "%s".'):format(words)
		end
		return ('%s %s %s "%s"'):format(U.Commas(n), noun[n == 1 and 1 or 2], n == 1 and "matches" or "match", words)
	end
	if not noun[3] or n == 0 then
		return nil
	end
	return ("%s %s"):format(U.Commas(n), noun[n == 1 and 1 or 2])
end

-- the line under the people: how many, or why there are none
function C.GroupedLine(n, filtering)
	if n == 0 then
		return filtering and "Nobody matches the filter."
			or "Nobody yet. A group counts after 5 minutes together, or in a dungeon."
	end
	return n == 1 and "1 person" or ("%s people"):format(U.Commas(n))
end

-- The rail's rows: a chart each, the one shown lit. Tags and Grouped are the
-- Ledger's, so only while the Ledger is on.
function C.PaintModes(view)
	if not view.rail then
		return
	end
	local entries = {}
	for _, m in ipairs(MODES) do
		if not m.ledger or BT.Enabled("ledger") then
			entries[#entries + 1] = { key = m.key, label = m.label, chosen = m.key == view.mode }
		elseif view.mode == m.key then
			view.mode = "class"
			entries[1].chosen = true
		end
	end
	BT.Book.RailRows(view.rail, entries)
	for k in pairs(view.modeButtons) do
		view.modeButtons[k] = nil
	end
	for i, e in ipairs(entries) do
		local r = view.rail.rows[i]
		r.pressed = e.chosen
		view.modeButtons[e.key] = r
	end
end

-- what the line under the bars calls a chart's gap in the book: "Race
-- unknown for 70", so the guild chart's gap is not read as its No guild row
C.NOTE = { class = "Class", race = "Race", level = "Level", guild = "Guild", zone = "Zone" }

-- the tiles, from the census: its count, both splits, and the level columns
function C.PaintTiles(view, census)
	local accent = BT.Widgets.ACCENT
	local count = view.countTile
	count.num:SetText(U.Commas(census.book or 0))
	count.sub:SetText(("%s seen today"):format(U.Commas(census.today or 0)))

	-- each half says its share of those whose side (or sex) is on file -
	-- "94% Alliance" fits a half-tile where "27,353 Alliance" does not - and
	-- its card says how many, and how many are not known yet
	local function paintSplit(t, counts, chosen, words, noun)
		local total, known = counts.unknown or 0, 0
		for _, k in ipairs(t.keys) do
			total = total + (counts[k] or 0)
			known = known + (counts[k] or 0)
		end
		t.tip = function(card, k)
			local n = counts[k] or 0
			card:Header({ name = words[k]:gsub("^%l", string.upper), sub = U.Commas(n) })
			if (counts.unknown or 0) > 0 then
				card:Note(("%s of %s have a %s on file so far."):format(U.Commas(known), U.Commas(total), noun))
			end
			if n > 0 or chosen == k then
				card:Foot({ { "Click", chosen == k and "show everyone" or "show only these" } })
			end
		end
		-- THE BAR SPLITS THOSE ON FILE (Josh 2026-10-01: "Gender summary chart
		-- should show male vs female"): it was a share of everyone, so with
		-- most genders not yet known it was a sliver of male and female
		-- along an empty track, under words that said 41% and 59%
		local w = t.w - 18
		local x = 0
		for _, k in ipairs(t.keys) do
			local part = t.parts[k]
			local share = known > 0 and (counts[k] or 0) / known or 0
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", t.track, "TOPLEFT", x, 0)
			part:SetWidth(math.max(share * w, 1))
			part:SetShown(share > 0)
			part:SetAlpha((chosen == nil or chosen == k) and 1 or 0.3)
			x = x + share * w
		end
		local any = known > 0
		local function pct(k)
			return any and math.floor((counts[k] or 0) / known * 100 + 0.5) or 0
		end
		t.paint = function()
			for _, k in ipairs(t.keys) do
				local b = t.buttons[k]
				local n = counts[k] or 0
				b.live = n > 0 or chosen == k
				b.words:SetText(("%d%% %s"):format(pct(k), words[k]))
				-- A SIDE WITH NO ONE SAYS NOTHING (Josh 2026-11-07: "100%
				-- Alliance" ran into "0% Horde"). The bar shows it, and a
				-- click on it does nothing.
				b.words:SetShown(any and b.live)
				if chosen == k then
					b.words:SetTextColor(accent[1], accent[2], accent[3])
				elseif b.hovered and b.live then
					BT.Ink(b.words, "ink")
				else
					BT.Ink(b.words, "soft")
				end
			end
			-- and two that would still meet: the smaller share keeps its number
			local a, b = t.buttons[t.keys[1]].words, t.buttons[t.keys[2]].words
			if a:IsShown() and b:IsShown() then
				local wa, wb = width(a), width(b)
				if wa and wb and wa + wb + 8 > t.w - 18 then
					local small = pct(t.keys[1]) < pct(t.keys[2]) and t.keys[1] or t.keys[2]
					t.buttons[small].words:SetText(("%d%%"):format(pct(small)))
				end
			end
			t.none:SetShown(not any)
		end
		t.paint()
	end
	local sides = census.sides or {}
	paintSplit(view.sideTile, sides, view.faction ~= "all" and view.faction or nil,
		{ Alliance = "Alliance", Horde = "Horde" }, "faction")
	local sexes = census.sexes or {}
	paintSplit(view.sexTile, { [2] = sexes.male or 0, [3] = sexes.female or 0, unknown = sexes.unknown or 0 },
		view.sex ~= "all" and view.sex or nil, { [2] = "male", [3] = "female" }, "gender")

	-- the level columns, each as tall as its share of the tallest
	local most = 0
	for _, r in ipairs(census.level or {}) do
		if r.n > most then most = r.n end
	end
	local filtering = bandFilter(view) ~= nil
	for _, r in ipairs(census.level or {}) do
		local b = view.bandButtons[r.key]
		if b then
			local on = view.bands[r.key] == true
			b.n = r.n
			b.live = r.n > 0 or on
			b.bar:SetHeight(math.max(2, (most > 0 and r.n / most or 0) * 22))
			if r.n == 0 then
				b.bar:SetColorTexture(NONE[1], NONE[2], NONE[3], 0.6)
			elseif on then
				b.bar:SetColorTexture(accent[1], accent[2], accent[3], 1)
			else
				local cr, cg, cb = barColour()
				b.bar:SetColorTexture(cr, cg, cb, filtering and 0.45 or 1)
			end
		end
	end
end

-- THE FILTERS THAT ARE ON, AS CHIPS (the census redesign): each one named,
-- and a click on it lets it go. Right to left from the window's edge.
-- "Seen today", "Seen in the past 3 hours": the Stats' own words, capitalised
local SEEN_WORDS = {}
for key, as in pairs(BT.Stats.SEEN_AS) do
	SEEN_WORDS[key] = as:gsub("^%l", string.upper)
end
function C.Chips(view)
	local out = {}
	if view.faction and view.faction ~= "all" then
		out[#out + 1] = { text = view.faction, clear = function() view.faction = "all" end }
	end
	if view.sex and view.sex ~= "all" then
		out[#out + 1] = { text = C.SEX_WORD[view.sex] or "?", clear = function() view.sex = "all" end }
	end
	local bands = {}
	for _, b in ipairs(BT.Stats.BANDS) do
		if view.bands[b.key] then
			bands[#bands + 1] = (b.key:gsub("%-", "–"))
		end
	end
	if #bands > 0 then
		out[#out + 1] = { text = (#bands == 1 and "Level " or "Levels ") .. table.concat(bands, ", "),
			clear = function() view.bands = {} end }
	end
	if SEEN_WORDS[view.seen] then
		out[#out + 1] = { text = SEEN_WORDS[view.seen], clear = function() view.seen = "all" end }
	end
	if view.pick then
		out[#out + 1] = { text = rowLabel(view.pick.mode, view.pick.key), clear = function() view.pick = nil end }
	end
	return out
end

function C.PaintChips(view)
	local list = C.Chips(view)
	local x = 0
	for i = 1, math.max(#list, #view.chips) do
		local c = list[i]
		local b = view.chips[i]
		if c and not b then
			b = BT.Widgets.Button(view, "", 60, 18)
			b:SetScript("OnClick", function(self)
				if self.clear then
					self.clear()
					C.Refresh(view)
				end
			end)
			view.chips[i] = b
		end
		if c then
			b.clear = c.clear
			b.text = c.text
			b:SetLabel(c.text .. "  |cff8a9894x|r")
			b:SetPressed(true)
			local w = BT.Pill.Width(b.label, c.text .. "  x", 8)
			b:SetWidth(w)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", view, "TOPLEFT", x, CAP_Y + 1)
			b:Show()
			x = x + w + 4
		elseif b then
			b.clear, b.text = nil, nil
			b:Hide()
		end
	end
	return #list
end
