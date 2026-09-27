-- Boot: the core's own login (Josh 2026-09-26).
--
-- THE CORE LOGS ITSELF IN. The census's collector used to do it: its
-- loading-screen handler bound the settings every module reads and built the
-- dock, and its target handler was the only thing that told the dock the
-- target had changed - so an addon without a census would have had no
-- settings and no dock. Those are the core's, here; the collector does only
-- the census's work, after the core has bound (BT.OnWorld), as anything else
-- that must wait for the world can.
--
--   BT.OnWorld(fn)   fn(initial, reloading) after every loading screen,
--                    once the settings and the book are bound
local _, BT = ...
local CreateFrame = BT.Cpu.For("Core/Boot.lua")

local U = BT.Util
local Boot = {}
BT.Boot = Boot

local listeners = {}
function BT.OnWorld(fn)
	listeners[#listeners + 1] = fn
end

Boot.handlers = {}
local handlers = Boot.handlers

handlers.PLAYER_ENTERING_WORLD = function(_, _, initial, reloading)
	local realm = GetRealmName and GetRealmName() or nil
	local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
	U.realm = realm
	U.LearnRealm(realm)
	-- the realm and faction are only knowable now. A plain zone-in (the
	-- client says neither login nor reload) with everything already bound
	-- does not bind it all again (see BT.Rebind).
	if initial == false and reloading == false then
		BT.Rebind(realm, faction)
	else
		BT.Bind(realm, faction)
	end
	if BT.Bar then
		BT.Bar.Create()
	end
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, initial, reloading)
		if not ok then
			-- remembered, not announced: /bt debug lists these
			Boot.failed = Boot.failed or {}
			Boot.failed[#Boot.failed + 1] = tostring(err)
		end
	end
end

-- light the dock's target row up, or let it go dark
handlers.PLAYER_TARGET_CHANGED = function()
	if BT.Bar then
		BT.Bar.Update()
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
	local h = handlers[event]
	if h then
		h(self, event, ...)
	end
end)
for event in pairs(handlers) do
	-- pcall, and the name left for Core/Blocked.lua: an event this client
	-- keeps for itself raises ADDON_ACTION_FORBIDDEN inside RegisterEvent
	BT.registering = event
	local ok, err = pcall(frame.RegisterEvent, frame, event)
	BT.registering = nil
	if not ok then
		Boot.refused = Boot.refused or {}
		Boot.refused[event] = tostring(err)
	end
end

-- last resort: if the login event itself was refused, bind when the addon loads
function Boot.Fallback()
	if Boot.refused and Boot.refused.PLAYER_ENTERING_WORLD then
		BT.Bind(GetRealmName and GetRealmName(), UnitFactionGroup and UnitFactionGroup("player"))
		if BT.Bar then
			BT.Bar.Create()
		end
	end
end
