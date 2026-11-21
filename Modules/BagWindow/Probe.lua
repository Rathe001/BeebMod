-- Can the game's bag slots be put somewhere else? (Josh 2026-11-21)
--
-- "How difficult would it be to arrange the BeebMod bag so it uses
-- categories?" The bag window only dresses the game's slots, and the game
-- places them. Categories mean BeebMod places every slot. Before that is
-- built, this finds out what the game allows, from a switch on the Testing
-- page:
--
--   whether a slot is protected, and so may not be moved in a fight
--   whether a slot BeebMod moved still uses, drags and sells its item, or the
--     game blocks the action as BeebMod's (Core/Blocked.lua writes that down)
--   when the game lays its slots out again, and whether ours can go back
--     straight after
--   whether a slot can be moved while you fight
--
-- ON, every shown slot of the open bags trades places with its neighbour: an
-- item is drawn where the next one was. That is plain to see, and it puts
-- BeebMod's hand on every slot's place, as a category layout would. OFF, each
-- goes back where the game had it. Everything seen is kept in
-- BeebModDB.bagProbe, which Claude reads after a /reload.
local _, BT = ...
local CreateFrame, C_Timer, hooksecurefunc = BT.Cpu.For("Modules/BagWindow/Probe.lua")

local U = BT.Util
local M = BT.GetModule("bagwindow")
local P = {}
M.Probe = P

P.on = false
P.lines = {}
-- [slot] = the points the game gave it, to put back
P.home = {}
-- [window] = true once its layout is watched
P.watched = {}
P.layouts, P.replaced = 0, 0

