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
R.AOE_ENEMIES = 4
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

-- HEALER: healing per second from the heal that gives the most
function R.Healing(s, kit)
	local best, name = 0, nil
	local more = s.healing - kit.at.healing
	for _, h in ipairs(kit.heals or {}) do
		local amount = (h.amount + h.share * more) * (1 + R.SPELL_CRIT * s.spellCrit / 100)
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
			local per = (h.amount + h.share * more) * (1 + R.SPELL_CRIT * s.spellCrit / 100) / h.cost
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
		heals[#heals + 1] = {
			amount = (h.amount + h.share * more) * (1 + R.SPELL_CRIT * s.spellCrit / 100),
			cast = math.max(h.cast, 1.5), cost = math.max(h.cost or 0, 0),
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

-- DAMAGE, AND THE SEAL THAT GIVES IT. `how` (all optional):
--   enemies: how many stand in Consecration (1)
--   white, holy: what a point of each kind of damage counts for (1 and 1).
--     Threat is damage with Righteous Fury's weights.
-- White hits are physical. Everything else a paladin does here is Holy.
-- `seconds`: how long the fight is (R.FightSeconds)
local function damage(s, kit, how, crusader, seconds)
	how = how or {}
	seconds = seconds or R.FIGHT_SECONDS
	local enemies, forWhite, forHoly = how.enemies or 1, how.white or 1, how.holy or 1
	local holy = s.spellDamage[2]
	-- Judgement of the Crusader on the enemy is spell power for Holy damage
	-- done to it (see R.Damage)
	local debuff = crusader and crusader.holy or 0
	local more = holy - kit.at.spell + debuff
	local crit, spellCrit = s.crit / 100, s.spellCrit / 100
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
	local swings = hit / swing

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
		local amount = (k.percent * average + k.holy + R.SHARE.holyStrike * (more - debuff)) * (1 + R.MELEE_CRIT * crit) * hit
		spells[#spells + 1] = { dps = amount / k.cooldown, mana = k.cost / k.cooldown }
	end
	-- Consecration: the same damage to every enemy in it, no crits
	if kit.consecration then
		local k = kit.consecration
		-- (the debuff is on one enemy only)
		local amount = ((k.total + R.SHARE.consecration * (more - debuff)) * enemies + R.SHARE.consecration * debuff) * spellHit
		spells[#spells + 1] = { dps = amount / k.cooldown, mana = k.cost / k.cooldown }
	end

	local function judge(seal, share)
		local j = kit.judgement
		if not (j and seal.judge) then
			return nil
		end
		local amount = (seal.judge + share * more) * (1 + R.SPELL_CRIT * spellCrit) * spellHit
		-- one Judgement of the fight went on the debuff
		local left = crusader and clamp(1 - j.cooldown / seconds, 0, 1) or 1
		return { dps = amount * left / j.cooldown, mana = j.cost / j.cooldown, needsSeal = true }
	end

	local seals = {}
	local k = kit.seals or {}
	if k.command then
		-- hits per minute are counted on the weapon's own speed, so a slow
		-- weapon lands the same number of bigger hits
		local chance = clamp(R.COMMAND_PER_MINUTE * s.weaponSpeed / 60, 0, 1)
		local amount = (k.command.percent * average + R.SHARE.commandHit * (holy + debuff)) * (1 + R.MELEE_CRIT * crit)
		seals.command = { dps = swings * chance * amount, mana = k.command.cost / R.SEAL_SECONDS,
			judge = judge(k.command, R.SHARE.commandJudge) }
	end
	if k.righteousness then
		-- the description gives the hit on the fastest and the slowest
		-- weapon; GUESS: 1.5 and 4.0 seconds, straight line between
		local t = clamp((s.weaponSpeed - 1.5) / 2.5, 0, 1)
		local amount = k.righteousness.low + (k.righteousness.high - k.righteousness.low) * t
			+ R.SHARE.righteousnessHit * more
		seals.righteousness = { dps = swings * amount, mana = k.righteousness.cost / R.SEAL_SECONDS,
			judge = judge(k.righteousness, R.SHARE.righteousnessJudge) }
	end
	if k.fury then
		local amount = k.fury.hit + R.SHARE.furyHit * more
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
		table.sort(rest, function(a, b) return a.dps / a.mana > b.dps / b.mana end)
		for _, a in ipairs(rest) do
			local f = a.mana > 0 and clamp(left / a.mana, 0, 1) or 1
			if a.needsSeal then
				f = math.min(f, kept)
			end
			sum = sum + f * a.dps
			left = left - f * a.mana
		end
		return forWhite * white + forHoly * sum
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
	if how.long or (how.white or 1) ~= 1 or (how.holy or 1) ~= 1 or (s.level or R.TOP_LEVEL) >= R.TOP_LEVEL then
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
