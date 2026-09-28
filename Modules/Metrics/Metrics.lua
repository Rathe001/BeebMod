-- Metrics: the readouts, as one module (Josh 2026-09-22).
--
-- Currency, Bags, Durability, Item level, Pick Pocket, Movement speed and
-- Performance are each a few cells of the panel's readout grid, and a tab on
-- the rail for each was seven places to look for one thing. They are parts of this module now:
-- one tab, one place in your order, and a switch for each on its page.
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
	blurb = "Money, bags, durability, item level, pockets, speed and performance in one grid",
	order = 38,
	-- on the right panel, so it has a tab on the rail
	dock = true,
	kind = "readout",
})

-- the parts, in the order the grid shows them
function M.Parts()
	local out = {}
	for _, m in ipairs(BT.Modules()) do
		if m.part == "metrics" then
			out[#out + 1] = m
		end
	end
	table.sort(out, function(a, b) return (a.order or 0) < (b.order or 0) end)
	return out
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

-- one row per part, its switch at the right
local function row(section, part)
	local r = BT.Widgets.SwitchRow(section, part.title, part.blurb or "",
		function() return BT.Switched(part.key) end,
		function(on)
			BT.SetEnabled(part.key, on)
			M:RefreshTab()
		end)
	r.part = part
	return r
end

function M:BuildTab(panel)
	self.panel = panel
	self.page = BT.Widgets.Stack(panel)
	local cells = self.page:Section("Cells")
	self.rows = {}
	-- (the switch that puts the game's bag bar away is the Bag window's now -
	-- Josh 2026-09-24)
	for _, part in ipairs(M.Parts()) do
		self.rows[#self.rows + 1] = row(cells, part)
	end
	-- START AGAIN (Josh 2026-09-28: "We don't need hundreds of slash
	-- commands"): a part that keeps a session or a record has its Reset here,
	-- where /bt gold reset and /bt pockets reset were (the part's resetRow)
	local again = self.page:Section("Start again")
	self.resets = {}
	for _, part in ipairs(M.Parts()) do
		if part.resetRow and part.Reset then
			local r = BT.Widgets.Row(again, part.resetRow[1], part.resetRow[2])
			r.part = part
			r.button = r:SetControl(BT.Widgets.Button(r, "Reset", 62, 20))
			r.button:SetScript("OnClick", function()
				part.Reset()
			end)
			self.resets[#self.resets + 1] = r
		end
	end
	local layout = self.page:Section("Layout")
	local cols = BT.Widgets.Row(layout, "Columns", "How many cells to a line")
	self.colsSeg = cols:SetControl(BT.Widgets.Segmented(cols, { { 3, "Three" }, { 2, "Two" } }, function(n)
		BT.EnsureBound()
		BT.settings.metricsCols = (n == 2) and 2 or nil
		BT.Bar.Relayout()
	end))
	self:RefreshTab()
end

-- which rows show: a part that is not for this class (Pick Pocket) has no row
function M:RefreshTab()
	if not self.rows then
		return
	end
	if self.colsSeg then
		self.colsSeg:Select(BT.Bar.Cols())
	end
	for _, r in ipairs(self.rows) do
		local fits = BT.ClassFits(r.part)
		r:SetShown(fits)
		if fits then
			r.switch:SetOn(BT.Switched(r.part.key))
		end
	end
	-- a part's Reset only while it is on
	for _, r in ipairs(self.resets or {}) do
		r:SetShown(BT.ClassFits(r.part) and BT.Enabled(r.part.key))
	end
	self.page:Layout()
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end
