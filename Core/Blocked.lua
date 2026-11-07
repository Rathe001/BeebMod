-- Debug: name the protected call (Josh 2026-09-18).
--
-- "BeebMod has been blocked from an action only available to the Blizzard UI"
-- is ADDON_ACTION_BLOCKED, and the popup never says WHICH action. The event
-- does, along with a stack, so we print both and the fix becomes obvious.
--
-- This file is for the beta shakedown and comes out once the cause is fixed.
local ADDON, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Blocked.lua")

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
