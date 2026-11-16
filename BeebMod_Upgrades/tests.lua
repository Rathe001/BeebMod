-- Run from the BeebMod folder: lua BeebMod_Upgrades/tests.lua
--
-- The first case is not made up. It is the probe's record of Josh's level 28
-- paladin on 2026-11-16, either side of taking off Graveweave Bindings. The
-- swap math has to land on what the game itself reported.
local UP = {}
assert(loadfile("BeebMod_Upgrades/Math.lua"))("BeebMod_Upgrades", UP)
local M = UP.Math

local failed = 0
local function near(what, got, want)
	if math.abs(got - want) > 0.011 then
		failed = failed + 1
		print(("FAIL %s: got %s, want %s"):format(what, tostring(got), tostring(want)))
	else
		print(("ok   %s = %s"):format(what, tostring(want)))
	end
end

-- as the game reported it with the bindings on
local worn = {
	strength = 86, agility = 40, stamina = 107, intellect = 77, spirit = 63,
	attackPower = 236,
	spellDamage = { [2] = 50, [3] = 50, [4] = 50, [5] = 50, [6] = 78, [7] = 50 },
	healing = 136, armor = 1654, crit = 8.8, spellCrit = 12.5641,
	health = 1519, mana = 1523, manaPer5 = 2,
	damageMin = 75.2, damageMax = 99.2,
	weaponSpeed = 2.8, -- 2.435 shown, with 15% haste
}
-- as GetAttackPowerForStat and its neighbours answered
local rates = {
	attackPowerPer = { strength = 2 },
	critPerAgility = 0.1,
	spellCritPerIntellect = 0.0333,
	healthPerStamina = 10,
	manaPerIntellect = 15,
}
local bindings = {
	ITEM_MOD_STRENGTH_SHORT = 6, ITEM_MOD_SPELL_POWER_SHORT = 5,
	ITEM_MOD_MANA_REGENERATION_SHORT = 2, RESISTANCE0_NAME = 21,
}

print("taking the bindings off, against the game's own numbers")
local off = M.Swap(worn, rates, bindings, nil)
near("strength", off.strength, 80)
near("attack power", off.attackPower, 224)
near("Holy spell damage", off.spellDamage[2], 45)
near("Shadow spell damage", off.spellDamage[6], 73)
near("healing", off.healing, 131)
near("armor", off.armor, 1633)
near("weapon damage, low", off.damageMin, 72.8)
near("weapon damage, high", off.damageMax, 96.8)
near("mana per 5 sec from gear", off.manaPer5, 0)
near("stamina untouched", off.stamina, 107)
near("health untouched", off.health, 1519)

print("putting them back on gives the start again")
local on = M.Swap(off, rates, nil, bindings)
near("strength", on.strength, 86)
near("attack power", on.attackPower, 236)
near("healing", on.healing, 136)
near("armor", on.armor, 1654)
near("weapon damage, low", on.damageMin, 75.2)

print("a swap is the worn piece out and the new piece in, not the new piece on top")
local other = { ITEM_MOD_STRENGTH_SHORT = 2, ITEM_MOD_AGILITY_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 4, RESISTANCE0_NAME = 30 }
local swapped = M.Swap(worn, rates, bindings, other)
near("strength 86 - 6 + 2", swapped.strength, 82)
near("attack power 236 - 12 + 4", swapped.attackPower, 228)
near("armor 1654 - 21 + 30 + 3 agility x 2", swapped.armor, 1669)
near("crit 8.8 + 3 agility x 0.1", swapped.crit, 9.1)
near("health 1519 + 4 stamina x 10", swapped.health, 1559)
near("healing 136 - 5", swapped.healing, 131)

print("a +10% strength multiplier works on the piece's strength before attack power")
local kings = { attackPowerPer = { strength = 2 }, multiplier = { strength = 1.1 } }
local buffed = M.Swap(worn, kings, nil, { ITEM_MOD_STRENGTH_SHORT = 10 })
near("strength 86 + 10 x 1.1", buffed.strength, 97)
near("attack power 236 + 11 x 2", buffed.attackPower, 258)

