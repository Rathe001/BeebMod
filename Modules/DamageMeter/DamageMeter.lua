-- The client's own damage meter, in the toolkit's clothes (Josh 2026-09-22).
--
-- This client draws its own meter (Blizzard_DamageMeter, the thing
-- Core/Collect/Meter.lua reads sessions from): a window with a title bar,
-- three buttons and a row per combatant. It wears the client's gold-and-stone
-- look, which is the loudest thing on a screen where everything else is a
-- flat fill and a one-pixel rim.
--
-- SAME BARGAIN AS THE ACTION BARS. Nothing is reimplemented: the window is
-- the client's, the rows are the client's, every button still does what it
-- did. The art comes off, our surface goes on, the bars go flat, the gold
-- text goes the panel's grey. Switched off, every one of them is put back.
--
-- WHAT THE DUMP SAID (Josh 2026-09-22, /bt meterdump): the window is a frame
-- called DamageMeter with a DamageMeterSessionWindow1 inside it - a Header
-- texture, a MinimizeButton, a SettingsDropdown, a SessionDropdown, a
-- DamageMeterTypeDropdown, and a MinimizeContainer holding a Background, a
-- ScrollBox of rows (Icon + StatusBar with Name and Value on it) and a
-- ScrollBar. All of it dresses by kind - see Core/Furniture.lua - so a build
-- that moves a piece still comes out right.
--
-- AND A LITTLE MORE THAN THE CLIENT'S (Josh 2026-09-24: "our damage meters
-- could use some love"):
--   * the spell breakdown (MinimizeContainer.SourceWindow) floats beside the
--     window, so it wears a surface of its own as well
--   * the header's marks - the type arrow, the cog, the minimise - are pinned
--     as marks, so no pass ever takes one for art
--   * the session is a word: "Current", "Overall", not the client's "C"/"O"
--   * the fight's length in the header, and each row's amount a second after
--     its total, "8,421 (93.5)" - the breakdown's own way of writing it. Both
--     from the client's meter, and only where it says them plainly: a secret
--     number (restricted content, in a fight) is left as the client wrote it.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/DamageMeter/DamageMeter.lua")

local U = BT.Util

local M = BT.Module({
	key = "damagemeter",
	feature = "unitframes",
	title = "Damage meter",
	blurb = "Draws the game's own damage meter flat",
	order = 58,
})

local dresser = BT.Furniture.New({ flatBars = true })

local function opt(name, fallback)
	local s = BT.settings and BT.settings.damagemeter
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.damagemeter = BT.settings.damagemeter or {}
	BT.settings.damagemeter[name] = value
	M.Unextras()
	M.StyleAll()
end
M.SetOpt = setOpt
local F_INK = BT.Furniture.INK

-- ---------------------------------------------------------------------------
-- Which frames
-- ---------------------------------------------------------------------------

-- the name the dump showed, and the ones a build might move to
local KNOWN = { "DamageMeter", "DamageMeterFrame", "DamageMeterWindow", "DamageMeterWindowFrame" }

local roots = {}

local function isRoot(f)
	if type(f) ~= "table" or f.beebs then
		return false
	end
	local name = BT.Furniture.Call(f, "GetName")
	if not (type(name) == "string" and name:find("DamageMeter", 1, true)) then
		return false
	end
	local parent = BT.Furniture.Call(f, "GetParent")
	return parent == nil or parent == UIParent
end

