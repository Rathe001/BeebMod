"""The toolkit's own glyphs: Art/icons.tga, a 256x32 sheet of 32x32 marks.

Eight slots of 0.125 each, so there is room to add one without moving the
others - the coordinates live in UI/Bar.lua and a shifted sheet silently
renames every icon in the addon.

  0  note          a page with a folded corner and three lines
  1  magnifier     search
  2  bar chart     the census
  3  check         a quest objective that is done
  4  cog           settings
  5  chevron       pointing down; flip it vertically for collapsed
  6  cross         a quest you have failed
  7  pencil        write on this character

White, with the shape in the ALPHA channel, so one vertex colour tints them
the way the pills are tinted. Drawn here rather than borrowed from the game's
own files: a path that does not exist in this client renders as nothing at
all, and we have been bitten by exactly that twice.

    python scripts/make-icons.py
"""
import math
import os
import struct

W, H = 256, 32
buf = [[0.0] * W for _ in range(H)]


def blend(x, y, a):
    if 0 <= x < W and 0 <= y < H:
        buf[y][x] = max(buf[y][x], min(1.0, a))


def line(x0, y0, x1, y1, thick=1.6):
    """anti-aliased segment, by distance from the line"""
    for px in range(W):
        for py in range(H):
            vx, vy = x1 - x0, y1 - y0
            wx, wy = px + 0.5 - x0, py + 0.5 - y0
            L2 = vx * vx + vy * vy
            t = 0.0 if L2 == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / L2))
            dx, dy = wx - t * vx, wy - t * vy
            d = math.sqrt(dx * dx + dy * dy)
            if d < thick / 2 + 0.5:
                blend(px, py, min(1.0, (thick / 2 + 0.5 - d)))


def poly(points, samples=3):
    """A filled convex shape, sampled a few times per pixel so the diagonals
    come out smooth. Strokes make a pencil look like a smudge at sixteen
    pixels; the shape has to be solid."""
    xs = [pt[0] for pt in points]
    ys = [pt[1] for pt in points]
    for px in range(max(0, int(min(xs)) - 1), min(W, int(max(xs)) + 2)):
        for py in range(max(0, int(min(ys)) - 1), min(H, int(max(ys)) + 2)):
            hits = 0
            for sx in range(samples):
                for sy in range(samples):
                    x = px + (sx + 0.5) / samples
                    y = py + (sy + 0.5) / samples
                    # either winding: a shape drawn clockwise is still a shape
                    left = right = True
                    for i in range(len(points)):
                        ax, ay = points[i]
                        bx, by = points[(i + 1) % len(points)]
                        cross = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
                        if cross < 0:
                            left = False
                        if cross > 0:
                            right = False
                    if left or right:
                        hits += 1
            if hits:
                blend(px, py, hits / float(samples * samples))


def circle(cx, cy, r, thick=1.8):
    for px in range(W):
        for py in range(H):
            d = abs(math.sqrt((px + 0.5 - cx) ** 2 + (py + 0.5 - cy) ** 2) - r)
            if d < thick / 2 + 0.5:
                blend(px, py, min(1.0, (thick / 2 + 0.5 - d)))


# ---- the note: a page, a folded corner, three written lines ----
PAGE_L, PAGE_R, PAGE_T, PAGE_B, FOLD = 8, 24, 5, 27, 6
line(PAGE_L, PAGE_T, PAGE_R - FOLD, PAGE_T)
line(PAGE_R - FOLD, PAGE_T, PAGE_R, PAGE_T + FOLD)
line(PAGE_R, PAGE_T + FOLD, PAGE_R, PAGE_B)
line(PAGE_L, PAGE_B, PAGE_R, PAGE_B)
line(PAGE_L, PAGE_T, PAGE_L, PAGE_B)
for i, y in enumerate((13, 18, 23)):
    line(PAGE_L + 3, y, PAGE_R - (3 if i < 2 else 7), y, 1.4)

# ---- the magnifier: a lens and a handle ----
circle(32 + 13, 13, 7.5)
line(32 + 18.5, 18.5, 32 + 25, 25, 2.6)

# ---- the census: three bars climbing off a baseline ----
BASE = 25
line(64 + 7, BASE, 64 + 25, BASE, 1.6)
for x, top in ((64 + 10, 17), (64 + 16, 11), (64 + 22, 7)):
    line(x, BASE - 1, x, top, 3.2)

# ---- the check: two strokes, the short one into the long one. Drawn with a
# thicker pen than the rest because it is used at ten pixels, where a hairline
# check reads as a smudge.
line(96 + 8, 17, 96 + 13, 23, 3.4)
line(96 + 13, 23, 96 + 24, 8, 3.4)

# ---- the cog: a ring, a hole, and eight teeth. Not a wrench and not three
# sliders: a cog is the one shape everybody reads as "settings" without a label.
CX, CY = 128 + 16, 16
circle(CX, CY, 8.0, 3.0)
circle(CX, CY, 3.2, 2.2)
for k in range(8):
    a = math.pi * 2 * k / 8
    x0, y0 = CX + math.cos(a) * 8.0, CY + math.sin(a) * 8.0
    x1, y1 = CX + math.cos(a) * 12.0, CY + math.sin(a) * 12.0
    line(x0, y0, x1, y1, 3.2)

