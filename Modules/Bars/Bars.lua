-- Action bars, in the same clothes as everything else (Josh 2026-09-20).
--
-- The toolkit's window, dock and tooltips are all one surface: a near-black
-- fill, a hairline rim, flat squares. The action bars are the one thing left
-- on screen still wearing the client's gilt-edged art, and they are the
-- biggest block of interface a player looks at.
--
-- WHAT THIS DOES AND DOES NOT TOUCH. An action button is a SECURE frame: the
-- client owns where it is, how big it is, and what happens when you press it,
-- and an addon that moves or resizes one in combat is an addon that stops
-- working. Nothing here touches position, size, or a single attribute - only
-- textures and fonts, which are not protected and never taint anything.
--
--   the gilt border      hidden; our own fill and rim in its place
--   the icon             cropped, because every icon ships with its own
--                        border baked into the corners of the image
--   pushed / checked     flat colour instead of the client's bevels
--   the hotkey           small, quiet, and in the corner
--   the macro name       off by default: you know what your own buttons do
--
-- It is a module like any other, so it can be switched off and the client's
-- art comes straight back.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Bars/Bars.lua")

local U = BT.Util

local M = BT.Module({
	key = "bars",
	group = "windows",
	title = "Action bars",
	blurb = "flat, like the rest",
	order = 50,
})

-- ---------------------------------------------------------------------------
-- What counts as an action button
-- ---------------------------------------------------------------------------

-- The client builds these by name, and which of them exist depends on the
-- build and on what the player has switched on. Any that are not there are
-- simply skipped - asking is cheaper than keeping a list per client version.
local BAR_NAMES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
	"PetActionButton",
	"StanceButton",
	"ShapeshiftButton",
	"PossessButton",
	"OverrideActionBarButton",
}
local PER_BAR = 12

-- ICONS COME WITH THEIR OWN BORDER (Josh 2026-09-20). Every spell icon in the
-- game is drawn with a dark bevelled frame around the edge of the image, on
-- the assumption that the button's own art will cover it. Ours does not, so
-- the outer twelfth is trimmed off and what is left is the picture.
local CROP = 0.08

local FILL = BT.Widgets.FILL
local RIM = BT.Widgets.RIM
local ACCENT = BT.Widgets.ACCENT

local styled = setmetatable({}, { __mode = "k" })

-- the tests look at what a button is wearing
function M.Skins()
	return styled
end

local function opt(name, fallback)
	local s = BT.settings and BT.settings.bars
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.bars = BT.settings.bars or {}
	BT.settings.bars[name] = value
	M.StyleAll()
end
M.SetOpt = setOpt

-- ---------------------------------------------------------------------------
-- One button
-- ---------------------------------------------------------------------------

-- The client keeps these in half a dozen places depending on the build: on the
-- button, under a global of its own name, or behind a getter. Ask every way we
-- know and take the first answer.
local function piece(button, key, suffix)
	if button[key] then
		return button[key]
	end
	local name = button.GetName and button:GetName()
	if name and suffix then
		return _G[name .. suffix]
	end
	return nil
end

local function skin(button)
	local s = styled[button]
	if s then
		return s
	end
	if not (button and button.CreateTexture) then
		return nil
	end
	-- A RIM IS A RING, NOT A RECTANGLE UNDER THE FILL (Josh 2026-09-21). The
	-- fill is translucent, so a rim drawn full-size underneath it bled twelve
	-- percent of the border colour through the whole surface - set the border
	-- red and the background went red. See UI/Pill.lua.
	-- BACKGROUND, so it sits under the icon the client puts at BORDER
	s = BT.Pill.Surface(button, "BACKGROUND", -8)
	styled[button] = s
	return s
end

-- What a texture of the client's showed, so it can show it again: an atlas
-- or a file, and the part of the file it was showing.
local function snapshot(t)
	local snap = {}
	if t.GetAtlas then
		local ok, atlas = pcall(t.GetAtlas, t)
		snap.atlas = (ok and type(atlas) == "string" and atlas ~= "") and atlas or nil
	end
	if t.GetTexture then
		local ok, file = pcall(t.GetTexture, t)
		if ok and (type(file) == "string" or type(file) == "number") then
			snap.file = file
		end
	end
	if t.GetTexCoord then
		local ok, a, b, c, d, e, f, g, h = pcall(t.GetTexCoord, t)
		if ok and type(a) == "number" then
			snap.coords = { a, b, c, d, e, f, g, h }
		end
	end
	return snap
end

local function restoreTex(t, snap)
	if not (t and snap) then
		return
	end
	if snap.atlas and t.SetAtlas then
		pcall(t.SetAtlas, t, snap.atlas)
	elseif snap.file and t.SetTexture then
		pcall(t.SetTexture, t, snap.file)
		if snap.coords and t.SetTexCoord then
			pcall(t.SetTexCoord, t, unpack(snap.coords))
		end
	end
