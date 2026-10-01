-- Item level: the average of what you wear, a readout of the panel
-- (Josh 2026-09-22).
--
-- One of the Metrics, worked out here from each worn piece's level, which
-- every client knows even where its tooltips do not show it. Point at it for
-- each piece.
--
-- RETAIL'S SUM (Josh 2026-09-22): every slot that takes gear counts, an empty
-- one as nothing - so taking a piece off lowers the number - a two-handed
-- weapon counts for the off hand as well, since it fills both, and the result
-- is rounded down, as the character sheet does. The ranged slot counts too,
-- as it did in retail for as long as there was one.
--
-- NOT THE CLIENT'S OWN FIGURE. This client has GetAverageItemLevel, and it
-- came out below even that sum (3, for pieces whose retail average is 4.1),
-- so it is counting by some other rule. Nothing asks it.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/ItemLevel/ItemLevel.lua")

local U = BT.Util

local M = BT.Module({
	key = "itemlevel",
	title = "Item level",
	blurb = "The average item level of what you wear",
	order = 39.65,
	dock = true,
	-- one of the Metrics, switched from its tab
	part = "metrics",
	kind = "readout",
})

local UNIT = "|cff8a9894%s|r"
local ARMOUR = "Interface\\Icons\\INV_Chest_Chain"

