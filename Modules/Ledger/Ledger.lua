-- The Ledger module: what you think of the people you meet (Josh 2026-09-19).
--
-- It owns the Find tab, the tooltip decoration, and the Ledger's entry in the
-- game's right-click menu on a player (Modules/Ledger/Menu.lua), where you tag
-- them and write a note. What you write is kept in the Ledger's own book
-- (Modules/Ledger/Store.lua), not on the census's rows: the Ledger works
-- with no census at all, and uses one to find people when there is one.
--
-- THE TAG SWEEP RUNS HERE AND NOWHERE ELSE. Migrating tags walks every
-- character and removes marks whose meaning no longer exists, which is the
-- most destructive thing this addon does on an ordinary login. A toolkit with
-- the Ledger switched off must never tidy away judgements it is not currently
-- showing you, so it hangs off this module's OnBind.
local _, BT = ...

local N = BT.Notes

local M = BT.Module({
	key = "ledger",
	feature = "ledger",
	title = "Ravenholdt Ledger",
	short = "Ledger",
	order = 10,
})

-- a setting that is on unless switched off, as a row's get and set
local function setting(key)
	return function()
		return not (BT.settings and BT.settings[key] == false)
	end, function(on)
		BT.EnsureBound()
		BT.settings[key] = on and true or false
	end
end

-- THE LEDGER'S PARTS (the settings canvas, Josh 2026-10-04): its own
-- switch is the feature's, so these stand at the top of its page, each one
-- a setting. Notes on tooltips is still BT.settings.tooltip, where
-- Modules/Ledger/Tooltip.lua reads it.
function M:Parts()
	local tipGet, tipSet = setting("tooltip")
	local groupGet, groupSet = setting("ledgerGroups")
	local duelGet, duelSet = setting("ledgerDuels")
	return {
		{ label = "Notes on tooltips", blurb = "Your note, tags and rating on player tooltips",
			get = tipGet, set = tipSet, field = "tooltip" },
		{ label = "People you grouped with", blurb = "Counts a group after 5 minutes together, or in a dungeon",
			get = groupGet, set = groupSet, field = "ledgerGroups" },
		{ label = "Duel scores", blurb = "Your duel record against each player",
			get = duelGet, set = duelSet, field = "ledgerDuels" },
	}
end

-- THE TARGET ROW IS GONE (Josh 2026-10-05: "I like menu B. Then we can
-- remove the old version from the dock"). Your target's name, a dot per tag,
-- the note's mark and a pencil sat in a row at the top of the dock. Notes and
-- tags are written from the game's right-click menu on a player now
-- (Modules/Ledger/Menu.lua), and read on their tooltip and the target frame.

function M:OnBind()
	-- once: what you wrote on the census's rows, into the Ledger's own book
	N.Move()
	BT.MigrateTags()
	-- and the target frame's mark, with the Ledger back on
	if BT.LedgerMenu then
		BT.LedgerMenu.Repaint()
	end
end

function M:OnDisable()
	BT.Find.CloseEditor()
	-- and its window, as the Expedition's goes with it (2026-10-05, audit): left
	-- open, its cards still wrote notes and tags with the Ledger switched off
	if BT.CensusWindow and BT.CensusWindow.Hide then
		BT.CensusWindow.Hide()
	end
	if BT.Tooltip and BT.Tooltip.HidePills then
		BT.Tooltip.HidePills()
	end
	-- the target frame's mark goes with it
	if BT.LedgerMenu then
		BT.LedgerMenu.Repaint()
	end
end

-- NO COMMANDS (Josh 2026-10-18: "I actually never use the slash commands.
-- I'd be fine with removing these (and the others) unless we are using them
-- internally or for debug."). /bt find, note, tag, flag and rate went that
-- day, and BT.Notes.WhoAndRest, which read a name off the front of them.
-- The game's right-click menu on a player writes a note, a tag and a rating
-- (Modules/Ledger/Menu.lua), and the Find page searches, and makes and
-- deletes tags (Modules/Ledger/Find.lua).
