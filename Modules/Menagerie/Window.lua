-- The Menagerie, in a window of its own (Josh 2026-09-25).
--
-- Opened from its line in the dock (or /bt menagerie), in the same surface as
-- the Census. Two views, and whose kills they count:
--
--   Bestiary       every kind of mob killed, filed by creature type, and the
--                  one you pick drawn on a turntable - by its NPC id alone,
--                  which this client draws from its creature cache even for a
--                  mob met sessions ago (MobProbe, 70009)
--   Achievements   every milestone, earned or the distance to it, and the
--                  kill records
--
--   This character / All characters   the counts, and so the points, of the
--                  character you are on, or of every one added together
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menagerie/Window.lua")

local U = BT.Util
local V = {}
BT.MenagerieWindow = V

local PAD, TITLE_H = 14, 40
local WIDTH, HEIGHT = 780, 540
local CONTROLS_Y = TITLE_H + 10
local BODY_Y = TITLE_H + 40
local LIST_W, ROW_H = 290, 20
local ACH_H, HEAD_ROW_H = 40, 24

local DIM = { 0.50, 0.55, 0.53 }
local WORDS = "|cff8a9894%s|r"
-- the rank's mark, the tooltip's colours: a gold elite, a silver rare
local RANK = {
	elite = { 1, 0.82, 0.30 },
	rare = { 0.78, 0.84, 0.90 },
	rareelite = { 0.85, 0.92, 1 },
	worldboss = { 1, 0.42, 0.32 },
}
local RANK_WORD = { elite = "Elite", rare = "Rare", rareelite = "Rare Elite", worldboss = "World Boss" }

local frame

-- what the window was left on, kept with the settings
local function ui()
	local s = BT.settings
	if not s then
		return { view = "bestiary", scope = "char", folded = {} }
	end
	s.menagerieUI = s.menagerieUI or {}
	local u = s.menagerieUI
	u.view = u.view or "bestiary"
	u.scope = u.scope or "char"
	u.folded = u.folded or {}
	return u
end

-- 12,345
local function big(n)
	n = math.floor(n or 0)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, s = pcall(BreakUpLargeNumbers, n)
		if ok and type(s) == "string" then
			return s
		end
	end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
V.Big = big

local function level(m)
	if m.skull then
		return "Level ??"
	elseif m.lo and m.hi and m.lo ~= m.hi then
		return ("Level %d-%d"):format(m.lo, m.hi)
	elseif m.lo then
		return ("Level %d"):format(m.lo)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------

function V.Build()
	if frame then
		return frame
	end
	local W = BT.Widgets
	frame = CreateFrame("Frame", "BeebModMenagerie", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 40, -20)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	W.PixelDrag(frame)
	frame:SetClampedToScreen(true)
	W.Panel(frame, W.SOLID)
	tinsert(UISpecialFrames, "BeebModMenagerie") -- escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD + 4, -PAD)
	frame.title:SetText("Menagerie")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

	frame.close = W.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() V.Hide() end)
	W.Divider(frame, PAD, -TITLE_H)

	frame.views = W.Segmented(frame, { { "bestiary", "Bestiary" }, { "achievements", "Achievements" } },
		function(key)
			ui().view = key
			V.Refresh()
		end, 100)
	frame.views:SetPoint("TOPLEFT", PAD, -CONTROLS_Y)
	frame.scopes = W.Segmented(frame, { { "char", "This character" }, { "account", "All characters" } },
		function(key)
			ui().scope = key
			V.Refresh()
		end, 110)
	frame.scopes:SetPoint("TOPRIGHT", -PAD, -CONTROLS_Y)

	V.BuildBestiary()
	V.BuildAchievements()
	frame:Hide()
	return frame
end

-- ---------------------------------------------------------------------------
-- Bestiary
-- ---------------------------------------------------------------------------

