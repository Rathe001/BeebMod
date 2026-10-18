-- The Ravenholdt Ledger's window: the Census's charts, the Ledger's search
-- and its commendations, a tab each (Josh 2026-09-22; one window since
-- 2026-10-04; the journals' window since 2026-10-05).
--
-- THE CENSUS JOINS THE LEDGER (Josh 2026-10-04: "I agree - let's update the
-- settings to reflect this"). The charts had this window to themselves; the
-- Ledger's search sat under its settings. Now both are read here: Charts,
-- and Find people. The charts are the Census module's, built into their page
-- the first time they show; the search is Modules/Ledger/Find.lua's, built
-- the first time it is wanted.
--
-- THE EXPEDITION'S SISTER (Josh 2026-10-04: "Ledger and expedition should
-- have similar experiences"; the "Sister journals" canvas, locked
-- 2026-10-05). The window is the journals' own (UI/Book.lua): your rank
-- under the tabs, a rail down each page's left and a toolbar over its column, and a
-- third tab, Commendations, the same page as the Expedition's.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/CensusWindow.lua")

local C = {}
BT.CensusWindow = C

local Bk = BT.Book

local frame
-- the frame that counts a slice a frame (C.Count)
local counter
-- what the Commendations page shows: a group, and all, earned or to do
C.ui = { pick = "all", show = "all" }

-- (Josh 2026-10-01: "Change this to 'Note: Only counts characters you've
-- personally seen'", with "Note:" in a highlight: the window's accent)
C.NOTE = "Only counts characters you've personally seen"
function C.NoteText()
	local a = BT.Widgets.ACCENT
	local function byte(v)
		return math.floor(v * 255 + 0.5)
	end
	return ("|cff%02x%02x%02xNote:|r %s"):format(byte(a[1]), byte(a[2]), byte(a[3]), C.NOTE)
end

local function feature()
	return BT.Feature and BT.Feature("ledger")
end

function C.Build()
	if frame then
		return frame
	end
	local f = feature()
	frame = Bk.Window({
		name = "BeebModCensus", title = f and f.title or "Ravenholdt Ledger",
		colour = f and f.color,
		tabs = { { "charts", "Charts" }, { "find", "Find people" }, { "comm", "Commendations" } },
		point = { "CENTER", 60, -10 },
		onTab = function(key)
			C.Show(key)
		end,
		onRank = function()
			C.Show("comm")
		end,
	})

	-- THE CHARTS: the six charts on the rail, the note and Seen on the
	-- toolbar, the tiles and bars in the column
	local charts = Bk.Page(frame, "charts")
	frame.chartsShell = { rail = Bk.Rail(charts, 0, { head = "Chart" }), toolbar = Bk.Toolbar(charts, 0) }
	-- ONLY WHO YOU HAVE COME ACROSS (Josh 2026-10-01: "put a note at the top
	-- explaining that census data is only built off of players you have
	-- personally seen"): a count of 29,398 reads like the realm's
	-- population, and it is the characters this copy of BeebMod has met
	frame.note = frame.chartsShell.toolbar:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.note:SetPoint("LEFT", 2, 0)
	frame.note:SetJustifyH("LEFT")
	frame.note:SetText(C.NoteText())
	frame.body = Bk.Column(charts, 0)

	-- FIND PEOPLE: who to show on the rail, the search on the toolbar
	local find = Bk.Page(frame, "find")
	frame.findShell = { rail = Bk.Rail(find, 0, { head = "Show" }), toolbar = Bk.Toolbar(find, 0) }
	frame.find = Bk.Column(find, 0)

	-- COMMENDATIONS: the Expedition's page, with the Ledger's in it
	frame.commendations = Bk.Commendations(frame, "comm", {
		onPick = function(key)
			C.ui.pick = key
			C.Refresh()
		end,
		onShow = function(key)
			C.ui.show = key
			C.Refresh()
		end,
	})

	-- Escape hides it without going through C.Hide, so the ticker stops here
	frame:HookScript("OnHide", function()
		if C.ticker then
			C.ticker:Cancel()
			C.ticker = nil
		end
		-- and a count still going stops with it (Josh 2026-09-30, review):
		-- it ran to the end for a window nobody could see, and opening the
		-- window again started a second beside it
		if counter then
			counter:SetScript("OnUpdate", nil)
		end
		-- THE OPENING COUNT TOO (2026-10-17, audit): the one the charts
		-- began (Chart.lua) went on at a few milliseconds a frame after the
		-- window shut
		local m = BT.GetModule("census")
		if m and m.view and BT.Census and BT.Census.Stop then
			BT.Census.Stop(m.view)
		end
	end)
	return frame
end

-- how many characters are in the realm's book, and how many were seen today -
-- counted by the census the charts were just drawn from, rather than by a
-- second walk of the whole book (Josh 2026-09-24)
local function counts()
	local m = BT.GetModule("census")
	local census = m and m.view and m.view.census
	-- the list's length, not a reading of every character in it (Josh
	-- 2026-09-29: opening the Census lagged)
	local L = BT.LedgerRanks
	local total = census and (census.book or census.total) or (L and L.characters) or 0
	return total, census and census.today
end

-- the header: the realm beside the title; your rank, or one previewed from
-- the Testing page, on the strip, with the book's count, today's and the points
local function header(points)
	local L = BT.LedgerRanks
	if not (frame and L and BT.DB) then
		return
	end
	if type(points) ~= "number" then
		points = L.Score()
	end
	local preview = BT.Dock and BT.Dock.preview and BT.Dock.preview.ledger
	local shown = preview and L.RANKS[preview] and L.RANKS[preview][1] or points
	local total, today = counts()
	local U = BT.Util
	Bk.SetHeader(frame, {
		subtitle = BT.scope and BT.scope.realm or "?",
		ranks = L.RANKS, badge = L.RankBadge, points = shown,
		stats = {
			{ "Characters", U.Commas(total) },
			{ "Seen today", today and U.Commas(today) or "-" },
			{ "Points", U.Commas(shown) },
		},
	})
	return shown
end

-- ---------------------------------------------------------------------------
-- The charts, counted while the window is open
-- ---------------------------------------------------------------------------

-- UP TO DATE WHILE IT IS OPEN (Josh 2026-09-22). While the charts are up, the
-- book is looked at every couple of seconds, and the charts and the count are
-- drawn again only if it has changed since.
local EVERY = 2

local function clock()
	return (type(GetTime) == "function" and GetTime()) or 0
end

-- a count still going: the window's own (C.Count), or the one the charts
-- began on opening or on a click (Chart.lua)
local function counting(view)
	if counter and counter:GetScript("OnUpdate") then
		return true
	end
	return view ~= nil and view.counting ~= nil
end

function C.Tick()
	if not (frame and frame:IsShown()) or C.Tab() ~= "charts" then
		return false
	end
	local rev = BT.DB and BT.DB.rev
	if rev == C.drawnAt then
		return false
	end
	-- NOT EVERY TICK IN A CITY (Josh 2026-09-23, audit): somebody is seen
	-- every second there, so every tick redrew - two walks of the whole book
	-- and a sort of every character's age. Drawn at once when opened, and
	-- again at most every ten seconds after that.
	local now = clock()
	if C.drawnTime and now - C.drawnTime < 10 then
		return false
	end
	local m = BT.GetModule("census")
	-- ONE COUNT AT A TIME (2026-10-17, audit): a big book takes longer than
	-- ten seconds at a few milliseconds a frame, and each new count threw
	-- the last away, so the charts never changed. The one going is left to
	-- finish, and the ten seconds start again from when it does.
	if counting(m and m.view) then
		C.drawnTime = now
		return false
	end
	C.drawnAt, C.drawnTime = rev, now
	if m and m.view then
		C.Count(m)
	end
	return true
end

-- A SLICE A FRAME (Josh 2026-09-24). Counted at once, the census of a book
-- of fourteen thousand was one long frame every ten seconds in a city. The
-- window's own redraws count it a slice a frame instead and draw when it is
-- done; opening it, or a click on a bracket, still draws at once.
function C.Counter()
	return counter
end

function C.Count(m)
	local view = m and m.view
	if not (view and BT.Stats and BT.Stats.CensusJob and BT.Census and BT.Census.Filter) then
		BT.CallHook(m, "Refresh")
		header()
		return false
	end
	local step = BT.Stats.CensusJob(BT.db, nil, BT.Census.Filter(view))
	if not (CreateFrame and C_Timer) then
		local census
		repeat
			census = step()
		until census
		BT.Census.Refresh(view, census)
		header()
		return true
	end
	counter = counter or CreateFrame("Frame")
	counter:SetScript("OnUpdate", function(self)
		-- a few milliseconds a frame, as a count you asked for (Chart.lua)
		local census = step(BT.Census.BUDGET)
		if census then
			self:SetScript("OnUpdate", nil)
			if frame and frame:IsShown() then
				BT.Census.Refresh(view, census)
				header()
			end
		end
	end)
	return true
end

-- the ticker stops with the window, however it was closed (Escape included)
local function stop()
	if C.ticker then
		C.ticker:Cancel()
		C.ticker = nil
	end
end

-- which tab is up: "charts", "find" or "comm"
function C.Tab()
	return C.tab or "charts"
end

-- the search built into its page, for the note panel to exist with the
-- window shut (Modules/Ledger/Find.lua, B.EnsureBuilt)
function C.BuildFind()
	C.Build()
	if not C.findBuilt and BT.Find and BT.Find.Build then
		C.findBuilt = true
		BT.Find.Build(frame.find, frame.findShell)
	end
	return frame.find
end

-- ---------------------------------------------------------------------------
-- Commendations
-- ---------------------------------------------------------------------------

-- "Earned 9/30/26", or "Earned" for one the Ledger had before it kept dates
local function earnedLine(it)
	local at = tonumber(it.at)
	if at and at > 0 and BT.Util.ShortDate then
		return ("Earned %s"):format(BT.Util.ShortDate(at))
	end
	return "Earned"
end

-- the groups the page shows: what each entry is worth, then the five groups
function C.Groups(c)
	local L = BT.LedgerRanks
	local big = Bk.Big
	local out = {
		{ key = "entries", title = "Entries", list = {
			{ id = "entries:characters", title = "Characters", text = "1 point for every 100 you record",
				need = 1, have = 1, right = ("%s recorded"):format(big(c.characters)) },
			{ id = "entries:notes", title = "Notes", text = "2 points for each note",
				need = 1, have = 1, right = ("%s written"):format(big(c.notes)) },
			{ id = "entries:tags", title = "Tags", text = "1 point for each tag",
				need = 1, have = 1, right = ("%s given"):format(big(c.tags)) },
		} },
	}
	local byGroup = {}
	for _, g in ipairs(L.GROUPS) do
		byGroup[g.key] = { key = g.key, title = g.title, list = {}, done = 0 }
	end
	for _, a in ipairs(L.List(c)) do
		local g = byGroup[a.group]
		if g then
			a.at = L.EarnedAt(a.id)
			g.list[#g.list + 1] = a
			if a.have >= a.need then
				g.done = g.done + 1
			end
		end
	end
	for _, g in ipairs(L.GROUPS) do
		out[#out + 1] = byGroup[g.key]
	end
	return out
end

local function drawCommendations(points)
	local L = BT.LedgerRanks
	local total, _, c, characters, entries = L.Score()
	local groups = C.Groups(c)
	-- the entries' tally says its points, as the Expedition's unique kills do
	-- ("1 point", not "1 points": 2026-10-17, audit)
	local entryPoints = characters + entries
	groups[1].count = ("%s %s"):format(Bk.Big(entryPoints), entryPoints == 1 and "point" or "points")
	local f = feature()
	local focus, scroll = C.focus, C.scrollToFocus
	C.scrollToFocus = nil
	return Bk.DrawCommendations(frame.commendations, {
		ranks = L.RANKS, badge = L.RankBadge, points = points or total, colour = f and f.color,
		groups = groups, pick = C.ui.pick, show = C.ui.show,
		sums = {
			{ "Characters", characters }, { "Notes and tags", entries },
			{ "Commendations", total - characters - entries }, { "Total", total },
		},
		earnedLine = earnedLine, focus = focus, scrollToFocus = scroll,
	})
end

-- the header and the open page drawn again: the book changed, or a preview
function C.Refresh()
	if not (frame and frame:IsShown()) then
		return false
	end
	local shown = header()
	if C.Tab() == "comm" then
		drawCommendations(shown)
	elseif C.Tab() == "find" and BT.Find and BT.Find.Refresh then
		BT.Find.Refresh()
	end
	return true
end

-- the Ledger earned something while it is open: drawn once for a burst
function C.Changed()
	if not (frame and frame:IsShown()) or C.pending then
		return
	end
	C.pending = true
	local function go()
		C.pending = nil
		C.Refresh()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, go)
	else
		go()
	end
end

-- A NOTICE OPENS ITS COMMENDATION (the Expedition's since 2026-09-29): the
-- Commendations page, everything shown, the commendation's own group picked
-- on the rail, and its tile scrolled to and outlined in gold
function C.ShowCommendation(id)
	local L = BT.LedgerRanks
	local pick = "all"
	if L then
		for _, a in ipairs(L.List()) do
			if a.id == id then
				pick = a.group
			end
		end
	end
	C.ui.pick, C.ui.show = pick, "all"
	C.focus, C.scrollToFocus = id, true
	return C.Show("comm")
end

-- ---------------------------------------------------------------------------
-- Opening and closing
-- ---------------------------------------------------------------------------

-- OPEN ON A TAB: "charts" (the default), "find" or "comm". The charts need
-- you to be recording everyone you see (the Census); without it, the window
-- opens on Find, and there is no Charts tab.
function C.Show(tab)
	local m = BT.GetModule("census")
	local charts = m ~= nil and BT.Enabled("census")
	local find = BT.Enabled("ledger")
	if not (charts or find) then
		return false
	end
	tab = tab or C.tab or "charts"
	if tab == "charts" and not charts then
		tab = "find"
	elseif tab == "find" and not find then
		tab = "charts"
	end
	BT.EnsureBound()
	C.Build()
	C.tab = tab
	-- a tab whose part is off is not there, and the tabs close up
	local buttons = frame.tabs.buttons
	buttons[1]:SetShown(charts)
	buttons[2]:SetShown(find)
	frame.tabs:Relayout()
	Bk.ShowPage(frame, tab)
	if tab ~= "comm" then
		C.focus = nil
	end
	if tab ~= "charts" then
		stop()
		if counter then
			counter:SetScript("OnUpdate", nil)
		end
	end
	frame:Show()
	frame:Raise()
	header()
	if tab == "find" then
		C.BuildFind()
		if BT.Find and BT.Find.Refresh then
			BT.Find.Refresh()
		end
		return true
	elseif tab == "comm" then
		drawCommendations(header())
		return true
	end
	if not m.view then
		BT.CallHook(m, "BuildTab", frame.body, frame.chartsShell)
	end
	BT.CallHook(m, "ShowTab")
	header()
	-- COUNTED ON OPENING (2026-10-17, audit): ShowTab just counted, so the
	-- window's own count waits its ten seconds. It began two seconds later,
	-- beside the first.
	C.drawnAt, C.drawnTime = BT.DB and BT.DB.rev, clock()
	if not C.ticker and C_Timer and C_Timer.NewTicker then
		C.ticker = C_Timer.NewTicker(EVERY, C.Tick)
	end
	return true
end

function C.Hide()
	stop()
	if frame then
		frame:Hide()
	end
end

function C.IsShown()
	return frame and frame:IsShown() and true or false
end

function C.Toggle(tab)
	if C.IsShown() and (not tab or tab == C.Tab()) then
		C.Hide()
		return false
	end
	return C.Show(tab)
end

-- the tests reach in here
function C.Frame() return frame end