local function say(text)
	P.lines[#P.lines + 1] = ("%s %s"):format(date and date("%H:%M:%S") or "?", text)
	while #P.lines > 200 do
		table.remove(P.lines, 1)
	end
end

local function fighting()
	return InCombatLockdown and InCombatLockdown() and true or false
end

-- written at every step: a crash or a logout in the middle loses nothing
function P.Save()
	if type(BeebModDB) ~= "table" then
		return
	end
	local blocked = {}
	for i, line in ipairs(BT.blockedLog or {}) do
		blocked[i] = line
	end
	BeebModDB.bagProbe = {
		at = U.Now(),
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		on = P.on,
		layouts = P.layouts,
		replaced = P.replaced,
		lines = P.lines,
		blocked = blocked,
		stack = BT.blockedStack,
	}
end

local function points(slot)
	local out = {}
	local n = slot.GetNumPoints and slot:GetNumPoints() or 0
	for i = 1, n do
		out[i] = { slot:GetPoint(i) }
	end
	return out
end

local function place(slot, pts)
	local ok, err = pcall(function()
		slot:ClearAllPoints()
		for _, p in ipairs(pts) do
			slot:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end)
	return ok, err
end

-- the shown slots of a window, in the order the game numbers them
local function shown(window)
	local out = {}
	for _, slot in ipairs(M.Slots(window)) do
		if slot.IsShown and slot:IsShown() then
			out[#out + 1] = slot
		end
	end
	table.sort(out, function(a, b)
		local ba, bb = (a.GetBagID and a:GetBagID()) or 0, (b.GetBagID and b:GetBagID()) or 0
		if ba ~= bb then
			return ba < bb
		end
		return (a.GetID and a:GetID() or 0) < (b.GetID and b:GetID() or 0)
	end)
	return out
end

-- each slot of a window in its neighbour's place; how many moved and how
-- many the game refused
function P.Swap(window)
	local slots = shown(window)
	local moved, refused, why = 0, 0, nil
	for i = 1, #slots - 1, 2 do
		local a, b = slots[i], slots[i + 1]
		local pa, pb = points(a), points(b)
		-- where the game had it, kept the first time only: a second swap must
		-- not take our own place for the game's
		P.home[a], P.home[b] = P.home[a] or pa, P.home[b] or pb
		local okA, errA = place(a, P.home[b])
		local okB, errB = place(b, P.home[a])
		if okA and okB then
			moved = moved + 2
		else
			refused = refused + 2
			why = why or tostring(errA or errB)
		end
	end
	return moved, refused, why
end

function P.Restore()
	local back, refused = 0, 0
	for slot, pts in pairs(P.home) do
		if place(slot, pts) then
			back = back + 1
		else
			refused = refused + 1
		end
	end
	if refused == 0 then
		P.home = {}
	end
	return back, refused
end

local function describe(window)
	local name = BT.Furniture.Call(window, "GetName") or "?"
	local slots = shown(window)
	local first = slots[1]
	local protected, explicit = nil, nil
	if first and first.IsProtected then
		local ok, p, e = pcall(first.IsProtected, first)
		if ok then
			protected, explicit = p, e
		end
	end
	local wprot = nil
	if window.IsProtected then
		local ok, p = pcall(window.IsProtected, window)
		wprot = ok and p or nil
	end
	return ("%s: %d shown slots · slot protected=%s explicit=%s · window protected=%s · layout call=%s"):format(
		name, #slots, tostring(protected), tostring(explicit), tostring(wprot), type(window.UpdateItemLayout))
end

local function openWindows()
	local out = {}
	for _, w in ipairs(M.Windows()) do
		if w.IsShown and w:IsShown() then
			out[#out + 1] = w
		end
	end
	return out
end

-- THE GAME LAYS ITS SLOTS OUT AGAIN when a bag changes size or the windows
-- are set up afresh. A category layout would put its own places back straight
-- after, so this does, and counts both.
local function watch(window)
	if P.watched[window] or type(window.UpdateItemLayout) ~= "function" or not hooksecurefunc then
		return
	end
	P.watched[window] = true
	hooksecurefunc(window, "UpdateItemLayout", function(w)
		P.layouts = P.layouts + 1
		if not P.on then
			return
		end
		-- the game has just put every slot home: those are the places to
		-- keep now, and the swap goes on again from them
		for _, slot in ipairs(M.Slots(w)) do
			P.home[slot] = nil
		end
		local moved, refused, why = P.Swap(w)
		P.replaced = P.replaced + 1
		if P.replaced <= 12 or refused > 0 then
			say(("the game laid out %s again (fight=%s): put back %d, refused %d%s"):format(
				BT.Furniture.Call(w, "GetName") or "?", tostring(fighting()), moved, refused,
				why and (" · " .. why:sub(1, 120)) or ""))
		end
		P.Save()
	end)
end

function P.Start()
	local windows = openWindows()
	if #windows == 0 then
		U.Print("Bag probe: open your bags first, then switch it on.")
		return false
	end
	P.on = true
	say(("on · fight=%s"):format(tostring(fighting())))
	for _, w in ipairs(windows) do
		say(describe(w))
		watch(w)
		local moved, refused, why = P.Swap(w)
		say(("swapped %d, refused %d%s"):format(moved, refused, why and (" · " .. why:sub(1, 160)) or ""))
	end
	P.Save()
	U.Print("Bag probe: on. Each item is drawn in its neighbour's place. Use one, drag one, sell one, "
		.. "and use one in a fight. Then switch it off and type /reload.")
	return true
end

function P.Stop()
	P.on = false
	local back, refused = P.Restore()
	say(("off · put back %d, refused %d · fight=%s"):format(back, refused, tostring(fighting())))
	P.Save()
	U.Print("Bag probe: off. Type /reload to save what it saw.")
end

function P.Set(on)
	if on and not P.on then
		return P.Start()
	elseif not on and P.on then
		P.Stop()
	end
	return P.on
end

-- A FIGHT: whether a slot can be moved once it has begun. One swap back and
-- forth as it starts, and the count of what the game refused.
P.events = CreateFrame("Frame")
P.events:RegisterEvent("PLAYER_REGEN_DISABLED")
P.events:RegisterEvent("PLAYER_REGEN_ENABLED")
P.events:RegisterEvent("PLAYER_LOGOUT")
P.events:SetScript("OnEvent", function(_, event)
	if not P.on then
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		-- a frame later: the lockdown is on by then
		local function try()
			for _, w in ipairs(openWindows()) do
				local back, backRefused = P.Restore()
				local moved, refused, why = P.Swap(w)
				say(("in a fight (lockdown=%s) %s: put home %d, refused %d · swapped again %d, refused %d%s"):format(
					tostring(fighting()), BT.Furniture.Call(w, "GetName") or "?", back, backRefused, moved, refused,
					why and (" · " .. why:sub(1, 160)) or ""))
			end
			if #openWindows() == 0 then
				say("in a fight: no bag open")
			end
			P.Save()
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.5, try)
		else
			try()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		say("the fight ended")
		P.Save()
	else
		P.Save()
	end
end)

-- cleared with the other records, and dropped when a day old (Core/Init.lua)
BT.Record("bagProbe")
