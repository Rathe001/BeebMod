-- Run from the BeebMod folder: lua tests/upgrades.lua
-- (tests/run.lua runs it too, as its last part.)
--
-- The first case is not made up. It is the probe's record of Josh's level 28
-- paladin on 2026-11-16, either side of taking off Graveweave Bindings. The
-- swap math has to land on what the game itself reported.
local BT = {}
assert(loadfile("Modules/Upgrades/Math.lua"))("BeebMod", BT)
local UP = BT.Upgrades
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
assert(loadfile("Modules/Upgrades/Roles.lua"))("BeebMod", BT)
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
-- (with a twentieth of what an enemy does taken as magic: R.MAGIC_SHARE)
near("tank, percent", R.Change(R.Survival(worn), R.Survival(s)), 6.08)

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
do
	local all = R.Combine({ tank = 7.5, threat = 34.4, healer = 2, sustain = 5, dps = 10, aoe = 2 })
	near("one number: tank is 70% survival, 30% threat", all.tank, 15.57)
	near("one number: dps is 75% one enemy, 25% four", all.dps, 8)
	near("one number: healer is the fight's healing", all.healer, 5)
	check("one number: with no heal that costs mana, healing per second", R.Combine({ healer = 2 }).healer == 2)
end
do
	-- A cheap heal (100 for 50 mana in 1.5 sec) and a big one (400 for 300
	-- in 2.5). 144 seconds of casting, 6,000 mana. The cheap one alone runs
	-- out of time: 96 casts, 9,600. The big one alone runs out of mana: 20
	-- casts, 8,000. Both limits used up: 1.5x + 2.5y = 144, 50x + 300y =
	-- 6,000, so y = 5.538, x = 86.769, and 8,676.9 + 2,215.4 = 10,892.3.
	local two = { at = { healing = 0 }, heals = {
		{ name = "cheap", amount = 100, share = 0, cast = 1.5, cost = 50 },
		{ name = "big", amount = 400, share = 0, cast = 2.5, cost = 300 },
	} }
	local who = { healing = 0, spellCrit = 0, mana = 6000, manaPer5 = 0, spiritRegen = 0 }
	near("one fight: the mix of two heals that uses the time and the mana", R.FightHealing(who, two), 10892.31)
	who.mana = 100000
	near("one fight: with mana to spare, the big heal for all the time", R.FightHealing(who, two), 144 / 2.5 * 400)
	who.mana = 1000
	near("one fight: with little mana, all of it on the cheap heal", R.FightHealing(who, two), 2000)
	check("one number: the fight's healing comes before sustain", R.Combine({ healer = 2, sustain = 5, fight = 3 }).healer == 3)
end
c = second({ ITEM_MOD_STAMINA_SHORT = 10 })
check("stamina: survival up, threat as it was", c.tank > 0 and c.threat == 0)

print("with a shield: block, and Seal of Fury's absorb")
worn.shield, worn.block, worn.blockValue = true, 4.68, 14
-- a level 28 elite does 23.00 x 1.25 a second, 57.5 a hit every 2 seconds,
-- and 62.70% lands past 1,654 armor: 36.05.
-- Block covers 14 / 36.05 of a hit, 4.68% of the time: 1.817% of the damage.
worn.shield = false
local without = R.Survival(worn)
worn.shield = true
near("block against no shield, percent", R.Change(without, R.Survival(worn)), 1.69)
-- Seal of Fury: 0.96 hits x 1.15 / 2.8 a second x 14 Holy x half = 2.760
-- absorbed a second, of 36.05 x (1 - 15.06%) x 1.05 for the enemy's crits
-- / 2 = 16.08 taken: 17.17%, and 1 / (1 - 17.17%) is 20.73% more life
near("Seal of Fury's absorb on top, percent", R.Change(R.Survival(worn), R.Survival(worn, kit)), 18.58)
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
-- taken: 36.05 a hit x (1 - 15.06%) x 1.05 / 2 seconds = 16.08 a second. 4
-- health per 5 is 0.8 a second; 16 is 3.2. Taking 4 off: (1 - 3.2 / 16.08)
-- over (1 - 2.4 / 16.08), less 1 = -5.85%
local less = M.Swap(worn, rates, { ITEM_MOD_HEALTH_REGEN_SHORT = 4 }, nil)
near("health per 5 after taking 4 off", less.healthPer5, 12)
near("losing 4 health per 5, tank percent", R.Change(R.Survival(worn), R.Survival(less)), -5.27)
worn.healthPer5 = nil

