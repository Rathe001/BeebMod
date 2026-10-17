-- How far your skills reach (Josh 2026-10-17: "the unit frame range fader
-- doesnt seem to match actual auto shot range of the hunder. We should make
-- sure the faders line up with the proper skill distance for each class").
--
-- THE GAME'S OWN ANSWER, SPELL BY SPELL. The client says whether a spell of
-- yours reaches a unit (C_Spell.IsSpellInRange), and it counts a spell's
-- least reach as well as its most: in September Throw and Charge answered
-- "out of range" inside 8 yards. That is the hunter's dead zone for Auto
-- Shot too. Each class has a list of spells for an enemy and one for a
-- friend, its main attack first:
--
--   R.Main   the first spell that answers: the resource display's icon
--            (Modules/ResourceDisplay), Auto Shot for a hunter, so the icon
--            goes dark too close as well as too far
--   R.Any    whether any of them reaches: what a target, focus or boss frame
--            fades by (Modules/UnitFrames/Unit.lua), so a hunter hitting
--            with Raptor Strike in melee is not faded
--
-- A spell you don't know answers nothing, and the next one is asked. Each
-- is asked by its number, then by its name, which finds whichever rank your
-- spellbook has. An answer the client keeps secret is handed on as it came:
-- nothing of ours may read it, so it cannot be weighed against another.
--
-- The 28-yard check this replaced (CheckInteractDistance) is refused in a
-- fight. These are the action bars' own question, asked of every button in
-- every fight. Should the client ever refuse one in a fight, R.refused
-- remembers it and nothing is asked in a fight again this session.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Core/Reach.lua")

local R = {}
BT.Reach = R

-- by class: `harm` for an enemy, `help` for a friend, the main one first.
-- Rank 1 of each; the name finds a later rank.
R.SPELLS = {
	-- Auto Shot; Raptor Strike and Wing Clip in melee; Mend Pet
	HUNTER = { harm = { 75, 2973, 2974 }, help = { 136 } },
	-- Heroic Strike; Charge, Throw, and Shoot with a bow, gun or crossbow
	WARRIOR = { harm = { 78, 100, 2764, 2480, 7918, 7919 }, help = {} },
	-- Sinister Strike; Throw, and Shoot with a bow, gun or crossbow
	ROGUE = { harm = { 1752, 2764, 2480, 7918, 7919 }, help = {} },
	-- Frostbolt, Fireball; Arcane Intellect
	MAGE = { harm = { 116, 133 }, help = { 1459 } },
	-- Shadow Bolt; Unending Breath
	WARLOCK = { harm = { 686 }, help = { 5697 } },
	-- Smite; Lesser Heal
	PRIEST = { harm = { 585 }, help = { 2050 } },
	-- Wrath; Healing Touch
	DRUID = { harm = { 5176 }, help = { 5185 } },
	-- Lightning Bolt; Healing Wave
	SHAMAN = { harm = { 403 }, help = { 331 } },
	-- Judgement, Hammer of Justice; Holy Light
	PALADIN = { harm = { 20271, 853 }, help = { 635 } },
}
-- A DRUID IN FORM FIGHTS IN MELEE: Claw in cat form, Maul in bear form,
-- before the caster's spells. The form is told by the power it shows.
R.FORMS = { [3] = { 1082 }, [1] = { 6807 } } -- energy, rage

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a call's first answer, or nil when it errs or keeps it secret
local function plain(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or secret(v) then
		return nil
	end
	return v
end

function R.Class()
	local _, class = nil, nil
	if type(UnitClass) == "function" then
		local ok, a, b = pcall(UnitClass, "player")
		if ok and not secret(b) then
			_, class = a, b
		end
	end
	return class
end

-- the spells to ask about `unit`, the main one first, or nil for a class
-- with none for it
local withForm = {}
function R.List(unit)
	local spells = R.SPELLS[R.Class() or ""]
	if not spells then
		return nil
	end
	if plain(UnitCanAssist, "player", unit) then
		return #spells.help > 0 and spells.help or nil
	end
	local form = R.SPELLS.DRUID == spells and R.FORMS[plain(UnitPowerType, "player") or -1]
	if form then
		local list = withForm[form]
		if not list then
			list = {}
			for _, id in ipairs(form) do
				list[#list + 1] = id
			end
			for _, id in ipairs(spells.harm) do
				list[#list + 1] = id
			end
			withForm[form] = list
		end
		return list
	end
	return spells.harm
end

local function fighting()
	return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- one spell's answer: true, false, a secret, or nil for none
function R.Ask(id, unit)
	local C = C_Spell
	local fn = C and C.IsSpellInRange
	if type(fn) ~= "function" then
		return nil
	end
	local ok, r = pcall(fn, id, unit)
	if ok and (secret(r) or type(r) == "boolean") then
		return r
	end
	local name = plain(C.GetSpellName, id)
	if type(name) == "string" then
		ok, r = pcall(fn, name, unit)
		if ok and (secret(r) or type(r) == "boolean") then
			return r
		end
	end
	return nil
end

-- the main attack's answer for `unit`: the first spell that gives one
function R.Main(unit)
	if R.refused and fighting() then
		return nil
	end
	for _, id in ipairs(R.List(unit) or {}) do
		local r = R.Ask(id, unit)
		if secret(r) or r ~= nil then
			return r
		end
	end
	return nil
end

-- whether any of them reaches `unit`: true, false, a secret, or nil when
-- none answers
function R.Any(unit)
	if R.refused and fighting() then
		return nil
	end
	local said = nil
	for _, id in ipairs(R.List(unit) or {}) do
		local r = R.Ask(id, unit)
		if secret(r) or r == true then
			return r
		elseif r == false then
			said = false
		end
	end
	return said
end

-- REFUSED IN A FIGHT, ONCE IS ENOUGH (see the top): the client names the
-- call it blocked, and a range question it blocked is not asked in a fight
-- again (Core/Blocked.lua writes the same event down for What loaded)
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:SetScript("OnEvent", function(_, _, addon, func)
	if addon == BT.NAME and tostring(func):find("SpellInRange", 1, true) then
		R.refused = true
	end
end)
