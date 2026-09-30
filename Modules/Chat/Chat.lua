-- The chat frames, in the toolkit's clothes (Josh 2026-09-20).
--
-- NOTHING HERE REIMPLEMENTS CHAT. Not one message is routed, filtered, or
-- rewritten: the client's chat frames do exactly what they did, and this
-- changes what they look like and where two of their pieces sit. That is the
-- whole reason it is a hundred lines rather than a thousand - the same bargain
-- the action bars module makes.
--
-- What it does:
--
--   the side buttons    the arrows and the speech bubble, which are a menu
--                       you can reach by right-clicking the tab and a scroll
--                       you can do with the wheel
--   the tabs            the client's tab art off, our own surface on
--   the edit box        moved to the TOP, laid over the tabs, in our surface
--
-- The edit box is the interesting one. The client re-anchors it every time it
-- opens, so putting it somewhere else means putting it back every time it
-- shows itself rather than once at login.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Chat/Chat.lua")

local U = BT.Util

local M = BT.Module({
	key = "chat",
	feature = "interface",
	title = "Chat",
	blurb = "Draws the chat windows flat",
	order = 60,
})

local FILL = BT.Widgets.FILL
local RIM = BT.Widgets.RIM
local EDIT_H = 22
-- a chat tab, once the art it was sized for is off it: a floor, a ceiling, and
-- the air left around the word itself
local TAB_H, TAB_MAX, TAB_PAD = 20, 28, 7
-- how far in the text starts once the client's own header is out of the way
local EDIT_INSET = 6

local skins = setmetatable({}, { __mode = "k" })

local function opt(name, fallback)
	local s = BT.settings and BT.settings.chat
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.chat = BT.settings.chat or {}
	BT.settings.chat[name] = value
	M.StyleAll()
end
M.SetOpt = setOpt

-- the tests look at what a tab is wearing
function M.Skins()
	return skins
end

-- ---------------------------------------------------------------------------
-- The pieces
-- ---------------------------------------------------------------------------

-- Alpha rather than Hide, for the same reason the action bars use it: the
-- client shows several of these itself on every update, and a hidden texture
-- it shows again is visible.
local function fade(thing, hidden)
	if thing and thing.SetAlpha then
		thing:SetAlpha(hidden and 0 or 1)
	end
end

-- ALPHA IS NOT ENOUGH FOR THE BUTTON FRAME (Josh 2026-09-20). The client fades
-- its side buttons IN when you point at chat, the same animation that brings
-- the background up - so a frame we had merely made transparent came back as a
-- second panel under the window the moment the mouse arrived. Hidden as well
-- as transparent, it has nothing to fade.
local function stow(thing, hidden)
	fade(thing, hidden)
	if thing and thing.SetShown then
		thing:SetShown(not hidden)
	end

end

-- PAINTED EVERY TIME, NOT ONCE (Josh 2026-09-21). The colours were set where
-- the textures were CREATED, so the surface kept whatever the theme was at the
-- moment a chat window first appeared: changing the colours in Settings
-- repainted every panel in the addon except this one.
local function paint(s)
	if not s then
		return
	end
	-- the shape hangs off the fill, wherever the fill has been stretched to:
	-- a chat window's panel reaches past the frame on purpose
	BT.Pill.PaintSurface(s, s.anchor or s.fill, FILL, RIM)
end

local function surface(frame, key)
	local s = skins[frame]
	if s then
		paint(s)
		return s
	end
	if not (frame and frame.CreateTexture) then
		return nil
	end
	-- A RIM IS A RING, NOT A RECTANGLE UNDER THE FILL (Josh 2026-09-21). The
	-- fill is translucent, so a rim drawn full-size underneath it bled twelve
	-- percent of the border colour through the whole window - set the border
	-- red and the chat background went red. The fill takes the shape now and
	-- the ring is drawn around it. See UI/Pill.lua.
	s = BT.Pill.Surface(frame, "BACKGROUND", -8)
	s.key = key
	skins[frame] = s
	paint(s)
	return s
end

