-- ONE NAME FOR EACH THING (Josh 2026-09-29: "I think we have a lot of drift
-- between what we label things in the user facing addon, and what we call it
-- behind the scenes. I'd like to get everything in alignment.").
--
-- The code now calls each thing by the name the player reads: the Currency
-- line is "currency", not "gold", and the Tooltips page is "tooltips", not
-- "tips". The saved file was written under the old names, so this moves what
-- it holds to the new ones when the book is bound, before any module reads
-- its settings (BT.Bind).
--
-- EACH RENAME IS A STEP: a list of pairs, the old name first. A later rename
-- adds a step at the end of R.STEPS and nothing else. A step can name:
--   modules    a module key: its switch (settings.modules) and its place in
--              your tab order (settings.order)
--   features   a feature key: its switch (settings.features)
--   settings   a key of the settings themselves, such as a module's options
--   records    a key at the top of BeebModDB: a record the Testing page wrote
--   rows       a field on every row of a character you wrote on: the
--              Ledger's rows, and any older copy that may still hold them
--              (the census's rows, the per-character stash, BeebModKeep)
--   within     a key inside one of the settings: { setting, old, new }
--   values     a value that named something: { setting, key, old, new }
--   earned     the start of a commendation's id, in each character's
--              earned and earnedBy (the Expedition's): { old, new }
--   dropped    a setting nothing reads any more, taken out
--
-- NOTHING IS LOST. A value moves only to a name that is empty. When both
-- names hold something, the new one is kept, the old one is left as it was,
-- and the log says so (BT.Err): nothing is deleted that was not copied first.
-- The one exception is a step's `dropped` list: settings no code has read
-- since an earlier release, which would otherwise stay in the file for good.
-- Running it again changes nothing, so it runs at every bind and does not
-- trust its own record. settings.renamed is the number of the last step that
-- ran, for anyone reading the saved file. Nothing is decided by it.
--
-- A NAME THAT MEANT SOMETHING ELSE. Step 1 gives "bags" to the Bags line.
-- It was the Bag bar restyle's key until 2026-09-24, and every release since
-- has dropped that module's switch and place at each bind (BT.DropRetired),
-- so a file any release has loaded holds no "bags" of the old kind. One that
-- somehow does is a file with both names, and is treated as one.
local _, BT = ...

local R = {}
BT.Rename = R

R.STEPS = {
	-- 1. MODULE NAMES (Josh 2026-09-29): each module's key, folder and file
	-- take the title the player sees
	{
		modules = {
			{ "gold", "currency" },
			{ "bagspace", "bags" },
			{ "perf", "performance" },
			{ "prd", "resourcedisplay" },
			{ "tips", "tooltips" },
			{ "menu", "gamemenu" },
			{ "menus", "dropdowns" },
			{ "frames", "unitframes" },
			{ "ilevel", "itemlevel" },
		},
		features = {
			{ "frames", "unitframes" },
		},
		settings = {
			{ "gold", "currency" },
			{ "prd", "resourcedisplay" },
			{ "tips", "tooltips" },
			{ "frames", "unitframes" },
		},
		records = {
			{ "prdDump", "resourcedisplayDump" },
			{ "menuDump", "gamemenuDump" },
			{ "menusDump", "dropdownsDump" },
			{ "framesDump", "unitframesDump" },
			{ "bagDump", "bagwindowDump" },
			{ "sheetDump", "charsheetDump" },
			{ "meterDump", "damagemeterDump" },
		},
	},
	-- 2. THE DOCK (Josh 2026-09-29): the panel was called the bar in the code
	-- (BT.Bar, UI/Bar.lua) long after the player knew it as the Dock. Its
	-- position is the dock's, and the switch named "bar" was the Target row's
	-- all along.
	{
		settings = {
			{ "barPos", "dockPos" },
			{ "bar", "targetRow" },
		},
	},
	-- 3. TAGS (Josh 2026-09-29): the player has only ever seen "tags"; each
	-- row of yours kept them in a field called flags
	{
		rows = {
			{ "flags", "tags" },
		},
	},
	-- 4. NESINGWARY'S EXPEDITION (Josh 2026-09-29): the Menagerie was renamed
	-- on screen on 2026-09-27 and kept its old name inside. Its journal is
	-- the Journal, its achievements are Commendations and its mobs are
	-- enemies, as the window says; a kind of enemy killed is a unique kill.
	{
		modules = {
			{ "menagerie", "expedition" },
		},
		features = {
			{ "menagerie", "expedition" },
		},
		settings = {
			{ "menagerie", "expedition" },
			{ "menagerieUI", "expeditionUI" },
			{ "menagerieDiscover", "expeditionDiscover" },
			{ "menagerieShows", "expeditionShows" },
			{ "menagerieToasts", "expeditionToasts" },
			{ "menagerieSound", "expeditionSound" },
		},
		within = {
			{ "expedition", "mobs", "enemies" },
			{ "expeditionUI", "achPick", "commendationPick" },
			{ "expeditionUI", "achShow", "commendationShow" },
		},
		values = {
			{ "expeditionUI", "view", "bestiary", "journal" },
			{ "expeditionUI", "view", "achievements", "commendations" },
			{ "expeditionUI", "commendationPick", "kinds", "uniques" },
		},
		earned = {
			{ "kinds:", "uniques:" },
		},
		-- read by nothing: the portraits' switch, gone since they stayed for
		-- good (2026-09-28), and reports older builds wrote into the settings,
		-- which Clear on the Testing page used to take out
		dropped = { "menagerieEdge", "menagerieLoreReport", "menagerieModelReport", "menagerieMapReport",
			"menagerieSceneReport" },
	},
}

local function note(where, old, new)
	BT.Err(("Rename: %s holds both %s and %s. Kept %s; %s is left as it was."):format(where, old, new, new, old))
end

-- one key of a table, moved to an empty name
local function moveKey(t, old, new, where)
	if type(t) ~= "table" or t[old] == nil then
		return 0
	end
	if t[new] ~= nil then
		note(where, old, new)
		return 0
	end
	t[new], t[old] = t[old], nil
	return 1
end

-- one name in a list of names, in its own place, unless the list already
-- has the new name
local function moveInList(list, old, new, where)
	if type(list) ~= "table" then
		return 0
	end
	local at, has = nil, false
	for i, v in ipairs(list) do
		if v == old and not at then
			at = i
		elseif v == new then
			has = true
		end
	end
	if not at then
		return 0
	end
	if has then
		note(where, old, new)
		return 0
	end
	list[at] = new
	return 1
end

-- One field on one row. The fields renamed here are sets ({ [key] = true }),
-- so a row that somehow has both is given one set holding every key of the
-- two: nothing is lost, and no line is written for each of thousands of rows.
local function moveField(p, old, new)
	if type(p) ~= "table" or p[old] == nil then
		return 0
	end
	if type(p[new]) == "table" and type(p[old]) == "table" then
		for k, v in pairs(p[old]) do
			if p[new][k] == nil then
				p[new][k] = v
			end
		end
	elseif p[new] ~= nil then
		return 0
	else
		p[new] = p[old]
	end
	p[old] = nil
	return 1
end

-- every row in a book's list of rows; a packed row is a string and never
-- holds anything of yours (Core/Pack.lua)
local function moveRows(list, old, new)
	local n = 0
	if type(list) == "table" then
		for _, p in pairs(list) do
			if type(p) == "table" then
				n = n + moveField(p, old, new)
			end
		end
	end
	return n
end

-- each list of rows in a table of books: books[scope][field]
local function eachBook(books, field, old, new)
	local n = 0
	if type(books) == "table" then
		for _, book in pairs(books) do
			if type(book) == "table" then
				n = n + moveRows(book[field], old, new)
			end
		end
	end
	return n
end

-- every commendation id that starts `old`, in each character's earned and
-- earnedBy, to start `new` instead
local function earned(s, old, new)
	local n = 0
	local book = type(s.expedition) == "table" and s.expedition.chars
	for who, c in pairs(type(book) == "table" and book or {}) do
		for _, field in ipairs({ "earned", "earnedBy" }) do
			local t = type(c) == "table" and c[field]
			if type(t) == "table" then
				local ids = {}
				for id in pairs(t) do
					if type(id) == "string" and id:sub(1, #old) == old then
						ids[#ids + 1] = id
					end
				end
				for _, id in ipairs(ids) do
					n = n + moveKey(t, id, new .. id:sub(#old + 1), ("expedition.chars[%s].%s"):format(tostring(who), field))
				end
			end
		end
	end
	return n
end

local function rows(saved, keep, char, old, new)
	local n = 0
	n = n + eachBook(type(saved.ledger) == "table" and saved.ledger.realms, "people", old, new)
	n = n + eachBook(saved.realms, "players", old, new)
	n = n + eachBook(type(keep) == "table" and keep.realms, "players", old, new)
	local stash = type(char) == "table" and char.book
	if type(stash) == "table" and type(stash.db) == "table" then
		n = n + moveRows(stash.db.players, old, new)
	end
	return n
end

-- Every step over a saved file: `saved` is BeebModDB, its settings inside;
-- `keep` and `char` are BeebModKeep and BeebModChar, when there are any.
-- Returns how many values moved.
function R.Run(saved, keep, char)
	if type(saved) ~= "table" or type(saved.settings) ~= "table" then
		return 0
	end
	local s = saved.settings
	local done = tonumber(s.renamed) or 0
	local moved = 0
	for _, step in ipairs(R.STEPS) do
		for _, p in ipairs(step.modules or {}) do
			moved = moved + moveKey(s.modules, p[1], p[2], "settings.modules")
			moved = moved + moveInList(s.order, p[1], p[2], "settings.order")
		end
		for _, p in ipairs(step.features or {}) do
			moved = moved + moveKey(s.features, p[1], p[2], "settings.features")
		end
		for _, p in ipairs(step.settings or {}) do
			moved = moved + moveKey(s, p[1], p[2], "settings")
		end
		for _, p in ipairs(step.records or {}) do
			moved = moved + moveKey(saved, p[1], p[2], "BeebModDB")
		end
		for _, p in ipairs(step.rows or {}) do
			moved = moved + rows(saved, keep, char, p[1], p[2])
		end
		for _, p in ipairs(step.within or {}) do
			moved = moved + moveKey(s[p[1]], p[2], p[3], "settings." .. p[1])
		end
		for _, p in ipairs(step.values or {}) do
			local t = s[p[1]]
			if type(t) == "table" and t[p[2]] == p[3] then
				t[p[2]] = p[4]
				moved = moved + 1
			end
		end
		for _, p in ipairs(step.earned or {}) do
			moved = moved + earned(s, p[1], p[2])
		end
		for _, key in ipairs(step.dropped or {}) do
			if s[key] ~= nil then
				s[key] = nil
				moved = moved + 1
			end
		end
	end
	if done < #R.STEPS then
		s.renamed = #R.STEPS
	end
	return moved
end

-- every old name a record had, so Clear on the Testing page takes those too
function R.OldRecords()
	local out = {}
	for _, step in ipairs(R.STEPS) do
		for _, p in ipairs(step.records or {}) do
			out[#out + 1] = p[1]
		end
	end
	return out
end
