-- Encounter notes: what each boss does and what your role does about it,
-- in the dock under the quests while you are in a dungeon (Josh 2026-11-06:
-- "When on a boss fight ... dynamically replace the quest panel with a boss
-- encounter notes panel").
--
--   ▌ ENCOUNTER                         2 of 7
--   ▌ ‹  Sneed's Shredder                   ›
--   ▌    Boss 2 of 7 · then Sneed
--   ▌ [Tank] [Healer] [DPS]
--   ▌    Your role in the group finder
--   ▌  •   Clear the Goblin Woodcarvers in the room first.
--   ▌ TANK Sneed starts with no threat on you. Taunt him.
--   ▌ KICK Cookie's Cooking heals him.
--   ▌      Warrior, Rogue, Mage, Shaman
--
-- BESIDE THE QUESTS, NOT IN PLACE OF THEM (Josh 2026-11-06, the canvas's
-- third board). The first idea swapped the quest list for the notes, which
-- needed a switch back. In a dungeon the tracker lists only that dungeon's
-- quests (Modules/Tracker/Tracker.lua), and the room that leaves is this
-- section's. Each header folds its own part.
--
-- WHICH BOSS. The first one not killed this run, when you come in. Then the
-- one whose fight starts (ENCOUNTER_START). A kill (ENCOUNTER_END, BOSS_KILL)
-- moves it to the next one alive. The arrows look at another, and it stays
-- there until a different boss is seen.
-- NOT BY ITS NAMEPLATE, IN THERE (the Dungeon run record, 2026-11-06, The
-- Hall of Thanes): inside a dungeon an enemy's GUID and name are both
-- secret, on its plate and as your target. The plate and the target are
-- still asked, by npc id and by name, for the day the client says; a
-- secret is never compared.
--
-- WHERE THE NOTES COME FROM: Modules/Encounter/Data.lua, and the research
-- behind each in docs/encounters/.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Encounter/Encounter.lua")

local E = BT.Encounter or {}
BT.Encounter = E

-- ITS SWITCH IS ON GENERAL (Josh 2026-11-06: "We will need to have an
-- option to enable/disable the encounter note switch in our general
-- options"), with Fishing's: no feature, and no row on the Dock's page to
-- drag. The section follows the quest tracker instead (`follows`, UI/Dock.lua).
local M = BT.Module({
	key = "encounter",
	title = "Encounter notes",
	order = 40.5,
})
E.module = M

-- the tracker's sizes and inks, because it sits right under it
local TITLE, LINE, HEAD = 12, 10, 10
local INK = BT.TEXT.ink
local DIM = { 0.58, 0.65, 0.62 }
local MUTED = { 0.42, 0.48, 0.45 }
local LIT = BT.TEXT.lit
local ROW, GAP, PAD = 15, 4, 6
-- AN ICON, NOT A WORD (Josh 2026-11-06: "use icons instead of the role tag.
-- The bullet column is too wide"). A note line starts with the game's role
-- icon, the icon of the spell a skill line asks for, or a dot for everyone,
-- in a column as narrow as the icon.
-- BIG ENOUGH TO TELL APART (Josh 2026-11-06: "Icons are too small to tell
-- what they are"): 16, up from 12
local ICON = 16
-- how far in a note's words start, past its icon
local TEXT_AT = ICON + 5
local ROLE_H = 18
-- the fewest note lines the section is squeezed to, under its header
local MIN_LINES = 2

-- the roles' colours, for their buttons, and a square where an icon is missing
E.COLOURS = {
	tank = { 0.94, 0.76, 0.35 },
	healer = { 0.36, 0.76, 0.55 },
	dps = { 0.91, 0.51, 0.44 },
	kick = { 0.66, 0.76, 0.74 },
	curse = { 0.71, 0.55, 0.91 },
	magic = { 0.45, 0.65, 0.95 },
	poison = { 0.55, 0.80, 0.35 },
	disease = { 0.80, 0.70, 0.40 },
	fear = { 0.76, 0.50, 0.82 },
	stun = { 0.85, 0.62, 0.40 },
	cc = { 0.62, 0.84, 1.00 },
}

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a plain answer from the client, or nil when it won't say or says it in
-- secret
local function plain(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok or secret(a) then
		return nil
	end
	return a, b, c, d, e, f, g, h
end
E.Plain = plain

local function opt(name, fallback)
	local s = BT.settings and BT.settings.encounter
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.encounter = BT.settings.encounter or {}
	BT.settings.encounter[name] = value
end

-- ---------------------------------------------------------------------------
-- Where you are
-- ---------------------------------------------------------------------------

local function zoneKey(name)
	return BT.Quests and BT.Quests.ZoneKey(name) or nil
end

-- the notes' keys for the wings of an instance, by the instance's key
function E.Wings(a, b)
	local out = {}
	for k, n in pairs(BT.EncounterNotes or {}) do
		if n.instance and (n.instance == a or n.instance == b) then
			out[#out + 1] = k
		end
	end
	table.sort(out)
	return out
end

-- A boss of another wing of this instance, seen: that wing is the one you
-- are in. Its key and the boss's place in it, or nil.
function E.OtherWing(key, npc, name)
	local all = BT.EncounterNotes or {}
	local mine = all[key]
	if not (mine and mine.instance) then
		return nil
	end
	for _, k in ipairs(E.Wings(mine.instance)) do
		if k ~= key then
			local i = E.Find(all[k], npc, name)
			if i then
				return k, i
			end
		end
	end
	return nil
end

-- THE DUNGEON YOU ARE IN, whether the notes are switched on or not: the
-- tracker asks it too. Its key, its name, its notes (nil for a dungeon
-- with none yet), and every key it might go by in the quest log - the
-- instance's name and the zone's, which may not be spelled alike. Nil
-- outside a dungeon or raid.
function E.Here()
	if E.demo then
		local notes = BT.EncounterNotes and BT.EncounterNotes[E.demo]
		return E.demo, notes and notes.name or E.demo, notes, { [E.demo] = true }
	end
	local inside, kind = plain(rawget(_G, "IsInInstance"))
	if not inside or (kind ~= "party" and kind ~= "raid") then
		return nil
	end
	local name = plain(rawget(_G, "GetInstanceInfo"))
	local zone = plain(rawget(_G, "GetRealZoneText"))
	local keys = {}
	local a, b = zoneKey(name), zoneKey(zone)
	if a then keys[a] = true end
	if b then keys[b] = true end
	local all = BT.EncounterNotes or {}
	-- the key that has notes, where one does
	local key = (a and all[a] and a) or (b and all[b] and b)
	-- A WING (Scarlet Monastery): the instance may go by the monastery's
	-- name in every wing. The wing whose boss was seen last, or the first.
	if not key then
		local wings = E.Wings(a, b)
		if #wings > 0 then
			key = wings[1]
			for _, k in ipairs(wings) do
				if k == E.wing then
					key = k
				end
			end
		end
	end
	key = key or a or b
	if not key then
		return nil
	end
	local notes = all[key]
	return key, notes and notes.name or name or zone, notes, keys
end

-- ---------------------------------------------------------------------------
-- Which boss
-- ---------------------------------------------------------------------------

-- this visit: the dungeon, the bosses dead, the one shown, whether the
-- arrows chose it, and the last one seen
E.run = { killed = {}, at = 1, held = false }
-- AWAY FOR HALF AN HOUR IS A NEW RUN: a wipe's run back leaves the dungeon
-- and comes in again to the same bosses dead, but a run the next evening
-- starts clean
E.FRESH_AFTER = 1800

local function now()
	return (type(GetTime) == "function" and GetTime()) or 0
end

-- a name to match by: "Mr. Smite" and "Mr Smite" are one boss
local function lower(s)
	if type(s) ~= "string" or secret(s) then
		return nil
	end
	local k = s:lower():gsub("[^%w]", "")
	return k ~= "" and k or nil
end

-- the boss a nameplate, a target or a fight is, by npc id or by name: its
-- place in the dungeon's list, or nil
function E.Find(notes, npc, name)
	if not notes then
		return nil
	end
	local want = lower(name)
	for i, boss in ipairs(notes.bosses) do
		for _, id in ipairs(boss.npc or {}) do
			if npc and id == npc then
				return i
			end
		end
		if want then
			if lower(boss.name) == want then
				return i
			end
			for _, other in ipairs(boss.also or {}) do
				if lower(other) == want then
					return i
				end
			end
		end
	end
	return nil
end

-- the first boss alive after `from` (or from the start), round the list once
function E.NextLive(notes, from)
	local n = #notes.bosses
	if n == 0 then
		return nil
	end
	local start = from or 0
	for step = 1, n do
		local i = (start + step - 1) % n + 1
		if not E.run.killed[i] then
			return i
		end
	end
	return nil
end

-- a new dungeon, or the same one after a long time away: a fresh run
function E.Enter(key, notes)
	local r = E.run
	if r.key == key then
		r.leftAt = nil
		return false
	end
	local away = r.leftAt and (now() - r.leftAt) or math.huge
	if r.lastKey == key and away < E.FRESH_AFTER then
		r.key, r.leftAt = key, nil
		return false
	end
	E.run = { key = key, lastKey = key, killed = {}, at = notes and E.NextLive(notes, nil) or 1, held = false }
	return true
end

function E.Leave()
	local r = E.run
	if r.key then
		r.lastKey, r.key, r.leftAt = r.key, nil, now()
	end
end

-- a boss seen: shown, unless the arrows are on another and it is the same
-- boss seen last time
function E.Seen(i)
	local r = E.run
	if not i then
		return false
	end
	local moved = false
	if not r.held or i ~= r.seen then
		moved = r.at ~= i or r.held
		r.at, r.held = i, false
	end
	r.seen = i
	return moved
end

-- a boss killed: the next one alive is shown, unless the arrows are on
-- another
function E.Killed(notes, i)
	local r = E.run
	if not (notes and i) then
		return false
	end
	r.killed[i] = true
	if r.at == i or not r.held then
		r.at = E.NextLive(notes, i) or r.at
		r.held = false
	end
	return true
end

-- the arrows: one boss on, or back
function E.Step(notes, dir)
	local r = E.run
	local n = notes and #notes.bosses or 0
	if n == 0 then
		return
	end
	r.at = ((r.at or 1) - 1 + dir) % n + 1
	r.held = true
end

-- "Boss 2 of 7 · then Sneed", "Optional · lower deck"
function E.Where(notes, i)
	local boss = notes.bosses[i]
	local n, at = 0, 0
	for j, b in ipairs(notes.bosses) do
		if not b.optional then
			n = n + 1
			if j <= i then
				at = n
			end
		end
	end
	local where = boss.optional and "Optional" or ("Boss %d of %d"):format(at, n)
	if boss.place then
		where = where .. " · " .. boss.place
	end
	return where
end

-- the lines for a role: everyone's, the role's own, and every skill line
function E.Lines(boss, role)
	local out = {}
	for _, l in ipairs(boss and boss.lines or {}) do
		if not l.role or l.role == role then
			out[#out + 1] = l
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- The section
-- ---------------------------------------------------------------------------

local frame, view, body
local pool = {}
-- every font string here and its size, set again on each layout: the face
-- and the size are settings (Core/Fonts.lua)
local fonts = {}

local function setFont(fs, size)
	if BeebModFontHighlightSmall and BeebModFontHighlightSmall.GetFont then
		local face, _, flags = BeebModFontHighlightSmall:GetFont()
		if face then
			pcall(fs.SetFont, fs, face, BT.Fonts.Size(size), flags)
		end
	end
end

local function text(parent, size, colour)
	local fs = parent:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	setFont(fs, size)
	fonts[fs] = size
	fs:SetTextColor(colour[1], colour[2], colour[3])
	fs:SetJustifyH("LEFT")
	return fs
end

local function refont()
	for fs, size in pairs(fonts) do
		setFont(fs, size)
	end
end

local function width()
	local w = BT.Pill.Number(frame and frame:GetWidth(), 0)
	if w < 100 then
		w = BT.Dock.Width()
	end
	return w
end

-- how tall a font string comes out at a width, wrapped
local function measure(fs, w, size)
	fs:SetWidth(math.max(1, w))
	fs:SetWordWrap(true)
	local h = BT.Pill.Number(fs.GetStringHeight and fs:GetStringHeight(), 0)
	if h <= 0 then
		h = BT.Fonts.Size(size) * 1.2
	end
	return math.max(math.ceil(h), ROW - 3)
end

-- a role's icon: the game's own, from its group finder. A client without
-- the atlas gets a square in the role's colour.
-- THE CLASSIC ROLE ICONS (2026-11-06): the shield, the cross and the sword
-- on their round backs, from one sheet the group finder still draws its
-- own role icon with (Blizzard_LFGVanilla_Listing.xml). The newer atlas
-- icons came out as grey smudges at this size. The unit frames draw the
-- same icons before a party member's name (F.DrawRole in Unit.lua).
function E.RoleIcon(tex, role)
	local r = E.ROLES[role]
	if not (r and BT.UnitFrames.DrawRole(tex, r.game)) then
		return false
	end
	tex:SetVertexColor(1, 1, 1, 1)
	tex.what = role
	return true
end

-- a role button: lit in its role's colour while it is yours, quiet with a
-- grey icon while it is not
function E.PaintRole(b)
	local W = BT.Widgets
	local c = E.COLOURS[b.key] or MUTED
	local t
	if b.on then
		BT.Pill.Recolour(b, { c[1] * 0.28, c[2] * 0.28, c[3] * 0.28, 0.95 }, { c[1], c[2], c[3], 1 })
		t = c
	else
		BT.Pill.Recolour(b, W.RAISED, b.hovered and W.HOVER or W.RIM)
		t = b.hovered and BT.TEXT.ink or BT.TEXT.quiet
	end
	b.label:SetTextColor(t[1], t[2], t[3])
	if b.icon.SetDesaturated then
		pcall(b.icon.SetDesaturated, b.icon, not b.on)
	end
	b.icon:SetAlpha(b.on and 1 or 0.7)
end

-- one note line: its icon (or a dot for everyone), its words, and under a
-- skill line what it is and who can do it
local function noteRow(i)
	local row = pool[i]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, body)
	-- a wash in the role's colour behind a role's line
	row.band = row:CreateTexture(nil, "BACKGROUND")
	row.band:SetPoint("TOPLEFT", row, "TOPLEFT", -3, 2)
	row.band:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 3, -2)
	row.band:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetSize(4, 4)
	row.dot:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
	row.dot:SetColorTexture(MUTED[1], MUTED[2], MUTED[3], 1)
	row.words = text(row, LINE, INK)
	-- the first line of words level with the middle of the icon
	row.words:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_AT, -2)
	row.who = text(row, LINE, MUTED)
	pool[i] = row
	return row
end

-- a role's line in the role's colour, a little toward white so it reads
function E.RoleInk(role)
	local c = E.COLOURS[role] or INK
	return { c[1] * 0.75 + INK[1] * 0.25, c[2] * 0.75 + INK[2] * 0.25, c[3] * 0.75 + INK[3] * 0.25 }
end

local function paintLine(row, l, class, w)
	-- YOUR ROLE'S LINES STAND OUT (Josh 2026-11-06: "highlight the role
	-- specific lines in the role color"): their words and a faint band
	local ink = l.role and E.RoleInk(l.role) or INK
	row.words:SetTextColor(ink[1], ink[2], ink[3])
	if l.role then
		local c = E.COLOURS[l.role] or MUTED
		row.band:SetColorTexture(c[1], c[2], c[3], 0.12)
		row.band:Show()
	else
		row.band:Hide()
	end
	if l.role then
		E.RoleIcon(row.icon, l.role)
		row.icon:Show()
		row.dot:Hide()
	elseif l.need and E.SKILLS[l.need] then
		row.icon:SetTexture(E.SKILLS[l.need].icon)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon:SetVertexColor(1, 1, 1, 1)
		row.icon.what = l.need
		row.icon:Show()
		row.dot:Hide()
	else
		row.icon:Hide()
		row.dot:Show()
	end
	row.words:SetText(l[1] or "")
	local tall = math.max(ICON, measure(row.words, w - TEXT_AT, LINE) + 2)
	local who = l.need and E.Who(l.need)
	if who then
		-- "Kick · Warrior, Rogue, Mage, Shaman": the icon's meaning, said
		who = E.SKILLS[l.need].label .. " · " .. who
		row.who:ClearAllPoints()
		row.who:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_AT, -(tall + 1))
		row.who:SetText(who)
		-- in your own class's ink where you are one of them
		local mine = E.Can(l.need, class)
		local c = mine and LIT or MUTED
		row.who:SetTextColor(c[1], c[2], c[3])
		tall = tall + 1 + measure(row.who, w - TEXT_AT, LINE)
		row.who:Show()
	else
		row.who:Hide()
	end
	row:SetHeight(tall)
	return tall
end

function M.Build()
	if frame then
		return frame
	end
	frame = BT.Dock.Section("encounter", 11)
	-- right under the quests, wherever they are in the dock
	frame.follows = "tracker"
	frame.wantWidth = nil
	-- it may be cut short to stay on the screen, after the quests are
	frame.shrinks = true
	frame.Fit = function(_, height)
		M.Fit(height)
	end

	-- THE HEADER, which folds it, and is a handle for the dock like the
	-- tracker's
	local head = CreateFrame("Button", nil, frame)
	head:SetHeight(ROW)
	head:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD)
	head.chevron = head:CreateTexture(nil, "ARTWORK")
	head.chevron:SetSize(12, 12)
	head.chevron:SetPoint("LEFT", 0, 0)
	head.chevron:SetTexture(BT.Dock.ICONS)
	head.chevron:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 1)
	head.title = text(head, HEAD, MUTED)
	head.title:SetPoint("LEFT", head, "LEFT", 18, 0)
	head.title:SetText(string.upper("Encounter"))
	head.hot = head:CreateTexture(nil, "BACKGROUND")
	head.hot:SetAllPoints()
	head.hot:Hide()
	head:SetScript("OnEnter", function(self)
		local c = BT.Widgets.RIM
		self.hot:SetColorTexture(c[1], c[2], c[3], 0.10)
		self.hot:Show()
	end)
	head:SetScript("OnLeave", function(self)
		self.hot:Hide()
	end)
	head:SetScript("OnClick", function()
		setOpt("collapsed", not opt("collapsed", false))
		M.Update()
	end)
	head:RegisterForClicks("AnyUp")
	BT.Dock.MakeHandle(head)
	frame.head = head

	-- everything under the header scrolls inside this
	view = CreateFrame("Frame", nil, frame)
	if view.SetClipsChildren then
		pcall(view.SetClipsChildren, view, true)
	end
	body = CreateFrame("Frame", nil, view)
	frame.view, frame.body = view, body

	-- the boss and the arrows either side of it
	body.prev = BT.Widgets.Button(body, "<", 18, 18)
	body.prev:SetScript("OnClick", function()
		local _, _, notes = E.Here()
		E.Step(notes, -1)
		M.Update()
	end)
	body.next = BT.Widgets.Button(body, ">", 18, 18)
	body.next:SetScript("OnClick", function()
		local _, _, notes = E.Here()
		E.Step(notes, 1)
		M.Update()
	end)
	body.boss = text(body, TITLE, INK)
	body.boss:SetWordWrap(false)
	body.where = text(body, LINE, MUTED)
	body.where:SetWordWrap(false)

	-- THE ROLE BUTTONS, IN THEIR COLOURS (Josh 2026-11-06: "Maybe color
	-- code the buttons"): each with the game's role icon, and the one you
	-- are lit in its role's colour. The line saying where the role came
	-- from went the same day ("I think we can remove 'Your pick'").
	body.roles = { buttons = {} }
	for _, key in ipairs(E.ROLE_ORDER) do
		local b = BT.Widgets.Button(body, E.ROLES[key].label, 60, ROLE_H)
		b.key = key
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(ICON, ICON)
		E.RoleIcon(b.icon, key)
		b.label:ClearAllPoints()
		b.label:SetPoint("CENTER", b, "CENTER", (ICON + 3) / 2, 0)
		b.icon:SetPoint("RIGHT", b.label, "LEFT", -3, 0)
		b:SetScript("OnEnter", function(self) self.hovered = true; E.PaintRole(self) end)
		b:SetScript("OnLeave", function(self) self.hovered = false; E.PaintRole(self) end)
		b:SetScript("OnClick", function(self)
			E.Role.Pick(self.key)
			M.Update()
		end)
		body.roles.buttons[#body.roles.buttons + 1] = b
	end
	body.roles.Select = function(self, role)
		for _, b in ipairs(self.buttons) do
			b.on = b.key == role
			E.PaintRole(b)
		end
	end

	frame.thumb = frame:CreateTexture(nil, "OVERLAY")
	frame.thumb:SetWidth(2)
	BT.Widgets.Lit(frame.thumb, 0.55)
	frame.thumb:Hide()
	frame:EnableMouseWheel(false)
	frame:SetScript("OnMouseWheel", function(_, delta)
		local over = math.max(0, (M.contentHeight or 0) - (M.maxHeight or 0))
		if over <= 0 then
			return
		end
		local was = M.scroll
		M.scroll = math.max(0, math.min(over, M.scroll - delta * ROW * 3))
		if M.scroll ~= was then
			M.Fit(M.maxHeight)
		end
	end)
	frame:Hide()
	return frame
end

M.scroll = 0

-- what is shown and how tall it comes out; the dock is asked again only
-- when that changes
function M.Update()
	if not frame then
		return 0
	end
	local wasShown = frame:IsShown()
	local key, _, notes = E.Here()
	if key then
		E.Enter(key, notes)
	else
		E.Leave()
	end
	E.live = BT.Enabled("encounter") and notes ~= nil and #notes.bosses > 0
	if not E.live then
		frame:Hide()
		M.lastBoss = nil
		if wasShown then
			BT.Dock.Relayout()
		end
		return 0
	end
	frame:Show()
	refont()
	local r = E.run
	if not notes.bosses[r.at] then
		r.at = E.NextLive(notes, nil) or 1
	end
	local boss = notes.bosses[r.at]
	M.lastBoss = boss.name
	local head = frame.head
	local shut = opt("collapsed", false)
	BT.Dock.ChevronCoord(head.chevron, shut)

	local w = width() - 2 * PAD
	local listTop = PAD + ROW + GAP
	local y = 0
	if not shut then
		-- the boss
		body.prev:ClearAllPoints()
		body.prev:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 6))
		body.next:ClearAllPoints()
		body.next:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(y + 6))
		body.boss:ClearAllPoints()
		body.boss:SetPoint("TOPLEFT", body, "TOPLEFT", 24, -y)
		body.boss:SetPoint("RIGHT", body, "RIGHT", -24, 0)
		body.boss:SetText(boss.name)
		body.where:ClearAllPoints()
		body.where:SetPoint("TOPLEFT", body, "TOPLEFT", 24, -(y + ROW + 1))
		body.where:SetPoint("RIGHT", body, "RIGHT", -24, 0)
		body.where:SetText(E.Where(notes, r.at))
		y = y + 2 * ROW + GAP + 2

		-- the role: three buttons across the width
		local role, from = E.Role.Current()
		local gap = 4
		local bw = math.floor((w - 2 * gap) / 3)
		for n, b in ipairs(body.roles.buttons) do
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", body, "TOPLEFT", (n - 1) * (bw + gap), -y)
			b:SetSize(bw, ROLE_H)
			b:Show()
		end
		body.roles:Select(role)
		y = y + ROLE_H + GAP + 4
		M.role, M.roleFrom = role, from

		-- the notes
		local class = E.Role.Class()
		local lines = E.Lines(boss, role)
		for i, l in ipairs(lines) do
			local row = noteRow(i)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
			row:SetWidth(w)
			local tall = paintLine(row, l, class, w)
			row:Show()
			y = y + tall + GAP + 2
		end
		for i = #lines + 1, #pool do
			pool[i]:Hide()
		end
		M.lines = #lines
		y = y - GAP - 2
		for _, part in ipairs({ body.prev, body.next, body.boss, body.where }) do
			part:Show()
		end
		body:Show()
	else
		body:Hide()
		M.lines = 0
	end

	local content = listTop + (shut and 0 or (y + PAD)) - (shut and GAP or 0)
	content = math.max(24, content)
	M.contentHeight, M.listTop, M.bodyHeight = content, listTop, y
	-- squeezed, it keeps its header, the boss, the role and two lines
	local floor = listTop + 2 * ROW + GAP + 2 + ROLE_H + GAP + 4 + MIN_LINES * (ROW + GAP) + PAD
	local minHeight = math.min(content, floor)
	if wasShown and frame.wantHeight == content and frame.minHeight == minHeight then
		M.Fit(M.maxHeight)
		return M.lines
	end
	frame.wantHeight, frame.minHeight = content, minHeight
	frame:SetHeight(content)
	M.maxHeight = content
	BT.Dock.Relayout()
	return M.lines
