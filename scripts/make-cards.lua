--[[ scripts/make-cards.lua (Josh 2026-09-26): the Menagerie card's ornaments.

The card's border is its mastery, and it gathers ornament as the mastery
climbs (chosen from the mockup, round four): a stepped corner at Bronze, the
toolkit's diamond on it at Silver, a fan behind that and a crest, studs and a
fan under the name at Gold, and at Platinum a sunburst crest with wings,
stepped side ornaments, a pendant and gems. Everything is drawn here, WHITE,
and the client tints it the tier's metal - so one set of art serves all five.
The gem and the crests' dark fills carry grey in them, which survives the tint
as shading.

Lua, not Python like scripts/make-rank.py: this machine has no Python. The
same method all the same - every pixel sampled 8 x 8 times and averaged, so a
one-unit line lands clean and a slant is smoothed.

    lua scripts/make-cards.lua

writes Art/Cards/*.tga. Coordinates are in DESIGN UNITS - the mockup's card
was 184 units wide - at two pixels a unit, so the art stays crisp when the
card is drawn larger than the mockup and is only brought down when smaller.
Modules/Menagerie/Card.lua places each piece by the same units.]]
local here = arg and arg[0] and arg[0]:match("^(.*)[/\\]") or "."
local OUT = here .. "/../Art/Cards/"

local S = 8   -- samples a pixel, each way
local R = 2   -- pixels a design unit

-- ---------------------------------------------------------------------------
-- Shapes: each says whether a point (in design units) is inside it
-- ---------------------------------------------------------------------------

local function segDist(px, py, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local len2 = dx * dx + dy * dy
	local t = len2 > 0 and math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / len2)) or 0
	local qx, qy = x1 + t * dx - px, y1 + t * dy - py
	return math.sqrt(qx * qx + qy * qy)
end

-- a path through points, `w` units wide, with square ends
local function path(pts, w, v, a)
	return { kind = "path", pts = pts, w = w or 1.3, v = v or 1, a = a or 1 }
end

local function poly(pts, v, a)
	return { kind = "poly", pts = pts, v = v or 1, a = a or 1 }
end

-- a hole: whatever is under it goes clear
local function hole(pts)
	return { kind = "poly", pts = pts, hole = true }
end

-- an arc about (cx, cy) from angle a0 to a1 (degrees, y down), `w` wide
local function arc(cx, cy, r, a0, a1, w, v, a)
	return { kind = "arc", cx = cx, cy = cy, r = r, a0 = a0, a1 = a1, w = w or 1.3, v = v or 1, a = a or 1 }
end

-- a filled wedge of a disc, for a fan's dark ground
local function wedge(cx, cy, r, a0, a1, v, a)
	return { kind = "wedge", cx = cx, cy = cy, r = r, a0 = a0, a1 = a1, v = v or 1, a = a or 1 }
end

local function diamond(cx, cy, r)
	return { { cx, cy - r }, { cx + r, cy }, { cx, cy + r }, { cx - r, cy } }
end

local function inPoly(px, py, pts)
	local inside = false
	local j = #pts
	for i = 1, #pts do
		local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
		if (yi > py) ~= (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function angleIn(px, py, cx, cy, a0, a1)
	local a = math.deg(math.atan(py - cy, px - cx)) % 360
	a0, a1 = a0 % 360, a1 % 360
	if a0 <= a1 then
		return a >= a0 - 0.01 and a <= a1 + 0.01
	end
	return a >= a0 - 0.01 or a <= a1 + 0.01
end

local function inside(sh, x, y)
	if sh.kind == "path" then
		local h = sh.w / 2
		for i = 1, #sh.pts - 1 do
			local p, q = sh.pts[i], sh.pts[i + 1]
			-- square ends: a straight run is a rectangle, not a sausage
			if p[1] == q[1] or p[2] == q[2] then
				local x0, x1 = math.min(p[1], q[1]) - h, math.max(p[1], q[1]) + h
				local y0, y1 = math.min(p[2], q[2]) - h, math.max(p[2], q[2]) + h
				if x >= x0 and x <= x1 and y >= y0 and y <= y1 then
					return true
				end
			elseif segDist(x, y, p[1], p[2], q[1], q[2]) <= h then
				return true
			end
		end
		return false
	elseif sh.kind == "poly" then
		return inPoly(x, y, sh.pts)
	elseif sh.kind == "arc" then
		local d = math.sqrt((x - sh.cx) ^ 2 + (y - sh.cy) ^ 2)
		return math.abs(d - sh.r) <= sh.w / 2 and angleIn(x, y, sh.cx, sh.cy, sh.a0, sh.a1)
	elseif sh.kind == "wedge" then
		local d = math.sqrt((x - sh.cx) ^ 2 + (y - sh.cy) ^ 2)
		return d <= sh.r and angleIn(x, y, sh.cx, sh.cy, sh.a0, sh.a1)
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Drawing: later shapes over earlier ones, a hole clears what is under it
-- ---------------------------------------------------------------------------

local function render(w, h, shapes, shade)
	local pw, ph = w * R, h * R
	local px = {}
	for j = 0, ph - 1 do
		for i = 0, pw - 1 do
			local cov, val = 0, 0
			for sj = 0, S - 1 do
				for si = 0, S - 1 do
					local x = (i + (si + 0.5) / S) / R
					local y = (j + (sj + 0.5) / S) / R
					local a, v = 0, 0
					for _, sh in ipairs(shapes) do
						if inside(sh, x, y) then
							if sh.hole then
								a, v = 0, 0
							else
								a, v = sh.a, sh.v
							end
						end
					end
					if shade and a > 0 then
						v = v * shade(x, y)
					end
					cov = cov + a
					val = val + v * a
				end
			end
			local n = S * S
			local alpha = cov / n
			local grey = cov > 0 and val / cov or 1
			px[#px + 1] = { grey, alpha }
		end
	end
	return { w = pw, h = ph, px = px }
end

-- 32-bit TGA, top row first, white-or-grey with the drawing in the alpha
local function save(name, img)
	local f = assert(io.open(OUT .. name .. ".tga", "wb"))
	local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
	f:write(string.char(0, 0, 2), string.rep("\0", 5), u16(0), u16(0), u16(img.w), u16(img.h), string.char(32, 0x28))
	local out = {}
	for _, p in ipairs(img.px) do
		local g = math.floor(math.max(0, math.min(1, p[1])) * 255 + 0.5)
		local a = math.floor(math.max(0, math.min(1, p[2])) * 255 + 0.5)
		out[#out + 1] = string.char(g, g, g, a)
	end
	f:write(table.concat(out))
	f:close()
	print(("wrote Art/Cards/%s.tga (%dx%d)"):format(name, img.w, img.h))
end

-- the dark inside a crest: the card's own colour once the tint is on it
local FILL = 0.09

-- ---------------------------------------------------------------------------
-- The corners. The card's corner is at (C, C); its outer line runs 0.75
-- units in from the edge and its inner line 4.5 in, the lines the card draws
-- between the corners (starting OUTER_RUN and INNER_RUN from the corner).
-- ---------------------------------------------------------------------------

local C = 12

local function corner(tier)
	local s = {}
	-- Bronze: the double line turns the corner in a stepped notch
	s[#s + 1] = path({ { C + 0.75, C + 11 }, { C + 0.75, C + 6 }, { C + 6, C + 6 }, { C + 6, C + 0.75 }, { C + 11, C + 0.75 } })
	s[#s + 1] = path({ { C + 4.5, C + 13 }, { C + 4.5, C + 9.5 }, { C + 9.5, C + 9.5 }, { C + 9.5, C + 4.5 }, { C + 13, C + 4.5 } })
	if tier >= 3 then
		-- Gold: a fan behind the point, out past the corner
		s[#s + 1] = arc(C, C, 8, 180, 270, 1)
		s[#s + 1] = arc(C, C, 10.5, 180, 270, 1, 1, 0.7)
		for _, d in ipairs({ { -7, -4.5 }, { -4.5, -7 }, { -6, -6 } }) do
			s[#s + 1] = path({ { C, C }, { C + d[1], C + d[2] } }, 1)
		end
	end
	if tier >= 2 then
		-- Silver: the toolkit's diamond at the point, cut out in the middle
		s[#s + 1] = poly(diamond(C, C, 5))
		s[#s + 1] = hole(diamond(C, C, 2))
	end
	if tier >= 4 then
		-- Platinum: a diamond on each line as it leaves the corner
		s[#s + 1] = poly(diamond(C + 16, C + 0.75, 2.5))
		s[#s + 1] = poly(diamond(C + 0.75, C + 16, 2.5))
	end
	return render(32, 32, s)
end

-- ---------------------------------------------------------------------------
-- The crests on the top edge: (CX, BASE) sits on the card
-- ---------------------------------------------------------------------------

local function rays(cx, cy, r, from, to, step, w, a)
	local out = {}
	for deg = from, to, step do
		local rad = math.rad(deg)
		out[#out + 1] = path({ { cx, cy }, { cx + r * math.cos(rad), cy + r * math.sin(rad) } }, w or 1, 1, a or 0.75)
	end
	return out
end

local function crest3()
	local cx, cy = 32, 28
	local s = { wedge(cx, cy, 20, 180, 360, FILL) }
	for _, r in ipairs(rays(cx, cy, 18, 210, 330, 30)) do s[#s + 1] = r end
	s[#s + 1] = arc(cx, cy, 14, 180, 360, 1)
	s[#s + 1] = arc(cx, cy, 20, 180, 360, 1.3)
	s[#s + 1] = path({ { cx - 20, cy }, { cx + 20, cy } })
	return render(64, 32, s)
end

local function crest4()
	local cx, cy = 64, 40
	local s = {}
	-- the wings: three stepped lines out either side
	for _, side in ipairs({ -1, 1 }) do
		s[#s + 1] = path({ { cx + side * 22, cy }, { cx + side * 44, cy } }, 1.2)
		s[#s + 1] = path({ { cx + side * 20, cy - 4.5 }, { cx + side * 38, cy - 4.5 } }, 1.2)
		s[#s + 1] = path({ { cx + side * 17, cy - 9 }, { cx + side * 32, cy - 9 } }, 1.2)
	end
	s[#s + 1] = wedge(cx, cy, 22, 180, 360, FILL)
	for _, r in ipairs(rays(cx, cy, 21, 200, 340, 23.3)) do s[#s + 1] = r end
	s[#s + 1] = arc(cx, cy, 15, 180, 360, 1)
	s[#s + 1] = arc(cx, cy, 22, 180, 360, 1.3)
	s[#s + 1] = path({ { cx - 22, cy }, { cx + 22, cy } })
	-- a diamond crowning it, cut out for the gem
	s[#s + 1] = poly(diamond(cx, cy - 26, 5))
	s[#s + 1] = hole(diamond(cx, cy - 26, 2.2))
	return render(128, 64, s)
end

-- the sides: (8, 16) sits on the card's edge, half way down
local function side3()
	return render(16, 32, { poly(diamond(8, 16, 4)) })
end

local function side4()
	return render(16, 32, {
		poly(diamond(8, 16, 5)),
		path({ { 4, 9 }, { 8, 5 }, { 12, 9 } }, 1.1),
		path({ { 4, 23 }, { 8, 27 }, { 12, 23 } }, 1.1),
		path({ { 5.5, 3 }, { 8, 0.8 }, { 10.5, 3 } }, 1.1),
		path({ { 5.5, 29 }, { 8, 31.2 }, { 10.5, 29 } }, 1.1),
	})
end

-- the pendant: its line (32, 6) sits on the card's foot, and it hangs below
local function pendant4()
	local cx, cy = 32, 6
	local s = { wedge(cx, cy, 16, 0, 180, FILL) }
	for _, r in ipairs(rays(cx, cy, 15, 40, 140, 50)) do s[#s + 1] = r end
	s[#s + 1] = arc(cx, cy, 16, 0, 180, 1.3)
	s[#s + 1] = path({ { cx - 16, cy }, { cx + 16, cy } })
	s[#s + 1] = poly(diamond(cx, cy + 20, 3.5))
	return render(64, 32, s)
end

-- the fan under the name: its top line at y 1.5, centred on x 64
local function fan()
	local cx = 64
	local s = { path({ { cx - 35, 1.5 }, { cx + 35, 1.5 } }, 1) }
	-- two half ellipses, drawn as short runs
	for _, e in ipairs({ { 13, 10 }, { 7, 6 } }) do
		local pts = {}
		for deg = 0, 180, 6 do
			local rad = math.rad(deg)
			pts[#pts + 1] = { cx + e[1] * math.cos(rad), 1.5 + e[2] * math.sin(rad) }
		end
		s[#s + 1] = path(pts, 1)
	end
	s[#s + 1] = path({ { cx, 1.5 }, { cx, 12 } }, 1)
	return render(128, 16, s)
end

-- the gem: a faceted diamond, lit from the top left, for the keystone (the
-- rank) and the platinum corners
local function gem()
	return render(16, 16, {
		poly(diamond(8, 8, 7)),
		poly(diamond(8, 8, 3.4), 1.25),
	}, function(x, y)
		-- lighter up and to the left, darker down and to the right
		local t = ((x - 1) + (y - 1)) / 14
		return 1.05 - 0.6 * math.max(0, math.min(1, t))
	end)
end

-- the platinum sheen: a soft band on the diagonal, for sweeping across
local function sheen()
	local w, h = 64, 64
	local img = { w = w, h = h, px = {} }
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local d = ((i + 0.5) - (j + 0.5) * 0.45) - w * 0.36
			local a = math.exp(-(d * d) / (2 * 6 * 6)) * 0.9
			img.px[#img.px + 1] = { 1, a }
		end
	end
	return img
end

-- ---------------------------------------------------------------------------
-- A proof: every piece tinted gold on the card's dark, as a PNG to look at.
-- PNG with STORED deflate blocks - uncompressed, so no zlib is needed, only
-- the two checksums.
-- ---------------------------------------------------------------------------

local function crc32(s)
	local crc = 0xFFFFFFFF
	for i = 1, #s do
		crc = crc ~ s:byte(i)
		for _ = 1, 8 do
			local lsb = crc & 1
			crc = crc >> 1
			if lsb == 1 then crc = crc ~ 0xEDB88320 end
		end
	end
	return crc ~ 0xFFFFFFFF
end

local function adler32(s)
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + s:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return (b << 16) | a
end

local function be32(n) return string.pack(">I4", n & 0xFFFFFFFF) end

local function writePNG(file, w, h, rgb)
	local rows = {}
	for y = 0, h - 1 do
		rows[#rows + 1] = "\0" .. rgb[y + 1]
	end
	local raw = table.concat(rows)
	local blocks, pos = {}, 1
	while pos <= #raw do
		local chunk = raw:sub(pos, pos + 65534)
		pos = pos + #chunk
		local last = pos > #raw and 1 or 0
		blocks[#blocks + 1] = string.char(last) .. string.pack("<I2", #chunk) .. string.pack("<I2", (~#chunk) & 0xFFFF) .. chunk
	end
	local zdata = "\120\1" .. table.concat(blocks) .. be32(adler32(raw))
	local function chunk(kind, data)
		return be32(#data) .. kind .. data .. be32(crc32(kind .. data))
	end
	local f = assert(io.open(file, "wb"))
	f:write("\137PNG\r\n\26\n",
		chunk("IHDR", be32(w) .. be32(h) .. string.char(8, 2, 0, 0, 0)),
		chunk("IDAT", zdata), chunk("IEND", ""))
	f:close()
end

local function proof(file, pieces)
	local W, H, GAP = 0, 0, 12
	for _, p in ipairs(pieces) do
		W = W + p.img.w + GAP
		H = math.max(H, p.img.h)
	end
	W, H = W + GAP, H + GAP * 2
	local bg = { 18, 14, 11 }
	local grid = {}
	for y = 1, H do
		grid[y] = {}
		for x = 1, W do grid[y][x] = { bg[1], bg[2], bg[3] } end
	end
	local x0 = GAP
	for _, p in ipairs(pieces) do
		local img, tint = p.img, p.tint
		for j = 0, img.h - 1 do
			for i = 0, img.w - 1 do
				local px = img.px[j * img.w + i + 1]
				local g, a = px[1], px[2]
				local cell = grid[GAP + j + 1][x0 + i + 1]
				for c = 1, 3 do
					cell[c] = cell[c] * (1 - a) + (g * tint[c] * 255) * a
				end
			end
		end
		x0 = x0 + img.w + GAP
	end
	local rgb = {}
	for y = 1, H do
		local row = {}
		for x = 1, W do
			local c = grid[y][x]
			row[#row + 1] = string.char(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5))
		end
		rgb[y] = table.concat(row)
	end
	writePNG(file, W, H, rgb)
	print("wrote " .. file)
end

local GOLD, RANK = { 0.89, 0.74, 0.35 }, { 1, 0.78, 0.25 }
local art = {
	{ "corner1", corner(1) }, { "corner2", corner(2) }, { "corner3", corner(3) }, { "corner4", corner(4) },
	{ "crest3", crest3() }, { "crest4", crest4() }, { "side3", side3() }, { "side4", side4() },
	{ "pendant4", pendant4() }, { "fan", fan() }, { "gem", gem() }, { "sheen", sheen() },
}
local pieces = {}
for _, a in ipairs(art) do
	save(a[1], a[2])
	pieces[#pieces + 1] = { img = a[2], tint = a[1] == "gem" and RANK or (a[1] == "sheen" and { 1, 1, 1 } or GOLD) }
end
if arg[1] then
	proof(arg[1], pieces)
end
