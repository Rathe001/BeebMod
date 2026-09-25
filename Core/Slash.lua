-- /bt, and the commands the toolkit itself owns (Josh 2026-09-19).
--
-- Modules register their own with BT.Command, so this file never grows a
-- branch for a utility it has not heard of, and a command belonging to
-- something you have switched off says so instead of half-working.
--
-- Every command that names a character also works on your target when you
-- leave the name out, which is how you actually use this: you just met
-- someone.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Slash.lua")

local U, DB = BT.Util, BT.DB

function BT.TargetKey()
	if UnitExists("target") and UnitIsPlayer("target") then
		local name, realm = BT.Collect.UnitFullName("target")
		BT.Collect.FromUnit("target") -- make sure there is a row to write on
		return U.Key(name, realm), name
	end
	return nil
end

-- Pulls a character off the front of a command (Josh 2026-09-18). Names have
-- two parts here, so "note Beeb Bob solid tank" has to read as Beeb Bob and
-- "solid tank", not as Beeb and "Bob solid tank". We try the longest thing
-- that is actually a character we know, then fall back to your target - which
-- is how you use this anyway, right after meeting someone.
--   /bt note "Beeb Bob" text     quotes win outright
--   /bt note Beeb Bob text       two words, when Beeb Bob is on file
--   /bt note Beeb text           one word, when Beeb is on file
--   /bt note text                your target
function BT.WhoAndRest(rest)
	local quoted, qtail = rest:match('^"([^"]+)"%s*(.*)$')
	if quoted then
		local key, full = U.Key(quoted)
		if key then
			return key, qtail, full
		end
	end
	local w1, w2, tail2 = rest:match("^(%S+)%s+(%S+)%s*(.*)$")
	if w1 and w2 then
		local key, full = U.Key(w1 .. " " .. w2)
		if key and DB.Get(BT.db, key) then
			return key, tail2, full
		end
	end
	local w, tail = rest:match("^(%S+)%s*(.*)$")
	if w then
		local key, full = U.Key(w)
		if key and DB.Get(BT.db, key) then
			return key, tail, full
		end
	end
	local key, tname = BT.TargetKey()
	if key then
		return key, rest, tname
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The toolkit's own commands: the book, the bar, and what is switched on.
-- ---------------------------------------------------------------------------

BT.Command("stats", function()
	local s = DB.Stats(BT.db)
	U.Print(("%s %s · %d characters · %d noted · %d guilded · %d sightings")
		:format(BT.scope.realm, BT.scope.faction, s.total, s.mine, s.guilded, BT.db.stats.sightings or 0))
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
		U.Print("other books: " .. table.concat(bits, ", "))
	end
end, "this book")

-- No longer a switch: the book is filled because the Ledger or the Census
-- wants it, so this says which (Josh 2026-09-20).
BT.Command("collect", function()
	local who = {}
	if BT.Enabled("ledger") then
		who[#who + 1] = "ledger"
	end
	if BT.Enabled("census") then
		who[#who + 1] = "census"
	end
	U.Print(#who > 0
		and ("collecting for " .. table.concat(who, " and "))
		or "not collecting - the ledger and the census are both off")
end, "who the book is being filled for")

BT.Command("bar", function()
	U.Print("target row " .. (BT.Bar.Toggle() and "on" or "off"))
end, "show or hide the target row at the top of the dock")

BT.Command("prune", function(rest)
	local days = tonumber(rest)
	-- AT LEAST A DAY (Josh 2026-09-23, audit): "0" meant "older than now",
	-- which is every unwritten sighting in the book
	if not days or days < 1 then
		U.Print("usage: /bt prune <days> · one day or more")
		return
	end
	days = math.floor(days)
	U.Print(("dropped %d unwritten sighting(s) over %d days old"):format(DB.Prune(BT.db, days), days))
end, "prune <days> - drop old unwritten sightings")

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
		and ("auto-purge after %d day%s · unwritten sightings only"):format(d, d == 1 and "" or "s")
		or "auto-purge off")
end, "autopurge <days|off> - at each loading screen, drop unwritten sightings older than this")

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
		and ("keeps up to %d characters · past that, those seen longest ago go at login · yours stay"):format(c)
		or "no size limit")
end, "cap <characters|off> - the most characters the book keeps")

BT.Command("cleanup", function()
	local gone = DB.Cleanup(BT.db)
	U.Print(("removed %d blank character%s; notes untouched")
		:format(gone, gone == 1 and "" or "s"))
	BT.Window.Refresh()
end, "drop blank names")

