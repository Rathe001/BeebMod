-- What counts as a kill, on a client with no combat log (Josh 2026-09-25).
--
-- This client forbids addons COMBAT_LOG_EVENT_UNFILTERED (see the README), so
-- there is no UNIT_DIED to listen for. A kill is pieced together from what the
-- client does say, which the MobProbe addon measured on 70009 (Josh
-- 2026-09-25: 18 kills over two sessions, solo, pulls, and mobs somebody else
-- tagged - the rule below counted exactly the 14 the XP lines said were ours
-- in the second, and none of the six that were not):
--
--   watching     every mob in a unit token we can read (the nameplates,
--                target, focus, mouseover, the soft target, the group's
--                targets), a few times a second: a mob we saw alive, with
--                the tag ours (UnitIsTapDenied false) and us on its threat,
--                that is then dead, is ours
--   the XP line  "Prideclaw dies, you gain 50 experience." - the client's own
--                word that the kill was ours, for a mob we watched alive and
--                then lost sight of. It names the mob and nothing else, so it
--                only ever confirms one we were watching
--   the loot     a corpse you can loot was tagged by you or your group; its
--                GUID comes with the loot window (GetLootSourceInfo)
--
-- Whichever says it first counts it, and the GUID means the others cannot
-- count it again - nor can the same corpse after a /reload, as the journal
-- keeps the last two hundred.
--
-- UnitHealth is SECRET on this client and UnitIsDead is not, which is all a
-- kill needs. The threat answer is sometimes secret too: a mob whose threat
-- was never readable falls back to "it was in combat, and so were we".
--
-- Nothing here draws anything; Menagerie.lua drives it from events and hears
-- about each kill through K.onKill.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Kills.lua")

local K = {}
BT.MenagerieKills = K

-- guid -> what we know about a mob in view: { npc, name, kind, family,
-- rank, level, zone, alive, denied, engaged, dead, t }
local W = {}
K.watch = W
-- guids already counted
local counted = {}
K.counted = counted
-- guids that are not mobs (players, their pets and totems): asked once
local notMobs = {}

-- how long an XP line may come after we last saw the mob it names
local XP_WINDOW = 15
-- a mob out of sight this long is forgotten
local FORGET = 300

-- what went where, for /bt menagerie debug
K.stats = { watched = 0, dead = 0, xp = 0, loot = 0, notOurs = 0, xpUnmatched = 0 }

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function now()
	return (type(GetTime) == "function" and GetTime()) or 0
end

-- "Creature-0-server-instance-zone-npcID-spawnUID". Vehicle- is a mob too;
-- Pet-, Player- and GameObject- (a herb, a vein, a chest) are not.
function K.Parse(guid)
	if type(guid) ~= "string" or secret(guid) then
		return nil
	end
	local kind, _, _, _, _, npc = strsplit("-", guid)
	if kind ~= "Creature" and kind ~= "Vehicle" then
		return nil
	end
	return tonumber(npc)
end

-- an answer we may keep, or nil: a refused call and a secret are both "not now"
local function ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or secret(v) then
		return nil
	end
	return v
end

-- the facts a page wants, each asked until it is readable and then kept
local FACTS = {
	{ "name", function(u) return UnitName and UnitName(u) end },
	{ "kind", function(u) return UnitCreatureType and UnitCreatureType(u) end },
	{ "family", function(u) return UnitCreatureFamily and UnitCreatureFamily(u) end },
	{ "rank", function(u) return UnitClassification and UnitClassification(u) end },
	{ "level", function(u) return UnitLevel and UnitLevel(u) end },
}

local function learn(w, unit)
	for _, f in ipairs(FACTS) do
		if w[f[1]] == nil then
			w[f[1]] = ask(f[2], unit)
		end
	end
	if w.zone == nil then
		w.zone = ask(GetRealZoneText) or ask(GetZoneText)
	end
end

-- the page's worth of a watched mob, for the journal
local function info(guid, w)
	return {
		guid = guid, npc = w.npc, name = w.name, kind = w.kind, family = w.family,
		rank = w.rank, level = w.level, zone = w.zone,
		myLevel = ask(UnitLevel, "player"),
	}
end

function K.Count(guid, w, how)
	if counted[guid] then
		return false
	end
	counted[guid] = true
	w.counted = true
	w.countedAt = now()
	K.stats[how] = (K.stats[how] or 0) + 1
	if K.onKill then
		K.onKill(info(guid, w), how)
	end
	return true
end

-- Ours: the tag was not somebody else's, and we were in the fight. A tag we
-- could never read is not held against it - the XP line and the loot are
-- there to say otherwise, and neither comes for somebody else's kill.
function K.Ours(w)
	return w.denied ~= true and w.engaged == true
end

