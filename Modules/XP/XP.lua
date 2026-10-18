-- Experience: where you are in the level, and how long the rest will take
-- (Josh 2026-09-22).
--
-- THE FIRST AND LARGEST ROW OF THE METERS (Josh 2026-10-05, the canvas "Dock
-- meters: level first", option A). A large shield with your level on it;
-- "Level 10" and how long until the next one at your pace; a bar with rested
-- experience as a paler stretch ahead of it; and under the bar how far
-- through the level you are and the experience left. Point at it for
-- zones and dungeons for your level.
--
-- EACH GAIN goes to the pace (M.Pace), and a level gained along the way is
-- counted whole rather than read as the bar going backwards. The session (a
-- login starts it, a /reload carries it on) keeps no total any more: nothing
-- showed it (2026-10-17, audit). At the level cap there is nothing to say, so
-- the line is not there.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/XP/XP.lua")

local U = BT.Util

local M = BT.Module({
	key = "xp",
	feature = "dock",
	title = "Experience",
	order = 37,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

-- the row (the canvas "Dock meters: level first"): 48 tall; the title and
-- the time 5 from the top, the bar 6 tall at 25, the words under it at 34
local ROW_H = 48
local TITLE_TOP, TITLE_H = 5, 16
local BAR_TOP, BAR_H = 25, 6
local SUB_TOP, SUB_H = 34, 12
local RIGHT = 6
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
		return { start = now }
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
	-- THE NEW MAX WITH THE OLD BAR (2026-10-17, audit) waits as well. Taken
	-- as a level gained, a read of 14 at 500 of 12,000 after 13 at 500 of
	-- 11,000 booked 11,000; the bar's own move then booked 11,550 more, and
	-- the level went to 15.
	if level > was and cur == wasCur then
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

-- 12,345: commas from a thousand, written the one way every count in
-- BeebMod is (U.Commas; 2026-10-17, audit: six copies used the client's
-- separator and the rest a comma)
local function big(n)
	return BT.Util.Commas(n)
end
M.Big = big

-- The row's words: the title, the time on its right, and the line under the
-- bar. "Level 10", "1h 17m to 11" (only once there is a pace), and "46% ·
-- 7,600 XP to go". The level is on the shield as well (Josh 2026-09-29), and
-- the canvas has it in the title too: the row is where you look for it.
function M.Lines(level, cur, max, rate)
	local pct = max > 0 and math.floor(cur / max * 100) or 0
	local title = ("Level %d"):format(level)
	local secs = M.ToLevel(cur, max, rate)
	local right = ""
	if secs then
		right = ("%s %s"):format(duration(secs), WORDS:format(("to %d"):format(level + 1)))
	end
	local sub = ("%d%% · %s XP to go"):format(pct, big(math.max(0, max - cur)))
	return title, right, sub
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
	local title, right, sub = M.Lines(level, cur, max, M.Rate())
	M.text:SetText(title)
	M.eta:SetText(right)
	M.sub:SetText(sub)
	M.restedWord:SetShown((rested or 0) > 0)
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

	local w = BT.Dock.LineBarWidth(M.frame, BT.Dock.HERO)
	if w <= 0 then
		return
	end
	local a = BT.Widgets.ACCENT
	-- "Rested" in the accent, lifted a third of the way to white
	M.restedWord:SetTextColor(a[1] + (1 - a[1]) * 0.3, a[2] + (1 - a[2]) * 0.3, a[3] + (1 - a[3]) * 0.3)
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
	-- (Josh 2026-09-27, the dock's tooltips redrawn) how far through the
	-- level, rested drawn on the bar.
	-- NO XP RATE (Josh 2026-10-04: "I think we can remove all of this
	-- redundant or unneeded info to save space"). The XP left, the time to
	-- level, this session and XP per hour went: the dock's line already says
	-- how long the level will take, and the room went to zones and dungeons.
	BT.Tip.Show(M.frame, { build = function(t)
		local className = UnitClass and select(1, UnitClass("player")) or nil
		local pct = max > 0 and math.floor(cur / max * 100) or 0
		t:Header({ name = "Experience", sub = ("Level %d%s"):format(level, className and (" " .. className) or ""),
			pill = (rested or 0) > 0 and "Rested" or nil, pillState = "rested" })
		t:Headline(pct .. "%", ("of level %d"):format(level))
		local done = max > 0 and cur / max or 0
		t:Bar(done, nil, nil, (rested or 0) > 0 and { (rested or 0) / max, "rested" } or nil)
		-- ZONES AND DUNGEONS FOR YOUR LEVEL (Josh 2026-10-04): three of each
		-- whose range takes you in, for your side, nearest the middle of
		-- their range first (Modules/XP/Zones.lua, Dungeons.lua); none, no section
		local side = UnitFactionGroup and select(1, UnitFactionGroup("player")) or nil
		local zones = BT.Zones and BT.Zones.For(level, side) or {}
		local dungeons = BT.Dungeons and BT.Dungeons.For(level, side) or {}
		local soon = #dungeons == 0 and BT.Dungeons and BT.Dungeons.Next(level, side) or {}
		-- A LEVEL HELPER (Josh 2026-10-04: "Can we add a 'Recommended content'
		-- heading for the zones/dungeons sub headings? I'd like to frame it
		-- more as a level helper"): one section, a small heading for each kind
		-- HOW HARD (Josh 2026-10-04: "Could we color the zones/dungeons by the
		-- relative difficulty (similar to quests and mobs)?"): by where you are
		-- in the range (Dungeons.lua, D.RangeColour). A dungeon still ahead of
		-- you, below its range, by the quests' rule on its lowest level.
		local function hard(entry, kind)
			return BT.Dungeons.RangeColour(entry, level, kind)
		end
		if #zones > 0 or #dungeons > 0 or #soon > 0 then
			t:Section("Recommended content")
			-- each kind a step in, a line between them (Josh 2026-10-04: "slightly
			-- indent the zones/dungeons sections, and place an (also indented)
			-- divider between them"); the section steps them in (UI/Tip.lua)
			if #zones > 0 then
				t:Subhead("Zones")
				for _, z in ipairs(zones) do
					t:ListRow(z.name, ("%d-%d"):format(z.lo, z.hi), nil, hard(z, "zone"))
				end
			end
			if #zones > 0 and (#dungeons > 0 or #soon > 0) then
				t:Divider()
			end
			if #dungeons > 0 then
				t:Subhead("Dungeons")
				for _, d in ipairs(dungeons) do
					t:ListRow(d.name, ("%d-%d"):format(d.lo, d.hi), nil, hard(d, "dungeon"))
				end
			elseif #soon > 0 then
				-- none yet: the first coming, a few levels off (Dungeons.lua, D.Next)
				t:Subhead("Next dungeon")
				for _, d in ipairs(soon) do
					t:ListRow(d.name, ("%d-%d"):format(d.lo, d.hi), nil, BT.Util.LevelColour(d.lo))
				end
			end
		end
		t:Foot({ { "Right-click", "reset session" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("xp", 7)
	M.frame.kind = "meter"
	M.frame.wantHeight = ROW_H
	-- the client draws nothing inside a frame with no height (see Performance)
	M.frame:SetHeight(ROW_H)
	-- a large shield at the start, your level on it
	local H = BT.Dock.HERO
	M.shield = BT.Dock.LineShield(M.frame, H.left, nil, H)
	BT.Dock.LineNumber(M.frame, M.shield, 13)
	-- everything else starts after the shield
	local x = H.left + H.w + BT.Dock.LINE_ICON_GAP
	M.text = M.frame:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	BT.Fonts.Set(M.text, "name", 13)
	M.text:SetPoint("TOPLEFT", M.frame, "TOPLEFT", x, -TITLE_TOP)
	M.text:SetHeight(TITLE_H)
	M.text:SetJustifyH("LEFT")
	M.text:SetWordWrap(false)
	M.eta = M.frame:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	BT.Fonts.Set(M.eta, "name", 11)
	M.eta:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -RIGHT, -TITLE_TOP)
	M.eta:SetHeight(TITLE_H)
	M.eta:SetJustifyH("RIGHT")
	-- NOT HUNG FROM THE TIME (2026-10-05: "Missing level label"). Its right
	-- edge was the time's left edge, and with no pace yet the time is no text
	-- at all - the game drew nothing hung from it, and the title went. The
	-- two fit side by side whatever they say ("Level 60", "12h 30m to 61").
	-- the bar: a faint track, the experience, and rested ahead of it
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPLEFT", M.frame, "TOPLEFT", x, -BAR_TOP)
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -RIGHT, -BAR_TOP)
	M.track:SetHeight(BAR_H)
	-- how far through, and what is left, under the bar; "Rested" opposite
	M.restedWord = BT.Widgets.Label(M.frame, "Rested", "small")
	M.restedWord:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -RIGHT, -SUB_TOP)
	M.restedWord:SetHeight(SUB_H)
	M.restedWord:SetJustifyH("RIGHT")
	M.restedWord:Hide()
	M.sub = BT.Widgets.Label(M.frame, "", "small", 0.54, 0.60, 0.58)
	M.sub:SetPoint("TOPLEFT", M.frame, "TOPLEFT", x, -SUB_TOP)
	-- (clear of "Rested", but not hung from it: see the title)
	M.sub:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -(RIGHT + 50), -SUB_TOP)
	M.sub:SetHeight(SUB_H)
	M.sub:SetJustifyH("LEFT")
	M.sub:SetWordWrap(false)
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

-- THE CLIENT'S OWN BAR, PUT AWAY WHILE THIS ONE IS UP (Josh 2026-09-22),
-- always since the settings canvas cut its switch (2026-10-04). See
-- Core/StatusBars.lua.
function M.HideClient()
	return true
end

-- the client's bar put away or given back now (for the tests)
function M.SetHideClient(on)
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

-- A NEW SESSION (Josh 2026-09-28: "We don't need hundreds of slash
-- commands"): what /bt xp reset did, from a right-click on the XP line
function M.Reset()
	local list = M.PaceList()
	if list then
		for i = #list, 1, -1 do
			list[i] = nil
		end
	end
	M.Start(true, false)
	U.Print("XP: session reset.")
end
