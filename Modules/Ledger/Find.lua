-- The Ledger's tab: find a character, and say what you think of them
-- (Josh 2026-09-19). Lifted out of the old standalone window when the toolkit
-- split, with the window chrome left behind - the toolkit owns the frame, the
-- title and the tabs now, and this owns what goes in one panel.
--
-- SEARCH, NOT A LIST. Nobody scrolls two thousand names looking for one. You
-- type, and you get the handful that match, with what you wrote on them.
--
-- THE SELECTED CARD IS THE EDITOR. Every row used to carry a "Note and tags"
-- button that opened a panel over the window - a button on every line to reach
-- a thing that could simply be the line. Click a row and it opens: every tag,
-- lit or dim, each one a switch, and the note as a field you can type in.
-- Click another row and this one closes again.
--
-- The separate panel is still here for one job the tab cannot do: writing on
-- whoever you are pointing at straight from the floating bar, with no window
-- open. It is also where tags are made and deleted.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Find.lua")

local U, N = BT.Util, BT.Notes

-- THE LEDGER'S OWN BOOK, AND THE CENSUS'S WHEN THERE IS ONE (Josh
-- 2026-09-26). What you wrote is on the Ledger's rows (Modules/Ledger/
-- Store.lua); anyone else is found in the census's book, if a census is here.
local function census()
	return BT.DB and BT.db and BT.DB or nil
end

-- a person's face to show: yours, else the census's, else what the unit
-- in front of you said when the panel was opened on them
local function face(key, info)
	if not key then
		return nil
	end
	local p = N.Get(key)
	if p then
		return p
	end
	local C = census()
	return (C and C.Get(BT.db, key)) or info
end

-- the census's changes: a number that only rises
local function bookRev()
	local C = census()
	return C and C.rev or 0
end
local B = {}
BT.Find = B

-- SEARCH, NOT A LIST (Josh 2026-09-19). The window used to open on a
-- scrollable list of every character on the realm - three hundred rows of
-- strangers, which nobody reads and which made the book feel like a
-- spreadsheet. What you actually arrive with is a question about one person,
-- so the window answers questions: a box, and a handful of cards.
-- A card has four things to say and needs room for each: who they are, what
-- the realm told us, your tags, and your note. Five roomy cards beat six
-- cramped ones - the sixth was never the one you were looking for anyway
-- (Josh 2026-09-19).
-- A CARD IS AS TALL AS WHAT IT HOLDS (Josh 2026-09-19). Every card used to be
-- the same height whether or not it had anything in it, and every one carried
-- a line of small print - class, level, guild, how many times you had seen
-- them, where. The class is already the colour of their name, and nobody came
-- here to find out they walked past somebody six times. What is left is the
-- name, what you tagged them, and what you wrote.
-- (the selected card is the editor: see the top of the file)
local CARDS, CARD_GAP = 5, 6
-- plain: a name. rich: a name and one row of tags or a note. credit: and
-- the line saying who wrote that note, and when.
local CARD_PLAIN, CARD_RICH, CARD_CREDIT = 32, 54, 68
local TAG_ROW_H = 20
-- CARDS_TOP is measured inside the find view, which itself starts VIEW_TOP
-- below the window's top edge. Mixing the two frames of reference is what put
-- the first card on top of the filter buttons (Josh 2026-09-19).
local VIEW_TOP, CARDS_TOP, WINDOW_MIN = 62, 84, 190
local panel, cards, searchBox, results, selected = nil, {}, nil, {}, nil
local findView, editor, emptyLine, moreLine
-- the "only:" filter row, rebuilt with the tags; defined after refreshFind
local buildFilters
-- the row wraps at the panel's content width, which is 584 (see the cards)
local FILTER_W = 584
-- what the panel is filtering by; it used to hang off the window frame, and
-- the window belongs to the toolkit now
local state = { mineOnly = false, tagFilter = nil }
-- declared here because the panel's open and close paths use them before the
-- file gets round to defining them
local editorTop, fitWindow, shownCards, cardsHeight = nil, nil, 0, 0
-- what the tick last drew: the Ledger's rev, the census's, and when the
-- census's was last drawn (B.Tick)
local seenNotes, seenBook, bookAt = -1, -1, nil
-- the noteRev the unit tooltip was last redrawn at
local restackedAt = -1

-- a note save, timed step by step (B.Timed, further down)
local function clock()
	return (type(debugprofilestop) == "function" and debugprofilestop()) or os.clock() * 1000
end
B.saves = {}
local timing

