-- BeebMod: a set of small utilities behind one window and one button
-- (Josh 2026-09-19).
--
-- THE CORE OWNS THE PARTS EVERY UTILITY WOULD OTHERWISE REINVENT: the window
-- with the tabs down its left side, the floating bar, the look of a button and
-- a pill, and the book - every player this client has ever told us about, kept
-- once and shared. A utility is a MODULE: it registers a tab, some cells on
-- the bar, maybe a slash command, and it can be switched off in Settings
-- without the rest noticing.
--
--   Ledger   what you think of the people you meet: notes, tags, tooltips
--   Census   what the realm is made of: class, race, level, your own tags
--
-- Both read the same book, which is why the book belongs to the core: turning
-- Ledger off must not blind the Census, and turning the Census off must not
-- lose a note.
--
-- ONE BOOK PER REALM AND FACTION. The saved file is account-wide, so every
-- character you play writes into the same book as long as they stand on the
-- same realm and the same side: the alt you level tonight already knows the
-- tank you flagged on your main last week. Another realm, or the other
-- faction, gets its own book - those are different populations, you cannot see
-- most of the other side anyway, and mixing them would make "seen 4 times" a
-- lie.
--
-- BeebModDB = {
--   schema, settings,                         account-wide
--   realms = { ["Whitemane|Alliance"] = { realm, players, words, stats } },
-- }
-- BT.db is the book for whoever is logged in; BT.settings is account-wide.
local ADDON, BT = ...

-- THE BOOK THE LIVE FILE SET (Josh 2026-09-22). Data\Live\BeebMod.lua
-- is the client's own save, linked into the addon and run as the first file
-- in the TOC (see there). Whatever it assigned is held onto here, because the
-- client's broken loader runs afterwards and may clear the global again before
-- ADDON_LOADED - and then it is put back.
-- THE OLD NAME'S BOOK (Josh 2026-09-22). BeebsToolkit became BeebMod. The
-- old name's book was adopted from its own file once, and has been saved
-- under the new name since; the TOC stopped loading the old file on 09-23
-- (it held a second copy of the whole book in memory). Adopt stays for an
-- install that still has only the old file.
local function anyRealms(db)
	if type(db) ~= "table" or type(db.realms) ~= "table" then
		return false
	end
	for _, book in pairs(db.realms) do
		if type(book) == "table" and type(book.players) == "table" and next(book.players) then
			return true
		end
	end
	return false
end

function BT.Adopt()
	if anyRealms(BeebModDB) then
		return false
	end
	if anyRealms(BeebsToolkitDB) then
		BeebModDB = BeebsToolkitDB
		BT.adopted = true
		return true
	end
	if type(BeebModDB) ~= "table" and type(BeebsToolkitDB) == "table" then
		BeebModDB = BeebsToolkitDB
		BT.adopted = true
		return true
	end
	return false
end

BT.Adopt()
BT.linked = type(BeebModDB) == "table" and BeebModDB or nil

BT.NAME = ADDON
-- THE NAME, AND THE FOLDER IT LIVES IN (Josh 2026-09-20). The addon is called
-- BeebMod; the folder is still BeebMod and the saved variables are still
-- BeebModDB, because renaming either of those is renaming the file the
-- book lives in, and this client is already bad enough at handing that back.
BT.TITLE = "BeebMod"
BT.VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "0.1.0-beta.4"
BT.SCHEMA = 13
-- Bumped by hand whenever something changes that must be reloaded to take
-- effect. /bt debug prints it, so "did the reload take?" is never a guess.
BT.BUILD = "2026-09-27-markers"

BT.SETTINGS = {
	modules = {},          -- module key -> false when you switch one off
	tooltip = true,        -- show notes and tags on unit tooltips
	tooltipGuild = true,   -- ...and a guild change
	collect = true,        -- write down players we see
	-- auto-purge: a character you saw once three months ago and never wrote on
	-- is noise, and the book gets slower and less true the more of them it
	-- keeps. Anything you have written on is never purged, at any age.
	pruneDays = 90,        -- 0 = keep everything
	-- the most characters a book keeps: past it, the ones seen longest ago
	-- go first (DB.Cap). About 9 MB of saved file, packed (Josh 2026-09-24).
	bookCap = 150000,      -- 0 = no limit
	bar = true,            -- the floating bar
	barPos = nil,          -- where you dragged it
}

-- ---------------------------------------------------------------------------
-- MODULES
--
-- A module is a table with a key, a title, and whatever hooks it needs. It is
-- registered while the files load and never disappears: switching one off
-- hides its tab and its cells and calls OnDisable, so a module has exactly one
-- place to undo itself and nothing else has to know it exists.
--
--   BT.Module({
--     key = "ledger", title = "Ledger", order = 10,
--     blurb = "notes and tags on the people you meet",
--     OnEnable = function(m) end,        -- switched on: hook, register, dress
--     OnDisable = function(m) end,       -- and put them back
--     BuildTab = function(m, parent) end,-- the panel behind its tab
--     ShowTab = function(m) end,         -- called each time the tab is opened
--     OnBind = function(m, db) end,      -- a book was bound (login, loading
--                                        -- screen): set up again, migrate
--     Cells = function(m) return {...} end, -- what it adds to the floating bar
--   })
--
-- Switching a module on calls its OnEnable, or its OnBind when it has none -
-- never both (see BT.SetEnabled).
-- ---------------------------------------------------------------------------
local modules, byKey = {}, {}

