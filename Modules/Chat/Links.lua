-- Guild names in green, and web addresses you can click (Josh 2026-09-29).
--
-- Both change the TEXT of a line as it is added, as the short channel names
-- do, and nothing else: no line is dropped or moved. The chat module calls
-- M.Decorate from its AddMessage (Modules/Chat/Chat.lua).
--
--   a guild     "<New Horizon> is recruiting" - the name in angle brackets,
--               in the guild chat's green, as a guild reads on a tooltip;
--               clicking it types a /who for the guild into the chat box
--   an address  "www.gofundme.com/f/x" becomes a link; clicking it opens a
--               box with the address in it, selected, to copy with Ctrl+C
--
-- Only the words of a line are looked at. A link, a colour, a texture or any
-- other escape in it is copied across exactly as it came, so an item link
-- that happens to hold a dot or a bracket is never touched.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Chat/Links.lua")

local M = BT.GetModule("chat")
local W = BT.Widgets

local function opt(name, fallback)
	return M.Opt(name, fallback)
end

-- ---------------------------------------------------------------------------
-- The words of a line
-- ---------------------------------------------------------------------------

-- where an escape that starts at `bar` ends: |H data |h text |h is a link,
-- |c is a colour (eight digits, or a name up to a colon), |T, |A and |K run
-- to their closing letter, and anything else (|r, |n, ||) is two characters
local function escapeEnd(text, bar, n)
	local c = text:sub(bar + 1, bar + 1)
	if c == "H" then
		local a = text:find("|h", bar + 2, true)
		local b = a and text:find("|h", a + 2, true)
		return b and b + 1 or n
	elseif c == "c" then
		if text:sub(bar + 2, bar + 2) == "n" then
			local colon = text:find(":", bar + 3, true)
			return colon or n
		end
		return math.min(bar + 9, n)
	elseif c == "T" or c == "A" or c == "K" then
		local close = text:find("|" .. c:lower(), bar + 2, true)
		return close and close + 1 or n
	end
	return math.min(bar + 1, n)
end

