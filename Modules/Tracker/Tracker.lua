-- Quest tracker: ours, not theirs, wearing the tooltip's clothes
-- (Josh 2026-09-19).
--
-- The first version restyled the client's tracker. It came out looking like
-- the client's tracker in a dark coat: the orange titles, the round map icons,
-- the two collapsing headers and the panel that runs the whole height of the
-- screen whether it holds four quests or none. Styling cannot fix a layout.
--
-- So this draws it. Every quest you are following, in the toolkit's own type:
--
--   ▌ QUESTS   4
--   ▌
--   ▌ * [7] Evershine              the mark, the level, the name
--   ▌     Get a cask of Evershine
--   ▌ * [8] Treacherous Cold
--   ▌     0/1 Stoneanvil's Rifle   counts read where you read, at the start
--   ▌     1/1 Sunhammer's Rifle    done: struck through, and still readable
--   ▌ v [9] Frostmane Hold         ready to hand in
--
-- ONE COLUMN, like the tracker everybody already knows how to read. It had the
-- level and the counts in a right-hand column, which is the tooltip's habit and
-- wrong here: a tooltip is two lines and a tracker is twenty, and twenty lines
-- of numbers down the right edge is a second thing to read (Josh 2026-09-19).
--
-- THE ONE YOU ARE DOING IS BANDED. A dot at the start of the line says which
-- quest the map is pointing at - except on a quest that is ready to hand in,
-- where that slot is a green check and there is nowhere left to put it. So the
-- active quest gets a band instead: a wash the width of the panel behind its
-- title and its objectives, with a hairline above and below. It reads at a
-- glance, it reads on a completed quest, and it costs no space (Josh
-- 2026-09-19).
--
-- IT FOLDS, like the tracker everybody already knows. The header folds the
-- whole list away and leaves a line saying how many are in it; right-clicking
-- a quest folds that quest's objectives and leaves its title. Both are
-- remembered, because a list you have to re-fold every login is a list you
-- stop folding.
--
-- THE MARK AT THE START OF A QUEST is the client's own "which one am I doing":
-- click it and the map points at that quest. A dot for a quest in progress,
-- jade when it is the one you are following, a green check when it is ready to
-- hand in.
--
-- WHAT IT KEEPS. Click a quest to open it, shift-click to stop following it,
-- and the panel is exactly as tall as what is in it. This client's tracker has
-- no progress bars, and that is still a thing to revisit the day they arrive.
--
-- THE QUEST'S ITEM (Josh 2026-09-22). A quest that hands you something to use
-- gets a button for it at the right end of its title: the item's picture,
-- its charges, its cooldown, its tooltip, and a click uses it. It is a secure
-- action button of ours, which is the one thing here the client puts rules
-- on: in combat it cannot be shown, hidden, moved or given another item. So
-- it lives on a plain holder of ours that can be shown and hidden freely,
-- and the one thing that is locked - which item it is - is only ever changed
-- out of combat. A row whose item changed mid-fight puts the button away
-- rather than showing the wrong thing, and catches up when the fight ends.
--
-- The client's own tracker is hidden while ours is up, and shown again the
-- moment the module is switched off.
--
-- IT IS NOT A PANEL OF ITS OWN. It is a section of the toolkit's dock, under
-- the row of cells - one thing on screen to drag, in one skin, rather than two
-- identical panels that have to be arranged separately every time you touch
-- your UI (Josh 2026-09-19).
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Tracker/Tracker.lua")

local U, Q = BT.Util, BT.Quests

local M = BT.Module({
	key = "tracker",
	feature = "dock",
	title = "Quest tracker",
	blurb = "The quests you track, in the dock",
	order = 40,
	-- on the right panel, so it has a tab on the rail (Josh 2026-09-22)
	dock = true,
})

-- the tooltip's sizes, because it is the same addon
-- in the game's face; the face in use moves them (Core/Fonts.lua)
local TITLE, LINE, HEAD = 12, 10, 10
local INK = { 0.87, 0.92, 0.89 }
local DIM = { 0.58, 0.65, 0.62 }
local MUTED = { 0.42, 0.48, 0.45 }
local DONE = { 0.36, 0.70, 0.48 }
local READY = { 1.00, 0.83, 0.25 }
local FAILED = { 0.86, 0.33, 0.33 }
-- the same inset as the dock's own two lines, so the quests line up under the
-- class icon rather than starting again further in (Josh 2026-09-19)
local ROW, GAP, PAD = 15, 4, 6
-- THE DOCK DECIDES HOW TALL (Josh 2026-09-23). The list used to stop at a
-- fixed share of the screen, whatever else was in the dock and wherever the
-- dock was - so a dock dragged to the top of the screen still scrolled at
-- 45%, and one with a map above the quests still ran off the bottom. The
-- tracker says how tall it would like to be; the dock gives it what is left
-- between everything else and the bottom of the screen (see BT.Dock.Room),
-- and the list scrolls past that. The QUESTS line stays put while it does:
-- it is the fold and the handle, and a list whose header scrolls away is a
-- list you cannot fold without scrolling back up.
-- the fewest quest lines the list is ever squeezed to, under its header
local MIN_LINES = 3
-- how far down the list you are, in pixels. Not a setting: it is where you
-- happen to be looking, and next login you are looking at the top again.
M.scroll = 0
local MARK, INDENT = 12, 18 -- the mark at the start of a title, and the text after it
local NEST = 10 -- how much further in an objective sits than the quest it belongs to

local frame, rows, header
-- declared here because Update draws the band and is written above the place
-- that knows how to draw it (paintBand too: without the declaration it was a
-- global, and any addon defining one would have replaced it)
local band, paintBand

local function opt(name, fallback)
	local s = BT.settings and BT.settings.tracker
	if not s or s[name] == nil then
		return fallback
	end
	return s[name]
end
M.Opt = opt

local function setOpt(name, value)
	BT.EnsureBound()
	BT.settings.tracker = BT.settings.tracker or {}
	BT.settings.tracker[name] = value
	M.Update()
	M:RefreshTab()
end
M.SetOpt = setOpt

-- ---------------------------------------------------------------------------
-- The client's own, out of the way
-- ---------------------------------------------------------------------------
local CLIENT_NAMES = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

function M.ClientFrame()
	for _, name in ipairs(CLIENT_NAMES) do
		local f = _G[name]
		if f and f.GetObjectType then
			M.foundAs = name
			return f
		end
	end
	M.foundAs = nil
	return nil
end

-- NOT IN A FIGHT IF IT IS PROTECTED (Josh 2026-09-30, review). The client's
-- tracker puts itself back on quest progress, which is often mid-fight, and
-- one that holds the game's secure item buttons is protected: hiding or
-- showing it then is "action blocked". In a fight it only goes see-through
-- (alpha is never locked), and is hidden or shown for real when it ends.
local function locked(f)
	return type(InCombatLockdown) == "function" and InCombatLockdown()
		and f.IsProtected and f:IsProtected() and true or false
