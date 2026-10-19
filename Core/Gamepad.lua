-- BeebMod's windows, for a controller (Josh 2026-10-18: "One thing I have
-- not tested at all is controller support").
--
-- THE CLIENT'S OWN NAVIGATION. This client's game type is "camelot", and
-- Blizzard_Gamepad loads for it (the forever branch's
-- Blizzard_Gamepad.toc): with a controller, the D-pad moves a cursor from
-- button to button in the windows it is told about. A window says it is
-- open with GamepadMode.FrameControlsManager:FrameShown(frame) and closed
-- with :FrameHidden(frame), as the client's buff frame and guild roster do,
-- only while InputUtil.IsGamepadUIEnabled(). The navigation finds the
-- buttons itself: any Button or EditBox in the window, and anything with a
-- mouse-down or mouse-up script (Blizzard_GamepadSmartNavigation/Utility.lua,
-- SmartNavigation_CanFocusFrame).
--
--   BT.Gamepad.Watch(frame)   a window of ours, told about as it shows and
--                             hides
--
-- NOT IN A FIGHT. The manager sets the controller's bindings when a window
-- comes and goes, and called from an addon that may be refused in a fight.
-- A window opened in a fight is not told about; one closed in a fight is
-- told when the fight ends.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Core/Gamepad.lua")

local G = { told = {}, owed = {} }
BT.Gamepad = G

-- the client's manager while the controller interface is on, or nil
function G.Manager()
	local ok, on = pcall(function()
		return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
	end)
	if not (ok and on == true) then
		return nil
	end
	local m = GamepadMode and GamepadMode.FrameControlsManager
	return type(m) == "table" and type(m.FrameShown) == "function" and m or nil
end

local function fighting()
	return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

function G.Shown(frame)
	local m = G.Manager()
	if not m or fighting() then
		return false
	end
	G.owed[frame] = nil
	local ok = pcall(m.FrameShown, m, frame)
	if ok then
		G.told[frame] = true
	end
	return ok
end

function G.Hidden(frame)
	if not G.told[frame] then
		return false
	end
	if fighting() then
		G.owed[frame] = true
		return false
	end
	G.told[frame], G.owed[frame] = nil, nil
	local m = GamepadMode and GamepadMode.FrameControlsManager
	if type(m) == "table" and type(m.FrameHidden) == "function" then
		pcall(m.FrameHidden, m, frame)
	end
	return true
end

local watched = setmetatable({}, { __mode = "k" })
function G.Watch(frame)
	if not frame or watched[frame] or not frame.HookScript then
		return frame
	end
	watched[frame] = true
	frame:HookScript("OnShow", G.Shown)
	frame:HookScript("OnHide", G.Hidden)
	-- a window built already open
	if frame.IsShown and frame:IsShown() then
		G.Shown(frame)
	end
	return frame
end

-- when a fight ends: what closed in it is told, unless it is open again,
-- and what opened in it and is still open
function G.AfterFight()
	for frame in pairs(G.owed) do
		if frame.IsShown and frame:IsShown() then
			G.owed[frame] = nil
		else
			G.Hidden(frame)
		end
	end
	for frame in pairs(watched) do
		if not G.told[frame] and frame.IsShown and frame:IsShown() then
			G.Shown(frame)
		end
	end
end
local after = CreateFrame("Frame")
after:RegisterEvent("PLAYER_REGEN_ENABLED")
after:SetScript("OnEvent", G.AfterFight)
