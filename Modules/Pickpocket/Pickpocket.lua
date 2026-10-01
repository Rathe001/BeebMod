-- Pick Pocket: what a rogue's fingers have been worth (Josh 2026-09-22).
--
-- A line of the dock, for rogues only: everything you have pickpocketed, as
-- money - the coin itself, plus what the vendor would give for the items -
-- all time on the left, this session on the right. Point at it for the split.
--
-- HOW A PICK IS TOLD APART FROM ANY OTHER LOOT. Pick Pocket is a cast, and
-- the loot window that opens straight after it is the victim's pocket. So a
-- successful cast is noted, and a loot window opening within a few seconds of
-- it is a pocket:
--
--   coin    whatever the purse goes up by while that window is open, and for
--           a moment after it closes (the money can land a beat late)
--   items   each slot that is actually taken - LOOT_SLOT_CLEARED - at the
--           item's vendor price; a slot left behind is not counted
--
-- Items are kept by ID and count, and priced when shown, so one the client has
-- not described yet counts as soon as it has. Kept per character, with the
-- rest of your settings.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Pickpocket/Pickpocket.lua")

local U = BT.Util

local M = BT.Module({
	key = "pickpocket",
	title = "Pick Pocket",
	blurb = "Coin from pockets, and what the items sell for",
	order = 39.7,
	-- on the right panel, and only for rogues
	dock = true,
	-- one of the Metrics, switched from its tab (Josh 2026-09-22)
	part = "metrics",
	class = "ROGUE",
	kind = "readout",
})

local PICK_POCKET = 921
-- how long after the cast a loot window still counts as the pocket, and how
-- long after it closes the money may still land
local OPEN_WITHIN, LATE_MONEY = 3, 1

local function now()
	if type(GetTime) == "function" then
		return GetTime()
	end
	return U.Now()
end

local function coins(copper)
	return BT.Coins and BT.Coins(copper) or tostring(math.floor(copper or 0))
end

-- ---------------------------------------------------------------------------
-- The record
-- ---------------------------------------------------------------------------

local function empty()
	return { coin = 0, items = {}, picks = 0 }
end

-- this character's all-time record, kept with the settings
function M.Record()
	if not BT.settings then
		return nil
	end
	BT.settings.pickpocket = BT.settings.pickpocket or {}
	local all = BT.settings.pickpocket
	local r, who = BT.Session.Mine(all)
	if not r then
		r = empty()
		all[who] = r
	end
	r.items = r.items or {}
	return r
end

-- A new session on a login, the same one on a reload (Core/Session.lua). The
-- session lives beside the record and is carried through a reload by the
-- record itself.
function M.Start(initial, reloading)
	local r = M.Record()
	if not r then
		return nil
	end
	if not BT.Session.CarriesOn(r.session, initial, reloading) then
		r.session = empty()
	end
	r.session.last = U.Now()
	M.session = r.session
	M.Update()
	return r.session
end

-- the vendor's price for one of an item, or 0 while the client has not said
local function price(itemID)
	local sell = select(11, U.ItemInfo(itemID))
	return tonumber(sell) or 0
end
M.Price = price

-- coin, and what the items would fetch, for a record or a session
function M.Worth(r)
	if not r then
		return 0, 0
	end
	local items = 0
	for id, count in pairs(r.items or {}) do
		items = items + price(id) * count
	end
	return r.coin or 0, items
end

local function add(r, what, amount, id)
	if r.session then
		r.session.last = U.Now()
	end
	for _, into in ipairs({ r, r.session }) do
		if into then
			if what == "coin" then
				into.coin = (into.coin or 0) + amount
			elseif what == "item" then
				into.items = into.items or {}
				into.items[id] = (into.items[id] or 0) + amount
			else
				into.picks = (into.picks or 0) + 1
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- A pocket
-- ---------------------------------------------------------------------------

local function money()
	return type(GetMoney) == "function" and (GetMoney() or 0) or 0
end

local function itemID(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%d+)"))
end

