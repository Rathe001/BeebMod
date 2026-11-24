-- WHAT THE GAME SAYS, IN THE SHAPE THE MATH TAKES (Josh 2026-11-16).
--
-- Every game call Upgrades makes for its numbers is in this file: your
-- totals, the rates the character sheet uses, what your spells do right now,
-- and an item's stats. Math.lua and Roles.lua take what this hands them and
-- call nothing.
--
-- PALADIN ONLY, for now. A spell is found by its id and its numbers are
-- taken from its description by their place in it, not by its words
-- (2026-11-17, SpellData.lua; see YOUR SPELLS, below). The description is
-- still what is read, because it is the game's own answer with your spell
-- power and talents already counted (probe, 2026-11-16).
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
local UP = BT.Upgrades

-- WHAT IT KEEPS, in BeebMod's own saved file under `upgrades` (2026-11-17,
-- when Upgrades became a module of BeebMod; it was BeebModUpgradesDB, the
-- saved file of an addon of its own): the rates worked out from the game,
-- the last fights and the swap checks.
function UP.DB()
	BeebModDB = BeebModDB or {}
	if type(BeebModDB.upgrades) ~= "table" then
		BeebModDB.upgrades = {}
	end
	return BeebModDB.upgrades
end

local Rd = {}
UP.Read = Rd

local STATS = { "strength", "agility", "stamina", "intellect", "spirit" }
local HIT_MELEE, HIT_SPELL, CRIT_MELEE = CR_HIT_MELEE or 6, CR_HIT_SPELL or 8, CR_CRIT_MELEE or 9

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a number the math may use, or nil
local function num(v)
	if type(v) == "number" and not secret(v) then
		return v
	end
	return nil
end

