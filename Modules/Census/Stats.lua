-- What the book adds up to (Josh 2026-09-18). Pure Lua, so the headless tests
-- can check the arithmetic.
--
-- No SPEC here, and there cannot be: this game has no API that tells you a
-- stranger's talents, and inspecting needs them targeted and in range. Your
-- own tags stand in - they are the roles you actually care about.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Census/Stats.lua")

-- Chat hands over a name and nothing else, so a large part of any book has no
-- class, race or level. Hiding that would make every chart a lie about its own
-- sample. So: the CLASS chart carries "Unknown" as a row of its own, because
-- "how much of the realm have I actually identified" is worth seeing; the race
-- and level charts leave those characters out and say how many they left out,
-- because an "unknown" bar in both would be the same people counted twice and
-- would drown the data we do have (Josh 2026-09-18).

local U, DB = BT.Util, BT.DB
local S = {}
BT.Stats = S

S.UNKNOWN = "__unknown"
-- a guild of "" is a character we have seen with no guild, which is not the
-- same as one we have never seen a guild line for (nil, UNKNOWN)
S.UNGUILDED = "__unguilded"
-- the rest of a long chart, summed into one row so its percentages still add up
S.OTHER = "__other"
-- SIXTY IS ITS OWN BAND (Josh 2026-09-19). "51-60" answers the wrong question:
-- what a raid leader wants to know is how many are DONE levelling, and a 54 is
-- not that. So the last stretch splits, and 60 stands alone.
S.BANDS = {
	{ min = 1,  max = 10, key = "1-10" },
	{ min = 11, max = 20, key = "11-20" },
	{ min = 21, max = 30, key = "21-30" },
	{ min = 31, max = 40, key = "31-40" },
	{ min = 41, max = 50, key = "41-50" },
	{ min = 51, max = 59, key = "51-59" },
	{ min = 60, max = 60, key = "60" },
}
S.AGE_BUCKETS = {
	{ key = "today", within = 86400 },
	{ key = "this week", within = 7 * 86400 },
	{ key = "this month", within = 30 * 86400 },
	{ key = "older", within = math.huge },
}

-- SEEN WITHIN (Josh 2026-09-24). A book kept for weeks remembers everyone who
-- ever passed through; "who plays here NOW" is the characters seen lately. The
-- window narrows every chart to one of these, and nil is the whole book.
S.SEEN = {
	{ key = "today", label = "Today", within = 86400 },
	{ key = "week",  label = "Week",  within = 7 * 86400 },
	{ key = "month", label = "Month", within = 30 * 86400 },
	{ key = "all",   label = "All" },
}
local seenWithin = {}
for _, s in ipairs(S.SEEN) do
	seenWithin[s.key] = s.within
end

-- Guild and zone are long charts - a realm has hundreds of guilds - so each
-- shows its largest and sums the rest into one row.
S.TOP = 10