-- ROLES ----------------------------------------------------------------------
assert(loadfile("BeebMod_Upgrades/Roles.lua"))("BeebMod_Upgrades", UP)
local R = UP.Roles
local function check(what, yes)
	if yes then
		print("ok   " .. what)
	else
		failed = failed + 1
		print("FAIL " .. what)
	end
end

-- the rest of the same record
worn.level, worn.haste, worn.dodge, worn.parry, worn.hit, worn.spellHit = 28, 15, 4.38, 5.68, 1, 1
worn.manaPer5 = 12
rates.dodgePerAgility = 0.1
-- his spells as their descriptions read with the bindings on
local kit = {
	at = { spell = 50, healing = 136 },
	holyStrike = { percent = 0.432, holy = 19.5, cost = 13, cooldown = 10 },
	judgement = { cost = 36, cooldown = 10 },
	seals = {
		command = { percent = 0.7, cost = 60, judge = 81.5 },
		righteousness = { low = 11, high = 30, cost = 83, judge = 87.5 },
	},
	heals = {
		{ name = "Holy Light", amount = 396.5, share = 0.714, cast = 2.5, cost = 190 },
		{ name = "Flash of Light", amount = 126.5, share = 0.429, cast = 1.5, cost = 50 },
	},
}

print("a new weapon: the worn one's damage out, the new one's in, at the new speed")
-- worn 28-52 at 2.8 (75.2 less 236 / 14 x 2.8 = 47.2); new 20-30 at 1.6
local fast = M.Swap(worn, rates, nil, nil, { worn = { min = 28, max = 52, speed = 2.8 }, new = { min = 20, max = 30, speed = 1.6 } })
near("speed", fast.weaponSpeed, 1.6)
near("low hit 20 + 236 / 14 x 1.6", fast.damageMin, 46.97)
near("high hit 30 + 236 / 14 x 1.6", fast.damageMax, 56.97)

print("the seal follows the weapon")
local _, slowSeal = R.Damage(worn, kit)
check("a 2.8 speed weapon comes out with Seal of Command", slowSeal == "command")
local _, fastSeal = R.Damage(fast, kit)
check("a 1.6 speed weapon comes out with Seal of Righteousness", fastSeal == "righteousness")

print("each stat moves the roles it feeds, and no others")
local function with(stats)
	local s = M.Swap(worn, rates, nil, stats)
	return R.Change(R.Damage(worn, kit), R.Damage(s, kit)), R.Change(R.Healing(worn, kit), R.Healing(s, kit)),
		R.Change(R.Survival(worn), R.Survival(s))
end
local d, h, t = with({ ITEM_MOD_STRENGTH_SHORT = 10 })
check("strength: DPS up, healing and survival as they were", d > 0 and h == 0 and t == 0)
d, h, t = with({ ITEM_MOD_SPELL_POWER_SHORT = 10 })
check("spell power: DPS and healing up, survival as it was", d > 0 and h > 0 and t == 0)
d, h, t = with({ ITEM_MOD_INTELLECT_SHORT = 10 })
check("intellect: DPS up (spell crit and mana), healing up (spell crit)", d > 0 and h > 0 and t == 0)
d, h, t = with({ ITEM_MOD_AGILITY_SHORT = 10 })
check("agility: DPS up (crit), survival up (armor and dodge)", d > 0 and h == 0 and t > 0)
d, h, t = with({ ITEM_MOD_STAMINA_SHORT = 10 })
check("stamina: survival only", d == 0 and h == 0 and t > 0)
d, h, t = with({ ITEM_MOD_SPIRIT_SHORT = 10 })
check("spirit: nothing yet (sustain is not built)", d == 0 and h == 0 and t == 0)

print("Heart of Agamaggan for Battleforge Shield of the Physician, worked by hand")
local shield = { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4,
	ITEM_MOD_STAMINA_SHORT = 4, RESISTANCE0_NAME = 561 }
