-- The Census, in a window of its own (Josh 2026-09-22).
--
-- The main window's rail is for what can appear on the right panel, and the
-- Census never does: it is something you open to read. So it has its own
-- window, opened from the chart icon in the panel's header (or /bt census),
-- in the same surface as everything else. The charts themselves are the
-- Census module's, built into it the first time it opens.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/CensusWindow.lua")

local C = {}
BT.CensusWindow = C

local PAD, TITLE_H = 14, 40
-- the line under the title that says where the census comes from
local NOTE_H = 22
local WIDTH, HEIGHT = 640, 500

local frame
-- the frame that counts a slice a frame (C.Count)
local counter

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

function C.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "BeebModCensus", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	-- by its top, where it was when centred: its height follows its rows
	-- (Chart.lua), and the top stays put while the bottom moves
	frame:SetPoint("TOP", UIParent, "TOP", 60, -150)
	frame:SetFrameStrata("HIGH")
	-- ONE WINDOW IN FRONT OF THE OTHER, NOT THROUGH IT (Josh 2026-09-22). This
	-- and the main window share a strata and a frame level, so opened together
	-- their contents interleaved - the charts drawn through the settings. A
	-- top-level window comes to the front when clicked, and each is raised
	-- when it opens.
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	-- moved a pixel at a time, an eighth clear of a tie (UI/Widgets.lua)
	BT.Widgets.PixelDrag(frame)
	frame:SetClampedToScreen(true)
	-- solid, as the main window is: a window you read, not a panel to see
	-- the world through
	BT.Widgets.Panel(frame, BT.Widgets.SOLID)
	tinsert(UISpecialFrames, "BeebModCensus") -- escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD + 4, -PAD)
	frame.title:SetText("Census")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

	frame.close = BT.Widgets.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() C.Hide() end)

	BT.Widgets.Divider(frame, PAD, -TITLE_H)

	-- ONLY WHO YOU HAVE COME ACROSS (Josh 2026-10-01: "put a note at the top
	-- explaining that census data is only built off of players you have
	-- personally seen"): a count of 29,398 reads like the realm's
	-- population, and it is the characters this copy of BeebMod has met
	frame.note = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.note:SetPoint("TOPLEFT", PAD + 4, -TITLE_H - 10)
	frame.note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD - 4, -TITLE_H - 10)
	frame.note:SetJustifyH("LEFT")
	frame.note:SetText(C.NoteText())

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetPoint("TOPLEFT", PAD, -TITLE_H - 10 - NOTE_H)
	frame.body:SetPoint("BOTTOMRIGHT", -PAD, PAD)

	-- Escape hides it without going through C.Hide, so the ticker stops here
	frame:SetScript("OnHide", function()
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
	end)

	frame:Hide()
	return frame
end

-- the realm, the side and how many are in the book, as the main window says it
-- - counted by the census the charts were just drawn from, rather than by a
-- second walk of the whole book (Josh 2026-09-24)
local function subtitle()
	if not (frame and BT.DB and BT.DB.Stats) then
		return
	end
	local m = BT.GetModule("census")
	local census = m and m.view and m.view.census
	-- the list's length, not a reading of every character in it (Josh
	-- 2026-09-29: opening the Census lagged)
	local total = census and (census.book or census.total) or (BT.DB.Count(BT.db))
	-- the realm's: its book holds both sides, and the Faction row filters them
	frame.subtitle:SetText(("%s · %s characters"):format(BT.scope and BT.scope.realm or "?", BT.Util.Commas(total)))
end

-- UP TO DATE WHILE IT IS OPEN (Josh 2026-09-22). As a tab of the main window
-- the charts were drawn when the tab was opened; in a window of their own
-- nothing drew them again, and the numbers only moved if you closed it and
-- opened it. While it is up, the book is looked at every couple of seconds,
-- and the charts and the count are drawn again only if it has changed since.
local EVERY = 2

function C.Tick()
	if not (frame and frame:IsShown()) then
		return false
	end
	-- kept still while it is open, if you would rather (Josh 2026-09-24)
	if BT.settings and BT.settings.censusLive == false then
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
	local now = (type(GetTime) == "function" and GetTime()) or 0
	if C.drawnTime and now - C.drawnTime < 10 then
		return false
	end
	C.drawnAt, C.drawnTime = rev, now
	local m = BT.GetModule("census")
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
		subtitle()
		return false
	end
	local step = BT.Stats.CensusJob(BT.db, nil, BT.Census.Filter(view))
	if not (CreateFrame and C_Timer) then
		local census
		repeat
			census = step()
		until census
		BT.Census.Refresh(view, census)
		subtitle()
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
				subtitle()
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

function C.Show()
	local m = BT.GetModule("census")
	if not (m and BT.Enabled("census")) then
		return false
	end
	BT.EnsureBound()
	C.Build()
	if not m.view then
		BT.CallHook(m, "BuildTab", frame.body)
	end
	-- AS TALL AS ITS ROWS (Josh 2026-09-30, the census redesign): the chart
	-- says how much room it took, and the window fits round it
	if m.view and not m.view.onHeight then
		m.view.onHeight = function(h)
			frame:SetHeight(TITLE_H + 10 + NOTE_H + h + PAD)
		end
		if m.view.height then
			m.view.onHeight(m.view.height)
		end
	end
	frame:Show()
	frame:Raise()
	BT.CallHook(m, "ShowTab")
	subtitle()
	C.drawnAt, C.drawnTime = BT.DB and BT.DB.rev, nil
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

function C.Toggle()
	if C.IsShown() then
		C.Hide()
		return false
	end
	return C.Show()
end

-- the tests reach in here
function C.Frame() return frame end
