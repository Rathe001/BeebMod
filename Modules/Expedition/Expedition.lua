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
	order = 38,
	-- A TAB OF ITS OWN (Josh 2026-09-25): on the right panel, so it goes where
	-- its tab is dragged, and its settings have a page to grow into
	dock = true,
})

-- how often the unit tokens are looked at: a death is seen within a fifth of
-- a second, and a look is a handful of reads per enemy in view
local SCAN_EVERY = 0.2

local WORDS = "|cff8a9894%s|r"
-- the Expedition's own colour: the blue of the loading screens' ink wash
M.INK = { 0.44, 0.64, 0.80 }
-- the row's notices are in its colour, and the bar's line names the book
M.colour, M.book = M.INK, "Expedition"

local big = BT.ExpeditionWindow.Big

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

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

-- A NEW RANK, ONCE (2026-10-17, audit): measured against the highest rank
-- this character has reached (J.RankUp), where it was the points just before
-- the kill - so points that fell and climbed back toasted a rank again. The
-- score is the one the kill's check kept (J.KeptScore), worked out once.
local function rankCheck()
	local points, _, st = J.KeptScore()
	local rank, title = J.RankUp(points)
	if rank then
		M.RankToast(rank, title)
	end
	return points, st
end

-- the dock's line and the journal drawn again: from the score just worked
-- out, or the made-up journal's while it is shown (J.Saved)
local function redraw(points, st)
	if J.demo then
		M.Update()
	else
		M.Update(points, st)
	end
	BT.ExpeditionWindow.Changed()
end

-- a kill, in your own journal (J.Saved): the notices for it, and the score
local function record(info)
	-- the rank the kill starts from, for a character with none kept yet
	J.BestRank()
	local new, news = J.Kill(info)
	local s = M.session
	if s then
		s.kills = (s.kills or 0) + 1
		s.new = (s.new or 0) + (new and 1 or 0)
		s.last = U.Now()
	end

	local name = info.name or ("#" .. info.npc)
	-- SMALL NOTICES, ON THE ROW (Josh 2026-10-05: "I worry about achievements
	-- being too spammy"): a new page is its points going up on the dock's
	-- line, and a mastery or a commendation is said there for a moment
	-- (UI/Notice.lua); only a new rank is a toast
	if new then
		local _, worth = J.Worth(J.Store().enemies[info.npc])
		BT.Notice.Gain(M, worth)
		-- a new kind may want its other look asked for (M.ProbeTick)
		M.Probe(true)
	end
	for _, a in ipairs(news or {}) do
		if a.mastery then
			BT.Notice.Say(M, { name = name, what = ("%s mastery"):format(a.name), kind = "mastery",
				points = a.points, onClick = openOn(info.npc) })
		else
			BT.Notice.Say(M, { name = a.title, what = "commendation", kind = "commendation", points = a.points,
				onClick = function() BT.ExpeditionWindow.ShowCommendation(a.id) end })
		end
	end
	-- a new rank last, once everything that earned it has been shown
	return rankCheck()
end

function M.Kill(info, how)
	if not BT.Enabled("expedition") then
		return
	end
	redraw(J.Saved(record, info))
end

-- A BOSS FIGHT WON (ENCOUNTER_END) moves the boss's category and its points
-- (J.EncounterWon). The rank and the dock's line were left as they were
-- until the next kill, and a rank reached by the boss's points never
-- toasted (2026-10-17, audit).
function M.EncounterWon(name)
	local points, st = J.Saved(function()
		J.BestRank()
		if J.EncounterWon(name) then
			return rankCheck()
		end
	end)
	if points then
		redraw(points, st)
	end
	return points ~= nil
end

K.onKill = M.Kill

-- FOR THE TESTING PAGE'S REPORT (Josh 2026-10-18, the squirrel that did not
-- count): how each kill since the reload was counted, and why the last of
-- your targets' deaths that did not count was left out (Kills.lua, K.Missed)
function M.Status()
	local s = K.stats
	local line = ("kills since reload: %d seen dying, %d in one blow, %d by XP line, %d by loot"):format(
		s.dead or 0, s.struck or 0, s.xp or 0, s.loot or 0)
	local miss = K.misses[1]
	if miss then
		local tag = miss.corpseTag == true and "somebody else's" or (miss.corpseTag == false and "yours" or "not said")
		line = line .. (" · last target not counted: %s, %s (corpse's tag %s)"):format(
			tostring(miss.name or "unknown"), miss.why or "no reason kept", tag)
	end
	return line
end
-- a look the journal has is not asked for again (Kills.lua, learnLook)
K.KnowsLook = J.HasLook