function V.BuildBestiary()
	local W = BT.Widgets
	local b = CreateFrame("Frame", nil, frame)
	b:SetPoint("TOPLEFT", PAD, -BODY_Y)
	b:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	frame.bestiary = b

	local box = CreateFrame("Frame", nil, b)
	box:SetPoint("TOPLEFT", 0, 0)
	box:SetPoint("BOTTOMLEFT", 0, 0)
	box:SetWidth(LIST_W)
	W.Panel(box, W.RAISED, W.HAIR)
	b.list = W.Scroller(box, 6)
	b.list:SetPoint("TOPLEFT", 4, -4)
	b.list:SetPoint("BOTTOMRIGHT", -4, 4)
	b.list.step = ROW_H * 3
	b.rows = {}

	-- the page: a turntable, and what we know
	local page = CreateFrame("Frame", nil, b)
	page:SetPoint("TOPLEFT", box, "TOPRIGHT", 12, 0)
	page:SetPoint("BOTTOMRIGHT", 0, 0)
	b.page = page

	local stage = CreateFrame("Frame", nil, page)
	stage:SetPoint("TOPLEFT", 0, 0)
	stage:SetPoint("TOPRIGHT", 0, 0)
	stage:SetHeight(280)
	W.Panel(stage, W.RAISED, W.HAIR)
	local model = CreateFrame("PlayerModel", nil, stage)
	model:SetPoint("TOPLEFT", 1, -1)
	model:SetPoint("BOTTOMRIGHT", -1, 1)
	-- dragged to turn it
	model:EnableMouse(true)
	model.facing = 0
	model:SetScript("OnMouseDown", function(self)
		self.turning = GetCursorPosition()
	end)
	model:SetScript("OnMouseUp", function(self)
		self.turning = nil
	end)
	model:SetScript("OnUpdate", function(self)
		if not self.turning then
			return
		end
		local x = GetCursorPosition()
		self.facing = self.facing + (x - self.turning) * 0.012
		self.turning = x
		pcall(self.SetFacing, self, self.facing)
	end)
	b.model = model

	b.name = page:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	b.name:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 2, -12)
	b.name:SetPoint("RIGHT", page, "RIGHT", -2, 0)
	b.name:SetJustifyH("LEFT")
	b.meta = W.Label(page, "", "small", DIM[1], DIM[2], DIM[3])
	b.meta:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
	b.lines = {}
	local prev = b.meta
	for i = 1, 4 do
		local fs = W.Label(page, "", "small")
		fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -12 or -6)
		fs:SetPoint("RIGHT", page, "RIGHT", -2, 0)
		fs:SetJustifyH("LEFT")
		b.lines[i] = fs
		prev = fs
	end
	b.empty = W.Label(page, "Nothing in the Menagerie yet.\nEvery kind of mob you kill is written in here.",
		"small", DIM[1], DIM[2], DIM[3])
	b.empty:SetPoint("CENTER", stage, "CENTER")
end

local function listRow(i)
	local b = frame.bestiary
	local r = b.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Button", nil, b.list.content)
	r:SetHeight(ROW_H)
	r.lit = r:CreateTexture(nil, "BACKGROUND")
	r.lit:SetAllPoints()
	r.lit:Hide()
	r.chev = r:CreateTexture(nil, "ARTWORK")
	r.chev:SetSize(10, 10)
	r.chev:SetPoint("LEFT", 4, 0)
	r.chev:SetTexture(BT.Bar.ICONS)
	r.mark = r:CreateTexture(nil, "ARTWORK")
	r.mark:SetSize(5, 5)
	r.mark:SetPoint("LEFT", 8, 0)
	r.name = W.Label(r, "", "small")
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.count = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.count:SetPoint("RIGHT", -6, 0)
	r.count:SetJustifyH("RIGHT")
	r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
	r:SetScript("OnClick", function(self)
		if self.kind then
			local folded = ui().folded
			folded[self.kind] = not folded[self.kind] or nil
		else
			V.selected = self.npc
		end
		V.Refresh()
	end)
	r:SetScript("OnEnter", function(self)
		if not self.chosen then
			self.lit:SetColorTexture(1, 1, 1, 0.05)
			self.lit:Show()
		end
	end)
	r:SetScript("OnLeave", function(self)
		if not self.chosen then
			self.lit:Hide()
		end
	end)
	b.rows[i] = r
	return r
end

