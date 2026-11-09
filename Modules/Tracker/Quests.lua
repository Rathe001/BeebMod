-- What the client knows about the quests you are following (Josh 2026-09-19).
--
-- Kept apart from the frame that draws it, because this half is the half that
-- breaks: every build moves quest data somewhere new, and the answer has to be
-- found through whichever API this one has. Nothing in here draws anything, so
-- the headless tests can read a whole quest log without a single frame.
--
--   C_QuestLog.*        the modern shape, and what this client answers to
--   GetQuestLogTitle    the vanilla globals, still here on a 1.x client
--
-- The result is one plain table per quest, which is all the tracker draws:
--   { questID, title, level, tag, complete, failed, objectives = {
--       { text = "Stoneanvil's Rifle", have = 0, need = 1, done = false } } }
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Tracker/Quests.lua")

local Q = {}
BT.Quests = Q

local function numEntries()
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		local n = C_QuestLog.GetNumQuestLogEntries()
		return tonumber(n) or 0
	end
	if GetNumQuestLogEntries then
		return tonumber((GetNumQuestLogEntries())) or 0
	end
	return 0
end

-- title, level, isHeader, questID - from whichever call this client has
local function entry(index)
	if C_QuestLog and C_QuestLog.GetInfo then
		local info = C_QuestLog.GetInfo(index)
		if info then
			return info.title, info.level, info.isHeader, info.questID
		end
		return nil
	end
	if GetQuestLogTitle then
		local title, level, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
		return title, level, isHeader, questID
	end
	return nil
end

local function watched(index, questID)
	if C_QuestLog and C_QuestLog.GetQuestWatchType and questID then
		return C_QuestLog.GetQuestWatchType(questID) ~= nil
	end
	if IsQuestWatched then
		return IsQuestWatched(index) and true or false
	end
	return false
end

-- A QUEST YOU HAVE FAILED (Josh 2026-09-19). Not the same as one you have not
-- finished: the escort died, the timer ran out, and the tracker should say so
-- rather than showing you objectives you can no longer complete. The modern
-- call answers directly; the vanilla one says it in the sign of a number.
local function failed(index, questID)
	if C_QuestLog and C_QuestLog.IsFailed and questID then
		local ok, yes = pcall(C_QuestLog.IsFailed, questID)
		if ok then
			return yes and true or false
		end
	end
	if GetQuestLogTitle then
		local isComplete = select(7, GetQuestLogTitle(index))
		if tonumber(isComplete) then
			return tonumber(isComplete) < 0
		end
	end
	return false
end

local function complete(index, questID)
	if C_QuestLog and C_QuestLog.IsComplete and questID then
		return C_QuestLog.IsComplete(questID) and true or false
	end
	if IsQuestComplete and questID then
		return IsQuestComplete(questID) and true or false
	end
	-- the same seventh return `failed` reads, from the other end: positive is
	-- ready to hand in, negative is failed. Without this a client that has
	-- neither of the calls above thinks nothing is ever finished, and "fold
	-- finished quests" has nothing to fold (Josh 2026-09-19).
	if GetQuestLogTitle then
		local isComplete = select(7, GetQuestLogTitle(index))
		if tonumber(isComplete) then
			return tonumber(isComplete) > 0
		end
	end
	return false
end

-- "Stoneanvil's Rifle: 0/1" is one string on the older API and three fields on
-- the newer one. The tracker wants them apart: the words on the left, the
-- count on the right, lined up down the column.
-- THE COUNT SITS AT EITHER END (Josh 2026-09-19). "Stoneanvil's Rifle: 0/1"
-- is one shape; this build writes the other - "0/6 Ice Claw Bear slain", with
-- the count in front and no colon. Stripping only the trailing form left the
-- leading one in the words, and the tracker then wrote its own count in front
-- of it: "0/6 0/6 Ice Claw Bear slain".
local function strip(text)
	if type(text) ~= "string" then
		return nil
	end
	local words = text:match("^(.-):%s*%d+%s*/%s*%d+%s*$")
	if words then
		return words
	end
	return text:match("^%s*%d+%s*/%s*%d+%s+(.+)$")
