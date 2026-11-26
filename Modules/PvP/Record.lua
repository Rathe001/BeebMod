-- A record for Claude: one battleground, as it happens (Josh 2026-11-26:
-- "Would we be able to add pvp objectives and timers to this pvp module?",
-- then "Let's try AB first").
--
-- WHAT NOBODY HAS SEEN YET, and the objectives would rest on:
--   whether the score at the top of the screen reads plain (the game's
--     widgets, C_UIWidgetManager), and which widget holds it
--   whether each base is a point on the battleground's map with a state an
--     addon can read (C_AreaPoiInfo), and how that state is told: a texture
--     number, an atlas, a description
--   whether a point being taken says how long is left, or the length has to
--     be timed from one change to the next
--   whether the battleground's chat lines ("has assaulted the blacksmith!")
--     reach an addon as plain words
--   what the game says of the gates' countdown, the match's clock, and the
--     wait at a graveyard
--
-- The Testing page's Record button arms it. It writes from the moment you
-- are in a battleground until you leave, only what changed, and stops by
-- itself. Armed through a /reload. Read from BeebModDB.teamsDump.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/PvP/Record.lua")

local T = BT.Teams or {}
BT.Teams = T

local R = {}
T.Record = R
R.MAX = 2500
R.LINE = 400

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function said(v)
	if v == nil then
		return "nil"
	end
	if secret(v) then
		return "secret"
	end
	return tostring(v)
end

