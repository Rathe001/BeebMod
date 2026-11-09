-- Repair and sell grey items at a vendor (Josh 2026-11-08: "Let's do the auto
-- repair and junk sell feature").
--
-- When a vendor's window opens:
--
--   1. every grey item in your bags that has a price is sold, a few at a
--      time (M.BATCH every M.PACE seconds), so the server takes each one
--   2. then your gear is repaired with your own gold, if the vendor repairs
--      and you have enough; the junk's money is in your purse by then
--   3. one chat line says what was sold and what the repair cost
--
-- Holding Shift as the window opens skips both. Each half has its own switch
-- on General. A grey item without a price (hasNoValue) is never sold, and
-- nothing is sold or repaired once the window has closed.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Vendor/Vendor.lua")

local U = BT.Util
local N = function(v, d) return BT.Pill.Number(v, d) end

local M = BT.Module({
	key = "junk",
	title = "Sell grey items",
	order = 99.1,
})
local R = BT.Module({
	key = "repair",
	title = "Repair at vendors",
	order = 99.2,
})
BT.Vendor = M
M.Repair = R

M.POOR = 0
M.BATCH = 6
M.PACE = 0.2

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
	if ok then
		return a, b, c, d, e, f, g, h, i, j, k
	end
	return nil
end

local function container(fn)
	local c = rawget(_G, "C_Container")
	return (c and c[fn]) or rawget(_G, fn)
end

local function bagIds()
	local last = tonumber(_G.NUM_BAG_SLOTS) or 4
	local ids = {}
	for bag = 0, last do
		ids[#ids + 1] = bag
	end
	local reagentBag = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
	if reagentBag and reagentBag > last then
		ids[#ids + 1] = reagentBag
	end
	return ids
end

-- what one stack sells for, in copper
local function priceOf(itemID, count)
	local item = rawget(_G, "C_Item")
	local get = (item and item.GetItemInfo) or rawget(_G, "GetItemInfo")
	local price = select(11, call(get, itemID))
	return N(price, 0) * math.max(1, count)
end

-- the slot as the client describes it: the table C_Container gives, or the
-- older list of values
local function slotInfo(bag, slot)
	local info = call(container("GetContainerItemInfo"), bag, slot)
	if type(info) == "table" then
		return info
	end
	local _, count, locked, quality, _, _, _, _, noValue, itemID = call(container("GetContainerItemInfo"), bag, slot)
	if itemID == nil then
		return nil
	end
	return { stackCount = count, isLocked = locked, quality = quality, hasNoValue = noValue, itemID = itemID }
end

-- every grey stack in your bags that a vendor will pay for
function M.Junk()
	local out = {}
	local numSlots = container("GetContainerNumSlots")
	for _, bag in ipairs(bagIds()) do
		for slot = 1, N(call(numSlots, bag), 0) do
			local info = slotInfo(bag, slot)
			if info and N(info.quality, -1) == M.POOR and not info.hasNoValue and not info.isLocked
				and info.itemID then
				local count = N(info.stackCount, 1)
				local price = priceOf(info.itemID, count)
				if price > 0 then
					out[#out + 1] = { bag = bag, slot = slot, itemID = info.itemID, price = price }
				end
			end
		end
	end
	return out
end

local function shiftDown()
	return call(rawget(_G, "IsShiftKeyDown")) and true or false
end

-- a visit: what was sold, and what the repair cost. M.visit is nil once the
-- window closes, so a timer left over from it does nothing.
M.visit = nil

function M.Say(visit)
	local parts = {}
	if visit.sold > 0 then
		parts[#parts + 1] = ("Sold %d grey %s for %s."):format(visit.sold,
			visit.sold == 1 and "item" or "items", BT.Coins(visit.earned))
	end
	if visit.repaired then
		parts[#parts + 1] = ("Repaired for %s."):format(BT.Coins(visit.repaired))
	elseif visit.short then
		parts[#parts + 1] = ("Not enough gold to repair. It costs %s."):format(BT.Coins(visit.short))
	end
	if #parts > 0 then
		U.Print(table.concat(parts, " "))
	end
	return #parts > 0 and table.concat(parts, " ") or nil
end

-- your own gold; a guild's is never spent
function R.Run(visit)
	if not BT.Enabled("repair") or not call(rawget(_G, "CanMerchantRepair")) then
		return
	end
	local cost, can = call(rawget(_G, "GetRepairAllCost"))
	cost = N(cost, 0)
	if not can or cost <= 0 then
		return
	end
	if N(call(rawget(_G, "GetMoney")), 0) < cost then
		visit.short = cost
		return
	end
	local repair = rawget(_G, "RepairAllItems")
	if type(repair) == "function" and pcall(repair, false) then
		visit.repaired = cost
	end
end

local function finish(visit)
	if M.visit ~= visit then
		return
	end
	R.Run(visit)
	M.Say(visit)
	M.visit = nil
end

-- a few stacks now, the rest after a pause
local function sellSome(visit)
	if M.visit ~= visit then
		return
	end
	local use = container("UseContainerItem")
	local n = 0
	while visit.next <= #visit.junk and n < M.BATCH do
		local j = visit.junk[visit.next]
		visit.next = visit.next + 1
		-- still the same item in the same slot: a bag sorted in between is
		-- not sold from by memory
		local info = slotInfo(j.bag, j.slot)
		if info and info.itemID == j.itemID and not info.isLocked then
			if pcall(use, j.bag, j.slot) then
				visit.sold = visit.sold + 1
				visit.earned = visit.earned + j.price
			end
			n = n + 1
		end
	end
	if visit.next <= #visit.junk and C_Timer and C_Timer.After then
		C_Timer.After(M.PACE, function() sellSome(visit) end)
	elseif C_Timer and C_Timer.After and visit.sold > 0 then
		-- the last sale's money arrives before the repair is asked for
		C_Timer.After(M.PACE, function() finish(visit) end)
	else
		finish(visit)
	end
end

function M.Open()
	M.visit = nil
	if shiftDown() or not (BT.Enabled("junk") or BT.Enabled("repair")) then
		return nil
	end
	local visit = { sold = 0, earned = 0, next = 1, junk = BT.Enabled("junk") and M.Junk() or {} }
	M.visit = visit
	sellSome(visit)
	return visit
end

function M.Close()
	M.visit = nil
end

M.events = CreateFrame("Frame")
pcall(M.events.RegisterEvent, M.events, "MERCHANT_SHOW")
pcall(M.events.RegisterEvent, M.events, "MERCHANT_CLOSED")
M.events:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		local ok, err = pcall(M.Open)
		if not ok then
			BT.Err("vendor.open: " .. tostring(err))
		end
	else
		M.Close()
	end
end)