end

-- the height the dock gave it: scroll what does not fit under the header
function M.Fit(height)
	if not (frame and view and body) then
		return
	end
	local content = M.contentHeight or 0
	height = height or content
	M.maxHeight = height
	local listTop = M.listTop or 0
	local over = math.max(0, content - height)
	M.scroll = math.max(0, math.min(M.scroll, over))
	view:ClearAllPoints()
	view:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -listTop)
	view:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -listTop)
	view:SetHeight(math.max(1, height - listTop - PAD))
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", view, "TOPLEFT", 0, M.scroll)
	body:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, M.scroll)
	body:SetHeight(math.max(1, M.bodyHeight or 1))
	frame:EnableMouseWheel(over > 0)
	local thumb = frame.thumb
	if over > 0 then
		local track = math.max(1, height - listTop - PAD)
		local h = math.max(12, math.floor(track * height / content + 0.5))
		local at = listTop + (track - h) * (M.scroll / over)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -at)
		thumb:SetHeight(h)
		thumb:Show()
	else
		thumb:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- What the game says
-- ---------------------------------------------------------------------------

local function npcOf(guid)
	return type(guid) == "string" and not secret(guid)
		and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")) or nil
end

-- the boss a unit or a fight is: in these notes, or in another wing of the
-- same instance, which then becomes the wing you are in (a fresh run of
-- it). Its place, and the notes it is in.
function E.Match(key, notes, npc, name)
	local i = E.Find(notes, npc, name)
	if i then
		return i, notes
	end
	local wing, at = E.OtherWing(key, npc, name)
	if not wing then
		return nil, notes
	end
	E.wing = wing
	local other = BT.EncounterNotes[wing]
	E.Enter(wing, other)
	return at, other
