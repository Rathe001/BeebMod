-- The game's dropdown and right-click menus, in the toolkit's clothes
-- (Josh 2026-09-24).
--
-- The bag window's Sorting menu, the chat's cog, the meter's dropdowns, a
-- right-click on a player: every one of them opens in the client's gold-and-
-- stone menu art, out of windows that are otherwise ours. This client draws
-- them all from one menu system, so one module dresses all of them.
--
-- SAME BARGAIN AS THE REST. Nothing is reimplemented: every entry, every tick
-- and every submenu is the client's and does what it did. The menu's art
-- comes off, our surface and shadow go on, a gold heading takes the panel's
-- text; the light under the pointer and the ticks and radio marks stay the
-- client's, so what you are pointing at and what is chosen still show.
--
-- FOUND TWO WAYS, because the names are this build's to choose:
--   * a menu opened through the manager (Menu.GetManager():OpenMenu and
--     OpenContextMenu) is dressed a frame after it opens, with its entries
--   * a menu made at all - a submenu included - is dressed as its look is
--     built (every global *Menu*Style*Mixin with a Generate), before anything
--     of it is drawn
-- /bt menusdump writes the next menu you open into the saved file, for when
-- one comes out wrong.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Menus/Menus.lua")

local U = BT.Util

local M = BT.Module({
	key = "menus",
	group = "windows",
	onPage = "allmenus",
	title = "Dropdown menus",
	blurb = "the game's right-click and dropdown menus, flat like the rest",
	order = 57.5,
})

-- the client's to show, whatever size it is: the light under the pointer,
-- the tick on a chosen entry, the dot of a radio, the arrow to a submenu
local KEEP = { "highlight", "hover", "select", "check", "radio", "arrow", "expand", "mouseover" }

local function keep(r)
	local ok, atlas = pcall(function() return r.GetAtlas and r:GetAtlas() end)
	if not (ok and type(atlas) == "string" and atlas ~= "") then
		return false
	end
	atlas = atlas:lower()
	for _, word in ipairs(KEEP) do
		if atlas:find(word, 1, true) then
			return true
		end
	end
	return false
end
M.Keep = keep

local dresser = BT.Furniture.New({ panelAlpha = 0.97, keep = keep })
M.Dresser = dresser

-- a menu, dressed: our surface under it, its art off, its words ours
local dressed = setmetatable({}, { __mode = "k" })
function M.DressMenu(menu)
	if not (type(menu) == "table" and menu.CreateTexture and BT.Enabled("menus")) then
		return false
	end
	local ok, err = pcall(dresser.DressRoot, dresser, menu)
	if not ok then
		BT.Err("menus: " .. tostring(err))
		return false
	end
	dressed[menu] = true
	-- the next one opened, written down (see /bt menusdump)
	if M.dumpNext then
		M.dumpNext = false
		M.Dump(menu)
	end
	return true
end

-- the one the manager says is open, and the entries it has just made
function M.AfterOpen()
	local menu = M.OpenMenu()
	if not menu then
		return false
	end
	M.DressMenu(menu)
	if C_Timer and C_Timer.After then
		-- its entries are laid out as it shows: once more when they are
		C_Timer.After(0, function()
			M.DressMenu(M.OpenMenu() or menu)
		end)
	end
	return true
end

function M.OpenMenu()
	local manager = _G.Menu and type(_G.Menu.GetManager) == "function" and _G.Menu.GetManager()
	if type(manager) ~= "table" or type(manager.GetOpenMenu) ~= "function" then
		return nil
	end
	local ok, menu = pcall(manager.GetOpenMenu, manager)
	return ok and type(menu) == "table" and menu or nil
end

-- The hooks, once: on the manager, and on every menu look the client has.
function M.Hook()
	if M.hooked or type(hooksecurefunc) ~= "function" then
		return M.hooked
	end
	M.hooked = true
	M.found = {}
	local manager = _G.Menu and type(_G.Menu.GetManager) == "function" and _G.Menu.GetManager()
	if type(manager) == "table" then
		for _, name in ipairs({ "OpenMenu", "OpenContextMenu" }) do
			if type(manager[name]) == "function" then
				pcall(hooksecurefunc, manager, name, function()
					if BT.Enabled("menus") then
						M.AfterOpen()
					end
				end)
				M.found[#M.found + 1] = "manager:" .. name
			end
		end
	end
	for key, value in pairs(_G) do
		if type(key) == "string" and type(value) == "table" and key:find("Menu", 1, true)
			and key:find("Style", 1, true) and key:find("Mixin$") and type(value.Generate) == "function" then
			pcall(hooksecurefunc, value, "Generate", function(self)
				if BT.Enabled("menus") then
					M.DressMenu(self)
				end
			end)
			M.found[#M.found + 1] = key
		end
	end
	return true
end

function M:OnEnable()
	M.Hook()
end

M.OnBind = M.OnEnable

function M:OnDisable()
	dresser:Undress()
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

function M:BuildTab(panel)
	local page = BT.Widgets.Stack(panel)
	page:Note("the game's dropdown and right-click menus: every entry does what it did · "
		.. "the light under the pointer and the ticks stay the game's")
	page:Note("switched off, the game's own art is back · /bt menusdump writes the next menu you open "
		.. "into the saved file", true)
	page:Layout()
end

function M:RefreshTab()
end

function M:ShowTab()
end

function M:Refresh()
end

-- ---------------------------------------------------------------------------
-- The dump
-- ---------------------------------------------------------------------------

function M.Dump(menu)
	local lines = BT.Furniture.Dump({ menu })
	table.insert(lines, 1, "hooked: " .. table.concat(M.found or {}, ", "))
	BT.EnsureBound()
	BeebModDB.menusDump = { at = U.Now(), lines = lines }
	U.Print(("menus: %d lines written down · /reload to save them"):format(#lines))
	return #lines
end

-- /bt menusdump: the next menu opened, written down
BT.Command("menusdump", function()
	M.dumpNext = true
	U.Print("menus: open any menu and it will be written down"
		.. ((M.found and #M.found > 0) and "" or " · none of the game's menu hooks were found on this build"))
end, "menusdump - the next menu you open, into the saved file", "menus")
