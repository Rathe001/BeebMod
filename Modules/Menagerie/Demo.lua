-- The Menagerie's made-up journal (Core/Demo.lua, Josh 2026-09-27): real
-- Classic mobs, so their models and their lore are real, at every creature
-- type, every rank - ordinary, elite, rare, rare elite, world boss - and every
-- mastery from none to Platinum, over a dozen zones, with the achievements
-- that earns. None of it is saved: while it is shown the journal reads this
-- store instead of yours (J.Store), and a kill made meanwhile is made here.
local _, BT = ...

local J = BT.Menagerie
local unpack = unpack or table.unpack

-- npc, name, type, family, rank, level (-1 a skull), zone, map, kills
local MOBS = {
	{ 6, "Kobold Vermin", "Humanoid", nil, "normal", 2, "Elwynn Forest", 1429, 612 },
	{ 299, "Young Wolf", "Beast", "Wolf", "normal", 2, "Elwynn Forest", 1429, 188 },
	{ 721, "Rabbit", "Critter", nil, "normal", 1, "Elwynn Forest", 1429, 16 },
	{ 448, "Hogger", "Humanoid", nil, "elite", 11, "Elwynn Forest", 1429, 26 },
	{ 36, "Harvest Golem", "Mechanical", nil, "normal", 12, "Westfall", 1436, 57 },
	{ 117, "Riverpaw Gnoll", "Humanoid", nil, "normal", 10, "Westfall", 1436, 44 },
	{ 515, "Murloc Raider", "Humanoid", nil, "normal", 11, "Westfall", 1436, 9 },
	{ 832, "Dust Devil", "Elemental", nil, "normal", 18, "Westfall", 1436, 14 },
	{ 345, "Bellygrub", "Beast", "Boar", "elite", 24, "Redridge Mountains", 1433, 5 },
	{ 48, "Skeletal Warrior", "Undead", nil, "normal", 26, "Duskwood", 1431, 64 },
	{ 412, "Stitches", "Undead", nil, "elite", 35, "Duskwood", 1431, 1 },
	{ 522, "Mor'Ladim", "Undead", nil, "rareelite", 35, "Duskwood", 1431, 10 },
	{ 14887, "Ysondre", "Dragonkin", nil, "worldboss", -1, "Duskwood", 1431, 1 },
	{ 682, "Stranglethorn Tiger", "Beast", "Cat", "normal", 32, "Stranglethorn Vale", 1434, 77 },
	{ 1042, "Red Whelp", "Dragonkin", nil, "normal", 22, "Wetlands", 1437, 12 },
	{ 2022, "Timberling", "Elemental", nil, "normal", 5, "Teldrassil", 1438, 152 },
	{ 2042, "Nightsaber", "Beast", "Cat", "normal", 7, "Teldrassil", 1438, 3 },
	{ 7319, "Lady Sathrah", "Beast", "Spider", "rare", 12, "Teldrassil", 1438, 20 },
	{ 2185, "Darkshore Thresher", "Beast", nil, "normal", 17, "Darkshore", 1439, 23 },
	{ 3943, "Ruuzel", "Humanoid", nil, "rare", 25, "Ashenvale", 1440, 5 },
	{ 5618, "Wastewander Bandit", "Humanoid", nil, "normal", 44, "Tanaris", 1446, 131 },
	{ 7153, "Deadwood Warrior", "Humanoid", nil, "normal", 48, "Felwood", 1448, 61 },
	{ 6498, "Devilsaur", "Beast", "Devilsaur", "elite", 52, "Un'Goro Crater", 1449, 75 },
	{ 10200, "Rak'shiri", "Beast", "Cat", "rare", 57, "Winterspring", 1452, 2 },
	{ 7431, "Frostsaber", "Beast", "Cat", "normal", 55, "Winterspring", 1452, 3 },
	{ 6109, "Azuregos", "Dragonkin", nil, "worldboss", -1, "Azshara", 1447, 5 },
	{ 12397, "Lord Kazzak", "Demon", nil, "worldboss", -1, "Blasted Lands", 1419, 2 },
}

local store

local function build()
	local U = BT.Util
	local now = U.Now()
	local rand = BT.Demo.Random(77)
	local s = { mobs = {}, chars = {}, sessions = {}, demo = true }
	local kills, first, altKills = {}, {}, {}
	for i, row in ipairs(MOBS) do
		local npc, name, kind, family, rank, level, zone, map, n = unpack(row)
		s.mobs[npc] = {
			name = name, kind = kind, family = family, rank = rank,
			lo = level > 0 and level or nil, hi = level > 0 and level or nil, skull = level < 0 or nil,
			zone = zone, map = map, mx = 0.2 + rand() * 0.6, my = 0.2 + rand() * 0.6,
			seen = now - i * 3600,
		}
		kills[npc] = n
		first[npc] = now - (40 - i) * 86400
		-- an alt has met a few of them too, for "All characters"
		if i % 3 == 0 then
			altKills[npc] = math.max(1, math.floor(n / 3))
		end
	end
	local me = (U.MeKey and U.MeKey()) or "?"
	s.chars[me] = { kills = kills, first = first, earned = {}, recent = {},
		feats = { skull = now - 5 * 86400, up5 = now - 9 * 86400 } }
	s.chars["Beeb Magus-" .. ((U.HomeRealm and U.HomeRealm()) or "?")] = {
		kills = altKills, first = {}, earned = {}, feats = {}, recent = {} }
	return s
end

BT.Demo.Register("menagerie", {
	on = function()
		store = store or build()
		J.demo = store
		-- the achievements it has earned, dated
		local c = J.Mine()
		if c and not next(c.earned) then
			J.Check(c, BT.Util.Now() - 86400)
		end
	end,
	off = function()
		J.demo = nil
	end,
})