end

local function hideNow(f)
	if locked(f) then
		pcall(f.SetAlpha, f, 0)
		M.clientFaded, M.clientLater = true, true
		return
	end
	f:Hide()
	if M.clientFaded then
		M.clientFaded = nil
		f:SetAlpha(1)
	end
end

local function hideClient()
	local f = M.ClientFrame()
	if not f then
		return false
	end
	if not M.clientHooked and f.HookScript then
		-- it puts itself back whenever a quest changes, so we have to mean it
		f:HookScript("OnShow", function(self)
			if BT.Enabled("tracker") then
				hideNow(self)
			end
		end)
		M.clientHooked = true
	end
	hideNow(f)
	return true
end

local function showClient()
	local f = M.ClientFrame()
	if not f then
		return
	end
	if M.clientFaded then
		M.clientFaded = nil
		pcall(f.SetAlpha, f, 1)
	end
	if locked(f) then
		M.clientLater = true
		return
	end
	f:Show()
end

-- what a fight held back, done when it ends: the client's tracker hidden
-- while ours is on, and shown while it is not
local function settleClient()
	if not M.clientLater then
		return
	end
	M.clientLater = nil
	if BT.Enabled("tracker") then
		hideClient()
	else
		showClient()
	end
end

-- ---------------------------------------------------------------------------
-- Ours
-- ---------------------------------------------------------------------------
local function line(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	if BeebModFontHighlightSmall and BeebModFontHighlightSmall.GetFont then
		local face, _, flags = BeebModFontHighlightSmall:GetFont()
		if face then
			pcall(fs.SetFont, fs, face, size, flags)
		end
	end
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	return fs
end

local function folded(quest)
	local f = BT.settings and BT.settings.tracker and BT.settings.tracker.folded
	return (f and quest.questID and f[quest.questID]) and true or false
end

local function fold(quest, on)
	if not (quest and quest.questID) then
		return
	end
	BT.EnsureBound()
	BT.settings.tracker = BT.settings.tracker or {}
	BT.settings.tracker.folded = BT.settings.tracker.folded or {}
	if on then
		BT.settings.tracker.folded[quest.questID] = true
	else
		BT.settings.tracker.folded[quest.questID] = nil
	end
end

local function rowFrame(i)
	local row = rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, frame)
	row:SetHeight(ROW)
	row:SetPoint("LEFT", frame, "LEFT", PAD, 0)
	row:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	-- the mark: a button of its own, because it does its own job. A dot for a
	-- quest you are following, a check for one that is done.
	--
	-- THE TARGET IS THE GUTTER, NOT THE DOT (Josh 2026-09-19). The mark is five
	-- pixels square and was its own hit area, which is a dart game. The button
	-- is the whole width of the indent and the whole height of the line - about
	-- eight times the area - and the dot inside it does not change size.
	row.mark = CreateFrame("Button", nil, row)
	row.mark:SetSize(INDENT, ROW)
	row.mark:SetPoint("LEFT", 0, 0)
	row.mark.hot = row.mark:CreateTexture(nil, "BACKGROUND")
	row.mark.hot:SetPoint("CENTER")
	row.mark.hot:SetSize(MARK + 2, MARK + 2)
	row.mark.hot.beebsTint = 0.18
	row.mark.hot:Hide()
	row.mark.dot = row.mark:CreateTexture(nil, "ARTWORK")
	row.mark.dot:SetSize(5, 5)
	row.mark.dot:SetPoint("CENTER")
	row.mark.check = row.mark:CreateTexture(nil, "ARTWORK")
	row.mark.check:SetSize(MARK, MARK)
	row.mark.check:SetPoint("CENTER")
	row.mark.check:SetTexture(BT.Dock.ICONS)
	BT.Dock.CheckCoord(row.mark.check)
	row.mark:SetScript("OnClick", function(self)
		if self.quest then
			Q.SuperTrack(self.quest)
			M.Update()
		end
	end)
	row.mark:SetScript("OnEnter", function(self)
		if self.quest then
			local c = BT.Widgets.RIM
			self.hot:SetColorTexture(c[1], c[2], c[3], self.hot.beebsTint)
			self.hot:Show()
			BT.Tip.Show(self, { build = function(t)
				t:Header({ icon = false, name = self.quest.title or "Quest" })
				t:Foot({ { "Click", "track it on the map" } })
			end })
		end
	end)
	row.mark:SetScript("OnLeave", function(self)
		self.hot:Hide()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	-- DONE IS A LINE THROUGH IT (Josh 2026-09-19). Objectives wore a green
	-- check, which is a second column of marks to read down and says the same
	-- thing the colour already said. A line through the words is how everybody
	-- crosses something off, and it is drawn at half alpha so the objective is
	-- still legible - you often want to know WHAT you finished.
	row.strike = row:CreateTexture(nil, "OVERLAY")
	row.strike:SetHeight(1)
	row.strike:Hide()

	row.chevron = row:CreateTexture(nil, "ARTWORK")
	row.chevron:SetSize(MARK, MARK)
	row.chevron:SetPoint("LEFT", 0, 0)
	row.chevron:SetTexture(BT.Dock.ICONS)
	row.chevron:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 1)
	row.chevron:Hide()

	row.text = line(row, LINE, DIM[1], DIM[2], DIM[3])
	row.text:SetPoint("LEFT", INDENT, 0)
	row.text:SetPoint("RIGHT", 0, 0)
	row.text:SetWordWrap(false)
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	row.hot.beebsTint = 0.10
	row.hot:Hide()
	row:SetScript("OnEnter", function(self)
		if self.quest or self.isHeader then
			local c = BT.Widgets.RIM
			self.hot:SetColorTexture(c[1], c[2], c[3], self.hot.beebsTint)
			self.hot:Show()
		end
		if self.quest and self.kind == "title" then
			M.QuestTip(self, self.quest)
		end
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		if BT.Tip then
			BT.Tip.Hide()
		end
	end)
	row:SetScript("OnClick", function(self, click)
		if self.isHeader then
			setOpt("collapsed", not opt("collapsed", false))
			return
		end
		if not self.quest then
			return
		end
		if click == "RightButton" then
			fold(self.quest, not folded(self.quest))
			M.Update()
		elseif IsShiftKeyDown and IsShiftKeyDown() then
			Q.Drop(self.quest)
			M.Update()
		else
			Q.Open(self.quest)
		end
	end)
	row:RegisterForClicks("AnyUp")
	rows[i] = row
	return row
end

-- `kind` is "head", "title" or "line"; `mark` is "dot", "tracking", "check",
-- or nil for nothing at the start of the line.
-- the item's own size on the line, and the room the title leaves for it
local ITEM_GAP = 4

