-- Bags: how full your bags are, one line of the dock (Josh 2026-09-22).
--
-- Moved out of what was the Inventory line, which is Currency again: gold is
-- one thing and room in your bags is another, and each can be switched off or
-- moved without the other.
--
-- BAGS AND REAGENTS, used of total. The backpack and the four bag slots,
-- split by what a bag will take: an ordinary bag takes anything and counts as
-- bags; one that only takes certain things - herbs, enchanting, soul shards,
-- ammunition, or a reagent bag in its own slot - counts as reagents. The
-- client says which through the bag's family.
--
-- The key is "bagspace" because "bags" was the Bag bar restyle's. That module
-- is gone (Josh 2026-09-24): the client's bag bar is this line's to put away,
-- and one owner is enough.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Space/Space.lua")

local U = BT.Util

local M = BT.Module({
	key = "bagspace",
	title = "Bags",
	blurb = "slots used, and your class's reagents",
	order = 39.5,
	-- on the right panel, as a row of the Metrics grid (a part has no tab of
	-- its own: its switch is on the Metrics tab)
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	kind = "readout",
})


local WORDS = "|cff8a9894%s|r"
local FULL = "|cfff26659"
local TIGHT = "|cfff2c75a"
local PLAIN = "|cffe6ebe8"

local function container(fn)
	local c = _G.C_Container
	return (c and c[fn]) or _G[fn]
end

