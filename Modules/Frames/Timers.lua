-- YOUR HEALS AND DAMAGE OVER TIME, AS BARS (Josh 2026-09-24: "the HoT
-- running bar ... would help healers keep track of who has a HoT, especially
-- in a raid ... we could do the same for DoTs. It could start blinking
-- faster as it is about to expire").
--
-- A thin bar along the top of the health for your HoT on a friend - party,
-- raid, main tanks, a friendly target - and one stacked above the frame for
-- each of your DoTs on an enemy - target, focus, bosses. Each spell has a lane of its own and a colour of
-- its own, always in the same place, so Corruption is the purple one at the
-- top on every enemy. The bar runs down as the spell does, and in its last
-- seconds the part that has run out flashes red, faster and faster.
--
-- NOTHING HERE READS AN AURA. The client will not let us in a fight (see
-- Auras.lua), so each lane is one of its aura containers told to show only
-- that spell - `includeSpellIDs`, which it honours for your buffs on a
-- friend and your debuffs on an enemy - and its button carries a duration
-- bar the CLIENT runs down (SetDurationBar -> SetTimerDuration).
--
-- The flash is the client's too: see T.BlinkCurve.

-- The spells are yours to choose on the Frames page. A spell is known by
-- name and found in your spellbook, every rank of it, so a lower rank cast
-- from a macro shows too.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Frames/Timers.lua")

local F = BT.UnitFrames
local T = {}
F.Timers = T

local BLANK = "Interface\\Buttons\\WHITE8X8"

-- The heals and the damage over time each class casts, in the order their
-- lanes stack. English names: this client is English, and the names are
-- what the spellbook is searched for.
--
-- ONE HEAL A CLASS (Josh 2026-09-24: "we should only show 1 HoT. Typically
-- I think we'd only track rejuv, renew, and riptide"). The one a healer keeps
-- rolling across a raid; a warlock's damage over time is another matter, and
-- keeps its several lanes. One lane a raid cell is forty containers, not
-- eighty.
T.SPELLS = {
	hot = {
		DRUID = { "Rejuvenation" },
		PRIEST = { "Renew" },
		SHAMAN = { "Riptide" },
	},
	dot = {
		DRUID = { "Moonfire", "Insect Swarm", "Rake", "Rip" },
		PRIEST = { "Shadow Word: Pain", "Devouring Plague", "Holy Fire" },
		WARLOCK = { "Corruption", "Curse of Agony", "Immolate", "Siphon Life" },
		HUNTER = { "Serpent Sting" },
		ROGUE = { "Rupture", "Garrote" },
		WARRIOR = { "Rend" },
		MAGE = { "Fireball", "Pyroblast" },
		SHAMAN = { "Flame Shock" },
	},
}

-- a colour a lane, by its place in the class's list
T.COLOURS = {
	hot = { { 0.36, 0.90, 0.46 }, { 0.30, 0.72, 1.00 }, { 1.00, 0.84, 0.36 } },
	dot = { { 0.76, 0.46, 1.00 }, { 1.00, 0.56, 0.22 }, { 1.00, 0.32, 0.30 }, { 0.40, 0.90, 0.80 } },
}

-- which frames carry which, and how tall a lane is on them
--
-- YOUR TARGET'S, OVER YOUR OWN BARS (Josh 2026-09-24: "they should be
-- displayed above the personal resource bars instead of on the target
-- frame"). The DoTs you are keeping up on your target go over the resource
-- display under your character - "prd", a holder of ours the Resource
-- display module keeps on top of the bars - which is where the eye is while
-- you cast. With that module off there are no bars to sit on, and they go
-- back over the target frame.
T.KINDS = {
	party = { "hot" }, raid = { "hot" }, tank = { "hot" },
	target = { "hot", "dot" }, focus = { "dot" }, boss = { "dot" }, prd = { "dot" },
}

-- whether the resource display carries your target's damage
function T.OnDisplay()
	return BT.Enabled and BT.Enabled("prd") and true or false
end

-- what a frame of this kind shows today
function T.Kinds(kind)
	if kind == "target" and T.OnDisplay() then
		return { "hot" }
	end
	return T.KINDS[kind]
end
T.LANE_H = { party = 3, target = 3, focus = 3, boss = 3, raid = 2, tank = 2 }
-- THICKER, AND SEE-THROUGH (Josh 2026-09-24: "can we make the DoT bars
-- thicker and add a bit of transparency?"). Above the frame they have the
-- room, and they are over the world rather than over the frame, where a
-- solid bar reads as something stuck to the screen.
T.DOT_H = 5
T.DOT_ALPHA, T.DOT_BACK = 0.75, 0.3

-- how tall a lane is: a heal's by the frame's size, damage's thicker
function T.Height(kind, which)
	if which == "dot" then
		return T.DOT_H
	end
	return T.LANE_H[kind] or 3
end
T.MAX_LANES = { hot = 1, dot = 4 }
-- the last seconds, counted down; a blink gets shorter the nearer the end
T.BLINK_FROM = 5

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function myClass()
	if not UnitClass then
		return nil
	end
	local _, token = UnitClass("player")
	return type(token) == "string" and token or nil
end

-- the names this class could track, `which` being "hot" or "dot"
function T.Spells(which, class)
	return (T.SPELLS[which] or {})[class or myClass() or ""] or {}
end

-- A SPELL KEEPS ITS COLOUR, WHEREVER IT GOES: its place in the class's list
function T.Colour(which, name, class)
	local list = T.COLOURS[which]
	for i, n in ipairs(T.Spells(which, class)) do
		if n == name then
			return list[((i - 1) % #list) + 1]
		end
	end
	return list[1]
end

-- YOUR ORDER (Josh 2026-09-24: "allow the player to change the order of
-- dots, so they can stack them however they'd like"). A lane is only there
-- while its spell is, so an empty one leaves a gap in the stack: the ones you
-- always keep up go nearest the frame, the ones you cast now and then on top.
-- The class's spells in the order you left them, first to last - first
-- being the lane nearest the frame. A spell your list has not heard of (a
-- class list that grew) goes after the rest; one it names that the class no
-- longer has is passed over.
function T.Ordered(which, class)
	local spells = T.Spells(which, class)
	local order = F.Opt("timerOrder", nil)
	order = type(order) == "table" and order[class or myClass() or ""] or nil
	if type(order) ~= "table" then
		return spells
	end
	local known, out, seen = {}, {}, {}
	for _, n in ipairs(spells) do
		known[n] = true
	end
	for _, n in ipairs(order) do
		if known[n] and not seen[n] then
			out[#out + 1], seen[n] = n, true
		end
	end
	for _, n in ipairs(spells) do
		if not seen[n] then
			out[#out + 1] = n
		end
	end
	return out
end

-- one place further from the frame (dir 1) or nearer it (dir -1); returns
-- whether it moved
function T.Move(which, name, dir)
	local list = T.Ordered(which)
	local at
	for i, n in ipairs(list) do
		if n == name then
			at = i
		end
	end
	local to = at and at + dir
	if not (to and to >= 1 and to <= #list) then
		return false
	end
	list = { (table.unpack or unpack)(list) }
	list[at], list[to] = list[to], list[at]
	BT.settings.frames = BT.settings.frames or {}
	local s = BT.settings.frames
	s.timerOrder = type(s.timerOrder) == "table" and s.timerOrder or {}
	s.timerOrder[myClass() or ""] = list
	-- only where they sit changes: the containers stay as they are
	T.Rebuild()
	return true
end

-- ---------------------------------------------------------------------------
-- Your choices: every spell on, unless you switched it off
-- ---------------------------------------------------------------------------

local function settings()
	BT.settings.frames = BT.settings.frames or {}
	return BT.settings.frames
end

function T.On(name)
	local off = F.Opt("timersOff", nil)
	return not (type(off) == "table" and off[name])
end

function T.SetOn(name, on)
	local s = settings()
	s.timersOff = type(s.timersOff) == "table" and s.timersOff or {}
	s.timersOff[name] = (not on) or nil
	T.Rebuild()
end

-- BLINK AS IT RUNS OUT (Josh 2026-09-24). In its last seconds a lane's empty
-- part flashes red, under the bar that is left: the countdown number that
-- started this went ("I think we can completely remove the number countdown
-- now. This is attention grabbing enough"). One switch for heals, on the Unit
-- frames page, and one for damage, on the Resource display's; on unless you
-- switch it off.
local BLINK_KEY = { hot = "timerBlinkHot", dot = "timerBlinkDot" }

function T.Blinks(which)
	local on = F.Opt(BLINK_KEY[which] or BLINK_KEY.dot, nil)
	if on == nil then
		return true
	end
	return on and true or false
end

function T.SetBlinks(on, which)
	local s = settings()
	-- on is the default, so only off is written down
	if on then
		s[BLINK_KEY[which] or BLINK_KEY.dot] = nil
	else
		s[BLINK_KEY[which] or BLINK_KEY.dot] = false
	end
	-- what the countdown's days left behind
	s.timerCount, s.timerBlink, s.timerCountHot, s.timerCountDot = nil, nil, nil, nil
	s.timerBarBlink, s.timerBarBlinkHot, s.timerBarBlinkDot = nil, nil, nil
	-- a lane is made blinking or not, and the ones already made are the
	-- client's buttons, so they are made again
	T.Rebuild(true)
end

-- what a lane was made with, to know when to make it again
function T.LaneStyle(which)
	return T.Blinks(which) and "blink" or "still"
end

-- the flash's red, 0-255 as an inline texture takes it
T.COVER = { 255, 92, 77 }

-- the spells a frame of this kind shows, with their colours and the lane
-- each takes: { { which, name, colour, slot }, ... }. Heals and damage count
-- their lanes from the top each - a frame is a friend or an enemy, never
-- both, so the two never show at once.
function T.Lanes(kind)
	local out = {}
	for _, which in ipairs(T.Kinds(kind) or {}) do
		local slot = 0
		for _, name in ipairs(T.Ordered(which)) do
			if T.On(name) and slot < (T.MAX_LANES[which] or 1) then
				slot = slot + 1
				out[#out + 1] = { which = which, name = name, colour = T.Colour(which, name), slot = slot }
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Every rank of a spell, from the spellbook
-- ---------------------------------------------------------------------------

local ids -- [name] = { [spellID] = true }

local function add(out, name, id)
	if type(name) == "string" and type(id) == "number" then
		out[name] = out[name] or {}
		out[name][id] = true
	end
end

local function readBook()
	local out = {}
	pcall(function()
		if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
			local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
			for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
				local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
				if info then
					for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
						local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
						if item then
							add(out, item.name, item.spellID or item.actionID)
						end
					end
				end
			end
		elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
			local book = _G.BOOKTYPE_SPELL or "spell"
			for tab = 1, GetNumSpellTabs() do
				local _, _, offset, n = GetSpellTabInfo(tab)
				for i = offset + 1, offset + n do
					local _, id = GetSpellBookItemInfo(i, book)
					add(out, GetSpellBookItemName(i, book), id)
				end
			end
		end
	end)
	-- and whatever rank the name itself resolves to, should the book list
	-- only the highest
	for _, list in pairs(T.SPELLS) do
		for _, names in pairs(list) do
			for _, name in ipairs(names) do
				local id
				if C_Spell and C_Spell.GetSpellInfo then
					local ok, info = pcall(C_Spell.GetSpellInfo, name)
					id = ok and type(info) == "table" and info.spellID or nil
				elseif GetSpellInfo then
					local ok, _, _, _, _, _, _, sid = pcall(GetSpellInfo, name)
					id = ok and sid or nil
				end
				add(out, name, id)
			end
		end
	end
	return out
end

-- NOT FOUND IS NOT FINAL (Josh 2026-09-24: no bar at all on the first
-- try). The frames are dressed at login, which can be before the client has
-- filled the spellbook in; the empty answer was kept, and nothing asked
-- again. A spell not found is looked for again, at most once a second.
local readAt = -math.huge

local function now()
	return type(GetTime) == "function" and GetTime() or 0
end

function T.Ids(name)
	if not ids or (ids[name] == nil and now() - readAt >= 1) then
		ids = readBook()
		readAt = now()
	end
	return ids[name]
end

-- the same spells as a string, to tell whether a lane's are still the ones
-- the book has (a new rank is a new spell ID)
local function signature(set)
	local list = {}
	for id in pairs(set or {}) do
		list[#list + 1] = id
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- ---------------------------------------------------------------------------
-- The flash: a colour against the seconds left, as a step curve
-- ---------------------------------------------------------------------------

-- how far each lane got, for /bt timers: buttons the client asked us to
-- dress, duration bars and flashes it took
T.seen = { inits = 0, bars = 0, texts = 0 }

-- THE FLASH IS THE CLIENT'S (Josh 2026-09-24, /bt timers in game: 530
-- buttons dressed, 530 bars taken, blinks 0). No script of ours runs on the
-- client's aura buttons, so nothing of ours can blink one. What it will run
-- is a duration TEXT whose colour it takes from a curve over the time left,
-- every frame - and a text can be a picture: an inline texture exactly the
-- lane's size, red. The curve switches it on and off in the last seconds,
-- each half-blink shorter than the last (under a tenth of a second at the
-- very end, half a second when it starts), and keeps it out of sight before.
local curve
function T.BlinkCurve()
	if curve then
		return curve
	end
	pcall(function()
		local c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Step)
		local at, lit = 0, true
		while at < T.BLINK_FROM do
			c:AddPoint(at, CreateColor(1, 1, 1, lit and 1 or 0))
			at = at + 0.07 + 0.09 * at
			lit = not lit
		end
		c:AddPoint(T.BLINK_FROM, CreateColor(1, 1, 1, 0))
		curve = c
	end)
	return curve
end

-- the options the flash is handed over with: the lane-sized red picture as
-- its whole text, our own binding (looked at every frame, the blink being in
-- its colour), and the curve
local function flashOptions(w, h)
	local c = T.BlinkCurve()
	local prop = Enum and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration
	if not (c and prop) then
		return nil
	end
	local r = T.COVER
	local strip = ("|T%s:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(BLANK, h, w, r[1], r[2], r[3])
	local opts = {
		textColor = { curve = c, property = prop },
		textFormat = { formatString = strip, components = {} },
	}
	pcall(function()
		local binding = C_DurationUtil.CreateDurationTextBinding()
		binding:SetUpdateInterval(0)
		binding:SetZeroDurationText("")
		binding:SetExpiredText("")
		opts.binding = binding
	end)
	return opts
end
T.FlashOptions = flashOptions

-- ---------------------------------------------------------------------------
-- A lane: one container, one button, one bar
-- ---------------------------------------------------------------------------

-- A lane, bottom to top: the dark track, the red flash, the bar. UNDER THE
-- BAR (Josh 2026-09-24: "it is sitting on top of the green bar... can it go
-- under?"): what is left of the spell stays in its colour, and the part that
-- has run out flashes red behind it. Each is a frame of its own, a level
-- apart, because a frame always draws over its parent's own textures - the
-- flash, as the button's own text, was hidden under the bar at first.
local function laneButton(w, h, colour, blinks, above)
	return function(b)
		T.seen.inits = T.seen.inits + 1
		b:SetSize(w, h)
		pcall(b.SetMouseClickEnabled, b, false)
		pcall(b.SetMouseMotionEnabled, b, false)
		local level = b:GetFrameLevel() or 1
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, above and T.DOT_BACK or 0.5)
		-- OVERSIZED, AND CUT TO THE LANE (Josh 2026-09-24: "the red bar
		-- still doesn't cover the full rail"): the client drew the picture
		-- short of the lane's end - by whatever it scales a text's picture
		-- by - so it is made twice the lane's width and a few pixels taller,
		-- and the frame it is on clips it to the lane's own edges
		local opts = blinks and flashOptions(w * 2, h + 6) or nil
		if opts and b.SetDurationText then
			-- the client only asks that the text be somewhere inside the button
			local under = CreateFrame("Frame", nil, b)
			under:SetAllPoints()
			under:SetFrameLevel(level + 1)
			if under.SetClipsChildren then
				under:SetClipsChildren(true)
			end
			b.bmCountFrame = under
			local text = under:CreateFontString(nil, "OVERLAY")
			pcall(text.SetFont, text, BT.Fonts.Face("num") or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
				BT.Fonts.Size(10), "")
			-- from the lane's left edge, as wide as the picture makes it
			text:SetPoint("LEFT", b, "LEFT", 0, 0)
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)
			local ok, err = pcall(b.SetDurationText, b, text, opts)
			if ok then
				T.seen.texts = T.seen.texts + 1
			elseif not T.seen.textRefused then
				T.seen.textRefused = tostring(err)
			end
		end
		local bar = CreateFrame("StatusBar", nil, b)
		bar:SetAllPoints()
		bar:SetFrameLevel(level + 2)
		bar:SetStatusBarTexture(BLANK)
		bar:SetStatusBarColor(colour[1], colour[2], colour[3], above and T.DOT_ALPHA or 1)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		b.bmBar = bar
		local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
		if b.SetDurationBar then
			local ok, err = pcall(b.SetDurationBar, b, bar, { direction = dir })
			if ok then
				T.seen.bars = T.seen.bars + 1
			elseif not T.seen.barRefused then
				T.seen.barRefused = tostring(err)
			end
		else
			T.seen.barRefused = "the button has no SetDurationBar"
		end
	end
end
T.LaneButton = laneButton

local function laneFor(b, set, lane)
	local kind = set.kind
	local h = T.Height(kind, lane.which)
	local w = (b.bmSpec and b.bmSpec.w or 100) - 4
	local spells = T.Ids(lane.name)
	if not (spells and next(spells)) then
		return nil
	end
	local spec = {
		key = "timer", max = 1, size = w, cellH = h, inside = true, flowAt = "TOPLEFT",
		filter = lane.which == "hot" and "HELPFUL|PLAYER" or "HARMFUL|PLAYER",
		candidate = { includeSpellIDs = spells },
		init = laneButton(w, h, lane.colour, T.Blinks(lane.which), T.Above(lane.which)),
	}
	local c = F.Auras.Container(set.host, spec, set.unit or b.bmUnit)
	if not c then
		return nil
	end
	c.bmSig = signature(spells)
	c.bmCountdown = T.LaneStyle(lane.which)
	return c
end

-- WHERE A LANE GOES. Your one heal sits along the top of the health, inside
-- the frame, above the name. DAMAGE GOES ABOVE THE FRAME (Josh 2026-09-24,
-- a warlock's target in game: the third lane, Immolate, ran straight through
-- the enemy's name): a warlock keeps three or four going, and stacked
-- inside they reach the name; stacked upwards from the frame's top edge
-- they cover nothing.
function T.Above(which)
	return which == "dot"
end

local function place(c, b, i, kind, which)
	local h = T.Height(kind, which)
	c:ClearAllPoints()
	if T.Above(which) then
		-- the lane's top edge, so the first one's bottom is a pixel clear of
		-- the frame and each next one a lane higher
		c:SetPoint("TOPLEFT", b, "TOPLEFT", 2, 1 + h + (i - 1) * (h + 1))
	else
		c:SetPoint("TOPLEFT", b.health, "TOPLEFT", 0, -(i - 1) * (h + 1))
	end
end
T.Place = place

local function drop(set, c)
	pcall(c.SetEnabled, c, false)
	c:Hide()
	for n = #set.list, 1, -1 do
		if set.list[n] == c then
			table.remove(set.list, n)
		end
	end
end

-- every button that wears lanes, to lay them out again when a choice changes
local wearing = setmetatable({}, { __mode = "k" })
local pending, regen

local function afterFight()
	pending = true
	if not regen then
		regen = CreateFrame("Frame")
		regen:RegisterEvent("PLAYER_REGEN_ENABLED")
		regen:SetScript("OnEvent", function()
			if pending then
				pending = false
				T.Rebuild()
			end
		end)
	end
end

-- The lanes on one button, made, moved or put away to match your choices.
-- Out of combat only: the containers are the client's.
function T.Build(b, remake)
	local set = b and b.bmAuras
	if not (set and T.KINDS[set.kind]) then
		return 0
	end
	if inCombat() then
		afterFight()
		return 0
	end
	wearing[b] = true
	set.timers = set.timers or {}
	local want = {}
	for _, lane in ipairs(T.Lanes(set.kind)) do
		local key = lane.which .. ":" .. lane.name
		want[key] = true
		local c = set.timers[key]
		local spells = T.Ids(lane.name)
		if c and (remake or c.bmSig ~= signature(spells) or c.bmCountdown ~= T.LaneStyle(lane.which)) then
			drop(set, c)
			c = nil
		end
		if not c then
			c = laneFor(b, set, lane)
			if c then
				set.list[#set.list + 1] = c
				pcall(c.SetEnabled, c, not set.off)
			end
			set.timers[key] = c
		end
		if c then
			place(c, b, lane.slot, set.kind, lane.which)
			c:Show()
		end
	end
	local shown = 0
	for key, c in pairs(set.timers) do
		if not want[key] then
			drop(set, c)
			set.timers[key] = nil
		else
			shown = shown + 1
		end
	end
	return shown
end

-- every button, after a choice or a new rank
function T.Rebuild(remake)
	if inCombat() then
		afterFight()
		return
	end
	ids = nil
	if display and not T.OnDisplay() then
		display:Hide()
	end
	for b in pairs(wearing) do
		T.Build(b, remake)
	end
end

-- called by Auras.Attach, once a button has its rows
function T.Attach(b)
	return T.Build(b)
end

-- ---------------------------------------------------------------------------
-- Their settings, for whichever page they belong on
-- ---------------------------------------------------------------------------

-- the blink, as a row, for heals or for damage
function T.BlinkRow(section, which, changed)
	return BT.Widgets.SwitchRow(section, "Blink as it runs out",
		"the last five seconds, the empty part of the lane flashes red",
		function() return T.Blinks(which) end,
		function(on)
			T.SetBlinks(on, which)
			if changed then
				changed()
			end
		end)
end

-- the damage-over-time rows in the order their lanes stack, top lane first
local function orderRows(section, page)
	local rank = {}
	local order = T.Ordered("dot")
	for i, name in ipairs(order) do
		rank[name] = #order - i
	end
	local rows, others = {}, {}
	for _, r in ipairs(section.rows) do
		if r.spell then
			rows[#rows + 1] = r
		else
			others[#others + 1] = r
		end
	end
	table.sort(rows, function(a, b) return (rank[a.spell] or 0) < (rank[b.spell] or 0) end)
	for _, r in ipairs(others) do
		rows[#rows + 1] = r
	end
	section.rows = rows
	if page then
		page:Layout()
	end
end
T.OrderRows = orderRows

-- YOUR ORDER (Josh 2026-09-24): the damage in a section of its own, listed
-- as it stacks - the top lane first, the one nearest the bars last - with a
-- chevron up and down on each and a swatch of its colour. `page` is the
-- stack the section is in, laid out again when a row moves. Nil for a class
-- with nothing to follow.
function T.DotSection(page, changed)
	local spells = T.Spells("dot")
	if #spells == 0 then
		return nil
	end
	local W = BT.Widgets
	local dots = page:Section("Damage over time")
	for _, name in ipairs(spells) do
		local row = W.SwitchRow(dots, name, "",
			function() return T.On(name) end,
			function(on)
				T.SetOn(name, on)
				if changed then
					changed()
				end
			end)
		row.spell = name
		row.swatch = row:CreateTexture(nil, "ARTWORK")
		row.swatch:SetSize(4, 12)
		row.swatch:SetPoint("LEFT", 2, 0)
		local c = T.Colour("dot", name)
		row.swatch:SetColorTexture(c[1], c[2], c[3], 1)
		row.moves = {}
		for n, up in ipairs({ true, false }) do
			local b = CreateFrame("Button", nil, row)
			b:SetSize(16, 16)
			b:SetPoint("RIGHT", row.switch, "LEFT", up and -26 or -8, 0)
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetAllPoints()
			b.icon:SetTexture(BT.Bar.ICONS)
			BT.Bar.ChevronCoord(b.icon, up)
			b.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
			b:SetScript("OnEnter", function(me)
				local a = W.ACCENT
				me.icon:SetVertexColor(a[1], a[2], a[3], 1)
			end)
			b:SetScript("OnLeave", function(me) me.icon:SetVertexColor(0.55, 0.63, 0.59, 1) end)
			-- up the list is up the stack: further from the bars
			b:SetScript("OnClick", function()
				if T.Move("dot", name, up and 1 or -1) then
					orderRows(dots, page)
					if changed then
						changed()
					end
				end
			end)
			row.moves[n] = b
		end
	end
	orderRows(dots, nil)
	W.Row(dots, "Nearest the bars at the bottom",
		"a lane is there only while its spell is · keep the ones you always use low")
	return dots
end

-- /bt timers: where the lanes got to, from the spells found to the blink
local function say(...)
	BT.Util.Print(...)
end

function T.Report()
	local class = myClass()
	say(("over time · %s · blink: heals %s, damage %s"):format(tostring(class),
		T.Blinks("hot") and "on" or "off", T.Blinks("dot") and "on" or "off"))
	for _, which in ipairs({ "hot", "dot" }) do
		for _, name in ipairs(T.Spells(which, class)) do
			local list = {}
			for id in pairs(T.Ids(name) or {}) do
				list[#list + 1] = tostring(id)
			end
			table.sort(list)
			say(("  %s %s · %s · ids %s"):format(which, name, T.On(name) and "on" or "off",
				#list > 0 and table.concat(list, ",") or "|cffff6b6bnone found|r"))
		end
	end
	local frames = 0
	for b in pairs(wearing) do
		frames = frames + 1
		local set = b.bmAuras
		if set and set.timers and (set.unit == "player" or set.kind == "target") then
			for key, c in pairs(set.timers) do
				local kids = c.GetNumChildren and c:GetNumChildren() or 0
				say(("  %s %s · %s · shown %s · buttons %d"):format(set.kind, tostring(set.unit), key,
					tostring(c:IsShown()), kids))
			end
		end
	end
	local s = T.seen
	say(("  frames with lanes %d · buttons dressed %d · duration bars taken %d · flashes taken %d")
		:format(frames, s.inits, s.bars, s.texts))
	if s.barRefused then
		say("  |cffff6b6bduration bar refused|r " .. s.barRefused:sub(1, 120))
	end
	if s.textRefused then
		say("  |cffff6b6bflash refused|r " .. s.textRefused:sub(1, 120))
	end
	if (T.Blinks("hot") or T.Blinks("dot")) and not T.BlinkCurve() then
		say("  |cffff6b6bno colour curve|r - the flash cannot be drawn")
	end
end

if BT.Command then
	BT.Command("timers", function() T.Report() end, "where the over-time bars got to")
end

-- a new rank learned, or the book read for the first time at login
-- ---------------------------------------------------------------------------
-- Over the resource display
-- ---------------------------------------------------------------------------
--
-- A frame of ours standing in for a unit frame: as wide as the display's
-- bars, its top edge on theirs, so the lanes stack above them exactly as they
-- stack above a frame. Its containers watch "target", and are bounced when
-- the target changes, as the target frame's are. The Resource display module
-- says where the bars are (T.OnPRD) whenever it lays them out; the frame is
-- ours and unprotected, so it may follow them in a fight.

local display

local function displayFrame()
	if display then
		return display
	end
	display = CreateFrame("Frame", nil, UIParent)
	display:SetSize(203, 1)
	display:Hide()
	display.health = display
	display.bmSpec = { w = 203 }
	local host = CreateFrame("Frame", nil, display)
	host:SetAllPoints()
	display.bmAuras = { host = host, list = {}, kind = "prd", unit = "target", off = false }
	return display
end
T.Display = function() return display end

-- `anchor` is the display's top bar, or nil when there is none to sit on
function T.OnPRD(anchor)
	if not T.OnDisplay() or not anchor then
		if display then
			display:Hide()
		end
		return false
	end
	local d = displayFrame()
	local width = BT.Pill.Number(BT.Furniture.Call(anchor, "GetWidth"), 199)
	pcall(function()
		d:ClearAllPoints()
		-- two to the left, as a unit frame's health sits two inside it
		d:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -2, 0)
		local strata = BT.Furniture.Call(anchor, "GetFrameStrata")
		if type(strata) == "string" then
			d:SetFrameStrata(strata)
		end
		d:SetFrameLevel(BT.Pill.Number(BT.Furniture.Call(anchor, "GetFrameLevel"), 1) + 5)
		-- a nameplate is drawn at a scale of its own: ours matches it, so a
		-- width measured off the bars is the bars' width here too
		local theirs = BT.Pill.Number(BT.Furniture.Call(anchor, "GetEffectiveScale"), 0)
		local mine = BT.Pill.Number(UIParent:GetEffectiveScale(), 0)
		if theirs > 0 and mine > 0 then
			d:SetScale(theirs / mine)
		end
	end)
	-- the lanes are as wide as the bars; a lane is the client's button, made
	-- to a width, so a new width is new lanes (out of combat)
	local w = math.floor(width + 0.5) + 4
	local remake = d.bmSpec.w ~= w
	d.bmSpec.w = w
	d:SetWidth(w)
	d:Show()
	if remake or not wearing[d] then
		T.Build(d, remake)
	end
	return true
end

-- a new target: its lanes read again (A.Refresh does the same for the frame)
local function bounce()
	local set = display and display.bmAuras
	if set and display:IsShown() then
		set.host:Hide()
		set.host:Show()
	end
end
T.Bounce = bounce

local watch = CreateFrame and CreateFrame("Frame")
if watch then
	watch:RegisterEvent("SPELLS_CHANGED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("PLAYER_TARGET_CHANGED")
	watch:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_TARGET_CHANGED" then
			bounce()
			return
		end
		T.Rebuild()
	end)
end

-- ---------------------------------------------------------------------------
-- The made-up frames: bars drawn by us, part run down, the last one blinking
-- ---------------------------------------------------------------------------

local FAKE_LEFT = { 0.8, 0.45, 0.6, 0.3 }

function T.Show(b, kind)
	b.bmFakeTimers = b.bmFakeTimers or {}
	local lanes = T.Kinds(kind) and T.Lanes(kind) or {}
	-- a made-up friend shows your heals, a made-up enemy your damage
	local friendly = kind ~= "boss" and kind ~= "focus"
	local mine = {}
	for _, lane in ipairs(lanes) do
		if (lane.which == "hot") == friendly then
			mine[#mine + 1] = lane
		end
	end
	local n = 0
	for _, lane in ipairs(mine) do
		do
			n = n + 1
			local f = b.bmFakeTimers[n]
			if not f then
				f = CreateFrame("StatusBar", nil, b)
				f:SetStatusBarTexture(BLANK)
				f.bg = f:CreateTexture(nil, "BACKGROUND")
				f.bg:SetAllPoints()
				f.bg:SetColorTexture(0, 0, 0, 0.5)
				f:SetMinMaxValues(0, 1)
				b.bmFakeTimers[n] = f
			end
			local h = T.Height(kind, lane.which)
			f:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
			f:SetSize((b.bmSpec and b.bmSpec.w or 100) - 4, h)
			place(f, b, n, kind, lane.which)
			local above = T.Above(lane.which)
			f.bg:SetColorTexture(0, 0, 0, above and T.DOT_BACK or 0.5)
			f:SetStatusBarColor(lane.colour[1], lane.colour[2], lane.colour[3], above and T.DOT_ALPHA or 1)
			-- the last one nearly run out, and blinking, as it would with a
			-- second or two left
			local last = n == #mine
			f:SetValue(last and 0.12 or FAKE_LEFT[((n - 1) % #FAKE_LEFT) + 1])
			f:SetAlpha(1)
			-- the flash: between the track and the bar, as on a real lane
			if not f.cover then
				f.cover = f:CreateTexture(nil, "BORDER")
				f.cover:SetAllPoints()
				f.cover:SetColorTexture(T.COVER[1] / 255, T.COVER[2] / 255, T.COVER[3] / 255, 1)
			end
			local blinks = T.Blinks(lane.which) and last
			f:SetScript("OnUpdate", blinks and function(self, elapsed)
				self.t = (self.t or 0) + elapsed
				self.cover:SetAlpha(math.floor(self.t / 0.18) % 2 == 0 and 1 or 0)
			end or nil)
			f.cover:SetAlpha(0)
			f:Show()
		end
	end
	for i = n + 1, #b.bmFakeTimers do
		b.bmFakeTimers[i]:Hide()
	end
	return n
end
