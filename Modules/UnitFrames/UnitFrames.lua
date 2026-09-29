-- Unit frames: every one of them, in the toolkit's clothes (Josh 2026-09-23).
--
-- Style A, in the corners: the player top left and the target beside it, the
-- target of target under the target, the pet and the focus under the player,
-- the party or the raid down the left side, the bosses to the left of the
-- dock. Class-coloured health on the toolkit's fill, no portraits, and next to
-- nothing to set: this is an opinion about unit frames, not a kit for making
-- them.
--
-- THE CLIENT'S OWN FRAMES ARE PUT AWAY, not dressed: given a parent that is
-- never shown, out of combat, because they are protected. They go on working
-- out of sight, so switching ours off - the whole module, or the switch for
-- one kind - moves them back and they are there as they were (M.STANDS_FOR).
--
-- THE GROUPS USE NO SNIPPETS. The client's secure snippets do not compile on
-- this build (forever-bugs #74, and the unit probe says so), and a group
-- header that is handed one fails. So each header is given attributes only,
-- makes its buttons from SecureUnitButtonTemplate, and they are dressed from
-- here - all of them at once while out of combat, so a player who joins in
-- the middle of a fight lands on a button that is already dressed.
--
-- AURAS ARE THE CLIENT'S TO DRAW. It will not let an addon read one in combat
-- at all (the second probe: "Auras cannot be accessed when secret while
-- tainted by 'BeebMod'"), so the debuff squares and dispel borders are its
-- aura containers, described and placed by Modules/UnitFrames/Auras.lua.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/UnitFrames/UnitFrames.lua")

local U = BT.Util
local F = BT.UnitFrames
local unpack = unpack or table.unpack

local M = BT.Module({
	key = "unitframes",
	feature = "unitframes",
	title = "Unit frames",
	blurb = "Frames for you, your group, the raid, your target, focus and bosses",
	order = 45,
})

local function opt(name, fallback)
	local s = BT.settings and BT.settings.unitframes
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.unitframes = BT.settings.unitframes or {}
	BT.settings.unitframes[name] = value
	M.Apply()
	-- the made-up people show what the switches show: redrawn on a change
	if M.previewing then
		M.Preview(M.previewing)
	end
end
M.SetOpt = setOpt

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- work that has to wait for the end of a fight, done once when it ends
--
-- DRAINED WHETHER OR NOT THE FRAMES ARE ON (Josh 2026-09-23, audit). The queue
-- used to be emptied by the module's own event handler, which steps aside
-- while the module is off - so switching the frames off in a fight queued the
-- "off" and nothing ever ran it (ours stayed up, the game's stayed away), and
-- a later switch back on left that stale "off" to fire after the next fight.
-- It has a frame of its own now, made as the file loads, and switching on
-- cancels a waiting "off" and the other way about.
local pending = {}
local function later(key, fn)
	if not inCombat() then
		fn()
		return true
	end
	pending[key] = fn
	return false
end
M.Pending = function() return pending end

local drain = CreateFrame("Frame")
pcall(drain.RegisterEvent, drain, "PLAYER_REGEN_ENABLED")
drain:SetScript("OnEvent", function()
	local todo = pending
	pending = {}
	for _, fn in pairs(todo) do
		pcall(fn)
	end
end)
M.drain = drain

-- ---------------------------------------------------------------------------
-- Where the blocks sit, and moving them
-- ---------------------------------------------------------------------------
--
-- SHIFT-DRAG TO MOVE (Josh 2026-09-23: "I tend to make location adjustments
-- based on the size of the raid"). The party, the raid and the bosses each
-- hang off a holder of their own - an invisible frame the size of the block -
-- and a shift-drag on any frame in the block moves the holder and everything
-- on it. Out of combat only: the headers and the boss frames are secure, and a
-- secure frame's anchor cannot move in a fight. Where each one is left is a
-- setting, written the way the dock writes its own: a TOPLEFT against the
-- screen, so a block that grows only ever grows downwards.

local RAID_W, RAID_H, RAID_GAP = F.KINDS.raid.w, F.KINDS.raid.h, 3
local GROUP_TOP = -190

local HOLDERS = {
	-- YOU ARE THE TOP OF THE PARTY (Josh 2026-09-23): the party column starts
	-- in the corner the player frame had, and is there alone as well
	party = { w = F.KINDS.party.w + 4 + F.KINDS.gtarget.w, h = 5 * (F.KINDS.party.h + 24),
		at = { "TOPLEFT", "TOPLEFT", 24, -24 } },
	raid = { w = 8 * (RAID_W + RAID_GAP), h = 5 * (RAID_H + 2), at = { "TOPLEFT", "TOPLEFT", 24, GROUP_TOP } },
	boss = { w = F.KINDS.boss.w, h = 5 * (F.KINDS.boss.h + 44), at = { "TOPRIGHT", "TOPRIGHT", -250, -300 } },
	-- THE MAIN TANKS, ON TOP OF THE RAID (Josh 2026-09-23: "place them above
	-- the raid frames on the left, so they aren't in the middle of the
	-- screen"). They stand on the raid's top edge, at its left, and go where
	-- it goes - until they are dragged somewhere of their own, which is then
	-- kept. The column grows upward from there (see buildGroups).
	tanks = { w = F.KINDS.tank.w + 4 + F.KINDS.gtarget.w, h = 5 * (F.KINDS.tank.h + 4),
		follow = "raid", at = { "BOTTOMLEFT", "TOPLEFT", 0, 14 } },
	-- your own cast bar, under the resource display
	cast = { w = 200, h = 18, at = { "BOTTOM", "BOTTOM", 0, 300 } },
}
M.holders = {}

local function holder(key)
	local h = M.holders[key]
	if h then
		return h
	end
	local spec = HOLDERS[key]
	h = CreateFrame("Frame", "BeebModHolder_" .. key, UIParent)
	h:SetSize(spec.w, spec.h)
	h:SetMovable(true)
	h:SetClampedToScreen(true)
	h.key = key
	-- the block's outline, shown while it is being moved and never otherwise
	h.ghost = CreateFrame("Frame", nil, h)
	h.ghost:SetAllPoints()
	h.ghost:SetFrameStrata("HIGH")
	h.ghost.fill = h.ghost:CreateTexture(nil, "BACKGROUND")
	h.ghost.fill:SetAllPoints()
	h.ghost.ring = BT.Pill.Ring(h.ghost, "OVERLAY", 1)
	BT.Pill.PlaceRing(h.ghost.ring, h.ghost, 0, 1, 0)
	h.ghost.label = h.ghost:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	h.ghost.label:SetPoint("BOTTOMLEFT", h.ghost, "TOPLEFT", 2, 3)
	h.ghost.label:SetText(({ boss = "Bosses", raid = "Raid", party = "Party", tanks = "Main tanks",
		cast = "Cast bar" })[key] or key)
	h.ghost:Hide()
	M.holders[key] = h
	return h
end
M.Holder = holder

-- where a holder was left, or where it starts
function M.PlaceHolder(key)
	local h = holder(key)
	local saved = opt("pos", {})[key]
	local at = (type(saved) == "table" and saved.point) and { saved.point, saved.rel or saved.point, saved.x or 0, saved.y or 0 }
		or HOLDERS[key].at
	h:ClearAllPoints()
	local follow = not (type(saved) == "table" and saved.point) and HOLDERS[key].follow
	h:SetPoint(at[1], follow and M.PlaceHolder(follow) or UIParent, at[2], at[3], at[4])
	return h
end

local function savePlace(h)
	local num = BT.Pill.Number
	local left, top = num(h:GetLeft(), nil), num(h:GetTop(), nil)
	local parentTop = num(UIParent:GetTop(), nil)
	if not (left and top and parentTop) then
		return false
	end
	BT.EnsureBound()
	BT.settings.unitframes = BT.settings.unitframes or {}
	BT.settings.unitframes.pos = BT.settings.unitframes.pos or {}
	BT.settings.unitframes.pos[h.key] = { point = "TOPLEFT", rel = "TOPLEFT", x = math.floor(left + 0.5),
		y = math.floor(top - parentTop + 0.5) }
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", UIParent, "TOPLEFT", BT.settings.unitframes.pos[h.key].x, BT.settings.unitframes.pos[h.key].y)
	return true
end

-- A frame in a block, made into a handle for it. Only with shift held, so a
-- plain drag off a raid frame still does whatever a drag did before.
function M.Handle(f, key)
	-- only the blocks that move: a made-up target, say, is not one of them
	-- (it named itself as the block to move and the drag found no holder)
	if f.bmHandle or not HOLDERS[key] then
		return f
	end
	if inCombat() then
		return f
	end
	f.bmHandle = key
	f:RegisterForDrag("LeftButton")
	f:HookScript("OnDragStart", function(self)
		if not (IsShiftKeyDown and IsShiftKeyDown()) then
			return
		end
		if inCombat() then
			U.Print("Unit frames: you can't move frames in a fight. Move them when it's over.")
			return
		end
		local h = holder(self.bmHandle)
		local a = BT.Widgets.ACCENT
		h.ghost.fill:SetColorTexture(a[1], a[2], a[3], 0.10)
		BT.Pill.PaintRing(h.ghost.ring, { a[1], a[2], a[3], 0.9 })
		h.ghost:Show()
		h.moving = true
		h:StartMoving()
	end)
	f:HookScript("OnDragStop", function(self)
		local h = holder(self.bmHandle)
		if not h.moving then
			return
		end
		h.moving = false
		h:StopMovingOrSizing()
		h.ghost:Hide()
		savePlace(h)
	end)
	return f
end

-- every block back where it started
function M.ResetPlaces()
	BT.EnsureBound()
	if BT.settings.unitframes then
		BT.settings.unitframes.pos = nil
	end
	return later("places", function()
		for key in pairs(HOLDERS) do
			M.PlaceHolder(key)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- The singles
-- ---------------------------------------------------------------------------

M.singles = {}
local GAP = 18

-- Where each one sits: the corners, as the client's own frames did.
-- NO PLAYER FRAME (Josh 2026-09-23: "we should just always use the group
-- frames there, with the player always on top"). Solo or in a party, the party
-- column is shown with you at the top of it - your pet under you, your target
-- beside you - so your frame and your party's can never look different. In a
-- raid you are in your group's column like everybody else. The target sits
-- to the right of the party column and its targets, where the eye goes next.
M.TARGET_X = 24 + F.KINDS.party.w + 4 + F.KINDS.gtarget.w + GAP
-- room under a boss for its cast bar (10 and 14), and over the next one for
-- four of your damage-over-time lanes (Timers.lua: 4 of 5, a pixel apart)
M.BOSS_GAP = 50
-- the column beside the target: this far from it, and this far between the
-- target of target and the focus - which makes the two as tall as the target
-- (room for an elite's ornate border between the target and the column)
M.COLUMN_GAP = GAP
M.STACK_GAP = F.KINDS.target.h - F.KINDS.tot.h - F.KINDS.focus.h

local function place(key, f)
	f:ClearAllPoints()
	local s = M.singles
	if key == "target" then
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", M.TARGET_X, -24)
	-- A COLUMN BESIDE THE TARGET (Josh 2026-09-23): its target at the top,
	-- level with it, and the focus under that - the two together as tall as
	-- the target, so the three read as one block. The target's debuffs moved
	-- underneath it to make the room (Modules/UnitFrames/Auras.lua).
	elseif key == "targettarget" then
		f:SetPoint("TOPLEFT", s.target, "TOPRIGHT", M.COLUMN_GAP, 0)
	elseif key == "focus" then
		f:SetPoint("TOPLEFT", s.targettarget, "BOTTOMLEFT", 0, -M.STACK_GAP)
	elseif key:find("^boss") then
		local n = tonumber(key:match("%d+")) or 1
		if n == 1 then
			f:SetPoint("TOPLEFT", holder("boss"), "TOPLEFT", 0, 0)
		else
			-- a boss's cast bar and the border's corners under it, and the
			-- next boss's crest above it
			f:SetPoint("TOPLEFT", s["boss" .. (n - 1)], "BOTTOMLEFT", 0, -M.BOSS_GAP)
		end
	end
end

local SINGLES = {
	{ "target", "target" }, { "targettarget", "tot" }, { "focus", "focus" }, { "boss1", "boss" }, { "boss2", "boss" }, { "boss3", "boss" },
	{ "boss4", "boss" }, { "boss5", "boss" },
}

local function buildSingles()
	for _, pair in ipairs(SINGLES) do
		local unit, kind = pair[1], pair[2]
		local f = M.singles[unit]
		if not f then
			f = F.Build(UIParent, kind, "BeebModUnit_" .. unit, true)
			f.bmOwnsUnit = true
			F.Clicks(f)
			M.singles[unit] = f
		end
	end
	for key in pairs(HOLDERS) do
		M.PlaceHolder(key)
	end
	for _, pair in ipairs(SINGLES) do
		place(pair[1], M.singles[pair[1]])
		if pair[2] == "boss" then
			M.Handle(M.singles[pair[1]], "boss")
		end
	end
end

-- shown by the client while the unit exists: a secure frame cannot be shown
-- or hidden from here in a fight, and RegisterUnitWatch does it in the client
local function watch(unit, on)
	local f = M.singles[unit]
	if not f then
		return
	end
	if on then
		-- the aura rows first, so the bind below points them at the unit
		if F.Auras then
			F.Auras.Attach(f, f.bmKind)
		end
		F.Bind(f, unit)
		if unit ~= "player" and RegisterUnitWatch then
			RegisterUnitWatch(f)
		else
			f:Show()
		end
	else
		if UnregisterUnitWatch then
			UnregisterUnitWatch(f)
		end
		f:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- The groups
-- ---------------------------------------------------------------------------

M.headers = {}

-- a header, given attributes and nothing else
local function header(name, kind, attrs)
	local h = CreateFrame("Frame", name, UIParent, "SecureGroupHeaderTemplate")
	h.bmKind = kind
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("point", "TOP")
	h:SetAttribute("unitsPerColumn", 5)
	h:SetAttribute("maxColumns", 1)
	for k, v in pairs(attrs) do
		h:SetAttribute(k, v)
	end
	return h
end

-- A PET AND A TARGET FOR EVERY MEMBER (Josh 2026-09-23). The pet's room is
-- kept whether there is a pet or not, so the party is evenly spaced and a
-- temporary pet does not shove everyone down; the target sits beside the
-- member, a bar and a name, which is how you see who is hitting the wrong
-- thing. Both are secure buttons parented to the member's, told to use its
-- unit plus a suffix - "party2" and "pet" is "partypet2" - so the client's
-- own code clicks and shows them, in a fight and through a reshuffle, with
-- no snippet. The client's show-and-hide for a unit (RegisterUnitWatch)
-- reads the unit the same way.
local PET_GAP, PET_H = 2, F.KINDS.gpet.h
M.PARTY_STEP = PET_GAP + PET_H + 6

function M.Minis(child, noPet)
	if child.bmTarget or inCombat() then
		return child
	end
	local minis = {}
	local pet
	if not noPet then
		pet = F.Build(child, "gpet", nil, true)
		pet:SetPoint("TOPRIGHT", child, "BOTTOMRIGHT", 0, -PET_GAP)
		minis[pet] = "pet"
	end
	local target = F.Build(child, "gtarget", nil, true)
	target:SetPoint("TOPLEFT", child, "TOPRIGHT", 4, 0)
	minis[target] = "target"
	for mini, suffix in pairs(minis) do
		mini:SetAttribute("useparent-unit", true)
		mini:SetAttribute("unitsuffix", suffix)
		F.Clicks(mini)
		if RegisterUnitWatch then
			RegisterUnitWatch(mini)
		end
		mini.bmWatched = true
	end
	child.bmPet, child.bmTarget = pet, target
	return child
end

-- NOT YOUR OWN TARGET (Josh 2026-09-23: "redundant since we have a separate
-- target frame"). Everybody else's target beside them says who is on what;
-- yours is the target frame. The party puts you first and keeps you there -
-- the header sorts by index and you are index nought - so the cell that is
-- yours does not change in a fight, and its target is simply not shown,
-- set out of combat whenever the cells are sorted. Your pet stays.
function M.SyncMinis(child)
	local target = child.bmTarget
	if not target or inCombat() then
		return
	end
	local want = child.bmUnit ~= nil and child.bmUnit ~= "player"
	if want and not target.bmWatched then
		if RegisterUnitWatch then
			RegisterUnitWatch(target)
		end
		target.bmWatched = true
	elseif not want and target.bmWatched then
		if UnregisterUnitWatch then
			UnregisterUnitWatch(target)
		end
		target.bmWatched = false
		target:Hide()
	end
end

-- every button a header has made, dressed and listening to its unit
function M.Sweep()
	if inCombat() then
		pending.sweep = M.Sweep
		return 0
	end
	local n = 0
	for _, h in ipairs(M.headers) do
		local kids = { h:GetChildren() }
		local changed = false
		for _, child in ipairs(kids) do
			if type(child) == "table" and child.GetAttribute and not child.bmDressed then
				F.Dress(child, h.bmKind)
				F.Clicks(child)
				if F.Auras then
					F.Auras.Attach(child, h.bmKind)
				end
				if h.bmRole == "party" then
					M.Minis(child)
				elseif h.bmRole == "tanks" then
					-- a tank's target, and no pet: who is on what is the point
					M.Minis(child, true)
				end
				M.Handle(child, h.bmRole)
				child:HookScript("OnAttributeChanged", function(self, name, value)
					if name == "unit" then
						F.Bind(self, value)
						M.SyncMinis(self)
					end
				end)
				changed = true
				n = n + 1
			end
			if type(child) == "table" and child.bmDressed then
				local unit = child:GetAttribute("unit")
				if unit ~= child.bmUnit then
					F.Bind(child, unit)
				elseif unit then
					F.Paint(child, F.Source(unit))
				end
				M.SyncMinis(child)
			end
		end
		-- a button that was sized after the header placed it: place them again
		if changed then
			h:SetAttribute("bmSized", n)
		end
	end
	return n
end

-- THE GROUPS, PACKED (Josh 2026-09-23: "arranging the raid groups by the
-- actual number group they belong to. We can skip rendering completely empty
-- groups though"). Each column is a header for one group number, so a member
-- is always in their own group's column and the columns stay in group order;
-- a group with nobody in it gives up its column, and the ones after it close
-- up. Groups 1 and 2 full and one member in 7: three columns, the third
-- being group 7. Read from the roster, and moved out of combat only - the
-- headers are secure. A roster that cannot be read leaves every group its
-- own column, as before.
M.RAID_STEP = RAID_W + RAID_GAP

function M.Occupied()
	if not (IsInRaid and IsInRaid()) then
		return nil
	end
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if type(n) ~= "number" or (issecretvalue and issecretvalue(n)) then
		return nil
	end
	local used = {}
	for i = 1, n do
		local ok, _, _, sub = pcall(GetRaidRosterInfo, i)
		if not ok or type(sub) ~= "number" or (issecretvalue and issecretvalue(sub)) then
			return nil
		end
		used[sub] = true
	end
	return used
end

-- where the columns go, given which groups are in use (nil: all of them);
-- returns the column each group gets and how many columns there are
function M.Columns(used)
	local at, n = {}, 0
	for g = 1, 8 do
		at[g] = n
		if not used or used[g] then
			n = n + 1
		end
	end
	return at, n
end

function M.PackRaid()
	return later("pack", function()
		local at, n = M.Columns(M.Occupied())
		for _, h in ipairs(M.headers) do
			local g = h.bmRole == "raid" and tonumber(h:GetAttribute("groupFilter"))
			if g then
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", holder("raid"), "TOPLEFT", at[g] * M.RAID_STEP, 0)
			end
		end
		-- the block, as wide as what is in it, for the outline while moving it
		holder("raid"):SetWidth(math.max(1, n) * M.RAID_STEP)
	end)
end

local function buildGroups()
	if #M.headers > 0 then
		return
	end
	local party = header("BeebModParty", "party", {
		showParty = true, showPlayer = true, showRaid = false, showSolo = true, yOffset = -M.PARTY_STEP,
	})
	party:SetPoint("TOPLEFT", holder("party"), "TOPLEFT", 0, 0)
	party.bmRole = "party"
	M.headers[#M.headers + 1] = party
	-- the raid: a column per group, side by side, groups in order
	for g = 1, 8 do
		local h = header("BeebModRaid" .. g, "raid", {
			showRaid = true, showParty = false, showPlayer = true, groupFilter = tostring(g), yOffset = -2,
		})
		h.bmRole = "raid"
		M.headers[#M.headers + 1] = h
	end
	M.PackRaid()
	-- THE MAIN TANKS (Josh 2026-09-23): whoever the raid has marked as main
	-- tank, in a column above the raid, each with its target - the raid's
	-- own roleFilter, so the client keeps the list
	-- The column grows up from the raid, so the first tank is listed last:
	-- the first is still at the top, and the last is nearest the raid.
	local tanks = header("BeebModTanks", "tank", {
		showRaid = true, showParty = false, showPlayer = true, roleFilter = "MAINTANK",
		point = "BOTTOM", yOffset = 4, sortDir = "DESC",
	})
	tanks:SetPoint("BOTTOMLEFT", holder("tanks"), "BOTTOMLEFT", 0, 0)
	tanks.bmRole = "tanks"
	M.headers[#M.headers + 1] = tanks
	-- MAKE THEM ALL NOW (the startingIndex trick): a header only makes a
	-- button when there is a unit to put in it, and one made in a fight cannot
	-- be sized. Asked to start five before the first, it makes all of them.
	for _, h in ipairs(M.headers) do
		pcall(function()
			h:SetAttribute("startingIndex", -4)
			h:Show()
			h:SetAttribute("startingIndex", 1)
			h:Hide()
		end)
	end
	M.Sweep()
end

-- which headers show when, handed to the client: [group:raid] and friends are
-- conditions the client resolves itself, in or out of a fight
local function drive(h, on)
	if not RegisterStateDriver then
		h:SetShown(on)
		return
	end
	if on then
		RegisterStateDriver(h, "visibility", (h.bmRole == "raid" or h.bmRole == "tanks") and "[group:raid] show; hide"
			or "[group:raid] hide; show")
	else
		if UnregisterStateDriver then
			UnregisterStateDriver(h, "visibility")
		end
		h:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- The client's own, put away
-- ---------------------------------------------------------------------------

-- WHICH OF THE GAME'S FRAMES EACH OF OURS STANDS IN FOR (Josh 2026-09-23:
-- "Disabling unit frames (or the sub options) should restore the default
-- blizzard version"). The target, its target and the focus go while unit
-- frames are on at all; the rest go with the switch that puts ours in their
-- place - the party column has you and your pet in it, so the game's player
-- and pet frames go with Party. Switched off, the game's own come back.
-- (The combo points go with the target: the game's ComboFrame hangs by the
-- target frame but is not inside it, so it stayed up on its own beside ours -
-- Josh 2026-09-24. Ours are the row under the target.)
M.STANDS_FOR = {
	{ names = { "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT", "ComboFrame",
		"ComboPointPlayerFrame" } },
	{ switch = "party", names = { "PlayerFrame", "PetFrame", "PartyFrame", "CompactPartyFrame" } },
	{ switch = "boss", names = { "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame",
		"Boss4TargetFrame", "Boss5TargetFrame" } },
	{ switch = "raid", names = { "CompactRaidFrameManager", "CompactRaidFrameContainer" } },
	{ switch = "cast", names = { "PlayerCastingBarFrame", "CastingBarFrame" } },
}

-- PUT AWAY, NOT TAKEN APART (Josh 2026-09-23). A frame of the game's used to
-- be unregistered from everything and hidden, which could not be undone
-- short of a /reload. Now it is only moved under a parent that is never
-- shown: it goes on hearing its events and keeping itself up to date, out of
-- sight, and moving it back under its own parent is all it takes to have it
-- back as it was. Protected ones are moved out of combat only.
local hider

function F.Stow(name)
	local f = _G[name]
	if type(f) ~= "table" or not f.SetParent or f.bmStowed then
		return false
	end
	hider = hider or CreateFrame("Frame")
	hider:Hide()
	local okP, home = pcall(f.GetParent, f)
	f.bmHome = (okP and home ~= hider) and home or UIParent
	pcall(f.SetParent, f, hider)
	-- only once it is there: a move the client refused (a protected frame,
	-- in a fight) is not a stow, and is tried again next time
	local okN, now = pcall(f.GetParent, f)
	if not (okN and now == hider) then
		return false
	end
	f.bmStowed = true
	-- the client puts some of them back under UIParent (Edit Mode does): back
	-- under the hider they go while they are meant to be away, when it is safe
	if hooksecurefunc and not f.bmHooked then
		f.bmHooked = true
		hooksecurefunc(f, "SetParent", function(self, parent)
			if self.bmStowed and parent ~= hider then
				later("restow" .. name, function()
					if self.bmStowed then
						pcall(self.SetParent, self, hider)
					end
				end)
			end
		end)
	end
	return true
end

function F.Unstow(name)
	local f = _G[name]
	if type(f) ~= "table" or not f.bmStowed then
		return false
	end
	f.bmStowed = false
	pcall(f.SetParent, f, f.bmHome or UIParent)
	return true
end

-- every one of the game's frames away or back, as the switches say; how many
-- were put away and how many brought back
function M.Stow()
	local away, back = 0, 0
	for _, group in ipairs(M.STANDS_FOR) do
		local on = M.live and (group.switch == nil or opt(group.switch, true))
		for _, name in ipairs(group.names) do
			if on then
				away = away + (F.Stow(name) and 1 or 0)
			else
				back = back + (F.Unstow(name) and 1 or 0)
			end
		end
	end
	return away, back
end

-- ---------------------------------------------------------------------------
-- Keeping them current
-- ---------------------------------------------------------------------------

function M.PaintAll()
	for unit, f in pairs(M.singles) do
		if f:IsShown() or unit == "targettarget" then
			F.Paint(f, F.Source(unit))
		end
	end
	for _, h in ipairs(M.headers) do
		for _, child in ipairs({ h:GetChildren() }) do
			if type(child) == "table" and child.bmUnit then
				F.Paint(child, F.Source(child.bmUnit))
			end
		end
	end
end

-- THE MASTER LOOTER (Josh 2026-09-23): the loot method says who, as a party
-- index or a raid index, and that is turned into the token their cell has
function M.UpdateLooter()
	local method, partyID, raidID
	local ok
	if C_PartyInfo and C_PartyInfo.GetLootMethod then
		ok, method, partyID, raidID = pcall(C_PartyInfo.GetLootMethod)
	elseif GetLootMethod then
		ok, method, partyID, raidID = pcall(GetLootMethod)
	end
	local master = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2
	F.masterLooter = nil
	if ok and (method == "master" or method == master) then
		if IsInRaid and IsInRaid() and type(raidID) == "number" then
			F.masterLooter = "raid" .. raidID
		elseif type(partyID) == "number" then
			F.masterLooter = partyID == 0 and "player" or ("party" .. partyID)
		end
	end
	return F.masterLooter
end

local SHARED = {
	"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "UNIT_PET",
	"GROUP_ROSTER_UPDATE", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "READY_CHECK",
	"READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	"PARTY_LOOT_METHOD_CHANGED", "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED",
	-- into an inn or a city and out again: the Zzz on your own cell
	"PLAYER_UPDATE_RESTING",
}
-- YOURS ALONE (Josh 2026-09-23, audit): these were heard for every unit in
-- range - every cast in a raid, every mob's threat - and all but yours were
-- thrown away after the handler had run
local PLAYER_ONLY = {
	"UNIT_POWER_FREQUENT", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP",
}

local ENEMY_FRAMES = { "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }

-- every group cell there is, in every header
function M.Cells()
	local out = {}
	for _, h in ipairs(M.headers) do
		for _, child in ipairs({ h:GetChildren() }) do
			if type(child) == "table" and child.bmUnit ~= nil then
				out[#out + 1] = child
			end
		end
	end
	return out
end

-- the white outline on whichever cell is your target, and nothing else
function M.PaintOutlines()
	for _, child in ipairs(M.Cells()) do
		if child.outline and child:IsVisible() then
			F.AlphaFrom(child.outline, F.Source(child.bmUnit):IsTarget(), 1, 0)
		end
	end
end

-- ONE PAINT FOR A BURST (Josh 2026-09-23, audit): a ready check answered by
-- forty people was forty full repaints of every frame in the raid
local paintQueued, rosterQueued = false, false
function M.QueuePaint()
	if paintQueued then
		return
	end
	if not (C_Timer and C_Timer.After) then
		M.PaintAll()
		return
	end
	paintQueued = true
	C_Timer.After(0, function()
		paintQueued = false
		if M.live then
			M.PaintAll()
		end
	end)
end

-- and a roster that changes in a burst (a raid forming) is read once
function M.QueueRoster()
	if rosterQueued then
		return
	end
	local function run()
		rosterQueued = false
		if M.live then
			M.UpdateLooter()
			M.PackRaid()
			M.Sweep()
			-- the same tokens may be other people now: every cell jumps
			for _, child in ipairs(M.Cells()) do
				F.Fresh(child)
				F.Fresh(child.bmPet)
				F.Fresh(child.bmTarget)
			end
			M.PaintAll()
		end
	end
	if not (C_Timer and C_Timer.After) then
		run()
		return
	end
	rosterQueued = true
	C_Timer.After(0.1, run)
end

local function onEvent(_, event, unit)
	if not M.live then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		-- the queue has been drained by then (see `drain`, made first)
		M.QueuePaint()
	elseif event == "PLAYER_UPDATE_RESTING" then
		-- resting or not: the Zzz on your own cell
		M.QueuePaint()
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- the same token, somebody else: the client reads the auras again
		if F.Auras then
			F.Auras.Refresh(M.singles.target)
		end
		for _, key in ipairs({ "target", "targettarget" }) do
			if M.singles[key] then
				F.Fresh(M.singles[key])
				F.Paint(M.singles[key], F.Source(key))
			end
		end
		-- the outline on whoever you have targeted in the group - only the
		-- outlines: repainting every cell of a raid on each click of a
		-- healer's was the costliest thing a target change did
		M.PaintOutlines()
	elseif event == "PLAYER_FOCUS_CHANGED" then
		if F.Auras then
			F.Auras.Refresh(M.singles.focus)
		end
		F.Fresh(M.singles.focus)
		F.Paint(M.singles.focus, F.Source("focus"))
	elseif event == "UNIT_TARGET" then
		if unit == "target" then
			F.Fresh(M.singles.targettarget)
			F.Paint(M.singles.targettarget, F.Source("targettarget"))
		end
		-- every header's cells (a call inside "and ... or" gives one value,
		-- so only the first party cell used to be looked at)
		for _, child in ipairs(M.Cells()) do
			if child.bmUnit == unit and child.bmTarget then
				F.Fresh(child.bmTarget)
				F.Paint(child.bmTarget, F.Source(F.TargetOf(unit)))
			end
		end
	elseif event == "UNIT_PET" then
		for _, child in ipairs(M.Cells()) do
			if child.bmPet and child.bmUnit == unit then
				F.Fresh(child.bmPet)
				F.Paint(child.bmPet, F.Source(F.PetOf(unit)))
			end
		end
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		-- an enemy's ring is YOUR threat on it, which moves when yours does
		-- (this is registered for you alone; an enemy frame hears its own
		-- unit's threat list itself)
		for _, key in ipairs(ENEMY_FRAMES) do
			local f = M.singles[key]
			if f and f:IsShown() then
				F.Paint(f, F.Source(key))
			end
		end
	elseif event == "UNIT_POWER_FREQUENT" then
		-- combo points live on the target frame (there is none yet when the
		-- frames were switched on in a fight)
		if unit == "player" and M.singles.target then
			F.PaintCombo(M.singles.target, F.Source("target"))
		end
	elseif event == "READY_CHECK_FINISHED" then
		M.PaintAll()
		if C_Timer and C_Timer.After then
			C_Timer.After(6, M.PaintAll)
		end
	elseif event:find("^UNIT_SPELLCAST") then
		if unit == "player" then
			M.CastEvent(event)
		end
	elseif event == "PARTY_LOOT_METHOD_CHANGED" then
		M.UpdateLooter()
		M.QueuePaint()
	elseif event == "GROUP_ROSTER_UPDATE" then
		M.QueueRoster()
	elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		-- the boss slots dealt again: whoever is in each now, from where they are
		for n = 1, 5 do
			F.Fresh(M.singles["boss" .. n])
		end
		M.QueuePaint()
	else
		-- ready checks answered one by one, a summon or a resurrection per
		-- member, markers: a burst of these is one paint, a frame later
		M.QueuePaint()
	end
end

-- The target of target has no events of its own, and range in a group moves
-- without telling anyone: both are asked again four times a second.
local function tick()
	if not M.live then
		return
	end
	local tot = M.singles.targettarget
	if tot and tot:IsShown() then
		F.Paint(tot, F.Source("targettarget"))
	end
	-- and reach, which changes with every step and tells nobody
	for key, f in pairs(M.singles) do
		if key ~= "targettarget" and f:IsShown() then
			F.AlphaFrom(f, F.Source(key):InRange(), 1, F.FAR_ALPHA)
		end
	end
	for _, h in ipairs(M.headers) do
		if h:IsShown() then
			for _, child in ipairs({ h:GetChildren() }) do
				if type(child) == "table" and child.bmUnit and child:IsShown() then
					local src = F.Source(child.bmUnit)
					F.AlphaFrom(child, src:InRange(), 1, F.GROUP_FAR)
					if child.bmTarget and child.bmTarget:IsShown() then
						F.Paint(child.bmTarget, F.Source(child.bmTarget.bmUnit))
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- On, off
-- ---------------------------------------------------------------------------

function M.Apply()
	if not M.live then
		return
	end
	pending.off = nil
	later("apply", function()
		if not M.live then
			return
		end
		buildSingles()
		for _, pair in ipairs(SINGLES) do
			local unit = pair[1]
			local on = true
			if unit:find("^boss") then
				on = opt("boss", true)
			end
			watch(unit, on)
		end
		buildGroups()
		for _, h in ipairs(M.headers) do
			drive(h, opt(h.bmRole, true))
		end
		M.BuildCast()
		if M.cast and not opt("cast", true) then
			M.cast.casting = nil
			M.cast:SetScript("OnUpdate", nil)
			M.cast:Hide()
		end
		M.Stow()
		M.Sweep()
		M.UpdateLooter()
		M.ApplyScale()
		M.PaintAll()
	end)
end

function M:OnEnable()
	M.live = true
	if not M.events then
		M.events = CreateFrame("Frame")
		for _, event in ipairs(SHARED) do
			pcall(M.events.RegisterEvent, M.events, event)
		end
		for _, event in ipairs(PLAYER_ONLY) do
			local ok = M.events.RegisterUnitEvent and pcall(M.events.RegisterUnitEvent, M.events, event, "player")
			if not ok then
				pcall(M.events.RegisterEvent, M.events, event)
			end
		end
		M.events:SetScript("OnEvent", onEvent)
	end
	if not M.ticker and C_Timer and C_Timer.NewTicker then
		M.ticker = C_Timer.NewTicker(0.25, tick)
	end
	M.Apply()
	-- and every frame once more a moment later: a name written in the first
	-- second of a session, before its face has loaded, is written again here
	-- rather than whenever that unit next changes (see WriteName in Unit.lua)
	if C_Timer and C_Timer.After then
		C_Timer.After(2, function()
			if M.live then
				M.PaintAll()
			end
		end)
	end
end

function M:OnBind()
	if BT.Enabled("unitframes") then
		M:OnEnable()
	end
end

function M:OnDisable()
	M.live = false
	M.Preview(nil)
	pending.apply = nil
	later("off", function()
		if M.live then
			return
		end
		for _, pair in ipairs(SINGLES) do
			watch(pair[1], false)
		end
		for _, h in ipairs(M.headers) do
			drive(h, false)
		end
		if M.cast then
			M.cast.casting = nil
			M.cast:SetScript("OnUpdate", nil)
			M.cast:Hide()
		end
		-- and the game's own, back where they were
		M.Stow()
	end)
end

-- the theme changed: the surfaces repaint themselves, the bars are asked
function M.Restyle()
	if M.live then
		M.PaintAll()
	end
	for _, f in ipairs(M.previews or {}) do
		if f.bmSrc then
			F.Paint(f, f.bmSrc)
		end
	end
end

-- ---------------------------------------------------------------------------
-- A preview: Made-up people, on the Testing page
-- ---------------------------------------------------------------------------

-- Made-up people in a made-up raid, drawn by the same code with plain numbers
-- where the client's secrets would be. A preview is not a secure frame and
-- clicks nothing.
-- spells for the made-up auras, by id: their pictures are the client's own
local SP = {
	renew = 139, rejuv = 774, shield = 17, regrowth = 8936, might = 19740, fortitude = 1243,
	poison = 2818, pain = 589, corruption = 172, curse = 19703, doom = 19702, hamstring = 1715,
	infected = 3427, rend = 772, frenzy = 8269, shout = 6673, defensive = 71,
	rupture = 1943, expose = 8647, sunder = 7386, fire = 770, garrote = 703, nova = 122,
}

local SKULL = { name = "Edwin VanCleef", reaction = "hostile", hp = 64, marker = 8 }
local PARTY = {
	{ name = "Brannoc", class = "WARRIOR", level = 34, hp = 64, max = 1480, heal = 20, shield = 8, aggro = 3, leader = true, ml = true,
		aim = SKULL, auras = { debuffs = { { spell = SP.poison, type = "Poison", count = 3 } },
			mine = { { spell = SP.renew }, { spell = SP.shield } }, dispel = "Poison" } },
	-- the one with something you could remove, to show the mark
	-- and a summon waiting for her
	{ name = "Maelis", class = "PRIEST", level = 33, hp = 92, max = 760, mana = 58, summon = 1, heal = 20,
		aim = { name = "Brannoc", class = "WARRIOR", hp = 64 },
		auras = { debuffs = { { spell = SP.pain, type = "Magic" }, { spell = SP.hamstring } }, dispel = "Magic" } },
	-- the one on the wrong target, which is what the column is for
	{ name = "Ysolde", class = "MAGE", level = 35, hp = 100, max = 720, mana = 71, target = true,
		aim = { name = "Defias Blackguard", reaction = "hostile", hp = 100 },
		auras = { debuffs = { { spell = SP.infected, type = "Disease" } }, mine = { { spell = SP.shield } },
			dispel = "Disease" } },
	-- a hunter, with a boar that is only content: the happiness square
	{ name = "Ashby", class = "HUNTER", level = 32, hp = 47, max = 1210, mana = 80, aim = SKULL,
		pet = { name = "Bristleback", reaction = "friendly", hp = 83, happy = 2 },
		auras = { debuffs = { { spell = SP.corruption, type = "Curse" } }, mine = { { spell = SP.rejuv } },
			dispel = "Curse" } },
}
local RAID_CLASSES = { "WARRIOR", "PRIEST", "PALADIN", "DRUID", "MAGE", "WARLOCK", "HUNTER", "ROGUE" }
local RAID_NAMES = {
	"Brannoc", "Hollis", "Maelis", "Pellam", "Thessaly", "Garrow", "Tamsin", "Sefa", "Isolt", "Fennick",
	"Odric", "Kestrel", "Orla", "Gerard", "Arwel", "Dunmore", "Rook", "Wenna", "Ansel", "Briony",
	"Ysolde", "Quill", "Emeric", "Aldith", "Merrin", "Sabine", "Tobiah", "Nell", "Corwen", "Liesl",
	"Morwen", "Draxis", "Hesper", "Vey", "Ashby", "Lark", "Wystan", "Beeb", "Corvin", "Slate",
}
local BOSSES = {
	{ name = "Lucifron", level = -1, classification = "worldboss", reaction = "hostile", hp = 38, marker = 8,
		cast = { name = "Impending Doom", p = 0.6, shielded = true },
		auras = {} },
	{ name = "Flamewaker Protector", level = 62, classification = "elite", reaction = "hostile", hp = 100, marker = 7,
		auras = {} },
	-- a rare, for the silver beside the gold
	{ name = "Mazzranache", level = 20, classification = "rare", reaction = "hostile", hp = 55, auras = {} },
	{ name = "Flamewaker Protector", level = 62, classification = "elite", reaction = "hostile", hp = 12, marker = 6,
		-- low, and enraged: the one mechanic worth showing beside it
		cast = { name = "Cleave", p = 0.3 }, auras = { mechanics = { { spell = SP.frenzy, type = "Enrage" } } } },
}

M.previews = {}

local function preview(kind, d, point, handle)
	local f = F.Build(UIParent, kind, nil, false)
	f:SetPoint(unpack(point))
	-- a made-up pet or target moves the party it hangs off; the made-up
	-- target frame moves nothing
	M.Handle(f, handle or ((kind == "gpet" or kind == "gtarget") and "party")
		or (kind == "tank" and "tanks") or kind)
	f:SetFrameStrata("MEDIUM")
	f:SetScale(M.Scale())
	F.Paint(f, F.Fake(d))
	if d.auras and F.Auras then
		F.Auras.Show(f, kind, d.auras)
	end
	-- and the bars of your heals or damage over time, part run down
	if F.Timers and not d.dead and not d.offline then
		F.Timers.Show(f, kind)
	end
	f:Show()
	M.previews[#M.previews + 1] = f
	return f
end

-- WHERE A PREVIEW HANGS (Josh 2026-09-23, audit): the holders are what the
-- secure headers are anchored to, and placing one again in a fight is moving
-- a frame the client guards. Out of a fight a holder is placed as saved; in
-- one it is used where it already is.
local function spot(key)
	if inCombat() then
		return holder(key)
	end
	return M.PlaceHolder(key)
end

-- "party", "raid" or nil for none
-- the made-up people drawn again, as they are now (a choice changed)
function M.RefreshPreview()
	if M.previewing then
		M.Preview(M.previewing)
	end
end

function M.Preview(what)
	for _, f in ipairs(M.previews) do
		f:Hide()
	end
	M.previews = {}
	if M.cast then
		M.cast.casting = nil
	end
	M.previewing = what
	if not what then
		return 0
	end
	if what == "party" then
		-- the first place is yours, and your real frame is already in it
		for i, d in ipairs(PARTY) do
			local cell = preview("party", d, { "TOPLEFT", spot("party"), "TOPLEFT", 0,
				-i * (F.KINDS.party.h + M.PARTY_STEP) })
			if d.pet then
				preview("gpet", d.pet, { "TOPRIGHT", cell, "BOTTOMRIGHT", 0, -PET_GAP })
			end
			if d.aim then
				preview("gtarget", d.aim, { "TOPLEFT", cell, "TOPRIGHT", 4, 0 })
			end
		end
	else
		-- group 6 is left empty, to show the columns closing up: groups 7 and
		-- 8 are drawn in the sixth and seventh
		local at, cols = M.Columns({ true, true, true, true, true, false, true, true })
		if not inCombat() then
			spot("raid"):SetWidth(cols * M.RAID_STEP)
		end
		M.raidCells = {}
		for i, name in ipairs(RAID_NAMES) do
			local g, slot = math.floor((i - 1) / 5), (i - 1) % 5
			-- nobody in group 6
			if g + 1 ~= 6 then
				local d = {
					name = name, class = RAID_CLASSES[(i % #RAID_CLASSES) + 1], max = 4000 + (i * 137) % 3500,
					hp = (i % 7 == 0) and 22 or (i % 3 == 0 and 71 or 100),
					dead = i == 39, offline = i == 34, range = not (i == 22 or i == 35), aggro = i == 1 and 3 or nil,
					heal = i == 1 and 18 or nil, shield = i == 1 and 8 or nil, charmed = i == 2, leader = i == 1,
					target = i == 21, marker = i == 1 and 1 or nil,
					-- a resurrection on its way to the dead, and a summon in each of
					-- its states - waiting, taken, turned down - along the last group
					rez = i == 39, summon = ({ [37] = 1, [38] = 2, [40] = 3 })[i], ml = i == 3,
				}
				-- EVERY TYPE, SIDE BY SIDE: every third member carries one, the five
				-- in turn - magic, curse, poison, disease, and a bleed, which nothing
				-- removes in this ruleset but is drawn so its pattern can be seen
				local auras = { debuffs = {}, mine = {} }
				if i % 3 == 0 then
					local kinds = {
						{ "Magic", SP.doom }, { "Curse", SP.curse }, { "Poison", SP.poison },
						{ "Disease", SP.infected }, { "Bleed", SP.rend },
					}
					local k = kinds[((i / 3) - 1) % #kinds + 1]
					auras.debuffs[#auras.debuffs + 1] = { spell = k[2], type = k[1] }
					auras.dispel = k[1]
				end
				if d.class == "WARRIOR" or i <= 2 then
					auras.mine = { { spell = SP.renew }, { spell = SP.shield } }
				end
				d.auras = auras
				M.raidCells[i] = preview("raid", d, { "TOPLEFT", spot("raid"), "TOPLEFT", at[g + 1] * M.RAID_STEP,
					-slot * (RAID_H + 2) })
			end
		end
	end
	-- WHAT THE SWITCHES SAY (Josh 2026-09-23: "need an option to disable
	-- showing main tanks"). The switch was there and the preview drew the
	-- tanks anyway, so it looked like it did nothing. The bosses, the main
	-- tanks and the cast bar are drawn only while they are switched on.
	for i, d in ipairs(opt("boss", true) and BOSSES or {}) do
		preview("boss", d, { "TOPLEFT", spot("boss"), "TOPLEFT", 0, -(i - 1) * (F.KINDS.boss.h + M.BOSS_GAP) })
	end
	-- and a target to judge the single frames by, to the right of yours,
	-- clear of the party and the raid down the left
	-- the main tanks, in a raid, each with what they have in hand
	if what == "raid" and opt("tanks", true) then
		local list = {
			{ name = "Brannoc", class = "WARRIOR", hp = 71, aggro = 3, aim = { name = "Lucifron", reaction = "hostile", hp = 38, marker = 8 } },
			{ name = "Garrow", class = "WARRIOR", hp = 22, aggro = 3, aim = { name = "Flamewaker Protector", reaction = "hostile", hp = 12, marker = 6 } },
		}
		-- stacked up from the raid, the first on top
		for i, t in ipairs(list) do
			local cell = preview("tank", t, { "BOTTOMLEFT", spot("tanks"), "BOTTOMLEFT", 0,
				(#list - i) * (F.KINDS.tank.h + 4) })
			preview("gtarget", t.aim, { "TOPLEFT", cell, "TOPRIGHT", 4, 0 }, "tanks")
		end
	end
	-- and your cast bar, part way through a Hearthstone
	local c = opt("cast", true) and M.BuildCast()
	if c then
		c.casting = nil
		c:SetScript("OnUpdate", nil)
		local a = BT.Widgets.ACCENT
		c.bar:SetStatusBarColor(a[1], a[2], a[3], 0.9)
		c.bar:SetValue(0.4)
		c.icon:SetTexture(134414)
		c.name:SetText("Hearthstone")
		c.time:SetText("6.0")
		spot("cast")
		c:Show()
		M.previews[#M.previews + 1] = c
	end
	M.previewTarget = preview("target", { name = "Defias Blackguard", level = 20, classification = "elite",
		reaction = "hostile", hp = 72, max = 1540, mana = 45, power = "RAGE", combo = 3, threat = 82, threatStatus = 2,
		auras = { debuffs = { { spell = SP.rupture }, { spell = SP.sunder, count = 5 }, { spell = SP.fire, type = "Magic" },
			{ spell = SP.hamstring }, { spell = SP.expose } },
			-- and its buffs under them, a stance it keeps all day included
			buffs = { { spell = SP.shout }, { spell = SP.defensive } } } },
		{ "TOPLEFT", UIParent, "TOPLEFT", M.TARGET_X + F.KINDS.target.w + M.COLUMN_GAP + F.KINDS.tot.w + GAP, -24 })
	return #M.previews
end

-- The unit frames' record (the Testing page's Record button): what the client
-- holds for the names that went blank - the face, the size, the text, whether
-- it is shown and how big - into the saved file, the same way the other
-- records go. Never a secret into a string.
local function describeText(label, fs)
	if not (fs and fs.GetText) then
		return label .. ": none"
	end
	local function say(v)
		if issecretvalue and issecretvalue(v) then
			return "SECRET(" .. type(v) .. ")"
		end
		if type(v) == "string" then
			return ("%q"):format(v:sub(1, 40))
		end
		return tostring(v)
	end
	local text = fs:GetText()
	local face, size, flags = fs:GetFont()
	local w = fs.GetStringWidth and fs:GetStringWidth()
	return ("%s: text=%s font=%s size=%s flags=%s shown=%s visible=%s alpha=%s width=%s strW=%s height=%s"):format(
		label, say(text), say(face), say(size), say(flags), say(fs:IsShown()), say(fs:IsVisible()),
		say(fs:GetAlpha()), say(fs:GetWidth()), say(w), say(fs:GetHeight()))
end

function M.Dump()
	local lines = { "build: " .. tostring(BT.BUILD), "fonts: " .. tostring(BT.Fonts.Current().key)
		.. " ok name=" .. tostring(BT.Fonts.Face("name")) }
	for key, f in pairs(M.singles) do
		if f:IsShown() then
			lines[#lines + 1] = describeText(key .. ".name", f.name)
			lines[#lines + 1] = describeText(key .. ".value", f.value)
		end
	end
	for i, h in ipairs(M.headers) do
		for n, child in ipairs({ h:GetChildren() }) do
			if type(child) == "table" and child.bmUnit and child:IsShown() then
				lines[#lines + 1] = describeText(("header%d.%d(%s).name"):format(i, n, child.bmUnit), child.name)
			end
		end
	end
	BT.EnsureBound()
	BeebModDB.unitframesDump = { at = U.Now(), lines = lines }
	return #lines
end

BT.Record("unitframesDump", M.Dump, "unitframes")

-- ---------------------------------------------------------------------------
-- Your cast bar
-- ---------------------------------------------------------------------------
--
-- YOURS, IN THE TOOLKIT'S CLOTHES (Josh 2026-09-23). The client's own cast bar
-- was the one piece of the unit frames left as it came. This one sits under
-- the resource display, in the accent, with the spell's picture, its name and
-- the time left - your own casts are plain to read, so the time can be
-- counted here - and shift-drags like the other blocks. The client's is put
-- away while it is on. A cast cut short flashes red for a moment.
local CAST_W, CAST_H = 200, 18

function M.BuildCast()
	if M.cast then
		return M.cast
	end
	local c = CreateFrame("Frame", "BeebModCastBar", UIParent)
	c:SetSize(CAST_W, CAST_H)
	c:SetPoint("TOPLEFT", holder("cast"), "TOPLEFT", 0, 0)
	c:SetFrameStrata("MEDIUM")
	BT.Pill.Panel(c, BT.Widgets.FILL, { 0, 0, 0, 0 })
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(CAST_H - 4, CAST_H - 4)
	c.icon:SetPoint("LEFT", 2, 0)
	c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.bar = CreateFrame("StatusBar", nil, c)
	c.bar:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 2, 0)
	c.bar:SetPoint("BOTTOMRIGHT", -2, 2)
	c.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	c.bar:SetMinMaxValues(0, 1)
	c.name = c.bar:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(c.name, "name", 10, "")
	c.name:SetShadowColor(0, 0, 0, 1)
	c.name:SetShadowOffset(1, -1)
	c.name:SetPoint("LEFT", 4, 0)
	c.name:SetJustifyH("LEFT")
	c.time = c.bar:CreateFontString(nil, "OVERLAY")
	BT.Fonts.Set(c.time, "text", 10, "")
	c.time:SetShadowColor(0, 0, 0, 1)
	c.time:SetShadowOffset(1, -1)
	c.time:SetPoint("RIGHT", -4, 0)
	c.name:SetPoint("RIGHT", c.time, "LEFT", -4, 0)
	c:EnableMouse(true)
	M.Handle(c, "cast")
	c:Hide()
	M.cast = c
	return c
end

-- the cast in progress, read plainly - your own are not secret
local function current()
	local name, _, icon, startMS, endMS = nil, nil, nil, nil, nil
	local channel = false
	if UnitCastingInfo then
		name, _, icon, startMS, endMS = UnitCastingInfo("player")
	end
	if not name and UnitChannelInfo then
		name, _, icon, startMS, endMS = UnitChannelInfo("player")
		channel = name ~= nil
	end
	if not name or type(startMS) ~= "number" or (issecretvalue and issecretvalue(startMS)) then
		return nil
	end
	return { name = name, icon = icon, start = startMS / 1000, finish = endMS / 1000, channel = channel }
end

local function paintCast(c, now)
	local k = c.casting
	if not k then
		return
	end
	local span = math.max(0.001, k.finish - k.start)
	local done = math.max(0, math.min(1, (now - k.start) / span))
	c.bar:SetValue(k.channel and (1 - done) or done)
	c.time:SetText(("%.1f"):format(math.max(0, k.finish - now)))
end

function M.CastEvent(event)
	local c = M.cast
	if not (c and M.live and opt("cast", true)) or M.previewing then
		return
	end
	if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		-- STILL CASTING, SO IT WAS ANOTHER ATTEMPT THAT FAILED (Josh
		-- 2026-09-23, audit): a key pressed mid-cast fails that spell, not
		-- this one, and the bar went red and vanished with the cast going on
		if current() then
			return
		end
		if c.casting then
			c.casting = nil
			c:SetScript("OnUpdate", nil)
			c.bar:SetStatusBarColor(0.82, 0.27, 0.24, 1)
			c.bar:SetValue(1)
			c.name:SetText(event == "UNIT_SPELLCAST_INTERRUPTED" and "Interrupted" or "Failed")
			c.time:SetText("")
			if C_Timer and C_Timer.After then
				C_Timer.After(0.6, function()
					if not c.casting then
						c:Hide()
					end
				end)
			else
				c:Hide()
			end
		end
		return
	end
	local k = current()
	if not k then
		c.casting = nil
		c:SetScript("OnUpdate", nil)
		c:Hide()
		return
	end
	c.casting = k
	local a = BT.Widgets.ACCENT
	c.bar:SetStatusBarColor(a[1], a[2], a[3], 0.9)
	c.icon:SetTexture(k.icon)
	c.name:SetText(k.name)
	c:SetScript("OnUpdate", function(self)
		paintCast(self, GetTime and GetTime() or 0)
	end)
	paintCast(c, GetTime and GetTime() or 0)
	c:Show()
end

-- ---------------------------------------------------------------------------
-- One size for all of them
-- ---------------------------------------------------------------------------
--
-- ONE SETTING (Josh 2026-09-23): every unit frame, the blocks they sit in and
-- the cast bar take the same scale, so a larger screen or a smaller one asks
-- for one number rather than a page of them. Secure frames are scaled out of
-- combat only; a change made in a fight waits for its end.
M.SCALE_MIN, M.SCALE_MAX, M.SCALE_STEP = 0.8, 1.3, 0.05

function M.Scale()
	return opt("scale", 1)
end

function M.ApplyScale()
	local s = M.Scale()
	return later("scale", function()
		local function set(f)
			if f and f.SetScale then
				f:SetScale(s)
			end
		end
		for _, f in pairs(M.singles) do set(f) end
		for _, h in ipairs(M.headers) do set(h) end
		for _, h in pairs(M.holders) do set(h) end
		set(M.cast)
		for _, f in ipairs(M.previews or {}) do set(f) end
	end)
end

function M.SetScale(s)
	s = math.floor((s or 1) / M.SCALE_STEP + 0.5) * M.SCALE_STEP
	s = math.max(M.SCALE_MIN, math.min(M.SCALE_MAX, s))
	BT.EnsureBound()
	BT.settings.unitframes = BT.settings.unitframes or {}
	BT.settings.unitframes.scale = s
	M.ApplyScale()
	return s
end

-- ---------------------------------------------------------------------------
-- Casting on what you point at
-- ---------------------------------------------------------------------------
--
-- MOUSEOVER CAST IS THE CLIENT'S (Josh 2026-09-23: "if I hover over a frame
-- and cast a heal, it should heal my hover target"). The client has it -
-- enableMouseoverCast, in its own Combat options on this build - and it is
-- the right tool: a spell goes to the unit under the cursor when it can land
-- there and to your target when it cannot, so a heal on a party cell heals
-- that member and a Sinister Strike still hits the mob. Click-casting would
-- need the secure snippets this build cannot compile; this needs nothing but
-- frames that carry a unit, which these do. The switch here is the client's
-- setting, not a copy of it: flip either and both agree.

function M.MouseoverSupported()
	if type(IsMouseoverCastSupported) ~= "function" then
		return false
	end
	local ok, yes = pcall(IsMouseoverCastSupported)
	if not (ok and yes == true) then
		return false
	end
	return C_CVar ~= nil and C_CVar.GetCVar ~= nil and C_CVar.GetCVar("enableMouseoverCast") ~= nil
end

function M.Mouseover()
	if not M.MouseoverSupported() then
		return false
	end
	return C_CVar.GetCVar("enableMouseoverCast") == "1"
end

function M.SetMouseover(on)
	if not M.MouseoverSupported() then
		return false
	end
	-- a setting the client guards in a fight: set when it is over
	return later("mouseover", function()
		pcall(C_CVar.SetCVar, "enableMouseoverCast", on and "1" or "0")
	end)
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local W = BT.Widgets
	local page = W.Stack(panel)
	local groups = page:Section("Show")
	W.SwitchRow(groups, "Party", "You and your pet at the top, then 4 others with their pets and targets",
		function() return opt("party", true) end, function(on) setOpt("party", on) end)
	W.SwitchRow(groups, "Raid", "A column for each group in use, in place of the game's raid frames",
		function() return opt("raid", true) end, function(on) setOpt("raid", on) end)
	W.SwitchRow(groups, "Main tanks", "In a raid, above the raid frames, each with its target",
		function() return opt("tanks", true) end, function(on) setOpt("tanks", on) end)
	W.SwitchRow(groups, "Bosses", "Up to 5, with their casts and mechanics",
		function() return opt("boss", true) end, function(on) setOpt("boss", on) end)
	W.SwitchRow(groups, "Your cast bar", "Under the resource display, in place of the game's cast bar",
		function() return opt("cast", true) end, function(on) setOpt("cast", on) end)
	local where = page:Section("Place")
	local move = W.Row(where, "Shift-drag to move", "Any block, out of combat")
	local reset = move:SetControl(W.Button(move, "Reset", 62, 20))
	reset:SetScript("OnClick", function()
		M.ResetPlaces()
	end)
	local size = W.Row(where, "Size", "Every unit frame, and the cast bar")
	self.sizeStep = size:SetControl(W.Stepper(size, function(dir)
		M.SetScale(M.Scale() + dir * M.SCALE_STEP)
		M:ShowTab()
	end))
	-- WHAT THEY SAY AND HOW THEY MOVE (Josh 2026-09-24)
	local health = page:Section("Health text")
	self.healthSegs = {}
	for _, pair in ipairs({ { "party", "Party" }, { "raid", "Raid", "Main tanks too" }, { "target", "Target" },
		{ "focus", "Focus" }, { "boss", "Bosses" } }) do
		local key = pair[1]
		local row = W.Row(health, pair[2], pair[3] or "")
		local seg = row:SetControl(W.Segmented(row, {
			{ "none", "None" }, { "percent", "%" }, { "value", "Value" }, { "both", "Both" },
		}, function(mode)
			local all = opt("health", nil)
			all = type(all) == "table" and all or {}
			all[key] = mode
			setOpt("health", all)
			M.PaintAll()
		end, 52))
		seg.healthKey = key
		self.healthSegs[#self.healthSegs + 1] = seg
	end
	local look = page:Section("Feel")
	local fadeRow = W.Row(look, "Out of range", "How much a frame fades when it's out of range")
	self.fadeSeg = fadeRow:SetControl(W.Segmented(fadeRow, {
		{ "light", "Light" }, { "medium", "Medium" }, { "strong", "Strong" },
	}, function(key)
		setOpt("fade", key)
		M.PaintAll()
	end))
	W.SwitchRow(look, "Bars slide", "Health and power slide to a new value. Off, they jump.",
		function() return opt("animate", true) end, function(on) setOpt("animate", on) end)
	W.SwitchRow(look, "Target's buffs", "A row of your target's buffs, beside its debuffs",
		function() return opt("targetBuffs", true) end,
		function(on)
			setOpt("targetBuffs", on)
			if F.Auras and M.singles.target then
				F.Auras.TargetBuffs(M.singles.target)
			end
		end)
	-- YOUR HEAL OVER TIME (Josh 2026-09-24): a bar along the top of the
	-- frame it is on (Timers.lua). The damage over time goes over your own
	-- bars now, and its settings with it, on the Resource display's page.
	local T = F.Timers
	if T and #T.Spells("hot") > 0 then
		local timers = page:Section("Heal over time")
		for _, name in ipairs(T.Spells("hot")) do
			W.SwitchRow(timers, name, "A bar on the player who has it, counting down",
				function() return T.On(name) end,
				function(on)
					T.SetOn(name, on)
					M.RefreshPreview()
				end)
		end
		-- the heal's own blink; the damage has its own, on the Resource
		-- display's page
		self.blinkRow = T.BlinkRow(timers, "hot", function() M.RefreshPreview() end)
	end
	local more = page:Section("More")
	if M.MouseoverSupported() then
		self.mouseoverRow = W.SwitchRow(more, "Cast on what you point at",
			"Heals go to the frame under the pointer. Attacks still go to your target.",
			function() return M.Mouseover() end,
			function(on) M.SetMouseover(on) end)
	end
	-- the made-up people are on the Testing page now (UI/Window.lua)
	page:Layout()
	self.page = page
end

function M:ShowTab()
	for _, seg in ipairs(self.healthSegs or {}) do
		seg:Select(F.HealthMode(seg.healthKey == "raid" and "raid" or seg.healthKey))
	end
	if self.fadeSeg then
		self.fadeSeg:Select(opt("fade", "strong"))
	end
	if self.sizeStep then
		self.sizeStep:Say(("%d%%"):format(math.floor(M.Scale() * 100 + 0.5)))
	end
end
