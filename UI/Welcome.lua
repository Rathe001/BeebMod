-- WHICH FEATURES DO YOU WANT? (Josh 2026-09-27: "On startup we should ask
-- users which modules they want to enable.")
--
-- Six cards, one for each feature (BT.FEATURES): a picture of what it looks
-- like, a line on what it does, and its switch. Start switches the features
-- as the cards say - the same switches the settings rail has, so any of it
-- can be changed later. It replaced three presets (full, just the dock, the
-- census and notes, Josh 2026-09-25): a preset is a guess at what somebody
-- wants, and six switches with pictures are the question itself.
--
-- Asked once, a few seconds after the first loading screen: on a fresh
-- install, and once for an install from before there were features, its
-- cards set to what it already has on. Escape puts it off to the next login.
-- /bt setup, or "Choose again" on the General page, asks again.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Welcome.lua")

local U = BT.Util
local W = {}
BT.Welcome = W

-- asked, or not yet: an answer, or nothing at all to go on
function W.ShouldAsk()
	local s = BT.settings
	return s ~= nil and not s.featuresAsked
end

-- the cards' switches, as they stand; set from the features when it opens
W.picks = {}

function W.Pick(key, on)
	W.picks[key] = on and true or false
	W.Paint()
end

-- every feature as its card says, and the question answered
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
	BT.settings.setup = "features"
	if BT.Window and BT.Window.Rebuild then
		pcall(BT.Window.Rebuild)
	end
	if BT.Bar and BT.Bar.Relayout then
		pcall(BT.Bar.Relayout)
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local frame
local PAD, GAP, COLS = 18, 10, 3
local CARD_W = 236
local PIC_H = math.floor(CARD_W * 9 / 16 + 0.5)
local CARD_H = PIC_H + 12 + 22 + 44
local WIDTH = PAD * 2 + COLS * CARD_W + (COLS - 1) * GAP

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- the cards as the picks say: lit and switched on, or quiet
function W.Paint()
	if not frame then
		return
	end
	for _, card in ipairs(frame.cards) do
		local on = W.picks[card.key] ~= false
		card.switch:SetOn(on)
		local c = card.feature.color
		BT.Pill.Recolour(card, on and { c[1] * 0.16, c[2] * 0.16, c[3] * 0.16, 0.95 } or { 0.06, 0.07, 0.07, 0.95 },
			on and { c[1], c[2], c[3], 0.7 } or BT.Widgets.HAIR)
		card.title:SetTextColor(on and 0.93 or 0.50, on and 0.95 or 0.54, on and 0.93 or 0.52)
		card.picture:SetAlpha(on and 1 or 0.35)
	end
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
		U.Print("BeebMod · set up after this fight")
	else
		W.Apply(picks)
	end
	if frame then
		frame:Hide()
	end
	U.Print("BeebMod · change any of it with /bt, or the cog on the dock")
end
W.Start = start

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
	Wd.Panel(frame, Wd.SOLID)
	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD, -PAD)
	frame.title:SetText("Welcome to |cff74c0fcBeeb|rMod")
	frame.question = Wd.Label(frame, "Pick what you want · all of it can change later", "small", 0.50, 0.55, 0.53)
	frame.question:SetPoint("LEFT", frame.title, "RIGHT", 10, -1)
	Wd.Divider(frame, PAD, -PAD - 26)
	frame.cards = {}
	local top = PAD + 36
	for i, f in ipairs(BT.FEATURES) do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local card = CreateFrame("Button", nil, frame)
		card:SetSize(CARD_W, CARD_H)
		card:SetPoint("TOPLEFT", PAD + col * (CARD_W + GAP), -(top + row * (CARD_H + GAP)))
		BT.Pill.Panel(card, { 0.06, 0.07, 0.07, 0.95 }, Wd.HAIR)
		card.key, card.feature = f.key, f
		card.picture = BT.Window.Picture(card, f, CARD_W - 12, PIC_H - 6)
		card.picture:SetPoint("TOPLEFT", 6, -6)
		card.title = card:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
		card.title:SetPoint("TOPLEFT", 8, -(PIC_H + 8))
		card.title:SetText(f.title)
		card.switch = Wd.Switch(card, function(on)
			W.Pick(f.key, on)
		end)
		card.switch:SetPoint("TOPRIGHT", -6, -(PIC_H + 4))
		card.line = Wd.Label(card, f.line, "small", 0.62, 0.68, 0.65)
		card.line:SetPoint("TOPLEFT", 8, -(PIC_H + 30))
		card.line:SetPoint("RIGHT", card, "RIGHT", -8, 0)
		card.line:SetJustifyH("LEFT")
		card.line:SetJustifyV("TOP")
		card.line:SetWordWrap(true)
		-- a click anywhere on the card is a click on its switch
		card:SetScript("OnClick", function()
			W.Pick(f.key, W.picks[f.key] == false)
		end)
		frame.cards[#frame.cards + 1] = card
	end
	local y = top + 2 * CARD_H + GAP + 12
	frame.foot = Wd.Label(frame, "The dock's logo and cog always stay, so you can find your way back · /bt", "small", 0.50, 0.55, 0.53)
	frame.foot:SetPoint("TOPLEFT", PAD, -(y + 5))
	frame.start = Wd.Button(frame, "Start", 72, 22)
	frame.start:SetPoint("TOPRIGHT", -PAD, -y)
	frame.start:SetScript("OnClick", start)
	frame.none = Wd.Button(frame, "None", 56, 22)
	frame.none:SetPoint("RIGHT", frame.start, "LEFT", -6, 0)
	frame.none:SetScript("OnClick", function()
		for _, f in ipairs(BT.FEATURES) do
			W.picks[f.key] = false
		end
		W.Paint()
	end)
	frame.all = Wd.Button(frame, "All", 56, 22)
	frame.all:SetPoint("RIGHT", frame.none, "LEFT", -6, 0)
	frame.all:SetScript("OnClick", function()
		for _, f in ipairs(BT.FEATURES) do
			W.picks[f.key] = true
		end
		W.Paint()
	end)
	frame:SetSize(WIDTH, y + 22 + PAD)
	frame:SetPoint("CENTER", 0, 40)
	-- Escape puts it off to the next login rather than choosing for you
	tinsert(UISpecialFrames, "BeebModWelcome")
	frame:Hide()
	return frame
end

-- open, its cards set to what is on now
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

BT.Command("setup", function()
	W.Show()
end, "choose again which features BeebMod uses")
