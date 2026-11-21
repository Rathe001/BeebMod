-- The realm, when the game names none (Josh 2026-11-21).
--
-- "For some reason I'm seeing duplicate characters on currency ... We no
-- longer have servers, so they should be combined." From 2026-11-20 the game
-- names no realm: GetRealmName and GetNormalizedRealmName give "", GetRealmID
-- gives 0, and UnitFullName gives the two halves of the name. BeebMod bound a
-- second book, the one with no realm in its key ("|All"), and filed every
-- character's records again as "Name@". Nothing was lost. It was all split in
-- two.
--
-- WHICH REALM, THEN. No call tells PvE from PvP any more, so the saved file
-- does. In order: the realm this character was last bound to (BeebModDB.homes,
-- written at every bind); the realm on a record this character already has
-- ("Name@Realm" in the settings); the only named book in the file. Hardcore
-- can still be asked (C_GameRules.IsHardcoreActive), so a book is only taken
-- for a character of its own kind, and a Hardcore character with no book yet
-- is bound to "Hardcore". With none of these the realm stays "", which is one
-- book for the account, shown as "Forever" (U.RealmLabel).
--
-- THEN THE TWO HALVES MADE ONE (BT.FoldNameless, at every bind to a named
-- realm). This character's "Name@" records go into its "Name@Realm" ones.
-- With one named book in the file, every character's do, and the book with
-- no realm goes into it, the Ledger's people with it. With two named books
-- the nameless book can't be shared out between them, so it is left alone.
local _, BT = ...

local U = BT.Util

local function blank(s)
	return type(s) ~= "string" or s:gsub("%s+", "") == ""
end

local function squeezed(s)
	return (s:gsub("%s+", ""))
end

-- the settings that hold one record a character, keyed "Name@Realm", and how
-- two records of one character are made one:
--   newer   the one touched last is kept (a session, a purse, a rank)
--   append  the second list goes on the end of the first (XP pace samples)
--   sum     numbers add up, tables field by field; the session is the newer
--   journal the Expedition's page of a character (joinJournal)
BT.BY_CHARACTER = {
	{ "xp", "newer" }, { "clock", "newer" }, { "currency", "newer" }, { "rep", "newer" }, { "pvp", "newer" },
	{ "purses", "newer" }, { "xpPace", "append" }, { "pickpocket", "sum" },
	{ "expedition", "journal", "chars" }, { "expedition", "newer", "sessions" },
}

local function tableAt(settings, row)
	local t = type(settings) == "table" and settings[row[1]] or nil
	if row[3] then
		t = type(t) == "table" and t[row[3]] or nil
	end
	return type(t) == "table" and t or nil
end

local function hardcore()
	local rules = rawget(_G, "C_GameRules")
	if not (rules and type(rules.IsHardcoreActive) == "function") then
		return false
	end
	local ok, on = pcall(rules.IsHardcoreActive)
	return ok and on == true
end

local function isHardcoreRealm(realm)
	return realm:lower():find("hardcore", 1, true) ~= nil
end

