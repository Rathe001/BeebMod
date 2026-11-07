"""The group and raid marks on friendly nameplates: Art/groupdots.tga, 64x32
(Josh 2026-11-06, option A on the "Group and raid on nameplates" canvas).

Two cells of 32x32. The left is a filled dot, for a player in your group.
The right is a ring, for a player elsewhere in your raid. Each is white with a
dark edge, so one vertex colour tints the white and leaves the edge dark, and
the mark reads on bright ground as the name's shadow does. Drawn eight times
larger and shrunk, so the curves come out smooth.

    python scripts/make-group-dots.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, SCALE = 32, 8
EDGE_ALPHA = 0.85
# radii in final pixels: the dark edge, then the white inside it
DOT_EDGE, DOT = 14, 10.5
RING_EDGE_OUT, RING_OUT, RING_IN, RING_EDGE_IN = 14.5, 11.5, 6.5, 3.5


def save_tga(img, path):
    # uncompressed 32-bit TGA, top row first: what the client reads
    w, h = img.size
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, "wb") as f:
        f.write(head)
        f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


def disc(d, cx, cy, r, fill):
    r = r * SCALE
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def main():
    big = CELL * SCALE
    img = Image.new("RGBA", (big * 2, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    edge = (0, 0, 0, int(255 * EDGE_ALPHA))
    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)
    c = big / 2
    # the dot
    disc(d, c, c, DOT_EDGE, edge)
    disc(d, c, c, DOT, white)
    # the ring
    x = big + c
    disc(d, x, c, RING_EDGE_OUT, edge)
    disc(d, x, c, RING_OUT, white)
    disc(d, x, c, RING_IN, edge)
    disc(d, x, c, RING_EDGE_IN, clear)
    small = img.convert("RGBa").resize((CELL * 2, CELL), Image.LANCZOS).convert("RGBA")
    path = os.path.join(ROOT, "Art", "groupdots.tga")
    save_tga(small, path)
    print("wrote Art/groupdots.tga")


if __name__ == "__main__":
    main()