-- for the tests, and for anything that knows the frame by another name
function M.AddRoot(f)
	if type(f) ~= "table" then
		return false
	end
	for _, r in ipairs(roots) do
		if r == f then
			return false
		end
	end
	roots[#roots + 1] = f
	return true
end

function M.Roots(again, byName)
	-- LOOKED FOR ONCE (Josh 2026-09-23, audit): with no meter found, every
	-- restyle - each fight's start and end, every roster change, every addon
	-- that loads - walked every frame in the game looking for one. A fresh
	-- look is asked for by name (a meter loading, the tab, the record).
	if (#roots > 0 or M.scanned) and not again then
		return roots
	end
	for _, name in ipairs(KNOWN) do
		local f = _G[name]
		if type(f) == "table" and f.GetRegions then
			M.AddRoot(f)
		end
	end
	-- `byName` looks under the known names only: a loading screen with no
	-- meter found walked every frame in the game again
	if not byName and type(_G.EnumerateFrames) == "function" then
		local f, guard = nil, 0
		repeat
			local ok, nxt = pcall(_G.EnumerateFrames, f)
			if not ok then
				break
			end
			f = nxt
			guard = guard + 1
			if f and isRoot(f) then
				M.AddRoot(f)
			end
		until not f or guard > 20000
	end
	M.scanned = true
	return roots
end

-- ---------------------------------------------------------------------------
-- Dressing
-- ---------------------------------------------------------------------------

-- how many frames a window is made of, as deep as a dress goes
local sizes = setmetatable({}, { __mode = "k" })
local function size(f, depth)
	if type(f) ~= "table" or depth > 10 then
		return 0
	end
	local n = 1
	local ok, kids = pcall(function() return { f:GetChildren() } end)
	for _, kid in ipairs(ok and kids or {}) do
		n = n + size(kid, depth + 1)
	end
	return n
end

-- Dresses every meter window there is; `plain` puts the client's look back.
function M.StyleAll(plain)
	if plain then
		dresser:Undress()
		M.Unextras()
		M.lastCount = 0
		for root in pairs(sizes) do
			sizes[root] = nil
		end
		return 0
	end
	local n = 0
	for _, root in ipairs(M.Roots()) do
		local ok, count = pcall(dresser.DressRoot, dresser, root)
		if ok then
			n = n + (count or 0)
		else
			BT.Err("damagemeter: " .. tostring(count))
		end
		local okE, err = pcall(M.Extras, root)
		if not okE then
			BT.Err("damagemeter.extras: " .. tostring(err))
		end
		-- how many frames it was made of when dressed (M.Grown)
		sizes[root] = size(root, 0)
	end
	M.lastCount = n
	M.Hook()
	return n
end

-- A NEW ROW IS A NEW FRAME (Josh 2026-09-30, review). The two-second look
-- dressed the whole meter every time, in a fight too: a walk of every piece,
-- each one asked who its parent is. Counting the frames is a walk of the
-- frames alone, and a new row, a new breakdown or a new scroll bar each adds
-- one; only then is there anything new to dress.
function M.Grown(root)
	return sizes[root] == nil or size(root, 0) ~= sizes[root]
end

-- the theme changed: paint again
function M.Restyle()
	if BT.Enabled("damagemeter") then
		return M.StyleAll()
	end
end

-- ---------------------------------------------------------------------------
-- More than the client's
-- ---------------------------------------------------------------------------

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

local function plainNumber(v)
	return type(v) == "number" and not secret(v) and v or nil
end

-- a frame's children, all of them (Furniture.Call hands back eight at most,
-- and a raid's meter has more rows than that)
local function children(f)
	if not (type(f) == "table" and type(f.GetChildren) == "function") then
		return {}
	end
	local ok, kids = pcall(function() return { f:GetChildren() } end)
	return ok and kids or {}
end

-- every session window in a meter: each has its own type and session
function M.SessionWindows(root)
	local out = {}
	for _, kid in ipairs(children(root)) do
		if type(kid) == "table" and kid.DamageMeterTypeDropdown then
			out[#out + 1] = kid
		end
	end
	return out
end

-- THE SESSION AS A WORD. The client writes one letter; the letters it uses
-- for the two standing sessions are said in full. A past fight's label is
-- left as it is.
M.SESSION_WORDS = { C = "Current", O = "Overall" }
local labelled = setmetatable({}, { __mode = "k" })

local function isWord(text)
	for _, word in pairs(M.SESSION_WORDS) do
		if text == word then
			return true
		end
	end
	return false
end
-- the dropdown's other label, which writes the same letter (Josh 2026-09-24:
-- the header read "OOverall"), see-through while ours says it in full
local doubled = setmetatable({}, { __mode = "k" })

-- the dropdown's other labels: any that says a session - the letter the
-- client writes, or our word - is see-through while ours says it, and is
-- watched, because the client writes it after ours (Josh 2026-09-24: still
-- "OOverall")
local function hush(r)
	if not (r and r.GetText and r.SetAlpha) or r.beebsLabelling then
		return
	end
	local okT, other = pcall(r.GetText, r)
	if not (okT and type(other) == "string") or secret(other) then
		return
	end
	local session = M.SESSION_WORDS[other] ~= nil or isWord(other)
	if session and BT.Enabled("damagemeter") then
		if doubled[r] == nil then
			doubled[r] = BT.Pill.Number(r.GetAlpha and r:GetAlpha(), 1)
		end
		r:SetAlpha(0)
	end
end

local function hushOthers(fs, dd)
	local function each(f)
		local okR, regions = pcall(function() return { f:GetRegions() } end)
		for _, r in ipairs(okR and regions or {}) do
			if r ~= fs and type(r) == "table" and r.GetText then
				if not r.beebsHushHooked and type(hooksecurefunc) == "function" then
					r.beebsHushHooked = true
					pcall(hooksecurefunc, r, "SetText", hush)
				end
				hush(r)
			end
		end
	end
	if type(dd) ~= "table" then
		return
	end
	each(dd)
	local okC, kids = pcall(function() return { dd:GetChildren() } end)
	for _, k in ipairs(okC and kids or {}) do
		each(k)
	end
end

local function relabel(fs)
	if fs.beebsLabelling or not BT.Enabled("damagemeter") then
		return
	end
	local ok, text = pcall(fs.GetText, fs)
	if not ok or type(text) ~= "string" or secret(text) then
		return
	end
	local word = M.SESSION_WORDS[text]
	if not word then
		-- A PAST FIGHT'S LABEL IS THE CLIENT'S (Josh 2026-09-30, review). The
		-- letter remembered from before was written back over it when the
		-- meter was switched off or a switch changed, and then read again as
		-- "Current" while the window showed the old fight. Our own word read
		-- again still stands for its letter.
		if not isWord(text) then
			labelled[fs] = nil
		end
		return
	end
	labelled[fs] = text
	fs.beebsLabelling = true
	fs:SetText(word)
	fs.beebsLabelling = false
	local dd = fs.beebsDropdown or (fs.GetParent and fs:GetParent())
	hushOthers(fs, dd)
	-- room for the word: the label and its button grow from their right
	local w = BT.Pill.Number(fs.GetStringWidth and fs:GetStringWidth(), 0)
	if w > 0 then
		pcall(fs.SetWidth, fs, w + 2)
		if dd and dd.SetWidth then
			pcall(dd.SetWidth, dd, w + 6)
		end
	end
end
M.Relabel = relabel

-- which session a window shows, as the meter API names it: its own field if
-- it has one, else the letter it wrote
function M.SessionOf(win)
	local T = Enum and Enum.DamageMeterSessionType
	local own = win.sessionType
	if own == nil and type(win.GetSessionType) == "function" then
		local ok, v = pcall(win.GetSessionType, win)
		own = ok and v or nil
	end
	if own ~= nil and not secret(own) then
		return own
	end
	local fs = win.SessionDropdown and win.SessionDropdown.SessionName
	local letter = fs and labelled[fs]
	if T and letter == "C" then
		return T.Current
	elseif T and letter == "O" then
		return T.Overall
	end
	return nil
end

-- the fight's length in seconds, plain, or nil
function M.Duration(win)
	local api = C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds
	local session = M.SessionOf(win)
	if type(api) ~= "function" or session == nil then
		return nil
	end
	local ok, secs = pcall(api, session)
	return ok and plainNumber(secs) or nil
end

function M.Clock(secs)
	secs = math.floor(secs + 0.5)
	return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

-- a row's amount a second: the client's own figure where the row's data has
-- one, else its total over the fight's length
function M.PerSecond(data, duration)
	if type(data) ~= "table" then
		return nil
	end
	local rate = plainNumber(data.amountPerSecond)
	if rate then
		return rate
	end
	local total = plainNumber(data.totalAmount)
	if total and duration and duration > 0 then
		return total / duration
	end
	return nil
end

local rowWindow = setmetatable({}, { __mode = "k" })
local shown = setmetatable({}, { __mode = "k" })

-- the client has just written a row's amount: its rate after it
local function decorate(fs)
	if fs.beebsWriting then
		return
	end
	-- the client has written this one: the total remembered from its last
	-- is old, and is not the one to put back (Josh 2026-09-30, review)
	shown[fs] = nil
	if not BT.Enabled("damagemeter") or not opt("perSecond", true) then
		return
	end
	local row = fs.beebsRow
	local win = row and rowWindow[row]
	local ok, text = pcall(fs.GetText, fs)
	if not (win and ok and type(text) == "string") or secret(text) or text == "" then
		return
	end
	local okD, data = pcall(function() return row.GetElementData and row:GetElementData() end)
	local rate = M.PerSecond(okD and data or nil, M.Duration(win))
	if not rate then
		return
	end
	shown[fs] = text
	fs.beebsWriting = true
	fs:SetText(("%s (%s)"):format(text, M.RateText(rate)))
	fs.beebsWriting = false
end
M.Decorate = decorate

-- a rate as the total beside it is written: to a tenth under a thousand, and
-- whole with its thousands marked from there - "84,213 (1,234)", not
-- "84,213 (1234.5)" (Josh 2026-09-30, review)
function M.RateText(rate)
	if rate < 999.95 then
		return ("%.1f"):format(rate)
	end
	local n = math.floor(rate + 0.5)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, s = pcall(BreakUpLargeNumbers, n)
		if ok and type(s) == "string" then
			return s
		end
	end
	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- the rows a window has made so far, each hooked once
local function eachRow(win, fn)
	local box = win.MinimizeContainer and win.MinimizeContainer.ScrollBox
	local target = box and box.ScrollTarget
	for _, row in ipairs(children(target)) do
		if type(row) == "table" and row.StatusBar and row.StatusBar.Value then
			fn(row)
		end
	end
end

function M.Extras(root)
	for _, win in ipairs(M.SessionWindows(root)) do
		-- the header's marks, pinned
		local marks = {
			win.DamageMeterTypeDropdown and win.DamageMeterTypeDropdown.Arrow,
			win.SettingsDropdown and win.SettingsDropdown.Icon,
		}
		for _, r in ipairs({ BT.Furniture.Call(win.MinimizeButton, "GetRegions") }) do
			marks[#marks + 1] = r
		end
		for _, r in pairs(marks) do
			if type(r) == "table" then
				r.beebsGlyph = true
				dresser:DressRegion(r)
			end
		end
		-- the session, said in full
		local fs = win.SessionDropdown and win.SessionDropdown.SessionName
		if fs then
			fs.beebsDropdown = win.SessionDropdown
		end
		if fs and not fs.beebsHooked and type(hooksecurefunc) == "function" then
			fs.beebsHooked = true
			pcall(hooksecurefunc, fs, "SetText", relabel)
		end
		if fs then
			relabel(fs)
		end
		-- the fight's length, just after the meter's name (M.Tick places it:
		-- beside the session it ran into "Damage Done" - Josh 2026-09-24)
		if not win.beebsClock and win.CreateFontString and win.SessionDropdown then
			win.beebsClock = BT.Widgets.Label(win, "", "small", F_INK[1], F_INK[2], F_INK[3])
			win.beebsClock.beebs = true
		end
		M.Tick(win)
		-- each row's rate, after the client writes its total
		eachRow(win, function(row)
			rowWindow[row] = win
			local value = row.StatusBar.Value
			if not value.beebsHooked and type(hooksecurefunc) == "function" then
				value.beebsHooked = true
				value.beebsRow = row
				pcall(hooksecurefunc, value, "SetText", decorate)
			end
		end)
		-- the breakdown: beside the window, so a surface of its own
		local source = win.MinimizeContainer and win.MinimizeContainer.SourceWindow
		if type(source) == "table" and source.CreateTexture then
			dresser:DressRoot(source)
		end
	end
end

-- the header's clock, now
function M.Tick(win)
	local clock = win.beebsClock
	if not clock then
		return
	end
	local secs = BT.Enabled("damagemeter") and opt("clock", true) and M.Duration(win)
	clock:SetText(secs and M.Clock(secs) or "")
	clock:SetShown(secs ~= nil)
	-- after the name as written now (the type is picked from a menu, and
	-- "Healing Done" is longer than "Damage Done"), or left of the session
	local name = win.DamageMeterTypeDropdown and win.DamageMeterTypeDropdown.TypeName
	clock:ClearAllPoints()
	if name and name.GetStringWidth then
		local w = BT.Pill.Number(name:GetStringWidth(), 0)
		clock:SetPoint("LEFT", name, "LEFT", w + 8, 0)
	else
		clock:SetPoint("RIGHT", win.SessionDropdown, "LEFT", -6, 0)
	end
	-- THE SESSION FIRST (Josh 2026-09-24: the clock ran into "Overall"). A
	-- narrow meter has no room for both; the session is the one you click, so
	-- the clock gives way until the window is widened
	local session = win.SessionDropdown and win.SessionDropdown.SessionName
	if secs and session then
		local right = BT.Pill.Number(clock.GetRight and clock:GetRight(), nil)
		local left = BT.Pill.Number(session.GetLeft and session:GetLeft(), nil)
		if right and left and right > left - 6 then
			clock:Hide()
		end
		-- and the client's second label, written after ours, kept quiet
		hushOthers(session, session.beebsDropdown or win.SessionDropdown)
	end
end

-- everything of ours off, and the client's words back
function M.Unextras()
	for r, alpha in pairs(doubled) do
		pcall(r.SetAlpha, r, alpha)
		doubled[r] = nil
	end
	for fs, letter in pairs(labelled) do
		fs.beebsLabelling = true
		pcall(fs.SetText, fs, letter)
		fs.beebsLabelling = false
		labelled[fs] = nil
	end
	for fs, text in pairs(shown) do
		fs.beebsWriting = true
		pcall(fs.SetText, fs, text)
		fs.beebsWriting = false
		shown[fs] = nil
	end
	for _, root in ipairs(roots) do
		for _, win in ipairs(M.SessionWindows(root)) do
			if win.beebsClock then
				win.beebsClock:Hide()
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- When to look again
-- ---------------------------------------------------------------------------

-- once a frame, however many of the meter's own calls asked
local queued = false
local function soon()
	if queued then
		return
	end
	if C_Timer and C_Timer.After then
		queued = true
		C_Timer.After(0, function()
			queued = false
			if BT.Enabled("damagemeter") then
				M.StyleAll()
			end
		end)
	elseif BT.Enabled("damagemeter") then
		M.StyleAll()
	end
end

-- once per window, not once ever: the meter may not exist yet when this is
-- first called, and a later look has to be able to hook it
function M.Hook()
	for _, root in ipairs(roots) do
		if root.HookScript and not root.beebsHooked then
			root.beebsHooked = true
			pcall(root.HookScript, root, "OnShow", soon)
			-- and whatever the window calls when it lays its rows out
			if type(hooksecurefunc) == "function" then
				for _, fn in ipairs({ "Layout", "Update", "Refresh", "UpdateRows", "RefreshRows" }) do
					if type(root[fn]) == "function" then
						pcall(hooksecurefunc, root, fn, soon)
					end
				end
			end
		end
	end
end

-- the two-second look: a meter shown that has grown since it was dressed is
-- dressed again (M.Grown)
-- AND EVERY TEN SECONDS ALL THE SAME: a row the client hands to another
-- combatant is not a new frame, and if it paints that row's bar again, only a
-- whole pass puts ours back. Ten seconds is how long that can show.
M.LOOK_ALL = 5
local looks = 0
function M.Look()
	if not BT.Enabled("damagemeter") then
		return false
	end
	looks = looks + 1
	for _, root in ipairs(roots) do
		if BT.Furniture.Call(root, "IsShown") and (looks >= M.LOOK_ALL or M.Grown(root)) then
			looks = 0
			M.StyleAll()
			return true
		end
	end
	return false
end

function M.Watch()
	if not M.events then
		M.events = CreateFrame("Frame")
		for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
			"PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE" }) do
			pcall(M.events.RegisterEvent, M.events, event)
		end
		M.events:SetScript("OnEvent", function(_, event, addon)
			if not BT.Enabled("damagemeter") then
				return
			end
			if event == "ADDON_LOADED" then
				-- the meter's own addon arriving is the one moment worth a scan
				if type(addon) == "string" and addon:find("DamageMeter", 1, true) then
					M.Roots(true)
				end
			elseif event == "PLAYER_ENTERING_WORLD" and #roots == 0 then
				-- by its names: the meter's addon loading is caught above
				M.Roots(true, true)
			end
			soon()
		end)
	end
	-- ROWS ARRIVE WITHOUT AN EVENT (Josh 2026-09-22). A new combatant is a
	-- new row, made by the client whenever it likes; nothing tells us. A
	-- slow tick over a small tree costs nothing, and dressing is idempotent:
	-- a piece already dressed is left as it is.
	-- the header's clock, a second at a time while a window is up
	if not M.clockTicker and C_Timer and C_Timer.NewTicker then
		M.clockTicker = C_Timer.NewTicker(1, function()
			if not BT.Enabled("damagemeter") then
				return
			end
			for _, root in ipairs(roots) do
				if BT.Furniture.Call(root, "IsShown") then
					for _, win in ipairs(M.SessionWindows(root)) do
						M.Tick(win)
					end
				end
			end
		end)
	end
	if not M.ticker and C_Timer and C_Timer.NewTicker then
		M.ticker = C_Timer.NewTicker(2, M.Look)
	end
	return M.events
end

function M:OnEnable()
	M.Watch()
	M.Roots(true)
	M.StyleAll()
end

function M:OnBind()
	M.Watch()
	M.StyleAll()
end

function M:OnDisable()
	M.StyleAll(true)
	-- and its two tickers stopped, as every other module's are: nothing of
	-- ours is on the meter to keep up (M.Watch starts them again)
	for _, key in ipairs({ "ticker", "clockTicker" }) do
		if M[key] then
			M[key]:Cancel()
			M[key] = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("This is the game's own damage meter. Every button and every row still does what it did before.")
	page:Note("Switched off, the meter looks like the game's again.", true)
	-- (Josh 2026-09-24) the two things this adds to the client's meter
	local more = page:Section("Extras")
	BT.Widgets.SwitchRow(more, "Per second", "Each row's amount per second after its total, as in 8,421 (93.5)",
		function() return opt("perSecond", true) and true or false end,
		function(on) setOpt("perSecond", on) end)
	BT.Widgets.SwitchRow(more, "Fight length", "How long the fight has run, in the header when there's room",
		function() return opt("clock", true) and true or false end,
		function(on) setOpt("clock", on) end)
	page:Layout()
	self.found = BT.Widgets.Label(panel, "", "small", 0.45, 0.50, 0.48)
	self.found:SetPoint("BOTTOMLEFT", 2, 4)
end

function M:RefreshTab()
	if self.found then
		if #roots == 0 then
			self.found:SetText("No meter window found yet. Open it, then open this page again.")
		else
			self.found:SetText(("%d window%s · %d pieces redrawn"):format(
				#roots, #roots == 1 and "" or "s", M.lastCount or 0))
		end
	end
end

function M:ShowTab()
	if BT.Enabled("damagemeter") then
		M.Roots(true)
		M.StyleAll()
	end
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
end

-- ---------------------------------------------------------------------------
-- The record
-- ---------------------------------------------------------------------------

-- the meter's frames, into the saved file (the Testing page's Record button)
function M.Dump()
	M.Roots(true)
	local lines = BT.Furniture.Dump(roots)
	-- and, when nothing was recognised, every named frame with Meter in it,
	-- so the next version can be told what the window is called
	if #roots == 0 and type(_G.EnumerateFrames) == "function" then
		local f, guard = nil, 0
		repeat
			local ok, nxt = pcall(_G.EnumerateFrames, f)
			if not ok then
				break
			end
			f = nxt
			guard = guard + 1
			local name = f and BT.Furniture.Call(f, "GetName")
			if type(name) == "string" and name:lower():find("meter", 1, true) then
				lines[#lines + 1] = "candidate " .. name .. " | " .. BT.Furniture.Describe(f)
			end
		until not f or guard > 20000
	end
	-- what the rows and the sessions carry, by name - never a secret into a
	-- string - so the rates can be read from what is really there
	for _, root in ipairs(roots) do
		for _, win in ipairs(M.SessionWindows(root)) do
			lines[#lines + 1] = ("session %s · duration %s"):format(tostring(M.SessionOf(win)),
				tostring(M.Duration(win)))
			eachRow(win, function(row)
				local ok, data = pcall(function() return row.GetElementData and row:GetElementData() end)
				if ok and type(data) == "table" then
					local keys = {}
					for k, v in pairs(data) do
						keys[#keys + 1] = tostring(k) .. "=" .. (secret(v) and "secret" or type(v))
					end
					table.sort(keys)
					lines[#lines + 1] = "row data: " .. table.concat(keys, " ")
				end
			end)
		end
	end
	if Enum and Enum.DamageMeterType then
		local types = {}
		for k, v in pairs(Enum.DamageMeterType) do
			types[#types + 1] = tostring(k) .. "=" .. tostring(v)
		end
		table.sort(types)
		lines[#lines + 1] = "types: " .. table.concat(types, " ")
	end
	BT.EnsureBound()
	BeebModDB.damagemeterDump = {
		at = U.Now(),
		build = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
		lines = lines,
	}
	return #lines
end

BT.Record("damagemeterDump", M.Dump, "damagemeter")
