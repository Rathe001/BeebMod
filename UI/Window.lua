-- The one window, with the utilities down its left side (Josh 2026-09-19).
--
-- The rail is on the LEFT because the list grows: tabs across the top run out
-- of room at five or six, and every new utility would make the ones before it
-- narrower. Down the side there is room for a name, and the twelfth reads
-- exactly like the first.
--
-- ONE RAIL, IN THREE GROUPS (Josh 2026-09-23). The furniture restyles used to
-- be pages of Settings, picked from a row of buttons across its top - a
-- second menu inside the first, and eight buttons at 92 wide in a column 570
-- wide, so the last of them hung off the window. Every page is a tab now:
--
--   General       what belongs to everything: the look, the panel header
--   Panel         what sits in the dock, in the dock's order - drag to move
--   Game frames   the client's own frames, restyled; their order means nothing
--
-- A module that is switched off has its name dimmed, so the rail answers
-- "what is running" without opening anything. (It was a dot at the end of
-- each tab, 2026-09-23 - which read as "something new in here", the way an
-- unread badge does, so it came off the same evening.)
--
-- Each module builds its page ONCE, the first time its tab is opened, into a
-- frame this file owns. Switching tabs shows one and hides the rest.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Window.lua")

local U = BT.Util
local W = {}
BT.Window = W

