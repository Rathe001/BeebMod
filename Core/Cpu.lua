-- Where the toolkit's time goes (Josh 2026-09-23), measured from the Testing
-- page's CPU row since 2026-09-28.
--
-- This times what RUNS BY ITSELF - updates, events and timers - by the file
-- that made them, which is where CPU is spent unasked.
--
-- The game's own count said BeebMod was a quarter to a third of the CPU the
-- interface uses, with nothing to say which part. This measures it: every
-- file after this one takes its CreateFrame and C_Timer from here (one line
-- under its header), so each frame and timer it makes is known by the file
-- that made it. For a set time the updates, events and timers of all of them
-- are timed, and the costliest are listed.
--
-- NOTHING IS WRAPPED UNTIL IT IS MEASURED. A frame of ours only remembers the
-- OnUpdate and OnEvent it is given; when measuring starts they are swapped
-- for timed ones, and when it ends the plain ones go back - so the rest of
-- the time it costs nothing at all. A timer carries a check of one flag.
-- Scripts hooked onto the game's own frames, and hooksecurefunc, are not
-- seen; the game's figure for the whole addon is shown beside the total so
-- the gap is plain.
--
-- NEVER THE GAME'S SECURE FRAMES: a frame made from a Secure template, and
-- the client's aura containers, are handed back exactly as the client made
-- them - wrapping what secure code touches would spread taint into it.
local _, BT = ...

local P = { on = false, stats = {}, owned = setmetatable({}, { __mode = "k" }) }
BT.Cpu = P

-- the scripts worth timing: the ones that run on their own
P.SCRIPTS = { OnUpdate = true, OnEvent = true }

local function now()
	if type(debugprofilestop) == "function" then
		return debugprofilestop()
	end
	return os.clock() * 1000
end

local function record(key, ms)
	local s = P.stats[key]
	if not s then
		s = { ms = 0, calls = 0, peak = 0 }
		P.stats[key] = s
	end
	s.ms = s.ms + ms
	s.calls = s.calls + 1
	if ms > s.peak then
		s.peak = ms
	end
end
P.Record = record

-- fn, timed under `label` (events under their own name as well); a timed
-- handler someone kept hold of after measuring stopped goes back to plain
local function timed(fn, label, byEvent)
	return function(...)
		if not P.on then
			return fn(...)
		end
		local t0 = now()
		local a, b, c, d = fn(...)
		local key = label
		if byEvent then
			local event = select(2, ...)
			key = label .. " " .. tostring(event)
		end
		record(key, now() - t0)
		return a, b, c, d
	end
end

-- fn, timed only while measuring (for what cannot be unwrapped: timers, hooks);
-- the timed wrapper is made the first time it is needed, not with every timer
local function whenOn(fn, label, byEvent)
	local t
	return function(...)
		if P.on then
			t = t or timed(fn, label, byEvent)
			return t(...)
		end
		return fn(...)
	end
end

local function secure(template)
	return type(template) == "string" and template:find("Secure") ~= nil
end

-- a frame of ours: its self-running scripts remembered, to be timed on request
local function own(f, label)
	if type(f) ~= "table" or type(f.SetScript) ~= "function" then
		return f
	end
	local set = f.SetScript
	local rec = { label = label, scripts = {}, set = set }
	P.owned[f] = rec
	local name = f.GetName and f:GetName()
	if type(name) == "string" then
		rec.label = label .. " " .. name
	end
	f.SetScript = function(self, script, fn)
		if P.SCRIPTS[script] then
			rec.scripts[script] = fn
			if fn and P.on then
				return set(self, script, timed(fn, rec.label .. " " .. script, script == "OnEvent"))
			end
		end
		return set(self, script, fn)
	end
	local hook = f.HookScript
	if type(hook) == "function" then
		f.HookScript = function(self, script, fn)
			if P.SCRIPTS[script] and type(fn) == "function" then
				fn = whenOn(fn, rec.label .. " " .. script .. " (hook)", script == "OnEvent")
			end
			return hook(self, script, fn)
		end
	end
	return f
end

