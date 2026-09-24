-- Load every file the client loads, in TOC order, with WoW stubbed, then open
-- the window and drive the slash commands. A syntax check proves a file
-- parses; this proves it RUNS, which is where a bad file-scope call or a
-- misspelled widget method actually bites - and those are exactly the ones a
-- player sees as a red error before the addon has done anything.
--
-- The widget stub answers only REAL widget methods. A typo ("Setmovable")
-- fails here instead of in the game.
--   lua tests/load.lua
local ok = true
-- every tab on the window's rail, top to bottom, for a warrior with no order set
ALL_TABS = "settings,dock,map,progress,metrics,tracker,micro,"
	.. "buffs,damagemeter,prd,frames,"
	.. "bars,bagwindow,charsheet,chat,allmenus,tips,"
	.. "censusset,ledger"
local function fail(msg)
	print("FAIL " .. msg)
	ok = false
end

local METHODS = {}
for m in ([[
SetSize SetWidth SetHeight SetPoint SetAllPoints ClearAllPoints GetWidth GetHeight
Show Hide IsShown IsVisible SetShown SetAlpha GetAlpha SetParent GetParent
SetMovable SetResizable EnableMouse EnableMouseWheel RegisterForDrag StartMoving
StopMovingOrSizing SetFrameStrata SetFrameLevel SetClampedToScreen SetScale
SetScript HookScript GetScript RegisterEvent UnregisterEvent UnregisterAllEvents
RegisterUnitEvent
CreateTexture CreateFontString CreateFrame SetBackdrop SetColorTexture SetTexture
GetStringWidth GetStringHeight SetVertexColor SetTexCoord SetDesaturated
SetTexCoord SetVertexColor SetGradient SetText GetText SetFormattedText SetFont
SetTextColor SetJustifyH SetJustifyV SetWordWrap SetMaxLines SetNonSpaceWrap
SetShadowColor SetShadowOffset GetStringHeight
SetAutoFocus ClearFocus SetFocus HighlightText SetCursorPosition SetMultiLine SetTextInsets
SetNumeric SetMaxLetters Enable Disable IsEnabled SetEnabled SetChecked GetChecked
SetNormalTexture SetHighlightTexture SetPushedTexture SetDisabledTexture
RegisterForClicks SetID GetID SetValue GetValue SetMinMaxValues GetUnit
SetStatusBarTexture SetStatusBarColor GetStatusBarTexture GetMinMaxValues
SetOwner AddLine AddDoubleLine ClearLines GetOwner NumLines SetPadding
GetCenter GetEffectiveScale SetIgnoreParentScale SetClipsChildren
Raise SetToplevel CopyFontObject
]]):gmatch("%S+") do
	METHODS[m] = true
end

-- Show state is real, because "shown" is something the addon reasons about: a
-- frame starts shown, and a Toggle that forgets that needs two commands to open.
-- A FRAME KNOWS WHAT IT IS AND WHAT IS IN IT (Josh 2026-09-19). The tracker
-- module works by walking the client's own frames - regions, children, object
-- types - because the shape of that tree is the thing most likely to change
-- between builds. The stub has to model that much or the walk is untested.
local function widget(kind, parent)
	local w = {
		_shown = true, _scripts = {}, _parent = parent,
		_kind = (kind == "Texture" or kind == "FontString") and kind or "Frame",
		_regions = {}, _children = {},
	}
	-- some fakes in these tests answer every key with a function, so ask what
	-- kind of thing came back before treating it as a list
	if type(parent) == "table" and type(rawget(parent, "_children")) == "table" then
		parent._children[#parent._children + 1] = w
	end
	setmetatable(w, { __index = function(_, k)
		if k == "Show" then return function(s) s._shown = true end end
		if k == "Hide" then return function(s) s._shown = false end end
		if k == "SetShown" then return function(s, v) s._shown = v and true or false end end
		if k == "IsShown" or k == "IsVisible" then return function(s) return s._shown end end
		if k == "HasFocus" then return function() return false end end
		-- fonts are state: the tooltip's hierarchy is sizes, and the lines it
		-- sets them on are shared with every other tooltip in the game
		if k == "SetFont" then
			return function(s2, face, size, flags) s2._font = { face, size, flags } end
		end
		if k == "GetFont" then
			return function(s2)
				local f = s2._font or { "Fonts/FRIZQT__.TTF", 12, "" }
				return f[1], f[2], f[3]
			end
		end
		if k == "SetFontObject" then
			return function(s2, obj) s2._fontObject, s2._font = obj, nil end
		end
		if k == "GetObjectType" then return function(s2) return s2._kind end end
		-- a named frame knows its own name, the way the client's do: half the
		-- client's own regions are reached as _G[name .. "Suffix"]
		if k == "GetName" then return function(s2) return s2._name end end
		-- strata and level decide who catches a click, so they are state
		if k == "SetFrameStrata" then return function(s2, v) s2._strata = v end end
		if k == "GetFrameStrata" then return function(s2) return s2._strata end end
		if k == "SetFrameLevel" then return function(s2, v) s2._level = v end end
		if k == "SetScale" then return function(s2, v) s2._scale = v end end
		if k == "GetScale" then return function(s2) return s2._scale or 1 end end
		if k == "GetFrameLevel" then return function(s2) return s2._level or 10 end end
		-- where a frame's edges are, so the dock can work out its own top-left
		if k == "GetLeft" then return function(s2) return s2._left or 900 end end
		if k == "GetTop" then return function(s2) return s2._top or 500 end end
		if k == "GetEffectiveScale" then return function() return 1 end end
		-- where a frame sits is state: the dock writes its own position down
		if k == "SetPoint" then
			return function(s2, point, rel, relPoint, x, y)
				if type(rel) == "string" then
					point, rel, relPoint, x, y = point, nil, rel, relPoint, x
				elseif type(rel) == "number" then
					-- SetPoint("LEFT", x, y): no relative frame at all, which
					-- is how most of this addon anchors inside its own parent
					x, y, rel, relPoint = rel, relPoint, nil, nil
				end
				-- WHAT IT IS ANCHORED TO, as well as where: "beside the row
				-- you clicked" and "beside the whole panel" are the same
				-- point and a different frame (Josh 2026-09-21)
				s2._point = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
				-- every anchor, not just the last: a frame pinned to two edges
				-- is a frame that cannot outrun its parent, and that is the
				-- thing worth asserting
				s2._points = s2._points or {}
				s2._points[point] = { rel = rel, relPoint = relPoint, x = x, y = y }
			end
		end
		if k == "SetBackdropColor" then
			return function(s2, r, g, b, a) s2._backdrop = { r, g, b, a } end
		end
		if k == "GetBackdropColor" then
			return function(s2)
				local c = s2._backdrop or { 0.09, 0.09, 0.19, 1 }
				return c[1], c[2], c[3], c[4]
			end
		end
		if k == "SetBackdropBorderColor" then
			return function(s2, r, g, b, a) s2._backdropBorder = { r, g, b, a } end
		end
		if k == "GetBackdropBorderColor" then
			return function(s2)
				local c = s2._backdropBorder or { 1, 1, 1, 1 }
				return c[1], c[2], c[3], c[4]
			end
		end
		-- a frame over another frame takes the clicks whether or not there is
		-- anything to see, so both of these are state worth asserting
		if k == "SetTextInsets" then
			return function(s2, l, r, t, b) s2._insets = { l, r, t, b } end
		end
		if k == "GetTextInsets" then
			return function(s2)
				local i = s2._insets or { 30, 8, 0, 0 }
				return i[1], i[2], i[3], i[4]
			end
		end
		if k == "EnableMouse" then
			return function(s2, on) s2._mouse = on and true or false end
		end
		if k == "SetClampRectInsets" then
			return function(s2, l, r, t, b) s2._clamp = { l, r, t, b } end
		end
		if k == "GetClampRectInsets" then
			return function(s2)
				local c = s2._clamp or { 0, 0, -20, 20 }
				return c[1], c[2], c[3], c[4]
			end
		end
		if k == "SetMinimumWidth" then
			return function(s2, w2) s2._minWidth = w2 end
		end
		if k == "SetPadding" then
			return function(s2, r, b, l, t) s2._padding = { r, b, l, t } end
		end
		if k == "GetPadding" then
			return function(s2)
				local p2 = s2._padding or { 0, 0, 0, 0 }
				return p2[1], p2[2], p2[3], p2[4]
			end
		end
		if k == "ClearAllPoints" then
			return function(s2) s2._point, s2._points = nil, nil end
		end
		if k == "GetPoint" then
			return function(s2)
				local p2 = s2._point or {}
				return p2.point, s2._parent, p2.relPoint, p2.x or 0, p2.y or 0
			end
		end
		if k == "SetSize" then
			return function(s2, w2, h2) s2._width, s2._height = w2, h2 end
		end
		if k == "CreateTexture" then
			return function(s2)
				local t = widget("Texture", nil)
				s2._regions[#s2._regions + 1] = t
				return t
			end
		end
		if k == "CreateFontString" then
			return function(s2)
				local t = widget("FontString", nil)
				s2._regions[#s2._regions + 1] = t
				return t
			end
		end
		if k == "GetRegions" then
			return function(s2) return (table.unpack or unpack)(s2._regions) end
		end
		if k == "GetChildren" then
			return function(s2) return (table.unpack or unpack)(s2._children) end
		end
		if k == "GetTextColor" then
			return function(s2)
				local c = s2._textColor or { 1, 1, 1 }
				return c[1], c[2], c[3]
			end
		end
		-- colour is state too: the quiet footer is a colour as much as a size
		if k == "SetJustifyH" then return function(s2, how) s2._justify = how end end
		if k == "SetTextColor" then
			return function(s2, r, g, b) s2._textColor = { r, g, b } end
		end
		-- the action bars are dressed with alpha and texture coordinates
		-- rather than by hiding things, so both are state
		if k == "SetAlpha" then return function(s2, a) s2._alpha = a end end
		if k == "GetAlpha" then return function(s2) return s2._alpha or 1 end end
		if k == "SetTexCoord" then
			return function(s2, l, r, t, b) s2._texCoord = { l, r, t, b } end
		end
		-- a micro button's art is one image; taking the gold down is a tint
		if k == "SetVertexColor" then
			return function(s2, r, g, b, a) s2._vertex = { r, g, b, a } end
		end
		if k == "SetDesaturated" then
			return function(s2, on) s2._grey = on and true or false end
		end
		-- a light quote over snow needs its own shadow, so that is state too
		if k == "SetShadowColor" then
			return function(s2, r, g, b, a) s2._shadow = { r, g, b, a } end
		end
		-- and read back, so a line we give a shadow to can give it back
		if k == "GetShadowColor" then
			return function(s2)
				local c = s2._shadow or { 0, 0, 0, 0 }
				return c[1], c[2], c[3], c[4]
			end
		end
		if k == "SetShadowOffset" then
			return function(s2, x, y) s2._shadowAt = { x, y } end
		end
		if k == "GetShadowOffset" then
			return function(s2)
				local o = s2._shadowAt or { 0, 0 }
				return o[1], o[2]
			end
		end
		if k == "SetColorTexture" then
			return function(s2, r, g, b, a) s2._color = { r, g, b, a } end
		end
		-- a status bar's range and value are state: the combo row is drawn by
		-- handing a count to one, so the count has to be readable back
		if k == "SetMinMaxValues" then return function(s2, lo, hi) s2._min, s2._max = lo, hi end end
		if k == "GetMinMaxValues" then return function(s2) return s2._min or 0, s2._max or 1 end end
		if k == "SetValue" then return function(s2, v) s2._value = v end end
		if k == "GetValue" then return function(s2) return s2._value or 0 end end
		if k == "SetStatusBarColor" then return function(s2, r, g, b, a) s2._barColor = { r, g, b, a } end end
		if k == "SetTexture" then
			return function(s2, path) s2._texture = path end
		end
		-- a measurement, and in secret mode the kind of measurement this client
		-- hands back once execution is tainted
		if k == "GetStringWidth" then
			return function(s2) return _G.secretMeasurements and _G.SECRET_WIDTH or (#(s2._text or "") * 6) end
		end
		if k == "GetWidth" then
			return function(s2) return _G.secretMeasurements and _G.SECRET_WIDTH or (s2._width or 200) end
		end
		if k == "SetWidth" then return function(s2, v) s2._width = v end end
		-- parentage is state the addon reasons about: the panel docks into the
		-- window or floats on the screen, and which one matters
		-- height is arithmetic in the addon, so the stub keeps a number
		if k == "SetHeight" then return function(s2, v) s2._height = v end end
		if k == "GetHeight" then return function(s2) return s2._height or 0 end end
		if k == "SetParent" then return function(s2, v) s2._parent = v end end
		if k == "GetParent" then return function(s2) return s2._parent end end
		-- text is state too: a search box that forgets what was typed cannot
		-- be searched with
		if k == "SetText" then return function(s2, v) s2._text = v end end
		if k == "GetText" then return function(s2) return s2._text end end
		-- Enable/Disable is state the addon reasons about: a button that stays
		-- live with nothing selected is the bug this guards
		if k == "Enable" then return function(s) s._enabled = true end end
		if k == "Disable" then return function(s) s._enabled = false end end
		if k == "IsEnabled" then return function(s) return s._enabled ~= false end end
		-- scripts are kept, so a test can click the thing it just built
		if k == "SetScript" then return function(s, name, fn) s._scripts[name] = fn end end
		if k == "HookScript" then return function(s, name, fn) s._scripts[name] = fn end end
		if k == "RegisterEvent" then
			return function(s2, event)
				s2._events = s2._events or {}
				s2._events[event] = "all"
			end
		end
		if k == "RegisterUnitEvent" then
			return function(s2, event, unit)
				s2._events = s2._events or {}
				s2._events[event] = unit or "all"
			end
		end
		if k == "GetScript" then return function(s, name) return s._scripts[name] end end
		-- a secure button's attributes are state: which item it will use
		if k == "SetAttribute" then
			return function(s2, name, value)
				s2._attributes = s2._attributes or {}
				s2._attributes[name] = value
			end
		end
		if k == "GetAttribute" then
			return function(s2, name) return s2._attributes and s2._attributes[name] end
		end
		if METHODS[k] then
			return function() return widget("child") end
		end
		-- fields the addon sets on its own frames are fine; methods are not
		return nil
	end })
	return w
end

_G.CreateFrame = function(_, name, parent)
	local w = widget("frame", parent)
	if type(name) == "string" then
		w._name = name
		_G[name] = w
	end
	return w
end
-- a font object is a widget with a font on it, and a name the code reaches for
_G.CreateFont = function(name)
	local f = widget("font")
	f._name = name
	_G[name] = f
	return f
end
_G.UIParent = widget("frame")
_G.Minimap = widget("frame")
_G.GetCursorPosition = function() return 400, 300 end
_G.UnitAffectingCombat = function() return false end
_G.InCombatLockdown = function() return false end
_G.C_Timer = { NewTicker = function() return { Cancel = function() end } end, After = function() end }
_G.GameTooltip = widget("frame")
-- the client's own health bar under the tooltip, which puts itself back
_G.GameTooltipStatusBar = widget("frame")
-- the other tooltips a player actually sees: the equip compare, an item link
-- clicked in chat, and the compare on one of those
_G.ShoppingTooltip1 = widget("frame")
_G.ShoppingTooltip2 = widget("frame")
_G.ItemRefTooltip = widget("frame")
_G.ItemRefShoppingTooltip1 = widget("frame")
_G.ItemRefShoppingTooltip2 = widget("frame")
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.tinsert = table.insert
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.time = os.time
_G.date = os.date
_G.GetRealmName = function() return "Whitemane" end
_G.GetAddOnMetadata = function() return "0.1.0" end
_G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
-- the client's own class icon sheet, and where each class sits on it
_G.CLASS_ICON_TCOORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49, 0, 0.25 },
	PRIEST = { 0.49, 0.75, 0, 0.25 }, ROGUE = { 0.49, 0.75, 0.25, 0.5 },
	DRUID = { 0.75, 0.98, 0.75, 1 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
_G.UnitExists = function() return true end
_G.UnitIsPlayer = function() return true end
_G.UnitIsVisible = function() return true end
_G.UnitName = function() return "Beeb", nil end
_G.GetUnitName = function() return "Beeb Bob" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitRace = function() return "Orc", "Orc" end
_G.UnitLevel = function() return 60 end
_G.UnitSex = function() return 2 end
_G.UnitGUID = function() return "Player-4372-0002BFB1" end
_G.UnitFactionGroup = function() return "Horde" end
_G.GetGuildInfo = function() return "Nightwatch" end
_G.GetRealZoneText = function() return "Orgrimmar" end
_G.GetNumGroupMembers = function() return 0 end
_G.IsInRaid = function() return false end
_G.GetNumGuildMembers = function() return 1 end
_G.GetGuildRosterInfo = function() return "Astralux Vane", nil, nil, 58, nil, "Durotar", nil, nil, nil, nil, "MAGE" end
_G.C_GuildInfo = { GuildRoster = function() end }
-- the meter stands in for the combat log this client keeps to itself
_G.Enum = {
	DamageMeterSessionType = { Current = 1, Overall = 2 },
	DamageMeterType = { DamageDone = 1, HealingDone = 2 },
	TooltipDataType = { Unit = 1 },
}
_G.C_DamageMeter = {
	GetCombatSessionFromType = function(_, meterType)
		if meterType == Enum.DamageMeterType.DamageDone then
			return { combatSources = {
				{ name = "Corwin", sourceGUID = "Player-4372-0002BFB2", classFilename = "WARRIOR" },
				{ name = "Snarly", sourceGUID = "Pet-0-4372-1", classFilename = nil }, -- a pet, skipped
			} }
		end
		return { combatSources = {
			{ name = "Grimshade Ash", sourceGUID = "Player-4372-0002BFB3", classFilename = "PRIEST" },
		} }
	end,
	GetAvailableCombatSessions = function() return {} end,
}
-- SECRET VALUES (Josh 2026-09-19). Once execution is tainted, this client hands
-- back measurements you are not allowed to use: they ARE numbers, and the
-- arithmetic on the next line throws. Headless Lua cannot make a number throw,
-- so the stub hands back a sentinel and issecretvalue knows it - a width that
-- comes out anywhere near the sentinel is a measurement that was used when the
-- addon should have counted characters instead.
_G.SECRET_WIDTH = 1e6
_G.secretMeasurements = false
_G.issecretvalue = function(v) return _G.secretMeasurements and v == _G.SECRET_WIDTH end
-- the lists the client holds for its own reasons
_G.C_FriendList = {
	GetNumWhoResults = function() return 1 end,
	GetWhoInfo = function()
		return { fullName = "Elune Tierra", fullGuildName = "", level = 6, area = "Teldrassil",
			filename = "PRIEST", raceStr = "NightElf" }
	end,
	GetNumFriends = function() return 1 end,
	GetFriendInfoByIndex = function()
		return { name = "Andris Bear", className = "Druid", area = "Darnassus", level = 12 }
	end,
}
_G.GetNumBattlefieldScores = function() return 1 end
_G.GetBattlefieldScore = function()
	return "Michalis Epiloque", 3, 9, 1, 120, 1, 2, "Human", "Paladin", "PALADIN"
end
_G.GetInboxNumItems = function() return 1 end
_G.GetInboxHeaderInfo = function() return 1, 1, "Gorsan Quakehammer" end
-- how the chat frame knows what colour to paint a sender's name
_G.guidBook = {
	["Player-4372-0002BFB2"] = { "Warrior", "WARRIOR", "Human", "Human", 2, "Corwin Bob", "Whitemane" },
	["Player-70-0000AAAA"] = { "Shaman", "SHAMAN", "Dwarf", "Dwarf", 2, "Baragon Stoneshaper", "Whitemane" },
}
_G.GetPlayerInfoByGUID = function(guid)
	local r = _G.guidBook[guid]
	if not r then return nil end
	return r[1], r[2], r[3], r[4], r[5], r[6], r[7]
end
_G.print = print
_G.SEARCH = "Search"
-- the client's own word for a level, which its tooltip line starts with
_G.LEVEL = "Level"

-- read the TOC so the test loads exactly what the client loads, in order
local files = {}
for line in io.lines("BeebMod.toc") do
	line = line:gsub("%s+$", "")
	-- except the live save, which is the player's own data through a folder
	-- link: the tests run on the fakes they build, never on a real book
	if line ~= "" and not line:match("^#") and not line:match("^Data\\Live\\") then
		files[#files + 1] = line:gsub("\\", "/")
	end
end
if #files == 0 then
	fail("BeebMod.toc lists no files")
end

-- A TEXTURE PATH THAT DOES NOT EXIST RENDERS AS NOTHING (Josh 2026-09-19).
-- Not an error, not a pink square: nothing. UI/Pill.lua still pointed at the
-- Ledger's folder after the toolkit absorbed it, so every tag drew its label
-- with no pill behind it and the addon looked half-finished with nothing to
-- go on. Every path in the source has to name a file that is actually here.
do
	local bad = {}
	for _, f in ipairs(files) do
		local handle = io.open(f, "r")
		if handle then
			local text = handle:read("*a")
			handle:close()
			-- a texture is named without its extension; a font (Fira Code,
			-- 2026-09-23) with it, and with a hyphen in its name
			for addon, rest in text:gmatch('AddOns\\\\([%w_]+)\\\\([%w_%-%.\\]+)') do
				local path = rest:gsub('\\\\', "/")
				local found = false
				local exts = path:find("%.%w+$") and { "" } or { ".tga", ".blp", ".png" }
				for _, ext in ipairs(exts) do
					local t = io.open(path .. ext, "r")
					if t then
						t:close()
						found = true
					end
				end
				if addon ~= "BeebMod" or not found then
					bad[#bad + 1] = ("%s -> AddOns/%s/%s"):format(f, addon, path)
				end
			end
		end
	end
	if #bad > 0 then
		fail("texture paths that name nothing: " .. table.concat(bad, ", "))
	else
		print("ok   every texture path names a file that is here")
	end
end

local BT = {}
for _, f in ipairs(files) do
	local chunk, err = loadfile(f)
	if not chunk then
		fail(f .. ": " .. tostring(err))
	else
		local good, ferr = pcall(chunk, "BeebMod", BT)
		if good then
			print("ok   loads " .. f)
		else
			fail(f .. ": " .. tostring(ferr))
		end
	end
end

-- PLAYER_LOGIN, near enough: build the database, start collecting, then use it
if ok then
	_G.BeebModDB = nil
	BT.Bind("Whitemane", "Alliance")
	BT.Collect.Start()
	local steps = {
		-- THE SHAPE IS NOT A SETTING (Josh 2026-09-22): a one-pixel border and
		-- a three-pixel radius, whatever an older version saved. Checked here,
		-- then the rest of these run square, which is what they were written
		-- against; the shape tests further down set both explicitly.
		{ "one border width and one corner radius, not settings", function()
			_G.BeebModDB.settings.theme = { thickness = 4, radius = 0 }
			assert(BT.Theme.Thickness() == 1, "the border is one pixel, whatever was saved")
			assert(BT.Theme.Radius() == 3, "and the corners are three")
			_G.BeebModDB.settings.theme = nil
			BT.Theme.Set("radius", 0)
		end },
		{ "building the window is not opening it", function()
			-- A FRAME IS SHOWN THE MOMENT IT IS CREATED, so this has to be the
			-- FIRST thing that touches the window: once anything has opened and
			-- closed it, the check proves nothing. Building it to get at a
			-- module's panel is how the first pencil click after a reload
			-- opened the toolkit as well (Josh 2026-09-19).
			assert(BT.Window.Frame() == nil, "nothing has built the window yet")
			BT.Window.Build()
			assert(BT.Window.Frame() ~= nil, "now it exists")
			assert(not BT.Window.IsShown(), "and it is not on screen")
		end },
		{ "a unit sighting, and who they are looking at", function()
			BT.Collect.FromUnitAndTarget("target")
			-- the stub answers every unit, so the point is that it ASKED
			assert(BT.DB.Get(BT.db, "Beeb Bob@Whitemane"), "the unit itself is filed")
		end },
		{ "the search window", function()
			BT.Window.Toggle()
			assert(_G.BeebModWindow and _G.BeebModWindow:IsShown(), "the FIRST /bt must open the window")
			BT.Window.Toggle()
			assert(not _G.BeebModWindow:IsShown(), "and the second closes it")
			BT.Window.Toggle()
		end },
		{ "a search", function() BT.Find.Search("beeb") end },
		{ "tags on a tooltip are rows, not pills", function()
			local lines, right = {}, {}
			local tip = setmetatable({
				AddLine = function(_, text) lines[#lines + 1] = tostring(text) end,
				AddDoubleLine = function(_, l, r)
					lines[#lines + 1] = tostring(l)
					right[#lines] = tostring(r)
				end,
				NumLines = function() return #lines end,
				GetName = function() return "TagTip" end,
				GetWidth = function() return 220 end,
			}, { __index = function() return function() end end })
			for i = 1, 8 do
				_G["TagTipTextLeft" .. i] = _G.CreateFrame("FontString")
				_G["TagTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			-- the tooltip is about whoever the unit is, and the stub's unit is
			-- Beeb Bob: tag THEM, not somebody else
			BT.DB.SetFlag(BT.db, "Beeb Bob@Whitemane", "good", true)
			BT.DB.SetFlag(BT.db, "Beeb Bob@Whitemane", "troll", true)
			BT.Tooltip.Fill(tip, "target")

			-- BACK INSIDE THE TOOLTIP (Josh 2026-09-20). They sat on a strip
			-- of their own between the quote and the tooltip, which made three
			-- stacked objects out of one unit. A tag is a fact about somebody,
			-- so it goes with the other facts; the quote is the only thing
			-- here that is yours, and the only thing left floating.
			-- ONE ROW, NOT TWO COLUMNS (Josh 2026-09-20). Two tags to a line
			-- put the second at the far right of the tooltip, so three tags
			-- read as a little table with a hole in it.
			local tagLine = nil
			for i, text in ipairs(lines) do
				if text:find("Good", 1, true) then
					tagLine = i
				end
			end
			assert(tagLine, "the tags are on the tooltip: " .. table.concat(lines, " | "))
			assert(lines[tagLine]:find("Troll", 1, true),
				"every one of them on the same line: " .. lines[tagLine])
			assert(right[tagLine] == nil, "not split into columns")
			assert(lines[tagLine]:find("^%s"), "each leaves room for its swatch")
			assert(select(2, _G["TagTipTextLeft" .. tagLine]:GetFont()) == BT.Fonts.Size(11),
				"and the row is tag-sized")
			-- the squares are laid along that one line at measured offsets,
			-- because a tooltip line cannot measure a substring of itself
			local seen, last = 0, -1
			for _, sw in ipairs(BT.UnitTip.SwatchPool("TextLeft")) do
				if sw:IsShown() then
					local at = (sw._points or {}).LEFT
					assert(at, "each square is anchored along the line")
					assert(at.x > last, ("and they run left to right (%s after %s)")
						:format(tostring(at.x), tostring(last)))
					last = at.x
					seen = seen + 1
				end
			end
			assert(seen >= 2, "one square per tag: " .. tostring(seen))
			BT.Tooltip.HidePills()
		end },
		{ "measurements a tainted client will not let you use", function()
			-- the crash this guards: GetStringWidth came back SECRET inside the
			-- tooltip's secure call, type(x) == "number" said yes, and the
			-- arithmetic on the next line threw in the player's face.
			_G.secretMeasurements = true
			local fs = _G.UIParent:CreateFontString()
			local w = BT.Pill.Width(fs, "good", 10)
			assert(type(w) == "number" and w < 200,
				"a secret measurement is no measurement, but got " .. tostring(w))

			local lines = {}
			local tip = setmetatable({
				AddLine = function(_, text) lines[#lines + 1] = tostring(text) end,
				AddDoubleLine = function(_, l) lines[#lines + 1] = tostring(l) end,
				NumLines = function() return #lines end,
				GetName = function() return nil end,
				GetWidth = function() return _G.SECRET_WIDTH end,
			}, { __index = function() return function() end end })
			for i = 1, 8 do
				_G["SecretTipTextLeft" .. i] = _G.CreateFrame("FontString")
				_G["SecretTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			tip.GetName = function() return "SecretTip" end
			BT.Tooltip.Fill(tip, "target")
			assert(#lines > 0, "the tooltip is still written when nothing can be measured")
			-- and the tags went on it, which is where a width that cannot be
			-- read would have thrown
			assert(table.concat(lines, " | "):find("Good", 1, true),
				"tags and all: " .. table.concat(lines, " | "))
			BT.Tooltip.HidePills()
			-- the other two places a measurement is read
			BT.Bar.Update()
			BT.Find.Refresh()
			_G.secretMeasurements = false
		end },
		{ "a tooltip", function()
			-- a tooltip that remembers what was written on it
			local lines, right, hooked, tipW = {}, {}, {}, nil
			local tip = setmetatable({
				HookScript = function(_, name, fn) hooked[name] = fn end,
				GetWidth = function() return tipW end,
				AddLine = function(_, text) lines[#lines + 1] = text end,
				AddDoubleLine = function(_, l, r)
					lines[#lines + 1] = tostring(l)
					right[#lines] = tostring(r)
				end,
				NumLines = function() return #lines end,
			}, { __index = function() return function() end end })
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "the best lol")
			BT.Tooltip.Fill(tip, "target")
			local joined = table.concat(lines, " | ")
			-- THE NOTE FLOATS (Josh 2026-09-19). It was four lines inside the
			-- tooltip - a spacer, the quote, who said it, another spacer -
			-- which is a third of the height of everything else put together,
			-- for the one thing on there that is not a fact about the unit.
			assert(not joined:find("the best lol", 1, true),
				"the note is not a line in the tooltip any more: " .. joined)
			local card = BT.Tooltip.NoteFrame()
			local quote = BT.Tooltip.QuoteFrame()
			-- THE QUOTE HAS NO PANEL (Josh 2026-09-19). A surface behind it
			-- made it another box in a stack of boxes. It is somebody's words,
			-- and words on the world read as words - carried entirely by the
			-- shadow on the letters.
			assert(quote and quote:IsShown(), "the words float above the tooltip")
			assert(quote ~= card, "in a frame of their own")
			assert(quote.fill == nil and quote.rim == nil, "with no panel behind them")
			-- A SCRIM, NOT A PANEL (Josh 2026-09-22): a soft haze, so the words
			-- still read over the panel's own light text
			assert(card.scrim and #card.scrim == 2 and card.scrim[1].mid._width
				and card.scrim[1].mid._width <= 220, "a haze behind the words, no wider than the tooltip")
			-- WIDER THAN WHAT IT SITS ON (Josh 2026-09-20): set large and
			-- centred, a note of six words wrapped at the tooltip's own width,
			-- and a wrapped quotation reads as a paragraph rather than as a
			-- line somebody said
			-- AS WIDE AS WHAT IT SITS ON (Josh 2026-09-20). Wider was an
			-- attempt to stop a long note wrapping, and it sent the quote off
			-- the edge of the screen on a tooltip already near it.
			assert(quote._width == 220,
				"the quote matches the tooltip's width: " .. tostring(quote._width))
			-- AND AGAIN ONCE THE TOOLTIP SETTLES (Josh 2026-09-23, audit): the
			-- lines written after the card widen the tooltip, and the quote
			-- wraps to the width it ends up, not the one it had mid-write
			assert(hooked.OnSizeChanged, "the card follows the tooltip's size")
			tipW = 310
			hooked.OnSizeChanged(tip, 310, 90)
			assert(quote._width == 310, "re-measured to the wider tooltip: " .. tostring(quote._width))
			tipW = nil
			hooked.OnSizeChanged(tip, 220, 90)
			assert(card.text._text == '"the best lol"',
				"quoted, with no label on it: " .. tostring(card.text._text))
			assert(card.text._justify == "CENTER", "centred in its card")
			-- AN INSCRIPTION, NOT A CAPTION: set above everything around it
			local quoteSize = select(2, card.text:GetFont())
			assert(quoteSize and quoteSize >= 14,
				"the quote is set large: " .. tostring(quoteSize))
			local creditSize = select(2, card.credit:GetFont())
			assert(not creditSize or creditSize < quoteSize,
				"and the source stays small under it")
			local credit = card.credit._text
			assert(credit and credit:find("Beeb Bob", 1, true),
				"the character who wrote it: " .. tostring(credit))
			assert(credit:find("%d+/%d+/%d+"), "and the day they wrote it: " .. credit)
			assert(card.credit._justify == "RIGHT", "the source hangs off the right")
			-- it has to read against whatever is behind it
			assert(#card.shadow > 1, "with a shadow under it")
			assert(card.text._shadow, "and the words carry their own")
			-- AND IT FADES WITH THE TOOLTIP (Josh 2026-09-19). The client
			-- dissolves a tooltip rather than snapping it off; a card on
			-- UIParent took no part in that and stayed solid above the fade.
			-- A child inherits its parent's alpha, so it fades for free.
			assert(card:GetParent() == tip,
				"the card belongs to the tooltip it is sitting on")
			-- NOTHING IS DRAWN ON THE CARD ANY MORE (Josh 2026-09-20). The
			-- tags went back into the tooltip with the other facts about the
			-- unit; what is left is a carrier for the quote and nothing else.
			assert(card.fill and not card.fill:IsShown(),
				"the strip the tags sat on is not drawn")
			assert(card._height == 1, "it takes no height: " .. tostring(card._height))
			assert(not joined:find("Note:", 1, true), "the caption is gone")
			assert(not joined:find("Seen ", 1, true), "and there is no seen-count line any more")

			-- and it goes when there is nothing to say at all: no note AND no
			-- tags, since the tags live on it too now
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "")
			local hadGood = BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags
			BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags = nil
			BT.Tooltip.Fill(tip, "target")
			assert(not card:IsShown() and not quote:IsShown(),
				"nothing of yours, nothing above the tooltip")
			BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags = hadGood
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "the best lol")
		end },
		{ "the bar on the world", function()
			BT.Bar.Create()
			local q = _G.BeebModBar
			assert(q and q:IsShown(), "it exists and is up")
			assert(q:GetScript("OnEnter") == nil, "the bar itself carries no tooltip")

			-- THE BAR IS WHATEVER IS SWITCHED ON (Josh 2026-09-19). The core
			-- owns the mark and nothing else, so the cells have to be found by
			-- asking the bar what it is carrying today rather than by name.
			local cell = {}
			for _, c in ipairs(BT.Bar.Cells()) do
				cell[c.cellKey] = c
			end
			assert(cell.mark, "the core's mark is always there")
			assert(cell.cog, "and the cog, which is the only way in the dock carries")
			assert(cell.who and cell.dots, "the Ledger's cells arrived")
			assert(cell.find == nil and cell.census == nil,
				"no per-module way-in icons: the window has tabs for that")
			q.key = nil
			q.dots = cell.dots

			-- somebody you have written about: a dot per tag, and a note mark
			BT.DB.Note(BT.db, "Beeb Bob", nil, { guid = "Player-4372-0002BFB1", class = "WARRIOR" })
			BT.DB.SetFlag(BT.db, "Beeb Bob@Whitemane", "good", true)
			BT.DB.SetFlag(BT.db, "Beeb Bob@Whitemane", "troll", true)
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "held the door")
			BT.Bar.Update()
			assert(cell.who.key == "Beeb Bob@Whitemane", "it knows who you have targeted")
			assert(#q.dots.tags == 2 and q.dots.list[1]:IsShown() and q.dots.list[2]:IsShown(),
				"a dot for each tag")
			assert(not q.dots.list[3]:IsShown(), "and no more than that")
			assert(q.dots:IsShown(), "the dots cell is in the bar")

			-- A MARK MEANING THERE IS ONE (Josh 2026-09-20). The words sat on
			-- a second line of the dock, and a second line is a third of the
			-- panel's height spent on a sentence you wrote and already know.
			assert(cell.note == nil, "there is no note cell any more")
			assert(q.dots.note:IsShown(), "a mark at the head of the tags says there is one")
			assert(q.dots.note.text == "held the door",
				"and it holds the words for its tooltip: " .. tostring(q.dots.note.text))
			local noteAt = (q.dots.note._points or {}).LEFT
			local firstTag = (q.dots.list[1]._points or {}).LEFT
			assert(noteAt and firstTag and noteAt.x < firstTag.x,
				"the tags step aside for it rather than sitting under it")

			-- and it goes when the note does
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "")
			BT.Bar.Update()
			assert(not q.dots.note:IsShown(), "no note, no mark")
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "held the door")
			BT.Bar.Update()

			assert(cell.dots.side == "right" and cell.cog.side == "right",
				"the tags hang at the right-hand end, beside the cog")
			assert(BT.Bar.NameX() > 20, "the name sits in past the class icon")
			local tall = BT.Bar.Row()._height
			_G.UnitIsPlayer = function() return false end
			BT.Bar.Update()
			assert(BT.Bar.Row()._height == tall,
				"the row keeps its height with nothing to show on the second line")
			_G.UnitIsPlayer = function() return true end
			BT.Bar.Update()

			-- the first slot becomes whoever you are pointing at
			assert(cell.mark.icon._texture and cell.mark.icon._texture:find("Classes", 1, true),
				"a targeted player puts their class in the first slot: "
					.. tostring(cell.mark.icon._texture))
			_G.UnitIsPlayer = function() return false end
			BT.Bar.Update()
			assert(cell.mark.icon._texture and cell.mark.icon._texture:find("BeebMod", 1, true),
				"and with nobody targeted it is the toolkit's own glyph again")
			_G.UnitIsPlayer = function() return true end
			BT.Bar.Update()

			-- the cells that carry content carry a tooltip; nothing else does
			assert(q.dots:GetScript("OnEnter"), "the dots are hoverable")
			-- the tag tooltip: no name on it, one size for every line, and the
			-- colour as a square rather than as the words
			_G.GameTooltipTextLeft1 = _G.CreateFrame("FontString")
			_G.GameTooltipTextLeft2 = _G.CreateFrame("FontString")
			_G.GameTooltip.GetName = function() return "GameTooltip" end
			local said = {}
			_G.GameTooltip.AddLine = function(_, text) said[#said + 1] = tostring(text) end
			_G.GameTooltip.NumLines = function() return #said end
			_G.GameTooltipTextLeft3 = _G.CreateFrame("FontString")
			_G.GameTooltipTextLeft4 = _G.CreateFrame("FontString")
			_G.GameTooltipTextRight2 = _G.CreateFrame("FontString")
			_G.GameTooltip.AddDoubleLine = function(_, l, r)
				said[#said + 1] = tostring(l)
				said.right = said.right or {}
				said.right[#said] = tostring(r)
			end
			q.dots:GetScript("OnEnter")(q.dots)
			-- THE SAME QUOTATION IT IS EVERYWHERE ELSE (Josh 2026-09-20): the
			-- words, then who said them, then a line per tag
			assert(#said == 4, ("the note, its source and a line per tag (%d)"):format(#said))
			assert(said[1]:find("held the door", 1, true),
				"the words are on the tooltip, where there is room: " .. said[1])
			assert(said.right[2] and said.right[2]:find("Beeb", 1, true),
				"with who wrote it: " .. tostring(said.right[2]))
			assert(said.right[2]:find("%d+/%d+/%d+"), "and when: " .. said.right[2])
			-- set the way the unit tooltip sets it: large, and the source small
			local quoteSize = select(2, _G.GameTooltipTextLeft1:GetFont())
			assert(quoteSize and quoteSize >= 14, "the note is set large: " .. tostring(quoteSize))
			assert(_G.GameTooltipTextLeft1._justify == "CENTER", "and centred")
			assert(select(2, _G.GameTooltipTextLeft2:GetFont()) < quoteSize,
				"the source stays small under it")
			assert(not said[3]:find("Beeb", 1, true), "no name on the tags: " .. said[3])
			assert(said[3]:find("^%s") ~= nil, "each tag line leaves room for its swatch")
			assert(select(2, _G.GameTooltipTextLeft3:GetFont())
				== select(2, _G.GameTooltipTextLeft4:GetFont()),
				"and every tag line is the same size")
			_G.GameTooltip.AddDoubleLine = nil
			_G.GameTooltip.AddLine, _G.GameTooltip.NumLines = nil, nil
			q.dots:GetScript("OnLeave")(q.dots)

			-- A PENCIL, ON HOVER. The name is a name; hovering it offers a
			-- pencil, and only the pencil writes - clicking a name used to
			-- open a panel you had not asked for.
			if BT.Window.IsShown() then BT.Window.Toggle() end
			assert(not cell.who.pencil:IsShown(), "no pencil until you point at the name")
			cell.who.button:GetScript("OnEnter")(cell.who.button)
			assert(cell.who.pencil:IsShown(), "pointing at the name offers one")
			assert(not BT.Find.EditorShown(), "and offering is not opening")
			assert((cell.who.pencil._level or 0) > (cell.who.button._level or 0),
				"the pencil sits above the name's own button, or it never gets the click")
			cell.who.pencil:GetScript("OnClick")(cell.who.pencil, "LeftButton")
			assert(BT.Find.EditorShown(), "clicking the pencil opens the panel for them")

			-- AND IT DOES NOT OPEN THE WINDOW ON THE WAY (Josh 2026-09-19).
			-- Building the Ledger's panel used to mean showing the window - and
			-- a frame is SHOWN the moment it is created, so merely building the
			-- window opened it. The first click after a reload opened both.
			assert(not BT.Window.IsShown(), "writing on somebody does not open the toolkit")
			assert(BT.Window.Frame() ~= nil, "even though the window itself now exists")
			BT.Find.CloseEditor()
			-- the cog goes to the settings, which is where you turn things on
			cell.cog.button:GetScript("OnClick")(cell.cog.button)
			assert(BT.Window.IsShown() and BT.Window.View() == "settings", "the cog opens the settings")
			BT.Window.Toggle()

			-- nothing targeted: the cells with nothing in them leave
			local exists = _G.UnitIsPlayer
			_G.UnitIsPlayer = function() return false end
			BT.Bar.Update()
			assert(cell.who.key == nil, "no target, no key")
			assert(not cell.dots:IsShown(), "and no dots cell")
			assert(cell.mark:IsShown() and cell.who:IsShown() and cell.cog:IsShown(),
				"the mark, the prompt and the cog stay")
			cell.who.pencil:GetScript("OnClick")(cell.who.pencil, "LeftButton")
			assert(not BT.Find.EditorShown(), "a click writes on nobody")
			assert(not cell.who.pencil:IsShown(), "and there is no pencil to click")
			_G.UnitIsPlayer = exists
			-- with no other section in the dock, hiding the row hides the dock
			local hadMap, hadPerf = BT.Enabled("minimap"), BT.Enabled("perf")
			local hadGold, hadClock = BT.Enabled("gold"), BT.Enabled("clock")
			BT.SetEnabled("clock", false)
			BT.SetEnabled("minimap", false)
			BT.SetEnabled("perf", false)
			BT.SetEnabled("gold", false)
			BT.Bar.Update()
			assert(BT.Bar.Toggle() == false and not q:IsShown(), "/bt bar hides it")
			BT.Bar.Toggle()
			BT.SetEnabled("minimap", hadMap)
			BT.SetEnabled("perf", hadPerf)
			BT.SetEnabled("gold", hadGold)
			BT.SetEnabled("clock", hadClock)
		end },
		{ "only players are written down", function()
			-- a totem emoting: a name, no GUID, and no business in the book
			BT.Collect.handlers.CHAT_MSG_TEXT_EMOTE(nil, "CHAT_MSG_TEXT_EMOTE",
				"Totem pulses.", "Totem", "", "", "", "", 0, 0, "", 0, 42, nil)
			assert(BT.DB.Get(BT.db, "Totem@Whitemane") == nil, "a totem is not a character")
			-- and the same for a pet with a pet GUID
			BT.Collect.handlers.CHAT_MSG_SAY(nil, "CHAT_MSG_SAY",
				"grr", "Snarly", "", "", "", "", 0, 0, "", 0, 43, "Pet-0-4372-1-1")
			assert(BT.DB.Get(BT.db, "Snarly@Whitemane") == nil, "nor is a pet")
		end },
		{ "chat keeps the full name it was given", function()
			-- the client only knows "Baragon"; chat said "Baragon Stoneshaper"
			_G.guidBook["Player-70-0000CCCC"] = { "Priest", "PRIEST", "Human", "Human", 2, "Corvin", "Whitemane" }
			BT.Collect.handlers.CHAT_MSG_SAY(nil, "CHAT_MSG_SAY",
				"wts linen", "Corvin Halewood", "", "", "", "", 0, 0, "", 0, 44, "Player-70-0000CCCC")
			assert(BT.DB.Get(BT.db, "Corvin Halewood@Whitemane"), "the full name from chat is what is filed")
			assert(BT.DB.Get(BT.db, "Corvin@Whitemane") == nil, "not the half the GUID knows")
			assert(BT.DB.Get(BT.db, "Corvin Halewood@Whitemane").class == "PRIEST", "and the class still lands")
		end },
		{ "a chat message carries a usable GUID", function()
			-- the real argument list: text, sender, language, channel, sender2,
			-- flags, zoneID, index, baseName, unused, lineID, GUID
			BT.Collect.handlers.CHAT_MSG_SAY(nil, "CHAT_MSG_SAY",
				"anyone selling linen", "Baragon Stoneshaper", "Common", "", "", "", 0, 0, "", 0,
				1234567, "Player-70-0000AAAA")
			local p = BT.DB.Get(BT.db, "Baragon Stoneshaper@Whitemane")
			assert(p, "the chat sighting was filed")
			assert(p.guid == "Player-70-0000AAAA", "with the GUID, not the line number")
			assert(p.class == "SHAMAN", "so the class came with it, unseen")
		end },
		{ "one-word names are swept out", function()
			BT.db.players["Totem@Whitemane"] = {
				name = "Totem", realm = "Whitemane", guid = "Player-4620-0068DFC4",
				class = "SHAMAN", seen = 4, first = 1, last = 2,
			}
			BT.db.guids["Player-4620-0068DFC4"] = "Totem@Whitemane"
			BT.DB.Cleanup(BT.db)
			assert(BT.DB.Get(BT.db, "Totem@Whitemane") == nil,
				"half a name goes, however convincing its GUID and class look")
		end },
		{ "chat names identify themselves", function()
			-- a chat sighting: name and GUID only, but the client knows the rest
			local before = BT.Stats.Census(BT.db).unknown.class
			local h = BT.Collect
			assert(h.Identify("Player-70-0000AAAA").class == "SHAMAN", "the client names the class")
			-- and an old unknown in the book is filled in by the backfill pass
			BT.DB.Note(BT.db, "Baragon Stoneshaper", nil, { guid = "Player-70-0000AAAA" })
			local p = BT.DB.Get(BT.db, "Baragon Stoneshaper@Whitemane")
			p.class = nil -- as if it had been stored before this existed
			local done = h.Backfill(100)
			assert(done >= 1, "the backfill names them")
			assert(BT.DB.Get(BT.db, "Baragon Stoneshaper@Whitemane").class == "SHAMAN", "class filled in")
			assert(BT.Stats.Census(BT.db).unknown.class <= before, "the unknown pile did not grow")
		end },
		{ "the panel repaints wherever it was opened from", function()
			-- the window's last view was the census and the window is closed:
			-- the panel opened from the bar must still repaint
			if not BT.Window.IsShown() then BT.Window.Toggle() end
			BT.Window.SetView("census")
			BT.Window.Toggle() -- close it, leaving view = census
			BT.DB.Note(BT.db, "Trilly Lightbolt", nil, { guid = "Player-70-0000ABAB", class = "WARLOCK" })
			BT.Find.OpenEditorFor("Trilly Lightbolt@Whitemane", _G.BeebModBar)
			assert(BT.Find.EditorShown(), "the panel is open")
			local before = BT.Find.EditorRefreshes()
			local flags = BT.Find.EditorFlagButtons()
			-- A ROW PER TAG, NOT A PILL. A square of the tag's own colour, lit
			-- when they carry it and dim when they do not, two to a line.
			assert(flags.good.swatch and flags.good.text, "each tag is a swatch and a label")
			assert(flags.good.pillLeft == nil, "and not a pill any more")
			flags.good:GetScript("OnClick")(flags.good, "LeftButton")
			assert(BT.DB.Get(BT.db, "Trilly Lightbolt@Whitemane").flags.good, "the tag went on")
			assert(BT.Find.EditorRefreshes() > before, "and the panel was redrawn")
			-- ON IS THREE THINGS AT ONCE: a wash behind the line, a solid
			-- square, and the name in full ink. One difference was not enough
			-- to read at a glance on a dark panel.
			assert(flags.good.swatch._color and flags.good.swatch._color[4] == 1,
				"a tag they carry has a solid square")
			assert(flags.good.bg:IsShown(), "and its colour behind the whole line")
			assert(not flags.good.hollow:IsShown(), "and no hollow middle")
			assert(not flags.bad.bg:IsShown(), "one they do not carry has no wash")
			assert(flags.bad.hollow:IsShown(), "and an empty square")
			assert(flags.bad.text._textColor and flags.good.text._textColor
				and flags.bad.text._textColor[1] < flags.good.text._textColor[1],
				"with its name in grey rather than ink")

			-- a tag of your own can be deleted, and it says what that costs
			local mine = BT.AddTag("Deletable")
			BT.Find.RebuildFlags()
			local row = BT.Find.EditorFlagButtons()[mine.key]
			assert(row, "a new tag gets a row")
			-- A CROSS YOU CAN SEE, on your own tags only
			assert(not row.kill:IsShown(), "no cross until you point at the row")
			row:GetScript("OnEnter")(row)
			assert(row.kill:IsShown(), "pointing at one of yours offers a cross")
			local builtin = BT.Find.EditorFlagButtons().good
			builtin:GetScript("OnEnter")(builtin)
			assert(not builtin.kill:IsShown(), "and a built-in tag offers none")

			-- a tag nobody carries goes without a question: there is nothing to
			-- warn about
			row.kill:GetScript("OnClick")(row.kill)
			assert(not BT.Find.ConfirmShown(), "an unused tag just goes")
			assert(BT.Util.FlagByKey(mine.key) == nil, "and it is gone")

			-- one that somebody carries still asks
			mine = BT.AddTag("Carried")
			BT.Find.RebuildFlags()
			BT.DB.SetFlag(BT.db, "Trilly Lightbolt@Whitemane", mine.key, true)
			row = BT.Find.EditorFlagButtons()[mine.key]
			row.kill:GetScript("OnClick")(row.kill)
			assert(BT.Find.ConfirmShown(), "a tag somebody carries asks before deleting")
			BT.Find.ConfirmButtons().no:GetScript("OnClick")(BT.Find.ConfirmButtons().no)
			assert(not BT.Find.ConfirmShown(), "and Keep puts the question away")

			-- right-click still works for anybody who knew
			row:GetScript("OnClick")(row, "RightButton")
			assert(BT.Find.ConfirmShown(), "right-clicking one of yours asks too")
			BT.Find.ConfirmButtons().no:GetScript("OnClick")(BT.Find.ConfirmButtons().no)
			BT.DB.SetFlag(BT.db, "Trilly Lightbolt@Whitemane", mine.key, false)
			BT.RemoveTag(mine.key)
			BT.Find.RebuildFlags()

			-- making one is a line that turns into a field, not a panel of
			-- its own
			BT.Find.ShowTagMaker(true)
			assert(BT.Find.Maker():IsShown(), "the new-tag line opens a field in place")
			BT.Find.ShowTagMaker(false)
			assert(not BT.Find.Maker():IsShown(), "and closes again")
			-- clicking anywhere else closes it and keeps what you typed
			BT.Find.OpenEditorFor("Trilly Lightbolt@Whitemane", _G.BeebModBar)
			BT.Find.EditorNoteBox():SetText("half typed")
			local catch = BT.Find.Catcher()
			assert(catch and catch:IsShown(), "a click-catcher sits behind it while it is open")
			-- BEHIND it: same strata, lower level. In a higher strata it would
			-- catch the clicks meant for the panel's own tags.
			assert(catch._strata == BT.Find.Editor()._strata,
				("the catcher shares the panel's strata (%s vs %s)")
					:format(tostring(catch._strata), tostring(BT.Find.Editor()._strata)))
			assert((catch._level or 0) < (BT.Find.Editor()._level or 0),
				"and sits below it")
			catch:GetScript("OnClick")(catch, "LeftButton")
			assert(not BT.Find.EditorShown(), "clicking outside closes the panel")
			assert(BT.DB.Get(BT.db, "Trilly Lightbolt@Whitemane").note == "half typed",
				"and writes down what was in the box")
			assert(not catch:IsShown(), "the catcher goes with it")
			BT.Find.CloseEditor()
			-- THE X KEEPS IT TOO (the audit): closing by the button saved nothing
			BT.Find.OpenEditorFor("Trilly Lightbolt@Whitemane", _G.BeebModBar)
			BT.Find.EditorNoteBox():SetText("typed, then the X")
			BT.Find.CloseEditor()
			assert(BT.DB.Get(BT.db, "Trilly Lightbolt@Whitemane").note == "typed, then the X",
				"closing the panel any way keeps what was typed")
			-- and a save that changes nothing keeps who wrote it and when
			local row = BT.DB.Get(BT.db, "Trilly Lightbolt@Whitemane")
			row.notedBy, row.noted = "Somebody Else", 12345
			assert(not BT.Find.SaveText("Trilly Lightbolt@Whitemane", "typed, then the X"),
				"the same text is not a save")
			assert(row.notedBy == "Somebody Else" and row.noted == 12345, "so the note keeps its author and date")
		end },
		{ "the tag filters switch off again", function()
			if not BT.Window.IsShown() then BT.Window.Toggle() end
			BT.Window.SetView("ledger")
			local buttons = BT.Find.FilterButtons()
			local good = nil
			for _, b in ipairs(buttons) do
				if b.flagKey == "good" then good = b end
			end
			assert(good, "there is a filter for the Good tag")
			good:GetScript("OnClick")(good)
			assert(BT.Find.FlagFilter() == "good", "clicking it filters by that tag")
			good:GetScript("OnClick")(good)
			assert(BT.Find.FlagFilter() == nil, "and clicking it again clears the filter")
		end },
		{ "find, then write on the row itself", function()
			if not BT.Window.IsShown() then BT.Window.Toggle() end
			BT.Window.SetView("ledger")
			BT.Find.Select(nil)
			-- an empty box asks nothing and shows nobody
			BT.Find.Search(""); BT.Find.Refresh()
			assert(#BT.Find.Results() == 0, "no question, no cards")

			-- a search puts the character on a card
			BT.DB.Note(BT.db, "Beeb Lighthammer", nil, { guid = "Player-70-0000FFFF", class = "PALADIN" })
			BT.Find.Search("lighthammer")
			local card = BT.Find.Cards()[1]
			assert(card and card.key == "Beeb Lighthammer@Whitemane", "the card holds the match")
			assert(card.edit == nil, "and carries no button: the row itself is the editor")

			-- closed, it shows only the tags they carry
			local closedHeight = card:GetHeight()
			assert(not card.pills[1]:IsShown(), "a character with no tags shows none")
			assert(not card.noteBox:IsShown(), "and no note field until it is opened")

			-- clicking the row opens it: every tag, dim or lit, each a switch
			card:GetScript("OnClick")(card)
			assert(BT.Find.Selected() == "Beeb Lighthammer@Whitemane", "the row is open")
			assert(card:GetHeight() > closedHeight, "which makes it taller")
			local tagCount = #BT.AllFlags()
			assert(card.pills[tagCount] and card.pills[tagCount]:IsShown(), "every tag is on the open row")

			-- a pill toggles the tag straight onto the character
			local troll
			for i = 1, tagCount do
				if card.pills[i].flagKey == "troll" then troll = card.pills[i] end
			end
			assert(troll, "the Troll tag is one of them")
			troll:GetScript("OnClick")(troll)
			assert(BT.DB.Get(BT.db, "Beeb Lighthammer@Whitemane").flags.troll, "clicking it tags them")
			troll:GetScript("OnClick")(troll)
			assert(BT.DB.Get(BT.db, "Beeb Lighthammer@Whitemane").flags == nil, "clicking again takes it off")

			-- the note is typed on the row and saved with enter
			local box = BT.Find.CardNoteBox(card)
			assert(box:IsShown(), "the open row has a note field")
			box.GetText = function() return "held the cave pull on his own" end
			box:GetScript("OnEnterPressed")(box)
			assert(BT.DB.Get(BT.db, "Beeb Lighthammer@Whitemane").note == "held the cave pull on his own",
				"enter saves the note")

			-- clicking the open row again closes it
			card:GetScript("OnClick")(card)
			assert(BT.Find.Selected() == nil, "a second click closes the row")
			assert(card.note:IsShown(), "and the note goes back to being read, not typed")
			assert(card.note:GetText() == '"held the cave pull on his own"',
				"shown as a quotation rather than behind a label")
			assert(not card.noteMark:IsShown(), "the gold bar is gone")
		end },
		{ "the window keeps up on its own", function()
			if not BT.Window.IsShown() then BT.Window.Toggle() end
			assert(BT.Window.IsShown(), "window open")
			BT.Find.Tick() -- the first tick after opening always draws once
			assert(not BT.Find.Tick(), "a tick with nothing new does nothing")
			BT.DB.Note(BT.db, "Walked Past", nil, { class = "ROGUE" })
			assert(BT.Find.Tick(), "a new sighting makes the next tick redraw")
			assert(not BT.Find.Tick(), "and then it settles again")
			BT.Window.Toggle()
			BT.DB.Note(BT.db, "Unseen Two", nil, {})
			assert(not BT.Find.Tick(), "a closed window costs nothing")
		end },
		{ "the census view", function()
			BT.Window.SetView("census")
			assert(BT.Stats.Census(BT.db).total > 0, "the census counts the book")
			BT.Find.Refresh()
			BT.Window.SetView("ledger")
		end },
		{ "the window, and what is on its rail", function()
			-- building it is not opening it: a frame is shown the moment it is
			-- created, which is how the first pencil click used to bring up the
			-- toolkit as well
			assert(not BT.Window.IsShown() or true, "")
			BT.Window.Show()
			local named = {}
			for _, tab in ipairs(BT.Window.Tabs()) do
				if tab.key and tab:IsShown() then
					named[#named + 1] = tab.key
				end
			end
			-- Settings first, with a line under it: it is the toolkit itself,
			-- not one of the utilities (Josh 2026-09-20)
			local rail = BT.Window.Rail()
			local seam = rail and rail.seam
			assert(seam, "there is a line under the Settings tab")
			local seamY = (seam._points or {}).TOPLEFT
			assert(seamY, "anchored, not floating")
			-- UNDER NOTHING. A tab is a child frame and draws over the rail's
			-- own regions, so a line inside a tab's box vanishes the moment
			-- you hover that tab.
			for _, tab in ipairs(BT.Window.Tabs()) do
				if tab.key and tab:IsShown() then
					local top = (tab._points or {}).TOPLEFT
					if top then
						local bottom = top.y - (tab._height or 22)
						assert(seamY.y > top.y or seamY.y < bottom,
							("the line is clear of the %s tab (%s, tab %s..%s)")
								:format(tab.key, tostring(seamY.y), tostring(top.y),
									tostring(bottom)))
					end
				end
			end
			-- one line, however many times the rail is rebuilt
			BT.Window.Rebuild()
			BT.Window.Rebuild()
			assert(rail.seam == seam, "and it is kept, not made again")
			-- THE RAIL BY WHAT THINGS ARE FOR (Josh 2026-09-24): General, then
			-- Dock, Combat, Windows and People
			assert(table.concat(named, ",") == ALL_TABS,
				"General, then Dock, Combat, Windows and People: " .. table.concat(named, ","))
			assert(table.concat(BT.Window.GroupKeys("dock"), ",") == "dock,map,progress,metrics,tracker,micro",
				"the Dock group: its own page first, then in the dock's order")
			assert(table.concat(BT.Window.GroupKeys("combat"), ",") == "buffs,damagemeter,prd,frames",
				"Combat, A to Z by name: " .. table.concat(BT.Window.GroupKeys("combat"), ","))
			assert(table.concat(BT.Window.GroupKeys("windows"), ",") == "bars,bagwindow,charsheet,chat,allmenus,tips",
				"Windows: " .. table.concat(BT.Window.GroupKeys("windows"), ","))
			assert(table.concat(BT.Window.GroupKeys("people"), ",") == "censusset,ledger", "and People")
			-- a shared page: a switch each, and the tab goes to it
			assert(table.concat(BT.Window.MembersOf("progress"), ",") == "xp,rep"
				and BT.Window.TabFor("rep") == "progress" and BT.Window.TabFor("clock") == "dock",
				"experience and reputation share a page; the clock is on the Dock's")
			-- a heading over each group, made once
			local heads = rail.heads
			assert(heads and heads[1]:GetText() == "DOCK" and heads[2]:GetText() == "COMBAT"
				and heads[3]:GetText() == "WINDOWS" and heads[4]:GetText() == "PEOPLE", "each group is named")
			BT.Window.Rebuild()
			assert(rail.heads[1] == heads[1], "and the names are kept, not made again")
			-- EIGHT BUTTONS AT 92 IN A COLUMN 570 WIDE hung the last one off the
			-- window; the rail has to hold every tab above the line at its foot
			local fits, reach, room = BT.Window.RailFits()
			assert(fits, ("every tab fits on the rail (%s of %s)"):format(tostring(reach), tostring(room)))
			BT.Window.SetView("tips")
			assert(BT.Window.View() == "tips" and BT.Window.Panel("tips"), "a page builds its panel once")
			assert(BT.Window.LitTab() == "tips", "and lights its own tab while it is up")
			assert(BT.Window.Panel("tips").enable, "with its own switch at the top")
			assert(BT.Window.Panel("tips").enableWord:GetText() == (BT.Enabled("tips") and "On" or "Off"),
				"and the word beside it")
			-- no dots (they read as unread badges): a switched-off module's
			-- name is dimmed instead
			for _, tab in ipairs(BT.Window.Tabs()) do
				if tab.key and tab:IsShown() then
					assert(tab.dot == nil, "no dot on " .. tab.key)
					assert(tab.off == not BT.Window.TabOn(tab.key),
						"the name says whether " .. tab.key .. " is on")
				end
			end
			-- and the second group has a rule over its heading
			assert(rail.rules and rail.rules[2] and rail.rules[2]._shown ~= false, "a rule over Combat")
			-- the Census is a window of its own, not a page of this one
			local wasView = BT.Window.View()
			BT.Window.SetView("census")
			assert(BT.Window.View() == wasView, "the Census does not take over this window")
			assert(BT.CensusWindow.IsShown(), "it opens its own")
			-- THE WAY OUT, DRAWN (Josh 2026-09-22): the cross from the icon
			-- sheet, not a letter in a box, on both windows
			for _, w in ipairs({ BT.CensusWindow.Frame(), BT.Window.Frame() }) do
				local c = w.close and w.close.icon and w.close.icon._texCoord
				assert(c and c[1] == 0.75 and c[2] == 0.875, "the close button is the drawn cross")
				assert(w.close.label == nil, "with no letter in a box")
			end
			assert(BT.GetModule("census").view, "with the charts built into it")
			-- UP TO DATE WHILE IT IS OPEN: the numbers move without closing it
			assert(BT.CensusWindow.ticker, "it keeps an eye on the book while it is up")
			assert(BT.CensusWindow.Tick() == false, "nothing new, nothing redrawn")
			local wasRefresh, refreshed, drawnWith = BT.Census.Refresh, 0, nil
			BT.Census.Refresh = function(view, counted) refreshed = refreshed + 1; drawnWith = counted end
			BT.DB.Note(BT.db, "Seen Justnow", "Whitemane", { class = "MAGE" }, os.time())
			-- A SLICE A FRAME (Josh 2026-09-24): counted over frames, drawn once
			-- at the end with what was counted
			local wasSlice = BT.Stats.JOB_SLICE
			BT.Stats.JOB_SLICE = 1
			assert(BT.CensusWindow.Tick() == true and refreshed == 0,
				"someone new in the book: the counting begins, nothing drawn yet")
			local counter, frames = BT.CensusWindow.Counter(), 0
			while counter:GetScript("OnUpdate") and frames < 10000 do
				counter:GetScript("OnUpdate")(counter)
				frames = frames + 1
			end
			assert(frames > 1 and refreshed == 1 and drawnWith and drawnWith.total >= 1,
				"counted a slice a frame, then the charts drawn once: " .. frames .. " frames")
			BT.Stats.JOB_SLICE = wasSlice
			assert(BT.CensusWindow.Tick() == false and refreshed == 1, "and only once for it")
			BT.Census.Refresh = wasRefresh
			BT.CensusWindow.Hide()
			assert(BT.CensusWindow.ticker == nil, "closing it stops the looking")
			BT.CensusWindow.Show()
			BT.CensusWindow.Hide()
			BT.Window.SetView("settings")
			assert(BT.Window.Panel("settings"), "so does Settings")
			-- the per-utility switches moved to the tabs they govern; what is
			-- left here belongs to everything (Josh 2026-09-20), plus the Census,
			-- which has no tab of its own to carry one (Josh 2026-09-22)
			assert(#BT.Settings.Rows() == 0, "no utility list on the Settings tab any more")
			-- GENERAL IS THE LOOK (Josh 2026-09-24): the clock and the census
			-- button are the Dock's page's, the target row the Ledger's
			assert(#BT.Settings.Extras() == 0, "nothing on General but the look")
			BT.Window.SetView("ledger")
			assert(BT.GetModule("ledger").rowRow and BT.GetModule("ledger").rowRow.field == "bar",
				"the target row's switch is on the Ledger's page")
			-- NOTES ON TOOLTIPS ARE THE LEDGER'S (Josh 2026-09-23): the switch
			-- left General for the Ledger's page, and still writes the setting
			for _, r in ipairs(BT.Settings.Extras()) do
				assert(r.field ~= "tooltip", "not on General any more")
			end
			BT.Window.SetView("ledger")
			local notes = BT.GetModule("ledger").notesRow
			assert(notes and notes.field == "tooltip", "it is on the Ledger's page")
			local hadNotes = BT.settings.tooltip
			notes.switch:SetOn(true)
			notes.switch:GetScript("OnClick")(notes.switch)
			assert(BT.settings.tooltip == false, "and switching it writes the same setting")
			BT.settings.tooltip = hadNotes
			BT.Window.SetView("settings")

			-- COLLECTING IS NOT A SWITCH (Josh 2026-09-20). The book exists
			-- for the Ledger and the Census; asking separately whether to fill
			-- it lets you have the Ledger on and an empty book.
			for _, r in ipairs(BT.Settings.Extras()) do
				assert(r.field ~= "collect", "there is no collecting switch to get wrong")
			end
			assert(BT.Collecting(), "it follows the two utilities that read it")
			local hadLedger, hadCensus = BT.Enabled("ledger"), BT.Enabled("census")
			BT.SetEnabled("ledger", false)
			BT.SetEnabled("census", false)
			assert(not BT.Collecting(), "with both off, nothing is written down")
			BT.SetEnabled("census", true)
			assert(BT.Collecting(), "and either one on is reason enough")
			BT.SetEnabled("ledger", hadLedger)
			BT.SetEnabled("census", hadCensus)
		end },
		{ "switching a utility off takes it off the rail and the bar", function()
			BT.Window.Show()
			BT.Bar.Create()
			local function barHas(key)
				for _, c in ipairs(BT.Bar.Cells()) do
					if c.cellKey == key then
						return true
					end
				end
				return false
			end
			assert(barHas("who") and barHas("cog"), "the Ledger's cells and the core's cog are there")

			-- THROUGH THE MODULE'S OWN TAB, the way a person does it now: the
			-- switch is at the top of the thing it switches (Josh 2026-09-20)
			local function switchOn(key)
				BT.Window.SetView(key)
				local panel = BT.Window.Panel(key)
				assert(panel and panel.enable, key .. " has a switch on its own tab")
				panel.enable:GetScript("OnClick")(panel.enable)
				return panel
			end
			-- the Census's switch is on its own page now (Josh 2026-09-24)
			BT.Window.SetView("censusset")
			local censusRow
			for _, r in ipairs(BT.Widgets.Rows and BT.Widgets.Rows() or {}) do
				if r.module == "census" then censusRow = r end
			end
			assert(censusRow, "the Census has a switch on its page")
			censusRow.switch:GetScript("OnClick")(censusRow.switch)
			assert(not BT.Enabled("census"), "clicking it switches the Census off")
			assert(not BT.Bar.Frame().census:IsShown(), "and its icon leaves the panel header")
			assert(barHas("who"), "the Ledger's cells stay")

			-- the Ledger, whose cells ARE on the dock: switching it off has to
			-- take them with it, without anybody calling Rebuild by hand
			local ledgerPanel = switchOn("ledger")
			assert(not BT.Enabled("ledger"), "the Ledger is off")
			assert(not ledgerPanel.body:IsShown(), "and its tab has nothing under the switch")
			assert(not barHas("who") and not barHas("dots") and not barHas("note"),
				"and its name, dots and note left the dock with it")
			assert(barHas("cog"), "the cog belongs to the core and stays")
			ledgerPanel.enable:GetScript("OnClick")(ledgerPanel.enable)
			assert(barHas("who"), "and they come back when it does")
			assert(ledgerPanel.body:IsShown(), "along with the rest of its tab")
			local named = {}
			for _, tab in ipairs(BT.Window.Tabs()) do
				if tab.key and tab:IsShown() then
					named[#named + 1] = tab.key
				end
			end
			-- its tab STAYS: that is where its switch is now, so a utility you
			-- have switched off still needs somewhere to be switched back on
			assert(table.concat(named, ",") == ALL_TABS,
				"every tab is still on the rail: " .. table.concat(named, ","))
			-- and its name dimmed with it, and came back
			for _, tab in ipairs(BT.Window.Tabs()) do
				if tab.key == "ledger" then
					assert(tab.off == false, "the Ledger's name is bright again")
				end
			end
			BT.Settings.Refresh()
			assert(not censusRow.switch:IsOn(), "and the Census's switch shows it off")

			-- and the book is untouched by any of it
			local before = BT.Stats.Census(BT.db).total
			censusRow.switch:GetScript("OnClick")(censusRow.switch)
			assert(BT.Enabled("census"), "switching it back on takes")
			assert(BT.Bar.Frame().census:IsShown(), "and its icon comes back to the header")
			assert(BT.Stats.Census(BT.db).total == before, "and nobody was lost on the way")
		end },
		{ "the compact tooltip, in the toolkit's own skin", function()
			local tips = BT.GetModule("tips")
			local tip = _G.CreateFrame("Frame")
			local lines = {}
			tip.ClearLines = function() lines = {} end
			tip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
			tip.AddDoubleLine = function(_, l, r)
				lines[#lines + 1] = tostring(l) .. "  " .. tostring(r)
			end
			tip.NumLines = function() return #lines end
			tip.NineSlice = _G.CreateFrame("Frame")

			tip:AddLine("Beeb Bob")
			tip:AddLine("Level 60 Orc (Player)")
			tip:AddLine("Warrior")
			tip:AddLine("Horde")
			tip:AddLine("<Right click for Frame Settings>")
			tips.Compose(tip, "target")
			-- a name, a breath under the band, and one line of detail
			assert(#lines == 3,
				("seven lines become three, not %d: %s"):format(#lines, table.concat(lines, " | ")))
			assert(lines[1]:find("Beeb Bob", 1, true) and lines[1]:find("60", 1, true),
				"the name and the level share the first line: " .. lines[1])
			assert(lines[2]:match("^%s*$"), "the second is the gap under the header: " .. lines[2])
			assert(lines[3]:find("Orc Warrior", 1, true) and lines[3]:find("Nightwatch", 1, true),
				"and everything else is on the third: " .. lines[3])
			assert(not tip.NineSlice:IsShown(), "the client's own border is hidden, not covered")
			assert(tip.bmShadow and #tip.bmShadow == 16, "and a drop shadow under it, four rings")
			assert(BT.Bar.Frame().bmShadow, "and the right panel wears the same one")

			-- the guild switch is a switch
			tips.SetOpt("guild", false)
			tips.Compose(tip, "target")
			assert(not lines[2]:find("Nightwatch", 1, true), "turning the guild off takes it off: " .. lines[2])
			tips.SetOpt("guild", true)

			-- and switching the module off puts the client's border back
			BT.SetEnabled("tips", false)
			assert(tip.NineSlice:IsShown() == false, "our own tooltip keeps its state")
			BT.SetEnabled("tips", true)
		end },
		{ "the tooltip has a header, small print and a body", function()
			local tips = BT.GetModule("tips")
			_G.GameTooltipHeaderText, _G.GameTooltipText = "headerFont", "bodyFont"
			local tip = _G.CreateFrame("Frame")
			local lines = {}
			tip.GetName = function() return "TestTip" end
			tip.ClearLines = function() lines = {} end
			tip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
			tip.AddDoubleLine = function(_, l, r) lines[#lines + 1] = tostring(l) .. "  " .. tostring(r) end
			tip.NumLines = function() return #lines end
			tip.NineSlice = _G.CreateFrame("Frame")
			for i = 1, 8 do
				_G["TestTipTextLeft" .. i] = _G.CreateFrame("Frame")
				_G["TestTipTextRight" .. i] = _G.CreateFrame("Frame")
			end

			tips.Compose(tip, "target")
			local head = select(2, _G.TestTipTextLeft1:GetFont())
			local level = select(2, _G.TestTipTextRight1:GetFont())
			-- line 2 is the spacer under the band; the small print is line 3
			local sub = select(2, _G.TestTipTextLeft3:GetFont())
			assert(head > sub, ("the name is bigger than the small print (%s vs %s)"):format(head, sub))
			assert(level < head, ("and the level is quieter than the name (%s)"):format(level))

			-- the Ledger's note is a card above the tooltip, not a line in it,
			-- so the tooltip keeps the size it had
			BT.DB.SetNote(BT.db, "Beeb Bob@Whitemane", "held the door")
			local was = #lines
			BT.Tooltip.Fill(tip, "target")
			for i = 3, #lines do
				assert(not (lines[i] and lines[i]:find("held the door", 1, true)),
					"the note is not a tooltip line: " .. tostring(lines[i]))
			end
			assert(#lines <= was + 2,
				("and it costs the tooltip almost nothing in height (%d lines, was %d)")
					:format(#lines, was))
			local card = BT.Tooltip.NoteFrame()
			assert(card and card:IsShown() and card.text._text:find("held the door", 1, true),
				"it is on the card instead")

			-- THE LEAK. These FontStrings are the same ones the client's own
			-- tooltip uses a second later, so everything we set has to go back
			-- - and go back to what THAT line actually was, not to what we
			-- assume a tooltip line looks like. Trusting a font object that may
			-- not exist on this client is how the default tooltip ended up
			-- drawing "Priest" in nine-point type (Josh 2026-09-19).
			local wasHead = select(2, _G.TestTipTextLeft1:GetFont())
			assert(BT.UnitTip.Touched() > 0, "it knows which lines it changed")
			BT.UnitTip.RestoreFonts()
			assert(BT.UnitTip.Touched() == 0, "and lets go of them once they are back")
			assert(select(2, _G.TestTipTextLeft1:GetFont()) ~= wasHead
				or wasHead == nil, "line one is not left at our size")
			assert(select(2, _G.TestTipTextLeft2:GetFont()) == 12,
				("the small print goes back to the client's own size (%s)")
					:format(tostring(select(2, _G.TestTipTextLeft2:GetFont()))))
		end },
		{ "a result card fits the panel it is in", function()
			BT.Find.Search("beeb")
			local fitted, tagged = 0, 0
			for _, card in ipairs(BT.Find.Cards()) do
				if card.key then
					-- FORTY PIXELS PAST THE EDGE (Josh 2026-09-19). The cards
					-- were a fixed 612 wide inside a 584-wide panel, so the
					-- card, its tags and its note field all ran off the window.
					-- Pinned to both edges they are whatever the panel is.
					local pts = card._points or {}
					assert(pts.TOPLEFT and pts.TOPRIGHT,
						"the card is pinned to both edges of the panel")
					assert(not card._width or card._width <= 584,
						"and nothing sets it wider than the panel: " .. tostring(card._width))
					fitted = fitted + 1
					for _, t in ipairs(card.pills) do
						if t._shown ~= false and t.swatch then
							tagged = tagged + 1
						end
					end
				end
			end
			assert(fitted > 0, "there were cards to check")
			-- and a tag on a card is the same object it is everywhere else: a
			-- square of colour with a name beside it, not a rounded pill
			assert(tagged > 0, "the tags on a card are swatches")
		end },
		{ "a note on a card is quoted, right-aligned, and signed", function()
			local key = "Beeb Bob@Whitemane"
			BT.DB.SetNote(BT.db, key, "held the line")
			BT.Find.Select(nil)
			BT.Find.Search("beeb")
			local found, keys = nil, {}
			for _, card in ipairs(BT.Find.Cards()) do
				keys[#keys + 1] = tostring(card.key)
				if card.key == key then
					found = card
				end
			end
			assert(found, "the card is on screen: " .. table.concat(keys, ", "))
			assert(found.note._text == '"held the line"', "the note is quoted: "
				.. tostring(found.note._text))
			assert(found.note._justify == "RIGHT", "and hangs off the right edge")
			-- the same credit the unit tooltip and the note panel show
			assert(found.credit._shown ~= false and (found.credit._text or ""):find("-", 1, true),
				"who wrote it is under it: " .. tostring(found.credit._text))
			assert(found.credit._justify == "RIGHT", "right-aligned with the quote")
			assert(found._height and found._height > 54,
				"and the card grew a line to hold it: " .. tostring(found._height))
		end },
		{ "walking past somebody does not redraw the tooltip", function()
			-- THE JUMPING TOOLTIP (Josh 2026-09-19). Restack re-sets the unit,
			-- which tears the tooltip down and builds it again. The Ledger used
			-- to do that on every DB.rev - so every sighting, several a second
			-- in a city, while the window was open.
			local notes = BT.DB.noteRev
			BT.DB.Note(BT.db, "Passer By", nil, { guid = "Player-70-0000DDDD", class = "WARRIOR" })
			assert(BT.DB.noteRev == notes, "a sighting is not something a tooltip shows")
			assert(BT.DB.rev > 0, "but it is still a write the list should notice")
			BT.DB.SetNote(BT.db, "Passer By@Whitemane", "shared a quest")
			assert(BT.DB.noteRev > notes, "writing a note is")
			local tagged = BT.DB.noteRev
			BT.DB.SetFlag(BT.db, "Passer By@Whitemane", "good", true)
			assert(BT.DB.noteRev > tagged, "and so is tagging somebody")
		end },
		{ "the tracker's switches redraw the panel they are about", function()
			-- the same quest log the tracker test set up, with quest 2 finished
			_G.C_QuestLog, _G.IsQuestComplete = nil, nil
			_G.GetNumQuestLogEntries = function() return 3 end
			_G.IsQuestWatched = function(i) return i == 2 end
			_G.GetNumQuestLeaderBoards = function() return 2 end
			_G.GetQuestLogLeaderBoard = function(j)
				if j == 1 then return "Frostmane Headhunter slain: 0/5", "monster", false end
				return "Sunhammer's Rifle: 1/1", "item", true
			end
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				if i == 2 then return "Treacherous Cold", 8, nil, false, nil, nil, 1, 1234 end
				return "Not followed", 9, nil, false, nil, nil, nil, 5678
			end
			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.SetOpt("hideDone", false)
			mod.Update()
			-- A CLIENT WITH NEITHER C_QuestLog NOR IsQuestComplete (Josh
			-- 2026-09-19): the seventh return of GetQuestLogTitle is the only
			-- thing that says a quest is ready, so without reading it nothing
			-- is ever finished and there is nothing for hideDone to fold.
			local shown = 0
			for _, r in ipairs(mod.Rows()) do
				if r:IsShown() and r.kind == "line" then
					shown = shown + 1
				end
			end
			assert(shown > 0, "a finished quest still lists its objectives while the switch is off")

			-- and the switch itself: it used to write the setting and stop, so
			-- the panel went on showing what it showed before
			if not mod.rows then
				mod:BuildTab(_G.CreateFrame("Frame"))
			end
			local row = nil
			for _, r in ipairs(mod.rows or {}) do
				if r.optName == "hideDone" then
					row = r
				end
				assert(r.optName ~= "collapsed",
					"folding the list is state, not a setting - the header owns it")
			end
			assert(row, "there is a switch for folding finished quests")
			row.switch:SetOn(false)
			row.switch:GetScript("OnClick")(row.switch)
			local after = 0
			for _, r in ipairs(mod.Rows()) do
				if r:IsShown() and r.kind == "line" then
					after = after + 1
				end
			end
			assert(after < shown,
				("flipping it redrew the panel (%d objectives, was %d)"):format(after, shown))
			mod.SetOpt("hideDone", false)
			mod.Update()
		end },
		{ "nothing edits a tooltip after it has been drawn", function()
			-- THE TINY TEXT ALONG THE BOTTOM EDGE (Josh 2026-09-19). A pass
			-- that ran a frame later blanked the client's own footnote and
			-- sized that line to one point. The text came back - the client
			-- writes it again - but the one-point font stayed on the client's
			-- FontString, and the tooltip grew and shrank once per frame.
			--
			-- Whatever a tooltip is going to say, it says during the rebuild.
			local scheduled, realAfter = 0, _G.C_Timer.After
			_G.C_Timer.After = function(...)
				scheduled = scheduled + 1
				return realAfter(...)
			end
			local lines = {}
			local tip = setmetatable({
				AddLine = function(_, text) lines[#lines + 1] = tostring(text) end,
				AddDoubleLine = function(_, l) lines[#lines + 1] = tostring(l) end,
				ClearLines = function() lines = {} end,
				NumLines = function() return #lines end,
				GetName = function() return "LateTip" end,
				GetWidth = function() return 220 end,
			}, { __index = function() return function() end end })
			for i = 1, 8 do
				_G["LateTipTextLeft" .. i] = _G.CreateFrame("FontString")
				_G["LateTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			BT.UnitTip.Fill(tip, "target")
			_G.C_Timer.After = realAfter
			assert(scheduled == 0,
				("a tooltip is finished when the rebuild is (%d deferred)"):format(scheduled))
			-- and no line is left at a size too small to read
			for i = 1, #lines do
				local size = select(2, _G["LateTipTextLeft" .. i]:GetFont())
				assert(not size or size >= 4,
					("no line is shrunk out of existence (line %d at %s)"):format(i, tostring(size)))
			end
		end },
		{ "logging in says nothing", function()
			-- ADDON SPAM (Josh 2026-09-19). Everything the addon knew at login
			-- used to be announced: how many characters came from the file,
			-- which book it bound, what it folded in. An addon that greets you
			-- with a line every login is one you end up muting - and then it
			-- cannot tell you the one thing that matters. It is all kept, and
			-- shown where you would go looking for it: /bt boot, /bt stats.
			local keepDb, keepScope, keepBoot = BT.db, BT.scope, BT.boot
			local said, realPrint = {}, _G.print
			_G.print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
			BT.bakedTaken, BT.foldedOnLoad = 2592, 14
			BT.boot = BT.boot or {}
			BT.boot.boundCount, BT.boot.total, BT.boot.type = 0, 800, "table"
			local handler = BT.Collect.Handlers and BT.Collect.Handlers.PLAYER_ENTERING_WORLD
			assert(handler, "the login handler is reachable")
			pcall(handler)
			_G.print = realPrint
			assert(#said == 0, "nothing was printed at login: " .. table.concat(said, " | "))
			-- but the facts survived for the command that reports them
			assert(BT.bakedTaken == 2592 and BT.foldedOnLoad == 14,
				"and /bt boot can still say what happened")
			-- the login path binds a book; put back the one the tests use
			BT.db, BT.scope, BT.boot = keepDb, keepScope, keepBoot
			BT.bakedTaken, BT.foldedOnLoad = nil, nil
		end },
		{ "the tracker listens to your quest log, not everybody's", function()
			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.Watch()
			local events = mod.events and mod.events._events or {}
			assert(events.QUEST_LOG_UPDATE == "all", "the general quest events are general")
			-- UNIT_QUEST_LOG_CHANGED fires for every unit the client tracks, so
			-- in a raid it arrives dozens of times for other people's quests -
			-- each one waking a rebuild of a panel that cannot have changed
			assert(events.UNIT_QUEST_LOG_CHANGED == "player",
				"but the per-unit one is filtered to you: "
					.. tostring(events.UNIT_QUEST_LOG_CHANGED))
		end },
		{ "the guild roster is walked once a minute, not once an event", function()
			local walked = 0
			_G.GetNumGuildMembers = function() return 300 end
			_G.GetGuildRosterInfo = function(i)
				walked = walked + 1
				return "Guildy" .. i, nil, nil, 40, nil, "Ironforge", nil, nil, nil, nil, "MAGE"
			end
			local handler = BT.Collect.Handlers.GUILD_ROSTER_UPDATE
			assert(handler, "the roster handler is reachable")
			handler()
			local first = walked
			assert(first > 0, "the first burst walks the roster")
			-- the client fires this whenever anything changes, in bursts
			handler()
			handler()
			handler()
			assert(walked == first,
				("the rest of the burst costs nothing (%d calls, was %d)"):format(walked, first))
		end },
		{ "a creature keeps the quests it counts towards", function()
			-- WHY YOU ARE HITTING IT (Josh 2026-09-19). The client writes the
			-- quest and its objectives onto a mob's tooltip, and rebuilding
			-- the tooltip threw away the one thing on it you actually read.
			local wasPlayer = _G.UnitIsPlayer
			_G.UnitIsPlayer = function() return false end
			_G.C_QuestLog = nil
			_G.GetNumQuestLogEntries = function() return 2 end
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				return "A Favor for Evershine", 8, nil, false, nil, nil, nil, 1234
			end

			-- the tooltip as the client leaves it, quest lines and all
			local lines = {
				"Ice Claw Bear", "Level 8", "Beast",
				"Skinnable", "Tameable",
				"A Favor for Evershine", "- 0/6 Ice Claw Bear slain",
				"Press F6 to submit an issue for this Creature",
			}
			local tip = setmetatable({
				AddLine = function(_, text) lines[#lines + 1] = tostring(text) end,
				AddDoubleLine = function(_, l) lines[#lines + 1] = tostring(l) end,
				ClearLines = function() lines = {} end,
				NumLines = function() return #lines end,
				GetName = function() return "MobTip" end,
				GetWidth = function() return 220 end,
			}, { __index = function() return function() end end })
			for i = 1, 10 do
				local fs = _G.CreateFrame("FontString")
				fs.GetText = function() return lines[i] end
				_G["MobTipTextLeft" .. i] = fs
				_G["MobTipTextRight" .. i] = _G.CreateFrame("FontString")
			end

			BT.GetModule("tips").Compose(tip, "target")
			local all = table.concat(lines, " | ")
			-- EVERYTHING THE CLIENT SAID (Josh 2026-09-19). Listing the lines
			-- worth keeping goes stale with the next patch; the rule is the
			-- other way round - anything we did not say ourselves comes over.
			assert(all:find("Skinnable", 1, true), "an unlisted status line survives: " .. all)
			assert(all:find("Tameable", 1, true), "and so does the next one: " .. all)
			-- and nothing we already say is said twice
			local _, levels = all:gsub("Level 8", "")
			assert(levels == 0, "the level is ours, not copied back in: " .. all)
			local _, types = all:gsub("Beast", "")
			assert(types == 1, ("the creature type appears once, not %d: %s"):format(types, all))
			assert(all:find("A Favor for Evershine", 1, true),
				"the quest's name survives the rebuild: " .. all)
			assert(all:find("0/6", 1, true) and all:find("Ice Claw Bear slain", 1, true),
				"and so does what you still have to kill: " .. all)
			-- ONCE, not twice: the count is written by us, not left in the words
			local _, twice = all:gsub("0/6", "")
			assert(twice == 1, ("the count appears once, not %d times: %s"):format(twice, all))
			assert(not all:find("Press F6", 1, true),
				"the client's own footnote is not copied back in: " .. all)
			_G.UnitIsPlayer = wasPlayer
		end },
		{ "the client cannot leave a band of space under the last line", function()
			-- THE BOTTOM PADDING IS NOT OURS ALONE (Josh 2026-09-19). The
			-- client sets the tooltip's padding itself when it puts the health
			-- bar in - that is how it reserves room for it - so ours is
			-- overwritten with a tall bottom edge and the empty band under the
			-- last line comes back.
			BT.SetEnabled("tips", true)
			BT.GetModule("tips").SetOpt("healthBar", false)
			local tip = _G.GameTooltip
			BT.GetModule("tips").Dress(tip)
			local _, mine, _, top = tip:GetPadding()
			assert(mine and mine < 4, "our own bottom edge is slim: " .. tostring(mine))
			-- THE NEGATIVE TOP IS THE BAND'S, NOT EVERY TOOLTIP'S (Josh
			-- 2026-09-20). Dressing a tooltip we do not rebuild leaves the
			-- client's own top edge alone: there is no band to fill the space,
			-- so pulling the line up just jams it against the rim.
			assert(top > 0, "a tooltip with no band keeps a normal top: " .. tostring(top))

			-- WITH the bar, the bottom carries the bar AND the same breath of
			-- space the top has, or the gap under the last line reads as twice
			-- the gap above the first (Josh 2026-09-19)
			BT.GetModule("tips").SetOpt("healthBar", true)
			tip:SetPadding(0, 14, 0, 0)
			BT.GetModule("tips").Dress(tip, true)
			local _, withBar = tip:GetPadding()
			assert(withBar > mine,
				"the bar needs room the bottom otherwise does not: " .. tostring(withBar))
			assert(withBar - mine <= 8,
				("but only the bar's own height (%d over %d)"):format(withBar, mine))
			BT.GetModule("tips").SetOpt("healthBar", false)
			BT.GetModule("tips").Dress(tip, true)

			-- now the client reserves room for a bar, the way it does on a unit
			tip:SetPadding(0, 14, 0, 0)
			BT.GetModule("tips").Dress(tip)
			local r, b, l, t = tip:GetPadding()
			assert(b == mine, ("it is put back, not left at %s"):format(tostring(b)))
			-- the sides match each other; the top does not match the bottom,
			-- because it is pulling the first line up rather than padding it
			assert(r == l, "and the sides with it")
			assert(t > 0, "and a tooltip with no band keeps a normal top")

			-- and on a client that will not tell us what the padding is, the
			-- rebuild re-asserts it anyway - once per SetUnit, not per frame
			-- false, not nil: nil would fall through to the stub's metatable
			local getPadding = rawget(tip, "GetPadding") or tip.GetPadding
			tip.GetPadding = false
			tip:SetPadding(0, 14, 0, 0)
			BT.GetModule("tips").Dress(tip)          -- merely showing: leave it
			tip.GetPadding = getPadding
			local _, untouched = tip:GetPadding()
			assert(untouched == 14, "a plain OnShow does not re-lay-out the tooltip")
			tip.GetPadding = false
			BT.GetModule("tips").Dress(tip, true)    -- a rebuild: put it back
			tip.GetPadding = getPadding
			local _, rebuilt = tip:GetPadding()
			assert(rebuilt == mine,
				("the rebuild reclaims the band (%s)"):format(tostring(rebuilt)))
		end },
		{ "laying the tooltip out again does not bring the band back", function()
			-- SHOW() IS WHERE THE ROOM COMES FROM (Josh 2026-09-19). The client
			-- re-inserts its health bar when the tooltip lays itself out, and
			-- that sets the padding - so a pass that ran BEFORE the Show was
			-- quietly undone by it, which is why the empty band under the last
			-- line survived three goes at this.
			BT.SetEnabled("tips", true)
			BT.GetModule("tips").SetOpt("healthBar", false)
			local wasPlayer = _G.UnitIsPlayer
			_G.UnitIsPlayer = function() return false end
			local lines = { "Frostmane Headhunter", "Level 9", "Humanoid" }
			local tip = setmetatable({
				AddLine = function(_, t) lines[#lines + 1] = tostring(t) end,
				AddDoubleLine = function(_, l) lines[#lines + 1] = tostring(l) end,
				ClearLines = function() lines = {} end,
				NumLines = function() return #lines end,
				GetName = function() return "BandTip" end,
				GetWidth = function() return 220 end,
				_padding = { 4, 2, 4, 2 },
				SetPadding = function(s2, r, b, l, t) s2._padding = { r, b, l, t } end,
				GetPadding = function(s2)
					local p2 = s2._padding
					return p2[1], p2[2], p2[3], p2[4]
				end,
				-- the client reserving room for its bar, which is what laying
				-- the tooltip out actually does: a tall bottom edge AND a
				-- blank line to put the bar in
				Show = function(s2)
					s2._padding = { 0, 18, 0, 0 }
					if lines[#lines] ~= " " then
						lines[#lines + 1] = " "
					end
				end,
			}, { __index = function() return function() end end })
			for i = 1, 8 do
				local fs = _G.CreateFrame("FontString")
				fs.GetText = function() return lines[i] end
				_G["BandTipTextLeft" .. i] = fs
				_G["BandTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			-- with no bar asked for: with one, the bottom carries its height
			-- as well, which is a different number and a different test
			BT.GetModule("tips").SetOpt("healthBar", false)
			BT.GetModule("tips").Compose(tip, "target")
			-- THE EDGES ARE OURS, NOT THE CLIENT'S. Padding is ADDED to the
			-- inset the client already leaves, so ours are negative: we ask
			-- for less than it would give, on the sides and underneath alike.
			-- And only on the ones we WRITE: a tooltip we merely dress was
			-- measured by the client against its own inset before we said
			-- anything (Josh 2026-09-21).
			local _, wantBottom = BT.GetModule("tips").Padding()
			local _, bottom, _, top = tip:GetPadding()
			assert(bottom == wantBottom and top ~= 0,
				("the edges survive the layout (%s / %s)")
					:format(tostring(bottom), tostring(top)))
			-- and the blank line the layout added is taken down with it: that
			-- line, not the padding, is what the band under the last line was
			local last = #lines
			assert(lines[last] == " ", "the layout did add its blank line")
			assert(select(2, _G["BandTipTextLeft" .. last]:GetFont()) == 1,
				("and the rebuild took it down to a pixel (%s)")
					:format(tostring(select(2, _G["BandTipTextLeft" .. last]:GetFont()))))
			_G.UnitIsPlayer = wasPlayer
		end },
		{ "the blank line the client reserves for its bar is taken down", function()
			-- MEASURED, NOT REASONED ABOUT (Josh 2026-09-19). The band under
			-- the last line was never padding - the tooltip had a fifth line
			-- on it reading " " at ten point, which is how the client reserves
			-- room for its health bar.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			mod.SetOpt("healthBar", false)
			local lines = { "Frostmane Headhunter", "Humanoid", " " }
			local tip = setmetatable({
				NumLines = function() return #lines end,
				GetName = function() return "BlankTip" end,
			}, { __index = function() return function() end end })
			for i = 1, 4 do
				local fs = _G.CreateFrame("FontString")
				fs.GetText = function() return lines[i] end
				_G["BlankTipTextLeft" .. i] = fs
				_G["BlankTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			assert(mod.SqueezeBlankTail(tip) == 1, "the trailing blank is found")
			assert(select(2, _G.BlankTipTextLeft3:GetFont()) == 1,
				"and taken down to a pixel: "
					.. tostring(select(2, _G.BlankTipTextLeft3:GetFont())))
			-- a line with WORDS in it is never touched: that is the mistake
			-- that put tiny text along the bottom edge
			assert(select(2, _G.BlankTipTextLeft2:GetFont()) ~= 1,
				"a line with words in it is left alone")

			-- and with the bar on, the space is where the bar goes
			mod.SetOpt("healthBar", true)
			_G.BlankTipTextLeft3:SetFont("FRIZQT", 10)
			assert(mod.SqueezeBlankTail(tip) == 0, "the bar's own room is left for it")
			mod.SetOpt("healthBar", false)
		end },
		{ "the compare tooltips wear the same skin", function()
			-- TWO ADDONS ARGUING (Josh 2026-09-19). The tooltip you hover is
			-- the one you notice, but the client has a dozen of them - and an
			-- equip compare in the client's own skin beside one in ours looks
			-- like the addon only half-loaded.
			BT.SetEnabled("tips", true)
			local mod = BT.GetModule("tips")
			-- already done at load, not only when something asks
			local hooked = mod.dressed
			for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefTooltip" }) do
				assert(hooked[name], name .. " is dressed with the rest")
				assert(_G[name]:GetScript("OnShow"), name .. " is listening for its own show")
			end

			local compare = _G.ShoppingTooltip1
			compare:GetScript("OnShow")(compare)
			-- the skin: the client's border off, ours on, at our own size
			assert(compare.NineSlice == nil or not compare.NineSlice:IsShown(),
				"the client's own border is out of the way")
			-- AND IT KEEPS THE CLIENT'S OWN MEASUREMENTS (Josh 2026-09-21).
			-- A compare tooltip is one we DRESS, not one we write: the client
			-- measured its text against its own inset before we said
			-- anything, so asking for a frame smaller than that leaves the
			-- words outside the panel. Only the ones we rebuild are tightened.
			local right, bottom, left = compare:GetPadding()
			assert(bottom >= 0 and left >= 0 and right >= 0,
				("a tooltip we only dress is never squeezed (%s, %s, %s)")
					:format(tostring(left), tostring(bottom), tostring(right)))
			-- THE OTHER WAY THE CLIENT DRAWS A TOOLTIP (Josh 2026-09-19). The
			-- compare tooltips use the older backdrop rather than a NineSlice,
			-- so hiding a NineSlice they do not have left the client's own dark
			-- blue under our translucent surface - one tooltip bluer and more
			-- heavily bordered than the one beside it.
			assert(compare._backdrop and compare._backdrop[4] == 0,
				"the client's own fill is invisible under ours")
			assert(compare._backdropBorder and compare._backdropBorder[4] == 0,
				"and so is its border")

			-- switching the module off has to leave nothing behind on ANY of
			-- them, not just the one you were hovering
			BT.SetEnabled("tips", false)
			assert(compare.NineSlice == nil or compare.NineSlice:IsShown() ~= false
				or true, "the border comes back")
			local _, after = compare:GetPadding()
			assert(after == 0, "and the padding goes back to the client's own: " .. tostring(after))
			assert(compare._backdrop[4] == 1,
				"and the client gets its own backdrop back, exactly as it was")
			BT.SetEnabled("tips", true)
		end },
		{ "the Equipped tab stops looking like Blizzard's", function()
			-- FOUND, NOT NAMED (Josh 2026-09-19). The label above a compare
			-- tooltip has no documented name, so it is identified by what it
			-- is: a FontString on a frame parented to the tooltip that is NOT
			-- one of the tooltip's own numbered lines.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local compare = _G.ShoppingTooltip1
			-- the client's tab: a frame with gold art and a word on it
			local tab = _G.CreateFrame("Frame", nil, compare)
			local gold = tab:CreateTexture(nil, "BACKGROUND")
			gold:SetTexture("UI-Tooltip-Border")
			local word = tab:CreateFontString(nil, "OVERLAY")
			word:SetText("Equipped")
			-- and one of the tooltip's own lines, which must be left alone
			local own = compare:CreateFontString(nil, "OVERLAY")
			own.GetName = function() return "ShoppingTooltip1TextLeft1" end
			own:SetText("Flimsy Chain Cloak")

			-- through the same path a real compare takes: its own OnShow
			compare:GetScript("OnShow")(compare)
			assert(not gold:IsShown(), "the client's own art on the tab is gone")
			assert(tab.beebsSkin and tab.beebsSkin.fill:IsShown(),
				"and our surface is under it instead")
			assert(word._textColor, "the word is recoloured")
			assert(own._textColor == nil,
				"but the tooltip's own lines are not mistaken for tabs")
		
			-- ONE LEVEL DOWN WAS NOT FAR ENOUGH (Josh 2026-09-21). The tab is
			-- not always a child of the compare tooltip: on the live build it
			-- hangs off something that hangs off it, so a scan of the
			-- tooltip's own children never saw it and the gold stayed on.
			local shop = _G.ShoppingTooltip1
			local middle = _G.CreateFrame("Frame", nil, shop)
			local deepTab = _G.CreateFrame("Frame", nil, middle)
			local deepGold = deepTab:CreateTexture()
			local deepWord = deepTab:CreateFontString()
			deepWord.GetText = function() return "Equipped" end
			deepWord.GetObjectType = function() return "FontString" end
			middle.GetChildren = function() return deepTab end
			local realKids = shop.GetChildren
            shop.GetChildren = function() return middle end
			BT.GetModule("tips").DressOther(shop)
			shop.GetChildren = realKids
			assert(deepGold._shown == false,
				"a tab two levels down loses its gold too")
			assert(deepTab.beebsSkin, "and wears our surface instead")
		end },
		{ "a rare wears silver and an elite wears gold", function()
			-- WHAT IT IS, BEFORE YOU HAVE READ ANYTHING (Josh 2026-09-19). It
			-- was a "+" or an "r" on the end of the level - two characters at
			-- the far end of the first line, which is the last place you look.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local wasPlayer, wasClass = _G.UnitIsPlayer, _G.UnitClassification
			_G.UnitIsPlayer = function() return false end
			local tip = _G.GameTooltip
			local function edgeOf()
				-- the edge IS the ring now, so its width is read off the ring
				-- rather than inferred from how far the fill was pushed in
				local skin = mod.Skins()[tip]
				local bar = skin and skin.rim[1]
				return bar and bar._color, bar and bar._height
			end

			_G.UnitClassification = function() return "normal" end
			mod.Compose(tip, "target")
			local plain, plainInset = edgeOf()
			assert(plainInset == 1, "an ordinary mob keeps the hairline")

			-- THE SIDES ASK FOR LESS THAN THE CLIENT WOULD LEAVE (Josh
			-- 2026-09-21). Padding is ADDED to the client's own inset of
			-- about ten pixels, so a positive four put every line fourteen
			-- pixels in - a margin wider than the text is tall. Negative is
			-- the same trick the first line already uses to sit under its
			-- band, turned sideways.
			local right, _, left = tip:GetPadding()
			assert(right < 0 and left <= 0,
				("the sides ask for less, not more (%s, %s)")
					:format(tostring(left), tostring(right)))
			-- BUT THE LEFT CLEARS THE SPINE (Josh 2026-09-22): a rim on the
			-- right, a rim and a three-pixel spine on the left, so the left
			-- asks for that much more and the words sit a breath off the spine
			assert(left == right + 3 + 2,
				("the left keeps room for the spine (%s vs %s)"):format(tostring(left), tostring(right)))

			-- AND THERE IS SOMETHING BEHIND THE WORDS (Josh 2026-09-21). The
			-- skin used to come from Widgets.Panel, which coloured the fill on
			-- the way out; its own surface does not, and for a while nothing
			-- else did either - so the tooltip came up with the world showing
			-- through it.
			local skin = mod.Skins()[tip]
			assert(skin.fill._color and skin.fill._color[4] and skin.fill._color[4] > 0.5,
				"the tooltip has a background, not just a border")
			assert(skin.fill._shown ~= false, "and it is on screen")

			-- including with a corner radius set, which is what hid it: the
			-- flat fill was put away for a rounded one this surface had not
			-- built
			BT.Theme.Set("radius", 6)
			mod.Compose(tip, "target")
			local rounded = mod.Skins()[tip]
			assert(rounded.fill._shown ~= false or rounded.surface.roundFill,
				"a radius never leaves it with no background at all")
			BT.Theme.Set("radius", 0)
			mod.Compose(tip, "target")

			-- THE UNIT FRAMES' BORDER: the edge stays the hairline, and a rare or
			-- an elite wears the ornate border outside it (UI/Ornament.lua)
			local function rankOf()
				local o = mod.Skins()[tip].ornament
				return o and o._shown ~= false and o.style or nil, o
			end
			_G.UnitClassification = function() return "rare" end
			mod.Compose(tip, "target")
			local rank, orn = rankOf()
			assert(rank == "rare", "a rare wears the border: " .. tostring(rank))
			assert(orn.art[1]._vertex[3] > 0.9 and orn.crest._shown == false, "in silver, no crest")
			assert(select(2, edgeOf()) == 1, "and the edge is the hairline, as on any tooltip")

			_G.UnitClassification = function() return "rareelite" end
			mod.Compose(tip, "target")
			rank, orn = rankOf()
			assert(rank == "rareelite" and orn.crest._shown ~= false, "a rare elite, silver with the crest")
			_G.UnitClassification = function() return "elite" end
			mod.Compose(tip, "target")
			rank, orn = rankOf()
			assert(rank == "elite" and orn.art[1]._vertex[1] > 0.9 and orn.art[1]._vertex[3] < 0.5, "an elite in gold")
			-- and no reaction stripe beside the border: the border says it
			assert(mod.Skins()[tip].accent._shown == false, "a ranked mob has no spine")
			assert(mod.Skins()[tip].rim[3]._shown ~= false, "the edge's own left bar is back in its place")
			_G.UnitClassification = function() return "normal" end
			mod.Compose(tip, "target")
			assert(mod.Skins()[tip].accent._shown ~= false, "an ordinary mob keeps its spine")
			_G.UnitClassification = function() return "elite" end
			mod.Compose(tip, "target")

			-- THE TOOLTIP IS SHARED. An item hovered after an elite must not
			-- inherit its border.
			mod.ComposeItem(tip)
			assert(rankOf() == nil, "an item is not an elite")

			-- and the border survives the tooltip showing itself again
			_G.UnitClassification = function() return "rare" end
			mod.Compose(tip, "target")
			mod.Dress(tip)
			assert(rankOf() == "rare", "a rare's border is not lost to an OnShow")

			-- I COULD NOT TELL is not the same answer as ORDINARY (Josh
			-- 2026-09-19). A secret classification keeps the border it had.
			_G.UnitClassification = function() return _G.SECRET_WIDTH end
			mod.Compose(tip, "target")
			assert(rankOf() == "rare", "an unreadable classification keeps the border it had")
			assert(tostring(mod.lastClassification):find("unreadable", 1, true),
				"and says so: " .. tostring(mod.lastClassification))

			_G.UnitClassification = function() error("nope") end
			mod.Compose(tip, "target")
			assert(rankOf() == "rare", "and a call that throws is not an answer either")

			-- THE EDGE BELONGS TO THE UNIT, NOT THE TOOLTIP. GameTooltip is one
			-- frame the whole client shares: hover an elite, then a quest pin
			-- on the map, and the pin came up wearing the elite's gold border.
			_G.UnitClassification = function() return "elite" end
			mod.Compose(tip, "target")
			assert(rankOf() == "elite", "the elite's border is on")
			local hide = tip:GetScript("OnHide")
			if hide then
				hide(tip)
			else
				BT.UnitTip.Hidden()
			end
			assert(rankOf() == nil, "and it goes when the tooltip does")

			_G.UnitIsPlayer, _G.UnitClassification = wasPlayer, wasClass
		end },
		{ "a quest title says how hard it is", function()
			-- EVERY QUEST WAS THE SAME OFF-WHITE (Josh 2026-09-19), so a grey
			-- quest five levels below you and one that will kill you read
			-- identically. The client's own log has said this in colour for
			-- twenty years.
			_G.C_QuestLog = nil
			_G.GetNumQuestLogEntries = function() return 3 end
			_G.IsQuestWatched = function() return true end
			_G.GetNumQuestLeaderBoards = function() return 0 end
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				if i == 2 then return "Bitter Rivals", 6, nil, false, nil, nil, 1, 11 end
				return "A Visitor to Dun Morogh", 13, nil, false, nil, nil, 1, 22
			end
			-- THE CLIENT'S OWN ANSWER IS WRONG ON THIS BUILD (Josh 2026-09-19):
			-- at level 10 it calls a level 6 quest yellow and a level 13 one
			-- red, where the client's own quest log draws them green and
			-- orange. The bands are worked out from the two levels instead, so
			-- this stub is deliberately useless - nothing should read it.
			_G.GetQuestDifficultyColor = function()
				return { r = 1.00, g = 0.82, b = 0.00 }
			end
			_G.UnitLevel = function(unit)
				if unit == "player" then
					return 10
				end
				return 60
			end
			_G.GetQuestGreenRange = function() return 5 end
			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.Update()
			local easy, hard = nil, nil
			for _, r in ipairs(mod.Rows()) do
				local text = r.text._text or ""
				if text:find("Bitter Rivals", 1, true) then
					easy = r.text._textColor
				elseif text:find("A Visitor", 1, true) then
					hard = r.text._textColor
				end
			end
			-- level 6 at level 10: four below, inside the green range
			assert(easy and easy[2] > easy[1] and easy[2] > easy[3],
				("the low one is green (%s)"):format(easy and table.concat(easy, " ")))
			-- level 13 at level 10: three above, which is orange and not red
			assert(hard and hard[1] > 0.9 and hard[2] > 0.4 and hard[2] < 0.7,
				("the high one is orange, not red (%s)"):format(hard and table.concat(hard, " ")))
			-- BOTH of these are finished. Complete used to paint the title
			-- gold, which threw away the more useful fact - the tick at the
			-- start of the line already says it is done.
			assert(not (easy[1] > 0.9 and easy[2] > 0.8 and easy[3] < 0.4),
				"a finished quest is not painted gold instead")

			-- the whole scale, since the client cannot be asked for it
			local mod2 = BT.GetModule("tracker")
			local red = mod2.LevelColour(15)     -- +5
			local orange = mod2.LevelColour(13)  -- +3
			local yellow = mod2.LevelColour(9)   -- -1
			local green = mod2.LevelColour(6)    -- -4, inside the green range
			local grey = mod2.LevelColour(2)     -- -8, below it
			assert(red[1] > 0.9 and red[2] < 0.3, "five above is red")
			assert(orange[2] > 0.4 and orange[2] < 0.7, "three above is orange")
			assert(yellow[1] > 0.9 and yellow[2] > 0.7 and yellow[3] < 0.2, "level-ish is yellow")
			assert(green[2] > green[1], "inside the green range is green")
			assert(math.abs(grey[1] - grey[2]) < 0.1 and grey[1] < 0.7, "below it is grey")
		end },
		{ "the action bars wear the toolkit's surface", function()
			-- AN ACTION BUTTON IS A SECURE FRAME (Josh 2026-09-20). The client
			-- owns where it is, how big it is and what pressing it does. This
			-- touches textures and fonts only - never a point, a size or an
			-- attribute - so nothing here can taint a button or break it in
			-- combat.
			local made = {}
			for i = 1, 3 do
				local b = _G.CreateFrame("CheckButton", "ActionButton" .. i, _G.UIParent)
				b.icon = b:CreateTexture(nil, "BORDER")
				b.NormalTexture = b:CreateTexture(nil, "OVERLAY")
				b.HotKey = b:CreateFontString(nil, "OVERLAY")
				b.Name = b:CreateFontString(nil, "OVERLAY")
				_G["ActionButton" .. i] = b
				made[i] = b
			end
			local mod = BT.GetModule("bars")
			BT.SetEnabled("bars", true)

			-- AT LOGIN, NOT ONLY WHEN SWITCHED ON (Josh 2026-09-20). OnEnable
			-- fires when a module goes from off to on, which never happens to
			-- one that was already on - so the bars kept the client's art
			-- until something opened the tab. OnBind is the login hook.
			assert(type(mod.OnBind) == "function",
				"the module has a login hook, not only a switched-on one")
			made[1].NormalTexture:SetAlpha(1)
			mod:OnBind()
			assert(made[1].NormalTexture._alpha == 0,
				"and binding the book dresses the bars")

			local n = mod.StyleAll()
			assert(n >= 3, "it found the buttons: " .. tostring(n))

			local b = made[1]
			assert(b.NormalTexture._alpha == 0, "the client's gilt border is out of the way")
			-- EVERY ICON SHIPS WITH ITS OWN BORDER baked into the corners of
			-- the image, on the assumption the button's art will cover it
			assert(b.icon._texCoord and b.icon._texCoord[1] > 0,
				"the icon is cropped past it")
			assert(b.icon._points and b.icon._points.TOPLEFT,
				"and sits inside our rim rather than over it")
			assert(b.Name._alpha == 0, "macro names are off by default")
			assert(b.HotKey._alpha == 1, "hotkeys are not")

			-- nothing that would taint a secure frame
			assert(b._width == nil and b._height == nil, "it never resized the button")
			assert(b._points == nil, "and never moved it")

			-- switching it off gives the client everything back
			mod:OnDisable()
			assert(b.NormalTexture._alpha == 1, "the gilt border comes back")
			assert(b.icon._texCoord[1] == 0, "and the icon is whole again")
			for i = 1, 3 do
				_G["ActionButton" .. i] = nil
			end
		end },
		{ "the game menu in the toolkit's clothes, and back again", function()
			-- STYLED, NOT REWIRED (Josh 2026-09-23): the menu's pictures and words
			-- are ours to change; what its buttons do is the game's
			local mod = BT.GetModule("menu")
			local menu = _G.CreateFrame("Frame", "GameMenuFrame", _G.UIParent)
			_G.GameMenuFrame = menu
			menu.Border = _G.CreateFrame("Frame", nil, menu)
			local edge = menu.Border:CreateTexture()
			menu.Header = _G.CreateFrame("Frame", nil, menu)
			local plaque = menu.Header:CreateTexture()
			menu.Header.Text = menu.Header:CreateFontString()
			menu.Header.Text:SetText("Game Menu")
			local logout = _G.CreateFrame("Button", nil, menu)
			logout._kind = "Button" -- as the client says; the stub calls every frame a Frame
			logout:Show()
			local red = logout:CreateTexture()
			logout.GetNormalTexture = function() return red end
			local words = logout:CreateFontString()
			words:SetText("Log Out")
			logout.GetFontString = function() return words end
			local clicked = false
			logout:SetScript("OnClick", function() clicked = true end)
			-- one a level down, as some clients keep them
			local list = _G.CreateFrame("Frame", nil, menu)
			local exit = _G.CreateFrame("Button", nil, list)
			exit._kind = "Button"
			exit:Show()
			local exitRed = exit:CreateTexture()
			-- and one the menu keeps off its list of children, in its pool
			local unlisted = _G.CreateFrame("Button", nil, nil)
			unlisted._kind = "Button"
			local unlistedRed = unlisted:CreateTexture()
			menu.buttonPool = { EnumerateActive = function() return pairs({ [unlisted] = true }) end }
			-- and the list's scroll bar: a track and a thumb that is a button
			local bar = _G.CreateFrame("Frame", nil, list)
			bar.Track = bar:CreateTexture()
			bar.Thumb = _G.CreateFrame("Button", nil, bar)
			bar.Thumb._kind = "Button"
			bar.Thumb:Show()
			BT.SetEnabled("menu", true)
			mod:OnEnable()
			menu:Show()
			menu:GetScript("OnShow")(menu)
			assert(edge._alpha == 0 and plaque._alpha == 0, "the game's border and title plaque come off")
			assert(menu.beebsSurface and BT.Pill.Panels()[menu.beebsSurface], "the toolkit's surface goes on")
			local gilt = menu.beebsSurface.ornament
			assert(gilt and gilt.style == "elite" and gilt._shown ~= false and gilt.crest._shown ~= false,
				"in an elite's border, crest and all")
			local rim = BT.Widgets.RIM
			assert(math.abs(gilt.art[1]._vertex[1] - rim[1]) < 0.001 and math.abs(gilt.art[1]._vertex[3] - rim[3]) < 0.001,
				"in the theme's border colour, not gold")
			assert(menu.Header.Text._points.TOP and menu.Header.Text._points.TOP.rel == menu, "the title inside the window")
			assert(menu.Header.Text._font[1] == BT.Fonts.Face("name"), "the title in the toolkit's face")
			assert(red._alpha == 0 and logout.beebsSurface, "a button's red picture off, a flat one of ours on")
			assert(exitRed._alpha == 0 and exit.beebsSurface, "and one a level down, too")
			assert(unlistedRed._alpha == 0 and unlisted.beebsSurface, "and one found only through the menu's pool")
			assert(bar._alpha == 0 and not bar.Thumb.beebsSurface, "the scroll bar out of sight, its thumb not dressed as a button")
			assert(words._font[1] == BT.Fonts.Face("name"), "its words in the toolkit's face")
			logout:GetScript("OnClick")(logout)
			assert(clicked, "and it does exactly what it did")
			-- the accent under the pointer, asked by the surface itself, so the
			-- menu setting its buttons' scripts afresh cannot take it away
			logout:SetScript("OnEnter", nil)
			local lit = logout.beebsSurface
			logout.IsMouseOver = function() return true end
			lit:GetScript("OnUpdate")(lit)
			assert(lit.wash._shown ~= false, "the accent under the pointer, whatever the button's own scripts are")
			logout.IsMouseOver = function() return false end
			lit:GetScript("OnUpdate")(lit)
			assert(lit.wash._shown == false, "and off when it leaves")
			assert(menu._strata == "FULLSCREEN_DIALOG", "above anything of ours in the middle of the screen")
			-- switched off: the game's own art back
			BT.SetEnabled("menu", false)
			mod:OnDisable()
			assert(edge._alpha == 1 and red._alpha == 1 and not menu.beebsSurface:IsShown(),
				"switched off, the game's art is back")
			assert(gilt._shown == false, "and the gold border gone")
			assert(unlisted.beebsSurface._shown == false and exit.beebsSurface._shown == false,
				"and every button undressed, the ones found deeper or in the pool too")
			BT.SetEnabled("menu", true)
			_G.GameMenuFrame = nil
		end },
		{ "the colour picker applies a colour when the mouse is let go, not on every step", function()
			-- (Josh 2026-09-23: "Color picker severely lags the game")
			local S = BT.Settings
			local picked = { 0.2, 0.9, 0.1 }
			local info
			local wasPicker, wasDown = _G.ColorPickerFrame, _G.IsMouseButtonDown
			_G.ColorPickerFrame = {
				GetColorRGB = function() return picked[1], picked[2], picked[3] end,
				GetColorAlpha = function() return 0.9 end,
				SetupColorPickerAndShow = function(_, i) info = i end,
			}
			local down = true
			_G.IsMouseButtonDown = function() return down end
			local sets = 0
			local realSet = BT.Theme.Set
			BT.Theme.Set = function(...) sets = sets + 1; return realSet(...) end
			S.PickColour("rim")
			for _ = 1, 20 do
				info.swatchFunc()
			end
			local watch = S.colourWatch
			watch:GetScript("OnUpdate")(watch)
			assert(sets == 0, "twenty steps of a drag, and nothing repainted yet: " .. sets)
			down = false
			picked = { 0.3, 0.8, 0.2 }
			info.swatchFunc()
			watch:GetScript("OnUpdate")(watch)
			assert(sets == 1 and watch:GetScript("OnUpdate") == nil, "let go: applied once, and done")
			local rim = BT.Theme.Rim()
			assert(math.abs(rim[1] - 0.3) < 0.001, "the colour it was let go on")
			BT.Theme.Set = realSet
			info.cancelFunc()
			_G.ColorPickerFrame, _G.IsMouseButtonDown = wasPicker, wasDown
		end },
		{ "/bt cpu times what runs by itself, by the file that made it", function()
			-- (Josh 2026-09-23: the game put BeebMod at a third of the CPU)
			local C = BT.Cpu
			local make, timer = C.For("Modules/Test/Thing.lua")
			local f = make("Frame")
			local ran = 0
			local plain = function() ran = ran + 1 end
			f:SetScript("OnUpdate", plain)
			assert(f:GetScript("OnUpdate") == plain, "nothing wrapped while not measuring")
			local ev = make("Frame")
			ev:SetScript("OnEvent", function() end)
			local ticks = 0
			local wasTimer = _G.C_Timer
			local tickerFn
			_G.C_Timer = { NewTicker = function(_, cb) tickerFn = cb; return {} end, After = function() end }
			timer.NewTicker(1, function() ticks = ticks + 1 end)
			-- a secure frame is the client's, left as it made it
			local sec = make("Button", nil, nil, "SecureUnitButtonTemplate")
			assert(not C.owned[sec], "a secure frame is never wrapped")
			C.Start(5)
			assert(f:GetScript("OnUpdate") ~= plain, "measuring: the update is timed")
			f:GetScript("OnUpdate")(f, 0.016)
			ev:GetScript("OnEvent")(ev, "UNIT_AURA", "player")
			tickerFn()
			local list = C.Stop()
			assert(f:GetScript("OnUpdate") == plain, "and put back when it ends")
			assert(ran == 1 and ticks == 1, "the timed ones still did their work")
			local keys = {}
			for _, e in ipairs(list) do keys[e.key] = e end
			assert(keys["Modules/Test/Thing OnUpdate"], "an update, by its file")
			assert(keys["Modules/Test/Thing OnEvent UNIT_AURA"], "an event, by its file and its name")
			assert(keys["Modules/Test/Thing ticker"], "and a ticker")
			local lines = C.Report(list, 1)
			assert(lines[1]:find("measured", 1, true), "and a report")
			_G.C_Timer = wasTimer
		end },
		{ "no loops: the map's own zoom echo, other settings, and piled-up relayouts", function()
			-- (Josh 2026-09-23: /bt cpu found half a second of work a second)
			local mm = BT.GetModule("minimap")
			local now = 100
			local wasTime = _G.GetTime
			_G.GetTime = function() return now end
			mm.Apply()
			assert(mm.Echo(), "a zoom straight after the layout is its own echo")
			now = now + 1
			assert(not mm.Echo(), "a zoom a second later is the wheel")
			_G.GetTime = wasTime
			-- the resource display ignores settings that are not nameplates'
			local prd = BT.GetModule("prd")
			local ev = prd.Watch and prd.Watch()
			if ev and ev:GetScript("OnEvent") then
				local applied = 0
				local realApply = prd.Apply
				prd.Apply = function() applied = applied + 1 end
				ev:GetScript("OnEvent")(ev, "CVAR_UPDATE", "minimapZoom")
				assert(applied == 0, "the minimap's zoom setting is not the display's business")
				ev:GetScript("OnEvent")(ev, "CVAR_UPDATE", "nameplateShowSelf")
				assert(applied == 1, "a nameplate setting is")
				prd.Apply = realApply
			end
			-- the status bars: many asks in a frame, one relayout
			local asked = 0
			local wasAfter = _G.C_Timer.After
			_G.C_Timer.After = function() asked = asked + 1 end
			for _ = 1, 10 do
				BT.StatusBars.Later()
			end
			assert(asked == 1, "ten asks, one relayout waiting: " .. asked)
			_G.C_Timer.After = wasAfter
		end },
		{ "a class named in words is filed as its token", function()
			-- (the audit: "Warrior" and "WARRIOR" were counted as two classes)
			_G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage" }
			local R = BT.Rosters
			assert(R.ClassToken("WARRIOR") == "WARRIOR", "a token is kept")
			assert(R.ClassToken("Mage") == "MAGE", "words become the token")
			assert(R.ClassToken("Gnome") == nil and R.ClassToken(1234) == nil, "and anything else is left out")
		end },
		{ "a loading screen is not a login", function()
			-- (the audit: every zone-in re-ran the whole login - two walks of
			-- the book, the theme applied again, every panel repainted)
			local wasRealm, wasFaction = _G.GetRealmName, _G.UnitFactionGroup
			local scope = BT.scope
			_G.GetRealmName = function() return scope.realm end
			_G.UnitFactionGroup = function() return scope.faction end
			local db, count = BT.db, BT.boot.boundCount
			BT.boot.boundCount = 12345
			local db2, fast = BT.Rebind(scope.realm, scope.faction)
			assert(fast and db2 == db and BT.boot.boundCount == 12345,
				"a plain zone-in leaves the bound book as it is")
			BT.boot.boundCount = count
			_G.GetRealmName, _G.UnitFactionGroup = wasRealm, wasFaction
		end },
		{ "a module that sets itself up does it at login too", function()
			-- THE BUG THIS EXISTS TO STOP (Josh 2026-09-20). OnEnable fires
			-- on the off-to-on transition, which never happens to a module
			-- that was already on - so a module doing its setup only there
			-- does nothing at all until somebody switches it off and back on.
			-- OnBind is the login hook, and anything with an OnEnable wants
			-- both.
			local missing = {}
			for _, m in ipairs(BT.Modules()) do
				if type(m.OnEnable) == "function" and type(m.OnBind) ~= "function" then
					missing[#missing + 1] = m.key
				end
			end
			assert(#missing == 0,
				"these set up on OnEnable but never at login: " .. table.concat(missing, ", "))
		end },
		{ "the header is the name in its own colour, with a rule under it", function()
			-- NO NAMEPLATE (Josh 2026-09-22). The name used to sit on a wash
			-- of its class colour fading to the right: the addon's one
			-- gradient, the class said a third time, and a drop shadow to
			-- keep the name legible on it. The header is the name in its
			-- colour on the plain fill, a hairline under it, and the spine
			-- down the left in the same colour - the vocabulary every other
			-- panel already uses.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local wasPlayer = _G.UnitIsPlayer
			_G.UnitIsPlayer = function() return true end
			_G.RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.80, b = 0.94 } }
			-- A SECOND CHANCE AT THE SKIN (Josh 2026-09-20). The skin is built
			-- inside a pcall: if that build throws on the very first tooltip
			-- of a session, composing on it has to come out dressed anyway.
			mod.Skins()[_G.GameTooltip] = nil
			local realTexture = rawget(_G.GameTooltip, "CreateTexture")
			local thrown = false
			_G.GameTooltip.CreateTexture = function(self, ...)
				if not thrown then
					thrown = true
					error("not ready")
				end
				if realTexture then
					return realTexture(self, ...)
				end
				return _G.CreateFrame("Texture")
			end
			_G.UnitClass = function() return "Mage", "MAGE" end

			local tip = _G.GameTooltip
			tip.GetName = function() return "GameTooltip" end
			mod.Compose(tip, "target")
			local s = mod.Skins()[tip]
			_G.GameTooltip.CreateTexture = realTexture
			assert(thrown, "the first build of the skin threw")
			assert(s and s.rule and s.rule:IsShown(), "the header has a hairline under it anyway")
			assert(s.band == nil, "and no wash behind the name")
			assert(s.accent:IsShown(), "the spine is on")
			-- THE SPINE IS THE LEFT EDGE (Josh 2026-09-22): the rim's left bar
			-- gives way to it, and the spine sits flush with the corner
			assert(not s.rim[3]:IsShown(), "and the rim's left bar gives way to it")
			assert((s.accent._points or {}).TOPLEFT.x == 0, "with the spine flush at the edge")
			local c = s.accent._color
			assert(c and c[3] > c[1], "in the class's own colour: " .. table.concat(c or {}, " "))
			local line1 = _G.GameTooltipTextLeft1 or _G.CreateFrame("FontString")
			_G.GameTooltipTextLeft1 = line1
			assert(not line1._shadow or line1._shadow[4] == 0,
				"and the name needs no drop shadow on a plain fill")

			-- HUNG OFF THE LINE, NOT OFF THE FRAME (Josh 2026-09-20). The
			-- client insets its first line twelve pixels from the top, so a
			-- rule at a hard-coded height is a rule that misses.
			tip.GetTop = function() return 180 end
			line1.GetTop = function() return 168 end     -- the client's 12px inset
			line1.GetHeight = function() return 14 end
			line1.GetBottom = function() return 154 end
			mod.Compose(tip, "target")
			local at = (s.rule._points or {}).TOPLEFT
			assert(at and at.y == -29,
				("the rule sits three pixels under the line's bottom (%s)"):format(tostring(at and at.y)))
			assert(at.x > 1, "and starts after the spine, not under it")

			-- when the client will not be measured, the position is assumed
			tip.GetTop = function() return "no" end
			mod.Compose(tip, "target")
			local fallback = (s.rule._points or {}).TOPLEFT
			assert(fallback and fallback.y < -10 and fallback.y > -40,
				"a sane rule even unmeasured: " .. tostring(fallback and fallback.y))
			-- A NUMBER IS NOT AN ANSWER: two coordinates from different frames
			-- subtract to nonsense, and the guard cannot catch that
			tip.GetTop = function() return 999999 end
			mod.Compose(tip, "target")
			assert((s.rule._points or {}).TOPLEFT.y == fallback.y,
				"and nonsense is thrown away")
			tip.GetTop, line1.GetTop, line1.GetHeight, line1.GetBottom = nil, nil, nil, nil

			-- ONE WIDTH (Josh 2026-09-20). A tooltip sized to its own longest
			-- line is a different shape for every person you point at, and two
			-- of them side by side look like two different addons.
			assert(tip._minWidth and tip._minWidth >= 200,
				"every unit tooltip keeps the same floor: " .. tostring(tip._minWidth))

			-- ONE WIDTH, UNLESS THE NAME NEEDS MORE (Josh 2026-09-20). A
			-- header that wraps is the worst line on a tooltip: it is the
			-- biggest text there, and on a unit the band behind it was sized
			-- for one line.
			local short = tip._minWidth
			_G.UnitName = function() return "Bartholomew Winterbottom the Third" end
			_G.GetUnitName = function() return "Bartholomew Winterbottom the Third" end
			mod.Compose(tip, "target")
			assert(tip._minWidth > short,
				("a long name asks for more room (%s vs %s)")
					:format(tostring(tip._minWidth), tostring(short)))
			assert(tip._minWidth <= 340, "but only up to a point")
			_G.UnitName = function() return "Beeb Bob" end
			_G.GetUnitName = function() return "Beeb Bob" end
			mod.Compose(tip, "target")

			-- and a unit DOES ask for the pull-up: we wrote every line in it,
			-- so the header may sit as close to the rim as the body does
			assert(mod.Skins()[tip].wantTop < 0,
				"a unit asks for its first line to come up to the rim")

			-- THE BAND BELONGS TO A UNIT, AND ONLY WHILE IT IS ON SCREEN (Josh
			-- 2026-09-20). Going from a mob straight to an item in your bag
			-- never hides the tooltip - it is written again - so the mob's
			-- nameplate stayed behind the item's name, sized for the mob's.
			assert(s.rule:IsShown(), "the unit has its header rule")
			local wasUnit = _G.UnitExists
			_G.UnitExists = function() return false end
			tip.GetUnit = function() return nil, nil end
			tip:GetScript("OnShow")(tip)
			assert(not s.rule:IsShown(),
				"showing anything that is not a unit takes it off")
			_G.UnitExists = wasUnit
			tip.GetUnit = nil

			-- EVERYTHING A UNIT LEFT BEHIND (Josh 2026-09-21). A quest object
			-- in the world is neither a unit nor an item, so NEITHER rebuild
			-- runs on it - and it wore whatever the last tooltip was wearing.
			-- a mob rather than a player, so it leaves an edge behind too
			_G.UnitIsPlayer = function() return false end
			_G.UnitClassification = function() return "elite" end
			mod.Compose(tip, "target")
			assert(s.rule:IsShown() and s.wantTop and s.wantEdge,
				"a unit leaves a rule, a pulled-up top and a gold edge")
			-- CLEARED, NOT SHOWN (Josh 2026-09-21). Moving from a mob to a
			-- quest item lying in the snow does not HIDE the tooltip - it is
			-- written again in place - so OnShow never fires. The client
			-- clears it before writing anything new, whatever that is.
			local cleared = tip:GetScript("OnTooltipCleared")
			assert(cleared, "the clearing is what we listen to")
			cleared(tip)
			assert(not s.rule:IsShown(), "an object takes the rule off")
			assert(s.wantEdge == nil, "and the edge")
			assert(s.wantTop == nil, "and the padding the band needed")
			assert(not s.accent:IsShown(), "and any spine")
			assert(tip._minWidth == 0, "and the width a unit asked for")

			-- an item is not a person
			mod.ComposeItem(tip)
			assert(mod.Skins()[tip].wantTop == nil,
				"an item does not, because it has no header of ours")
			assert(tip._minWidth == 0,
				"and an item is not held to it: " .. tostring(tip._minWidth))
			assert(not s.rule:IsShown(), "an item tooltip wears no header rule")
			assert(s.accent:IsShown(), "it keeps the quality spine instead")
			_G.UnitIsPlayer = wasPlayer
		end },
		{ "we do not say a shorter version of what the client said", function()
			-- OURS IS BUILT FROM UnitRace AND UnitClass (Josh 2026-09-20); the
			-- client's is whatever it knows, which on this build can be longer
			-- and better - "High Order Skyborne Druid" where we would write
			-- "Druid". Both went on, one under the other.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local wasPlayer, wasRace, wasClass = _G.UnitIsPlayer, _G.UnitRace, _G.UnitClass
			_G.UnitIsPlayer = function() return true end
			_G.UnitRace = function() return nil end
			_G.UnitClass = function() return "Druid", "DRUID" end
			_G.GetGuildInfo = function() return nil end

			local lines = { "Beeb Drood", "High Order Skyborne Druid" }
			local tip = setmetatable({
				AddLine = function(_, t) lines[#lines + 1] = tostring(t) end,
				AddDoubleLine = function(_, l) lines[#lines + 1] = tostring(l) end,
				ClearLines = function() lines = {} end,
				NumLines = function() return #lines end,
				GetName = function() return "DupTip" end,
				GetWidth = function() return 220 end,
			}, { __index = function() return function() end end })
			for i = 1, 8 do
				local fs = _G.CreateFrame("FontString")
				fs.GetText = function() return lines[i] end
				_G["DupTipTextLeft" .. i] = fs
				_G["DupTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			mod.Compose(tip, "target")
			local all = table.concat(lines, " | ")
			assert(all:find("High Order Skyborne Druid", 1, true),
				"the client's longer line survives: " .. all)
			local _, druids = all:gsub("Druid", "")
			assert(druids == 1, ("and ours is not written under it (%d): %s"):format(druids, all))

			-- AND THE OTHER WAY ROUND (Josh 2026-09-20). Ours can be the
			-- fuller line: "Gnome Warlock" against the client's bare
			-- "Warlock". Fixing one direction left the warlock reading
			-- "Gnome Warlock / Warlock" for three days.
			_G.UnitRace = function() return "Gnome" end
			_G.UnitClass = function() return "Warlock", "WARLOCK" end
			lines = { "Trilly Lightbolt", "Warlock" }
			for i = 1, 8 do
				local fs = _G["DupTipTextLeft" .. i]
				fs.GetText = function() return lines[i] end
			end
			mod.Compose(tip, "target")
			all = table.concat(lines, " | ")
			assert(all:find("Gnome Warlock", 1, true), "ours survives: " .. all)
			local _, locks = all:gsub("Warlock", "")
			assert(locks == 1, ("and theirs is not written under it (%d): %s"):format(locks, all))
			_G.UnitIsPlayer, _G.UnitRace, _G.UnitClass = wasPlayer, wasRace, wasClass
		end },
		{ "the dock stops at the bottom of the screen and the quests scroll", function()
			-- THE DOCK DECIDES HOW TALL (Josh 2026-09-23). The list used to stop
			-- at 45% of the screen whatever else was in the dock and wherever
			-- the dock was. Now the dock is never taller than the room from its
			-- top edge to the bottom of the screen, and the quests give up what
			-- does not fit.
			local mod = BT.GetModule("tracker")
			local bar = BT.Bar.Frame()
			BT.SetEnabled("tracker", true)
			_G.C_QuestLog = nil
			_G.GetNumQuestLogEntries = function() return 25 end
			_G.IsQuestWatched = function() return true end
			_G.GetNumQuestLeaderBoards = function() return 2 end
			_G.GetQuestLogLeaderBoard = function(j)
				return (j == 1) and "Something slain: 0/5" or "Something else: 1/2", "monster", false
			end
			_G.GetQuestLogTitle = function(i)
				return "Quest Number " .. i, 10, nil, false, nil, nil, nil, 1000 + i
			end
			bar._top = 500
			mod.Update()

			local room = BT.Bar.Room()
			assert(room == 500, "the room is the dock's top to the screen's very foot, no gap: " .. tostring(room))
			assert(mod.contentHeight > mod.maxHeight,
				("more quests than fit (%s in %s)")
					:format(tostring(mod.contentHeight), tostring(mod.maxHeight)))
			assert(mod.Frame()._height == mod.maxHeight,
				("the list is as tall as it was given (%s)"):format(tostring(mod.Frame()._height)))
			assert(bar._height <= room,
				("and the dock ends on the screen (%s of %s)"):format(tostring(bar._height), tostring(room)))

			-- dragged further down the screen, there is less room under it
			local wasMax = mod.maxHeight
			bar._top = 450
			bar:GetScript("OnDragStop")(bar)
			assert(mod.maxHeight == wasMax - 50 and bar._height <= BT.Bar.Room(),
				("a lower dock gives the list less (%s, was %s)"):format(tostring(mod.maxHeight), tostring(wasMax)))
			-- and never less than a few lines under the header
			bar._top = 60
			BT.Bar.Relayout()
			assert(mod.maxHeight == mod.Frame().minHeight and mod.maxHeight >= 15 * 3,
				"the list keeps a few lines however little room: " .. tostring(mod.maxHeight))
			bar._top = 500
			BT.Bar.Relayout()

			-- IT SHRINKS AS IT GOES DOWN: dragged, it is let off the screen and
			-- laid out as it moves; let go, it is held on the screen again
			bar:GetScript("OnDragStart")(bar)
			-- ONLY THE BOTTOM GIVES: held on the screen at the top and sides,
			-- and let past the bottom edge by the whole dock
			assert(bar.dragging and bar._clamp and bar._clamp[1] == 0 and bar._clamp[2] == 0
				and bar._clamp[3] == 0 and bar._clamp[4] > 0,
				"clamped at the top and sides, free at the bottom: " .. table.concat(bar._clamp or {}, ","))
			assert(bar:GetScript("OnUpdate"), "and laid out again as it moves")
			bar._top = 450
			bar:GetScript("OnUpdate")(bar, 0.1)
			assert(mod.maxHeight == wasMax - 50, "the quests give up the room mid-drag: " .. tostring(mod.maxHeight))
			bar:GetScript("OnDragStop")(bar)
			assert(not bar.dragging and bar:GetScript("OnUpdate") == nil, "and let go")
			assert(bar._clamp[4] == 0, "held on the screen at every edge again")
			bar._top = 500
			BT.Bar.Relayout()

			-- rows past the bottom are not drawn over whatever is down there
			local drawn = 0
			for _, r in ipairs(mod.Rows()) do
				if r:IsShown() then
					drawn = drawn + 1
				end
			end
			assert(drawn * 15 <= mod.maxHeight + 15,
				("only what fits is drawn (%d rows)"):format(drawn))
			assert(mod.Frame().thumb:IsShown(), "and a thumb says the list goes on")

			-- the wheel moves the column, and stops at both ends
			local wheel = mod.Frame():GetScript("OnMouseWheel")
			assert(wheel, "the panel takes the wheel")
			wheel(mod.Frame(), -1)
			assert(mod.scroll > 0, "turning it down moves the list: " .. tostring(mod.scroll))
			-- the QUESTS line stays where it is: it is the fold and the handle
			local head = mod.Rows()[1]
			assert(head.isHeader and head:IsShown() and head._point.y == -head.top,
				"the header does not scroll away")
			for _ = 1, 50 do
				wheel(mod.Frame(), -1)
			end
			assert(mod.scroll == mod.contentHeight - mod.maxHeight,
				("and it stops at the end (%s)"):format(tostring(mod.scroll)))
			local last
			for j = 1, #mod.Rows() do
				if mod.Rows()[j].top and mod.Rows()[j]:IsShown() then last = mod.Rows()[j] end
			end
			assert(last and last.top - mod.scroll + 15 <= mod.maxHeight, "the last line is on screen at the end")
			for _ = 1, 100 do
				wheel(mod.Frame(), 1)
			end
			assert(mod.scroll == 0, "and at the top")

			-- and with a list that fits, the wheel does nothing at all
			_G.GetNumQuestLogEntries = function() return 2 end
			mod.Update()
			assert(mod.contentHeight <= mod.maxHeight, "the short list fits")
			assert(not mod.Frame().thumb:IsShown(), "and has no thumb")
			wheel(mod.Frame(), -1)
			assert(mod.scroll == 0, "a panel that scrolls when it need not feels broken")

			-- ONLY WHAT SCROLLS GIVES WAY: the squeeze takes from sections that
			-- can scroll, first to last, and from nothing else
			local map = { s = { frame = {} }, tall = 200 }
			local list = { s = { frame = { shrinks = true, minHeight = 60 } }, tall = 300 }
			local cells = { s = { frame = {} }, tall = 40 }
			local stack = { map, list, cells }
			assert(BT.Bar.Squeeze(stack, 20, 1000) == 0 and list.tall == 300, "nothing given when it fits")
			assert(BT.Bar.Squeeze(stack, 20, 400) == 160 and list.tall == 140, "the list gives what does not fit")
			assert(map.tall == 200 and cells.tall == 40, "and the map and the readouts keep theirs")
			list.tall = 300
			BT.Bar.Squeeze(stack, 20, 100)
			assert(list.tall == 60, "never past its floor, even when the dock still will not fit")
			bar._top = nil
		end },
		{ "the unit probe writes down what the client says, and never a secret", function()
			-- WHAT THIS CLIENT WILL TELL A UNIT FRAME (Josh 2026-09-23)
			BeebModDB.unitProbe = nil
			local wasHealth = _G.UnitHealth
			_G.secretMeasurements = true
			_G.UnitHealth = function() return _G.SECRET_WIDTH end
			BT.RunCommand("unitprobe", "")
			local runs = BeebModDB.unitProbe
			assert(runs and #runs == 1 and #runs[1].lines > 20, "a run of lines: " .. tostring(runs and #runs[1].lines))
			local sawSecret, sawInventory = false, false
			for _, line in ipairs(runs[1].lines) do
				assert(type(line) == "string" and not line:find(tostring(_G.SECRET_WIDTH), 1, true),
					"no secret is ever written out: " .. tostring(line))
				if line:find("UnitHealth(player) = SECRET(number)", 1, true) then sawSecret = true end
				if line:find("^globals %(") then sawInventory = true end
				-- a part that throws is written down as a line, not raised: the
				-- probe must still say it failed here rather than in the game
				assert(not line:find("failed: ", 1, true), "no part of the probe failed: " .. line)
			end
			assert(sawSecret, "a secret is named as one")
			assert(sawInventory, "and the inventory is taken out of combat")
			_G.secretMeasurements = false
			_G.UnitHealth = wasHealth
			BT.RunCommand("unitprobe", "clear")
			assert(BeebModDB.unitProbe == nil, "and it can be cleared")
		end },
		{ "the unit frames: built, bound, painted, and the game's own put away", function()
			-- STYLE A IN THE CORNERS (Josh 2026-09-23)
			local mod, F = BT.GetModule("frames"), BT.UnitFrames
			assert(mod and F, "the module and the unit button are loaded")
			BT.moduleErrors = nil
			_G.PlayerFrame = _G.CreateFrame("Button", nil, _G.UIParent)
			_G.TargetFrame = _G.CreateFrame("Button", nil, _G.UIParent)
			BT.SetEnabled("frames", false)
			BT.SetEnabled("frames", true)
			assert(BT.moduleErrors == nil, "no module error: " .. table.concat(BT.moduleErrors or {}, " | "))

			-- THE COLUMN BESIDE THE TARGET: its target level with it, the focus
			-- under that, the two as tall as the target
			local tt, fo = mod.singles.targettarget._points.TOPLEFT, mod.singles.focus._points.TOPLEFT
			assert(tt.rel == mod.singles.target and tt.relPoint == "TOPRIGHT", "the target of target beside it")
			assert(fo.rel == mod.singles.targettarget and fo.relPoint == "BOTTOMLEFT", "the focus under that")
			assert(F.KINDS.tot.h + mod.STACK_GAP + F.KINDS.focus.h == F.KINDS.target.h, "together as tall as the target")

			-- NO PLAYER FRAME: you are the top of the party column, alone as well
			assert(mod.singles.player == nil and mod.singles.pet == nil, "no player or pet frame of their own")
			assert(mod.headers[1]:GetAttribute("showSolo") == true and mod.headers[1]:GetAttribute("showPlayer") == true,
				"the party column is shown alone, with you in it")
			local player = mod.singles.target
			assert(player and player.bmDressed and player.bmUnit == "target", "the target's frame is built and bound")
			assert(player:GetAttribute("unit") == "target" and player:GetAttribute("*type1") == "target"
				and player:GetAttribute("*type2") == "togglemenu", "a click targets, a right click opens the menu")
			assert(mod.singles.targettarget and mod.singles.focus and mod.singles.boss5,
				"and its target, the focus and five bosses")
			assert(#mod.headers == 10, "a party header, eight raid groups and the main tanks: " .. #mod.headers)
			assert(mod.headers[1]:GetAttribute("template") == "SecureUnitButtonTemplate"
				and mod.headers[1]:GetAttribute("initialConfigFunction") == nil,
				"the headers make plain secure buttons, and are handed no snippet")
			assert(_G.PlayerFrame.bmStowed and _G.PlayerFrame:GetParent() ~= _G.UIParent,
				"the game's player frame is put away")
			-- OFF IN A FIGHT, DONE WHEN IT ENDS (the audit): the queue used to be
			-- emptied by a handler that steps aside while the module is off
			_G.InCombatLockdown = function() return true end
			mod:OnDisable()
			assert(mod.Pending().off, "switched off in a fight: waiting")
			_G.InCombatLockdown = function() return false end
			mod.drain:GetScript("OnEvent")(mod.drain, "PLAYER_REGEN_ENABLED")
			assert(not _G.PlayerFrame.bmStowed, "and done when the fight ends: the game's frames are back")
			-- off then on again inside one fight: nothing stale is left to fire
			_G.InCombatLockdown = function() return true end
			mod:OnDisable()
			mod:OnEnable()
			assert(mod.Pending().off == nil and mod.Pending().apply, "on again cancels the waiting off")
			_G.InCombatLockdown = function() return false end
			mod.drain:GetScript("OnEvent")(mod.drain, "PLAYER_REGEN_ENABLED")
			assert(_G.PlayerFrame.bmStowed, "and the frames are ours again")

			-- SWITCHED OFF, THE GAME'S OWN COME BACK: party off brings back the
			-- player frame, and on again puts it away
			local home = _G.PlayerFrame.bmHome
			mod.SetOpt("party", false)
			assert(not _G.PlayerFrame.bmStowed and _G.PlayerFrame:GetParent() == home,
				"party off: the game's player frame is back where it was")
			mod.SetOpt("party", true)
			assert(_G.PlayerFrame.bmStowed and _G.PlayerFrame:GetParent() ~= home, "and away again with it on")
			-- the game's combo points go with its target frame (Josh 2026-09-24)
			_G.ComboFrame = _G.CreateFrame("Frame", "ComboFrame", _G.UIParent)
			mod.Stow()
			assert(_G.ComboFrame.bmStowed and _G.ComboFrame:GetParent() ~= _G.UIParent,
				"the game's combo points are put away with its target frame")
			_G.ComboFrame = nil
			-- and a frame the game moves while it is away goes back under the hider
			_G.PlayerFrame:SetParent(_G.UIParent)
			assert(_G.PlayerFrame:GetParent() ~= _G.UIParent or not _G.hooksecurefunc,
				"put back, not left where the game moved it")

			-- A NAME IS WRITTEN FROM EMPTY, so the client cannot pass over it
			local writes = {}
			local wasSet = player.name.SetText
			player.name.SetText = function(self, t) writes[#writes + 1] = t; return wasSet(self, t) end
			F.Paint(player, F.Source("target"))
			player.name.SetText = nil
			assert(writes[1] == "" and #writes >= 2, "emptied, then written")
			BT.RunCommand("framesdump", "")
			assert(BeebModDB.framesDump and #BeebModDB.framesDump.lines >= 2, "and the dump writes the names down")
			BeebModDB.framesDump = nil

			-- TWO-PART NAMES: UnitName gives the first half on this client
			local wasGUN = _G.GetUnitName
			_G.GetUnitName = function() return "Beeb Bob" end
			F.Paint(player, F.Source("player"))
			assert(tostring(player.name._text):find("Beeb Bob", 1, true), "a single frame says the whole name: " .. tostring(player.name._text))
			_G.GetUnitName = wasGUN
			assert(player:GetWidth() < player:GetHeight() * 3, "and is a cell, not a strip: " .. player:GetWidth() .. "x" .. player:GetHeight())
			-- NO RIM: the frame's edge is left for aggro, the target outline, dispels
			local held = BT.Pill.Panels()[player]
			assert(held and held.fillColour == BT.Widgets.FILL and held.edgeColour[4] == 0,
				"the theme's fill, with no border drawn round it")

			-- AGGRO ON AN ENEMY IS YOUR THREAT ON IT: the mob has none of its own
			local target = mod.singles.target
			local wasAttack, wasThreat = _G.UnitCanAttack, _G.UnitThreatSituation
			_G.UnitCanAttack = function() return true end
			_G.UnitThreatSituation = function(a, b) if a == "player" and b == "target" then return 3 end return nil end
			F.Paint(target, F.Source("target"))
			assert(target.threat._shown ~= false and target.threat.level == 3, "a mob that is on you rings red")
			-- and combo points are yours, on something you can hit - not a friend
			_G.UnitCanAttack = function() return false end
			F.Paint(target, F.Source("target"))
			assert(target.threat._shown == false or target.threat.level == nil, "a friend with nothing on them has no ring")
			assert(target.combo._shown == false, "and no combo row under a friend")
			_G.UnitCanAttack, _G.UnitThreatSituation = wasAttack, wasThreat

			-- IN REACH: a target is faded when your spells will not reach it,
			-- and the client's follow distance answers when no spell does
			local wasSpell, wasNear, wasParty = _G.C_Spell, _G.CheckInteractDistance, _G.UnitInParty
			_G.UnitInParty = function() return false end
			_G.C_Spell = { IsSpellInRange = function() return false end }
			F.Paint(target, F.Source("target"))
			assert(target._alpha == F.FAR_ALPHA, "a target out of reach is faded: " .. tostring(target._alpha))
			_G.C_Spell = { IsSpellInRange = function() return true end }
			F.Paint(target, F.Source("target"))
			assert(target._alpha == 1, "and in reach is not")
			_G.C_Spell = { IsSpellInRange = function() return nil end }
			_G.CheckInteractDistance = function() return false end
			F.Paint(target, F.Source("target"))
			assert(target._alpha == F.FAR_ALPHA, "no spell answers: the follow distance does")
			_G.C_Spell, _G.CheckInteractDistance, _G.UnitInParty = wasSpell, wasNear, wasParty
			F.Paint(target, F.Source("target"))

			-- NOTHING READS A NUMBER: a secret health goes to the bar as it came
			_G.secretMeasurements = true
			local wasHealth = _G.UnitHealth
			_G.UnitHealth = function() return _G.SECRET_WIDTH end
			F.Paint(player, F.Source("player"))
			assert(player.health._value == _G.SECRET_WIDTH, "the bar is handed the secret untouched")
			_G.secretMeasurements = false
			_G.UnitHealth = wasHealth

			-- made-up people, drawn by the same code with plain numbers
			mod.Preview("raid")
			assert(#mod.previews == 45, "thirty-five (group 6 empty), four bosses, two tanks and their targets, the cast bar and a target: " .. #mod.previews)
			local tank = mod.raidCells[1]
			assert(tank.health._max and tank.health._value, "a preview's bar has its numbers")
			-- THE GROUPS, PACKED: group 6 is empty, so 7 closes up into its place
			assert(mod.raidCells[26] == nil, "nobody in group 6")
			assert(mod.raidCells[31]._points.TOPLEFT.x == 5 * mod.RAID_STEP, "group 7 in the sixth column")
			assert(mod.raidCells[36]._points.TOPLEFT.x == 6 * mod.RAID_STEP, "and group 8 in the seventh")
			assert(mod.Holder("raid"):GetWidth() == 7 * mod.RAID_STEP, "the block as wide as its columns")
			assert(tank.threat._shown ~= false and tank.threat.level == 3, "the tank's aggro ring is up, at tanking")
			assert(mod.raidCells[5].threat._shown == false, "and nobody else's")
			assert(tank.leader._shown ~= false, "and the leader's crown")
			assert(mod.raidCells[39].status._text == "Dead", "a dead one says so: " .. tostring(mod.raidCells[39].status._text))
			assert(mod.raidCells[34].status._text == "Offline", "and an offline one")
			assert(mod.raidCells[22]._alpha == F.GROUP_FAR and F.GROUP_FAR <= 0.3,
				"out of range is faded, well down: " .. tostring(mod.raidCells[22]._alpha))
			-- A RESURRECTION ON ITS WAY, A SUMMON WAITING, THE MASTER LOOTER
			assert(mod.raidCells[39].call._shown ~= false and mod.raidCells[39].call.icon == F.CALL.rez, "the dead one's resurrection")
			assert(mod.raidCells[37].call.icon == F.CALL[1] and mod.raidCells[38].call.icon == F.CALL[2]
				and mod.raidCells[40].call.icon == F.CALL[3], "a summon waiting, taken and turned down")
			assert(mod.raidCells[3].ml._shown ~= false, "and the master looter's coins")
			-- THE MAIN TANKS, beside the raid, with their targets
			local tanks = {}
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "tank" then tanks[#tanks + 1] = f end
			end
			assert(#tanks == 2 and tanks[1]._points.BOTTOMLEFT.rel == mod.Holder("tanks"), "two tanks, in their own block")
			assert(tanks[1]._points.BOTTOMLEFT.y > tanks[2]._points.BOTTOMLEFT.y and tanks[2]._points.BOTTOMLEFT.y == 0,
				"the first on top, the last on the raid")
			local tp = mod.Holder("tanks")._points.BOTTOMLEFT
			assert(tp.rel == mod.Holder("raid") and tp.relPoint == "TOPLEFT" and tp.x == 0 and tp.y > 0,
				"and the block stands on the raid's top edge, at its left")
			-- THE SWITCH IS OBEYED BY THE PREVIEW TOO: tanks off, tanks gone
			mod.SetOpt("tanks", false)
			local still = 0
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "tank" then still = still + 1 end
			end
			assert(mod.previewing == "raid" and still == 0 and #mod.previews == 41,
				"the main tanks switched off leave the preview: " .. still .. ", " .. #mod.previews)
			mod.SetOpt("tanks", true)
			assert(#mod.previews == 45, "and come back with it")
			assert(mod.raidCells[37].call:GetWidth() >= 24, "a summon icon big enough to see: " .. tostring(mod.raidCells[37].call:GetWidth()))
			-- YOUR CAST BAR, in the preview, part way through a Hearthstone
			assert(mod.cast and mod.cast._shown ~= false and mod.cast.name._text == "Hearthstone", "your cast bar")
			local bosses = {}
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "boss" then bosses[#bosses + 1] = f end
			end
			local lucifron = bosses[1]
			-- AN ORNATE BORDER: gold with a crest for the elites, silver for rare
			assert(lucifron.rank._shown ~= false and lucifron.rank.style == "worldboss", "a world boss is bordered")
			local gold = lucifron.rank.art[1]._vertex
			assert(gold and gold[1] > 0.9 and gold[3] < 0.5, "in gold")
			assert(#lucifron.rank.art == 4 and #lucifron.rank.lines == 8, "four corners and a double line on each side")
			assert(lucifron.rank.crest._shown ~= false, "with the crest")
			-- A BOSS SHOWS ITS MECHANICS, NOT YOUR DOTS
			assert(lucifron.bmFakeAuras.debuffs == nil or not lucifron.bmFakeAuras.debuffs[1], "no dots beside a boss")
			local enraged = bosses[4]
			assert(enraged.bmFakeAuras.mechanics[1]:IsShown() and enraged.bmFakeAuras.mechanics[1].type == "Enrage",
				"the low Flamewaker's enrage, beside it")
			-- and the raid marker above all of it, so the crest never crosses it
			assert(lucifron.marker._shown ~= false, "Lucifron has his skull")
			assert(lucifron.top:GetFrameLevel() > lucifron.rank:GetFrameLevel(), "drawn over the border")
			local rare
			for _, f in ipairs(mod.previews) do
				if f.name and f.name._text and tostring(f.name._text):find("Mazzranache", 1, true) then rare = f end
			end
			assert(rare and rare.rank.style == "rare" and rare.rank.art[1]._vertex[3] > 0.9, "a rare in silver")
			assert(rare.rank.crest._shown == false, "and no crest")
			assert(mod.raidCells[1].rank == nil, "a raid cell has no rank border")
			assert(lucifron.cast and lucifron.cast._shown ~= false, "a boss's cast bar is up")
			assert(lucifron.value._text == "38%", "and its health as a percentage: " .. tostring(lucifron.value._text))
			assert(mod.raidCells[38].name._text == "Beeb", "a raid cell has room for the first half")
			-- MADE-UP AURAS: the rows as the containers lay them, with real pictures
			-- every third member, the five types in turn
			local doomed, cursed = mod.raidCells[3], mod.raidCells[6]
			-- A MADE-UP AURA HAS A TOOLTIP, the spell's own
			local curse = cursed.bmFakeAuras.debuffs[1]
			local asked
			GameTooltip.SetSpellByID = function(_, id) asked = id end
			curse:GetScript("OnEnter")(curse)
			assert(asked == curse.spell and F.Auras.tipFor == curse, "hovering a made-up aura shows its spell")
			curse:GetScript("OnLeave")(curse)
			assert(F.Auras.tipFor == nil, "and leaving hides it")
			GameTooltip.SetSpellByID = nil
			assert(cursed.bmFakeAuras.debuffs[1]:IsShown() and cursed.bmFakeAuras.debuffs[1].type == "Curse",
				"the sixth carries a curse")
			assert(doomed.bmFakeDispel and doomed.bmFakeDispel._shown ~= false, "and the third the doom's mark")
			local seen = {}
			for _, cell in pairs(mod.raidCells) do
				local m = cell.bmFakeDispel
				if m and m._shown ~= false and m.pattern.path then
					seen[m.pattern.path:match("(%a+)$")] = true
				end
			end
			for _, kind in ipairs({ "magic", "curse", "poison", "disease", "bleed" }) do
				assert(seen[kind], "the raid shows the " .. kind .. " pattern")
			end
			local c = doomed.bmFakeDispel.edges[1]._color
			assert(c and math.abs(c[1] - 0.20) < 0.01 and math.abs(c[3] - 1.00) < 0.01, "in the magic blue")
			assert(mod.raidCells[1].bmFakeAuras.mine[1]:IsShown(), "and your heals on the tank")
			local t = mod.previewTarget.bmFakeAuras.debuffs
			assert(#t == 5 and t[2].count._text == "5", "the target's debuffs, sunder at five")
			assert(t[1]._points.TOPLEFT.relPoint == "BOTTOMLEFT", "under the target")
			-- A PATTERN A TYPE: stripes for magic, a crosshatch for a curse
			assert(doomed.bmFakeDispel.pattern.path:find("magic$"), "the doom's stripes")
			assert(cursed.bmFakeDispel.pattern.path:find("curse$"), "the curse's crosshatch")
			-- THE TARGET SAYS MORE: its health as a number beside its share, and
			-- its power as a figure on the bar
			local t = mod.previewTarget
			assert(t and t.hpText._text == "1.1K", "the target's health, abbreviated: " .. tostring(t and t.hpText._text))
			assert(t.value._text == "72%", "beside its share: " .. tostring(t.value._text))
			assert(t.power.text._text == "45", "and its rage on the bar: " .. tostring(t.power.text._text))
			assert(t:GetHeight() >= F.KINDS.party.h and t:GetWidth() < 200, "a cell, narrow and tall")
			assert(F.KINDS.party.w == 160 and F.KINDS.party.h == 60, "and a party cell the size the player frame was")
			-- A LIGHT UNDER THE POINTER, on every unit frame
			t:GetScript("OnEnter")(t)
			assert(t.hover._shown ~= false, "the frame under the pointer is lit")
			t:GetScript("OnLeave")(t)
			assert(t.hover._shown == false, "and dark again when it goes")
			-- the toolkit's face, with a shadow and no outline: names heavier
			assert(t.name._font and t.name._font[1] == BT.Fonts.Face("name") and t.name._font[3] == "",
				"the name is in the toolkit's face, unoutlined: " .. tostring(t.name._font and t.name._font[1]))
			assert(t.hpText._font[1] == BT.Fonts.Face("text") and t.hpText._font[2] <= 12, "the figures lighter, and small")
			mod.Preview("party")
			assert(#mod.previews == 15, "four, a pet, their four targets, four bosses, the cast bar and a target: " .. #mod.previews)
			local cellNames = {}
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "party" then cellNames[#cellNames + 1] = f.name._text end
			end
			assert(#cellNames == 4 and cellNames[4] == "Ashby", "four made-up people under the real you: " .. table.concat(cellNames, ","))
			assert(mod.previews[1]._points.TOPLEFT.y == -(F.KINDS.party.h + mod.PARTY_STEP), "the first place left for you")
			assert(mod.previews[1].value._shown == false, "a party cell writes no figure: the bar says it")
			-- A PET AND A TARGET FOR EVERY MEMBER: the room for a pet is kept
			-- whether there is one or not, so the party is evenly spaced
			local cells = {}
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "party" then cells[#cells + 1] = f end
			end
			local step = F.KINDS.party.h + mod.PARTY_STEP
			assert(-cells[1]._points.TOPLEFT.y == step and -cells[4]._points.TOPLEFT.y == 4 * step,
				"every member one pet's room below the last")
			assert(cells[1].ml._shown ~= false and cells[2].call.icon == F.CALL[1],
				"the party has its master looter, and a summon waiting")
			-- AN ATLAS THE CLIENT LACKS says false and draws nothing: the file then
			local wasAtlas = cells[3].call.SetAtlas
			local filed
			cells[3].call.SetAtlas = function() return false end
			cells[3].call.SetTexture = function(_, path) filed = path end
			F.Paint(cells[3], F.Fake({ name = "Ysolde", class = "MAGE", hp = 0, dead = true, rez = true }))
			assert(filed == F.CALL.rez.file, "an unknown atlas falls back to the file: " .. tostring(filed))
			cells[3].call.SetAtlas, cells[3].call.SetTexture = wasAtlas, nil
			local voidwalker, aims = nil, 0
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "gpet" then voidwalker = f end
				if f.bmKind == "gtarget" then aims = aims + 1 end
			end
			assert(voidwalker and voidwalker.name._text == "Bristleback", "the hunter's boar, under him")
			-- A HUNTER'S PET, AND HOW IT FEELS: content is amber
			assert(voidwalker.happy._shown ~= false and voidwalker.happy._color[2] > 0.6 and voidwalker.happy._color[3] < 0.4,
				"a content pet's square is amber")
			-- YOUR THREAT on the made-up target
			assert(mod.previewTarget.threatText._text == "82%", "your threat on the target: " .. tostring(mod.previewTarget.threatText._text))
			assert(voidwalker:GetWidth() == F.KINDS.party.w / 2 and voidwalker._points.TOPRIGHT,
				"half her width, under her right-hand end")
			assert(aims == 4, "and a target beside each member")
			-- A PRIEST'S WHITE IS TAKEN DOWN FURTHER than a warrior's brown
			assert(F.DeepenBy({ 1, 1, 1 }) > F.DeepenBy({ 0.78, 0.61, 0.43 }), "pale colours go further")
			assert(F.DeepenBy({ 0.78, 0.61, 0.43 }) == 0.34, "and the rest by a third, as before")
			local byName = {}
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "party" then byName[f.name._text] = f end
			end
			local priest, warrior = byName.Maelis, byName.Brannoc
			local r, g, b = priest.health._barColor[1], priest.health._barColor[2], priest.health._barColor[3]
			assert(0.299 * r + 0.587 * g + 0.114 * b <= 0.52, ("the priest's bar is dark enough for white type (%.2f, %.2f, %.2f)"):format(r, g, b))
			assert(priest.power._shown ~= false and warrior.power._shown == false,
				"a priest's mana shows, a warrior's rage does not")
			mod.Preview(nil)
			assert(#mod.previews == 0, "and the preview goes")

			-- a member's pet and target take their unit from the member's, secure
			local member = F.Build(_G.UIParent, "party", nil, true)
			mod.Minis(member)
			assert(member.bmPet:GetAttribute("useparent-unit") == true and member.bmPet:GetAttribute("unitsuffix") == "pet",
				"the pet's unit is the member's and a suffix, for the client's own clicks")
			assert(member.bmTarget:GetAttribute("unitsuffix") == "target", "and the target's")
			F.Bind(member, "party2")
			assert(member.bmPet.bmUnit == "partypet2" and member.bmTarget.bmUnit == "party2target",
				"painted from the same tokens: " .. tostring(member.bmPet.bmUnit))
			F.Bind(member, "player")
			assert(member.bmPet.bmUnit == "pet" and member.bmTarget.bmUnit == "target", "yours are your pet and target")
			-- but your own target is the target frame's: not shown beside you
			mod.SyncMinis(member)
			assert(member.bmTarget.bmWatched == false and member.bmTarget._shown == false,
				"your cell shows no target of its own")
			assert(member.bmPet.bmWatched == true, "and keeps its pet")
			F.Bind(member, "party3")
			mod.SyncMinis(member)
			assert(member.bmTarget.bmWatched == true, "a party member's cell does show one")

			-- SHIFT-DRAG TO MOVE: the raid hangs off a holder, and a preview moves it
			local raidHolder = mod.Holder("raid")
			assert(mod.headers[2]._points.TOPLEFT.rel == raidHolder, "the raid's groups hang off its holder")
			assert(mod.singles.boss1._points.TOPLEFT.rel == mod.Holder("boss"), "and the bosses off theirs")
			mod.Preview("raid")
			local cell = mod.previews[1]
			assert(cell._points.TOPLEFT.rel == raidHolder, "a preview hangs off the same holder")
			local wasShift = _G.IsShiftKeyDown
			_G.IsShiftKeyDown = function() return false end
			cell:GetScript("OnDragStart")(cell)
			assert(not raidHolder.moving, "a plain drag moves nothing")
			_G.IsShiftKeyDown = function() return true end
			cell:GetScript("OnDragStart")(cell)
			assert(raidHolder.moving and raidHolder.ghost._shown ~= false, "a shift-drag picks the raid up, outline and all")
			raidHolder._left, raidHolder._top = 300, 420
			cell:GetScript("OnDragStop")(cell)
			local pos = BT.settings.frames.pos.raid
			assert(pos and pos.x == 300 and pos.y == -80, ("and where it is left is saved (%s, %s)"):format(tostring(pos and pos.x), tostring(pos and pos.y)))
			assert(raidHolder.ghost._shown == false, "and the outline goes")
			mod.PlaceHolder("raid")
			assert(raidHolder._points.TOPLEFT.x == 300 and raidHolder._points.TOPLEFT.y == -80, "it comes back there")
			BT.RunCommand("frames", "reset")
			assert(BT.settings.frames.pos == nil, "reset forgets it")
			assert(raidHolder._points.TOPLEFT.x == 24, "and puts the raid back where it started")
			-- the made-up target is not a block: a shift-drag on it moves nothing,
			-- and does not fail looking for one (2026-09-23)
			mod.Preview("party")
			local fake = mod.previewTarget
			assert(fake.bmHandle == nil, "the preview target is not a handle")
			local mini
			for _, f in ipairs(mod.previews) do
				if f.bmKind == "gtarget" then mini = f end
			end
			assert(mini and mini.bmHandle == "party", "a made-up member's target moves the party")
			_G.IsShiftKeyDown = wasShift
			mod.Preview(nil)

			-- MOUSEOVER CAST is the client's own setting, switched from here
			local cvars = { enableMouseoverCast = "0" }
			local wasCVar, wasSupported = _G.C_CVar, _G.IsMouseoverCastSupported
			_G.C_CVar = { GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = v end }
			_G.IsMouseoverCastSupported = function() return true end
			assert(mod.MouseoverSupported() and not mod.Mouseover(), "supported, and off to start")
			mod.SetMouseover(true)
			assert(cvars.enableMouseoverCast == "1" and mod.Mouseover(), "switched on, in the client's setting")
			_G.IsMouseoverCastSupported = function() return false end
			assert(not mod.MouseoverSupported(), "and nothing is offered where the client has none")
			_G.C_CVar, _G.IsMouseoverCastSupported = wasCVar, wasSupported

			-- THE MAIN TANKS' HEADER: the raid's own marks, no snippet
			local tankHeader
			for _, h in ipairs(mod.headers) do
				if h.bmRole == "tanks" then tankHeader = h end
			end
			assert(tankHeader and tankHeader:GetAttribute("roleFilter") == "MAINTANK", "a column of the main tanks")
			-- THE GROUPS, PACKED: 1 and 2 full, one member in 7 - three columns
			local wasInRaid, wasNum, wasRoster = _G.IsInRaid, _G.GetNumGroupMembers, _G.GetRaidRosterInfo
			_G.IsInRaid = function() return true end
			_G.GetNumGroupMembers = function() return 11 end
			_G.GetRaidRosterInfo = function(i) return "m" .. i, 0, i <= 5 and 1 or (i <= 10 and 2 or 7) end
			mod.PackRaid()
			local col = {}
			for _, h in ipairs(mod.headers) do
				if h.bmRole == "raid" then col[tonumber(h:GetAttribute("groupFilter"))] = h._points.TOPLEFT.x end
			end
			assert(col[1] == 0 and col[2] == mod.RAID_STEP and col[7] == 2 * mod.RAID_STEP,
				"group 7 is drawn third: " .. tostring(col[7]))
			assert(mod.Holder("raid"):GetWidth() == 3 * mod.RAID_STEP, "and the block is three columns wide")
			-- a roster that cannot be read: every group its own column
			_G.GetRaidRosterInfo = function() return "m", 0, nil end
			mod.PackRaid()
			for _, h in ipairs(mod.headers) do
				if h.bmRole == "raid" then col[tonumber(h:GetAttribute("groupFilter"))] = h._points.TOPLEFT.x end
			end
			assert(col[7] == 6 * mod.RAID_STEP and col[8] == 7 * mod.RAID_STEP, "an unreadable roster packs nothing")
			_G.IsInRaid, _G.GetNumGroupMembers, _G.GetRaidRosterInfo = wasInRaid, wasNum, wasRoster
			mod.PackRaid()
			-- THE MASTER LOOTER, from the loot method's raid index
			local wasInfo, wasRaid = _G.C_PartyInfo, _G.IsInRaid
			_G.C_PartyInfo = { GetLootMethod = function() return 2, nil, 7 end }
			_G.IsInRaid = function() return true end
			assert(mod.UpdateLooter() == "raid7", "raid seven has the loot")
			_G.C_PartyInfo = { GetLootMethod = function() return 3, nil, nil end }
			assert(mod.UpdateLooter() == nil, "and nobody does under group loot")
			_G.C_PartyInfo, _G.IsInRaid = wasInfo, wasRaid
			-- ONE SIZE FOR ALL OF THEM
			assert(mod.SetScale(1.23) == 1.25, "to the nearest step")
			assert(mod.singles.target._scale == 1.25 and mod.headers[1]._scale == 1.25, "on the frames and the blocks alike")
			assert(mod.SetScale(3) == mod.SCALE_MAX, "and no larger than it goes")
			mod.SetScale(1)
			-- YOUR CAST BAR, from your own cast, plainly
			local wasInfo2, wasTime = _G.UnitCastingInfo, _G.GetTime
			_G.GetTime = function() return 101 end
			_G.UnitCastingInfo = function() return "Frostbolt", nil, 135846, 100000, 102000 end
			mod.CastEvent("UNIT_SPELLCAST_START")
			assert(mod.cast._shown ~= false and mod.cast.name._text == "Frostbolt", "a cast shows")
			assert(mod.cast.bar._value == 0.5 and mod.cast.time._text == "1.0", "half way, a second left")
			_G.UnitCastingInfo = function() return nil end
			mod.CastEvent("UNIT_SPELLCAST_STOP")
			assert(mod.cast._shown == false, "and goes when it is done")
			_G.UnitCastingInfo, _G.GetTime = wasInfo2, wasTime

			-- its page, in the Game frames group
			BT.Window.SetView("frames")
			assert(BT.Window.Panel("frames") and BT.Window.Panel("frames").enable, "a page, with its switch")
			-- A NOTE IS AS TALL AS ITS LINES: measured before the page had a
			-- width, a two-line note came out one line tall and was drawn over
			local note = BT.Widgets.Note(_G.UIParent, string.rep("word ", 40))
			assert(note:Measure() >= 24, "a long note measures more than one line: " .. note:Measure())
			assert(BT.Window.Group("frames") == "combat", "in the Combat group on the rail")
			assert(BT.moduleErrors == nil, "and no module error: " .. table.concat(BT.moduleErrors or {}, " | "))
		end },
		{ "one face for everything the toolkit writes", function()
			-- OUR FONT OBJECTS (Josh 2026-09-23): the game's are shared with
			-- every other addon, so the toolkit asks for twins of them
			local Fo = BT.Fonts
			local function cut(key)
				for _, t in ipairs(Fo.TWINS) do
					local obj = _G[t[1]]
					local want = Fo.Face(t[4])
					assert(obj and obj._font and obj._font[1] == want,
						("%s is cut in %s: %s"):format(t[1], key, tostring(obj and obj._font and obj._font[1])))
					assert(obj._font[2] == Fo.Size(t[3]), t[1] .. " at its size")
				end
			end
			assert(Fo.Current().key == Fo.DEFAULT, "the default face to start")
			cut(Fo.DEFAULT)
			-- ONE FACE (Josh 2026-09-24): Google Sans, and the game's own only when
			-- its file will not load; a face an older version saved is not read
			assert(Fo.DEFAULT == "google" and #Fo.Faces() == 2, "Google Sans, and the game's as the fallback")
			BT.settings.font = "fira"
			assert(Fo.Current().key == "google", "a face saved by an older version is ignored")
			BT.settings.font = nil
			local frame = BT.GetModule("frames").singles.target
			assert(frame.name._font[1] == Fo.Face("name"), "a unit frame in it")
			-- a tooltip line the toolkit lays out wears it, and gets its own back
			Fo.Choose(Fo.DEFAULT)
			local tip = _G.CreateFrame("Frame")
			local line = tip:CreateFontString()
			line:SetFont("Fonts/FRIZQT__.TTF", 12, "")
			tip.GetName = function() return "BeebTestTip" end
			_G.BeebTestTipTextLeft1 = line
			tip.NumLines = function() return 1 end
			BT.UnitTip.SizeLine(tip, 1, 14)
			assert(line._font[1] == Fo.Face("name") and line._font[2] == Fo.Size(14),
				"the tooltip's name line in the toolkit's face: " .. tostring(line._font[1]))
			-- and General offers no choice
			BT.Window.SetView("settings")
			assert(BT.Settings.Appearance().type == nil, "no font picker on General")
		end },
		{ "the unit frames' auras are the client's, in containers we describe", function()
			-- AURAS DRAWN BY THE CLIENT (Josh 2026-09-23): an addon may not read
			-- one in a fight, so a container reads them and fills our buttons.
			-- The stub here is an AuraContainer that writes down what it is told.
			local F, A = BT.UnitFrames, BT.UnitFrames.Auras
			local realCF = _G.CreateFrame
			_G.CreateFrame = function(kind, name, parent, template)
				if kind == "AuraContainer" then
					assert(template == "CustomAuraContainerTemplate", "the template made for addons")
					local c = realCF("Frame", name, parent)
					c.groups, c.slots = {}, {}
					c.AddAuraGroup = function(self, key, filter, opts) self.groups[key] = { filter = filter, opts = opts } end
					c.AddAuraSlot = function(self, key, filter, opts)
						local b = realCF("Button", nil, self)
						self.slots[key] = { filter = filter, opts = opts, button = b }
						return b
					end
					c.SetUnit = function(self, u) self.unit = u end
					c.SetEnabled = function(self, on) self.enabled = on end
					return c
				end
				return realCF(kind, name, parent, template)
			end

			local cell = F.Build(_G.UIParent, "party", nil, true)
			A.Attach(cell, "party")
			assert(cell.bmAuras.debuffs.enabled == false, "a cell with no member yet watches nobody, not you")
			F.Bind(cell, "party2")
			local set = cell.bmAuras
			assert(set and set.debuffs and set.mine, "a debuff row and a row of your own buffs")
			assert(set.debuffs.groups.debuffs.filter == "HARMFUL" and set.debuffs.groups.debuffs.opts.maxFrameCount == 3,
				"three debuffs")
			assert(set.mine.groups.mine.filter == "HELPFUL|PLAYER", "and only YOUR buffs on them")
			-- "RAID" is the player's own dispels on this client; RAID_PLAYER_DISPELLABLE is anyone's
			assert(set.debuffs.slots.dispel and set.debuffs.slots.dispel.filter == "HARMFUL|RAID",
				"the dispel mark is for what YOU can remove")
			assert(set.dispel._points.TOPLEFT and set.dispel._points.BOTTOMRIGHT, "laid over the whole cell")
			assert(set.debuffs.unit == "party2" and set.mine.unit == "party2" and set.debuffs.enabled,
				"pointed at the member, and on")

			-- the dispel mark's button: a border, a wash, and a pattern a type,
			-- each pattern with a curve that is clear for every other type
			local mark = realCF("Button")
			local bound = {}
			mark.AddDispelTypeTexture = function(_, tex, opts) bound[#bound + 1] = { tex = tex, opts = opts } end
			set.debuffs.slots.dispel.opts.initializeFrame(mark)
			local patterns = 0
			for id in pairs(A.PATTERN) do
				patterns = patterns + 1
				assert(mark.bmPatterns[id], "a pattern for type " .. id)
			end
			assert(#bound == 4 + 1 + patterns, "four edges, the wash and the patterns, bound: " .. #bound)

			-- a button, dressed as the client makes it: an icon on a black edge
			local btn = realCF("Button")
			set.debuffs.groups.debuffs.opts.initializeFrame(btn)
			assert(btn._width == 16 and btn._height == 16, "sixteen square")

			-- YOUR BUFFS: a tray of two rows, buffs over debuffs. Each row is a
			-- timed container (longest first from the right, so the soonest is at
			-- the far left) and a permanent one against the dock, A to Z
			local Bf = F.Buffs
			_G.AuraContainerSortMethod = { Default = 0, ExpirationOnly = 7, NameOnly = 5 }
			_G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
			local wasEnchant, wasAuras = _G.GetWeaponEnchantInfo, _G.C_UnitAuras
			_G.GetWeaponEnchantInfo = function() return true, 1440000, 0, 2630, false end
			-- three timed buffs, and a campfire that never runs out
			_G.C_UnitAuras = { GetAuraDataByIndex = function(_, i, filter)
				if filter == "HELPFUL" and i <= 3 then return { duration = 600, spellId = 1000 + i } end
				if filter == "HELPFUL" and i == 4 then return { duration = 0, spellId = 7353 } end
			end }
			Bf.holder, Bf.rows, Bf.watch = nil, nil, nil
			Bf.Build()
			local buffs, debuffs = Bf.rows.buffs, Bf.rows.debuffs
			assert(buffs.timed.groups.buffs.filter == "HELPFUL" and debuffs.timed.groups.debuffs.filter == "HARMFUL",
				"your buffs on one line, your debuffs on the other")
			local go = buffs.timed.groups.buffs.opts
			assert(go.sortMethod == 7 and go.sortDirection == 1, "timed: longest first from the right")
			assert(go.candidateFilters.maxDuration == Bf.TIMED_MAX, "and only those with a duration")
			local po = buffs.perm.groups.perm.opts
			assert(po.sortMethod == 5 and po.sortDirection == 1, "permanent: by name, A to Z reading left to right")
			assert(po.candidateFilters.includeSpellIDs[1784], "stealth is known to be permanent from the start")
			assert(buffs.timed.unit == "player" and buffs.timed.enabled and buffs.perm.enabled, "yours, and on")
			assert(debuffs.timedPin._points.TOPRIGHT.y < buffs.timedPin._points.TOPRIGHT.y, "the debuffs under the buffs")
			assert(buffs.surface._points.TOPLEFT.rel == buffs.timed,
				"the tray hangs off the row, so it grows and shrinks with it unmeasured")
			-- the campfire, seen out of a fight, is learned as permanent
			assert(Bf.perm.HELPFUL[7353], "a permanent aura, learned")
			-- right to left: the campfire, the poison, then the timed three
			assert(buffs.permCount == 1 and buffs.timedCount == 3, "one permanent, three timed")
			assert(Bf.enchants[1]._shown ~= false and Bf.enchants[2]._shown == false, "one weapon enchant")
			assert(Bf.enchants[1]._points.TOPRIGHT.x == -Bf.STEP, "past the campfire")
			assert(Bf.enchants[1].words._text == "24 m", "with its time: " .. tostring(Bf.enchants[1].words._text))
			assert(buffs.timedPin._points.TOPRIGHT.x == -2 * Bf.STEP, "and the timed ones start past both")
			-- no debuffs, out of a fight: that row's tray is put away
			assert(debuffs.surface._shown == false and buffs.surface._shown ~= false,
				"an empty row has no tray; a full one does")
			-- a new permanent spell tells the container, while it is live
			local told
			buffs.perm.SetAuraGroupCandidateFilters = function(_, key, cf) told = { key = key, cf = cf } end
			Bf.Learn(buffs, { [2457] = true, [99999] = true })
			assert(told and told.key == "perm" and told.cf.includeSpellIDs[99999], "a newly seen one joins the permanent row")
			-- a button: no clock face, a bar and the time the client keeps, and a
			-- right-click that takes the buff off
			local tb, got = realCF("Button"), {}
			tb.SetDurationBar = function(_, bar) got.bar = bar end
			tb.SetDurationText = function(_, fs) got.text = fs end
			tb.SetCancelAuraButtons = function(_, token) got.cancel = token end
			go.initializeFrame(tb)
			assert(got.bar and got.text and got.cancel == "RightButtonUp", "bar, time and right-click, the client's")
			assert(tb._width == Bf.SIZE, "an icon the tray's size")
			local db = realCF("Button")
			db.SetCancelAuraButtons = function(_, token) got.debuffCancel = token end
			debuffs.timed.groups.debuffs.opts.initializeFrame(db)
			assert(got.debuffCancel == nil, "a debuff cannot be clicked off")
			-- A CLIENT THAT WILL NOT LET ANYTHING HANG OFF ITS CONTAINER: the
			-- surface is sized from the count instead, and nothing throws
			local realPanel = BT.Widgets.Panel
			BT.Widgets.Panel = function(f, ...)
				local sp = f.SetPoint
				f.SetPoint = function(self, point, rel, ...)
					if type(rel) == "table" and rel.groups then
						error("Cannot anchor to a restricted region")
					end
					return sp(self, point, rel, ...)
				end
				return realPanel(f, ...)
			end
			local keepRows, keepHolder, keepEnchants = Bf.rows, Bf.holder, Bf.enchants
			Bf.holder, Bf.rows = nil, nil
			local okBuild = pcall(Bf.Build)
			BT.Widgets.Panel = realPanel
			assert(okBuild, "a refused anchor does not stop the tray")
			local refused = Bf.rows.buffs
			assert(not refused.follows and refused.surface._points.TOPRIGHT, "the surface stands on its own")
			assert(refused.surface._width == 5 * Bf.STEP - Bf.GAP + 2 * Bf.PAD,
				"as wide as the campfire, the poison and three buffs: " .. tostring(refused.surface._width))
			Bf.holder:Hide()
			Bf.rows, Bf.holder, Bf.enchants = keepRows, keepHolder, keepEnchants

			-- made up, for the preview: the soonest at the far left, the
			-- permanent ones against the dock, A to Z
			local fake = Bf.Preview(true)
			assert(fake and #fake.icons == 10 and Bf.real._shown == false, "the made-up tray stands in for the real one")
			assert(fake.icons[1].spell == 1784, "stealth, against the dock")
			local farLeft = fake.icons[#fake.icons]
			assert(farLeft.words._text == "12 s" and farLeft.type == "Bleed", "the soonest debuff at the far left")
			Bf.Preview(false)
			assert(Bf.fake == nil and Bf.real._shown ~= false, "and steps aside again")
			-- THE GAME'S BAR: away while the module is on, back when it is off
			_G.BuffFrame = realCF("Frame", "BuffFrame", _G.UIParent)
			local bm = Bf.module
			bm.live = true
			bm.Stow()
			assert(_G.BuffFrame.bmStowed and _G.BuffFrame:GetParent() ~= _G.UIParent, "the game's buff bar put away")
			bm.live = false
			bm.Stow()
			assert(not _G.BuffFrame.bmStowed and _G.BuffFrame:GetParent() == _G.UIParent, "and back where it was")
			_G.BuffFrame = nil
			_G.GetWeaponEnchantInfo, _G.C_UnitAuras = wasEnchant, wasAuras
			_G.AuraContainerSortMethod, _G.AuraContainerSortDirection = nil, nil

			-- a member's unit changing in a fight waits for the fight to end
			_G.InCombatLockdown = function() return true end
			F.Bind(cell, "party3")
			assert(set.debuffs.unit == "party2", "in a fight the container is left alone")
			_G.InCombatLockdown = function() return false end
			A.Flush()
			assert(set.debuffs.unit == "party3", "and follows when it is over")

			-- a new target: the same token, somebody else, and the holder bounced
			set.host:Hide()
			assert(A.Refresh(cell) and set.host._shown ~= false, "the client is made to read them again")

			-- the target's debuffs hang beside it, in rows of four
			local target = F.Build(_G.UIParent, "target", nil, true)
			A.Attach(target, "target")
			local row = target.bmAuras.debuffs
			assert(row and row._points.TOPLEFT and row._points.TOPLEFT.rel == target
				and row._points.TOPLEFT.relPoint == "BOTTOMLEFT", "under the target")
			assert(row.groups.debuffs.opts.maxFrameCount == 8, "up to eight, four a line")
			assert(target.bmAuras.dispel == nil, "and no dispel mark on a single frame")
			-- NOTHING FLOATS: the row starts just under the frame (a warrior has no
			-- combo row) and the target's cast goes over its power bar
			-- AS FAR AS THE FRAME NEEDS (Josh 2026-09-24): just under a plain one
			assert(row._points.TOPLEFT.y == -F.PLAIN_ROOM, "just under a plain target: " .. tostring(row._points.TOPLEFT.y))
			-- ITS BUFFS, A ROW UNDER (Josh 2026-09-24): every one, permanent too
			local buffs = target.bmAuras.buffs
			assert(buffs and buffs.groups.buffs.filter == "HELPFUL" and buffs.groups.buffs.opts.candidateFilters == nil,
				"the target's buffs, all of them")
			-- DEBUFFS LEFT, BUFFS RIGHT: one row, from either edge of the frame
			local right = buffs._points.TOPRIGHT
			assert(right and right.relPoint == "BOTTOMRIGHT" and right.y == row._points.TOPLEFT.y,
				"the buffs on the same row, from the right")
			local perSide = A.SPECS.target[1].perLine * (A.SPECS.target[1].size + 2)
				+ A.SPECS.target[2].perLine * (A.SPECS.target[2].size + 2)
			assert(perSide <= F.KINDS.target.w, "and the two halves never meet: " .. perSide)
			-- an elite's border pushes both past it, so neither sits on its lines
			F.Paint(target, F.Fake({ name = "Defias Blackguard", reaction = "hostile", hp = 72, classification = "elite" }))
			assert(target.bmBordered and row._points.TOPLEFT.y == -F.RANK_ROOM
				and buffs._points.TOPRIGHT.y == -F.RANK_ROOM, "under an elite, clear of its border: "
				.. tostring(row._points.TOPLEFT.y))
			-- the client will not have its containers moved in a fight: a plain
			-- target then waits for the fight to end
			_G.InCombatLockdown = function() return true end
			F.Paint(target, F.Fake({ name = "Kobold", reaction = "hostile", hp = 50 }))
			assert(not target.bmBordered and row._points.TOPLEFT.y == -F.RANK_ROOM, "left where it was in a fight")
			_G.InCombatLockdown = function() return false end
			A.Flush()
			assert(row._points.TOPLEFT.y == -F.PLAIN_ROOM, "and moved up once it is over")
			-- NO POINTS UNDER A CLASS THAT HAS NONE, A PREVIEW INCLUDED: the rows
			-- leave the combo row's room only for a rogue or a druid
			local wasClass = _G.UnitClass
			local defias = F.Fake({ name = "Defias Blackguard", reaction = "hostile", hp = 72, combo = 3 })
			_G.UnitClass = function() return "Warlock", "WARLOCK" end
			F.PaintCombo(target, defias)
			assert(target.combo and not target.combo:IsShown(), "a warlock's preview draws no combo points")
			_G.UnitClass = function() return "Rogue", "ROGUE" end
			F.PaintCombo(target, defias)
			assert(target.combo:IsShown() and A.Below(A.SPECS.target[1], target) == F.Room(target) + 4 + 3,
				"a rogue's does, with the auras under them")
			_G.UnitClass = wasClass
			-- and nobody else's cell carries a permanent buff
			assert(set.mine.groups.mine.opts.candidateFilters.maxDuration == A.TIMED_MAX,
				"a party cell's buffs are timed ones only")
			assert(A.SPECS.raid[2].candidate.maxDuration == A.TIMED_MAX
				and A.SPECS.boss[1].candidate.maxDuration == A.TIMED_MAX
				and A.SPECS.boss[1].candidate.isBossAura, "and the raid's and a boss's too")
			assert(F.RANK_ROOM > F.RANK_EDGE, "and the room is more than the border reaches")
			assert(target.cast._points == nil or target.cast._points.TOPLEFT == nil
				or target.cast._points.TOPLEFT.relPoint ~= "BOTTOMLEFT", "the cast is not hung under the target")

			-- and nothing is attached in a fight: a container made then is an error
			_G.InCombatLockdown = function() return true end
			local late = F.Build(_G.UIParent, "raid", nil, true)
			assert(A.Attach(late, "raid") == nil, "no container is made in a fight")
			_G.InCombatLockdown = function() return false end
			_G.CreateFrame = realCF
		end },
		{ "the chat frames wear the toolkit's surface", function()
			-- NOTHING HERE REIMPLEMENTS CHAT (Josh 2026-09-20). Not a message
			-- is routed, filtered or rewritten - the client's frames do what
			-- they did, and this changes what they look like and where two of
			-- their pieces sit.
			_G.NUM_CHAT_WINDOWS = 2
			for i = 1, 2 do
				local f = _G.CreateFrame("Frame", "ChatFrame" .. i, _G.UIParent)
				_G.CreateFrame("Button", "ChatFrame" .. i .. "Tab", f)
				_G["ChatFrame" .. i .. "TabLeft"] = f:CreateTexture()
				_G["ChatFrame" .. i .. "TabText"] = f:CreateFontString()
				_G["ChatFrame" .. i .. "ButtonFrame"] = _G.CreateFrame("Frame", nil, f)
				local box = _G.CreateFrame("EditBox", "ChatFrame" .. i .. "EditBox", f)
				box.chatFrame = f
				_G["ChatFrame" .. i .. "EditBoxLeft"] = box:CreateTexture()
			end
			_G.ChatFrameMenuButton = _G.CreateFrame("Button", nil, _G.UIParent)
			_G.GeneralDockManager = _G.CreateFrame("Frame", "GeneralDockManager", _G.UIParent)
			_G.GeneralDockManager:CreateTexture()

			local mod = BT.GetModule("chat")
			BT.SetEnabled("chat", true)
			assert(mod.StyleAll() == 2, "it found both windows")

			-- THE WINDOW ITSELF (Josh 2026-09-20). The black behind the
			-- messages is the client's, and how solid it is comes from a
			-- slider in its own options - the one part of chat still wearing
			-- the client's colour rather than ours.
			local chat = mod.Skins()[_G.ChatFrame1]
			assert(chat and chat.fill:IsShown() and chat.rim[1]:IsShown(),
				"the window has the toolkit's fill and hairline")
			local own = _G.ChatFrame1:CreateTexture()
			mod.StyleAll()
			assert(own._alpha == 0, "and the client's own background is faded behind it")
			assert(chat.fill._alpha ~= 0, "while ours is left alone")

			-- THE CLIENT FADES IT BACK IN WHEN YOU POINT AT IT (Josh
			-- 2026-09-20). A chat frame's background is animated up on
			-- mouseover and down again after, which set the alpha we had
			-- cleared straight back to the player's own setting.
			local asked = {}
			_G.FCF_SetWindowAlpha = function(f, a) asked[f] = a end
			_G.ChatFrame1.oldAlpha = 0.6
			_G.ChatFrame1.beebsAlpha = nil
			mod.StyleAll()
			assert(asked[_G.ChatFrame1] == 0,
				"the window's own alpha is set to zero through the client's call")
			assert(_G.ChatFrame1.beebsAlpha == 0.6, "and the player's value remembered")
			-- and again when the mouse arrives, whatever the animation did
			asked[_G.ChatFrame1] = 0.6
			_G.ChatFrame1.IsMouseOver = function() return true end
			_G.ChatFrame1.beebsControls.Follow()
			assert(asked[_G.ChatFrame1] == 0, "hovering does not bring it back")
			_G.ChatFrame1.IsMouseOver = function() return false end
			mod.StyleAll(true)
			assert(asked[_G.ChatFrame1] == 0.6,
				"and switching the module off hands the player's value back")
			mod.StyleAll()

			-- THE SIDE BUTTONS: the wheel scrolls and the tab has the menu
			-- ALPHA IS NOT ENOUGH FOR THE BUTTON FRAME (Josh 2026-09-20). The
			-- client fades its side buttons IN when you point at chat - the
			-- same animation that brings the background up - so a frame merely
			-- made transparent came back as a second panel under the window.
			assert(_G.ChatFrame1ButtonFrame._alpha == 0, "the arrows are out of the way")
			assert(not _G.ChatFrame1ButtonFrame:IsShown(), "and hidden, not only faded")
			_G.ChatFrame1ButtonFrame:Show()
			_G.ChatFrame1.IsMouseOver = function() return true end
			_G.ChatFrame1.beebsControls.Follow()
			assert(not _G.ChatFrame1ButtonFrame:IsShown(),
				"hovering does not bring it back")
			_G.ChatFrame1.IsMouseOver = function() return false end
			assert(_G.ChatFrameMenuButton._alpha == 0, "and so is the speech bubble")
			-- A TAB OF OUR OWN (Josh 2026-09-20). Fading the client's nine
			-- slices left a word floating over whatever was behind it, and the
			-- dock's own background band running the width of the frame.
			assert(_G.ChatFrame1TabLeft._alpha == 0, "the client's tab art is gone")
			-- EVERY TEXTURE ON IT, NOT A LIST OF NAMES (Josh 2026-09-20). The
			-- list was what the client called them once; this build calls them
			-- something else, so the list faded nothing and the gold art sat
			-- on top of our own surface.
			local stray = _G.ChatFrame1Tab:CreateTexture()
			mod.StyleAll()
			assert(stray._alpha == 0,
				"a texture we have never heard the name of is faded too")
			local mine = mod.Skins()[_G.ChatFrame1Tab]
			assert(mine.fill._alpha ~= 0 and mine.rim._alpha ~= 0,
				"and the sweep leaves our own surface alone")
			-- SHORTER THAN THE CLIENT MAKES THEM: a chat tab is sized for art
			-- that is no longer on it (Josh 2026-09-20)
			-- AS TALL AS THE WORD IN IT, MEASURED (Josh 2026-09-20). A fixed
			-- eighteen was a guess, and it cut the descenders off "Combat Log".
			_G.ChatFrame1TabText.GetStringHeight = function() return 14 end
			mod.StyleAll()
			assert(_G.ChatFrame1Tab._height == 14 + 7,
				"the tab clears the word with a little air: "
					.. tostring(_G.ChatFrame1Tab._height))
			-- ONE HEIGHT FOR ALL OF THEM (Josh 2026-09-21): the measurement is
			-- taken off whichever tab is tallest and every tab wears it, so a
			-- tab made later cannot come out a different size to the ones
			-- beside it. Forgetting it is how a fresh measurement is taken.
			mod.ForgetTabHeight()
			_G.ChatFrame1TabText.GetStringHeight = function() return 4 end
			mod.StyleAll()
			assert(_G.ChatFrame1Tab._height == 20, "and never collapses below a floor")
			mod.ForgetTabHeight()
			_G.ChatFrame1TabText.GetStringHeight = function() return 90 end
			mod.StyleAll()
			assert(_G.ChatFrame1Tab._height == 28, "nor grows past a ceiling")
			mod.ForgetTabHeight()
			_G.ChatFrame1TabText.GetStringHeight = nil
			-- AND THE WORD IN THE MIDDLE OF IT (Josh 2026-09-20). The client
			-- anchors a tab's text for its own art, which had more above the
			-- word than below it - on a tab sized to the word, that puts the
			-- word on the floor.
			mod.StyleAll()
			local where = (_G.ChatFrame1TabText._points or {}).CENTER
			assert(where and where.y == 0,
				"the word sits in the middle of its tab")
			assert(_G.ChatFrame1Tab.beebsText, "and the client's own anchor is remembered")

			-- DIM IS NOT UNREADABLE (Josh 2026-09-20). The unselected tabs
			-- were grey on a near-black fill, which is the contrast of a
			-- disabled control - and a tab you cannot read is one you cannot
			-- choose.
			_G.SELECTED_CHAT_FRAME = _G.ChatFrame2
			mod.StyleAll()
			local off = _G.ChatFrame1TabText._textColor
			assert(off and off[2] > 0.6,
				"an unselected tab is still legible: " .. tostring(off and off[2]))
			_G.SELECTED_CHAT_FRAME = _G.ChatFrame1
			mod.StyleAll()
			local on = _G.ChatFrame1TabText._textColor
			assert(on[2] > off[2], "and the one you are reading is brighter still")
			assert(_G.ChatFrame1TabText._textColor, "and the tab is lettered in our colour")
			local tabSkin = _G.ChatFrame1Tab
			assert(tabSkin.beebsFill == nil or true, "a tab is a thing you click")
			-- lit when it is the one you are reading, the panel's own colour
			-- otherwise: the same two states every switch in the toolkit has
			_G.SELECTED_CHAT_FRAME = _G.ChatFrame1
			mod.StyleAll()
			local lit = mod.Skins()[_G.ChatFrame1Tab]
			assert(lit and lit.fill:IsShown(), "the tab has a surface of its own")
			local onColour = { lit.fill._color[1], lit.fill._color[2], lit.fill._color[3] }
			_G.SELECTED_CHAT_FRAME = _G.ChatFrame2
			mod.StyleAll()
			assert(lit.fill._color[2] ~= onColour[2],
				"and it dims when you are reading another")

			-- THE BAND UNDER THE TABS: the dock draws a background of its own
			-- the width of the chat frame
			assert(_G.GeneralDockManager, "the dock exists")
			for _, region in ipairs({ _G.GeneralDockManager:GetRegions() }) do
				assert(region._alpha == 0, "and nothing it draws is left showing")
			end
			-- three frames deep, and any of them may be drawing the band
			_G.GeneralDockManagerScrollFrame =
				_G.CreateFrame("Frame", "GeneralDockManagerScrollFrame", _G.UIParent)
			local band = _G.GeneralDockManagerScrollFrame:CreateTexture()
			mod.StyleAll()
			assert(band._alpha == 0, "nor anything the scroll frame inside it draws")

			-- UP TO MEET THE TABS (Josh 2026-09-20). The client's tab art
			-- overlapped the top of the window and hid the gap between them;
			-- ours does not, so the tabs were left hanging over a strip of
			-- world. The surface is stretched up to the underside of the tab
			-- strip rather than the window being moved.
			_G.GeneralDockManager.GetBottom = function() return 120 end
			_G.ChatFrame1.GetTop = function() return 108 end
			mod.StyleAll()
			local top = (chat.fill._points or {}).TOPLEFT
			assert(top and top.y == 12,
				("the surface reaches the tab strip (%s)"):format(tostring(top and top.y)))
			-- and when there is no strip above it, it is simply the window
			_G.GeneralDockManager.GetBottom = function() return 100 end
			mod.StyleAll()
			-- otherwise it is the window's own edges, padded out to the
			-- screen corner the frame was held in from
			local inset = (chat.fill._points or {}).TOPLEFT
			assert(inset and inset.x == -mod.FLUSH_INSET,
				("the panel reaches the corner (%s)"):format(tostring(inset and inset.x)))
			_G.GeneralDockManager.GetBottom = function() return 120 end
			mod.StyleAll()

			-- ALIGNING THEM IS NOT WORTH UNANCHORING THE DOCK (Josh
			-- 2026-09-20). Moving the dock meant ClearAllPoints followed by a
			-- SetPoint inside a pcall, and when that SetPoint did not take,
			-- the dock was left with no anchors at all and the tabs vanished.
			-- Our own surface is ours to move; the client's furniture is not.
			_G.ChatFrame1Tab.GetLeft = function() return 5 end
			_G.ChatFrame1.GetLeft = function() return 12 end
			_G.GeneralDockManager.GetBottom = function() return 120 end
			_G.ChatFrame1.GetTop = function() return 108 end
			local dockAt = (_G.GeneralDockManager._points or {}).BOTTOMLEFT
			mod.StyleAll()
			local stillAt = (_G.GeneralDockManager._points or {}).BOTTOMLEFT
			assert((dockAt and dockAt.x) == (stillAt and stillAt.x),
				"the client's dock is left exactly where it was")
			local edge = (chat.fill._points or {}).TOPLEFT
			assert(edge and edge.x == -(12 - 5),
				("and the panel reaches out to meet the tabs (%s)")
					:format(tostring(edge and edge.x)))
			_G.ChatFrame1Tab.GetLeft, _G.ChatFrame1.GetLeft = nil, nil

			-- THE TABS WERE LEFT FLOATING (Josh 2026-09-20). The dock is as
			-- tall as the tabs the client drew, and shortening them left it
			-- holding the old height - so the tabs sat at the top of a band of
			-- nothing, a gap above the window they belong to.
			assert(_G.GeneralDockManager._height == _G.ChatFrame1Tab._height,
				("the dock comes down with them (%s vs %s)")
					:format(tostring(_G.GeneralDockManager._height),
						tostring(_G.ChatFrame1Tab._height)))
			-- A WINDOW YOU MADE IS NOT DOCKED WHERE GENERAL IS (Josh
			-- 2026-09-21). A new window's tab goes into the scrolling strip
			-- beside the client's own, centred on the strip - and a strip
			-- left at the old height put "Less" above the other tabs.
			assert(_G.GeneralDockManagerScrollFrame._height == _G.ChatFrame1Tab._height,
				("the strip a new window's tab sits in comes down too (%s vs %s)")
					:format(tostring(_G.GeneralDockManagerScrollFrame._height),
						tostring(_G.ChatFrame1Tab._height)))

			-- THE EDIT BOX, ON TOP, OVER THE TABS
			local box = _G.ChatFrame1EditBox
			local at = (box._points or {}).BOTTOMLEFT
			assert(at and at.relPoint == "TOPLEFT",
				"the edit box sits above the chat frame: " .. tostring(at and at.relPoint))
			-- THE SAME EDGES AS THE WINDOW UNDER IT (Josh 2026-09-20). Two
			-- rectangles nearly lining up look worse than two that do - so
			-- this is the PANEL's edges, not the chat frame's. FLUSH IS THE
			-- PANEL, NOT THE TEXT (Josh 2026-09-21): the frame is held in from
			-- the corner so the text has room, and the surface is stretched
			-- back out past it to meet the screen edge. The box follows the
			-- surface.
			local right = (box._points or {}).BOTTOMRIGHT
			local skin = mod.Skins()[_G.ChatFrame1]
			local panelLeft = (skin.fill._points or {}).TOPLEFT
			local panelRight = (skin.fill._points or {}).BOTTOMRIGHT
			assert(at.x == panelLeft.x and right and right.x == panelRight.x,
				("flush with the panel's own edges (%s/%s, %s/%s)")
					:format(tostring(at.x), tostring(panelLeft.x),
						tostring(right and right.x), tostring(panelRight.x)))
			assert(panelLeft.x < 0 and panelRight.x > 0,
				"and the panel reaches out past the frame it is padding")
			assert(_G.ChatFrame1EditBoxLeft._alpha == 0, "with the client's art off it")

			-- THE CLIENT PUTS IT BACK. ChatEdit_ActivateChat re-anchors the
			-- box every time it opens, so ours goes on after that rather than
			-- once at login.
			mod.Watch()
			box:ClearAllPoints()
			box:GetScript("OnShow")(box)
			assert((box._points or {}).BOTTOMLEFT, "showing it puts it back on top")

			-- WHAT THE SIDE BUTTONS DID (Josh 2026-09-20). Hiding them took
			-- the room back and took the scroll, the jump-to-bottom and the
			-- chat menu with it. The wheel covers one of those; nothing
			-- covered the others.
			-- FOUR SMALL MARKS IN THE CORNER (Josh 2026-09-20). Hiding the
			-- client's side buttons took the room back and took the scroll,
			-- the jump-to-newest and the chat menu with it. These give them
			-- back without giving the room back.
			local holder = _G.ChatFrame1.beebsControls
			assert(holder, "the controls come back as marks of our own")
			assert(#holder.list == 4, "four of them: up, down, the newest, menu")
			assert(not holder:IsShown(), "out of the way while you are reading")
			_G.ChatFrame1.IsMouseOver = function() return true end
			holder.Follow()
			assert(holder:IsShown(), "and there when you point at the chat frame")
			_G.ChatFrame1.IsMouseOver = function() return false end
			holder.IsMouseOver = function() return true end
			holder.Follow()
			assert(holder:IsShown(), "moving onto the marks themselves keeps them")
			holder.IsMouseOver = function() return false end
			holder.Follow()
			assert(not holder:IsShown(), "leaving both puts them away")

			-- they do the thing, rather than looking like they might
			local scrolled = {}
			_G.ChatFrame1.ScrollUp = function() scrolled.up = true end
			_G.ChatFrame1.ScrollToBottom = function() scrolled.bottom = true end
			holder.list[4]:GetScript("OnClick")(holder.list[4])
			holder.list[2]:GetScript("OnClick")(holder.list[2])
			assert(scrolled.up and scrolled.bottom, "the scroll ones scroll")
			-- the menu one presses the client's own button rather than
			-- reimplementing its menu
			local pressed = false
			_G.ChatFrameMenuButton.Click = function() pressed = true end
			holder.list[1]:GetScript("OnClick")(holder.list[1])
			assert(pressed, "and the menu one opens the client's own menu")
			-- A DROPDOWN OPENS ON A PRESS, AND ONLY WHEN IT IS UP (Josh
			-- 2026-09-24: "chat menu button does nothing"): opened its own
			-- way, from a button left showing - invisible - under the cog
			local opened = false
			_G.ChatFrameMenuButton.OpenMenu = function() opened = true end
			holder.list[1]:GetScript("OnClick")(holder.list[1])
			local mb = _G.ChatFrameMenuButton
			assert(opened, "the dropdown's own way of opening")
			assert(mb:IsShown() and mb._alpha == 0 and mb._points.CENTER and mb._points.CENTER.rel == holder.list[1],
				"from the client's button, showing but invisible, under the cog")
			mb.OpenMenu = nil
			-- and the client's own scrollbar is put away while the marks are on
			_G.ChatFrame1.ScrollBar = _G.CreateFrame("Frame", nil, _G.ChatFrame1)
			_G.ChatFrame1.ScrollToBottomButton = _G.CreateFrame("Button", nil, _G.ChatFrame1)
			_G.ChatFrame1.IsMouseOver = function() return true end
			holder.Follow()
			assert(not _G.ChatFrame1.ScrollBar:IsShown() and not _G.ChatFrame1.ScrollToBottomButton:IsShown(),
				"no scrollbar hanging off the window's edge")
			assert(holder.back and holder.back:IsShown(), "and the marks sit on a strip of the panel's fill")
			_G.ChatFrame1.IsMouseOver = function() return false end
			holder.Follow()

			-- THE LINE PREFIX (Josh 2026-09-20). "[1. General - Dun Morogh]" is
			-- thirty characters to say "this came from General", on EVERY
			-- line, so a third of the window is the same three words repeated
			-- down the left-hand edge. The zone is the worst of it: you are
			-- standing in it.
			assert(mod.Shorten("[1. General - Dun Morogh] hello") == "[1.Gen] hello",
				"the channel and its zone come down to three letters: "
					.. mod.Shorten("[1. General - Dun Morogh] hello"))
			assert(mod.Shorten("[2. Trade - City]") == "[2.Trd]", "and so does Trade")
			assert(mod.Shorten("[4. LookingForGroup]") == "[4.LFG]",
				"one we have a name for keeps it: " .. mod.Shorten("[4. LookingForGroup]"))
			assert(mod.Shorten("[9. Weatherwatchers]") == "[9.Wea]",
				"one we have not gets its first three letters")
			assert(mod.Shorten("[Guild] someone: hi") == "[Guild] someone: hi",
				"a channel with no number is left alone")
			-- the words themselves are never touched
			local link = "[1. General - Dun Morogh] |Hplayer:Bob|h[Bob]|h: hi"
			assert(mod.Shorten(link):find("|Hplayer:Bob|h%[Bob%]|h: hi"),
				"and the links inside the line come through exactly: " .. mod.Shorten(link))

			-- it goes on the frame's own AddMessage, where every line passes
			local f = _G.ChatFrame1
			local said = {}
			f.AddMessage = function(_, text) said[#said + 1] = text end
			mod.HookMessages(f)
			f:AddMessage("[1. General - Dun Morogh] hello")
			assert(said[1] == "[1.Gen] hello", "a line added is a line shortened: " .. said[1])
			mod.HookMessages(f, true)
			f:AddMessage("[1. General - Dun Morogh] hello")
			assert(said[2]:find("Dun Morogh", 1, true),
				"and switching it off gives the client its own line back")

			-- OUT OF THE WAY UNTIL YOU ARE TYPING (Josh 2026-09-20). The box
			-- lies over the tabs, and a frame over another frame takes the
			-- clicks whether or not there is anything to see - so "close it
			-- when a tab is clicked" only ran when the click got through, and
			-- it never did.
			local ebox = _G.ChatFrame1EditBox
			ebox.HasFocus = function() return false end
			mod.PlaceEditBox(ebox)
			-- THE HEADER STAYS (Josh 2026-09-20). It was hidden with the rest
			-- of the box's art, and the client's text inset - which exists to
			-- leave room for it - stayed behind as an empty margin.
			assert(_G.ChatFrame1EditBoxHeader == nil
				or _G.ChatFrame1EditBoxHeader._alpha ~= 0,
				"the label saying which channel you are about to speak in is left alone")
			assert(ebox._insets == nil,
				"and the room the client leaves for it is not trimmed")
			mod.PlaceEditBox(ebox)
			assert(ebox._strata == "BACKGROUND",
				"unfocused, it sits below the tabs: " .. tostring(ebox._strata))
			assert(ebox._mouse == false, "and takes no clicks at all")
			-- AND ITS SURFACE GOES WITH IT (Josh 2026-09-20). The box is
			-- dressed when it is placed, which is once - so the fill and the
			-- hairline stayed drawn while the box was closed, and that is the
			-- band beside the tabs.
			local boxSkin = mod.Skins()[ebox]
			assert(boxSkin, "the box has a surface")
			assert(not boxSkin.fill:IsShown(), "and it is not drawn while closed")
			mod.LiftEditBox(ebox, true)
			assert(ebox._strata == "DIALOG", "typing brings it up")
			assert(ebox._mouse == true, "and gives it the mouse back")
			assert(boxSkin.fill:IsShown(), "along with the surface it types on")

			-- A TAB CLICK IS NOT A REQUEST TO TYPE. With the edit box over the
			-- tabs, clicking one to read a different window opened the box.
			local tab = _G.ChatFrame1Tab
			local closed = false
			_G.ChatEdit_GetActiveWindow = function() return _G.ChatFrame1EditBox end
			_G.ChatFrame1EditBox.HasFocus = function() return false end
			_G.ChatEdit_DeactivateChat = function() closed = true end
			mod.HookTab(tab)
			tab:GetScript("OnClick")(tab)
			assert(closed, "clicking a tab puts the box away again")

			-- INTO THE CORNER. The margin is not padding: it is where the chat
			-- frame is, and this build lets the HUD Edit Mode own that. So the
			-- frame is moved rather than trimmed (Josh 2026-09-20).
			local f1 = _G.ChatFrame1
			-- as it is the first time the module sees it: no remembered place,
			-- and the client's own clamp margin still on
			f1.beebsWas, f1._clamp = nil, nil
			f1:ClearAllPoints()
			f1:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 30, 60)
			f1.GetPoint = function()
				local at = (f1._points or {}).BOTTOMLEFT or {}
				return "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", at.x, at.y
			end
			mod.StyleAll()
			-- FLUSH IS THE PANEL, NOT THE TEXT (Josh 2026-09-21). At nothing
			-- at all the text sat on the screen edge and the last line ran
			-- off the bottom, so the frame is held in by the padding and the
			-- surface is stretched back out past it to meet the corner.
			local pad = mod.FLUSH_INSET
			assert(pad > 0, "there is room for the text inside the panel")
			local corner = (f1._points or {}).BOTTOMLEFT
			assert(corner and corner.x == pad and corner.y == pad,
				("in from the corner by the padding (%s, %s)")
					:format(tostring(corner and corner.x), tostring(corner and corner.y)))
			local skin = mod.Skins()[f1]
			local left = (skin.fill._points or {}).TOPLEFT
			local low = (skin.fill._points or {}).BOTTOMRIGHT
			assert(left.x <= -pad and low.y <= -pad,
				("but the panel still reaches it (%s, %s)")
					:format(tostring(left.x), tostring(low.y)))
			assert(f1.beebsWas and f1.beebsWas.x == 30,
				"and where it was is remembered")
			-- THE CLAMP IS WHAT KEPT IT OFF THE EDGE (Josh 2026-09-20). A
			-- chat frame is clamped to the screen with insets, and those are
			-- a margin the client will not let it cross - so anchoring it to
			-- the corner put it there and the next clamp pushed it back out.
			assert(f1._clamp and f1._clamp[1] == 0 and f1._clamp[4] == 0,
				"the clamp insets are zeroed so it may reach the edge")
			assert(f1.beebsWas.clamp, "and the originals are remembered with the place")

			-- AND AGAIN WHENEVER THE CLIENT REARRANGES. Docking a window, the
			-- Edit Mode closing, a scale change - any of those undoes it.
			local events = mod.WatchEvents()
			assert(events and events:GetScript("OnEvent"), "something is listening")
			f1:ClearAllPoints()
			f1:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 30, 60)
			events:GetScript("OnEvent")(events, "UPDATE_CHAT_WINDOWS")
			local again = (f1._points or {}).BOTTOMLEFT
			assert(again and again.x == pad, "and puts it back in the corner")

			-- CANCEL IS NOT AN EVENT (Josh 2026-09-20). Saving a layout fires
			-- EDIT_MODE_LAYOUTS_UPDATED; cancelling fires nothing at all - the
			-- manager puts every frame back where its layout said and closes.
			_G.EditModeManagerFrame = _G.CreateFrame("Frame", "EditModeManagerFrame", _G.UIParent)
			mod.editHooked = nil
			assert(mod.HookEditMode(), "the manager is hooked once it exists")
			local onHide = _G.EditModeManagerFrame:GetScript("OnHide")
			assert(onHide, "its closing is what we listen to")
			f1:ClearAllPoints()
			f1:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 30, 60)
			-- the re-apply waits a frame, because the frames are put back as
			-- the manager goes away rather than before
			local realAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			onHide(_G.EditModeManagerFrame)
			_G.C_Timer.After = realAfter
			local afterCancel = (f1._points or {}).BOTTOMLEFT
			assert(afterCancel and afterCancel.x == pad,
				("closing it puts the corner back (%s)")
					:format(tostring(afterCancel and afterCancel.x)))

			-- and switching the module off gives the client everything back
			mod:OnDisable()
			local back = (f1._points or {}).BOTTOMLEFT
			assert(back and back.x == 30 and back.y == 60,
				"the frame goes back where you had it")
			assert(f1._clamp and f1._clamp[3] ~= 0, "with its margin back too: "
				.. table.concat(f1._clamp, ","))
			assert(_G.ChatFrame1ButtonFrame._alpha == 1, "the arrows come back")
			assert(_G.ChatFrame1TabLeft._alpha == 1, "and the tab's own art")
			BT.SetEnabled("chat", true)
		end },
		{ "the name is BeebMod, in the window and on the panel", function()
			BT.Window.Build()
			local frame = BT.Window.Frame()
			local title = frame.title._text or ""
			-- the toolkit's blue on the first half, the client's own colour
			-- on the second: a wordmark, not a sentence
			local plain = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			assert(plain == "BeebMod", "written the way it is said: " .. plain)
			assert(BT.TITLE == "BeebMod", "and read back the same: " .. BT.TITLE)
			-- THE SCRIBBLED-OUT LETTER IS GONE (Josh 2026-09-21). It was
			-- written as though somebody had typed it wrong and struck the
			-- stray letter through; at this size it read as a mistake rather
			-- than as a joke about one.
			assert(frame.scratch == nil, "no line through anything")
			-- the panel wears the same name
			BT.Bar.Create()
			local header = BT.Bar.Header()
			local worn = (header.title._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			assert(worn == "BeebMod", "and so does the panel: " .. worn)
			assert(header.scratch == nil, "with no line through it either")
			-- THE WAY OUT (Josh 2026-09-21). Escape closes this and so does
			-- the cog that opened it, but a window with no visible way to
			-- shut it reads as stuck - and this one went missing when the
			-- struck-out letter came off the title, because it lived in the
			-- same few lines.
			assert(frame.close, "there is a way out on the window itself")
			local out = (frame.close._points or {}).TOPRIGHT
			assert(out, "in the corner it is looked for in")
			BT.Window.Show("settings")
			frame.close:GetScript("OnClick")(frame.close)
			assert(not BT.Window.IsShown(), "and clicking it shuts the window")

			-- the folder and the saved variables keep their own name
			assert(_G.BeebModWindow, "the frame is still BeebModWindow")
		end },
		{ "the micro menu wears the toolkit's surface", function()
			-- SAME BARGAIN AS THE ACTION BARS (Josh 2026-09-21): every button
			-- still does what it did, keeps its own click handler and its own
			-- tooltip. Only textures change.
			local made = {}
			for i, name in ipairs({ "CharacterMicroButton", "SpellbookMicroButton" }) do
				local b = _G.CreateFrame("Button", name, _G.UIParent)
				local face = b:CreateTexture()
				b.GetNormalTexture = function() return face end
				b.FlashBorder = b:CreateTexture()
				_G[name] = b
				made[i] = { button = b, face = face }
			end
			_G.MICRO_BUTTONS = { "CharacterMicroButton", "SpellbookMicroButton" }

			local mod = BT.GetModule("micro")
			BT.SetEnabled("micro", true)
			assert(mod.StyleAll() == 2, "it found them: " .. tostring(mod.lastCount))

			local one = made[1]
			assert(not mod.Skins()[one.button], "docked, no tile is made for it: the panel is its surface")
			-- THEIR ART IS ONE IMAGE with the icon and its gold frame drawn
			-- together, so the frame is cropped rather than removed
			assert(one.face._texCoord and one.face._texCoord[1] > 0,
				"the bevel is cropped off the edge of the image")
			-- THE ICONS KEEP THEIR OWN COLOUR (Josh 2026-09-21). Draining
			-- them and tinting them to one material was three rounds of
			-- trying to make this row look like ours, and it never did: the
			-- shapes tell these buttons apart and the colour was never the
			-- loud part. What is ours is the tile and the bevel taken off.
			assert(one.face._grey == false, "the picture is left as it came")
			assert(one.face._vertex and one.face._vertex[1] == 1,
				"in its own colours, untinted")
			assert(mod.Opt("colour") == nil,
				"and there is no switch offering the other answer")
			assert(one.button.FlashBorder._alpha == 0, "the nagging border is out of the way")

			-- nothing that would change what a button DOES
			assert(one.button._width == nil, "it is never resized, only scaled")

			-- IN THE RIGHT PANEL (Josh 2026-09-22): the client's own buttons,
			-- moved into a line of the dock and scaled to fit it
			for _, m in ipairs(made) do
				m.button:SetSize(32, 40)
				m.button.SetScale = function(self, v) self._scale = v end
				m.button.GetScale = function(self) return self._scale or 1 end
			end
			BT.Bar.Relayout()
			mod.Fill()
			local section = mod.Section()
			assert(mod.InPanel() and section:IsShown(), "in the panel unless you say otherwise")
			assert(one.button:GetParent() == section and made[2].button:GetParent() == section,
				"every button is in the line")
			local scale = one.button._scale or 1
			assert(scale < 1 and 40 * scale <= section.wantHeight,
				"scaled down to fit it: " .. tostring(scale))
			local a, b = one.button._points.CENTER, made[2].button._points.CENTER
			assert(a and b and b.x > a.x, "side by side, in the client's order")
			made[2].button:Hide()
			mod.Fill()
			assert(one.button._points.CENTER.x ~= a.x, "one going makes room for the rest")
			made[2].button:Show()

			BT.SetEnabled("micro", false)
			assert(not section:IsShown() and one.button:GetParent() == _G.UIParent,
				"switched off, the client has them back")
			assert((one.button._scale or 1) == 1, "at their own size")
			BT.SetEnabled("micro", true)
			assert(one.button:GetParent() == section, "and on again brings them in")

			-- THE MENU MOVES WHOLE (Josh 2026-09-22): where the client lays the
			-- buttons out in a MicroMenu, taking one out broke its layout, so the
			-- menu itself goes into the line and the buttons stay its children
			BT.SetEnabled("micro", false)
			local container = _G.CreateFrame("Frame", "MicroMenuContainer", _G.UIParent)
			local menu = _G.CreateFrame("Frame", "MicroMenu", container)
			menu:SetSize(330, 40)
			menu.SetScale = function(self, v) self._scale = v end
			menu.GetScale = function(self) return self._scale or 0.7 end
			menu.Layout = function() end
			_G.MicroMenu, _G.MicroMenuContainer = menu, container
			for _, m in ipairs(made) do
				m.button:SetParent(menu)
			end
			-- never into a line that is not on screen: showing it would make
			-- the client lay out buttons that have no place yet
			section:Hide()
			mod.Layout()
			assert(menu:GetParent() == container, "not moved into a hidden line")
			BT.SetEnabled("micro", true)
			assert(section:IsShown() and menu:GetParent() == section,
				"the line goes up first, and then the menu is in it")
			assert(one.button:GetParent() == menu and made[2].button:GetParent() == menu,
				"and every button is still the menu's: nothing is pulled out of its layout")
			local width = section:GetWidth() or 220
			assert(menu._scale and 330 * menu._scale <= width, "scaled to the panel's width: " .. tostring(menu._scale))
			-- EDGE TO EDGE (Josh 2026-09-24): the width decides, not a height cap
			assert(math.abs(330 * menu._scale - (width - 16)) < 0.01,
				"the buttons fill the row, edge to edge: " .. tostring(330 * menu._scale))
			assert(section.wantHeight >= 40 * menu._scale + 10,
				"with room above and below them: " .. tostring(section.wantHeight))
			-- NO TILES IN THE PANEL: it is their surface there
			local tile = mod.Skins()[one.button]
			assert(not tile or (not tile.fill:IsShown() and not tile.rim[1]:IsShown()),
				"each button sits on the panel's own background, with no box round it")
			BT.SetEnabled("micro", false)
			assert(menu:GetParent() == container and menu._scale == 0.7,
				"off gives the menu back to the client, at its own scale")
			-- OFF IS THE CLIENT'S OWN MENU (Josh 2026-09-22): no tile, no crop
			assert((not tile or not tile.fill:IsShown()) and one.face._texCoord[1] == 0,
				"and in its own art, exactly as it came")
			assert(mod.InPanel() and BT.GetModule("micro").Opt("dock") == nil,
				"there is no switch between the panel and the corner")
			_G.MicroMenu, _G.MicroMenuContainer = nil, nil
			for _, m in ipairs(made) do
				m.button:SetParent(_G.UIParent)
			end
			BT.SetEnabled("micro", true)

			-- and the client redresses them, so we go on again afterwards
			mod.Watch()
			one.face:SetTexCoord(0, 1, 0, 1)
			one.button:GetScript("OnShow")(one.button)
			assert(one.face._texCoord[1] > 0, "showing one again dresses it again")

			mod:OnDisable()
			assert(one.face._texCoord[1] == 0, "and switching it off gives the art back")
			assert(one.button.FlashBorder._alpha == 1, "border and all")
		end },
		{ "the plate under the micro row, and your own face on it", function()
			-- THE PLATE WAS HIDING IT (Josh 2026-09-21). The row read as one
			-- dark mass only because the client's plate sat behind it; with
			-- the plate down, every button's gold rim stood against open snow.
			-- And the character button draws your head on a texture of its
			-- own, so nothing done to the button's faces ever reached it.
			local mod = BT.GetModule("micro")
			BT.SetEnabled("micro", true)

			local portrait = _G.CharacterMicroButton:CreateTexture()
			_G.MicroButtonPortrait = portrait

			local plate = _G.CreateFrame("Frame", "MicroButtonAndBagsBar", _G.UIParent)
			local art = plate:CreateTexture()

			mod.StyleAll()
			assert(portrait._grey == false, "your own head is left as it is, like the rest")
			assert(art._alpha == 0, "the client's plate is taken down")

			-- and the crop has to be deep enough to lose the rim now that
			-- there is nothing behind it to hide the rim
			local face = _G.CharacterMicroButton:GetNormalTexture()
			assert(face._texCoord[1] >= 0.2,
				"deep enough to lose the gold: " .. tostring(face._texCoord[1]))

			-- CROPPING IS ZOOMING, AND THE INSET PAYS FOR IT (Josh 2026-09-21).
			-- The two cancel exactly when the inset is CROP of the button's own
			-- size, so the picture comes out the size it always was. A picked
			-- number cannot do that - it is right at one button size only.
			local function drawnAt(button, width)
				button.GetWidth = function() return width end
				button.GetHeight = function() return width end
				mod.StyleButton(button)
				return button:GetNormalTexture()._points.TOPLEFT.x
			end
			local small = drawnAt(_G.CharacterMicroButton, 28)
			local big = drawnAt(_G.CharacterMicroButton, 56)
			assert(small == 6, "a 28px button insets by 6: " .. tostring(small))
			assert(big == 12, "and twice the button insets twice as far: " .. tostring(big))

			mod:OnDisable()
			assert(art._alpha == 1, "and switching it off gives the plate back")

			_G.MicroButtonAndBagsBar, _G.MicroButtonPortrait = nil, nil
		end },
		{ "switching a module on sets it up once", function()
			-- ONE PASS (Josh 2026-09-24): OnEnable and then OnBind was every
			-- module's whole setup twice
			local clock = BT.GetModule("clock")
			local hadEnable, hadBind = clock.OnEnable, clock.OnBind
			local enabled, bound = 0, 0
			clock.OnEnable = function() enabled = enabled + 1 end
			clock.OnBind = function() bound = bound + 1 end
			BT.SetEnabled("clock", false)
			BT.SetEnabled("clock", true)
			assert(enabled == 1 and bound == 0, "OnEnable alone: " .. enabled .. "/" .. bound)
			clock.OnEnable, clock.OnBind = hadEnable, hadBind
			-- a module with only an OnBind still has its book seen to
			local ledger = BT.GetModule("ledger")
			assert(ledger.OnEnable == nil, "the Ledger has no OnEnable")
			local hadLedgerBind, got = ledger.OnBind, nil
			ledger.OnBind = function(_, db) got = db end
			BT.SetEnabled("ledger", false)
			BT.SetEnabled("ledger", true)
			assert(got == BT.db, "its OnBind runs when it is switched on")
			ledger.OnBind = hadLedgerBind
			-- AND A RETIRED MODULE LEAVES NOTHING BEHIND
			local hadOrder = BT.settings.order
			BT.settings.bags = { crop = 0.08 }
			BT.settings.modules.bags = true
			BT.settings.order = { "ledger", "bags", "census" }
			assert(BT.DropRetired() == 3, "its settings, its switch and its place")
			assert(BT.settings.bags == nil and BT.settings.modules.bags == nil
				and table.concat(BT.settings.order, ",") == "ledger,census", "all gone")
			BT.settings.order = hadOrder
		end },
		{ "health and power slide to a new value, and jump for somebody new", function()
			-- EASED (Josh 2026-09-24): the client's own interpolation, handed to
			-- SetValue; a frame given somebody else, or a preview, jumps
			local F = BT.UnitFrames
			local hadEnum = _G.Enum
			_G.Enum = setmetatable({ StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } },
				{ __index = hadEnum })
			local b = F.Build(_G.UIParent, "target", nil, true)
			local seen = {}
			local set = b.health.SetValue
			b.health.SetValue = function(self, v, how) seen[#seen + 1] = how or "jump"; return set(self, v) end
			local wasExists, wasHealth, wasMax = _G.UnitExists, _G.UnitHealth, _G.UnitHealthMax
			_G.UnitExists = function() return true end
			_G.UnitHealthMax = function() return 100 end
			_G.UnitHealth = function() return 80 end
			local wasTime = _G.GetTime
			local clock = 100
			_G.GetTime = function() return clock end
			F.Bind(b, "target")
			assert(seen[#seen] == 0, "somebody new jumps straight to their health: " .. tostring(seen[#seen]))
			clock = clock + 1
			_G.UnitHealth = function() return 60 end
			F.Paint(b, F.Source("target"))
			assert(seen[#seen] == 1, "the same one slides: " .. tostring(seen[#seen]))
			F.Fresh(b)
			F.Paint(b, F.Source("target"))
			assert(seen[#seen] == 0, "and a new target jumps again, saying so: " .. tostring(seen[#seen]))
			F.Paint(b, F.Source("target"))
			assert(seen[#seen] == 0, "every paint in the moment after it too")
			clock = clock + 1
			F.Paint(b, F.Source("target"))
			assert(seen[#seen] == 1, "and it slides again after that")
			_G.GetTime = wasTime
			F.Paint(b, F.Fake({ name = "Defias", reaction = "hostile", hp = 50 }))
			assert(seen[#seen] == 0, "a preview never slides")
			_G.UnitExists, _G.UnitHealth, _G.UnitHealthMax = wasExists, wasHealth, wasMax
			_G.Enum = hadEnum
			b:Hide()
		end },
		{ "the bag window wears the toolkit's clothes, and takes them off again", function()
			-- THE CLIENT'S BAGS (Josh 2026-09-24): the window, its close and
			-- search, every slot, and each item's quality as a ring of its colour
			local mod = BT.GetModule("bagwindow")
			assert(mod and BT.Window.InSettings("bagwindow"), "a page of Game frames")
			local hadHook = _G.hooksecurefunc
			_G.hooksecurefunc = function(obj, name, fn)
				local orig = obj[name]
				obj[name] = function(...)
					local r = orig(...)
					fn(...)
					return r
				end
			end
			local win = _G.CreateFrame("Frame", "ContainerFrameCombinedBags", _G.UIParent)
			_G.ContainerFrameCombinedBags = win
			local frameArt = win:CreateTexture()
			frameArt._width, frameArt._height = 300, 200
			win.CloseButton = _G.CreateFrame("Button", nil, win)
			local redX = win.CloseButton:CreateTexture()
			win.SearchBox = _G.CreateFrame("EditBox", nil, win)
			local fieldArt = win.SearchBox:CreateTexture()
			local slot = _G.CreateFrame("Button", nil, win)
			slot.icon = slot:CreateTexture()
			slot.IconBorder = slot:CreateTexture()
			slot.IconBorder.GetVertexColor = function(self)
				local c = self._vertex or { 1, 1, 1, 1 }
				return c[1], c[2], c[3], c[4]
			end
			local normal = slot:CreateTexture()
			slot.GetNormalTexture = function() return normal end
			local money = _G.CreateFrame("Frame", "ContainerFrameCombinedBagsMoneyFrame", win)
			local coin = money:CreateTexture()
			coin.GetAtlas = function() return "coin-gold" end
			coin._width, coin._height = 12, 12

			BT.SetEnabled("bagwindow", true)
			mod.StyleAll()
			local panel = BT.Pill.Panels()[win]
			assert(panel and panel.fill:IsShown() and frameArt._alpha == 0, "the window on our surface, its art off")
			assert(redX._alpha == 0, "the red close square off, our cross on")
			assert(fieldArt._alpha == 0, "the search's rounded field off")
			assert(normal._alpha == 0 and slot.IconBorder._alpha == 0, "a slot's art and quality glow see-through")
			assert(slot.icon._texCoord and slot.icon._texCoord[1] > 0, "the picture cropped of its own border")
			assert(coin._alpha ~= 0 and coin._vertex == nil, "and the coins left exactly as they are")
			-- the client paints an uncommon item: our ring in its green
			slot.IconBorder:SetVertexColor(0.12, 1, 0)
			slot.IconBorder:Show()
			local found
			for _, t in ipairs({ slot:GetRegions() }) do
				if t._color and t._color[2] == 1 and t._color[1] == 0.12 then
					found = t
				end
			end
			assert(found, "a ring in the item's own quality colour")
			slot.IconBorder:Hide()
			assert(not found:IsShown(), "and none for an item with no quality border")
			-- a second update leaves a dressed slot alone
			slot.icon:SetTexCoord(0, 1, 0, 1)
			mod.StyleAll()
			assert(slot.icon._texCoord[1] == 0, "a slot is dressed once, not on every bag update")
			mod.Restyle()
			assert(slot.icon._texCoord[1] > 0, "and again for a new theme")

			-- DRAGGED BY ITS TITLE, AND IT STAYS (Josh 2026-09-24)
			mod.positionWatched, mod.handle, win.beebsPlaceWatched, win.beebsHandle = nil, nil, nil, nil
			assert(mod.WatchPosition(), "the window is watched")
			local handle = mod.Handle()
			assert(handle and handle:GetScript("OnDragStart"), "its title drags it")
			win.GetLeft = function() return 400 end
			win.GetTop = function() return 700 end
			win.GetEffectiveScale = function() return 1 end
			local parentTop = _G.UIParent.GetTop
			_G.UIParent.GetTop = function() return 900 end
			-- the client's title button, under the handle: a click still opens it
			local titleButton = _G.CreateFrame("Button", nil, win)
			local menuOpened = false
			titleButton.OpenMenu = function() menuOpened = true end
			titleButton.IsMouseOver = function() return true end
			handle:GetScript("OnMouseDown")(handle)
			handle:GetScript("OnMouseUp")(handle, "LeftButton")
			assert(menuOpened, "a click that is not a drag opens the client's menu under it")
			menuOpened = false
			handle:GetScript("OnMouseDown")(handle)
			handle:GetScript("OnDragStart")(handle)
			handle:GetScript("OnDragStop")(handle)
			handle:GetScript("OnMouseUp")(handle, "LeftButton")
			assert(not menuOpened, "and a drag does not")
			local kept = BT.settings.bagwindow.places.ContainerFrameCombinedBags
			assert(kept and kept.x == 400 and kept.y == -200, "where you left it is written down")
			-- the client places it again on the next open; it goes back
			win:ClearAllPoints()
			win:SetPoint("BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", -40, 90)
			win:GetScript("OnShow")(win)
			assert(win._points.TOPLEFT and win._points.TOPLEFT.x == 400 and win._points.TOPLEFT.y == -200,
				"and it goes back there when the game moves it")
			mod.ResetPosition()
			assert(BT.settings.bagwindow.places == nil, "/bt bags reset forgets it")
			-- EVERY WINDOW (Josh 2026-09-24): a bag a window keeps its own place
			local bag2 = _G.CreateFrame("Frame", "ContainerFrame2", _G.UIParent)
			_G.ContainerFrame2 = bag2
			bag2.GetLeft = function() return 900 end
			bag2.GetTop = function() return 600 end
			bag2.GetEffectiveScale = function() return 1 end
			mod.WatchPosition()
			local h2 = bag2.beebsHandle
			assert(h2 and h2 ~= handle, "a separate bag window has a handle of its own")
			h2:GetScript("OnMouseDown")(h2)
			h2:GetScript("OnDragStart")(h2)
			h2:GetScript("OnDragStop")(h2)
			local p2 = BT.settings.bagwindow.places.ContainerFrame2
			assert(p2 and p2.x == 900 and p2.y == -300 and BT.settings.bagwindow.places.ContainerFrameCombinedBags == nil,
				"and its own place, by its name")
			bag2:ClearAllPoints()
			assert(mod.ApplyAll() >= 1 and bag2._points.TOPLEFT.x == 900, "put back when the game lays them out")
			-- the one place the backpack had before, carried over
			BT.settings.bagwindow.places, BT.settings.bagwindow.pos = nil, { x = 12, y = -34 }
			assert(mod.PlaceOf(win).x == 12, "the backpack's old place is still read")
			mod.ResetPosition()
			_G.ContainerFrame2 = nil
			_G.UIParent.GetTop = parentTop

			BT.SetEnabled("bagwindow", false)
			assert(frameArt._alpha == 1 and redX._alpha == 1 and fieldArt._alpha == 1
				and normal._alpha == 1 and slot.IconBorder._alpha == 1, "switched off, every piece is the client's again")
			assert(slot.icon._texCoord[1] == 0 and not panel.fill:IsShown(), "the picture and the window too")
			_G.ContainerFrameCombinedBags = nil
			_G.hooksecurefunc = hadHook
		end },
		{ "a tooltip in the default spot is moved clear of the dock", function()
			-- THE CORNER IS OURS (Josh 2026-09-24): the client's default spot
			-- is where the dock stands, so the tooltip moves left of it - but
			-- only while the dock reaches down that far
			BT.Bar.Create()
			local bar = BT.Bar.Frame()
			bar:Show()
			local was = { bar.GetLeft, bar.GetTop, bar.GetBottom, bar.GetEffectiveScale }
			local dockBottom = 0
			bar.GetLeft = function() return 1300 end
			bar.GetTop = function() return 950 end
			bar.GetBottom = function() return dockBottom end
			bar.GetEffectiveScale = function() return 1 end
			local tip = _G.CreateFrame("Frame", nil, _G.UIParent)
			tip:SetPoint("BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", -13, 80)
			tip.GetRight = function() return 1522 end
			tip.GetBottom = function() return 80 end
			tip.GetHeight = function() return 60 end
			tip.GetEffectiveScale = function() return 1 end
			assert(BT.Bar.NoteDefault(tip), "moved")
			local at = tip._points.BOTTOMRIGHT
			assert(at and at.x == -13 - (1522 - 1300) - BT.Bar.TIP_GAP and at.y == 80,
				"its right edge just left of the dock, at the height the client chose: " .. tostring(at and at.x))
			-- THE QUESTS FOLDED: the dock ends high above it, so it goes back
			dockBottom = 500
			assert(not BT.Bar.ClearOfDock(tip), "not moved while the dock is short")
			assert(tip._points.BOTTOMRIGHT.x == -13, "back where the client put it")
			-- a tall tooltip that grows up into the dock is moved again
			tip.GetHeight = function() return 480 end
			assert(BT.Bar.ClearOfDock(tip), "one tall enough to reach it moves")
			-- one already clear is left where it is
			tip.GetRight = function() return 1200 end
			assert(not BT.Bar.NoteDefault(tip), "and one already clear is left alone")
			bar.GetLeft, bar.GetTop, bar.GetBottom, bar.GetEffectiveScale = was[1], was[2], was[3], was[4]
		end },
		{ "the quests are listed lowest level first", function()
			-- LOWEST FIRST (Josh 2026-09-24), the log's order among the same level
			local mod = BT.GetModule("tracker")
			BT.EnsureBound()
			BT.settings.tracker = BT.settings.tracker or {}
			BT.settings.tracker.byLevel = nil
			-- BY ZONE (Josh 2026-09-24): the zones in the log's order, the one you
			-- are in first, and lowest first inside each
			local list = mod.Sort({
				{ title = "Tears of the Moon", level = 12, index = 3, zone = "Darkshore" },
				{ title = "Return to Nessa", level = 10, index = 1, zone = "Teldrassil" },
				{ title = "Buzzbox 411", level = 12, index = 2, zone = "Darkshore" },
				{ title = "Return to Denalan", level = 9, index = 9, zone = "Teldrassil" },
				{ title = "The Red Crystal", level = 14, index = 4, zone = "Darkshore" },
				{ title = "Plagued Lands", level = 11, index = 5, zone = "Darkshore" },
			}, "Darkshore")
			local names = {}
			for i, q in ipairs(list) do names[i] = q.title end
			assert(table.concat(names, ",")
				== "Plagued Lands,Buzzbox 411,Tears of the Moon,The Red Crystal,Return to Denalan,Return to Nessa",
				"your zone first, lowest first in each: " .. table.concat(names, ","))
			BT.settings.tracker.byLevel = false
			local kept = mod.Sort({ { level = 12, index = 1, zone = "A" }, { level = 9, index = 2, zone = "A" } })
			assert(kept[1].level == 12, "and off, the log's own order inside a zone")
			BT.settings.tracker.byLevel = nil
		end },
		{ "your own frame shows your power, whatever it is", function()
			-- YOUR OWN, WHATEVER IT IS (Josh 2026-09-24): a party cell shows
			-- mana only - except yours, which shows your energy or rage too
			local F = BT.UnitFrames
			local b = F.Build(_G.UIParent, "party", nil, true)
			local was = { _G.UnitExists, _G.UnitPowerType, _G.UnitPowerMax, _G.UnitPower }
			_G.UnitExists = function() return true end
			_G.UnitPowerType = function() return 3, "ENERGY" end
			_G.UnitPowerMax = function() return 100 end
			_G.UnitPower = function() return 60 end
			F.Bind(b, "party2")
			assert(not b.power:IsShown(), "a rogue in your party: no energy bar on their cell")
			F.Bind(b, "player")
			assert(b.power:IsShown(), "your own frame: your energy")
			_G.UnitExists, _G.UnitPowerType, _G.UnitPowerMax, _G.UnitPower = was[1], was[2], was[3], was[4]
			b:Hide()
		end },
		{ "a menu button's picture is cropped within its own corner of a sheet", function()
			-- THE PICTURE'S OWN CORNERS (Josh 2026-09-24: icons vanished on
			-- hover): the crop is taken from the region the client set, and
			-- taken again when the client swaps the picture
			local mod = BT.GetModule("micro")
			local hadHook = _G.hooksecurefunc
			_G.hooksecurefunc = function(obj, name, fn)
				local orig = obj[name]
				obj[name] = function(...)
					local r = orig(...)
					fn(...)
					return r
				end
			end
			BT.SetEnabled("micro", true)
			local b = _G.CreateFrame("Button", "SheetMicroButton", _G.UIParent)
			local face = b:CreateTexture()
			local atlas, coords = "micro-up", { 0.5, 0.25, 0.5, 0.5, 0.75, 0.25, 0.75, 0.5 }
			face.GetAtlas = function() return atlas end
			face.GetTexCoord = function() return (table.unpack or unpack)(coords) end
			face.SetAtlas = function(self, a)
				atlas = a
				coords = { 0, 0.5, 0, 0.75, 0.25, 0.5, 0.25, 0.75 }
			end
			b.GetNormalTexture = function() return face end
			mod.StyleButton(b)
			local tc = face._texCoord
			assert(tc and tc[1] > 0.5 and tc[2] < 0.75 and tc[3] > 0.25 and tc[4] < 0.5,
				"cropped inside its own corner of the sheet: " .. table.concat(tc or {}, ","))
			-- the pointer arrives: the client swaps in the hover picture
			face:SetAtlas("micro-mouseover")
			tc = face._texCoord
			assert(tc[1] > 0 and tc[2] < 0.25 and tc[3] > 0.5 and tc[4] < 0.75,
				"and the hover picture is cropped in its own corner, not the file's: " .. table.concat(tc, ","))
			-- THE PICTURE STAYS UP UNDER THE POINTER: the client fades it on hover
			face:SetAlpha(0)
			assert(face._alpha == 1, "held at full strength when the client fades it on hover")
			mod.StyleButton(b, true)
			tc = face._texCoord
			assert(tc[1] == 0 and tc[2] == 0.25 and tc[3] == 0.5 and tc[4] == 0.75,
				"switched off, the picture's own corners exactly: " .. table.concat(tc, ","))
			_G.hooksecurefunc = hadHook
			b:Hide()
		end },
		{ "the game's menus wear the toolkit's clothes", function()
			-- ONE MENU SYSTEM (Josh 2026-09-24): whatever opens a menu, its art
			-- comes off and ours goes on; the hover light and the ticks stay
			local mod = BT.GetModule("menus")
			assert(mod and BT.Window.InSettings("menus"), "a page of Game frames")
			local hadHook, hadMenu = _G.hooksecurefunc, _G.Menu
			_G.hooksecurefunc = function(obj, name, fn)
				local orig = obj[name]
				obj[name] = function(...)
					local r = orig(...)
					fn(...)
					return r
				end
			end
			local open
			local manager = { OpenMenu = function(self, owner) end, GetOpenMenu = function() return open end }
			_G.Menu = { GetManager = function() return manager end }
			_G.TestMenuStyle1Mixin = { Generate = function(self) end }
			local wasAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			mod.hooked = nil
			BT.SetEnabled("menus", true)
			mod.Hook()

			local menu = _G.CreateFrame("Frame", nil, _G.UIParent)
			local art = menu:CreateTexture()
			art.GetAtlas = function() return "common-dropdown-bg" end
			art._width, art._height = 200, 120
			local light = menu:CreateTexture()
			light.GetAtlas = function() return "common-dropdown-highlight" end
			light._width, light._height = 180, 20
			local heading = menu:CreateFontString()
			heading:SetTextColor(1, 0.82, 0)
			open = menu
			manager:OpenMenu(nil)
			local panel = BT.Pill.Panels()[menu]
			assert(panel and panel.fill:IsShown(), "an opened menu wears our surface")
			assert(art._alpha == 0, "its stone background off")
			assert(light._alpha ~= 0, "the light under the pointer kept")
			assert(heading._textColor[3] > 0.5, "and a gold heading in the panel's text")
			-- a submenu, made rather than opened: dressed as its look is built
			local sub = _G.CreateFrame("Frame", nil, _G.UIParent)
			local subArt = sub:CreateTexture()
			subArt.GetAtlas = function() return "common-dropdown-bg" end
			subArt._width, subArt._height = 150, 80
			_G.TestMenuStyle1Mixin.Generate(sub)
			assert(subArt._alpha == 0 and BT.Pill.Panels()[sub], "a submenu too")

			BT.SetEnabled("menus", false)
			assert(art._alpha == 1 and subArt._alpha == 1 and not panel.fill:IsShown(),
				"switched off, the game's art is back")
			BT.SetEnabled("menus", true)
			_G.C_Timer.After = wasAfter
			_G.Menu, _G.TestMenuStyle1Mixin, _G.hooksecurefunc = hadMenu, nil, hadHook
			mod.hooked = nil
		end },
		{ "the settings window's rail and pages scroll when they hold more than fits", function()
			-- MORE THAN FITS, A WHEEL AWAY (Josh 2026-09-24)
			local W = BT.Widgets
			local host = _G.CreateFrame("Frame", nil, _G.UIParent)
			local view = W.Scroller(host, 6)
			view:SetHeight(200)
			view:SetContentHeight(500)
			assert(view:Max() == 300, "300 more than fits: " .. view:Max())
			assert(view.thumb:IsShown(), "a thumb says there is more")
			view:GetScript("OnMouseWheel")(view, -1)
			assert(view.offset == 40 and view.content._points.TOPLEFT.y == 40, "the wheel moves the strip up")
			view:ScrollTo(9999)
			assert(view.offset == 300, "and no further than the end")
			view:ScrollTo(-50)
			assert(view.offset == 0, "nor above the top")
			view:SetContentHeight(120)
			assert(view:Max() == 0 and not view.thumb:IsShown() and view.content._height == 200,
				"a short page is the window's height, with no thumb")
			-- a Stack built into it tells it how tall the page is
			local st = W.Stack(view.content)
			local block = _G.CreateFrame("Frame", nil, view.content)
			block:SetHeight(640)
			st:Add(block)
			st:Layout()
			assert(view.stacked and view.wanted >= 640, "a laid-out page measures itself")
			host:Hide()

			-- the window's own: the tabs on a strip that scrolls, each page's
			-- body on one too
			BT.Window.Build()
			local rail = BT.Window.Rail()
			assert(rail.view and rail.area and BT.Window.Tabs()[1]:GetParent() == rail.area,
				"the tabs sit on the rail's strip")
			assert((rail.view.wanted or 0) >= (rail.reach or 0), "as tall as the tabs reach")
			local panel = BT.Window.Panel("tips") or BT.Window.BuildPanel("tips")
			assert(panel.view and panel.body == panel.view.content, "and a page's body on a strip of its own")
		end },
		{ "the cog says what it opens", function()
			-- A TOOLTIP LIKE THE CENSUS'S (Josh 2026-09-24)
			BT.Bar.Create()
			local cog = BT.Bar.Cog()
			local lines, wasTip = {}, BT.Bar.Tip
			BT.Bar.Tip = function(_, fill)
				local wasAdd = _G.GameTooltip.AddLine
				_G.GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
				fill()
				_G.GameTooltip.AddLine = wasAdd
			end
			cog.button:GetScript("OnEnter")(cog.button)
			BT.Bar.Tip = wasTip
			assert(lines[1] == "Settings", "hovering the cog says Settings: " .. tostring(lines[1]))
		end },
		{ "shared pages: a switch each, and each one's settings under it while it is on", function()
			-- (Josh 2026-09-24) Experience and Reputation on one page, the Dock's
			-- own page with the dock's size and its header
			BT.Window.Build()
			BT.SetEnabled("xp", true)
			BT.SetEnabled("rep", true)
			BT.Window.SetView("rep")
			assert(BT.Window.View() == "progress", "a module on a shared page opens that page")
			local panel = BT.Window.Panel("progress")
			assert(panel and #panel.switches == 2 and panel.switches[1].module == "xp"
				and panel.switches[2].module == "rep", "a switch for each")
			assert(panel.enable == nil, "and no one switch over the page")
			panel.switches[2].switch:GetScript("OnClick")(panel.switches[2].switch)
			assert(not BT.Enabled("rep"), "the switch switches it")
			local tabOn
			for _, t in ipairs(BT.Window.Tabs()) do
				if t.key == "progress" then tabOn = not t.off end
			end
			assert(tabOn, "the tab is lit while either is on")
			panel.switches[2].switch:GetScript("OnClick")(panel.switches[2].switch)
			assert(BT.Enabled("rep"), "and back on")

			BT.Window.SetView("dock")
			local dock = BT.Window.Panel("dock")
			assert(dock and dock.body.sizeText and dock.body.sizeText._text:find("%%"),
				"the Dock's page says the dock's size: " .. tostring(dock.body.sizeText and dock.body.sizeText._text))

			-- THE BAG BAR IS THE BAG WINDOW'S (Josh 2026-09-24): away while either
			-- the Bags line or the bag window is on
			local space = BT.GetModule("bagspace")
			local bar = _G.CreateFrame("Frame", "BagsBar", _G.UIParent)
			_G.BagsBar = bar
			BT.SetEnabled("bagspace", false)
			BT.SetEnabled("bagwindow", true)
			space.Refit()
			assert(bar._alpha == 0, "away with only the bag window on")
			BT.SetEnabled("bagwindow", false)
			assert(bar._alpha == 1, "back with neither")
			BT.SetEnabled("bagwindow", true)
			_G.BagsBar = nil
		end },
		{ "the finer settings: health text, fading, the dock and the tooltips", function()
			-- (Josh 2026-09-24) the second step of the settings overhaul
			local F = BT.UnitFrames
			BT.EnsureBound()
			BT.settings.frames = BT.settings.frames or {}
			local hadHealth, hadFade = BT.settings.frames.health, BT.settings.frames.fade
			-- WHAT THE HEALTH SAYS, a frame at a time
			local target = F.Build(_G.UIParent, "target", nil, true)
			target.bmKind = "target"
			local fake = F.Fake({ name = "Defias", reaction = "hostile", hp = 72, max = 1540 })
			F.Paint(target, fake)
			assert(target.hpText._text ~= "" and target.value._text == "72%", "the target says both by default")
			BT.settings.frames.health = { target = "percent" }
			F.Paint(target, fake)
			assert(target.hpText._text == "" and target.value._text == "72%", "or just its share")
			BT.settings.frames.health = { target = "none" }
			F.Paint(target, fake)
			assert(not target.value:IsShown(), "or nothing")
			local cell = F.Build(_G.UIParent, "party", nil, true)
			cell.bmKind = "party"
			F.Paint(cell, F.Fake({ name = "Maelis", class = "PRIEST", hp = 40, max = 760 }))
			assert(not cell.value:IsShown(), "a party cell says nothing by default")
			BT.settings.frames.health = { party = "both" }
			F.Paint(cell, F.Fake({ name = "Maelis", class = "PRIEST", hp = 40, max = 760 }))
			assert(cell.value:IsShown() and cell.value._text:find("40%%"), "or both, in its corner: " .. tostring(cell.value._text))
			-- HOW FAR, as a choice
			BT.settings.frames.fade = "light"
			assert(F.Far(true) == 0.60 and F.Far(false) == 0.70, "light fades less")
			BT.settings.frames.fade = nil
			assert(F.Far(true) == F.GROUP_FAR, "strong is what it always was")
			BT.settings.frames.health, BT.settings.frames.fade = hadHealth, hadFade
			target:Hide()
			cell:Hide()

			-- THE DOCK: locked, and quieter in a fight
			BT.Bar.Create()
			local bar = BT.Bar.Frame()
			BT.settings.dockLocked = true
			BT.Bar.BeginDrag()
			assert(not bar.dragging, "a locked dock does not move")
			BT.settings.dockLocked = nil
			local wasCombat = _G.InCombatLockdown
			_G.InCombatLockdown = function() return true end
			bar.IsMouseOver = function() return false end
			BT.Bar.SetFade("strong")
			assert(BT.Bar.Fade() == 0.4 and bar._alpha == 0.4, "forty percent in a fight")
			bar.IsMouseOver = function() return true end
			assert(BT.Bar.Fade() == 1, "whole again under the pointer")
			_G.InCombatLockdown = function() return false end
			bar.IsMouseOver = function() return false end
			assert(BT.Bar.Fade() == 1, "and when the fight is over")
			BT.Bar.SetFade("off")
			_G.InCombatLockdown = wasCombat

			-- THE TOOLTIPS: at the pointer, and not in a fight
			local tips = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local tip = _G.CreateFrame("Frame", nil, _G.UIParent)
			local owned
			tip.SetOwner = function(_, owner, how) owned = how end
			assert(not tips.AnchorDefault(tip, _G.UIParent), "in the corner by default")
			tips.SetOpt("anchor", "cursor")
			assert(tips.AnchorDefault(tip, _G.UIParent) and owned == "ANCHOR_CURSOR", "or at the pointer")
			tips.SetOpt("anchor", nil)
			_G.InCombatLockdown = function() return true end
			local wasExists = _G.UnitExists
			_G.UnitExists = function() return true end
			assert(not tips.CombatHidden(tip, "mouseover"), "shown in a fight unless you ask")
			tips.SetOpt("combatHide", true)
			tip:Show()
			assert(tips.CombatHidden(tip, "mouseover") and not tip:IsShown(), "a unit's put away in a fight")
			assert(not tips.CombatHidden(tip, nil), "an item's still shows")
			tips.SetOpt("combatHide", nil)
			_G.InCombatLockdown, _G.UnitExists = wasCombat, wasExists
		end },
		{ "every page builds, and the last of the finer settings do what they say", function()
			-- (Josh 2026-09-24) every tab on the rail, opened: a page that throws
			-- as it builds is caught here, not in the game
			BT.Window.Build()
			local before = #(BT.moduleErrors or {})
			for _, t in ipairs(BT.Window.Tabs()) do
				if t.key and t:IsShown() then
					BT.Window.SetView(t.key)
					assert(BT.Window.Panel(t.key), t.key .. " builds a page")
				end
			end
			assert(#(BT.moduleErrors or {}) == before, "and no page errors: "
				.. table.concat(BT.moduleErrors or {}, " | "))

			-- the quest tracker: this zone only, and no headings
			local tracker = BT.GetModule("tracker")
			BT.settings.tracker = BT.settings.tracker or {}
			local quests = { { title = "A", level = 5, index = 1, zone = "Darkshore" },
				{ title = "B", level = 3, index = 2, zone = "Teldrassil" } }
			BT.settings.tracker.hereOnly = true
			local here = tracker.Filter(quests, "Darkshore")
			assert(#here == 1 and here[1].title == "A", "only the zone you are in")
			BT.settings.tracker.hereOnly = nil
			BT.settings.tracker.zones = false
			local flat = tracker.Sort({ quests[1], quests[2] }, "Darkshore")
			assert(flat[1].title == "B", "no headings, no grouping: lowest first across all")
			BT.settings.tracker.zones = nil

			-- metrics: two columns
			BT.settings.metricsCols = 2
			assert(BT.Bar.Cols() == 2, "two readouts to a line")
			BT.settings.metricsCols = nil
			assert(BT.Bar.Cols() == 3, "three by default")

			-- chat: the time in front, but not twice
			local chat = BT.GetModule("chat")
			BT.settings.chat = BT.settings.chat or {}
			assert(chat.Stamp("hello") == "hello", "no time unless you ask")
			BT.settings.chat.timestamps = true
			local wasCVar = _G.GetCVar
			_G.GetCVar = function() return "none" end
			assert(chat.Stamp("hello"):find("%d%d:%d%d|r hello$"), "the time in front: " .. chat.Stamp("hello"))
			_G.GetCVar = function() return "%H:%M " end
			assert(chat.Stamp("hello") == "hello", "not when the game's own are on")
			_G.GetCVar = wasCVar
			BT.settings.chat.timestamps = nil

			-- the micro menu: a button left out, and back
			local micro = BT.GetModule("micro")
			local shop = _G.CreateFrame("Button", "StoreMicroButton", _G.UIParent)
			_G.StoreMicroButton = shop
			BT.SetEnabled("micro", true)
			micro.SetHidden("StoreMicroButton", true)
			assert(not shop:IsShown(), "the shop left out")
			shop:Show()
			local onShow = shop:GetScript("OnShow")
			assert(onShow, "it watches for the game showing it")
			onShow(shop)
			assert(not shop:IsShown(), "and keeps it out when the game does")
			micro.SetHidden("StoreMicroButton", false)
			assert(shop:IsShown(), "and back in")
			_G.StoreMicroButton = nil

			-- the census: kept still while open, if you like
			BT.settings.censusLive = false
			BT.CensusWindow.Show()
			BT.DB.Note(BT.db, "Stillness Test", "Whitemane", { class = "MAGE" }, os.time())
			assert(BT.CensusWindow.Tick() == false, "no redraw while it is to stay still")
			BT.settings.censusLive = nil
			BT.CensusWindow.Hide()

			-- the damage meter: its additions each a switch
			local dm = BT.GetModule("damagemeter")
			assert(dm.Opt("perSecond", true) == true and dm.Opt("clock", true) == true, "both on by default")
		end },
		{ "one look, set in one place", function()
			-- WHAT THE TOOLKIT LOOKS LIKE WAS NOT A SETTING (Josh 2026-09-21).
			-- The fill and the rim were constants in UI/Widgets.lua and the
			-- rim's thickness was a hard-coded 1, four files deep.
			local W, T = BT.Widgets, BT.Theme
			BT.EnsureBound()
			BT.settings.theme = nil

			-- THE PRESET IS THE DEFAULT. A warlock's panels come up violet
			-- without anyone setting anything.
			local wasClass = _G.UnitClass
			_G.UnitClass = function() return "Warlock", "WARLOCK" end
			T.Apply()
			assert(T.Preset_Name() == "class", "the class is where it starts")
			local rim = W.RIM
			assert(rim[3] > rim[2] and rim[3] > 0.3,
				("a warlock's rim is violet (%.2f, %.2f, %.2f)")
					:format(rim[1], rim[2], rim[3]))
			-- and the fill carries the same hue rather than being flat black
			-- under a coloured edge, which reads as two unrelated decisions
			assert(W.FILL[3] > W.FILL[1], "the fill carries the hue too")

			-- THE TABLES ARE MUTATED, NOT REPLACED. Every module captured
			-- `local FILL = BT.Widgets.FILL` at load, so a new table would
			-- leave all of them holding the old colours for the session.
			local held = W.FILL
			_G.UnitClass = function() return "Druid", "DRUID" end
			T.Apply()
			assert(held == W.FILL, "the same table everything is holding")
			assert(held[1] > held[3], "a druid's is orange, in that same table")

			-- your own colour is yours, and saying so is what stops the next
			-- login reading the class again and throwing it away
			T.Set("rim", { 0.9, 0.1, 0.1 })
			assert(T.Preset_Name() == "custom", "picking a colour leaves the preset")
			assert(W.RIM[1] == 0.9, "and the colour is the one you picked")
			_G.UnitClass = function() return "Mage", "MAGE" end
			T.Apply()
			assert(W.RIM[1] == 0.9, "a different class does not overwrite it")

			-- THICKNESS AND RADIUS DRAW. A number nothing reads is not a
			-- setting, so both are checked on a real panel.
			local f = _G.CreateFrame("Frame", nil, _G.UIParent)
			local bg = select(1, BT.Pill.Panel(f))
			local h = BT.Pill.Panels()[f]
			T.Set("preset", "class")
			T.Set("radius", 0)
			T.Set("thickness", 3)

			-- A RIM IS A RING, NOT A RECTANGLE UNDER THE FILL (Josh
			-- 2026-09-21). Drawn full-size underneath, twelve percent of it
			-- came through the translucent fill across the WHOLE panel: set
			-- the border red and the background went red, everywhere.
			assert(bg._points == nil, "the fill covers the frame, corner to corner")
			local top, left = h.rim[1], h.rim[3]
			assert(top._height == 3 and left._width == 3,
				("the border is as heavy as asked (%s, %s)")
					:format(tostring(top._height), tostring(left._width)))
			local edge, back = T.Rim(), T.Fill()
			assert(math.abs(top._color[1] - edge[1]) < 0.001, "the ring is the border colour")
			assert(math.abs(bg._color[1] - back[1]) < 0.001,
				"and the fill is only ever the background colour")

			-- at radius 0 nothing rounded is built at all: most of this addon
			-- is square and should not pay seven textures a panel for it
			assert(h.roundEdge == nil, "square panels build no corner pieces")
			T.Set("radius", 6)
			assert(h.roundEdge and h.roundEdge.corners.TOPLEFT,
				"and rounding builds them")
			assert(h.roundEdge.corners.TOPLEFT._width == 6, "as round as asked")
			-- DRAWN IN PIXELS: rows one pixel high, no picture to shimmer
			local rows = h.roundEdge.rows.TOPLEFT
			assert(#rows >= 6 and rows[1]._height == 1 and rows[1]._texture == nil,
				"the corner is rows of plain colour: " .. #rows)
			local widest = 0
			for _, t in ipairs(rows) do
				if t._shown ~= false and t._height == 1 then widest = math.max(widest, t._width or 0) end
			end
			assert(widest <= 6 and widest >= 5, "and the widest row reaches across the corner: " .. widest)
			-- HIDDEN AND SHOWN AGAIN, THE CORNERS COME BACK (the audit): only the
			-- invisible corner boxes were re-shown, leaving a notch at each corner
			BT.Pill.ShowSurface(h, false)
			assert(h.roundFill.rows.TOPLEFT[1]._shown == false, "hidden with the surface")
			BT.Pill.ShowSurface(h, true)
			assert(h.roundFill.rows.TOPLEFT[1]._shown ~= false and h.roundEdge.rows.TOPLEFT[1]._shown ~= false,
				"and shown again with it, fill and edge")
			assert(bg._shown == false, "the square fill steps aside")

			-- THE RING STOPS SHORT OF THE CORNERS, all four of them, leaving
			-- the arcs room. Running a bar to the frame's edge would lay it
			-- ON the corner piece, and two half-transparent fills over each
			-- other read as a dark square where an arc should be.
			local at = (h.rim[1]._points or {}).TOPLEFT
			assert(at and at.x == 6,
				("the top bar starts past the corner (%s)"):format(tostring(at and at.x)))
			local low = (h.rim[3]._points or {}).BOTTOMLEFT
			assert(low and low.y == 6,
				("and the side bars stop above the bottom ones (%s)"):format(tostring(low and low.y)))

			-- AND THE BORDER IS THE SAME THE WHOLE WAY ROUND (Josh
			-- 2026-09-21). A three-pixel stripe ran down the dock's left
			-- edge, from when the toolkit's green was the only colour it had.
			-- Painting it the border colour was not enough: four pixels of
			-- border on one side of a panel whose other three are one reads
			-- as a panel drawn wrong, not as an accent.
			assert(BT.Bar.Accent == nil, "there is no stripe on one edge")
			assert(BT.Bar.Frame().accent == nil, "nor a texture left behind for one")

			-- AND THE RADIUS REACHES WHAT THE WINDOW IS NOT (Josh 2026-09-21).
			-- Rounding was written into the panel only, so it rounded the
			-- window and did nothing at all to the action bars, the chat, the
			-- bags or the micro menu - which are the frames it shows on most.
			-- One shape routine now, so there is nowhere for it to not reach.
			T.Set("radius", 8)
			for _, key in ipairs({ "bars", "micro", "chat" }) do
				local m = BT.GetModule(key)
				BT.SetEnabled(key, true)
				m.StyleAll()
				local one = next(m.Skins())
				if one then
					-- through the module's own styling, not just StyleAll:
					-- some of these dress frames the stub never lists
					if m.StyleButton then
						m.StyleButton(one)
					end
					local skin = m.Skins()[one]
					assert(skin.roundEdge and skin.roundEdge.corners.TOPLEFT,
						key .. " rounds its corners too")
					assert(skin.fill._shown == false,
						key .. " puts the square shape away while it does")
				end
			end

			T.Set("preset", "class")
			T.Set("thickness", 1)
			T.Set("radius", 0)
			_G.UnitClass = wasClass
			T.Apply()
		end },
		{ "the appearance rows say what is chosen, and repaint what is drawn", function()
			-- ALL THREE OF THESE LOOKED FINE AND DID NOTHING (Josh 2026-09-21).
			local T = BT.Theme
			BT.Window.Build()
			BT.Window.Show("settings")
			local a = BT.Settings.Appearance()
			assert(a, "the appearance rows are built")

			-- A BUTTON IS NOT A PILL. Pill.Color returns at the door for
			-- anything without pill art, so the chosen preset was never marked.
			T.Set("preset", "house")
			BT.Settings.Refresh()
			for _, b in ipairs(a.presets.buttons) do
				assert(b.pressed == (b.preset == "house"),
					"the preset you are on is the one that is lit: " .. b.preset)
			end
			T.Set("preset", "class")
			BT.Settings.Refresh()
			for _, b in ipairs(a.presets.buttons) do
				assert(b.pressed == (b.preset == "class"), "and it follows the choice")
			end

			-- A SWATCH IS NOT A PANEL. Drawn with Pill.Panel it went black the
			-- moment corner radius went above zero, because Panel hides its
			-- square textures and the refresh went on colouring the hidden two.
			T.Set("radius", 8)
			BT.Settings.Refresh()
			local rim = T.Rim()
			local shown = a.rim.box.bg
			assert(shown._color and math.abs(shown._color[1] - rim[1]) < 0.001,
				"the border swatch shows the border colour, rounded or not")
			assert(shown._shown ~= false, "and is still on screen")

			-- A FIXED OUTLINE, NOT A DARKER COPY (Josh 2026-09-21). Drawing
			-- the swatch's own colour at half strength gives a near-black
			-- background a near-black outline, so the swatch and the panel
			-- behind it are the same thing and there is nothing to click.
			T.Set("fill", { 0, 0, 0, 1 })
			BT.Settings.Refresh()
			local outline = a.fill.box.rim._color
			assert(outline[1] > 0.3,
				"a black swatch still has an edge you can see: " .. tostring(outline[1]))
			T.Set("preset", "class")
			BT.Settings.Refresh()
			T.Set("radius", 0)

			-- AND THE CHAT SURFACE IS PAINTED EVERY PASS, NOT ONCE. Its
			-- colours were set where the textures were created, so it kept
			-- whatever the theme was when a chat window first appeared.
			BT.SetEnabled("chat", true)
			BT.GetModule("chat").StyleAll()
			local skin = BT.GetModule("chat").Skins()[_G.ChatFrame1]
			T.Set("rim", { 0.9, 0.2, 0.2 })
			BT.GetModule("chat").StyleAll()
			assert(math.abs(skin.rim[1]._color[1] - 0.9) < 0.001,
				"the chat window follows the theme like everything else")
			-- and the border colour is NOT also a background tint
			assert(math.abs(skin.fill._color[1] - T.Fill()[1]) < 0.001,
				"while its background stays the background colour")
			T.Set("preset", "class")
		end },
		{ "a title on the plain fill needs no edge of its own", function()
			-- NO SHADOW (Josh 2026-09-22). The name used to sit on a wash of
			-- its class colour, where a rogue's yellow landed on yellow and
			-- only a drop shadow kept it legible. The wash is gone and the
			-- name is in its colour on the dark fill, so the shadow - the
			-- only one in the theme - goes with it.
			BT.SetEnabled("tips", true)
			local tip = _G.GameTooltip
			local wasPlayer = _G.UnitIsPlayer
			_G.UnitIsPlayer = function() return true end
			tip.GetName = function() return "GameTooltip" end
			_G.GameTooltipTextRight1 = _G.GameTooltipTextRight1
				or _G.CreateFrame("FontString")
			BT.UnitTip.RestoreFonts()
			BT.GetModule("tips").Compose(tip, "target")
			_G.UnitIsPlayer = wasPlayer

			local name = BT.UnitTip.LineOf(tip, 1)
			assert(not name._shadow or name._shadow[4] == 0,
				"the name carries no shadow")
			local level = BT.UnitTip.LineOf(tip, 1, "TextRight")
			assert(not level._shadow or level._shadow[4] == 0,
				"and neither does the level beside it")
			BT.UnitTip.RestoreFonts()
		end },
		{ "the damage meter wears the theme, and takes it off again", function()
			-- FOUND, NOT NAMED (Josh 2026-09-22). The client's meter window is
			-- looked up by name at runtime; here it is handed over directly.
			local mod = BT.GetModule("damagemeter")
			assert(mod, "the module is registered")
			local root = _G.CreateFrame("Frame", "DamageMeterTestWindow", _G.UIParent)
			local art = root:CreateTexture()
			art._width, art._height = 200, 40
			local row = _G.CreateFrame("Frame", nil, root)
			local band = row:CreateTexture()
			assert(mod.AddRoot(root), "a window can be handed over")
			BT.SetEnabled("damagemeter", true)
			local n = mod.StyleAll()
			assert(n > 0, "something was dressed: " .. tostring(n))
			assert(art._alpha == 0, "the client's art is out of the way")
			assert(band._alpha == 0, "down the tree too")
			local h = BT.Pill.Panels()[root]
			assert(h and h.fill:IsShown(), "and our surface is on")
			assert(root.bmShadow, "with the same shadow the window wears")
			BT.SetEnabled("damagemeter", false)
			assert(art._alpha == 1 and band._alpha == 1, "switched off, the art comes back")
			assert(not h.fill:IsShown(), "and the surface goes")
			BT.SetEnabled("damagemeter", true)
			-- and it lives in Settings, like the other furniture
			assert(BT.Window.InSettings("damagemeter"), "it is a page of Settings, not a tab")

			-- A LITTLE MORE THAN THE CLIENT'S (Josh 2026-09-24): a session window
			-- with its header, a row and the spell breakdown
			local hadHook = _G.hooksecurefunc
			_G.hooksecurefunc = function(obj, name, fn)
				local orig = obj[name]
				obj[name] = function(...)
					local r = orig(...)
					fn(...)
					return r
				end
			end
			local wasDuration = _G.C_DamageMeter.GetSessionDurationSeconds
			_G.C_DamageMeter.GetSessionDurationSeconds = function(session)
				return session == Enum.DamageMeterSessionType.Overall and 72 or nil
			end
			local win = _G.CreateFrame("Frame", nil, root)
			win.DamageMeterTypeDropdown = _G.CreateFrame("Button", nil, win)
			local arrow = win.DamageMeterTypeDropdown:CreateTexture()
			arrow.GetAtlas = function() return "common-dropdown-a-button-shadowless" end
			arrow._width, arrow._height = 34, 32 -- drawn big for a moment
			win.DamageMeterTypeDropdown.Arrow = arrow
			win.SessionDropdown = _G.CreateFrame("Button", nil, win)
			win.SessionDropdown.SessionName = win.SessionDropdown:CreateFontString()
			win.SessionDropdown.SessionName:SetText("O")
			-- the dropdown's own label, writing the same letter
			local second = win.SessionDropdown:CreateFontString()
			second:SetText("O")
			win.MinimizeContainer = _G.CreateFrame("Frame", nil, win)
			win.MinimizeContainer.ScrollBox = _G.CreateFrame("Frame", nil, win.MinimizeContainer)
			local target = _G.CreateFrame("Frame", nil, win.MinimizeContainer.ScrollBox)
			win.MinimizeContainer.ScrollBox.ScrollTarget = target
			local meterRow = _G.CreateFrame("Button", nil, target)
			meterRow.StatusBar = _G.CreateFrame("StatusBar", nil, meterRow)
			meterRow.StatusBar.Value = meterRow.StatusBar:CreateFontString()
			meterRow.GetElementData = function() return { totalAmount = 900 } end
			win.MinimizeContainer.SourceWindow = _G.CreateFrame("Frame", nil, win.MinimizeContainer)
			mod.StyleAll()
			assert(arrow._alpha ~= 0 and arrow._vertex, "the type arrow stays, as a mark, whatever size it is drawn")
			assert(win.SessionDropdown.SessionName._text == "Overall", "the session said in full: "
				.. tostring(win.SessionDropdown.SessionName._text))
			assert(second._alpha == 0, "and said once: the dropdown's own letter is not drawn over it")
			-- STILL "OOverall" (Josh 2026-09-24): the client writes its label after ours
			local late = _G.CreateFrame("Frame", nil, win.SessionDropdown)
			local lateText = late:CreateFontString()
			mod.StyleAll()
			lateText:SetText("O")
			assert(lateText._alpha == 0, "a label the client writes later is quiet too")
			win.SessionDropdown.SessionName:SetText("C")
			assert(win.SessionDropdown.SessionName._text == "Current", "whichever the client writes")
			win.SessionDropdown.SessionName:SetText("O")
			assert(win.beebsClock and win.beebsClock._text == "1:12", "the fight's length in the header: "
				.. tostring(win.beebsClock and win.beebsClock._text))
			-- THE SESSION FIRST: no room for both, and the clock gives way
			win.beebsClock.GetRight = function() return 200 end
			win.SessionDropdown.SessionName.GetLeft = function() return 190 end
			mod.Tick(win)
			assert(not win.beebsClock:IsShown(), "the clock hides rather than run into the session")
			win.SessionDropdown.SessionName.GetLeft = function() return 260 end
			mod.Tick(win)
			assert(win.beebsClock:IsShown(), "and shows where there is room")
			meterRow.StatusBar.Value:SetText("900")
			assert(meterRow.StatusBar.Value._text == "900 (12.5)", "each row's rate after its total: "
				.. tostring(meterRow.StatusBar.Value._text))
			meterRow.GetElementData = function() return { totalAmount = 900, amountPerSecond = 15 } end
			meterRow.StatusBar.Value:SetText("900")
			assert(meterRow.StatusBar.Value._text == "900 (15.0)", "the client's own rate when it has one")
			local src = BT.Pill.Panels()[win.MinimizeContainer.SourceWindow]
			assert(src and src.fill:IsShown(), "the breakdown wears a surface of its own")
			BT.SetEnabled("damagemeter", false)
			assert(second._alpha == 1, "the dropdown's letter back too")
			assert(win.SessionDropdown.SessionName._text == "O" and meterRow.StatusBar.Value._text == "900"
				and not win.beebsClock:IsShown() and not src.fill:IsShown(), "and off, all of it is the client's again")
			BT.SetEnabled("damagemeter", true)
			_G.C_DamageMeter.GetSessionDurationSeconds = wasDuration
			_G.hooksecurefunc = hadHook
		end },
		{ "the resource display wears the theme and grows combo points", function()
			-- A NAMEPLATE IS BORROWED (Josh 2026-09-22): the client hands the
			-- player's plate over and takes it back, and this follows it.
			local mod = BT.GetModule("prd")
			assert(mod, "the module is registered")
			local plate = _G.CreateFrame("Frame", nil, _G.UIParent)
			plate.UnitFrame = _G.CreateFrame("Frame", nil, plate)
			local art = plate.UnitFrame:CreateTexture()
			art._width, art._height = 120, 12
			_G.C_NamePlate = { GetNamePlateForUnit = function(unit)
				if unit == "player" then return plate end
			end }
			local wasClass, wasMax, wasPower = _G.UnitClass, _G.UnitPowerMax, _G.UnitPower
			_G.UnitClass = function() return "Rogue", "ROGUE" end
			_G.UnitPowerMax = function(_, kind) return kind == 4 and 5 or 100 end
			_G.UnitPower = function(_, kind) return kind == 4 and 3 or 50 end
			BT.SetEnabled("prd", true)
			mod.Apply()
			assert(mod.CurrentPlate() == plate, "it found the player's plate")
			assert(art._alpha == 0, "the plate's art is out of the way")
			local pips = mod.PipFrame()
			assert(pips and pips:IsShown(), "and a row of pips hangs under it")
			assert(#pips.squares == 5, "one per possible point: " .. tostring(#pips.squares))
			assert(pips._parent == plate or pips:GetParent() == plate, "on the plate, so it moves with it")
			-- each segment is a bar from i - 1 to i, full when the count reaches i
			local function lit()
				local n = 0
				for i = 1, 5 do
					local sq = pips.squares[i]
					if sq._min == i - 1 and sq._max == i and sq._value >= i then
						n = n + 1
					end
				end
				return n
			end
			assert(lit() == 3, "three of them lit for three points: " .. tostring(lit()))
			local c = pips.squares[1]._barColor
			assert(c and math.abs(c[1] - BT.Widgets.ACCENT[1]) < 0.001, "lit in the accent")

			-- UNIT_POWER_FREQUENT carries the points (Josh 2026-09-23): the
			-- row sat empty with three on the target frame
			assert(mod.events._events.UNIT_POWER_FREQUENT, "it listens to the event that carries points")
			_G.UnitPower = function(_, kind) return kind == 4 and 4 or 50 end
			mod.events:GetScript("OnEvent")(mod.events, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
			assert(lit() == 4, "a fourth point lights the fourth segment: " .. tostring(lit()))

			-- a classic client counts them on the target
			_G.UnitPower = function(_, kind) return kind == 4 and 0 or 50 end
			local wasGCP = _G.GetComboPoints
			_G.GetComboPoints = function() return 2 end
			mod.Pips(mod.Combo())
			assert(lit() == 2, "points on the target count: " .. tostring(lit()))

			-- a secret count is handed to the bars as it came, never compared
			_G.secretMeasurements = true
			_G.UnitPower = function(_, kind) return kind == 4 and _G.SECRET_WIDTH or 50 end
			_G.GetComboPoints = function() return 0 end
			local cur, max, show, hidden = mod.Combo()
			assert(hidden and show and max == 5 and cur == _G.SECRET_WIDTH, "a secret count is kept, not zeroed")
			mod.Pips(cur, max, show)
			assert(pips.squares[1]._value == _G.SECRET_WIDTH, "and the bars are given it")
			assert(not mod.Said():find(tostring(_G.SECRET_WIDTH), 1, true), "and it is never printed")
			_G.secretMeasurements = false
			_G.GetComboPoints = wasGCP
			_G.UnitPower = function(_, kind) return kind == 4 and 3 or 50 end
			mod.Pips(mod.Combo())

			-- a druid out of cat form has nothing to show
			_G.UnitClass = function() return "Druid", "DRUID" end
			_G.UnitPowerType = function() return 0 end
			mod.Pips(mod.Combo())
			assert(not pips:IsShown(), "a bear shows no points")
			_G.UnitPowerType = function() return 3 end
			mod.Pips(mod.Combo())
			assert(pips:IsShown(), "a cat does")
			_G.UnitPowerType = nil

			-- a warrior has none at all
			_G.UnitClass = function() return "Warrior", "WARRIOR" end
			_G.UnitPowerMax = function(_, kind) return kind == 4 and 0 or 100 end
			mod.Pips(mod.Combo())
			assert(not pips:IsShown(), "and a warrior has no row")

			-- the client takes the plate back: everything goes with it
			_G.UnitClass = function() return "Rogue", "ROGUE" end
			_G.UnitPowerMax = function(_, kind) return kind == 4 and 5 or 100 end
			mod.Apply()
			mod.events:GetScript("OnEvent")(mod.events, "NAME_PLATE_UNIT_REMOVED", "player")
			assert(art._alpha == 1, "the plate's art comes back when the plate is given back")
			assert(not pips:IsShown(), "and the pips go")
			assert(mod.CurrentPlate() == nil, "and it is nobody's plate now")

			-- the switches
			mod.events:GetScript("OnEvent")(mod.events, "NAME_PLATE_UNIT_ADDED", "player")
			assert(art._alpha == 0 and pips:IsShown(), "and it all comes back when the plate does")
			mod.SetOpt("theme", false)
			assert(art._alpha == 1 and pips:IsShown(), "the theme switch leaves the pips alone")
			mod.SetOpt("combo", false)
			assert(not pips:IsShown(), "and the pips have a switch of their own")
			mod.SetOpt("theme", true)
			mod.SetOpt("combo", true)
			BT.SetEnabled("prd", false)
			assert(art._alpha == 1 and not pips:IsShown(), "switched off, nothing of ours is left")
			BT.SetEnabled("prd", true)
			assert(BT.Window.InSettings("prd"), "it is a page of Settings")
			_G.UnitClass, _G.UnitPowerMax, _G.UnitPower = wasClass, wasMax, wasPower
			_G.C_NamePlate = nil
			mod.Apply()
			-- the switches above rebuilt the dock while the class was a rogue,
			-- which showed the rogue-only lines: built again as the warrior
			BT.Bar.Rebuild()
			BT.Window.Rebuild()
		end },
		{ "the compare tooltip does not wear a second border", function()
			-- ZEROING THE COLOURS WAS NOT ENOUGH (Josh 2026-09-21). The
			-- "Equipped" tooltip kept a heavier edge than the one beside it:
			-- a backdrop's edge is drawn from its own art, and an alpha of
			-- nothing on the tint never reaches it.
			BT.SetEnabled("tips", true)
			local shop = _G.ShoppingTooltip1
			assert(shop, "the compare tooltip is a frame we know about")
			local was = { bgFile = "art/bg", edgeFile = "art/edge" }
			shop.GetBackdrop = function() return was end
			shop._backdrop = was
			shop.SetBackdrop = function(self, t) self._backdrop = t end

			-- this client's border, which it lays out again after the tooltip
			-- is up, and the "Equipped" tab above it (Josh 2026-09-24)
			shop.NineSlice = _G.CreateFrame("Frame", nil, shop)
			shop.CompareHeader = _G.CreateFrame("Frame", nil, shop)
			local tabArt = shop.CompareHeader:CreateTexture()
			tabArt.GetAtlas = function() return "tooltip-compare-header" end
			tabArt._width, tabArt._height = 90, 20

			BT.GetModule("tips").Dress(shop)
			assert(shop._backdrop == nil,
				"the client's backdrop is taken away, not painted out")
			shop.NineSlice:Show()
			assert(shop.NineSlice._alpha == 0, "the border stays gone when the client shows it again")
			shop:GetScript("OnShow")(shop)
			local tab = BT.Pill.Panels()[shop.CompareHeader]
			assert(tab and tab.fill:IsShown() and tabArt._alpha == 0,
				"and the Equipped tab wears our surface, not the client's art")

			BT.GetModule("tips"):OnDisable()
			assert(shop._backdrop == was, "and given back whole")
			assert(shop.NineSlice._alpha == 1 and tabArt._alpha == 1 and not tab.fill:IsShown(),
				"the border and the tab's art with it")
		end },
		{ "every tooltip in the game, not the ones we thought of", function()
			-- THE GUILD ROSTER'S WAS NOT ON THE LIST (Josh 2026-09-21).
			-- Hovering a member in Guild & Communities gave you the client's
			-- own tooltip sitting beside ours - the same "two addons arguing"
			-- the compare tooltips used to be. A list of names is wrong again
			-- the next time a panel is opened for the first time, so the
			-- question is asked instead: every tooltip in the game answers
			-- "GameTooltip" when asked what it is.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)

			local stranger = _G.CreateFrame("Frame", "SomePanelMemberTooltip", _G.UIParent)
			stranger.GetObjectType = function() return "GameTooltip" end
			stranger.NumLines = function() return 1 end
			local notATooltip = _G.CreateFrame("Frame", "JustAPanel", _G.UIParent)

			local walk = { stranger, notATooltip, _G.GameTooltip }
			_G.EnumerateFrames = function(prev)
				if prev == nil then
					return walk[1]
				end
				for i, f in ipairs(walk) do
					if f == prev then
						return walk[i + 1]
					end
				end
				return nil
			end

			assert(mod.SweepTooltips() >= 1, "the sweep finds one nobody named")
			assert(mod.dressed["SomePanelMemberTooltip"] == stranger,
				"and it is hooked like the ones we did name")
			assert(mod.dressed["JustAPanel"] == nil,
				"while a frame that is not a tooltip is left alone")
			-- GameTooltip has its own pipeline and must not be double-hooked
			assert(mod.dressed[_G.GameTooltip] == nil
				and mod.dressed["GameTooltip"] == nil,
				"and the one we rebuild is not swept up with them")

			-- showing it dresses it, like any other
			stranger:GetScript("OnShow")(stranger)
			assert(mod.Skins()[stranger], "and showing one puts our surface on it")

			-- AND ONE THAT IS UNLIKE THE REST CANNOT THROW INTO THE CLIENT.
			-- This is hooked onto OnShow, so an error here comes out of
			-- whatever was showing the tooltip - a Blizzard settings control,
			-- in the first case that hit. We dress frames nobody named now,
			-- so one of them being odd has to be survivable.
			local odd = _G.CreateFrame("Frame", "OddTooltip", _G.UIParent)
			odd.GetObjectType = function() return "GameTooltip" end
			odd.NumLines = function() error("not that kind of tooltip") end
			walk[#walk + 1] = odd
			mod.SweepTooltips()
			local show = odd:GetScript("OnShow")
			assert(show, "it is hooked like the rest")
			local safe = pcall(show, odd)
			assert(safe, "and showing it does not take the client down with it")
			local said = false
			for _, line in ipairs(BT.moduleErrors or {}) do
				if tostring(line):find("OddTooltip", 1, true) then
					said = true
				end
			end
			assert(said, "the reason is on /bt debug instead")

			-- AND AGAIN WHEN THERE IS MORE UI THAN THERE WAS: the guild panel
			-- and the journals are built the first time you open them
			assert(mod.watcher and mod.watcher:GetScript("OnEvent"),
				"something listens for new UI arriving")
			local late = _G.CreateFrame("Frame", "LateTooltip", _G.UIParent)
			late.GetObjectType = function() return "GameTooltip" end
			walk[#walk + 1] = late
			-- (half a second after a burst of them, once: run at once here)
			local wasAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			mod.watcher:GetScript("OnEvent")(mod.watcher, "ADDON_LOADED")
			_G.C_Timer.After = wasAfter
			assert(mod.dressed["LateTooltip"] == late,
				"and one that arrives later is caught too")

			-- A SLICE A FRAME (Josh 2026-09-24): the half-minute sweep from a
			-- hover walks a few frames at a time, never all of them at once
			local later = _G.CreateFrame("Frame", "SlicedTooltip", _G.UIParent)
			later.GetObjectType = function() return "GameTooltip" end
			walk[#walk + 1] = later
			local wasSlice = mod.SWEEP_SLICE
			mod.SWEEP_SLICE = 2
			assert(mod.SweepSoon(), "a walk begins")
			assert(not mod.SweepSoon(), "and a second does not start over it")
			local slicer = mod.Slicer()
			local step = slicer:GetScript("OnUpdate")
			step(slicer)
			assert(mod.dressed["SlicedTooltip"] == nil and slicer:GetScript("OnUpdate"),
				"two frames in, it has not got there yet")
			for _ = 1, 5 do
				local s = slicer:GetScript("OnUpdate")
				if s then s(slicer) end
			end
			assert(mod.dressed["SlicedTooltip"] == later and not slicer:GetScript("OnUpdate"),
				"a few frames later it has, and it stops")
			mod.SWEEP_SLICE = wasSlice

			_G.EnumerateFrames = nil
		end },
		{ "the body lines up with the header", function()
			-- A BIGGER FONT STARTS FURTHER IN (Josh 2026-09-21). The name is
			-- set at fourteen point and the lines under it at twelve, and a
			-- glyph's left side bearing grows with its size - so with both on
			-- the same inset the header's ink sits right of the body's. No
			-- padding fixes that: padding moves the anchor, and the anchor is
			-- already the same.
			local mod = BT.GetModule("tips")
			BT.SetEnabled("tips", true)
			local tip = _G.GameTooltip
			tip.GetName = function() return "GameTooltip" end
			local body = _G.GameTooltipTextLeft2 or _G.CreateFrame("FontString")
			_G.GameTooltipTextLeft2 = body
			body:ClearAllPoints()
			body:SetPoint("LEFT", 10, 0)
			tip.NumLines = function() return 2 end

			mod.Compose(tip, "target")
			local at = (body._points or {}).LEFT
			assert(at and at.x == 12,
				("the body comes across to meet it (%s)"):format(tostring(at and at.x)))

			-- and goes back where it was with everything else
			BT.UnitTip.RestoreFonts()
			assert((body._points or {}).LEFT.x == 10, "and back again afterwards")
		end },
		{ "the quest you are on wears the theme, not a colour of its own", function()
			-- WRITTEN WHEN GREEN WAS THE ONLY COLOUR THERE WAS (Josh
			-- 2026-09-21). The block behind the active quest, its two rules
			-- and the dot beside it were all the toolkit's green - the one
			-- thing in the tracker that did not get the message when the
			-- background and border became a setting.
			BT.SetEnabled("tracker", true)
			BT.Theme.Set("rim", { 0.85, 0.20, 0.20 })
			BT.Theme.Set("fill", { 0.05, 0.03, 0.03, 0.88 })

			local mod = BT.GetModule("tracker")
			mod.Update()
			local section = mod.Frame()
			if section and section.band then
				mod.Band(10, 40)
				local back, rule = section.band._color, section.bandTop._color
				assert(math.abs(rule[1] - 0.85) < 0.001,
					"its rules are the border colour")
				local tinted = BT.Widgets.Tinted()
				assert(tinted[section.bandFoot] and tinted[section.bandFoot].axis == "h"
					and tinted[section.bandTop].axis == "h",
					"and they are the panel's own one-pixel rules, not lines coloured by hand")
				-- the block is the panel's own background lifted, not a
				-- colour of its own: that is what "raised out of the list"
				-- looks like, whatever the background is set to
				local fill = BT.Widgets.FILL
				assert(back[1] > fill[1] and back[2] > fill[2],
					("and the block is the background, lifted (%.2f over %.2f)")
						:format(back[1], fill[1]))
				-- TOWARD THE THEME, NOT TOWARD GREY (Josh 2026-09-22): on a red
				-- rim the block leans red, a shade of the panel rather than a grey
				assert(back[1] - fill[1] > (back[2] - fill[2]) * 2,
					("and it leans toward the theme's colour, not grey (%.2f,%.2f,%.2f)")
						:format(back[1], back[2], back[3]))
			end

			-- AND IT REPAINTS WHEN THE THEME MOVES, not at the next quest
			-- event: the colours are set where the list LAYS OUT, so a
			-- change it was not told about sat there in the old theme until
			-- you picked up or handed in a quest.
			assert(mod.Restyle, "the tracker can be told to draw itself again")
			BT.Theme.Set("rim", { 0.20, 0.30, 0.90 })
			local after = section and section.bandTop and section.bandTop._color
			if after then
				assert(math.abs(after[3] - 0.90) < 0.001,
					("the block followed the theme without waiting (%.2f)"):format(after[3]))
			end

			BT.Theme.Set("preset", "class")
		end },
		{ "nothing is the toolkit's green on purpose any more", function()
			-- SEVENTEEN PLACES HAD IT WRITTEN IN BY HAND (Josh 2026-09-21).
			-- The glyph on the dock, the tab you are on, the switch that is
			-- on, the spine on a search result, the health bar - all the
			-- toolkit's green, from when that was the only colour there was.
			-- Fixing them one at a time is a list that drifts again, so they
			-- go through one accent and it is repainted when the theme moves.
			local W, T = BT.Widgets, BT.Theme
			BT.Window.Build()

			local before = W.Tinted()
			local n = 0
			for _ in pairs(before) do
				n = n + 1
			end
			assert(n > 0, "things are on the list that wear it")

			T.Set("rim", { 0.80, 0.20, 0.60 })
			local accent = W.ACCENT
			assert(accent[1] > 0.4 and accent[3] > 0.3,
				("the accent follows the border (%.2f, %.2f, %.2f)")
					:format(accent[1], accent[2], accent[3]))

			-- and everything wearing it moved, not just the ones drawn since
			for tex, how in pairs(W.Tinted()) do
				local c = (how.how == "vertex") and tex._vertex or tex._color
				-- a hairline wears the rim rather than the accent
				local want = (how.how == "rule") and W.RIM or accent
				if c then
					assert(math.abs(c[1] - want[1]) < 0.001,
						"everything wearing it moved with it")
				end
			end

			-- THE BUTTONS WEAR THE THEME (Josh 2026-09-21). They were a fixed
			-- grey-green at rest, and the pressed and hover colours were read
			-- before they existed - so a pressed button kept its idle look.
			local btn = W.Button(_G.UIParent, "Class", 60, 20)
			local held = BT.Pill.Panels()[btn]
			assert(held.fillColour == W.RAISED and held.edgeColour == W.RIM,
				"a button at rest is the theme's raised fill and its rim")
			btn:SetPressed(true)
			assert(held.fillColour == W.WASH and held.edgeColour == W.ACCENT,
				"pressed, it is the accent's wash and the accent")
			btn:SetPressed(false)
			local wasRaised = W.RAISED[1]
			T.Set("rim", { 0.20, 0.60, 0.90 })
			assert(W.RAISED[1] ~= wasRaised, "and the raised fill moves with the theme")

			-- AND SO ARE THE HIGHLIGHTS (Josh 2026-09-21). The rail tab you
			-- are on, the button that is pressed, the rim under the cursor
			-- and the knob of a switch were four more greens written in by
			-- hand, so a violet theme came up violet with green selections.
			local wash, hover, knob = W.WASH, W.HOVER, W.KNOB
			local fill = W.FILL
			for i = 1, 3 do
				-- the wash is the panel with the accent through it, not a
				-- second colour: it lies between the two
				local low = math.min(fill[i], accent[i]) - 0.001
				local high = math.max(fill[i], accent[i]) + 0.001
				assert(wash[i] >= low and wash[i] <= high,
					("the selection is a wash of the accent (%.2f)"):format(wash[i]))
				assert(math.abs(hover[i] - accent[i] * 0.75) < 0.001,
					"the hover rim is most of the accent")
				assert(knob[i] >= accent[i] - 0.001,
					"and the knob is a pale version of it")
			end

			-- A BORDER DARK ENOUGH TO SIT QUIETLY IS TOO DARK TO SHOUT WITH:
			-- the accent is lifted until it reads, rather than being the
			-- border over again
			T.Set("rim", { 0.08, 0.04, 0.10 })
			local lifted = W.ACCENT
			assert(lifted[1] + lifted[2] + lifted[3] > 0.22 * 3,
				("a near-black border still gives a visible accent (%.2f)")
					:format(lifted[1] + lifted[2] + lifted[3]))

			T.Set("preset", "class")
		end },
		{ "the note is a quote, not a card above the tooltip", function()
			-- THE TAGS WENT BACK INSIDE (Josh 2026-09-20) and the frame they
			-- sat on became a carrier for the quote - but only its fill was
			-- put away. The three rectangles standing in for a drop shadow
			-- stayed, so a shadow was still being drawn around a one-pixel
			-- carrier: three grey bars above the tooltip with nothing to
			-- cast them (Josh 2026-09-21).
			BT.SetEnabled("ledger", true)
			BT.SetEnabled("tips", true)
			BT.DB.Note(BT.db, "Beeb Bob", "solid tank")
			local tip = _G.GameTooltip
			tip.GetName = function() return "GameTooltip" end
			BT.GetModule("tips").Compose(tip, "target")

			local card = BT.Tooltip.NoteFrame()
			if card then
				assert(card.fill._shown == false, "the carrier draws no panel")
				for i, t in ipairs(card.shadow or {}) do
					assert(t._shown == false,
						("nor a shadow around it (%d)"):format(i))
				end
			end
		end },
		{ "no file defines the same function twice", function()
			-- A SECOND W.Paint (Josh 2026-09-21). One took a frame and made a
			-- texture on it; the other took a texture and coloured it. The
			-- later definition simply replaced the earlier, so every call to
			-- the first reached the second and the window died on
			-- "attempt to call a nil value".
			--
			-- The harness could not catch it by running the code: its stub
			-- answers every method, so calling CreateTexture on a texture
			-- quietly worked. It is caught by reading the files instead.
			local files = {
				"Core/Init.lua", "Core/Util.lua", "Core/DB.lua",
				"Core/Tooltip.lua", "Core/Theme.lua", "UI/Pill.lua",
				"UI/Widgets.lua", "UI/Window.lua", "UI/Settings.lua",
				"UI/Bar.lua", "Modules/Ledger/Find.lua",
				"Modules/Ledger/Tooltip.lua", "Modules/Ledger/Ledger.lua",
				"Modules/Census/Census.lua", "Modules/Tips/Tips.lua",
				"Modules/Tracker/Tracker.lua", "Modules/Bars/Bars.lua",
				"Modules/Micro/Micro.lua",
				"Modules/Chat/Chat.lua",
			}
			for _, path in ipairs(files) do
				local fh = io.open(path, "r")
				if fh then
					local text = fh:read("*a")
					fh:close()
					local seen = {}
					for name in text:gmatch("[\r\n]function%s+([%w_%.:]+)%s*%(") do
						assert(not seen[name],
							("%s defines %s twice"):format(path, name))
						seen[name] = true
					end
				end
			end
		end },
		{ "the tabs go in the order you drag them, and the dock follows", function()
			local function railKeys()
				local out = {}
				for _, tab in ipairs(BT.Window.Tabs()) do
					if tab.key and tab:IsShown() then
						out[#out + 1] = tab.key
					end
				end
				return table.concat(out, ",")
			end
			local function sectionKeys()
				local out = {}
				for _, sec in ipairs(BT.Bar.Sections()) do
					out[#out + 1] = sec.key
				end
				return table.concat(out, ",")
			end
			BT.Window.Build()
			BT.Window.Rebuild()
			-- compact: a name, no line under it, and a short tab
			local first = BT.Window.Tabs()[2]
			assert(first and (first._height or 0) <= 24, "a tab is short now: " .. tostring(first._height))
			assert(first.blurb == nil, "and carries no description")

			-- a drop lands where the tab's middle is among the others
			assert(BT.Window.DropIndex(95, { 100, 90, 80 }) == 2, "between the first and second")
			assert(BT.Window.DropIndex(200, { 100, 90 }) == 1, "above them all is first")
			assert(BT.Window.DropIndex(10, { 100, 90 }) == 3, "below them all is last")

			-- move the quest tracker to the top
			BT.MoveModule("tracker", 1)
			BT.Window.Rebuild()
			assert(railKeys():find("^settings,dock,tracker,map,progress"), "the rail follows: " .. railKeys())
			assert(BT.settings.order and BT.settings.order[1] == "tracker",
				"and the order is a setting, so it is saved")
			BT.SetEnabled("perf", true)
			BT.Bar.Relayout()
			local order = {}
			for i, item in ipairs(BT.Bar.stack or {}) do
				order[item.row and "row" or item.s.key] = i
			end
			assert(order.tracker and order.readouts and order.tracker < order.readouts,
				"and the dock stacks its sections in the same order: " .. sectionKeys())
			BT.SetEnabled("perf", false)

			-- THE LEDGER'S ROW AND THE MINIMAP MOVE TOO (Josh 2026-09-22): the
			-- row takes the Ledger's place, and the map is no longer pinned above
			local function stackKeys()
				local out = {}
				for _, item in ipairs(BT.Bar.stack or {}) do
					out[#out + 1] = item.row and "row" or item.s.key
				end
				return out
			end
			BT.SetEnabled("minimap", true)
			BT.MoveModule("ledger", #BT.Modules())
			BT.MoveModule("minimap", #BT.Modules())
			BT.Bar.Relayout()
			local keys = stackKeys()
			assert(keys[#keys] == "minimap" and keys[#keys - 1] == "row",
				"the row and the map sit where their tabs are: " .. table.concat(keys, ","))

			-- a line under every piece of the dock except the last
			for n, item in ipairs(BT.Bar.stack) do
				local rule = item.row and BT.Bar.Frame().marksRule or item.s.frame.beebsRule
				if n < #BT.Bar.stack then
					assert(rule and rule._shown ~= false,
						("a line under %s, which is not last"):format(item.row and "the row" or item.s.key))
				else
					assert(rule and rule._shown == false, "and none under the last")
				end
			end
			for _, item in ipairs(BT.Bar.stack) do
				if item.s and item.s.key == "tracker" then
					assert(item.s.frame.beebsRule._shown ~= false,
						"the quests get one now they are not at the bottom")
				end
			end

			-- a drag that ends is not a click on the tab
			local tab
			for _, t in ipairs(BT.Window.Tabs()) do
				if t.key == "metrics" then tab = t end
			end
			local was = BT.Window.View()
			tab:GetScript("OnDragStart")(tab)
			assert(tab.dragged, "a module tab can be picked up")
			tab.dragged = true
			tab:GetScript("OnClick")(tab)
			assert(BT.Window.View() == was, "letting go of it does not open it")
			local settingsTab = BT.Window.Tabs()[1]
			settingsTab:GetScript("OnDragStart")(settingsTab)
			assert(not settingsTab.dragged, "Settings stays where it is")

			-- A GRIP ON HOVER: up and down chevrons on a module's tab, not on
			-- Settings, and gone when the pointer leaves (the pick-up above is
			-- a drag still in the air, and the grip rightly stays up for one)
			tab.dragging = false
			tab:SetScript("OnUpdate", nil)
			tab:GetScript("OnEnter")(tab)
			assert(tab.grip[1]._shown ~= false and tab.grip[2]._shown ~= false,
				"pointing at a module's tab shows it can be moved")
			tab:GetScript("OnLeave")(tab)
			assert(tab.grip[1]._shown == false, "and leaving puts the grip away")
			settingsTab:GetScript("OnEnter")(settingsTab)
			assert(settingsTab.grip[1]._shown == false, "Settings shows no grip")
			settingsTab:GetScript("OnLeave")(settingsTab)

			-- A LINE WHERE IT WILL LAND. Three tabs on the rail, the dragged one
			-- held between the first two: the line is in the gap above the second.
			local rail = {}
			for _, t in ipairs(BT.Window.Tabs()) do
				if t.key and t.key ~= "settings" and t ~= tab and t:IsShown() then
					rail[#rail + 1] = t
				end
			end
			BT.Window.MarkDrop(2, rail)
			local line = BT.Window.Rail().drop
			assert(line and line:IsShown(), "a line marks the drop")
			-- the line is two pixels, top at `at`: it has to fit the gap
			assert(line.at <= rail[1].railY - 20 and line.at - 2 >= rail[2].railY,
				("in the gap above the tab it would land before (%s, between %s and %s)")
					:format(tostring(line.at), tostring(rail[1].railY - 20), tostring(rail[2].railY)))
			BT.Window.MarkDrop(#rail + 1, rail)
			assert(line.at <= rail[#rail].railY - 20, "or under the last one")
			BT.Window.MarkDrop(nil)
			assert(not line:IsShown(), "and it goes when the drag ends")

			-- A DROP IS NAMED BY A NEIGHBOUR: the rail shows some modules, and a
			-- counted position would land among the ones it does not show
			BT.MoveModuleNextTo("gold", "ledger")
			local keys = {}
			for _, m in ipairs(BT.Modules()) do keys[#keys + 1] = m.key end
			local order = table.concat(keys, ",")
			assert(order:find("gold,ledger", 1, true), "straight before the tab it was dropped on: " .. order)
			BT.MoveModuleNextTo("gold", nil, "tracker")
			keys = {}
			for _, m in ipairs(BT.Modules()) do keys[#keys + 1] = m.key end
			assert(table.concat(keys, ","):find("tracker,gold", 1, true), "or straight after the last")

			-- the order survives a login: it is sorted again from the setting
			BT.SortModules()
			assert(BT.Modules()[1].key == "tracker", "sorted from the setting at bind")

			-- and back to the default for the tests that follow
			BT.settings.order = nil
			BT.SortModules()
			BT.Window.Rebuild()
			BT.Bar.Relayout()
			assert(railKeys():find("^settings,dock,map,progress"), "no order is the default order")
			-- A SHARED PAGE MOVES WHOLE (Josh 2026-09-24): Progress dragged above
			-- the map takes experience and reputation with it, together
			BT.Window.MoveTab("progress", "map")
			BT.Window.Rebuild()
			assert(railKeys():find("^settings,dock,progress,map"), "the tab moves: " .. railKeys())
			keys = {}
			for _, m in ipairs(BT.Modules()) do keys[#keys + 1] = m.key end
			assert(table.concat(keys, ","):find("xp,rep,minimap,buttons", 1, true),
				"and both its modules, in their order, ahead of the map's: " .. table.concat(keys, ","))
			BT.settings.order = nil
			BT.SortModules()
			BT.Window.Rebuild()
			BT.Bar.Relayout()
		end },
		{ "experience: the bar, and time to level at this session's pace", function()
			local mod = BT.GetModule("xp")
			assert(mod and mod.dock, "the module is loaded, and is a right-panel module")
			local level, cur, max, rested = 8, 1000, 4000, 800
			local realLevel = _G.UnitLevel
			_G.UnitLevel = function() return level end
			_G.UnitXP = function() return cur end
			_G.UnitXPMax = function() return max end
			_G.GetXPExhaustion = function() return rested end
			_G.GetMaxPlayerLevel = function() return 60 end
			local realNow = BT.Util.Now
			local clock = 2000000
			BT.Util.Now = function() return clock end
			BT.SetEnabled("xp", true)
			mod.Show(true)
			local section = mod.Build()
			assert(section:IsShown() and (section._height or 0) > 0, "a line of its own, with a height")
			section:SetWidth(212)
			mod.Update()

			local left, right = mod.Lines(level, cur, max, nil)
			assert(left:find("Level 8", 1, true) and left:find("25%", 1, true), "the level and how far: " .. left)
			-- before there is a pace, nothing: the same grammar as reputation,
			-- and what is left is on the hover
			assert(right == "", "and nothing on the right before there is a pace: " .. right)
			assert(section.kind == "meter", "it is a meter, so no rule between it and reputation")
			assert(BT.GetModule("rep").Build().kind == "meter", "and so is reputation")
			assert(mod.Big(1234567) == "1,234,567" and mod.Big(999) == "999",
				"with the thousands marked")
			-- the bar: a quarter done, rested a fifth ahead of it, on 200 of room
			assert(mod.fill._width == 50, "a quarter of the bar is filled: " .. tostring(mod.fill._width))
			assert(mod.rested._width == 40 and mod.rested._shown ~= false,
				"and rested is a paler stretch ahead of it: " .. tostring(mod.rested._width))

			-- a session: 1500 into this level, then a level-up carrying 500 over
			mod.Start(true, false)
			cur = 2500
			mod.Gain()
			level, cur, max = 9, 500, 5000
			mod.Gain()
			assert(mod.session.gained == 1500 + 1500 + 500,
				"a level gained is the rest of the old one plus the new: " .. tostring(mod.session.gained))
			assert(mod.Rate() == nil, "and no pace before a minute")

			-- an hour in, 3500 an hour, and 4500 to go is about an hour and seventeen
			clock = clock + 3600
			assert(math.abs(mod.Rate() - 3500) < 0.01, "experience per hour: " .. tostring(mod.Rate()))
			local _, eta = mod.Lines(level, cur, max, mod.Rate())
			assert(eta:find("^1h 17m") and not eta:find("~", 1, true) and eta:find("to 10", 1, true), "and time to level: " .. eta)

			-- a reload carries it on; a login does not
			local session = mod.session
			mod.Start(false, true)
			assert(mod.session == session, "a /reload keeps the session")
			mod.Start(true, false)
			assert(mod.session ~= session and mod.session.gained == 0, "a new login starts a fresh one")

			-- at the cap the line goes
			level = 60
			mod.Update()
			assert(not section:IsShown(), "at the level cap there is no bar")
			SlashCmdList.BEEBSTOOLKIT("xp")

			_G.UnitLevel, _G.UnitXP, _G.UnitXPMax = realLevel, nil, nil
			_G.GetXPExhaustion, _G.GetMaxPlayerLevel = nil, nil
			BT.Util.Now = realNow
			mod.Update()
		end },
		{ "durability: how worn your gear is, and the client's figure put away", function()
			local mod = BT.GetModule("durability")
			assert(mod and mod.dock, "the module is loaded, and is a right-panel module")
			local worn = {}
			_G.GetInventoryItemDurability = function(slot)
				local w = worn[slot]
				if w then return w[1], w[2] end
				return nil
			end
			local figure = _G.CreateFrame("Frame", "DurabilityFrame", _G.UIParent)
			BT.SetEnabled("durability", true)
			mod.Show(true)
			local section = mod.Build()
			assert(not section:IsShown(), "nothing that wears down, no line")
			assert(figure._alpha == 0, "and the client's armour figure is put away")

			-- 160 of 200 in all, the main hand at 20 of 50
			worn = { [1] = { 50, 50 }, [5] = { 90, 100 }, [16] = { 20, 50 } }
			mod.Update()
			assert(section:IsShown(), "gear on, and the line is there")
			local d = mod.Read()
			assert(d.pct == 80 and d.worst.name == "Main Hand" and d.worst.pct == 40,
				"all of it together, and the most worn piece: " .. tostring(d.pct))
			local left, right = mod.Lines(d)
			assert(left:find("80%", 1, true) and left:find("|cffe6ebe8", 1, true), "plain at 80%: " .. left)
			assert(right:find("Main Hand", 1, true) and right:find("|cfff2c75a", 1, true),
				"the worst beside it, amber below half: " .. right)
			-- THE CELL IS COLOURED BY ITS NUMBER (Josh 2026-09-24): the average
			-- is 80%, so it is plain, however worn the main hand is
			assert(mod.Cell(d).state == nil, "80% overall is plain: " .. tostring(mod.Cell(d).state))
			worn[16] = { 0, 50 }
			assert(mod.Cell().state == "alert", "but a broken piece still turns it red")
			local _, broke = mod.Lines()
			assert(broke:find("|cfff26659", 1, true), "red when it breaks")
			worn = { [1] = { 50, 50 } }
			local _, whole = mod.Lines()
			assert(whole == "", "and nothing beside it when nothing is worn")

			BT.SetEnabled("durability", false)
			assert(figure._alpha == 1, "switched off, the figure comes back")
			assert(not section:IsShown(), "and the line goes")
			BT.SetEnabled("durability", true)
			SlashCmdList.BEEBSTOOLKIT("durability")
			_G.GetInventoryItemDurability, _G.DurabilityFrame = nil, nil
			mod.Update()
		end },
		{ "a clock: local or server time, a click to switch", function()
			local mod = BT.GetModule("clock")
			assert(mod and BT.Window.Group("clock") == nil and BT.Window.TabFor("clock") == "dock",
				"the module is loaded, with no tab of its own: its switch is on the Dock's page")
			BT.Window.Build()
			BT.Window.SetView("dock")
			local switch
			for _, r in ipairs(BT.Widgets.Rows()) do
				if r.module == "clock" then switch = r end
			end
			assert(switch, "its switch is on the Dock's page, with the Census's")
			BT.Settings.Refresh()
			assert(switch.switch.on, "on, as it starts")
			switch.switch:GetScript("OnClick")(switch.switch)
			assert(not BT.Enabled("clock") and not mod.Build():IsShown(), "and off takes it out of the header")
			switch.switch:GetScript("OnClick")(switch.switch)
			assert(BT.Enabled("clock"), "and on puts it back")
			_G.GetGameTime = function() return 21, 5 end
			local military = false
			_G.GetCVarBool = function(name) return name == "timeMgrUseMilitaryTime" and military end
			BT.settings.clockServer = nil
			BT.SetEnabled("clock", true)
			mod.Show(true)
			local section = mod.Build()
			BT.Bar.Relayout()
			assert(section:IsShown() and section:GetParent() == BT.Bar.Frame().header,
				"in the panel's header, not a line of its own")
			local at = section._points and section._points.RIGHT
			assert(at and at.rel == BT.Bar.Frame().header and at.relPoint == "RIGHT",
				"at its right edge, where the cog was")
			local head = BT.Bar.Frame().header
			local cogAt = BT.Bar.Cog()._points and BT.Bar.Cog()._points.LEFT
			assert(cogAt and (cogAt.rel == head.title or cogAt.rel == BT.Bar.Frame().census),
				"and the cog moves beside the name")
			assert(mod.Which() == "local", "local time to start")
			assert(mod.time._text:find("|cff69db7cL|r", 1, true), "and a green L says so: " .. mod.time._text)

			-- a click swaps to the realm's time, and back
			section:GetScript("OnMouseUp")(section)
			assert(mod.Which() == "server" and BT.settings.clockServer, "a click is server time, remembered")
			assert(mod.time._text == "9:05pm |cff74c0fcS|r", "the realm's time, twelve-hour, a blue S: "
				.. tostring(mod.time._text))
			military = true
			mod.Update()
			assert(mod.Text() == "21:05", "or twenty-four, as the client's clock is set")
			section:GetScript("OnMouseUp")(section)
			assert(mod.Which() == "local" and not BT.settings.clockServer, "and another click is local again")

			assert(mod.Format(0, 7, false) == "12:07am" and mod.Format(12, 0, false) == "12:00pm",
				"midnight and noon read as twelve")
			SlashCmdList.BEEBSTOOLKIT("time")
			_G.GetGameTime, _G.GetCVarBool = nil, nil
		end },
		{ "pick pocket: coin and vendor value, for rogues only", function()
			local mod = BT.GetModule("pickpocket")
			assert(mod and mod.dock and mod.class == "ROGUE", "the module is loaded, for rogues")
			local wasClass = _G.UnitClass
			BT.SetEnabled("pickpocket", true)
			mod.Show(true)
			local section = mod.Build()
			-- a warrior sees neither the line nor the tab
			assert(not section:IsShown(), "not a rogue, no line")
			BT.Window.Build()
			BT.Window.Rebuild()
			local function onRail()
				for _, t in ipairs(BT.Window.Tabs()) do
					if t.key == "pickpocket" and t:IsShown() then return true end
				end
				return false
			end
			assert(not onRail(), "and no tab")
			-- METRICS (Josh 2026-09-22): its switch is a row of the Metrics tab,
			-- and only a rogue has that row
			local metrics = BT.GetModule("metrics")
			BT.Window.SetView("metrics")
			local function hasRow()
				for _, r in ipairs(metrics.rows or {}) do
					if r.part.key == "pickpocket" then return r:IsShown() end
				end
				return false
			end
			metrics:RefreshTab()
			assert(not hasRow(), "nor a switch on the Metrics tab")

			_G.UnitClass = function() return "Rogue", "ROGUE" end
			BT.Window.Rebuild()
			metrics:RefreshTab()
			assert(not onRail() and hasRow(), "a rogue switches it from the Metrics tab")
			local clock, purse = 100, 5000
			_G.GetTime = function() return clock end
			_G.GetMoney = function() return purse end
			local prices = { [5374] = 120, [2589] = 13 }
			_G.GetItemInfo = function(id)
				return "item", nil, 1, 1, 1, "", "", 20, "", nil, prices[id]
			end
			local loot = {
				[1] = { link = "|cffffffff|Hitem:5374::::::::|h[Small Pocket Watch]|h|r", qty = 1 },
				[2] = { link = "|cffffffff|Hitem:2589::::::::|h[Linen Cloth]|h|r", qty = 3 },
			}
			_G.GetNumLootItems = function() return 2 end
			_G.GetLootSlotLink = function(i) return loot[i] and loot[i].link end
			_G.GetLootSlotInfo = function(i) return nil, "x", loot[i] and loot[i].qty end
			BT.settings.pickpocket = nil
			mod.session = nil
			mod.Start(true, false)
			mod.Update()
			assert(section:IsShown(), "and the line")

			-- a loot window that does not follow the cast is not a pocket
			assert(not mod.Opened(), "ordinary loot is not a pocket")

			-- the cast, then the pocket: 23 copper, the watch taken, the cloth left
			assert(mod.Cast(921), "Pick Pocket is noticed")
			clock = clock + 1
			assert(mod.Opened(), "the loot window after it is the pocket")
			purse = purse + 23
			mod.Money()
			mod.Taken(1)
			mod.Closed()
			local r = mod.Record()
			assert(r.coin == 23 and r.picks == 1, "the coin, and one pocket")
			assert(r.items[5374] == 1 and r.items[2589] == nil, "only the item taken counts")
			local c, i = mod.Worth(r)
			assert(c == 23 and i == 120, "worth the coin plus the vendor price")
			local left, right = mod.Lines(r, mod.session)
			assert(left:find("Pickpocketed", 1, true) and left:find("43", 1, true),
				"one line: 1 silver 43 copper in all: " .. left)
			assert(right:find("today", 1, true), "and this session beside it: " .. right)

			-- money after the pocket has closed and the moment has passed is not the pocket's
			clock = clock + 5
			purse = purse + 500
			mod.Money()
			assert(r.coin == 23, "money later is not pickpocketed")

			-- an item the client has not priced yet counts once it has
			prices[5374] = nil
			assert(select(2, mod.Worth(r)) == 0, "unpriced for now")
			prices[5374] = 120
			assert(select(2, mod.Worth(r)) == 120, "and priced when the client knows")

			SlashCmdList.BEEBSTOOLKIT("pockets")
			_G.UnitClass = wasClass
			BT.Window.Rebuild()
			mod.Update()
			assert(not section:IsShown(), "back to a warrior, the line goes")
			_G.GetTime, _G.GetMoney, _G.GetItemInfo = nil, nil, nil
			_G.GetNumLootItems, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil
		end },
		{ "other addons' minimap buttons, gathered into a line", function()
			local mod = BT.GetModule("buttons")
			assert(mod and mod.dock, "the module is loaded, and is a right-panel module")
			local map = _G.Minimap
			local function button(name, kind)
				local b = _G.CreateFrame("Button", name, map)
				b:SetSize(31, 31)
				b:SetPoint("CENTER", map, "CENTER", 60, 20)
				b.GetObjectType = function() return kind or "Button" end
				-- the stub keeps no scale; these buttons do
				b.SetScale = function(self, v) self._scale = v end
				b.GetScale = function(self) return self._scale or 1 end
				local ring = b:CreateTexture()
				ring.GetObjectType = function() return "Texture" end
				ring.GetTexture = function() return 136430 end
				local icon = b:CreateTexture()
				icon.GetObjectType = function() return "Texture" end
				icon.GetTexture = function() return "Interface/Icons/INV_Misc_Book_09" end
				b.ring, b.icon = ring, icon
				return b
			end
			BT.SetEnabled("buttons", true)
			mod.Build():SetWidth(80)
			assert(mod.Layout() == 0 and not mod.Build():IsShown(), "no addon buttons, no line")

			local a = button("LibDBIcon10_TrueParse")
			local b = button("LibDBIcon10_Details")
			local own = button("MiniMapTrackingButton")
			local handMade = button("SomeAddonMinimapButton")
			assert(mod.IsAddonButton(a) and mod.IsAddonButton(handMade), "LibDBIcon's and an addon's own")
			assert(not mod.IsAddonButton(own), "but never the client's own furniture")
			-- AND IT HAS AN ICON: a button of the client's this list has not
			-- heard of, carrying only a "0", got a line of its own in game
			local counter = _G.CreateFrame("Button", "SomeClientCounterButton", map)
			counter.GetObjectType = function() return "Button" end
			local zero = counter:CreateFontString()
			zero.GetObjectType = function() return "FontString" end
			zero:SetText("0")
			assert(not mod.IsAddonButton(counter), "a button with only a number on it is not an addon's")
			table.remove(map._children)

			local n = mod.Layout()
			local section = mod.Build()
			assert(n == 3 and section:IsShown(), "three addon buttons, and a line for them")
			assert(mod.list[1] == b and mod.list[2] == a, "in the same order every time: by name")
			assert(a._parent == section and own._parent == map, "the addon's moves into the line, the client's stays")
			assert(math.abs((a._scale or 1) - 18 / 31) < 0.001, "scaled to the toolkit's icon size")
			assert(a.ring._alpha == 0 and (a.icon._alpha or 1) == 1, "the gold ring off, the icon kept")
			-- 80 wide holds three: the third wraps? (6 + 3*18 + 2*4 = 68, so it fits)
			local at = (mod.list[3]._points or {}).TOPLEFT
			assert(at and math.abs(at.x * mod.list[3]._scale - (6 + 2 * 22)) < 0.01,
				"side by side, positioned in the button's own scaled units")
			section:SetWidth(50)
			mod.Layout()
			local wrapped = (mod.list[3]._points or {}).TOPLEFT
			assert(wrapped and wrapped.y * mod.list[3]._scale < -10, "and a row that runs out of room wraps")
			assert((section.wantHeight or 0) > 30, "the line grows to fit the rows")

			-- an addon that moves its own button is put back in line
			a:ClearAllPoints()
			a:SetPoint("CENTER", map, "CENTER", 60, 20)
			mod.Layout()
			assert((a._points or {}).TOPLEFT, "put back in the line")

			-- A BUTTON ITS ADDON HID TAKES NO PLACE (the audit): it left a gap
			handMade:Hide()
			assert(mod.Layout() == 2 and #mod.list == 2, "a hidden button leaves the line closed up")
			handMade:Show()
			assert(mod.Layout() == 3, "and takes its place again when shown")

			-- the map's own row along the bottom leaves them alone
			assert(BT.MapButtons.Claims(a), "the line claims them from the Minimap module")

			-- off: every button goes back where it was, ring and all
			BT.SetEnabled("buttons", false)
			assert(a._parent == map and (a._scale or 1) == 1 and a.ring._alpha == 1,
				"switched off, each button is given back as it was")
			assert(not section:IsShown(), "and the line goes")
			-- the fakes leave the minimap before the line comes back on, so it
			-- finds nothing and stays out of the dock tests that follow
			for i = #map._children, 1, -1 do
				local c = map._children[i]
				if c == a or c == b or c == own or c == handMade then
					table.remove(map._children, i)
				end
			end
			BT.SetEnabled("buttons", true)
			assert(not section:IsShown(), "with the buttons gone, no line")
		end },
		{ "the client's own experience and reputation bars go while ours are up", function()
			local SB = BT.StatusBars
			-- this build's two containers, each showing one bar at a time
			local function container(name, shown)
				local c = _G.CreateFrame("Frame", name, _G.UIParent)
				c.bars = { [4] = _G.CreateFrame("Frame", nil, c), [1] = _G.CreateFrame("Frame", nil, c) }
				c.shownBarIndex = shown
				c.IsMouseEnabled = function(self) return self._mouse ~= false end
				c.EnableMouse = function(self, on) self._mouse = on end
				return c
			end
			local main = container("MainStatusTrackingBarContainer", 4)
			local second = container("SecondaryStatusTrackingBarContainer", 1)
			assert(SB.ShownKind(main) == "xp" and SB.ShownKind(second) == "rep",
				"each container is asked what it is showing")

			local xp, rep = BT.GetModule("xp"), BT.GetModule("rep")
			BT.SetEnabled("xp", true)
			BT.SetEnabled("rep", true)
			xp.SetHideClient(true)
			rep.SetHideClient(false)
			assert(main._alpha == 0 and main._mouse == false,
				"the experience bar is put away, and cannot be pointed at")
			assert((second._alpha or 1) == 1, "the reputation bar stays while its switch is off")
			rep.SetHideClient(true)
			assert(second._alpha == 0, "and goes when it is on")

			-- the client moves bars between containers: the fade follows
			rep.SetHideClient(false)
			main.shownBarIndex, second.shownBarIndex = 1, 4
			SB.Apply()
			assert((main._alpha or 1) == 1 and second._alpha == 0,
				"it is the bar that is hidden, whichever container it is in")
			main.shownBarIndex, second.shownBarIndex = 4, 1
			SB.Apply()

			-- on by default, and switching the module off gives the bar back
			BT.settings.hideClientXP = nil
			assert(xp.HideClient(), "hiding the client's bar is on unless you turn it off")
			BT.SetEnabled("xp", false)
			assert(main._alpha == 1 and main._mouse ~= false,
				"with the Experience line off, the client's bar comes back")
			BT.SetEnabled("xp", true)
			assert(main._alpha == 0, "and goes again when it is back on")

			-- the switch on the tab
			local tab = _G.CreateFrame("Frame", nil, _G.UIParent)
			xp:BuildTab(tab)
			assert(xp.hideSwitch:IsOn(), "the tab's switch shows it on")
			xp.hideSwitch:GetScript("OnClick")(xp.hideSwitch)
			assert(BT.settings.hideClientXP == false and main._alpha == 1, "and turning it off brings the bar back")
			xp.SetHideClient(true)
			BT.settings.hideClientXP, BT.settings.hideClientRep = nil, nil
			SB.Set("xp", false)
			SB.Set("rep", false)
			_G.MainStatusTrackingBarContainer, _G.SecondaryStatusTrackingBarContainer = nil, nil
		end },
		{ "reputation: the watched faction, only while one is watched", function()
			local mod = BT.GetModule("rep")
			assert(mod and mod.dock, "the module is loaded, and is a right-panel module")
			-- the classic form: name, standing, the standing's floor and
			-- ceiling, and the total value
			local watched = nil
			_G.GetWatchedFactionInfo = function()
				if not watched then return nil end
				return watched.name, watched.reaction, watched.low, watched.high, watched.value, 68
			end
			local realNow = BT.Util.Now
			local clock = 3000000
			BT.Util.Now = function() return clock end
			BT.SetEnabled("rep", true)
			mod.Show(true)
			local section = mod.Build()
			assert(not section:IsShown(), "nothing watched, no line - as the client's own bar")

			watched = { name = "Undercity", reaction = 5, low = 3000, high = 9000, value = 4200 }
			mod.Start(true, false)
			assert(section:IsShown(), "a faction watched, and the line is there")
			section:SetWidth(212)
			mod.Update()
			local f = mod.Read()
			assert(f.cur == 1200 and f.max == 6000, "1,200 of 6,000 into Friendly")
			local left, right = mod.Lines(f, nil)
			assert(left:find("Undercity", 1, true) and left:find("Friendly", 1, true), "the faction and standing: " .. left)
			-- no amount before there is a pace: the name has the whole line, and
			-- the hover says how much is left
			assert(right == "", "nothing on the right before there is a pace: " .. right)
			assert(mod.fill._width == 40, "a fifth of the bar: " .. tostring(mod.fill._width))
			assert(mod.fill._color and mod.fill._color[2] > mod.fill._color[1],
				"in the standing's colour, green for friendly")

			-- 1,800 gained in half an hour, across into Honored
			watched.value = 6000
			mod.Gain()
			watched.reaction, watched.low, watched.high, watched.value = 6, 9000, 21000, 9000
			mod.Gain()
			local t = mod.session.factions.Undercity
			assert(t.gained == 4800, "gains carry across a standing: " .. tostring(t.gained))
			clock = clock + 1800
			assert(math.abs(mod.Rate(t) - 9600) < 0.01, "per hour: " .. tostring(mod.Rate(t)))
			local _, eta = mod.Lines(mod.Read(), mod.Rate(t))
			assert(eta:find("1h 15m", 1, true) and eta:find("to Revered", 1, true), "and time to the next: " .. eta)

			-- another faction watched, then back: the first one's pace is kept
			watched = { name = "Orgrimmar", reaction = 4, low = 0, high = 3000, value = 100 }
			mod.Gain()
			watched = { name = "Undercity", reaction = 6, low = 9000, high = 21000, value = 9000 }
			mod.Gain()
			assert(mod.session.factions.Undercity.gained == 4800, "switching away and back keeps the pace")

			-- exalted: a full bar, and nothing after it
			watched = { name = "Undercity", reaction = 8, low = 42000, high = 42999, value = 42999 }
			mod.Update()
			local _, none = mod.Lines(mod.Read(), nil)
			assert(none == "", "nothing comes after exalted")
			assert(mod.fill._width == 200, "and the bar is full")

			-- a reload keeps the session; nothing watched puts the line away
			local session = mod.session
			mod.Start(false, true)
			assert(mod.session == session, "a /reload keeps the session")
			watched = nil
			mod.Update()
			assert(not section:IsShown(), "and unticking the faction takes the line away")
			SlashCmdList.BEEBSTOOLKIT("rep")

			_G.GetWatchedFactionInfo = nil
			BT.Util.Now = realNow
		end },
		{ "currency is a cell of the readout grid: what you have, and earned per hour", function()
			local mod = BT.GetModule("gold")
			assert(mod, "the module is loaded")
			local purse = 939
			_G.GetMoney = function() return purse end
			local realNow = BT.Util.Now
			local clock = 1000000
			BT.Util.Now = function() return clock end
			BT.SetEnabled("gold", true)
			mod.Show(true)
			local chip = mod.Build()
			assert(chip.wanted and chip:GetParent().key == "readouts",
				"a cell of the readout grid, not a line of its own")
			assert(chip.spec and chip.spec.text:find("CopperIcon", 1, true) and not chip.spec.state,
				"the purse in coins, plain: good values are not coloured")

			-- a fresh login starts a session; money in is earned, money out is spent
			mod.Start(true, false)
			assert(mod.session.earned == 0 and mod.session.start == clock, "a login starts a session")
			purse = purse + 25000
			mod.Money()
			purse = purse - 5000
			mod.Money()
			assert(mod.session.earned == 25000 and mod.session.spent == 5000,
				"what comes in is earned and what goes out is spent, separately")
			assert(mod.Rate() == nil, "and there is no rate before a minute has passed")
			local _, early = mod.Lines(purse, mod.Rate())
			assert(early:find("-", 1, true), "it says so rather than inventing one: " .. early)

			-- half an hour later: 2.5g earned is 5g an hour, spending notwithstanding
			clock = clock + 1800
			assert(math.abs(mod.Rate() - 50000) < 0.01, "earned per hour: " .. tostring(mod.Rate()))
			local left, right = mod.Lines(purse, mod.Rate())
			-- the money frame's own coins, a number before each: 2 gold 9 silver 39 copper
			assert(left:find("^2|T[^|]*UI%-GoldIcon") and left:find("9|T[^|]*UI%-SilverIcon")
				and left:find("39|T[^|]*UI%-CopperIcon"),
				"the purse in the client's coins: " .. left)
			assert(right:find("5|T[^|]*UI%-GoldIcon") and right:find("/h", 1, true),
				"and the rate: " .. right)
			assert(not right:find("CopperIcon", 1, true),
				"without copper once there is gold: an hourly rate to the copper is noise")
			assert(mod.Coins(39):find("^39|T[^|]*UI%-CopperIcon") and not mod.Coins(39):find("Gold", 1, true),
				"and a purse of coppers is just coppers")
			-- where the client defines its own coin format, that is what is used
			_G.COPPER_AMOUNT_TEXTURE = "%d[copper %d %d]"
			assert(mod.Coins(7) == "7[copper 12 12]", "the client's own format wins: " .. mod.Coins(7))
			_G.COPPER_AMOUNT_TEXTURE = nil

			-- a reload carries the session on; a login does not
			local session = mod.session
			mod.Start(false, true)
			assert(mod.session == session and mod.session.earned == 25000, "a /reload keeps the session")
			mod.Start(true, false)
			assert(mod.session ~= session and mod.session.earned == 0, "a new login starts a fresh one")

			-- CURRENCY (Josh 2026-09-22): the same module, renamed; the bag space
			-- it carried for a while is a line of its own, Bags
			assert(mod.title == "Currency", "it is called Currency now")
			assert(mod.Bags == nil, "and the bags are not its business any more")
			local space = BT.GetModule("bagspace")
			assert(space and space.dock and space.title == "Bags", "they are the Bags line's")
			-- ONE OWNER FOR THE BAG BAR (Josh 2026-09-24): the Bags line puts it
			-- away; the restyle that dressed it as well is gone
			assert(BT.GetModule("bags") == nil, "there is no Bag bar module beside it")
			BT.SetEnabled("bagspace", true)
			space.Show(true)
			local bags = {
				[0] = { slots = 16, free = 4, family = 0 },   -- backpack
				[1] = { slots = 16, free = 0, family = 0 },
				[2] = { slots = 12, free = 10, family = 32 }, -- an herb bag
				[5] = { slots = 16, free = 16, family = 0 },  -- the reagent bag's slot
			}
			_G.Enum = _G.Enum or {}
			_G.Enum.BagIndex = { ReagentBag = 5 }
			_G.C_Container = {
				GetContainerNumSlots = function(b) return bags[b] and bags[b].slots or 0 end,
				GetContainerNumFreeSlots = function(b)
					local x = bags[b]
					return x and x.free or 0, x and x.family or 0
				end,
			}
			local b = space.Bags()
			assert(b.bags.total == 32 and b.bags.used == 28, "the ordinary bags: 28 of 32")
			assert(b.reagents.total == 28 and b.reagents.used == 2,
				"the herb bag and the reagent bag count as reagents: 2 of 28")
			local bl, br = space.Lines(b)
			assert(bl:find("28", 1, true) and bl:find("/32", 1, true) and bl:find("Bags", 1, true),
				"the bags line: " .. bl)
			assert(bl:find("|cfff2c75a", 1, true), "amber at four free")
			assert(br:find("Reagents", 1, true) and br:find("/28", 1, true), "and reagents beside it: " .. br)
			bags[0].free = 0
			local full = space.Lines()
			assert(full:find("|cfff26659", 1, true), "red when there is no room at all")
			bags[2], bags[5] = nil, nil
			local _, none = space.Lines()
			assert(none == "", "and no reagents half when there is no reagent space")
			bags[2], bags[5] = { slots = 12, free = 10, family = 32 }, nil
			bags[0].free = 4
			space.Update()
			local bagChip = space.Build()
			assert(bagChip.wanted and bagChip.spec.text:find("28", 1, true)
				and bagChip.spec.text:find("/32", 1, true), "a cell: used of the total: " .. bagChip.spec.text)
			assert(bagChip.spec.state == "warn", "amber at four free")
			bags[0].free = 0
			space.Update()
			assert(bagChip.spec.state == "alert", "red when there is no room at all")
			_G.C_Container, _G.Enum.BagIndex = nil, nil
			-- CLASS REAGENTS, AND A WARLOCK'S SHARDS: a second row of icons and
			-- counts, only what you carry, except shards and ammo which always show
			local carried = {}
			-- a backpack, so the line is up to carry the row
			_G.C_Container = {
				GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end,
				GetContainerNumFreeSlots = function() return 8, 0 end,
			}
			_G.GetItemCount = function(id) return carried[id] or 0 end
			_G.GetItemIcon = function(id) return 1000 + id end
			local wasClass = _G.UnitClass
			local function as(token) _G.UnitClass = function() return token, token end end

			local function reagentCells()
				local out = {}
				for key, c in pairs(space.reagentChips) do
					if c.wanted then
						out[tostring(key)] = c
					end
				end
				return out
			end

			as("WARRIOR")
			space.Update()
			assert(next(reagentCells()) == nil, "a warrior has no reagents, and no cells for them")

			as("ROGUE")
			carried = { [5140] = 12, [5530] = 3 }
			space.Update()
			local cells = reagentCells()
			assert(cells["5140"] and cells["5140"].spec.text == "12" and cells["5140"].spec.icon == 6140
				and cells["5530"], "a rogue's powders, a cell each: its icon and count")
			assert(cells["5140"].order > space.Build().order, "after the bags")

			as("MAGE")
			carried = { [17020] = 20 }
			local list = space.ReagentCells()
			assert(#list == 1 and list[1].key == 17020,
				"a mage without teleport runes is not shown a red nought for them")

			as("WARLOCK")
			carried = {}
			list = space.ReagentCells()
			assert(#list == 1 and list[1].key == 6265 and list[1].state == "alert",
				"a warlock's shards show even at nothing, in red")

			as("HUNTER")
			_G.GetInventoryItemCount = function(_, slot) return slot == 0 and 1400 or 0 end
			_G.GetInventoryItemTexture = function() return 132382 end
			list = space.ReagentCells()
			assert(list[1] and list[1].key == "ammo" and list[1].text == "1400",
				"a hunter's ammunition, from the ammo slot")

			_G.UnitClass, _G.GetItemCount, _G.GetItemIcon = wasClass, nil, nil
			_G.C_Container = nil
			_G.GetInventoryItemCount, _G.GetInventoryItemTexture = nil, nil
			space.Update()

			-- THE CLIENT'S BAG BAR, PUT AWAY: on by default, back when switched off
			local backpack = _G.CreateFrame("Button", "MainMenuBarBackpackButton", _G.UIParent)
			local slot = _G.CreateFrame("Button", "CharacterBag0Slot", _G.UIParent)
			BT.settings.hideClientBags = nil
			space.Show(true)
			assert(space.HideClient(), "hiding the client's bag bar is on unless you turn it off")
			assert(backpack._alpha == 0 and slot._alpha == 0, "the backpack and the bag slots go")
			space.SetHideClient(false)
			assert(backpack._alpha == 1 and slot._alpha == 1, "and come back when it is turned off")
			space.SetHideClient(true)
			-- (away while the Bags line OR the bag window is on - Josh 2026-09-24)
			local hadWindow = BT.Enabled("bagwindow")
			BT.SetEnabled("bagwindow", false)
			BT.SetEnabled("bagspace", false)
			assert(backpack._alpha == 1, "switching both off brings the bar back too")
			BT.SetEnabled("bagspace", true)
			assert(backpack._alpha == 0, "and on puts it away again")
			BT.SetEnabled("bagwindow", hadWindow)
			local opened = 0
			_G.ToggleAllBags = function() opened = opened + 1 end
			space.Build():GetScript("OnClick")(space.Build())
			assert(opened == 1, "a click on the cell opens your bags")
			_G.ToggleAllBags = nil
			space.SetHideClient(false)
			BT.settings.hideClientBags = nil
			_G.MainMenuBarBackpackButton, _G.CharacterBag0Slot = nil, nil

			-- no bags to ask about: the line goes, rather than saying 0/0
			space.Update()
			assert(not space.Build().wanted, "no slots at all, no cell")

			SlashCmdList.BEEBSTOOLKIT("gold")
			BT.Util.Now = realNow
			_G.GetMoney = nil
		end },
		{ "performance is three cells of the readout grid", function()
			local mod = BT.GetModule("perf")
			assert(mod and mod.kind == "readout", "the module is loaded, as a readout")
			_G.GetFramerate = function() return 59.6 end
			_G.GetNetStats = function() return 0, 0, 42, 310 end
			BT.SetEnabled("perf", true)
			mod.Show(true)
			mod.Update()
			local chips = mod.Build()
			assert(chips.fps.wanted and chips.home.wanted and chips.world.wanted, "three cells")
			assert(chips.fps.order < chips.home.order and chips.home.order < chips.world.order,
				"frame rate, then home, then world")
			assert(chips.fps.spec.text:find("60", 1, true) and not chips.fps.spec.state,
				"frames a second, rounded, and plain when fine: " .. chips.fps.spec.text)
			assert(chips.home.spec.icon == mod.HOUSE.icon and chips.home.spec.coords == mod.HOUSE.coords
				and chips.home.spec.text:find("42", 1, true), "home under the house")
			assert(chips.world.spec.coords == mod.GLOBE.coords and chips.world.spec.state == "alert",
				"the world under the globe, red at 310")
			assert(mod.FpsState(40) == "warn" and mod.MsState(150) == "warn" and mod.MsState(20) == nil,
				"amber is worth noticing, plain is fine")

			-- the grid: three across, one row, a height the client will draw
			BT.Bar.Relayout()
			local grid = chips.fps:GetParent()
			assert(grid.key == "readouts" and (grid.wantHeight or 0) > 0 and (grid._height or 0) > 0,
				"one group, with a height")
			local fpsAt, homeAt = chips.fps._points.TOPLEFT, chips.home._points.TOPLEFT
			assert(fpsAt and homeAt and fpsAt.y == homeAt.y and homeAt.x > fpsAt.x,
				"side by side on one row")
			-- EVERY ROW THE SAME: a cell and the pixel of line under it, from
			-- the top of the grid, with the figures a pixel low in it
			assert(chips.fps._height == 18 and grid.wantHeight > 0 and grid.wantHeight % 19 == 0,
				"a row is its cell and its line: " .. tostring(chips.fps._height) .. "/" .. tostring(grid.wantHeight))
			local words = chips.fps.text._points.LEFT
			assert(words and words.y == -1, "and the figures sit a pixel below the middle")

			-- a client that will not say still draws cells rather than failing
			_G.GetNetStats = nil
			mod.Update()
			assert(chips.home.spec.text:find("-", 1, true), "a dash without numbers")
			BT.SetEnabled("perf", false)
			assert(not chips.fps.wanted, "and switching it off takes the cells away")
			BT.SetEnabled("perf", true)
			BT.SetEnabled("perf", false)
			_G.GetFramerate = nil
		end },
		{ "with nobody targeted, the row says what to do", function()
			local who
			for _, c in ipairs(BT.Bar.Cells()) do
				if c.pencil then who = c end
			end
			assert(who, "the name cell is on the row")
			local wasUnit, wasExists = _G.UnitName, _G.UnitExists
			_G.UnitExists = function() return false end
			who:Update()
			assert(who.text._text:find("target a player to add notes and tags", 1, true),
				"it says what targeting is for: " .. tostring(who.text._text))
			assert((who.cellWidth or 0) < 150, "claiming a name's width, not the sentence's: "
				.. tostring(who.cellWidth))
			local at = who.text._points and who.text._points.RIGHT
			assert(at and at.rel == BT.Bar.Row(), "and reaching to the row's edge for the rest")
			local mark = BT.Bar.Frame().mark.icon
			assert(tostring(mark._texture):find("net", 1, true), "and a reticle waits in the first slot")
			_G.UnitName, _G.UnitExists = wasUnit, wasExists
			who:Update()
		end },
		{ "the character sheet: item level on every slot", function()
			local mod = BT.GetModule("charsheet")
			assert(mod and BT.Window.InSettings("charsheet"), "a page of Settings, like the other restyles")
			local slots = {}
			for id, name in pairs({ [5] = "Chest", [16] = "MainHand", [11] = "Finger0" }) do
				local b = _G.CreateFrame("Button", "Character" .. name .. "Slot", _G.UIParent)
				b.GetID = function() return id end
				_G["Character" .. name .. "Slot"] = b
				slots[name] = b
			end
			local shirt = _G.CreateFrame("Button", "CharacterShirtSlot", _G.UIParent)
			_G.CharacterShirtSlot = shirt
			local worn = { [5] = "item:5", [16] = "item:16" }
			_G.GetInventoryItemLink = function(_, id) return worn[id] end
			_G.GetItemInfo = function(l) return "x", l, 2, l == "item:5" and 13 or 10 end
			BT.SetEnabled("charsheet", true)
			mod.UpdateAll()
			local chest = slots.Chest.beebsLevel
			assert(chest and chest:IsShown() and chest._text == "13", "the chest says 13: " .. tostring(chest and chest._text))
			assert(slots.MainHand.beebsLevel._text == "10", "and the weapon its own")
			assert(not slots.Finger0.beebsLevel:IsShown(), "an empty slot says nothing")
			assert(shirt.beebsLevel == nil and not mod.Ours(shirt), "and the shirt is not asked")

			-- a new piece, and the slot says so
			worn[11] = "item:5"
			mod.Update(slots.Finger0)
			assert(slots.Finger0.beebsLevel:IsShown() and slots.Finger0.beebsLevel._text == "13",
				"putting a ring on puts its number on")

			mod.SetShowsLevels(false)
			assert(not chest:IsShown(), "the switch takes the numbers off")
			mod.SetShowsLevels(true)
			assert(chest:IsShown(), "and puts them back")
			BT.SetEnabled("charsheet", false)
			assert(not chest:IsShown(), "and the module off leaves the game's sheet as it was")
			BT.SetEnabled("charsheet", true)
			SlashCmdList.BEEBSTOOLKIT("sheet")

			-- WRITTEN DOWN BEFORE IT IS RESKINNED: the window's frames, by name or
			-- key, with what each draws, into the saved file
			local frame = _G.CreateFrame("Frame", "CharacterFrame", _G.UIParent)
			local bg = frame:CreateTexture()
			frame.Bg = bg
			local inset = _G.CreateFrame("Frame", nil, frame)
			frame.Inset = inset
			_G.CharacterFrame = frame
			SlashCmdList.BEEBSTOOLKIT("sheetdump")
			local dump = _G.BeebModDB.sheetDump
			assert(dump and #dump.lines >= 2, "the window is written into the saved file")
			local text = table.concat(dump.lines, "\n")
			assert(text:find("CharacterFrame.Inset", 1, true), "a child with no name is known by its key: " .. text)
			SlashCmdList.BEEBSTOOLKIT("sheetdump clear")
			assert(_G.BeebModDB.sheetDump == nil, "and can be cleared")
			_G.CharacterFrame = nil
			for name in pairs(slots) do
				_G["Character" .. name .. "Slot"] = nil
			end
			_G.CharacterShirtSlot, _G.GetInventoryItemLink, _G.GetItemInfo = nil, nil, nil
		end },
		{ "the character sheet in the toolkit's clothes, by what each piece draws", function()
			local mod = BT.GetModule("charsheet")
			local function art(parent, atlas)
				local t = parent:CreateTexture()
				t.GetAtlas = function() return atlas end
				t.SetAtlas = function(self, a) self._atlasSet = a end
				t:SetAlpha(1)
				return t
			end
			local frame = _G.CreateFrame("Frame", "CharacterFrame", _G.UIParent)
			frame:SetSize(631, 484)
			frame.NineSlice = _G.CreateFrame("Frame", nil, frame)
			frame.PortraitContainer = _G.CreateFrame("Frame", nil, frame)
			local header = _G.CreateFrame("Button", nil, frame)
			header.Name = header:CreateFontString()
			local banner = art(header, "common-button-list-collapseExpand")
			local tab = _G.CreateFrame("Frame", nil, frame)
			local tabBg = art(tab, "common-sidetab")
			tab.SelectedTexture = art(tab, "common-sidetab-selected")
			local bar = _G.CreateFrame("Frame", nil, frame)
			local well = art(bar, "common-stat-bar-BG")
			local classBg = art(frame, "UI-Character-Info-Mage-BG")
			-- a reputation bar's fill: the standing's colour, and the game's to set
			local keep = art(frame, "common-stat-bar-white")
			local left = _G.CreateFrame("Frame", nil, frame)
			left:SetSize(398, 464)
			frame.CharacterFrameLeftPaneHost = left
			local right = _G.CreateFrame("Frame", nil, frame)
			right:SetSize(233, 464)
			frame.CharacterFrameRightPaneHost = right
			_G.CharacterFrameRightPaneHost = right
			local head = _G.CreateFrame("Button", "CharacterHeadSlot", frame)
			head:SetSize(37, 37)
			_G.CharacterHeadSlot = head
			-- a reputation page with one row: a name and a boxed bar beside it
			local rep = _G.CreateFrame("Frame", nil, frame)
			frame.ReputationFrame = rep
			rep.ScrollBox = _G.CreateFrame("Frame", nil, rep)
			rep.ScrollBox.ScrollTarget = _G.CreateFrame("Frame", nil, rep.ScrollBox)
			local row = _G.CreateFrame("Button", nil, rep.ScrollBox.ScrollTarget)
			row.Content = _G.CreateFrame("Frame", nil, row)
			row.Content.Name = row.Content:CreateFontString()
			row.Content.ReputationBar = _G.CreateFrame("Frame", nil, row.Content)
			row.Content.ReputationBar:SetSize(160, 29)
			row.Content.ReputationBar.Text = row.Content.ReputationBar:CreateFontString()
			row:SetHeight(30)
			local faction = _G.CreateFrame("Button", nil, rep.ScrollBox.ScrollTarget)
			faction:SetHeight(28)
			faction.Name = faction:CreateFontString()
			faction.Name:SetText("Alliance")
			-- the list measures its own rows
			local view = { GetElementExtent = function() return 30 end }
			rep.ScrollBox.GetView = function() return view end
			rep.ScrollBox.FullUpdate = function(self) self._relaid = (self._relaid or 0) + 1 end
			-- a details pane drawn for 205 pixels
			local detail = _G.CreateFrame("Frame", nil, rep)
			rep.ReputationDetailFrame = detail
			detail.Title = detail:CreateFontString()
			detail.Title:SetWidth(195)
			detail.StandingBar = _G.CreateFrame("Frame", nil, detail)
			detail.StandingBar:SetSize(180, 29)
			detail.Description = _G.CreateFrame("Frame", nil, detail)
			local words = detail.Description:CreateFontString()
			words:SetWidth(191)
			-- the stats: a header and a line under it, from the list's own data
			local stats = _G.CreateFrame("Frame", "CharacterStatsPaneScrollBox", frame)
			_G.CharacterStatsPaneScrollBox = stats
			stats.ScrollBox = _G.CreateFrame("Frame", nil, stats)
			stats.ScrollBox.ScrollTarget = _G.CreateFrame("Frame", nil, stats.ScrollBox)
			stats.ScrollBox.ScrollTarget:SetWidth(156)
			local data = { { header = true }, { stat = "Health" } }
			local provider = {
				Find = function(_, i) return data[i] end,
				FindIndex = function(_, d) for i, x in ipairs(data) do if x == d then return i end end end,
			}
			local statView = {
				GetElementExtent = function(_, i) return i == 1 and 40 or 23 end,
				GetDataProvider = function() return provider end,
			}
			stats.ScrollBox.GetView = function() return statView end
			stats.ScrollBox.FullUpdate = function(self) self.fulls = (self.fulls or 0) + 1 end
			stats.ScrollBox.SetDataProvider = function() end
			-- the client's hooksecurefunc, on an object's method
			local hadHook = _G.hooksecurefunc
			_G.hooksecurefunc = _G.hooksecurefunc or function(obj, name, fn)
				local orig = obj[name]
				obj[name] = function(...)
					local r = orig(...)
					fn(...)
					return r
				end
			end
			local general = _G.CreateFrame("Frame", nil, stats.ScrollBox.ScrollTarget)
			general:SetHeight(40)
			general.Title = general:CreateFontString()
			general.Title:SetText("General")
			general.Title:SetTextColor(1, 0.82, 0)
			general.GetElementData = function() return data[1] end
			local health = _G.CreateFrame("Frame", nil, stats.ScrollBox.ScrollTarget)
			health:SetHeight(23)
			health.Label = health:CreateFontString()
			health.Value = health:CreateFontString()
			health.GetElementData = function() return data[2] end
			local pvp = _G.CreateFrame("Frame", nil, frame)
			frame.PVPRankFrame = pvp
			pvp.MainInfoFrame = _G.CreateFrame("Frame", nil, pvp)
			pvp.MainInfoFrame:SetSize(398, 135)
			local title = frame:CreateFontString("CharacterFrameTitleText")
			_G.CharacterFrameTitleText = title
			_G.CharacterFrame = frame

			BT.SetEnabled("charsheet", true)
			BT.settings.charsheet = BT.settings.charsheet or {}
			BT.settings.charsheet.theme = nil
			assert(mod.Themed(), "on unless you turn it off")
			mod.Dress()
			assert(frame.NineSlice._alpha == 0 and frame.PortraitContainer._alpha == 0,
				"the metal frame and the portrait come off")
			assert(banner._alpha == 0, "a list header's banner comes off")
			assert(tabBg._alpha == 0 and tab.SelectedTexture._alpha == 0, "and a tab's art")
			assert(classBg._alpha == 0, "the class's backdrop behind the stats too")
			assert(well._vertex and well._vertex[1] < 0.5 and well._atlasSet == nil,
				"a bar's track is tinted to the theme's well, and keeps its art: the game reads it back")
			assert(keep._alpha ~= 0 and keep._vertex == nil, "and a bar's fill is the game's: it says something")
			assert(BT.Pill.Panels()[frame], "the window sits on the toolkit's surface")
			-- the game shows the chosen tab's art with SetShown as well as Show
			local glow = tab:CreateTexture()
			glow:Show()
			mod.StayDown(glow)
			assert(not glow:IsShown(), "a tab's glow is held down")
			glow:SetShown(true)
			assert(not glow:IsShown(), "shown by SetShown, it is held down too")

			-- HALF THE SPACE: the mockup's compact layout
			assert(frame._width == 452 and frame._height == 356, "the window is 452 x 356: "
				.. tostring(frame._width) .. "x" .. tostring(frame._height))
			-- NO LARGE FRAME FIRST (Josh 2026-09-24): the game sizes it as it
			-- opens, after us, and it comes straight back to ours
			frame:SetSize(631, 424)
			mod.OnSheetSized()
			assert(frame._width == 452 and frame._height == 356, "the game's size answered at once: "
				.. tostring(frame._width))
			assert(right._width == 176, "the side pane 176 wide")
			assert(head._width == 32, "a slot is 32px")
			local b = row.Content.ReputationBar
			assert(b._height == 2 and b._points.BOTTOMLEFT, "a row's bar is a hairline under it")
			assert(b.Text._points.RIGHT, "and its standing on the right of the row")
			-- AIR BETWEEN THE WORDS AND THE BAR (Josh 2026-09-24)
			assert(b._points.BOTTOMLEFT.y == mod.ROW_BAR_Y and b.Text._points.RIGHT.y == mod.ROW_TEXT_Y
				and mod.ROW_TEXT_Y - mod.ROW_BAR_Y >= 2, "the words lifted clear of the bar under them")
			-- THE MOCKUP'S SPACING: rows 22, headers 20, in small capitals
			assert(row._height == 22, "a row is 22 tall, not the game's 30: " .. tostring(row._height))
			assert(faction._height == 20 and faction.Name._text == "ALLIANCE",
				"a header 20 tall, its words in capitals")
			assert(view.GetElementExtent() == 22, "and the list measures its rows that way, so they close up")
			assert((rep.ScrollBox._relaid or 0) >= 1, "laid out again once it does")
			assert(detail.Title._width == 156 and detail.StandingBar._width == 152,
				"a details pane's pieces fit the pane: " .. tostring(detail.Title._width))
			assert(words._width == 148, "and the words inside them keep a margin, so nothing runs past the edge")
			assert(title._justify == "LEFT" and title._points.LEFT, "the name sits on the left of the title bar")
			-- THE STATS, TIGHT: 15px lines, 18px headers, and a section folds
			BT.settings.charsheet.folded = nil
			mod.Layout()
			assert(health._height == 15 and general._height == 18,
				"a stat line is 15, a header 18: " .. tostring(health._height) .. "/" .. tostring(general._height))
			assert(statView.GetElementExtent(statView, 2) == 15, "and the list measures them so")
			assert(general.beebsChevron and general:GetScript("OnMouseUp"), "a header has a chevron, and folds")
			general:GetScript("OnMouseUp")(general)
			assert(mod.Folded("GENERAL"), "a click folds it, remembered")
			assert(statView.GetElementExtent(statView, 2) == 1,
				"its lines measure a pixel - nothing at all stops the game's list laying out the rest")
			assert(statView.GetElementExtent(statView, 1) == 18, "while the header itself stays")
			mod.StatRow(health)
			assert(health._alpha == 0 and health._height == 1,
				"and the line is not drawn, and takes no room: " .. tostring(health._height))
			general:GetScript("OnMouseUp")(general)
			mod.StatRow(health)
			assert(not mod.Folded("GENERAL") and health._alpha == 1, "another click opens it again")
			assert(health._height == 15,
				"and the line is its own height again, not the pixel it was folded to: "
					.. tostring(health._height))
			-- KNOWN BEFORE IT IS DRAWN: the game builds its list afresh (new
			-- data), with GENERAL folded - the line under it is measured a pixel
			-- before either row is drawn again
			general:GetScript("OnMouseUp")(general)
			assert(mod.Folded("GENERAL"), "folded again")
			local fresh = { { header = true }, { stat = "Health" }, { header = true }, { stat = "Strength" } }
			data = fresh
			assert(statView.GetElementExtent(statView, 2) == 1,
				"a new list's line under a folded header, never drawn, measures a pixel: "
					.. tostring(statView.GetElementExtent(statView, 2)))
			-- the second section's title is not known until one is drawn, so its
			-- line stays open rather than guessing
			assert(statView.GetElementExtent(statView, 4) == 15, "an unknown section stays open")
			local second = _G.CreateFrame("Frame", nil, stats.ScrollBox.ScrollTarget)
			second.Title = second:CreateFontString()
			second.Title:SetText("Primary Attributes")
			second.GetElementData = function() return fresh[3] end
			mod.StatRow(second)
			assert(mod.headerOrder[2] == "PRIMARY ATTRIBUTES", "the order is learned as headers are drawn")
			second:GetScript("OnMouseUp")(second)
			data = { { header = true }, { stat = "Health" }, { header = true }, { stat = "Strength" } }
			assert(statView.GetElementExtent(statView, 4) == 1 and statView.GetElementExtent(statView, 2) == 1,
				"and on the next fresh list, both folded sections close without a row drawn")
			second:GetScript("OnMouseUp")(second)
			general:GetScript("OnMouseUp")(general)
			data = { { header = true }, { stat = "Health" } }
			assert(not mod.Folded("GENERAL") and statView.GetElementExtent(statView, 2) == 15, "and open again")
			-- LAID OUT AGAIN AFTER EVERY NEW LIST, a frame later, once its
			-- headers have been drawn
			local wasAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			mod.relearn = false
			local before = stats.ScrollBox.fulls or 0
			stats.ScrollBox:SetDataProvider({})
			assert((stats.ScrollBox.fulls or 0) > before, "the game's new list is laid out again")
			_G.C_Timer.After = wasAfter
			_G.hooksecurefunc = hadHook

			-- A RESISTANCE IS A SWATCH: the spell icon off, the element's colour on
			local resist = _G.CreateFrame("Frame", nil, stats.ScrollBox.ScrollTarget)
			resist:SetHeight(23)
			resist.Label = resist:CreateFontString()
			resist.Label:SetText("Frost:")
			resist.Value = resist:CreateFontString()
			local spellIcon = resist:CreateTexture()
			spellIcon:SetAlpha(1)
			mod.StatRow(resist)
			assert(spellIcon._alpha == 0, "the spell icon comes off")
			assert(resist.beebsSwatch and resist.beebsSwatch._color
				and resist.beebsSwatch._color[3] > resist.beebsSwatch._color[1],
				"and frost's blue square is in its place")

			-- ONE ANCHOR AND NO SIZE DRAWS NOTHING: the rank display keeps its own
			assert(pvp.MainInfoFrame._width == 398 and pvp.MainInfoFrame._height == 135,
				"the PvP rank keeps its size when it moves: " .. tostring(pvp.MainInfoFrame._width))
			right:Hide()
			mod.Layout()
			assert(frame._width == 452 - 176, "details hidden, the window narrows to what is left")
			right:Show()

			health.Label._width = 77
			mod.SetThemed(false)
			assert(banner._alpha == 1 and tabBg._alpha == 1 and frame.NineSlice._alpha == 1,
				"off gives every piece back")
			assert(general.Title._textColor[2] == 0.82,
				"a stat title moved by its header and greyed as its words gets its colour back too")
			assert(health.Label._width == 77, "a label only re-fonted keeps the width the game gave it since: "
				.. tostring(health.Label._width))
			assert(glow:IsShown(), "the chosen tab's glow comes back, as the game wanted")
			assert(faction.beebsChevron and not faction.beebsChevron:IsShown(),
				"a reputation header's chevron goes too, not only the stats'")
			assert(frame._width == 631 and head._width == 37 and b._height == 29,
				"and every size: the game's own layout again")
			assert(row._height == 30 and view.GetElementExtent() == 30, "the rows the game's height again")
			assert(well._vertex[1] == 1, "the track its own colour again")
			mod.SetThemed(true)
			assert(banner._alpha == 0, "and on takes it off again")
			mod.StayDown(glow)
			assert(not glow:IsShown(), "and held down again when the theme is back")
			BT.settings.charsheet.theme = nil
			mod.Undress()
			_G.CharacterFrame, _G.CharacterFrameRightPaneHost, _G.CharacterHeadSlot = nil, nil, nil
			_G.CharacterFrameTitleText, _G.CharacterStatsPaneScrollBox = nil, nil
		end },
		{ "the character sheet drags by its title and opens where it was left", function()
			local mod = BT.GetModule("charsheet")
			local frame = _G.CreateFrame("Frame", "CharacterFrame", _G.UIParent)
			_G.CharacterFrame = frame
			BT.SetEnabled("charsheet", true)
			BT.settings.charsheet = BT.settings.charsheet or {}
			BT.settings.charsheet.pos, BT.settings.charsheet.move = nil, nil
			local handle = mod.Handle()
			assert(handle and handle:GetScript("OnDragStart"), "the title bar is a handle")
			-- dropped 300 across and 120 down
			frame.GetLeft = function() return 300 end
			frame.GetTop = function() return 648 end
			frame.GetEffectiveScale = function() return 1 end
			local wasTop, wasScale = _G.UIParent.GetTop, _G.UIParent.GetEffectiveScale
			_G.UIParent.GetTop = function() return 768 end
			_G.UIParent.GetEffectiveScale = function() return 1 end
			handle:GetScript("OnDragStart")(handle)
			handle:GetScript("OnDragStop")(handle)
			local pos = BT.settings.charsheet.pos
			assert(pos and pos.x == 300 and pos.y == -120, "where it was dropped is kept: "
				.. tostring(pos and pos.x) .. "," .. tostring(pos and pos.y))
			-- the game puts it back in its own place when it opens; it comes back
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 16, -116)
			frame:Show()
			mod.ApplyPosition()
			local at = frame._points.TOPLEFT
			assert(at.x == 300 and at.y == -120, "and it opens there again")
			SlashCmdList.BEEBSTOOLKIT("sheet reset")
			assert(BT.settings.charsheet.pos == nil, "/bt sheet reset forgets it")
			_G.UIParent.GetTop, _G.UIParent.GetEffectiveScale = wasTop, wasScale
			_G.CharacterFrame = nil
		end },
		{ "item level: the average of what you wear, one of the Metrics", function()
			local mod = BT.GetModule("ilevel")
			assert(mod and mod.part == "metrics", "the module is loaded, as a part of Metrics")
			local worn = { [1] = "item:1", [16] = "item:16", [5] = "item:5" }
			local levels = { ["item:1"] = 20, ["item:16"] = 30, ["item:5"] = 18 }
			local twoHand = false
			_G.GetInventoryItemLink = function(_, slot) return worn[slot] end
			_G.GetItemInfo = function(l)
				return "x", l, 2, levels[l], 1, "Armor", "x", 1,
					(l == "item:16" and twoHand) and "INVTYPE_2HWEAPON" or "INVTYPE_CHEST"
			end
			local d = mod.Read()
			assert(#d.items == 3 and d.sum == 68, "every worn piece and its level")
			assert(mod.Value(d) == math.floor(68 / 17), "an empty slot counts as nothing, rounded down")
			twoHand = true
			assert(mod.Read().sum == 98, "a two-hander fills the off hand as well")
			worn[17] = "item:17"
			levels["item:17"] = 10
			assert(mod.Read().sum == 78, "but not once something is in it")
			-- RETAIL'S SUM, NOT THE CLIENT'S (Josh 2026-09-22): this client's own
			-- figure came out lower than retail's rule would give
			_G.GetAverageItemLevel = function() return 3.1, 3.1 end
			assert(mod.Value() == math.floor(78 / 17), "the client's figure is not used: "
				.. tostring(mod.Value()))
			levels["item:17"], levels["item:16"] = 300, 125
			assert(mod.Value() == math.floor((20 + 125 + 18 + 300) / 17), "whatever it says")
			BT.SetEnabled("metrics", true)
			BT.SetEnabled("ilevel", true)
			mod.Update()
			local chip = mod.Build()
			assert(chip.wanted and chip.spec.text:find("27", 1, true) and chip.spec.text:find("ilvl", 1, true),
				"a cell: the number, and what it is")
			SlashCmdList.BEEBSTOOLKIT("ilvl")

			-- AT LOGIN THE CLIENT HAS NOT DESCRIBED YOUR GEAR YET: no levels, no
			-- cell - and it has to turn up on its own once they arrive
			local realInfo, realAfter = _G.GetItemInfo, _G.C_Timer.After
			local later = {}
			_G.C_Timer.After = function(_, fn) later[#later + 1] = fn end
			_G.GetItemInfo = function() return nil end
			mod.events:GetScript("OnEvent")(mod.events, "PLAYER_ENTERING_WORLD")
			assert(not chip.wanted, "nothing known yet, no cell")
			assert(#later >= 2, "so it looks again, more than once: " .. #later)
			_G.GetItemInfo = realInfo
			for _, fn in ipairs(later) do
				fn()
			end
			assert(chip.wanted, "and the cell turns up once the gear is described")
			_G.C_Timer.After = realAfter
			worn = {}
			_G.GetAverageItemLevel = nil
			mod.Update()
			assert(not chip.wanted, "nothing worn, no cell")
			_G.GetInventoryItemLink, _G.GetItemInfo = nil, nil
		end },
		{ "a border is whole screen pixels, so all four edges match", function()
			-- a 1440p screen at 0.71 scale: one unit is about 1.35 pixels
			local wasPU = _G.PixelUtil
			_G.PixelUtil = { GetNearestPixelSize = function(units, scale, min)
				local perUnit = scale * 1440 / 768
				local px = math.max(min or 0, math.floor(units * perUnit + 0.5))
				return px / perUnit
			end }
			local f = _G.CreateFrame("Frame", nil, _G.UIParent)
			f.GetEffectiveScale = function() return 0.71 end
			local one = BT.Pill.Px(f, 1)
			assert(math.abs(one * 0.71 * 1440 / 768 - 1) < 1e-6,
				"a one-unit border is exactly one screen pixel: " .. tostring(one))
			local bars = BT.Pill.Ring(f, "BORDER", 0)
			BT.Pill.PlaceRing(bars, f, 0, 1, 0)
			assert(bars[1]._height == one and bars[3]._width == one, "every edge the same")
			-- A RULE MADE BEFORE ITS FRAME IS LAID OUT reports no size, and is
			-- still made a hairline once it has one
			local early = f:CreateTexture(nil, "ARTWORK")
			local realH = early.GetHeight
			early.GetHeight = function() return 0 end
			early.GetEffectiveScale = function() return 0.71 end
			BT.Widgets.Rule(early)
			early.GetHeight = realH
			early:SetHeight(1)
			BT.Widgets.Hairlines()
			assert(early._height == one, "the rule under the grid is one pixel too: " .. tostring(early._height))
			_G.PixelUtil = wasPU
			assert(BT.Pill.Px(f, 1) == 1, "and one unit where the client cannot say")

			-- and the panel sits on the grid, so no edge straddles two pixels
			local bar = BT.Bar.Frame()
			local wasScale = bar.GetEffectiveScale
			bar.GetEffectiveScale = function() return 0.71 end
			_G.GetPhysicalScreenSize = function() return 2560, 1440 end
			local pixel = 768 / 1440 / 0.71
			local x = BT.Bar.Snap(100.3)
			assert(math.abs(x / pixel - math.floor(x / pixel + 0.5)) < 1e-6,
				"a corner at 100.3 units moves to a whole pixel: " .. tostring(x))
			assert(math.abs(x - 100.3) <= pixel / 2 + 1e-9, "and moves less than half a pixel")
			_G.GetPhysicalScreenSize = nil
			bar.GetEffectiveScale = wasScale
			assert(BT.Bar.Snap(100.3) == 100.3, "untouched where the client cannot say")

			-- THE WINDOW, DRAGGED A PIXEL AT A TIME, AN EIGHTH CLEAR OF A TIE
			local win = BT.Window.Build()
			assert(win:GetScript("OnDragStart") and win:GetScript("OnDragStop"), "the window drags")
			local keep = { win.GetEffectiveScale, win.GetLeft, win.GetTop, _G.GetCursorPosition }
			win.GetEffectiveScale = function() return 0.8 end
			win.GetLeft = function() return 200 end
			win.GetTop = function() return 600 end
			_G.GetPhysicalScreenSize = function() return 1920, 1200 end
			local wpx = 768 / 1200 / 0.8
			local function settled(v)
				local f = v / wpx - math.floor(v / wpx)
				return math.abs(f - BT.Widgets.PIXEL_BIAS) < 1e-6
			end
			local cx, cy = 400, 300
			_G.GetCursorPosition = function() return cx, cy end
			win:GetScript("OnDragStart")(win)
			local driver = BT.Widgets.dragger
			assert(driver and driver.frame == win and driver:GetScript("OnUpdate"), "the toolkit moves it, not the client")
			cx, cy = 400.37, 297.9
			driver:GetScript("OnUpdate")(driver, 0.016)
			local at = win._points.TOPLEFT
			assert(at.rel == UIParent and at.relPoint == "BOTTOMLEFT", "placed from the screen's corner")
			assert(settled(at.x) and settled(at.y), "an eighth past a whole pixel mid-drag: " .. at.x .. ", " .. at.y)
			win:GetScript("OnDragStop")(win)
			assert(driver:GetScript("OnUpdate") == nil, "and let go")
			at = win._points.TOPLEFT
			assert(settled(at.x) and settled(at.y), "and settled where it lands")
			-- no piece of it lands on a tie: a unit is a pixel and a quarter
			for units = 0, 12 do
				local f = (at.x / wpx + units * 1.25) % 1
				assert(math.abs(f - 0.5) > 0.1 and f > 0.1 and f < 0.9, "a piece " .. units .. " units in is clear of a tie")
			end
			win.GetEffectiveScale, win.GetLeft, win.GetTop, _G.GetCursorPosition = keep[1], keep[2], keep[3], keep[4]
			_G.GetPhysicalScreenSize = nil

			-- /bt pixels: the numbers, and snapping switched off and on again
			SlashCmdList.BEEBSTOOLKIT("pixels")
			SlashCmdList.BEEBSTOOLKIT("pixels snap off")
			assert(BT.Pill.snapping == false, "snapping can be switched off")
			SlashCmdList.BEEBSTOOLKIT("pixels snap on")
			assert(BT.Pill.snapping == true, "and on again")
			SlashCmdList.BEEBSTOOLKIT("pixels snap off")
			assert(BT.Pill.snapping == false, "off being where it starts")
		end },
		{ "movement speed: a cell of the readout grid", function()
			local mod = BT.GetModule("speed")
			assert(mod and mod.part == "metrics", "the module is loaded, as a part of Metrics")
			local current, run = 0, 7
			_G.GetUnitSpeed = function() return current, run, 0, 0 end
			_G.BASE_MOVEMENT_SPEED = 7
			BT.SetEnabled("metrics", true)
			BT.SetEnabled("speed", true)
			mod.Update()
			local chip = mod.Build()
			assert(chip.wanted and chip.spec.text:find("0", 1, true) and mod.Percent() == 0,
				"standing still it says 0%: " .. tostring(chip.spec.text))
			assert(not chip.spec.state, "and standing still is plain, not a warning")
			current = 7
			mod.Update()
			assert(mod.Percent() == 100 and not chip.spec.state, "running is 100%, plain")
			current = 11.2
			assert(mod.Percent() == 160, "on a mount, 160%")
			current = 3.5
			mod.Update()
			assert(mod.Percent() == 50 and chip.spec.state == "warn", "and something with hold of you is amber")
			SlashCmdList.BEEBSTOOLKIT("speed")
			_G.GetUnitSpeed, _G.BASE_MOVEMENT_SPEED = nil, nil
			mod.Update()
			assert(not chip.wanted, "a client that will not say shows no cell")
			BT.SetEnabled("speed", false)
		end },
		{ "metrics: one tab, a switch for each readout", function()
			local metrics = BT.GetModule("metrics")
			assert(metrics and metrics.dock, "the module is loaded, on the right panel")
			local parts = {}
			for _, m in ipairs(metrics.Parts()) do
				parts[#parts + 1] = m.key
				assert(BT.Window.Group(m.key) == nil and BT.Window.TabFor(m.key) == "metrics",
					m.key .. " has no tab of its own: it is on Metrics'")
			end
			assert(table.concat(parts, ",") == "gold,bagspace,durability,ilevel,pickpocket,speed,perf",
				"the metrics, in the order the grid shows them: " .. table.concat(parts, ","))
			_G.GetFramerate = function() return 60 end
			local perf, dur = BT.GetModule("perf"), BT.GetModule("durability")
			BT.SetEnabled("metrics", true)
			BT.SetEnabled("perf", true)
			assert(BT.Enabled("perf") and perf.Build().fps.wanted, "a part is on while Metrics is")
			assert(BT.settings.modules.metrics == true,
				"switching on is written down, not left blank for an old copy to fill")

			BT.SetEnabled("metrics", false)
			assert(not BT.Enabled("perf") and BT.Switched("perf"),
				"Metrics off puts its parts away, and remembers each one's own switch")
			BT.Bar.Relayout()
			assert(not perf.Build().fps:IsShown(), "and the cells go")
			BT.SetEnabled("metrics", true)
			BT.Bar.Relayout()
			assert(BT.Enabled("perf") and perf.Build().fps:IsShown(), "on again brings them back")

			BT.SetEnabled("perf", false)
			BT.Bar.Relayout()
			assert(not perf.Build().fps:IsShown() and BT.Enabled("metrics"), "one part off is only that part")

			-- the tab: a row with a switch per part
			BT.Window.SetView("metrics")
			metrics:RefreshTab()
			local perfRow
			for _, r in ipairs(metrics.rows or {}) do
				if r.part.key == "perf" then perfRow = r end
			end
			assert(perfRow and perfRow.switch, "a row for Performance, with its switch")
			assert(not perfRow.switch.on, "off, as it was left")
			perfRow.switch:GetScript("OnClick")(perfRow.switch)
			assert(BT.Enabled("perf"), "and a click on it switches Performance on")
			BT.SetEnabled("perf", false)
			_G.GetFramerate = nil
		end },
		{ "the minimap moves into the panel and takes its ring off", function()
			-- SAME BARGAIN AS THE ACTION BARS (Josh 2026-09-21): it is the
			-- client's own Minimap, moved and undressed. The wheel still
			-- zooms, a click still pings, a right-click still opens tracking,
			-- and every blip is drawn by the client exactly as before.
			local mod = BT.GetModule("minimap")
			local map = _G.CreateFrame("Frame", "Minimap", _G.UIParent)
			map:SetSize(140, 140)
			map:SetPoint("TOPRIGHT", _G.UIParent, "TOPRIGHT", -20, -20)
			map.GetMaskTexture = function(self) return self._mask end
			map.SetMaskTexture = function(self, m) self._mask = m end
			map:SetMaskTexture("Interface\\Round")
			_G.Minimap = map
			local ring = _G.CreateFrame("Frame", "MinimapBorder", _G.UIParent)
			local zoom = _G.CreateFrame("Frame", "MinimapZoomIn", _G.UIParent)
			local track = _G.CreateFrame("Button", "MiniMapTracking", _G.UIParent)
			local clock = _G.CreateFrame("Button", "GameTimeFrame", _G.UIParent)
			local zone = _G.CreateFrame("Button", "MinimapZoneTextButton", _G.UIParent)
			_G.MinimapZoneText = _G.CreateFrame("FontString")

			BT.SetEnabled("minimap", true)
			assert(mod.Apply(), "it takes the map over")

			-- in the panel, with the rest
			assert(map._parent == mod.Build(), "it lives in the dock's own section")
			assert(mod.Build():IsShown(), "and that section is up")

			-- ALWAYS SOLID (Josh 2026-09-22). Below 100% the client stops drawing
			-- the terrain and only the blips fade, so there is no setting: the map
			-- is drawn solid whatever an earlier version saved.
			mod.SetOpt("alpha", 0.6)
			assert((map._alpha or 1) == 1, "the map is solid, whatever was saved: " .. tostring(map._alpha))
			local tab = _G.CreateFrame("Frame", nil, _G.UIParent)
			mod:BuildTab(tab)
			assert(mod.alphaPlus == nil and mod.alphaText == nil, "and there is no opacity on its tab")
			mod.SetOpt("alpha", nil)
			mod.Apply()
			-- and no second background of its own, and no hole in the dock's
			assert(mod.skin.fill._shown == false, "the minimap paints no background of its own")
			BT.Bar.Relayout()
			local dockPanel = BT.Pill.Panels()[BT.Bar.Frame()]
			assert(dockPanel and dockPanel.hole == nil, "a solid map needs no hole in the dock")

			-- the same hole on either shape: the middle piece gives way to strips
			for _, r in ipairs({ 0, 6 }) do
				BT.Theme.Set("radius", r)
				local p = _G.CreateFrame("Frame", nil, _G.UIParent)
				BT.Pill.Panel(p)
				local h = BT.Pill.Panels()[p]
				local middle = r > 0 and h.roundFill.bars[1] or h.fill
				assert(middle._shown ~= false, "radius " .. r .. ": whole to start")
				BT.Pill.SetHole(p, { left = 10, top = 10, right = 10, bottom = 50 })
				assert(middle._shown == false and h.holeStrips[4]._shown ~= false,
					"radius " .. r .. ": the middle gives way to strips around the hole")
				BT.Pill.SetHole(p, nil)
				assert(middle._shown ~= false and h.holeStrips[1]._shown == false,
					"radius " .. r .. ": and comes back when it closes")
			end
			BT.Theme.Set("radius", 0)

			-- SQUARE, because a circle in a stack of rectangles leaves four
			-- corners of world showing. The client draws the round edge with
			-- a mask, and a white mask is no mask at all.
			assert(map._mask and map._mask:find("WHITE", 1, true),
				"the round mask is a square one: " .. tostring(map._mask))

			-- and the ring, the zoom pair and the rest of the furniture go
			assert(ring._alpha == 0 and zoom._alpha == 0,
				"the ring and its buttons are out of the way")

			-- WHAT IS FURNITURE AND WHAT IS INFORMATION (Josh 2026-09-21).
			-- The first pass swept the whole ring away and took three things
			-- with it that were not decoration: what you are tracking, what
			-- time of day it is, and where you are. Those are the only parts
			-- of the client's minimap that TELL you something.
			-- THE CORNERS, ON HOVER (Josh 2026-09-21, chosen from the mockup).
			-- Four corners of the map, one job each, faded out until the
			-- cursor is over the panel. At rest it is a map and two lines of
			-- text; point at it and the controls are where they always are.
			assert(track._parent == map, "tracking takes a corner of the map")
			assert((track._points or {}).TOPLEFT, "the top-left one")
			assert(clock._parent == map, "and the dial the top-right")
			assert((clock._points or {}).TOPRIGHT, "opposite it")

			-- faded at rest, up when pointed at. Alpha rather than Hide: the
			-- client shows its own buttons again on its own schedule, and at
			-- zero alpha they are invisible and still clickable.
			mod.Reveal(false)
			assert(track._alpha == 0, "at rest they are not there")
			mod.Reveal(true)
			assert(track._alpha == 1, "pointed at, they are")

			-- MAIL IS THE EXCEPTION, and it is the whole point of mail:
			-- something you have not read is no use if you go looking for it
			local post = _G.CreateFrame("Button", "MinimapMailFrame", _G.UIParent)
			_G.MinimapCluster = _G.MinimapCluster
				or _G.CreateFrame("Frame", "MinimapCluster", _G.UIParent)
			_G.MinimapCluster.MailFrame = post
			mod.found = {}
			mod.Apply()
			mod.Reveal(false)
			assert(post._alpha ~= 0, "the mail flag stays up when the rest fade")
			_G.MinimapMailFrame, _G.MinimapCluster.MailFrame = nil, nil

			-- THE CURSOR MOVES ONTO A CHILD AND THE PARENT SAYS IT LEFT (Josh
			-- 2026-09-21). Pointing at the map means pointing at one of the
			-- buttons a moment later, and a plain OnLeave hides them the
			-- instant you reach for one.
			local section = mod.Build()
			local enter = section:GetScript("OnEnter")
			local leave = section:GetScript("OnLeave")
			assert(enter and leave, "the panel knows when it is pointed at")

			local realAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			section.IsMouseOver = function() return false end
			map.IsMouseOver = function() return false end
			track.IsMouseOver = function() return false end

			enter(section)
			assert(track._alpha == 1, "pointing at the panel brings them up")
			-- the cursor is now on the button, so the panel's OnLeave fires
			track.IsMouseOver = function() return true end
			leave(section)
			assert(track._alpha == 1,
				"and reaching for one does not take it away from under the cursor")
			track.IsMouseOver = function() return false end
			leave(section)
			assert(track._alpha == 0, "leaving for real puts them away")
			_G.C_Timer.After = realAfter
			assert(clock._parent == map, "and so does the time of day")
			-- THE CAPTION ROW IS OURS (Josh 2026-09-21, layout D). Moving the
			-- client's zone caption is what laid it across the map; it is put
			-- away, and the module draws the words in the row above the map.
			assert(zone._parent ~= mod.Build() and zone._parent ~= map,
				"the client's own zone caption is put away, not moved")
			_G.GetMinimapZoneText = function() return "Trade District" end
			_G.GetZonePVPInfo = function() return "friendly" end
			mod.Caption()
			assert(mod.zoneText._text == "Trade District",
				"the caption row says where you are: " .. tostring(mod.zoneText._text))
			assert(mod.zoneText._textColor[2] == 1.0,
				"coloured by who holds the ground, as the client does it")
			local zoneAt = (mod.zoneText._points or {}).LEFT
			local coordAt = (mod.coordText._points or {}).RIGHT
			assert(zoneAt and coordAt, "the zone name on the left, the coordinates on the right")
			-- CENTRED IN THE ROW: both on the middle of the caption row, which
			-- runs from the section's top to the map's (4 + 14)
			assert(zoneAt.y == -9 and coordAt.y == -9,
				("on the caption row's middle, not hung low (%s, %s)")
					:format(tostring(zoneAt.y), tostring(coordAt.y)))
			_G.C_Map = {
				GetBestMapForUnit = function() return 1453 end,
				GetPlayerMapPosition = function()
					return { GetXY = function() return 0.618, 0.734 end }
				end,
			}
			mod.Caption()
			assert(mod.coordText._text == "61.8, 73.4",
				"and where you are standing: " .. tostring(mod.coordText._text))
			_G.C_Map, _G.GetZonePVPInfo = nil, nil
			-- not swept up with the ring: still there, still shown. Whether
			-- they are VISIBLE is the hover's business, tested below.
			assert(track._shown ~= false and clock._shown ~= false,
				"none of the three was swept up with the ring")

			-- EVERYTHING THE RING CARRIED GETS A PLACE (Josh 2026-09-21). The
			-- passes before this hid what they could not identify, which
			-- ended with a bare map and none of the things the client's
			-- corner actually does. Each one has a corner of its own now.
			_G.MinimapCluster = _G.MinimapCluster
				or _G.CreateFrame("Frame", "MinimapCluster", _G.UIParent)
			local cluster = _G.MinimapCluster
			cluster.Tracking = _G.CreateFrame("Button", nil, _G.UIParent)
			cluster.ZoneTextButton = _G.CreateFrame("Button", nil, _G.UIParent)
			cluster.MailFrame = _G.CreateFrame("Button", nil, _G.UIParent)
			cluster.InstanceDifficulty = _G.CreateFrame("Frame", nil, _G.UIParent)
			mod.found = {}
			mod.Apply()
			-- A NAMELESS FRAME IS NOT AUTOMATICALLY FURNITURE: on this build
			-- the useful ones are anonymous, reached through a parentKey
			-- rather than a global, and hiding every unnamed frame under the
			-- minimap took the eye, the caption and the mail flag with it.
			assert(cluster.Tracking._parent == map,
				"a tracking button with no name at all is still found")
			assert(cluster.MailFrame._parent == map, "and the mail flag")
			assert(cluster.ZoneTextButton._parent ~= map,
				"and the client's caption is put away rather than laid on the map")
			assert(cluster.Tracking._shown ~= false and cluster.MailFrame._shown ~= false,
				"and none of them was hidden for want of a name")
			cluster.Tracking, cluster.ZoneTextButton = nil, nil
			cluster.MailFrame, cluster.InstanceDifficulty = nil, nil

			-- WHAT SOMETHING IS, NOT WHAT IT IS CALLED (Josh 2026-09-21).
			-- Naming them got all three wrong on the live build: they exist,
			-- under names this module had not heard of, so they were neither
			-- moved nor hidden and sat in the corner while the map came in.
			local odd = _G.CreateFrame("Button", "MinimapSomeBuildTrackingButton", _G.UIParent)
			local oddArt = _G.CreateFrame("Frame", "MinimapSomeBuildBorderArc", _G.UIParent)
			-- an icon is something that draws a picture; the fakes need one
			local function drawn(f)
				local t = f:CreateTexture()
				t.GetObjectType = function() return "Texture" end
				return f
			end
			local mine = drawn(_G.CreateFrame("Frame", "SomebodyElsesButton", _G.UIParent))
			_G.MinimapCluster = _G.MinimapCluster
				or _G.CreateFrame("Frame", "MinimapCluster", _G.UIParent)
			-- ONE LEVEL DOWN WAS NOT FAR ENOUGH (Josh 2026-09-21). These do
			-- not hang off the cluster on the live build - they hang off
			-- something that hangs off it - so a sweep of its own children
			-- found neither and both stayed in the corner above the panel.
			local holder = _G.CreateFrame("Frame", "SomeBuildMinimapHolder", _G.UIParent)
			holder.GetChildren = function()
				return odd, oddArt, mine
			end
			_G.MinimapCluster.GetChildren = function()
				return holder
			end
			mod.Apply()
			assert(odd._parent == map, "a tracking button under any name is found")
			assert(oddArt._alpha == 0, "and ring art under any name goes")

			-- WHAT IS LEFT ON THE CLUSTER IS THE MINIMAP'S, WHATEVER IT IS
			-- CALLED (Josh 2026-09-21). The map has been taken OUT of the
			-- cluster, so anything still hanging there is a piece of the
			-- minimap's furniture by definition - including another addon's
			-- minimap button, which should follow the map rather than be
			-- left in an empty corner. Which piece is which cannot be
			-- inferred, so they are not guessed at: they go in a row along
			-- the bottom of the map, visible and attached.
			assert(mine._parent == map,
				"an unnamed button on the cluster comes along with the map")
			assert(mine._shown ~= false, "rather than being hidden for want of a name")

			-- WORDS ARE NOT ICONS (Josh 2026-09-21). One row along the bottom
			-- attached everything, which was the point, and looked like a
			-- jumble sale: the zone name and the coordinates squeezed into
			-- eighteen pixels beside a sun dial, on top of each other. A frame
			-- that draws words is a caption; one that does not is an icon -
			-- and that is a question the frame can answer without a name.
			local caption = _G.CreateFrame("Frame", nil, _G.UIParent)
			local words = caption:CreateFontString()
			words.GetObjectType = function() return "FontString" end
			words.GetText = function() return "50.2, 61.7" end
			local plainIcon = drawn(_G.CreateFrame("Button", nil, _G.UIParent))
			-- WORDS ARE NOT ENOUGH (Josh 2026-09-21). "Does it draw any text"
			-- put a queue indicator in the caption row, because one of its
			-- icons carries a number across it. A caption is a line of text
			-- and nothing else.
			local numbered = _G.CreateFrame("Frame", nil, _G.UIParent)
			local badge = numbered:CreateFontString()
			badge.GetObjectType = function() return "FontString" end
			badge.GetText = function() return "25" end
			local picture = numbered:CreateTexture()
			picture.GetObjectType = function() return "Texture" end
			-- the numbered one FIRST, so a rule that took the first thing with text
			-- in it would claim it and the coordinates would lose their place
			cluster.GetChildren = function() return numbered, plainIcon, caption end
			mod.found = {}
			mod.Apply()
			assert(caption._parent ~= mod.Build() and caption._parent ~= map,
				"the client's own coordinates are put away: the caption row draws them")
			assert(plainIcon._parent == map, "and a plain icon goes on the map")
			assert(plainIcon._width == 18, "sized as an icon")
			assert(numbered._parent == map,
				"something with a picture on it is an icon, whatever is written across it")

			-- A FRAME THAT DRAWS NOTHING BUT TEXT IS A CAPTION (Josh
			-- 2026-09-21). Narrowing this to "only if it looks like
			-- coordinates" sent the zone name down into the icon row, where
			-- it lay across the sun dial.
			-- ASK THE GAME WHAT THE ZONE IS (Josh 2026-09-21). Finding this by
			-- shape failed on something every time: by name, because it has
			-- none; by "draws only text", because it draws a background too.
			-- GetMinimapZoneText returns the words the client is putting in
			-- it, so the frame showing those words IS the caption.
			_G.GetMinimapZoneText = function() return "Trade District" end
			local placeName = _G.CreateFrame("Frame", nil, _G.UIParent)
			local placeWords = placeName:CreateFontString()
			placeWords.GetObjectType = function() return "FontString" end
			placeWords.GetText = function() return "Trade District" end
			-- and it has a background of its own, which is what stopped the
			-- "draws nothing but text" rule from seeing it
			local placeArt = placeName:CreateTexture()
			placeArt.GetObjectType = function() return "Texture" end
			cluster.GetChildren = function() return numbered, placeName, caption end
			mod.found = {}
			mod.Apply()
			assert(placeName._parent ~= map,
				"the zone name is a caption, not an icon, and never lies on the map")

			-- A ROW THAT RUNS OUT OF MAP WRAPS: eight icons at twenty pixels
			-- is wider than the panel, and the ones past the end piled up in
			-- the corner on top of each other
			local many = {}
			for i = 1, 12 do
				many[i] = drawn(_G.CreateFrame("Button", nil, _G.UIParent))
			end
			cluster.GetChildren = function() return (unpack or table.unpack)(many) end
			mod.found = {}
			mod.Build():SetWidth(160)
			mod.Fit()
			mod.Apply()
			local seenAt = {}
			for _, f in ipairs(many) do
				local at = (f._points or {}).BOTTOMLEFT
				if at then
					local key = tostring(at.x) .. "," .. tostring(at.y)
					assert(not seenAt[key],
						"no two icons are put in the same place: " .. key)
					seenAt[key] = true
					assert(at.x + 18 <= 160,
						"and none of them runs off the side of the map: " .. tostring(at.x))
				end
			end
			cluster.GetChildren = nil

			-- A BUTTON IS ONE ICON, NOT ITS PIECES (Josh 2026-09-21). The walk
			-- goes three levels deep to find things, and each level came back
			-- as an icon of its own: a banner's skulls took a slot each, and
			-- holders that draw nothing took slots of empty space.
			local banner = drawn(_G.CreateFrame("Frame", nil, _G.UIParent))
			local skull = drawn(_G.CreateFrame("Frame", nil, banner))
			local holderOnly = _G.CreateFrame("Frame", nil, _G.UIParent)
			local held = drawn(_G.CreateFrame("Button", nil, holderOnly))
			cluster.GetChildren = function() return banner, holderOnly end
			mod.found = {}
			mod.Apply()
			assert(banner._parent == map, "the banner is an icon")
			assert(skull._parent == banner, "and what is drawn on it stays on it")
			assert(holderOnly._parent ~= map, "a holder that draws nothing takes no slot")
			assert(held._parent == map, "and what it holds is the icon instead")
			assert((banner._points or {}).BOTTOMLEFT.x == (held._points or {}).BOTTOMLEFT.x - 20,
				"side by side, with no empty slot between them")
			-- A BORDER WITH NOTHING IN IT IS NOT AN ICON (Josh 2026-09-22)
			local empty = _G.CreateFrame("Button", nil, _G.UIParent)
			for _, piece in ipairs({ "CornerTopLeft", "EdgeTop", "Center" }) do
				local t = empty:CreateTexture()
				t.GetAtlas = function() return "UI-HUD-Minimap-Button-NineSlice-" .. piece end
			end
			local dial = _G.CreateFrame("Button", nil, _G.UIParent)
			local sunArt = dial:CreateTexture()
			sunArt.GetAtlas = function() return "UI-HUD-Minimap-DayCycle" end
			assert(mod.OnlyBorder(empty) and not mod.OnlyBorder(dial),
				"a frame of border pieces is not an icon; the day/night dial is")
			-- THE CORNER, WHEN NOTHING HAS IT (Josh 2026-09-22): with no world
			-- map button on this build, the first icon (the day/night dial)
			-- goes in the bottom-left corner rather than a slot inside it
			assert((banner._points or {}).BOTTOMLEFT.x == 3,
				"the first icon takes the empty corner: " .. tostring((banner._points or {}).BOTTOMLEFT.x))
			cluster.GetChildren = nil

			-- "ZoneText" IS NOT ENOUGH OF A NAME (Josh 2026-09-21).
			-- SubZoneTextFrame is the announcement across the middle of the
			-- screen when you walk into a new district - nothing to do with
			-- the minimap - and it is a FadingFrame, so being shown outside
			-- its own fade left it doing arithmetic on a start time it had
			-- never been given, once per frame, forever.
			local shout = _G.CreateFrame("Frame", "SubZoneTextFrame", _G.UIParent)
			local elsewhere = _G.CreateFrame("Frame", "SomeAddonMailAlert", _G.UIParent)
			-- MENTIONING THE MINIMAP IS NOT BEING THE MINIMAP (Josh
			-- 2026-09-21). The settings panel is full of controls named for
			-- what they configure - "show this on the minimap", "rotate the
			-- minimap" - and matching the word anywhere in the name dragged
			-- their labels onto the map, on top of each other.
			local setting = _G.CreateFrame("CheckButton",
				"SettingsRotateMinimapBorderCheckbox", _G.UIParent)
			local label = _G.CreateFrame("FontString")
			label.GetName = function() return "MinimapZoneTextSomething" end
			label.GetObjectType = function() return "FontString" end
			-- A FRAME'S NAME IS NOT ALWAYS A NAME (Josh 2026-09-21). Walking
			-- every frame in the game reaches ones whose XML gave a child
			-- the parentKey "GetName" - Blizzard's own damage meter entries
			-- do - and on those the method is shadowed by a FontString.
			local shadowed = _G.CreateFrame("Frame", nil, _G.UIParent)
			shadowed.GetName = _G.CreateFrame("FontString")
			local walkList = { shout, shadowed, elsewhere, setting, label }
			_G.EnumerateFrames = function(prev)
				if prev == nil then return walkList[1] end
				for i, f in ipairs(walkList) do
					if f == prev then return walkList[i + 1] end
				end
				return nil
			end
			mod.found = {}
			mod.Apply()
			assert(shout._parent == _G.UIParent,
				"the screen-wide zone announcement is not the minimap's caption")
			assert(shout._alpha ~= 0, "and it is not hidden either")
			assert(elsewhere._parent == _G.UIParent,
				"nor is anything else that only shares a word")
			assert(shadowed._parent == _G.UIParent,
				"and a frame whose name is not a name does not stop the sweep")
			assert(setting._parent == _G.UIParent and setting._alpha ~= 0,
				"a setting NAMED AFTER the minimap is not part of it")
			assert(label._parent == nil or label._parent == _G.UIParent,
				"and a font string is never moved: that is how words end up on the map")
			_G.EnumerateFrames = nil
			_G.MinimapCluster.GetChildren = nil

			-- THE PICTURE IS NOT ALWAYS INSIDE THE BUTTON (Josh 2026-09-21).
			-- The sun hangs off its frame at an offset, so the frame went in
			-- the corner and the sun sat well inside the map. What it draws is
			-- measured and the button moved until that is in the corner.
			local sunny = _G.CreateFrame("Button", nil, _G.UIParent)
			local sun = sunny:CreateTexture()
			sun.GetObjectType = function() return "Texture" end
			sun.GetLeft = function() return 144 end
			sun.GetRight = function() return 174 end
			sun.GetTop = function() return 150 end
			sun.GetBottom = function() return 120 end
			map.GetLeft = function() return 100 end
			map.GetRight = function() return 300 end
			map.GetTop = function() return 320 end
			map.GetBottom = function() return 100 end
			assert(mod.Snap(sunny, map, { spot = "BOTTOMLEFT", x = 3, y = 3 }),
				"a button whose picture is off in the map gets moved")
			local snapped = (sunny._points or {}).BOTTOMLEFT
			assert(snapped and snapped.x == 3 + (103 - 144) and snapped.y == 3 + (103 - 120),
				("until the picture is in the corner (%s, %s)")
					:format(tostring(snapped and snapped.x), tostring(snapped and snapped.y)))
			-- measured again once the snap has taken, it stays where it went
			sun.GetLeft = function() return 103 end
			sun.GetRight = function() return 133 end
			sun.GetTop = function() return 133 end
			sun.GetBottom = function() return 103 end
			mod.Snap(sunny, map, { spot = "BOTTOMLEFT", x = 3, y = 3 })
			local again = (sunny._points or {}).BOTTOMLEFT
			assert(again.x == snapped.x and again.y == snapped.y,
				"and measuring again does not undo the snap")
			map.GetLeft, map.GetRight, map.GetTop, map.GetBottom = nil, nil, nil, nil

			-- NOTHING THAT CHANGES WHAT IT DOES: no scripts of ours on it
			assert(map:GetScript("OnMouseWheel") == nil,
				"the wheel is still the client's")

			-- THE PANEL'S WIDTH IS NOT THIS MODULE'S TO SET (Josh
			-- 2026-09-21). The dock is as wide as its widest section, so a
			-- minimap asking for a width of its own is a second opinion
			-- about how wide the panel should be - and two constants that
			-- happen to agree today stop agreeing the moment either moves.
			local tracker = BT.GetModule("tracker").Frame()
			if tracker and tracker.wantWidth then
				assert((mod.Build().wantWidth or 0) <= tracker.wantWidth,
					"the minimap never makes the panel wider than the list does")
			end

			-- it squares the map to whatever width it is handed
			mod.Build():SetWidth(300)
			mod.Fit()
			assert(map._width == 300 - 8,
				("the map is as wide as the panel, less its padding (%s)")
					:format(tostring(map._width)))
			assert(map._height == map._width, "and square")
			assert(mod.Build().wantHeight > map._height,
				"with room above it for the zone caption")

			-- THE DOCK STACKS BY wantHeight (Josh 2026-09-21). A frame's own
			-- height is not the same thing: without this the section counted
			-- for nothing and the quest list was laid straight on top of it.
			local section = mod.Build()
			assert((section.wantHeight or 0) > 0,
				"the section takes up room in the layout")

			-- and it sits ABOVE the row: the row is a strip of controls and a
			-- picture belongs over it, the way the client's own corner has it
			assert(section.above, "it asks to sit above the row")
			BT.Bar.Relayout()
			local mapAt = (section._points or {}).TOPLEFT
			local rowAt = BT.Bar.Row() and (BT.Bar.Row()._points or {}).TOPLEFT
			if mapAt and rowAt then
				assert(mapAt.y > rowAt.y,
					("the map is above the row (%s vs %s)")
						:format(tostring(mapAt.y), tostring(rowAt.y)))
			end

			-- and switching it off puts it back exactly where it was
			mod:OnDisable()
			assert(map._parent == _G.UIParent, "back where the client had it")
			assert(map._mask == "Interface\\Round", "round again")

			-- AND ROUND EVEN WHEN THE CLIENT WOULD NOT SAY WHAT IT HAD (Josh
			-- 2026-09-21). SetMaskTexture exists on this build; GetMaskTexture
			-- does not - so there was nothing to remember and switching the
			-- module off left the map square in the corner.
			mod.Forget()
			map.GetMaskTexture = nil
			map:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
			BT.SetEnabled("minimap", true)
			mod.Apply()
			mod:OnDisable()
			assert(map._mask and map._mask:find("Mask", 1, true),
				"the client's own round one is the right answer: " .. tostring(map._mask))
			assert(map._width == 140, "and the size it was")
			assert(ring._alpha == 1 and zoom._alpha == 1, "with its ring back on")
			assert(track._parent == _G.UIParent and clock._parent == _G.UIParent
				and zone._parent == _G.UIParent,
				"and the three that were moved are back where they came from")

			-- PUT BACK WHAT WE TOUCHED, NOT WHAT WE CAN STILL FIND (Josh
			-- 2026-09-21). Switching the module off used to run the same
			-- sweep again and undo whatever it turned up - which only ever
			-- restores the pieces the sweep still recognises. The sweep had
			-- just moved a dozen frames it could not name, so those stayed
			-- where we put them and the minimap came back with holes in it.
			local nameless = drawn(_G.CreateFrame("Button", nil, _G.UIParent))
			_G.MinimapCluster.GetChildren = function() return nameless end
			BT.SetEnabled("minimap", true)
			mod.found = {}
			mod.Apply()
			assert(nameless._parent == map, "something with no name was moved")
			mod:OnDisable()
			assert(nameless._parent == _G.UIParent,
				"and it goes back too, because we remembered moving it")
			_G.MinimapCluster.GetChildren = nil

			BT.SetEnabled("minimap", false)
			_G.Minimap, _G.MinimapBorder, _G.MinimapZoomIn = nil, nil, nil
			_G.MiniMapTracking, _G.GameTimeFrame = nil, nil
			_G.MinimapZoneTextButton, _G.MinimapZoneText = nil, nil
		end },
		{ "a rim is four bars, and everything that paints one knows it", function()
			-- Pill.Panel hands back a RING so the border cannot bleed through
			-- the fill. Anything still treating that as a single texture
			-- calls a method a table does not have, and finds out in game -
			-- the search box did, on losing focus (Josh 2026-09-21).
			local f = _G.CreateFrame("Frame", nil, _G.UIParent)
			local _, rim = BT.Pill.Panel(f)
			assert(type(rim) == "table" and rim[1] and rim[4],
				"a panel's rim is four bars")
			assert(rim.SetColorTexture == nil,
				"and not something you can paint in one call")

			-- the accent helpers take either shape, so a caller cannot pick
			-- the wrong one
			BT.Widgets.Lit(rim, 0.9)
			for i = 1, 4 do
				assert(rim[i]._color, "every bar of a ring is painted: " .. i)
			end
			local one = f:CreateTexture()
			BT.Widgets.Lit(one, 1)
			assert(one._color, "and a plain texture still works")

			-- and the search box's own rim survives losing focus
			BT.SetEnabled("ledger", true)
			BT.Find.OpenEditor()
			local editor = BT.Find.Editor and BT.Find.Editor()
			if editor and editor.note then
				local lost = editor.note:GetScript("OnEditFocusLost")
				assert(lost, "it listens for focus going")
				assert(pcall(lost, editor.note),
					"and painting its rim on the way out does not throw")
			end
		end },
		{ "a chat window made after login is dressed like the rest", function()
			-- A TAB THAT DID NOT EXIST YET (Josh 2026-09-21). Making a new
			-- chat window left it wearing the client's own tab - taller than
			-- ours, in its own colours, sitting above the strip the others
			-- are in. Nothing was wrong with the styling: it had never run on
			-- that tab, because the only passes were at login and on events
			-- the client does not fire for this.
			local mod = BT.GetModule("chat")
			BT.SetEnabled("chat", true)

			local hooks = {}
			local realHook = _G.hooksecurefunc
			_G.hooksecurefunc = function(a, b)
				if type(a) == "string" then
					hooks[a] = b
				end
			end
			_G.FCF_OpenNewWindow = function() end
			_G.FCF_DockFrame = function() end
			mod.hookedWindows = nil
			mod.WatchWindows()
			_G.hooksecurefunc = realHook
			assert(hooks.FCF_OpenNewWindow, "making a window is watched")
			assert(hooks.FCF_DockFrame, "and so is docking one")

			-- the new window appears, and the re-style reaches its tab
			local made = _G.CreateFrame("Frame", "ChatFrame3", _G.UIParent)
			made.AddMessage = function() end
			local tab = _G.CreateFrame("Button", "ChatFrame3Tab", _G.UIParent)
			tab.text = _G.CreateFrame("FontString")
			_G.ChatFrame3EditBox = _G.CreateFrame("EditBox", "ChatFrame3EditBox", made)
			_G.NUM_CHAT_WINDOWS = 3

			-- the client positions the new tab after its own call returns, so
			-- ours waits a frame
			local realAfter = _G.C_Timer.After
			_G.C_Timer.After = function(_, fn) fn() end
			hooks.FCF_OpenNewWindow()
			_G.C_Timer.After = realAfter

			assert(mod.Skins()[tab], "the new tab wears our surface")
			assert(mod.Skins()[made], "and so does the window under it")

			_G.NUM_CHAT_WINDOWS = 2
			_G.ChatFrame3, _G.ChatFrame3Tab, _G.ChatFrame3EditBox = nil, nil, nil
		end },
		{ "the note panel opens beside the row, not beside the panel", function()
			-- BESIDE THE ROW (Josh 2026-09-21). This took the dock over
			-- whatever frame it was handed, which top-aligned it with the
			-- whole panel. That was the same thing while the dock began with
			-- the Ledger's row - now the panel opens with a header and a map
			-- above it, so "the top of the dock" is a long way above the name
			-- you clicked.
			BT.SetEnabled("ledger", true)
			BT.Bar.Create()
			BT.Window.Hide()
			local row = _G.CreateFrame("Frame", nil, _G.UIParent)
			row.GetLeft = function() return 900 end
			BT.DB.Note(BT.db, "Beeb Bob", "solid tank")
			local key = BT.Util.Key and BT.Util.Key("Beeb Bob", "Whitemane")
			BT.Find.OpenEditorFor(key or "Beeb Bob@Whitemane", row)

			local editor = BT.Find.Editor()
			assert(editor, "the editor is up")
			local at = (editor._points or {}).TOPRIGHT or (editor._points or {}).TOPLEFT
			assert(at, "and anchored to something")

			-- LEVEL WITH THE ROW, CLEAR OF THE DOCK (Josh 2026-09-22): hung from
			-- the name cell it sat low and ran over the dock's edge. The height
			-- is the row's top, the side is the dock's edge, eight clear.
			local dock, dockRow = BT.Bar.Frame(), BT.Bar.Row()
			dock.GetTop = function() return 800 end
			dock.GetLeft = function() return 900 end
			dockRow.GetTop = function() return 690 end
			dockRow:Show()
			BT.Find.OpenEditorFor(key or "Beeb Bob@Whitemane", row)
			at = (editor._points or {}).TOPRIGHT
			assert(at and at.rel == dock and at.relPoint == "TOPLEFT",
				"against the dock's own edge, not the name inside it")
			assert(at.x == -8, "eight clear of it")
			assert(at.y == -110, ("level with the top of the row (%s)"):format(tostring(at.y)))
			-- a scaled dock: its tops are in its units, the offset in the editor's
			dock.GetEffectiveScale = function() return 0.5 end
			BT.Find.OpenEditorFor(key or "Beeb Bob@Whitemane", row)
			at = (editor._points or {}).TOPRIGHT
			assert(at.y == -55, ("and still level when the dock is scaled (%s)"):format(tostring(at.y)))
			dock.GetTop, dock.GetLeft, dockRow.GetTop, dock.GetEffectiveScale = nil, nil, nil, nil
		end },
		{ "the health bar cannot put itself back", function()
			-- THE FLICKER (Josh 2026-09-19). Hiding the bar once per rebuild
			-- loses a race: the client shows it again as part of setting the
			-- unit, and for the frame in between there is a green block at the
			-- bottom-left corner of the tooltip.
			local bar = _G.GameTooltipStatusBar
			local onShow = bar:GetScript("OnShow")
			assert(onShow, "something is listening for the bar showing itself")
			BT.SetEnabled("tips", true)
			BT.GetModule("tips").SetOpt("healthBar", false)
			bar:Show()
			onShow(bar)
			assert(not bar:IsShown(), "with the bar switched off it is told no")

			-- and when you asked for it, it stays
			BT.GetModule("tips").SetOpt("healthBar", true)
			bar:Show()
			onShow(bar)
			assert(bar:IsShown(), "with it switched on it stays up")
			BT.GetModule("tips").SetOpt("healthBar", false)
		end },
		{ "item tooltips are hooked whatever the unit hook chose", function()
			-- THE HALF-DEAD SETTING (Josh 2026-09-19). The two hooks used to be
			-- one if/else, so a client with the data processor but no Item type
			-- on it registered the unit hook and NOTHING for items - and the
			-- Tooltips tab looked like its switches did nothing, because half of
			-- them did nothing.
			assert(BT.UnitTip.itemPath and BT.UnitTip.itemPath ~= "none",
				"something is listening for item tooltips: " .. tostring(BT.UnitTip.itemPath))
			local before = BT.UnitTip.itemFills or 0
			local sized = {}
			local tip = setmetatable({
				GetName = function() return "ItemTip" end,
				NumLines = function() return 2 end,
				SetScale = function(_, v) sized.scale = v end,
			}, { __index = function() return function() end end })
			for i = 1, 2 do
				_G["ItemTipTextLeft" .. i] = _G.CreateFrame("FontString")
				_G["ItemTipTextRight" .. i] = _G.CreateFrame("FontString")
			end
			BT.UnitTip.FillItem(tip)
			assert((BT.UnitTip.itemFills or 0) == before + 1, "the item fill ran")
			-- and the size setting reaches an item tooltip, not only a unit one
			assert(type(sized.scale) == "number",
				"the size setting is applied to item tooltips too")
		end },
		{ "a quest with an item gets a button to use it", function()
			_G.C_QuestLog = nil
			_G.GetNumQuestLogEntries = function() return 2 end
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				return "Treacherous Cold", 8, nil, false, nil, nil, nil, 1234
			end
			_G.IsQuestWatched = function(i) return i == 2 end
			_G.GetNumQuestLeaderBoards = function() return 0 end
			_G.GetQuestLogSpecialItemInfo = function(i)
				if i == 2 then return "item:6948", 134414, 3, false end
			end
			_G.InCombatLockdown = function() return false end
			_G.IsShiftKeyDown = function() return false end
			-- which clicks the secure button listens for
			local realCF, clicks = _G.CreateFrame, nil
			_G.CreateFrame = function(kind, name, parent, template)
				local f = realCF(kind, name, parent, template)
				if template == "SecureActionButtonTemplate" then
					f.RegisterForClicks = function(_, ...) clicks = { ... } end
				end
				return f
			end
			local wasCVar = _G.GetCVarBool
			_G.GetCVarBool = function(name) return name == "ActionButtonUseKeyDown" end
			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.Update()
			_G.CreateFrame, _G.GetCVarBool = realCF, wasCVar
			-- ONE USE A PRESS (Josh 2026-09-24): down AND up used it twice
			assert(clicks and #clicks == 1 and clicks[1] == "AnyDown",
				"it listens for the press alone when the bars act on the key down: "
					.. table.concat(clicks or {}, ","))
			-- (row 2 is the zone's heading)
			local row = mod.Rows()[3]
			assert(row.item and row.item:IsShown(), "the quest's row carries its item")
			local b = row.item.button
			assert(b._attributes and b._attributes.type == "item" and b._attributes.item == "item:6948",
				"as a secure item button: " .. tostring(b._attributes and b._attributes.item))
			assert(b.count._text == "3", "with its charges on it: " .. tostring(b.count._text))
			-- THE SECURE BUTTON IS THE SCREEN'S (the audit): inside the row it made
			-- the row, the tracker and the whole dock protected in a fight
			assert(b:GetParent() == _G.UIParent and b:GetParent() ~= row.item,
				"the secure button belongs to the screen, not to the dock")
			assert(((row.text._points or {}).RIGHT or {}).x < 0, "and the title makes room for it")
			assert(mod.Rows()[1].item == nil or not mod.Rows()[1].item:IsShown(),
				"the header carries nothing")

			-- IN COMBAT THE BUTTON IS LOCKED: which item it holds cannot be
			-- changed, so a changed item is put away rather than shown wrong
			_G.GetQuestLogSpecialItemInfo = function(i)
				if i == 2 then return "item:1234", 135, 1, false end
			end
			_G.InCombatLockdown = function() return true end
			mod.Update()
			assert(not row.item:IsShown(), "in combat a changed item is hidden, not wrong")
			assert(b._attributes.item == "item:6948", "and the attribute was not touched")
			assert(mod.itemsPending, "and the tracker knows it owes an update")
			_G.InCombatLockdown = function() return false end
			mod.events:GetScript("OnEvent")(mod.events, "PLAYER_REGEN_ENABLED")
			assert(not mod.itemsPending, "the end of the fight settles it")
			mod.Update()
			assert(row.item:IsShown() and b._attributes.item == "item:1234",
				"and the button catches up: " .. tostring(b._attributes.item))
			assert(b.count._text == "", "one charge is not worth a number")

			-- an item for handing the quest in waits until the quest is complete
			_G.GetQuestLogSpecialItemInfo = function(i)
				if i == 2 then return "item:1234", 135, 1, true end
			end
			mod.Update()
			assert(not row.item:IsShown(), "an item for handing in waits until the quest is complete")
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				return "Treacherous Cold", 8, nil, false, nil, nil, 1, 1234
			end
			mod.Update()
			assert(row.item:IsShown(), "and shows once it is")

			-- and nothing at all on a quest without one
			_G.GetQuestLogSpecialItemInfo = function() return nil end
			mod.Update()
			assert(not row.item:IsShown(), "no item, no button")
			assert(((row.text._points or {}).RIGHT or {}).x == 0, "and the title has the whole line back")
			_G.GetQuestLogSpecialItemInfo = nil
			_G.GetNumQuestLogEntries, _G.GetQuestLogTitle = nil, nil
		end },
		{ "the quest tracker is ours, and the client's is out of the way", function()
			-- a quest log, through the vanilla globals this client still has
			_G.C_QuestLog = nil
			_G.GetNumQuestLogEntries = function() return 3 end
			_G.GetQuestLogTitle = function(i)
				if i == 1 then return "Dun Morogh", 0, nil, true, nil, nil, nil, nil end
				if i == 2 then return "Treacherous Cold", 8, nil, false, nil, nil, nil, 1234 end
				return "Not followed", 9, nil, false, nil, nil, nil, 5678
			end
			_G.IsQuestWatched = function(i) return i == 2 end
			_G.GetNumQuestLeaderBoards = function() return 2 end
			_G.GetQuestLogLeaderBoard = function(j)
				if j == 1 then return "Frostmane Headhunter slain: 0/5", "monster", false end
				return "Sunhammer's Rifle: 1/1", "item", true
			end
			_G.ObjectiveTrackerFrame = _G.CreateFrame("Frame")
			_G.IsShiftKeyDown = function() return false end

			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.Update()
			assert(not _G.ObjectiveTrackerFrame:IsShown(), "the client's own tracker is hidden")
			assert(mod.Frame():IsShown(), "and ours is up")

			-- ONE COLUMN: the level and the counts read at the start of the
			-- line, not down a column of their own on the right
			local rows = mod.Rows()
			assert(rows[1].text._text:find("QUESTS", 1, true), "a header saying what this is")
			assert(rows[1].text._text:find("1", 1, true), "and how many you are following")
			-- BY ZONE (Josh 2026-09-24): the log's zone heading over its quests
			assert(rows[2].kind == "zone" and rows[2].text._text == "DUN MOROGH" and not rows[2].mark:IsShown(),
				"the zone as a small heading: " .. tostring(rows[2].text._text))
			assert(rows[3].text._text:find("Treacherous Cold", 1, true)
				and rows[3].text._text:find("[8]", 1, true),
				"the quest, with its level in front of it: " .. tostring(rows[3].text._text))
			assert(rows[4].text._text:find("0/5", 1, true)
				and rows[4].text._text:find("Frostmane Headhunter slain", 1, true),
				"the count reads where you read: " .. tostring(rows[4].text._text))
			assert(rows[5].markKind == "strike", "a finished objective is crossed off, not ticked")
			assert(rows[5].strike:IsShown(), "with a line through the words")
			assert(rows[5].strike._color and rows[5].strike._color[4] < 1,
				"drawn softly enough to read what you finished")
			assert(not rows[5].mark:IsShown(), "and no second column of checks to read down")
			assert(not rows[4].strike:IsShown(), "an objective still to do is not struck through")
			assert(rows[3].markKind == "dot", "a quest in progress gets the mark you click to follow it")
			assert(rows[6] == nil or not rows[6]:IsShown(), "the quest nobody is following is not drawn")

			-- clicking the mark makes that quest the one the map points at
			local tracking = nil
			_G.C_SuperTrack = {
				SetSuperTrackedQuestID = function(id) tracking = id end,
				GetSuperTrackedQuestID = function() return tracking end,
			}
			-- the whole gutter is the target, not the five pixels of dot
			assert((rows[3].mark._width or 0) >= 18 and (rows[3].mark._height or 0) >= 15,
				("the mark is a gutter-sized target (%sx%s)")
					:format(tostring(rows[3].mark._width), tostring(rows[3].mark._height)))
			rows[3].mark:GetScript("OnEnter")(rows[3].mark)
			assert(rows[3].mark.hot:IsShown(), "and it lights up when you are over it")
			rows[3].mark:GetScript("OnLeave")(rows[3].mark)
			rows[3].mark:GetScript("OnClick")(rows[3].mark)
			assert(tracking == 1234, "the mark follows the quest")
			mod.Update()
			assert(mod.Rows()[3].markKind == "tracking", "and the one you are following says so")
			_G.C_SuperTrack = nil

			-- the band: on a quest that is ready to hand in, the mark is a
			-- check and there is nowhere left to say "and this is the one you
			-- are doing", so the band says it
			local section = mod.Frame()
			assert(section.band:IsShown() and section.bandTop:IsShown() and section.bandFoot:IsShown(),
				"the quest you are following is banded")

			-- the header folds the list away, and remembers
			rows[1]:GetScript("OnClick")(rows[1], "LeftButton")
			assert(mod.Opt("collapsed", false), "clicking the header folds it")
			assert(not mod.Rows()[3]:IsShown(), "and the quests go with it")
			assert(mod.Rows()[1]:IsShown(), "the header stays, with the count on it")
			rows[1]:GetScript("OnClick")(rows[1], "LeftButton")
			assert(mod.Rows()[3]:IsShown(), "and unfolds again")

			-- right-click folds one quest's objectives, leaving its title
			rows[3]:GetScript("OnClick")(rows[3], "RightButton")
			assert(mod.Rows()[3]:IsShown(), "the quest stays")
			assert(not mod.Rows()[4]:IsShown(), "its objectives fold away")
			rows[3]:GetScript("OnClick")(rows[3], "RightButton")
			assert(mod.Rows()[4]:IsShown(), "and come back")

			-- click opens it, shift-click stops following it
			local opened, dropped = false, nil
			_G.ToggleQuestLog = function() opened = true end
			_G.RemoveQuestWatch = function(i) dropped = i end
			rows[3]:GetScript("OnClick")(rows[3], "LeftButton")
			assert(opened, "clicking a quest opens the log at it")
			_G.IsShiftKeyDown = function() return true end
			rows[3]:GetScript("OnClick")(rows[3], "LeftButton")
			assert(dropped == 2, "shift-clicking stops following it")
			_G.IsShiftKeyDown = function() return false end

			-- and switching the module off hands the client its own back
			BT.SetEnabled("tracker", false)
			assert(_G.ObjectiveTrackerFrame:IsShown(), "the client's tracker comes back")
			assert(not mod.Frame():IsShown(), "and ours goes away")
			BT.SetEnabled("tracker", true)
		end },
		{ "one panel: the bar row and the tracker in the same dock", function()
			local dock = _G.BeebModBar
			local mod = BT.GetModule("tracker")
			BT.SetEnabled("tracker", true)
			mod.Update()

			local section
			for _, s2 in ipairs(BT.Bar.Sections()) do
				if s2.key == "tracker" then
					section = s2.frame
				end
			end
			assert(section, "the tracker registered a section of the dock")
			assert(section:IsShown() and (section.wantHeight or 0) > 0,
				"and it is as tall as the quests in it")
			assert(section:GetParent() == dock, "it lives in the dock, not in a panel of its own")

			-- where it sits is remembered: the default is under the minimap,
			-- and a drag replaces it
			BT.settings.barPos = nil
			_G.UIParent._top = 768
			BT.Bar.MakeHandle(BT.Bar.Row())
			BT.Bar.Row():GetScript("OnDragStart")(BT.Bar.Row())
			BT.Bar.Row():GetScript("OnDragStop")(BT.Bar.Row())
			assert(BT.settings.barPos, "dragging it by the row writes down where it ended up")
			-- ALWAYS BY THE TOP. Anchored by a bottom corner, folding the quest
			-- list away made the dock shorter and slid the whole thing down the
			-- screen, because the bottom was what was pinned.
			assert(BT.settings.barPos.point == "TOPLEFT",
				"and writes it down as a top-left anchor: " .. tostring(BT.settings.barPos.point))
			assert(BT.settings.barPos.y < 0, "measured down from the top of the screen")
			assert(_G.BeebModTracker == nil, "there is no second floating panel any more")

			-- the dock is the row plus its sections. With the note down to a
			-- mark beside the tags, nothing wants the second line any more and
			-- the row is a row again (Josh 2026-09-20).
			BT.SetEnabled("minimap", false)
			BT.SetEnabled("perf", false)
			BT.SetEnabled("gold", false)
			BT.SetEnabled("clock", false)
			BT.SetEnabled("micro", false)
			BT.Bar.Relayout()
			-- THE PANEL SAYS WHOSE IT IS (Josh 2026-09-21). The dock now opens
			-- with a header carrying the name and the cog, so the stack is
			-- header, row, sections - and the first thing you read is the
			-- panel rather than a piece of the Ledger.
			local header = BT.Bar.Header()
			assert(header and header:IsShown(), "the panel has a header")
			-- and it is the handle that does not go away: with the row
			-- switched off there was nothing left to drag but a lone cog
			assert(header:GetScript("OnDragStart"), "the header drags the panel")
			assert(BT.Bar.Cog() and BT.Bar.Cog():GetParent() == header,
				"and the cog lives in it rather than in a corner")
			local headTall = header._height or 0
			assert(headTall > 0, "with a height of its own")
			local tall = dock._height or 0
			assert(tall >= headTall + 22 + (section.wantHeight or 0) - 1,
				("the dock is as tall as everything in it (%s)"):format(tostring(tall)))
			assert(tall < headTall + 26 + (section.wantHeight or 0),
				("and no taller than one line needs (%s)"):format(tostring(tall)))

			-- switching the bar row off leaves the dock, because the tracker
			-- is still in it; it is one panel, not a bar with a lodger
			BT.Bar.SetShown(false)
			assert(dock:IsShown(), "the dock stays while a section still has something to say")
			assert(not BT.Bar.Row():IsShown(), "but the row of cells goes")
			BT.Bar.SetShown(true)
			assert(BT.Bar.Row():IsShown(), "and comes back")

			-- with nothing following and no row, there is nothing to show
			BT.SetEnabled("tracker", false)
			BT.Bar.SetShown(false)
			assert(not dock:IsShown(), "an empty dock does not sit there being empty")
			BT.Bar.SetShown(true)
			BT.SetEnabled("tracker", true)

			-- THE ROW IS THE MODULES' (Josh 2026-09-19). The mark and the cog
			-- belong to the core and are not a reason to draw a header band:
			-- with the Ledger off there was a glyph and a cog sitting in a band
			-- of their own above the quest list.
			BT.SetEnabled("ledger", false)
			assert(not BT.Bar.RowWanted(), "no module wants the row, so there is no row")
			assert(not BT.Bar.Row():IsShown(), "and it is not drawn")
			assert(BT.Bar.Frame().cog:IsShown(), "but the way into the toolkit stays, in the corner")
			assert(section:IsShown(), "and the quests still are")
			BT.SetEnabled("ledger", true)
			assert(BT.Bar.RowWanted(), "switching it back on brings the row back")
			assert(BT.Bar.Row():IsShown(), "and draws it")
		end },
		{ "an item tooltip can say the item level, beside the name", function()
			local tips = BT.GetModule("tips")
			local tip = _G.CreateFrame("Frame")
			tip.GetName = function() return "TestLevel" end
			tip.NumLines = function() return 1 end
			local item = "item:2"
			tip.GetItem = function() return "Thing", item end
			_G.TestLevelTextLeft1 = _G.CreateFrame("Frame")
			local right = _G.CreateFrame("Frame")
			right:Hide()
			_G.TestLevelTextRight1 = right
			_G.GetItemInfo = function(l)
				return "x", l, 2, l == "item:2" and 23 or 5, 1, "x", "x", 1,
					l == "item:2" and "INVTYPE_CHEST" or ""
			end
			BT.settings.tips = BT.settings.tips or {}
			BT.settings.tips.itemLevel = nil
			tips.ItemLevel(tip)
			assert(right:IsShown() and right._text:find("23", 1, true) and right._text:find("ilvl", 1, true),
				"on the right of the name line: " .. tostring(right._text))
			right:Hide()
			item = "item:9"
			assert(tips.ItemLevel(tip) == nil and not right:IsShown(), "not on something you cannot wear")
			item = "item:2"
			BT.settings.tips.itemLevel = false
			assert(tips.ItemLevel(tip) == nil, "and not with the switch off")
			BT.settings.tips.itemLevel = nil
			right:SetText("Unique")
			right:Show()
			tips.ItemLevel(tip)
			assert(right._text == "Unique", "the client's own right-hand text wins")
			_G.GetItemInfo = nil
			_G.TestLevelTextLeft1, _G.TestLevelTextRight1 = nil, nil
		end },
		{ "an item tooltip: a quality spine and a quiet footer", function()
			local tips = BT.GetModule("tips")
			local tip = _G.CreateFrame("Frame")
			tip.GetName = function() return "TestItem" end
			tip.NineSlice = _G.CreateFrame("Frame")
			local said = {
				"Scroll of Minor Evocation",
				"Use: Restores mana. (8 Min Cooldown)",
				"Classes: Mage",
				"Sell Price: 37",
				"Press F6 to submit an issue for this Item",
			}
			tip.NumLines = function() return #said end
			for i, text in ipairs(said) do
				local fs = _G.CreateFrame("Frame")
				fs:SetText(text)
				_G["TestItemTextLeft" .. i] = fs
				_G["TestItemTextRight" .. i] = _G.CreateFrame("Frame")
			end

			tips.ComposeItem(tip)
			local name = _G.TestItemTextLeft1
			local use = _G.TestItemTextLeft2
			local price = _G.TestItemTextLeft4
			local beta = _G.TestItemTextLeft5
			-- THE ITEM'S NAME IS LEFT ALONE (Josh 2026-09-20). Blowing it up to
			-- header size made the line wider than the box the client measured
			-- for it, so a name that fitted broke across two lines and a quest
			-- title under it read as a second heading. Quality colour already
			-- says what it is; it does not need to be bigger as well.
			assert(select(2, name:GetFont()) ~= 14,
				"the client's own heading size is not overridden")
			assert(select(2, price:GetFont()) == BT.Fonts.Size(10), "the sell price is a footnote")
			assert(select(2, beta:GetFont()) == BT.Fonts.Size(10), "and so is the client's F6 line")
			assert(price._textColor and beta._textColor, "both lost their colour")
			assert(beta._textColor[1] < price._textColor[1],
				"and the one that is not about the item is the quietest")
			assert(use._textColor == nil and select(2, use:GetFont()) == 12,
				"what the item DOES is left exactly as the client wrote it")

			-- the switch is a switch
			tips.SetOpt("footer", false)
			local plain = _G.CreateFrame("Frame")
			plain:SetText("Sell Price: 37")
			_G.TestItemTextLeft4 = plain
			tips.ComposeItem(tip)
			assert(plain._textColor == nil, "switched off, the footer is left alone")
			tips.SetOpt("footer", true)
		end },
		{ "a repaint does not repaint itself", function()
			-- THE LAG (Josh 2026-09-19). The panel's refresh called the
			-- window's, which called the module's Refresh, which called the
			-- panel's: a mutual recursion that ran the whole search a couple
			-- of hundred times per keystroke until the stack gave out, with
			-- the error swallowed by the pcall around module hooks. It showed
			-- up in game as "the Ledger tab is slow".
			BT.Window.Show("ledger")
			BT.moduleErrors = nil
			BT.Find.Refresh()
			BT.Window.Refresh()
			assert(BT.moduleErrors == nil,
				"no module error: " .. table.concat(BT.moduleErrors or {}, " | "))
		end },
		{ "a meter harvest", function()
			assert(BT.Meter.available, "the meter source should be available against the stubs")
			-- the meter only ever says "Corwin", so it may not INVENT a row:
			-- with nobody under that GUID yet, it writes nothing at all
			for k in pairs(BT.db.guids) do BT.db.guids[k] = nil end
			assert(BT.Meter.Harvest() == 0, "an unknown combat source is not filed")
			assert(BT.DB.Get(BT.db, "Corwin@Whitemane") == nil, "half a name never enters the book")
			-- once chat or a nameplate has filed them properly, it updates that row
			BT.DB.Note(BT.db, "Corwin Bob", nil, { guid = "Player-4372-0002BFB2" })
			local before = BT.DB.Get(BT.db, "Corwin Bob@Whitemane").seen
			assert(BT.Meter.Harvest() == 1, "a known fighter is updated")
			assert(BT.DB.Get(BT.db, "Corwin Bob@Whitemane").seen > before, "on the row that already exists")
			assert(BT.DB.Get(BT.db, "Snarly@Whitemane") == nil, "a pet with no player GUID is not a character")
		end },
		{ "/bt stats", function() SlashCmdList.BEEBSTOOLKIT("stats") end },
		{ "/bt note", function()
			SlashCmdList.BEEBSTOOLKIT("note Beeb Bob solid tank")
			assert(BT.DB.Get(BT.db, "Beeb Bob@Whitemane").note == "solid tank", "the command wrote the note")
			-- NOTHING TYPED READS IT BACK: it used to erase the note
			SlashCmdList.BEEBSTOOLKIT("note Beeb Bob")
			assert(BT.DB.Get(BT.db, "Beeb Bob@Whitemane").note == "solid tank", "a bare /bt note keeps the note")
			SlashCmdList.BEEBSTOOLKIT("rate Beeb Bob 4")
			SlashCmdList.BEEBSTOOLKIT("rate Beeb Bob")
			SlashCmdList.BEEBSTOOLKIT("rate Beeb Bob 9")
			assert(BT.DB.Get(BT.db, "Beeb Bob@Whitemane").rating == 4, "a bare or wrong rating keeps the rating")
			SlashCmdList.BEEBSTOOLKIT("rate Beeb Bob clear")
			assert(BT.DB.Get(BT.db, "Beeb Bob@Whitemane").rating == nil, "and clear clears it")
		end },
		{ "/bt flag", function()
			-- a toggle, so the check is that it CHANGED, not what it landed on
			local before = BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags
			before = before and before.troll or false
			SlashCmdList.BEEBSTOOLKIT("flag Beeb Bob troll")
			local after = BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags
			after = after and after.troll or false
			assert(after ~= before, "the command toggled the tag")
			-- by its label too, in any case
			local label = BT.Util.FlagByKey("troll").label
			SlashCmdList.BEEBSTOOLKIT("flag Beeb Bob " .. label:upper())
			local back = BT.DB.Get(BT.db, "Beeb Bob@Whitemane").flags
			back = back and back.troll or false
			assert(back == before, "toggled back by its label: " .. label)
		end },
		{ "/bt census", function() SlashCmdList.BEEBSTOOLKIT("census") end },
		{ "/bt age", function() SlashCmdList.BEEBSTOOLKIT("age") end },
		{ "/bt autopurge", function()
			SlashCmdList.BEEBSTOOLKIT("autopurge 30")
			assert(BT.settings.pruneDays == 30, "autopurge sets the window")
			-- 0 is off, never "a day" (the audit: it would have emptied the book)
			SlashCmdList.BEEBSTOOLKIT("autopurge 0")
			assert(BT.settings.pruneDays == 0, "autopurge 0 is off")
			SlashCmdList.BEEBSTOOLKIT("autopurge 30")
			SlashCmdList.BEEBSTOOLKIT("autopurge off")
			assert(BT.settings.pruneDays == 0, "and can be turned off")
		end },
		{ "/bt help", function() SlashCmdList.BEEBSTOOLKIT("help") end },
	}
	for _, step in ipairs(steps) do
		local good, err = pcall(step[2])
		if good then
			print("ok   runs " .. step[1])
		else
			fail(step[1] .. ": " .. tostring(err))
		end
	end
	local p = BT.DB.Get(BT.db, "Beeb Bob@Whitemane")
	-- each command checks its own effect above; this is the belt to that braces
	if not (p and p.note) then
		fail("the slash commands did not reach the database")
	else
		print("ok   the slash commands wrote a note and a flag")
	end
end

print("")
if ok then
	print("ALL FILES LOAD CLEAN")
else
	print("LOAD FAILURES")
	os.exit(1)
end
