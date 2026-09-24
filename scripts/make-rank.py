"""scripts/make-rank.py (Josh 2026-09-23): the ornate border round an elite or
rare mob's unit frame - an Art Deco corner (a stepped notch, a double line, a
diamond at the point and a fan behind it) and a crest for the top edge. White
with the drawing in the alpha channel, so the client tints it gold or silver.

Drawn at eight times the size and brought down, so a one-pixel line lands on
one pixel with its edges smoothed.

    python scripts/make-rank.py [proof.png]

writes Art/Rank/corner.tga (32x32, the top-left corner; the others are it
mirrored) and Art/Rank/crest.tga (32x16), and a proof - a target frame in gold
and in silver, three times the size - to the path given. Needs Pillow."""
import os
import sys
from PIL import Image, ImageDraw, ImageChops

S = 8                     # drawn at this many times the size
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Art', 'Rank')
PROOF = sys.argv[1] if len(sys.argv) > 1 else 'rank_proof.png'

# In the corner texture, pixel (0, 0) is 8 units up and left of the frame's
# corner: the frame's edge is at 8, the outer line at 3, the inner at 6. The
# lines between the corners (drawn by the addon, a unit wide) meet these.
EDGE, OUTER, INNER = 8, 3, 6


def line(d, pts, w=1.0):
    """a path through pixel centres. A straight run along a row or a column is
    laid as a block exactly one pixel wide, so it lands on one pixel at full
    strength; anything slanted is drawn and smoothed by the averaging."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if (x0 == x1 or y0 == y1) and w >= 1.0 and float(x0).is_integer() and float(y0).is_integer():
            ax, bx = sorted((x0, x1))
            ay, by = sorted((y0, y1))
            d.rectangle([ax * S, ay * S, bx * S + S - 1, by * S + S - 1], fill=255)
        else:
            d.line([(x0 * S + S / 2, y0 * S + S / 2), (x1 * S + S / 2, y1 * S + S / 2)], fill=255, width=max(1, int(w * S)))


def corner():
    img = Image.new('L', (32 * S, 32 * S), 0)
    d = ImageDraw.Draw(img)
    # the outer line: along the top and down the left, stopping short of the
    # point, where the diamond sits
    line(d, [(12, OUTER), (34, OUTER)])
    line(d, [(OUTER, 12), (OUTER, 34)])
    # the inner line turns the corner in a stepped notch
    line(d, [(INNER, 34), (INNER, 14), (10, 14), (10, 10), (14, 10), (14, INNER), (34, INNER)])
    # the diamond at the point, outlined, with a dot in it
    cx, cy, r = 4.5, 4.5, 3.6
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    d.polygon([(x * S + S / 2, y * S + S / 2) for x, y in pts], outline=255, width=int(1 * S))
    d.ellipse([(cx - 0.9) * S + S / 2, (cy - 0.9) * S + S / 2, (cx + 0.9) * S + S / 2, (cy + 0.9) * S + S / 2], fill=255)
    # a fan of three short rays from the notch, out along the diagonal
    for a, b in (((11, 11), (8, 8)), ((12.5, 10), (10.5, 7.5)), ((10, 12.5), (7.5, 10.5))):
        line(d, [a, b], 0.8)
    # ticks where the lines leave the corner
    line(d, [(18, OUTER - 2), (18, INNER + 2)])
    line(d, [(OUTER - 2, 18), (INNER + 2, 18)])
    return img.resize((32, 32), Image.BOX)


def crest():
    img = Image.new('L', (32 * S, 16 * S), 0)
    d = ImageDraw.Draw(img)
    cx, cy = 15.5, 7
    # a tall diamond, filled, standing on the line, with a smaller one inside cut out
    r_w, r_h = 4.2, 6.2
    outer = [(cx, cy - r_h), (cx + r_w, cy), (cx, cy + r_h), (cx - r_w, cy)]
    d.polygon([(x * S + S / 2, y * S + S / 2) for x, y in outer], fill=255)
    inner = [(cx, cy - r_h + 2.4), (cx + r_w - 1.8, cy), (cx, cy + r_h - 2.4), (cx - r_w + 1.8, cy)]
    d.polygon([(x * S + S / 2, y * S + S / 2) for x, y in inner], fill=0)
    # wings: two steps out each side, along the line
    for side in (-1, 1):
        x_in, x_out = (20, 27) if side > 0 else (4, 11)
        line(d, [(x_in, cy), (x_out, cy)])
        wing_in, wing_out = (21, 24) if side > 0 else (7, 10)
        line(d, [(wing_in, cy - 2), (wing_out, cy - 2)])
        line(d, [(wing_in, cy + 2), (wing_out, cy + 2)])
        tip = 28 if side > 0 else 3
        line(d, [(tip, cy - 1), (tip, cy + 1)])
    return img.resize((32, 16), Image.BOX)


def save(name, alpha):
    white = Image.new('L', alpha.size, 255)
    Image.merge('RGBA', (white, white, white, alpha)).save(os.path.join(OUT, name + '.tga'))


os.makedirs(OUT, exist_ok=True)
c, k = corner(), crest()
save('corner', c)
save('crest', k)

# --- the proof: a 160x60 target frame, gold then silver, at three times the size
Z = 3
W, H = 160, 60
sheet = Image.new('RGB', ((W + 40) * 2 * Z + 20 * Z, (H + 40) * Z), (32, 30, 34))
for n, col in enumerate(((255, 209, 102), (214, 224, 242))):
    ox, oy = 20 + n * (W + 50), 20
    frame = Image.new('RGBA', (W + 40, H + 40), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fx, fy = 20, 20
    fd.rectangle([fx, fy, fx + W - 1, fy + H - 1], fill=(19, 21, 16, 255))
    fd.rectangle([fx + 2, fy + 2, fx + W - 3, fy + H - 15], fill=(140, 40, 34, 255))
    ink = Image.new('RGBA', frame.size, col + (0,))
    mask = Image.new('L', frame.size, 0)
    corners = [(c, fx - EDGE, fy - EDGE),
               (c.transpose(Image.FLIP_LEFT_RIGHT), fx + W + EDGE - 32, fy - EDGE),
               (c.transpose(Image.FLIP_TOP_BOTTOM), fx - EDGE, fy + H + EDGE - 32),
               (c.transpose(Image.ROTATE_180), fx + W + EDGE - 32, fy + H + EDGE - 32)]
    def add(img, x, y):
        # laid over, not blended: where two pieces cross, the brighter wins,
        # as texture over texture does in the game
        layer = Image.new('L', mask.size, 0)
        layer.paste(img, (x, y))
        return ImageChops.lighter(mask, layer)
    for img, x, y in corners:
        mask = add(img, x, y)
    lines = Image.new('L', mask.size, 0)
    md = ImageDraw.Draw(lines)
    # the lines between the corners
    for off in (EDGE - OUTER, EDGE - INNER):
        md.line([(fx - EDGE + 32, fy - off), (fx + W + EDGE - 33, fy - off)], fill=255)
        md.line([(fx - EDGE + 32, fy + H - 1 + off), (fx + W + EDGE - 33, fy + H - 1 + off)], fill=255)
        md.line([(fx - off, fy - EDGE + 32), (fx - off, fy + H + EDGE - 33)], fill=255)
        md.line([(fx + W - 1 + off, fy - EDGE + 32), (fx + W - 1 + off, fy + H + EDGE - 33)], fill=255)
    mask = ImageChops.lighter(mask, lines)
    kx, ky = fx + W // 2 - 16, fy - (EDGE - OUTER) - 8
    mask = add(k, kx, ky)
    ink.putalpha(mask)
    frame = Image.alpha_composite(frame, ink)
    sheet.paste(frame.resize(((W + 40) * Z, (H + 40) * Z), Image.NEAREST), (ox * Z // 1, 0), frame.resize(((W + 40) * Z, (H + 40) * Z), Image.NEAREST))
sheet.save(PROOF)
print('ok')
