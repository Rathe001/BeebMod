-- Your four bag slots, beside the backpack (Josh 2026-09-28: "We currently
-- have no way to replace bags on the bag bar ... Let's add the bags to the
-- inventory as you suggested").
--
-- The game's bag bar is faded away by default (Modules/Bags/Bags.lua), and
-- in Classic its four slots are the only place a bag is put on or taken off.
-- These four stand in for them, in a row across the foot of the backpack's
-- window, and ask the game to do what its own slots do:
--
--   drag a bag onto one     PutItemInBag: it goes on, or swaps with that one
--   drag one off            PickupBagFromSlot: the bag comes onto the cursor
--   click one               the bag opens or closes (ToggleBag)
--   point at one            the bag's own tooltip
--
-- AND THE REAGENT BAG AND THE KEYRING UNDER THEM (Josh 2026-09-28: "I think
-- we need a reagent bag slot and keyring right?", and then, the game's own bar
-- in the picture: "we now have 4 bag slots and a separate reagent slot").
-- This client is built on the modern one and has the reagent bag's slot (bag
-- 5) as well as Classic's keyring. The reagent slot is here where the client
-- has one, and does what a bag slot does. The keyring is here wherever the
-- game has one (its keyring button, or C_ActionBar.ShouldShowKeyring): a
-- click opens it, a key dropped on it goes in.
--
-- Our own buttons, not the game's four moved here: Edit Mode puts back what is
-- moved out of its bar, which is why that bar is faded rather than moved.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/BagWindow/BagSlots.lua")

local M = BT.GetModule("bagwindow")
local S = {}
M.BagSlots = S

