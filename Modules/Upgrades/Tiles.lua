-- TANK, HEALER, DPS ON AN ITEM'S TOOLTIP (Josh 2026-11-16).
--
-- Josh: "I want the tooltip to show me a % increase/decrease in each role."
-- For the item under the mouse: your totals as you stand, then with the worn
-- piece out and this one in (Math.lua), each priced per role (Roles.lua).
-- The cells say the change in percent of your whole character, so most
-- pieces read between 0% and 5%.
--
-- The item card draws the cells (BT.OnItemCells, Core/Tooltip.lua).
--
-- A RING OR TRINKET has two pieces it could replace, and gets a row of cells
-- for each.
--
-- AND IT CHECKS ITSELF. Every time you really change a piece, the totals the
-- math expected are compared with what the game then reports, and a miss is
-- kept in the module's saved table, as `checks`. Nothing is said in chat.
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
local UP = BT.Upgrades
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Upgrades/Tiles.lua")

local Rd, M, R = UP.Read, UP.Math, UP.Roles
local T = {}
UP.Tiles = T

-- A MODULE OF BEEBMOD (Josh 2026-11-17: "I think I've decided to include
-- this in BeebMod proper instead of a separate module"). It was an addon of
-- its own, BeebMod: Upgrades, that asked BeebMod for a switch. Now it is a
-- module like any other, with its switch on the General page (UI/Settings.lua)
-- as the vendor utilities have theirs. Off, nothing here shows, checks or
-- records.
local Mod = BT.Module({
	key = "upgrades",
	title = "Upgrades on gear tooltips",
	order = 99.3,
	-- the switch it had as an addon of its own was kept in settings.extras
	OnBind = function()
		local s = BT.settings
		if type(s) == "table" and type(s.extras) == "table" then
			if s.extras.upgrades == false then
				s.modules = s.modules or {}
				s.modules.upgrades = false
			end
			s.extras = nil
		end
	end,
})
UP.Module = Mod
function UP.On()
	return BT.Enabled("upgrades")
end

local GREEN, RED, GREY = "|cff1eff00", "|cffff5a4d", "|cff9aa5a0"
local ROLES = { { "tank", "tank" }, { "healer", "healer" }, { "dps", "DPS" } }

-- A CLASS THE MODEL HAS SPELLS FOR (2026-11-17, when the warrior came after
-- the paladin: it was "a paladin" everywhere). SpellData.lua has a list for
-- each such class.
-- (The class does not change in a session, so it is asked for once.)
local covers = nil
local function covered()
	if covers == nil then
		local data = UP.SpellData
		local _, class = UnitClass("player")
		if not class then
			return false
		end
		covers = type(data) == "table" and type(data.spells) == "table" and data.spells[class] ~= nil
	end
	return covers
end
-- true where the role numbers are worked out for your class (Fights.lua
-- keeps fights only then)
UP.Covers = covered

-- your totals, rates and kit, read at most twice a second
local seen, seenAt
local function now()
	local t = GetTime()
	if seen and seenAt and t - seenAt < 0.5 then
		return seen
	end
	local s = Rd.State()
	if not s then
		return nil
	end
	seen = { state = s, rates = Rd.Rates(s), kit = Rd.Kit(s) }
	seenAt = t
	return seen
end

-- each role's first profile under its own name, its second under SECOND's
local SECOND = { tank = "threat", healer = "sustain", dps = "aoe" }
local SECOND_WORDS = { threat = "threat", sustain = "sustain", aoe = "AoE" }
-- and what the first is called beside it, with Shift held
local FIRST_WORDS = { tank = "survival", healer = "output", dps = "single" }

local function price(s, kit)
	return {
		tank = R.Survival(s, kit), healer = R.Healing(s, kit), dps = R.Damage(s, kit),
		threat = R.Threat(s, kit), sustain = R.Sustain(s, kit), fight = R.FightHealing(s, kit),
		aoe = R.Damage(s, kit, { enemies = R.AoeEnemies(kit) }),
	}
end

-- THE CHANGE PER ROLE FOR THIS ITEM, in percent, for each piece it could
-- replace: one for most slots, two for a ring or a trinket. Each is
-- { swap, change = { tank, healer, dps, threat, sustain, aoe }, seal }.
function T.Compare(link)
	local n = now()
	if not n then
		return nil
	end
	local before = price(n.state, n.kit)
	local out = {}
	for _, swap in ipairs(Rd.Swaps(link)) do
		-- the new piece as it is priced: its stats, what its "Use:" gives,
		-- and any set bonus it starts (Rd.Priced, Rd.SetChange)
		local new = Rd.Priced(link)
		for k, v in pairs(swap.gains or {}) do
			new[k] = (new[k] or 0) + v
		end
		-- and the piece from your bags that goes on with it (Rd.Partner)
		for k, v in pairs(swap.with and Rd.Priced(swap.with) or {}) do
			new[k] = (new[k] or 0) + v
		end
		-- (a weapon specialization: the kind of weapon held after the swap)
		local hands = swap.twoHand
		if hands == nil then
			hands = n.state.twoHand
		end
		local lifts = n.state.lifts
		if swap.weapons and not swap.weapons.ranged then
			swap.weapons.lift = M.Lift(lifts, hands)
		end
		local after = M.Swap(n.state, n.rates, swap.worn, new, swap.weapons)
		after.liftPhysical = M.Lift(lifts, hands) / M.Lift(lifts, n.state.twoHand)
		after.liftHoly = M.Lift(lifts, hands, true) / M.Lift(lifts, n.state.twoHand, true)
		if swap.shield ~= nil then
			after.shield = swap.shield
		end
		if swap.twoHand ~= nil then
			after.twoHand = swap.twoHand
		end
		if swap.dagger ~= nil then
			after.dagger = swap.dagger
		end
		-- the off hand's swings after it (Roles.lua, the rogue)
		if swap.off ~= nil then
			R.OffHand(after, swap.off)
		end
		local worth = price(after, n.kit)
		local change = {}
		for key, was in pairs(before) do
			change[key] = R.Change(was, worth[key])
		end
		-- `all` is the one number a role (R.Combine); `change` its parts
		-- WHAT THE NUMBERS LEAVE OUT, SAID OVER THE TILES (Josh 2026-11-17:
		-- "Let's fix 1-4"). An effect that is not a stat cannot be priced,
		-- and a spell whose description did not read is left out of the
		-- sums. Either way the numbers were shown as if they were whole.
		local notes = {}
		if swap.partly then
			notes[#notes + 1] = T.NOTE_EFFECT
		end
		if n.kit.unread and #n.kit.unread > 0 then
			notes[#notes + 1] = T.NOTE_SPELLS
		end
		-- a way fought in a form that has not been seen yet (Read.lua, Rd.Forms)
		for _, spec in pairs(n.kit.specs or {}) do
			if spec.form and not (n.state.forms and n.state.forms[spec.form]) then
				notes[#notes + 1] = T.NOTE_FORMS
				break
			end
		end
		out[#out + 1] = { swap = swap, change = change, all = R.Combine(change), seal = select(2, R.Damage(after, n.kit)),
			note = #notes > 0 and table.concat(notes, " · ") or nil }
	end
	return out
end

T.NOTE_EFFECT = "One effect is not counted"
T.NOTE_SPELLS = "Some of your spells could not be read"
T.NOTE_FORMS = "Go into Cat Form and Bear Form once to count them"

-- what a two-slot piece's rows are called: "ring 1", "ring 2"
local PAIRS = { [11] = "ring 1", [12] = "ring 2", [13] = "trinket 1", [14] = "trinket 2", [16] = "main hand", [17] = "off hand" }

local function named(wornLink)
	return type(wornLink) == "string" and wornLink:match("%[(.-)%]") or "empty"
end

local function link(tip, data)
	if type(data) == "table" then
		if data.guid and C_Item.GetItemLinkByGUID then
			local l = C_Item.GetItemLinkByGUID(data.guid)
			if l then
				return l
			end
		end
		if type(data.hyperlink) == "string" then
			return data.hyperlink
		end
	end
	if TooltipUtil and TooltipUtil.GetDisplayedItem then
		local _, l = TooltipUtil.GetDisplayedItem(tip)
		return l
	end
	return nil
end

-- FOR BEEBMOD'S NEW ITEM CARD (Josh 2026-11-16, the tooltip redesign: "I like
-- option B"): the same numbers as tiles, and the Shift breakdown as a grid
-- whose three columns are the three roles.
local UP_INK, DOWN_INK, FLAT_INK = { 0.44, 0.86, 0.55 }, { 1, 0.54, 0.40 }, { 0.60, 0.65, 0.63 }
local function figure(v)
	if not v or math.abs(v) < 0.05 then
		return "0.0%", FLAT_INK
	end
	return ("%+.1f%%"):format(v), v < 0 and DOWN_INK or UP_INK
end

-- A row of three tiles for each piece the item could replace, headed by
-- that piece's name where there are two. A tile is the role's one number
-- (R.Combine). With Shift held its two parts are named under it.
function T.TilesFor(found, shift)
	local groups = {}
	for _, one in ipairs(found) do
		local group = {}
		if #found > 1 then
			group.head = one.swap.wornLink and ("In place of " .. named(one.swap.wornLink)) or "In the empty slot"
		end
		-- (the piece from your bags the numbers are with, as the game's own
		-- comparison says it: "With Death Speaker Scepter")
		if one.swap.with then
			local words = "With " .. named(one.swap.with)
			group.head = group.head and (group.head .. " · " .. words) or words
		end
		-- (what the numbers leave out, as the row's heading or after it)
		if one.note then
			group.head = group.head and (group.head .. " · " .. one.note) or one.note
		end
		for _, role in ipairs(ROLES) do
			local first, second = role[1], SECOND[role[1]]
			local value, rgb = figure((one.all or R.Combine(one.change))[first])
			local tile = { value = value, rgb = rgb, label = role[2] }
			if shift then
				tile.parts = {}
				for _, part in ipairs({ { FIRST_WORDS[first], one.change[first] }, { SECOND_WORDS[second], one.change[second] } }) do
					if part[2] then
						local text, ink = figure(part[2])
						tile.parts[#tile.parts + 1] = { part[1], text, ink }
					end
				end
			end
			group[#group + 1] = tile
		end
		groups[#groups + 1] = group
	end
	return groups
end

-- the comparison tooltips, which show what you are wearing
local function wornCard(tip)
	return tip == ShoppingTooltip1 or tip == ShoppingTooltip2 or tip == ItemRefShoppingTooltip1
		or tip == ItemRefShoppingTooltip2
end

local function cell(v, word, newRow)
	local n, colour = "0.0%", GREY
	if v and math.abs(v) >= 0.05 then
		n, colour = ("%+.1f%%"):format(v), v < 0 and RED or GREEN
	end
	return { colour .. n .. "|r " .. word, n .. " " .. word, newRow = newRow }
end

-- the answers kept (T.Cells), by the item's link
local kept = {}
T.KEEP = 5
-- (true from when your gear, buffs, stats, spells or level changed until
-- the swap check's "before" has been read again: see the ticker below)
local changed = true
local stale = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UNIT_AURA", "UNIT_STATS",
	"UNIT_ATTACK_POWER", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS",
	"SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
	pcall(stale.RegisterEvent, stale, event)
end
stale:SetScript("OnEvent", function(_, _, unit)
	if unit == nil or unit == "player" or type(unit) ~= "string" then
		kept = {}
		changed = true
	end
end)

-- The cells for BeebMod's item card: { shown words, plain words } each.
-- NOT ON WHAT YOU ARE WEARING (Josh 2026-11-16: "I don't think the equipped
-- items need to show the new upgrade stats"): nothing on the comparison
-- tooltips, and nothing for an item that is on you (Rd.Swaps).
function T.Cells(tip, data, shopping)
	if shopping or wornCard(tip) or not UP.On() or not covered() then
		return nil
	end
	local l = link(tip, data)
	if not l or not Rd.Where(l) then
		return nil
	end
	-- WORKED OUT ONCE, NOT FIVE TIMES A SECOND (Josh 2026-11-16: "Tooltip
	-- performance issues. 70 fps with no tooltip open... 61 after I open
	-- it"). The game writes a tooltip again several times a second while
	-- the mouse rests on an item, and each time the whole comparison was
	-- worked out again. The answer for an item is kept until something it
	-- stands on changes (your gear, buffs, stats, spells or level: `stale`
	-- below), and for T.KEEP seconds at most.
	-- (kept by the item and its partner from your bags: Shift-C changes the
	-- partner, and the numbers with it)
	local t = GetTime()
	local key = l .. "|" .. tostring(Rd.Partner(l) or "")
	local found = kept[key]
	if not (found and t - found.at < T.KEEP) then
		found = T.Compare(l)
		if not found or #found == 0 then
			return nil
		end
		found.at = t
		kept[key] = found
	end
	local cells = {}
	if #found > 1 then
		-- A ROW FOR EACH RING (Josh 2026-11-16: "maybe we should have a
		-- "ring 1" and "ring 2" row on the item, so we can see if the item
		-- is an upgrade over either slot"). Each row starts with which one
		-- it is against. The second profiles are in the Shift breakdown.
		for _, one in ipairs(found) do
			local words = PAIRS[one.swap.slot] or ("slot " .. one.swap.slot)
			cells[#cells + 1] = { GREY .. words .. "|r", words, newRow = #cells > 0 }
			for _, role in ipairs(ROLES) do
				cells[#cells + 1] = cell(one.all[role[1]], role[2])
			end
		end
	else
		-- ALWAYS ALL THREE (Josh 2026-11-16: "I think we should always show
		-- the stats. Sometimes they are missing right now"): a role the item
		-- does nothing for reads 0.0%, in grey
		-- ONE NUMBER A ROLE, its parts with Shift (R.Combine)
		for _, role in ipairs(ROLES) do
			cells[#cells + 1] = cell(found[1].all[role[1]], role[2])
		end
	end
	local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
	-- NO TABLE OF STATS UNDER THE TILES (Josh 2026-11-16: "The "where it comes
	-- from" section on shift is confusing to me... I think we could probably
	-- just remove that?"). Shift names each tile's two parts and no more.
	cells.tiles = T.TilesFor(found, shift)
	return cells
end

BT.OnItemCells(T.Cells)

-- EVERY SPELL THE MODEL PRICES, AS THE GAME DESCRIBES IT NOW, FOR THE RECORD
-- (Josh 2026-11-17, of the warrior: "I dont have a warrior character"). The
-- game describes any class's spell by its id, to any character. So the
-- Testing page's Record writes down the description of every spell in the
-- generated list, for every class in it. A class's reading can then be
-- checked from the saved file with no character of that class. A spell the
-- game has not loaded yet is asked for and counted as waiting: Record again
-- a few seconds later has it.
-- WHAT THE GAME SAYS OF YOUR TALENTS (Josh 2026-11-18: "What do you need me
-- to check regarding talents?"). Crit talents and the way you fight are both
-- found by asking the game whether you know a talent's spell (Read.lua). It
-- had not been seen whether the game answers for a talent, nor whether the
-- spell you know is the one in the tables or a later rank of it. This
-- records, for the record on the Testing page: the two calls' answers for
-- each talent the tables list for your class, and each talent you have
-- points in as the talent window has it, with its spell and the same two
-- answers.
function T.Known(data)
	local function ask(call, id)
		if type(call) ~= "function" then
			return "no call"
		end
		local ok, known = pcall(call, id)
		return ok and known == true
	end
	local function both(id)
		return { player = ask(IsPlayerSpell, id), known = ask(IsSpellKnown, id) }
	end
	local _, class = UnitClass("player")
	local out = { class = class, listed = {}, marks = {}, points = {}, calls = {
		traits = C_Traits ~= nil and C_ClassTalents ~= nil, old = GetNumTalentTabs ~= nil and GetTalentInfo ~= nil } }
	for id in pairs(type(data.talents) == "table" and data.talents[class] or {}) do
		out.listed[id] = both(id)
	end
	-- (the paladin's own, Read.lua, and their words; and whether the game's
	-- cooldown for Judgement has Improved Judgement in it: 10 seconds if not)
	for id in pairs(Rd.PALADIN or {}) do
		local row = both(id)
		local ok, text = pcall(C_Spell.GetSpellDescription, id)
		row.words = ok and type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text or nil
		out.listed[id] = row
	end
	if GetSpellBaseCooldown then
		local ok, ms = pcall(GetSpellBaseCooldown, 20271)
		out.judgement = ok and type(ms) == "number" and not (issecretvalue and issecretvalue(ms)) and ms or nil
	end
	for way, spec in pairs(type(data.specs) == "table" and data.specs[class] or {}) do
		for id in pairs(spec.marks or {}) do
			out.marks[id] = both(id)
			out.marks[id].way = way
		end
	end
	local ok, problem = pcall(function()
		local config = C_ClassTalents.GetActiveConfigID()
		local info = config and C_Traits.GetConfigInfo(config)
		for _, tree in ipairs(info and info.treeIDs or {}) do
			for _, node in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
				local n = C_Traits.GetNodeInfo(config, node)
				local entry = n and n.activeEntry and n.activeEntry.entryID
				if entry and (n.currentRank or 0) > 0 then
					local e = C_Traits.GetEntryInfo(config, entry)
					local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
					local id = d and (d.overriddenSpellID or d.spellID)
					local row = id and both(id) or {}
					row.spell, row.rank, row.most = id, n.currentRank, n.maxRanks
					-- (its words at your rank, as the talent window has them)
					row.words = id and Rd.TalentWords and Rd.TalentWords(id) or nil
					row.name = id and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
					out.points[#out.points + 1] = row
				end
			end
		end
	end)
	if not ok then
		out.problem = tostring(problem)
	end
	return out
end

function T.Dump()
	local data = UP.SpellData
	if not (UP.On() and type(data) == "table" and type(data.spells) == "table" and C_Spell and C_Spell.GetSpellDescription) then
		return nil
	end
	local out = { at = date("%Y-%m-%d %H:%M:%S"), classes = {}, waiting = 0, spells = 0 }
	for class, list in pairs(data.spells) do
		local words = {}
		for id in pairs(list) do
			local ready = not C_Spell.IsSpellDataCached or C_Spell.IsSpellDataCached(id)
			local ok, text = pcall(C_Spell.GetSpellDescription, id)
			if ready and ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
				words[id] = text
				out.spells = out.spells + 1
			else
				out.waiting = out.waiting + 1
				if C_Spell.RequestLoadSpellData then
					pcall(C_Spell.RequestLoadSpellData, id)
				end
			end
		end
		out.classes[class] = words
	end
	-- (and the crit talents' own words, which say their amounts)
	out.talents = {}
	for class, list in pairs(type(data.talents) == "table" and data.talents or {}) do
		local words = {}
		for id in pairs(list) do
			local ok, text = pcall(C_Spell.GetSpellDescription, id)
			if ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
				words[id] = text
			elseif C_Spell.RequestLoadSpellData then
				pcall(C_Spell.RequestLoadSpellData, id)
			end
		end
		out.talents[class] = words
	end
	out.known = T.Known(data)
	BeebModDB = BeebModDB or {}
	BeebModDB.upgradesDump = out
	return out.spells
end
BT.Record("upgradesDump", T.Dump, "upgrades")

-- pressing or letting go of Shift over an item draws its tooltip again
local shift = CreateFrame("Frame")
shift:RegisterEvent("MODIFIER_STATE_CHANGED")
shift:SetScript("OnEvent", function(_, _, key)
	if key ~= "LSHIFT" and key ~= "RSHIFT" then
		return
	end
	-- ONLY A TOOLTIP THAT HAS THE NUMBERS ON IT (Josh 2026-11-17, an error
	-- with a Questie map icon's tooltip up: "attempt to index local 'color'
	-- (a secret table value, while execution tainted by 'BeebMod')", from
	-- this line). Shift redrew whatever tooltip was showing. Redrawn from
	-- addon code, a tooltip of a unit whose words the game keeps secret
	-- cannot be written by the game's own code, and it stops with an error.
	-- So nothing is redrawn unless this is on, you are a paladin, and the
	-- tooltip shows an item that could be worn: the only ones Shift changes.
	if not UP.On() or not covered() then
		return
	end
	for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tip and tip.IsShown and tip:IsShown() and tip.RefreshData and TooltipUtil and TooltipUtil.GetDisplayedItem then
			local ok, _, shown = pcall(TooltipUtil.GetDisplayedItem, tip)
			if ok and type(shown) == "string" and not (issecretvalue and issecretvalue(shown)) and Rd.Where(shown) then
				pcall(tip.RefreshData, tip)
			end
		end
	end
end)

-- THE CHECK ------------------------------------------------------------------

-- A POINT OF ROUNDING IS NOT A MISS (Josh 2026-11-16, a screenshot of nine
-- lines in chat: "expected stamina 110.2... The game says 111.0", "expected
-- health 1264.0... The game says 1272.0", "expected intellect 76.2... The
-- game says 77.0"). With Blessing of Kings a piece's stats count 1.1 times,
-- so the math's totals have fractions. The game shows whole numbers, and
-- the total it started from was rounded too. So a stat may be up to a point
-- and a half off with nothing wrong, and what hangs on it by as much: 10
-- health a point of stamina, 15 mana a point of intellect, 2 attack power a
-- point of strength, 2 armor a point of agility.
local CHECKED = {
	{ "strength", 1.5 }, { "agility", 1.5 }, { "stamina", 1.5 }, { "intellect", 1.5 }, { "spirit", 1.5 },
	{ "attackPower", 3.1 }, { "healing", 0.6 }, { "armor", 3.1 }, { "crit", 0.16 }, { "spellCrit", 0.06 },
	{ "dodge", 0.16 }, { "health", 16 }, { "mana", 23 }, { "damageMin", 0.6 }, { "damageMax", 0.6 },
}
local WORDS = {
	attackPower = "attack power", spellCrit = "spell crit", damageMin = "weapon damage (low)",
	damageMax = "weapon damage (high)",
}

local last -- { state, rates, links }

local function links()
	local out = {}
	for slot = 1, 19 do
		out[slot] = GetInventoryItemLink("player", slot)
	end
	return out
end

local function remember()
	-- (only where the tiles show: on, and a class the model covers)
	if not UP.On() or not covered() then
		last = nil
		return
	end
	local s = Rd.State()
	last = s and { state = s, rates = Rd.Rates(s), links = links() } or nil
end

local function check()
	seen = nil
	if not UP.On() then
		last = nil
		return
	end
	local was = last
	remember()
	if not (was and last) then
		return
	end
	local expected, changed = was.state, {}
	for slot = 1, 19 do
		if was.links[slot] ~= last.links[slot] then
			changed[#changed + 1] = slot
			local weapons
			if slot == 16 and last.links[slot] then
				weapons = { worn = Rd.Weapon(was.links[slot]), new = Rd.Weapon(last.links[slot]) }
			end
			expected = M.Swap(expected, was.rates, Rd.ItemStats(was.links[slot]), Rd.ItemStats(last.links[slot]), weapons)
		end
	end
	if #changed == 0 then
		return
	end
	-- a weapon swap moves crit by the two weapons' skills, which the math
	-- leaves out on purpose (Rd.SkillShort), so crit is not checked for one
	local weapon = false
	for _, slot in ipairs(changed) do
		weapon = weapon or slot == 16
	end
	local misses = {}
	for _, c in ipairs(CHECKED) do
		local want, got = expected[c[1]], last.state[c[1]]
		if want and got and math.abs(want - got) > c[2] and not (weapon and c[1] == "crit") then
			misses[#misses + 1] = { stat = c[1], expected = want, game = got }
		end
	end
	if math.abs(expected.spellDamage[2] - last.state.spellDamage[2]) > 0.6 then
		misses[#misses + 1] = { stat = "Holy spell damage", expected = expected.spellDamage[2], game = last.state.spellDamage[2] }
	end
	local db = UP.DB()
	db.checks = db.checks or {}
	table.insert(db.checks, { at = date("%Y-%m-%d %H:%M:%S"), slots = changed, misses = misses,
		off = was.links[changed[1]], on = last.links[changed[1]] })
	while #db.checks > 30 do
		table.remove(db.checks, 1)
	end
	-- KEPT, NOT SAID IN CHAT (the same screenshot: "The debug lines show
	-- here"). A miss is in `checks`, above, with its words
	-- made here so the saved file reads as the chat lines did.
	for _, m in ipairs(misses) do
		m.words = ("expected %s %.1f after that swap. The game says %.1f."):format(WORDS[m.stat] or m.stat, m.expected, m.game)
	end
end

local waiting = false
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(4, remember)
		-- the probe's records, from before the math was written: dropped
		UP.DB().probe = nil
		-- THE "BEFORE" IS KEPT FRESH (Josh's chat lines, 2026-11-16: every
		-- stat 5 under what was expected, and armor 152 under). The totals
		-- had been remembered at login, a buff ended before the swap, and
		-- the check blamed the swap for it. So they are read again while
		-- the gear is as it was remembered.
		-- ONLY WHEN SOMETHING CHANGED (review 2026-11-18). The whole
		-- character was read every second of the session, in combat too:
		-- some 40 stat calls, two weapon tooltips and 19 items' stats. The
		-- events that empty the kept answers (`stale`) are the same ones
		-- that can move a total, so the read waits for one of them.
		C_Timer.NewTicker(1, function()
			if waiting or not changed or not UP.On() then
				return
			end
			if not last then
				remember()
				changed = last == nil
				return
			end
			for slot = 1, 19 do
				if last.links[slot] ~= GetInventoryItemLink("player", slot) then
					return
				end
			end
			remember()
			changed = false
		end)
	elseif not waiting then
		waiting = true
		C_Timer.After(1.5, function()
			waiting = false
			check()
		end)
	end
end)
