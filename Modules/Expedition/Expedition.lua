-- Nesingwary's Expedition: every enemy you have killed (Josh 2026-09-25).
--
-- A journal of every kind of enemy this character has killed - rares and elites
-- among them - with a count and a model of each, filed by creature type, and
-- commendations whose points are the score. One line of the dock says the
-- score and how far it is to the next milestone; a click on it opens the
-- journal (Window.lua). Kills are counted per character, and the journal
-- adds every character together at the flick of a switch.
--
--   Journal.lua   the book, the commendations and the arithmetic
--   Kills.lua     what counts as a kill, with no combat log to ask
--   Toast.lua     "Gold mastery · 150 kills", then "Barn Owl"
--   Window.lua    the journal
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Expedition/Expedition.lua")

local U = BT.Util
local J, K, T = BT.Expedition, BT.ExpeditionKills, BT.ExpeditionToast

local M = BT.Module({
	key = "expedition",
	feature = "expedition",
	-- (Nesingwary's Expedition to players, Josh 2026-09-27; see BT.FEATURES)
	title = "Nesingwary's Expedition",
	blurb = "A journal of the enemies you've killed",
	order = 38,
	-- A TAB OF ITS OWN (Josh 2026-09-25): on the right panel, so it goes where
	-- its tab is dragged, and its settings have a page to grow into
	dock = true,
})

local TEXT_H = 16
local BAR_H = 4
-- the same line as Experience and Reputation: text, then a thin bar
local LINE_H = TEXT_H + BAR_H + 9
local INSET = 6
-- YOUR BADGE AT THE START OF THE LINE (Josh 2026-09-29), where Level and
-- reputation have a shield of their own (BT.Dock.LineIcon)
-- how often the unit tokens are looked at: a death is seen within a fifth of
-- a second, and a look is a handful of reads per enemy in view
local SCAN_EVERY = 0.2

local WORDS = "|cff8a9894%s|r"
-- the Expedition's own colour: the blue of the loading screens' ink wash
M.INK = { 0.44, 0.64, 0.80 }

local big = BT.ExpeditionWindow.Big

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

-- the dock line's number: "points" or "kills"
function M.Shows()
	return (BT.settings and BT.settings.expeditionShows == "kills") and "kills" or "points"
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
		BT.ExpeditionWindow.Show(npc)
	end
end

function M.Kill(info, how)
	if not BT.Enabled("expedition") then
		return
	end
	local rankBefore = J.Rank((J.Score()))
	local new, news = J.Kill(info)
	local s = M.session
	if s then
		s.kills = (s.kills or 0) + 1
		s.new = (s.new or 0) + (new and 1 or 0)
		s.last = U.Now()
	end

	local name = info.name or ("#" .. info.npc)
	-- ON UNLESS SWITCHED OFF (Josh 2026-09-27: "this should be enabled by
	-- default for new players"): a new page in the journal says so
	if new and on("expeditionDiscover", true) then
		local _, worth = J.Worth(J.Store().enemies[info.npc])
		-- minor: it gives way in a full queue (T.Push)
		T.Push({ head = "New in the Field Journal", text = name, points = worth, icon = T.HunterIcon("discover"),
			onClick = openOn(info.npc), minor = true })
	end
	for _, a in ipairs(news or {}) do
		if a.mastery then
			T.Push({
				-- the milestone above, the enemy's name on a line of its own (Josh
				-- 2026-09-28: "10 kills on Blackwood Pathfin..." was cut off)
				head = ("%s mastery · %s %s"):format(a.name, big(a.need), a.need == 1 and "kill" or "kills"), text = name,
				points = a.points, icon = T.HunterIcon("mastery"), onClick = openOn(info.npc),
			})
		else
			T.Push({
				head = "Expedition commendation", text = a.title, points = a.points,
				icon = T.HunterIcon("commendation"),
				onClick = function() BT.ExpeditionWindow.ShowCommendation(a.id) end,
			})
		end
	end
	-- a new rank last, once everything that earned it has been shown
	-- (the score worked out once, and the dock's line drawn from it)
	local points, _, st = J.Score()
	local rank, title = J.Rank(points)
	if rank > rankBefore then
		M.RankToast(rank, title)
	end
	M.Update(points, st)
	BT.ExpeditionWindow.Changed()
end

K.onKill = M.Kill

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

-- THE RANK, NOT THE COUNT (Josh 2026-09-25): "Menagerie · Scholar", where
-- it said how many unique kills; those are on the hover
-- and no count after it (Josh 2026-09-29: "remove the '(2/10)' so
-- expidition matches the format of the other meters"): "Expedition ·
-- Tracker". Which of ten it is, is on the hover and the Commendations page.
function M.Lines(points, st)
	local _, title = J.Rank(points)
	local left = ("Expedition %s"):format(WORDS:format("· " .. title))
	local right
	if M.Shows() == "kills" then
		right = ("%s %s"):format(big(st.total), WORDS:format("kills"))
	else
		right = ("%s %s"):format(big(points), WORDS:format("pts"))
	end
	return left, right
end

-- `points` and `st` where the caller has just worked them out (M.Kill)
function M.Update(points, st)
	if not (M.frame and J.Store()) then
		return
	end
	if type(points) ~= "number" or type(st) ~= "table" then
		points, _, st = J.Score()
	end
	local left, right = M.Lines(points, st)
	M.text:SetText(left)
	M.eta:SetText(right)
	-- your rank's badge, or a rank previewed from the Testing page
	M.badge:SetTexture(J.RankBadge(BT.Dock.preview.expedition or (J.Rank(points))))

	local w = BT.Dock.LineBarWidth(M.frame, INSET)
	if w <= 0 then
		return
	end
	-- the bar: from this rank to the next, full at the top
	local _, _, prev, nextAt = J.Rank(points)
	local share = nextAt and (points - prev) / (nextAt - prev) or 1
	-- OWN COLOUR (Josh 2026-09-26): it wore Experience's accent, and two
	-- orange rows read as one; it takes the loading screens' ink blue, for
	-- its bar and for the band behind it
	local a = M.INK
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	BT.Dock.BandColor(M.frame, a)
	-- a texture of no width is drawn as a whole one, so an empty part is hidden
	M.fill:SetShown(share > 0)
	M.fill:SetWidth(math.max(1, w * math.min(1, share)))
end

-- (Josh 2026-09-27, the dock's tooltips redrawn, and "Much better" of the
-- plainer words) your rank and how far to the next, the masteries you are
-- closest to, and this session's hunting; a new character is told how to
-- start instead of shown rows of zeros
function M.Tip()
	if not (BT.Tip and J.Store()) then
		return
	end
	local points, _, st = J.Score()
	local s = M.session
	local feature = BT.Feature and BT.Feature("expedition")
	BT.Tip.Show(M.frame, { edge = feature and feature.color, build = function(t)
		local rank, title, at, nextAt, nextTitle = J.Rank(points)
		local me = UnitName and UnitName("player") or nil
		t:Header({ name = "Nesingwary's Expedition", sub = me and ("%s's journal"):format(me) or nil,
			pill = ("Rank %d / %d"):format(rank, #J.RANKS) })
		t:Title(title, (st.uniques or 0) > 0 and ("%s points"):format(big(points)) or nil)
		if (st.uniques or 0) == 0 then
			t:Note("No kills yet. Each unique kill is worth 1 point.")
			if nextAt then
				t:Section()
				t:Row("Next rank", ("%s at %s"):format(nextTitle, big(nextAt)))
			end
			t:Foot({ { "Click", "open the journal" } })
			return
		end
		if nextAt then
			local span = math.max(1, nextAt - at)
			t:Bar((points - at) / span, feature and feature.color)
			t:Scale(("%s to %s"):format(big(nextAt - points), nextTitle), big(nextAt))
		end
		local near = J.NextMasteries(J.Mine() and J.Mine().kills or {}, 3)
		if #near > 0 then
			t:Section("Closest masteries")
			local enemies = J.Store().enemies
			for _, nx in ipairs(near) do
				local enemy = enemies[nx.npc]
				local metal = J.Ladder(enemy)[nx.tier]
				t:Row(("%s · %s"):format((enemy and enemy.name) or ("#" .. nx.npc), metal.name),
					("%d / %d"):format(nx.have, nx.need), nil, { nx.have / math.max(1, nx.need), metal.color })
			end
		end
		if s and (s.kills or 0) > 0 then
			t:Section("This session")
			local hours = math.max(1 / 60, (U.Now() - (s.start or U.Now())) / 3600)
			t:Stats({
				{ big(s.kills), s.kills == 1 and "kill" or "kills" },
				{ "+" .. (s.new or 0), s.new == 1 and "unique kill" or "unique kills", (s.new or 0) > 0 and "good" or nil },
				{ big(math.floor(s.kills / hours + 0.5)), "an hour" },
			})
		end
		t:Foot({ { "Click", "open the journal" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("expedition", 8)
	M.frame.kind = "meter"
	M.frame.wantHeight = LINE_H
	-- the client draws nothing inside a frame with no height (see Perf)
	M.frame:SetHeight(LINE_H)
	M.text = BT.Widgets.Label(M.frame, "", "small")
	M.text:SetJustifyH("LEFT")
	M.badge = BT.Dock.LineIcon(M.frame, INSET)
	M.eta = BT.Widgets.Label(M.frame, "", "small")
	M.eta:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -3)
	M.eta:SetJustifyH("RIGHT")
	-- as tall as the left words, so both sit on one line (Josh 2026-09-29:
	-- the right side sat a pixel high, its height its own)
	M.eta:SetHeight(TEXT_H - 2)
	M.text:SetPoint("TOPRIGHT", M.eta, "TOPLEFT", -8, 0)
	M.text:SetHeight(TEXT_H - 2)
	M.text:SetWordWrap(false)
	M.track = M.frame:CreateTexture(nil, "BORDER")
	M.track:SetPoint("TOPRIGHT", M.frame, "TOPRIGHT", -INSET, -(TEXT_H + 3))
	BT.Dock.LineAfter(M.badge, M.text, M.track, TEXT_H)
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
			BT.ExpeditionWindow.Toggle()
		end
	end)
	return M.frame
end

-- ---------------------------------------------------------------------------
-- The quest log, for lore
-- ---------------------------------------------------------------------------
--
-- A quest's story is only to be had for the SELECTED quest (the client's own
-- log shows one at a time), so each quest not yet kept is selected, read,
-- and the selection put back - and never while the quest log is open in
-- front of you, where it would jump about. A quest is read once: after that
-- the journal has it (Journal.lua, J.QuestSeen).

local function questCount()
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
		if ok then
			return tonumber(n) or 0
		end
	end
	if GetNumQuestLogEntries then
		local ok, n = pcall(GetNumQuestLogEntries)
		return ok and tonumber(n) or 0
	end
	return 0
end

-- title, is it a heading, quest id
local function questEntry(i)
	if GetQuestLogTitle then
		local ok, title, _, _, isHeader, _, _, _, questID = pcall(GetQuestLogTitle, i)
		if ok then
			return title, isHeader, questID
		end
	end
	if C_QuestLog and C_QuestLog.GetInfo then
		local ok, info = pcall(C_QuestLog.GetInfo, i)
		if ok and type(info) == "table" then
			return info.title, info.isHeader, info.questID
		end
	end
	return nil
end

local function questObjectives(i, questID)
	local out = {}
	if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
		local ok, n = pcall(GetNumQuestLeaderBoards, i)
		for j = 1, (ok and tonumber(n) or 0) do
			local okT, text = pcall(GetQuestLogLeaderBoard, j, i)
			if okT and type(text) == "string" and text ~= "" then
				out[#out + 1] = text
			end
		end
	end
	if #out == 0 and questID and C_QuestLog and C_QuestLog.GetNumQuestObjectives and GetQuestObjectiveInfo then
		local ok, n = pcall(C_QuestLog.GetNumQuestObjectives, questID)
		for j = 1, (ok and tonumber(n) or 0) do
			local okT, text = pcall(GetQuestObjectiveInfo, questID, j, false)
			if okT and type(text) == "string" and text ~= "" then
				out[#out + 1] = text
			end
		end
	end
	return out
end

local function select_(i, questID)
	if SelectQuestLogEntry then
		return pcall(SelectQuestLogEntry, i)
	elseif C_QuestLog and C_QuestLog.SetSelectedQuest and questID then
		return pcall(C_QuestLog.SetSelectedQuest, questID)
	end
	return false
end

local function logOpen()
	for _, name in ipairs({ "QuestLogFrame", "QuestLogDetailFrame", "QuestMapFrame", "WorldMapFrame" }) do
		local f = _G[name]
		if f and f.IsShown and f:IsShown() then
			return true
		end
	end
	return false
end

-- Read every quest in the log the journal has not kept yet. Returns how
-- many were read.
function M.ReadQuests()
	local s = J.Store()
	if not s or logOpen() or type(GetQuestLogQuestText) ~= "function" then
		return 0
	end
	s.quests = s.quests or {}
	local was = GetQuestLogSelection and select(2, pcall(GetQuestLogSelection))
	local wasID = C_QuestLog and C_QuestLog.GetSelectedQuest and select(2, pcall(C_QuestLog.GetSelectedQuest))
	local read, lore, moved = 0, 0, false
	for i = 1, questCount() do
		local title, isHeader, questID = questEntry(i)
		if title and not isHeader and questID and not s.quests[questID] and select_(i, questID) then
			moved = true
			local ok, text = pcall(GetQuestLogQuestText, i)
			if ok and type(text) == "string" and text ~= "" then
				lore = lore + J.QuestSeen({ id = questID, title = title, text = text,
					objectives = questObjectives(i, questID) })
				read = read + 1
			end
		end
	end
	-- the selection put back as it was: whenever it moved, a quest whose
	-- story came back empty too
	if moved then
		if type(was) == "number" and SelectQuestLogEntry then
			pcall(SelectQuestLogEntry, was)
		elseif type(wasID) == "number" and C_QuestLog and C_QuestLog.SetSelectedQuest then
			pcall(C_QuestLog.SetSelectedQuest, wasID)
		end
	end
	if lore > 0 then
		BT.ExpeditionWindow.Changed()
	end
	return read, lore
end

-- the log changes often; read it a beat after it settles, not every time
function M.QuestsChanged()
	if M.questsPending or not (C_Timer and C_Timer.After) then
		return
	end
	M.questsPending = true
	C_Timer.After(2, function()
		M.questsPending = nil
		if BT.Enabled("expedition") then
			M.ReadQuests()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

M.events = CreateFrame("Frame")
-- the loading screen is heard whatever the switch says: it opens the session
pcall(M.events.RegisterEvent, M.events, "PLAYER_ENTERING_WORLD")

-- QUIET WHILE OFF (Josh 2026-09-30, review). Every unit's health reached
-- this frame whether the Expedition was on or not, to be turned away one by one. They are heard while it is
-- on: from its OnBind or OnEnable, until its OnDisable.
local HEARD = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH", "UNIT_FLAGS",
	"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CHAT_MSG_COMBAT_XP_GAIN", "LOOT_READY", "QUEST_ACCEPTED",
	"QUEST_LOG_UPDATE", "ENCOUNTER_END" }
function M.Listen(on)
	on = on and true or false
	if M.listening == on then
		return
	end
	M.listening = on
	local ev = M.events
	for _, event in ipairs(HEARD) do
		pcall(on and ev.RegisterEvent or ev.UnregisterEvent, ev, event)
	end
	-- your own casts, for Pick Pocket (Modules/Expedition/Kills.lua, K.Cast)
	if on then
		local ok = ev.RegisterUnitEvent and pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
		if not ok then
			pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED")
		end
	else
		pcall(ev.UnregisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED")
	end
end

M.events:SetScript("OnEvent", function(_, event, a, b, c, d, e)
	if not BT.Enabled("expedition") then
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
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if a == "player" then
			K.Cast(c)
		end
	elseif event == "LOOT_READY" then
		K.Loot()
	elseif event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, a, b)
		M.QuestsChanged()
	elseif event == "QUEST_ACCEPTED" or event == "QUEST_LOG_UPDATE" then
		M.QuestsChanged()
	elseif event == "ENCOUNTER_END" then
		-- id, name, difficulty, group size, success: a boss beaten is a boss
		-- (J.Category), its kill counted by its death as any other
		if e == 1 or e == true then
			J.EncounterWon(b)
		end
	end
end)

function M.Show(show)
	local frame = M.Build()
	if show then
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(SCAN_EVERY, function()
				if BT.Enabled("expedition") then
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
		BT.ExpeditionWindow.Hide()
	end
	BT.Dock.Relayout()
end

function M:OnEnable()
	M.Listen(true)
	K.Reset(J.Counted())
	M.Show(true)
	BT.Session.Ensure(M)
end

-- a book was bound: the GUIDs this character counted before a reload are
-- still counted, and the enemies in view are looked at afresh
function M:OnBind()
	M.Listen(true)
	-- two pages for one enemy, from before they were one (J.MergeSame)
	J.MergeSame()
	K.Reset(J.Counted())
	M.Show(true)
end

function M:OnDisable()
	M.Listen(false)
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	-- the feature's picture first, as every feature's page has (UI/Window.lua)
	local art
	art, panel.picture = BT.Window.FeatureArt(panel, "expedition")
	if art then
		page:Add(art)
	end
	page:Note("Every enemy you kill goes in the journal, with its kill count and a model of it. "
		.. "Unique kills, masteries and commendations are worth points. Your points set your Expedition rank.")
	page:Note("A kill counts when an enemy you tagged and fought dies in view, or when the game gives you "
		.. "experience or loot for it. Click the Expedition line in the dock to open the journal.", true)

	local journal = page:Section("The field journal")
	local open = W.Row(journal, "Open the Expedition", "The Field Journal and Commendations, or type /bt expedition")
	open:SetControl(W.Button(open, "Open", 80, 20)):SetScript("OnClick", function()
		BT.ExpeditionWindow.Show()
	end)

	local toasts = page:Section("Toasts")
	W.SwitchRow(toasts, "Commendations, masteries and ranks", "Shows a toast at the top of the screen when you earn one",
		function() return on("expeditionToasts", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.expeditionToasts = v and true or false
		end)
	W.SwitchRow(toasts, "Every unique kill", "Shows a toast when an enemy goes in the journal for the first time",
		function() return on("expeditionDiscover", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.expeditionDiscover = v and true or false
		end)
	W.SwitchRow(toasts, "Sound", "Plays the game's achievement sound with each toast",
		function() return on("expeditionSound", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.expeditionSound = v and true or false
		end)
	-- THE WIKI'S CREDIT, ONCE (Josh 2026-09-28: "Let's move the credit line to
	-- the expedition's setting page"). Most descriptions are the Warcraft
	-- Wiki's own sentences, and the rest are rewritten from them, so CC BY-SA
	-- 3.0 asks for the source and the licence to be named. Here, not under
	-- every enemy.
	page:Note("The journal's descriptions come from the Warcraft Wiki (warcraft.wiki.gg), "
		.. "some of them rewritten, under the CC BY-SA 3.0 licence.", true)
	page:Note("An enemy's abilities come from the VMaNGOS database (github.com/vmangos), "
		.. "under the GPL 2.0 licence.", true)
	page:Layout()
end

-- ITS LINE IN THE DOCK (Josh 2026-09-27): what the line shows is on the
-- Expedition's tab in the Dock's block, which is dragged to move the line
function M:BuildDockTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	local line = page:Section("The line")
	local shows = W.Row(line, "It shows", "Your Expedition points, or how many enemies you have killed")
	self.shows = shows:SetControl(W.Segmented(shows, { { "points", "Points" }, { "kills", "Kills" } },
		function(key)
			BT.EnsureBound()
			BT.settings.expeditionShows = key
			M.Update()
		end, 62))
	page:Note("Click the line to open the journal. Drag this tab on the rail to move the line in the dock.", true)
	page:Layout()
	self:RefreshTab()
end

function M:RefreshDockTab()
	self:RefreshTab()
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

-- A SAMPLE TOAST (Josh 2026-09-28: "I'd actually prefer to use the 'Testing'
-- module with buttons/toggles going forward"): what /bt expedition toast
-- showed, from the Testing page. A Platinum mastery on the last enemy you
-- killed, or on a Barn Owl before you have killed anything.
function M.SampleToast()
	local c = J.Mine()
	local last = c and c.last and J.Store().enemies[c.last.npc]
	T.Push({
		head = "Platinum mastery · 500 kills", text = last and last.name or "Barn Owl",
		points = 10, icon = T.HunterIcon("mastery"),
	})
end

-- a new rank's toast, with its badge; a click opens the Commendations page
function M.RankToast(rank, title)
	return T.Push({
		head = "Expedition rank", text = ("%s %s"):format(title, WORDS:format(("· rank %d of %d")
			:format(rank, #J.RANKS))),
		icon = T.RANK_ICON, badge = J.RankBadge(rank),
		onClick = function() BT.ExpeditionWindow.Show(nil, "commendations") end,
	})
end

-- the Testing page's rank toast: yours, as if just reached
function M.SampleRankToast()
	local rank, title = J.Rank((J.Score()))
	return M.RankToast(rank, title)
end

-- /bt expedition, and the old name still (Josh 2026-09-27): only the new one
-- is in /bt's list
local function command()
	BT.ExpeditionWindow.Toggle()
end

BT.Command("expedition", command, "open the journal of every enemy you have killed", "expedition")
BT.Command("menagerie", command, nil, "expedition")
