-- The Ledger in the game's right-click menu (Josh 2026-10-05: "Would it be
-- possible to right click a player and add some options to that menu?", and
-- of the canvas "Ledger from the right-click menu": "I like menu B. Then we
-- can remove the old version from the dock").
--
-- One entry at the foot of every menu the game opens on a player - their
-- frame, their name in chat, the guild, friends and raid lists - with your
-- note and tags marked on it, and a list of its own:
--
--   Ledger  [note] [tag]  >   [x] Good
--                             [ ] Bad
--                             New tag
--                             -----------
--                             Edit note
--                             Rating   >
--
-- A tag is ticked and unticked with the menu still open. A note opens the
-- note panel (Modules/Ledger/Find.lua) under the frame you right-clicked.
--
-- The client's menus are built for this (Blizzard_Menu/Menu.lua and its
-- implementation guide, on the forever branch): Menu.ModifyMenu adds to a
-- tagged menu without tainting the game's own entries. Right-clicking a
-- character in the world opens no menu in this client; their frame and
-- their name do.
--
-- It replaces the dock's target row, which showed your target's name, a dot
-- per tag and a pencil. What you wrote is read where the player is: on their
-- tooltip, as before, and as a mark on the target frame (LM.Mark).
local _, BT = ...

local U, N = BT.Util, BT.Notes

local LM = {}
BT.LedgerMenu = LM

-- every menu the game opens on a player, by the name it gives it. Your own
-- frames open PLAYER, PARTY, RAID_PLAYER or FOCUS (SECURE_ACTIONS.togglemenu);
-- a name in chat opens FRIEND.
LM.MENUS = {
	"PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FOCUS",
	"FRIEND", "FRIEND_OFFLINE", "GUILD", "GUILD_OFFLINE", "CHAT_ROSTER",
	"COMMUNITIES_WOW_MEMBER", "COMMUNITIES_GUILD_MEMBER",
	"RECENT_ALLY", "RECENT_ALLY_OFFLINE", "WORLD_STATE_SCORE", "PVP_SCOREBOARD",
}

-- ---------------------------------------------------------------------------
-- Who the menu is about
-- ---------------------------------------------------------------------------

-- A frame's menu has the unit; a name in chat or a list has only the name,
-- and sometimes the surname apart from it. Returns the key, the name and what
-- is known of them: the unit's face, or the name alone, which is enough for a
-- first note to make their row. Nothing for you, an NPC or a pet.
function LM.Who(contextData)
	local c = type(contextData) == "table" and contextData or {}
	local unit = c.unit
	if unit then
		if UnitIsUnit and UnitIsUnit(unit, "player") then
			return nil
		end
		local key, info = N.Face(unit)
		if not key then
			return nil
		end
		return key, info.name, info
	end
	local name = c.name
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if type(c.surname) == "string" and c.surname ~= "" then
		-- U.Key takes a tail that is not a realm for the second half of a name
		name = name .. "-" .. c.surname
	end
	local key, full = U.Key(name)
	if not key then
		return nil
	end
	local me = U.Me and U.Me()
	if me and U.Key(me) == key then
		return nil
	end
	return key, full, { name = full }
end

-- ---------------------------------------------------------------------------
-- The entry and its list
-- ---------------------------------------------------------------------------

-- a square of a tag's colour, inside a line of menu text
local SQUARE = "|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t"
function LM.Square(color)
	local c = type(color) == "table" and color or { 0.6, 0.65, 0.62 }
	return SQUARE:format(math.floor((c[1] or 0.6) * 255), math.floor((c[2] or 0.65) * 255),
		math.floor((c[3] or 0.62) * 255))
end

-- the note's mark, as the tooltip and the old dock row drew it: the first
-- picture on the dock's sheet (Art/icons, eight across, 256 by 32)
LM.NOTE_MARK = "|TInterface\\AddOns\\BeebMod\\Art\\icons:12:12:0:0:256:32:0:32:0:32:230:224:204|t"

