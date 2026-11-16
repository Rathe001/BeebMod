-- TANK, HEALER, DPS ON AN ITEM'S TOOLTIP (Josh 2026-11-16).
--
-- Josh: "I want the tooltip to show me a % increase/decrease in each role."
-- For the item under the mouse: your totals as you stand, then with the worn
-- piece out and this one in (Math.lua), each priced per role (Roles.lua).
-- The cells say the change in percent of your whole character, so most
-- pieces read between 0% and 5%.
--
-- BeebMod draws the cells in its item card (BeebMod.OnItemCells). Without
-- that this file does nothing.
--
-- A RING OR TRINKET has two pieces it could replace, and gets a row of cells
-- for each.
--
-- AND IT CHECKS ITSELF. Every time you really change a piece, the totals the
-- math expected are compared with what the game then reports, and a miss is
-- said in chat and kept in BeebModUpgradesDB.checks.
local _, UP = ...

local Rd, M, R = UP.Read, UP.Math, UP.Roles
local T = {}
UP.Tiles = T

-- ITS SWITCH, IN BEEBMOD'S SETTINGS (Josh 2026-11-16: "make sure we have a
-- switch for this in the options"). BeebMod draws it on its General page and
-- keeps the answer (BeebMod.AddSwitch). Off, nothing here shows, checks or
-- records.
if BeebMod and BeebMod.AddSwitch then
	BeebMod.AddSwitch({
		key = "upgrades", section = "Upgrades", title = "Upgrades on gear tooltips",
		blurb = "Shows how much a piece of gear changes your tank, healer and DPS numbers",
	})
end
function UP.On()
	return not (BeebMod and BeebMod.SwitchOn) or BeebMod.SwitchOn("upgrades")
end

local GREEN, RED, GREY = "|cff1eff00", "|cffff5a4d", "|cff9aa5a0"
local ROLES = { { "tank", "tank" }, { "healer", "healer" }, { "dps", "DPS" } }

local function paladin()
	local _, class = UnitClass("player")
	return class == "PALADIN"
end

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

