-- One unit button, drawn in the toolkit's clothes (Josh 2026-09-23).
--
-- Every unit frame in the addon is one of these: the player, the target, a
-- party member, a raid member, a boss. What differs is its size and which
-- pieces it wears; the drawing is the same, which is the point of style A -
-- class-coloured health on the toolkit's dark fill, inside its rim.
--
-- NOTHING HERE READS A NUMBER (the probes of 2026-09-23). On this client a
-- unit's health, power, heals, shield and range come back as SECRET values -
-- out of combat as well as in, for the player as well as the target. They may
-- be handed to a widget and to nothing else: no arithmetic, no comparison, no
-- test for truth. So each piece takes what the client gives and passes it on:
--
--   the bars          StatusBar:SetValue, and SetMinMaxValues for the ceiling
--   the text          formatted by the client - string.format, TruncateWhenZero,
--                     WrapString - into a string that is itself secret, and set
--   range             SetAlphaFromBoolean on the secret answer to UnitInRange
--   your target       the same, on the outline, when UnitIsUnit is secret
--   a shield          clamped by the client's calculator, which also says
--                     whether it fitted; that answer picks the bar shown
--   cast bars         a Duration object from UnitCastingDuration, run by the bar
--   combo points      five bars from i - 1 to i, as the resource display draws them
--
-- The plain answers (dead, offline, level, reaction, threat, leader, marker,
-- ready check) are read as ordinary values, each behind an issecretvalue guard
-- in case a later build hides them too.
--
-- A button is secure when it is a real unit frame (a click targets, a right
-- click opens the menu), and plain when it is a preview (Made-up people, on
-- the Testing page).
-- A preview takes its numbers from a table rather than the client; see F.Fake.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/UnitFrames/Unit.lua")

local F = BT.UnitFrames or {}
BT.UnitFrames = F

local W = BT.Widgets
-- a panel with no edge: the theme's fill, and nothing drawn round it
local NO_EDGE = { 0, 0, 0, 0 }
local BLANK = "Interface\\Buttons\\WHITE8X8"
-- FIRA CODE (Josh 2026-09-23: "hard to read but too large at the same time").
-- The game's face with an outline blurred at these sizes - the outline eats
-- the counters of every letter - and had to be set large to survive it. Fira
-- Code is drawn for screens at small sizes and reads with a one-pixel shadow
-- instead of an outline. It is one choice among several now (Core/Fonts.lua):
-- the frames use whatever face the toolkit writes in, the heavier weight for
-- names, with the shadow whatever the face.
local Fonts = BT.Fonts

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end
F.Secret = secret

-- A SECRET MARK, DRAWN BY THE CLIENT (Josh 2026-09-27). The mark on a unit may
-- come back as a secret: nothing of ours may read it, compare it or do sums
-- with it, but a call of the client's may be handed it. The client's own
-- icon call first, then a sprite sheet's cell - the sheet is four by four,
-- the marks its first eight - and whichever this client takes is kept in
-- F.markerWith, which What loaded reports when it is none. True when the
-- mark is drawn.
function F.DrawMarker(tex, marker)
	if F.markerWith ~= false and _G.SetRaidTargetIconTexture and F.markerWith ~= "SetSpriteSheetCell" then
		if pcall(_G.SetRaidTargetIconTexture, tex, marker) then
			F.markerWith = "SetRaidTargetIconTexture"
			return true
		end
	end
	if tex.SetSpriteSheetCell then
		tex:SetTexCoord(0, 1, 0, 1)
		if pcall(tex.SetSpriteSheetCell, tex, marker, 4, 4) then
			F.markerWith = "SetSpriteSheetCell"
			return true
		end
	end
	F.markerWith = false
	return false
end