end
M.SnapshotTexture, M.RestoreTexture = snapshot, restoreTex

-- Everything the client draws round the outside. Hidden rather than removed:
-- switching the module off has to give every one of them back.
local ART = {
	{ "NormalTexture", "NormalTexture" },
	{ "SlotBackground", nil },
	{ "SlotArt", nil },
	{ "IconMask", nil },
	{ "Border", "Border" },
	{ "FloatingBG", "FloatingBG" },
}

local function hideArt(button, hide)
	for _, pair in ipairs(ART) do
		local art = piece(button, pair[1], pair[2])
		if art and art.SetAlpha then
			-- alpha rather than Hide: the client shows some of these itself on
			-- every update, and a hidden texture it shows again is visible,
			-- while a transparent one it shows again is still transparent
			art:SetAlpha(hide and 0 or 1)
		end
	end
	-- the one that is a method rather than a region on some builds: what it
	-- was is remembered the first time, and put back on `plain`
	if button.SetNormalTexture then
		if hide then
			if button.beebsNormal == nil then
				local ok, snap = pcall(function()
					local t = button.GetNormalTexture and button:GetNormalTexture()
					return t and snapshot(t) or false
				end)
				button.beebsNormal = ok and snap or false
			end
			pcall(button.SetNormalTexture, button, nil)
		elseif button.beebsNormal then
			local snap = button.beebsNormal
			if snap.atlas then
				pcall(function() button:GetNormalTexture():SetAtlas(snap.atlas) end)
			elseif snap.file then
				pcall(button.SetNormalTexture, button, snap.file)
				pcall(function() restoreTex(button:GetNormalTexture(), snap) end)
			end
			button.beebsNormal = nil
		end
	end
end

local function styleText(button, hide)
	local name = button.GetName and button:GetName()
	local hotkey = piece(button, "HotKey", "HotKey")
	if hotkey then
		-- `hide` here means "put the client's look back": its hotkeys show
		hotkey:SetAlpha((hide or opt("hotkeys", true)) and 1 or 0)
		if not hide and hotkey.SetTextColor then
			hotkey:SetTextColor(0.55, 0.63, 0.59)
		end
	end
	local macro = piece(button, "Name", "Name")
	if macro then
		-- off by default: you know what your own buttons do, and the name
		-- covers the bottom third of the icon saying so
		macro:SetAlpha((not hide) and opt("macroNames", false) and 1 or (hide and 1 or 0))
	end
	local count = piece(button, "Count", "Count")
	if count and count.SetTextColor and not hide then
		count:SetTextColor(0.87, 0.92, 0.89)
	end
	if name then
		local border = _G[name .. "FloatingBG"]
		if border and border.SetAlpha then
			border:SetAlpha(hide and 1 or 0)
		end
	end
end

-- Flat states instead of the client's bevels: one colour for "pressed", the
-- toolkit's green for "this one is on".
--
-- AND BACK AGAIN (Josh 2026-09-22). The highlight, pushed and checked
-- textures were replaced with flat colour and never put back, so with the
-- module off a pressed button or an active stance stayed a flat block until
-- /reload. What each was is written down the first time it is touched.
local STATES = {
	{ "Highlight", { 1, 1, 1, 0.12 } },
	{ "Pushed", { 0, 0, 0, 0.35 } },
	{ "Checked", nil }, -- the accent, read when it is painted
}

local function styleStates(button, plain)
	local was = button.beebsStates
	if plain then
		if was then
			for _, st in ipairs(STATES) do
				local snap = was[st[1]]
				local get, set = button["Get" .. st[1] .. "Texture"], button["Set" .. st[1] .. "Texture"]
				if snap and set then
					if snap.atlas then
						pcall(function() get(button):SetAtlas(snap.atlas) end)
					else
						pcall(set, button, snap.file)
						pcall(function() restoreTex(get(button), snap) end)
					end
				end
			end
			button.beebsStates = nil
		end
		return
	end
	if not was then
		was = {}
		for _, st in ipairs(STATES) do
			local get = button["Get" .. st[1] .. "Texture"]
			local ok, snap = pcall(function()
				local t = get and get(button)
				return t and snapshot(t) or nil
			end)
			was[st[1]] = ok and snap or nil
		end
		button.beebsStates = was
	end
	for _, st in ipairs(STATES) do
		local get, set = button["Get" .. st[1] .. "Texture"], button["Set" .. st[1] .. "Texture"]
		if set then
			pcall(set, button, "Interface\\Buttons\\WHITE8X8")
			local t = get and get(button)
			if t and t.SetColorTexture then
				local c = st[2] or { ACCENT[1], ACCENT[2], ACCENT[3], 0.30 }
				t:SetColorTexture(c[1], c[2], c[3], c[4])
				t:SetAllPoints()
			end
		end
	end
