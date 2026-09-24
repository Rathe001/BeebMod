-- The game menu - the one Escape opens - in the toolkit's clothes (Josh 2026-09-23).
--
-- "Are we able to style the main game menu, or is that off limits?" It is not
-- off limits: the menu is a plain frame of the client's, not a protected one,
-- so its look is ours to change. What is not ours is what its buttons DO -
-- Log Out and Exit Game must run the client's own code - so a button keeps
-- its scripts untouched and only its pictures and words are changed.
--
-- The window: the client's border, background and gold title plaque off, the
-- toolkit's surface on, the title in the toolkit's face at the top. A button:
-- the client's red pictures off (normal, pushed, lit and greyed), a raised
-- surface of ours on with its hairline rim, the words in the toolkit's face,
-- and a wash of the accent while the pointer is over it.
--
-- THE CLIENT MAKES ITS BUTTONS AFRESH (the modern menu takes them from a pool
-- each time it opens, and lays them out again), so the dressing is done every
-- time it is shown - and once more a frame later, after the client's own
-- layout - and it is done to whatever buttons are there, however they are
-- named. Everything changed is remembered, and put back when this is off.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menu/Menu.lua")

local U = BT.Util

local M = BT.Module({
	key = "menu",
	group = "windows",
	onPage = "allmenus",
	title = "Game menu",
	blurb = "the Escape menu, in the toolkit's clothes",
	order = 59,
})

-- what was changed, to put back: [object] = { alpha = n } or { font = {...}, colour = {...} }
local was = setmetatable({}, { __mode = "k" })
M.was = was

local function call(obj, method, ...)
	return BT.Furniture.Call(obj, method, ...)
end

local function objectType(obj)
	return call(obj, "GetObjectType")
end

-- a texture of the client's, out of sight - remembered, to come back
local function off(tex)
	if type(tex) ~= "table" or tex.beebs then
		return
	end
	if not was[tex] then
		was[tex] = { alpha = call(tex, "GetAlpha") or 1 }
	end
	call(tex, "SetAlpha", 0)
end

-- a font string of the client's, in the toolkit's face - remembered
local function refont(fs, size, colour)
	if type(fs) ~= "table" or not fs.SetFont then
		return
	end
	if not was[fs] then
		local face, sz, flags = call(fs, "GetFont")
		local r, g, b, a = call(fs, "GetTextColor")
		was[fs] = { font = { face, sz, flags }, colour = { r, g, b, a } }
	end
	call(fs, "SetFont", BT.Fonts.Face("name") or _G.STANDARD_TEXT_FONT, BT.Fonts.Size(size), "")
	call(fs, "SetShadowColor", 0, 0, 0, 1)
	call(fs, "SetShadowOffset", 1, -1)
	if colour then
		call(fs, "SetTextColor", colour[1], colour[2], colour[3], 1)
	end
end

-- A SCROLL BAR (Josh 2026-09-23: "still seeing the right line"). The menu's
-- buttons are a scrolling list on this client, and the thin line down the
-- right was its bar - a track, a thumb and two arrows, some of them buttons,
-- which is why it was neither hidden with the chrome nor fit to dress. The
-- whole bar is put out of sight (it has nothing to scroll: every button fits).
local function isScrollBar(f)
	return type(f) == "table" and (type(f.Track) == "table" or type(f.Thumb) == "table"
		or type(f.GetThumb) == "function" or objectType(f) == "Slider")
end
M.IsScrollBar = isScrollBar

-- EVERY TEXTURE OF THE WINDOW'S OWN, AT EVERY DEPTH (Josh 2026-09-23: a
-- line of the client's border was left standing down the right-hand side).
-- The border is pieces inside pieces; all of it is walked, except the buttons
-- (dressed on their own) and the surfaces that are ours.
local function chromeOff(frame, depth)
	depth = depth or 0
	if depth > 4 then
		return
	end
	for _, r in ipairs({ call(frame, "GetRegions") }) do
		if objectType(r) == "Texture" then
			off(r)
		end
	end
	for _, child in ipairs({ call(frame, "GetChildren") }) do
		if type(child) == "table" and not child.beebs then
			if isScrollBar(child) then
				off(child)
			elseif objectType(child) ~= "Button" then
				chromeOff(child, depth + 1)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- A button
-- ---------------------------------------------------------------------------

M.TEXT = { 0.90, 0.91, 0.88 }
-- every button dressed, wherever it was found (a list, a pool), so switching
-- off reaches them all (Josh 2026-09-23, audit: only the window's own
-- children were undressed, and the rest kept our surface)
M.buttons = setmetatable({}, { __mode = "k" })
M.DIM = { 0.50, 0.53, 0.50 }

