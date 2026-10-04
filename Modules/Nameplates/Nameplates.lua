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
-- A FRIEND'S PLATE IS ITS NAME (Josh 2026-10-04: "Can we add friendly
-- nameplates as well? They should look distinct and more simple than enemy
-- nameplates to reduce clutter on screen"; A on the friendly nameplates
-- canvas, "look good... lets proceed"). No bar, no level, no figures: a
-- player's name in their class colour, an NPC's in the friendly green, and a
-- white line under your target's. A plate the client keeps from addons (a
-- "forbidden" one, as a friend's in an instance) is left as the game draws it.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Nameplates/Nameplates.lua")

local F = BT.UnitFrames

local M = BT.Module({
	key = "nameplates",
	feature = "unitframes",
	title = "Nameplates",
	blurb = "Enemy nameplates with your damage over time on them, and friends' names",
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

-- ---------------------------------------------------------------------------
-- Friends: the name and nothing else
-- ---------------------------------------------------------------------------

-- [token] = the name we put on a friend's plate. Plain frames, with no aura
-- containers, so made when they are first wanted, in a fight too.
M.friends = {}

function M.Friend(token)
	local f = M.friends[token]
	if f then
		return f
	end
	f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(200, 16)
	f:EnableMouse(false)
	f.name = f:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(f.name, "name", 11, "")
	f.name:SetShadowColor(0, 0, 0, 1)
	f.name:SetShadowOffset(1, -1)
	f.name:SetWordWrap(false)
	f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
	-- your target's: a white line under the name
	-- what an NPC does, before its name (M.RoleOf)
	f.role = f:CreateTexture(nil, "OVERLAY")
	f.role:SetSize(M.ROLE_SIZE, M.ROLE_SIZE)
	f.role:SetPoint("RIGHT", f.name, "LEFT", -3, 0)
	f.role:Hide()
	f.under = f:CreateTexture(nil, "OVERLAY")
	f.under:SetColorTexture(1, 1, 1, 1)
	f.under:SetHeight(1)
	f.under:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -1)
	f.under:SetPoint("TOPRIGHT", f.name, "BOTTOMRIGHT", 0, -1)
	f:Hide()
	f.bmUnit = token
	M.friends[token] = f
	return f
end

-- a player's class colour, lifted to read on the ground; an NPC's green.
-- AN NPC STEPS BACK (Josh 2026-10-04: "Able to make NPCs distinct from
-- players? They should be less noticeable, but still readable"): a softer
-- green, in the lighter face, a size down; a player's name stays the name
-- face at 11. A pet or a minion is not a player, so it is drawn as an NPC.
M.FRIEND_NPC = { 0.56, 0.74, 0.60 }
M.FRIEND_SIZE = { player = 11, npc = 10 }
function M.FriendColour(src)
	if src:IsPlayer() then
		local r, g, b = BT.Util.ClassColor(src:Class())
		return BT.Util.Bright({ r, g, b })
	end
	return M.FRIEND_NPC[1], M.FRIEND_NPC[2], M.FRIEND_NPC[3]
end

-- ---------------------------------------------------------------------------
-- What an NPC does
-- ---------------------------------------------------------------------------
--
-- A PICTURE FOR WHAT AN NPC DOES (Josh 2026-10-04: "Could we put
-- vendor/trainer/directions icons on NPCs that have them? That is much more
-- important than their name"). The game gives addons no role for an NPC; the
-- subtitle under its name on its tooltip says it ("<Innkeeper>", "<Warrior
-- Trainer>"), so that is read, as the game writes it in English, and a city
-- guard - who gives directions - is known by the last word of its name. One
-- picture, the most useful role first; the game's own minimap tracking and
-- gossip pictures. Learned once for each kind of NPC.
local TRACK, GOSSIP = "Interface\\Minimap\\Tracking\\", "Interface\\GossipFrame\\"
M.ROLE_SIZE = 16
M.ROLES = {
	{ key = "flight", icon = TRACK .. "FlightMaster",
		words = { "Flight Master", "Gryphon Master", "Wind Rider Master", "Hippogryph Master", "Bat Handler" } },
	{ key = "inn", icon = TRACK .. "Innkeeper", words = { "Innkeeper" } },
	{ key = "bank", icon = TRACK .. "Banker", words = { "Banker" } },
	{ key = "auction", icon = TRACK .. "Auctioneer", words = { "Auctioneer" } },
	{ key = "stable", icon = TRACK .. "StableMaster", words = { "Stable Master" } },
	{ key = "class", icon = TRACK .. "Class", words = { "Warrior Trainer", "Paladin Trainer", "Hunter Trainer",
		"Rogue Trainer", "Priest Trainer", "Shaman Trainer", "Mage Trainer", "Warlock Trainer", "Druid Trainer" } },
	{ key = "trainer", icon = TRACK .. "Profession", words = { "Trainer" } },
	{ key = "repair", icon = TRACK .. "Repair", words = { "Armorer", "Armorsmith", "Weaponsmith", "Blacksmith", "Repair" } },
	{ key = "food", icon = TRACK .. "Food", words = { "Food", "Drink", "Baker", "Butcher", "Cook", "Fruit", "Fishmonger" } },
	{ key = "reagents", icon = TRACK .. "Reagents", words = { "Reagent" } },
	{ key = "poisons", icon = TRACK .. "Poisons", words = { "Poison" } },
	{ key = "ammo", icon = TRACK .. "Ammunition", words = { "Bowyer", "Gunsmith", "Ammunition", "Arrow", "Bullet" } },
	{ key = "vendor", icon = GOSSIP .. "VendorGossipIcon",
		words = { "Merchant", "Vendor", "Supplies", "Supplier", "Goods", "Trader", "Tradesman", "Provisioner" } },
}
-- a city guard, who gives directions: the last word of its name, and only
-- in a capital (the same day: "The directions are only available in major
-- cities") - Auberdine's sentinels guard, and send nobody anywhere
M.GUARDS = { Guard = true, Sentinel = true, Grunt = true, Deathguard = true, Bluffwatcher = true, Mountaineer = true }
-- Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity
M.CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
function M.InCapital()
	local get = C_Map and C_Map.GetBestMapForUnit
	local ok, map = false, nil
	if get then
		ok, map = pcall(get, "player")
	end
	return ok and M.CAPITALS[map] or false
end
M.DIRECTIONS = { key = "directions", icon = "Interface\\Icons\\INV_Misc_Map_01" }

-- the title under an NPC's name on its tooltip, plain, or nil: its second
-- line, with or without angle brackets (Core/Util.lua, U.NpcTitle)
function M.Subtitle(token)
	local get = C_TooltipInfo and C_TooltipInfo.GetUnit
	if not get then
		return nil
	end
	local ok, data = pcall(get, token)
	if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local second = type(data.lines[2]) == "table" and data.lines[2].leftText or nil
	return BT.Util.NpcTitle(second)
end

-- what an NPC does, by its title, as an entry of M.ROLES, or nil
function M.RoleFor(subtitle)
	if type(subtitle) == "string" then
		for _, role in ipairs(M.ROLES) do
			for _, word in ipairs(role.words) do
				if subtitle:find(word, 1, true) then
					return role
				end
			end
		end
	end
	return nil
end

-- a guard who gives directions: the last word of its name, in a capital
function M.GivesDirections(name, inCapital)
	if not inCapital or type(name) ~= "string" then
		return false
	end
	local last = name:match("(%S+)$")
	return last and M.GUARDS[last] or false
end

-- [npc id] = the role its title gives, or false for none: a title does not
-- change. Whether a guard gives directions is asked each time, since the
-- same guard may stand at a capital's gate and inside it.
M.roles = {}
function M.RoleOf(token)
	local guid = F.Plain(UnitGUID, token)
	local npc = type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or nil
	local role
	if npc and M.roles[npc] ~= nil then
		role = M.roles[npc] or nil
	else
		role = M.RoleFor(M.Subtitle(token))
		if npc then
			M.roles[npc] = role or false
		end
	end
	if not role and M.GivesDirections(F.Plain(UnitName, token), M.InCapital()) then
		role = M.DIRECTIONS
	end
	return role
end

-- the whole name where the game gives it; nothing tested that may be hidden
function M.PaintFriend(f, src)
	local name = src:FullName()
	if not F.Secret(name) and name == nil then
		name = src:Name()
	end
	if not F.Secret(name) and name == nil then
		name = ""
	end
	local player = src:IsPlayer()
	if f.bmPlayer ~= player then
		f.bmPlayer = player
		BT.Fonts.Set(f.name, player and "name" or "text", player and M.FRIEND_SIZE.player or M.FRIEND_SIZE.npc, "")
	end
	f.name:SetText(name)
	f.name:SetTextColor(M.FriendColour(src))
	F.AlphaFrom(f.under, src:IsTarget(), 1, 0)
	local role = not player and f.bmUnit and M.RoleOf(f.bmUnit) or nil
	if role then
		f.role:SetTexture(role.icon)
		f.role:Show()
	else
		f.role:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- Pets and minions: the game's own switch
-- ---------------------------------------------------------------------------
--
-- PLATES FOR PETS (Josh 2026-10-04: "can we add nameplates for player
-- pets/minions?"). Whether a pet has a plate at all is the game's to say,
-- with its own setting - Interface, Nameplates, Friendly players, Minions -
-- and once it has one, it is a friend's like any other. So BeebMod's switch
-- turns the game's on, and puts back what you had when it goes off. The game
-- will not have its plate settings changed in a fight, so a change asked for
-- then is made when the fight ends.
M.MINION_CVAR = "nameplateShowFriendlyPlayerMinions"

local function cvar(name, value)
	local c = _G.C_CVar
	if value == nil then
		local get = c and c.GetCVar or _G.GetCVar
		return get and get(name) or nil
	end
	local set = c and c.SetCVar or _G.SetCVar
	if set then
		pcall(set, name, value)
	end
end

-- on or off; true when made, false when it waits for the fight to end or
-- the client has no such setting
function M.ShowMinions(on)
	if inCombat() then
		M.minionsAfter = on and true or false
		return false
	end
	M.minionsAfter = nil
	local now = cvar(M.MINION_CVAR)
	if now == nil then
		return false
	end
	if on then
		if now ~= "1" and opt("minionsWas", nil) == nil then
			M.SetOpt("minionsWas", now)
		end
		cvar(M.MINION_CVAR, "1")
	else
		local was = opt("minionsWas", nil)
		if was ~= nil then
			cvar(M.MINION_CVAR, was)
			M.SetOpt("minionsWas", nil)
		end
	end
	return true
end

-- our frames off a token's plate, without giving the client's back
local function hideSkin(token)
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
end
local function hideFriend(token)
	local f = M.friends[token]
	if f then
		f:Hide()
		pcall(f.SetParent, f, UIParent)
		f:ClearAllPoints()
		if f.bmSpot then
			f.bmSpot:ClearAllPoints()
			pcall(f.bmSpot.SetParent, f.bmSpot, f)
		end
	end
end

-- A plate came into view: ours on it, the client's put away - an enemy's
-- whole frame, or a friend's name. True when ours is on.
function M.Added(token)
	if not BT.Enabled("nameplates") then
		return false
	end
	local src = F.Source(token)
	local friend = not src:CanAttack()
	local s = M.skins[token]
	if friend and not opt("friends", true) or not friend and not s then
		-- a friend with their names switched off, or an enemy past the first
		-- M.PLATES: the game's own
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
	if friend then
		-- an enemy's frame off a token that is a friend's now, the name on
		hideSkin(token)
		local f = M.Friend(token)
		if not pcall(f.SetParent, f, plate) then
			pcall(f.SetParent, f, UIParent)
		end
		M.Place(f, plate)
		f:Show()
		M.PaintFriend(f, src)
		return true
	end
	hideFriend(token)
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
	hideSkin(token)
	hideFriend(token)
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
	-- a friend's name can be on a plate past the first M.PLATES too
	for token, f in pairs(M.friends) do
		if f:IsShown() and not (on and opt("friends", true) and F.Plain(UnitExists, token)) then
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
	for token, f in pairs(M.friends) do
		if f:IsShown() then
			F.AlphaFrom(f.under, F.Source(token):IsTarget(), 1, 0)
		end
	end
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE" }) do
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
	elseif event == "UNIT_NAME_UPDATE" then
		-- a friend's name the game had not sent yet
		local f = type(token) == "string" and M.friends[token]
		if f and f:IsShown() then
			M.PaintFriend(f, F.Source(token))
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- switched on in a fight: made now it is over
		if M.makeAfter then
			M.MakeAll()
			M.Sweep()
		end
		if M.minionsAfter ~= nil then
			M.ShowMinions(M.minionsAfter)
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
	if opt("minions", true) then
		M.ShowMinions(true)
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
	-- the game's pet plates as you had them
	M.ShowMinions(false)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	page:Note("An enemy's nameplate shows its level, name and health. A ring means it is attacking you, and "
		.. "a white outline marks your target. Gold brackets mean elite and silver brackets mean rare. Casts "
		.. "show under the plate and your damage over time shows above it.")
	page:Note("A friend's nameplate shows only the name: a player's in class colour, an NPC's or a pet's smaller "
		.. "and in a softer green. An NPC who sells, trains, flies you, keeps an inn, a bank or a stable, or "
		.. "gives directions in a capital has a picture for it before the name. Nameplates must be on in the game's options. "
		.. "In dungeons the game keeps friendly ones for itself.", true)
	local look = page:Section("Look")
	W.SwitchRow(look, "Friendly nameplates", "Names only, underlined for your target",
		function() return opt("friends", true) and true or false end,
		function(on)
			-- on is the default, so only off is written down
			if on then
				M.SetOpt("friends", nil)
			else
				M.SetOpt("friends", false)
			end
			M.Sweep()
		end)
	W.SwitchRow(look, "Pets and minions", "Names over your pet and other players' pets and minions",
		function() return opt("minions", true) and true or false end,
		function(on)
			if on then
				M.SetOpt("minions", nil)
			else
				M.SetOpt("minions", false)
			end
			M.ShowMinions(on)
		end)
	W.SwitchRow(look, "Dim other enemies", "Other nameplates fade while you have a target",
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
