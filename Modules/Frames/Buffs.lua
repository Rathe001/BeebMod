-- Your own buffs and debuffs, in a tray beside the dock (Josh 2026-09-23).
--
-- "A cleaner more consolidated look ... buffs on one line, and debuffs on a
-- different line ... the tray would work best for that, and sort them by
-- duration." The game's bar was a loose row of big icons with a time under
-- each and a collapse arrow; this is two rows on the toolkit's surface, to
-- the left of the dock: your buffs on the top line, your debuffs under them.
--
-- THE ORDER, LEFT TO RIGHT (Josh 2026-09-23: "the perma buffs/debuffs should
-- always be furthest to the right, in ABC order"): the soonest to run out at
-- the far left, then each a little longer, then your weapon enchants, then -
-- against the dock - the ones that never run out, A to Z.
--
-- DRAWN BY THE CLIENT, as the unit frames' auras are (Modules/Frames/Auras.lua):
-- in a fight an addon may not read an aura at all, so each row is the client's
-- aura containers, told "player", a filter and an order, filling buttons we
-- describe - the unit frames' icon, with the time left as a thin bar inside it
-- and as words under it, both kept by the client. A row is two containers:
--   * timed: every aura with a duration (a duration cap keeps permanent ones
--     out - the client's own filter), longest first from the right, so the
--     soonest ends up at the far left
--   * permanent: named by spell, A to Z from the left. No filter says "no
--     duration", so which spells those are is learned out of a fight, when
--     auras can be read, and a few that are always permanent (stances, forms,
--     stealth, aspects, auras) are known from the start
--
-- THE SURFACE follows the timed container where the client lets it (a
-- container sizes itself to its icons, in a fight too, where the addon cannot
-- count them); where it will not, it is as wide as a count taken out of a
-- fight. The containers and the enchants are placed from counts taken out of
-- a fight, which is the one thing that can be out of step until it ends.
--
-- WEAPON ENCHANTS - poisons, stones, a shaman's weapon - are not auras and no
-- container shows them, so they are ours, from GetWeaponEnchantInfo, with the
-- same bar and time. A right-click on a buff cancels it (the client allows
-- that out of a fight only).
--
-- A MODULE OF ITS OWN (Josh 2026-09-23: "buffs aren't a part of unit frames"):
-- its own page in the Game frames group and its own switch, and switched off,
-- the game's own buff bar is back.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Frames/Buffs.lua")

local U = BT.Util
local F = BT.UnitFrames
local A = F.Auras
local B = {}
F.Buffs = B

local M = BT.Module({
	key = "buffs",
	group = "combat",
	title = "Buffs",
	blurb = "yours, in a tray beside the dock: buffs over debuffs",
	order = 46,
})
B.module = M

B.SIZE = 26 -- an icon
B.GAP = 3 -- between icons
B.PAD = 4 -- the surface around a row
B.TEXT_H = 11 -- the time under an icon
B.ROW_GAP = 5 -- between the two rows' surfaces
B.EDGE = 8 -- from the dock
B.ROW_H = B.SIZE + B.TEXT_H
B.STEP = B.SIZE + B.GAP
B.PERM_MAX = 12
-- a duration cap no aura reaches: the client's filter then passes every aura
-- that has a duration and none that has not (the unit frames' buff rows use it
-- too)
B.TIMED_MAX = A.TIMED_MAX

B.ROWS = {
	{ key = "buffs", filter = "HELPFUL", max = 24 },
	{ key = "debuffs", filter = "HARMFUL", max = 12, harmful = true },
}

-- spells that are always permanent on you, before any has been seen
B.SEEDS = {
	1784, 1785, 1786, 1787, -- Stealth
	2457, 71, 2458, -- Battle, Defensive, Berserker Stance
	5487, 9634, 768, 783, 1066, 24858, -- Bear, Dire Bear, Cat, Travel, Aquatic, Moonkin Form
	15473, 2645, -- Shadowform, Ghost Wolf
	13165, 14318, 14319, 14320, 14321, 14322, 25296, -- Aspect of the Hawk
	5118, 13159, 13163, 20043, 20190, 13161, -- Cheetah, Pack, Monkey, Wild, Beast
	465, 10290, 643, 10291, 1032, 10292, 10293, -- Devotion Aura
	7294, 10298, 10299, 10300, 10301, 19746, -- Retribution, Concentration Aura
}
B.perm = { HELPFUL = {}, HARMFUL = {} }
for _, id in ipairs(B.SEEDS) do
	B.perm.HELPFUL[id] = true
end

-- where a row's icons start: its top, below the holder's
function B.RowTop(i)
	return -(i - 1) * (B.ROW_H + 2 * B.PAD + B.ROW_GAP)
end

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function plainNumber(v)
	return type(v) == "number" and not (issecretvalue and issecretvalue(v)) and v or nil
end

local function timeWords(sec)
	if type(sec) ~= "number" then
		return ""
	end
	if sec >= 3600 then
		return ("%d h"):format(math.floor(sec / 3600 + 0.5))
	elseif sec >= 60 then
		return ("%d m"):format(math.floor(sec / 60 + 0.5))
	end
	return ("%d s"):format(math.max(0, math.floor(sec + 0.5)))
end
B.TimeWords = timeWords

-- the time under an icon and the bar inside it: plain pieces, for the made-up
-- ones and the enchants, and handed to the client for the real ones
local function timePieces(b)
	local bar = CreateFrame("StatusBar", nil, b)
	bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
	bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	bar:SetHeight(2)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 1)
	bar:SetFrameLevel((b:GetFrameLevel() or 1) + 2)
	local a = BT.Widgets.ACCENT
	bar:SetStatusBarColor(a[1], a[2], a[3], 1)
	bar.track = bar:CreateTexture(nil, "BACKGROUND")
	bar.track:SetAllPoints()
	bar.track:SetColorTexture(0, 0, 0, 0.65)
	local words = b:CreateFontString(nil, "OVERLAY")
	-- the face set here and not through Fonts.Set: a change of face writes a
	-- string's text again, and on a real button this string is the client's
	pcall(words.SetFont, words, BT.Fonts.Face("text") or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
		BT.Fonts.Size(9), "")
	words:SetShadowColor(0, 0, 0, 1)
	words:SetShadowOffset(1, -1)
	words:SetPoint("TOP", b, "BOTTOM", 0, -2)
	words:SetTextColor(0.86, 0.82, 0.58)
	return bar, words
end

-- a real button, as the client makes it: the unit frames' icon, no clock face
local function trayButton(size, harmful)
	local dress = A.IconButton(size, false, false, false, true)
	return function(b)
		dress(b)
		local bar, words = timePieces(b)
		if b.SetDurationBar then
			pcall(b.SetDurationBar, b, bar, {})
		else
			bar:Hide()
		end
		-- (the time in words can be left off - it takes a reload: a button is
		-- the client's once it is made - Josh 2026-09-24)
		local s = BT.settings and BT.settings.buffs
		if s and s.timeText == false then
			words:Hide()
		elseif b.SetDurationText then
			pcall(b.SetDurationText, b, words, {})
		end
		-- a right-click takes a buff off (the client says when it may)
		if not harmful and b.SetCancelAuraButtons then
			if not pcall(b.SetCancelAuraButtons, b, "RightButtonUp") then
				pcall(b.SetCancelAuraButtons, b, "RightButton")
			end
		end
	end
end
B.TrayButton = trayButton

-- the permanent container's filter: the spells known to be permanent, or -
-- none known yet - one spell nobody has, which shows nothing
function B.PermFilter(filter)
	local ids = {}
	for id in pairs(B.perm[filter] or {}) do
		ids[id] = true
	end
	if next(ids) == nil then
		ids[1] = true
	end
	return { includeSpellIDs = ids }
end

-- one of a row's containers: flowing left from its right edge
local function trayContainer(parent, key, filter, max, candidate, sortMethod, sortDirection, harmful)
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if not (ok and c and c.AddAuraGroup) then
		return nil
	end
	pcall(c.SetEditModePreviewEnabled, c, false)
	local dir = AnchorUtil and AnchorUtil.FlowDirection
	if c.SetFlowLayoutAnchorPoint then
		pcall(c.SetFlowLayoutAnchorPoint, c, "TOPRIGHT")
	end
	if dir and c.SetFlowLayoutGrowthDirection then
		pcall(c.SetFlowLayoutGrowthDirection, c, dir.Left, dir.Down)
	end
	if c.SetFlowLayoutMaximumLineSize then
		pcall(c.SetFlowLayoutMaximumLineSize, c, max * B.STEP)
	end
	pcall(c.SetUnit, c, "player")
	local okG = pcall(c.AddAuraGroup, c, key, filter, {
		maxFrameCount = max,
		initializeFrame = trayButton(B.SIZE, harmful),
		candidateFilters = candidate,
		sortMethod = sortMethod,
		sortDirection = sortDirection,
		layout = { elementSpacing = B.GAP, lineSpacing = 2, elementWidth = B.SIZE, elementHeight = B.ROW_H },
	})
	if not okG then
		return nil
	end
	return c
end

-- ---------------------------------------------------------------------------
-- The tray
-- ---------------------------------------------------------------------------

-- beside the dock, or where the dock would be when it is off
function B.Place()
	local h = B.holder
	if not h then
		return
	end
	-- AS BIG AS YOU LIKE (Josh 2026-09-24): the whole tray, scaled - never in a
	-- fight, where its containers are the client's to keep still
	if not (InCombatLockdown and InCombatLockdown()) then
		local s = BT.settings and BT.settings.buffs
		h:SetScale((s and s.scale) or 1)
	end
	h:ClearAllPoints()
	local dock = BT.Bar and BT.Bar.Frame and BT.Bar.Frame()
	if dock and dock.IsShown and dock:IsShown() then
		h:SetPoint("TOPRIGHT", dock, "TOPLEFT", -(B.EDGE + B.PAD), -B.PAD)
	else
		h:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -(B.PAD + 4))
	end
end

-- one weapon enchant's icon, in the buffs row
local function enchantIcon(parent, slot)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(B.SIZE, B.SIZE)
	f.edge = f:CreateTexture(nil, "BACKGROUND")
	f.edge:SetAllPoints()
	f.edge:SetColorTexture(0, 0, 0, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.bar, f.words = timePieces(f)
	f.slot = slot
	f:SetScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
			if GameTooltip.SetInventoryItem then
				pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot)
			end
			GameTooltip:Show()
		end
	end)
	f:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	f:Hide()
	return f
