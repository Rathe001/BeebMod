-- /bt and /beeb, which open the window, and What loaded for the Testing page.
--
-- NO COMMANDS AFTER /bt (Josh 2026-10-18: "I actually never use the slash
-- commands. I'd be fine with removing these (and the others) unless we are
-- using them internally or for debug."). /bt help, the Ledger's note, tag,
-- rate and find, the census's prune, autopurge and cap, and the rest went
-- that day, with BT.Command, which registered them. The right-click menu on
-- a player writes notes, tags and ratings, the Find page searches and makes
-- tags, and the Testing page has the made-up data, the first login and the
-- other books. Nothing on screen changes the purge's days or the book's size
-- limit (BT.SETTINGS, Core/Init.lua). The welcome tells you to type /bt, so
-- /bt stays, and whatever you type after it is not read: /bt anything opens
-- the window as /bt does.
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
-- WITH COMMAS (2026-10-17, audit): "150000 characters" read as a code, not
-- a count (U.Commas, as everywhere else)
local C = U.Commas
local function bootLines(say)
	local b = BT.boot
	if not b then
		return
	end
	if b.type ~= "table" then
		say(("saved file: nothing arrived (%s). Nothing is lost. The file is still on disk."):format(tostring(b.type)))
	else
		say(("saved file: schema %s · settings %s · %s characters in %s book%s"):format(tostring(b.schema),
			b.settings and "yes" or "no", C(b.total), C(#b.books), #b.books == 1 and "" or "s"))
	end
	if b.bound then
		say(("bound: %s · %s at login"):format((b.bound:gsub("|", " ")), C(b.boundCount)))
	end
	if BT.slimmedOnLoad then
		say(("%s rows slimmed of fields they did not need"):format(C(BT.slimmedOnLoad)))
	end
	if BT.foldedOnLoad then
		say(("%s folded in from the realm's old name"):format(C(BT.foldedOnLoad)))
	end
	if BT.renamedOnLoad then
		say(("%s settings moved to their new names"):format(C(BT.renamedOnLoad)))
	end
	-- the launch reset (BT.DropBeta): what told it this is the beta, and what
	-- it dropped the day neither did
	local beta = BT.betaCheck
	if beta then
		local yes = function(v) return v and "yes" or "no" end
		say(("beta realm: %s · beta client: %s · beta records: %s"):format(
			beta.known and yes(beta.realm) or "not known yet", yes(beta.client),
			(beta.realm or beta.client or not beta.known) and "kept" or "dropped"))
	end
	local gone = BT.betaDropped
	if gone then
		say(("beta records dropped: %s characters seen in %s book%s · %s people in the Ledger · %s Expedition characters · %s enemies · %s other character records"):format(
			C(gone.characters), C(gone.books), gone.books == 1 and "" or "s", C(gone.people), C(gone.journals),
			C(gone.enemies), C(gone.records)))
	end
	if BT.lateBook then
		say(("saved data loaded late · %s found · %s seen since login kept"):format(C(BT.lateBook.found),
			C(BT.lateBook.kept)))
	end
end

function BT.WhatLoaded()
	BT.EnsureBound()
	U.Print(("%s %s (%s)"):format(BT.TITLE, tostring(BT.VERSION), tostring(BT.BUILD)))
	U.Print(("book: %s · settings: %s · characters: %s"):format(
		BT.scope and BT.scope.key or "|cffff6b6bnone|r",
		BT.settings and "yes" or "|cffff6b6bnone|r",
		(BT.DB and BT.db) and C(BT.DB.Stats(BT.db).total) or "-"))
	bootLines(U.Print)
	local on = {}
	for _, m in ipairs(BT.Modules()) do
		on[#on + 1] = ("%s %s"):format(m.key, BT.Enabled(m.key) and "on" or "off")
	end
	U.Print("modules: " .. table.concat(on, ", "))
	-- WHAT EACH IS DOING (the settings canvas, Josh 2026-10-04: the lines at
	-- the foot of the old pages, such as "52 buttons redrawn", moved here)
	for _, m in ipairs(BT.Modules()) do
		if m.Status and BT.Enabled(m.key) then
			local ok, said = pcall(m.Status)
			if ok and said then
				U.Print(("%s: %s"):format(m.short or m.title or m.key, tostring(said)))
			end
		end
	end
	-- which tooltip hooks fire (Core/Tooltip.lua)
	local T = BT.UnitTip
	if T then
		U.Print(("tooltip hooks: unit %s (%d filled) · item %s (%d filled) · spell %s (%d filled)"):format(
			tostring(T.path), T.fills or 0, tostring(T.itemPath), T.itemFills or 0, tostring(T.spellPath),
			T.spellFills or 0))
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

-- /bt opens the window, and a second /bt closes it. What follows it, if
-- anything, is not read (see the top of this file).
SLASH_BEEBSTOOLKIT1, SLASH_BEEBSTOOLKIT2 = "/bt", "/beeb"
SlashCmdList.BEEBSTOOLKIT = function()
	-- the window needs a book; bind one now if login never did
	BT.EnsureBound()
	BT.Window.Toggle()
end
