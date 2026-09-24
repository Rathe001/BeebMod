-- The combat log, by other means (Josh 2026-09-18).
--
-- This client forbids addons the raw combat log: registering
-- COMBAT_LOG_EVENT_UNFILTERED raises ADDON_ACTION_FORBIDDEN and the "blocked
-- from an action only available to the Blizzard UI" popup, which is what the
-- first install did. The modern engine computes meter aggregates natively
-- instead, and each combat source carries the two things a census wants:
--
--   combatSource = { name, sourceGUID, classFilename, totalAmount, ... }
--
-- So we read the finished fight when combat drops. It is a smaller net than
-- the combat log - only players the meter counted, not everyone in earshot -
-- but it is the whole group and anyone who fought beside you, for free.
--
-- Mid-combat values can be SECRET in restricted content, which Lua cannot
-- read; harvesting after combat sidesteps that, and a secret name is skipped
-- rather than written down as garbage.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Collect/Meter.lua")

local U, DB = BT.Util, BT.DB
local M = {}
BT.Meter = M

M.available = (C_DamageMeter ~= nil) and (C_DamageMeter.GetCombatSessionFromType ~= nil)
	and (Enum ~= nil) and (Enum.DamageMeterSessionType ~= nil)

local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

-- The fight that just ended, falling back to the live one: the names are the
-- same either way, and a census does not care about the numbers.
local function session(meterType)
	local s = C_DamageMeter.GetCombatSessionFromType(Enum.DamageMeterSessionType.Current, meterType)
	if s and s.combatSources and #s.combatSources > 0 then
		return s
	end
	local all = C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetAvailableCombatSessions()
	local latest = all and all[#all] -- oldest first
	if latest and latest.sessionID and C_DamageMeter.GetCombatSessionFromID then
		s = C_DamageMeter.GetCombatSessionFromID(latest.sessionID, meterType)
		if s and s.combatSources and #s.combatSources > 0 then
			return s
		end
	end
	return nil
end

-- Damage AND healing: a healer who never hit anything is in one list only.
local function meterTypes()
	local t = {}
	local E = Enum.DamageMeterType
	if E then
		t[#t + 1] = E.DamageDone
		t[#t + 1] = E.HealingDone
	else
		t[#t + 1] = 0
	end
	return t
end

function M.Harvest()
	if not (M.available and BT.Collecting()) then
		return 0
	end
	local wrote = 0
	for _, mt in ipairs(meterTypes()) do
		local s = mt ~= nil and session(mt)
		for _, src in ipairs(s and s.combatSources or {}) do
			local name = src.name
			-- secret first: even "~=" on a secret string is an error
			if not isSecret(name) and type(name) == "string" and name ~= "" then
				-- A PLAYER GUID OR NOTHING (Josh 2026-09-18). Pets and totems
				-- are combat sources too, and letting a missing GUID through
				-- "just in case" filed Paws and Nature as characters. A source
				-- we cannot prove is a player is not one.
				local guid = (not isSecret(src.sourceGUID)) and src.sourceGUID or nil
				-- THE METER NEVER NAMES ANYBODY IN FULL (Josh 2026-09-18). It
				-- reports the given name - "Dylzz", not "Dylzz Drood" - and
				-- neither GetPlayerInfoByGUID nor UnitName will finish it; only
				-- chat and GetUnitName carry both halves. So this source no
				-- longer CREATES characters, it only updates ones the book
				-- already knows by their GUID. Anyone new it sees will arrive
				-- properly named the moment they speak or are seen.
				local known = type(guid) == "string" and BT.db.guids and BT.db.guids[guid]
				local p = known and DB.Get(BT.db, known)
				if p and BT.Collect.Fresh(known) then
					DB.Note(BT.db, p.name, p.realm, {
						src = "meter", guid = guid,
						class = p.class
							or ((type(src.classFilename) == "string" and not isSecret(src.classFilename))
								and src.classFilename or nil),
						zone = GetRealZoneText and GetRealZoneText() or nil,
					})
					wrote = wrote + 1
				end
			end
		end
	end
	return wrote
end
