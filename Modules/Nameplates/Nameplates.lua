-- Enemy nameplates in the toolkit's clothes (Josh 2026-10-03).
--
-- "I think it's time we make a Nameplates module. We can make these much
-- cleaner than the default so they are easier to read." The look is D on the
-- nameplates design canvas: the level in a tab at the left, the name and the
-- health's share inside the bar, and the rest the unit frames' own - the
-- threat ring, the white outline round your target, gold or silver brackets
-- on an elite or a rare, the cast bar under it, and your damage over time in
-- short lanes above it.
--
-- THE GAME'S PLATE, OUR FRAME ON IT. The plate is still the client's: it
-- finds the enemy, places, scales and fades the plate, and takes the click.
-- What it draws on the plate is a "unit frame" it lends each plate from a
-- pool while the enemy is in view; that is put at no alpha, and one of our
-- unit frames (Modules/UnitFrames/Unit.lua, kind "plate") sits on the plate in
-- its place, reading the same secret health the same way and hearing the
-- same events as every other frame of ours. When the enemy goes the client's
-- frame goes back to its pool as it came.
--
-- MADE BEFORE A FIGHT. The lanes are the client's aura containers, which may
-- only be made out of combat, so a frame is made for each of the first
-- M.PLATES tokens ("nameplate1" and on) when the module comes on, and after
-- that only moved, shown and hidden - which the client allows in a fight. An
-- enemy whose plate has a later token keeps the game's own plate.
--
-- ENEMIES ONLY. A friend's plate, and a plate the client keeps from addons
-- (a "forbidden" one, as in an instance), are left as the game draws them.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Nameplates/Nameplates.lua")

local F = BT.UnitFrames

local M = BT.Module({
	key = "nameplates",
	feature = "unitframes",
	title = "Nameplates",
	blurb = "Enemy nameplates in BeebMod's style, with your damage over time on them",
	order = 58.6,
})

-- how many enemies at once wear ours
M.PLATES = 20
-- how far the others step back while you have a target
M.DIM = 0.7
-- the alpha the client gives the highlight on its target's plate (its XML)
local HIGHLIGHT = 0.25

-- [token] = our frame for that plate
M.skins = {}
-- [token] = the client's frame we put away, to give back
M.lent = {}

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function opt(name, fallback)
	local s = BT.settings and BT.settings.nameplates
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

function M.SetOpt(name, value)
	BT.EnsureBound()
	BT.settings.nameplates = BT.settings.nameplates or {}
	BT.settings.nameplates[name] = value
end

-- THE OTHERS STEP BACK (on unless you turn it off): read by a plate's paint
-- (Unit.lua, paintRange), the alpha the others go to, or nil for none
F.PlateDim = function()
	if not (BT.Enabled("nameplates") and opt("dim", true)) then
		return nil
	end
	return M.DIM
end

function M.Token(i)
	return "nameplate" .. i
end

-- ---------------------------------------------------------------------------
-- Our frames, made once
-- ---------------------------------------------------------------------------

-- the frame for one token, made out of combat only
function M.Make(token)
	local s = M.skins[token]
	if s or inCombat() then
		return s
	end
	s = F.Build(UIParent, "plate", nil, false)
	-- the plate takes the click, not us
	s:EnableMouse(false)
	s:Hide()
	s.bmUnit = token
	-- the lanes, on the same token (Auras.lua, Timers.lua)
	if F.Auras then
		F.Auras.Attach(s, "plate")
	end
	F.Bind(s, token)
	M.skins[token] = s
	return s
end

function M.MakeAll()
	if inCombat() then
		M.makeAfter = true
		return 0
	end
	M.makeAfter = nil
	local n = 0
	for i = 1, M.PLATES do
		if M.Make(M.Token(i)) then
			n = n + 1
		end
	end
	return n
end

-- ---------------------------------------------------------------------------
-- On a plate, and off it
-- ---------------------------------------------------------------------------

-- the client's plate for a token, or nil (a forbidden one is not handed out)
function M.PlateOf(token)
	local np = _G.C_NamePlate
	if not (np and np.GetNamePlateForUnit) then
		return nil
	end
	local ok, p = pcall(np.GetNamePlateForUnit, token)
	if ok and type(p) == "table" then
		return p
	end
	return nil
end

