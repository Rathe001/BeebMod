-- The book's commands (Josh 2026-09-26: moved out of Core/Slash.lua, the
-- core's own, when the census became a thing of its own): how long it keeps
-- characters, how many it keeps, and the other books in the file. How many
-- are in it is a report on the Testing page (BT.StatsReport).
local _, BT = ...

local U, DB = BT.Util, BT.DB

-- THE BOOK, ON THE TESTING PAGE (Josh 2026-09-28: "I'd actually prefer to
-- use the 'Testing' module with buttons/toggles going forward"): what /bt
-- stats printed, from the page's Show button.
function BT.StatsReport()
	BT.EnsureBound()
	local s = DB.Stats(BT.db)
	-- noted: the Ledger's to count (its own book), when there is a Ledger
	local noted = BT.Notes and BT.Notes.Count() or s.mine
	U.Print(("Census: %s %s · %d characters · %d noted · %d in a guild · %d sightings")
		:format(BT.scope.realm, BT.scope.faction, s.total, noted, s.guilded, BT.db.stats.sightings or 0))
	-- how the book is kept (Core/Pack.lua): packed, and how big it may grow
	local n, packed = DB.Count(BT.db)
	local cap = BT.settings.bookCap or 0
	U.Print(("%d of %d packed · %s"):format(packed, n,
		cap > 0 and ("keeps up to %d"):format(cap) or "no size limit"))
	local r = BT.lastRun
	if r and ((r.identified or 0) > 0 or (r.cleaned or 0) > 0 or (r.pruned or 0) > 0 or (r.capped or 0) > 0) then
		U.Print(("last login · identified %d · cleaned %d · purged %d · over the limit %d")
			:format(r.identified or 0, r.cleaned or 0, r.pruned or 0, r.capped or 0))
	end
	local others = BT.OtherBooks()
	if #others > 0 then
		local bits = {}
		for _, b in ipairs(others) do
			bits[#bits + 1] = ("%s %d"):format(b.key, b.n)
		end
		U.Print("Other books: " .. table.concat(bits, ", "))
	end
end

BT.Command("prune", function(rest)
	local days = tonumber(rest)
	-- AT LEAST A DAY (Josh 2026-09-23, audit): "0" meant "older than now",
	-- which is every unwritten sighting in the book
	if not days or days < 1 then
		U.Print("Type /bt prune <days> to drop old sightings. Days must be 1 or more.")
		return
	end
	days = math.floor(days)
	local dropped = DB.Prune(BT.db, days)
	U.Print(("Census: dropped %d %s you haven't noted and haven't seen in %d %s."):format(dropped,
		dropped == 1 and "character" or "characters", days, days == 1 and "day" or "days"))
end, "prune <days> - drop characters you haven't noted and haven't seen in that many days")

BT.Command("autopurge", function(rest)
	-- 0 IS OFF, NOT ONE DAY (Josh 2026-09-23, audit): "0" was raised to 1,
	-- and the next loading screen dropped every unwritten sighting older than
	-- a day - most of the book
	local n = tonumber(rest)
	if rest == "off" or (n and n <= 0) then
		BT.settings.pruneDays = 0
	elseif n then
		BT.settings.pruneDays = math.max(1, math.floor(n))
	end
	local d = BT.settings.pruneDays or 0
	U.Print(d > 0
		and ("Census: auto-purge after %d day%s, for characters you haven't noted."):format(d, d == 1 and "" or "s")
		or "Census: auto-purge off.")
end, "autopurge <days|off> - at each loading screen, drop characters you haven't noted and haven't seen in that many days")

-- THE BOOK HAS A SIZE (Josh 2026-09-24): past it, the characters seen
-- longest ago go at the next login (DB.Cap). Never below a thousand: a limit
-- that small is a typo, and it would take most of the book with it.
BT.Command("cap", function(rest)
	local n = tonumber(rest)
	if rest == "off" or (n and n <= 0) then
		BT.settings.bookCap = 0
	elseif n then
		BT.settings.bookCap = math.max(1000, math.floor(n))
	end
	local c = BT.settings.bookCap or 0
	U.Print(c > 0
		and ("Census: the book keeps up to %d characters. Past that, at login, levels 1-10 go first, then those seen longest ago. Characters you've noted stay."):format(c)
		or "Census: no size limit.")
end, "cap <characters|off> - the most characters the book keeps")

BT.Command("books", function()
	for _, b in ipairs(BT.Books()) do
		U.Print(("%s%s  %d"):format(b.mine and "* " or "   ", (b.key:gsub("|", " ")), b.n))
	end
	U.Print("* is this character's book. Type /bt adopt <book> to move another one across.")
end, "list every book in the file")

BT.Command("adopt", function(rest)
	local done = BT.AdoptBook(rest)
	if not done then
		U.Print("No such book. Type /bt books to list them.")
		return
	end
	U.Print(("Census: adopted %s · %d brought over · %d merged")
		:format((done.key:gsub("|", " ")), done.added, done.folded))
	BT.Window.Refresh()
end, "adopt <book> - merge another book into this one")

