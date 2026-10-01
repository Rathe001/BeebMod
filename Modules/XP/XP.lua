-- Experience: where you are in the level, and how long the rest will take
-- (Josh 2026-09-22).
--
-- One line of the dock and a thin bar under it. The shield at its start says
-- the level, the line how far through it you are, and roughly how long until
-- the next one at your pace; the bar shows the same, with rested experience as a
-- paler stretch ahead of it. Point at it for the numbers.
--
-- WHAT THIS SESSION GAINED is kept as the gold per hour is: a login starts
-- it, a /reload carries it on, and a level gained along the way is counted
-- whole rather than read as the bar going backwards. The PACE is not the
-- session's any more (M.Pace). At the level cap there is nothing to say, so
-- the line is not there.
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
-- the level's shield: dark slate, and a fifth of Experience's colour at
-- four tenths of its light
M.SHIELD_SLATE = { 0.20, 0.22, 0.23 }

-- THE RIM BY BRACKET (Josh 2026-09-29: "we should use 10 level brackets
-- though. 1-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60. These tend to be
-- major breakpoints, and match pvp brackets"). The rim takes the item
-- quality colours in turn, poor grey to artifact gold at 60, crowned.
M.RIMS = {
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level1",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level2",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level3",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level4",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level5",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level6",
	"Interface\\AddOns\\BeebMod\\Art\\Dock\\level7",
}
-- the 60 shield's crop: taller than the others', so its crown is in it
M.CROWN_CROP = { 0.25, 0.75, 0.06, 0.875 }

function M.Bracket(level)
	level = tonumber(level) or 1
	return math.max(1, math.min(#M.RIMS, math.floor(level / 10) + 1))
end
function M.ShieldTint(a)
	local s = M.SHIELD_SLATE
	return s[1] * 0.8 + a[1] * 0.08, s[2] * 0.8 + a[2] * 0.08, s[3] * 0.8 + a[3] * 0.08
end

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
	-- A LEVEL READ HALF NEW (Josh 2026-09-30, review). The client can answer
	-- the new level's experience while UnitLevel still says the old one, or
	-- the new level with the old experience. Read as it came, the next gain
	-- was nearly a whole level, and the pace jumped for an hour. Experience
	-- going down without a new level is a level gained; a new level with the
	-- bar unmoved waits for the bar.
	if level > was and cur == wasCur and max == wasMax then
		return
	end
	local levelled = level > was or (level == was and cur < wasCur)
	local gained
	if levelled then
		gained = math.max(0, wasMax - wasCur) + cur
	else
		gained = cur - wasCur
	end
	if gained > 0 then
		s.gained = (s.gained or 0) + gained
		M.Note(gained, U.Now())
	end
	-- a level never goes down in a session, so a late read of the old one
	-- is not a level to gain again
	M.level = levelled and math.max(level, was + 1) or math.max(level, was)
	M.cur, M.max = cur, max
	s.last = U.Now()
	M.Update()
end

-- THE PACE WHILE YOU PLAY (Josh 2026-09-28: "Anything we can do to make the
-- time to level estimate more accurate and not dependent on when the addon
-- was installed, and how far into a level the player is already?"). It was
-- the session's experience over the time since login, so an hour spent
-- installing and setting up counted as an hour of levelling, and each login
-- began again from nothing: after a few kills, 81 hours to level.
--
-- Now it is experience over the time between one gain and the next. The
-- time before the first and after the last is not levelling. A gap longer
-- than M.BREAK counts as M.BREAK: a flight or a trip to a vendor is still
-- levelling, an hour away from the keyboard is not. The last M.WINDOW of
-- that time is kept for each character across logins, so a login starts
-- from the last hour's pace rather than from nothing. Before M.MIN_GAINS
-- gains and M.MIN_TIME of counted time there is no pace to give.
M.BREAK = 300
M.WINDOW = 3600
M.MIN_GAINS = 3
M.MIN_TIME = 120
-- however quick the gains, a list no longer than this
local KEEP = 400

-- this character's gains, oldest first: { { t = when, xp = how much } }
function M.PaceList()
	if not BT.settings then
		return nil
	end
	BT.settings.xpPace = BT.settings.xpPace or {}
	local who = (U.MeKey and U.MeKey()) or (U.Me and U.Me()) or "?"
	BT.settings.xpPace[who] = BT.settings.xpPace[who] or {}
	return BT.settings.xpPace[who]
end

-- the time between gain i - 1 and gain i, as it counts
local function counts(list, i)
	return math.min(math.max((list[i].t or 0) - (list[i - 1].t or 0), 0), M.BREAK)
end

-- a gain, and the list cut back to the window (with the gain it starts from)
function M.Note(xp, now)
	local list = M.PaceList()
	if not list then
		return
	end
	list[#list + 1] = { t = now, xp = xp }
	local counted, first = 0, 1
	for i = #list, 2, -1 do
		counted = counted + counts(list, i)
		if counted >= M.WINDOW then
			first = i - 1
			break
		end
	end
	first = math.max(first, #list - KEEP + 1)
	if first > 1 then
		for _ = 1, first - 1 do
			table.remove(list, 1)
		end
	end
end

-- experience an hour over the last M.WINDOW of counted time, or nil
function M.Pace(list)
	list = list or M.PaceList()
	if not list or #list < M.MIN_GAINS then
		return nil
	end
	local counted, gained = 0, 0
	for i = #list, 2, -1 do
		counted = counted + counts(list, i)
		gained = gained + (list[i].xp or 0)
		if counted >= M.WINDOW then
			break
		end
	end
	if counted < M.MIN_TIME then
		return nil
	end
	return gained * 3600 / counted
end

-- what the pace still needs, in words, while there is none
function M.Waiting(list)
	list = list or M.PaceList() or {}
	local more = M.MIN_GAINS - #list
	if more > 0 then
		return ("The time to level shows after %d more %s of XP."):format(more, more == 1 and "gain" or "gains")
	end
	return "The time to level shows after a little more play."
end

-- experience per hour at your pace, or nil while there is too little to go on
function M.Rate()
	return M.Pace()
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
	-- THE LEVEL IS ON THE SHIELD (Josh 2026-09-29: "put the number level
	-- inside the icon - it would save some room"): the line says how far
	-- through it you are, and the hover says the rest. A TITLE FIRST (Josh
	-- 2026-09-29: "we need some titles for these progress bars, kind of like
	-- how the expedition starts with Expedition"): "Level · 46%".
	local left = ("Level %s"):format(WORDS:format(("· %d%%"):format(pct)))
	local secs = M.ToLevel(cur, max, rate)
	-- ONE GRAMMAR WITH REPUTATION (Josh 2026-09-22, the panel redesign): the
	-- right side is a time, and only once there is a pace. What is
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
		BT.Dock.Relayout()
	end
	if cap then
		return
	end
	local left, right = M.Lines(level, cur, max, M.Rate())
	M.text:SetText(left)
	M.eta:SetText(right)
	-- the level on the shield, or the Testing page's preview of another
	local shown = BT.Dock.preview.level or level
	local bracket = M.Bracket(shown)
	M.shield.number:SetText(shown)
	M.shield.rim:SetTexture(M.RIMS[bracket])
	-- 60 wears a crown over the shield: drawn with a taller crop so it shows,
	-- and the number a little lower, in the middle of the field again
	local crop = bracket == #M.RIMS and M.CROWN_CROP or BT.Dock.LINE_ICON_CROP
	for _, layer in ipairs({ M.shield.field, M.shield.rim }) do
		layer:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
	end
	M.shield.number:ClearAllPoints()
	M.shield.number:SetPoint("CENTER", M.shield.icon, "CENTER", 0, bracket == #M.RIMS and -0.5 or 1)

	local w = BT.Dock.LineBarWidth(M.frame, INSET)
	if w <= 0 then
		return
	end
	local a = BT.Widgets.ACCENT
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	BT.Dock.BandColor(M.frame, a)
	-- A DARK SHIELD (Josh 2026-09-29: "what if we make the shield darker? It
	-- kind of looks too similar to the expidition"): dark slate with a trace
	-- of Experience's colour, so the white level reads on it - a class colour
	-- darkened alone came out the brown of the Expedition's leather
	M.shield.field:SetVertexColor(M.ShieldTint(a))
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
		t:Section("At your pace")
		if secs then
			t:Row(("Level %d in"):format(level + 1), "about " .. duration(secs))
		else
			-- NOT YET, AND WHY (Josh 2026-09-28: "Not seeing any 'x to next
			-- level' estimates now"): the pace needs a few gains first
			t:Note(M.Waiting())
		end
		if s and (s.gained or 0) > 0 then
			t:Row("This session", ("+%s in %s"):format(big(s.gained), duration(U.Now() - (s.start or U.Now()))))
		end
		if rate then
			t:Row("Per hour", big(math.floor(rate)))
		end
		t:Foot({ { "Right-click", "start the pace again" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("xp", 7)
	M.frame.kind = "meter"
	M.frame.wantHeight = LINE_H
	-- the client draws nothing inside a frame with no height (see Performance)
	M.frame:SetHeight(LINE_H)
	M.text = BT.Widgets.Label(M.frame, "", "small")
	M.text:SetJustifyH("LEFT")
	-- a shield at the start, your level on it
	M.shield = BT.Dock.LineShield(M.frame, INSET)
	BT.Dock.LineNumber(M.frame, M.shield)
	M.eta = BT.Widgets.Label(M.frame, "", "small")
	M.eta:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -3)
	M.eta:SetJustifyH("RIGHT")
	-- as tall as the left words, so both sit on one line (Josh 2026-09-29:
	-- the right side sat a pixel high, its height its own)
	M.eta:SetHeight(TEXT_H - 2)
	-- A LONG NAME STOPS SHORT OF THE RIGHT-HAND TEXT (Josh 2026-09-22):
	-- "Gnomeregan Exiles · Friendly" ran straight into "2,807 to Honored".
	-- The left text ends where the right one begins, and is cut short with
	-- an ellipsis rather than drawn over it.
	M.text:SetPoint("TOPRIGHT", M.eta, "TOPLEFT", -8, 0)
	M.text:SetHeight(TEXT_H - 2)
	M.text:SetWordWrap(false)
	-- the bar: a faint track, the experience, and rested ahead of it
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -(TEXT_H + 3))
	M.track:SetHeight(BAR_H)
	BT.Dock.LineAfter(M.shield.icon, M.text, M.track, TEXT_H)
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
	-- RIGHT-CLICK TO START AGAIN (Josh 2026-09-28: "Maybe we should add a
	-- 'right click to reset'"), as the Reset on the Progress page does
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			M.Reset()
			if BT.Tip and BT.Tip.IsShown() then
				M.Tip()
			end
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
	BT.Dock.Relayout()
end

function M:OnEnable()
	-- WHAT THE BAR SAYS NOW (Josh 2026-09-30, review): experience gained
	-- while this was off is not one gain. Booked as one, it made the pace
	-- for the next hour, as Currency's purse once did (Currency.lua, M.Show).
	if M.session then
		M.level, M.cur, M.max = M.Read()
	end
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
	page:Note("Your level, how far through it you are, and roughly how long the rest will take.")
	page:Note("The time to level comes from the XP you gained in your last hour of play. "
		.. "Only the time between one gain and the next counts, and a gap longer than 5 minutes counts as 5.", true)
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
	local list = M.PaceList()
	if list then
		for i = #list, 1, -1 do
			list[i] = nil
		end
	end
	M.Start(true, false)
	U.Print("XP: the session and the pace start again now.")
end
