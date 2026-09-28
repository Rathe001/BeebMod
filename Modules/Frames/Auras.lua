-- Auras on the unit frames, drawn by the client (Josh 2026-09-23).
--
-- THE CLIENT WILL NOT LET US READ ONE IN A FIGHT. Every aura call - by index,
-- by instance ID, the whole list - is refused in combat "while tainted by
-- 'BeebMod'" (the second unit probe). What it offers instead is a container:
-- an AuraContainer made from CustomAuraContainerTemplate, told a unit and a
-- filter, which reads the auras itself, in its own secure code, and fills
-- buttons we describe. The addon never sees an aura; it says where, how many,
-- how big, and what a button is made of.
--
-- WHAT GOES WHERE
--   party cell   up to three debuffs along the bottom left, and up to three
--                of YOUR buffs on them (the heals you keep up) bottom right
--   raid cell    the same, two of each and smaller
--   target       under it, one row shared: its debuffs from the left and its
--                buffs from the right, four of each a line, two lines each
--   focus        your own debuffs on it, up to four, beside it
--   boss         its buffs that are part of the fight, up to three, beside it
--
-- NO PERMANENT BUFFS BUT THE TARGET'S (Josh 2026-09-24: "filter out perma
-- buffs from all unit frames except target"). A pet's aura, a stance, a form
-- is on somebody all day and says nothing on a cell; the buff rows keep only
-- auras with a duration, by the client's own filter (as the Buffs tray does).
-- The target is where you go to read what somebody has, so it shows them all.
--
-- A DEBUFF YOU CAN REMOVE colours the cell: a border inside the aggro ring and
-- a wash across the top, in the debuff's colour. The client decides whether
-- there is one (the filter is "HARMFUL|RAID", which on this client means
-- "one the player can dispel" - RAID_PLAYER_DISPELLABLE means anyone in the
-- raid could, the other way round from how it reads) and paints the colour;
-- we only made the textures.
--
-- THE RULES (from the client's source and from Dander's Frames, which found
-- most of them the hard way):
--   * a container is made and switched on out of combat only; so is its unit
--   * a button is the client's: set up in initializeFrame and never touched
--     again - in a fight the client refuses anything tainted done to one
--   * nothing is anchored TO a container; containers are anchored to us
--   * no formatter on the stack count - a secret count stops the container
--   * a unit change is written with SetUnit, and the container only acts on
--     it at its next aura event; hiding and showing it makes the client read
--     everything again, on its own secure side. So each frame's containers
--     sit on a holder of ours, and a new target or focus bounces the holder.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Frames/Auras.lua")

local F = BT.UnitFrames
local A = {}
F.Auras = A

local W = BT.Widgets

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- a duration cap no aura reaches: the client's candidate filter then passes
-- every aura that has a duration and none that has not
A.TIMED_MAX = 1e9
local TIMED = { maxDuration = A.TIMED_MAX }

