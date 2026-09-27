-- The census's made-up realm (Core/Demo.lua, Josh 2026-09-27): fifteen
-- hundred characters of your side, in a book of their own that is never
-- saved. While it is shown, BT.db is that book - so every chart, the census
-- window, Find and the tooltip's "Was in" line read it - and your own is put
-- back when the switch goes off, or bound again at a loading screen.
local _, BT = ...

local CD = { size = 1500 }
BT.CensusDemo = CD

local real, book

local function build()
	local U, DB = BT.Util, BT.DB
	local now = U.Now()
	local b = { players = {}, stats = { sightings = 0 }, realm = BT.scope and BT.scope.realm, demo = true }
	for _, who in ipairs(BT.Demo.People(CD.size)) do
		local when = now - who.ago
		local p = DB.Note(b, who.name, nil, {
			class = who.class, race = who.race, level = who.level, zone = who.zone, vouch = true,
			guild = who.formerGuild or who.guild,
		}, who.formerGuild and when - 20 * 86400 or when)
		if p then
			-- a guild changed along the way, for the tooltip's "Was in"
			if who.formerGuild then
				DB.SetGuild(p, who.guild, when)
			end
			p.last = when
			p.first = when - (who.ago % (40 * 86400))
			p.seen = 1 + (who.level % 9)
			b.stats.sightings = b.stats.sightings + p.seen
		end
	end
	return b
end

local function swapIn()
	if not (BT.DB and BT.db) then
		return
	end
	book = book or build()
	if BT.db ~= book then
		real = BT.db
		BT.db = book
	end
end

BT.Demo.Register("census", {
	on = swapIn,
	off = function()
		if real and BT.db == book then
			BT.db = real
		end
		real = nil
	end,
	-- the loading screen bound your own book again: that is the one to give back
	world = function()
		if BT.db ~= book then
			real = BT.db
			BT.db = book
		end
	end,
})

-- the made-up book, for the tests
function CD.Book()
	return book
end