function M.Bags()
	local numSlots = container("GetContainerNumSlots")
	local numFree = container("GetContainerNumFreeSlots")
	local out = { bags = { used = 0, total = 0 }, reagents = { used = 0, total = 0 } }
	if type(numSlots) ~= "function" or type(numFree) ~= "function" then
		return out
	end
	local last = tonumber(_G.NUM_BAG_SLOTS) or 4
	-- the reagent bag's own slot, where the client has one
	local reagentBag = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
	local ids = {}
	for bag = 0, last do
		ids[#ids + 1] = bag
	end
	if reagentBag and reagentBag > last then
		ids[#ids + 1] = reagentBag
	end
	for _, bag in ipairs(ids) do
		local okSlots, slots = pcall(numSlots, bag)
		slots = okSlots and tonumber(slots) or 0
		if slots > 0 then
			local okFree, free, family = pcall(numFree, bag)
			free = okFree and tonumber(free) or 0
			local special = bag == reagentBag or (tonumber(family) or 0) ~= 0
			local into = special and out.reagents or out.bags
			into.total = into.total + slots
			into.used = into.used + math.max(0, slots - free)
		end
	end
	return out
end

-- "28/80", amber at four or fewer free and red when there are none
local function space(label, b)
	local free = b.total - b.used
	local colour = free <= 0 and FULL or (free <= 4 and TIGHT or PLAIN)
	return ("%s %s%d|r%s"):format(WORDS:format(label), colour, b.used,
		WORDS:format("/" .. b.total))
end

function M.Lines(b)
	b = b or M.Bags()
	local left = space("Bags", b.bags)
	local right = b.reagents.total > 0 and space("Reagents", b.reagents) or ""
	return left, right
end

-- ---------------------------------------------------------------------------
-- Class reagents
-- ---------------------------------------------------------------------------

-- CLASS REAGENTS, AND A WARLOCK'S SHARDS (Josh 2026-09-22). What each class
-- spends on its own spells, as the item's own icon and how many you carry.
-- Only what you have is shown - a mage who has not learnt Teleport yet is not
-- told off in red about runes - except the two a class cannot do without:
-- a warlock's shards, and a hunter's ammunition, which show even at nothing.
M.CLASS_REAGENTS = {
	ROGUE = { 5140, 5530 },                         -- Flash Powder, Blinding Powder
	MAGE = { 17031, 17032, 17020, 17056 },          -- Teleportation, Portals, Arcane Powder, Light Feather
	PRIEST = { 17028, 17029, 17056 },               -- Holy Candle, Sacred Candle, Light Feather
	PALADIN = { 17033, 21177 },                     -- Symbol of Divinity, Symbol of Kings
	DRUID = { 17034, 17035, 17036, 17037, 17038,    -- the rebirth seeds
		17021, 17026, 22147 },                      -- and the Gift of the Wild herbs
	SHAMAN = { 17030 },                             -- Ankh
	WARLOCK = { 6265, 5565, 16583 },                -- Soul Shard, Infernal Stone, Demonic Figurine
}
local ALWAYS = { [6265] = true }
-- the hunter's is the ammo slot rather than an item list
local AMMO_SLOT = 0

local function playerClass()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, token = pcall(UnitClass, "player")
	return ok and token or nil
end

local function count(id)
	local get = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
	if type(get) ~= "function" then
		return 0
	end
	local ok, n = pcall(get, id)
	return ok and tonumber(n) or 0
end

local function iconOf(id)
	-- listed with no gaps: a missing first one would end an ipairs before the second
	local getters = {}
	if C_Item and C_Item.GetItemIconByID then
		getters[#getters + 1] = C_Item.GetItemIconByID
	end
	getters[#getters + 1] = _G.GetItemIcon
	for _, get in ipairs(getters) do
		if type(get) == "function" then
			local ok, tex = pcall(get, id)
			if ok and tex then
				return tex
			end
		end
	end
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if type(info) == "function" then
		local ok, _, _, _, _, _, _, _, _, _, tex = pcall(info, id)
		if ok and tex then
			return tex
		end
	end
	return 134400 -- the question mark
end

local function nameOf(id)
	local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if type(info) == "function" then
		local ok, name = pcall(info, id)
		if ok and type(name) == "string" then
			return name
		end
	end
	return ("item %d"):format(id)
end

-- Every reagent of the player's class: its icon, name, how many are carried,
-- and whether it is shown even at nothing.
function M.Reagents()
	local class = playerClass()
	local out = {}
	if class == "HUNTER" then
		local n = 0
		if type(GetInventoryItemCount) == "function" then
			local ok, v = pcall(GetInventoryItemCount, "player", AMMO_SLOT)
			n = ok and tonumber(v) or 0
		end
		local tex = nil
		if type(GetInventoryItemTexture) == "function" then
			-- the second return of a FAILED pcall is the error text, and that
			-- was going to SetTexture as a path
			local ok, t = pcall(GetInventoryItemTexture, "player", AMMO_SLOT)
			tex = ok and t or nil
		end
		out[1] = { name = "Ammunition", icon = tex or 132382, count = n, always = true }
		return out
	end
	for _, id in ipairs(M.CLASS_REAGENTS[class or ""] or {}) do
		out[#out + 1] = { id = id, name = nameOf(id), icon = iconOf(id), count = count(id),
			always = ALWAYS[id] == true }
	end
	return out
end

-- the row: each one carried (or always shown) as its icon and its count
function M.ReagentRow(list)
	list = list or M.Reagents()
	local parts = {}
	for _, r in ipairs(list) do
		if r.count > 0 or r.always then
			local colour = r.count <= 0 and FULL or PLAIN
			parts[#parts + 1] = ("|T%s:13:13:0:0|t %s%d|r"):format(tostring(r.icon), colour, r.count)
		end
	end
	return table.concat(parts, "  ")
end

-- ---------------------------------------------------------------------------
-- The cells (Josh 2026-09-22, the panel redesign)
-- ---------------------------------------------------------------------------
--
-- READOUTS, NOT A LINE. The bags are one cell of the panel's readout grid - a
-- backpack and "17/38", amber at four free and red when full, and a click
-- opens them. Each class reagent the line used to list on a second row is a
-- cell of its own: the item's icon and how many you carry. The space in
-- reagent bags is on the hover, with every reagent of the class.
local BACKPACK = "Interface\\Icons\\INV_Misc_Bag_08"

local function state(free)
	if free <= 0 then
		return "alert"
	elseif free <= 4 then
		return "warn"
	end
	return nil
end

function M.BagCell(b)
	b = b or M.Bags()
	return {
		icon = BACKPACK,
		text = ("%d%s"):format(b.bags.used, WORDS:format("/" .. b.bags.total)),
		state = state(b.bags.total - b.bags.used),
	}
end

-- the reagents that get a cell: each one carried, and the two a class cannot
-- do without even at nothing
function M.ReagentCells(list)
	list = list or M.Reagents()
	local out = {}
	for _, r in ipairs(list) do
		if r.count > 0 or r.always then
			out[#out + 1] = {
				key = r.id or "ammo",
				icon = r.icon,
				text = tostring(r.count),
				state = r.count <= 0 and "alert" or nil,
			}
		end
	end
	return out
end

local function openBags()
	if type(ToggleAllBags) == "function" then
		pcall(ToggleAllBags)
	elseif type(OpenAllBags) == "function" then
		pcall(OpenAllBags)
	end
end

local function hideTip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

function M.Tip(owner)
	if not (GameTooltip and BT.Bar and BT.Bar.Tip) then
		return
	end
	local b = M.Bags()
	BT.Bar.Tip(owner or M.chip, function()
		GameTooltip:AddDoubleLine("Bags", "click to open", 1, 1, 1, 0.55, 0.60, 0.58)
		GameTooltip:AddDoubleLine("bags", ("%d used, %d free"):format(b.bags.used,
			b.bags.total - b.bags.used), 0.7, 0.75, 0.73, 1, 1, 1)
		if b.reagents.total > 0 then
			GameTooltip:AddDoubleLine("reagent bags", ("%d used, %d free"):format(b.reagents.used,
				b.reagents.total - b.reagents.used), 0.7, 0.75, 0.73, 1, 1, 1)
		end
		-- every reagent of the class, the ones you have none of included
		local list = M.Reagents()
		if #list > 0 then
			GameTooltip:AddLine(" ")
			for _, r in ipairs(list) do
				local zero = r.count <= 0
				GameTooltip:AddDoubleLine(("|T%s:13:13:0:0|t %s"):format(tostring(r.icon), r.name),
					tostring(r.count), 0.7, 0.75, 0.73, zero and 0.95 or 1, zero and 0.40 or 1, zero and 0.35 or 1)
			end
		end
	end)
end

-- a cell of the grid, made the first time it is wanted
local function cell(id, order)
	local c = BT.Bar.Chip("bagspace", id, order)
	if not c.beebsBags then
		c.beebsBags = true
		c:SetScript("OnEnter", function(self) M.Tip(self) end)
		c:SetScript("OnLeave", hideTip)
		c:SetScript("OnClick", openBags)
	end
	return c
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = cell("bags", 1)
	M.reagentChips = {}
	return M.chip
end

function M.Update()
	if not M.chip then
		return
	end
	local on = BT.Enabled("bagspace")
	-- no slots at all is no answer yet (the bags are not loaded, or there is
	-- no client to ask): no cell rather than "0/0"
	local b = M.Bags()
	local any = b.bags.total + b.reagents.total > 0
	M.chip:Set(M.BagCell(b))
	M.chip:Want(on and any)
	-- the class's reagents, a cell each, after the bags
	local wanted = {}
	for i, r in ipairs(M.ReagentCells()) do
		local c = M.reagentChips[r.key]
		if not c then
			c = cell("reagent:" .. tostring(r.key), 1 + i)
			M.reagentChips[r.key] = c
		end
		c.order = 1 + i
		c:Set(r)
		wanted[c] = true
	end
	for _, c in pairs(M.reagentChips) do
		c:Want(on and wanted[c] == true)
	end
end

-- whatever moves in or out of a bag, once the client has settled
--
-- ONCE A BURST, AND ONLY WHAT IS OURS (Josh 2026-09-23, audit): BAG_UPDATE
-- (once per bag per change) came beside BAG_UPDATE_DELAYED (once when they
-- settle); every group member's gear change woke it; and every item the
-- client learnt about - by the hundred at an auction house - re-read every
-- bag. Now: the settled event, your own inventory, a name for one of your
-- class's reagents, and one read a frame however many ask.
M.events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
-- a hunter's ammunition is in the ammo slot, not a bag
do
	local ok = M.events.RegisterUnitEvent
		and pcall(M.events.RegisterUnitEvent, M.events, "UNIT_INVENTORY_CHANGED", "player")
	if not ok then
		pcall(M.events.RegisterEvent, M.events, "UNIT_INVENTORY_CHANGED")
	end
end
local queued = false
M.events:SetScript("OnEvent", function(_, event, a)
	if not BT.Enabled("bagspace") then
		return
	end
	if event == "UNIT_INVENTORY_CHANGED" and a and a ~= "player" then
		return
	end
	if event == "GET_ITEM_INFO_RECEIVED" then
		local id = tonumber(a)
		local okC, _, class = pcall(UnitClass, "player")
		class = okC and class or nil
		local mine = false
		for _, rid in ipairs(M.CLASS_REAGENTS[type(class) == "string" and class or ""] or {}) do
			if rid == id then
				mine = true
			end
		end
		if not mine then
			return
		end
	end
	if queued then
		return
	end
	if C_Timer and C_Timer.After then
		queued = true
		C_Timer.After(0, function()
			queued = false
			if BT.Enabled("bagspace") then
				M.Update()
			end
		end)
	else
		M.Update()
	end
end)

-- ---------------------------------------------------------------------------
-- The client's bag bar
-- ---------------------------------------------------------------------------

-- THE CLIENT'S BAG BAR, PUT AWAY (Josh 2026-09-22): a switch on this tab, on
-- unless you turn it off. The backpack, the four bag slots, the reagent slot
-- and what holds them - faded to nothing and taking no clicks, not removed,
-- because Edit Mode owns that bar and puts back anything moved out of it.
-- Your bag keys still open your bags, and so does a click on this line.
local BAG_BAR = {
	"BagsBar", "MainMenuBarBackpackButton",
	"CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "BagBarExpandToggle", "KeyRingButton",
}
local faded = setmetatable({}, { __mode = "k" })

local function fade(f, away)
	if type(f) ~= "table" or not f.SetAlpha then
		return
	end
	if away then
		if faded[f] == nil then
			local ok, mouse = pcall(function() return f.IsMouseEnabled and f:IsMouseEnabled() end)
			faded[f] = { alpha = (f.GetAlpha and f:GetAlpha()) or 1, mouse = ok and mouse or false }
		end
		pcall(f.SetAlpha, f, 0)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, false)
		end
	elseif faded[f] then
		pcall(f.SetAlpha, f, faded[f].alpha)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, faded[f].mouse)
		end
		faded[f] = nil
	end
end

function M.HideClient()
	return not (BT.settings and BT.settings.hideClientBags == false)
end

function M.ApplyClient(hide)
	for _, name in ipairs(BAG_BAR) do
		fade(_G[name], hide)
	end
end

-- AWAY WHILE SOMETHING OF OURS STANDS IN FOR IT (Josh 2026-09-24): the Bags
-- line in the dock, or the bag window; with both off, the game's bar is back
-- whatever the switch says. The switch is on the Bag window's page.
function M.Refit()
	M.ApplyClient(M.HideClient() and (BT.Enabled("bagspace") or BT.Enabled("bagwindow")))
end

function M.SetHideClient(on)
	BT.EnsureBound()
	BT.settings.hideClientBags = on and true or false
	M.Refit()
end

function M.Show(on)
	M.Refit()
	M.Build()
	-- the cells say whether they are wanted; Update decides
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
	local page = BT.Widgets.Stack(panel)
	page:Note("slots used of the slots you have, and under them your class's reagents - a warlock's shards, a hunter's ammo")
	page:Note("amber at four free, red when full · herb, enchanting, soul and ammunition bags count as reagents", true)
	-- (the switch that puts the game's bag bar away is on the Bag window's page)
	page:Layout()
end

function M:RefreshTab()
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

BT.Command("space", function()
	local b = M.Bags()
	U.Print(("bags %d/%d · reagents %d/%d"):format(b.bags.used, b.bags.total,
		b.reagents.used, b.reagents.total))
end, "how full your bags are", "bagspace")
