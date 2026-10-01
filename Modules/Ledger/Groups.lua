-- The people you grouped with (Josh 2026-09-29, from the list of ideas:
-- "Ledger: people you grouped with").
--
-- A group counts once you have been in it with someone for five minutes, or
-- at once inside a dungeon or a raid. A two-minute invite to kill one quest's
-- enemy doesn't count; a run does. Each person's row in the Ledger's book
-- (Modules/Ledger/Store.lua) keeps how many groups, when the last one was,
-- and where:
--
--   row.grouped       how many times
--   row.groupedAt     the last time you were together
--   row.groupedWhere  the dungeon, when there was one, or the zone
--
-- A group is counted once for each person, however long it lasts. Someone
-- who leaves and is invited back is a new group. The group in progress is
-- kept in the book too (ledger.group), so a /reload in the middle of a run
-- doesn't count it twice or start its five minutes again.
--
-- It reads only who is in your group and where you are, both of which the
-- client gives freely. Nothing is sent to anyone.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Groups.lua")

local U, N = BT.Util, BT.Notes

local G = {}
BT.LedgerGroups = G

-- long enough together to count
G.LONG_ENOUGH = 300
-- a group remembered across a reload or a relog within this long
G.STALE = 3600
-- how often the group is looked at, besides the client's own events
G.EVERY = 30

function G.On()
	return BT.Enabled("ledger") and not (BT.settings and BT.settings.ledgerGroups == false)
end

-- where you are: a dungeon's or a raid's name inside one, and whether it is
-- one; the zone outside
function G.Place()
	local inside, kind = false, nil
	if IsInInstance then
		local ok, a, b = pcall(IsInInstance)
		if ok then
			inside, kind = a, b
		end
	end
	local dungeon = inside and (kind == "party" or kind == "raid") or false
	local name
	if dungeon and GetInstanceInfo then
		local ok, n = pcall(GetInstanceInfo)
		if ok and type(n) == "string" and n ~= "" then
			name = n
		end
	end
	if not name and GetRealZoneText then
		local ok, z = pcall(GetRealZoneText)
		if ok and type(z) == "string" and z ~= "" then
			name = z
		end
	end
	return name, dungeon
end

-- everyone in your group but you: key -> their unit
-- THE NAME, NOT THE FACE (Josh 2026-09-30, review). Every roster change read
-- each member's class, race, level, guild and GUID, forty members in a raid,
-- and threw it away for anyone already counted. Now only a member about to
-- be counted is read in full.
function G.Members()
	local out = {}
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if type(n) ~= "number" or n == 0 then
		return out
	end
	local raid = IsInRaid and IsInRaid()
	for i = 1, n do
		local unit = (raid and "raid" or "party") .. i
		if UnitExists and UnitExists(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
			local name, realm = U.UnitFullName(unit)
			local key = name and U.Key(name, realm)
			if key then
				out[key] = unit
			end
		end
	end
	return out
end

-- the group in progress, in the book: whose it is, when it was last looked
-- at, and each member's start and whether they have counted
local function state(t)
	local root = N.Root()
	if not root then
		return nil
	end
	local me = U.MeKey and U.MeKey() or nil
	local st = root.group
	if type(st) ~= "table" or st.me ~= me or t - (st.at or 0) > G.STALE then
		st = { me = me, at = t, members = {} }
		root.group = st
	end
	st.members = st.members or {}
	return st
end

-- a group that has lasted long enough: one more on their row
function G.Count(key, info, place, dungeon, t)
	local p = N.Ensure(key, info)
	if not p then
		return nil
	end
	p.grouped = (p.grouped or 0) + 1
	p.groupedAt = t
	p.groupedWhere = place
	N.Touched(true)
	return p
end

-- still together: the last time moves with you, and a dungeon you went into
-- together is where you last were
function G.Touch(key, place, dungeon, t)
	local p = N.Get(key)
	if not p then
		return nil
	end
	p.groupedAt = t
	if dungeon and place then
		p.groupedWhere = place
	end
	return p
end

function G.Update(t)
	-- not while the made-up notes stand in for this book: a group counted
	-- then went into them, and was marked done in the real one
	if not G.On() or N.demo then
		return 0
	end
	t = t or U.Now()
	-- not before this realm's book is open: a count made then has nowhere
	-- to go, and would be marked done all the same
	local st = N.People() and state(t)
	if not st then
		return 0
	end
	local here = G.Members()
	local place, dungeon = G.Place()
	-- gone: forgotten here; the count on their row stays
	for key in pairs(st.members) do
		if not here[key] then
			st.members[key] = nil
		end
	end
	local counted = 0
	for key, unit in pairs(here) do
		local m = st.members[key]
		if not m then
			m = { since = t }
			st.members[key] = m
		end
		if not m.counted then
			if dungeon or t - m.since >= G.LONG_ENOUGH then
				local _, info = N.Face(unit)
				if info then
					m.counted = true
					G.Count(key, info, place, dungeon, t)
					counted = counted + 1
				end
			end
		else
			G.Touch(key, place, dungeon, t)
		end
	end
	st.at = t
	return counted
end

-- "Grouped 3 times · last in The Deadmines, 2 days ago", or nil for
-- someone you have never grouped with
function G.Line(p, now)
	local n = p and tonumber(p.grouped)
	if not n or n < 1 then
		return nil
	end
	local times = n == 1 and "Grouped once" or ("Grouped %d times"):format(n)
	local when = U.Since(p.groupedAt, now)
	if type(p.groupedWhere) == "string" and p.groupedWhere ~= "" then
		return ("%s · last in %s, %s"):format(times, p.groupedWhere, when)
	end
	return ("%s · last %s"):format(times, when)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

G.events = CreateFrame("Frame")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(G.events.RegisterEvent, G.events, event)
end
-- a raid forming or moving people round is a burst of these: one look a
-- second later covers the lot
local queued = false
G.events:SetScript("OnEvent", function()
	if not (C_Timer and C_Timer.After) then
		G.Update()
		return
	end
	if queued then
		return
	end
	queued = true
	C_Timer.After(1, function()
		queued = false
		G.Update()
	end)
end)
-- and every half minute, for the five minutes that no event marks
if C_Timer and C_Timer.NewTicker then
	G.ticker = C_Timer.NewTicker(G.EVERY, function()
		G.Update()
	end)
end
