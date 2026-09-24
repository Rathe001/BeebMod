-- Where the time and the memory go (Josh 2026-09-21).
--
-- The Game Menu showed the toolkit at 37 MB and 12% CPU, climbing to 45 MB
-- before dropping back. The drop is the garbage collector, not a leak - a leak
-- never comes back down - but a sawtooth that tall means a lot is being made
-- and thrown away, and 12% is a lot of CPU for something that mostly sits
-- there. Guessing from the code found nothing; these measure instead.
--
--   /bt mem          a full collection, then the size of what is really
--                    alive. Run it now and after an hour: if THIS number
--                    climbs, that is a leak. The sawtooth is not.
--   /bt prof start   wrap every function the modules and the core expose,
--                    and every module's event handler, with a stopwatch and
--                    a memory meter
--   /bt prof         the worst of them, by time and by memory made
--   /bt prof stop    unwrap everything, exactly as it was
--
-- Times are INCLUSIVE: a function that calls another wrapped one counts that
-- one's time too. Memory is what the heap grew by during the call, and a call
-- the collector ran in the middle of is not counted, so the figures are a floor.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Profile.lua")

local U = BT.Util

local P = { stats = {}, wrapped = {}, scripts = {} }
BT.Prof = P

local clock = _G.debugprofilestop or function() return os.clock() * 1000 end

local function record(name, t0, k0)
	local s = P.stats[name]
	if not s then
		s = { calls = 0, ms = 0, kb = 0 }
		P.stats[name] = s
	end
	s.calls = s.calls + 1
	s.ms = s.ms + (clock() - t0)
	local grew = collectgarbage("count") - k0
	if grew > 0 then
		s.kb = s.kb + grew
	end
end

-- a pass-through for the results, so wrapping never changes what comes back
local function finish(name, t0, k0, ...)
	record(name, t0, k0)
	return ...
end

-- and plain again the moment profiling stops, for a caller that kept hold of
-- the wrapped one (Josh 2026-09-23, audit)
local function wrap(name, fn)
	return function(...)
		if not P.on then
			return fn(...)
		end
		return finish(name, clock(), collectgarbage("count"), fn(...))
	end
end

-- the tables whose functions are called through the table, so that swapping
-- the field reaches every caller: each module, and the core's own parts
local function owners()
	local list = {}
	for _, m in ipairs((BT.Modules and BT.Modules()) or {}) do
		list[#list + 1] = { name = m.key, t = m }
	end
	for _, part in ipairs({ "DB", "Collect", "Bar", "Tooltip", "Stats", "Census",
		"Find", "Window", "Pill", "Widgets", "Theme", "Util", "Rosters" }) do
		if type(BT[part]) == "table" then
			list[#list + 1] = { name = part, t = BT[part] }
		end
	end
	return list
end

function P.Start()
	if P.on then
		return 0
	end
	P.on, P.stats, P.since = true, {}, clock()
	local n = 0
	for _, o in ipairs(owners()) do
		for key, fn in pairs(o.t) do
			-- this file's own functions and anything already wrapped are left
			if type(fn) == "function" and type(key) == "string" and o.t ~= P then
				P.wrapped[#P.wrapped + 1] = { t = o.t, key = key, fn = fn }
				o.t[key] = wrap(o.name .. "." .. key, fn)
				n = n + 1
			end
		end
	end
	-- the collector looks its handlers up by event name on every event
	local handlers = BT.Collect and BT.Collect.handlers
	for event, fn in pairs(handlers or {}) do
		P.wrapped[#P.wrapped + 1] = { t = handlers, key = event, fn = fn }
		handlers[event] = wrap("collect:" .. event, fn)
		n = n + 1
	end
	-- and each module's event frame, named by the event that woke it
	for _, m in ipairs((BT.Modules and BT.Modules()) or {}) do
		local f = m.events
		local fn = f and f.GetScript and f:GetScript("OnEvent")
		if fn then
			P.scripts[#P.scripts + 1] = { f = f, fn = fn }
			f:SetScript("OnEvent", function(self, event, ...)
				return finish(m.key .. ":" .. tostring(event), clock(),
					collectgarbage("count"), fn(self, event, ...))
			end)
			n = n + 1
		end
	end
	return n
end

function P.Stop()
	for i = #P.wrapped, 1, -1 do
		local w = P.wrapped[i]
		w.t[w.key] = w.fn
	end
	for _, s in ipairs(P.scripts) do
		s.f:SetScript("OnEvent", s.fn)
	end
	P.wrapped, P.scripts, P.on = {}, {}, false
end

-- the worst few, by one measure
function P.Top(by, n)
	local rows = {}
	for name, s in pairs(P.stats) do
		rows[#rows + 1] = { name = name, calls = s.calls, ms = s.ms, kb = s.kb }
	end
	table.sort(rows, function(a, b) return a[by] > b[by] end)
	local out = {}
	for i = 1, math.min(n or 10, #rows) do
		out[i] = rows[i]
	end
	return out
end

-- the size of what is alive, and of what was waiting to be collected
function P.Memory()
	local before = collectgarbage("count")
	collectgarbage("collect")
	local after = collectgarbage("count")
	return before / 1024, after / 1024
end

BT.Command("mem", function()
	local before, after = P.Memory()
	U.Print(("memory: %.1f MB before a full collection, %.1f MB alive after it"):format(before, after))
	U.Print("  run this again later: if the second number climbs, that is a leak")
end, "how much memory is really in use")

BT.Command("prof", function(rest)
	rest = (rest or ""):lower()
	if rest == "start" then
		U.Print(("profiling %d functions and handlers · /bt prof to see, /bt prof stop to end")
			:format(P.Start()))
		return
	elseif rest == "stop" then
		P.Stop()
		U.Print("profiling stopped, everything unwrapped")
		return
	end
	if not P.since then
		U.Print("/bt prof start first, play for a few minutes, then /bt prof")
		return
	end
	local secs = math.max(1, (clock() - P.since) / 1000)
	U.Print(("over %d seconds · by time (inclusive):"):format(secs))
	for _, r in ipairs(P.Top("ms", 10)) do
		U.Print(("  %7.1f ms  %6d calls  %s"):format(r.ms, r.calls, r.name))
	end
	U.Print("by memory made:")
	for _, r in ipairs(P.Top("kb", 10)) do
		U.Print(("  %7.0f KB  %6d calls  %s"):format(r.kb, r.calls, r.name))
	end
end, "prof start|stop - where the time and memory go")