end

-- `plain` puts the client's own look back rather than applying ours.
function M.StyleButton(button, plain)
	if not (button and button.GetName) then
		return false
	end
	local icon = piece(button, "icon", "Icon") or piece(button, "Icon", "Icon")
	hideArt(button, not plain)
	styleText(button, plain)
	styleStates(button, plain)

	local s = skin(button)
	if s then
		BT.Pill.PaintSurface(s, button, FILL, RIM)
		BT.Pill.ShowSurface(s, not plain)
	end

	if icon and icon.SetTexCoord then
		if plain then
			icon:SetTexCoord(0, 1, 0, 1)
		else
			icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		end
		if icon.ClearAllPoints and icon.SetPoint then
			icon:ClearAllPoints()
			if plain then
				icon:SetAllPoints()
			else
				-- inside the rim, so the hairline reads all the way round
				icon:SetPoint("TOPLEFT", 1, -1)
				icon:SetPoint("BOTTOMRIGHT", -1, 1)
			end
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- All of them
-- ---------------------------------------------------------------------------

function M.Buttons()
	local out = {}
	for _, base in ipairs(BAR_NAMES) do
		for i = 1, PER_BAR do
			local button = _G[base .. i]
			if button then
				out[#out + 1] = button
			end
		end
	end
	return out
end

-- Returns how many it dressed, which is what the settings tab reports and what
-- the tests count.
function M.StyleAll(plain)
	local n = 0
	for _, button in ipairs(M.Buttons()) do
		if M.StyleButton(button, plain) then
			n = n + 1
		end
	end
	M.lastCount = n
	return n
end

-- IN COMBAT, NOTHING (Josh 2026-09-20). None of this is protected, but the
-- client rebuilds buttons as you fight - a spell going on cooldown, a stance
-- changing the whole bar - and re-dressing thirty-six buttons in the middle of
-- that is work nobody asked for. It waits for the fight to end.
local pending = false

local function restyle()
	if not BT.Enabled("bars") then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	M.StyleAll()
end
M.Restyle = restyle

function M.Watch()
	if M.events then
		return M.events
	end
	M.events = CreateFrame("Frame")
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD", "ACTIONBAR_PAGE_CHANGED", "ACTIONBAR_SLOT_CHANGED",
		"UPDATE_BINDINGS", "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE",
		"PLAYER_REGEN_ENABLED",
	}) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	-- ONCE A FRAME (Josh 2026-09-23, audit): a slot changes one event at a
	-- time, and a talent swap or a page filled by hand is dozens of them in a
	-- row - each one restyled every button of every bar
	local queued = false
	M.events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and not pending then
			return
		end
		if queued then
			return
		end
		if C_Timer and C_Timer.After then
			queued = true
			C_Timer.After(0, function()
				queued = false
				restyle()
			end)
		else
			restyle()
		end
	end)
	return M.events
end

function M:OnEnable()
	M.Watch()
	restyle()
end

-- AND AT LOGIN, NOT ONLY WHEN SWITCHED ON (Josh 2026-09-20). OnEnable fires
-- when a module goes from off to on, which never happens to one that was
-- already on - so the bars kept the client's art until something opened the
-- tab. OnBind is the login hook: it runs for every live module once the book
-- is bound.
M.OnBind = M.OnEnable

function M:OnDisable()
	-- the client's own art, straight back
	M.StyleAll(true)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the client's art off, the toolkit's surface on · nothing is moved or resized")

	self.rows = {}
	local each = page:Section("On each button")
	local function row(title, blurb, name, default)
		local r = BT.Widgets.SwitchRow(each, title, blurb,
			function() return opt(name, default) and true or false end,
			function(on) setOpt(name, on) end)
		r.optName, r.default = name, default
		self.rows[#self.rows + 1] = r
	end
	row("Hotkeys", "the binding in the corner", "hotkeys", true)
	row("Macro names", "the label across the bottom", "macroNames", false)
	page:Layout()

	self.found = BT.Widgets.Label(panel, "", "small", 0.45, 0.50, 0.48)
	self.found:SetPoint("BOTTOMLEFT", 2, 4)
end

function M:RefreshTab()
	for _, r in ipairs(self.rows or {}) do
		r.switch:SetOn(opt(r.optName, r.default) and true or false)
	end
	if self.found then
		self.found:SetText(("%d buttons dressed"):format(M.lastCount or 0))
	end
end

function M:ShowTab()
	restyle()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

BT.Command("bars", function()
	local n = M.StyleAll()
	U.Print(("%d buttons · hotkeys %s · macro names %s"):format(n,
		opt("hotkeys", true) and "on" or "off",
		opt("macroNames", false) and "on" or "off"))
end, "restyle the action bars now", "bars")
