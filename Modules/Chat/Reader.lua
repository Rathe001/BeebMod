-- The chat in a large window (Josh 2026-09-29: "Can we add a button that
-- opens the chat in a large modal?").
--
-- The expand mark in a chat window's corner opens it. It shows every line
-- that window still holds, in the window's own colours and text size, and
-- new lines as they arrive. Links in it work as they do in chat: an item
-- shows its tooltip, a name opens its menu, a web address opens the copy
-- box. The wheel scrolls, Shift and the wheel go to the top or the newest
-- line, Ctrl and the wheel go a page at a time, and Escape closes it.
--
-- SELECT TEXT (Josh 2026-09-29: "Big chat window should have selectable text
-- so the user can copy it"). The game can't select text in a chat frame, only
-- in a box you type in. So the Select text button swaps the lines for such a
-- box, holding the same lines as plain words: no colours, and each link as
-- the words it shows. Drag to select, Ctrl+A for all of it, Ctrl+C to copy.
-- Pressed again, the button brings the chat back, with any lines that came
-- in meanwhile.
--
-- It reads the chat window's own history and adds nothing to it: close it
-- and the chat window is as it was.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Chat/Reader.lua")

local M = BT.GetModule("chat")
local W = BT.Widgets

local R = {}
BT.ChatReader = R

local PAD, TITLE_H = 14, 40
local WIDTH, HEIGHT = 820, 540
-- a window holds a few hundred lines; the copy keeps at least this many, so
-- it has room for what arrives while it is open
local KEEP = 1000

local frame

local function N(v, fallback)
	return BT.Pill.Number(v, fallback)
end

function R.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "BeebModChatReader", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 0, 40)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	W.PixelDrag(frame)
	frame:SetClampedToScreen(true)
	W.Panel(frame, W.SOLID)
	tinsert(UISpecialFrames, "BeebModChatReader") -- escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "BeebModFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", PAD + 4, -PAD)
	frame.title:SetText("Chat")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

	frame.close = W.Close(frame, 20)
	frame.close:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.close:SetScript("OnClick", function() R.Hide() end)

	frame.select = W.Button(frame, "Select text", 86, 20)
	frame.select:SetPoint("RIGHT", frame.close, "LEFT", -10, 0)
	frame.select:SetScript("OnClick", function() R.SetSelecting(not R.selecting) end)
	frame.hint = frame:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
	frame.hint:SetPoint("RIGHT", frame.select, "LEFT", -10, 0)
	frame.hint:SetText("Drag to select. Ctrl+A selects all, Ctrl+C copies.")
	frame.hint:Hide()

	W.Divider(frame, PAD, -TITLE_H)

	local msgs = CreateFrame("ScrollingMessageFrame", nil, frame)
	msgs:SetPoint("TOPLEFT", PAD + 4, -TITLE_H - 10)
	msgs:SetPoint("BOTTOMRIGHT", -PAD - 4, PAD)
	msgs:SetFading(false)
	msgs:SetJustifyH("LEFT")
	msgs:SetMaxLines(KEEP)
	msgs:SetHyperlinksEnabled(true)
	msgs:EnableMouseWheel(true)
	msgs:SetScript("OnMouseWheel", function(self, delta)
		if IsShiftKeyDown and IsShiftKeyDown() then
			if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
		elseif IsControlKeyDown and IsControlKeyDown() then
			if delta > 0 then self:PageUp() else self:PageDown() end
		elseif delta > 0 then
			self:ScrollUp()
		else
			self:ScrollDown()
		end
	end)
	-- a link does what it does in the chat window it came from: the menu on
	-- a name needs that window, not this one
	msgs:SetScript("OnHyperlinkClick", function(_, link, text, button)
		if type(SetItemRef) == "function" then
			SetItemRef(link, text, button, R.source or _G.DEFAULT_CHAT_FRAME)
		end
	end)
	frame.msgs = msgs
	M.Newest(msgs)

	-- the box you select in, where the lines were
	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", PAD + 4, -TITLE_H - 10)
	scroll:SetPoint("BOTTOMRIGHT", -PAD - 4, PAD)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(WIDTH - 2 * (PAD + 4))
	pcall(edit.SetFontObject, edit, "BeebModFontHighlightSmall")
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = N(self:GetVerticalScrollRange(), 0)
		local at = N(self:GetVerticalScroll(), 0) - delta * 42
		self:SetVerticalScroll(math.max(0, math.min(range, at)))
	end)
	-- the client's own way to keep the cursor in view while you drag past
	-- the edge of the box
	if type(_G.ScrollingEdit_OnCursorChanged) == "function" then
		edit:SetScript("OnCursorChanged", _G.ScrollingEdit_OnCursorChanged)
	end
	if type(_G.ScrollingEdit_OnUpdate) == "function" then
		edit:SetScript("OnUpdate", function(self, elapsed)
			_G.ScrollingEdit_OnUpdate(self, elapsed, scroll)
		end)
	end
	-- the words can be selected, not changed: a key that changes them puts
	-- them back
	edit:SetScript("OnTextChanged", function(self, typed)
		if typed and R.text and self:GetText() ~= R.text then
			self:SetText(R.text)
		end
	end)
	edit:SetScript("OnEscapePressed", function() R.Hide() end)
	scroll:Hide()
	frame.scroll, frame.edit = scroll, edit

	-- closed any way, by Escape too: stop copying new lines into it, and
	-- open on the chat next time
	frame:SetScript("OnHide", function()
		R.source = nil
		R.SetSelecting(false)
	end)
	frame:Hide()
	return frame
