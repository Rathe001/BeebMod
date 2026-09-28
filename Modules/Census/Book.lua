-- The book's commands (Josh 2026-09-26: moved out of Core/Slash.lua, the
-- core's own, when the census became a thing of its own). How many, how old,
-- how big, and what the saved file handed back at login.
local _, BT = ...

local U, DB = BT.Util, BT.DB

BT.Command("stats", function()
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
end, "count what is in this book")

-- No longer a switch: the book is filled because the Census wants it
-- (Josh 2026-09-20; the Census alone since 2026-09-26).
BT.Command("collect", function()
	U.Print(BT.Enabled("census") and "Census: on, so BeebMod writes down who you see."
		or "Census: off, so BeebMod writes nobody down.")
end, "say whether BeebMod is writing down who you see")

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

BT.Command("cleanup", function()
	local gone = DB.Cleanup(BT.db)
	U.Print(("Census: removed %d blank character%s. Notes are untouched.")
		:format(gone, gone == 1 and "" or "s"))
	BT.Window.Refresh()
end, "remove blank names")

BT.Command("identify", function()
	local done, looked, noGuid, renamed = BT.Collect.Backfill(2000)
	U.Print(("Census: looked up %d · identified %d · renamed %d")
		:format(looked or 0, done or 0, renamed or 0))
	if (noGuid or 0) > 0 then
		U.Print(("Census: %d have nothing to look up. See them again to identify them."):format(noGuid))
	end
	BT.Window.Refresh()
end, "identify unknown names")

-- WHERE DID THE BOOK GO (Josh 2026-09-19). These three are about the FILE
-- rather than about characters, and exist because a morning came where the
-- answer to "all my data is gone" was not knowable from inside the game.
BT.Command("boot", function()
	local b = BT.boot
	if not b then
		U.Print("No boot report.")
		return
	end
	if b.type ~= "table" then
		U.Print("no saved variables this login (" .. tostring(b.type) .. ")")
		U.Print("Nothing loaded, and nothing lost. The file is still on disk.")
	else
		U.Print(("file arrived · schema %s · settings %s · %d characters in %d book(s)")
			:format(tostring(b.schema), b.settings and "yes" or "no", b.total, #b.books))
		for _, bk in ipairs(b.books) do
			U.Print(("   %s  %d"):format((bk.key:gsub("|", " ")), bk.n))
		end
	end
	-- THE SECOND VARIABLE (Josh 2026-09-20). Small enough that a client
	-- choking on the size of the first should still manage it. If this one
	-- comes back and the book does not, the cause is size.
	-- the three channels, and which of them the client honoured
	for _, pair in ipairs({
		{ "account-wide", _G.BeebModKeep },
		{ "per-character", _G.BeebModChar },
	}) do
		local store = pair[2]
		if type(store) == "table" then
			local rows = 0
			for _, book in pairs(store.realms or {}) do
				for _ in pairs(book.players or {}) do
					rows = rows + 1
				end
			end
			U.Print(("%s notes: |cff74c0fcarrived|r · %d rows"):format(pair[1], rows))
		else
			U.Print(("%s notes: |cffff6b6bnothing arrived|r (%s)"):format(pair[1], type(store)))
		end
	end
	local stash = type(_G.BeebModChar) == "table" and _G.BeebModChar.book
	if stash then
		local n = 0
		for _ in pairs((stash.db and stash.db.players) or {}) do
			n = n + 1
		end
		U.Print(("stashed book: %s · %d characters%s"):format(tostring(stash.key), n,
			BT.stashTaken and (" · %d put back"):format(BT.stashTaken) or ""))
	else
		U.Print("stashed book: |cffff6b6bnothing arrived|r")
	end
	if BT.keptTaken then
		U.Print(("%d put back into the book"):format(BT.keptTaken))
	end
	-- the client's own save, run as addon code through the Data\Live link
	if BT.linked then
		local n = 0
		for _, book in pairs(BT.linked.realms or {}) do
			for _ in pairs(book.players or {}) do
				n = n + 1
			end
		end
		U.Print(("live file: |cff74c0fcloaded|r · %d characters%s"):format(n,
			BT.linkedRestored and " · put back after the client cleared it" or ""))
	else
		U.Print("live file: |cffff6b6bnot loaded|r. Check that the Data/Live link is there.")
	end
	U.Print(("baked file: %s%s")
		:format(type(BT.baked) == "table" and "loaded" or "missing",
			BT.bakedTaken and (" · %d taken from it"):format(BT.bakedTaken) or ""))
	U.Print(("bound: %s · %d at login")
		:format(tostring(b.bound and b.bound:gsub("|", " ")), b.boundCount or 0))
	-- the things that used to be announced at login
	if BT.slimmedOnLoad then
		U.Print(("%d rows slimmed of fields they did not need"):format(BT.slimmedOnLoad))
	end
	if BT.foldedOnLoad then
		U.Print(("%d folded in from the realm's old name"):format(BT.foldedOnLoad))
	end
	if BT.lateBook then
		U.Print(("the book turned up late · %d found · %d seen since login kept")
			:format(BT.lateBook.found, BT.lateBook.kept))
	end
end, "show what loaded at login")

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

