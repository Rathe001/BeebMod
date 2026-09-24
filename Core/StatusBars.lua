-- The client's own experience and reputation bars, out of the way while ours
-- are up (Josh 2026-09-22).
--
-- The Experience and Reputation lines in the dock say what the bars across
-- the top of the screen say, so each has a switch - on by default - to put the
-- client's version away. This is the one place that does it for both.
--
-- WHICH BAR IS WHERE IS THE CLIENT'S BUSINESS. This build uses the modern
-- status bars: two containers (MainStatusTrackingBarContainer and
-- SecondaryStatusTrackingBarContainer, both Edit Mode systems - its layout
-- file names the first), each showing one bar at a time and moving bars
-- between them as they come and go. So a container is not "the experience
-- bar"; it is asked what it is showing, every time that might have changed,
-- and faded only while that is a bar you have asked to hide.
--
-- FADED, NOT MOVED: Edit Mode owns those containers and puts back anything
-- that is reparented or hidden. At no alpha and taking no mouse, they are
-- simply not there to see or to point at. The older single-bar frames are
-- covered too, for a build that still has them.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/StatusBars.lua")

local S = {}
BT.StatusBars = S

S.wanted = { xp = false, rep = false }

local CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local OLD = { xp = { "MainMenuExpBar", "ExhaustionTick" }, rep = { "ReputationWatchBar" } }

-- the client's numbering of its bars, with the retail values where it has none
local function index(kind)
	local info = _G.StatusTrackingBarInfo
	local e = info and info.BarsEnum
	if kind == "xp" then
		return (e and e.Experience) or 4
	end
	return (e and e.Reputation) or 1
end

-- what a container is showing: "xp", "rep" or nil
function S.ShownKind(container)
	if type(container) ~= "table" then
		return nil
	end
	local shown = container.shownBarIndex
	if shown == nil and type(container.bars) == "table" then
		for i, bar in pairs(container.bars) do
			if type(bar) == "table" and bar.IsShown and bar:IsShown() then
				shown = i
			end
		end
	end
	if shown == nil then
		return nil
	end
	if shown == index("xp") then
		return "xp"
	elseif shown == index("rep") then
		return "rep"
	end
	return nil
end

-- remembered per frame: whether it took the mouse before we faded it
local faded = setmetatable({}, { __mode = "k" })

local function fade(f, away)
	if type(f) ~= "table" or not f.SetAlpha then
		return
	end
	if away then
		if faded[f] == nil then
			local ok, mouse = pcall(function() return f.IsMouseEnabled and f:IsMouseEnabled() end)
			faded[f] = { mouse = ok and mouse or false }
		end
		pcall(f.SetAlpha, f, 0)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, false)
		end
		-- the bars inside take the mouse on their own, for their tooltips
		for _, bar in pairs(type(f.bars) == "table" and f.bars or {}) do
			if type(bar) == "table" and bar.EnableMouse then
				if faded[bar] == nil then
					local ok, mouse = pcall(function() return bar.IsMouseEnabled and bar:IsMouseEnabled() end)
					faded[bar] = { mouse = ok and mouse or false }
				end
				pcall(bar.EnableMouse, bar, false)
			end
		end
	elseif faded[f] then
		pcall(f.SetAlpha, f, 1)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, faded[f].mouse)
		end
		for _, bar in pairs(type(f.bars) == "table" and f.bars or {}) do
			if faded[bar] and bar.EnableMouse then
				pcall(bar.EnableMouse, bar, faded[bar].mouse)
				faded[bar] = nil
			end
		end
		faded[f] = nil
	end
end

function S.Apply()
	for _, name in ipairs(CONTAINERS) do
		local c = _G[name]
		if c then
			local kind = S.ShownKind(c)
			fade(c, kind ~= nil and S.wanted[kind] == true)
		end
	end
	for kind, names in pairs(OLD) do
		for _, name in ipairs(names) do
			fade(_G[name], S.wanted[kind] == true)
		end
	end
end

-- Say whether the client's bar of a kind should be hidden.
function S.Set(kind, hide)
	S.wanted[kind] = hide and true or false
	S.Watch()
	S.Apply()
end

-- Again whenever the client might have moved a bar between containers: a
-- frame later, once it has.
-- ONE WAITING AT A TIME (Josh 2026-09-23, /bt cpu: 225 a second): the bar
-- manager lays out on every change of a setting, and each asked for a frame of
-- its own; however many ask in a frame, the bars are put right once.
local waiting = false
local function later()
	if waiting then
		return
	end
	if C_Timer and C_Timer.After then
		waiting = true
		C_Timer.After(0, function()
			waiting = false
			S.Apply()
		end)
	else
		S.Apply()
	end
end
S.Later = later

function S.Watch()
	if S.events then
		return S.events
	end
	S.events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
		"UPDATE_EXHAUSTION", "UPDATE_FACTION", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN" }) do
		pcall(S.events.RegisterEvent, S.events, event)
	end
	S.events:SetScript("OnEvent", later)
	-- and after the manager lays the bars out itself
	local manager = _G.StatusTrackingBarManager
	if type(manager) == "table" and hooksecurefunc then
		for _, fn in ipairs({ "UpdateBarsShown", "UpdateBarVisibility" }) do
			if type(manager[fn]) == "function" then
				pcall(hooksecurefunc, manager, fn, later)
			end
		end
	end
	return S.events
end