-- a plain value from the client, or nil when it will not say or says in secret
local function plain(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or secret(v) then
		return nil
	end
	return v
end
F.Plain = plain

-- the same call, whatever came back: for handing straight to a widget.
-- EVERY VALUE (Josh 2026-09-23, audit): it gave back the first two, so the
-- eighth of UnitCastingInfo - whether a cast can be kicked - was never seen.
local function pass(ok, ...)
	if ok then
		return ...
	end
	return nil
end

local function raw(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	return pass(pcall(fn, ...))
end
F.Raw = raw

-- ---------------------------------------------------------------------------
-- Colours
-- ---------------------------------------------------------------------------

-- the client's own, where it will say; the toolkit's copy where it will not
local function classColour(token)
	if type(token) ~= "string" then
		return nil
	end
	local c = (BT.Theme and BT.Theme.CLASS and BT.Theme.CLASS[token])
	if c then
		return c
	end
	local rc = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[token]
	return rc and { rc.r, rc.g, rc.b } or nil
end

local REACTION = {
	hostile = { 0.82, 0.27, 0.24 },
	neutral = { 0.90, 0.78, 0.29 },
	friendly = { 0.34, 0.72, 0.47 },
	tapped = { 0.50, 0.50, 0.50 },
	gone = { 0.35, 0.35, 0.35 },
}
F.REACTION = REACTION

local POWER = {
	MANA = { 0.25, 0.50, 0.88 }, RAGE = { 0.78, 0.26, 0.23 }, ENERGY = { 0.91, 0.85, 0.29 },
	FOCUS = { 0.90, 0.55, 0.25 }, RUNIC_POWER = { 0.00, 0.82, 1.00 },
}

-- A CLASS COLOUR A STEP DEEPER (style A). Laid straight on the dark fill, a
-- priest's white or a rogue's yellow is too bright to put white type on; a
-- third of the way toward the fill it still says whose frame it is, and the
-- outlined name reads on every class.
--
-- AND THE PALE ONES FURTHER (Josh 2026-09-23). A third was not enough for a
-- priest's white or a rogue's yellow: white type with a shadow on them was the
-- hardest thing in a raid to read. Rather than name the classes, a colour is
-- taken down until it is no brighter than BRIGHTEST, so any colour pale
-- enough to wash the type out - a class, a reaction, one a later build adds -
-- gets the same treatment, and the rest are left at the third.
local DEEPEN, BRIGHTEST = 0.34, 0.50
local function luminance(c)
	return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
end

-- how far toward the fill: a third, or far enough that the mix lands on
-- BRIGHTEST - measured against the fill itself, which is dark but not black
function F.DeepenBy(c)
	local lum, floor = luminance(c), luminance(W.FILL)
	if lum <= BRIGHTEST or lum <= floor then
		return DEEPEN
	end
	return math.max(DEEPEN, math.min(0.8, (lum - BRIGHTEST) / (lum - floor)))
end
local function deepen(c)
	local f = W.FILL
	local by = F.DeepenBy(c)
	return c[1] + (f[1] - c[1]) * by, c[2] + (f[2] - c[2]) * by, c[3] + (f[3] - c[3]) * by
end
F.Deepen = deepen

-- what colour a unit's health is, and why: its class for a player, its
-- reaction for anything else, grey for one you cannot tag or cannot reach
function F.HealthColour(src)
	if src:Gone() then
		return REACTION.gone
	end
	if src:Charmed() then
		return REACTION.hostile
	end
	local cls = src:IsPlayer() and classColour(src:Class())
	if cls then
		return cls
	end
	if src:Tapped() then
		return REACTION.tapped
	end
	return REACTION[src:Reaction()] or REACTION.neutral
end

-- ---------------------------------------------------------------------------
-- Where the numbers come from: the client, or a table
-- ---------------------------------------------------------------------------

local SCALE100 = _G.CurveConstants and _G.CurveConstants.ScaleTo100

local Live = {}
Live.__index = Live

-- ONE A UNIT, KEPT (Josh 2026-09-23, audit): a new table for every paint,
-- and forty cells in a fight paint many times a second. A source holds
-- nothing but its unit token, and there are only so many of those.
local sources = {}
function F.Source(unit)
	if unit == nil then
		return setmetatable({}, Live)
	end
	local s = sources[unit]
	if not s then
		s = setmetatable({ unit = unit }, Live)
		sources[unit] = s
	end
	return s
end

function Live:Exists() return plain(UnitExists, self.unit) and true or false end
-- TWO-PART NAMES (see Core/Util.lua): UnitName gives "Elyan", GetUnitName
-- gives "Elyan Ellenstan". A raid cell has room for the first half only; every
-- other frame says the whole name.
function Live:Name() return raw(UnitName, self.unit) end
function Live:FullName()
	local full = raw(GetUnitName, self.unit, false)
	if full ~= nil then
		return full
	end
	return raw(UnitName, self.unit)
end
function Live:Class()
	local _, token = raw(UnitClass, self.unit)
	return (not secret(token)) and token or nil
end
function Live:IsPlayer() return plain(UnitIsPlayer, self.unit) and true or false end
function Live:Level() return plain(UnitLevel, self.unit) end
function Live:Classification() return plain(UnitClassification, self.unit) end
function Live:Tapped() return plain(UnitIsTapDenied, self.unit) and true or false end
function Live:Charmed()
	-- secret for an enemy in a fight; a player in your group is plain
	return plain(UnitIsCharmed, self.unit) and plain(UnitIsPlayer, self.unit) and true or false
end
function Live:Reaction()
	local r = plain(UnitReaction, self.unit, "player")
	if type(r) ~= "number" then
		return "neutral"
	end
	return r <= 3 and "hostile" or (r == 4 and "neutral" or "friendly")
end
function Live:Dead() return plain(UnitIsDeadOrGhost, self.unit) and true or false end
function Live:Ghost() return plain(UnitIsGhost, self.unit) and true or false end
function Live:Offline()
	return plain(UnitIsPlayer, self.unit) and plain(UnitIsConnected, self.unit) == false or false
end
function Live:Gone() return self:Dead() or self:Offline() end
-- the bars' ceiling and value, as the client gives them
function Live:HealthMax() return raw(UnitHealthMax, self.unit) end
function Live:Health() return raw(UnitHealth, self.unit) end
function Live:Heals() return raw(UnitGetIncomingHeals, self.unit) end
-- THE SHIELD, TWO WAYS (2026-10-04, after Dander's Frames: "Dander's
-- default"). The client's calculator clamps a shield inside the client, where
-- secret arithmetic is allowed, and says whether it had to. Clamped to the
-- health missing, it is the shield that fits after the health, and the "had
-- to" says it did not fit. Clamped to the unit's most health, it is the whole
-- shield, as far as the bar can show it. One calculator for each, made once.
-- Its own default is the health missing: drawn from the bar's end, a shield
-- at full health came out as nothing ("Not seeing the shield at all").
local function absorbs(unit, mode)
	F.calcs = F.calcs or {}
	local c = F.calcs[mode]
	if c == nil then
		local ok, made = pcall(CreateUnitHealPredictionCalculator)
		c = ok and type(made) == "table" and made or false
		if c and c.SetDamageAbsorbClampMode then
			pcall(c.SetDamageAbsorbClampMode, c, mode)
		end
		F.calcs[mode] = c
	end
	if not c or not c.GetDamageAbsorbs or not pcall(UnitGetDetailedHealPrediction, unit, nil, c) then
		return nil
	end
	return pass(pcall(c.GetDamageAbsorbs, c))
end
-- what fits after the health, the whole shield, and whether it was too big
-- to fit; with no calculator, the plain total and no word on fitting
function Live:Shields()
	local modes = Enum and Enum.UnitDamageAbsorbClampMode
	if modes and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
		local fit, tooBig = absorbs(self.unit, modes.MissingHealth)
		local whole = absorbs(self.unit, modes.MaximumHealth)
		if whole ~= nil then
			return fit, whole, tooBig
		end
	end
	return nil, raw(UnitGetTotalAbsorbs, self.unit), nil
end
function Live:PowerType()
	local _, token = raw(UnitPowerType, self.unit)
	return (not secret(token)) and token or nil
end
function Live:PowerMax() return raw(UnitPowerMax, self.unit) end
function Live:Power() return raw(UnitPower, self.unit) end
function Live:PercentText()
	if not (UnitHealthPercent and SCALE100) then
		return nil
	end
	local ok, pct = pcall(UnitHealthPercent, self.unit, true, SCALE100)
	if not ok or pct == nil then
		return nil
	end
	local okF, text = pcall(string.format, "%d%%", pct)
	return okF and text or nil
end
-- "1.1K": the client abbreviates a secret into a secret string, which is set
function Live:HealthText()
	local ok, text = pcall(function() return AbbreviateNumbers(UnitHealth(self.unit)) end)
	return ok and text or nil
end
function Live:PowerText()
	local ok, text = pcall(function() return AbbreviateNumbers(UnitPower(self.unit)) end)
	return ok and text or nil
end
-- IN REACH (Josh 2026-09-23: "the out of range fader is not working, at
-- least on targets"). It was only ever asked of a group: UnitInRange answers
-- for your party and raid (in secret, onto an alpha) and for nobody else, so
-- the target, the focus and the bosses were never faded at all.
-- ONE DISTANCE FOR EVERYONE ELSE (Josh 2026-09-29: "Can we just test a 30
-- yard range?"). They are faded past the client's follow distance, 28 yards,
-- whatever your class. It asked a spell of each class before - Throw and
-- Charge for a warrior - and those refuse anything within 8 yards, so a
-- warrior's target faded while she hit it; and the answer can be a secret,
-- which only the client may read, so no two could be weighed together. The
-- one answer goes to the alpha as it came.
-- HOW FAR A FADED FRAME FADES (Josh 2026-09-23: "hard to tell if it is
-- faded"): a cell out of range to a quarter, a single frame to a third
F.FAR_ALPHA = 0.35
F.GROUP_FAR = 0.25

-- the unit frames' own settings, read here as well as by UnitFrames.lua (this
-- file loads first)
-- FIXED, NOT ASKED (the settings canvas, Josh 2026-10-04: "This addon is
-- supposed to be an opinionated solution, not fully customizable"): frames
-- out of range fade strongly, bars slide, the target's buffs show, the
-- health text is each frame's default (F.HEALTH_DEFAULT), and every heal and
-- damage over time has its lane, in the class's order, blinking as it runs
-- out. A saved answer to any of these is not read.
F.FIXED = { fade = "strong", animate = true, targetBuffs = true }
F.UNASKED = { health = true, timerOrder = true, timersOff = true, timerBlinkHot = true, timerBlinkDot = true }

function F.Opt(name, fallback)
	if F.FIXED[name] ~= nil then
		return F.FIXED[name]
	elseif F.UNASKED[name] then
		return fallback
	end
	local s = BT.settings and BT.settings.unitframes
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end

-- HOW FAR, AS A CHOICE (Josh 2026-09-24): light, medium or strong - a group
-- cell and a single frame each, strong being what it always was
F.FADES = { light = { 0.60, 0.70 }, medium = { 0.40, 0.50 }, strong = { F.GROUP_FAR, F.FAR_ALPHA } }
function F.Far(group)
	local f = F.FADES[F.Opt("fade", "strong")] or F.FADES.strong
	return group and f[1] or f[2]
end

-- WHAT THE HEALTH SAYS, A FRAME AT A TIME (Josh 2026-09-24): none, its share,
-- the number, or both - for the party, the raid (main tanks with it), the
-- target, the focus and the bosses. What each said before is its default.
F.HEALTH_KIND = { party = "party", raid = "raid", tank = "raid", target = "target", focus = "focus", boss = "boss" }
F.HEALTH_DEFAULT = { party = "none", raid = "none", target = "both", focus = "percent", boss = "percent" }
function F.HealthMode(kind, k)
	local key = F.HEALTH_KIND[kind or ""]
	if not key then
		return (k and k.text == "percent") and "percent" or "none"
	end
	local chosen = F.Opt("health", nil)
	return (type(chosen) == "table" and chosen[key]) or F.HEALTH_DEFAULT[key]
end
function Live:InRange()
	local unit = self.unit
	if unit == "player" then
		return true
	end
	if UnitInParty and (plain(UnitInParty, unit) or plain(UnitInRaid, unit)) then
		return (raw(UnitInRange, unit))
	end
	-- within 28 yards; no answer at all is in reach, not faded.
	-- OUT OF A FIGHT ONLY (2026-10-04: "Interface action failed because of
	-- an AddOn"). In one the client refuses the question from an addon; the
	-- saved record caught it on a target frame shown mid-fight. Refused, it
	-- answered nothing anyway, so a fight changes nothing that showed.
	if InCombatLockdown and InCombatLockdown() then
		return true
	end
	local near = raw(CheckInteractDistance, unit, 4)
	if not secret(near) and near == nil then
		return true
	end
	return near
end
function Live:IsTarget() return (raw(UnitIsUnit, self.unit, "target")) end
-- WHOSE THREAT (Josh 2026-09-23, "not seeing an aggro indicator at all"). On a
-- friend - you, your party - it is theirs: is something attacking them. On an
-- enemy the client keeps no status of its own, so asking it about the mob
-- came back nil every time; what an enemy's frame should say is whether it
-- is on YOU, which is your threat on it (the probe: 3 in a fight).
function Live:CanAttack() return plain(UnitCanAttack, "player", self.unit) and true or false end
function Live:Threat()
	if self:CanAttack() then
		return plain(UnitThreatSituation, "player", self.unit)
	end
	return plain(UnitThreatSituation, self.unit)
end
-- THE MARK AS THE CLIENT GIVES IT (Josh 2026-09-27: "Target markers don't
-- seem to be showing on these unit frames"). Handed back as it came - a
-- secret included - because a secret mark can still be drawn by the client
-- (F.DrawMarker), and plain() read one as no mark at all.
function Live:Marker()
	if type(GetRaidTargetIndex) ~= "function" then
		return nil
	end
	local ok, v = pcall(GetRaidTargetIndex, self.unit)
	return ok and v or nil
end
function Live:Leader() return plain(UnitIsGroupLeader, self.unit) and true or false end
-- A RESURRECTION ON ITS WAY, A SUMMON WAITING (Josh 2026-09-23): plain answers,
-- both. A summon is 0 none, 1 waiting, 2 taken, 3 turned down.
function Live:Res() return plain(UnitHasIncomingResurrection, self.unit) and true or false end
function Live:Summon()
	local fn = C_IncomingSummon and C_IncomingSummon.IncomingSummonStatus
	local s = plain(fn, self.unit)
	return type(s) == "number" and s or 0
end
-- the group's master looter, worked out once for the group (UnitFrames.lua)
function Live:MasterLooter() return F.masterLooter ~= nil and self.unit == F.masterLooter end
-- A HUNTER'S PET, AND HOW IT FEELS (Josh 2026-09-23): 1 unhappy, 2 content,
-- 3 happy - the Classic question a hunter asks of the pet frame
function Live:Happiness()
	if self.unit ~= "pet" then
		return nil
	end
	local h = plain(GetPetHappiness)
	return type(h) == "number" and h or nil
end
-- YOUR THREAT ON AN ENEMY, as a share of what pulls it (the probe: plain for
-- your target in a fight). Nothing out of a fight or on a friend.
function Live:ThreatPercent()
	if not (plain(UnitAffectingCombat, "player") and self:CanAttack()) then
		return nil
	end
	local ok, _, status, scaled = pcall(UnitDetailedThreatSituation, "player", self.unit)
	if not ok or scaled == nil then
		return nil
	end
	if secret(scaled) then
		return scaled, nil
	end
	if type(scaled) ~= "number" then
		return nil
	end
	return math.floor(scaled + 0.5), (not secret(status)) and status or nil
end
function Live:Ready() return plain(GetReadyCheckStatus, self.unit) end
function Live:Cast()
	local unit = self.unit
	local dur = raw(UnitCastingDuration, unit)
	local channel = false
	if dur == nil then
		dur = raw(UnitChannelDuration, unit)
		channel = dur ~= nil
	end
	if dur == nil then
		return nil
	end
	-- one call each: the name first, its picture third, whether it can be
	-- kicked seventh (a channel) or eighth (a cast). Only a true-or-false is
	-- that answer: on an older layout the same place holds the spell's number.
	-- THE PICTURE TOO (Josh 2026-10-04: "The target unit frame and nameplates
	-- don't show the name of the spell or icon on the cast bar").
	local name, icon, shield, spell
	if channel then
		local n, _, t, _, _, _, noKick, id = raw(UnitChannelInfo, unit)
		name, icon, shield, spell = n, t, noKick, id
	else
		local n, _, t, _, _, _, _, noKick, id = raw(UnitCastingInfo, unit)
		name, icon, shield, spell = n, t, noKick, id
	end
	if not secret(shield) and type(shield) ~= "boolean" then
		shield = nil
	end
	-- A CAST TO STOP (Josh 2026-10-04: "highlights high priority casts that
	-- should be interrupted ... If it is a list, probably forget it"). Not a
	-- list: the game's own word, C_Spell.IsSpellImportant - "a spell that's
	-- lethal if not interrupted" - which takes the spell's hidden number and
	-- gives a true-or-false that may be hidden too, for the bar to show as is
	local important
	if C_Spell and C_Spell.IsSpellImportant and (secret(spell) or spell ~= nil) then
		important = raw(C_Spell.IsSpellImportant, spell)
	end
	F.NoteCast(unit, name, icon, shield, important)
	return { duration = dur, name = name, icon = icon, shielded = shield, important = important, channel = channel }
end

-- WHAT THE GAME GAVE FOR A CAST, ONCE A KIND OF UNIT (the same day: the
-- nameplate showed "Fireball" while the target frame's bar, the same enemy's
-- cast, showed no name). Into the saved file the first time a target, a
-- nameplate, a focus, a boss or a party member casts in a session, so the
-- next reload says which answers come back empty or hidden.
F.castNotes = {}
local function describe(v)
	if secret(v) then
		return "SECRET(" .. type(v) .. ")"
	end
	if type(v) == "string" then
		return ("%q"):format(v:sub(1, 30))
	end
	return tostring(v)
end
function F.NoteCast(unit, name, icon, shield, important)
	local kind = type(unit) == "string" and unit:gsub("%d+$", "") or "?"
	if F.castNotes[kind] then
		return
	end
	F.castNotes[kind] = ("%s (%s): name=%s icon=%s noKick=%s important=%s"):format(kind, tostring(unit),
		describe(name), describe(icon), describe(shield), describe(important))
	if type(BeebModDB) == "table" then
		local lines = {}
		for _, line in pairs(F.castNotes) do
			lines[#lines + 1] = line
		end
		table.sort(lines)
		BeebModDB.castDump = { at = BT.Util.Now(), lines = lines }
	end
end
BT.Record("castDump", function()
	return next(F.castNotes) and 1 or nil
end)
function Live:Combo()
	local display = BT.GetModule and BT.GetModule("resourcedisplay")
	if display and display.Combo then
		local cur, max, show = display.Combo()
		return cur, max, show
	end
	return 0, 0, false
end

-- A preview's numbers: plain, from a table, so Made-up people draws what a
-- raid looks like while you stand alone in Darkshore.
local Fake = {}
Fake.__index = function(t, k)
	return Fake[k]
end

function F.Fake(d)
	return setmetatable({ d = d, unit = d.unit or "fake" }, Fake)
end

function Fake:Exists() return true end
function Fake:Name() return (self.d.name or ""):match("^(%S+)") end
function Fake:FullName() return self.d.name end
function Fake:Class() return self.d.class end
function Fake:IsPlayer() return self.d.class ~= nil end
function Fake:Level() return self.d.level end
function Fake:Classification() return self.d.classification end
function Fake:Tapped() return false end
function Fake:Charmed() return self.d.charmed and true or false end
function Fake:Reaction() return self.d.reaction or "friendly" end
function Fake:Dead() return self.d.dead and true or false end
function Fake:Ghost() return false end
function Fake:Offline() return self.d.offline and true or false end
function Fake:Gone() return self:Dead() or self:Offline() end
function Fake:HealthMax() return self.d.max or 100 end
function Fake:Health() return self:Gone() and 0 or (self.d.max or 100) * (self.d.hp or 100) / 100 end
function Fake:Heals() return (self.d.max or 100) * (self.d.heal or 0) / 100 end
function Fake:Shields()
	local most = self.d.max or 100
	local whole = most * (self.d.shield or 0) / 100
	local room = math.max(0, most - self:Health() - self:Heals())
	return math.min(whole, room), math.min(whole, most), whole > room
end
function Fake:PowerType() return self.d.power or (self.d.class == "WARRIOR" and "RAGE") or (self.d.class == "ROGUE" and "ENERGY") or "MANA" end
function Fake:PowerMax() return 100 end
function Fake:Power() return self.d.mana or 70 end
function Fake:PercentText() return ("%d%%"):format(self.d.hp or 100) end
local function abbreviate(n)
	n = math.floor((n or 0) + 0.5)
	if n >= 10000 then
		return ("%dK"):format(math.floor(n / 1000 + 0.5))
	elseif n >= 1000 then
		return (("%.1fK"):format(n / 1000):gsub("%.0K$", "K"))
	end
	return tostring(n)
end
function Fake:HealthText() return abbreviate(self:Health()) end
function Fake:PowerText() return abbreviate(self:Power()) end
function Fake:InRange() return self.d.range ~= false end
function Fake:IsTarget() return self.d.target and true or false end
function Fake:Threat() return self.d.aggro end
function Fake:CanAttack() return self.d.reaction == "hostile" end
function Fake:Marker() return self.d.marker end
function Fake:Leader() return self.d.leader and true or false end
function Fake:Ready() return self.d.ready end
function Fake:Res() return self.d.rez and true or false end
function Fake:Summon() return self.d.summon or 0 end
function Fake:MasterLooter() return self.d.ml and true or false end
function Fake:Happiness() return self.d.happy end
function Fake:ThreatPercent() return self.d.threat, self.d.threatStatus end
function Fake:Cast()
	if not self.d.cast then
		return nil
	end
	return { value = self.d.cast.p, name = self.d.cast.name, icon = self.d.cast.icon, shielded = self.d.cast.shielded,
		important = self.d.cast.important }
end
function Fake:Combo() return self.d.combo or 0, 5, self.d.combo ~= nil end

-- ---------------------------------------------------------------------------
-- Building one
-- ---------------------------------------------------------------------------

-- A line of type: Fira Code with a hard one-pixel shadow, which is what lets
-- white read on a priest's bar as well as a warlock's. `face` is "name" or
-- "num". If the client will not load the file, the game's face with its
-- outline, as before.
local function text(parent, size, justify, face)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	-- `size` in the game's face; the face in use moves it (Fonts.Size), and a
	-- new choice reaches this string without a reload
	Fonts.Set(fs, face == "name" and "name" or "text", size, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	fs:SetTextColor(1, 1, 1)
	return fs
end

-- how far past the end of the health bar a heal may show, as a share of
-- the bar's width, on the frames that allow it (`overheal` below)
F.OVERHEAL = 0.08
-- A SHIELD IS A HONEYCOMB (Josh 2026-10-04: "C: honeycomb"). It was a white
-- wash, then the game's white hatching at half strength ("Shields are very
-- hard to see"), then Dander's Frames' cyan stripes, which read but were
-- somebody else's ("looks more like BeebMod instead of a Dander's Frames
-- copy"). A lattice drawn as the dispel patterns are (scripts/make-
-- patterns.py), its white tinted this ice blue and its dark lines left dark,
-- in the toolkit's one-pixel rim: a neutral colour, since the theme's accent
-- is a class colour and would vanish on that class's own bar.
F.SHIELD_PATTERN = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\shield"
F.SHIELD_COLOUR = { 0.72, 0.90, 1.00, 1 }
-- A FINER ONE ON A SHORT BAR (Josh 2026-10-04: "scale down the textures of
-- the raid unit frames a bit? Doesn't read quite as well as player/target
-- frames"). On a raid cell's bar, forty tall, a shield showed two or three
-- hexagons. Any bar shorter than this wears the finer lattice - the raid,
-- the tanks, the focus, the bosses, the pets and the plates - and the target
-- and the party, fifty-four tall, keep the larger.
F.SHIELD_FINE = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\shield-fine"
F.SHIELD_FINE_BELOW = 45
F.SHIELD_RIM = { 0.72, 0.90, 1.00, 0.9 }
F.SHIELD_EDGE = { 0.02, 0.03, 0.03, 0.9 }

local function bar(parent, level)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetStatusBarTexture(BLANK)
	b:SetMinMaxValues(0, 1)
	b:SetValue(0)
	if level and b.SetFrameLevel then
		b:SetFrameLevel((parent:GetFrameLevel() or 1) + level)
	end
	return b
end

-- A shield bar's honeycomb. The bar's own fill stays unseen; a frame laid
-- on it cuts to it, and the lattice inside covers the whole bar and holds
-- still, so a shield wearing away uncovers less of it rather than sliding it
-- along. Round it the toolkit's one-pixel rim: light along the top and the
-- bottom, and at the left end - where the shield meets the health, or how
-- far it reaches back over it - a dark line with a light one inside.
-- which lattice a kind of frame wears, by how tall its health bar is
function F.ShieldPattern(k)
	local power = k and k.power or 0
	local tall = (k and k.h or 0) - (power > 0 and power + 1 or 0)
	return tall < F.SHIELD_FINE_BELOW and F.SHIELD_FINE or F.SHIELD_PATTERN
end

function F.ShieldLattice(shield, pattern)
	shield:SetStatusBarColor(1, 1, 1, 0)
	local cut = CreateFrame("Frame", nil, shield)
	cut:SetFrameLevel((shield:GetFrameLevel() or 1) + 1)
	cut:SetAllPoints(shield:GetStatusBarTexture())
	if cut.SetClipsChildren then
		cut:SetClipsChildren(true)
	end
	local c = F.SHIELD_COLOUR
	cut.lattice = cut:CreateTexture(nil, "ARTWORK")
	cut.lattice:SetAllPoints(shield)
	cut.lattice:SetTexture(pattern or F.SHIELD_PATTERN, "REPEAT", "REPEAT")
	pcall(cut.lattice.SetHorizTile, cut.lattice, true)
	pcall(cut.lattice.SetVertTile, cut.lattice, true)
	cut.lattice:SetVertexColor(c[1], c[2], c[3], c[4])
	local px = BT.Pill.Px(shield, 1) or 1
	local function line(colour, a, b, x, size, wide)
		local t = cut:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
		t:SetPoint(a, cut, a, x, 0)
		t:SetPoint(b, cut, b, x, 0)
		if wide then
			t:SetHeight(size)
		else
			t:SetWidth(size)
		end
		return t
	end
	cut.top = line(F.SHIELD_RIM, "TOPLEFT", "TOPRIGHT", 0, px, true)
	cut.bottom = line(F.SHIELD_RIM, "BOTTOMLEFT", "BOTTOMRIGHT", 0, px, true)
	cut.edge = line(F.SHIELD_EDGE, "TOPLEFT", "BOTTOMLEFT", 0, px)
	cut.inner = line(F.SHIELD_RIM, "TOPLEFT", "BOTTOMLEFT", px, px)
	return cut
end

-- What each kind of frame wears.
--
-- TALLER AND NARROWER (Josh 2026-09-23, first look in game). The first cut
-- was 240 by 34 for the player: a long thin strip with a hairline of energy
-- under it, more ruler than frame. A frame you glance at in a fight wants
-- height - a health bar you can hit with your eye and type that fills it -
-- and it does not need the width once there is no portrait to balance.
--
-- A GROUP CELL, SCALED UP (Josh 2026-09-23, third look). Even at 200 by 44 the
-- player and target read as strips beside the party cells under them. They
-- are cells now - narrow and tall, the name at the top and the numbers at the
-- bottom - and the target is the one that says more: its health as a number
-- as well as a share, and its mana, rage or energy on a power bar tall enough
-- to carry the figure. Your own numbers are on the resource display already.
F.KINDS = {
	-- WIDER THAN A CELL (Josh 2026-09-24: "let's make the target bar wider
	-- since we're showing a lot more info in it"): its level, a name like
	-- "Defias Rogue Wizard" and your threat on one line were cut to "Defias
	-- Rogue..." at a party cell's 160. The column beside it (its target, the
	-- focus) hangs off its right edge and moves with it.
	-- A LITTLE SHORTER, AND ITS HEALTH AS TALL AS YOURS (Josh 2026-10-03: "the
	-- target [frame] is just a bit too long, and the health bar should be
	-- taller to match the player's"), AND ITS POWER BAR TALL (the same day:
	-- "The energy/power/mana/cast bar on the target frame should be taller"):
	-- 200 wide, the power bar twelve tall with its figure on it, and the frame
	-- as much taller than your cell as its power bar is, so the two health
	-- bars are one height. The cast covers the power bar, the same height.
	target = { w = 200, h = 67, power = 12, name = 12, text = "percent", stack = true, hpValue = true, castOverPower = true,
		threat = true, overheal = true, powerValue = true, cast = true, combo = true },
	focus = { w = 110, h = 30, power = 0, name = 11, text = "percent", cast = true, castGap = 10 },
	tot = { w = 110, h = 22, power = 0, name = 10, text = "none" },
	pet = { w = 110, h = 22, power = 0, name = 10, text = "none" },
	boss = { w = 170, h = 36, power = 0, name = 11, text = "percent", cast = true, marker = true, castGap = 10 },
	-- NO FIGURE ON A GROUP CELL (Josh 2026-09-23): the missing health was
	-- written in the corner, and the bar already says it - at a glance, which
	-- is how a raid is read. The corner is left for Dead, Offline, Charmed.
	-- THE PLAYER FRAME'S SIZE (Josh 2026-09-23): the party column is your
	-- frame now, so a cell is what the player frame was - 160 by 60, the name
	-- at the top in its size - laid out as a stacked cell
	-- THE LEVEL IN FRONT OF THE NAME (Josh 2026-09-24: "can you add player
	-- level to the frame?"), as the target wears it; a raid cell is too narrow
	party = { w = 160, h = 60, power = 5, manaOnly = true, name = 12, text = "none", group = true, stack = true,
		overheal = true, level = true },
	raid = { w = 70, h = 40, power = 0, name = 10, text = "none", group = true, short = true },
	-- a main tank: a smaller cell than a party member's, with its target beside
	-- it, in a column of their own in a raid (Josh 2026-09-23)
	tank = { w = 140, h = 40, power = 0, name = 11, text = "none", group = true },
	-- a party member's pet under their cell, and whoever they are targeting
	-- beside it: a bar and a name, no more (Josh 2026-09-23)
	-- half a member's width, under its right-hand end (Josh 2026-09-23): a
	-- pet is the smaller thing, and hangs off its owner rather than matching it
	-- ITS MANA OR FOCUS UNDER ITS HEALTH (Josh 2026-10-03: "Can we add a
	-- resource bar to the pet unit frames?"), whatever kind it is: an imp's
	-- mana and a boar's focus both say when it can act. Taken from the
	-- health, not added, so the party below keeps its spacing.
	gpet = { w = 80, h = 16, power = 3, name = 9, text = "none", mini = true },
	gtarget = { w = 96, h = 22, power = 0, name = 9, text = "none", mini = true },
	-- AN ENEMY'S NAMEPLATE (Josh 2026-10-03, design D on the nameplates
	-- canvas: "I like the name, level, and [health] % of option C, but
	-- everything else option A"). The level in a tab of its own at the left,
	-- the name and the health's share inside the bar; gold or silver brackets
	-- at the ends for an elite or a rare, in place of the ornate border; the
	-- cast bar under it; your damage over time in short lanes above
	-- (Timers.lua). Modules/Nameplates/Nameplates.lua puts one on each plate.
	-- SMALLER, AND TIGHTER INSIDE (Josh 2026-10-03, first look in game: "overall
	-- width smaller, smaller text, tighter padding so more of the name shows"):
	-- 136 by 16 cut "Ravaged Corpse" to "Ravaged Cor...", with six units of
	-- padding at each end of the words and between them
	-- ITS LANES AS WIDE AS IT (Josh 2026-10-03: "make them the same width as
	-- the bar"), now each has its spell's picture at its left
	plate = { w = 120, h = 14, power = 0, name = 9, text = "percent", mini = true, plate = true,
		levelTab = 14, textInset = 3, textGap = 4, brackets = true, cast = true, castGap = 5, castH = 10,
		laneW = 120 },
}

-- whether you are resting, for the Zzz on your own cell
F.REST_ICON = "Interface\\CharacterFrame\\UI-StateIcon"
function F.Resting()
	if type(IsResting) ~= "function" then
		return false
	end
	local ok, resting = pcall(IsResting)
	return ok and resting == true
end

-- Everything a button wears, made once. `secure` for a real unit frame; a
-- preview is a plain Button that clicks nothing.
function F.Build(parent, kind, name, secure)
	local k = F.KINDS[kind] or F.KINDS.party
	local b
	if secure then
		b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
	else
		b = CreateFrame("Button", name, parent)
	end
	F.Dress(b, kind)
	return b
end

-- the pieces, on any button - also the ones a group header makes for us
function F.Dress(b, kind)
	if b.bmDressed then
		return b
	end
	local k = F.KINDS[kind] or F.KINDS.party
	b.bmDressed, b.bmKind, b.bmSpec = true, kind, k
	if not InCombatLockdown or not InCombatLockdown() then
		b:SetSize(k.w, k.h)
	end
	-- NO RIM (Josh 2026-09-23, second look in game). The theme's border went
	-- round every frame, and aggro, your target's outline and (to come) a
	-- dispel border all need to BE the frame's edge: a rim in the theme's
	-- colour beside a red aggro line reads as two edges arguing.
	-- NO DARK EDGE EITHER (Josh 2026-09-28: "all of our unit frames acquired
	-- a black border. Can you remove it?"). The fill showed two units deep
	-- round the bars; the bars reach the frame's edge now, and the fill shows
	-- only in the line between health and power.
	BT.Pill.Panel(b, W.FILL, NO_EDGE)

	local inset = 0
	local powerH = k.power or 0
	b.health = bar(b, 1)
	-- after the level's tab, on a frame that has one
	b.health:SetPoint("TOPLEFT", inset + (k.levelTab or 0), -inset)
	b.health:SetPoint("TOPRIGHT", -inset, -inset)
	b.health:SetPoint("BOTTOM", b, "BOTTOM", 0, inset + (powerH > 0 and (powerH + 1) or 0))
	-- the heal hangs off the end of the health and the shield lies over it,
	-- both inside it: a heal worth more than the missing health runs into the
	-- clip, not past it
	if b.health.SetClipsChildren then
		b.health:SetClipsChildren(true)
	end
	local fill = b.health:GetStatusBarTexture()
	-- PAST THE END, A LITTLE (Josh 2026-09-24: "party, player, and target
	-- frames should extend visual heal beyond the health bar. But it should
	-- be limited"). On the frames you heal from, the heal has a clip of its
	-- own: the health bar and F.OVERHEAL of its width past the right-hand
	-- end, so a heal bigger than the health missing shows as a ghost running
	-- off the frame, and stops. The amount is secret; the client's clip does
	-- the sum, not us.
	local healParent = b.health
	if k.overheal then
		local over = math.floor((k.w - 2 * inset) * F.OVERHEAL + 0.5)
		b.healRoom = CreateFrame("Frame", nil, b)
		b.healRoom:SetPoint("TOPLEFT", b.health, "TOPLEFT", 0, 0)
		b.healRoom:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", over, 0)
		if b.healRoom.SetClipsChildren then
			b.healRoom:SetClipsChildren(true)
		end
		b.healRoom:SetFrameLevel((b.health:GetFrameLevel() or 1) + 1)
		healParent = b.healRoom
	end
	b.heals = bar(healParent, 1)
	b.heals:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
	b.heals:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
	-- THE SHIELD (F.SHIELD_PATTERN, above), AS DANDER'S FRAMES DRAWS IT (Josh
	-- 2026-10-04: "Dander's default"). While it fits in the health missing,
	-- it goes straight after the heal, so health, heal and shield read as one
	-- length. When it is too big to fit, that one hides and the whole shield
	-- shows from the bar's right-hand end back over the health, as long
	-- against the bar as the shield is against the unit's most health. Which
	-- one shows is the client's word (Live:Shields), never a sum of ours.
	-- Each is a bar with its own fill unseen and the honeycomb laid over the
	-- fill (F.ShieldLattice). On the way: a light blue wash after the heal, then white
	-- hatching from the bar's end ("The shield should grow over the health
	-- bar from the right side"), hard to see, and only ever the too-big case
	-- in Dander's Frames' pictures.
	local healEnd = b.heals:GetStatusBarTexture()
	-- (a level under the words: the honeycomb sits a level above its bar)
	b.shield = bar(b.health, 2)
	b.shield:SetPoint("TOPLEFT", healEnd, "TOPRIGHT", 0, 0)
	b.shield:SetPoint("BOTTOMLEFT", healEnd, "BOTTOMRIGHT", 0, 0)
	b.shieldOver = bar(b.health, 2)
	b.shieldOver:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", 0, 0)
	b.shieldOver:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", 0, 0)
	if b.shieldOver.SetReverseFill then
		pcall(b.shieldOver.SetReverseFill, b.shieldOver, true)
	end
	b.shieldOver.bmBackwards = true
	b.shieldLattice = F.ShieldLattice(b.shield, F.ShieldPattern(k))
	b.shieldOverLattice = F.ShieldLattice(b.shieldOver, F.ShieldPattern(k))

	if powerH > 0 then
		b.power = bar(b, 1)
		b.power:SetPoint("BOTTOMLEFT", inset, inset)
		b.power:SetPoint("BOTTOMRIGHT", -inset, inset)
		b.power:SetHeight(powerH)
	end

	-- the words sit over the bars, on a frame of their own so no bar covers them
	b.over = CreateFrame("Frame", nil, b)
	b.over:SetAllPoints()
	b.over:SetFrameLevel((b:GetFrameLevel() or 1) + 5)
	b.name = text(b.over, k.name or 11, "LEFT", "name")
	b.value = text(b.over, k.group and 10 or (k.stack and 11) or (k.name or 11), "RIGHT", "num")
	if k.stack then
		b.name:SetPoint("TOPLEFT", b.health, "TOPLEFT", 5, -5)
		b.name:SetPoint("RIGHT", b.health, "RIGHT", -5, 0)
		b.value:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -5, 5)
		-- the target's health as a number, opposite its share
		if k.hpValue then
			b.hpText = text(b.over, 11, "LEFT", "num")
			b.hpText:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 5, 5)
		end
		-- and its mana, rage or energy as a figure on the bar
		if k.powerValue and b.power then
			b.power.text = text(b.over, 10, "RIGHT", "num")
			b.power.text:SetPoint("RIGHT", b.power, "RIGHT", -4, 0)
		end
	elseif k.group then
		b.name:SetPoint("TOPLEFT", b.health, "TOPLEFT", 3, -3)
		b.name:SetPoint("RIGHT", b.health, "RIGHT", -3, 0)
		b.value:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -3, 3)
	else
		local inset, gap = k.textInset or 6, k.textGap or 6
		b.name:SetPoint("LEFT", b.health, "LEFT", inset, 0)
		b.name:SetPoint("RIGHT", b.value, "LEFT", -gap, 0)
		b.value:SetPoint("RIGHT", b.health, "RIGHT", -inset, 0)
	end
	b.status = text(b.over, k.stack and 11 or (k.plate and k.name) or 10, "RIGHT", "num")
	b.status:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", k.stack and -5 or -3, k.stack and 5 or 3)
	if not (k.group or k.stack) then
		b.status:ClearAllPoints()
		b.status:SetPoint("RIGHT", b.health, "RIGHT", -(k.textInset or 6), 0)
	end
	b.status:SetTextColor(0.80, 0.84, 0.82)

	-- the level in its tab, in the colour of how hard the enemy is
	if k.levelTab then
		b.levelText = text(b.over, k.name or 10, "CENTER", "name")
		b.levelText:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		b.levelText:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", k.levelTab, 0)
	end

	-- AN ELITE OR A RARE IN BRACKETS: an upright and two feet turned in at
	-- each end, gold or silver as the ornate border would be (F.Paint)
	if k.brackets then
		b.brackets = {}
		for _, side in ipairs({ "LEFT", "RIGHT" }) do
			local br = CreateFrame("Frame", nil, b)
			br:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
			-- clear of the threat ring and the target's outline
			br:SetSize(6, k.h + 14)
			if side == "LEFT" then
				br:SetPoint("RIGHT", b, "LEFT", -6, 0)
			else
				br:SetPoint("LEFT", b, "RIGHT", 6, 0)
			end
			local up = br:CreateTexture(nil, "OVERLAY")
			up:SetPoint("TOP" .. side, br, "TOP" .. side, 0, 0)
			up:SetPoint("BOTTOM" .. side, br, "BOTTOM" .. side, 0, 0)
			up:SetWidth(2)
			local top = br:CreateTexture(nil, "OVERLAY")
			top:SetPoint("TOPLEFT", br, "TOPLEFT", 0, 0)
			top:SetPoint("TOPRIGHT", br, "TOPRIGHT", 0, 0)
			top:SetHeight(2)
			local foot = br:CreateTexture(nil, "OVERLAY")
			foot:SetPoint("BOTTOMLEFT", br, "BOTTOMLEFT", 0, 0)
			foot:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", 0, 0)
			foot:SetHeight(2)
			br.parts = { up, top, foot }
			br:Hide()
			b.brackets[#b.brackets + 1] = br
		end
	end

	-- AGGRO IS THE WHOLE EDGE (Josh 2026-09-23). It was a two-pixel line
	-- across the top, which nobody saw; with the theme's rim gone the edge is
	-- free, and a ring round the frame in the client's own threat colours -
	-- yellow, orange, red - is the one thing on it.
	b.threat = CreateFrame("Frame", nil, b)
	if k.plate then
		-- OUTSIDE A PLATE: inside a bar fourteen tall it would cover the name.
		-- Past the target's outline, which is a pixel off the bar (below).
		b.threat:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
		b.threat:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
	else
		b.threat:SetAllPoints()
	end
	b.threat:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
	b.threat.ring = BT.Pill.Ring(b.threat, "OVERLAY", 2)
	BT.Pill.PlaceRing(b.threat.ring, b.threat, 0, 2, 0)
	b.threat:Hide()

	-- the leader's crown before the name, the raid marker at the right end
	b.leader = b.over:CreateTexture(nil, "OVERLAY")
	b.leader:SetSize(10, 10)
	b.leader:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 4)
	b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	b.leader:Hide()
	-- RESTING (Josh 2026-09-28: "I am not seeing the resting icon. I'm in
	-- Ironforge"): the game's own player frame showed its Zzz, and ours took
	-- that frame's place without it. The same picture, at the top right of
	-- whichever cell is you, while you are resting.
	if not k.mini then
		b.rest = b.over:CreateTexture(nil, "OVERLAY")
		b.rest:SetSize(16, 16)
		b.rest:SetPoint("TOPRIGHT", b, "TOPRIGHT", 4, 8)
		b.rest:SetTexture(F.REST_ICON)
		b.rest:SetTexCoord(0, 0.5, 0, 0.421875)
		b.rest:Hide()
	end
	-- THE MARKER ON TOP OF EVERYTHING (Josh 2026-09-23): it sat under an
	-- elite's border, and the crest's lines ran through the skull. It has a
	-- frame of its own above the border, the outline and the aggro ring, so
	-- it covers the crest rather than being crossed by it.
	b.top = CreateFrame("Frame", nil, b)
	b.top:SetAllPoints()
	b.top:SetFrameLevel((b:GetFrameLevel() or 1) + 9)
	b.marker = b.top:CreateTexture(nil, "OVERLAY")
	b.marker:SetSize(k.group and 12 or 16, k.group and 12 or 16)
	if k.plate then
		-- a plate's at its left, clear of a bracket, where the lanes are not
		b.marker:SetSize(14, 14)
		b.marker:SetPoint("RIGHT", b, "LEFT", k.brackets and -14 or -6, 0)
	else
		b.marker:SetPoint(k.group and "TOPRIGHT" or "CENTER", b.health, k.group and "TOPRIGHT" or "TOP", k.group and -2 or 0, k.group and -2 or 0)
	end
	b.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	b.marker:Hide()
	b.ready = b.over:CreateTexture(nil, "OVERLAY")
	b.ready:SetSize(16, 16)
	b.ready:SetPoint("CENTER", b.health, "CENTER")
	b.ready:Hide()

	-- AN ORNATE BORDER FOR ELITE AND RARE (Josh 2026-09-23): gold for an
	-- elite, silver for a rare, a crest on the elites - the same border the
	-- unit tooltip wears (UI/Ornament.lua). Wholly outside the frame, clear
	-- of the aggro ring inside it.
	if not k.group and not k.mini then
		b.rank = BT.Ornament.Build(b, 6)
	end

	-- the master looter's coins beside the leader's crown
	if k.group then
		b.ml = b.over:CreateTexture(nil, "OVERLAY")
		b.ml:SetSize(10, 10)
		b.ml:SetPoint("TOPLEFT", b, "TOPLEFT", 8, 4)
		b.ml:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
		b.ml:Hide()
	end

	-- a resurrection coming, or a summon: in the middle of the cell, over
	-- everything, where the ready check goes
	if k.group then
		b.call = b.top:CreateTexture(nil, "OVERLAY")
		-- as big as the cell allows: the client's icons have room round them
		local side = math.min(32, math.floor(k.h * 0.65))
		b.call:SetSize(side, side)
		b.call:SetPoint("CENTER", b.health, "CENTER")
		b.call:Hide()
	end

	-- a hunter's pet: a small square at the end of its bar, green, amber, red
	if kind == "gpet" then
		b.happy = b.over:CreateTexture(nil, "OVERLAY")
		b.happy:SetSize(6, 6)
		b.happy:SetPoint("RIGHT", b.health, "RIGHT", -3, 0)
		b.happy:Hide()
	end

	-- your threat on the target, in its top right corner
	if k.threat then
		b.threatText = text(b.over, 10, "RIGHT", "text")
		b.threatText:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -5, -5)
		b.threatText:Hide()
		-- the name stops short of it
		b.name:SetPoint("RIGHT", b.health, "RIGHT", -38, 0)

		-- WHAT YOU WROTE ON THEM (Josh 2026-10-05, the canvas "Ledger from the
		-- right-click menu"): the note's mark and a square per tag, in the
		-- same corner. The dock's target row showed them, and it is gone; a
		-- player has no threat to show there, and an enemy no note.
		b.ledger = CreateFrame("Frame", nil, b.over)
		b.ledger:SetSize(44, 11)
		b.ledger:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -5, -5)
		b.ledger.note = b.ledger:CreateTexture(nil, "OVERLAY")
		b.ledger.note:SetSize(11, 11)
		b.ledger.note:SetTexture("Interface\\AddOns\\BeebMod\\Art\\icons")
		b.ledger.note:SetTexCoord(0, 0.125, 0, 1)
		b.ledger.note:SetVertexColor(0.90, 0.88, 0.80, 1)
		b.ledger.squares = {}
		for i = 1, 3 do
			b.ledger.squares[i] = b.ledger:CreateTexture(nil, "OVERLAY")
			b.ledger.squares[i]:SetSize(7, 7)
		end
		b.ledger:Hide()
	end

	-- your target: a one-pixel outline round the whole frame, in white
	b.outline = CreateFrame("Frame", nil, b)
	-- A PIXEL OFF THE BAR (Josh 2026-10-03: "Maybe just 1px of margin inside
	-- the selected box"): the outline is a pixel thick and two out, so one
	-- pixel shows between it and the bar. On a plate the threat ring goes
	-- outside it.
	b.outline:SetPoint("TOPLEFT", -2, 2)
	b.outline:SetPoint("BOTTOMRIGHT", 2, -2)
	b.outline:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
	b.outline.ring = BT.Pill.Ring(b.outline, "OVERLAY", 1)
	BT.Pill.PlaceRing(b.outline.ring, b.outline, 0, 1, 0)
	BT.Pill.PaintRing(b.outline.ring, { 1, 1, 1, 1 })
	b.outline:Hide()

	if k.cast then
		b.cast = bar(b, 1)
		if k.castOverPower and b.power then
			-- THE TARGET CASTS OVER ITS POWER BAR (Josh 2026-09-23: "why is this
			-- aura icon floating off in space?"). A cast bar under the target
			-- needed room kept for it, and the debuffs under that hung in the
			-- gap whenever nothing was being cast. While the target casts, the
			-- cast covers the power bar, and nothing below the frame moves.
			-- TALLER THAN A THIN POWER BAR (Josh 2026-10-03): from the frame's
			-- foot up, as tall as castH says, short of the health's figures
			b.cast:SetPoint("BOTTOMLEFT", b.power, "BOTTOMLEFT", 0, 0)
			b.cast:SetPoint("BOTTOMRIGHT", b.power, "BOTTOMRIGHT", 0, 0)
			b.cast:SetHeight(k.castH or powerH)
			b.cast:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
		else
			-- below the ornate border's bottom corners, on a frame that can wear one
			local gap = k.castGap or 3
			b.cast:SetHeight(k.castH or 14)
			b.cast:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -gap)
			b.cast:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -gap)
		end
		BT.Pill.Panel(b.cast, W.FILL, NO_EDGE)
		-- smaller on a cast bar thinner than the usual
		local castText = (k.castH and k.castH <= 10 and 8) or (k.castH and k.castH < 14 and 9) or 10
		b.cast.text = text(b.cast, castText, "LEFT", "name")
		b.cast.text:SetPoint("RIGHT", -5, 0)
		-- the spell's picture at the bar's left end, as tall as the bar, and
		-- the name after it; with no picture, the name where the picture was
		local tall = k.castH or (k.castOverPower and powerH > 0 and powerH) or 14
		b.cast.icon = b.cast:CreateTexture(nil, "OVERLAY")
		b.cast.icon:SetSize(tall, tall)
		b.cast.icon:SetPoint("LEFT", b.cast, "LEFT", 0, 0)
		b.cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.cast.icon:Hide()
		F.CastTextAt(b, false)
		-- a cast the game calls important: a red rim a pixel out from the bar
		b.cast.rim = CreateFrame("Frame", nil, b.cast)
		b.cast.rim:SetPoint("TOPLEFT", -1, 1)
		b.cast.rim:SetPoint("BOTTOMRIGHT", 1, -1)
		b.cast.rim.ring = BT.Pill.Ring(b.cast.rim, "OVERLAY", 1)
		BT.Pill.PlaceRing(b.cast.rim.ring, b.cast.rim, 0, 1, 0)
		BT.Pill.PaintRing(b.cast.rim.ring, F.IMPORTANT)
		b.cast.rim:SetAlpha(0)
		b.cast:Hide()
	end
	if k.combo then
		b.combo = CreateFrame("Frame", nil, b)
		b.combo:SetHeight(4)
		b.combo.segs = {}
		for i = 1, 5 do
			local s = bar(b.combo, 0)
			s:SetMinMaxValues(i - 1, i)
			s.bg = s:CreateTexture(nil, "BACKGROUND")
			s.bg:SetAllPoints()
			b.combo.segs[i] = s
		end
		b.combo:Hide()
	end
	-- shown by the client (a new target, a boss arriving): painted as it
	-- appears, rather than on whichever event happens to come next
	b:HookScript("OnShow", function(self)
		if self.bmUnit then
			F.Paint(self, F.Source(self.bmUnit))
		end
	end)
	-- A LIGHT UNDER THE POINTER (Josh 2026-09-23): a faint wash over the
	-- frame while the mouse is on it, so the frame a click or a mouseover heal
	-- will land on is the one that is lit. Added light, on the words' own layer,
	-- so it brightens what is there rather than covering it.
	b.hover = b.over:CreateTexture(nil, "BACKGROUND")
	b.hover:SetAllPoints(b)
	b.hover:SetColorTexture(1, 1, 1, 0.08)
	pcall(b.hover.SetBlendMode, b.hover, "ADD")
	b.hover:Hide()
	b:SetScript("OnEnter", function(self)
		self.hover:Show()
		if self.bmUnit and GameTooltip and GameTooltip_SetDefaultAnchor then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			pcall(GameTooltip.SetUnit, GameTooltip, self.bmUnit)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.hover:Hide()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return b
end

-- the combo row lays itself out under the frame and above the cast bar
local function placeCombo(b)
	if not b.combo then
		return
	end
	-- laid out when the frame's width changes, not on every paint: this ran
	-- for every health change of the target and every tick of your energy
	-- (Josh 2026-09-23, audit)
	local width = BT.Pill.Number(b:GetWidth(), b.bmSpec.w)
	local laidFor = width .. (b.bmBordered and "+" or "")
	if b.comboLaidFor == laidFor then
		return
	end
	b.comboLaidFor = laidFor
	b.combo:ClearAllPoints()
	-- below an elite's border when it wears one, not on its lines; just
	-- under the frame when it does not (F.Room)
	b.combo:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -F.Room(b))
	b.combo:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -F.Room(b))
	local w = BT.Pill.Number(b:GetWidth(), b.bmSpec.w)
	local seg = (w - 4 * 2) / 5
	for i, s in ipairs(b.combo.segs) do
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", b.combo, "TOPLEFT", (i - 1) * (seg + 2), 0)
		s:SetSize(seg, 4)
	end
	if b.cast and not b.bmSpec.castOverPower then
		b.cast:ClearAllPoints()
		b.cast:SetPoint("TOPLEFT", b.combo, "BOTTOMLEFT", 0, -3)
		b.cast:SetPoint("TOPRIGHT", b.combo, "BOTTOMRIGHT", 0, -3)
	end
end

-- ---------------------------------------------------------------------------
-- Painting one
-- ---------------------------------------------------------------------------

-- the client's classifications, as the ornate border: its colour, and
-- whether it wears the crest
-- the ornate border's measures, from where it lives (UI/Ornament.lua)
F.RANK = BT.Ornament.RANK
F.RANK_EDGE, F.RANK_OUTER, F.RANK_INNER = BT.Ornament.EDGE, BT.Ornament.OUTER, BT.Ornament.INNER
F.RANK_ROOM = BT.Ornament.ROOM

-- EASED, NOT JUMPED (Josh 2026-09-24: "a very quick animation to health and
-- resource bars as they get larger or smaller"). The values are secret, so
-- nothing of ours could tween them - but the client can: SetValue takes an
-- interpolation, and the bar slides to its new value on the client's side
-- (the unit probe found GetInterpolatedValue and IsInterpolating on this
-- build's bars). The heal rides on the health's edge, so it follows it. A frame that has just been handed somebody else - a new target,
-- a raid slot re-dealt - is F.Fresh and jumps, rather than sliding from the
-- last one's health; so does one that is not on screen.
local function easing(ease)
	local e = Enum and Enum.StatusBarInterpolation
	return e and (ease and e.ExponentialEaseOut or e.Immediate)
end

-- a jump says so: a bare SetValue part-way through a slide can carry the
-- slide on to the new value instead of stopping it (Josh 2026-09-24: a new
-- target's bars still slid)
local function setBar(bar, value, ease)
	local how = easing(ease)
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return
	end
	bar:SetValue(value)
end
F.SetBar = setBar

-- `b` is somebody new: its bars jump, for every paint in the next moment -
-- a target change is followed by more than one (its own events, the change
-- itself, a show), and only the first used to be told
F.FRESH_FOR = 0.25
function F.Fresh(b)
	if b then
		b.bmFresh = true
		local now = type(GetTime) == "function" and GetTime() or 0
		b.bmJumpUntil = now + F.FRESH_FOR
	end
end
-- what hangs under a frame with no border starts this far under it
F.PLAIN_ROOM = 3

-- how far under a frame its own things start: past the border it is wearing
-- now, or just under a plain one (Josh 2026-09-24)
function F.Room(b)
	return (b and b.bmBordered) and F.RANK_ROOM or F.PLAIN_ROOM
end

-- the icons for a resurrection and a summon: the client's atlases, with its
-- files as the fallback on a build without them
local CALL = {
	rez = { atlas = "Raid-Icon-Rez", file = "Interface\\RaidFrame\\Raid-Icon-Rez" },
	[1] = { atlas = "Raid-Icon-SummonPending", file = "Interface\\RaidFrame\\Raid-Icon-SummonPending" },
	[2] = { atlas = "Raid-Icon-SummonAccepted", file = "Interface\\RaidFrame\\Raid-Icon-SummonAccepted" },
	[3] = { atlas = "Raid-Icon-SummonDeclined", file = "Interface\\RaidFrame\\Raid-Icon-SummonDeclined" },
}
F.CALL = CALL
local HAPPY = { [1] = { 0.86, 0.28, 0.24 }, [2] = { 0.92, 0.76, 0.28 }, [3] = { 0.36, 0.78, 0.40 } }
F.HAPPY = HAPPY

-- an atlas the client does not have is not an error: SetAtlas says false
-- and draws nothing, so the answer is read as well as the call
local function setIcon(tex, icon)
	local ok, took = false, false
	if tex.SetAtlas then
		ok, took = pcall(tex.SetAtlas, tex, icon.atlas)
	end
	if not (ok and took ~= false) then
		tex:SetTexture(icon.file)
	end
	tex.icon = icon
end

local READY = {
	ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

-- a boolean that may be secret, onto something's alpha
local function alphaFrom(region, v, on, off)
	if v == nil then
		region:SetAlpha(off)
	elseif secret(v) then
		if region.SetAlphaFromBoolean then
			pcall(region.SetAlphaFromBoolean, region, v, on, off)
		else
			region:SetAlpha(on)
		end
	else
		region:SetAlpha(v and on or off)
	end
end
F.AlphaFrom = alphaFrom

local function levelText(src)
	local level = src:Level()
	if type(level) ~= "number" then
		return ""
	end
	local cls = src:Classification()
	local tag = level < 0 and "??" or tostring(level)
	if cls == "elite" or cls == "worldboss" or cls == "rareelite" then
		tag = tag .. "+"
	end
	if cls == "rare" or cls == "rareelite" then
		tag = tag .. " R"
	end
	-- how hard, by the shared rule (Core/Util.lua, U.LevelColour): the
	-- client's own answer is the modern game's on this build
	local c = BT.Util.LevelColour(level)
	if c then
		local function hex(v) return math.floor(v * 255 + 0.5) end
		return ("|cff%02x%02x%02x%s|r "):format(hex(c[1]), hex(c[2]), hex(c[3]), tag)
	end
	return tag .. " "
end

-- the level alone, for a tab of its own: "??" for one too far above you to
-- say, and how hard it is in colour (U.LevelColour). The rank is the
-- brackets' to show.
function F.LevelTag(src)
	local level = src:Level()
	if type(level) ~= "number" then
		return ""
	end
	if level < 0 then
		return "|cffff4a3d??|r"
	end
	local c = BT.Util.LevelColour(level)
	if c then
		local function hex(v) return math.floor(v * 255 + 0.5) end
		return ("|cff%02x%02x%02x%d|r"):format(hex(c[1]), hex(c[2]), hex(c[3]), level)
	end
	return tostring(level)
end

-- A NAME IS WRITTEN FROM EMPTY EVERY TIME (Josh 2026-09-23: "after
-- restarting the game, my name is missing", the second time). The names that
-- went blank were the ones written once and never changed - yours, the
-- target's - while the target of target, written four times a second, and the
-- figures, which change all the time, were fine. The client passes over a
-- SetText of the text a string already has; so a first write that drew
-- nothing (a face not loaded yet at the start of a session is the likely
-- reason) was never drawn again. Emptied first, it is drawn on the next paint.
local function writeName(fs, text)
	fs:SetText("")
	fs:SetText(text or "")
end
F.WriteName = writeName

-- whether the bars slide to their new value or jump there: a preview's
-- made-up numbers, a frame just given somebody new, or one not on screen go
-- straight there
local function easeOf(b, src)
	local now = type(GetTime) == "function" and GetTime() or 0
	local ease = F.Opt("animate", true) and not (b.bmFresh or src.d) and now >= (b.bmJumpUntil or 0)
		and b.IsVisible and b:IsVisible() and true or false
	b.bmFresh = nil
	return ease
end

-- health, the heal past its end, and the shield after it or over it
local function paintHealth(b, src, gone, ease)
	local r, g, bl = deepen(F.HealthColour(src))
	b.health:SetStatusBarColor(r, g, bl, 1)
	local max = src:HealthMax()
	if max ~= nil then
		b.health:SetMinMaxValues(0, max)
		b.heals:SetMinMaxValues(0, max)
		b.shield:SetMinMaxValues(0, max)
		b.shieldOver:SetMinMaxValues(0, max)
	end
	-- the frame's own width, not a measurement: before the client has laid
	-- the bar out it measures nothing, and the heal came out zero wide
	local width = BT.Pill.Number(b:GetWidth(), 0)
	-- AS WIDE AS THE HEALTH BAR ITSELF, so a heal or a shield is as long
	-- against it as it is against the health: it ran edge to edge once the
	-- dark border went (2026-09-28), and four were still taken off for it
	width = (width > 0 and width or b.bmSpec.w) - (b.bmSpec.levelTab or 0)
	b.heals:SetWidth(width)
	b.shield:SetWidth(width)
	b.shieldOver:SetWidth(width)
	if gone then
		setBar(b.health, 0, ease)
		b.heals:SetValue(0)
		b.shield:SetValue(0)
		b.shieldOver:SetValue(0)
	else
		setBar(b.health, src:Health() or 0, ease)
		b.heals:SetStatusBarColor(r, g, bl, 0.45)
		b.heals:SetValue(src:Heals() or 0)
		local fit, whole, tooBig = src:Shields()
		b.shield:SetValue(fit or 0)
		b.shieldOver:SetValue(whole or 0)
		-- after the health while it fits, from the bar's end when it does
		-- not; with no word on fitting, from the end
		if tooBig == nil then
			b.shieldLattice:SetAlpha(0)
			b.shieldOverLattice:SetAlpha(1)
		else
			alphaFrom(b.shieldLattice, tooBig, 0, 1)
			alphaFrom(b.shieldOverLattice, tooBig, 1, 0)
		end
	end
end

-- power: under the health, for everyone on a single frame and for mana
-- users only in a party - a warrior's rage bar in a party cell is noise
local function paintPower(b, src, gone, ease)
	if not b.power then
		return
	end
	local pt = src:PowerType()
	-- YOUR OWN, WHATEVER IT IS (Josh 2026-09-24: "is the energy bar
	-- missing from the player frame?"). Your frame sits in the party
	-- column and took its rule; the rule is about other people's cells.
	local show = not gone and (not b.bmSpec.manaOnly or pt == "MANA" or b.bmUnit == "player")
	b.power:SetShown(show and true or false)
	if show then
		local c = POWER[pt or ""] or POWER.MANA
		b.power:SetStatusBarColor(c[1], c[2], c[3], 1)
		local pmax = src:PowerMax()
		if pmax ~= nil then
			b.power:SetMinMaxValues(0, pmax)
		end
		setBar(b.power, src:Power() or 0, ease)
	end
	if b.power.text then
		b.power.text:SetText((not gone and b.power:IsShown()) and (src:PowerText() or "") or "")
		b.power.text:SetShown(not gone)
	end
end

-- the name, with the level in front of it where there is room
local function paintName(b, src, gone)
	local k = b.bmSpec
	local name
	if k.short then
		name = src:Name()
	else
		name = src:FullName()
	end
	if k.group then
		local line = name
		if k.level and name ~= nil then
			-- a secret name is still a string: the client joins it for us
			local ok, joined = pcall(function() return levelText(src) .. name end)
			line = ok and joined or name
		end
		writeName(b.name, line)
		if gone then
			b.name:SetTextColor(0.60, 0.64, 0.62)
		elseif src:Charmed() then
			b.name:SetTextColor(1, 0.80, 0.78)
		else
			b.name:SetTextColor(1, 1, 1)
		end
	elseif name ~= nil then
		-- a secret name is still a string: the client joins it for us. A
		-- frame with a tab for the level does not say it twice.
		local ok, line = pcall(function()
			return (k.text ~= "none" and not k.levelTab and levelText(src) or "") .. name
		end)
		writeName(b.name, ok and line or name)
	else
		b.name:SetText("")
	end
end

-- the Ledger's mark on the target (BT.LedgerMenu.Mark): the note's mark,
-- then the tags' squares, ending at the corner
local SQUARE_STEP = 10
local function paintLedger(b, gone)
	local m = b.ledger
	if not m then
		return
	end
	local note, colors = false, nil
	local mark = BT.LedgerMenu and BT.LedgerMenu.Mark
	if mark and b.bmUnit and not gone then
		local ok, n, c = pcall(mark, b.bmUnit)
		if ok then
			note, colors = n, c
		end
	end
	colors = colors or {}
	if not note and #colors == 0 then
		m:Hide()
		return
	end
	local x = 0
	for i = #m.squares, 1, -1 do
		local s, c = m.squares[i], colors[i]
		if c then
			s:SetColorTexture(c[1], c[2], c[3], 1)
			s:ClearAllPoints()
			s:SetPoint("RIGHT", m, "RIGHT", -x, 0)
			s:Show()
			x = x + SQUARE_STEP
		else
			s:Hide()
		end
	end
	m.note:ClearAllPoints()
	m.note:SetPoint("RIGHT", m, "RIGHT", -x, 0)
	m.note:SetShown(note and true or false)
	m:Show()
end

-- what is said in place of the health, from plain answers only: offline, a
-- ghost, dead, or (in a group) charmed
local function statusOf(src, k)
	return src:Offline() and "Offline" or (src:Ghost() and "Ghost") or (src:Dead() and "Dead")
		or (k.group and src:Charmed() and "Charmed") or nil
end

-- the health in words, as the frame's setting says (F.HealthMode): on the
-- target the number to the left and the share to the right; elsewhere
-- one corner, both joined when both are wanted
local function paintValue(b, src, status)
	local mode = F.HealthMode(b.bmKind, b.bmSpec)
	local left, right = "", ""
	if status == nil and mode ~= "none" then
		local pct = (mode == "percent" or mode == "both") and (src:PercentText() or "") or nil
		local val = (mode == "value" or mode == "both") and (src:HealthText() or "") or nil
		if b.hpText then
			left, right = val or "", pct or ""
		elseif pct and val then
			-- a secret figure is still a string: the client joins it for us
			local ok, joined = pcall(function() return val .. "  " .. pct end)
			right = ok and joined or pct
		else
			right = pct or val or ""
		end
	end
	if b.hpText then
		b.hpText:SetText(left)
	end
	b.status:SetText(status or "")
	b.status:SetShown(status ~= nil)
	b.value:SetShown(status == nil and mode ~= "none")
	b.value:SetText(right)
end

-- range and target, which may be secret: onto alpha, never tested
local function paintRange(b, src)
	local k = b.bmSpec
	if k.group then
		alphaFrom(b, src:InRange(), 1, F.Far(true))
		b.outline:Show()
		alphaFrom(b.outline, src:IsTarget(), 1, 0)
	elseif k.plate then
		-- a plate is always in reach: what it says is whether it is your
		-- target, by the outline, and the others step back while you have
		-- one (F.PlateDim, the Nameplates module's choice)
		local target = src:IsTarget()
		b.outline:Show()
		alphaFrom(b.outline, target, 1, 0)
		local dim = F.PlateDim and F.PlateDim()
		if dim and plain(UnitExists, "target") then
			alphaFrom(b, target, 1, dim)
		else
			b:SetAlpha(1)
		end
	elseif not k.mini then
		-- a single frame fades less than a cell: a target you are walking
		-- towards is still read
		alphaFrom(b, src:InRange(), 1, F.Far(false))
	end
end

-- The whole button, from its source. Every call is a setter, and nothing is
-- laid out except the combo row. An event about one thing paints that thing
-- alone (F.OnUnitEvent); this is everything else, and a frame's first paint.
function F.Paint(b, src)
	if not (b and b.bmDressed and src) then
		return
	end
	local k = b.bmSpec
	b.bmSrc = src
	if not src:Exists() then
		return
	end
	local gone = src:Gone()
	local ease = easeOf(b, src)
	paintHealth(b, src, gone, ease)
	paintPower(b, src, gone, ease)
	paintName(b, src, gone)
	local status = statusOf(src, k)
	-- what stood in for the health at the last whole paint (F.PaintHealth)
	b.bmStatus = status or false
	paintValue(b, src, status)

	-- the rank: gold for elite and world boss, silver for rare, crested elites
	if b.rank then
		local worn = BT.Ornament.Paint(b.rank, (not gone) and src:Classification() or nil) ~= nil
		-- a border on or off moves what hangs under the frame
		if worn ~= (b.bmBordered or false) then
			b.bmBordered = worn
			placeCombo(b)
			if F.Auras and b.bmAuras then
				F.Auras.Place(b)
			end
		end
	end

	-- the level's tab, and the brackets for an elite or a rare
	if b.levelText then
		b.levelText:SetText(F.LevelTag(src))
	end
	if b.brackets then
		local style = (not gone) and F.RANK[src:Classification() or ""] or nil
		for _, br in ipairs(b.brackets) do
			if style then
				local c = style.colour
				for _, t in ipairs(br.parts) do
					t:SetColorTexture(c[1], c[2], c[3], 1)
				end
				br:Show()
			else
				br:Hide()
			end
		end
	end

	-- aggro: 1 high threat, 2 about to pull it, 3 it is on them (or on you)
	local threat = src:Threat()
	if type(threat) == "number" and threat >= 1 and not gone then
		local r, g, bl = 0.82, 0.27, 0.24
		if _G.GetThreatStatusColor then
			local ok, cr, cg, cb = pcall(_G.GetThreatStatusColor, threat)
			if ok and type(cr) == "number" then
				r, g, bl = cr, cg, cb
			end
		end
		local c = b.threat.colour or {}
		b.threat.colour = c
		c[1], c[2], c[3], c[4] = r, g, bl, 1
		BT.Pill.PaintRing(b.threat.ring, c)
		b.threat.level = threat
		b.threat:Show()
	else
		b.threat.level = nil
		b.threat:Hide()
	end

	-- the marks
	local marker = src:Marker()
	if secret(marker) then
		-- never read, only handed to the client to draw
		b.marker:SetShown(F.DrawMarker(b.marker, marker))
	elseif type(marker) == "number" and marker > 0 and marker <= 8 then
		if _G.SetRaidTargetIconTexture then
			_G.SetRaidTargetIconTexture(b.marker, marker)
		else
			-- the client's own sheet is four across: star, circle, diamond,
			-- triangle, then moon, square, cross, skull
			local col, row = (marker - 1) % 4, math.floor((marker - 1) / 4)
			b.marker:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
		end
		b.marker:Show()
	else
		b.marker:Hide()
	end
	b.leader:SetShown(k.group and src:Leader() or false)
	paintLedger(b, gone)
	if b.rest then
		b.rest:SetShown(b.bmUnit == "player" and F.Resting() or false)
	end
	if b.ml then
		b.ml:SetShown(src:MasterLooter() and true or false)
	end
	-- a summon before a resurrection: the summon is the one you act on
	if b.call then
		local summon = src:Summon()
		local icon = (summon and summon > 0 and CALL[summon]) or (src:Res() and CALL.rez) or nil
		if icon and not src:Offline() then
			setIcon(b.call, icon)
			b.call:Show()
		else
			b.call.icon = nil
			b.call:Hide()
		end
	end
	if b.happy then
		local h = HAPPY[src:Happiness() or 0]
		if h then
			b.happy:SetColorTexture(h[1], h[2], h[3], 1)
			b.happy:Show()
		else
			b.happy:Hide()
		end
	end
	if b.threatText then
		local pct, status = src:ThreatPercent()
		if pct ~= nil then
			local okF, line = pcall(string.format, "%d%%", pct)
			b.threatText:SetText(okF and line or "")
			local cr, cg, cb = 0.80, 0.84, 0.82
			if type(status) == "number" and _G.GetThreatStatusColor then
				local ok, r, g, bl = pcall(_G.GetThreatStatusColor, status)
				if ok and type(r) == "number" then
					cr, cg, cb = r, g, bl
				end
			end
			b.threatText:SetTextColor(cr, cg, cb)
			b.threatText:Show()
		else
			b.threatText:Hide()
		end
	end
	local ready = src:Ready()
	if ready and READY[ready] and k.group then
		b.ready:SetTexture(READY[ready])
		b.ready:Show()
	else
		b.ready:Hide()
	end

	paintRange(b, src)

	F.PaintCast(b, src)
	F.PaintCombo(b, src)
end

-- the rim round a cast the game calls important: red, warmer than the
-- target's white outline and the threat ring's red so it reads as its own
F.IMPORTANT = { 1.00, 0.36, 0.25, 1 }

-- the cast's name after the picture, or at the bar's left end without one
function F.CastTextAt(b, withIcon)
	if b.cast.bmTextAfter == withIcon then
		return
	end
	b.cast.bmTextAfter = withIcon
	b.cast.text:ClearAllPoints()
	b.cast.text:SetPoint("RIGHT", -5, 0)
	if withIcon then
		b.cast.text:SetPoint("LEFT", b.cast.icon, "RIGHT", 4, 0)
	else
		b.cast.text:SetPoint("LEFT", 5, 0)
	end
end

-- the cast bar: a Duration the bar runs itself, and the colour says whether
-- a kick will land - grey for a cast you cannot interrupt
local CAN_KICK = { 0.90, 0.78, 0.29 }
local NO_KICK = { 0.55, 0.57, 0.56 }

function F.PaintCast(b, src)
	if not (b and b.cast) then
		return
	end
	local c = src:Cast()
	if not c then
		b.cast:Hide()
		return
	end
	local tex = b.cast:GetStatusBarTexture()
	if c.duration ~= nil and b.cast.SetTimerDuration then
		pcall(b.cast.SetTimerDuration, b.cast, c.duration)
	elseif c.value then
		b.cast:SetMinMaxValues(0, 1)
		b.cast:SetValue(c.value)
	end
	if secret(c.shielded) and tex.SetVertexColorFromBoolean and CreateColor then
		b.castNo = b.castNo or CreateColor(NO_KICK[1], NO_KICK[2], NO_KICK[3], 1)
		b.castYes = b.castYes or CreateColor(CAN_KICK[1], CAN_KICK[2], CAN_KICK[3], 1)
		b.cast:SetStatusBarColor(1, 1, 1, 0.9)
		pcall(tex.SetVertexColorFromBoolean, tex, c.shielded, b.castNo, b.castYes)
	else
		local col = c.shielded and NO_KICK or CAN_KICK
		b.cast:SetStatusBarColor(col[1], col[2], col[3], 0.9)
	end
	-- a name or a picture the client keeps hidden goes to the widget as it
	-- came: nothing here may test it, so only a plain one is looked at
	local name = c.name
	if not secret(name) and name == nil then
		name = ""
	end
	b.cast.text:SetText(name)
	local icon = c.icon
	if b.cast.icon and (secret(icon) or icon ~= nil) then
		b.cast.icon:SetTexture(icon)
		b.cast.icon:Show()
		F.CastTextAt(b, true)
	elseif b.cast.icon then
		b.cast.icon:Hide()
		F.CastTextAt(b, false)
	end
	if b.cast.rim then
		alphaFrom(b.cast.rim, c.important, 1, 0)
	end
	b.cast:Show()
end

-- does this character have combo points at all - a rogue, or a druid (whose
-- are the cat's). Settles whether the row under the target is kept.
function F.UsesCombo()
	local cls = select(2, raw(UnitClass, "player"))
	return cls == "ROGUE" or cls == "DRUID"
end

-- A POWER TICK THAT IS NOT A POINT (Josh 2026-09-30, review). Energy, mana,
-- rage and focus come on the same event as combo points, many times a
-- second, and the event names which power moved. Only these known others are
-- passed over, so a client that names its points some other way still has
-- them counted. (The resource display keeps the same list.)
F.NOT_COMBO = { ENERGY = true, MANA = true, RAGE = true, FOCUS = true }
function F.NotCombo(powerType)
	return type(powerType) == "string" and not secret(powerType) and F.NOT_COMBO[powerType] == true
end

function F.PaintCombo(b, src)
	if not (b and b.combo) then
		return
	end
	-- YOUR points, on something you can hit (Josh 2026-09-23): the row showed
	-- under a friendly druid in bear form, where it read as the druid's own.
	-- The class and the cat form are the resource display's question.
	-- A PREVIEW TOO (Josh 2026-09-24): it drew points for every class, and
	-- the auras under a target leave the combo row's room only for a class
	-- that has one - so a warlock's preview had its debuffs on the points.
	local cls = select(2, raw(UnitClass, "player"))
	local cur, max, show = src:Combo()
	if not (show and src:CanAttack() and (secret(cls) or cls == "ROGUE" or cls == "DRUID")) then
		b.combo:Hide()
		placeCombo(b)
		if b.cast and not b.bmSpec.castOverPower then
			local gap = b.bmSpec.castGap or 3
			b.cast:ClearAllPoints()
			b.cast:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -gap)
			b.cast:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -gap)
		end
		return
	end
	placeCombo(b)
	local a = W.ACCENT
	for _, s in ipairs(b.combo.segs) do
		s:SetStatusBarColor(a[1], a[2], a[3], 1)
		s.bg:SetColorTexture(W.FILL[1], W.FILL[2], W.FILL[3], 0.9)
		s:SetValue(cur)
	end
	b.combo:Show()
end

-- ---------------------------------------------------------------------------
-- A secure one, tied to a unit
-- ---------------------------------------------------------------------------

-- the events a unit's own frame listens to; the shared ones are in UnitFrames.lua
-- (UNIT_POWER_FREQUENT alone: it comes with every change, and
-- UNIT_POWER_UPDATE only says it again, so the two painted a frame twice)
F.UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
	"UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_FACTION",
	"UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_THREAT_LIST_UPDATE", "UNIT_HAPPINESS",
	"UNIT_IN_RANGE_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

-- WHAT A FRAME SHOWS IS WHAT IT HEARS (Josh 2026-09-23, audit). Every frame
-- listened for all of these, so a raid cell with no power bar and no cast bar
-- was painted in full for every mana tick and every cast of its member.
-- Power only where there is a power bar, casts only where there is a cast
-- bar, a pet's mood only on a pet.
local POWER = { UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }
function F.EventsFor(b)
	local out = {}
	for _, event in ipairs(F.UNIT_EVENTS) do
		local want = true
		if POWER[event] then
			want = b.power ~= nil
		elseif event:find("^UNIT_SPELLCAST") then
			want = b.cast ~= nil
		elseif event == "UNIT_HAPPINESS" then
			want = b.happy ~= nil
		end
		if want then
			out[#out + 1] = event
		end
	end
	return out
end

-- ONE EVENT, ONE PIECE (Josh 2026-09-30, review). Every event a frame heard
-- painted all of it: a raid cell's health moving in a fight wrote its name,
-- marks, threat and range again too - some forty calls into the client for
-- each tick of each cell. An event now paints what it is about. Health is its
-- bars and its words; a death or a disconnect changes more than those (the
-- name greys, the power goes), so a different word in place of the health
-- than the last whole paint wrote is a whole paint again. Dead, ghost and
-- offline are plain answers: nothing here asks a secret anything.
local function painted(b, src)
	return b and b.bmDressed and src and src:Exists()
end

function F.PaintHealth(b, src)
	if not painted(b, src) then
		return
	end
	local status = statusOf(src, b.bmSpec)
	if (status or false) ~= b.bmStatus then
		return F.Paint(b, src)
	end
	b.bmSrc = src
	paintHealth(b, src, src:Gone(), easeOf(b, src))
	paintValue(b, src, status)
end

function F.PaintPower(b, src)
	if not painted(b, src) then
		return
	end
	b.bmSrc = src
	paintPower(b, src, src:Gone(), easeOf(b, src))
end

function F.PaintRange(b, src)
	if painted(b, src) then
		paintRange(b, src)
	end
end

-- which painter each event goes to, by name; any other event paints it all
local PIECE = { UNIT_HEALTH = "PaintHealth", UNIT_MAXHEALTH = "PaintHealth", UNIT_HEAL_PREDICTION = "PaintHealth",
	UNIT_ABSORB_AMOUNT_CHANGED = "PaintHealth", UNIT_IN_RANGE_UPDATE = "PaintRange" }
for event in pairs(POWER) do
	PIECE[event] = "PaintPower"
end
for _, event in ipairs(F.UNIT_EVENTS) do
	if event:find("^UNIT_SPELLCAST") then
		PIECE[event] = "PaintCast"
	end
end
F.PIECE = PIECE

-- not while it cannot be seen: a party cell hidden in a raid, a boss frame
-- switched off, your own target mini - they are painted as they appear (the
-- OnShow hook in F.Dress)
function F.OnUnitEvent(self, event)
	if self.bmUnit and self.bmDressed and self:IsVisible() then
		F[PIECE[event] or "Paint"](self, F.Source(self.bmUnit))
	end
end

-- Point a button at a unit: its events, its clicks (out of combat only - they
-- are attributes of a secure frame), and a paint.
-- a member's pet and target, as unit tokens
function F.PetOf(unit)
	if type(unit) ~= "string" then
		return nil
	end
	if unit == "player" then
		return "pet"
	end
	local kind, n = unit:match("^(%a+)(%d+)$")
	if kind == "party" or kind == "raid" then
		return kind .. "pet" .. n
	end
	return nil
end

function F.TargetOf(unit)
	return type(unit) == "string" and (unit == "player" and "target" or unit .. "target") or nil
end

function F.Bind(b, unit)
	-- the member's pet and target follow the member: the client's secure code
	-- works their units out from ours (useparent-unit and a suffix) for clicks
	-- and for showing them, and these are the same tokens for painting
	if b.bmPet then
		F.Bind(b.bmPet, F.PetOf(unit))
	end
	if b.bmTarget then
		F.Bind(b.bmTarget, F.TargetOf(unit))
	end
	if b.bmUnit ~= unit then
		F.Fresh(b)
	end
	b.bmUnit = unit
	-- the aura rows follow the unit (Modules/UnitFrames/Auras.lua)
	if F.Auras and b.bmAuras then
		F.Auras.SetUnit(b, unit)
	end
	if unit and b.SetAttribute and not (InCombatLockdown and InCombatLockdown()) and b.bmOwnsUnit then
		b:SetAttribute("unit", unit)
	end
	b:UnregisterAllEvents()
	if unit then
		b.bmEvents = b.bmEvents or F.EventsFor(b)
		for _, event in ipairs(b.bmEvents) do
			if b.RegisterUnitEvent then
				pcall(b.RegisterUnitEvent, b, event, unit)
			end
		end
	end
	b:SetScript("OnEvent", F.OnUnitEvent)
	if unit then
		F.Paint(b, F.Source(unit))
	end
end

-- the clicks a unit frame has always had: target it, or its menu
function F.Clicks(b)
	if not b.SetAttribute or (InCombatLockdown and InCombatLockdown()) then
		return false
	end
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("*type1", "target")
	b:SetAttribute("*type2", "togglemenu")
	return true
end
