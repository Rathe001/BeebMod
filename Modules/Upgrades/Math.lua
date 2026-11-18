-- THE SWAP: YOUR TOTALS WITH ONE PIECE CHANGED (Josh 2026-11-16).
--
-- Josh: "We'd need to remove the stats from the currently worn piece of gear,
-- and add the stats of the new gear... it is imperative that we get the math
-- order and formula working properly."
--
-- No game calls in this file, so the tests can run it. It is handed your
-- totals as the game reports them (the worn piece is in them), the worn
-- piece's stats and the new piece's stats, both as C_Item.GetItemStats gives
-- them, and it answers with the totals you would have.
--
-- THE ORDER
--   1. new piece minus worn piece, stat by stat
--   2. a primary stat's difference is multiplied by that stat's multiplier
--      (a talent or buff giving "+10% strength" works on gear too)
--   3. what a primary stat makes is worked out from its difference: attack
--      power from strength, crit and armor from agility, health from stamina,
--      mana and spell crit from intellect. Never added a second time.
--   4. what the piece gives outright is added: attack power, spell power,
--      armor, mana per 5 seconds
--   5. weapon damage follows attack power: 14 attack power is 1 damage per
--      second, times the weapon's speed before haste
--   6. a new weapon: the worn weapon's own damage comes out and the new
--      one's goes in, with attack power's share worked out again at the new
--      speed
--
-- CHECKED AGAINST THE GAME (probe record, 2026-11-16, level 28 paladin, build
-- 70938): taking off Graveweave Bindings (+6 Strength, +5 spell power, 2 mana
-- per 5 sec, 21 Armor) moved strength 86 to 80, attack power 236 to 224, Holy
-- spell damage 50 to 45, healing 136 to 131, armor 1654 to 1633 and weapon
-- damage 75.2-99.2 to 72.8-96.8. tests/upgrades.lua holds that swap.
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
local UP = BT.Upgrades

local M = {}
UP.Math = M