-- AND KEPT AT NO ALPHA (Josh 2026-10-03: "the default bar is not hidden").
-- The client sets its frame's alpha itself: CompactUnitFrame_UpdateCenterStatusIcon
-- ends by putting it back to full, and that runs when the enemy's flags
-- change - as it goes into a fight - and as it crosses a distance. So each
-- of its frames we have put away is watched, and put back to nothing
-- whenever anything sets it while it is ours.
M.away = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local holding = false

local function keepAway(uf)
	if holding or not M.away[uf] then
		return
	end
	holding = true
	pcall(uf.SetAlpha, uf, 0)
	holding = false
end

-- the client's frame we put away for a token, back as it came, to go back
-- to the client's pool
local function giveBack(token)
	local uf = M.lent[token]
	if not uf then
		return
	end
	M.lent[token] = nil
	-- not ours any more: let go before it is set, or the watch puts it away again
	M.away[uf] = nil
	pcall(uf.SetAlpha, uf, 1)
	local glow = uf.selectionHighlight
	if type(glow) == "table" and glow.SetAlpha then
		pcall(glow.SetAlpha, glow, HIGHLIGHT)
	end
end

-- the client's own frame on the plate, at no alpha; its target highlight
-- ignores its parent's alpha, so that is put away by itself
local function lend(token, plate)
	local uf = plate.UnitFrame
	if type(uf) ~= "table" or not uf.SetAlpha then
		return false
	end
	-- a token handed a new frame without the old one taken back first
	if M.lent[token] and M.lent[token] ~= uf then
		giveBack(token)
	end
	M.away[uf] = true
	if not watched[uf] and hooksecurefunc then
		watched[uf] = true
		pcall(hooksecurefunc, uf, "SetAlpha", keepAway)
	end
	keepAway(uf)
	local glow = uf.selectionHighlight
	if type(glow) == "table" and glow.SetAlpha then
		pcall(glow.SetAlpha, glow, 0)
	end
	M.lent[token] = uf
	return true
end

-- WHERE THE GAME DRAWS ITS BAR (Josh 2026-10-03: "needs moved down a bit so
-- it is in the same spot as the default one"). Centred on the plate, ours sat
-- above the game's: the client draws its health bar low in the plate, on top
-- of the room it keeps for a cast bar. So ours is centred on what the game
-- draws - from its health bar's top left to the top right of its cast bar's
-- room, which is as wide as the bar and the level badge beside it - and lands
-- where the plate always was, whatever size plates are set to. The plate's
-- middle is the fallback, for a build that names those parts differently.
function M.Place(s, plate)
	s:ClearAllPoints()
	local uf = plate.UnitFrame
	local bars = type(uf) == "table" and uf.HealthBarsContainer or nil
	local casts = type(uf) == "table" and uf.CastBarsContainer or nil
	if type(bars) == "table" and type(casts) == "table" then
		local spot = s.bmSpot or CreateFrame("Frame", nil, plate)
		s.bmSpot = spot
		pcall(spot.SetParent, spot, plate)
		spot:ClearAllPoints()
		local ok = pcall(spot.SetPoint, spot, "TOPLEFT", bars, "TOPLEFT", 0, 0)
			and pcall(spot.SetPoint, spot, "BOTTOMRIGHT", casts, "TOPRIGHT", 0, 0)
		if ok then
			s:SetPoint("CENTER", spot, "CENTER", 0, 0)
			return "bar"
		end
		spot:ClearAllPoints()
	end
	s:SetPoint("CENTER", plate, "CENTER", 0, 0)
	return "plate"
end

-- An enemy's plate came into view: ours on it, the client's put away. True
-- when ours is on.
function M.Added(token)
	local s = M.skins[token]
	if not (s and BT.Enabled("nameplates")) then
		return false
	end
	local src = F.Source(token)
	if not src:CanAttack() then
		-- a friend, or an enemy this token no longer is
		M.Removed(token)
		return false
	end
	local plate = M.PlateOf(token)
	if not plate then
		return false
	end
	if not lend(token, plate) then
		-- THE CLIENT FIRST. Its own handler for the event lends the plate its
		-- frame, and it runs before ours; should ours ever come first, the
		-- plate is dressed a frame later, once the client's is there.
		if C_Timer and C_Timer.After and not s.bmWaiting then
			s.bmWaiting = true
			C_Timer.After(0, function()
				s.bmWaiting = nil
				if M.PlateOf(token) == plate then
					M.Added(token)
				end
			end)
		end
		return false
	end
	-- on the plate itself, so it is placed, scaled and faded with it
	if not pcall(s.SetParent, s, plate) then
		pcall(s.SetParent, s, UIParent)
	end
	M.Place(s, plate)
	s.bmPlate = plate
	-- somebody new: the bars jump to them, and the lanes read them afresh
	F.Fresh(s)
	s:Show()
	F.Paint(s, src)
	if F.Auras then
		F.Auras.Refresh(s)
	end
	return true
end

-- the plate went (or is somebody else's now): ours off it, the client's back
function M.Removed(token)
	local s = M.skins[token]
	if s then
		s:Hide()
		s.bmPlate = nil
		pcall(s.SetParent, s, UIParent)
		-- nothing of ours left hanging off the client's frame, which goes
		-- back to its pool for another plate
		s:ClearAllPoints()
		if s.bmSpot then
			s.bmSpot:ClearAllPoints()
			pcall(s.bmSpot.SetParent, s.bmSpot, s)
		end
	end
	giveBack(token)
end

-- every plate in view, dressed or given back as the module is now
function M.Sweep()
	local on = BT.Enabled("nameplates")
	local n = 0
	for i = 1, M.PLATES do
		local token = M.Token(i)
		if on and F.Plain(UnitExists, token) then
			if M.Added(token) then
				n = n + 1
			end
		else
			M.Removed(token)
		end
	end
	return n
end

-- a new target: every plate in view says again whether it is the one
function M.TargetChanged()
	for token, s in pairs(M.skins) do
		if s:IsShown() then
			F.PaintRange(s, F.Source(token))
		end
	end
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, token)
	if event == "NAME_PLATE_UNIT_REMOVED" then
		-- given back even with the module off: nothing of ours stays on a
		-- plate the client is about to hand to somebody else
		if type(token) == "string" then
			M.Removed(token)
		end
		return
	end
	if not BT.Enabled("nameplates") then
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		if type(token) == "string" then
			M.Added(token)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		M.TargetChanged()
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- switched on in a fight: made now it is over
		if M.makeAfter then
			M.MakeAll()
			M.Sweep()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		M.Sweep()
	end
end)

