-- Debug: name the protected call (Josh 2026-09-18).
--
-- "BeebMod has been blocked from an action only available to the Blizzard UI"
-- is ADDON_ACTION_BLOCKED, and the popup never says WHICH action. The event
-- does, along with a stack, so we print both and the fix becomes obvious.
--
-- This file is for the beta shakedown and comes out once the cause is fixed.
local ADDON, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Blocked.lua")

-- WHOSE A FRAME'S FIELDS ARE (Josh 2026-11-20: a player's leather armor kit,
-- used from the bags, was refused). The game refuses a protected call when
-- the code on the way to it read anything an addon wrote. issecurevariable
-- says, field by field, which of a table's fields are the game's own and
-- which addon wrote the others. Scan counts the ones that are not the game's
-- into `found`, by field and addon, and leaves BeebMod's own fields out
-- (beebs..., bmShadow): the game never reads those.
BT.Taint = {}
local Taint = BT.Taint

function Taint.Can()
	return type(rawget(_G, "issecurevariable")) == "function"
end

function Taint.Scan(t, found)
	local check = rawget(_G, "issecurevariable")
	if type(check) ~= "function" or type(t) ~= "table" then
		return false
	end
	local hit = false
	for key in pairs(t) do
		if type(key) == "string" and not key:find("^beebs") and not key:find("^bm%u") then
			local ok, secure, by = pcall(check, t, key)
			if ok and not secure then
				local name = key .. " by " .. ((by ~= nil and by ~= "") and tostring(by) or "?")
				found[name] = (found[name] or 0) + 1
				hit = true
			end
		end
	end
	return hit
end

