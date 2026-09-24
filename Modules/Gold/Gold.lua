-- Currency: your gold, and what this session is earning (Josh 2026-09-22).
--
-- CALLED GOLD, THEN INVENTORY (Josh 2026-09-22). The key is still "gold", so
-- the sessions it saved, its place in your tab order and whether it is on all
-- carry over. The bag space it carried for a while is its own line now: see
-- Modules/Space/Space.lua.
--
-- One line of the dock, under the row: your money on the left in the client's
-- own coins, and what you have earned per hour on the right. Point at it for
-- the session's totals.
--
-- EARNED, NOT NET. Money coming in is what "per hour" is about - loot, quest
-- rewards, sales. A trainer visit is not a slower farm, so spending is counted
-- separately and shown on hover rather than taken off the rate.
--
-- A SESSION IS A LOGIN. A /reload carries it on (the save comes back through
-- Data/Live, and the client says which kind of load this is); a fresh login
-- starts a new one. Kept per character, because each has their own purse.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Gold/Gold.lua")

local U = BT.Util

local M = BT.Module({
	key = "gold",
	title = "Currency",
	blurb = "your gold, and earned per hour",
	order = 39,
	-- on the right panel, as a row of the Metrics grid (a part has no tab of
	-- its own: its switch is on the Metrics tab)
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	kind = "readout",
})

local EVERY = 10
local COIN = 12

local WORDS = "|cff8a9894%s|r"
local GAIN = "|cff8cd99a"

-- THE COINS THE MONEY FRAME DRAWS (Josh 2026-09-22). Not GetCoinTextureString,
-- which this client may not have - its absence left "2g 9s 39c" in letters.
-- A number and its coin, the way the bag bar shows your purse: the client's
-- own format strings where it defines them, and the same three images by
-- path where it does not.
local ICON = {
	gold = "Interface\\MoneyFrame\\UI-GoldIcon",
	silver = "Interface\\MoneyFrame\\UI-SilverIcon",
	copper = "Interface\\MoneyFrame\\UI-CopperIcon",
}
local FORMAT = {
	gold = "GOLD_AMOUNT_TEXTURE",
	silver = "SILVER_AMOUNT_TEXTURE",
	copper = "COPPER_AMOUNT_TEXTURE",
}

local function coin(n, which)
	local fmt = _G[FORMAT[which]]
	if type(fmt) == "string" then
		local ok, s = pcall(string.format, fmt, n, COIN, COIN)
		if ok and s then
			return s
		end
	end
	return ("%d|T%s:%d:%d:2:0|t"):format(n, ICON[which], COIN, COIN)
end

