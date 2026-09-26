-- The Menagerie: every kind of mob you have killed (Josh 2026-09-25).
--
-- A journal of every kind of mob this character has killed - rares and elites
-- among them - with a count and a model of each, filed by creature type, and
-- achievements whose points are the score. One line of the dock says the
-- score and how far it is to the next milestone; a click on it opens the
-- journal (Window.lua). Kills are counted per character, and the journal
-- adds every character together at the flick of a switch.
--
--   Journal.lua   the book, the achievements and the arithmetic
--   Kills.lua     what counts as a kill, with no combat log to ask
--   Toast.lua     "1000 kills on Barn Owl!"
--   Window.lua    the journal
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Menagerie.lua")

local U = BT.Util
local J, K, T = BT.Menagerie, BT.MenagerieKills, BT.MenagerieToast

local M = BT.Module({
	key = "menagerie",
	group = "dock",
	-- on the Progress page, beside Experience and Reputation
	onPage = "progress",
	title = "Menagerie",
	blurb = "every kind of mob you have killed, and achievements for it",
	order = 38,
	dock = true,
})

local TEXT_H = 16
local BAR_H = 4
-- the same line as Experience and Reputation: text, then a thin bar
local LINE_H = TEXT_H + BAR_H + 9
local INSET = 6
-- how often the unit tokens are looked at: a death is seen within a fifth of
-- a second, and a look is a handful of reads per mob in view
local SCAN_EVERY = 0.2

local WORDS = "|cff8a9894%s|r"

local big = BT.MenagerieWindow.Big

-- the last few kills and how each was known, for /bt menagerie debug
M.recent = {}

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

-- the dock line's number: "points" or "kills"
function M.Shows()
	return (BT.settings and BT.settings.menagerieShows == "kills") and "kills" or "points"
end

local function on(key, default)
	local v = BT.settings and BT.settings[key]
	if v == nil then
		return default
	end
	return v and true or false
end

-- ---------------------------------------------------------------------------
-- A kill
-- ---------------------------------------------------------------------------

-- the session: kills since login, carried through a reload (Core/Session.lua)
function M.Start(initial, reloading)
	local s = J.Store()
	if not s then
		return nil
	end
	s.sessions = s.sessions or {}
	M.session = BT.Session.Open(s.sessions, initial, reloading, function(now)
		return { start = now, kills = 0, new = 0 }
	end)
	M.Update()
	return M.session
end

local function openOn(npc)
	return function()
		BT.MenagerieWindow.Show(npc)
	end
end

function M.Kill(info, how)
	if not BT.Enabled("menagerie") then
		return
	end
	local new, news = J.Kill(info)
	local s = M.session
	if s then
		s.kills = (s.kills or 0) + 1
		s.new = (s.new or 0) + (new and 1 or 0)
		s.last = U.Now()
	end
	table.insert(M.recent, 1, ("%s (%s) by %s%s"):format(info.name or "?", tostring(info.npc), how,
		new and ", new" or ""))
	M.recent[21] = nil

	local icon = T.Icon(info.kind)
	local name = info.name or ("#" .. info.npc)
	if new and on("menagerieDiscover", false) then
		T.Push({ head = "New to the Menagerie", text = name, icon = icon, onClick = openOn(info.npc) })
	end
	for _, a in ipairs(news or {}) do
		if a.record then
			T.Push({
				head = "Kill Record!", text = ("%s kills on %s!"):format(big(a.need), name),
				points = a.points, icon = icon, onClick = openOn(info.npc),
			})
		else
			T.Push({
				head = "Menagerie achievement", text = a.title, points = a.points,
				icon = a.kind and T.Icon(a.kind) or icon,
				onClick = function() BT.MenagerieWindow.Show(nil, "achievements") end,
			})
		end
	end
	M.Update()
	BT.MenagerieWindow.Changed()
end

K.onKill = M.Kill

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

function M.Lines(points, st)
	local left = ("Menagerie %s"):format(WORDS:format(("· %s kinds"):format(big(st.kinds))))
	local right
	if M.Shows() == "kills" then
		right = ("%s %s"):format(big(st.total), WORDS:format("kills"))
	else
		right = ("%s %s"):format(big(points), WORDS:format("pts"))
	end
	return left, right
end

function M.Update()
	if not (M.frame and J.Store()) then
		return
	end
	local points, _, st = J.Score("char")
	local left, right = M.Lines(points, st)
	M.text:SetText(left)
	M.eta:SetText(right)

	local w = BT.Pill.Number(M.frame:GetWidth(), 0) - INSET * 2
	if w <= 0 then
		return
	end
	-- the bar: from the last discovery milestone to the next
	local prev, nextAt = J.NextDiscovery(st.kinds)
	local share = nextAt and (st.kinds - prev) / (nextAt - prev) or 1
	local a = BT.Widgets.ACCENT
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	-- a texture of no width is drawn as a whole one, so an empty part is hidden
	M.fill:SetShown(share > 0)
	M.fill:SetWidth(math.max(1, w * math.min(1, share)))
end

