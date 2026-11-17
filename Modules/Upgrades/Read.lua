-- WHAT THE GAME SAYS, IN THE SHAPE THE MATH TAKES (Josh 2026-11-16).
--
-- Every game call Upgrades makes for its numbers is in this file: your
-- totals, the rates the character sheet uses, what your spells do right now,
-- and an item's stats. Math.lua and Roles.lua take what this hands them and
-- call nothing.
--
-- PALADIN ONLY, ENGLISH ONLY, for now: a spell's numbers are read out of its
-- description's words ("Heals a friendly target for 376 to 417."), because
-- those words are the game's own answer with your spell power and talents
-- already counted (probe, 2026-11-16).
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

-- your totals as you stand; nil if the game keeps any of them back
function Rd.State()
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
	local weapon = Rd.Weapon(GetInventoryItemLink("player", 16))
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
	s.hit = (num(GetHitModifier and GetHitModifier()) or 0) + (num(GetCombatRatingBonus(HIT_MELEE)) or 0)
	s.spellHit = (num(GetSpellHitModifier and GetSpellHitModifier()) or 0) + (num(GetCombatRatingBonus(HIT_SPELL)) or 0)
	s.dodge = num(GetDodgeChance()) or 0
	s.parry = num(GetParryChance()) or 0
	s.block = num(GetBlockChance and GetBlockChance()) or 0
	s.blockValue = num(GetShieldBlock and GetShieldBlock()) or 0
	s.shield = C_PaperDollInfo and C_PaperDollInfo.OffhandHasShield and C_PaperDollInfo.OffhandHasShield() and true or false
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

-- what one point is worth, asked of the functions the character sheet calls
function Rd.Rates(s)
	local r = { attackPowerPer = {}, multiplier = Rd.Multipliers() }
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
	return r
end

local function words(id)
	local text = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
	if type(text) ~= "string" or secret(text) then
		return ""
	end
	return (text:gsub(",", ""))
end

local function cost(id)
	local costs = C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(id)
	local first = type(costs) == "table" and costs[1]
	return first and num(first.cost) or 0
end

local function middle(a, b)
	a, b = tonumber(a), tonumber(b)
	return a and b and (a + b) / 2 or nil
end

-- name -> what to read out of the description, and where it goes in the kit
local SPELLS = {
	["Holy Strike"] = function(kit, id, text)
		local percent, low, high = text:match("causes ([%d%.]+)%% weapon damage plus an additional (%d+) to (%d+)")
		local seconds = num(GetSpellBaseCooldown and GetSpellBaseCooldown(id))
		if percent and seconds and seconds > 0 then
			kit.holyStrike = { percent = tonumber(percent) / 100, holy = middle(low, high), cost = cost(id), cooldown = seconds / 1000 }
		end
	end,
	["Judgement"] = function(kit, id)
		local seconds = num(GetSpellBaseCooldown and GetSpellBaseCooldown(id))
		if seconds and seconds > 0 then
			kit.judgement = { cost = cost(id), cooldown = seconds / 1000 }
		end
	end,
	-- "doing 16 Holy damage over 8 sec ... will take an additional 49 damage
	-- over 8 sec": both parts, for each enemy in it
	["Consecration"] = function(kit, id, text)
		local first = text:match("doing (%d+) Holy damage over")
		local second = text:match("additional (%d+) damage over")
		local seconds = num(GetSpellBaseCooldown and GetSpellBaseCooldown(id))
		if first and seconds and seconds > 0 then
			kit.consecration = { total = tonumber(first) + (tonumber(second) or 0), cost = cost(id), cooldown = seconds / 1000 }
		end
	end,
	-- "Increases all threat generated by 33%, and all threat generated by
	-- your Holy attacks by an additional 90%."
	["Righteous Fury"] = function(kit, _, text)
		local all = text:match("all threat generated by (%d+)%%")
		local holy = text:match("Holy attacks by an additional (%d+)%%")
		if all then
			kit.righteousFury = { all = 1 + tonumber(all) / 100, holy = 1 + (tonumber(holy) or 0) / 100 }
		end
	end,
	-- "...Unleashing this Seal's energy will judge an enemy for 40 sec,
	-- increasing Holy damage taken by up to 58."
	["Seal of the Crusader"] = function(kit, id, text)
		local holy = text:match("Holy damage taken by up to (%d+)")
		if holy then
			kit.crusader = { holy = tonumber(holy), cost = cost(id) }
		end
	end,
	["Seal of Command"] = function(kit, id, text)
		local percent = text:match("equal to (%d+)%% of normal weapon damage")
		if percent then
			kit.seals.command = { percent = tonumber(percent) / 100, cost = cost(id),
				judge = middle(text:match("instantly causing (%d+) to (%d+) Holy damage")) }
		end
	end,
	["Seal of Righteousness"] = function(kit, id, text)
		local low, high = text:match("additional (%d+) to (%d+) Holy damage")
		if low then
			kit.seals.righteousness = { low = tonumber(low), high = tonumber(high), cost = cost(id),
				judge = middle(text:match("will cause (%d+) to (%d+) Holy damage")) }
		end
	end,
	["Seal of Fury"] = function(kit, id, text)
		local hit = text:match("additional (%d+) Holy damage")
		if hit then
			kit.seals.fury = { hit = tonumber(hit), cost = cost(id),
				judge = middle(text:match("inflicts (%d+) to (%d+) Holy damage")) }
		end
	end,
}
-- heals, with each one's share of spell power (SpellEffect table)
local HEALS = { ["Holy Light"] = 0.714, ["Flash of Light"] = 0.429 }

