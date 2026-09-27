-- The personal resource display, in the toolkit's clothes, with combo points
-- under it (Josh 2026-09-22).
--
-- The display is your own nameplate: the client puts a health bar and a
-- power bar under your character when nameplateShowSelf is on. It wears the
-- nameplate's own art, and on this client it says nothing about combo points
-- - a rogue or a cat reads them off the target frame, which is the wrong
-- end of the screen for a number you act on every second.
--
-- TWO THINGS, TWO SWITCHES. The bars are dressed the way every other piece
-- of the client's furniture is (Core/Furniture.lua): their textures go flat,
-- their art comes off, a one-pixel rim of ours goes round each. And a row of
-- pips of our own hangs under them, one per point, lit in the accent as you
-- earn them - for whoever has points to show: rogues always, druids in cat
-- form, anyone else whose class turns out to carry them.
--
-- A NAMEPLATE IS BORROWED, NOT OWNED. The client keeps a pool of them and
-- hands one to whatever unit needs it; the one showing you now may show a
-- boar in a minute. So everything here is keyed to the moment the client
-- says the player's plate arrived, and put back the moment it says it went.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/PRD/PRD.lua")

local U = BT.Util

local M = BT.Module({
	key = "prd",
	feature = "frames",
	title = "Resource display",
	blurb = "your own nameplate, flat, with combo points under it",
	order = 58.5,
})

local FILL = BT.Widgets.FILL
local RIM = BT.Widgets.RIM
local ACCENT = BT.Widgets.ACCENT

local dresser = BT.Furniture.New({ flatBars = true, ringBars = true })

-- THE PIPS ARE A BAR (Josh 2026-09-22). Five small squares under two full
-- width bars read as a different object; a row the width of the bars, cut
-- into as many segments as there are points, reads as a third bar. The
-- height, the gap between segments, and how far under the bars it hangs.
local PIP_H, PIP_GAP, PIP_DROP = 6, 2, 3

local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local ENERGY = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3

local function opt(name, fallback)
	local s = BT.settings and BT.settings.prd
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

function M.SetOpt(name, value)
	BT.EnsureBound()
	BT.settings.prd = BT.settings.prd or {}
	BT.settings.prd[name] = value
	M.Apply()
end

-- ---------------------------------------------------------------------------
-- The plate
-- ---------------------------------------------------------------------------

local plate -- the nameplate frame showing the player right now, if any
-- hooks the display's own show and hide; written below Apply, used in it
local hookPlate

-- the frame a piece of the client's hangs off, walked up to the nameplate
local function plateOf(f)
	local guard = 0
	while type(f) == "table" and guard < 6 do
		local name = BT.Furniture.Call(f, "GetName")
		if type(name) == "string" and name:find("NamePlate", 1, true) then
			return f
		end
		if f.namePlateUnitToken or (type(f.UnitFrame) == "table") then
			return f
		end
		f = BT.Furniture.Call(f, "GetParent")
		guard = guard + 1
	end
	return nil
end

-- does this plate say it is the player's
local function isMine(p)
	if type(p) ~= "table" then
		return false
	end
	local token = p.namePlateUnitToken or p.unit
		or (type(p.UnitFrame) == "table" and (p.UnitFrame.unit or p.UnitFrame.displayedUnit))
	if type(token) ~= "string" then
		return false
	end
	if token == "player" then
		return true
	end
	if UnitIsUnit then
		local ok, same = pcall(UnitIsUnit, token, "player")
		return ok and same and true or false
	end
	return false
end

