-- Where the names come from. Nothing here queries the server: every source is
-- something the client was already told (Josh 2026-09-18). /who is the one
-- source that asks, and it is deliberately not in this first version.
--
-- The sources, richest last:
--   meter        everyone the damage meter counted in the fight that just
--                ended, with their class - see Collect/Meter.lua. This client
--                FORBIDS addons the raw combat log: registering
--                COMBAT_LOG_EVENT_UNFILTERED raises ADDON_ACTION_FORBIDDEN and
--                the "blocked from an action" popup (seen on 1.60.1.69893),
--                so the meter sessions stand in for it.
--   chat         a name and a GUID for everyone talking in range or in a
--                channel, which is how a city fills itself in
--   units        nameplates, mouseover, target, group, guild roster: the only
--                sources that carry class, race, level and guild
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Collect/Sightings.lua")

local U, DB = BT.Util, BT.DB
local C = {}
BT.Collect = C

-- One write per player per minute: a busy channel and a raid roster both
-- name the same people over and over.
local fresh = U.Throttle(60)
C.Fresh = fresh -- Collect/Meter.lua shares the window

local function enabled()
	return BT.Collecting()
end

local function zone()
	return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or nil
end

-- The full name of a unit is the core's now (U.UnitFullName): the ledger and
-- the tooltips want it without a census. The old name stays for callers.
C.UnitFullName = function(unit) return U.UnitFullName(unit) end

-- the same people by GUID, for the unit path's first question
local freshGuid = U.Throttle(60)

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a side as the client names it, or nil (Core/Pack.lua keeps three)
local function side(unit)
	local ok, f = pcall(UnitFactionGroup or error, unit)
	if ok and type(f) == "string" and not secret(f) and BT.Pack.FACTION_CODE[f] then
		return f
	end
	return nil
end
C.Side = side

-- the game's 2 (male) or 3 (female), or nil
local function sexOf(unit)
	local ok, v = pcall(UnitSex or error, unit)
	if ok and type(v) == "number" and not secret(v) and (v == 2 or v == 3) then
		return v
	end
	return nil
end
C.Sex = sexOf

-- A unit token you can still see: the best kind of sighting.
-- WHO WAS SEEN A MOMENT AGO IS ASKED FIRST (Josh 2026-09-30, review). In a
-- city the nameplates and the mouseover name the same people over and over,
-- and each one's name and key were worked out before the throttle said no.
-- A GUID the client hands over plainly answers that in one call. A secret one
-- is never used as a key, and is not written down either.
function C.FromUnit(unit)
	if not (enabled() and unit and UnitExists(unit) and UnitIsPlayer(unit)) then
		return nil
	end
	local guid = UnitGUID and UnitGUID(unit)
	if type(guid) ~= "string" or secret(guid) then
		guid = nil
	elseif not freshGuid(guid) then
		return nil
	end
	local name, realm = C.UnitFullName(unit)
	if not name then
		return nil
	end
	U.LearnRealm(realm)
	local key = U.Key(name, realm)
	if not (key and fresh(key)) then
		return nil
	end
	local _, class = UnitClass(unit)
	local _, race = UnitRace(unit)
	local level = UnitLevel(unit)
	local guild = GetGuildInfo(unit)
	return DB.Note(BT.db, name, realm, {
		src = "unit:" .. tostring(unit),
		class = class,
		race = race,
		faction = side(unit),
		sex = sexOf(unit),
		-- "we could not tell" is nil and changes nothing. A unit whose guild
		-- has not arrived yet reads the same as an unguilded one, so a unit
		-- never records a leave (Josh 2026-09-23, audit): a /who you ran,
		-- which states the guild outright, is what does.
		guild = guild,
		level = (level and level > 0) and level or nil,
		zone = zone(),
		guid = guid,
	})
end

