-- The micro menu, in the toolkit's clothes (Josh 2026-09-21).
--
-- The row of small buttons along the bottom - character, spellbook, talents,
-- the quest log, the guild, the group finder, collections, the journal, the
-- game menu and help. Ten gilt-framed squares, and the last piece of the
-- client's own furniture still wearing its own art.
--
-- SAME BARGAIN AS THE ACTION BARS. Nothing here is reimplemented: every button
-- does exactly what it did, keeps its own click handler and its own tooltip.
-- Only textures change.
--
-- WHAT CANNOT BE DONE, AND WHY. A micro button's art is ONE texture with the
-- icon and its gold frame drawn into the same image - there is no separate
-- icon to keep. So the frame cannot simply be taken off: what is left is to
-- crop the bevel at the edges, sit the result on our own surface, and take the
-- gold down with a tint. It reads as ours; it is not the icon redrawn.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Micro/Micro.lua")

local U = BT.Util

local M = BT.Module({
	key = "micro",
	feature = "dock",
	title = "Micro menu",
	blurb = "Puts the game's menu buttons in the dock",
	order = 55,
	-- IN THE PANEL (Josh 2026-09-22): the row can live in the dock, so the
	-- module has a tab on the rail
	dock = true,
})

local FILL = BT.Widgets.FILL
local RIM = BT.Widgets.RIM

-- the outer edge of a micro button's image is its frame; this much of it is
-- bevel rather than picture
--
-- CROPPING IS ZOOMING (Josh 2026-09-21). The texture still fills the button
-- after the crop, so every pixel taken off the edge magnifies what is left -
-- 20% off each side drew the glyph half again as big, which is what "the
-- buttons became larger" was. The frame is never going to come off this way,
-- so take only the outermost bevel and let the colour do the work.
--
-- THE PLATE WAS HIDING IT (Josh 2026-09-21). At 13% the gold rim was still on
-- every button; it read as one dark mass only because the client's plate sat
-- behind the row. Taking the plate down put those rims against open snow, and
-- the row went gold again. So the crop goes back up - and the face is inset
-- further to pay for the magnification it costs, which is what makes the
-- buttons look bigger.
--
-- SO DERIVE THE INSET, DO NOT PICK ONE (Josh 2026-09-21). Cropping magnifies
-- by 1/(1 - 2*CROP); drawing the result inside the tile shrinks it back by
-- (size - 2*inset)/size. Those cancel exactly when the inset is CROP of the
-- button's own size, and at that point the picture is drawn at the size it
-- always was - the bevel is simply replaced by our surface instead of being
-- blown up. Three flat pixels was a guess, and 28px buttons needed six.
local CROP = 0.22

local skins = setmetatable({}, { __mode = "k" })

local function opt(name, fallback)
	local s = BT.settings and BT.settings.micro
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt


-- the tests look at what a button is wearing
function M.Skins()
	return skins
end

-- ---------------------------------------------------------------------------
-- Which buttons
-- ---------------------------------------------------------------------------

-- The client keeps a list of its own; the names are the fallback for a build
-- that does not, or that adds one we have not heard of.
local NAMES = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
	"QuestLogMicroButton", "SocialsMicroButton", "GuildMicroButton",
	"LFDMicroButton", "CollectionsMicroButton", "EJMicroButton",
	"AchievementMicroButton", "MainMenuMicroButton", "HelpMicroButton",
	"StoreMicroButton", "WorldMapMicroButton",
}

-- THE ROW IS NOT THE CORNER (Josh 2026-09-21). Three rounds of this module got
-- darker and darker and the corner kept looking like the client's, because the
-- micro buttons were never the only loud part: both rows sit on a grey-brown
-- plate of the client's, and the character button wears a full-colour portrait
-- that is a texture of its own and ignores everything done to its faces.
--
-- The bags are dressed by their own module - they are a different object with
-- a different problem, and they belong on their own switch.
local PLATES = {
	"MicroButtonAndBagsBar", "MicroMenuContainer", "MicroMenu",
}