end

-- the elites a record writes down: a boss is one of them
local ELITE = { elite = true, rareelite = true, worldboss = true }

-- a unit that may be a boss: its nameplate, or your target
function E.Look(unit)
	if not (E.live or E.recording) then
		return false
	end
	local npc = npcOf(plain(rawget(_G, "UnitGUID"), unit))
	local name = plain(rawget(_G, "UnitName"), unit)
	-- in a dungeon both are secret (the Dungeon run record, 2026-11-06):
	-- nothing to match, so nothing more to ask
	if npc == nil and name == nil and not E.recording then
		return false
	end
	local key, _, notes = E.Here()
	local i
	i, notes = E.Match(key, notes, npc, name)
	if E.recording and key then
		local rank = plain(rawget(_G, "UnitClassification"), unit)
		if i or ELITE[rank] then
			-- as the game gave them, secret or not
			local okG, guid = pcall(rawget(_G, "UnitGUID") or error, unit)
			local okN, raw = pcall(rawget(_G, "UnitName") or error, unit)
			E.Note("unit", unit, rank, okG and guid or nil, okN and raw or nil, npc, i)
		end
	end
	if not E.live then
		return false
	end
	if i and E.Seen(i) then
		M.Update()
		return true
	end
	return false
end

function E.Fight(event, id, name, a, b, success)
	local key, _, notes = E.Here()
	E.Note(event, id, name, a, b, success)
	if not E.live then
		return false
	end
	local i
	i, notes = E.Match(key, notes, nil, name)
	if not i then
		return false
	end
	if event == "ENCOUNTER_START" then
		E.Seen(i)
	elseif event == "BOSS_KILL" or (event == "ENCOUNTER_END" and tonumber(success) == 1) then
		E.Killed(notes, i)
	else
		return false
	end
	M.Update()
	return true