print("a weapon's chance on hit")
local plainHit = R.Damage(worn, kit)
worn.proc = { damage = 98, magic = true, perMinute = 3 }
-- 98 damage 3 times a minute is 4.9 a second, and armor takes none of Fire
near("Searing Blade's fireball, DPS it adds", R.Damage(worn, kit) - plainHit, 4.9)
worn.proc = { damage = 98, magic = false, perMinute = 3 }
-- one that is not magic loses the enemy's armor share: a level 28 enemy's
-- 1,142 armor (the game's table), of 1,142 + 400 + 85 x 28
near("an enemy's armor by level, from the game's table", R.EnemyArmor(28), 1142)
near("past the table's end, its last level", R.EnemyArmor(200), 4113)
near("the same, not magic", R.Damage(worn, kit) - plainHit, 4.9 * (1 - 1142 / 3922))
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
-- YOUR SPELLS BY ID, THEIR NUMBERS BY POSITION (Josh 2026-11-17: "Let's
-- proceed with the rework"). The descriptions are the ones his level 30
-- paladin's spellbook gave, as the Testing page's Record wrote them down.
print("spells found by id and read by position")
assert(loadfile("Modules/Upgrades/SpellData.lua"))("BeebMod", BT)
assert(loadfile("Modules/Upgrades/Read.lua"))("BeebMod", BT)
local Rd, data = UP.Read, UP.SpellData
near("a number with its thousands marked", Rd.Number("1,234"), 1234)
near("a decimal", Rd.Number("43.2"), 43.2)
near("the other way round, thousands", Rd.Number("1.234"), 1234)
near("the other way round, a decimal", Rd.Number("43,2"), 43.2)
near("both marks", Rd.Number("1.234,5"), 1234.5)
near("one that ends a sentence", Rd.Number("417."), 417)
local pal = data.spells.PALADIN
local function read(id, words)
	return pal[id] and Rd.Planned(pal[id].read, words) or {}
end
local strike = read(680, "An instant strike that causes 43.2% weapon damage plus an additional 18 to 23 as Holy damage.")
check("Holy Strike is known by its id", pal[680] and pal[680].is == "holyStrike")
near("its weapon share", strike.percent or 0, 43.2)
near("the middle of its Holy damage", strike.holy or 0, 20.5)
near("its share of spell power, from the table", pal[680].share, 0.429)
local command = read(20915, "Gives the Paladin a chance to deal additional Holy damage equal to 70% of normal weapon damage.  "
	.. "Only one Seal can be active on the Paladin at any one time.  Lasts 30 sec.\n\nUnleashing this Seal's energy will judge "
	.. "an enemy, instantly causing 83 to 93 Holy damage, 166 to 186 if the target is stunned or incapacitated.")
near("Seal of Command's weapon share", command.percent or 0, 70)
near("its Judgement, not the stunned one", command.judge or 0, 88)
local crusader = read(20305, "Fills the Paladin with the spirit of a crusader for 30 sec, granting 107 melee attack power.  "
	.. "The Paladin also attacks 40% faster, but deals less damage with each attack.  Only one Seal can be active on the "
	.. "Paladin at any one time.\n\nUnleashing this Seal's energy will judge an enemy for 10 sec, increasing Holy damage "
	.. "taken by up to 58.  Your melee strikes will refresh the spell's duration.  Only one Judgement per Paladin can be "
	.. "active at any one time.")
near("Seal of the Crusader's attack power", crusader.ap or 0, 107)
near("and what its Judgement adds to Holy damage", crusader.holy or 0, 58)
local light = read(1042, "Heals a friendly target for 474 to 527.")
near("Holy Light's middle", light.amount or 0, 500.5)
-- the same sentence in another language's order of words reads the same
local german = read(1042, "Heilt ein befreundetes Ziel um 474 bis 527.")
near("and in words it cannot read", german.amount or 0, 500.5)
check("a description with another count of numbers is not guessed at",
	Rd.Planned(pal[680].read, "An instant strike that causes 43.2% weapon damage.") == nil)
check("Blessing of Kings raises every stat, by its id", data.stats[20217] and data.stats[20217].all == 10)
local found = {}
check("and is taken from the table", Rd.StatPercents(20217, found, "") == true)
near("as a tenth more strength", found.strength or 0, 1.1)
check("Searing Blade's chance on hit, from the table", data.procs[12992] and data.procs[12992][1] == 98 and data.procs[12992][2] == true)
-- a weapon's lines, from the client's own sentences
_G.DAMAGE_TEMPLATE, _G.SPEED = "%s - %s Schaden", "Tempo"
local low, high = ("58 - 87 Schaden"):match(Rd.Shape("DAMAGE_TEMPLATE", "%s - %s Damage"))
check("a weapon's damage line in the client's own words", low == "58" and high == "87")
_G.DAMAGE_TEMPLATE, _G.SPEED = nil, nil
low, high = ("58 - 87 Damage"):match(Rd.Shape("DAMAGE_TEMPLATE", "%s - %s Damage"))
check("and in English where the client has no sentence", low == "58" and high == "87")

-- THE FOUR FIXES FOR A PLAYER LEVELING (Josh 2026-11-17: "Let's fix 1-4")
print("a fight as long as the enemy lasts")
do
	local keep = worn.level
	local _, _, _, seconds = R.Damage(worn, kit)
	check("below the top level, a fight of under half a minute: " .. ("%.1f"):format(seconds), seconds > 8 and seconds < 30)
	local d = R.Damage(worn, kit)
	near("which is the enemy's health over your damage", R.EnemyHealth(28) / d, seconds)
	local wise = M.Swap(worn, rates, nil, { ITEM_MOD_INTELLECT_SHORT = 10 })
	local strong = M.Swap(worn, rates, nil, { ITEM_MOD_STRENGTH_SHORT = 10 })
	check("intellect does next to nothing for damage in a fight that short", math.abs(R.Change(d, (R.Damage(wise, kit)))) < 0.2)
	check("and strength does", R.Change(d, (R.Damage(strong, kit))) > 1.5)
	worn.level = 60
	local _, _, _, long = R.Damage(worn, kit)
	near("at the top level, the long fight", long, R.FIGHT_SECONDS)
	worn.level = keep
	near("threat is a group's: the long fight below it too", R.FightSeconds(worn, kit, { white = 1.33, holy = 2.5 }), R.FIGHT_SECONDS)
end

print("every rank of a heal, each with its own share")
do
	local top, first = pal[1042], pal[635]
	near("the top rank's share is the table's", Rd.HealShare(top, 500.5, 68, 30), 0.713)
	near("the first rank's is cut, as its description shows", Rd.HealShare(first, 63.5, 68, 30), 0.254)
	near("with little healing power to measure by, the table's", Rd.HealShare(first, 50, 10, 30), 0.714)
	-- with much healing power and little mana, a low rank is the better buy
	local healer = { healing = 600, spellCrit = 0, mana = 1500, manaPer5 = 0, spiritRegen = 0 }
	local ranks = {
		heals = { { name = "low", amount = 212.5, share = 0.714, cast = 2.5, cost = 110 },
			{ name = "top", amount = 500.5, share = 0.714, cast = 2.5, cost = 275 } },
		at = { healing = 68 },
	}
	local both = R.FightHealing(healer, ranks)
	local only = R.FightHealing(healer, { heals = { ranks.heals[2] }, at = ranks.at })
	check(("a lower rank known is more healing from the same mana: %.0f against %.0f"):format(both, only), both > only * 1.2)
end

print("the highest rank you know, in whatever order the spellbook has them")
do
	local found = Rd.ByRank({
		{ id = 680, entry = pal[680], at = 1 }, { id = 679, entry = pal[679], at = 2 }, { id = 1866, entry = pal[1866], at = 3 },
	})
	check("Holy Strike's ranks by the level each is learned at, the highest last",
		found[1].id == 679 and found[2].id == 1866 and found[3].id == 680 and pal[680].lvl == 28)
end

print("Defense")
do
	-- (Josh 2026-11-17: "Defense is a main tanking stat... I think we should
	-- consider it")
	local keep = worn.shield
	worn.shield = false
	local sturdy = M.Swap(worn, rates, nil, { ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10 })
	near("10 Defense is 0.4% more dodge", sturdy.dodge - worn.dodge, 0.4)
	near("and parry", sturdy.parry - worn.parry, 0.4)
	near("and is kept for the enemy's side of it", sturdy.defense, 10)
	-- avoided 15.06% -> 15.06 + 0.4 dodge + 0.4 parry + 0.4 missed = 16.26%;
	-- crits 5% -> 4.6%. (1 - 0.1506) / (1 - 0.1626) x 1.05 / 1.046, less 1
	-- (of the physical 95%; the magic 5% is as it was: 1.66%)
	near("10 Defense, tank percent", R.Change(R.Survival(worn), R.Survival(sturdy)), 1.66)
	local set = M.Swap(worn, rates, nil, { UPGRADES_DEFENSE = 10 })
	near("the same from a set bonus", R.Survival(set), R.Survival(sturdy))
	worn.shield = keep
end

print("resistances, attack power against a kind of enemy, expertise")
do
	-- (Josh 2026-11-17: "We should consider resists in the tanking stats...
	-- Attack power vs type should be divided by however many types there
	-- are... Expertise should have a value for dps and tank threat")
	local keep = worn.shield
	worn.shield = false
	local warded = M.Swap(worn, rates, nil, { RESISTANCE2_NAME = 30 })
	near("30 fire resistance is kept by its school", warded.resist[2], 30)
	near("and no other", warded.resist[5], 0)
	local tank = R.Change(R.Survival(worn), R.Survival(warded))
	check(("a resistance is worth something to a tank, and not much: %+.2f%%"):format(tank), tank > 0.05 and tank < 1)
	local all = M.Swap(worn, rates, nil, { ITEM_MOD_SPELL_RESISTANCE_ALL_SCHOOLS_SHORT = 10 })
	near("resistance to every school goes to all five", all.resist[2] + all.resist[3] + all.resist[4] + all.resist[5] + all.resist[6], 50)
	near("at 28, 140 resistance is the most there is", R.Resisted(140, 28), 0.75)
	near("and 500 no more", R.Resisted(500, 28), 0.75)
	worn.shield = keep

	local slayer = M.Swap(worn, rates, nil, { ITEM_MOD_ATTACK_POWER_VS_UNDEAD_SHORT = 40 })
	near("40 attack power against undead is 5 of plain: one kind of eight", slayer.attackPower - worn.attackPower, 5)
	local set = M.Swap(worn, rates, nil, { UPGRADES_ATTACK_POWER_VS = 40 })
	near("the same from a set bonus", set.attackPower - worn.attackPower, 5)

	local sure = M.Swap(worn, rates, nil, { ITEM_MOD_EXPERTISE_RATING_SHORT = 40 })
	near("40 expertise rating is 4 expertise, 1% off an enemy's dodge", sure.expertise, 1)
	local d = R.Damage(worn, kit)
	local more = R.Change(d, (R.Damage(sure, kit)))
	check(("which is about 1%% more damage: %+.2f%%"):format(more), more > 0.6 and more < 1.4)
	local threat = R.Change(R.Threat(worn, kit), R.Threat(sure, kit))
	check(("and more than that in threat, from the front, where it is parried too: %+.2f%%"):format(threat), threat > more)
end

print("how many enemies AoE is")
do
	-- (Josh 2026-11-17: "either the max, or 4... whichever is higher")
	near("four, with no spell that says more", R.AoeEnemies({}), 4)
	near("four, where a spell says fewer", R.AoeEnemies({ consecration = { cap = 3 } }), 4)
	near("as many as a spell says, where that is more", R.AoeEnemies({ consecration = { cap = 6 } }), 6)
	local cons = read(20116, "Consecrates the land beneath the Paladin, doing 24 Holy damage over 8 sec to enemies who "
		.. "enter the area. The first 4 enemies who enter the area will take an additional 74 damage over 8 sec.")
	near("Consecration says how many take its second part", cons.cap or 0, 4)
	near("and both parts", (cons.first or 0) + (cons.second or 0), 98)
end

print("a class priced by its abilities: the warrior")
do
	-- (Josh 2026-11-17: "Warrior sounds good to start. We can just leave
	-- healing at 0.0")
	local w = data.spells.WARRIOR
	check("Heroic Strike is known by its id, as a swing's", w[25286] and w[25286].is == "ability" and w[25286].swing == true)
	check("and by its lower ranks under the same name", w[78] and w[78].key == w[25286].key)
	local strike = Rd.Planned(w[25286].read, "A strong attack that increases melee damage by 157 and causes a high amount of threat.")
	near("what it adds to a swing", strike.add or 0, 157)
	local clap = Rd.Planned(w[11581].read, "Blasts nearby enemies with thunder, increasing the time between their attacks by 10% for "
		.. "30 sec and doing 103 damage to them. Will affect up to 4 targets.")
	near("Thunder Clap's damage", clap.hit or 0, 103)
	near("and how many it reaches", clap.cap or 0, 4)
	local fighter = {
		level = 40, attackPower = 400, armor = 2500, crit = 12, health = 2400, mana = 0, manaPer5 = 0,
		damageMin = 150, damageMax = 220, weaponSpeed = 3.4, haste = 0, dodge = 6, parry = 5, block = 0, blockValue = 0, hit = 0,
		spellHit = 0, spellCrit = 0, healing = 0, spellDamage = { [2] = 0 }, twoHand = true, shield = false,
	}
	local moves = { heals = {}, seals = {}, at = { healing = 0, spell = 0 }, rage = { charge = { amount = 12 } }, abilities = {
		heroicstrike = { v = { add = 80 }, cost = 15, swing = true, threat = 120, tmult = 1 },
		mortalstrike = { v = { add = 85 }, cost = 30, cooldown = 6, weapon = "norm" },
		whirlwind = { v = { cap = 4 }, cost = 25, cooldown = 10, weapon = "norm", aoe = true },
		sunderarmor = { v = {}, cost = 15, threat = 200, tmult = 1, tank = true },
	} }
	local plain = { heals = {}, seals = {}, at = {}, abilities = {} }
	local d, _, _, seconds = R.Damage(fighter, moves)
	local white = R.Damage(fighter, plain)
	check(("abilities add to the swings: %.1f against %.1f"):format(d, white), d > white * 1.15 and d < white * 3)
	check("a fight below the top level is short", seconds < 60)
	local one = R.Damage(fighter, moves, { long = true })
	local four = R.Damage(fighter, moves, { enemies = 4, long = true })
	check(("more enemies, more damage, by what reaches them: %.1f against %.1f"):format(four, one), four > one)
	local threat = R.Threat(fighter, moves)
	check(("threat counts what a tank's abilities add outright: %.1f"):format(threat), threat > one * R.STANCE_THREAT)
	near("its healer number has nothing to stand on", R.Healing(fighter, moves), 0)
	check("and so shows no change", R.Change(R.FightHealing(fighter, moves), R.FightHealing(fighter, moves)) == nil)
	local stronger = {}
	for k, v in pairs(fighter) do stronger[k] = v end
	stronger.attackPower, stronger.damageMin, stronger.damageMax = 440, 150 + 40 / 14 * 3.4, 220 + 40 / 14 * 3.4
	check("attack power is worth damage", R.Damage(stronger, moves) > d)
	-- (Josh 2026-11-18, a shield at -0.1% DPS: "everything should be a gain")
	local armored = {}
	for k, v in pairs(fighter) do armored[k] = v end
	armored.armor, armored.dodge, armored.parry = fighter.armor + 500, fighter.dodge + 3, fighter.parry + 3
	near("armor and avoidance take no damage away", R.Damage(armored, moves), d)
	check("nor threat", math.abs(R.Threat(armored, moves) - threat) < 0.001)
	near("four enemies, where no ability says more", R.AoeEnemies(moves), 4)
end

print("a caster priced by the same sum: the mage")
do
	-- (Josh 2026-11-17: "We could do mage next - i do have one of those, but
	-- I'd rather use numbers from the game data")
	local m = data.spells.MAGE
	local ball = m[25306]
	check("Fireball is known by its id, as a Fire spell", ball and ball.is == "ability" and ball.spell == 3 and ball.over == true)
	near("its share of spell power is the table's", ball.share, 1)
	local read = Rd.Planned(ball.read, "Hurls a fiery ball that causes 596 to 760 Fire damage and an additional 76 Fire damage over 8 sec.")
	near("its hit is the middle of what it says", read.hit or 0, 678)
	near("and its burn", read.dot or 0, 76)
	near("Arcane Missiles' share is every missile's", m[10212].dshare, 1.43)
	check("and it is channelled for as long as it lasts", m[10212].channel == true and m[10212].secs == 5)
	near("Blizzard's share is every second's", m[10187].dshare, 0.336)
	check("Frostfire Bolt has two schools", m[1237313].spell == 3 and m[1237313].spell2 == 5)
	check("Evocation is mana given back", m[12051].is == "mana" and m[12051].secs == 8)
	local caster = {
		level = 60, attackPower = 20, armor = 800, crit = 3, health = 2500, mana = 4000, manaPer5 = 10, spiritRegen = 15,
		damageMin = 20, damageMax = 30, weaponSpeed = 0, haste = 0, dodge = 4, parry = 0, block = 0, blockValue = 0, hit = 0,
		spellHit = 0, spellCrit = 8, healing = 0, spellDamage = { [2] = 100, [3] = 100, [4] = 100, [5] = 100, [6] = 100, [7] = 100 },
	}
	local function with(change)
		local t = {}
		for k, v in pairs(caster) do t[k] = v end
		t.spellDamage = {}
		for k, v in pairs(caster.spellDamage) do t.spellDamage[k] = v end
		change(t)
		return t
	end
	local spells = { caster = true, heals = {}, seals = {}, at = { spell = 100, healing = 0, spells = { [3] = 100, [5] = 100, [7] = 100 } },
		abilities = {
			fireball = { v = { hit = 700, dot = 80 }, cost = 400, cast = 3.5, spell = 3, share = 1, secs = 8, over = true },
			fireblast = { v = { hit = 480 }, cost = 340, cooldown = 8, spell = 3, share = 0.429 },
			explosion = { v = { hit = 250 }, cost = 390, spell = 7, share = 0.143, aoe = true },
		} }
	local long = R.Damage(caster, spells, { long = true })
	check(("a fight with no weapon to swing still has a number: %.1f"):format(long), long == long and long > 0)
	-- mana is what runs out over three minutes: 4000 + 2 a second, in Fireballs
	near("a long fight is short of mana", long, (4000 / 180 + 2) / 400 * (700 * (1 + 0.5 * 0.08) + 80 * 3.5 / 8) * 0.96)
	local short = with(function(t) t.level = 30 end)
	local quick, _, _, seconds = R.Damage(short, spells)
	check("a fight below the top level is short", seconds < 60)
	check(("and is short of time, so it does far more: %.1f"):format(quick), quick > long * 2)
	check("spell power in a spell's school is worth damage",
		R.Damage(with(function(t) t.spellDamage[3] = 150 end), spells, { long = true }) > long)
	near("and in another school is worth nothing to it",
		R.Damage(with(function(t) t.spellDamage[5] = 150 end), spells, { long = true }), long)
	check("spell crit is worth damage", R.Damage(with(function(t) t.spellCrit = 12 end), spells, { long = true }) > long)
	check("spell hit is worth damage", R.Damage(with(function(t) t.spellHit = 2 end), spells, { long = true }) > long)
	check("mana is worth damage where it runs out", R.Damage(with(function(t) t.mana = 4500 end), spells, { long = true }) > long)
	near("attack power is worth nothing", R.Damage(with(function(t) t.attackPower = 200 end), spells, { long = true }), long)
	local four = R.Damage(short, spells, { enemies = 4 })
	check(("more enemies, more damage, by what reaches them: %.1f against %.1f"):format(four, quick), four > quick)
	spells.evocation = { pct = 1500, secs = 8 }
	check("Evocation gives a long fight more mana", R.Damage(caster, spells, { long = true }) > long)
	near("and a short one nothing", R.Damage(short, spells), quick)
	near("its healer number has nothing to stand on", R.Healing(caster, spells), 0)
	local after = M.Swap(worn, { critPerRating = 1 / 14, hitPerRating = 0.1 }, nil,
		{ ITEM_MOD_CRIT_SPELL_RATING_SHORT = 14, ITEM_MOD_HIT_SPELL_RATING_SHORT = 10 })
	near("spell crit rating is spell crit", after.spellCrit, worn.spellCrit + 1)
	near("and not melee crit", after.crit, worn.crit)
	near("spell hit rating is spell hit", after.spellHit, (worn.spellHit or 0) + 1)
end

print("crit talents")
do
	-- (Josh 2026-11-18: "Let's do the crit")
	local t = data.talents
	check("Critical Mass is a mage's, on its Fire spells", t.MAGE[11115].crit == 2 and t.MAGE[11115].keys.fireball
		and not t.MAGE[11115].keys.frostbolt)
	check("Ice Shards is on its Frost spells", t.MAGE[11207].more == 100 and t.MAGE[11207].keys.frostbolt
		and not t.MAGE[11207].keys.fireball)
	check("Ignite follows a Fire crit", t.MAGE[11119].after == 40 and t.MAGE[11119].keys.scorch)
	check("Arcane Mind's amount is its description's second number", t.MAGE[11232].nth == 2)
	check("Impale is a warrior's, on its abilities", t.WARRIOR[16493].more == 10 and t.WARRIOR[16493].keys.mortalstrike)
	local function kit()
		return { caster = true, heals = {}, seals = {}, at = { spell = 0, healing = 0 }, abilities = {
			fireball = { v = { hit = 100 }, cost = 10, cast = 3, spell = 3 },
			frostbolt = { v = { hit = 100 }, cost = 10, cast = 3, spell = 5 },
		} }
	end
	local words = { [11115] = "Increases the critical strike chance of your Fire spells by 6%." }
	local function describe(id) return words[id] end
	local with = kit()
	Rd.Talents(with, t.MAGE, function(id) return id == 11115 or id == 11207 or id == 11119 end, describe)
	near("a talent's amount is what its words say now", with.abilities.fireball.critAdd, 6)
	near("or the table's, where they say nothing", with.abilities.frostbolt.critMore, 100)
	near("Ignite is on the Fire spell", with.abilities.fireball.critAfter, 40)
	check("and not the Frost one", with.abilities.frostbolt.critAfter == nil and with.abilities.frostbolt.critAdd == nil)
	local none = kit()
	Rd.Talents(none, t.MAGE, function() return false end, describe)
	check("a talent you do not have does nothing", none.abilities.fireball.critAdd == nil)
	local both = { abilities = { overpower = { v = {} } } }
	Rd.Talents(both, t.WARRIOR, function(id) return id == 12290 or id == 12963 end, describe)
	near("of two ranks the higher counts", both.abilities.overpower.critAdd, 50)
	-- in the sum: one Fireball every 3 s, 10% crit, 96% to land
	local s = { level = 60, attackPower = 0, armor = 0, crit = 0, health = 1, mana = 100000, manaPer5 = 0, damageMin = 0, damageMax = 0,
		weaponSpeed = 0, haste = 0, dodge = 0, parry = 0, hit = 0, spellHit = 0, spellCrit = 10, healing = 0,
		spellDamage = { [3] = 0, [5] = 0 } }
	local fire = kit()
	fire.abilities.frostbolt = nil
	near("a spell crit adds half", R.Damage(s, fire, { long = true }), 100 * 1.05 * 0.96 / 3)
	fire.abilities.fireball.critAdd, fire.abilities.fireball.critAfter = 6, 40
	near("more chance, and Ignite on each crit", R.Damage(s, fire, { long = true }), 100 * (1 + (1.5 * 1.4 - 1) * 0.16) * 0.96 / 3)
	local frost = kit()
	frost.abilities.fireball = nil
	frost.abilities.frostbolt.critMore = 100
	near("Ice Shards makes a crit double", R.Damage(s, frost, { long = true }), 100 * 1.1 * 0.96 / 3)
	frost.at.crits, frost.at.crit = { [5] = 14 }, 10
	near("a school's own crit is counted", R.Damage(s, frost, { long = true }), 100 * 1.14 * 0.96 / 3)
end

print("energy and combo points: the rogue")
do
	-- (Josh 2026-11-18: "Commit, then start on rogue")
	local r = data.spells.ROGUE
	check("Sinister Strike builds a point, for energy", r[11294].points == 1 and r[11294].energy == true and r[11294].cost == 45)
	check("Backstab needs a dagger, and you behind the enemy", r[25300].dagger == true and r[25300].behind == true)
	check("Eviscerate is a finishing move, at its energy and not its points", r[31016].finisher == true and r[31016].cost == 35)
	local evis = Rd.Planned(r[31016].read, "Finishing move that causes damage per combo point, increased by Attack Power:\n"
		.. "   1 point  : 224-332 damage\n   2 points: 394-502 damage\n   3 points: 564-672 damage\n"
		.. "   4 points: 734-842 damage\n   5 points: 904-1,012 damage")
	check("its damage is read for each count of points", evis and evis.p1 == 278 and evis.p3 == 618 and evis.p5 == 958)
	local rupture = Rd.Planned(r[11275].read, "Finishing move that causes damage over time, increased by your Attack Power.  "
		.. "Lasts longer per combo point:\n   1 point  : 240 damage over 8 secs\n   2 points: 350 damage over 10 secs\n"
		.. "   3 points: 480 damage over 12 secs\n   4 points: 630 damage over 14 secs\n   5 points: 800 damage over 16 secs")
	check("Rupture's total and seconds, for each", rupture and rupture.r1 == 240 and rupture.t1 == 8 and rupture.r5 == 800 and rupture.t5 == 16)
	local dice = Rd.Planned(r[6774].read, "Finishing move that increases melee attack speed by 30%.  Lasts longer per combo point:\n"
		.. "   1 point  : 9 seconds\n   2 points: 12 seconds\n   3 points: 15 seconds\n   4 points: 18 seconds\n   5 points: 21 seconds")
	check("Slice and Dice's percent and seconds", dice and dice.pct == 30 and dice.t1 == 9 and dice.t5 == 21)
	local ambush = Rd.Planned(r[11269].read, "Ambush the target, causing 250% weapon damage plus 290 to the target.  Must be stealthed "
		.. "and behind the target.  Requires a dagger in the main hand.  Awards 1 combo point.")
	check("a number the words say outright is read: Ambush's", ambush and ambush.pct == 250 and ambush.add == 290)
	local thief = {
		level = 60, attackPower = 500, armor = 1500, crit = 20, health = 3000, mana = 0, manaPer5 = 0, damageMin = 120, damageMax = 180,
		weaponSpeed = 2.6, haste = 0, dodge = 15, parry = 5, block = 0, blockValue = 0, hit = 0, spellHit = 0, spellCrit = 0, healing = 0,
		spellDamage = { [2] = 0 }, dagger = false,
	}
	local function with(change)
		local t = {}
		for k, v in pairs(thief) do t[k] = v end
		change(t)
		return t
	end
	local function kit(more)
		local a = { sinisterstrike = { v = { add = 68 }, cost = 45, weapon = "norm", points = 1 } }
		for k, v in pairs(more or {}) do a[k] = v end
		return { energy = true, heals = {}, seals = {}, at = { spell = 0, healing = 0 }, abilities = a }
	end
	local none = { energy = true, heals = {}, seals = {}, at = {}, abilities = {} }
	local white = R.Damage(thief, none)
	local strikes = R.Damage(thief, kit())
	-- 10 energy a second in Sinister Strikes of 45, each (the weapon evened out to 2.4 + 68) with 20% crit, through
	-- armor; 5% miss and 5% are dodged
	local through = 1 - R.ArmorCut(R.EnemyArmor(60), 60)
	near("energy is spent at its rate, whatever the gear", strikes - white, 10 / 45 * (150 - 500 / 14 * 2.6 + 500 / 14 * 2.4 + 68) * 1.2 * through * 0.9)
	local evisKit = kit({ eviscerate = { v = { p1 = 280, p2 = 440, p3 = 600, p4 = 760, p5 = 920 }, cost = 35, finisher = true } })
	check("a finishing move adds to what builds its points", R.Damage(thief, evisKit) > strikes)
	local alone = kit({ eviscerate = evisKit.abilities.eviscerate })
	alone.abilities.sinisterstrike = nil
	near("and is nothing with nothing to build them", R.Damage(thief, alone), white)
	local diceKit = kit({ sliceanddice = { v = { pct = 30, t1 = 9, t2 = 12, t3 = 15, t4 = 18, t5 = 21 }, cost = 25, finisher = true, speed = true } })
	local diced = R.Damage(thief, diceKit)
	check(("Slice and Dice is worth its share of your swings: %.1f against %.1f"):format(diced, strikes), diced > strikes)
	check("and no more than that, kept up the whole fight", diced - strikes < white * 0.3 + 0.01)
	local stab = { backstab = { v = { pct = 150, add = 150 }, cost = 60, weapon = "norm", points = 1, dagger = true, behind = true } }
	near("Backstab is nothing without a dagger", R.Damage(thief, kit(stab)), strikes)
	local knife = with(function(t) t.dagger = true end)
	check("and something with one, in a fight where you can stand behind", R.Damage(knife, kit(stab)) > R.Damage(knife, kit()))
	local young = with(function(t) t.level, t.dagger = 30, true end)
	near("but not in a fight alone", R.Damage(young, kit(stab)), R.Damage(young, kit()))
	local opener = kit({ ambush = { v = { pct = 250, add = 290 }, cost = 60, weapon = "norm", points = 1, dagger = true, opener = true } })
	local once = R.Damage(knife, opener) - R.Damage(knife, kit())
	check(("an opener is used once a fight: %.2f"):format(once), once > 0 and once < 15)
	-- the off hand
	local both = with(function(t) R.OffHand(t, { min = 60, max = 100, speed = 1.6 }) end)
	near("an off-hand weapon hits for half, its attack power counted", both.offMin, (60 + 500 / 14 * 1.6) * 0.5)
	local dualWhite = R.Damage(both, none)
	-- the main hand misses 19% more; the off hand's swings are added
	local main = 150 * 1.2 * through / 2.6
	local off = (80 + 500 / 14 * 1.6) * 0.5 * 1.2 * through / 1.6
	near("two weapons: both swing, and miss more", dualWhite, (main + off) * (1 - 0.24 - 0.05))
	local stronger = with(function(t) R.OffHand(t, { min = 60, max = 100, speed = 1.6 }) t.attackPower = 640 end)
	near("attack power gained since moves the off hand by half", R.Damage(stronger, none) - dualWhite,
		140 / 14 * 1.6 * 0.5 * 1.2 * through / 1.6 * 0.71)
	local unarmed = with(function(t) R.OffHand(t, { min = 60, max = 100, speed = 1.6 }) R.OffHand(t, false) end)
	near("an off hand taken away is gone", R.Damage(unarmed, none), white)
	check("hit is worth more with two weapons", R.Damage(with(function(t) R.OffHand(t, { min = 60, max = 100, speed = 1.6 }) t.hit = 5 end), none)
		/ dualWhite > R.Damage(with(function(t) t.hit = 5 end), none) / white)
	near("its healer number has nothing to stand on", R.Healing(thief, kit()), 0)
	local t = data.talents.ROGUE
	check("Lethality is a rogue's, on what builds points", t[14128].more == 6 and t[14128].keys.sinisterstrike and t[14128].keys.backstab)
end

print("shots and a pet: the hunter")
do
	-- (Josh 2026-11-18: "Commit and work on hunter")
	local h = data.spells.HUNTER
	check("Aimed Shot is a shot with the ranged weapon", h[20904].ranged == true and h[20904].weapon == "plain" and h[20904].cd == 6)
	check("Arcane Shot is magic", h[14287].spell == 7)
	check("Serpent Sting is damage over time and nothing else", h[425737].lasts == true and h[425737].secs == 12)
	local multi = Rd.Planned(h[2643].read, "Fires several missiles, hitting 3 targets. Multi-Shot shares its cooldown with Aimed Shot.")
	check("Multi-Shot says how many it hits", multi and multi.cap == 3)
	local archer = {
		level = 60, attackPower = 300, armor = 2000, crit = 5, health = 3000, mana = 3000, manaPer5 = 0, damageMin = 100, damageMax = 150,
		weaponSpeed = 3, haste = 0, dodge = 10, parry = 5, block = 0, blockValue = 0, hit = 0, spellHit = 0, spellCrit = 5, healing = 0,
		spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, strength = 50, agility = 200, stamina = 100, intellect = 80, spirit = 60,
		rangedMin = 200, rangedMax = 300, rangedSpeed = 2.5, rangedBase = 2.9, rangedPower = 700, rangedCrit = 20, rangedHit = 0,
	}
	local function with(change)
		local t = {}
		for k, v in pairs(archer) do t[k] = v end
		t.spellDamage = { [2] = 0, [4] = 0, [7] = 0 }
		change(t)
		return t
	end
	local function kit(more)
		local a = {}
		for k, v in pairs(more or {}) do a[k] = v end
		return { ranged = true, mana = true, heals = {}, seals = {}, at = { spell = 0, healing = 0 }, abilities = a }
	end
	local through = 1 - R.ArmorCut(R.EnemyArmor(60), 60)
	local auto = R.Damage(archer, kit(), { long = true })
	near("Auto Shot is the ranged weapon's, and none is dodged", auto, 250 * 1.2 * through * 0.95 / 2.5)
	near("the melee weapon is not in it", R.Damage(with(function(t) t.damageMin, t.damageMax = 300, 400 end), kit(), { long = true }), auto)
	local pet = with(function(t) t.petDps = 40 end)
	near("the pet does its own, through armor", R.Damage(pet, kit(), { long = true }), auto + 40 * through)
	local aimed = kit({ aimedshot = { v = { add = 350 }, cost = 310, cooldown = 6, cast = 2, weapon = "plain" } })
	-- mana is what runs out: 3000 over three minutes, in shots of 310
	near("a shot is the ranged weapon's damage and what it adds", R.Damage(archer, aimed, { long = true }) - auto,
		3000 / 180 / 310 * (250 + 350) * 1.2 * through * 0.95)
	local arcane = kit({ arcaneshot = { v = { hit = 280 }, cost = 300, cooldown = 6, spell = 7 } })
	near("a magic shot crits as a shot does, and armor takes none", R.Damage(archer, arcane, { long = true }) - auto,
		3000 / 180 / 300 * 280 * 1.2 * 0.95)
	local sting = kit({ serpentsting = { v = { dot = 600 }, cost = 1, spell = 4, secs = 12, lasts = true } })
	near("Serpent Sting once each time it runs out", R.Damage(archer, sting, { long = true }) - auto, 600 / 12 * 0.95)
	local multi4 = kit({ multishot = { v = { cap = 3 }, cost = 1, cooldown = 6, weapon = "plain", aoe = true } })
	near("Multi-Shot reaches as many as it says",
		R.Damage(archer, multi4, { long = true, enemies = 4 }) - R.Damage(archer, kit(), { long = true, enemies = 4 }),
		250 * 3 * 1.2 * through * 0.95 / 6)
	-- the swap math
	local rates = { attackPowerPer = { strength = 1, agility = 1 }, critPerAgility = 0.02, critPerRating = 1 / 14, hitPerRating = 0.1 }
	local agile = M.Swap(archer, rates, nil, { ITEM_MOD_AGILITY_SHORT = 10 })
	near("agility is ranged attack power, 2 a point", agile.rangedPower, 720)
	near("which is damage by the weapon's own speed", agile.rangedMin, 200 + 20 / 14 * 2.9)
	near("and ranged crit, as melee's", agile.rangedCrit, 20.2)
	local powered = M.Swap(archer, rates, nil, { ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 28 })
	near("ranged attack power on a piece", powered.rangedMax, 300 + 2 * 2.9)
	near("is none for melee", powered.damageMax, 150)
	local bow = M.Swap(archer, rates, nil, nil, { worn = { min = 50, max = 100, speed = 2.9 }, new = { min = 80, max = 140, speed = 2.0 }, ranged = true })
	-- what the worn one had beyond the weapon's own, a second of its speed, is kept
	near("a new ranged weapon: its damage, and yours by its speed", bow.rangedMin, 80 + (200 - 50) / 2.9 * 2.0)
	near("its speed, with the quiver's haste kept", bow.rangedSpeed, 2.5 * 2.0 / 2.9)
	near("and the melee weapon is left alone", bow.damageMin, 100)
	check("a faster bow of less damage is less a shot, more shots", bow.rangedMax < archer.rangedMax and bow.rangedSpeed < archer.rangedSpeed)
	local plain = M.Swap(worn, rates, nil, { ITEM_MOD_AGILITY_SHORT = 10 })
	check("a class with no ranged weapon has none after", plain.rangedMin == nil and plain.rangedPower == nil)
	check("Mortal Shots is a hunter's, on its shots", data.talents.HUNTER[19485].more == 30 and data.talents.HUNTER[19485].keys.aimedshot)
	near("its healer number has nothing to stand on", R.Healing(archer, kit()), 0)
end

print("damage over time, a pet and Life Tap: the warlock")
do
	-- (Josh 2026-11-18: "Ok, next class?")
	local w = data.spells.WARLOCK
	check("Corruption is damage over time and nothing else, in Shadow", w[25311].lasts == true and w[25311].spell == 6 and w[25311].secs == 18)
	near("its share of spell power is every tick's", w[25311].dshare, 1.2)
	check("Siphon Life ticks every 3 seconds", w[18881].period == 3 and w[18881].secs == 30)
	check("Life Tap is mana for a cast", w[11689].is == "tap")
	local tapped = Rd.Planned(w[11689].read, "Converts 439 Health into 439 Mana for you. Spirit increases the amount converted.")
	check("and its second number is the mana", tapped and tapped.mana == 439)
	local lock = {
		level = 60, attackPower = 20, armor = 800, crit = 3, health = 3000, mana = 4000, manaPer5 = 0, spiritRegen = 10,
		damageMin = 20, damageMax = 30, weaponSpeed = 0, haste = 0, dodge = 4, parry = 0, block = 0, blockValue = 0, hit = 0,
		spellHit = 0, spellCrit = 10, healing = 0, spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 },
	}
	local function with(change)
		local t = {}
		for k, v in pairs(lock) do t[k] = v end
		t.spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }
		change(t)
		return t
	end
	local function kit(more)
		local a = {}
		for k, v in pairs(more or {}) do a[k] = v end
		return { caster = true, pet = true, heals = {}, seals = {}, abilities = a,
			at = { spell = 0, healing = 0, spells = { [3] = 0, [6] = 0 } } }
	end
	local through = 1 - R.ArmorCut(R.EnemyArmor(60), 60)
	near("with no pet out, nothing", R.Damage(lock, kit(), { long = true }), 0)
	local pet = with(function(t) t.petDps = 50 end)
	near("the pet does its own, through armor", R.Damage(pet, kit(), { long = true }), 50 * through)
	local corruption = { v = { dot = 822 }, cost = 1, cast = 2, spell = 6, dshare = 1.2, secs = 18, lasts = true }
	near("damage over time is kept up, once each time it runs out", R.Damage(lock, kit({ corruption = corruption }), { long = true }),
		822 / 18 * 0.96)
	near("and spell power moves it by its share",
		R.Damage(with(function(t) t.spellDamage[6] = 100 end), kit({ corruption = corruption }), { long = true }), (822 + 120) / 18 * 0.96)
	local siphon = { v = { tick = 45 }, cost = 1, spell = 6, secs = 30, period = 3, lasts = true }
	near("an amount every 3 seconds, for as long as it lasts", R.Damage(lock, kit({ siphonlife = siphon }), { long = true }),
		45 * 30 / 3 / 30 * 0.96)
	local immolate = { v = { hit = 279, dot = 510 }, cost = 1, cast = 2, spell = 3, secs = 15, lasts = true }
	near("Immolate: its hit, which can crit, and its burn, each time it runs out",
		R.Damage(lock, kit({ immolate = immolate }), { long = true }), (279 * 1.05 + 510) / 15 * 0.96)
	-- Life Tap
	local bolt = { v = { hit = 500 }, cost = 370, cast = 3, spell = 6, share = 0.857 }
	local dry = R.Damage(lock, kit({ shadowbolt = bolt }), { long = true })
	near("without Life Tap a long fight is short of mana", dry, 4000 / 180 / 370 * 500 * 1.05 * 0.96)
	local tapping = kit({ shadowbolt = bolt })
	tapping.lifetap = { mana = 440 }
	-- each bolt takes its 3 seconds and the taps that pay for it
	near("with it, each spell takes the time to tap its cost back", R.Damage(lock, tapping, { long = true }),
		500 * 1.05 * 0.96 / (3 + 370 / 440 * 1.5))
	local young = with(function(t) t.level = 30 end)
	local quick, _, _, seconds = R.Damage(young, tapping)
	check("a short fight on a full bar is not charged for tapping", seconds < 60 and math.abs(quick - 500 * 1.05 * 0.96 / 3) < 0.01)
	check("mana is worth nothing to one that taps, in a long fight",
		math.abs(R.Damage(with(function(t) t.mana = 6000 end), tapping, { long = true }) - R.Damage(lock, tapping, { long = true })) < 0.01)
	check("Ruin is a warlock's", data.talents.WARLOCK[17959].more == 100)
	near("its healer number has nothing to stand on", R.Healing(lock, kit()), 0)
end

print("a healer by the heals' own sum: the priest")
do
	-- (Josh 2026-11-18: "Let's go ahead with that spec work")
	local p = data.spells.PRIEST
	check("Greater Heal is a heal, with its own amount from the tables", p[25314].is == "heal:greaterHeal" and p[25314].base == 1960)
	check("Smite is a Holy spell", p[10934].spell == 2 and p[10934].is == "ability")
	check("Shadow Word: Pain is damage over time and nothing else", p[10894].lasts == true and p[10894].spell == 6)
	check("the priest fights one way", data.specs.PRIEST == nil)
	local healer = { level = 60, mana = 5000, manaPer5 = 30, spiritRegen = 20, spellCrit = 5, healing = 300 }
	local heals = { at = { healing = 300 }, heals = {
		{ name = "Greater Heal", amount = 2200, cast = 3, cost = 710, share = 0.857 },
		{ name = "Flash Heal", amount = 1000, cast = 1.5, cost = 380, share = 0.429 },
	} }
	local now = R.FightHealing(healer, heals)
	check(("a priest's heals give a healer number: %.0f"):format(now), now > 0)
	local more = {}
	for k, v in pairs(healer) do more[k] = v end
	more.healing = 400
	check("and healing power moves it", R.FightHealing(more, heals) > now)
end

print("a class that fights two ways: the shaman")
do
	-- (Josh 2026-11-18: "the player could either have a melee spec or
	-- caster. We need to determine which one by which talents they have
	-- selected. The rotation formula will be completely different based on
	-- that.")
	local specs = data.specs.SHAMAN
	check("the shaman fights two ways", specs.melee and specs.caster and specs.caster.caster == true and specs.melee.mana == true)
	check("Stormstrike marks melee, and is its ability", specs.melee.marks[17364] and data.spells.SHAMAN[17364].spec == "melee")
	check("Elemental Fury marks a caster", specs.caster.marks[16089] == true)
	check("Lightning Bolt is a caster's", data.spells.SHAMAN[403].spec == "caster")
	check("Earth Shock is used either way", data.spells.SHAMAN[10414].spec == nil)
	-- which way, by talents
	near("no talents: no way marked", Rd.Spec(specs, function() return false end) == nil and 1 or 0, 1)
	check("Stormstrike known: melee", Rd.Spec(specs, function(id) return id == 17364 end) == "melee")
	check("Elemental Fury known: a caster", Rd.Spec(specs, function(id) return id == 16089 end) == "caster")
	check("more of one than the other: that one",
		Rd.Spec(specs, function(id) return id == 17364 or id == 16255 or id == 16089 end) == "melee")
	check("as many of each: none, and gear decides", Rd.Spec(specs, function(id) return id == 17364 or id == 16089 end) == nil)
	-- the sums
	local shaman = {
		level = 60, attackPower = 600, armor = 3000, crit = 15, health = 3500, mana = 4000, manaPer5 = 0, damageMin = 250, damageMax = 350,
		weaponSpeed = 3.5, haste = 0, dodge = 5, parry = 5, block = 0, blockValue = 0, hit = 0, spellHit = 0, spellCrit = 5, healing = 0,
		spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, twoHand = true,
	}
	local function with(change)
		local t = {}
		for k, v in pairs(shaman) do t[k] = v end
		t.spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }
		change(t)
		return t
	end
	local function kit(spec)
		return { specs = specs, spec = spec, heals = {}, seals = {}, at = { spell = 0, healing = 0, spells = { [4] = 0 } }, abilities = {
			lightningbolt = { v = { hit = 450 }, cost = 265, cast = 3, spell = 4, share = 0.857, spec = "caster" },
			earthshock = { v = { hit = 540 }, cost = 450, cooldown = 6, spell = 4, share = 0.386 },
			stormstrike = { v = { pct = 150 }, cost = 300, cooldown = 8, weapon = "norm", spec = "melee" },
		} }
	end
	local melee = R.Damage(shaman, kit("melee"), { long = true })
	local caster = R.Damage(shaman, kit("caster"), { long = true })
	local white = R.Damage(shaman, { abilities = {}, heals = {}, seals = {}, at = {} }, { long = true })
	check(("melee swings, with Stormstrike and a shock: %.1f over %.1f of swings"):format(melee, white), melee > white)
	check(("a caster does not swing: %.1f"):format(caster), caster < white)
	local strong = with(function(t) t.damageMin, t.damageMax = 350, 450 end)
	check("a better weapon is worth damage to melee", R.Damage(strong, kit("melee"), { long = true }) > melee)
	near("and nothing to a caster", R.Damage(strong, kit("caster"), { long = true }), caster)
	local wise = with(function(t) t.spellDamage[4] = 200 end)
	check("spell power is worth more to a caster than to melee",
		R.Damage(wise, kit("caster"), { long = true }) / caster > R.Damage(wise, kit("melee"), { long = true }) / melee)
	-- no way marked: the higher of the two, which follows gear
	near("no way marked, a two-hander in hand: melee's number", R.Damage(shaman, kit(nil), { long = true }), melee)
	local robed = with(function(t)
		t.damageMin, t.damageMax, t.attackPower, t.mana, t.spellCrit = 40, 60, 100, 9000, 20
		t.spellDamage[4] = 500
	end)
	near("no way marked, spell power and mana: a caster's number", R.Damage(robed, kit(nil), { long = true }),
		R.Damage(robed, kit("caster"), { long = true }))
	check("and that is the higher", R.Damage(robed, kit("caster"), { long = true }) > R.Damage(robed, kit("melee"), { long = true }))
	local short = with(function(t) t.level = 30 end)
	local d, _, _, seconds = R.Damage(short, kit("melee"))
	check("a fight below the top level is short, and has a number", seconds < 60 and d > 0)
	near("a class that fights one way is as it was", R.Damage(shaman, { abilities = {}, heals = {}, seals = {}, at = {} }, { long = true }), white)
end

print("three ways, two of them in a form: the druid")
do
	-- (Josh 2026-11-18: "Start druid")
	local d = data.spells.DRUID
	local specs = data.specs.DRUID
	check("the druid fights three ways", specs.caster.caster == true and specs.cat.energy == true and specs.cat.form == "cat"
		and specs.bear.tank == true and specs.bear.form == "bear")
	check("Claw is a cat's, and builds a point", d[9850].spec == "cat" and d[9850].points == 1)
	check("Maul is a bear's, with its swing", d[9881].spec == "bear" and d[9881].swing == true and d[9881].cost == 15)
	check("Starfire is a caster's", d[25298].spec == "caster" and d[25298].spell == 7)
	check("Rip is a finishing move that bleeds for a set time", d[9896].finisher == true and d[9896].bleed == true and d[9896].secs == 12)
	local bite = Rd.Planned(d[31018].read, "Finishing move that causes damage per combo point and converts each extra point of energy "
		.. "into 2.1 additional damage.  Damage is increased by your Attack Power.\n   1 point  : 245-321 damage\n"
		.. "   2 points: 426-502 damage\n   3 points: 607-683 damage\n   4 points: 788-864 damage\n   5 points: 969-1,045 damage")
	check("Ferocious Bite's amounts are read, though they are plain words", bite and bite.p1 == 283 and bite.p5 == 1007)
	local rip = Rd.Planned(d[9896].read, "Finishing move that causes damage over time.  Damage increases per combo point and by your "
		.. "Attack Power:\n   1 point  : 174 damage over 12 sec.\n   2 points: 300 damage over 12 sec.\n"
		.. "   3 points: 426 damage over 12 sec.\n   4 points: 552 damage over 12 sec.\n   5 points: 678 damage over 12 sec.")
	check("and Rip's, for each count of points", rip and rip.r1 == 174 and rip.r5 == 678)
	check("Healing Touch is a heal", d[25297].is == "heal:healingTouch")
	check("Moonkin Form marks a caster, Shredding Attacks a cat", specs.caster.marks[24858] and next(specs.cat.marks) ~= nil)

	-- the forms, kept from when each was seen
	local db = {}
	local standing = { level = 60, attackPower = 200, crit = 8, armor = 1500, health = 3000, damageMin = 90, damageMax = 130, weaponSpeed = 3 }
	near("out of form, none is known yet", next(Rd.Forms(standing, db)) == nil and 1 or 0, 1)
	local asCat = { level = 60, form = "cat", attackPower = 520, crit = 14, armor = 1500, health = 3000,
		damageMin = 55 + 520 / 14, damageMax = 75 + 520 / 14, weaponSpeed = 1 }
	local seen = Rd.Forms(asCat, db)
	near("in Cat Form: the attack power it adds", seen.cat.ap, 320)
	near("its crit", seen.cat.crit, 6)
	near("and its paws, with attack power's share taken out", seen.cat.pawMin, 55)
	local asBear = { level = 60, form = "bear", attackPower = 420, crit = 10, armor = 6000, health = 4200,
		damageMin = 100 + 420 / 14 * 2.5, damageMax = 140 + 420 / 14 * 2.5, weaponSpeed = 2.5 }
	seen = Rd.Forms(asBear, db)
	near("in Bear Form: what armor is multiplied by", seen.bear.armor, 4)
	near("and the health it adds", seen.bear.health, 1200)
	check("a new level starts over", next(Rd.Forms({ level = 61, form = "cat", attackPower = 1, crit = 1, armor = 1, health = 1,
		damageMin = 1, damageMax = 2, weaponSpeed = 1 }, { forms = db.forms })) == nil)

	local druid = {
		level = 60, attackPower = 200, armor = 1500, crit = 8, health = 3000, mana = 4000, manaPer5 = 0, damageMin = 90, damageMax = 130,
		weaponSpeed = 3, haste = 0, dodge = 8, parry = 0, block = 0, blockValue = 0, hit = 0, spellHit = 0, spellCrit = 6, healing = 0,
		spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, forms = seen,
	}
	local function with(change)
		local t = {}
		for k, v in pairs(druid) do t[k] = v end
		t.spellDamage = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }
		change(t)
		return t
	end
	local cat = R.FormState(druid, "cat")
	near("as a cat: your attack power and what the form adds", cat.attackPower, 520)
	near("the paws' swing, not the weapon's", cat.damageMin, 55 + 520 / 14)
	near("at the cat's speed", cat.weaponSpeed, 1)
	local inCat = with(function(t) t.form, t.attackPower, t.crit = "cat", 520, 14 end)
	near("already in Cat Form: nothing is added twice", R.FormState(inCat, "cat").attackPower, 520)
	near("from Cat Form to a bear: the cat's share comes off first", R.FormState(inCat, "bear").attackPower, 420)
	near("a bear's armor", R.FormState(druid, "bear").armor, 6000)
	check("a form never seen cannot be worked out", R.FormState(with(function(t) t.forms = {} end), "cat") == nil)
	near("attack power for forms only, from a swap", R.FormState(with(function(t) t.feralGain = 70 end), "cat").attackPower, 590)

	local function kit(spec)
		return { specs = specs, spec = spec, heals = {}, seals = {}, at = { spell = 0, healing = 0, spells = { [4] = 0, [7] = 0 } },
			rage = { enrage = { amount = 20, every = 60 } }, abilities = {
				wrath = { v = { hit = 250 }, cost = 120, cast = 2, spell = 4, share = 0.571, spec = "caster" },
				claw = { v = { pct = 140, add = 115 }, cost = 45, weapon = "plain", points = 1, spec = "cat" },
				ferociousbite = { v = { p1 = 283, p2 = 464, p3 = 645, p4 = 826, p5 = 1007 }, cost = 35, finisher = true, spec = "cat" },
				maul = { v = { add = 128 }, cost = 15, swing = true, spec = "bear", threat = 100, tmult = 1 },
				swipe = { v = { cap = 3, hit = 83 }, cost = 20, aoe = true, spec = "bear" },
			} }
	end
	local asCaster = R.Damage(druid, kit("caster"), { long = true })
	local asCatDps = R.Damage(druid, kit("cat"), { long = true })
	check(("a caster's number and a cat's are different sums: %.1f and %.1f"):format(asCaster, asCatDps),
		asCaster > 0 and asCatDps > 0 and math.abs(asCaster - asCatDps) > 1)
	local staff = with(function(t) t.damageMin, t.damageMax = 300, 400 end)
	near("a better weapon is nothing to a cat", R.Damage(staff, kit("cat"), { long = true }), asCatDps)
	check("attack power is worth damage to a cat",
		R.Damage(with(function(t) t.attackPower = 300 end), kit("cat"), { long = true }) > asCatDps)
	near("and nothing to a caster", R.Damage(with(function(t) t.attackPower = 300 end), kit("caster"), { long = true }), asCaster)
	check("spell power is worth damage to a caster",
		R.Damage(with(function(t) t.spellDamage[4] = 200 end), kit("caster"), { long = true }) > asCaster)
	near("and nothing to a cat", R.Damage(with(function(t) t.spellDamage[4] = 200 end), kit("cat"), { long = true }), asCatDps)
	near("no way marked: the higher of caster and cat", R.Damage(druid, kit(nil), { long = true }), math.max(asCaster, asCatDps))
	local unseen = with(function(t) t.forms = {} end)
	near("a cat never seen in its form gives way to the caster", R.Damage(unseen, kit("cat"), { long = true }),
		R.Damage(unseen, kit("caster"), { long = true }))
	-- the bear is the tank's way
	local threat = R.Threat(druid, kit("cat"))
	local bear = R.FormState(druid, "bear")
	check(("threat is the bear's sum, whatever the DPS way: %.1f"):format(threat), threat > 0 and threat == R.Threat(druid, kit("caster")))
	check("the bear is never the DPS number", R.Damage(druid, kit("bear"), { long = true }) == math.max(asCaster, asCatDps))
	near("survival is as a bear", R.Survival(druid, kit("cat")), R.Survival(bear, { heals = {}, seals = {}, at = {} }))
	check("which is more than as you stand", R.Survival(druid, kit("cat")) > R.Survival(druid, { heals = {}, seals = {}, at = {} }))
end

print("an item's other effects")
do
	check("a trinket's Use, as stats for the time it is up", type(data.uses) == "table" and next(data.uses) ~= nil)
	check("items with an effect that is not counted are listed", type(data.partly) == "table" and next(data.partly) ~= nil)
	-- a made-up set: two pieces give 20 strength, three something that is no stat
	local sets = { sets = { [9] = { { 2, { ITEM_MOD_STRENGTH_SHORT = 20 } }, { 3, false } } }, setOf = { [101] = 9, [102] = 9, [103] = 9 } }
	local lost, gained, partly = Rd.SetChange(sets, { [9] = 1 }, 102, {})
	check("the second piece starts the bonus", gained.ITEM_MOD_STRENGTH_SHORT == 20 and next(lost) == nil and partly == false)
	lost, gained, partly = Rd.SetChange(sets, { [9] = 2 }, nil, { 101 })
	check("taking one off ends it", lost.ITEM_MOD_STRENGTH_SHORT == 20 and next(gained) == nil)
	lost, gained, partly = Rd.SetChange(sets, { [9] = 2 }, 103, {})
	check("a bonus that is not a stat is said, not priced", partly == true and next(gained) == nil)
	lost, gained, partly = Rd.SetChange(sets, { [9] = 2 }, 103, { 101 })
	check("one piece of the set for another changes nothing", next(lost) == nil and next(gained) == nil and partly == false)
	check("Defias Leather is a set the tables know", data.setOf[10399] == 161 and type(data.sets[161]) == "table")
end

if failed > 0 then
	print(failed .. " FAILED")
else
	print("ALL UPGRADES TESTS PASSED")
end
-- run on its own, it ends with its own answer; run from tests/run.lua, it
-- hands back how many failed
if ... == "from run.lua" then
	return failed
end
if failed > 0 then
	os.exit(1)
end
