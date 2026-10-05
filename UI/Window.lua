-- The one window, with General and the features down its left side (Josh
-- 2026-09-19; one page per feature since 2026-10-04).
--
-- AN OPINIONATED WINDOW (Josh 2026-10-04: "I think we need to seriously audit
-- and rework our options... it is getting too complicated. This addon is
-- supposed to be an opinionated solution, not fully customizable. I think we
-- should list only the top level modules on the left. The existing sub tabs
-- should be folded into the single module page, and cleaned up. I think we
-- really just need to be able to turn each feature on/off."). The design is
-- the settings canvas he locked the same day:
--
--   General       the colours, one size for every panel, and positions
--   INTERFACE     Dock, Unit frames, Game frames
--   JOURNALS      the Ravenholdt Ledger, Nesingwary's Expedition
--   Testing       under the features, in a copy to work on only: made-up
--                 data, reports and records
--
-- Every feature's page is the same: its name and a line on what it is, its
-- switch at the top right, then its parts, a switch each (a part of a part
-- indented under it), then any options, then the buttons that open its
-- windows. The Dock's parts are the dock's rows, top to bottom, and dragging
-- a row moves it in the dock. A feature that is off has its page dimmed, and
-- its name dimmed on the rail.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Window.lua")

local U = BT.Util
local W = {}
BT.Window = W

local RAIL, PAD = 148, 14
local TAB_H, TAB_STRIDE = 20, 22
-- the line at the foot of the rail, and a group's heading on it
local FOOT_H, GROUP_H = 16, 24
-- shorter than when the rail held every page: the pages scroll
local TITLE_H, WINDOW_W, WINDOW_H = 40, 760, 620
-- the page's own header: its name, a line or two under it, and its switch
local HEADER_H = 66
-- a part of a part sits this far in; a dock row leaves room for its grip
local SUB_IN, GRIP_IN = 18, 14
-- the search box in the title bar
local SEARCH_W, SEARCH_H = 190, 22

local frame, rail, content, tabs, current
-- the words being searched for, while there are any, and as typed
local searching, searchText
-- every page lives in this frame; only one is shown
local panels = {}

-- ---------------------------------------------------------------------------
-- The rail
-- ---------------------------------------------------------------------------

-- the groups under their headings, in order (BT.FEATURES says which a
-- feature is in)
W.GROUPS = {
	{ key = "interface", title = "Interface" },
	{ key = "journals", title = "Journals" },
}

-- on, for a page: a feature that is on (and a one-module feature's module),
-- and General and Testing always
function W.TabOn(key)
	local f = BT.Feature(key)
	if not f then
		return true
	end
	return BT.FeatureOn(key) and (not f.single or BT.Switched(f.single))
end

local function tabTint(tab, on, hot)
	-- OFF IS DIMMED, NOT BADGED: a switched-off feature's name is quieter
	-- than the rest, and is still there to be switched back on
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
	if tab.pip then
		local c = tab.colour
		if c and not tab.off then
			tab.pip:SetColorTexture(c[1], c[2], c[3], 1)
		else
			tab.pip:SetColorTexture(0.23, 0.27, 0.25, 1)
		end
		tab.pip:SetShown(c ~= nil)
	end
end

-- THE LIT TAB FOLLOWS THE THEME (Josh 2026-09-22): picking a new colour
-- repaints the tab you are on at once
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
	-- a feature's own colour, a dot before its name (the first-login card's)
	tab.pip = tab:CreateTexture(nil, "ARTWORK")
	tab.pip:SetSize(6, 6)
	tab.pip:SetPoint("LEFT", 14, 0)
	tab.pip:Hide()
	tab.label = tab:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	tab.label:SetJustifyH("LEFT")
	tab:SetScript("OnEnter", function(self)
		tabTint(self, W.LitTab() == self.key, true)
	end)
	tab:SetScript("OnLeave", function(self)
		tabTint(self, W.LitTab() == self.key, false)
	end)
	tab:SetScript("OnClick", function(self)
		W.SetView(self.key)
	end)
	tabs[i] = tab
	return tab
end

-- which tab is lit: the page you are on, and none while the search's
-- results are in its place
function W.LitTab()
	return (not searching) and current or nil
end

-- THE TESTING PAGE IN A COPY TO WORK ON ONLY (Josh 2026-10-05: "is there a
-- way to disable it in production builds so normal users don't see it?"): on
-- the rail, in the search and as a page only while BT.DEV (Core/Init.lua)
function W.Testing()
	return BT.DEV == true
end

-- a page's name on the rail: General, Testing, or a feature's (its short name)
function W.TitleOf(key)
	if key == "settings" then
		return "General"
	elseif key == "testing" then
		return "Testing"
	end
	local f = BT.Feature(key)
	return f and (f.short or f.title) or key
end

-- THE PAGE A THING IS ON. A feature is its own page; a module is on its
-- feature's (a part of Metrics on the Dock's, the Census on the Ledger's);
-- anything else, General.
function W.TabFor(key)
	if key == "settings" or (key == "testing" and W.Testing()) or BT.Feature(key) then
		return key
	end
	local m = BT.GetModule(key)
	local f = m and BT.FeatureOf(m)
	return (f and BT.Feature(f)) and f or "settings"
end

-- the features of one group, in BT.FEATURES order
function W.GroupKeys(group)
	local out = {}
	for _, f in ipairs(BT.FEATURES) do
		if f.group == group then
			out[#out + 1] = f.key
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- A feature's page: what is on it
-- ---------------------------------------------------------------------------

-- THE WORDS ON A PART'S ROW, as the settings canvas has them. A module with
-- none here has no row of its own (the Ledger and the Expedition: their
-- switch is the feature's, and their parts are their own `Parts`).
W.LABELS = {
	clock = { "Clock", "In the header. Click it for local or server time." },
	minimap = { "Minimap", "The game's minimap, square" },
	buttons = { "Addon buttons", "Other addons' minimap buttons, in a line" },
	xp = { "Experience", "Your XP bar and time to level" },
	pvp = { "PvP", "Your PvP rank, and how far to the next" },
	rep = { "Reputation", "Your standing with the faction you watch" },
	metrics = { "Metrics", "Small readouts, three to a row" },
	currency = { "Gold" },
	bags = { "Bags" },
	durability = { "Durability" },
	itemlevel = { "Item level" },
	pickpocket = { "Pick Pocket" },
	speed = { "Movement speed" },
	performance = { "Performance" },
	tracker = { "Quest tracker", "The quests you track, lowest level first" },
	micro = { "Micro menu", "The game's menu buttons" },
	unitframes = { "Unit frames", "You, your target, focus and target of target" },
	buffs = { "Buffs", "Your buffs and debuffs, in a tray beside the dock" },
	nameplates = { "Nameplates", "Enemies with your damage over time. Needs the game's nameplates on." },
	resourcedisplay = { "Resource display", "Flat bars and combo points on the game's Personal Resource Display" },
	damagemeter = { "Damage meter", "The game's own meter, flat, with figures per second" },
	bars = { "Action bars", "Flat buttons with their hotkeys" },
	bagwindow = { "Bag window", "Flat bags, quality rings, and bag slots along the bottom" },
	charsheet = { "Character sheet", "Item level on every slot you wear" },
	chat = { "Chat", "Flat windows, short channel names and links you can copy" },
	tooltips = { "Tooltips", "Two lines on players and NPCs, in the corner" },
	gamemenu = { "Game menu", "The menu Escape opens" },
	dropdowns = { "Dropdown menus", "Dropdown and right-click menus" },
	census = { "Record everyone you see", "Class, race, level, guild and zone of each player, for the charts" },
}

-- the modules on a page, in the page's order (the Dock's is the dock's own,
-- worked out in dockModules)
W.PAGE_MODULES = {
	unitframes = { "unitframes", "buffs", "nameplates", "resourcedisplay", "damagemeter" },
	interface = { "bars", "bagwindow", "charsheet", "chat", "tooltips", "gamemenu", "dropdowns" },
	-- the Ledger's rank toasts are its line's (Modules/Ledger/Line.lua)
	ledger = { "census", "ledger", "ledgerline" },
	expedition = { "expedition" },
}

-- the options under a page's parts: few, and only where the canvas has them
W.OPTIONS = {
	dock = function()
		return {
			-- FADED IN COMBAT, ONE WAY (the audit: "One switch, 70%")
			{ label = "Fade in combat", blurb = "Shows again when you point at it",
				get = function() return BT.Dock.FadeLevel() < 1 end,
				set = function(on) BT.Dock.SetFade(on and "soft" or "off") end },
		}
	end,
}

-- the buttons that open a feature's windows
W.OPEN = {
	ledger = function()
		return {
			{ label = "Charts", blurb = "Who is on your realm, by class, race, level and guild", button = "Open",
				run = function() return BT.CensusWindow and BT.CensusWindow.Show("charts") end },
			{ label = "Find people", blurb = "By name, guild or a word you wrote", button = "Open",
				run = function() return BT.CensusWindow and BT.CensusWindow.Show("find") end },
		}
	end,
	expedition = function()
		return {
			{ label = "Journal", blurb = "Or click its line in the dock, or type /bt expedition", button = "Open",
				run = function() return BT.ExpeditionWindow and BT.ExpeditionWindow.Show() end },
		}
	end,
}

-- quiet lines at the foot of a page
W.FOOT = {
	-- THE WIKI'S CREDIT, ONCE (Josh 2026-09-28): most descriptions are the
	-- Warcraft Wiki's sentences, so CC BY-SA 3.0 asks for the source and the
	-- licence to be named - here, not under every enemy
	expedition = {
		"The journal's descriptions come from the Warcraft Wiki (warcraft.wiki.gg), some of them rewritten, "
			.. "under the CC BY-SA 3.0 licence.",
		"An enemy's abilities come from the VMaNGOS database (github.com/vmangos), under the GPL 2.0 licence.",
	},
}

-- whether a module's row is in the Dock's list now: a row of another feature
-- (the Expedition's line, the Ledger's) only while that feature
-- and its module are on
function W.DockPageLive(key)
	local m = BT.GetModule(key)
	local fkey = m and BT.FeatureOf(m)
	return m ~= nil and (not fkey or BT.FeatureOn(fkey)) and BT.Enabled(key) and BT.ClassFits(m)
end

-- the dock's rows, top to bottom, in the dock's order: the modules that stand
-- in it, but not the parts of one (the cells of Metrics)
local function dockModules()
	local out = {}
	for _, m in ipairs(BT.Modules()) do
		if m.dock and not m.part then
			out[#out + 1] = m
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- A feature's page: building it
-- ---------------------------------------------------------------------------

-- A page's header: its name, what it is, and - for a feature - its switch,
-- with the word beside it. Everything under the header is the page's body.
local function header(panel, title, blurb)
	panel.enableLabel = panel:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	panel.enableLabel:SetPoint("TOPLEFT", 2, -2)
	panel.enableLabel:SetText(title or "")
	-- a line or two, kept clear of the switch at the right
	panel.enableBlurb = BT.Widgets.Label(panel, blurb or "", "small", 0.50, 0.55, 0.53)
	panel.enableBlurb:SetPoint("TOPLEFT", 2, -22)
	panel.enableBlurb:SetPoint("RIGHT", panel, "RIGHT", -96, 0)
	panel.enableBlurb:SetJustifyH("LEFT")
	panel.enableBlurb:SetWordWrap(true)
	BT.Widgets.Divider(panel, 0, -(HEADER_H - 12))
	-- AND ITS BODY SCROLLS (Josh 2026-09-24): a page longer than the window is
	-- a wheel away, not cut off at the foot (see W.Scroller)
	panel.view = BT.Widgets.Scroller(panel, 6)
	panel.view:SetPoint("TOPLEFT", 0, -HEADER_H)
	panel.view:SetPoint("BOTTOMRIGHT", 0, 0)
	panel.body = panel.view.content
end

-- A JOURNAL'S LINE, IN ITS KEEPER'S VOICE (Josh 2026-10-04: "add a clever
-- description in the existing interfaces"; the name "right aligned and
-- prefixed with '- '"). For a Stack: it measures itself.
local function quote(parent, text, by)
	local f = CreateFrame("Frame", nil, parent)
	f.text = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	f.text:SetPoint("TOPLEFT", 2, 0)
	f.text:SetPoint("TOPRIGHT", -2, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(true)
	f.text:SetTextColor(0.76, 0.82, 0.80)
	f.text:SetText(text or "")
	f.by = f:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	f.by:SetPoint("TOPRIGHT", f.text, "BOTTOMRIGHT", 0, -4)
	f.by:SetJustifyH("RIGHT")
	f.by:SetTextColor(0.50, 0.55, 0.53)
	f.by:SetText(by and ("- " .. by) or "")
	f.Measure = function(self)
		local w = BT.Pill.Number(self:GetWidth(), 0)
		if w <= 0 then
			w = WINDOW_W - RAIL - PAD * 4
		end
		self.text:SetWidth(w - 4)
		local h = BT.Pill.Number(self.text:GetStringHeight(), 14) + 4 + 14
		self:SetHeight(h)
		return h
	end
	return f
end

-- every row of the page you are on: its switch, and dimmed while what it
-- belongs to is off. A row of the search's results says which feature it is
-- in, and is hidden when it does not match.
local function paintRows(panel)
	for _, r in ipairs(panel.rows or {}) do
		local fkey = r.feature or panel.feature
		local featureOn = not fkey or BT.FeatureOn(fkey)
		local on = true
		if r.get then
			local ok, v = pcall(r.get)
			on = ok and v and true or false
		end
		local under = r.under
		local underOn = true
		if under and under.get then
			local ok, v = pcall(under.get)
			underOn = ok and v and true or false
		end
		r:SetAlpha((featureOn and underOn) and 1 or 0.45)
		if r.live ~= nil or r.match ~= nil then
			r:SetShown(r.match ~= false and (r.live == nil or r.live()))
		end
		r.on = on
	end
	if panel.enable then
		local fkey = panel.feature
		local on = W.TabOn(fkey)
		panel.enable:SetOn(on)
		panel.enableWord:SetText(on and "On" or "Off")
	end
end

-- a row on a page: a switch, a button, or (with neither) words only; `sub`
-- for a part of the row above, in the smaller face
local function addRow(panel, section, spec, indent, sub)
	local Wd = BT.Widgets
	local opts = { indent = indent > 0 and indent or nil, small = sub and true or false }
	local r
	if spec.button then
		r = Wd.Row(section, spec.label, spec.blurb or "", opts)
		r.go = r:SetControl(Wd.Button(r, spec.button, 70, 20))
		r.go:SetScript("OnClick", function()
			if spec.run then
				spec.run()
			end
		end)
	elseif spec.get then
		r = Wd.SwitchRow(section, spec.label, spec.blurb or "", spec.get, function(on)
			if spec.set then
				spec.set(on)
			end
			W.SyncPage()
		end, opts)
	else
		r = Wd.Row(section, spec.label, spec.blurb or "", opts)
	end
	r.get, r.spec = spec.get, spec
	r.module, r.live = spec.module, spec.live
	panel.rows[#panel.rows + 1] = r
	return r
end

-- a module's own row: its switch, in the words the canvas gives it
local function moduleSpec(m)
	local words = W.LABELS[m.key]
	if not words then
		return nil
	end
	return {
		label = words[1], blurb = words[2], module = m.key,
		get = function() return BT.Switched(m.key) end,
		set = function(on)
			BT.SetEnabled(m.key, on)
		end,
		-- a part for one class (Pick Pocket) only shows for that class
		live = m.class and function() return BT.ClassFits(m) end or nil,
	}
end

-- the parts of a part: Metrics' cells (modules that say `part`), then
-- whatever the module lists itself (M:Parts)
local function subSpecs(m)
	local out = {}
	local parts = {}
	for _, p in ipairs(BT.Modules()) do
		if p.part == m.key then
			parts[#parts + 1] = p
		end
	end
	table.sort(parts, function(a, b) return (a.order or 0) < (b.order or 0) end)
	for _, p in ipairs(parts) do
		local spec = moduleSpec(p)
		if spec then
			out[#out + 1] = spec
		end
	end
	if m.Parts then
		local ok, list = pcall(m.Parts, m)
		if ok and type(list) == "table" then
			for _, spec in ipairs(list) do
				out[#out + 1] = spec
			end
		end
	end
	return out
end

-- one module's rows: its own, then its parts under it. A module with no row
-- of its own puts its parts at the top level, each one a part of the row
-- above it where it says `sub`.
local function moduleRows(panel, section, m, indent, gripped)
	local top = moduleSpec(m)
	local group = {}
	local head
	if top then
		head = addRow(panel, section, top, indent)
		group[#group + 1] = head
	end
	local lastTop = head
	for _, spec in ipairs(subSpecs(m)) do
		local sub = head ~= nil or spec.sub
		local r = addRow(panel, section, spec, indent + (sub and SUB_IN or 0), sub)
		r.under = sub and lastTop or nil
		if not sub then
			lastTop = r
		end
		group[#group + 1] = r
	end
	if gripped and head then
		W.Grip(panel, head, m.key)
	end
	return group
end

-- The dock's rows into a section: the clock in the header, then each row of
-- the dock, top to bottom. On the Dock's page each row has a grip to drag it
-- by (`gripped`); the search's results list the same rows without one. Gives
-- back the clock's rows, and each dock row's group.
local function dockRows(panel, sec, indent, gripped)
	local clockRows, groups = nil, {}
	local clock = BT.GetModule("clock")
	if clock then
		clockRows = moduleRows(panel, sec, clock, indent, false)
	end
	for _, m in ipairs(dockModules()) do
		local group
		if BT.FeatureOf(m) == "dock" then
			group = moduleRows(panel, sec, m, indent, gripped)
		elseif m.DockRow then
			-- another feature's row in the dock: its own switch for the row, and
			-- there only while that feature and its module are on
			local ok, spec = pcall(m.DockRow, m)
			if ok and type(spec) == "table" then
				spec.live = function() return W.DockPageLive(m.key) end
				local r = addRow(panel, sec, spec, indent)
				if gripped then
					W.Grip(panel, r, m.key)
				end
				group = { r }
			end
		end
		if group and #group > 0 then
			groups[#groups + 1] = { key = m.key, rows = group }
		end
	end
	return clockRows, groups
end

-- the Dock's list: the clock in the header, then each row of the dock
local function dockSection(panel, st)
	local sec = st:Section("Parts, top to bottom")
	sec.aside = sec:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	sec.aside:SetPoint("TOPRIGHT", -2, 0)
	sec.aside:SetText("Drag a row to move it in the dock")
	panel.dockSection = sec
	panel.dockClock, panel.dockGroups = dockRows(panel, sec, GRIP_IN, true)
	return sec
end

local function featurePage(panel, fkey)
	local f = BT.Feature(fkey)
	panel.feature = fkey
	panel.rows = {}
	panel.enable = BT.Widgets.Switch(panel, function(on)
		BT.SetFeature(fkey, on)
		W.SyncPage()
	end)
	panel.enable:SetPoint("TOPRIGHT", -2, -4)
	panel.enableWord = BT.Widgets.Label(panel, "", "small", 0.50, 0.55, 0.53)
	panel.enableWord:SetPoint("RIGHT", panel.enable, "LEFT", -8, 0)
	local st = BT.Widgets.Stack(panel.body)
	panel.stack = st
	if f.quote then
		panel.quote = st:Add(quote(panel.body, f.quote, f.by))
	end
	if fkey == "dock" then
		dockSection(panel, st)
	else
		local parts = st:Section("Parts")
		for _, key in ipairs(W.PAGE_MODULES[fkey] or {}) do
			local m = BT.GetModule(key)
			if m then
				moduleRows(panel, parts, m, 0, false)
			end
		end
	end
	local options = W.OPTIONS[fkey] and W.OPTIONS[fkey]() or nil
	if options then
		local sec = st:Section("Options")
		for _, spec in ipairs(options) do
			addRow(panel, sec, spec, 0)
		end
	end
	local open = W.OPEN[fkey] and W.OPEN[fkey]() or nil
	if open then
		local sec = st:Section("Open")
		for _, spec in ipairs(open) do
			addRow(panel, sec, spec, 0)
		end
	end
	for _, line in ipairs(W.FOOT[fkey] or {}) do
		st:Note(line, true)
	end
	paintRows(panel)
	st:Layout()
end

-- ---------------------------------------------------------------------------
-- Dragging a dock row
-- ---------------------------------------------------------------------------
--
-- THE DOCK'S ORDER ON ITS OWN PAGE (Josh 2026-10-04: "Still need to be able
-- to rearrange the dock (under the dock page options, not in the sidebar)").
-- A row of the Dock's list follows the pointer while dragged, a line marks
-- where it will land, and it lands where its middle is when you let go; the
-- dock stacks its sections in the same order. A row's parts go with it.

-- Where a dragged row lands: the number of rows whose middle is above its
-- own, plus one. Pure arithmetic on centres, so the tests can drive it.
function W.DropIndex(y, others)
	local above = 0
	for _, oy in ipairs(others) do
		if oy > y then
			above = above + 1
		end
	end
	return above + 1
end

-- the other draggable rows, top to bottom, with their middles
local function dockHeads(panel, except)
	local list, centres = {}, {}
	for _, g in ipairs(panel.dockGroups or {}) do
		local head = g.rows[1]
		if head ~= except and head:IsShown() then
			local _, y = head:GetCenter()
			if type(y) == "number" then
				list[#list + 1] = g
				centres[#centres + 1] = y
			end
		end
	end
	return list, centres
end

-- where a dragged row would land now, and the rows it is placed among
function W.Landing(panel, row)
	local list, centres = dockHeads(panel, row)
	local _, y = row:GetCenter()
	if type(y) ~= "number" then
		return nil, list
	end
	return W.DropIndex(y, centres), list
end

-- the line in the gap the row would drop into
function W.MarkDrop(panel, index, list)
	if not panel.drop then
		panel.drop = CreateFrame("Frame", nil, panel.body)
		panel.drop:SetHeight(2)
		panel.drop.line = panel.drop:CreateTexture(nil, "OVERLAY")
		panel.drop.line:SetAllPoints()
		BT.Widgets.Lit(panel.drop.line)
		panel.drop:Hide()
	end
	local target = index and list and (list[index] or list[#list])
	if not target then
		panel.drop:Hide()
		return
	end
	local head = target.rows[1]
	local last = target.rows[#target.rows]
	panel.drop:ClearAllPoints()
	if list[index] then
		panel.drop:SetPoint("BOTTOMLEFT", head, "TOPLEFT", 4, -1)
		panel.drop:SetPoint("BOTTOMRIGHT", head, "TOPRIGHT", -4, -1)
	else
		panel.drop:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, 1)
		panel.drop:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", -4, 1)
	end
	panel.drop:SetFrameLevel(BT.Pill.Number(panel.body:GetFrameLevel(), 1) + 20)
	panel.drop:Show()
end

-- the rows of the Dock's list put back in the dock's order, and laid out
function W.Reorder(panel)
	local sec = panel and panel.dockSection
	if not sec then
		return
	end
	local rank = {}
	for i, m in ipairs(BT.Modules()) do
		rank[m.key] = i
	end
	table.sort(panel.dockGroups, function(a, b)
		return (rank[a.key] or 0) < (rank[b.key] or 0)
	end)
	sec.rows = {}
	for _, r in ipairs(panel.dockClock or {}) do
		sec.rows[#sec.rows + 1] = r
	end
	for _, g in ipairs(panel.dockGroups) do
		for _, r in ipairs(g.rows) do
			sec.rows[#sec.rows + 1] = r
		end
	end
	panel.stack:Layout()
end

-- a row moved before one row or after another
function W.Drop(panel, row, key)
	local index, list = W.Landing(panel, row)
	if index then
		local before = list[index]
		local after = (not before) and list[#list] or nil
		BT.MoveModuleNextTo(key, before and before.key, after and after.key)
	end
	W.Reorder(panel)
	if BT.Dock then
		BT.Dock.Rebuild()
		BT.Dock.Relayout()
	end
end

-- a grip at the left of a dock row, and the row dragged by it
function W.Grip(panel, row, key)
	row.grip = {}
	for n, up in ipairs({ true, false }) do
		local g = row:CreateTexture(nil, "OVERLAY")
		g:SetSize(8, 8)
		g:SetPoint("LEFT", row, "LEFT", 5, up and 4 or -4)
		g:SetTexture(BT.Dock.ICONS)
		BT.Dock.ChevronCoord(g, up)
		g:SetVertexColor(0.55, 0.63, 0.59, 0.6)
		row.grip[n] = g
	end
	row.dockKey = key
	row:EnableMouse(true)
	row:SetMovable(true)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:SetFrameLevel(BT.Pill.Number(panel.body:GetFrameLevel(), 1) + 10)
		self:StartMoving()
		self:SetScript("OnUpdate", function(me)
			W.MarkDrop(panel, W.Landing(panel, me))
		end)
	end)
	row:SetScript("OnDragStop", function(self)
		if not self.dragging then
			return
		end
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		self:StopMovingOrSizing()
		W.MarkDrop(panel, nil)
		W.Drop(panel, self, key)
	end)
end

-- the Testing page: things to look at, and things to ask
local function testingPage(body)
	local Wd = BT.Widgets
	local st = Wd.Stack(body)
	body.stack = st
	local look = st:Section("Preview")
	-- MADE-UP DATA (Josh 2026-09-27: "mock some data for me so we can show off
	-- all the features/designs"): every feature at once, for screenshots -
	-- nothing saved, and off again after a reload (Core/Demo.lua)
	body.demoRow = Wd.SwitchRow(look, "Made-up data", "A made-up realm, notes, journal and party. None of it is saved.",
		function() return BT.Demo and BT.Demo.IsOn() or false end,
		function(on)
			if BT.Demo then
				BT.Demo.Set(on)
			end
		end)
	-- the unit frames' made-up group (Modules/UnitFrames/UnitFrames.lua)
	local people = Wd.Row(look, "Made-up people", "The unit frames as a group when you are alone. Needs Unit frames on.")
	body.peopleSeg = people:SetControl(Wd.Segmented(people, {
		{ "off", "Off" }, { "party", "Party" }, { "raid", "Raid" },
	}, function(key)
		local m = BT.GetModule("unitframes")
		-- only while Unit frames is on, as its line says (Josh 2026-09-30,
		-- review): switched off, the made-up group drew itself over the
		-- game's own frames. Off is always heard.
		if m and m.Preview and (key == "off" or m.live) then
			m.Preview(key ~= "off" and key or nil)
		end
	end))
	-- the buff tray full (Modules/UnitFrames/Buffs.lua)
	body.aurasRow = Wd.SwitchRow(look, "Made-up auras", "Fills the tray with buffs, a weapon poison and debuffs. Needs Buffs on.",
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
	-- THE FIRST LOGIN (Josh 2026-09-25; five cards since 2026-10-04): the
	-- question a fresh install is asked, to see again
	local first = Wd.Row(look, "First login", "The five cards a new install shows, one switch for each feature")
	body.firstButton = first:SetControl(Wd.Button(first, "Show", 62, 20))
	body.firstButton:SetScript("OnClick", function()
		if BT.Welcome then
			BT.Welcome.Show()
		end
	end)
	-- A SAMPLE NOTICE (Josh 2026-09-28; small since 2026-10-05): a made-up
	-- mastery on the Expedition's line in the dock and a commendation on the
	-- Ledger's, said as real ones are (UI/Notice.lua)
	local toast = Wd.Row(look, "Small notices", "A made-up mastery and commendation on the journals' lines in the dock")
	body.toastButton = toast:SetControl(Wd.Button(toast, "Show", 62, 20))
	body.toastButton:SetScript("OnClick", function()
		for _, key in ipairs({ "expedition", "ledgerline" }) do
			local m = BT.GetModule(key)
			if m and m.SampleNotice and BT.Enabled(key) then
				m.SampleNotice()
			end
		end
	end)
	-- and a new rank's, with its badge (Josh 2026-09-29) and its keeper's
	-- word (2026-10-05): each journal's, one after the other
	local rankToast = Wd.Row(look, "Rank toasts", "Your ranks, shown as if you had just reached them")
	body.rankToastButton = rankToast:SetControl(Wd.Button(rankToast, "Show", 62, 20))
	body.rankToastButton:SetScript("OnClick", function()
		for _, key in ipairs({ "expedition", "ledgerline" }) do
			local m = BT.GetModule(key)
			if m and m.SampleRankToast and BT.Enabled(key) then
				m.SampleRankToast()
			end
		end
	end)
	-- THE DOCK'S SHIELDS, ONE AT A TIME (Josh 2026-09-29: "I'd like to be
	-- able to preview the different icons for all 4 of these rows"). Each
	-- steps through what its shield can be, starting from your own; only the
	-- shields change, and a reload puts them back (BT.Dock.preview).
	local prev = st:Section("Preview the dock's shields")
	local STANDINGS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
	local previews = {
		{ key = "level", title = "Level", blurb = "Each ten-level bracket's rim, with the level on it",
			values = { 1, 10, 20, 30, 40, 50, 60 }, say = function(v) return "Level " .. v end },
		{ key = "standing", title = "Reputation", blurb = "The shield in each standing's colour",
			values = { 1, 2, 3, 4, 5, 6, 7, 8 }, say = function(v) return STANDINGS[v] end },
		{ key = "pvp", title = "PvP rank", blurb = "No rank, then the game's insignia for ranks 1 to 14",
			values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
			say = function(v) return v == 0 and "None" or ("Rank " .. v) end },
		{ key = "side", title = "PvP side", blurb = "The side's colour on the shield before the first rank",
			values = { "Alliance", "Horde" }, say = function(v) return v end },
		{ key = "expedition", title = "Expedition", blurb = "Each Expedition rank's badge",
			values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, say = function(v) return "Rank " .. v end },
		{ key = "ledger", title = "Ledger", blurb = "Each Ledger rank's badge",
			values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, say = function(v) return "Rank " .. v end },
	}
	body.previews = {}
	for _, p in ipairs(previews) do
		local row = Wd.Row(prev, p.title, p.blurb)
		-- 0 is your own; 1 onwards, the values in turn
		local at = 0
		local stepper
		stepper = row:SetControl(Wd.Stepper(row, function(dir)
			at = (at + dir) % (#p.values + 1)
			local v = at > 0 and p.values[at] or nil
			stepper:Say(v ~= nil and p.say(v) or "Yours")
			if BT.Dock and BT.Dock.SetPreview then
				BT.Dock.SetPreview(p.key, v)
			end
		end))
		stepper:Say("Yours")
		stepper.reset = function()
			at = 0
			stepper:Say("Yours")
		end
		body.previews[p.key] = stepper
	end
	local clear = Wd.Row(prev, "Clear previews", "Shows your own shields again")
	body.clearPreviews = clear:SetControl(Wd.Button(clear, "Clear", 62, 20))
	body.clearPreviews:SetScript("OnClick", function()
		for _, s in pairs(body.previews) do
			s.reset()
		end
		if BT.Dock and BT.Dock.ClearPreviews then
			BT.Dock.ClearPreviews()
		end
	end)
	-- BUTTONS, NOT COMMANDS (Josh 2026-09-28: "We don't need hundreds of
	-- slash commands for debugging. I'd actually prefer to use the 'Testing'
	-- module with buttons/toggles going forward"). The reports that were
	-- /bt debug, /bt timers and /bt stats; they go to your chat.
	local ask = st:Section("Reports")
	for _, c in ipairs({
		{ "whatButton", "What loaded", "Says in chat which modules loaded and what the game refused",
			function() BT.WhatLoaded() end },
		{ "timersButton", "Over-time bars", "Says in chat where each heal and damage bar got to, spell by spell",
			function()
				local T = BT.UnitFrames and BT.UnitFrames.Timers
				if T and T.Report then
					T.Report()
				end
			end },
		{ "statsButton", "Saved characters", "Says in chat how many characters BeebMod has saved",
			function() BT.StatsReport() end },
	}) do
		local row = Wd.Row(ask, c[2], c[3])
		local run = row:SetControl(Wd.Button(row, "Show", 62, 20))
		run:SetScript("OnClick", c[4])
		body[c[1]] = run
	end
	-- RECORDS FOR CLAUDE (Josh 2026-09-28): what the frame dumps, the unit
	-- probe and /bt cpu wrote into the saved file, from three buttons. Each
	-- module's record is registered with BT.Record (Core/Init.lua).
	local rec = st:Section("Record for Claude")
	local record = Wd.Row(rec, "The game's frames", "Writes how the game built each part you have on into the saved file")
	body.recordButton = record:SetControl(Wd.Button(record, "Record", 62, 20))
	body.recordButton:SetScript("OnClick", function()
		local wrote, waits = BT.RecordAll()
		local line = ("Records: wrote %d into the saved file."):format(wrote)
		if #waits > 0 then
			local also = #waits == 1 and waits[1]
				or (table.concat(waits, ", ", 1, #waits - 1) .. " and " .. waits[#waits])
			line = line .. (" BeebMod also writes down %s."):format(also)
		end
		BT.Util.Print(line .. " Type /reload to save them.")
	end)
	local clear = Wd.Row(rec, "Records", "Takes every record out of the saved file")
	body.clearButton = clear:SetControl(Wd.Button(clear, "Clear", 62, 20))
	body.clearButton:SetScript("OnClick", function()
		BT.Util.Print(("Records: took %d out of the saved file."):format(BT.ClearRecords()))
	end)
	local cpu = Wd.Row(rec, "CPU use", ("Times BeebMod for %d seconds and lists the costliest parts in chat")
		:format(BT.Cpu.SECONDS))
	body.cpuButton = cpu:SetControl(Wd.Button(cpu, "Measure", 62, 20))
	body.cpuButton:SetScript("OnClick", function()
		BT.Cpu.Measure()
	end)
	-- what is showing now, whenever the page is opened
	body:HookScript("OnShow", function()
		local m = BT.GetModule("unitframes")
		body.peopleSeg:Select(m and m.previewing or "off")
		Wd.SyncRows()
	end)
	body.peopleSeg:Select("off")
	st:Layout()
end

-- the picture of a feature: its screenshot, or its colour and name until
-- there is one (BT.FEATURES[n].art)
local PIC_W, PIC_H = 320, 180
-- the picture is the left 455 of a 512-wide texture (a power of two each
-- way): scripts/make-feature-art.ps1
local FEATURE_ART_U = 455 / 512
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
		pic.art:SetTexCoord(0, FEATURE_ART_U, 0, 1)
		pic.name:Hide()
	else
		pic.art:Hide()
	end
	-- TWO PICTURES, SIDE BY SIDE (the Census and the Ledger, one feature since
	-- 2026-10-04): the left half of each, until there is one of both
	if f.art and f.art2 then
		pic.art:ClearAllPoints()
		pic.art:SetPoint("TOPLEFT", 0, 0)
		pic.art:SetPoint("BOTTOMRIGHT", pic, "BOTTOM", -1, 0)
		pic.art:SetTexCoord(0, FEATURE_ART_U / 2, 0, 1)
		pic.art2 = pic:CreateTexture(nil, "ARTWORK")
		pic.art2:SetPoint("TOPLEFT", pic, "TOP", 1, 0)
		pic.art2:SetPoint("BOTTOMRIGHT", 0, 0)
		pic.art2:SetTexture(f.art2)
		pic.art2:SetTexCoord(0, FEATURE_ART_U / 2, 0, 1)
	end
	pic.rim = BT.Pill.Panel and select(2, BT.Pill.Panel(pic, { 0, 0, 0, 0 }, BT.Widgets.HAIR))
	return pic
end

-- ---------------------------------------------------------------------------
-- The pages
-- ---------------------------------------------------------------------------

-- the toolkit's own page: General
local function generalPage()
	local panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels.settings = panel
	header(panel, "General", "Colours, size and positions for every BeebMod panel")
	-- the name the tests and older code know it by
	panel.toolkit = panel.body
	BT.Settings.Build(panel.body)
	return panel
end

local function testingPanel()
	local panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels.testing = panel
	header(panel, "Testing", "Made-up data to look at when you are alone, and BeebMod's own reports and records")
	testingPage(panel.body)
	return panel
end

local function panelFor(key)
	local panel = panels[key]
	if panel then
		return panel
	end
	if key == "settings" then
		return generalPage()
	elseif key == "testing" then
		if not W.Testing() then
			return panelFor("settings")
		end
		return testingPanel()
	end
	local f = BT.Feature(key)
	if not f then
		return panelFor("settings")
	end
	panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels[key] = panel
	header(panel, f.title, f.blurb or f.line)
	featurePage(panel, key)
	return panel
end

-- ---------------------------------------------------------------------------
-- The search
-- ---------------------------------------------------------------------------
--
-- SEARCH ANYTHING (Josh 2026-10-05: "Is it possible to add a 'search
-- anything' box, similar to the default WoW options UI?"). Typing in the box
-- in the title bar puts the page away for the rows that match, under their
-- features' names, in the rail's order. Each row is built from the same spec
-- as the row on its page, so its switch is that switch. A part that matches
-- brings the row it is a part of; a row that matches brings its parts; a
-- feature's name brings its whole page. A feature that is off shows its own
-- switch above its rows, since they are dimmed for it. General's and
-- Testing's rows have a button to their page. Clicking a page on the rail,
-- Escape, or the cross in the box puts the search away.

-- what a word in the box also finds: the old name of a thing, or what a
-- player might call it
W.SEARCH_WORDS = {
	Colours = "theme class accent",
	Size = "scale bigger smaller",
	Positions = "move reset drag",
	Gold = "money session",
	Bags = "space reagents",
	Durability = "repair",
	["Item level"] = "ilvl gear",
	Performance = "fps frame rate latency lag",
	["Action bars"] = "keybinds",
}

-- American spellings, so "color" finds Colours
W.SPELLINGS = { color = "colour", gray = "grey", armor = "armour" }

-- the words of a search: lower case, without apostrophes
function W.SearchWords(text)
	local out = {}
	text = tostring(text or ""):lower():gsub("'", "")
	for word in text:gmatch("%S+") do
		for us, uk in pairs(W.SPELLINGS) do
			word = word:gsub(us, uk)
		end
		out[#out + 1] = word
	end
	return out
end

-- what a row is found by: its name, its line, and any words it adds. Spaces
-- taken out too, so "pickpocket" finds Pick Pocket.
local function hayOf(r)
	if not r.hay then
		local spec = r.spec or {}
		local extra = (not spec.head) and W.SEARCH_WORDS[spec.label or ""] or ""
		local text = table.concat({ spec.label or "", spec.blurb or "", spec.words or "", extra }, " ")
		text = text:lower():gsub("'", "")
		r.hay = text .. " " .. text:gsub("%s+", "")
	end
	return r.hay
end

local function matches(r, words)
	local hay = hayOf(r)
	for _, word in ipairs(words) do
		if not hay:find(word, 1, true) then
			return false
		end
	end
	return true
end

-- a feature's rows in the results: its own switch first, then its page's
-- rows in the page's order
local function searchFeature(panel, st, fkey)
	local f = BT.Feature(fkey)
	local sec = st:Section(f.title)
	local first = #panel.rows + 1
	local head = addRow(panel, sec, {
		label = f.title, blurb = "The whole feature, on or off", head = true, words = f.short,
		get = function() return W.TabOn(fkey) end,
		set = function(on) BT.SetFeature(fkey, on) end,
	}, 0)
	if fkey == "dock" then
		dockRows(panel, sec, 0, false)
	else
		for _, key in ipairs(W.PAGE_MODULES[fkey] or {}) do
			local m = BT.GetModule(key)
			if m then
				moduleRows(panel, sec, m, 0, false)
			end
		end
	end
	for _, list in ipairs({ W.OPTIONS[fkey] or false, W.OPEN[fkey] or false }) do
		for _, spec in ipairs(list and list() or {}) do
			addRow(panel, sec, spec, 0)
		end
	end
	local group = { key = fkey, head = head, rows = {} }
	for i = first, #panel.rows do
		local r = panel.rows[i]
		-- the feature's own switch is never dimmed; the rest are, while it is off
		r.feature = r ~= head and fkey or nil
		group.rows[#group.rows + 1] = r
	end
	panel.groups[#panel.groups + 1] = group
end

-- General's and Testing's rows in the results: read from the page itself,
-- each with a button to that page
local function searchPage(panel, st, key)
	local page = panelFor(key)
	local stack = page.body and page.body.stack
	local sec = st:Section(W.TitleOf(key))
	local group = { key = key, rows = {} }
	for _, item in ipairs(stack and stack.items or {}) do
		for _, src in ipairs(item.rows or {}) do
			local label = src.label and src.label:GetText()
			if label and label ~= "" then
				group.rows[#group.rows + 1] = addRow(panel, sec, {
					label = label, blurb = src.blurb and src.blurb:GetText() or "",
					button = W.TitleOf(key), run = function() W.SetView(key) end,
				}, 0)
			end
		end
	end
	panel.groups[#panel.groups + 1] = group
end

-- the results page: every row there is, built once, and hidden or shown as
-- the words change
local function resultsPanel()
	local panel = panels.search
	if panel then
		return panel
	end
	panel = CreateFrame("Frame", nil, content)
	panel:SetAllPoints()
	panel:Hide()
	panels.search = panel
	header(panel, "Search results", "")
	panel.rows, panel.groups = {}, {}
	local st = BT.Widgets.Stack(panel.body)
	panel.stack = st
	searchPage(panel, st, "settings")
	for _, g in ipairs(W.GROUPS) do
		for _, fkey in ipairs(W.GroupKeys(g.key)) do
			searchFeature(panel, st, fkey)
		end
	end
	if W.Testing() then
		searchPage(panel, st, "testing")
	end
	return panel
end

local function live(r)
	return r.live == nil or (r.live() and true or false)
end

-- which rows the words find, and how many are shown
local function filter(panel, words)
	local shown = 0
	for _, g in ipairs(panel.groups) do
		local direct = {}
		for _, r in ipairs(g.rows) do
			direct[r] = matches(r, words)
		end
		local whole = g.head and direct[g.head]
		for _, r in ipairs(g.rows) do
			r.match = (whole or direct[r] or (r.under and direct[r.under])) and true or false
		end
		local any = false
		for _, r in ipairs(g.rows) do
			if direct[r] and r.under then
				r.under.match = true
			end
		end
		for _, r in ipairs(g.rows) do
			if r.match and r ~= g.head and live(r) then
				any = true
			end
		end
		-- dimmed rows say why: the feature's own switch, off, above them
		if g.head and any and not W.TabOn(g.key) then
			g.head.match = true
		end
		for _, r in ipairs(g.rows) do
			if r.match and live(r) then
				shown = shown + 1
			end
		end
	end
	return shown
end

-- the results brought up to date: what matches, what is dimmed, and the
-- line under the title when nothing does
local function showResults(panel)
	local shown = filter(panel, searching)
	paintRows(panel)
	panel.stack:Layout()
	panel.enableBlurb:SetText(shown > 0 and "" or ("Nothing matches “%s”"):format(searchText or ""))
	return shown
end

-- the box's own look: its prompt while empty, its cross while not
function W.SearchLook()
	local f = frame and frame.search
	if not f then
		return
	end
	local text = f.box:GetText() or ""
	f.ghost:SetShown(text == "" and not f.box:HasFocus())
	f.clear:SetShown(text ~= "")
end

-- Search for these words: the results in place of the page, or, with no
-- words, the page back
function W.Search(text)
	if not frame then
		return
	end
	W.SearchLook()
	local words = W.SearchWords(text)
	if #words == 0 then
		if searching then
			searching, searchText = nil, nil
			W.SetView(current or "settings")
		end
		return
	end
	local was = searchText
	searching, searchText = words, tostring(text):match("^%s*(.-)%s*$")
	local panel = resultsPanel()
	for _, p in pairs(panels) do
		if p ~= panel then
			p:Hide()
		end
	end
	panel:Show()
	W.SyncPage()
	if searchText ~= was and panel.view.ScrollTo then
		panel.view:ScrollTo(0)
	end
end

-- the search put away, and the page you were on back
function W.ClearSearch()
	if frame then
		W.SetView(current or "settings")
	end
end

-- whether the results are showing, and the words in the box
function W.Searching()
	return searching ~= nil, searchText
end

-- the box in the title bar: a magnifier, the prompt, and a cross to empty it
local function searchField(parent)
	local Wd = BT.Widgets
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(SEARCH_W, SEARCH_H)
	f:EnableMouse(true)
	BT.Pill.Panel(f, Wd.FIELD_IDLE.fill, Wd.FIELD_IDLE.edge)
	f.glass = f:CreateTexture(nil, "OVERLAY")
	f.glass:SetSize(12, 12)
	f.glass:SetPoint("LEFT", 7, 0)
	f.glass:SetTexture(BT.Dock.ICONS)
	BT.Dock.SearchCoord(f.glass)
	f.glass:SetVertexColor(0.50, 0.56, 0.53, 0.9)
	f.box = CreateFrame("EditBox", nil, f)
	f.box:SetPoint("TOPLEFT", 22, -2)
	f.box:SetPoint("BOTTOMRIGHT", -20, 2)
	f.box:SetAutoFocus(false)
	f.box:SetMaxLetters(40)
	-- an edit box with no font refuses its first letter
	if BeebModFontHighlightSmall then
		pcall(f.box.SetFontObject, f.box, BeebModFontHighlightSmall)
		if BeebModFontHighlightSmall.GetFont then
			local face, _, flags = BeebModFontHighlightSmall:GetFont()
			if face then
				pcall(f.box.SetFont, f.box, face, 11, flags)
			end
		end
	end
	f.box:SetTextColor(0.90, 0.92, 0.90)
	f.ghost = f:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	f.ghost:SetPoint("LEFT", 24, 0)
	f.ghost:SetText("Search")
	f.clear = Wd.Close(f, 16)
	f.clear:SetPoint("RIGHT", -3, 0)
	f.clear:SetScript("OnClick", function() W.ClearSearch() end)
	f.clear:Hide()
	-- where you are typing: the Ledger's note box's lit rim
	local function lit(on)
		if on then
			local c = Wd.ACCENT
			BT.Pill.Recolour(f, Wd.FIELD_LIT.fill, { c[1], c[2], c[3], 1 })
		else
			BT.Pill.Recolour(f, Wd.FIELD_IDLE.fill, Wd.FIELD_IDLE.edge)
		end
	end
	f.Lit = lit
	f:SetScript("OnMouseDown", function() f.box:SetFocus() end)
	f.box:SetScript("OnTextChanged", function(self) W.Search(self:GetText()) end)
	f.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.box:SetScript("OnEscapePressed", function() W.ClearSearch() end)
	f.box:SetScript("OnEditFocusGained", function()
		lit(true)
		W.SearchLook()
	end)
	f.box:SetScript("OnEditFocusLost", function()
		lit(false)
		W.SearchLook()
	end)
	return f
end

-- the page you are on, in step: its switches, what is dimmed, the dock's
-- rows that come and go, and the rail's names. While searching, the results.
function W.SyncPage()
	if searching and panels.search then
		showResults(panels.search)
	else
		local panel = current and panels[current]
		if panel and panel.rows then
			paintRows(panel)
			if panel.stack then
				panel.stack:Layout()
			end
		end
	end
	BT.Widgets.SyncRows()
	W.Retint()
end

-- (the names older code calls it by)
W.SyncTab = function() W.SyncPage() end
W.SyncFeature = function() W.SyncPage() end

function W.SetView(key)
	if not frame then
		return
	end
	key = W.TabFor(key)
	-- a page asked for is the search put away
	local box = frame.search and frame.search.box
	if searching or (box and (box:GetText() or "") ~= "") then
		searching, searchText = nil, nil
		if box then
			box:SetText("")
			box:ClearFocus()
		end
		W.SearchLook()
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
	if key == "settings" then
		BT.Settings.Refresh()
	end
	W.SyncPage()
end

function W.View()
	return current
end

-- A page, built but not shown
function W.BuildPanel(key)
	W.Build()
	return panelFor(W.TabFor(key))
end

-- where the rail's tabs may reach before they meet the line at its foot
local function railRoom()
	return WINDOW_H - TITLE_H - 8 - PAD - FOOT_H
end

-- The rail: General; each group's heading and its features; then Testing,
-- in a copy to work on only. The version is at the foot.
function W.Rebuild()
	if not frame then
		return
	end
	local y, shown = -6, 0
	local area = rail.area or rail
	local function place(key, title, colour, at)
		shown = shown + 1
		local tab = makeTab(shown)
		-- A TAB AT THE FOOT IS NOT IN THE LIST (Josh 2026-10-05: "We lost the
		-- Testing module"). Every tab was made inside the list that scrolls,
		-- and the list stops above the foot, so Testing, placed at the foot,
		-- was cut off with nothing to say so. A tab is reused by its place in
		-- the order, so it is given its parent each time.
		tab:SetParent(at and rail or area)
		tab.key, tab.title, tab.colour = key, title, colour
		tab.label:SetText(title)
		tab.label:ClearAllPoints()
		tab.label:SetPoint("LEFT", colour and 28 or 14, 0)
		tab:ClearAllPoints()
		if at then
			tab:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 6, at)
		else
			tab:SetPoint("TOPLEFT", area, "TOPLEFT", 6, y)
			y = y - TAB_STRIDE
		end
		tab:SetWidth(RAIL - 12)
		tab:SetFrameLevel(((at and rail or area):GetFrameLevel() or 1) + 4)
		tab:Show()
		tabTint(tab, W.LitTab() == key, false)
		return tab
	end
	place("settings", "General")
	rail.heads = rail.heads or {}
	for i, g in ipairs(W.GROUPS) do
		local head = rail.heads[i]
		if not head then
			head = area:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
			head:SetJustifyH("LEFT")
			rail.heads[i] = head
		end
		head:SetText(string.upper(g.title))
		head:ClearAllPoints()
		head:SetPoint("TOPLEFT", area, "TOPLEFT", 20, y - 10)
		head:Show()
		y = y - GROUP_H
		for _, fkey in ipairs(W.GroupKeys(g.key)) do
			local f = BT.Feature(fkey)
			place(fkey, f.short or f.title, f.color)
		end
	end
	-- TESTING UNDER THE FEATURES, NOT AT THE FOOT (Josh 2026-10-05: "Still
	-- not seeing the testing module"). The settings canvas put it at the
	-- rail's foot, and the client's Issue Reporter button, drawn above every
	-- window, sits on that corner of a window opened in the middle of the
	-- screen. It is the addon's own, not a feature, so a gap sets it apart;
	-- in a copy to work on only (W.Testing).
	if W.Testing() then
		y = y - 10
		place("testing", "Testing")
	end
	for i = shown + 1, #tabs do
		tabs[i]:Hide()
		tabs[i].key = nil
	end
	-- how far down the last tab of the list reaches, so a test can say it fits
	rail.reach = -(y + (TAB_STRIDE - TAB_H))
	if rail.view then
		rail.view:SetContentHeight(rail.reach + 6)
	end
	W.Retint()
	if current and panels[current] then
		W.SyncPage()
	end
end

-- does every tab fit above the version at the rail's foot
function W.RailFits()
	return rail ~= nil and (rail.reach or 0) <= railRoom() - TAB_STRIDE, rail and rail.reach, railRoom() - TAB_STRIDE
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
	-- in front of the Ledger's window when clicked or opened, never through it
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

	-- THE WAY OUT (Josh 2026-09-21): Escape closes this and so does the cog
	-- that opened it, and so does this
	frame.close = BT.Widgets.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() W.Hide() end)

	-- the search, beside the way out (W.Search); closing the window puts it
	-- away, so the window opens on a page
	frame.search = searchField(frame)
	frame.search:SetPoint("RIGHT", frame.close, "LEFT", -10, 0)
	frame:HookScript("OnHide", function()
		if searching then
			W.ClearSearch()
		end
	end)

	BT.Widgets.Divider(frame, PAD, -TITLE_H)

	rail = CreateFrame("Frame", nil, frame)
	rail:SetPoint("TOPLEFT", PAD - 4, -TITLE_H - 8)
	rail:SetPoint("BOTTOMLEFT", PAD - 4, PAD)
	rail:SetWidth(RAIL)
	rail.view = BT.Widgets.Scroller(rail)
	rail.view:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, 0)
	-- down to the version at the foot
	rail.view:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 0, FOOT_H)
	rail.area = rail.view.content

	-- THE VERSION, ONCE (Josh 2026-09-23), at the foot of the rail
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
	-- A FRAME IS SHOWN THE MOMENT IT IS CREATED (Josh 2026-09-19): building
	-- the window must not open it. Whoever wants it open says so.
	frame:Hide()
	return frame
end

-- Just the line under the title (a module repainting itself wants this and
-- nothing else: see W.Refresh)
function W.UpdateSubtitle()
	if not frame then
		return
	end
	local where = BT.scope and BT.scope.realm or "?"
	if BT.DB and BT.db then
		-- counted from the list alone: reading each character to count them
		-- was a long frame on a big book every time the window opened
		where = ("%s · %s characters"):format(where, BT.Util.Commas((BT.DB.Count(BT.db))))
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

function W.Refresh()
	if not frame or refreshing then
		return
	end
	refreshing = true -- the backstop, whatever any module does in its Refresh
	local ok, err = pcall(function()
		W.UpdateSubtitle()
		W.UpdateFoot()
		if current == "settings" then
			BT.Settings.Refresh()
		end
		W.SyncPage()
	end)
	refreshing = false
	if not ok then
		BT.Err("window.Refresh: " .. tostring(err))
	end
end

function W.Show(view)
	W.Build()
	BT.EnsureBound()
	frame:Show()
	frame:Raise()
	if view then
		W.SetView(view)
	elseif not current then
		W.SetView("settings")
	else
		W.Refresh()
	end
	W.UpdateSubtitle()
	W.UpdateFoot()
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
	if W.IsShown() and (not view or W.TabFor(view) == current) then
		W.Hide()
		return false
	end
	W.Show(view)
	return true
end

-- the tests reach in here rather than at the frames
function W.Frame() return frame end
function W.Tabs() return tabs end
function W.Rail() return rail end
function W.Panel(key) return panels[key] end