end

local function onEvent(_, event, ...)
	if not BT.Enabled("encounter") then
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		E.Look((...))
	elseif event == "PLAYER_TARGET_CHANGED" then
		E.Look("target")
	elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" or event == "BOSS_KILL" then
		local id, name, a, b, success = ...
		if event == "BOSS_KILL" then
			id, name = ...
		end
		E.Fight(event, id, name, a, b, success)
	else
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
			E.NoteWhere()
		end
		M.Queue()
	end
end

local pending = false
function M.Queue()
	if not (C_Timer and C_Timer.After) then
		M.Update()
		return
	end
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		M.Update()
	end)
end

function M.Watch()
	if M.events then
		return
	end
	M.events = CreateFrame("Frame")
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
		"NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED",
		"ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
		-- your role: the group's and the finder's
		"GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
	}) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	M.events:SetScript("OnEvent", onEvent)
end

function M:OnEnable()
	M.Build()
	M.Watch()
	M.Update()
end

function M:OnDisable()
	E.live = false
	if frame then
		frame:Hide()
		BT.Dock.Relayout()
	end
end

M.OnBind = M.OnEnable

function M.Frame() return frame end
function M.Rows() return pool end
function M.Restyle() return M.Update() end

function M.Status()
	local key, _, notes = E.Here()
	if not key then
		return "not in a dungeon"
	end
	return notes and ("%s · %s"):format(notes.name, M.lastBoss or "no boss shown") or "no notes for this dungeon"