-- FOUND FOUR WAYS (Josh 2026-09-22). Asked for by unit, which is the modern
-- answer and the one this client did not give; then every plate the client
-- lists, asked whose it is; then the client's own power bar for the display
-- (ClassNameplateManaBarFrame, the driver's class bar), walked up to its
-- plate; then every frame there is, for one called NamePlate that says it
-- is the player's.
-- WHAT THE DUMP SAID (Josh 2026-09-22, /bt prddump): on this client the
-- display is not a nameplate at all. It is a frame of its own called
-- PersonalResourceDisplayFrame, 199 by 34, shown under the character, and
-- the nameplate driver's own bars sit hidden with no parent. So that is
-- asked for first, by name; the nameplate answers stay for a build that
-- goes back to them.
local OWN = { "PersonalResourceDisplayFrame", "PersonalResourceDisplay" }

function M.Plate()
	for _, name in ipairs(OWN) do
		local f = _G[name]
		if type(f) == "table" and f.GetRegions then
			return f, name
		end
	end
	if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
		local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "player")
		if ok and type(p) == "table" then
			return p, "unit"
		end
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, list = pcall(C_NamePlate.GetNamePlates)
		for _, p in ipairs(ok and type(list) == "table" and list or {}) do
			if isMine(p) then
				return p, "list"
			end
		end
	end
	for _, name in ipairs({ "ClassNameplateManaBarFrame", "ClassNameplateBarFrame" }) do
		local bar = _G[name]
		if type(bar) == "table" and BT.Furniture.Call(bar, "IsShown") then
			local p = plateOf(BT.Furniture.Call(bar, "GetParent"))
			if p then
				return p, name
			end
		end
	end
	local driver = _G.NamePlateDriverFrame
	if type(driver) == "table" then
		for _, key in ipairs({ "classNamePlatePowerBar", "classNamePlateMechanicFrame", "classNamePlateAlternatePowerBar" }) do
			local bar = driver[key]
			if type(bar) == "table" and BT.Furniture.Call(bar, "IsShown") then
				local p = plateOf(BT.Furniture.Call(bar, "GetParent"))
				if p then
					return p, key
				end
			end
		end
	end
	if type(_G.EnumerateFrames) == "function" then
		local f, guard = nil, 0
		repeat
			local ok, nxt = pcall(_G.EnumerateFrames, f)
			if not ok then
				break
			end
			f = nxt
			guard = guard + 1
			-- NAMED NamePlate, AND the player's: `unit == "player"` alone is
			-- true of every buff button on the screen, and the scan once
			-- handed one of those over (the dump showed a 29x39 aura)
			local name = f and BT.Furniture.Call(f, "GetName")
			if f and type(name) == "string" and name:find("NamePlate", 1, true)
				and isMine(f) and BT.Furniture.Call(f, "IsShown") then
				return f, "scan"
			end
		until not f or guard > 20000
	end
	return nil
end

-- the frame the bars hang off: the plate's UnitFrame when it has one
local function bars(p)
	return (type(p) == "table" and type(p.UnitFrame) == "table") and p.UnitFrame or p
end

-- ---------------------------------------------------------------------------
-- The points
-- ---------------------------------------------------------------------------

-- how many you have, how many you could have, whether they are worth showing
-- at all right now, and whether the count is one we may not read
--
-- A SECRET COUNT IS STILL A COUNT (Josh 2026-09-23). The row sat empty with
-- three points on the target frame. In combat this client can hand the count
-- back as a secret value, and Pill.Number turns a secret into its fallback -
-- so three points became none. The count cannot be compared or added up, but
-- it can be handed to a status bar, which is how the segments draw it (see
-- M.Pips). A readable count above zero wins; failing that a secret one, which
-- may hold the answer; failing both, none.
local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a number from the client, or nil. Only type() and issecretvalue() are asked
-- of what comes back: a secret cannot be compared, even with nil or false.
local function ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if ok and type(v) == "number" then
		return v
	end
	return nil
end

function M.Combo()
	local _, class = nil, nil
	if UnitClass then
		local ok, a, b = pcall(UnitClass, "player")
		if ok then
			_, class = a, b
		end
	end
	local max = BT.Pill.Number(ask(UnitPowerMax, "player", COMBO), 0)
	if max <= 0 and (class == "ROGUE" or class == "DRUID") then
		max = 5 -- a client that will not say still has five for these two
	end
	if max <= 0 then
		return 0, 0, false, false
	end
	-- a druid's points are the cat's: out of cat form there is nothing to show
	if class == "DRUID" and UnitPowerType then
		local ok, kind = pcall(UnitPowerType, "player")
		if ok and kind ~= ENERGY then
			return 0, max, false, false
		end
	end
	local hidden, anyHidden = nil, false
	for _, v in ipairs({ { ask(UnitPower, "player", COMBO) }, { ask(GetComboPoints, "player", "target") } }) do
		v = v[1]
		if type(v) == "number" then
			if secret(v) then
				if not anyHidden then
					hidden, anyHidden = v, true
				end
			elseif v > 0 then
				return math.min(v, max), max, true, false
			end
		end
	end
	if anyHidden then
		return hidden, max, true, true
	end
	return 0, max, true, false
end

local pips -- the holder, and the squares on it