# ---- the chevron: two strokes meeting at the bottom. Drawn pointing DOWN,
# for a section that is open; the tracker flips it vertically for one that is
# folded up, which is the same glyph and half the sheet.
line(160 + 8, 12, 160 + 16, 21, 3.2)
line(160 + 16, 21, 160 + 24, 12, 3.2)

# ---- the cross: the check's opposite, and drawn to the same weight so a
# failed quest reads at the same distance as a finished one.
line(192 + 10, 10, 192 + 22, 22, 3.4)
line(192 + 22, 10, 192 + 10, 22, 3.4)

# ---- the pencil, and the line it is writing on: the shape everybody reads as
# "edit". Filled rather than stroked - three lines at this size came out as a
# smudge - and drawn on the diagonal, because a vertical pencil twelve pixels
# tall is just a rectangle.
import math as _m
O = 224
TIPX, TIPY = 8.5, 21.5
DX, DY = _m.cos(_m.radians(-45)), _m.sin(_m.radians(-45))  # up and to the right
PX, PY = -DY, DX                                            # across the shaft
HALF = 3.0


def _at(along, across):
    return (O + TIPX + DX * along + PX * across, TIPY + DY * along + PY * across)


# the sharpened end: a triangle closing to the point
poly([(O + TIPX, TIPY), _at(5.5, HALF), _at(5.5, -HALF)])
# the shaft
poly([_at(5.5, HALF), _at(16.0, HALF), _at(16.0, -HALF), _at(5.5, -HALF)])
# the blunt end, a hair away from the shaft so the two read as two
poly([_at(17.2, HALF), _at(20.5, HALF), _at(20.5, -HALF), _at(17.2, -HALF)])
# and the line being written on
poly([(O + 7, 25.5), (O + 25, 25.5), (O + 25, 27.5), (O + 7, 27.5)])

pixels = bytearray()
for y in range(H):
    for x in range(W):
        pixels += bytes((255, 255, 255, int(round(buf[y][x] * 255))))

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
dest = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Art")
os.makedirs(dest, exist_ok=True)
path = os.path.join(dest, "icons.tga")
with open(path, "wb") as f:
    f.write(header)
    f.write(pixels)
print("wrote", path, os.path.getsize(path), "bytes")

# a crude look at what we drew, so a mistake shows up here and not in game
for y in range(0, H, 2):
    print("".join("#" if buf[y][x] > 0.6 else ("+" if buf[y][x] > 0.2 else ".") for x in range(W)))


# ---------------------------------------------------------------------------
# Art/net.tga: a second sheet (Josh 2026-09-21). The first sheet's eight
# slots are all taken, and widening it would move every coordinate in
# UI/Bar.lua. Same pen, same white-in-alpha. 128x32 - four slots of 0.25, a
# width the client will load - since the reticle joined it (2026-09-22).
#
#   0  house       latency to your realm ("home")
#   1  globe       latency to the world server
#   2  reticle     nobody targeted: the dock's first slot, waiting
# ---------------------------------------------------------------------------
W, H = 128, 32
buf = [[0.0] * W for _ in range(H)]

# ---- the house: a roof and a box with a door. Solid roof, stroked walls, so
# it reads as a house at twelve pixels rather than as an arrow.
poly([(16, 4), (28, 15), (4, 15)])
line(8, 15, 8, 27, 2.6)
line(24, 15, 24, 27, 2.6)
line(8, 27, 24, 27, 2.6)
poly([(14, 19), (18, 19), (18, 27), (14, 27)])

# ---- the globe: a ring, the equator, a meridian, and two parallels
GX, GY, GR = 32 + 16, 16, 11
circle(GX, GY, GR, 2.4)
line(GX - GR, GY, GX + GR, GY, 1.8)
# the meridian, as an ellipse half as wide as the globe
steps = 24
for i in range(steps):
    a0 = math.pi * 2 * i / steps
    a1 = math.pi * 2 * (i + 1) / steps
    line(GX + math.cos(a0) * GR * 0.45, GY + math.sin(a0) * GR,
         GX + math.cos(a1) * GR * 0.45, GY + math.sin(a1) * GR, 1.8)
for dy in (-6, 6):
    half = math.sqrt(GR * GR - dy * dy) - 1
    line(GX - half, GY + dy, GX + half, GY + dy, 1.6)

# ---- the reticle: a ring and four ticks crossing it, pointing at the middle.
# What you do to fill the slot it sits in: target somebody.
RX, RY, RR = 64 + 16, 16, 8.5
circle(RX, RY, RR, 2.2)
for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
    line(RX + dx * 4, RY + dy * 4, RX + dx * 13, RY + dy * 13, 2.4)

pixels = bytearray()
for y in range(H):
    for x in range(W):
        pixels += bytes((255, 255, 255, int(round(buf[y][x] * 255))))
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
path = os.path.join(dest, "net.tga")
with open(path, "wb") as f:
    f.write(header)
    f.write(pixels)
print("wrote", path, os.path.getsize(path), "bytes")
for y in range(0, H, 2):
    print("".join("#" if buf[y][x] > 0.6 else ("+" if buf[y][x] > 0.2 else ".") for x in range(W)))
