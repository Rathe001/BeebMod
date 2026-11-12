-- Encounter notes: what each boss does and what your role does about it,
-- in a panel beside the dock while you are in a dungeon (Josh 2026-11-06:
-- "When on a boss fight ... dynamically replace the quest panel with a boss
-- encounter notes panel"; beside the dock since 2026-11-10, opened by a tab
-- on its edge).
--
--   ▌ ENCOUNTER                  The Deadmines
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
-- quests (Modules/Tracker/Tracker.lua). The notes were a section under them
-- until 2026-11-10, and are a panel of their own now (M.Build).
--
-- WHICH BOSS. The first one not killed this run, when you come in. Then the
-- one whose fight starts (ENCOUNTER_START). A kill (ENCOUNTER_END, BOSS_KILL)
-- moves it to the next one alive. The arrows look at another, and it stays
-- there until a different boss is seen.
-- BY THE KILLS, IN ORDER (Josh 2026-11-07: "TrueParse just loads them
-- sequentially as they are killed"). Nameplates and targets don't choose:
-- inside a dungeon an enemy's GUID and name are both secret (the Dungeon run
-- record, 2026-11-06, The Hall of Thanes), and a later boss's plate seen
-- across a room would have jumped ahead. A kill whose name matches no boss
-- is the boss shown. The run is kept through a /reload.
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
-- drag. Its panel hangs off the dock's side (M.Build).
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
	-- lowest level first, so the Graveyard leads Scarlet Monastery's four
	local rank = {}
	for i, d in ipairs(BT.Dungeons and BT.Dungeons.LIST or {}) do
		local key = BT.Dungeons.Key(d.name)
		if key then
			rank[key] = i
		end
	end
	table.sort(out, function(x, y)
		local rx, ry = rank[x] or math.huge, rank[y] or math.huge
		if rx ~= ry then
			return rx < ry
		end
		return x < y
	end)
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

-- the wall clock, for time away: it goes on through a reload and a restart
local function clock()
	return BT.Util.Now()
end

-- KEPT THROUGH A RELOAD (Josh 2026-11-07: the notes went back to the first
-- boss). The run is this character's, in the saved settings: the dungeon,
-- the bosses killed, the one shown, and when it was last looked at.
local function saved()
	local guid = plain(rawget(_G, "UnitGUID"), "player")
	if type(guid) ~= "string" or type(BT.settings) ~= "table" then
		return nil, nil
	end
	BT.settings.encounter = BT.settings.encounter or {}
	BT.settings.encounter.runs = BT.settings.encounter.runs or {}
	return BT.settings.encounter.runs, guid
end

