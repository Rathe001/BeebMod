-- WHICH FEATURES DO YOU WANT? (Josh 2026-09-27: "On startup we should ask
-- users which modules they want to enable.")
--
-- A LIST, AND THE ONE YOU CLICK IN PICTURES (Josh 2026-10-18: "Our current
-- screen is out of date (still uses the ledger and expedition quotes), and
-- doesn't feel very professional", then of three designs, "For the start
-- screen, I like option C"). Down the left, the five features (BT.FEATURES)
-- under the settings rail's two headings: a square in each one's colour, its
-- name, a few words on it, and its switch. Click a row and the right side
-- shows that feature: its pictures one at a time with a caption under each,
-- then a line on what it is and six things it adds. A click on a row only
-- shows it. Its switch is what picks it.
-- NOT WHAT STAYS WHEN IT IS OFF (Josh 2026-10-18: "It is self explainatory
-- what will happen if you turn off a module"). The Ledger's line says its
-- records never leave your computer, which its "Off:" line used to.
--
-- Start switches the features as the switches say. They are the same
-- switches the settings rail has, so any of it can be changed later. This
-- window replaced five cards with pictures (2026-10-04), which replaced
-- three presets (full, just the dock, the census and notes, Josh
-- 2026-09-25): a preset is a guess at what somebody wants, and five switches
-- are the question itself.
--
-- Asked once, a few seconds after the first loading screen: on a fresh
-- install, and once for an install from before there were features, its
-- switches set to what it already has on. Escape puts it off to the next
-- login. First login on the Testing page shows it again (/bt setup did too,
-- until the commands went on 2026-10-18: Core/Slash.lua).
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Welcome.lua")

local U = BT.Util
local W = {}
BT.Welcome = W

-- ---------------------------------------------------------------------------
-- What the window says about each feature
-- ---------------------------------------------------------------------------
--
-- ITS OWN WORDS (the design, 2026-10-18). BT.FEATURES keeps what the settings
-- pages show (`line`, and a journal's `blurb`, `quote` and `by`). The first
-- login says what each feature does here: a few words for its row (`tag`), a
-- line, and six things it adds (`adds`, two to a row).
--
-- THE SLIDES, AND HOW TO ADD ONE. Each feature's pictures, in the order they
-- show, each with the caption under it. A picture is a 512x256 BLP in
-- Art/Features with the picture itself in its left 455 (ART_U, below);
-- scripts/make-feature-art.ps1 makes them from screenshots. To add one, put
-- the file in Art/Features and add a line to the feature's `slides` with its
-- path, written out whole, and its caption. With two or more, the arrows and
-- the dots show by themselves. List only files that are in the folder: the
-- client cannot tell an addon whether a file exists, and a missing one draws
-- nothing. (tests/load.lua fails on a path in the source that names no file,
-- which is why each is written out.) A new file needs the game restarted,
-- because a /reload does not find new files.
--
-- THE PICTURES (Josh's screenshots, 2026-10-18): four for each interface
-- feature, and the journals' a new rank's toast as well, made by
-- scripts/make-feature-art.ps1, which also keeps each one full size in
-- docs/screens for the CurseForge page. Each is a BLP, DXT1-compressed, 65
-- KB where a TGA was 384: dock2 was made one first, to see the client draws
-- it (Josh: "Dock slide 2 seems ok").
W.ABOUT = {
	dock = {
		tag = "Map, experience, quests and readouts",
		line = "A panel at the side of the screen with your map, experience, quests and readouts.",
		adds = { "The minimap, square, with your coordinates", "Level, XP to go and time to level",
			"Your quests by zone, lowest level first", "Gold, bags, durability and item level",
			"Frame rate and latency", "PvP rank and the faction you watch" },
		slides = {
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\dock1", caption = "The dock beside the game" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\dock2", caption = "Experience: time to level, and where to go" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\dock3", caption = "Your quests by zone" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\dock4", caption = "Readouts, each with a tooltip" },
		},
	},
	unitframes = {
		tag = "Group, target and nameplates",
		line = "Frames for you, your group and your target, and nameplates, in one look.",
		adds = { "Party and raid, with pets and targets", "Target, focus and boss frames",
			"Nameplates with casts to interrupt", "Buffs and debuffs beside the dock",
			"A flat resource bar", "Combo points under it" },
		slides = {
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\unitframes1", caption = "Your party, your target and nameplates" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\unitframes2", caption = "Nameplates, with your damage over time" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\unitframes3", caption = "Raid frames" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\unitframes4", caption = "Buffs beside the dock, and your resource bar" },
		},
	},
	interface = {
		tag = "Bars, bags, chat, tooltips and menus",
		line = "The game's own bars, bags, chat, tooltips and menus, drawn to match.",
		adds = { "Action bars and the game menu", "One bag window you can drag",
			"Item and spell tooltips with their DPS", "Item level on the character sheet",
			"Guild names in chat you can click", "Every dropdown and right-click menu" },
		slides = {
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\interface1", caption = "One bag window" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\interface2", caption = "Item tooltips, beside the item you have on" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\interface3", caption = "Spell tooltips, with DPS and cost" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\interface4", caption = "Item level on the character sheet" },
		},
	},
	ledger = {
		tag = "Everyone you see, and your notes",
		line = "A record of everyone you see, with your notes, tags and ratings. It never leaves your computer.",
		adds = { "Charts of your realm", "Find anyone by name or guild",
			"Notes and tags from the right-click menu", "Groups and duel scores",
			"Commendations and points", "Ranks up to Eye of Ravenholdt" },
		slides = {
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\ledger1", caption = "Your realm in charts" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\ledger2", caption = "Find anyone, with your notes" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\ledger3", caption = "Your note on their tooltip" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\ledger4", caption = "Commendations and ranks" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\ledger5", caption = "A new rank" },
		},
	},
	expedition = {
		tag = "Every enemy you kill",
		line = "A journal of every enemy you kill, with its model, lore and where you found it.",
		adds = { "A page for each enemy", "A map of where you killed it",
			"Masteries, Bronze to Platinum", "Commendations for rares and elites",
			"Points for each unique kill", "Ranks up to Expedition Leader" },
		slides = {
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\expedition1", caption = "A page for every enemy" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\expedition2", caption = "What it casts, and what that does" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\expedition3", caption = "Every enemy you've killed" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\expedition4", caption = "Commendations" },
			{ file = "Interface\\AddOns\\BeebMod\\Art\\Features\\expedition5", caption = "A new rank" },
		},
	},
}

-- asked, or not yet: an answer, or nothing at all to go on
function W.ShouldAsk()
	local s = BT.settings
	return s ~= nil and not s.featuresAsked
end

-- the switches, as they stand; set from the features when it opens
W.picks = {}
-- the feature shown on the right (the first until you click another), and
-- the slide each feature is on
W.selected = nil
W.slideAt = {}

function W.Pick(key, on)
	W.picks[key] = on and true or false
	W.Paint()
end

function W.Select(key)
	if BT.Feature(key) then
		W.selected = key
	end
	W.Paint()
end

-- every switch on, or every one off
function W.SetAll(on)
	for _, f in ipairs(BT.FEATURES) do
		W.picks[f.key] = on and true or false
	end
	W.Paint()
end

-- how many of the switches are on
function W.OnCount()
	local n = 0
	for _, f in ipairs(BT.FEATURES) do
		if W.picks[f.key] ~= false then
			n = n + 1
		end
	end
	return n
end

function W.Slides(key)
	local about = W.ABOUT[key]
	return about and about.slides or {}
end

-- the slide a feature is on: the first, or 0 with none
function W.SlideIndex(key)
	local n = #W.Slides(key)
	local i = W.slideAt[key] or 1
	if n == 0 then
		return 0
	end
	-- (a slide taken out of the list since: back to the first)
	if i < 1 or i > n then
		i = 1
	end
	return i
end

-- the next slide (step 1) or the one before (step -1), round from the last
-- to the first
function W.Step(step)
	local key = W.selected
	local n = #W.Slides(key)
	if n < 2 then
		return
	end
	W.slideAt[key] = (W.SlideIndex(key) - 1 + step) % n + 1
	W.Paint()
end

-- a slide by its dot
function W.GoTo(i)
	local key = W.selected
	if i >= 1 and i <= #W.Slides(key) then
		W.slideAt[key] = i
	end
	W.Paint()
end

-- every feature as its switch says, and the question answered
function W.Apply(picks)
	BT.EnsureBound()
	picks = picks or W.picks
	for _, f in ipairs(BT.FEATURES) do
		local want = picks[f.key] ~= false
		-- a one-page feature asks its module too: on here is on
		local now = BT.FeatureOn(f.key) and (not f.single or BT.Switched(f.single))
		if want ~= now then
			BT.SetFeature(f.key, want)
		end
	end
	BT.settings.featuresAsked = true
	if BT.Window and BT.Window.Rebuild then
		pcall(BT.Window.Rebuild)
	end
	if BT.Dock and BT.Dock.Relayout then
		pcall(BT.Dock.Relayout)
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
--
-- THE SIZES. The design is drawn at about 120% of the game's size, so each
-- of its sizes is divided by 1.2 and rounded to the house's: a list 256
-- wide, a 16:9 picture 432 by 243 beside it, 765 by 569 in all (the old
-- cards were 764 wide, the settings window is 760). The fonts are the
-- house's three sizes (Core/Fonts.lua): 15 for the names at the top of each
-- side, 12 for a feature's name in the list and its line, 10 for the rest.

local frame
local PAD, TOP = 20, 18
local HEAD_H, GAP = 34, 14
local LIST_W, SPLIT = 256, 18
local PIC_W, PIC_H = 432, 243
-- a row of the list, the space between two, and a group's heading
local ROW_H, ROW_GAP, GROUP_H = 46, 5, 19
-- the right side's height: the picture and everything under it, with room
-- for the line and the note to take two lines each
local BODY_H = 432
local BUTTON_H = 24
local WIDTH = PAD * 2 + LIST_W + SPLIT * 2 + 1 + PIC_W
local HEIGHT = TOP * 2 + HEAD_H + GAP * 3 + 1 + BODY_H + BUTTON_H
-- the six things a feature adds, two to a row
local COL_GAP, ADD_GAP = 15, 5
local COL_W = math.floor((PIC_W - COL_GAP) / 2)
-- where a row's name and tag start, and how wide they may run before its switch
local TEXT_X = 24
local TEXT_W = LIST_W - TEXT_X - 8 - 34 - 8
-- the picture is the left 455 of a 512-wide texture (a power of two each
-- way): scripts/make-feature-art.ps1
local ART_U = 455 / 512

-- the design's colours
local WELL = { 0.05, 0.075, 0.067, 0.95 }
local GREY = { 0.49, 0.55, 0.53 }
local SOFT = { 0.73, 0.78, 0.76 }
local BRIGHT = { 0.93, 0.95, 0.94 }
-- a square while its feature is off (the settings rail's), an add's, and a dot
local OFF_SQUARE = { 0.23, 0.27, 0.25 }
local OFF_ADD = { 0.29, 0.35, 0.33 }
local DOT = { 0.16, 0.22, 0.20 }
-- the arrows over the picture
local ARROW_FILL = { 0.04, 0.06, 0.05, 0.82 }
local ARROW_RIM = { 0.20, 0.27, 0.25, 1 }

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- a row of the list: lit and rimmed in its colour while it is the one shown
local function paintRow(row)
	local Wd = BT.Widgets
	local c = row.feature.color
	local on = W.picks[row.key] ~= false
	local shown = W.selected == row.key
	local rim = shown and { c[1], c[2], c[3], 0.6 } or (row.hot and Wd.RIM or Wd.HAIR)
	BT.Pill.Recolour(row, shown and { c[1], c[2], c[3], 0.09 } or WELL, rim)
	local sq = on and c or OFF_SQUARE
	row.square:SetColorTexture(sq[1], sq[2], sq[3], 1)
	local t = on and BRIGHT or GREY
	row.title:SetTextColor(t[1], t[2], t[3])
	row.switch:SetOn(on)
end

local function makeRow(parent, f)
	local Wd = BT.Widgets
	local about = W.ABOUT[f.key] or {}
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(LIST_W, ROW_H)
	BT.Pill.Panel(row, WELL, Wd.HAIR)
	row.key, row.feature = f.key, f
	row.square = row:CreateTexture(nil, "ARTWORK")
	row.square:SetSize(6, 6)
	row.square:SetPoint("TOPLEFT", 11, -14)
	row.title = row:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	row.title:SetPoint("TOPLEFT", TEXT_X, -9)
	row.title:SetWidth(TEXT_W)
	row.title:SetJustifyH("LEFT")
	row.title:SetWordWrap(false)
	row.title:SetText(f.title)
	row.tag = Wd.Label(row, about.tag or "", "small", GREY[1], GREY[2], GREY[3])
	row.tag:SetPoint("TOPLEFT", TEXT_X, -26)
	row.tag:SetWidth(TEXT_W)
	row.tag:SetJustifyH("LEFT")
	row.tag:SetWordWrap(false)
	-- the switch picks; a click anywhere else on the row only shows it
	row.switch = Wd.Switch(row, function(on)
		W.Pick(f.key, on)
	end)
	row.switch:SetPoint("RIGHT", -8, 0)
	row:SetScript("OnClick", function()
		W.Select(f.key)
	end)
	row:SetScript("OnEnter", function(self)
		self.hot = true
		paintRow(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hot = false
		paintRow(self)
	end)
	return row
end

-- an arrow over the picture's edge: the dock's chevron, which points down,
-- turned a quarter to point left (step -1) or right (step 1)
local function makeArrow(parent, step)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	BT.Pill.Panel(b, ARROW_FILL, ARROW_RIM)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(10, 10)
	b.icon:SetPoint("CENTER")
	b.icon:SetTexture(BT.Dock.ICONS)
	-- the chevron's slot is 0.625 to 0.75 across the sheet; each corner of
	-- the icon is given the slot's corner that turns it the right way
	if step < 0 then
		b.icon:SetTexCoord(0.625, 1, 0.75, 1, 0.625, 0, 0.75, 0)
	else
		b.icon:SetTexCoord(0.75, 0, 0.625, 0, 0.75, 1, 0.625, 1)
	end
	b.icon:SetVertexColor(BRIGHT[1], BRIGHT[2], BRIGHT[3], 1)
	b:SetScript("OnClick", function()
		W.Step(step)
	end)
	b:SetScript("OnEnter", function(self)
		local a = BT.Widgets.ACCENT
		self.icon:SetVertexColor(a[1], a[2], a[3], 1)
	end)
	b:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(BRIGHT[1], BRIGHT[2], BRIGHT[3], 1)
	end)
	return b
end

-- a slide's dot, made the first time a feature has that many slides
local function dotAt(d, i)
	local b = d.dots[i]
	if b then
		return b
	end
	b = CreateFrame("Button", nil, d.dotRow)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("LEFT", 0, 0)
	b.bar:SetPoint("RIGHT", 0, 0)
	b.bar:SetHeight(6)
	b:SetScript("OnClick", function()
		W.GoTo(i)
	end)
	d.dots[i] = b
	return b
end

-- the six things a feature adds, two to a row: a row as tall as the taller
-- of its two, since a long one wraps
local function layoutAdds(box, adds, colour)
	for i = #box.items + 1, #adds do
		local item = {}
		item.square = box:CreateTexture(nil, "ARTWORK")
		item.square:SetSize(4, 4)
		item.text = BT.Widgets.Label(box, "", "small", 0.79, 0.83, 0.81)
		item.text:SetWidth(COL_W - 10)
		item.text:SetJustifyH("LEFT")
		item.text:SetWordWrap(true)
		box.items[i] = item
	end
	local y, rowH = 0, 0
	for i, item in ipairs(box.items) do
		local text = adds[i]
		item.text:SetShown(text ~= nil)
		item.square:SetShown(text ~= nil)
		if text then
			local left = i % 2 == 1
			if left and i > 1 then
				y, rowH = y + rowH + ADD_GAP, 0
			end
			local x = left and 0 or (COL_W + COL_GAP)
			item.text:SetText(text)
			item.text:ClearAllPoints()
			item.text:SetPoint("TOPLEFT", x + 10, -y)
			item.square:ClearAllPoints()
			item.square:SetPoint("TOPLEFT", x, -(y + 4))
			item.square:SetColorTexture(colour[1], colour[2], colour[3], 1)
			rowH = math.max(rowH, BT.Pill.Number(item.text:GetStringHeight(), 12))
		end
	end
	box:SetHeight(math.max(1, y + rowH))
end

-- the right side: the shown feature's slide, and what it is
local function paintDetail()
	local d = frame.detail
	local key = W.selected
	local f = BT.Feature(key)
	local about = W.ABOUT[key] or {}
	local on = W.picks[key] ~= false
	local c = f.color
	local slides = W.Slides(key)
	local n, at = #slides, W.SlideIndex(key)
	local slide = slides[at]
	-- the picture, faded and grey while the feature is off
	local art = d.pic.art
	if slide then
		art:SetTexture(slide.file)
		art:SetTexCoord(0, ART_U, 0, 1)
		art:Show()
	else
		art:Hide()
	end
	art:SetAlpha(on and 1 or 0.4)
	art:SetDesaturated(not on)
	-- a one-pixel rim in the feature's colour, drawn over the picture's edge
	-- and measured again each time, as the interface scale may have changed
	BT.Pill.PlaceRing(d.pic.rim, d.pic, 0, 1, 0)
	BT.Pill.PaintRing(d.pic.rim, { c[1], c[2], c[3], on and 0.55 or 0.2 })
	d.caption:SetText(slide and slide.caption or "")
	-- ONE SLIDE, NO ARROWS OR DOTS: they show from two, and the caption always
	local many = n > 1
	d.prev:SetShown(many)
	d.next:SetShown(many)
	-- the dots from the right, the current one wider and in the feature's colour
	local right = 0
	for i = n, 1, -1 do
		local b = dotAt(d, i)
		local w = (i == at) and 15 or 6
		local dc = (i == at) and c or DOT
		b:SetSize(w, 14)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", d.dotRow, "RIGHT", -right, 0)
		b.bar:SetColorTexture(dc[1], dc[2], dc[3], 1)
		b:SetShown(many)
		right = right + w + 5
	end
	for i = n + 1, #d.dots do
		d.dots[i]:Hide()
	end
	d.title:SetText(f.title)
	d.state:SetText(on and "On" or "Off")
	local sc = on and c or GREY
	d.state:SetTextColor(sc[1], sc[2], sc[3])
	d.line:SetText(about.line or "")
	layoutAdds(d.adds, about.adds or {}, on and c or OFF_ADD)
end

-- the list and the right side as the switches and the selection say
function W.Paint()
	if not frame then
		return
	end
	if not BT.Feature(W.selected or "") then
		W.selected = BT.FEATURES[1] and BT.FEATURES[1].key
	end
	for _, row in ipairs(frame.rows) do
		paintRow(row)
	end
	frame.count:SetText(("%d of %d on"):format(W.OnCount(), #BT.FEATURES))
	if W.selected then
		paintDetail()
	end
end

-- (the switches and the Start button wear the accent: a new theme repaints them)
if BT.Theme and BT.Theme.Register then
	BT.Theme.Register(function()
		W.Paint()
	end)
end

local function start()
	-- a fight: switching the frames now would be refused; after it, then
	local picks = {}
	for k, v in pairs(W.picks) do
		picks[k] = v
	end
	if inCombat() then
		W.pending = picks
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			if W.pending then
				W.Apply(W.pending)
				W.pending = nil
			end
		end)
		U.Print("Your choices take effect when this fight ends.")
	else
		W.Apply(picks)
	end
	if frame then
		frame:Hide()
	end
	-- (Josh 2026-10-18: the old line "sounds very AI")
	U.Print("Enable or disable modules in the settings panel.")
end
W.Start = start

-- Start is the one button in the accent, with dark words on it
local function paintStart(b)
	local Wd = BT.Widgets
	BT.Pill.Recolour(b, Wd.ACCENT, b.hovered and Wd.KNOB or Wd.ACCENT)
	b.label:SetTextColor(0.03, 0.06, 0.05)
end

function W.Build()
	if frame then
		return frame
	end
	local Wd = BT.Widgets
	frame = CreateFrame("Frame", "BeebModWelcome", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 0, 40)
	Wd.Panel(frame, Wd.SOLID)

	-- the header: the title, the question under it, and how many are on
	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	frame.title:SetPoint("TOPLEFT", PAD, -TOP)
	frame.title:SetTextColor(0.91, 0.93, 0.92)
	frame.title:SetText("Welcome to |cff74c0fcBeeb|rMod")
	frame.question = Wd.Label(frame, "Pick the parts you want. Click one to see what it does.", "small",
		0.60, 0.66, 0.64)
	frame.question:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", PAD, -(TOP + HEAD_H))
	frame.count = Wd.Label(frame, "", "small", GREY[1], GREY[2], GREY[3])
	frame.count:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -(TOP + HEAD_H))

	-- the list, under the rail's headings (UI/Window.lua, W.GROUPS)
	local bodyTop = TOP + HEAD_H + GAP
	local list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", PAD, -bodyTop)
	list:SetSize(LIST_W, BODY_H)
	frame.list = list
	frame.rows, frame.heads = {}, {}
	local y = 0
	for _, g in ipairs(BT.Window.GROUPS) do
		local head = Wd.Label(list, string.upper(g.title), "small", GREY[1], GREY[2], GREY[3])
		head:SetPoint("TOPLEFT", 2, -(y + 7))
		frame.heads[#frame.heads + 1] = head
		y = y + GROUP_H + ROW_GAP
		for _, fkey in ipairs(BT.Window.GroupKeys(g.key)) do
			local row = makeRow(list, BT.Feature(fkey))
			row:SetPoint("TOPLEFT", 0, -y)
			frame.rows[#frame.rows + 1] = row
			y = y + ROW_H + ROW_GAP
		end
	end

	local seam = frame:CreateTexture(nil, "ARTWORK")
	seam:SetPoint("TOPLEFT", PAD + LIST_W + SPLIT, -bodyTop)
	seam:SetSize(1, BODY_H)
	Wd.Rule(seam, 0.5, "v")

	-- the right side, top to bottom
	local d = CreateFrame("Frame", nil, frame)
	d:SetPoint("TOPLEFT", PAD + LIST_W + SPLIT * 2 + 1, -bodyTop)
	d:SetSize(PIC_W, BODY_H)
	frame.detail = d
	local pic = CreateFrame("Frame", nil, d)
	pic:SetSize(PIC_W, PIC_H)
	pic:SetPoint("TOPLEFT", 0, 0)
	pic.fill = pic:CreateTexture(nil, "BACKGROUND")
	pic.fill:SetAllPoints()
	pic.fill:SetColorTexture(WELL[1], WELL[2], WELL[3], 1)
	pic.art = pic:CreateTexture(nil, "ARTWORK")
	pic.art:SetAllPoints()
	-- a square rim: the picture's corners are square, so a rounded panel's
	-- would leave them poking out
	pic.rim = BT.Pill.Ring(pic, "OVERLAY", 2)
	d.pic = pic
	d.prev = makeArrow(pic, -1)
	d.prev:SetPoint("LEFT", 7, 0)
	d.next = makeArrow(pic, 1)
	d.next:SetPoint("RIGHT", -7, 0)
	d.caption = Wd.Label(d, "", "small", SOFT[1], SOFT[2], SOFT[3])
	d.caption:SetPoint("TOPLEFT", pic, "BOTTOMLEFT", 0, -8)
	d.caption:SetWidth(PIC_W - 80)
	d.caption:SetJustifyH("LEFT")
	d.caption:SetWordWrap(false)
	d.dotRow = CreateFrame("Frame", nil, d)
	d.dotRow:SetPoint("TOPRIGHT", pic, "BOTTOMRIGHT", 0, -7)
	d.dotRow:SetSize(80, 14)
	d.dots = {}
	d.title = d:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightLarge")
	d.title:SetPoint("TOPLEFT", pic, "BOTTOMLEFT", 0, -30)
	d.title:SetTextColor(BRIGHT[1], BRIGHT[2], BRIGHT[3])
	-- On or Off at the right, level with the name
	d.state = Wd.Label(d, "", "small")
	d.state:SetPoint("RIGHT", d, "TOPRIGHT", 0, -(PIC_H + 30 + 9))
	d.line = d:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	d.line:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6)
	d.line:SetWidth(PIC_W)
	d.line:SetJustifyH("LEFT")
	d.line:SetWordWrap(true)
	d.line:SetTextColor(SOFT[1], SOFT[2], SOFT[3])
	d.adds = CreateFrame("Frame", nil, d)
	d.adds:SetPoint("TOPLEFT", d.line, "BOTTOMLEFT", 0, -9)
	d.adds:SetSize(PIC_W, 1)
	d.adds.items = {}

	-- the foot: a rule, the note, and the buttons
	Wd.Divider(frame, PAD, -(bodyTop + BODY_H + GAP))
	frame.start = Wd.Button(frame, "Start", 84, BUTTON_H)
	frame.start:SetPoint("BOTTOMRIGHT", -PAD, TOP)
	frame.start:SetScript("OnClick", start)
	frame.start:SetScript("OnEnter", function(self)
		self.hovered = true
		paintStart(self)
	end)
	frame.start:SetScript("OnLeave", function(self)
		self.hovered = false
		paintStart(self)
	end)
	paintStart(frame.start)
	frame.allOff = Wd.Button(frame, "All off", 64, BUTTON_H)
	frame.allOff:SetPoint("RIGHT", frame.start, "LEFT", -7, 0)
	frame.allOff:SetScript("OnClick", function()
		W.SetAll(false)
	end)
	frame.allOn = Wd.Button(frame, "All on", 64, BUTTON_H)
	frame.allOn:SetPoint("RIGHT", frame.allOff, "LEFT", -7, 0)
	frame.allOn:SetScript("OnClick", function()
		W.SetAll(true)
	end)
	frame.foot = Wd.Label(frame, "The dock's logo and cog always stay. Click the cog to open the settings.", "small",
		GREY[1], GREY[2], GREY[3])
	frame.foot:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD, TOP + BUTTON_H / 2)

	-- Escape puts it off to the next login rather than choosing for you
	tinsert(UISpecialFrames, "BeebModWelcome")
	frame:Hide()
	return frame
end

-- open, its switches set to what is on now
function W.Show()
	BT.EnsureBound()
	W.Build()
	for _, f in ipairs(BT.FEATURES) do
		W.picks[f.key] = BT.FeatureOn(f.key) and (not f.single or BT.Switched(f.single))
	end
	W.Paint()
	frame:Show()
	frame:Raise()
	return frame
end

function W.Frame()
	return frame
end

-- asked a few seconds after the first loading screen, out of combat
local watch = CreateFrame("Frame")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		local function ask()
			if not W.ShouldAsk() then
				return
			end
			if inCombat() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED")
				return
			end
			W.Show()
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(4, ask)
		else
			ask()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if W.ShouldAsk() then
			W.Show()
		end
	end
end)