-- WEAPON SKILL IS TAKEN AS FULL (Josh 2026-11-16: "We should just assume max
-- weapon skill for the level if possible... otherwise weapons with low skill
-- would look terrible on paper, but in reality could be a much better
-- item"). A weapon you are hovering is priced as if its skill were full
-- already, since nothing about it is read from the sheet. The one you are
-- wearing is on the sheet, so where its skill is short of full, the crit the
-- shortfall costs is put back. Both then stand on the same footing.
-- GUESS: classic's 0.04% crit for each point of skill.
-- NOT YET: an item that adds weapon skill of its own.
Rd.CRIT_PER_SKILL = 0.04
-- weapon kind -> its skill line (the character sheet's own list,
-- Camelot/PaperDollFrameStats.lua)
local SKILL_OF = {}
do
	local W = Enum and Enum.ItemWeaponSubclass or {}
	for name, id in pairs({ Sword1H = 43, Axe1H = 44, Bows = 45, Guns = 46, Mace1H = 54, Sword2H = 55, Staff = 136,
		Mace2H = 160, Axe2H = 172, Dagger = 173, Thrown = 176, Crossbow = 226, Wand = 228, Polearm = 229, Unarmed = 162 }) do
		if W[name] then
			SKILL_OF[W[name]] = id
		end
	end
end

-- how many points the worn main-hand weapon's skill is short of full
function Rd.SkillShort(level)
	local link = GetInventoryItemLink("player", 16)
	if not (link and C_Item and C_Item.GetItemInfoInstant and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then
		return 0
	end
	local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(link)
	local line = class == (Enum.ItemClass and Enum.ItemClass.Weapon or 2) and SKILL_OF[sub]
	local info = line and C_SkillInfo.GetSkillLineInfoByID(line)
	local rank = type(info) == "table" and num(info.rank)
	if not rank then
		return 0
	end
	return math.max(0, level * 5 - rank)
end

-- A DRUID'S FORMS (Josh 2026-11-18: "Start druid"). A cat's and a bear's
-- attack power, crit, armor, health and swings are not yours as you stand,
-- and the game says them only while you are in the form. So what you are
-- out of any form is kept, and each time you are seen in a form, what it
-- adds to that is kept too: attack power, crit and health as amounts, armor
-- as what it is multiplied by, and the paws' own damage and speed. Kept for
-- your level. Gear changed while in a form makes it a little off until you
-- are next seen out of one and back in.
-- (the game's form numbers: cat 1, bear 5, dire bear 8)
Rd.FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }
function Rd.Forms(s, db)
	db.forms = type(db.forms) == "table" and db.forms.level == s.level and db.forms or { level = s.level, seen = {} }
	local kept = db.forms
	if not s.form then
		kept.base = { ap = s.attackPower, crit = s.crit, armor = s.armor, health = s.health }
	elseif kept.base and kept.base.armor > 0 and s.weaponSpeed > 0 then
		local own = s.attackPower / 14 * s.weaponSpeed
		kept.seen[s.form] = {
			ap = s.attackPower - kept.base.ap, crit = s.crit - kept.base.crit, armor = s.armor / kept.base.armor,
			health = s.health - kept.base.health, pawMin = s.damageMin - own, pawMax = s.damageMax - own, speed = s.weaponSpeed,
		}
	end
	return kept.seen
end

-- WHICH TOTAL THE GAME KEEPS BACK, FOR WHAT LOADED (Josh 2026-11-23, a shield
-- in his bags in a battleground with no numbers on it: "Any idea why the
-- Upgrades isnt showing here?"). Rd.State gives nothing where any one of
-- these cannot be read, and did not say which. The same reads, each named:
-- the first that is missing or secret, or nil where all of them read.
function Rd.Held()
	if not UnitStat then
		return "no UnitStat"
	end
	local function state(v)
		return secret(v) and "secret" or (type(v) ~= "number" and type(v)) or nil
	end
	for i, name in ipairs(STATS) do
		local ok, _, effective = pcall(UnitStat, "player", i)
		local bad = not ok and "error" or state(effective)
		if bad then
			return name .. " " .. bad
		end
	end
	local reads = {
		{ "attack power", function() local a, b, c = UnitAttackPower("player") return state(a) or state(b) or state(c) end },
		{ "armor", function() local _, a = UnitArmor("player") return state(a) end },
		{ "damage", function() local a, b = UnitDamage("player") return state(a) or state(b) end },
		{ "attack speed", function() return state((UnitAttackSpeed("player"))) end },
		{ "mana regen", function() local _, c = GetManaRegen() return state(c) end },
		{ "haste", function() return state(GetMeleeHaste and GetMeleeHaste() or 0) end },
		{ "health", function() return state(UnitHealthMax("player")) end },
	}
	for _, r in ipairs(reads) do
		local ok, bad = pcall(r[2])
		if not ok then
			return r[1] .. " error"
		end
		if bad then
			return r[1] .. " " .. bad
		end
	end
	return nil
end

-- your totals as you stand; nil if the game keeps any of them back
function Rd.State()
	-- (a client without the call has nothing to read)
	if not UnitStat then
		return nil
	end
	local s = { level = UnitLevel("player") }
	for i, name in ipairs(STATS) do
		local _, effective = UnitStat("player", i)
		s[name] = num(effective)
		if not s[name] then
			return nil
		end
	end
	local base, up, down = UnitAttackPower("player")
	local _, armor = UnitArmor("player")
	local low, high = UnitDamage("player")
	local shown = UnitAttackSpeed("player")
	local _, casting = GetManaRegen()
	local haste = GetMeleeHaste and GetMeleeHaste() or 0
	local want = { base, up, down, armor, low, high, shown, casting, haste }
	for i = 1, 9 do
		if not num(want[i]) then
			return nil
		end
	end
	s.attackPower = base + up + down
	s.armor = armor
	s.damageMin, s.damageMax = low, high
	s.haste = haste
	-- the weapon's own speed: the sheet shows it with haste taken off
	s.weaponSpeed = shown * (1 + haste / 100)
	-- SEAL OF THE CRUSADER BENDS THE SHEET (Josh's fights, 2026-11-16: with it
	-- up at the pull the sheet said 316 attack power, a 2.0 speed and 65-82
	-- a hit; with it down, 212, 2.8 and 70-94). It is a buff of 30 seconds,
	-- not what your gear is worth, and its speed is not in GetMeleeHaste, so
	-- the weapon read as a faster one and every seal was priced for that.
	-- The weapon's own speed comes from its tooltip. Where the sheet's speed
	-- is well short of it, the seal is up: its attack power is taken off and
	-- the hit worked out again from the weapon (weapon + attack power / 14 x
	-- speed, which matched the sheet to the decimal in the probe).
	-- (not in a druid's form: its swings are its paws', at the form's own speed)
	local form = Rd.FORMS[num(GetShapeshiftFormID and GetShapeshiftFormID()) or 0]
	s.form = form
	local weapon = not form and Rd.Weapon(GetInventoryItemLink("player", 16)) or nil
	if weapon then
		s.proc = weapon.proc
		local faster = weapon.speed / s.weaponSpeed
		s.weaponSpeed = weapon.speed
		local ap = faster > 1.25 and Rd.CrusaderPower() or nil
		if ap then
			s.crusader = true
			s.attackPower = s.attackPower - ap
			s.damageMin = weapon.min + s.attackPower / 14 * weapon.speed
			s.damageMax = weapon.max + s.attackPower / 14 * weapon.speed
		end
	end
	s.manaPer5 = casting * 5
	-- mana a second from spirit, which comes only while you are not casting
	s.spiritRegen = num(GetManaRegenFromSpirit and GetManaRegenFromSpirit()) or 0
	s.spellDamage = {}
	for school = 2, 7 do
		s.spellDamage[school] = num(GetSpellBonusDamage(school)) or 0
	end
	s.healing = num(GetSpellBonusHealing()) or 0
	s.crit = num(GetCritChance()) or 0
	-- as it would be with the weapon's skill full (Rd.SkillShort)
	s.skillShort = Rd.SkillShort(s.level)
	s.crit = s.crit + s.skillShort * Rd.CRIT_PER_SKILL
	s.spellCrit = num(GetSpellCritChance(2)) or 0
	-- (and each school's own, for a caster's spells)
	s.spellCrits = {}
	for school = 2, 7 do
		s.spellCrits[school] = num(GetSpellCritChance(school)) or s.spellCrit
	end
	s.hit = (num(GetHitModifier and GetHitModifier()) or 0) + (num(GetCombatRatingBonus(HIT_MELEE)) or 0)
	s.spellHit = (num(GetSpellHitModifier and GetSpellHitModifier()) or 0) + (num(GetCombatRatingBonus(HIT_SPELL)) or 0)
	s.dodge = num(GetDodgeChance()) or 0
	s.parry = num(GetParryChance()) or 0
	s.block = num(GetBlockChance and GetBlockChance()) or 0
	-- DEFENSE OVER YOUR LEVEL'S OWN: what gear and buffs add. The skill
	-- itself is taken as full for your level, as a weapon's is (Josh
	-- 2026-11-16, of weapon skill: "We should just assume max"), so it is
	-- the sheet's second number that counts.
	-- your resistances, by school (fire 2, nature 3, frost 4, shadow 5,
	-- arcane 6), and your expertise in percent off an enemy's dodge
	s.resist = {}
	for school = 2, 6 do
		local _, total = UnitResistance("player", school)
		s.resist[school] = num(total) or 0
	end
	s.expertise = num(GetExpertisePercent and GetExpertisePercent())
		or ((num(GetExpertise and GetExpertise()) or 0) * 0.25)
	s.defense = 0
	if UnitDefenseSkill then
		local _, added = UnitDefenseSkill("player")
		s.defense = math.max(0, num(added) or 0)
	end
	s.blockValue = num(GetShieldBlock and GetShieldBlock()) or 0
	s.shield = C_PaperDollInfo and C_PaperDollInfo.OffhandHasShield and C_PaperDollInfo.OffhandHasShield() and true or false
	-- (a two-hander: some abilities need one, and a weapon's damage is
	-- evened out for an ability by which it is)
	do
		-- (THE KIND OF WEAPON WAS NEVER READ, review 2026-11-18. It was asked
		-- for at the end of a chain of `and`, which hands on one value only,
		-- and the kind is the fourth. So a two-hander was never one here.)
		local main = GetInventoryItemLink("player", 16)
		s.twoHand = Rd.TwoHanded(main)
		-- (a dagger: some of a rogue's abilities need one)
		s.dagger = Rd.Dagger(main)
		-- (a weapon specialization: what each kind of weapon is lifted by,
		-- and what the one in hand is, which the game's damage has in it)
		if Rd.Gear then
			s.lifts = Rd.Gear()
			s.weaponLift = UP.Math.Lift(s.lifts, s.twoHand)
		end
	end
	-- a druid's forms, kept from when each was last seen (Rd.Forms)
	s.forms = Rd.Forms(s, UP.DB())
	-- A RANGED WEAPON, as the game shows it: its speed with a quiver's haste
	-- in, its damage with attack power and ammunition in. And the weapon's
	-- own speed from its tooltip, which is what attack power is counted by.
	do
		local speed, low, high = UnitRangedDamage("player")
		if num(speed) and speed > 0 and num(low) and num(high) then
			s.rangedSpeed, s.rangedMin, s.rangedMax = speed, low, high
			local rBase, rUp, rDown = UnitRangedAttackPower("player")
			s.rangedPower = (num(rBase) or 0) + (num(rUp) or 0) + (num(rDown) or 0)
			s.rangedCrit = num(GetRangedCritChance and GetRangedCritChance()) or s.crit
			s.rangedHit = (num(GetHitModifier and GetHitModifier()) or 0) + (num(GetCombatRatingBonus(CR_HIT_RANGED or 7)) or 0)
			local own = Rd.Weapon(GetInventoryItemLink("player", 18))
			s.rangedBase = own and own.speed or speed
		end
	end
	-- A PET: what its sheet says it does a second. Kept from when it was
	-- last out, so a dismissed pet does not change every number.
	do
		local db = UP.DB()
		if UnitExists and UnitExists("pet") then
			local low, high = UnitDamage("pet")
			local speed = UnitAttackSpeed("pet")
			if num(low) and num(high) and num(speed) and speed > 0 then
				db.pet = { level = s.level, dps = (low + high) / 2 / speed }
			end
		end
		if type(db.pet) == "table" and db.pet.level == s.level then
			s.petDps = db.pet.dps
		end
	end
	-- WHAT IS ON YOUR WEAPONS: a poison, or a shaman's imbue (Rd.Imbue)
	if GetWeaponEnchantInfo then
		local ok, hasMain, _, _, mainId, hasOff, _, _, offId = pcall(GetWeaponEnchantInfo)
		local data = UP.SpellData
		if ok and type(data) == "table" and type(data.enchants) == "table" then
			s.imbue = Rd.Imbue(data.enchants, UP.DB(), hasMain and num(mainId) or nil, hasOff and num(offId) or nil)
		end
	end
	-- A WEAPON IN THE OFF HAND: its swings as the game shows them, which is
	-- with the off hand's cut taken. Kept with the attack power they were
	-- read at, so a change in it can move them (Roles.lua).
	do
		local _, _, offLow, offHigh = UnitDamage("player")
		local _, offSpeed = UnitAttackSpeed("player")
		local has = OffhandHasWeapon and OffhandHasWeapon()
		if has and num(offLow) and num(offHigh) and num(offSpeed) and offSpeed > 0 then
			s.dual = true
			s.offMin, s.offMax, s.offSpeed, s.offAp = offLow, offHigh, offSpeed * (1 + s.haste / 100), s.attackPower
		end
	end
	s.health = num(UnitHealthMax("player"))
	s.mana = num(UnitPowerMax("player", 0)) or 0
	if not s.health then
		return nil
	end
	-- health per 5 seconds from what you wear: the game has no total for it
	-- that leaves spirit out, so the pieces are added up
	s.healthPer5 = 0
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		local stats = link and C_Item and C_Item.GetItemStats and C_Item.GetItemStats(link)
		local regen = type(stats) == "table" and num(stats.ITEM_MOD_HEALTH_REGEN_SHORT)
		if regen then
			s.healthPer5 = s.healthPer5 + regen
		end
	end
	return s
end

-- WHAT IS ON YOUR WEAPONS (Josh 2026-11-18, of what was left: "proceed").
-- The game gives the id of the temporary enchantment on each hand, and the
-- tables' list (`list`, SpellData.enchants) says what it adds. What was on
-- a hand last is kept in `db`, so a poison that has run out, or a weapon
-- held for a moment with none, does not change every number: you are taken
-- to put the same one on again. One that is on now and is not in the list
-- (Crippling Poison) is your choice, and counts for nothing.
-- Returns { main = entry, off = entry }.
function Rd.Imbue(list, db, mainId, offId)
	db.imbue = type(db.imbue) == "table" and db.imbue or {}
	local out = {}
	local function hand(name, id)
		if id and id > 0 then
			db.imbue[name] = list[id] and id or false
		end
		out[name] = db.imbue[name] and list[db.imbue[name]] or nil
	end
	hand("main", mainId)
	hand("off", offId)
	return out
end

-- what one point is worth, asked of the functions the character sheet calls
function Rd.Rates(s)
	local r = { attackPowerPer = {}, multiplier = Rd.Multipliers() }
	-- (Toughness and Shield Specialization: Rd.GEAR_TALENTS)
	local g = Rd.Gear and Rd.Gear() or {}
	r.armorFromItems = 1 + (g.armor or 0) / 100
	r.blockValue = 1 + (g.block or 0) / 100
	for i, name in ipairs(STATS) do
		local per = num(GetAttackPowerForStat and GetAttackPowerForStat(i, 100))
		if per and per ~= 0 then
			r.attackPowerPer[name] = per / 100
		end
	end
	-- these two answer as a share of 1 for the total given, so the answer
	-- for 100 points is the percent for 1
	r.critPerAgility = num(GetCritChanceFromStat and GetCritChanceFromStat(2, 100)) or 0
	r.spellCritPerIntellect = num(GetSpellCritChanceFromStat and GetSpellCritChanceFromStat(4, 100)) or 0
	r.healthPerStamina = num(UnitHPPerStamina and UnitHPPerStamina("player")) or 10
	r.manaPerIntellect = MANA_PER_INTELLECT or 15
	local dodge = num(GetDodgeChanceFromAttribute and GetDodgeChanceFromAttribute())
	r.dodgePerAgility = dodge and s.agility > 0 and dodge * 100 / s.agility or 0
	-- WHAT A POINT OF SPIRIT GIVES. The game says what your spirit gives now
	-- and nothing for a total you don't have. So the rate is worked out the
	-- first time your spirit is seen at two different totals, and kept.
	-- GUESS until then: classic's 0.1 mana a second for a paladin.
	local db = UP.DB()
	local was = db.spirit
	if type(was) == "table" and was.level == s.level and math.abs(was.spirit - s.spirit) >= 3 then
		local per = (s.spiritRegen - was.regen) / (s.spirit - was.spirit)
		if per > 0 and per < 2 then
			db.regenPerSpirit = { level = s.level, per = per }
		end
	end
	if type(was) ~= "table" or was.level ~= s.level then
		db.spirit = { level = s.level, spirit = s.spirit, regen = s.spiritRegen }
	end
	local kept = db.regenPerSpirit
	r.regenPerSpirit = type(kept) == "table" and kept.level == s.level and kept.per or 0.1

	-- WHAT A POINT OF RATING GIVES (Josh's chat lines, 2026-11-16: boots with
	-- 7 crit rating went on and crit rose 0.5 where 0 was expected - with no
	-- rating worn there was nothing to divide). While you wear some, the game
	-- is asked. With none, the client's own table answers
	-- (gametables/combatratings.txt, build 70938): rating for 1%, and the
	-- same on every one of its 123 level rows.
	local function perRating(id, forOne)
		local rating, bonus = num(GetCombatRating(id)), num(GetCombatRatingBonus(id))
		if rating and bonus and rating > 0 and bonus > 0 then
			return bonus / rating
		end
		return 1 / forOne
	end
	r.critPerRating = perRating(CRIT_MELEE, 14)
	r.hitPerRating = perRating(HIT_MELEE, 10)
	r.dodgePerRating = perRating(CR_DODGE or 3, 12)
	r.parryPerRating = perRating(CR_PARRY or 4, 15)
	r.hastePerRating = perRating(CR_HASTE_MELEE or 18, 10)
	r.blockPerRating = perRating(CR_BLOCK or 5, 5)
	-- (rating for a point of expertise: the table's 10)
	r.expertisePerRating = perRating(CR_EXPERTISE or 24, 10)
	-- (rating for a point of Defense, not for 1%: the table's 1)
	r.defensePerRating = perRating(CR_DEFENSE_SKILL or 2, 1)
	return r
end

local function words(id)
	local text = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
	if type(text) ~= "string" or secret(text) then
		return ""
	end
	return text
end

local function cost(id)
	local costs = C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(id)
	local first = type(costs) == "table" and costs[1]
	return first and num(first.cost) or 0
end

-- ---------------------------------------------------------------------------
-- YOUR SPELLS, FOUND BY ID AND READ BY POSITION (Josh 2026-11-17: "Anything
-- else we can use from the game files? Spell names/ids would be nice", then
-- "Let's proceed with the rework")
-- ---------------------------------------------------------------------------
--
-- A spell was found by its English name and its numbers were picked out of
-- English sentences ("causes 43.2% weapon damage plus an additional 16 to
-- 23"). Both are gone. SpellData.lua, made from the game's own tables by
-- scripts/make-upgrade-spells.py, lists every rank of each spell the model
-- prices by id, and for each one what its description's numbers are in the
-- order it says them: "percent holy holy" for the sentence above.
--
-- The live amounts still come from the description. It is the only place
-- the game says them with your talents and buffs counted: the table has
-- Holy Strike at 32% weapon damage where his read 43.2%. So the description
-- is asked for, every number in it is taken in order, and the list says
-- which is which. No word of it is read.
--
-- LIMIT: a translation that says a spell's numbers in another order than
-- the English would be read wrongly. A count that does not match the list
-- is caught, and that spell is left out of the kit.

-- one number as a description writes it: "1,234", "43.2", and the other way
-- round as some languages do ("1.234", "43,2")
function Rd.Number(str)
	if type(str) ~= "string" then
		return nil
	end
	str = str:gsub("[%.,]+$", "")
	local dots, commas = select(2, str:gsub("%.", "")), select(2, str:gsub(",", ""))
	if dots > 0 and commas > 0 then
		-- both: the one that comes last is the decimal mark
		local lastDot, lastComma = str:find("%.[^%.]*$"), str:find(",[^,]*$")
		if lastDot > lastComma then
			str = str:gsub(",", "")
		else
			str = str:gsub("%.", ""):gsub(",", ".")
		end
	elseif dots + commas > 0 then
		-- one kind: thousands where exactly three digits follow each, as in
		-- "1,234"; a decimal mark otherwise
		local mark = dots > 0 and "%." or ","
		local thousands = str:find("^%d%d?%d?" .. ("(" .. mark .. "%d%d%d)"):rep(dots + commas) .. "$") ~= nil
		if thousands then
			str = str:gsub(mark, "")
		else
			str = str:gsub(",", ".")
		end
	end
	return tonumber(str)
end

-- every number in a description, in the order it says them
function Rd.Numbers(text)
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	for found in text:gmatch("%d[%d%.,]*") do
		out[#out + 1] = Rd.Number(found)
	end
	return out
end

-- A description's numbers by what they are (`read`: a word for each number,
-- "-" for one not used; the same word twice is a range, and its middle is
-- kept). Nil where the description has another count of numbers than the
-- list: a spell whose words changed is not guessed at.
function Rd.Planned(read, text)
	local numbers = Rd.Numbers(text)
	local keys = {}
	for key in tostring(read or ""):gmatch("%S+") do
		keys[#keys + 1] = key
	end
	if #keys ~= #numbers then
		return nil
	end
	local sum, count = {}, {}
	for i, key in ipairs(keys) do
		if key ~= "-" and numbers[i] then
			sum[key] = (sum[key] or 0) + numbers[i]
			count[key] = (count[key] or 0) + 1
		end
	end
	local out = {}
	for key, total in pairs(sum) do
		out[key] = total / count[key]
	end
	return out
end

-- the generated list for your class, or an empty one
function Rd.Spells()
	local data = UP.SpellData
	local _, class = UnitClass("player")
	return type(data) == "table" and type(data.spells) == "table" and data.spells[class] or {}
end

-- every spell in your spellbook, lowest rank first: fn(id, item, entry),
-- where `entry` is the generated list's for a spell the model prices
local function eachSpell(fn)
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
		return
	end
	local known = Rd.Spells()
	local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if type(info) == "table" then
			local first = (info.itemIndexOffset or 0) + 1
			for index = first, first + (info.numSpellBookItems or 0) - 1 do
				local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
				if type(item) == "table" then
					local id = item.actionID or item.spellID
					if type(id) == "number" and not secret(id) then
						local spell = type(item.spellID) == "number" and not secret(item.spellID) and item.spellID or nil
						fn(id, item, known[id] or (spell and known[spell]) or nil)
					end
				end
			end
		end
	end
end

-- THE HIGHEST RANK YOU KNOW, WHATEVER ORDER THE SPELLBOOK IS IN (Josh
-- 2026-11-17, asked which rank is used, then "Do we still need to fix those
-- 2 bugs from before this refactor?"). The last rank read for a spell was
-- kept, which is the highest only while the spellbook lists ranks lowest
-- first. The generated list has the level each rank is learned at, so the
-- spells the model prices are gathered and handed over lowest level first:
-- fn(id, item, entry), the highest rank of each spell last.
function Rd.ByRank(found)
	table.sort(found, function(a, b)
		local la, lb = a.entry.lvl or 0, b.entry.lvl or 0
		if la ~= lb then
			return la < lb
		end
		return a.at < b.at
	end)
	return found
end
local function eachPriced(fn)
	local found = {}
	eachSpell(function(id, item, entry)
		if entry then
			found[#found + 1] = { id = id, item = item, entry = entry, at = #found + 1 }
		end
	end)
	for _, one in ipairs(Rd.ByRank(found)) do
		fn(one.id, one.item, one.entry)
	end
end

local function cooldown(id)
	local ms = num(GetSpellBaseCooldown and GetSpellBaseCooldown(id))
	return ms and ms > 0 and ms / 1000 or nil
end

-- what a spell is to the model -> where its numbers go in the kit
-- (`v`: its description's numbers by what they are, Rd.Planned)
local ROLES = {
	holyStrike = function(kit, id, v, entry)
		local seconds = cooldown(id)
		if v.percent and v.holy and seconds then
			kit.holyStrike = { percent = v.percent / 100, holy = v.holy, cost = cost(id), cooldown = seconds,
				share = entry.share }
		end
	end,
	judgement = function(kit, id)
		local seconds = cooldown(id)
		if seconds then
			kit.judgement = { cost = cost(id), cooldown = seconds }
		end
	end,
	-- "doing 16 Holy damage over 8 sec ... will take an additional 49 damage
	-- over 8 sec": both parts, for each enemy in it
	consecration = function(kit, id, v)
		local seconds = cooldown(id)
		if v.first and seconds then
			-- (`cap`: how many enemies take the second part, as the spell says)
			kit.consecration = { total = v.first + (v.second or 0), first = v.first, cap = v.cap, cost = cost(id),
				cooldown = seconds }
		end
	end,
	-- "Increases all threat generated by 33%, and all threat generated by
	-- your Holy attacks by an additional 90%."
	righteousFury = function(kit, _, v)
		if v.all then
			kit.righteousFury = { all = 1 + v.all / 100, holy = 1 + (v.holy or 0) / 100 }
		end
	end,
	-- "...granting 104 melee attack power ... Unleashing this Seal's energy
	-- will judge an enemy for 40 sec, increasing Holy damage taken by up to 58."
	crusader = function(kit, id, v)
		if v.holy then
			kit.crusader = { holy = v.holy, cost = cost(id), power = v.ap }
		end
	end,
	command = function(kit, id, v)
		if v.percent then
			kit.seals.command = { percent = v.percent / 100, cost = cost(id), judge = v.judge }
		end
	end,
	righteousness = function(kit, id, v)
		if v.low and v.high then
			kit.seals.righteousness = { low = v.low, high = v.high, cost = cost(id), judge = v.judge }
		end
	end,
	fury = function(kit, id, v)
		if v.hit then
			kit.seals.fury = { hit = v.hit, cost = cost(id), judge = v.judge }
		end
	end,
	-- AN ABILITY OF A CLASS PRICED BY ITS ABILITIES (Roles.lua): its numbers
	-- as its description has them now, its cost and cooldown as the game
	-- says them, or as the tables do where it will not, and the plain facts
	-- about it from the generated list. Every rank is under one name, so the
	-- highest you know is the one kept.
	ability = function(kit, id, v, entry)
		kit.abilities = kit.abilities or {}
		local spell = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
		local cast = type(spell) == "table" and num(spell.castTime) or 0
		local paid = cost(id)
		local a = { v = v, cost = paid > 0 and paid or entry.cost or 0, cooldown = cooldown(id) or entry.cd or 0,
			cast = cast / 1000 }
		for _, fact in ipairs({ "swing", "also", "weapon", "aoe", "dot", "secs", "after", "tank", "shield", "blockvalue",
			"part", "twohand", "threat", "tmult", "spell", "spell2", "share", "dshare", "over", "channel",
			"points", "finisher", "dagger", "behind", "opener", "bleed", "speed", "lasts", "period", "spec" }) do
			a[fact] = entry[fact]
		end
		-- (energy: it comes at a set rate, Roles.lua)
		if entry.energy then
			kit.energy = true
		end
		-- (a class with a pet: its damage is counted beside yours)
		if entry.pet then
			kit.pet = true
		end
		-- (a ranged class: its shots for swings, and mana)
		if entry.ranged then
			kit.ranged, kit.mana = true, true
		end
		-- (a spell: the class is priced as a caster, by mana and casting time)
		-- (not for a class that fights more than one way: each way says how
		-- it is priced, Roles.lua)
		if entry.spell and not kit.specs then
			kit.caster = true
		end
		kit.abilities[entry.key or id] = a
	end,
	-- mana for a cast of its own (Life Tap)
	tap = function(kit, _, v)
		if v.mana and v.mana > 0 then
			kit.lifetap = { mana = v.mana }
		end
	end,
	-- mana given back by a spell of your own (Evocation)
	mana = function(kit, _, v, entry)
		if v.pct then
			kit.evocation = { pct = v.pct, secs = entry.secs, every = entry.cd }
		end
	end,
	-- what gives the class's resource outright (Charge, Bloodrage)
	rage = function(kit, _, v, entry)
		kit.rage = kit.rage or {}
		kit.rage[entry.key or #kit.rage + 1] = { amount = (v.rage or 0) + (v.more or 0), every = entry.every }
	end,
}

-- A BUFF OR A PASSIVE THAT MULTIPLIES A STAT (Josh's chat lines, 2026-11-16,
-- with Blessing of Kings up: "expected intellect 76.0 after that swap. The
-- game says 77.0", and his own reading of it: "Probably because I have
-- blessing of kings"). Kings is "Increases stats by 10%", and that 10% works
-- on the stats a piece of gear gives too, so 10 intellect on an item is 11.
-- Math.lua has had a multiplier for each stat from the start; nothing ever
-- filled it in.
--
-- The game has no call for it. Each buff on you and each passive in your
-- spellbook is looked up by id in the generated list of auras that raise a
-- stat by a percent (SpellData.stats, from the game's tables). One that is
-- not in the list has its English words searched as before, for "stats by
-- N%" or "<a stat> by N%": a talent the tables file under another kind of
-- effect. Buffs cannot be read in combat, so what was found last is kept
-- until they can.
local multipliers, multipliersAt = nil, nil
local function percents(text, into)
	text = text:lower()
	local all = text:match("all stats by (%d+)%%") or text:match("total stats by (%d+)%%") or text:match("stats by (%d+)%%")
	for _, name in ipairs(STATS) do
		local one = text:match(name .. " by (%d+)%%")
		local n = tonumber(one or all)
		if n and n > 0 and n <= 50 then
			into[name] = (into[name] or 1) * (1 + n / 100)
		end
	end
end
-- one aura or passive's share, by id from the tables or else by its words
function Rd.StatPercents(id, into, text)
	local data = UP.SpellData
	local listed = type(data) == "table" and type(data.stats) == "table" and data.stats[id]
	if type(listed) == "table" then
		for _, name in ipairs(STATS) do
			local n = listed[name] or listed.all
			if n then
				into[name] = (into[name] or 1) * (1 + n / 100)
			end
		end
		return true
	end
	percents(text or words(id), into)
	return false
end
-- a talent's share: the stats the tables list for it, by the percent its
-- words say at your rank (the tables' own where the words give none)
function Rd.TalentPercents(listed, said, into)
	if type(listed) ~= "table" then
		return
	end
	for _, name in ipairs(STATS) do
		local n = listed[name] or listed.all
		if n then
			local pct = said and said > 0 and said <= 50 and said or n
			into[name] = (into[name] or 1) * (1 + pct / 100)
		end
	end
end
function Rd.Multipliers()
	local t = GetTime()
	if multipliers and multipliersAt and (t - multipliersAt < 2 or InCombatLockdown()) then
		return multipliers
	end
	if InCombatLockdown() then
		return multipliers or {}
	end
	local found = {}
	-- the buffs on you
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	for i = 1, get and 40 or 0 do
		local ok, aura = pcall(get, "player", i, "HELPFUL")
		if not ok or type(aura) ~= "table" then
			break
		end
		local id = aura.spellId
		if type(id) == "number" and not secret(id) then
			Rd.StatPercents(id, found)
		end
	end
	-- and your talents, each at your rank. The tables have a talent's first
	-- rank, and its words at your rank say what it is now (Rd.TalentWords).
	local data = UP.SpellData
	local listed = type(data) == "table" and type(data.stats) == "table" and data.stats or {}
	local talents = Rd.Traits and Rd.Traits() or {}
	for id in pairs(talents) do
		Rd.TalentPercents(listed[id], Rd.Numbers(Rd.TalentWords(id))[1], found)
	end
	-- and your passives
	eachSpell(function(id, item)
		if item.isPassive and not (talents[id] and listed[id]) then
			Rd.StatPercents(id, found)
		end
	end)
	multipliers, multipliersAt = found, t
	return found
end

-- the attack power your highest Seal of the Crusader gives, looked for at
-- most every half minute
local crusaderPower, crusaderAt
function Rd.CrusaderPower()
	local t = GetTime()
	if crusaderAt and t - crusaderAt < 30 then
		return crusaderPower
	end
	crusaderAt, crusaderPower = t, nil
	eachPriced(function(id, _, entry)
		if entry and entry.is == "crusader" then
			local v = Rd.Planned(entry.read, words(id))
			crusaderPower = v and v.ap or crusaderPower
		end
	end)
	return crusaderPower
end

-- What your spells do now. Every rank is in the spellbook, lowest first, so
-- the last one read for a spell is the highest you know.
-- EVERY RANK OF A HEAL IS KEPT (Josh 2026-11-17: "Let's fix 1-4"). Only the
-- highest rank of each heal was priced. A lower rank is often the better
-- heal for its mana, and more so the more healing power you have, so the
-- healer's number sold healing power short. Each rank you know is a heal of
-- its own now, and the model picks among them (R.FightHealing).
-- A RANK'S SHARE OF HEALING POWER IS WORKED OUT FROM WHAT IT SAYS. The table
-- gives every rank of Holy Light the same share, 0.714. The game cuts it for
-- the lowest ranks: at 68 healing power his first rank said 63.5, which is
-- its own 46 and a share of 0.25. So where the tables give a rank's own
-- amount (base, and what it grows by a level) and you have healing power
-- enough to measure with, the share is what is left of the description's
-- amount over your healing power, and never more than the table's.
Rd.SHARE_FROM = 30
function Rd.HealShare(entry, amount, healing, level)
	local share = entry.share or 0
	if not (entry.base and healing and healing >= Rd.SHARE_FROM and amount) then
		return share
	end
	local grown = math.max(0, math.min((entry.to or 0) - (entry.from or 0), (level or 0) - (entry.from or 0)))
	local own = entry.base + (entry.per or 0) * grown
	return math.max(0, math.min(share, (amount - own) / healing))
end
-- A TALENT'S WORDS AT YOUR RANK (Josh's record, 2026-11-18: Improved
-- Judgement with 2 of 2 points read "Decreases the cooldown of your
-- Judgement ability by 1 sec."). A talent is one spell whatever your points
-- in it, and that spell's description is its first rank's. The talent
-- window gets its words from the talent itself with the rank handed over
-- (C_TooltipInfo.GetTraitEntry, as Blizzard_TalentDisplay.lua calls it), so
-- the same is done here. `Rd.Traits()`: each talent you have points in, by
-- its spell, with what the talent window calls it and your rank.
local traits, traitsAt
function Rd.Traits()
	local t = GetTime and GetTime() or 0
	if traits and traitsAt and t - traitsAt < 5 then
		return traits
	end
	local found = {}
	pcall(function()
		local config = C_ClassTalents.GetActiveConfigID()
		local info = config and C_Traits.GetConfigInfo(config)
		for _, tree in ipairs(info and info.treeIDs or {}) do
			for _, node in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
				local n = C_Traits.GetNodeInfo(config, node)
				local entry = n and n.activeEntry and n.activeEntry.entryID
				local rank = n and num(n.currentRank) or 0
				if entry and rank > 0 then
					local e = C_Traits.GetEntryInfo(config, entry)
					local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
					for _, id in ipairs({ d and d.spellID or false, d and d.overriddenSpellID or false }) do
						if type(id) == "number" and not secret(id) then
							found[id] = { entry = entry, rank = rank }
						end
					end
				end
			end
		end
	end)
	traits, traitsAt = found, t
	return found
end
function Rd.TalentWords(id)
	local t = Rd.Traits()[id]
	if t and C_TooltipInfo and C_TooltipInfo.GetTraitEntry then
		local ok, data = pcall(C_TooltipInfo.GetTraitEntry, t.entry, t.rank)
		if ok and type(data) == "table" and type(data.lines) == "table" then
			-- (the last line is the description. The ones before it are
			-- "Passive", or a cost and a cast time, whose numbers are not
			-- the talent's: Seal of Command's began "60 Mana", "Instant".)
			local last = nil
			for _, line in ipairs(data.lines) do
				local text = type(line) == "table" and line.leftText
				if type(text) == "string" and not secret(text) and text ~= "" then
					last = text
				end
			end
			if last then
				return last
			end
		end
	end
	return words(id)
end

-- TALENTS THAT CHANGE WHAT GEAR GIVES (Josh 2026-11-18: "Let's add those 2-3
-- you recommend"). By id, from the game's tables; the number is which one
-- of the talent's words is its percent.
--   armor  "Increases your armor value from items by 10%": Toughness, the
--          paladin's and the warrior's
--   block  "Increases the amount of damage absorbed by your shield by 30%":
--          Shield Specialization, the paladin's and the shaman's
--   hands  more damage while a weapon of that kind is held: the weapon
--          specializations. `holy`: the paladin's two-handed one, which
--          says "Physical and Holy".
Rd.GEAR_TALENTS = {
	[20143] = { armor = 1 }, [12299] = { armor = 1 },
	[20148] = { block = 1 }, [20149] = { block = 1 }, [20150] = { block = 1 },
	[16253] = { block = 2 }, [16298] = { block = 2 }, [16299] = { block = 2 }, [16300] = { block = 2 }, [16301] = { block = 2 },
	[12163] = { hands = "twoHand" }, [20111] = { hands = "twoHand", holy = true }, [20196] = { hands = "oneHand" },
}
-- Returns { armor = percent, block = percent, twoHand = { pct, holy },
-- oneHand = { pct } }, each only where you have the talent.
-- `known(id)`, `describe(id)`: the game's calls, handed in.
function Rd.GearTalents(known, describe)
	local out = {}
	for id, t in pairs(Rd.GEAR_TALENTS) do
		if known(id) then
			local n = Rd.Numbers(describe(id) or "")
			local pct = n[t.armor or t.block or 1] or 0
			if pct > 0 and pct <= 100 then
				if t.armor then
					out.armor = math.max(out.armor or 0, pct)
				elseif t.block then
					out.block = math.max(out.block or 0, pct)
				elseif not out[t.hands] or pct > out[t.hands].pct then
					out[t.hands] = { pct = pct, holy = t.holy }
				end
			end
		end
	end
	return out
end
local function knows(id)
	local ok, known = pcall(IsPlayerSpell or IsSpellKnown, id)
	return ok and known == true
end
local gear, gearAt
function Rd.Gear()
	local t = GetTime and GetTime() or 0
	if not (gear and gearAt and t - gearAt < 5) then
		gear, gearAt = Rd.GearTalents(knows, Rd.TalentWords), t
	end
	return gear
end

-- WHICH WAY YOU FIGHT, BY YOUR TALENTS (Josh 2026-11-18: "We need to
-- determine which one by which talents they have selected"). Each way of a
-- class lists the talents only it takes. The way with the most of them
-- known is yours. None known, or two ways level: nil, and the sum follows
-- your gear (Roles.lua). `known(id)`: the game's call, handed in.
function Rd.Spec(specs, known)
	local best, most, level = nil, 0, false
	for name, spec in pairs(specs) do
		local n = 0
		for id in pairs(spec.marks or {}) do
			if known(id) then
				n = n + 1
			end
		end
		if n > most then
			best, most, level = name, n, false
		elseif n == most and n > 0 then
			level = true
		end
	end
	return not level and best or nil
end

-- CRIT TALENTS (Josh 2026-11-18: "Let's do the crit"). Each passive in the
-- tables' list that you know puts what it does on the abilities it touches
-- (Roles.lua, what crits add). Its amount is the number its description
-- says now, where that can be read, since your points in a talent change
-- it; the table's otherwise. Two ranks of one talent: the higher counts.
-- `known(id)`, `describe(id)`: the game's calls, handed in so this is plain.
local TALENT = { crit = "critAdd", more = "critMore", after = "critAfter" }
function Rd.Talents(kit, list, known, describe)
	if not (kit.abilities and type(list) == "table") then
		return
	end
	local best = {}
	for id, t in pairs(list) do
		-- (`spec`: a form's, which counts for the way of fighting in it only)
		if known(id) and (not t.spec or kit.spec == t.spec) then
			for what, field in pairs(TALENT) do
				if t[what] then
					local said = t.nth and t.nth > 0 and describe and Rd.Numbers(describe(id) or "")[t.nth]
					local amount = said and said > 0 and said <= 300 and said or t[what]
					local slot = (t.of or id) .. field
					if not best[slot] or amount > best[slot].amount then
						best[slot] = { amount = amount, field = field, keys = t.keys }
					end
				end
			end
		end
	end
	for _, one in pairs(best) do
		for key in pairs(one.keys) do
			local a = kit.abilities[key]
			if a then
				a[one.field] = (a[one.field] or 0) + one.amount
			end
		end
	end
end
-- THE PALADIN'S TALENTS (Josh 2026-11-18: "Let's finish the paladin stuff").
-- The ones that change what a piece of gear is worth, each by its id. Its
-- amounts are the numbers its description says now, in order, since your
-- points in it change them. A talent that only makes everything a set
-- percent bigger is not here: it is in both sides of a comparison.
--   Vengeance             percent, seconds, stacks: damage after a crit
--   Sanctified Judgement  chance, percent: the judged seal's mana back
--   Improved Judgement    seconds off Judgement's cooldown
--   Illumination          chance, percent: a heal's mana back after a crit
--   Holy Power            percent more of what a heal crit adds
--   Improved Flash of Light  percent more chance for it to crit
-- `known(id)`, `describe(id)`: the game's calls, handed in.
Rd.PALADIN = {
	[20049] = "vengeance", [1311074] = "judgeBack", [25956] = "judgeSooner", [20210] = "illumination", [5923] = "holyPower",
	[20249] = "flash", [20250] = "flash", [20251] = "flash",
}
function Rd.PaladinTalents(kit, known, describe)
	local flash, power = 0, 0
	for id, what in pairs(Rd.PALADIN) do
		if known(id) then
			local n = Rd.Numbers(describe(id) or "")
			local a, b, c = n[1] or 0, n[2] or 0, n[3] or 0
			if what == "vengeance" and a > 0 and a <= 50 and b > 0 then
				kit.vengeance = { pct = a, secs = b, stacks = c >= 1 and c or 1 }
			elseif what == "judgeBack" and a > 0 and a <= 100 and b > 0 and b <= 100 then
				kit.judgeBack = a / 100 * b / 100
			elseif what == "judgeSooner" and a > 0 and kit.judgement and not kit.judgement.sooner then
				-- (the game's call gives the cooldown without talents)
				kit.judgement.sooner = a
				kit.judgement.cooldown = math.max(1.5, kit.judgement.cooldown - a)
			elseif what == "illumination" and a > 0 and a <= 100 and b > 0 and b <= 100 then
				kit.back = a / 100 * b / 100
			elseif what == "holyPower" and a > 0 and a <= 300 then
				power = math.max(power, a)
			elseif what == "flash" and a > 0 and a <= 100 then
				flash = math.max(flash, a)
			end
		end
	end
	for _, h in ipairs(kit.heals or {}) do
		if power > 0 then
			h.critMore = (h.critMore or 0) + power
		end
		if flash > 0 and h.key == "flashOfLight" then
			h.critAdd = (h.critAdd or 0) + flash
		end
	end
end

-- `kit.unread`: the ids of spells the model prices whose descriptions did
-- not have the numbers the list says (see LIMIT, above).
function Rd.Kit(s)
	-- (`at.spells`: your spell power in every school as the descriptions
	-- were read, for a caster's spells)
	local spells = {}
	for school, amount in pairs(s.spellDamage) do
		spells[school] = amount
	end
	local kit = { seals = {}, heals = {}, at = { spell = s.spellDamage[2], healing = s.healing, spells = spells,
		crits = s.spellCrits, crit = s.spellCrit } }
	-- the ways your class fights, where it has more than one, and which is
	-- yours by your talents (Rd.Spec)
	do
		local data = UP.SpellData
		local _, class = UnitClass("player")
		local specs = type(data) == "table" and type(data.specs) == "table" and data.specs[class] or nil
		if type(specs) == "table" then
			kit.specs = specs
			kit.spec = Rd.Spec(specs, function(id)
				local ok, known = pcall(IsPlayerSpell or IsSpellKnown, id)
				return ok and known == true
			end)
		end
	end
	local heals = {}
	eachPriced(function(id, item, entry)
		if not entry or item.isPassive then
			return
		end
		local v = Rd.Planned(entry.read, words(id))
		if not v then
			kit.unread = kit.unread or {}
			kit.unread[#kit.unread + 1] = id
			return
		end
		local heal = entry.is:match("^heal:(.+)$")
		if heal then
			local spell = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
			local cast = type(spell) == "table" and num(spell.castTime) or 0
			if v.amount then
				local name = type(item.name) == "string" and not secret(item.name) and item.name or heal
				heals[#heals + 1] = { name = name, amount = v.amount, cast = cast / 1000, cost = cost(id), id = id, key = heal,
					share = Rd.HealShare(entry, v.amount, s.healing, s.level) }
			end
		elseif ROLES[entry.is] then
			ROLES[entry.is](kit, id, v, entry)
		end
	end)
	-- HOLY STRIKE READS HIGHER UNDER SEAL OF THE CRUSADER (the same fights:
	-- "60.5% weapon damage plus 38" with the seal up, "43.2% plus 19.5"
	-- without). What it says with the seal down is kept, and used while the
	-- seal is up, moved by any spell power gained since.
	local db = UP.DB()
	local strike = kit.holyStrike
	if strike and not s.crusader then
		db.holyStrike = { level = s.level, percent = strike.percent, holy = strike.holy, spell = s.spellDamage[2] }
	elseif strike then
		local kept = db.holyStrike
		if type(kept) == "table" and kept.level == s.level then
			strike.percent = kept.percent
			strike.holy = kept.holy + (strike.share or 0.429) * (s.spellDamage[2] - kept.spell)
		else
			-- never seen without it: the weapon share is 1.4 times too high
			strike.percent = strike.percent / 1.4
		end
	end
	kit.heals = heals
	local data = UP.SpellData
	local _, class = UnitClass("player")
	-- (their words at your rank: Rd.TalentWords)
	Rd.Talents(kit, type(data) == "table" and type(data.talents) == "table" and data.talents[class] or nil, knows, Rd.TalentWords)
	if class == "PALADIN" then
		Rd.PaladinTalents(kit, knows, Rd.TalentWords)
	end
	return kit
end

-- A LINE OF THE GAME'S OWN, AS A PATTERN (2026-11-17, with the spells): a
-- weapon's damage, its speed and a shield's block are lines of an item's
-- tooltip, written from the client's own sentences ("%s - %s Damage"). The
-- sentence is asked of the client and each %s or %d in it stands for a
-- number, so the line is known in whatever language the client speaks.
-- `fallback`: the English, for a client without the sentence.
-- (each sentence's pattern is built once and kept by the sentence: a
-- weapon's tooltip asked for three of them on every line)
local shapes = {}
local function shape(key, fallback)
	local said = type(_G[key]) == "string" and not secret(_G[key]) and _G[key] or fallback
	if shapes[said] then
		return shapes[said]
	end
	local text = said:gsub("%%%d%$", "%%")
	text = text:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	text = text:gsub("%%[sd]", "([%%d%%.,]+)")
	shapes[said] = "^" .. text
	return shapes[said]
end
Rd.Shape = shape

function Rd.ItemStats(link)
	local stats = link and C_Item and C_Item.GetItemStats and C_Item.GetItemStats(link)
	if type(stats) ~= "table" then
		return {}
	end
	local out = {}
	for k, v in pairs(stats) do
		if type(k) == "string" and num(v) then
			out[k] = v
		end
	end
	-- A SHIELD'S BLOCK is not among its stats (probe, 2026-11-16: a shield
	-- whose tooltip says "11 Block" listed armor, stamina and intellect
	-- only), so it is read from the tooltip's words
	if Rd.Where(link) == "INVTYPE_SHIELD" then
		local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
		for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
			local left = line.leftText
			local block = type(left) == "string" and not secret(left) and left:match(shape("SHIELD_BLOCK_TEMPLATE", "%d Block") .. "$")
			if block then
				out.UPGRADES_BLOCK = Rd.Number(block)
			end
		end
	end
	return out
end

-- AN ITEM'S OTHER EFFECTS (Josh 2026-11-17: "Let's fix 1-4"; an item with a
-- "Use:" or the third piece of a set had counted for nothing).
--
-- Rd.Priced is what an item is priced as: its stats, and what its "Use:"
-- gives where that is a stat, for the share of the time it can be up (a
-- trinket with 20 seconds of 150 attack power every 2 minutes is 25 attack
-- power). The list is SpellData.uses, from the game's tables. The swap check
-- still uses Rd.ItemStats: a "Use:" is not on your sheet until pressed.
function Rd.Priced(link)
	local out = Rd.ItemStats(link)
	local data = UP.SpellData
	local id = link and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
	local use = type(id) == "number" and type(data) == "table" and type(data.uses) == "table" and data.uses[id]
	for k, v in pairs(type(use) == "table" and use or {}) do
		out[k] = (out[k] or 0) + v
	end
	return out
end
-- true for an item with an effect that is not counted (SpellData.partly):
-- the tooltip says so
function Rd.Partly(link)
	local data = UP.SpellData
	local id = link and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
	return type(id) == "number" and type(data) == "table" and type(data.partly) == "table" and data.partly[id] ~= nil
end

-- A SET'S BONUSES, GAINED AND LOST. Putting `link` on in place of `off`
-- changes how many pieces of a set you wear. Each bonus that starts or
-- stops counting is found (SpellData.sets, SpellData.setOf): `worn`, the
-- pieces of each set on you now, by set. Returns the stats of the bonuses
-- lost, of those gained, and true where one of them is not a stat and so
-- is not counted. Pure: `pieces` and the ids are handed in.
function Rd.SetChange(data, pieces, newId, offIds)
	local lost, gained, partly = {}, {}, false
	if not (type(data) == "table" and type(data.sets) == "table" and type(data.setOf) == "table") then
		return lost, gained, partly
	end
	local delta = {}
	local newSet = newId and data.setOf[newId]
	if newSet then
		delta[newSet] = (delta[newSet] or 0) + 1
	end
	for _, id in pairs(offIds or {}) do
		local set = data.setOf[id]
		if set then
			delta[set] = (delta[set] or 0) - 1
		end
	end
	for set, change in pairs(delta) do
		local before = pieces[set] or 0
		local after = before + change
		for _, bonus in ipairs(change ~= 0 and data.sets[set] or {}) do
			local had, has = before >= bonus[1], after >= bonus[1]
			if had ~= has then
				if type(bonus[2]) ~= "table" then
					partly = true
				else
					local into = had and lost or gained
					for k, v in pairs(bonus[2]) do
						into[k] = (into[k] or 0) + v
					end
				end
			end
		end
	end
	return lost, gained, partly
end
-- the pieces of each set on you now, by set
function Rd.SetPieces()
	local data = UP.SpellData
	local pieces = {}
	for slot = 1, 19 do
		local id = GetInventoryItemID and GetInventoryItemID("player", slot)
		local set = type(id) == "number" and type(data) == "table" and type(data.setOf) == "table" and data.setOf[id]
		if set then
			pieces[set] = (pieces[set] or 0) + 1
		end
	end
	return pieces
end

-- a weapon's own damage and speed, from its tooltip's words
function Rd.Weapon(link)
	local data = link and C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
	if type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local w = {}
	for _, line in ipairs(data.lines) do
		local left, right = line.leftText, line.rightText
		if type(left) == "string" and not secret(left) then
			local low, high = left:match(shape("DAMAGE_TEMPLATE", "%s - %s Damage"))
			if low and not w.min then
				w.min, w.max = Rd.Number(low), Rd.Number(high)
			end
		end
		if type(right) == "string" and not secret(right) then
			local speed = right:match(shape("SPEED", "Speed") .. " ([%d%.,]+)")
			if speed then
				w.speed = Rd.Number(speed)
			end
		end
		if type(left) == "string" and not secret(left) and left:find(shape("ITEM_SPELL_TRIGGER_ONPROC", "Chance on hit:")) then
			w.proc = Rd.Proc(left, link)
		end
	end
	-- its chance on hit from the game's tables, where it is listed there:
	-- the words are then not needed (Rd.ListedProc)
	w.proc = Rd.ListedProc(link) or w.proc
	if w.min and w.max and w.speed then
		return w
	end
	return nil
end

-- A WEAPON'S "CHANCE ON HIT" (Josh 2026-11-16, of Searing Blade's "Hurls a
-- fiery ball that causes 80 Fire damage and an additional 18 damage over 6
-- sec": "It would be really cool if we could factor that into the stats as
-- well"). The damage is read from the line's words: a range's middle or a
-- plain amount, plus any "additional N damage". Named for a school of magic,
-- armor takes none of it.
--
-- HOW OFTEN IS NOT SAID ANYWHERE, SO EVERY PROC GETS THE SAME RATE (Josh
-- 2026-11-16: "All procs will have different rates, so we can't just
-- measure the sword... Is there some API we can use to determine this per
-- item, rather than trying to measure?"). There is none. The tooltip does
-- not say. The client's tables were read for all 457 chance-on-hit effects
-- (build 70888): none has an item cooldown, a proc cooldown or a
-- procs-per-minute entry, and the chance is a placeholder (101). The rate
-- and any hidden cooldown are the server's. Measuring the worn weapon and
-- guessing the hovered one would compare a known against a guess, so
-- neither is measured.
-- GUESS: 2 a minute, for every weapon. Two proc weapons then compare by
-- what a proc does.
Rd.PROC_PER_MINUTE = 2
-- WHAT IT DOES, FROM THE GAME'S TABLES (2026-11-17, SpellData.procs: every
-- weapon's chance on hit, its damage added up from its spell's effects and
-- whether it is magic). A weapon listed there needs none of its words read.
-- One that is not listed is read from its line, in English, as before.
function Rd.ListedProc(link)
	local data = UP.SpellData
	local id = link and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
	local listed = type(id) == "number" and type(data) == "table" and type(data.procs) == "table" and data.procs[id]
	if type(listed) ~= "table" then
		return nil
	end
	return { damage = listed[1], magic = listed[2] and true or false, perMinute = Rd.PROC_PER_MINUTE, item = id }
end
function Rd.Proc(text, link)
	text = text:gsub(",", "")
	local damage, magic = 0, false
	local SCHOOLS = { Fire = true, Frost = true, Nature = true, Shadow = true, Holy = true, Arcane = true }
	local rest = text:gsub("(%d+) to (%d+) (%a*) ?damage", function(low, high, school)
		damage = damage + (tonumber(low) + tonumber(high)) / 2
		magic = magic or SCHOOLS[school] or false
		return ""
	end)
	rest = rest:gsub("additional (%d+) damage", function(n)
		damage = damage + tonumber(n)
		return ""
	end)
	rest:gsub("(%d+) (%a+) damage", function(n, school)
		if SCHOOLS[school] then
			damage = damage + tonumber(n)
			magic = true
		end
	end)
	if damage <= 0 then
		return nil
	end
	local id = link and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
	return { damage = damage, magic = magic, perMinute = Rd.PROC_PER_MINUTE, item = id }
end

local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
	INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- whether a weapon is a dagger (the game's item class 2, subclass 15)
function Rd.Dagger(link)
	if not (link and C_Item and C_Item.GetItemInfoInstant) then
		return false
	end
	local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(link)
	return class == 2 and sub == 15
end

local function where(link)
	if not (link and C_Item and C_Item.GetItemInfoInstant) then
		return nil
	end
	local _, _, _, loc = C_Item.GetItemInfoInstant(link)
	return loc
end
Rd.Where = where
function Rd.TwoHanded(link)
	return where(link) == "INVTYPE_2HWEAPON"
end

-- THE SLOTS A PIECE COULD GO IN. A one-hand weapon goes in the main hand.
-- It goes in either hand where you hold a weapon in the off hand now
-- (review 2026-11-18: a rogue with two daggers got one row for a sword,
-- against the main hand only; a ring gets a row for each finger).
-- `offKind`: what the off hand holds, as the game names its kind.
function Rd.Slots(loc, offKind)
	if loc == "INVTYPE_WEAPON" and (offKind == "INVTYPE_WEAPON" or offKind == "INVTYPE_WEAPONOFFHAND") then
		return { 16, 17 }
	end
	return loc and SLOTS[loc] or nil
end

-- THE OTHER HAND, FROM YOUR BAGS (Josh 2026-11-17, a shield in his bags with
-- a two-hander worn, and no numbers on it: "Is there any way we can show
-- Upgrades for situations like this? We would need to combine mainhand and
-- offhand and compare against the 2h"). A shield cannot go on beside a
-- two-hander, so there was no swap to price. The game's own comparison
-- already answers this: it picks a one-hand weapon from your bags to go
-- with the shield ("With Death Speaker Scepter equipped in your
-- main-hand"), and Shift-C goes through the others. The same call says
-- which, so the numbers are for the pair the game is showing: the
-- two-hander off, the hovered piece and its partner on. The other way
-- round too: a one-hand weapon hovered is paired with an off hand from
-- your bags.
-- Returns the partner's link and which hand it is for ("main" or "off"),
-- or nil where the game pairs it with nothing.
function Rd.Partner(link)
	local E = Enum and Enum.TooltipComparisonMethod
	if not (link and E and C_TooltipComparison and C_TooltipComparison.GetItemComparisonInfo) then
		return nil
	end
	local ok, info = pcall(C_TooltipComparison.GetItemComparisonInfo, { hyperlink = link })
	if not ok or type(info) ~= "table" or secret(info.method) then
		return nil
	end
	local hand = (info.method == E.WithBagMainHandItem and "main") or (info.method == E.WithBagOffHandItem and "off") or nil
	local list = info.additionalItems
	if not hand or type(list) ~= "table" or #list == 0 then
		return nil
	end
	-- the one the game is showing now (Shift-C moves its count along)
	local index = 1
	local shown = rawget(_G, "TooltipComparisonManager")
	if type(shown) == "table" and type(shown.comparisonIndex) == "number" and type(shown.compareInfo) == "table"
		and shown.compareInfo.method == info.method then
		index = shown.comparisonIndex
	end
	local item = list[index] or list[1]
	local partner = type(item) == "table" and (item.hyperlink or (item.guid and C_Item.GetItemLinkByGUID and C_Item.GetItemLinkByGUID(item.guid)))
	if type(partner) ~= "string" or secret(partner) then
		return nil
	end
	return partner, hand
end

-- THE SWAPS THIS ITEM COULD BE. Each is what comes off (one piece, or the
-- main hand and the off hand for a two-hander) and, for a weapon, both
-- weapons' own damage. A ring or trinket gives two. Nothing for an item you
-- are wearing, or for an off hand while a two-hander is worn.
function Rd.Swaps(link)
	local loc = where(link)
	local slots = Rd.Slots(loc, where(GetInventoryItemLink("player", 17)))
	if not slots then
		return {}
	end
	-- on you already, in any slot it fits: nothing to swap
	for _, slot in ipairs(slots) do
		if GetInventoryItemLink("player", slot) == link then
			return {}
		end
	end
	local out = {}
	local partner, hand = Rd.Partner(link)
	for _, slot in ipairs(slots) do
		local worn = GetInventoryItemLink("player", slot)
		local off = { worn }
		local ok = worn ~= link
		-- the piece from your bags that goes on with it (Rd.Partner)
		local with = nil
		local main = GetInventoryItemLink("player", 16)
		if loc == "INVTYPE_2HWEAPON" then
			off[#off + 1] = GetInventoryItemLink("player", 17)
		elseif slot == 17 and where(main) == "INVTYPE_2HWEAPON" then
			-- an off hand with a two-hander worn: the two-hander comes off,
			-- this and a main hand from your bags go on
			if partner and hand == "main" then
				with, worn, off = partner, main, { main }
			else
				ok = false
			end
		elseif slot == 16 and where(main) == "INVTYPE_2HWEAPON" and partner and hand == "off" then
			-- a one-hand weapon with a two-hander worn: an off hand from
			-- your bags goes on with it
			with = partner
		end
		if ok then
			local stats = {}
			local offIds = {}
			for _, l in pairs(off) do
				for k, v in pairs(Rd.Priced(l)) do
					stats[k] = (stats[k] or 0) + v
				end
				offIds[#offIds + 1] = C_Item.GetItemInfoInstant(l)
			end
			local swap = { slot = slot, worn = stats, wornLink = worn }
			-- the set bonuses the change starts or stops: those lost come off
			-- with the worn piece, those gained go on with the new one
			local lost, gained, partly = Rd.SetChange(UP.SpellData, Rd.SetPieces(), (C_Item.GetItemInfoInstant(link)), offIds)
			for k, v in pairs(lost) do
				stats[k] = (stats[k] or 0) + v
			end
			swap.gains = gained
			-- an effect of the new piece or of a worn one that is not counted
			swap.partly = partly or Rd.Partly(link)
			-- its partner from your bags: priced with it (Tiles.lua)
			if with then
				swap.with = with
				swap.partly = swap.partly or Rd.Partly(with)
				local _, more, alsoPartly = Rd.SetChange(UP.SpellData, Rd.SetPieces(), (C_Item.GetItemInfoInstant(with)), {})
				for k, v in pairs(more) do
					gained[k] = (gained[k] or 0) + v
				end
				swap.partly = swap.partly or alsoPartly
			end
			for _, l in pairs(off) do
				swap.partly = swap.partly or Rd.Partly(l)
			end
			-- whether a shield is worn after it: a two-hander takes it off
			-- (whether a two-hander is worn after it)
			if loc == "INVTYPE_2HWEAPON" then
				swap.twoHand = true
			elseif slot == 16 or with then
				swap.twoHand = false
			end
			if loc == "INVTYPE_2HWEAPON" then
				swap.shield = false
			elseif slot == 17 then
				swap.shield = loc == "INVTYPE_SHIELD"
			elseif with then
				swap.shield = where(with) == "INVTYPE_SHIELD"
			end
			-- whether the main hand is a dagger after it, and what the off
			-- hand swings with: a weapon's own numbers, or nothing
			if slot == 16 then
				swap.dagger = Rd.Dagger(link)
			elseif with and hand == "main" then
				swap.dagger = Rd.Dagger(with)
			end
			if loc == "INVTYPE_2HWEAPON" then
				swap.off = false
			elseif slot == 17 then
				swap.off = (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND") and Rd.Weapon(link) or false
			elseif with and hand == "off" then
				local kind = where(with)
				swap.off = (kind == "INVTYPE_WEAPON" or kind == "INVTYPE_WEAPONOFFHAND") and Rd.Weapon(with) or false
			end
			if slot == 18 then
				-- a ranged weapon: its own damage and speed (Math.lua, 5b)
				local new = Rd.Weapon(link)
				if new then
					swap.weapons = { worn = Rd.Weapon(worn), new = new, ranged = true }
				end
			elseif slot == 16 then
				local new = Rd.Weapon(link)
				if not new then
					ok = false
				end
				swap.weapons = { worn = Rd.Weapon(worn), new = new }
			elseif with then
				-- (an off hand hovered: the weapon that changes is its partner)
				local new = Rd.Weapon(with)
				if not new then
					ok = false
				end
				swap.weapons = { worn = Rd.Weapon(worn), new = new }
			end
			if ok then
				out[#out + 1] = swap
			end
		end
	end
	return out
end