S.BAGS = 4
-- IN A ROW ACROSS THE FOOT (Josh 2026-09-28: "Maybe align them horizontally
-- across the bottom left?"), in the window's own line with the money: small
-- enough for that line, and placed by its corner
S.SIZE, S.GAP = 18, 3
S.LEFT, S.BOTTOM = 8, 6
local CROP = 0.08

-- on unless switched off, on the Bag window's page
function S.On()
	return not (BT.settings and BT.settings.bagwindow and BT.settings.bagwindow.bagSlots == false)
end

function S.SetOn(on)
	BT.EnsureBound()
	BT.settings.bagwindow = BT.settings.bagwindow or {}
	-- on, the default, is not written down (`(not on) and false or nil` is nil
	-- either way, the rings switch's old trap)
	if on then
		BT.settings.bagwindow.bagSlots = nil
	else
		BT.settings.bagwindow.bagSlots = false
	end
	S.Attach()
end

-- the character's inventory slot that holds bag `bag` (1 to 4): 20 to 23 in
-- Classic, asked for where the game can say
-- THE GAME'S OWN SLOT KNOWS (Josh 2026-09-28: "I found and equipped a bag,
-- but it isn't showing"). Classic's bag slots are 20 to 23, but this client
-- is built on the modern one, where they are 31 to 34, and it did not answer
-- ContainerIDToInventoryID - so the guess read an empty slot. Each of the
-- game's own bag slot buttons carries its inventory slot as its ID, so that
-- is asked first; then the game's function, then its offset, then Classic's.
-- Asked again on every refresh, since the game's buttons may come later.
local GAME_SLOT = { "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }

function S.InvSlot(bag)
	local button = _G[GAME_SLOT[bag] or ""]
	if bag == S.REAGENT then
		button = _G.CharacterReagentBag0Slot
	end
	if type(button) == "table" and type(button.GetID) == "function" then
		local ok, id = pcall(button.GetID, button)
		if ok and tonumber(id) and tonumber(id) > 0 then
			return tonumber(id)
		end
	end
	local f = (C_Container and C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
	if type(f) == "function" then
		local ok, id = pcall(f, bag)
		if ok and tonumber(id) then
			return tonumber(id)
		end
	end
	if tonumber(_G.CONTAINER_BAG_OFFSET) then
		return tonumber(_G.CONTAINER_BAG_OFFSET) + bag
	end
	if bag == S.REAGENT then
		return nil
	end
	return 19 + bag
end

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if ok then
		return a, b, c
	end
	return nil
end

-- the window the row goes in: the combined backpack, or the window
-- showing bag 0, whichever is up
function S.Host()
	for _, w in ipairs(M.Windows()) do
		local shown = call(w.IsShown, w)
		if shown then
			if w == _G.ContainerFrameCombinedBags or call(w.GetID, w) == 0 then
				return w
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- What a slot does
-- ---------------------------------------------------------------------------

local function cursorHasItem()
	return call(_G.CursorHasItem) and true or false
end

function S.Drop(b)
	if cursorHasItem() then
		call(_G.PutItemInBag, b.inv)
		return true
	end
	return false
end

function S.Lift(b)
	call(_G.PickupBagFromSlot, b.inv)
end

function S.Click(b)
	if S.Drop(b) then
		return
	end
	call(_G.ToggleBag, b.bag)
end

function S.Tip(b)
	local tip = _G.GameTooltip
	if not tip then
		return
	end
	call(tip.SetOwner, tip, b, "ANCHOR_LEFT")
	if b.keyring then
		call(tip.SetText, tip, _G.KEYRING or "Key Ring", 1, 1, 1)
		call(tip.Show, tip)
		return
	end
	-- A TOOLTIP ON EVERY SLOT (Josh 2026-09-28: "Can you add tooltips to the
	-- bags and reagent bag as well?"). The game's words were asked for and
	-- came to nothing on this client, so nothing here leans on them: a bag is
	-- the game's own tooltip for it, or failing that its name; an empty slot
	-- says what it is and what to do with it, in our words.
	local slot = b.reagent and "Reagent bag slot" or "Bag slot"
	local bagID = call(_G.GetInventoryItemID, "player", b.inv)
	local link = call(_G.GetInventoryItemLink, "player", b.inv)
	local drawn = false
	if bagID or link then
		call(tip.SetInventoryItem, tip, "player", b.inv)
		drawn = (tonumber(call(tip.NumLines, tip)) or 0) > 0
		if not drawn then
			local name = BT.Util.ItemInfo(link or bagID)
			call(tip.SetText, tip, type(name) == "string" and name or slot, 1, 1, 1)
			drawn = true
		end
	else
		call(tip.SetText, tip, slot, 1, 1, 1)
		call(tip.AddLine, tip, b.reagent and "Drag a reagent bag here to put it on." or "Drag a bag here to put it on.",
			0.8, 0.8, 0.8, true)
		drawn = true
	end
	call(tip.Show, tip)
	return drawn
end

-- ITS SLOTS LIGHT UP (Josh 2026-09-28: "mousing over the bag in the default
-- UI highlights the bag's respective slots"). Pointing at one of these marks
-- every item slot of that bag in the open windows, as the game's own bar
-- does, and leaving it clears them. A slot says which bag it is in
-- (GetBagID), or its window does (GetID) where it cannot.
local MARK = { 0.35, 0.70, 1.00 }

local function bagOf(item)
	local id = tonumber(call(item.GetBagID, item))
	if id then
		return id
	end
	local parent = item.GetParent and item:GetParent()
	return parent and tonumber(call(parent.GetID, parent)) or nil
end

function S.Mark(bag)
	local n = 0
	for _, w in ipairs(M.Windows()) do
		for _, item in ipairs(M.Slots(w)) do
			local on = bag ~= nil and bagOf(item) == bag
			local mark = item.beebsBagMark
			if on and not mark then
				mark = { ring = BT.Pill.Ring(item, "OVERLAY", 6), fill = item:CreateTexture(nil, "OVERLAY", nil, 5) }
				mark.fill:SetAllPoints()
				mark.fill:SetColorTexture(MARK[1], MARK[2], MARK[3], 0.18)
				item.beebsBagMark = mark
			end
			if mark then
				if on then
					BT.Pill.PlaceRing(mark.ring, item, 0, 1, 0)
					BT.Pill.PaintRing(mark.ring, { MARK[1], MARK[2], MARK[3], 1 })
					n = n + 1
				else
					BT.Pill.HideRing(mark.ring)
				end
				mark.fill:SetShown(on)
			end
		end
	end
	return n
end

-- the reagent bag: its bag number, and the inventory slot that holds it where
-- this client has one (the game's own bar has CharacterReagentBag0Slot)
S.REAGENT = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
function S.ReagentSlot()
	if _G.CharacterReagentBag0Slot == nil then
		return nil
	end
	return S.InvSlot(S.REAGENT)
end

-- the keyring: whether this client has one. Its own bar shows it by default
-- (Josh 2026-09-28: "Keyring is also showing by default on the default UI"),
-- so the game's keyring button is enough; failing that, the game is asked
function S.HasKeyring()
	if _G.KeyRingButton ~= nil then
		return true
	end
	local bar = _G.C_ActionBar
	if bar and type(bar.ShouldShowKeyring) == "function" then
		return call(bar.ShouldShowKeyring) and true or false
	end
	return false
end

local KEY_ICON = "Interface\\ContainerFrame\\KeyRing-Bag-Icon"

function S.KeyClick()
	if cursorHasItem() then
		call(_G.PutKeyInKeyRing)
		return
	end
	if type(_G.ToggleKeyRing) == "function" then
		call(_G.ToggleKeyRing)
	else
		call(_G.ToggleBag, _G.KEYRING_CONTAINER or -2)
	end
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

local function make(parent, bag)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(S.SIZE, S.SIZE)
	b.bag, b.inv = bag, S.InvSlot(bag)
	b.surface = BT.Pill.Surface(b, "BACKGROUND", -8)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	b.hover = b:CreateTexture(nil, "HIGHLIGHT")
	b.hover:SetAllPoints()
	b.hover:SetColorTexture(1, 1, 1, 0.12)
	if b.RegisterForDrag then
		b:RegisterForDrag("LeftButton")
	end
	if b.RegisterForClicks then
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	b:SetScript("OnClick", S.Click)
	b:SetScript("OnReceiveDrag", S.Drop)
	b:SetScript("OnDragStart", S.Lift)
	b:SetScript("OnEnter", function(self)
		S.Tip(self)
		S.Mark(self.bag)
	end)
	b:SetScript("OnLeave", function()
		if _G.GameTooltip then
			call(_G.GameTooltip.Hide, _G.GameTooltip)
		end
		S.Mark(nil)
	end)
	return b
end

function S.Build()
	if S.frame then
		return S.frame
	end
	local f = CreateFrame("Frame", "BeebModBagSlots", UIParent)
	f.buttons = {}
	for bag = 1, S.BAGS do
		f.buttons[bag] = make(f, bag)
	end
	-- the reagent bag's slot, under the four
	local reagent = make(f, S.REAGENT)
	reagent.reagent = true
	f.reagent = reagent
	-- the keyring, a slot under the bags, with a key for its picture
	local key = make(f, 0)
	-- no bag of its own in the windows, so nothing to light up
	key.keyring, key.inv, key.bag = true, nil, nil
	key:SetScript("OnClick", S.KeyClick)
	key:SetScript("OnReceiveDrag", S.KeyClick)
	key:SetScript("OnDragStart", nil)
	key.icon:SetTexture(KEY_ICON)
	key.icon:SetTexCoord(0, 1, 0, 1)
	f.key = key
	f:Hide()
	S.frame = f
	return f
end

-- the slots it shows, left to right, and the row as wide as they are
local function fit(f, reagentInv, keyring)
	f.reagent.inv = reagentInv
	f.reagent:SetShown(reagentInv ~= nil)
	f.key:SetShown(keyring)
	local shown = {}
	for _, b in ipairs(f.buttons) do
		shown[#shown + 1] = b
	end
	if reagentInv then
		shown[#shown + 1] = f.reagent
	end
	if keyring then
		shown[#shown + 1] = f.key
	end
	for i, b in ipairs(shown) do
		b:ClearAllPoints()
		b:SetPoint("LEFT", f, "LEFT", (i - 1) * (S.SIZE + S.GAP), 0)
	end
	local n = #shown
	f:SetSize(n * S.SIZE + (n - 1) * S.GAP, S.SIZE)
	return shown
end

-- every slot's picture as it stands, faded while the game holds the bag
function S.Refresh()
	local f = S.frame
	if not (f and f:IsShown()) then
		return 0
	end
	local W = BT.Widgets
	local shown = fit(f, S.ReagentSlot(), S.HasKeyring())
	local n = 0
	for _, b in ipairs(shown) do
		BT.Pill.PaintSurface(b.surface, b, W.FILL, W.RIM)
		BT.Pill.ShowSurface(b.surface, true)
	end
	local bags = {}
	for _, b in ipairs(f.buttons) do
		b.inv = S.InvSlot(b.bag)
		bags[#bags + 1] = b
	end
	if f.reagent.inv then
		bags[#bags + 1] = f.reagent
	end
	for _, b in ipairs(bags) do
		local tex = call(_G.GetInventoryItemTexture, "player", b.inv)
		b.icon:SetTexture(tex)
		b.icon:SetShown(tex ~= nil)
		local locked = call(_G.IsInventoryItemLocked, b.inv)
		if b.icon.SetDesaturated then
			b.icon:SetDesaturated(locked and true or false)
		end
		if tex then
			n = n + 1
		end
	end
	return n
end

-- in the backpack while it is open, the module on and the row wanted
function S.Attach()
	local f = S.Build()
	local host = BT.Enabled("bagwindow") and S.On() and S.Host() or nil
	if not host then
		f:Hide()
		return false
	end
	f:SetParent(host)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", S.LEFT, S.BOTTOM)
	-- over the window's own pieces, not under them
	if host.GetFrameLevel and f.SetFrameLevel then
		f:SetFrameLevel((host:GetFrameLevel() or 1) + 5)
	end
	f:Show()
	S.Refresh()
	return true
end

S.events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
	"ITEM_LOCK_CHANGED", "PLAYER_ENTERING_WORLD" }) do
	pcall(S.events.RegisterEvent, S.events, event)
end
S.events:SetScript("OnEvent", function()
	if S.frame and S.frame:IsShown() then
		S.Refresh()
	end
end)
