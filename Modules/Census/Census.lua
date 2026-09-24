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
	group = "people",
	onPage = "censusset",
	title = "Census",
	blurb = "who is on the realm",
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
end, "the charts, in their own window", "census")

BT.Command("age", function()
	BT.Util.Print(BT.Stats.AgeLine(BT.Stats.Census(BT.db)))
end, "how old this book is", "census")
