-- Your own buffs and debuffs, in a tray beside the dock (Josh 2026-09-23).
--
-- "A cleaner more consolidated look ... buffs on one line, and debuffs on a
-- different line ... the tray would work best for that, and sort them by
-- duration." The game's bar was a loose row of big icons with a time under
-- each and a collapse arrow; this is two rows of the toolkit's icons, to the
-- left of the dock: your buffs on the top line, your debuffs under them.
--
-- THE ORDER, LEFT TO RIGHT (Josh 2026-09-23: "the perma buffs/debuffs should
-- always be furthest to the right, in ABC order"): the soonest to run out at
-- the far left, then each a little longer, then your weapon enchants, then -
-- against the dock - the ones that never run out, A to Z.
--
-- DRAWN BY THE CLIENT, as the unit frames' auras are (Modules/UnitFrames/Auras.lua):
-- in a fight an addon may not read an aura at all, so each row is one of the
-- client's aura containers, told "player" and what to show, filling buttons
-- we describe - the unit frames' icon, with the time left as a thin bar inside
-- it and as words under it, both kept by the client.
--
-- ONE CONTAINER A ROW (Josh 2026-11-05: "It looks like there is a space for
-- it, but it is offset", an empty slot between the permanent buff and the
-- timed ones, the last timed one outside the border). The buffs' row was two
-- containers and weapon enchant icons of our own, each placed by a count of
-- what stood before it. Counts are read out of a fight only, so a change in
-- one - an enchant that ran out - left a slot empty until the fight ended.
-- Now one container lays out the whole row, in and out of a fight, in parts
-- from the right (B.PART):
--   * permanent: named by spell, A to Z reading left to right. No filter says
--     "no duration", so which spells those are is learned out of a fight, when
--     auras can be read, and a few that are always permanent (stances, forms,
--     stealth, aspects, auras) are known from the start
--   * your weapon enchants - poisons, stones, a shaman's weapon - which the
--     container reads for itself (AddItemEnchantment, Blizzard_AuraContainer)
--   * timed: every aura with a duration (a duration cap keeps permanent ones
--     out - the client's own filter), longest first from the right, so the
--     soonest ends up at the far left
-- THE DEBUFFS' ROW IS ONE PART (2026-10-17, audit). The client will not filter
-- your debuffs by spell (Blizzard_AuraContainerUtil.lua,
-- CanApplyIdentityCandidateFilters: no spell filter for a harmful aura on a
-- unit you can help), so a permanent part there showed nothing, and the timed
-- one's cap kept a debuff with no duration out as well. One part with no cap
-- holds them all; the client sorts the permanent ones after the timed, which
-- from the right is against the dock.
--
-- NO BACKGROUND (Josh 2026-11-05: "Maybe we should just remove the buff and
-- debuff backgrounds, since we cant really control that in combat"). Each row
-- had a panel behind it, as wide as a count read out of a fight or hung off
-- the container's edge. In a fight neither could follow what the client drew,
-- so icons sat outside it. The icons stand on their own now, each with its
-- black edge and its time under it.
--
-- A right-click on a buff or an enchant cancels it (the client allows that
-- out of a fight only).
--
-- A MODULE OF ITS OWN (Josh 2026-09-23: "buffs aren't a part of unit frames"):
-- its own page in the Game frames group and its own switch, and switched off,
-- the game's own buff bar is back.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/UnitFrames/Buffs.lua")

local U = BT.Util
local F = BT.UnitFrames
local A = F.Auras
local B = {}
F.Buffs = B

local M = BT.Module({
	key = "buffs",
	feature = "unitframes",
	title = "Buffs",
	order = 46,
})
B.module = M

B.SIZE = 26 -- an icon
B.GAP = 3 -- between icons
-- the room the rows' backgrounds took, kept so the icons stay where they were
B.PAD = 4 -- around a row
B.TEXT_H = 11 -- the time under an icon
B.ROW_GAP = 5 -- between the two rows
B.EDGE = 8 -- from the dock
B.ROW_H = B.SIZE + B.TEXT_H
B.STEP = B.SIZE + B.GAP
B.PERM_MAX = 12
-- the parts of the buffs' row, from the right
B.PART = { perm = 1, enchants = 2, timed = 3 }
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

-- THE CLIENT'S OWN BANDS (2026-10-17, audit): an enchant's time is written
-- as the client writes an aura's beside it (Blizzard_AuraContainerShared.lua,
-- DefaultAuraDurationFormatter): seconds up to 90 seconds, minutes up to 90
-- minutes, hours up to a day and a half, and cut down, not rounded
local function timeWords(sec)
	if type(sec) ~= "number" then
		return ""
	end
	sec = math.max(0, sec)
	if sec >= 1 + 1.5 * 86400 then
		return ("%d d"):format(math.floor(sec / 86400))
	elseif sec >= 1 + 1.5 * 3600 then
		return ("%d h"):format(math.floor(sec / 3600))
	elseif sec >= 1 + 1.5 * 60 then
		return ("%d m"):format(math.floor(sec / 60))
	end
	return ("%d s"):format(math.floor(sec))
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
		-- the time left in words, always (the settings canvas cut its switch)
		if b.SetDurationText then
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

-- how each part of a row is laid out: icons a step apart, and the next part a
-- step on. The client adds no gap of its own between parts: the last icon's
-- spacing is the gap (Blizzard_SharedXMLBase/AnchorUtil.lua, ApplyFlowLayout).
function B.Layout(part)
	return { elementSpacing = B.GAP, lineSpacing = 2, elementWidth = B.SIZE, elementHeight = B.ROW_H,
		layoutIndex = part }
end

-- a row's container: flowing left from its right edge, on one line
local function trayContainer(parent, lineMax)
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
		pcall(c.SetFlowLayoutMaximumLineSize, c, lineMax)
	end
	pcall(c.SetUnit, c, "player")
	return c
end

-- one part of a row's auras; true when the client took it
local function addPart(c, key, filter, max, candidate, sortMethod, sortDirection, harmful, part)
	return (pcall(c.AddAuraGroup, c, key, filter, {
		maxFrameCount = max,
		initializeFrame = trayButton(B.SIZE, harmful),
		candidateFilters = candidate,
		sortMethod = sortMethod,
		sortDirection = sortDirection,
		layout = B.Layout(part),
	}))
end

-- your weapon enchants, one button a weapon slot, read and timed by the
-- container itself; how many slots it took
local function addEnchants(c)
	local slots = _G.AuraContainerItemEnchantmentSlot
	if not (c.AddItemEnchantment and type(slots) == "table") then
		return 0
	end
	local ids = {}
	for _, id in pairs(slots) do
		if type(id) == "number" then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local n = 0
	for _, id in ipairs(ids) do
		if pcall(c.AddItemEnchantment, c, id, { initializeFrame = trayButton(B.SIZE, false) }) then
			n = n + 1
		end
	end
	if n > 0 and c.SetItemEnchantmentLayout then
		pcall(c.SetItemEnchantmentLayout, c, B.Layout(B.PART.enchants))
	end
	return n
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
		-- the one size (UI/Settings.lua)
		h:SetScale(BT.Scale and BT.Scale() or 1)
	end
	h:ClearAllPoints()
	local dock = BT.Dock and BT.Dock.Frame and BT.Dock.Frame()
	if dock and dock.IsShown and dock:IsShown() then
		h:SetPoint("TOPRIGHT", dock, "TOPLEFT", -(B.EDGE + B.PAD), -B.PAD)
	else
		h:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -(B.PAD + 4))
	end
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
		local row = { spec = spec, enchantSlots = 0 }
		local top = B.RowTop(i)
		row.top = top
		local box = trayContainer(real, (B.PERM_MAX + 3 + spec.max) * B.STEP)
		if box then
			if not spec.harmful then
				-- the permanent ones, A to Z reading left to right: from the
				-- right edge that is Z first (buffs only: see the top of this file)
				addPart(box, "perm", spec.filter, B.PERM_MAX, B.PermFilter(spec.filter), byName, reverse, false,
					B.PART.perm)
				row.enchantSlots = addEnchants(box)
			end
			-- the timed ones, longest first from the right: the soonest far
			-- left; the debuffs' permanent ones with them, against the dock
			if addPart(box, spec.key, spec.filter, spec.max, not spec.harmful and { maxDuration = B.TIMED_MAX } or nil,
				byTime, reverse, spec.harmful, B.PART.timed) then
				box:ClearAllPoints()
				box:SetPoint("TOPRIGHT", real, "TOPRIGHT", 0, top)
				pcall(box.SetEnabled, box, true)
				row.box = box
			else
				pcall(box.SetEnabled, box, false)
				box:Hide()
			end
		end
		B.rows[i] = row
		B.rows[spec.key] = row
	end
	B.Update()
	B.Watch()
	return h
end

-- ---------------------------------------------------------------------------
-- What is on you, out of a fight
-- ---------------------------------------------------------------------------

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
	if fresh and row.box and row.box.SetAuraGroupCandidateFilters then
		pcall(row.box.SetAuraGroupCandidateFilters, row.box, "perm", B.PermFilter(row.spec.filter))
	end
	return fresh
end
B.Learn = learn

-- what the tray does itself, out of a fight: learn which of your buffs are
-- permanent. Where everything goes is the client's.
function B.Update()
	if not (B.holder and B.rows) or inCombat() then
		return
	end
	for _, row in ipairs(B.rows) do
		if not row.spec.harmful then
			local r = B.Read(row.spec.filter)
			if r then
				learn(row, r.ids)
			end
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
	-- yours alone: an aura of anybody else's is no news
	local ok = w.RegisterUnitEvent and pcall(w.RegisterUnitEvent, w, "UNIT_AURA", "player")
	if not ok then
		pcall(w.RegisterEvent, w, "UNIT_AURA")
	end
	w:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" and unit ~= "player" then
			return
		end
		-- a switch made in the fight, made now it is over (B.Enable)
		if event == "PLAYER_REGEN_ENABLED" and B.enableAfter ~= nil then
			B.Enable(B.enableAfter)
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
	B.watch = w
end

-- PUT AWAY, NOT READING (Josh 2026-09-30, review): the tray's containers are
-- the client's, and a hidden one still reads your auras and lays them out. Off
-- with the tray and on with it; the client will not have one switched in a
-- fight, so a change asked for then is made when the fight ends.
function B.Enable(on)
	on = on and true or false
	if not B.rows then
		return false
	end
	if inCombat() then
		B.enableAfter = on
		return false
	end
	B.enableAfter = nil
	for _, row in ipairs(B.rows) do
		if row.box then
			pcall(row.box.SetEnabled, row.box, on)
		end
	end
	return true
end

function B.SetShown(on)
	if on then
		B.Build()
	end
	if B.holder then
		B.holder:SetShown(on and true or false)
		B.Enable(on)
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

-- the tray, drawn from made-up auras over where the real one sits. The
-- made-up auras never change, so the tray is drawn once and shown again
-- (Josh 2026-09-30, review: each switch on built a whole new one, and the
-- client never gives a frame back).
function B.Preview(on)
	B.previewing = on and true or false
	if B.fake then
		B.fake:SetShown(on and true or false)
	end
	if B.real then
		B.real:SetShown(not on)
	end
	if not on or not B.holder then
		return nil
	end
	if B.fake then
		return B.fake
	end
	local fake = CreateFrame("Frame", nil, B.holder)
	fake:SetAllPoints(B.holder)
	fake:SetFrameLevel((B.holder:GetFrameLevel() or 1) + 1)
	fake.icons = {}
	for i, spec in ipairs(B.ROWS) do
		local top = B.RowTop(i)
		local list = B.PREVIEW[spec.key]
		-- laid from the right, the last of the list first
		for k = #list, 1, -1 do
			fake.icons[#fake.icons + 1] = fakeTimed(fake, list[k], -(#list - k) * B.STEP, top)
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
	-- a tray that fails is said, and the game's bar is left where it is; the
	-- error itself goes to the log What loaded prints (2026-10-17, audit: it was
	-- printed raw into chat)
	local ok, err = pcall(B.SetShown, true)
	if not ok then
		if not M.failed then
			M.failed = tostring(err)
			BT.Err("buffs: " .. M.failed)
			U.Print("Buffs: BeebMod couldn't make the buff tray. The default buffs stay.")
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

-- THE TRAY, FOR THE RECORD (Josh 2026-11-05: "We had an alignment issue
-- here"). What each row holds and where its container is, in pixels from
-- the tray's right edge: the Testing page's Record writes it.
function B.Dump()
	local lines = {}
	local real = B.real
	local okR, edge = pcall(function() return real:GetRight() end)
	local right = okR and plainNumber(edge) or nil
	local function from(f)
		if not (f and right) then
			return "?"
		end
		local ok, l, r = pcall(function() return f:GetLeft(), f:GetRight() end)
		l, r = ok and plainNumber(l), ok and plainNumber(r)
		if not (l and r) then
			return "no place"
		end
		return ("%.0f..%.0f"):format(l - right, r - right)
	end
	for _, row in ipairs(B.rows or {}) do
		local r = B.Read(row.spec.filter)
		lines[#lines + 1] = ("%s: permanent=%s timed=%s enchant slots=%s box=%s"):format(row.spec.key,
			tostring(r and r.perm), tostring(r and r.timed), tostring(row.enchantSlots), from(row.box))
	end
	BT.EnsureBound()
	BeebModDB.buffsDump = { at = U.Now(), lines = lines }
	return #lines
end

BT.Record("buffsDump", B.Dump, "buffs")