-- A GUID is not just an identity: the client knows who it belongs to
-- (Josh 2026-09-18). GetPlayerInfoByGUID is how the chat frame colours a
-- sender's name by class, so anything we heard in chat can be identified
-- without ever seeing it - which is what emptied the "unknown" bar.
--   -> localizedClass, englishClass, localizedRace, englishRace, sex, name, realm
-- NOTE: `name` here is the GIVEN name on this client ("Dylzz"), not the full
-- one - the same half that UnitName returns. Use it for class and race, never
-- to name a row; GetUnitName and chat are the two sources that carry both
-- halves (Josh 2026-09-18).
function C.Identify(guid)
	if type(guid) ~= "string" or not GetPlayerInfoByGUID then
		return nil
	end
	local ok, _, class, _, race, sex, name, realm = pcall(GetPlayerInfoByGUID, guid)
	if not ok or type(class) ~= "string" or class == "" then
		return nil -- the client has not cached this one
	end
	return {
		class = class,
		race = (type(race) == "string" and race ~= "") and race or nil,
		sex = (type(sex) == "number" and sex > 0) and sex or nil,
		name = (type(name) == "string" and name ~= "") and name or nil,
		realm = (type(realm) == "string" and realm ~= "") and realm or nil,
	}
end

-- A name and a GUID, with no unit to inspect: chat.
--
-- A PLAYER GUID IS THE ADMISSION TICKET (Josh 2026-09-18). Totems, pets and
-- NPCs turn up in chat too - CHAT_MSG_TEXT_EMOTE fires for "Totem" and for a
-- hunter's pet, with no GUID attached - and they were landing in the book as
-- grey, classless, one-word rows. Anything the client will not identify is not
-- a character, so it is not written down.
local function fromName(name, guid, faction)
	if not enabled() or type(name) ~= "string" or name == "" then
		return nil
	end
	if type(guid) ~= "string" or not guid:match("^Player%-") then
		return nil
	end
	local key = U.Key(name)
	if not (key and fresh(key)) then
		return nil
	end
	local info = C.Identify(guid)
	if info then
		-- a surname in the realm's place is no realm (U.SurnameIsRealm), and
		-- is not learned as one
		if U.SurnameIsRealm(name, info.realm) then
			info.realm = nil
		end
		U.LearnRealm(info.realm)
		-- NEVER take the shorter name (Josh 2026-09-18). Identify returns the
		-- GIVEN name on this client, so "name = info.name" quietly cut every
		-- chat sighting down to half - the very thing we were trying to fix.
		-- It may only ever ADD a surname, never remove one.
		if info.name and U.HasSurname(info.name) and not U.HasSurname(name) then
			name = info.name
		end
	end
	-- "Beeb Bob-Faerlina" with its realm handed over as well: the name
	-- without the realm on it, or the row is filed as "Beeb Bob-Faerlina"
	-- (Josh 2026-09-23, audit). A name never holds a hyphen of its own.
	if info and info.realm then
		name = name:match("^([^%-]+)%-.+$") or name
	end
	return DB.Note(BT.db, name, info and info.realm or nil, {
		src = "chat", guid = guid, zone = zone(),
		class = info and info.class or nil,
		race = info and info.race or nil,
		faction = faction,
		sex = info and info.sex or nil,
	})
end