end

-- which end of a window's history is the newest line. The client's own
-- order is not written down anywhere an addon can read, so it is worked out
-- from the last line the chat module saw go in (Modules/Chat/Chat.lua keeps
-- it as beebsLast). With nothing to go on, the first line is the oldest.
function R.NewestFirst(src, n)
	if n < 2 or src.beebsLast == nil then
		return false
	end
	local ok, first = pcall(function()
		local a = src:GetMessageInfo(1)
		local z = src:GetMessageInfo(n)
		return a == src.beebsLast and z ~= src.beebsLast
	end)
	return ok and first or false
end

function R.Fill(src)
	local msgs = R.Build().msgs
	msgs:Clear()
	if not (src and src.GetNumMessages and src.GetMessageInfo) then
		return 0
	end
	local n = N(src:GetNumMessages(), 0)
	msgs:SetMaxLines(math.max(KEEP, n))
	local from, to, step = 1, n, 1
	if R.NewestFirst(src, n) then
		from, to, step = n, 1, -1
	end
	local added = 0
	for i = from, to, step do
		local ok, text, r, g, b = pcall(src.GetMessageInfo, src, i)
		if ok and text ~= nil then
			msgs:AddMessage(text, r, g, b)
			added = added + 1
		end
	end
	msgs:ScrollToBottom()
	return added
end

-- A line as plain words: a link is the words it shows, and colours,
-- pictures and the game's other escapes are gone. "||" is the one bar a
-- player typed.
function R.Plain(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		return nil
	end
	local ok, out = pcall(function()
		return (text:gsub("|H.-|h(.-)|h", "%1")
			:gsub("|c%x%x%x%x%x%x%x%x", "")
			:gsub("|cn[^:]*:", "")
			:gsub("|r", "")
			:gsub("|T.-|t", "")
			:gsub("|A.-|a", "")
			:gsub("|K.-|k", "")
			:gsub("||", "|"))
	end)
	return ok and out or nil
end

-- every line the large window holds, as plain words, one a line; a line
-- the game keeps secret is left out, as it can't be read
function R.PlainText()
	local msgs = R.Build().msgs
	local lines = {}
	for i = 1, N(msgs:GetNumMessages(), 0) do
		local plain = R.Plain((msgs:GetMessageInfo(i)))
		if plain then
			lines[#lines + 1] = plain
		end
	end
	return table.concat(lines, "\n")
end

function R.SetSelecting(on)
	on = on and true or false
	R.selecting = on
	if not frame then
		return on
	end
	frame.select:SetPressed(on)
	frame.hint:SetShown(on)
	frame.msgs:SetShown(not on)
	frame.scroll:SetShown(on)
	local edit = frame.edit
	if on then
		R.text = R.PlainText()
		edit:SetText(R.text)
		-- at the newest line, as the chat was
		edit:SetFocus()
		edit:SetCursorPosition(#R.text)
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				frame.scroll:SetVerticalScroll(N(frame.scroll:GetVerticalScrollRange(), 0))
			end)
		end
	else
		R.text = nil
		edit:ClearFocus()
		edit:SetText("")
	end
	return on
end

-- a line the chat window has just taken, while this shows that window
function R.Add(text, r, g, b)
	if frame and frame:IsShown() and text ~= nil then
		frame.msgs:AddMessage(text, r, g, b)
		if frame.msgs.beebsNewest then
			frame.msgs.beebsNewest.Update()
		end
	end
end

-- the window's name, as its tab shows it
local function tabName(src)
	local name = src and src.GetName and src:GetName()
	local tab = name and _G[name .. "Tab"]
	local text = tab and (tab.Text or _G[name .. "TabText"])
	local word = text and text.GetText and text:GetText()
	if type(word) == "string" and word ~= "" then
		return word
	end
	return ""
end

function R.Open(src)
	src = src or _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
	if not src then
		return false
	end
	local f = R.Build()
	-- the chat window's text size, whatever it was set to
	if src.GetFont then
		local face, size, flags = src:GetFont()
		if face and size then
			pcall(f.msgs.SetFont, f.msgs, face, size, flags)
		end
	end
	f.subtitle:SetText(tabName(src))
	R.source = src
	f:Show()
	f:Raise()
	R.Fill(src)
	return true
end

function R.Hide()
	if frame then
		frame:Hide()
	end
	R.source = nil
	R.SetSelecting(false)
end

function R.Toggle(src)
	if frame and frame:IsShown() and R.source == (src or R.source) then
		R.Hide()
		return false
	end
	return R.Open(src)
end

function R.Frame()
	return frame
end