-- The client's own art on a tab: three slices each for normal, selected and
-- highlighted, all named after the tab.
local TAB_ART = {
	"Left", "Middle", "Right",
	"SelectedLeft", "SelectedMiddle", "SelectedRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}

-- A TAB OF OUR OWN (Josh 2026-09-20). Fading the client's nine slices left a
-- word floating over whatever was behind it, and the dock's own background
-- band running the width of the frame underneath. A tab is a thing you click,
-- so it gets the surface everything else clickable in this addon has: the
-- fill, the hairline, and the accent when it is the one you are reading.
local function styleTab(tab, plain, selected)
	if not tab then
		return
	end
	local name = tab.GetName and tab:GetName()
	surface(tab, "tab")
	-- EVERY TEXTURE ON IT, NOT A LIST OF NAMES (Josh 2026-09-20). The list was
	-- Left/Middle/Right and SelectedLeft and so on, which is what the client
	-- called them once. This build calls them something else - Active rather
	-- than Selected, and hung on the tab rather than under a global - so the
	-- list faded nothing and the gold art sat on top of our own surface.
	--
	-- Asking the tab what it is drawing cannot go out of date. Ours are marked
	-- so the sweep leaves them alone.
	if tab.GetRegions then
		for _, region in ipairs({ tab:GetRegions() }) do
			if not region.beebs and region.GetObjectType
				and region:GetObjectType() == "Texture" then
				fade(region, not plain)
			end
		end
	end
	-- and the few the client still keeps under a global of its own
	for _, part in ipairs(TAB_ART) do
		fade(name and _G[name .. part], not plain)
	end
	local text = tab.Text or (name and _G[name .. "Text"])
	if text and text.SetTextColor then
		if plain then
			text:SetTextColor(1, 0.82, 0)
		elseif selected then
			text:SetTextColor(0.90, 0.98, 0.94)
		else
			-- DIM IS NOT UNREADABLE (Josh 2026-09-20). The unselected tabs
			-- were 0.48 grey on a near-black fill, which is the contrast of a
			-- disabled control - and a tab you cannot read is a tab you cannot
			-- choose. Told apart by weight of colour, not by being hidden.
			text:SetTextColor(0.70, 0.77, 0.74)
		end
	end
	-- SHORTER THAN THE CLIENT MAKES THEM (Josh 2026-09-20). A chat tab is
	-- sized for art that is no longer on it: with the gold gone it is a word
	-- in a box half again as tall as the word.
	if tab.SetHeight then
		if not tab.beebsHeight and tab.GetHeight then
			local ok, was = pcall(tab.GetHeight, tab)
			tab.beebsHeight = BT.Pill.Number(ok and was or nil, 0) > 0 and was or nil
		end
		if plain then
			if tab.beebsHeight then
				tab:SetHeight(tab.beebsHeight)
				tab.beebsHeight = nil
			end
		else
			-- ONE HEIGHT FOR ALL OF THEM (Josh 2026-09-21). Measuring each
			-- tab's own text means a tab made later measures differently -
			-- its text may not be laid out yet, or its word may have no
			-- descender - and comes out a different size to the ones beside
			-- it. A strip of tabs is one object: they line up or they look
			-- broken, and "Less" sat above the others because of it.
			--
			-- So the measurement happens once, off whichever tab is tallest,
			-- and every tab gets that. Still measured rather than guessed -
			-- eighteen was a guess and it cut the descenders off "Combat Log".
			local want = M.TabHeight(text)
			tab:SetHeight(want)
		end
	end
	-- AND THE WORD IN THE MIDDLE OF IT (Josh 2026-09-20). The client anchors a
	-- tab's text for its own art, which had more above the word than below it.
	-- On a tab sized to the word, that offset puts the word on the floor.
	if text and text.ClearAllPoints and text.SetPoint then
		if plain then
			local was = tab.beebsText
			if was then
				text:ClearAllPoints()
				pcall(text.SetPoint, text, was.point, tab, was.relPoint, was.x, was.y)
				tab.beebsText = nil
			end
		else
			if not tab.beebsText and text.GetPoint then
				local ok, point, _, relPoint, x, y = pcall(text.GetPoint, text, 1)
				if ok and point then
					tab.beebsText = { point = point, relPoint = relPoint, x = x, y = y }
				end
			end
			text:ClearAllPoints()
			pcall(text.SetPoint, text, "CENTER", tab, "CENTER", 0, 0)
		end
	end

	local s = surface(tab, "tab")
	if not s then
		return
	end
	BT.Pill.ShowSurface(s, not plain)
	if plain then
		return
	end
	-- THE ONE YOU ARE READING IS LIT, the rest are the panel's own colour -
	-- the same two states every switch and tag in the toolkit has.
	if selected then
		BT.Pill.PaintSurface(s, tab, BT.Widgets.WASH, BT.Widgets.ACCENT)
	else
		BT.Pill.PaintSurface(s, tab, FILL, RIM)
	end
end

-- THE BAND UNDER THE TABS. The dock that holds them draws a background of its
-- own the width of the chat frame, which with the tabs' art gone is a grey
-- stripe over the world and nothing else.
local function styleDock(plain, tabHeight)
	local dock = _G.GeneralDockManager
	if not dock then
		return
	end
	-- the dock, the scroll frame inside it, and the child inside that: three
	-- frames deep, and any of them may be drawing the band
	-- pairs, not ipairs: a frame this build has not got is a hole in the
	-- list, and ipairs stops at the first hole
	for _, f in pairs({ dock, _G.GeneralDockManagerScrollFrame,
		_G.GeneralDockManagerScrollFrameChild, dock.Background }) do
		if f and f.GetRegions then
			for _, region in ipairs({ f:GetRegions() }) do
				if not region.beebs and region.GetObjectType
					and region:GetObjectType() == "Texture" then
					fade(region, not plain)
				end
			end
		end
	end
	fade(dock.Background, not plain)

	-- ALIGNING THEM IS NOT WORTH UNANCHORING THE DOCK (Josh 2026-09-20). The
	-- tabs start a few pixels left of the window, because the client's tab art
	-- had a shaped end that overhung it. Moving the dock to match meant
	-- ClearAllPoints followed by a SetPoint inside a pcall - and when that
	-- SetPoint did not take, the dock was left with no anchors at all and the
	-- tabs vanished.
	--
	-- Our own surface is ours to move; the client's furniture is not. The
	-- panel goes out to meet the tabs instead - see styleFrame.

	-- THE TABS WERE LEFT FLOATING (Josh 2026-09-20). The dock is as tall as
	-- the tabs the client drew, and shortening them left it holding the old
	-- height - so the tabs sat at the top of a band of nothing, a gap above
	-- the window they belong to. It comes down with them.
	if dock.SetHeight then
		if not dock.beebsHeight and dock.GetHeight then
			local ok, was = pcall(dock.GetHeight, dock)
			dock.beebsHeight = BT.Pill.Number(ok and was or nil, 0) > 0 and was or nil
		end
		if plain then
			if dock.beebsHeight then
				dock:SetHeight(dock.beebsHeight)
				dock.beebsHeight = nil
			end
		elseif tabHeight and tabHeight > 0 then
			dock:SetHeight(tabHeight)
		end
	end

	-- A WINDOW YOU MADE IS NOT DOCKED WHERE GENERAL IS (Josh 2026-09-21). The
	-- client docks its own windows straight onto the dock, centred on it; a
	-- window you create goes into the scrolling strip beside them, centred on
	-- THAT. Shortening the dock and not the strip left the strip at the old
	-- height, and "Less" centred on a taller box sat above the other tabs
	-- however tall the tabs themselves were. The strip and what it scrolls
	-- come down with the dock.
	local scroll = dock.scrollFrame or _G.GeneralDockManagerScrollFrame
	local child = (scroll and type(scroll.GetScrollChild) == "function"
		and select(2, pcall(scroll.GetScrollChild, scroll)))
		or _G.GeneralDockManagerScrollFrameChild
	for _, f in pairs({ scroll, child }) do
		if type(f) == "table" and f.SetHeight then
			if not f.beebsHeight and f.GetHeight then
				local ok, was = pcall(f.GetHeight, f)
				f.beebsHeight = BT.Pill.Number(ok and was or nil, 0) > 0 and was or nil
			end
			if plain then
				if f.beebsHeight then
					pcall(f.SetHeight, f, f.beebsHeight)
					f.beebsHeight = nil
				end
			elseif tabHeight and tabHeight > 0 then
				pcall(f.SetHeight, f, tabHeight)
			end
		end
	end
end

-- THE WINDOW ITSELF (Josh 2026-09-20). The black behind the messages is the
-- client's, and how solid it is comes from a slider in its own options - so it
-- is the one part of chat that was still the client's colour rather than ours.
--
-- The client's is faded and one of our own goes behind it: the same fill and
-- hairline every panel in the toolkit wears. The slider still works; it is
-- just moving something that is no longer drawn.
local function styleFrame(frame, plain)
	-- THE CLIENT FADES IT BACK IN WHEN YOU POINT AT IT (Josh 2026-09-20). A
	-- chat frame's background is not simply drawn - it is animated up on
	-- mouseover and down again after, which set the alpha we had cleared
	-- straight back to the player's own setting. Hovering turned the window
	-- black.
	--
	-- So the window's alpha is set through the client's OWN call rather than
	-- by hiding its textures behind its back: with the setting itself at zero,
	-- the fade has nothing to fade to and the animation is a no-op. The
	-- player's value is remembered and handed back when the module goes.
	if _G.FCF_SetWindowAlpha then
		if plain then
			if frame.beebsAlpha then
				pcall(_G.FCF_SetWindowAlpha, frame, frame.beebsAlpha, true)
				frame.beebsAlpha = nil
			end
		else
			if not frame.beebsAlpha then
				frame.beebsAlpha = frame.oldAlpha or frame.bgAlpha or 1
			end
			pcall(_G.FCF_SetWindowAlpha, frame, 0, true)
		end
	end
	local s = surface(frame, "chat")
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if not region.beebs and region.GetObjectType
				and region:GetObjectType() == "Texture" then
				fade(region, not plain)
			end
		end
	end
	if not s then
		return
	end
	BT.Pill.ShowSurface(s, not plain)
	if plain then
		return
	end

	-- UP TO MEET THE TABS (Josh 2026-09-20). The client's tab art overlapped
	-- the top of the window and hid the gap between them; ours does not, so
	-- the tabs were left hanging over a strip of world. Rather than move the
	-- window - the client owns where that is - the surface is stretched up to
	-- the underside of the tab strip, which is the edge the tabs are sitting
	-- on anyway.
	local dock = _G.GeneralDockManager
	s.fill:ClearAllPoints()
	if dock and dock.GetBottom and frame.GetTop then
		local N = BT.Pill.Number
		local under = N(dock:GetBottom(), nil)
		local top = N(frame:GetTop(), nil)
		if under and top and under > top then
			-- and out to the left, as far as the tabs start: the same few
			-- pixels the client's shaped tab art used to overhang by
			local tab = _G.ChatFrame1Tab
			local tabLeft = N(tab and tab.GetLeft and tab:GetLeft(), nil)
			local frameLeft = N(frame.GetLeft and frame:GetLeft(), nil)
			local out = 0
			if tabLeft and frameLeft and frameLeft > tabLeft
				and frameLeft - tabLeft < 20 then
				out = frameLeft - tabLeft
			end
			-- out to the corner the frame was moved off, so the padding
			-- inside the panel is not a gap outside it
			-- HOW FAR OUT IS NOT A CONSTANT (Josh 2026-09-21). On the left
			-- it is whichever is further - the padding, or the few pixels
			-- the tabs already start out by - so it is remembered here and
			-- the edit box lines up with what was actually drawn rather
			-- than with what it assumes was drawn.
			s.pad = { left = math.max(out, M.FLUSH_INSET), right = M.FLUSH_INSET }
			s.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", -s.pad.left, under - top)
			s.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
				s.pad.right, -M.FLUSH_INSET)
			s.anchor = s.fill
			paint(s)
			return
		end
	end
	s.pad = { left = M.FLUSH_INSET, right = M.FLUSH_INSET }
	s.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", -M.FLUSH_INSET, 0)
	s.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
		M.FLUSH_INSET, -M.FLUSH_INSET)
	s.anchor = s.fill
	paint(s)