function Taint.Said(found, most)
	local names = {}
	for name, n in pairs(found) do
		names[#names + 1] = n > 1 and ("%s x%d"):format(name, n) or name
	end
	table.sort(names)
	local more = #names - most
	while #names > most do
		table.remove(names)
	end
	if #names == 0 then
		return "none"
	end
	return table.concat(names, ", ") .. (more > 0 and (" and %d more"):format(more) or "")
end

-- THE OTHER FRAMES A KIT GOES THROUGH. Using a kit or an enchant opens the
-- character window (GameEvent.HandleEnchantSpellSelected, then
-- ToggleCharacter), a click on an equipped item runs
-- PaperDollItemSlotButton_OnClick, and replacing an enchant asks in a popup.
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs",
	"Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }
local GROUPS = {
	{ "character window", { "CharacterFrame", "PaperDollFrame", "PaperDollItemsFrame" } },
	{ "equipped slots", SLOTS, "Character%sSlot" },
	{ "popups", { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" } },
	{ "vendor window", { "MerchantFrame" } },
}
local GLOBALS = { "FRAME_THAT_OPENED_BAGS", "UIPanelWindows", "StaticPopupDialogs", "ToggleCharacter", "ShowUIPanel",
	"PaperDollItemSlotButton_OnClick", "ContainerFrameItemButton_OnClick" }

function Taint.Others()
	if not Taint.Can() then
		return nil
	end
	local parts = {}
	for _, group in ipairs(GROUPS) do
		local found = {}
		for _, name in ipairs(group[2]) do
			Taint.Scan(rawget(_G, group[3] and group[3]:format(name) or name), found)
		end
		parts[#parts + 1] = group[1] .. " " .. Taint.Said(found, 8)
	end
	local check, globals = rawget(_G, "issecurevariable"), {}
	for _, name in ipairs(GLOBALS) do
		local ok, secure, by = pcall(check, name)
		if ok and not secure then
			globals[#globals + 1] = name .. " by " .. tostring(by)
		end
	end
	parts[#parts + 1] = "globals " .. (#globals > 0 and table.concat(globals, ", ") or "none")
	return table.concat(parts, " · ")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:SetScript("OnEvent", function(_, event, addon, func)
	-- the event names the addon by its folder, which is what the loader handed
	-- us as ADDON; it was "Ledger" once, and that string filtered out every
	-- report after the rename
	if addon ~= ADDON then
		return
	end
	-- once per function, ever: a blocked call that repeats would otherwise
	-- fill the chat frame with the same line (Josh 2026-09-18)
	BT.blocked = BT.blocked or {}
	local key = tostring(func) .. "/" .. tostring(BT.registering)
	if BT.blocked[key] then
		return
	end
	BT.blocked[key] = true
	-- WRITTEN DOWN, NOT SHOUTED (Josh 2026-09-19). This used to put the event
	-- and ten frames of stack straight into the chat frame, which is the exact
	-- addon spam it exists to diagnose. What loaded, on the Testing page,
	-- prints what was collected.
	local while_ = BT.registering and (" while registering " .. BT.registering) or ""
	BT.blockedLog = BT.blockedLog or {}
	BT.blockedLog[#BT.blockedLog + 1] = ("%s calling %s%s"):format(event, tostring(func), while_)
	if debugstack then
		BT.blockedStack = debugstack(2, 10, 0)
	end
	-- WHOSE THE BAG SLOTS WERE WHEN IT HAPPENED (Josh 2026-11-20: reports of
	-- items refused when used from the bags). The bag window names every field
	-- on the game's bag windows and slots that an addon wrote
	-- (Modules/BagWindow/BagWindow.lua, M.Taint).
	local window = BT.GetModule and BT.GetModule("bagwindow")
	if window and window.Taint then
		local ok, taint = pcall(window.Taint)
		if ok and taint then
			BT.blockedLog[#BT.blockedLog + 1] = "then: " .. taint
		end
	end
	local okOthers, others = pcall(Taint.Others)
	if okOthers and others then
		BT.blockedLog[#BT.blockedLog + 1] = "then: " .. others
	end
	-- KEPT IN THE SAVED FILE TOO (2026-10-04: "Interface action failed
	-- because of an AddOn", and the list had gone with the reload)
	-- ONLY IN A COPY TO WORK ON (2026-10-17, audit): a player's copy has no
	-- Record button to read it or clear it (BT.DEV)
	if BT.DEV and type(BeebModDB) == "table" then
		BeebModDB.blockedDump = { at = BT.Util.Now(), lines = BT.blockedLog, stack = BT.blockedStack }
	end
end)

-- WHO LOADED THE GUILD WINDOW (Josh 2026-11-06, The Hall of Thanes). A guild
-- rank update mid-fight ran the guild settings' own code, and the game
-- forbade its Discord calls as BeebMod's. That code is loaded with the guild
-- window (Blizzard_Communities lists Blizzard_GuildControlUI as a
-- dependency), and loaded from tainted code, all of it is tainted. Opening
-- the window from the dock's guild button loaded it clean (issecurevariable
-- said true), so something else loaded it that night. When either loads,
-- this writes down whether the load was clean, whose taint it carried, and
-- the stack that loaded it.
local WATCH_LOADS = { Blizzard_Communities = "CommunitiesFrame", Blizzard_GuildControlUI = "GuildControlUI_Setup" }
local loads = CreateFrame("Frame")
loads:RegisterEvent("ADDON_LOADED")
loads:SetScript("OnEvent", function(_, _, name)
	local probe = WATCH_LOADS[name]
	if not (probe and BT.DEV) then
		return
	end
	local secure, by = true, nil
	if issecurevariable then
		local ok, s, t = pcall(issecurevariable, probe)
		if ok then
			secure, by = s, t
		end
	end
	BT.blockedLog = BT.blockedLog or {}
	BT.blockedLog[#BT.blockedLog + 1] = ("%s loaded: %s"):format(name,
		secure and "clean" or ("tainted by " .. tostring(by)))
	if debugstack then
		BT.blockedStack = debugstack(2, 20, 0)
	end
	if type(BeebModDB) == "table" then
		BeebModDB.blockedDump = { at = BT.Util.Now(), lines = BT.blockedLog, stack = BT.blockedStack }
	end
end)

-- the record is written when it happens; this only says there is one
BT.Record("blockedDump", function()
	return BT.blockedLog and #BT.blockedLog or nil
end)

-- THE GAME'S TAINT LOG, FROM A SWITCH (Josh 2026-11-08: start on the taint
-- sweep). With the console variable taintLog at 2 the game writes every
-- taint it sees into Logs\taint.log, which Claude reads after you quit. It
-- may not last past a launch, so BeebMod remembers the switch in the saved
-- file and sets it again at login. Only in a copy to work on
-- (BT.DEV): the Testing page holds the switch.
BT.TaintLog = {}
local TL = BT.TaintLog
TL.CVAR, TL.ON = "taintLog", "2"

local function getCVar(name)
	local c = rawget(_G, "C_CVar")
	local get = c and c.GetCVar or rawget(_G, "GetCVar")
	if type(get) ~= "function" then
		return nil
	end
	local ok, v = pcall(get, name)
	return ok and v or nil
end

local function setCVar(name, value)
	local c = rawget(_G, "C_CVar")
	local set = c and c.SetCVar or rawget(_G, "SetCVar")
	if type(set) ~= "function" then
		return false
	end
	return pcall(set, name, value) and true or false
end

-- whether the game is writing the log now
function TL.IsOn()
	local v = getCVar(TL.CVAR)
	return v ~= nil and tostring(v) ~= "0" and tostring(v) ~= ""
end

-- on or off, remembered; true when the game took it
function TL.Set(on)
	on = on and true or false
	if BT.EnsureBound then
		BT.EnsureBound()
	end
	if type(BeebModDB) == "table" then
		BeebModDB.taintLog = on or nil
	end
	setCVar(TL.CVAR, on and TL.ON or "0")
	return TL.IsOn() == on
end

-- at login: on again, if the switch was left on
function TL.Apply()
	if BT.DEV and type(BeebModDB) == "table" and BeebModDB.taintLog and not TL.IsOn() then
		setCVar(TL.CVAR, TL.ON)
	end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	TL.Apply()
end)
