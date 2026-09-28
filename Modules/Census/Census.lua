-- The Census module: what the realm is made of (Josh 2026-09-19).
--
-- It owns a window of its own, opened from the dock's header, and nothing
-- else. The book it draws belongs to the core, which is the point of the
-- split: you can switch the Ledger off, keep no notes on anybody, and still
-- watch the realm fill up.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Census/Census.lua")

local M = BT.Module({
	key = "census",
	feature = "census",
	onPage = "censusset",
	title = "Census",
	blurb = "Who is on the realm",
	order = 20,
	-- its own window, opened from the panel header: no tab on the rail
	standalone = true,
})

function M:BuildTab(parent)
	self.view = BT.Census.Build(parent)
end

function M:ShowTab()
	if self.view then
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
	BT.CensusWindow.Toggle()
end, "open the charts in their own window", "census")

BT.Command("age", function()
	local line = BT.Stats.AgeLine(BT.Stats.Census(BT.db))
	BT.Util.Print("Census: " .. line:sub(1, 1):lower() .. line:sub(2))
end, "print how old this book is", "census")

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
	local p = key and BT.DB.Get(BT.db, key)
	local former, when = BT.DB.FormerGuild(p)
	if former then
		tip:AddLine(("Was in %s, %s"):format(former, U.Since(when)), 0.6, 0.65, 0.7)
		if tip.Show then
			tip:Show()
		end
	end
end)