local heart = { ITEM_MOD_STAMINA_SHORT = 7, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 5, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 15,
	RESISTANCE0_NAME = 757 }
local s = M.Swap(worn, rates, shield, heart)
near("healing 136 - 4 + 15", s.healing, 147)
near("armor 1654 - 561 + 757", s.armor, 1850)
near("health 1519 + 3 stamina x 10", s.health, 1549)
-- Holy Light: (396.5 + 0.714 x 11) x (1 + 0.5 x 12.4975%) over (396.5) x (1 + 0.5 x 12.5641%)
near("healer, percent", R.Change(R.Healing(worn, kit), R.Healing(s, kit)), 1.95)
-- armor takes 1654 / 4434 = 37.30%, then 1850 / 4630 = 39.96%; health 1519 to 1549
near("tank, percent", R.Change(R.Survival(worn), R.Survival(s)), 6.49)

print("ratings, at the client table's rates: 14 crit rating and 10 hit rating for 1%")
local rated = { critPerRating = 1 / 14, hitPerRating = 1 / 10, dodgePerRating = 1 / 12, parryPerRating = 1 / 15, hastePerRating = 1 / 10 }
local boots = M.Swap(worn, rated, nil, { ITEM_MOD_CRIT_RATING_SHORT = 7, ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_DODGE_RATING_SHORT = 12 })
near("crit 8.8 + 7 rating (the game said 0.5)", boots.crit, 9.3)
near("spell crit 12.5641 + 0.5", boots.spellCrit, 13.0641)
near("hit 1 + 1", boots.hit, 2)
near("dodge 4.38 + 1", boots.dodge, 5.38)

print("second profiles: AoE, sustain, threat")
worn.spiritRegen = 14.125
rates.regenPerSpirit = 0.1
kit.consecration = { total = 65, cost = 124, cooldown = 8 }
kit.righteousFury = { all = 1.33, holy = 1.9 }
kit.seals.fury = { hit = 14, cost = 55, judge = 71.5 }
local function second(stats)
	local s2 = M.Swap(worn, rates, nil, stats)
	local four = { enemies = 4 }
	return {
		dps = R.Change(R.Damage(worn, kit), R.Damage(s2, kit)),
		aoe = R.Change(R.Damage(worn, kit, four), R.Damage(s2, kit, four)),
		healer = R.Change(R.Healing(worn, kit), R.Healing(s2, kit)),
		sustain = R.Change(R.Sustain(worn, kit), R.Sustain(s2, kit)),
		tank = R.Change(R.Survival(worn), R.Survival(s2)),
		threat = R.Change(R.Threat(worn, kit), R.Threat(s2, kit)),
	}
end
local c = second({ ITEM_MOD_SPIRIT_SHORT = 10 })
check("spirit: sustain up, healing per second as it was", c.sustain > 0 and c.healer == 0)
-- 10 spirit x 0.1 a second x a fifth of 180 seconds = 36 mana on 2,463.5
near("10 spirit, sustain percent", c.sustain, 1.46)
c = second({ ITEM_MOD_INTELLECT_SHORT = 10 })
check("intellect: sustain up more than healing per second (the pool)", c.sustain > c.healer and c.healer > 0)
check("intellect: threat up (spell crit on Holy damage)", c.threat > 0)
c = second({ ITEM_MOD_MANA_REGENERATION_SHORT = 5 })
check("mana per 5: sustain up, healing per second as it was", c.sustain > 0 and c.healer == 0)
c = second({ ITEM_MOD_SPELL_POWER_SHORT = 10 })
check("spell power: worth more on four enemies than on one", c.aoe > c.dps and c.dps > 0)
check("spell power: threat up, survival as it was", c.threat > 0 and c.tank == 0)
c = second({ ITEM_MOD_STRENGTH_SHORT = 10 })
check("strength: worth less on four enemies than on one", c.aoe < c.dps and c.aoe > 0)
c = second({ ITEM_MOD_STAMINA_SHORT = 10 })
check("stamina: survival up, threat as it was", c.tank > 0 and c.threat == 0)

