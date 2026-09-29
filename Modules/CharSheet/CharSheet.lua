-- The character sheet (Josh 2026-09-22).
--
-- The panel you open with C: your gear, your stats, and the tabs beside it
-- for reputation, skills, PvP, currency and statistics - in the toolkit's
-- look, with stat sections that fold and item levels on the slots.
--
-- ITEM LEVEL ON EVERY SLOT. The number in the corner of each piece you wear,
-- the way the right panel's Item level metric reads them - so a slot that is
-- dragging the average down is visible at a glance, without pointing at
-- nineteen tooltips. Shirts and tabards have no say in it and show none.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/CharSheet/CharSheet.lua")

local U = BT.Util

local M = BT.Module({
	key = "charsheet",
	feature = "interface",
	title = "Character sheet",
	blurb = "Item level on every slot, and BeebMod's look",
	order = 57,
})

-- the slots of the sheet, by the name the game gives each button
M.SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
	"MainHand", "SecondaryHand", "Ranged",
}

local function opt(name, fallback)
	local s = BT.settings and BT.settings.charsheet
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

function M.ShowsLevels()
	return BT.Enabled("charsheet") and opt("levels", true) and true or false
end

function M.SetShowsLevels(on)
	BT.EnsureBound()
	BT.settings.charsheet = BT.settings.charsheet or {}
	BT.settings.charsheet.levels = on and true or false
	M.UpdateAll()
end

-- one of this sheet's slots that takes gear (not the shirt, not the tabard)
local ours = {}
for _, name in ipairs(M.SLOTS) do
	ours["Character" .. name .. "Slot"] = true
end
function M.Ours(button)
	local ok, name = pcall(function() return button and button.GetName and button:GetName() end)
	return ok and name ~= nil and ours[name] == true
end

function M.Buttons()
	local out = {}
	for _, name in ipairs(M.SLOTS) do
		local b = _G["Character" .. name .. "Slot"]
		if type(b) == "table" then
			out[#out + 1] = b
		end
	end
	return out
end

-- the number, made once per slot: small, white, outlined so it reads over
-- any icon, in the bottom-right corner where nothing else of the game's sits
local function label(button)
	if button.beebsLevel then
		return button.beebsLevel
	end
	if not button.CreateFontString then
		return nil
	end
	local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	if fs.GetFont and fs.SetFont then
		local face = fs:GetFont()
		if face then
			-- small: a corner mark on a 32px slot, not a label across it
			pcall(fs.SetFont, fs, face, 10, "OUTLINE")
		end
	end
	fs:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
	fs:SetJustifyH("RIGHT")
	fs:SetTextColor(1, 1, 1)
	button.beebsLevel = fs
	return fs
end

-- what one slot should say: its item's level, or nothing
function M.LevelFor(button)
	if not (button and button.GetID and type(GetInventoryItemLink) == "function") then
		return nil
	end
	local itemlevel = BT.GetModule("itemlevel")
	if not (itemlevel and itemlevel.LevelOf) then
		return nil
	end
	local ok, link = pcall(GetInventoryItemLink, "player", button:GetID())
	return ok and itemlevel.LevelOf(link) or nil
end

function M.Update(button)
	local fs = label(button)
	if not fs then
		return
	end
	local lvl = M.ShowsLevels() and M.LevelFor(button) or nil
	fs:SetText(lvl and tostring(lvl) or "")
	fs:SetShown(lvl ~= nil)
end

function M.UpdateAll()
	local n = 0
	for _, b in ipairs(M.Buttons()) do
		M.Update(b)
		n = n + 1
	end
	return n
end

-- THE GAME REDRAWS A SLOT ITSELF whenever what is in it changes; each time,
-- the number is put back on. The equipment event covers a build that draws
-- slots some other way, and a piece the client had not described yet gets its
-- number when it has.
local hooked = false
local function watch()
	if hooked then
		return
	end
	hooked = true
	if type(hooksecurefunc) == "function" and type(_G.PaperDollItemSlotButton_Update) == "function" then
		pcall(hooksecurefunc, "PaperDollItemSlotButton_Update", function(button)
			-- the level on the slots that have one; the ammo slot is dressed
			-- but has no level - its corner is its count (Josh 2026-09-23,
			-- audit: a level was printed over the count, and never cleared)
			local ammo = button and button.GetName and button:GetName() == "CharacterAmmoSlot"
			if M.Ours(button) then
				M.Update(button)
			end
			if (M.Ours(button) or ammo) and M.Themed and M.Themed() then
				M.DressSlot(button)
			end
		end)
	end
	local sheet = _G.CharacterFrame or _G.PaperDollFrame
	if sheet and sheet.HookScript then
		sheet:HookScript("OnShow", function()
			M.UpdateAll()
		end)
	end
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event)
	if BT.Enabled("charsheet") then
		-- GET_ITEM_INFO_RECEIVED fires for every item anything asks the
		-- client about; the numbers are refreshed, the window is not
		-- dressed again for each one
		-- and only while the sheet is open: it comes by the hundred at an
		-- auction house, and opening the sheet refreshes them anyway
		if event == "GET_ITEM_INFO_RECEIVED" then
			local sheet = _G.CharacterFrame
			if sheet and sheet.IsShown and sheet:IsShown() then
				M.UpdateAll()
			end
			return
		end
		watch()
		M.UpdateAll()
		M.WatchTheme()
		M.WatchPosition()
		if M.Themed() and _G.CharacterFrame and _G.CharacterFrame:IsShown() then
			M.Dress()
		end
	end
end)

function M:OnEnable()
	watch()
	M.WatchPosition()
	M.UpdateAll()
	M.WatchTheme()
	M.Apply()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

-- THE THEME MOVED (Josh 2026-09-22). Every surface, rim, tint and slot edge
-- in this window is painted where it is dressed, so a colour picked while the
-- window is open sat there in the old one. The theme calls this on every
-- module that paints on the client's own frames.
function M:Restyle()
	if M.Themed() and _G.CharacterFrame then
		M.Dress()
	end
end

