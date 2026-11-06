-- Which classes can do what a note asks (Josh 2026-11-06, the notes canvas):
-- a line that wants a kick or a curse removed names the classes that have
-- one, under it. Forever's classes, with the spells they have for it:
--
--   kick     Warrior Pummel, Rogue Kick, Mage Counterspell, Shaman Earth Shock
--   purge    Shaman Purge, Priest Dispel Magic, on the enemy
--   curse    Mage Remove Lesser Curse, Druid Remove Curse
--   magic    Priest Dispel Magic, Paladin Cleanse
--   poison   Paladin Purify, Druid Cure Poison, Shaman Cure Poison
--   disease  Priest Cure Disease, Paladin Purify, Shaman Cure Disease
--   fear     Shaman Tremor Totem
--   stun     Warrior, Rogue, Paladin Hammer of Justice, Druid Bash
--   cc       Mage, Rogue, Warlock, Hunter, Priest, Druid
--
-- A pet's spell (a Felhunter's Spell Lock) is left out: a warlock without
-- that pet out can't do it.
local _, BT = ...

local E = BT.Encounter or {}
BT.Encounter = E

-- the skills a line can ask for: the icon at the start of the line (a
-- spell that does it), and what the line under it calls it
local ICONS = "Interface\\Icons\\"
E.SKILLS = {
	kick = { label = "Kick", icon = ICONS .. "Ability_Kick",
		classes = { "WARRIOR", "ROGUE", "MAGE", "SHAMAN" } },
	curse = { label = "Remove curse", icon = ICONS .. "Spell_Holy_RemoveCurse",
		classes = { "MAGE", "DRUID" } },
	magic = { label = "Dispel magic", icon = ICONS .. "Spell_Holy_DispelMagic",
		classes = { "PRIEST", "PALADIN" } },
	poison = { label = "Cure poison", icon = ICONS .. "Spell_Nature_NullifyPoison",
		classes = { "PALADIN", "DRUID", "SHAMAN" } },
	disease = { label = "Cure disease", icon = ICONS .. "Spell_Holy_NullifyDisease",
		classes = { "PRIEST", "PALADIN", "SHAMAN" } },
	fear = { label = "Tremor Totem", icon = ICONS .. "Spell_Nature_TremorTotem",
		classes = { "SHAMAN" } },
	-- a buff taken off the boss (Hamhock's Bloodlust, Atrexis's Unholy Frenzy)
	purge = { label = "Purge", icon = ICONS .. "Spell_Nature_Purge",
		classes = { "SHAMAN", "PRIEST" } },
	stun = { label = "Stun", icon = ICONS .. "Spell_Holy_SealOfMight",
		classes = { "WARRIOR", "ROGUE", "PALADIN", "DRUID" } },
	cc = { label = "Crowd control", icon = ICONS .. "Spell_Nature_Polymorph",
		classes = { "MAGE", "ROGUE", "WARLOCK", "HUNTER", "PRIEST", "DRUID" } },
}

-- the roles: the game's word for each (its role icons are drawn by
-- BT.Encounter.RoleIcon), and the words on their buttons
E.ROLES = {
	tank = { game = "TANK", label = "Tank" },
	healer = { game = "HEALER", label = "Healer" },
	dps = { game = "DAMAGER", label = "DPS" },
}
E.ROLE_ORDER = { "tank", "healer", "dps" }

local CLASS_WORDS = {
	WARRIOR = "Warrior", ROGUE = "Rogue", MAGE = "Mage", SHAMAN = "Shaman", DRUID = "Druid",
	PRIEST = "Priest", PALADIN = "Paladin", WARLOCK = "Warlock", HUNTER = "Hunter",
}

-- a class as the game writes it, in your language where the game says
local function classWord(token)
	local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
	local word = type(names) == "table" and names[token]
	return type(word) == "string" and word ~= "" and word or CLASS_WORDS[token] or token
end

-- "Warrior, Rogue, Mage, Shaman": who can do what a skill line asks
function E.Who(need)
	local s = E.SKILLS[need]
	if not s then
		return nil
	end
	local words = {}
	for _, c in ipairs(s.classes) do
		words[#words + 1] = classWord(c)
	end
	return table.concat(words, ", ")
end

-- whether your class is one of them
function E.Can(need, class)
	local s = E.SKILLS[need]
	for _, c in ipairs(s and s.classes or {}) do
		if c == class then
			return true
		end
	end
	return false
end
