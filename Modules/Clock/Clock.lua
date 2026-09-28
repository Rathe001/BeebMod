-- Clock: the time, in the panel's header (Josh 2026-09-22).
--
-- Local time or the realm's, and a click on it swaps them; which one it
-- shows is remembered. A letter after the time says which: a green L for
-- local, a blue S for the server. Twelve or twenty-four hours follows the client's own
-- clock setting, so it reads the same as the time anywhere else in the game.
-- Point at it for both.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Clock/Clock.lua")

local U = BT.Util

local M = BT.Module({
	key = "clock",
	feature = "dock",
	title = "Clock",
	blurb = "Local or server time. Click it to switch.",
	order = 4,
	-- NOT A TAB (Josh 2026-09-22): it lives in the header, where there is
	-- nothing to move, so it is a switch on the Settings page like the Census
	standalone = true,
	kind = "header",
})

-- the minute changes on its own schedule; a few seconds late is never noticed
local EVERY = 5

-- the letter after the time: which clock it is
M.MARK = { ["local"] = "|cff69db7cL|r", server = "|cff74c0fcS|r" }

-- which one: "local" unless you have clicked it to "server"
function M.Which()
	return (BT.settings and BT.settings.clockServer) and "server" or "local"
end

function M.Toggle()
	BT.EnsureBound()
	BT.settings.clockServer = not BT.settings.clockServer
	M.Update()
	return M.Which()
end

-- the client's own twelve-or-twenty-four setting
local function military()
	if type(GetCVarBool) == "function" then
		local ok, on = pcall(GetCVarBool, "timeMgrUseMilitaryTime")
		if ok then
			return on and true or false
		end
	end
	local get = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
	if type(get) == "function" then
		local ok, v = pcall(get, "timeMgrUseMilitaryTime")
		if ok and v ~= nil then
			return v == "1"
		end
	end
	return false
end

-- hours and minutes, local or the realm's
function M.Now(which)
	if which == "server" and type(GetGameTime) == "function" then
		local ok, h, m = pcall(GetGameTime)
		if ok and h then
			return h, m or 0
		end
	end
	local t = date("*t")
	return t.hour, t.min
end

function M.Format(h, m, twentyFour)
	if twentyFour then
		return ("%02d:%02d"):format(h, m)
	end
	local suffix = h < 12 and "am" or "pm"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return ("%d:%02d%s"):format(h12, m, suffix)
end

function M.Text(which)
	which = which or M.Which()
	local h, m = M.Now(which)
	return M.Format(h, m, military())
end

function M.Update()
	if not M.frame then
		return
	end
	M.time:SetText(M.Label())
	-- as wide as what it says, so the header can lay it against its edge
	-- through Pill.Number: a measurement can come back secret on this client
	M.frame:SetWidth(math.max(20, BT.Pill.Number(M.time:GetStringWidth(), 40) + 2))
end

-- "9:21am L": the time, and which clock
function M.Label(which)
	which = which or M.Which()
	return M.Text(which) .. " " .. M.MARK[which]
end

-- when this session began: the login, or the last reload
M.since = type(time) == "function" and time() or nil

-- (Josh 2026-09-27, the dock's tooltips redrawn) both clocks side by side,
-- the header's lit, the date, and how long you have played
function M.Tip()
	if not BT.Tip then
		return
	end
	BT.Tip.Show(M.frame, { build = function(t)
		local day = type(date) == "function" and date("%A %d %B") or nil
		t:Header({ name = "Clock", sub = day and (day:gsub(" 0", " ")) or nil })
		local which = M.Which()
		t:Stats({
			{ M.Text("local"), which == "local" and "local, in the header" or "local", nil, which == "local" },
			{ M.Text("server"), which == "server" and "server, in the header" or "server", nil, which == "server" },
		}, 16)
		if M.since and type(time) == "function" then
			t:Note(("Played this session: %s."):format(BT.Session.Duration(time() - M.since)))
		end
		t:Foot({ { "Click", which == "local" and "show server time instead" or "show local time instead" } })
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Bar.HeaderItem(CreateFrame("Button", nil, UIParent))
	M.frame:SetSize(60, 18)
	-- THE HEADER'S SIZE, NOT THE SMALL PRINT (Josh 2026-09-22): the time is
	-- one of the things you glance at, so it reads at the size of the name
	-- beside it, in the panel's own light text rather than the font's gold
	M.time = BT.Widgets.Label(M.frame, "", nil, 0.86, 0.88, 0.92)
	M.time:SetPoint("RIGHT", M.frame, "RIGHT", 0, 0)
	M.time:SetJustifyH("RIGHT")
	M.frame:EnableMouse(true)
	M.frame:SetScript("OnMouseUp", function()
		M.Toggle()
		-- the tooltip says both; redrawn so it is not a click behind
		if BT.Tip and BT.Tip.IsShown() then
			M.Tip()
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

function M.Show(on)
	local frame = M.Build()
	if on then
		frame:Show()
		M.Update()
		if not M.ticker and C_Timer and C_Timer.NewTicker then
			M.ticker = C_Timer.NewTicker(EVERY, function()
				if BT.Enabled("clock") then
					M.Update()
				end
			end)
		end
	else
		frame:Hide()
		if M.ticker then
			M.ticker:Cancel()
			M.ticker = nil
		end
	end
	BT.Bar.Relayout()
end

function M:OnEnable()
	M.Show(true)
end

-- a book bound (a login, a loading screen) is the same setup
M.OnBind = M.OnEnable

function M:OnDisable()
	M.Show(false)
end
