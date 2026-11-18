-- WHAT YOUR TOTALS ARE WORTH: DPS, HEALING, SURVIVAL (Josh 2026-11-16).
--
-- No game calls in this file. It is handed totals (Math.lua's shape) and a
-- kit: what your spells do right now, read from the game by Read.lua. It
-- answers with one number per role. An item's tile is that number with the
-- item on, over that number as you stand, minus one.
--
-- EVERY STAT GETS ITS VALUE BY WHAT IT FEEDS (Josh: "I want to make sure we
-- collect all the subtle interactions"). Nothing here names intellect, yet
-- intellect counts for damage: it is spell crit, which Judgement uses, and
-- mana, which decides how many spells the fight can pay for.
--
-- TWO PROFILES A ROLE (Josh 2026-11-16: "there are different scenarios...
-- Single target vs AoE is the big one"): DPS on one enemy and on four,
-- healing without stopping and healing a fight's mana can pay for, physical
-- hits survived and threat.
--
-- FROM THE GAME: every amount in the kit (spell descriptions count your
-- spell power and talents), and each spell's share of spell power, from the
-- client's SpellEffect table (build 70888).
-- FROM THE GAME'S ExpectedStat TABLE: an enemy's armor and damage by level.
-- GUESSED, AND MARKED WHERE USED: Seal of Command's hits
-- per minute, which hits can crit, the fight's length, the share of a fight
-- a healer is not casting, Consecration's share of spell power.
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
local UP = BT.Upgrades

local R = {}
UP.Roles = R

R.FIGHT_SECONDS = 180
-- AN ENEMY'S ARMOR AND DAMAGE, FROM THE GAME'S OWN TABLE, LEVEL BY LEVEL
-- (Josh 2026-11-17, of two numbers fitted to his fights as so much a level:
-- "Keep in mind all those damage, health, armor, etc values will all scale
-- with level. Are we not able to examine the game files and use real
-- values?"). They are in the client: the ExpectedStat table (wago.tools,
-- product wowf, build 1.60.1) has, for each level, what a creature of that
-- level is expected to have. CreatureArmor and CreatureAutoAttackDps are
-- copied here for levels 1 to 70. Its ArmorConstant is 400 + 85 a level,
-- the same sum R.ArmorCut uses, which is how the table is known to be this
-- game's and in use.
--
-- Checked against 160 recorded fights (Fights.lua):
--   armor: a level 24 enemy has 1,002, which leaves a level 30's white hits
--     0.75 of their damage. The fights gave 0.71 to 0.79.
--   damage: a level 24 enemy does 20.05 a second before armor. Less the 16%
--     that missed or was dodged or parried, that is 16.8. 61 solo fights
--     against normal enemies of that level gave 16.6.
-- They do not rise evenly: armor is 41 a level at 24 and 59 a level at 60.
R.ENEMY_ARMOR = {
	20, 21, 46, 82, 126, 180, 245, 322, 412, 518,
	545, 580, 615, 650, 685, 721, 756, 791, 826, 861,
	897, 932, 967, 1002, 1037, 1072, 1108, 1142, 1177, 1212,
	1247, 1283, 1317, 1353, 1387, 1494, 1607, 1724, 1849, 1980,
	2117, 2262, 2414, 2574, 2742, 2798, 2853, 2907, 2963, 3018,
	3072, 3128, 3183, 3237, 3292, 3348, 3402, 3457, 3512, 3566,
	3622, 3677, 3731, 3786, 3840, 3895, 3950, 4005, 4059, 4113,
}
R.ENEMY_DPS = {
	0.77, 1.16, 1.63, 2.25, 3.01, 4.00, 5.18, 6.02, 6.91, 7.62,
	8.60, 9.84, 10.71, 11.81, 12.85, 13.59, 14.56, 15.25, 16.18, 17.10,
	17.75, 18.60, 19.23, 20.05, 20.83, 21.49, 22.35, 23.00, 23.82, 24.69,
	25.32, 26.08, 26.74, 27.51, 28.26, 28.94, 29.85, 30.63, 31.59, 32.59,
	34.14, 36.29, 38.71, 41.91, 43.99, 44.90, 46.02, 46.93, 48.03, 49.20,
	50.16, 51.39, 52.37, 53.56, 54.68, 55.76, 56.94, 58.03, 59.22, 60.45,
	61.53, 62.75, 63.86, 65.08, 66.34, 67.43, 68.72, 69.89, 71.22, 72.48,
}
-- and its health (CreatureHealth, the same table): how long a fight with
-- it lasts (R.FightSeconds)
R.ENEMY_HEALTH = {
	42, 55, 71, 86, 102, 120, 137, 156, 180, 208,
	239, 272, 307, 345, 385, 427, 473, 521, 572, 629,
	677, 731, 787, 846, 909, 975, 1040, 1109, 1177, 1242,
	1308, 1374, 1443, 1512, 1586, 1660, 1737, 1814, 1897, 1981,
	2061, 2146, 2231, 2317, 2402, 2495, 2587, 2681, 2779, 2909,
	3040, 3174, 3317, 3458, 3602, 3755, 3909, 4105, 4234, 4365,
	4496, 4629, 4763, 4453, 4581, 4711, 4846, 4984, 5123, 5265,
}
local function ofLevel(list, level)
	level = math.floor(tonumber(level) or 1)
	return list[math.max(1, math.min(#list, level))]
end
-- the armor of an enemy of `level`
function R.EnemyArmor(level)
	return ofLevel(R.ENEMY_ARMOR, level)
end
function R.EnemyHealth(level)
	return ofLevel(R.ENEMY_HEALTH, level)
end
-- AN ELITE HITS HARDER THAN THE TABLE'S ENEMY, and the tank's number is
-- about elites. How much harder is the server's and in no file. MEASURED:
-- 13 solo fights against elites of level 29 gave 25.1 a second before
-- armor, where the table's 23.8 less 16% avoided is 20.0. That is 1.25.
-- Dungeon elites are not measured: in a group the hits are not all on you.
-- (The table set gives dungeons a damage share of 1.2, ExpectedStatMod 489.
-- Whether an elite's own share comes on top of it is not known.)
R.ELITE_DAMAGE = 1.25
-- one hit every 2 seconds (GUESS: the meter gives totals, not hits)
R.ENEMY_SWING = 2
-- what an elite of `level` hits for, before your armor
function R.EnemyHit(level)
	return ofLevel(R.ENEMY_DPS, level) * R.ELITE_DAMAGE * R.ENEMY_SWING
end
-- an enemy of your level: 5% to miss you, 5% to crit you (classic's; the
-- character sheet's Defense tooltip speaks of both)
R.ENEMY_MISS, R.ENEMY_CRIT = 5, 5
-- and what it does against your swings (classic's, for an enemy of your level)
R.ENEMY_DODGE, R.ENEMY_PARRY = 5, 5
R.PER_DEFENSE = 0.04
-- Seal of Fury's absorb, as its description says: half the Holy damage
R.FURY_ABSORB = 0.5
R.STRENGTH_PER_BLOCK = 20
-- Classic's 7 hits a minute. The table gives no rate for the seal: its rows
-- (SpellAuraOptions, 20375) are classic's own, a chance of 100 once a second,
-- and classic kept the 7 on the server. 32 fights under the seal alone
-- (2026-11-17) give 6.1 to 7.0 a minute, depending on the enemy's armor.
R.COMMAND_PER_MINUTE = 7
R.SEAL_SECONDS = 30
-- HOW MANY ENEMIES "AOE" IS (Josh 2026-11-17: "AoE is fine at 4 enemies,
-- unless the skill/spell specifies otherwise. We should go with either the
-- max, or 4... whichever is higher"). Four, or as many as a spell of yours
-- says it reaches where that is more. A spell that reaches fewer still hits
-- only as many as it says.
R.AOE_ENEMIES = 4
function R.AoeEnemies(kit)
	local most = R.AOE_ENEMIES
	local c = kit and kit.consecration
	if c and type(c.cap) == "number" and c.cap > most then
		most = c.cap
	end
	for _, a in pairs(kit and kit.abilities or {}) do
		local cap = a.aoe and a.v and a.v.cap
		if type(cap) == "number" and cap > most then
			most = cap
		end
	end
	return most
end
-- crits: a melee crit doubles, a spell crit adds half
R.MELEE_CRIT = 1.0
R.SPELL_CRIT = 0.5

-- each spell's share of spell power (SpellEffect.EffectBonusCoefficient)
R.SHARE = {
	holyStrike = 0.429,
	commandHit = 0.29,
	commandJudge = 0.2145, -- half of 0.429 on a target that is not stunned
	righteousnessHit = 0.10,
	righteousnessJudge = 0.429,
	furyHit = 0.10,
	furyJudge = 0.429,
	-- GUESS: classic's share over the whole 8 seconds. The table has none on
	-- the spell, and 5 spell power moved its description by 2.
	consecration = 0.33,
}

-- the share of a physical hit that armor takes, as the character sheet
-- works it out (C_PaperDollInfo.GetArmorEffectiveness gave the same numbers)
function R.ArmorCut(armor, level)
	return armor / (armor + 400 + 85 * level)
end

local function clamp(v, low, high)
	return math.max(low, math.min(high, v))
end

-- MAGIC IN WHAT A TANK TAKES (Josh 2026-11-17: "We should consider resists
-- in the tanking stats so they aren't completely ignored"). The tank's
-- number was physical damage alone, so a resistance was worth nothing.
-- A JUDGEMENT, not the game's math: R.MAGIC_SHARE of what an enemy does is
-- taken to be magic, split evenly over the five schools that can be
-- resisted. Armor, dodge, parry and block do nothing against it. A
-- resistance takes off, on average, three quarters of its share of 5 a
-- level (classic's: 150 at level 30 is 75%, the most there is).
-- The share is of what the enemy does before anything is taken off. Armor
-- and avoidance take most of the physical part, so 5% of the whole is about
-- an eighth of what a tank ends up taking.
R.MAGIC_SHARE = 0.05
R.RESIST_MOST = 0.75
function R.Resisted(resist, level)
	return clamp((resist or 0) / (5 * math.max(1, level or 1)), 0, 1) * R.RESIST_MOST
end

-- TANK: the damage it takes to kill you
-- WITH A SHIELD, two more things take damage off, and both need to know how
-- hard the enemy hits (R.EnemyHit before armor, one hit every
-- R.ENEMY_SWING seconds):
--   block: your block chance, times the share of a hit your block value
--     covers
--   Seal of Fury: "each attack also grants an absorb shield equal to 50% of
--     the Holy damage dealt", so spell power is survival too (Josh
--     2026-11-16: "I want to make sure we collect all the subtle
--     interactions"). Counted when you know the seal: a tank is taken to
--     have it up.
function R.Survival(s, kit)
	-- (a tank's way that is fought in a form: as you would be in it)
	local _, tank = R.TankSpec(kit)
	if tank and tank.form then
		s = R.FormState(s, tank.form) or s
	end
	local cut = R.ArmorCut(s.armor, s.level)
	-- an enemy of your level misses 5% of the time, and crits 5% of the
	-- time for twice the damage. Each point of Defense over your level's
	-- own is 0.04% more of the first and less of the second (Math.lua,
	-- M.PER_DEFENSE; your dodge, parry and block have their share already).
	local defense = math.max(0, s.defense or 0) * R.PER_DEFENSE
	local avoided = clamp((s.dodge + s.parry + R.ENEMY_MISS + defense) / 100, 0, 0.9)
	local crits = 1 + clamp(R.ENEMY_CRIT - defense, 0, R.ENEMY_CRIT) / 100
	-- the share of an enemy's physical damage that costs you health
	local physical = (1 - cut) * (1 - avoided) * crits
	local landed = R.EnemyHit(s.level) * (1 - cut)
	local taken = landed * (1 - avoided) * crits / R.ENEMY_SWING
	-- HEALTH PER 5 SECONDS FROM GEAR (Josh 2026-11-16, of Sustaining Ring:
	-- "Is health per 5 seconds included in our tank calculations?"). It
	-- comes back all through a fight, so it is counted as the share of the
	-- damage taken that it gives back. No shield needed.
	local back = clamp((s.healthPer5 or 0) / 5 / taken, 0, 0.5)
	physical = physical * (1 - back)
	-- and of its magic, by school (see MAGIC IN WHAT A TANK TAKES)
	local magic = 0
	for school = 2, 6 do
		magic = magic + (1 - R.Resisted(s.resist and s.resist[school], s.level)) / 5
	end
	local function life(share)
		return s.health / ((1 - R.MAGIC_SHARE) * share + R.MAGIC_SHARE * magic)
	end
	if not s.shield then
		return life(physical)
	end
	local blocked = clamp((s.block or 0) / 100, 0, 1) * clamp((s.blockValue or 0) / landed, 0, 1)
	local absorbed = 0
	local fury = kit and kit.seals and kit.seals.fury
	if fury then
		local hit = 1 - math.max(0, 5 - s.hit) / 100
		local swings = hit * (1 + s.haste / 100) / s.weaponSpeed
		local each = fury.hit + R.SHARE.furyHit * (s.spellDamage[2] - kit.at.spell)
		absorbed = clamp(swings * each * R.FURY_ABSORB / taken, 0, 0.5)
	end
	return life(physical * (1 - blocked) * (1 - absorbed))
end

-- A HEAL'S CRITS, WITH TALENTS (Josh 2026-11-18: "Let's finish the paladin
-- stuff"). A heal crit adds half. A talent can raise one heal's chance
-- (`critAdd`, Improved Flash of Light) or what a crit adds (`critMore`, Holy
-- Power), and Read.lua puts those on the heal. Returns what the heal's
-- amount is multiplied by, and its chance to crit.
local function healCrits(s, h)
	local chance = clamp((s.spellCrit + (h.critAdd or 0)) / 100, 0, 1)
	return 1 + R.SPELL_CRIT * (1 + (h.critMore or 0) / 100) * chance, chance
end
-- What a heal costs, with the mana a crit gives back (`kit.back`, the share
-- of the cost: Illumination). So crit is worth mana to a healer who has it.
local function healCost(kit, h, chance)
	return math.max(h.cost or 0, 0) * (1 - clamp((kit.back or 0) * chance, 0, 0.9))
end

-- HEALER: healing per second from the heal that gives the most
function R.Healing(s, kit)
	local best, name = 0, nil
	local more = s.healing - kit.at.healing
	for _, h in ipairs(kit.heals or {}) do
		local amount = (h.amount + h.share * more) * healCrits(s, h)
		local per = amount / math.max(h.cast, 1.5)
		if per > best then
			best, name = per, h.name
		end
	end
	return best, name
end

-- HEALER, SUSTAIN (Josh 2026-11-16: "mana sustain is also pretty important to
-- consider, otherwise we won't value spirit at all... throughput vs
-- sustain"): all the healing a fight's mana can buy with the heal that gives
-- the most per mana. The mana is your pool, what comes back while casting,
-- and spirit's share for the part of the fight you are not casting.
-- GUESS: a fifth of the fight is spent not casting.
R.NOT_CASTING = 0.2
function R.Sustain(s, kit)
	local more = s.healing - kit.at.healing
	local best = 0
	for _, h in ipairs(kit.heals or {}) do
		if h.cost > 0 then
			local by, chance = healCrits(s, h)
			local per = (h.amount + h.share * more) * by / healCost(kit, h, chance)
			best = math.max(best, per)
		end
	end
	local mana = s.mana + R.FIGHT_SECONDS * (s.manaPer5 / 5 + R.NOT_CASTING * (s.spiritRegen or 0))
	-- and no more than there is time to cast
	local time = R.Healing(s, kit) * R.FIGHT_SECONDS * (1 - R.NOT_CASTING)
	return math.min(best * mana, time)
end

-- HEALER, ONE FIGHT: the most healing a fight allows, with two limits at
-- once: the time there is to cast, and the mana there is to spend.
-- (Josh 2026-11-16, of a mace with +68 healing that read +30.2% on its tile,
-- "sustain +30.2%" and "output +14.1%" under it: "Feels like the number
-- should be in between those 2".) The tile was R.Sustain, which spends all
-- the mana on the cheapest heal and so priced the mace as if only Flash of
-- Light were ever cast. A real fight mixes the cheap heal with the big one:
-- as many big ones as the mana allows, the cheap one for the rest of the
-- time. That mix is worked out here. With two limits the best plan is one
-- heal alone, or the two heals that use up both limits exactly, so each
-- heal and each pair is tried and the best kept.
function R.FightHealing(s, kit)
	local more = s.healing - kit.at.healing
	local time = R.FIGHT_SECONDS * (1 - R.NOT_CASTING)
	local mana = s.mana + R.FIGHT_SECONDS * (s.manaPer5 / 5 + R.NOT_CASTING * (s.spiritRegen or 0))
	local heals = {}
	for _, h in ipairs(kit.heals or {}) do
		local by, chance = healCrits(s, h)
		heals[#heals + 1] = {
			amount = (h.amount + h.share * more) * by,
			cast = math.max(h.cast, 1.5), cost = healCost(kit, h, chance),
		}
	end
	local best = 0
	for i, a in ipairs(heals) do
		-- this heal alone, until the time or the mana is gone
		local casts = time / a.cast
		if a.cost > 0 then
			casts = math.min(casts, mana / a.cost)
		end
		best = math.max(best, casts * a.amount)
		-- with another, so that both the time and the mana are used up
		for j = i + 1, #heals do
			local b = heals[j]
			local det = a.cast * b.cost - b.cast * a.cost
			if det ~= 0 then
				local x = (time * b.cost - b.cast * mana) / det
				local y = (a.cast * mana - time * a.cost) / det
				if x >= 0 and y >= 0 then
					best = math.max(best, x * a.amount + y * b.amount)
				end
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- A CLASS PRICED BY ITS ABILITIES (Josh 2026-11-17: "move on to the other
-- classes", and of the first: "Warrior sounds good to start")
-- ---------------------------------------------------------------------------
--
-- The paladin's sums below were written spell by spell. A class after it is
-- priced by one sum over a list of its abilities (kit.abilities, from
-- SpellData.lua by way of Read.lua): what each does, what it costs, how
-- often it can be used. The sum spends what the fight gives, a second of
-- time and so much of the class's resource, on whichever ability gives the
-- most for its cost, then the next, until one of the two runs out.
--
-- THE WARRIOR'S RAGE is the one thing here that is in no game file. The
-- original game's rule is used, and Forever's may differ:
--   a hit you land gives its damage x 7.5 over a number for your level
--   a hit you take gives its damage x 2.5 over the same number
--   that number is 0.0091 x level squared + 3.2256 x level + 4.2653
-- What an enemy does to you is the game's table (R.ENEMY_DPS): a normal
-- enemy while you level alone, an elite for a tank, nothing in a long
-- fight where someone else is hit.
-- A weapon's damage "evened out" for an ability is its own damage plus your
-- attack power at a set speed, 3.3 for a two-hander and 2.4 for a one-hand
-- weapon (the original game's).
R.RAGE = { hit = 7.5, taken = 2.5 }
R.RAGE_TAKEN = 0.6
function R.RageFactor(level)
	return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911
end
R.GLOBAL = 1.5
R.EVEN_SPEED = { twoHand = 3.3, oneHand = 2.4, dagger = 1.7 }

-- THE ROGUE (Josh 2026-11-18: "Commit, then start on rogue"). The same sum
-- again. None of these is in a game file; they are the original game's:
--   energy comes at 20 every 2 seconds, whatever you wear (R.ENERGY)
--   an ability is followed by 1 second before the next (R.ENERGY_GLOBAL)
--   a dagger's damage is evened out for an ability at a speed of 1.7
--   a swing with a weapon in each hand misses 19% more (R.DUAL_MISS)
--   an off-hand weapon hits for half (R.OFF_HAND)
-- COMBO POINTS. A finishing move is priced with the abilities that build
-- its points: the one that gives the most for its energy, used as many
-- times as the finisher takes points, then the finisher. Every count of
-- points from 1 to 5 is tried and the one that gives the most for its
-- energy is kept. Slice and Dice is worth its percent of your swings for as
-- long as it lasts, and Rupture its total. Neither can be on twice at once.
-- An ability that needs you behind the enemy is left out of a fight alone,
-- where the enemy faces you. One that needs stealth is used once a fight.
-- Not counted: poisons, and a point a talent gives on a crit.
-- THE HUNTER (Josh 2026-11-18: "Commit and work on hunter"). The same sum,
-- with mana as a caster has it. Its Auto Shot is what swings are to the
-- others: the ranged weapon's damage, speed, crit and hit, as the game
-- shows them. A shot's weapon damage is the ranged weapon's. No shot is
-- dodged or parried. A shot that is magic (Arcane Shot) lands and crits as
-- a shot does, and armor takes none of it.
-- THE PET is counted as it is, from its own sheet, and no gear of yours
-- moves it. It is there so a change is a share of all your damage.
-- Not counted: a cast shot holding back the Auto Shot, and the hunter's
-- melee.
R.ENERGY = 10
R.ENERGY_GLOBAL = 1
R.DUAL_MISS = 19
R.OFF_HAND = 0.5
-- A state's off hand set to a weapon ({ min, max, speed }, as its tooltip
-- says), or to none (false)
function R.OffHand(s, weapon)
	if not weapon then
		s.dual, s.offMin, s.offMax, s.offSpeed, s.offAp = false, nil, nil, nil, nil
		return
	end
	local power = s.attackPower / 14 * weapon.speed
	s.dual = true
	s.offMin, s.offMax = (weapon.min + power) * R.OFF_HAND, (weapon.max + power) * R.OFF_HAND
	s.offSpeed, s.offAp = weapon.speed, s.attackPower
end
-- (a tank's stance: every point of threat counts this much. It moves no
-- comparison; it is here so the number is the game's.)
R.STANCE_THREAT = 1.3

-- A CASTER (Josh 2026-11-17: "We could do mage next ... I'd rather use
-- numbers from the game data"). The same sum, with three things changed.
-- Mana is what is spent: the mana you start with, over the fight, and what
-- comes back while you cast. Time is spent by casting: a spell takes its
-- cast time, a channelled one as long as it lasts, and never less than the
-- 1.5 seconds between spells. There are no swings: a wand is not counted.
-- A spell's damage is what its description says now, moved by its share of
-- any spell power gained or lost since (the tables' share). Its hit can
-- crit and what it does over time cannot. Damage over time that trails a
-- hit (Fireball's burn) starts over when the spell is cast again, so only
-- the part that runs before the next cast is counted.
-- The spells are tried in two orders, the most damage for its mana first
-- and the most for its time first, and the better sum is kept. A short
-- fight is short of time and a long one of mana.
-- EVOCATION is used once in a fight of a minute or more (R.EVOCATION_FROM,
-- an estimate; its cooldown is longer than any fight here). It gives the
-- mana its words say, your spirit's regeneration raised by its percent for
-- as long as it lasts, and that time is not spent casting.
R.EVOCATION_FROM = 60
-- THE WARLOCK (Josh 2026-11-18: "Ok, next class?"). A caster with a pet,
-- which is counted as the hunter's is. LIFE TAP gives mana for a cast of
-- its own, so a warlock is not short of mana, only of time. The sum is
-- done a second way for one that knows it: mana is free, and each spell
-- takes its own time and the time to tap its cost back. The better of the
-- two is kept, so a short fight on a full bar is not charged for tapping.
-- The health Life Tap takes is not counted.

-- WHAT CRITS ADD TO AN ABILITY (Josh 2026-11-18, of talents: "Let's do the
-- crit"). A crit adds a set part of the hit, as much again for a swing and
-- half for a spell. A talent can change that for some abilities, and the
-- game's totals do not show it, so Read.lua puts it on each ability from
-- the tables' list (SpellData.talents):
--   critAdd    percent more chance to crit (Critical Mass)
--   critMore   percent more of what a crit adds (Ice Shards, Impale)
--   critAfter  percent of a crit's whole damage dealt again (Ignite)
-- Returns what the ability's damage is multiplied by, crits counted.
local function crits(a, adds, chance)
	chance = clamp(chance + (a.critAdd or 0) / 100, 0, 1)
	local each = (1 + adds * (1 + (a.critMore or 0) / 100)) * (1 + (a.critAfter or 0) / 100) - 1
	return 1 + each * chance
end

-- ON YOUR WEAPONS: A POISON, OR A SHAMAN'S IMBUE (Josh 2026-11-18, of what
-- was left: "proceed"). `s.imbue`: what is on the main hand and the off
-- hand, from the tables' list by way of Read.lua. Each adds to your swings'
-- damage, and each follows the weapon: a fast one lands a poison more
-- often, a slow one swings harder under Windfury. Returns damage a second.
--   hit       a chance on each hit to do so much. Magic: armor takes none.
--   dot       a chance on each hit for damage over time that stacks. How
--             many stacks are up is an estimate, as Vengeance's is: your
--             hits that put it on, times how long it lasts, levelling off
--             at the most there can be.
--   windfury  a chance on each hit for extra swings with more attack power,
--             and not more than once in 3 seconds (R.WINDFURY_EVERY, the
--             original game's; no game file has it). Main hand only.
--   flame     damage on every hit, by the weapon's speed
-- `rates`: the swings that land a second, main and off. Not counted: an
-- ability's hit landing a poison, and spell power on any of these.
R.WINDFURY_EVERY = 3
R.FLAME_SPEED = { low = 1.3, high = 4.0 }
function R.Imbued(s, rates, average, crit, through, hit)
	local im = s.imbue
	if type(im) ~= "table" then
		return 0
	end
	local sum = 0
	for _, name in ipairs({ "main", "off" }) do
		local e, rate = im[name], rates[name] or 0
		if type(e) == "table" and rate > 0 then
			local chance = (e.chance or 100) / 100
			if e.kind == "hit" then
				sum = sum + rate * chance * (e.hit or 0)
			elseif e.kind == "dot" and (e.period or 0) > 0 then
				local most = math.max(1, e.stacks or 1)
				sum = sum + most * (1 - math.exp(-rate * chance * (e.secs or 0) / most)) * (e.tick or 0) / e.period
			elseif e.kind == "windfury" and name == "main" then
				local procs = math.min(rate * chance, 1 / R.WINDFURY_EVERY)
				sum = sum + procs * (e.attacks or 1) * (average + (e.ap or 0) / 14 * s.weaponSpeed)
					* (1 + R.MELEE_CRIT * crit) * through * hit
			elseif e.kind == "flame" then
				local speed = name == "main" and s.weaponSpeed or s.offSpeed or 0
				local t = clamp((speed - R.FLAME_SPEED.low) / (R.FLAME_SPEED.high - R.FLAME_SPEED.low), 0, 1)
				sum = sum + rate * ((e.low or 0) + ((e.high or 0) - (e.low or 0)) * t)
			end
		end
	end
	return sum
end

-- A CLASS THAT FIGHTS MORE THAN ONE WAY (Josh 2026-11-18: "the player could
-- either have a melee spec or caster. We need to determine which one by
-- which talents they have selected. The rotation formula will be completely
-- different based on that."). `kit.specs` lists the ways, each with how it
-- is priced; `kit.spec` is the one your talents mark (Read.lua, Rd.Spec),
-- or nil where they mark none. An ability marked for one way is used in
-- that way only. With a way marked, the sum is done for it. With none, it
-- is done for each and the higher kept: a shaman with a two-hander and
-- strength comes out melee, one with spell power a caster.
-- THE TANK'S WAY (the druid's bear) is for threat and survival and is never
-- the DPS number. Threat is its sum where a class has one.
-- A WAY FOUGHT IN A FORM (cat, bear) has stats that are not yours as you
-- stand: its attack power, crit, armor and health, and its paws for a
-- weapon. The game says them only while you are in the form, so they are
-- kept from then (Read.lua) as what the form adds, and put on here
-- (R.FormState). A form never seen cannot be priced. A way your talents
-- mark that cannot be priced gives way to the others.
function R.TankSpec(kit)
	for name, spec in pairs(kit and kit.specs or {}) do
		if spec.tank then
			return name, spec
		end
	end
	return nil
end
-- `s` as it would be in a form. `s.forms[form]`: what the form adds (ap,
-- crit, health), what it multiplies armor by, and its paws (pawMin, pawMax,
-- speed). `s.form`: the form you stand in, whose own share is taken off
-- first. `s.feralGain`: attack power a swap adds in forms only. Nil where
-- the form has not been seen.
function R.FormState(s, form)
	if s.formed == form then
		return s
	end
	local f = s.forms and s.forms[form]
	if not f then
		return nil
	end
	local from = s.form and s.forms[s.form] or nil
	local t = {}
	for k, v in pairs(s) do
		t[k] = v
	end
	t.attackPower = s.attackPower - (from and from.ap or 0) + (f.ap or 0) + (s.feralGain or 0)
	t.crit = s.crit - (from and from.crit or 0) + (f.crit or 0)
	t.armor = s.armor / (from and from.armor or 1) * (f.armor or 1)
	t.health = s.health - (from and from.health or 0) + (f.health or 0)
	t.weaponSpeed = f.speed
	t.damageMin = f.pawMin + t.attackPower / 14 * f.speed
	t.damageMax = f.pawMax + t.attackPower / 14 * f.speed
	t.dual, t.offSpeed, t.twoHand, t.dagger, t.shield, t.proc = false, nil, false, false, false, nil
	t.imbue = nil
	t.formed = form
	return t
end

local function abilities(s, kit, how, seconds)
	how = how or {}
	seconds = seconds or R.FIGHT_SECONDS
	if kit.specs and not how.spec then
		local tank = R.TankSpec(kit)
		local function among(only)
			local best = nil
			for name, spec in pairs(kit.specs) do
				local use
				if how.threat and tank then
					use = name == tank
				else
					use = not spec.tank and (not only or only == name)
				end
				if use then
					local one = {}
					for k, v in pairs(how) do
						one[k] = v
					end
					one.spec = name
					local sum = abilities(s, kit, one, seconds)
					if not best or sum > best then
						best = sum
					end
				end
			end
			return best or 0
		end
		local marked = kit.spec and kit.specs[kit.spec] and not kit.specs[kit.spec].tank and kit.spec or nil
		local best = among(marked)
		if best <= 0 and marked then
			best = among(nil)
		end
		return best
	end
	-- (how it is priced: the way's own facts, or the kit's)
	local mode = how.spec and kit.specs and kit.specs[how.spec] or kit
	if mode.form then
		s = R.FormState(s, mode.form)
		if not s then
			return 0
		end
	end
	local enemies = how.enemies or 1
	local crit = s.crit / 100
	local turned = clamp(R.ENEMY_DODGE - (s.expertise or 0), 0, R.ENEMY_DODGE)
	local dodged = turned / 100
	if how.front then
		turned = turned + clamp(R.ENEMY_PARRY - (s.expertise or 0), 0, R.ENEMY_PARRY)
	end
	local hit = 1 - math.max(0, 5 - s.hit) / 100 - turned / 100
	-- (a swing, not an ability, with a weapon in each hand)
	local swingHit = 1 - math.max(0, 5 + (s.dual and R.DUAL_MISS or 0) - s.hit) / 100 - turned / 100
	local through = 1 - R.ArmorCut(R.EnemyArmor(s.level), s.level)
	local swing = s.weaponSpeed / (1 + s.haste / 100)
	local average = (s.damageMin + s.damageMax) / 2
	local swings = swing > 0 and swingHit / swing or 0
	-- one swing that lands
	local landed = average * (1 + R.MELEE_CRIT * crit) * through
	local white = landed * swings
	-- and the off hand's swings: its damage as the game showed it, moved by
	-- half of any attack power gained since
	local offSwings = 0
	if s.dual and (s.offSpeed or 0) > 0 then
		local off = ((s.offMin or 0) + (s.offMax or 0)) / 2
			+ (s.attackPower - (s.offAp or s.attackPower)) / 14 * s.offSpeed * R.OFF_HAND
		offSwings = swingHit / (s.offSpeed / (1 + s.haste / 100))
		white = white + math.max(0, off) * (1 + R.MELEE_CRIT * crit) * through * offSwings
	end
	if s.proc then
		white = white + s.proc.damage * s.proc.perMinute / 60 * (s.proc.magic and 1 or through)
	end
	-- what is on your weapons (see ON YOUR WEAPONS)
	white = white + R.Imbued(s, { main = swings, off = offSwings }, average, crit, through, hit)
	-- a ranged class: its shots in place of all of that, and its pet
	if mode.ranged then
		local speed = s.rangedSpeed or 0
		average = ((s.rangedMin or 0) + (s.rangedMax or 0)) / 2
		crit = (s.rangedCrit or s.crit) / 100
		hit = 1 - math.max(0, 5 - (s.rangedHit or s.hit)) / 100
		swings = speed > 0 and hit / speed or 0
		landed = average * (1 + R.MELEE_CRIT * crit) * through
		white = landed * swings + (s.petDps or 0) * through
	end
	-- the weapon as an ability evens it out
	local own = average - s.attackPower / 14 * s.weaponSpeed
	local even = own + s.attackPower / 14
		* (s.dagger and R.EVEN_SPEED.dagger or s.twoHand and R.EVEN_SPEED.twoHand or R.EVEN_SPEED.oneHand)
	local global = mode.energy and R.ENERGY_GLOBAL or R.GLOBAL
	-- (a swap that changes the kind of weapon held, with a weapon
	-- specialization: Math.lua. Weapon damage has its lift in it already;
	-- this is for the amounts a description gives.)
	local lifted = s.liftPhysical or 1

	-- what the fight gives a second: rage from the hits landed and taken,
	-- and from what gives it outright
	local per = R.RageFactor(s.level)
	-- What gets through to you is a set part of the enemy's damage, the same
	-- whatever you wear (R.RAGE_TAKEN, an estimate). Your own armor and
	-- avoidance are left out on purpose. With them in, every piece of armor
	-- took a little rage away and showed as a DPS loss (Josh 2026-11-18, a
	-- shield on a level 1 warrior at -0.1%: "everything should be a gain").
	local hurt = 0
	if how.threat then
		hurt = R.EnemyHit(s.level) / R.ENEMY_SWING * R.RAGE_TAKEN
	elseif seconds < R.FIGHT_SECONDS then
		-- (each of the enemies you fight alone is hitting you)
		hurt = R.ENEMY_DPS[math.max(1, math.min(#R.ENEMY_DPS, math.floor(s.level)))] * R.RAGE_TAKEN * enemies
	end
	local free = 1
	local rage = white * R.RAGE.hit / per + hurt * R.RAGE.taken / per
	for _, r in pairs(kit.rage or {}) do
		local times = r.every and math.max(1, seconds / r.every) or 1
		rage = rage + (r.amount or 0) * times / seconds
	end
	if mode.energy then
		rage = R.ENERGY
	end
	if mode.caster then
		-- (no swings, and a pet's own damage where the class has one)
		white = kit.pet and (s.petDps or 0) * through or 0
	end
	if mode.caster or mode.mana then
		rage = s.mana / seconds + s.manaPer5 / 5
		local evo = kit.evocation
		if evo and seconds >= R.EVOCATION_FROM and (evo.secs or 0) > 0 then
			rage = rage + (s.spiritRegen or 0) * (1 + (evo.pct or 0) / 100) * evo.secs / seconds
			free = 1 - evo.secs / seconds
		end
	end
	local lands = 1 - math.max(1, 4 - (s.spellHit or 0)) / 100
	local spellCrit = (s.spellCrit or 0) / 100
	local was = kit.at and kit.at.spells
	local function power(from, a)
		return math.max(from[a.spell] or 0, a.spell2 and from[a.spell2] or 0)
	end
	-- (a school's own crit, where it is above the one the state carries:
	-- as much above it now as when the spells were read)
	local critsWere, critWas = kit.at and kit.at.crits, kit.at and kit.at.crit
	local function schoolCrit(a)
		if not (critsWere and critWas) then
			return spellCrit
		end
		local own = math.max(critsWere[a.spell] or critWas, a.spell2 and critsWere[a.spell2] or critWas)
		return spellCrit + (own - critWas) / 100
	end

	local list, finishers = {}, {}
	for _, a in pairs(kit.abilities or {}) do
		local v = a.v or {}
		local usable = not (a.tank and not how.threat) and not (a.shield and not s.shield) and not (a.twohand and not s.twoHand)
			and not (a.dagger and not s.dagger) and not (a.behind and seconds < R.FIGHT_SECONDS)
			and not (a.spec and how.spec and a.spec ~= how.spec)
		if usable and a.finisher then
			finishers[#finishers + 1] = a
		elseif usable then
			local gain, cost, most, takes = 0, a.cost or 0, 0, 0
			if a.spell then
				local more = was and power(s.spellDamage, a) - power(was, a) or 0
				local secs = a.secs or 0
				takes = a.channel and secs > 0 and secs or math.max(R.GLOBAL, a.cast or 0)
				local every = math.max(a.cooldown or 0, takes)
				-- (damage over time and nothing else: once each time it runs out)
				if a.lasts and secs > 0 then
					every = math.max(every, secs)
				end
				-- (a shot: it lands and crits as a shot does)
				local chance, adds, land = schoolCrit(a), R.SPELL_CRIT, lands
				if mode.ranged then
					chance, adds, land = crit, R.MELEE_CRIT, hit
				end
				local direct = (v.hit or 0) + (a.share or 0) * more
				local over = (v.dot or 0) + (v.tick or 0) * secs / (a.period or 1) + (a.dshare or 0) * more
				if a.over and secs > 0 then
					over = over * math.min(1, every / secs)
				end
				local reach = a.aoe and math.min(enemies, v.cap or enemies) or 1
				gain = (math.max(0, direct) * crits(a, adds, chance) + math.max(0, over)) * land * reach
				most = 1 / every
			elseif a.swing then
				-- with your next swing, in place of it: what it adds, and the
				-- rage the plain swing would have given is lost
				gain = (v.add or 0) * lifted * crits(a, R.MELEE_CRIT, crit) * through
				if a.also and enemies >= 2 then
					gain = gain + (average + (v.add or 0) * lifted) * crits(a, R.MELEE_CRIT, crit) * through
				end
				cost = cost + landed * R.RAGE.hit / per
				most = swings
			elseif a.dot then
				-- over time, said as a total: once each time it runs out.
				-- A bleed, so armor takes none.
				gain = (v.dot or 0) * lifted * hit
				most = (a.secs and a.secs > 0) and 1 / a.secs or 0
				takes = global
			else
				-- (a percent of the weapon's damage, where its words give one)
				local part = ((s.dagger and v.pctdagger) or v.pct or 100) / 100
				local amount = (a.weapon == "norm" and even or a.weapon == "plain" and average or 0) * part
					+ ((v.add or 0) + (v.hit or 0) + (v.appct or 0) / 100 * s.attackPower
						+ (a.blockvalue and (s.blockValue or 0) or 0)) * lifted
				local reach = a.aoe and math.min(enemies, v.cap or enemies) or 1
				gain = amount * crits(a, R.MELEE_CRIT, crit) * through * hit * reach
				-- (and a bleed behind the hit: armor takes none, and it is
				-- used once each time it runs out)
				if v.dot then
					gain = gain + v.dot * hit
				end
				takes = math.max(global, a.cast or 0)
				most = 1 / math.max(a.cooldown or 0, takes)
				if a.after == "dodge" then
					-- only after the enemy dodges a swing of yours
					most = math.min(most, dodged / swing)
				elseif a.after == "avoid" then
					-- only after you block, dodge or parry a swing of its
					most = math.min(most, clamp((s.dodge + s.parry + (s.shield and s.block or 0)) / 100, 0, 1) / R.ENEMY_SWING)
				end
				if a.part then
					most = most * a.part
				end
				if a.lasts and (a.secs or 0) > 0 then
					most = math.min(most, 1 / a.secs)
				end
			end
			if how.threat then
				gain = (gain + (a.threat or 0) * hit) * (a.tmult or 1)
			end
			-- (out of stealth: once a fight)
			if a.opener then
				most = math.min(most, 1 / seconds)
			end
			if gain > 0 and most > 0 then
				list[#list + 1] = { gain = gain, cost = cost, most = most, takes = takes,
					builds = a.points and not a.opener and (a.cooldown or 0) <= takes and not a.dot and not a.lasts }
			end
		end
	end
	-- a finishing move, with what builds its points (see THE ROGUE, above)
	local builder = nil
	for _, one in ipairs(list) do
		if one.builds and one.cost > 0 and (not builder or one.gain / one.cost > builder.gain / builder.cost) then
			builder = one
		end
	end
	for _, f in ipairs(builder and finishers or {}) do
		local v = f.v or {}
		local best = nil
		for n = 1, 5 do
			local gain, cap = 0, nil
			-- (how long it lasts at this many points, or however many: Rip)
			local lasts = v["t" .. n] or f.secs
			if f.speed then
				if lasts and lasts > 0 then
					gain, cap = white * (v.pct or 0) / 100 * lasts, 1 / lasts
				end
			elseif f.bleed then
				if v["r" .. n] and lasts and lasts > 0 then
					gain, cap = v["r" .. n] * hit, 1 / lasts
				end
			elseif v["p" .. n] then
				gain = v["p" .. n] * crits(f, R.MELEE_CRIT, crit) * through * hit
			end
			if gain > 0 then
				local takes = (n + 1) * global
				local one = { gain = n * builder.gain + gain, cost = n * builder.cost + (f.cost or 0), takes = takes,
					most = math.min(cap or math.huge, 1 / takes) }
				if not best or one.gain / one.cost > best.gain / best.cost then
					best = one
				end
			end
		end
		list[#list + 1] = best
	end
	-- (`tapped`: mana is free, and a spell takes the time to tap its cost back)
	local tap = kit.lifetap and (kit.lifetap.mana or 0) > 0 and kit.lifetap.mana or nil
	for _, a in ipairs(list) do
		a.tapped = a.takes + (tap and a.cost / tap * R.GLOBAL or 0)
	end
	local function spend(tapping)
		local sum, left, time = white, rage, free
		for _, a in ipairs(list) do
			local uses = a.most
			local takes = tapping and a.tapped or a.takes
			if a.cost > 0 and not tapping then
				uses = math.min(uses, left / a.cost)
			end
			if takes > 0 then
				uses = math.min(uses, time / takes)
			end
			uses = math.max(0, uses)
			sum = sum + uses * a.gain
			left = left - uses * a.cost
			time = time - uses * takes
		end
		return sum
	end
	local function order(by)
		table.sort(list, function(a, b)
			local ea, eb = a[by] > 0 and a.gain / a[by] or math.huge, b[by] > 0 and b.gain / b[by] or math.huge
			if ea ~= eb then
				return ea > eb
			end
			return a.gain > b.gain
		end)
	end
	-- the most for its rage or mana first; one that costs none before any
	order("cost")
	local sum = spend()
	if mode.caster then
		-- and the most for its time first: the better of the two
		order("takes")
		sum = math.max(sum, spend())
	end
	if tap then
		order("tapped")
		sum = math.max(sum, spend(true))
	end
	if how.threat then
		sum = sum * R.STANCE_THREAT
	end
	return sum
end

-- DAMAGE, AND THE SEAL THAT GIVES IT. `how` (all optional):
--   enemies: how many stand in Consecration (1)
--   white, holy: what a point of each kind of damage counts for (1 and 1).
--     Threat is damage with Righteous Fury's weights.
-- White hits are physical. Everything else a paladin does here is Holy.
-- `seconds`: how long the fight is (R.FightSeconds)
local function damage(s, kit, how, crusader, seconds)
	how = how or {}
	seconds = seconds or R.FIGHT_SECONDS
	-- (a class priced by its abilities: the sum above)
	if kit.abilities then
		return abilities(s, kit, how, seconds), nil
	end
	local enemies, forWhite, forHoly = how.enemies or 1, how.white or 1, how.holy or 1
	local holy = s.spellDamage[2]
	-- Judgement of the Crusader on the enemy is spell power for Holy damage
	-- done to it (see R.Damage)
	local debuff = crusader and crusader.holy or 0
	local more = holy - kit.at.spell + debuff
	local crit, spellCrit = s.crit / 100, s.spellCrit / 100
	-- (a swap that changes the kind of weapon held, with a talent that lifts
	-- Holy damage for one kind: Math.lua, A WEAPON SPECIALIZATION. Weapon
	-- damage has its lift in it already.)
	local lifted = s.liftHoly or 1
	-- EXPERTISE (Josh 2026-11-17: "Expertise should have a value for dps and
	-- tank threat"). An enemy of your level dodges 5% of your swings, and
	-- parries 5% of those from the front, which is where a tank stands. A
	-- swing dodged or parried was not in the sums at all, so expertise had
	-- nothing to take off. Each percent of it takes one off each.
	local turned = clamp(R.ENEMY_DODGE - (s.expertise or 0), 0, R.ENEMY_DODGE)
	if how.front then
		turned = turned + clamp(R.ENEMY_PARRY - (s.expertise or 0), 0, R.ENEMY_PARRY)
	end
	local hit = 1 - math.max(0, 5 - s.hit) / 100 - turned / 100
	local spellHit = 1 - math.max(1, 4 - s.spellHit) / 100
	local through = 1 - R.ArmorCut(R.EnemyArmor(s.level), s.level)
	local swing = s.weaponSpeed / (1 + s.haste / 100)
	local average = (s.damageMin + s.damageMax) / 2
	local swings = swing > 0 and hit / swing or 0

	-- white hits cost nothing
	local white = average * (1 + R.MELEE_CRIT * crit) * hit * through / swing
	-- nor does the weapon's chance on hit: its damage, as often as your own
	-- fights say it comes (Read.lua, Rd.Proc). Armor takes its share of one
	-- that is not magic.
	if s.proc then
		white = white + s.proc.damage * s.proc.perMinute / 60 * (s.proc.magic and 1 or through)
	end

	-- mana a second the fight can pay: the pool spread over the fight, and
	-- what comes back while casting
	local budget = s.mana / seconds + s.manaPer5 / 5
	-- the opening seal and Judgement that put the debuff up are paid once
	if crusader and kit.judgement then
		budget = math.max(0, budget - (crusader.cost + kit.judgement.cost) / seconds)
	end

	local spells = {}
	-- (no share of the Crusader debuff: in his fights it did about 60 a cast,
	-- which is its description with nothing added)
	-- Holy Strike: a share of weapon damage plus Holy damage, all of it
	-- Holy, so armor takes none
	if kit.holyStrike then
		local k = kit.holyStrike
		local amount = (k.percent * average + (k.holy + R.SHARE.holyStrike * (more - debuff)) * lifted) * (1 + R.MELEE_CRIT * crit) * hit
		spells[#spells + 1] = { dps = amount / k.cooldown, mana = k.cost / k.cooldown }
	end
	-- Consecration: the same damage to every enemy in it, no crits
	if kit.consecration then
		local k = kit.consecration
		-- (the debuff is on one enemy only)
		-- (its second part is for the first `cap` enemies only, as it says;
		-- the rest take the first part's share of the whole)
		local each = k.total + R.SHARE.consecration * (more - debuff)
		local full = math.min(enemies, k.cap or enemies)
		local part = (k.first and k.total > 0) and k.first / k.total or 1
		local amount = (each * full + each * part * (enemies - full) + R.SHARE.consecration * debuff) * spellHit * lifted
		spells[#spells + 1] = { dps = amount / k.cooldown, mana = k.cost / k.cooldown }
	end

	local function judge(seal, share)
		local j = kit.judgement
		if not (j and seal.judge) then
			return nil
		end
		local amount = (seal.judge + share * more) * (1 + R.SPELL_CRIT * spellCrit) * spellHit * lifted
		-- one Judgement of the fight went on the debuff
		local left = crusader and clamp(1 - j.cooldown / seconds, 0, 1) or 1
		-- (`kit.judgeBack`: the share of the judged seal's cost a Judgement
		-- gives back, Sanctified Judgement)
		local paid = math.max(0, j.cost - (kit.judgeBack or 0) * (seal.cost or 0))
		return { dps = amount * left / j.cooldown, mana = paid / j.cooldown, needsSeal = true,
			crits = spellCrit * spellHit * left / j.cooldown }
	end
	-- VENGEANCE (the same day). "Increases your Physical and Holy damage dealt
	-- by 3% for 30 sec after landing a non-periodic critical strike. Stacks up
	-- to 3 times." Everything a paladin does here is one or the other, so it
	-- multiplies the whole sum, and crit is worth more for it.
	-- AN ESTIMATE of how many stacks are up on average: your crits a second
	-- (swings, Holy Strike, Seal of Command's hits, Judgement) times how long
	-- one lasts, levelling off at the most there can be. A fight starts with
	-- none, so a short fight has less time with them.
	local function vengeance(seal)
		local v = kit.vengeance
		if not (v and (v.pct or 0) > 0 and (v.secs or 0) > 0) then
			return 1
		end
		local rate = swings * crit + (seal and seal.crits or 0) + (seal and seal.judge and seal.judge.crits or 0)
		if kit.holyStrike then
			rate = rate + crit * hit / kit.holyStrike.cooldown
		end
		local d = v.secs
		local window = seconds <= d and seconds / 2 or d - d * d / (2 * seconds)
		local most = math.max(1, v.stacks or 1)
		return 1 + v.pct / 100 * most * (1 - math.exp(-rate * window / most))
	end

	local seals = {}
	local k = kit.seals or {}
	if k.command then
		-- hits per minute are counted on the weapon's own speed, so a slow
		-- weapon lands the same number of bigger hits
		local chance = clamp(R.COMMAND_PER_MINUTE * s.weaponSpeed / 60, 0, 1)
		local amount = (k.command.percent * average + R.SHARE.commandHit * (holy + debuff) * lifted) * (1 + R.MELEE_CRIT * crit)
		seals.command = { dps = swings * chance * amount, mana = k.command.cost / R.SEAL_SECONDS,
			judge = judge(k.command, R.SHARE.commandJudge), crits = swings * chance * crit }
	end
	if k.righteousness then
		-- the description gives the hit on the fastest and the slowest
		-- weapon; GUESS: 1.5 and 4.0 seconds, straight line between
		local t = clamp((s.weaponSpeed - 1.5) / 2.5, 0, 1)
		local amount = (k.righteousness.low + (k.righteousness.high - k.righteousness.low) * t
			+ R.SHARE.righteousnessHit * more) * lifted
		seals.righteousness = { dps = swings * amount, mana = k.righteousness.cost / R.SEAL_SECONDS,
			judge = judge(k.righteousness, R.SHARE.righteousnessJudge) }
	end
	if k.fury then
		local amount = (k.fury.hit + R.SHARE.furyHit * more) * lifted
		seals.fury = { dps = swings * amount, mana = k.fury.cost / R.SEAL_SECONDS,
			judge = judge(k.fury, R.SHARE.furyJudge) }
	end

	-- THE SEAL IS NOT ASSUMED. Each one is priced with this weapon and the
	-- best is kept: a slow weapon comes out with Seal of Command, a fast one
	-- with Seal of Righteousness. The seal is paid first, then whatever
	-- gives the most damage for its mana, until the mana runs out.
	local function total(seal)
		local left, sum = budget, 0
		local kept = 1
		if seal then
			kept = seal.mana > 0 and clamp(left / seal.mana, 0, 1) or 1
			sum = sum + kept * seal.dps
			left = left - kept * seal.mana
		end
		local rest = {}
		for _, a in ipairs(spells) do
			rest[#rest + 1] = a
		end
		if seal and seal.judge then
			rest[#rest + 1] = seal.judge
		end
		-- (one that costs nothing before any)
		local function worth(a)
			return a.mana > 0 and a.dps / a.mana or math.huge
		end
		table.sort(rest, function(a, b)
			local wa, wb = worth(a), worth(b)
			if wa ~= wb then
				return wa > wb
			end
			return a.dps > b.dps
		end)
		for _, a in ipairs(rest) do
			local f = a.mana > 0 and clamp(left / a.mana, 0, 1) or 1
			if a.needsSeal then
				f = math.min(f, kept)
			end
			sum = sum + f * a.dps
			left = left - f * a.mana
		end
		return (forWhite * white + forHoly * sum) * vengeance(seal)
	end

	local best, name = total(nil), nil
	for _, key in ipairs({ "command", "righteousness", "fury" }) do
		if seals[key] then
			local sum = total(seals[key])
			if sum > best then
				best, name = sum, key
			end
		end
	end
	return best, name
end

-- JUDGEMENT OF THE CRUSADER FIRST, WHERE IT PAYS (Josh's fights, 2026-11-16:
-- he pulls with Seal of the Crusader, judges it, then casts his damage seal;
-- his Judgement of Righteousness did about 115 a cast where its description
-- says about 85). The debuff "increases Holy damage taken by up to 58", and
-- the client's table has it as a flat amount on Holy damage taken, which each
-- spell takes its own share of, as it does of spell power: 0.429 x 58 is the
-- 25 his Judgement gained. So the rotation is priced with the debuff up and
-- without, and the better one is the answer. It costs the opening seal's
-- mana and one Judgement of the fight.
--
-- HOW LONG THE FIGHT IS (Josh 2026-11-17, asked whether the model suits a
-- player leveling from 1 to 60 and "constantly upgrading their gear": "Let's
-- fix 1-4"). Every fight was 180 seconds, with the mana pool spread over all
-- of it, so the spells were rationed. His fights against enemies of his
-- level lasted 10 to 20 seconds, and in a fight that short the pool is not
-- what limits you. Intellect and mana were worth too much to the DPS number
-- and spell power too little.
--
-- So below R.TOP_LEVEL the fight is as long as it takes to kill a normal
-- enemy of your level: its health from the game's table (R.EnemyHealth),
-- over the damage you do in a fight that long. The two depend on each
-- other, so it is worked out a few times over until it settles. At level 30
-- it comes to about 18 seconds, as his fights did. Each fight starts with a
-- full pool: eating and drinking between fights are left out (his words: "I
-- don't think we should worry about eating or drinking at this time").
--
-- The long fight stays where it belongs: at the top level, and for threat,
-- which is a tank's and so a group's (`how.long`, or weights for threat).
R.TOP_LEVEL = 60
R.SHORTEST_FIGHT = 6
function R.FightSeconds(s, kit, how)
	how = how or {}
	if how.long or how.threat or (how.white or 1) ~= 1 or (how.holy or 1) ~= 1 or (s.level or R.TOP_LEVEL) >= R.TOP_LEVEL then
		return R.FIGHT_SECONDS
	end
	local health = R.EnemyHealth(s.level) * (how.enemies or 1)
	local seconds = 20
	for _ = 1, 12 do
		local dps = damage(s, kit, how, nil, seconds)
		if not dps or dps <= 0 then
			return R.FIGHT_SECONDS
		end
		local next = clamp(health / dps, R.SHORTEST_FIGHT, R.FIGHT_SECONDS)
		if math.abs(next - seconds) < 0.01 then
			seconds = next
			break
		end
		-- (half way each time: it settles and does not swing)
		seconds = (seconds + next) / 2
	end
	return seconds
end
-- Returns the damage a second, the seal it is with, whether the Crusader's
-- Judgement opens it, and how long the fight was taken to be.
function R.Damage(s, kit, how)
	local seconds = R.FightSeconds(s, kit, how)
	local plain, seal = damage(s, kit, how, nil, seconds)
	local c = kit.crusader
	if c and c.holy and c.holy > 0 and kit.judgement then
		local with, sealWith = damage(s, kit, how, c, seconds)
		if with > plain then
			return with, sealWith, true, seconds
		end
	end
	return plain, seal, false, seconds
end

-- TANK, THREAT: damage on one enemy, counted as Righteous Fury counts it.
-- Without Righteous Fury it is plain damage.
function R.Threat(s, kit)
	-- (a class priced by its abilities: each one's own threat is in its sum)
	if kit.abilities then
		return R.Damage(s, kit, { threat = true, front = true, long = true })
	end
	local f = kit.righteousFury
	if not f then
		return R.Damage(s, kit, { front = true, long = true })
	end
	return R.Damage(s, kit, { white = f.all, holy = f.all * f.holy, front = true })
end

-- ONE NUMBER A ROLE (Josh 2026-11-16: "Do you think it would make sense to
-- combine them so we only have 3 stats? Like the tank stat would include the
-- threat, as well as all the other tank stats. Then we'd have a breakdown
-- when the user holds shift key", and of the weights: "Yeah the ratios sound
-- good"). `change` is the six changes in percent. What comes back is three.
--   tank:   70% survival, 30% threat. A JUDGEMENT, not the game's math.
--   dps:    75% one enemy, 25% four. A JUDGEMENT too.
--   healer: all the healing of one fight (R.FightHealing): the best mix
--           of your heals for the time and the mana there is. No weight is
--           needed. Without it, sustain, then healing per second.
R.MIX = { tank = 0.3, dps = 0.25 }
local function mix(a, b, share)
	if a == nil and b == nil then
		return nil
	end
	if b == nil then
		return a
	end
	return (a or 0) * (1 - share) + b * share
end
function R.Combine(change)
	return {
		tank = mix(change.tank, change.threat, R.MIX.tank),
		healer = change.fight or change.sustain or change.healer,
		dps = mix(change.dps, change.aoe, R.MIX.dps),
	}
end

-- the change, in percent
function R.Change(before, after)
	if not (before and after) or before <= 0 then
		return nil
	end
	return (after / before - 1) * 100
end
