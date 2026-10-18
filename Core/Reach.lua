-- How far your skills reach (Josh 2026-10-17: "the unit frame range fader
-- doesnt seem to match actual auto shot range of the hunder. We should make
-- sure the faders line up with the proper skill distance for each class").
--
-- THE GAME'S OWN ANSWER, SPELL BY SPELL. The client says whether a spell of
-- yours reaches a unit (C_Spell.IsSpellInRange), and it counts a spell's
-- least reach as well as its most: in September Throw and Charge answered
-- "out of range" inside 8 yards. That is the hunter's dead zone for Auto
-- Shot too. Each class has spells for an enemy in melee, spells for an enemy
-- further off, and spells for a friend:
--
--   R.Band   how near: "melee", "ranged" or "out" - the resource display's
--            crosshair, green, yellow or red (Modules/ResourceDisplay)
--   R.Any    whether any of them reaches: what a target, focus or boss frame
--            fades by (Modules/UnitFrames/Unit.lua), so a hunter hitting
--            with Raptor Strike in melee is not faded
--
-- TALENTS COUNT (Josh 2026-10-18: "This should be smart also, because some
-- talents increase range"). The client's answer is the spell's reach as you
-- have it, Hawk Eye's or Arctic Reach's yards included. A class's ranged
-- spells are one of each school its talents lengthen, and the band is
-- "ranged" when any of them reaches, so the longest decides.
--
-- A spell you don't know answers nothing, and the next one is asked. Each
-- is asked by its number, then by its name, which finds whichever rank your
-- spellbook has. An answer the client keeps secret is handed on as it came:
-- nothing of ours may read it, so it cannot be weighed against another.
--
-- The 28-yard check this replaced (CheckInteractDistance) is refused in a
-- fight. These are the action bars' own question, asked of every button in
-- every fight. Should the client ever refuse one in a fight, R.refused
-- remembers it and nothing is asked in a fight again this session.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Core/Reach.lua")

local R = {}
BT.Reach = R

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a call's first answer, or nil when it errs or keeps it secret
local function plain(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or secret(v) then
		return nil
	end
	return v
end

-- by class: `melee` and `ranged` for an enemy, `help` for a friend. Rank 1
-- of each; the name finds a later rank.
-- A MELEE CLASS'S RANGED IS ITS THROW OR SHOOT (Josh 2026-10-18: "For melee
-- classes, we should use their throw or shoot skills for the ranged state").
-- These, Auto Shot and Charge reach nothing inside 8 yards, so a target
-- between your weapon's reach and 8 yards is "out": nothing you have can hit
-- it there. Charge left the warrior's list: it is not a ranged attack.
R.SPELLS = {
	-- Raptor Strike, Wing Clip; Auto Shot; Mend Pet
	HUNTER = { melee = { 2973, 2974 }, ranged = { 75 }, help = { 136 } },
	-- Heroic Strike; Throw, and Shoot with a bow, gun or crossbow
	WARRIOR = { melee = { 78 }, ranged = { 2764, 2480, 7918, 7919 }, help = {} },
	-- Sinister Strike; the same
	ROGUE = { melee = { 1752 }, ranged = { 2764, 2480, 7918, 7919 }, help = {} },
	-- Frostbolt, Fireball, Arcane Missiles; Arcane Intellect
	MAGE = { melee = {}, ranged = { 116, 133, 5143 }, help = { 1459 } },
	-- Shadow Bolt, Immolate, Corruption; Unending Breath
	WARLOCK = { melee = {}, ranged = { 686, 348, 172 }, help = { 5697 } },
	-- Smite, Shadow Word: Pain; Lesser Heal
	PRIEST = { melee = {}, ranged = { 585, 589 }, help = { 2050 } },
	-- Wrath, Moonfire, and Faerie Fire (Feral) for a cat or a bear; Healing
	-- Touch
	DRUID = { melee = {}, ranged = { 5176, 8921, 16857 }, help = { 5185 } },
	-- Stormstrike; Lightning Bolt; Healing Wave
	SHAMAN = { melee = { 17364 }, ranged = { 403 }, help = { 331 } },
	-- Holy Strike (Josh 2026-10-18: "Classic paladin does have Holy Strike as
	-- a melee skill"): 1.12 dropped it (its ranks are "zzOLDHoly Strike" in
	-- the VMaNGOS data, 679 the first), and Forever has it again. 679 by its
	-- number, and by the name of 13953 (an enemy's Holy Strike, which the
	-- client knows by name whatever number Forever gave the paladin's), which
	-- finds the rank in your spellbook. Then Exorcism, Holy Shock,
	-- Judgement, Hammer of Justice, and Holy Light ("Paladin I guess would
	-- use a healing spell for range"), which the client does not answer for
	-- an enemy; Holy Light, Flash of Light
	PALADIN = { melee = { 679, 13953 }, ranged = { 879, 20473, 20271, 853, 635 }, help = { 635, 19750 } },
}
-- A DRUID IN FORM FIGHTS IN MELEE: Claw in cat form, Maul in bear form. The
-- form is told by the power it shows.
R.FORMS = { [3] = { 1082 }, [1] = { 6807 } } -- energy, rage
-- MELEE: THE ATTACK BUTTON IF IT IS ON YOUR BARS, YOUR CLASS'S MELEE
-- ABILITY IF NOT (Josh 2026-10-18: "Is it possible to use "Attack" spell
-- only if it is on the bars, otherwise fallback to the other skills you
-- mentioned? I know level 1 characters do start with Attack on their
-- bars"). Melee range is no set distance - 5 yards and the two bodies'
-- size, more for a giant - and the client tells an addon no enemy's
-- distance, only whether a spell or a button of yours reaches it. The Attack
-- button is asked as the bars ask it, to colour its key; it is the auto
-- attack's own reach, so every class has it while Attack is on a bar. Nothing
-- is put on your bars for it ("I'd rather not make changes to the players
-- action bars").
-- WHAT NEVER ANSWERS (Josh's paladin's Record, 2026-10-18): the Attack spell
-- itself (its range is "self only", rangeIndex 1 in the VMaNGOS data), the
-- older global IsSpellInRange (not in this client), and another class's
-- melee ability you don't know. They were asked, and are not any more.
R.ATTACK = 6603

-- the action slot with Attack on it, or nil; found again when a bar changes
local attackSlot, slotsChanged = nil, true
-- THE CLIENT'S OWN NAMES (Josh 2026-10-18, Attack on a bar and still no
-- swords: "Is there maybe some other flag on the API that holds that "in
-- range" value?"). This client's bars ask C_ActionBar (the forever branch's
-- Blizzard_ActionBar/Shared/ActionButton.lua): FindSpellActionButtons for the
-- slots a spell is in, IsActionInRange(slot, unit) for its reach. The globals
-- of those names were all that was asked, and the client may have neither.
-- The red blink on the Attack button is not its range: the bars flash it
-- while you are auto-attacking (UpdateFlash: IsAttackAction and
-- IsCurrentAction); its reach shows as its key in red.
local function actionBar(name)
	local fn = C_ActionBar and C_ActionBar[name]
	return type(fn) == "function" and fn or nil
end

function R.AttackSlot()
	if not slotsChanged then
		return attackSlot
	end
	slotsChanged, attackSlot = false, nil
	local find = actionBar("FindSpellActionButtons")
	if find then
		local ok, slots = pcall(find, R.ATTACK)
		if ok and type(slots) == "table" and not secret(slots[1]) and type(slots[1]) == "number" then
			attackSlot = slots[1]
			return attackSlot
		end
	end
	-- or slot by slot: Attack by its spell, or by the bars' own word for it
	local info = type(GetActionInfo) == "function" and GetActionInfo or actionBar("GetActionInfo")
	local isAttack = actionBar("IsAttackAction") or (type(IsAttackAction) == "function" and IsAttackAction) or nil
	for slot = 1, 120 do
		local ok, kind, id = false, nil, nil
		if info then
			ok, kind, id = pcall(info, slot)
		end
		local found = ok and not secret(kind) and not secret(id) and kind == "spell" and id == R.ATTACK
		if not found and isAttack then
			local okA, a = pcall(isAttack, slot)
			found = okA and not secret(a) and a == true
		end
		if found then
			attackSlot = slot
			break
		end
	end
	return attackSlot
end

-- whether the Attack button reaches `unit`: true, false, a secret, or nil
-- with no such button or no answer
function R.AskAttack(unit)
	-- C_ActionBar's takes the unit; the old global asks of the target alone
	local inRange = actionBar("IsActionInRange")
	local old = type(IsActionInRange) == "function" and IsActionInRange or nil
	if not inRange and not (old and unit == "target") then
		return nil
	end
	local slot = R.AttackSlot()
	if not slot then
		return nil
	end
	local ok, r
	if inRange then
		ok, r = pcall(inRange, slot, unit)
	else
		ok, r = pcall(old, slot)
	end
	if not ok then
		return nil
	elseif secret(r) or type(r) == "boolean" then
		return r
	elseif r == 1 then
		return true
	elseif r == 0 then
		return false
	end
	return nil
end

-- THE DEAD ZONE (Josh 2026-10-18: "For the deadzone, we could use a new
-- cancel or no action icon"). These classes' ranged attacks reach nothing
-- inside 8 yards, and the client says "out of range" there as it does past
-- the far end. Which end it is:
--   out of a fight   the client's own 28-yard check (CheckInteractDistance,
--                    4: the distance you can follow from). Throw, Shoot and
--                    Auto Shot all reach 30 yards or more, so a target within
--                    28 that none of them reaches is too close for them.
--   in a fight       that check is refused, so by what was said just
--                    before: a target that was in melee or the dead zone a
--                    moment ago is still close, since nothing crosses the
--                    22 yards past Throw's far end in R.KEEP seconds
-- A target coming in from range is "out" until it is in melee, or until a
-- fight ends.
-- NOT THE DUEL'S DISTANCE (Josh 2026-10-18: "There is still a range where
-- we're showing the red crosshairs, even though I am in the deadzone"): the
-- check first asked was 3, a duel's, which is 7 yards on this client (9.9
-- in 2004), so a rogue 7 to 8 yards off was "out".
R.DEAD_ZONE = { HUNTER = true, WARRIOR = true, ROGUE = true }
R.KEEP = 1.5
R.NEAR = 4

function R.Class()
	local _, class = nil, nil
	if type(UnitClass) == "function" then
		local ok, a, b = pcall(UnitClass, "player")
		if ok and not secret(b) then
			_, class = a, b
		end
	end
	return class
end

-- the spells to ask about `unit`: { melee, ranged } for an enemy, { help }
-- for a friend, or nil for a class with none for it
local lists = {}
function R.Lists(unit)
	local class = R.Class() or ""
	local spells = R.SPELLS[class]
	if not spells then
		return nil
	end
	if plain(UnitCanAssist, "player", unit) then
		if #spells.help == 0 then
			return nil
		end
		lists.help = lists.help or {}
		lists.help[class] = lists.help[class] or { help = spells.help }
		return lists.help[class]
	end
	local form = R.SPELLS.DRUID == spells and R.FORMS[plain(UnitPowerType, "player") or -1]
	local key = class .. (form and tostring(form[1]) or "")
	if not lists[key] then
		lists[key] = { melee = form or spells.melee, ranged = spells.ranged }
	end
	return lists[key]
end

-- every spell to ask about `unit`, melee first: what What loaded names, and
-- what R.Any asks
local flat = {}
function R.List(unit)
	local l = R.Lists(unit)
	if not l then
		return nil
	end
	local list = flat[l]
	if not list then
		list = {}
		for _, part in ipairs({ l.help or {}, l.melee or {}, l.ranged or {} }) do
			for _, id in ipairs(part) do
				list[#list + 1] = id
			end
		end
		flat[l] = list
	end
	return list
end

local function fighting()
	return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- one spell's answer: true, false, a secret, or nil for none
function R.Ask(id, unit)
	local C = C_Spell
	local fn = C and C.IsSpellInRange
	if type(fn) ~= "function" then
		return nil
	end
	local ok, r = pcall(fn, id, unit)
	if ok and (secret(r) or type(r) == "boolean") then
		return r
	end
	local name = plain(C.GetSpellName, id)
	if type(name) == "string" then
		ok, r = pcall(fn, name, unit)
		if ok and (secret(r) or type(r) == "boolean") then
			return r
		end
	end
	return nil
end

-- whether any spell of `list` reaches `unit`: true and the spell, a secret
-- and its spell, false and the first that said no, or nil when none answered
local function anyOf(list, unit)
	local said, by = nil, nil
	for _, id in ipairs(list or {}) do
		local r = R.Ask(id, unit)
		if secret(r) or r == true then
			return r, id
		elseif r == false and said == nil then
			said, by = false, id
		end
	end
	return said, by
end

-- what each unit was last said to be: { guid, band, at }
R.last = {}

local function now()
	return type(GetTime) == "function" and GetTime() or 0
end

-- whether `unit`, out of every reach, is too close rather than too far (the
-- dead zone, above)
local function tooClose(unit)
	if not fighting() then
		if R.nearRefused or type(CheckInteractDistance) ~= "function" then
			return false
		end
		return plain(CheckInteractDistance, unit, R.NEAR) == true
	end
	local was = R.last[unit]
	return was ~= nil and (was.band == "melee" or was.band == "close") and now() - was.at <= R.KEEP
		and was.guid == plain(UnitGUID, unit)
end

-- HOW NEAR `unit` IS: "melee", "ranged", "close" (the dead zone) or "out",
-- and the spell that said so; a secret as it came, and its spell; nil when
-- nothing answered. A friend is "ranged" in reach of your help, and "out"
-- past it.
-- (Josh 2026-10-18, first: "red if target is out of ranged attack (or
-- spell) range, yellow if in ranged attack range, and green if in melee
-- range"; then the icons, Modules/ResourceDisplay.)
function R.Band(unit)
	local band, spell = R.Measure(unit)
	if not secret(band) then
		R.last[unit] = band and { guid = plain(UnitGUID, unit), band = band, at = now() } or nil
	end
	return band, spell
end

function R.Measure(unit)
	if R.refused and fighting() then
		return nil
	end
	local l = R.Lists(unit)
	if not l then
		return nil
	end
	if l.help then
		local r, id = anyOf(l.help, unit)
		if secret(r) then
			return r, id
		elseif r == nil then
			return nil
		end
		return r and "ranged" or "out", id
	end
	-- melee: the Attack button if it is on your bars, your class's melee
	-- abilities if not (R.ATTACK, above)
	local m, mid = R.AskAttack(unit), R.ATTACK
	if m == nil then
		m, mid = anyOf(l.melee, unit)
	end
	if secret(m) then
		return m, mid
	elseif m == true then
		return "melee", mid
	end
	local g, gid = anyOf(l.ranged, unit)
	if secret(g) then
		return g, gid
	end
	if g == true then
		return "ranged", gid
	elseif g == false and R.DEAD_ZONE[R.Class() or ""] and tooClose(unit) then
		return "close", gid
	elseif g == false then
		-- (and the spell that said no, for What loaded)
		return "out", gid
	elseif m == false then
		return "out", mid
	end
	return nil
end

-- whether any of them reaches `unit`: true, false, a secret, or nil when
-- none answers
function R.Any(unit)
	if R.refused and fighting() then
		return nil
	end
	local said = nil
	for _, id in ipairs(R.List(unit) or {}) do
		local r = R.Ask(id, unit)
		if secret(r) or r == true then
			return r
		elseif r == false then
			said = false
		end
	end
	return said
end

-- REFUSED IN A FIGHT, ONCE IS ENOUGH (see the top): the client names the
-- call it blocked, and a range question it blocked is not asked in a fight
-- again (Core/Blocked.lua writes the same event down for What loaded)
-- The 28-yard check is only asked out of a fight, but if the client ever
-- refuses it, it is not asked again this session (R.nearRefused).
-- A NEW TARGET IS MEASURED AFRESH: what the last one was said to be does
-- not carry over (the dead zone's memory, above).
local watch = CreateFrame("Frame")
R.watch = watch
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:RegisterEvent("PLAYER_TARGET_CHANGED")
watch:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
watch:SetScript("OnEvent", function(_, event, addon, func)
	if event == "PLAYER_TARGET_CHANGED" then
		R.last.target = nil
		return
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- the Attack button may have moved (R.AttackSlot)
		slotsChanged = true
		return
	end
	if addon == BT.NAME and tostring(func):find("SpellInRange", 1, true) then
		R.refused = true
	elseif addon == BT.NAME and tostring(func):find("CheckInteractDistance", 1, true) then
		R.nearRefused = true
	end
end)