-- THE SECURE BUTTON IS NOT THE DOCK'S (Josh 2026-09-23, audit). It used to
-- sit inside its row, and a frame with a protected frame anywhere under it is
-- protected too: the row, the tracker, and the whole dock became frames the
-- client will not let an addon move, size, show or hide in a fight - every
-- quest update and every dock relayout in combat an "action blocked". The
-- row keeps a holder of ours, which only marks the spot; the button itself
-- belongs to the screen and is laid over the holder whenever things settle,
-- out of combat (M.PlaceItems). In a fight it cannot move, so if its row
-- moves or goes it is made invisible where it stands until the fight ends.
local placed = setmetatable({}, { __mode = "k" })

local function inCombatNow()
	return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- every item button over its holder, or put away when its holder is not seen
function M.PlaceItems()
	local num = BT.Pill.Number
	for _, row in ipairs(rows or {}) do
		local holder = row.item
		local b = holder and holder.button
		if b then
			local want = holder:IsVisible() and holder.wanted
			local l, t = num(holder:GetLeft(), nil), num(holder:GetTop(), nil)
			local w, h = num(holder:GetWidth(), 0), num(holder:GetHeight(), 0)
			local hs, bs = num(holder:GetEffectiveScale(), 0), num(b:GetEffectiveScale(), 0)
			local where
			if want and l and t and hs > 0 and bs > 0 then
				local k = hs / bs
				where = { l * k, t * k, w * k, h * k }
			end
			local p = placed[b]
			local same = where and p and math.abs(p[1] - where[1]) < 0.5 and math.abs(p[2] - where[2]) < 0.5
				and math.abs(p[3] - where[3]) < 0.5
			if inCombatNow() then
				-- nothing secure moves in a fight: seen only where it still is
				pcall(b.SetAlpha, b, (want and same) and 1 or 0)
				if not same then
					M.itemsPending = true
				end
			elseif where then
				if not same then
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", where[1], where[2])
					b:SetSize(where[3], where[4])
					placed[b] = where
				end
				pcall(b.SetFrameStrata, b, holder:GetFrameStrata() or "MEDIUM")
				pcall(b.SetFrameLevel, b, (holder:GetFrameLevel() or 1) + 4)
				b:SetAlpha(1)
				b:Show()
			else
				b:Hide()
				placed[b] = nil
			end
		end
	end
end

