-- What this client lets addons say to each other (Josh 2026-09-25).
--
-- Sharing the book, and your notes with friends, both ride on hidden addon
-- messages: text a player never sees, sent between two copies of an addon.
-- Nothing in BeebMod has sent one yet, and this client locks away a lot, so
-- before anything is built on them they are tried - with a friend, because
-- it takes two.
--
-- IT RUNS ITSELF (Josh 2026-09-25: "I'd like to just have someone install
-- the addon, and not have to bother them about running probes or
-- anything").
--
-- EVERYONE, NOT FRIENDS (Josh 2026-09-25: "I want friends lists to share
-- notes, but I want everyone with the addon installed to share census data.
-- The WoW Forever beta doesn't have a functional friends list yet"). So what
-- is tried is the public way: after the loading screen, out of combat, every
-- copy joins a hidden channel - out of every chat window, its notices
-- filtered away - and says one hello on it a session. Whoever hears it
-- answers by whisper, a stranger to a stranger, with a line about its client,
-- so both ends are in YOUR file; once a day a short burst measures how much
-- gets through. An answer waits a few random seconds and nobody answers more
-- than a few hellos a minute, so a busy channel cannot flood anyone. A friend
-- online, and the guild, get a hello too, where the client says who they are.
--
-- None of it prints - only a player on a newer build than yours says so,
-- once - and all of it is in /bt comms log and the saved file. A switch on
-- the Testing page stops it.
--
-- The commands are still here, for trying something by hand:
--
--   /bt comms              what the client offers: the calls, the friends
--                          list, the channels - written down and printed
--   /bt comms ping <name>  a hidden whisper; theirs answers, and both say so
--   /bt comms guild        the same to your guild
--   /bt comms channel      join a hidden channel and say hello on it
--   /bt comms burst <name> [n]  n whispers as fast as the client will take
--                          them (40 unless you say): how many it let out, and
--                          how many arrived
--   /bt comms log          what was sent and heard this session
--   /bt comms clear        forget it
--
-- Everything goes into BeebModDB.commsProbe as well; /reload to save it.
-- It uses the client's own calls and no library, so what it reports is the
-- client's behaviour and nothing else's. It never prints a secret value.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/CommsProbe.lua")

local U = BT.Util

local P = {}
BT.CommsProbe = P

P.PREFIX = "BeebModProbe"
-- the channel every copy of BeebMod meets on: the census will be shared
-- with whoever is in it (the notes, later, with friends only)
P.CHANNEL = "BeebModNet"
P.LOG_MAX = 300

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a value as words, never a secret as text
local function say(v)
	if secret(v) then
		return "SECRET(" .. type(v) .. ")"
	end
	local t = type(v)
	if t == "string" then
		return ("%q"):format(v:sub(1, 60))
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(v)
	elseif t == "table" then
		local n = 0
		for _ in pairs(v) do
			n = n + 1
		end
		return ("table(%d)"):format(n)
	end
	return t
end
P.Say = say

local function now()
	return type(GetTime) == "function" and GetTime() or 0
end

-- ---------------------------------------------------------------------------
-- The log: this session's, and the file's
-- ---------------------------------------------------------------------------

P.log = {}

local function store()
	if type(BeebModDB) ~= "table" then
		return nil
	end
	BeebModDB.commsProbe = BeebModDB.commsProbe or {}
	return BeebModDB.commsProbe
end

-- quiet unless you asked for something by hand this session: the automatic
-- hellos write to the log and the file, never to your chat
P.verbose = false

local function note(line, quiet)
	quiet = quiet or not P.verbose
	local stamp = ("%.2f %s"):format(now(), line)
	P.log[#P.log + 1] = stamp
	if #P.log > P.LOG_MAX then
		table.remove(P.log, 1)
	end
	local s = store()
	if s then
		s.log = s.log or {}
		s.log[#s.log + 1] = (U.Now and U.Now() or 0) .. " " .. line
		while #s.log > P.LOG_MAX do
			table.remove(s.log, 1)
		end
		s.build = BT.BUILD
	end
	if not quiet then
		U.Print("comms · " .. line)
	end
end
P.Note = note

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

-- the client's answer to a send, by name where it has one
local function resultName(r)
	if r == nil then
		return "nil"
	end
	if r == true or r == false then
		return tostring(r)
	end
	local e = Enum and Enum.SendAddonMessageResult
	if type(e) == "table" then
		for name, v in pairs(e) do
			if v == r then
				return name
			end
		end
	end
	return say(r)
end
P.ResultName = resultName

local function registered()
	if P.prefixOk ~= nil then
		return P.prefixOk
	end
	local C = C_ChatInfo
	if not (C and C.RegisterAddonMessagePrefix) then
		P.prefixOk = false
		note("no C_ChatInfo.RegisterAddonMessagePrefix")
		return false
	end
	local ok, r = pcall(C.RegisterAddonMessagePrefix, P.PREFIX)
	P.prefixOk = ok and r ~= false and true or false
	note(("prefix %s registered: %s"):format(P.PREFIX, ok and resultName(r) or ("error " .. tostring(r):sub(1, 80))), true)
	return P.prefixOk
end

-- one message; returns what the client said, as a name
function P.Send(text, chatType, target)
	registered()
	local C = C_ChatInfo
	if not (C and C.SendAddonMessage) then
		return "absent"
	end
	local ok, r = pcall(C.SendAddonMessage, P.PREFIX, text, chatType, target)
	local said = ok and resultName(r) or ("error " .. tostring(r):sub(1, 80))
	P.lastSend = now()
	return said
end

-- ---------------------------------------------------------------------------
-- What the client offers
-- ---------------------------------------------------------------------------

local function has(ns, fn)
	local t = _G[ns]
	return type(t) == "table" and type(t[fn]) == "function"
end

function P.Survey()
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	add(("build %s · realm %s"):format(tostring(BT.BUILD), say(GetRealmName and GetRealmName())))
	for _, fn in ipairs({ "RegisterAddonMessagePrefix", "SendAddonMessage", "SendAddonMessageLogged",
		"IsAddonMessagePrefixRegistered", "GetRegisteredAddonMessagePrefixes", "InChatMessagingLockdown" }) do
		add(("C_ChatInfo.%s: %s"):format(fn, has("C_ChatInfo", fn) and "yes" or "absent"))
	end
	registered()
	add("prefix registered: " .. tostring(P.prefixOk))
	if has("C_ChatInfo", "InChatMessagingLockdown") then
		local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
		add("messaging locked down now: " .. (ok and say(v) or "error"))
	end
	-- the friends list: can we read who is on it, and whether they are online?
	if has("C_FriendList", "GetNumFriends") then
		local ok, n = pcall(C_FriendList.GetNumFriends)
		add("friends: " .. (ok and say(n) or "error"))
		if ok and type(n) == "number" and n > 0 and has("C_FriendList", "GetFriendInfoByIndex") then
			local ok2, info = pcall(C_FriendList.GetFriendInfoByIndex, 1)
			if ok2 and type(info) == "table" then
				add(("first friend: name %s · connected %s · level %s · className %s"):format(
					say(info.name), say(info.connected), say(info.level), say(info.className)))
			else
				add("first friend: " .. say(info))
			end
		end
	else
		add("C_FriendList.GetNumFriends: absent")
	end
	if type(BNGetNumFriends) == "function" then
		local ok, total, online = pcall(BNGetNumFriends)
		add(("Battle.net friends: %s, %s online"):format(ok and say(total) or "error", ok and say(online) or "?"))
	end
	add("in a guild: " .. say(IsInGuild and IsInGuild()))
	for _, fn in ipairs({ "JoinTemporaryChannel", "JoinChannelByName", "LeaveChannelByName", "GetChannelName" }) do
		add(("%s: %s"):format(fn, type(_G[fn]) == "function" and "yes" or "absent"))
	end
	local s = store()
	if s then
		s.survey = lines
	end
	for _, line in ipairs(lines) do
		U.Print("comms · " .. line)
	end
	return lines
end

-- ---------------------------------------------------------------------------
-- Ping, burst, channel
-- ---------------------------------------------------------------------------
--
-- On the wire, one letter and fields:
--   P:<id>          a ping; answered with Q:<id>
--   Q:<id>          the answer, timed against when P went
--   B:<run>:<i>:<n> one of a burst of n
--   C:<run>:<got>:<n> the other end's count of a burst, some seconds after
--   H:<build>       hello on the channel or to the guild; answered by whisper

P.pings = {}
P.bursts = {}

local seq = 0
local function nextId()
	seq = seq + 1
	return ("%d%03d"):format(math.floor(now() * 10) % 100000, seq % 1000)
end

function P.Ping(target, chatType)
	chatType = chatType or "WHISPER"
	local id = nextId()
	P.pings[id] = { at = now(), to = target or chatType }
	local r = P.Send("P:" .. id, chatType, target)
	note(("ping %s to %s: %s"):format(id, tostring(target or chatType), r))
	return r, id
end

function P.Burst(target, n)
	n = math.max(1, math.min(200, tonumber(n) or 40))
	local run = nextId()
	local results = {}
	for i = 1, n do
		local r = P.Send(("B:%s:%d:%d"):format(run, i, n), "WHISPER", target)
		results[r] = (results[r] or 0) + 1
	end
	local parts = {}
	for r, c in pairs(results) do
		parts[#parts + 1] = ("%s x%d"):format(r, c)
	end
	table.sort(parts)
	P.bursts[run] = { at = now(), n = n, to = target, results = results }
	note(("burst %s: %d to %s in one go · the client said %s"):format(run, n, tostring(target), table.concat(parts, ", ")))
	return results, run
end

-- A CHANNEL NOBODY SEES. Its notices ("Joined Channel: 5. BeebModNet") and
-- anything a person might type in it are filtered out of every chat window,
-- and the channel is taken off each window's list; the addon's own messages
-- on it are never shown anyway.
local function ours(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "string" and not secret(v) then
			local ok, hit = pcall(string.find, v:lower(), P.CHANNEL:lower(), 1, true)
			if ok and hit then
				return true
			end
		end
	end
	return false
end

-- the filters go in once a session (P.filtered)
local function hideChannel()
	if not P.filtered and type(ChatFrame_AddMessageEventFilter) == "function" then
		P.filtered = true
		local function filter(_, _, ...)
			return ours(...)
		end
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_NOTICE", filter)
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_NOTICE_USER", filter)
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL", filter)
	end
	if type(ChatFrame_RemoveChannel) == "function" then
		for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
			local f = _G["ChatFrame" .. i]
			if f then
				pcall(ChatFrame_RemoveChannel, f, P.CHANNEL)
			end
		end
	end
end
P.HideChannel = hideChannel
P.Ours = ours

-- the channel's number, once we are in it
function P.ChannelNumber()
	if type(GetChannelName) ~= "function" then
		return nil
	end
	local ok, n = pcall(GetChannelName, P.CHANNEL)
	if ok and type(n) == "number" and not secret(n) and n > 0 then
		return n
	end
	return nil
end

-- in, quietly; `hello` says so on it once it is joined
function P.JoinQuietly(hello)
	hideChannel()
	local joined, why = false, "no join call"
	if not P.ChannelNumber() then
		if type(JoinTemporaryChannel) == "function" then
			local ok, a = pcall(JoinTemporaryChannel, P.CHANNEL)
			joined, why = ok, ok and say(a) or tostring(a):sub(1, 80)
		elseif type(JoinChannelByName) == "function" then
			local ok, a = pcall(JoinChannelByName, P.CHANNEL)
			joined, why = ok, ok and say(a) or tostring(a):sub(1, 80)
		end
		note(("channel %s: join %s (%s)"):format(P.CHANNEL, tostring(joined), tostring(why)))
	end
	-- a channel takes a moment to join, and only then leaves the windows
	local function after()
		hideChannel()
		local n = P.ChannelNumber()
		if not n then
			note("not in the channel: " .. say(type(GetChannelName) == "function" and select(2, pcall(GetChannelName, P.CHANNEL))))
			return
		end
		P.channelNumber = n
		if hello then
			P.hellos.channel = now()
			note(("hello on channel %d: %s"):format(n,
				P.Send(("H:%s:%s"):format(BT.VERSION or "?", tostring(BT.BUILD)), "CHANNEL", tostring(n))))
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(3, after)
	else
		after()
	end
	return joined
end

function P.Channel()
	local joined, why = false, nil
	if type(JoinTemporaryChannel) == "function" then
		local ok, a = pcall(JoinTemporaryChannel, P.CHANNEL)
		joined, why = ok, ok and say(a) or tostring(a):sub(1, 80)
	elseif type(JoinChannelByName) == "function" then
		local ok, a = pcall(JoinChannelByName, P.CHANNEL)
		joined, why = ok, ok and say(a) or tostring(a):sub(1, 80)
	end
	local id = type(GetChannelName) == "function" and GetChannelName(P.CHANNEL) or nil
	note(("channel %s: joined %s (%s) · number %s"):format(P.CHANNEL, tostring(joined), tostring(why), say(id)))
	-- a channel can take a moment to join; say hello once it has
	local function hello()
		local n = type(GetChannelName) == "function" and GetChannelName(P.CHANNEL) or nil
		if type(n) == "number" and n > 0 then
			note(("hello on channel %d: %s"):format(n, P.Send("H:" .. tostring(BT.BUILD), "CHANNEL", tostring(n))))
		else
			note("still not in the channel: " .. say(n))
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(2, hello)
	else
		hello()
	end
	return joined
end

function P.Guild()
	note("hello to the guild: " .. P.Send("H:" .. tostring(BT.BUILD), "GUILD"))
end

-- ---------------------------------------------------------------------------
-- Hearing
-- ---------------------------------------------------------------------------

local counting = {} -- [run] = { got, n, from }

function P.Heard(prefix, text, channel, sender)
	if prefix ~= P.PREFIX then
		return false
	end
	if secret(text) or secret(sender) then
		note(("heard something secret on %s"):format(say(channel)))
		return true
	end
	local kind = type(text) == "string" and text:sub(1, 1) or "?"
	-- the census, shared: its own module, and too many to write down each
	if kind == "S" then
		if BT.Share then
			BT.Share.Heard(text, sender)
		end
		return true
	end
	if kind == "P" then
		local id = text:match("^P:(%S+)$")
		note(("ping %s from %s on %s · answering: %s"):format(tostring(id), tostring(sender), tostring(channel),
			P.Send("Q:" .. tostring(id), "WHISPER", sender)))
	elseif kind == "Q" then
		local id = text:match("^Q:(%S+)$")
		local p = id and P.pings[id]
		if p then
			note(("answer to %s from %s: %.0f ms there and back"):format(id, tostring(sender), (now() - p.at) * 1000))
			P.pings[id] = nil
		else
			note(("an answer %s from %s to a ping this session did not send"):format(tostring(id), tostring(sender)))
		end
	elseif kind == "B" then
		local run, i, n = text:match("^B:(%S+):(%d+):(%d+)$")
		if run then
			local c = counting[run]
			if not c then
				c = { got = 0, n = tonumber(n), from = sender, first = now() }
				counting[run] = c
				-- all that is coming has come by then, or never will
				local function report()
					note(("burst %s from %s: %d of %d arrived, over %.1f s"):format(run, tostring(sender), c.got, c.n,
						(c.last or c.first) - c.first))
					P.Send(("C:%s:%d:%d"):format(run, c.got, c.n), "WHISPER", sender)
					counting[run] = nil
				end
				if C_Timer and C_Timer.After then
					C_Timer.After(10, report)
				end
			end
			c.got = c.got + 1
			c.last = now()
		end
	elseif kind == "C" then
		local run, got, n = text:match("^C:(%S+):(%d+):(%d+)$")
		note(("burst %s: %s says %s of %s arrived"):format(tostring(run), tostring(sender), tostring(got), tostring(n)))
	elseif kind == "H" then
		-- a channel, or the guild, hands you your own hello back
		if P.IsMe(sender) then
			note(("your own hello came back on %s, as %s"):format(tostring(channel), sender))
			return true
		end
		local version, build = text:match("^H:([^:]*):?(.*)$")
		P.Met(sender, version, build, channel)
		-- A LOTTERY, ON A CHANNEL (Josh 2026-09-25): one hello there reaches
		-- every copy, and a newcomer does not need a thousand answers - each
		-- answers with a chance of about three in however many it knows of
		if channel ~= "WHISPER" and math.random() > P.AnswerChance() then
			note(("hello from %s on %s · left to the others"):format(tostring(sender), tostring(channel)))
			return true
		end
		if not P.MayAnswer() then
			note(("hello from %s on %s · not answered: enough this minute"):format(tostring(sender), tostring(channel)))
			return true
		end
		note(("hello from %s on %s (%s, build %s) · answering"):format(tostring(sender), tostring(channel),
			tostring(version), tostring(build)))
		local function answer()
			P.Send(("A:%s:%s:%s"):format(BT.VERSION or "?", tostring(BT.BUILD), P.Report()), "WHISPER", sender)
		end
		-- a hello on a channel reaches everyone at once: the answers spread out
		if channel ~= "WHISPER" and C_Timer and C_Timer.After then
			C_Timer.After(2 + math.random() * 10, answer)
		else
			answer()
		end
	elseif kind == "A" then
		local version, build, report = text:match("^A:([^:]*):([^:]*):?(.*)$")
		local sent = P.hellos[P.Base(sender)] or P.hellos.channel or P.hellos.guild
		local rtt = sent and ((now() - sent) * 1000) or nil
		P.Met(sender, version, build, channel, report, rtt)
		note(("%s has BeebMod %s (build %s)%s · their client: %s"):format(tostring(sender), tostring(version),
			tostring(build), rtt and (" · %.0f ms there and back"):format(rtt) or "", tostring(report)))
		P.MaybeBurst(sender)
	else
		note(("something else from %s on %s: %s"):format(tostring(sender), tostring(channel), say(text)))
	end
	return true
end

-- a whisper to someone offline or unknown comes back as a system line; the
-- ones that arrive just after a send are kept, to see what the client says
function P.System(text)
	if P.lastSend and now() - P.lastSend < 3 then
		note("system, just after a send: " .. say(text), true)
	end
end

local frame = CreateFrame("Frame")
P.frame = frame
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		P.Heard(...)
	elseif event == "CHAT_MSG_SYSTEM" then
		P.System(...)
	end
end)

-- listening costs nothing until it is asked for: the events are registered
-- the first time /bt comms runs, on both ends
function P.Listen()
	if P.listening then
		return
	end
	P.listening = true
	for _, event in ipairs({ "CHAT_MSG_ADDON", "CHAT_MSG_SYSTEM" }) do
		local ok, err = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			note(("%s refused: %s"):format(event, tostring(err):sub(1, 80)))
		end
	end
	registered()
end

-- ---------------------------------------------------------------------------
-- By itself: hellos to friends, and what comes back
-- ---------------------------------------------------------------------------

P.hellos = {} -- [base name] = when the hello went; guild = the guild's
P.helloed = {} -- [base name] = true once this session

-- a name without its realm, for matching a whisper's sender to a friend
function P.Base(name)
	if type(name) ~= "string" then
		return nil
	end
	return (name:match("^([^%-]+)") or name):lower()
end

function P.IsMe(sender)
	local me = U.Me and U.Me()
	return me ~= nil and P.Base(sender) == P.Base(me)
end

function P.On()
	return not (BT.settings and BT.settings.commsHello == false)
end

-- a line about this client, for the other end's file: the prefix, the
-- friends list, the lockdown, the realm - short, and never a secret
function P.Report()
	local bits = {}
	bits[#bits + 1] = "prefix=" .. tostring(registered())
	local nf = C_FriendList and C_FriendList.GetNumFriends and select(2, pcall(C_FriendList.GetNumFriends))
	bits[#bits + 1] = "friends=" .. (secret(nf) and "secret" or tostring(nf))
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
		bits[#bits + 1] = "lockdown=" .. (ok and (secret(v) and "secret" or tostring(v)) or "error")
	end
	local realm = GetRealmName and GetRealmName()
	bits[#bits + 1] = "realm=" .. (secret(realm) and "secret" or tostring(realm):gsub("[:%s]", ""))
	return table.concat(bits, ";")
end

-- "0.1.0-beta.3" as something that sorts
local function versionKey(v)
	local a, b, c, stage, n = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)%-?(%a*)%.?(%d*)")
	if not a then
		return nil
	end
	local rank = ({ alpha = 1, beta = 2 })[stage] or 3
	return ((tonumber(a) * 1000 + tonumber(b)) * 1000 + tonumber(c)) * 10000 + rank * 1000 + (tonumber(n) or 0)
end
P.VersionKey = versionKey

-- somebody with BeebMod: kept for the session and in the file
P.peers = {}
function P.Met(sender, version, build, channel, report, rtt)
	local key = P.Base(sender)
	if not key then
		return
	end
	local peer = P.peers[key] or {}
	peer.name, peer.version, peer.build, peer.via = sender, version, build, channel
	peer.report = report or peer.report
	peer.rtt = rtt or peer.rtt
	peer.seen = U.Now and U.Now() or 0
	P.peers[key] = peer
	local s = store()
	if s then
		s.peers = s.peers or {}
		s.peers[key] = { name = sender, version = version, build = build, via = channel, report = peer.report,
			rtt = peer.rtt and math.floor(peer.rtt + 0.5) or nil, seen = peer.seen }
	end
	-- a friend on a newer build: said once a session, the one line this prints
	local theirs, mine = versionKey(version), versionKey(BT.VERSION)
	if theirs and mine and theirs > mine and not P.nagged then
		P.nagged = true
		U.Print(("%s has BeebMod %s · you have %s · update when you get a chance"):format(
			tostring(sender), tostring(version), tostring(BT.VERSION)))
	end
end

-- once a day a friend with BeebMod gets a short burst: how much gets through
P.BURST = 20
function P.MaybeBurst(sender)
	local s, key = store(), P.Base(sender)
	if not (s and key) then
		return
	end
	s.burstDay = s.burstDay or {}
	local today = math.floor((U.Now and U.Now() or 0) / 86400)
	if s.burstDay[key] == today then
		return
	end
	s.burstDay[key] = today
	P.Burst(sender, P.BURST)
end

-- about three answers to a hello on the channel, however many copies hear it
P.ANSWERS_WANTED = 3
function P.AnswerChance()
	local known = 0
	for _ in pairs(P.peers) do
		known = known + 1
	end
	if BT.Share then
		known = math.max(known, BT.Share.Senders())
	end
	return math.min(1, P.ANSWERS_WANTED / math.max(1, known))
end

-- a few answers a minute at most: one hello on a busy channel is heard by
-- everyone in it, and must not turn into everyone whispering everyone
P.ANSWERS_A_MINUTE = 5
local answered = {}
function P.MayAnswer()
	local t = now()
	for i = #answered, 1, -1 do
		if t - answered[i] > 60 then
			table.remove(answered, i)
		end
	end
	if #answered >= P.ANSWERS_A_MINUTE then
		return false
	end
	answered[#answered + 1] = t
	return true
end

-- not in a fight, not where the client locks messages away
local function quietMoment()
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and v == true then
			return false
		end
	end
	return true
end

-- the friends online now, by name, where the client will say
function P.OnlineFriends()
	local out = {}
	local F = C_FriendList
	if not (F and F.GetNumFriends and F.GetFriendInfoByIndex) then
		return out
	end
	local ok, n = pcall(F.GetNumFriends)
	if not ok or secret(n) or type(n) ~= "number" then
		return out
	end
	for i = 1, math.min(n, 100) do
		local ok2, info = pcall(F.GetFriendInfoByIndex, i)
		if ok2 and type(info) == "table" and not secret(info.name) and not secret(info.connected)
			and info.connected and type(info.name) == "string" and info.name ~= "" then
			out[#out + 1] = info.name
		end
	end
	return out
end

-- a hello to one friend, once a session
function P.Hello(name)
	local key = P.Base(name)
	if not key or P.helloed[key] or P.IsMe(name) then
		return false
	end
	P.helloed[key] = true
	P.hellos[key] = now()
	local r = P.Send(("H:%s:%s"):format(BT.VERSION or "?", tostring(BT.BUILD)), "WHISPER", name)
	note(("hello to %s: %s"):format(name, r))
	return true
end

-- a hello to every friend online, a few tenths of a second apart, and one to
-- the guild; put off while it is not a quiet moment
-- the census shared (Core/Share.lua) sits on the same channel
local function sharing()
	return BT.Share ~= nil and BT.Share.On()
end

function P.HelloAll()
	if not (P.On() or sharing()) then
		return 0
	end
	if not quietMoment() then
		if C_Timer and C_Timer.After then
			C_Timer.After(30, P.HelloAll)
		end
		return 0
	end
	P.Listen()
	local n = 0
	-- the channel everyone with BeebMod is in: joined quietly, and a hello
	-- on it while the hellos are on
	if not P.helloed.channel then
		P.helloed.channel = true
		P.JoinQuietly(P.On())
	end
	if not P.On() then
		return 0
	end
	for i, name in ipairs(P.OnlineFriends()) do
		if i > 25 then
			break
		end
		local key = P.Base(name)
		if not P.helloed[key] then
			n = n + 1
			if C_Timer and C_Timer.After then
				C_Timer.After(n * 0.3, function() P.Hello(name) end)
			else
				P.Hello(name)
			end
		end
	end
	if IsInGuild and IsInGuild() and not P.helloed.guild then
		P.helloed.guild = true
		P.hellos.guild = now()
		note("hello to the guild: " .. P.Send(("H:%s:%s"):format(BT.VERSION or "?", tostring(BT.BUILD)), "GUILD"))
	end
	return n
end

-- after the loading screen, and whenever the friends list changes (somebody
-- came online): friends not yet greeted this session are
local auto = CreateFrame("Frame")
P.auto = auto
auto:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(auto.RegisterEvent, auto, "FRIENDLIST_UPDATE")
auto:SetScript("OnEvent", function(_, event)
	if not (P.On() or sharing()) then
		return
	end
	P.Listen()
	if event == "PLAYER_ENTERING_WORLD" then
		if C_FriendList and C_FriendList.ShowFriends then
			pcall(C_FriendList.ShowFriends)
		end
		-- a moment for the client, and for a friend's own addon, to settle
		if C_Timer and C_Timer.After then
			C_Timer.After(15, P.HelloAll)
		end
	elseif event == "FRIENDLIST_UPDATE" and P.primed then
		-- a friend who just logged in: give their addon time to load
		if C_Timer and C_Timer.After then
			C_Timer.After(10, P.HelloAll)
		end
	end
	P.primed = true
end)

function P.SetOn(on)
	BT.EnsureBound()
	-- off is written down, on (the default) is not: `(not on) and false or nil`
	-- was nil either way, and the switch could never turn it off (Josh 2026-09-25)
	if on then
		BT.settings.commsHello = nil
	else
		BT.settings.commsHello = false
	end
	if on then
		P.HelloAll()
	end
end

-- ---------------------------------------------------------------------------
-- The command
-- ---------------------------------------------------------------------------

BT.Command("comms", function(rest)
	P.Listen()
	P.verbose = true
	local word, arg, more = (rest or ""):match("^(%S*)%s*(%S*)%s*(.-)$")
	word = (word or ""):lower()
	-- a name with a surname is two words: "Beeb Drood" as well as "Beeb-Drood"
	local function nameFrom(a, b)
		if a == "" then
			return nil
		end
		if b ~= "" and not tonumber(b) then
			return a .. " " .. b
		end
		return a
	end
	if word == "" or word == "survey" then
		P.Survey()
	elseif word == "ping" then
		local target = nameFrom(arg, more)
		if not target then
			U.Print("usage: /bt comms ping <name>")
			return
		end
		P.Ping(target)
	elseif word == "burst" then
		-- "burst Beeb Drood 40": the count is the last word, if it is a number
		local words = {}
		for w in (arg .. " " .. more):gmatch("%S+") do
			words[#words + 1] = w
		end
		local n = tonumber(words[#words])
		if n then
			table.remove(words)
		end
		if #words == 0 then
			U.Print("usage: /bt comms burst <name> [how many]")
			return
		end
		P.Burst(table.concat(words, " "), n)
	elseif word == "guild" then
		P.Guild()
	elseif word == "channel" then
		P.Channel()
	elseif word == "friends" then
		local any = false
		for _, peer in pairs(P.peers) do
			any = true
			U.Print(("comms · %s: BeebMod %s%s · %s"):format(tostring(peer.name), tostring(peer.version),
				peer.rtt and (" · %.0f ms"):format(peer.rtt) or "", tostring(peer.report)))
		end
		if not any then
			U.Print("comms · no friend with BeebMod has answered this session")
		end
	elseif word == "log" then
		for i = math.max(1, #P.log - 30), #P.log do
			U.Print("comms · " .. P.log[i])
		end
		if #P.log == 0 then
			U.Print("comms · nothing sent or heard yet this session")
		end
	elseif word == "clear" then
		P.log = {}
		if type(BeebModDB) == "table" then
			BeebModDB.commsProbe = nil
		end
		U.Print("comms · forgotten")
	else
		U.Print("comms · /bt comms [friends | ping <name> | guild | channel | burst <name> [n] | log | clear]")
	end
end, "comms [friends | ping <name> | guild | channel | burst <name> [n] | log | clear] - hidden addon messages, and who has BeebMod")