local function pipHolder()
	if pips then
		return pips
	end
	pips = CreateFrame("Frame", nil, UIParent)
	pips.beebs = true
	pips.squares = {}
	pips:Hide()
	return pips
end

-- A SEGMENT IS A STATUS BAR (Josh 2026-09-23), running from i - 1 to i: the
-- count handed to it fills it when you have at least i points and leaves it
-- empty otherwise. A status bar takes a secret value where arithmetic will
-- not, so the row reads the same in combat as out of it.
local BLANK = "Interface\\Buttons\\WHITE8X8"

local function pip(i)
	local h = pipHolder()
	local sq = h.squares[i]
	if sq then
		return sq
	end
	sq = CreateFrame("StatusBar", nil, h)
	sq.beebs = true
	sq:SetHeight(PIP_H)
	sq:SetStatusBarTexture(BLANK)
	sq:SetMinMaxValues(i - 1, i)
	sq.bg = sq:CreateTexture(nil, "BACKGROUND")
	sq.bg.beebs = true
	sq.bg:SetAllPoints()
	-- on the segment, not the holder: a child frame draws over its parent's
	-- textures, so a rim on the holder would be under the bar it goes round
	sq.rim = BT.Pill.Ring(sq, "OVERLAY", 1)
	h.squares[i] = sq
	return sq
end

