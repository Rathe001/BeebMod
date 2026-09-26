-- THE CENSUS, SHARED (Josh 2026-09-25: "would it be possible to implement a
-- basic version of census sharing right now"). Every copy of BeebMod tells
-- the others, on the hidden channel they all sit in (Core/CommsProbe.lua), about
-- the characters it sees - and files what they tell it.
--
-- NEWS, NOT THE BOOK (Josh: "not sure a catch up would even be needed really.
-- It won't take too long for players to catch up naturally if new sightings
-- are shared"). Nothing is sent from the book as it stands; only a sighting
-- of yours that is news: somebody new, somebody seen for the first time
-- today, a new level, a new guild (DB.OnNews).
--
-- AND NOT 1000 COPIES SAYING IT (Josh: "we need to somehow rate limit so we
-- don't have 1000 players sending tons of messages"):
--
--   * news waits a random half a minute to two minutes before it goes; if
--     another copy says it first, yours is dropped - in a city full of
--     BeebMod users each character goes out about once, not once each
--   * the channel has one budget, about two messages a second, shared out
--     between everyone heard sending: with ten copies each may send every
--     five seconds, with a thousand every eight minutes - the channel is as
--     busy as the realm is big, not as the addon is popular
--   * six or so characters a message; the most useful first (a new level or
--     guild, then somebody new, then seen-again-today); news that has
--     waited a quarter of an hour is let go
--   * a copy that sends far more than its share is not listened to again
--     this session, and a line that does not read as a character is dropped
--
-- What arrives is filed as HEARD (DB.Note): never a sighting of yours, never
-- over a guild you saw more recently, never passed on. A switch on the Census
-- page turns sharing off, both ways.
--
-- On the wire, after the channel prefix:
--   S:1:<entry>;<entry>;...
--   entry = name,class,race,level,guild,minutes
--     class and race: a place in the lists below (0 unknown); level: 0
--     unknown; guild: "" unknown, "~" no guild; minutes: how long ago it was
--     seen, when it went
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Share.lua")

local U, DB = BT.Util, BT.DB
local S = {}
BT.Share = S

S.WIRE = 1
S.MAX_LEN = 250          -- a message, all of it
S.BUDGET = 2             -- messages a second, for the whole channel
S.MIN_GAP = 5            -- never more often than this, however quiet it is
S.HOLD_MIN, S.HOLD_MAX = 30, 120 -- how long news waits for somebody else to say it
S.STALE = 15 * 60        -- news older than this is let go
S.FLOOD = 30             -- messages a minute from one copy before it is ignored
S.SENDERS_WINDOW = 10 * 60

S.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
	"MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
S.RACES = { "Human", "Dwarf", "NightElf", "Gnome", "Orc", "Scourge", "Tauren", "Troll", "BloodElf", "Draenei",
	"Goblin", "Worgen", "Pandaren" }
local classAt, raceAt = {}, {}
for i, c in ipairs(S.CLASSES) do
	classAt[c] = i
end
for i, r in ipairs(S.RACES) do
	raceAt[r] = i
end

local PRIORITY = { level = 1, guild = 1, new = 2, today = 3 }

local function clock()
	return type(GetTime) == "function" and GetTime() or 0
end

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

S.stats = { queued = 0, sent = 0, entriesSent = 0, dropped = 0, heard = 0, entriesHeard = 0, filed = 0,
	rejected = 0, ignored = 0 }

function S.On()
	return BT.settings and BT.settings.shareCensus ~= false and BT.Enabled and BT.Enabled("census") or false
end

function S.SetOn(on)
	BT.EnsureBound()
	-- off is written down, on (the default) is not: `(not on) and false or nil`
	-- was nil either way, and the switch could never turn it off (Josh 2026-09-25)
	if on then
		BT.settings.shareCensus = nil
	else
		BT.settings.shareCensus = false
	end
end

-- ---------------------------------------------------------------------------
-- An entry, and back
-- ---------------------------------------------------------------------------

-- a character as one entry, or nil if it has nothing worth saying
function S.Encode(p, now)
	if type(p) ~= "table" or type(p.name) ~= "string" or not U.HasSurname(p.name) then
		return nil
	end
	if p.name:find("[,;:|]") then
		return nil
	end
	local guild = ""
	if p.guild == "" then
		guild = "~"
	elseif type(p.guild) == "string" then
		if p.guild:find("[,;:|~]") or #p.guild > 32 then
			return nil
		end
		guild = p.guild
	end
	local ago = math.max(0, math.floor(((now or U.Now()) - (p.last or now or 0)) / 60))
	return ("%s,%d,%d,%d,%s,%d"):format(p.name, classAt[p.class or ""] or 0, raceAt[p.race or ""] or 0,
		(type(p.level) == "number" and p.level) or 0, guild, math.min(ago, 999))
end

-- an entry as the fields DB.Note takes, and when; nil for anything that is
-- not plainly a character
function S.Decode(entry, now)
	if type(entry) ~= "string" or #entry > 80 then
		return nil
	end
	local name, c, r, l, g, m = entry:match("^([^,]+),(%d+),(%d+),(%d+),([^,]*),(%d+)$")
	if not name then
		return nil
	end
	if not (U.LooksLikeName(name) and U.HasSurname(name)) or #name > 40 then
		return nil
	end
	c, r, l, m = tonumber(c), tonumber(r), tonumber(l), tonumber(m)
	if c > #S.CLASSES or r > #S.RACES or l > 100 or m > 999 then
		return nil
	end
	local info = { heard = true }
	info.class = c > 0 and S.CLASSES[c] or nil
	info.race = r > 0 and S.RACES[r] or nil
	info.level = l > 0 and l or nil
	if g == "~" then
		info.guild = ""
	elseif g ~= "" then
		if #g > 32 then
			return nil
		end
		info.guild = g
	end
	return name, info, (now or U.Now()) - m * 60
end

-- ---------------------------------------------------------------------------
-- Sending: the news waits, and goes when it is our turn
-- ---------------------------------------------------------------------------

S.queue = {} -- [key] = { due, kind, at }
S.saidToday = {} -- [key] = the day it was said, by us or by anyone

local function today(t)
	return math.floor((t or U.Now()) / 86400)
end

-- DB.OnNews: a sighting of yours worth telling
function S.News(db, key, kind)
	if db ~= BT.db or not S.On() then
		return
	end
	-- said today already (by us or by another copy), and nothing new since
	if kind == "today" and S.saidToday[key] == today() then
		return
	end
	local q = S.queue[key]
	if q then
		if (PRIORITY[kind] or 9) < (PRIORITY[q.kind] or 9) then
			q.kind = kind
		end
		return
	end
	S.queue[key] = { due = clock() + S.HOLD_MIN + math.random() * (S.HOLD_MAX - S.HOLD_MIN), kind = kind, at = clock() }
	S.stats.queued = S.stats.queued + 1
end
DB.OnNews = S.News

-- who is sending, to share the channel's budget out
S.senders = {} -- [sender] = last heard (clock)

function S.Senders()
	local n, t = 0, clock()
	for who, at in pairs(S.senders) do
		if t - at > S.SENDERS_WINDOW then
			S.senders[who] = nil
		else
			n = n + 1
		end
	end
	return n
end

-- how long between two messages of ours: our share of the channel's budget
function S.Gap()
	return math.max(S.MIN_GAP, (S.Senders() + 1) / S.BUDGET)
end

-- the next message: what is due, most useful first, as many as fit; the
-- stale let go. Returns the text and how many it carries, or nil.
function S.Next(now)
	local t = clock()
	local due = {}
	for key, q in pairs(S.queue) do
		if t - q.at > S.STALE then
			S.queue[key] = nil
			S.stats.dropped = S.stats.dropped + 1
		elseif q.due <= t then
			due[#due + 1] = { key = key, q = q }
		end
	end
	if #due == 0 then
		return nil
	end
	table.sort(due, function(a, b)
		local pa, pb = PRIORITY[a.q.kind] or 9, PRIORITY[b.q.kind] or 9
		if pa ~= pb then
			return pa < pb
		end
		return a.q.at < b.q.at
	end)
	local head = ("S:%d:"):format(S.WIRE)
	local parts, len, used = {}, #head, 0
	for _, d in ipairs(due) do
		local p = DB.Get(BT.db, d.key)
		local e = p and not p.heard and S.Encode(p, now)
		if e then
			if len + #e + 1 > S.MAX_LEN then
				break
			end
			parts[#parts + 1] = e
			len = len + #e + 1
		end
		S.queue[d.key] = nil
		S.saidToday[d.key] = today(now)
		used = used + 1
	end
	if #parts == 0 then
		return nil
	end
	return head .. table.concat(parts, ";"), #parts
end

-- one tick: our turn, and something to say, and the channel to say it on
S.lastSent = -math.huge
function S.Tick()
	if not S.On() or not next(S.queue) then
		return false
	end
	if clock() - S.lastSent < S.Gap() then
		return false
	end
	local P = BT.CommsProbe
	local n = P and P.ChannelNumber and P.ChannelNumber()
	if not n then
		return false
	end
	local text, count = S.Next()
	if not text then
		return false
	end
	S.lastSent = clock()
	local r = P.Send(text, "CHANNEL", tostring(n))
	S.stats.sent = S.stats.sent + 1
	S.stats.entriesSent = S.stats.entriesSent + count
	S.stats.lastResult = r
	return true
end

-- ---------------------------------------------------------------------------
-- Hearing: another copy's news, filed as heard
-- ---------------------------------------------------------------------------

local perMinute = {} -- [sender] = { t, n }
S.ignoring = {}

function S.Heard(text, sender)
	if not S.On() or type(text) ~= "string" or secret(text) or secret(sender) then
		return 0
	end
	if BT.CommsProbe and BT.CommsProbe.IsMe(sender) then
		return 0
	end
	if S.ignoring[sender] then
		return 0
	end
	-- a copy far over its share is not listened to again this session
	local w = perMinute[sender]
	local t = clock()
	if not w or t - w.t > 60 then
		w = { t = t, n = 0 }
		perMinute[sender] = w
	end
	w.n = w.n + 1
	if w.n > S.FLOOD then
		S.ignoring[sender] = true
		S.stats.ignored = S.stats.ignored + 1
		if BT.CommsProbe then
			BT.CommsProbe.Note(("not listening to %s: %d messages in a minute"):format(tostring(sender), w.n))
		end
		return 0
	end
	S.senders[sender] = t
	S.stats.heard = S.stats.heard + 1
	local body = text:match("^S:%d+:(.*)$")
	if not body or not BT.db then
		S.stats.rejected = S.stats.rejected + 1
		return 0
	end
	local filed, now = 0, U.Now()
	for entry in body:gmatch("[^;]+") do
		S.stats.entriesHeard = S.stats.entriesHeard + 1
		local name, info, when = S.Decode(entry, now)
		if name then
			local key = U.Key(name)
			-- said by somebody: ours can wait for tomorrow
			if key then
				S.saidToday[key] = today(now)
				S.queue[key] = nil
			end
			if DB.Note(BT.db, name, nil, info, when) then
				filed = filed + 1
			end
		else
			S.stats.rejected = S.stats.rejected + 1
		end
	end
	S.stats.filed = S.stats.filed + filed
	return filed
end

-- the channel's messages come through the probe's listener
local ticker = CreateFrame("Frame")
S.ticker = ticker
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	since = since + (elapsed or 0)
	if since < 1 then
		return
	end
	since = 0
	S.Tick()
end)

BT.Command("share", function()
	local st = S.stats
	U.Print(("census sharing %s · %d other copies sending · one message every %.0f s"):format(
		S.On() and "on" or "off", S.Senders(), S.Gap()))
	local waiting = 0
	for _ in pairs(S.queue) do
		waiting = waiting + 1
	end
	U.Print(("sent %d messages, %d characters · %d waiting · %d let go"):format(st.sent, st.entriesSent, waiting,
		st.dropped))
	U.Print(("heard %d messages, %d characters · %d filed · %d turned away · %d copies ignored"):format(
		st.heard, st.entriesHeard, st.filed, st.rejected, st.ignored))
end, "share - how the census sharing is going")
