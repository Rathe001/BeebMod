-- Performance: frames a second and the two latencies (Josh 2026-09-21).
--
-- The client has these already, behind a hover on the micro menu's help button
-- and a keypress for the frame rate. Both are things you go looking for at the
-- moment something feels wrong - which is the moment you would rather be
-- looking at the fight. Read at a glance; the last two minutes of them are on
-- a graph in the hover (Josh 2026-09-29), sixty readings a line.
--
-- ONE CELL OF THE READOUT GRID (Josh 2026-09-22, the panel redesign; one
-- cell since 2026-09-29, M.Line) - the frame rate, then home and world
-- latency after the gauge, the house and the globe, each in its line's
-- colour, and red when it is why that felt wrong.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Performance/Performance.lua")

local U = BT.Util

local M = BT.Module({
	key = "performance",
	title = "Performance",
	blurb = "Frame rate and latency",
	order = 39.8,
	-- on the right panel, as a row of the Metrics grid (a part has no tab of
	-- its own: its switch is on the Metrics tab)
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	kind = "readout",
})

-- often enough to see a stutter, rarely enough to cost nothing
local EVERY = 1

-- HOUSE AND GLOBE (Josh 2026-09-21). Drawn by scripts/make-icons.py into
-- Art/net.tga, a sheet of marks a quarter wide each, in the same quiet grey
-- the words were.
local NET = "Interface\\AddOns\\BeebMod\\Art\\net"
local QUIET = { 0.54, 0.60, 0.58, 1 }
M.HOUSE = { icon = NET, coords = { 0, 0.25, 0, 1 }, tint = QUIET }
M.GLOBE = { icon = NET, coords = { 0.25, 0.5, 0, 1 }, tint = QUIET }

local UNIT = "|cff8a9894%s|r"

-- more frames is better, less latency is better; plain is fine
function M.FpsState(fps)
	if fps >= 50 then
		return nil
	elseif fps >= 30 then
		return "warn"
	end
	return "alert"
end

function M.MsState(ms)
	if ms < 100 then
		return nil
	elseif ms < 250 then
		return "warn"
	end
	return "alert"
end

-- What the client says right now: frames a second, home and world latency in
-- milliseconds. Nil for anything it will not say.
function M.Read()
	local fps = type(GetFramerate) == "function" and GetFramerate() or nil
	local home, world
	if type(GetNetStats) == "function" then
		local _, _, h, w = GetNetStats()
		home, world = h, w
	end
	return fps, home, world
end

-- the three figures, each as it should read now (M.Line joins them). Not
-- `Cells`: that name is the dock's question to a module (UI/Dock.lua, B.Rebuild)
function M.Figures(fps, home, world)
	local function ms(mark, v)
		return {
			icon = mark.icon, coords = mark.coords, tint = mark.tint,
			text = v and (math.floor(v + 0.5) .. " " .. UNIT:format("ms")) or UNIT:format("-"),
			state = v and M.MsState(v) or nil,
		}
	end
	return {
		fps = {
			text = fps and (math.floor(fps + 0.5) .. " " .. UNIT:format("fps")) or UNIT:format("- fps"),
			state = fps and M.FpsState(fps) or nil,
		},
		home = ms(M.HOUSE, home),
		world = ms(M.GLOBE, world),
	}
end

