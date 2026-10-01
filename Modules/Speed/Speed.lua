-- Movement speed: how fast you are, as a percentage (Josh 2026-09-22).
--
-- One of the Metrics. A hundred percent is a walk-out-of-town run; a mount is
-- sixty percent more, a dazed hit takes half of it away. The number is the one
-- the character sheet gives, read from the client every half second, so a
-- slow-fall, a sprint or a crippling poison shows up as it happens.
--
-- WHAT YOU ARE DOING, NOT WHAT YOU COULD DO (Josh 2026-09-22). It showed your
-- running speed while you stood still, which reads as "you are moving" when
-- you are not. It is the current speed and nothing else: 0% standing, 100%
-- running, 160% on a mount.
--
-- THE CLIENT KEEPS ITS SPEED SECRET (Josh 2026-09-22). On this build
-- GetUnitSpeed hands an addon a "secret number": it can be passed back to the
-- client but not added, divided or printed - "attempt to perform arithmetic on
-- a secret number value". So the sum is tried once, and where it is refused
-- the number comes from the character sheet instead, which the client fills in
-- itself: the same figure, moving only when that sheet is open.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Speed/Speed.lua")

local U = BT.Util

local M = BT.Module({
	key = "speed",
	title = "Movement speed",
	blurb = "How fast you are, as a percentage",
	order = 39.75,
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	kind = "readout",
})

-- often enough to catch a sprint, rarely enough to cost nothing
local EVERY = 0.5

-- the speed everybody runs at, from the client where it says so
local function base()
	local b = _G.BASE_MOVEMENT_SPEED
	return (type(b) == "number" and b > 0) and b or 7
end

local UNIT = "|cff8a9894%s|r"
local BOOTS = "Interface\\Icons\\INV_Boots_Cloth_05"

-- whether the client will let us do the sum at all; asked once
M.secret = nil

local function yardsToPercent(yards)
	if yards == nil then
		return nil
	end
	local ok, pct = pcall(function()
		return math.floor(yards / base() * 100 + 0.5)
	end)
	if ok and type(pct) == "number" then
		return pct
	end
	M.secret = true
	return nil
end
M.Percentage = yardsToPercent

-- THE SHEET'S OWN FIGURE: the client writes "Movement Speed: 100%" into the
-- character sheet, and that string is ours to read.
--
-- ONLY WHILE THE SHEET IS OPEN (Josh 2026-09-23, audit): this walked every row
-- of the sheet twice a second for the whole session, closed or open, for a
-- figure the client only writes while the sheet is up. It is read while the
-- sheet is shown and kept from then on; closed, the last figure stands.
local function readSheet()
	local pane = _G.CharacterStatsPaneScrollBox
	local target = pane and pane.ScrollBox and pane.ScrollBox.ScrollTarget
	if not (target and target.GetChildren) then
		return nil
	end
	-- the MOVEMENT row: "Attack Speed" comes first on the sheet and its
	-- "2.60" read as two percent
	local want = type(STAT_MOVEMENT_SPEED) == "string" and STAT_MOVEMENT_SPEED:lower() or "movement speed"
	for _, row in ipairs({ target:GetChildren() }) do
		local label = row.IsShown and row:IsShown() and row.Label and row.Label.GetText and row.Label:GetText()
		if type(label) == "string" then
			local l = label:lower()
			if l:find(want, 1, true) or l:find("movement", 1, true) then
				local value = row.Value and row.Value.GetText and row.Value:GetText()
				local n = type(value) == "string" and (value:match("(%d+)%s*%%") or value:match("(%d+)"))
				if n then
					return tonumber(n)
				end
			end
		end
	end
	return nil
end

function M.FromSheet()
	local sheet = _G.CharacterFrame
	if sheet and sheet.IsShown and sheet:IsShown() then
		M.sheetValue = readSheet() or M.sheetValue
	end
	return M.sheetValue
end

-- current, running, flying and swimming, in yards a second
function M.Read()
	if type(GetUnitSpeed) ~= "function" then
		return nil
	end
	local ok, current, run, flight, swim = pcall(GetUnitSpeed, "player")
	if not ok then
		return nil
	end
	-- as they came: a secret is not tested for truth here - yardsToPercent
	-- does the sum inside a pcall and says when it could not
	local function plain(v)
		if issecretvalue and issecretvalue(v) then
			return v
		end
		return type(v) == "number" and v or 0
	end
	return plain(current), plain(run), plain(flight), plain(swim)
end

-- what the cell says: how fast you are going right now
function M.Percent()
	if not M.secret then
		local current = M.Read()
		local pct = yardsToPercent(current)
		if pct then
			return pct
		end
	end
	-- the client will not let the sum be done; the sheet says it instead
	return M.FromSheet()
end

-- SLOWER THAN A WALK, WHILE WALKING, IS WORTH SEEING (Josh 2026-09-22).
-- Faster is good news and reads plain, like every other good value in the
-- grid; moving at less than a run is something with hold of you, and that is
-- amber. Standing still is neither, and reads plain.
function M.State(pct)
	if pct and pct > 0 and pct < 100 then
		return "warn"
	end
	return nil
end

function M.Cell(pct)
	pct = pct or M.Percent()
	if not pct then
		return nil
	end
	return { icon = BOOTS, text = pct .. UNIT:format("%"), state = M.State(pct) }
end

function M.Update()
	if not M.chip then
		return
	end
	local cell = M.Cell()
	M.chip:Want(cell ~= nil and BT.Enabled("speed"))
	if cell then
		M.chip:Set(cell)
	end
end

-- (Josh 2026-09-27, the dock's tooltips redrawn) the figure, and where it
-- came from when the game will not give it
function M.Tip()
	if not BT.Tip then
		return
	end
	local current, run, flight, swim
	if not M.secret then
		current, run, flight, swim = M.Read()
	end
	BT.Tip.Show(M.chip, { build = function(t)
		local pct = M.Percent()
		t:Header({ name = "Movement speed" })
		t:Headline(pct and (pct .. "%") or "-", "of running speed")
		if M.secret then
			t:Note("From your character sheet. The game doesn't give addons your live speed.")
			return
		end
		local rows = {}
		local function line(label, yards)
			local n = M.Percentage(yards)
			if n and n > 0 then
				rows[#rows + 1] = { label, n .. "%" }
			end
		end
		line("Running", run)
		line("Moving now", current)
		line("Swimming", swim)
		line("Flying", flight)
		if #rows > 0 then
			t:Section()
			for _, r in ipairs(rows) do
				t:Row(r[1], r[2])
			end
		end
	end })
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Dock.Chip("speed", "run", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	M.chip:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.chip
end

-- NOTHING TO READ (Josh 2026-09-30, review): with the speed secret the
-- figure is the sheet's, and with the sheet closed it is the one already
-- shown. The half-second tick repainted it twice a second all the same.
function M.Still()
	local sheet = _G.CharacterFrame
	return M.secret == true and not (sheet and sheet.IsShown and sheet:IsShown())
end

function M.Show(on)
	M.Build()
	M.Update()
	if on then
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("speed") and not M.Still() then
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