function M.DressButton(b)
	if type(b) ~= "table" or objectType(b) ~= "Button" then
		return false
	end
	-- the client's pictures, every state of them
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
		off(call(b, getter))
	end
	for _, key in ipairs({ "Left", "Middle", "Right", "Center" }) do
		if type(b[key]) == "table" and objectType(b[key]) == "Texture" then
			off(b[key])
		end
	end
	for _, r in ipairs({ call(b, "GetRegions") }) do
		if objectType(r) == "Texture" then
			off(r)
		end
	end
	-- ours: a raised surface with its rim, and the accent's wash on hover
	if not b.beebsSurface then
		local s = CreateFrame("Frame", nil, b)
		s.beebs = true
		s:SetAllPoints(b)
		s:SetFrameLevel(math.max(0, (call(b, "GetFrameLevel") or 1) - 1))
		BT.Widgets.Panel(s, BT.Widgets.RAISED, BT.Widgets.RIM)
		s.wash = s:CreateTexture(nil, "ARTWORK")
		s.wash.beebs = true
		s.wash:SetPoint("TOPLEFT", 1, -1)
		s.wash:SetPoint("BOTTOMRIGHT", -1, 1)
		s.wash:Hide()
		b.beebsSurface = s
		-- LIT BY WHERE THE POINTER IS, ASKED BY US (Josh 2026-09-23: "we lose
		-- the hover effect on buttons if I close and reopen it"). It was
		-- hooked onto the button's OnEnter, and the menu sets its buttons'
		-- scripts afresh each time it opens, which drops any hook. The surface
		-- is ours, so it asks each frame whether the pointer is over its
		-- button - only while the menu is open, since it is hidden with it.
		s.owner = b
		s:SetScript("OnUpdate", function(self)
			local over = M.live and call(self.owner, "IsMouseOver") and true or false
			if over ~= self.lit then
				self.lit = over
				if over then
					local a = BT.Widgets.ACCENT
					self.wash:SetColorTexture(a[1], a[2], a[3], 0.18)
				end
				self.wash:SetShown(over)
			end
		end)
	end
	b.beebsSurface:Show()
	M.buttons[b] = true
	local enabled = call(b, "IsEnabled")
	refont(call(b, "GetFontString"), 13, enabled == false and M.DIM or M.TEXT)
	return true
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

function M.Frame()
	return _G.GameMenuFrame
end

-- the menu's title: the client's header text, wherever it keeps it
local function titleOf(frame)
	local header = frame.Header
	if type(header) == "table" then
		if type(header.Text) == "table" then
			return header.Text, header
		end
		for _, r in ipairs({ call(header, "GetRegions") }) do
			if objectType(r) == "FontString" then
				return r, header
			end
		end
	end
	for _, r in ipairs({ call(frame, "GetRegions") }) do
		if objectType(r) == "FontString" then
			return r, nil
		end
	end
	return nil, header
end

function M.Dress()
	local frame = M.Frame()
	if not (M.live and type(frame) == "table") or M.dressing then
		return 0
	end
	-- never inside itself: dressing can set the client laying out again
	M.dressing = true
	local ok, n = pcall(M.DressNow, frame)
	M.dressing = false
	return ok and n or 0
end

function M.DressNow(frame)
	M.HookLists(frame)
	chromeOff(frame)
	local title, header = titleOf(frame)
	if header then
		chromeOff(header)
	end
	if not frame.beebsSurface then
		local s = CreateFrame("Frame", nil, frame)
		s.beebs = true
		s:SetAllPoints(frame)
		s:SetFrameLevel(math.max(0, (call(frame, "GetFrameLevel") or 1) - 1))
		BT.Widgets.Panel(s, BT.Widgets.SOLID, BT.Widgets.RIM)
		-- THE ELITE'S BORDER (Josh 2026-09-23: "can we dress it up similar to
		-- our elite unit frame?"): the gold corners, the double line and the
		-- crest on the top edge, outside the window as they are outside a
		-- frame (UI/Ornament.lua)
		if BT.Ornament then
			s.ornament = BT.Ornament.Build(s, 4)
		end
		frame.beebsSurface = s
	end
	frame.beebsSurface:Show()
	-- IN THE THEME'S BORDER COLOUR (Josh 2026-09-23: "rather than gold border,
	-- could we use the theme border color?") - read each time it opens, so it
	-- follows the colour when that changes
	if frame.beebsSurface.ornament then
		BT.Ornament.Paint(frame.beebsSurface.ornament, "elite", BT.Widgets.RIM)
	end
	if title then
		refont(title, 14, BT.Widgets.ACCENT)
		-- INSIDE THE WINDOW (Josh 2026-09-23): the client's title hangs on a
		-- plaque above the top edge; with the plaque gone the words sat on the
		-- border. Where it was is remembered, to put back.
		local w = was[title]
		if w and not w.points then
			w.points = {}
			for i = 1, (call(title, "GetNumPoints") or 0) do
				w.points[i] = { call(title, "GetPoint", i) }
			end
		end
		call(title, "ClearAllPoints")
		call(title, "SetPoint", "TOP", frame, "TOP", 0, -12)
	end
	-- above anything of ours that sits high in the middle of the screen (the
	-- resource display drew over it)
	if not was[frame] then
		was[frame] = { strata = call(frame, "GetFrameStrata") }
	end
	call(frame, "SetFrameStrata", "FULLSCREEN_DIALOG")
	-- ONE BUTTON AT A TIME, EACH ON ITS OWN (Josh 2026-09-23: three were
	-- dressed and the rest left red). One that fails is said, once, and the
	-- rest are still done.
	-- AT ANY DEPTH (Josh 2026-09-23: the same five stayed red, in the game's
	-- own face - never reached). Not every button is the window's own child;
	-- every button in it is found, however deep.
	local n = 0
	local function walk(f, depth)
		if depth > 4 then
			return
		end
		for _, child in ipairs({ call(f, "GetChildren") }) do
			if type(child) == "table" and not child.beebs and not isScrollBar(child) then
				if objectType(child) == "Button" then
					local ok, dressed = pcall(M.DressButton, child)
					if ok and dressed then
						n = n + 1
					elseif not ok and not M.failed then
						M.failed = tostring(dressed)
						U.Print("the game menu: a button could not be dressed - " .. M.failed)
					end
				else
					walk(child, depth + 1)
				end
			end
		end
	end
	walk(frame, 0)
	-- NOT EVERY BUTTON IS LISTED (Josh 2026-09-23, the menu dump): asked for
	-- its children, the menu names only Options, AddOns and Edit Mode - the
	-- rest are kept off the list. They may still be reached by name, through
	-- the pools the menu makes them from.
	for key, pool in pairs(frame) do
		if type(key) == "string" and key:lower():find("pool") and type(pool) == "table" then
			local okE, iter, state, first = pcall(function() return pool:EnumerateActive() end)
			if okE and type(iter) == "function" then
				for b in iter, state, first do
					if type(b) == "table" and not b.beebsSurface then
						local ok, dressed = pcall(M.DressButton, b)
						if ok and dressed then
							n = n + 1
						end
					elseif type(b) == "table" then
						pcall(M.DressButton, b)
					end
				end
			end
		end
	end
	-- and the border's edges by name: the right one is off the list as well
	for _, holder in ipairs({ frame.Border, frame.NineSlice }) do
		if type(holder) == "table" then
			for _, key in ipairs({ "RightEdge", "LeftEdge", "TopEdge", "BottomEdge", "Center",
				"TopRightCorner", "TopLeftCorner", "BottomRightCorner", "BottomLeftCorner" }) do
				if type(holder[key]) == "table" then
					off(holder[key])
				end
			end
		end
	end
	M.lastCount = n
	return n
end

-- everything back as the client had it
function M.Undress()
	for obj, w in pairs(was) do
		if w.alpha ~= nil then
			call(obj, "SetAlpha", w.alpha)
		end
		if w.font and w.font[1] then
			call(obj, "SetFont", w.font[1], w.font[2], w.font[3])
		end
		if w.colour and w.colour[1] then
			call(obj, "SetTextColor", w.colour[1], w.colour[2], w.colour[3], w.colour[4] or 1)
		end
		if w.strata then
			call(obj, "SetFrameStrata", w.strata)
		end
		if w.points and #w.points > 0 then
			call(obj, "ClearAllPoints")
			for _, pt in ipairs(w.points) do
				call(obj, "SetPoint", pt[1], pt[2], pt[3], pt[4], pt[5])
			end
		end
		was[obj] = nil
	end
	local frame = M.Frame()
	if type(frame) == "table" then
		if frame.beebsSurface then
			if frame.beebsSurface.ornament then
				BT.Ornament.Paint(frame.beebsSurface.ornament, nil)
			end
			frame.beebsSurface:Hide()
		end
		for b in pairs(M.buttons) do
			if b.beebsSurface then
				b.beebsSurface:Hide()
			end
		end
	end
end

-- THE LIST MAKES AND REUSES ITS ROWS (Josh 2026-09-23: "they also changed if
-- I close and reopen the menu"). A scrolling list hands out its buttons as it
-- lays itself out, to whichever row wants one, and a row made after the menu
-- was dressed kept the game's red. So every list in the menu is watched, and
-- dressed again each time it lays itself out.
function M.HookLists(f, depth)
	depth = depth or 0
	if type(f) ~= "table" or depth > 6 or not hooksecurefunc then
		return
	end
	if f.ScrollTarget and type(f.Update) == "function" and not f.beebsHooked then
		f.beebsHooked = true
		pcall(hooksecurefunc, f, "Update", function()
			if M.live then
				M.Dress()
			end
		end)
	end
	for _, kid in ipairs({ call(f, "GetChildren") }) do
		M.HookLists(kid, depth + 1)
	end
end

-- dressed each time it opens, and once more after the client's own layout
function M.Watch()
	local frame = M.Frame()
	if M.watching or type(frame) ~= "table" or not frame.HookScript then
		return false
	end
	M.watching = true
	-- and after the menu's own making and laying out of its buttons, where it
	-- has those
	if hooksecurefunc then
		for _, method in ipairs({ "InitButtons", "Layout" }) do
			if type(frame[method]) == "function" then
				pcall(hooksecurefunc, frame, method, function()
					if M.live then
						M.Dress()
					end
				end)
			end
		end
	end
	frame:HookScript("OnShow", function()
		if not M.live then
			return
		end
		M.Dress()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if M.live then
					M.Dress()
				end
			end)
		end
	end)
	return true
end

function M:OnEnable()
	M.live = true
	M.Watch()
	local frame = M.Frame()
	if type(frame) == "table" and call(frame, "IsShown") then
		M.Dress()
	end
end

function M:OnBind()
	if BT.Enabled("menu") then
		M:OnEnable()
	end
end

function M:OnDisable()
	M.live = false
	M.Undress()
end

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the menu Escape opens, in an elite's border drawn in your border colour · "
		.. "buttons in the toolkit's font, lit with the accent under the pointer")
	page:Note("only the look changes · every button does what the game's did · the game keeps some of its "
		.. "buttons from addons, so those stay its own · switched off, the game's art is back", true)
	page:Layout()