end

-- a frame of ours a container's right edge is pinned to, moved as counts change
local function pin(parent, top)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(1, 1)
	p:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, top)
	return p
end

function B.Build()
	if B.holder then
		return B.holder
	end
	if type(CreateFrame) ~= "function" then
		return nil
	end
	local h = CreateFrame("Frame", "BeebModAuraTray", UIParent)
	h:SetSize(1, 1)
	h:SetFrameStrata("MEDIUM")
	B.holder = h
	-- everything real hangs off this, so a preview can put it aside
	local real = CreateFrame("Frame", nil, h)
	real:SetAllPoints(h)
	B.real = real
	B.Place()
	B.rows = {}
	local methods, dirs = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
	local byName = methods and (methods.NameOnly or methods.Name)
	local byTime = methods and (methods.ExpirationOnly or methods.Expiration)
	local reverse = dirs and dirs.Reverse
	for i, spec in ipairs(B.ROWS) do
		local row = { spec = spec, permCount = 0, timedCount = 0 }
		local top = B.RowTop(i)
		row.top = top
		row.permPin = pin(real, top)
		row.timedPin = pin(real, top)
		row.surface = CreateFrame("Frame", nil, real)
		row.surface:SetFrameLevel((real:GetFrameLevel() or 1) + 1)
		BT.Widgets.Panel(row.surface)
		-- the permanent ones, A to Z reading left to right: from the right
		-- edge that is Z first
		row.perm = trayContainer(real, "perm", spec.filter, B.PERM_MAX, B.PermFilter(spec.filter), byName, reverse,
			spec.harmful)
		-- the timed ones, longest first from the right: the soonest far left
		row.timed = trayContainer(real, spec.key, spec.filter, spec.max, { maxDuration = B.TIMED_MAX }, byTime, reverse,
			spec.harmful)
		for _, pair in ipairs({ { row.perm, row.permPin }, { row.timed, row.timedPin } }) do
			local c = pair[1]
			if c then
				c:ClearAllPoints()
				c:SetPoint("TOPRIGHT", pair[2], "TOPRIGHT", 0, 0)
				c:SetFrameLevel((row.surface:GetFrameLevel() or 1) + 2)
				pcall(c.SetEnabled, c, true)
			end
		end
		-- the surface: from the timed container's left to the holder's right.
		-- A CLIENT MAY REFUSE THIS (Josh 2026-09-23: "seeing double buffs"):
		-- anchoring to its container threw, and took the rest of a setup with
		-- it. Refused, the surface is as wide as a count (see B.Update).
		if row.timed then
			row.follows = pcall(row.surface.SetPoint, row.surface, "TOPLEFT", row.timed, "TOPLEFT", -B.PAD, B.PAD)
		end
		if row.follows then
			row.surface:SetPoint("BOTTOMRIGHT", real, "TOPRIGHT", B.PAD, top - B.ROW_H - B.PAD)
		else
			row.surface:ClearAllPoints()
			row.surface:SetPoint("TOPRIGHT", real, "TOPRIGHT", B.PAD, top + B.PAD)
			row.surface:SetHeight(B.ROW_H + 2 * B.PAD)
		end
		B.rows[i] = row
		B.rows[spec.key] = row
	end
	B.enchants = { enchantIcon(real, 16), enchantIcon(real, 17) }
	B.Update()
	B.Watch()
	return h
