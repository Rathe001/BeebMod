-- The Census module: what the realm is made of (Josh 2026-09-19).
--
-- Its charts are the Charts page of the Ledger's window (UI/CensusWindow.lua),
-- and that is all it shows. The book it draws belongs to the core, which is
-- the point of the split: you can keep no notes on anybody and still watch
-- the realm fill up.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Census/Census.lua")

local M = BT.Module({
	key = "census",
	-- a part of the Ledger since 2026-10-04 (BT.MergeCensus)
	feature = "ledger",
	title = "Census",
	-- what a player sees it called: it is the Ledger's, "Record everyone you
	-- see" on its page (2026-10-05, audit: /bt help said "(Census)")
	short = "Ledger",
	order = 20,
})

-- `shell` is the Charts page's rail and toolbar (UI/CensusWindow.lua)
function M:BuildTab(parent, shell)
	self.view = BT.Census.Build(parent, shell)
end

-- opened: the book has moved since it was last counted, very likely, so
-- it is counted again - a slice a frame when it is big (Chart.lua), the
-- last charts showing meanwhile
function M:ShowTab()
	if self.view then
		self.view.stale = true
		BT.Census.Refresh(self.view)
	end
end

function M:Refresh()
	if self.view then
		BT.Census.Refresh(self.view)
	end
end

-- Nothing on the dock: the census is something you go and look at, not
-- something you watch while you play.

BT.Command("census", function()
	BT.CensusWindow.Toggle("charts")
end, "open the Ledger's charts", "census")

-- WAS IN A GUILD (moved from the Ledger's tooltip, Josh 2026-09-26): a guild
-- change is the census's to know, so it says so itself, for anyone in the
-- book - after the Ledger's note and tags
BT.OnUnitTooltip("census", 30, function(tip, unit)
	if not (BT.settings and BT.settings.tooltipGuild and BT.db and tip and unit and UnitIsPlayer(unit)) then
		return
	end
	local U = BT.Util
	local name, realm = U.UnitFullName(unit)
	local key = name and U.Key(name, realm)
	-- read, not taken out: DB.Get unpacks a packed row and keeps it unpacked
	-- until logout, so every player you pointed at stayed a table
	local p = key and BT.DB.View(BT.db, key, BT.DB.Players(BT.db)[key], true)
	local former, when = BT.DB.FormerGuild(p)
	if former then
		-- a row like the Ledger's, under a banner (Josh 2026-10-17, the
		-- tooltip canvas)
		local feature = BT.Feature and BT.Feature("ledger")
		BT.UnitTip.Row(tip, "guild", feature and feature.color or { 0.61, 0.50, 0.82 },
			("Was in %s, %s"):format(former, U.Since(when)), { 0.73, 0.78, 0.76 })
		if tip.Show then
			tip:Show()
		end
	end
end)