-- the cast: the next loot window, if it comes soon, is a pocket
function M.Cast(spellID)
	local isPick = spellID == PICK_POCKET
	if not isPick and type(GetSpellInfo) == "function" then
		if not M.pickName then
			local ok, name = pcall(GetSpellInfo, PICK_POCKET)
			M.pickName = (ok and type(name) == "string") and name or "Pick Pocket"
		end
		local ok, name = pcall(GetSpellInfo, spellID)
		isPick = ok and name == M.pickName
	end
	if isPick then
		M.castAt = now()
	end
	return isPick
end

-- the loot window: a pocket if it follows the cast; what is in each slot is
-- read now, and counted only when the slot is taken
function M.Opened()
	if not (M.castAt and now() - M.castAt <= OPEN_WITHIN) then
		return false
	end
	M.castAt = nil
	local r = M.Record()
	if not r then
		return false
	end
	M.pocket = { slots = {} }
	-- and not the last pocket's closing time, or this one's coin is refused
	-- and the timer from the last one empties this one
	M.closedAt = nil
	M.purse = money()
	add(r, "pick")
	local n = type(GetNumLootItems) == "function" and GetNumLootItems() or 0
	for slot = 1, n do
		local link = type(GetLootSlotLink) == "function" and GetLootSlotLink(slot) or nil
		local id = itemID(link)
		if id then
			local quantity = 1
			if type(GetLootSlotInfo) == "function" then
				quantity = select(3, GetLootSlotInfo(slot)) or 1
			end
			M.pocket.slots[slot] = { id = id, count = tonumber(quantity) or 1 }
		end
	end
	M.Update()
	return true
end

function M.Taken(slot)
	local item = M.pocket and M.pocket.slots[slot]
	local r = M.Record()
	if item and r then
		add(r, "item", item.count, item.id)
		M.pocket.slots[slot] = nil
		M.Update()
	end
end

function M.Money()
	local open = M.pocket and (not M.closedAt or now() - M.closedAt <= LATE_MONEY)
	local purse = money()
	if open and M.purse then
		local up = purse - M.purse
		local r = M.Record()
		if up > 0 and r then
			add(r, "coin", up)
			M.Update()
		end
	end
	M.purse = purse
end