function BT.Module(def)
	assert(type(def) == "table" and def.key, "a module needs a key")
	assert(not byKey[def.key], "two modules called " .. tostring(def.key))
	def.order = def.order or 100
	byKey[def.key] = def
	modules[#modules + 1] = def
	table.sort(modules, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.key < b.key
	end)
	return def
end

-- WHO WANTS THE BOOK (Josh 2026-09-20). Collecting used to be a switch of its
-- own on the Settings tab, which asked the player a question they had already
-- answered: the book exists for the Ledger and the Census, and switching both
-- of those off and leaving the collector running writes a book nobody reads.
--
-- So it follows them. Nothing to set, and no way to end up with the Ledger on
-- and an empty book.
-- THE CENSUS ALONE (Josh 2026-09-26): the Ledger keeps what you write in a
-- book of its own, and needs nobody collected to write on someone - so the
-- census's book is filled for the census, and only while it is on.
function BT.Collecting()
	return BT.db ~= nil and BT.Enabled("census")
end

function BT.Modules()
	return modules
end

-- MODULES THAT ARE GONE (Josh 2026-09-24): their switch, their place in your
-- tab order and their own settings, so the saved file stops carrying them.
-- "bags" was the Bag bar restyle; the Bags line in Metrics owns the client's
-- bag bar now.
BT.RETIRED = { "bags" }

function BT.DropRetired()
	local s = BT.settings
	if type(s) ~= "table" then
		return 0
	end
	local n = 0
	for _, key in ipairs(BT.RETIRED) do
		if not byKey[key] then
			if s[key] ~= nil then
				s[key], n = nil, n + 1
			end
			if type(s.modules) == "table" and s.modules[key] ~= nil then
				s.modules[key], n = nil, n + 1
			end
			if type(s.order) == "table" then
				for i = #s.order, 1, -1 do
					if s.order[i] == key then
						table.remove(s.order, i)
						n = n + 1
					end
				end
			end
		end
	end
	return n
end

-- FOR ONE CLASS (Josh 2026-09-22). A module may say `class = "ROGUE"`: it
-- is then only for that class - no tab on the rail and no line in the dock
-- for anyone else. With the class not known yet, it is not shown.
function BT.ClassFits(m)
	if not (m and m.class) then
		return true
	end
	if type(UnitClass) ~= "function" then
		return false
	end
	local ok, _, token = pcall(UnitClass, "player")
	return ok and token == m.class
end

-- YOUR ORDER, NOT OURS (Josh 2026-09-22). The tabs can be dragged into any
-- order, and the dock stacks its sections in the same one - so the order is a
-- setting, a list of module keys, and the module list itself is sorted by it.
-- Everything that walks the modules (the rail, the dock, the cells on the row)
-- follows without knowing there is an order at all. A module the list has not
-- heard of yet - one added in a later version - goes at the end, in its
-- default place among any others like it.
function BT.SortModules()
	local order = BT.settings and BT.settings.order
	local rank = {}
	if type(order) == "table" then
		for i, key in ipairs(order) do
			rank[key] = i
		end
	end
	table.sort(modules, function(a, b)
		local ra = rank[a.key] or (1000 + a.order)
		local rb = rank[b.key] or (1000 + b.order)
		if ra ~= rb then
			return ra < rb
		end
		return a.key < b.key
	end)
	return modules
end

-- Put one module just before another, or just after one (the rail's drop:
-- the rail shows only some modules, so a position is named by a neighbour
-- rather than counted). With neither, it goes last.
function BT.MoveModuleNextTo(key, beforeKey, afterKey)
	if not (BT.settings and byKey[key]) then
		return nil
	end
	local keys = {}
	for _, m in ipairs(modules) do
		if m.key ~= key then
			keys[#keys + 1] = m.key
		end
	end
	local at = #keys + 1
	for i, k in ipairs(keys) do
		if beforeKey and k == beforeKey then
			at = i
			break
		elseif afterKey and k == afterKey then
			at = i + 1
			break
		end
	end
	table.insert(keys, at, key)
	BT.settings.order = keys
	BT.SortModules()
	return keys
end

-- Put one module at a position (1 = first) and keep the rest in their order.
function BT.MoveModule(key, to)
	if not (BT.settings and byKey[key]) then
		return nil
	end
	local keys = {}
	for _, m in ipairs(modules) do
		if m.key ~= key then
			keys[#keys + 1] = m.key
		end
	end
	to = math.max(1, math.min(#keys + 1, math.floor(to or 1)))
	table.insert(keys, to, key)
	BT.settings.order = keys
	BT.SortModules()
	return keys
end

function BT.GetModule(key)
	return byKey[key]
end

-- Off only when it has been deliberately switched off: a module added in a
-- later version arrives switched on, like a new utility should.
-- Its own switch, and nothing else.
function BT.Switched(key)
	local s = BT.settings and BT.settings.modules
	return byKey[key] ~= nil and not (s and s[key] == false)
end

-- PARTS (Josh 2026-09-22). A module can belong to another - `part = "metrics"`
-- - and is then on only while its owner is on as well: the owner's tab has
-- the switches, and switching the owner off puts all of its parts away.
function BT.Enabled(key)
	local m = byKey[key]
	if not m then
		return false
	end
	if m.part and not BT.Switched(m.part) then
		return false
	end
	-- and a whole feature switched off takes everything in it (BT.SetFeature)
	local f = BT.FeatureOf(m)
	if f and not BT.FeatureOn(f) then
		return false
	end
	return BT.Switched(key)
end

-- ---------------------------------------------------------------------------
-- FEATURES (Josh 2026-09-27: "I'd like it to be a single addon, but each of
-- those modules should work independently... Entire modules should have a
-- toggle switch then, so users can easily turn on or off entire modules
-- instead of 1 option at a time").
--
-- Six of them, each a switch of its own over every module in it. Switching a
-- feature off takes all of its modules with it and remembers each one's own
-- switch, so switching it back on brings back exactly what you had. A
-- feature with one page (the Census, the Ledger, the Menagerie) IS its
-- module: switched on, the module is on too.
--
-- The dock's logo and cog are none of these: they are always there, the way
-- back into the settings whatever is switched off (UI/Bar.lua).
-- ---------------------------------------------------------------------------
BT.FEATURES = {
	{ key = "dock", title = "Dock", color = { 0.45, 0.75, 0.99 },
		line = "A panel at the side of the screen: minimap, clock, experience and reputation, gold, bags, durability, the quest tracker." },
	{ key = "frames", title = "Unit frames", color = { 0.49, 0.77, 0.48 },
		line = "Your frame, your party and raid, target and focus, buffs, and your heals and damage over time as bars." },
	{ key = "interface", title = "Interface", color = { 0.88, 0.64, 0.29 },
		line = "The game's own windows in BeebMod's look: action bars, bags, chat, the character sheet, tooltips and menus." },
	{ key = "census", title = "Census", color = { 0.69, 0.56, 0.88 }, single = "census",
		line = "Every character you see, written down: who is on your realm, by class, race, level, guild and zone." },
	{ key = "ledger", title = "Ledger", color = { 0.90, 0.81, 0.42 }, single = "ledger",
		line = "Notes, tags and a rating on the people you meet, shown on their tooltip and in the dock when you target them." },
	{ key = "menagerie", title = "Menagerie", color = { 0.44, 0.64, 0.80 }, single = "menagerie",
		line = "A journal of every kind of mob you kill: a card for each, its lore, masteries, ranks and achievements." },
}
local featureByKey = {}
for _, f in ipairs(BT.FEATURES) do
	featureByKey[f.key] = f
end

function BT.Feature(key)
	return featureByKey[key]
end

-- a module that still says the group it used to be filed under
local FROM_GROUP = { dock = "dock", combat = "frames", windows = "interface" }

-- the feature a module (or a module's key) is part of: its own word, its
-- owner's for a part, or what its older group meant
function BT.FeatureOf(m)
	if type(m) == "string" then
		m = byKey[m]
	end
	if not m then
		return nil
	end
	if m.feature then
		return m.feature
	end
	if m.part then
		return BT.FeatureOf(byKey[m.part])
	end
	if m.group == "people" then
		return featureByKey[m.key] and m.key or nil
	end
	return FROM_GROUP[m.group]
end

-- on unless switched off: a feature added later arrives on
function BT.FeatureOn(key)
	local s = BT.settings and BT.settings.features
	return not (s and s[key] == false)
end

-- the modules of a feature, parts included, in module order
function BT.FeatureModules(key)
	local out = {}
	for _, m in ipairs(modules) do
		if BT.FeatureOf(m) == key then
			out[#out + 1] = m
		end
	end
	return out
end

-- A FEATURE'S SWITCH, FOR AN INSTALL THAT NEVER HAD ONE (2026-09-27): on if
-- anything in it is switched on, off if you had switched all of it off - so
-- the switches start out saying what you already chose. Once.
function BT.SeedFeatures()
	local s = BT.settings
	if not s or type(s.features) == "table" then
		return false
	end
	s.features = {}
	for _, f in ipairs(BT.FEATURES) do
		local on = false
		for _, m in ipairs(BT.FeatureModules(f.key)) do
			if not m.part and BT.Switched(m.key) then
				on = true
			end
		end
		s.features[f.key] = on
	end
	return true
end

-- ONE LOG OF WHAT WENT WRONG (Josh 2026-09-23, audit). Six places appended to
-- BT.moduleErrors on every failure, so an error that repeats - a tooltip
-- contributor on every hover, a dress on every target - grew it without end,
-- and /bt debug printed every copy. The same message is written once and
-- counted after that, and the log stops at fifty different ones.
BT.ERRORS_MAX = 50
function BT.Err(msg)
	msg = tostring(msg)
	BT.errorCounts = BT.errorCounts or {}
	local n = BT.errorCounts[msg]
	if n then
		BT.errorCounts[msg] = n + 1
		return false
	end
	BT.moduleErrors = BT.moduleErrors or {}
	if #BT.moduleErrors >= BT.ERRORS_MAX then
		return false
	end
	BT.errorCounts[msg] = 1
	BT.moduleErrors[#BT.moduleErrors + 1] = msg
	return true
end

local function call(m, hook, ...)
	if m and m[hook] then
		local ok, err = pcall(m[hook], m, ...)
		if not ok then
			BT.Err(("%s.%s: %s"):format(m.key, hook, tostring(err)))
		end
	end
end
BT.CallHook = call

-- SWITCHED ON IS ONE PASS (Josh 2026-09-24). This called OnEnable and then
-- OnBind, and nearly every module's two are the same setup, so switching one
-- on dressed, laid out and restyled everything twice. OnEnable is the whole of
-- coming on; a module with only an OnBind (the Ledger's tag migration) has
-- that run instead, so its book is still seen to.
local function switchOn(m)
	if m.OnEnable then
		call(m, "OnEnable")
	elseif BT.db then
		call(m, "OnBind", BT.db)
	end
end

-- Turning one off has to take effect NOW rather than at the next login: a
-- setting you have to reload to see is a setting you do not trust.
function BT.SetEnabled(key, on)
	local m = byKey[key]
	if not (m and BT.settings) then
		return false
	end
	BT.settings.modules = BT.settings.modules or {}
	-- written out, because `on and nil or false` can never BE nil: `and nil`
	-- is false, so the `or` branch always wins and switching a module back ON
	-- would record it as off (Josh 2026-09-19, the same trap as the tag
	-- filters last week)
	-- ON IS WRITTEN DOWN TOO (Josh 2026-09-22). It used to be recorded as no
	-- entry at all, which is the same thing as never having been asked - so
	-- anything that fills unanswered settings from an older copy switched it
	-- straight back off. An answer is a value either way.
	BT.settings.modules[key] = on and true or false
	if on then
		-- a part of something switched off stays put away until its owner is on
		if BT.Enabled(key) then
			switchOn(m)
		end
	else
		call(m, "OnDisable")
	end
	-- an owner takes its parts with it, each as its own switch says
	for _, part in ipairs(modules) do
		if part.part == key and BT.Switched(part.key) then
			if on then
				switchOn(part)
			else
				call(part, "OnDisable")
			end
		end
	end
	if BT.Window then
		BT.Window.Rebuild()
	end
	-- REBUILD, NOT UPDATE (Josh 2026-09-19). Update repaints the cells that are
	-- there; Rebuild asks the live modules which cells there should BE. With
	-- Update, switching the Ledger off left its name, its dots and its note
	-- sitting on the dock with nothing behind them.
	if BT.Bar then
		BT.Bar.Rebuild()
	end
	return true
end

-- A whole feature on or off, now. Every module that goes from running to not
-- (or back) is told once, whatever its own switch or its owner's said; its
-- own switch is left as it was, to come back with the feature.
function BT.SetFeature(key, on)
	local f = featureByKey[key]
	if not (f and BT.settings) then
		return false
	end
	local before = {}
	for _, m in ipairs(modules) do
		before[m] = BT.Enabled(m.key)
	end
	BT.settings.features = BT.settings.features or {}
	BT.settings.features[key] = on and true or false
	-- a one-page feature is its module: switched on, it runs
	if on and f.single and byKey[f.single] and not BT.Switched(f.single) then
		BT.settings.modules = BT.settings.modules or {}
		BT.settings.modules[f.single] = true
	end
	for _, m in ipairs(modules) do
		local now = BT.Enabled(m.key)
		if now and not before[m] then
			switchOn(m)
		elseif before[m] and not now then
			call(m, "OnDisable")
		end
	end
	if BT.Window then
		BT.Window.Rebuild()
	end
	if BT.Bar then
		BT.Bar.Rebuild()
	end
	return true
end

-- Every enabled module, in tab order.
function BT.Live()
	local out = {}
	for _, m in ipairs(modules) do
		if BT.Enabled(m.key) then
			out[#out + 1] = m
		end
	end
	return out
end

function BT.EachLive(hook, ...)
	for _, m in ipairs(modules) do
		if BT.Enabled(m.key) then
			call(m, hook, ...)
		end
	end
end

-- Slash commands, registered the same way tabs are. A command belonging to a
-- module that is switched off says so rather than half-working, because
-- "/bt note" quietly doing nothing is worse than being told the Ledger is off.
local commands = {}

function BT.Command(name, fn, help, moduleKey)
	commands[name] = { fn = fn, help = help, module = moduleKey, name = name }
end

function BT.Commands()
	return commands
end

function BT.RunCommand(name, rest)
	local c = commands[name]
	if not c then
		return false
	end
	if c.module and not BT.Enabled(c.module) then
		BT.Util.Print(("%s is switched off · /bt to turn it back on"):format(
			(BT.GetModule(c.module) or {}).title or c.module))
		return true
	end
	c.fn(rest or "")
	return true
end

-- ---------------------------------------------------------------------------
-- THE BOOK
-- ---------------------------------------------------------------------------

-- deep copy anything missing, so a setting added in a later version arrives
-- without wiping what is already saved
local function fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function newBook()
	return { players = {}, stats = { sightings = 0 } }
end

function BT.ScopeKey(realm, faction)
	realm = (realm or "?"):gsub("%s+", "")
	return realm .. "|" .. (faction or "?"), realm, (faction or "?")
end

-- WHAT THE CLIENT HANDED US (Josh 2026-09-19). A morning came where a book of
-- 1,913 characters came up empty and nothing in the addon could say why. This
-- is the witness: the state of the saved variables recorded BEFORE a single
-- line of ours has touched them. /bt boot reads it back.
function BT.BootReport()
	local r = { type = type(BeebModDB), books = {}, total = 0 }
	if type(BeebModDB) == "table" then
		r.schema = BeebModDB.schema
		r.settings = type(BeebModDB.settings) == "table"
		for key, book in pairs(BeebModDB.realms or {}) do
			local n = 0
			for _ in pairs(book.players or {}) do
				n = n + 1
			end
			r.books[#r.books + 1] = { key = key, n = n }
			r.total = r.total + n
		end
		table.sort(r.books, function(a, b) return a.n > b.n end)
	end
	return r
end

-- Point BT.db at the book for this character. Called once the realm and
-- faction are known, which is PLAYER_ENTERING_WORLD rather than ADDON_LOADED.
--
-- The core only binds. Anything that has to walk every character - migrating
-- tags, sweeping marks whose meaning has changed - belongs to the module that
-- owns that meaning, and arrives through OnBind. A module that is switched off
-- must never get the chance to tidy away data it is not currently displaying.
-- A LOADING SCREEN IS NOT A LOGIN (Josh 2026-09-23, audit). Binding ran on
-- every PLAYER_ENTERING_WORLD - every zone-in and instance - and each one
-- walked the whole book twice, re-applied the fonts and the theme (every
-- panel repainted, every module restyled), and moved the login figures /bt
-- boot reports. A zone-in with the same book already bound only tells the
-- modules again: the client re-lays some of its frames out on a loading
-- screen, and they put their dressing back. Anything else is a full Bind.
-- THE CENSUS UNSHARED (schema 13, Josh 2026-09-26: "kill the whole census
-- sharing concept"): what other copies told us is not ours, and nor are the
-- settings and the log the sharing kept. Once, on the login after it went.
function BT.Unshare()
	BT.heardDropped = BT.DB and BT.DB.DropHeard(BeebModDB.realms) or 0
	BeebModDB.commsProbe = nil
	local s = BeebModDB.settings
	if s then
		s.shareCensus, s.commsHello = nil, nil
	end
	return BT.heardDropped
end

function BT.Rebind(realm, faction)
	local key = BT.ScopeKey(realm, faction)
	if BT.db and BT.scope and BT.scope.key == key and type(BeebModDB) == "table"
		and type(BeebModDB.realms) == "table" and BeebModDB.realms[key] == BT.db then
		BT.EachLive("OnBind", BT.db, BeebModDB.schema or BT.SCHEMA)
		return BT.db, true
	end
	return BT.Bind(realm, faction), false
end

function BT.Bind(realm, faction)
	BT.Adopt()
	BT.boot = BT.boot or BT.BootReport()
	if type(BeebModDB) ~= "table" then
		BeebModDB = {}
	end
	fill(BeebModDB, { schema = BT.SCHEMA, settings = BT.SETTINGS, realms = {} })
	local key, rname, fname = BT.ScopeKey(realm, faction)
	BeebModDB.realms[key] = BeebModDB.realms[key] or newBook()
	fill(BeebModDB.realms[key], newBook())
	BT.settings = BeebModDB.settings
	BT.db = BeebModDB.realms[key]
	BT.scope = { key = key, realm = rname, faction = fname }
	-- before the modules get their OnBind: a module that sweeps marks whose tag
	-- it cannot find would erase your judgements while the characters they
	-- were about are being restored
	BT.TakeBaked(key)
	-- the same realm under two spellings is one realm
	local folded = BT.DB and BT.DB.FoldRealms(BT.db, rname) or 0
	if folded > 0 then
		BT.foldedOnLoad = folded
	end
	-- EVERY BOOK IN ONE SHAPE (Josh 2026-09-24): the realm off the keys of
	-- the other books too (each by its own realm), and the GUID index no
	-- book saves any more (DB.ByGuid) off all of them - as well as off what
	-- you wrote, which is keyed the same way, before it is read back below
	if BT.DB then
		for otherKey, book in pairs(BeebModDB.realms) do
			if type(book) == "table" then
				book.guids = nil
				local r = type(otherKey) == "string" and otherKey:match("^(.-)|")
				if book ~= BT.db and r and r ~= "?" and type(book.players) == "table" then
					BT.DB.FoldRealms(book, r)
				end
			end
		end
	end
	-- THE BOOK'S OWN HYGIENE IS THE CORE'S (Josh 2026-09-19). Dropping rows
	-- that are a name and nothing else says nothing about what anybody thinks
	-- of them, so it belongs here rather than in a module - and it runs once,
	-- on the login after a version that could still create them.
	local wasSchema = BeebModDB.schema or 1
	BeebModDB.schema = BT.SCHEMA
	if wasSchema < BT.SCHEMA and BT.DB then
		local gone = BT.DB.Cleanup(BT.db)
		if gone > 0 then
			BT.cleanedOnLoad = gone
		end
		-- SIX FIELDS OFF EVERY ROW (Josh 2026-09-20). Written by a version
		-- that stored what it could compute, and worth about six hundred
		-- kilobytes of a file this client will not read back if it is too big.
		local slimmed = BT.DB.Slim(BT.db)
		if slimmed > 0 then
			BT.slimmedOnLoad = slimmed
		end
		if wasSchema < 13 then
			BT.Unshare()
		end
	end
	BT.boot.bound = key
	BT.boot.boundCount = 0
	for _ in pairs(BT.db.players or {}) do
		BT.boot.boundCount = BT.boot.boundCount + 1
	end

	-- the whole book from the per-character file, if the account one brought
	-- none - then what you wrote, which is the floor under both
	BT.TakeStashed(key)
	BT.TakeStashedSettings()
	-- after the stashes, which would otherwise bring them back
	BT.DropRetired()
	-- a switch for each feature, once, from the modules you already have on
	BT.SeedFeatures()
	-- the modules in your order, before the rail or the dock is laid out
	BT.SortModules()
	-- BEFORE ANYTHING DRAWS (Josh 2026-09-21). The fill and the rim are a
	-- setting now, and the class preset cannot be read until there is a
	-- player to read it off - so the colours are put in place here, while the
	-- modules that use them are still being bound.
	-- the face the toolkit writes in is a setting too (Core/Fonts.lua)
	if BT.Fonts then
		pcall(BT.Fonts.Apply)
	end
	if BT.Theme then
		pcall(BT.Theme.Apply)
	end
	BT.EachLive("OnBind", BT.db, wasSchema)
	return BT.db
end

-- THE BAKED BOOK (Josh 2026-09-19). This client writes saved variables
-- correctly and then hands the addon nothing at load, so a book that lives
-- only in SavedVariables disappears every login. Data/Baked.lua is the same
-- book as an addon FILE, and addon files always load. It is taken ONLY when
-- the saved variables came up empty, so the day the client is fixed this stops
-- happening on its own - and a book you have deliberately emptied does not
-- refill itself, because by then the saved variables are arriving.
function BT.TakeBaked(key)
	local baked = BT.baked
	if not (type(baked) == "table" and type(baked.realms) == "table" and BT.DB) then
		return 0
	end
	local from = baked.realms[key]
	local book = BeebModDB.realms[key]
	if type(from) ~= "table" or type(book) ~= "table" then
		return 0
	end
	-- THE SAVE ARRIVED, SO THE BAKED FILE ONLY FILLS GAPS (Josh 2026-09-22).
	-- With the live file linked in, the book comes back on every launch and
	-- the baked copy stops being the seed. It still knows characters the saves
	-- lost while this was being worked out, so on the way out it hands over
	-- any the book has not got - whole, into every book it carries - and
	-- leaves every row the book already has exactly as it is.
	if next(book.players or {}) then
		local added = 0
		for otherKey, other in pairs(baked.realms) do
			local into = BeebModDB.realms[otherKey]
			if type(into) ~= "table" then
				into = newBook()
				BeebModDB.realms[otherKey] = into
			end
			into.players = into.players or {}
			for who in pairs(type(other) == "table" and other.players or {}) do
				if not into.players[who] then
					-- as a table: a packed row reads only with its own words
					into.players[who] = BT.DB.Get(other, who)
					added = added + 1
				end
			end
		end
		BT.bakedTaken = added > 0 and added or nil
		BT.bakedFilled = true
		return added
	end
	-- SETTINGS COME BACK TOO (Josh 2026-09-19). This used to restore the book
	-- and the tags and nothing else, so every login handed back two thousand
	-- characters and a factory-fresh addon: the dock back under the minimap,
	-- every module switched on again, the tooltip back to full size. It read
	-- as "the position does not save", and what was actually happening is that
	-- NOTHING saved except the book.
	--
	-- Only when the file brought no settings of its own: the moment the client
	-- starts handing saved variables back, they win and this stops happening.
	if baked.settings and not (BT.boot and BT.boot.settings) then
		for k, v in pairs(baked.settings) do
			BT.settings[k] = v
		end
		BT.bakedSettings = true
	end
	local added = BT.DB.Adopt(book, from)
	BT.bakedTaken = added
	-- AND EVERY OTHER BOOK IT CARRIES (Josh 2026-09-21). Only this realm and
	-- faction's book used to come across, so an alt's book - 430 Horde
	-- characters - lived nowhere but here. The companion is written from what
	-- is bound, so everything the baked file knows goes in on the first login.
	for otherKey, other in pairs(baked.realms) do
		if otherKey ~= key and type(other) == "table"
			and type(BeebModDB.realms[otherKey]) ~= "table" then
			BeebModDB.realms[otherKey] = other
		end
	end
	return added
end

-- IF THE BOOK TURNS UP LATE (Josh 2026-09-19). The addon must not decide, at
-- one instant, that everything you collected is gone. If the saved variables
-- land after we have already bound an empty book - a client that delivers them
-- late, or out of order - this notices, takes the real one, and keeps what was
-- seen while we waited.
function BT.AcceptLateBook()
	local sc = BT.scope
	if not (sc and BT.db and type(BeebModDB) == "table" and type(BeebModDB.realms) == "table") then
		return false
	end
	local live = BeebModDB.realms[sc.key]
	if live == BT.db then
		return false -- the same table we have been writing in: nothing arrived
	end
	local n = 0
	for _ in pairs((live and live.players) or {}) do
		n = n + 1
	end
	if n == 0 then
		return false
	end
	local session = BT.db
	BT.Bind(sc.realm, sc.faction)
	local added = BT.DB.Adopt(BT.db, session)
	-- kept for /bt boot rather than announced: nothing is printed at login
	BT.lateBook = { found = n, kept = added }
	return true
end

-- Keep looking for a while rather than once: the client's timing is the thing
-- we are least sure of.
function BT.WatchForBook()
	if not (C_Timer and C_Timer.After) then
		return
	end
	local tries = 0
	local function look()
		tries = tries + 1
		if BT.AcceptLateBook() then
			if BT.Window and BT.Window.Refresh then
				BT.Window.Refresh()
			end
			return
		end
		if tries < 6 then
			C_Timer.After(tries * 2, look)
		end
	end
	C_Timer.After(1, look)
end

-- Bind late if something ate PLAYER_ENTERING_WORLD: no command should fail
-- silently just because the event that normally binds never arrived.
function BT.EnsureBound()
	if BT.db and BT.settings then
		return true
	end
	BT.Bind(GetRealmName and GetRealmName(), UnitFactionGroup and UnitFactionGroup("player"))
	return BT.db ~= nil
end

-- Every book in the file, this character's first. The key here is the REAL
-- one, because it is what /bt adopt takes.
function BT.Books()
	local out = {}
	for key, book in pairs(BeebModDB and BeebModDB.realms or {}) do
		local n = 0
		for _ in pairs(book.players or {}) do
			n = n + 1
		end
		out[#out + 1] = { key = key, n = n, mine = key == (BT.scope and BT.scope.key) }
	end
	table.sort(out, function(a, b)
		if a.mine ~= b.mine then return a.mine end
		return a.n > b.n
	end)
	return out
end

-- Move another book's characters into this one. Matching is loose on purpose:
-- you type what /bt books showed you, spaces and all.
function BT.AdoptBook(text)
	if not (BT.db and text and text ~= "") then
		return nil
	end
	local want = text:lower():gsub("[%s|]", "")
	for key, book in pairs(BeebModDB and BeebModDB.realms or {}) do
		if key ~= (BT.scope and BT.scope.key) and key:lower():gsub("[%s|]", "") == want then
			local added, folded = BT.DB.Adopt(BT.db, book)
			return { key = key, added = added, folded = folded }
		end
	end
	return nil
end

-- What your other books hold, for /bt stats.
function BT.OtherBooks()
	local out = {}
	for key, book in pairs(BeebModDB and BeebModDB.realms or {}) do
		if key ~= (BT.scope and BT.scope.key) then
			local n = 0
			for _ in pairs(book.players or {}) do
				n = n + 1
			end
			out[#out + 1] = { key = (key:gsub("|", " ")), n = n }
		end
	end
	table.sort(out, function(a, b) return a.n > b.n end)
	return out
end

-- ---------------------------------------------------------------------------
-- The Ledger keeps what you write in a book of its own now (Josh 2026-09-26,
-- Modules/Ledger/Store.lua), in the account file this client hands back
-- since build 70009. BeebModKeep is read once more, by the Ledger's move, and
-- written no longer.

-- ---------------------------------------------------------------------------
-- THE WHOLE BOOK, IN THE ONE CHANNEL THAT HAS COME BACK
-- ---------------------------------------------------------------------------
--
-- Measured rather than assumed (Josh 2026-09-21). The account file is written
-- perfectly - eighteen kilobytes, valid Lua, every character in it - and the
-- client hands back nothing at load. The per-character file HAS come back:
-- /bt boot said so, twice.
--
-- So the book goes there as well. Not on every sighting, which would copy a
-- thousand rows a minute for nothing, but once at PLAYER_LOGOUT - which fires
-- before the client writes its files, and is the last moment the book exists.
--
-- Nothing reads from it while the account book arrives intact. It is a floor.

function BT.StashBook()
	if not (BT.db and BT.scope) then
		return 0
	end
	if type(BeebModChar) ~= "table" then
		BeebModChar = {}
	end
	local n = 0
	for _ in pairs(BT.db.players or {}) do
		n = n + 1
	end
	BeebModChar.book = { key = BT.scope.key, at = BT.Util and BT.Util.Now(), db = BT.db }
	-- no settings: a copy of them goes stale the moment you change one (2026-09-22)
	return n
end

-- Returns how many characters it put back.
function BT.TakeStashed(key)
	local stash = type(BeebModChar) == "table" and BeebModChar.book or nil
	if not (stash and stash.key == key and type(stash.db) == "table" and BT.db) then
		return 0
	end
	local have = 0
	for _ in pairs(BT.db.players or {}) do
		have = have + 1
	end
	if have > 0 then
		return 0 -- the account file arrived: it is the truth, not this
	end
	local back = 0
	BT.db.players = BT.db.players or {}
	local keys = {}
	for who in pairs(stash.db.players or {}) do
		keys[#keys + 1] = who
	end
	for _, who in ipairs(keys) do
		if not BT.db.players[who] then
			BT.db.players[who] = BT.DB.Get(stash.db, who)
			back = back + 1
		end
	end
	for _, field in ipairs({ "stats", "tags" }) do
		if stash.db[field] and not next(BT.db[field] or {}) then
			BT.db[field] = stash.db[field]
		end
	end
	-- THE CACHES KEY OFF THE REVISION (Josh 2026-09-21). Rows put back here go
	-- straight into the table rather than through DB.SetNote and friends, so
	-- nothing bumped the counter the census and the search cache their answers
	-- against - and the window opened on a book it had already decided the
	-- shape of. It read as "the data is there but the panel is a tab behind".
	if back > 0 and BT.DB then
		BT.DB.rev = (BT.DB.rev or 0) + 1
	end
	BT.stashTaken = back > 0 and back or nil
	return back
end

-- THE SETTINGS WERE STASHED AND NEVER TAKEN BACK (Josh 2026-09-21). Logout
-- wrote them into the per-character file along with the book, which is the one
-- channel this client actually hands back - and then nothing read them. So
-- every choice on the Settings tab survived to disk and died at the next
-- login: the theme reverted, switched-off modules came back on, and it looked
-- as though nothing had been saved at all.
--
-- A setting the account file DID bring is the truth; this only fills in what
-- came back empty, which on this client is everything.
function BT.TakeStashedSettings()
	-- THE REAL SETTINGS ARRIVED, SO THE COPIES ARE STALE (Josh 2026-09-22).
	-- With the Data\Live link the account file comes back every launch, and
	-- an older copy filling its "gaps" undid what you had changed since. The
	-- copies are dropped so they cannot do it on some later login either.
	if BT.boot and BT.boot.settings then
		for _, store in ipairs({ BeebModChar, BeebModKeep }) do
			if type(store) == "table" then
				store.settings = nil
			end
		end
		return 0
	end
	local stash = type(BeebModChar) == "table" and BeebModChar.settings or nil
	if not (type(stash) == "table" and type(BT.settings) == "table") then
		return 0
	end
	local back = 0
	for key, value in pairs(stash) do
		if BT.settings[key] == nil then
			BT.settings[key] = value
			back = back + 1
		elseif key == "modules" and type(value) == "table" then
			-- the defaults create this table empty, so "already there" is not
			-- the same as "already answered": a module you switched OFF is a
			-- key inside it, and those have to come across one at a time
			for mod, on in pairs(value) do
				if BT.settings.modules[mod] == nil then
					BT.settings.modules[mod] = on
					back = back + 1
				end
			end
		end
	end
	BT.settingsTaken = back > 0 and back or nil
	return back
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
-- NO SECOND COPY AT LOGOUT (Josh 2026-09-22). The whole book used to be
-- stashed in the per-character file as well, in case that channel came back
-- when the account one did not. Neither did - and since build 70009 the
-- client reads saved variables back the ordinary way (Josh 2026-09-24) - so
-- the stash was 2.9 MB written at every logout for nothing. BT.StashBook and
-- BT.TakeStashed stay for a file that still has one; Adopt and BT.linked stay
-- as a net should a later build lose the book again.
loader:SetScript("OnEvent", function(_, event, addon)
	if addon ~= ADDON then
		return
	end
	-- the live file's book, if the client's loader cleared it after it ran
	BT.Adopt()
	if type(BeebModDB) ~= "table" and BT.linked then
		BeebModDB = BT.linked
		BT.linkedRestored = true
	end
	-- before anything of ours runs: what actually arrived in the file
	BT.boot = BT.BootReport()
	-- DO NOT CREATE THE GLOBAL HERE (Josh 2026-09-19). It used to be created
	-- the moment the addon was told it had loaded, which is the one thing that
	-- could stop a late delivery from landing: a client that declines to
	-- overwrite a global the addon already made would leave us writing into an
	-- orphan for the rest of the session. BT.Bind makes it, later, and only if
	-- nothing has turned up by then.
	if BT.Collect and BT.Collect.Start then
		BT.Collect.Start() -- events only; nothing is written until BT.Bind runs
	end
	-- if the client kept the loading screen from us, log in now (Core/Boot.lua)
	if BT.Boot then
		BT.Boot.Fallback()
	end
end)
