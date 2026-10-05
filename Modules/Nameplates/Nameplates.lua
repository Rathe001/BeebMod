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
-- canvas, "look good... lets proceed"). No bar, no figures: a player's name
-- in their class colour, an NPC's in the friendly green, and a white line
-- under your target's. A player's level stands before the name (the same
-- day: "Can we add level to friendly players?"), and under an NPC's name its
-- title, or a pet's owner (M.OwnerTag). A plate the client keeps from addons (a
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

-- FIXED, NOT ASKED (the settings canvas, Josh 2026-10-04: "This addon is
-- supposed to be an opinionated solution, not fully customizable"). The other enemies dimmed while you have a target.
M.FIXED = { dim = true }

local function opt(name, fallback)
	if M.FIXED[name] ~= nil then
		return M.FIXED[name]
	end
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
	BT.Fonts.Set(f.name, "name", M.FRIEND_SIZE.player, "")
	f.name:SetShadowColor(0, 0, 0, 1)
	f.name:SetShadowOffset(1, -1)
	f.name:SetWordWrap(false)
	f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
	-- a player's level, a size down, before the name; the name stays centred
	f.level = f:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(f.level, "name", M.FRIEND_SIZE.level, "")
	f.level:SetShadowColor(0, 0, 0, 1)
	f.level:SetShadowOffset(1, -1)
	f.level:SetPoint("RIGHT", f.name, "LEFT", -3, 0)
	-- an NPC's title or a pet's owner, a size down again, under the name and
	-- your target's line
	f.sub = f:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(f.sub, "text", M.FRIEND_SIZE.sub, "")
	f.sub:SetShadowColor(0, 0, 0, 1)
	f.sub:SetShadowOffset(1, -1)
	f.sub:SetWordWrap(false)
	f.sub:SetPoint("TOP", f.name, "BOTTOM", 0, -3)
	-- your target's: a white line under the name
	-- what an NPC does, before its name (M.RoleOf)
	f.role = f:CreateTexture(nil, "OVERLAY")
	f.role:SetSize(M.ROLE_SIZE, M.ROLE_SIZE)
	f.role:SetPoint("RIGHT", f.name, "LEFT", -4, 0)
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
-- (a player's name 13 and its level 12, Josh 2026-10-04: "can you increase
-- player nameplate name text size?")
M.FRIEND_SIZE = { player = 13, npc = 10, level = 12, sub = 9 }
-- the line under an NPC's name, grey (Josh 2026-10-04: "Can you make the NPC
-- titles gray?"): light enough to read on the ground at its small size
M.FRIEND_SUB = { 0.66, 0.68, 0.67 }
function M.FriendColour(src)
	if src:IsPlayer() then
		local r, g, b = BT.Util.ClassColor(src:Class())
		return BT.Util.Bright({ r, g, b })
	end
	return M.FRIEND_NPC[1], M.FRIEND_NPC[2], M.FRIEND_NPC[3]
end

-- ---------------------------------------------------------------------------
-- Whose pet
-- ---------------------------------------------------------------------------
--
-- WHOSE PET (Josh 2026-10-04: "Under player pets, can we tag <Luigi's
-- pet>?"). The game writes the owner on a pet's tooltip, on the line under its
-- name: "Luigi's Pet", "Luigi's Minion". Its own strings for that line
-- (UNITNAME_TITLE_PET and the rest) say which lines are an owner's, in the
-- client's language, so that line is read for a unit a player controls and
-- shown under its name, the kind in lower case as Josh wrote it.
M.OWNER_TITLES = { "UNITNAME_TITLE_PET", "UNITNAME_TITLE_MINION", "UNITNAME_TITLE_GUARDIAN",
	"UNITNAME_TITLE_CHARM", "UNITNAME_TITLE_COMPANION", "UNITNAME_TITLE_CREATION" }
-- and the English ones, for a client missing any
M.OWNER_FORMS = { "%s's Pet", "%s's Minion", "%s's Guardian" }

-- "<Luigi's pet>" from the line "Luigi's Pet", or nil for any other line
function M.OwnerTag(line)
	if type(line) ~= "string" or F.Secret(line) then
		return nil
	end
	local forms = {}
	for _, key in ipairs(M.OWNER_TITLES) do
		local form = _G[key]
		if type(form) == "string" and form:find("%s", 1, true) then
			forms[#forms + 1] = form
		end
	end
	for _, form in ipairs(M.OWNER_FORMS) do
		forms[#forms + 1] = form
	end
	for _, form in ipairs(forms) do
		local pattern = (form:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)", 1))
		local owner = line:match("^" .. pattern .. "$")
		if owner then
			return "<" .. owner .. line:sub(#owner + 1):lower() .. ">"
		end
	end
	return nil
end

-- whether a player controls this unit: the game's word, or a hunter's pet's
-- GUID where that is hidden
function M.Owned(token)
	-- "a pet, totem, or guardian", the client's own documentation says
	for _, ask in ipairs({ "UnitIsMinion", "UnitPlayerControlled" }) do
		local v = F.Plain(_G[ask], token)
		if v ~= nil then
			return v and true or false
		end
	end
	local guid = F.Plain(UnitGUID, token)
	return type(guid) == "string" and guid:find("^Pet%-") ~= nil
end

-- YOURS GOES UNSAID (Josh 2026-10-04, "Let's do 1-4"): "<Beeb's pet>" under
-- your own pet tells you nothing
function M.Mine(token)
	local v = F.Plain(_G.UnitIsOwnerOrControllerOfUnit, "player", token)
	if v ~= nil then
		return v and true or false
	end
	return F.Plain(UnitIsUnit, token, "pet") == true
end

-- NO TOTEMS (Josh 2026-10-04, "Let's do 1-4"): the pets and minions switch
-- may give every shaman's totems a plate, four names each; a friendly
-- totem's plate shows nothing. A totem is the game's creature type 11.
M.TOTEM = 11
function M.IsTotem(token)
	local ok, _, id = pcall(_G.UnitCreatureType or error, token)
	return ok and not F.Secret(id) and id == M.TOTEM or false
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
-- LARGER THAN THE NAME (the same day: "Can we make all the icons larger?"):
-- 16 read as a speck beside a 10-point name
M.ROLE_SIZE = 24
-- THE TRACKING MENU'S OWN PICTURES (the same day: "Can we do the same for
-- all the trackable icons that go on NPCs?", with the minimap's tracking
-- menu): a role the menu lists names its entry in `track`, and wears the
-- picture the game gives that entry (M.TrackIcons); `icon` is the old
-- picture, for a client that lists none. Battlemasters joined them.
M.ROLES = {
	{ key = "flight", track = "Flight Master", icon = TRACK .. "FlightMaster",
		words = { "Flight Master", "Gryphon Master", "Wind Rider Master", "Hippogryph Master", "Bat Handler" } },
	-- (not an assistant innkeeper, Josh 2026-10-04: "Oddly enough, you cannot
	-- interact with <assistant innkeeper>")
	{ key = "inn", track = "Innkeeper", icon = TRACK .. "Innkeeper", words = { "Innkeeper" }, except = { "Assistant" } },
	{ key = "bank", track = "Banker", icon = TRACK .. "Banker", words = { "Banker" } },
	{ key = "auction", track = "Auctioneer", icon = TRACK .. "Auctioneer", words = { "Auctioneer" } },
	{ key = "stable", track = "Stable Master", icon = TRACK .. "StableMaster", words = { "Stable Master" } },
	{ key = "battle", track = "Battlemaster", icon = TRACK .. "BattleMaster", words = { "Battlemaster" } },
	-- (a Weapon Master trains weapon skills, and comes before repair's "Weapon")
	{ key = "class", track = "Class Trainer", icon = TRACK .. "Class", words = { "Warrior Trainer", "Paladin Trainer",
		"Hunter Trainer", "Rogue Trainer", "Priest Trainer", "Shaman Trainer", "Mage Trainer", "Warlock Trainer",
		"Druid Trainer", "Weapon Master" } },
	{ key = "trainer", track = "Profession Trainers", icon = TRACK .. "Profession", words = { "Trainer" } },
	-- REPAIR, BEFORE A MERCHANT (the same day: "Repair NPCs should use the
	-- repair icon not the bag icon", at a <Weapon Merchant>): the weapon and
	-- armour sellers - Weapon, Armor (Leather Armor Merchant too), Shield -
	-- are the ones who repair
	{ key = "repair", track = "Repair", icon = TRACK .. "Repair",
		words = { "Armorer", "Armorsmith", "Weaponsmith", "Blacksmith", "Repair", "Weapon", "Armor", "Shield" } },
	{ key = "food", icon = TRACK .. "Food", words = { "Food", "Drink", "Baker", "Butcher", "Cook", "Fruit", "Fishmonger" } },
	{ key = "reagents", icon = TRACK .. "Reagents", words = { "Reagent" } },
	{ key = "poisons", icon = TRACK .. "Poisons", words = { "Poison" } },
	{ key = "ammo", icon = TRACK .. "Ammunition", words = { "Bowyer", "Gunsmith", "Ammunition", "Arrow", "Bullet" } },
	{ key = "vendor", icon = GOSSIP .. "VendorGossipIcon",
		words = { "Merchant", "Vendor", "Supplies", "Supplier", "Goods", "Trader", "Tradesman", "Provisioner" } },
}
-- [the tracking menu's entry name] = its picture, read from the game once it
-- lists any
function M.TrackIcons()
	if M.trackIcons then
		return M.trackIcons
	end
	local mm = _G.C_Minimap
	if not (mm and mm.GetNumTrackingTypes and mm.GetTrackingInfo) then
		return {}
	end
	local ok, n = pcall(mm.GetNumTrackingTypes)
	local out, any = {}, false
	for i = 1, ok and type(n) == "number" and n or 0 do
		local okI, info = pcall(mm.GetTrackingInfo, i)
		if okI and type(info) == "table" and type(info.name) == "string" and info.texture then
			out[info.name] = info.texture
			any = true
		end
	end
	if any then
		M.trackIcons = out
	end
	return out
end

-- the picture a role wears: the tracking menu's, or its own
function M.RoleIcon(role)
	return role.track and M.TrackIcons()[role.track] or role.icon
end

-- a city guard, who gives directions: the last word of its name, and only
-- in a capital (the same day: "The directions are only available in major
-- cities") - Auberdine's sentinels guard, and send nobody anywhere
M.GUARDS = { Guard = true, Sentinel = true, Grunt = true, Deathguard = true, Bluffwatcher = true, Mountaineer = true }
-- Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity: by
-- their map IDs, and by the names the game gives the zone, for a client
-- whose map IDs are not Classic's (the same day: "Not seeing the icons on
-- these guards", Ironforge Guards in Ironforge)
M.CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
M.CAPITAL_NAMES = { ["Stormwind City"] = true, Ironforge = true, Darnassus = true, Orgrimmar = true,
	["Thunder Bluff"] = true, Undercity = true }
function M.InCapital()
	local get = C_Map and C_Map.GetBestMapForUnit
	if get then
		local ok, map = pcall(get, "player")
		if ok and M.CAPITALS[map] then
			return true
		end
	end
	for _, fn in ipairs({ _G.GetRealZoneText, _G.GetZoneText }) do
		local ok, zone = pcall(fn or error)
		if ok and type(zone) == "string" and not F.Secret(zone) and M.CAPITAL_NAMES[zone] then
			return true
		end
	end
	return false
end
M.DIRECTIONS = { key = "directions", icon = "Interface\\Icons\\INV_Misc_Map_01" }

-- the title under an NPC's name on its tooltip, plain, or nil: its second
-- line, with or without angle brackets (Core/Util.lua, U.NpcTitle); and the
-- name on its first, plain, or nil
function M.Subtitle(token)
	local get = C_TooltipInfo and C_TooltipInfo.GetUnit
	if not get then
		return nil
	end
	local ok, data = pcall(get, token)
	if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
		return nil
	end
	local first = type(data.lines[1]) == "table" and data.lines[1].leftText or nil
	local second = type(data.lines[2]) == "table" and data.lines[2].leftText or nil
	if F.Secret(first) or type(first) ~= "string" then
		first = nil
	end
	return BT.Util.NpcTitle(second), first
end

-- what an NPC does, by its title, as an entry of M.ROLES, or nil
function M.RoleFor(subtitle)
	if type(subtitle) == "string" then
		for _, role in ipairs(M.ROLES) do
			-- a title with one of the role's `except` words is not that role
			local barred = false
			for _, word in ipairs(role.except or {}) do
				if subtitle:find(word, 1, true) then
					barred = true
				end
			end
			for _, word in ipairs(barred and {} or role.words) do
				if subtitle:find(word, 1, true) then
					return role
				end
			end
		end
	end
	return nil
end

-- A ROLE IN THE NAME ITSELF (the same day: "Not seeing auctioneer", at
-- Auctioneer Lympkin): Classic names some NPCs by what they do, "Auctioneer
-- Lympkin", "Innkeeper Firebrew", with no title under the name. A name that
-- starts with a role's word, then a space, has that role.
function M.RoleInName(name)
	if type(name) ~= "string" then
		return nil
	end
	for _, role in ipairs(M.ROLES) do
		for _, word in ipairs(role.words) do
			if name:sub(1, #word + 1) == word .. " " then
				return role
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

-- ---------------------------------------------------------------------------
-- Which role: what you learned, the game's cursor, then the words
-- ---------------------------------------------------------------------------
--
-- THREE WAYS, THE SUREST FIRST (Josh 2026-10-04: "maybe a mix of these 3
-- methods will make it work as expected. If anything, it should tell us
-- whether the NPC gets an icon at all"). The record showed the game's cursor
-- answering for any plate in view, not only the soft target - an Ironforge
-- banker's "Cursor Crosshair_UnableBuy_64", the buy cursor while too far to
-- use it - and nothing for a pet.
--   1. what you learned: talking to an NPC, the game says what it is (a
--      merchant, and whether it repairs; a trainer, a flight master, a
--      banker, an innkeeper, an auctioneer, a stable master, a battlemaster),
--      kept for every NPC of that kind, in the saved file (BeebModDB.npcRoles)
--   2. the game's cursor for it, from its flags: none, the words decide; repair,
--      flight, inn or stable say the role outright; a trainer's or a buy
--      cursor says the family, and the words pick which (a banker and an
--      auctioneer both get the buy cursor); a talk or quest cursor leaves it
--      to the words
--   3. the words: the title, or a name like "Auctioneer Lympkin", where the
--      cursor cannot be asked at all
M.BY_KEY = {}
for _, role in ipairs(M.ROLES) do
	M.BY_KEY[role.key] = role
end

-- PROFESSION PICTURES (Josh 2026-10-04: "is it possible to use the profession
-- icons for their respective trainers?"). A trainer's title names its craft -
-- "Alchemy Trainer", "Expert Blacksmith" - so once an NPC is known to be a
-- profession trainer, the title picks that craft's own icon (M.Sharpen). The
-- words are read only then, so "Blacksmith" on a merchant still means repair.
-- A trainer whose title names no craft keeps the tracking menu's picture.
local ICONS = "Interface\\Icons\\"
M.PROFESSIONS = {
	{ key = "alchemy", icon = ICONS .. "Trade_Alchemy", words = { "Alchem" } },
	{ key = "blacksmithing", icon = ICONS .. "Trade_BlackSmithing", words = { "Blacksmith", "Armorsmith", "Weaponsmith" } },
	{ key = "enchanting", icon = ICONS .. "Trade_Engraving", words = { "Enchant" } },
	{ key = "engineering", icon = ICONS .. "Trade_Engineering", words = { "Engineer" } },
	{ key = "herbalism", icon = ICONS .. "INV_Misc_Flower_02", words = { "Herbalis" } },
	{ key = "leatherworking", icon = ICONS .. "INV_Misc_ArmorKit_17", words = { "Leatherwork" } },
	{ key = "mining", icon = ICONS .. "Trade_Mining", words = { "Mining", "Miner" } },
	{ key = "skinning", icon = ICONS .. "INV_Misc_Pelt_Wolf_01", words = { "Skinn" } },
	{ key = "tailoring", icon = ICONS .. "Trade_Tailoring", words = { "Tailor" } },
	{ key = "cooking", icon = ICONS .. "INV_Misc_Food_15", words = { "Cook", "Chef" } },
	{ key = "firstaid", icon = ICONS .. "Spell_Holy_SealOfSacrifice", words = { "First Aid", "Physician", "Surgeon" } },
	{ key = "fishing", icon = ICONS .. "Trade_Fishing", words = { "Fish", "Angler" } },
}
for _, p in ipairs(M.PROFESSIONS) do
	p.profession = true
	M.BY_KEY[p.key] = p
end

-- the craft a title names, as an entry of M.PROFESSIONS, or nil
function M.ProfessionOf(title)
	if type(title) ~= "string" or F.Secret(title) then
		return nil
	end
	for _, p in ipairs(M.PROFESSIONS) do
		for _, word in ipairs(p.words) do
			if title:find(word, 1, true) then
				return p
			end
		end
	end
	return nil
end

-- CLASS PICTURES (Josh 2026-10-04: "would it be possible to use class icons
-- for the class trainers?"), the same way: a class trainer's title names its
-- class, and it wears the game's own icon for it - the "classicon-mage"
-- pictures the client's UI draws (GetClassAtlas), or, on a client without
-- them, that class's square on the old character-creation sheet, cut round.
-- A weapon master teaches no one class and keeps the menu's picture.
M.CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
M.CLASS_TRAINERS = {}
for _, c in ipairs({
	{ "WARRIOR", "Warrior", { 0, 0.25, 0, 0.25 } }, { "MAGE", "Mage", { 0.25, 0.49609375, 0, 0.25 } },
	{ "ROGUE", "Rogue", { 0.49609375, 0.7421875, 0, 0.25 } }, { "DRUID", "Druid", { 0.7421875, 0.98828125, 0, 0.25 } },
	{ "HUNTER", "Hunter", { 0, 0.25, 0.25, 0.5 } }, { "SHAMAN", "Shaman", { 0.25, 0.49609375, 0.25, 0.5 } },
	{ "PRIEST", "Priest", { 0.49609375, 0.7421875, 0.25, 0.5 } }, { "WARLOCK", "Warlock", { 0.7421875, 0.98828125, 0.25, 0.5 } },
	{ "PALADIN", "Paladin", { 0, 0.25, 0.5, 0.75 } },
}) do
	local role = { key = "class-" .. c[2]:lower(), class = c[1], words = { c[2] }, atlas = "classicon-" .. c[2]:lower(),
		icon = M.CLASS_SHEET, coords = c[3], profession = true }
	M.CLASS_TRAINERS[#M.CLASS_TRAINERS + 1] = role
	M.BY_KEY[role.key] = role
end

-- the class a title names, as an entry of M.CLASS_TRAINERS, or nil
function M.ClassOf(title)
	if type(title) ~= "string" or F.Secret(title) then
		return nil
	end
	for _, c in ipairs(M.CLASS_TRAINERS) do
		if title:find(c.words[1], 1, true) then
			return c
		end
	end
	return nil
end

-- a trainer made particular by its title: its class, or its craft; any other
-- role as it is
function M.Sharpen(role, title)
	if role and role.key == "class" then
		return M.ClassOf(title) or role
	elseif role and role.key == "trainer" then
		return M.ProfessionOf(title) or role
	end
	return role
end
-- the cursors that name a role outright, and the families the words choose in
M.CURSOR_ROLE = { Repairnpc = "repair", Repair = "repair", Taxi = "flight", Innkeeper = "inn", Stablemaster = "stable" }
M.CURSOR_FAMILY = {
	Trainer = { class = true, trainer = true },
	Buy = { bank = true, auction = true, repair = true, food = true, reagents = true, poisons = true, ammo = true,
		vendor = true },
}
M.CURSOR_FALLBACK = { Trainer = "trainer", Buy = "vendor" }

-- the game's cursor for a unit: the cursor's name with any "Unable" (too
-- far) taken off ("Buy", "Repairnpc", "Trainer", "Speak", "Point"...), true
-- for one whose name cannot be read, nil for none, false when the game will
-- not be asked
function M.CursorOf(token)
	local set = _G.SetUnitCursorTexture
	if type(set) ~= "function" then
		return false
	end
	-- NOT IN A FIGHT (Josh 2026-10-04, "Let's do 1-4"): whether the game
	-- blocks this call in combat is not known, and a blocked call is
	-- "Interface action failed because of an AddOn", as CheckInteractDistance
	-- was. What you learned and the words answer until the fight ends.
	if inCombat() then
		return false
	end
	local probe = M.probeTexture
	if not probe then
		probe = UIParent:CreateTexture(nil, "BACKGROUND")
		probe:Hide()
		M.probeTexture = probe
	end
	-- THE GAMEPAD'S PICTURE, THEN THE MOUSE'S (the same day: "The game does
	-- have a hover cursor for the flightmaster though"): the game's own
	-- soft-target icon asks for the gamepad's set, the "Crosshair" pictures,
	-- and that answered nothing for a flight master; the mouse's set is the
	-- cursor you see when you point at it
	local mouse = Enum and Enum.CursorStyle and Enum.CursorStyle.Mouse or 0
	local tries = { { nil, true }, { mouse, false } }
	local ok, has
	for _, try in ipairs(tries) do
		pcall(probe.SetTexture, probe, nil)
		ok, has = pcall(set, probe, token, try[1], nil, try[2])
		if not ok then
			return false
		end
		if not F.Secret(has) and has then
			break
		end
	end
	if F.Secret(has) or not has then
		return nil
	end
	local okT, tex = pcall(probe.GetTexture, probe)
	tex = okT and tex or nil
	if F.Secret(tex) or type(tex) ~= "string" then
		return true
	end
	return M.CursorName(tex) or true
end

-- a cursor's kind from its picture's name: "Cursor Crosshair_UnableBuy_64"
-- (the gamepad's) or "Interface\\Cursor\\Taxi" (the mouse's), with any
-- "Unable" (too far) taken off, or nil
function M.CursorName(tex)
	if type(tex) ~= "string" then
		return nil
	end
	local mode = tex:match("Crosshair_(%a+)_") or tex:match("[Cc]ursor[\\/ _]+(%a+)%.?%a*$")
	if not mode then
		return nil
	end
	mode = mode:gsub("^[Uu]nable", "")
	-- the mouse set's names start in lower or upper case alike
	return mode:sub(1, 1):upper() .. mode:sub(2)
end

-- [npc id] = the role learned by talking to it, kept in the saved file
function M.Learned()
	if type(BeebModDB) ~= "table" then
		return {}
	end
	BeebModDB.npcRoles = BeebModDB.npcRoles or {}
	return BeebModDB.npcRoles
end

local function npcOf(guid)
	return type(guid) == "string" and not F.Secret(guid) and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or nil
end

-- [npc id] = its title, as the game writes it, once read
M.titles = {}
-- an NPC's title, from its tooltip the first time and kept after; nil for
-- none, or for a tooltip not ready yet, which is asked again next time
function M.TitleOf(token)
	local npc = npcOf(F.Plain(UnitGUID, token))
	if npc and M.titles[npc] then
		return M.titles[npc]
	end
	local title = M.Subtitle(token)
	if type(title) ~= "string" or F.Secret(title) then
		return nil
	end
	if npc then
		M.titles[npc] = title
	end
	return title
end

-- [npc id] = the role the cursor and the words gave, or false for none,
-- for the session: a quest cursor is not kept, since a quest comes and goes
M.roles = {}
function M.RoleOf(token)
	local npc = npcOf(F.Plain(UnitGUID, token))
	local learned = npc and M.Learned()[npc]
	if learned and M.BY_KEY[learned] then
		-- a trainer kept before its class or craft was read (Priestess
		-- Josetta, the same day): read from its title now, and kept so
		if learned == "class" or learned == "trainer" then
			local sharp = M.Sharpen(M.BY_KEY[learned], M.TitleOf(token))
			if sharp.key ~= learned then
				M.Learned()[npc] = sharp.key
			end
			return sharp
		end
		return M.BY_KEY[learned]
	end
	local role, tipName
	if npc and M.roles[npc] ~= nil then
		role = M.roles[npc] or nil
	else
		local title
		title, tipName = M.Subtitle(token)
		if npc and type(title) == "string" and not F.Secret(title) then
			M.titles[npc] = title
		end
		local words = M.RoleFor(title) or M.RoleInName(F.Plain(UnitName, token) or tipName)
		local cursor = M.CursorOf(token)
		local keep = true
		if cursor == false or cursor == true then
			-- the game not asked, or its cursor not read: the words alone
			role = words
		elseif cursor == nil or cursor == "Point" then
			-- NO CURSOR IS NOT NO ROLE (the same day: "Not seeing an icon for
			-- the flightmaster", Gryth Thurden, <Gryphon Master>, in Ironforge):
			-- the game gave a flight master no cursor, so a title or a name
			-- that says what an NPC does still counts; the cursor only adds
			-- one the words miss, and sharpens one they find
			role = words
		elseif M.CURSOR_ROLE[cursor] then
			role = M.BY_KEY[M.CURSOR_ROLE[cursor]]
		elseif M.CURSOR_FAMILY[cursor] then
			local family = M.CURSOR_FAMILY[cursor]
			role = words and family[words.key] and words or M.BY_KEY[M.CURSOR_FALLBACK[cursor]]
		else
			-- talking, or a quest: the words say what else it does
			role = words
			keep = not cursor:find("^Quest") and not cursor:find("^CampaignQuest")
		end
		role = M.Sharpen(role, title)
		-- in a fight it was the words alone: asked again once it is over
		if npc and keep and not inCombat() then
			M.roles[npc] = role or false
		end
	end
	if not role and M.InCapital() then
		-- the name as the game gives it, or off the tooltip when that is hidden
		local name = F.Plain(UnitName, token)
		if not name then
			name = tipName or select(2, M.Subtitle(token))
		end
		if M.GivesDirections(name, true) then
			role = M.DIRECTIONS
		end
	end
	return role
end

-- what talking to an NPC says it is, by the game's interaction types
M.INTERACTION = { [6] = "flight", [8] = "bank", [20] = "inn", [21] = "auction", [22] = "stable", [23] = "battle" }
M.MERCHANT, M.VENDOR, M.TRAINER = 5, 12, 7
-- learned from the NPC you are talking to; every plate of its kind repainted
function M.Learn(kind)
	local npc = npcOf(F.Plain(UnitGUID, "npc"))
	if not npc then
		return nil
	end
	local key = M.INTERACTION[kind]
	if kind == M.MERCHANT or kind == M.VENDOR then
		local ok, repairs = pcall(_G.CanMerchantRepair or error)
		if ok and not F.Secret(repairs) and repairs then
			key = "repair"
		else
			-- a merchant who does not repair: what its words say it sells
			local words = M.RoleFor(M.Subtitle("npc")) or M.RoleInName(F.Plain(UnitName, "npc"))
			key = words and M.CURSOR_FAMILY.Buy[words.key] and words.key ~= "repair" and words.key or "vendor"
		end
	elseif kind == M.TRAINER then
		local title = M.Subtitle("npc")
		local words = M.RoleFor(title)
		key = M.Sharpen(words and words.key == "class" and words or M.BY_KEY.trainer, title).key
	end
	if not key then
		return nil
	end
	BT.EnsureBound()
	M.Learned()[npc] = key
	for token, f in pairs(M.friends) do
		if f:IsShown() and npcOf(F.Plain(UnitGUID, token)) == npc then
			M.PaintFriend(f, F.Source(token))
		end
	end
	return key
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
	-- coloured by how far from yours, as on the unit frames (F.LevelTag)
	f.level:SetText(player and F.LevelTag(src) or "")
	F.AlphaFrom(f.under, src:IsTarget(), 1, 0)
	-- a pet: its owner under the name, and nothing it sells
	local owned = not player and f.bmUnit and M.Owned(f.bmUnit) or false
	local role = not player and not owned and f.bmUnit and M.RoleOf(f.bmUnit) or nil
	-- UNDER THE NAME (Josh 2026-10-04: "I think NPCs still need their tag
	-- under their nameplates as well", "<Priest trainer> <Physician> etc"): a
	-- pet's owner, or an NPC's title as the game writes it - its capitals
	-- too, since a title can hold a place, as in "Warsong Gulch Battlemaster"
	local line = ""
	if owned then
		line = not M.Mine(f.bmUnit) and M.OwnerTag((M.Subtitle(f.bmUnit))) or ""
	elseif not player and f.bmUnit then
		local title = M.TitleOf(f.bmUnit)
		line = title and ("<" .. title .. ">") or ""
	end
	f.sub:SetText(line)
	f.sub:SetTextColor(M.FRIEND_SUB[1], M.FRIEND_SUB[2], M.FRIEND_SUB[3])
	if role then
		if role.atlas and M.HasAtlas(role.atlas) and f.role.SetAtlas then
			f.role:SetAtlas(role.atlas)
			M.Round(f, "atlas")
		else
			f.role:SetTexture(M.RoleIcon(role))
			M.Round(f, role.profession and "square" or nil, role.coords)
		end
		f.role:Show()
	else
		f.role:Hide()
	end
end

-- whether the client has a picture by that atlas name
function M.HasAtlas(name)
	local get = _G.C_Texture and _G.C_Texture.GetAtlasInfo
	if type(get) ~= "function" then
		return false
	end
	local ok, info = pcall(get, name)
	return ok and type(info) == "table"
end

-- A PROFESSION'S ICON IS CUT ROUND. It is a square picture with its own
-- edge, where the tracking menu's are shapes on nothing; trimmed, cut to a
-- circle and a size down, it sits beside them as one of the set. `shape` is
-- "square" for such a picture (`coords`, the part of a sheet that is it),
-- "atlas" for one the game cuts out itself, nil for the menu's.
M.PROFESSION_SIZE = 20
M.ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function M.Round(f, shape, coords)
	local on = shape ~= nil
	local size = on and M.PROFESSION_SIZE or M.ROLE_SIZE
	f.role:SetSize(size, size)
	-- an atlas sets its own corners; anything else is set every time, since
	-- a picture keeps the last one's
	if shape ~= "atlas" and f.role.SetTexCoord then
		local c = coords or { 0, 1, 0, 1 }
		if on then
			local w, h = (c[2] - c[1]) * 0.08, (c[4] - c[3]) * 0.08
			f.role:SetTexCoord(c[1] + w, c[2] - w, c[3] + h, c[4] - h)
		else
			f.role:SetTexCoord(c[1], c[2], c[3], c[4])
		end
	end
	if on and not f.roleMask and f.CreateMaskTexture then
		local ok, mask = pcall(f.CreateMaskTexture, f)
		if ok and mask then
			pcall(mask.SetTexture, mask, M.ROUND_MASK, "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
			mask:SetAllPoints(f.role)
			f.roleMask = mask
		end
	end
	if f.roleMask and (f.bmRound or false) ~= on then
		f.bmRound = on
		local apply = on and f.role.AddMaskTexture or f.role.RemoveMaskTexture
		if apply then
			pcall(apply, f.role, f.roleMask)
		end
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
		-- (a friend past the first M.PLATES tokens has no enemy frame: its
		-- name's frame waits instead)
		local waiter = s or M.Friend(token)
		if C_Timer and C_Timer.After and not waiter.bmWaiting then
			waiter.bmWaiting = true
			C_Timer.After(0, function()
				waiter.bmWaiting = nil
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
		if M.IsTotem(token) then
			-- a totem: the game's frame is away, and nothing goes in its place
			hideFriend(token)
			return true
		end
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
	"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"UNIT_LEVEL" }) do
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
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
		-- talking to an NPC: what it is, learned (M.Learn); `token` is the type
		if type(token) == "number" then
			M.Learn(token)
		end
	elseif event == "UNIT_NAME_UPDATE" then
		-- a friend's name the game had not sent yet
		local f = type(token) == "string" and M.friends[token]
		if f and f:IsShown() then
			M.PaintFriend(f, F.Source(token))
		end
	elseif event == "UNIT_LEVEL" then
		-- a friend's new level; yours changes the colour of everyone's
		for t, f in pairs(M.friends) do
			if f:IsShown() and (token == "player" or t == token) then
				M.PaintFriend(f, F.Source(t))
			end
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
-- The NPC record (the Testing page's Record button)
-- ---------------------------------------------------------------------------
--
-- WHAT THE GAME SAYS AN NPC IS (Josh 2026-10-04: "Is there a better way to
-- handle this besides name matching? Do NPCs have a flag or something else in
-- the API we could use?", then "Let's do that"). No flag reaches an addon, but
-- the cursor the game shows over a unit is chosen from its flags - buy,
-- repair, trainer, taxi, innkeeper, stable master - and SetUnitCursorTexture
-- draws it onto a texture: the call the game's own soft-target icons make.
-- The game makes it only for the unit you soft-target, so whether it answers
-- for any plate in view is what this finds out. For each friendly NPC's plate
-- in view: its name, the title read, the role BeebMod picks, whether the game
-- calls it interactable, and the cursor it draws, with and without the
-- low-priority ones; and the zone and its map, for the capitals.
local function describe(v)
	if F.Secret(v) then
		return "SECRET(" .. type(v) .. ")"
	end
	if type(v) == "string" then
		return ("%q"):format(v:sub(1, 40))
	end
	return tostring(v)
end

function M.Dump()
	local lines = {}
	local probe = M.probeTexture
	if not probe then
		probe = UIParent:CreateTexture(nil, "BACKGROUND")
		probe:Hide()
		M.probeTexture = probe
	end
	local function cursor(token, low, style, gamepad)
		local set = _G.SetUnitCursorTexture
		if type(set) ~= "function" then
			return "no SetUnitCursorTexture"
		end
		if inCombat() then
			return "not asked in a fight"
		end
		pcall(probe.SetTexture, probe, nil)
		local ok, has = pcall(set, probe, token, style, low, gamepad)
		if not ok then
			return "error " .. tostring(has):sub(1, 60)
		end
		local okT, tex = pcall(probe.GetTexture, probe)
		local okA, atlas = false, nil
		if probe.GetAtlas then
			okA, atlas = pcall(probe.GetAtlas, probe)
		end
		return ("has=%s tex=%s atlas=%s"):format(describe(has), describe(okT and tex or nil), describe(okA and atlas or nil))
	end
	local map
	if C_Map and C_Map.GetBestMapForUnit then
		local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
		map = ok and m or nil
	end
	local zone = _G.GetRealZoneText and _G.GetRealZoneText() or nil
	lines[#lines + 1] = ("zone=%s map=%s capital=%s"):format(describe(zone), describe(map), tostring(M.InCapital()))
	for i = 1, 40 do
		local token = M.Token(i)
		local src = F.Source(token)
		if F.Plain(UnitExists, token) and not src:CanAttack() and not src:IsPlayer() then
			local title, tipName = M.Subtitle(token)
			local role = M.RoleOf(token)
			local interactable = F.Raw(_G.UnitIsInteractable, token)
			-- and whether a player controls it, for a pet's owner line (M.Owned)
			local controlled = F.Raw(_G.UnitPlayerControlled, token)
			lines[#lines + 1] = ("%s %s | title=%s | role=%s | controlled=%s | owner=%s | interactable=%s | cursor %s | low %s"):format(token,
				describe(F.Plain(UnitName, token) or tipName), describe(title), role and role.key or "none",
				describe(controlled), describe(M.OwnerTag(title)), describe(interactable),
				cursor(token, nil, nil, true), cursor(token, true, nil, true))
			-- and the mouse's pictures, which the gamepad's may not have
			local mouse = Enum and Enum.CursorStyle and Enum.CursorStyle.Mouse or 0
			lines[#lines + 1] = ("    mouse %s | mouse low %s | kind %s"):format(cursor(token, nil, mouse, false),
				cursor(token, true, mouse, false), tostring(M.CursorOf(token)))
		end
	end
	BT.EnsureBound()
	BeebModDB.nameplatesDump = { at = BT.Util.Now(), lines = lines }
	return #lines
end

BT.Record("nameplatesDump", M.Dump, "nameplates")

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
-- Its parts
-- ---------------------------------------------------------------------------

-- THE NAMEPLATES' PARTS, under their row on the Unit frames page (the
-- settings canvas, Josh 2026-10-04)
function M:Parts()
	return {
		{ label = "Friendly players and NPCs", field = "friends",
			get = function() return opt("friends", true) and true or false end,
			set = function(on)
				-- on is the default, so only off is written down (written out:
				-- `(not on) and false or nil` is nil either way)
				if on then
					M.SetOpt("friends", nil)
				else
					M.SetOpt("friends", false)
				end
				M.Sweep()
			end },
		{ label = "Pets and minions", field = "minions",
			get = function() return opt("minions", true) and true or false end,
			set = function(on)
				if on then
					M.SetOpt("minions", nil)
				else
					M.SetOpt("minions", false)
				end
				M.ShowMinions(on)
			end },
	}
end
