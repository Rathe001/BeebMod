-- The Expedition's toast: "Gold mastery · 150 kills", then "Barn Owl" (Josh 2026-09-25).
--
-- In the game's own commendation art, which this client still ships - the
-- MobProbe drew it on 70009 from these very files and coordinates. One at a
-- time, the rest in a queue: an AoE pull that crosses three milestones shows
-- three toasts, one after the other, never three on top of each other.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Expedition/Toast.lua")

local T = {}
BT.ExpeditionToast = T

local ART = "Interface\\AchievementFrame\\"
local SKULL = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
-- how long each is up, and how long it takes to come and go
local HOLD, FADE_IN, FADE_OUT = 5, 0.2, 0.6
-- past this many waiting, the rest are said in one line of chat
local QUEUE_MAX = 6

-- a rank is knowledge: a book, where the client has one
T.RANK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
-- a rank's badge in the toast, in place of the icon
T.BADGE_H = 44
-- WHERE THE ICON'S MIDDLE SITS, badge or icon, from the toast's left edge
-- (Josh 2026-09-29, by eye in the game: 46 sat a little right, 34 a touch
-- left, 37 "is perfect" for the badge; 34 sets the icon against the
-- art's border, the badge with it), and an ordinary icon's size
T.SLOT_X = 34
T.ICON_SIZE = 40

local known = {}
local function exists(path)
	if known[path] == nil then
		local ok, id = pcall(GetFileIDFromPath or function() return nil end, path)
		known[path] = ok and id ~= nil and id ~= 0
	end
	return known[path]
end

-- A HUNTER'S ICON FOR EACH TOAST (Josh 2026-09-29: "Can we update the
-- expidition toast icon to a more hunter oriented icon?"): the creature's
-- type told you little the name did not. A rifle for a mastery - the weapon
-- Nesingwary is known by - the tracking eye for a new page, a hunting horn
-- for a commendation; each with others behind it, for a client without the
-- file, and the beast call behind those.
T.HUNTER = {
	mastery = { "INV_Weapon_Rifle_01", "INV_Weapon_Rifle_02", "Ability_Hunter_SniperShot" },
	discover = { "Ability_Tracking", "Ability_Hunter_EagleEye" },
	commendation = { "INV_Misc_Horn_01", "Ability_Hunter_AspectOfTheMonkey" },
}
function T.HunterIcon(what)
	for _, name in ipairs(T.HUNTER[what] or {}) do
		local path = "Interface\\Icons\\" .. name
		if exists(path) then
			return path
		end
	end
	local call = "Interface\\Icons\\Ability_Hunter_BeastCall"
	return exists(call) and call or SKULL
end

-- the client's commendation sound, by whichever name this build gives it
local SOUNDS = { "UI_ALERT_ACHIEVEMENT_GAINED", "ACHIEVEMENT_MENU_OPEN", "UI_EPICLOOT_TOAST" }
local function chime()
	if BT.settings and BT.settings.expeditionSound == false then
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

-- THE WHOLE NAME (Josh 2026-09-28: "Anything we can do to make the text fit
-- better on the commendations?" - "10 kills on Blackwood Pathfin..."). The
-- line between the icon and the shield is this wide. A line too long for it
-- steps down a size at a time to T.SMALLEST, and one too long even then goes
-- onto a second line rather than being cut off.
T.TEXT_W = 190
T.LARGEST, T.SMALLEST = 12, 10

function T.Fit(fs, words)
	fs:SetWordWrap(false)
	if fs.SetMaxLines then
		pcall(fs.SetMaxLines, fs, 1)
	end
	fs:SetText(words or "")
	local fits = false
	for size = T.LARGEST, T.SMALLEST, -1 do
		if BT.Fonts and BT.Fonts.Set then
			BT.Fonts.Set(fs, "text", size)
		end
		local ok, w = pcall(fs.GetStringWidth, fs)
		if not (ok and type(w) == "number") or w <= T.TEXT_W then
			fits = true
			break
		end
	end
	if not fits then
		fs:SetWordWrap(true)
		if fs.SetMaxLines then
			pcall(fs.SetMaxLines, fs, 2)
		end
	end
	return fits
end

function T.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Button", "BeebModExpeditionToast", UIParent)
	frame:SetSize(300, 88)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetTexture(ART .. "UI-Achievement-Alert-Background")
	frame.bg:SetTexCoord(0, 0.605, 0, 0.703)
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(T.ICON_SIZE, T.ICON_SIZE)
	frame.icon:SetPoint("CENTER", frame, "LEFT", T.SLOT_X, 1)
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
	frame.text:SetWidth(T.TEXT_W)
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
	-- A NEW RANK SHOWS ITS BADGE (Josh 2026-09-29), larger than an icon: the
	-- art leaves room round the shield. It is the addon's own file, which the
	-- client's list of its files does not name, so it is not looked up there.
	local icon = spec.badge
	frame.icon:ClearAllPoints()
	if icon then
		-- CENTRED WHERE AN ICON IS (Josh 2026-09-29: "Rank toast icon is not
		-- aligned properly"): hung by its left edge like a 40-pixel icon, a
		-- larger badge's middle came out right of it; both hang by their
		-- middles now, at T.SLOT_X
		-- AND ONLY THE SHIELD (Josh 2026-09-29: "Still off"): drawn whole, the
		-- art's room for antlers and tusks left the toast's gilt showing round
		-- a small shield where an icon covers it; cropped as in the dock, the
		-- shield fills the icon's height and covers the same corner
		local c = BT.Dock and BT.Dock.LINE_ICON_CROP or { 0.25, 0.75, 0.2, 0.875 }
		frame.icon:SetTexCoord(c[1], c[2], c[3], c[4])
		frame.icon:SetSize(math.floor(T.BADGE_H * (c[2] - c[1]) / (c[4] - c[3]) + 0.5), T.BADGE_H)
		frame.icon:SetPoint("CENTER", frame, "LEFT", T.SLOT_X, 1)
	else
		frame.icon:SetTexCoord(0, 1, 0, 1)
		frame.icon:SetPoint("CENTER", frame, "LEFT", T.SLOT_X, 1)
		-- an icon this client does not have is the skull, not a green square
		icon = spec.icon
		if icon ~= SKULL and not (icon and exists(icon)) then
			icon = SKULL
		end
		frame.icon:SetSize(T.ICON_SIZE, T.ICON_SIZE)
	end
	frame.icon:SetTexture(icon)
	frame.head:SetText(spec.head or "")
	T.Fit(frame.text, spec.text)
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

-- spec = { head, text, points, icon, badge, onClick, minor }
function T.Push(spec)
	-- the commendations' switch is theirs alone: a new page has its own
	-- (expeditionDiscover, asked before it is pushed)
	if not spec.minor and BT.settings and BT.settings.expeditionToasts == false then
		return false
	end
	-- A NEW PAGE GIVES WAY (Josh 2026-09-27, new-enemy toasts on by default):
	-- a fresh journal's first dozen kills are a dozen new pages, and they
	-- filled the queue ahead of the commendation and rank those kills earned.
	-- A full queue lets its last new page go - to chat, as ever - for anything
	-- that is not one.
	if #queue >= QUEUE_MAX and not spec.minor then
		for i = #queue, 1, -1 do
			if queue[i].minor then
				local gone = table.remove(queue, i)
				if BT.Util and BT.Util.Print then
					BT.Util.Print(("Expedition: %s · %s"):format(gone.head or "", gone.text or ""))
				end
				break
			end
		end
	end
	if #queue >= QUEUE_MAX then
		if BT.Util and BT.Util.Print then
			BT.Util.Print(("Expedition: %s · %s"):format(spec.head or "", spec.text or ""))
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