end

-- /bt menudump: what the game menu is made of, for when this client lays it
-- out differently from the one this was written against
BT.Command("menudump", function()
	local frame = M.Frame()
	if type(frame) ~= "table" then
		U.Print("no GameMenuFrame on this client")
		return
	end
	local lines = {}
	local function describe(obj, path, depth)
		if depth > 3 or type(obj) ~= "table" then
			return
		end
		local kind = objectType(obj) or "?"
		local text = kind == "FontString" and call(obj, "GetText") or nil
		local atlas = kind == "Texture" and call(obj, "GetAtlas") or nil
		-- a frame the game keeps from addons answers nothing but this
		local forbidden = call(obj, "IsForbidden")
		local protected = call(obj, "IsProtected")
		local label = kind == "Button" and call(call(obj, "GetFontString"), "GetText") or nil
		lines[#lines + 1] = ("%s | %s %s%s%s%s%s%s"):format(path, kind, call(obj, "IsShown") and "shown" or "hidden",
			text and (" text=" .. tostring(text)) or "", atlas and (" atlas=" .. tostring(atlas)) or "",
			label and (" label=" .. tostring(label)) or "", forbidden and " FORBIDDEN" or "",
			protected and " protected" or "")
		for i, r in ipairs({ call(obj, "GetRegions") }) do
			describe(r, path .. ".#r" .. i, depth + 1)
		end
		for i, c in ipairs({ call(obj, "GetChildren") }) do
			describe(c, path .. ".#c" .. i, depth + 1)
		end
	end
	describe(frame, "GameMenuFrame", 0)
	-- what the menu keeps by name, which is how a button off its list is found
	local keys = {}
	for k, v in pairs(frame) do
		if type(k) == "string" then
			keys[#keys + 1] = k .. "=" .. type(v)
		end
	end
	table.sort(keys)
	lines[#lines + 1] = "keys: " .. table.concat(keys, " ")
	if type(frame.Border) == "table" then
		local bk = {}
		for k, v in pairs(frame.Border) do
			if type(k) == "string" then
				bk[#bk + 1] = k .. "=" .. type(v)
			end
		end
		table.sort(bk)
		lines[#lines + 1] = "border keys: " .. table.concat(bk, " ")
	end
	lines[#lines + 1] = ("dressed last time: %s buttons · failed: %s"):format(tostring(M.lastCount), tostring(M.failed))
	BT.EnsureBound()
	BeebModDB.menuDump = { at = U.Now(), lines = lines }
	local kept = 0
	for _, line in ipairs(lines) do
		if line:find("FORBIDDEN", 1, true) or line:find(" protected", 1, true) then
			kept = kept + 1
		end
	end
	U.Print(("game menu: %d lines written down · /reload to save them · %s buttons dressed · %d kept from addons%s")
		:format(#lines, tostring(M.lastCount), kept, M.failed and (" · failed: " .. M.failed) or ""))
end, "menudump - write the game menu's frames into the saved file", "menu")