-- What your spells do now. Every rank is in the spellbook, lowest first, so
-- the last one read for a name is the highest you know.
-- A BUFF OR A PASSIVE THAT MULTIPLIES A STAT (Josh's chat lines, 2026-11-16,
-- with Blessing of Kings up: "expected intellect 76.0 after that swap. The
-- game says 77.0", and his own reading of it: "Probably because I have
-- blessing of kings"). Kings is "Increases stats by 10%", and that 10% works
-- on the stats a piece of gear gives too, so 10 intellect on an item is 11.
-- Math.lua has had a multiplier for each stat from the start; nothing ever
-- filled it in.
--
-- The game has no call for it. So the words are read: each buff on you, and
-- each passive in your spellbook, is looked up and its description searched
-- for "stats by N%" or "<a stat> by N%". Buffs cannot be read in combat, so
-- what was found last is kept until they can.
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
			percents(words(id), found)
		end
	end
	-- and your passives
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if type(info) == "table" then
				local first = (info.itemIndexOffset or 0) + 1
				for index = first, first + (info.numSpellBookItems or 0) - 1 do
					local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
					if type(item) == "table" and item.isPassive and item.spellID and not secret(item.spellID) then
						percents(words(item.actionID or item.spellID), found)
					end
				end
			end
		end
	end
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
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
		return nil
	end
	local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if type(info) == "table" then
			local first = (info.itemIndexOffset or 0) + 1
			for index = first, first + (info.numSpellBookItems or 0) - 1 do
				local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
				if type(item) == "table" and item.name == "Seal of the Crusader" then
					local ap = words(item.actionID or item.spellID):match("granting (%d+) melee attack power")
					crusaderPower = tonumber(ap) or crusaderPower
				end
			end
		end
	end
	return crusaderPower
end

function Rd.Kit(s)
	local kit = { seals = {}, heals = {}, at = { spell = s.spellDamage[2], healing = s.healing } }
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
		return kit
	end
	local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	local heals = {}
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if type(info) == "table" then
			local first = (info.itemIndexOffset or 0) + 1
			for index = first, first + (info.numSpellBookItems or 0) - 1 do
				local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
				if type(item) == "table" and not item.isPassive and type(item.name) == "string" and not secret(item.name) then
					local id = item.actionID or item.spellID
					if SPELLS[item.name] then
						SPELLS[item.name](kit, id, words(id))
					elseif HEALS[item.name] then
						local amount = middle(words(id):match("for (%d+) to (%d+)"))
						local spell = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
						local cast = type(spell) == "table" and num(spell.castTime) or 0
						if amount then
							heals[item.name] = { name = item.name, amount = amount, share = HEALS[item.name],
								cast = cast / 1000, cost = cost(id) }
						end
					end
				end
			end
		end
	end
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
			strike.holy = kept.holy + 0.429 * (s.spellDamage[2] - kept.spell)
		else
			-- never seen without it: the weapon share is 1.4 times too high
			strike.percent = strike.percent / 1.4
		end
	end
	for _, h in pairs(heals) do
		kit.heals[#kit.heals + 1] = h
	end
	return kit
end

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
			local block = type(left) == "string" and not secret(left) and left:match("^(%d+) Block$")
			if block then
				out.UPGRADES_BLOCK = tonumber(block)
			end
		end
	end
	return out
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
			local low, high = left:gsub(",", ""):match("^([%d%.]+) %- ([%d%.]+) Damage")
			if low and not w.min then
				w.min, w.max = tonumber(low), tonumber(high)
			end
		end
		if type(right) == "string" and not secret(right) then
			local speed = right:match("Speed ([%d%.]+)")
			if speed then
				w.speed = tonumber(speed)
			end
		end
		if type(left) == "string" and not secret(left) and left:find("^Chance on hit:") then
			w.proc = Rd.Proc(left, link)
		end
	end
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

local function where(link)
	if not (link and C_Item and C_Item.GetItemInfoInstant) then
		return nil
	end
	local _, _, _, loc = C_Item.GetItemInfoInstant(link)
	return loc
end
Rd.Where = where

-- THE SWAPS THIS ITEM COULD BE. Each is what comes off (one piece, or the
-- main hand and the off hand for a two-hander) and, for a weapon, both
-- weapons' own damage. A ring or trinket gives two. Nothing for an item you
-- are wearing, or for an off hand while a two-hander is worn.
function Rd.Swaps(link)
	local loc = where(link)
	local slots = loc and SLOTS[loc]
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
	for _, slot in ipairs(slots) do
		local worn = GetInventoryItemLink("player", slot)
		local off = { worn }
		local ok = worn ~= link
		if loc == "INVTYPE_2HWEAPON" then
			off[#off + 1] = GetInventoryItemLink("player", 17)
		elseif slot == 17 and where(GetInventoryItemLink("player", 16)) == "INVTYPE_2HWEAPON" then
			ok = false
		end
		if ok then
			local stats = {}
			for _, l in pairs(off) do
				for k, v in pairs(Rd.ItemStats(l)) do
					stats[k] = (stats[k] or 0) + v
				end
			end
			local swap = { slot = slot, worn = stats, wornLink = worn }
			-- whether a shield is worn after it: a two-hander takes it off
			if loc == "INVTYPE_2HWEAPON" then
				swap.shield = false
			elseif slot == 17 then
				swap.shield = loc == "INVTYPE_SHIELD"
			end
			if slot == 16 then
				local new = Rd.Weapon(link)
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