-- every named realm with a book in the file, each once
function BT.NamedRealms()
	local seen, list = {}, {}
	for key in pairs(type(BeebModDB) == "table" and type(BeebModDB.realms) == "table" and BeebModDB.realms or {}) do
		local r = type(key) == "string" and key:match("^(.-)|") or nil
		if r and r ~= "?" and not blank(r) and not seen[r] then
			seen[r] = true
			list[#list + 1] = r
		end
	end
	table.sort(list)
	return list
end

-- The realm to bind for what the game said. `raw` back when it names one, or
-- when the saved file can't say.
function BT.Home(raw)
	if type(BeebModDB) ~= "table" then
		return raw
	end
	local me = U.Me and U.Me() or nil
	local function keep(realm)
		if me and me ~= "" then
			BeebModDB.homes = type(BeebModDB.homes) == "table" and BeebModDB.homes or {}
			BeebModDB.homes[me] = squeezed(realm)
		end
		return realm
	end
	if not blank(raw) then
		return keep(raw)
	end
	local hc = hardcore()
	local function fits(realm)
		-- (never a beta realm's book, from a WTF folder copied across: those
		-- records go at launch, BT.DropBeta)
		return not blank(realm) and isHardcoreRealm(realm) == hc and not (BT.IsBetaRealm and BT.IsBetaRealm(realm))
	end
	local homes = BeebModDB.homes
	if me and type(homes) == "table" and fits(homes[me]) then
		return homes[me]
	end
	-- a record this character already has, under a realm
	if me then
		local found = {}
		for _, row in ipairs(BT.BY_CHARACTER) do
			for who in pairs(tableAt(BeebModDB.settings, row) or {}) do
				-- (on a line of its own: `and` in front of the call kept only
				-- its first answer, so the realm was never read. Review,
				-- 2026-11-21)
				local name, realm = nil, nil
				if type(who) == "string" then
					name, realm = who:match("^(.-)@(.+)$")
				end
				if name == me and fits(realm) then
					found[realm] = true
				end
			end
		end
		local realm = next(found)
		if realm and next(found, realm) == nil then
			return keep(realm)
		end
	end
	-- the only named book of this character's kind
	local mine = {}
	for _, realm in ipairs(BT.NamedRealms()) do
		if fits(realm) then
			mine[#mine + 1] = realm
		end
	end
	if #mine == 1 then
		return keep(mine[1])
	end
	if hc and #mine == 0 then
		return keep("Hardcore")
	end
	return raw
end

-- what the game says now, made a realm to bind, and kept for U.HomeRealm
function BT.RealmNow()
	local raw = GetRealmName and GetRealmName() or nil
	local realm = BT.Home(raw)
	U.realm = realm
	return realm
end

-- ---------------------------------------------------------------------------
-- Two records of one character made one
-- ---------------------------------------------------------------------------

local function touched(r)
	return math.max(tonumber(r.at) or 0, tonumber(r.last) or 0, tonumber(r.start) or 0)
end

local function sum(to, from)
	for k, v in pairs(from) do
		if k == "session" then
			if type(v) == "table" and (type(to[k]) ~= "table" or touched(v) >= touched(to[k])) then
				to[k] = v
			end
		elseif type(v) == "number" and type(to[k]) == "number" then
			to[k] = to[k] + v
		elseif type(v) == "table" and type(to[k]) == "table" then
			sum(to[k], v)
		elseif to[k] == nil then
			to[k] = v
		end
	end
	return to
end

-- THE EXPEDITION'S PAGE OF A CHARACTER (Modules/Expedition/Journal.lua):
-- kills add up, a first kill and a feat keep their earliest day, and the last
-- kill and the recent ones are the later record's.
local function joinJournal(to, from)
	to.kills, to.first, to.earned = to.kills or {}, to.first or {}, to.earned or {}
	for npc, n in pairs(type(from.kills) == "table" and from.kills or {}) do
		if type(n) == "number" then
			to.kills[npc] = (tonumber(to.kills[npc]) or 0) + n
		end
	end
	for npc, at in pairs(type(from.first) == "table" and from.first or {}) do
		if type(at) == "number" then
			to.first[npc] = math.min(tonumber(to.first[npc]) or at, at)
		end
	end
	for id, at in pairs(type(from.earned) == "table" and from.earned or {}) do
		local had = to.earned[id]
		if type(had) ~= "number" or (type(at) == "number" and at < had) then
			to.earned[id] = at
			if type(from.earnedBy) == "table" and from.earnedBy[id] ~= nil then
				to.earnedBy = to.earnedBy or {}
				to.earnedBy[id] = from.earnedBy[id]
			end
		end
	end
	if type(from.bestRank) == "number" then
		to.bestRank = math.max(tonumber(to.bestRank) or 0, from.bestRank)
	end
	if type(from.last) == "table" and (type(to.last) ~= "table" or touched(from.last) >= touched(to.last)) then
		to.last = from.last
	end
	if type(from.recent) == "table" and next(from.recent) ~= nil then
		to.recent = from.recent
	end
	for k, v in pairs(from) do
		if to[k] == nil then
			to[k] = v
		elseif k ~= "kills" and k ~= "first" and k ~= "earned" and k ~= "earnedBy" and k ~= "last" and k ~= "recent"
			and type(v) == "table" and type(to[k]) == "table" then
			for kk, vv in pairs(v) do
				if to[k][kk] == nil then
					to[k][kk] = vv
				end
			end
		end
	end
	return to
end

-- `from` into `to` by the rule; what is kept
function BT.JoinRecords(how, to, from)
	if type(from) ~= "table" then
		return to
	end
	if type(to) ~= "table" then
		return from
	end
	if how == "newer" then
		return touched(from) >= touched(to) and from or to
	elseif how == "append" then
		for _, v in ipairs(from) do
			to[#to + 1] = v
		end
		return to
	elseif how == "journal" then
		return joinJournal(to, from)
	end
	return sum(to, from)
end

-- The records filed under no realm ("Name@") into `realm`'s, and the book
-- with no realm into the bound one. Returns how many records and how many
-- characters came across.
function BT.FoldNameless(realm)
	if blank(realm) or type(BeebModDB) ~= "table" then
		return 0, 0
	end
	realm = squeezed(realm)
	local named = BT.NamedRealms()
	local all = #named == 1 and named[1] == realm
	local me = U.Me and U.Me() or nil
	-- WHOSE RECORDS MAY MOVE (review, 2026-11-21). One named book does not
	-- prove a record under no realm belongs to it: a Hardcore character first
	-- played after 2026-11-20 has only "Name@" records, and a PvE character's
	-- login took them for PvE. So a character's records move when it is the
	-- one logged in, or when the file already knows it on this realm, by a
	-- record under "Name@Realm" or the realm it was last bound to. Any other
	-- waits for its own login.
	local known = {}
	for _, row in ipairs(BT.BY_CHARACTER) do
		for who in pairs(tableAt(BeebModDB.settings, row) or {}) do
			if type(who) == "string" then
				local name, r = who:match("^(.-)@(.+)$")
				if name and r == realm then
					known[name] = true
				end
			end
		end
	end
	for name, r in pairs(type(BeebModDB.homes) == "table" and BeebModDB.homes or {}) do
		if type(r) == "string" then
			known[name] = squeezed(r) == realm or nil
		end
	end
	local records = 0
	for _, row in ipairs(BT.BY_CHARACTER) do
		local t = tableAt(BeebModDB.settings, row)
		local moves = {}
		for who in pairs(t or {}) do
			local name = type(who) == "string" and who:match("^(.+)@$") or nil
			if name and (name == me or (all and known[name])) then
				moves[#moves + 1] = { who, name .. "@" .. realm }
			end
		end
		for _, mv in ipairs(moves) do
			t[mv[2]] = BT.JoinRecords(row[2], t[mv[2]], t[mv[1]])
			t[mv[1]] = nil
			records = records + 1
		end
	end
	local characters = 0
	local books = type(BeebModDB.realms) == "table" and BeebModDB.realms or nil
	local bound = BT.scope and BT.scope.key
	if all and books and bound and BT.db and BT.DB then
		for _, key in ipairs({ "|" .. BT.ALL_SIDES, "|Alliance", "|Horde" }) do
			local book = books[key]
			if key ~= bound and type(book) == "table" and book ~= BT.db then
				local ok, added, folded = pcall(BT.DB.Adopt, BT.db, book)
				if ok then
					books[key] = nil
					characters = characters + (added or 0) + (folded or 0)
					-- the Ledger's people, and when each commendation was earned:
					-- the earlier day of the two (Modules/Ledger/Ranks.lua)
					local ledger = type(BeebModDB.ledger) == "table" and BeebModDB.ledger.realms or nil
					local from = type(ledger) == "table" and ledger[key] or nil
					-- (the realm's own Ledger book made first if it has none:
					-- the dates were dropped where it had not been. And a 0,
					-- "before the Ledger kept dates", never takes a real
					-- date's place. Review, 2026-11-21)
					local to = nil
					if type(from) == "table" and BT.Notes and BT.Notes.Book then
						local okB, book = pcall(BT.Notes.Book, bound)
						to = okB and type(book) == "table" and book or nil
					end
					if type(from) == "table" and type(to) == "table" then
						if type(from.earned) == "table" then
							to.earned = type(to.earned) == "table" and to.earned or {}
							for id, at in pairs(from.earned) do
								local had = to.earned[id]
								if type(had) ~= "number" or (type(at) == "number" and at > 0 and (had == 0 or at < had)) then
									to.earned[id] = at
								end
							end
						end
						if type(from.rank) == "number" then
							to.rank = math.max(tonumber(to.rank) or 0, from.rank)
						end
					end
					if BT.Notes and BT.Notes.Join then
						pcall(BT.Notes.Join, key, bound)
					end
				end
			end
		end
	end
	return records, characters
end