-- the list, as rows: a heading per type, and its mobs unless it is folded
function V.Entries(pages, folded)
	local out = {}
	for _, p in ipairs(pages) do
		out[#out + 1] = { kind = p.kind, n = #p.mobs }
		if not folded[p.kind] then
			for _, e in ipairs(p.mobs) do
				out[#out + 1] = e
			end
		end
	end
	return out
end

function V.DrawBestiary(kills, all)
	local J = BT.Menagerie
	local b = frame.bestiary
	local u = ui()
	local pages = J.Pages(kills)
	local entries = V.Entries(pages, u.folded)
	-- the one picked, or the first there is
	local first
	for _, p in ipairs(pages) do
		for _, e in ipairs(p.mobs) do
			if e.npc == V.selected then
				first = e.npc
			end
		end
	end
	if not first then
		V.selected = pages[1] and pages[1].mobs[1] and pages[1].mobs[1].npc or nil
	end

	local width = BT.Pill.Number(b.list.content:GetWidth(), LIST_W - 14)
	for i, e in ipairs(entries) do
		local r = listRow(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", b.list.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
		r:SetWidth(width)
		r.kind, r.npc = e.kind, e.npc
		r.chosen = (not e.kind) and e.npc == V.selected
		if e.kind then
			r.chev:Show()
			BT.Bar.ChevronCoord(r.chev, u.folded[e.kind])
			r.chev:SetVertexColor(DIM[1], DIM[2], DIM[3])
			r.mark:Hide()
			r.name:SetPoint("LEFT", r.chev, "RIGHT", 6, 0)
			r.name:SetText(e.kind:upper())
			BT.Widgets.TintText(r.name, 0.8)
			r.count:SetText(tostring(e.n))
		else
			r.chev:Hide()
			local c = RANK[e.m.rank]
			r.mark:SetShown(c ~= nil)
			if c then
				r.mark:SetColorTexture(c[1], c[2], c[3], 1)
			end
			r.name:SetPoint("LEFT", r, "LEFT", 18, 0)
			r.name:SetText(e.m.name or ("#" .. e.npc))
			r.name:SetTextColor(0.92, 0.94, 0.93)
			r.count:SetText(big(e.n))
		end
		if r.chosen then
			local w = BT.Widgets.WASH
			r.lit:SetColorTexture(w[1], w[2], w[3], w[4])
			r.lit:Show()
		else
			r.lit:Hide()
		end
		r:Show()
	end
	for i = #entries + 1, #b.rows do
		b.rows[i]:Hide()
	end
	b.list:SetContentHeight(#entries * ROW_H)
	V.DrawPage(V.selected, kills, all)
end

-- the page of one mob
function V.DrawPage(npc, kills, all)
	local J = BT.Menagerie
	local b = frame.bestiary
	local s = J.Store()
	local m = npc and s and s.mobs[npc]
	b.empty:SetShown(not m)
	b.model:SetShown(m ~= nil)
	b.name:SetShown(m ~= nil)
	b.meta:SetShown(m ~= nil)
	for _, fs in ipairs(b.lines) do
		fs:SetShown(m ~= nil)
	end
	if not m then
		return
	end
	if b.model.npc ~= npc then
		b.model.npc = npc
		b.model.facing = 0
		pcall(b.model.SetCreature, b.model, npc)
		pcall(b.model.SetFacing, b.model, 0)
	end
	b.name:SetText(m.name or ("#" .. npc))
	local c = RANK[m.rank]
	if c then
		b.name:SetTextColor(c[1], c[2], c[3])
	else
		b.name:SetTextColor(1, 1, 1)
	end
	local meta = {}
	for _, part in ipairs({ J.KindOf(m), m.family, level(m), RANK_WORD[m.rank] }) do
		if part then
			meta[#meta + 1] = part
		end
	end
	b.meta:SetText(table.concat(meta, " · "))

	local n = kills[npc] or 0
	local account = ui().scope == "account"
	local line1 = ("Killed %s %s"):format(big(n), n == 1 and "time" or "times")
	if not account and (all[npc] or 0) > n then
		line1 = line1 .. WORDS:format((" · %s by all your characters"):format(big(all[npc])))
	end
	b.lines[1]:SetText(line1)

	-- first killed: this character's, or the earliest of any
	local first
	for who, ch in pairs(s.chars) do
		local at = ch.first and ch.first[npc]
		if at and (account or ch == J.Mine()) and (not first or at < first) then
			first = at
		end
	end
	local when = first and U.ShortDate(first)
	b.lines[2]:SetText(when and (("First killed %s"):format(when)
		.. (m.zone and WORDS:format((" in %s"):format(m.zone)) or "")) or "")

	local nextAt = J.NextRecord(n)
	if nextAt then
		b.lines[3]:SetText(("Next kill record at %s %s"):format(big(nextAt),
			WORDS:format(("· %s to go"):format(big(nextAt - n)))))
	else
		b.lines[3]:SetText("Every kill record earned")
	end
	b.lines[4]:SetText(WORDS:format(("NPC %d · drag the model to turn it"):format(npc)))
end

-- ---------------------------------------------------------------------------
-- Achievements
-- ---------------------------------------------------------------------------

function V.BuildAchievements()
	local W = BT.Widgets
	local a = CreateFrame("Frame", nil, frame)
	a:SetPoint("TOPLEFT", PAD, -BODY_Y)
	a:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	W.Panel(a, W.RAISED, W.HAIR)
	a.list = W.Scroller(a, 6)
	a.list:SetPoint("TOPLEFT", 6, -6)
	a.list:SetPoint("BOTTOMRIGHT", -6, 6)
	a.list.step = ACH_H * 2
	a.rows, a.heads = {}, {}
	frame.achievements = a
	a:Hide()
end

local function achRow(i)
	local a = frame.achievements
	local r = a.rows[i]
	if r then
		return r
	end
	local W = BT.Widgets
	r = CreateFrame("Frame", nil, a.list.content)
	r:SetHeight(ACH_H)
	r.points = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.points:SetPoint("LEFT", 6, 0)
	r.points:SetWidth(34)
	r.points:SetJustifyH("CENTER")
	r.title = r:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	r.title:SetPoint("TOPLEFT", 50, -6)
	r.title:SetJustifyH("LEFT")
	r.text = W.Label(r, "", "small", DIM[1], DIM[2], DIM[3])
	r.text:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
	r.text:SetJustifyH("LEFT")
	r.right = W.Label(r, "", "small")
	r.right:SetPoint("TOPRIGHT", -8, -8)
	r.right:SetJustifyH("RIGHT")
	r.track = r:CreateTexture(nil, "BORDER")
	r.track:SetSize(90, 3)
	r.track:SetPoint("TOPRIGHT", r.right, "BOTTOMRIGHT", 0, -6)
	r.fill = r:CreateTexture(nil, "ARTWORK")
	r.fill:SetHeight(3)
	r.fill:SetPoint("LEFT", r.track, "LEFT", 0, 0)
	r.hair = r:CreateTexture(nil, "BORDER")
	r.hair:SetPoint("TOPLEFT", 0, 0)
	r.hair:SetPoint("TOPRIGHT", 0, 0)
	r.hair:SetHeight(1)
	BT.Widgets.Hairline(r.hair)
	a.rows[i] = r
	return r
end

local function achHead(i)
	local a = frame.achievements
	local h = a.heads[i]
	if h then
		return h
	end
	h = CreateFrame("Frame", nil, a.list.content)
	h:SetHeight(HEAD_ROW_H)
	h.text = h:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	h.text:SetPoint("BOTTOMLEFT", 6, 5)
	BT.Widgets.TintText(h.text, 0.8)
	h.count = BT.Widgets.Label(h, "", "small", DIM[1], DIM[2], DIM[3])
	h.count:SetPoint("BOTTOMRIGHT", -8, 5)
	a.heads[i] = h
	return h
end

-- when an achievement was earned: this character's date, or the earliest of any
local function earnedAt(id, account)
	local J = BT.Menagerie
	local s = J.Store()
	if not account then
		local c = J.Mine()
		return c and c.earned[id]
	end
	local best
	for _, c in pairs(s and s.chars or {}) do
		local at = c.earned and c.earned[id]
		if at and (not best or at < best) then
			best = at
		end
	end
	return best
end

-- The achievements, grouped: each group's own, then the kill records - every
-- one earned, newest first, and the five nearest to being earned.
function V.Groups(kills, feats, account)
	local J = BT.Menagerie
	local st = J.Stats(kills, feats)
	local byGroup = {}
	for _, g in ipairs(J.GROUPS) do
		byGroup[g.key] = {}
	end
	for _, a in ipairs(J.List(st)) do
		a.at = earnedAt(a.id, account)
		local list = byGroup[a.group]
		list[#list + 1] = a
	end
	local earned, next = J.Records(kills)
	for _, r in ipairs(earned) do
		r.at = earnedAt(r.id, account)
	end
	table.sort(earned, function(x, y)
		return (x.at or 0) > (y.at or 0)
	end)
	table.sort(next, function(x, y)
		return x.have / x.need > y.have / y.need
	end)
	local records = byGroup.records
	for _, r in ipairs(earned) do
		records[#records + 1] = r
	end
	for i = 1, math.min(5, #next) do
		records[#records + 1] = next[i]
	end
	local out = {}
	for _, g in ipairs(J.GROUPS) do
		local list = byGroup[g.key]
		if #list > 0 then
			local done = 0
			for _, a in ipairs(list) do
				if a.have >= a.need then
					done = done + 1
				end
			end
			out[#out + 1] = { title = g.title, list = list, done = done, key = g.key }
		end
	end
	return out
end

function V.DrawAchievements(kills, feats)
	local a = frame.achievements
	local account = ui().scope == "account"
	local accent = BT.Widgets.ACCENT
	local width = BT.Pill.Number(a.list.content:GetWidth(), WIDTH - PAD * 2 - 20)
	local y, ri, hi = 0, 0, 0
	for _, g in ipairs(V.Groups(kills, feats, account)) do
		hi = hi + 1
		local h = achHead(hi)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
		h:SetWidth(width)
		h.text:SetText(g.title:upper())
		-- the records have no end to them, so no "of"
		if g.key == "records" then
			h.count:SetText(("%d earned"):format(g.done))
		else
			h.count:SetText(("%d / %d"):format(g.done, #g.list))
		end
		h:Show()
		y = y + HEAD_ROW_H
		for _, it in ipairs(g.list) do
			ri = ri + 1
			local r = achRow(ri)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", a.list.content, "TOPLEFT", 0, -y)
			r:SetWidth(width)
			local done = it.have >= it.need
			r.points:SetText(tostring(it.points))
			r.title:SetText(it.title)
			r.text:SetText(it.text)
			if done then
				r.points:SetTextColor(accent[1], accent[2], accent[3])
				r.title:SetTextColor(1, 1, 1)
				r.right:SetText(it.at and U.ShortDate(it.at) or "earned")
				r.right:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.track:Hide()
				r.fill:Hide()
			else
				r.points:SetTextColor(DIM[1], DIM[2], DIM[3])
				r.title:SetTextColor(0.62, 0.66, 0.64)
				r.right:SetText(("%s / %s"):format(big(it.have), big(it.need)))
				r.right:SetTextColor(0.75, 0.78, 0.77)
				r.track:SetColorTexture(1, 1, 1, 0.07)
				r.fill:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
				local share = math.min(1, it.have / it.need)
				r.track:Show()
				-- a texture of no width is drawn whole: an empty bar is no bar
				r.fill:SetShown(share > 0)
				r.fill:SetWidth(math.max(1, 90 * share))
			end
			r:Show()
			y = y + ACH_H
		end
	end
	for i = ri + 1, #a.rows do
		a.rows[i]:Hide()
	end
	for i = hi + 1, #a.heads do
		a.heads[i]:Hide()
	end
	a.list:SetContentHeight(y + 6)
end

-- ---------------------------------------------------------------------------
-- Drawing, opening, closing
-- ---------------------------------------------------------------------------

function V.Refresh()
	if not (frame and frame:IsShown()) then
		return false
	end
	local J = BT.Menagerie
	if not J.Store() then
		return false
	end
	local u = ui()
	frame.views:Select(u.view)
	frame.scopes:Select(u.scope)
	local kills, feats = J.Counts(u.scope)
	local all = u.scope == "account" and kills or J.Counts("account")
	local points, _, st = J.Points(kills, feats)
	frame.subtitle:SetText(("%s · %s kinds · %s kills · %s points"):format(
		u.scope == "account" and "all characters" or ((U.Me and U.Me()) or "this character"),
		big(st.kinds), big(st.total), big(points)))
	local bestiary = u.view ~= "achievements"
	frame.bestiary:SetShown(bestiary)
	frame.achievements:SetShown(not bestiary)
	if bestiary then
		V.DrawBestiary(kills, all)
	else
		V.DrawAchievements(kills, feats)
	end
	return true
end

-- a kill while it is open: drawn once for a burst of them, not once each
function V.Changed()
	if not (frame and frame:IsShown()) or V.pending then
		return
	end
	V.pending = true
	local function go()
		V.pending = nil
		V.Refresh()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, go)
	else
		go()
	end
end

-- open, on a mob or a view if one is named
function V.Show(npc, view)
	if not BT.Enabled("menagerie") then
		return false
	end
	BT.EnsureBound()
	V.Build()
	if npc then
		V.selected = npc
		ui().view = "bestiary"
	elseif view then
		ui().view = view
	end
	frame:Show()
	frame:Raise()
	V.Refresh()
	return true
end

function V.Hide()
	if frame then
		frame:Hide()
	end
end

function V.IsShown()
	return frame and frame:IsShown() and true or false
end

function V.Toggle()
	if V.IsShown() then
		V.Hide()
		return false
	end
	return V.Show()
end

-- the tests reach in here
function V.Frame() return frame end
