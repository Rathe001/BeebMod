-- Battleground objectives and timers: the score, who holds each base, how
-- long until a base being taken falls, and who wins when if nothing changes
-- (Josh 2026-11-26: "Would we be able to add pvp objectives and timers to
-- this pvp module?", "Let's try AB first", then "Can we build out the other
-- BGs?").
--
--   ARATHI BASIN                      25:35
--   Alliance 1,020             Horde 1,170
--   Horde wins in 8:18        1,570 - 2,000
--   Stables                       Alliance
--   Gold Mine                     Alliance
--   Blacksmith               Horde in 0:42
--   Farm                             Horde
--   Lumber Mill                      Horde
--
-- WHAT ARATHI BASIN RESTS ON (the Testing page's records of two matches,
-- 2026-11-26, Modules/PvP/Record.lua):
--   THE SCORE is the game's own widget at the top of the screen: a double
--     status bar in the top-centre set, the Alliance on its left (950 and
--     1,070 of 2,000 as the first record began; the Horde's side reached
--     2,000 and "The Horde wins!").
--   A BASE is a point on the battleground's map (C_AreaPoiInfo). Its picture
--     number says its state. Each base has five in a row: nobody's, the
--     Alliance taking, the Alliance's, the Horde taking, the Horde's. The
--     Gold Mine's start at 16, the Lumber Mill's at 21, the Blacksmith's at
--     26, the Farm's at 31 and the Stables' at 36. Twenty of the twenty-five
--     were seen, each matching the chat line beside it.
--   A CAPTURE TAKES 60 SECONDS. Thirteen were timed from "has assaulted" to
--     "has taken", all between 60 and 61.2, read once a second. The game
--     says a point is timed and gives no seconds left (IsAreaPOITimed true,
--     GetAreaPOISecondsLeft nil), so the clock is BeebMod's own, started
--     when it sees the base change. A base already being taken when you
--     come in has no clock.
--   THE SCORE GOES UP 10 AT A TIME: every 12 seconds with one base, 9 with
--     two, 6 with three and 3 with four, all four measured.
--   THE MATCH'S CLOCK is C_PvP.GetActiveMatchDuration.
--
-- THE OTHER BATTLEGROUNDS ARE FROM WHAT IS PUBLISHED, NOT MEASURED (Josh
-- 2026-11-26: "Can you search either the game files or the internet for the
-- data you need, so I don't have to keep recording?"). The addon Capping
-- (github.com/BigWigsMods/Capping) runs on this game, and its code states
-- these as facts of the game. None of its code is here; BeebMod's is its
-- own, written from the facts:
--   the instance numbers: Warsong Gulch 489, Alterac Valley 30, Darkspear
--     Islands 2997
--   Arathi Basin with all five bases: 30 points a second
--   Darkspear Islands: four bases, 60 seconds to capture, a flag that comes
--     back 23 seconds after it is captured, and a capture worth 75, 85 or
--     100 points with one, two or three bases
--   Warsong Gulch: the flags come back 12 seconds after a capture
--   Alterac Valley: a tower or graveyard takes 300 seconds
--   the picture number of a point being taken, for every kind of point
--     (O.TAKING)
-- NOT YET SEEN IN GAME: everything outside Arathi Basin. Where a published
-- fact turns out wrong here, a record from the Testing page settles it.
--
-- NOT HERE: the gates' countdown (no record began before the gates opened)
-- and the wait at a graveyard (the game's own window counts that down).
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/PvP/Objectives.lua")

local T = BT.Teams or {}
BT.Teams = T

local O = {}
T.Objectives = O

O.ARATHI_BASIN, O.WARSONG_GULCH, O.ALTERAC_VALLEY, O.DARKSPEAR_ISLANDS = 529, 489, 30, 2997

-- WHAT IS KNOWN OF EACH, by the game's number for its instance.
--   capture   seconds a point takes to fall
--   every     seconds between steps of the score, by bases held
--   gain      points a step, by bases held
--   measured  no table of steps: the win time is worked out from how fast
--             each side's score has been going up
--   jump      a rise this big is a flag capture, not a step
--   flag      seconds until a captured flag comes back
--   flags     the two flags are the objective: a row each (Warsong Gulch)
--   five      a point's picture number alone says its state (O.StateOf)
--   list      "all": every point has a row. "taken": only the points being
--             taken (Alterac Valley has over twenty)
--   score     false where the top of the screen has no two scores to read
O.PLACES = {
	[O.ARATHI_BASIN] = { name = "Arathi Basin", capture = 60, list = "all", five = true,
		every = { 12, 9, 6, 3, 1 }, gain = { 10, 10, 10, 10, 30 } },
	[O.DARKSPEAR_ISLANDS] = { name = "Darkspear Islands", capture = 60, list = "all", measured = true, jump = 65,
		flag = 23 },
	[O.WARSONG_GULCH] = { name = "Warsong Gulch", flags = true, flag = 12, score = false },
	[O.ALTERAC_VALLEY] = { name = "Alterac Valley", capture = 300, list = "taken", score = false },
}

-- Arathi Basin's five kinds of point, five pictures each, from 16 to 40
O.FIRST, O.STATES, O.LAST = 16, 5, 40
-- the picture of a point being taken, and by whom, for the other kinds: a
-- graveyard, a tower, a workshop, a hangar, the docks, a refinery, a
-- market, ruins and a shrine
O.TAKING = {
	[4] = "Alliance", [14] = "Horde", [9] = "Alliance", [12] = "Horde",
	-- a mine, a lumber mill, a blacksmith, a farm and stables, where another
	-- battleground has one
	[17] = "Alliance", [19] = "Horde", [22] = "Alliance", [24] = "Horde", [27] = "Alliance", [29] = "Horde",
	[32] = "Alliance", [34] = "Horde", [37] = "Alliance", [39] = "Horde",
	[137] = "Alliance", [139] = "Horde", [142] = "Alliance", [144] = "Horde",
	[147] = "Alliance", [149] = "Horde", [152] = "Alliance", [154] = "Horde",
	[208] = "Alliance", [209] = "Horde", [213] = "Alliance", [214] = "Horde",
	[218] = "Alliance", [219] = "Horde",
}

local INK = BT.TEXT.ink
local MUTED = { 0.42, 0.48, 0.45 }
local DIM = { 0.58, 0.65, 0.62 }
local LEFT, RIGHT = 8, 6
local HEAD, SCORE, WINS, ROW, FOOT = 20, 16, 14, 13, 6

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function number(v)
	return not secret(v) and type(v) == "number"
end

-- a table of the client's and one of its calls; nothing where it has no
-- such call or the call fails
local function call(space, name, ...)
	local tbl = rawget(_G, space)
	local fn = type(tbl) == "table" and tbl[name] or nil
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		return nil
	end
	return a, b
end

local function side(name)
	local pvp = BT.GetModule("pvp")
	return (pvp and pvp.SIDES and pvp.SIDES[name]) or INK
end

local function other(name)
	return name == "Alliance" and "Horde" or "Alliance"
end

-- "4:05"
function O.Time(secs)
	secs = math.max(0, math.floor(secs + 0.5))
	return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

-- ---------------------------------------------------------------------------
-- What the game says
-- ---------------------------------------------------------------------------

-- the battleground you are in, if it is one of O.PLACES: its number, its
-- name and what is known of it
function O.Where()
	-- one previewed from the Testing page (Modules/PvP/Teams.lua, T.Preview)
	local shown = T.Preview and T.Preview()
	if shown then
		local name = shown:gsub(" at 60$", "")
		for id, place in pairs(O.PLACES) do
			if place.name == name then
				return id, name, place
			end
		end
		return nil
	end
	local fn = rawget(_G, "GetInstanceInfo")
	if type(fn) ~= "function" then
		return nil
	end
	local ok, name, kind, _, _, _, _, _, id = pcall(fn)
	if not ok or secret(kind) or kind ~= "pvp" or secret(id) or not O.PLACES[id] then
		return nil
	end
	local place = O.PLACES[id]
	return id, (not secret(name) and type(name) == "string" and name ~= "") and name or place.name, place
end

-- the Alliance's score, the Horde's, and what wins
function O.Score()
	local set = call("C_UIWidgetManager", "GetTopCenterWidgetSetID")
	if set == nil or secret(set) then
		return nil
	end
	local list = call("C_UIWidgetManager", "GetAllWidgetsBySetID", set)
	if type(list) ~= "table" or secret(list) then
		return nil
	end
	for _, w in ipairs(list) do
		local id = type(w) == "table" and w.widgetID
		if id ~= nil and not secret(id) then
			local info = call("C_UIWidgetManager", "GetDoubleStatusBarWidgetVisualizationInfo", id)
			if type(info) == "table" and not secret(info) and number(info.leftBarValue) and number(info.rightBarValue) then
				local max = number(info.leftBarMax) and info.leftBarMax > 0 and info.leftBarMax or 2000
				return info.leftBarValue, info.rightBarValue, max
			end
		end
	end
	return nil
end

-- WHOSE A POINT IS, OR WHO IS TAKING IT. Arathi Basin's kinds say both by
-- the picture's number. For any other kind the picture says who is taking
-- it (O.TAKING), and whose it is comes from the point's own words
-- ("Alliance Controlled"). Returns the owner, who is taking it, and whether
-- the answer is to be believed.
--
-- THE NUMBER ALONE ONLY IN ARATHI BASIN (the code review, 2026-11-26): the
-- five-in-a-row rule was applied in every battleground, and a point
-- elsewhere whose picture fell in 16 to 40 was read as one of Arathi
-- Basin's. `place.five` says the rule holds there.
function O.StateOf(texture, description, place)
	if place and place.five and number(texture) and texture >= O.FIRST and texture <= O.LAST then
		local k = (texture - O.FIRST) % O.STATES
		if k == 1 then
			return nil, "Alliance", true
		elseif k == 2 then
			return "Alliance", nil, true
		elseif k == 3 then
			return nil, "Horde", true
		elseif k == 4 then
			return "Horde", nil, true
		end
		return nil, nil, true
	end
	if number(texture) and O.TAKING[texture] then
		return nil, O.TAKING[texture], true
	end
	if not secret(description) and type(description) == "string" then
		local d = description:lower()
		if d:find("conflict", 1, true) then
			return nil, "?", true
		elseif d:find("alliance", 1, true) then
			return "Alliance", nil, true
		elseif d:find("horde", 1, true) then
			return "Horde", nil, true
		end
	end
	return nil, nil, false
end

-- every point on the battleground's map, north to south:
-- { name, owner, taking, known }
function O.Bases(place)
	local map = call("C_Map", "GetBestMapForUnit", "player")
	if not number(map) then
		return nil
	end
	local ids = call("C_AreaPoiInfo", "GetAreaPOIForMap", map)
	if type(ids) ~= "table" or secret(ids) then
		return nil
	end
	local out = {}
	for _, id in ipairs(ids) do
		local info = not secret(id) and call("C_AreaPoiInfo", "GetAreaPOIInfo", map, id) or nil
		if type(info) == "table" and not secret(info) and not secret(info.name) and type(info.name) == "string" then
			local owner, taking, known = O.StateOf(info.textureIndex, info.description, place)
			local y = 0
			local at = info.position
			if type(at) == "table" and not secret(at) and type(at.GetXY) == "function" then
				local ok, _, py = pcall(at.GetXY, at)
				if ok and number(py) then
					y = py
				end
			end
			out[#out + 1] = { name = info.name, owner = owner, taking = taking, y = y, known = known }
		end
	end
	table.sort(out, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.name < b.name
	end)
	return out
end

-- WHO WINS, AND WHEN, if every base stays as it is, from a table of steps:
-- the side that reaches the winning score first, the seconds until it does,
-- and the other side's score by then. Nil while nobody holds a base.
-- `place`: whose table; Arathi Basin's where none is given.
function O.Forecast(alliance, horde, max, heldA, heldH, place)
	place = place or O.PLACES[O.ARATHI_BASIN]
	local function left(score, held)
		local every, gain = place.every[held], place.gain[held]
		if not every then
			return nil
		end
		return math.max(0, math.ceil((max - score) / gain)) * every
	end
	local function by(score, held, secs)
		local every, gain = place.every[held], place.gain[held]
		return math.min(max, score + (every and math.floor(secs / every) * gain or 0))
	end
	local ta, th = left(alliance, heldA), left(horde, heldH)
	if not ta and not th then
		return nil
	end
	if th == nil or (ta ~= nil and ta <= th) then
		return "Alliance", ta, by(horde, heldH, ta)
	end
	return "Horde", th, by(alliance, heldA, th)
end

-- The same, from how fast each side's score is going up: points a second.
function O.ForecastByRate(alliance, horde, max, rateA, rateH)
	local ta = rateA and rateA > 0 and (max - alliance) / rateA or nil
	local th = rateH and rateH > 0 and (max - horde) / rateH or nil
	if not ta and not th then
		return nil
	end
	local function by(score, rate, secs)
		return math.min(max, math.floor((score + (rate or 0) * secs) / 10) * 10)
	end
	if th == nil or (ta ~= nil and ta <= th) then
		return "Alliance", ta, by(horde, rateH, ta)
	end
	return "Horde", th, by(alliance, rateA, th)
end

-- HOW FAST A SCORE IS GOING UP, for a battleground with no table of steps.
-- Each rise is timed from the one before; the rate is the last two rises
-- together. A rise bigger than the place's `jump` is a flag capture and is
-- passed over. A side holding nothing has no rate.
function O.Rate(key, score, held, now, place)
	local r = O.rates[key]
	if not r then
		r = { score = score, at = now }
		O.rates[key] = r
		return nil
	end
	if held == 0 then
		r.score, r.at, r.a, r.b = score, now, nil, nil
		return nil
	end
	if score ~= r.score then
		local rise, took = score - r.score, now - r.at
		if rise > 0 and rise <= (place.jump or math.huge) and took >= 0.5 then
			r.b, r.a = r.a, { rise = rise, took = took }
		end
		r.score, r.at = score, now
	end
	if not r.a then
		return nil
	end
	local rise, took = r.a.rise + (r.b and r.b.rise or 0), r.a.took + (r.b and r.b.took or 0)
	return took > 0 and rise / took or nil
end

-- ---------------------------------------------------------------------------
-- The flags, from the battleground's chat lines
-- ---------------------------------------------------------------------------

-- A LINE ABOUT A FLAG. Warsong Gulch says each change in words: "The
-- Alliance Flag was picked up by Das!", "... was dropped by Das!", "... was
-- returned to its base by Ann!", "Das captured the Alliance flag!". These
-- are Classic's lines; nobody has checked that this game's read the same. A
-- capture, in any battleground with a flag, starts the wait for it to come
-- back.
function O.Chat(text, now)
	local _, _, place = O.Where()
	if not place or not place.flag or secret(text) or type(text) ~= "string" then
		return false
	end
	O.flags = O.flags or {}
	local low = text:lower()
	if low:find("captured the", 1, true) then
		O.flagBack = now + place.flag
		O.flags.Alliance, O.flags.Horde = nil, nil
		return true
	end
	if low:find("placed at their bases", 1, true) then
		O.flags.Alliance, O.flags.Horde = nil, nil
		return true
	end
	local which = (low:find("alliance flag", 1, true) and "Alliance") or (low:find("horde flag", 1, true) and "Horde")
	if not which then
		return false
	end
	local who = text:match("picked up by (.-)!")
	if who then
		O.flags[which] = { carried = who }
	elseif low:find("dropped", 1, true) then
		O.flags[which] = { dropped = true }
	elseif low:find("returned", 1, true) then
		O.flags[which] = nil
	else
		return false
	end
	return true
end

-- a flag's row: whose flag, what has become of it, and in whose colour
function O.FlagWords(which)
	local f = O.flags and O.flags[which]
	if type(f) == "table" and f.carried then
		return f.carried, side(other(which))
	elseif type(f) == "table" and f.dropped then
		return "Dropped", DIM
	end
	return "At base", MUTED
end

-- ---------------------------------------------------------------------------
-- Everything it shows
-- ---------------------------------------------------------------------------

-- A BATTLEGROUND PREVIEWED FROM THE TESTING PAGE: made-up numbers, with one
-- of everything the place can show. Its countdowns run, and start again
-- when they reach nothing.
function O.Demo(id, name, place, now)
	O.demoAt = O.demoAt or now
	local function left(total, into)
		return total - ((now - O.demoAt + into) % total)
	end
	local s = { name = name, place = place, rows = {}, clock = 1535 + (now - O.demoAt), heldA = 2, heldH = 2,
		scored = place.score ~= false }
	local function base(n, owner, taking, secs)
		local said, colour = O.BaseWords({ owner = owner, taking = taking, ends = secs and (now + secs), known = true }, now)
		s.rows[#s.rows + 1] = { n, said, colour }
	end
	if id == O.ARATHI_BASIN then
		base("Stables", "Alliance")
		base("Gold Mine", "Alliance")
		base("Blacksmith", nil, "Horde", left(60, 18))
		base("Farm", "Horde")
		base("Lumber Mill", "Horde")
		s.alliance, s.horde, s.max = 1020, 1170, 2000
		s.winner, s.secs, s.other = O.Forecast(s.alliance, s.horde, s.max, 2, 2, place)
	elseif id == O.DARKSPEAR_ISLANDS then
		base("Camp", "Alliance")
		base("Ruins", "Horde")
		base("Abandoned Tower", nil, "Alliance", left(60, 40))
		base("Shipwreck Cove")
		s.rows[#s.rows + 1] = { "Flag back in", O.Time(left(place.flag, 5)), INK }
		s.alliance, s.horde, s.max = 640, 710, 2000
		s.winner, s.secs, s.other = "Horde", 774, 1930
	elseif id == O.WARSONG_GULCH then
		s.rows[1] = { "Alliance flag", "Zug Zugson", side("Horde") }
		s.rows[2] = { "Horde flag", "At base", MUTED }
		s.rows[3] = { "Flags back in", O.Time(left(place.flag, 0)), INK }
	elseif id == O.ALTERAC_VALLEY then
		base("Stonehearth Bunker", nil, "Horde", left(place.capture, 100))
		base("Snowfall Graveyard", nil, "Alliance", left(place.capture, 220))
	end
	return s
end

-- as of `now`; nil outside a battleground it knows
function O.Read(now)
	local id, name, place = O.Where()
	if not id then
		return nil
	end
	if T.Preview and T.Preview() then
		return O.Demo(id, name, place, now)
	end
	-- a new match: nothing is known of when a base began to be taken, how
	-- fast a score goes up, or where a flag is
	if O.match ~= T.match or O.id ~= id then
		O.match, O.id, O.seen, O.rates, O.flags, O.flagBack = T.match, id, {}, {}, {}, nil
	end
	O.seen, O.rates = O.seen or {}, O.rates or {}
	local s = { name = name, place = place, rows = {} }
	local clock = call("C_PvP", "GetActiveMatchDuration")
	s.clock = number(clock) and clock > 0 and clock or nil

	local bases = place.list and O.Bases(place) or {}
	local heldA, heldH = 0, 0
	for _, b in ipairs(bases) do
		if b.owner == "Alliance" then
			heldA = heldA + 1
		elseif b.owner == "Horde" then
			heldH = heldH + 1
		end
		-- THE CLOCK STARTS WHEN THE CHANGE IS SEEN. The first look at a base
		-- starts none: one already being taken began nobody knows when.
		local code = (b.taking and ("t" .. b.taking)) or (b.owner and ("o" .. b.owner)) or "n"
		local seen = O.seen[b.name]
		if not seen then
			O.seen[b.name] = { code = code }
		elseif seen.code ~= code then
			seen.code = code
			seen.ends = b.taking and place.capture and (now + place.capture) or nil
		end
		b.ends = O.seen[b.name].ends
		if place.list == "all" or b.taking then
			local said, colour = O.BaseWords(b, now)
			s.rows[#s.rows + 1] = { b.name, said, colour }
		end
	end
	s.bases, s.heldA, s.heldH = bases, heldA, heldH
	if place.list == "taken" and #s.rows == 0 then
		s.rows[1] = { "Nothing being taken", "", MUTED, MUTED }
	end

	if place.flags then
		for _, which in ipairs({ "Alliance", "Horde" }) do
			local said, colour = O.FlagWords(which)
			s.rows[#s.rows + 1] = { which .. " flag", said, colour }
		end
	end
	if place.flag and O.flagBack and O.flagBack > now then
		s.rows[#s.rows + 1] = { place.flags and "Flags back in" or "Flag back in", O.Time(O.flagBack - now), INK }
	end

	if place.score ~= false then
		s.scored = true
		s.alliance, s.horde, s.max = O.Score()
		if s.alliance then
			if place.every then
				s.winner, s.secs, s.other = O.Forecast(s.alliance, s.horde, s.max, heldA, heldH, place)
			elseif place.measured then
				local ra = O.Rate("Alliance", s.alliance, heldA, now, place)
				local rh = O.Rate("Horde", s.horde, heldH, now, place)
				s.winner, s.secs, s.other = O.ForecastByRate(s.alliance, s.horde, s.max, ra, rh)
			end
		end
	end
	return s
end

-- what a base's row says on its right, and in which colour
function O.BaseWords(b, now)
	if b.taking then
		local who = b.taking ~= "?" and b.taking or nil
		local colour = who and side(who) or DIM
		if b.ends and b.ends > now then
			return who and ("%s in %s"):format(who, O.Time(b.ends - now)) or ("Taken in %s"):format(O.Time(b.ends - now)),
				colour
		end
		return who and ("%s taking"):format(who) or "Being taken", colour
	elseif b.owner then
		return b.owner, side(b.owner)
	end
	return b.known and "Nobody's" or "-", MUTED
end

-- ---------------------------------------------------------------------------
-- The block, at the top of the Teams section
-- ---------------------------------------------------------------------------

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

function O.Build(parent)
	if O.frame then
		return O.frame
	end
	local f = CreateFrame("Frame", nil, parent)
	O.frame = f
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	f:SetHeight(HEAD)
	O.head = words(f, "name", 10, MUTED)
	O.head:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -6)
	O.clock = words(f, "text", 10, MUTED, true)
	O.clock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -6)
	O.alliance = words(f, "name", 12, INK)
	O.alliance:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -HEAD)
	O.horde = words(f, "name", 12, INK, true)
	O.horde:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -HEAD)
	O.wins = words(f, "text", 10, DIM)
	O.wins:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -(HEAD + SCORE))
	O.final = words(f, "text", 10, DIM, true)
	O.final:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, -(HEAD + SCORE))
	O.rows = {}
	-- a line between the objectives and the teams under them
	O.rule = f:CreateTexture(nil, "ARTWORK")
	O.rule:SetHeight(1)
	O.rule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 0)
	O.rule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 0)
	O.rule:SetColorTexture(1, 1, 1, 0.07)
	f:EnableMouse(true)
	-- Shift-drag moves the dock from here too, as from any of its lines
	BT.Dock.MakeHandle(f)
	f:SetScript("OnEnter", O.Tip)
	f:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return f
end

local function row(i, top)
	local r = O.rows[i]
	local f = O.frame
	if not r then
		r = { name = words(f, "text", 11, INK), state = words(f, "text", 11, INK, true) }
		O.rows[i] = r
	end
	local y = -(top + (i - 1) * ROW)
	if r.y ~= y then
		r.y = y
		r.name:ClearAllPoints()
		r.name:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, y)
		r.state:ClearAllPoints()
		r.state:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT, y)
	end
	return r
