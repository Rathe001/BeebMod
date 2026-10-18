-- The book's report on the Testing page (BT.StatsReport): how many
-- characters it holds, how it is kept, and the other books in the file.
--
-- NO COMMANDS (Josh 2026-10-18: "I actually never use the slash commands.
-- I'd be fine with removing these (and the others) unless we are using them
-- internally or for debug."). /bt prune, /bt autopurge, /bt cap, /bt books
-- and /bt adopt lived here, and nothing but a player typing ran them. The
-- purge at each loading screen and the size limit at login still run, with
-- the days and the limit in BT.SETTINGS (Core/Init.lua). Another book is
-- moved in from its row on the Testing page (BT.AdoptBook).
local _, BT = ...

local U, DB = BT.Util, BT.DB

-- THE BOOK, ON THE TESTING PAGE (Josh 2026-09-28: "I'd actually prefer to
-- use the 'Testing' module with buttons/toggles going forward"): what /bt
-- stats printed, from the page's Show button.
function BT.StatsReport()
	BT.EnsureBound()
	local s = DB.Stats(BT.db)
	-- noted: the Ledger's to count (its own book), when there is a Ledger
	local noted = BT.Notes and BT.Notes.CountNoted() or s.mine
	U.Print(("Ledger: %s · %s characters · %s noted · %s in a guild · %s sightings")
		:format(BT.scope.realm, U.Commas(s.total), U.Commas(noted), U.Commas(s.guilded), U.Commas(BT.db.stats.sightings or 0)))
	-- how the book is kept (Core/Pack.lua): packed, and how big it may grow
	local n, packed = DB.Count(BT.db)
	local cap = BT.settings.bookCap or 0
	U.Print(("%s of %s packed · %s"):format(U.Commas(packed), U.Commas(n),
		cap > 0 and ("keeps up to %s"):format(U.Commas(cap)) or "no size limit"))
	local r = BT.lastRun
	if r and ((r.identified or 0) > 0 or (r.cleaned or 0) > 0 or (r.pruned or 0) > 0 or (r.capped or 0) > 0) then
		U.Print(("last login · identified %s · cleaned %s · purged %s · over the limit %s")
			:format(U.Commas(r.identified), U.Commas(r.cleaned), U.Commas(r.pruned), U.Commas(r.capped)))
	end
	local others = BT.OtherBooks()
	if #others > 0 then
		local bits = {}
		for _, b in ipairs(others) do
			bits[#bits + 1] = ("%s %s"):format(b.name, U.Commas(b.n))
		end
		U.Print("Other books: " .. table.concat(bits, ", "))
	end
end
