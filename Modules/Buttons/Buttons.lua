-- Addon buttons: the minimap buttons other addons add, in a line of their own
-- (Josh 2026-09-22).
--
-- Addons hang a round button on the minimap's edge - most through LibDBIcon,
-- which names them LibDBIcon10_<addon>, a few by hand. With the map square and
-- in the panel there is no edge to hang them on, and the leftovers were lined
-- up along the bottom of the map. This gathers them into one line of the dock
-- instead: each one scaled to the toolkit's icon size, with the client's gold
-- ring and dark disc taken off so what is left is the addon's own icon.
--
-- NOTHING ELSE CHANGES. A click, a right-click, a drag and a tooltip all do
-- what the addon made them do. If an addon moves its button back, it is put
-- back in the line. With no addon buttons at all there is no line, and
-- switching this off gives every button back to where it was.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Buttons/Buttons.lua")

local U = BT.Util

local M = BT.Module({
	key = "buttons",
	feature = "dock",
	onPage = "map",
	title = "Addon buttons",
	blurb = "other addons' minimap buttons, in a line",
	order = 6,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})
BT.MapButtons = M

local ICON = 18
local GAP = 4
local INSET = 6
local PAD_Y = 4

-- the client's own furniture on the minimap, which is the Minimap module's
local BLIZZARD = {
	"^Mini[Mm]ap", "^GameTimeFrame", "^TimeManager", "^QueueStatus", "^Garrison",
	"^ExpansionLanding", "^Queue", "^LFG", "^Battlefield", "^BeebMod",
	-- the client's addon compartment: a menu button with a count on it (the
	-- "0" that got a line of its own), which the Minimap module puts away
	"^AddonCompartment",
}

-- the ring and the disc behind the icon, by file ID or by name
local RING = { [136430] = true, [136467] = true }
local RING_NAMES = { "TrackingBorder", "UI%-Minimap%-Background" }

local owned = setmetatable({}, { __mode = "k" }) -- button -> how to give it back
M.list = {}

local function nameOf(f)
	if type(f) ~= "table" or type(f.GetName) ~= "function" then
		return nil
	end
	local ok, n = pcall(f.GetName, f)
	return ok and type(n) == "string" and n or nil
end

-- Is this an addon's minimap button? A LibDBIcon one always is; otherwise a
-- named button that is not one of the client's own.
function M.IsAddonButton(f)
	local name = nameOf(f)
	if not name or f.beebs then
		return false
	end
	if name:find("^LibDBIcon10_") then
		return true
	end
	local ok, kind = pcall(function() return f:GetObjectType() end)
	if not (ok and kind == "Button") then
		return false
	end
	for _, pattern in ipairs(BLIZZARD) do
		if name:find(pattern) then
			return false
		end
	end
	-- AND IT HAS AN ICON (Josh 2026-09-22). A button of the client's own that
	-- this list has not heard of - one carrying nothing but a "0" - was taken
	-- for an addon's and given a line of its own. An addon's minimap button is
	-- a picture: a texture that is not the ring or the disc behind it.
	return M.HasIcon(f)
end

-- a texture on it that is an actual picture, not the ring and not nothing
function M.HasIcon(f)
	local ok, regions = pcall(function() return { f:GetRegions() } end)
	for _, r in ipairs(ok and regions or {}) do
		local okKind, kind = pcall(r.GetObjectType, r)
		if okKind and kind == "Texture" then
			local okTex, tex = pcall(function() return r:GetTexture() end)
			if okTex and tex ~= nil and tex ~= "" and not M.IsRing(r) then
				return true
			end
		end
	end
	return false
end

-- whether this line has taken a button (the Minimap module leaves those alone)
function M.Claims(f)
	return BT.Enabled("buttons") and (owned[f] ~= nil or M.IsAddonButton(f))
end

