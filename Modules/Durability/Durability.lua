-- Durability: how worn your gear is, a readout of the panel (Josh 2026-09-22).
--
-- Everything you wear, as one percentage - what it has left of what it could
-- have - and the most worn piece beside it, once something has taken damage.
-- Point at it for every piece. Amber from half, red from a fifth or anything
-- broken: the same points the client's own armour figure changes colour.
--
-- THE CLIENT'S FIGURE GOES WHILE THIS IS ON. The little armoured man it puts
-- on screen when gear wears down says the same thing less exactly. It is
-- faded, not moved or hidden: the client shows and hides it on its own as
-- durability changes, and a faded frame stays faded whichever it does.
-- Switching this off brings it back.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Durability/Durability.lua")

local U = BT.Util

local M = BT.Module({
	key = "durability",
	title = "Durability",
	blurb = "How worn your gear is. Hides the game's armour figure.",
	order = 39.6,
	-- on the right panel, so it has a tab on the rail
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	kind = "readout",
})

local WORDS = "|cff8a9894%s|r"
local RED = "|cfff26659"
local AMBER = "|cfff2c75a"
local PLAIN = "|cffe6ebe8"

-- the slots that wear down, and what to call them
M.SLOTS = {
	{ 1, "Head" }, { 3, "Shoulders" }, { 5, "Chest" }, { 6, "Waist" }, { 7, "Legs" },
	{ 8, "Feet" }, { 9, "Wrists" }, { 10, "Hands" },
	{ 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
}

local function colour(pct, broken)
	if broken or pct <= 20 then
		return RED
	elseif pct <= 50 then
		return AMBER
	end
	return PLAIN
end

-- Every worn piece that has durability: its name, what it has, what it could
-- have. And all of them together, and the worst.
function M.Read()
	local out = { items = {}, cur = 0, max = 0 }
	if type(GetInventoryItemDurability) ~= "function" then
		return out
	end
	for _, slot in ipairs(M.SLOTS) do
		local ok, cur, max = pcall(GetInventoryItemDurability, slot[1])
		cur, max = ok and tonumber(cur) or nil, ok and tonumber(max) or nil
		if cur and max and max > 0 then
			local item = { slot = slot[1], name = slot[2], cur = cur, max = max,
				pct = math.floor(cur / max * 100 + 0.5) }
			out.items[#out.items + 1] = item
			out.cur, out.max = out.cur + cur, out.max + max
			if not out.worst or item.pct < out.worst.pct then
				out.worst = item
			end
		end
	end
	out.pct = out.max > 0 and math.floor(out.cur / out.max * 100 + 0.5) or nil
	return out
end

function M.Lines(d)
	d = d or M.Read()
	if not d.pct then
		return "", ""
	end
	local broken = d.worst and d.worst.cur <= 0
	local left = ("%s %s%d%%|r"):format(WORDS:format("Durability"), colour(d.pct, broken), d.pct)
	local right = ""
	if d.worst and d.worst.pct < 100 then
		right = ("%s %s%d%%|r"):format(WORDS:format(d.worst.name), colour(d.worst.pct, d.worst.cur <= 0),
			d.worst.pct)
	end
	return left, right
end

-- ---------------------------------------------------------------------------
-- The client's figure
-- ---------------------------------------------------------------------------

local faded

function M.HideFigure(hide)
	local f = _G.DurabilityFrame
	if type(f) ~= "table" or not f.SetAlpha then
		return false
	end
	if hide then
		if not faded then
			local ok, mouse = pcall(function() return f.IsMouseEnabled and f:IsMouseEnabled() end)
			faded = { alpha = (f.GetAlpha and f:GetAlpha()) or 1, mouse = ok and mouse or false }
		end
		pcall(f.SetAlpha, f, 0)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, false)
		end
	elseif faded then
		pcall(f.SetAlpha, f, faded.alpha)
		-- and the mouse, which was taken away with the alpha
		if f.EnableMouse and faded.mouse then
			pcall(f.EnableMouse, f, true)
		end
		faded = nil
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The line
-- ---------------------------------------------------------------------------

-- A READOUT (Josh 2026-09-22, the panel redesign): one cell of the grid - an
-- anvil and the percentage, amber from half and red from a fifth or anything
-- broken. The most worn piece and every other one are on the hover.
local ANVIL = "Interface\\Icons\\Trade_BlackSmithing"

function M.Cell(d)
	d = d or M.Read()
	if not d.pct then
		return nil
	end
	-- BY THE FIGURE IT SHOWS (Josh 2026-09-24): the colour was the most worn
	-- piece's, so one tired pair of boots turned a 92% red. The number and its
	-- colour are the average now; the worst piece is on the hover. A piece
	-- actually broken still turns it red: it has stopped doing anything.
	local broken = d.worst and d.worst.cur <= 0
	local state
	if broken or d.pct <= 20 then
		state = "alert"
	elseif d.pct <= 50 then
		state = "warn"
	end
	return { icon = ANVIL, text = d.pct .. "%", state = state }
end

function M.Update()
	if not M.chip then
		return
	end
	local cell = M.Cell()
	-- nothing that wears down, nothing to say
	M.chip:Want(cell ~= nil and BT.Enabled("durability"))
	if cell then
		M.chip:Set(cell)
	end
end

-- a piece's state: red at a fifth or broken, amber at half
local function wear(item)
	if item.cur <= 0 or item.pct <= 20 then
		return "bad"
	elseif item.pct <= 50 then
		return "warn"
	end
	return nil
end

-- WORST FIRST, AND ONLY WHAT NEEDS YOU (Josh 2026-09-27, the dock's tooltips
-- redrawn): the average, then the pieces under 80%, the worst at the top;
-- the rest are counted, not listed
M.FINE = 80

function M.Tip()
	if not BT.Tip then
		return
	end
	local d = M.Read()
	BT.Tip.Show(M.chip, { build = function(t)
		local worn = {}
		for _, item in ipairs(d.items) do
			if item.pct < M.FINE then
				worn[#worn + 1] = item
			end
		end
		table.sort(worn, function(a, b) return a.pct < b.pct end)
		local worst = worn[1] and wear(worn[1])
		t:Header({ name = "Durability", sub = "Your worn gear",
			pill = worst == "bad" and "Repair now" or (worst == "warn" and "Repair soon" or nil),
			pillState = worst })
		local avg = d.pct or 100
		t:Headline(avg .. "%", "on average", avg <= 20 and "bad" or (avg <= 50 and "warn" or nil))
		t:Bar(avg / 100, avg <= 20 and "bad" or (avg <= 50 and "warn" or "good"), { { 0.2, "bad" }, { 0.5, "warn" } })
		if #worn == 0 then
			t:Note(("Every piece is above %d%%."):format(M.FINE))
			return
		end
		t:Section("Worst first")
		for i = 1, math.min(4, #worn) do
			local item = worn[i]
			t:Row(item.name, item.cur <= 0 and "broken" or (item.pct .. "%"), wear(item))
		end
		local more, fine = #worn - math.min(4, #worn), #d.items - #worn
		if more > 0 then
			t:Note(("%d more below %d%%."):format(more, M.FINE))
		end
		if fine > 0 then
			t:Note(("%d other %s above %d%%."):format(fine, fine == 1 and "piece is" or "pieces are", M.FINE))
		end
	end })
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Bar.Chip("durability", "gear", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	M.chip:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.chip
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function()
	if BT.Enabled("durability") then
		M.HideFigure(true)
		M.Update()
	end
end)

function M.Show(on)
	M.Build()
	M.HideFigure(on)
	-- wanted or not by what Update finds
	M.Update()
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
		"Everything you wear as one percentage. Point at it for each piece, worst first.",
		"small", 0.55, 0.60, 0.58)
	note:SetPoint("TOPLEFT", 0, -2)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")

	local why = BT.Widgets.Label(panel,
		"While this is on, BeebMod hides the game's armour figure. Amber from 50%, red from 20%.",
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

BT.Command("durability", function()
	local d = M.Read()
	if not d.pct then
		U.Print("Durability: nothing you wear has any.")
		return
	end
	U.Print(("Durability: %d%%%s"):format(d.pct,
		d.worst and d.worst.pct < 100 and (" · most worn %s %d%%"):format(d.worst.name, d.worst.pct) or ""))
end, "print how worn your gear is", "durability")
