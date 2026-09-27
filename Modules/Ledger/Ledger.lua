-- The Ledger module: what you think of the people you meet (Josh 2026-09-19).
--
-- It owns the Find tab, the tooltip decoration, and the part of the floating
-- bar that is about whoever you are pointing at: their name, a dot per tag,
-- and your note. What you write is kept in the Ledger's own book
-- (Modules/Ledger/Store.lua), not on the census's rows: the Ledger works
-- with no census at all, and uses one to find people when there is one.
--
-- THE TAG SWEEP RUNS HERE AND NOWHERE ELSE. Migrating tags walks every
-- character and removes marks whose meaning no longer exists, which is the
-- most destructive thing this addon does on an ordinary login. A toolkit with
-- the Ledger switched off must never tidy away judgements it is not currently
-- showing you, so it hangs off this module's OnBind.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Ledger.lua")

local U, N = BT.Util, BT.Notes

local M = BT.Module({
	key = "ledger",
	feature = "ledger",
	title = "Ledger",
	blurb = "notes and tags",
	order = 10,
	-- on the right panel, so it has a tab on the rail (Josh 2026-09-22)
	dock = true,
})

-- NOTES ON TOOLTIPS LIVE HERE (Josh 2026-09-23). The switch was on the
-- toolkit's own page, which made it a setting of everything; the notes are
-- the Ledger's, so it sits above the Ledger's list. The setting itself is
-- still BT.settings.tooltip, where Modules/Ledger/Tooltip.lua reads it.
function M:BuildTab(parent)
	local stack = BT.Widgets.Stack(parent)
	local tips = stack:Section("Tooltips")
	self.notesRow = BT.Widgets.SwitchRow(tips, "Notes on tooltips", "your note above the tooltip · tags and rating under it",
		function() return BT.settings and BT.settings.tooltip ~= false end,
		function(on)
			BT.EnsureBound()
			BT.settings.tooltip = on and true or false
		end)
	self.notesRow.field = "tooltip"
	-- THE TARGET ROW (Josh 2026-09-24): who you are pointing at, their tags and
	-- your note, at the top of the dock - the Ledger's, so its switch is here
	local dock = stack:Section("In the dock")
	self.rowRow = BT.Widgets.SwitchRow(dock, "Target row", "who you are pointing at, their tags and your note",
		function() return BT.settings and BT.settings.bar ~= false end,
		function(on)
			BT.EnsureBound()
			BT.settings.bar = on and true or false
			if BT.Bar then
				BT.Bar.SetShown(on)
			end
		end)
	self.rowRow.field = "bar"
	local find = CreateFrame("Frame", nil, parent)
	find:SetPoint("TOPLEFT", 0, -(stack:Layout() + 8))
	find:SetPoint("BOTTOMRIGHT", 0, 0)
	BT.Find.Build(find)
end

function M:ShowTab()
	BT.Find.Refresh()
end

function M:Refresh()
	BT.Find.Refresh()
end

function M:OnBind()
	-- once: what you wrote on the census's rows, into the Ledger's own book
	N.Move()
	BT.MigrateTags()
end

function M:OnDisable()
	BT.Bar.SetMark(nil) -- the toolkit's own glyph back in the first slot
	BT.Find.CloseEditor()
	if BT.Tooltip and BT.Tooltip.HidePills then
		BT.Tooltip.HidePills()
	end
end

-- ---------------------------------------------------------------------------
-- What the Ledger puts on the floating bar
--
--   [ who you are pointing at ] [ ••• ] [ note ] [ find ]
--
-- The dots and the note are the only things on the whole bar that carry a
-- tooltip, and each shows CONTENT rather than instructions - the hover panel
-- this replaced explained the addon to somebody who already had it installed.
-- ---------------------------------------------------------------------------
local DOT, DOT_GAP, MAX_DOTS = 7, 3, 5
-- the unit tooltip's own quotation sizes, because it is the same quotation
local NOTE_SIZE, CREDIT_SIZE = 15, 10
local MARK_X = 4 -- the second line starts under the class icon, not inset again
-- with nobody targeted: a reticle in the first slot, and what targeting is for
local RETICLE = "Interface\\AddOns\\BeebMod\\Art\\net"
local RETICLE_COORDS = { 0.5, 0.75, 0, 1 }
local QUIET = { 0.54, 0.60, 0.58, 1 }
local EMPTY = "|cff7d8a84target a player to add notes and tags|r"
-- what the hint claims of the row: a name's worth, never the whole sentence
local HINT_W = 90