-- `coarse` drops the copper once there is gold: an hourly rate to the copper
-- is noise, and "5g 0s 0c /h" reads worse than "5g 0s /h"
function M.Coins(copper, coarse)
	copper = math.max(0, math.floor(copper or 0))
	local g = math.floor(copper / 10000)
	local s = math.floor(copper / 100) % 100
	local c = copper % 100
	local parts = {}
	if g > 0 then
		parts[#parts + 1] = coin(g, "gold")
	end
	-- a zero in the middle is shown, as the money frame does: 2g 0s 5c
	if s > 0 or g > 0 then
		parts[#parts + 1] = coin(s, "silver")
	end
	if not (coarse and g > 0) then
		parts[#parts + 1] = coin(c, "copper")
	end
	return table.concat(parts, " ")
end

-- the coins, for any line that shows an amount of money (Pick Pocket does)
BT.Coins = M.Coins

local function money()
	return type(GetMoney) == "function" and (GetMoney() or 0) or 0
end

-- ---------------------------------------------------------------------------
-- The session
-- ---------------------------------------------------------------------------

local function store()
	if not BT.settings then
		return nil
	end
	BT.settings.gold = BT.settings.gold or {}
	return BT.settings.gold
end

-- A new session on a login, the same one on a reload (Core/Session.lua).
function M.Start(initial, reloading)
	local all = store()
	if not all then
		return nil
	end
	M.session = BT.Session.Open(all, initial, reloading, function(now)
		return { start = now, earned = 0, spent = 0 }
	end)
	M.purse = money()
	M.Update()
	return M.session
end

-- Every change to the purse: in is earned, out is spent.
function M.Money()
	local s = M.session
	if not s then
		return
	end
	local now = money()
	local delta = now - (M.purse or now)
	if delta > 0 then
		s.earned = (s.earned or 0) + delta
	elseif delta < 0 then
		s.spent = (s.spent or 0) - delta
	end
	M.purse = now
	s.last = U.Now()
	M.Update()
end

-- copper per hour earned, or nil while there is too little time to say
function M.Rate(s, now)
	s = s or M.session
	if not s then
		return nil
	end
	return BT.Session.Rate(s.earned, s.start, now)
end

-- ---------------------------------------------------------------------------
-- The line
-- ---------------------------------------------------------------------------

function M.Lines(purse, rate)
	local left = M.Coins(purse)
	local right
	if not rate then
		right = WORDS:format("- /h")
	elseif rate < 1 then
		right = WORDS:format("0 /h")
	else
		right = GAIN .. "+|r" .. M.Coins(rate, true) .. " " .. WORDS:format("/h")
	end
	return left, right
end

-- A READOUT (Josh 2026-09-22, the panel redesign): one cell of the grid, your
-- gold as the client's coins - to the silver once there is gold, so it fits
-- a third of the panel. The rate per hour is on the hover with the rest of
-- the session.
function M.Cell(purse)
	return { text = M.Coins(purse, true) }
end

function M.Update()
	if not M.chip then
		return
	end
	M.chip:Set(M.Cell(money()))
	if M.session then
		M.session.last = U.Now()
	end
end

local duration = BT.Session.Duration

function M.Tip()
	local s = M.session
	if not (s and GameTooltip and BT.Bar and BT.Bar.Tip) then
		return
	end
	BT.Bar.Tip(M.chip, function()
		GameTooltip:AddDoubleLine("Currency", M.Coins(money()), 1, 1, 1, 1, 1, 1)
		local _, rate = M.Lines(money(), M.Rate())
		GameTooltip:AddDoubleLine("earned an hour", rate, 0.7, 0.75, 0.73, 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("This session", 1, 1, 1)
		GameTooltip:AddDoubleLine("earned", M.Coins(s.earned), 0.7, 0.75, 0.73, 1, 1, 1)
		GameTooltip:AddDoubleLine("spent", M.Coins(s.spent), 0.7, 0.75, 0.73, 1, 1, 1)
		local net = (s.earned or 0) - (s.spent or 0)
		GameTooltip:AddDoubleLine(net >= 0 and "up" or "down", M.Coins(math.abs(net)),
			0.7, 0.75, 0.73, 1, 1, 1)
		GameTooltip:AddDoubleLine("over", duration(U.Now() - (s.start or U.Now())),
			0.7, 0.75, 0.73, 1, 1, 1)
	end)
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Bar.Chip("gold", "purse", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	M.chip:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.chip
end

-- the purse and the load: money changes, and which kind of load this was
M.events = CreateFrame("Frame")
M.events:RegisterEvent("PLAYER_MONEY")
M.events:RegisterEvent("PLAYER_ENTERING_WORLD")
M.events:SetScript("OnEvent", function(_, event, initial, reloading)
	if not BT.Enabled("gold") then
		return
	end
	if event == "PLAYER_MONEY" then
		M.Money()
	elseif event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, initial, reloading)
	end
end)

function M.Show(on)
	M.Build():Want(on)
	if on then
		-- what is in the purse NOW: money made or spent while this was off
		-- is not this session's to count (Josh 2026-09-23, audit - it booked
		-- the whole gap as one purchase or one windfall)
		if M.session and type(GetMoney) == "function" then
			local ok, now = pcall(GetMoney)
			if ok and type(now) == "number" then
				M.purse = now
			end
		end
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("gold") then
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
	-- switched on mid-session (Core/Session.lua)
	BT.Session.Ensure(M)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local note = BT.Widgets.Label(panel,
		"your gold, and what this session has earned per hour - point at the line for the totals",
		"small", 0.55, 0.60, 0.58)
	note:SetPoint("TOPLEFT", 0, -2)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")

	local why = BT.Widgets.Label(panel,
		"earned counts money coming in; spending is shown on its own rather than taken off the rate",
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

BT.Command("gold", function(rest)
	if (rest or ""):lower() == "reset" then
		M.Start(true, false)
		U.Print("a new gold session starts now")
		return
	end
	local s = M.session
	if not s then
		U.Print("no gold session yet")
		return
	end
	local rate = M.Rate()
	U.Print(("gold: %s · earned %s · spent %s · %s"):format(M.Coins(money()),
		M.Coins(s.earned), M.Coins(s.spent),
		rate and (M.Coins(rate) .. " an hour") or "too early for a rate"))
end, "gold [reset] - this session's gold, or start a new one", "gold")