-- `fn`, timed as step `name` of the save being measured, if one is
local function step(name, fn, ...)
	if not timing then
		return fn(...)
	end
	local t0 = clock()
	local a, b = fn(...)
	timing.steps[#timing.steps + 1] = { name, clock() - t0 }
	return a, b
end

local function paint(f, r, g, b, a)
	local t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

local function label(parent, text, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", size == "small" and "BeebModFontHighlightSmall" or "BeebModFontNormal")
	fs:SetText(text or "")
	if r then fs:SetTextColor(r, g, b) end
	return fs
end

-- The editor: everything you can write on one character, in one small panel
-- that opens over the window and closes when you are done.
-- THE PANEL, AS ROWS (Josh 2026-09-19). It was a grid of round pills and a
-- "+ New tag" pill under them, which is a lot of shape for "tick the ones that
-- apply". Rebuilt as the quest tracker is built: a line per tag, a square of
-- its own colour at the start, lit when the character carries it and dim when
-- they do not. Two columns, because tags are short and the panel should not be
-- taller than what it is about.
--
--   Beeb Magus                          x
--   -------------------------------------
--   # Good            # Bad
--   # Troll           # Friendly
--   + new tag
--   -------------------------------------
--   the best lol
--
-- Right-click a tag of your own to delete it, and it says how many characters
-- carry it before it goes.
local E_W, E_ROW, E_PAD, E_SWATCH = 240, 16, 8, 7
local editorRefreshes = 0

local function editorLine(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", "BeebModFontHighlightSmall")
	if BeebModFontHighlightSmall and BeebModFontHighlightSmall.GetFont then
		local face, _, flags = BeebModFontHighlightSmall:GetFont()
		if face then
			pcall(fs.SetFont, fs, face, size, flags)
		end
	end
	fs:SetTextColor(r or 0.6, g or 0.66, b or 0.63)
	fs:SetJustifyH("LEFT")
	return fs
end

local function buildEditor(parent, anchor, label, paint)
	local e = CreateFrame("Frame", nil, parent)
	e:SetSize(E_W, 120)
	e:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
	e:SetFrameStrata("DIALOG")
	e:EnableMouse(true) -- clicks land here, not on whatever is underneath
	BT.Widgets.Panel(e)
	-- the same spine as the dock and the tooltips
	e.spine = e:CreateTexture(nil, "ARTWORK")
	e.spine:SetPoint("TOPLEFT", 1, -1)
	e.spine:SetPoint("BOTTOMLEFT", 1, 1)
	e.spine:SetWidth(3)
	BT.Widgets.Lit(e.spine, 0.9)

	e.title = editorLine(e, 12, 0.87, 0.92, 0.89)
	e.title:SetPoint("TOPLEFT", E_PAD + 4, -E_PAD)

	e.close = BT.Widgets.Close(e, 16)
	e.close:SetPoint("TOPRIGHT", -5, -5)
	e.close:SetScript("OnClick", function() B.CloseEditor() end)

	e.rule = e:CreateTexture(nil, "ARTWORK")
	e.rule:SetHeight(1)
	BT.Widgets.Rule(e.rule)
	e.rule:SetPoint("TOPLEFT", E_PAD, -(E_PAD + 16))
	e.rule:SetPoint("TOPRIGHT", -E_PAD, -(E_PAD + 16))

	e.tagBtns, e.pool = {}, {}

	-- the new-tag row, and the maker it turns into
	e.newTag = CreateFrame("Button", nil, e)
	e.newTag:SetHeight(E_ROW)
	e.newTag.text = editorLine(e.newTag, 10, 0.42, 0.48, 0.45)
	e.newTag.text:SetPoint("LEFT", 0, 0)
	e.newTag.text:SetText("+  Tag")
	e.newTag:SetScript("OnEnter", function(self)
		local c = BT.Widgets.ACCENT
		self.text:SetTextColor(c[1], c[2], c[3])
	end)
	e.newTag:SetScript("OnLeave", function(self) self.text:SetTextColor(0.42, 0.48, 0.45) end)
	e.newTag:SetScript("OnClick", function() B.ShowTagMaker(true) end)

	e.maker = CreateFrame("Frame", nil, e)
	e.maker:SetHeight(E_ROW + 14)
	e.maker:Hide()
	e.maker.box = CreateFrame("EditBox", nil, e.maker, "InputBoxTemplate")
	e.maker.box:SetHeight(18)
	e.maker.box:SetAutoFocus(false)
	e.maker.box:SetPoint("TOPLEFT", 4, 0)
	e.maker.box:SetPoint("TOPRIGHT", -4, 0)
	e.maker.swatches = {}
	for i, choice in ipairs(BT.TAG_COLORS) do
		local sw = CreateFrame("Button", nil, e.maker)
		sw:SetSize(12, 12)
		sw:SetPoint("TOPLEFT", (i - 1) * 15, -20)
		sw.fill = sw:CreateTexture(nil, "BACKGROUND")
		sw.fill:SetAllPoints()
		sw.fill:SetColorTexture(choice.color[1], choice.color[2], choice.color[3], 0.85)
		sw.edge = sw:CreateTexture(nil, "OVERLAY")
		sw.edge:SetAllPoints()
		sw.edge:SetColorTexture(1, 1, 1, 0)
		sw:SetScript("OnClick", function()
			e.maker.colour = i
			for j, other in ipairs(e.maker.swatches) do
				other.edge:SetColorTexture(1, 1, 1, j == i and 0.5 or 0)
			end
		end)
		e.maker.swatches[i] = sw
	end
	e.maker.box:SetScript("OnEnterPressed", function(self)
		local tag, why = BT.AddTag(self:GetText(), e.maker.colour)
		if not tag then
			U.Print("Ledger: " .. (why or "couldn't make that tag."))
		end
		self:SetText("")
		self:ClearFocus()
		B.ShowTagMaker(false)
		B.RebuildTags()
		B.Refresh()
	end)
	e.maker.box:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		B.ShowTagMaker(false)
	end)

	-- A FIELD THAT LOOKS LIKE A FIELD (Josh 2026-09-19). It was an underline
	-- with the words above it and "enter saves" beside them, which reads as a
	-- caption rather than something you can type in - and the hint was needed
	-- precisely because nothing else said "this is a box". A sunken panel says
	-- it without a word, and clicking anywhere else saves anyway.
	e.field = CreateFrame("Frame", nil, e)
	e.field:SetHeight(22)
	e.field:EnableMouse(true)
	e.fieldFill, e.fieldRim = BT.Pill.Panel(e.field,
		{ 0.02, 0.03, 0.03, 0.55 }, { 0.20, 0.26, 0.24, 0.95 })
	e.field:SetScript("OnMouseDown", function() e.note:SetFocus() end)
	e.note = CreateFrame("EditBox", nil, e)
	e.note:SetHeight(18)
	e.note:SetAutoFocus(false)
	e.note:SetTextInsets(2, 2, 0, 0)
	if BeebModFontHighlightSmall and BeebModFontHighlightSmall.GetFont then
		local face, _, flags = BeebModFontHighlightSmall:GetFont()
		if face then
			pcall(e.note.SetFont, e.note, face, 11, flags)
		end
	end
	e.note:SetTextColor(0.90, 0.88, 0.80)
	e.note:SetScript("OnEnterPressed", function(self)
		B.Timed("Enter in the note panel", function()
			B.SaveNote()
			step("let go", self.ClearFocus, self)
			B.Refresh()
		end)
	end)
	e.note:SetScript("OnEscapePressed", function(self)
		B.Timed("Escape in the note panel", function()
			B.SaveNote()
			step("let go", self.ClearFocus, self)
			step("close", B.CloseEditor)
		end)
	end)
	-- what the field is for, in the field, until there is something in it
	e.ghost = editorLine(e, 11, 0.38, 0.43, 0.41)
	e.ghost:SetText("Write a note")
	-- HOW MUCH ROOM IS LEFT (Josh 2026-09-29: a note has a limit now,
	-- N.MAX_NOTE): the count at the field's right end, once 30 or fewer
	-- characters are left, and the text kept clear of it
	e.left = editorLine(e, 10, 0.50, 0.56, 0.53)
	e.left:SetPoint("RIGHT", e.field, "RIGHT", -6, 0)
	e.left:SetJustifyH("RIGHT")
	e.left:Hide()
	local function ghost()
		local text = e.note:GetText()
		e.ghost:SetShown((text == nil or text == "") and not e.note:HasFocus())
		-- the client says 0 for a box with no limit
		local most = BT.Pill.Number(e.note.GetMaxLetters and e.note:GetMaxLetters(), 0)
		if most <= 0 then
			most = N.MAX_NOTE
		end
		local left = most - N.Length(text)
		local near = e.note:HasFocus() and left <= 30
		e.left:SetText(near and (left == 1 and "1 left" or ("%d left"):format(left)) or "")
		e.left:SetShown(near)
		e.note:SetTextInsets(2, near and 46 or 2, 0, 0)
	end
	e.note:SetScript("OnTextChanged", ghost)
	e.note:SetScript("OnEditFocusGained", function()
		BT.Widgets.Lit(e.fieldRim, 0.9)
		ghost()
	end)
	e.note:SetScript("OnEditFocusLost", function()
		-- A RIM IS FOUR BARS NOW, NOT ONE TEXTURE (Josh 2026-09-21). Pill.Panel
		-- hands back a ring so the border cannot bleed through the fill, and
		-- anything still painting it as a single texture calls a method a
		-- table does not have.
		BT.Pill.PaintRing(e.fieldRim, { 0.20, 0.26, 0.24, 0.95 })
		ghost()
	end)
	e.Ghost = ghost

	-- deleting a tag takes it off every character, so it asks first
	e.confirm = CreateFrame("Frame", nil, e)
	e.confirm:SetFrameStrata("FULLSCREEN_DIALOG")
	e.confirm:SetPoint("TOPLEFT", E_PAD, -(E_PAD + 20))
	e.confirm:SetPoint("TOPRIGHT", -E_PAD, -(E_PAD + 20))
	e.confirm:SetHeight(56)
	-- the one panel that is NOT see-through: a question about deleting
	-- something has to sit on its own ground
	BT.Widgets.Panel(e.confirm, { 0.08, 0.05, 0.05, 0.99 }, { 0.55, 0.25, 0.25, 1 })
	e.confirm.text = editorLine(e.confirm, 10, 0.92, 0.86, 0.84)
	e.confirm.text:SetPoint("TOPLEFT", 8, -8)
	e.confirm.text:SetPoint("TOPRIGHT", -8, -8)
	e.confirm.text:SetWordWrap(true)
	e.confirm.yes = BT.Widgets.Button(e.confirm, "Delete", 60, 18)
	e.confirm.yes:SetPoint("BOTTOMRIGHT", -8, 6)
	e.confirm.no = BT.Widgets.Button(e.confirm, "Keep", 48, 18)
	e.confirm.no:SetPoint("RIGHT", e.confirm.yes, "LEFT", -6, 0)
	e.confirm.no:SetScript("OnClick", function() e.confirm:Hide() end)
	e.confirm:Hide()

	e:Hide()
	return e
end

-- One row per tag, two to a line: a square of its colour, then its name.
function B.RebuildTags()
	-- the filter buttons on the Find tab show the same list, and used to be
	-- built once: a tag made in the editor had no button until /reload
	if buildFilters then
		buildFilters()
	end
	if not editor then
		return
	end
	local e = editor
	local width = (E_W - E_PAD * 2 - 8) / 2
	local tags = BT.AllTags()
	local y = E_PAD + 22
	for i, f in ipairs(tags) do
		local row = e.pool[i]
		if not row then
			row = CreateFrame("Button", nil, e)
			row:SetHeight(E_ROW)
			row:RegisterForClicks("AnyUp")
			-- ON IS THREE THINGS AT ONCE (Josh 2026-09-19). A dimmed square
			-- and slightly greyer text is not enough to read at a glance on a
			-- dark panel - you end up checking each one. A tag they carry gets
			-- a wash of its own colour behind the whole line, a solid square,
			-- and its name in full ink; one they do not gets an empty outline
			-- and grey. Three differences, and you can see it from the other
			-- side of the screen.
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetPoint("TOPLEFT", -3, 0)
			row.bg:SetPoint("BOTTOMRIGHT", 0, 0)
			row.bg:Hide()
			row.hot = row:CreateTexture(nil, "BORDER")
			row.hot:SetPoint("TOPLEFT", -3, 0)
			row.hot:SetPoint("BOTTOMRIGHT", 0, 0)
			row.hot:SetColorTexture(1, 1, 1, 0.06)
			row.hot:Hide()
			row:SetScript("OnEnter", function(self)
				self.hot:Show()
				local tag = U.TagByKey(self.tagKey)
				self.kill:SetShown(tag ~= nil and not tag.builtin)
			end)
			row:SetScript("OnLeave", function(self)
				self.hot:Hide()
				if not (self.kill.IsMouseOver and self.kill:IsMouseOver()) then
					self.kill:Hide()
				end
			end)
			row.swatch = row:CreateTexture(nil, "ARTWORK")
			row.swatch:SetSize(E_SWATCH, E_SWATCH)
			row.swatch:SetPoint("LEFT", 0, 0)
			-- the hollow middle of an unlit swatch: the panel's own colour,
			-- one pixel in, so the square reads as an empty box
			row.hollow = row:CreateTexture(nil, "OVERLAY")
			row.hollow:SetSize(E_SWATCH - 2, E_SWATCH - 2)
			row.hollow:SetPoint("CENTER", row.swatch, "CENTER")
			row.hollow:Hide()

			-- A CROSS YOU CAN SEE (Josh 2026-09-19). Deleting a tag of your own
			-- was right-click and nothing else, which is a thing you have to be
			-- told - and a right-click that misses the row lands on the panel's
			-- click-catcher, so the panel shuts and it looks like the feature
			-- is gone. It appears on hover, on your own tags only; right-click
			-- still works for anybody who knew.
			row.kill = CreateFrame("Button", nil, row)
			row.kill:SetSize(14, 14)
			row.kill:SetPoint("RIGHT", 0, 0)
			row.kill:RegisterForClicks("AnyUp")
			row.kill:SetFrameLevel(BT.Pill.Number(row.GetFrameLevel and row:GetFrameLevel(), 5) + 2)
			row.kill.icon = row.kill:CreateTexture(nil, "OVERLAY")
			row.kill.icon:SetAllPoints()
			row.kill.icon:SetTexture(BT.Dock.ICONS)
			BT.Dock.CrossCoord(row.kill.icon)
			row.kill.icon:SetVertexColor(0.55, 0.60, 0.58, 1)
			row.kill:Hide()
			row.kill:SetScript("OnEnter", function(self)
				self.icon:SetVertexColor(0.86, 0.33, 0.33, 1)
				self:Show()
			end)
			row.kill:SetScript("OnLeave", function(self)
				self.icon:SetVertexColor(0.55, 0.60, 0.58, 1)
			end)
			row.kill:SetScript("OnClick", function(self)
				local tag = U.TagByKey(row.tagKey)
				if tag and not tag.builtin then
					B.ConfirmTagDelete(tag)
				end
			end)
			row.text = editorLine(row, 10)
			row.text:SetPoint("LEFT", E_SWATCH + 6, 0)
			row.text:SetPoint("RIGHT", -16, 0)
			row.text:SetWordWrap(false)
			row:SetScript("OnClick", function(self, click)
				if not selected then
					return
				end
				if click == "RightButton" then
					local tag = U.TagByKey(self.tagKey)
					if tag and not tag.builtin then
						B.ConfirmTagDelete(tag)
					end
					return
				end
				N.ToggleTag(selected, self.tagKey, editor and editor.info)
				B.Refresh()
			end)
			e.pool[i] = row
		end
		local column = (i - 1) % 2
		local line = math.floor((i - 1) / 2)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", e, "TOPLEFT", E_PAD + column * (width + 8), -(y + line * E_ROW))
		row:SetWidth(width)
		row.tagKey = f.key
		row.tag = f
		row:Show()
		e.tagBtns[f.key] = row
	end
	for i = #tags + 1, #e.pool do
		e.pool[i]:Hide()
	end
	-- everything under the tags hangs off however many rows there were
	local lines = math.ceil(#tags / 2)
	local below = y + lines * E_ROW + 2
	e.newTag:ClearAllPoints()
	e.newTag:SetPoint("TOPLEFT", e, "TOPLEFT", E_PAD, -below)
	e.newTag:SetWidth(width)
	e.maker:ClearAllPoints()
	e.maker:SetPoint("TOPLEFT", e, "TOPLEFT", E_PAD, -below)
	e.maker:SetPoint("TOPRIGHT", e, "TOPRIGHT", -E_PAD, -below)
	local makerTall = e.maker:IsShown() and (E_ROW + 20) or 0
	local noteTop = below + E_ROW + 6 + makerTall
	e.field:ClearAllPoints()
	e.field:SetPoint("TOPLEFT", e, "TOPLEFT", E_PAD, -noteTop)
	e.field:SetPoint("TOPRIGHT", e, "TOPRIGHT", -E_PAD, -noteTop)
	e.note:ClearAllPoints()
	e.note:SetPoint("TOPLEFT", e.field, "TOPLEFT", 6, -2)
	e.note:SetPoint("BOTTOMRIGHT", e.field, "BOTTOMRIGHT", -6, 2)
	e.ghost:ClearAllPoints()
	e.ghost:SetPoint("LEFT", e.field, "LEFT", 7, 0)
	e:SetHeight(noteTop + 22 + E_PAD)
end

-- the panel, the click-catcher and the maker, for the tests
function B.Editor()
	return editor
end

function B.Catcher()
	return editor and editor.catch
end

function B.Maker()
	return editor and editor.maker
end

function B.ConfirmButtons()
	return editor and editor.confirm
end

function B.ShowTagMaker(show)
	if not editor then
		return
	end
	editor.maker:SetShown(show and true or false)
	editor.newTag:SetShown(not show)
	B.RebuildTags()
	if show then
		editor.maker.box:SetFocus()
	end
end

-- Deleting a tag takes it off every character that carries it, so the question
-- "how much am I about to throw away" has an answer before the click.
function B.ConfirmTagDelete(tag)
	if not (editor and tag) then
		return
	end
	local characters, books = BT.TagUsage(tag.key)
	-- NOTHING TO WARN ABOUT (Josh 2026-09-19). The question exists because
	-- deleting a tag takes it off everybody who carries it. A tag nobody
	-- carries takes nothing with it, so asking is a click you have to make for
	-- no reason - it just goes.
	if characters == 0 then
		BT.RemoveTag(tag.key)
		editor.confirm:Hide()
		B.RebuildTags()
		B.Refresh()
		return
	end
	editor.confirm.text:SetText(
		("Delete %s? It's on %d character%s%s.")
			:format(tag.label, characters, characters == 1 and "" or "s",
				books > 1 and (" in %d books"):format(books) or ""))
	editor.confirm.yes:SetScript("OnClick", function()
		BT.RemoveTag(tag.key)
		editor.confirm:Hide()
		B.RebuildTags()
		B.Refresh()
	end)
	editor.confirm:Show()
end

function B.ConfirmShown()
	return editor ~= nil and editor.confirm:IsShown()
end

function B.EditorRefreshes()
	return editorRefreshes
end

local function refreshEditor()
	if not (editor and editor:IsShown()) then
		return
	end
	editorRefreshes = editorRefreshes + 1
	local p = face(selected, editor.info)
	if not p then
		return
	end
	editor.title:SetText(U.Colorize(p.name, p.class))
	for _, row in pairs(editor.tagBtns) do
		local f = row.tag
		local on = p.tags and p.tags[row.tagKey]
		local c = (f and f.color) or { 0.6, 0.65, 0.62 }
		if on then
			row.swatch:SetColorTexture(c[1], c[2], c[3], 1)
			row.hollow:Hide()
			row.bg:SetColorTexture(c[1], c[2], c[3], 0.14)
			row.bg:Show()
			row.text:SetTextColor(0.92, 0.96, 0.94)
		else
			row.swatch:SetColorTexture(c[1], c[2], c[3], 0.45)
			row.hollow:SetColorTexture(0.05, 0.07, 0.06, 1)
			row.hollow:Show()
			row.bg:Hide()
			row.text:SetTextColor(0.42, 0.48, 0.45)
		end
		row.text:SetText(f and f.label or row.tagKey)
	end
	-- refilled for a different character, or when the box is not being
	-- typed in - never over a half-written note (the tag maker takes the
	-- focus away, and a refresh then put the old note back over yours)
	local typed = editor.note:GetText()
	if editor.noteFor ~= selected
		or (not editor.note:HasFocus() and (typed == nil or typed == editor.noteLoaded)) then
		editor.note:SetMaxLetters(N.Room(p))
		editor.note:SetText(p.note or "")
		editor.noteFor, editor.noteLoaded = selected, p.note or ""
	end
	if editor.Ghost then
		editor.Ghost()
	end
end

-- BESIDE, NEVER INSIDE (Josh 2026-09-19). It used to dock into the bottom of
-- the Ledger tab, which made the window taller and the panel a part of it.
-- Now it is always its own small panel, put where the thing you clicked is:
-- against the right edge of the window when the window is open, against the
-- left edge of the dock when it is not. Never overlapping either.
function B.DockEditor()
	if not editor then
		return
	end
	local window = BT.Window.Frame()
	editor:SetParent(UIParent)
	editor:ClearAllPoints()
	editor:SetWidth(E_W)
	editor:SetClampedToScreen(true)
	if window and BT.Window.IsShown() then
		editor:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
	else
		editor:SetPoint("CENTER")
	end
	B.RebuildTags()
end

local function num(v, fallback)
	return BT.Pill.Number(v, fallback)
end

-- BESIDE THE DOCK, NOT OVER IT (Josh 2026-09-19). Clicking a name on the dock
-- used to open this wherever the arithmetic put it, which was usually on top
-- of the thing you had just clicked. It belongs alongside: pinned to the
-- dock's left edge, top aligned, so the name you clicked and the note you are
-- writing about them are on one line - and narrow, because it holds a row of
-- tags and one field, not a form.
local FLOAT_W = E_W

function B.FloatEditor(anchor)
	if not editor then
		return
	end
	editor:SetParent(UIParent)
	editor:ClearAllPoints()
	editor:SetWidth(E_W)
	editor:SetClampedToScreen(true) -- the backstop, whatever the arithmetic says
	B.RebuildTags()
	-- BESIDE THE ROW, NOT BESIDE THE PANEL (Josh 2026-09-21). This took the
	-- dock over whatever it was handed, which top-aligned it with the whole
	-- panel. That was the same thing while the dock began with the Ledger's
	-- row - now the panel opens with a header and a map above it, so "the top
	-- of the dock" is a long way above the name you clicked.
	--
	-- The frame you clicked decides the height; the dock still decides the
	-- side, because that is about the screen edge rather than about the row.
	local dock = BT.Dock and BT.Dock.Frame()
	anchor = anchor or dock
	if not anchor then
		editor:SetPoint("CENTER")
		return
	end
	-- to the left, unless there is no room to the left, in which case the
	-- right: a panel half off the screen is worse than one on the wrong side
	local edge = dock or anchor
	local left = num(edge.GetLeft and edge:GetLeft(), nil)
	local onRight = left and left < FLOAT_W + 20
	-- LEVEL WITH THE ROW, CLEAR OF THE DOCK (Josh 2026-09-22). Hung from the
	-- name you clicked, the editor started where that cell does - a little
	-- below the top of its row, and on the inside of the class icon, so it
	-- sat low and ran over the dock's edge. The height is the ROW's top and
	-- the side is the DOCK's edge, eight clear of it, like everything else
	-- that opens beside the panel.
	local row = BT.Dock and BT.Dock.Row and BT.Dock.Row()
	local topOf = (row and row.IsShown and row:IsShown() and row) or anchor
	local dockTop = dock and num(dock.GetTop and dock:GetTop(), nil)
	local rowTop = num(topOf.GetTop and topOf:GetTop(), nil)
	if dock and dockTop and rowTop then
		-- the dock may be scaled: its tops are in its own units, the offset
		-- is in the editor's
		local dockScale = num(dock.GetEffectiveScale and dock:GetEffectiveScale(), 1)
		local ownScale = num(editor.GetEffectiveScale and editor:GetEffectiveScale(), 1)
		local dy = (rowTop - dockTop) * dockScale / math.max(0.01, ownScale)
		if onRight then
			editor:SetPoint("TOPLEFT", dock, "TOPRIGHT", 8, dy)
		else
			editor:SetPoint("TOPRIGHT", dock, "TOPLEFT", -8, dy)
		end
		return
	end
	if onRight then
		editor:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
	else
		editor:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
	end
end

-- `info`: what a unit in front of you says about them, for someone neither
-- book has yet - the first note on a stranger makes their row
function B.OpenEditorFor(key, anchor, info)
	if not (editor and key and face(key, info)) then
		return false
	end
	selected = key
	editor.info = info
	if panel and BT.Window.IsShown() and BT.Window.View() == "ledger" then
		B.DockEditor()
	else
		B.FloatEditor(anchor)
	end
	return B.OpenEditor()
end

-- CLICK ANYWHERE ELSE AND IT GOES (Josh 2026-09-19). A small panel that
-- follows what you clicked has to get out of the way when you click something
-- else, and it has to keep what you typed on the way out: losing a half-typed
-- note because you clicked the game world is the kind of thing you only
-- forgive an addon once.
local function catcher()
	if editor.catch then
		return editor.catch
	end
	local c = CreateFrame("Button", nil, UIParent)
	c:SetAllPoints(UIParent)
	-- THE SAME STRATA AS THE PANEL, A LEVEL BELOW IT (Josh 2026-09-19). It was
	-- put in FULLSCREEN, which is ABOVE the panel's own DIALOG - so it caught
	-- every click including the ones meant for the tags, and the panel shut
	-- the moment you tried to use it. Strata first, frame level second: a
	-- higher strata wins whatever the levels say.
	c:SetFrameStrata("DIALOG")
	c:EnableMouse(true)
	c:RegisterForClicks("AnyUp")
	c:SetScript("OnClick", function()
		B.SaveNote()
		B.CloseEditor()
	end)
	c:Hide()
	editor.catch = c
	return c
end

-- What is in the box, written down. Called on the way out however you leave.
-- ONLY A CHANGED NOTE IS WRITTEN (Josh 2026-09-23, audit). Writing a note
-- stamps it with who and when, and the editor and the cards wrote whatever was
-- in the box on every Enter and every click away - so a note your main wrote
-- in March came out "- Alt, today" after you toggled a tag. Every save goes
-- through here, and one that changes nothing is not a save.
function B.SaveText(key, text)
	if not (key and type(text) == "string") then
		return false
	end
	local info = editor and editor.info
	local p = face(key, info)
	if p and (p.note or "") ~= text then
		step("write", N.SetNote, key, text, key == selected and info or nil)
		return true
	end
	return false
end

function B.SaveNote()
	if not (editor and selected and editor.note) then
		return false
	end
	return B.SaveText(selected, editor.note:GetText())
end

function B.OpenEditor()
	if not (editor and selected) then
		return false
	end
	editor:Show()
	local c = catcher()
	-- under the panel, over everything else
	local level = BT.Pill.Number(editor.GetFrameLevel and editor:GetFrameLevel(), 10)
	editor:SetFrameLevel(level + 5)
	c:SetFrameLevel(math.max(1, level))
	c:Show()
	refreshEditor()
	editor.note:SetFocus()
	fitWindow()
	return true
end

-- SAVED ON THE WAY OUT, HOWEVER YOU LEAVE (Josh 2026-09-23, audit): the X
-- and switching the Ledger off closed the panel without saving, and what you
-- had typed was lost
function B.CloseEditor()
	if editor then
		B.SaveNote()
		editor.note:ClearFocus()
		editor.confirm:Hide()
		editor:Hide()
		if editor.catch then
			editor.catch:Hide()
		end
	end
	fitWindow()
	B.Refresh()
end

function B.EditorShown()
	return editor ~= nil and editor:IsShown()
end


-- handles for the headless tests, which click these rather than trust them

function B.EditorTagButtons()
	return editor and editor.tagBtns
end

function B.EditorNoteBox()
	return editor and editor.note
end

-- THE SAME TAG EVERYWHERE (Josh 2026-09-19). The note panel, the dock and the
-- unit tooltip all show a tag as a square of its colour with its name beside
-- it. The cards were the last place still drawing rounded pills, so the same
-- tag looked like two different things depending on where you read it.
--
-- On is the same three things it is in the note panel: a wash of the tag's
-- colour behind the row, a solid square, and the name in full ink. Off is an
-- empty outline and grey.
local TAG_H, TAG_GAP, TAG_SWATCH = 16, 12, 7

local function cardTag(card, i)
	local t = card.pills[i]
	if not t then
		-- a Button, not a Frame: on the open card every tag is a switch
		t = CreateFrame("Button", nil, card)
		t:SetHeight(TAG_H)
		t:RegisterForClicks("AnyUp")
		t.bg = t:CreateTexture(nil, "BACKGROUND")
		t.bg:SetPoint("TOPLEFT", -4, 0)
		t.bg:SetPoint("BOTTOMRIGHT", 4, 0)
		t.bg:Hide()
		t.hot = t:CreateTexture(nil, "BORDER")
		t.hot:SetPoint("TOPLEFT", -4, 0)
		t.hot:SetPoint("BOTTOMRIGHT", 4, 0)
		t.hot:SetColorTexture(1, 1, 1, 0.06)
		t.hot:Hide()
		t.swatch = t:CreateTexture(nil, "ARTWORK")
		t.swatch:SetSize(TAG_SWATCH, TAG_SWATCH)
		t.swatch:SetPoint("LEFT", 0, 0)
		-- the hollow middle of an unlit swatch: the card's own colour, one
		-- pixel in, so the square reads as an empty box
		t.hollow = t:CreateTexture(nil, "OVERLAY")
		t.hollow:SetSize(TAG_SWATCH - 2, TAG_SWATCH - 2)
		t.hollow:SetPoint("CENTER", t.swatch, "CENTER")
		t.hollow:Hide()
		t.text = label(t, "", "small")
		t.text:SetPoint("LEFT", TAG_SWATCH + 6, 0)
		t.text:SetWordWrap(false)
		t:SetScript("OnEnter", function(self)
			if self.live then
				self.hot:Show()
			end
		end)
		t:SetScript("OnLeave", function(self) self.hot:Hide() end)
		t:SetScript("OnClick", function(self)
			if card.key and self.tagKey then
				N.ToggleTag(card.key, self.tagKey)
				B.Refresh()
			end
		end)
		card.pills[i] = t
	end
	return t
end

-- `open` lays out EVERY tag, hollow when the character does not carry it and
-- lit when they do, each one a switch. Closed, it lays out only the ones they
-- carry, and they are just marks. Returns how many were drawn and how many
-- rows they took.
local function layTags(card, p, open)
	local x, y, shown, rows = 0, 0, 0, 1
	-- the card is as wide as the panel it is in, so the wrap point is measured
	-- rather than assumed (Josh 2026-09-19 - it was 580 against a 584-wide
	-- panel, so nothing ever wrapped and the row ran off the edge)
	local width = BT.Pill.Number(card.GetWidth and card:GetWidth(), 560) - 28
	for _, f in ipairs(BT.AllTags()) do
		local on = p.tags and p.tags[f.key] or false
		if open or on then
			shown = shown + 1
			local t = cardTag(card, shown)
			t.text:SetText(f.label)
			local w = TAG_SWATCH + 6
				+ BT.Pill.Number(t.text.GetStringWidth and t.text:GetStringWidth(), 46)
			if x > 0 and x + w > width then
				x, y, rows = 0, y + TAG_ROW_H, rows + 1
			end
			local c = f.color or { 0.6, 0.65, 0.62 }
			if on then
				t.swatch:SetColorTexture(c[1], c[2], c[3], 1)
				t.hollow:Hide()
				t.bg:SetColorTexture(c[1], c[2], c[3], 0.14)
				t.bg:Show()
				t.text:SetTextColor(0.92, 0.96, 0.94)
			else
				t.swatch:SetColorTexture(c[1], c[2], c[3], 0.45)
				t.hollow:SetColorTexture(0.07, 0.10, 0.09, 1)
				t.hollow:Show()
				t.bg:Hide()
				t.text:SetTextColor(0.42, 0.48, 0.45)
			end
			t:SetWidth(w)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + x, -30 - y)
			t.tagKey = f.key
			t.live = open and true or false
			t:EnableMouse(t.live)
			t:Show()
			x = x + w + TAG_GAP
		end
	end
	for i = shown + 1, #card.pills do
		card.pills[i]:Hide()
	end
	card.tagWidth = x
	return shown, rows
end

-- Where the cards end, which is where the panel docks and where the window
-- stops. A window with five empty card slots under one result is mostly a
-- reminder that you searched for something rare.
function editorTop()
	return VIEW_TOP + CARDS_TOP + cardsHeight + 4
end

-- The window is one fixed size now that it holds tabs for everything, so
-- there is nothing left to resize: the panel is as tall as its tab. Kept as a
-- no-op because the editor's open and close paths still call it, and they will
-- again the day something here does need a second thought about its height.
function fitWindow()
end

-- One card: who they are, what you tagged them, what you wrote. Returns how
-- tall it had to be.
local function fillCard(card, row)
	local p = row.p
	card.key = row.key
	card.name:SetText(U.Colorize(p.name, p.class))
	-- the level rides with the name rather than heading a line of small print
	-- and how often you grouped with them, after it (Modules/Ledger/Groups.lua)
	local small = {}
	small[#small + 1] = p.level and U.LevelText(p) or nil
	small[#small + 1] = BT.LedgerGroups and BT.LedgerGroups.Line(p) or nil
	-- and your duels with them (Modules/Ledger/Duels.lua)
	small[#small + 1] = BT.LedgerDuels and BT.LedgerDuels.Line(p) or nil
	card.level:SetText(#small > 0 and ("|cff6b7a74" .. table.concat(small, " · ") .. "|r") or "")
	local open = row.key == selected
	local tagged, rows = layTags(card, p, open)
	card.sel:SetShown(open)

	if open then
		-- the note is a field you type in, under the tags
		card.note:Hide()
		card.credit:Hide()
		card.noteMark:Hide()
		card.noteBox:ClearAllPoints()
		card.noteBox:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -30 - rows * TAG_ROW_H - 4)
		card.noteBox:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -30 - rows * TAG_ROW_H - 4)
		if not card.noteBox:HasFocus() then
			card.noteBox:SetMaxLetters(N.Room(p))
			card.noteBox:SetText(p.note or "")
		end
		card.noteBox:Show()
		local height = 34 + rows * TAG_ROW_H + 30
		card:SetHeight(height)
		return height
	end

	card.noteBox:Hide()
	-- closed, the note follows the tags along the one row they share
	-- THE QUOTE HANGS OFF THE RIGHT (Josh 2026-09-19). Left-aligned it started
	-- wherever the tags happened to stop, so the notes down a list of results
	-- never lined up with one another. Against the right edge they do, and the
	-- tags keep the left.
	card.note:ClearAllPoints()
	card.note:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (tagged > 0 and card.tagWidth or 0), -30)
	card.note:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -30)
	-- QUOTED, NOT LABELLED (Josh 2026-09-19). The gold bar was a label saying
	-- "a note follows", which the words already say by being words. Quotes do
	-- the same job in two characters and read as somebody's own phrasing.
	-- There is no italic font in the client - FRIZQT, ARIALN, SKURRI and
	-- MORPHEUS are all upright - so the quotes carry it alone.
	card.note:SetText(p.note and ('"%s"'):format(p.note) or "")
	card.noteMark:Hide()
	card.note:SetShown(p.note ~= nil)
	-- and its source under it, the same line the unit tooltip and the note
	-- panel show: a note from your main in March is not a note your alt wrote
	-- this afternoon
	local credit = p.note and U.Credit(p) or nil
	card.credit:SetText(credit or "")
	card.credit:SetShown(credit ~= nil)
	card:Show()
	local height = credit and CARD_CREDIT
		or ((tagged > 0 or p.note) and CARD_RICH or CARD_PLAIN)
	card:SetHeight(height)
	return height
end

local function refreshFind()
	if not (panel and searchBox) then
		return
	end
	-- NOT WHILE YOU ARE TYPING (Josh 2026-09-22). A sighting bumps DB.rev, the
	-- tick refills every card, and a card that was yours a moment ago can be
	-- somebody else's: hiding its box then saved your half-typed note on them.
	for _, card in ipairs(cards) do
		if card.noteBox and card.noteBox.HasFocus and card.noteBox:HasFocus() then
			return
		end
	end
	local text = searchBox:GetText()
	if type(text) ~= "string" then
		text = ""
	end
	local query = {
		text = text ~= "" and text or nil,
		tag = state.tagFilter,
		mineOnly = state.mineOnly,
		limit = CARDS + 1,
	}
	local asked = query.text ~= nil or query.tag ~= nil or query.mineOnly
	results = {}
	if asked then
		-- the people you wrote on first; then, with a census, anyone else it
		-- knows - but a tag or "yours only" is a question for the Ledger alone
		local have = {}
		for _, r in ipairs(N.Search(query)) do
			results[#results + 1] = r
			have[r.key] = true
		end
		local C = census()
		if C and not query.tag and not query.mineOnly and #results < query.limit then
			for _, r in ipairs(C.Search(BT.db, query)) do
				if #results >= query.limit then
					break
				end
				if not have[r.key] then
					results[#results + 1] = r
				end
			end
		end
	end
	shownCards, cardsHeight = 0, 0
	for i, card in ipairs(cards) do
		local row = results[i]
		if row and i <= CARDS then
			local h = fillCard(card, row)
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", findView, "TOPLEFT", 16, -(CARDS_TOP + cardsHeight))
			card:SetPoint("TOPRIGHT", findView, "TOPRIGHT", -16, -(CARDS_TOP + cardsHeight))
			card:Show()
			cardsHeight = cardsHeight + h + CARD_GAP
			shownCards = i
		else
			card.key = nil
			card:Hide()
		end
	end
	if not asked then
		-- COUNTED, NOT READ (Josh 2026-09-30, review): DB.Stats is kept until
		-- the book changes, and in a city it changes every second, so each
		-- tick unpacked every row in the book to say how many there are.
		-- DB.Count only counts them, as the window's subtitle does.
		local C = census()
		emptyLine:SetText(C
			and ("%s characters · %s you've noted"):format(U.Commas((C.Count(BT.db))), U.Commas(N.CountNoted()))
			or ("%s characters you've noted"):format(U.Commas(N.CountNoted())))
		emptyLine:Show()
	elseif #results == 0 then
		emptyLine:SetText("Nobody matches that.")
		emptyLine:Show()
	else
		emptyLine:Hide()
	end
	moreLine:SetText(#results > CARDS and ("More than %d match. Type more to narrow it."):format(CARDS) or "")
	moreLine:ClearAllPoints()
	moreLine:SetPoint("TOPLEFT", 20, -(CARDS_TOP + cardsHeight))
	BT.Window.UpdateSubtitle()
	-- the panel rides under whatever is on screen now
	if editor and editor:IsShown() and editor:GetParent() == panel then
		editor:ClearAllPoints()
		editor:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -editorTop())
	end
end

-- Called on a timer while the window is open: the book fills up as you play,
-- and a window that shows what it showed a minute ago is worse than one you
-- have to reopen. Cheap when nothing has changed, which is most ticks.
-- A SIGHTING IS NOT A NOTE (Josh 2026-09-30, review). Both books' changes
-- were one number, so every sighting ran the whole refresh, and in a city
-- that is one a second. The refresh searches the census when a search is
-- typed, and lays out the dock and the editor again. Only the list can show
-- a sighting, so a census change redraws the list alone, at most every ten
-- seconds, as the Census window does. While a tag or "My notes" leaves the
-- census out of the list, a census change redraws nothing. Something you
-- wrote still redraws everything on the next tick.
B.BOOK_EVERY = 10

function B.Tick()
	if not (panel and BT.Enabled("ledger") and BT.Window.IsShown() and BT.Window.View() == "ledger") then
		return false
	end
	local notes, book = N.rev, bookRev()
	if notes == seenNotes and book == seenBook then
		return false
	end
	-- NOT UNDER THE POINTER (Josh 2026-09-23, audit): the list is sorted by
	-- who was seen last, and in a city somebody is always being seen - the
	-- cards moved every second, and a click landed on whoever had just slid
	-- under it. While you are pointing at the list it waits; it catches up
	-- the moment you move off it.
	if panel.IsMouseOver and panel:IsMouseOver() then
		return false
	end
	local now = (type(GetTime) == "function" and GetTime()) or 0
	if notes == seenNotes then
		if state.tagFilter or state.mineOnly then
			seenBook = book
			return false
		end
		if bookAt and now - bookAt < B.BOOK_EVERY then
			return false
		end
		seenBook, bookAt = book, now
		refreshFind()
		return true
	end
	seenNotes, seenBook, bookAt = notes, book, now
	-- never overwrite a note you are in the middle of typing
	if B.EditorShown() then
		refreshFind()
	else
		B.Refresh()
	end
	return true
end

-- ---------------------------------------------------------------------------
-- How long a save takes
-- ---------------------------------------------------------------------------

-- SAVING A NOTE LAGS (Josh 2026-09-29: "saving notes causes some lag. I ran
-- the CPU debug tool"). The CPU row times what runs on its own, and a save
-- runs from a key or a click, so it never showed there. Each save times its
-- own steps instead - the write, the box letting go, and each part of the
-- redraw after it - and the last few go into the saved file when the
-- Testing page's Record button runs (ledgerDump).

-- a whole save, from the key or the click to the last redraw
function B.Timed(how, fn)
	if timing then
		return fn()
	end
	timing = { how = how, steps = {} }
	local t0 = clock()
	local ok, err = pcall(fn)
	local done = timing
	timing = nil
	done.total = clock() - t0
	table.insert(B.saves, 1, done)
	B.saves[6] = nil
	if not ok then
		error(err, 0)
	end
	return done
end

function B.Dump()
	local lines = {}
	for _, s in ipairs(B.saves) do
		local parts = {}
		for _, st in ipairs(s.steps) do
			parts[#parts + 1] = ("%s %.1f"):format(st[1], st[2])
		end
		lines[#lines + 1] = ("%s · %.1f ms · %s"):format(s.how, s.total, table.concat(parts, " · "))
	end
	if #lines == 0 then
		lines[1] = "no note saved since the last /reload"
	end
	BT.EnsureBound()
	BeebModDB.ledgerDump = { at = U.Now(), lines = lines }
	return #lines
end
BT.Record("ledgerDump", B.Dump, "ledger")

function B.Refresh()
	-- THE PANEL IS REFRESHED WHATEVER THE WINDOW IS DOING (Josh 2026-09-19).
	-- This used to return early whenever the window's last view was the
	-- census - even with the window CLOSED - so tags toggled from the bar
	-- changed the book and never repainted the panel you clicked them on.
	-- THE LIST WAITS WHILE NOBODY CAN SEE IT (Josh 2026-09-29, the lag on a
	-- save): the editor is repainted either way, but the cards under the
	-- search box only when the Ledger's page is up. Refilling them runs the
	-- search again, through the whole Census with a search typed, and
	-- B.Tick catches them up the moment the page shows (seenNotes is left
	-- behind for it).
	if BT.Window.IsShown() and BT.Window.View() == "ledger" then
		step("list", refreshFind)
	end
	step("editor", refreshEditor)
	-- THE DOCK SHOWS THESE TAGS AS WELL (Josh 2026-09-19). Tagging somebody in
	-- the panel changed the book and repainted the panel, and the row of dots
	-- on the dock - the same tags, on the same character - went on showing
	-- what it showed a minute ago.
	if BT.Dock and BT.Dock.Update then
		step("dock", BT.Dock.Update)
	end
	-- A UNIT TOOLTIP IS ONLY REDRAWN WHEN IT WOULD SAY SOMETHING ELSE (Josh
	-- 2026-09-19). Restack re-sets the unit, which tears the tooltip down and
	-- rebuilds it - so doing it on every DB.rev meant doing it on every
	-- sighting, which in a city is several a second, and the tooltip under
	-- your cursor jumped the whole time the window was open.
	if N.noteRev ~= restackedAt and BT.Tooltip and BT.Tooltip.Restack then
		restackedAt = N.noteRev
		step("tooltip", BT.Tooltip.Restack)
	end
end

-- the cards, for the headless tests
function B.Cards()
	return cards
end

-- The "only:" row: a button per tag, sized to its label, wrapped at the
-- panel's width. Pooled, so it can be built again whenever the tags change.
buildFilters = function()
	if not findView then
		return 0
	end
	findView.tagButtons = findView.tagButtons or {}
	local pool = findView.tagButtons
	local fx, fy, n = 146, -34, 0
	for _, f in ipairs(BT.AllTags()) do
		n = n + 1
		-- sized to the label: a fixed width let "Do not group" run out of its
		-- own button (Josh 2026-09-19)
		local w = math.max(56, #f.label * 7 + 18)
		if fx + w > FILTER_W then
			fx, fy = 146, fy - 24
		end
		local b = pool[n]
		if not b then
			b = BT.Widgets.Button(findView, f.label, w, 20)
			b:SetScript("OnClick", function(self)
				-- written out, because `(x == y) and nil or y` can never BE
				-- nil: `and nil` is false, so the `or` branch always wins and
				-- the filter could be switched on but never off (Josh 2026-09-19)
				if state.tagFilter == self.tagKey then
					state.tagFilter = nil
				else
					state.tagFilter = self.tagKey
				end
				for _, other in ipairs(pool) do
					other:SetPressed(other.tagKey == state.tagFilter)
				end
				refreshFind()
			end)
			pool[n] = b
		else
			b:SetLabel(f.label)
			b:SetWidth(w)
		end
		b.tagKey = f.key
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", fx, fy)
		b:SetPressed(state.tagFilter == f.key)
		b:Show()
		fx = fx + w + 5
	end
	for i = n + 1, #pool do
		pool[i]:Hide()
		pool[i].tagKey = nil
	end
	-- a filter on a tag that no longer exists is no filter
	if state.tagFilter and not U.TagByKey(state.tagFilter) then
		state.tagFilter = nil
	end
	return n
end

function B.Results()
	return results
end

-- nil closes whatever was open
function B.Select(key)
	selected = key
	B.Refresh()
end

-- Build the Ledger's panel into the tab the toolkit hands us. Everything from
-- here down is the code that used to build the standalone window; what has
-- gone is the frame, the title, the close button and the tabs - the toolkit
-- owns those now, and a module should not draw them twice.
function B.Build(parent)
	panel = parent
	findView = CreateFrame("Frame", nil, panel)
	findView:SetAllPoints()

	searchBox = CreateFrame("EditBox", nil, findView, "InputBoxTemplate")
	searchBox:SetSize(300, 20)
	searchBox:SetPoint("TOPLEFT", 20, -6)
	searchBox:SetAutoFocus(false)
	-- TYPING IS A BURST (Josh 2026-09-19). OnTextChanged fires per letter, and
	-- "lighthammer" is twelve searches of the whole book for eleven answers
	-- nobody read. One is scheduled a moment ahead instead, and every letter
	-- that lands before it fires is absorbed - so a word costs one search and
	-- the box still keeps up with you.
	local pending = false
	searchBox:SetScript("OnTextChanged", function()
		if not (C_Timer and C_Timer.After) then
			refreshFind()
			return
		end
		if pending then
			return
		end
		pending = true
		C_Timer.After(0.12, function()
			pending = false
			refreshFind()
		end)
	end)
	searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	local prompt = label(findView, "Name, guild, or a word you wrote", "small", 0.42, 0.47, 0.45)
	prompt:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

	-- the questions you actually ask: who did I write about, and who did I tag
	local only = label(findView, "Only:", "small", 0.42, 0.47, 0.45)
	only:SetPoint("TOPLEFT", 20, -38)
	local mine = BT.Widgets.Button(findView, "My notes", 86, 20)
	mine:SetPoint("TOPLEFT", 54, -34)
	mine:SetScript("OnClick", function(self)
		state.mineOnly = not state.mineOnly
		self:SetPressed(state.mineOnly)
		refreshFind()
	end)
	findView.mineButton = mine
	buildFilters()

	-- the cards: five is what fits, and more than five means "search better"
	for i = 1, CARDS do
		local card = CreateFrame("Button", nil, findView)
		-- AS WIDE AS THE PANEL, NOT 612 (Josh 2026-09-19). The content area is
		-- 584 wide; a card fixed at 612 ran forty pixels past the window's own
		-- edge, note field and all. Both edges are anchored, so the card is
		-- whatever the panel is.
		card:SetHeight(CARD_PLAIN)
		card:SetPoint("TOPLEFT", findView, "TOPLEFT", 16, -(CARDS_TOP + (i - 1) * CARD_RICH))
		card:SetPoint("TOPRIGHT", findView, "TOPRIGHT", -16, -(CARDS_TOP + (i - 1) * CARD_RICH))
		-- the rim is under the fill, so selecting a card draws a line around it
		-- rather than washing it green
		card.sel = card:CreateTexture(nil, "BACKGROUND")
		card.sel:SetAllPoints()
		BT.Widgets.Lit(card.sel, 0.75)
		card.sel:Hide()
		local cardBg = card:CreateTexture(nil, "BORDER")
		cardBg:SetPoint("TOPLEFT", 1, -1)
		cardBg:SetPoint("BOTTOMRIGHT", -1, 1)
		cardBg:SetColorTexture(0.09, 0.12, 0.11, 0.94)
		card.name = label(card, "", nil)
		card.name:SetPoint("TOPLEFT", 12, -7)
		card.level = label(card, "", "small", 0.42, 0.48, 0.45)
		card.level:SetPoint("LEFT", card.name, "RIGHT", 8, -1)
		card.pills = {}
		-- the note wears a gold bar rather than a "Note:" label: the colour
		-- says what it is, and the words are yours
		card.noteMark = card:CreateTexture(nil, "ARTWORK")
		card.noteMark:SetSize(2, 14)
		card.noteMark:SetColorTexture(1, 0.82, 0.25, 0.9)
		card.note = label(card, "", nil)
		card.note:SetWordWrap(false)
		-- a shade warmer than the interface around it, the way a quotation
		-- sits apart from the page
		card.note:SetTextColor(0.90, 0.88, 0.80)
		card.note:SetJustifyH("RIGHT")
		card.credit = label(card, "", "small", 0.42, 0.48, 0.45)
		card.credit:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -46)
		card.credit:SetJustifyH("RIGHT")
		card.credit:SetWordWrap(false)
		card.credit:Hide()
		card.noteBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
		card.noteBox:SetHeight(20)
		card.noteBox:SetAutoFocus(false)
		-- Enter saves and leaves; leaving saves too, and a save that changes
		-- nothing is not one, so the note is written once
		card.noteBox:SetScript("OnEnterPressed", function(self)
			B.Timed("Enter on a card", function()
				B.SaveText(self.forKey or card.key, self:GetText())
				step("let go", self.ClearFocus, self)
				B.Refresh()
			end)
		end)
		card.noteBox:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			B.Refresh()
		end)
		-- SAVING IS NOT A SECRET (Josh 2026-09-19). The field used to carry an
		-- "enter saves" hint, which is the interface explaining itself. It
		-- saves when you leave it, the way the note panel does, so there is
		-- nothing left to explain.
		-- the note belongs to whoever the card showed when you started
		-- typing, whatever the card shows by the time you leave the box
		card.noteBox:SetScript("OnEditFocusGained", function(self)
			self.forKey = card.key
		end)
		card.noteBox:SetScript("OnEditFocusLost", function(self)
			local key = self.forKey or card.key
			self.forKey = nil
			B.SaveText(key, self:GetText())
		end)
		card.noteBox:Hide()
		card:SetScript("OnClick", function(self)
			if not self.key then
				return
			end
			-- a second click on the open row closes it, so the list can be
			-- read without anything expanded
			B.Select(self.key ~= selected and self.key or nil)
		end)
		card:Hide()
		cards[i] = card
	end

	emptyLine = label(findView, "", "small", 0.45, 0.5, 0.48)
	emptyLine:SetPoint("TOPLEFT", 20, -(CARDS_TOP + 6))
	emptyLine:SetWidth(600)
	emptyLine:SetJustifyH("LEFT")
	moreLine = label(findView, "", "small", 0.45, 0.5, 0.48)
	moreLine:SetPoint("TOPLEFT", 20, -(CARDS_TOP + CARDS * CARD_RICH))

	editor = buildEditor(UIParent, panel, label, paint)
	B.RebuildTags()
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(1, B.Tick)
	end
	return findView
end

-- The bar writes on your target with no window open, so the editor has to
-- exist before the tab has ever been looked at.
function B.EnsureBuilt()
	BT.Window.Build()
	if not panel then
		-- built, not shown: asking for the note panel must not open the window
		BT.Window.BuildPanel("ledger")
	end
	return panel
end

function B.CardNoteBox(card)
	return card and card.noteBox
end

-- the filter row and which tag it is filtering by, for the tests
function B.FilterButtons()
	return findView and findView.tagButtons or {}
end

function B.TagFilter()
	return state.tagFilter
end

-- the "My notes" button, for the tests
function B.MineButton()
	return findView and findView.mineButton
end

-- who the panel is open on
function B.Selected()
	return selected
end

-- /bt find <text>: open the Ledger on a search, whatever was on screen.
function B.Search(text)
	BT.Window.Show("ledger")
	if text and searchBox then
		searchBox:SetText(text)
	end
	B.Refresh()
end

function B.Panel()
	return panel
end
