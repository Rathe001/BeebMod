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
-- WHERE THE RANK COMES FROM. This game has none of Classic's honor calls.
-- Its PvP tab shows a rank and rank points, which come from the client's
-- C_MajorFactions call (M.FromCall); where that says nothing, they are read
-- off the tab (M.FromTab). A client with Classic's calls is read those
-- instead. With none of them, there is no line.
local _, BT = ...
local CreateFrame, C_Timer, hooksecurefunc = BT.Cpu.For("Modules/PvP/PvP.lua")

local M = BT.Module({
	key = "pvp",
	feature = "dock",
	title = "PvP",
	order = 37.2,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

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

-- 12,345: commas from a thousand, written the one way every count in
-- BeebMod is (U.Commas; 2026-10-17, audit: six copies used the client's
-- separator and the rest a comma)
local function big(n)
	return BT.Util.Commas(n)
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

-- a rank's number, 1 to 14, from the tab's label; 0 for none (Civilian).
-- THE LABEL IS NUMBER AND TITLE (2026-10-17, audit). The tab writes a ranked
-- character's label as PVP_RANK_NUMBER_AND_TITLE, the number and the name
-- together; only Civilian is a bare word. So the number in it is taken
-- first, and failing that the longest rank name inside it ("Master Sergeant"
-- holds "Sergeant").
function M.NumberOf(name)
	if type(name) ~= "string" then
		return 0
	end
	local digits = tonumber(name:match("%d+"))
	if digits and digits >= 1 and digits <= 14 then
		return math.floor(digits)
	end
	local low = name:lower()
	local best, bestLen = 0, 0
	local lists = { M.RANKS[M.SideName() or ""], M.RANKS.Alliance, M.RANKS.Horde }
	for _, list in ipairs(lists) do
		for i, rank in ipairs(list or {}) do
			if #rank > bestLen and low:find(rank:lower(), 1, true) then
				best, bestLen = i, #rank
			end
		end
	end
	return best
end

-- rank `n`'s name on your side: the client's own words, as its tab writes
-- them, or the list's
function M.RankName(n)
	n = tonumber(n)
	if not (n and n >= 1 and n <= 14) then
		return nil
	end
	local side = M.SideName()
	local ranks = _G.Enum and _G.Enum.PvPRanks
	if type(ranks) == "table" and type(ranks.Rank_1) == "number" and side then
		local key = ("PVP_RANK_%d_%d"):format(ranks.Rank_1 + n - 1, side == "Alliance" and 1 or 0)
		local word = ask("GetText", key, ask("UnitSex", "player"))
		if type(word) == "string" and word ~= "" and word ~= key and not (issecretvalue and issecretvalue(word)) then
			return word
		end
	end
	return (M.RANKS[side or ""] or M.RANKS.Alliance)[n]
end

-- the rank after number `n` on your side, by name
function M.NextName(n)
	return M.RankName((n or 0) + 1)
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
-- of the character window says "Civilian" and "Rank Points: 0 / 750". The
-- first records found no call that says either, so they are read off the
-- tab's labels, each time the game writes them (M.WatchTab), and kept for
-- the character, so the line has them after a restart too. Since the audit
-- (2026-10-17) the call the tab reads comes first (M.FromCall), and the
-- labels are what is left where it says nothing.
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

-- a number the client gave, or nil for none or a secret
local function plainNumber(v)
	if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then
		return nil
	end
	return v
end

-- THE CLIENT'S OWN CALL FIRST (2026-10-17, audit). The tab fills its labels
-- from C_MajorFactions.GetMajorFactionProgressionInfo: rank points are a
-- faction of their own (PVP_RANK_POINTS_FACTION_ID, 2800, a local in the
-- tab's file). Its renownLevel is the rank, 0 to 14; renownReputationEarned
-- and renownLevelThreshold are the points and the cap. Read here, it needs
-- no tab and no label to pick apart. { name, number, points, cap }, or nil
-- where the client has no such call or it says nothing.
M.RANK_FACTION = 2800
function M.HasCall()
	local factions = _G.C_MajorFactions
	return type(factions) == "table" and type(factions.GetMajorFactionProgressionInfo) == "function"
end

function M.FromCall()
	if not M.HasCall() then
		return nil
	end
	local ok, info = pcall(_G.C_MajorFactions.GetMajorFactionProgressionInfo, M.RANK_FACTION)
	if not (ok and type(info) == "table") then
		return nil
	end
	local n = plainNumber(info.renownLevel)
	if not n then
		return nil
	end
	n = math.max(0, math.min(14, math.floor(n)))
	local civilian = type(_G.PVP_RANK_0_NAME) == "string" and _G.PVP_RANK_0_NAME or "Civilian"
	return {
		name = n > 0 and M.RankName(n) or civilian,
		number = n,
		points = plainNumber(info.renownReputationEarned) or 0,
		cap = plainNumber(info.renownLevelThreshold) or 0,
	}
end

-- what the tab says now: { name, number, points, cap }, or nil when it says
-- nothing
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
	name = plainText(name)
	return { name = name, number = M.NumberOf(name), points = number(a) or 0, cap = number(b) or 0 }
end

-- the rank points kept for this character: the tab's last word on them
local function kept()
	if not BT.settings then
		return nil
	end
	BT.settings.pvp = BT.settings.pvp or {}
	-- BY NAME AND REALM (Josh 2026-09-30, review). The settings are
	-- account-wide, and under the name alone two characters of one name on
	-- two realms shared a rank. Kept by U.MeKey like every other record of a
	-- character; one kept under the bare name comes across (BT.Session.Mine).
	local _, who = BT.Session.Mine(BT.settings.pvp)
	return BT.settings.pvp, who
end

-- read the client's call, or else the tab, and keep what it says; true when
-- there was something
function M.TakeTab()
	local t = M.FromCall() or M.FromTab()
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

-- ASKED, NOT WAITED FOR (Josh 2026-09-30: "PvP progress meter is not
-- showing"). The tab's labels are written when the tab is opened, so a
-- character whose PvP tab you had never opened had no line at all. The tab
-- has an Update of its own (the Testing page's record lists
-- PVPRankFrame:Update), which writes them without showing anything: it is
-- asked to, until this character's rank is on file, at most every half
-- minute. Its labels are then read as ever (M.WatchTab, M.TakeTab).
-- NOT WHERE THE CALL IS THERE (2026-10-17, audit). The tab's Update fills its
-- labels from the call M.FromCall reads, so asking it adds nothing there; and
-- run from BeebMod, it leaves BeebMod's taint on Blizzard's frame for the
-- session. It is asked only on a client without that call.
M.ASK_EVERY = 30
function M.AskTab()
	local tab = M.Tab()
	local now = BT.Util.Now and BT.Util.Now() or 0
	if M.HasCall() then
		return false
	end
	if not (tab and type(tab.Update) == "function") or now - (M.askedAt or -math.huge) < M.ASK_EVERY then
		return false
	end
	M.askedAt = now
	return (pcall(tab.Update, tab))
end

-- whether there is anything to read: Classic's calls, or this game's call
-- or tab
function M.Available()
	return M.Classic() or M.FromCall() ~= nil or M.TabFields() ~= nil
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
	-- the number as read; one kept before it was kept is found in the label
	p.number = tonumber(t.number) or M.NumberOf(t.name)
	-- Civilian, and anything else the ranks do not name, is no rank yet
	p.name = p.number > 0 and (M.RankName(p.number) or t.name) or nil
	p.title = p.name or t.name
	p.points, p.cap = t.points or 0, t.cap or 0
	p.nextName = M.NextName(p.number)
	p.progress = p.cap > 0 and math.max(0, math.min(1, p.points / p.cap)) or 0
	return p
end

-- ---------------------------------------------------------------------------
-- Battlegrounds won and lost
-- ---------------------------------------------------------------------------

-- WON AND LOST, BY BATTLEGROUND (Josh 2026-11-23: "Possible to show the
-- win/lose rate of each bg, and then the total?"). The game keeps no such
-- count that an addon can ask for, so each match is written down as it ends:
-- PVP_MATCH_COMPLETE names the winning side (0 the Horde, 1 the Alliance,
-- anything else nobody), and GetBattlefieldArenaFaction the side you fought
-- on. Kept for the character, under the battleground's name as the game has
-- it. Matches from before this was built are not in it.
local function plainOf(v)
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return v
end

-- this character's counts: { [battleground] = { won, lost, draw } }
function M.Matches()
	if not BT.settings then
		return nil
	end
	BT.settings.pvpMatches = BT.settings.pvpMatches or {}
	local all = BT.settings.pvpMatches
	local mine, who = BT.Session.Mine(all)
	if not mine then
		mine = {}
		all[who] = mine
	end
	return mine
end

-- the side you are fighting on: 0 the Horde, 1 the Alliance, or nil
function M.Team()
	local team = plainOf((ask("GetBattlefieldArenaFaction")))
	if team == 0 or team == 1 then
		return team
	end
	local side = plainOf((ask("UnitFactionGroup", "player")))
	return (side == "Horde" and 0) or (side == "Alliance" and 1) or nil
end

-- "won", "lost" or "draw"; nil where your side is not known
function M.Result(winner, team)
	if team ~= 0 and team ~= 1 then
		return nil
	end
	if winner ~= 0 and winner ~= 1 then
		return "draw"
	end
	return winner == team and "won" or "lost"
end

-- one match written down; what it was counted as
function M.Tally(name, winner, team)
	local mine = M.Matches()
	local result = M.Result(winner, team)
	if not (mine and result and type(name) == "string" and name ~= "") then
		return nil
	end
	local row = mine[name]
	if type(row) ~= "table" then
		row = { won = 0, lost = 0, draw = 0 }
		mine[name] = row
	end
	row[result] = (tonumber(row[result]) or 0) + 1
	M.TallyBracket(result)
	return result
end

-- BY BRACKET (Josh 2026-11-26: "Lets give stats per bracket. 10-19, 20-29,
-- 30-39, etc. This would replace 'all'"). A match is also counted under the
-- ten levels you were in when it ended, for this character:
-- { [who] = { [30] = { won, lost, draw } } }. A battleground's own row still
-- counts every match in it, whatever your level was.
function M.Brackets()
	if not BT.settings then
		return nil
	end
	BT.settings.pvpBrackets = BT.settings.pvpBrackets or {}
	local all = BT.settings.pvpBrackets
	local mine, who = BT.Session.Mine(all)
	if not mine then
		mine = {}
		all[who] = mine
	end
	return mine
end

-- the bracket a level is in, by its lowest level: 30 for 30 to 39
function M.BracketOf(level)
	level = tonumber(level)
	if not level or level < 1 then
		return nil
	end
	return math.floor(level / 10) * 10
end

-- "30-39"; "60" for the bracket of one level
function M.BracketName(lo)
	return lo >= 60 and tostring(lo) or ("%d-%d"):format(lo, lo + 9)
end

function M.TallyBracket(result)
	local mine = M.Brackets()
	local lo = M.BracketOf(plainOf((ask("UnitLevel", "player"))))
	if not (mine and lo and result) then
		return false
	end
	local row = mine[lo]
	if type(row) ~= "table" then
		row = { won = 0, lost = 0, draw = 0 }
		mine[lo] = row
	end
	row[result] = (tonumber(row[result]) or 0) + 1
	return true
end

-- every bracket with a match in it, lowest first. Then one row, "Earlier",
-- for the matches counted before brackets were: `total` is every match
-- (M.MatchRows), and what the brackets don't account for is those.
--
-- THE MATCHES FROM BEFORE GO IN THE BRACKET YOU ARE IN (Josh 2026-11-26, of a
-- tooltip whose only new row was "Earlier · 6 won · 12 lost": "Not seeing
-- the brackets"). BeebMod never wrote your level down with a match, so this
-- is a guess: matches have only been counted since 2026-11-23, and most
-- characters are still in the bracket they played them in. Done once for
-- each character, the first time its level is known. "Earlier" is left for
-- a character whose level the game won't say.
function M.MoveEarlier(total)
	local mine = M.Brackets()
	local lo = M.BracketOf(plainOf((ask("UnitLevel", "player"))))
	if not (mine and lo and total) or mine.moved then
		return false
	end
	local sum = { won = 0, lost = 0, draw = 0 }
	for key, row in pairs(mine) do
		if tonumber(key) and type(row) == "table" then
			for k in pairs(sum) do
				sum[k] = sum[k] + (tonumber(row[k]) or 0)
			end
		end
	end
	local row = type(mine[lo]) == "table" and mine[lo] or { won = 0, lost = 0, draw = 0 }
	local any = false
	for k in pairs(sum) do
		local rest = math.max(0, (tonumber(total[k]) or 0) - sum[k])
		row[k] = (tonumber(row[k]) or 0) + rest
		any = any or rest > 0
	end
	if any then
		mine[lo] = row
	end
	mine.moved = true
	return any
end

function M.BracketRows(total)
	M.MoveEarlier(total)
	local rows, sum = {}, { won = 0, lost = 0, draw = 0 }
	for lo, row in pairs(M.Brackets() or {}) do
		lo = tonumber(lo)
		if lo and type(row) == "table" then
			local one = { lo = lo, name = M.BracketName(lo), won = tonumber(row.won) or 0, lost = tonumber(row.lost) or 0,
				draw = tonumber(row.draw) or 0 }
			if one.won + one.lost + one.draw > 0 then
				rows[#rows + 1] = one
				sum.won, sum.lost, sum.draw = sum.won + one.won, sum.lost + one.lost, sum.draw + one.draw
			end
		end
	end
	table.sort(rows, function(a, b) return a.lo < b.lo end)
	if total then
		local rest = { name = "Earlier", won = math.max(0, total.won - sum.won), lost = math.max(0, total.lost - sum.lost),
			draw = math.max(0, total.draw - sum.draw) }
		if rest.won + rest.lost + rest.draw > 0 then
			rows[#rows + 1] = rest
		end
	end
	return rows
end

-- the match you are in has ended: counted once, in a battleground only
function M.MatchOver(winner)
	if M.counted then
		return nil
	end
	local name, kind = ask("GetInstanceInfo")
	name, kind, winner = plainOf(name), plainOf(kind), plainOf(winner)
	if kind ~= "pvp" then
		return nil
	end
	local result = M.Tally(name, winner, M.Team())
	M.counted = result ~= nil
	M.lastMatch = ("%s: winner %s, team %s, %s"):format(tostring(name), tostring(winner), tostring(M.Team()),
		tostring(result))
	return result
end

-- every battleground with a match in it, by name, and all of them together
function M.MatchRows()
	local rows, total = {}, { won = 0, lost = 0, draw = 0 }
	for name, row in pairs(M.Matches() or {}) do
		if type(row) == "table" then
			local one = { name = name, won = tonumber(row.won) or 0, lost = tonumber(row.lost) or 0,
				draw = tonumber(row.draw) or 0 }
			if one.won + one.lost + one.draw > 0 then
				rows[#rows + 1] = one
				total.won, total.lost, total.draw = total.won + one.won, total.lost + one.lost, total.draw + one.draw
			end
		end
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	return rows, total
end

-- "3 won · 1 lost · 75%": the share is of every match, a draw among them
function M.MatchWords(row)
	local n = row.won + row.lost + row.draw
	local words = ("%s won · %s lost"):format(big(row.won), big(row.lost))
	if row.draw > 0 then
		words = words .. (" · %s drawn"):format(big(row.draw))
	end
	return words .. (" · %d%%"):format(n > 0 and math.floor(row.won / n * 100 + 0.5) or 0)
end

-- ---------------------------------------------------------------------------
-- Other players' ranks
-- ---------------------------------------------------------------------------

-- SOMEBODY ELSE'S RANK, REMEMBERED (Josh 2026-11-23, of a rank 3 Sergeant's
-- nameplate: "im wondering if we should just show the rank icon instead,
-- maybe before level?"). The game tells an addon another player's rank in
-- two places only. His two commands on that Sergeant said so:
-- UnitHonorLevel("target") printed 1 and UnitPVPName("target") the bare
-- name. The two places are a battleground's scoreboard, where each row's
-- honorLevel is the rank (Blizzard_PVPMatch/Camelot/PVPMatchTableOverrides.lua),
-- and the inspect window (GetInspectHonorData's seventh value, as
-- Blizzard_InspectUI/Camelot/InspectPVPFrame.lua reads it). Each is read as
-- the game shows it and kept by the player's GUID. Nobody is inspected by
-- BeebMod: that would ask the server about everyone near you.
-- Kept across sessions, for every character of yours. Past RANKS_KEPT the
-- list is started again, since nothing says which are old.
M.RANKS_KEPT = 5000
M.ranksNoted = 0

local function rankBook()
	if not BT.settings then
		return nil
	end
	local book = BT.settings.pvpRanks
	if type(book) ~= "table" then
		book = { n = 0, by = {} }
		BT.settings.pvpRanks = book
	end
	book.by = type(book.by) == "table" and book.by or {}
	book.n = tonumber(book.n) or 0
	return book
end

-- a rank heard for a GUID: 1 to 14 kept, anything else forgets them
function M.NoteRank(guid, rank)
	local book = rankBook()
	guid, rank = plainOf(guid), plainOf(rank)
	if not (book and type(guid) == "string" and guid:match("^Player%-") and type(rank) == "number") then
		return false
	end
	rank = math.floor(rank)
	local had = book.by[guid]
	if rank < 1 or rank > 14 then
		if had then
			book.by[guid] = nil
			book.n = math.max(0, book.n - 1)
		end
		return had ~= nil
	end
	if had == rank then
		return false
	end
	if not had then
		if book.n >= M.RANKS_KEPT then
			book.by, book.n = {}, 0
		end
		book.n = book.n + 1
	end
	book.by[guid] = rank
	M.ranksNoted = M.ranksNoted + 1
	return true
end

-- the rank kept for a GUID, 1 to 14, or nil
function M.RankFor(guid)
	local book = rankBook()
	guid = plainOf(guid)
	if not (book and type(guid) == "string") then
		return nil
	end
	return book.by[guid]
end

-- the rank a title names, 1 to 14: "Corporal" is 2. Only the whole title.
function M.RankOfTitle(title)
	title = plainOf(title)
	if type(title) ~= "string" or title == "" then
		return nil
	end
	local low = title:lower()
	for _, side in ipairs({ "Alliance", "Horde" }) do
		for n, name in ipairs(M.RANKS[side]) do
			if name:lower() == low then
				return n
			end
		end
	end
	return nil
end

-- A UNIT'S RANK AND ITS NAME ON THEIR SIDE, for their tooltip (Josh
-- 2026-11-24: the rank "should just be on the tooltip of the player"). The
-- rank kept for their GUID first. Where there is none, or the game keeps the
-- GUID secret, the words the game puts before their name: in a battleground
-- UnitPVPName gives "Corporal Aeki" (seen 2026-11-23), in a city the bare
-- name.
function M.UnitRank(unit)
	if type(unit) ~= "string" then
		return nil
	end
	-- YOUR OWN, AS THE DOCK'S LINE HAS IT (Josh 2026-11-25, a Private with
	-- no tag on their own tooltip: "Shouldnt my own tooltip say my pvp rank
	-- or icon somewhere?"). The book holds players met on a scoreboard or
	-- inspected, and you are neither. Your rank is what M.Read says.
	if plainOf((ask("UnitIsUnit", unit, "player"))) == true then
		local ok, mine = pcall(M.Read)
		local n = ok and type(mine) == "table" and tonumber(mine.number) or nil
		if n and n >= 1 and n <= 14 then
			return math.floor(n), mine.name or M.RankName(n)
		end
		return nil
	end
	local rank = M.RankFor((ask("UnitGUID", unit)))
	if not rank then
		local titled, name = plainOf((ask("UnitPVPName", unit))), plainOf((ask("UnitName", unit)))
		if type(titled) == "string" and type(name) == "string" and name ~= "" then
			local from = titled:find(name, 1, true)
			if from and from > 1 then
				local before = titled:sub(1, from - 1):gsub("%s+$", "")
				rank = M.RankOfTitle(before)
			end
		end
	end
	if not rank then
		return nil
	end
	local side = plainOf((ask("UnitFactionGroup", unit)))
	local list = M.RANKS[side or ""] or M.RANKS[M.SideName() or ""] or M.RANKS.Alliance
	return rank, list[rank]
end

-- the scoreboard as it stands: every row's rank; how many were news
function M.ReadScoreboard()
	local pvp = _G.C_PvP
	if not (type(pvp) == "table" and type(pvp.GetScoreInfo) == "function") then
		return 0
	end
	local n = plainOf((ask("GetNumBattlefieldScores")))
	local news = 0
	-- for What loaded: rows read, rows whose GUID or rank the game kept
	-- secret, and rows with a rank
	local said = { rows = 0, secret = 0, ranked = 0 }
	for i = 1, (type(n) == "number" and n or 0) do
		local ok, row = pcall(pvp.GetScoreInfo, i)
		if ok and type(row) == "table" then
			said.rows = said.rows + 1
			local level = plainOf(row.honorLevel)
			if plainOf(row.guid) == nil or level == nil then
				said.secret = said.secret + 1
			elseif type(level) == "number" and level >= 1 then
				said.ranked = said.ranked + 1
			end
			if M.NoteRank(row.guid, row.honorLevel) then
				news = news + 1
			end
		end
	end
	M.scoreSaid = said
	return news
end

-- whoever the inspect window is showing: their rank
function M.ReadInspect()
	local window = _G.InspectFrame
	local unit = type(window) == "table" and plainOf(window.unit) or nil
	if type(unit) ~= "string" then
		return false
	end
	local guid = plainOf((ask("UnitGUID", unit)))
	local _, _, _, _, _, _, level = ask("GetInspectHonorData")
	return M.NoteRank(guid, plainOf(level) or 0)
end

-- FOR A CHARACTER IN THE LEDGER (Josh 2026-11-25: "even include it in our
-- ledger data", then "Let's move forward with the ledger part"). The Ledger
-- keeps a character's GUID and side, and the ranks are kept by GUID, so the
-- Ledger reads a character's rank through here. It is not written into the
-- Ledger's packed rows: those are a fixed width, and a letter more on every
-- row is a change to every saved book for a thing few characters have.
-- `p`: a Ledger row with its GUID (DB.Get, or DB.View with `full`).
-- Returns the rank 1 to 14 and its name on their side, or nil.
function M.RankOfRecord(p)
	if type(p) ~= "table" then
		return nil
	end
	local rank = M.RankFor(p.guid)
	if not rank then
		return nil
	end
	local list = M.RANKS[p.faction or ""] or M.RANKS[M.SideName() or ""] or M.RANKS.Alliance
	return rank, list[rank]
end

-- FOR THE CENSUS'S PVP CHART (Josh 2026-11-25: "Can we add a pvp graph?").
-- The ranks by GUID, and by the seven letters a packed Ledger row keeps a
-- GUID in (Core/Pack.lua, P.GuidCoder), so the count reads a rank for a row
-- with one lookup. Made once a count.
function M.RankCodes(db)
	local book = rankBook()
	if not (book and BT.Pack and BT.Pack.GuidCoder) then
		return nil
	end
	local coder = BT.Pack.GuidCoder(db)
	local codes = {}
	for guid, rank in pairs(book.by) do
		local code = coder(guid)
		if code then
			codes[code] = rank
		end
	end
	return { code = codes, guid = book.by }
end

-- a rank's insignia as a picture in a line of text, `size` across, lifted
-- `lift` pixels; nil where the game has no picture for it
function M.RankMarkup(n, size, lift)
	local how, art = M.RankArt(n)
	size, lift = tonumber(size) or 14, tonumber(lift) or 0
	if how == "atlas" then
		return ("|A:%s:%d:%d:0:%d|a"):format(art, size, size, lift)
	elseif how == "file" and type(art) == "string" then
		return ("|T%s:%d:%d:0:%d|t"):format(art, size, size, lift)
	end
	return nil
end

-- the two together, for a line about a Ledger character: "<insignia> Sergeant"
function M.RankWords(p, size, lift)
	local n, word = M.RankOfRecord(p)
	if not word then
		return nil
	end
	local mark = M.RankMarkup(n, size, lift)
	return mark and (mark .. " " .. word) or word
end

-- ASKED FOR WHEN YOU POINT AT A PLAYER (Josh 2026-11-25: "I'd like to load
-- the rank in all player tooltips if possible, and even include it in our
-- ledger data"). The game says another player's rank in two places only, a
-- scoreboard and the inspect window. No call gives it for a unit:
-- UnitHonorLevel said 1 of a rank 3 player and UnitPVPName the bare name
-- (Josh's dumps, 2026-11-23). So BeebMod asks as the inspect window does
-- (Blizzard_InspectUI/Camelot: NotifyInspect, then INSPECT_HONOR_UPDATE and
-- GetInspectHonorData's seventh value), without opening the window.
--
-- This is the asking the note above ruled out. It is kept small:
--   one player at a time, and no sooner than ASK_EVERY seconds after the last
--   a player once in ASK_AGAIN seconds, whatever the answer
--   never in a fight, and never while the inspect window is open, since the
--   answer would be taken for the one that window is waiting on
--   only a player the game says can be inspected (your own side, near you)
-- An answer not heard in ASK_WAIT seconds is counted as lost. The game is
-- told it may forget the inspected player afterwards (ClearInspectPlayer),
-- as addons that inspect do. Counted for What loaded. Not yet seen in game.
M.ASK_EVERY, M.ASK_WAIT, M.ASK_AGAIN = 1.5, 4, 1800
M.asked = {}
M.askSaid = { sent = 0, answered = 0, lost = 0, refused = 0, ranked = 0 }

local function clock()
	return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

local function inspecting()
	local w = _G.InspectFrame
	local ok, shown = pcall(function() return type(w) == "table" and w.IsShown and w:IsShown() end)
	return ok and shown and true or false
end

--
-- FOR THE BATTLEGROUND TEAMS TOO (2026-11-26, Modules/PvP/Teams.lua): a
-- teammate's item level comes with the same answer, so Teams asks through
-- here and the game is never asked by two parts of BeebMod at once. Its
-- `opts`: `teams` (asked for Teams, whose own switch counts), `fight` (in a
-- fight too: a match is mostly fights, and the measuring addon's asks in
-- fights were answered) and `again` (within ASK_AGAIN: a teammate out of
-- range the first time).
-- an answer still awaited, or the last ask too recent: nothing can be asked
-- now, so a caller need not look for someone to ask about
function M.Busy()
	local now = clock()
	if M.asking and now - M.asking.at < M.ASK_WAIT then
		return true
	end
	return now - (M.askAt or -math.huge) < M.ASK_EVERY
end

function M.AskRank(unit, opts)
	opts = type(opts) == "table" and opts or {}
	if type(unit) ~= "string" or type(_G.NotifyInspect) ~= "function"
		or not (BT.Enabled("pvp") or (opts.teams and BT.Enabled("teams"))) then
		return false
	end
	if plainOf((ask("UnitIsPlayer", unit))) ~= true or plainOf((ask("UnitIsUnit", unit, "player"))) == true then
		return false
	end
	local guid = plainOf((ask("UnitGUID", unit)))
	if type(guid) ~= "string" then
		return false
	end
	local now = clock()
	local said = M.askSaid
	if M.asking then
		if now - M.asking.at < M.ASK_WAIT then
			return false
		end
		-- (lost: the honor never came. The talents alone not coming is not.)
		if not M.asking.honor then
			said.lost = said.lost + 1
		end
		M.asking = nil
		if not inspecting() then
			ask("ClearInspectPlayer")
		end
	end
	if now - (M.askAt or -math.huge) < M.ASK_EVERY then
		return false
	end
	if not opts.again and M.asked[guid] and now - M.asked[guid] < M.ASK_AGAIN then
		return false
	end
	if inspecting() or (not opts.fight and ask("InCombatLockdown")) then
		return false
	end
	if plainOf((ask("CanInspect", unit))) ~= true then
		said.refused = said.refused + 1
		return false
	end
	if not pcall(_G.NotifyInspect, unit) then
		return false
	end
	M.asking = { guid = guid, at = now }
	M.asked[guid], M.askAt = now, now
	said.sent = said.sent + 1
	return true
end

-- THEIR TALENTS COME WITH THE SAME ANSWER (Josh 2026-11-25: "it would be
-- nice to show spec on the tooltips", and "I don't think the ledger should
-- store that since it would be outdated pretty fast"). His dump with a
-- player inspected: C_Traits.HasValidInspectData() true, and
-- C_SpecializationInfo.GetSpecializationInfo(1, true) with no name and no
-- points. So the trees are read as the game's talent window reads them
-- (Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua,
-- RefreshTreeHeaders): the three trees of a class are groups of one tree
-- (C_Traits.GetGroupDisplayInfoByTreeID: a name, an icon, an order), and
-- the points spent in each is C_Traits.GetGroupCurrencyInfo's first
-- currency's `spent`. The inspected player's talents are config -1
-- (Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID), yours the active one.
--
-- `config`: which talents. Returns { name, icon, spent = { 5, 8, 25 } }: the
-- tree with the most points, and each tree's points in the window's order.
-- Nil with no points anywhere, or two trees level at the top.
function M.SpecOf(config)
	local traits = _G.C_Traits
	if not (type(traits) == "table" and type(config) == "number" and traits.GetConfigInfo
		and traits.GetGroupDisplayInfoByTreeID and traits.GetGroupCurrencyInfo) then
		return nil
	end
	local okC, info = pcall(traits.GetConfigInfo, config)
	local tree = okC and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1] or nil
	if type(tree) ~= "number" then
		return nil
	end
	local okD, shown = pcall(traits.GetGroupDisplayInfoByTreeID, tree)
	if not (okD and type(shown) == "table" and #shown > 0) then
		return nil
	end
	local ids, trees = {}, {}
	for _, d in ipairs(shown) do
		if type(d) == "table" and type(d.groupID) == "number" then
			ids[#ids + 1] = d.groupID
			trees[#trees + 1] = { id = d.groupID, name = plainOf(d.displayName), icon = plainOf(d.icon),
				order = tonumber(plainOf(d.orderIndex)) or #trees, spent = 0 }
		end
	end
	local okG, groups = pcall(traits.GetGroupCurrencyInfo, config, ids)
	if not (okG and type(groups) == "table") then
		return nil
	end
	for _, g in ipairs(groups) do
		local first = type(g) == "table" and type(g.currencyInfos) == "table" and g.currencyInfos[1]
		local spent = type(first) == "table" and tonumber(plainOf(first.spent)) or 0
		for _, t in ipairs(trees) do
			if t.id == g.traitNodeGroupID then
				t.spent = spent
			end
		end
	end
	table.sort(trees, function(a, b) return a.order < b.order end)
	local best, level, spent = nil, false, {}
	for _, t in ipairs(trees) do
		spent[#spent + 1] = t.spent
		if not best or t.spent > best.spent then
			best, level = t, false
		elseif t.spent == best.spent then
			level = true
		end
	end
	if not best or best.spent <= 0 or level or type(best.name) ~= "string" then
		return nil
	end
	return { name = best.name, icon = best.icon, spent = spent }
end

-- [guid] = what M.SpecOf said of them, for this session only
M.specs = {}

-- a unit's talents as last heard: another player's from the answer to
-- M.AskRank, your own read now
function M.SpecFor(unit)
	if type(unit) ~= "string" then
		return nil
	end
	if plainOf((ask("UnitIsUnit", unit, "player"))) == true then
		local talents = _G.C_ClassTalents
		local ok, config = pcall(function() return talents and talents.GetActiveConfigID and talents.GetActiveConfigID() end)
		return ok and M.SpecOf(config) or nil
	end
	local guid = plainOf((ask("UnitGUID", unit)))
	return type(guid) == "string" and M.specs[guid] or nil
end

-- their tooltip, still up, written again with what was heard
--
-- THE TOOLTIP'S OWN WAY OF DRAWING AGAIN, A FRAME LATER (Josh 2026-11-25, a
-- player's tooltip with no talents line until pointed at twice: "Any way to
-- update the tooltips in real time after the spec results come back?"). The
-- first try asked GameTooltip for "mouseover" again from inside the game's
-- answer, and only where "mouseover" had the asked player's GUID. Nothing
-- was drawn again. It is now what a tag written while a tooltip is up uses
-- (Core/Tooltip.lua, T.Restack: the unit the tooltip shows, whatever it
-- hangs off), run on the next frame, once the answer has been put away.
-- The player shown is checked by the GUID the tooltip was drawn with, or
-- "mouseover"'s where that one is not known. Counted for What loaded.
M.retips = { asked = 0, other = 0, drawn = 0 }
function M.Retip(guid)
	local said = M.retips
	said.asked = said.asked + 1
	local function again()
		local T = BT.UnitTip
		if not (T and T.Restack) or ask("InCombatLockdown") then
			return false
		end
		local shown = plainOf(T.guid)
		if shown == nil then
			shown = plainOf((ask("UnitGUID", "mouseover")))
		end
		if shown ~= guid then
			said.other = said.other + 1
			return false
		end
		local ok, did = pcall(T.Restack)
		if ok and did then
			said.drawn = said.drawn + 1
			return true
		end
		return false
	end
	local timer = _G.C_Timer
	if type(timer) == "table" and type(timer.After) == "function" then
		timer.After(0, again)
		return true
	end
	return again()
end
local retip = function(guid) return M.Retip(guid) end

-- both answers in, or given up on: the game told it may forget them
local function done(a)
	if a.honor and a.ready then
		M.asking = nil
		if not inspecting() then
			ask("ClearInspectPlayer")
		end
	end
end

-- the game's answer about a player's honor: ours, if one is waited for
function M.Answered()
	local a = M.asking
	if not a or a.honor or clock() - a.at >= M.ASK_WAIT or inspecting() then
		return false
	end
	a.honor = true
	local said = M.askSaid
	said.answered = said.answered + 1
	local _, _, _, _, _, _, level = ask("GetInspectHonorData")
	level = plainOf(level)
	local news = M.NoteRank(a.guid, type(level) == "number" and level or 0)
	if type(level) == "number" and level >= 1 then
		said.ranked = said.ranked + 1
	end
	if news then
		retip(a.guid)
	end
	done(a)
	return true, news
end

-- the game's word that an inspected player's gear and talents are in
-- (INSPECT_READY, with their GUID): ours, if they are the one asked about
function M.Ready(guid)
	local a = M.asking
	guid = plainOf(guid)
	if not a or a.ready or guid ~= a.guid or clock() - a.at >= M.ASK_WAIT or inspecting() then
		return false
	end
	a.ready = true
	local consts = _G.Constants and _G.Constants.TraitConsts
	local config = type(consts) == "table" and tonumber(consts.INSPECT_TRAIT_CONFIG_ID) or -1
	local ok, spec = pcall(M.SpecOf, config)
	spec = ok and spec or nil
	local had = M.specs[a.guid]
	M.specs[a.guid] = spec
	local said = M.askSaid
	said.specs = (said.specs or 0) + (spec and 1 or 0)
	if spec and not (had and had.name == spec.name) then
		retip(a.guid)
	end
	-- a teammate's item level, read before the game is told it may forget
	-- them (Modules/PvP/Teams.lua)
	if BT.Teams and BT.Teams.Ready then
		pcall(BT.Teams.Ready, a.guid)
	end
	done(a)
	return true, spec
end

-- the game's picture for a rank: its atlas where the client has one (the
-- scoreboard's), or the insignia file; "atlas" or "file", and which
function M.RankArt(n)
	n = tonumber(n)
	if not (n and n >= 1 and n <= 14) then
		return nil
	end
	local atlas = ("UI-Character-Info-Honor-Icon-%d"):format(n)
	local get = _G.C_Texture and _G.C_Texture.GetAtlasInfo
	if type(get) == "function" then
		local ok, info = pcall(get, atlas)
		if ok and type(info) == "table" then
			return "atlas", atlas
		end
	end
	local file = M.Insignia(n)
	if file then
		return "file", file
	end
	return nil
end

function M.Status()
	local rows, total = M.MatchRows()
	local book = rankBook()
	local s = M.scoreSaid
	local a = M.askSaid
	return ("battlegrounds counted: %d kinds, %d matches · last: %s · other players' ranks kept: %d, heard this session: %d · last scoreboard: %s · ranks asked for: %d sent, %d answered, %d with a rank, %d with talents, %d lost, %d the game would not let be inspected · tooltips drawn again: %d of %d asked, %d showing somebody else")
		:format(#rows, total.won + total.lost + total.draw, tostring(M.lastMatch or "none this session"),
			book and book.n or 0, M.ranksNoted,
			s and ("%d rows, %d kept secret, %d with a rank"):format(s.rows, s.secret, s.ranked) or "none read",
			a.sent, a.answered, a.ranked, a.specs or 0, a.lost, a.refused,
			M.retips.drawn, M.retips.asked, M.retips.other)
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
		local all, who = kept()
		if not (all and all[who]) then
			M.AskTab()
		end
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

	local w = BT.Dock.LineBarWidth(M.frame)
	if w <= 0 then
		return
	end
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
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
			t:Headline(math.floor(p.progress * 100) .. "%", ("to %s"):format(p.nextName))
			t:Bar(p.progress, c)
		else
			t:Headline(p.name or "PvP", nil, c, true)
		end
				t:Section("Honorable kills")
		t:ListRow("Today", big(p.today.hk))
		t:ListRow("Yesterday", big(p.yesterday.hk))
		if p.week and p.week.hk then
			t:ListRow("This week", big(p.week.hk))
		end
		if p.last and p.last.hk then
			t:ListRow("Last week", big(p.last.hk))
		end
		t:ListRow("All time", big(p.life.hk))
		if p.week and p.week.honor then
			t:Section("Honor")
			t:ListRow("Today", big(p.today.honor))
			t:ListRow("This week", big(p.week.honor))
			if p.last and p.last.honor then
				t:ListRow("Last week", big(p.last.honor))
			end
		end
		if p.last and (p.last.standing or 0) > 0 then
			t:ListRow("Last week's standing", big(p.last.standing))
		end
		if p.life.highest then
			t:ListRow("Highest rank", p.life.highest)
		end
		-- won and lost, each battleground and then all of them (M.MatchRows)
		local rows, total = M.MatchRows()
		if #rows > 0 then
			t:Section("Battlegrounds")
			for _, row in ipairs(rows) do
				t:ListRow(row.name, M.MatchWords(row))
			end
			-- by bracket, where "All" was (Josh 2026-11-26)
			for _, row in ipairs(M.BracketRows(total)) do
				t:ListRow(row.name, M.MatchWords(row))
			end
		end
		if p.fromTab then
			t:Note("From your PvP tab.")
		end
		t:Foot({ { "Click", "open PvP tab" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("pvp", 7)
	-- a slim line under Level (BT.Dock.SlimLine, Josh 2026-10-05)
	M.shield = BT.Dock.LineShield(M.frame, nil, BT.Dock.SHIELD_SWORDS)
	-- the game's insignia is square: as wide as the shield, in its middle
	M.insignia = M.frame:CreateTexture(nil, "ARTWORK", nil, 4)
	M.insignia:SetSize(BT.Dock.LINE_ICON_W, BT.Dock.LINE_ICON_W)
	M.insignia:SetPoint("CENTER", M.shield.icon, "CENTER", 0, 0)
	M.insignia:Hide()
	M.text, M.eta, M.track, M.fill = BT.Dock.SlimLine(M.frame, M.shield.icon)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	M.frame:EnableMouse(true)
	-- a click opens the PvP page of the character window (Josh 2026-09-29)
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and not BT.Dock.JustMoved() then
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
-- rank points are a faction's (M.FromCall): its changes are heard as the
-- tab hears them (2026-10-17, audit)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED",
	"UNIT_FACTION", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
pcall(M.events.RegisterEvent, M.events, "PVP_MATCH_COMPLETE")
-- other players' ranks, as the game shows them (M.NoteRank)
pcall(M.events.RegisterEvent, M.events, "UPDATE_BATTLEFIELD_SCORE")
pcall(M.events.RegisterEvent, M.events, "INSPECT_HONOR_UPDATE")
pcall(M.events.RegisterEvent, M.events, "INSPECT_READY")
M.SCORE_EVERY = 5
M.events:SetScript("OnEvent", function(_, event, unit)
	if not BT.Enabled("pvp") then
		-- an answer Teams asked for is still put away, so the next can be asked
		if BT.Enabled("teams") and M.asking then
			if event == "INSPECT_READY" then
				pcall(M.Ready, unit)
			elseif event == "INSPECT_HONOR_UPDATE" then
				pcall(M.Answered)
			end
		end
		return
	end
	-- a match ended (its winner is the event's first word); a new place, and
	-- the next match is a new one
	if event == "PVP_MATCH_COMPLETE" then
		local ok, err = pcall(M.MatchOver, unit)
		if not ok then
			BT.Err("pvp.match: " .. tostring(err))
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		M.counted = nil
	end
	-- the scoreboard is sent over and over in a match: read every few seconds
	if event == "UPDATE_BATTLEFIELD_SCORE" then
		local now = GetTime and GetTime() or 0
		if now - (M.scoreAt or -math.huge) >= M.SCORE_EVERY then
			M.scoreAt = now
			pcall(M.ReadScoreboard)
		end
		return
	end
	if event == "INSPECT_READY" then
		pcall(M.Ready, unit)
		return
	end
	if event == "INSPECT_HONOR_UPDATE" then
		local ok, ours = pcall(M.Answered)
		if not (ok and ours) then
			pcall(M.ReadInspect)
		end
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
	step("FromCall", M.FromCall())
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