function M:OnDisable()
	-- the numbers go and the art comes back; the sheet is the game's again
	M.UpdateAll()
	M.Undress()
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("BeebMod redraws the game's character sheet. Click a stat heading to fold its section.")
	local sheet = page:Section("Sheet")
	self.levelSwitch = BT.Widgets.SwitchRow(sheet, "Item level on every slot",
		"In the corner of each piece you wear. Shirts and tabards show none.",
		function() return opt("levels", true) and true or false end,
		function(on) M.SetShowsLevels(on) end).switch
	self.themeSwitch = BT.Widgets.SwitchRow(sheet, "In BeebMod's look",
		"Flat panels and plain headings. Off, the game's art comes back.",
		function() return opt("theme", true) and true or false end,
		function(on) M.SetThemed(on) end).switch
	self.moveSwitch = BT.Widgets.SwitchRow(sheet, "Drag it by its title",
		"It opens where you left it",
		function() return opt("move", true) and true or false end,
		function(on)
			BT.EnsureBound()
			BT.settings.charsheet = BT.settings.charsheet or {}
			BT.settings.charsheet.move = on and true or false
			if not on then
				M.ResetPosition()
			end
		end).switch
	-- PUT BACK FROM THE PAGE (Josh 2026-09-28: "We don't need hundreds of
	-- slash commands"): the Reset that /bt sheet reset was
	local back = BT.Widgets.Row(sheet, "Where it opens", "Back where the game puts it")
	self.resetButton = back:SetControl(BT.Widgets.Button(back, "Reset", 62, 20))
	self.resetButton:SetScript("OnClick", function()
		M.ResetPosition()
		U.Print("Character sheet: the window is back where the game puts it.")
	end)
	page:Layout()
end

function M:RefreshTab()
	if self.levelSwitch then
		self.levelSwitch:SetOn(opt("levels", true) and true or false)
	end
	if self.themeSwitch then
		self.themeSwitch:SetOn(opt("theme", true) and true or false)
	end
	if self.moveSwitch then
		self.moveSwitch:SetOn(opt("move", true) and true or false)
	end
end

function M:ShowTab()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- ---------------------------------------------------------------------------
-- The theme
-- ---------------------------------------------------------------------------
--
-- A KEY OR A NAME (Josh 2026-09-22). The sheet's record labels a frame by its global
-- name when it has one and by the key it hangs off otherwise, and most of this
-- window's frames have names: CharacterFrameLeftPaneHost is a global, not a key
-- on CharacterFrame. Read as keys, the layout found nothing to move but the
-- window itself. Every piece is looked up both ways.
local function pick(owner, name)
	return (type(owner) == "table" and owner[name]) or _G[name]
end
M.Pick = pick
--
-- BY WHAT IT DRAWS, NOT WHERE IT HANGS (Josh 2026-09-22). /bt sheetdump showed
-- this build's character window is its own: side tabs in CharacterFrameModeTabs,
-- the pages in a left and a right pane host, and every list a scroll box that
-- makes its rows as they scroll into view. What every piece of it does have is
-- an atlas name - UI-Character-Info-Title on a stat header, common-sidetab
-- behind a tab, common-button-list-collapseExpand behind a list header - and
-- the same names appear on every tab. So the window is walked, and each piece
-- of art is taken off or recoloured by what it is, wherever it turns up: a row
-- made later, on a tab not opened yet, is dressed the same way when it is.
--
-- Everything changed is written down first and given back exactly when the
-- module (or its switch) goes off.

local FILL, RIM = BT.Widgets.FILL, BT.Widgets.RIM

-- the art that comes off, by atlas (lower case)
M.HIDE = {
	["ui-character-info-general-bg"] = true,
	["ui-character-info-stat-bg"] = true,
	["ui-character-info-stat-stonebg"] = true,
	["common-insideframe"] = true,
	["ui-character-info-title"] = true,
	["ui-character-info-line-bounce"] = true,
	["ui-character-info-line-bounce2"] = true,
	["ui-character-info-itemlevel-bounce"] = true,
	["ui-character-info-scrollline"] = true,
	["ui-character-info-scrollline-long"] = true,
	["ui-character-info-honor-levelbg"] = true,
	["ui-character-info-gearslot"] = true,
	["ui-character-info-gearslotsmall"] = true,
	["ui-character-info-gearslot-arrow"] = true,
	-- the scroll arrows: the wheel and the thumb do their job, and the mockup
	-- has neither
	["minimal-scrollbar-arrow-top"] = true,
	["minimal-scrollbar-arrow-bottom"] = true,
	["minimal-scrollbar-arrow-top-over"] = true,
	["minimal-scrollbar-arrow-bottom-over"] = true,
	["minimal-scrollbar-arrow-top-down"] = true,
	["minimal-scrollbar-arrow-bottom-down"] = true,
	["common-framedivider"] = true,
	["common-button-list-collapseexpand"] = true,
	-- the ends of the row highlight: a band across the row reads as "this one",
	-- two rounded caps read as a box stuck on it
	["charactercreate-customize-dropdown-linemouseover-side"] = true,
	["minimal-scrollbar-track-top"] = true,
	["minimal-scrollbar-track-bottom"] = true,
	["!minimal-scrollbar-track-middle"] = true,
}

-- the art that comes off and leaves its button on a surface of ours instead
M.SURFACE = {
	["common-sidetab"] = "tab",
	["common-sidetab-selected"] = "tab",
	["common-sidetab-hover"] = "tab",
	["ui-character-info-stattab"] = "tab",
	["ui-character-info-stattab-selected"] = "tab",
	["common-dropdown-textholder"] = "button",
	-- a check box: the game's rounded plate off, the panel's own small square
	-- with a rim in its place (the tick keeps its shape, in the theme's colour)
	["checkbox-minimal"] = "box",
	["checkbox-minimal-disabled"] = "box",
	["common-button-tertiary-normal"] = "button",
	["common-button-square-gray-up"] = "button",
	["common-button-square-gray-down"] = "button",
	["128-redbutton-left"] = "button",
	["128-redbutton-right"] = "button",
	["_128-redbutton-center"] = "button",
	["128-redbutton-left-disabled"] = "button",
	["128-redbutton-right-disabled"] = "button",
	["_128-redbutton-center-disabled"] = "button",
	["128-redbutton-left-pressed"] = "button",
	["128-redbutton-right-pressed"] = "button",
	["_128-redbutton-center-pressed"] = "button",
}

-- the art that stays but in the theme's colours
M.RECOLOUR = {
	-- the track under a bar: dark, but a step off the panel, or the bar reads
	-- as an underline that stops halfway
	["common-stat-bar-bg"] = "track",
	-- a skill bar's blue is the client's, and loud beside the panel's text;
	-- a reputation bar keeps its colour, which is the standing
	["common-stat-bar-blue"] = "skill",
	["charactercreate-customize-dropdown-linemouseover-middle"] = "raised",
	["minimal-scrollbar-small-thumb-top"] = "rim",
	["minimal-scrollbar-small-thumb-middle"] = "rim",
	["minimal-scrollbar-small-thumb-bottom"] = "rim",
	-- the model's zoom and turn marks and the scroll arrows were the game's
	-- gold; they are the panel's quiet grey, like every other mark in it
	["checkmark-minimal"] = "accent",
	["checkmark-minimal-disabled"] = "ink",
	["common-icon-zoomin"] = "ink",
	["common-icon-zoomout"] = "ink",
	["common-icon-rotateleft"] = "ink",
	["common-icon-rotateright"] = "ink",
	["common-icon-undo"] = "ink",
	["common-icon-redo"] = "ink",
	-- a list header's minus and plus, and Statistics' own fold buttons
	["common-button-list-minus"] = "ink",
	["common-button-list-plus"] = "ink",
	["campaign_headericon_open"] = "ink",
	["campaign_headericon_openpressed"] = "ink",
	["campaign_headericon_closed"] = "ink",
	["campaign_headericon_closedpressed"] = "ink",
}

-- a class's own backdrop behind the stats: UI-Character-Info-Mage-BG and so on
local function classBackdrop(atlas)
	return atlas:find("^ui%-character%-info%-%a+%-bg$") ~= nil
end

local function colourOf(which)
	if which == "ink" then
		return { 0.62, 0.68, 0.66, 1 }
	elseif which == "track" then
		return { RIM[1] * 0.55 + 0.03, RIM[2] * 0.55 + 0.03, RIM[3] * 0.55 + 0.03, 1 }
	elseif which == "skill" then
		return { 0.38, 0.45, 0.78, 1 }
	elseif which == "accent" then
		local a = BT.Widgets.ACCENT
		return { a[1], a[2], a[3], 1 }
	elseif which == "well" then
		return { FILL[1] * 0.55, FILL[2] * 0.55, FILL[3] * 0.55, 1 }
	elseif which == "raised" then
		local r = BT.Widgets.RAISED
		return { r[1], r[2], r[3], 1 }
	end
	return { RIM[1], RIM[2], RIM[3], 1 }
end

function M.Themed()
	return BT.Enabled("charsheet") and opt("theme", true) and true or false
end

-- what each touched region was, so it can be given back
local was = setmetatable({}, { __mode = "k" })

-- EACH THING ONCE, NOT EACH REGION ONCE (Josh 2026-09-23, audit): the record
-- was the first thing done to a region and nothing after, so a stat title
-- moved by its header and then greyed as its words kept the grey when the
-- theme went off. One record a region, a field for each thing changed.
local function keep(r)
	local w = was[r]
	if not w then
		w = {}
		was[r] = w
	end
	return w
end

local function keepAlpha(r)
	local w = keep(r)
	if w.alpha == nil then
		w.alpha = (r.GetAlpha and r:GetAlpha()) or 1
	end
end

local function keepText(fs)
	local w = keep(fs)
	if w.text == nil and fs.GetTextColor then
		local r, g, b = fs:GetTextColor()
		w.text = { r or 1, g or 1, b or 1 }
	end
end
-- the surfaces and marks of ours, by the frame they sit on
local dressed = setmetatable({}, { __mode = "k" })

local function atlasOf(r)
	local ok, atlas = pcall(r.GetAtlas, r)
	return ok and type(atlas) == "string" and atlas:lower() or nil
end

local function hide(r)
	keepAlpha(r)
	r:SetAlpha(0)
end

-- TINTED, NOT REPLACED (Josh 2026-09-22). Swapping the art for a flat colour
-- took its atlas away, and the game's scroll bar reads its thumb's atlas every
-- time it resizes it - "bad argument to GetAtlasInfo" the moment the window
-- opened. The art stays; it is drained of its own colour and tinted to the
-- theme's, so anything of the game's that asks what it is still gets an answer.
local TINT = { well = 2.2, raised = 2.4, rim = 1.0, ink = 1, track = 1, skill = 1, accent = 1 }

local function recolour(r, atlas, which)
	local w = keep(r)
	if not w.vertex then
		local okV, vr, vg, vb, va = pcall(r.GetVertexColor, r)
		local okD, desat = pcall(r.IsDesaturated, r)
		w.vertex = okV and { vr or 1, vg or 1, vb or 1, va or 1 } or { 1, 1, 1, 1 }
		w.desat = okD and desat or false
	end
	local c, k = colourOf(which), TINT[which] or 1
	if r.SetDesaturated then
		pcall(r.SetDesaturated, r, true)
	end
	r:SetVertexColor(math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1)
end

-- THE MODEL'S CONTROLS WEAR NO BORDER (Josh 2026-09-22). Zoom and turn are
-- four small marks over the model; each on a rimmed square, in a rimmed
-- strip, was a lot of box for four marks. Their art comes off like any other
-- button's and nothing of ours goes on in its place: the marks stand on the
-- panel by themselves.
M.CONTROL_ICONS = {
	["common-icon-zoomin"] = true, ["common-icon-zoomout"] = true,
	["common-icon-rotateleft"] = true, ["common-icon-rotateright"] = true,
	["common-icon-undo"] = true, ["common-icon-redo"] = true,
}

-- the control strip itself, one of its buttons, or a button carrying one of
-- the marks: known by where it hangs or by what it shows
local function isBare(f)
	if type(f) ~= "table" then
		return false
	end
	if f.beebsBare ~= nil then
		return f.beebsBare
	end
	local bare = false
	local scene = _G.CharacterModelScene
	local ctrl = scene and scene.ControlFrame
	if ctrl and (f == ctrl or (f.GetParent and f:GetParent() == ctrl)) then
		bare = true
	else
		local ok, regions = pcall(function() return { f:GetRegions() } end)
		for _, r in ipairs(ok and regions or {}) do
			if M.CONTROL_ICONS[atlasOf(r) or ""] then
				bare = true
			end
		end
	end
	f.beebsBare = bare
	return bare
end
M.IsBare = isBare

-- a surface of ours on a button whose own art has come off
local function surface(f, kind)
	local o = dressed[f]
	if not o then
		o = { kind = kind, surface = BT.Pill.Surface(f, "BACKGROUND", -7) }
		dressed[f] = o
	end
	local lit = kind == "tab" and M.Selected(f)
	BT.Pill.PaintSurface(o.surface, f, lit and BT.Widgets.RAISED or FILL, RIM)
	BT.Pill.ShowSurface(o.surface, true)
	return o
end

-- a tab is lit while its own "selected" art would be showing
function M.Selected(f)
	-- the game's own selected art is held down (see stayDown), so "is it
	-- showing" is no longer the answer; what it was told to be is
	for _, key in ipairs({ "SelectedTexture" }) do
		local t = f[key]
		if t and t.IsShown then
			if t.beebsDown then
				return t.beebsWanted and true or false
			else
				return t:IsShown() and true or false
			end
		end
	end
	if f.GetChecked then
		local ok, on = pcall(f.GetChecked, f)
		return ok and on and true or false
	end
	return false
end

-- A LIST HEADER KEEPS ITS WORDS AND GAINS A RULE: its banner comes off, and
-- the panel's own header - quiet words and a hairline to the edge - is what
-- is left.
local function headerRule(f)
	local o = dressed[f] or {}
	dressed[f] = o
	-- a stat header's title is centred on its banner; with the banner gone it
	-- reads as a heading only set to the left, where the rule can follow it
	local title = f.Title
	if title and title.GetPoint and not keep(title).moved then
		local w = keep(title)
		local ok, point, rel, relPoint, x, y = pcall(title.GetPoint, title, 1)
		w.moved = true
		w.at = ok and point and { point, rel, relPoint, x or 0, y or 0 } or nil
		w.justify = title.GetJustifyH and title:GetJustifyH() or nil
		title:ClearAllPoints()
		title:SetPoint("LEFT", f, "LEFT", 6, 0)
		if title.SetJustifyH then
			title:SetJustifyH("LEFT")
		end
	end
	-- only a header with words gets a rule to follow them; a button that
	-- happens to wear the same banner (Next rewards) is left without one
	local words = f.Name or f.Title
	if not (words and words.GetRight) then
		return
	end
	keepText(words)
	words:SetTextColor(0.62, 0.68, 0.66)
	if not o.rule and f.CreateTexture then
		o.rule = f:CreateTexture(nil, "ARTWORK")
		o.rule.beebs = true
		o.rule:SetHeight(1)
		local name = words
		if name and name.GetRight then
			o.rule:SetPoint("LEFT", name, "RIGHT", 6, 0)
		else
			o.rule:SetPoint("LEFT", f, "LEFT", 8, 0)
		end
		o.rule:SetPoint("RIGHT", f, "RIGHT", -4, 0)
		BT.Widgets.Rule(o.rule, 0.9, "h")
	end
	if o.rule then
		o.rule:Show()
	end
end

local function dressRegion(r)
	local okT, kind = pcall(r.GetObjectType, r)
	if not (okT and kind == "Texture") or r.beebs then
		return
	end
	local atlas = atlasOf(r)
	if not atlas then
		return
	end
	-- a pressed or highlighted state of a piece that is coming off
	local base = atlas:gsub("%-disabled$", ""):gsub("%-pressed$", "")
	if M.HIDE[atlas] or classBackdrop(atlas) then
		hide(r)
		if atlas == "common-button-list-collapseexpand" or atlas == "ui-character-info-title" then
			local parent = r:GetParent()
			if parent then
				headerRule(parent)
			end
		end
	elseif M.SURFACE[atlas] or M.SURFACE[base] then
		hide(r)
		local parent = r:GetParent()
		if parent and parent.CreateTexture and not isBare(parent) then
			surface(parent, M.SURFACE[atlas] or M.SURFACE[base])
		end
	elseif M.RECOLOUR[atlas] then
		recolour(r, atlas, M.RECOLOUR[atlas])
	end
end

-- the whole of one frame, and all it holds
local function dressTree(f, depth)
	if type(f) ~= "table" or f.beebs or depth > 12 then
		return
	end
	local okR, regions = pcall(function() return { f:GetRegions() } end)
	for _, r in ipairs(okR and regions or {}) do
		dressRegion(r)
	end
	local okC, kids = pcall(function() return { f:GetChildren() } end)
	for _, kid in ipairs(okC and kids or {}) do
		dressTree(kid, depth + 1)
	end
end
M.DressTree = dressTree

-- ---------------------------------------------------------------------------
-- The pieces with names
-- ---------------------------------------------------------------------------

local function qualityColour(button)
	if type(GetInventoryItemQuality) ~= "function" or not button.GetID then
		return nil
	end
	local ok, q = pcall(GetInventoryItemQuality, "player", button:GetID())
	if not (ok and q) then
		return nil
	end
	local get = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
	if type(get) ~= "function" then
		return nil
	end
	local okC, r, g, b = pcall(get, q)
	return okC and type(r) == "number" and { r, g, b, 1 } or nil
end

-- A SLOT: a dark well, a one-pixel edge in the item's quality colour (or the
-- rim's, empty), and the icon a pixel inside it. The stone ring and the
-- client's own quality glow come off.
function M.DressSlot(button)
	if not (button and button.CreateTexture) then
		return
	end
	local o = dressed[button]
	if not o then
		o = {}
		o.well = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		o.well.beebs = true
		o.well:SetAllPoints()
		o.ring = BT.Pill.Ring(button, "OVERLAY", 6)
		for _, t in ipairs(o.ring) do
			t.beebs = true
		end
		BT.Pill.PlaceRing(o.ring, button, 0, 1, 0)
		dressed[button] = o
	end
	local w = colourOf("well")
	o.well:SetColorTexture(w[1], w[2], w[3], 1)
	o.well:Show()
	BT.Pill.PaintRing(o.ring, qualityColour(button) or { RIM[1] * 0.7, RIM[2] * 0.7, RIM[3] * 0.7, 1 })
	for _, key in ipairs({ "IconBorder" }) do
		if button[key] then
			hide(button[key])
		end
	end
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	if normal then
		hide(normal)
	end
	local icon = button.icon or button.Icon
		or (button.GetName and button:GetName() and _G[button:GetName() .. "IconTexture"])
	if icon and icon.SetTexCoord and not keep(icon).coords then
		keep(icon).coords = true
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
end

local function undressSlot(button)
	local o = dressed[button]
	if o and o.well then
		o.well:Hide()
		BT.Pill.HideRing(o.ring)
	end
end

-- the close button: its red square off, our cross on
local function dressClose(button)
	if not button then
		return
	end
	local okR, regions = pcall(function() return { button:GetRegions() } end)
	for _, r in ipairs(okR and regions or {}) do
		if not r.beebs then
			local okT, kind = pcall(r.GetObjectType, r)
			if okT and kind == "Texture" then
				hide(r)
			end
		end
	end
	local o = dressed[button]
	if not o then
		o = { cross = button:CreateTexture(nil, "OVERLAY") }
		o.cross.beebs = true
		o.cross:SetSize(10, 10)
		o.cross:SetPoint("CENTER")
		o.cross:SetTexture(BT.Dock.ICONS)
		BT.Dock.CrossCoord(o.cross)
		button:HookScript("OnEnter", function()
			if dressed[button] and M.Themed() then
				dressed[button].cross:SetVertexColor(1, 1, 1, 1)
			end
		end)
		button:HookScript("OnLeave", function()
			if dressed[button] and M.Themed() then
				dressed[button].cross:SetVertexColor(0.55, 0.60, 0.58, 1)
			end
		end)
		dressed[button] = o
	end
	o.cross:SetVertexColor(0.55, 0.60, 0.58, 1)
	o.cross:Show()
end

-- THE DETAILS ARROW: the game's gold square off, our chevron on, pointing the
-- way the pane will go - right to fold it away, left to bring it back
local function paintToggle(button)
	local o = dressed[button]
	if not (o and o.chevron) then
		return
	end
	local right = _G.CharacterFrameRightPaneHost
	local open = not right or right:IsShown()
	o.chevron:SetRotation(open and (math.pi / 2) or (-math.pi / 2))
	o.chevron:Show()
end

local function dressToggle(button)
	if not (button and button.CreateTexture) then
		return
	end
	local okR, regions = pcall(function() return { button:GetRegions() } end)
	for _, r in ipairs(okR and regions or {}) do
		local okT, kind = pcall(r.GetObjectType, r)
		if okT and kind == "Texture" and not r.beebs then
			hide(r)
		end
	end
	local o = dressed[button]
	if not o then
		o = { chevron = button:CreateTexture(nil, "OVERLAY") }
		o.chevron.beebs = true
		o.chevron:SetSize(12, 12)
		o.chevron:SetPoint("CENTER")
		o.chevron:SetTexture(BT.Dock.ICONS)
		BT.Dock.ChevronCoord(o.chevron)
		o.chevron:SetVertexColor(0.62, 0.68, 0.66, 1)
		o.surface = BT.Pill.Surface(button, "BACKGROUND", -7)
		o.kind = "button"
		button:HookScript("OnClick", function()
			if M.Themed() then
				paintToggle(button)
			end
		end)
		dressed[button] = o
	end
	BT.Pill.PaintSurface(o.surface, button, FILL, RIM)
	BT.Pill.ShowSurface(o.surface, true)
	paintToggle(button)
end

-- the frame itself: our surface and shadow, the portrait and the metal off,
-- a rule under the title and one down the seam between the panes
local function dressFrame(frame)
	if frame.NineSlice then
		hide(frame.NineSlice)
	end
	if frame.PortraitContainer then
		hide(frame.PortraitContainer)
	end
	-- a touch more solid than the dock: a window this big over the world
	-- shows too much of it at the dock's 88%
	BT.Widgets.Panel(frame, { FILL[1], FILL[2], FILL[3], 0.96 }, RIM)
	BT.Pill.ShowSurface(BT.Pill.Panels()[frame], true)
	BT.Widgets.Shadow(frame)
	BT.Widgets.ShowShadow(frame, true)
	local o = dressed[frame] or {}
	dressed[frame] = o
	if not o.titleRule then
		o.titleRule = frame:CreateTexture(nil, "ARTWORK")
		o.titleRule.beebs = true
		o.titleRule:SetHeight(1)
		o.titleRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -21)
		o.titleRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -21)
		BT.Widgets.Rule(o.titleRule, 0.9, "h")
	end
	o.titleRule:Show()
	local right = pick(frame, "CharacterFrameRightPaneHost")
	if right and right.CreateTexture then
		local r = dressed[right] or {}
		dressed[right] = r
		if not r.seam then
			r.seam = right:CreateTexture(nil, "ARTWORK")
			r.seam.beebs = true
			r.seam:SetWidth(1)
			r.seam:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
			r.seam:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
			BT.Widgets.Rule(r.seam, 0.9, "v")
		end
		r.seam:Show()
	end
	-- THE RACE SCENE COMES OFF (Josh 2026-09-22). At half strength it was a
	-- washed-out picture laid over whatever the window stood in front of; the
	-- model stands on the panel like everything else in it
	local scene = _G.CharacterModelScene
	if scene then
		for _, key in ipairs({ "BackgroundOverlay" }) do
			if scene[key] then
				hide(scene[key])
			end
		end
		-- the zoom and turn controls: every texture but the marks off, and
		-- no surface of ours on the strip or the buttons (see isBare)
		local ctrl = scene.ControlFrame
		if ctrl then
			local function bareTextures(f)
				local ok, regions = pcall(function() return { f:GetRegions() } end)
				for _, r in ipairs(ok and regions or {}) do
					local okT, kind = pcall(r.GetObjectType, r)
					if okT and kind == "Texture" and not r.beebs
						and not M.CONTROL_ICONS[atlasOf(r) or ""] then
						hide(r)
					end
				end
				local o = dressed[f]
				if o and o.surface then
					BT.Pill.ShowSurface(o.surface, false)
				end
			end
			bareTextures(ctrl)
			local okC, kids = pcall(function() return { ctrl:GetChildren() } end)
			for _, kid in ipairs(okC and kids or {}) do
				bareTextures(kid)
			end
		end
		for _, name in ipairs({ "CharacterModelFrameBackgroundTopLeft", "CharacterModelFrameBackgroundTopRight",
			"CharacterModelFrameBackgroundBotLeft", "CharacterModelFrameBackgroundBotRight" }) do
			local t = _G[name]
			if t and t.SetAlpha then
				keepAlpha(t)
				t:SetAlpha(0)
			end
		end
	end
	local title = _G.CharacterFrameTitleText
	if title and title.SetTextColor then
		keepText(title)
		title:SetTextColor(0.86, 0.88, 0.92)
	end