function M.Buttons()
	local out, seen = {}, {}
	local list = _G.MICRO_BUTTONS
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			local b = (type(entry) == "string") and _G[entry] or entry
			if type(b) == "table" and not seen[b] then
				seen[b] = true
				out[#out + 1] = b
			end
		end
	end
	for _, name in ipairs(NAMES) do
		local b = _G[name]
		if b and not seen[b] then
			seen[b] = true
			out[#out + 1] = b
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- One button
-- ---------------------------------------------------------------------------

local function surface(button)
	local s = skins[button]
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
	s = BT.Pill.Surface(button, "BACKGROUND", -8)
	skins[button] = s
	return s
end

-- Every face a button has: the one it wears, the one it wears pressed, the one
-- it wears while the window it opens is up.
local FACES = {
	{ "GetNormalTexture", "SetNormalTexture" },
	{ "GetPushedTexture", "SetPushedTexture" },
	{ "GetDisabledTexture", "SetDisabledTexture" },
}

-- how far in to draw a cropped picture so it comes out its own size again
local function inset(button)
	local w = BT.Pill.Number(button and button.GetWidth and button:GetWidth(), 0)
	local h = BT.Pill.Number(button and button.GetHeight and button:GetHeight(), 0)
	-- a button the client has not sized yet measures zero, which would inset
	-- by nothing and put the zoom straight back
	if w <= 0 then w = 28 end
	if h <= 0 then h = 28 end
	local x = math.max(2, math.floor(w * CROP + 0.5))
	local y = math.max(2, math.floor(h * CROP + 0.5))
	return x, y
end

-- THE PICTURE'S OWN CORNERS, NOT THE FILE'S (Josh 2026-09-24: "many icons
-- disappear when I hover them"). A face can be a region of a sheet of
-- pictures (an atlas), and the client swaps one for another as the pointer
-- arrives. The crop was written as a fraction of the whole FILE - a corner of
-- the sheet, mostly empty - so it is taken from the region the client set
-- instead, remembered per picture, and taken again whenever the picture
-- changes (see M.WatchFaces).
local function pictureOf(tex)
	local okA, atlas = pcall(tex.GetAtlas, tex)
	if okA and type(atlas) == "string" and atlas ~= "" then
		return "atlas:" .. atlas
	end
	local okF, file = pcall(tex.GetTexture, tex)
	return "file:" .. tostring(okF and file or "")
end

local function region(tex)
	local key = pictureOf(tex)
	local r = tex.beebsRegion
	if r and r.key == key then
		return r
	end
	-- a new picture: the corners the client gave it are the whole of it
	local l, rt, t, b = 0, 1, 0, 1
	local ok, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(tex.GetTexCoord, tex)
	if ok and type(ulx) == "number" and type(lry) == "number" then
		l, rt = math.min(ulx, llx), math.max(urx, lrx)
		t, b = math.min(uly, ury), math.max(lly, lry)
	end
	-- OUR CROP IS NOT THE CLIENT'S CORNERS (Josh 2026-09-30, review). A new
	-- atlas brings corners of its own, but a new file keeps whatever was set
	-- last, and that was our crop: read as the new picture's corners, it was
	-- cropped again inside itself, and the picture grew with every change.
	-- Corners still at our crop are the client's last ones.
	local cut = tex.beebsCut
	if r and cut and math.abs(l - cut[1]) < 1e-4 and math.abs(rt - cut[2]) < 1e-4
		and math.abs(t - cut[3]) < 1e-4 and math.abs(b - cut[4]) < 1e-4 then
		l, rt, t, b = r.l, r.r, r.t, r.b
	end
	r = { key = key, l = l, r = rt, t = t, b = b }
	tex.beebsRegion = r
	return r
end
M.Region = region

-- One picture, dressed: cropped to the bevel, drained, tinted, and drawn at
-- its own size inside the tile. Both the button's faces and the character
-- portrait come through here, so the row is one material.
local function dress(tex, plain, button)
	if not tex then
		return
	end
	if plain then
		if tex.SetTexCoord then
			local r = region(tex)
			tex:SetTexCoord(r.l, r.r, r.t, r.b)
			tex.beebsCut = nil
		end
		if tex.SetVertexColor then
			tex:SetVertexColor(1, 1, 1, 1)
		end
		if tex.SetDesaturated then
			pcall(tex.SetDesaturated, tex, false)
		end
		if tex.SetAllPoints then
			tex:SetAllPoints()
		end
		return
	end
	if tex.SetTexCoord then
		local r = region(tex)
		local w, h = r.r - r.l, r.b - r.t
		local cut = { r.l + w * CROP, r.r - w * CROP, r.t + h * CROP, r.b - h * CROP }
		tex:SetTexCoord(cut[1], cut[2], cut[3], cut[4])
		tex.beebsCut = cut
	end

	-- THE ICONS KEEP THEIR OWN COLOUR (Josh 2026-09-21). Draining them and
	-- tinting them to one material was three rounds of trying to make this
	-- row look like ours, and it never did - the shapes are what tell these
	-- buttons apart and the colour was never the loud part. What is ours is
	-- the tile behind them and the bevel taken off the edge; the picture is
	-- the client's and is left alone. The switch that used to offer both is
	-- gone too: one of its two settings was never the right answer.
	if tex.SetDesaturated then
		pcall(tex.SetDesaturated, tex, false)
	end
	if tex.SetVertexColor then
		tex:SetVertexColor(1, 1, 1, 1)
	end
	if tex.ClearAllPoints and tex.SetPoint then
		local x, y = inset(button)
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", x, -y)
		tex:SetPoint("BOTTOMRIGHT", -x, y)
	end
end

local function eachFace(button, fn)
	for _, pair in ipairs(FACES) do
		local get = button[pair[1]]
		if get then
			local ok, tex = pcall(get, button)
			if ok and tex then
				fn(tex)
			end
		end
	end
end

-- the flat wash we light a button with, in place of the client's art
function M.FlatHighlight(button)
	pcall(button.SetHighlightTexture, button, "Interface\\Buttons\\WHITE8X8")
	local hi = button.GetHighlightTexture and button:GetHighlightTexture()
	if hi and hi.SetColorTexture then
		hi:SetColorTexture(1, 1, 1, 0.12)
		hi:SetAllPoints()
	end
end

-- a face the client gives a new picture (on hover, on a press, as its window
-- opens) is dressed again at once, from that picture's own corners
--
-- AND THE PICTURE STAYS UP UNDER THE POINTER (Josh 2026-09-24: "many icons
-- disappear when I hover them"; /bt microdump showed it). On hover the client
-- fades a button's picture to nothing and lets its highlight - the same
-- picture, lit - take over. Ours is a faint wash, not a picture, so the
-- button went blank. The picture is held at full strength instead, and the
-- wash lights it.
local holding = false
local function holdUp(tex)
	if holding or not BT.Enabled("micro") then
		return
	end
	local a = BT.Pill.Number(tex.GetAlpha and tex:GetAlpha(), 1)
	if a < 1 then
		holding = true
		tex:SetAlpha(1)
		holding = false
	end
end
M.HoldUp = holdUp

function M.WatchFace(tex, button)
	if tex.beebsWatched or type(hooksecurefunc) ~= "function" then
		return
	end
	tex.beebsWatched = true
	local function again(self)
		if BT.Enabled("micro") then
			dress(self, false, button)
		end
	end
	for _, method in ipairs({ "SetAtlas", "SetTexture" }) do
		if type(tex[method]) == "function" then
			pcall(hooksecurefunc, tex, method, again)
		end
	end
	-- only the face it wears: the pressed and disabled ones are the client's
	-- to show and hide
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	if tex == normal and type(tex.SetAlpha) == "function" then
		pcall(hooksecurefunc, tex, "SetAlpha", holdUp)
		if button.HookScript and not button.beebsHoverHeld then
			button.beebsHoverHeld = true
			local function check(self)
				local t = self.GetNormalTexture and self:GetNormalTexture()
				if t then
					holdUp(t)
				end
			end
			-- and again as the fade would run, in case the client animates it
			-- rather than setting it
			local function hover(self)
				check(self)
				if C_Timer and C_Timer.After then
					C_Timer.After(0, function() check(self) end)
					C_Timer.After(0.3, function() check(self) end)
				end
			end
			button:HookScript("OnEnter", hover)
			button:HookScript("OnLeave", hover)
		end
	end
end

function M.StyleButton(button, plain)
	if not (button and button.GetName) then
		return false
	end
	-- NO TILES IN THE PANEL (Josh 2026-09-22). On the open screen each
	-- button needs a surface of its own; in the panel it is already on one,
	-- and a bordered tile per button read as a strip of boxes stuck to the
	-- bottom of the panel. There they sit on the panel's own background, like
	-- every other icon in it. (And a tile is only made for a button that will
	-- wear it: docked, a dozen were built and never shown - 2026-09-23, audit.)
	local tiled = not plain and not M.Docked()
	local s = tiled and surface(button) or skins[button]
	if s then
		-- opaque, so the row is a strip of our tiles rather than our colour
		-- laid over whatever is behind the bottom of the screen
		if tiled then
			BT.Pill.PaintSurface(s, button, FILL, RIM)
		end
		BT.Pill.ShowSurface(s, tiled)
	end

	-- the bevel is the outer edge of the image, and there is no separate icon
	-- underneath it to keep
	eachFace(button, function(tex)
		dress(tex, plain, button)
		M.WatchFace(tex, button)
	end)

	-- THE PORTRAIT IS NOT A FACE (Josh 2026-09-21). The character button draws
	-- your own head on a texture of its own, so it sat there in full colour
	-- while the eleven buttons beside it went grey - the single most obvious
	-- thing in the row, and nothing done to the faces reached it.
	local nm = button.GetName and button:GetName()
	local portrait = button.Portrait or (nm and _G[nm .. "Portrait"])
	if not portrait and nm == "CharacterMicroButton" then
		portrait = _G.MicroButtonPortrait
	end
	dress(portrait, plain, button)

	-- the flashing border the client puts on a button to nag you, and the
	-- alert it hangs off one: both are art of its own
	local name = button:GetName()
	for _, suffix in ipairs({ "FlashBorder", "Flash", "Border" }) do
		local art = button[suffix] or (name and _G[name .. suffix])
		if art and art.SetAlpha then
			art:SetAlpha(plain and 1 or 0)
		end
	end

	if button.SetHighlightTexture then
		local bars = BT.GetModule("bars")
		local hi = button.GetHighlightTexture and button:GetHighlightTexture()
		if plain then
			-- the client's own highlight back, not ours at no alpha
			local snap = button.beebsHighlight
			if snap and bars and bars.RestoreTexture then
				if not snap.atlas and snap.file then
					pcall(button.SetHighlightTexture, button, snap.file)
					hi = button:GetHighlightTexture()
				end
				bars.RestoreTexture(hi, snap)
			end
			button.beebsHighlight = nil
		else
			if hi and button.beebsHighlight == nil and bars and bars.SnapshotTexture then
				local ok, snap = pcall(bars.SnapshotTexture, hi)
				button.beebsHighlight = ok and snap or false
			end
			M.FlatHighlight(button)
			if not button.beebsHighlightHooked and type(hooksecurefunc) == "function"
				and type(button.SetHighlightAtlas) == "function" then
				button.beebsHighlightHooked = true
				-- the client lights a button with an atlas of its own as the
				-- pointer arrives: ours goes back on over it
				pcall(hooksecurefunc, button, "SetHighlightAtlas", function(self)
					if BT.Enabled("micro") then
						M.FlatHighlight(self)
					end
				end)
			end
		end
	end
	return true
end

-- SWEEP THE REGIONS, DO NOT NAME THEM (Josh 2026-09-21). The plate under this
-- corner is drawn in pieces whose names differ by build, so ask each container
-- what it is drawing and take down everything that is not ours.
local plateArt = setmetatable({}, { __mode = "k" })

function M.StylePlate(plain)
	local n = 0
	for _, key in ipairs(PLATES) do
		local f = _G[key]
		if type(f) == "table" and f.GetRegions then
			local ok, regions = pcall(function()
				return { f:GetRegions() }
			end)
			for _, r in ipairs(ok and regions or {}) do
				if type(r) == "table" and not r.beebs and r.GetObjectType
					and r.SetAlpha and r:GetObjectType() == "Texture" then
					if plateArt[r] == nil then
						plateArt[r] = r:GetAlpha() or 1
					end
					r:SetAlpha(plain and plateArt[r] or 0)
					n = n + 1
				end
			end
		end
	end
	return n
end

function M.StyleAll(plain)
	local n = 0
	for _, button in ipairs(M.Buttons()) do
		if M.StyleButton(button, plain) then
			n = n + 1
		end
	end
	M.StylePlate(plain)
	M.lastCount = n
	return n
end

-- THE CLIENT REDRESSES THEM (Josh 2026-09-21). A micro button's face is set
-- again whenever what it opens changes state - the spellbook opening, a talent
-- point arriving, the game menu going up - so this goes on again after those
-- rather than once at login.
function M.Watch()
	if not M.events then
		M.events = CreateFrame("Frame")
		-- (not the loading screen: OnBind dresses them on every one already -
		-- Josh 2026-09-30, review)
		for _, event in ipairs({
			"UPDATE_BINDINGS", "PLAYER_LEVEL_UP",
			"PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORMS",
			"PORTRAITS_UPDATED",
		}) do
			pcall(M.events.RegisterEvent, M.events, event)
		end
		-- your own head is redrawn on the character button - yours, not every
		-- unit's in the raid, which is what the unfiltered event delivers
		if M.events.RegisterUnitEvent then
			pcall(M.events.RegisterUnitEvent, M.events, "UNIT_PORTRAIT_UPDATE", "player")
		else
			pcall(M.events.RegisterEvent, M.events, "UNIT_PORTRAIT_UPDATE")
		end
		M.events:SetScript("OnEvent", function()
			if BT.Enabled("micro") then
				M.StyleAll()
			end
		end)
	end
	-- ONCE PER BUTTON, NOT ONCE EVER (Josh 2026-09-21). Remembering only that
	-- we had run meant a call made before the client had built the micro menu
	-- hooked nothing and then refused to try again - the same trap the chat
	-- module fell into with its edit boxes.
	local function hook(button, style)
		if button.HookScript and not button.beebsHooked then
			button.beebsHooked = true
			button:HookScript("OnShow", function(self)
				if BT.Enabled("micro") then
					style(self)
				end
			end)
		end
	end
	for _, button in ipairs(M.Buttons()) do
		hook(button, M.StyleButton)
	end
	return M.events
end

-- ---------------------------------------------------------------------------
-- In the right panel
-- ---------------------------------------------------------------------------
--
-- THE CLIENT'S OWN BUTTONS, MOVED (Josh 2026-09-22). The same bargain as the
-- minimap: the buttons are not redrawn, they are moved into a line of the
-- dock and scaled to fit it. Each keeps its click, its tooltip, its key and
-- the glow the client puts on it to nag you. Copies that clicked the real
-- ones would have run the client's code from ours, and some of what these
-- open will not be opened that way in combat.
--
-- They can only be in one place, so while they are in the panel the corner
-- they came from is empty - its plate was already put away above. Switching
-- the line off, or the module, gives them back to the client.

local ROW_H, EDGE = 26, 8
-- room above and below the buttons, so they stand off the line over them the
-- way the text in every other line does
local PAD_Y = 5
-- where each button was, and at what size, for giving it back
local home = setmetatable({}, { __mode = "k" })

-- ALWAYS, WHILE THE MODULE IS ON (Josh 2026-09-22). There was a switch for
-- the panel or the client's corner, which made two versions of one module;
-- on is the panel, and off is the client's own micro menu, untouched.
function M.InPanel()
	return true
end

function M.Docked()
	return BT.Enabled("micro")
end

function M.Section()
	if M.section then
		return M.section
	end
	M.section = BT.Dock.Section("micro", 55)
	M.section.wantHeight = ROW_H
	-- the client draws nothing inside a frame with no height (see Performance)
	M.section:SetHeight(ROW_H)
	if M.section.HookScript then
		M.section:HookScript("OnSizeChanged", function()
			M.Layout()
		end)
	end
	return M.section
end

local function remember(b)
	if home[b] then
		return
	end
	local h = { parent = b.GetParent and b:GetParent(), scale = b.GetScale and b:GetScale() or 1 }
	if b.GetPoint then
		local ok, point, rel, relPoint, x, y = pcall(b.GetPoint, b, 1)
		if ok and point then
			h.at = { point, rel, relPoint, x or 0, y or 0 }
		end
	end
	home[b] = h
end

-- the buttons the client is showing, in its order
function M.Shown()
	local out = {}
	for _, b in ipairs(M.Buttons()) do
		if b.IsShown and b:IsShown() then
			out[#out + 1] = b
		end
	end
	return out
end

-- THE MENU MOVES WHOLE, NOT BUTTON BY BUTTON (Josh 2026-09-22). On this
-- build the buttons are laid out by the client's MicroMenu, a grid that
-- measures every button it holds. Taking the first one out made the store
-- button's OnHide ask the grid to lay itself out again, with a button it could
-- no longer measure - an error inside the client's own code. So where there
-- is a MicroMenu, it is the thing that moves: into the line, scaled to the
-- panel's width, with every button still its child and its own layout still
-- doing the arranging. One button at a time is only for a build without it.
local function menuOf()
	local menu = _G.MicroMenu
	if type(menu) == "table" and menu.SetParent and menu.GetWidth and menu.SetScale then
		return menu
	end
	return nil
end
M.Menu = menuOf

local function placed(f)
	return f:IsShown() and f.GetLeft and f:GetLeft() ~= nil
end

local function layoutMenu(menu)
	-- NOT INTO A LINE THAT IS NOT ON SCREEN (Josh 2026-09-22). Moved into a
	-- hidden line, the menu was hidden with it, and showing the line showed
	-- the menu - whose OnShow lays it out, measuring buttons that had no
	-- place on screen yet: an error in the client's own code. The line is up
	-- and placed first (see Fill), and only then does the menu come in.
	if not placed(M.section) then
		return #M.Shown()
	end
	remember(menu)
	if menu:GetParent() ~= M.section then
		menu:SetParent(M.section)
	end
	local width = BT.Pill.Number(M.section:GetWidth(), 0)
	if width <= 0 then
		width = 220
	end
	-- its own size, before our scale: the client sizes it to its buttons
	local w = BT.Pill.Number(menu:GetWidth(), 0)
	local h = BT.Pill.Number(menu:GetHeight(), 0)
	local shown = #M.Shown()
	if w <= 0 or h <= 0 then
		-- not laid out yet; the client's Layout, which is hooked, comes back
		return shown
	end
	-- EDGE TO EDGE (Josh 2026-09-24: "scale these icons so they fill out the
	-- entire row"). They were held to 22 tall as well, which left the row a
	-- strip of icons in the middle of the panel; the width decides now, and
	-- the line is as tall as that makes them.
	local scale = (width - EDGE * 2) / w
	menu:SetScale(scale)
	menu:ClearAllPoints()
	menu:SetPoint("CENTER", M.section, "CENTER", 0, 0)
	-- the line as tall as the menu came out, and no taller
	local want = math.ceil(h * scale) + PAD_Y * 2
	if M.section.wantHeight ~= want then
		M.section.wantHeight = want
		M.section:SetHeight(want)
		BT.Dock.Relayout()
	end
	return shown
end

local laying = false
function M.Layout()
	if laying or not (M.section and BT.Enabled("micro") and M.InPanel()) then
		return 0
	end
	laying = true
	local menu = menuOf()
	if menu then
		local ok, n = pcall(layoutMenu, menu)
		laying = false
		return ok and n or 0
	end
	local shown = M.Shown()
	local width = BT.Pill.Number(M.section:GetWidth(), 0)
	if width <= 0 then
		width = 220
	end
	local n = math.max(1, #shown)
	local cell = (width - EDGE * 2) / n
	-- guarded like the menu path: one button that will not be moved must not
	-- leave `laying` set and every later Layout returning nothing
	local ok = pcall(function()
		for i, b in ipairs(shown) do
			remember(b)
			if b:GetParent() ~= M.section then
				b:SetParent(M.section)
			end
			-- as large as the cell allows, whichever side runs out first
			local bw = BT.Pill.Number(b.GetWidth and b:GetWidth(), 0)
			local bh = BT.Pill.Number(b.GetHeight and b:GetHeight(), 0)
			if bw <= 0 then bw = 28 end
			if bh <= 0 then bh = 36 end
			local scale = math.min((cell - 1) / bw, (ROW_H - PAD_Y * 2) / bh)
			if b.SetScale then
				b:SetScale(scale)
			end
			b:ClearAllPoints()
			-- a scaled frame's offsets are in its own units
			b:SetPoint("CENTER", M.section, "LEFT", (EDGE + cell * (i - 0.5)) / scale, 0)
		end
	end)
	laying = false
	return ok and #shown or 0
end

-- every button back where the client had it
function M.Release()
	for b, h in pairs(home) do
		if b.SetScale then
			b:SetScale(h.scale or 1)
		end
		if h.parent and b.SetParent then
			b:SetParent(h.parent)
		end
		if h.at and b.ClearAllPoints then
			b:ClearAllPoints()
			pcall(b.SetPoint, b, h.at[1], h.at[2], h.at[3], h.at[4], h.at[5])
		end
		home[b] = nil
	end
	-- and the client's own layout, where it has one, puts them in order
	if type(_G.UpdateMicroButtonsParent) == "function" and _G.MicroMenu then
		pcall(_G.UpdateMicroButtonsParent, _G.MicroMenu)
	end
	if _G.MicroMenu and type(_G.MicroMenu.Layout) == "function" then
		pcall(_G.MicroMenu.Layout, _G.MicroMenu)
	end
	if _G.MicroMenuContainer and type(_G.MicroMenuContainer.Layout) == "function" then
		pcall(_G.MicroMenuContainer.Layout, _G.MicroMenuContainer)
	end
end

-- THE CLIENT PUTS THEM BACK (Josh 2026-09-22). Vehicles, pet battles and its
-- own layout pass all hand the buttons back to the client's row; each time,
-- they come straight back here. A button appearing or going (the store, the
-- guild) is a new layout too.
local hooked = false
local function watchClient()
	if hooked or type(hooksecurefunc) ~= "function" then
		return
	end
	hooked = true
	local function again()
		if BT.Enabled("micro") and M.InPanel() then
			M.Fill()
		end
	end
	for _, name in ipairs({ "UpdateMicroButtonsParent", "MoveMicroButtons", "UpdateMicroButtons" }) do
		if type(_G[name]) == "function" then
			pcall(hooksecurefunc, name, again)
		end
	end
	-- the menu lays itself out, and its container lays out the menu - which
	-- may put it back where the container keeps it
	for _, holder in ipairs({ _G.MicroMenu, _G.MicroMenuContainer }) do
		if type(holder) == "table" and type(holder.Layout) == "function" then
			pcall(hooksecurefunc, holder, "Layout", again)
		end
	end
	for _, b in ipairs(M.Buttons()) do
		if b.HookScript then
			b:HookScript("OnShow", again)
			b:HookScript("OnHide", again)
		end
	end
end

-- laid out, and the line up only while it has a button in it: a build with
-- no micro menu gets no empty strip in the dock
--
-- In this order: the line up and placed by the dock, THEN the menu moved in.
-- Going away, the other way round: the menu back to the client, then the line
-- down, so the menu is never hidden and shown again by a line of ours.
-- NEVER INSIDE ITSELF (Josh 2026-09-23, audit): giving the menu back calls
-- the client's layout, which this is hooked to - with no button shown and the
-- line still up, that came straight back here, again and again
local filling = false
local function fill()
	local section = M.Section()
	if #M.Shown() == 0 then
		if section:IsShown() then
			section:Hide()
			M.Release()
			BT.Dock.Relayout()
		end
		return false
	end
	if not section:IsShown() then
		section:Show()
		BT.Dock.Relayout()
	end
	M.Layout()
	return true
end

function M.Fill()
	if filling then
		return false
	end
	filling = true
	local ok, r = pcall(fill)
	filling = false
	return ok and r or false
end

-- WHICH BUTTONS (Josh 2026-09-24): any of the game's menu buttons can be
-- left out. It stays in the client's menu, hidden - moving one out once broke
-- the client's own layout - and hidden again if the client shows it; the
-- client's grid closes the gap. Switched back in, or the module off, it is
-- shown again (only the ones hidden here).
M.LABELS = {
	CharacterMicroButton = "Character", SpellbookMicroButton = "Spellbook", TalentMicroButton = "Talents",
	QuestLogMicroButton = "Quest log", SocialsMicroButton = "Social", GuildMicroButton = "Guild",
	LFDMicroButton = "Group finder", CollectionsMicroButton = "Collections", EJMicroButton = "Adventure guide",
	AchievementMicroButton = "Achievements", MainMenuMicroButton = "Game menu", HelpMicroButton = "Help",
	StoreMicroButton = "Shop", WorldMapMicroButton = "World map",
}

function M.Hidden(b)
	local name = b and b.GetName and b:GetName()
	local h = opt("hidden", nil)
	return (name and type(h) == "table" and h[name] == true) and true or false
end

local held = setmetatable({}, { __mode = "k" })
function M.ApplyHidden(plain)
	for _, b in ipairs(M.Buttons()) do
		local hide = not plain and BT.Enabled("micro") and M.Hidden(b)
		if hide then
			held[b] = true
			if not b.beebsHideHooked and b.HookScript then
				b.beebsHideHooked = true
				b:HookScript("OnShow", function(self)
					if held[self] and BT.Enabled("micro") and M.Hidden(self) then
						self:Hide()
					end
				end)
			end
			b:Hide()
		elseif held[b] then
			held[b] = nil
			b:Show()
		end
	end
	local menu = _G.MicroMenu
	if type(menu) == "table" and type(menu.Layout) == "function" then
		pcall(menu.Layout, menu)
	end
end

function M.SetHidden(name, hidden)
	BT.EnsureBound()
	BT.settings.micro = BT.settings.micro or {}
	local h = BT.settings.micro.hidden or {}
	h[name] = hidden and true or nil
	BT.settings.micro.hidden = h
	M.ApplyHidden()
	M.Layout()
end

function M.Apply()
	local on = BT.Enabled("micro") and M.InPanel()
	local section = M.Section()
	if on then
		watchClient()
		M.Fill()
		M.ApplyHidden()
	else
		M.ApplyHidden(true)
		M.Release()
		section:Hide()
	end
	BT.Dock.Relayout()
	return on
end

function M:OnEnable()
	M.Watch()
	M.StyleAll()
	M.Apply()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.StyleAll(true)
	M.Apply()
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("BeebMod moves the game's own buttons into the dock. Every one still does what it did before.")
	page:Note("Switch this off and the game's micro menu comes back as it was.", true)
	local list = page:Section("Buttons")
	for _, b in ipairs(M.Buttons()) do
		local name = b.GetName and b:GetName()
		if name then
			BT.Widgets.SwitchRow(list, M.LABELS[name] or name:gsub("MicroButton$", ""), "",
				function() return not M.Hidden(b) end,
				function(on) M.SetHidden(name, not on) end)
		end
	end
	page:Layout()
	self.found = BT.Widgets.Label(panel, "", "small", 0.45, 0.50, 0.48)
	self.found:SetPoint("BOTTOMLEFT", 2, 4)
end

function M:RefreshTab()
	if self.found then
		self.found:SetText(("%d buttons redrawn"):format(M.lastCount or 0))
	end
end

function M:ShowTab()
	M.StyleAll()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- Every button's faces as they are this moment, into the saved file (the
-- Testing page's Record button). A button under the pointer says so.
function M.Dump()
	local lines = {}
	for _, b in ipairs(M.Buttons()) do
		local name = tostring(b.GetName and b:GetName())
		local over = b.IsMouseOver and b:IsMouseOver() and " (under the pointer)" or ""
		lines[#lines + 1] = name .. over
		local faces = {}
		eachFace(b, function(tex)
			faces[#faces + 1] = tex
		end)
		local hi = b.GetHighlightTexture and b:GetHighlightTexture()
		if hi then
			faces[#faces + 1] = hi
		end
		for _, tex in ipairs(faces) do
			local ok, a, bb, c, d, e, f, g, h = pcall(tex.GetTexCoord, tex)
			lines[#lines + 1] = ("  %s | %s | coords %s | %s"):format(tostring(tex.GetDrawLayer and tex:GetDrawLayer()),
				pictureOf(tex), ok and table.concat({ a, bb, c, d, e, f, g, h }, ",") or "?",
				BT.Furniture.Describe(tex))
		end
	end
	BT.EnsureBound()
	BeebModDB.microDump = { at = U.Now(), lines = lines }
	return #lines
end

BT.Record("microDump", M.Dump, "micro")
