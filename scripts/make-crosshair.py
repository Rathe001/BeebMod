"""The resource display's crosshair: Art/crosshair.tga, 64x64 (Josh 2026-10-17:
"I meant a crosshair icon - not hunters mark").

Two rings and four ticks that cross them, the middle left open. White, with
the shape in the ALPHA channel, so one vertex colour tints it lit or dim, as
the glyphs in Art/icons.tga are tinted (scripts/make-icons.py). Drawn eight
times larger and shrunk, so the curves come out smooth.

    python scripts/make-crosshair.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE, SCALE = 64, 8
# the rings (radius to the middle of the stroke, and the stroke) and the
# ticks (how wide, and from how far out to how far in), in final pixels
OUTER, OUTER_W = 21, 5.5
INNER, INNER_W = 10.5, 4.5
TICK_W, TICK_OUT, TICK_IN = 4.5, 31, 5


def save_tga(img, path):
    # uncompressed 32-bit TGA, top row first: what the client reads
    w, h = img.size
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, "wb") as f:
        f.write(head)
        f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


def main():
    big = SIZE * SCALE
    mask = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(mask)
    c = big / 2

    def ring(r, w):
        r, w = r * SCALE, w * SCALE
        d.ellipse((c - r - w / 2, c - r - w / 2, c + r + w / 2, c + r + w / 2), fill=255)
        d.ellipse((c - r + w / 2, c - r + w / 2, c + r - w / 2, c + r - w / 2), fill=0)

    ring(OUTER, OUTER_W)
    ring(INNER, INNER_W)
    w, out, inn = TICK_W * SCALE / 2, TICK_OUT * SCALE, TICK_IN * SCALE
    for sx, sy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        if sx == 0:
            y0, y1 = sorted((c + sy * inn, c + sy * out))
            d.rectangle((c - w, y0, c + w, y1), fill=255)
        else:
            x0, x1 = sorted((c + sx * inn, c + sx * out))
            d.rectangle((x0, c - w, x1, c + w), fill=255)
    alpha = mask.resize((SIZE, SIZE), Image.LANCZOS)
    white = Image.new("L", (SIZE, SIZE), 255)
    img = Image.merge("RGBA", (white, white, white, alpha))
    path = os.path.join(ROOT, "Art", "crosshair.tga")
    save_tga(img, path)
    print("wrote Art/crosshair.tga")


if __name__ == "__main__":
    main()
