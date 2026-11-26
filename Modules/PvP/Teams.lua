-- Battleground teams: both teams' average level, and your own team's average
-- item level, on the dock while you are in a battleground (Josh 2026-11-26:
-- "Would it be possible in battlegrounds to show average item level and
-- average level of each team?", then, of the addon it was first built as,
-- "maybe we roll it into beebmod and place it on the dock").
--
--   TEAM LEVEL             Enemy · 14 of 15
--   36.0                               38.1
--   TEAM GEAR                 14 of 15 read
--   32.1  1.8 above usual
--
-- (The card as it is now: M.Arrange, below, has how it got here.)
--
-- WHAT THE GAME ALLOWS (measured in a 15 a side match, 2026-11-26, with a
-- throwaway addon that wrote down every answer):
--   A teammate's level reads anywhere, through their raid unit.
--   A teammate's item level comes from inspecting them, within about 30
--     yards. The game's own number is used (C_PaperDollInfo.GetInspectItemLevel),
--     the one a character sheet shows.
--   An enemy's level reads once they are seen: a nameplate, your target or
--     your mouse. Their GUID and class stay secret. Their name reads.
--   An enemy cannot be inspected (CanInspect false for all 14 seen, and six
--     asked anyway never answered). There is no enemy item level.
--   The scoreboard names everyone and gives no level.
--
-- HIGH OR LOW FOR THE BRACKET (Josh 2026-11-26: "im not sure how to indicate
-- we have a high ilvl for the bracket, or low"). Answered from what BeebMod
-- has read itself. Every teammate inspected in a battleground is kept, level
-- and item level. A straight line through those, item level against level,
-- is the usual item level at each level of a ten-level bracket (T.Fit). Each
-- teammate is compared with the usual at their own level, so a team of level
-- 31s is not called badly geared for being 31.
--
-- THE COLOURS (Josh 2026-11-26: "I'd like to use purple/blue/green/gray
-- colors to indicated the numbers", and of three layouts on a canvas, "I
-- think I like C"). The game's item quality colours, worst to best. The cuts
-- are a first guess and nobody has tuned them (T.GearTier, T.LevelTier).
--
-- ONE QUEUE OF INSPECTS. The PvP module already asks about players for their
-- rank and talents (Modules/PvP/PvP.lua, M.AskRank). This asks through it, so
-- two parts of BeebMod never ask the game at once.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/PvP/Teams.lua")

local T = BT.Teams or {}
BT.Teams = T

local M = BT.Module({
	key = "teams",
	feature = "dock",
	title = "Battleground teams",
	order = 37.3,
	dock = true,
})
T.module = M

-- players read in a bracket before a team is compared with usual
T.MIN_SAMPLES = 20
-- past this many kept, the list is started again (as the ranks are, PvP.lua)
T.KEPT = 4000
-- a teammate is asked about this many times, then once in T.ASK_REST seconds
T.MAX_ASKS = 3
T.ASK_REST = 60

-- gray, green, blue, purple. The blue and purple are lighter than the game's
-- own, which are hard to read on the dock.
T.TIERS = {
	{ 0.616, 0.616, 0.616, name = "Gray" },
	{ 0.118, 1.000, 0.000, name = "Green" },
	{ 0.290, 0.620, 1.000, name = "Blue" },
	{ 0.725, 0.478, 1.000, name = "Purple" },
}
local INK = BT.TEXT.ink
local MUTED = { 0.42, 0.48, 0.45 }
local DIM = { 0.58, 0.65, 0.62 }

local GROUP, SIGHT = {}, { "target", "mouseover" }
for i = 1, 40 do
	GROUP[#GROUP + 1] = "raid" .. i
	SIGHT[#SIGHT + 1] = "nameplate" .. i
end
for i = 1, 4 do
	GROUP[#GROUP + 1] = "party" .. i
end

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a plain first answer from the client, or nil when it has no such call,
-- the call fails, or the answer is secret
local function ask(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or secret(v) then
		return nil
	end
	return v
end

local function clock()
	return ask("GetTime") or 0
end

-- ---------------------------------------------------------------------------
-- Where you are
-- ---------------------------------------------------------------------------

-- THE BATTLEGROUND YOU ARE IN, whether this module is switched on or not: the
-- tracker asks it too, as it asks the Encounter notes about a dungeon. Its
-- zone key, every key its quests may be filed under, and its name. Nil
-- outside a battleground.
--
-- OR THE ONE PREVIEWED FROM THE TESTING PAGE (Josh 2026-11-26: "Can you add
-- a testing option to enable a pvp mode so I can look at it?"). The page's
-- Battleground row steps through each battleground BeebMod knows, and while
-- one is chosen the dock is as it would be there, with made-up numbers: the
-- quests filed under it, the journals' lines put away, its objectives and
-- the teams. Nothing is read from the game and nothing is saved. "Arathi
-- Basin at 60" is the same with the level 60 card.
function T.Preview()
	local v = BT.Dock and BT.Dock.preview and BT.Dock.preview.battleground
	return type(v) == "string" and v or nil
end

function T.Place()
	local shown = T.Preview()
	if shown then
		local name = shown:gsub(" at 60$", "")
		local key = (BT.Quests and BT.Quests.ZoneKey(name)) or name:lower()
		return key, { [key] = true }, name
	end
	local fn = rawget(_G, "IsInInstance")
	if type(fn) ~= "function" then
		return nil
	end
	local ok, inside, kind = pcall(fn)
	if not ok or secret(inside) or secret(kind) or not inside or kind ~= "pvp" then
		return nil
	end
	local name, zone = ask("GetInstanceInfo"), ask("GetRealZoneText")
	local Q = BT.Quests
	local a = Q and Q.ZoneKey(name) or nil
	local b = Q and Q.ZoneKey(zone) or nil
	local keys = {}
	if a then keys[a] = true end
	if b then keys[b] = true end
	local key = a or b
	if not key then
		return nil
	end
	return key, keys, (type(name) == "string" and name) or zone
end

-- the ten levels a match is drawn from: 30 for 30 to 39
function T.Bracket(level)
	return math.floor((tonumber(level) or 1) / 10) * 10
end

-- ---------------------------------------------------------------------------
-- The players read, kept
-- ---------------------------------------------------------------------------

-- { [guid] = { level, item level } }, for every character of yours
local function book()
	if not BT.settings then
		return nil
	end
	BT.settings.pvpGear = BT.settings.pvpGear or {}
	return BT.settings.pvpGear
end

function T.Remember(guid, level, ilvl)
	local all = book()
	if not (all and type(guid) == "string" and type(level) == "number" and type(ilvl) == "number") then
		return false
	end
	if not all[guid] then
		local n = 0
		for _ in pairs(all) do
			n = n + 1
		end
		if n >= T.KEPT then
			all = {}
			BT.settings.pvpGear = all
		end
	end
	all[guid] = { level, ilvl }
	return true
end

-- THE USUAL ITEM LEVEL AT EACH LEVEL OF A BRACKET: a straight line through
-- everyone kept in it. { a, b, n }: usual at a level is a + b * level. Nil,
-- and how many are kept, until there are T.MIN_SAMPLES.
-- `team`: the GUIDs of this match's teammates. The third answer is how many
-- of the players kept are not among them (T.Refit).
function T.Fit(lo, team)
	local n, others, sx, sy, sxx, sxy = 0, 0, 0, 0, 0, 0
	for guid, p in pairs(book() or {}) do
		local l, i = type(p) == "table" and tonumber(p[1]), type(p) == "table" and tonumber(p[2])
		if l and i and T.Bracket(l) == lo then
			n, sx, sy, sxx, sxy = n + 1, sx + l, sy + i, sxx + l * l, sxy + l * i
			if not (team and team[guid]) then
				others = others + 1
			end
		end
	end
	if n < T.MIN_SAMPLES then
		return nil, n, others
	end
	local spread = n * sxx - sx * sx
	local slope = 0
	-- a line only where the levels differ enough to draw one; else the average
	if spread > n * n * 0.5 then
		slope = math.max(0, math.min(2, (n * sxy - sx * sy) / spread))
	end
	return { a = (sy - slope * sx) / n, b = slope, n = n }, n, others
end

-- USUAL, AS SOON AS THERE IS ONE (Josh 2026-11-26, his first match with the
-- section: "Not seeing the notch on the gear meter". It said "Compares after
-- 20 read" with 14 read, and would have said so through the next match too,
-- since usual was worked out once, as the match began). A match that begins
-- without a usual looks again each time a teammate is read.
--
-- AT LEAST HALF FROM OTHER MATCHES. A line drawn through this team alone
-- passes through this team: everyone on it would be "about usual" whatever
-- they wear. So the line is used only once T.MIN_OTHERS of the players
-- behind it are not in this match.
T.MIN_OTHERS = 10
function T.Refit()
	local m = T.match
	if not m or m.usual then
		return false
	end
	local fit, n, others = T.Fit(m.lo, m.own)
	m.read = n
	if fit and others >= T.MIN_OTHERS then
		m.usual = fit
		return true
	end
	return false
end

-- item level against usual: 3 or more above, 1 to 3 above, within 1, below
function T.GearTier(d)
	return d >= 3 and 4 or d >= 1 and 3 or d > -1 and 2 or 1
end

-- an average level in its bracket: the top two levels, the two under them,
-- the middle three, the bottom three. Nil where everyone is one level (60).
function T.LevelTier(avg, lo)
	if lo >= 60 then
		return nil
	end
	local o = avg - lo
	return o >= 8 and 4 or o >= 6 and 3 or o >= 3 and 2 or 1
end

-- ---------------------------------------------------------------------------
-- Reading a match
-- ---------------------------------------------------------------------------

-- the match you are in: begun when you come into a battleground, gone when
-- you leave
function T.Begin()
	local level = ask("UnitLevel", "player")
	level = type(level) == "number" and level > 0 and level or 1
	local m = { scan = 0, own = {}, foe = {}, lo = T.Bracket(level) }
	-- a previewed battleground: a 30-39 match, or a level 60 one
	m.preview = T.Preview()
	if m.preview then
		m.lo = m.preview:find(" at 60$") and 60 or 30
	end
	-- NO USUAL YET: T.Refit works it out once the first scan says who is on
	-- your team. Worked out here it counted everyone kept as from another
	-- match, so a match begun again part-way through (a /reload, the switch)
	-- compared the team with itself (the code review, 2026-11-26).
	local _, read = T.Fit(m.lo)
	m.read = read
	T.match = m
	return m
end

-- your teammates, as the group stands now, and each one's level
function T.Scan()
	local m = T.match
	if not m then
		return
	end
	m.scan = m.scan + 1
	for _, u in ipairs(GROUP) do
		if ask("UnitExists", u) and ask("UnitIsPlayer", u) and not ask("UnitIsUnit", u, "player") then
			local guid = ask("UnitGUID", u)
			if type(guid) == "string" then
				local p = m.own[guid]
				if not p then
					p = { asked = 0 }
					m.own[guid] = p
				end
				p.here = m.scan
				local level = ask("UnitLevel", u)
				if type(level) == "number" and level > 0 then
					p.level = level
				end
			end
		end
	end
	for _, u in ipairs(SIGHT) do
		T.See(u)
	end
	-- usual, once your team is known (see T.Begin)
	if not m.usual then
		T.Refit()
	end
end

-- an enemy player in sight: their level, by their name
function T.See(u)
	local m = T.match
	if not m or type(u) ~= "string" or not ask("UnitExists", u) or not ask("UnitIsPlayer", u)
		or ask("UnitIsEnemy", "player", u) ~= true then
		return false
	end
	local name, level = ask("UnitName", u), ask("UnitLevel", u)
	if type(name) ~= "string" or type(level) ~= "number" or level <= 0 then
		return false
	end
	m.foe[name] = m.foe[name] or {}
	m.foe[name].level = level
	return true
end

-- the scoreboard: how many a side, and the enemy's names, so one who has
-- left is dropped from the average
function T.ReadBoard()
	local m = T.match
	local pvp = rawget(_G, "C_PvP")
	local n, mine = ask("GetNumBattlefieldScores"), ask("GetBattlefieldArenaFaction")
	if not m or type(n) ~= "number" or n == 0 or type(mine) ~= "number"
		or not (type(pvp) == "table" and type(pvp.GetScoreInfo) == "function") then
		return false
	end
	local own, foes, names = 0, 0, {}
	for i = 1, n do
		local ok, row = pcall(pvp.GetScoreInfo, i)
		if ok and type(row) == "table" and not secret(row) then
			local side, name = row.faction, row.name
			if not secret(side) and side == mine then
				own = own + 1
			elseif not secret(side) and type(side) == "number" then
				foes = foes + 1
				if not secret(name) and type(name) == "string" then
					names[#names + 1] = name
				end
			end
		end
	end
	m.sizeOwn, m.sizeFoe, m.foeNames = own, foes, names
	return true
end

local function unitOf(guid)
	for _, u in ipairs(GROUP) do
		if ask("UnitExists", u) and ask("UnitGUID", u) == guid then
			return u
		end
	end
	return nil
end

-- the game's word that an inspected player's gear is in: a teammate's item
-- level, whoever asked (this, the PvP module, or your own inspect window)
function T.Ready(guid)
	local m = T.match
	if not m or secret(guid) or type(guid) ~= "string" then
		return false
	end
	local p = m.own[guid]
	local unit = p and unitOf(guid)
	local paper = rawget(_G, "C_PaperDollInfo")
	if not (unit and type(paper) == "table" and type(paper.GetInspectItemLevel) == "function") then
		return false
	end
	local ok, v = pcall(paper.GetInspectItemLevel, unit)
	if not ok or secret(v) or type(v) ~= "number" or v <= 0 then
		return false
	end
	p.ilvl = v
	if p.level then
		T.Remember(guid, p.level, v)
		T.Refit()
	end
	return true
end

-- ask about one teammate whose gear is not read yet: someone the game says
-- can be inspected, and is not known to be out of range
function T.Ask()
	local m = T.match
	local pvp = BT.GetModule("pvp")
	if not (m and pvp and pvp.AskRank) then
		return false
	end
	-- NOTHING IS LOOKED AT WHILE NOTHING CAN BE ASKED (the code review,
	-- 2026-11-26): this runs twice a second, and went through every teammate
	-- each time before the PvP module said an answer was still awaited
	if pvp.Busy and pvp.Busy() then
		return false
	end
	local now = clock()
	local best, unit
	for _, u in ipairs(GROUP) do
		local guid = ask("UnitExists", u) and ask("UnitGUID", u)
		local p = type(guid) == "string" and m.own[guid] or nil
		-- THREE ASKS, THEN ONE A MINUTE. The game may not say how far a
		-- teammate is in a fight, and one asked about from across the map
		-- never answers. Three such asks used to be the end of it for the
		-- match, even once they stood next to you.
		local may = p and not p.ilvl and (p.asked < T.MAX_ASKS or now - (p.askedAt or -math.huge) >= T.ASK_REST)
		if may and (not best or p.asked < best.asked)
			and ask("CanInspect", u, false) == true and ask("CheckInteractDistance", u, 1) ~= false then
			best, unit = p, u
		end
	end
	if not best then
		return false
	end
	-- in a fight too, and again within the half hour the PvP module waits:
	-- a match is mostly fights, and a teammate out of range the first time
	-- may be near the next
	if pvp.AskRank(unit, { fight = true, again = true, teams = true }) then
		best.asked, best.askedAt = best.asked + 1, now
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- The numbers
-- ---------------------------------------------------------------------------

-- your own item level, as your character sheet says it of what you wear
local function myGear()
	local fn = rawget(_G, "GetAverageItemLevel")
	if type(fn) ~= "function" then
		return nil
	end
	local ok, _, equipped = pcall(fn)
	if not ok or secret(equipped) or type(equipped) ~= "number" or equipped <= 0 then
		return nil
	end
	return equipped
end

function T.Figures()
	local m = T.match
	local r = { levelN = 0, levelSum = 0, gearN = 0, gearSum = 0, overN = 0, overSum = 0, members = 1 }
	local function add(level, ilvl)
		if level then
			r.levelN, r.levelSum = r.levelN + 1, r.levelSum + level
		end
		if ilvl then
			r.gearN, r.gearSum = r.gearN + 1, r.gearSum + ilvl
			if level and m.usual then
				r.overN, r.overSum = r.overN + 1, r.overSum + ilvl - (m.usual.a + m.usual.b * level)
			end
		end
	end
	local mine = ask("UnitLevel", "player")
	add(type(mine) == "number" and mine > 0 and mine or nil, myGear())
	for _, p in pairs(m.own) do
		-- still in the group
		if p.here == m.scan then
			r.members = r.members + 1
			add(p.level, p.ilvl)
		end
	end
	r.size = math.max(m.sizeOwn or 0, r.members)

	-- AN ENEMY WHO LEFT IS DROPPED, once the scoreboard's names are known to
	-- match the names units give. A unit gives the first part of a two-part
	-- name ("Das" for the scoreboard's "Das Infekt").
	local names, matches = m.foeNames or {}, false
	local function listed(name)
		for _, full in ipairs(names) do
			local head = full:sub(1, #name + 1)
			if full == name or head == name .. " " or head == name .. "-" then
				return true
			end
		end
		return false
	end
	for name, e in pairs(m.foe) do
		e.listed = listed(name)
		matches = matches or e.listed
	end
	r.foeN, r.foeSum = 0, 0
	for _, e in pairs(m.foe) do
		if e.listed or not matches then
			r.foeN, r.foeSum = r.foeN + 1, r.foeSum + e.level
		end
	end
	r.foeSize = math.max(m.sizeFoe or 0, r.foeN)
	return r
end

-- what the section says, and in which colours
function T.View()
	local m = T.match
	-- previewed from the Testing page: made-up numbers, one of each colour
	if m.preview then
		local sixty = m.lo >= 60
		return { count = "All read", gear = sixty and "62.3" or "31.1", gearColor = T.TIERS[sixty and 3 or 2],
			d = sixty and 1.8 or 0.2, verdict = sixty and "1.8 above usual" or "About usual",
			level = "36.9", levelColor = T.TIERS[3], foe = "38.0", foeColor = T.TIERS[4], foeLabel = "Enemy · 13 of 15" }
	end
	local r = T.Figures()
	local v = { gearColor = MUTED, levelColor = INK, foeColor = MUTED }
	v.count = r.gearN < r.size and ("%d of %d read"):format(r.gearN, r.size) or "All read"
	if r.gearN > 0 then
		v.gear, v.gearColor = ("%.1f"):format(r.gearSum / r.gearN), INK
		if r.overN > 0 then
			local d = r.overSum / r.overN
			v.d, v.gearColor = d, T.TIERS[T.GearTier(d)]
			v.verdict = (d >= 0.5 and ("%.1f above usual"):format(d)) or (d <= -0.5 and ("%.1f below usual"):format(-d))
				or "About usual"
		else
			-- how far off a usual is, in players still to read
			-- (enough read, all of them on this team: it is players from other
			-- matches that are missing, and no count of this one's says so)
			local short = T.MIN_SAMPLES - (m.read or 0)
			v.verdict = short > 0 and ("%d more to compare"):format(short) or "Needs another match"
		end
	end
	if r.levelN > 0 then
		local avg = r.levelSum / r.levelN
		v.level, v.levelColor = ("%.1f"):format(avg), T.TIERS[T.LevelTier(avg, m.lo) or 0] or INK
	end
	v.foeLabel = "Enemy"
	if r.foeN > 0 then
		local avg = r.foeSum / r.foeN
		v.foe, v.foeColor = ("%.1f"):format(avg), T.TIERS[T.LevelTier(avg, m.lo) or 0] or INK
		if r.foeN < r.foeSize then
			v.foeLabel = ("Enemy · %d of %d"):format(r.foeN, r.foeSize)
		end
	end
	return v
end

-- ---------------------------------------------------------------------------
-- The section
-- ---------------------------------------------------------------------------

local LEFT, RIGHT = 8, 6

-- TWO CARDS (Josh 2026-11-26, of the first card, which led with item level
-- in every bracket: "At <60, average level is most important. At 60, we
-- obviously dont even need average level, and ilevel bcomes important").
--
--   below 60                              at 60
--   TEAM LEVEL        Enemy · 13 of 15    TEAM GEAR            All read
--   36.9                          38.0    31.1  About usual
--   TEAM GEAR                 All read
--   31.1  About usual
--
-- Below 60 both teams' levels are the large numbers, and your team's gear is
-- a smaller line under them. At 60 everyone is one level, so the levels are
-- left out and gear is the large number.
--
-- NO BAR (Josh 2026-11-26: "Not sure the ilvl meter actually adds much...
-- let's remove that and save some space"). Under the item level there was a
-- bar in four colours, low to geared, with a mark where the team stood. The
-- number's own colour and the words beside it say the same.
local LAYOUT = {
	level = { tall = 78, gearAt = 58, gearSize = 13, verdictSize = 10, countAt = 46 },
	gear = { tall = 46, gearAt = 19, gearSize = 20, verdictSize = 11, countAt = 6 },
}
T.LAYOUT = LAYOUT

local function words(f, role, size, color, right)
	local fs = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	BT.Fonts.Set(fs, role, size)
	fs:SetTextColor(color[1], color[2], color[3])
	fs:SetJustifyH(right and "RIGHT" or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function put(fs, s, c)
	fs:SetText(s)
	fs:SetTextColor(c[1], c[2], c[3])
end

-- the card laid out for a bracket below 60 ("level") or for 60 ("gear");
-- done again only when that changes
function M.Arrange(mode)
	local L, f = LAYOUT[mode], M.card
	if mode == M.mode then
		return L
	end
	M.mode = mode
	local byLevel = mode == "level"
	M.head:SetText(string.upper(byLevel and "Team level" or "Team gear"))
	for _, fs in ipairs({ M.level, M.foe, M.foeLabel, M.gearHead }) do
		fs:SetShown(byLevel)
	end
	M.count:ClearAllPoints()
	M.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -L.countAt)
	BT.Fonts.Set(M.gear, "name", L.gearSize)
	M.gear:ClearAllPoints()
	M.gear:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -L.gearAt)
	BT.Fonts.Set(M.verdict, "text", L.verdictSize)
	f:SetHeight(L.tall)
	return L
end

function M.Update()
	local f = M.frame
	if not f then
		return
	end
	local want = T.match ~= nil and BT.Enabled("teams")
	if want ~= M.shownFor then
		M.shownFor = want
		f:SetShown(want)
		BT.Dock.Relayout()
	end
	if not want then
		return
	end
	local L = M.Arrange(T.match.lo >= 60 and "gear" or "level")
	local v = T.View()
	M.count:SetText(v.count)
	put(M.gear, v.gear or "-", v.gearColor)
	put(M.verdict, v.verdict or "None read yet", v.d and v.gearColor or DIM)
	put(M.level, v.level or "-", v.levelColor)
	M.foeLabel:SetText(v.foeLabel)
	put(M.foe, v.foe or "-", v.foeColor)

	-- THE OBJECTIVES ABOVE THE CARD (Modules/PvP/Objectives.lua): the score,
	-- the bases and their timers, in a battleground it knows. The card sits
	-- under however tall that is, and the section is as tall as both.
	local top = T.Objectives and T.Objectives.Update(f, clock()) or 0
	if top ~= M.top or L.tall ~= M.tall then
		M.top, M.tall = top, L.tall
		M.card:ClearAllPoints()
		M.card:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
		M.card:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
		f.wantHeight = top + L.tall
		f:SetHeight(top + L.tall)
		BT.Dock.Relayout()
	end
end

-- what the colours mean, and where the numbers come from
function M.Tip()
	local m = T.match
	if not (m and BT.Tip) then
		return
	end
	local _, _, place = T.Place()
	BT.Tip.Show(M.frame, { build = function(t)
		t:Header({ name = "Battleground teams", sub = place or "Battleground" })
		t:Section("Item level against usual")
		local gear = { "1 or more below", "Within 1", "1 to 3 above", "3 or more above" }
		for i = 4, 1, -1 do
			t:ListRow(T.TIERS[i].name, gear[i], nil, T.TIERS[i])
		end
		if m.lo < 60 then
			t:Section(("Level in a %d-%d match"):format(m.lo, m.lo + 9))
			local span = { { 0, 2 }, { 3, 5 }, { 6, 7 }, { 8, 9 } }
			for i = 4, 1, -1 do
				t:ListRow(T.TIERS[i].name, ("%d to %d"):format(m.lo + span[i][1], m.lo + span[i][2]), nil, T.TIERS[i])
			end
		end
		if m.usual then
			-- (commas from 1,000: up to T.KEPT are kept; the code review, 2026-11-26)
			t:Note(("Usual comes from %s players read in the %d-%d bracket. Each teammate is compared at their own level.")
				:format(BT.Util.Commas(m.usual.n), m.lo, m.lo + 9))
		else
			t:Note(("%s players read in this bracket. BeebMod compares with usual after %d, with at least %d from other matches.")
				:format(BT.Util.Commas(m.read or 0), T.MIN_SAMPLES, T.MIN_OTHERS))
		end
		t:Note("Gear is read from teammates within about 30 yards. The game doesn't let addons inspect enemies.")
		t:Note("An enemy's level is read once you see them.")
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	local tall = LAYOUT.level.tall
	local section = BT.Dock.Section("teams", 7.5)
	M.frame = section
	section.kind = "card"
	section.wantHeight = tall
	-- the client draws nothing inside a frame with no height (see Performance)
	section:SetHeight(tall)
	-- the card is a frame of its own inside the section, so the objectives
	-- can sit above it and push it down (M.Update)
	local f = CreateFrame("Frame", nil, section)
	M.card, M.top, M.tall = f, 0, tall
	f:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	f:SetHeight(tall)

	-- the top line: what the large number is, and below 60 the enemy's count
	M.head = words(f, "name", 10, MUTED)
	M.head:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -6)
	M.foeLabel = words(f, "text", 10, MUTED, true)
	M.foeLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -6)
	-- both teams' levels, yours on the left
	M.level = words(f, "name", 20, INK)
	M.level:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -19)
	M.foe = words(f, "name", 20, INK, true)
	M.foe:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -19)
	-- your team's gear: its own heading below 60, under the levels
	M.gearHead = words(f, "name", 10, MUTED)
	M.gearHead:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -LAYOUT.level.countAt)
	M.gearHead:SetText(string.upper("Team gear"))
	M.count = words(f, "text", 10, MUTED, true)
	M.gear = words(f, "name", 13, INK)
	M.verdict = words(f, "text", 10, DIM)
	M.verdict:SetPoint("BOTTOMLEFT", M.gear, "BOTTOMRIGHT", 6, 1)

	M.Arrange("level")

	section:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	section:EnableMouse(true)
	section:SetScript("OnEnter", M.Tip)
	section:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return section
end

-- ---------------------------------------------------------------------------
-- The clock and the events
-- ---------------------------------------------------------------------------

-- in or out of a battleground: the match begun or dropped, and the quests
-- listed again for where you are
function T.Check()
	local place = T.Place()
	local on = place ~= nil and BT.Enabled("teams")
	-- a preview begun, changed or ended: the match it showed is dropped
	if T.match and T.match.preview ~= T.Preview() then
		T.match = nil
	end
	if on and not T.match then
		T.Begin()
		if not T.match.preview then
			T.Scan()
		end
	elseif not on and T.match then
		T.match = nil
	end
	if place ~= T.place then
		T.place = place
		local tracker = BT.GetModule("tracker")
		if tracker and tracker.Update and BT.Enabled("tracker") then
			pcall(tracker.Update)
		end
		-- and the journals' lines put away, or brought back (UI/Dock.lua, B.Hold)
		BT.Dock.Relayout()
	end
	M.Update()
end

T.SCAN_EVERY, T.BOARD_EVERY, T.DRAW_EVERY = 2, 15, 1

function T.Tick(now)
	local m = T.match
	if not m then
		return
	end
	now = now or clock()
	-- a preview reads nothing and asks about nobody; its timers still count
	if m.preview then
		if now - (m.drawAt or -math.huge) >= T.DRAW_EVERY then
			m.drawAt = now
			M.Update()
		end
		return
	end
	if now - (m.scanAt or -math.huge) >= T.SCAN_EVERY then
		m.scanAt = now
		T.Scan()
	end
	if now - (m.boardAt or -math.huge) >= T.BOARD_EVERY then
		m.boardAt = now
		ask("RequestBattlefieldScoreData")
		T.ReadBoard()
	end
	T.Ask()
	if now - (m.drawAt or -math.huge) >= T.DRAW_EVERY then
		m.drawAt = now
		M.Update()
	end
end

local function guarded(what, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		BT.Err("teams." .. what .. ": " .. tostring(err))
	end
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "INSPECT_READY",
	"UPDATE_BATTLEFIELD_SCORE", "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, a1)
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		-- the tracker's battleground quests follow this whether Teams is on or not
		guarded("check", T.Check)
		return
	end
	if not (T.match and BT.Enabled("teams")) then
		return
	end
	if event == "INSPECT_READY" then
		guarded("ready", T.Ready, a1)
	elseif event == "UPDATE_BATTLEFIELD_SCORE" then
		guarded("board", T.ReadBoard)
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		guarded("see", T.See, a1)
	elseif event == "PLAYER_TARGET_CHANGED" then
		guarded("see", T.See, "target")
	else
		guarded("see", T.See, "mouseover")
	end
end)

function M.Show(on)
	local frame = M.Build()
	if on then
		M.shownFor = nil
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(0.5, function()
				if T.match then
					guarded("tick", T.Tick)
				end
			end)
		end
		guarded("check", T.Check)
	else
		T.match = nil
		M.shownFor = false
		frame:Hide()
		if M.ticker then
			M.ticker:Cancel()
			M.ticker = nil
		end
		BT.Dock.Relayout()
	end
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