end

-- THE SIDE BUTTONS. Two scroll arrows, a jump-to-bottom, and the speech
-- bubble that opens a menu - all of which the wheel and a right-click on the
-- tab already do, and all of which sit in the margin taking up room.
--
-- AND THE SCROLLBAR (Josh 2026-09-24: "the arrows and scrollbar seem to be
-- hanging outside of the chat window"). This client's chat has a scrollbar
-- of its own - two arrows, a thumb and a jump to the newest - on the window's
-- right edge, half outside it. The marks in the corner do all four.
--
-- THE MENU BUTTON IS PARKED, NOT HIDDEN (Josh 2026-09-24: "chat menu button
-- does nothing when clicked"). Its menu will not open for a button that is
-- not showing, and it opens on a press, not on a click from code. So it
-- stays up - invisible, deaf to the mouse - sitting under our cog, and the
-- cog opens its menu there (see openMenu).
local parked

local function park(mb, frame, hide)
	if not (mb and mb.SetPoint) then
		return
	end
	if hide then
		if not parked then
			local points = {}
			for i = 1, (mb.GetNumPoints and mb:GetNumPoints()) or 0 do
				points[i] = { mb:GetPoint(i) }
			end
			parked = { parent = mb.GetParent and mb:GetParent(), points = points,
				mouse = mb.IsMouseEnabled and mb:IsMouseEnabled() }
		end
		local cog = frame.beebsControls and frame.beebsControls.list[1]
		pcall(mb.SetParent, mb, frame)
		mb:ClearAllPoints()
		if cog then
			mb:SetPoint("CENTER", cog, "CENTER", 0, 0)
		else
			mb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
		end
		mb:SetAlpha(0)
		pcall(mb.EnableMouse, mb, false)
		mb:Show()
	elseif parked then
		pcall(mb.SetParent, mb, parked.parent)
		mb:ClearAllPoints()
		for _, p in ipairs(parked.points) do
			pcall(mb.SetPoint, mb, unpack(p))
		end
		mb:SetAlpha(1)
		pcall(mb.EnableMouse, mb, parked.mouse ~= false)
		mb:Show()
		parked = nil
	end
end

-- PUT AWAY FOR GOOD, NOT UNTIL THE NEXT SCROLL (Josh 2026-09-29: "The
-- scrollbar and related buttons go outside of our chat box, and you cannot
-- click them. They disappear as soon as you hover over them"). The client
-- shows its scrollbar and its jump-to-bottom again whenever you scroll up,
-- and only pointing at chat put them away - so they went as the mouse
-- reached them. Each one is hidden again as it shows. What they told you,
-- that newer lines are below, is a mark inside the panel now (M.Newest).
local function keepStowed(thing)
	if not (thing and thing.HookScript) or thing.beebsStowed then
		return
	end
	thing.beebsStowed = true
	thing:HookScript("OnShow", function(self)
		if BT.Enabled("chat") and opt("buttons", true) then
			self:Hide()
		end
	end)
end

local function styleButtons(frame, plain)
	local name = frame.GetName and frame:GetName()
	local hide = (not plain) and opt("buttons", true)
	local pieces = { frame.buttonFrame, frame.ScrollBar, frame.ScrollToBottomButton }
	for _, suffix in ipairs({ "ButtonFrame", "ButtonFrameUpButton",
		"ButtonFrameDownButton", "ButtonFrameBottomButton", "ScrollBar", "ScrollToBottomButton" }) do
		pieces[#pieces + 1] = name and _G[name .. suffix]
	end
	-- pairs, not ipairs: a piece this build has not got is a hole in the list
	for _, thing in pairs(pieces) do
		stow(thing, hide)
		if hide then
			keepStowed(thing)
		end
	end
	if name == "ChatFrame1" then
		park(_G.ChatFrameMenuButton, frame, hide)
		stow(_G.QuickJoinToastButton, hide)
	end
end

-- ---------------------------------------------------------------------------
-- The edit box, which will not stay where it is put
-- ---------------------------------------------------------------------------

-- THE HEADER STAYS (Josh 2026-09-20). It was hidden with the rest of the
-- box's art, and the client's text inset - which exists to leave room for it -
-- stayed behind as an empty margin. Trimming the inset fixed the margin and
-- lost the one thing worth having in it: the label that says WHICH channel
-- you are about to say this in.
--
-- So the label comes back and the inset goes back to the client's, which is
-- the size of the label. Only the frame's own gilt edges come off.
local EDIT_ART = {
	"Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid",
	"ConversationIcon",
}

function M.PlaceEditBox(box, plain)
	if not (box and box.ClearAllPoints) then
		return false
	end
	local parent = box.chatFrame or _G.ChatFrame1
	if not parent then
		return false
	end
	local name = box.GetName and box:GetName()
	for _, part in ipairs(EDIT_ART) do
		fade(name and _G[name .. part], not plain)
		fade(box[part], not plain)
	end
	if plain then
		-- and the height, the strata and the mouse, which LiftEditBox and the
		-- placement below change and the client never puts back
		local was = box.beebsWas
		if was then
			if was.height and box.SetHeight then
				pcall(box.SetHeight, box, was.height)
			end
			if was.strata and box.SetFrameStrata then
				pcall(box.SetFrameStrata, box, was.strata)
			end
			box.beebsWas = nil
		end
		if box.EnableMouse then
			pcall(box.EnableMouse, box, true)
		end
		local s = skins[box]
		if s then
			BT.Pill.ShowSurface(s, false)
		end
		return true
	end
	if not box.beebsWas then
		local okh, h = pcall(function() return box:GetHeight() end)
		local oks, strata = pcall(function() return box:GetFrameStrata() end)
		box.beebsWas = {
			height = BT.Pill.Number(okh and h or nil, 0) > 0 and h or nil,
			strata = (oks and type(strata) == "string") and strata or nil,
		}
	end
	surface(box, "edit")
	-- ON TOP, OVER THE TABS (Josh 2026-09-20). Typing happens at the bottom of
	-- the screen in every other game and at the bottom of the chat frame here,
	-- which is where your eye already is for the newest line. Above it, the
	-- box is somewhere on its own, and the tabs it covers are only wanted when
	-- you are not typing.
	box:ClearAllPoints()
	-- THE SAME EDGES AS THE WINDOW UNDER IT (Josh 2026-09-20). Two pixels
	-- either side made the box wider than the panel it sits on, which reads as
	-- a mistake rather than as a deliberate overhang - two rectangles nearly
	-- lining up look worse than two that do.
	-- and the panel now reaches past the frame on both sides, so the box
	-- follows it out rather than lining up with the frame it is anchored to
	local under = M.Skins()[parent]
	local pad = (under and under.pad) or { left = M.FLUSH_INSET, right = M.FLUSH_INSET }
	box:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", -pad.left, 1)
	box:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", pad.right, 1)
	box:SetHeight(EDIT_H)
	M.LiftEditBox(box, box.HasFocus and box:HasFocus())
	return true
end

-- OUT OF THE WAY UNTIL YOU ARE TYPING (Josh 2026-09-20). The box lies over
-- the tabs, and a frame over another frame takes the clicks whether or not
-- there is anything to see: "close it when a tab is clicked" only ran when the
-- click got through, and it never did.
--
-- So it drops below the tabs and stops taking the mouse at all when it is not
-- focused, and comes back up when it is. Nothing is clickable in a text field
-- you are not typing in anyway - it is opened with Enter.
function M.LiftEditBox(box, up)
	if not box then
		return false
	end
	-- AND ITS SURFACE GOES WITH IT (Josh 2026-09-20). The box is dressed when
	-- it is placed, which is once - so the fill and the hairline stayed drawn
	-- while the box was closed, and that is the band beside the tabs. It is a
	-- box you are typing in or it is nothing at all.
	local s = skins[box]
	if s then
		BT.Pill.ShowSurface(s, up and true or false)
	end

	if box.SetFrameStrata then
		box:SetFrameStrata(up and "DIALOG" or "BACKGROUND")
	end
	if box.EnableMouse then
		box:EnableMouse(up and true or false)
	end

	return true
end

-- ---------------------------------------------------------------------------
-- Into the corner
-- ---------------------------------------------------------------------------

-- THE MARGIN IS THE FRAME'S OWN POSITION (Josh 2026-09-20). There is no
-- padding to take off: the gap at the left and the bottom is where the chat
-- frame IS, and on this build the HUD Edit Mode owns that. So the frame is
-- moved rather than trimmed - hard into the bottom-left corner, keeping the
-- size it already had.
--
-- Its first anchor is remembered, so switching the module off puts the frame
-- back wherever you had it rather than leaving it in the corner for good.
--
-- FLUSH IS THE PANEL, NOT THE TEXT (Josh 2026-09-21). At nothing at all the
-- text sat on the screen edge and the last line ran off the bottom of it. So
-- the FRAME comes in by a few pixels and the surface is stretched back out to
-- meet the corner - the panel stays flush and the text gets room inside it.
-- Moving the two together would only put the strip of world back.
local FLUSH_INSET = 6
M.FLUSH_INSET = FLUSH_INSET

function M.Corner(frame, plain)
	if not (frame and frame.ClearAllPoints and frame.SetPoint) then
		return false
	end
	if plain then
		local was = frame.beebsWas
		if was then
			frame:ClearAllPoints()
			pcall(frame.SetPoint, frame, was.point, UIParent, was.relPoint, was.x, was.y)
			if was.clamp and frame.SetClampRectInsets then
				pcall(frame.SetClampRectInsets, frame, was.clamp[1], was.clamp[2],
					was.clamp[3], was.clamp[4])
			end
			frame.beebsWas = nil
		end
		return true
	end
	if not frame.beebsWas and frame.GetPoint then
		local ok, point, _, relPoint, x, y = pcall(frame.GetPoint, frame, 1)
		if ok and point then
			frame.beebsWas = { point = point, relPoint = relPoint, x = x, y = y }
			if frame.GetClampRectInsets then
				local okc, l, r, t, b = pcall(frame.GetClampRectInsets, frame)
				if okc then
					frame.beebsWas.clamp = { l, r, t, b }
				end
			end
		end
	end
	-- THE CLAMP IS WHAT KEPT IT OFF THE EDGE (Josh 2026-09-20). A chat frame
	-- is clamped to the screen with insets, and those insets are a margin the
	-- client will not let the frame cross - so anchoring it to the corner put
	-- it there and the next clamp pushed it straight back out. The anchor was
	-- never the problem.
	--
	-- Zeroed, the frame may sit flush against the edge. The originals are
	-- remembered with the position, so switching the module off gives back
	-- both the place and the margin.
	if frame.SetClampRectInsets then
		pcall(frame.SetClampRectInsets, frame, 0, 0, 0, 0)
	end

	frame:ClearAllPoints()
	local ok = pcall(frame.SetPoint, frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT",
		FLUSH_INSET, FLUSH_INSET)
	if ok and frame.SetUserPlaced then
		pcall(frame.SetUserPlaced, frame, true)
	end
	return ok
end

-- ---------------------------------------------------------------------------
-- The controls, on hover
-- ---------------------------------------------------------------------------

-- WHAT THE SIDE BUTTONS DID (Josh 2026-09-20). Hiding them took the room back
-- and took the scroll, the jump-to-bottom and the chat menu with it. The wheel
-- covers one of those; nothing covered the others, and "it is in a menu you
-- have to know about" is not an answer.
--
-- They come back as four small marks in the corner of the chat frame, shown
-- only while the mouse is over it. Out of the way when you are reading, and
-- exactly where you expect when you reach for them.
--
-- The menu one presses the client's own button rather than reimplementing its
-- menu: that button is faded to nothing, not removed, and a faded button still
-- takes a click from code.
-- Four small marks in the corner of the chat frame, shown only while the mouse
-- is over it (Josh 2026-09-20). Out of the way when you are reading, and where
-- you expect them when you reach for them.
--
-- They were tried as large buttons down the right-hand edge, in the style of
-- the game's own jump-to-bottom. The marks were better: this is chat, and a
-- column of buttons inside it is a scrollbar nobody asked for.
--
-- The menu one presses the client's own button rather than reimplementing its
-- menu: that button is faded to nothing, not removed, and a faded button still
-- takes a click from code.
-- BIG ENOUGH TO SEE, AND ON SOMETHING (Josh 2026-09-24: "barely visible").
-- Twelve pixels of the rule's grey-green over the text of the chat itself
-- was nearly nothing; they are a size up, in the panel's light text, on a
-- strip of the panel's own fill so a line of chat under them does not show
-- through.
local CONTROL, CONTROL_GAP = 14, 4
local MARK = { 0.80, 0.84, 0.82 }

local function controlButton(holder, i, coord, flip, onClick, tip)
	local b = holder.list[i]
	if b then
		return b
	end
	b = CreateFrame("Button", nil, holder)
	b:SetSize(CONTROL, CONTROL)
	b:SetPoint("RIGHT", holder, "RIGHT", -((i - 1) * (CONTROL + CONTROL_GAP)), 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexture(BT.Dock.ICONS)
	coord(b.icon, flip)
	b.icon:SetVertexColor(MARK[1], MARK[2], MARK[3], 1)
	b:SetScript("OnEnter", function(self)
		BT.Widgets.Tint(self.icon)
		if tip and GameTooltip then
			BT.Dock.Tip(self, function() GameTooltip:AddLine(tip, 1, 1, 1) end)
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(MARK[1], MARK[2], MARK[3], 1)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	b:SetScript("OnClick", onClick)
	holder.list[i] = b
	return b
end

-- the client's chat menu, opened from the cog: its own button, parked under
-- it, opened the way a dropdown opens - on a press - and a click for a build
-- whose button still answers one
function M.OpenMenu(frame)
	local mb = _G.ChatFrameMenuButton
	if not mb then
		return false
	end
	park(mb, frame, true)
	if type(mb.OpenMenu) == "function" and pcall(mb.OpenMenu, mb) then
		return true
	end
	local press = mb.GetScript and mb:GetScript("OnMouseDown")
	if press and pcall(press, mb, "LeftButton") then
		return true
	end
	return mb.Click ~= nil and pcall(mb.Click, mb) or false
end

-- the third sheet: Art/chat.tga, two slots of 0.5 (scripts/make-icons.py)
M.ART = "Interface\\AddOns\\BeebMod\\Art\\chat"
function M.ExpandCoord(tex)
	tex:SetTexture(M.ART)
	tex:SetTexCoord(0, 0.5, 0, 1)
end
-- NEWEST LINE IS AN ARROW ONTO A LINE (Josh 2026-09-29, from a picture). It
-- was the check mark, which reads as "done", not as "down to the newest".
function M.NewestCoord(tex)
	tex:SetTexture(M.ART)
	tex:SetTexCoord(0.5, 1, 0, 1)
end

-- THE NEWEST LINE, WHILE YOU ARE SCROLLED UP (Josh 2026-09-29). The client's
-- jump-to-bottom is hidden for good (keepStowed), and it was the only thing
-- that said you were reading old lines. This mark says it from inside the
-- panel's corner: it shows while there are newer lines below, and a click
-- takes you to them. The large chat window has one too.
--
-- `wanted` says whether the mark may show at all, so the chat windows can
-- follow their switch and the large window can ignore it.
function M.Newest(smf, wanted)
	if not smf then
		return nil
	end
	local b = smf.beebsNewest
	if not b then
		b = CreateFrame("Button", nil, smf)
		b:SetSize(CONTROL, CONTROL)
		b:SetPoint("BOTTOMRIGHT", smf, "BOTTOMRIGHT", -4, 4)
		b:SetFrameLevel((smf.GetFrameLevel and smf:GetFrameLevel() or 1) + 10)
		b.back = b:CreateTexture(nil, "BACKGROUND")
		b.back:SetPoint("TOPLEFT", -4, 3)
		b.back:SetPoint("BOTTOMRIGHT", 3, -3)
		b.back:SetColorTexture(FILL[1], FILL[2], FILL[3], 0.92)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		M.NewestCoord(b.icon)
		b.icon:SetVertexColor(MARK[1], MARK[2], MARK[3], 1)
		b:SetScript("OnEnter", function(self)
			BT.Widgets.Tint(self.icon)
			if GameTooltip then
				BT.Dock.Tip(self, function() GameTooltip:AddLine("Newest line", 1, 1, 1) end)
			end
		end)
		b:SetScript("OnLeave", function(self)
			self.icon:SetVertexColor(MARK[1], MARK[2], MARK[3], 1)
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
		b:SetScript("OnClick", function()
			smf:ScrollToBottom()
		end)
		b.wanted = wanted
		b.Update = function()
			local ok, at = false, nil
			if smf.AtBottom then
				ok, at = pcall(smf.AtBottom, smf)
			end
			local up = ok and at == false
			b:SetShown(up and (not b.wanted or b.wanted()) and true or false)
		end
		smf.beebsNewest = b
		-- every way the view moves: the wheel, the marks, Page Up and Down,
		-- and the client's own calls
		if hooksecurefunc then
			for _, fn in ipairs({ "ScrollUp", "ScrollDown", "ScrollToTop", "ScrollToBottom",
				"PageUp", "PageDown", "SetScrollOffset", "ScrollByAmount" }) do
				if type(smf[fn]) == "function" then
					pcall(hooksecurefunc, smf, fn, b.Update)
				end
			end
		end
	end
	b.back:SetColorTexture(FILL[1], FILL[2], FILL[3], 0.92)
	b.Update()
	return b
end

function M.Controls(frame, plain)
	if plain then
		if frame.beebsControls then
			frame.beebsControls:Hide()
		end
		if frame.beebsNewest then
			frame.beebsNewest:Hide()
		end
		return true
	end
	M.Newest(frame, function()
		return BT.Enabled("chat") and opt("buttons", true)
	end)
	local holder = frame.beebsControls
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		holder.list = {}
		holder:SetSize(CONTROL * 5 + CONTROL_GAP * 4, CONTROL)
		holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
		holder:EnableMouse(true)
		-- above the text, on the panel's own fill
		holder:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 10)
		holder.back = holder:CreateTexture(nil, "BACKGROUND")
		holder.back:SetPoint("TOPLEFT", -4, 3)
		holder.back:SetPoint("BOTTOMRIGHT", 3, -3)
		holder.back:SetColorTexture(FILL[1], FILL[2], FILL[3], 0.92)
		frame.beebsControls = holder

		-- reading right to left: the menu, the newest, down, up, and the
		-- large window (Josh 2026-09-29: "Can we add a button that opens the
		-- chat in a large modal?"), Modules/Chat/Reader.lua
		controlButton(holder, 5, M.ExpandCoord, nil, function()
			if BT.ChatReader then
				BT.ChatReader.Toggle(frame)
			end
		end, "Open in a large window")
		controlButton(holder, 1, BT.Dock.CogCoord, nil, function()
			M.OpenMenu(frame)
		end, "Chat menu")
		controlButton(holder, 2, M.NewestCoord, nil, function()
			if frame.ScrollToBottom then
				frame:ScrollToBottom()
			end
		end, "Newest line")
		controlButton(holder, 3, BT.Dock.ChevronCoord, false, function()
			if frame.ScrollDown then
				frame:ScrollDown()
			end
		end, "Scroll down")
		controlButton(holder, 4, BT.Dock.ChevronCoord, true, function()
			if frame.ScrollUp then
				frame:ScrollUp()
			end
		end, "Scroll up")

		-- ONLY WHILE YOU ARE POINTING AT IT. Leaving the frame hides them,
		-- unless you have moved onto the marks themselves.
		local function follow()
			-- hooked once and never unhooked, so it has to know when the
			-- module is off: it used to keep fading the window and stowing
			-- the client's buttons on every hover after the switch
			if not (BT.Enabled("chat") and opt("buttons", true)) then
				holder:Hide()
				return
			end
			local over = (frame.IsMouseOver and frame:IsMouseOver())
				or (holder.IsMouseOver and holder:IsMouseOver())
			holder:SetShown(over and true or false)
			-- the fade runs on the way in and on the way out; the window's
			-- own alpha is zero either way
			if over then
				-- the fade brings the client's own furniture back with the
				-- background; both are put away again
				if _G.FCF_SetWindowAlpha then
					pcall(_G.FCF_SetWindowAlpha, frame, 0, true)
				end
				styleButtons(frame, false)
				-- in the theme's fill as it is now
				holder.back:SetColorTexture(FILL[1], FILL[2], FILL[3], 0.92)
			end
		end
		holder.Follow = follow
		frame:HookScript("OnEnter", follow)
		frame:HookScript("OnLeave", follow)
		holder:SetScript("OnEnter", follow)
		holder:SetScript("OnLeave", follow)
	end
	holder:Hide()
	return true
end

-- ---------------------------------------------------------------------------
-- The line prefix
-- ---------------------------------------------------------------------------

-- "[1. General - Dun Morogh]" is thirty characters to say "this came from
-- General", and it is on EVERY line - so a third of the chat window is the
-- same three words repeated down the left-hand edge (Josh 2026-09-20).
--
-- The zone is the worst of it: you are standing in it. The number tells you
-- which channel far faster than the name does, and three letters is enough to
-- tell General from Trade from LookingForGroup.
--
-- This rewrites the TEXT of a line as it is added and nothing else. No message
-- is dropped, re-ordered or re-routed, and the link escapes inside it are left
-- exactly as they came.
local SHORT = {
	general = "Gen", trade = "Trd", localdefense = "Def", worlddefense = "Def",
	lookingforgroup = "LFG", guildrecruitment = "GR", services = "Svc",
	guild = "G", officer = "O", party = "P", raid = "R", instance = "I",
	["raid leader"] = "RL", ["party leader"] = "PL", ["raid warning"] = "RW",
}

local function abbreviate(name)
	local key = name:lower()
	if SHORT[key] then
		return SHORT[key]
	end
	-- anything we have not heard of: the first three letters of it, which is
	-- what the known ones are anyway
	return (name:gsub("%s", ""):sub(1, 3))
end
M.Abbreviate = abbreviate

local CHANNEL = "%[(%d+)%.%s*([^%]|]+)%]"
local function shortenChannel(n, rest)
	local name = rest:match("^(.-)%s+%-%s+") or rest
	return "[" .. n .. "." .. abbreviate(name) .. "]"
end

function M.Shorten(text)
	if type(text) ~= "string" then
		return text
	end
	-- A SECRET LINE IS LEFT ALONE (Josh 2026-09-22). A chat line that carries
	-- a secret value - one of our own prints of a nameplate's measurement -
	-- is a secret string: type() says string, and indexing it throws.
	if issecretvalue and issecretvalue(text) then
		return text
	end
	-- a numbered channel, with or without the zone hanging off it (no new
	-- functions per line: every line of chat passes through here)
	local ok, short = pcall(string.gsub, text, CHANNEL, shortenChannel)
	return ok and short or text
end

-- ---------------------------------------------------------------------------
-- All of them
-- The height every tab wears. Measured off the tallest word in the strip, once
-- per session: see styleTab.
function M.TabHeight(text)
	if text and text.GetStringHeight then
		local tall = BT.Pill.Number(text:GetStringHeight(), 0)
		if tall > 0 then
			local want = math.max(TAB_H, math.min(TAB_MAX, math.floor(tall) + TAB_PAD))
			if want > (M.tabHeight or 0) then
				M.tabHeight = want
			end
		end
	end
	return M.tabHeight or TAB_H
end

function M.ForgetTabHeight()
	M.tabHeight = nil
end

-- ---------------------------------------------------------------------------

-- EVERY WINDOW, THE POPPED-OUT ONES TOO (Josh 2026-09-23, audit): a whisper
-- opened in its own window is ChatFrame11 or later, past NUM_CHAT_WINDOWS,
-- and kept the client's look. The client's own list names them all.
function M.Frames()
	local out, seen = {}, {}
	local function add(frame)
		if type(frame) == "table" and not seen[frame] then
			seen[frame] = true
			out[#out + 1] = frame
		end
	end
	local n = BT.Pill.Number(_G.NUM_CHAT_WINDOWS, 10)
	for i = 1, n do
		add(_G["ChatFrame" .. i])
	end
	if type(_G.CHAT_FRAMES) == "table" then
		for _, name in ipairs(_G.CHAT_FRAMES) do
			add(_G[name])
		end
	end
	return out
end

-- THE TIME ON A LINE (Josh 2026-09-24), when asked for: the hour and minute,
-- quiet, in front - and not when the game's own timestamps are on already
function M.Stamp(text)
	if not opt("timestamps", false) or type(text) ~= "string" then
		return text
	end
	local game = type(GetCVar) == "function" and GetCVar("showTimestamps")
	if game and game ~= "none" and game ~= "" then
		return text
	end
	local ok, line = pcall(function()
		return "|cff6e7b75" .. date("%H:%M") .. "|r " .. text
	end)
	return ok and line or text
end

-- HOW BIG THE WORDS ARE (Josh 2026-09-24): the game's own size for each
-- window, set for all of them at once
function M.ApplySize()
	local size = opt("size", nil)
	if not size then
		return false
	end
	for _, frame in ipairs(M.Frames()) do
		if type(_G.FCF_SetChatWindowFontSize) == "function" then
			pcall(_G.FCF_SetChatWindowFontSize, nil, frame, size)
		elseif frame.GetFont and frame.SetFont then
			local face, _, flags = frame:GetFont()
			pcall(frame.SetFont, frame, face, size, flags)
		end
	end
	return true
end

-- The line rewriter goes on the frame's own AddMessage, which is the one
-- place every line passes through however it arrived.
function M.HookMessages(frame, plain)
	if not (frame and frame.AddMessage) then
		return false
	end
	if plain then
		if frame.beebsAdd then
			frame.AddMessage = frame.beebsAdd
			frame.beebsAdd = nil
		end
		return true
	end
	if frame.beebsAdd then
		return true
	end
	frame.beebsAdd = frame.AddMessage
	frame.AddMessage = function(self, text, ...)
		if BT.Enabled("chat") and opt("shortChannels", true) then
			text = M.Shorten(text)
		end
		-- guild names in green and web addresses you can click
		-- (Modules/Chat/Links.lua)
		if BT.Enabled("chat") and M.Decorate then
			text = M.Decorate(text)
		end
		if BT.Enabled("chat") then
			text = M.Stamp(text)
		end
		-- the line as the frame keeps it, so the large window can tell which
		-- end of the frame's history is the newest
		self.beebsLast = text
		local r1, r2, r3, r4 = frame.beebsAdd(self, text, ...)
		-- and a copy for the large window while it shows this frame
		local reader = BT.ChatReader
		if reader and reader.source == self and reader.Add then
			reader.Add(text, ...)
		end
		return r1, r2, r3, r4
	end
	return true
end

-- A TAB CLICK IS NOT A REQUEST TO TYPE (Josh 2026-09-20). With the edit box
-- over the tabs, clicking one to read a different window opened the box as
-- well - so choosing a tab put you in a text field you had not asked for. The
-- box belongs to Enter, and to nothing else.
function M.HookTab(tab, plain)
	if not (tab and tab.HookScript) then
		return false
	end
	if plain or tab.beebsTab then
		return true
	end
	tab.beebsTab = true
	tab:HookScript("OnClick", function()
		-- the lit one has changed
		if BT.Enabled("chat") then
			M.StyleAll()
		end
		if not (BT.Enabled("chat") and opt("editOnTop", true)) then
			return
		end
		local box = _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
		if box and box.HasFocus and not box:HasFocus() then
			if ChatEdit_DeactivateChat then
				pcall(ChatEdit_DeactivateChat, box)
			else
				box:Hide()
			end
		end
	end)
	return true
end

function M.StyleAll(plain)
	-- the manager is built the first time you open it, so this is worth
	-- another go rather than only at login
	if not plain then
		M.HookEditMode()
	end
	local n, tabHeight = 0, nil
	for _, frame in ipairs(M.Frames()) do
		local name = frame:GetName()
		styleFrame(frame, plain)
		styleTab(_G[name .. "Tab"], plain, _G.SELECTED_CHAT_FRAME == frame)
		tabHeight = BT.Pill.Number(_G[name .. "Tab"] and _G[name .. "Tab"].GetHeight
			and _G[name .. "Tab"]:GetHeight(), tabHeight)
		M.HookTab(_G[name .. "Tab"], plain)
		M.HookMessages(frame, plain)
		-- EACH SWITCH UNDOES ITS OWN PART (Josh 2026-09-23, audit): turning
		-- one off used to leave its work in place until a /reload - two sets
		-- of side buttons, the edit box still on top, the window still in the
		-- corner. Off is the plain form of each, as the module's off is.
		M.Controls(frame, plain or not opt("buttons", true))

		styleButtons(frame, plain)
		M.PlaceEditBox(_G[name .. "EditBox"], plain or not opt("editOnTop", true))
		-- only the first one: the rest are docked to it or placed by hand
		if name == "ChatFrame1" then
			M.Corner(frame, plain or not opt("flush", true))
		end
		n = n + 1
	end
	styleDock(plain, tabHeight)
	M.lastCount = n
	return n
end

-- THE CLIENT PUTS IT BACK (Josh 2026-09-20). ChatEdit_ActivateChat re-anchors
-- the edit box every time it opens, so ours has to go on after that rather
-- than once at login. Hooking the box's own OnShow is enough and costs nothing
-- the rest of the time.
function M.Watch()
	M.hooked = M.hooked or {}
	-- ONCE PER BOX, NOT ONCE EVER (Josh 2026-09-20). Remembering only that we
	-- had tried meant a call made before the client had built its chat frames
	-- hooked nothing and then refused to try again - the edit box stayed where
	-- the client put it for the whole session.
	local done = {}
	for _, box in ipairs(M.hooked) do
		done[box] = true
	end
	for _, frame in ipairs(M.Frames()) do
		local box = _G[frame:GetName() .. "EditBox"]
		if box and box.HookScript and not done[box] then
			M.hooked[#M.hooked + 1] = box
			box:HookScript("OnShow", function(self)
				if BT.Enabled("chat") and opt("editOnTop", true) then
					M.PlaceEditBox(self)
				end
			end)
			-- up while you type, down the moment you stop
			box:HookScript("OnEditFocusGained", function(self)
				if BT.Enabled("chat") and opt("editOnTop", true) then
					M.LiftEditBox(self, true)
				end
			end)
			box:HookScript("OnEditFocusLost", function(self)
				if BT.Enabled("chat") and opt("editOnTop", true) then
					M.LiftEditBox(self, false)
				end
			end)
		end
	end
	return M.hooked
end

-- AND AGAIN WHENEVER THE CLIENT REARRANGES (Josh 2026-09-20). Chat windows
-- are rebuilt when you dock or undock one, the HUD Edit Mode puts frames back
-- where its layout says when it closes, and a scale change re-lays out the
-- lot. Any of those undoes the corner, so it goes on again after each.
-- A TAB THAT DID NOT EXIST YET (Josh 2026-09-21). Making a new chat window
-- leaves it wearing the client's own tab: taller than ours, in its own
-- colours, sitting above the strip the others are in. Nothing was wrong with
-- the styling - it had simply never run on that tab, because the only passes
-- were at login and on events the client does not fire for this.
--
-- These are the functions that add, remove or re-dock a window. The
-- re-style waits a frame, because the client positions the new tab after its
-- own function returns.
function M.WatchWindows()
	if M.hookedWindows or not hooksecurefunc then
		return false
	end
	M.hookedWindows = true
	local function later()
		if not BT.Enabled("chat") then
			return
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if BT.Enabled("chat") then
					M.Watch()
					M.StyleAll()
				end
			end)
		else
			M.Watch()
			M.StyleAll()
		end
	end
	for _, fn in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow",
		"FCF_DockFrame", "FCF_UnDockFrame", "FCF_Close" }) do
		if type(_G[fn]) == "function" then
			pcall(hooksecurefunc, fn, later)
		end
	end
	return true
end

function M.WatchEvents()
	if M.events then
		return M.events
	end
	M.WatchWindows()
	M.events = CreateFrame("Frame")
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS",
		"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
	}) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	M.events:SetScript("OnEvent", function()
		if BT.Enabled("chat") then
			M.Watch()
			M.StyleAll()
		end
	end)
	return M.events
end

-- CANCEL IS NOT AN EVENT (Josh 2026-09-20). Saving a layout fires
-- EDIT_MODE_LAYOUTS_UPDATED and we catch it. Cancelling does not fire
-- anything: the manager simply puts every frame back where its layout said
-- and closes, which undoes the corner with nothing to tell us it happened.
--
-- So the manager's own closing is what we listen to, and the re-apply waits a
-- frame - the frames are moved back as it goes away, not before.
function M.HookEditMode()
	if M.editHooked then
		return true
	end
	local manager = _G.EditModeManagerFrame
	if not (manager and manager.HookScript) then
		return false
	end
	M.editHooked = true
	manager:HookScript("OnHide", function()
		if not BT.Enabled("chat") then
			return
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if BT.Enabled("chat") then
					M.StyleAll()
				end
			end)
		else
			M.StyleAll()
		end
	end)
	return true
end

function M:OnEnable()
	M.Watch()
	M.WatchEvents()
	M.HookEditMode()
	M.StyleAll()
end

-- and at login, not only when switched on
M.OnBind = M.OnEnable

function M:OnDisable()
	M.StyleAll(true)
	if BT.ChatReader then
		BT.ChatReader.Hide()
	end
	local copy = M.CopyBox and M.CopyBox()
	if copy then
		copy:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("BeebMod redraws the game's chat windows. It doesn't filter lines or move them to another window.")

	self.rows = {}
	local layout = page:Section("Layout")
	local function row(title, blurb, name, default)
		local r = BT.Widgets.SwitchRow(layout, title, blurb,
			function() return opt(name, default) and true or false end,
			function(on) setOpt(name, on) end)
		r.optName, r.default = name, default
		self.rows[#self.rows + 1] = r
	end
	row("Side buttons on hover", "The scroll and menu buttons show only while you point at chat",
		"buttons", true)
	row("Edit box on top", "The box you type in sits above the tabs, clear of the newest line", "editOnTop", true)
	row("Into the corner", "The main chat window sits in the bottom-left corner of the screen", "flush", true)
	row("Short channel names", "[1. General - Dun Morogh] becomes [1.Gen]", "shortChannels", true)
	row("Timestamps", "Puts the time in front of each new line. Off while the game's own timestamps are on.", "timestamps", false)
	row("Guild names in green", "A guild written in a line, such as <New Horizon>, turns guild green. Click it to get its /who in the chat box.", "guilds", true)
	row("Clickable links", "Click a web address in chat to get it in a box you can copy from", "links", true)
	local size = BT.Widgets.Row(page:Section("Text"), "Text size", "Sets the game's own text size for every chat window")
	local step = size:SetControl(BT.Widgets.Stepper(size, function(dir)
		local now = opt("size", 14) + dir
		now = math.max(10, math.min(20, now))
		BT.EnsureBound()
		BT.settings.chat = BT.settings.chat or {}
		BT.settings.chat.size = now
		M.ApplySize()
		self.sizeText:SetText(tostring(now))
	end))
	self.sizeText = step.value
	self.sizeText:SetText(tostring(opt("size", 14)))
	page:Layout()

	self.found = BT.Widgets.Label(panel, "", "small", 0.45, 0.50, 0.48)
	self.found:SetPoint("BOTTOMLEFT", 2, 4)
end

function M:RefreshTab()
	for _, r in ipairs(self.rows or {}) do
		r.switch:SetOn(opt(r.optName, r.default) and true or false)
	end
	if self.found then
		self.found:SetText(("%d chat windows redrawn"):format(M.lastCount or 0))
	end
end

function M:ShowTab()
	M.StyleAll()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- WHERE EACH TAB ACTUALLY IS (Josh 2026-09-21). A tab that will not line up
-- with the others has been guessed at twice. This says, per window, whether it
-- is docked, whether it is shown, and where its tab is anchored and how tall -
-- which is the difference between "it is a floating window, behaving normally"
-- and "our styling did not reach it". Into the saved file since 2026-09-28,
-- from the Testing page's Record button, like the other records.
function M.Dump()
	local lines = {}
	for _, frame in ipairs(M.Frames()) do
		local name = frame:GetName()
		local tab = _G[name .. "Tab"]
		local docked = frame.isDocked
		local at, x, y = "?", "?", "?"
		if tab and tab.GetPoint then
			local ok, point, rel, _, px, py = pcall(tab.GetPoint, tab, 1)
			if ok and point then
				at = tostring(point) .. " of "
					.. tostring((rel and rel.GetName and rel:GetName()) or rel or "?")
				x, y = tostring(px), tostring(py)
			end
		end
		lines[#lines + 1] = ("%s: %s, %s · tab %s (%s,%s) h=%s"):format(name,
			docked and "docked" or "FLOATING",
			frame:IsShown() and "shown" or "hidden",
			at, x, y,
			tostring(tab and tab.GetHeight and select(2, pcall(tab.GetHeight, tab))))
	end
	local function tall(f)
		return tostring(f and f.GetHeight and select(2, pcall(f.GetHeight, f)))
	end
	-- the strip a window you made sits in, which is centred on its own height
	lines[#lines + 1] = ("dock height %s, strip height %s, BeebMod's tab height %s"):format(
		tall(_G.GeneralDockManager), tall(_G.GeneralDockManagerScrollFrame),
		tostring(M.tabHeight))
	BT.EnsureBound()
	BeebModDB.chatDump = { at = U.Now(), lines = lines }
	return #lines
end

BT.Record("chatDump", M.Dump, "chat")