-- One look at a unit token.
function K.Observe(unit, t)
	if not (UnitExists and ask(UnitExists, unit)) then
		return nil
	end
	-- checked before it is used as a key: a secret key only ever misses
	local guid = UnitGUID(unit)
	if type(guid) ~= "string" or secret(guid) or counted[guid] then
		return nil
	end
	-- A MOB ALREADY KNOWN IS CHEAP (Josh 2026-09-25): this runs five times a
	-- second for every nameplate, so the GUID is split and the pet question
	-- asked once per mob, and a corpse already dealt with is left alone
	if notMobs[guid] then
		return nil
	end
	local w = W[guid]
	if w and w.dead then
		return w
	end
	if not w then
		local npc = K.Parse(guid)
		if not npc then
			notMobs[guid] = true
			return nil
		end
		-- a player's pet, totem or guardian: a Creature GUID, but not a mob.
		-- Only a yes skips it - an older client says nil for no
		local pc = UnitPlayerControlled and UnitPlayerControlled(unit)
		if secret(pc) then
			return nil
		elseif pc then
			notMobs[guid] = true
			return nil
		end
		w = { npc = npc }
		W[guid] = w
		K.stats.watched = K.stats.watched + 1
	end
	t = t or now()
	w.t = t
	if not w.learnt then
		learn(w, unit)
		-- every fact in hand: nothing more to ask this mob
		w.learnt = w.name ~= nil and w.kind ~= nil and w.rank ~= nil and w.level ~= nil and w.zone ~= nil
	end

	local dead = UnitIsDead(unit)
	if secret(dead) then
		return w
	end
	if not dead then
		w.alive = true
		local denied = UnitIsTapDenied and UnitIsTapDenied(unit)
		if denied ~= nil and not secret(denied) then
			w.denied = denied and true or false
		end
		local threat = UnitThreatSituation and UnitThreatSituation("player", unit)
		if secret(threat) then
			w.threatHidden = true
		elseif threat ~= nil then
			w.engaged = true
			w.byThreat = true
		end
		-- no readable threat: in combat, and so are we
		if not w.byThreat and w.threatHidden then
			local a, b = UnitAffectingCombat(unit), UnitAffectingCombat("player")
			if a and b and not secret(a) and not secret(b) then
				w.engaged = true
			end
		end
	elseif not w.dead then
		w.dead = t
		-- a corpse we never saw standing is somebody's, but we cannot say whose
		if w.alive then
			if K.Ours(w) then
				K.Count(guid, w, "dead")
			else
				K.stats.notOurs = K.stats.notOurs + 1
			end
		end
	end
	return w
end

-- ---------------------------------------------------------------------------
-- The other two witnesses
-- ---------------------------------------------------------------------------

