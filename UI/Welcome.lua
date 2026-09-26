-- HOW MUCH SHOULD IT CHANGE? (Josh 2026-09-25: "When the player first logs in
-- after installing the addon, can we present them with 3 options? The full UI,
-- just the dock, or census only? Many of my friends don't like using addons,
-- so they probably don't want dramatic UI rewrites. Going through the settings
-- and turning everything off manually is annoying.")
--
-- The first login after installing asks once, in a small window of its own,
-- and each answer is only a set of module switches - the same ones the
-- settings have, so anything can be changed back one at a time later:
--
--   full      everything
--   dock      the dock and what is on it, and the census and your notes; the
--             unit frames, buffs, meter, bars, bags, sheet, chat, menus and
--             tooltips stay the game's
--   census    the census and your notes (Josh: "they kind of go hand in hand
--             I think, and are non-intrusive") and nothing else - the game's
--             own interface, untouched
--
-- An install that already has its modules set is not asked: somebody who
-- has been choosing switches has made their choice. /bt setup, or the button
-- on the General page, asks again.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Welcome.lua")

local U = BT.Util
local W = {}
BT.Welcome = W

W.CHOICES = {
	{ key = "full", title = "Full",
		blurb = "The whole thing: the dock, unit frames, bars, bags, chat and tooltips, all in one look." },
	{ key = "dock", title = "Just the dock",
		blurb = "One panel at the side with your map, quests, XP and the numbers you check. The rest stays as the game made it." },
	{ key = "census", title = "Census and notes",
		blurb = "Your interface stays exactly as it is. BeebMod quietly keeps the census and your notes on people, from a small button." },
}

-- which group a module is in, for the choices: a part goes with its owner,
-- and the clock lives on the Dock's page
local function groupOf(m)
	if m.part then
		local owner = BT.GetModule(m.part)
		return owner and groupOf(owner) or nil
	end
	if m.key == "clock" then
		return "dock"
	end
	return m.group
end
W.GroupOf = groupOf

-- whether a choice keeps a module on
function W.Keeps(choice, m)
	if choice == "full" then
		return true
	end
	local g = groupOf(m)
	if choice == "dock" then
		return g == "dock" or g == "people"
	end
	-- census: the census and the ledger, and nothing that belongs to anything
	-- else - the Ledger's own readout is a part of the Metrics
	return (m.key == "census" or m.key == "ledger") and not m.part
end

-- the switches for a choice, thrown all at once; a part keeps its own switch
-- and follows its owner, so it is only switched on (never off) here
function W.Apply(choice)
	if not (choice == "full" or choice == "dock" or choice == "census") then
		return false
	end
	BT.EnsureBound()
	for _, m in ipairs(BT.Modules()) do
		local on = W.Keeps(choice, m)
		if m.part then
			if on and not BT.Switched(m.key) then
				BT.SetEnabled(m.key, true)
			end
		elseif BT.Switched(m.key) ~= on then
			BT.SetEnabled(m.key, on)
		end
	end
	BT.settings.setup = choice
	if BT.Window and BT.Window.Rebuild then
		pcall(BT.Window.Rebuild)
	end
	if BT.Bar and BT.Bar.Relayout then
		pcall(BT.Bar.Relayout)
	end
	return true
end

-- An install that has set module switches has chosen already; so has one
-- that answered this before. A fresh one - or one that never touched a
-- switch - is asked.
function W.ShouldAsk()
	local s = BT.settings
	if not s or s.setup ~= nil then
		return false
	end
	if type(s.modules) == "table" and next(s.modules) ~= nil then
		s.setup = "kept"
		return false
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local frame
local WIDTH, PAD, CHOICE_H = 440, 18, 58

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function choose(key)
	-- a fight: switching the frames now would be refused; after it, then
	if inCombat() then
		W.pending = key
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
		W.Apply(key)
	end
	if frame then
		frame:Hide()
	end
	for _, c in ipairs(W.CHOICES) do
		if c.key == key then
			U.Print(("BeebMod · %s · change it any time with /bt"):format(c.title:lower()))
		end
	end
end
W.Choose = choose

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
	frame.title:SetText("|cff74c0fcBeeb|rMod")
	frame.question = Wd.Label(frame, "How much of your interface should it change?", "normal", 0.91, 0.93, 0.92)
	frame.question:SetPoint("TOPLEFT", PAD, -PAD - 26)
	frame.choices = {}
	local y = -PAD - 54
	for _, c in ipairs(W.CHOICES) do
		local b = Wd.Button(frame, "", WIDTH - 2 * PAD, CHOICE_H)
		b:SetPoint("TOPLEFT", PAD, y)
		b.label:Hide()
		b.head = b:CreateFontString(nil, "OVERLAY", "BeebModFontNormal")
		b.head:SetPoint("TOPLEFT", 12, -10)
		b.head:SetText(c.title)
		b.text = Wd.Label(b, c.blurb, "small", 0.62, 0.68, 0.65)
		b.text:SetPoint("TOPLEFT", 12, -28)
		b.text:SetPoint("RIGHT", b, "RIGHT", -12, 0)
		b.text:SetJustifyH("LEFT")
		b.text:SetWordWrap(true)
		b.key = c.key
		b:SetScript("OnClick", function() choose(c.key) end)
		frame.choices[#frame.choices + 1] = b
		y = y - CHOICE_H - 8
	end
	frame.foot = Wd.Label(frame, "Every piece can be switched on or off later, one at a time: /bt", "small", 0.50, 0.55, 0.53)
	frame.foot:SetPoint("TOPLEFT", PAD, y - 4)
	frame:SetSize(WIDTH, -y + 4 + 14 + PAD)
	frame:SetPoint("CENTER", 0, 60)
	-- Escape puts it off to the next login rather than choosing for you
	tinsert(UISpecialFrames, "BeebModWelcome")
	frame:Hide()
	return frame
end

function W.Show()
	W.Build()
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
end, "choose again how much BeebMod changes: full, just the dock, or census and notes")