end

-- ---------------------------------------------------------------------------
-- The compact layout
-- ---------------------------------------------------------------------------
--
-- HALF THE SPACE (Josh 2026-09-22, chosen from the mockup). The game's window
-- is 631 x 484 and most of it is air: 37px slots a thumb's width from a model
-- in a 398px pane, a 233px side pane, 30px rows with a boxed bar beside the
-- name. The same window in 452 x 356: the slots against the model, the side
-- pane 176 wide, and every list row one line with a hairline bar under it.
--
-- Everything moved or resized here is written down the first time, and put
-- back exactly when the theme goes off. The game moves some of these itself -
-- folding the side pane away narrows the window - so the layout runs again
-- after it does.

M.W, M.H, M.PANE, M.TITLE = 452, 356, 176, 22
-- a row with a meter: its words this far over the middle, its bar this far
-- off the bottom (see compactRow)
M.ROW_TEXT_Y, M.ROW_BAR_Y = 4, 2
M.SLOT, M.GAP = 32, 3
M.TAB = 30

local placed = setmetatable({}, { __mode = "k" })

-- where a frame was and how big, the first time it is moved
local function remember(f)
	if placed[f] or not f then
		return
	end
	local p = { points = {} }
	local okN, n = pcall(f.GetNumPoints, f)
	for i = 1, (okN and n) or 0 do
		local ok, point, rel, relPoint, x, y = pcall(f.GetPoint, f, i)
		if ok and point then
			p.points[#p.points + 1] = { point, rel, relPoint, x or 0, y or 0 }
		end
	end
	local okS, w, h = pcall(function() return f:GetWidth(), f:GetHeight() end)
	if okS then
		p.w, p.h = w, h
	end
	placed[f] = p
end

-- ONLY WHAT WE CHANGED GOES BACK (Josh 2026-09-23, audit): every frame was
-- given back its first-seen size and points when the theme went off, so a
-- label that was only re-fonted came back fixed at the width it had that
-- moment, and the character frame at wherever it stood then. A size is put
-- back when one of ours set it, and points when place() moved it.
local function resizing(f)
	remember(f)
	placed[f].sized = true
end

-- Put a frame somewhere: `points` is a list of { point, rel, relPoint, x, y }.
local function place(f, points, w, h)
	if not (f and f.ClearAllPoints) then
		return false
	end
	remember(f)
	placed[f].moved = true
	if w or h then
		placed[f].sized = true
	end
	f:ClearAllPoints()
	for _, p in ipairs(points or {}) do
		pcall(f.SetPoint, f, p[1], p[2], p[3], p[4] or 0, p[5] or 0)
	end
	if w and f.SetWidth then
		f:SetWidth(w)
	end
	if h and f.SetHeight then
		f:SetHeight(h)
	end
	return true
end
M.Place = place

-- a font a new size, the same face - remembered like a position
local function sized(fs, size)
	if not (fs and fs.GetFont and fs.SetFont) then
		return
	end
	remember(fs)
	local p = placed[fs]
	if not p.font then
		local face, sz, flags = fs:GetFont()
		p.font = { face, sz, flags }
	end
	if p.font[1] then
		pcall(fs.SetFont, fs, p.font[1], size, p.font[3])
	end
end
M.Sized = sized

local function justified(fs, how)
	if not (fs and fs.SetJustifyH) then
		return
	end
	remember(fs)
	local p = placed[fs]
	if p.justify == nil then
		p.justify = fs.GetJustifyH and fs:GetJustifyH() or false
	end
	fs:SetJustifyH(how)
end

local function scaled(f, scale)
	if not (f and f.SetScale) then
		return
	end
	remember(f)
	local p = placed[f]
	if p.scale == nil then
		p.scale = f.GetScale and f:GetScale() or 1
	end
	f:SetScale(scale)
end

-- A ROW'S HEIGHT, THE MOCKUP'S (Josh 2026-09-22). The game's rows are 30 and
-- its headers 26-28, its stat lines 23 and its stat headers 40: comfortable
-- for a big window, air in a small one. Each comes down to what the mockup
-- drew - 22 for a row, 20 for a header, 18 for a stat line, 24 for a stat
-- header - by what it was, so a row type added later lands somewhere sane.
local function compactExtent(h)
	if type(h) ~= "number" or h <= 0 then
		return h
	end
	if h >= 36 then
		return 24
	elseif h >= 26 then
		return h - 8
	elseif h >= 21 then
		return h - 5
	end
	return h
end
M.CompactExtent = compactExtent

local function unplace()
	for f, p in pairs(placed) do
		if p.moved then
			pcall(f.ClearAllPoints, f)
			for _, pt in ipairs(p.points) do
				pcall(f.SetPoint, f, pt[1], pt[2], pt[3], pt[4], pt[5])
			end
		end
		if p.sized and p.w and p.h and f.SetSize then
			pcall(f.SetSize, f, p.w, p.h)
		end
		if p.coords and f.SetTexCoord then
			f:SetTexCoord(0, 1, 0, 1)
		end
		if p.mask and f.AddMaskTexture then
			pcall(f.AddMaskTexture, f, p.mask)
		end
		if p.font and p.font[1] and f.SetFont then
			pcall(f.SetFont, f, p.font[1], p.font[2], p.font[3])
		end
		if p.justify and f.SetJustifyH then
			f:SetJustifyH(p.justify)
		end
		if p.scale and f.SetScale then
			f:SetScale(p.scale)
		end
		if p.level and f.SetFrameLevel then
			f:SetFrameLevel(p.level)
		end
		placed[f] = nil
	end
end

-- the side pane: showing, unless the game's arrow has folded it away
local function paneOpen()
	local right = _G.CharacterFrameRightPaneHost
	return not right or right:IsShown()
end

-- One list row as the panel's meter: the name on the left, the value on the
-- right, and the bar a hairline under both. A header keeps its words - small,
-- in capitals, the panel's grey - and its rule (see headerRule). Rows are made
-- and reused as a list scrolls, so this runs on every row every time the list
-- updates.
local function shorter(row)
	resizing(row)
	local h = placed[row].h
	if h and h > 0 then
		row:SetHeight(compactExtent(h))
	end
end

local function header(words)
	sized(words, 10)
	local ok, text = pcall(words.GetText, words)
	if ok and type(text) == "string" and text ~= text:upper() then
		words:SetText(text:upper())
	end
end

local function compactRow(row)
	if type(row) ~= "table" or not row.GetHeight then
		return
	end
	local content = row.Content
	if not content then
		-- a header: a banner (gone), its words and a fold marker. The marker
		-- goes to the LEFT of the words, where the mockup has its chevron and
		-- where every other fold in the toolkit is (Josh 2026-09-22).
		if row.Name and not row.Label then
			shorter(row)
			header(row.Name)
			-- THE TOOLKIT'S CHEVRON (Josh 2026-09-22): the game's minus is a
			-- 13px dash, twice the mark the mockup has and nothing like the
			-- chevron every other fold in the panel wears. Its own marker says
			-- which way the section is; ours is drawn from it.
			local folded = false
			if row.StateIcon then
				local okA, atlas = pcall(row.StateIcon.GetAtlas, row.StateIcon)
				folded = okA and type(atlas) == "string" and atlas:lower():find("plus") ~= nil
				hide(row.StateIcon)
			end
			if M.Chevron then
				local c = M.Chevron(row)
				if c then
					BT.Dock.ChevronCoord(c, folded)
					c:Show()
				end
			end
			place(row.Name, { { "LEFT", row, "LEFT", 16, 0 } })
		end
		return
	end
	shorter(row)
	place(content, { { "TOPLEFT", row, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0 } })
	if content.BackgroundHighlight then
		place(content.BackgroundHighlight, {
			{ "TOPLEFT", content, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0 },
		})
	end
	local name = content.Name
	local bar = content.ReputationBar or content.SkillsBar
	if name then
		sized(name, 12)
	end
	if not (bar and name) then
		-- a statistic: its name and its figure, on one line
		if name and content.Value then
			sized(content.Value, 11)
		end
		return
	end
	-- AIR BETWEEN THE WORDS AND THE BAR (Josh 2026-09-24: "the text is
	-- sitting too close to the progress bars"). The words sat two above the
	-- middle of a 22 row and the bar three off its bottom, so a "g" reached the
	-- bar. The words go up, the bar down, and the row keeps its height.
	local text = bar.Text
	place(bar, {
		{ "BOTTOMLEFT", content, "BOTTOMLEFT", 6, M.ROW_BAR_Y },
		{ "BOTTOMRIGHT", content, "BOTTOMRIGHT", -6, M.ROW_BAR_Y },
	}, nil, 2)
	if bar.Fill then
		resizing(bar.Fill)
		bar.Fill:SetHeight(2)
	end
	if bar.Mask and bar.Fill and bar.Fill.RemoveMaskTexture and not placed[bar.Fill].mask then
		placed[bar.Fill].mask = bar.Mask
		pcall(bar.Fill.RemoveMaskTexture, bar.Fill, bar.Mask)
	end
	place(name, { { "LEFT", content, "LEFT", 6, M.ROW_TEXT_Y } })
	if text then
		place(text, { { "RIGHT", content, "RIGHT", -6, M.ROW_TEXT_Y } })
		justified(text, "RIGHT")
		sized(text, 11)
	end
end
M.CompactRow = compactRow

-- a stat row: grey label, light value, as the right panel reads
local function statRow(row)
	-- as wide as the list it is in: the game's rows are 193 wide, the pane 176
	local target = row.GetParent and row:GetParent()
	local width = target and target.GetWidth and target:GetWidth()
	if width and width > 0 and row.SetWidth and (row.Label or row.Title) then
		resizing(row)
		row:SetWidth(width)
	end
	-- the stats' own, tighter heights (see statExtent)
	local function tight()
		resizing(row)
		local h = placed[row].h
		if h and h > 0 then
			row:SetHeight(M.StatExtent(h))
		end
	end
	if row.Title and not row.Label then
		-- a stat header: small capitals beside its rule
		tight()
		header(row.Title)
		sized(row.Title, 9)
	elseif row.Label then
		-- 10 for both, the tightest text in the window: the stats are read at
		-- a glance, and the more of them fit, the less the pane scrolls
		tight()
		sized(row.Label, 10)
		sized(row.Value, 10)
	end
	if row.Label and row.Value and row.Label.SetTextColor then
		for _, fs in ipairs({ row.Label, row.Value }) do
			keepText(fs)
		end
		row.Label:SetTextColor(0.55, 0.62, 0.60)
		row.Value:SetTextColor(0.86, 0.88, 0.92)
	end
	if M.ResistRow then
		M.ResistRow(row)
	end
	if M.FoldRow then
		M.FoldRow(row)
	end
end
M.StatRow = statRow

-- ---------------------------------------------------------------------------
-- The stats: tighter, and folding
-- ---------------------------------------------------------------------------
--
-- AS MUCH AS FITS WITHOUT SCROLLING (Josh 2026-09-22). The stats are read, not
-- clicked, and the pane is short, so they get the tightest spacing in the
-- window: 15px lines at 10px, 18px headers in 9px capitals.
local function statExtent(h)
	if type(h) ~= "number" or h <= 0 then
		return h
	end
	if h >= 36 then
		return 18
	elseif h >= 21 then
		return 15
	end
	return h
end
M.StatExtent = statExtent

-- A SECTION FOLDS (Josh 2026-09-22). Click a header and its lines go; click it
-- again and they come back. The list is the game's and makes its own rows, so
-- a folded line is not hidden - the list is told it is no height at all, and
-- closes up over it. Which sections are folded is remembered.
--
-- A header is known by the data behind it: the list hands each row its piece
-- of data, and a header's is written down the first time one is drawn. A line
-- belongs to the nearest header above it in the list's own order.
M.statHeaders = setmetatable({}, { __mode = "k" })

function M.Folded(title)
	local f = opt("folded", nil)
	return type(f) == "table" and title ~= nil and f[title] == true
end

function M.ToggleFold(title)
	if not title then
		return
	end
	BT.EnsureBound()
	BT.settings.charsheet = BT.settings.charsheet or {}
	BT.settings.charsheet.folded = BT.settings.charsheet.folded or {}
	BT.settings.charsheet.folded[title] = (not M.Folded(title)) or nil
	M.Refold()
end

-- THE LIST IS REBUILT TWICE (Josh 2026-09-22). It lays its rows out from the
-- heights it has, and the heights are ours to set as each row is drawn - so
-- the first pass after a fold positions rows by what they WERE. The rows are
-- put right, then it lays out again: once immediately, so the fold is
-- instant, and once on the next frame, when every row has its new height.
function M.Refold()
	local stats = pick(_G.CharacterFrame, "CharacterStatsPaneScrollBox")
	local box = stats and stats.ScrollBox
	if not (box and box.FullUpdate) then
		return
	end
	pcall(box.FullUpdate, box, true)
	local target = box.ScrollTarget
	if target and target.GetChildren then
		for _, row in ipairs({ target:GetChildren() }) do
			M.StatRow(row)
		end
	end
	pcall(box.FullUpdate, box, true)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if M.Themed() then
				pcall(box.FullUpdate, box, true)
			end
		end)
	end
end

local function dataAt(view, index)
	local okD, dp = pcall(view.GetDataProvider, view)
	if not (okD and dp and dp.Find) then
		return nil, nil
	end
	local ok, data = pcall(dp.Find, dp, index)
	return ok and data or nil, dp
end

-- KNOWN BEFORE IT IS DRAWN (Josh 2026-09-23: "the stat accordions are still
-- not working ... most if the panel opens and a section has previously been
-- collapsed"). A header used to be known only once its row had been drawn -
-- but the list measures every line BEFORE it draws any, and draws only the
-- rows in view. So on opening, and every time the game built its list afresh
-- (new data, so nothing known), a folded section's lines were measured at
-- full height and drawn as nothing: gaps, and sections missing their lines.
--
-- Two things are learned from the first rows drawn, and kept for the session:
-- what a header's data looks like (the keys it has, which a line's does not),
-- and the section titles in the order they come. Then any row of the list can
-- be placed without being drawn: a header is data of the header's shape, and
-- it is the n-th header, so its title is the n-th title.
M.headerShape, M.lineShape = nil, nil
M.headerOrder = {}

-- worked out once per piece of data: the list asks for every row's height on
-- every layout and every step of a scroll, and this sorted a new key list
-- each time (Josh 2026-09-23, audit)
local shapes = setmetatable({}, { __mode = "k" })
local function shapeOf(data)
	if type(data) ~= "table" then
		return nil
	end
	local known = shapes[data]
	if known then
		return known
	end
	local keys = {}
	for k in pairs(data) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	known = table.concat(keys, ",")
	shapes[data] = known
	return known
end

-- whether this piece of the list's data is a header's
local function isHeader(data)
	if data == nil then
		return false
	end
	if M.statHeaders[data] then
		return true
	end
	local shape = M.headerShape
	return shape ~= nil and shape ~= M.lineShape and shapeOf(data) == shape
end

-- the index of each header in the list, in order, up to `last`
local function headersUpTo(view, last)
	local found = {}
	for j = 1, last do
		local data = dataAt(view, j)
		if data == nil then
			break
		end
		if isHeader(data) then
			found[#found + 1] = j
		end
	end
	return found
end

-- the header a line of the list sits under, and whether it is that header
function M.SectionAt(view, index)
	if type(index) ~= "number" then
		return nil, false
	end
	for j = index, 1, -1 do
		local data = dataAt(view, j)
		if isHeader(data) then
			local title = M.statHeaders[data]
			if not title then
				-- never drawn: the n-th header has the n-th title
				local n = #headersUpTo(view, j)
				title = M.headerOrder[n]
			end
			return title, j == index
		end
	end
	return nil, false
end

-- once something new is learned, the list is laid out again - once, a frame
-- later, when the rows that taught it have all been drawn
M.relearn = false
local function learned()
	if M.relearn then
		return
	end
	M.relearn = true
	local function go()
		M.relearn = false
		if M.Themed() then
			M.Refold()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, go)
	else
		go()
	end
end
M.Learned = learned

local function indexOf(view, data)
	local _, dp = dataAt(view, 1)
	if dp and dp.FindIndex then
		local ok, i = pcall(dp.FindIndex, dp, data)
		return ok and i or nil
	end
	return nil
end

-- the stats list measures its lines tight, and a folded section's as nothing
local function tightList(box)
	local view = box and box.GetView and box:GetView()
	if type(view) ~= "table" or view.beebsCompact then
		return false
	end
	view.beebsCompact = true
	-- LAID OUT AGAIN AFTER EVERY NEW LIST (Josh 2026-09-23: "the collapsed
	-- sections are not loading initially as collapsed (however their contents
	-- is still hidden)"). The game hands the list fresh data each time the
	-- sheet opens or a stat changes, and lays it out before a single row is
	-- drawn - before anything can say which lines are folded, if the data
	-- does not show it. The rows are then drawn hidden in line-sized holes.
	-- So a new list is laid out once more, a frame later, when its headers
	-- have been drawn: the same thing a click on a header did, which is why a
	-- click put everything right.
	if box.SetDataProvider and hooksecurefunc and not box.beebsRelay then
		box.beebsRelay = true
		hooksecurefunc(box, "SetDataProvider", function()
			if M.Themed() then
				M.Learned()
			end
		end)
	end
	local orig = view.GetElementExtent
	if type(orig) == "function" then
		view.GetElementExtent = function(self, index, ...)
			local h = orig(self, index, ...)
			if not M.Themed() then
				return h
			end
			local title, isHeader = M.SectionAt(self, index)
			if title and not isHeader and M.Folded(title) then
				-- A PIXEL, NOT NOTHING (Josh 2026-09-22). A folded line was
				-- given no height at all, and the game's list stops laying
				-- rows out when one measures nothing: folding a section took
				-- every section under it with it. One pixel keeps the list
				-- walking, and the line itself is not drawn.
				return 1
			end
			return statExtent(h)
		end
	end
	local tmpl = view.GetTemplateExtent
	if type(tmpl) == "function" then
		view.GetTemplateExtent = function(self, ...)
			local h = tmpl(self, ...)
			if M.Themed() then
				return statExtent(h)
			end
			return h
		end
	end
	return true
end
M.TightList = tightList

-- RESISTANCES ARE A SWATCH (Josh 2026-09-22). Each resistance line carries a
-- spell icon, drawn for a 23px row; at 15 they overlapped their own words. A
-- resistance is one thing - which element - and a square of its colour says it
-- in eight pixels, the way a tag reads in the Ledger.
M.ELEMENTS = {
	-- APART AT A GLANCE (Josh 2026-09-22): arcane and shadow were two violets
	-- a shade apart; arcane is the bright magenta it is in the spell art, and
	-- shadow the deep near-black violet
	arcane = { 0.95, 0.45, 0.95 },
	fire = { 0.95, 0.40, 0.25 },
	frost = { 0.40, 0.68, 0.95 },
	nature = { 0.35, 0.82, 0.40 },
	shadow = { 0.42, 0.26, 0.60 },
	holy = { 0.96, 0.90, 0.60 },
}

local function elementOf(row)
	local label = row.Label
	local ok, text = pcall(function() return label and label.GetText and label:GetText() end)
	if not (ok and type(text) == "string") then
		return nil
	end
	local word = text:match("^%a+")
	local colour = word and M.ELEMENTS[word:lower()]
	return colour, word
end

function M.ResistRow(row)
	local colour = elementOf(row)
	if not colour then
		-- a row the list reused for another stat keeps no swatch from the
		-- resistance it showed before (Josh 2026-09-23, audit)
		if row.beebsSwatch then
			row.beebsSwatch:Hide()
		end
		return false
	end
	-- the icon off, and a square of the element's colour in its place
	local okR, regions = pcall(function() return { row:GetRegions() } end)
	for _, r in ipairs(okR and regions or {}) do
		local okT, kind = pcall(r.GetObjectType, r)
		if okT and kind == "Texture" and not r.beebs then
			hide(r)
		end
	end
	if not row.beebsSwatch and row.CreateTexture then
		row.beebsSwatch = row:CreateTexture(nil, "OVERLAY")
		row.beebsSwatch.beebs = true
		row.beebsSwatch:SetSize(8, 8)
		row.beebsSwatch:SetPoint("LEFT", row, "LEFT", 4, 0)
	end
	if row.beebsSwatch then
		row.beebsSwatch:SetColorTexture(colour[1], colour[2], colour[3], 1)
		row.beebsSwatch:Show()
	end
	place(row.Label, { { "LEFT", row, "LEFT", 16, 0 } })
	return true
end

-- every chevron made, the stats' and the other lists' alike, so Unfold can
-- take them all away (it only found the stats' before - Josh 2026-09-23, audit)
local chevrons = setmetatable({}, { __mode = "k" })

-- the chevron beside a stat header, pointing down when open
local function chevron(row)
	if row.beebsChevron or not row.CreateTexture then
		return row.beebsChevron
	end
	local c = row:CreateTexture(nil, "OVERLAY")
	chevrons[c] = true
	c.beebs = true
	c:SetSize(8, 8)
	c:SetPoint("LEFT", row, "LEFT", 3, 0)
	c:SetTexture(BT.Dock.ICONS)
	c:SetVertexColor(0.55, 0.62, 0.60, 1)
	row.beebsChevron = c
	return c
end

-- the same chevron for a list header, which is drawn elsewhere
function M.Chevron(row)
	return chevron(row)
end

-- whether a row took the mouse before we changed it, so off gives it back
local function holdMouse(row)
	if row.beebsMouse == nil and row.IsMouseEnabled then
		local ok, on = pcall(row.IsMouseEnabled, row)
		row.beebsMouse = ok and on and true or false
	end
end

local function statTitle(row)
	local ok, text = pcall(row.Title.GetText, row.Title)
	return ok and type(text) == "string" and text:upper() or nil
end

-- one row of the stats list, every time the list draws it
function M.FoldRow(row)
	local okE, data = pcall(function() return row.GetElementData and row:GetElementData() end)
	data = okE and data or nil
	local box = row.GetParent and row:GetParent() and row:GetParent():GetParent()
	local view = box and box.GetView and box:GetView()
	if row.Title and not row.Label then
		local title = statTitle(row)
		if data and title then
			M.statHeaders[data] = title
			-- what a header looks like, and where this one comes in the order
			local fresh = false
			if not M.headerShape then
				M.headerShape = shapeOf(data)
				fresh = true
			end
			if view then
				local at = indexOf(view, data)
				local n = at and #headersUpTo(view, at)
				if n and n > 0 and M.headerOrder[n] ~= title then
					M.headerOrder[n] = title
					fresh = true
				end
			end
			if fresh then
				learned()
			end
		end
		local c = chevron(row)
		if c then
			BT.Dock.ChevronCoord(c, M.Folded(title))
			c:Show()
		end
		place(row.Title, { { "LEFT", row, "LEFT", 14, 0 } })
		-- (clickable every time: off gave the mouse back, and on again has to
		-- take it again)
		if row.EnableMouse then
			holdMouse(row)
			pcall(row.EnableMouse, row, true)
		end
		if not row.beebsFoldable and row.HookScript then
			row.beebsFoldable = true
			row:HookScript("OnMouseUp", function(self)
				if M.Themed() then
					M.ToggleFold(statTitle(self))
				end
			end)
		end
		row:SetAlpha(1)
	elseif row.Label and view and data then
		if not M.lineShape then
			M.lineShape = shapeOf(data)
			learned()
		end
		local title = M.SectionAt(view, indexOf(view, data))
		local away = title ~= nil and M.Folded(title)
		row:SetAlpha(away and 0 or 1)
		-- ITS OWN HEIGHT TOO (Josh 2026-09-22). Told the row measures a pixel,
		-- the list still laid the next one out below a row that was still 15
		-- tall - a hidden line leaving a line-sized hole. The frame comes down
		-- to the pixel as well, and the hole closes.
		--
		-- AND BACK UP AGAIN, ALWAYS (Josh 2026-09-22). A row is reused for
		-- whatever the list needs next, so one that was folded away came back
		-- a pixel tall under a section that was open - which is what the rows
		-- landing on top of each other were. Its height is set every time it
		-- is drawn, folded or not.
		if row.SetHeight then
			resizing(row)
			local h = placed[row].h
			row:SetHeight(away and 1 or M.StatExtent(h and h > 0 and h or 23))
		end
		-- and it takes no clicks while it is folded away
		if row.EnableMouse then
			holdMouse(row)
			pcall(row.EnableMouse, row, not away)
		end
	end
end

-- off: every line showing and no chevrons, whatever was folded
function M.Unfold()
	for c in pairs(chevrons) do
		c:Hide()
	end
	local stats = pick(_G.CharacterFrame, "CharacterStatsPaneScrollBox")
	local target = stats and stats.ScrollBox and stats.ScrollBox.ScrollTarget
	if not (target and target.GetChildren) then
		return
	end
	for _, row in ipairs({ target:GetChildren() }) do
		row:SetAlpha(1)
		if row.beebsSwatch then
			row.beebsSwatch:Hide()
		end
		-- a folded line took no clicks, so no tooltip: the mouse as the game
		-- had it
		if row.beebsMouse ~= nil and row.EnableMouse then
			pcall(row.EnableMouse, row, row.beebsMouse)
		end
	end
end

-- THE LIST MEASURES ITS ROWS ITSELF, so a shorter row alone just leaves a
-- gap under it. Each list's view is asked what a row's height is, and while
-- the theme is on the answer is the compact one; the list is laid out again
-- so the rows close up. Off, the view answers as it always did.
local function compactList(box)
	local view = box and box.GetView and box:GetView()
	if type(view) ~= "table" or view.beebsCompact then
		return false
	end
	view.beebsCompact = true
	for _, method in ipairs({ "GetElementExtent", "GetTemplateExtent" }) do
		local orig = view[method]
		if type(orig) == "function" then
			view[method] = function(self, ...)
				local h = orig(self, ...)
				if M.Themed() then
					return compactExtent(h)
				end
				return h
			end
		end
	end
	return true
end

function M.Lists()
	local frame = _G.CharacterFrame
	local out = {}
	for _, key in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame", "TokenFrame" }) do
		local page = pick(frame, key)
		if page and page.ScrollBox then
			out[#out + 1] = page.ScrollBox
		end
	end
	local stats = pick(frame, "CharacterStatsPaneScrollBox")
	if stats and stats.ScrollBox then
		out[#out + 1] = stats.ScrollBox
	end
	return out
end

function M.CompactLists()
	local stats = pick(_G.CharacterFrame, "CharacterStatsPaneScrollBox")
	local statBox = stats and stats.ScrollBox
	for _, box in ipairs(M.Lists()) do
		local changed
		if box == statBox then
			changed = tightList(box)
		else
			changed = compactList(box)
		end
		if changed and box.FullUpdate then
			pcall(box.FullUpdate, box, true)
		end
	end
end

function M.RelayoutLists()
	for _, box in ipairs(M.Lists()) do
		if box.FullUpdate then
			pcall(box.FullUpdate, box, true)
		end
	end
end

function M.EachRow(fn)
	local frame = _G.CharacterFrame
	if not frame then
		return
	end
	for _, key in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame", "TokenFrame" }) do
		local page = pick(frame, key)
		local target = page and page.ScrollBox and page.ScrollBox.ScrollTarget
		if target and target.GetChildren then
			for _, row in ipairs({ target:GetChildren() }) do
				fn(row)
			end
		end
	end
	local stats = pick(frame, "CharacterStatsPaneScrollBox")
	local target = stats and stats.ScrollBox and stats.ScrollBox.ScrollTarget
	if target and target.GetChildren then
		for _, row in ipairs({ target:GetChildren() }) do
			statRow(row)
		end
	end
end

-- THE SIDE TABS: 30px tiles down the right edge, the game's picture cropped
-- inside its own ring and unmasked, so it reads as an icon on our tile.
-- AT THE MOMENT THE GAME RESIZES IT, NOT A FRAME LATER (Josh 2026-09-22).
-- Folding the side pane makes the game lay its tabs out again at their own
-- 55px, and putting that right on the next frame was a visible flash of one
-- big tab. Each tab says when its size changes, and is put back in the same
-- frame, before anything is drawn.
local sizing = false

-- THE GLOW COMES BACK BY ITSELF (Josh 2026-09-22). Choosing a tab plays an
-- animation on the selected art, which shows it and fades its alpha up -
-- straight past the alpha of nothing it was given. Hidden it stays hidden,
-- and if the animation shows it again it is hidden again in the same frame.
local holding = false
-- every texture held down, so Undress can let the wanted ones up again
local held = setmetatable({}, { __mode = "k" })

-- (SetShown as well as Show and Hide, and held down again when the theme
-- comes back on after Undress let it up - Josh 2026-09-23, audit)
local function wanted(self, show)
	if holding then
		return
	end
	self.beebsWanted = show and true or false
	if show and M.Themed() then
		holding = true
		self:Hide()
		holding = false
	end
end

local function stayDown(tex)
	if not (tex and tex.Hide) then
		return
	end
	if not tex.beebsDown then
		tex.beebsDown = true
		tex.beebsWanted = tex.IsShown and tex:IsShown() or false
		if type(hooksecurefunc) == "function" then
			pcall(hooksecurefunc, tex, "Show", function(self)
				wanted(self, true)
			end)
			pcall(hooksecurefunc, tex, "Hide", function(self)
				wanted(self, false)
			end)
			pcall(hooksecurefunc, tex, "SetShown", function(self, show)
				wanted(self, show)
			end)
		end
	end
	held[tex] = true
	-- only when it is showing: every layout comes through here, and a Hide
	-- is a call the window's watchers hear
	if not tex.IsShown or tex:IsShown() then
		holding = true
		tex:Hide()
		holding = false
	end
end
M.StayDown = stayDown

local function placeTab(tabs, tab, i)
	place(tab, { { "TOPLEFT", tabs, "TOPLEFT", 0, -(i - 1) * (M.TAB + 3) } }, M.TAB, M.TAB)
	for _, key in ipairs({ "TabGlow", "SelectedTexture", "HighlightTexture" }) do
		stayDown(tab[key])
	end
	local icon = tab.Icon
	if not icon then
		return
	end
	place(icon, { { "CENTER", tab, "CENTER", 0, 0 } }, M.TAB - 6, M.TAB - 6)
	-- ITS PICTURE IS SET AGAIN when a tab is chosen, at the size it was drawn
	-- for; that is the flash. Setting it is what puts it back.
	if not icon.beebsSized and type(hooksecurefunc) == "function" then
		icon.beebsSized = true
		for _, method in ipairs({ "SetSize", "SetTexture", "SetAtlas", "SetWidth", "SetHeight" }) do
			if type(icon[method]) == "function" then
				pcall(hooksecurefunc, icon, method, function(self)
					if sizing or not M.Themed() then
						return
					end
					sizing = true
					self:SetSize(M.TAB - 6, M.TAB - 6)
					self:SetTexCoord(0.16, 0.84, 0.16, 0.84)
					sizing = false
				end)
			end
		end
	end
	if tab.Mask and icon.RemoveMaskTexture and not placed[icon].mask then
		placed[icon].mask = tab.Mask
		pcall(icon.RemoveMaskTexture, icon, tab.Mask)
	end
	if not placed[icon].coords then
		placed[icon].coords = true
		icon:SetTexCoord(0.16, 0.84, 0.16, 0.84)
	end
end

local function layoutTabs(frame)
	local tabs = pick(frame, "CharacterFrameModeTabs")
	if not tabs then
		return
	end
	place(tabs, { { "TOPLEFT", frame, "TOPRIGHT", 4, -M.TITLE - 4 } }, M.TAB, (M.TAB + 3) * 8)
	for i = 1, 8 do
		local tab = pick(tabs, "CharacterFrameModeTab" .. i)
		if tab then
			placeTab(tabs, tab, i)
			if not tab.beebsSizing and tab.HookScript then
				tab.beebsSizing = true
				tab:HookScript("OnSizeChanged", function(self)
					if sizing or not M.Themed() then
						return
					end
					sizing = true
					placeTab(tabs, self, i)
					sizing = false
				end)
			end
		end
	end
end

local function layoutDoll(frame, left)
	local slot, gap = M.SLOT, M.GAP
	local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
	local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
	for i, name in ipairs(LEFT) do
		local b = _G["Character" .. name .. "Slot"]
		place(b, { { "TOPLEFT", left, "TOPLEFT", 6, -6 - (i - 1) * (slot + gap) } }, slot, slot)
	end
	for i, name in ipairs(RIGHT) do
		local b = _G["Character" .. name .. "Slot"]
		place(b, { { "TOPRIGHT", left, "TOPRIGHT", -6, -6 - (i - 1) * (slot + gap) } }, slot, slot)
	end
	-- the weapons in one even row under the model: main hand, off hand,
	-- ranged, and ammunition where the class has any
	local row = { _G.CharacterMainHandSlot, _G.CharacterSecondaryHandSlot, _G.CharacterRangedSlot }
	local ammo = _G.CharacterAmmoSlot
	if ammo and ammo.IsShown and ammo:IsShown() then
		row[#row + 1] = ammo
	end
	for i, b in ipairs(row) do
		local off = (i - (#row + 1) / 2) * (slot + gap)
		place(b, { { "BOTTOM", left, "BOTTOM", off, 6 } }, slot, slot)
	end
	-- every slot's icon fills it, a pixel inside our edge
	for _, name in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands",
		"Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand",
		"Ranged", "Ammo" }) do
		local b = _G["Character" .. name .. "Slot"]
		local icon = b and _G["Character" .. name .. "SlotIconTexture"]
		if icon then
			place(icon, { { "TOPLEFT", b, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1 } })
		end
	end
	-- the model between the columns, above the weapons
	local scene = _G.CharacterModelScene
	place(scene, {
		{ "TOPLEFT", left, "TOPLEFT", 6 + slot + 4, -4 },
		{ "BOTTOMRIGHT", left, "BOTTOMRIGHT", -(6 + slot + 4), 6 + slot + 4 },
	})
end

local function layoutSide(frame, right)
	-- the stats / titles / sets buttons along the top, small
	local bar = pick(frame, "PaperDollSidebarTabs")
	if bar then
		place(bar, { { "TOPLEFT", right, "TOPLEFT", 8, -6 }, { "TOPRIGHT", right, "TOPRIGHT", -8, -6 } }, nil, 24)
		for i = 1, 3 do
			local t = _G["PaperDollSidebarTab" .. i]
			if t then
				place(t, { { "LEFT", bar, "LEFT", (i - 1) * 27, 0 } }, 24, 24)
				if t.Icon then
					place(t.Icon, { { "TOPLEFT", t, "TOPLEFT", 2, -2 }, { "BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2 } })
				end
			end
		end
	end
	-- your level and class go up into the title bar, beside your name (see
	-- layoutTitle), so the pane opens straight onto the stats
	-- the stats, titles and sets fill the rest
	for _, key in ipairs({ "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" }) do
		local pane = pick(frame, key)
		place(pane, { { "TOPLEFT", right, "TOPLEFT", 0, -32 }, { "BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 2 } })
		-- the list inside it, and its bar, within the pane rather than the
		-- game's 233 pixels - close to the edges, the pane is short
		if pane and pane.ScrollBox then
			place(pane.ScrollBox, {
				{ "TOPLEFT", pane, "TOPLEFT", 4, 0 },
				{ "BOTTOMRIGHT", pane, "BOTTOMRIGHT", -8, 0 },
			})
			if pane.ScrollBar then
				place(pane.ScrollBar, {
					{ "TOPLEFT", pane.ScrollBox, "TOPRIGHT", 3, 0 },
					{ "BOTTOMLEFT", pane.ScrollBox, "BOTTOMRIGHT", 3, 0 },
				})
			end
		end
	end
	local doll = pick(frame, "PaperDollFrame")
	for _, key in ipairs({ "EquipmentManagerPane", "TitleManagerPane" }) do
		local pane = pick(doll, key)
		place(pane, { { "TOPLEFT", right, "TOPLEFT", 0, -34 }, { "BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 4 } })
		if pane and pane.ScrollBox then
			local top = key == "EquipmentManagerPane" and -32 or -2
			local bottom = key == "EquipmentManagerPane" and 32 or 2
			place(pane.ScrollBox, {
				{ "TOPLEFT", pane, "TOPLEFT", 8, top },
				{ "BOTTOMRIGHT", pane, "BOTTOMRIGHT", -12, bottom },
			})
			if pane.ScrollBar then
				place(pane.ScrollBar, {
					{ "TOPLEFT", pane.ScrollBox, "TOPRIGHT", 3, 0 },
					{ "BOTTOMLEFT", pane.ScrollBox, "BOTTOMRIGHT", 3, 0 },
				})
			end
		end
	end
	-- THE SETS' BUTTONS, IN THE PANE: New set along the top, Equip and Save
	-- side by side along the bottom, as the mockup's Sets view has them
	local sets = pick(doll, "EquipmentManagerPane")
	if sets then
		place(pick(sets, "PaperDollFrameNewSet"), {
			{ "TOPLEFT", sets, "TOPLEFT", 8, -4 }, { "TOPRIGHT", sets, "TOPRIGHT", -8, -4 },
		}, nil, 24)
		local half = (M.PANE - 16 - 4) / 2
		place(pick(sets, "PaperDollFrameEquipSet"), { { "BOTTOMLEFT", sets, "BOTTOMLEFT", 8, 4 } }, half, 22)
		place(pick(sets, "PaperDollFrameSaveSet"), { { "BOTTOMRIGHT", sets, "BOTTOMRIGHT", -8, 4 } }, half, 22)
	end
end

-- THE TITLE BAR, AS THE MOCKUP HAS IT: the name on the left, and on the
-- character page your level and class beside it, quieter
local function layoutTitle(frame)
	local title = _G.CharacterFrameTitleText
	if not title then
		return
	end
	place(title, { { "LEFT", frame, "TOPLEFT", 10, -11 } }, 240, 16)
	justified(title, "LEFT")
	sized(title, 13)
	local info = _G.PaperDollLevelInfo
	local text = _G.CharacterLevelText
	if info and text then
		local w = BT.Pill.Number(title.GetStringWidth and title:GetStringWidth(), 90)
		place(info, { { "LEFT", frame, "TOPLEFT", 10 + w + 8, -11 } }, 200, 16)
		place(text, { { "LEFT", info, "LEFT", 0, 0 } }, 200, 16)
		justified(text, "LEFT")
		sized(text, 11)
		keepText(text)
		text:SetTextColor(0.55, 0.62, 0.60)
	end
end

local function layoutPages(frame, left, right)
	for _, key in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame", "TokenFrame" }) do
		local page = pick(frame, key)
		if page and page.ScrollBox then
			place(page.ScrollBox, {
				{ "TOPLEFT", left, "TOPLEFT", 6, -6 },
				{ "BOTTOMRIGHT", left, "BOTTOMRIGHT", -14, 6 },
			})
			if page.ScrollBar then
				place(page.ScrollBar, {
					{ "TOPLEFT", page.ScrollBox, "TOPRIGHT", 3, 0 },
					{ "BOTTOMLEFT", page.ScrollBox, "BOTTOMRIGHT", 3, 0 },
				})
			end
		end
	end
	local details = {
		pick(pick(frame, "ReputationFrame"), "ReputationDetailFrame"),
		pick(pick(frame, "SkillsFrame"), "SkillDetailFrame"),
		pick(pick(frame, "TokenFrame"), "TokenDetailFrame"),
		pick(frame, "PVPRankFrame") and pick(frame, "PVPRankFrame").DetailFrame,
	}
	-- a details pane's pieces were drawn for 205 pixels; each is the pane's
	-- width now, so a title centres on it and a bar ends at its edge
	local inner = M.PANE - 20
	-- EVERY LINE IN THE PANE, NOT ONLY THE PANE (Josh 2026-09-22). The pieces
	-- were fitted and the words inside them were not: a description is a frame
	-- with its own 191px line of text in it, which ran past the window's edge
	-- and wrapped where it liked.
	-- the words sit inside the pane with a margin of their own, and anything
	-- else in there - a button, a reward - is no wider than the pane either
	local text = inner - 8
	local function fitWords(f, depth)
		if type(f) ~= "table" or depth > 4 or f.beebs then
			return
		end
		local okR, regions = pcall(function() return { f:GetRegions() } end)
		for _, r in ipairs(okR and regions or {}) do
			local okT, kind = pcall(r.GetObjectType, r)
			if okT and kind == "FontString" and not r.beebs then
				local okW, w = pcall(r.GetWidth, r)
				if okW and type(w) == "number" and w > text then
					resizing(r)
					r:SetWidth(text)
					if r.SetWordWrap then
						pcall(r.SetWordWrap, r, true)
					end
				end
				-- the mockup's sizes: a title at 14, everything under it at 11
				sized(r, 11)
			end
		end
		local okC, kids = pcall(function() return { f:GetChildren() } end)
		for _, kid in ipairs(okC and kids or {}) do
			local okW, w = pcall(kid.GetWidth, kid)
			if okW and type(w) == "number" and w > inner and kid.SetWidth then
				resizing(kid)
				kid:SetWidth(inner)
			end
			fitWords(kid, depth + 1)
		end
	end
	for _, d in pairs(details) do
		fitWords(d, 0)
		place(d, { { "TOPLEFT", right, "TOPLEFT", 4, -4 }, { "BOTTOMRIGHT", right, "BOTTOMRIGHT", -4, 4 } })
		for _, key in ipairs({ "Title", "Subtitle", "EmptyText", "Description", "Content", "Footer", "Divider" }) do
			local piece = d[key]
			if piece and piece.SetWidth then
				resizing(piece)
				piece:SetWidth(inner)
			end
		end
		-- the pane's own heading, a size up from what it holds
		sized(d.Title, 14)
		sized(d.Subtitle, 11)
		for _, key in ipairs({ "StandingBar", "RankBar" }) do
			local dbar = d[key]
			if dbar and dbar.SetWidth then
				resizing(dbar)
				dbar:SetWidth(inner - 4)
				if dbar.Text then
					sized(dbar.Text, 11)
				end
			end
		end
	end
	-- A DETAILS PANE, LAID OUT (Josh 2026-09-22). Its pieces were drawn for a
	-- 205px pane and anchored to each other in the game's own order, so in a
	-- 176px one the bar sat over the description and its numbers over the
	-- standing. Each piece is placed here, top to bottom, with the same
	-- spacing the mockup has: title, standing, the meter and its numbers, the
	-- words, and the switches along the bottom.
	for _, d in pairs(details) do
		local bar = d.StandingBar or d.RankBar
		local y = -6
		-- the name and the standing on the left, as the mockup reads them
		if d.Title then
			place(d.Title, { { "TOPLEFT", d, "TOPLEFT", 8, y } })
			justified(d.Title, "LEFT")
			y = y - 18
		end
		if d.Subtitle and d.Subtitle:IsShown() then
			place(d.Subtitle, { { "TOPLEFT", d, "TOPLEFT", 8, y } })
			justified(d.Subtitle, "LEFT")
			y = y - 14
		end
		if bar then
			resizing(bar)
			bar:SetHeight(6)
			if bar.Fill then
				resizing(bar.Fill)
				bar.Fill:SetHeight(6)
				if bar.Mask and bar.Fill.RemoveMaskTexture and not placed[bar.Fill].mask then
					placed[bar.Fill].mask = bar.Mask
					pcall(bar.Fill.RemoveMaskTexture, bar.Fill, bar.Mask)
				end
			end
			if bar.Text then
				-- the numbers on their own line over the meter, right-aligned,
				-- clear of the title over them and of the meter under them
				-- (Josh 2026-09-24: they sat on both)
				place(bar.Text, { { "BOTTOMRIGHT", bar, "TOPRIGHT", 0, 5 } })
				if bar.Text.SetJustifyH then
					bar.Text:SetJustifyH("RIGHT")
				end
				sized(bar.Text, 11)
				y = y - 20
			end
			place(bar, { { "TOPLEFT", d, "TOPLEFT", 8, y }, { "TOPRIGHT", d, "TOPRIGHT", -8, y } }, nil, 6)
			y = y - 14
		end
		if d.Divider then
			place(d.Divider, { { "TOP", d, "TOP", 0, y } })
			y = y - 8
		end
		-- THE WORDS FILL WHAT IS LEFT (Josh 2026-09-22). The description is a
		-- scrolling box, and the game sized it for a 436px pane: anchored only
		-- by its top it kept that height and cut its own first line off. Top
		-- AND bottom, so it is exactly the room between the meter and whatever
		-- sits along the bottom of the pane.
		local floor = (d == pick(pick(frame, "ReputationFrame"), "ReputationDetailFrame")) and (8 + 3 * 22) or 8
		local function up(piece)
			return piece and piece.IsShown and piece:IsShown()
		end
		if up(d.Description) and up(d.Content) then
			-- BOTH, AS THE PVP PANE HAS (Josh 2026-09-29: "the next pvp reward is
			-- still not moved"): the words, and under them the next rank's
			-- rewards. The game hangs the rewards from the pane's bottom edge,
			-- which put them under the window; they stand on the pane's floor
			-- instead, as tall as what is in them, and the words take the rest.
			local tall = M.ContentHeight(d.Content)
			place(d.Content, {
				{ "BOTTOMLEFT", d, "BOTTOMLEFT", 8, floor },
				{ "BOTTOMRIGHT", d, "BOTTOMRIGHT", -8, floor },
			}, nil, tall)
			place(d.Description, {
				{ "TOPLEFT", d, "TOPLEFT", 8, y },
				{ "BOTTOMRIGHT", d.Content, "TOPRIGHT", 0, 8 },
			})
		else
			for _, key in ipairs({ "Description", "Content" }) do
				local piece = d[key]
				if up(piece) then
					place(piece, {
						{ "TOPLEFT", d, "TOPLEFT", 8, y },
						{ "BOTTOMRIGHT", d, "BOTTOMRIGHT", -8, floor },
					})
					break
				end
			end
		end
		if d.EmptyText and d.EmptyText.IsShown and d.EmptyText:IsShown() then
			place(d.EmptyText, { { "TOP", d, "TOP", 0, y - 10 } })
		end
	end
	-- the switches, along the bottom of the pane where nothing else is
	local repDetail2 = pick(pick(frame, "ReputationFrame"), "ReputationDetailFrame")
	local boxes = repDetail2 and { repDetail2.WatchFactionCheckbox, repDetail2.MakeInactiveCheckbox,
		repDetail2.AtWarCheckbox } or {}
	for i, box in ipairs(boxes) do
		if box and box.SetSize then
			resizing(box)
			box:SetSize(16, 16)
			place(box, { { "BOTTOMLEFT", repDetail2, "BOTTOMLEFT", 8, 8 + (i - 1) * 22 } }, 16, 16)
		end
		local label = box and box.Label
		if label and label.SetTextColor then
			keepText(label)
			local enabled = not box.IsEnabled or box:IsEnabled()
			if enabled then
				label:SetTextColor(0.86, 0.88, 0.92)
			end
			sized(label, 11)
			place(label, { { "LEFT", box, "RIGHT", 6, 0 } })
		end
	end
	local rank = pick(frame, "PVPRankFrame")
	local info = rank and rank.MainInfoFrame
	if info then
		scaled(info, 0.68)
		-- ITS OWN SIZE, KEPT (Josh 2026-09-22). Anchored by one point it came
		-- out 0x0, and the client draws nothing inside a frame with no size:
		-- the rank, the ring and the points all went with it. /bt sheetdump
		-- showed it.
		remember(info)
		local w, h = placed[info].w, placed[info].h
		if not (w and w > 0) then
			w = 398
		end
		if not (h and h > 0) then
			h = 135
		end
		place(info, { { "TOP", left, "TOP", 0, -10 / 0.68 } }, w, h)
		if info.SetFrameLevel and left.GetFrameLevel then
			remember(info)
			if placed[info].level == nil then
				placed[info].level = info:GetFrameLevel()
			end
			info:SetFrameLevel(left:GetFrameLevel() + 10)
		end
		info:SetAlpha(1)
		info:Show()
	end
end

-- How tall a pane's list of pieces really is: the game gives the PvP
-- rewards 141 pixels and puts its last line of words, 45 tall, at 117 down.
-- Each piece's own offset from the list's top, and the tallest of it and
-- its words, whichever reaches lowest.
function M.ContentHeight(content)
	local okH, h = pcall(content.GetHeight, content)
	local tall = okH and type(h) == "number" and h or 0
	local okC, kids = pcall(function() return { content:GetChildren() } end)
	for _, kid in ipairs(okC and kids or {}) do
		local okP, point, rel, _, _, y = pcall(kid.GetPoint, kid, 1)
		if okP and point == "TOPLEFT" and rel == content and type(y) == "number" then
			local okK, kh = pcall(kid.GetHeight, kid)
			local own = okK and type(kh) == "number" and kh or 0
			local okR, regions = pcall(function() return { kid:GetRegions() } end)
			for _, r in ipairs(okR and regions or {}) do
				local okT, rh = pcall(r.GetHeight, r)
				if okT and type(rh) == "number" and rh > own then
					own = rh
				end
			end
			tall = math.max(tall, -y + own)
		end
	end
	return math.floor(tall + 0.5)
end

local laying = false
local function layoutBody(frame)
	local open = paneOpen()
	local width = open and M.W or (M.W - M.PANE)
	resizing(frame)
	frame:SetSize(width, M.H)
	local left, right = pick(frame, "CharacterFrameLeftPaneHost"), pick(frame, "CharacterFrameRightPaneHost")
	if left then
		place(left, {
			{ "TOPLEFT", frame, "TOPLEFT", 0, -M.TITLE },
			{ "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0 },
		}, M.W - M.PANE)
	end
	if right then
		place(right, {
			{ "TOPRIGHT", frame, "TOPRIGHT", 0, -M.TITLE },
			{ "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 },
		}, M.PANE)
	end
	-- THE ARROW IN THE TITLE BAR, beside the close button, where it is out of
	-- the way of the slots and the lists and reads as the window's own control
	local toggle = pick(frame, "CharacterFrameRightPaneToggleButton")
	if toggle then
		place(toggle, { { "TOPRIGHT", frame, "TOPRIGHT", -24, -2 } }, 18, 18)
	end
	if left then
		layoutDoll(frame, left)
		layoutPages(frame, left, right or left)
	end
	if right then
		layoutSide(frame, right)
	end
	layoutTabs(frame)
	layoutTitle(frame)
	M.CompactLists()
	M.EachRow(compactRow)
	return true
end

function M.Layout()
	local frame = _G.CharacterFrame
	if laying or not (frame and M.Themed()) then
		return false
	end
	-- GUARDED (Josh 2026-09-22). One error in here - a piece a build renamed
	-- - left `laying` set for the rest of the session and Layout silently
	-- never ran again. The flag is cleared on every way out.
	laying = true
	local ok, err = pcall(layoutBody, frame)
	laying = false
	if not ok then
		BT.Err("charsheet.Layout: " .. tostring(err))
		return false
	end
	return err and true or false
end

function M.Unlayout()
	M.Unfold()
	unplace()
	-- the lists measure their rows the game's way again
	M.RelayoutLists()
end

-- ---------------------------------------------------------------------------
-- Where it sits
-- ---------------------------------------------------------------------------
--
-- DRAGGED BY ITS TITLE, AND IT STAYS (Josh 2026-09-22). The game places this
-- window itself, through the panel manager that lines windows up along the
-- left of the screen, and puts it back there every time it opens or another
-- window opens beside it. Taking it out of that manager means writing to one
-- of the game's own tables, which is how an addon earns "action blocked" in
-- combat. So the manager is left to do its work, and the window is put back
-- where you left it straight after - from hooks, which change nothing of the
-- game's.

function M.Moves()
	return BT.Enabled("charsheet") and opt("move", true) and true or false
end

function M.SavePosition()
	local frame = _G.CharacterFrame
	if not (frame and frame.GetLeft and frame:GetLeft()) then
		return nil
	end
	local num = BT.Pill.Number
	local scale = num(frame:GetEffectiveScale(), 1)
	local parentScale = num(UIParent:GetEffectiveScale(), 1)
	local top = num(frame:GetTop(), 0)
	local parentTop = num(UIParent:GetTop(), 0)
	BT.EnsureBound()
	BT.settings.charsheet = BT.settings.charsheet or {}
	BT.settings.charsheet.pos = {
		x = math.floor(num(frame:GetLeft(), 0) + 0.5),
		y = math.floor((top * scale - parentTop * parentScale) / scale + 0.5),
	}
	return BT.settings.charsheet.pos
end

function M.ApplyPosition()
	local frame = _G.CharacterFrame
	local pos = opt("pos", nil)
	if not (frame and pos and M.Moves() and frame:IsShown()) then
		return false
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x or 0, pos.y or 0)
	return true
end

function M.ResetPosition()
	if BT.settings and BT.settings.charsheet then
		BT.settings.charsheet.pos = nil
	end
	if type(_G.UpdateUIPanelPositions) == "function" then
		pcall(_G.UpdateUIPanelPositions, _G.CharacterFrame)
	end
end

-- the handle: the title bar, short of the arrow and the close button
local handle
function M.Handle()
	local frame = _G.CharacterFrame
	if handle or not frame then
		return handle
	end
	handle = CreateFrame("Frame", nil, frame)
	handle.beebs = true
	handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, 0)
	handle:SetHeight(22)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function(self)
		if M.Moves() then
			self.moving = true
			frame:SetMovable(true)
			frame:SetClampedToScreen(true)
			frame:StartMoving()
		end
	end)
	handle:SetScript("OnDragStop", function(self)
		-- with "drag it by its title" off nothing moved, and there is no
		-- position to write down
		if not self.moving then
			return
		end
		self.moving = false
		frame:StopMovingOrSizing()
		-- ours to keep, not the client's layout cache's
		if frame.SetUserPlaced then
			pcall(frame.SetUserPlaced, frame, false)
		end
		M.SavePosition()
		M.ApplyPosition()
	end)
	return handle
end

local placing = false
local function watchPosition()
	if placing then
		return
	end
	local frame = _G.CharacterFrame
	if not frame then
		return
	end
	placing = true
	M.Handle()
	local function back()
		if M.Moves() then
			M.ApplyPosition()
			if C_Timer and C_Timer.After then
				C_Timer.After(0, M.ApplyPosition)
			end
		end
	end
	frame:HookScript("OnShow", back)
	if type(hooksecurefunc) == "function" and type(_G.UpdateUIPanelPositions) == "function" then
		pcall(hooksecurefunc, "UpdateUIPanelPositions", function()
			if frame:IsShown() then
				back()
			end
		end)
	end
end
M.WatchPosition = watchPosition

-- ---------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------

function M.Dress()
	local frame = _G.CharacterFrame
	if not (frame and M.Themed()) then
		return false
	end
	dressFrame(frame)
	dressTree(frame, 0)
	dressClose(pick(frame, "CharacterFrameCloseButton"))
	dressToggle(pick(frame, "CharacterFrameRightPaneToggleButton"))
	for _, name in ipairs(M.SLOTS) do
		M.DressSlot(_G["Character" .. name .. "Slot"])
	end
	for _, name in ipairs({ "Shirt", "Tabard", "Ammo" }) do
		M.DressSlot(_G["Character" .. name .. "Slot"])
	end
	-- the tabs' lit state, now that their surfaces exist
	for f, o in pairs(dressed) do
		if o.kind == "tab" and o.surface then
			BT.Pill.PaintSurface(o.surface, f, M.Selected(f) and BT.Widgets.RAISED or FILL, RIM)
		end
	end
	M.Layout()
	return true
end

function M.Undress()
	M.Unlayout()
	-- the selected tab's glow and art, which stayDown kept hidden while the
	-- theme was on, come back if the client wanted them shown
	for tex in pairs(held) do
		if tex.beebsWanted and tex.Show then
			holding = true
			pcall(tex.Show, tex)
			holding = false
		end
	end
	for r, w in pairs(was) do
		if w.alpha then
			r:SetAlpha(w.alpha)
		end
		if w.vertex then
			r:SetVertexColor(w.vertex[1], w.vertex[2], w.vertex[3], w.vertex[4])
			if r.SetDesaturated then
				pcall(r.SetDesaturated, r, w.desat and true or false)
			end
		end
		if w.coords then
			r:SetTexCoord(0, 1, 0, 1)
		end
		if w.text then
			r:SetTextColor(w.text[1], w.text[2], w.text[3])
		end
		if w.justify and r.SetJustifyH then
			r:SetJustifyH(w.justify)
		end
		if w.at then
			r:ClearAllPoints()
			pcall(r.SetPoint, r, w.at[1], w.at[2], w.at[3], w.at[4], w.at[5])
		end
		was[r] = nil
	end
	for f, o in pairs(dressed) do
		if o.surface then
			BT.Pill.ShowSurface(o.surface, false)
		end
		if o.rule then o.rule:Hide() end
		if o.cross then o.cross:Hide() end
		if o.titleRule then o.titleRule:Hide() end
		if o.seam then o.seam:Hide() end
		if o.chevron then o.chevron:Hide() end
		undressSlot(f)
	end
	local frame = _G.CharacterFrame
	if frame then
		local h = BT.Pill.Panels()[frame]
		if h then
			BT.Pill.ShowSurface(h, false)
		end
		BT.Widgets.ShowShadow(frame, false)
	end
end

function M.SetThemed(on)
	BT.EnsureBound()
	BT.settings.charsheet = BT.settings.charsheet or {}
	BT.settings.charsheet.theme = on and true or false
	M.Apply()
end

function M.Apply()
	if M.Themed() then
		M.Dress()
	else
		M.Undress()
	end
end

-- AGAIN WHENEVER THE CLIENT DRAWS SOMETHING NEW: the window opening, a tab
-- opening, a list making rows as it scrolls, a slot's item changing, a tab
-- being chosen. Each pass is the same walk; a region already dressed is
-- dressed again to the same thing.
-- the game has just sized the window: ours again, before it is drawn
function M.OnSheetSized()
	if M.Themed() then
		return M.Layout()
	end
	return false
end

local watching = false
local function watchTheme()
	if watching then
		return
	end
	local frame = _G.CharacterFrame
	if not frame then
		return
	end
	watching = true
	-- ONCE A FRAME (Josh 2026-09-23, audit): this is hooked to the window,
	-- every page and all eight tabs' Show, Hide and SetShown, and opening the
	-- sheet set off a dozen of them at once - a dozen full dressings of a
	-- window of two thousand pieces, and a dozen layouts queued behind them.
	-- The first in a frame dresses (so nothing flashes in the game's look);
	-- the rest wait for the one layout that follows.
	local dressed, trailing = false, false
	local function again()
		if not M.Themed() then
			return
		end
		if not (C_Timer and C_Timer.After) then
			M.Dress()
			return
		end
		if not dressed then
			dressed = true
			M.Dress()
		end
		-- and once more after the game's own layout pass, which can put a
		-- tab or a pane back the moment after a page opens
		if not trailing then
			trailing = true
			C_Timer.After(0, function()
				dressed, trailing = false, false
				if M.Themed() then
					M.Layout()
					-- and the stats' folds, now their headers are drawn
					M.Refold()
				end
			end)
		end
	end
	frame:HookScript("OnShow", again)
	-- NO LARGE FRAME FIRST (Josh 2026-09-24: "it is very briefly large before
	-- resizing... kind of causing a flashing"). The game sizes the window
	-- itself as it opens - its pages do it in their own OnShow, after ours -
	-- and the layout that put our size back came a frame later: one frame
	-- drawn at the game's size. Laid out again the moment the game sizes it,
	-- before anything is drawn (Layout's own guard keeps our resize from
	-- answering itself).
	frame:HookScript("OnSizeChanged", M.OnSheetSized)
	-- folding the side pane away: the game narrows the window after it hides
	-- the pane, so the layout goes a frame later and has the last word
	local right = pick(frame, "CharacterFrameRightPaneHost")
	if right and right.HookScript then
		local function later()
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if M.Themed() then
						M.Layout()
					end
				end)
			end
		end
		right:HookScript("OnShow", later)
		right:HookScript("OnHide", later)
	end
	for _, key in ipairs({ "PaperDollFrame", "ReputationFrame", "SkillsFrame", "PVPRankFrame",
		"StatisticsFrame", "TokenFrame" }) do
		local page = pick(frame, key)
		if page and page.HookScript then
			page:HookScript("OnShow", again)
		end
	end
	-- every list: rows are made and reused as it scrolls
	local function hookLists(f, depth)
		if type(f) ~= "table" or depth > 8 then
			return
		end
		if f.ScrollTarget and type(f.Update) == "function" and not f.beebsHooked then
			f.beebsHooked = true
			pcall(hooksecurefunc, f, "Update", function(self)
				if not M.Themed() then
					return
				end
				dressTree(self, 0)
				-- the stat rows as stats, every other list's rows compact - as
				-- M.EachRow does. Both on every list gave the pet's stats the
				-- player's folds, and its rows the stats' heights in a list
				-- that measures them its own way (Josh 2026-09-23, audit).
				local stats = pick(_G.CharacterFrame, "CharacterStatsPaneScrollBox")
				local isStats = stats and stats.ScrollBox == self
				local target = self.ScrollTarget
				if target and target.GetChildren then
					for _, row in ipairs({ target:GetChildren() }) do
						if isStats then
							M.StatRow(row)
						else
							M.CompactRow(row)
						end
					end
				end
				-- CHOOSING A ROW REFILLS THE PANE BESIDE IT, in the game's own
				-- order and anchors; the layout runs again so it is laid out
				-- in ours. Not on every frame of a scroll: a tenth of a second
				-- apart is faster than anyone picks a faction. The last of a
				-- burst still gets one, a moment late - a pick inside the tenth
				-- was left in the game's layout (Josh 2026-09-23, audit).
				local now = (type(GetTime) == "function" and GetTime()) or 0
				if now - (M.laidAt or 0) > 0.1 then
					M.laidAt = now
					M.Layout()
				elseif not M.layLate and C_Timer and C_Timer.After then
					M.layLate = true
					C_Timer.After(0.1, function()
						M.layLate = false
						if M.Themed() then
							M.laidAt = (type(GetTime) == "function" and GetTime()) or 0
							M.Layout()
						end
					end)
				end
			end)
		end
		local okC, kids = pcall(function() return { f:GetChildren() } end)
		for _, kid in ipairs(okC and kids or {}) do
			hookLists(kid, depth + 1)
		end
	end
	hookLists(frame, 0)
	-- the side tabs and the stats/titles/sets buttons light as they are chosen
	local tabs = pick(frame, "CharacterFrameModeTabs")
	for i = 1, 8 do
		local tab = pick(tabs, "CharacterFrameModeTab" .. i)
		local sel = tab and tab.SelectedTexture
		if sel and type(hooksecurefunc) == "function" then
			-- the game choosing a tab, not stayDown holding its art down: that
			-- is part of a layout, and answering it with another was a layout
			-- every frame for as long as the sheet was open
			local function lit()
				if not holding then
					again()
				end
			end
			pcall(hooksecurefunc, sel, "Show", lit)
			pcall(hooksecurefunc, sel, "Hide", lit)
			pcall(hooksecurefunc, sel, "SetShown", lit)
		end
	end
	for i = 1, 3 do
		local tab = _G["PaperDollSidebarTab" .. i]
		if tab and tab.HookScript then
			tab:HookScript("OnClick", again)
		end
	end
end
M.WatchTheme = watchTheme

-- ---------------------------------------------------------------------------
-- What the client actually built
-- ---------------------------------------------------------------------------
--
-- STOP GUESSING WHAT THEY ARE CALLED (Josh 2026-09-22, the lesson of the
-- minimap). The reskin touches every tab of this window, and the frames on
-- this build are named by whoever built this build. So before any of it is
-- written, the window is written down: every frame and every region in it,
-- by name or by the key it hangs off, with its size, whether it is showing,
-- and what it draws - an atlas, a texture file, or words. It goes into the
-- saved file, so it can be read off the disk after a /reload rather than
-- copied out of chat.

local ROOTS = {
	"CharacterFrame", "PaperDollFrame", "ReputationFrame", "SkillFrame",
	"HonorFrame", "PVPFrame", "TokenFrame", "CharacterStatsPane",
	"PaperDollItemsFrame", "EquipmentFlyoutFrame", "GearManagerDialogPopup",
}

local function describe(r)
	local bits = {}
	local okT, kind = pcall(r.GetObjectType, r)
	bits[#bits + 1] = okT and kind or "?"
	local okS, w, h = pcall(function() return r:GetWidth(), r:GetHeight() end)
	if okS and w then
		bits[#bits + 1] = ("%.0fx%.0f"):format(w or 0, h or 0)
	end
	local okV, shown = pcall(r.IsShown, r)
	bits[#bits + 1] = (okV and shown) and "shown" or "hidden"
	-- WHERE, AND WHETHER IT IS ACTUALLY DRAWN (Josh 2026-09-22): shown is only
	-- the frame's own flag; visible is whether anything above it is hiding it,
	-- and the first anchor and the level say where it went and what covers it
	local okVis, visible = pcall(r.IsVisible, r)
	if okVis and shown and not visible then
		bits[#bits + 1] = "not-visible"
	end
	local okA, alpha = pcall(r.GetAlpha, r)
	if okA and type(alpha) == "number" and alpha < 1 then
		bits[#bits + 1] = ("alpha=%.2f"):format(alpha)
	end
	local okP, point, rel, relPoint, x, y = pcall(r.GetPoint, r, 1)
	if okP and point then
		local relName = "?"
		if type(rel) == "table" then
			local okN, n = pcall(rel.GetName, rel)
			relName = (okN and n) or tostring(rel.GetObjectType and select(2, pcall(rel.GetObjectType, rel)) or "frame")
		end
		bits[#bits + 1] = ("at=%s:%s:%s:%.0f,%.0f"):format(point, relName, tostring(relPoint), x or 0, y or 0)
	end
	local okL, level = pcall(r.GetFrameLevel, r)
	if okL and level then
		bits[#bits + 1] = "lvl=" .. level
	end
	if kind == "Texture" or kind == "MaskTexture" then
		local okA, atlas = pcall(r.GetAtlas, r)
		if okA and atlas then
			bits[#bits + 1] = "atlas=" .. tostring(atlas)
		else
			local okF, file = pcall(r.GetTexture, r)
			if okF and file then
				bits[#bits + 1] = "tex=" .. tostring(file)
			end
		end
		local okL, layer, sub = pcall(r.GetDrawLayer, r)
		if okL and layer then
			bits[#bits + 1] = layer .. (sub and ("/" .. sub) or "")
		end
	elseif kind == "FontString" then
		local okX, text = pcall(r.GetText, r)
		if okX and text and text ~= "" then
			bits[#bits + 1] = "text=" .. (tostring(text):gsub("\n", " ")):sub(1, 60)
		end
	end
	return table.concat(bits, " ")
end

-- the key a child hangs off its parent by, when it has no name
local function keyOf(parent, child)
	if type(parent) ~= "table" then
		return nil
	end
	for k, v in pairs(parent) do
		if v == child and type(k) == "string" then
			return k
		end
	end
	return nil
end

function M.Dump()
	local lines, seen = {}, {}
	local LIMIT = 6000
	local function add(line)
		if #lines < LIMIT then
			lines[#lines + 1] = line
		end
	end
	-- how the stat sections are told apart (see M.SectionAt)
	add(("stat headers: shape=%s line=%s order=%s"):format(tostring(M.headerShape), tostring(M.lineShape),
		table.concat(M.headerOrder, " / ")))
	local function walk(f, path, depth)
		if seen[f] or depth > 8 or #lines >= LIMIT then
			return
		end
		seen[f] = true
		add(path .. " | " .. describe(f))
		local okR, regions = pcall(function() return { f:GetRegions() } end)
		for i, r in ipairs(okR and regions or {}) do
			local okN, name = pcall(r.GetName, r)
			local label = (okN and name) or keyOf(f, r) or ("#r" .. i)
			add(path .. "." .. label .. " | " .. describe(r))
		end
		local okC, kids = pcall(function() return { f:GetChildren() } end)
		for i, kid in ipairs(okC and kids or {}) do
			local okN, name = pcall(kid.GetName, kid)
			local label = (okN and name) or keyOf(f, kid) or ("#c" .. i)
			walk(kid, path .. "." .. label, depth + 1)
		end
	end
	for _, name in ipairs(ROOTS) do
		local f = _G[name]
		if type(f) == "table" and f.GetRegions then
			walk(f, name, 0)
		end
	end
	-- the tabs, wherever they hang
	for i = 1, 12 do
		local tab = _G["CharacterFrameTab" .. i]
		if type(tab) == "table" and tab.GetRegions then
			walk(tab, "CharacterFrameTab" .. i, 0)
		end
	end
	BT.EnsureBound()
	BeebModDB.charsheetDump = {
		at = U.Now and U.Now() or 0,
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	return #lines
end

BT.Record("charsheetDump", M.Dump, "charsheet")