-- "%s dies, you gain %d experience." as a Lua pattern
local function patternOf(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
	return "^" .. p
end

local xpPatterns
local function xpName(text)
	if not xpPatterns then
		xpPatterns = {}
		-- the rested and group forms first: they begin the same way and say more
		for _, g in ipairs({ "COMBATLOG_XPGAIN_EXHAUSTION1", "COMBATLOG_XPGAIN_EXHAUSTION2",
			"COMBATLOG_XPGAIN_EXHAUSTION4", "COMBATLOG_XPGAIN_EXHAUSTION5", "COMBATLOG_XPGAIN_FIRSTPERSON" }) do
			xpPatterns[#xpPatterns + 1] = patternOf(_G[g])
		end
		xpPatterns[#xpPatterns + 1] = "^(.-) dies, you gain"
	end
	for _, p in ipairs(xpPatterns) do
		local name = text:match(p)
		if name then
			return name
		end
	end
	return nil
end
K.XPName = xpName

-- THE XP LINE WAITS A BEAT (Josh 2026-09-25, MobProbe session 3). It comes in
-- the same frame as the death, and often before the look that sees the
-- corpse - so matched at once, "Highlands Bandit dies" went to a DIFFERENT
-- Highlands Bandit standing on a nameplate, and the real one was then counted
-- by its death as well: two kills for one. A line is held for a second, by
-- which time the corpse has been seen, and then read.
local XP_SETTLE = 1
-- a mob seen this recently is still on its feet: not the one that died
local GONE = 1
local pendingXP = {}
K.pendingXP = pendingXP

function K.XP(text, t)
	if type(text) ~= "string" or secret(text) then
		return false
	end
	local name = xpName(text)
	if not name then
		return false
	end
	pendingXP[#pendingXP + 1] = { name = name, t = t or now() }
	return true
end

-- One held line, read. A death of that name counted around the same moment
-- is the kill it describes: the line is its receipt, and counts nothing. If
-- there is none, the kill happened where we could not see it, and it is the
-- watched mob of that name that is lying dead uncounted (seen alive, but not
-- known to be ours: now it is), or else the one out of sight longest ago -
-- never one that is standing in view.
function K.Resolve(x, t)
	for _, w in pairs(W) do
		if w.name == x.name and w.counted and not w.receipt and w.countedAt
			and math.abs(w.countedAt - x.t) <= 2 then
			w.receipt = true
			K.stats.confirmed = (K.stats.confirmed or 0) + 1
			return "receipt"
		end
	end
	local best, bestGuid
	for guid, w in pairs(W) do
		local candidate = w.name == x.name and not w.counted and w.alive
			and (w.dead or (t - (w.t or 0) >= GONE))
			and x.t - (w.t or 0) <= XP_WINDOW
		if candidate then
			local better = not best
				or (w.dead and not best.dead)
				or ((w.dead ~= nil) == (best.dead ~= nil) and (w.t or 0) > (best.t or 0))
			if better then
				best, bestGuid = w, guid
			end
		end
	end
	if best then
		best.receipt = true
		K.Count(bestGuid, best, "xp")
		return "counted"
	end
	K.stats.xpUnmatched = K.stats.xpUnmatched + 1
	return nil
end

-- the held lines old enough to read, oldest first
function K.Settle(t)
	t = t or now()
	while pendingXP[1] and t - pendingXP[1].t >= XP_SETTLE do
		K.Resolve(table.remove(pendingXP, 1), t)
	end
end

-- is somebody picking this pocket? (then the loot is a living mob's)
local function pickpocketing(t)
	local pp = BT.GetModule and BT.GetModule("pickpocket")
	return pp and pp.castAt and t - pp.castAt <= 3
end

-- Every corpse in the loot window. Loot you may take is loot from a kill
-- that was yours or your group's.
function K.Loot(t)
	if type(GetLootSourceInfo) ~= "function" or type(GetNumLootItems) ~= "function" then
		return 0
	end
	t = t or now()
	if pickpocketing(t) then
		return 0
	end
	local n = 0
	local seen = {}
	for slot = 1, (ask(GetNumLootItems) or 0) do
		local r = { pcall(GetLootSourceInfo, slot) }
		-- guid, quantity, guid, quantity, ...
		for i = 2, #r, 2 do
			local guid = r[i]
			if r[1] and type(guid) == "string" and not secret(guid) and not seen[guid] and not counted[guid] then
				seen[guid] = true
				local npc = K.Parse(guid)
				if npc and not K.Standing(guid) then
					local w = W[guid] or { npc = npc }
					W[guid] = w
					w.t = t
					if K.Count(guid, w, "loot") then
						n = n + 1
					end
				end
			end
		end
	end
	return n
end

-- a mob that is still on its feet (a pocket, whatever the cast says)
function K.Standing(guid)
	local token = type(UnitTokenFromGUID) == "function" and ask(UnitTokenFromGUID, guid)
	if type(token) ~= "string" then
		return false
	end
	local dead = UnitIsDead(token)
	return dead == false
end

-- ---------------------------------------------------------------------------
-- Looking
-- ---------------------------------------------------------------------------

-- softenemy is the action-targeting token, and it answered UNIT_HEALTH on 70009
K.TOKENS = { "target", "focus", "mouseover", "softenemy", "pettarget", "targettarget",
	"party1target", "party2target", "party3target", "party4target" }

local plates = {}
K.plates = plates

function K.PlateAdded(unit)
	plates[unit] = true
	K.Observe(unit)
end

-- the last look: a plate that goes at the moment of death carries the death
function K.PlateRemoved(unit)
	K.Observe(unit)
	plates[unit] = nil
end

-- the tokens an event names that are worth a look
function K.Watched(unit)
	if type(unit) ~= "string" then
		return false
	end
	return plates[unit] or unit == "target" or unit == "focus" or unit == "mouseover"
		or unit == "softenemy" or unit == "pettarget" or unit == "targettarget"
		or unit:match("^party%dtarget$") ~= nil
end

local lastForget = 0
function K.Scan(t)
	t = t or now()
	for _, u in ipairs(K.TOKENS) do
		K.Observe(u, t)
	end
	for u in pairs(plates) do
		K.Observe(u, t)
	end
	K.Settle(t)
	if t - lastForget > 30 then
		lastForget = t
		K.Forget(t)
	end
end

-- mobs long out of sight; the counted set is the journal's, not this
function K.Forget(t)
	for guid, w in pairs(W) do
		if t - (w.t or 0) > FORGET then
			W[guid] = nil
		end
	end
	-- a city's worth of players is only worth remembering for a while
	local n = 0
	for _ in pairs(notMobs) do
		n = n + 1
	end
	if n > 500 then
		for guid in pairs(notMobs) do
			notMobs[guid] = nil
		end
	end
end

-- a book was bound: the GUIDs this character counted before the reload
function K.Reset(set)
	for guid in pairs(counted) do
		counted[guid] = nil
	end
	for guid in pairs(set or {}) do
		counted[guid] = true
	end
	for guid in pairs(W) do
		W[guid] = nil
	end
	for guid in pairs(notMobs) do
		notMobs[guid] = nil
	end
end
