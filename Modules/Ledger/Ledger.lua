-- The Ledger module: what you think of the people you meet (Josh 2026-09-19).
--
-- It owns the Find tab, the tooltip decoration, and the Ledger's entry in the
-- game's right-click menu on a player (Modules/Ledger/Menu.lua), where you tag
-- them and write a note. What you write is kept in the Ledger's own book
-- (Modules/Ledger/Store.lua), not on the census's rows: the Ledger works
-- with no census at all, and uses one to find people when there is one.
--
-- THE TAG SWEEP RUNS HERE AND NOWHERE ELSE. Migrating tags walks every
-- character and removes marks whose meaning no longer exists, which is the
-- most destructive thing this addon does on an ordinary login. A toolkit with
-- the Ledger switched off must never tidy away judgements it is not currently
-- showing you, so it hangs off this module's OnBind.
local _, BT = ...

local U, N = BT.Util, BT.Notes

local M = BT.Module({
	key = "ledger",
	feature = "ledger",
	title = "Ravenholdt Ledger",
	short = "Ledger",
	order = 10,
})

-- a setting that is on unless switched off, as a row's get and set
local function setting(key)
	return function()
		return not (BT.settings and BT.settings[key] == false)
	end, function(on)
		BT.EnsureBound()
		BT.settings[key] = on and true or false
	end
end

-- THE LEDGER'S PARTS (the settings canvas, Josh 2026-10-04): its own
-- switch is the feature's, so these stand at the top of its page, each one
-- a setting. Notes on tooltips is still BT.settings.tooltip, where
-- Modules/Ledger/Tooltip.lua reads it.
function M:Parts()
	local tipGet, tipSet = setting("tooltip")
	local groupGet, groupSet = setting("ledgerGroups")
	local duelGet, duelSet = setting("ledgerDuels")
	return {
		{ label = "Notes on tooltips", blurb = "Your note, tags and rating on player tooltips",
			get = tipGet, set = tipSet, field = "tooltip" },
		{ label = "People you grouped with", blurb = "Counts a group after 5 minutes together, or in a dungeon",
			get = groupGet, set = groupSet, field = "ledgerGroups" },
		{ label = "Duel scores", blurb = "The duels you win and lose against each player",
			get = duelGet, set = duelSet, field = "ledgerDuels" },
	}
end

