-- Metrics: the readouts, as one module (Josh 2026-09-22).
--
-- Currency, Bags, Durability, Item level, Pick Pocket, Movement speed and
-- Performance are each a few cells of the panel's readout grid, and a tab on
-- the rail for each was seven places to look for one thing. They are parts
-- of this module now: one row of the dock, one place in your order, and a
-- switch for each under Metrics on the Dock's page (2026-10-04).
--
-- Each part is still its own module underneath - its own events, its own
-- hover, its own switch - and is on only while this is on as well (see
-- BT.Enabled). Switching Metrics off puts every cell away; switching it back
-- on brings back the ones you had.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Metrics/Metrics.lua")

local M = BT.Module({
	key = "metrics",
	feature = "dock",
	title = "Metrics",
	order = 38,
	-- a row of the dock, switched and dragged on the Dock's page
	dock = true,
})
