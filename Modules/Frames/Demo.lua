-- The unit frames' made-up group (Core/Demo.lua, Josh 2026-09-27): the same
-- made-up party and full buff tray the Testing page shows one at a time, both
-- at once, with the rest of the made-up data. Each only while its module is on.
local _, BT = ...

local function frames()
	local m = BT.GetModule("frames")
	return m and m.live and m.Preview and m or nil
end

local function buffs()
	local B = BT.UnitFrames and BT.UnitFrames.Buffs
	local m = BT.GetModule("buffs")
	return B and m and m.live and B or nil
end

BT.Demo.Register("frames", {
	on = function()
		local m = frames()
		if m then
			m.Preview("party")
		end
		local B = buffs()
		if B then
			B.Build()
			B.Preview(true)
		end
	end,
	off = function()
		local m = frames()
		if m then
			m.Preview(nil)
		end
		local B = buffs()
		if B and B.previewing then
			B.Preview(false)
		end
	end,
})