local function price(s, kit)
	return {
		tank = R.Survival(s, kit), healer = R.Healing(s, kit), dps = R.Damage(s, kit),
		threat = R.Threat(s, kit), sustain = R.Sustain(s, kit),
		aoe = R.Damage(s, kit, { enemies = R.AOE_ENEMIES }),
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
		local after = M.Swap(n.state, n.rates, swap.worn, Rd.ItemStats(link), swap.weapons)
		if swap.shield ~= nil then
			after.shield = swap.shield
		end
		local worth = price(after, n.kit)
		local change = {}
		for key, was in pairs(before) do
			change[key] = R.Change(was, worth[key])
		end
		out[#out + 1] = { swap = swap, change = change, seal = select(2, R.Damage(after, n.kit)) }
	end
	return out
end

-- THE BREAKDOWN, WITH SHIFT HELD (Josh 2026-11-16: "Proceed with shift").
-- Under each role, what each stat of the swap does on its own: the stat's
-- difference put on your totals with nothing else changed, priced for both
-- of the role's profiles. A new weapon's damage and speed are one line,
-- "Weapon". The lines need not add up to the role's number exactly: stats
-- work on each other (crit is worth more with more attack power).
local TITLES = { tank = "Tank", healer = "Healer", dps = "DPS" }
local SEALS = { command = "Seal of Command", righteousness = "Seal of Righteousness", fury = "Seal of Fury" }
local SKIP = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = true }
local NAMES = { UPGRADES_BLOCK = "Block" }
-- what a two-slot piece's rows are called: "ring 1", "ring 2"
local PAIRS = { [11] = "ring 1", [12] = "ring 2", [13] = "trinket 1", [14] = "trinket 2" }

local function percent(v)
	if not v or math.abs(v) < 0.05 then
		return GREY .. "0.0%|r"
	end
	return (v < 0 and RED or GREEN) .. ("%+.1f%%"):format(v) .. "|r"
end

local function amount(v)
	if v == math.floor(v) then
		return ("%+d"):format(v)
	end
	return ("%+.1f"):format(v)
end

local function named(wornLink)
	return type(wornLink) == "string" and wornLink:match("%[(.-)%]") or "empty"
end

function T.Rows(link, found)
	local n = now()
	if not (n and found) then
		return nil
	end
	local before = price(n.state, n.kit)
	local new = Rd.ItemStats(link)
	local rows = {}
	for _, one in ipairs(found) do
		local swap, change = one.swap, one.change
		-- which of the two it is against, when there are two
		if #found > 1 and PAIRS[swap.slot] then
			local words = PAIRS[swap.slot]
			rows[#rows + 1] = { words:sub(1, 1):upper() .. words:sub(2) .. " · " .. named(swap.wornLink) }
		end
		for _, role in ipairs(ROLES) do
			local first, second = role[1], SECOND[role[1]]
			local title = TITLES[first]
			if first == "dps" and one.seal and SEALS[one.seal] then
				title = title .. " · " .. SEALS[one.seal]
			end
			rows[#rows + 1] = { title, percent(change[first]) .. "  " .. SECOND_WORDS[second] .. " " .. percent(change[second]) }
			local function part(words, stats, weapons, shield)
				local alone = M.Swap(n.state, n.rates, nil, stats, weapons)
				if shield ~= nil then
					alone.shield = shield
				end
				local worth = price(alone, n.kit)
				local a, b = R.Change(before[first], worth[first]) or 0, R.Change(before[second], worth[second]) or 0
				if math.abs(a) >= 0.05 or math.abs(b) >= 0.05 then
					rows[#rows + 1] = { "   " .. words, percent(a) .. "  " .. SECOND_WORDS[second] .. " " .. percent(b), quiet = true }
				end
			end
			local d = M.Difference(swap.worn, new)
			local keys = {}
			for k, v in pairs(d) do
				if v ~= 0 and not SKIP[k] then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				part(amount(d[k]) .. " " .. (NAMES[k] or type(_G[k]) == "string" and _G[k] or k), { [k] = d[k] })
			end
			if swap.weapons and swap.weapons.new then
				part("Weapon", nil, swap.weapons)
			end
			-- a shield coming off or going on: its block and Seal of Fury's
			-- absorb with it
			if swap.shield ~= nil and swap.shield ~= n.state.shield then
				part(swap.shield and "Shield" or "No shield", nil, nil, swap.shield)
			end
		end
	end
	return rows
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

-- The cells for BeebMod's item card: { shown words, plain words } each.
-- NOT ON WHAT YOU ARE WEARING (Josh 2026-11-16: "I don't think the equipped
-- items need to show the new upgrade stats"): nothing on the comparison
-- tooltips, and nothing for an item that is on you (Rd.Swaps).
function T.Cells(tip, data, shopping)
	if shopping or wornCard(tip) or not UP.On() or not paladin() then
		return nil
	end
	local l = link(tip, data)
	if not l or not Rd.Where(l) then
		return nil
	end
	local found = T.Compare(l)
	if not found or #found == 0 then
		return nil
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
				cells[#cells + 1] = cell(one.change[role[1]], role[2])
			end
		end
	else
		local change = found[1].change
		-- ALWAYS ALL THREE (Josh 2026-11-16: "I think we should always show
		-- the stats. Sometimes they are missing right now"): a role the item
		-- does nothing for reads 0.0%, in grey
		for _, role in ipairs(ROLES) do
			cells[#cells + 1] = cell(change[role[1]], role[2])
		end
		-- A SECOND PROFILE ONLY WHERE IT TELLS A DIFFERENT STORY (Josh
		-- 2026-11-16, asked whether to show every profile: one number a
		-- role, the other where they disagree). That is the other sign, or
		-- a whole percent apart. They get a row of their own under the three.
		local first = true
		for _, role in ipairs(ROLES) do
			local a, b = change[role[1]] or 0, change[SECOND[role[1]]]
			if b and (math.abs(a - b) >= 1 or (a * b < 0 and math.abs(a - b) >= 0.1)) then
				cells[#cells + 1] = cell(b, SECOND_WORDS[SECOND[role[1]]], first)
				first = false
			end
		end
	end
	if IsShiftKeyDown and IsShiftKeyDown() then
		cells.rows = T.Rows(l, found)
	end
	return cells
end

if BeebMod and BeebMod.OnItemCells then
	BeebMod.OnItemCells(T.Cells)
end

-- pressing or letting go of Shift over an item draws its tooltip again
local shift = CreateFrame("Frame")
shift:RegisterEvent("MODIFIER_STATE_CHANGED")
shift:SetScript("OnEvent", function(_, _, key)
	if key ~= "LSHIFT" and key ~= "RSHIFT" then
		return
	end
	for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tip and tip.IsShown and tip:IsShown() and tip.RefreshData then
			pcall(tip.RefreshData, tip)
		end
	end
end)

-- THE CHECK ------------------------------------------------------------------

local CHECKED = {
	{ "strength", 0.6 }, { "agility", 0.6 }, { "stamina", 0.6 }, { "intellect", 0.6 }, { "spirit", 0.6 },
	{ "attackPower", 1.1 }, { "healing", 0.6 }, { "armor", 1.1 }, { "crit", 0.06 }, { "spellCrit", 0.06 },
	{ "dodge", 0.06 }, { "health", 1.1 }, { "mana", 1.1 }, { "damageMin", 0.6 }, { "damageMax", 0.6 },
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
	BeebModUpgradesDB = BeebModUpgradesDB or {}
	local db = BeebModUpgradesDB
	db.checks = db.checks or {}
	table.insert(db.checks, { at = date("%Y-%m-%d %H:%M:%S"), slots = changed, misses = misses,
		off = was.links[changed[1]], on = last.links[changed[1]] })
	while #db.checks > 30 do
		table.remove(db.checks, 1)
	end
	for _, m in ipairs(misses) do
		print(("Upgrades: expected %s %.1f after that swap. The game says %.1f."):format(WORDS[m.stat] or m.stat, m.expected, m.game))
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
		if type(BeebModUpgradesDB) == "table" then
			BeebModUpgradesDB.probe = nil
		end
		-- THE "BEFORE" IS KEPT FRESH (Josh's chat lines, 2026-11-16: every
		-- stat 5 under what was expected, and armor 152 under). The totals
		-- had been remembered at login, a buff ended before the swap, and
		-- the check blamed the swap for it. So they are read again each
		-- second while the gear is as it was remembered.
		C_Timer.NewTicker(1, function()
			if waiting or not UP.On() then
				return
			end
			if not last then
				remember()
				return
			end
			for slot = 1, 19 do
				if last.links[slot] ~= GetInventoryItemLink("player", slot) then
					return
				end
			end
			remember()
		end)
	elseif not waiting then
		waiting = true
		C_Timer.After(1.5, function()
			waiting = false
			check()
		end)
	end
end)
