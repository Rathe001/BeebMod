-- The Ledger's made-up notes (Core/Demo.lua, Josh 2026-09-27): a dozen of the
-- made-up people - the same ones the census shows, when it is on - and you,
-- written on with notes, tags and ratings. Target or hover yourself to see a
-- note on a tooltip and in the dock. None of it is saved: while it is shown
-- the Ledger reads this book instead of yours (BT.Notes.People).
local _, BT = ...

local N = BT.Notes

local NOTES = {
	{ "Tanked the whole of the Deadmines without a wipe. Invite again.", { good = true }, 5 },
	{ "Ninja'd the Cruel Barb on a need roll. Never again.", { bad = true }, 1 },
	{ "Calm healer, kept us up through Mor'Ladim twice.", { good = true }, 5 },
	{ "Sells mageweave cheap on Tuesday nights.", nil, 4 },
	{ "Knows every step of the Uldaman key quest.", { good = true }, 4 },
	{ "Chatty, but a solid rogue in a pinch.", nil, 3 },
	{ "Went afk at every boss in Scarlet Monastery.", { bad = true, troll = true }, 2 },
	{ "Recruits for Night Watch. Asked about raiding.", nil, nil },
	{ "Spams the trade channel with jokes.", { troll = true }, 2 },
	{ "Brought portals to Ironforge for the whole group.", { good = true }, 5 },
	{ nil, { good = true }, 4 },
	{ "Owes me 3 gold for the Blue Pearl.", nil, nil },
}
local ALTS = { "Beeb Magus", "Beeb Straffe", "Beeb Lighthammer" }

local book

local function build()
	local U = BT.Util
	local now = U.Now()
	local people = {}
	local list = BT.Demo.People(60)
	-- spread across the list, so the notes are on people seen at every age
	for i, n in ipairs(NOTES) do
		local who = list[1 + (i - 1) * 4]
		local key = U.Key(who.name)
		if key then
			people[key] = {
				name = who.name, class = who.class, race = who.race, level = who.level, guild = who.guild,
				last = now - who.ago,
				note = n[1], noted = n[1] and (now - i * 86400 * 2) or nil,
				notedBy = n[1] and ALTS[1 + (i % #ALTS)] or nil,
				flags = n[2], rating = n[3],
			}
		end
	end
	-- and you, so a note can be seen on a tooltip without anybody else about
	-- keyed as the Ledger keys anyone: the name alone on your own realm
	local me = U.Me and U.Me() and U.Key(U.Me())
	if me then
		local _, class = UnitClass and UnitClass("player")
		people[me] = {
			name = U.Me and U.Me() or me, class = class, level = UnitLevel and UnitLevel("player") or nil,
			note = "Always first to the mailbox after a dungeon. Good company.", noted = now - 3 * 86400,
			notedBy = ALTS[1], flags = { good = true }, rating = 5, last = now,
		}
	end
	return people
end

BT.Demo.Register("ledger", {
	on = function()
		book = book or build()
		N.demo = book
	end,
	off = function()
		N.demo = nil
	end,
})