-- ---------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------

function M:OnEnable()
	M.MakeAll()
	-- the lanes read again, if they were put away with the module
	for _, s in pairs(M.skins) do
		if F.Auras then
			F.Auras.Pause(s, false)
		end
	end
	M.Sweep()
	-- your target's damage leaves the target frame for its plate (Timers.lua)
	if F.Timers then
		F.Timers.Rebuild()
	end
end

function M:OnBind()
	if BT.Enabled("nameplates") then
		M:OnEnable()
	end
end

-- every plate back as the game draws it, and the lanes stop reading
function M:OnDisable()
	M.Sweep()
	for _, s in pairs(M.skins) do
		if F.Auras then
			F.Auras.Pause(s, true)
		end
	end
	-- and goes back over the target frame
	if F.Timers then
		F.Timers.Rebuild()
	end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	page:Note("An enemy's nameplate shows its level, its name and how much health it has left. A ring "
		.. "shows when it is attacking you, and a white outline marks your target. Gold brackets mark an "
		.. "elite and silver ones a rare. Its casts show under the plate, and your damage over time above it.")
	page:Note("Friendly nameplates stay as the game draws them. The game's enemy nameplates need to be on.", true)
	local look = page:Section("Look")
	W.SwitchRow(look, "Dim other enemies", "While you have a target, the other nameplates fade a little",
		function() return opt("dim", true) and true or false end,
		function(on)
			-- on is the default, so only off is written down
			if on then
				M.SetOpt("dim", nil)
			else
				M.SetOpt("dim", false)
			end
			M.TargetChanged()
		end)
	-- YOUR DAMAGE OVER TIME, HERE (Josh 2026-10-03: "Remove the DoT bar from
	-- the personal resource display - the nameplates version deprecates
	-- that"): which spells, in what order, and the blink, on the page of the
	-- plates they are on now (Modules/UnitFrames/Timers.lua). The same lanes
	-- stand over the focus and the bosses.
	local T = F.Timers
	if T then
		self.dots = T.DotSection(page)
		if self.dots then
			self.blinkRow = T.BlinkRow(self.dots, "dot")
		end
	end
	page:Layout()
end

function M:ShowTab()
	if BT.Widgets.SyncRows then
		BT.Widgets.SyncRows()
	end
end
