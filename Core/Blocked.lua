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
	-- addon spam it exists to diagnose. /bt debug prints what was collected.
	local while_ = BT.registering and (" while registering " .. BT.registering) or ""
	BT.blockedLog = BT.blockedLog or {}
	BT.blockedLog[#BT.blockedLog + 1] = ("%s calling %s%s"):format(event, tostring(func), while_)
	if debugstack then
		BT.blockedStack = debugstack(2, 10, 0)
	end
end)