function E.Save()
	local r = E.run
	local key = r.key or r.lastKey
	if not key then
		return
	end
	local all, me = saved()
	if not all then
		return
	end
	local killed = {}
	for i in pairs(r.killed) do
		killed[#killed + 1] = i
	end
	table.sort(killed)
	all[me] = { key = key, killed = killed, at = r.at, left = r.leftAt, seen = clock() }
end

-- once a session: the run as it was saved. Inside the same dungeon within
-- half an hour, Enter keeps it.
function E.Load()
	if E.loaded then
		return
	end
	local all, me = saved()
	if not all then
		return
	end
	E.loaded = true
	local s = all[me]
	if type(s) ~= "table" or type(s.key) ~= "string" then
		return
	end
	local killed = {}
	for _, i in ipairs(type(s.killed) == "table" and s.killed or {}) do
		if type(i) == "number" then
			killed[i] = true
		end
	end
	E.run = { lastKey = s.key, killed = killed, at = tonumber(s.at) or 1, held = false,
		leftAt = tonumber(s.left) or tonumber(s.seen) or 0 }
end

-- a name to match by: "Mr. Smite" and "Mr Smite" are one boss
local function lower(s)
	if type(s) ~= "string" or secret(s) then
		return nil
	end
	local k = s:lower():gsub("[^%w]", "")
	return k ~= "" and k or nil
end

-- the boss a fight is, by npc id or by name: its
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
-- PAST THE OPTIONAL ONES (2026-11-07, the second batch): Dire Maul North's
-- guards, Blackrock Depths' bar and the bosses a quest calls up are skipped
-- by most runs. One shows when its fight starts, or when nothing else is left.
function E.NextLive(notes, from)
	local n = #notes.bosses
	if n == 0 then
		return nil
	end
	local start = from or 0
	local spare
	for step = 1, n do
		local i = (start + step - 1) % n + 1
		if not E.run.killed[i] then
			if not notes.bosses[i].optional then
				return i
			end
			spare = spare or i
		end
	end
	return spare
end

-- a new dungeon, or the same one after a long time away: a fresh run
function E.Enter(key, notes)
	local r = E.run
	if r.key == key then
		r.leftAt = nil
		return false
	end
	local away = r.leftAt and (clock() - r.leftAt) or math.huge
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
		r.lastKey, r.key, r.leftAt = r.key, nil, clock()
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
-- which of the bosses that count boss `i` is, and how many count: an
-- optional one is left out of both
function E.Count(notes, i)
	local n, at = 0, 0
	for j, b in ipairs(notes.bosses) do
		if not b.optional then
			n = n + 1
			if j <= i then
				at = n
			end
		end
	end
	return at, n
end

function E.Where(notes, i)
	local boss = notes.bosses[i]
	local at, n = E.Count(notes, i)
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

-- ---------------------------------------------------------------------------
-- The panel beside the dock
-- ---------------------------------------------------------------------------
--
-- A PANEL OF ITS OWN, OPENED BY A TAB (Josh 2026-11-10: "Rather than
-- encounter notes being on the dock, what do you think about having a notes
-- button floating (but attached) to the left of the dock?", then option A of
-- the canvas: "I prefer A too"). In the dock the notes shared its height with
-- the quests, and scrolled in a dungeon with many. Now a tab on the dock's
-- edge, a page with "2/7" under it, opens a panel beside the dock that is as
-- tall as its notes, down to the bottom of the screen. The tab rides the
-- panel's outer edge and shuts it again.
--
-- Both are the dock's: they move, scale and fade with it, and go to its
-- right when the dock is on the left half of the screen. Open or shut is
-- kept for each character. The ENCOUNTER header folds the panel to the boss
-- and the arrows.
E.PANEL_W = 260
E.TAB_W, E.TAB_H = 30, 50
-- LEVEL WITH THE PANEL'S TOP, OPEN ON ITS INNER SIDE (Josh 2026-11-10:
-- "align it with the top of the level row, and remove the right border
-- radius and border? It should look like a tab"). The tab's skin is drawn
-- E.TAB_HIDE wider than the tab and the tab cuts it off, so the inner side's
-- corners and border are never seen, whatever corners and border the Look
-- page sets. The tab overlaps the dock (or the panel) by one border, which
-- its fill covers.
E.TAB_TOP = 0
E.TAB_HIDE = 18
-- UNDER THE MAP, BESIDE WHAT FOLLOWS IT (Josh 2026-11-10: "encounter notes
-- panel is overlapping. Can we attach it to the left of the level row?").
-- The game's buffs sit left of the minimap, and with the map at the top of
-- the dock the panel lay over them. So the panel's top is the map's foot
-- while the map is in the dock: beside the level row, or whatever row is
-- under the map once that one is switched off. With no map in the dock, the
-- dock's top. Under a map dragged low in the dock, less than E.MIN_ROOM
-- would be left, so the panel goes back to the dock's top.
E.MIN_ROOM = 200
E.TAB_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local tab

-- the character the panel is opened or shut for
local function me()
	local guid = plain(rawget(_G, "UnitGUID"), "player")
	return type(guid) == "string" and guid or nil
end

-- open until you shut it
function E.IsOpen()
	local s = BT.settings and BT.settings.encounter
	local id = me()
	return not (s and s.shut and id and s.shut[id])
end

function E.SetOpen(open)
	local id = me()
	if not id then
		return
	end
	setOpt("shut", opt("shut", nil) or {})
	BT.settings.encounter.shut[id] = (not open) or nil
end

-- whether the dock is on the left half of the screen, where the panel goes
-- to its right
function E.OnRight(dock)
	local N = BT.Pill.Number
	if not (dock and dock.GetCenter and UIParent and UIParent.GetWidth) then
		return false
	end
	local x = N((dock:GetCenter()), nil)
	local w = N(UIParent:GetWidth(), nil)
	if not (x and w) then
		return false
	end
	local s = N(dock.GetEffectiveScale and dock:GetEffectiveScale(), 1)
	local us = N(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale(), 1)
	return x * s < w * us / 2
end

-- how far below the dock's top the panel starts: the map's foot, or 0
function E.Below(dock)
	local map = BT.Dock.SectionFrame and BT.Dock.SectionFrame("minimap")
	if not (dock and map and map:IsShown() and map.GetBottom and dock.GetTop) then
		return 0
	end
	local N = BT.Pill.Number
	local top, foot = N(dock:GetTop(), nil), N(map:GetBottom(), nil)
	if not (top and foot) or foot >= top then
		return 0
	end
	local down = math.floor(top - foot + 0.5)
	local room = BT.Dock.Room()
	if room and room - down < E.MIN_ROOM then
		return 0
	end
	return down
end

-- the panel against the dock's side, and the tab against the panel's outer
-- edge, or the dock's while the panel is shut; each overlaps the other by
-- its border, so the two read as one
function M.Place()
	local dock = BT.Dock.Frame()
	if not (frame and tab and dock) then
		return
	end
	local right = E.OnRight(dock)
	M.side = right and "right" or "left"
	local down = E.Below(dock)
	M.down = down
	local open = frame:IsShown()
	local by = open and frame or dock
	local tabY = -(E.TAB_TOP + (open and 0 or down))
	-- over the border it meets, by that border's width
	local over = BT.Pill.Px(dock, (BT.Theme and BT.Theme.Thickness()) or 1) or 1
	frame:ClearAllPoints()
	tab:ClearAllPoints()
	tab.skin:ClearAllPoints()
	tab.skin:SetWidth(E.TAB_W + E.TAB_HIDE)
	if right then
		frame:SetPoint("TOPLEFT", dock, "TOPRIGHT", -1, -down)
		tab:SetPoint("TOPLEFT", by, "TOPRIGHT", -over, tabY)
		tab.skin:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
		tab.skin:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
	else
		frame:SetPoint("TOPRIGHT", dock, "TOPLEFT", 1, -down)
		tab:SetPoint("TOPRIGHT", by, "TOPLEFT", over, tabY)
		tab.skin:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
		tab.skin:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
	end
end

-- the room from the panel's top to the bottom of the screen
local function room()
	local r = BT.Dock.Room()
	return r and math.max(E.MIN_ROOM, r - E.Below(BT.Dock.Frame())) or nil
end

-- the tab lit in the toolkit's green while the panel is open
function E.PaintTab()
	if not tab then
		return
	end
	local W = BT.Widgets
	local open = frame and frame:IsShown()
	if open then
		local c = W.HOVER
		BT.Pill.Recolour(tab.skin, { c[1] * 0.25, c[2] * 0.25, c[3] * 0.25, 0.95 }, c)
	else
		BT.Pill.Recolour(tab.skin, W.FILL, tab.hovered and W.HOVER or W.RIM)
	end
	local lit = open or tab.hovered
	if tab.icon.SetDesaturated then
		pcall(tab.icon.SetDesaturated, tab.icon, not lit)
	end
	tab.icon:SetAlpha(lit and 1 or 0.75)
	local t = lit and INK or MUTED
	tab.count:SetTextColor(t[1], t[2], t[3])
end

function M.Build()
	if frame then
		return frame
	end
	local dock = BT.Dock.Create()
	frame = CreateFrame("Frame", "BeebModEncounter", dock)
	frame:SetWidth(E.PANEL_W)
	frame:SetHeight(60)
	frame:EnableMouse(true)
	BT.Widgets.Panel(frame)
	BT.Widgets.Shadow(frame)
	-- Shift-drag moves the dock from here too
	BT.Dock.MakeHandle(frame)

	-- THE HEADER, which folds it to the boss, with the dungeon at its right
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
	head.where = text(head, HEAD, MUTED)
	head.where:SetPoint("RIGHT", head, "RIGHT", 0, 0)
	head.where:SetPoint("LEFT", head.title, "RIGHT", 8, 0)
	head.where:SetJustifyH("RIGHT")
	head.where:SetWordWrap(false)
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

	-- THE TAB: a page, and which boss of how many
	tab = CreateFrame("Button", "BeebModEncounterTab", dock)
	tab:SetSize(E.TAB_W, E.TAB_H)
	tab:SetFrameLevel(BT.Pill.Number(frame:GetFrameLevel(), 1) + 3)
	if tab.SetClipsChildren then
		pcall(tab.SetClipsChildren, tab, true)
	end
	tab.skin = CreateFrame("Frame", nil, tab)
	tab.skin:SetFrameLevel(BT.Pill.Number(tab:GetFrameLevel(), 1))
	tab.skin:SetHeight(E.TAB_H)
	BT.Widgets.Panel(tab.skin)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(ICON, ICON)
	tab.icon:SetPoint("TOP", tab, "TOP", 0, -9)
	tab.icon:SetTexture(E.TAB_ICON)
	tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tab.count = text(tab, LINE, MUTED)
	tab.count:SetPoint("BOTTOM", tab, "BOTTOM", 0, 8)
	tab.count:SetJustifyH("CENTER")
	tab:RegisterForClicks("AnyUp")
	tab:SetScript("OnClick", function()
		-- the end of a Shift-drag by the tab is not a click
		if BT.Dock.JustMoved() then
			return
		end
		E.SetOpen(not E.IsOpen())
		M.Update()
	end)
	tab:SetScript("OnEnter", function(self)
		self.hovered = true
		E.PaintTab()
		if BT.Tip then
			BT.Tip.Show(self, { build = function(t)
				t:Header({ icon = false, name = "Encounter notes" })
				t:Foot({ { "Click", E.IsOpen() and "hide" or "show" } })
			end })
		end
	end)
	tab:SetScript("OnLeave", function(self)
		self.hovered = false
		E.PaintTab()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	BT.Dock.MakeHandle(tab)
	frame.tab = tab

	frame:Hide()
	tab:Hide()
	-- faded with the dock, and whole again under the pointer like it
	BT.Dock.Attach(frame)
	BT.Dock.Attach(tab)
	-- placed again when the dock is: moved, resized, a new screen
	BT.Dock.AfterLayout(M.Docked)
	return frame
end

M.scroll = 0

-- what is shown and how tall it comes out
function M.Update()
	if not frame then
		return 0
	end
	local key, _, notes = E.Here()
	E.Load()
	if key then
		E.Enter(key, notes)
	else
		E.Leave()
	end
	E.Save()
	E.live = BT.Enabled("encounter") and notes ~= nil and #notes.bosses > 0
	if not E.live then
		frame:Hide()
		tab:Hide()
		M.lastBoss = nil
		return 0
	end
	refont()
	local r = E.run
	if not notes.bosses[r.at] then
		r.at = E.NextLive(notes, nil) or 1
	end
	local boss = notes.bosses[r.at]
	M.lastBoss = boss.name
	-- as the panel counts them: "2/6", and "opt" on an optional boss
	local at, n = E.Count(notes, r.at)
	tab.count:SetText(boss.optional and "opt" or ("%d/%d"):format(at, n))
	tab:Show()
	if not E.IsOpen() then
		frame:Hide()
		M.lines = 0
		M.Place()
		E.PaintTab()
		return 0
	end
	frame:Show()
	local head = frame.head
	head.where:SetText(notes.name or "")
	local shut = opt("collapsed", false)
	BT.Dock.ChevronCoord(head.chevron, shut)

	local w = E.PANEL_W - 2 * PAD
	local listTop = PAD + ROW + GAP
	-- the boss, folded or not
	body.prev:ClearAllPoints()
	body.prev:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -6)
	body.next:ClearAllPoints()
	body.next:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -6)
	body.boss:ClearAllPoints()
	body.boss:SetPoint("TOPLEFT", body, "TOPLEFT", 24, 0)
	body.boss:SetPoint("RIGHT", body, "RIGHT", -24, 0)
	body.boss:SetText(boss.name)
	body.where:ClearAllPoints()
	body.where:SetPoint("TOPLEFT", body, "TOPLEFT", 24, -(ROW + 1))
	body.where:SetPoint("RIGHT", body, "RIGHT", -24, 0)
	body.where:SetText(E.Where(notes, r.at))
	for _, part in ipairs({ body.prev, body.next, body.boss, body.where }) do
		part:Show()
	end
	local y = 2 * ROW + 2
	local shown = 0
	if not shut then
		y = y + GAP
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
		shown = #lines
		y = y - GAP - 2
	else
		for _, b in ipairs(body.roles.buttons) do
			b:Hide()
		end
	end
	for i = shown + 1, #pool do
		pool[i]:Hide()
	end
	M.lines = shown
	body:Show()

	local content = listTop + y + PAD
	M.contentHeight, M.listTop, M.bodyHeight = content, listTop, y
	-- as tall as the notes, down to the bottom of the screen
	M.room = room()
	M.Fit(math.min(content, M.room or content))
	M.Place()
	E.PaintTab()
	return M.lines
end

-- the dock laid out again: placed against it, and measured again if the
-- room under the dock's top changed
function M.Docked()
	if not (frame and tab and tab:IsShown()) then
		return
	end
	M.Place()
	if frame:IsShown() and room() ~= M.room then
		M.Update()
	end
end

-- the panel at `height`: what does not fit under the header scrolls
function M.Fit(height)
	if not (frame and view and body) then
		return
	end
	local content = M.contentHeight or 0
	height = height or content
	M.maxHeight = height
	frame:SetHeight(math.max(1, height))
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

-- the boss a fight is: in these notes, or in another wing of the
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

-- ONE KILL, TWO EVENTS: the game sends ENCOUNTER_END and BOSS_KILL for the
-- same kill. The second comes within a few seconds of the first, for the
-- same fight (when the game says which).
E.SAME_KILL = 5

local function sameKill(id)
	local r = E.run
	local t = now()
	local plainId = (id ~= nil and not secret(id)) and id or nil
	local same = r.lastKill ~= nil and t - r.lastKill < E.SAME_KILL
		and (plainId == nil or r.lastKillId == nil or plainId == r.lastKillId)
	r.lastKill, r.lastKillId = t, plainId
	return same
end

function E.Fight(event, id, name, a, b, success)
	local key, _, notes = E.Here()
	E.Note(event, id, name, a, b, success)
	if not E.live then
		return false
	end
	local kill = event == "BOSS_KILL" or (event == "ENCOUNTER_END" and tonumber(success) == 1)
	if kill and sameKill(id) then
		return false
	end
	local i
	i, notes = E.Match(key, notes, nil, name)
	if not i then
		-- A KILL BY ANOTHER NAME: the game's name for the fight matches none
		-- of ours. The boss shown is the one killed, or with the arrows
		-- looking elsewhere, the first one still alive.
		if not kill then
			return false
		end
		local r = E.run
		i = (not r.held and notes.bosses[r.at]) and r.at or E.NextLive(notes, nil)
		if not i then
			return false
		end
	end
	if event == "ENCOUNTER_START" then
		-- A BOSS YOU KILLED, FIGHTING AGAIN, IS A NEW RUN (2026-11-11, audit):
		-- a run started within E.FRESH_AFTER of the last one kept its kills,
		-- which is every run for a group that resets and goes straight back
		-- in. With every boss marked dead the notes opened on the last one
		-- and stopped moving on. A dead boss cannot start a fight, so its
		-- fight starting says the dungeon is a fresh one.
		if E.run.killed[i] then
			local r = E.run
			E.run = { key = r.key, lastKey = r.lastKey or r.key, killed = {}, at = r.at, held = r.held,
				seen = r.seen }
		end
		E.Seen(i)
	elseif kill then
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
	if event == "ENCOUNTER_START" or event == "ENCOUNTER_END" or event == "BOSS_KILL" then
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
		frame.tab:Hide()
	end
end

M.OnBind = M.OnEnable

function M.Frame() return frame end
function M.Tab() return frame and frame.tab end
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
