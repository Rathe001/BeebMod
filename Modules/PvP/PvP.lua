-- PvP: your PvP rank and how far to the next (Josh 2026-09-29: "I think we
-- should add a pvp meter, and we can use the pvp rank icon for it").
--
-- One line of the dock and a thin bar, as Experience and Reputation have.
-- The shield at its start is the game's own insignia for your rank - Private
-- to Grand Marshal, Scout to High Warlord - and before the first rank, a
-- shield of your side's colour with two swords on it. The line says the
-- rank, and on the right your rank points ("0 / 750 pts"); the bar is how
-- far through them you are. Point at it for your honorable kills.
--
-- WHERE THE RANK COMES FROM. This game has none of Classic's honor calls: its
-- PvP tab shows a rank and rank points that no call gives, so they are read
-- off that tab (M.FromTab). A client with Classic's calls is read those
-- instead. With neither, there is no line, and the settings page says so.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/PvP/PvP.lua")

local M = BT.Module({
	key = "pvp",
	feature = "dock",
	onPage = "progress",
	title = "PvP",
	blurb = "Your PvP rank, and how far to the next",
	order = 37.2,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

local TEXT_H = 16
local BAR_H = 4
local LINE_H = TEXT_H + BAR_H + 9
local INSET = 6
local EVERY = 30
-- the first rank's id: the client counts from 5, Private or Scout
local FIRST_RANK = 5
local INSIGNIA = "Interface\\PvPRankBadges\\PvPRank%02d"

local WORDS = "|cff8a9894%s|r"

-- each side's colour, for the bar and the shield before the first rank
M.SIDES = {
	Alliance = { 0.30, 0.52, 0.90 },
	Horde = { 0.82, 0.24, 0.20 },
}
M.NEUTRAL = { 0.60, 0.62, 0.64 }

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
M.Big = big

-- a call of the client's, its answers, or nothing where it has none
local function pass(ok, ...)
	if ok then
		return ...
	end
	return nil
end
local function ask(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return nil
	end
	return pass(pcall(fn, ...))
end

-- ---------------------------------------------------------------------------
-- What the client says
-- ---------------------------------------------------------------------------

-- the ranks by name, each side's, 1 to 14: the number gives the insignia
M.RANKS = {
	Alliance = { "Private", "Corporal", "Sergeant", "Master Sergeant", "Sergeant Major", "Knight",
		"Knight-Lieutenant", "Knight-Captain", "Knight-Champion", "Lieutenant Commander", "Commander",
		"Marshal", "Field Marshal", "Grand Marshal" },
	Horde = { "Scout", "Grunt", "Sergeant", "Senior Sergeant", "First Sergeant", "Stone Guard",
		"Blood Guard", "Legionnaire", "Centurion", "Champion", "Lieutenant General", "General",
		"Warlord", "High Warlord" },
}

-- your side: "Alliance", "Horde" or nil (or the Testing page's preview)
function M.SideName()
	local side = BT.Dock.preview.side or ask("UnitFactionGroup", "player")
	return M.RANKS[side or ""] and side or nil
end

-- your side's colour
function M.Side()
	return M.SIDES[M.SideName() or ""] or M.NEUTRAL
end

-- a rank's number, 1 to 14, from its name; 0 for none (Civilian)
function M.NumberOf(name)
	if type(name) ~= "string" then
		return 0
	end
	local lists = { M.RANKS[M.SideName() or ""], M.RANKS.Alliance, M.RANKS.Horde }
	for _, list in ipairs(lists) do
		for i, rank in ipairs(list or {}) do
			if rank:lower() == name:lower() then
				return i
			end
		end
	end
	return 0
end

-- the rank after number `n` on your side, by name
function M.NextName(n)
	local list = M.RANKS[M.SideName() or ""] or M.RANKS.Alliance
	return list[(n or 0) + 1]
end

-- CLASSIC'S HONOR SYSTEM, where a client has it: a rank id from 5 up, and
-- its progress as a share
function M.Classic()
	return type(_G.UnitPVPRank) == "function" and type(_G.GetPVPRankInfo) == "function"
end

-- a rank by the client's id: its name and its number, 1 to 14; nil before
-- the first
function M.RankOf(id)
	id = tonumber(id) or 0
	if id < FIRST_RANK then
		return nil, 0
	end
	local name, number = ask("GetPVPRankInfo", id, "player")
	if type(number) ~= "number" or number < 1 then
		number = id - FIRST_RANK + 1
	end
	return type(name) == "string" and name ~= "" and name or ("Rank " .. number), number
end

-- THIS GAME'S OWN: RANK POINTS (Josh 2026-09-29, two records). The PvP tab
-- of the character window says "Civilian" and "Rank Points: 0 / 750", and
-- no call an addon can make says either: the game writes them onto the
-- tab's own labels and nowhere else. So they are read off those labels,
-- each time the game writes them (M.WatchTab), and kept for the character,
-- so the line has them after a restart too.
-- The tab is a frame with a name of its own, PVPRankFrame: the character
-- window holds it, but not under that key (the record's first try looked
-- there and found nothing).
function M.Tab()
	local sheet = _G.CharacterFrame
	local tab = (type(sheet) == "table" and sheet.PVPRankFrame) or _G.PVPRankFrame
	return type(tab) == "table" and tab or nil
end

function M.TabFields()
	local tab = M.Tab()
	local info = type(tab) == "table" and tab.MainInfoFrame
	if type(info) == "table" and info.CurrentRankField and info.CurrentRankProgressField then
		return info
	end
	return nil
end

local function textOf(fs)
	local ok, s = pcall(fs.GetText, fs)
	if ok and type(s) == "string" and not (issecretvalue and issecretvalue(s)) then
		return s
	end
	return nil
end

-- the words without the client's colour codes
local function plainText(s)
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
	return s
end

local function number(s)
	return tonumber((s:gsub("[,%.%s]", "")))
end

-- what the tab says now: { name, points, cap }, or nil when it says nothing
function M.FromTab()
	local info = M.TabFields()
	if not info then
		return nil
	end
	local name = textOf(info.CurrentRankField)
	local progress = textOf(info.CurrentRankProgressField)
	if not (name and name ~= "" and progress) then
		return nil
	end
	local a, b = plainText(progress):match("([%d,%.]+)%s*/%s*([%d,%.]+)")
	if not a then
		return nil
	end
	return { name = plainText(name), points = number(a) or 0, cap = number(b) or 0 }
end

-- the rank points kept for this character: the tab's last word on them
local function kept()
	if not BT.settings then
		return nil
	end
	BT.settings.pvp = BT.settings.pvp or {}
	local who = (BT.Util.Me and BT.Util.Me()) or "?"
	return BT.settings.pvp, who
end

-- read the tab and keep what it says; true when there was something
function M.TakeTab()
	local t = M.FromTab()
	local all, who = kept()
	if not (t and all) then
		return false
	end
	t.at = BT.Util.Now and BT.Util.Now() or 0
	all[who] = t
	return true
end

-- The game writes the tab's labels whenever your rank or points change
-- (open or not, once it has made them): each write is read, a frame later.
function M.WatchTab()
	if M.watching then
		return true
	end
	local info = M.TabFields()
	if not (info and hooksecurefunc) then
		return false
	end
	local function heard()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if M.TakeTab() then
					M.Update()
				end
			end)
		elseif M.TakeTab() then
			M.Update()
		end
	end
	-- NOT ONLY SetText (Josh 2026-09-29: "Still no pvp meter on the dock"):
	-- the points line is written as a format, and the rank may have been
	-- written before anything listened. Either kind of write, and the tab
	-- being shown, are each a reason to read it.
	for _, fs in ipairs({ info.CurrentRankField, info.CurrentRankProgressField }) do
		for _, how in ipairs({ "SetText", "SetFormattedText" }) do
			if type(fs[how]) == "function" then
				pcall(hooksecurefunc, fs, how, heard)
			end
		end
	end
	for _, f in ipairs({ M.Tab(), info }) do
		if f.HookScript then
			pcall(f.HookScript, f, "OnShow", heard)
		end
	end
	M.watching = true
	M.TakeTab()
	return true
end

-- whether there is anything to read: Classic's calls, or this game's tab
function M.Available()
	return M.Classic() or M.TabFields() ~= nil
end

-- Everything the line and the hover say: your rank, the next, how far, and
-- your honorable kills and honor, as far as the game says them.
function M.Read()
	local todayHK, todayHonor = ask("GetPVPSessionStats")
	local yesterdayHK, _, yesterdayHonor = ask("GetPVPYesterdayStats")
	local lifeHK, _, highest = ask("GetPVPLifetimeStats")
	local p = {
		today = { hk = tonumber(todayHK) or 0, honor = tonumber(todayHonor) or 0 },
		yesterday = { hk = tonumber(yesterdayHK) or 0, honor = tonumber(yesterdayHonor) },
		life = { hk = tonumber(lifeHK) or 0 },
	}
	if M.Classic() then
		local id = tonumber((ask("UnitPVPRank", "player"))) or 0
		p.name, p.number = M.RankOf(id)
		p.nextName = M.RankOf(id < FIRST_RANK and FIRST_RANK or id + 1)
		p.progress = math.max(0, math.min(1, tonumber((ask("GetPVPRankProgress"))) or 0))
		local weekHK, weekHonor = ask("GetPVPThisWeekStats")
		local lastHK, _, lastHonor, lastStanding = ask("GetPVPLastWeekStats")
		p.week = { hk = tonumber(weekHK), honor = tonumber(weekHonor) }
		p.last = { hk = tonumber(lastHK), honor = tonumber(lastHonor), standing = tonumber(lastStanding) }
		p.life.highest = (M.RankOf(highest))
		return p
	end
	local all, who = kept()
	local t = all and all[who]
	if not t then
		return nil
	end
	p.fromTab, p.at = true, t.at
	p.number = M.NumberOf(t.name)
	-- Civilian, and anything else the ranks do not name, is no rank yet
	p.name = p.number > 0 and t.name or nil
	p.title = t.name
	p.points, p.cap = t.points or 0, t.cap or 0
	p.nextName = M.NextName(p.number)
	p.progress = p.cap > 0 and math.max(0, math.min(1, p.points / p.cap)) or 0
	return p
end

-- the game's insignia for a rank, if the client has the file
function M.Insignia(n)
	if not (n and n >= 1) then
		return nil
	end
	local path = INSIGNIA:format(n)
	if type(GetFileIDFromPath) == "function" then
		local ok, id = pcall(GetFileIDFromPath, path)
		if not (ok and id) then
			return nil
		end
	end
	return path
end

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

-- the rank on the left; on the right, rank points where the game has them,
-- and this week's honor where it has that
function M.Lines(p)
	-- A TITLE FIRST (Josh 2026-09-29), as the Expedition's line has, and no
	-- count after it: "PvP · Sergeant", or "PvP · Civilian" before the first
	-- rank. Which of fourteen is on the hover.
	local left
	if p.name then
		left = ("PvP %s"):format(WORDS:format("· " .. p.name))
	else
		left = ("PvP %s"):format(WORDS:format("· " .. (p.title or "no rank yet")))
	end
	local right = ""
	if p.fromTab then
		right = ("%s / %s %s"):format(big(p.points), big(p.cap), WORDS:format("pts"))
	elseif p.week and (p.week.honor or 0) > 0 then
		right = ("%s %s"):format(big(p.week.honor), WORDS:format("honor"))
	end
	return left, right
end

function M.Update()
	if not M.frame then
		return
	end
	if not M.watching then
		M.WatchTab()
	end
	-- and read it again now: two labels, cheap, and whatever the game
	-- wrote without a word to us is taken the next time round
	if not M.Classic() then
		M.TakeTab()
	end
	local p = M.Read()
	local want = p ~= nil and BT.Enabled("pvp")
	if want ~= M.shownFor then
		M.shownFor = want
		M.frame:SetShown(want)
		BT.Dock.Relayout()
	end
	if not p then
		return
	end
	local left, right = M.Lines(p)
	M.text:SetText(left)
	M.eta:SetText(right)
	-- the rank's insignia; before the first, your side's shield and swords
	local c = M.Side()
	-- the rank's, or one previewed from the Testing page (0 for none)
	local rank = BT.Dock.preview.pvp
	if rank == nil then
		rank = p.number
	end
	local insignia = M.Insignia(rank)
	M.insignia:SetShown(insignia ~= nil)
	if insignia then
		M.insignia:SetTexture(insignia)
	end
	for _, layer in ipairs({ M.shield.field, M.shield.rim, M.shield.mark }) do
		layer:SetShown(insignia == nil)
	end
	M.shield.field:SetVertexColor(c[1], c[2], c[3])

	local w = BT.Dock.LineBarWidth(M.frame, INSET)
	if w <= 0 then
		return
	end
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	BT.Dock.BandColor(M.frame, c)
	-- a texture of no width is drawn as a whole one, so an empty bar is hidden
	M.fill:SetShown(p.progress > 0)
	M.fill:SetWidth(math.max(1, w * p.progress))
end

-- your rank and how far to the next, then your kills and honor
function M.Tip()
	local p = M.Read()
	if not (p and BT.Tip) then
		return
	end
	local c = M.Side()
	BT.Tip.Show(M.frame, { build = function(t)
		t:Header({ name = "PvP", sub = p.title or p.name or "No rank yet",
			pill = p.name and ("Rank %d / 14"):format(p.number) or nil, pillState = c })
		if p.fromTab then
			t:Headline(("%s / %s"):format(big(p.points), big(p.cap)), "rank points")
			t:Bar(p.progress, c)
			if p.nextName then
				t:Scale(("Next rank: %s"):format(p.nextName))
			end
		elseif p.nextName then
			t:Headline(math.floor(p.progress * 100) .. "%", ("of the way to %s"):format(p.nextName))
			t:Bar(p.progress, c)
		else
			t:Headline(p.name or "PvP", nil, c, true)
		end
		t:Section("Honorable kills")
		t:Row("Today", big(p.today.hk))
		t:Row("Yesterday", big(p.yesterday.hk))
		if p.week and p.week.hk then
			t:Row("This week", big(p.week.hk))
		end
		if p.last and p.last.hk then
			t:Row("Last week", big(p.last.hk))
		end
		t:Row("In all", big(p.life.hk))
		if p.week and p.week.honor then
			t:Section("Honor")
			t:Row("Today", big(p.today.honor))
			t:Row("This week", big(p.week.honor))
			if p.last and p.last.honor then
				t:Row("Last week", big(p.last.honor))
			end
		end
		if p.last and (p.last.standing or 0) > 0 then
			t:Row("Last week's standing", big(p.last.standing))
		end
		if p.life.highest then
			t:Row("Highest rank", p.life.highest)
		end
		if p.fromTab then
			t:Note("As your character window's PvP tab last showed them.")
		end
		t:Foot({ { "Click", "open the PvP page" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("pvp", 7)
	M.frame.kind = "meter"
	M.frame.wantHeight = LINE_H
	-- the client draws nothing inside a frame with no height (see Performance)
	M.frame:SetHeight(LINE_H)
	M.text = BT.Widgets.Label(M.frame, "", "small")
	M.text:SetJustifyH("LEFT")
	M.shield = BT.Dock.LineShield(M.frame, INSET, BT.Dock.SHIELD_SWORDS)
	-- the game's insignia is square: as wide as the shield, in its middle
	M.insignia = M.frame:CreateTexture(nil, "ARTWORK", nil, 4)
	M.insignia:SetSize(BT.Dock.LINE_ICON_W, BT.Dock.LINE_ICON_W)
	M.insignia:SetPoint("CENTER", M.shield.icon, "CENTER", 0, 0)
	M.insignia:Hide()
	M.eta = BT.Widgets.Label(M.frame, "", "small")
	M.eta:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -3)
	M.eta:SetJustifyH("RIGHT")
	-- as tall as the left words, so both sit on one line (Josh 2026-09-29:
	-- the right side sat a pixel high, its height its own)
	M.eta:SetHeight(TEXT_H - 2)
	-- a long rank name stops short of the honor on the right
	M.text:SetPoint("TOPRIGHT", M.eta, "TOPLEFT", -8, 0)
	M.text:SetHeight(TEXT_H - 2)
	M.text:SetWordWrap(false)
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -(TEXT_H + 3))
	M.track:SetHeight(BAR_H)
	BT.Dock.LineAfter(M.shield.icon, M.text, M.track, TEXT_H)
	M.fill = M.frame:CreateTexture(nil, "ARTWORK")
	M.fill:SetPoint("TOPLEFT", M.track, "TOPLEFT", 0, 0)
	M.fill:SetHeight(BAR_H)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	M.frame:EnableMouse(true)
	-- a click opens the PvP page of the character window (Josh 2026-09-29)
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			BT.Util.OpenCharacter("pvp")
		end
	end)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.frame
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED",
	"UNIT_FACTION" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, unit)
	if not BT.Enabled("pvp") then
		return
	end
	if event == "UNIT_FACTION" and unit ~= "player" then
		return
	end
	M.Update()
end)

function M.Show(on)
	local frame = M.Build()
	if on then
		M.shownFor = nil
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			-- rank progress is worked out by the client; read it now and then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("pvp") then
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
	M.Show(true)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The record (the Testing page)
-- ---------------------------------------------------------------------------

-- WHAT THIS CLIENT'S PVP SAYS (Josh 2026-09-29: the game's PvP panel shows
-- "Rank Points: 0 / 750" and a weekly cap, which Classic's honor system never
-- had). Every function the client has whose name speaks of PvP, honor or
-- rank, and what the ones that only read answer - Get, Is, Has, Can and Unit
-- (asked about you) - so the line can be built on what is really there.
local READS = { "^Get", "^Is", "^Has", "^Can", "^Unit" }
local function reads(name)
	for _, p in ipairs(READS) do
		if name:find(p) then
			return true
		end
	end
	return false
end

local function say(v)
	if issecretvalue and issecretvalue(v) then
		return "<secret>"
	end
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do
			if #parts >= 12 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = tostring(k) .. "=" .. tostring(x)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function answers(fn, ...)
	local out = { pcall(fn, ...) }
	if not out[1] then
		return "error: " .. tostring(out[2])
	end
	local parts = {}
	for i = 2, math.max(2, #out) do
		parts[#parts + 1] = say(out[i])
	end
	return table.concat(parts, ", ")
end

function M.Dump()
	local lines = {}
	local function ask(label, fn, ...)
		lines[#lines + 1] = label .. " = " .. answers(fn, ...)
	end
	local names = {}
	for name, v in pairs(_G) do
		if type(name) == "string" and type(v) == "function" then
			local low = name:lower()
			if low:find("pvp") or low:find("honor") or low:find("rank") then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		if reads(name) then
			if name:find("^Unit") then
				ask(name .. '("player")', _G[name], "player")
			else
				ask(name .. "()", _G[name])
			end
		else
			lines[#lines + 1] = name .. " (not called)"
		end
	end
	-- the namespaces a newer client keeps them in
	for ns, v in pairs(_G) do
		if type(ns) == "string" and ns:find("^C_") and type(v) == "table" then
			local low = ns:lower()
			if low:find("pvp") or low:find("honor") or low:find("rank") then
				local members = {}
				for k in pairs(v) do
					members[#members + 1] = k
				end
				table.sort(members)
				for _, k in ipairs(members) do
					if type(v[k]) == "function" and reads(k) then
						ask(ns .. "." .. k .. "()", v[k])
					else
						lines[#lines + 1] = ns .. "." .. k .. " (" .. type(v[k]) .. ", not called)"
					end
				end
			end
		end
	end
	-- RANK POINTS (the first record: no Classic honor calls here, and none
	-- of the namespaces above says "Rank Points"). Every other namespace's
	-- functions about ranks, seasons or points; the PvP tab's own fields and
	-- functions, which the game's panel fills itself from; and your currency
	-- list, in case the points are one.
	for ns, v in pairs(_G) do
		if type(ns) == "string" and ns:find("^C_") and type(v) == "table" then
			local low = ns:lower()
			if not (low:find("pvp") or low:find("honor") or low:find("rank")) then
				local members = {}
				for k, fn in pairs(v) do
					local lk = type(k) == "string" and k:lower() or ""
					if type(fn) == "function" and (lk:find("rank") or lk:find("season") or lk:find("point")) then
						members[#members + 1] = k
					end
				end
				table.sort(members)
				for _, k in ipairs(members) do
					if reads(k) then
						ask(ns .. "." .. k .. "()", v[k])
					else
						lines[#lines + 1] = ns .. "." .. k .. " (not called)"
					end
				end
			end
		end
	end
	local tab = M.Tab()
	for label, f in pairs({ PVPRankFrame = tab, MainInfoFrame = tab and tab.MainInfoFrame }) do
		if type(f) == "table" then
			local keys = {}
			for k, x in pairs(f) do
				if type(k) == "string" and type(x) ~= "userdata" then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				local x = f[k]
				if type(x) == "function" then
					lines[#lines + 1] = label .. ":" .. k .. "()"
				elseif type(x) ~= "table" or not x.GetObjectType then
					lines[#lines + 1] = label .. "." .. k .. " = " .. say(x)
				end
			end
		end
	end
	local cur = _G.C_CurrencyInfo
	if cur and type(cur.GetCurrencyListSize) == "function" and type(cur.GetCurrencyListInfo) == "function" then
		local ok, n = pcall(cur.GetCurrencyListSize)
		for i = 1, (ok and tonumber(n) or 0) do
			local okI, info = pcall(cur.GetCurrencyListInfo, i)
			if okI and type(info) == "table" then
				lines[#lines + 1] = ("currency %d: %s = %s of %s (id %s)"):format(i, tostring(info.name),
					tostring(info.quantity), tostring(info.maxQuantity), tostring(info.currencyID))
			end
		end
	end
	-- THE LINE'S OWN READING, step by step (Josh 2026-09-29: "Still not
	-- showing up"): where the tab was found, what each label hands back and
	-- whether it is a secret, what the reading makes of it, and what is kept
	local function step(label, v) lines[#lines + 1] = "step " .. label .. ": " .. say(v) end
	step("CharacterFrame.PVPRankFrame", _G.CharacterFrame and _G.CharacterFrame.PVPRankFrame and "yes" or "no")
	step("_G.PVPRankFrame", type(_G.PVPRankFrame) == "table" and "yes" or tostring(_G.PVPRankFrame))
	local f = M.TabFields()
	step("TabFields", f and "found" or "nil")
	if f then
		for _, key in ipairs({ "CurrentRankField", "CurrentRankProgressField" }) do
			local fs = f[key]
			local ok, s = pcall(fs.GetText, fs)
			local isSecret = issecretvalue and issecretvalue(s) or false
			step(key .. " type", type(s) .. (isSecret and " (secret)" or ""))
			if not isSecret then
				step(key .. " text", s)
			end
			step(key .. " textOf", textOf(fs))
		end
	end
	step("FromTab", M.FromTab())
	local all, who = kept()
	step("who", who)
	step("kept", all and all[who])
	step("frame", M.frame and ("shown=" .. tostring(M.frame:IsShown())) or "none")
	step("shownFor", M.shownFor)
	step("watching", M.watching)
	step("enabled", BT.Enabled("pvp"))
	step("available / classic", tostring(M.Available()) .. " / " .. tostring(M.Classic()))
	lines[#lines + 1] = "this line reads: " .. say(M.Read())
	BT.EnsureBound()
	BeebModDB.pvpDump = {
		at = BT.Util.Now and BT.Util.Now() or 0,
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	return #lines
end
BT.Record("pvpDump", M.Dump, "pvp")

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("Your PvP rank, with its insignia, and your rank points towards the next rank. Point at the line for your honorable kills.")
	if not M.Available() then
		page:Note("This game has no PvP rank to read, so there is no line.", true)
	elseif not M.Classic() then
		page:Note("The game shows rank points only in the PvP tab of your character window, so BeebMod reads them there whenever the game writes them. If the line is missing, open that tab once.", true)
	end
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