-- THE LOWEST BAR IS THE ONE TO HANG UNDER (Josh 2026-09-22). The plate's
-- UnitFrame holds the health bar, and the client's power bar for the display
-- hangs under that from a frame of its own - so a row anchored to the
-- UnitFrame's bottom landed on top of the power bar, behind it. Every bar
-- that could be the display's is asked where its bottom is, and the row goes
-- under the lowest, a step above it in frame level.
function M.PipAnchor()
	local candidates = {}
	if plate then
		candidates[#candidates + 1] = bars(plate)
		candidates[#candidates + 1] = plate
	end
	for _, name in ipairs({ "ClassNameplateManaBarFrame", "ClassNameplateBarFrame" }) do
		candidates[#candidates + 1] = _G[name]
	end
	local driver = _G.NamePlateDriverFrame
	if type(driver) == "table" then
		for _, key in ipairs({ "classNamePlatePowerBar", "classNamePlateAlternatePowerBar", "classNamePlateMechanicFrame" }) do
			candidates[#candidates + 1] = driver[key]
		end
	end
	local best, bestBottom = nil, nil
	for _, f in ipairs(candidates) do
		if type(f) == "table" and BT.Furniture.Call(f, "IsShown") then
			local bottom = BT.Pill.Number(BT.Furniture.Call(f, "GetBottom"), nil)
			if bottom and (not bestBottom or bottom < bestBottom) then
				best, bestBottom = f, bottom
			elseif not best then
				best = f
			end
		end
	end
	return best
end

-- paint the row for what you have; `cur`, `max` from M.Combo. `cur` may be
-- secret: it is only ever handed to SetValue, never compared.
function M.Pips(cur, max, show)
	local h = pipHolder()
	local anchor = (show and max > 0 and opt("combo", true)) and M.PipAnchor() or nil
	if not anchor then
		h:Hide()
		return 0
	end
	M.pipAnchor = anchor
	h:SetParent(plate or anchor)
	h:ClearAllPoints()
	-- the bars' own edges, so the row is exactly as wide as they are
	h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -PIP_DROP)
	h:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -PIP_DROP)
	h:SetHeight(PIP_H)
	-- over the bar it hangs under, not behind it
	local strata = BT.Furniture.Call(anchor, "GetFrameStrata")
	if type(strata) == "string" and h.SetFrameStrata then
		pcall(h.SetFrameStrata, h, strata)
	end
	local level = BT.Pill.Number(BT.Furniture.Call(anchor, "GetFrameLevel"), 1)
	if h.SetFrameLevel then
		pcall(h.SetFrameLevel, h, level + 5)
	end
	-- the segments share the width; measured off the bars, with the width
	-- the dump showed as the fallback for a client that keeps it secret
	local width = BT.Pill.Number(BT.Furniture.Call(anchor, "GetWidth"), 199)
	local seg = math.max(4, (width - (max - 1) * PIP_GAP) / max)
	for i = 1, max do
		local sq = pip(i)
		sq:ClearAllPoints()
		sq:SetWidth(seg)
		sq:SetPoint("LEFT", h, "LEFT", (i - 1) * (seg + PIP_GAP), 0)
		sq:SetStatusBarColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		sq.bg:SetColorTexture(FILL[1], FILL[2], FILL[3], 0.88)
		-- as it came: `cur or 0` would test a secret, and the client may refuse that
		sq:SetValue(cur)
		BT.Pill.PlaceRing(sq.rim, sq, 0, 1, 0)
		BT.Pill.PaintRing(sq.rim, RIM)
		sq:Show()
	end
	for i = max + 1, #h.squares do
		h.squares[i]:Hide()
		BT.Pill.HideRing(h.squares[i].rim)
	end
	h:Show()
	return max
end

-- ---------------------------------------------------------------------------
-- Putting it all on, and taking it off
-- ---------------------------------------------------------------------------

-- The player's plate, as the client has it right now: dressed if the switch
-- is on, and the pips under it. Called on every event that could have moved
-- anything; a plate already dressed costs a walk of a small tree.
function M.Apply()
	if not BT.Enabled("prd") then
		return M.Release()
	end
	local p, how = M.Plate()
	if p ~= plate then
		-- the plate we had may be somebody else's now: everything back
		dresser:Undress()
		plate = p
	end
	M.foundBy = p and how or nil
	hookPlate(p)
	local n = 0
	if plate and opt("theme", true) then
		local ok, count = pcall(dresser.DressTree, dresser, bars(plate), 0, nil)
		n = ok and (count or 0) or 0
		if not ok then
			BT.Err("prd: " .. tostring(count))
		end
	elseif plate then
		dresser:Undress()
	end
	M.lastCount = n
	M.Pips(M.Combo())
	-- your target's damage over time, over the bars (Frames/Timers.lua)
	local T = BT.UnitFrames and BT.UnitFrames.Timers
	if T then
		T.OnPRD(plate and M.TopAnchor() or nil)
	end
	return n
end

-- the top of the display: the health bar, where the plate names it
function M.TopAnchor()
	if not plate then
		return nil
	end
	local uf = bars(plate)
	for _, key in ipairs({ "healthBar", "HealthBarsContainer" }) do
		local f = uf[key]
		if type(f) == "table" and BT.Furniture.Call(f, "IsShown") then
			return f
		end
	end
	return uf
end

-- the client's plate back as it came, and the pips away
function M.Release()
	dresser:Undress()
	local T = BT.UnitFrames and BT.UnitFrames.Timers
	if T then
		T.OnPRD(nil)
	end
	if pips then
		pips:Hide()
		pips:SetParent(UIParent)
	end
	plate = nil
	M.lastCount = 0
	return 0
end

-- the theme changed: paint again
function M.Restyle()
	if BT.Enabled("prd") then
		return M.Apply()
	end
end

-- once per frame: the display's own show and hide, when it is a frame of
-- its own rather than a nameplate the events announce
hookPlate = function(p)
	if not (type(p) == "table" and p.HookScript) or p.beebsPrdHooked then
		return
	end
	p.beebsPrdHooked = true
	pcall(p.HookScript, p, "OnShow", function()
		if BT.Enabled("prd") then
			M.Apply()
		end
	end)
	pcall(p.HookScript, p, "OnHide", function()
		if pips then
			pips:Hide()
		end
	end)
end

function M.Watch()
	if M.events then
		return M.events
	end
	M.events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
		"PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM", "CVAR_UPDATE" }) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	-- your own power, not every unit's on the screen
	-- UNIT_POWER_FREQUENT IS THE ONE THAT CARRIES POINTS (Josh 2026-09-23):
	-- it is what the client's own combo frame listens to, and on this client
	-- earning a point does not always raise UNIT_POWER_UPDATE
	for _, event in ipairs({ "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
		local ok = M.events.RegisterUnitEvent
			and pcall(M.events.RegisterUnitEvent, M.events, event, "player")
		if not ok then
			pcall(M.events.RegisterEvent, M.events, event)
		end
	end
	M.events:SetScript("OnEvent", function(_, event, unit)
		if not BT.Enabled("prd") then
			return
		end
		-- EVERY SETTING IN THE GAME SAYS WHEN IT CHANGES (Josh 2026-09-23, /bt
		-- cpu: 225 a second, from the minimap's zoom): only the nameplate ones
		-- are this display's business
		if event == "CVAR_UPDATE" and not tostring(unit or ""):lower():find("nameplate", 1, true) then
			return
		end
		if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
			-- a plate's token is "nameplate3", never "player": asked whether
			-- that plate is you (Josh 2026-09-23, audit - these did nothing)
			local isMe = unit == "player"
			if not isMe and type(UnitIsUnit) == "function" and type(unit) == "string" then
				local ok, same = pcall(UnitIsUnit, unit, "player")
				isMe = ok and same == true
			end
			if not isMe then
				return
			end
			if event == "NAME_PLATE_UNIT_REMOVED" then
				-- the frame is about to be somebody else's
				M.Release()
				return
			end
		elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT"
			or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
			if unit and unit ~= "player" then
				return
			end
			-- the points alone: the bars did not move. And never the whole
			-- look for the display from a power tick (it walked every frame
			-- in the game several times a second while none was up); the
			-- other events find it.
			if plate then
				M.Pips(M.Combo())
			end
			return
		end
		M.Apply()
	end)
	return M.events
end

function M:OnEnable()
	M.Watch()
	M.Apply()
	-- your target's damage leaves the target frame for the bars
	if BT.UnitFrames and BT.UnitFrames.Timers then
		BT.UnitFrames.Timers.Rebuild()
	end
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.Release()
	-- your target's damage goes back over the target frame
	if BT.UnitFrames and BT.UnitFrames.Timers then
		BT.UnitFrames.Timers.Rebuild()
	end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

local function switchRow(section, title, blurb, name, fallback)
	local r = BT.Widgets.SwitchRow(section, title, blurb,
		function() return opt(name, fallback) end,
		function(on) M.SetOpt(name, on) end)
	r.name, r.fallback = name, fallback
	return r
end

-- the points in words; a secret count is never formatted, because a secret
-- in a string makes the whole string secret and the chat line unreadable
function M.Said()
	local cur, max, show, hidden = M.Combo()
	if not show then
		return "no points to show"
	elseif hidden then
		return ("count kept secret by the client · out of %d · the row still shows it"):format(max)
	end
	return ("%d of %d points"):format(cur, max)
end

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("your own nameplate, when the client shows one (nameplateShowSelf) · /bt prddump writes its frames into the saved file")
	local plateSection = page:Section("The display")
	self.rows = {
		switchRow(plateSection, "Theme the bars", "flat bars in a one-pixel rim, the client's art off", "theme", true),
		switchRow(plateSection, "Combo points under it", "a segment a point · rogues, and druids in cat form", "combo", true),
	}
	-- what the display is doing right now, as a row of its own: pinned to
	-- the foot of the panel it sat on the rows once the page grew
	self.status = BT.Widgets.Row(plateSection, "On screen", " ")
	self.found = self.status.blurb
	-- YOUR TARGET'S DAMAGE OVER TIME, OVER THESE BARS (Josh 2026-09-24:
	-- "need to move the options as well"): which spells, in what order, and
	-- the countdown - here, where the lanes are (Frames/Timers.lua). The
	-- same lanes stand over the focus and the bosses.
	local T = BT.UnitFrames and BT.UnitFrames.Timers
	if T then
		self.dots = T.DotSection(page)
		if self.dots then
			self.blinkRow = T.BlinkRow(self.dots, "dot")
		end
	end
	page:Layout()
end

function M:RefreshTab()
	for _, r in ipairs(self.rows or {}) do
		r.switch:SetOn(opt(r.name, r.fallback))
	end
	if self.found then
		if not (plate and plate.IsVisible and plate:IsVisible()) then
			self.found:SetText("no resource display on screen · is nameplateShowSelf on?")
		else
			self.found:SetText(("%d pieces dressed · %s"):format(M.lastCount or 0, M.Said()))
		end
	end
end

function M:ShowTab()
	if BT.Enabled("prd") then
		M.Apply()
	end
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- the tests want the pieces without going through frames
function M.PipFrame()
	return pips
end
function M.CurrentPlate()
	return plate
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

BT.Command("prd", function()
	local n = M.Apply()
	if not (plate and plate.IsVisible and plate:IsVisible()) then
		U.Print("no resource display on screen · is nameplateShowSelf on? · /bt prddump says what is there")
	else
		U.Print(("resource display: %d pieces dressed · %s"):format(n, M.Said()))
	end
	-- THE RAW ANSWERS (Josh 2026-09-22), because "0 of 5" can be a client
	-- that counts points somewhere else, and "not shown" can be a row hung
	-- behind the bar it is under
	local function raw(fn, ...)
		if type(fn) ~= "function" then
			return "n/a"
		end
		local ok, v = pcall(fn, ...)
		if not ok then
			return "err"
		end
		-- a secret value printed makes the whole chat line secret, and the
		-- chat module then cannot read its own line
		if issecretvalue and issecretvalue(v) then
			return "secret"
		end
		return tostring(v)
	end
	U.Print(("  plate %s · found by %s · UnitFrame %s"):format(
		tostring(plate and (BT.Furniture.Call(plate, "GetName") or "unnamed") or "none"),
		tostring(M.foundBy), tostring(plate and plate.UnitFrame ~= nil)))
	U.Print(("  UnitPower(%d)=%s max=%s · GetComboPoints=%s · power type=%s · class=%s"):format(
		COMBO, raw(UnitPower, "player", COMBO), raw(UnitPowerMax, "player", COMBO),
		raw(GetComboPoints, "player", "target"), raw(UnitPowerType, "player"),
		tostring(select(2, pcall(function() return select(2, UnitClass("player")) end)))))
	local h = M.PipFrame()
	local anchor = M.pipAnchor
	U.Print(("  pips %s · under %s · %d squares · anchor bottom %s"):format(
		h and (h:IsShown() and "shown" or "hidden") or "none",
		tostring(anchor and (BT.Furniture.Call(anchor, "GetName") or BT.Furniture.KeyOf(plate, anchor) or "unnamed") or "nothing"),
		h and #h.squares or 0,
		tostring(BT.Pill.Number(anchor and BT.Furniture.Call(anchor, "GetBottom"), "secret"))))
end, "restyle the resource display now", "prd")

BT.Command("prddump", function(rest)
	if (rest or "") == "clear" then
		BT.EnsureBound()
		BeebModDB.prdDump = nil
		U.Print("resource display dump cleared")
		return
	end
	local p, how = M.Plate()
	local lines = BT.Furniture.Dump(p and { p } or {})
	table.insert(lines, 1, "player plate: " .. (p and ("found by " .. tostring(how)) or "NOT FOUND"))
	-- and every plate the client will list, whose it says it is, and the
	-- driver's own bars: enough to name the thing on the next attempt
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, list = pcall(C_NamePlate.GetNamePlates)
		for i, np in ipairs(ok and type(list) == "table" and list or {}) do
			lines[#lines + 1] = ("plate %d: %s token=%s unit=%s UnitFrame=%s | %s"):format(i,
				tostring(BT.Furniture.Call(np, "GetName")), tostring(np.namePlateUnitToken),
				tostring(np.unit or (np.UnitFrame and np.UnitFrame.unit)),
				tostring(np.UnitFrame ~= nil), BT.Furniture.Describe(np))
		end
	end
	for _, name in ipairs({ "PersonalResourceDisplayFrame", "ClassNameplateManaBarFrame", "ClassNameplateBarFrame",
		"NamePlateDriverFrame", "PersonalResourceDisplay", "PlayerNamePlate" }) do
		local f = _G[name]
		if type(f) == "table" then
			lines[#lines + 1] = name .. " | " .. BT.Furniture.Describe(f) .. " parent="
				.. tostring(BT.Furniture.Call(BT.Furniture.Call(f, "GetParent"), "GetName"))
			for _, l in ipairs(BT.Furniture.Dump({ f }, 300)) do
				lines[#lines + 1] = "  " .. l
			end
		end
	end
	if type(_G.EnumerateFrames) == "function" then
		local f, guard, n = nil, 0, 0
		repeat
			local okE, nxt = pcall(_G.EnumerateFrames, f)
			if not okE then
				break
			end
			f = nxt
			guard = guard + 1
			local name = f and BT.Furniture.Call(f, "GetName")
			if type(name) == "string" and (name:find("NamePlate", 1, true) or name:lower():find("resource", 1, true))
				and BT.Furniture.Call(f, "IsShown") and n < 40 then
				n = n + 1
				lines[#lines + 1] = "shown " .. name .. " | " .. BT.Furniture.Describe(f)
					.. " token=" .. tostring(f.namePlateUnitToken) .. " unit=" .. tostring(f.unit)
			end
		until not f or guard > 20000
	end
	BT.EnsureBound()
	BeebModDB.prdDump = {
		at = U.Now(),
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	U.Print(("resource display: %d lines written down · /reload to save them"):format(#lines))
end, "prddump [clear] - write the resource display's frames into the saved file", "prd")
