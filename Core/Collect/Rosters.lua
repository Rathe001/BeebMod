-- Lists the client is already holding (Josh 2026-09-18).
--
-- Everything here reads a table the client has downloaded for its own reasons.
-- Nothing asks the server for anything, and nothing here fires on a timer: it
-- reads when the game says the list changed.
--
--   /who results      you ran the query; reading the answer is free, and it is
--                     the only source carrying level, guild AND zone at once
--   friends           name, level, class and where, for everyone on your list
--   battleground      forty players with class and faction in one table
--   mail              who sent you things: names you would never otherwise meet
--   channel list      every player in a chat channel, after a /chatlist
--
-- These sources have no GUID to offer, so a row from them is `vouched`: it is
-- in a list the client only builds for real characters, which is reason enough
-- to keep it (see DB.Cleanup).
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Collect/Rosters.lua")

local U, DB = BT.Util, BT.DB
local R = {}
BT.Rosters = R

local function on()
	return BT.Collecting()
end

local function note(name, info)
	if not (on() and type(name) == "string" and name ~= "") then
		return false
	end
	-- these sources are read out of the client's own text, and text is not
	-- always what it claims to be: a channel LIST can be a list of channels
	if not U.LooksLikeName(name) then
		return false
	end
	-- ONCE A MINUTE, LIKE EVERY OTHER SOURCE (Josh 2026-09-23, audit): a
	-- battleground scoreboard refreshes over and over, and every refresh was
	-- a "sighting" of all forty
	local key = U.Key(name)
	local fresh = BT.Collect and BT.Collect.Fresh
	if key and fresh and not fresh(key) then
		return false
	end
	info.vouch = true
	-- ONE SIDE'S LISTS (Josh 2026-09-30): /who, your friends, your mail and a
	-- channel's members are all your own faction's; a battleground's
	-- scoreboard says each player's own
	if info.faction == nil and BT.Collect and BT.Collect.Side then
		info.faction = BT.Collect.Side("player")
	end
	return DB.Note(BT.db, name, nil, info) ~= nil
end

-- THE CLASS AS A TOKEN (Josh 2026-09-23, audit). The friends list names the
-- class in words ("Warrior") where everything else gives the token
-- ("WARRIOR"), and the census counted the two as different classes. Words are
-- turned back into the token; anything unknown is left out rather than
-- filed wrong.
local classByName
function R.ClassToken(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	-- a token is one word in capitals ("WARRIOR", "DEATHKNIGHT")
	if text:match("^%u+$") or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[text]) then
		return text
	end
	if not classByName then
		classByName = {}
		for _, list in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
			for token, words in pairs(type(list) == "table" and list or {}) do
				classByName[words] = token
			end
		end
	end
	return classByName[text]
end

-- A /who YOU ran. Sending one is blocked for addons on this client; reading
-- the reply is not.
function R.WhoResults()
	local cf = C_FriendList
	local count = (cf and cf.GetNumWhoResults) or _G.GetNumWhoResults
	local info = (cf and cf.GetWhoInfo) or _G.GetWhoInfo
	if not (count and info) then
		return 0
	end
	local n = count() or 0
	local wrote = 0
	for i = 1, n do
		local w = info(i)
		if type(w) == "table" and w.fullName then
			-- no race: the row names it in words, not the token the rest of
			-- the book files races under - it comes from seeing them instead
			if note(w.fullName, {
				src = "who", class = R.ClassToken(w.filename), zone = w.area,
				level = (type(w.level) == "number" and w.level > 0) and w.level or nil,
				-- a /who row states the guild outright, blank when there is
				-- none: the one source that can record leaving one
				guild = w.fullGuildName or "",
			}) then
				wrote = wrote + 1
			end
		end
	end
	return wrote
end

function R.Friends()
	local cf = C_FriendList
	if not (cf and cf.GetNumFriends and cf.GetFriendInfoByIndex) then
		return 0
	end
	local wrote = 0
	for i = 1, (cf.GetNumFriends() or 0) do
		local f = cf.GetFriendInfoByIndex(i)
		if type(f) == "table" and f.name then
			if note(f.name, {
				src = "friends", class = R.ClassToken(f.className), zone = f.area,
				level = (type(f.level) == "number" and f.level > 0) and f.level or nil,
			}) then
				wrote = wrote + 1
			end
		end
	end
	return wrote
end

-- A battleground scoreboard is forty characters with their class and faction,
-- handed over in one table, most of whom you will never stand next to.
function R.Battleground()
	if not (GetNumBattlefieldScores and GetBattlefieldScore) then
		return 0
	end
	local wrote = 0
	for i = 1, (GetNumBattlefieldScores() or 0) do
		local name, _, _, _, _, side, _, _, _, classToken = GetBattlefieldScore(i)
		if name then
			-- the class only when it is a real token (the scoreboard's layout
			-- differs between clients), and no race: it is given in words.
			-- The side is 0 for the Horde, 1 for the Alliance.
			local faction = (side == 0 and "Horde") or (side == 1 and "Alliance") or false
			if note(name, { src = "bg", class = R.ClassToken(classToken), faction = faction }) then
				wrote = wrote + 1
			end
		end
	end
	return wrote
end

function R.Mail()
	if not (GetInboxNumItems and GetInboxHeaderInfo) then
		return 0
	end
	local wrote = 0
	for i = 1, (GetInboxNumItems() or 0) do
		local _, _, sender = GetInboxHeaderInfo(i)
		-- an auction house or a quest sends mail too; those are not characters.
		-- The sender reads "Auction House" (or "Alliance Auction House" on some
		-- builds): the old pattern needed capitals BEFORE the word and let the
		-- plain one through, where LooksLikeName then filed it as a person
		if type(sender) == "string" and sender ~= "" and not sender:lower():find("auction", 1, true) then
			if note(sender, { src = "mail" }) then
				wrote = wrote + 1
			end
		end
	end
	return wrote
end

-- CHAT_MSG_CHANNEL_LIST carries the membership of a channel as one comma-
-- separated string - every player in the zone's General, or the realm's Trade.
-- The client only receives it when somebody types /chatlist, so this reads
-- yours rather than asking for its own.
function R.ChannelList(text)
	if type(text) ~= "string" then
		return 0
	end
	local wrote = 0
	for name in text:gmatch("[^,]+") do
		-- the list marks owners and moderators with @ and +
		name = name:gsub("^%s*[@+]?%s*", ""):gsub("%s*$", "")
		if name ~= "" and note(name, { src = "channel" }) then
			wrote = wrote + 1
		end
	end
	return wrote
end