-- Everyone already in the book who has a GUID but no class: ask the client
-- about them a few at a time, so a book built before this existed catches up
-- without a hitch on login.
-- Fills in what a GUID can tell us about rows already in the book: the class
-- of a character we only heard, and the SURNAME of one the damage meter filed
-- under a given name alone. A renamed row merges into the full-named one if it
-- is already there, which is what DB.Note does with a GUID it recognises.
function C.Backfill(budget)
	if not BT.db then
		return 0, 0, 0
	end
	local done, looked, noGuid, renamed = 0, 0, 0, 0
	-- written after the walk: a rename can add a row and empty this one, and
	-- adding to the table being walked is an "invalid key to next"
	local renames = {}
	for key, row in pairs(DB.Players(BT.db)) do
		-- A PACKED ROW IS A TIDY ONE (Josh 2026-09-24): only a real GUID
		-- goes into the string, so a packed row with a class has nothing
		-- to put right, and one without is unpacked to be filled in. The
		-- class is read off the string's first letter (Josh 2026-09-30,
		-- review): unpacking all of them to look cost a visible moment five
		-- seconds after login, and more the bigger the book.
		if not (type(row) == "string" and BT.Pack.HasClass(row)) then
			local p = type(row) == "string" and DB.Get(BT.db, key) or row
			-- a "guid" that is not one is the lineID bug above: drop it, so the
			-- count of who we cannot identify is honest
			if p.guid ~= nil and (type(p.guid) ~= "string" or not p.guid:match("^Player%-")) then
				p.guid = nil
			end
			if not p.class and not p.guid then
				noGuid = noGuid + 1
			end
			local halfNamed = p.guid and p.name and select(2, U.SplitName(p.name)) == nil
			if (not p.class or halfNamed) and p.guid and GetPlayerInfoByGUID then
				looked = looked + 1
				local info = C.Identify(p.guid)
				if info then
					p.class = p.class or info.class
					p.race = p.race or info.race
					p.sex = p.sex or ((info.sex == 2 or info.sex == 3) and info.sex or nil)
					done = done + 1
					-- on the off chance a build starts returning both halves
					if info.name and select(2, U.SplitName(info.name)) ~= nil
						and select(2, U.SplitName(p.name)) == nil then
						renames[#renames + 1] = { info.name, info.realm, p.guid, p.class }
						renamed = renamed + 1
					end
				end
				if looked >= (budget or 200) then
					break
				end
			end
		end
	end
	for _, r in ipairs(renames) do
		DB.Note(BT.db, r[1], r[2], { guid = r[3], class = r[4], listed = true })
	end
	if done > 0 then
		DB.rev = DB.rev + 1
	end
	return done, looked, noGuid, renamed
end

local frame = CreateFrame("Frame")
local handlers = {}
C.handlers = handlers -- the headless tests drive these directly

-- A /who answer arrived: read it. We never send one (see Rosters.lua).
handlers.WHO_LIST_UPDATE = function()
	if BT.Rosters then
		BT.Rosters.WhoResults() -- a /who YOU ran; we only read the answer
	end
end

handlers.FRIENDLIST_UPDATE = function()
	if BT.Rosters then
		BT.Rosters.Friends()
	end
end

handlers.UPDATE_BATTLEFIELD_SCORE = function()
	if BT.Rosters then
		BT.Rosters.Battleground()
	end
end

handlers.MAIL_INBOX_UPDATE = function()
	if BT.Rosters then
		BT.Rosters.Mail()
	end
end

handlers.CHAT_MSG_CHANNEL_LIST = function(_, _, text)
	if BT.Rosters then
		BT.Rosters.ChannelList(text)
	end
end

-- Combat just ended: read the meter's roll call of who was in it.
handlers.PLAYER_REGEN_ENABLED = function()
	if BT.Meter then
		BT.Meter.Harvest()
	end
end

-- Chat: arg2 is the sender, arg12 the sender's GUID.
--
-- COUNT THE UNDERSCORES (Josh 2026-09-18). Written as a parameter list this
-- landed one short and picked up arg11, the lineID - a number, not a GUID. So
-- every chat sighting stored a line number as its identity: nothing could be
-- identified from it, and two names for one character never merged. select()
-- says which argument it wants out loud, which is the point.
-- WHO CAN BE ON THE OTHER SIDE (Josh 2026-09-30): only what is said aloud
-- reaches you from the other faction; a channel, your guild, your group or a
-- whisper is your own side's
local ANY_SIDE = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true, CHAT_MSG_TEXT_EMOTE = true }
local function onChat(_, event, ...)
	local sender, guid = select(2, ...), select(12, ...)
	fromName(sender, guid, not ANY_SIDE[event] and side("player") or nil)
end
for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_WHISPER" }) do
	handlers[e] = onChat
end

-- The units nobody has to click (Josh 2026-09-18). Your target's target, your
-- mouseover's target, and what each of your group is looking at are all full
-- unit tokens - name, class, race, level, guild - for players you never
-- touched. In a crowded zone this roughly doubles what the unit path sees, and
-- it costs one existence check each.
function C.FromUnitAndTarget(unit)
	C.FromUnit(unit)
	C.FromUnit(unit .. "target")