end

-- Drawn again from what the game says now. How tall the block is: nothing
-- outside a battleground it knows.
function O.Update(parent, now)
	local s = O.Read(now)
	O.state = s
	if not s then
		if O.frame then
			O.frame:Hide()
		end
		return 0
	end
	local f = O.Build(parent)
	f:Show()
	O.head:SetText(string.upper(s.name))
	O.clock:SetText(s.clock and O.Time(s.clock) or "")
	for _, fs in ipairs({ O.alliance, O.horde, O.wins, O.final }) do
		fs:SetShown(s.scored == true)
	end
	local top = HEAD
	if s.scored then
		top = HEAD + SCORE + WINS
		if s.alliance then
			put(O.alliance, ("Alliance %s"):format(BT.Util.Commas(s.alliance)), side("Alliance"))
			put(O.horde, ("Horde %s"):format(BT.Util.Commas(s.horde)), side("Horde"))
		else
			put(O.alliance, "No score yet", MUTED)
			O.horde:SetText("")
		end
		if s.winner then
			O.wins:SetText(("%s wins in %s"):format(s.winner, O.Time(s.secs)))
			local a, h = s.winner == "Alliance" and s.max or s.other, s.winner == "Horde" and s.max or s.other
			O.final:SetText(("%s - %s"):format(BT.Util.Commas(a), BT.Util.Commas(h)))
		else
			O.wins:SetText("")
			O.final:SetText("")
		end
	end
	for i, line in ipairs(s.rows) do
		local r = row(i, top)
		put(r.name, line[1], line[4] or INK)
		put(r.state, line[2], line[3])
		r.name:Show()
		r.state:Show()
	end
	for i = #s.rows + 1, #O.rows do
		O.rows[i].name:Hide()
		O.rows[i].state:Hide()
	end
	local tall = top + #s.rows * ROW + FOOT
	f:SetHeight(tall)
	return tall
