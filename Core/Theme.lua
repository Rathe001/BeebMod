-- One look, set in one place (Josh 2026-09-21).
--
-- Every module draws the same surface: a dark fill with a rim around it. Until
-- now that was two constants in UI/Widgets.lua and a hard-coded 1 for the rim's
-- thickness, which meant "what the toolkit looks like" was four files deep and
-- not a setting at all.
--
-- The four things that decide it live here: the fill, the rim, how thick the
-- rim is, and how round the corners are. Everything else reads them.
--
-- THE TABLES ARE MUTATED, NOT REPLACED (Josh 2026-09-21). Modules capture
-- `local FILL = BT.Widgets.FILL` at load, so handing out a NEW table would
-- leave every one of them holding the old colours for the rest of the session.
-- Apply writes into the tables that are already out there.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Theme.lua")

local T = {}
BT.Theme = T

-- What a class looks like, as the client draws it. The rim takes the class
-- colour; the fill takes a very dark wash of it, so a warlock's panels are
-- near-black with a violet cast rather than near-black with a violet edge
-- pasted on.
local CLASS = {
	WARRIOR = { 0.78, 0.61, 0.43 },
	PALADIN = { 0.96, 0.55, 0.73 },
	HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1.00, 0.96, 0.41 },
	PRIEST = { 1.00, 1.00, 1.00 },
	DEATHKNIGHT = { 0.77, 0.12, 0.23 },
	SHAMAN = { 0.00, 0.44, 0.87 },
	MAGE = { 0.25, 0.78, 0.92 },
	WARLOCK = { 0.53, 0.53, 0.93 },
	MONK = { 0.00, 1.00, 0.59 },
	DRUID = { 1.00, 0.49, 0.04 },
	EVOKER = { 0.20, 0.58, 0.50 },
}
T.CLASS = CLASS

-- The toolkit's own, for anyone who does not want their class on the furniture
-- - and the floor if the client will not say what class you are.
local HOUSE = { 0.31, 0.71, 0.55 }
T.HOUSE = HOUSE

T.MIN_THICK, T.MAX_THICK = 1, 4
T.MIN_RADIUS, T.MAX_RADIUS = 0, 12

local function clamp(v, low, high)
	v = BT.Pill.Number(tonumber(v), low)
	if v < low then
		return low
	elseif v > high then
		return high
	end
	return v
end

-- ---------------------------------------------------------------------------
-- What the preset says
-- ---------------------------------------------------------------------------

function T.Class()
	if not UnitClass then
		return nil
	end
	local ok, _, token = pcall(UnitClass, "player")
	if ok and type(token) == "string" and CLASS[token] then
		return token
	end
	return nil
end

-- A rim you can see against the world, and a fill that is nearly black but
-- still carries the hue - a flat near-black under a coloured rim reads as two
-- unrelated decisions.
function T.Preset(token)
	local c = CLASS[token or ""] or HOUSE
	return {
		rim = { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 0.95 },
		fill = { 0.03 + c[1] * 0.045, 0.04 + c[2] * 0.045, 0.04 + c[3] * 0.045, 0.88 },
	}
end

-- ---------------------------------------------------------------------------
-- Reading it
-- ---------------------------------------------------------------------------

local function saved()
	return BT.settings and BT.settings.theme or nil
end

-- "class" follows whoever you are logged in as and changes with them; a colour
-- you picked yourself is yours and is left alone.
function T.Preset_Name()
	local s = saved()
	if s and s.preset == "house" then
		return "house"
	elseif s and s.preset == "custom" then
		return "custom"
	end
	return "class"
end

local function base()
	local name = T.Preset_Name()
	if name == "house" then
		return T.Preset(nil)
	end
	return T.Preset(T.Class())
end

local function colour(which)
	local s = saved()
	if s and T.Preset_Name() == "custom" and type(s[which]) == "table" then
		local c = s[which]
		return { c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1 }
	end
	return base()[which]
end

function T.Fill()
	return colour("fill")
end

function T.Rim()
	return colour("rim")
end

-- THE LIT COLOUR (Josh 2026-09-21). The border is the class colour taken down
-- so it sits quietly around a panel; the accent is what says "this one" - the
-- tab you are on, the switch that is on, the glyph on the dock. It is the same
-- colour at full strength, because two unrelated highlight colours in one
-- window is how a theme stops looking like one.
function T.Accent()
	if T.Preset_Name() == "custom" then
		local c = T.Rim()
		-- a border dark enough to sit quietly is too dark to shout with, so a
		-- custom one is lifted until it reads - the same lift a dark tag gets
		if BT.Util and BT.Util.Bright then
			local r, g, b = BT.Util.Bright({ c[1], c[2], c[3] })
			return { r, g, b, 1 }
		end
		return { c[1], c[2], c[3], 1 }
	end
	local c = CLASS[T.Class() or ""] or HOUSE
	if T.Preset_Name() == "house" then
		c = HOUSE
	end
	return { c[1], c[2], c[3], 1 }