M.AP_PER_DPS = 14
-- DEFENSE (Josh 2026-11-17: "Defense is a main tanking stat... I think we
-- should consider it. Each point of Defense provides 0.04% reduction in
-- incoming critical hit chance, as well as small increases to dodge, parry,
-- and block"). The character sheet has the same number, and says one more
-- thing a point does: "Decreases chance to be hit and critically hit"
-- (PaperDollFrameStats.lua, STAT_PER_DEFENSE = 0.04). So a point is 0.04% of
-- dodge, of parry and of block, 0.04% less chance to be hit and 0.04% less
-- chance to be critically hit. An item has it as a stat of its own, in
-- rating, and the game's table makes 1 rating 1 Defense at every level
-- (gametables/combatratings.txt). A set bonus or a "Use:" that gives it
-- comes from the tables as UPGRADES_DEFENSE.
M.PER_DEFENSE = 0.04
M.RANGED_POWER_PER = { agility = 2 }
-- THE REST OF WHAT AN ITEM CAN HAVE (Josh 2026-11-17, of the stats that
-- counted for nothing: "We should consider resists in the tanking stats so
-- they aren't completely ignored. Attack power vs type should be divided by
-- however many types there are. So +50 attack power vs undead would only
-- count as +10 if there are 5 types. Expertise should have a value for dps
-- and tank threat").
--   resistances: kept by school for the tank's sum (Roles.lua). The schools
--     as UnitResistance numbers them: fire 2, nature 3, frost 4, shadow 5,
--     arcane 6. An item has one as RESISTANCE<n>_NAME or under the school's
--     name; a stat with RESISTANCE and ALL in its name is all five.
--   attack power against a kind of enemy: the amount over M.ENEMY_KINDS, as
--     plain attack power. The game has eight kinds of enemy you fight:
--     beast, demon, dragonkin, elemental, giant, humanoid, mechanical and
--     undead.
--   expertise: each point takes 0.25% off an enemy's chance to dodge or
--     parry you (classic's), kept in percent for Roles.lua.
M.RESIST = { RESISTANCE2_NAME = 2, RESISTANCE3_NAME = 3, RESISTANCE4_NAME = 4, RESISTANCE5_NAME = 5, RESISTANCE6_NAME = 6,
	ITEM_MOD_FIRE_RESISTANCE_SHORT = 2, ITEM_MOD_NATURE_RESISTANCE_SHORT = 3, ITEM_MOD_FROST_RESISTANCE_SHORT = 4,
	ITEM_MOD_SHADOW_RESISTANCE_SHORT = 5, ITEM_MOD_ARCANE_RESISTANCE_SHORT = 6 }
M.ENEMY_KINDS = 8
M.PER_EXPERTISE = 0.25
M.ARMOR_PER_AGILITY = 2

-- spell schools as GetSpellBonusDamage numbers them
M.SCHOOLS = { HOLY = 2, FIRE = 3, NATURE = 4, FROST = 5, SHADOW = 6, ARCANE = 7 }

local PRIMARY = {
	ITEM_MOD_STRENGTH_SHORT = "strength",
	ITEM_MOD_AGILITY_SHORT = "agility",
	ITEM_MOD_STAMINA_SHORT = "stamina",
	ITEM_MOD_INTELLECT_SHORT = "intellect",
	ITEM_MOD_SPIRIT_SHORT = "spirit",
}

-- new minus worn, for every stat either piece has
function M.Difference(worn, new)
	local d = {}
	for k, v in pairs(new or {}) do
		d[k] = v
	end
	for k, v in pairs(worn or {}) do
		d[k] = (d[k] or 0) - v
	end
	return d
end

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end

-- `now`: strength, agility, stamina, intellect, spirit, attackPower,
--   spellDamage[2..7], healing, armor, crit, spellCrit (both in percent),
--   health, mana, manaPer5, damageMin, damageMax, weaponSpeed (before haste)
-- `rates`: multiplier[stat], attackPowerPer[stat], critPerAgility,
--   spellCritPerIntellect, critPerRating (all crit rates in percent per
--   point), healthPerStamina, manaPerIntellect
-- `weapons`, when the piece is a weapon: { worn = { min, max, speed },
--   new = { min, max, speed } }, each as its tooltip says
function M.Swap(now, rates, worn, new, weapons)
	local d = M.Difference(worn, new)
	local after = copy(now)
	local function get(key)
		return d[key] or 0
	end

	-- 2. primaries, with their multipliers
	local gained = {}
	for key, stat in pairs(PRIMARY) do
		local mult = rates.multiplier and rates.multiplier[stat] or 1
		gained[stat] = get(key) * mult
		after[stat] = now[stat] + gained[stat]
	end

	-- 3. what the primaries make
	local ap = 0
	for stat, per in pairs(rates.attackPowerPer or {}) do
		ap = ap + (gained[stat] or 0) * per
	end
	after.armor = now.armor + gained.agility * M.ARMOR_PER_AGILITY
	after.crit = now.crit + gained.agility * (rates.critPerAgility or 0)
	after.spellCrit = now.spellCrit + gained.intellect * (rates.spellCritPerIntellect or 0)
	after.dodge = (now.dodge or 0) + gained.agility * (rates.dodgePerAgility or 0)
	after.spiritRegen = (now.spiritRegen or 0) + gained.spirit * (rates.regenPerSpirit or 0)
	-- block value: 1 for every 20 strength (the character sheet's
	-- BLOCK_VALUE_PER_STRENGTH), and what a shield has of its own, which
	-- Read.lua takes from its tooltip as UPGRADES_BLOCK
	after.blockValue = (now.blockValue or 0) + gained.strength / 20 + get("UPGRADES_BLOCK") + get("ITEM_MOD_BLOCK_VALUE_SHORT")
	after.block = (now.block or 0) + get("ITEM_MOD_BLOCK_RATING_SHORT") * (rates.blockPerRating or 0)
	after.health = now.health + gained.stamina * (rates.healthPerStamina or 0) + get("ITEM_MOD_HEALTH_SHORT")
	after.mana = now.mana + gained.intellect * (rates.manaPerIntellect or 0) + get("ITEM_MOD_MANA_SHORT")

	-- 4. what the piece gives outright
	ap = ap + get("ITEM_MOD_ATTACK_POWER_SHORT")
	-- (and attack power against one kind of enemy, as its share of plain)
	after.resist = {}
	for school = 2, 6 do
		after.resist[school] = now.resist and now.resist[school] or 0
	end
	for key, v in pairs(d) do
		if type(key) == "string" then
			if (key:find("ATTACK_POWER_VS", 1, true) or key:find("ATTACK_POWER_VERSUS", 1, true)) and not key:find("RANGED", 1, true) then
				ap = ap + v / M.ENEMY_KINDS
			elseif M.RESIST[key] then
				after.resist[M.RESIST[key]] = after.resist[M.RESIST[key]] + v
			elseif key:find("RESISTANCE", 1, true) and key:find("ALL", 1, true) then
				for school = 2, 6 do
					after.resist[school] = after.resist[school] + v
				end
			end
		end
	end
	after.expertise = (now.expertise or 0)
		+ get("ITEM_MOD_EXPERTISE_RATING_SHORT") * (rates.expertisePerRating or 0.1) * M.PER_EXPERTISE
	after.attackPower = now.attackPower + ap
	after.armor = after.armor + get("RESISTANCE0_NAME")
	local both = get("ITEM_MOD_SPELL_POWER_SHORT")
	local damage = both + get("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT")
	for name, school in pairs(M.SCHOOLS) do
		after.spellDamage[school] = now.spellDamage[school] + damage
			+ get("ITEM_MOD_" .. name .. "_DAMAGE_DONE_SHORT")
	end
	after.healing = now.healing + both + get("ITEM_MOD_SPELL_HEALING_DONE_SHORT")
	local rating = get("ITEM_MOD_CRIT_RATING_SHORT") * (rates.critPerRating or 0)
	after.crit = after.crit + rating
	-- (and the kind that is for spells only)
	after.spellCrit = after.spellCrit + rating + get("ITEM_MOD_CRIT_SPELL_RATING_SHORT") * (rates.critPerRating or 0)
	after.manaPer5 = now.manaPer5 + get("ITEM_MOD_MANA_REGENERATION_SHORT")
	after.healthPer5 = (now.healthPer5 or 0) + get("ITEM_MOD_HEALTH_REGEN_SHORT")
	local hit = get("ITEM_MOD_HIT_RATING_SHORT") * (rates.hitPerRating or 0)
	after.hit = (now.hit or 0) + hit
	after.spellHit = (now.spellHit or 0) + hit + get("ITEM_MOD_HIT_SPELL_RATING_SHORT") * (rates.hitPerRating or 0)
	after.dodge = after.dodge + get("ITEM_MOD_DODGE_RATING_SHORT") * (rates.dodgePerRating or 0)
	after.parry = (now.parry or 0) + get("ITEM_MOD_PARRY_RATING_SHORT") * (rates.parryPerRating or 0)
	after.haste = (now.haste or 0) + get("ITEM_MOD_HASTE_RATING_SHORT") * (rates.hastePerRating or 0)
	-- Defense: what it adds to dodge, parry and block here; what it takes
	-- off an enemy's chance to hit and to crit is the tank's sum (Roles.lua)
	local defense = get("ITEM_MOD_DEFENSE_SKILL_RATING_SHORT") * (rates.defensePerRating or 1) + get("UPGRADES_DEFENSE")
	after.defense = (now.defense or 0) + defense
	after.dodge = after.dodge + defense * M.PER_DEFENSE
	after.parry = after.parry + defense * M.PER_DEFENSE
	after.block = after.block + defense * M.PER_DEFENSE

	-- (attack power a piece gives in a druid's forms only: Roles.lua, R.FormState)
	after.feralGain = (now.feralGain or 0) + get("ITEM_MOD_FERAL_ATTACK_POWER_SHORT")

	-- 5. weapon damage follows attack power
	local perHit = ap / M.AP_PER_DPS * now.weaponSpeed
	after.damageMin = now.damageMin + perHit
	after.damageMax = now.damageMax + perHit

	-- 5b. A RANGED WEAPON'S DAMAGE FOLLOWS RANGED ATTACK POWER (the hunter).
	-- The game has no call for what a stat gives of it, so the original
	-- game's rule is used: 2 for a point of agility (M.RANGED_POWER_PER).
	-- Attack power on a piece counts for both kinds. Ranged crit and hit
	-- move as melee's do. `rangedBase`: the weapon's own speed, which is
	-- what attack power is counted by; `rangedSpeed` is with a quiver's
	-- haste in it.
	local rap = get("ITEM_MOD_ATTACK_POWER_SHORT") + get("ITEM_MOD_RANGED_ATTACK_POWER_SHORT")
	for stat, per in pairs(rates.rangedPowerPer or M.RANGED_POWER_PER) do
		rap = rap + (gained[stat] or 0) * per
	end
	if now.rangedSpeed then
		local base = now.rangedBase or now.rangedSpeed
		after.rangedPower = (now.rangedPower or 0) + rap
		after.rangedMin = now.rangedMin + rap / M.AP_PER_DPS * base
		after.rangedMax = now.rangedMax + rap / M.AP_PER_DPS * base
		after.rangedCrit = (now.rangedCrit or now.crit) + (after.crit - now.crit)
		after.rangedHit = (now.rangedHit or now.hit or 0) + (after.hit - (now.hit or 0))
		-- a new ranged weapon: what each second of the worn one's speed had
		-- beyond the weapon's own (attack power and ammunition) is kept
		local was, will = weapons and weapons.worn, weapons and weapons.new
		if will and weapons.ranged then
			local restMin = was and (now.rangedMin - was.min) / was.speed or (now.rangedPower or 0) / M.AP_PER_DPS
			local restMax = was and (now.rangedMax - was.max) / was.speed or (now.rangedPower or 0) / M.AP_PER_DPS
			after.rangedMin = will.min + (restMin + rap / M.AP_PER_DPS) * will.speed
			after.rangedMax = will.max + (restMax + rap / M.AP_PER_DPS) * will.speed
			after.rangedSpeed = now.rangedSpeed * will.speed / base
			after.rangedBase = will.speed
		end
	end
	if weapons and weapons.ranged then
		return after, d
	end

	-- 6. a new weapon. What is left of today's damage once the worn weapon
	-- and attack power's share are taken out (nothing, as a rule) is kept.
	local was, will = weapons and weapons.worn, weapons and weapons.new
	if will then
		local share = now.attackPower / M.AP_PER_DPS * now.weaponSpeed
		local restMin = was and (now.damageMin - was.min - share) or 0
		local restMax = was and (now.damageMax - was.max - share) or 0
		local newShare = after.attackPower / M.AP_PER_DPS * will.speed
		after.weaponSpeed = will.speed
		-- and its chance on hit, if it has one, in place of the worn one's
		after.proc = will.proc
		after.damageMin = will.min + newShare + restMin
		after.damageMax = will.max + newShare + restMax
	end

	return after, d
end
