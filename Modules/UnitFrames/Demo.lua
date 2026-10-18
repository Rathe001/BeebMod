-- The unit frames' part of the made-up data (Core/Demo.lua, Josh 2026-09-27):
-- the full buff tray the Testing page's Made-up auras shows, with the rest of
-- the made-up data, while Buffs is on.
-- NOT THE MADE-UP PARTY (Josh 2026-10-18: "when I load the fake data, it auto
-- enables the group debug view for unit frames"). It drew the party too,
-- while the Made-up people row still said Off; the party is that row's alone.
local _, BT = ...

local function buffs()
	local B = BT.UnitFrames and BT.UnitFrames.Buffs
	local m = BT.GetModule("buffs")
	return B and m and m.live and B or nil
end

BT.Demo.Register("unitframes", {
	on = function()
		local B = buffs()
		if B then
			B.Build()
			B.Preview(true)
		end
	end,
	off = function()
		local B = buffs()
		if B and B.previewing then
			B.Preview(false)
		end
	end,
})