end

-- THE SHAPE IS NOT A SETTING (Josh 2026-09-22). Border width and corner
-- radius were both on the Settings tab, and between them caused more trouble
-- than they were worth: every surface in the addon had to be drawn two ways,
-- and a combination nobody had tried broke something each time. The toolkit
-- has one shape now - a one-pixel border and a three-pixel radius - and any
-- value an older version saved is ignored.
--
-- The override is for the tests, which still draw both shapes to check the
-- drawing; it is never saved.
T.THICKNESS, T.RADIUS = 1, 3

function T.Thickness()
	return clamp(T.thicknessOverride or T.THICKNESS, T.MIN_THICK, T.MAX_THICK)
end

function T.Radius()
	return clamp(T.radiusOverride or T.RADIUS, T.MIN_RADIUS, T.MAX_RADIUS)
end

-- ---------------------------------------------------------------------------
-- Changing it
-- ---------------------------------------------------------------------------

local listeners = {}

-- Anything that has drawn a surface and wants to know the surface changed.
function T.Register(fn)
	if type(fn) == "function" then
		listeners[#listeners + 1] = fn
	end
	return fn
end

function T.Set(name, value)
	BT.EnsureBound()
	BT.settings.theme = BT.settings.theme or {}
	local s = BT.settings.theme
	if name == "fill" or name == "rim" then
		s[name] = { value[1], value[2], value[3], value[4] or (name == "rim" and 0.95 or 0.88) }
		-- picking a colour IS choosing to leave the preset: otherwise the next
		-- login reads the class again and the colour you picked is gone
		s.preset = "custom"
	elseif name == "preset" then
		s.preset = value
		if value ~= "custom" then
			s.fill, s.rim = nil, nil
		end
	elseif name == "thickness" then
		-- not saved: see T.THICKNESS
		T.thicknessOverride = clamp(value, T.MIN_THICK, T.MAX_THICK)
	elseif name == "radius" then
		T.radiusOverride = clamp(value, T.MIN_RADIUS, T.MAX_RADIUS)
	else
		return false
	end
	T.Apply()
	return true
end

-- Puts the four numbers where everything already looks for them, then tells
-- everything that has drawn something to draw it again.
function T.Apply()
	local W = BT.Widgets
	if W then
		local fill, rim, accent = T.Fill(), T.Rim(), T.Accent()
		for i = 1, 4 do
			W.FILL[i] = fill[i]
			W.RIM[i] = rim[i]
			W.ACCENT[i] = accent[i]
		end
		-- the window's nearly solid copy of the fill, and the quiet rim round
		-- a group of rows (see UI/Widgets.lua)
		if W.SOLID then
			for i = 1, 3 do
				W.SOLID[i] = fill[i]
				W.HAIR[i] = rim[i]
			end
			W.SOLID[4] = math.max(fill[4] or 0.88, 0.96)
			W.HAIR[4] = 0.45
		end
		-- a selection is the panel with a wash of the accent through it, not
		-- a second colour: a third of the way from one to the other reads as
		-- "this one" without becoming a block of paint
		for i = 1, 3 do
			W.WASH[i] = fill[i] + (accent[i] - fill[i]) * 0.30
			W.HOVER[i] = accent[i] * 0.75
			W.KNOB[i] = accent[i] + (1 - accent[i]) * 0.55
		end
		W.WASH[4], W.HOVER[4], W.KNOB[4] = 0.95, 1, 1
		-- a button at rest is the panel lifted a step, with a touch of the
		-- accent so it belongs to the same theme as the rim around it
		if W.RAISED then
			for i = 1, 3 do
				W.RAISED[i] = math.min(1, fill[i] + (accent[i] - fill[i]) * 0.08 + 0.03)
			end
			W.RAISED[4] = 0.95
		end
		if W.Retint then
			W.Retint()
		end
	end
	if BT.Pill and BT.Pill.RepaintAll then
		BT.Pill.RepaintAll()
	end
	for _, fn in ipairs(listeners) do
		pcall(fn)
	end
	-- and the modules that dress the client's own furniture, which paint on
	-- top of frames we did not make
	for _, m in ipairs((BT.Modules and BT.Modules()) or {}) do
		if BT.Enabled(m.key) then
			-- Restyle where a module has one, StyleAll where it has only that:
			-- the tracker paints the block behind the quest you are on where it
			-- LAYS OUT, so a colour change it is not told about sits there in
			-- the old theme until the next quest event. ONE OR THE OTHER (Josh
			-- 2026-09-23, audit): a module with both was dressed twice, and its
			-- Restyle is the path that stands aside in combat.
			if m.Restyle then
				pcall(m.Restyle)
			elseif m.StyleAll then
				pcall(m.StyleAll)
			end
		end
	end
	return true
end
