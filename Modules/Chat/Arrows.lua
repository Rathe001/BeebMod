-- Arrow keys in the chat box (Josh 2026-11-24: "Arrow keys on typing chat no
-- longer seem to work", then "Yes please add that").
--
-- The game's chat box leaves the plain arrow keys to your character. Only
-- Alt with an arrow moves the cursor or goes through what you typed before
-- (an edit box's "alt arrow key mode", on for the chat box). Prat, Leatrix
-- Plus and ElvUI turn that mode off. This does the same.
--
-- Each box's own mode is kept and put back when this is switched off. A chat
-- window made later (a whisper in a window of its own) is done when its box
-- is opened: the game's ChatEdit_ActivateChat is followed. The game's name
-- completion sets the mode itself while its list is up and puts back what it
-- found (Blizzard_AutoComplete/AutoComplete.lua), which is ours.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Chat/Arrows.lua")

local M = BT.Module({
	key = "chatarrows",
	title = "Arrow keys in the chat box",
	order = 99.4,
})
BT.ChatArrows = M

-- [box] = the mode it had before
M.home = setmetatable({}, { __mode = "k" })
M.set = 0

-- one chat box: plain arrows for the text (`on`), or as it was
function M.Set(box, on)
	if not (type(box) == "table" and type(box.SetAltArrowKeyMode) == "function") then
		return false
	end
	if on then
		if M.home[box] == nil then
			local ok, was = pcall(function() return box.GetAltArrowKeyMode and box:GetAltArrowKeyMode() end)
			-- (the game's own setting for a chat box where it cannot be read)
			M.home[box] = (ok and type(was) == "boolean") and was or true
		end
		if pcall(box.SetAltArrowKeyMode, box, false) then
			M.set = M.set + 1
			return true
		end
		return false
	end
	local was = M.home[box]
	if was == nil then
		return false
	end
	M.home[box] = nil
	return (pcall(box.SetAltArrowKeyMode, box, was))
end

-- every chat window's box
function M.Boxes()
	local out = {}
	local chat = BT.GetModule and BT.GetModule("chat")
	for _, frame in ipairs(chat and chat.Frames and chat.Frames() or {}) do
		local name = frame.GetName and frame:GetName()
		local box = type(name) == "string" and _G[name .. "EditBox"] or nil
		if type(box) == "table" then
			out[#out + 1] = box
		end
	end
	return out
end

function M.All(on)
	local n = 0
	for _, box in ipairs(M.Boxes()) do
		if M.Set(box, on) then
			n = n + 1
		end
	end
	return n
end

-- a box the game opens for typing: a window made since the last look
function M.Opened(box)
	if BT.Enabled("chatarrows") and type(box) == "table" and M.home[box] == nil then
		M.Set(box, true)
	end
end

function M.Hook()
	if M.hooked or type(hooksecurefunc) ~= "function" then
		return false
	end
	M.hooked = true
	if type(_G.ChatEdit_ActivateChat) == "function" then
		pcall(hooksecurefunc, "ChatEdit_ActivateChat", M.Opened)
	end
	local util = _G.ChatFrameUtil
	if type(util) == "table" and type(util.ActivateChat) == "function" then
		pcall(hooksecurefunc, util, "ActivateChat", M.Opened)
	end
	return true
end

M.events = CreateFrame("Frame")
pcall(M.events.RegisterEvent, M.events, "PLAYER_ENTERING_WORLD")
M.events:SetScript("OnEvent", function()
	if BT.Enabled("chatarrows") then
		M.All(true)
	end
end)

function M:OnEnable()
	M.Hook()
	M.All(true)
end

M.OnBind = M.OnEnable

function M:OnDisable()
	M.All(false)
end

-- for What loaded, on the Testing page
function M.Status()
	local held = 0
	for _ in pairs(M.home) do
		held = held + 1
	end
	return ("%d chat boxes take plain arrow keys"):format(held)
end
