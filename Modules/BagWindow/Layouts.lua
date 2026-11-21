-- The bags by category, and the switch between layouts (Josh 2026-11-21).
--
-- "How difficult would it be to arrange the BeebMod bag so it uses
-- categories?" Board A of the bag categories canvas, Shelves: each category
-- is a row, its name and count in a column at the left and its items to the
-- right, a category a row. Empty slots are not drawn: a line at the foot
-- says how many are free.
--
-- THE GAME'S OWN SLOTS, MOVED. Nothing is made: every item is still the
-- game's slot, so a click uses, a drag moves and a right-click sells as
-- before. Only where each slot sits is ours. The probe (Probe.lua) found the
-- slots are not protected: all 68 moved in a fight and out of one, went back
-- after the game laid them out again, and no action was blocked.
--
-- A LAYOUT IS AN ENTRY IN A LIST (Josh: "let's set this up so it facilitates
-- future layout updates"). M.Layouts holds each by its key, and M.LAYOUT_ORDER
-- is the order of their buttons in the window's title. An entry has a title,
-- `icon` (the bars of its button's picture) and `arrange(items, empties,
-- opts)`, which says where everything goes and touches no frame:
--
--   { width, height,            the room the items need, under the search
--     places = { { slot, x, y } },     from that room's top left corner
--     labels = { { x, y, w, name, sub, ink } },
--     free = { x, y } }         where the empty slots are stacked
--
-- An entry with no `arrange` is the game's own layout ("grid"): every slot
-- goes back where the game put it. Categories are worked out once, by
-- M.Categorize, whichever layout draws them.
--
-- A SWITCH ON THE WINDOW (Josh: "I'm not sure all players will like this
-- update, and dont want to make them dig through settings"): one button a
-- layout, in the title, and the choice is kept. Shelves is the default, so
-- the new layout is seen.
--
-- ONLY THE COMBINED BACKPACK. A window a bag keeps the game's layout, and so
-- does controller mode, whose D-pad walks the game's own grid.
local _, BT = ...
local CreateFrame, C_Timer, hooksecurefunc = BT.Cpu.For("Modules/BagWindow/Layouts.lua")

local U = BT.Util
local M = BT.GetModule("bagwindow")
local L = {}
M.Shelves = L

M.DEFAULT_LAYOUT = "shelves"
M.LAYOUT_ORDER = { "shelves", "grid" }
M.Layouts = {}

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

-- the shelves, top to bottom. `ink` names one of the inks below.
M.CATEGORIES = {
	{ key = "new", name = "New", ink = "accent" },
	{ key = "quest", name = "Quest", ink = "gold" },
	{ key = "gear", name = "Gear" },
	{ key = "consumable", name = "Consumables" },
	{ key = "crafting", name = "Crafting" },
	{ key = "ammo", name = "Ammo" },
	{ key = "shards", name = "Shards" },
	{ key = "junk", name = "Junk", ink = "quiet" },
	{ key = "other", name = "Other" },
}

-- the game's item classes (Enum.ItemClass)
local CLASS = {
	[0] = "consumable",
	[2] = "gear", [4] = "gear",
	[3] = "crafting", [5] = "crafting", [7] = "crafting", [9] = "crafting",
	[6] = "ammo", [11] = "ammo",
	[12] = "quest",
}
local SOUL_SHARD = 6265

local function plain(v)
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return v
end

-- [item's number] = { class, price, bind }, once the game has told all three
M.itemFacts = {}

-- What is in a slot: { id, quality, count, class, quest, new, price }, or nil
-- for an empty one.
function M.ItemIn(bag, index)
	local c = rawget(_G, "C_Container")
	if not (c and c.GetContainerItemInfo and bag and index) then
		return nil
	end
	local ok, info = pcall(c.GetContainerItemInfo, bag, index)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local id = plain(info.itemID)
	if type(id) ~= "number" then
		return nil
	end
	local item = { id = id, quality = tonumber(plain(info.quality)) or 1, count = tonumber(plain(info.stackCount)) or 1 }
	-- bound to you already (the search's "soulbound", Search.lua)
	item.bound = plain(info.isBound) == true
	-- WHAT AN ITEM ALWAYS IS, ASKED ONCE: its class, its worth and how it
	-- binds are the same for every one of that item, so they are kept by the
	-- item's number once the game has them all. Each opening of the bags
	-- asked them again of every slot.
	local known = M.itemFacts[id]
	if known then
		item.class, item.price, item.bind = known.class, known.price, known.bind
	end
	local instant = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
	if instant and not known then
		local okI, _, _, _, _, _, class = pcall(instant, id)
		item.class = okI and tonumber(plain(class)) or nil
	end
	if c.GetContainerItemQuestInfo then
		local okQ, q = pcall(c.GetContainerItemQuestInfo, bag, index)
		if okQ and type(q) == "table" then
			item.quest = (plain(q.isQuestItem) or plain(q.questID)) and true or false
		end
	end
	-- the equipment set it belongs to, the first where it is in several
	if c.GetContainerItemEquipmentSetInfo then
		local okS, inSet, names = pcall(c.GetContainerItemEquipmentSetInfo, bag, index)
		names = okS and plain(inSet) == true and plain(names) or nil
		if type(names) == "string" and names ~= "" then
			item.set = names:match("^%s*([^,]+)") or names
			item.set = item.set:match("^(.-)%s*$")
		end
	end
	local fresh = rawget(_G, "C_NewItems")
	if fresh and fresh.IsNewItem then
		local okN, isNew = pcall(fresh.IsNewItem, bag, index)
		item.new = okN and plain(isNew) == true
	end
	local full = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
	if full and not known then
		local got = { pcall(full, id) }
		-- the game has not loaded this item yet: asked again when it has
		if not (got[1] and got[2] ~= nil) then
			item.waiting = true
		end
		item.price = got[1] and tonumber(plain(got[12])) or nil
		-- how it binds: 1 when picked up, 2 when equipped, 3 when used
		item.bind = got[1] and tonumber(plain(got[15])) or nil
		if not item.waiting and item.class then
			M.itemFacts[id] = { class = item.class, price = item.price, bind = item.bind }
		end
	end
	return item
end

-- which shelf an item goes on
function M.CategoryOf(item)
	if item.new then
		return "new"
	elseif item.quest or item.class == 12 then
		return "quest"
	elseif item.id == SOUL_SHARD then
		return "shards"
	elseif item.quality == 0 then
		return "junk"
	end
	return CLASS[item.class or -1] or "other"
end

-- ONLY THE SLOTS THAT HOLD ITEMS (Josh 2026-11-21, a bag's own button on the
-- square for dropping: "im no longer able to drop stacks on the icon"). The
-- combined backpack has seven more buttons that look like slots, one for each
-- bag: the game's bag buttons, which it keeps on the window for a controller.
-- M.Slots finds them with the rest, by their look, so the bag window can
-- dress them. They hold no item, so the layout took them for empty slots: it
-- counted 69 slots where the dock counted 62, and stacked them on the square
-- with the true empty ones. One on top took the drop for its bag. The game
-- keeps its item slots in the window's own list, and that is what is laid out.
function M.ItemSlots(w)
	if type(w) == "table" and type(w.Items) == "table" then
		local out = {}
		for _, slot in pairs(w.Items) do
			if type(slot) == "table" and slot.GetBagID and slot.SetPoint then
				out[#out + 1] = slot
			end
		end
		if #out > 0 then
			return out
		end
	end
	return M.Slots(w)
end

-- The slots of a window as items by shelf, and its empty slots. An item is
-- { slot, cat, id, quality, count, price, bag, index }.
function M.Categorize(slots)
	local items, empties = {}, {}
	for _, slot in ipairs(slots) do
		local bag = slot.GetBagID and slot:GetBagID() or nil
		local index = slot.GetID and slot:GetID() or nil
		local item = M.ItemIn(bag, index)
		if item then
			item.slot, item.bag, item.index = slot, bag or 0, index or 0
			item.cat = M.CategoryOf(item)
			items[#items + 1] = item
		else
			empties[#empties + 1] = slot
		end
	end
	-- the best first, then like with like, then where it lies in the bags
	table.sort(items, function(a, b)
		if a.quality ~= b.quality then
			return a.quality > b.quality
		elseif a.id ~= b.id then
			return a.id < b.id
		elseif a.bag ~= b.bag then
			return a.bag < b.bag
		end
		return a.index < b.index
	end)
	-- whether any item's worth and binding are still to come (L.events)
	M.itemsWaiting = false
	for _, item in ipairs(items) do
		if item.waiting then
			M.itemsWaiting = true
			break
		end
	end
	return items, empties
end

-- ---------------------------------------------------------------------------
-- Shelves
-- ---------------------------------------------------------------------------

L.COLS = 11 -- items across a full shelf
L.MAX_COLS = 18 -- and at most, for bags too full to fit the screen
-- SMALLER THAN THE GAME DRAWS THEM (Josh 2026-11-21: "I think we can reduce
-- the size of all item icons as well - that should save some space"): each
-- slot at this share of its size, its count and its ring with it
L.SCALE = 0.84
L.NAME_H, L.SUB_H = 14, 12 -- a shelf's name, and each line under it
L.HEAD_H = 13 -- a group's heading, over its items
L.HEAD_CHAR = 6 -- about what one letter of a heading takes
L.GROUP_GAP = 14 -- between two groups on a row
L.CARET = 9 -- the arrow before a shelf's name
-- (wide enough for CONSUMABLES, which was cut short at 86: Josh's first
-- screenshot, 2026-11-21)
-- (112 since the arrow before the name took 13 of it and cut the word again)
L.LABEL = 112 -- the column a shelf's name sits in
L.GAP = 4 -- between two items
L.LABEL_GAP = 10 -- between the name and the items
L.PAD_Y = 9 -- above and under a shelf's items
L.FOLD_PAD = 5 -- and above and under a row of folded shelves
L.FREE_GAP = 8 -- between the last shelf and the line of free slots
L.FREE_H = 14 -- that line

local function rowsFor(n, cols)
	return math.max(1, math.ceil(n / cols))
end

-- Board A. `opts.size` is a slot's side as drawn, `opts.cols` how many go
-- across a full shelf (L.COLS), and `opts.folded[key]` a shelf shut.
--
-- A FOLDED SHELF IS ITS NAME AND NOTHING ELSE (Josh 2026-11-21: "it doesn't
-- hide the first item"). Its slots are listed in `hidden`, and the window
-- puts them out of sight. An arrow before each name says which way it is.
--
-- GROUPS INSIDE A SHELF (Josh, the same day: "I'd like equipment set names to
-- show up under Gear"). A shelf's items may come in groups, each under a small
-- heading: Gear by equipment set, with the rest under "No set". Groups run
-- along the row and start a new one when the next won't fit. L.GroupsOf says
-- which shelves have them, so another shelf can be given groups there.
function L.GroupsOf(shelf)
	if shelf.cat.key ~= "gear" then
		return { { items = shelf.items } }
	end
	local bySet, names, rest = {}, {}, {}
	for _, item in ipairs(shelf.items) do
		if item.set then
			if not bySet[item.set] then
				bySet[item.set] = {}
				names[#names + 1] = item.set
			end
			table.insert(bySet[item.set], item)
		else
			rest[#rest + 1] = item
		end
	end
	if #names == 0 then
		return { { items = shelf.items } }
	end
	table.sort(names)
	local groups = {}
	for _, name in ipairs(names) do
		groups[#groups + 1] = { head = name, items = bySet[name] }
	end
	if #rest > 0 then
		groups[#groups + 1] = { head = "No set", items = rest }
	end
	return groups
end

local function shelves(items, empties, opts)
	local size = opts.size or 37
	local cols = opts.cols or L.COLS
	local folded = opts.folded or {}
	local step = size + L.GAP
	local fullW = L.LABEL + L.LABEL_GAP + cols * step - L.GAP
	local byCat = {}
	for _, item in ipairs(items) do
		byCat[item.cat] = byCat[item.cat] or {}
		table.insert(byCat[item.cat], item)
	end
	local list = {}
	for _, cat in ipairs(M.CATEGORIES) do
		if byCat[cat.key] then
			list[#list + 1] = { cat = cat, items = byCat[cat.key], folded = folded[cat.key] and true or false }
		end
	end
	local out = { width = fullW, cols = cols, places = {}, labels = {}, heads = {}, hidden = {} }
	local y = 0
	-- the room above and under the row being drawn: less for a row with
	-- nothing on it but folded shelves
	local pad = L.PAD_Y
	-- one shelf drawn from `x`, `across` items to a row; how tall it came out
	local function draw(shelf, x, across, w)
		local n = #shelf.items
		local sub, lines = n == 1 and "1 item" or ("%d items"):format(n), 1
		if shelf.cat.key == "junk" then
			local worth = 0
			for _, item in ipairs(shelf.items) do
				worth = worth + (item.price or 0) * item.count
			end
			if worth > 0 and BT.Coins then
				sub, lines = sub .. "\n" .. BT.Coins(worth, true), 2
			end
		end
		local labelH = L.NAME_H + L.SUB_H * lines
		-- ONE LINE WHEN FOLDED (Josh 2026-11-21: "Collapsing the categories
		-- doesnt seem to save any space"): the count and the worth go after
		-- the name, on its line, and the row is as tall as that line
		if shelf.folded then
			sub = sub:gsub("\n", "  ·  ")
		end
		out.labels[#out.labels + 1] = { key = shelf.cat.key, x = x, y = y, w = w, name = shelf.cat.name, sub = sub,
			ink = shelf.cat.ink, folded = shelf.folded, pad = pad }
		if shelf.folded then
			for _, item in ipairs(shelf.items) do
				out.hidden[#out.hidden + 1] = item.slot
			end
			return L.NAME_H
		end
		local left, top = x + L.LABEL + L.LABEL_GAP, y + pad
		local areaW = across * step - L.GAP
		local groups = L.GroupsOf(shelf)
		local headH = groups[1].head and L.HEAD_H or 0
		local cx, cy, lineRows = 0, 0, 0
		local function newLine()
			cy = cy + headH + lineRows * step
			cx, lineRows = 0, 0
		end
		for _, g in ipairs(groups) do
			local count = #g.items
			local gw = math.min(count, across) * step - L.GAP
			-- room for its heading too, so two headings don't run together
			if g.head then
				gw = math.max(gw, #g.head * L.HEAD_CHAR)
			end
			if cx > 0 and cx + gw > areaW then
				newLine()
			end
			if g.head then
				out.heads[#out.heads + 1] = { x = left + cx, y = top + cy, text = g.head }
			end
			for i, item in ipairs(g.items) do
				local col, row = (i - 1) % across, math.floor((i - 1) / across)
				out.places[#out.places + 1] = { slot = item.slot, x = left + cx + col * step,
					y = top + cy + headH + row * step }
			end
			local rows = cx == 0 and rowsFor(count, across) or 1
			lineRows = math.max(lineRows, rows)
			if rows > 1 then
				newLine()
			else
				cx = cx + gw + L.GROUP_GAP
			end
		end
		if lineRows > 0 then
			newLine()
		end
		return math.max(cy - L.GAP, labelH)
	end
	-- A SHELF A ROW, ALWAYS (Josh 2026-11-21: "we should always keep the
	-- categories as a full width row. It's a bit confusing having some as 50%
	-- width"). Two short shelves shared a row until then.
	for _, shelf in ipairs(list) do
		pad = shelf.folded and L.FOLD_PAD or L.PAD_Y
		y = y + pad * 2 + draw(shelf, 0, cols, fullW)
	end
	-- the line that says how many slots are free
	out.free = { x = 0, y = y + L.FREE_GAP, n = #empties, of = #empties + #items }
	out.height = y + L.FREE_GAP + L.FREE_H
	return out
end

M.Layouts.shelves = {
	key = "shelves",
	title = "Categories",
	-- three lines, each a short bar and a long one
	icon = { { 0, 1, 3, 2 }, { 5, 1, 9, 2 }, { 0, 6, 3, 2 }, { 5, 6, 9, 2 }, { 0, 11, 3, 2 }, { 5, 11, 9, 2 } },
	arrange = shelves,
}
M.Layouts.grid = {
	key = "grid",
	title = "Grid",
	-- four squares
	icon = { { 1, 1, 5, 5 }, { 8, 1, 5, 5 }, { 1, 8, 5, 5 }, { 8, 8, 5, 5 } },
}

-- ---------------------------------------------------------------------------
-- Which layout
-- ---------------------------------------------------------------------------

local function store()
	if not BT.settings then
		return nil
	end
	BT.settings.bagwindow = BT.settings.bagwindow or {}
	return BT.settings.bagwindow
end

function M.Layout()
	local s = store()
	local key = s and s.layout or M.DEFAULT_LAYOUT
	return M.Layouts[key] and key or M.DEFAULT_LAYOUT
end

function M.SetLayout(key)
	local s = store()
	if not (s and M.Layouts[key]) then
		return M.Layout()
	end
	s.layout = key ~= M.DEFAULT_LAYOUT and key or nil
	L.Apply()
	return key
end

local function window()
	local w = rawget(_G, "ContainerFrameCombinedBags")
	return type(w) == "table" and w or nil
end

local function gamepad()
	local input = rawget(_G, "InputUtil")
	if not (input and input.IsGamepadUIEnabled) then
		return false
	end
	local ok, on = pcall(input.IsGamepadUIEnabled)
	return ok and on == true
end

-- FOLDED SHELVES. Junk is folded until you unfold it; any other is open until
-- you fold it. A click on a shelf's name does either, and it is kept.
function M.ShelfFolded(key)
	local s = store()
	local v = nil
	if s and type(s.folded) == "table" then
		v = s.folded[key]
	end
	if v == nil then
		return key == "junk"
	end
	return v and true or false
end

function M.FoldShelf(key, fold)
	local s = store()
	if not s then
		return false
	end
	s.folded = type(s.folded) == "table" and s.folded or {}
	if fold == nil then
		fold = not M.ShelfFolded(key)
	end
	s.folded[key] = fold and true or false
	L.Soon()
	return s.folded[key]
end

local function atVendor()
	local m = rawget(_G, "MerchantFrame")
	return type(m) == "table" and m.IsShown and m:IsShown() and true or false
end

-- which shelves are drawn folded now: none at a vendor, where junk is sold
function L.Folded()
	local out = {}
	if atVendor() then
		return out
	end
	for _, cat in ipairs(M.CATEGORIES) do
		if M.ShelfFolded(cat.key) then
			out[cat.key] = true
		end
	end
	return out
end

-- the layout that places the slots now, or nil for the game's own
function L.Active()
	if not BT.Enabled("bagwindow") or gamepad() then
		return nil
	end
	local layout = M.Layouts[M.Layout()]
	return layout and layout.arrange and layout or nil
end

-- ---------------------------------------------------------------------------
-- Putting it on the window
-- ---------------------------------------------------------------------------

L.TOP = 64 -- under the title and the search
L.SIDE = 12
L.FOOT = 30 -- the money line and the bag slots' rail
L.MIN_W = 300
L.MAX_SHARE = 0.8 -- of the screen's height, at most
L.BAR_W, L.BAR_H = 120, 4 -- how full the bags are, beside the free square

-- [slot] = the points the game gave it; the game's size for the window
L.home = {}
-- [slot] = the scale the game had it at
L.homeScale = {}
L.labels = {}
L.heads = {}
L.AWAY = 20000 -- how far off a folded shelf's slots are put

local INK = {
	accent = function() return BT.Widgets.ACCENT end,
	gold = function() return { 0.90, 0.76, 0.31 } end,
	quiet = function() return BT.TEXT.quiet end,
}

local function points(f)
	local out = {}
	for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do
		out[i] = { f:GetPoint(i) }
	end
	return out
end

local function put(f, pts)
	return pcall(function()
		f:ClearAllPoints()
		for _, p in ipairs(pts) do
			f:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end)
end

-- where the game has its slots and its window now: taken before anything of
-- ours moves them, and again each time the game lays them out
function L.Remember(w, again)
	-- (this window's own, not every window's: the reagent bag's slots are
	-- kept here too, and its game layout comes at another time)
	if again then
		for _, slot in ipairs(M.ItemSlots(w)) do
			L.home[slot] = nil
		end
	end
	for _, slot in ipairs(M.ItemSlots(w)) do
		if not L.home[slot] then
			L.home[slot] = points(slot)
		end
	end
	if w == window() and not L.gameSize and not L.sized then
		local width, height = w:GetSize()
		width, height = BT.Pill.Number(width, 0), BT.Pill.Number(height, 0)
		if width > 0 and height > 0 then
			L.gameSize = { width, height }
		end
	end
end

local function canvas(w)
	if L.canvas then
		return L.canvas
	end
	local c = CreateFrame("Frame", nil, w)
	c.beebs = true
	c:EnableMouse(false)
	L.canvas = c
	-- the free square's line
	c.free = c:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(c.free, "text", 11, "")
	c.freeBack = c:CreateTexture(nil, "BACKGROUND")
	c.freeBack:SetTexture("Interface\\Buttons\\WHITE8X8")
	c.barBack = c:CreateTexture(nil, "BACKGROUND")
	c.barBack:SetTexture("Interface\\Buttons\\WHITE8X8")
	c.bar = c:CreateTexture(nil, "ARTWORK")
	c.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
	return c
end

local function label(c, i)
	local l = L.labels[i]
	if l then
		return l
	end
	l = {}
	l.rule = c:CreateTexture(nil, "BACKGROUND")
	l.rule:SetTexture("Interface\\Buttons\\WHITE8X8")
	l.name = c:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(l.name, "name", 11, "")
	l.name:SetJustifyH("LEFT")
	l.name:SetWordWrap(false)
	l.sub = c:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(l.sub, "text", 10, "")
	l.sub:SetJustifyH("LEFT")
	l.sub:SetJustifyV("TOP")
	-- the arrow before the name: down for a shelf that is open, across for
	-- one that is folded (the game's own menu arrow, turned)
	l.caret = c:CreateTexture(nil, "OVERLAY")
	l.caret:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	-- the name takes a click: fold, or unfold
	l.hit = CreateFrame("Button", nil, c)
	l.hit.beebs = true
	l.hit:SetScript("OnClick", function(self)
		if self.key then
			-- (not at a vendor, where every shelf is open whatever is kept:
			-- the click changed nothing in sight and turned the kept answer
			-- over. Review, 2026-11-21)
			if not next(L.Folded()) and M.ShelfFolded(self.key) then
				return
			end
			M.FoldShelf(self.key)
		end
	end)
	l.hit:SetScript("OnEnter", function(self)
		if GameTooltip and self.key then
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:SetText(M.ShelfFolded(self.key) and "Click: unfold" or "Click: fold")
			GameTooltip:Show()
		end
	end)
	l.hit:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	L.labels[i] = l
	return l
end

-- THE SEARCH AS WIDE AS THE SHELVES (Josh's first screenshot, 2026-11-21: the
-- game's field stayed 330 wide and 62 in, on a window half as wide again). It
-- starts at the shelves' left edge and stops short of the game's sort button.
-- Where the game had it is kept, and put back with the grid.
L.SEARCH_Y = 37
L.SORT_ROOM = 34

local function searchBox(w)
	local box = w.SearchBox or rawget(_G, "BagItemSearchBox")
	return type(box) == "table" and box.SetWidth and box or nil
end

function L.FitSearch(w, width)
	local box = searchBox(w)
	if not box then
		return false
	end
	if not L.searchHome then
		L.searchHome = { points = points(box), width = BT.Pill.Number(box:GetWidth(), 0) }
	end
	local sort = rawget(_G, "BagItemAutoSortButton")
	local room = (type(sort) == "table" and sort.IsShown and sort:IsShown()) and L.SORT_ROOM or 0
	put(box, { { "TOPLEFT", w, "TOPLEFT", L.SIDE + 4, -L.SEARCH_Y } })
	pcall(box.SetWidth, box, math.max(120, width - L.SIDE * 2 - 4 - room))
	return true
end

function L.FreeSearch(w)
	local box, home = searchBox(w), L.searchHome
	L.searchHome = nil
	if not (box and home) then
		return false
	end
	put(box, home.points)
	if home.width > 0 then
		pcall(box.SetWidth, box, home.width)
	end
	return true
end

-- THE DOCK'S COUNT, NOT THE WINDOW'S (Josh 2026-11-21: "The dock says I have
-- 62 slots, but the bags says I have 69 slots"). The window also holds the
-- slots of a bag that takes only certain things, a reagent bag or a
-- profession's. The dock counts those apart (Modules/Bags/Bags.lua, M.Bags),
-- and so does this line: ordinary bags first, then the others as "Reagents".
-- `items` and `empties` are the window's own counts, used where the dock's
-- can't be read. Returns used, total, and the special bags' used and total.
function M.BagCounts(items, empties)
	local bags = BT.GetModule("bags")
	local ok, got = pcall(function() return bags and bags.Bags and bags.Bags() end)
	if ok and type(got) == "table" and type(got.bags) == "table" and (got.bags.total or 0) > 0 then
		local r = type(got.reagents) == "table" and got.reagents or {}
		return got.bags.used or 0, got.bags.total, r.used or 0, r.total or 0
	end
	return items, items + empties, 0, 0
end

function M.FreeWords(items, empties)
	local used, total, rUsed, rTotal = M.BagCounts(items, empties)
	local free = total - used
	local words = ("%s  ·  %d/%d"):format(free <= 0 and "Bags full" or ("%d free"):format(free), used, total)
	if rTotal > 0 then
		words = words .. ("  ·  Reagents %d/%d"):format(rUsed, rTotal)
	end
	return words
end

-- THE REAGENT BAG ON THE SHELVES TOO (Josh 2026-11-21, the Linen Reagent Bag
-- in a window of its own next to the shelves: "Can we combine the reagent bags
-- into the main bag?"). The game keeps the reagent bag in its own window
-- however the backpack is set. In the category layout its items go on the
-- shelves with the rest, each still the game's own slot.
--
-- ITS WINDOW IS PUT OUT OF SIGHT, NOT HIDDEN. A slot is drawn only while its
-- window is shown, so the window stays shown and is moved off the screen. It
-- is lifted a layer above the backpack, so its slots draw over the shelves
-- and not under them. Where the game had it, and its layer, are kept and put
-- back with the grid. The bag window's own placing leaves it alone meanwhile
-- (M.ApplyPosition).
local function reagentBagIndex()
	return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or nil
end

-- the reagent bag's window, while it is shown
function L.Reagents()
	local index = reagentBagIndex()
	if not index then
		return nil
	end
	local combined = window()
	for _, w in ipairs(M.Windows()) do
		if w ~= combined and w.IsShown and w:IsShown() and type(w.GetBagID) == "function" then
			local ok, bag = pcall(w.GetBagID, w)
			if ok and plain(bag) == index then
				return w
			end
		end
	end
	return nil
end

-- FOR WHAT LOADED (Josh 2026-11-21, a screenshot of the shelves with the
-- reagent bag's six items on none of them and its window nowhere in sight).
-- Every bag window the game has that could be the reagent bag's: its name,
-- the bag it says it is, whether it is shown, how many slots it lists and
-- how many are shown, and its layer. Then what the layout did with it.
function L.Said()
	local index = reagentBagIndex()
	local parts = { ("reagent bag index %s"):format(tostring(index)) }
	local combined = window()
	for _, w in ipairs(M.Windows()) do
		if w ~= combined then
			local name = BT.Furniture.Call(w, "GetName") or "?"
			local okB, bag = pcall(function() return w.GetBagID and w:GetBagID() end)
			local okI, id = pcall(function() return w.GetID and w:GetID() end)
			local shown = w.IsShown and w:IsShown() and true or false
			-- only the ones that are up, or say they are the reagent bag
			if shown or (okB and plain(bag) == index) or (okI and plain(id) == index) then
				local listed, up = 0, 0
				for _, slot in ipairs(M.ItemSlots(w)) do
					listed = listed + 1
					if slot.IsShown and slot:IsShown() then
						up = up + 1
					end
				end
				parts[#parts + 1] = ("%s bag=%s id=%s shown=%s slots=%d up=%d strata=%s items=%s"):format(name,
					tostring(okB and plain(bag)), tostring(okI and plain(id)), tostring(shown), listed, up,
					tostring(w.GetFrameStrata and w:GetFrameStrata()), type(w.Items))
			end
		end
	end
	parts[#parts + 1] = ("merged=%s layout=%s drawn=%s"):format(
		L.merged and (BT.Furniture.Call(L.merged, "GetName") or "yes") or "no", tostring(M.Layout()), tostring(L.drawn))
	return "reagents: " .. table.concat(parts, " · ")
end

-- OPENED WITH THE BACKPACK (What loaded, 2026-11-21: "merged=no", and no
-- reagent window listed). The B key opens the backpack and leaves the reagent
-- bag shut on this client: it was open in Josh's screenshot only because he
-- had clicked its icon. With no window shown its slots are not drawn, so
-- there was nothing to put on the shelves. In the category layout the
-- reagent bag is opened a frame after the backpack, the way a click on its
-- icon in the row at the foot opens it (BagSlots.lua), and shut again with
-- the backpack. In a fight too: the game's OpenBag has no check for one.
function L.OpenReagents()
	local index = reagentBagIndex()
	if not index or L.Reagents() then
		return false
	end
	local c = rawget(_G, "C_Container")
	local count = (c and c.GetContainerNumSlots) or rawget(_G, "GetContainerNumSlots")
	local okN, n = pcall(function() return count and count(index) end)
	if not (okN and (tonumber(plain(n)) or 0) > 0) then
		return false -- no reagent bag worn
	end
	local open = rawget(_G, "OpenBag")
	if type(open) ~= "function" then
		return false
	end
	if M.NoteOpen then
		pcall(M.NoteOpen, "slot")
	end
	pcall(open, index)
	L.openedReagents = L.Reagents() ~= nil
	return L.openedReagents
end

function L.CloseReagents()
	if not L.openedReagents then
		return false
	end
	L.openedReagents = nil
	L.Unmerge()
	local index, close = reagentBagIndex(), rawget(_G, "CloseBag")
	if index and type(close) == "function" then
		pcall(close, index)
	end
	return true
end

function L.Merge(r)
	if L.merged ~= r then
		L.Unmerge()
		L.merged = r
		L.mergedHome = { points = points(r), strata = r.GetFrameStrata and r:GetFrameStrata() or nil,
			clamped = r.IsClampedToScreen and r:IsClampedToScreen() or nil }
	end
	if r.SetClampedToScreen then
		pcall(r.SetClampedToScreen, r, false)
	end
	if r.SetFrameStrata then
		pcall(r.SetFrameStrata, r, "HIGH")
	end
	return put(r, { { "TOPLEFT", UIParent, "TOPLEFT", -L.AWAY, L.AWAY } })
end

function L.Unmerge()
	local r, home = L.merged, L.mergedHome
	L.merged, L.mergedHome = nil, nil
	if not (r and home) then
		return false
	end
	if home.strata and r.SetFrameStrata then
		pcall(r.SetFrameStrata, r, home.strata)
	end
	put(r, home.points)
	if home.clamped ~= nil and r.SetClampedToScreen then
		pcall(r.SetClampedToScreen, r, home.clamped and true or false)
	end
	return true
end

-- every slot where the game had it, the window its own size, ours put away
function L.Restore()
	local w = window()
	if not w then
		return 0
	end
	local n = 0
	for slot, was in pairs(L.homeScale) do
		pcall(slot.SetScale, slot, was)
	end
	L.homeScale = {}
	for slot, pts in pairs(L.home) do
		if put(slot, pts) then
			n = n + 1
		end
	end
	if L.sized and L.gameSize then
		pcall(w.SetSize, w, L.gameSize[1], L.gameSize[2])
	end
	L.sized = nil
	L.FreeSearch(w)
	L.Unmerge()
	if L.canvas then
		L.canvas:Hide()
	end
	L.drawn = nil
	return n
end

-- the active layout drawn on the combined backpack; true when it was
function L.Arrange()
	local w = window()
	local layout = L.Active()
	if not (w and w.IsShown and w:IsShown()) then
		return false
	end
	if not layout then
		if L.drawn then
			L.Restore()
		end
		return false
	end
	L.Remember(w)
	local slots = {}
	for _, slot in ipairs(M.ItemSlots(w)) do
		if slot.IsShown and slot:IsShown() then
			slots[#slots + 1] = slot
		end
	end
	-- the reagent bag's, from its own window (L.Reagents)
	local reagents = L.Reagents()
	if reagents then
		L.HookReagents(reagents)
		L.Remember(reagents)
		for _, slot in ipairs(M.ItemSlots(reagents)) do
			if slot.IsShown and slot:IsShown() then
				slots[#slots + 1] = slot
			end
		end
		L.Merge(reagents)
	elseif L.merged then
		L.Unmerge()
	end
	local scale = L.SCALE
	local size = (slots[1] and BT.Pill.Number(slots[1]:GetWidth(), 37) or 37) * scale
	local items, empties = M.Categorize(slots)
	-- AS TALL AS THE SCREEN ALLOWS, THEN WIDER: bags too full for the height
	-- get more items across, a column at a time, and nothing scrolls
	local most = BT.Pill.Number(UIParent.GetHeight and UIParent:GetHeight(), 768) * L.MAX_SHARE - L.TOP - L.FOOT
	local folded = L.Folded()
	local plan
	for cols = L.COLS, L.MAX_COLS do
		plan = layout.arrange(items, empties, { size = size, cols = cols, folded = folded })
		if plan.height <= most then
			break
		end
	end
	local c = canvas(w)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", w, "TOPLEFT", L.SIDE, -L.TOP)
	c:SetSize(plan.width, plan.height)
	c:SetFrameLevel((BT.Pill.Number(w:GetFrameLevel(), 1)) + 1)
	-- a slot at its smaller size, `x` across and `y` down from the canvas's
	-- corner. Its own scale stretches the distance, so that is taken out.
	local function seat(slot, x, y)
		if L.homeScale[slot] == nil then
			L.homeScale[slot] = BT.Pill.Number(slot.GetScale and slot:GetScale(), 1)
		end
		-- a slot of another window (the reagent bag's) takes that window's
		-- scale, which need not be the backpack's: made up for here
		local own = scale
		local parent = slot.GetParent and slot:GetParent() or nil
		if parent and parent ~= w and parent.GetEffectiveScale then
			local theirs = BT.Pill.Number(parent:GetEffectiveScale(), 0)
			local ours = BT.Pill.Number(w:GetEffectiveScale(), 0)
			if theirs > 0 and ours > 0 then
				own = scale * ours / theirs
			end
		end
		pcall(slot.SetScale, slot, own)
		put(slot, { { "TOPLEFT", c, "TOPLEFT", x / scale, -y / scale } })
	end
	for _, p in ipairs(plan.places) do
		seat(p.slot, p.x, p.y)
	end
	-- NO SQUARE FOR THE EMPTY SLOTS (Josh 2026-11-21: "do we even need that?
	-- I'm not sure it adds any value"). They were stacked on one square at
	-- the foot, to drop an item on. They go off the screen with a folded
	-- shelf's, and come back as one square while you hold an item (L.Hold).
	local free = plan.free or { x = 0, y = plan.height - L.FREE_H, n = #empties }
	for _, slot in ipairs(empties) do
		seat(slot, -L.AWAY, -L.AWAY)
	end
	-- a folded shelf's slots, far off the screen: not drawn, and not clicked
	for _, slot in ipairs(plan.hidden or {}) do
		seat(slot, -L.AWAY, -L.AWAY)
	end
	-- the headings over a shelf's groups
	for i, h in ipairs(plan.heads or {}) do
		local fs = L.heads[i]
		if not fs then
			fs = c:CreateFontString(nil, "OVERLAY")
			BT.Fonts.Set(fs, "text", 10, "")
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(false)
			L.heads[i] = fs
		end
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", c, "TOPLEFT", h.x, -h.y)
		fs:SetText(h.text)
		fs:SetTextColor(BT.TEXT.soft[1], BT.TEXT.soft[2], BT.TEXT.soft[3])
		fs:Show()
	end
	for i = #(plan.heads or {}) + 1, #L.heads do
		L.heads[i]:Hide()
	end
	local quiet, rim = BT.TEXT.quiet, BT.Widgets.RIM
	for i, spec in ipairs(plan.labels) do
		local l = label(c, i)
		local ink = (INK[spec.ink or ""] or function() return BT.TEXT.ink end)()
		l.rule:ClearAllPoints()
		l.rule:SetPoint("TOPLEFT", c, "TOPLEFT", spec.x, -spec.y)
		l.rule:SetSize(spec.w, 1)
		l.rule:SetVertexColor(rim[1], rim[2], rim[3], 0.6)
		l.rule:Show()
		l.name:ClearAllPoints()
		local pad = spec.pad or L.PAD_Y
		l.name:SetPoint("TOPLEFT", c, "TOPLEFT", spec.x + L.CARET + 4, -(spec.y + pad + 1))
		-- folded, the name is as wide as its word, and the count follows it
		l.name:SetWidth(spec.folded and 0 or (L.LABEL - L.CARET - 4))
		l.caret:ClearAllPoints()
		l.caret:SetPoint("LEFT", c, "TOPLEFT", spec.x, -(spec.y + pad + 7))
		l.caret:SetSize(L.CARET, L.CARET)
		l.caret:SetVertexColor(ink[1], ink[2], ink[3], 0.9)
		if l.caret.SetRotation then
			pcall(l.caret.SetRotation, l.caret, spec.folded and 0 or -math.pi / 2)
		end
		l.caret:Show()
		l.name:SetText(spec.name:upper())
		l.name:SetTextColor(ink[1], ink[2], ink[3])
		l.name:Show()
		l.sub:ClearAllPoints()
		if spec.folded then
			l.sub:SetPoint("LEFT", l.name, "RIGHT", 10, 0)
			l.sub:SetWidth(0)
		else
			l.sub:SetPoint("TOPLEFT", l.name, "BOTTOMLEFT", 0, -2)
			l.sub:SetWidth(L.LABEL)
		end
		l.sub:SetText(spec.sub or "")
		l.sub:SetTextColor(quiet[1], quiet[2], quiet[3])
		l.sub:Show()
		l.hit.key = spec.key
		l.hit:ClearAllPoints()
		l.hit:SetPoint("TOPLEFT", c, "TOPLEFT", spec.x, -(spec.y + pad))
		l.hit:SetSize(spec.folded and spec.w or L.LABEL, spec.folded and L.NAME_H or (L.NAME_H + L.SUB_H))
		l.hit:Show()
	end
	for i = #plan.labels + 1, #L.labels do
		local l = L.labels[i]
		l.rule:Hide()
		l.name:Hide()
		l.sub:Hide()
		l.caret:Hide()
		l.hit:Hide()
	end
	-- the free square and its words
	c.freeBack:ClearAllPoints()
	c.freeBack:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(free.y - L.FREE_GAP))
	c.freeBack:SetSize(plan.width, 1)
	c.freeBack:SetVertexColor(rim[1], rim[2], rim[3], 0.6)
	-- HOW MANY OF HOW MANY (Josh 2026-11-21: "We don't show total number of bag
	-- slots anywhere. Should probably show 55/62 somewhere")
	c.free:SetTextColor(quiet[1], quiet[2], quiet[3])
	-- the words, and the square to drop on while an item is held (L.Hold)
	L.empties, L.freeAt, L.drawnSize, L.counts = empties, free, size, { #items, #empties }
	L.Hold(true)
	-- how full, as a bar after the words
	local barUsed, barAll = M.BagCounts(#items, #empties)
	local used = barAll > 0 and (barUsed / barAll) or 0
	local accent = BT.Widgets.ACCENT
	c.barBack:ClearAllPoints()
	c.barBack:SetPoint("LEFT", c.free, "RIGHT", 10, 0)
	c.barBack:SetSize(L.BAR_W, L.BAR_H)
	c.barBack:SetVertexColor(rim[1], rim[2], rim[3], 0.8)
	c.bar:ClearAllPoints()
	c.bar:SetPoint("LEFT", c.barBack, "LEFT", 0, 0)
	c.bar:SetSize(math.max(1, L.BAR_W * used), L.BAR_H)
	c.bar:SetVertexColor(accent[1], accent[2], accent[3], 1)
	c:Show()
	-- the window as large as what is on it. Held back where the game would
	-- refuse it in a fight, and done when the fight ends.
	local width = math.max(L.MIN_W, plan.width + L.SIDE * 2)
	local height = L.TOP + plan.height + L.FREE_GAP + L.FOOT
	local protected = w.IsProtected and select(2, pcall(w.IsProtected, w)) == true
	if protected and InCombatLockdown and InCombatLockdown() then
		L.owed = true
	elseif pcall(w.SetSize, w, width, height) then
		L.sized, L.owed = true, nil
	end
	L.FitSearch(w, width)
	L.drawn = layout.key
	L.stale = nil
	L.Buttons()
	return true
end

-- A SQUARE TO DROP ON, WHILE YOU HOLD AN ITEM (Josh 2026-11-21: "Is it
-- possible to make that empty icon we remove show up only when a stack of
-- something is picked up?"). With no empty slot drawn there was nowhere to
-- put half of a split stack. While the cursor holds an item, the empty slots
-- of your ordinary bags are stacked on one square at the left of the foot's
-- line, with "Drop here" beside it. Let go, and they are off the screen
-- again. The square is taller than the line and sits across it, in the room
-- above and under it, so the window does not change size.
--
-- ORDINARY BAGS ONLY: an empty slot of a bag that takes only certain things
-- would refuse most items, and which slot of the stack is on top can't be
-- chosen.
local function ordinary(slot)
	local bag = slot.GetBagID and slot:GetBagID() or nil
	if bag == nil then
		return true
	end
	local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
	if reagentBag and bag == reagentBag then
		return false
	end
	local c = rawget(_G, "C_Container")
	local free = (c and c.GetContainerNumFreeSlots) or rawget(_G, "GetContainerNumFreeSlots")
	if type(free) ~= "function" then
		return true
	end
	local ok, _, family = pcall(free, bag)
	return not ok or (tonumber(plain(family)) or 0) == 0
end

local function holding()
	local has = rawget(_G, "CursorHasItem")
	if type(has) ~= "function" then
		return false
	end
	local ok, yes = pcall(has)
	return ok and plain(yes) and true or false
end

function L.Hold(force)
	local c, at = L.canvas, L.freeAt
	if not (c and at and (force or L.drawn)) then
		return false
	end
	local held = holding()
	if held == L.held and not force then
		return held
	end
	L.held = held
	local size, scale = L.drawnSize or 31, L.SCALE
	local shown = 0
	for _, slot in ipairs(L.empties or {}) do
		local x, y = -L.AWAY, -L.AWAY
		if held and ordinary(slot) then
			x, y = at.x, at.y + L.FREE_H / 2 - size / 2
			shown = shown + 1
		end
		pcall(slot.SetScale, slot, scale)
		put(slot, { { "TOPLEFT", c, "TOPLEFT", x / scale, -y / scale } })
	end
	local words = M.FreeWords(L.counts and L.counts[1] or 0, L.counts and L.counts[2] or 0)
	c.free:ClearAllPoints()
	if shown > 0 then
		c.free:SetPoint("LEFT", c, "TOPLEFT", at.x + size + 8, -(at.y + L.FREE_H / 2))
		c.free:SetText("Drop here to split or move  ·  " .. words)
	else
		c.free:SetPoint("LEFT", c, "TOPLEFT", at.x, -(at.y + L.FREE_H / 2))
		-- HELD, AND NOWHERE TO PUT IT (Josh 2026-11-21, half a stack in hand
		-- and 62 of 62 slots used: "the icon no longer shows up at all").
		-- There is no square because there is no free slot. The line says
		-- so, in the warning's colour, while the item is held.
		if held then
			c.free:SetText("No free slot to drop in  ·  " .. words)
			local warn = (BT.Tip and BT.Tip.STATE and BT.Tip.STATE.warn) or BT.TEXT.quiet
			c.free:SetTextColor(warn[1], warn[2], warn[3])
		else
			c.free:SetText(words)
			c.free:SetTextColor(BT.TEXT.quiet[1], BT.TEXT.quiet[2], BT.TEXT.quiet[3])
		end
	end
	if shown > 0 then
		c.free:SetTextColor(BT.TEXT.quiet[1], BT.TEXT.quiet[2], BT.TEXT.quiet[3])
	end
	return held
end

-- once a frame, however many of the game's calls asked
-- NOT TWICE FOR ONE OPENING (Josh 2026-11-21: "Anything we can do about the
-- stutter when the bags are opened"). Opening the bags asked for the layout
-- four times: the game sized the window, laid its slots out, set its search
-- and showed the window, and each asked. The layout was drawn at once from
-- the second and again a frame later for the rest. A request now only says
-- the layout is stale, and drawing it says it is not, so the frame after an
-- opening finds nothing to do.
local queued = false
function L.Soon()
	L.stale = true
	if queued then
		return
	end
	if C_Timer and C_Timer.After then
		queued = true
		C_Timer.After(0, function()
			queued = false
			if L.stale then
				pcall(L.Arrange)
			end
		end)
	else
		pcall(L.Arrange)
	end
end

-- asked by the bag window's own pass (M.StyleAll): hooked, the switch
-- drawn, and the layout put on a window that shows without it
function L.Ensure()
	L.Hook()
	L.Buttons()
	local w, layout = window(), L.Active()
	if layout and w and w.IsShown and w:IsShown() and L.drawn ~= layout.key then
		L.Soon()
	elseif not layout and L.drawn then
		L.Restore()
	end
end

-- the chosen layout put on, or the game's own put back
function L.Apply()
	if L.Active() then
		L.Hook()
		L.Arrange()
	else
		L.Restore()
	end
	L.Buttons()
end

-- ---------------------------------------------------------------------------
-- The switch in the title
-- ---------------------------------------------------------------------------

L.BUTTON_W, L.BUTTON_H = 22, 18
L.buttons = {}

local function paintButton(b)
	local on = b.key == M.Layout()
	local a, quiet = BT.Widgets.ACCENT, BT.TEXT.quiet
	local ink = on and BT.TEXT.lit or quiet
	for _, bar in ipairs(b.bars) do
		bar:SetVertexColor(ink[1], ink[2], ink[3], 1)
	end
	-- (no line under the chosen one: Josh 2026-11-21, "The background highlight is enough")
	b.back:SetVertexColor(a[1], a[2], a[3], on and 0.14 or (b.over and 0.08 or 0))
end

local function button(w, key)
	local layout = M.Layouts[key]
	local b = CreateFrame("Button", nil, w)
	b.beebs = true
	b.key = key
	b:SetSize(L.BUTTON_W, L.BUTTON_H)
	b.back = b:CreateTexture(nil, "BACKGROUND")
	b.back:SetTexture("Interface\\Buttons\\WHITE8X8")
	b.back:SetAllPoints(b)
	b.bars = {}
	for i, r in ipairs(layout.icon or {}) do
		local bar = b:CreateTexture(nil, "OVERLAY")
		bar:SetTexture("Interface\\Buttons\\WHITE8X8")
		bar:SetPoint("TOPLEFT", b, "TOPLEFT", 4 + r[1], -(2 + r[2]))
		bar:SetSize(r[3], r[4])
		b.bars[i] = bar
	end
	b:SetScript("OnClick", function(self)
		M.SetLayout(self.key)
	end)
	b:SetScript("OnEnter", function(self)
		self.over = true
		paintButton(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(M.Layouts[self.key].title)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.over = nil
		paintButton(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return b
end

-- one button a layout, left of the close button; hidden while the module is
-- off or a controller is in use
function L.Buttons()
	local w = window()
	if not w then
		return
	end
	local show = BT.Enabled("bagwindow") and not gamepad()
	local n = #M.LAYOUT_ORDER
	for i, key in ipairs(M.LAYOUT_ORDER) do
		local b = L.buttons[key]
		if not b and show then
			b = button(w, key)
			L.buttons[key] = b
		end
		if b then
			b:ClearAllPoints()
			b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -(30 + (n - i) * (L.BUTTON_W + 2)), -3)
			-- over the strip the window is dragged by (M.Handle)
			b:SetFrameLevel((BT.Pill.Number(w:GetFrameLevel(), 1)) + 45)
			b:SetShown(show)
			paintButton(b)
		end
	end
end

-- ---------------------------------------------------------------------------
-- When
-- ---------------------------------------------------------------------------

-- the reagent bag's window: its slots laid out again by the game, and the
-- window shown or hidden, each ask for the shelves again
L.reagentHooked = setmetatable({}, { __mode = "k" })
function L.HookReagents(r)
	if L.reagentHooked[r] or type(hooksecurefunc) ~= "function" then
		return
	end
	L.reagentHooked[r] = true
	if type(r.UpdateItemLayout) == "function" then
		pcall(hooksecurefunc, r, "UpdateItemLayout", function()
			L.Remember(r, true)
			if L.Active() then
				L.Soon()
			end
		end)
	end
	if r.HookScript then
		for _, script in ipairs({ "OnShow", "OnHide" }) do
			pcall(r.HookScript, r, script, function()
				if L.Active() then
					L.Soon()
				end
			end)
		end
	end
end

-- the game places its bag windows again as each opens: the reagent bag's is
-- put out of sight again after it
if type(hooksecurefunc) == "function" and type(rawget(_G, "UpdateContainerFrameAnchors")) == "function" then
	pcall(hooksecurefunc, "UpdateContainerFrameAnchors", function()
		if L.merged and L.Active() then
			L.mergedHome.points = points(L.merged)
			L.Merge(L.merged)
		end
	end)
end

function L.Hook()
	local w = window()
	if not w or L.hooked or type(hooksecurefunc) ~= "function" then
		return
	end
	L.hooked = true
	-- the game has just put every slot and its own size back: those are the
	-- ones to keep, and ours go on again
	-- (at once, not a frame later: the window opens with ours already on,
	-- as the probe put its own back from this same hook)
	if type(w.UpdateItemLayout) == "function" then
		pcall(hooksecurefunc, w, "UpdateItemLayout", function()
			L.Remember(w, true)
			if L.Active() then
				pcall(L.Arrange)
			end
		end)
	end
	-- its size is the game's again: kept, and ours goes on with the layout
	if type(w.UpdateFrameSize) == "function" then
		pcall(hooksecurefunc, w, "UpdateFrameSize", function()
			L.sized, L.gameSize = nil, nil
			local width, height = w:GetSize()
			width, height = BT.Pill.Number(width, 0), BT.Pill.Number(height, 0)
			if width > 0 and height > 0 then
				L.gameSize = { width, height }
			end
			if L.Active() then
				L.Soon()
			end
			-- (the game lays its slots out next, and that hook draws at
			-- once and clears this request)
		end)
	end
	-- the game has put its search field back where it keeps it
	if type(w.UpdateSearchBox) == "function" then
		pcall(hooksecurefunc, w, "UpdateSearchBox", function()
			L.searchHome = nil
			-- (the field alone put right, not the whole layout drawn again:
			-- this comes with every opening. The stutter watch, 2026-11-21)
			if L.Active() and L.drawn then
				L.FitSearch(w, BT.Pill.Number(w:GetWidth(), 0))
			end
		end)
	end
	if w.HookScript then
		pcall(w.HookScript, w, "OnShow", function()
			L.Buttons()
			-- the reagent bag's window, opened with this one (L.OpenReagents)
			if L.Active() and C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if not (L.Active() and w:IsShown()) then
						return
					end
					L.OpenReagents()
					if L.Reagents() and not L.merged then
						L.Soon()
					end
				end)
			end
			-- (the game's own OnShow has laid the slots out by now, and that
			-- hook drew ours: asked only where it did not)
			if L.Active() and not L.drawn then
				L.Soon()
			end
		end)
		-- and shut with it, where this opened it
		pcall(w.HookScript, w, "OnHide", function()
			L.CloseReagents()
		end)
	end
end

L.events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "QUEST_ACCEPTED", "QUEST_REMOVED",
	"NEW_ITEM_ADDED", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "CURSOR_CHANGED", "ITEM_LOCK_CHANGED" }) do
	pcall(L.events.RegisterEvent, L.events, event)
end
L.events:SetScript("OnEvent", function(_, event)
	-- an item picked up or put down: the square to drop on, and no more
	if event == "CURSOR_CHANGED" or event == "ITEM_LOCK_CHANGED" then
		pcall(L.Hold)
		return
	end
	-- (the game says this of every item it loads, anywhere: only when one of
	-- the bags' own was waited for. Review, 2026-11-21)
	if event == "GET_ITEM_INFO_RECEIVED" and not M.itemsWaiting then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" and not L.owed then
		return
	end
	local w = window()
	if L.Active() and w and w.IsShown and w:IsShown() then
		L.Soon()
	end
end)