end

-- MADE-UP DATA (the Testing page): you are in The Deadmines
BT.Demo.Register("encounter", {
	on = function()
		E.demo = "deadmines"
		M.Update()
		if BT.GetModule("tracker") and BT.GetModule("tracker").Update then
			BT.GetModule("tracker").Update()
		end
	end,
	off = function()
		E.demo = nil
		M.Update()
		if BT.GetModule("tracker") and BT.GetModule("tracker").Update then
			BT.GetModule("tracker").Update()
		end
	end,
})

-- ---------------------------------------------------------------------------
-- A record for Claude: one dungeon run, as it happens
-- ---------------------------------------------------------------------------
--
-- What the notes rest on and nobody has seen yet (2026-11-06): the
-- dungeon's name as the instance gives it and as the quest log files it,
-- whether a boss's GUID and name read plain in there, what a fight's start
-- and end say, and what the role calls answer in a group. Recording starts
-- from the Testing page's Record button and stops when you leave the
-- dungeon you recorded in, or after E.RECORD_MAX lines.
E.RECORD_MAX = 400

local function said(v)
	if v == nil then
		return "nil"
	end
	if secret(v) then
		return "secret"
	end
	return tostring(v)
end

function E.Note(...)
	local rec = E.recording and type(BeebModDB) == "table" and BeebModDB.encounterDump
	if not rec then
		return
	end
	if #rec.lines >= E.RECORD_MAX then
		E.recording = false
		return
	end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = said((select(i, ...)))
	end
	rec.lines[#rec.lines + 1] = ("%.1f "):format(now()) .. table.concat(parts, " | ")
	rec.at = BT.Util.Now()
end

-- where you are, the quest log's headings and your role's answers
function E.NoteWhere()
	if not E.recording then
		return
	end
	local inside, kind = plain(rawget(_G, "IsInInstance"))
	E.Note("where", inside, kind, plain(rawget(_G, "GetRealZoneText")))
	E.Note("instance", plain(rawget(_G, "GetInstanceInfo")))
	local Q = rawget(_G, "C_QuestLog")
	if type(Q) == "table" and Q.GetNumQuestLogEntries and Q.GetInfo then
		local n = tonumber((plain(Q.GetNumQuestLogEntries))) or 0
		for i = 1, n do
			local info = plain(Q.GetInfo, i)
			if type(info) == "table" and info.isHeader then
				E.Note("heading", info.title, info.isCollapsed)
			end
		end
	end
	E.Note("role", plain(rawget(_G, "IsInGroup")), plain(rawget(_G, "UnitGroupRolesAssigned"), "player"),
		E.Role.Finder(), E.Role.Class())
	local T = rawget(_G, "C_EncounterTimeline")
	local fns = {}
	for k, v in pairs(type(T) == "table" and T or {}) do
		if type(v) == "function" then
			fns[#fns + 1] = k
		end
	end
	table.sort(fns)
	E.Note("timeline", #fns > 0 and table.concat(fns, ",") or "none")
	if inside then
		E.recordedIn = true
	elseif E.recordedIn then
		-- out of the dungeon recorded in: the record is done
		E.Note("done")
		E.recording, E.recordedIn = false, nil
		BT.Util.Print("Encounter notes: the dungeon run is written down. Type /reload to save it.")
	end
end

-- the Record button: start writing, from now
function E.Record()
	BT.EnsureBound()
	BeebModDB.encounterDump = { at = BT.Util.Now(), lines = {} }
	E.recording, E.recordedIn = true, nil
	E.NoteWhere()
end

BT.Record("encounterDump", function()
	E.Record()
end, "encounter", "your next dungeon run")
