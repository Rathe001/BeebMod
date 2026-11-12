-- Currency: your gold, and what this session is earning (Josh 2026-09-22).
--
-- CALLED GOLD, THEN INVENTORY (Josh 2026-09-22). The key stayed "gold" through
-- both names, and became "currency" with the rest of the keys on 2026-09-29
-- (Core/Rename.lua moves the sessions it saved, its place in your tab order
-- and its switch). The bag space it carried for a while is its own line now:
-- see Modules/Bags/Bags.lua.
--
-- One cell of the dock's readout grid: your money, in the client's own coins.
-- Point at it for the session's totals.
--
-- EARNED AND SPENT, APART. Money coming in and money going out are counted
-- separately and are two rows on the hover, with the net an hour under them
-- (Josh 2026-09-27, the dock's tooltips redrawn). The earned-an-hour figure
-- the line once showed went with the line; the words that still promised it
-- went on 2026-09-30 (review).
--
-- A SESSION IS A LOGIN. A /reload carries it on (the save comes back through
-- Data/Live, and the client says which kind of load this is); a fresh login
-- starts a new one. Kept per character, because each has their own purse.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Currency/Currency.lua")

local U = BT.Util

local M = BT.Module({
	key = "currency",
	title = "Currency",
	order = 39,
	-- on the right panel, as a row of the Metrics grid (a part has no tab of
	-- its own: its switch is on the Metrics tab)
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
})

local EVERY = 10
local COIN = 12

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
	BT.settings.currency = BT.settings.currency or {}
	return BT.settings.currency
end

-- ---------------------------------------------------------------------------
-- Every character's purse
-- ---------------------------------------------------------------------------

-- EVERY CHARACTER'S GOLD (Josh 2026-11-08: "Possible to track total money
-- across all characters?"). The game tells an addon only the purse of the
-- character you are playing. So each character writes its own into the
-- account-wide settings when its money changes, under its name and realm
-- (U.MeKey), and the hover adds them up. A character you haven't logged in
-- since this came in isn't counted until you do.
M.LIST_MAX = 10

local function purses()
	if not BT.settings then
		return nil
	end
	BT.settings.purses = BT.settings.purses or {}
	return BT.settings.purses
end

-- this character's purse, written down; nil when there is no name to file
-- it under or no purse to read
function M.Remember()
	local all = purses()
	if not all or type(GetMoney) ~= "function" then
		return nil
	end
	local ok, copper = pcall(GetMoney)
	copper = ok and BT.Pill.Number(copper, nil) or nil
	local who = U.MeKey and U.MeKey() or nil
	if not copper or not who or who == "?" then
		return nil
	end
	local entry = type(all[who]) == "table" and all[who] or {}
	local okC, _, class = pcall(UnitClass, "player")
	if okC and type(class) == "string" then
		entry.class = class
	end
	entry.copper, entry.at = copper, U.Now()
	all[who] = entry
	return entry
end

-- every purse written down, richest first, and what they come to
function M.Purses()
	local list, total, realms = {}, 0, {}
	for who, e in pairs(purses() or {}) do
		if type(who) == "string" and type(e) == "table" and type(e.copper) == "number" then
			local name, realm = who:match("^(.-)@(.+)$")
			list[#list + 1] = { who = who, name = name or who, realm = realm, copper = e.copper, class = e.class }
			total = total + e.copper
			realms[realm or ""] = true
		end
	end
	table.sort(list, function(a, b)
		if a.copper ~= b.copper then
			return a.copper > b.copper
		end
		return a.who < b.who
	end)
	local n = 0
	for _ in pairs(realms) do
		n = n + 1
	end
	return list, total, n > 1
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
	M.Remember()
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
	M.Remember()
	M.Update()
end

-- ---------------------------------------------------------------------------
-- The cell
-- ---------------------------------------------------------------------------

-- A READOUT (Josh 2026-09-22, the panel redesign): one cell of the grid, your
-- gold as the client's coins - to the silver once there is gold, so it fits
-- a third of the panel. The rate per hour is on the hover with the rest of
-- the session.
--
-- ALL OF THEM, FROM A CLICK (Josh 2026-11-08: "Can we click the metric to
-- toggle between total and char only gold?"). A click swaps the cell between
-- this character's gold and every character's together, as the clock swaps
-- local and server time, and which one it shows is remembered. The total
-- has a pile of coins in front, so the two can't be mistaken. With only one
-- character written down there is no total, and the cell shows yours.
M.TOTAL_ICON = "Interface\\Icons\\INV_Misc_Coin_02"

function M.Cell(purse, total)
	if total then
		return { icon = M.TOTAL_ICON, text = M.Coins(total, true) }
	end
	return { text = M.Coins(purse, true) }
end

-- whether there are other characters to add up
function M.HasOthers()
	return #(M.Purses()) > 1
end

-- whether the cell shows every character's gold
function M.ShowsTotal()
	return (BT.settings and BT.settings.currencyTotal) and M.HasOthers() or false
end

function M.Toggle()
	BT.EnsureBound()
	-- NOTHING TO SWITCH TO WITH ONE CHARACTER (2026-11-11, audit): a click
	-- then set the total on unseen, and it showed by itself the day a second
	-- character logged in
	if not M.HasOthers() then
		return false
	end
	BT.settings.currencyTotal = not M.ShowsTotal() or nil
	M.Update()
	return M.ShowsTotal()
end

function M.Update()
	if not M.chip then
		return
	end
	local total = M.ShowsTotal() and select(2, M.Purses()) or nil
	M.chip:Set(M.Cell(money(), total))
	if M.session then
		M.session.last = U.Now()
	end
end

local duration = BT.Session.Duration

function M.Tip()
	local s = M.session
	if not (s and BT.Tip) then
		return
	end
	-- (Josh 2026-09-27, the dock's tooltips redrawn) what you have, which way
	-- this session went, and by how much an hour
	BT.Tip.Show(M.chip, { build = function(t)
		local net = (s.earned or 0) - (s.spent or 0)
		local long = U.Now() - (s.start or U.Now())
		local moved = (s.earned or 0) > 0 or (s.spent or 0) > 0
		-- YOUR WHOLE NAME (2026-10-17, audit). UnitName gives only the first
		-- half on this client (Core/Util.lua, U.Me).
		t:Header({ name = "Money", sub = U.Me and U.Me() or nil,
			pill = moved and (net >= 0 and "Up" or "Down") or nil, pillState = net >= 0 and "good" or "bad" })
		t:Headline(M.Coins(money()))
		if not moved then
			t:Note("No money in or out yet this session.")
		else
			t:Note(("%s%s in %s this session."):format(net >= 0 and "+" or "-", M.Coins(math.abs(net)), duration(long)),
				net >= 0 and "good" or "bad")
			t:Section("This session")
			t:Row("Earned", M.Coins(s.earned or 0))
			t:Row("Spent", M.Coins(s.spent or 0))
			-- ONE RULE FOR A RATE (2026-10-17, audit). The rate follows the
			-- sessions' rule and waits S.SETTLE (Core/Session.lua, S.Rate).
			local rate = BT.Session.Rate(net, s.start)
			if rate then
				t:Row("Net per hour", (rate >= 0 and "+" or "-") .. M.Coins(math.abs(rate), true),
					rate >= 0 and "good" or "bad")
			end
		end
		M.TipPurses(t)
		local foot = {}
		if M.HasOthers() then
			foot[1] = { "Click", M.ShowsTotal() and "show this character" or "show all characters" }
		end
		t:Foot(foot)
	end })
end

-- every character's gold, once there is more than this one: the richest
-- first, the rest as one row, and the total
function M.TipPurses(t)
	local list, total, realms = M.Purses()
	if #list < 2 then
		return false
	end
	t:Section("All characters")
	local others, rest = 0, 0
	for i, p in ipairs(list) do
		if i <= M.LIST_MAX then
			local name = realms and p.realm and (p.name .. " · " .. p.realm) or p.name
			local colour = p.class and { U.ClassColor(p.class) } or nil
			t:Row(name, M.Coins(p.copper, true), nil, nil, colour)
		else
			others, rest = others + 1, rest + p.copper
		end
	end
	if others > 0 then
		t:Row(("%d more"):format(others), M.Coins(rest, true))
	end
	t:Total("Total", M.Coins(total, true))
	return true
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Dock.Chip("currency", "purse", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	-- a click shows every character's gold or this one's, and the open
	-- tooltip says so at once. NO RIGHT-CLICK (Josh 2026-11-10, of Pick
	-- Pocket: "I see no reason the user would ever delete data"; 2026-11-11,
	-- audit: the same holds here): it started a new session. One still
	-- starts on each login.
	M.chip:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		M.Toggle()
		if BT.Tip and BT.Tip.IsShown() then
			M.Tip()
		end
	end)
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
	if not BT.Enabled("currency") then
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
		M.Remember()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("currency") then
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
	-- switched on mid-session (Core/Session.lua)
	BT.Session.Ensure(M)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end