-- a table as the client gave it, in words: its fields in order, a table
-- inside it the same way, two deep
local function flat(t, depth)
	if secret(t) then
		return "secret"
	end
	if type(t) ~= "table" then
		return said(t)
	end
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do
		local v = t[k]
		if type(v) == "table" and not secret(v) then
			out[#out + 1] = tostring(k) .. "=" .. ((depth or 0) < 2 and ("{" .. flat(v, (depth or 0) + 1) .. "}") or "{...}")
		elseif type(v) ~= "function" then
			out[#out + 1] = tostring(k) .. "=" .. said(v)
		end
	end
	return table.concat(out, ",")
end
R.Flat = flat

local function clock()
	local fn = rawget(_G, "GetTime")
	local ok, v = pcall(function() return fn and fn() end)
	return ok and type(v) == "number" and v or 0
end

-- a call of the client's by its name, "C_Map.GetBestMapForUnit" too: every
-- answer, or nothing where it has no such call or the call fails
local function call(name, ...)
	local space, fn = name:match("^([%w_]+)%.([%w_]+)$")
	local f
	if space then
		local tbl = rawget(_G, space)
		f = type(tbl) == "table" and tbl[fn] or nil
	else
		f = rawget(_G, name)
	end
	if type(f) ~= "function" then
		return nil
	end
	local res = { pcall(f, ...) }
	if not res[1] then
		return nil
	end
	return (table.unpack or unpack)(res, 2, 9)
end

local function dump()
	return type(BeebModDB) == "table" and BeebModDB.teamsDump or nil
end

function R.Note(...)
	local rec = R.on and dump()
	if not rec then
		return
	end
	if #rec.lines >= R.MAX then
		return
	end
	local parts = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		parts[#parts + 1] = type(v) == "table" and flat(v) or said(v)
	end
	local line = ("%.1f "):format(clock()) .. table.concat(parts, " | ")
	rec.lines[#rec.lines + 1] = #line > R.LINE and (line:sub(1, R.LINE) .. "...") or line
end

-- written only when it is not what was last written under `key`
local function changed(key, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		parts[#parts + 1] = type(v) == "table" and flat(v) or said(v)
	end
	local now = table.concat(parts, " | ")
	if R.last[key] == now then
		return false
	end
	R.last[key] = now
	R.Note(key, now)
	return true
end

-- ---------------------------------------------------------------------------
-- What is asked
-- ---------------------------------------------------------------------------

-- every way the client has of saying what a widget shows; the one that
-- answers for a widget is its kind
local GETTERS = { "GetDoubleStatusBarWidgetVisualizationInfo", "GetIconAndTextWidgetVisualizationInfo",
	"GetDoubleStateIconRowVisualizationInfo", "GetDoubleIconAndTextWidgetVisualizationInfo",
	"GetIconTextAndBackgroundWidgetVisualizationInfo", "GetIconTextAndCurrenciesWidgetVisualizationInfo",
	"GetStatusBarWidgetVisualizationInfo", "GetCaptureBarWidgetVisualizationInfo",
	"GetTextWithStateWidgetVisualizationInfo", "GetStackedResourceTrackerWidgetVisualizationInfo",
	"GetHorizontalCurrenciesWidgetVisualizationInfo", "GetBulletTextListWidgetVisualizationInfo",
	"GetTextureAndTextVisualizationInfo", "GetTextureAndTextRowVisualizationInfo",
	"GetTextureWithAnimationVisualizationInfo", "GetSpellDisplayVisualizationInfo",
	"GetZoneControlVisualizationInfo", "GetCaptureZoneVisualizationInfo", "GetScenarioHeaderCurrenciesAndBackgroundWidgetVisualizationInfo",
	"GetFillUpFramesWidgetVisualizationInfo", "GetDiscreteProgressStepsVisualizationInfo",
	"GetTextColumnRowVisualizationInfo", "GetItemDisplayVisualizationInfo", "GetUnitPowerBarWidgetVisualizationInfo",
	"GetTugOfWarWidgetVisualizationInfo", "GetDoubleStateIconRowVisualizationInfo" }
local SETS = { "GetTopCenterWidgetSetID", "GetBelowMinimapWidgetSetID", "GetObjectiveTrackerWidgetSetID",
	"GetPowerBarWidgetSetID" }

function R.Widgets()
	local W = rawget(_G, "C_UIWidgetManager")
	if type(W) ~= "table" then
		changed("widgets", "no C_UIWidgetManager")
		return
	end
	for _, setName in ipairs(SETS) do
		local set = call("C_UIWidgetManager." .. setName)
		local list = (not secret(set) and set ~= nil) and call("C_UIWidgetManager.GetAllWidgetsBySetID", set) or nil
		changed("set " .. setName, set, type(list) == "table" and not secret(list) and #list or said(list))
		if type(list) == "table" and not secret(list) then
			for _, w in ipairs(list) do
				local id = type(w) == "table" and w.widgetID
				if id ~= nil and not secret(id) then
					local got
					for _, g in ipairs(GETTERS) do
						local info = call("C_UIWidgetManager." .. g, id)
						if info ~= nil then
							got = true
							changed(("widget %s %s"):format(tostring(id), g), w.widgetType, info)
						end
					end
					if not got then
						changed("widget " .. tostring(id), w, "no getter answered")
					end
				else
					changed("widget ?", w)
				end
			end
		end
	end
end

function R.Points()
	local map = call("C_Map.GetBestMapForUnit", "player")
	changed("map", map, (not secret(map) and map) and flat((call("C_Map.GetMapInfo", map))) or "nil")
	if secret(map) or type(map) ~= "number" then
		return
	end
	local ids = call("C_AreaPoiInfo.GetAreaPOIForMap", map)
	changed("points", type(ids) == "table" and not secret(ids) and #ids or said(ids))
	if type(ids) ~= "table" or secret(ids) then
		return
	end
	for _, id in ipairs(ids) do
		if not secret(id) then
			local info = call("C_AreaPoiInfo.GetAreaPOIInfo", map, id)
			-- where it is on the map is left out of what counts as a change
			local where
			if type(info) == "table" and not secret(info) then
				where, info.position = info.position, nil
			end
			if changed("point " .. tostring(id), info) then
				R.Note("point " .. tostring(id) .. " timed", call("C_AreaPoiInfo.IsAreaPOITimed", id),
					call("C_AreaPoiInfo.GetAreaPOISecondsLeft", id),
					type(where) == "table" and not secret(where) and where.GetXY and flat({ where:GetXY() }) or said(where))
			end
		end
	end
	-- the old way, where the client still has it
	local n = call("GetNumMapLandmarks")
	if n ~= nil then
		changed("landmarks", n)
	end
end

function R.Clock()
	changed("match state", call("C_PvP.GetActiveMatchState"), call("C_PvP.IsMatchActive"),
		call("C_PvP.IsMatchComplete"), call("C_PvP.GetActiveMatchWinner"))
	local now = clock()
	if now - (R.clockAt or -math.huge) >= 60 then
		R.clockAt = now
		R.Note("match clock", call("C_PvP.GetActiveMatchDuration"), call("GetBattlefieldInstanceRunTime"),
			call("C_PvP.GetActiveMatchStartTime"), call("GetBattlefieldInstanceExpiration"))
	end
	-- dead: the wait at the graveyard
	local dead = call("UnitIsDeadOrGhost", "player")
	if not secret(dead) and dead then
		if now - (R.deadAt or -math.huge) >= 3 then
			R.deadAt = now
			R.Note("dead", call("GetAreaSpiritHealerTime"), call("GetCorpseRecoveryDelay"))
		end
	end
end

local CALLS = { "C_UIWidgetManager.GetTopCenterWidgetSetID", "C_UIWidgetManager.GetAllWidgetsBySetID",
	"C_AreaPoiInfo.GetAreaPOIForMap", "C_AreaPoiInfo.GetAreaPOIInfo", "C_AreaPoiInfo.GetAreaPOISecondsLeft",
	"C_AreaPoiInfo.IsAreaPOITimed", "C_Map.GetBestMapForUnit", "C_PvP.GetActiveMatchState",
	"C_PvP.GetActiveMatchDuration", "C_PvP.IsMatchActive", "GetBattlefieldInstanceRunTime",
	"GetAreaSpiritHealerTime", "GetNumMapLandmarks", "GetMapLandmarkInfo", "GetWorldStateUIInfo",
	"GetNumWorldStateUI", "GetBattlefieldFlagPosition", "GetNumBattlefieldFlagPositions",
	"C_PvP.GetBattlefieldFlagPosition", "C_PvP.GetArenaCrowdControlInfo", "GetBattlefieldVehicleInfo" }

-- once, as the record begins: where you are, and which calls the client has
function R.Where()
	R.Note("where", call("IsInInstance"))
	R.Note("instance", call("GetInstanceInfo"))
	R.Note("zone", call("GetRealZoneText"), call("GetSubZoneText"))
	local have, lack = {}, {}
	for _, name in ipairs(CALLS) do
		local space, fn = name:match("^([%w_]+)%.([%w_]+)$")
		local tbl = space and rawget(_G, space)
		local f = space and (type(tbl) == "table" and tbl[fn]) or (not space and rawget(_G, name)) or nil
		local list = type(f) == "function" and have or lack
		list[#list + 1] = name
	end
	-- the scoreboard's own columns: flag captures, bases assaulted and so on
	R.Note("stat columns", call("C_PvP.GetMatchPVPStatColumns"))
	R.Note("bracket", call("C_PvP.GetActiveMatchBracket"))
	R.Note("calls the client has", table.concat(have, ","))
	R.Note("calls it lacks", table.concat(lack, ","))
	-- every call of C_PvP's and C_AreaPoiInfo's, by name, for what was not thought of
	for _, space in ipairs({ "C_PvP", "C_AreaPoiInfo" }) do
		local names = {}
		for k, v in pairs(type(rawget(_G, space)) == "table" and rawget(_G, space) or {}) do
			if type(v) == "function" then
				names[#names + 1] = k
			end
		end
		table.sort(names)
		local rec = dump()
		if rec then
			rec[space] = table.concat(names, ",")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Starting and stopping
-- ---------------------------------------------------------------------------

-- a real one: a battleground previewed from the Testing page is not written
-- down, and would have replaced the record of the real match of that name
-- (the code review, 2026-11-26)
local function inBattleground()
	if T.Preview and T.Preview() then
		return false
	end
	return T.Place ~= nil and T.Place() ~= nil
end

-- a match still being written this long ago is the same match: a /reload
-- takes seconds, the next match of the same battleground takes minutes
R.SAME_MATCH = 120

-- WSG's flags, and whatever else a battleground has that Arathi Basin
-- doesn't (Josh 2026-11-26: "Can we build out the other BGs?"): a flag on
-- the map, the two "arena" units a flag carrier is shown as, and vehicles
function R.Flags()
	local map = call("C_Map.GetBestMapForUnit", "player")
	if secret(map) or type(map) ~= "number" then
		return
	end
	for i = 1, 4 do
		local x, y, texture = call("C_PvP.GetBattlefieldFlagPosition", i, map)
		-- where it is changes all the time; that it is there, and its picture, don't
		changed("flag " .. i, x ~= nil and "on the map" or "none", texture)
	end
	for i = 1, 2 do
		local u = "arena" .. i
		changed("unit " .. u, call("UnitExists", u), call("UnitName", u), (select(2, call("UnitClass", u))),
			call("UnitFactionGroup", u))
	end
	local vehicles = call("C_PvP.GetBattlefieldVehicles", map)
	changed("vehicles", type(vehicles) == "table" and not secret(vehicles) and #vehicles or said(vehicles))
end

-- EVERY BATTLEGROUND YOU PLAY, ONE RECORD EACH (2026-11-26). The first
-- recorder wrote one match and stopped, which meant a click before every
-- queue. It stays armed now, and keeps the latest match of each
-- battleground by name, until the Testing page's Clear takes them out.
function R.Tick()
	local rec = dump()
	if not (rec and rec.armed) then
		return
	end
	local inside = inBattleground()
	if inside and not R.on then
		local _, _, name = T.Place()
		name = type(name) == "string" and name or "?"
		rec.matches = type(rec.matches) == "table" and rec.matches or {}
		R.name = name
		R.on, R.last, R.clockAt, R.deadAt = true, {}, nil, nil
		-- A /RELOAD IN THE MATCH GOES ON WITH ITS RECORD (the code review,
		-- 2026-11-26: it began an empty one, and the lines before the reload
		-- were lost)
		local now = BT.Util.Now()
		if rec.live == name and type(rec.matches[name]) == "table" and now - (tonumber(rec.liveAt) or 0) <= R.SAME_MATCH then
			rec.lines = rec.matches[name]
			R.Note("reloaded")
		else
			rec.lines = {}
			rec.matches[name] = rec.lines
		end
		rec.live, rec.liveAt = name, now
		R.Where()
	elseif not inside and R.on then
		R.Note("done")
		R.on = false
		rec.live, rec.liveAt = nil, nil
		BT.Util.Print(("PvP: %s is written down. Type /reload to save it."):format(R.name or "The battleground"))
		return
	end
	if R.on then
		rec.liveAt = BT.Util.Now()
		R.Widgets()
		R.Points()
		R.Flags()
		R.Clock()
	end
end

-- the Record button: armed for the battleground you are in, or the next one
function R.Arm()
	BT.EnsureBound()
	-- the matches already written are kept: a second click loses nothing
	local had = type(BeebModDB.teamsDump) == "table" and BeebModDB.teamsDump.matches or nil
	BeebModDB.teamsDump = { at = BT.Util.Now(), armed = true, lines = {}, matches = type(had) == "table" and had or {} }
	R.on, R.last = false, {}
	R.Watch()
	R.Tick()
end

local EVENTS = { "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_MONSTER_YELL", "START_TIMER", "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE",
	"PVP_MATCH_STATE_CHANGED", "UPDATE_UI_WIDGET", "AREA_POIS_UPDATED", "PLAYER_DEAD", "PLAYER_ALIVE",
	"AREA_SPIRIT_HEALER_IN_RANGE", "AREA_SPIRIT_HEALER_OUT_OF_RANGE", "UPDATE_BATTLEFIELD_STATUS",
	"BATTLEFIELD_MGR_STATE_CHANGE", "PLAYER_ENTERING_BATTLEGROUND", "ARENA_OPPONENT_UPDATE",
	"BATTLEGROUND_POINTS_UPDATE", "BATTLEGROUND_OBJECTIVES_UPDATE", "CHAT_MSG_MONSTER_EMOTE",
	"CHAT_MSG_RAID_WARNING", "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP" }

function R.Watch()
	if R.events then
		return
	end
	R.events = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do
		pcall(R.events.RegisterEvent, R.events, event)
	end
	R.events:SetScript("OnEvent", function(_, event, a, b, c, d)
		if not R.on then
			return
		end
		local ok, err = pcall(function()
			-- the score widget says so many times a second: counted, not written
			if event == "UPDATE_UI_WIDGET" then
				R.widgetEvents = (R.widgetEvents or 0) + 1
				return
			end
			R.Note("event " .. event, a, b, c, d)
			if event == "PLAYER_DEAD" then
				R.Note("dead", call("GetAreaSpiritHealerTime"))
			end
			-- and what changed with it, read at once
			if event:find("^CHAT_MSG_BG") or event == "AREA_POIS_UPDATED" then
				R.Points()
				R.Widgets()
				R.Flags()
			end
		end)
		if not ok then
			BT.Err("pvp.record: " .. tostring(err))
		end
	end)
	if C_Timer and C_Timer.NewTicker then
		R.ticker = C_Timer.NewTicker(1, function()
			local ok, err = pcall(R.Tick)
			if not ok then
				BT.Err("pvp.record: " .. tostring(err))
			end
		end)
	end
end

BT.Record("teamsDump", function()
	R.Arm()
end, "teams", "every battleground you play")

-- armed before a /reload: still armed after it
local boot = CreateFrame("Frame")
pcall(boot.RegisterEvent, boot, "PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function()
	local rec = dump()
	if type(rec) == "table" and rec.armed and type(rec.lines) == "table" then
		R.last = R.last or {}
		R.Watch()
	end
end)