-- THE TARGET ROW IS GONE (Josh 2026-10-05: "I like menu B. Then we can
-- remove the old version from the dock"). Your target's name, a dot per tag,
-- the note's mark and a pencil sat in a row at the top of the dock. Notes and
-- tags are written from the game's right-click menu on a player now
-- (Modules/Ledger/Menu.lua), and read on their tooltip and the target frame.

function M:OnBind()
	-- once: what you wrote on the census's rows, into the Ledger's own book
	N.Move()
	BT.MigrateTags()
	-- and the target frame's mark, with the Ledger back on
	if BT.LedgerMenu then
		BT.LedgerMenu.Repaint()
	end
end

function M:OnDisable()
	BT.Find.CloseEditor()
	-- and its window, as the Expedition's goes with it (2026-10-05, audit): left
	-- open, its cards still wrote notes and tags with the Ledger switched off
	if BT.CensusWindow and BT.CensusWindow.Hide then
		BT.CensusWindow.Hide()
	end
	if BT.Tooltip and BT.Tooltip.HidePills then
		BT.Tooltip.HidePills()
	end
	-- the target frame's mark goes with it
	if BT.LedgerMenu then
		BT.LedgerMenu.Repaint()
	end
end

-- ---------------------------------------------------------------------------
-- What the Ledger adds to /bt. Each one is refused with a line saying so when
-- the module is off, rather than quietly doing nothing.
-- ---------------------------------------------------------------------------
BT.Command("find", function(rest)
	BT.Find.Search(rest ~= "" and rest or nil)
end, "find <text> - search names, guilds and notes", "ledger")

-- NOTHING TYPED IS A QUESTION, NOT AN ERASER (Josh 2026-09-23, audit). "/bt
-- note" on your target, or "/bt note Beeb Bob", cleared the note you had
-- written; typing the command to read a note deleted it. Now it reads it
-- back, and clearing takes the word.
BT.Command("note", function(rest)
	local key, text, name, info = N.WhoAndRest(rest)
	if not key then
		U.Print("Ledger: no character by that name, and no player targeted.")
		return
	end
	text = (text or ""):match("^%s*(.-)%s*$")
	if text == "" then
		local p = N.Get(key)
		U.Print(p and p.note and p.note ~= "" and ("Ledger: note on %s · \"%s\""):format(name, p.note)
			or ("Ledger: no note on %s. Type /bt note %s <text> to write one."):format(name, name))
		return
	end
	if text:lower() == "clear" then
		N.SetNote(key, "", info)
		U.Print("Ledger: cleared the note on " .. name .. ".")
	elseif N.SetNote(key, text, info) then
		U.Print(("Ledger: note on %s · \"%s\""):format(name, text))
	else
		U.Print(("Ledger: couldn't write a note on %s. Target them first."):format(name))
	end
	BT.Find.Refresh()
end, "note [name] <text|clear> - write, read or clear a note. With no name, uses your target.", "ledger")

-- A tag on someone, or off them: /bt tag [name] <tag>. By what you see
-- (Josh 2026-09-23, audit): a tag of yours is "tag3" inside and "Tank" on
-- the screen, so the label is tried first, whole and in any case, then the
-- key.
local function toggle(rest)
	-- WhoAndRest returns nothing at all when nobody matches and nothing is
	-- targeted, and indexing that nil was a Lua error where the usage line
	-- should have been
	local key, said, name, info = N.WhoAndRest(rest)
	said = (said or ""):match("^%s*(.-)%s*$")
	local tag
	for _, f in ipairs(BT.AllTags()) do
		if f.label:lower() == said:lower() or f.key == said then
			tag = f
		end
	end
	if not key or not tag then
		local labels = {}
		for _, f in ipairs(BT.AllTags()) do
			labels[#labels + 1] = f.label
		end
		U.Print("Ledger: type /bt tag [name] <" .. table.concat(labels, " | ") .. ">.")
		return
	end
	local p, on = N.ToggleTag(key, tag.key, info)
	if not p and on then
		U.Print(("Ledger: couldn't tag %s. Target them first."):format(name))
		return
	end
	U.Print(("Ledger: %s %s on %s."):format(on and "set" or "cleared", tag.label, name))
	BT.Find.Refresh()
end

BT.Command("tag", function(rest)
	local sub, arg = rest:match("^(%S*)%s*(.-)$")
	if sub == "new" or sub == "add" then
		local tag, why = BT.AddTag(arg)
		U.Print(tag and ("Ledger: added the tag " .. tag.label .. ".") or ("Ledger: " .. (why or "couldn't make that tag.")))
	elseif sub == "delete" or sub == "remove" then
		if arg == "" then
			U.Print("Ledger: type /bt tag delete <name>.")
			return
		end
		local ok, gone = BT.RemoveTag(arg)
		U.Print(ok and ("Ledger: deleted " .. gone.label .. " and took it off every character.")
			or ("Ledger: you have no tag called " .. arg .. "."))
	elseif sub ~= "" then
		toggle(rest)
		return
	else
		local built, mine = {}, {}
		for _, f in ipairs(BT.AllTags()) do
			local into = f.builtin and built or mine
			into[#into + 1] = f.icon .. " " .. f.label
		end
		U.Print("Built-in tags: " .. table.concat(built, ", "))
		U.Print("Your tags: " .. (#mine > 0 and table.concat(mine, ", ") or "none. Type /bt tag new <name> to make one."))
	end
	if BT.Find.RebuildTags then
		BT.Find.RebuildTags()
		BT.Find.Refresh()
	end
end, "tag [name] <tag> - put a tag on someone, or take it off | tag - list the tags | tag new <name> | tag delete <name>", "ledger")
-- the command's name until 2026-09-29, kept so it still works; no help line
BT.Command("flag", toggle, nil, "ledger")

BT.Command("rate", function(rest)
	local key, n, name, info = N.WhoAndRest(rest)
	if not key then
		U.Print("Ledger: no character by that name, and no player targeted.")
		return
	end
	-- as with a note: nothing reads the rating back, "clear" clears it, and a
	-- number that is not 1 to 5 changes nothing (it used to clear it)
	n = (n or ""):match("^%s*(.-)%s*$")
	local current = N.Get(key)
	if n == "" then
		local r = current and current.rating
		U.Print(r and ("Ledger: %s is rated %d/5."):format(name, r) or ("Ledger: %s is not rated."):format(name))
		return
	end
	local want = tonumber(n)
	if n:lower() == "clear" then
		N.SetRating(key, nil, info)
		U.Print("Ledger: cleared the rating on " .. name .. ".")
		return
	end
	if not want or want < 1 or want > 5 then
		U.Print("Ledger: type /bt rate [name] <1-5|clear>.")
		return
	end
	local p = N.SetRating(key, math.floor(want), info)
	local rating = p and p.rating
	U.Print(rating and ("Ledger: rated %s %d/5."):format(name, rating) or ("Ledger: couldn't rate " .. name .. "."))
end, "rate [name] <1-5|clear> - rate someone. With no number, shows their rating.", "ledger")