-- ---------------------------------------------------------------------------
-- A man and a woman, asked for in the background
-- ---------------------------------------------------------------------------
--
-- THE OTHER LOOK, ASKED FOR (Josh 2026-10-03: the Scarlet Convert's card drew
-- a man and its page a woman). The game picks one of a creature's looks each
-- time a model is drawn, and every model the journal draws keeps the one it
-- got (Window.lua, V.LearnLook). A hidden model of ours asks again for the
-- enemies in the book with one look known and not the other, or none known
-- yet: one ask every few seconds, out of combat only, until both are found.
-- An enemy that comes back the same sex every time is marked as having one
-- look and not asked again; one whose model is neither a man's nor a woman's
-- (a wolf, an elemental) is marked after two.
M.PROBE_EVERY = 3
M.PROBE_TRIES = 6
M.PROBE_NEITHER = 2
M.PROBE_MISSES = 3
M.probeStats = { asked = 0, learnt = 0, misses = 0, done = 0 }

-- this session's enemies the game would not draw for us: left alone
local unloadable = {}

local function plainNumber(fn, model)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, model)
	if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) and v > 0 then
		return v
	end
	return nil
end

-- the hidden model: shown, so the client loads into it, and at no alpha
function M.ProbeModel()
	if M.probeModel then
		return M.probeModel
	end
	local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
	if not (ok and m and m.SetCreature) then
		return nil
	end
	m:SetSize(1, 1)
	m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	pcall(m.SetAlpha, m, 0)
	pcall(m.EnableMouse, m, false)
	M.probeModel = m
	return m
end

-- whether this enemy still wants asking
function M.WantsLook(npc, m)
	if type(npc) ~= "number" or type(m) ~= "table" or m.oneLook or J.Looks(m) or unloadable[npc] then
		return false
	end
	return (m.lookTries or 0) < M.PROBE_TRIES
end

-- the next enemy to ask for: the open page's first, then one with a look
-- known, then any
function M.NextLook()
	local s = J.Store()
	if not s or J.demo then
		return nil
	end
	local open = BT.ExpeditionWindow.open
	if open and M.WantsLook(open, s.enemies[open]) then
		return open
	end
	local any
	for npc, m in pairs(s.enemies) do
		if M.WantsLook(npc, m) then
			if type(m.looks) == "table" and next(m.looks) then
				return npc
			end
			any = any or npc
		end
	end
	return any
end

-- what the hidden model drew for `npc`, written down: true when it drew
local function readProbe(model, npc)
	local s = J.Store()
	local m = s and s.enemies[npc]
	if not m then
		return true
	end
	local file = plainNumber(model.GetModelFileID, model)
	if not file then
		return false
	end
	m.lookTries = (m.lookTries or 0) + 1
	local sex = J.SexOfFile(file)
	if sex and J.AddLook(m, sex, plainNumber(model.GetDisplayInfo, model)) then
		M.probeStats.learnt = M.probeStats.learnt + 1
		BT.ExpeditionWindow.LookLearnt(npc)
	end
	if J.Looks(m) then
		M.probeStats.done = M.probeStats.done + 1
	elseif not (type(m.looks) == "table" and next(m.looks)) and m.lookTries >= M.PROBE_NEITHER then
		-- neither a man's model nor a woman's, twice: nothing to switch
		m.oneLook = true
		M.probeStats.done = M.probeStats.done + 1
	elseif m.lookTries >= M.PROBE_TRIES then
		m.oneLook = true
		M.probeStats.done = M.probeStats.done + 1
	end
	return true
end