-- What each kind of frame shows. `inside` rows sit on the health bar; the
-- others hang to the right of the frame, or under it (BELOW: from its left
-- edge, or from its right with growLeft).
A.SPECS = {
	party = {
		{ key = "debuffs", filter = "HARMFUL", max = 3, size = 16, at = "BOTTOMLEFT", inside = true },
		{ key = "mine", filter = "HELPFUL|PLAYER", max = 3, size = 14, at = "BOTTOMRIGHT", inside = true, quiet = true,
			candidate = TIMED },
		dispel = true,
	},
	raid = {
		{ key = "debuffs", filter = "HARMFUL", max = 2, size = 12, at = "BOTTOMLEFT", inside = true },
		{ key = "mine", filter = "HELPFUL|PLAYER", max = 2, size = 10, at = "BOTTOMRIGHT", inside = true, quiet = true,
			candidate = TIMED },
		dispel = true,
	},
	-- DEBUFFS LEFT, BUFFS RIGHT (Josh 2026-09-24: "we have 2 rows for
	-- buffs/debuffs, so the buffs look like they are sitting too low... there
	-- are no debuffs to fill that gap"). One row under the target, just below
	-- the frame - or below the combo row, for a class that has one (kept for
	-- the class, not the moment, so nothing moves): its debuffs from the left
	-- edge, its buffs - permanent ones too - from the right, a size smaller.
	-- Four of each a line and a second line under its own half, so the two
	-- never meet: in a fight nothing of ours can count what is in them. A buff
	-- you could purge or steal wears its type's colour at the edge. The cast
	-- goes over the power bar, so nothing else is here.
	target = {
		{ key = "debuffs", filter = "HARMFUL", max = 8, size = 18, perLine = 4, at = "BELOW", below = "combo" },
		{ key = "buffs", filter = "HELPFUL", max = 8, size = 16, perLine = 4, at = "BELOW", below = "combo",
			growLeft = true, flowAt = "TOPRIGHT", helpfulRing = true },
	},
	focus = {
		{ key = "debuffs", filter = "HARMFUL|PLAYER", max = 4, size = 14, at = "RIGHT" },
	},
	-- A BOSS SHOWS ITS MECHANICS, NOT YOUR DOTS (Josh 2026-09-23: "remove the
	-- debuffs from the right, unless it is part of a boss mechanic"). What is
	-- worth a glance beside a boss is a buff that is part of the fight - an
	-- enrage, an empowerment - so the row is its helpful auras the client
	-- itself flags as a boss's, and a purgeable or soothable one wears its
	-- type's colour at the edge.
	boss = {
		{ key = "mechanics", filter = "HELPFUL", max = 3, size = 16, at = "RIGHT",
			candidate = { isBossAura = true, maxDuration = A.TIMED_MAX }, helpfulRing = true },
	},
}

-- The colour of a dispel type, as a curve the client evaluates in its own
-- code: a secret dispel name cannot be looked up in a table of ours (Dander's
-- found a name-keyed map washed everything white). The x values are the
-- client's dispel type ids - 1 magic, 2 curse, 3 disease, 4 poison - which
-- no enum in the source names; the colours are the client's own.
local DISPEL = {
	[1] = { 0.20, 0.60, 1.00 }, [2] = { 0.60, 0.00, 1.00 }, [3] = { 0.60, 0.40, 0.00 },
	[4] = { 0.00, 0.60, 0.00 }, [9] = { 0.80, 0.20, 0.20 }, [11] = { 0.80, 0.20, 0.20 },
}
local curve
local function dispelCurve()
	if curve ~= nil then
		return curve or nil
	end
	curve = false
	pcall(function()
		local c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Step)
		c:AddPoint(0, CreateColor(0, 0, 0, 1))
		for id, rgb in pairs(DISPEL) do
			c:AddPoint(id, CreateColor(rgb[1], rgb[2], rgb[3], 1))
		end
		curve = c
	end)
	return curve or nil
end
A.DispelCurve = dispelCurve

-- A PATTERN FOR EACH TYPE, NOT ONLY A COLOUR (Josh 2026-09-23: "might help
-- colorblind people"). Blue for magic and purple for a curse are one colour
-- to a good many eyes, so the wash across the top of a cell also carries a
-- texture of its own, drawn rather than ruled (Josh 2026-09-23, "something a
-- bit more designed"): sparks for magic, smoke for a curse, bubbles for
-- poison, blotches and spores for disease, blood running down for a bleed.
-- 128-pixel tiles of ours in Art/Patterns, white, so each takes its type's
-- colour; made by a script from periodic noise, so every one tiles cleanly.
--
-- The client picks which to show without us reading the debuff: each pattern
-- is its own texture with its own curve, the type's colour at full strength
-- at that type's id and nothing - alpha nought - at every other, and the
-- client paints a dispel texture with SetVertexColor(curve colour:GetRGBA())
-- (Blizzard_CustomAuraButton.lua, ApplyCustomDispelTypeTextureColor). So only
-- the right one is ever visible. A map keyed by the type's name would not do:
-- the name is secret in a fight, and a secret key finds nothing.
A.PATTERN = {
	[1] = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\magic", [2] = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\curse", [3] = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\disease",
	[4] = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\poison", [11] = "Interface\\AddOns\\BeebMod\\Art\\Patterns\\bleed",
}
A.TYPE_ID = { Magic = 1, Curse = 2, Disease = 3, Poison = 4, Bleed = 11 }
A.PATTERN_ALPHA = 0.45

-- a curve that is the type's colour at its own id and clear everywhere else
local typeCurves = {}
local function typeCurve(id)
	if typeCurves[id] ~= nil then
		return typeCurves[id] or nil
	end
	typeCurves[id] = false
	pcall(function()
		local c = C_CurveUtil.CreateColorCurve()
		c:SetType(Enum.LuaCurveType.Step)
		local rgb = DISPEL[id] or { 1, 1, 1 }
		for x = 0, 12 do
			if x == id then
				c:AddPoint(x, CreateColor(rgb[1], rgb[2], rgb[3], 1))
			else
				c:AddPoint(x, CreateColor(0, 0, 0, 0))
			end
		end
		typeCurves[id] = c
	end)
	return typeCurves[id] or nil
end
A.TypeCurve = typeCurve

-- a texture that repeats its picture across whatever it covers
local function tiled(tex, path)
	tex:SetTexture(path, "REPEAT", "REPEAT")
	pcall(tex.SetHorizTile, tex, true)
	pcall(tex.SetVertTile, tex, true)
	return tex
end
A.Tiled = tiled

local function dispelOptions(helpful)
	local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	return {
		style = style and style.PreserveAsset or nil,
		showWhenHarmful = true,
		-- a boss's buff you could purge or soothe shows its type as well
		showWhenHelpful = helpful and true or nil,
		customDispelColorCurve = dispelCurve(),
	}
end

-- ---------------------------------------------------------------------------
-- Buttons: made by the client, dressed once, here
-- ---------------------------------------------------------------------------

-- An icon: black edge, the picture cropped of its own border, a sweep for its
-- time, its stacks, and the edge in its dispel colour when it has one.
-- noSweep: no clock face across the picture (the aura tray shows time as a bar)
local function iconButton(size, quiet, clickThrough, helpful, noSweep)
	return function(b)
		b:SetSize(size, size)
		-- ITS TOOLTIP (Josh 2026-09-23: "should be able to see tooltips if I
		-- mouse over auras on frames"). The client's button shows its aura's
		-- tooltip on its own when it hears the mouse; the icons on a cell were
		-- deaf to it, so a click would reach the cell. They hear the mouse now
		-- and pass it on: a click still goes to the cell, and so does the
		-- hover, so its highlight stays lit. On a cell the tooltip keeps out
		-- of a fight, where a healer's cursor is sweeping across the raid.
		pcall(b.SetMouseMotionEnabled, b, true)
		if clickThrough then
			pcall(b.SetMouseClickEnabled, b, false)
			pcall(b.SetPropagateMouseMotion, b, true)
			pcall(b.SetHideTooltipInCombat, b, true)
		end
		local edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
		edge:SetAllPoints()
		edge:SetColorTexture(0, 0, 0, 1)
		if not quiet and b.AddDispelTypeTexture then
			local ring = b:CreateTexture(nil, "BACKGROUND", nil, 1)
			ring:SetAllPoints()
			ring:SetColorTexture(1, 1, 1, 1)
			pcall(b.AddDispelTypeTexture, b, ring, dispelOptions(helpful))
		end
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if b.SetIcon then
			pcall(b.SetIcon, b, icon)
		end
		if not noSweep then
			local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
			cd:SetAllPoints(icon)
			pcall(cd.SetReverse, cd, true)
			pcall(cd.SetHideCountdownNumbers, cd, true)
			pcall(cd.SetDrawEdge, cd, false)
			if b.SetDurationCooldown then
				pcall(b.SetDurationCooldown, b, cd)
			end
		end
		local count = b:CreateFontString(nil, "OVERLAY")
		-- the face set here and not through Fonts.Set: a change of face
		-- writes a string's text again, and this string is the client's
		pcall(count.SetFont, count, BT.Fonts.Face("text") or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
			BT.Fonts.Size(math.max(8, math.floor(size * 0.55))), "OUTLINE")
		count:SetPoint("BOTTOMRIGHT", 2, -1)
		if b.SetApplicationCount then
			-- NO formatter: a secret count handed to one stops the container
			pcall(b.SetApplicationCount, b, count, {})
		end
	end
end
A.IconButton = iconButton

-- The dispel mark on a cell: the one button of a slot, laid over the whole
-- cell. Its textures are ours; the client shows them when there is a debuff
-- you can remove and colours them by its type. The wash sits on a frame of
-- our own at a quarter strength, because the colour the client paints is at
-- full strength and an alpha on the texture would be overwritten with it.
local function dispelButton(w, h)
	return function(b)
		b:SetSize(w, h)
		pcall(b.SetMouseClickEnabled, b, false)
		pcall(b.SetMouseMotionEnabled, b, false)
		local opts = dispelOptions()
		local T = 2
		local edges = {
			{ "TOPLEFT", "TOPRIGHT", nil, T }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, T },
			{ "TOPLEFT", "BOTTOMLEFT", T, nil }, { "TOPRIGHT", "BOTTOMRIGHT", T, nil },
		}
		for _, e in ipairs(edges) do
			local t = b:CreateTexture(nil, "OVERLAY")
			t:SetPoint(e[1], b, e[1], 0, 0)
			t:SetPoint(e[2], b, e[2], 0, 0)
			if e[3] then t:SetWidth(e[3]) end
			if e[4] then t:SetHeight(e[4]) end
			t:SetColorTexture(1, 1, 1, 1)
			if b.AddDispelTypeTexture then
				pcall(b.AddDispelTypeTexture, b, t, opts)
			end
		end
		local washHost = CreateFrame("Frame", nil, b)
		washHost:SetPoint("TOPLEFT", 0, 0)
		washHost:SetPoint("TOPRIGHT", 0, 0)
		washHost:SetHeight(math.floor(h * 0.45))
		washHost:SetAlpha(0.28)
		local wash = washHost:CreateTexture(nil, "ARTWORK")
		wash:SetAllPoints()
		wash:SetColorTexture(1, 1, 1, 1)
		if b.AddDispelTypeTexture then
			pcall(b.AddDispelTypeTexture, b, wash, opts)
		end
		-- and over the wash, the type's pattern: one texture a type, each
		-- clear unless the debuff is of its type
		local patternHost = CreateFrame("Frame", nil, b)
		patternHost:SetAllPoints(washHost)
		patternHost:SetAlpha(A.PATTERN_ALPHA)
		b.bmPatterns = {}
		local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
		for id, path in pairs(A.PATTERN) do
			local t = tiled(patternHost:CreateTexture(nil, "OVERLAY"), path)
			t:SetAllPoints()
			b.bmPatterns[id] = t
			if b.AddDispelTypeTexture then
				pcall(b.AddDispelTypeTexture, b, t, {
					style = style and style.PreserveAsset or nil,
					showWhenHarmful = true,
					customDispelColorCurve = typeCurve(id),
				})
			end
		end
	end
end
A.DispelButton = dispelButton

-- ---------------------------------------------------------------------------
-- Containers: on a holder of ours, out of combat
-- ---------------------------------------------------------------------------

local FLOW = function()
	return AnchorUtil and AnchorUtil.FlowDirection
end

-- One container, one group in it. A spec may bring its own button (init),
-- order (sort, direction), flow corner (flowAt, growLeft) and cell height
-- (cellH); the unit frames' rows use the defaults.
local function container(host, spec, unit)
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, host, "CustomAuraContainerTemplate")
	if not (ok and c and c.AddAuraGroup) then
		return nil
	end
	pcall(c.SetEditModePreviewEnabled, c, false)
	local dir = FLOW()
	local growLeft = spec.growLeft or spec.at == "BOTTOMRIGHT"
	if c.SetFlowLayoutAnchorPoint then
		pcall(c.SetFlowLayoutAnchorPoint, c, spec.flowAt or (spec.inside and spec.at) or "TOPLEFT")
	end
	if dir and c.SetFlowLayoutGrowthDirection then
		pcall(c.SetFlowLayoutGrowthDirection, c, growLeft and dir.Left or dir.Right,
			spec.inside and dir.Up or dir.Down)
	end
	if spec.perLine and c.SetFlowLayoutMaximumLineSize then
		pcall(c.SetFlowLayoutMaximumLineSize, c, spec.perLine * (spec.size + 2))
	end
	pcall(c.SetUnit, c, unit or "player")
	local sort = _G.AuraContainerSortMethod and _G.AuraContainerSortMethod.UnitFrameDebuff
	local ok2 = pcall(c.AddAuraGroup, c, spec.key, spec.filter, {
		maxFrameCount = spec.max,
		initializeFrame = spec.init or iconButton(spec.size, spec.quiet, spec.inside, spec.helpfulRing),
		candidateFilters = spec.candidate,
		sortMethod = spec.sort or (spec.filter:find("HARMFUL") and sort) or nil,
		sortDirection = spec.direction,
		layout = { elementSpacing = spec.spacing or (spec.inside and 1 or 2), lineSpacing = 2,
			elementWidth = spec.size, elementHeight = spec.cellH or spec.size },
	})
	if not ok2 then
		return nil
	end
	return c
end

A.Container = container

-- how far under the frame a row below it starts: under the combo row for a
-- class that has one, else just under the frame
--
-- AS FAR AS THE FRAME NEEDS (Josh 2026-09-24: "for an elite frame with a
-- border, it should be moved down a bit; for a plain frame, up more"). The
-- room for an elite's border was kept under every target, so a plain one had
-- its rows hanging well below it. Past the border when the frame wears one
-- (F.Room), just under the frame when it does not.
function A.Below(spec, b)
	if spec.below == "combo" then
		-- and past the combo row, for a class that has one
		local room = F.Room(b)
		return (F.UsesCombo and F.UsesCombo()) and (room + 4 + 3) or room
	end
	return spec.below or 3
end

-- The rows under a frame, put where its border says. The containers are the
-- client's and it will not have them moved in a fight: a target changed
-- then keeps the rows where they were until the fight is over.
local placing = setmetatable({}, { __mode = "k" })
local regen

local function afterFight()
	if not regen then
		regen = CreateFrame("Frame")
		regen:RegisterEvent("PLAYER_REGEN_ENABLED")
		regen:SetScript("OnEvent", function()
			A.Flush()
		end)
	end
end

-- a row under the frame: from its left edge, or from its right
local function anchorBelow(c, b, spec)
	c:ClearAllPoints()
	local y = -A.Below(spec, b)
	if spec.growLeft then
		c:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, y)
	else
		c:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, y)
	end
end

-- THE TARGET'S BUFFS, A CHOICE (Josh 2026-09-24): its row shown or not.
-- The client will not have a container switched in a fight; a change made
-- then waits for the end of it.
function A.TargetBuffs(b)
	local set = b and b.bmAuras
	local row = set and set.buffs
	if not (row and set.kind == "target") then
		return false
	end
	if inCombat() then
		placing[b] = true
		afterFight()
		return false
	end
	local on = F.Opt("targetBuffs", true) and true or false
	pcall(row.SetEnabled, row, on and not set.off)
	row:SetShown(on)
	return true
end

function A.Place(b)
	local set = b and b.bmAuras
	if not set then
		return false
	end
	if inCombat() then
		placing[b] = true
		afterFight()
		return false
	end
	placing[b] = nil
	A.TargetBuffs(b)
	for _, spec in ipairs(A.SPECS[set.kind] or {}) do
		local c = set[spec.key]
		if c and spec.at == "BELOW" then
			anchorBelow(c, b, spec)
		end
	end
	return true
end

-- Every aura row a button wears, made once while out of combat. `b` is a
-- dressed unit button, `kind` its kind.
function A.Attach(b, kind)
	local specs = A.SPECS[kind]
	if not specs or b.bmAuras or inCombat() then
		return b.bmAuras
	end
	if type(CreateFrame) ~= "function" then
		return nil
	end
	local host = CreateFrame("Frame", nil, b)
	host:SetAllPoints()
	host:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
	local set = { host = host, list = {}, kind = kind }
	local unit = b.bmUnit
	for _, spec in ipairs(specs) do
		local c = container(host, spec, unit)
		if c then
			c:ClearAllPoints()
			if spec.inside then
				local x = spec.at == "BOTTOMLEFT" and 3 or -3
				c:SetPoint(spec.at, b.health, spec.at, x, 3)
			elseif spec.at == "BELOW" then
				anchorBelow(c, b, spec)
			else
				-- past the right-hand corners of a border the frame may wear
				c:SetPoint("TOPLEFT", b, "TOPRIGHT", F.RANK_ROOM + 2, 0)
			end
			set.list[#set.list + 1] = c
			set[spec.key] = c
		end
	end
	-- the dispel mark: a slot in the debuff container, laid over the cell
	if specs.dispel and set.debuffs and set.debuffs.AddAuraSlot then
		local w, h = b.bmSpec.w, b.bmSpec.h
		local ok, slot = pcall(set.debuffs.AddAuraSlot, set.debuffs, "dispel", "HARMFUL|RAID", {
			initializeFrame = dispelButton(w, h),
		})
		if ok and type(slot) == "table" and slot.SetPoint then
			slot:ClearAllPoints()
			slot:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
			slot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
			set.dispel = slot
		end
	end
	-- your heals and damage over time, a bar a spell along the top (Timers.lua)
	b.bmAuras = set
	if F.Timers then
		F.Timers.Attach(b)
	end
	-- NOBODY'S UNTIL IT HAS SOMEBODY (Josh 2026-09-23, audit): a raid cell is
	-- made before the group gives it a member, and its rows stood on "player"
	-- meanwhile - forty cells' worth of your own auras, read and laid out
	-- behind frames nobody could see, or on one that showed before its unit
	-- arrived. Off until F.Bind hands it one.
	set.unit = unit
	set.off = unit == nil
	for _, c in ipairs(set.list) do
		pcall(c.SetEnabled, c, not set.off)
	end
	b.bmAuras = set
	if kind == "target" then
		A.TargetBuffs(b)
	end
	return set
end

-- The containers' unit follows the button's. Out of combat it is written and
-- the holder bounced, so the client reads the new unit at once; in a fight it
-- waits for the fight to end (a party reshuffling mid-pull is rare, and a
-- single frame's unit never changes - "target" is always "target").
local waiting = setmetatable({}, { __mode = "k" })

function A.SetUnit(b, unit)
	local set = b.bmAuras
	if not (set and unit) then
		return
	end
	if set.unit == unit then
		return
	end
	if inCombat() then
		waiting[b] = unit
		afterFight()
		return
	end
	set.unit = unit
	for _, c in ipairs(set.list) do
		pcall(c.SetUnit, c, unit)
		if set.off then
			pcall(c.SetEnabled, c, true)
		end
	end
	set.off = false
	A.Refresh(b)
end

-- the units that changed in a fight, written now it is over, and the rows
-- that wanted moving
function A.Flush()
	for button, u in pairs(waiting) do
		waiting[button] = nil
		A.SetUnit(button, u)
	end
	for button in pairs(placing) do
		A.Place(button)
	end
end

-- A new target or focus: the same token, somebody else. Hiding and showing
-- the holder has the client read the auras again from its own side, which it
-- will do in a fight as well - the holder is a plain frame of ours.
function A.Refresh(b)
	local set = b and b.bmAuras
	if not set then
		return false
	end
	set.host:Hide()
	set.host:Show()
	return true
end

-- ---------------------------------------------------------------------------
-- Made-up auras, for the previews
-- ---------------------------------------------------------------------------
--
-- A PREVIEW DRAWS ITS OWN (Josh 2026-09-23). A container reads a real unit,
-- and the Testing page's made-up people are not real; so a preview's auras are
-- plain frames of ours laid out exactly as the containers lay theirs - the
-- same rows, sizes, black edges, dispel colours and stack counts - with the
-- real spells' pictures. The dispel mark is shown on a preview whatever your
-- class can remove, so there is something to look at.

-- the client's own colours for a debuff's type, by name, for the made-up ones
A.TYPE_COLOUR = {
	Magic = DISPEL[1], Curse = DISPEL[2], Disease = DISPEL[3], Poison = DISPEL[4], Bleed = DISPEL[11],
	Enrage = DISPEL[9],
}

local QUESTION = 134400

local function spellIcon(id)
	if type(id) ~= "number" then
		return QUESTION
	end
	local ok, tex
	if C_Spell and C_Spell.GetSpellTexture then
		ok, tex = pcall(C_Spell.GetSpellTexture, id)
	elseif GetSpellTexture then
		ok, tex = pcall(GetSpellTexture, id)
	end
	if ok and (type(tex) == "number" or type(tex) == "string") then
		return tex
	end
	return QUESTION
end
A.SpellIcon = spellIcon

-- one made-up icon, dressed as iconButton dresses the client's
local function fakeIcon(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.edge = f:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.edge:SetAllPoints()
	f.edge:SetColorTexture(0, 0, 0, 1)
	f.ring = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.ring:SetAllPoints()
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.count = f:CreateFontString(nil, "OVERLAY")
	pcall(f.count.SetFont, f.count, BT.Fonts.Face("text") or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
		BT.Fonts.Size(math.max(8, math.floor(size * 0.55))), "OUTLINE")
	f.count:SetPoint("BOTTOMRIGHT", 2, -1)
	-- a tooltip on the made-up ones too, the spell's own; the click and the
	-- drag go through to the frame under it, as on the client's buttons
	pcall(f.EnableMouseMotion, f, true)
	pcall(f.SetMouseClickEnabled, f, false)
	pcall(f.SetPropagateMouseMotion, f, true)
	f:SetScript("OnEnter", function(self)
		if not (GameTooltip and self.spell) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		local ok = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell)
		if not ok and GameTooltip.SetText then
			GameTooltip:SetText(tostring(self.spell))
		end
		GameTooltip:Show()
		A.tipFor = self
	end)
	f:SetScript("OnLeave", function(self)
		if GameTooltip and A.tipFor == self then
			GameTooltip:Hide()
			A.tipFor = nil
		end
	end)
	return f
end

A.FakeIcon = fakeIcon

-- where the n-th icon of a row goes, the way the container's flow lays it
local function placeIcon(f, b, spec, n)
	local gap = spec.inside and 1 or 2
	local step = spec.size + gap
	local per = spec.perLine or spec.max
	local col, line = (n - 1) % per, math.floor((n - 1) / per)
	f:ClearAllPoints()
	if spec.inside then
		local x = spec.at == "BOTTOMLEFT" and (3 + col * step) or -(3 + col * step)
		f:SetPoint(spec.at, b.health, spec.at, x, 3 + line * step)
	elseif spec.at == "BELOW" then
		local y = -A.Below(spec, b) - line * (spec.size + 2)
		if spec.growLeft then
			f:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -col * step, y)
		else
			f:SetPoint("TOPLEFT", b, "BOTTOMLEFT", col * step, y)
		end
	else
		f:SetPoint("TOPLEFT", b, "TOPRIGHT", F.RANK_ROOM + 2 + col * step, -line * (spec.size + 2))
	end
end

-- The dispel mark, as the client paints it: a border inside the cell and a
-- wash across the top, in the colour of the debuff's type.
local function fakeDispel(b, colour, typeName)
	local m = b.bmFakeDispel
	if not m then
		m = CreateFrame("Frame", nil, b)
		m:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		m:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
		m.edges = {}
		for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
			{ "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
			local t = m:CreateTexture(nil, "OVERLAY")
			t:SetPoint(e[1], m, e[1], 0, 0)
			t:SetPoint(e[2], m, e[2], 0, 0)
			if e[3] then t:SetWidth(e[3]) end
			if e[4] then t:SetHeight(e[4]) end
			m.edges[i] = t
		end
		m.wash = m:CreateTexture(nil, "ARTWORK")
		m.wash:SetPoint("TOPLEFT", 0, 0)
		m.wash:SetPoint("TOPRIGHT", 0, 0)
		m.wash:SetHeight(math.floor(b.bmSpec.h * 0.45))
		m.pattern = m:CreateTexture(nil, "OVERLAY")
		m.pattern:SetAllPoints(m.wash)
		b.bmFakeDispel = m
	end
	for _, t in ipairs(m.edges) do
		t:SetColorTexture(colour[1], colour[2], colour[3], 1)
	end
	m.wash:SetColorTexture(colour[1], colour[2], colour[3], 0.28)
	local path = A.PATTERN[A.TYPE_ID[typeName or ""] or -1]
	if path then
		tiled(m.pattern, path)
		m.pattern:SetVertexColor(colour[1], colour[2], colour[3], A.PATTERN_ALPHA)
		m.pattern:Show()
	else
		m.pattern:Hide()
	end
	m.colour, m.pattern.path = colour, path
	m:Show()
	return m
end

-- A preview's auras: `data` holds a list per row key - { spell = id,
-- type = "Magic", count = 3 } - and `dispel`, the type of a debuff you could
-- remove. Rows the kind does not have are ignored.
function A.Show(b, kind, data)
	local specs = A.SPECS[kind]
	if not (specs and data) then
		return 0
	end
	b.bmFakeAuras = b.bmFakeAuras or {}
	local shown = 0
	for _, spec in ipairs(specs) do
		local list = data[spec.key] or {}
		local icons = b.bmFakeAuras[spec.key] or {}
		b.bmFakeAuras[spec.key] = icons
		for n = 1, math.min(#list, spec.max) do
			local a = list[n]
			local f = icons[n] or fakeIcon(b, spec.size)
			icons[n] = f
			f:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
			f.icon:SetTexture(spellIcon(a.spell))
			local c = A.TYPE_COLOUR[a.type or ""]
			if c and not spec.quiet and (spec.filter:find("HARMFUL") or spec.helpfulRing) then
				f.ring:SetColorTexture(c[1], c[2], c[3], 1)
				f.ring:Show()
			else
				f.ring:Hide()
			end
			f.count:SetText((a.count and a.count > 1) and tostring(a.count) or "")
			f.spell, f.type = a.spell, a.type
			placeIcon(f, b, spec, n)
			f:Show()
			shown = shown + 1
		end
		for n = math.min(#list, spec.max) + 1, #icons do
			icons[n]:Hide()
		end
	end
	if specs.dispel and data.dispel and A.TYPE_COLOUR[data.dispel] then
		fakeDispel(b, A.TYPE_COLOUR[data.dispel], data.dispel)
	elseif b.bmFakeDispel then
		b.bmFakeDispel:Hide()
	end
	return shown
end