end

function Q.SplitObjective(text, have, need)
	if type(have) == "number" and type(need) == "number" and need > 0 then
		return strip(text) or text, have, need
	end
	if type(text) == "string" then
		local words, a, b = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
		if words then
			return words, tonumber(a), tonumber(b)
		end
		local a2, b2, rest = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
		if rest then
			return rest, tonumber(a2), tonumber(b2)
		end
	end
	return text, nil, nil
end

local function objectives(index, questID)
	local out = {}
	if C_QuestLog and C_QuestLog.GetNumQuestObjectives and GetQuestObjectiveInfo and questID then
		local n = tonumber(C_QuestLog.GetNumQuestObjectives(questID)) or 0
		for j = 1, n do
			local text, _, finished, fulfilled, required = GetQuestObjectiveInfo(questID, j, false)
			if text and text ~= "" then
				local words, have, need = Q.SplitObjective(text, fulfilled, required)
				out[#out + 1] = { text = words, have = have, need = need, done = finished and true or false }
			end
		end
		return out
	end
	if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
		local n = tonumber(GetNumQuestLeaderBoards(index)) or 0
		for j = 1, n do
			local text, _, finished = GetQuestLogLeaderBoard(j, index)
			if text and text ~= "" then
				local words, have, need = Q.SplitObjective(text)
				out[#out + 1] = { text = words, have = have, need = need, done = finished and true or false }
			end
		end
	end
	return out
end

-- Every quest title in the log, followed or not: the tooltip matches the
-- client's own quest lines against these to know which lines are quest lines.
function Q.All()
	local out = {}
	for i = 1, numEntries() do
		local title, _, isHeader = entry(i)
		if title and not isHeader then
			out[#out + 1] = title
		end
	end
	return out
end

-- EVERY ITEM STILL TO COLLECT (Josh 2026-11-04: "Small spider leg should be
-- showing as a quest item on this spider's tooltip"). The client puts a quest
-- line on an enemy's tooltip only for a quest-only item, so a reagent a quest
-- asks for, like Small Spider Leg, never gets one. Each unfinished item
-- objective in the log: { title, text, have, need }, `text` the item's name.
function Q.ItemObjectives()
	local out = {}
	for i = 1, numEntries() do
		local title, _, isHeader, questID = entry(i)
		if title and not isHeader then
			if C_QuestLog and C_QuestLog.GetNumQuestObjectives and GetQuestObjectiveInfo and questID then
				local n = tonumber(C_QuestLog.GetNumQuestObjectives(questID)) or 0
				for j = 1, n do
					local text, kind, finished, fulfilled, required = GetQuestObjectiveInfo(questID, j, false)
					if kind == "item" and not finished and type(text) == "string" and text ~= "" then
						local words, have, need = Q.SplitObjective(text, fulfilled, required)
						out[#out + 1] = { title = title, text = words, have = have, need = need }
					end
				end
			elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
				for j = 1, tonumber(GetNumQuestLeaderBoards(i)) or 0 do
					local text, kind, finished = GetQuestLogLeaderBoard(j, i)
					if kind == "item" and not finished and type(text) == "string" and text ~= "" then
						local words, have, need = Q.SplitObjective(text)
						out[#out + 1] = { title = title, text = words, have = have, need = need }
					end
				end
			end
		end
	end
	return out
end

-- THE QUEST'S ITEM (Josh 2026-09-22). Some quests hand you a thing to use -
-- a horn to blow, a cage to open - and the client's own tracker shows it as
-- a button beside the quest. GetQuestLogSpecialItemInfo answers with the
-- item's link, its picture, how many charges are left, and whether it is
-- only for handing the quest in (in which case it is shown once the quest
-- is complete, the way the client does it). Nil when there is none.
function Q.Item(index, isComplete)
	if type(GetQuestLogSpecialItemInfo) ~= "function" or not index then
		return nil
	end
	local ok, link, icon, charges, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, index)
	if not (ok and type(link) == "string" and link ~= "") then
		return nil
	end
	if showWhenComplete and not isComplete then
		return nil
	end
	return { link = link, icon = icon, charges = tonumber(charges) or 0, index = index }
end

-- and how long until it can be used again: start, duration, enable
function Q.ItemCooldown(index)
	if type(GetQuestLogSpecialItemCooldown) ~= "function" or not index then
		return nil
	end
	local ok, start, duration, enable = pcall(GetQuestLogSpecialItemCooldown, index)
	if not ok then
		return nil
	end
	return start, duration, enable
end

-- WHAT KIND OF QUEST (Josh 2026-10-08: "We should add those quest labels").
-- Build 70291 gave the client's own tracker a word in brackets after an elite,
-- dungeon, PvP or raid quest's title, read from the quest's tag. Ours says the
-- same, in the client's own words where it has them. Nil for any other quest.
local TAGS = {
	{ id = "QUEST_INFO_ELITE_ID", word = "ELITE", fallback = "Elite" },
	{ id = "QUEST_INFO_DUNGEON_ID", word = "CALENDAR_TYPE_DUNGEON", fallback = "Dungeon" },
	{ id = "QUEST_INFO_PVP_ID", word = "CALENDAR_TYPE_PVP", fallback = "PvP" },
	{ id = "QUEST_INFO_RAID_ID", word = "RAID", fallback = "Raid" },
}

function Q.Tag(questID)
	if not (questID and C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function") then
		return nil
	end
	local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
	local tagID = ok and type(info) == "table" and info.tagID or nil
	local ids = type(Constants) == "table" and Constants.QuestConsts or nil
	if tagID == nil or type(ids) ~= "table" then
		return nil
	end
	for _, tag in ipairs(TAGS) do
		if ids[tag.id] ~= nil and ids[tag.id] == tagID then
			local word = _G[tag.word]
			return (type(word) == "string" and word ~= "") and word or tag.fallback
		end
	end
	return nil
end

-- Every quest you are following, in the order the client keeps them, with
-- the zone each sits under (Q.Watched, below).
-- A TIMED QUEST'S CLOCK (Josh 2026-09-28: "timed quests don't have a timer on
-- the quest log"). The client counts down an escort or a delivery, and its
-- own tracker showed the time; ours never asked. GetQuestTimers gives the
-- seconds left on each running timer, GetQuestIndexForTimer the quest each
-- belongs to. { [log index] = seconds left }, as of now.
function Q.Timers()
	local out = {}
	if type(GetQuestTimers) ~= "function" or type(GetQuestIndexForTimer) ~= "function" then
		return out
	end
	local times = { pcall(GetQuestTimers) }
	if not times[1] then
		return out
	end
	for n = 2, #times do
		local secs = tonumber(times[n])
		local ok, index = pcall(GetQuestIndexForTimer, n - 1)
		if secs and ok and tonumber(index) then
			out[tonumber(index)] = secs
		end
	end
	return out
end

-- the seconds left on one quest's clock, by its timer or, where the client
-- has it, by the time it allows and the time gone
local function timeLeft(index, questID, timers)
	if timers[index] then
		return timers[index]
	end
	if questID and C_QuestLog and type(C_QuestLog.GetTimeAllowed) == "function" then
		local ok, total, elapsed = pcall(C_QuestLog.GetTimeAllowed, questID)
		total, elapsed = tonumber(total), tonumber(elapsed)
		if ok and total and elapsed and total > 0 then
			return math.max(0, total - elapsed)
		end
	end
	return nil
end

-- one quest as the tracker draws it
local function build(i, title, level, questID, zone, timers, clock)
	local done = complete(i, questID)
	local left = timeLeft(i, questID, timers)
	return {
		index = i,
		questID = questID,
		title = title,
		level = tonumber(level) or 0,
		tag = Q.Tag(questID),
		zone = zone,
		complete = done,
		failed = failed(i, questID),
		objectives = objectives(i, questID),
		item = Q.Item(i, done),
		-- when its clock runs out, on GetTime's clock
		endsAt = left and (clock + left) or nil,
	}
end

function Q.Watched()
	local out, zone = {}, nil
	local timers = Q.Timers()
	local clock = (type(GetTime) == "function" and GetTime()) or 0
	for i = 1, numEntries() do
		local title, level, isHeader, questID = entry(i)
		if isHeader then
			zone = title
		elseif title and watched(i, questID) then
			out[#out + 1] = build(i, title, level, questID, zone, timers, clock)
		end
	end
	return out
end

-- a zone's name as a key: "The Deadmines" and "Deadmines" are one place
-- (the same rule as the dungeon list's, Modules/XP/Dungeons.lua)
function Q.ZoneKey(name)
	local D = BT.Dungeons
	if D and D.Key then
		return D.Key(name)
	end
	if type(name) ~= "string" then
		return nil
	end
	local k = name:lower():gsub("^the%s+", ""):gsub("[^%w]", "")
	return k ~= "" and k or nil
end

-- A DUNGEON'S OWN QUESTS (Josh 2026-11-06: "in dungeons/raids to only show
-- the quests that are in that zone"). Every quest under the log's heading
-- for the place, followed or not: those are the ones you went in for. Then
-- the quests you follow everywhere else, which the tracker folds away under
-- one line. Two lists, from one pass over the log. `keys` is one zone key,
-- or a set of them: a dungeon's instance and its zone may be spelled apart.
function Q.Split(keys)
	if type(keys) ~= "table" then
		keys = keys and { [keys] = true } or {}
	end
	local here, others, zone, inside = {}, {}, nil, false
	local timers = Q.Timers()
	local clock = (type(GetTime) == "function" and GetTime()) or 0
	for i = 1, numEntries() do
		local title, level, isHeader, questID = entry(i)
		if isHeader then
			zone = title
			local k = Q.ZoneKey(title)
			inside = k ~= nil and keys[k] == true
		elseif title and inside then
			here[#here + 1] = build(i, title, level, questID, zone, timers, clock)
		elseif title and watched(i, questID) then
			others[#others + 1] = build(i, title, level, questID, zone, timers, clock)
		end
	end
	return here, others
end

-- Opening one, and stopping following one. Both go through whichever call
-- exists; neither is protected on this client.
function Q.Open(quest)
	if not quest then
		return false
	end
	if C_QuestLog and C_QuestLog.SetSelectedQuest and quest.questID then
		pcall(C_QuestLog.SetSelectedQuest, quest.questID)
	elseif SelectQuestLogEntry and quest.index then
		pcall(SelectQuestLogEntry, quest.index)
	end
	-- and then open the log AT it, rather than just opening the log
	if QuestLog_SetSelection and quest.index then
		pcall(QuestLog_SetSelection, quest.index)
		if QuestLog_Update then
			pcall(QuestLog_Update)
		end
	end
	if QuestMapFrame_OpenToQuestDetails and quest.questID then
		local ok = pcall(QuestMapFrame_OpenToQuestDetails, quest.questID)
		if ok then
			return true
		end
	end
	if QuestLogPopupDetailFrame and QuestLogPopupDetailFrame_Show and quest.questID then
		local ok = pcall(QuestLogPopupDetailFrame_Show, quest.questID)
		if ok then
			return true
		end
	end
	if QuestLogFrame and ShowUIPanel and not QuestLogFrame:IsShown() then
		pcall(ShowUIPanel, QuestLogFrame)
		return true
	end
	-- already open: the selection has moved, and toggling would close it
	if QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown() then
		return true
	end
	if ToggleQuestLog then
		pcall(ToggleQuestLog)
		return true
	end
	return false
end

-- WHICH ONE ARE YOU DOING NOW (Josh 2026-09-19). The client calls it super
-- tracking: the quest the map points you at. On the default tracker it is
-- what the little icon beside each quest sets; here it is the mark at the
-- start of the line.
function Q.SuperTracked()
	if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
		local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
		if ok then
			return id
		end
	end
	return nil
end

function Q.SuperTrack(quest)
	if not quest then
		return false
	end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID and quest.questID then
		return pcall(C_SuperTrack.SetSuperTrackedQuestID, quest.questID)
	end
	-- a client with no such notion: selecting it in the log is the nearest
	-- thing to "this is the one I am doing"
	if C_QuestLog and C_QuestLog.SetSelectedQuest and quest.questID then
		return pcall(C_QuestLog.SetSelectedQuest, quest.questID)
	end
	if SelectQuestLogEntry and quest.index then
		return pcall(SelectQuestLogEntry, quest.index)
	end
	return false
end

function Q.Drop(quest)
	if not quest then
		return false
	end
	if C_QuestLog and C_QuestLog.RemoveQuestWatch and quest.questID then
		return pcall(C_QuestLog.RemoveQuestWatch, quest.questID)
	end
	if RemoveQuestWatch and quest.index then
		return pcall(RemoveQuestWatch, quest.index)
	end
	return false
end

-- ---------------------------------------------------------------------------
-- The record
-- ---------------------------------------------------------------------------

-- WHAT THE GAME SAYS OF EACH OBJECTIVE (Josh 2026-11-09: "This quest
-- objective is showing as complete, but it is not. I used the item, but I
-- didn't actually catch the bear yet"). The tracker crosses an objective out
-- when the game calls it finished. This writes down every answer the game
-- gives for each followed quest, through each call the tracker could use, so
-- the saved file shows which one said finished.
local function raw(...)
	local out = {}
	for i = 1, select("#", ...) do
		out[i] = tostring((select(i, ...)))
	end
	return table.concat(out, " | ")
end

function Q.Dump()
	local quests = {}
	for i = 1, numEntries() do
		local title, _, isHeader, questID = entry(i)
		if not isHeader and title and watched(i, questID) then
			local q = { index = i, questID = questID, title = title, complete = complete(i, questID), objectives = {} }
			if GetQuestLogTitle then
				q.logTitle = raw(pcall(GetQuestLogTitle, i))
			end
			local n = 0
			if C_QuestLog and C_QuestLog.GetNumQuestObjectives and questID then
				n = tonumber(C_QuestLog.GetNumQuestObjectives(questID)) or 0
			end
			if GetNumQuestLeaderBoards then
				n = math.max(n, tonumber(GetNumQuestLeaderBoards(i)) or 0)
			end
			for j = 1, n do
				local o = {}
				if GetQuestObjectiveInfo and questID then
					o.objectiveInfo = raw(pcall(GetQuestObjectiveInfo, questID, j, false))
				end
				if GetQuestLogLeaderBoard then
					o.leaderBoard = raw(pcall(GetQuestLogLeaderBoard, j, i))
				end
				q.objectives[j] = o
			end
			if C_QuestLog and C_QuestLog.GetQuestObjectives and questID then
				local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
				if ok and type(list) == "table" then
					q.questObjectives = {}
					for j, o in ipairs(list) do
						q.questObjectives[j] = raw(o.text, o.type, o.finished, o.numFulfilled, o.numRequired)
					end
				end
			end
			quests[#quests + 1] = q
		end
	end
	BT.EnsureBound()
	BeebModDB.trackerDump = { at = BT.Util.Now(), quests = quests }
	return quests
end

BT.Record("trackerDump", Q.Dump, "tracker")