-- this file's CreateFrame and C_Timer, labelled with its name
function P.For(file)
	local label = tostring(file):gsub("%.lua$", "")
	local function createFrame(kind, name, parent, template, id)
		local f = _G.CreateFrame(kind, name, parent, template, id)
		if kind == "AuraContainer" or secure(template) then
			return f
		end
		-- and anything the client made protected, whatever its template is
		-- called: secure code calling SetScript must never run ours
		if f and f.IsProtected then
			local okP, protected = pcall(f.IsProtected, f)
			if okP and protected then
				return f
			end
		end
		return own(f, label)
	end
	local timer = setmetatable({}, { __index = function(_, key)
		local real = _G.C_Timer
		local fn = real and real[key]
		if type(fn) ~= "function" then
			return fn
		end
		if key == "NewTicker" or key == "NewTimer" or key == "After" then
			local kind = label .. " " .. (key == "After" and "timer" or "ticker")
			return function(delay, cb, ...)
				if type(cb) == "function" then
					cb = whenOn(cb, kind)
				end
				-- the client's function as it is now: the tests swap it
				local current = _G.C_Timer and _G.C_Timer[key]
				return (current or fn)(delay, cb, ...)
			end
		end
		return fn
	end })
	return createFrame, timer
end

-- ---------------------------------------------------------------------------
-- Measuring
-- ---------------------------------------------------------------------------

-- every remembered script swapped for its timed self, or back
local function swap(on)
	for f, rec in pairs(P.owned) do
		for script, fn in pairs(rec.scripts) do
			if fn then
				local use = on and timed(fn, rec.label .. " " .. script, script == "OnEvent") or fn
				pcall(rec.set, f, script, use)
			end
		end
	end
end

-- the game's own figure for the whole addon, in ms a frame, where it has one
function P.GameFigure()
	local prof = C_AddOnProfiler
	local metric = Enum and Enum.AddOnProfilerMetric
	if not (prof and prof.GetAddOnMetric and metric) then
		return nil
	end
	local ok, v = pcall(prof.GetAddOnMetric, "BeebMod", metric.RecentAverageTime or metric.SessionAverageTime)
	return ok and type(v) == "number" and v or nil
end

function P.Start(seconds)
	P.stats = {}
	P.startedAt = now()
	P.on = true
	swap(true)
	P.seconds = seconds
end

-- the costliest first: { key, ms, calls, peak }, and the seconds measured
function P.Stop()
	P.on = false
	swap(false)
	local secs = math.max(0.001, (now() - (P.startedAt or now())) / 1000)
	local list = {}
	for key, s in pairs(P.stats) do
		list[#list + 1] = { key = key, ms = s.ms, calls = s.calls, peak = s.peak }
	end
	table.sort(list, function(a, b) return a.ms > b.ms end)
	return list, secs
end

function P.Report(list, secs)
	local U = BT.Util
	local total = 0
	for _, e in ipairs(list) do
		total = total + e.ms
	end
	local lines = {}
	lines[#lines + 1] = ("Time measured · %.1f s · %.2f ms a second · %d things"):format(secs, total / secs, #list)
	local game = P.GameFigure()
	if game then
		lines[#lines + 1] = ("The game's own figure for BeebMod · %.3f ms a frame"):format(game)
	end
	for i = 1, math.min(12, #list) do
		local e = list[i]
		lines[#lines + 1] = ("%5.2f ms/s  %5d calls  peak %5.2f  %s"):format(e.ms / secs, e.calls, e.peak, e.key)
	end
	for _, line in ipairs(lines) do
		U.Print(line)
	end
	BT.EnsureBound()
	if BeebModDB then
		BeebModDB.cpuDump = { at = U.Now(), lines = lines }
	end
	return lines
end

-- MEASURED FROM A BUTTON (Josh 2026-09-28: "I'd actually prefer to use the
-- 'Testing' module with buttons/toggles going forward"). The CPU row on the
-- Testing page starts this; the list goes to chat and into the saved file.
-- False when a measurement is already running.
P.SECONDS = 10

function P.Measure(seconds)
	seconds = math.max(2, math.min(120, seconds or P.SECONDS))
	if P.on then
		BT.Util.Print("CPU: already measuring. The list comes when it ends.")
		return false
	end
	P.Start(seconds)
	BT.Util.Print(("CPU: measuring for %d seconds. Play as you normally would."):format(seconds))
	local after = _G.C_Timer and _G.C_Timer.After
	if after then
		after(seconds, function()
			P.Report(P.Stop())
		end)
	end
	return true
end

-- the list is a record too, so Clear on the Testing page takes it out
BT.Record("cpuDump")
