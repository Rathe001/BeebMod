-- Double right-click to fish (Josh 2026-11-05: "There is a simple addon called
-- Fishing Buddy that lets you double right click to cast fishing when a
-- fishing pole is equipped", then "On by default" and "Should be in the
-- general settings probably").
--
-- HOW IT CASTS. An addon can't cast a spell from its own code, but a secure
-- button can, when the player presses it. So:
--
--   1. a right-click on the world is heard (WorldFrame's OnMouseDown)
--   2. a second one within DOUBLE seconds, with a fishing pole in your hands,
--      points the right mouse button at our hidden button for a moment
--      (SetOverrideBindingClick)
--   3. letting go of the button is then a click on ours, which casts Fishing
--   4. its PostClick gives the right mouse button back
--
-- The same way Fishing Buddy does it (LibFishing). Not in a fight: the game
-- lets nothing change what a key does then. Not on a person or an NPC, so a
-- double-click on one still talks to them or opens their menu. Not mounted,
-- swimming or flying, where Fishing can't be cast anyway. The cast acts on
-- the release (useOnKeyDown false), since the press has already gone to the
-- world by the time the button is pointed at ours.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Fishing/Fishing.lua")

local M = BT.Module({
	key = "fishing",
	title = "Double-click to fish",
	order = 99,
})

-- two right-clicks closer together than this are a double-click
M.DOUBLE = 0.4
-- the right mouse button is given back after this long even if no click came
M.GIVE_BACK = 1

-- Fishing's ranks, Apprentice to Artisan; cast by name, the game picks the
-- highest you know
M.SPELLS = { 7620, 7731, 7732, 18248 }
M.MAIN_HAND = 16
M.WEAPON, M.POLE = 2, 20

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g = pcall(fn, ...)
	if ok then
		return a, b, c, d, e, f, g
	end
	return nil
end

-- the name of Fishing as you know it, or nil if you don't
function M.SpellName()
	local spell = rawget(_G, "C_Spell")
	for _, id in ipairs(M.SPELLS) do
		if call(_G.IsPlayerSpell, id) or call(_G.IsSpellKnown, id) then
			local name = (spell and call(spell.GetSpellName, id)) or call(_G.GetSpellInfo, id)
			if type(name) == "string" and name ~= "" then
				return name
			end
		end
	end
	return nil
end

-- a fishing pole in your main hand
function M.HasPole()
	local id = call(_G.GetInventoryItemID, "player", M.MAIN_HAND)
	if not id then
		return false
	end
	local item = rawget(_G, "C_Item")
	local get = (item and item.GetItemInfoInstant) or _G.GetItemInfoInstant
	local _, _, _, _, _, class, sub = call(get, id)
	return class == M.WEAPON and sub == M.POLE
end

-- whether a double-click here and now should cast
function M.Wanted()
	if not BT.Enabled("fishing") then
		return false
	end
	if call(_G.InCombatLockdown) then
		return false
	end
	if call(_G.UnitExists, "mouseover") then
		return false
	end
	if call(_G.IsMounted) or call(_G.IsSwimming) or call(_G.IsFlying) then
		return false
	end
	return M.HasPole() and M.SpellName() ~= nil
end

-- ---------------------------------------------------------------------------
-- The button
-- ---------------------------------------------------------------------------

function M.Build()
	if M.button then
		return M.button
	end
	local b = CreateFrame("Button", "BeebModFishingButton", UIParent, "SecureActionButtonTemplate")
	b:SetSize(1, 1)
	b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	b:EnableMouse(false)
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("type", "spell")
	b:SetAttribute("useOnKeyDown", false)
	b:SetScript("PostClick", function()
		M.GiveBack()
	end)
	M.button = b
	return b
end

-- the right mouse button pointed at ours; whether it was
function M.Take()
	local b = M.Build()
	local name = M.SpellName()
	if not name or call(_G.InCombatLockdown) then
		return false
	end
	b:SetAttribute("spell", name)
	-- a drag to turn the camera is already going: end it, or the release is
	-- the camera's and not ours
	if call(_G.IsMouselooking) then
		call(_G.MouselookStop)
	end
	if type(_G.SetOverrideBindingClick) ~= "function" then
		return false
	end
	local ok = pcall(_G.SetOverrideBindingClick, b, true, "BUTTON2", "BeebModFishingButton")
	if not ok then
		return false
	end
	M.taken = true
	if C_Timer and C_Timer.After then
		C_Timer.After(M.GIVE_BACK, function()
			M.GiveBack()
		end)
	end
	return true
end

-- the right mouse button does what it did again
function M.GiveBack()
	if not (M.taken and M.button) then
		return false
	end
	if call(_G.InCombatLockdown) then
		return false
	end
	call(_G.ClearOverrideBindings, M.button)
	M.taken = false
	return true
end

-- ---------------------------------------------------------------------------
-- The clicks
-- ---------------------------------------------------------------------------

function M.MouseDown(button)
	if button ~= "RightButton" then
		return false
	end
	local now = tonumber(call(_G.GetTime)) or 0
	local last = M.lastRight
	M.lastRight = now
	if not (last and now - last <= M.DOUBLE) then
		return false
	end
	M.lastRight = nil
	if not M.Wanted() then
		return false
	end
	return M.Take()
end

function M.Hook()
	if M.hooked then
		return true
	end
	local world = rawget(_G, "WorldFrame")
	if not (type(world) == "table" and type(world.HookScript) == "function") then
		return false
	end
	M.hooked = true
	world:HookScript("OnMouseDown", function(_, button)
		local ok, err = pcall(M.MouseDown, button)
		if not ok then
			BT.Err("fishing.click: " .. tostring(err))
		end
	end)
	return true
end

-- a fight starting while the button is ours: given back while the game
-- still allows it
M.events = CreateFrame("Frame")
pcall(M.events.RegisterEvent, M.events, "PLAYER_REGEN_DISABLED")
M.events:SetScript("OnEvent", function()
	M.GiveBack()
end)

function M:OnEnable()
	M.Build()
	M.Hook()
end

M.OnBind = M.OnEnable

function M:OnDisable()
	M.lastRight = nil
	M.GiveBack()
end
