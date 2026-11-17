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
	after.spellCrit = after.spellCrit + rating
	after.manaPer5 = now.manaPer5 + get("ITEM_MOD_MANA_REGENERATION_SHORT")
	after.healthPer5 = (now.healthPer5 or 0) + get("ITEM_MOD_HEALTH_REGEN_SHORT")
	local hit = get("ITEM_MOD_HIT_RATING_SHORT") * (rates.hitPerRating or 0)
	after.hit = (now.hit or 0) + hit
	after.spellHit = (now.spellHit or 0) + hit
	after.dodge = after.dodge + get("ITEM_MOD_DODGE_RATING_SHORT") * (rates.dodgePerRating or 0)
	after.parry = (now.parry or 0) + get("ITEM_MOD_PARRY_RATING_SHORT") * (rates.parryPerRating or 0)
	after.haste = (now.haste or 0) + get("ITEM_MOD_HASTE_RATING_SHORT") * (rates.hastePerRating or 0)

	-- 5. weapon damage follows attack power
	local perHit = ap / M.AP_PER_DPS * now.weaponSpeed
	after.damageMin = now.damageMin + perHit
	after.damageMax = now.damageMax + perHit

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