-- Every addon button there is: LibDBIcon's own list where it has one, and
-- whatever hangs off the minimap's frames.
function M.Find()
	local out, seen = {}, {}
	local function take(f)
		if type(f) == "table" and not seen[f] and M.IsAddonButton(f) then
			seen[f] = true
			out[#out + 1] = f
		end
	end
	local stub = _G.LibStub
	local lib = type(stub) == "table" and stub.GetLibrary and select(2, pcall(stub.GetLibrary, stub, "LibDBIcon-1.0", true))
	if type(lib) == "table" and type(lib.objects) == "table" then
		for _, b in pairs(lib.objects) do
			take(b)
		end
	end
	for _, parentName in ipairs({ "Minimap", "MinimapCluster", "MinimapBackdrop" }) do
		local p = _G[parentName]
		if p and p.GetChildren then
			local ok, kids = pcall(function() return { p:GetChildren() } end)
			for _, f in ipairs(ok and kids or {}) do
				take(f)
			end
		end
	end
	-- and the ones already in the line, which no longer hang off the minimap
	for f in pairs(owned) do
		take(f)
	end
	-- the same order every time: by name
	table.sort(out, function(a, b) return (nameOf(a) or "") < (nameOf(b) or "") end)
	return out
end

-- the ring and the disc: faded, and given back when the button is
local function isRing(tex)
	local ok, t = pcall(function() return tex:GetTexture() end)
	if not ok or t == nil then
		return false
	end
	if type(t) == "number" then
		return RING[t] == true
	end
	for _, pattern in ipairs(RING_NAMES) do
		if tostring(t):find(pattern) then
			return true
		end
	end
	return false
end

M.IsRing = isRing

local function take(b)
	if owned[b] then
		return owned[b]
	end
	local o = { parent = b:GetParent(), scale = (b.GetScale and b:GetScale()) or 1, rings = {} }
	if b.GetPoint then
		local ok, p, rel, rp, x, y = pcall(b.GetPoint, b, 1)
		if ok and p then
			o.at = { p, rel, rp, x, y }
		end
	end
	local ok, regions = pcall(function() return { b:GetRegions() } end)
	for _, r in ipairs(ok and regions or {}) do
		local okKind, kind = pcall(r.GetObjectType, r)
		if okKind and kind == "Texture" and isRing(r) then
			o.rings[#o.rings + 1] = { tex = r, alpha = (r.GetAlpha and r:GetAlpha()) or 1 }
			pcall(r.SetAlpha, r, 0)
		end
	end
	-- an addon that moves its own button (a refresh) is put back in line, and
	-- one that shows or hides it ("hide minimap icon") closes the line up
	if hooksecurefunc and not b.beebsHooked then
		b.beebsHooked = true
		for _, method in ipairs({ "SetPoint", "Show", "Hide" }) do
			pcall(hooksecurefunc, b, method, function()
				if owned[b] and not M.placing then
					M.Queue()
				end
			end)
		end
	end
	-- NOT DRAGGED ROUND THE MINIMAP WHILE IT IS IN THE LINE (Josh 2026-09-23,
	-- audit): the addon's drag moved it every frame, each move laid the whole
	-- line out again, and the addon saved an angle measured against a map
	-- the button was no longer on. Its drag is put back when it goes back.
	if b.GetScript and b.SetScript then
		local okD, drag = pcall(b.GetScript, b, "OnDragStart")
		if okD and drag then
			o.drag = drag
			pcall(b.SetScript, b, "OnDragStart", nil)
		end
	end
	owned[b] = o
	return o
end

-- ONE LAYOUT A FRAME (Josh 2026-09-23, audit): each SetPoint an addon made
-- asked for a layout of its own, next frame, and each one read every button
-- and laid the dock out again
local queued = false
function M.Queue()
	if queued then
		return
	end
	if not (C_Timer and C_Timer.After) then
		M.Layout()
		return
	end
	queued = true
	C_Timer.After(0, function()
		queued = false
		M.Layout()
	end)
end

local function giveBack(b)
	local o = owned[b]
	if not o then
		return
	end
	owned[b] = nil
	pcall(b.SetParent, b, o.parent or _G.Minimap or UIParent)
	pcall(b.SetScale, b, o.scale or 1)
	if o.at then
		pcall(b.ClearAllPoints, b)
		pcall(b.SetPoint, b, o.at[1], o.at[2], o.at[3], o.at[4], o.at[5])
	end
	for _, ring in ipairs(o.rings) do
		pcall(ring.tex.SetAlpha, ring.tex, ring.alpha)
	end
	if o.drag then
		pcall(b.SetScript, b, "OnDragStart", o.drag)
	end
end

-- ---------------------------------------------------------------------------
-- The line
-- ---------------------------------------------------------------------------

function M.Layout()
	local frame = M.frame
	if not frame then
		return 0
	end
	if not BT.Enabled("buttons") then
		for b in pairs(owned) do
			giveBack(b)
		end
		M.list = {}
		frame:Hide()
		BT.Bar.Relayout()
		return 0
	end
	local found = M.Find()
	-- A BUTTON ITS ADDON HAS HIDDEN TAKES NO PLACE (Josh 2026-09-23, audit):
	-- it kept its slot, so hiding one left a gap and hiding them all left an
	-- empty line in the dock. It is still taken (and given back), just not
	-- laid out; showing it again lays the line out (the Show hook above).
	local list = {}
	for _, b in ipairs(found) do
		take(b)
		if b.IsShown and b:IsShown() then
			list[#list + 1] = b
		end
	end
	M.list = list
	local width = BT.Pill.Number(frame:GetWidth(), 0)
	if width <= 0 then
		width = 230
	end
	local perRow = math.max(1, math.floor((width - INSET * 2 + GAP) / (ICON + GAP)))
	M.placing = true
	for i, b in ipairs(list) do
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		-- scaled to the icon size, whatever size the addon drew it at
		local w = BT.Pill.Number(b.GetWidth and b:GetWidth(), 31)
		local h = BT.Pill.Number(b.GetHeight and b:GetHeight(), 31)
		local scale = ICON / math.max(1, w, h)
		pcall(b.SetParent, b, frame)
		pcall(b.SetScale, b, scale)
		pcall(b.ClearAllPoints, b)
		-- a point is in the button's own scaled units, so the offset is too
		pcall(b.SetPoint, b, "TOPLEFT", frame, "TOPLEFT",
			(INSET + col * (ICON + GAP)) / scale, -(PAD_Y + row * (ICON + GAP)) / scale)
		if b.SetFrameLevel and frame.GetFrameLevel then
			pcall(b.SetFrameLevel, b, (frame:GetFrameLevel() or 1) + 2)
		end
		-- not shown by force: a button its own addon has hidden ("hide
		-- minimap icon") stays hidden, in the line or out of it
	end
	M.placing = false
	-- buttons that are gone - an addon switched off - are given back
	local still = {}
	for _, b in ipairs(found) do
		still[b] = true
	end
	for b in pairs(owned) do
		if not still[b] then
			giveBack(b)
		end
	end
	local rows = math.max(1, math.ceil(#list / perRow))
	local tall = PAD_Y * 2 + rows * ICON + (rows - 1) * GAP
	frame.wantHeight = tall
	frame:SetHeight(tall)
	-- NO BUTTONS, NO LINE
	local want = #list > 0
	if want ~= frame:IsShown() then
		frame:SetShown(want)
	end
	BT.Bar.Relayout()
	return #list
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.Section("buttons", 6)
	M.frame.wantHeight = ICON + PAD_Y * 2
	M.frame:SetHeight(M.frame.wantHeight)
	-- the dock sets the width; the rows are worked out against it
	M.frame:SetScript("OnSizeChanged", function(self, w)
		if not M.placing and w and math.abs((M.lastWidth or 0) - w) > 1 then
			M.lastWidth = w
			M.Layout()
		end
	end)
	return M.frame
end

-- addons make their buttons as they load, and some a moment after login
M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event)
	if not (BT.Enabled("buttons") and M.frame) then
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 2 or 0.5, M.Layout)
	else
		M.Layout()
	end
end)

function M:OnEnable()
	M.Build()
	M.Layout()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.Build()
	M.Layout()
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the buttons other addons put on the minimap, in a line of the panel, at the toolkit's icon size")
	page:Note("each still does what its addon made it do · with no addon buttons there is no line", true)
	self.found = page:Note("", true).text
	page:Layout()
end

function M:RefreshTab()
	if self.found then
		local names = {}
		for _, b in ipairs(M.list or {}) do
			names[#names + 1] = ((nameOf(b) or "?"):gsub("^LibDBIcon10_", ""))
		end
		self.found:SetText(#names > 0 and ("in the line: " .. table.concat(names, ", "))
			or "no addon has a minimap button right now")
	end
end

function M:ShowTab()
	M.Layout()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

BT.Command("buttons", function()
	local n = M.Layout()
	U.Print(("%d addon button%s in the line"):format(n, n == 1 and "" or "s"))
end, "gather other addons' minimap buttons into their line now", "buttons")
