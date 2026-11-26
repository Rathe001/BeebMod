-- Chat text that stays (Josh 2026-11-23: "Any idea why my chat text randomly
-- disappears? ... Comes back if I scroll", then 2026-11-25, two screenshots
-- of the same window: "Still seeing blank chat ... Seems to happen randomly").
--
-- The game fades a chat line out two minutes after it arrives, while the
-- window is scrolled to the bottom. That is the one way its chat window
-- hides a line that has text (Blizzard_SharedXML/ScrollingMessageFrame.lua,
-- RefreshDisplay and UpdateFading). Scrolling shows every line again, which
-- is what Josh saw.
--
-- His screenshots do not look like a plain fade: older lines stayed while
-- newer ones between them were gone. Why is not known. With fading off the
-- game shows every line whatever its age, so the blanks cannot come from
-- that code. M.Status counts lines that have text and are hidden all the
-- same, for What loaded, in case they come from somewhere else.
--
-- Each window's own setting is kept and put back when this is switched off.
-- The game turns fading back on when a controller leaves the chat window
-- (FloatingChatFrameMixin:UnfocusGamepad). Each window's SetFading is
-- followed, and turned off again while this is on.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Chat/Fading.lua")

local M = BT.Module({
	key = "chatfade",
	title = "Chat text stays",
	order = 99.5,
})
BT.ChatFade = M

-- [frame] = whether it faded before
M.home = setmetatable({}, { __mode = "k" })
M.hooked = setmetatable({}, { __mode = "k" })
M.again = 0

-- one chat window: its text stays (`on`), or as it was
function M.Set(frame, on)
	if not (type(frame) == "table" and type(frame.SetFading) == "function") then
		return false
	end
	if on then
		if M.home[frame] == nil then
			local ok, was = pcall(function() return frame.GetFading and frame:GetFading() end)
			-- (the game's own setting for a chat window where it cannot be read)
			-- (an if, not "and was or true": that gave true for a window that
			-- did not fade, and switching this off then made it fade; the code
			-- review, 2026-11-26)
			if ok and type(was) == "boolean" then
				M.home[frame] = was
			else
				M.home[frame] = true
			end
		end
		if not M.hooked[frame] and type(hooksecurefunc) == "function" then
			M.hooked[frame] = true
			pcall(hooksecurefunc, frame, "SetFading", function(self, fades)
				if fades and not M.setting and M.home[self] ~= nil and BT.Enabled("chatfade") then
					M.again = M.again + 1
					M.setting = true
					pcall(self.SetFading, self, false)
					M.setting = nil
				end
			end)
		end
		M.setting = true
		local ok = pcall(frame.SetFading, frame, false)
		M.setting = nil
		return ok
	end
	local was = M.home[frame]
	if was == nil then
		return false
	end
	M.home[frame] = nil
	M.setting = true
	local ok = pcall(frame.SetFading, frame, was)
	M.setting = nil
	return ok
end

function M.Frames()
	local chat = BT.GetModule and BT.GetModule("chat")
	return chat and chat.Frames and chat.Frames() or {}
end

function M.All(on)
	local n = 0
	for _, frame in ipairs(M.Frames()) do
		if M.Set(frame, on) then
			n = n + 1
		end
	end
	return n
end

M.events = CreateFrame("Frame")
pcall(M.events.RegisterEvent, M.events, "PLAYER_ENTERING_WORLD")
pcall(M.events.RegisterEvent, M.events, "UPDATE_CHAT_WINDOWS")
M.events:SetScript("OnEvent", function()
	if BT.Enabled("chatfade") then
		M.All(true)
	end
end)

function M:OnEnable()
	M.All(true)
end

M.OnBind = M.OnEnable

function M:OnDisable()
	M.All(false)
end

-- a window's lines as the game has them drawn: how many are on screen, and
-- how many have text and are hidden all the same
function M.Lines(frame)
	local shown, hidden = 0, 0
	local lines = type(frame) == "table" and frame.visibleLines
	if type(lines) ~= "table" then
		return nil
	end
	for _, line in ipairs(lines) do
		if type(line) == "table" and line.messageInfo ~= nil then
			local ok, up, alpha = pcall(function() return line:IsShown(), line:GetAlpha() end)
			if ok and up and (type(alpha) ~= "number" or alpha > 0) then
				shown = shown + 1
			else
				hidden = hidden + 1
			end
		end
	end
	return shown, hidden
end

-- for What loaded, on the Testing page
function M.Status()
	local parts = {}
	for i, frame in ipairs(M.Frames()) do
		local okV, visible = pcall(function() return frame:IsVisible() end)
		if okV and visible then
			local okF, fades = pcall(function() return frame:GetFading() end)
			local shown, hidden = M.Lines(frame)
			parts[#parts + 1] = ("window %d fading %s, %s"):format(i, okF and tostring(fades) or "unreadable",
				shown and ("%d lines on screen, %d with text hidden"):format(shown, hidden) or "lines unreadable")
		end
	end
	return ("%s · turned off again %d times"):format(#parts > 0 and table.concat(parts, " · ") or "no chat window on screen", M.again)
end
