-- YOUR FIGHTS, TO CHECK THE GUESSES AGAINST (Josh 2026-11-16: "This version
-- of the game has no target dummies").
--
-- Roles.lua guesses what the game will not say: an enemy's armor, how often
-- Seal of Command hits, which hits crit, Consecration's share of spell
-- power. A dummy would have settled them. Real fights can, more slowly.
--
-- This client keeps the combat log from addons, but its own damage meter
-- gives each of your spells' totals once a fight is over (C_DamageMeter).
-- So after every fight this writes down those totals, how long the fight
-- was, how many times you cast each spell, and your totals and spell
-- numbers as the fight began. Set beside what Roles.lua would have said for
-- the same fight, the guesses show.
--
-- It only records, into the module's saved table, as `fights` (the last 80). Nothing
-- reads it in game yet.
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
local UP = BT.Upgrades
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Upgrades/Fights.lua")

local Rd = UP.Read
local KEEP = 80

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function plain(v)
	local t = type(v)
	if secret(v) then
		return nil
	end
	if t == "number" or t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local function copy(t, depth)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			if (depth or 0) < 3 then
				out[k] = copy(v, (depth or 0) + 1)
			end
		else
			out[k] = plain(v)
		end
	end
	return out
end

local fight -- the one going on
local seal -- the last seal you cast, by name

-- your spells' totals from the game's meter, for damage or healing
local function totals(kind)
	if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType and Enum.DamageMeterSessionType and kind) then
		return nil
	end
	local guid = UnitGUID("player")
	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Current, kind, guid)
	local spells = ok and type(source) == "table" and source.combatSpells
	if (type(spells) ~= "table" or #spells == 0) and C_DamageMeter.GetAvailableCombatSessions then
		-- or the newest finished fight, as BeebMod's own meter reading does
		local all = C_DamageMeter.GetAvailableCombatSessions()
		local latest = type(all) == "table" and all[#all]
		if latest and latest.sessionID and C_DamageMeter.GetCombatSessionSourceFromID then
			ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, latest.sessionID, kind, guid)
			spells = ok and type(source) == "table" and source.combatSpells
		end
	end
	if type(spells) ~= "table" then
		return nil
	end
	local out = {}
	for _, sp in ipairs(spells) do
		local id, amount = plain(sp.spellID), plain(sp.totalAmount)
		if id and amount then
			out[#out + 1] = { id = id, name = C_Spell and C_Spell.GetSpellName and plain(C_Spell.GetSpellName(id)) or nil,
				total = amount }
		end
	end
	return out
end

local function finish()
	local f = fight
	fight = nil
	if not f then
		return
	end
	f.seconds = GetTime() - f.began
	f.began = nil
	local E = Enum.DamageMeterType
	f.damage = totals(E and E.DamageDone)
	f.healing = totals(E and E.HealingDone)
	-- what hit you, for the tank number's guess at how hard an enemy hits
	-- (a kind of total the meter does not keep gives nothing)
	f.taken = totals(E and E.DamageTaken)
	f.absorbed = totals(E and E.Absorbs)
	if C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds and Enum.DamageMeterSessionType then
		local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, Enum.DamageMeterSessionType.Current)
		f.meterSeconds = ok and plain(seconds) or nil
	end
	-- (a weapon's procs are not added up into a rate of its own: every proc
	-- is priced at one rate, Rd.PROC_PER_MINUTE. They stay in the fight's
	-- casts, to check that one rate against.)
	UP.DB().procs = nil
	-- a fight with nothing in it says nothing
	if not (f.damage and #f.damage > 0) and not (f.healing and #f.healing > 0) then
		return
	end
	local db = UP.DB()
	db.fights = db.fights or {}
	table.insert(db.fights, f)
	while #db.fights > KEEP do
		table.remove(db.fights, 1)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:SetScript("OnEvent", function(_, event, _, _, spellID)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (any class the model has spells for)
		if not UP.On() or not (UP.Covers and UP.Covers()) then
			return
		end
		local ok, s = pcall(Rd.State)
		if not (ok and s) then
			return
		end
		local okKit, kit = pcall(Rd.Kit, s)
		fight = {
			at = date("%Y-%m-%d %H:%M:%S"), began = GetTime(), state = copy(s), kit = okKit and copy(kit) or nil,
			seal = seal, casts = {},
			target = { level = plain(UnitLevel("target")), kind = plain(UnitClassification("target")) },
			grouped = IsInGroup() and true or false,
		}
		-- the weapon's chance on hit, and the name its proc casts under
		if s.proc and s.proc.item then
			local link = GetInventoryItemLink("player", 16)
			local name = link and C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(link)
			fight.proc = { item = s.proc.item, name = plain(name), damage = s.proc.damage }
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- the meter closes the fight a moment after combat drops
		C_Timer.After(1.5, finish)
	elseif spellID and not secret(spellID) then
		local name = C_Spell and C_Spell.GetSpellName and plain(C_Spell.GetSpellName(spellID))
		-- (a seal by its id in the generated list, not by its English name)
		local entry = Rd.Spells()[spellID]
		local SEALS = { crusader = true, command = true, righteousness = true, fury = true }
		if name and entry and SEALS[entry.is] then
			seal = name
			if fight then
				fight.seals = fight.seals or {}
				fight.seals[#fight.seals + 1] = name
			end
		end
		if fight and name then
			fight.casts[name] = (fight.casts[name] or 0) + 1
		end
	end
end)