end

handlers.UPDATE_MOUSEOVER_UNIT = function() C.FromUnitAndTarget("mouseover") end
-- (the dock's target row is the core's to light: Core/Boot.lua)
handlers.PLAYER_TARGET_CHANGED = function()
	C.FromUnitAndTarget("target")
end
handlers.NAME_PLATE_UNIT_ADDED = function(_, _, unit) C.FromUnit(unit) end

-- ONCE A BURST HAS SETTLED (Josh 2026-09-23, audit): a raid forming is a
-- roster change per person, and each read all forty and their targets
local rosterQueued = false
local function readRoster()
	rosterQueued = false
	if not enabled() then
		return
	end
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
	for i = 1, n do
		C.FromUnitAndTarget(prefix .. i)
	end
end
C.ReadRoster = readRoster

handlers.GROUP_ROSTER_UPDATE = function()
	if not enabled() or rosterQueued then
		return
	end
	if C_Timer and C_Timer.After then
		rosterQueued = true
		C_Timer.After(1, readRoster)
	else
		readRoster()
	end
end

-- The guild roster is the one source that hands over offline characters, so it
-- is worth walking whenever the client refreshes it.
local lastRoster = 0

handlers.GUILD_ROSTER_UPDATE = function()
	if not (enabled() and GetNumGuildMembers) then
		return
	end
	-- ONCE A MINUTE IS ENOUGH (Josh 2026-09-19). The client fires this whenever
	-- anything about the roster changes - a member logging in or out, a note
	-- edited, the panel being opened - and each one used to walk every member
	-- of the guild. In a five-hundred-strong guild that is five hundred API
	-- calls for a list that cannot have meaningfully changed since the last
	-- burst, and it arrives in bursts.
	local now = U.Now()
	if now - lastRoster < 60 then
		return
	end
	-- an empty roster is the one that comes at login before the members do,
	-- and it must not use up the minute the real one arrives in
	local total = GetNumGuildMembers()
	if (total or 0) == 0 then
		return
	end
	lastRoster = now

	local guild = GetGuildInfo and GetGuildInfo("player")
	for i = 1, total do
		local name, _, _, level, _, zoneName, _, _, online, _, class = GetGuildRosterInfo(i)
		if name then
			local key = U.Key(name)
			if key and fresh(key) then
				-- an offline member is listed, not seen, and where they last
				-- logged out is not where they are
				DB.Note(BT.db, name, nil, {
					src = "guild", class = class, level = (level and level > 0) and level or nil,
					guild = guild, zone = online and zoneName or nil, listed = not online or nil,
					-- a guild is one side's
					faction = side("player"),
				})
			end
		end
	end
end

