-- The bag window, in the toolkit's clothes (Josh 2026-09-24).
--
-- The client's bags - the one combined backpack, or a window a bag - wear its
-- gold-and-leather frame, a portrait, a red close button and a bevelled slot
-- behind every item: the loudest window you open all day, in a toolkit where
-- everything else is a flat fill and a one-pixel rim.
--
-- SAME BARGAIN AS THE ACTION BARS. Nothing is reimplemented: the window, its
-- slots, the search, the sorting and the money are the client's, and every
-- one still does what it did - a click uses, a drag moves, a right-click
-- opens. Only the look changes, and switched off, all of it is put back:
--
--   the window       our surface and shadow; the frame, the portrait and the
--                    title bar's art off; the title in the panel's text
--   the close        our cross, as the character sheet wears
--   the search       a flat field of the panel's own
--   a slot           our square: the client's slot art off, the picture
--                    cropped of its baked-in border and set inside the rim
--   its quality      a crisp ring in the item's own colour - read from the
--                    client's quality border as it paints it, which then
--                    goes transparent - rather than the client's soft glow
--   the money        left exactly as it is: the coins are pictures
--
-- WHAT THE CLIENT CALLS THEM is looked for rather than assumed, and /bt
-- bagdump writes the window down into the saved file when something comes
-- out wrong, the way the meter and the character sheet were put right.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/BagWindow/BagWindow.lua")

local U = BT.Util

local M = BT.Module({
	key = "bagwindow",
	group = "windows",
	title = "Bag window",
	blurb = "your bags, flat like the rest",
	order = 57,
})

local FILL = BT.Widgets.FILL
local RIM = BT.Widgets.RIM
local CROP = 0.08
local MUTED = { 0.55, 0.60, 0.58 }

-- ---------------------------------------------------------------------------
-- Which frames
-- ---------------------------------------------------------------------------

