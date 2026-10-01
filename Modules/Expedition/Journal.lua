-- The Expedition's book: every enemy you have killed (Josh 2026-09-25).
--
-- NO LIST OF ENEMIES. Every creature's GUID carries its NPC id, so the first kill
-- of an id is a new page - this client's enemies are its own (ids around 250000
-- on Zephras Isle), and no list of the old game's would have had them. What
-- the page says about the enemy - its name, type, family and rank - is read off
-- the living unit (Kills.lua) and kept once, for every character.
--
--   expedition.enemies[npc]  what an enemy is: name, kind (the creature type),
--                            family, rank, levels, the zone it was first met
--                            in and the spot on that zone's map (map, mx, my)
--   expedition.chars[who]    one character's: kills[npc], first[npc], feats,
--                            earned[commendation id] = when it was earned, and
--                            the last few GUIDs counted, so a reload and a
--                            corpse looted after it are one kill, not two
--
-- COMMENDATIONS ARE THE SCORE (Josh 2026-09-25: "base the score off
-- commendation points rather than completion"). Without a list of every enemy
-- there is no "73% complete" to show, but there is always a next milestone -
-- and every unique kill is worth a point or more of its own (J.Worth), and
-- every enemy killed often enough a mastery (J.MASTERY).
-- Points are worked out from the kills every time they are asked for, so
-- changing a milestone here changes every character's score at once.
-- `earned` only remembers WHEN, and which toasts have been shown.
--
-- Pure Lua - no frames - so the headless tests load it as it is.
local _, BT = ...

local U = BT.Util
local J = {}
BT.Expedition = J

-- EVERY KIND IS WORTH SOMETHING (Josh 2026-09-25: "give some points for each
-- unique enemy killed as well, not just the breakpoint commendations"), and a
-- rarer one more. A rank not read yet is worth what an ordinary enemy is - a
-- kind we could not rank is still a kind - and it is worked out again every
-- time, so the day the rank is read the points follow.
--
-- BY HOW HARD IT IS AND HOW OFTEN YOU MEET ONE (Josh 2026-09-27: "It should be
-- based on how difficult the enemy is and also the rarity that it will be
-- encountered in the world"). The client's rank alone put a rabbit with a
-- wolf, a dungeon's trash with Hogger, and Van Cleef with a Defias Pirate, so
-- an enemy is put in one of nine categories (J.Category), from its rank, its
-- creature type, whether it was met in a dungeon or a raid, and whether it
-- was a boss there. A first kill is worth what meeting and beating one is;
-- each mastery's kills are set so a metal takes about as long to earn
-- whatever the enemy - about forty an hour of an ordinary enemy, fifteen of a
-- dungeon's trash a run, a rare an hour or two of waiting, a boss a run, a
-- raid a lockout - so the metals are worth the same 2, 3, 5 and 10 for every
-- one. A grey kill counts like any other (Josh: "Level 60s should be able to
-- run old content if they want to try to get platinum for missed enemies").
J.CATEGORIES = {
	worldboss = { word = "World Boss", many = "World bosses", points = 20, at = { 1, 2, 3, 5 } },
	raidboss = { word = "Raid Boss", many = "Raid bosses", points = 15, at = { 1, 3, 6, 12 } },
	dungeonboss = { word = "Dungeon Boss", many = "Dungeon bosses", points = 6, at = { 2, 5, 10, 25 } },
	rareelite = { word = "Rare Elite", many = "Rare elites", points = 8, at = { 2, 4, 8, 15 } },
	rare = { word = "Rare", many = "Rares", points = 5, at = { 2, 4, 8, 15 } },
	elite = { word = "Elite", many = "Elites", points = 3, at = { 3, 10, 30, 100 } },
	dungeonelite = { word = "Dungeon Elite", many = "Dungeon elites", points = 2, at = { 5, 25, 75, 250 } },
	normal = { word = "Normal", many = "Normal enemies", points = 1, at = { 10, 50, 150, 500 } },
	critter = { word = "Critter", many = "Critters", points = 1, at = { 20, 100, 300, 1000 } },
}
J.KIND_ORDER = { "worldboss", "raidboss", "dungeonboss", "rareelite", "rare", "elite", "dungeonelite", "normal",
	"critter" }
J.KIND_POINTS, J.KIND_WORDS, J.MASTERY_AT = {}, {}, {}
for key, cat in pairs(J.CATEGORIES) do
	J.KIND_POINTS[key], J.KIND_WORDS[key], J.MASTERY_AT[key] = cat.points, cat.many, cat.at
end

-- WHERE A ENEMY WAS MET, FOR A ENEMY MET BEFORE IT WAS NOTED (Josh 2026-09-27).
-- A kill now notes whether it was in a dungeon or a raid; a kind already in
-- the journal is placed by its zone, as the client names Classic's
-- instances, until its next kill says.
J.INSTANCE_ZONES = {
	["Ragefire Chasm"] = "party", ["Wailing Caverns"] = "party", ["The Deadmines"] = "party",
	["Deadmines"] = "party", ["Shadowfang Keep"] = "party", ["Blackfathom Deeps"] = "party",
	["The Stockade"] = "party", ["Stormwind Stockade"] = "party", ["Gnomeregan"] = "party",
	["Razorfen Kraul"] = "party", ["Scarlet Monastery"] = "party", ["Razorfen Downs"] = "party",
	["Uldaman"] = "party", ["Zul'Farrak"] = "party", ["Maraudon"] = "party",
	["The Temple of Atal'Hakkar"] = "party", ["Sunken Temple"] = "party", ["Blackrock Depths"] = "party",
	["Blackrock Spire"] = "party", ["Lower Blackrock Spire"] = "party", ["Upper Blackrock Spire"] = "party",
	["Dire Maul"] = "party", ["Stratholme"] = "party", ["Scholomance"] = "party",
	["Molten Core"] = "raid", ["Onyxia's Lair"] = "raid", ["Blackwing Lair"] = "raid", ["Zul'Gurub"] = "raid",
	["Ruins of Ahn'Qiraj"] = "raid", ["Ahn'Qiraj"] = "raid", ["Temple of Ahn'Qiraj"] = "raid",
	["Naxxramas"] = "raid",
}

-- "party", "raid" or nil (the open world, or not known)
function J.InstanceOf(m)
	if not m then
		return nil
	end
	if m.instance == "party" or m.instance == "raid" then
		return m.instance
	end
	return J.INSTANCE_ZONES[m.zone]
end

-- The category enemy `m` (its record) is scored and shown as - a key of
-- J.CATEGORIES. A raid's bosses are "world bosses" to the client (a skull, a
-- ?? level), so one met in a raid is a raid boss; a boss the client or a won
-- encounter named (m.boss) is a dungeon's or a raid's by where it was. A rank
-- this client has not been seen to give ("trivial", "minus") is ordinary.
function J.Category(m)
	if not m then
		return "normal"
	end
	local rank, inst = m.rank, J.InstanceOf(m)
	if rank == "worldboss" then
		return inst == "raid" and "raidboss" or (inst == "party" and "dungeonboss") or "worldboss"
	end
	if m.boss and inst then
		return inst == "raid" and "raidboss" or "dungeonboss"
	end
	if rank == "rareelite" or rank == "rare" then
		return rank
	end
	if rank == "elite" then
		return inst and "dungeonelite" or "elite"
	end
	if m.kind == "Critter" then
		return "critter"
	end
	return "normal"
end

-- WHAT THE POINTS MAKE YOU (Josh 2026-09-25: "10 ranks which are titles based
-- on how many points the character has", from a knowledge theme - "novice to
-- savant", with Polymath above it).
-- NOT BEASTS (Josh 2026-09-25): a humanoid, an elemental and a machine are
-- in the book too, so nothing here is named for beasts but the beasts' own.
--
-- RETUNED FOR THE KINDS AND THE MASTERIES (Josh 2026-09-25: "players will
-- likely have a lot more points now"). Still a reckoning, not a measurement -
-- a run to 60, thoroughly:
--   uniques     ~500: 450 at a point, 40 elites, 15 rares     ~ 660
--   masteries   Bronze on ~200, Silver ~40, Gold ~8, one Plat ~ 570
--   milestones  discovery, kills, types, rares, zones, feats   ~ 410
-- so ~1,650 thoroughly and ~1,100 at an ordinary pace: Taxonomist to
-- Loresage at 60, and the last two for whoever stays to master their enemies.
-- The saved file says what real play earns; move these when it does.
-- THE EXPEDITION'S RANKS (Josh 2026-09-27: the journal became Nesingwary's
-- Expedition, and its ranks hunters' - "I like all of this, including the
-- rank rename to hunter themed"). The points are as they were. The top one
-- leads the expedition (Josh 2026-09-29, in place of "Nesingwary's Equal").
J.RANKS = {
	{ 0, "Greenhorn" }, { 50, "Tracker" }, { 150, "Trapper" }, { 300, "Stalker" }, { 500, "Pathfinder" },
	{ 800, "Huntsman" }, { 1200, "Big-Game Hunter" }, { 1800, "Trophy Hunter" }, { 2600, "Master of the Hunt" },
	{ 3600, "Expedition Leader" },
}

-- A RANK'S BADGE (Josh 2026-09-29): Art/Ranks/rank1.tga to rank10.tga, drawn
-- by scripts/make-badges.py from scripts/rank-badges.html
-- (written out, so the tests can check that each file is there)
J.BADGES = {
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank1",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank2",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank3",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank4",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank5",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank6",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank7",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank8",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank9",
	"Interface\\AddOns\\BeebMod\\Art\\Ranks\\rank10",
}
function J.RankBadge(n)
	n = math.max(1, math.min(#J.BADGES, math.floor(tonumber(n) or 1)))
	return J.BADGES[n]
end

-- the rank `points` earn: its number, its title, the points it began at, and
-- the next one's points and title (nil at the top)
function J.Rank(points)
	points = points or 0
	local i = 1
	for n, r in ipairs(J.RANKS) do
		if points >= r[1] then
			i = n
		end
	end
	local here, nxt = J.RANKS[i], J.RANKS[i + 1]
	return i, here[2], here[1], nxt and nxt[1], nxt and nxt[2]
end

-- ---------------------------------------------------------------------------
-- Lore from the Warcraft Wiki
-- ---------------------------------------------------------------------------
--
-- WHAT A ENEMY IS (Josh 2026-09-28: "I think we need an exact match on enemy
-- name. If none exists, we should fall back to the enemy type... I can't think
-- of a reason we should lazy match the enemy name"). Only a page whose title is
-- the enemy's whole name is its own. Matching words of a name found an Ancient
-- for "Sethir the Ancient", a satyr, and three Frostmane pages for one whelp.
-- What else the card says comes from what the game knows: the model the
-- portrait drew, the beast family, the creature type.
--
--   "Burly Rockjaw Trogg"   its own page, then Trogg (its model), Humanoid
--   "Prideclaw"             no page of its own: Cat (its family), Beast

-- The types whose page says nothing about a particular enemy ("A humanoid
-- usually has two arms, two legs, and one head"): a card whose best match is
-- one of these says what the journal knows instead. The page is still shown
-- in full on the enemy's own page. Elemental, Undead, Demon and the rest say
-- something, and stay.
local PLAIN_TYPES = { Humanoid = true, Beast = true, Critter = true, Mechanical = true }
-- a page shorter than this, on a card, is followed by the next that says more
local SHORT_LORE = 140

-- the data, or none: the addon works without it
local function loreData()
	return BT.ExpeditionLoreData or {}
end
J.LoreData = loreData

-- WHAT ITS MODEL IS (Josh 2026-09-28, on reading "Bloodfeather Sorceresses are
-- harpies" out of a page: "can that also be determined via the model?"). Every
-- portrait tells us which model file it drew (m.body), and
-- Modules/Expedition/BodyData.lua, made from the community listfile by
-- scripts/make-bodies.lua, says what that model is: creature/harpy is a harpy
-- whatever the enemy is called.
function J.Body(npc, id)
	local s = J.Store()
	local m = s and s.enemies[npc]
	if not m or type(id) ~= "number" or (issecretvalue and issecretvalue(id)) or id <= 0 or m.body == id then
		return false
	end
	m.body = id
	return true
end

-- Every page that speaks of the enemy, its own first: { { kind, title, text,
-- how } }. A page is taken once, however many ways it is reached.
function J.WikiLore(m)
	local data = loreData()
	local out, seen = {}, {}
	-- `how` it was found: its name, its model, its family, its type
	local function add(entry, how)
		if entry and not seen[entry[2]] then
			seen[entry[2]] = true
			out[#out + 1] = { kind = entry[1], title = entry[2], text = entry[3], how = how }
		end
	end
	if not (m and next(data)) then
		return out
	end
	if type(m.name) == "string" and m.name ~= "" then
		add(data[m.name:lower()], "name")
	end
	local bodies = BT.ExpeditionBodies
	if bodies and type(m.body) == "number" and bodies[m.body] then
		add(data[bodies[m.body]], "body")
	end
	if m.family then
		add(data[m.family:lower()], "family")
	end
	local kind = J.KindOf(m)
	if kind ~= J.UNTYPED then
		add(data[kind:lower()], "type")
	end
	return out
end

-- A LINE OF LORE (Josh 2026-09-26: "if the game had descriptions of each enemy
-- we could put on the card... a lore aspect to it"). The game has none an
-- addon can read. What a quest says about the enemy, where one has named it,
-- is kept with it (m.lore); otherwise a line made only from what the journal
-- knows - nothing is invented, so nothing contradicts the game.
function J.LoreLine(m)
	if not m then
		return ""
	end
	-- THE WIKI'S, ITS OWN PAGE FIRST (Josh 2026-09-26: "I like the wowpedia
	-- lore ... I do like the specific match"), then what its model is
	local wiki = J.WikiLore(m)
	if wiki[1] and not (wiki[1].kind == "type" and PLAIN_TYPES[wiki[1].title]) then
		-- A LINE, THEN THE LORE: an enemy's own page is often one line ("...are
		-- harpies found in Teldrassil"), and the card has room for more; the
		-- next page that says something - its race or its kind of animal -
		-- follows it
		local text = wiki[1].text
		if #text < SHORT_LORE then
			-- its model's race or animal, or its family
			for i = 2, #wiki do
				local e = wiki[i]
				if e.kind ~= "type" then
					text = text .. " " .. e.text
					break
				end
			end
		end
		return text
	end
	-- a quest's words only where they speak of the enemy by name: a quest
	-- giver greeting you ("I hope you're here to lend us a hand, shaman") is
	-- not lore about a trogg
	if type(m.lore) == "table" and m.lore.named and type(m.lore.line) == "string" and m.lore.line ~= "" then
		return m.lore.line
	end
	local kind = J.KindOf(m)
	local what
	if m.family then
		what = m.family:lower()
	elseif kind == J.UNTYPED then
		what = "enemy of no known type"
	else
		what = kind:lower()
	end
	local article = what:match("^[aeiou]") and "An" or "A"
	local out = ("%s %s"):format(article, what)
	if m.zone then
		-- "of" after a kind, "on" after no kind: "a creature of no known kind
		-- of Zephras Isle" read twice over
		out = out .. (kind == J.UNTYPED and not m.family and ", met on " or " of ") .. m.zone
	end
	if m.lo then
		out = out .. (", first met at level %d"):format(m.lo)
	elseif m.skull then
		out = out .. ", its level shown as a skull"
	end
	return out .. "."
end

-- ---------------------------------------------------------------------------
-- Lore from quests
-- ---------------------------------------------------------------------------
--
-- WHAT THE QUESTS SAY (Josh 2026-09-26). A quest that sends you after an enemy
-- usually says something about it - where it came from, why it is trouble -
-- and that is the game's own writing. Every quest the log shows us is kept
-- (its title, its words, its objectives: a few hundred, the newest kept), so
-- an enemy killed long after the quest was handed in still finds it. An enemy's
-- lore is the first quest that names it: in an objective ("Prideclaw slain")
-- before the story, and in the story with or without a plural.

local QUESTS_KEPT = 300
-- the longest a card's line of lore may run, in letters
local LINE_MAX = 150

local function lowerFind(hay, needle)
	return type(hay) == "string" and needle ~= "" and hay:lower():find(needle:lower(), 1, true) ~= nil
end

-- the sentence of `text` that names `name`, or its first; as one line
function J.LoreSentence(text, name)
	if type(text) ~= "string" then
		return nil
	end
	local flat = text:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	local sentences = {}
	for s in (flat .. " "):gmatch("(.-[%.!%?]+[\"']?)%s") do
		sentences[#sentences + 1] = s
	end
	if #sentences == 0 and flat ~= "" then
		sentences[1] = flat
	end
	local pick
	if name then
		for _, s in ipairs(sentences) do
			if lowerFind(s, name) then
				pick = s
				break
			end
		end
	end
	pick = pick or sentences[1]
	if pick and #pick > LINE_MAX then
		pick = pick:sub(1, LINE_MAX - 3):gsub("%s+%S*$", "") .. "..."
	end
	return pick
end

-- A QUEST'S WORDS IN LOWER CASE, ONCE (Josh 2026-09-30, review). Each look
-- for an enemy's name made a lower-case copy of every kept quest's story, and
-- a kill of an enemy no quest names looked through all of them - a few
-- milliseconds a kill with a full log. The copies are made once a session,
-- held by the quest's own table (a quest read again is a new table), and
-- never saved.
local lowered = setmetatable({}, { __mode = "k" })
local function lowerOf(q)
	local l = lowered[q]
	if not l then
		l = { text = type(q.text) == "string" and q.text:lower() or "", objectives = {} }
		for i, o in ipairs(q.objectives or {}) do
			l.objectives[i] = type(o) == "string" and o:lower() or ""
		end
		lowered[q] = l
	end
	return l
end

-- does the quest name the enemy (`name` in lower case)? in an objective, or
-- in its story - "the prideclaws have grown bold" names Prideclaw too, the
-- name being inside its plural
local function names(q, name)
	if name == "" then
		return nil
	end
	local l = lowerOf(q)
	for _, o in ipairs(l.objectives) do
		if o:find(name, 1, true) then
			return "objective"
		end
	end
	if l.text:find(name, 1, true) then
		return "text"
	end
	return nil
end

-- an enemy's lore from a quest, if the quest names it
local function loreFrom(q, m)
	if not (m and type(m.name) == "string" and not m.lore) then
		return false
	end
	if not names(q, m.name:lower()) then
		return false
	end
	local line = J.LoreSentence(q.text, m.name)
	if not line or line == "" then
		return false
	end
	-- whether the line itself names the enemy, or is only the quest's first
	-- sentence: only the first kind goes on a card
	local named = lowerFind(line, m.name)
	m.lore = { line = line, text = q.text, quest = q.title, questID = q.id, named = named or nil }
	return true
end

-- the quests kept so far, as a count that moves whenever one is kept
local questsRev = 0
-- enemy -> the name it was looked up by, and the quests then (J.FindLore)
local looked = setmetatable({}, { __mode = "k" })

-- A quest the log showed us: kept, and handed to every enemy that has no lore
-- yet. Returns how many enemies it gave lore to.
function J.QuestSeen(q)
	local s = J.Store()
	if not (s and q and q.id and type(q.text) == "string" and q.text ~= "") then
		return 0
	end
	s.quests = s.quests or {}
	s.questOrder = s.questOrder or {}
	if not s.quests[q.id] then
		s.questOrder[#s.questOrder + 1] = q.id
		while #s.questOrder > QUESTS_KEPT do
			s.quests[table.remove(s.questOrder, 1)] = nil
		end
	end
	s.quests[q.id] = { id = q.id, title = q.title, text = q.text, objectives = q.objectives }
	questsRev = questsRev + 1
	local n = 0
	for _, m in pairs(s.enemies) do
		if loreFrom(s.quests[q.id], m) then
			n = n + 1
		end
	end
	return n
end

-- An enemy new to the book looks through the quests already kept - newest
-- first, the likeliest to be about it.
-- ONCE, NOT EVERY KILL (Josh 2026-09-30, review). J.Learn asks this on every
-- kill of an enemy with no lore, which is most of them, and the answer only
-- changes when a quest is kept - and J.QuestSeen hands each new one to every
-- enemy itself. So an enemy is looked up again only under another name, or
-- once more quests have been kept.
function J.FindLore(m)
	local s = J.Store()
	if not (s and m and not m.lore and s.quests) then
		return false
	end
	local l = looked[m]
	if l and l.rev == questsRev and l.name == m.name and l.quests == s.quests then
		return false
	end
	looked[m] = { rev = questsRev, name = m.name, quests = s.quests }
	local order = s.questOrder or {}
	for i = #order, 1, -1 do
		local q = s.quests[order[i]]
		if q and loreFrom(q, m) then
			return true
		end
	end
	return false
end

-- the category a kind is scored as (J.Category), and what it is worth
function J.Worth(m)
	local cat = J.Category(m)
	return cat, J.CATEGORIES[cat].points
end

-- MASTERY OF ONE ENEMY (Josh 2026-09-25: "masteries for killing a specific
-- number of each enemy ... bronze, silver, gold, platinum", worth 2, 3, 5 and
-- 10). Each is earned on the way to the next, so an enemy at Platinum has been
-- worth all four - twenty points. They took the place of KillTrack's kill
-- records, which were the same idea at 100, 500 and 1000.
J.MASTERY = {
	{ n = 10, points = 2, name = "Bronze", color = { 0.80, 0.52, 0.28 } },
	{ n = 50, points = 3, name = "Silver", color = { 0.76, 0.80, 0.85 } },
	{ n = 150, points = 5, name = "Gold", color = { 1, 0.82, 0.30 } },
	{ n = 500, points = 10, name = "Platinum", color = { 0.62, 0.90, 1 } },
}

-- FEWER KILLS FOR THE RARER KINDS (Josh 2026-09-26: "Killing 500 of the same
-- rare enemy would be insane... same with elites"). The kills each mastery
-- takes are the category's (J.CATEGORIES, J.MASTERY_AT); the metals and their
-- points are the same for every enemy. J.MASTERY's own `n` is an ordinary enemy's.
local ladders = {}
-- the four masteries for enemy `m` (its record, or nil for an ordinary one):
-- J.MASTERY's entries, with `n` the kills each takes at its rank
function J.Ladder(m)
	local rank = J.Worth(m)
	local ladder = ladders[rank]
	if not ladder then
		local at = J.MASTERY_AT[rank] or J.MASTERY_AT.normal
		ladder = {}
		for i, tier in ipairs(J.MASTERY) do
			ladder[i] = { n = at[i], points = tier.points, name = tier.name, color = tier.color }
		end
		ladders[rank] = ladder
	end
	return ladder
end

-- the creature types the client names, in the order the journal lists them;
-- a type this list does not know (another language, a new one) is added after
J.TYPES = { "Beast", "Humanoid", "Undead", "Demon", "Dragonkin", "Elemental", "Giant", "Mechanical", "Critter" }
-- no type at all, or the client's word for none, filed together at the end.
-- This client has enemies of no type: Living Lightning on Zephras Isle is "Not
-- specified", not an elemental (Josh 2026-09-25)
J.UNTYPED = "Unclassified"

-- a type as a heading names many: "Beasts (3)" (Josh 2026-09-25). A type
-- this list does not know - another language, a new one - keeps its own word
local PLURAL = {
	Beast = "Beasts", Humanoid = "Humanoids", Demon = "Demons", Elemental = "Elementals",
	Giant = "Giants", Mechanical = "Mechanicals", Critter = "Critters",
}
function J.Plural(kind)
	return PLURAL[kind] or kind
end

-- how many counted GUIDs a character remembers across a reload
local RECENT = 200

-- ---------------------------------------------------------------------------
-- The store
-- ---------------------------------------------------------------------------

function J.Store()
	-- the made-up journal stands in for yours while it is shown
	-- (Modules/Expedition/Demo.lua)
	if J.demo then
		return J.demo
	end
	if not BT.settings then
		return nil
	end
	local s = BT.settings.expedition
	if type(s) ~= "table" then
		s = {}
		BT.settings.expedition = s
	end
	s.enemies = s.enemies or {}
	s.chars = s.chars or {}
	return s
end

local function fresh(c)
	c.kills = c.kills or {}
	c.first = c.first or {}
	c.earned = c.earned or {}
	c.feats = c.feats or {}
	c.recent = c.recent or {}
	-- the abilities list, gone (2026-09-30): the game keeps an enemy's
	-- spells from addons
	c.spells = nil
	return c
end

-- this character's page, under name and realm (Core/Session.lua)
function J.Mine()
	local s = J.Store()
	if not s then
		return nil
	end
	local c, who = BT.Session.Mine(s.chars)
	if not c then
		c = {}
		s.chars[who] = c
	end
	return fresh(c), who
end

-- the type an enemy is filed under
function J.KindOf(m)
	local k = m and m.kind
	if type(k) ~= "string" or k == "" or k == "Not specified" then
		return J.UNTYPED
	end
	return k
end

function J.IsRare(rank)
	return rank == "rare" or rank == "rareelite"
end

function J.IsElite(rank)
	return rank == "elite" or rank == "rareelite" or rank == "worldboss"
end

-- ---------------------------------------------------------------------------
-- A kill
-- ---------------------------------------------------------------------------

-- What an enemy is, from whatever the living unit said. Each field is taken when
-- it is known and kept when it is not: a rank the client hid mid-fight is not
-- "normal", it is the rank we read last time (or nothing yet).
function J.Learn(info, now)
	local s = J.Store()
	if not (s and info and info.npc) then
		return nil
	end
	local m = s.enemies[info.npc]
	if not m then
		m = {}
		s.enemies[info.npc] = m
	end
	for _, field in ipairs({ "name", "kind", "family", "rank" }) do
		local v = info[field]
		if type(v) == "string" and v ~= "" then
			m[field] = v
		end
	end
	-- met in a dungeon or a raid, and a boss there (J.Category): kept once
	-- known - one kill in the open world does not make a dungeon's enemy less
	if info.instance == "party" or info.instance == "raid" then
		m.instance = info.instance
	end
	if info.boss == true then
		m.boss = true
	end
	local lvl = tonumber(info.level)
	if lvl then
		-- -1 is the skull: above anything, and kept apart from the numbers
		if lvl < 0 then
			m.skull = true
		else
			m.lo = math.min(m.lo or lvl, lvl)
			m.hi = math.max(m.hi or lvl, lvl)
		end
	end
	if not m.zone and type(info.zone) == "string" and info.zone ~= "" then
		m.zone = info.zone
	end
	-- where on the map it was first met, for its card's background: the first
	-- spot kept, and an enemy killed before spots were kept takes its next one
	if (not m.mx or m.spotGuess) and type(info.map) == "number" and type(info.mx) == "number"
		and type(info.my) == "number" then
		m.map, m.mx, m.my, m.spotGuess = info.map, info.mx, info.my, nil
	end
	J.AddSpot(m, info.map, info.mx, info.my)
	m.seen = now or U.Now()
	-- a name to go by: any quest already kept that speaks of it
	if m.name and not m.lore then
		J.FindLore(m)
	end
	return m
end


-- ONE NAME, ONE PAGE (Josh 2026-09-28: "Getting duplicates" - two cards
-- called Skyhopper). The game can give two enemies the same name and body under
-- different ids: Zephras Isle's Enchanted Skyhopper is a Skyhopper to look
-- at, on purpose ("You won't be able to tell which are enchanted by looking
-- at them"). What you see is one kind of enemy, so it is one page: an enemy of a
-- name and creature type the journal already has goes on that page, its
-- kills added to that page's. A type not yet read matches on the name alone.
-- expedition.same[npc] = the npc whose page it is, so each id is looked up once.
-- An enemy's name in lower case is made once per name and held for the
-- session: J.PageOf compares every enemy's for each new id, and J.MergeSame
-- the names of the whole book on each loading screen.
local lowerNames, lowerFrom = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function lowerName(m)
	local name = m.name
	if lowerFrom[m] ~= name then
		lowerFrom[m], lowerNames[m] = name, name:lower()
	end
	return lowerNames[m]
end

local function sameName(a, b)
	if type(a.name) ~= "string" or a.name == "" or type(b.name) ~= "string" then
		return false
	end
	if lowerName(a) ~= lowerName(b) then
		return false
	end
	local ka, kb = J.KindOf(a), J.KindOf(b)
	return ka == kb or ka == J.UNTYPED or kb == J.UNTYPED
end

-- the npc whose page an enemy `info` = { npc, name, kind } goes on
function J.PageOf(info)
	local s = J.Store()
	if not (s and info and info.npc) then
		return info and info.npc
	end
	s.same = s.same or {}
	local to = s.same[info.npc]
	if to and s.enemies[to] then
		return to
	end
	if s.enemies[info.npc] then
		return info.npc
	end
	for npc, m in pairs(s.enemies) do
		if sameName(info, m) then
			s.same[info.npc] = npc
			return npc
		end
	end
	return info.npc
end

-- one page into another: what it is, and every character's kills of it
local function merge(s, to, from)
	local m, d = s.enemies[to], s.enemies[from]
	if d.lo then
		m.lo = math.min(m.lo or d.lo, d.lo)
	end
	if d.hi then
		m.hi = math.max(m.hi or d.hi, d.hi)
	end
	for _, field in ipairs({ "kind", "family", "rank", "zone", "instance", "body", "lore" }) do
		if m[field] == nil then
			m[field] = d[field]
		end
	end
	m.skull = m.skull or d.skull
	m.boss = m.boss or d.boss
	for _, sp in ipairs(d.spots or {}) do
		J.AddSpot(m, sp[1], sp[2], sp[3])
	end
	if (not m.mx or m.spotGuess) and d.mx and not d.spotGuess then
		m.map, m.mx, m.my, m.spotGuess = d.map, d.mx, d.my, nil
	end
	m.seen = math.max(m.seen or 0, d.seen or 0)
	for _, c in pairs(s.chars) do
		if type(c) == "table" then
			local kills, first = c.kills or {}, c.first or {}
			if kills[from] then
				kills[to] = (kills[to] or 0) + kills[from]
				kills[from] = nil
			end
			if first[from] then
				first[to] = math.min(first[to] or first[from], first[from])
				first[from] = nil
			end
			if c.last and c.last.npc == from then
				c.last.npc = to
			end
			for id, by in pairs(c.earnedBy or {}) do
				if by == from then
					c.earnedBy[id] = to
				end
			end
			-- a mastery earned on either is earned on the page, when it first was
			-- (gathered first: a key added to a table while it is walked can
			-- cut the walk short)
			local moved = {}
			for id, at in pairs(c.earned or {}) do
				local npc, tier = tostring(id):match("^mastery:(%d+):(%d+)$")
				if tonumber(npc) == from then
					moved[#moved + 1] = { id, ("mastery:%d:%s"):format(to, tier), at }
				end
			end
			for _, mv in ipairs(moved) do
				local id, mine, at = mv[1], mv[2], mv[3]
				c.earned[mine] = math.min(c.earned[mine] or at, at)
				c.earned[id] = nil
			end
		end
	end
	s.enemies[from] = nil
	s.same = s.same or {}
	s.same[from] = to
end

-- Pages already in the book for the same enemy, made one: the lowest id keeps
-- the page. How many went.
function J.MergeSame()
	local s = J.Store()
	if not s then
		return 0
	end
	local ids = {}
	for npc in pairs(s.enemies) do
		if type(npc) == "number" then
			ids[#ids + 1] = npc
		end
	end
	table.sort(ids)
	-- ONE NAME AT A TIME (Josh 2026-09-30, review). Every pair of enemies in
	-- the book was compared on each loading screen - nearly half a second for
	-- two thousand. Enemies of two names are never one page, so the ids are
	-- put with their name first, and only those of one name are compared, in
	-- the same order as before: the lowest id keeps the page.
	local byName, order = {}, {}
	for _, npc in ipairs(ids) do
		local m = s.enemies[npc]
		if type(m.name) == "string" and m.name ~= "" then
			local key = lowerName(m)
			local list = byName[key]
			if not list then
				list = {}
				byName[key] = list
				order[#order + 1] = key
			end
			list[#list + 1] = npc
		end
	end
	local n = 0
	for _, key in ipairs(order) do
		local list = byName[key]
		for i = 1, #list - 1 do
			local to = list[i]
			if s.enemies[to] then
				for k = i + 1, #list do
					local from = list[k]
					if s.enemies[from] and sameName(s.enemies[to], s.enemies[from]) then
						merge(s, to, from)
						n = n + 1
					end
				end
			end
		end
	end
	return n
end

-- WHERE IT WAS KILLED, NOT ONLY FIRST (Josh 2026-09-28: "are we able to show a
-- little map where these were killed on the details modal?"). The first spot
-- was all a card's background needed; the page's map wants each place.
-- Up to J.SPOTS of them, as { map, x, y } in m.spots, and a spot almost on
-- one already kept (J.NEAR of the map's width) is the same camp, not a new
-- place. Kills from before this have their first spot and no more.
J.SPOTS = 25
-- A CAMP IS A DOT (Josh 2026-09-28, two kills a few steps apart drawn as one
-- dot on the other): a fortieth of the map, a dot's width on the page's map
J.NEAR = 0.025

function J.AddSpot(m, map, x, y)
	if not (m and type(map) == "number" and type(x) == "number" and type(y) == "number") then
		return false
	end
	m.spots = m.spots or {}
	if #m.spots >= J.SPOTS then
		return false
	end
	for _, sp in ipairs(m.spots) do
		if sp[1] == map and math.abs(sp[2] - x) < J.NEAR and math.abs(sp[3] - y) < J.NEAR then
			return false
		end
	end
	-- four places are enough for a map a few hundred units across
	local function short(v)
		return math.floor(v * 10000 + 0.5) / 10000
	end
	m.spots[#m.spots + 1] = { map, short(x), short(y) }
	return true
end

-- the places an enemy was killed on `map` (its first map, if none is named):
-- its kept spots, or the first spot where it has only that. Not a guess.
function J.Spots(m, map)
	local out = {}
	if not m then
		return out
	end
	map = map or m.map
	-- THE FIRST KILL FIRST (Josh 2026-09-28: "It looks like one dot is
	-- large"): an enemy killed before places were kept has its first spot and
	-- a list begun later; the first spot is the first place, unless the list
	-- already has it
	local first = m.map == map and m.mx and not m.spotGuess and { x = m.mx, y = m.my } or nil
	if first then
		out[1] = first
	end
	for _, sp in ipairs(m.spots or {}) do
		if sp[1] == map then
			local same = first and math.abs(sp[2] - first.x) < J.NEAR and math.abs(sp[3] - first.y) < J.NEAR
			if not same then
				out[#out + 1] = { x = sp[2], y = sp[3] }
			end
		end
	end
	return out
end

-- A SPOT UNTIL THERE IS A REAL ONE (Josh 2026-09-26: "still not seeing the
-- portrait backgrounds"). Spots are kept from the kill, so an enemy killed
-- before they were has none until it is killed again. Standing in its zone,
-- we know that zone's map, and it takes the middle of it - marked a guess,
-- so its next kill puts the real spot in its place. Returns how many.
function J.GuessSpots(zone, map)
	local s = J.Store()
	if not (s and type(zone) == "string" and zone ~= "" and type(map) == "number") then
		return 0
	end
	local n = 0
	for _, m in pairs(s.enemies) do
		if not m.mx and m.zone == zone then
			m.map, m.mx, m.my, m.spotGuess = map, 0.5, 0.5, true
			n = n + 1
		end
	end
	return n
end

-- A BOSS FIGHT WON (ENCOUNTER_END): the enemy of that name in the journal is a
-- boss, where the client would not say so of the unit. An encounter named for
-- no one enemy ("The Seven") names nothing. Whether one was marked.
function J.EncounterWon(name)
	local s = J.Store()
	if not (s and type(name) == "string" and name ~= "") then
		return false
	end
	for _, m in pairs(s.enemies) do
		if m.name == name then
			m.boss = true
			return true
		end
	end
	return false
end

-- a GUID counted, remembered past a reload; the oldest goes first
function J.Remember(c, guid)
	if not (c and guid) then
		return
	end
	local r = c.recent
	r[#r + 1] = guid
	while #r > RECENT do
		table.remove(r, 1)
	end
end

-- One kill, of `info` = { npc, name, kind, family, rank, level, zone,
-- myLevel, guid }. Returns whether it was a new kind, and whatever was
-- earned by it - commendations and masteries - for the toasts.
function J.Kill(info, now)
	local c = J.Mine()
	if not (c and info and info.npc) then
		return false, {}
	end
	now = now or U.Now()
	-- an enemy of a name the book has is that page's (J.PageOf)
	info.npc = J.PageOf(info)
	J.Learn(info, now)
	local npc = info.npc
	local was = c.kills[npc] or 0
	c.kills[npc] = was + 1
	if was == 0 then
		c.first[npc] = now
	end
	c.last = { npc = npc, at = now }
	J.Remember(c, info.guid)
	-- the feats are about the moment, so they are decided now
	local lvl, mine = tonumber(info.level), tonumber(info.myLevel)
	if lvl and mine then
		if lvl < 0 then
			c.feats.skull = c.feats.skull or now
		elseif lvl - mine >= 5 then
			c.feats.up5 = c.feats.up5 or now
		end
	end
	return was == 0, J.Check(c, now, npc, was)
end

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

-- kills[npc] and feats for this character. JUST THIS CHARACTER (Josh
-- 2026-09-29: "Let's get rid of 'all characters' I think I'd like to keep
-- this addon personal, and that would also reduce some complexity"): the
-- journal adds no other character's kills to yours. Theirs stay in the book,
-- each shown when you play that one.
function J.Counts()
	local s = J.Store()
	if not s then
		return {}, {}
	end
	local c = J.Mine()
	return c.kills, c.feats, c
end

-- everything the commendations are measured against, from one set of counts
function J.Stats(kills, feats)
	local s = J.Store()
	local enemies = s and s.enemies or {}
	local st = {
		uniques = 0, total = 0, byType = {}, families = 0, rares = 0, elites = 0, bosses = 0, zones = 0,
		feats = feats or {},
	}
	local fam, zone = {}, {}
	for npc, n in pairs(kills or {}) do
		st.uniques = st.uniques + 1
		st.total = st.total + n
		local m = enemies[npc] or {}
		local kind = J.KindOf(m)
		st.byType[kind] = (st.byType[kind] or 0) + 1
		if m.family and not fam[m.family] then
			fam[m.family] = true
			st.families = st.families + 1
		end
		if J.IsRare(m.rank) then
			st.rares = st.rares + 1
		end
		if J.IsElite(m.rank) then
			st.elites = st.elites + 1
		end
		-- a world boss by its category, not the client's rank: a raid's bosses
		-- wear the world boss's skull too, and are raid bosses (J.Category)
		if J.Category(m) == "worldboss" then
			st.bosses = st.bosses + 1
		end
		if m.zone and not zone[m.zone] then
			zone[m.zone] = true
			st.zones = st.zones + 1
		end
	end
	return st
end

-- the types to list and to have commendations for: the client's usual ones,
-- then any other it has named, then the untyped
function J.Types(st)
	local out, have = {}, {}
	for _, k in ipairs(J.TYPES) do
		out[#out + 1] = k
		have[k] = true
	end
	local extra = {}
	for k in pairs(st and st.byType or {}) do
		if not have[k] and k ~= J.UNTYPED then
			extra[#extra + 1] = k
		end
	end
	table.sort(extra)
	for _, k in ipairs(extra) do
		out[#out + 1] = k
	end
	return out
end

-- ---------------------------------------------------------------------------
-- The commendations
-- ---------------------------------------------------------------------------

J.GROUPS = {
	{ key = "discover", title = "Discovery" },
	{ key = "slaughter", title = "Slaughter" },
	{ key = "types", title = "Creature types" },
	{ key = "rank", title = "Rare and elite" },
	{ key = "world", title = "Far and wide" },
}

-- { need, points, title }
local DISCOVER = {
	{ 10, 5, "First Pages" }, { 25, 5, "Field Notes" }, { 50, 10, "Naturalist" },
	{ 100, 10, "Collector" }, { 200, 15, "Cataloguer" }, { 350, 20, "Curator" },
	{ 500, 25, "Encyclopedist" }, { 750, 25, "Grand Archivist" }, { 1000, 50, "The Green Hills of Azeroth" },
}
local SLAUGHTER = {
	{ 100, 5, "Blooded" }, { 500, 5, "Hunter" }, { 1000, 10, "Slayer" }, { 5000, 15, "Reaper" },
	{ 10000, 20, "Scourge of the Land" }, { 25000, 25, "Extinction Event" }, { 50000, 50, "Nothing Left Standing" },
}
local TYPE_TIERS = { { 5, 5, "I" }, { 15, 10, "II" }, { 40, 15, "III" } }
local FAMILIES = { { 5, 5, "Tracker" }, { 10, 10, "Trapper" }, { 20, 20, "Beastmaster" } }
local RARES = { { 1, 10, "Rare Find" }, { 5, 10, "Rare Hunter" }, { 15, 20, "Rare Collector" }, { 30, 40, "Silver Standard" } }
local ELITES = { { 10, 5, "Elite Slayer" }, { 50, 10, "Elite Hunter" }, { 150, 20, "Elite Nemesis" } }
local ZONES = { { 5, 5, "Wanderer" }, { 15, 10, "Well Travelled" }, { 30, 20, "Everywhere at Once" } }

local function tiers(out, group, id, have, list, text)
	for _, t in ipairs(list) do
		out[#out + 1] = {
			id = id .. ":" .. t[1], group = group, title = t[3], points = t[2],
			need = t[1], have = have, text = text:format(t[1]),
		}
	end
end

local function plural(n, one, many)
	return n == 1 and one or many
end

-- Every commendation there is, measured against `st`. The type ones are made
-- for whatever types are in the list, so a type this client adds has its own.
function J.List(st)
	st = st or J.Stats()
	local out = {}
	tiers(out, "discover", "uniques", st.uniques, DISCOVER, "Reach %d unique kills")
	tiers(out, "slaughter", "total", st.total, SLAUGHTER, "Kill %d enemies")
	for _, kind in ipairs(J.Types(st)) do
		for _, t in ipairs(TYPE_TIERS) do
			out[#out + 1] = {
				id = "type:" .. kind .. ":" .. t[1], group = "types", kind = kind,
				title = ("%s Hunter %s"):format(kind, t[3]), points = t[2], need = t[1],
				have = st.byType[kind] or 0,
				text = ("Reach %d unique %s kills"):format(t[1], kind:lower()),
			}
		end
	end
	tiers(out, "types", "family", st.families, FAMILIES, "Kill beasts of %d different families")
	for _, t in ipairs(RARES) do
		out[#out + 1] = {
			id = "rare:" .. t[1], group = "rank", title = t[3], points = t[2], need = t[1], have = st.rares,
			text = ("Kill %d %s"):format(t[1], plural(t[1], "rare", "different rares")),
		}
	end
	tiers(out, "rank", "elite", st.elites, ELITES, "Reach %d unique elite kills")
	out[#out + 1] = {
		id = "boss:1", group = "rank", title = "Worldbreaker", points = 25, need = 1, have = st.bosses,
		text = "Kill a world boss",
	}
	tiers(out, "world", "zones", st.zones, ZONES, "Kill enemies in %d different zones")
	out[#out + 1] = {
		id = "feat:up5", group = "world", title = "Punching Up", points = 10, need = 1,
		have = st.feats.up5 and 1 or 0, text = "Kill an enemy 5 or more levels above you",
	}
	out[#out + 1] = {
		id = "feat:skull", group = "world", title = "Skull and Bones", points = 25, need = 1,
		have = st.feats.skull and 1 or 0, text = "Kill an enemy whose level shows as a skull",
	}
	return out
end

-- What one enemy is worth with `n` kills of it: the kind's own points and every
-- mastery earned on it - what a heading in the compendium adds up
function J.EnemyPoints(m, n)
	local _, worth = J.Worth(m)
	local tier = J.Mastery(n, m)
	for i = 1, tier do
		worth = worth + J.MASTERY[i].points
	end
	return worth
end

-- The mastery `n` kills of one enemy have reached: its number (0 for none yet)
-- and its entry, and the next one's entry (nil past Platinum). `enemy` is its
-- record, whose rank sets the kills each takes (an ordinary enemy's without).
function J.Mastery(n, enemy)
	n = n or 0
	local ladder = J.Ladder(enemy)
	local tier = 0
	for i, m in ipairs(ladder) do
		if n >= m.n then
			tier = i
		end
	end
	return tier, ladder[tier], ladder[tier + 1]
end

local function enemyOf(npc)
	local s = J.Store()
	return s and s.enemies[npc]
end

-- Every mastery a set of counts holds, added up: the points, and per tier how
-- many enemies are AT it (a Gold enemy is counted under Gold, though it earned
-- Bronze and Silver on the way) and what the tier's own step has earned
-- across every enemy past it - { [tier] = { enemies, points } }.
function J.Masteries(kills)
	local total, byTier = 0, {}
	for i in ipairs(J.MASTERY) do
		byTier[i] = { enemies = 0, points = 0 }
	end
	for npc, n in pairs(kills or {}) do
		local tier = J.Mastery(n, enemyOf(npc))
		if tier > 0 then
			byTier[tier].enemies = byTier[tier].enemies + 1
			for i = 1, tier do
				byTier[i].points = byTier[i].points + J.MASTERY[i].points
				total = total + J.MASTERY[i].points
			end
		end
	end
	return total, byTier
end

-- the masteries nearest to being earned: { npc, have, need, tier } for the
-- `limit` enemies furthest along toward their next one
function J.NextMasteries(kills, limit)
	local out = {}
	for npc, n in pairs(kills or {}) do
		local tier, _, nxt = J.Mastery(n, enemyOf(npc))
		if nxt then
			out[#out + 1] = { npc = npc, have = n, need = nxt.n, tier = tier + 1 }
		end
	end
	table.sort(out, function(a, b)
		local fa, fb = a.have / a.need, b.have / b.need
		if fa ~= fb then
			return fa > fb
		end
		return a.npc < b.npc
	end)
	for i = #out, (limit or #out) + 1, -1 do
		out[i] = nil
	end
	return out
end

-- What your unique kills are worth: the total, and per rank how many unique
-- kills and how many points - { worldboss = { uniques, points }, ... }
function J.KindPoints(kills)
	local s = J.Store()
	local enemies = s and s.enemies or {}
	local total, byRank = 0, {}
	for npc in pairs(kills or {}) do
		local rank, p = J.Worth(enemies[npc])
		local r = byRank[rank] or { uniques = 0, points = 0 }
		byRank[rank] = r
		r.uniques = r.uniques + 1
		r.points = r.points + p
		total = total + p
	end
	return total, byRank
end

-- points, how many commendations, the stats they came from, and how many of
-- the points are the unique kills' own and the masteries'
function J.Points(kills, feats)
	local st = J.Stats(kills, feats)
	local uniquePoints = J.KindPoints(kills)
	local masteryPoints = J.Masteries(kills)
	local points, count = uniquePoints + masteryPoints, 0
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need then
			points = points + a.points
			count = count + 1
		end
	end
	return points, count, st, uniquePoints, masteryPoints
end

-- This character's score, with the stats it came from.
function J.Score()
	local kills, feats = J.Counts()
	return J.Points(kills, feats)
end

-- What this character has just earned: every commendation now met that has no
-- date yet (dated now, and handed back for a toast), and the mastery this one
-- kill of `npc` reached, if it reached one.
function J.Check(c, now, npc, was)
	local news = {}
	local st = J.Stats(c.kills, c.feats)
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need and not c.earned[a.id] then
			c.earned[a.id] = now
			-- WHERE IT WAS EARNED (Josh 2026-09-28, the page redrawn: "Earned
			-- dates and where"): the enemy whose kill earned it
			if npc then
				c.earnedBy = c.earnedBy or {}
				c.earnedBy[a.id] = npc
			end
			news[#news + 1] = a
		end
	end
	if npc then
		local enemy = enemyOf(npc)
		local before = J.Mastery(was or 0, enemy)
		local tier, m = J.Mastery(c.kills[npc] or 0, enemy)
		if tier > before then
			local id = ("mastery:%d:%d"):format(npc, tier)
			c.earned[id] = c.earned[id] or now
			c.earnedBy = c.earnedBy or {}
			c.earnedBy[id] = c.earnedBy[id] or npc
			news[#news + 1] = {
				id = id, mastery = true, npc = npc, tier = tier, name = m.name, need = m.n, points = m.points,
			}
		end
	end
	return news
end

-- ---------------------------------------------------------------------------
-- The journal's list
-- ---------------------------------------------------------------------------

-- an enemy with no zone on record, filed last when the journal goes by zone
J.NOWHERE = "Unknown zone"

-- the two orders within a section: A to Z, or the highest mastery first (a
-- rare's comes with fewer kills), then the most killed, with A to Z between
-- equals
local function byName(a, b)
	local an, bn = a.m.name or "", b.m.name or ""
	if an ~= bn then
		return an < bn
	end
	return a.npc < b.npc
end
local SORTS = {
	name = byName,
	mastery = function(a, b)
		local at, bt = J.Mastery(a.n, a.m), J.Mastery(b.n, b.m)
		if at ~= bt then
			return at > bt
		end
		if a.n ~= b.n then
			return a.n > b.n
		end
		return byName(a, b)
	end,
}

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
--
-- LAZY MATCHING (Josh 2026-09-27: "a search box that ... does a search
-- through all data. We should use lazy matching here"). Every word typed has
-- to be found somewhere in the enemy, but loosely: without capitals or
-- apostrophes ("morladim"), as the start of a word or inside one, one letter
-- wrong, missing, extra or swapped ("ragnoros"), or its letters in order
-- ("rgnrs"). The loose ways are tried on the short fields only - the name,
-- the category, the type, the family, the zone - since a page of lore holds
-- nearly any letters in order; the lore is matched as it is written.

-- lower case, apostrophes gone, anything else not a letter or a digit a space
local function fold(s)
	return ((tostring(s or "")):lower():gsub("'", ""):gsub("[^%w]+", " "))
end
J.Fold = fold

local function words(s)
	local out = {}
	for w in s:gmatch("%S+") do
		out[#out + 1] = w
	end
	return out
end

-- one letter wrong, missing, extra or swapped - or none
local function within1(a, b)
	local la, lb = #a, #b
	if math.abs(la - lb) > 1 then
		return false
	end
	if a == b then
		return true
	end
	local i = 1
	while i <= la and i <= lb and a:sub(i, i) == b:sub(i, i) do
		i = i + 1
	end
	if la == lb then
		if a:sub(i + 1) == b:sub(i + 1) then
			return true
		end
		return a:sub(i, i) == b:sub(i + 1, i + 1) and a:sub(i + 1, i + 1) == b:sub(i, i)
			and a:sub(i + 2) == b:sub(i + 2)
	elseif la > lb then
		return a:sub(i + 1) == b:sub(i)
	end
	return a:sub(i) == b:sub(i + 1)
end
J.Within1 = within1

-- `q`'s letters in `w`, in order, from the same first letter
local function inOrder(q, w)
	if q:sub(1, 1) ~= w:sub(1, 1) then
		return false
	end
	local at = 1
	for i = 1, #q do
		at = w:find(q:sub(i, i), at, true)
		if not at then
			return false
		end
		at = at + 1
	end
	return true
end

-- how well one typed word `q` matches one field's folded `text` (with its
-- words `ws`), 0 for not at all; `loose` for the short fields
local function wordScore(q, text, ws, loose)
	local at = text:find(q, 1, true)
	if at then
		-- the start of a word beats the middle of one
		return (at == 1 or text:sub(at - 1, at - 1) == " ") and 3 or 2
	end
	if not loose then
		return 0
	end
	local best = 0
	for _, w in ipairs(ws) do
		if #q >= 4 and (within1(q, w) or within1(q, w:sub(1, #q))) then
			best = math.max(best, 1.5)
		elseif #q >= 3 and inOrder(q, w) then
			best = math.max(best, 1)
		end
	end
	return best
end

-- what an enemy is searched by: { text, weight, loose, words }, the name
-- first (the words only of a loose field: only those are matched word by word)
function J.SearchFields(m)
	local fields = {}
	local function add(text, weight, loose)
		if type(text) == "string" and text ~= "" then
			local f = fold(text)
			fields[#fields + 1] = { f, weight, loose, loose and words(f) or nil }
		end
	end
	add(m.name, 3, true)
	add(J.CATEGORIES[J.Category(m)].word, 2, true)
	add(J.KindOf(m), 2, true)
	add(m.family, 2, true)
	add(m.zone, 2, true)
	if m.skull then
		add("level ?? boss skull", 1)
	elseif m.lo then
		local lv = m.hi and m.hi ~= m.lo and (m.lo .. " " .. m.hi) or tostring(m.lo)
		add("level " .. lv .. " lv " .. lv, 1)
	end
	-- the lore it would show: its pages' titles and words, and a quest's
	for _, e in ipairs(J.WikiLore(m)) do
		add(e.title, 1.5)
		add(e.text, 1)
	end
	if type(m.lore) == "table" then
		add(m.lore.quest, 1)
		add(m.lore.text, 1)
	end
	return fields
end

-- MADE ONCE, NOT EVERY DRAW (Josh 2026-09-30, review). An enemy's fields fold
-- its wiki pages and quest whole, and a search typed in drew them all again
-- for every enemy on every redraw - each arrow key, each burst of kills: over
-- twenty milliseconds and ten megabytes of strings with a full journal. They
-- are kept for the session, by the enemy's own table, and made again when
-- anything they are made from has moved.
local searched = setmetatable({}, { __mode = "k" })
local SEARCHED_BY = { "name", "rank", "kind", "family", "zone", "instance", "boss", "skull", "lo", "hi", "body", "lore" }
local function fieldsOf(m)
	local c = searched[m]
	-- (the data itself: loreData() is a new empty table each time without it)
	local data, bodies = BT.ExpeditionLoreData, BT.ExpeditionBodies
	if c and c.data == data and c.bodies == bodies and c.wiki == J.WikiLore then
		local same = true
		for _, key in ipairs(SEARCHED_BY) do
			if c[key] ~= m[key] then
				same = false
				break
			end
		end
		if same then
			return c.fields
		end
	end
	c = { data = data, bodies = bodies, wiki = J.WikiLore, fields = J.SearchFields(m) }
	for _, key in ipairs(SEARCHED_BY) do
		c[key] = m[key]
	end
	searched[m] = c
	return c.fields
end

-- the score of the typed words `qs` against enemy `m`, or nil
local function matchWords(qs, m)
	local fields = fieldsOf(m)
	local total = 0
	for _, q in ipairs(qs) do
		local best = 0
		for _, f in ipairs(fields) do
			local s = wordScore(q, f[1], f[4], f[3]) * f[2]
			if s > best then
				best = s
			end
		end
		if best == 0 then
			return nil
		end
		total = total + best
	end
	return total
end

-- How well `query` matches enemy `m`: a score, or nil when some word typed is
-- found nowhere. An empty query matches everything, at nothing.
function J.Match(query, m)
	local qs = words(fold(query))
	if #qs == 0 then
		return 0
	end
	return matchWords(qs, m or {})
end

-- the enemies of `list` ({ npc, n, m }) that `query` matches, the best first and
-- the rest in the order they came
function J.Search(list, query)
	local out = {}
	local qs = words(fold(query))
	for i, e in ipairs(list) do
		local score = #qs == 0 and 0 or matchWords(qs, e.m or {})
		if score then
			out[#out + 1] = { e = e, score = score, i = i }
		end
	end
	table.sort(out, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.i < b.i
	end)
	for i, r in ipairs(out) do
		out[i] = r.e
	end
	return out
end

-- Every enemy the counts have, in sections: { { kind, enemies = { { npc, n, m } } } }.
-- VIEWS (Josh 2026-09-25: "by type like we currently have, by zone. Then
-- sort by Alphabetical or mastery"). `by` is "type" - the client's usual
-- order, the untyped last - or "zone", A to Z with the unknown last; `sort` is
-- "name" or "mastery". `kind` is the section's key whichever it is.
-- a list of enemies, in one of the two orders ("All" on the rail sorts every
-- section's enemies together)
function J.SortEnemies(list, sort)
	table.sort(list, SORTS[sort] or byName)
	return list
end

function J.Pages(kills, by, sort)
	local s = J.Store()
	local enemies = s and s.enemies or {}
	local byKey = {}
	for npc, n in pairs(kills or {}) do
		local m = enemies[npc] or {}
		local key
		if by == "zone" then
			key = (type(m.zone) == "string" and m.zone ~= "") and m.zone or J.NOWHERE
		else
			key = J.KindOf(m)
		end
		byKey[key] = byKey[key] or {}
		local list = byKey[key]
		list[#list + 1] = { npc = npc, n = n, m = m }
	end
	local order
	if by == "zone" then
		order = {}
		for key in pairs(byKey) do
			if key ~= J.NOWHERE then
				order[#order + 1] = key
			end
		end
		table.sort(order)
		order[#order + 1] = J.NOWHERE
	else
		order = J.Types({ byType = byKey })
		order[#order + 1] = J.UNTYPED
	end
	local cmp = SORTS[sort] or byName
	local out = {}
	for _, key in ipairs(order) do
		local list = byKey[key]
		if list then
			table.sort(list, cmp)
			out[#out + 1] = { kind = key, enemies = list }
		end
	end
	return out
end

-- the GUIDs this character counted lately, as a set
function J.Counted()
	local c = J.Mine()
	local set = {}
	for _, guid in ipairs(c and c.recent or {}) do
		set[guid] = true
	end
	return set
end