local function sorted(counts)
	local rows = {}
	for key, n in pairs(counts) do
		rows[#rows + 1] = { key = key, n = n }
	end
	table.sort(rows, function(a, b)
		if a.n ~= b.n then
			return a.n > b.n
		end
		return a.key < b.key
	end)
	return rows
end

local function median(t)
	if #t == 0 then
		return nil
	end
	table.sort(t)
	local mid = math.floor((#t + 1) / 2)
	return t[mid]
end

-- Which band a level falls in, or nil for a character we have never seen.
-- (Looked up rather than searched for the whole levels: the census asks for
-- every character in the book each time it is drawn - Josh 2026-09-24.)
local bandAt = {}
for _, b in ipairs(S.BANDS) do
	for level = b.min, b.max do
		bandAt[level] = b.key
	end
end

function S.BandOf(level)
	if type(level) ~= "number" then
		return nil
	end
	local key = bandAt[level]
	if key then
		return key
	end
	for _, b in ipairs(S.BANDS) do
		if level >= b.min and level <= b.max then
			return b.key
		end
	end
	return nil
end

-- Every chart the window can draw, plus how old the book is.
--
-- `bands` is a set of band keys to count, or nil for all of them. It filters
-- the class, race and tag charts - who you are looking at - but never the
-- LEVEL chart, which is a chart OF the bands and would be nonsense filtered by
-- itself; there the selection is a highlight (Josh 2026-09-19). A character
-- with no level on file cannot be in a band, so a filter excludes them and the
-- footer says how many.
--
-- IN THREE STEPS (Josh 2026-09-24): a tally is begun, every character is
-- counted into it, and it is finished into the charts. S.Census does all of
-- it at once; S.CensusJob does the counting a slice at a time, so the window
-- open in a city never spends one frame on fourteen thousand characters.
--
-- THE FILTER (Josh 2026-09-24) is a table, every part of it optional:
--   bands   the brackets above
--   seen    a key of S.SEEN: only characters seen that recently count at all
--   pick    { mode = "class", key = "HUNTER" } - a bar clicked in the window.
--           Every OTHER chart counts only the characters it picks; its own
--           chart still counts everybody, with the bar lit, so you can see
--           what you picked from and pick again.

-- The key a character is filed under on each chart that can be picked from.
local function guildKey(p)
	local g = p.guild
	if g == nil then
		return S.UNKNOWN
	end
	return g == "" and S.UNGUILDED or g
end

local keyOf = {
	class = function(p) return p.class or S.UNKNOWN end,
	race = function(p) return p.race or S.UNKNOWN end,
	guild = guildKey,
	zone = function(p) return p.zone or S.UNKNOWN end,
}
S.PICKABLE = { class = true, race = true, guild = true, zone = true, tag = true }

local function picks(pick, p, tags)
	if pick.mode == "tag" then
		return tags ~= nil and tags[pick.key] ~= nil
	end
	local of = keyOf[pick.mode]
	return of ~= nil and of(p) == pick.key
end

local function begin(now, filter)
	filter = filter or {}
	local bands = filter.bands
	local filtering = false
	if bands then
		for _ in pairs(bands) do
			filtering = true
			break
		end
	end
	local pick = filter.pick
	if pick and not (S.PICKABLE[pick.mode] and pick.key ~= nil) then
		pick = nil
	end
	local t = {
		now = now, bands = bands, filtering = filtering,
		seen = seenWithin[filter.seen] and filter.seen or nil,
		within = seenWithin[filter.seen], pick = pick,
		class = {}, race = {}, band = {}, tag = {}, guild = {}, zone = {},
		ages = {}, ageBuckets = {},
		-- book: every character; total: those seen recently enough; matched:
		-- those of them the pick picks (all of them with no pick)
		book = 0, total = 0, matched = 0, mine = 0,
		unknownClass = 0, unknownLevel = 0, unknownRace = 0,
		unknownGuild = 0, unknownZone = 0,
		-- characters carrying at least one tag: the tag chart's rows count
		-- marks, and a character with three tags is one character
		tagged = 0,
		-- the Ledger's people, looked up once for the whole count
		people = BT.Notes and BT.Notes.People and BT.Notes.People() or nil,
	}
	for _, b in ipairs(S.AGE_BUCKETS) do
		t.ageBuckets[b.key] = 0
	end
	return t
end

-- ONE CHARACTER, NOTHING MADE (Josh 2026-09-24, /bt cpu: the census window's
-- redraw was a 48 ms frame in a city). Fourteen thousand characters each made
-- an empty table to walk their tags when they had none, and searched the
-- bands and the age buckets in order.
local AGE = S.AGE_BUCKETS
-- YOUR TAGS ARE THE LEDGER'S (Josh 2026-09-26): what you wrote on someone is
-- in its own book (Modules/Ledger/Store.lua), looked up by the key; a row an
-- older version wrote on, not moved yet, still carries its own
local function yours(t, key, p)
	local mine = key and t.people and t.people[key]
	if mine then
		return true, mine.tags
	end
	return DB.IsMine(p), p.tags
end

local function count(t, p, key)
	t.book = t.book + 1
	local age = t.now - (p.last or t.now)
	-- not seen lately: on no chart at all (never seen has no age, so it is
	-- as old as the book)
	if t.within and (p.last == nil or age >= t.within) then
		return
	end
	t.total = t.total + 1
	local pick = t.pick
	local isMine, tags = yours(t, key, p)
	local matched = pick == nil or picks(pick, p, tags)
	-- a chart counts a character the pick picks - or anybody, if the pick
	-- was made on that chart
	local pickMode = pick and pick.mode
	local myBand = S.BandOf(p.level)
	-- the level chart counts everybody the brackets would leave out
	if matched then
		t.matched = t.matched + 1
		if myBand then
			t.band[myBand] = (t.band[myBand] or 0) + 1
		else
			t.unknownLevel = t.unknownLevel + 1
		end
	end
	if not ((not t.filtering) or (myBand ~= nil and t.bands[myBand])) then
		matched, pickMode = false, nil
	end
	if isMine then
		t.mine = t.mine + 1
	end
	if matched or pickMode == "class" then
		local c = p.class
		if c then
			t.class[c] = (t.class[c] or 0) + 1
		else
			t.unknownClass = t.unknownClass + 1
		end
	end
	if matched or pickMode == "race" then
		local r = p.race
		if r then
			t.race[r] = (t.race[r] or 0) + 1
		else
			t.unknownRace = t.unknownRace + 1
		end
	end
	if matched or pickMode == "guild" then
		local g = guildKey(p)
		if g == S.UNKNOWN then
			t.unknownGuild = t.unknownGuild + 1
		else
			t.guild[g] = (t.guild[g] or 0) + 1
		end
	end
	if matched or pickMode == "zone" then
		local z = p.zone
		if z then
			t.zone[z] = (t.zone[z] or 0) + 1
		else
			t.unknownZone = t.unknownZone + 1
		end
	end
	if matched or pickMode == "tag" then
		if tags and next(tags) then
			t.tagged = t.tagged + 1
			for key in pairs(tags) do
				t.tag[key] = (t.tag[key] or 0) + 1
			end
		end
	end
	if pick and not picks(pick, p, tags) then
		return
	end
	t.ages[#t.ages + 1] = age
	for i = 1, #AGE do
		local b = AGE[i]
		if age < b.within then
			t.ageBuckets[b.key] = t.ageBuckets[b.key] + 1
			break
		end
	end
end

-- the largest `top` rows, and everything after them as one OTHER row; the
-- rows kept last (Unguilded) go after that, whatever their size
local function topRows(counts, top, last)
	local rows = sorted(counts)
	local kept, tail = {}, {}
	local other = 0
	for _, r in ipairs(rows) do
		if last and last[r.key] then
			tail[#tail + 1] = r
		elseif #kept < top then
			kept[#kept + 1] = r
		else
			other = other + r.n
		end
	end
	if other > 0 then
		kept[#kept + 1] = { key = S.OTHER, n = other }
	end
	for _, r in ipairs(tail) do
		kept[#kept + 1] = r
	end
	return kept
end

local function finish(t)
	local ages, sum = t.ages, 0
	for _, a in ipairs(ages) do
		sum = sum + a
	end
	-- bands sort by level, not by size: a chart of 1-10 .. 51-60 out of order
	-- is unreadable however tall the bars are
	local bands = {}
	for _, b in ipairs(S.BANDS) do
		bands[#bands + 1] = { key = b.key, n = t.band[b.key] or 0 }
	end
	local buckets = {}
	for _, b in ipairs(S.AGE_BUCKETS) do
		buckets[#buckets + 1] = { key = b.key, n = t.ageBuckets[b.key] }
	end
	local classRows = sorted(t.class)
	-- last row, whatever its size: it is not a class, it is the gap in the book
	if t.unknownClass > 0 then
		classRows[#classRows + 1] = { key = S.UNKNOWN, n = t.unknownClass }
	end
	return {
		book = t.book,
		total = t.total,
		matched = t.matched,
		mine = t.mine,
		filtered = t.filtering,
		seen = t.seen,
		pick = t.pick,
		class = classRows,
		race = sorted(t.race),
		level = bands,
		tag = sorted(t.tag),
		guild = topRows(t.guild, S.TOP, { [S.UNGUILDED] = true }),
		zone = topRows(t.zone, S.TOP + 1),
		tagged = t.tagged,
		unknown = {
			class = t.unknownClass, level = t.unknownLevel, race = t.unknownRace, tag = 0,
			guild = t.unknownGuild, zone = t.unknownZone,
		},
		age = {
			mean = #ages > 0 and (sum / #ages) or nil,
			median = median(ages),
			buckets = buckets,
		},
	}
end

-- a packed character is read into one borrowed table, only the six fields a
-- count wants (Core/Pack.lua, P.CensusReader); a table row is read as it is
local function reader(db)
	local read = BT.Pack and BT.Pack.CensusReader and BT.Pack.CensusReader(db)
	local lean = {}
	return function(key, row)
		if type(row) == "string" then
			return read and read(row, lean) or DB.View(db, key, row)
		end
		return row
	end
end

function S.Census(db, now, filter)
	local t = begin(now or U.Now(), filter)
	local view = reader(db)
	for key, row in pairs(DB.Players(db)) do
		count(t, view(key, row), key)
	end
	return finish(t)
end

-- The same census, a slice a call: each call of the step it returns counts
-- the next slice, and the last hands back the charts (nil until then, with
-- how far it has got, 0 to 1). A slice is `per` characters - or, given a
-- budget in milliseconds and a clock to hold it to, as many as fit in it:
-- the game's Lua ran a 2,000-character slice at 49 ms (Josh 2026-09-29).
-- The book's size comes back with the step, so a caller can tell whether a
-- slice at a time is worth it.
-- The book is listed first, so characters seen while it runs wait for the
-- next one rather than upsetting the walk.
S.JOB_SLICE = 2000
function S.CensusJob(db, now, filter, per)
	-- the row as it was when listed, and its key: a packed row is read with
	-- its key (which is its name) and the book's words
	local list, keys = {}, {}
	for key, p in pairs(DB.Players(db)) do
		list[#list + 1] = p
		keys[#list] = key
	end
	local t = begin(now or U.Now(), filter)
	local view = reader(db)
	local at = 0
	per = per or S.JOB_SLICE
	return function(budget)
		local clock = budget and type(debugprofilestop) == "function" and debugprofilestop or nil
		local started = clock and clock()
		local stop = clock and #list or math.min(#list, at + per)
		local i = at
		while i < stop do
			i = i + 1
			count(t, view(keys[i], list[i]), keys[i])
			-- the clock is asked every hundred: asking it is not free either
			if clock and i % 100 == 0 and clock() - started >= budget then
				break
			end
		end
		at = i
		if at >= #list then
			return finish(t)
		end
		return nil, (#list > 0 and at / #list or 1)
	end, #list
end

-- What a chart is a chart OF. The unidentified are mentioned only when there
-- ARE any: "0 of them unidentified" is a caveat about nothing (Josh 2026-09-18).
--
-- OUT OF WHOM (Josh 2026-09-24): with a bar picked, a chart counts the
-- characters it picked, so "of" is out of them and not out of the realm - and
-- the chart it was picked on is still out of everybody.
local NOUN = { race = "race", guild = "guild on file", zone = "zone on file" }
local SEEN_AS = { today = "seen today", week = "seen this week", month = "seen this month" }

local function subtitle(mode, census, counted)
	local unknown = (census.unknown and census.unknown[mode]) or 0
	local pick = census.pick
	local of = (pick and pick.mode ~= mode and census.matched) or census.total
	if mode == "tag" then
		-- characters, not marks: "6 of 3 tagged" was three people with two
		-- tags each
		return ("%d of %d tagged"):format(census.tagged or counted, of)
	end
	if mode == "level" then
		local noLevel = (census.unknown and census.unknown.level) or 0
		return noLevel > 0
			and ("%d of %d · %d no level"):format(counted, of, noLevel)
			or ("All %d"):format(counted)
	end
	-- with brackets switched off, say what is being left out rather than
	-- letting the chart read like the whole book
	if census.filtered then
		local noLevel = (census.unknown and census.unknown.level) or 0
		local tail = unknown > 0 and (" · %d unknown"):format(unknown) or ""
		return ("%d of %d in these levels%s%s"):format(counted, of, tail,
			noLevel > 0 and (" · %d no level"):format(noLevel) or "")
	end
	if unknown > 0 then
		if mode == "class" then
			return ("All %d · %d unknown"):format(counted, unknown)
		end
		return ("%d of %d · %d no %s"):format(counted, of, unknown, NOUN[mode] or mode)
	end
	return ("All %d"):format(counted)
end

function S.Subtitle(mode, census, counted)
	local line = subtitle(mode, census, counted)
	local seen = SEEN_AS[census.seen]
	return seen and (line .. " · " .. seen) or line
end

-- "median 2 days, average 5 days" - how much of this book you should believe.
-- NOBODY TO COUNT (Josh 2026-09-28, "fix it"): an empty book, the Seen filter
-- and a picked bar all leave no ages, and only the first is an empty book, so
-- the line says which one it is.
function S.AgeLine(census)
	local a = census.age
	if not a.median then
		if (census.book or 0) == 0 then
			return "Nobody in the book yet. Characters you see go in it."
		elseif (census.total or 0) == 0 and SEEN_AS[census.seen] then
			return ("Nobody in the book was %s."):format(SEEN_AS[census.seen])
		end
		return "Nobody in the book matches the bar you picked."
	end
	return ("Median %s old · average %s"):format(
		U.Ago(0, a.median), U.Ago(0, math.floor(a.mean or a.median)))
end