end

function O.Tip()
	local s = O.state
	if not (s and BT.Tip) then
		return
	end
	local place = s.place
	BT.Tip.Show(O.frame, { build = function(t)
		t:Header({ name = s.name, sub = s.clock and ("%s played"):format(O.Time(s.clock)) or "Battleground" })
		if s.alliance then
			t:Section("Score")
			t:ListRow("Alliance", ("%s / %s"):format(BT.Util.Commas(s.alliance), BT.Util.Commas(s.max)), nil, side("Alliance"))
			t:ListRow("Horde", ("%s / %s"):format(BT.Util.Commas(s.horde), BT.Util.Commas(s.max)), nil, side("Horde"))
			t:ListRow("Bases held", ("%d · %d"):format(s.heldA, s.heldH))
		end
		if place.capture then
			t:Note(("A capture takes %s. The countdown starts when BeebMod sees the change, so one already under way when you arrive has none.")
				:format(place.capture >= 120 and ("%d minutes"):format(place.capture / 60) or ("%d seconds"):format(place.capture)))
		end
		if place.every then
			t:Note("The win time assumes every base stays as it is now.")
		elseif place.measured then
			t:Note("The win time comes from how fast each score has been rising. It assumes every base stays as it is now.")
		end
		if place.flag then
			t:Note(("A captured flag comes back after %d seconds."):format(place.flag))
		end
		if place.flags then
			t:Note("Flag rows follow the battleground's chat lines, so a flag taken before you arrived shows as at base.")
		end
	end })
end

-- the battleground's own chat lines, for the flags
O.events = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }) do
	pcall(O.events.RegisterEvent, O.events, event)
end
O.events:SetScript("OnEvent", function(_, _, text)
	if not (T.match and BT.Enabled("teams")) then
		return
	end
	local fn = rawget(_G, "GetTime")
	local ok, now = pcall(function() return fn and fn() end)
	local did, err = pcall(O.Chat, text, ok and type(now) == "number" and now or 0)
	if not did then
		BT.Err("teams.flags: " .. tostring(err))
	end
end)
