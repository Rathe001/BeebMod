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
		local name, realm = BT.Util.UnitFullName("target")
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
-- The toolkit's own commands: the target row, and what is switched on. The
-- book's are the census's (Modules/Census/Book.lua).
-- ---------------------------------------------------------------------------

BT.Command("bar", function()
	U.Print("target row " .. (BT.Bar.Toggle() and "on" or "off"))
end, "show or hide the target row at the top of the dock")

BT.Command("debug", function()
	U.Print(("%s %s (%s)"):format(BT.TITLE, tostring(BT.VERSION), tostring(BT.BUILD)))
	U.Print(("book: %s | settings: %s | characters: %s"):format(
		BT.scope and BT.scope.key or "|cffff6b6bNONE|r",
		BT.settings and "yes" or "|cffff6b6bnil|r",
		(BT.DB and BT.db) and tostring(BT.DB.Stats(BT.db).total) or "-"))
	local on = {}
	for _, m in ipairs(BT.Modules()) do
		on[#on + 1] = ("%s %s"):format(m.key, BT.Enabled(m.key) and "on" or "off")
	end
	U.Print("modules: " .. table.concat(on, ", "))
	local refused = {}
	for _, from in ipairs({ BT.Boot and BT.Boot.refused, BT.Collect and BT.Collect.refused }) do
		for event, why in pairs(from or {}) do
			refused[#refused + 1] = ("%s (%s)"):format(event, tostring(why):sub(1, 40))
		end
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