-- ONE CELL, NOT THREE (Josh 2026-09-29: "The performance/latency metrics
-- should be grouped together instead of individual cells"): two columns of
-- the grid, the frame rate after a gauge, then home and world latency after
-- the house and the globe, each figure in its own colour when it is worth
-- noticing. THE SAME SIZE AND THE SAME MIDDLE AS THE OTHERS (Josh
-- 2026-09-29): each mark is an icon of its own, as any cell's is, cropped to
-- the drawing so it fills its twelve pixels as a game icon does; the marks
-- say which figure is which, and each keeps its unit close up: "45fps 39ms 93ms".
local function mark(slot)
	local l = slot * 0.25
	return { icon = NET, coords = { l + 0.25 * 3 / 32, l + 0.25 * 29 / 32, 3 / 32, 29 / 32 }, tint = QUIET }
end
M.MARKS = { fps = mark(3), home = mark(0), world = mark(1) }

-- A LINE EACH (Josh 2026-09-29: "a single graph, with 3 colored lines ... We
-- would then color the text and icon to match the line color"): each
-- figure, its mark and its line in one colour - none of them the red a bad
-- figure turns, or the amber it no longer does
M.COLORS = {
	fps = { 0.42, 0.85, 0.62 },
	home = { 0.45, 0.72, 1.00 },
	world = { 0.78, 0.62, 1.00 },
}

-- THE LAST TWO MINUTES: a reading every two seconds, sixty in all. Latency
-- is worked out afresh only every thirty seconds or so, so a shorter window
-- would draw two flat lines and the frame rate. Each line keeps at least
-- this much room, so a steady figure is a steady line and not its noise
-- blown up to the graph's height.
M.SAMPLE_EVERY, M.SAMPLES = 2, 60
M.SPAN = { fps = 10, home = 20, world = 20 }
M.history = { fps = {}, home = {}, world = {} }

function M.Sample(fps, home, world, now)
	now = now or (type(GetTime) == "function" and GetTime()) or 0
	if M.sampledAt and now - M.sampledAt < M.SAMPLE_EVERY then
		return false
	end
	M.sampledAt = now
	for key, v in pairs({ fps = fps, home = home, world = world }) do
		local list = M.history[key]
		list[#list + 1] = v
		while #list > M.SAMPLES do
			table.remove(list, 1)
		end
	end
	return true
end

-- the graph's three lines, in the figures' order
function M.Series()
	local out = {}
	for _, key in ipairs({ "fps", "home", "world" }) do
		out[#out + 1] = { values = M.history[key], slots = M.SAMPLES, span = M.SPAN[key], color = M.COLORS[key] }
	end
	return out
end

function M.Line(fps, home, world)
	local cells = M.Figures(fps, home, world)
	local function figure(v)
		return v and tostring(math.floor(v + 0.5)) or "-"
	end
	local segments = {}
	for _, it in ipairs({
		-- A UNIT EACH, CLOSE UP (Josh 2026-09-29: "Can we format this like:
		-- 45fps 39ms 93ms"), in the units' quiet grey
		{ "fps", figure(fps) .. UNIT:format("fps") },
		{ "home", figure(home) .. UNIT:format("ms") },
		{ "world", figure(world) .. UNIT:format("ms") },
	}) do
		local m, key = M.MARKS[it[1]], it[1]
		-- in the line's colour; red only when it is bad
		local state = cells[key].state == "alert" and "alert" or nil
		segments[#segments + 1] = { icon = m.icon, coords = m.coords, tint = M.COLORS[key],
			color = M.COLORS[key], text = it[2], state = state }
	end
	return { segments = segments, parts = cells }
end

function M.Update()
	if not M.chips then
		return
	end
	local fps, home, world = M.Read()
	M.chips.all:Set(M.Line(fps, home, world))
	-- with a new reading, every other second, the tooltip - if it is open -
	-- is drawn again, graph and all
	if M.Sample(fps, home, world) and M.tipOpen and BT.Tip and BT.Tip.IsShown() then
		M.Tip(M.chips.all)
	end
end

-- a cell's state as the tooltip colours it
local TIP_STATE = { warn = "warn", alert = "bad" }

-- (Josh 2026-09-27, the dock's tooltips redrawn) three tiles, coloured by
-- how they are doing, and a line on which latency is which
function M.Tip(owner)
	if not BT.Tip then
		return
	end
	local fps, home, world = M.Read()
	BT.Tip.Show(owner, { build = function(t)
		local fs = fps and TIP_STATE[M.FpsState(fps) or ""]
		local hs = home and TIP_STATE[M.MsState(home) or ""]
		local ws = world and TIP_STATE[M.MsState(world) or ""]
		local worst = (fs == "bad" or hs == "bad" or ws == "bad") and "bad"
			or ((fs or hs or ws) and "warn" or "good")
		t:Header({ name = "Performance", sub = "This computer and its connection",
			pill = worst == "bad" and "Slow" or (worst == "warn" and "Uneven" or "Smooth"), pillState = worst })
		-- each figure in its line's colour, red when it is bad: the key to
		-- the graph under them (Josh 2026-09-29: the graph in the tooltip)
		local function tone(state, key)
			return state == "bad" and "bad" or M.COLORS[key]
		end
		t:Stats({
			{ fps and math.floor(fps + 0.5) or "-", "frames a second", tone(fs, "fps") },
			{ home or "-", "home ms", tone(hs, "home") },
			{ world or "-", "world ms", tone(ws, "world") },
		})
		t:Graph(M.Series(), 40)
		t:Note("The last two minutes, each line on its own scale. Home latency is chat and the auction house. World latency is combat. Above about 150 ms, casts and swings feel late.")
	end })
end

function M.Build()
	if M.chips then
		return M.chips
	end
	M.chips = {
		-- two of the grid's three columns (Josh 2026-09-29: "reduce the
		-- colspan to 2 instead of 3")
		all = BT.Dock.Chip("performance", "all", 1, 2),
	}
	for _, c in pairs(M.chips) do
		c:SetScript("OnEnter", function(self)
			M.tipOpen = true
			M.Tip(self)
		end)
		c:SetScript("OnLeave", function()
			M.tipOpen = false
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
	end
	return M.chips
end

function M.Show(on)
	M.Build()
	for _, c in pairs(M.chips) do
		c:Want(on)
	end
	if on then
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("performance") then
					M.Update()
				end
			end)
		end
	elseif M.ticker then
		M.ticker:Cancel()
		M.ticker = nil
	end
	BT.Dock.Relayout()
end

function M:OnEnable()
	M.Show(true)
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local note = BT.Widgets.Label(panel,
		"Frames a second, and latency to your realm (the house) and to the world server (the globe).",
		"small", 0.55, 0.60, 0.58)
	note:SetPoint("TOPLEFT", 0, -2)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")

	local why = BT.Widgets.Label(panel,
		"Red below 30 fps or from 250 ms. Point at them for the last two minutes on a graph, each line on its own scale.",
		"small", 0.45, 0.50, 0.48)
	why:SetPoint("TOPLEFT", 0, -22)
	why:SetWidth(520)
	why:SetJustifyH("LEFT")
end

function M:RefreshTab()
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end
