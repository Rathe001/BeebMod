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
