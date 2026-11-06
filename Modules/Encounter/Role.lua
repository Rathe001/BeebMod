-- Your role, for the notes (Josh 2026-11-06: "can we auto select the role
-- button of the player?").
--
-- In this order:
--   1. the role your group gave you (UnitGroupRolesAssigned), set by the
--      group finder or the leader
--   2. alone, the one role you ticked in the group finder
--      (C_LFGListRoles.GetRoles), when exactly one is ticked
--   3. your class, where it can only deal damage
-- A click on a role button beats all three, and is kept for that character.
--
-- NOT YOUR TALENTS (the Dungeon run record, 2026-11-06). The guess was the
-- talent tree with the most points, from GetTalentTabInfo. On Forever that
-- answered nil for all three trees: talents are C_Traits nodes now, in one
-- spec per class (Blizzard_PlayerSpells, Camelot). A class that can only
-- deal damage needs no guess; anyone else is asked once, by the buttons.
local _, BT = ...

local E = BT.Encounter or {}
BT.Encounter = E

local R = {}
E.Role = R

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function plain(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if not ok or secret(a) then
		return nil
	end
	return a, b, c, d, e, f
end

-- the classes with no tank or healer in them
R.ONLY_DPS = { ROGUE = true, MAGE = true, WARLOCK = true, HUNTER = true }

local FROM_GROUP = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

function R.Group()
	local grouped = plain(rawget(_G, "IsInGroup"))
	if not grouped then
		return nil
	end
	local r = plain(rawget(_G, "UnitGroupRolesAssigned"), "player")
	return FROM_GROUP[r]
end

-- the boxes ticked in the group finder, when only one is
function R.Finder()
	local L = rawget(_G, "C_LFGListRoles")
	local roles = type(L) == "table" and plain(L.GetRoles)
	if type(roles) ~= "table" then
		return nil
	end
	local one, n = nil, 0
	for _, key in ipairs(E.ROLE_ORDER) do
		if roles[key] == true then
			one, n = key, n + 1
		end
	end
	return n == 1 and one or nil
end

-- DPS for a class that can only deal damage, else nil
function R.FromClass(class)
	return class and R.ONLY_DPS[class] and "dps" or nil
end

function R.Class()
	local _, class = plain(rawget(_G, "UnitClass"), "player")
	return type(class) == "string" and class or nil
end

-- the character a pick is kept for
local function who()
	local guid = plain(rawget(_G, "UnitGUID"), "player")
	return type(guid) == "string" and guid or nil
end

local function picks(make)
	if make then
		BT.EnsureBound()
		BT.settings.encounter = BT.settings.encounter or {}
		BT.settings.encounter.roles = BT.settings.encounter.roles or {}
	end
	local s = BT.settings and BT.settings.encounter
	return s and s.roles
end

function R.Picked()
	local all, me = picks(false), who()
	local r = all and me and all[me]
	return E.ROLES[r] and r or nil
end

function R.Pick(role)
	local me = who()
	if not (me and E.ROLES[role]) then
		return false
	end
	picks(true)[me] = role
	return true
end

-- your role, and where it came from: "pick", "group", "finder", "class",
-- or "none" for a guess of DPS with nothing to go on
function R.Current()
	local r = R.Picked()
	if r then
		return r, "pick"
	end
	r = R.Group()
	if r then
		return r, "group"
	end
	r = R.Finder()
	if r then
		return r, "finder"
	end
	r = R.FromClass(R.Class())
	if r then
		return r, "class"
	end
	return "dps", "none"
end