-- the combined backpack, and the window a bag each for anyone who keeps them
-- apart (ContainerFrame1 is the backpack, the rest its bags and the bank's)
function M.Windows()
	local out = {}
	local combined = _G.ContainerFrameCombinedBags
	if type(combined) == "table" then
		out[#out + 1] = combined
	end
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if type(f) == "table" then
			out[#out + 1] = f
		end
	end
	return out
end

local function children(f)
	if not (type(f) == "table" and type(f.GetChildren) == "function") then
		return {}
	end
	local ok, kids = pcall(function() return { f:GetChildren() } end)
	return ok and kids or {}
end

-- an item's slot: a button with the client's quality border on it
local function isSlot(f)
	return type(f) == "table" and type(f.IconBorder) == "table"
		and (f.icon ~= nil or f.Icon ~= nil)
end

-- the money line: pictures of coins, never inked or taken away
local function isMoney(f)
	local name = BT.Furniture.Call(f, "GetName")
	return type(name) == "string" and name:find("Money", 1, true) ~= nil
end

-- every slot a window has made, however it keeps them
function M.Slots(window)
	local out, seen = {}, {}
	local function add(b)
		if isSlot(b) and not seen[b] then
			seen[b] = true
			out[#out + 1] = b
		end
	end
	if type(window.Items) == "table" then
		for _, b in pairs(window.Items) do
			add(b)
		end
	end
	for _, kid in ipairs(children(window)) do
		add(kid)
		for _, grand in ipairs(children(kid)) do
			add(grand)
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local dresser = BT.Furniture.New({
	panelAlpha = 0.96,
	skip = function(f) return isSlot(f) or isMoney(f) end,
})

local function piece(f, key, suffix)
	if type(f) ~= "table" then
		return nil
	end
	if f[key] then
		return f[key]
	end
	local name = BT.Furniture.Call(f, "GetName")
	return (type(name) == "string" and suffix) and _G[name .. suffix] or nil
end

-- the close button: its red square off, our cross on
local crosses = setmetatable({}, { __mode = "k" })
local function dressClose(button)
	if not (type(button) == "table" and button.CreateTexture) then
		return
	end
	for _, r in ipairs({ BT.Furniture.Call(button, "GetRegions") }) do
		if type(r) == "table" and not r.beebs and BT.Furniture.Call(r, "GetObjectType") == "Texture" then
			dresser:Hide(r)
		end
	end
	local cross = crosses[button]
	if not cross then
		cross = button:CreateTexture(nil, "OVERLAY")
		cross.beebs = true
		cross:SetSize(10, 10)
		cross:SetPoint("CENTER")
		cross:SetTexture(BT.Bar.ICONS)
		BT.Bar.CrossCoord(cross)
		crosses[button] = cross
		button:HookScript("OnEnter", function()
			if BT.Enabled("bagwindow") then
				cross:SetVertexColor(1, 1, 1, 1)
			end
		end)
		button:HookScript("OnLeave", function()
			cross:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 1)
		end)
	end
	cross:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 1)
	cross:Show()
end

-- the search: the client's rounded field off, a flat one of ours on, and its
-- magnifier kept
local fields = setmetatable({}, { __mode = "k" })
local function dressSearch(box)
	if not (type(box) == "table" and box.CreateTexture) then
		return
	end
	local glass = piece(box, "searchIcon", "SearchIcon") or box.SearchIcon
	for _, r in ipairs({ BT.Furniture.Call(box, "GetRegions") }) do
		if type(r) == "table" and not r.beebs and r ~= glass
			and BT.Furniture.Call(r, "GetObjectType") == "Texture" then
			dresser:Hide(r)
		end
	end
	local s = fields[box]
	if not s then
		s = BT.Pill.Surface(box, "BACKGROUND", -8)
		fields[box] = s
	end
	BT.Pill.PaintSurface(s, box, { FILL[1] * 0.6, FILL[2] * 0.6, FILL[3] * 0.6, 1 }, RIM)
	BT.Pill.ShowSurface(s, true)
end

-- ---------------------------------------------------------------------------
-- A slot
-- ---------------------------------------------------------------------------

local slots = setmetatable({}, { __mode = "k" })

-- the ring in the quality's colour, while the client's border says there is
-- one; the plain rim when it says there is not
-- OURS OR THE GAME'S (Josh 2026-09-24): with rings off, the client's own
-- quality glow is left showing instead
function M.Rings()
	return not (BT.settings and BT.settings.bagwindow and BT.settings.bagwindow.rings == false)
end

local function paintQuality(b)
	local s = slots[b]
	local border = b.IconBorder
	if not (s and border) then
		return
	end
	border:SetAlpha(M.Rings() and 0 or 1)
	local shown = BT.Enabled("bagwindow") and M.Rings() and BT.Furniture.Call(border, "IsShown")
	if shown then
		local r, g, bl = BT.Furniture.Call(border, "GetVertexColor")
		r, g, bl = BT.Pill.Number(r, 1), BT.Pill.Number(g, 1), BT.Pill.Number(bl, 1)
		BT.Pill.PlaceRing(s.quality, b, 0, 1, 0)
		BT.Pill.PaintRing(s.quality, { r, g, bl, 1 })
	else
		BT.Pill.HideRing(s.quality)
	end
end
M.PaintQuality = paintQuality

-- what the client's pieces were, for putting back
local function remember(s, key, t)
	if t and s.was[key] == nil then
		s.was[key] = BT.Pill.Number(BT.Furniture.Call(t, "GetAlpha"), 1)
	end
end

local ART = { "NormalTexture", "ItemSlotBackground", "SlotBackground", "slotTexture" }

-- ONCE A SLOT, NOT EVERY UPDATE: the window lays its slots out again on every
-- bag change while you loot, and a slot already dressed keeps what it wears -
-- the client sets a new picture, not a new crop, and its quality comes through
-- the hooks. Painted again only for a new theme (`force`).
function M.StyleSlot(b, plain, force)
	if not isSlot(b) then
		return false
	end
	local s = slots[b]
	if s and s.dressed and not (plain or force) then
		return false
	end
	if plain then
		if not s then
			return false
		end
		BT.Pill.ShowSurface(s.surface, false)
		BT.Pill.HideRing(s.quality)
		for key, alpha in pairs(s.was) do
			local t = key == "NormalTexture" and BT.Furniture.Call(b, "GetNormalTexture") or b[key]
			if t and t.SetAlpha then
				t:SetAlpha(alpha)
			end
		end
		s.was = {}
		s.dressed = nil
		local icon = b.icon or b.Icon
		if icon and icon.SetTexCoord then
			icon:SetTexCoord(0, 1, 0, 1)
			icon:ClearAllPoints()
			icon:SetAllPoints()
		end
		return true
	end
	if not s then
		s = { surface = BT.Pill.Surface(b, "BACKGROUND", -8), quality = BT.Pill.Ring(b, "OVERLAY", 7), was = {} }
		slots[b] = s
		-- the quality as the client paints it: its border goes see-through,
		-- and what colour it was given, and whether it is showing, is ours
		local border = b.IconBorder
		if type(hooksecurefunc) == "function" then
			for _, method in ipairs({ "SetVertexColor", "Show", "Hide", "SetShown", "SetTexture", "SetAtlas" }) do
				if type(border[method]) == "function" then
					pcall(hooksecurefunc, border, method, function()
						paintQuality(b)
					end)
				end
			end
		end
	end
	BT.Pill.PaintSurface(s.surface, b, FILL, RIM)
	BT.Pill.ShowSurface(s.surface, true)
	-- the client's slot art, and its quality border, see-through
	for _, key in ipairs(ART) do
		local t = key == "NormalTexture" and BT.Furniture.Call(b, "GetNormalTexture") or b[key]
		if type(t) == "table" and t.SetAlpha then
			remember(s, key, t)
			t:SetAlpha(0)
		end
	end
	remember(s, "IconBorder", b.IconBorder)
	-- the picture without its own border, inside the rim
	local icon = b.icon or b.Icon
	if icon and icon.SetTexCoord then
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	paintQuality(b)
	s.dressed = true
	return true
end

-- ---------------------------------------------------------------------------
-- All of it
-- ---------------------------------------------------------------------------

function M.StyleAll(plain, force)
	local n = 0
	if plain then
		dresser:Undress()
		for b in pairs(slots) do
			M.StyleSlot(b, true)
		end
		for _, cross in pairs(crosses) do
			cross:Hide()
		end
		for _, s in pairs(fields) do
			BT.Pill.ShowSurface(s, false)
		end
		return 0
	end
	for _, w in ipairs(M.Windows()) do
		local ok, err = pcall(function()
			n = n + (dresser:DressRoot(w) or 0)
			dressClose(piece(w, "CloseButton", "CloseButton"))
			for _, b in ipairs(M.Slots(w)) do
				if M.StyleSlot(b, false, force) then
					n = n + 1
				end
			end
		end)
		if not ok then
			BT.Err("bagwindow: " .. tostring(err))
		end
	end
	-- the search is the combined window's, or a global one on some builds
	dressSearch((_G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags.SearchBox)
		or _G.BagItemSearchBox)
	M.lastCount = n
	M.Hook()
	-- the window may not have existed when the module came on
	M.WatchPosition()
	return n
end

-- the theme changed: every slot painted again in it
function M.Restyle()
	if BT.Enabled("bagwindow") then
		return M.StyleAll(false, true)
	end
end

-- once a frame, however many of the client's own calls asked
local queued = false
local function soon()
	if queued then
		return
	end
	if C_Timer and C_Timer.After then
		queued = true
		C_Timer.After(0, function()
			queued = false
			if BT.Enabled("bagwindow") then
				M.StyleAll()
			end
		end)
	elseif BT.Enabled("bagwindow") then
		M.StyleAll()
	end
end
M.Soon = soon

-- a window shown, or laying its slots out again, is dressed again: a bag
-- bought or swapped makes slots the last pass never saw
function M.Hook()
	for _, w in ipairs(M.Windows()) do
		if w.HookScript and not w.beebsBagHooked then
			w.beebsBagHooked = true
			pcall(w.HookScript, w, "OnShow", soon)
			if type(hooksecurefunc) == "function" then
				for _, fn in ipairs({ "UpdateItemLayout", "UpdateItems", "Update" }) do
					if type(w[fn]) == "function" then
						pcall(hooksecurefunc, w, fn, soon)
					end
				end
			end
		end
	end
end

function M.Watch()
	if M.events then
		return M.events
	end
	M.events = CreateFrame("Frame")
	for _, event in ipairs({ "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED" }) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	M.events:SetScript("OnEvent", function()
		if BT.Enabled("bagwindow") then
			soon()
		end
	end)
	return M.events
end

local function refitBar()
	local space = BT.GetModule("bagspace")
	if space and space.Refit then
		space.Refit()
	end
end

function M:OnEnable()
	M.Watch()
	M.WatchPosition()
	M.StyleAll()
	refitBar()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.StyleAll(true)
	refitBar()
end

-- ---------------------------------------------------------------------------
-- Where it sits
-- ---------------------------------------------------------------------------
--
-- DRAGGED BY ITS TITLE, AND IT STAYS (Josh 2026-09-24: "make the bags frame
-- draggable, and persist the new position"). The client places its bag
-- windows itself (UpdateContainerFrameAnchors) every time one opens, and
-- again as others open beside it. That is left to do its work, and each
-- window you have moved is put back where you left it straight after - the
-- way the character sheet stays put. Never in a fight if the client has made
-- the window protected: that would be "action blocked".
--
-- EVERY WINDOW, NOT ONLY THE BACKPACK (Josh 2026-09-24): a bag a window, for
-- anyone who keeps them apart, each where you last put it, by its name.

local function settings()
	BT.EnsureBound()
	local s = BT.settings.bagwindow or {}
	BT.settings.bagwindow = s
	s.places = s.places or {}
	-- where the backpack was kept before every window had a place of its own
	if s.pos then
		s.places.ContainerFrameCombinedBags = s.places.ContainerFrameCombinedBags or s.pos
		s.pos = nil
	end
	return s
end

local function movable(frame)
	return not (InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected())
end

local function nameOf(frame)
	return BT.Furniture.Call(frame, "GetName")
end

local function combined()
	return _G.ContainerFrameCombinedBags
end

function M.PlaceOf(frame)
	local name = nameOf(frame or combined())
	local s = BT.settings and BT.settings.bagwindow
	if not (name and s) then
		return nil
	end
	return (s.places and s.places[name]) or (name == "ContainerFrameCombinedBags" and s.pos) or nil
end

function M.SavePosition(frame)
	frame = frame or combined()
	local name = nameOf(frame)
	if not (name and frame.GetLeft and frame:GetLeft()) then
		return nil
	end
	local num = BT.Pill.Number
	local scale = num(frame:GetEffectiveScale(), 1)
	local parentScale = num(UIParent:GetEffectiveScale(), 1)
	local top = num(frame:GetTop(), 0)
	local parentTop = num(UIParent:GetTop(), 0)
	local s = settings()
	s.places[name] = {
		x = math.floor(num(frame:GetLeft(), 0) + 0.5),
		y = math.floor((top * scale - parentTop * parentScale) / scale + 0.5),
	}
	return s.places[name]
end

function M.ApplyPosition(frame)
	frame = frame or combined()
	local pos = frame and M.PlaceOf(frame)
	if not (frame and pos and BT.Enabled("bagwindow") and frame:IsShown() and movable(frame)) then
		return false
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x or 0, pos.y or 0)
	return true
end

-- every window that is showing, where you left it
function M.ApplyAll()
	local n = 0
	for _, w in ipairs(M.Windows()) do
		if M.ApplyPosition(w) then
			n = n + 1
		end
	end
	return n
end

function M.ResetPosition()
	if BT.settings and BT.settings.bagwindow then
		BT.settings.bagwindow.places = nil
		BT.settings.bagwindow.pos = nil
	end
	if type(_G.UpdateContainerFrameAnchors) == "function" then
		pcall(_G.UpdateContainerFrameAnchors)
	end
end

-- the client's own button under the pointer, in the window's top two levels
-- (a click on the title that was not a drag is handed to it)
function M.Under(frame, except)
	local function look(f, depth)
		for _, kid in ipairs(children(f)) do
			if kid ~= except and not kid.beebs and BT.Furniture.Call(kid, "IsShown")
				and BT.Furniture.Call(kid, "IsMouseOver")
				and (type(kid.OpenMenu) == "function" or BT.Furniture.Call(kid, "GetScript", "OnMouseDown")
					or BT.Furniture.Call(kid, "GetScript", "OnClick")) then
				return kid
			end
			if depth < 2 then
				local found = look(kid, depth + 1)
				if found then
					return found
				end
			end
		end
		return nil
	end
	return look(frame, 1)
end

-- ABOVE THE CLIENT'S TITLE BUTTON (Josh 2026-09-24: "cannot drag... it just
-- opens this menu"). The client covers its title with a button of its own -
-- the one with the sorting menu - which sat over the handle and took every
-- press. The handle is raised over it, a drag moves the window, and a click
-- that was not a drag is passed to whatever of the client's is under it, so
-- the menu is still a click away.
local function forward(frame, h)
	local b = M.Under(frame, h)
	if not b then
		return false
	end
	if type(b.OpenMenu) == "function" and pcall(b.OpenMenu, b) then
		return true
	end
	local press = BT.Furniture.Call(b, "GetScript", "OnMouseDown")
	if press and pcall(press, b, "LeftButton") then
		return true
	end
	return b.Click ~= nil and pcall(b.Click, b) or false
end
M.Forward = forward

-- the handle: the title bar, short of the bag's own button on the left (its
-- menu) and the close button on the right - one a window
function M.Handle(frame)
	frame = frame or combined()
	if not frame then
		return nil
	end
	if frame.beebsHandle then
		return frame.beebsHandle
	end
	local h = CreateFrame("Frame", nil, frame)
	h.beebs = true
	h:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, 0)
	h:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, 0)
	h:SetHeight(22)
	h:SetFrameLevel((BT.Pill.Number(frame:GetFrameLevel(), 1)) + 40)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnMouseDown", function(self)
		self.dragged = false
	end)
	h:SetScript("OnMouseUp", function(self, button)
		if not self.dragged and BT.Enabled("bagwindow") then
			forward(frame, self)
		end
	end)
	h:SetScript("OnDragStart", function(self)
		self.dragged = true
		if BT.Enabled("bagwindow") and movable(frame) then
			self.moving = true
			frame:SetMovable(true)
			frame:SetClampedToScreen(true)
			frame:StartMoving()
		end
	end)
	h:SetScript("OnDragStop", function(self)
		if not self.moving then
			return
		end
		self.moving = false
		frame:StopMovingOrSizing()
		-- ours to keep, not the client's layout cache's
		if frame.SetUserPlaced then
			pcall(frame.SetUserPlaced, frame, false)
		end
		M.SavePosition(frame)
		M.ApplyPosition(frame)
	end)
	frame.beebsHandle = h
	if frame == combined() then
		M.handle = h
	end
	return h