-- the tags someone carries, in the order the tags are listed
function LM.TagsOn(p)
	local out = {}
	for _, f in ipairs(BT.AllTags and BT.AllTags() or {}) do
		if p and p.tags and p.tags[f.key] then
			out[#out + 1] = f
		end
	end
	return out
end

-- The entry's words: "Ledger", then the note's mark and a square per tag when
-- you have written on them, so a glance at the menu says so. Three squares at
-- most, as on the target frame.
LM.MOST_SQUARES = 3
function LM.EntryText(p)
	local marks = {}
	if p and p.note then
		marks[#marks + 1] = LM.NOTE_MARK
	end
	for i, f in ipairs(LM.TagsOn(p)) do
		if i > LM.MOST_SQUARES then
			break
		end
		marks[#marks + 1] = LM.Square(f.color)
	end
	if #marks == 0 then
		return "Ledger"
	end
	return "Ledger  " .. table.concat(marks, " ")
end

-- what the Rating entry says: the rating when there is one
function LM.RatingText(p)
	local r = p and p.rating
	return r and ("Rating · %d / 5"):format(r) or "Rating"
end

-- the note panel, for this person, under `owner`; with the tag maker open
-- when `newTag`
function LM.Open(key, owner, info, newTag)
	if not BT.Find then
		return false
	end
	BT.Find.EnsureBuilt()
	if not BT.Find.OpenEditorFor(key, owner, info) then
		return false
	end
	if newTag then
		BT.Find.ShowTagMaker(true)
	end
	return true
end

-- a tag ticked or a rating chosen: the Ledger's windows and the tooltip
-- catch up (the target frame's mark hears it from the book, LM.Listen)
local function changed()
	if BT.Find and BT.Find.Refresh then
		BT.Find.Refresh()
	end
end

-- The Ledger's entry and its list, added to `root`, a menu the game is
-- building. Each check reads the book as the menu draws it, so a tag ticked
-- shows ticked at once.
function LM.Build(root, key, info, owner)
	local p = N.Get(key)
	root:CreateDivider()
	-- A CLICK ON "LEDGER" IS NOT NOTHING (Josh 2026-10-05: "I still see no
	-- way to edit notes or tags of a player via right clicking the target").
	-- Its list opens on pointing at it; a click on the entry itself opens the
	-- note panel, with every tag and the note, under the frame.
	local entry = root:CreateButton(LM.EntryText(p), function()
		LM.Open(key, owner, info)
	end)
	if entry.SetShouldRespondIfSubmenu then
		entry:SetShouldRespondIfSubmenu(true)
	end
	for _, f in ipairs(BT.AllTags()) do
		local tag = f.key
		entry:CreateCheckbox(LM.Square(f.color) .. " " .. f.label, function()
			local q = N.Get(key)
			return (q and q.tags and q.tags[tag]) and true or false
		end, function()
			N.ToggleTag(key, tag, info)
			changed()
		end)
	end
	entry:CreateButton("New tag", function()
		LM.Open(key, owner, info, true)
	end)
	entry:CreateDivider()
	entry:CreateButton((p and p.note) and "Edit note" or "Write a note", function()
		LM.Open(key, owner, info)
	end)
	local rating = entry:CreateButton(LM.RatingText(p))
	for n = 1, 5 do
		rating:CreateRadio(tostring(n), function()
			local q = N.Get(key)
			return (q and q.rating == n) and true or false
		end, function()
			N.SetRating(key, n, info)
			changed()
		end)
	end
	rating:CreateRadio("No rating", function()
		local q = N.Get(key)
		return not (q and q.rating)
	end, function()
		N.SetRating(key, nil, info)
		changed()
	end)
	return entry
end

-- what Menu.ModifyMenu calls, every time one of LM.MENUS opens. Only while
-- the Ledger is on; a mistake here costs the entry, never the game's menu.
function LM.Add(owner, root, contextData)
	if not (BT.Enabled and BT.Enabled("ledger")) or not root then
		return
	end
	local ok, key, _, info = pcall(LM.Who, contextData)
	if not (ok and key) then
		return
	end
	local built, err = pcall(LM.Build, root, key, info, owner)
	if not built and BT.Err then
		BT.Err("Ledger menu: " .. tostring(err))
	end
end

-- Once: the menus can't be let go of again, so the entry asks whether the
-- Ledger is on each time (LM.Add).
function LM.Hook()
	if LM.hooked then
		return true
	end
	local Menu = _G.Menu
	if not (type(Menu) == "table" and Menu.ModifyMenu) then
		return false
	end
	for _, which in ipairs(LM.MENUS) do
		pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, LM.Add)
	end
	LM.hooked = true
	return true
end

-- ---------------------------------------------------------------------------
-- The mark on the target frame
-- ---------------------------------------------------------------------------

-- What the target frame shows of what you wrote on `unit`: whether there is
-- a note, and the tags' colours (LM.MOST_SQUARES at most). Nothing for
-- anyone you have not written on, or with the Ledger off.
-- The name alone is asked for, not the whole face N.Face reads: the frame is
-- painted on every target change, and a name a book has no row for is the
-- usual answer. A name the client keeps secret is no answer at all.
local function keyOf(unit)
	if not (UnitIsPlayer and UnitIsPlayer(unit)) then
		return nil
	end
	local name, realm = U.UnitFullName(unit)
	return name and U.Key(name, realm) or nil
end

function LM.Mark(unit)
	if not (BT.Enabled and BT.Enabled("ledger")) then
		return false, {}
	end
	local ok, key = pcall(keyOf, unit)
	local p = ok and key and N.Get(key)
	if not p then
		return false, {}
	end
	local colors = {}
	for i, f in ipairs(LM.TagsOn(p)) do
		if i > LM.MOST_SQUARES then
			break
		end
		colors[i] = f.color or { 0.6, 0.65, 0.62 }
	end
	return p.note ~= nil, colors
end

-- a note or a tag changed: the frames paint their marks again
function LM.Repaint()
	local uf = BT.GetModule and BT.GetModule("unitframes")
	if uf and uf.PaintSingles and BT.Enabled and BT.Enabled("unitframes") then
		pcall(uf.PaintSingles)
	end
end

N.Listen(LM.Repaint)
LM.Hook()
-- (and again in the world, should the game's menus load after BeebMod)
if BT.OnWorld then
	BT.OnWorld(function()
		LM.Hook()
	end)
end