-- each run of plain words through fn, every escape copied as it is
function M.EachPlain(text, fn)
	local out, i, n = {}, 1, #text
	while i <= n do
		local bar = text:find("|", i, true)
		if not bar then
			out[#out + 1] = fn(text:sub(i))
			break
		end
		if bar > i then
			out[#out + 1] = fn(text:sub(i, bar - 1))
		end
		local stop = escapeEnd(text, bar, n)
		out[#out + 1] = text:sub(bar, stop)
		i = stop + 1
	end
	return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- Guild names
-- ---------------------------------------------------------------------------

-- the game's own flags, which are in angle brackets too: <AFK>, <DND>, <GM>
local FLAGS = { afk = true, dnd = true, away = true, busy = true, gm = true, dev = true }

-- A guild name is letters and spaces, 2 to 24 of them, and starts with a
-- letter. That keeps out "<3", "<- look" and the flags above. Letters past
-- ASCII count, for a name such as "Café Noir".
local LETTER = "[%a\128-\255]"
function M.IsGuildName(name)
	if type(name) ~= "string" or #name < 2 or #name > 24 then
		return false
	end
	if not name:find("^" .. LETTER) or not name:find("^[%a\128-\255 ]+$") or name:find("%s$") then
		return false
	end
	if FLAGS[name:lower()] then
		return false
	end
	for _, flag in ipairs({ _G.CHAT_FLAG_AFK, _G.CHAT_FLAG_DND, _G.CHAT_FLAG_GM }) do
		if type(flag) == "string" and flag == "<" .. name .. ">" then
			return false
		end
	end
	return true
end

M.GUILD_LINK = "addon:BeebMod:guild:"

-- the guild chat's green, the one a guild wears on a tooltip, and a link:
-- a click puts a /who for the guild in the chat box (M.WhoGuild)
local function greenGuild(inside)
	if M.IsGuildName(inside) then
		local T = BT.GetModule("tooltips")
		return ((T and T.GUILD) or "|cff40ff40%s|r"):format(
			"|H" .. M.GUILD_LINK .. inside .. "|h<" .. inside .. ">|h")
	end
	return nil
end

local function guilds(words)
	return (words:gsub("<([^<>]+)>", greenGuild))
end

-- ---------------------------------------------------------------------------
-- Web addresses
-- ---------------------------------------------------------------------------

-- the endings an address without http:// or www. must have to count, so
-- "e.g." or "Tweak.lua" stays a word
local TLD = {}
for t in ([[com net org io gg tv me co uk de fr eu info app dev xyz us ca au
nl ru pl se es it be ch at nz ly]]):gmatch("%S+") do
	TLD[t] = true
end

M.LINK = "addon:BeebMod:url:"
-- a web link's blue, apart from the guild's green and the game's item colours
M.LINK_COLOUR = "|cff6fb7ff"

function M.IsAddress(word)
	if type(word) ~= "string" or word == "" then
		return false
	end
	if word:find("^[Hh][Tt][Tt][Pp][Ss]?://[%w%-]") then
		return true
	end
	if word:find("^[Ww][Ww][Ww]%.[%w%-]+%.%a") then
		return true
	end
	-- a bare name.ending, then a path or nothing: gofundme.com/f/x
	local host = word:match("^([%w%-%.]+)[/:]") or word:match("^([%w%-%.]+)$")
	if not host or host:find("%.%.") then
		return false
	end
	local name, tld = host:match("^([%w%-%.]*%w)%.(%a+)$")
	return name ~= nil and name:find("%a") ~= nil and TLD[tld:lower()] == true
end

-- the brackets and full stops round an address are the sentence's, not the
-- address's: "(see www.x.com)." links www.x.com
local function address(word)
	local lead, core, trail = word:match("^([%(%[\"']*)(.-)([%.,;:!%?%)%]\"']*)$")
	if not core or not M.IsAddress(core) then
		return word
	end
	return lead .. M.LINK_COLOUR .. "|H" .. M.LINK .. core .. "|h" .. core .. "|h|r" .. trail
end

local function addresses(words)
	return (words:gsub("%S+", address))
end

-- ---------------------------------------------------------------------------
-- A line
-- ---------------------------------------------------------------------------

function M.Decorate(text)
	if type(text) ~= "string" then
		return text
	end
	-- a secret line is left alone, as the short channel names leave it
	if issecretvalue and issecretvalue(text) then
		return text
	end
	local green, links = opt("guilds", true), opt("links", true)
	if not (green or links) or not (text:find("<", 1, true) or text:find(".", 1, true)) then
		return text
	end
	local ok, out = pcall(M.EachPlain, text, function(words)
		if green then
			words = guilds(words)
		end
		if links then
			-- the guild's colour is an escape now, so the address pass skips
			-- it; run on the pieces between
			words = M.EachPlain(words, addresses)
		end
		return words
	end)
	return ok and out or text
end

-- ---------------------------------------------------------------------------
-- The box you copy from
-- ---------------------------------------------------------------------------

local PAD = 14
local box

local function build()
	if box then
		return box
	end
	box = CreateFrame("Frame", "BeebModCopyLink", UIParent)
	box:SetSize(460, 104)
	box:SetPoint("CENTER", 0, 120)
	box:SetFrameStrata("DIALOG")
	box:SetToplevel(true)
	box:SetMovable(true)
	box:EnableMouse(true)
	W.PixelDrag(box)
	box:SetClampedToScreen(true)
	W.Panel(box, W.SOLID)
	tinsert(UISpecialFrames, "BeebModCopyLink") -- escape closes it

	box.title = box:CreateFontString(nil, "OVERLAY", "BeebModFontNormal")
	box.title:SetPoint("TOPLEFT", PAD + 2, -PAD)
	box.title:SetText("Copy link")
	box.close = W.Close(box, 18)
	box.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 4)
	box.close:SetScript("OnClick", function() box:Hide() end)

	local field = CreateFrame("Frame", nil, box)
	field:SetPoint("TOPLEFT", PAD, -PAD - 24)
	field:SetPoint("TOPRIGHT", -PAD, -PAD - 24)
	field:SetHeight(24)
	W.Panel(field, W.FILL, W.HAIR)
	local edit = CreateFrame("EditBox", nil, field)
	edit:SetPoint("TOPLEFT", 8, 0)
	edit:SetPoint("BOTTOMRIGHT", -8, 0)
	edit:SetAutoFocus(false)
	pcall(edit.SetFontObject, edit, "BeebModFontHighlightSmall")
	box.edit = edit

	box.hint = W.Label(box, "Press Ctrl+C to copy it, then Escape to close this box.", "small", 0.62, 0.68, 0.65)
	box.hint:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 2, -8)

	-- the address can't be typed over: a key that changes it puts it back,
	-- selected, so Ctrl+C still copies all of it
	edit:SetScript("OnTextChanged", function(self, typed)
		if typed and box.url and self:GetText() ~= box.url then
			self:SetText(box.url)
			self:HighlightText()
		end
	end)
	edit:SetScript("OnEscapePressed", function() box:Hide() end)
	edit:SetScript("OnEnterPressed", function() box:Hide() end)
	edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnHide", function() edit:ClearFocus() end)
	box:Hide()
	return box
end

function M.CopyBox()
	return box
end

function M.ShowLink(url)
	if type(url) ~= "string" or url == "" then
		return false
	end
	local b = build()
	b.url = url
	b:Show()
	b:Raise()
	b.edit:SetText(url)
	b.edit:SetFocus()
	-- the start of a long address in view, and all of it selected
	b.edit:SetCursorPosition(0)
	b.edit:HighlightText()
	return true
end

-- what follows `prefix` in one of our links, or nil for any other link
local function after(link, prefix)
	if type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then
		return nil
	end
	local rest = link:sub(1, #prefix) == prefix and link:sub(#prefix + 1) or nil
	return rest ~= "" and rest or nil
end

function M.LinkAddress(link)
	return after(link, M.LINK)
end

function M.LinkGuild(link)
	return after(link, M.GUILD_LINK)
end

-- ---------------------------------------------------------------------------
-- A guild's /who
-- ---------------------------------------------------------------------------

-- THE /who IS TYPED FOR YOU, NOT SENT (Josh 2026-09-29: "Can we make the
-- guild names clickable to open '/who Unbroken Titans'"). This client won't
-- let an addon send a /who (README, "No /who"), so a click opens the chat
-- box with the command in it and you press Enter. g-"..." asks for that
-- guild alone; a bare /who Unbroken Titans also finds anyone named Titan.
function M.WhoText(guild)
	return '/who g-"' .. guild .. '"'
end

function M.WhoGuild(guild)
	if type(guild) ~= "string" or guild == "" then
		return false
	end
	local text = M.WhoText(guild)
	local util = _G.ChatFrameUtil
	local open = (type(util) == "table" and type(util.OpenChat) == "function" and util.OpenChat)
		or _G.ChatFrame_OpenChat
	if type(open) == "function" and pcall(open, text) then
		return true
	end
	-- a build with neither: the main window's own box, opened by hand
	local frame = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
	local box = frame and (frame.editBox or _G[(frame.GetName and frame:GetName() or "") .. "EditBox"])
	if box and box.SetText then
		box:Show()
		box:SetFocus()
		box:SetText(text)
		return true
	end
	BT.Util.Print("Chat: type " .. text .. " to see who is in that guild.")
	return false
end

-- ---------------------------------------------------------------------------
-- The click
-- ---------------------------------------------------------------------------

-- A CLICK ON A LINK GOES TO SetItemRef, a guild's as well as an address's. The client passes a link that starts
-- "addon:" to addons through EventRegistry's "SetItemRef" event instead of
-- treating it as an item, which is why ours start "addon:BeebMod:". The hook
-- on SetItemRef itself is for a build that has no such event; opening the
-- box twice for one click shows the same address, so both may run. Neither
-- checks the switch: a link already in the window still opens after Clickable
-- links goes off, as the line was written with it.
local function clicked(...)
	for i = 1, select("#", ...) do
		local link = (select(i, ...))
		local url = M.LinkAddress(link)
		if url then
			M.ShowLink(url)
			return true
		end
		local guild = M.LinkGuild(link)
		if guild then
			M.WhoGuild(guild)
			return true
		end
	end
	return false
end
M.Clicked = clicked

function M.WatchClicks()
	if M.clicksWatched then
		return true
	end
	M.clicksWatched = true
	local registry = _G.EventRegistry
	if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
		pcall(registry.RegisterCallback, registry, "SetItemRef", function(...)
			if BT.Enabled("chat") then
				clicked(...)
			end
		end, M)
	end
	if hooksecurefunc and type(_G.SetItemRef) == "function" then
		pcall(hooksecurefunc, "SetItemRef", function(link)
			if BT.Enabled("chat") then
				clicked(link)
			end
		end)
	end
	return true
end

M.WatchClicks()
