-- The Menagerie's toast: "Gold mastery! 150 kills on Barn Owl" (Josh 2026-09-25).
--
-- In the game's own achievement art, which this client still ships - the
-- MobProbe drew it on 70009 from these very files and coordinates. One at a
-- time, the rest in a queue: an AoE pull that crosses three milestones shows
-- three toasts, one after the other, never three on top of each other.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Toast.lua")

local T = {}
BT.MenagerieToast = T

local ART = "Interface\\AchievementFrame\\"
local SKULL = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
-- how long each is up, and how long it takes to come and go
local HOLD, FADE_IN, FADE_OUT = 5, 0.2, 0.6
-- past this many waiting, the rest are said in one line of chat
local QUEUE_MAX = 6

-- an icon per creature type, where the client has the file; the skull where not
local TYPE_ICONS = {
	Beast = "Ability_Hunter_BeastCall",
	Humanoid = "INV_Misc_Head_Human_01",
	Undead = "Spell_Shadow_RaiseDead",
	Demon = "Spell_Shadow_SummonFelHunter",
	Dragonkin = "INV_Misc_Head_Dragon_01",
	Elemental = "Spell_Frost_SummonWaterElemental",
	Mechanical = "INV_Misc_Gear_01",
}

-- a rank is knowledge: a book, where the client has one
T.RANK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local known = {}
local function exists(path)
	if known[path] == nil then
		local ok, id = pcall(GetFileIDFromPath or function() return nil end, path)
		known[path] = ok and id ~= nil and id ~= 0
	end
	return known[path]
end

function T.Icon(kind)
	local name = kind and TYPE_ICONS[kind]
	if name then
		local path = "Interface\\Icons\\" .. name
		if exists(path) then
			return path
		end
	end
	return SKULL
end

-- the client's achievement sound, by whichever name this build gives it
local SOUNDS = { "UI_ALERT_ACHIEVEMENT_GAINED", "ACHIEVEMENT_MENU_OPEN", "UI_EPICLOOT_TOAST" }
local function chime()
	if BT.settings and BT.settings.menagerieSound == false then
		return
	end
	if not (SOUNDKIT and type(PlaySound) == "function") then
		return
	end
	for _, key in ipairs(SOUNDS) do
		if SOUNDKIT[key] then
			pcall(PlaySound, SOUNDKIT[key])
			return
		end
	end
end

local frame
local queue = {}
T.queue = queue

function T.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Button", "BeebModMenagerieToast", UIParent)
	frame:SetSize(300, 88)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetTexture(ART .. "UI-Achievement-Alert-Background")
	frame.bg:SetTexCoord(0, 0.605, 0, 0.703)
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(40, 40)
	frame.icon:SetPoint("LEFT", frame, "LEFT", 26, 1)
	frame.shield = frame:CreateTexture(nil, "ARTWORK")
	frame.shield:SetSize(52, 48)
	frame.shield:SetPoint("RIGHT", frame, "RIGHT", -10, -4)
	frame.shield:SetTexture(ART .. "UI-Achievement-Shields")
	frame.shield:SetTexCoord(0, 0.5, 0, 0.45)
	frame.points = frame:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	frame.points:SetPoint("CENTER", frame.shield, "CENTER", 0, 3)
	frame.head = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.head:SetPoint("TOP", frame, "TOP", -4, -24)
	frame.head:SetTextColor(1, 0.82, 0.3)
	frame.text = frame:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	frame.text:SetPoint("TOP", frame.head, "BOTTOM", 0, -5)
	frame.text:SetWidth(190)
	frame.text:SetWordWrap(false)
	-- a click puts it away, and opens the journal on what it was about
	frame:SetScript("OnClick", function(self)
		local spec = self.spec
		T.Next()
		if spec and spec.onClick then
			spec.onClick(spec)
		end
	end)
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.age = (self.age or 0) + (elapsed or 0)
		local a = self.age
		if a < FADE_IN then
			self:SetAlpha(a / FADE_IN)
		elseif a < FADE_IN + HOLD or self:IsMouseOver() then
			-- held while you point at it
			if a >= FADE_IN + HOLD then
				self.age = FADE_IN + HOLD
			end
			self:SetAlpha(1)
		elseif a < FADE_IN + HOLD + FADE_OUT then
			self:SetAlpha(1 - (a - FADE_IN - HOLD) / FADE_OUT)
		else
			T.Next()
		end
	end)
	return frame
end

local function show(spec)
	T.Build()
	frame.spec = spec
	frame.age = 0
	-- an icon this client does not have is the skull, not a green square
	local icon = spec.icon
	if icon ~= SKULL and not (icon and exists(icon)) then
		icon = SKULL
	end
	frame.icon:SetTexture(icon)
	frame.head:SetText(spec.head or "")
	frame.text:SetText(spec.text or "")
	frame.points:SetText(spec.points and tostring(spec.points) or "")
	frame:SetAlpha(0)
	frame:Show()
	chime()
end

-- the next one, or nothing
function T.Next()
	local spec = table.remove(queue, 1)
	if spec then
		show(spec)
	elseif frame then
		frame.spec = nil
		frame:Hide()
	end
end

-- spec = { head, text, points, icon, onClick }
function T.Push(spec)
	if BT.settings and BT.settings.menagerieToasts == false then
		return false
	end
	if #queue >= QUEUE_MAX then
		if BT.Util and BT.Util.Print then
			BT.Util.Print(("Menagerie: %s · %s"):format(spec.head or "", spec.text or ""))
		end
		return false
	end
	queue[#queue + 1] = spec
	if not (frame and frame:IsShown()) then
		T.Next()
	end
	return true
end

function T.Frame() return frame end
