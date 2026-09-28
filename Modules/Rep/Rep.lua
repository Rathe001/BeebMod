-- Reputation: the faction you are watching, and how long the rest of the
-- standing will take (Josh 2026-09-22).
--
-- The same line and thin bar as Experience, for whichever faction is ticked
-- "Show as Experience Bar" in the reputation panel - and, like the client's
-- own bar, not there at all when none is. The bar is the standing's colour,
-- the one the reputation panel paints it.
--
-- THE PACE IS PER FACTION, for this session: watch another faction and back,
-- and the first one's pace is still there. A /reload carries the session on;
-- a login starts a new one.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Rep/Rep.lua")

local U = BT.Util

local M = BT.Module({
	key = "rep",
	feature = "dock",
	onPage = "progress",
	title = "Reputation",
	blurb = "The faction you watch, and time to the next standing",
	order = 37.5,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

local TEXT_H = 16
local BAR_H = 4
local LINE_H = TEXT_H + BAR_H + 9
local INSET = 6
local EVERY = 10
-- exalted is the top of the ladder: nothing comes after it
local TOP = 8

local WORDS = "|cff8a9894%s|r"

-- the client's own standing names and colours, and plain ones where it has none
local NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local COLOURS = {
	{ 0.80, 0.30, 0.22 }, { 0.80, 0.30, 0.22 }, { 0.75, 0.27, 0 }, { 0.90, 0.70, 0 },
	{ 0, 0.60, 0.10 }, { 0, 0.60, 0.10 }, { 0, 0.60, 0.10 }, { 0, 0.60, 0.10 },
}

function M.StandingName(reaction)
	local own = _G["FACTION_STANDING_LABEL" .. tostring(reaction)]
	if type(own) == "string" and own ~= "" then
		return own
	end
	return NAMES[reaction] or "?"
end

function M.StandingColour(reaction)
	local own = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
	if type(own) == "table" and own.r then
		return { own.r, own.g, own.b }
	end
	return COLOURS[reaction] or COLOURS[4]
end

-- ---------------------------------------------------------------------------
-- What the client says
-- ---------------------------------------------------------------------------

-- The watched faction, or nil when nothing is watched: its name, its
-- standing, how far through the standing (cur of max), and its total value,
-- which only ever goes up with gains - across standings too.
function M.Read()
	local r = _G.C_Reputation
	if r and type(r.GetWatchedFactionData) == "function" then
		local ok, d = pcall(r.GetWatchedFactionData)
		if ok and type(d) == "table" and d.name and d.name ~= "" then
			local low = d.currentReactionThreshold or 0
			local high = d.nextReactionThreshold or low
			local value = d.currentStanding or low
			return {
				name = d.name, reaction = d.reaction or 4, value = value,
				cur = value - low, max = high - low, id = d.factionID,
			}
		end
	end
	if type(_G.GetWatchedFactionInfo) == "function" then
		local ok, name, reaction, low, high, value, id = pcall(_G.GetWatchedFactionInfo)
		if ok and type(name) == "string" and name ~= "" then
			low, high, value = low or 0, high or 0, value or 0
			return {
				name = name, reaction = reaction or 4, value = value,
				cur = value - low, max = high - low, id = id,
			}
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The session
-- ---------------------------------------------------------------------------

local function store()
	if not BT.settings then
		return nil
	end
	BT.settings.rep = BT.settings.rep or {}
	return BT.settings.rep
end

-- A new session on a login, the same one on a reload (Core/Session.lua).
function M.Start(initial, reloading)
	local all = store()
	if not all then
		return nil
	end
	local s = BT.Session.Open(all, initial, reloading, function(now)
		return { start = now, factions = {} }
	end)
	s.factions = s.factions or {}
	M.session = s
	M.Gain()
	return s
end

-- The faction's own record in this session, begun the first time it is seen.
local function track(f)
	local s = M.session
	if not (s and f) then
		return nil
	end
	local key = f.name
	local t = s.factions[key]
	if not t then
		t = { since = U.Now(), gained = 0, value = f.value }
		s.factions[key] = t
	end
	return t
end

-- Every change: what went up since last time is gained. The total value
-- carries on across standings, so a new standing is no special case.
function M.Gain()
	local f = M.Read()
	local t = track(f)
	if t then
		local up = f.value - (t.value or f.value)
		if up > 0 then
			t.gained = (t.gained or 0) + up
		end
		t.value = f.value
		M.session.last = U.Now()
	end
	M.Update()
end

-- reputation per hour for a faction this session, or nil while it is too soon
function M.Rate(t, now)
	if not t then
		return nil
	end
	return BT.Session.Rate(t.gained, t.since, now)
end

local duration = BT.Session.Duration

local function big(n)
	n = math.floor(n or 0)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, s = pcall(BreakUpLargeNumbers, n)
		if ok and type(s) == "string" then
			return s
		end
	end
	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

function M.Lines(f, rate)
	local left = ("%s %s"):format(f.name, WORDS:format("· " .. M.StandingName(f.reaction)))
	if f.reaction >= TOP or f.max <= 0 then
		return left, ""
	end
	local nextName = M.StandingName(f.reaction + 1)
	local togo = math.max(0, f.max - f.cur)
	local right = ""
	if rate and rate > 0 then
		right = ("%s %s"):format(duration(togo * 3600 / rate), WORDS:format("to " .. nextName))
	end
	-- NO AMOUNT BEFORE THERE IS A PACE (Josh 2026-09-22). "2,807 to Honored"
	-- took half the line from the faction's name, and the hover says it
	-- anyway. Until there is a time to give, the name has the whole line.
	return left, right
end

function M.Update()
	if not M.frame then
		return
	end
	local f = M.Read()
	-- NOTHING WATCHED, NOTHING SHOWN - as with the client's own bar
	local want = f ~= nil and BT.Enabled("rep")
	if want ~= M.shownFor then
		M.shownFor = want
		M.frame:SetShown(want)
		BT.Bar.Relayout()
	end
	if not f then
		return
	end
	local t = M.session and M.session.factions and M.session.factions[f.name]
	local left, right = M.Lines(f, M.Rate(t))
	M.text:SetText(left)
	M.eta:SetText(right)

	local w = BT.Pill.Number(M.frame:GetWidth(), 0) - INSET * 2
	if w <= 0 then
		return
	end
	local c = M.StandingColour(f.reaction)
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	BT.Bar.BandColor(M.frame, c)
	local done = (f.reaction >= TOP or f.max <= 0) and 1 or math.min(1, f.cur / f.max)
	-- a texture of no width is drawn as a whole one, so an empty bar is hidden
	M.fill:SetShown(done > 0)
	M.fill:SetWidth(math.max(1, w * done))
end

-- (Josh 2026-09-27, the dock's tooltips redrawn) the watched faction's
-- standing and how long the next one takes at your pace, then every faction
-- that moved this session
function M.Tip()
	local f = M.Read()
	if not (f and BT.Tip) then
		return
	end
	local session = M.session and M.session.factions and M.session.factions[f.name]
	local rate = M.Rate(session)
	BT.Tip.Show(M.frame, { build = function(t)
		local c = M.StandingColour(f.reaction)
		t:Header({ name = f.name, sub = "The faction you watch", pill = M.StandingName(f.reaction), pillState = c })
		local top = f.reaction >= TOP or f.max <= 0
		if top then
			t:Headline(M.StandingName(f.reaction), nil, c, true)
		else
			t:Headline(big(f.cur), "/ " .. big(f.max))
			t:Bar(f.cur / f.max, c)
			local togo = f.max - f.cur
			local secs = rate and rate > 0 and togo * 3600 / rate or nil
			t:Scale(("%s to %s"):format(big(togo), M.StandingName(f.reaction + 1)),
				secs and ("about %s"):format(duration(secs)) or nil)
		end
		local moved = {}
		for name, entry in pairs(M.session and M.session.factions or {}) do
			if (entry.gained or 0) ~= 0 then
				moved[#moved + 1] = { name = name, gained = entry.gained }
			end
		end
		table.sort(moved, function(a, b) return a.gained > b.gained end)
		if #moved > 0 then
			t:Section("This session")
			for i = 1, math.min(5, #moved) do
				local m = moved[i]
				t:Row(m.name, (m.gained > 0 and "+" or "-") .. big(math.abs(m.gained)), m.gained > 0 and "good" or "bad")
			end
		end
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.Section("rep", 7)
	M.frame.kind = "meter"
	M.frame.wantHeight = LINE_H
	M.frame:SetHeight(LINE_H)
	M.text = BT.Widgets.Label(M.frame, "", "small")
	M.text:SetPoint("TOPLEFT", M.frame, "TOPLEFT", INSET, -3)
	M.text:SetJustifyH("LEFT")
	M.eta = BT.Widgets.Label(M.frame, "", "small")
	M.eta:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -3)
	M.eta:SetJustifyH("RIGHT")
	-- A LONG NAME STOPS SHORT OF THE RIGHT-HAND TEXT (Josh 2026-09-22):
	-- "Gnomeregan Exiles · Friendly" ran straight into "2,807 to Honored".
	-- The left text ends where the right one begins, and is cut short with
	-- an ellipsis rather than drawn over it.
	M.text:SetPoint("TOPRIGHT", M.eta, "TOPLEFT", -8, 0)
	M.text:SetHeight(TEXT_H - 2)
	M.text:SetWordWrap(false)
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPLEFT", M.frame, "TOPLEFT", INSET, -(TEXT_H + 3))
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -(TEXT_H + 3))
	M.track:SetHeight(BAR_H)
	M.fill = M.frame:CreateTexture(nil, "ARTWORK")
	M.fill:SetPoint("TOPLEFT", M.track, "TOPLEFT", 0, 0)
	M.fill:SetHeight(BAR_H)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	M.frame:EnableMouse(true)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.frame
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, initial, reloading)
	if not BT.Enabled("rep") then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, initial, reloading)
	else
		-- a gain, or a different faction ticked: either way, read it again
		M.Gain()
	end
end)

-- THE CLIENT'S OWN BAR, PUT AWAY WHILE THIS ONE IS UP (Josh 2026-09-22): a
-- switch on this tab, on unless you turn it off. See Core/StatusBars.lua.
function M.HideClient()
	return not (BT.settings and BT.settings.hideClientRep == false)
end

function M.SetHideClient(on)
	BT.EnsureBound()
	BT.settings.hideClientRep = on and true or false
	BT.StatusBars.Set("rep", BT.Enabled("rep") and on)
end

function M.Show(on)
	-- switched off, the client's bar comes back whatever the switch says
	BT.StatusBars.Set("rep", on and M.HideClient())
	local frame = M.Build()
	if on then
		M.shownFor = nil
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("rep") then
					M.Update()
				end
			end)
		end
	else
		frame:Hide()
		if M.ticker then
			M.ticker:Cancel()
			M.ticker = nil
		end
	end
	BT.Bar.Relayout()
end

function M:OnEnable()
	M.Show(true)
	-- switched on mid-session (Core/Session.lua)
	BT.Session.Ensure(M)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("The faction you watch, and roughly how long the rest of its standing will take. Watch a faction by ticking \"Show as Experience Bar\" in the reputation panel.")
	page:Note("With no faction watched there is no line, the same as the game's own bar.", true)
	local r = BT.Widgets.SwitchRow(page:Section("The game's own"), "Hide the game's bar",
		"Hides the game's reputation bar while this one shows",
		function() return M.HideClient() and true or false end,
		function(on) M.SetHideClient(on) end)
	self.hideSwitch = r.switch
	page:Layout()
end

function M:RefreshTab()
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

BT.Command("rep", function()
	local f = M.Read()
	if not f then
		U.Print("Reputation: no faction watched. Tick \"Show as Experience Bar\" in the reputation panel to watch one.")
		return
	end
	local t = M.session and M.session.factions and M.session.factions[f.name]
	local left, right = M.Lines(f, M.Rate(t))
	U.Print("Reputation: " .. left .. (right ~= "" and ("  ·  " .. right) or ""))
end, "print the faction you watch, and time to the next standing", "rep")
