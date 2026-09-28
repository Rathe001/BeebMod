-- The Menagerie's book: every kind of mob you have killed (Josh 2026-09-25).
--
-- NO LIST OF MOBS. Every creature's GUID carries its NPC id, so the first kill
-- of an id is a new page - this client's mobs are its own (ids around 250000
-- on Zephras Isle), and no list of the old game's would have had them. What
-- the page says about the mob - its name, type, family and rank - is read off
-- the living unit (Kills.lua) and kept once, for every character.
--
--   menagerie.mobs[npc]    what a mob is: name, kind (the creature type),
--                          family, rank, levels, the zone it was first met in
--                          and the spot on that zone's map (map, mx, my)
--   menagerie.chars[who]   one character's: kills[npc], first[npc], feats,
--                          earned[achievement id] = when it was earned, and
--                          the last few GUIDs counted, so a reload and a
--                          corpse looted after it are one kill, not two
--
-- ACHIEVEMENTS ARE THE SCORE (Josh 2026-09-25: "base the score off
-- achievement points rather than completion"). Without a list of every mob
-- there is no "73% complete" to show, but there is always a next milestone -
-- and every kind killed is worth a point or more of its own (J.Worth), and
-- every mob killed often enough a mastery (J.MASTERY).
-- Points are worked out from the kills every time they are asked for, so a
-- character's points and the account's are the same arithmetic on different
-- counts, and changing a milestone here changes everyone's score at once.
-- `earned` only remembers WHEN, and which toasts have been shown.
--
-- Pure Lua - no frames - so the headless tests load it as it is.
local _, BT = ...

local U = BT.Util
local J = {}
BT.Menagerie = J

-- EVERY KIND IS WORTH SOMETHING (Josh 2026-09-25: "give some points for each
-- unique enemy killed as well, not just the breakpoint achievements"), and a
-- rarer one more. A rank not read yet is worth what an ordinary mob is - a
-- kind we could not rank is still a kind - and it is worked out again every
-- time, so the day the rank is read the points follow.
--
-- BY HOW HARD IT IS AND HOW OFTEN YOU MEET ONE (Josh 2026-09-27: "It should be
-- based on how difficult the mob is and also the rarity that it will be
-- encountered in the world"). The client's rank alone put a rabbit with a
-- wolf, a dungeon's trash with Hogger, and Van Cleef with a Defias Pirate, so
-- a mob is put in one of nine categories (J.Category), from its rank, its
-- creature type, whether it was met in a dungeon or a raid, and whether it
-- was a boss there. A first kill is worth what meeting and beating one is;
-- each mastery's kills are set so a metal takes about as long to earn
-- whatever the mob - about forty an hour of an ordinary mob, fifteen of a
-- dungeon's trash a run, a rare an hour or two of waiting, a boss a run, a
-- raid a lockout - so the metals are worth the same 2, 3, 5 and 10 for every
-- one. A grey kill counts like any other (Josh: "Level 60s should be able to
-- run old content if they want to try to get platinum for missed mobs").
J.CATEGORIES = {
	worldboss = { word = "World Boss", many = "World bosses", points = 20, at = { 1, 2, 3, 5 } },
	raidboss = { word = "Raid Boss", many = "Raid bosses", points = 15, at = { 1, 3, 6, 12 } },
	dungeonboss = { word = "Dungeon Boss", many = "Dungeon bosses", points = 6, at = { 2, 5, 10, 25 } },
	rareelite = { word = "Rare Elite", many = "Rare elites", points = 8, at = { 2, 4, 8, 15 } },
	rare = { word = "Rare", many = "Rares", points = 5, at = { 2, 4, 8, 15 } },
	elite = { word = "Elite", many = "Elites", points = 3, at = { 3, 10, 30, 100 } },
	dungeonelite = { word = "Dungeon Elite", many = "Dungeon elites", points = 2, at = { 5, 25, 75, 250 } },
	normal = { word = "Normal", many = "Normal mobs", points = 1, at = { 10, 50, 150, 500 } },
	critter = { word = "Critter", many = "Critters", points = 1, at = { 20, 100, 300, 1000 } },
}
J.KIND_ORDER = { "worldboss", "raidboss", "dungeonboss", "rareelite", "rare", "elite", "dungeonelite", "normal",
	"critter" }
J.KIND_POINTS, J.KIND_WORDS, J.MASTERY_AT = {}, {}, {}
for key, cat in pairs(J.CATEGORIES) do
	J.KIND_POINTS[key], J.KIND_WORDS[key], J.MASTERY_AT[key] = cat.points, cat.many, cat.at
end

-- WHERE A MOB WAS MET, FOR A MOB MET BEFORE IT WAS NOTED (Josh 2026-09-27).
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

-- The category mob `m` (its record) is scored and shown as - a key of
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
--   kinds       ~500: 450 at a point, 40 elites, 15 rares     ~ 660
--   masteries   Bronze on ~200, Silver ~40, Gold ~8, one Plat ~ 570
--   milestones  discovery, kills, types, rares, zones, feats   ~ 410
-- so ~1,650 thoroughly and ~1,100 at an ordinary pace: Taxonomist to
-- Loresage at 60, and the last two for whoever stays to master their mobs.
-- The saved file says what real play earns; move these when it does.
J.RANKS = {
	{ 0, "Novice" }, { 50, "Scribbler" }, { 150, "Observer" }, { 300, "Chronicler" }, { 500, "Scholar" },
	{ 800, "Lorekeeper" }, { 1200, "Taxonomist" }, { 1800, "Loresage" }, { 2600, "Savant" },
	{ 3600, "Polymath" },
}

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
-- WHAT A MOB IS NAMED AFTER (Josh 2026-09-26). The journal fills as you kill,
-- so there is no list of mobs to look up ahead of time - but there is a list
-- of what they are named after: races, tribes and clans, animals, beast
-- families, creature types. scripts/fetch-lore.ps1 gathers the wiki's
-- opening lines on all of them (Modules/Menagerie/LoreData.lua, CC BY-SA),
-- and a mob is matched here by the words of its name, then its family, then
-- its type.
--
--   "Burly Rockjaw Trogg"   rockjaw (the Rockjaw tribe), then trogg (a race)
--   "Frostmane Troll Whelp" frostmane (the Frostmane tribe), then troll
--   "Prideclaw"             no word of it has a page; its family, Cat, does

-- how specific each kind of page is: a mob's own, then a tribe or clan, a
-- race, an animal, a beast family, a creature type
local KIND_RANK = { npc = 6, group = 5, race = 4, beast = 3, family = 2, type = 1 }

-- words too common to be what a mob is named after, however a page is titled
local COMMON = {}
for w in ([[young elder old great greater lesser large small giant mature adult wild feral rabid
	diseased mangy vicious savage fierce frenzied infected corrupted burly lost lord king queen chief
	captain guard guardian warrior shaman mystic seer brute thug bandit servant the of a an and
	dark black red blue green grey gray white golden silver shadow blood fire frost ice stone
	elite champion scout sentry watcher hunter defender protector bruiser runt whelp]]):gmatch("%S+") do
	COMMON[w] = true
end

-- The types whose page says nothing about a particular mob ("A humanoid
-- usually has two arms, two legs, and one head"): a card whose best match is
-- one of these says what the journal knows instead. The page is still shown
-- in full on the mob's own page. Elemental, Undead, Demon and the rest say
-- something, and stay.
local PLAIN_TYPES = { Humanoid = true, Beast = true, Critter = true, Mechanical = true }
-- a page shorter than this, on a card, is followed by the next that says more
local SHORT_LORE = 140

-- the data, or none: the addon works without it
local function loreData()
	return BT.MenagerieLoreData or {}
end
J.LoreData = loreData

-- A word's page, as written or as one of its kind: "harpies" is Harpy,
-- "troggs" Trogg, "wolves" Wolf. English plurals, the common ones.
function J.Singular(data, w)
	if data[w] then
		return data[w]
	end
	for _, rule in ipairs({ { "ies$", "y" }, { "ves$", "f" }, { "ves$", "fe" }, { "es$", "" }, { "s$", "" } }) do
		local s, n = w:gsub(rule[1], rule[2])
		if n > 0 and data[s] then
			return data[s]
		end
	end
	return nil
end

-- Every page that speaks of the mob, most specific first: { { kind, title,
-- text } }. A page is taken once, however many ways it matches.
-- THE SAME BODY AS ONE WE KNOW (Josh 2026-09-26: "Is there no way to
-- determine that this named mob is a harpy?" - Witchmother Arysa, one of
-- this realm's own, has no page, and her name says nothing). Every portrait
-- tells us which model file it drew (m.body); a mob whose name and pages
-- never say what it is borrows the race - or failing that the animal - of
-- another mob in the journal drawn from the same file. A tribe is not
-- borrowed: one body serves many tribes. { [body] = entry or false }, made
-- again whenever a mob's body is learnt.
local kinLore = {}
local BORROW = { race = 2, beast = 1 }

function J.Body(npc, id)
	local s = J.Store()
	local m = s and s.mobs[npc]
	if not m or type(id) ~= "number" or (issecretvalue and issecretvalue(id)) or id <= 0 or m.body == id then
		return false
	end
	m.body = id
	kinLore = {}
	return true
end

-- the page mobs with this body are: the best race or animal any of them
-- reaches by its own name and pages, and whose it was
local function kinEntry(m)
	local hit = kinLore[m.body]
	if hit == nil then
		hit = false
		local s = J.Store()
		local best
		for npc, other in pairs(s and s.mobs or {}) do
			if other.body == m.body and other ~= m then
				for _, e in ipairs(J.WikiLore(other, true)) do
					local b = BORROW[e.kind]
					if b and (not best or b > best.b) then
						best = { b = b, entry = { e.kind, e.title, e.text }, name = other.name }
					end
				end
			end
		end
		hit = best or false
		kinLore[m.body] = hit
	end
	return hit or nil
end

function J.WikiLore(m, ownOnly)
	local data = loreData()
	local out, seen = {}, {}
	-- `how` it was found, for /bt menagerie lore: its name, part of its name,
	-- what a page says it is, its body, its family, its type
	local function add(entry, weight, how)
		if entry and not seen[entry[2]] then
			seen[entry[2]] = true
			out[#out + 1] = { kind = entry[1], title = entry[2], text = entry[3], how = how,
				rank = (KIND_RANK[entry[1]] or 0) * 10 + (weight or 0) }
		end
	end
	if not (m and next(data)) then
		return out
	end
	if type(m.name) == "string" and m.name ~= "" then
		local words = {}
		for w in m.name:lower():gsub("'s%f[%A]", ""):gmatch("[%w'%-]+") do
			words[#words + 1] = w
		end
		-- its own name, whole
		add(data[table.concat(words, " ")], 9, "name")
		-- then any run of three, two or one of its words, the longer first.
		-- ANOTHER MOB'S PAGE ONLY BY TWO WORDS OR MORE (Josh 2026-09-26, when
		-- every Classic mob's page came in): "Elder Darkshore Thresher" is
		-- well served by "Darkshore Thresher", but one word of a name is no
		-- reason to take on some other creature's page as its own
		for len = math.min(3, #words), 1, -1 do
			for i = 1, #words - len + 1 do
				local phrase = table.concat(words, " ", i, i + len - 1)
				if not (len == 1 and COMMON[phrase]) then
					local e = data[phrase] or (len == 1 and J.Singular(data, phrase))
					if not (len == 1 and e and e[1] == "npc") then
						add(e, len, "part")
					end
				end
			end
		end
	end
	-- WHAT ITS OWN PAGE SAYS IT IS (Josh 2026-09-26: a Bloodfeather Sorceress
	-- had its own page - "Bloodfeather Sorceresses are harpies found in
	-- Teldrassil" - and never reached the Harpy page, since "harpy" is not in
	-- its name). The first sentence of a mob's own page, or its tribe's, names
	-- what it is; the first race there follows the pages matched so far.
	-- A race first; failing that, an animal or another creature's own page
	-- ("Oakenscowl is a timberling" - and Timberling has a page).
	local found = #out
	for i = 1, found do
		local e = out[i]
		if e.kind == "npc" or e.kind == "group" then
			local first = (e.text:match("^(.-[%.!%?])%s") or e.text):lower()
			-- NOT ITS OWN NAME (Josh 2026-09-27: "This is definitely not a
			-- cursed centaur"). "Cursed Highborne are banshees..." begins with
			-- the mob's own words, and "cursed" alone found the Cursed
			-- Centaur's page. What the sentence says it IS comes after them.
			local own = {}
			for _, said in ipairs({ e.title or "", m.name or "" }) do
				for w in said:lower():gmatch("[%a'%-]+") do
					own[w] = true
				end
			end
			local race, other
			for w in first:gmatch("[%a'%-]+") do
				local r = not COMMON[w] and not own[w] and J.Singular(data, w)
				if r and r[2] ~= e.title then
					if r[1] == "race" then
						race = race or r
					elseif r[1] == "beast" or r[1] == "npc" then
						other = other or r
					end
				end
			end
			if race or other then
				local before = #out
				add(race or other, 1, "says")
				if #out > before then
					out[#out].via = true
				end
			end
		end
	end
	-- nothing yet says what it is: what the mobs with its body are
	if m.body and not ownOnly then
		local says = false
		for _, e in ipairs(out) do
			says = says or e.kind == "race" or e.kind == "group" or e.kind == "beast"
		end
		local kin = not says and kinEntry(m)
		if kin then
			local before = #out
			add(kin.entry, 0, "body")
			if #out > before then
				out[#out].via = true
				out[#out].kin = kin.name
			end
		end
	end
	if m.family then
		add(data[m.family:lower()], 0, "family")
	end
	local kind = J.KindOf(m)
	if kind ~= J.UNTYPED then
		add(data[kind:lower()], 0, "type")
	end
	table.sort(out, function(a, b)
		return a.rank > b.rank
	end)
	return out
end

-- A LINE OF LORE (Josh 2026-09-26: "if the game had descriptions of each mob
-- we could put on the card... a lore aspect to it"). The game has none an
-- addon can read. What a quest says about the mob, where one has named it,
-- is kept with it (m.lore); otherwise a line made only from what the journal
-- knows - nothing is invented, so nothing contradicts the game.
function J.LoreLine(m)
	if not m then
		return ""
	end
	-- THE WIKI'S, MOST SPECIFIC FIRST (Josh 2026-09-26: "I like the wowpedia
	-- lore ... I do like the specific match"): the Rockjaw tribe for a
	-- Rockjaw trogg, before troggs at large
	local wiki = J.WikiLore(m)
	if wiki[1] and not (wiki[1].kind == "type" and PLAIN_TYPES[wiki[1].title]) then
		-- A LINE, THEN THE LORE: a mob's own page is often one line ("...are
		-- harpies found in Teldrassil"), and the card has room for more; the
		-- next page that says something - its race, its tribe, its kind of
		-- animal - follows it
		local text = wiki[1].text
		if #text < SHORT_LORE then
			-- a race, tribe, animal or family; or a creature's page the first
			-- one named ("is a timberling") - never a kin's one-line stub
			for i = 2, #wiki do
				local e = wiki[i]
				if (e.kind ~= "type" and e.kind ~= "npc") or e.via then
					text = text .. " " .. e.text
					break
				end
			end
		end
		return text
	end
	-- a quest's words only where they speak of the mob by name: a quest
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
		what = "creature of no known kind"
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
		out = out .. ", too strong to measure"
	end
	return out .. "."
end

-- ---------------------------------------------------------------------------
-- Lore from quests
-- ---------------------------------------------------------------------------
--
-- WHAT THE QUESTS SAY (Josh 2026-09-26). A quest that sends you after a mob
-- usually says something about it - where it came from, why it is trouble -
-- and that is the game's own writing. Every quest the log shows us is kept
-- (its title, its words, its objectives: a few hundred, the newest kept), so
-- a mob killed long after the quest was handed in still finds it. A mob's
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

-- does the quest name the mob? in an objective, or in its story
local function names(q, name)
	for _, o in ipairs(q.objectives or {}) do
		if lowerFind(o, name) then
			return "objective"
		end
	end
	if lowerFind(q.text, name) then
		return "text"
	end
	-- "the prideclaws have grown bold": the plural in the story
	if lowerFind(q.text, name .. "s") or lowerFind(q.text, name .. "es") then
		return "text"
	end
	return nil
end

-- a mob's lore from a quest, if the quest names it
local function loreFrom(q, m)
	if not (m and m.name and not m.lore) then
		return false
	end
	if not names(q, m.name) then
		return false
	end
	local line = J.LoreSentence(q.text, m.name)
	if not line or line == "" then
		return false
	end
	-- whether the line itself names the mob, or is only the quest's first
	-- sentence: only the first kind goes on a card
	local named = lowerFind(line, m.name) or lowerFind(line, m.name .. "s") or lowerFind(line, m.name .. "es")
	m.lore = { line = line, text = q.text, quest = q.title, questID = q.id, named = named or nil }
	return true
end

-- A quest the log showed us: kept, and handed to every mob that has no lore
-- yet. Returns how many mobs it gave lore to.
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
	local n = 0
	for _, m in pairs(s.mobs) do
		if loreFrom(s.quests[q.id], m) then
			n = n + 1
		end
	end
	return n
end

-- A mob new to the book looks through the quests already kept - newest
-- first, the likeliest to be about it.
function J.FindLore(m)
	local s = J.Store()
	if not (s and m and not m.lore and s.quests) then
		return false
	end
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

-- MASTERY OF ONE MOB (Josh 2026-09-25: "masteries for killing a specific
-- number of each mob ... bronze, silver, gold, platinum", worth 2, 3, 5 and
-- 10). Each is earned on the way to the next, so a mob at Platinum has been
-- worth all four - twenty points. They took the place of KillTrack's kill
-- records, which were the same idea at 100, 500 and 1000.
J.MASTERY = {
	{ n = 10, points = 2, name = "Bronze", color = { 0.80, 0.52, 0.28 } },
	{ n = 50, points = 3, name = "Silver", color = { 0.76, 0.80, 0.85 } },
	{ n = 150, points = 5, name = "Gold", color = { 1, 0.82, 0.30 } },
	{ n = 500, points = 10, name = "Platinum", color = { 0.62, 0.90, 1 } },
}

-- FEWER KILLS FOR THE RARER KINDS (Josh 2026-09-26: "Killing 500 of the same
-- rare mob would be insane... same with elites"). The kills each mastery
-- takes are the category's (J.CATEGORIES, J.MASTERY_AT); the metals and their
-- points are the same for every mob. J.MASTERY's own `n` is an ordinary mob's.
local ladders = {}
-- the four masteries for mob `m` (its record, or nil for an ordinary one):
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
-- This client has mobs of no type: Living Lightning on Zephras Isle is "Not
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
	-- (Modules/Menagerie/Demo.lua)
	if J.demo then
		return J.demo
	end
	if not BT.settings then
		return nil
	end
	local s = BT.settings.menagerie
	if type(s) ~= "table" then
		s = {}
		BT.settings.menagerie = s
	end
	s.mobs = s.mobs or {}
	s.chars = s.chars or {}
	return s
end

local function fresh(c)
	c.kills = c.kills or {}
	c.first = c.first or {}
	c.earned = c.earned or {}
	c.feats = c.feats or {}
	c.recent = c.recent or {}
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

-- the type a mob is filed under
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

-- What a mob is, from whatever the living unit said. Each field is taken when
-- it is known and kept when it is not: a rank the client hid mid-fight is not
-- "normal", it is the rank we read last time (or nothing yet).
function J.Learn(info, now)
	local s = J.Store()
	if not (s and info and info.npc) then
		return nil
	end
	local m = s.mobs[info.npc]
	if not m then
		m = {}
		s.mobs[info.npc] = m
	end
	for _, field in ipairs({ "name", "kind", "family", "rank" }) do
		local v = info[field]
		if type(v) == "string" and v ~= "" then
			m[field] = v
		end
	end
	-- met in a dungeon or a raid, and a boss there (J.Category): kept once
	-- known - one kill in the open world does not make a dungeon's mob less
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
	-- spot kept, and a mob killed before spots were kept takes its next one
	if (not m.mx or m.spotGuess) and type(info.map) == "number" and type(info.mx) == "number"
		and type(info.my) == "number" then
		m.map, m.mx, m.my, m.spotGuess = info.map, info.mx, info.my, nil
	end
	m.seen = now or U.Now()
	-- a name to go by: any quest already kept that speaks of it
	if m.name and not m.lore then
		J.FindLore(m)
	end
	return m
end

-- A SPOT UNTIL THERE IS A REAL ONE (Josh 2026-09-26: "still not seeing the
-- portrait backgrounds"). Spots are kept from the kill, so a mob killed
-- before they were has none until it is killed again. Standing in its zone,
-- we know that zone's map, and it takes the middle of it - marked a guess,
-- so its next kill puts the real spot in its place. Returns how many.
function J.GuessSpots(zone, map)
	local s = J.Store()
	if not (s and type(zone) == "string" and zone ~= "" and type(map) == "number") then
		return 0
	end
	local n = 0
	for _, m in pairs(s.mobs) do
		if not m.mx and m.zone == zone then
			m.map, m.mx, m.my, m.spotGuess = map, 0.5, 0.5, true
			n = n + 1
		end
	end
	return n
end

-- A BOSS FIGHT WON (ENCOUNTER_END): the mob of that name in the journal is a
-- boss, where the client would not say so of the unit. An encounter named for
-- no one mob ("The Seven") names nothing. Whether one was marked.
function J.EncounterWon(name)
	local s = J.Store()
	if not (s and type(name) == "string" and name ~= "") then
		return false
	end
	for _, m in pairs(s.mobs) do
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
-- earned by it - achievements and masteries - for the toasts.
function J.Kill(info, now)
	local c = J.Mine()
	if not (c and info and info.npc) then
		return false, {}
	end
	now = now or U.Now()
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
	J.rev = (J.rev or 0) + 1
	return was == 0, J.Check(c, now, npc, was)
end

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

-- kills[npc] and feats for "char" (this character) or "account" (every
-- character added together; a feat counts once anyone has done it)
function J.Counts(scope)
	local s = J.Store()
	if not s then
		return {}, {}
	end
	if scope ~= "account" then
		local c = J.Mine()
		return c.kills, c.feats, c
	end
	local kills, feats = {}, {}
	for _, c in pairs(s.chars) do
		for npc, n in pairs(c.kills or {}) do
			kills[npc] = (kills[npc] or 0) + n
		end
		for k, v in pairs(c.feats or {}) do
			feats[k] = math.min(feats[k] or v, v)
		end
	end
	return kills, feats
end

-- everything the achievements are measured against, from one set of counts
function J.Stats(kills, feats)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local st = {
		kinds = 0, total = 0, byType = {}, families = 0, rares = 0, elites = 0, bosses = 0, zones = 0,
		feats = feats or {},
	}
	local fam, zone = {}, {}
	for npc, n in pairs(kills or {}) do
		st.kinds = st.kinds + 1
		st.total = st.total + n
		local m = mobs[npc] or {}
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
		if m.rank == "worldboss" then
			st.bosses = st.bosses + 1
		end
		if m.zone and not zone[m.zone] then
			zone[m.zone] = true
			st.zones = st.zones + 1
		end
	end
	return st
end

-- the types to list and to have achievements for: the client's usual ones,
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
-- The achievements
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
	{ 500, 25, "Encyclopedist" }, { 750, 25, "Grand Archivist" }, { 1000, 50, "The Menagerie" },
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

-- Every achievement there is, measured against `st`. The type ones are made
-- for whatever types are in the list, so a type this client adds has its own.
function J.List(st)
	st = st or J.Stats()
	local out = {}
	tiers(out, "discover", "kinds", st.kinds, DISCOVER, "kill %d different kinds of mob")
	tiers(out, "slaughter", "total", st.total, SLAUGHTER, "kill %d mobs")
	for _, kind in ipairs(J.Types(st)) do
		for _, t in ipairs(TYPE_TIERS) do
			out[#out + 1] = {
				id = "type:" .. kind .. ":" .. t[1], group = "types", kind = kind,
				title = ("%s Hunter %s"):format(kind, t[3]), points = t[2], need = t[1],
				have = st.byType[kind] or 0,
				text = ("kill %d different kinds of %s"):format(t[1], kind:lower()),
			}
		end
	end
	tiers(out, "types", "family", st.families, FAMILIES, "kill beasts of %d different families")
	for _, t in ipairs(RARES) do
		out[#out + 1] = {
			id = "rare:" .. t[1], group = "rank", title = t[3], points = t[2], need = t[1], have = st.rares,
			text = ("kill %d %s"):format(t[1], plural(t[1], "rare", "different rares")),
		}
	end
	tiers(out, "rank", "elite", st.elites, ELITES, "kill %d different kinds of elite")
	out[#out + 1] = {
		id = "boss:1", group = "rank", title = "Worldbreaker", points = 25, need = 1, have = st.bosses,
		text = "kill a world boss",
	}
	tiers(out, "world", "zones", st.zones, ZONES, "meet your kills in %d different zones")
	out[#out + 1] = {
		id = "feat:up5", group = "world", title = "Punching Up", points = 10, need = 1,
		have = st.feats.up5 and 1 or 0, text = "kill a mob five or more levels above you",
	}
	out[#out + 1] = {
		id = "feat:skull", group = "world", title = "Skull and Bones", points = 25, need = 1,
		have = st.feats.skull and 1 or 0, text = "kill a mob whose level is a skull",
	}
	return out
end

-- What one mob is worth with `n` kills of it: the kind's own points and every
-- mastery earned on it - what a heading in the compendium adds up
function J.MobPoints(m, n)
	local _, worth = J.Worth(m)
	local tier = J.Mastery(n, m)
	for i = 1, tier do
		worth = worth + J.MASTERY[i].points
	end
	return worth
end

-- The mastery `n` kills of one mob have reached: its number (0 for none yet)
-- and its entry, and the next one's entry (nil past Platinum). `mob` is its
-- record, whose rank sets the kills each takes (an ordinary mob's without).
function J.Mastery(n, mob)
	n = n or 0
	local ladder = J.Ladder(mob)
	local tier = 0
	for i, m in ipairs(ladder) do
		if n >= m.n then
			tier = i
		end
	end
	return tier, ladder[tier], ladder[tier + 1]
end

local function mobOf(npc)
	local s = J.Store()
	return s and s.mobs[npc]
end

-- Every mastery a set of counts holds, added up: the points, and per tier how
-- many mobs are AT it (a Gold mob is counted under Gold, though it earned
-- Bronze and Silver on the way) and what the tier's own step has earned
-- across every mob past it - { [tier] = { mobs, points } }.
function J.Masteries(kills)
	local total, byTier = 0, {}
	for i in ipairs(J.MASTERY) do
		byTier[i] = { mobs = 0, points = 0 }
	end
	for npc, n in pairs(kills or {}) do
		local tier = J.Mastery(n, mobOf(npc))
		if tier > 0 then
			byTier[tier].mobs = byTier[tier].mobs + 1
			for i = 1, tier do
				byTier[i].points = byTier[i].points + J.MASTERY[i].points
				total = total + J.MASTERY[i].points
			end
		end
	end
	return total, byTier
end

-- the masteries nearest to being earned: { npc, have, need, tier } for the
-- `limit` mobs furthest along toward their next one
function J.NextMasteries(kills, limit)
	local out = {}
	for npc, n in pairs(kills or {}) do
		local tier, _, nxt = J.Mastery(n, mobOf(npc))
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

-- What the kinds themselves are worth: the total, and per rank how many kinds
-- and how many points - { worldboss = { kinds, points }, ... }
function J.KindPoints(kills)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local total, byRank = 0, {}
	for npc in pairs(kills or {}) do
		local rank, p = J.Worth(mobs[npc])
		local r = byRank[rank] or { kinds = 0, points = 0 }
		byRank[rank] = r
		r.kinds = r.kinds + 1
		r.points = r.points + p
		total = total + p
	end
	return total, byRank
end

-- points, how many achievements, the stats they came from, and how many of
-- the points are the kinds' own and the masteries'
function J.Points(kills, feats)
	local st = J.Stats(kills, feats)
	local kindPoints = J.KindPoints(kills)
	local masteryPoints = J.Masteries(kills)
	local points, count = kindPoints + masteryPoints, 0
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need then
			points = points + a.points
			count = count + 1
		end
	end
	return points, count, st, kindPoints, masteryPoints
end

-- The score for "char" or "account", with the stats it came from.
function J.Score(scope)
	local kills, feats = J.Counts(scope)
	return J.Points(kills, feats)
end

-- What this character has just earned: every achievement now met that has no
-- date yet (dated now, and handed back for a toast), and the mastery this one
-- kill of `npc` reached, if it reached one.
function J.Check(c, now, npc, was)
	local news = {}
	local st = J.Stats(c.kills, c.feats)
	for _, a in ipairs(J.List(st)) do
		if a.have >= a.need and not c.earned[a.id] then
			c.earned[a.id] = now
			news[#news + 1] = a
		end
	end
	if npc then
		local mob = mobOf(npc)
		local before = J.Mastery(was or 0, mob)
		local tier, m = J.Mastery(c.kills[npc] or 0, mob)
		if tier > before then
			local id = ("mastery:%d:%d"):format(npc, tier)
			c.earned[id] = c.earned[id] or now
			news[#news + 1] = {
				id = id, mastery = true, npc = npc, tier = tier, name = m.name, need = m.n, points = m.points,
			}
		end
	end
	return news
end

-- the next discovery milestone: the last one passed, and the one ahead
function J.NextDiscovery(kinds)
	local prev = 0
	for _, t in ipairs(DISCOVER) do
		if kinds < t[1] then
			return prev, t[1], t[3]
		end
		prev = t[1]
	end
	return prev, nil, nil
end

-- ---------------------------------------------------------------------------
-- The journal's list
-- ---------------------------------------------------------------------------

-- a mob with no zone on record, filed last when the journal goes by zone
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
-- to be found somewhere in the mob, but loosely: without capitals or
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

-- what a mob is searched by: { text, weight, loose }, the name first
function J.SearchFields(m)
	local fields = {}
	local function add(text, weight, loose)
		if type(text) == "string" and text ~= "" then
			local f = fold(text)
			fields[#fields + 1] = { f, weight, loose, words(f) }
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

-- How well `query` matches mob `m`: a score, or nil when some word typed is
-- found nowhere. An empty query matches everything, at nothing.
function J.Match(query, m)
	local qs = words(fold(query))
	if #qs == 0 then
		return 0
	end
	local fields = J.SearchFields(m or {})
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

-- the mobs of `list` ({ npc, n, m }) that `query` matches, the best first and
-- the rest in the order they came
function J.Search(list, query)
	local out = {}
	for i, e in ipairs(list) do
		local score = J.Match(query, e.m)
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

-- Every mob the counts have, in sections: { { kind, mobs = { { npc, n, m } } } }.
-- VIEWS (Josh 2026-09-25: "by type like we currently have, by zone. Then
-- sort by Alphabetical or mastery"). `by` is "type" - the client's usual
-- order, the untyped last - or "zone", A to Z with the unknown last; `sort` is
-- "name" or "mastery". `kind` is the section's key whichever it is.
-- a list of mobs, in one of the two orders ("All" on the rail sorts every
-- section's mobs together)
function J.SortMobs(list, sort)
	table.sort(list, SORTS[sort] or byName)
	return list
end

function J.Pages(kills, by, sort)
	local s = J.Store()
	local mobs = s and s.mobs or {}
	local byKey = {}
	for npc, n in pairs(kills or {}) do
		local m = mobs[npc] or {}
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
			out[#out + 1] = { kind = key, mobs = list }
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
