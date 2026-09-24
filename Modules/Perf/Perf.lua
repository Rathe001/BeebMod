-- Performance: frames a second and the two latencies (Josh 2026-09-21).
--
-- The client has these already, behind a hover on the micro menu's help button
-- and a keypress for the frame rate. Both are things you go looking for at the
-- moment something feels wrong - which is the moment you would rather be
-- looking at the fight. Read at a glance, and nothing else: no graph, no
-- history, no memory table.
--
-- THREE READOUTS (Josh 2026-09-22, the panel redesign). They were one line of
-- their own; now they are three cells of the panel's readout grid - the frame
-- rate, then home and world latency under the house and the globe. A good
-- number is plain; amber and red are the only colours, and they mean "worth
-- noticing" and "this is why that felt wrong".
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Perf/Perf.lua")

local U = BT.Util

local M = BT.Module({
	key = "perf",
	title = "Performance",
	blurb = "frame rate and latency",
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

-- the three cells, as they should read now
function M.Cells(fps, home, world)
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

function M.Update()
	if not M.chips then
		return
	end
	local cells = M.Cells(M.Read())
	for id, c in pairs(M.chips) do
		c:Set(cells[id])
	end
end

function M.Tip(owner)
	if not (GameTooltip and BT.Bar and BT.Bar.Tip) then
		return
	end
	local fps, home, world = M.Read()
	BT.Bar.Tip(owner, function()
		GameTooltip:AddLine("Performance", 1, 1, 1)
		GameTooltip:AddDoubleLine("frame rate", fps and ("%d fps"):format(math.floor(fps + 0.5)) or "-",
			0.7, 0.75, 0.73, 1, 1, 1)
		GameTooltip:AddDoubleLine("home: your realm", home and ("%d ms"):format(home) or "-",
			0.7, 0.75, 0.73, 1, 1, 1)
		GameTooltip:AddDoubleLine("world · combat and other players", world and ("%d ms"):format(world) or "-",
			0.7, 0.75, 0.73, 1, 1, 1)
	end)
end

function M.Build()
	if M.chips then
		return M.chips
	end
	M.chips = {
		fps = BT.Bar.Chip("perf", "fps", 1),
		home = BT.Bar.Chip("perf", "home", 2),
		world = BT.Bar.Chip("perf", "world", 3),
	}
	for _, c in pairs(M.chips) do
		c:SetScript("OnEnter", function(self) M.Tip(self) end)
		c:SetScript("OnLeave", function()
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
				if BT.Enabled("perf") then
					M.Update()
				end
			end)
		end
	elseif M.ticker then
		M.ticker:Cancel()
		M.ticker = nil
	end
	BT.Bar.Relayout()
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
		"frames a second, and latency to your realm (the house) and to the world server (the globe)",
		"small", 0.55, 0.60, 0.58)
	note:SetPoint("TOPLEFT", 0, -2)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")

	local why = BT.Widgets.Label(panel,
		"plain is fine, amber is worth noticing, red is why that felt wrong",
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

BT.Command("perf", function()
	local fps, home, world = M.Read()
	U.Print(("%s fps · home %s ms · world %s ms"):format(
		fps and math.floor(fps + 0.5) or "?", tostring(home or "?"), tostring(world or "?")))
end, "frame rate and latency, once", "perf")
