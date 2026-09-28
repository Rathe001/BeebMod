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
--   Toast.lua     "Gold mastery! 150 kills on Barn Owl"
--   Window.lua    the journal
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Menagerie.lua")

local U = BT.Util
local J, K, T = BT.Menagerie, BT.MenagerieKills, BT.MenagerieToast

local M = BT.Module({
	key = "menagerie",
	feature = "menagerie",
	-- (Nesingwary's Expedition to players, Josh 2026-09-27; see BT.FEATURES)
	title = "Nesingwary's Expedition",
	blurb = "Every kind of mob you kill, and commendations for it",
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
-- how often the unit tokens are looked at: a death is seen within a fifth of
-- a second, and a look is a handful of reads per mob in view
local SCAN_EVERY = 0.2

local WORDS = "|cff8a9894%s|r"
-- the Menagerie's own colour: the blue of the loading screens' ink wash
M.INK = { 0.44, 0.64, 0.80 }

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
	local rankBefore = J.Rank((J.Score("char")))
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
	-- ON UNLESS SWITCHED OFF (Josh 2026-09-27: "this should be enabled by
	-- default for new players"): a new page in the journal says so
	if new and on("menagerieDiscover", true) then
		local _, worth = J.Worth(J.Store().mobs[info.npc])
		-- minor: it gives way in a full queue (T.Push)
		T.Push({ head = "New in the Field Journal", text = name, points = worth, icon = icon,
			onClick = openOn(info.npc), minor = true })
	end
	for _, a in ipairs(news or {}) do
		if a.mastery then
			T.Push({
				head = ("%s mastery!"):format(a.name), text = ("%s %s on %s"):format(big(a.need), a.need == 1 and "kill" or "kills", name),
				points = a.points, icon = icon, onClick = openOn(info.npc),
			})
		else
			T.Push({
				head = "Expedition commendation", text = a.title, points = a.points,
				icon = a.kind and T.Icon(a.kind) or icon,
				onClick = function() BT.MenagerieWindow.Show(nil, "achievements") end,
			})
		end
	end
	-- a new rank last, once everything that earned it has been shown
	local rank, title = J.Rank((J.Score("char")))
	if rank > rankBefore then
		T.Push({
			head = "Expedition rank", text = ("%s %s"):format(title, WORDS:format(("· rank %d of %d")
				:format(rank, #J.RANKS))),
			icon = T.RANK_ICON, onClick = function() BT.MenagerieWindow.Show(nil, "achievements") end,
		})
	end
	M.Update()
	BT.MenagerieWindow.Changed()
end

K.onKill = M.Kill

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

-- THE RANK, NOT THE COUNT (Josh 2026-09-25): "Menagerie · Scholar", where
-- it said how many kinds; the kinds are on the hover
-- and where that rank stands (Josh 2026-09-25: "Novice (1/10)", so a player
-- has an idea how far up it is)
function M.Lines(points, st)
	local rank, title = J.Rank(points)
	local left = ("Expedition %s"):format(WORDS:format(("· %s (%d/%d)"):format(title, rank, #J.RANKS)))
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
	-- the bar: from this rank to the next, full at the top
	local _, _, prev, nextAt = J.Rank(points)
	local share = nextAt and (points - prev) / (nextAt - prev) or 1
	-- OWN COLOUR (Josh 2026-09-26): it wore Experience's accent, and two
	-- orange rows read as one; it takes the loading screens' ink blue, for
	-- its bar and for the band behind it
	local a = M.INK
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	BT.Bar.BandColor(M.frame, a)
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
	local points, _, st = J.Score("char")
	local s = M.session
	local feature = BT.Feature and BT.Feature("menagerie")
	BT.Tip.Show(M.frame, { edge = feature and feature.color, build = function(t)
		local rank, title, at, nextAt, nextTitle = J.Rank(points)
		local me = UnitName and UnitName("player") or nil
		t:Header({ name = "Nesingwary's Expedition", sub = me and ("%s's journal"):format(me) or nil,
			pill = ("Rank %d / %d"):format(rank, #J.RANKS) })
		t:Title(title, (st.kinds or 0) > 0 and ("%s points"):format(big(points)) or nil)
		if (st.kinds or 0) == 0 then
			t:Note("No kills yet. Each new kind of mob you kill is worth 1 point.")
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
			local mobs = J.Store().mobs
			for _, nx in ipairs(near) do
				local mob = mobs[nx.npc]
				local metal = J.Ladder(mob)[nx.tier]
				t:Row(("%s · %s"):format((mob and mob.name) or ("#" .. nx.npc), metal.name),
					("%d / %d"):format(nx.have, nx.need), nil, { nx.have / math.max(1, nx.need), metal.color })
			end
		end
		if s and (s.kills or 0) > 0 then
			t:Section("This session")
			local hours = math.max(1 / 60, (U.Now() - (s.start or U.Now())) / 3600)
			t:Stats({
				{ big(s.kills), s.kills == 1 and "kill" or "kills" },
				{ "+" .. (s.new or 0), s.new == 1 and "new kind" or "new kinds", (s.new or 0) > 0 and "good" or nil },
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
	local read, lore = 0, 0
	for i = 1, questCount() do
		local title, isHeader, questID = questEntry(i)
		if title and not isHeader and questID and not s.quests[questID] and select_(i, questID) then
			local ok, text = pcall(GetQuestLogQuestText, i)
			if ok and type(text) == "string" and text ~= "" then
				lore = lore + J.QuestSeen({ id = questID, title = title, text = text,
					objectives = questObjectives(i, questID) })
				read = read + 1
			end
		end
	end
	-- the selection put back as it was
	if read > 0 then
		if type(was) == "number" and SelectQuestLogEntry then
			pcall(SelectQuestLogEntry, was)
		elseif type(wasID) == "number" and C_QuestLog and C_QuestLog.SetSelectedQuest then
			pcall(C_QuestLog.SetSelectedQuest, wasID)
		end
	end
	if lore > 0 then
		BT.MenagerieWindow.Changed()
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
		if BT.Enabled("menagerie") then
			M.ReadQuests()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

M.events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH", "UNIT_FLAGS",
	"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CHAT_MSG_COMBAT_XP_GAIN", "LOOT_READY", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE",
	"PLAYER_ENTERING_WORLD", "ENCOUNTER_END" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
-- your own casts, for Pick Pocket (Modules/Menagerie/Kills.lua, K.Cast)
do
	local ok = M.events.RegisterUnitEvent
		and pcall(M.events.RegisterUnitEvent, M.events, "UNIT_SPELLCAST_SUCCEEDED", "player")
	if not ok then
		pcall(M.events.RegisterEvent, M.events, "UNIT_SPELLCAST_SUCCEEDED")
	end
end
M.events:SetScript("OnEvent", function(_, event, a, b, c, d, e)
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
	page:Note("Every kind of mob you kill goes in the journal, with its kill count and a model of it. "
		.. "Kinds, masteries and commendations are worth points. Your points set your Expedition rank.")
	page:Note("A kill counts when a mob you tagged and fought dies in view, or when the game gives you "
		.. "experience or loot for it. Click the Expedition line in the dock to open the journal.", true)

	local journal = page:Section("The field journal")
	local open = W.Row(journal, "Open the Expedition", "The Field Journal and Commendations, or type /bt expedition")
	open:SetControl(W.Button(open, "Open", 80, 20)):SetScript("OnClick", function()
		BT.MenagerieWindow.Show()
	end)

	local toasts = page:Section("Toasts")
	W.SwitchRow(toasts, "Commendations, masteries and ranks", "Shows a toast at the top of the screen when you earn one",
		function() return on("menagerieToasts", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieToasts = v and true or false
		end)
	W.SwitchRow(toasts, "Every new kind of mob", "Shows a toast when a new kind of mob goes in the journal",
		function() return on("menagerieDiscover", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieDiscover = v and true or false
		end)
	W.SwitchRow(toasts, "Sound", "Plays the game's achievement sound with each toast",
		function() return on("menagerieSound", true) end,
		function(v)
			BT.EnsureBound()
			BT.settings.menagerieSound = v and true or false
		end)
	page:Layout()
end

-- ITS LINE IN THE DOCK (Josh 2026-09-27): what the line shows is on the
-- Menagerie's tab in the Dock's block, which is dragged to move the line
function M:BuildDockTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	local line = page:Section("The line")
	local shows = W.Row(line, "It shows", "Your Expedition points, or how many mobs you have killed")
	self.shows = shows:SetControl(W.Segmented(shows, { { "points", "Points" }, { "kills", "Kills" } },
		function(key)
			BT.EnsureBound()
			BT.settings.menagerieShows = key
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

local function command(rest)
	local cmd = (rest or ""):lower():match("^(%S*)")
	if cmd == "debug" then
		local st = K.stats
		U.Print(("Expedition: watched %d · counted by death %d, by XP %d, by loot %d · XP lines for kills "
			.. "already counted %d, unmatched %d · deaths that weren't yours %d"):format(st.watched or 0, st.dead or 0,
			st.xp or 0, st.loot or 0, st.confirmed or 0, st.xpUnmatched or 0, st.notOurs or 0))
		for i = 1, math.min(10, #M.recent) do
			U.Print("  " .. M.recent[i])
		end
		-- whether the card portraits could be held still, and how
		local how = BT.MenagerieWindow.freezeWith
		U.Print(("Expedition: portraits %s · effects %s"):format(how == nil and "not drawn yet (open the journal first)"
			or how == false and "keep moving, since the game gives no way to hold them still"
			or ("held still by %s"):format(how),
			BT.MenagerieWindow.canHideEffects and "can be switched off (SetParticlesEnabled)"
				or "cannot be switched off"))
		return
	elseif cmd == "edge" then
		-- A FACE AT THE GRID'S EDGE (Josh 2026-09-27): held back until wholly
		-- in view, or drawn whole for the grid to clip - which only the game
		-- can show works. Each asking changes it.
		BT.EnsureBound()
		local show = BT.settings.menagerieEdge ~= "show"
		BT.settings.menagerieEdge = show and "show" or nil
		if BT.MenagerieWindow.IsShown and BT.MenagerieWindow.IsShown() then
			BT.MenagerieWindow.Deal()
		end
		U.Print(show and "Expedition: portraits at the grid's edge now show in full. If one spills past the grid, "
			.. "type /bt expedition edge again." or "Expedition: portraits at the grid's edge now show only when fully in view.")
		return
	elseif cmd == "lore" then
		-- WHERE EACH MOB'S LORE CAME FROM (Josh 2026-09-26: "Is there a way we
		-- can make sure we're matching the mob properly with the lore?"):
		-- every mob, the page it leads with, and how that page was found. A
		-- mob that got no nearer than its type is one the wiki data lacks,
		-- or that has no page: run scripts/fetch-lore.ps1 and /reload.
		BT.EnsureBound()
		local s = J.Store()
		local list = {}
		for _, m in pairs(s and s.mobs or {}) do
			list[#list + 1] = m
		end
		table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
		local HOW = { name = "its own page", part = "part of its name", says = "its page says so",
			body = "same body as a known one", family = "its family", type = "only its type" }
		local lines, vague = {}, 0
		for _, m in ipairs(list) do
			local e = J.WikiLore(m)[1]
			local line
			if not e then
				line = ("%s: no page"):format(m.name or "?")
				vague = vague + 1
			else
				line = ("%s: %s (%s, %s)"):format(m.name or "?", e.title, e.kind, HOW[e.how] or e.how or "?")
				if e.how == "type" or e.how == "family" then
					vague = vague + 1
				end
			end
			lines[#lines + 1] = line
			U.Print("  " .. line)
		end
		U.Print(("Expedition: lore for %d mobs, %d with nothing nearer than their family or type. "
			.. "Type /reload to save the list."):format(#list, vague))
		BT.settings.menagerieLoreReport = lines
		return
	elseif cmd == "model" then
		-- what the client will do with the camera on a mob's page, written
		-- into the saved file as well, since it is a wall of numbers
		local lines = BT.MenagerieWindow.ModelReport()
		if not lines then
			U.Print("Expedition: open a mob's page in the journal first.")
			return
		end
		for _, line in ipairs(lines) do
			U.Print("  " .. line)
		end
		BT.EnsureBound()
		BT.settings.menagerieModelReport = lines
		U.Print("Expedition: model report written. Type /reload to save it.")
		return
	elseif cmd == "map" then
		-- what the client says about maps, for the cards' backgrounds
		local lines = {}
		local function say(fmt, ...)
			lines[#lines + 1] = fmt:format(...)
		end
		local calls = {}
		for _, name in ipairs({ "GetBestMapForUnit", "GetPlayerMapPosition", "GetMapInfo", "GetMapArtLayers",
			"GetMapArtLayerTextures" }) do
			calls[#calls + 1] = ("%s %s"):format(name, (C_Map and type(C_Map[name]) == "function") and "yes" or "NO")
		end
		say("calls: %s", table.concat(calls, " · "))
		local map, x, y = K.Where()
		local info = map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, map))
		say("here: map %s (%s) at %s, %s", tostring(map), type(info) == "table" and tostring(info.name) or "?",
			x and ("%.3f"):format(x) or "no position", y and ("%.3f"):format(y) or "-")
		local art = map and BT.MenagerieWindow.MapArt(map)
		if art then
			say("art: %d x %d in tiles of %d x %d, %d across, %d tiles, first %s", art.lw, art.lh, art.tw, art.th,
				art.cols, #art.files, tostring(art.files[1]))
		else
			say("art: none for this map")
		end
		local spots, all = 0, 0
		for _, m in pairs(J.Store().mobs) do
			all = all + 1
			if m.mx then
				spots = spots + 1
			end
		end
		say("journal: %d of %d kinds have a spot on the map (a kind gets one on its next kill)", spots, all)
		for _, line in ipairs(lines) do
			U.Print("  " .. line)
		end
		BT.EnsureBound()
		BT.settings.menagerieMapReport = lines
		return
	elseif cmd == "scene" then
		-- THE CHARACTER SHEET'S SCENE (Josh 2026-09-26: "the default character
		-- sheet has a background... could we maybe use that?"). What the
		-- client hangs behind your own model - which our character sheet takes
		-- off (Modules/CharSheet) - and which races' scenes this client has,
		-- as files or as atlases, for the cards and the model page.
		local lines = {}
		local function say(fmt, ...)
			lines[#lines + 1] = fmt:format(...)
		end
		local function describe(label, t)
			if type(t) ~= "table" or type(t.GetTexture) ~= "function" then
				return
			end
			local _, tex = pcall(t.GetTexture, t)
			local _, file = pcall(t.GetTextureFileID or function() return nil end, t)
			local _, atlas = pcall(t.GetAtlas or function() return nil end, t)
			local okC, l, r, top, bottom = pcall(t.GetTexCoord, t)
			say("%s: texture %s · file %s · atlas %s · coords %s", label, tostring(tex), tostring(file),
				tostring(atlas), okC and ("%.2f %.2f %.2f %.2f"):format(l or 0, r or 0, top or 0, bottom or 0) or "?")
		end
		local scene = _G.CharacterModelScene
		if scene then
			for key, v in pairs(scene) do
				if type(v) == "table" and type(key) == "string" and key:find("Background") then
					describe("CharacterModelScene." .. key, v)
				end
			end
			local ok, regions = pcall(function() return { scene:GetRegions() } end)
			for i, r in ipairs(ok and regions or {}) do
				describe(("CharacterModelScene region %d"):format(i), r)
			end
		else
			say("CharacterModelScene: not there")
		end
		for _, name in ipairs({ "CharacterModelFrameBackgroundTopLeft", "CharacterModelFrameBackgroundTopRight",
			"CharacterModelFrameBackgroundBotLeft", "CharacterModelFrameBackgroundBotRight" }) do
			describe(name, _G[name])
		end
		-- every race's scene, both ways the client might keep it
		local fileOf = GetFileIDFromPath
		local atlasOf = C_Texture and C_Texture.GetAtlasInfo
		for _, race in ipairs({ "Human", "Dwarf", "NightElf", "Gnome", "Orc", "Scourge", "Tauren", "Troll",
			"BloodElf", "Draenei", "Goblin", "Worgen", "Pandaren", "VoidElf", "Nightborne", "HighmountainTauren",
			"LightforgedDraenei", "DarkIronDwarf", "MagharOrc", "ZandalariTroll", "KulTiran", "Vulpera",
			"Mechagnome", "Dracthyr", "EarthenDwarf" }) do
			local f = fileOf and select(2, pcall(fileOf, "Interface\\DressUpFrame\\DressUpBackground-" .. race .. "1"))
			local a = atlasOf and select(2, pcall(atlasOf, "dressingroom-background-" .. race:lower()))
			if f or type(a) == "table" then
				say("%s: file %s · atlas %s", race, tostring(f),
					type(a) == "table" and ("%sx%s"):format(tostring(a.width), tostring(a.height)) or "none")
			end
		end
		for _, line in ipairs(lines) do
			U.Print("  " .. line)
		end
		BT.EnsureBound()
		BT.settings.menagerieSceneReport = lines
		U.Print("Expedition: scene report written. Type /reload to save it.")
		return
	elseif cmd == "toast" then
		local c = J.Mine()
		local last = c and c.last and J.Store().mobs[c.last.npc]
		T.Push({
			head = "Platinum mastery!", text = ("500 kills on %s"):format(last and last.name or "Barn Owl"),
			points = 10, icon = T.Icon(last and last.kind),
		})
		return
	end
	BT.MenagerieWindow.Toggle()
end

-- /bt expedition, and the old name still (Josh 2026-09-27): only the new one
-- is in /bt's list
BT.Command("expedition", command,
	"expedition [debug|edge|map|model|scene|toast] - open the journal of every kind of mob you have killed",
	"menagerie")
BT.Command("menagerie", command, nil, "menagerie")
