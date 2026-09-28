-- Experience: where you are in the level, and how long the rest will take
-- (Josh 2026-09-22).
--
-- One line of the dock and a thin bar under it. The line says the level and
-- how far through it you are, and roughly how long until the next one at the
-- pace of this session; the bar shows the same, with rested experience as a
-- paler stretch ahead of it. Point at it for the numbers.
--
-- THE PACE IS THIS SESSION'S, like the gold per hour: a login starts it, a
-- /reload carries it on, and a level gained along the way is counted whole
-- rather than read as the bar going backwards. At the level cap there is
-- nothing to say, so the line is not there.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/XP/XP.lua")

local U = BT.Util

local M = BT.Module({
	key = "xp",
	feature = "dock",
	onPage = "progress",
	title = "Experience",
	blurb = "The bar, and time to level",
	order = 37,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

local TEXT_H = 16
local BAR_H = 4
-- 3 above the text, 3 between it and the bar, and 6 under the bar: the bar
-- sat on the line below it with 3 (Josh 2026-09-22)
local LINE_H = TEXT_H + BAR_H + 9
local INSET = 6
local EVERY = 10

local WORDS = "|cff8a9894%s|r"

-- ---------------------------------------------------------------------------
-- What the client says
-- ---------------------------------------------------------------------------

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	return ok and v or nil
end

-- level, experience into it, experience the level needs, rested on top
function M.Read()
	local level = call(UnitLevel, "player") or 0
	local cur = call(UnitXP, "player") or 0
	local max = call(UnitXPMax, "player") or 0
	local rested = call(GetXPExhaustion) or 0
	return level, cur, max, rested
end

-- at the cap there is no bar: the client either says what the cap is, or the
-- level needs no experience at all
function M.AtCap(level, max)
	local cap = call(GetMaxPlayerLevel)
	if cap and level and level >= cap then
		return true
	end
	return (max or 0) <= 0
end

-- ---------------------------------------------------------------------------
-- The session
-- ---------------------------------------------------------------------------

local function store()
	if not BT.settings then
		return nil
	end
	BT.settings.xp = BT.settings.xp or {}
	return BT.settings.xp
end

-- A new session on a login, the same one on a reload (Core/Session.lua).
function M.Start(initial, reloading)
	local all = store()
	if not all then
		return nil
	end
	M.session = BT.Session.Open(all, initial, reloading, function(now)
		return { start = now, gained = 0 }
	end)
	M.level, M.cur, M.max = M.Read()
	M.Update()
	return M.session
end

-- Every change to the bar. A level gained in between is the rest of the old
-- level plus what is on the new one - never a negative number.
function M.Gain()
	local s = M.session
	if not s then
		return
	end
	local level, cur, max = M.Read()
	local was, wasCur, wasMax = M.level or level, M.cur or cur, M.max or max
	local gained
	if level > was then
		gained = math.max(0, wasMax - wasCur) + cur
	else
		gained = cur - wasCur
	end
	if gained > 0 then
		s.gained = (s.gained or 0) + gained
	end
	M.level, M.cur, M.max = level, cur, max
	s.last = U.Now()
	M.Update()
end

-- experience per hour this session, or nil while there is too little time
function M.Rate(s, now)
	s = s or M.session
	if not s then
		return nil
	end
	return BT.Session.Rate(s.gained, s.start, now)
end

-- seconds to the next level at that pace, or nil if there is no pace yet
function M.ToLevel(cur, max, rate)
	if not rate or rate <= 0 then
		return nil
	end
	return math.max(0, max - cur) * 3600 / rate
end

local duration = BT.Session.Duration
M.Duration = duration

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

-- 12,345: the client's own thousands separator where it has one
local function big(n)
	n = math.floor(n or 0)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, s = pcall(BreakUpLargeNumbers, n)
		if ok and type(s) == "string" then
			return s
		end
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
M.Big = big

function M.Lines(level, cur, max, rate)
	local pct = max > 0 and math.floor(cur / max * 100) or 0
	local left = ("Level %d %s"):format(level, WORDS:format(("· %d%%"):format(pct)))
	local secs = M.ToLevel(cur, max, rate)
	-- ONE GRAMMAR WITH REPUTATION (Josh 2026-09-22, the panel redesign): the
	-- right side is a time, and only once the session has a pace. What is
	-- left in experience is on the hover.
	local right = ""
	if secs then
		right = ("%s %s"):format(duration(secs), WORDS:format(("to %d"):format(level + 1)))
	end
	return left, right
end

function M.Update()
	if not M.frame then
		return
	end
	local level, cur, max, rested = M.Read()
	local cap = M.AtCap(level, max)
	-- at the cap the line goes, and the dock closes the gap
	if cap ~= M.hiddenAtCap then
		M.hiddenAtCap = cap
		M.frame:SetShown(not cap and BT.Enabled("xp"))
		BT.Bar.Relayout()
	end
	if cap then
		return
	end
	local left, right = M.Lines(level, cur, max, M.Rate())
	M.text:SetText(left)
	M.eta:SetText(right)

	local w = BT.Pill.Number(M.frame:GetWidth(), 0) - INSET * 2
	if w <= 0 then
		return
	end
	local a = BT.Widgets.ACCENT
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	BT.Bar.BandColor(M.frame, a)
	M.rested:SetColorTexture(a[1], a[2], a[3], 0.30)
	local done = max > 0 and math.min(1, cur / max) or 0
	local ahead = max > 0 and math.min(1 - done, (rested or 0) / max) or 0
	-- a texture of no width is drawn as a whole one, so an empty part is hidden
	M.fill:SetShown(done > 0)
	M.fill:SetWidth(math.max(1, w * done))
	M.rested:SetShown(ahead > 0)
	M.rested:SetWidth(math.max(1, w * ahead))
end

function M.Tip()
	if not BT.Tip then
		return
	end
	local level, cur, max, rested = M.Read()
	local s = M.session
	local rate = M.Rate()
	-- (Josh 2026-09-27, the dock's tooltips redrawn) how far through the
	-- level, rested drawn on the bar, and how long the rest takes at your pace
	BT.Tip.Show(M.frame, { build = function(t)
		local className = UnitClass and select(1, UnitClass("player")) or nil
		local pct = max > 0 and math.floor(cur / max * 100) or 0
		t:Header({ name = "Experience", sub = ("Level %d%s"):format(level, className and (" " .. className) or ""),
			pill = (rested or 0) > 0 and "Rested" or nil, pillState = "rested" })
		t:Headline(pct .. "%", ("through level %d"):format(level))
		local done = max > 0 and cur / max or 0
		t:Bar(done, nil, nil, (rested or 0) > 0 and { (rested or 0) / max, "rested" } or nil)
		t:Scale(("%s XP to %d"):format(big(math.max(0, max - cur)), level + 1),
			(rested or 0) > 0 and ("%s rested"):format(big(rested)) or nil, "rested")
		local secs = M.ToLevel(cur, max, rate)
		if secs or (s and (s.gained or 0) > 0) then
			t:Section("At your pace")
			if secs then
				t:Row(("Level %d in"):format(level + 1), "about " .. duration(secs))
			end
			if s and (s.gained or 0) > 0 then
				t:Row("This session", ("+%s in %s"):format(big(s.gained), duration(U.Now() - (s.start or U.Now()))))
			end
			if rate then
				t:Row("Per hour", big(math.floor(rate)))
			end
		end
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.Section("xp", 7)
	M.frame.kind = "meter"
	M.frame.wantHeight = LINE_H
	-- the client draws nothing inside a frame with no height (see Perf)
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
	-- the bar: a faint track, the experience, and rested ahead of it
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPLEFT", M.frame, "TOPLEFT", INSET, -(TEXT_H + 3))
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -(TEXT_H + 3))
	M.track:SetHeight(BAR_H)
	M.fill = M.frame:CreateTexture(nil, "ARTWORK")
	M.fill:SetPoint("TOPLEFT", M.track, "TOPLEFT", 0, 0)
	M.fill:SetHeight(BAR_H)
	M.rested = M.frame:CreateTexture(nil, "ARTWORK")
	M.rested:SetPoint("TOPLEFT", M.fill, "TOPRIGHT", 0, 0)
	M.rested:SetHeight(BAR_H)
	-- the dock sets the width; the bar is measured against whatever it is
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
for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
	"PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, initial, reloading)
	if not BT.Enabled("xp") then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, initial, reloading)
	elseif event == "UPDATE_EXHAUSTION" then
		M.Update()
	else
		M.Gain()
	end
end)

-- THE CLIENT'S OWN BAR, PUT AWAY WHILE THIS ONE IS UP (Josh 2026-09-22): a
-- switch on this tab, on unless you turn it off. See Core/StatusBars.lua.
function M.HideClient()
	return not (BT.settings and BT.settings.hideClientXP == false)
end

function M.SetHideClient(on)
	BT.EnsureBound()
	BT.settings.hideClientXP = on and true or false
	BT.StatusBars.Set("xp", BT.Enabled("xp") and on)
end

function M.Show(on)
	-- switched off, the client's bar comes back whatever the switch says
	BT.StatusBars.Set("xp", on and M.HideClient())
	local frame = M.Build()
	if on then
		M.hiddenAtCap = nil
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("xp") then
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
	page:Note("Your level, how far through it you are, and roughly how long the rest will take at this session's pace.")
	page:Note("The paler stretch on the bar is rested XP. At the level cap there is no line.", true)
	local r = BT.Widgets.SwitchRow(page:Section("The game's own"), "Hide the game's bar",
		"Hides the game's experience bar while this one shows",
		function() return M.HideClient() and true or false end,
		function(on) M.SetHideClient(on) end)
	self.hideSwitch = r.switch
	local session = BT.Widgets.Row(page:Section("Session"), "New session", "Starts XP an hour and the time to level again from now")
	self.resetButton = session:SetControl(BT.Widgets.Button(session, "Reset", 62, 20))
	self.resetButton:SetScript("OnClick", function()
		M.Reset()
	end)
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

-- A NEW SESSION FROM THE PAGE (Josh 2026-09-28: "We don't need hundreds of
-- slash commands"): what /bt xp reset did, as the Reset row on this page
function M.Reset()
	M.Start(true, false)
	U.Print("XP: a new session starts now.")
end