-- every slot that takes gear, and what to call it; the shirt and tabard are
-- not gear
M.SLOTS = {
	{ 1, "Head" }, { 2, "Neck" }, { 3, "Shoulders" }, { 15, "Back" }, { 5, "Chest" },
	{ 9, "Wrists" }, { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
	{ 11, "Ring" }, { 12, "Ring" }, { 13, "Trinket" }, { 14, "Trinket" },
	{ 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
}

local function link(slot)
	if type(GetInventoryItemLink) ~= "function" then
		return nil
	end
	local ok, l = pcall(GetInventoryItemLink, "player", slot)
	return ok and l or nil
end

-- a piece's level: the detailed one where the client has it (it counts
-- upgrades), the base one where it does not
function M.LevelOf(itemLink)
	if not itemLink then
		return nil
	end
	local detailed = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
	if type(detailed) == "function" then
		local ok, lvl = pcall(detailed, itemLink)
		if ok and tonumber(lvl) and tonumber(lvl) > 0 then
			return tonumber(lvl)
		end
	end
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if type(info) == "function" then
		local ok, _, _, _, lvl = pcall(info, itemLink)
		if ok and tonumber(lvl) and tonumber(lvl) > 0 then
			return tonumber(lvl)
		end
	end
	return nil
end

-- whether it is two-handed, and whether the client could say (an item it has
-- not described yet answers nothing)
local function twoHanded(itemLink)
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if not (itemLink and type(info) == "function") then
		return false, true
	end
	local ok, name, _, _, _, _, _, _, _, equipLoc = pcall(info, itemLink)
	return ok and equipLoc == "INVTYPE_2HWEAPON", ok and name ~= nil
end

-- Every worn piece and its level, and the average. `doubled` is the level a
-- two-hander adds for the off hand it fills; `pending` says a worn piece has
-- not been described yet, so the answer may still change.
function M.Read()
	local out = { items = {}, sum = 0, slots = #M.SLOTS }
	local offEmpty, mainTwoHand, mainLevel = true, false, nil
	for _, slot in ipairs(M.SLOTS) do
		local l = link(slot[1])
		local lvl = M.LevelOf(l)
		if l and not lvl then
			out.pending = true
		end
		if lvl then
			out.items[#out.items + 1] = { slot = slot[1], name = slot[2], level = lvl }
			out.sum = out.sum + lvl
			if slot[1] == 16 then
				local known
				mainTwoHand, known = twoHanded(l)
				mainLevel = lvl
				if not known then
					out.pending = true
				end
			elseif slot[1] == 17 then
				offEmpty = false
			end
		end
	end
	if mainTwoHand and offEmpty and mainLevel then
		out.sum = out.sum + mainLevel
		out.doubled = mainLevel
	end
	out.avg = #out.items > 0 and out.sum / out.slots or nil
	return out
end

function M.Value(d)
	d = d or M.Read()
	return d.avg and math.floor(d.avg) or nil
end

function M.Cell(d)
	local v = M.Value(d)
	if not v then
		return nil
	end
	return { icon = ARMOUR, text = v .. " " .. UNIT:format("ilvl") }
end

function M.Update()
	if not M.chip then
		return
	end
	local d = M.Read()
	M.pending = d.pending and true or false
	local cell = M.Cell(d)
	-- nothing worn that has a level, nothing to say
	M.chip:Want(cell ~= nil and BT.Enabled("itemlevel"))
	if cell then
		M.chip:Set(cell)
	end
end

-- an item's name and its quality's colour, or the slot's name
local function named(item)
	local l = link(item.slot)
	if l then
		local name, _, quality = U.ItemInfo(l)
		if type(name) == "string" then
			local colour
			if type(quality) == "number" and type(GetItemQualityColor) == "function" then
				local okC, r, g, b = pcall(GetItemQualityColor, quality)
				if okC and type(r) == "number" then
					colour = { r, g, b }
				end
			end
			return name, colour
		end
	end
	return item.name, nil
end

-- UPGRADES, NOT SEVENTEEN SLOTS (Josh 2026-09-27, the dock's tooltips
-- redrawn): the average, then the three lowest - an empty slot lowest of all
-- - and the best piece
function M.Tip()
	if not BT.Tip then
		return
	end
	local d = M.Read()
	BT.Tip.Show(M.chip, { build = function(t)
		t:Header({ name = "Item level", sub = "All 17 slots, a two-hander counted twice" })
		t:Headline(d.avg and ("%.1f"):format(d.avg) or "-", "average")
		local worn = {}
		for _, item in ipairs(d.items) do
			worn[item.slot] = item
		end
		local low = {}
		for _, slot in ipairs(M.SLOTS) do
			local item = worn[slot[1]]
			-- the off hand a two-hander fills is not empty: the sum counts it
			-- full (Josh 2026-09-30, review: it was listed lowest, in red)
			if item then
				low[#low + 1] = { item = item, level = item.level }
			elseif not (slot[1] == 17 and d.doubled) then
				low[#low + 1] = { empty = slot[2], level = -1 }
			end
		end
		table.sort(low, function(a, b) return a.level < b.level end)
		t:Section("Lowest")
		for i = 1, math.min(3, #low) do
			local e = low[i]
			if e.empty then
				t:Row(e.empty, "empty", "bad")
			else
				local name, colour = named(e.item)
				t:Row(name, e.level, nil, nil, colour)
			end
		end
		local best
		for _, item in ipairs(d.items) do
			if not best or item.level > best.level then
				best = item
			end
		end
		if best then
			t:Section("Highest")
			local name, colour = named(best)
			t:Row(name, best.level, nil, nil, colour)
		end
	end })
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Dock.Chip("itemlevel", "worn", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	M.chip:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.chip
end

-- ASKED AGAIN AFTER LOGIN (Josh 2026-09-22). At login the client has not
-- described your gear yet: every piece's level comes back nil, the cell
-- stays away, and nothing about logging in ever says "your gear" again the
-- way changing a piece does. A few more looks over the first seconds, and
-- whenever the inventory changes, is what switching it off and on did by hand.
local LOOK_AGAIN = { 1, 3, 8 }

function M.Settle()
	M.Update()
	if C_Timer and C_Timer.After then
		for _, after in ipairs(LOOK_AGAIN) do
			C_Timer.After(after, function()
				if BT.Enabled("itemlevel") then
					M.Update()
				end
			end)
		end
	end
end

-- NOT ON A LOADING SCREEN (Josh 2026-09-30, review): every loading screen
-- runs OnBind, which is Show(true) and so M.Settle - the same looks this
-- handler started on PLAYER_ENTERING_WORLD, so each screen had them twice
M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_AVG_ITEM_LEVEL_UPDATE", "GET_ITEM_INFO_RECEIVED", "UNIT_INVENTORY_CHANGED" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
local queued = false
M.events:SetScript("OnEvent", function(_, event, unit)
	if not BT.Enabled("itemlevel") then
		return
	end
	if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
		return
	-- ONLY WHILE SOMETHING WORN IS UNDESCRIBED (Josh 2026-09-30, review).
	-- Item information arrives all the time at an auction house or a bank,
	-- for items you are not wearing; once every worn piece has its level,
	-- none of it can change the number.
	elseif event == "GET_ITEM_INFO_RECEIVED" and M.pending == false then
		return
	elseif queued then
		return
	elseif C_Timer and C_Timer.After then
		-- one read a frame: item information arrives by the hundred at an
		-- auction house or a bank (Josh 2026-09-23, audit)
		queued = true
		C_Timer.After(0, function()
			queued = false
			if BT.Enabled("itemlevel") then
				M.Update()
			end
		end)
	else
		M.Update()
	end
end)

function M.Show(on)
	M.Build()
	-- wanted or not by what Update finds, and found again once the client
	-- has described your gear
	if on then
		M.Settle()
	else
		M.Update()
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
