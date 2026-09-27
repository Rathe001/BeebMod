-- The vocabulary the Ledger writes in (Josh 2026-09-19). Moved out of the core
-- when the toolkit split: a tag is a judgement about a person, which is the
-- Ledger's business and nobody else's. The Census may draw a chart of them,
-- and asks first whether the Ledger is switched on at all.
--
-- These live on BT rather than on the module table because the tooltip, the
-- bar and the charts all speak this vocabulary, and none of them should have
-- to reach through a module to say "green, called Good".
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Ledger/Tags.lua")

-- THREE BUILT IN, THE REST ARE YOURS (Josh 2026-09-19). Any list I write is a
-- guess at what you will want to say about people. These three are the ones
-- everybody needs; everything past them is a tag you make yourself, so the
-- vocabulary is the one your guild actually uses.
--
-- WHAT A TAG IS FOR. Not roles - a class already tells you who can tank, and
-- the game tells you their level. What nothing else records is what they were
-- LIKE: the one who waited while you ran back, the one who pulled the room and
-- left, the one who took the roll.
--
-- One word each, so a pill stays a pill: "Good player" was a wide badge
-- wherever three of them had to fit (Josh 2026-09-19). `key` is what the book
-- stores, so renaming a label is safe and renaming a key is not.
BT.FLAGS = {
	{ key = "good",  label = "Good",  short = "Good",  icon = "|cff40c057+|r", color = { 0.25, 0.78, 0.40 }, builtin = true },
	{ key = "bad",   label = "Bad",   short = "Bad",   icon = "|cffff6b6bv|r", color = { 0.91, 0.30, 0.30 }, builtin = true },
	{ key = "troll", label = "Troll", short = "Troll", icon = "|cffba9ffa!|r", color = { 0.73, 0.62, 0.98 }, builtin = true },
}

-- The palette a custom tag can pick from: enough to tell them apart at a
-- glance, few enough to stay a decision rather than a colour wheel.
BT.TAG_COLORS = {
	{ name = "green",  color = { 0.31, 0.82, 0.48 } },
	{ name = "blue",   color = { 0.45, 0.75, 0.99 } },
	{ name = "gold",   color = { 1.00, 0.83, 0.23 } },
	{ name = "orange", color = { 1.00, 0.57, 0.17 } },
	{ name = "red",    color = { 1.00, 0.42, 0.42 } },
	{ name = "violet", color = { 0.73, 0.62, 0.98 } },
}

-- Flags that used to exist, and where they land now. Anything else that is
-- still in use becomes a custom tag rather than being thrown away, and a NOTE
-- is never touched.
BT.FLAG_MOVED = { great = "good", terrible = "bad", watch = "troll" }
BT.FLAG_RETIRED = { friendly = "Good company", recruit = "Worth asking",
	tank = "Tank", healer = "Healer" }
BT.FLAG_DROPPED = { avoid = true }

