"""The unit tooltip's row pictures: Art/tipicons.tga, a 256x32 sheet of 32x32
glyphs (Josh 2026-10-17, the tooltip canvas "C, everything as tags").

  0  quest      an exclamation mark: an objective this enemy counts for
  1  kills      a paw: the Expedition's kills of it
  2  note       a quotation mark: your note
  3  tags       a tag: your tags
  4  grouped    two people: the times you grouped
  5  rating     a star: your rating
  6  duels      crossed swords: your duels
  7  guild      a banner: the guild they were in

White, with the shape in the ALPHA channel, so each row tints its own (Core/
Tooltip.lua, T.Icon), as the glyphs in Art/icons.tga are tinted. Drawn eight
times larger and shrunk, so the curves come out smooth at eleven pixels.

    python scripts/make-tip-icons.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, COUNT, SCALE = 32, 8, 8


def save_tga(img, path):
    # uncompressed 32-bit TGA, top row first: what the client reads
    w, h = img.size
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, "wb") as f:
        f.write(head)
        f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


class Cell:
    """drawing in one cell's own 32-pixel coordinates"""

    def __init__(self, draw, index):
        self.d = draw
        self.x0 = index * CELL * SCALE

    def p(self, x, y):
        return (self.x0 + x * SCALE, y * SCALE)

    def circle(self, cx, cy, r, fill=255):
        (x, y), s = self.p(cx, cy), r * SCALE
        self.d.ellipse((x - s, y - s, x + s, y + s), fill=fill)

    def ellipse(self, cx, cy, rx, ry, fill=255):
        (x, y) = self.p(cx, cy)
        self.d.ellipse((x - rx * SCALE, y - ry * SCALE, x + rx * SCALE, y + ry * SCALE), fill=fill)

    def poly(self, points, fill=255):
        self.d.polygon([self.p(x, y) for x, y in points], fill=fill)

    def line(self, x0, y0, x1, y1, w):
        self.d.line([self.p(x0, y0), self.p(x1, y1)], fill=255, width=int(w * SCALE))
        self.circle(x0, y0, w / 2)
        self.circle(x1, y1, w / 2)

    def rect(self, x0, y0, x1, y1, fill=255):
        self.d.rectangle((*self.p(x0, y0), *self.p(x1, y1)), fill=fill)


def quest(c):
    c.poly([(12.5, 3), (19.5, 3), (18, 20), (14, 20)])
    c.circle(16, 26.5, 3.4)


def kills(c):
    c.ellipse(16, 21.5, 7.8, 6.6)
    for x, y in ((6.5, 13.5), (12, 7.5), (20, 7.5), (25.5, 13.5)):
        c.circle(x, y, 3.3)


def note(c):
    for x in (10, 22):
        c.circle(x, 12, 5)
        c.poly([(x - 4.6, 13), (x + 4.8, 12.5), (x - 3, 24)])


def tags(c):
    outer = [(4, 4), (15, 4), (28, 17), (17, 28), (4, 15)]
    inner = [(7.5, 7.5), (13.6, 7.5), (23.4, 17.2), (17.2, 23.4), (7.5, 13.6)]
    c.poly(outer)
    c.poly(inner, fill=0)
    c.circle(11.5, 11.5, 2.4)


def grouped(c):
    # the one behind, then the one in front over it
    c.circle(22, 10, 4)
    c.ellipse(23, 26, 7, 8.5)
    c.circle(12, 11, 5.4, fill=0)
    c.ellipse(12, 28, 10.6, 10.4, fill=0)
    c.circle(12, 11, 4.4)
    c.ellipse(12, 28, 9.4, 9.2)
    c.rect(0, 29.5, 32, 32, fill=0)


def rating(c):
    pts = []
    for i in range(10):
        r = 14 if i % 2 == 0 else 5.8
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((16 + r * math.cos(a), 17 + r * math.sin(a)))
    c.poly(pts)


def duels(c):
    # two blades crossing, each with a guard across it and a grip below
    c.line(5, 4, 21, 20, 3)
    c.line(27, 4, 11, 20, 3)
    c.line(17, 24, 25, 16, 3)
    c.line(7, 16, 15, 24, 3)
    c.line(21, 20, 27, 26, 3.4)
    c.line(11, 20, 5, 26, 3.4)


def guild(c):
    c.rect(6, 3, 9, 29)
    c.poly([(9, 4), (27, 4), (21.5, 10.5), (27, 17), (9, 17)])


DRAW = [quest, kills, note, tags, grouped, rating, duels, guild]


def main():
    mask = Image.new("L", (CELL * COUNT * SCALE, CELL * SCALE), 0)
    d = ImageDraw.Draw(mask)
    for i, fn in enumerate(DRAW):
        fn(Cell(d, i))
    alpha = mask.resize((CELL * COUNT, CELL), Image.LANCZOS)
    white = Image.new("L", alpha.size, 255)
    img = Image.merge("RGBA", (white, white, white, alpha))
    save_tga(img, os.path.join(ROOT, "Art", "tipicons.tga"))
    print("wrote Art/tipicons.tga")


if __name__ == "__main__":
    main()