end

-- put back after the client has placed them: as each shows, and whenever the
-- client lays its bag windows out again
function M.WatchPosition()
	local fresh = false
	for _, frame in ipairs(M.Windows()) do
		if not frame.beebsPlaceWatched and frame.HookScript then
			frame.beebsPlaceWatched = true
			fresh = true
			M.Handle(frame)
			frame:HookScript("OnShow", function(self)
				M.ApplyPosition(self)
				if C_Timer and C_Timer.After then
					C_Timer.After(0, function() M.ApplyPosition(self) end)
				end
			end)
		end
	end
	if not M.anchorsHooked and type(hooksecurefunc) == "function"
		and type(_G.UpdateContainerFrameAnchors) == "function" then
		M.anchorsHooked = true
		pcall(hooksecurefunc, "UpdateContainerFrameAnchors", function()
			M.ApplyAll()
			if C_Timer and C_Timer.After then
				C_Timer.After(0, M.ApplyAll)
			end
		end)
	end
	M.positionWatched = M.positionWatched or fresh
	return fresh
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the client's own bags · every slot still uses, drags and opens as it did · "
		.. "an item's quality is a ring in its colour")
	page:Note("drag a bag window by its title and it stays there · /bt bags reset puts them all back")
	page:Note("switched off, the bags are back in the client's own art · /bt bagdump writes the window "
		.. "into the saved file", true)
	-- the game's bag bar, from Metrics (Josh 2026-09-24): the bag window's page
	-- is where you look for anything to do with your bags
	local look = page:Section("Slots")
	BT.Widgets.SwitchRow(look, "Quality rings", "a crisp ring in an item's colour · off, the game's own glow",
		function() return M.Rings() end,
		function(on)
			BT.EnsureBound()
			BT.settings.bagwindow = BT.settings.bagwindow or {}
			BT.settings.bagwindow.rings = (not on) and false or nil
			for b in pairs(slots) do
				paintQuality(b)
			end
		end)
	local bar = page:Section("The game's own")
	local space = BT.GetModule("bagspace")
	self.hideBags = BT.Widgets.SwitchRow(bar, "Hide the bag bar",
		"the backpack and bag slots by the action bars · your bag keys still open them",
		function() return space and space.HideClient() and true or false end,
		function(on)
			if space then
				space.SetHideClient(on)
			end
		end)
	page:Layout()
end

function M:RefreshTab()
end

function M:ShowTab()
	if BT.Enabled("bagwindow") then
		M.StyleAll()
	end
end

function M:Refresh()
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

-- /bt bags reset: back where the client puts it
BT.Command("bags", function(rest)
	if (rest or ""):lower() == "reset" then
		M.ResetPosition()
		U.Print("bags: back where the game puts them")
	else
		U.Print("/bt bags reset · every bag window back where the game puts it")
	end
end, "bags reset - every bag window back where the game puts it", "bagwindow")

-- /bt bagdump: the windows as the client built them, into the saved file
BT.Command("bagdump", function()
	local lines = BT.Furniture.Dump(M.Windows())
	BT.EnsureBound()
	BeebModDB.bagDump = {
		at = U.Now(),
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	U.Print(("bag window: %d lines written down · /reload to save them"):format(#lines))
end, "bagdump - the bag windows' frames, into the saved file", "bagwindow")
