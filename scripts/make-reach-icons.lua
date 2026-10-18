--[[ scripts/make-reach-icons.lua (Josh 2026-10-18): the resource display's
two other reach icons, beside its crosshair (Art/crosshair.tga, drawn by
scripts/make-crosshair.py).

  Art/reach-melee.tga   two crossed swords: your target is in melee range
  Art/reach-close.tga   a ring with a bar across it: too close for your
                        ranged attack, too far for melee (the dead zone)

Josh: "maybe we should use a green crosshairs icon if in ranged range, and a
new melee icon if in melee range. For the deadzone, we could use a new
cancel or no action icon."

64x64 and WHITE, with the shape in the alpha channel, as the crosshair is, so
one vertex colour tints each. The ring is the crosshair's outer ring, so the
three read as one set. Lua, as scripts/make-cards.lua is, so it needs
nothing but the Lua the tests run on. Every pixel is sampled 8 x 8 times
and averaged, as that script does.

    lua scripts/make-reach-icons.lua
]]
local here = arg and arg[0] and arg[0]:match("^(.*)[/\\]") or "."
local OUT = here .. "/../Art/"

local SIZE, S = 64, 8
local C = SIZE / 2
local SQ2 = math.sqrt(2)

-- the crosshair's outer ring: radius to the middle of the stroke, and the
-- stroke (scripts/make-crosshair.py, OUTER and OUTER_W)
local RING, RING_W = 21, 5.5

-- the ring with a bar across it, top left to bottom right
local function close(x, y)
	local dx, dy = x - C, y - C
	local d = math.sqrt(dx * dx + dy * dy)
	if math.abs(d - RING) <= RING_W / 2 then
		return true
	end
	-- the bar: as wide as the ring, from one side of it to the other
	if d <= RING then
		local across = math.abs(dx - dy) / SQ2
		return across <= RING_W / 2
	end
	return false
end

-- A SWORD along an axis from its tip: `u` from the tip toward the pommel,
-- `v` across. Each part is a stretch of `u` and how far across it reaches.
local PARTS = {
	-- the blade, coming to a point over its first 8
	{ from = 0, to = 42, half = function(u) return 3.6 * math.min(1, u / 8) end },
	-- the guard, short enough that the two guards do not meet
	{ from = 41.5, to = 46, half = function() return 7.5 end },
	-- the grip
	{ from = 46, to = 54.5, half = function() return 2.6 end },
}
local POMMEL_U, POMMEL_R = 57.5, 4
-- the tips: in from the sides, and down from the top so the pair is centred
local TIP_X, TIP_Y = 8, 9

-- whether (x, y) is on a sword whose tip is at (tx, ty), pointing along
-- (dx, dy) toward its pommel; `grow` widens it, for the gap round the other
local function onSword(x, y, tx, ty, dx, dy, grow)
	local px, py = x - tx, y - ty
	local u = px * dx + py * dy
	local v = math.abs(-px * dy + py * dx)
	for _, part in ipairs(PARTS) do
		if u >= part.from - grow and u <= part.to + grow and v <= part.half(math.max(part.from, math.min(part.to, u))) + grow then
			return true
		end
	end
	local qx, qy = px - POMMEL_U * dx, py - POMMEL_U * dy
	return math.sqrt(qx * qx + qy * qy) <= POMMEL_R + grow
end

-- two swords crossed, tips up; the second lies over the first, with a gap
-- cut round it so the two read as two
local GAP = 2
local function melee(x, y)
	local d = 1 / SQ2
	local over = onSword(x, y, SIZE - TIP_X, TIP_Y, -d, d, 0)
	if over then
		return true
	end
	return onSword(x, y, TIP_X, TIP_Y, d, d, 0) and not onSword(x, y, SIZE - TIP_X, TIP_Y, -d, d, GAP)
end

-- every pixel sampled S x S times; white, the coverage in the alpha
local function render(shape)
	local rows = {}
	for py = 0, SIZE - 1 do
		local row = {}
		for px = 0, SIZE - 1 do
			local n = 0
			for sy = 0, S - 1 do
				for sx = 0, S - 1 do
					if shape(px + (sx + 0.5) / S, py + (sy + 0.5) / S) then
						n = n + 1
					end
				end
			end
			row[#row + 1] = string.char(255, 255, 255, math.floor(n / (S * S) * 255 + 0.5))
		end
		rows[#rows + 1] = table.concat(row)
	end
	return table.concat(rows)
end

-- uncompressed 32-bit TGA, top row first, blue-green-red-alpha: what the
-- client reads (white, so the order of the colours does not matter)
local function save(name, pixels)
	local head = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, SIZE % 256, SIZE // 256, SIZE % 256, SIZE // 256, 32, 0x28)
	local f = assert(io.open(OUT .. name, "wb"))
	f:write(head, pixels)
	f:close()
	print("wrote Art/" .. name)
end

save("reach-melee.tga", render(melee))
save("reach-close.tga", render(close))