end

-- ---------------------------------------------------------------------------
-- What is on you, out of a fight
-- ---------------------------------------------------------------------------

-- the enchants on your weapons now: { slot, left (seconds), charges }
function B.ReadEnchants()
	if type(GetWeaponEnchantInfo) ~= "function" then
		return {}
	end
	local r = { pcall(GetWeaponEnchantInfo) }
	if not r[1] then
		return {}
	end
	local out = {}
	for _, w in ipairs({ { slot = 16, at = 2 }, { slot = 17, at = 6 } }) do
		local has = r[w.at]
		if type(has) == "boolean" and has then
			local ms = plainNumber(r[w.at + 1])
			out[#out + 1] = { slot = w.slot, left = ms and ms / 1000 or nil, charges = plainNumber(r[w.at + 2]) }
		end
	end
	return out
end

-- your auras of a kind, out of a fight: how many are permanent and how many
-- timed, and the permanent ones' spells; nil when they cannot be read
function B.Read(filter)
	if inCombat() then
		return nil
	end
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then
		return nil
	end
	local out = { perm = 0, timed = 0, ids = {} }
	for i = 1, 40 do
		local ok, a = pcall(get, "player", i, filter)
		if not ok then
			return nil
		end
		-- type() is the one question safe to ask of anything secret
		if type(a) ~= "table" then
			break
		end
		local okD, duration = pcall(function() return a.duration end)
		local okS, spell = pcall(function() return a.spellId end)
		duration = okD and plainNumber(duration) or nil
		if duration == 0 then
			out.perm = out.perm + 1
			spell = okS and plainNumber(spell) or nil
			if spell then
				out.ids[spell] = true
			end
		else
			out.timed = out.timed + 1
		end
	end
	return out
end

B.longest = {}

-- a row's permanent spells, learned: the container told when there are new ones
local function learn(row, ids)
	local known = B.perm[row.spec.filter]
	local fresh = false
	for id in pairs(ids) do
		if not known[id] then
			known[id] = true
			fresh = true
		end
	end
	if fresh and row.perm and row.perm.SetAuraGroupCandidateFilters then
		pcall(row.perm.SetAuraGroupCandidateFilters, row.perm, "perm", B.PermFilter(row.spec.filter))
	end
	return fresh
end
B.Learn = learn

-- `enchantsOnly`: the ticker's pass, which only counts the enchants down
-- (the auras are read when they change, not every second - Josh 2026-09-23,
-- audit)
function B.Update(enchantsOnly)
	if not (B.holder and B.rows) then
		return
	end
	local enchants = B.ReadEnchants()
	-- a slot with nothing on it forgets how long its last enchant lasted,
	-- or a new one's bar starts measured against the old one
	local on = {}
	for _, e in ipairs(enchants) do
		on[e.slot] = true
	end
	for slot in pairs(B.longest) do
		if not on[slot] then
			B.longest[slot] = nil
		end
	end
	if not enchantsOnly then
		for _, row in ipairs(B.rows) do
			local r = B.Read(row.spec.filter)
			if r then
				learn(row, r.ids)
				row.permCount = math.min(r.perm, B.PERM_MAX)
				row.timedCount = math.min(r.timed, row.spec.max)
			end
		end
	end
	-- right to left: the permanent ones, the enchants (buffs only), the timed
	for _, row in ipairs(B.rows) do
		local lead = row.permCount
		if row.spec.key == "buffs" then
			for i, f in ipairs(B.enchants) do
				local e = enchants[i]
				if e then
					f.slot = e.slot
					local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", e.slot)
					f.icon:SetTexture(tex or 134400)
					f:ClearAllPoints()
					f:SetPoint("TOPRIGHT", B.real, "TOPRIGHT", -(lead + i - 1) * B.STEP, row.top)
					if e.left then
						-- how long it lasts is not said; the longest seen stands in
						local longest = math.max(B.longest[e.slot] or 0, e.left)
						B.longest[e.slot] = longest
						f.bar:SetValue(longest > 0 and e.left / longest or 0)
						f.bar:Show()
						f.words:SetText(timeWords(e.left))
					else
						f.bar:Hide()
						f.words:SetText("")
					end
					f:Show()
				else
					f:Hide()
				end
			end
			lead = lead + #enchants
		end
		-- the timed container moved along only when what is before it
		-- changed, and never in a fight: the client's container hangs off
		-- this pin
		if row.lead ~= lead and not inCombat() then
			row.lead = lead
			row.timedPin:ClearAllPoints()
			row.timedPin:SetPoint("TOPRIGHT", B.real, "TOPRIGHT", -lead * B.STEP, row.top)
		end
		-- a row with nothing in it puts its surface away; one that cannot hang
		-- off its container is as wide as its count
		local n = lead + row.timedCount
		if not inCombat() then
			row.surface:SetShown(n > 0)
		end
		if not row.follows and n > 0 then
			row.surface:SetWidth(n * B.STEP - B.GAP + 2 * B.PAD)
		end
	end
end

function B.Watch()
	if B.watch then
		return
	end
	local w = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
		pcall(w.RegisterEvent, w, event)
	end
	-- yours alone: an aura or an item change of anybody else's is no news
	for _, event in ipairs({ "UNIT_AURA", "UNIT_INVENTORY_CHANGED" }) do
		local ok = w.RegisterUnitEvent and pcall(w.RegisterUnitEvent, w, event, "player")
		if not ok then
			pcall(w.RegisterEvent, w, event)
		end
	end
	w:SetScript("OnEvent", function(_, event, unit)
		if (event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED") and unit ~= "player" then
			return
		end
		if not M.live then
			return
		end
		-- the dock is made after the book is bound, which may be after the
		-- tray was first placed: placed again as each world is entered
		if event == "PLAYER_ENTERING_WORLD" then
			B.Place()
		end
		B.Update()
	end)
	-- the enchants' time runs down on its own; the auras are read when they
	-- change
	if C_Timer and C_Timer.NewTicker then
		B.ticker = C_Timer.NewTicker(1, function()
			if M.live and B.holder and B.holder:IsShown() and not B.previewing then
				B.Update(true)
			end
		end)
	end
	B.watch = w
end

function B.SetShown(on)
	if on then
		B.Build()
	end
	if B.holder then
		B.holder:SetShown(on and true or false)
		if on then
			B.Place()
			B.Update()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Made-up auras, for the preview
-- ---------------------------------------------------------------------------

local SP = {
	thorns = 467, fed = 19705, mark = 1126, fort = 1243, fire = 7353, stealth = 1784,
	rend = 772, poison = 744, curse = 702, instant = 8679,
}
-- each row as it is laid out, left to right
B.PREVIEW = {
	buffs = {
		{ spell = SP.thorns, left = 192, max = 600 },
		{ spell = SP.fed, left = 842, max = 900 },
		{ spell = SP.mark, left = 1690, max = 1800 },
		{ spell = SP.fort, left = 2710, max = 3600 },
		{ spell = SP.instant, left = 1440, max = 1800, enchant = true },
		{ spell = SP.fire, name = "Cozy Fire" },
		{ spell = SP.stealth, name = "Stealth" },
	},
	debuffs = {
		{ spell = SP.rend, left = 12, max = 21, type = "Bleed" },
		{ spell = SP.poison, left = 64, max = 90, type = "Poison", count = 3 },
		{ spell = SP.curse, left = 105, max = 120, type = "Curse" },
	},
}

local function fakeTimed(parent, a, x, y)
	local f = A.FakeIcon(parent, B.SIZE)
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
	f.icon:SetTexture(A.SpellIcon(a.spell))
	f.spell, f.type = a.spell, a.type
	local c = a.type and A.TYPE_COLOUR[a.type]
	if c then
		f.ring:SetColorTexture(c[1], c[2], c[3], 1)
		f.ring:Show()
	else
		f.ring:Hide()
	end
	f.count:SetText((a.count and a.count > 1) and tostring(a.count) or "")
	f.bar, f.words = timePieces(f)
	if a.left then
		f.bar:SetValue(a.left / (a.max or a.left))
		f.words:SetText(timeWords(a.left))
	else
		f.bar:Hide()
		f.words:SetText("")
	end
	f:Show()
	return f
end

-- the tray, drawn from made-up auras over where the real one sits
function B.Preview(on)
	B.previewing = on and true or false
	if B.fake then
		B.fake:Hide()
		B.fake = nil
	end
	if B.real then
		B.real:SetShown(not on)
	end
	if not on or not B.holder then
		return nil
	end
	local fake = CreateFrame("Frame", nil, B.holder)
	fake:SetAllPoints(B.holder)
	fake:SetFrameLevel((B.holder:GetFrameLevel() or 1) + 1)
	fake.icons = {}
	for i, spec in ipairs(B.ROWS) do
		local top = B.RowTop(i)
		local list = B.PREVIEW[spec.key]
		local surface = CreateFrame("Frame", nil, fake)
		surface:SetPoint("TOPRIGHT", fake, "TOPRIGHT", B.PAD, top + B.PAD)
		surface:SetSize(#list * B.STEP - B.GAP + 2 * B.PAD, B.ROW_H + 2 * B.PAD)
		BT.Widgets.Panel(surface)
		local layer = CreateFrame("Frame", nil, fake)
		layer:SetAllPoints(fake)
		layer:SetFrameLevel((surface:GetFrameLevel() or 1) + 2)
		-- laid from the right, the last of the list first
		for k = #list, 1, -1 do
			fake.icons[#fake.icons + 1] = fakeTimed(layer, list[k], -(#list - k) * B.STEP, top)
		end
	end
	fake:Show()
	B.fake = fake
	return fake
end

-- ---------------------------------------------------------------------------
-- The module: the tray on, the game's bar away - and back when it is off
-- ---------------------------------------------------------------------------

M.GAME = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }

function M.Stow()
	for _, name in ipairs(M.GAME) do
		if M.live then
			F.Stow(name)
		else
			F.Unstow(name)
		end
	end
end

function M:OnEnable()
	M.live = true
	-- a tray that fails is said, and the game's bar is left where it is
	local ok, err = pcall(B.SetShown, true)
	if not ok then
		if not M.failed then
			M.failed = tostring(err)
			U.Print("the buff tray could not be made: " .. M.failed)
		end
		return
	end
	M.Stow()
end

-- at login, for a module that was already on (OnEnable is only the switch)
function M:OnBind()
	if BT.Enabled("buffs") then
		M:OnEnable()
	end
end

function M:OnDisable()
	M.live = false
	B.Preview(false)
	B.SetShown(false)
	M.Stow()
end

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	page:Note("your buffs on the top line, your debuffs under them · left to right: the soonest to run out, "
		.. "then each a little longer, your weapon enchants, and the ones that never run out, A to Z")
	page:Note("right-click a buff to cancel it, out of combat · switched off, the game's own buff bar is back", true)
	local tray = page:Section("Tray")
	local size = W.Row(tray, "Size", "the whole tray, icons and times")
	local step = size:SetControl(W.Stepper(size, function(dir)
		BT.EnsureBound()
		BT.settings.buffs = BT.settings.buffs or {}
		local now = math.floor(((BT.settings.buffs.scale or 1) + dir * 0.1) * 10 + 0.5) / 10
		BT.settings.buffs.scale = math.max(0.7, math.min(1.5, now))
		B.Place()
		M.sizeText:SetText(("%d%%"):format(math.floor(BT.settings.buffs.scale * 100 + 0.5)))
	end))
	M.sizeText = step.value
	M.sizeText:SetText(("%d%%"):format(math.floor(((BT.settings and BT.settings.buffs
		and BT.settings.buffs.scale) or 1) * 100 + 0.5)))
	W.SwitchRow(tray, "Time left in words", "under each icon · takes a /reload",
		function() return not (BT.settings and BT.settings.buffs and BT.settings.buffs.timeText == false) end,
		function(on)
			BT.EnsureBound()
			BT.settings.buffs = BT.settings.buffs or {}
			-- off is written down, on (the default) is not: `(not on) and false or nil`
			-- was nil either way, and the switch could never turn it off (Josh 2026-09-25)
			if on then
				BT.settings.buffs.timeText = nil
			else
				BT.settings.buffs.timeText = false
			end
		end)
	-- the made-up auras are on the Testing page now (UI/Window.lua)
	page:Layout()
end

function M:ShowTab()
	if BT.Widgets.SyncRows then
		BT.Widgets.SyncRows()
	end
end
