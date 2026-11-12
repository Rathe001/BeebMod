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
-- ON A RAIL WITH ROOM INSIDE IT (Josh 2026-11-07: "Can we add some padding
-- inside that rail?"). The game puts its items 4 above the money line, which
-- sits 8 up and is 13 tall, so the foot of the window is 25 tall. The rail
-- fills 4 to 24 of it. The slots are 14 so a few pixels show round them.
S.SIZE, S.GAP = 14, 3
S.LEFT, S.BOTTOM = 8, 7
S.RAIL_SIDE, S.RAIL_BOTTOM, S.RAIL_H = 4, 4, 20
local CROP = 0.08

-- always (the settings canvas, Josh 2026-10-04, cut their switch)
function S.On()
	return true
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

-- IN A FIGHT TOO (Josh 2026-10-18), as the dock's click is
-- (Modules/Bags/Bags.lua). ToggleBag has no combat check and shows only
-- plain frames.
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
	-- (secrets first: one may not be tested, see S.Picture)
	local hidID, hidLink = S.Secret(bagID), S.Secret(link)
	if hidID or hidLink or bagID ~= nil or link ~= nil then
		call(tip.SetInventoryItem, tip, "player", b.inv)
		drawn = (tonumber(call(tip.NumLines, tip)) or 0) > 0
		if not drawn then
			local plain = (not hidLink and link) or (not hidID and bagID) or nil
			local name = plain and BT.Util.ItemInfo(plain)
			call(tip.SetText, tip, type(name) == "string" and name or slot, 1, 1, 1)
			drawn = true
		end
	else
		call(tip.SetText, tip, slot, 1, 1, 1)
		call(tip.AddLine, tip, b.reagent and "Drag a reagent bag here to equip it." or "Drag a bag here to equip it.",
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

-- THE KEYRING BY TOGGLEBAG (2026-10-18). This client has no ToggleKeyRing,
-- which is Classic's; the forever branch has no Keyring.lua. The game's own
-- keyring button opens it with ToggleBag(KEYRING_CONTAINER)
-- (Blizzard_MainMenuBarBagButtons/Camelot), and so does this one, in a
-- fight too.
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
	-- OURS, SO THE WINDOW'S RESTYLE LEAVES IT BE (Josh 2026-11-05, What
	-- loaded: the pouch's slot "tex=133636 ... shown=true drawn=true a=0").
	-- The row lives in the backpack's window, and the restyle that takes the
	-- client's art off that window (Core/Furniture.lua) went through it too,
	-- each time the bags changed: it took each slot's picture for art and set
	-- it to nothing. After a /reload the row came after the restyle, which is
	-- why the picture was back until the next bag went on. A frame marked
	-- `beebs` is skipped.
	f.beebs = true
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

-- the rail the row and the coins sit on, ours (`beebs`) so the restyle
-- leaves it be
function S.Rail()
	if S.rail then
		return S.rail
	end
	local r = CreateFrame("Frame", nil, UIParent)
	r.beebs = true
	r.surface = BT.Pill.Surface(r, "BACKGROUND", -8)
	r:Hide()
	S.rail = r
	return r
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

-- THE BAG'S PICTURE, OR ITS ITEM'S (Josh 2026-11-04: "Mining bag icon is not
-- showing in the bag slots"). The slot's tooltip named the Apprentice's
-- Mining Pack, so the item was readable, but the slot stayed empty. The
-- picture is asked of the slot first, as the game's own bag bar asks it, and
-- then of the item in it.
-- A SECRET PICTURE IS STILL A PICTURE (Josh 2026-11-05: "Bag icons are still
-- not showing", a Small Blue Pouch named in its slot's tooltip, the slot
-- empty until a /reload). The client can answer with a secret value, and a
-- secret may be handed on but not tested: `if tex` on one throws, which ended
-- the row's pass before the icon was shown, with no error in sight (the
-- buffs tray hit the same on 2026-11-05). So nothing here tests a secret: a
-- plain picture is preferred, the slot's or else its item's, and a secret one
-- is handed back only when there is no plain one.
local function secret(v)
	return (issecretvalue and issecretvalue(v)) and true or false
end
S.Secret = secret

function S.Picture(inv)
	if not inv then
		return nil
	end
	local tex = call(_G.GetInventoryItemTexture, "player", inv)
	local hidden = nil
	if secret(tex) then
		hidden = tex
	elseif tex then
		return tex
	end
	local id = call(_G.GetInventoryItemID, "player", inv)
	if id ~= nil and not secret(id) then
		local icon = call(C_Item and C_Item.GetItemIconByID, id)
		if icon ~= nil and not secret(icon) then
			return icon
		end
		icon = call(_G.GetItemIcon, id)
		if icon ~= nil and not secret(icon) then
			return icon
		end
	end
	return hidden
end

-- the last few times the row looked, and what each slot got, for the record
S.LOG = 12
S.log = {}

local function note(why, bags)
	local parts = {}
	for _, b in ipairs(bags) do
		parts[#parts + 1] = ("%s=%s/%s"):format(tostring(b.inv), tostring(b.seen),
			tostring(call(b.icon.IsShown, b.icon)))
	end
	local now = tonumber(call(_G.GetTime)) or 0
	table.insert(S.log, ("%.1f %s %s"):format(now, tostring(why), table.concat(parts, " ")))
	while #S.log > S.LOG do
		table.remove(S.log, 1)
	end
end

-- every slot's picture as it stands, faded while the game holds the bag
local function refresh(why)
	local f = S.frame
	if not (f and f:IsShown()) then
		if why then
			note(tostring(why) .. "(hidden)", {})
		end
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
		local tex = S.Picture(b.inv)
		local hidden = secret(tex)
		b.seen = hidden and "secret" or tex
		local okT = pcall(b.icon.SetTexture, b.icon, tex)
		-- and seen, whatever faded it before the row was marked as ours
		b.icon:SetAlpha(1)
		-- a secret is there by being secret; only a plain one is asked
		local has = okT and (hidden or tex ~= nil)
		b.icon:SetShown(has and true or false)
		local locked = call(_G.IsInventoryItemLocked, b.inv)
		if secret(locked) then
			locked = false
		end
		if b.icon.SetDesaturated then
			b.icon:SetDesaturated(locked and true or false)
		end
		if has then
			n = n + 1
		end
	end
	note(why or "?", bags)
	return n
end

-- AND AN ERROR IS SAID (2026-11-05): the pass runs from events, where an
-- error is silent unless the game's script errors are on. One goes to the log
-- What loaded prints, on the Testing page.
function S.Refresh(why)
	local ok, r = pcall(refresh, why)
	if not ok then
		BT.Err("bagslots: " .. tostring(r))
		return 0
	end
	return r
end

-- WHAT EACH SLOT READS, FOR THE RECORD (Josh 2026-11-04: "Small brown pouch
-- icon isnt showing on the bag bar now"). The pouch's slot named it in its
-- tooltip but showed no picture, and the /run line to ask why was too long to
-- type. The bag window's record (the Testing page's Record) writes these.
local function said(v)
	if issecretvalue and issecretvalue(v) then
		return "secret"
	end
	return type(v) == "string" and ("%q"):format(v) or tostring(v)
end

function S.Dump()
	local lines = {}
	local f = S.frame
	if not f then
		lines[1] = "slots: not built"
		return lines
	end
	local parent = f:GetParent()
	lines[1] = ("slots: shown=%s parent=%s"):format(said(f:IsShown()),
		said(parent and call(parent.GetName, parent)))
	local all = {}
	for i, b in ipairs(f.buttons) do
		all[#all + 1] = { "bag" .. i, b, _G[GAME_SLOT[i]] }
	end
	all[#all + 1] = { "reagent", f.reagent, _G.CharacterReagentBag0Slot }
	for _, row in ipairs(all) do
		local name, b, game = row[1], row[2], row[3]
		local inv = b.inv
		local gameIcon = game and (game.icon or game.Icon)
		lines[#lines + 1] = ("%s: inv=%s now=%s gameID=%s tex=%s id=%s picture=%s"):format(name, said(inv),
			said(S.InvSlot(b.bag)), said(game and call(game.GetID, game)),
			said(inv and call(_G.GetInventoryItemTexture, "player", inv)),
			said(inv and call(_G.GetInventoryItemID, "player", inv)), said(S.Picture(inv)))
		lines[#lines + 1] = ("%s: icon=%s iconShown=%s iconAlpha=%s button=%s size=%s gameIcon=%s"):format(name,
			said(call(b.icon.GetTexture, b.icon)), said(b.icon:IsShown()), said(call(b.icon.GetAlpha, b.icon)),
			said(b:IsShown()), said(call(b.icon.GetWidth, b.icon)),
			said(gameIcon and call(gameIcon.GetTexture, gameIcon)))
		local l, r, t, bt = call(b.icon.GetTexCoord, b.icon)
		local cr, cg, cb, ca = call(b.icon.GetVertexColor, b.icon)
		lines[#lines + 1] = ("%s: visible=%s file=%s desat=%s coords=%s,%s,%s,%s color=%s,%s,%s,%s layer=%s points=%s"):format(
			name, said(call(b.icon.IsVisible, b.icon)), said(call(b.icon.GetTextureFileID, b.icon)),
			said(call(b.icon.IsDesaturated, b.icon)), said(l), said(r), said(t), said(bt),
			said(cr), said(cg), said(cb), said(ca), said(call(b.icon.GetDrawLayer, b.icon)),
			said(call(b.icon.GetNumPoints, b.icon)))
	end
	for _, line in ipairs(S.log) do
		lines[#lines + 1] = "looked: " .. line
	end
	return lines
end

-- the same, short enough for one line of What loaded: per slot its inventory
-- slot, what the client gives (slot picture, item, item's icon), what the row
-- chose and what the icon holds, shown and drawn; then the last three passes
S.BRIEF_PASSES = 3
function S.Brief()
	local f = S.frame
	if not f then
		return "bag slots: not built"
	end
	local parts = { ("bag slots %s"):format(f:IsShown() and "up" or "down") }
	local list = {}
	for i, b in ipairs(f.buttons) do
		list[#list + 1] = { tostring(i), b }
	end
	list[#list + 1] = { "r", f.reagent }
	for _, row in ipairs(list) do
		local b, inv = row[2], row[2].inv
		local id = inv and call(_G.GetInventoryItemID, "player", inv)
		parts[#parts + 1] = ("%s:%s tex=%s id=%s icon=%s chose=%s has=%s shown=%s drawn=%s a=%s"):format(row[1],
			said(inv), said(inv and call(_G.GetInventoryItemTexture, "player", inv)), said(id),
			said(id and not secret(id) and call(C_Item and C_Item.GetItemIconByID, id)), said(b.seen),
			said(call(b.icon.GetTexture, b.icon)), said(b.icon:IsShown()), said(call(b.icon.IsVisible, b.icon)),
			said(call(b.icon.GetAlpha, b.icon)))
	end
	for i = math.max(1, #S.log - S.BRIEF_PASSES + 1), #S.log do
		parts[#parts + 1] = "pass " .. S.log[i]
	end
	return table.concat(parts, " · ")
end

-- in the backpack while it is open, the module on and the row wanted
function S.Attach()
	local f = S.Build()
	local rail = S.Rail()
	local host = BT.Enabled("bagwindow") and S.On() and S.Host() or nil
	if not host then
		f:Hide()
		rail:Hide()
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
	-- the rail under the row and the coins: at the window's own level, so
	-- the money line (one up) and the row draw over it
	rail:SetParent(host)
	rail:ClearAllPoints()
	rail:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", S.RAIL_SIDE, S.RAIL_BOTTOM)
	rail:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -S.RAIL_SIDE, S.RAIL_BOTTOM)
	rail:SetHeight(S.RAIL_H)
	if host.GetFrameLevel and rail.SetFrameLevel then
		rail:SetFrameLevel(host:GetFrameLevel() or 1)
	end
	local W = BT.Widgets
	BT.Pill.PaintSurface(rail.surface, rail, { W.FILL[1] * 0.6, W.FILL[2] * 0.6, W.FILL[3] * 0.6, 1 }, W.RIM)
	BT.Pill.ShowSurface(rail.surface, true)
	rail:Show()
	S.Refresh("attach")
	return true
end

-- AND AGAIN A MOMENT LATER (Josh 2026-11-04: "Small brown pouch icon isnt
-- showing on the bag bar now", and after a /reload: "the bag icon appears").
-- The slot numbers and the picture were right, so the row had looked too
-- soon: a bag just put on can have no picture yet when the event comes. Each
-- change is looked at now and once more half a second later, and again when
-- the game has loaded an item's data.
S.LATER = 0.5

function S.Soon(why)
	S.Refresh(why or "soon")
	if not (S.frame and S.frame:IsShown()) then
		return
	end
	if S.waiting or not (C_Timer and C_Timer.After) then
		return
	end
	S.waiting = true
	C_Timer.After(S.LATER, function()
		S.waiting = false
		S.Refresh("later")
	end)
end

S.events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
	"ITEM_LOCK_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED", "ITEM_DATA_LOAD_RESULT",
	"GET_ITEM_INFO_RECEIVED" }) do
	pcall(S.events.RegisterEvent, S.events, event)
end
S.events:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
		return
	end
	-- NOTHING TO REDRAW WHILE THE BAGS ARE SHUT (2026-11-11, audit): the
	-- game sends hundreds of item events at login, and each one wrote a line
	-- in the log for slots nobody could see, with the module off as well.
	-- The slots are drawn when the window opens (S.Attach).
	local f = S.frame
	if not (f and f.IsVisible and f:IsVisible() and BT.Enabled("bagwindow")) then
		return
	end
	S.Soon(event)
end)