-- AFTER THE CORE HAS BOUND (Core/Boot.lua, Josh 2026-09-26): the core logs
-- itself in - the settings, the book, the dock - and this is the census's
-- share of every loading screen, which it used to do all of
function C.World(initial, reloading)
	-- SILENT AT LOGIN (Josh 2026-09-19). The addon says nothing when you log
	-- in - not one line, however interesting it is to the addon. Everything
	-- that used to be announced here is kept and shown where you would go
	-- looking for it: What loaded and The book, on the Testing page.
	--
	-- An addon that greets you with a line every login is an addon you end up
	-- muting, and then it cannot tell you the one thing that matters.
	-- and if the book is only slow, not missing, take it when it lands
	if (BT.boot and (BT.boot.boundCount or 0) == 0) then
		BT.WatchForBook()
	end
	-- the client's GUID cache is warmest right after login; walk the unknowns
	-- once, off the loading screen so it costs nothing visible
	-- ONCE A SESSION (Josh 2026-09-23, audit): the walks below each go over
	-- the whole book, and they ran at every loading screen
	-- AND ONLY WITH THE CENSUS ON (Josh 2026-09-30, review). Nothing moves a
	-- row's last-seen while the census is off, so pruning then would take out
	-- everyone not seen in the window for no reason but the switch. A module
	-- that is off never tidies away what it is not showing (BT.Bind); the
	-- session is marked only when the work ran, so switching the census on
	-- lets the next loading screen do it.
	if C.housekept or not enabled() then
		C.FromUnit("player")
		return
	end
	C.housekept = true
	if C_Timer and C_Timer.After then
		-- Housekeeping is SILENT (Josh 2026-09-18). An addon that greets you
		-- with three lines every login is one you end up muting. What it did
		-- is kept in BT.lastRun and shown where you go looking for it: The
		-- book, on the Testing page.
		C_Timer.After(5, function()
			BT.lastRun = BT.lastRun or {}
			BT.lastRun.cleaned = BT.cleanedOnLoad
			BT.cleanedOnLoad = nil
			BT.lastRun.identified = C.Backfill(400)
		end)
	end
	C.FromUnit("player")
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	end
	-- and the friends list, which the client sends only when asked: the
	-- hidden channel used to ask at login (Core/CommsProbe.lua, gone with
	-- the sharing, Josh 2026-09-26), and FRIENDLIST_UPDATE files what comes
	if C_FriendList and C_FriendList.ShowFriends then
		pcall(C_FriendList.ShowFriends)
	end
	-- pruning belongs at a quiet moment, not at logout where it would sit in
	-- front of the saved-variables write
	if BT.db and (BT.settings.pruneDays or 0) > 0 then
		BT.lastRun = BT.lastRun or {}
		BT.lastRun.pruned = DB.Prune(BT.db, BT.settings.pruneDays)
	end
	-- and the book's size, at the same quiet moment (DB.Cap)
	if BT.db and (BT.settings.bookCap or 0) > 0 then
		BT.lastRun = BT.lastRun or {}
		BT.lastRun.capped, BT.lastRun.cappedLow, BT.lastRun.capFrom = DB.Cap(BT.db, BT.settings.bookCap)
	end
end

-- PACKED FOR THE NIGHT (Josh 2026-09-24). Every character the session
-- unpacked goes back into its string before the client writes the file - in
-- every book, so one bound before the packing existed is packed too. A row
-- that cannot be packed stays a table, which the next login reads just the
-- same, so nothing here can lose anybody; and it is all inside a pcall,
-- because an error here would stand between you and the logout.
handlers.PLAYER_LOGOUT = function()
	if not (BT.DB and type(BeebModDB) == "table" and type(BeebModDB.realms) == "table") then
		return
	end
	pcall(function()
		local packed = 0
		for key, book in pairs(BeebModDB.realms) do
			if type(book) == "table" and type(book.players) == "table" then
				book.realm = book.realm or key:match("^(.-)|")
				packed = packed + DB.PackAll(book)
			end
		end
		BeebModDB.packedAtLogout = packed
	end)
end

-- the tests reach the login handler through this rather than through an event
C.Handlers = handlers

function C.Start()
	frame:SetScript("OnEvent", function(self, event, ...)
		local h = handlers[event]
		if h then
			h(self, event, ...)
		end
	end)
	for event in pairs(handlers) do
		-- an event this client keeps for itself raises ADDON_ACTION_FORBIDDEN
		-- inside RegisterEvent, and the popup never says which one; leaving
		-- the name here lets Core/Blocked.lua name it (that is how the combat
		-- log was found on 1.60.1.69893).
		--
		-- pcall, because ONE refused event used to abort this whole loop, and
		-- `pairs` order is arbitrary: the casualty was whatever came after it.
		-- When that was PLAYER_ENTERING_WORLD, the addon never bound a book
		-- and everything quietly did nothing (Josh 2026-09-18).
		BT.registering = event
		local ok, err = pcall(frame.RegisterEvent, frame, event)
		BT.registering = nil
		if not ok then
			-- remembered, not announced: What loaded, on the Testing page,
			-- lists these
			C.refused = C.refused or {}
			C.refused[event] = tostring(err)
		end
	end
end

-- the census's share of every loading screen, once the core has bound
BT.OnWorld(function(initial, reloading)
	C.World(initial, reloading)
end)
