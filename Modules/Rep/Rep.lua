-- Reputation: the faction you are watching, and where you stand with it
-- (Josh 2026-09-22).
--
-- The same line and thin bar as Experience, for whichever faction is ticked
-- "Show as Experience Bar" in the reputation panel - and, like the client's
-- own bar, not there at all when none is. The bar is the standing's colour,
-- the one the reputation panel paints it.
--
-- WHAT THIS SESSION GAINED is kept per faction: watch another faction and
-- back, and the first one's gains are still there. Every faction is counted,
-- watched or not, and losses as well as gains (M.Gain). A /reload carries the
-- session on; a login starts a new one.
--
-- NO TIME TO THE NEXT STANDING (Josh 2026-09-28: "I think we can remove the
-- rep time estimates"). Reputation comes in lumps - a quest turned in, a
-- batch of kills - so an hour's pace said little ("11h 57m to Honored"). The
-- line is the faction and its standing; the hover says what is left.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Rep/Rep.lua")

local U = BT.Util

local M = BT.Module({
	key = "rep",
	feature = "dock",
	title = "Reputation",
	order = 37.5,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

-- exalted is the top of the ladder: nothing comes after it
local TOP = 8

local WORDS = "|cff8a9894%s|r"

-- the client's own standing names and colours, and plain ones where it has none
local NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local COLOURS = {
	{ 0.80, 0.30, 0.22 }, { 0.80, 0.30, 0.22 }, { 0.75, 0.27, 0 }, { 0.90, 0.70, 0 },
	{ 0, 0.60, 0.10 }, { 0, 0.60, 0.10 }, { 0, 0.60, 0.10 }, { 0, 0.60, 0.10 },
}

function M.StandingName(reaction)
	local own = _G["FACTION_STANDING_LABEL" .. tostring(reaction)]
	if type(own) == "string" and own ~= "" then
		return own
	end
	return NAMES[reaction] or "?"
end

function M.StandingColour(reaction)
	local own = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
	if type(own) == "table" and own.r then
		return { own.r, own.g, own.b }
	end
	return COLOURS[reaction] or COLOURS[4]
end

-- ---------------------------------------------------------------------------
-- What the client says
-- ---------------------------------------------------------------------------

-- The watched faction, or nil when nothing is watched: its name, its
-- standing, how far through the standing (cur of max), and its total value,
-- which only ever goes up with gains - across standings too.
function M.Read()
	local r = _G.C_Reputation
	if r and type(r.GetWatchedFactionData) == "function" then
		local ok, d = pcall(r.GetWatchedFactionData)
		if ok and type(d) == "table" and d.name and d.name ~= "" then
			local low = d.currentReactionThreshold or 0
			local high = d.nextReactionThreshold or low
			local value = d.currentStanding or low
			return {
				name = d.name, reaction = d.reaction or 4, value = value,
				cur = value - low, max = high - low, id = d.factionID,
			}
		end
	end
	if type(_G.GetWatchedFactionInfo) == "function" then
		local ok, name, reaction, low, high, value, id = pcall(_G.GetWatchedFactionInfo)
		if ok and type(name) == "string" and name ~= "" then
			low, high, value = low or 0, high or 0, value or 0
			return {
				name = name, reaction = reaction or 4, value = value,
				cur = value - low, max = high - low, id = id,
			}
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The session
-- ---------------------------------------------------------------------------

local function store()
	if not BT.settings then
		return nil
	end
	BT.settings.rep = BT.settings.rep or {}
	return BT.settings.rep
end

-- A new session on a login, the same one on a reload (Core/Session.lua).
function M.Start(initial, reloading)
	local all = store()
	if not all then
		return nil
	end
	local s = BT.Session.Open(all, initial, reloading, function(now)
		return { start = now, factions = {} }
	end)
	s.factions = s.factions or {}
	M.session = s
	M.Gain()
	return s
end

-- Every faction the client lists, as (name, value, id): the reputation
-- page's own walk. A header with no standing of its own is not a faction.
-- A folded header hides what is under it from this list, as on the page.
-- false where the client has no such list.
function M.EachFaction(fn)
	local r = _G.C_Reputation
	if not (r and type(r.GetNumFactions) == "function" and type(r.GetFactionDataByIndex) == "function") then
		return false
	end
	local okN, n = pcall(r.GetNumFactions)
	for i = 1, (okN and tonumber(n)) or 0 do
		local ok, d = pcall(r.GetFactionDataByIndex, i)
		if ok and type(d) == "table" and type(d.name) == "string" and d.name ~= ""
			and (not d.isHeader or d.isHeaderWithRep) then
			fn(d.name, d.currentStanding, d.factionID)
		end
	end
	return true
end

-- EVERY FACTION THAT MOVED, BOTH WAYS (2026-10-17, audit). Only the watched
-- faction was read, and only what it went up: a faction that moved while you
-- watched another was left out, and a loss was dropped. Watching Booty Bay,
-- -25 for a pirate and +25 for a quest read +25, where the truth is 0. Now
-- each change to any faction is added with its sign. The total value carries
-- on across standings, so a new standing is no special case. A faction is
-- first seen at the value it has then. With `rebase`, every value is read
-- and nothing is counted (switched back on: what moved while it was off is
-- not this session's).
local seen = {}
function M.Gain(rebase)
	local s = M.session
	if s then
		local now = U.Now()
		local function saw(name, value, id)
			if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then
				return
			end
			seen[name] = true
			local t = s.factions[name]
			if not t then
				s.factions[name] = { since = now, gained = 0, value = value, id = id }
				return
			end
			t.id = t.id or id
			if not rebase then
				t.gained = (t.gained or 0) + (value - (t.value or value))
			end
			t.value = value
		end
		for name in pairs(seen) do
			seen[name] = nil
		end
		M.EachFaction(saw)
		-- the ones a folded header keeps off the list, by their id
		local r = _G.C_Reputation
		if r and type(r.GetFactionDataByID) == "function" then
			for name, t in pairs(s.factions) do
				if not seen[name] and t.id then
					local ok, d = pcall(r.GetFactionDataByID, t.id)
					if ok and type(d) == "table" then
						saw(name, d.currentStanding, t.id)
					end
				end
			end
		end
		-- and the watched one, whether or not the client lists it
		local f = M.Read()
		if f and not seen[f.name] then
			saw(f.name, f.value, f.id)
		end
		s.last = now
	end
	M.Update()
end

-- 12,345: commas from a thousand, written the one way every count in
-- BeebMod is (U.Commas; 2026-10-17, audit: six copies used the client's
-- separator and the rest a comma)
local function big(n)
	return BT.Util.Commas(n)
end

-- ---------------------------------------------------------------------------
-- The line and the bar
-- ---------------------------------------------------------------------------

-- A TITLE FIRST (Josh 2026-09-29: "we need some titles for these progress
-- bars"): "Reputation · Darnassus", and the standing on the right, where
-- nothing else is. NO AMOUNT (Josh 2026-09-22): "2,807 to Honored" took half
-- the line, and the hover says it anyway.
function M.Lines(f)
	local left = ("Reputation %s"):format(WORDS:format("· " .. f.name))
	return left, M.StandingName(f.reaction)
end

function M.Update()
	if not M.frame then
		return
	end
	local f = M.Read()
	-- NOTHING WATCHED, NOTHING SHOWN - as with the client's own bar
	local want = f ~= nil and BT.Enabled("rep")
	if want ~= M.shownFor then
		M.shownFor = want
		M.frame:SetShown(want)
		BT.Dock.Relayout()
	end
	if not f then
		return
	end
	local left, right = M.Lines(f)
	M.text:SetText(left)
	M.eta:SetText(right)

	local c = M.StandingColour(f.reaction)
	-- the shield's field wears the standing's colour, as the bar does
	-- (or a standing previewed from the Testing page)
	local shield = BT.Dock.preview.standing and M.StandingColour(BT.Dock.preview.standing) or c
	M.shield.field:SetVertexColor(shield[1], shield[2], shield[3])
	-- the standing in its own colour, as the bar is, lifted to read on the
	-- dark panel (the canvas "Dock meters: level first")
	M.eta:SetTextColor(BT.Util.Bright(c))
	local w = BT.Dock.LineBarWidth(M.frame)
	if w <= 0 then
		return
	end
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	local done = (f.reaction >= TOP or f.max <= 0) and 1 or math.min(1, f.cur / f.max)
	-- a texture of no width is drawn as a whole one, so an empty bar is hidden
	M.fill:SetShown(done > 0)
	M.fill:SetWidth(math.max(1, w * done))
end

-- (Josh 2026-09-27, the dock's tooltips redrawn) the watched faction's
-- standing and what is left of it, then every faction that moved this session
function M.Tip()
	local f = M.Read()
	if not (f and BT.Tip) then
		return
	end
	BT.Tip.Show(M.frame, { build = function(t)
		local c = M.StandingColour(f.reaction)
		t:Header({ name = f.name, sub = "Watched faction", pill = M.StandingName(f.reaction), pillState = c })
		local top = f.reaction >= TOP or f.max <= 0
		if top then
			t:Headline(M.StandingName(f.reaction), nil, c, true)
		else
			t:Headline(big(f.cur), "/ " .. big(f.max))
			t:Bar(f.cur / f.max, c)
			t:Scale(("%s to %s"):format(big(f.max - f.cur), M.StandingName(f.reaction + 1)))
		end
		local moved = {}
		for name, entry in pairs(M.session and M.session.factions or {}) do
			if (entry.gained or 0) ~= 0 then
				moved[#moved + 1] = { name = name, gained = entry.gained }
			end
		end
		table.sort(moved, function(a, b) return a.gained > b.gained end)
		if #moved > 0 then
						t:Section("This session")
			for i = 1, math.min(5, #moved) do
				local m = moved[i]
				t:ListRow(m.name, (m.gained > 0 and "+" or "-") .. big(math.abs(m.gained)), m.gained > 0 and "good" or "bad")
			end
		end
		t:Foot({ { "Click", "open reputation" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("rep", 7)
	-- a shield at the start with a banner on it (Josh 2026-09-29), on a slim
	-- line under Level (BT.Dock.SlimLine, Josh 2026-10-05)
	M.shield = BT.Dock.LineShield(M.frame, nil, BT.Dock.SHIELD_BANNER)
	M.text, M.eta, M.track, M.fill = BT.Dock.SlimLine(M.frame, M.shield.icon)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	M.frame:EnableMouse(true)
	-- a click opens the reputation page of the character window (Josh 2026-09-29)
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and not BT.Dock.JustMoved() then
			BT.Util.OpenCharacter("reputation")
		end
	end)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.frame
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, initial, reloading)
	if not BT.Enabled("rep") then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		BT.Session.OnWorld(M, initial, reloading)
	else
		-- a gain, or a different faction ticked: either way, read it again
		M.Gain()
	end
end)

-- THE CLIENT'S OWN BAR, PUT AWAY WHILE THIS ONE IS UP (Josh 2026-09-22),
-- always since the settings canvas cut its switch (2026-10-04). See
-- Core/StatusBars.lua.
function M.HideClient()
	return true
end

-- the client's bar put away or given back now (for the tests)
function M.SetHideClient(on)
	BT.StatusBars.Set("rep", BT.Enabled("rep") and on)
end

-- NO TICKER (Josh 2026-09-30, review). It read the faction again every ten
-- seconds, and nothing on the line changes with time: a gain or another
-- faction watched is UPDATE_FACTION, a new width is OnSizeChanged, and a
-- standing previewed from the Testing page calls M.Update itself.
function M.Show(on)
	-- switched off, the client's bar comes back whatever the switch says
	BT.StatusBars.Set("rep", on and M.HideClient())
	local frame = M.Build()
	if on then
		M.shownFor = nil
		frame:Show()
		M.Update()
	else
		frame:Hide()
	end
	BT.Dock.Relayout()
end

function M:OnEnable()
	-- WHAT EACH FACTION SAYS NOW (2026-10-17, audit), as Experience and
	-- Currency do: reputation that moved while this was off is not one gain
	if M.session then
		M.Gain(true)
	end
	M.Show(true)
	-- switched on mid-session (Core/Session.lua)
	BT.Session.Ensure(M)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end
