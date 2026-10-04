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
-- file names the first), each holding one bar of every kind, showing one at a
-- time and moving bars between them as they come and go.
--
-- THE BARS GO, NOT THE CONTAINERS (Josh 2026-10-03: unticking "Show as
-- Experience Bar" brought both of the client's bars back, empty). The client
-- reads a container's own alpha before it changes the bar in it: at no alpha
-- it skips the fade-out, and the end of the fade-out is what tells it to
-- finish moving a bar across and to hide a container left empty. On this
-- client a watched faction takes the first container, so unwatching one moves
-- experience across; with both containers at no alpha, both were left shown
-- and empty, and this file, seeing them hold nothing, gave them their alpha
-- back. So a container's own alpha is the client's. What is faded is inside
-- it: every bar of a kind you have asked to hide, in either container, and
-- the frame and dividers of a container while the bar it holds is one of
-- those. The client never sets a bar's own alpha, and its fades multiply with
-- ours, so nothing it plays brings a hidden bar back.
--
-- FADED, NOT MOVED: Edit Mode owns those containers and puts back anything
-- that is reparented or hidden. At no alpha and taking no mouse, the bars are
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

-- what a bar is, by its place in a container's list: "xp", "rep" or nil
local function kindOf(i)
	if i == index("xp") then
		return "xp"
	elseif i == index("rep") then
		return "rep"
	end
	return nil
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
	return kindOf(shown)
end

-- remembered per frame: whether it took the mouse before we faded it
local faded = setmetatable({}, { __mode = "k" })

-- A bar takes the mouse on its own, for its tooltip, so a faded one is told
-- not to.
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
	elseif faded[f] then
		pcall(f.SetAlpha, f, 1)
		if f.EnableMouse then
			pcall(f.EnableMouse, f, faded[f].mouse)
		end
		faded[f] = nil
	end
end

function S.Apply()
	for _, name in ipairs(CONTAINERS) do
		local c = _G[name]
		if type(c) == "table" then
			-- every bar by its kind, shown or not, so a bar the client puts
			-- up is faded already
			local isBar = {}
			for i, bar in pairs(type(c.bars) == "table" and c.bars or {}) do
				isBar[bar] = true
				local kind = kindOf(i)
				fade(bar, kind ~= nil and S.wanted[kind] == true)
			end
			-- the frame round the bar, and the dividers on it, go with the
			-- bar it holds; Edit Mode's outline stays, for moving it
			local kind = S.ShownKind(c)
			local away = kind ~= nil and S.wanted[kind] == true
			fade(c.BarFrameTexture, away)
			local ok, children = pcall(function() return { c:GetChildren() } end)
			for _, child in ipairs(ok and children or {}) do
				if not isBar[child] and child ~= c.Selection then
					fade(child, away)
				end
			end
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

-- WHAT THE CLIENT'S BARS SAY (Josh 2026-09-29: "Showing the rep meter should
-- hide the default exp bar rep tracker" - the reputation bar stayed up while
-- the experience one went). For the Testing page: each container, what it
-- says it shows, the bars in it and which are up, the client's numbering,
-- and what was asked to be hidden.
function S.Dump()
	local lines = {}
	local function add(s) lines[#lines + 1] = s end
	local function where(f)
		local ok, p, rel, rp, x, y = pcall(f.GetPoint, f, 1)
		local relName = ok and rel and rel.GetName and rel:GetName() or tostring(rel)
		return ok and ("%s %s %s %s %s"):format(tostring(p), tostring(relName), tostring(rp), tostring(x), tostring(y)) or "?"
	end
	local function shown(f)
		local ok, v = pcall(function() return f:IsShown() end)
		return ok and tostring(v) or "?"
	end
	local function alpha(f)
		local ok, v = pcall(function() return f:GetAlpha() end)
		return ok and tostring(v) or "?"
	end
	add(("wanted: xp=%s rep=%s"):format(tostring(S.wanted.xp), tostring(S.wanted.rep)))
	local info = _G.StatusTrackingBarInfo
	local e = info and info.BarsEnum
	if type(e) == "table" then
		local parts = {}
		for k, v in pairs(e) do parts[#parts + 1] = k .. "=" .. tostring(v) end
		table.sort(parts)
		add("BarsEnum: " .. table.concat(parts, " "))
	else
		add("BarsEnum: none")
	end
	for _, name in ipairs(CONTAINERS) do
		local c = _G[name]
		if type(c) ~= "table" then
			add(name .. ": none")
		else
			add(("%s: shown=%s alpha=%s frame=%s shownBarIndex=%s pending=%s kind=%s at %s"):format(name,
				shown(c), alpha(c), type(c.BarFrameTexture) == "table" and alpha(c.BarFrameTexture) or "none",
				tostring(c.shownBarIndex), tostring(c.pendingBarToShowIndex), tostring(S.ShownKind(c)), where(c)))
			for i, bar in pairs(type(c.bars) == "table" and c.bars or {}) do
				local bn = type(bar) == "table" and bar.GetName and bar:GetName()
				add(("  bars[%s] %s shown=%s alpha=%s"):format(tostring(i), tostring(bn),
					type(bar) == "table" and shown(bar) or "?", type(bar) == "table" and alpha(bar) or "?"))
			end
			local keys = {}
			for k, v in pairs(c) do
				if type(v) ~= "function" and type(v) ~= "userdata" then keys[#keys + 1] = tostring(k) end
			end
			table.sort(keys)
			add("  fields: " .. table.concat(keys, " "))
		end
	end
	for kind, names in pairs(OLD) do
		for _, name in ipairs(names) do
			local f = _G[name]
			add(("%s (%s): %s"):format(name, kind, type(f) == "table" and ("shown=" .. shown(f) .. " alpha=" .. alpha(f)
				.. " at " .. where(f)) or "none"))
		end
	end
	-- anything else the client calls a status or tracking bar
	local more = {}
	for name, v in pairs(_G) do
		if type(name) == "string" and type(v) == "table" and v.IsShown
			and (name:find("StatusTracking") or name:find("ReputationBar") or name:find("ReputationWatch")
				or name:find("ExpBar") or name:find("StatusBar$")) then
			more[#more + 1] = name
		end
	end
	table.sort(more)
	for _, name in ipairs(more) do
		local f = _G[name]
		add(("%s: shown=%s alpha=%s at %s"):format(name, shown(f), alpha(f), where(f)))
	end
	BT.EnsureBound()
	BeebModDB.statusbarsDump = {
		at = BT.Util and BT.Util.Now and BT.Util.Now() or 0,
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	return #lines
end
BT.Record("statusbarsDump", S.Dump)

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
	-- and whenever a container changes the bar it holds, and at the start and
	-- end of its fades, for a build that changes it some other way
	for _, name in ipairs(CONTAINERS) do
		local c = _G[name]
		if type(c) == "table" then
			if type(c.ApplyPendingBarToShow) == "function" and hooksecurefunc then
				pcall(hooksecurefunc, c, "ApplyPendingBarToShow", later)
			end
			for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }) do
				local anim = c[key]
				if type(anim) == "table" and anim.HookScript then
					pcall(anim.HookScript, anim, "OnPlay", later)
					pcall(anim.HookScript, anim, "OnFinished", later)
				end
			end
		end
	end
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
