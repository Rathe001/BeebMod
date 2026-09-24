-- What this client will tell a unit frame (Josh 2026-09-23).
--
-- The unit frames are being redrawn, and this client is an odd mix: a
-- classic-era game on the modern engine, with Edit Mode and SECRET VALUES -
-- numbers an addon may hand to a widget but may not compare or add up. What
-- each call returns, and whether it comes back secret, decides the whole
-- design (a health percentage we cannot compute is a percentage we cannot
-- print). Nobody documents this client, so it is asked.
--
--   /bt unitprobe        write down what is here now, and again two seconds
--                        into the next fight - /reload after the fight to
--                        save both into the file
--   /bt unitprobe clear  forget both
--
-- It writes into BeebModDB.unitProbe, where the book is, and reads nothing
-- back. It never prints a secret value: a secret put into a string makes the
-- whole string secret, and a secret cannot be saved.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/UnitProbe.lua")

local U = BT.Util
local unpack = unpack or table.unpack

local P = {}
BT.UnitProbe = P

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- a value as words, without ever turning a secret into text
local function say(v)
	if secret(v) then
		return "SECRET(" .. type(v) .. ")"
	end
	local t = type(v)
	if t == "nil" then
		return "nil"
	elseif t == "string" then
		return ("%q"):format(v:sub(1, 40))
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local keys = 0
		for _ in pairs(v) do
			keys = keys + 1
		end
		return ("table(%d)"):format(keys)
	end
	return t
end