local function itemButton(row)
	if row.item then
		return row.item
	end
	-- the holder is ours, takes no rules and marks the spot; the button is
	-- the screen's (see above)
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(ROW, ROW)
	-- beside the title's first line, however many it wraps to
	holder:SetPoint("TOPRIGHT", 0, 0)
	holder.beebs = true
	holder:SetScript("OnShow", function() M.PlaceItems() end)
	holder:SetScript("OnHide", function() M.PlaceItems() end)
	local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	b:SetSize(ROW, ROW)
	b:Hide()
	-- ONE USE A PRESS (Josh 2026-09-24: using a quest item "seems to cause an
	-- error, it did seem to work though"). Heard on the way down AND up, a
	-- click used the item twice: the first worked, the second was refused
	-- with the client's red error. It listens for whichever the action bars
	-- act on - the press, if you have them use the key down.
	if b.RegisterForClicks then
		local onDown = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown")
		b:RegisterForClicks(onDown and "AnyDown" or "AnyUp")
	end
	if b.SetAttribute then
		b:SetAttribute("type", "item")
	end
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- the toolkit's own rim round the picture, like a slot on the sheet
	b.rim = BT.Pill.Ring(b, "OVERLAY", 1)
	BT.Pill.PlaceRing(b.rim, b, 0, 1, 0)
	BT.Pill.PaintRing(b.rim, BT.Widgets.RIM)
	b.count = line(b, 8, 1, 1, 1)
	b.count:SetPoint("BOTTOMRIGHT", -1, 1)
	b.count:SetJustifyH("RIGHT")
	if CreateFrame then
		local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
		if ok and cd then
			cd:SetAllPoints()
			cd.beebs = true
			if cd.SetDrawEdge then
				pcall(cd.SetDrawEdge, cd, false)
			end
			b.cd = cd
		end
	end
	b:SetScript("OnEnter", function(self)
		if not (GameTooltip and self.link) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if GameTooltip.SetHyperlink then
			pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	holder.button = b
	row.item = holder
	return holder
end

local inCombat = inCombatNow

local function itemCooldown(b)
	if not (b and b.cd and b.index) then
		return
	end
	local start, duration, enable = Q.ItemCooldown(b.index)
	if type(start) ~= "number" or type(duration) ~= "number" then
		return
	end
	if type(CooldownFrame_Set) == "function" then
		pcall(CooldownFrame_Set, b.cd, start, duration, enable)
	elseif b.cd.SetCooldown then
		pcall(b.cd.SetCooldown, b.cd, start, duration)
	end
end

-- the item on a title row, or nothing on any other kind of row
local function placeItem(row, item)
	if not item then
		if row.item then
			row.item.wanted = false
			row.item:Hide()
		end
		return false
	end
	-- a button is made and given its action out of combat only: made in a
	-- fight it would be left with no action for the session
	if not row.item and inCombat() then
		M.itemsPending = true
		return false
	end
	local holder = itemButton(row)
	local b = holder.button
	if b.link ~= item.link then
		-- WHICH ITEM is the one locked thing: not in combat
		if inCombat() then
			holder.wanted = false
			holder:Hide()
			M.itemsPending = true
			return false
		end
		b.link, b.index = item.link, item.index
		if b.SetAttribute then
			b:SetAttribute("item", item.link)
		end
	end
	b.index = item.index
	if b.icon.SetTexture then
		b.icon:SetTexture(item.icon)
	end
	b.count:SetText((item.charges or 0) > 1 and tostring(item.charges) or "")
	itemCooldown(b)
	holder.wanted = true
	holder:Show()
	return true
end

-- every shown item's cooldown, when the client says one changed
function M.UpdateCooldowns()
	for _, row in ipairs(rows or {}) do
		if row.item and row.item:IsShown() then
			itemCooldown(row.item.button)
		end
	end
end

-- LONG LINES WRAP (Josh 2026-10-01: "some quest text is running off the
-- right side of the dock"). A title or an objective too long for one line
-- goes on to a second and a third, and its row grows to hold them. A crossed
-- off objective stays on one line: its line through is drawn to the width of
-- the words, and on a wrapped one there is no knowing where each line ends.
local WRAP_LINES = 3

-- how wide the list is: the dock's last layout, or its setting before it has
-- had one
local function listWidth()
	local w = BT.Pill.Number(frame and frame:GetWidth(), 0)
	if w < 100 then
		w = BT.Dock.Width()
	end
	return w
end

-- the row's words from `left` to `right` short of its end, and how tall that
-- makes the row
local function layText(row, left, right, wrap, size)
	local num = BT.Pill.Number
	local fs = row.text
	fs:ClearAllPoints()
	fs:SetWidth(math.max(1, listWidth() - 2 * PAD - left - right))
	fs:SetWordWrap(wrap and true or false)
	if fs.SetMaxLines then
		pcall(fs.SetMaxLines, fs, wrap and WRAP_LINES or 1)
	end
	local tall, lines = ROW, 1
	if wrap then
		local h = num(fs.GetStringHeight and fs:GetStringHeight(), 0)
		local ok, n = false, nil
		if fs.GetNumLines then
			ok, n = pcall(fs.GetNumLines, fs)
		end
		n = ok and num(n, nil) or nil
		-- no count of lines: the height says it, a line being the font's size
		-- and a little
		if not n and h > 0 then
			n = math.max(1, math.floor(h / (size * 1.15) + 0.5))
		end
		if n and n > 1 and h > 0 then
			lines = n
			local one = h / n
			fs:SetJustifyV("TOP")
			fs:SetPoint("TOPLEFT", row, "TOPLEFT", left, -math.max(0, (ROW - one) / 2))
			tall = math.ceil(ROW + h - one)
		end
	end
	if lines == 1 then
		fs:SetJustifyV("MIDDLE")
		fs:SetPoint("LEFT", row, "LEFT", left, 0)
	end
	return tall
end

local function setRow(i, y, kind, text, mark, colour, quest)
	local row = rowFrame(i)
	row.endsAt = nil
	-- EVERY ROW IS PLACED, NOT EVERY ROW IS SEEN (Josh 2026-09-20). What is
	-- past the height the dock gave the list is scrolled to rather than drawn
	-- off the bottom of the screen. The rows sit where they always sat; M.Fit
	-- shifts the column up by however far you have scrolled.
	row.top = y
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
	row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
	row.text:SetFontObject(nil)
	local size = BT.Fonts.Size((kind == "title" or kind == "clock") and TITLE
		or ((kind == "head" or kind == "zone") and HEAD or LINE))
	pcall(row.text.SetFont, row.text, select(1, row.text:GetFont()), size, select(3, row.text:GetFont()))
	row.text:SetText(text or "")
	row.text:SetTextColor(colour[1], colour[2], colour[3])

	-- NESTED, NOT NEXT (Josh 2026-09-19). Objectives sat on the same left edge
	-- as the quest they belong to, which reads as five things in a list rather
	-- than two quests with objectives under them. They step in, and their check
	-- steps in with them so the ticks line up in a gutter of their own.
	row.text:ClearAllPoints()
	-- A CLOCK YOU CANNOT MISS (Josh 2026-09-29: "it doesn't stand out very
	-- much. Can we make it larger and highlight it somehow"): the title's
	-- size, a pocket watch before it, and a band of its colour behind it
	local clock = kind == "clock"
	if clock and not row.watch then
		row.band = row:CreateTexture(nil, "BACKGROUND")
		row.band:SetPoint("TOPLEFT", row, "TOPLEFT", INDENT + NEST - 4, 0)
		row.band:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.watch = row:CreateTexture(nil, "ARTWORK")
		row.watch:SetSize(12, 12)
		row.watch:SetPoint("LEFT", row, "LEFT", INDENT + NEST, 0)
		row.watch:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
		row.watch:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	if row.watch then
		row.watch:SetShown(clock)
		row.band:SetShown(clock)
		if clock then
			row.band:SetColorTexture(colour[1], colour[2], colour[3], 0.14)
		end
	end
	local left = (kind == "line" and (INDENT + NEST)) or (clock and (INDENT + NEST + 16))
		or (kind == "zone" and 0 or INDENT)
	-- the mark beside the first line, however many the words wrap to
	row.mark:ClearAllPoints()
	row.mark:SetPoint("TOPLEFT", kind == "line" and NEST or 0, 0)
	row.mark:SetSize(INDENT, ROW)
	-- the quest's item, on its title and nowhere else; the title stops short
	-- of it
	local item = placeItem(row, kind == "title" and quest and quest.item or nil)
	row.tall = layText(row, left, item and (ROW + ITEM_GAP) or 0,
		(kind == "title" or kind == "line") and mark ~= "strike", size)
	row:SetHeight(row.tall)

	row.kind = kind
	row.isHeader = (kind == "head")
	row.chevron:SetShown(row.isHeader)
	if row.isHeader then
		BT.Dock.ChevronCoord(row.chevron, opt("collapsed", false))
		BT.Dock.MakeHandle(row) -- the one line of the dock that is not a control
	end

	if mark == "strike" then
		-- the width of the words, not of the line they sit on
		local w = BT.Pill.Number(row.text.GetStringWidth and row.text:GetStringWidth(),
			#(text or "") * 5)
		-- and no wider than the line: words cut short with "..." are still
		-- measured whole, and the line through ran off the dock
		local room = BT.Pill.Number(row.text:GetWidth(), w)
		row.strike:ClearAllPoints()
		row.strike:SetPoint("LEFT", row.text, "LEFT", 0, 0)
		row.strike:SetWidth(math.max(8, math.min(w, room)))
		row.strike:SetColorTexture(colour[1], colour[2], colour[3], 0.55)
		row.strike:Show()
	else
		row.strike:Hide()
	end

	row.mark.quest = quest
	if mark == "check" or mark == "failed" then
		local failed = mark == "failed"
		local c = failed and FAILED or DONE
		if failed then
			BT.Dock.CrossCoord(row.mark.check)
		else
			BT.Dock.CheckCoord(row.mark.check)
		end
		row.mark.check:SetVertexColor(c[1], c[2], c[3], 1)
		row.mark.check:Show()
		row.mark.dot:Hide()
		row.mark:Show()
	elseif mark == "dot" or mark == "tracking" then
		local c = (mark == "tracking") and BT.Widgets.RIM or MUTED
		local size = (mark == "tracking") and 7 or 5
		row.mark.dot:SetColorTexture(c[1], c[2], c[3], 1)
		row.mark.dot:SetSize(size, size)
		row.mark.dot:Show()
		row.mark.check:Hide()
		row.mark:Show()
	else
		row.mark:Hide()
		row.mark.quest = nil
	end
	row.mark:EnableMouse(row.mark.quest ~= nil)
	row.markKind = mark

	row.quest = quest
	row:EnableMouse(quest ~= nil or row.isHeader)
	row:Show()
	return y + row.tall + (kind == "title" and 1 or 0)
end

-- A colour as a text escape, for the parts of a line that are not the line's
-- own colour: the level in front of a title, the count in front of an
-- objective. One string, one column, two colours.
local function tint(color, text)
	return ("|cff%02x%02x%02x%s|r"):format(
		math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), text)
end

-- HOW HARD IT IS, WORKED OUT HERE (Josh 2026-09-19). This was GetQuestDifficultyColor,
-- which on this build does not answer the question the client's own quest log
-- answers: at level 10 it calls a level 6 quest yellow and a level 13 one red,
-- where the log beside it draws them green and orange. Measured, not guessed -
-- /bt tracker colours printed 1.00 0.82 0.00 for every quest but one.
--
-- So the five bands are worked out from your level and the quest's, the way
-- they have been since the game shipped:
--
--   +5 or more   red        it will kill you
--   +3 or +4     orange     bring somebody
--   -2 to +2     yellow     about right
--   within the green range  green      easy
--   below that   grey       not worth the time
--
-- GetQuestGreenRange is the client's own idea of how far below your level a
-- quest stays worth doing; it narrows as you level, and five is what it is
-- around here if the call is missing.
local DIFFICULTY = {
	impossible = { 1.00, 0.24, 0.24 },
	verydifficult = { 1.00, 0.50, 0.25 },
	difficult = { 1.00, 0.82, 0.00 },
	standard = { 0.35, 0.78, 0.38 },
	trivial = { 0.58, 0.62, 0.60 },
}

local function greenRange()
	if not GetQuestGreenRange then
		return 5
	end
	-- newer clients want the unit, older ones take nothing at all
	local ok, n = pcall(GetQuestGreenRange, "player")
	if not ok then
		ok, n = pcall(GetQuestGreenRange)
	end
	return BT.Pill.Number(ok and n or nil, 5)
end

local function levelColour(level)
	local mine = BT.Pill.Number(UnitLevel and UnitLevel("player"), 0)
	if not (level and level > 0 and mine > 0) then
		return MUTED
	end
	local diff = level - mine
	if diff >= 5 then
		return DIFFICULTY.impossible
	elseif diff >= 3 then
		return DIFFICULTY.verydifficult
	elseif diff >= -2 then
		return DIFFICULTY.difficult
	elseif -diff <= greenRange() then
		return DIFFICULTY.standard
	end
	return DIFFICULTY.trivial
end
M.LevelColour = levelColour

-- BY ZONE, AND LOWEST FIRST IN EACH (Josh 2026-09-24: "we need to add the
-- zone sub headers, and then sort them by level per zone"). The quest log
-- keeps its quests under their zones, in the order you took them; with the
-- zones not shown that read as no order at all. The zones are back as small
-- headings - the one you are standing in first, the rest in the log's order
-- - and inside each the lowest level comes first, the same level in the
-- log's order. "By level" off keeps the log's order inside a zone.
function M.Sort(quests, here)
	local rank, n = {}, 0
	for _, q in ipairs(quests) do
		local z = q.zone or ""
		if rank[z] == nil then
			n = n + 1
			rank[z] = n
		end
	end
	if here and rank[here] then
		rank[here] = 0
	end
	local byLevel = opt("byLevel", true)
	-- with no headings, no grouping either: a zone's quests together under
	-- nothing that says so reads as no order (Josh 2026-09-24)
	local grouped = opt("zones", true)
	table.sort(quests, function(a, b)
		local za, zb = rank[a.zone or ""], rank[b.zone or ""]
		if grouped and za ~= zb then
			return za < zb
		end
		if byLevel then
			local la, lb = a.level or 0, b.level or 0
			if la ~= lb then
				return la < lb
			end
		end
		return (a.index or 0) < (b.index or 0)
	end)
	return quests
end

-- ONLY HERE, IF YOU LIKE (Josh 2026-09-24): the quests of the zone you are
-- standing in, and none from elsewhere; all of them where it cannot be told
function M.Filter(quests, here)
	if not (opt("hereOnly", false) and here) then
		return quests
	end
	local out = {}
	for _, q in ipairs(quests) do
		if q.zone == here then
			out[#out + 1] = q
		end
	end
	return out
end

-- the zone you are standing in, as the quest log names zones
local function hereZone()
	local get = _G.GetRealZoneText or _G.GetZoneText
	local ok, z = pcall(function() return get and get() end)
	return ok and type(z) == "string" and z ~= "" and z or nil
end

-- A QUEST'S OWN TOOLTIP (Josh 2026-09-27, the dock's tooltips redrawn; the
-- rows had none): its zone and level, how many objectives are done, each one
-- with its count and a bar, and the clicks a row already answers to
-- "4:32 left", "1:02:09 left": a quest's clock, as it stands at `now`
function M.TimeLeft(endsAt, now)
	local secs = math.max(0, math.floor((endsAt or 0) - (now or ((type(GetTime) == "function" and GetTime()) or 0))))
	local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60
	if h > 0 then
		return ("%d:%02d:%02d left"):format(h, m, s)
	end
	return ("%d:%02d left"):format(m, s)
end

-- amber while it runs; red in the last minute
local CLOCK = { 1.00, 0.72, 0.28 }
local function clockColour(endsAt, now)
	return (endsAt - now) < 60 and FAILED or CLOCK
end

-- THE CLOCK TICKS ON ITS OWN (the list is not drawn again every second): the
-- rows that hold a clock have their words set again, once a second, while
-- any is shown
function M.TickClocks()
	local now = (type(GetTime) == "function" and GetTime()) or 0
	local any = false
	for _, row in ipairs(rows or {}) do
		if row.endsAt and row:IsShown() then
			any = true
			row.text:SetText(M.TimeLeft(row.endsAt, now))
			local c = clockColour(row.endsAt, now)
			row.text:SetTextColor(c[1], c[2], c[3])
			if row.band then
				row.band:SetColorTexture(c[1], c[2], c[3], 0.14)
			end
		end
	end
	-- THE TOOLTIP'S CLOCK TOO (Josh 2026-09-29: "Tooltip timer doesn't update
	-- in real time when it is open"): a quest's tooltip open over a timed
	-- quest is drawn again with the clock
	local tip = BT.Tip and BT.Tip.IsShown() and BT.Tip.Frame and BT.Tip.Frame()
	local owner = tip and tip.owner
	if owner and owner.quest and owner.quest.endsAt and not owner.quest.failed then
		M.QuestTip(owner, owner.quest)
		any = true
	end
	if not any and M.clockTicker then
		M.clockTicker:Cancel()
		M.clockTicker = nil
	end
	return any
end

-- THE CLOCK STOPS WITH THE LIST (Josh 2026-09-30, review). A row keeps its
-- own shown flag while the list is hidden around it, so a clock left on one
-- kept the ticker writing to a list nobody could see, once a second, for the
-- rest of the session: after the last quest went with "Hide when empty" on,
-- or with the tracker switched off. Drawing the list again starts it.
local function stopClocks()
	for _, row in ipairs(rows or {}) do
		row.endsAt = nil
	end
	if M.clockTicker then
		M.clockTicker:Cancel()
		M.clockTicker = nil
	end
end

function M.QuestTip(owner, q)
	if not (BT.Tip and q) then
		return
	end
	BT.Tip.Show(owner, { build = function(t)
		local objectives = q.objectives or {}
		local done = 0
		for _, o in ipairs(objectives) do
			if o.done then
				done = done + 1
			end
		end
		local sub = {}
		if q.zone then
			sub[#sub + 1] = q.zone
		end
		if q.level then
			sub[#sub + 1] = "Level " .. q.level
		end
		local pill, pillState
		if q.failed then
			pill, pillState = "Failed", "bad"
		elseif q.complete then
			pill, pillState = "Ready to turn in", "good"
		elseif #objectives > 0 then
			pill = ("%d of %d"):format(done, #objectives)
		end
		t:Header({ icon = false, name = q.title or "Quest", sub = #sub > 0 and table.concat(sub, " · ") or nil,
			pill = pill, pillState = pillState })
		if q.endsAt and not q.failed then
			t:Row("Time", M.TimeLeft(q.endsAt), (q.endsAt - ((type(GetTime) == "function" and GetTime()) or 0)) < 60 and "bad" or nil)
		end
		if #objectives > 0 then
			t:Section()
			for _, o in ipairs(objectives) do
				local need = tonumber(o.need)
				local have = tonumber(o.have)
				local count = need and need > 0 and have and ("%d / %d"):format(have, need) or (o.done and "done" or "")
				t:Row(o.text or "", count, o.done and "good" or nil,
					(need and need > 1 and not o.done) and { (have or 0) / need } or nil, o.done and "good" or nil)
			end
		end
		t:Foot({
			{ "Click", "open it in the quest log" },
			{ "Right-click", "fold its objectives" },
			{ "Shift-click", "stop tracking it" },
		})
	end })
end

function M.Update()
	if not frame then
		return 0
	end
	if not BT.Enabled("tracker") then
		stopClocks()
		frame:Hide()
		BT.Dock.Relayout()
		return 0
	end
	local here = hereZone()
	local quests = M.Sort(M.Filter(Q.Watched(), here), here)
	M.lastCount = #quests
	if #quests == 0 and opt("hideEmpty", true) then
		band(nil)
		stopClocks()
		frame:Hide()
		BT.Dock.Relayout()
		return 0
	end
	frame:Show()

	local tracked = Q.SuperTracked()
	-- folded by its chevron, or for the length of a fight when asked
	local shut = opt("collapsed", false)
		or (opt("combatFold", false) and InCombatLockdown and InCombatLockdown() and true or false)
	local i, y = 0, PAD
	i = i + 1
	y = setRow(i, y, "head", string.upper("Quests") .. "   " .. tint(MUTED, tostring(#quests)), nil, MUTED, nil)
	y = y + GAP

	local bandTop, bandFoot = nil, nil
	local zone = false
	for _, quest in ipairs(shut and {} or quests) do
		-- a heading where the zone changes (a quest filed under none has none)
		if opt("zones", true) and quest.zone ~= zone then
			zone = quest.zone
			if zone then
				i = i + 1
				y = setRow(i, y, "zone", zone:upper(), nil, MUTED, nil)
			end
		end
		i = i + 1
		local active = tracked ~= nil and quest.questID ~= nil and tracked == quest.questID
		local mark = "dot"
		if quest.failed then
			mark = "failed"
		elseif quest.complete then
			mark = "check"
		elseif active then
			mark = "tracking"
		end
		if active then
			bandTop = y
		end
		local level = ""
		if quest.level and quest.level > 0 then
			level = tint(levelColour(quest.level), ("[%d] "):format(quest.level))
		end
		-- HOW HARD IT IS, IN THE TITLE (Josh 2026-09-19). Every quest was the
		-- same off-white, so a grey quest five levels below you and one that
		-- will kill you read identically - and the client's own log has told
		-- people this in colour for twenty years. The level in front of the
		-- title already wore the difficulty colour; the title wears it too.
		--
		-- Complete no longer means gold: the tick at the start of the line
		-- says that, and spending the title's colour on it threw away the more
		-- useful fact. Failed still overrides everything.
		local titleColour = quest.failed and FAILED or levelColour(quest.level)
		y = setRow(i, y, "title", level .. quest.title, mark, titleColour, quest)
		-- its clock, first under the title while it runs (Q.Timers)
		-- DONE IS NOT DELIVERED (Josh 2026-09-29: "Time limit is still not
		-- showing" - Iverron's Antidote): a quest that asks you only to carry
		-- something reads as complete the moment it is taken, and its clock
		-- is still running until you hand it in. Only a failed one has none.
		if quest.endsAt and not quest.failed then
			i = i + 1
			local now = (type(GetTime) == "function" and GetTime()) or 0
			y = setRow(i, y, "clock", M.TimeLeft(quest.endsAt, now), nil, clockColour(quest.endsAt, now), quest)
			rows[i].endsAt = quest.endsAt
			if not M.clockTicker and C_Timer and C_Timer.NewTicker then
				M.clockTicker = C_Timer.NewTicker(1, M.TickClocks)
			end
		end
		-- a failed quest's objectives are no longer worth reading
		if not quest.failed and not folded(quest)
			and not (quest.complete and opt("hideDone", false)) then
			for _, o in ipairs(quest.objectives) do
				i = i + 1
				local count = ""
				if o.need and o.need > 1 then
					count = tint(o.done and DONE or MUTED, ("%d/%d "):format(o.have or 0, o.need))
				end
				y = setRow(i, y, "line", count .. (o.text or ""), o.done and "strike" or nil,
					o.done and DONE or DIM, quest)
			end
		end
		if active then
			bandFoot = y
		end
		y = y + GAP
	end

	for j = i + 1, #rows do
		rows[j]:Hide()
		rows[j].quest = nil
	end

	-- the whole list, however tall: the dock decides how much of it shows,
	-- and M.Fit is handed the answer
	local content = math.max(24, y + PAD - GAP)
	M.contentHeight, M.used = content, i
	-- the width the words were wrapped to (M.Fit)
	M.laidWidth = listWidth()
	M.listTop = PAD + ROW + GAP
	M.bandTop, M.bandFoot = bandTop, bandFoot
	frame.wantHeight = content
	frame.minHeight = math.min(content, M.listTop + MIN_LINES * ROW + PAD)
	frame:SetHeight(content)
	M.maxHeight = content
	BT.Dock.Relayout()
	return i
end

-- The height the dock gave the list: scroll what does not fit, keep the
-- QUESTS line where it is, and show where in the list you are.
function M.Fit(height)
	if not (frame and rows) then
		return
	end
	-- A NEW WIDTH WRAPS THE WORDS AGAIN: the dock's width changed, or it had
	-- not been laid out when the list was drawn. Update hands the dock the
	-- new heights, and the dock calls back here with the room for them.
	if M.laidWidth and listWidth() ~= M.laidWidth and frame:IsShown() then
		M.Update()
		return
	end
	local content = M.contentHeight or 0
	height = height or content
	M.maxHeight = height
	local over = math.max(0, content - height)
	-- clamped here rather than where the wheel turns: the list changes under
	-- you as quests are taken and handed in, and the room with the dock
	M.scroll = math.max(0, math.min(M.scroll, over))
	local listTop = M.listTop or 0
	for j = 1, math.min(M.used or 0, #rows) do
		local row = rows[j]
		if row.top then
			-- the header is never scrolled
			local at = row.isHeader and row.top or (row.top - M.scroll)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -at)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -at)
			-- a row is shown whole or not at all, so one that starts inside the
			-- list and ends past it is past it
			row:SetShown(row.isHeader or over <= 0 or (at >= listTop - 1 and at + (row.tall or ROW) <= height))
		end
	end
	-- THE BAND SCROLLS WITH THE ROWS (Josh 2026-09-22), and is cut to the
	-- part of the list that shows
	local bandTop, bandFoot = M.bandTop, M.bandFoot
	if bandTop and bandFoot then
		local top, foot = bandTop - M.scroll, bandFoot - M.scroll
		if over > 0 then
			top, foot = math.max(top, listTop), math.min(foot, height - 2)
		end
		if foot <= top then
			band(nil)
		else
			band(top, foot)
		end
	else
		band(nil)
	end
	-- THE WHEEL IS THE CAMERA'S WHEN THE LIST FITS (Josh 2026-09-30, review):
	-- a frame that takes the wheel keeps it even when it does nothing with
	-- it, so over a short list the camera would not zoom
	frame:EnableMouseWheel(over > 0)
	-- A THUMB, SO IT READS AS A LIST THAT GOES ON (Josh 2026-09-23). The
	-- wheel was the only sign there was more: a list cut off at a quest
	-- title looks like the whole list.
	local thumb = frame.thumb
	if thumb then
		if over > 0 then
			local track = math.max(1, height - listTop - PAD)
			local h = math.max(12, math.floor(track * height / content + 0.5))
			local at = listTop + (track - h) * (M.scroll / over)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -at)
			thumb:SetHeight(h)
			thumb:Show()
		else
			thumb:Hide()
		end
	end
	-- the item buttons over wherever their rows now are
	M.PlaceItems()
end

-- A section of the dock, not a panel of our own: the dock carries the skin,
-- the spine, where it sits and how big it is. All this owns is what is in it
-- and how tall that comes out.
function M.Build()
	if frame then
		return frame
	end
	rows = {}
	frame = BT.Dock.Section("tracker", 10)
	-- as wide as the dock, which has a width of its own (UI/Dock.lua): the
	-- list asking for 230 was what made the whole dock wider with it
	frame.wantWidth = nil
	-- the one section the dock may cut short to stay on the screen
	frame.shrinks = true
	frame.Fit = function(_, height)
		M.Fit(height)
	end
	frame.thumb = frame:CreateTexture(nil, "OVERLAY")
	frame.thumb:SetWidth(2)
	BT.Widgets.Lit(frame.thumb, 0.55)
	frame.thumb:Hide()

	-- THE WHEEL, AND ONLY WHEN THERE IS SOMEWHERE TO GO (Josh 2026-09-20).
	-- Three rows a notch, which is the same as the client's own lists, and
	-- nothing happens at all when the whole list already fits - a panel that
	-- scrolls when it does not need to feels broken. (Taken only while the
	-- list does not fit: M.Fit.)
	frame:EnableMouseWheel(false)
	frame:SetScript("OnMouseWheel", function(_, delta)
		local over = math.max(0, (M.contentHeight or 0) - (M.maxHeight or 0))
		if over <= 0 then
			return
		end
		local was = M.scroll
		M.scroll = math.max(0, math.min(over, M.scroll - delta * ROW * 3))
		-- the list moves inside the height it already has: nothing else in
		-- the dock changes, so the dock is not laid out again
		if M.scroll ~= was then
			M.Fit(M.maxHeight)
		end
	end)

	-- a texture on the section draws UNDER the rows, which are frames of their
	-- own: no layering to arrange and nothing for the clicks to catch on
	-- (painted where it is shown, not here: the colours are a setting)
	frame.band = frame:CreateTexture(nil, "BACKGROUND")
	frame.band:Hide()
	frame.bandTop = frame:CreateTexture(nil, "BORDER")
	frame.bandTop:SetHeight(1)
	frame.bandTop:Hide()
	frame.bandFoot = frame:CreateTexture(nil, "BORDER")
	frame.bandFoot:SetHeight(1)
	frame.bandFoot:Hide()
	return frame
end

-- THE QUEST YOU ARE ON WEARS THE THEME (Josh 2026-09-21). The block behind it,
-- its two rules and the dot beside it were all the toolkit's green, written
-- when that was the only colour there was. With the background and border a
-- setting, a green block in a violet panel is the one thing in the tracker
-- that did not get the message.
--
-- The block is the panel's OWN background lifted a few shades rather than a
-- colour of its own: that is what "this row is raised out of the list" looks
-- like, and it stays true whatever the background is set to - including a
-- background so light that a lighter one has to go darker to be seen.
--
-- TOWARD THE THEME, NOT TOWARD GREY (Josh 2026-09-22). Lifting all three
-- channels by the same amount made a near-black fill plain grey, whatever
-- colour the theme was. It is lifted toward the rim instead - the theme's own
-- colour - so on a Paladin's panel the block is a faint pink and on the house
-- preset a faint green: the same panel, a step up.
M.LIFT = 0.15

local function lifted(by)
	local f, r = BT.Widgets.FILL, BT.Widgets.RIM
	local amount = by or M.LIFT
	-- past about two-thirds there is no lighter left to go, so it steps the
	-- other way and the block still reads as a step out of the panel
	if (f[1] + f[2] + f[3]) / 3 > 0.65 then
		return { f[1] - 0.10, f[2] - 0.10, f[3] - 0.10 }
	end
	return {
		f[1] + (r[1] - f[1]) * amount,
		f[2] + (r[2] - f[2]) * amount,
		f[3] + (r[3] - f[3]) * amount,
	}
end
M.Lifted = lifted

-- Its colours, separately from its position: a theme change repaints it
-- whether or not there is a quest to draw it around at that moment.
function paintBand()
	if not (frame and frame.band) then
		return false
	end
	local lift, edge = lifted(), BT.Widgets.RIM
	frame.band:SetColorTexture(lift[1], lift[2], lift[3], 1)
	-- THE PANEL'S OWN RULE, ONE SCREEN PIXEL (Josh 2026-09-22). These were
	-- coloured by hand, so they missed the hairline treatment every other rule
	-- gets and the one under the quest came out two pixels at this scale.
	BT.Widgets.Rule(frame.bandTop, 0.9, "h")
	BT.Widgets.Rule(frame.bandFoot, 0.9, "h")
	return true
end

-- `top` and `bottom` are distances down from the top of the section, the same
-- numbers the rows are laid out with.
function band(top, bottom)
	if not frame.band then
		return
	end
	if not top then
		frame.band:Hide()
		frame.bandTop:Hide()
		frame.bandFoot:Hide()
		return
	end
	paintBand()
	-- on whole screen pixels, so neither rule straddles two
	local snap = (BT.Dock and BT.Dock.Snap) or function(v) return v end
	local t = snap(top - 2)
	local h = snap(bottom + 2) - t
	frame.band:ClearAllPoints()
	frame.band:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -t)
	frame.band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -t)
	frame.band:SetHeight(h)
	frame.bandTop:ClearAllPoints()
	frame.bandTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -t)
	frame.bandTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -t)
	frame.bandFoot:ClearAllPoints()
	frame.bandFoot:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(t + h))
	frame.bandFoot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -(t + h))
	frame.band:Show()
	frame.bandTop:Show()
	frame.bandFoot:Show()
end

-- The client tells us a quest changed in half a dozen ways and often three at
-- once; the tracker is rebuilt a moment later, once.
--
-- M.Queue, NOT M.Refresh (Josh 2026-09-23, audit): Refresh is the name the
-- window calls on an open tab to bring its page up to date, and here it
-- meant "rebuild the list" - so the tab's switches and its count were never
-- refreshed. The rebuild has its own name; M:Refresh does both.
local pending = false

function M.Queue()
	if not (C_Timer and C_Timer.After) then
		M.Update()
		return
	end
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.15, function()
		pending = false
		M.Update()
	end)
end

function M.Watch()
	if M.events then
		return
	end
	M.events = CreateFrame("Frame")
	-- (not the loading screen: OnBind draws the list on every one already -
	-- Josh 2026-09-30, review)
	for _, event in ipairs({
		"QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED",
		"QUEST_ACCEPTED", "QUEST_REMOVED",
		"ZONE_CHANGED_NEW_AREA",
	}) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	-- YOUR quest log, not everybody's (Josh 2026-09-19). UNIT_QUEST_LOG_CHANGED
	-- fires for every unit the client is tracking, so in a raid it arrives
	-- dozens of times for other people's quests - each one waking a rebuild of
	-- a panel that cannot have changed. Filtered to the player it fires when
	-- your own log does, and not otherwise.
	local filtered = M.events.RegisterUnitEvent
		and pcall(M.events.RegisterUnitEvent, M.events, "UNIT_QUEST_LOG_CHANGED", "player")
	if not filtered then
		pcall(M.events.RegisterEvent, M.events, "UNIT_QUEST_LOG_CHANGED")
	end
	-- the items: a cooldown that changed, and the end of a fight for a
	-- button that could not be given its item during one
	for _, event in ipairs({ "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
		pcall(M.events.RegisterEvent, M.events, event)
	end
	M.events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			settleClient()
		end
		if not BT.Enabled("tracker") then
			-- SWITCHED OFF IN A FIGHT (Josh 2026-09-30, review): an item button
			-- could only go see-through then, and is the screen's, so it still
			-- took clicks after the list had gone. Put away when the fight ends.
			if event == "PLAYER_REGEN_ENABLED" and M.itemsPending then
				M.itemsPending = false
				M.PlaceItems()
			end
			return
		end
		if event == "BAG_UPDATE_COOLDOWN" then
			M.UpdateCooldowns()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if M.itemsPending or opt("combatFold", false) then
				M.itemsPending = false
				M.Queue()
			end
		elseif event == "PLAYER_REGEN_DISABLED" then
			-- folded for the fight, if asked
			if opt("combatFold", false) then
				M.Queue()
			end
		else
			M.Queue()
		end
	end)
end

function M:OnEnable()
	M.Build()
	M.Watch()
	hideClient()
	M.Update()
end

function M:OnDisable()
	stopClocks()
	if frame then
		frame:Hide()
		BT.Dock.Relayout()
	end
	showClient()
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------
function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("Click a quest to open it. Right-click to fold it. Shift-click to stop tracking it.")

	self.rows = {}
	local quests = page:Section("Quests")
	local function row(title, blurb, name, default)
		local r = BT.Widgets.SwitchRow(quests, title, blurb,
			function() return opt(name, default) and true or false end,
			function(on) setOpt(name, on) end)
		r.optName, r.default = name, default
		self.rows[#self.rows + 1] = r
	end
	row("By level", "Lowest level first in each zone, instead of the quest log's order", "byLevel", true)
	row("Zone headings", "Each zone's name over its quests, instead of one list", "zones", true)
	row("Only this zone", "Only the quests of the zone you are in", "hereOnly", false)
	row("Fold in combat", "The list folds while you fight and unfolds after", "combatFold", false)
	row("Hide when empty", "Hides the panel when you track no quests", "hideEmpty", true)
	row("Fold finished quests", "Hides their objectives", "hideDone", false)
	-- "Fold the list" used to be a row here. Folding the list is something you
	-- do to the panel in front of you and undo a second later - it is state,
	-- not a preference, and the chevron on the QUESTS header already is the
	-- control for it (Josh 2026-09-19).

	-- (the dock's size was here, the whole panel's, on the quests' page: it is
	-- on the Dock's own page now - Josh 2026-09-24)
	page:Layout()

	self.found = BT.Widgets.Label(panel, "", "small", 0.45, 0.50, 0.48)
	self.found:SetPoint("BOTTOMLEFT", 2, 4)
end

function M:RefreshTab()
	for _, r in ipairs(self.rows or {}) do
		r.switch:SetOn(opt(r.optName, r.default) and true or false)
	end
	if self.found then
		self.found:SetText(("%d tracked · game's tracker %s")
			:format(M.lastCount or 0, M.ClientFrame() and "hidden" or "not found"))
	end
end

function M:ShowTab()
	M.Update()
	self:RefreshTab()
end

function M:Refresh()
	self:RefreshTab()
	M.Queue()
end

-- the tests reach in here rather than at the frames
function M.Frame() return frame end

-- THE COLOURS ARE SET WHERE IT LAYS OUT (Josh 2026-09-21). The block behind
-- the quest you are on, its rules and its dot are painted as the list is
-- drawn, which happens on quest events - so changing the theme left them in
-- the old colours until you picked up or handed in a quest. Laying out again
-- is the repaint.
function M.Restyle()
	paintBand()
	return M.Update()
end
-- the tests want the band without going through a quest log
M.Band = function(...) return band(...) end
function M.Rows() return rows or {} end
