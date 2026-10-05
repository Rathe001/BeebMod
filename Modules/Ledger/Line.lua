-- The Ledger's line in the dock: your rank and points (Josh 2026-10-05).
--
-- A DEDICATED ROW, AS THE EXPEDITION HAS (Josh 2026-10-04: "Remove the census
-- icon from the header, and make a dedicated row for ledger, the same as
-- expedition - show rank icon, name, and total points"). The badge of your
-- rank, "Ledger · Informant", your points and a bar to the next rank, on a
-- band of the Ledger's own colour; a click opens the Ledger, as the chart
-- button in the header did. It is a module of its own so the Dock's page can
-- drag it like any other row.
--
-- It also says what the Ledger earns (UI/Notice.lua): a commendation for a
-- moment on the row, more points as they come, and a new rank as a toast
-- with a word from Jorach.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Line.lua")

local U = BT.Util
local L = BT.LedgerRanks

local M = BT.Module({
	key = "ledgerline",
	feature = "ledger",
	title = "Ledger",
	blurb = "Your Ledger rank and points",
	-- straight after the Expedition's line: the same number, and its key
	-- comes after the Expedition's and before Metrics'
	order = 38,
	dock = true,
})

local WORDS = "|cff8a9894%s|r"
local big = BT.Book.Big

local function feature()
	return BT.Feature and BT.Feature("ledger")
end
-- the row's notices are in the Ledger's colour, and the bar's line names it
M.colour = (feature() or {}).color or { 0.61, 0.50, 0.82 }
M.book = "Ledger"

local function on(key, default)
	local v = BT.settings and BT.settings[key]
	if v == nil then
		return default
	end
	return v and true or false
end

-- ---------------------------------------------------------------------------
-- The line
-- ---------------------------------------------------------------------------

function M.Lines(points)
	local _, title = L.Rank(points)
	return ("Ledger %s"):format(WORDS:format("· " .. title)),
		("%s%s %s"):format(BT.Notice.GainText(M), big(points), WORDS:format("pts"))
end

-- drawn again from the points last worked out: what a notice ending or a
-- gain wants, with no walk of the book (UI/Notice.lua)
function M.Redraw()
	M.Update(M.points)
end

function M.Update(points)
	if not M.frame then
		return
	end
	if type(points) ~= "number" then
		points = L.Score()
	end
	M.points = points
	if not BT.Notice.Saying(M) then
		local left, right = M.Lines(points)
		M.text:SetText(left)
		M.eta:SetText(right)
	end
	-- your rank's badge, or a rank previewed from the Testing page
	local preview = BT.Dock.preview and BT.Dock.preview.ledger
	M.badge:SetTexture(L.RankBadge(preview or (L.Rank(points))))
	local w = BT.Dock.LineBarWidth(M.frame)
	if w <= 0 then
		return
	end
	local _, _, prev, nextAt = L.Rank(points)
	local share = nextAt and (points - prev) / (nextAt - prev) or 1
	local c = M.colour
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(c[1], c[2], c[3], 0.9)
	BT.Dock.BandColor(M.frame, c)
	M.fill:SetShown(share > 0)
	M.fill:SetWidth(math.max(1, w * math.min(1, share)))
end

-- the commendations nearest to done, the most done first
function M.Closest(c, n)
	local out = {}
	for _, a in ipairs(L.List(c)) do
		if a.have < a.need and a.have > 0 then
			out[#out + 1] = a
		end
	end
	table.sort(out, function(x, y)
		local sx, sy = x.have / x.need, y.have / y.need
		if sx ~= sy then
			return sx > sy
		end
		return x.need < y.need
	end)
	for i = #out, (n or 3) + 1, -1 do
		out[i] = nil
	end
	return out
end

-- (the Expedition's tooltip, Josh 2026-09-27, with the Ledger's own words in
-- it): your rank and how far to the next, the commendations you are closest
-- to, and what this session added
function M.Tip()
	if not BT.Tip then
		return
	end
	local points, _, c = L.Score()
	local f = feature()
	BT.Tip.Show(M.frame, { edge = f and f.color, build = function(t)
		local rank, title, at, nextAt, nextTitle = L.Rank(points)
		local realm = BT.scope and BT.scope.realm
		t:Header({ name = f and f.title or "Ravenholdt Ledger", sub = realm and ("Your book on %s"):format(realm) or nil,
			pill = ("Rank %d / %d"):format(rank, #L.RANKS) })
		t:Title(title, points > 0 and ("%s points"):format(big(points)) or nil)
		if points == 0 then
			t:Note("Nothing in the book yet. Every 100 characters you see is worth 1 point.")
			if nextAt then
				t:Section()
				t:ListRow("Next rank", ("%s at %s"):format(nextTitle, big(nextAt)))
			end
			t:Foot({ { "Click", "open ledger" } })
			return
		end
		if nextAt then
			t:Bar((points - at) / math.max(1, nextAt - at), f and f.color)
			t:Scale(("%s to %s"):format(big(nextAt - points), nextTitle), big(nextAt))
		end
		local near = M.Closest(c, 3)
		if #near > 0 then
						t:Section("Closest commendations")
			for _, a in ipairs(near) do
				t:ListRow(a.title, ("%s / %s"):format(big(a.have), big(a.need)), nil, nil, { a.have / a.need, f and f.color })
			end
		end
		local s = M.session
		if s then
			local more = (L.characters or 0) - s.characters
			local notes, tags = c.notes - s.notes, c.tags - s.tags
			if more > 0 or notes > 0 or tags > 0 then
				t:Section("This session")
				t:Stats({
					{ "+" .. big(math.max(0, more)), more == 1 and "character" or "characters", more > 0 and "good" or nil },
					{ "+" .. math.max(0, notes), notes == 1 and "note" or "notes" },
					{ "+" .. math.max(0, tags), tags == 1 and "tag" or "tags" },
				})
			end
		end
		t:Foot({ { "Click", "open ledger" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("ledgerline", 9)
	-- your rank's badge, on a slim line under Level (BT.Dock.SlimLine, Josh
	-- 2026-10-05)
	M.badge = BT.Dock.LineIcon(M.frame)
	M.text, M.eta, M.track, M.fill = BT.Dock.SlimLine(M.frame, M.badge)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update(M.points)
	end)
	M.frame:EnableMouse(true)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	M.frame:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or BT.Dock.JustMoved() then
			return
		end
		if M.noticeClick then
			M.noticeClick()
		elseif BT.CensusWindow then
			BT.CensusWindow.Toggle()
		end
	end)
	return M.frame
end

-- ---------------------------------------------------------------------------
-- What the Ledger earns, said
-- ---------------------------------------------------------------------------

local function openOn(id)
	return function()
		if BT.CensusWindow and BT.CensusWindow.ShowCommendation then
			BT.CensusWindow.ShowCommendation(id)
		end
	end
end

-- a new rank's toast, with its badge and Jorach's word on it; a click opens
-- the Ledger's Commendations. Off with the Ledger's Rank toasts switch.
function M.RankToast(rank)
	if not on("ledgerToasts", true) then
		return false
	end
	local f = feature()
	local _, title = L.RankByNumber(rank)
	-- the journals' one toast (Modules/Expedition/Toast.lua, loaded after this)
	local T = BT.ExpeditionToast
	return T.Push({
		head = "Ledger rank", text = ("%s %s"):format(title, WORDS:format(("· rank %d of %d"):format(rank, #L.RANKS))),
		icon = T.RANK_ICON, badge = L.RankBadge(rank), book = "Ledger",
		quote = L.QUOTES[rank], by = f and f.by, sound = on("ledgerSound", true),
		onClick = function()
			if BT.CensusWindow then
				BT.CensusWindow.Show("comm")
			end
		end,
	})
end

-- the book looked at again: the commendations it earned said on the row,
-- more points by the points, a new rank toasted (L.Changed, a beat after)
function M.Changed()
	if not BT.Enabled("ledgerline") then
		return
	end
	local before = M.points
	local news, up, points = L.Check()
	local earned = 0
	for _, a in ipairs(news) do
		earned = earned + a.points
		BT.Notice.Say(M, { name = a.title, what = "commendation", kind = "commendation", points = a.points,
			onClick = openOn(a.id) })
	end
	-- what came from seeing and writing, not from a commendation: by the points
	if before and points - before - earned > 0 and #news == 0 then
		BT.Notice.Gain(M, points - before - earned)
	end
	if up then
		M.RankToast(up)
	end
	M.Update(points)
	if BT.CensusWindow and BT.CensusWindow.Changed then
		BT.CensusWindow.Changed()
	end
end
L.onChange = M.Changed

-- the rank of a number, its title
function L.RankByNumber(n)
	local r = L.RANKS[n] or L.RANKS[1]
	return n, r[2], r[1]
end

-- ---------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------

function M.LineOn()
	return on("ledgerLine", true)
end

function M.Show(show)
	local frame = M.Build()
	if show then
		frame:SetShown(M.LineOn())
		M.Update()
	else
		frame:Hide()
	end
	BT.Dock.Relayout()
end

-- Bound: at login, and at every loading screen after it (BT.Rebind). The
-- census's book is counted once for each book, not at every zone-in - it can
-- hold 150,000 characters - and the session runs on until another book is
-- bound.
local function start()
	if L.countedFor ~= BT.db then
		L.CountCharacters()
		L.countedFor = BT.db
	end
	-- the first look writes down what the book has, quietly (L.Check)
	local _, _, points, c = L.Check()
	M.points = points
	if not M.session or M.session.db ~= BT.db then
		M.session = { db = BT.db, characters = L.characters or 0, notes = c and c.notes or 0, tags = c and c.tags or 0 }
	end
	M.Show(true)
end

function M:OnEnable()
	start()
end

function M:OnBind()
	start()
end

function M:OnDisable()
	M.Show(false)
end

-- ITS LINE IN THE DOCK, switched and dragged on the Dock's page
function M:DockRow()
	return {
		label = "Ledger", blurb = "From the Ledger: your points and rank", field = "ledgerLine",
		get = function() return M.LineOn() end,
		set = function(v)
			BT.EnsureBound()
			BT.settings.ledgerLine = v and true or false
			if M.frame and BT.Enabled("ledgerline") then
				M.frame:SetShown(v and true or false)
				BT.Dock.Relayout()
			end
		end,
	}
end

-- its toasts, on the Ledger's page (UI/Window.lua, W.PAGE_MODULES)
function M:Parts()
	local function setting(key)
		return function() return on(key, true) end, function(v)
			BT.EnsureBound()
			BT.settings[key] = v and true or false
		end
	end
	local toastGet, toastSet = setting("ledgerToasts")
	local soundGet, soundSet = setting("ledgerSound")
	return {
		{ label = "Rank toasts", blurb = "When you reach a new rank, with a word from Jorach",
			get = toastGet, set = toastSet, field = "ledgerToasts" },
		{ label = "Sound", get = soundGet, set = soundSet, sub = true, field = "ledgerSound" },
	}
end

-- ---------------------------------------------------------------------------
-- For the Testing page
-- ---------------------------------------------------------------------------

-- a made-up commendation, said on the row as a real one is
function M.SampleNotice()
	return BT.Notice.Say(M, { name = "Fine Print", what = "commendation", kind = "commendation", points = 10 })
end

-- your rank's toast, as if just reached
function M.SampleRankToast()
	return M.RankToast((L.Rank((L.Score()))))
end
