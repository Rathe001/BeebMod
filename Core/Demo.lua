-- Made-up data, for screenshots (Josh 2026-09-27: "are you able to mock some
-- data for me so we can show off all the features/designs?").
--
-- ONE SWITCH, NOTHING SAVED. While it is on, each feature shows a made-up
-- world instead of yours: a realm's worth of characters in the census, notes
-- on a dozen of them (and on you) in the ledger, a journal of enemies at every
-- rank and mastery in the Expedition, a party on the unit frames. Each
-- feature makes its own (it registers here), so a feature that is off - or
-- not there - simply has nothing to show. Nothing is written into your saved
-- books; the switch is off again after a reload, and switching it off puts
-- everything back as it was.
--
--   BT.Demo.Register(key, { on = fn, off = fn, world = fn })
--     on/off   swap your data out and back in
--     world    after a loading screen, which binds your real books again
--   BT.Demo.People(n)   the same made-up people for every feature that asks
local _, BT = ...

local U = BT.Util
local D = { on = false, parts = {} }
BT.Demo = D

function D.Register(key, part)
	part.key = key
	D.parts[#D.parts + 1] = part
end

function D.IsOn()
	return D.on
end

-- a small generator of its own, seeded, so the made-up realm is the same
-- realm every time it is shown
function D.Random(seed)
	local s = seed or 1
	return function(a, b)
		s = (s * 1103515245 + 12345) % 2147483648
		local r = s / 2147483648
		if a then
			return a + math.floor(r * (b - a + 1))
		end
		return r
	end
end

local GIVEN = { "Aeri", "Bran", "Cael", "Dorn", "Elun", "Fae", "Garr", "Hald", "Ith", "Jor", "Kael", "Lira",
	"Mor", "Nyss", "Orin", "Pell", "Quen", "Rhea", "Syl", "Thar", "Ulm", "Vess", "Wyn", "Yrs", "Zel", "Bael",
	"Cor", "Dael", "Eld", "Fen" }
local ENDS = { "a", "en", "is", "or", "wyn", "ric", "ael", "ith", "an", "ia", "on", "ra", "ius", "ea", "" }
local SUR = { "Ash", "Black", "Bright", "Cinder", "Dawn", "Ember", "Frost", "Gold", "Grim", "Iron", "Moon",
	"Night", "Oak", "Raven", "Shadow", "Silver", "Stone", "Storm", "Sun", "Thorn", "Wind", "Wolf", "Hollow",
	"Amber", "Flint" }
local SUR_END = { "blade", "brook", "fall", "forge", "heart", "mane", "song", "strider", "vale", "ward",
	"whisper", "wood", "shield", "bane", "hammer", "crest" }

-- the playable races of a side, as the client names them, and what each can be
local RACES = {
	Alliance = {
		Human = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		Dwarf = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST" },
		NightElf = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" },
		Gnome = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK" },
	},
	Horde = {
		Orc = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" },
		Scourge = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		Tauren = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
		Troll = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" },
	},
}
-- how many of each, roughly: humans and night elves, orcs and undead lead
local RACE_WEIGHT = { Human = 32, NightElf = 30, Dwarf = 20, Gnome = 18, Orc = 30, Scourge = 28, Troll = 22, Tauren = 20 }

local GUILDS = { "Night Watch", "House Fortemps", "The Silver Hand", "Ashen Verdict", "Wolfpack", "Nomads",
	"Stormwind Guard", "Dawnbreakers", "The Last Light", "Iron Oath", "Moonglade Circle", "Blackrock Irregulars",
	"Old Guard", "Emerald Dreamers", "Tavern Regulars", "Gnomeregan Exiles", "Kingsguard", "The Wandering",
	"Hearthstone", "Sunwell Remnant", "Stonecutters", "Late Night Pugs", "Deeprun Rats", "Bank Alts Anonymous" }

-- zones by the levels they are for
local ZONES = {
	{ 1, 12, { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades" } },
	{ 10, 22, { "Westfall", "Loch Modan", "Darkshore", "The Barrens", "Silverpine Forest", "Redridge Mountains" } },
	{ 18, 32, { "Duskwood", "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains" } },
	{ 30, 45, { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Dustwallow Marsh", "Swamp of Sorrows" } },
	{ 42, 55, { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Felwood", "Azshara" } },
	{ 53, 60, { "Un'Goro Crater", "Burning Steppes", "Winterspring", "Western Plaguelands", "Silithus" } },
	{ 60, 60, { "Ironforge", "Stormwind City", "Orgrimmar", "Blackrock Mountain", "Eastern Plaguelands" } },
}

local function pickWeighted(rand, weights)
	local total = 0
	for _, w in pairs(weights) do
		total = total + w
	end
	local at = rand() * total
	local keys = {}
	for k in pairs(weights) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		at = at - weights[k]
		if at <= 0 then
			return k
		end
	end
	return keys[#keys]
end

local people
-- `n` made-up characters of your side: { name, class, race, level, guild,
-- zone, ago = seconds since last seen, formerGuild? }. The same list each
-- time, and the first ones the same whatever `n` is.
function D.People(n)
	if people and #people >= n then
		return people
	end
	local faction = (BT.scope and BT.scope.faction) or (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
	local races = RACES[faction] or RACES.Alliance
	local weights = {}
	for race in pairs(races) do
		weights[race] = RACE_WEIGHT[race] or 20
	end
	local rand = D.Random(4242)
	local out, used = {}, {}
	while #out < n do
		local name = GIVEN[rand(1, #GIVEN)] .. ENDS[rand(1, #ENDS)] .. " " .. SUR[rand(1, #SUR)] .. SUR_END[rand(1, #SUR_END)]
		if not used[name] then
			used[name] = true
			local race = pickWeighted(rand, weights)
			local classes = races[race]
			local roll = rand()
			local level = roll < 0.33 and rand(1, 15) or roll < 0.62 and rand(16, 40)
				or roll < 0.84 and rand(41, 59) or 60
			local zones
			for _, z in ipairs(ZONES) do
				if level >= z[1] and level <= z[2] then
					zones = z[3]
				end
			end
			-- a few big guilds and a long tail, and some in none
			local guild = ""
			if rand() < 0.72 then
				guild = GUILDS[math.min(#GUILDS, 1 + math.floor((rand() ^ 2.2) * #GUILDS))]
			end
			local seen = rand()
			local ago = seen < 0.4 and rand(60, 20 * 3600) or seen < 0.7 and rand(86400, 6 * 86400)
				or seen < 0.9 and rand(7 * 86400, 29 * 86400) or rand(30 * 86400, 80 * 86400)
			out[#out + 1] = {
				name = name, race = race, class = classes[rand(1, #classes)], level = level, guild = guild,
				zone = zones[rand(1, #zones)], ago = ago,
				formerGuild = rand() < 0.06 and GUILDS[rand(1, #GUILDS)] or nil,
			}
		end
	end
	people = out
	return people
end

-- everything that shows the data, drawn again
local function redraw()
	if BT.DB then
		BT.DB.rev = (BT.DB.rev or 0) + 1
	end
	if BT.Notes then
		BT.Notes.Touched(true)
	end
	local C = BT.CensusWindow
	if C then
		C.drawnAt, C.drawnTime = nil, nil
		pcall(C.Tick)
	end
	for _, f in ipairs({ BT.Window and BT.Window.Refresh, BT.ExpeditionWindow and BT.ExpeditionWindow.Refresh,
		BT.Find and BT.Find.Refresh, BT.Dock and BT.Dock.Update }) do
		pcall(f)
	end
end

function D.Set(on)
	on = on and true or false
	if on == D.on then
		return D.on
	end
	BT.EnsureBound()
	D.on = on
	D.failed = nil
	for _, part in ipairs(D.parts) do
		local fn = on and part.on or part.off
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				D.failed = D.failed or {}
				D.failed[#D.failed + 1] = part.key .. ": " .. tostring(err)
			end
		end
	end
	redraw()
	return D.on
end

-- a loading screen binds your real books again: the made-up ones go back in
function D.World()
	if not D.on then
		return
	end
	for _, part in ipairs(D.parts) do
		if part.world then
			pcall(part.world)
		end
	end
	redraw()
end
BT.OnWorld(function()
	D.World()
end)

BT.Command("demo", function(rest)
	local want = (rest or ""):lower()
	local on
	if want == "on" then
		on = true
	elseif want == "off" then
		on = false
	else
		on = not D.on
	end
	D.Set(on)
	U.Print(D.on and "Made-up data is on. The census, the Ledger, the Expedition, the unit frames and the buff tray show made-up data. BeebMod saves none of it. Type /bt demo off to see your own again."
		or "Made-up data is off. Your own data is back.")
	for _, line in ipairs(D.failed or {}) do
		U.Print("|cffff6b6bCould not make up data for|r " .. line)
	end
end, "demo [on|off] - show made-up data in every feature, for screenshots. BeebMod saves none of it.")