-- Built-ins first, then yours, in the order you made them.
function BT.AllFlags()
	local out = {}
	for _, f in ipairs(BT.FLAGS) do
		out[#out + 1] = f
	end
	for _, t in ipairs((BT.settings and BT.settings.tags) or {}) do
		out[#out + 1] = t
	end
	return out
end

local function tagColorMarkup(color)
	return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

-- Returns the tag, or nil and why not. Labels are unique because they are what
-- you read; keys are private and never reused.
function BT.AddTag(label, colorIndex, key)
	if not BT.settings then
		return nil, "no book is open yet"
	end
	label = type(label) == "string" and label:match("^%s*(.-)%s*$") or ""
	if label == "" then
		return nil, "a tag needs a name"
	end
	if #label > 20 then
		return nil, "that name is too long for a button"
	end
	for _, f in ipairs(BT.AllFlags()) do
		if f.label:lower() == label:lower() then
			return nil, ("there is already a tag called %s"):format(f.label)
		end
	end
	if #(BT.settings.tags or {}) >= 12 then
		return nil, "twelve tags is as many as the panel can show"
	end
	local pick = BT.TAG_COLORS[tonumber(colorIndex) or (#(BT.settings.tags or {}) % #BT.TAG_COLORS + 1)]
		or BT.TAG_COLORS[1]
	BT.settings.tags = BT.settings.tags or {}
	BT.settings.nextTag = (BT.settings.nextTag or 0) + 1
	local tag = {
		key = key or ("tag" .. BT.settings.nextTag),
		label = label, short = label, color = pick.color,
		icon = tagColorMarkup(pick.color) .. "*|r",
	}
	BT.settings.tags[#BT.settings.tags + 1] = tag
	-- a new tag is something a tooltip can show, so the tooltip's own
	-- counter moves too (see BT.Notes.noteRev)
	if BT.Notes then
		BT.Notes.Touched(true)
	end
	return tag
end

-- How many characters carry this tag, and in how many books. Deleting is not
-- reversible, so the question "how much am I about to throw away" has to have
-- an answer before the click, not after (Josh 2026-09-19).
-- Every book of the Ledger's (Modules/Ledger/Store.lua), realm and side each.
local function ledgerBooks()
	local root = BT.Notes and BT.Notes.Root()
	return (root and root.realms) or {}
end

function BT.TagUsage(key)
	local characters, books = 0, 0
	for _, book in pairs(ledgerBooks()) do
		local here = 0
		for _, p in pairs(book.people or {}) do
			if p.flags and p.flags[key] then
				here = here + 1
			end
		end
		if here > 0 then
			characters = characters + here
			books = books + 1
		end
	end
	return characters, books
end

-- Removing a tag takes it off every character too: a mark nobody can see or
-- filter by is worse than no mark.
function BT.RemoveTag(key)
	if not (BT.settings and BT.settings.tags) then
		return false
	end
	local found
	for i, t in ipairs(BT.settings.tags) do
		if t.key == key or t.label:lower() == tostring(key):lower() then
			found = table.remove(BT.settings.tags, i)
			break
		end
	end
	if not found then
		return false
	end
	for _, book in pairs(ledgerBooks()) do
		local people = book.people or {}
		for key, p in pairs(people) do
			if p.flags and p.flags[found.key] then
				p.flags[found.key] = nil
				if not next(p.flags) then
					p.flags = nil
				end
				-- a row that was only this tag is nobody's any more
				if BT.Notes and not BT.Notes.IsMine(p) then
					people[key] = nil
				end
			end
		end
	end
	-- and the tooltip under the cursor stops showing the deleted tag
	if BT.Notes then
		BT.Notes.Touched(true)
	end
	return true, found
end

-- WHO IS ALLOWED TO SWEEP (Josh 2026-09-19). This walks every character and
-- removes marks whose meaning no longer exists, which is the most destructive
-- thing the addon does on an ordinary login. It runs from the Ledger module's
-- OnBind and nowhere else, so a toolkit with the Ledger switched off never
-- tidies away judgements it is not currently showing you.
function BT.MigrateTags()
	-- the people written on in this book: the tags live on the Ledger's rows
	local db = { players = BT.Notes and BT.Notes.People() }
	if not (db.players and BT.settings) then
		return
	end
	local live = {}
	for _, f in ipairs(BT.AllFlags()) do
		live[f.key] = true
	end
	-- a flag dropped outright leaves the book and every character on it:
	-- RemoveTag handles the ones that had become tags, and this sweeps the
	-- marks left by ones that never did
	for dropped in pairs(BT.FLAG_DROPPED) do
		if live[dropped] then
			BT.RemoveTag(dropped)
			live[dropped] = nil
		end
	end
	for _, p in pairs(db.players or {}) do
		for k in pairs(p.flags or {}) do
			if BT.FLAG_DROPPED[k] then
				p.flags[k] = nil
			end
		end
		if p.flags and not next(p.flags) then
			p.flags = nil
		end
	end
	-- a retired flag you actually used becomes a custom tag, so a judgement
	-- you made months ago survives the day the built-in list changed
	-- WHEN THE TAG CANNOT BE MADE (Josh 2026-09-22). AddTag refuses a label
	-- that is already a tag of yours, and refuses a thirteenth tag - and on
	-- either refusal the sweep below used to drop the mark from every
	-- character. A clash means you already made that tag by hand, so the
	-- mark moves onto it; a full panel means the mark simply stays as it is.
	local movedTo = {}
	for _, p in pairs(db.players or {}) do
		for k in pairs(p.flags or {}) do
			if not live[k] and not movedTo[k] and not BT.FLAG_MOVED[k] and BT.FLAG_RETIRED[k] then
				if BT.AddTag(BT.FLAG_RETIRED[k], nil, k) then
					live[k] = true
				else
					local existing
					for _, f in ipairs(BT.AllFlags()) do
						if f.label:lower() == BT.FLAG_RETIRED[k]:lower() then
							existing = f
						end
					end
					if existing and existing.key ~= k then
						movedTo[k] = existing.key
					else
						live[k] = true
					end
				end
			end
		end
	end
	for _, p in pairs(db.players or {}) do
		if p.flags then
			-- collect first, THEN edit: adding a key to the table you are
			-- walking is an "invalid key to next" error, not a warning
			-- ONLY WHAT IS KNOWN TO BE OLD (Josh 2026-09-23, audit). Every key
			-- that was not a live tag used to go, and a tag of yours whose
			-- definition had gone missing from the settings took its marks off
			-- every character in the book with it, for good. Now a key moves
			-- or goes only when it is one this sweep knows about - moved,
			-- retired onto an existing tag, or dropped - and anything else is
			-- left alone, to show again if its tag comes back.
			local stale = {}
			for k in pairs(p.flags) do
				if not live[k] and (BT.FLAG_MOVED[k] or movedTo[k] or BT.FLAG_DROPPED[k]) then
					stale[#stale + 1] = k
				end
			end
			for _, k in ipairs(stale) do
				p.flags[k] = nil
				local moved = BT.FLAG_MOVED[k] or movedTo[k]
				if moved then
					p.flags[moved] = true
				end
			end
			if not next(p.flags) then
				p.flags = nil
			end
		end
	end
end
