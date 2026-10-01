-- /bt, and the commands the toolkit itself owns (Josh 2026-09-19): help, and
-- What loaded for the Testing page.
--
-- Modules register their own with BT.Command, so this file never grows a
-- branch for a utility it has not heard of, and a command belonging to
-- something you have switched off says so instead of half-working.
--
-- A command that names a character is the Ledger's, and reads the name the
-- Ledger's way (BT.Notes.WhoAndRest): your target when you leave it out.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Slash.lua")

local U = BT.Util

-- ---------------------------------------------------------------------------
-- WHAT LOADED (Josh 2026-09-28: "I'd actually prefer to use the 'Testing'
-- module with buttons/toggles going forward"). What /bt debug and /bt boot
-- printed, as one report from the Testing page's Show button: the build,
-- what the saved file handed back, each module, and what the game refused.
-- ---------------------------------------------------------------------------

-- what the saved file handed back at login (BT.BootReport), and what was done
-- to it while the book was bound
local function bootLines(say)
	local b = BT.boot
	if not b then
		return
	end
	if b.type ~= "table" then
		say(("saved file: nothing arrived (%s). Nothing is lost. The file is still on disk."):format(tostring(b.type)))
	else
		say(("saved file: schema %s · settings %s · %d characters in %d book%s"):format(tostring(b.schema),
			b.settings and "yes" or "no", b.total, #b.books, #b.books == 1 and "" or "s"))
	end
	if b.bound then
		say(("bound: %s · %d at login"):format((b.bound:gsub("|", " ")), b.boundCount or 0))
	end
	if BT.linkedRestored then
		say("BeebMod put back the book the client cleared")
	end
	if BT.stashTaken then
		say(("%d put back from the stashed book"):format(BT.stashTaken))
	end
	if BT.bakedTaken then
		say(("%d taken from the baked file"):format(BT.bakedTaken))
	end
	if BT.slimmedOnLoad then
		say(("%d rows slimmed of fields they did not need"):format(BT.slimmedOnLoad))
	end
	if BT.foldedOnLoad then
		say(("%d folded in from the realm's old name"):format(BT.foldedOnLoad))
	end
	if BT.renamedOnLoad then
		say(("%d settings moved to their new names"):format(BT.renamedOnLoad))
	end
	if BT.lateBook then
		say(("the book turned up late · %d found · %d seen since login kept"):format(BT.lateBook.found,
			BT.lateBook.kept))
	end
end

function BT.WhatLoaded()
	BT.EnsureBound()
	U.Print(("%s %s (%s)"):format(BT.TITLE, tostring(BT.VERSION), tostring(BT.BUILD)))
	U.Print(("book: %s · settings: %s · characters: %s"):format(
		BT.scope and BT.scope.key or "|cffff6b6bnone|r",
		BT.settings and "yes" or "|cffff6b6bnone|r",
		(BT.DB and BT.db) and tostring(BT.DB.Stats(BT.db).total) or "-"))
	bootLines(U.Print)
	local on = {}
	for _, m in ipairs(BT.Modules()) do
		on[#on + 1] = ("%s %s"):format(m.key, BT.Enabled(m.key) and "on" or "off")
	end
	U.Print("modules: " .. table.concat(on, ", "))
	-- which tooltip hooks fire (Core/Tooltip.lua)
	local T = BT.UnitTip
	if T then
		U.Print(("tooltip hooks: unit %s (%d filled) · item %s (%d filled)"):format(tostring(T.path),
			T.fills or 0, tostring(T.itemPath), T.itemFills or 0))
	end
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
	-- a step of the login that threw (Core/Boot.lua kept these, and nothing
	-- printed them until 2026-09-28)
	for _, err in ipairs(BT.Boot and BT.Boot.failed or {}) do
		U.Print("|cffff6b6blogin step failed|r " .. err)
	end
	-- the over-time bars' flash is the client's to allow (UnitFrames/Timers.lua)
	local F = BT.UnitFrames
	local timers = F and F.Timers
	local flash = timers and timers.seen and timers.seen.textRefused
	if flash then
		U.Print("|cffff6b6bflash refused|r " .. flash:sub(1, 120))
	end
	-- and a secret raid mark, which only the client may draw (UnitFrames/Unit.lua)
	if F and F.markerWith == false then
		U.Print("|cffff6b6bmarks refused|r the game accepts none of the ways BeebMod draws a secret raid mark")
	end
end

BT.Command("help", function()
	U.Print(("%s commands. Type /bt on its own to open the window."):format(BT.TITLE))
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
			-- the module by the name its tab shows, not its key
			if c.module then
				local m = BT.GetModule(c.module)
				line = line .. " |cff6e7b75(" .. tostring(m and m.title or c.module) .. ")|r"
			end
			U.Print(line)
		end
	end
end, "list these commands")

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