print("with a shield: block, and Seal of Fury's absorb")
worn.shield, worn.block, worn.blockValue = true, 4.68, 14
-- an enemy hits for 3 x 28 = 84, and 62.70% lands past 1,654 armor: 52.67.
-- Block covers 14 / 52.67 of a hit, 4.68% of the time: 1.244% of the damage.
worn.shield = false
local without = R.Survival(worn)
worn.shield = true
near("block against no shield, percent", R.Change(without, R.Survival(worn)), 1.26)
-- Seal of Fury: 0.96 hits x 1.15 / 2.8 a second x 14 Holy x half = 2.760
-- absorbed a second, of 52.67 x (1 - 15.06%) / 2 = 22.37 taken: 12.34%,
-- and 1 / (1 - 12.34%) is 14.08% more life
near("Seal of Fury's absorb on top, percent", R.Change(R.Survival(worn), R.Survival(worn, kit)), 14.08)
local function tank(stats)
	local s3 = M.Swap(worn, rates, nil, stats)
	return R.Change(R.Survival(worn, kit), R.Survival(s3, kit))
end
check("spell power is survival with a shield and Seal of Fury", tank({ ITEM_MOD_SPELL_POWER_SHORT = 10 }) > 0)
check("a shield's block is survival", tank({ UPGRADES_BLOCK = 6 }) > 0)
check("20 strength is 1 block value", M.Swap(worn, rates, nil, { ITEM_MOD_STRENGTH_SHORT = 20 }).blockValue == 15)
local off = M.Swap(worn, rates, nil, nil)
off.shield = false
check("taking the shield off costs both", R.Survival(off, kit) < R.Survival(worn, kit))
worn.shield = nil

print("health per 5 seconds from gear")
worn.healthPer5 = 16
-- taken: 52.67 a hit x (1 - 15.06%) / 2 seconds = 22.37 a second. 4 health
-- per 5 is 0.8 a second; 16 is 3.2. Taking 4 off: (1 - 3.2 / 22.37) over
-- (1 - 2.4 / 22.37), less 1 = -4.01%
local less = M.Swap(worn, rates, { ITEM_MOD_HEALTH_REGEN_SHORT = 4 }, nil)
near("health per 5 after taking 4 off", less.healthPer5, 12)
near("losing 4 health per 5, tank percent", R.Change(R.Survival(worn), R.Survival(less)), -4.01)
worn.healthPer5 = nil

print("a weapon's chance on hit")
local plainHit = R.Damage(worn, kit)
worn.proc = { damage = 98, magic = true, perMinute = 3 }
-- 98 damage 3 times a minute is 4.9 a second, and armor takes none of Fire
near("Searing Blade's fireball, DPS it adds", R.Damage(worn, kit) - plainHit, 4.9)
worn.proc = { damage = 98, magic = false, perMinute = 3 }
-- one that is not magic loses the enemy's armor share: 1,400 / 4,180
near("the same, not magic", R.Damage(worn, kit) - plainHit, 4.9 * (1 - 1400 / 4180))
local other = M.Swap(worn, rates, nil, nil, { worn = { min = 28, max = 52, speed = 2.8 }, new = { min = 28, max = 52, speed = 2.8 } })
check("a new weapon with no chance on hit takes the worn one's away", other.proc == nil)
worn.proc = nil

print("Judgement of the Crusader on the enemy")
local before6 = R.Damage(worn, kit)
kit.crusader = { holy = 58, cost = 60 }
local with6, _, used6 = R.Damage(worn, kit)
check("the rotation with the debuff is the better one, and is used", used6 == true and with6 > before6)
kit.crusader = { holy = 0, cost = 60 }
check("a debuff worth nothing is not opened with", select(3, R.Damage(worn, kit)) == false)
kit.crusader = nil

print("")
if failed > 0 then
	print(failed .. " FAILED")
	os.exit(1)
end
print("ALL UPGRADES TESTS PASSED")