-- One step: what the last ask drew is read, and the next enemy asked for.
-- What it did, for the tests: "fight", "read", "missed", "asked" or "idle".
function M.ProbeTick()
	if InCombatLockdown and InCombatLockdown() then
		return "fight"
	end
	local model = M.ProbeModel()
	if not model then
		return "idle"
	end
	local said
	local npc = M.probing
	if npc then
		M.probing = nil
		if readProbe(model, npc) then
			said = "read"
		else
			-- the client had to send for it: asked again next time, a few times
			M.probeStats.misses = M.probeStats.misses + 1
			M.probeMisses = M.probeMisses or {}
			M.probeMisses[npc] = (M.probeMisses[npc] or 0) + 1
			if M.probeMisses[npc] >= M.PROBE_MISSES then
				unloadable[npc] = true
			end
			said = "missed"
		end
	end
	npc = M.NextLook()
	if not npc then
		-- NOTHING LEFT TO ASK (2026-10-05, audit): it went on every three
		-- seconds for as long as the Expedition was on, walking the whole
		-- journal each time, the last creature still loaded in the hidden
		-- model. It stops, the model emptied, until a new kind is killed or a
		-- page is opened (M.Kill, the journal's V.Open and V.Show).
		pcall(model.ClearModel, model)
		M.Probe(false)
		return said or "idle"
	end
	M.probing = npc
	M.probeStats.asked = M.probeStats.asked + 1
	pcall(model.ClearModel, model)
	pcall(model.SetCreature, model, npc)
	return said or "asked"
end

function M.Probe(on)
	if on and not M.prober and C_Timer and C_Timer.NewTicker then
		M.prober = C_Timer.NewTicker(M.PROBE_EVERY, function()
			if BT.Enabled("expedition") then
				M.ProbeTick()
			end
		end)
	elseif not on and M.prober then
		M.prober:Cancel()
		M.prober = nil
		M.probing = nil
	end
end

-- WHAT THE LOOKS CAME TO (Josh 2026-10-03), for the Testing page's Record:
-- whether this client has the calls a look is learnt and shown with, what
-- each way of learning one has found this session, and every enemy with a
-- look on file.
function M.Dump()
	local lines = {}
	local function add(s) lines[#lines + 1] = s end
	-- one model, kept, only to ask which calls it has
	M.callsProbe = M.callsProbe or CreateFrame("PlayerModel", nil, UIParent)
	local probe = M.callsProbe
	probe:Hide()
	add(("calls: UnitSex %s · SetUnit %s · GetDisplayInfo %s · SetCreature %s · GetModelFileID %s"):format(
		tostring(type(UnitSex) == "function"), tostring(type(probe.SetUnit) == "function"),
		tostring(type(probe.GetDisplayInfo) == "function"), tostring(type(probe.SetCreature) == "function"),
		tostring(type(probe.GetModelFileID) == "function")))
	local files = 0
	for _ in pairs(BT.ExpeditionSexes or {}) do
		files = files + 1
	end
	add(("model files known to be a man's or a woman's: %d"):format(files))
	for _, unit in ipairs({ "target", "mouseover" }) do
		if UnitExists and UnitExists(unit) then
			local okS, sex = pcall(UnitSex, unit)
			add(("%s: %s · UnitSex %s · look %s"):format(unit, tostring(UnitName(unit)),
				okS and tostring(sex) or "refused", tostring(K.Look(unit))))
		end
	end
	local V, P = BT.ExpeditionWindow, M.probeStats
	add(("this session, from portraits: learnt %d · asked again for the sex chosen %d"):format(
		V.lookStats.portraits, V.lookStats.rerolls))
	add(("this session, from the hidden model: asked %d · learnt %d · not drawn %d · settled %d · asking %s"):format(
		P.asked, P.learnt, P.misses, P.done, tostring(M.probing)))
	add(("this session, from enemies met: learnt %d · missed %d"):format(K.stats.looks or 0, K.stats.lookMisses or 0))
	local s = J.Store()
	local n, both, one, tries = 0, 0, 0, 0
	for npc, m in pairs(s and s.enemies or {}) do
		tries = tries + (m.lookTries or 0)
		if m.oneLook then
			one = one + 1
		end
		if type(m.looks) == "table" then
			n = n + 1
			if J.Looks(m) then
				both = both + 1
			end
			add(("  %s %s · male %s · female %s · tries %d%s"):format(tostring(npc), tostring(m.name),
				tostring(m.looks[J.MALE]), tostring(m.looks[J.FEMALE]), m.lookTries or 0,
				m.oneLook and " · one look" or ""))
		end
	end
	add(("enemies with a look: %d · with both: %d · settled on one: %d · tries spent in all: %d"):format(
		n, both, one, tries))
	BT.EnsureBound()
	BeebModDB.expeditionDump = {
		at = BT.Util and BT.Util.Now and BT.Util.Now() or 0,
		lines = lines,
	}
	return #lines
end
BT.Record("expeditionDump", function() return M.Dump() end, "expedition")

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
	-- the points (the settings canvas cut the choice of kills, and the code
	-- for it went 2026-10-17, audit); a gain just made stands before them a
	-- moment (UI/Notice.lua)
	local right = ("%s%s %s"):format(BT.Notice.GainText(M), big(points), WORDS:format("pts"))
	return left, right
end

-- drawn again from the score last worked out: what a notice ending or a gain
-- wants, without counting the whole journal again (UI/Notice.lua)
function M.Redraw()
	M.Update(M.lastPoints, M.lastSt)
end

-- `points` and `st` where the caller has just worked them out (M.Kill)
function M.Update(points, st)
	if not (M.frame and J.Store()) then
		return
	end
	if type(points) ~= "number" or type(st) ~= "table" then
		points, _, st = J.Score()
	end
	M.lastPoints, M.lastSt = points, st
	-- the words are a notice's while one is said (UI/Notice.lua); the badge
	-- and the bar are drawn either way
	if not BT.Notice.Saying(M) then
		local left, right = M.Lines(points, st)
		M.text:SetText(left)
		M.eta:SetText(right)
	end
	-- your rank's badge, or a rank previewed from the Testing page
	M.badge:SetTexture(J.RankBadge(BT.Dock.preview.expedition or (J.Rank(points))))

	local w = BT.Dock.LineBarWidth(M.frame)
	if w <= 0 then
		return
	end
	-- the bar: from this rank to the next, full at the top
	local _, _, prev, nextAt = J.Rank(points)
	local share = nextAt and (points - prev) / (nextAt - prev) or 1
	-- OWN COLOUR (Josh 2026-09-26): it wore Experience's accent, and two
	-- orange rows read as one; it takes the loading screens' ink blue, for
	-- its bar (a slim line has no band behind it: UI/Dock.lua, B.SlimLine)
	local a = M.INK
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	-- a texture of no width is drawn as a whole one, so an empty part is hidden
	M.fill:SetShown(share > 0)
	M.fill:SetWidth(math.max(1, w * math.min(1, share)))
end

-- (Josh 2026-09-27, the dock's tooltips redrawn, and "Much better" of the
-- plainer words) your rank and how far to the next, the enemies you killed
-- last with how far each is from its next mastery (Josh 2026-10-17, in place
-- of the closest masteries: "so it kind of tracks with the zone"), and this
-- session's hunting; a new character is told how to start instead of shown
-- rows of zeros
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
		t:Title(title, (st.uniques or 0) > 0 and ("%s %s"):format(big(points), points == 1 and "point" or "points")
			or nil)
		if (st.uniques or 0) == 0 then
			t:Note("No kills yet. Each unique kill is worth 1 point.")
			if nextAt then
				t:Section()
				t:ListRow("Next rank", ("%s at %s"):format(nextTitle, big(nextAt)))
			end
			t:Foot({ { "Click", "open journal" } })
			return
		end
		if nextAt then
			local span = math.max(1, nextAt - at)
			t:Bar((points - at) / span, feature and feature.color)
			t:Scale(("%s to %s"):format(big(nextAt - points), nextTitle), big(nextAt))
		end
		-- each with the mastery it is working towards, or the last one it has
		local last = J.LastKilled(J.Mine(), 3)
		if #last > 0 then
			t:Section("Last killed")
			local enemies = J.Store().enemies
			for _, k in ipairs(last) do
				local enemy = enemies[k.npc]
				local name = (enemy and enemy.name) or ("#" .. k.npc)
				local ladder = J.Ladder(enemy)
				if k.need then
					local metal = ladder[k.tier + 1]
					t:ListRow(("%s · %s"):format(name, metal.name), ("%s / %s"):format(big(k.have), big(k.need)), nil,
						nil, { k.have / math.max(1, k.need), metal.color })
				else
					local metal = ladder[k.tier]
					t:ListRow(("%s · %s"):format(name, metal.name), ("%s kills"):format(big(k.have)), nil, nil,
						{ 1, metal.color })
				end
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
		t:Foot({ { "Click", "open journal" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("expedition", 8)
	-- your rank's badge, on a slim line under Level (BT.Dock.SlimLine, Josh
	-- 2026-10-05)
	M.badge = BT.Dock.LineIcon(M.frame)
	M.text, M.eta, M.track, M.fill = BT.Dock.SlimLine(M.frame, M.badge)
	-- a new width draws the bar again from the last score, as the Ledger's
	-- line does, rather than counting the journal (2026-10-05, audit)
	M.frame:SetScript("OnSizeChanged", function()
		M.Redraw()
	end)
	M.frame:EnableMouse(true)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or BT.Dock.JustMoved() then
			return
		end
		-- a click while the row says a commendation opens it
		if M.noticeClick then
			M.noticeClick()
		else
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
-- HEALTH AND FLAGS FOR THE TARGET AND THE MOUSEOVER ONLY (2026-10-05, audit):
-- heard for every unit, they came by the hundred a second in a raid, each one
-- asked whether it was a unit being watched. The scan looks at every
-- nameplate five times a second, and a plate that goes is heard on its own
-- (NAME_PLATE_UNIT_REMOVED); these two only see a death between looks.
local HEARD_UNITS = { "UNIT_HEALTH", "UNIT_FLAGS" }
-- Your auto-attack going on and off (PLAYER_ENTER_COMBAT, PLAYER_LEAVE_COMBAT)
-- is a swing, for a kill in one blow (Kills.lua, K.Struck).
local HEARD = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
	"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CHAT_MSG_COMBAT_XP_GAIN", "LOOT_READY", "QUEST_ACCEPTED",
	"QUEST_LOG_UPDATE", "ENCOUNTER_END", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT" }
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
	for _, event in ipairs(HEARD_UNITS) do
		if on then
			if ev.RegisterUnitEvent then
				pcall(ev.RegisterUnitEvent, ev, event, "target", "mouseover")
			end
		else
			pcall(ev.UnregisterEvent, ev, event)
		end
	end
	-- your own casts, for Pick Pocket and a kill in one blow
	-- (Modules/Expedition/Kills.lua, K.Cast)
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
			M.EncounterWon(b)
		end
	elseif event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT" then
		K.Swing(event == "PLAYER_ENTER_COMBAT")
	end
end)

function M.Show(show)
	local frame = M.Build()
	if show then
		-- the line only while its own switch is on (M:DockRow); the journal
		-- counts either way
		frame:SetShown(M.LineOn())
		M.Update()
		M.Probe(true)
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
		M.Probe(false)
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
-- Its parts, and its line in the dock
-- ---------------------------------------------------------------------------

-- a setting that is on unless switched off, as a row's get and set
local function setting(key)
	return function()
		return on(key, true)
	end, function(v)
		BT.EnsureBound()
		BT.settings[key] = v and true or false
	end
end

-- THE EXPEDITION'S PARTS (the settings canvas, Josh 2026-10-04): its own
-- switch is the feature's, so the toasts stand at the top of its page, and
-- their sound under them. A toast is a new rank's alone since 2026-10-05
-- (UI/Notice.lua), so "Every unique kill" went: a unique kill is the points
-- going up on the dock's line.
function M:Parts()
	local toastGet, toastSet = setting("expeditionToasts")
	local soundGet, soundSet = setting("expeditionSound")
	return {
		{ label = "Rank toasts", blurb = "When you reach a new rank",
			get = toastGet, set = toastSet, field = "expeditionToasts" },
		{ label = "Sound", get = soundGet, set = soundSet, sub = true, field = "expeditionSound" },
	}
end

-- ITS LINE IN THE DOCK (Josh 2026-09-27), switched and dragged on the Dock's
-- page. It shows your points (the audit: "Expedition line shows: Points,
-- Kills" - cut, points).
function M.LineOn()
	return on("expeditionLine", true)
end

function M:DockRow()
	return {
		label = "Expedition", blurb = "Your rank and points", field = "expeditionLine",
		get = function() return M.LineOn() end,
		set = function(v)
			BT.EnsureBound()
			BT.settings.expeditionLine = v and true or false
			if M.frame and BT.Enabled("expedition") then
				M.frame:SetShown(v and true or false)
				BT.Dock.Relayout()
			end
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Notices and toasts
-- ---------------------------------------------------------------------------

-- A SAMPLE NOTICE (Josh 2026-09-28: "I'd actually prefer to use the
-- 'Testing' module with buttons/toggles going forward"): from the Testing
-- page, a Platinum mastery on the last enemy you killed, or on a Barn Owl
-- before you have killed anything, said on the dock's line as a real one is
function M.SampleNotice()
	local c = J.Mine()
	local last = c and c.last and J.Store().enemies[c.last.npc]
	return BT.Notice.Say(M, { name = last and last.name or "Barn Owl", what = "Platinum mastery",
		kind = "mastery", points = 10 })
end

-- a new rank's toast, with its badge; a click opens the Commendations page.
-- Off with the Rank toasts switch.
function M.RankToast(rank, title)
	if not on("expeditionToasts", true) then
		return false
	end
	return T.Push({
		head = "Expedition rank", text = ("%s %s"):format(title, WORDS:format(("· rank %d of %d")
			:format(rank, #J.RANKS))),
		icon = T.RANK_ICON, badge = J.RankBadge(rank), book = "Expedition",
		sound = on("expeditionSound", true),
		onClick = function() BT.ExpeditionWindow.Show(nil, "commendations") end,
	})
end

-- the Testing page's rank toast: yours, as if just reached
function M.SampleRankToast()
	local rank, title = J.Rank((J.Score()))
	return M.RankToast(rank, title)
end