BT.Command("identify", function()
	local done, looked, noGuid, renamed = BT.Collect.Backfill(2000)
	U.Print(("looked up %d · identified %d · renamed %d")
		:format(looked or 0, done or 0, renamed or 0))
	if (noGuid or 0) > 0 then
		U.Print(("%d have no GUID - only seeing them will fix that"):format(noGuid))
	end
	BT.Window.Refresh()
end, "identify unknown names")

-- WHERE DID THE BOOK GO (Josh 2026-09-19). These three are about the FILE
-- rather than about characters, and exist because a morning came where the
-- answer to "all my data is gone" was not knowable from inside the game.
BT.Command("boot", function()
	local b = BT.boot
	if not b then
		U.Print("no boot report")
		return
	end
	if b.type ~= "table" then
		U.Print("no saved variables this login (" .. tostring(b.type) .. ")")
		U.Print("nothing loaded, nothing lost - the file is still on disk")
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
		U.Print("live file: |cffff6b6bnot loaded|r - is the Data/Live link there?")
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
end, "what loaded at login")

BT.Command("books", function()
	for _, b in ipairs(BT.Books()) do
		U.Print(("%s%s  %d"):format(b.mine and "* " or "   ", (b.key:gsub("|", " ")), b.n))
	end
	U.Print("* is this character's book · /bt adopt <book> moves another across")
end, "every book in the file")

BT.Command("adopt", function(rest)
	local done = BT.AdoptBook(rest)
	if not done then
		U.Print("no such book · /bt books lists them")
		return
	end
	U.Print(("adopted %s · %d brought over · %d merged")
		:format((done.key:gsub("|", " ")), done.added, done.folded))
	BT.Window.Refresh()
end, "adopt <book> - merge another book into this one")

BT.Command("debug", function()
	U.Print(("%s %s (%s)"):format(BT.TITLE, tostring(BT.VERSION), tostring(BT.BUILD)))
	U.Print(("book: %s | settings: %s | characters: %d"):format(
		BT.scope and BT.scope.key or "|cffff6b6bNONE|r",
		BT.settings and "yes" or "|cffff6b6bnil|r",
		DB.Stats(BT.db).total))
	local on = {}
	for _, m in ipairs(BT.Modules()) do
		on[#on + 1] = ("%s %s"):format(m.key, BT.Enabled(m.key) and "on" or "off")
	end
	U.Print("modules: " .. table.concat(on, ", "))
	local refused = {}
	for event, why in pairs(BT.Collect.refused or {}) do
		refused[#refused + 1] = ("%s (%s)"):format(event, tostring(why):sub(1, 40))
	end
	U.Print("refused events: " .. (#refused > 0 and table.concat(refused, ", ") or "none"))
	for _, line in ipairs(BT.blockedLog or {}) do
		U.Print("|cffff6b6bblocked|r " .. line)
	end
	for _, err in ipairs(BT.moduleErrors or {}) do
		U.Print("|cffff6b6bmodule error|r " .. err)
	end
	-- the over-time bars' flash is the client's to allow (Frames/Timers.lua)
	local timers = BT.UnitFrames and BT.UnitFrames.Timers
	local refused = timers and timers.seen and timers.seen.textRefused
	if refused then
		U.Print("|cffff6b6bflash refused|r " .. refused:sub(1, 120))
	end
end, "what loaded, what the client refused")

BT.Command("help", function()
	U.Print(("%s · /bt opens the window"):format(BT.TITLE))
	local names = {}
	for name in pairs(BT.Commands()) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local c = BT.Commands()[name]
		if c.help and (not c.module or BT.Enabled(c.module)) then
			-- a help line that already starts with its own command is printed
			-- as written, so "/bt find <text> - search ..." does not come out
			-- as "/bt find - find <text> - search ..." (Josh 2026-09-19)
			local line = c.help:sub(1, #name) == name
				and ("/bt " .. c.help)
				or ("/bt %s - %s"):format(name, c.help)
			if c.module then
				line = line .. " |cff6e7b75(" .. c.module .. ")|r"
			end
			U.Print(line)
		end
	end
end, "this list")

SLASH_BEEBSTOOLKIT1, SLASH_BEEBSTOOLKIT2 = "/bt", "/beeb"
SlashCmdList.BEEBSTOOLKIT = function(msg)
	-- every command needs a book; bind one now if login never did
	BT.EnsureBound()
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		BT.Window.Toggle()
		return
	end
	if BT.RunCommand(cmd, rest) then
		return
	end
	-- a module's key opens its tab: /bt census, /bt ledger
	-- its own tab, switched on or not: that is where the switch is now
	if BT.GetModule(cmd) then
		BT.Window.Show(cmd)
		return
	end
	-- anything else is a search, because that is what you meant
	if BT.Enabled("ledger") then
		BT.RunCommand("find", msg)
	else
		BT.RunCommand("help", "")
	end
end