-- every result of a call, as words; an error is an answer too
local function ask(fn, ...)
	if type(fn) ~= "function" then
		return "absent"
	end
	local out = { pcall(fn, ...) }
	if not out[1] then
		return "error: " .. tostring(out[2]):sub(1, 80)
	end
	local bits = {}
	for i = 2, math.max(2, select("#", unpack(out))) do
		bits[#bits + 1] = say(out[i])
	end
	return table.concat(bits, ", ")
end

-- A table of fields (an aura, a cast): each field's name, and whether it is
-- readable. The values themselves are left out unless they are plain words
-- or numbers, which is what a design needs to know.
local function fields(t)
	if type(t) ~= "table" then
		return say(t)
	end
	if secret(t) then
		return "SECRET(table)"
	end
	local names = {}
	for k in pairs(t) do
		if type(k) == "string" then
			names[#names + 1] = k
		end
	end
	table.sort(names)
	local bits = {}
	for _, k in ipairs(names) do
		bits[#bits + 1] = k .. "=" .. say(t[k])
	end
	return table.concat(bits, " ")
end

-- the names in a table that match, sorted and joined
local function namesIn(t, pattern, want)
	local out = {}
	if type(t) ~= "table" then
		return out
	end
	for k, v in pairs(t) do
		if type(k) == "string" and (not pattern or k:find(pattern)) and (not want or type(v) == want) then
			out[#out + 1] = k
		end
	end
	table.sort(out)
	return out
end

-- ---------------------------------------------------------------------------
-- What there is
-- ---------------------------------------------------------------------------

-- the globals a unit frame might want, found by name rather than listed, so
-- a function this client added under a name nobody expected still turns up
local GLOBAL_PATTERNS = {
	"^Unit", "Secret", "secret", "Curve", "Duration", "HealPrediction", "Absorb",
	"^GetRaid", "^GetNumGroup", "^GetNumSubgroup", "^IsIn", "^GetPartyAssign", "^GetReadyCheck",
	"^CheckInteract", "^IsSpellInRange", "^IsItemInRange", "^Abbreviate", "^GetThreat",
	"^GetComboPoints", "^RegisterUnitWatch", "^UnregisterUnitWatch", "^RegisterStateDriver",
	"^RegisterAttributeDriver", "^SecureHandler", "^GetArena", "^GetNumArena", "^CastingInfo",
	"^ChannelInfo", "^InCombatLockdown", "^GetShapeshift", "^GetSpecialization",
	"^CreateUnitHealPrediction", "^SecureHandler", "^GetDispel",
}

local NAMESPACES = {
	"C_UnitAuras", "C_CurveUtil", "C_Secrets", "C_DurationUtil", "C_Spell", "C_PartyInfo",
	"C_IncomingSummon", "C_IncomingResurrect", "C_PvP", "C_NamePlate", "C_PlayerInfo",
	"C_ClassColor", "C_RaidLocks", "C_UnitAurasPrivate", "C_TooltipInfo", "C_StringUtil",
	"C_ColorUtil", "C_Timer", "C_EditMode", "C_EncounterJournal", "C_ActionBar", "C_Scenario",
	"C_LossOfControl", "C_DamageMeter", "C_SpellBook", "C_ClassTalents", "C_CVar",
	"C_RestrictedActions", "C_LFGInfo", "C_LFGList", "C_AuraContainerUtil", "C_XMLUtil",
}

local FRAMES = {
	"PlayerFrame", "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT", "PetFrame",
	"PartyFrame", "PartyMemberFrame1", "CompactPartyFrame", "CompactPartyFrameMember1",
	"CompactRaidFrameContainer", "CompactRaidFrameManager", "CompactRaidFrame1",
	"BossTargetFrameContainer", "Boss1TargetFrame", "ArenaEnemyFramesContainer",
	"PlayerCastingBarFrame", "CastingBarFrame", "TargetFrameSpellBar", "FocusFrameSpellBar",
	"PetCastingBarFrame", "ComboFrame", "ComboPointPlayerFrame", "RuneFrame", "TotemFrame",
	"PlayerFrameAlternateManaBar", "MonkHarmonyBarFrame", "PaladinPowerBarFrame",
	"EditModeManagerFrame", "PlayerBuffFrame", "BuffFrame", "DebuffFrame",
	"TargetFrameBuff1", "PlayerFrameHealthBar", "TargetFrameHealthBar",
}

local TEMPLATES = {
	"SecureUnitButtonTemplate", "SecureGroupHeaderTemplate", "SecureGroupPetHeaderTemplate",
	"SecureHandlerStateTemplate", "SecureHandlerAttributeTemplate", "PingableUnitFrameTemplate",
	"SmallCastingBarFrameTemplate", "CastingBarFrameTemplate", "CompactUnitFrameTemplate",
}

-- the widget methods a secret-aware frame would reach for, by name
local METHOD_PATTERN = "Secret|FromBoolean|Duration|Timer|Interpolat|Curve|Smooth|Fill|Reverse|Clip|Pixel|Mask|Timer"

local function methodsOf(kind, template)
	local ok, f = pcall(CreateFrame, kind, nil, UIParent, template)
	if not ok or not f then
		return nil
	end
	f:Hide()
	local mt = getmetatable(f)
	local index = mt and mt.__index
	return type(index) == "table" and index or nil
end

local function textureMethods()
	local ok, f = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok then
		return nil
	end
	f:Hide()
	local t = f:CreateTexture()
	local s = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local mt1, mt2 = getmetatable(t), getmetatable(s)
	return mt1 and mt1.__index, mt2 and mt2.__index
end

local function filtered(index)
	local out = {}
	for _, name in ipairs(namesIn(index, nil, "function")) do
		for word in METHOD_PATTERN:gmatch("[^|]+") do
			if name:find(word) then
				out[#out + 1] = name
				break
			end
		end
	end
	return out
end

local function inventory(lines)
	local function add(line)
		lines[#lines + 1] = line
	end
	local build = { pcall(GetBuildInfo) }
	add("build: " .. table.concat({ say(build[2]), say(build[3]), say(build[4]), say(build[5]) }, " · "))
	add("project: WOW_PROJECT_ID=" .. say(_G.WOW_PROJECT_ID) .. " LE_EXPANSION_LEVEL_CURRENT="
		.. say(_G.LE_EXPANSION_LEVEL_CURRENT) .. " MAX_PLAYER_LEVEL=" .. say(_G.MAX_PLAYER_LEVEL))

	-- globals by pattern
	local seen, found = {}, {}
	for _, pattern in ipairs(GLOBAL_PATTERNS) do
		for _, name in ipairs(namesIn(_G, pattern, "function")) do
			if not seen[name] then
				seen[name] = true
				found[#found + 1] = name
			end
		end
	end
	table.sort(found)
	add(("globals (%d): %s"):format(#found, table.concat(found, " ")))
	for _, name in ipairs({ "issecretvalue", "issecrettable", "canaccessvalue", "canaccesstable",
		"canaccessallvalues", "secretwrap", "scrubsecretvalues", "dropsecretaccess",
		"hasanysecretvalues", "securecallfunction", "forceinsecure" }) do
		add(("  %s: %s"):format(name, type(_G[name])))
	end

	-- namespaces, every function in them
	for _, ns in ipairs(NAMESPACES) do
		local t = _G[ns]
		if type(t) == "table" then
			local fns = namesIn(t, nil, "function")
			add(("%s (%d): %s"):format(ns, #fns, table.concat(fns, " ")))
		else
			add(ns .. ": absent")
		end
	end
	-- any namespace at all whose name suggests units, auras or secrets
	local others = {}
	for _, name in ipairs(namesIn(_G, "^C_", "table")) do
		if name:find("Unit") or name:find("Aura") or name:find("Secret") or name:find("Curve")
			or name:find("Party") or name:find("Raid") or name:find("Heal") or name:find("Duration") then
			others[#others + 1] = name
		end
	end
	add("namespaces like these: " .. table.concat(others, " "))

	-- widget methods
	for _, kind in ipairs({ "StatusBar", "Cooldown", "Frame", "Button" }) do
		local index = methodsOf(kind)
		if index then
			add(("%s methods of note: %s"):format(kind, table.concat(filtered(index), " ")))
		end
	end
	local sb = methodsOf("StatusBar")
	if sb then
		add("StatusBar all: " .. table.concat(namesIn(sb, nil, "function"), " "))
	end
	local tex, fs = textureMethods()
	if tex then
		add("Texture methods of note: " .. table.concat(filtered(tex), " "))
	end
	if fs then
		add("FontString methods of note: " .. table.concat(filtered(fs), " "))
	end

	add("CurveConstants: " .. (type(_G.CurveConstants) == "table"
		and table.concat(namesIn(_G.CurveConstants), " ") or "absent"))
	add("Enum.LuaCurveType: " .. ((_G.Enum and type(_G.Enum.LuaCurveType) == "table")
		and table.concat(namesIn(_G.Enum.LuaCurveType), " ") or "absent"))
	add("Enum.AddOnRestrictionType: " .. ((_G.Enum and type(_G.Enum.AddOnRestrictionType) == "table")
		and table.concat(namesIn(_G.Enum.AddOnRestrictionType), " ") or "absent"))

	-- SECURE SNIPPETS (forever-bugs #74): the client's restricted code could
	-- not compile a snippet in the first beta week, which takes click-casting
	-- and the group header's snippets with it. Asked by running one, because
	-- the global it hinges on is nil on a healthy client as well.
	local okH, h = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
	if okH and h and type(_G.SecureHandlerExecute) == "function" then
		h:Hide()
		local ran, err = pcall(_G.SecureHandlerExecute, h, "self:SetAttribute('beebsProbe', 7)")
		local got = h.GetAttribute and h:GetAttribute("beebsProbe")
		add("secure snippets: " .. ((ran and got == 7) and "WORK"
			or ("BROKEN (" .. tostring(err or "no effect"):sub(1, 80) .. ")")))
	else
		add("secure snippets: no handler template or SecureHandlerExecute")
	end

	-- TEMPLATES ARE ASKED ABOUT, NOT MADE (Josh 2026-09-23). Making one ran
	-- its OnLoad, and CompactUnitFrameTemplate's throws for a frame with no
	-- name - outside the pcall, because OnLoad is its own call. The client
	-- will describe a template without building it; only the secure ones,
	-- which have no OnLoad of consequence, are made when it will not.
	local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo
	for _, template in ipairs(TEMPLATES) do
		if info then
			local ok, t = pcall(info, template)
			add(("template %s: %s"):format(template, (ok and type(t) == "table")
				and ("type=" .. say(t.type) .. " inherits=" .. say(t.inherits)) or "absent"))
		elseif template:find("^Secure") then
			local kind = template:find("Header") and "Frame" or "Button"
			local ok, err = pcall(CreateFrame, kind, nil, UIParent, template)
			if ok and err then
				err:Hide()
			end
			add(("template %s: %s"):format(template, ok and "ok" or ("error: " .. tostring(err):sub(1, 60))))
		else
			add(("template %s: not asked (no C_XMLUtil)"):format(template))
		end
	end

	-- the client's own frames: there, shown, protected, how big
	for _, name in ipairs(FRAMES) do
		local f = _G[name]
		if type(f) == "table" and f.GetObjectType then
			local protected = f.IsProtected and select(2, pcall(f.IsProtected, f))
			add(("frame %s: %s protected=%s"):format(name, BT.Furniture.Describe(f), say(protected)))
		else
			add("frame " .. name .. ": absent")
		end
	end
	-- the CVars that move the client's own raid frames about
	if C_CVar and C_CVar.GetCVar then
		local cvars = {}
		for _, cvar in ipairs({ "useCompactPartyFrames", "raidOptionIsShown", "raidFramesDisplayClassColor",
			"raidFramesDisplayAggroHighlight", "raidFramesDisplayOnlyDispellableDebuffs",
			"raidFramesHealthText", "nameplateShowSelf", "showTargetOfTarget", "predictedHealth" }) do
			cvars[#cvars + 1] = cvar .. "=" .. say(select(2, pcall(C_CVar.GetCVar, cvar)))
		end
		add("cvars: " .. table.concat(cvars, " "))
	end
end

-- two curves a frame would use: debuff type to colour, and health to colour
function P.DispelCurve()
	if P.dispel ~= nil then
		return P.dispel or nil
	end
	P.dispel = false
	local ok, c = pcall(function()
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		for i = 0, 11 do
			curve:AddPoint(i, CreateColor(i / 11, 0.5, 1 - i / 11, 1))
		end
		return curve
	end)
	if ok then
		P.dispel = c
	end
	return P.dispel or nil
end

function P.HealthCurve()
	if P.health ~= nil then
		return P.health or nil
	end
	P.health = false
	local ok, c = pcall(function()
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		curve:AddPoint(0, CreateColor(0.8, 0.2, 0.2, 1))
		curve:AddPoint(1, CreateColor(0.3, 0.7, 0.5, 1))
		return curve
	end)
	if ok then
		P.health = c
	end
	return P.health or nil
end

-- ---------------------------------------------------------------------------
-- What each unit says
-- ---------------------------------------------------------------------------

local UNITS = { "player", "pet", "target", "targettarget", "focus", "mouseover", "party1", "party2",
	"raid1", "boss1", "arena1", "nameplate1" }

local function g(name)
	return _G[name]
end

local function ns(space, name)
	local t = _G[space]
	return type(t) == "table" and t[name] or nil
end

local function units(lines)
	local function add(line)
		lines[#lines + 1] = line
	end
	for _, unit in ipairs(UNITS) do
		local exists = ask(g("UnitExists"), unit)
		add(("[%s] exists=%s"):format(unit, exists))
		if exists == "true" then
			local calls = {
				{ "UnitName", unit }, { "UnitClass", unit }, { "UnitLevel", unit },
				{ "UnitEffectiveLevel", unit }, { "UnitClassification", unit },
				{ "UnitReaction", unit, "player" }, { "UnitIsPlayer", unit }, { "UnitIsEnemy", "player", unit },
				{ "UnitCanAttack", "player", unit }, { "UnitHealth", unit }, { "UnitHealthMax", unit },
				{ "UnitHealthPercent", unit }, { "UnitHealthMissing", unit },
				{ "UnitPower", unit }, { "UnitPowerMax", unit }, { "UnitPowerType", unit },
				{ "UnitPowerPercent", unit },
				{ "UnitGetIncomingHeals", unit }, { "UnitGetTotalAbsorbs", unit },
				{ "UnitGetTotalHealAbsorbs", unit }, { "UnitInRange", unit },
				{ "CheckInteractDistance", unit, 4 }, { "UnitIsConnected", unit },
				{ "UnitIsDeadOrGhost", unit }, { "UnitIsDead", unit }, { "UnitIsGhost", unit },
				{ "UnitIsAFK", unit }, { "UnitIsDND", unit }, { "UnitIsCharmed", unit },
				{ "UnitPhaseReason", unit }, { "UnitIsVisible", unit },
				{ "UnitThreatSituation", unit }, { "UnitThreatSituation", "player", unit },
				{ "UnitDetailedThreatSituation", "player", unit },
				{ "UnitGroupRolesAssigned", unit }, { "UnitIsGroupLeader", unit },
				{ "UnitIsGroupAssistant", unit }, { "GetRaidTargetIndex", unit },
				{ "UnitHasIncomingResurrection", unit }, { "UnitCastingInfo", unit },
				{ "UnitChannelInfo", unit }, { "UnitIsTapDenied", unit }, { "UnitIsPVP", unit },
				{ "UnitFactionGroup", unit }, { "UnitGUID", unit }, { "UnitIsUnit", unit, "target" },
				{ "UnitCreatureType", unit }, { "UnitSex", unit }, { "UnitRace", unit },
				{ "UnitCastingDuration", unit }, { "UnitChannelDuration", unit },
				{ "UnitHealthPercent", unit, true, _G.CurveConstants and _G.CurveConstants.ScaleTo100 },
			}
			-- arguments are named with say(), not joined as they are: a call
			-- given `true` stopped the whole unit section on the second probe
			for _, c in ipairs(calls) do
				local named = {}
				for i = 2, 5 do
					if c[i] ~= nil then
						named[#named + 1] = type(c[i]) == "string" and c[i] or say(c[i])
					end
				end
				add(("  %s(%s) = %s"):format(c[1], table.concat(named, ","), ask(g(c[1]), unpack(c, 2, 5))))
			end
			add("  C_IncomingSummon.HasIncomingSummon = " .. ask(ns("C_IncomingSummon", "HasIncomingSummon"), unit))
			add("  C_IncomingSummon.IncomingSummonStatus = " .. ask(ns("C_IncomingSummon", "IncomingSummonStatus"), unit))
			-- the first buff and the first debuff, field by field
			local byIndex = ns("C_UnitAuras", "GetAuraDataByIndex")
			for _, filter in ipairs({ "HELPFUL", "HARMFUL", "HARMFUL|RAID", "HELPFUL|PLAYER" }) do
				if byIndex then
					local ok, aura = pcall(byIndex, unit, 1, filter)
					add(("  aura 1 %s: %s"):format(filter, ok and fields(aura) or ("error: " .. tostring(aura):sub(1, 60))))
					if ok and type(aura) == "table" and not secret(aura) and aura.auraInstanceID ~= nil then
						local id = aura.auraInstanceID
						add("    GetAuraDuration = " .. ask(ns("C_UnitAuras", "GetAuraDuration"), unit, id))
						add("    GetAuraDispelTypeColor = " .. ask(ns("C_UnitAuras", "GetAuraDispelTypeColor"), unit, id))
						add("    IsAuraFilteredOutByInstanceID RAID = "
							.. ask(ns("C_UnitAuras", "IsAuraFilteredOutByInstanceID"), unit, id, "HARMFUL|RAID"))
					end
				end
			end
			-- IN A FIGHT THE AURAS WILL NOT BE READ (first probe, 09-23): what
			-- is left is the instance IDs and the helpers that take them
			if unit == "player" or unit == "target" or unit == "party1" or unit == "raid1" then
				local ids = ns("C_UnitAuras", "GetUnitAuraInstanceIDs")
				for _, filter in ipairs({ "HELPFUL", "HARMFUL", "HARMFUL|RAID_PLAYER_DISPELLABLE" }) do
					if ids then
						local ok, list = pcall(ids, unit, filter)
						local first = (ok and type(list) == "table" and not secret(list)) and list[1] or nil
						add(("  GetUnitAuraInstanceIDs %s = %s first=%s"):format(filter,
							ok and say(list) or ("error: " .. tostring(list):sub(1, 60)), say(first)))
						if first ~= nil and not secret(first) then
							add("    GetAuraDuration = " .. ask(ns("C_UnitAuras", "GetAuraDuration"), unit, first))
							add("    GetAuraDataByAuraInstanceID = "
								.. (function()
									local ok2, d = pcall(ns("C_UnitAuras", "GetAuraDataByAuraInstanceID"), unit, first)
									return ok2 and fields(d) or ("error: " .. tostring(d):sub(1, 60))
								end)())
							local curve = P.DispelCurve()
							add("    GetAuraDispelTypeColor(curve) = "
								.. ask(ns("C_UnitAuras", "GetAuraDispelTypeColor"), unit, first, curve))
							add("    GetAuraApplicationDisplayCount = "
								.. ask(ns("C_UnitAuras", "GetAuraApplicationDisplayCount"), unit, first))
						end
					end
				end
				add("  GetUnitAuras HARMFUL = " .. ask(ns("C_UnitAuras", "GetUnitAuras"), unit, "HARMFUL"))
				-- the health text a frame would print, made the only ways a
				-- secret allows: formatted by the client, never by arithmetic
				local scale = _G.CurveConstants and _G.CurveConstants.ScaleTo100
				local okP, pct = pcall(g("UnitHealthPercent"), unit, true, scale)
				add("  format(%d%%, UnitHealthPercent ScaleTo100) = "
					.. (okP and ask(string.format, "%d%%", pct) or "error"))
				add("  AbbreviateNumbers(UnitHealth) = "
					.. ask(function() return AbbreviateNumbers(UnitHealth(unit)) end))
				add("  TruncateWhenZero(UnitHealthMissing) = "
					.. ask(function() return C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)) end))
				add("  UnitHealthPercent(colour curve) = "
					.. ask(function() return UnitHealthPercent(unit, true, P.HealthCurve()) end))
				add("  UnitCastingDuration = " .. ask(g("UnitCastingDuration"), unit))
			end
			add("  UnitAura(1) = " .. ask(g("UnitAura"), unit, 1))
			add("  UnitBuff(1) = " .. ask(g("UnitBuff"), unit, 1))
			add("  UnitDebuff(1) = " .. ask(g("UnitDebuff"), unit, 1))
		end
	end
	add("group: IsInGroup=" .. ask(g("IsInGroup")) .. " IsInRaid=" .. ask(g("IsInRaid"))
		.. " GetNumGroupMembers=" .. ask(g("GetNumGroupMembers")) .. " GetRaidRosterInfo(1)="
		.. ask(g("GetRaidRosterInfo"), 1) .. " GetReadyCheckStatus(player)=" .. ask(g("GetReadyCheckStatus"), "player"))
	if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
		local r = {}
		for name, v in pairs(Enum.AddOnRestrictionType) do
			r[#r + 1] = name .. "=" .. ask(C_RestrictedActions.IsAddOnRestrictionActive, v)
		end
		table.sort(r)
		add("restrictions active: " .. table.concat(r, " "))
	end
	add("combo: GetComboPoints=" .. ask(g("GetComboPoints"), "player", "target")
		.. " UnitPower(4)=" .. ask(g("UnitPower"), "player", 4))
end

-- ---------------------------------------------------------------------------
-- Running it
-- ---------------------------------------------------------------------------

function P.Run(why)
	local lines = {}
	local combat = InCombatLockdown and InCombatLockdown() or false
	lines[#lines + 1] = ("run: %s · combat=%s · affecting=%s"):format(why or "asked", tostring(combat),
		ask(g("UnitAffectingCombat"), "player"))
	local ok, err = pcall(units, lines)
	if not ok then
		lines[#lines + 1] = "units failed: " .. tostring(err)
	end
	-- the inventory only once per session: it makes frames, and it does not
	-- change between a fight and the quiet after it
	if not P.inventoried and not combat then
		local ok2, err2 = pcall(inventory, lines)
		if not ok2 then
			lines[#lines + 1] = "inventory failed: " .. tostring(err2)
		end
		P.inventoried = true
	end
	BT.EnsureBound()
	BeebModDB.unitProbe = BeebModDB.unitProbe or {}
	local runs = BeebModDB.unitProbe
	runs[#runs + 1] = { at = U.Now(), combat = combat, lines = lines }
	while #runs > 4 do
		table.remove(runs, 1)
	end
	return #lines
end

-- and once more a moment into the next fight, where the secrets are
function P.Arm()
	if P.armed then
		return
	end
	P.armed = CreateFrame("Frame")
	P.armed:RegisterEvent("PLAYER_REGEN_DISABLED")
	P.armed:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		P.armed = nil
		local function go()
			local n = P.Run("two seconds into a fight")
			U.Print(("unit probe: %d lines from the fight · /reload after it to save them"):format(n))
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(2, go)
		else
			go()
		end
	end)
end

BT.Command("unitprobe", function(rest)
	if (rest or "") == "clear" then
		BT.EnsureBound()
		BeebModDB.unitProbe = nil
		U.Print("unit probe cleared")
		return
	end
	local n = P.Run("asked")
	P.Arm()
	U.Print(("unit probe: %d lines written down · target something and start a fight, it runs again two seconds in · /reload after to save both"):format(n))
end, "unitprobe [clear] - write down what the client tells a unit frame, now and in the next fight")
