-- The bag search knows a few words of its own (Josh 2026-11-21).
--
-- "Baginator's search allows you to search item tags as well, so you can
-- search for 'boe' or 'soulbound' and it will only highlight those items.
-- Can we do that?" The search field is the game's, and it matches an item's
-- name. Typed into it, each word in S.TAGS is taken out of what the game is
-- asked and answered here instead: an item that is not what the word says is
-- dimmed. The other words still go to the game, so "boe sword" is the swords
-- that bind when equipped.
--
--   boe         binds when equipped, and is not bound yet
--   bop         binds when picked up
--   bou         binds when used, and is not bound yet
--   soulbound   bound to you ("bound" too)
--   set         in one of your equipment sets
--   new quest gear consumables crafting ammo shards junk other
--               on that shelf of the category layout (Layouts.lua)
--
-- DIMMED BY ITS OWN ALPHA. The game dims an item it did not match with a
-- picture over the slot, and puts that picture back as it pleases. A slot
-- this dims is made faint as a whole, which the game never touches, and is
-- made solid again when the words go. It works in the grid as well as on the
-- shelves, and in a window a bag.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/BagWindow/Search.lua")

local M = BT.GetModule("bagwindow")
local S = {}
M.Search = S

S.DIM = 0.2

local function onShelf(key)
	return function(item)
		return item.cat == key
	end
end

-- [word] = whether an item is that
S.TAGS = {
	boe = function(item) return item.bind == 2 and not item.bound end,
	bop = function(item) return item.bind == 1 end,
	bou = function(item) return item.bind == 3 and not item.bound end,
	soulbound = function(item) return item.bound == true end,
	set = function(item) return item.set ~= nil end,
	new = onShelf("new"),
	quest = onShelf("quest"),
	gear = onShelf("gear"),
	consumable = onShelf("consumable"),
	crafting = onShelf("crafting"),
	ammo = onShelf("ammo"),
	shards = onShelf("shards"),
	junk = onShelf("junk"),
	other = onShelf("other"),
}
S.TAGS.bound = S.TAGS.soulbound
S.TAGS.consumables = S.TAGS.consumable

-- What was typed, as the tags in it and the rest: "BoE sword" gives
-- { boe's test }, "sword".
function S.Parse(text)
	local tests, rest = {}, {}
	if type(text) ~= "string" then
		return tests, ""
	end
	for word in text:gmatch("%S+") do
		local test = S.TAGS[word:lower()]
		if test then
			tests[#tests + 1] = test
		else
			rest[#rest + 1] = word
		end
	end
	return tests, table.concat(rest, " ")
end

-- whether an item is everything the tags say
function S.Matches(item, tests)
	if not item then
		return false
	end
	for _, test in ipairs(tests) do
		if not test(item) then
			return false
		end
	end
	return true
end

-- [slot] = true while this has made it faint
S.dimmed = setmetatable({}, { __mode = "k" })

function S.Clear()
	for slot in pairs(S.dimmed) do
		pcall(slot.SetAlpha, slot, 1)
	end
	S.dimmed = setmetatable({}, { __mode = "k" })
end

-- every slot of the bag windows, faint where it is not what the tags say;
-- how many are left solid
function S.Apply()
	local tests = S.tests
	if not (tests and #tests > 0 and BT.Enabled("bagwindow")) then
		S.Clear()
		return nil
	end
	local kept = 0
	for _, w in ipairs(M.Windows()) do
		for _, slot in ipairs(M.Slots(w)) do
			local item = M.ItemIn(slot.GetBagID and slot:GetBagID() or nil, slot.GetID and slot:GetID() or nil)
			if item then
				item.cat = M.CategoryOf(item)
			end
			if S.Matches(item, tests) then
				kept = kept + 1
				if S.dimmed[slot] then
					S.dimmed[slot] = nil
					pcall(slot.SetAlpha, slot, 1)
				end
			else
				S.dimmed[slot] = true
				pcall(slot.SetAlpha, slot, S.DIM)
			end
		end
	end
	return kept
end

-- the field's words changed: ours taken out, the rest given to the game
function S.Typed(text)
	local tests, rest = S.Parse(text)
	S.tests = #tests > 0 and tests or nil
	if S.tests then
		local c = rawget(_G, "C_Container")
		if c and c.SetItemSearch then
			pcall(c.SetItemSearch, rest)
		end
	end
	return S.Apply()
end

local function box()
	local w = rawget(_G, "ContainerFrameCombinedBags")
	local b = (type(w) == "table" and w.SearchBox) or rawget(_G, "BagItemSearchBox")
	return type(b) == "table" and b.HookScript and b or nil
end

-- asked by the bag window's own pass (M.StyleAll): the field may not exist
-- when the module comes on
function S.Hook()
	local b = box()
	if not b or S.hooked == b then
		return false
	end
	S.hooked = b
	-- after the game's own handler, which asks the game for every word
	pcall(b.HookScript, b, "OnTextChanged", function(self)
		local ok, text = pcall(self.GetText, self)
		pcall(S.Typed, ok and text or "")
	end)
	return true
end

local queued = false
local function soon()
	if queued or not S.tests then
		return
	end
	if C_Timer and C_Timer.After then
		queued = true
		C_Timer.After(0, function()
			queued = false
			pcall(S.Apply)
		end)
	else
		pcall(S.Apply)
	end
end

-- an item moved, or the game answered its own search: the same words again
S.events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "INVENTORY_SEARCH_UPDATE" }) do
	pcall(S.events.RegisterEvent, S.events, event)
end
S.events:SetScript("OnEvent", soon)
