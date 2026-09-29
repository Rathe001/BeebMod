-- Your four bag slots, beside the backpack (Josh 2026-09-28: "We currently
-- have no way to replace bags on the bag bar ... Let's add the bags to the
-- inventory as you suggested").
--
-- The game's bag bar is faded away by default (Modules/Space/Space.lua), and
-- in Classic its four slots are the only place a bag is put on or taken off.
-- These four stand in for them, in a column down the left of the backpack's
-- window, and ask the game to do what its own slots do:
--
--   drag a bag onto one     PutItemInBag: it goes on, or swaps with that one
--   drag one off            PickupBagFromSlot: the bag comes onto the cursor
--   click one               the bag opens or closes (ToggleBag)
--   point at one            the bag's own tooltip
--
-- Our own buttons, not the game's four moved here: Edit Mode puts back what is
-- moved out of its bar, which is why that bar is faded rather than moved.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/BagWindow/BagSlots.lua")

local M = BT.GetModule("bagwindow")
local S = {}
M.BagSlots = S

S.BAGS = 4
S.SIZE, S.GAP, S.PAD = 30, 4, 4
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
function S.InvSlot(bag)
	local f = (C_Container and C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
	if type(f) == "function" then
		local ok, id = pcall(f, bag)
		if ok and tonumber(id) then
			return tonumber(id)
		end
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

-- the window the column goes beside: the combined backpack, or the window
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
	local has = call(tip.SetInventoryItem, tip, "player", b.inv)
	if not has then
		-- the game's own words for an empty bag slot, where it has them
		call(tip.SetText, tip, _G.EQUIP_CONTAINER or "Bag slot", 1, 1, 1)
	end
	call(tip.Show, tip)
end

-- ---------------------------------------------------------------------------
-- The column
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
	b:SetScript("OnEnter", S.Tip)
	b:SetScript("OnLeave", function()
		if _G.GameTooltip then
			call(_G.GameTooltip.Hide, _G.GameTooltip)
		end
	end)
	return b
end

function S.Build()
	if S.frame then
		return S.frame
	end
	local f = CreateFrame("Frame", "BeebModBagSlots", UIParent)
	f:SetSize(S.SIZE + S.PAD * 2, S.BAGS * S.SIZE + (S.BAGS - 1) * S.GAP + S.PAD * 2)
	f.surface = BT.Pill.Surface(f, "BACKGROUND", -8)
	f.buttons = {}
	for bag = 1, S.BAGS do
		local b = make(f, bag)
		b:SetPoint("TOP", f, "TOP", 0, -(S.PAD + (bag - 1) * (S.SIZE + S.GAP)))
		f.buttons[bag] = b
	end
	f:Hide()
	S.frame = f
	return f
end

-- every slot's picture as it stands, faded while the game holds the bag
function S.Refresh()
	local f = S.frame
	if not (f and f:IsShown()) then
		return 0
	end
	local W = BT.Widgets
	BT.Pill.PaintSurface(f.surface, f, W.FILL, W.RIM)
	BT.Pill.ShowSurface(f.surface, true)
	local n = 0
	for _, b in ipairs(f.buttons) do
		BT.Pill.PaintSurface(b.surface, b, W.FILL, W.RIM)
		BT.Pill.ShowSurface(b.surface, true)
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

-- beside the backpack while it is open, the module on and the column wanted
function S.Attach()
	local f = S.Build()
	local host = BT.Enabled("bagwindow") and S.On() and S.Host() or nil
	if not host then
		f:Hide()
		return false
	end
	f:SetParent(host)
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", host, "TOPLEFT", -4, 0)
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
