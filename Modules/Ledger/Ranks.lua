-- The Ravenholdt Ledger's ranks, points and commendations (Josh 2026-10-05).
--
-- THE LEDGER GAMIFIED, AS THE EXPEDITION IS (Josh 2026-10-04: "I'd like to
-- gamify the ledger in a similar way - achievements for hitting breakpoints
-- on number of characters scanned, number of tags given, number of notes.
-- The 'scanned' achievements will need to be quite high (I have 35,000 from
-- not a ton of playtime). We can have ranks just like the expedition"). The
-- keeper is Lord Jorach Ravenholdt (2026-10-05: "something that would be
-- more of the 'big brother is watching' vibe, but still keep the WoW RP"),
-- and the ranks are a spy's. The thresholds are the Expedition's, so the two
-- books climb alike.
--
--   points      one for every hundred characters recorded, two a note, one
--               a tag, and each commendation's own
--   the book    the realm's: every character of yours there shares one rank,
--               where the Expedition is each character's own
--
-- When each commendation was earned is kept in the realm's book
-- (BeebModDB.ledger.realms[key].earned), and the rank last seen there, so a
-- new one is told once (Modules/Ledger/Line.lua).
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Ranks.lua")

local U = BT.Util
local N = BT.Notes
local L = {}
BT.LedgerRanks = L

-- Lord Jorach Ravenholdt, at his manor in the Alterac Mountains
L.NPC = 6768

L.RANKS = {
	{ 0, "Fledgling" }, { 50, "Lookout" }, { 150, "Eavesdropper" }, { 300, "Informant" }, { 500, "Shadow" },
	{ 800, "Agent" }, { 1200, "Handler" }, { 1800, "Spymaster" }, { 2600, "Master of Shadows" },
	{ 3600, "Eye of Ravenholdt" },
}

-- Art/Ravenholdt/rank1.tga to rank10.tga, drawn by scripts/make-badges.py
-- from scripts/ravenholdt-badges.html (written out, so the tests can check
-- that each file is there)
L.BADGES = {
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank1",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank2",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank3",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank4",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank5",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank6",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank7",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank8",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank9",
	"Interface\\AddOns\\BeebMod\\Art\\Ravenholdt\\rank10",
}
function L.RankBadge(n)
	n = math.max(1, math.min(#L.BADGES, math.floor(tonumber(n) or 1)))
	return L.BADGES[n]
end

-- WHAT JORACH SAYS TO YOU, a line for each rank (the "Sister journals"
-- canvas, 2026-10-05). The first is the one on the Ledger's settings page.
-- IN HIS OWN VOICE (Josh 2026-10-05: "Lets do the same content updates for
-- Ravenholdt. Find a number of sources so you can learn how the NPC talks").
-- In 1.12 he is a showy host ("Welcome, welcome, welcome!"), and Fahrad's
-- letter says "Ravenholdt has taken an interest in you... We have been
-- watching." In Legion's Hall of Shadows he is a calm chairman who speaks as
-- "we": "We operate where others cannot", "You have my ear", "Your
-- reputation precedes you", "I must admit to a certain level of envy", "We
-- do not need the fame. We reap the rewards." Dry, polite, business-like;
-- he never cheers and never calls anyone a hero. The fifth rank is his
-- council's title: "Take your seat as the final Shadow".
local function quoted(s)
	return "\226\128\156" .. s .. "\226\128\157"
end
L.QUOTES = {
	quoted("Welcome, welcome, welcome! We have been watching you. Now you watch everyone else."),
	quoted("You see faces where others see a crowd. Clever. Keep your eyes open."),
	quoted("People speak freely when they think no one is listening. Rather careless of them."),
	quoted("A name, a guild, a level. Small things add up. You have my ear."),
	quoted("Take your seat among the Shadows. We operate where others cannot."),
	quoted("Your reputation precedes you. Do try to keep it a little quieter."),
	quoted("You run people of your own now. Trust them, or at least trust them to get the job done."),
	quoted("Your files are better kept than mine. I must admit to a certain level of envy."),
	quoted("Kings ask me what happens in their own cities. Lately, I find myself asking you."),
	quoted("Nothing on this realm escapes you now. We do not need the fame. We reap the rewards."),
}

-- the rank `points` earn: its number, its title, the points it began at, and
-- the next one's points and title (nil at the top), as BT.Expedition.Rank
function L.Rank(points)
	points = points or 0
	local i = 1
	for n, r in ipairs(L.RANKS) do
		if points >= r[1] then
			i = n
		end
	end
	local here, nxt = L.RANKS[i], L.RANKS[i + 1]
	return i, here[2], here[1], nxt and nxt[1], nxt and nxt[2]
end

-- ---------------------------------------------------------------------------
-- What the book holds
-- ---------------------------------------------------------------------------

-- POINTS FOR WHAT YOU WRITE AND SEE: a character recorded is a hundredth of a
-- point, a note two, a tag one
L.PER_CHARACTERS, L.NOTE_POINTS, L.TAG_POINTS = 100, 2, 1

-- the characters the census holds for this realm: counted once when the book
-- is bound, then one more for each new row (Core/DB.lua, DB.onNew)
L.characters = 0

function L.CountCharacters()
	local db = BT.db
	if not (db and BT.DB and BT.DB.Count) then
		L.characters = 0
		return 0
	end
	L.characters = (BT.DB.Count(db))
	return L.characters
end

-- what the commendations are measured against, from this realm's book
function L.Counts()
	local c = { characters = L.characters or 0, notes = 0, tags = 0, kinds = {}, own = false, grouped = 0, wins = 0 }
	for _, p in pairs((N and N.People()) or {}) do
		if type(p) == "table" then
			if p.note ~= nil then
				c.notes = c.notes + 1
			end
			if type(p.tags) == "table" then
				for tag in pairs(p.tags) do
					c.tags = c.tags + 1
					c.kinds[tag] = true
				end
			end
			if (tonumber(p.grouped) or 0) > 0 then
				c.grouped = c.grouped + 1
			end
			c.wins = c.wins + (tonumber(p.duelsWon) or 0)
		end
	end
	-- a tag of your own made, whether or not it is on anyone yet
	local mine = BT.settings and BT.settings.tags
	c.own = type(mine) == "table" and #mine > 0
	c.mixed = (c.kinds.good and 1 or 0) + (c.kinds.bad and 1 or 0) + (c.kinds.troll and 1 or 0)
	return c
end

-- ---------------------------------------------------------------------------
-- The commendations
-- ---------------------------------------------------------------------------

L.GROUPS = {
	{ key = "characters", title = "Characters" },
	{ key = "notes", title = "Notes" },
	{ key = "tags", title = "Tags" },
	{ key = "groups", title = "Groups" },
	{ key = "duels", title = "Duels" },
}

-- { need, points, title }
local CHARACTERS = {
	{ 100, 5, "New Faces" }, { 1000, 5, "Familiar Faces" }, { 5000, 10, "Head Count" },
	{ 10000, 15, "Persons of Interest" }, { 25000, 20, "Census Taker" }, { 50000, 25, "Nobody Slips By" },
	{ 100000, 40, "Everyone's in the Book" }, { 150000, 50, "Eyes Everywhere" },
}
local NOTES = {
	{ 1, 5, "First Entry" }, { 5, 5, "Taking Notes" }, { 10, 10, "Fine Print" }, { 25, 10, "Paper Trail" },
	{ 50, 15, "Case Files" }, { 100, 20, "Little Black Book" }, { 250, 25, "Dossier" },
	{ 500, 50, "Blackmail Material" },
}
local TAGS = {
	{ 1, 5, "Labelled" }, { 10, 5, "Sorted" }, { 25, 10, "Filed Away" }, { 100, 15, "Tagged and Bagged" },
	{ 250, 20, "Cross-Referenced" }, { 500, 30, "Everyone Has a Label" }, { 1000, 50, "A Price on Every Head" },
}
local GROUPS = {
	{ 1, 5, "Made Contact" }, { 10, 10, "Network" }, { 50, 15, "Web of Contacts" },
	{ 150, 25, "Friends in Every Guild" },
}
local DUELS = { { 1, 5, "Sized Up" }, { 10, 10, "Studied Opponents" }, { 50, 20, "Read Like a Book" } }

local function tiers(out, group, id, have, list, one, many)
	for _, t in ipairs(list) do
		out[#out + 1] = {
			id = id .. ":" .. t[1], group = group, title = t[3], points = t[2], need = t[1], have = have,
			text = t[1] == 1 and one or many:format(U.Commas(t[1])),
		}
	end
end

-- Every commendation there is, measured against `c` (L.Counts)
function L.List(c)
	c = c or L.Counts()
	local out = {}
	tiers(out, "characters", "characters", c.characters, CHARACTERS, "Record a character", "Record %s characters")
	tiers(out, "notes", "notes", c.notes, NOTES, "Write a note on a character", "Write notes on %s characters")
	tiers(out, "tags", "tags", c.tags, TAGS, "Tag a character", "Give %s tags")
	out[#out + 1] = { id = "tags:mixed", group = "tags", title = "Mixed Reviews", points = 10, need = 3, have = c.mixed,
		text = "Use the Good, Bad and Troll tags" }
	out[#out + 1] = { id = "tags:own", group = "tags", title = "Code Name", points = 10, need = 1,
		have = c.own and 1 or 0, text = "Make a tag of your own" }
	tiers(out, "groups", "groups", c.grouped, GROUPS, "Group with another player", "Group with %s different players")
	tiers(out, "duels", "duels", c.wins, DUELS, "Win a duel", "Win %s duels")
	return out
end

-- points, how many commendations, the counts they came from, and how many of
-- the points are the characters' and the notes' and tags'
function L.Points(c)
	c = c or L.Counts()
	local characters = math.floor((c.characters or 0) / L.PER_CHARACTERS)
	local entries = c.notes * L.NOTE_POINTS + c.tags * L.TAG_POINTS
	local points, count = characters + entries, 0
	for _, a in ipairs(L.List(c)) do
		if a.have >= a.need then
			points = points + a.points
			count = count + 1
		end
	end
	return points, count, c, characters, entries
end

function L.Score()
	return L.Points(L.Counts())
end

-- ---------------------------------------------------------------------------
-- When each was earned, and what is new
-- ---------------------------------------------------------------------------

-- the realm's book, where the dates are kept; nothing while made-up notes
-- are shown (Modules/Ledger/Demo.lua)
function L.Book()
	if N.demo or not N.Book then
		return nil
	end
	return N.Book()
end

-- when a commendation was earned: a time, 0 for "before the Ledger kept
-- dates", or nil for not yet
function L.EarnedAt(id)
	local book = L.Book()
	return book and type(book.earned) == "table" and book.earned[id] or nil
end

-- What is new since the book was last looked at: every commendation now met
-- that has no date (dated now), and a rank above the one kept. The first look
-- at a book writes down what it already has without a word about it - a
-- Ledger of a month's notes is not a month of notices at once.
-- Gives back the new commendations, the new rank (or nil) and the score.
function L.Check(now)
	local book = L.Book()
	local points, _, c = L.Score()
	local rank = L.Rank(points)
	if not book then
		return {}, nil, points, c
	end
	now = now or U.Now()
	local first = type(book.earned) ~= "table"
	book.earned = book.earned or {}
	local news = {}
	for _, a in ipairs(L.List(c)) do
		if a.have >= a.need and book.earned[a.id] == nil then
			book.earned[a.id] = first and 0 or now
			if not first then
				news[#news + 1] = a
			end
		end
	end
	-- THE HIGHEST RANK REACHED, KEPT: points can fall (a tag deleted from
	-- everyone, the book trimmed), and climbing back is not a new rank
	local was = tonumber(book.rank)
	book.rank = math.max(was or 0, rank)
	local up = (not first and was and rank > was) and rank or nil
	return news, up, points, c
end

-- ---------------------------------------------------------------------------
-- Heard
-- ---------------------------------------------------------------------------
--
-- A note, a tag, a group or a duel is heard from the Ledger's book (N.onTouched),
-- a new character from the census (DB.onNew). Whatever comes in one moment is
-- looked at once, a second later: a crowded city records a dozen characters
-- a heartbeat, and their notices are one (UI/Notice.lua).
L.WAIT = 1

function L.Changed()
	if L.pending then
		return
	end
	L.pending = true
	local function go()
		L.pending = nil
		if L.onChange then
			L.onChange()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(L.WAIT, go)
	else
		go()
	end
end

if N then
	N.onTouched = function()
		L.Changed()
	end
end
if BT.DB then
	BT.DB.onNew = function(db)
		if db == BT.db then
			L.characters = (L.characters or 0) + 1
			-- only a hundredth is a point, and the next commendation is at a
			-- round number: the rest is no change worth looking at
			if L.characters % L.PER_CHARACTERS == 0 then
				L.Changed()
			end
		end
	end
end
