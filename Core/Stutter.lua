-- Stutters (Josh 2026-11-09: "I am getting some performance issues in game,
-- with a bit of stuttering. Is there a way we can monitor BeebMod to
-- determine if it is the cause?").
--
-- A stutter is one slow frame. The CPU row (Core/Cpu.lua) gives averages,
-- which a single slow frame hardly moves. This watches frames instead.
--
-- THE GAME COUNTS FOR US. Its addon profiler (C_AddOnProfiler) is always on.
-- For each addon, for all addons together and for the whole game, it counts
-- the frames that took over 5, 10, 50 and 100 ms. The watch reads those
-- counts as it starts and as it stops. The difference says how many slow
-- frames there were, and in how many of them BeebMod's own code was slow.
-- The game counts every line BeebMod runs, hooks on its frames included.
--
-- Meanwhile an OnUpdate reads each frame's length. The slowest frames are
-- kept with what all addons and BeebMod took in them. BeebMod's own parts are
-- timed by Core/Cpu.lua at the same time, so a slow part can be named.
--
-- The OnUpdate runs only while watching. The memory figures come last,
-- after the counts are read: asking the game for them can itself take a
-- frame or two.
local _, BT = ...

local S = { on = false }
BT.Stutter = S

-- a frame this long is a stutter you can see (20 frames a second)
S.SLOW_MS = 50
-- the slowest frames kept in the saved file, and shown in chat
S.KEEP = 10
S.SHOW = 5
-- it stops by itself after ten minutes
S.MAX_SECONDS = 600
S.ADDON = "BeebMod"
-- the game's counts, read at start and stop
S.COUNTS = { "CountTimeOver5Ms", "CountTimeOver10Ms", "CountTimeOver50Ms", "CountTimeOver100Ms" }
S.LIMITS = { 5, 10, 50, 100 }

local function plain(v)
	if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then
		return nil
	end
	return v
end

local function metricId(name)
	local e = Enum and Enum.AddOnProfilerMetric
	return e and e[name]
end

-- one of the game's figures. `who` is an addon's name, "all" for every addon
-- together, or "game" for the whole game.
function S.Read(who, name)
	local prof = C_AddOnProfiler
	local m = metricId(name)
	if not (prof and m) then
		return nil
	end
	local ok, v
	if who == "all" or who == "game" then
		local fn = who == "all" and prof.GetOverallMetric or prof.GetApplicationMetric
		if type(fn) ~= "function" then
			return nil
		end
		ok, v = pcall(fn, m)
	else
		if type(prof.GetAddOnMetric) ~= "function" then
			return nil
		end
		ok, v = pcall(prof.GetAddOnMetric, who, m)
	end
	return ok and plain(v) or nil
end

local function counts()
	local c = {}
	for _, name in ipairs(S.COUNTS) do
		c[name] = { me = S.Read(S.ADDON, name), all = S.Read("all", name), game = S.Read("game", name) }
	end
	return c
end

-- each addon's count for one figure, by name
function S.Top(name)
	local out = {}
	local prof = C_AddOnProfiler
	local m = metricId(name)
	if not (prof and m and type(prof.GetTopKAddOnsForMetric) == "function") then
		return out
	end
	local ok, list = pcall(prof.GetTopKAddOnsForMetric, m, 60)
	if not ok or type(list) ~= "table" then
		return out
	end
	for _, r in ipairs(list) do
		local n, v = type(r) == "table" and r.addOnName, type(r) == "table" and plain(r.metricValue)
		if type(n) == "string" and not (issecretvalue and issecretvalue(n)) and v then
			out[n] = v
		end
	end
	return out
end

local function clock()
	return (type(GetTime) == "function" and GetTime()) or os.clock()
end

-- ---------------------------------------------------------------------------
-- Each frame
-- ---------------------------------------------------------------------------

-- what the last frame held, kept in plain values: the game's figure for a
-- frame may land in the one after it, so a slow frame takes the larger
local prev = { me = 0, all = 0, ours = 0, part = nil, partMs = 0 }
local getAddOn, getAll, lastId

local function lastTime(fn, a, b)
	if not fn then
		return 0
	end
	local ok, v
	if b ~= nil then
		ok, v = pcall(fn, a, b)
	else
		ok, v = pcall(fn, a)
	end
	return ok and plain(v) or 0
end

local function keep(w, hit)
	local list = w.slowest
	list[#list + 1] = hit
	table.sort(list, function(a, b) return a.ms > b.ms end)
	while #list > S.KEEP do
		list[#list] = nil
	end
end

function S.OnUpdate(_, elapsed)
	local w = S.watch
	if not w then
		return
	end
	local ms = (tonumber(elapsed) or 0) * 1000
	local me = lastTime(getAddOn, S.ADDON, lastId)
	local all = lastTime(getAll, lastId)
	local cpu = BT.Cpu
	local ours, part, partMs = cpu.frameMs, cpu.frameTop, cpu.frameTopMs
	cpu.frameMs, cpu.frameTop, cpu.frameTopMs = 0, nil, 0
	-- a loading screen is one long frame that no addon makes
	if w.loading or w.skip > 0 then
		w.skip = math.max(0, w.skip - 1)
		w.skipped = w.skipped + 1
	else
		w.frames = w.frames + 1
		if ms > w.worst then
			w.worst = ms
		end
		if ms >= S.SLOW_MS then
			w.slow = w.slow + 1
			local hit = {
				ms = ms,
				at = (type(date) == "function" and date("%H:%M:%S")) or "",
				all = math.max(all, prev.all),
				me = math.max(me, prev.me),
				ours = math.max(ours, prev.ours),
			}
			if partMs >= prev.partMs then
				hit.part, hit.partMs = part, partMs
			else
				hit.part, hit.partMs = prev.part, prev.partMs
			end
			keep(w, hit)
		end
	end
	prev.me, prev.all, prev.ours, prev.part, prev.partMs = me, all, ours, part, partMs
	if clock() - w.started >= S.MAX_SECONDS then
		S.Stop()
	end
end

function S.OnEvent(_, event)
	local w = S.watch
	if not w then
		return
	end
	if event == "LOADING_SCREEN_ENABLED" then
		w.loading = true
	elseif event == "LOADING_SCREEN_DISABLED" then
		w.loading = false
		w.skip = 1
	end
end

-- ---------------------------------------------------------------------------
-- Start and stop
-- ---------------------------------------------------------------------------

-- false when the watch or the CPU row is already running
function S.Start()
	if S.on or BT.Cpu.on then
		BT.Util.Print(S.on and "Stutters: already watching." or "Stutters: wait for the CPU measurement to end.")
		return false
	end
	local prof = C_AddOnProfiler
	getAddOn = prof and type(prof.GetAddOnMetric) == "function" and prof.GetAddOnMetric or nil
	getAll = prof and type(prof.GetOverallMetric) == "function" and prof.GetOverallMetric or nil
	lastId = metricId("LastTime")
	if not lastId then
		getAddOn, getAll = nil, nil
	end
	prev.me, prev.all, prev.ours, prev.part, prev.partMs = 0, 0, 0, nil, 0
	S.watch = {
		started = clock(), frames = 0, slow = 0, worst = 0, skipped = 0, skip = 0,
		slowest = {}, before = counts(), topBefore = S.Top("CountTimeOver5Ms"),
	}
	S.on = true
	BT.Cpu.Start()
	if not S.frame then
		S.frame = _G.CreateFrame("Frame")
		S.frame:SetScript("OnEvent", S.OnEvent)
	end
	S.frame:RegisterEvent("LOADING_SCREEN_ENABLED")
	S.frame:RegisterEvent("LOADING_SCREEN_DISABLED")
	S.frame:SetScript("OnUpdate", S.OnUpdate)
	BT.Util.Print("Stutters: watching. Play until it stutters a few times, then press Stop on the Testing page.")
	if S.OnChange then
		S.OnChange()
	end
	return true
end

-- the report's lines, written to chat and to the saved file
function S.Stop()
	local w = S.watch
	if not S.on or not w then
		return nil
	end
	S.on = false
	S.frame:SetScript("OnUpdate", nil)
	S.frame:UnregisterAllEvents()
	local parts = BT.Cpu.Stop()
	w.secs = math.max(0.001, clock() - w.started)
	w.after = counts()
	w.topAfter = S.Top("CountTimeOver5Ms")
	if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
		pcall(UpdateAddOnMemoryUsage)
		local ok, kb = pcall(GetAddOnMemoryUsage, S.ADDON)
		w.memory = ok and plain(kb) or nil
	end
	w.allMemory = plain(collectgarbage("count"))
	S.watch = nil
	local lines = S.Report(w, parts)
	if S.OnChange then
		S.OnChange()
	end
	return lines
end

function S.Toggle()
	if S.on then
		return S.Stop()
	end
	return S.Start()
end

-- ---------------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------------

local function span(secs)
	secs = math.floor(secs + 0.5)
	if secs < 60 then
		return ("%d s"):format(secs)
	end
	return ("%d min %d s"):format(math.floor(secs / 60), secs % 60)
end

local function megabytes(kb)
	return ("%.1f MB"):format(kb / 1024)
end

-- how much one count grew while watching, or nil where the game has none
local function grew(w, name, who)
	local a, b = w.before[name] and w.before[name][who], w.after[name] and w.after[name][who]
	if not (a and b) then
		return nil
	end
	return math.max(0, b - a)
end

local function row(w, who)
	local out = {}
	for i, name in ipairs(S.COUNTS) do
		local n = grew(w, name, who)
		if n == nil then
			return nil
		end
		out[i] = tostring(n)
	end
	return table.concat(out, " / ")
end

local function short(key)
	return (tostring(key or "?"):gsub("^Modules/", ""):gsub("^Core/", ""):gsub("^UI/", ""))
end

function S.Report(w, parts)
	local U = BT.Util
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	add(("Stutters · watched %s · %s frames · %d over %d ms · the slowest %d ms")
		:format(span(w.secs), U.Commas(w.frames), w.slow, S.SLOW_MS, math.floor(w.worst + 0.5)))
	local limits = table.concat(S.LIMITS, " / ")
	local game, all, me = row(w, "game"), row(w, "all"), row(w, "me")
	if game then
		add(("Frames over %s ms · the whole game %s"):format(limits, game))
	end
	if all and me then
		add(("Frames where addon code took over %s ms · all addons %s · BeebMod %s"):format(limits, all, me))
	elseif not game then
		add("The game's addon profiler isn't on this client, so only BeebMod's own timings follow.")
	end
	-- which addons were slow while watching
	local over = {}
	for name, after in pairs(w.topAfter or {}) do
		local n = after - ((w.topBefore or {})[name] or 0)
		if n > 0 then
			over[#over + 1] = { name = name, n = n }
		end
	end
	table.sort(over, function(a, b) return a.n > b.n end)
	if #over > 0 then
		local bits = {}
		for i = 1, math.min(6, #over) do
			bits[i] = ("%s %d"):format(over[i].name, over[i].n)
		end
		add("Most frames over 5 ms by addon · " .. table.concat(bits, " · "))
	elseif all then
		add("No addon took over 5 ms in any frame.")
	end
	-- the slowest frames, and what the addons took in each
	for i = 1, math.min(S.SHOW, #w.slowest) do
		local h = w.slowest[i]
		local s = ("%s · %d ms · all addons %.1f ms · BeebMod %.1f ms"):format(h.at, math.floor(h.ms + 0.5), h.all, h.me)
		if h.part and h.partMs >= 0.5 then
			s = s .. (" · most of it %s %.1f ms"):format(short(h.part), h.partMs)
		end
		add(s)
	end
	-- BeebMod's parts by their slowest single run
	table.sort(parts, function(a, b) return a.peak > b.peak end)
	for i = 1, math.min(6, #parts) do
		local e = parts[i]
		add(("peak %5.2f ms  %d over %d ms  %d runs  %s"):format(e.peak, e.slow or 0, BT.Cpu.SLOW, e.calls, short(e.key)))
	end
	local peakMe, peakAll = S.Read(S.ADDON, "PeakTime"), S.Read("all", "PeakTime")
	if peakMe and peakAll then
		add(("Since login, the slowest frame of addon code · BeebMod %.1f ms · all addons %.1f ms"):format(peakMe, peakAll))
	end
	if w.memory and w.allMemory then
		add(("Memory · BeebMod %s · all interface code %s"):format(megabytes(w.memory), megabytes(w.allMemory)))
	end
	for _, line in ipairs(lines) do
		U.Print(line)
	end
	BT.EnsureBound()
	if BeebModDB then
		local saved = {}
		for i, h in ipairs(w.slowest) do
			saved[i] = { at = h.at, ms = h.ms, all = h.all, me = h.me, ours = h.ours, part = h.part, partMs = h.partMs }
		end
		local top = {}
		for i = 1, math.min(20, #parts) do
			top[i] = parts[i]
		end
		BeebModDB.stutterDump = {
			at = U.Now(), lines = lines, secs = w.secs, frames = w.frames, skipped = w.skipped,
			slowest = saved, parts = top, before = w.before, after = w.after, addons = over,
		}
	end
	return lines
end

-- the report is a record too, so Clear on the Testing page takes it out
BT.Record("stutterDump")