function M.Tip()
	if not (GameTooltip and BT.Bar and BT.Bar.Tip and J.Store()) then
		return
	end
	local points, count, st = J.Score("char")
	local allPoints, _, all = J.Score("account")
	local s = M.session
	BT.Bar.Tip(M.frame, function()
		local grey = { 0.7, 0.75, 0.73 }
		local function pair(l, r)
			GameTooltip:AddDoubleLine(l, r, grey[1], grey[2], grey[3], 1, 1, 1)
		end
		GameTooltip:AddLine("Menagerie", 1, 1, 1)
		pair("points", ("%s · %d achievements"):format(big(points), count))
		pair("kinds of mob", big(st.kinds))
		pair("kills", big(st.total))
		if s and (s.kills or 0) > 0 then
			pair("this session", ("%s kills · %d new"):format(big(s.kills), s.new or 0))
		end
		if all.kinds ~= st.kinds or allPoints ~= points then
			pair("all characters", ("%s points · %s kinds"):format(big(allPoints), big(all.kinds)))
		end
		local _, nextAt, title = J.NextDiscovery(st.kinds)
		if nextAt then
			pair("next", ("%s at %d kinds · %d to go"):format(title, nextAt, nextAt - st.kinds))
		end
		GameTooltip:AddLine("click for the journal", 0.5, 0.55, 0.53)
	end)
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.Section("menagerie", 8)
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
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			BT.MenagerieWindow.Toggle()
		end
	end)
	return M.frame
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

M.events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH", "UNIT_FLAGS",
	"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CHAT_MSG_COMBAT_XP_GAIN", "LOOT_READY",
	"PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, a, b)
	if not BT.Enabled("menagerie") then
		return
	end
	if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
		if K.Watched(a) then
			K.Observe(a)
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		K.PlateAdded(a)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		K.PlateRemoved(a)
	elseif event == "PLAYER_TARGET_CHANGED" then
		K.Observe("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		K.Observe("mouseover")
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		K.XP(a)
	elseif event == "LOOT_READY" then
		K.Loot()
	elseif event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, a, b)
	end
end)

function M.Show(show)
	local frame = M.Build()
	if show then
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(SCAN_EVERY, function()
				if BT.Enabled("menagerie") then
					K.Scan()
				end
			end)
		end
	else
		frame:Hide()
		if M.ticker then
			M.ticker:Cancel()
			M.ticker = nil
		end
		BT.MenagerieWindow.Hide()
	end
	BT.Bar.Relayout()
end

function M:OnEnable()
	K.Reset(J.Counted())
	M.Show(true)
	BT.Session.Ensure(M)
end

-- a book was bound: the GUIDs this character counted before a reload are
-- still counted, and the mobs in view are looked at afresh
function M:OnBind()
	K.Reset(J.Counted())
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	page:Note("every kind of mob you kill, with a count and a model of each, filed by creature type - "
		.. "and achievements for it, whose points are the score")
	page:Note("counted when a mob you tagged and fought dies in view, or when the game gives you "
		.. "experience or loot for it · click the Menagerie line in the dock for the journal", true)

	local journal = page:Section("The journal")
	local open = W.Row(journal, "Open the Menagerie", "the bestiary and the achievements · /bt menagerie")
	open:SetControl(W.Button(open, "Open", 80, 20)):SetScript("OnClick", function()
		BT.MenagerieWindow.Show()
	end)
	local shows = W.Row(journal, "The dock line shows", "your achievement points, or every kill")
	self.shows = shows:SetControl(W.Segmented(shows, { { "points", "Points" }, { "kills", "Kills" } },
		function(key)
			BT.EnsureBound()
			BT.settings.menagerieShows = key
			M.Update()
		end, 62))

	local toasts = page:Section("Toasts")
	W.SwitchRow(toasts, "Achievements and kill records", "a toast at the top of the screen when you earn one",
		function() return on("menagerieToasts", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieToasts = v and true or false
		end)
	W.SwitchRow(toasts, "Every new kind of mob", "a toast for each new page in the journal, too",
		function() return on("menagerieDiscover", false) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieDiscover = v and true or false
		end)
	W.SwitchRow(toasts, "Sound", "the game's achievement chime with each toast",
		function() return on("menagerieSound", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieSound = v and true or false
		end)
	page:Layout()
end

function M:RefreshTab()
	if self.shows then
		self.shows:Select(M.Shows())
	end
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

BT.Command("menagerie", function(rest)
	local cmd = (rest or ""):lower():match("^(%S*)")
	if cmd == "debug" then
		local st = K.stats
		U.Print(("menagerie: watched %d · counted by death %d, xp %d, loot %d · xp lines that were "
			.. "receipts %d, unmatched %d · deaths not ours %d"):format(st.watched or 0, st.dead or 0,
			st.xp or 0, st.loot or 0, st.confirmed or 0, st.xpUnmatched or 0, st.notOurs or 0))
		for i = 1, math.min(10, #M.recent) do
			U.Print("  " .. M.recent[i])
		end
		return
	elseif cmd == "toast" then
		local c = J.Mine()
		local last = c and c.last and J.Store().mobs[c.last.npc]
		T.Push({
			head = "Kill Record!", text = ("1000 kills on %s!"):format(last and last.name or "Barn Owl"),
			points = 20, icon = T.Icon(last and last.kind),
		})
		return
	end
	BT.MenagerieWindow.Toggle()
end, "menagerie [debug|toast] - the journal of every mob you have killed", "menagerie")