-- your target: its key, its name, and what the unit says about it
local function currentTarget()
	return N.Target()
end

local function tagsOn(p)
	local out = {}
	for _, f in ipairs(BT.AllFlags()) do
		if p and p.flags and p.flags[f.key] then
			out[#out + 1] = f
		end
	end
	return out
end

function M:Cells()
	local PAD = BT.Bar.PAD

	-- who you are pointing at; clicking writes on them
	local who = BT.Bar.Cell("who", 120)
	who.button = CreateFrame("Button", nil, who)
	who.button:SetAllPoints()
	who.button:RegisterForClicks("AnyUp")
	who.text = who:CreateFontString(nil, "OVERLAY", "BeebModFontHighlight")
	who.text:SetPoint("LEFT", PAD, 0)
	who.text:SetJustifyH("LEFT")
	who.text:SetWordWrap(false)
	-- A PENCIL, ON HOVER (Josh 2026-09-19). The whole name used to be the
	-- button, so pointing at somebody and clicking to read their tags opened a
	-- panel you had not asked for. Now the name is just their name; hovering it
	-- offers a pencil, and the pencil is the only thing that writes.
	who.pencil = CreateFrame("Button", nil, who)
	who.pencil:SetSize(16, 16)
	who.pencil:SetPoint("RIGHT", -1, 0)
	who.pencil:RegisterForClicks("AnyUp")
	-- ABOVE THE NAME'S OWN BUTTON (Josh 2026-09-19). The button that offers the
	-- pencil covers the whole cell, and the pencil sits inside it: two siblings
	-- at the same frame level, and the one underneath was taking the click. The
	-- pencil is the only thing here that does anything, so it goes on top.
	who.pencil:SetFrameLevel(BT.Pill.Number(who.button.GetFrameLevel
		and who.button:GetFrameLevel(), 5) + 2)
	who.pencil.icon = who.pencil:CreateTexture(nil, "ARTWORK")
	who.pencil.icon:SetAllPoints()
	who.pencil.icon:SetTexture("Interface\\AddOns\\BeebMod\\Art\\icons")
	BT.Bar.PencilCoord(who.pencil.icon)
	who.pencil.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
	who.pencil:Hide()

	-- moving from the name onto the pencil leaves the name, so neither frame
	-- can decide on its own that you have gone: they ask together, a moment
	-- later
	local function overEither()
		return (who.IsMouseOver and who:IsMouseOver())
			or (who.pencil.IsMouseOver and who.pencil:IsMouseOver())
	end
	local function maybeHide()
		if C_Timer and C_Timer.After then
			C_Timer.After(0.08, function()
				if not overEither() then
					who.pencil:Hide()
				end
			end)
		else
			who.pencil:Hide()
		end
	end
	local function offer()
		if who.key then
			who.pencil:Show()
		end
	end
	who.button:SetScript("OnEnter", offer)
	who.button:SetScript("OnLeave", maybeHide)
	-- no tooltip: a pencil on a name says what it does (Josh 2026-09-19)
	who.pencil:SetScript("OnEnter", function(self)
		BT.Widgets.Tint(self.icon)
		offer()
	end)
	who.pencil:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(0.55, 0.63, 0.59, 1)
		if GameTooltip then
			GameTooltip:Hide()
		end
		maybeHide()
	end)
	who.pencil:SetScript("OnClick", function()
		if not who.key then
			return -- nobody targeted: there is nothing to write on
		end
		BT.Find.EnsureBuilt()
		-- what the unit says, for a row the note is the first thing on
		BT.Find.OpenEditorFor(who.key, who, who.info)
	end)
	who.Offer = offer

	-- the tags hang at the right-hand end, beside the cog: they are marks about
	-- the person on this line, so they belong on this line
	local dots = BT.Bar.Cell("dots", 0)
	dots.side = "right"
	dots.list = {}
	-- the note's own mark, at the head of the row of tags
	dots.note = dots:CreateTexture(nil, "ARTWORK")
	dots.note:SetSize(DOT + 3, DOT + 3)
	dots.note:SetTexture(BT.Bar.ICONS)
	BT.Bar.NoteCoord(dots.note)
	dots.note:SetVertexColor(0.90, 0.88, 0.80, 1)
	dots.note:Hide()
	for i = 1, MAX_DOTS do
		local d = dots:CreateTexture(nil, "ARTWORK")
		d:SetSize(DOT, DOT)
		d:Hide()
		dots.list[i] = d
	end
	dots:EnableMouse(true)
	dots:SetScript("OnEnter", function(self)
		if not ((self.tags and #self.tags > 0) or self.note.text) then
			return
		end
		-- No name on it: you are pointing at the dots, on the line under the
		-- name, about the person whose name is right there. One size for every
		-- line, and the colour as a square rather than as the text - a tag
		-- colour chosen for a pill is a poor colour for words (Josh
		-- 2026-09-19).
		local colours = {}
		for i, f in ipairs(self.tags) do
			colours[i] = f.color or { 0.6, 0.65, 0.62 }
		end
		-- THE SAME QUOTATION IT IS EVERYWHERE ELSE (Josh 2026-09-20). This
		-- tooltip wrote the note as one more tooltip line, small and grey with
		-- the tags, while the unit tooltip set it large, warm and centred with
		-- its source under it. The same words in two voices read as two
		-- different things; the note is the note wherever you meet it.
		BT.Bar.Tip(self, function()
			if self.note.text then
				GameTooltip:AddLine(('"%s"'):format(self.note.text), 0.94, 0.92, 0.84, true)
				if self.note.credit then
					-- the right-hand column of a double line, because telling
					-- a tooltip line to align right does nothing at all
					GameTooltip:AddDoubleLine(" ", self.note.credit,
						1, 1, 1, 0.62, 0.66, 0.64)
				end
			end
			for _, f in ipairs(self.tags) do
				GameTooltip:AddLine("    " .. f.label, 0.87, 0.92, 0.89)
			end
		end)
		local first = 1
		if self.note.text then
			-- the quote in the text face, as it is on a unit's tooltip: the
			-- first line is otherwise taken for a name
			BT.UnitTip.SizeLine(GameTooltip, 1, NOTE_SIZE, nil, "text")
			BT.UnitTip.Center(GameTooltip, 1)
			first = 2
			if self.note.credit then
				BT.UnitTip.SizeLine(GameTooltip, 2, CREDIT_SIZE)
				BT.UnitTip.SizeLine(GameTooltip, 2, CREDIT_SIZE, "TextRight")
				first = 3
			end
		end
		for i = first, first + #self.tags - 1 do
			BT.UnitTip.SizeLine(GameTooltip, i, 11)
		end
		BT.UnitTip.Swatches(GameTooltip, colours, first)
		GameTooltip:Show()
	end)
	dots:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	-- A MARK MEANING THERE IS ONE, AFTER ALL (Josh 2026-09-20). The words went
	-- on the second line of the dock for a while, and a second line is a third
	-- of the panel's height spent on a sentence you wrote and already know.
	-- The icon says there is something to read and the tooltip reads it, which
	-- is the right trade at this size - the note is still the first thing on
	-- the unit tooltip, where you are looking at the person rather than at the
	-- panel.

	who.Update = function(self)
		local key, name, info = currentTarget()
		self.key, who.key, who.info = key, key, info
		-- someone you wrote on, seen again: their face brought up to date
		local p = key and N.Seen(key, info)
		-- NOBODY TARGETED SAYS WHAT TO DO (Josh 2026-09-22). "target a player"
		-- beside the toolkit's page glyph read as a label on a document; the
		-- slot shows a reticle now - the thing to do - and the words say why,
		-- a size down so the sentence fits the row a name will.
		-- THE HINT TAKES THE ROOM THERE IS (Josh 2026-09-22). Measured like a
		-- name, the sentence was the widest thing in the dock and pushed the
		-- whole panel out. It claims a name's worth of the row, reaches to the
		-- row's right edge, and is cut short there if the panel is narrower.
		self.text:ClearAllPoints()
		self.text:SetPoint("LEFT", PAD, 0)
		if key then
			self.text:SetFontObject(BeebModFontHighlight)
			self.text:SetText(U.Colorize(name, (info and info.class) or (p and p.class)))
		else
			self.text:SetFontObject(BeebModFontHighlightSmall)
			self.text:SetText(EMPTY)
			local row = BT.Bar.Row and BT.Bar.Row()
			if row then
				self.text:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
			end
		end
		-- the first slot becomes their class while you are pointing at them
		-- the unit's own class: a stranger has no row to read it from
		local class = (info and info.class) or (p and p.class)
		if class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
			BT.Bar.SetMark("Interface\\TargetingFrame\\UI-Classes-Circles", CLASS_ICON_TCOORDS[class])
		elseif key then
			BT.Bar.SetMark(nil)
		else
			BT.Bar.SetMark(RETICLE, RETICLE_COORDS, QUIET)
		end
		local measured = key and self.text.GetStringWidth and self.text:GetStringWidth() or HINT_W
		-- room for the pencil at the end, whether or not it is showing: the
		-- row must not jump when you point at it
		BT.Bar.SetCellWidth(self, BT.Pill.Number(measured, 90) + PAD * 2 + 16)
		self.wanted = true
		if not key then
			who.pencil:Hide()
		end

		local tags = tagsOn(p)
		dots.tags = tags
		for i, dot in ipairs(dots.list) do
			local f = tags[i]
			if f and i <= MAX_DOTS then
				local c = f.color or { 0.6, 0.65, 0.62 }
				dot:SetColorTexture(c[1], c[2], c[3], 1)
				dot:ClearAllPoints()
				dot:SetPoint("LEFT", dots, "LEFT", MARK_X + (i - 1) * (DOT + DOT_GAP), 0)
				dot:Show()
			else
				dot:Hide()
			end
		end
		local shown = math.min(#tags, MAX_DOTS)
		dots.note.text = p and p.note or nil
		dots.note.credit = dots.note.text and U.Credit(p) or nil
		dots.note:SetShown(dots.note.text ~= nil)
		local x = MARK_X
		if dots.note.text then
			dots.note:ClearAllPoints()
			dots.note:SetPoint("LEFT", dots, "LEFT", x, 0)
			x = x + DOT + 3 + DOT_GAP
			-- the tags step aside for it rather than sitting under it
			for i = 1, shown do
				dots.list[i]:ClearAllPoints()
				dots.list[i]:SetPoint("LEFT", dots, "LEFT",
					x + (i - 1) * (DOT + DOT_GAP), 0)
			end
			x = x + shown * DOT + math.max(0, shown - 1) * DOT_GAP
		else
			x = x + shown * DOT + math.max(0, shown - 1) * DOT_GAP
		end
		dots.wanted = shown > 0 or dots.note.text ~= nil
		BT.Bar.SetCellWidth(dots, x + 6)
	end
	dots.Update = function() end

	-- no way-in icon of its own: the cog goes to the settings and the window
	-- has a tab for everything else
	return { who, dots }
end

-- ---------------------------------------------------------------------------
-- What the Ledger adds to /bt. Each one is refused with a line saying so when
-- the module is off, rather than quietly doing nothing.
-- ---------------------------------------------------------------------------
BT.Command("find", function(rest)
	BT.Find.Search(rest ~= "" and rest or nil)
end, "find <text> - names, guilds, notes", "ledger")

-- NOTHING TYPED IS A QUESTION, NOT AN ERASER (Josh 2026-09-23, audit). "/bt
-- note" on your target, or "/bt note Beeb Bob", cleared the note you had
-- written; typing the command to read a note deleted it. Now it reads it
-- back, and clearing takes the word.
BT.Command("note", function(rest)
	local key, text, name, info = N.WhoAndRest(rest)
	if not key then
		U.Print("no such character, and no player targeted")
		return
	end
	text = (text or ""):match("^%s*(.-)%s*$")
	if text == "" then
		local p = N.Get(key)
		U.Print(p and p.note and p.note ~= "" and ("note on %s · \"%s\""):format(name, p.note)
			or ("no note on %s · /bt note %s <text> writes one"):format(name, name))
		return
	end
	if text:lower() == "clear" then
		N.SetNote(key, "", info)
		U.Print("note cleared on " .. name)
	elseif N.SetNote(key, text, info) then
		U.Print(("note on %s · \"%s\""):format(name, text))
	else
		U.Print(("could not write on %s · target them first"):format(name))
	end
	BT.Find.Refresh()
end, "note [name] <text|clear> - name defaults to your target; no text reads it back", "ledger")

BT.Command("flag", function(rest)
	local key, flag, name, info = N.WhoAndRest(rest)
	-- WhoAndRest returns nothing at all when nobody matches and nothing is
	-- targeted, and indexing that nil was a Lua error where the usage
	-- line should have been
	-- BY WHAT YOU SEE (Josh 2026-09-23, audit): a tag of yours is "tag3"
	-- inside and "Tank" on the screen, and only the inside name was taken.
	-- The label is tried first, whole and in any case, then the key.
	local said = (flag or ""):match("^%s*(.-)%s*$")
	local tag
	for _, f in ipairs(BT.AllFlags()) do
		if f.label:lower() == said:lower() or f.key == said then
			tag = f
		end
	end
	if not key or not tag then
		local labels = {}
		for _, f in ipairs(BT.AllFlags()) do
			labels[#labels + 1] = f.label
		end
		U.Print("usage: /bt flag [name] <" .. table.concat(labels, " | ") .. ">")
		return
	end
	local p, on = N.ToggleFlag(key, tag.key, info)
	if not p and on then
		U.Print(("could not tag %s · target them first"):format(name))
		return
	end
	U.Print(("%s %s on %s"):format(on and "set" or "cleared", tag.label, name))
	BT.Find.Refresh()
end, "flag [name] <tag> - toggle a tag, by its name", "ledger")

BT.Command("tag", function(rest)
	local sub, arg = rest:match("^(%S*)%s*(.-)$")
	if sub == "new" or sub == "add" then
		local tag, why = BT.AddTag(arg)
		U.Print(tag and ("new tag: " .. tag.label) or (why or "could not make that tag"))
	elseif sub == "delete" or sub == "remove" then
		if arg == "" then
			U.Print("usage: /bt tag delete <name>")
			return
		end
		local ok, gone = BT.RemoveTag(arg)
		U.Print(ok and ("deleted " .. gone.label .. " · off every character")
			or ("no tag of yours called " .. arg))
	else
		local built, mine = {}, {}
		for _, f in ipairs(BT.AllFlags()) do
			local into = f.builtin and built or mine
			into[#into + 1] = f.icon .. " " .. f.label
		end
		U.Print("built in: " .. table.concat(built, ", "))
		U.Print("yours: " .. (#mine > 0 and table.concat(mine, ", ") or "none · /bt tag new <name>"))
	end
	if BT.Find.RebuildFlags then
		BT.Find.RebuildFlags()
		BT.Find.Refresh()
	end
end, "tag - list them | tag new <name> | tag delete <name>", "ledger")

BT.Command("rate", function(rest)
	local key, n, name, info = N.WhoAndRest(rest)
	if not key then
		U.Print("no such character, and no player targeted")
		return
	end
	-- as with a note: nothing reads the rating back, "clear" clears it, and a
	-- number that is not 1 to 5 changes nothing (it used to clear it)
	n = (n or ""):match("^%s*(.-)%s*$")
	local current = N.Get(key)
	if n == "" then
		local r = current and current.rating
		U.Print(r and ("%s is rated %d/5"):format(name, r) or ("%s is not rated"):format(name))
		return
	end
	local want = tonumber(n)
	if n:lower() == "clear" then
		N.SetRating(key, nil, info)
		U.Print("rating cleared on " .. name)
		return
	end
	if not want or want < 1 or want > 5 then
		U.Print("usage: /bt rate [name] <1-5|clear>")
		return
	end
	local p = N.SetRating(key, math.floor(want), info)
	local rating = p and p.rating
	U.Print(rating and ("rated %s %d/5"):format(name, rating) or ("could not rate " .. name))
end, "rate [name] <1-5|clear> - no number reads it back", "ledger")