local RAIL, PAD = 148, 14
-- COMPACT (Josh 2026-09-22): a name and nothing under it. The line saying what
-- each utility is lives at the top of its own page, where it is read once,
-- not down the rail where it is read every time you look for a tab.
-- (A pixel off each side, Josh 2026-09-24: the Game frames group grew past
-- the foot of the window at 22 apart, and every tab paid two pixels for it.)
local TAB_H, TAB_STRIDE = 20, 22
-- a group's name over its tabs, and the line at the foot of the rail
-- A GROUP IS A BLOCK (Josh 2026-09-23: "difficult to tell that the top
-- section is different from the bottom section"): a rule above each heading,
-- like the one under General, and room either side of it
local GROUP_H, GROUP_GAP, FOOT_H = 20, 8, 16
-- TALLER (Josh 2026-09-23): the rail carries every page now - twenty tabs
-- with two headings since the unit frames, buffs and game menu arrived - and
-- they need the room
-- (640 tall, Josh 2026-09-24: the rail's five groups want the room; 660
-- the same day, for the Testing tab under General; 682, a tab's stride more,
-- for the Menagerie's, Josh 2026-09-25)
local TITLE_H, WINDOW_W, WINDOW_H = 40, 760, 682
-- the page's own header: its name, a line under it, and its switch
local HEADER_H = 54

local frame, rail, content, tabs, current


local function tabTint(tab, on, hot)
	-- OFF IS DIMMED, NOT BADGED: a switched-off module's name is quieter than
	-- the rest, and is still there to be switched back on
	tab.off = tab.key ~= nil and not W.TabOn(tab.key)
	if on then
		local w = BT.Widgets.WASH
		tab.fill:SetColorTexture(w[1], w[2], w[3], w[4])
		tab.mark:Show()
		if tab.off then
			tab.label:SetTextColor(0.60, 0.66, 0.63)
		else
			tab.label:SetTextColor(0.85, 0.95, 0.90)
		end
	else
		tab.fill:SetColorTexture(0.06, 0.08, 0.07, hot and 0.9 or 0)
		tab.mark:Hide()
		if tab.off then
			tab.label:SetTextColor(hot and 0.55 or 0.36, hot and 0.60 or 0.40, hot and 0.58 or 0.38)
		else
			tab.label:SetTextColor(hot and 0.80 or 0.62, hot and 0.86 or 0.68, hot and 0.83 or 0.65)
		end
	end
end

-- THE LIT TAB FOLLOWS THE THEME (Josh 2026-09-22). A tab takes the selection
-- colour when it is drawn and when the cursor is on it, and nowhere else - so
-- picking a new colour left the tab you were on wearing the old one until you
-- moved the mouse over it. The theme says when it has changed; this is the
-- rail listening.
function W.Retint()
	for _, tab in ipairs(tabs or {}) do
		if tab.key then
			tabTint(tab, W.LitTab() == tab.key, false)
		end
	end
end

if BT.Theme and BT.Theme.Register then
	BT.Theme.Register(function()
		W.Retint()
	end)
end

local function makeTab(i)
	local tab = tabs[i]
	if tab then
		return tab
	end
	tab = CreateFrame("Button", nil, rail.area or rail)
	tab:SetSize(RAIL - 12, TAB_H)
	tab.fill = tab:CreateTexture(nil, "BACKGROUND")
	tab.fill:SetAllPoints()
	tab.fill:SetColorTexture(0, 0, 0, 0)
	-- the mark is the only bright thing on the rail: it says where you are
	tab.mark = tab:CreateTexture(nil, "ARTWORK")
	tab.mark:SetPoint("TOPLEFT", 0, 0)
	tab.mark:SetPoint("BOTTOMLEFT", 0, 0)
	tab.mark:SetWidth(3)
	BT.Widgets.Lit(tab.mark)
	tab.mark:Hide()
	tab.label = tab:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	tab.label:SetPoint("LEFT", 14, 0)
	tab.label:SetJustifyH("LEFT")
	-- A GRIP ON HOVER (Josh 2026-09-22): an up and a down chevron at the right
	-- of a tab that can be moved, only while you point at it.
	tab.grip = {}
	for n, up in ipairs({ true, false }) do
		local g = tab:CreateTexture(nil, "OVERLAY")
		g:SetSize(10, 10)
		g:SetPoint("RIGHT", tab, "RIGHT", -6, up and 4 or -4)
		g:SetTexture(BT.Bar.ICONS)
		BT.Bar.ChevronCoord(g, up)
		g:SetVertexColor(0.55, 0.63, 0.59, 0.9)
		g:Hide()
		tab.grip[n] = g
	end
	tab:SetScript("OnEnter", function(self)
		W.ShowGrip(self, self.group == "dock" and self.key ~= "dock")
		tabTint(self, W.LitTab() == self.key, true)
	end)
	tab:SetScript("OnLeave", function(self)
		if not self.dragging then
			W.ShowGrip(self, false)
		end
		tabTint(self, W.LitTab() == self.key, false)
	end)
	tab:SetScript("OnClick", function(self)
		-- letting go of a drag is not a click on the tab it was
		if self.dragged then
			self.dragged = false
			return
		end
		W.SetView(self.key)
	end)
	-- DRAGGED INTO YOUR ORDER (Josh 2026-09-22). The tab follows the cursor
	-- and lands where its middle is when you let go; the dock follows the
	-- same order. Only the Panel group moves: its order is the dock's, and
	-- the order of the game frames means nothing.
	tab:SetMovable(true)
	tab:RegisterForDrag("LeftButton")
	tab:SetScript("OnDragStart", function(self)
		if self.group ~= "dock" or self.key == "dock" then
			return
		end
		self.dragged, self.dragging = true, true
		self:SetFrameLevel(((rail.area or rail):GetFrameLevel() or 1) + 10)
		self:StartMoving()
		-- AND A LINE WHERE IT WILL LAND (Josh 2026-09-22), following the tab
		-- as it moves: the same arithmetic the drop uses, so the line and the
		-- landing never disagree
		self:SetScript("OnUpdate", function(me)
			W.MarkDrop(W.Landing(me))
		end)
	end)
	tab:SetScript("OnDragStop", function(self)
		if not self.dragged then
			return
		end
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		self:StopMovingOrSizing()
		W.MarkDrop(nil)
		W.ShowGrip(self, false)
		W.Drop(self)
		-- the click that follows a release lands in this same frame, if it
		-- lands at all: the tab has just been moved out from under the cursor,
		-- so most drops get no click - and without this the NEXT real click on
		-- the tab was the one swallowed
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function() self.dragged = false end)
		else
			self.dragged = false
		end
	end)
	tabs[i] = tab
	return tab
end

-- Where a dragged tab lands: the number of module tabs whose middle is above
-- its own, plus one. Pure arithmetic on centres, so the tests can drive it.
function W.DropIndex(y, others)
	local above = 0
	for _, oy in ipairs(others) do
		if oy > y then
			above = above + 1
		end
	end
	return above + 1
end

-- the chevrons on a tab, up or away
function W.ShowGrip(tab, on)
	for _, g in ipairs(tab.grip or {}) do
		g:SetShown(on and true or false)
	end
end

-- Where a dragged tab would land right now: its place among the other Panel
-- tabs, and those tabs top to bottom (the rail's own order).
function W.Landing(tab)
	local _, y = tab:GetCenter()
	local centres, list = {}, {}
	for _, t in ipairs(tabs) do
		if t ~= tab and t:IsShown() and t.key and t.group == "dock" and t.key ~= "dock" then
			local _, oy = t:GetCenter()
			if type(oy) == "number" then
				centres[#centres + 1] = oy
				list[#list + 1] = t
			end
		end
	end
	if type(y) ~= "number" then
		return nil, list
	end
	return W.DropIndex(y, centres), list
end

-- The line in the gap the tab would drop into: above the tab it would land
-- before, or under the last one. Its own frame, above the tabs, because a
-- texture on the rail draws underneath them.
function W.MarkDrop(index, list)
	if not rail then
		return
	end
	local area = rail.area or rail
	if not rail.drop then
		rail.drop = CreateFrame("Frame", nil, area)
		rail.drop:SetHeight(2)
		rail.drop:SetFrameLevel((area:GetFrameLevel() or 1) + 20)
		rail.drop.line = rail.drop:CreateTexture(nil, "OVERLAY")
		rail.drop.line:SetAllPoints()
		BT.Widgets.Lit(rail.drop.line)
		rail.drop:Hide()
	end
	local target = index and list and (list[index] or list[#list])
	if not target then
		rail.drop:Hide()
		return
	end
	-- the gap between two tabs is TAB_STRIDE - TAB_H tall; the line sits in it
	local y
	if list[index] then
		y = target.railY + (TAB_STRIDE - TAB_H) / 2 + 1
	else
		y = target.railY - TAB_H - (TAB_STRIDE - TAB_H) / 2 + 1
	end
	rail.drop:ClearAllPoints()
	rail.drop:SetPoint("TOPLEFT", area, "TOPLEFT", 6, y)
	rail.drop:SetPoint("TOPRIGHT", area, "TOPRIGHT", -6, y)
	rail.drop:Show()
	rail.drop.at = y
end

-- A tab moved before one tab or after another: a shared page moves its
-- modules together, in their order, and lands by the other's first or last
function W.MoveTab(key, beforeTab, afterTab)
	local moving = W.MembersOf(key)
	local beforeKey = beforeTab and W.MembersOf(beforeTab)[1]
	local afterMembers = afterTab and W.MembersOf(afterTab)
	local afterKey = afterMembers and afterMembers[#afterMembers]
	if not moving[1] then
		return false
	end
	BT.MoveModuleNextTo(moving[1], beforeKey, afterKey)
	for i = 2, #moving do
		BT.MoveModuleNextTo(moving[i], nil, moving[i - 1])
	end
	return true
end

function W.Drop(tab)
	local index, list = W.Landing(tab)
	if index then
		-- before the tab it landed above, or after the last one: named, not
		-- numbered, because the rail shows only some of the modules and a
		-- number counts all of them
		local before = list[index]
		local after = (not before) and list[#list] or nil
		W.MoveTab(tab.key, before and before.key, after and after.key)
	end
	-- the rail re-anchors every tab, the dragged one included
	W.Rebuild()
	if BT.Bar then
		BT.Bar.Rebuild()
		BT.Bar.Relayout()
	end
end

-- Every page lives in this frame; only one is shown.
local panels = {}

-- which tab is lit: every page has a tab of its own now
function W.LitTab()
	return current
end

-- THE RAIL BY WHAT THINGS ARE FOR (Josh 2026-09-24: "organize all of these
-- so they make more logical sense"). It was grouped by where a thing sat -
-- in the dock, or not - which put the unit frames beside the chat and the
-- game menu beside the damage meter. Now:
--   Dock      the panel itself, and what is in it
--   Combat    what you watch in a fight
--   Windows   the game's own windows and menus, in the toolkit's clothes
--   People    the book: notes and tags, and the census
-- A module says which (`group`). A few share a page, a switch each (`onPage`):
-- the minimap and the addon buttons that sit on it, experience and
-- reputation, the two kinds of menu. The Dock and the Census have pages of
-- their own that are not one module's.
-- THE GROUPS ARE THE FEATURES (Josh 2026-09-27): six of them, each a block
-- of its own on the rail with its switch on its heading (BT.FEATURES).
W.GROUPS = {}
for _, f in ipairs(BT.FEATURES) do
	W.GROUPS[#W.GROUPS + 1] = { key = f.key, title = f.title, feature = f }
end

W.PAGES = {
	dock = { title = "Dock", group = "dock", fixed = true,
		blurb = "the panel at the side of the screen: its size, and what sits in its header" },
	map = { title = "Minimap", group = "dock", members = { "minimap", "buttons" },
		blurb = "the map in the dock, and the line of other addons' buttons" },
	progress = { title = "Progress", group = "dock", members = { "xp", "rep" },
		blurb = "your level and your standing, and roughly how long the rest will take" },
	allmenus = { title = "Menus", group = "interface", members = { "menu", "menus" },
		blurb = "the menu Escape opens, and every dropdown and right-click menu" },
	censusset = { title = "Census", group = "census", members = { "census" },
		blurb = "the realm's charts, in a window of their own" },
	-- TESTING (Josh 2026-09-24: "let's add a testing or debug section to
	-- the options panel, and move the options like this to it"): the
	-- made-up people and auras that let you see a frame while you are alone,
	-- and the addon's own reports - none of it a setting, all of it a look.
	-- Not one module's: under General, above the rail's line.
	testing = { title = "Testing", group = "general", fixed = true,
		blurb = "made-up people and auras to look at while you are alone, and the addon's own reports" },
}

-- A FEATURE'S OWN PAGE (Josh 2026-09-27): what it is, its switch, and a
-- switch for each of its parts with the way to that part's settings. One
-- for each feature with more than one page; a feature of one page is that
-- page.
for _, f in ipairs(BT.FEATURES) do
	if not f.single then
		W.PAGES["feature:" .. f.key] = { title = f.title, group = f.key, overview = f.key, blurb = f.line }
	end
end

function W.Page(key)
	return W.PAGES[key]
end

-- the page a feature's heading opens: its own page, or its one page
function W.HeadTab(fkey)
	local f = BT.Feature(fkey)
	if not f then
		return nil
	end
	if f.single then
		return W.GroupKeys(fkey)[1]
	end
	return "feature:" .. fkey
end

-- is this the page a feature's heading opens
function W.IsHead(key)
	local g = key and W.Group(key)
	return g ~= nil and g ~= "general" and W.HeadTab(g) == key
end

-- the modules behind a tab: a shared page's, or the one module
function W.MembersOf(key)
	local page = W.PAGES[key]
	if page then
		return page.members or {}
	end
	return { key }
end

-- a tab's name: a page's, or its module's
function W.TitleOf(key)
	local page = W.PAGES[key]
	if page then
		return page.title
	end
	local m = BT.GetModule(key)
	return m and m.title or key
end

-- on, for a tab: any of its modules is (the Dock page always is)
function W.TabOn(key)
	if key == "settings" then
		return true
	end
	local page = W.PAGES[key]
	if page and page.overview then
		return BT.FeatureOn(page.overview)
	end
	if page and page.fixed then
		return true
	end
	for _, k in ipairs(W.MembersOf(key)) do
		if BT.Enabled(k) then
			return true
		end
	end
	return false
end

-- which group of the rail a tab is in, or nil for a module with no tab of its
-- own (one on a shared page, a part of Metrics, the Clock on the Dock page)
function W.Group(key)
	if key == "settings" then
		return "general"
	end
	local page = W.PAGES[key]
	if page then
		return page.group
	end
	local m = BT.GetModule(key)
	local feature = m and BT.FeatureOf(m)
	-- (standalone: the clock, switched on the Dock's page, with no tab)
	if not m or m.part or m.onPage or m.standalone or not feature or not BT.ClassFits(m) then
		return nil
	end
	return feature
end

-- the tab a module's settings are on
function W.TabFor(key)
	local m = BT.GetModule(key)
	if m and m.part and W.Group(m.part) then
		return m.part
	end
	if m and m.onPage and W.PAGES[m.onPage] then
		return m.onPage
	end
	if key == "clock" then
		return "dock"
	end
	return key
end

-- older names for two of the groups' questions, which the tests still ask
function W.OnRail(key)
	return W.Group(W.TabFor(key)) == "dock"
end

function W.InSettings(key)
	local g = W.Group(W.TabFor(key))
	return g ~= nil and g ~= "dock" and g ~= "general"
end

-- the tabs of one group. The Dock's in the dock's own order - which you set
-- by dragging - with its own page first; the others A to Z by name: nothing
-- is stacked by them, so their order only has to be easy to find things in
function W.GroupKeys(group)
	local out, seen = {}, {}
	if group == "dock" then
		out[1], seen.dock = "dock", true
	end
	for _, m in ipairs(BT.Modules()) do
		local tab = W.TabFor(m.key)
		if not seen[tab] and W.Group(tab) == group then
			seen[tab] = true
			out[#out + 1] = tab
		end
	end
	if group ~= "dock" then
		table.sort(out, function(a, b)
			return tostring(W.TitleOf(a)):lower() < tostring(W.TitleOf(b)):lower()
		end)
	end
	return out
end

-- A page's header: its name, what it is, and - for a module - its switch,
-- with the word beside it. Everything under the header is the page's body.
local function header(panel, title, blurb)
	panel.enableLabel = panel:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	panel.enableLabel:SetPoint("TOPLEFT", 2, -2)
	panel.enableLabel:SetText(title or "")
	panel.enableBlurb = BT.Widgets.Label(panel, blurb or "", "small", 0.50, 0.55, 0.53)
	panel.enableBlurb:SetPoint("TOPLEFT", 2, -22)
	BT.Widgets.Divider(panel, 0, -(HEADER_H - 12))
	-- AND ITS BODY SCROLLS (Josh 2026-09-24): a page longer than the window
	-- - the unit frames', the tracker's - is a wheel away, not cut off at the
	-- foot. What a page builds goes on the strip (see W.Scroller).
	panel.view = BT.Widgets.Scroller(panel, 6)
	panel.view:SetPoint("TOPLEFT", 0, -HEADER_H)
	panel.view:SetPoint("BOTTOMRIGHT", 0, 0)
	panel.body = panel.view.content
end

-- the toolkit's own page: General
local function generalPage()
	local panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels.settings = panel
	header(panel, "General", "the look of every panel in the toolkit")
	-- the name the tests and older code know it by
	panel.toolkit = panel.body
	BT.Settings.Build(panel.body)
	return panel
end

-- A SHARED PAGE: a switch for each of its modules, and under it each one's
-- own settings while it is on, under its name.
local BLOCK_HEAD = 20
local function sharedPage(panel, page)
	local st = BT.Widgets.Stack(panel.body)
	local show = st:Section("Show")
	panel.switches = {}
	local function relayout()
		st:Layout()
	end
	panel.Relayout = relayout
	for _, key in ipairs(page.members) do
		local m = BT.GetModule(key)
		if m and BT.ClassFits(m) then
			local r = BT.Widgets.SwitchRow(show, m.title, m.blurb,
				function() return BT.Enabled(key) end,
				function(on)
					BT.SetEnabled(key, on)
					W.SyncTab(key)
					relayout()
				end)
			r.module = key
			panel.switches[#panel.switches + 1] = r
			local block = CreateFrame("Frame", nil, panel.body)
			block.head = block:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
			block.head:SetPoint("TOPLEFT", 2, 0)
			block.head:SetText(string.upper(m.title or key))
			BT.Widgets.TintText(block.head, 0.8)
			block.body = CreateFrame("Frame", nil, block)
			block.body:SetPoint("TOPLEFT", 0, -BLOCK_HEAD)
			block.body:SetPoint("TOPRIGHT", 0, -BLOCK_HEAD)
			block.body:SetHeight(1)
			BT.CallHook(m, "BuildTab", block.body)
			block.Layout = function(self)
				local h = BT.Enabled(key) and (block.body.beebsStackHeight or 0) or 0
				self:SetShown(h > 0)
				if h <= 0 then
					self:SetHeight(1)
					return 0
				end
				block.body:SetHeight(h)
				self:SetHeight(BLOCK_HEAD + h)
				return BLOCK_HEAD + h
			end
			st:Add(block)
		end
	end
	relayout()
end

-- the Dock's own page: the panel itself, and what sits in its header
local function dockPage(body)
	local st = BT.Widgets.Stack(body)
	body.stack = st
	local sizeSec = st:Section("Size")
	local size = BT.Widgets.Row(sizeSec, "Dock size", "the whole panel, from the header to the quests")
	local step = size:SetControl(BT.Widgets.Stepper(size, function(dir)
		local now = math.floor((BT.Bar.Scale() + dir * 0.05) * 100 + 0.5) / 100
		BT.Bar.SetScale(math.max(0.7, math.min(1.3, now)))
		W.RefreshDock()
	end))
	body.sizeText = step.value
	-- ONE WIDTH, WHATEVER IS IN IT (Josh 2026-09-24)
	local wide = BT.Widgets.Row(sizeSec, "Dock width", "the same with the quests or without them")
	local wstep = wide:SetControl(BT.Widgets.Stepper(wide, function(dir)
		BT.Bar.SetWidth(BT.Bar.Width() + dir * BT.Bar.WIDTH_STEP)
		W.RefreshDock()
	end))
	body.widthText = wstep.value
	-- (Josh 2026-09-24) where it stays, and how loud it is in a fight
	local feel = st:Section("Behaviour")
	BT.Widgets.SwitchRow(feel, "Lock in place", "no drag moves it · off, drag it by anything in it",
		function() return BT.Bar.Locked() end,
		function(on)
			BT.EnsureBound()
			BT.settings.dockLocked = on and true or nil
		end)
	local fade = BT.Widgets.Row(feel, "Fade in combat", "quieter while you fight · whole again under the pointer")
	body.fadeSeg = fade:SetControl(BT.Widgets.Segmented(fade, {
		{ "off", "Off" }, { "soft", "70%" }, { "strong", "40%" },
	}, function(key)
		BT.Bar.SetFade(key)
	end))
	local head = st:Section("Header")
	local clock = BT.Widgets.SwitchRow(head, "Clock", "the time in the header · click it for local or server",
		function() return BT.Enabled("clock") end,
		function(on)
			BT.EnsureBound()
			BT.SetEnabled("clock", on)
		end)
	clock.module = "clock"
	st:Layout()
	W.RefreshDock()
end

function W.RefreshDock()
	local panel = panels.dock
	local body = panel and panel.body
	if body and body.sizeText and BT.Bar and BT.Bar.Scale then
		body.sizeText:SetText(("%d%%"):format(math.floor(BT.Bar.Scale() * 100 + 0.5)))
	end
	if body and body.widthText and BT.Bar and BT.Bar.Width then
		body.widthText:SetText(tostring(BT.Bar.Width()))
	end
	if body and body.fadeSeg then
		body.fadeSeg:Select(BT.settings and BT.settings.dockFade or "off")
	end
end

-- the Census's page: its switch and the way into its window
local function censusPage(body)
	local st = BT.Widgets.Stack(body)
	st:Note("the realm's characters by class, race, level, tag and age, from everyone the book has seen")
	local sec = st:Section("Census")
	local on = BT.Widgets.SwitchRow(sec, "Census", "the charts, and their button in the dock's header",
		function() return BT.Enabled("census") end,
		function(v)
			BT.EnsureBound()
			BT.SetFeature("census", v)
			if not v and BT.CensusWindow then
				BT.CensusWindow.Hide()
			end
			if BT.Bar then
				BT.Bar.Relayout()
			end
			W.SyncTab("census")
		end)
	on.module = "census"
	BT.Widgets.SwitchRow(sec, "Button in the header", "the chart glyph beside the cog",
		function() return not (BT.settings and BT.settings.censusButton == false) end,
		function(v)
			BT.EnsureBound()
			-- off is written down, on (the default) is not: `(not v) and false or nil`
			-- was nil either way, and the switch could never turn it off (Josh 2026-09-25)
			if v then
				BT.settings.censusButton = nil
			else
				BT.settings.censusButton = false
			end
			if BT.Bar then
				BT.Bar.Relayout()
			end
		end)
	BT.Widgets.SwitchRow(sec, "Up to date while open", "the charts redrawn as the book fills · off, as they were when opened",
		function() return not (BT.settings and BT.settings.censusLive == false) end,
		function(v)
			BT.EnsureBound()
			-- off is written down, on (the default) is not: `(not v) and false or nil`
			-- was nil either way, and the switch could never turn it off (Josh 2026-09-25)
			if v then
				BT.settings.censusLive = nil
			else
				BT.settings.censusLive = false
			end
		end)
	local open = BT.Widgets.Row(sec, "Open the charts", "the same as the chart button in the header · /bt census")
	local b = open:SetControl(BT.Widgets.Button(open, "Open", 62, 20))
	b:SetScript("OnClick", function()
		if BT.CensusWindow then
			BT.CensusWindow.Show()
		end
	end)
	st:Layout()
end

-- the Testing page: things to look at, and things to ask
local function testingPage(body)
	local Wd = BT.Widgets
	local st = Wd.Stack(body)
	body.stack = st
	local look = st:Section("Look at")
	-- MADE-UP DATA (Josh 2026-09-27: "mock some data for me so we can show off
	-- all the features/designs"): every feature at once, for screenshots -
	-- nothing saved, and off again after a reload (Core/Demo.lua)
	body.demoRow = Wd.SwitchRow(look, "Made-up data", "a made-up realm in the census, notes in the ledger, a journal in the menagerie and a party · nothing is saved · /bt demo",
		function() return BT.Demo and BT.Demo.IsOn() or false end,
		function(on)
			if BT.Demo then
				BT.Demo.Set(on)
			end
		end)
	-- the unit frames' made-up group (Modules/Frames/Frames.lua)
	local people = Wd.Row(look, "Made-up people", "see the frames in a group while you are alone · needs Unit frames on")
	body.peopleSeg = people:SetControl(Wd.Segmented(people, {
		{ "off", "Off" }, { "party", "Party" }, { "raid", "Raid" },
	}, function(key)
		local m = BT.GetModule("frames")
		if m and m.Preview then
			m.Preview(key ~= "off" and key or nil)
		end
	end))
	-- the buff tray full (Modules/Frames/Buffs.lua)
	body.aurasRow = Wd.SwitchRow(look, "Made-up auras", "see the tray full: buffs, a weapon poison, debuffs · needs Buffs on",
		function()
			local B = BT.UnitFrames and BT.UnitFrames.Buffs
			return B and B.previewing or false
		end,
		function(on)
			local B = BT.UnitFrames and BT.UnitFrames.Buffs
			local m = BT.GetModule("buffs")
			if B and m and m.live then
				B.Build()
				B.Preview(on)
			end
		end)
	-- THE FIRST LOGIN (Josh 2026-09-25; six cards since 2026-09-27): the
	-- question a fresh install is asked, to see again
	local first = Wd.Row(look, "First login", "the question a fresh install is asked: six cards, a switch for each feature")
	body.firstButton = first:SetControl(Wd.Button(first, "Show", 62, 20))
	body.firstButton:SetScript("OnClick", function()
		if BT.Welcome then
			BT.Welcome.Show()
		end
	end)
	-- the reports /bt already writes, a click away; they go to your chat
	local ask = st:Section("Ask the addon")
	for _, c in ipairs({
		{ "debug", "What loaded", "the build, the book, every module, what the client refused" },
		{ "timers", "Over-time bars", "where the heal and damage bars got to, spell by spell" },
		{ "stats", "The book", "how many characters, how many packed, and the other books" },
	}) do
		local row = Wd.Row(ask, c[2], c[3] .. " · /bt " .. c[1])
		local run = row:SetControl(Wd.Button(row, "Show", 62, 20))
		run:SetScript("OnClick", function()
			local cmd = SlashCmdList and SlashCmdList.BEEBSTOOLKIT
			if cmd then
				cmd(c[1])
			end
		end)
	end
	-- what is showing now, whenever the page is opened
	body:HookScript("OnShow", function()
		local m = BT.GetModule("frames")
		body.peopleSeg:Select(m and m.previewing or "off")
		Wd.SyncRows()
	end)
	body.peopleSeg:Select("off")
	st:Layout()
end

-- the picture of a feature: its screenshot, or its colour and name until
-- there is one (BT.FEATURES[n].art)
local PIC_W, PIC_H = 320, 180
function W.Picture(parent, f, w, h)
	w, h = w or PIC_W, h or PIC_H
	local pic = CreateFrame("Frame", nil, parent)
	pic:SetSize(w, h)
	local c = f.color or { 0.6, 0.6, 0.6 }
	pic.fill = pic:CreateTexture(nil, "BACKGROUND")
	pic.fill:SetAllPoints()
	pic.fill:SetColorTexture(c[1] * 0.18, c[2] * 0.18, c[3] * 0.18, 0.95)
	pic.art = pic:CreateTexture(nil, "ARTWORK")
	pic.art:SetAllPoints()
	pic.name = pic:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	pic.name:SetPoint("CENTER", 0, 0)
	pic.name:SetText(f.title)
	pic.name:SetTextColor(c[1], c[2], c[3])
	if f.art then
		pic.art:SetTexture(f.art)
		pic.name:Hide()
	else
		pic.art:Hide()
	end
	pic.rim = BT.Pill.Panel and select(2, BT.Pill.Panel(pic, { 0, 0, 0, 0 }, BT.Widgets.HAIR))
	return pic
end

local function featurePage(panel, fkey)
	local f = BT.Feature(fkey)
	panel.feature = fkey
	panel.enable = BT.Widgets.Switch(panel, function(on)
		BT.SetFeature(fkey, on)
		W.SyncFeature(fkey)
	end)
	panel.enable:SetPoint("TOPRIGHT", -2, -4)
	panel.enableWord = BT.Widgets.Label(panel, "", "small", 0.50, 0.55, 0.53)
	panel.enableWord:SetPoint("RIGHT", panel.enable, "LEFT", -8, 0)
	panel.off = CreateFrame("Frame", nil, panel)
	panel.off:SetPoint("TOPLEFT", 0, -HEADER_H - 12)
	panel.off:SetPoint("TOPRIGHT", 0, -HEADER_H - 12)
	panel.off:SetHeight(40)
	panel.off.title = BT.Widgets.Label(panel.off, fkey == "dock" and "The Dock is off: its logo and cog stay"
		or ("%s is off"):format(f.title), nil, 0.72, 0.77, 0.75)
	panel.off.title:SetPoint("TOPLEFT", 2, 0)
	panel.off.blurb = BT.Widgets.Label(panel.off, "everything in it is off · what you chose inside it comes back with it",
		"small", 0.50, 0.55, 0.53)
	panel.off.blurb:SetPoint("TOPLEFT", 2, -18)
	local st = BT.Widgets.Stack(panel.body)
	local holder = CreateFrame("Frame", nil, panel.body)
	holder:SetHeight(PIC_H + 4)
	panel.picture = W.Picture(holder, f)
	panel.picture:SetPoint("TOPLEFT", 2, -2)
	st:Add(holder)
	local parts = st:Section("Parts")
	panel.partRows = {}
	for _, m in ipairs(BT.FeatureModules(fkey)) do
		if not m.part and BT.ClassFits(m) then
			local r = BT.Widgets.SwitchRow(parts, m.title, m.blurb,
				function() return BT.Switched(m.key) end,
				function(on)
					BT.SetEnabled(m.key, on)
					W.SyncTab(m.key)
				end)
			r.module = m.key
			r.go = BT.Widgets.Button(r, "Settings", 64, 18)
			r.go:SetPoint("RIGHT", r.switch, "LEFT", -8, 0)
			r.go:SetScript("OnClick", function()
				W.SetView(W.TabFor(m.key))
			end)
			panel.partRows[#panel.partRows + 1] = r
		end
	end
	st:Layout()
	W.SyncFeature(fkey)
end

-- a feature's switches in step: its page's, and its heading's on the rail
function W.SyncFeature(fkey)
	local on = BT.FeatureOn(fkey)
	local panel = panels["feature:" .. fkey]
	if panel and panel.enable then
		panel.enable:SetOn(on)
		panel.enableWord:SetText(on and "On" or "Off")
		panel.body:SetShown(on)
		panel.off:SetShown(not on)
	end
	W.PaintHeads()
end

local function pagePanel(key, page)
	local panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels[key] = panel
	header(panel, page.title, page.blurb)
	if page.overview then
		featurePage(panel, page.overview)
	elseif key == "dock" then
		dockPage(panel.body)
	elseif key == "censusset" then
		censusPage(panel.body)
	elseif key == "testing" then
		testingPage(panel.body)
	else
		sharedPage(panel, page)
	end
	return panel
end

local function panelFor(key)
	local panel = panels[key]
	if panel then
		return panel
	end
	if key == "settings" then
		return generalPage()
	end
	if W.PAGES[key] then
		return pagePanel(key, W.PAGES[key])
	end
	panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels[key] = panel
	local m = BT.GetModule(key)
	if not m then
		return panel
	end

	-- THE SWITCH BELONGS TO THE THING IT SWITCHES (Josh 2026-09-20). It sits
	-- at the top of the module's own page, and everything under it is the
	-- module's: with the switch off there is nothing under it to read,
	-- because a page of settings for a thing that is not running is a page
	-- of questions with no answers.
	header(panel, m.title, m.blurb)
	-- AND IT SAYS WHICH WAY IT IS (Josh 2026-09-23): the one switch on the
	-- page that governs all the others gets the word beside it
	-- a feature of one page IS this module: its switch is the feature's
	local fkey = BT.FeatureOf(m)
	local single = fkey and BT.Feature(fkey) and BT.Feature(fkey).single == key
	panel.enable = BT.Widgets.Switch(panel, function(on)
		if single then
			BT.SetFeature(fkey, on)
		else
			BT.SetEnabled(key, on)
		end
		W.SyncTab(key)
	end)
	panel.enable:SetPoint("TOPRIGHT", -2, -4)
	panel.enableWord = BT.Widgets.Label(panel, "", "small", 0.50, 0.55, 0.53)
	panel.enableWord:SetPoint("RIGHT", panel.enable, "LEFT", -8, 0)

	-- SAYING WHY IT IS EMPTY (Josh 2026-09-23): the body goes away with the
	-- switch off, as it always has, and a line says that is all it is
	panel.off = CreateFrame("Frame", nil, panel)
	panel.off:SetPoint("TOPLEFT", 0, -HEADER_H - 12)
	panel.off:SetPoint("TOPRIGHT", 0, -HEADER_H - 12)
	panel.off:SetHeight(40)
	panel.off.title = BT.Widgets.Label(panel.off, ("%s is off"):format(m.title), nil, 0.72, 0.77, 0.75)
	panel.off.title:SetPoint("TOPLEFT", 2, 0)
	panel.off.blurb = BT.Widgets.Label(panel.off, "its settings are kept for when it is back on",
		"small", 0.50, 0.55, 0.53)
	panel.off.blurb:SetPoint("TOPLEFT", 2, -18)

	BT.CallHook(m, "BuildTab", panel.body)
	W.SyncTab(key)
	return panel
end

-- The switch, the word, whether there is anything under it, and the name on
-- the rail, dimmed while it is off.
function W.SyncTab(key)
	local tab = W.TabFor(key)
	if tab ~= key then
		for _, t in ipairs(tabs or {}) do
			if t.key == tab then
				tabTint(t, W.LitTab() == tab, false)
			end
		end
		local shared = panels[tab]
		if shared and shared.Relayout then
			shared.Relayout()
		end
	end
	local panel = panels[key]
	if not (panel and panel.enable) then
		for _, t in ipairs(tabs or {}) do
			if t.key == key then
				tabTint(t, W.LitTab() == key, false)
			end
		end
		return
	end
	local on = BT.Enabled(key)
	panel.enable:SetOn(on)
	panel.enableWord:SetText(on and "On" or "Off")
	panel.body:SetShown(on)
	panel.off:SetShown(not on)
	for _, tab in ipairs(tabs or {}) do
		if tab.key == key then
			tabTint(tab, W.LitTab() == key, false)
		end
	end
end

function W.SetView(key)
	if not frame then
		return
	end
	-- the Census is not a page of this window any more
	if key == "census" then
		if BT.CensusWindow then
			BT.CensusWindow.Show()
		end
		return
	end
	-- a part (gold, bags, durability...) is switched from its owner's page, a
	-- module on a shared page from that, and the clock from the Dock's
	key = W.TabFor(key)
	if key ~= "settings" and not W.Group(key) then
		key = "settings"
	end
	current = key
	for _, panel in pairs(panels) do
		panel:Hide()
	end
	local shown = panelFor(key)
	shown:Show()
	-- a page that did not lay itself out on a Stack is measured as it opens
	-- (and again a frame later, once the client has placed what it holds)
	local view = shown.view
	if view and view.Fit and not view.stacked then
		view:Fit()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				view:Fit()
			end)
		end
	end
	for _, tab in ipairs(tabs) do
		if tab.key then
			tabTint(tab, tab.key == key, false)
		end
	end
	W.PaintHeads()
	BT.Widgets.SyncRows()
	if key == "settings" then
		BT.Settings.Refresh()
	elseif key == "dock" then
		W.RefreshDock()
	elseif W.PAGES[key] and W.PAGES[key].overview then
		W.SyncFeature(W.PAGES[key].overview)
	else
		W.SyncTab(key)
		for _, k in ipairs(W.MembersOf(key)) do
			local m = BT.GetModule(k)
			if m and BT.Enabled(k) then
				BT.CallHook(m, "ShowTab")
			end
		end
		local shared = panels[key]
		if shared and shared.Relayout then
			shared.Relayout()
		end
	end
end

function W.View()
	return current
end

-- A module's panel, built but not shown. The bar needs the Ledger's panel to
-- exist so it can open the note panel, and it used to get there by SHOWING the
-- window - so the first click on a name after a reload opened the toolkit as
-- well as the thing you asked for (Josh 2026-09-19).
function W.BuildPanel(key)
	W.Build()
	return panelFor(key)
end

-- where the rail's tabs may reach before they meet the line at its foot
local function railRoom()
	return WINDOW_H - TITLE_H - 8 - PAD - FOOT_H
end

-- A BLOCK FOR EACH FEATURE (Josh 2026-09-27: "make each section look more
-- distinct... right now it reads more as a big single list rather than
-- separate modules"). Its colour down the left edge and across its heading,
-- its switch on the heading, and its tabs inside it - none, while it is off:
-- "if disabled we should hide the sub options".
local BLOCK_HEAD, BLOCK_GAP, BLOCK_PAD, BLOCK_INDENT = 24, 7, 3, 6

local function block(fkey)
	rail.blocks = rail.blocks or {}
	local b = rail.blocks[fkey]
	if b then
		return b
	end
	local area = rail.area or rail
	b = CreateFrame("Frame", nil, area)
	b.key = fkey
	b.fill = b:CreateTexture(nil, "BACKGROUND")
	b.fill:SetAllPoints()
	b.edge = b:CreateTexture(nil, "BORDER")
	b.edge:SetPoint("TOPLEFT", 0, 0)
	b.edge:SetPoint("BOTTOMLEFT", 0, 0)
	b.edge:SetWidth(3)
	b.head = CreateFrame("Button", nil, b)
	b.head:SetPoint("TOPLEFT", 3, 0)
	b.head:SetPoint("TOPRIGHT", 0, 0)
	b.head:SetHeight(BLOCK_HEAD)
	b.head.band = b.head:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.head.band:SetAllPoints()
	b.head.label = b.head:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	b.head.label:SetPoint("LEFT", 7, 0)
	b.head.label:SetJustifyH("LEFT")
	b.head:SetScript("OnClick", function()
		W.SetView(W.HeadTab(fkey))
	end)
	b.head:SetScript("OnEnter", function(self)
		self.hot = true
		W.PaintHeads()
	end)
	b.head:SetScript("OnLeave", function(self)
		self.hot = false
		W.PaintHeads()
	end)
	b.switch = BT.Widgets.Switch(b.head, function(on)
		BT.SetFeature(fkey, on)
		W.SetView(W.HeadTab(fkey))
		W.SyncFeature(fkey)
	end)
	b.switch:SetPoint("RIGHT", b.head, "RIGHT", -4, 0)
	rail.blocks[fkey] = b
	return b
end

-- the headings' colours: lit where you are, bright while on, quiet while off
function W.PaintHeads()
	for fkey, b in pairs((rail and rail.blocks) or {}) do
		local f = BT.Feature(fkey)
		local c = f and f.color or { 0.6, 0.6, 0.6 }
		local on = BT.FeatureOn(fkey)
		local lit = W.LitTab() ~= nil and W.LitTab() == W.HeadTab(fkey)
		b.fill:SetColorTexture(c[1], c[2], c[3], on and 0.05 or 0)
		if on then
			b.edge:SetColorTexture(c[1], c[2], c[3], 0.9)
		else
			b.edge:SetColorTexture(0.30, 0.32, 0.30, 0.8)
		end
		local band = lit and 0.26 or (b.head.hot and 0.18 or (on and 0.11 or 0.03))
		b.head.band:SetColorTexture(c[1], c[2], c[3], band)
		if on then
			b.head.label:SetTextColor(0.92, 0.95, 0.93)
		else
			b.head.label:SetTextColor(0.46, 0.50, 0.48)
		end
		local single = f and f.single
		b.switch:SetOn(single and BT.Enabled(single) or (not single and on))
	end
end

-- The rail, whenever the list of modules changes.
function W.Rebuild()
	if not frame then
		return
	end
	local y, shown = -6, 0
	local area = rail.area or rail
	local function place(key, title, group, indent)
		indent = indent or 0
		shown = shown + 1
		local tab = makeTab(shown)
		tab.key, tab.title, tab.group = key, title, group
		tab.label:SetText(title)
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", area, "TOPLEFT", 6 + indent, y)
		tab:SetWidth(RAIL - 12 - indent)
		-- where it sits on the rail, for the drop line
		tab.railY = y
		tab:SetFrameLevel((area:GetFrameLevel() or 1) + 4)
		tab:Show()
		W.ShowGrip(tab, false)
		tabTint(tab, W.LitTab() == key, false)
		y = y - TAB_STRIDE
	end
	-- a group's name, small and quiet, over its tabs; made once per group
	rail.heads = rail.heads or {}
	rail.rules = rail.rules or {}
	local function heading(n, text)
		local h = rail.heads[n]
		if not h then
			h = area:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
			h:SetJustifyH("LEFT")
			rail.heads[n] = h
		end
		-- the first group sits under General's own line; the others get one
		if n > 1 then
			y = y - GROUP_GAP
			local rule = rail.rules[n]
			if not rule then
				rule = BT.Widgets.Divider(area, 10, 0)
				rail.rules[n] = rule
			end
			rule:ClearAllPoints()
			rule:SetPoint("TOPLEFT", area, "TOPLEFT", 10, y)
			rule:SetPoint("TOPRIGHT", area, "TOPRIGHT", -10, y)
			rule:Show()
			y = y - 4
		end
		h:SetText(string.upper(text))
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", area, "TOPLEFT", 20, y - 6)
		h:Show()
		y = y - GROUP_H
	end

	-- THE SETTINGS TAB IS NOT ONE OF THE UTILITIES (Josh 2026-09-20). It is
	-- the toolkit itself, so it goes above them with a line under it.
	place("settings", "General", "general")
	-- and Testing under it: the addon's too, not a utility's - a group of
	-- its own at the foot ran the rail past the window
	place("testing", W.TitleOf("testing"), "general")
	-- CENTRED IN THE GAP, AND UNDER NOTHING (Josh 2026-09-20). `place` leaves
	-- y one tab below where it drew, and a tab is shorter than its stride - so
	-- the tab it just drew ends that gap above y. The line went BELOW y once,
	-- which put it inside the bottom of the Settings tab: a tab is a child
	-- frame and draws over the rail's own regions, so hovering Settings
	-- painted its highlight straight over the line and it vanished.
	--
	-- One divider, kept: Rebuild runs every time a utility is switched on or
	-- off, and a new texture each time is a texture each time forever.
	local settingsBottom = y + (TAB_STRIDE - TAB_H)
	if not rail.seam then
		rail.seam = BT.Widgets.Divider(area, 10, 0)
	end
	rail.seam:ClearAllPoints()
	rail.seam:SetPoint("TOPLEFT", area, "TOPLEFT", 10, settingsBottom - 5)
	rail.seam:SetPoint("TOPRIGHT", area, "TOPRIGHT", -10, settingsBottom - 5)
	y = settingsBottom - 8

	-- A BLOCK EACH (see block): its heading always - the way to switch it
	-- back on - and its tabs only while it is on. Every module of a feature
	-- that is on has a tab, switched on or not: its own tab is where its
	-- switch is (Josh 2026-09-20).
	for _, g in ipairs(W.GROUPS) do
		local f = g.feature
		local keys = W.GroupKeys(f.key)
		if #keys > 0 then
			y = y - BLOCK_GAP
			local b = block(f.key)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", area, "TOPLEFT", 6, y)
			b:SetWidth(RAIL - 12)
			b:SetFrameLevel((area:GetFrameLevel() or 1) + 1)
			b.head.label:SetText(f.title)
			local top = y
			y = y - BLOCK_HEAD
			if BT.FeatureOn(f.key) and not f.single then
				y = y - BLOCK_PAD
				for _, key in ipairs(keys) do
					place(key, W.TitleOf(key), f.key, BLOCK_INDENT)
				end
				y = y + (TAB_STRIDE - TAB_H) - BLOCK_PAD
			end
			b:SetHeight(top - y)
			b:Show()
		elseif rail.blocks and rail.blocks[f.key] then
			rail.blocks[f.key]:Hide()
		end
	end
	W.PaintHeads()
	for i = shown + 1, #tabs do
		tabs[i]:Hide()
		tabs[i].key, tabs[i].group = nil, nil
	end
	-- how far down the last tab reaches, so a test can say the rail fits
	rail.reach = -(y + (TAB_STRIDE - TAB_H))
	-- and the strip is that tall: more than the rail holds, and it scrolls
	if rail.view then
		rail.view:SetContentHeight(rail.reach + 6)
	end
	-- the tab we were on may have just been folded away with its feature:
	-- its feature's own page then, where the switch to bring it back is
	local live = W.IsHead(W.LitTab())
	for i = 1, shown do
		if tabs[i].key == W.LitTab() then
			live = true
		end
	end
	if not live then
		local g = W.LitTab() and W.Group(W.LitTab())
		if g and g ~= "general" and BT.Feature(g) then
			W.SetView(W.HeadTab(g))
		else
			W.SetView(tabs[1] and tabs[1].key or "settings")
		end
	end
end

-- does every tab fit above the line at the rail's foot
function W.RailFits()
	return rail ~= nil and (rail.reach or 0) <= railRoom(), rail and rail.reach, railRoom()
end

function W.Build()
	if frame then
		return frame
	end
	tabs = {}
	frame = CreateFrame("Frame", "BeebModWindow", UIParent)
	frame:SetSize(WINDOW_W, WINDOW_H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	-- in front of the Census window when clicked or opened, never through it
	-- (see UI/CensusWindow.lua)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	-- moved a pixel at a time, an eighth clear of a tie (UI/Widgets.lua)
	BT.Widgets.PixelDrag(frame)
	frame:SetClampedToScreen(true)
	-- the theme's fill, nearly solid: see W.SOLID in UI/Widgets.lua
	BT.Widgets.Panel(frame, BT.Widgets.SOLID)
	tinsert(UISpecialFrames, "BeebModWindow") -- escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD + 4, -PAD)
	frame.title:SetText("|cff74c0fcBeeb|rMod")

	-- the realm, the faction and how many people are in the book: what this
	-- window is looking at, in the one place it never changes
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)
	W.UpdateSubtitle()

	-- THE WAY OUT (Josh 2026-09-21). Escape closes this and so does the cog
	-- that opened it, but a window with no visible way to shut it reads as
	-- stuck - and this one went missing when the struck-out letter came off
	-- the title, because it lived in the same few lines.
	frame.close = BT.Widgets.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() W.Hide() end)

	BT.Widgets.Divider(frame, PAD, -TITLE_H)

	rail = CreateFrame("Frame", nil, frame)
	rail:SetPoint("TOPLEFT", PAD - 4, -TITLE_H - 8)
	rail:SetPoint("BOTTOMLEFT", PAD - 4, PAD)
	rail:SetWidth(RAIL)
	-- THE TABS SCROLL (Josh 2026-09-24): every module has a tab, and the rail
	-- is only so tall. They sit on a strip in a window above the foot line,
	-- and the wheel moves the strip (UI/Widgets.lua, W.Scroller).
	rail.view = BT.Widgets.Scroller(rail)
	rail.view:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, 0)
	rail.view:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 0, FOOT_H)
	rail.area = rail.view.content

	-- THE VERSION, ONCE (Josh 2026-09-23). It was a line at the foot of the
	-- Settings tab that also repeated the header's character count; it is
	-- the foot of the rail now, where it is out of the way on every page.
	rail.foot = rail:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	rail.foot:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 20, 0)
	rail.foot:SetJustifyH("LEFT")

	local seam = frame:CreateTexture(nil, "ARTWORK")
	seam:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
	seam:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", 0, 0)
	seam:SetWidth(1)
	BT.Widgets.Rule(seam)

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", rail, "TOPRIGHT", PAD + 2, -4)
	content:SetPoint("BOTTOMRIGHT", -PAD - 2, PAD)

	W.Rebuild()
	W.UpdateFoot()
	-- A FRAME IS SHOWN THE MOMENT IT IS CREATED (Josh 2026-09-19). Building the
	-- window to get at a module's panel therefore OPENED the window, so the
	-- first click on the pencil after a reload brought up the toolkit as well
	-- as the note panel. Whoever wants it open says so.
	frame:Hide()
	return frame
end

-- Just the line under the title. A module repainting itself wants to update
-- this and nothing else: going through W.Refresh would call the module's own
-- Refresh straight back (Josh 2026-09-19 - that was a mutual recursion that
-- ran the search two hundred times per keystroke before the stack gave out,
-- and it read in game as the window being slow).
function W.UpdateSubtitle()
	if not frame then
		return
	end
	-- the realm and side always; how many characters only with a census
	local where = ("%s · %s"):format(BT.scope and BT.scope.realm or "?", BT.scope and BT.scope.faction or "?")
	if BT.DB and BT.db then
		where = ("%s · %d characters"):format(where, BT.DB.Stats(BT.db).total)
	end
	frame.subtitle:SetText(where)
end

-- the version, and whether the book came back the way it should
function W.UpdateFoot()
	if not (rail and rail.foot) then
		return
	end
	rail.foot:SetText(("%s · %s"):format(BT.VERSION or "?",
		BT.bakedTaken and "loaded from file" or "saved ok"))
end

local refreshing = false

local refreshBody

function W.Refresh()
	if not frame or refreshing then
		return
	end
	refreshing = true -- the backstop, whatever any module does in its Refresh
	-- and let go whatever happens: an error in here used to leave the latch
	-- set, and nothing refreshed the window again that session
	local ok, err = pcall(refreshBody)
	refreshing = false
	if not ok then
		BT.Err("window.Refresh: " .. tostring(err))
	end
end

refreshBody = function()
	W.UpdateSubtitle()
	W.UpdateFoot()
	if current and current ~= "settings" then
		-- the switch first, whether the module is live or not: its own tab is
		-- where a switched-off utility gets switched back on (Josh 2026-09-20)
		W.SyncTab(current)
		if current == "dock" then
			W.RefreshDock()
		end
		for _, k in ipairs(W.MembersOf(current)) do
			local m = BT.GetModule(k)
			if m and panels[current] and BT.Enabled(k) then
				BT.CallHook(m, "Refresh")
			end
		end
	elseif current == "settings" then
		BT.Settings.Refresh()
	end
end

function W.Show(view)
	-- the Census opens its own window, not this one
	if view == "census" then
		return BT.CensusWindow and BT.CensusWindow.Show()
	end
	W.Build()
	BT.EnsureBound()
	frame:Show()
	frame:Raise()
	-- a switched-off utility can still be opened: that is where its switch is
	if view and (view == "settings" or BT.GetModule(view) or W.PAGES[view]) then
		W.SetView(view)
	elseif not current then
		W.SetView(tabs[1] and tabs[1].key or "settings")
	end
	W.Refresh()
end

function W.Hide()
	if frame then
		frame:Hide()
	end
end

function W.IsShown()
	return frame and frame:IsShown() and true or false
end

function W.Toggle(view)
	if W.IsShown() and (not view or view == current) then
		W.Hide()
		return false
	end
	W.Show(view)
	return true
end

-- the tests reach in here rather than at the frames
function W.Frame() return frame end
function W.Tabs() return tabs end
-- the features' blocks on the rail, by feature
function W.Blocks() return (rail and rail.blocks) or {} end
-- the rail itself, for the tests: the line under Settings lives on it
function W.Rail() return rail end
function W.Panel(key) return panels[key] end