function M.Closed()
	if M.pocket then
		M.closedAt = now()
		if C_Timer and C_Timer.After then
			C_Timer.After(LATE_MONEY, function()
				if M.closedAt and now() - M.closedAt >= LATE_MONEY then
					M.pocket, M.closedAt = nil, nil
				end
			end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- The cell
-- ---------------------------------------------------------------------------

-- A READOUT (Josh 2026-09-22, the panel redesign): one cell of the grid - a
-- pouch and everything pickpocketed, as coins to the silver. This session's
-- take and the split between coin and items are on the hover.
local POUCH = "Interface\\Icons\\INV_Misc_Bag_11"

function M.Cell(r)
	local c, i = M.Worth(r or M.Record())
	return { icon = POUCH, text = BT.Coins and BT.Coins(c + i, true) or coins(c + i) }
end

function M.Update()
	if not M.chip then
		return
	end
	-- for rogues only (the grid also asks, but a cell nobody sees needs no text)
	local want = BT.Enabled("pickpocket") and BT.ClassFits(M)
	M.chip:Want(want)
	if want then
		M.chip:Set(M.Cell())
	end
end

-- the item that has fetched the most, all told: its name and how many
function M.Best(r)
	local bestID, bestWorth, bestCount
	for id, count in pairs(r and r.items or {}) do
		local worth = price(id) * count
		if not bestWorth or worth > bestWorth then
			bestID, bestWorth, bestCount = id, worth, count
		end
	end
	if not bestID then
		return nil
	end
	-- no name until the client has loaded the item: the row waits for it
	local name = U.ItemInfo(bestID)
	if type(name) ~= "string" then
		return nil
	end
	return name, bestCount
end

-- (Josh 2026-09-27, the dock's tooltips redrawn) one total, coin and loot
-- together: this session's first, with what a pocket is worth, then all time
function M.Tip()
	local r = M.Record()
	if not (r and BT.Tip) then
		return
	end
	local s = M.session
	BT.Tip.Show(M.chip, { build = function(t)
		t:Header({ icon = POUCH, name = "Pick Pocket", sub = "Coin and loot, at vendor prices" })
		local sc, si = M.Worth(s)
		local picks = s and s.picks or 0
		if picks > 0 then
			t:Headline(coins(sc + si))
			t:Note(("This session, from %d %s. %s a pocket."):format(picks, picks == 1 and "pocket" or "pockets",
				coins(math.floor((sc + si) / picks))))
		else
			t:Headline(coins(0))
			t:Note("No pockets picked this session.")
		end
		local c, i = M.Worth(r)
		if (r.picks or 0) > 0 then
			t:Section("All time")
			t:Row("Coin and loot", coins(c + i))
			t:Row("Pockets picked", r.picks)
			local name, count = M.Best(r)
			if name then
				t:Row("Best find", ("%s ×%d"):format(name, count))
			end
		end
	end })
end

function M.Build()
	if M.chip then
		return M.chip
	end
	M.chip = BT.Dock.Chip("pickpocket", "pockets", 1)
	M.chip:SetScript("OnEnter", M.Tip)
	M.chip:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.chip
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED",
	"LOOT_CLOSED", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
-- yours, not every cast by everyone in range (Josh 2026-09-23, audit)
do
	local ok = M.events.RegisterUnitEvent
		and pcall(M.events.RegisterUnitEvent, M.events, "UNIT_SPELLCAST_SUCCEEDED", "player")
	if not ok then
		pcall(M.events.RegisterEvent, M.events, "UNIT_SPELLCAST_SUCCEEDED")
	end
end
M.events:SetScript("OnEvent", function(_, event, a, b, c)
	if not (BT.Enabled("pickpocket") and BT.ClassFits(M)) then
		return
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if a == "player" then
			M.Cast(c)
		end
	elseif event == "LOOT_OPENED" then
		M.Opened()
	elseif event == "LOOT_SLOT_CLEARED" then
		M.Taken(a)
	elseif event == "LOOT_CLOSED" then
		M.Closed()
	elseif event == "PLAYER_MONEY" then
		M.Money()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		-- a price the client has just learnt - only worth a look when it is
		-- the price of something taken from a pocket (the event comes by the
		-- hundred at an auction house)
		local r = M.Record()
		local id = tonumber(a)
		if r and r.items and id and r.items[id] then
			M.Update()
			-- and the tooltip, if it is up and was waiting for this name
			if M.chip and BT.Tip and BT.Tip.IsShown() and BT.Tip.Frame().owner == M.chip then
				M.Tip()
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, a, b)
	end
end)

function M.Show(on)
	M.Build()
	if on then
		M.purse = money()
	end
	-- wanted or not by what Update finds (and only by a rogue)
	M.Update()
	BT.Dock.Relayout()
end

function M:OnEnable()
	M.Show(true)
	-- switched on mid-session (Core/Session.lua), by a rogue
	if BT.ClassFits(M) then
		BT.Session.Ensure(M)
	end
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
		"The coin you pickpocket, plus what a vendor would pay for the items.",
		"small", 0.55, 0.60, 0.58)
	note:SetPoint("TOPLEFT", 0, -2)
	note:SetWidth(520)
	note:SetJustifyH("LEFT")

	local why = BT.Widgets.Label(panel,
		"The total is all time. Point at it for this session. Only items you loot count.",
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

-- CLEARED FROM THE PAGE (Josh 2026-09-28: "We don't need hundreds of slash
-- commands"). What /bt pockets reset did, as a Reset row on the Metrics page
-- (see Gold's M.Reset).
M.resetRow = { "Pick Pocket record", "Clears what pickpocketing has been worth, all time and this session" }

function M.Reset()
	if not M.Record() then
		return
	end
	-- under the name and realm, where M.Record keeps it (the name alone,
	-- which this cleared, is always empty - Josh 2026-09-23, audit)
	for _, who in ipairs({ U.MeKey and U.MeKey(), U.Me and U.Me() }) do
		if who then
			BT.settings.pickpocket[who] = nil
		end
	end
	M.session = nil
	M.Start(true, false)
	U.Print("Pick Pocket: record cleared.")
end
