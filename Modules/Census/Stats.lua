-- What the book adds up to (Josh 2026-09-18). Pure Lua, so the headless tests
-- can check the arithmetic.
--
-- No SPEC here, and there cannot be: this game has no API that tells you a
-- stranger's talents, and inspecting needs them targeted and in range. Your
-- own flags stand in - they are the roles you actually care about.
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
-- the class, race and flag charts - who you are looking at - but never the
-- LEVEL chart, which is a chart OF the bands and would be nonsense filtered by
-- itself; there the selection is a highlight (Josh 2026-09-19). A character
-- with no level on file cannot be in a band, so a filter excludes them and the
-- footer says how many.
--
-- IN THREE STEPS (Josh 2026-09-24): a tally is begun, every character is
-- counted into it, and it is finished into the charts. S.Census does all of
-- it at once; S.CensusJob does the counting a slice at a time, so the window
-- open in a city never spends one frame on fourteen thousand characters.

local function begin(now, bands)
	local filtering = false
	if bands then
		for _ in pairs(bands) do
			filtering = true
			break
		end
	end
	local t = {
		now = now, bands = bands, filtering = filtering,
		class = {}, race = {}, band = {}, flag = {}, ages = {}, ageBuckets = {},
		total = 0, mine = 0, unknownClass = 0, unknownLevel = 0, unknownRace = 0,
		-- characters carrying at least one tag: the flag chart's rows count
		-- marks, and a character with three tags is one character
		tagged = 0,
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
local function count(t, p)
	t.total = t.total + 1
	local myBand = S.BandOf(p.level)
	-- the level chart counts everybody, whatever the filter says
	if myBand then
		t.band[myBand] = (t.band[myBand] or 0) + 1
	else
		t.unknownLevel = t.unknownLevel + 1
	end
	local counted = (not t.filtering) or (myBand ~= nil and t.bands[myBand])
	if DB.IsMine(p) then
		t.mine = t.mine + 1
	end
	if counted then
		local c, r, flags = p.class, p.race, p.flags
		if c then
			t.class[c] = (t.class[c] or 0) + 1
		else
			t.unknownClass = t.unknownClass + 1
		end
		if r then
			t.race[r] = (t.race[r] or 0) + 1
		else
			t.unknownRace = t.unknownRace + 1
		end
		if flags and next(flags) then
			t.tagged = t.tagged + 1
			for key in pairs(flags) do
				t.flag[key] = (t.flag[key] or 0) + 1
			end
		end
	end
	local age = t.now - (p.last or t.now)
	t.ages[t.total] = age
	for i = 1, #AGE do
		local b = AGE[i]
		if age < b.within then
			t.ageBuckets[b.key] = t.ageBuckets[b.key] + 1
			break
		end
	end
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
		total = t.total,
		mine = t.mine,
		filtered = t.filtering,
		class = classRows,
		race = sorted(t.race),
		level = bands,
		flag = sorted(t.flag),
		tagged = t.tagged,
		unknown = { class = t.unknownClass, level = t.unknownLevel, race = t.unknownRace, flag = 0 },
		age = {
			mean = #ages > 0 and (sum / #ages) or nil,
			median = median(ages),
			buckets = buckets,
		},
	}
end

function S.Census(db, now, bands)
	local t = begin(now or U.Now(), bands)
	for _, p in pairs(DB.Players(db)) do
		count(t, p)
	end
	return finish(t)
end

-- The same census, `per` characters a call: each call of the step it returns
-- counts the next slice, and the last hands back the charts (nil until then).
-- The book is listed first, so characters seen while it runs wait for the
-- next one rather than upsetting the walk.
S.JOB_SLICE = 2000
function S.CensusJob(db, now, bands, per)
	local list = {}
	for _, p in pairs(DB.Players(db)) do
		list[#list + 1] = p
	end
	local t = begin(now or U.Now(), bands)
	local at = 0
	per = per or S.JOB_SLICE
	return function()
		local stop = math.min(#list, at + per)
		for i = at + 1, stop do
			count(t, list[i])
		end
		at = stop
		if at >= #list then
			return finish(t)
		end
		return nil
	end
end

-- What a chart is a chart OF. The unidentified are mentioned only when there
-- ARE any: "0 of them unidentified" is a caveat about nothing (Josh 2026-09-18).
function S.Subtitle(mode, census, counted)
	local unknown = (census.unknown and census.unknown[mode]) or 0
	if mode == "flag" then
		-- characters, not marks: "6 of 3 tagged" was three people with two
		-- tags each
		return ("%d of %d tagged"):format(census.tagged or counted, census.total)
	end
	if mode == "level" then
		local noLevel = (census.unknown and census.unknown.level) or 0
		return noLevel > 0
			and ("%d of %d · %d no level"):format(counted, census.total, noLevel)
			or ("all %d"):format(counted)
	end
	-- with brackets switched off, say what is being left out rather than
	-- letting the chart read like the whole book
	if census.filtered then
		local noLevel = (census.unknown and census.unknown.level) or 0
		local tail = unknown > 0 and (" · %d unknown"):format(unknown) or ""
		return ("%d of %d in these levels%s%s"):format(counted, census.total, tail,
			noLevel > 0 and (" · %d no level"):format(noLevel) or "")
	end
	if unknown > 0 then
		if mode == "class" then
			return ("all %d · %d unknown"):format(counted, unknown)
		end
		return ("%d of %d · %d no %s"):format(counted, census.total, unknown, mode)
	end
	return ("all %d"):format(counted)
end

-- "median 2 days, average 5 days" - how much of this book you should believe.
function S.AgeLine(census)
	local a = census.age
	if not a.median then
		return "nothing yet"
	end
	return ("median %s old · average %s"):format(
		U.Ago(0, a.median), U.Ago(0, math.floor(a.mean or a.median)))
end
