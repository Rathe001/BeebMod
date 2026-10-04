"""scripts/make-patterns.py (Josh 2026-09-23): the debuff-type textures for the
unit frames' dispel mark - magic sparks, curse smoke, poison bubbles, disease
spores, bleed drips. White, with the drawing in the alpha channel, so the
client tints each in its type's colour. Every one tiles seamlessly (all the
noise is periodic over the tile). And the lattice of a shield over a unit's
health (shield, below).

    python scripts/make-patterns.py [proof.png]

writes Art/Patterns/*.tga, and a proof sheet - each texture tiled, and as it
sits on a party cell - to the path given (default patterns_proof.png here).
Needs numpy and Pillow. A changed texture needs a restart of the game."""
import numpy as np
from PIL import Image
import os
import sys

N = 128
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Art', 'Patterns')
PROOF = sys.argv[1] if len(sys.argv) > 1 else 'patterns_proof.png'

yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def perlin(period, seed, px=None, py=None):
    """periodic gradient noise, period cells across the tile, in [-1, 1]"""
    rng = np.random.default_rng(seed)
    ang = rng.uniform(0, 2 * np.pi, (period, period))
    gx, gy = np.cos(ang), np.sin(ang)
    x = (xx if px is None else px) / N * period
    y = (yy if py is None else py) / N * period
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0

    def dot(ix, iy, dx, dy):
        i, j = ix % period, iy % period
        return gx[j, i] * dx + gy[j, i] * dy

    u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    n00 = dot(x0, y0, fx, fy)
    n10 = dot(x0 + 1, y0, fx - 1, fy)
    n01 = dot(x0, y0 + 1, fx, fy - 1)
    n11 = dot(x0 + 1, y0 + 1, fx - 1, fy - 1)
    nx0 = n00 + u * (n10 - n00)
    nx1 = n01 + u * (n11 - n01)
    return (nx0 + v * (nx1 - nx0)) * 1.41


def fbm(base, octaves, seed, px=None, py=None, gain=0.5):
    total, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        total = total + amp * perlin(base * 2 ** o, seed + o * 17, px, py)
        norm += amp
        amp *= gain
    return total / norm


def wrapdist(cx, cy):
    dx = np.abs(xx - cx)
    dy = np.abs(yy - cy)
    dx = np.minimum(dx, N - dx)
    dy = np.minimum(dy, N - dy)
    return dx, dy


def save(name, alpha):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    rgba = np.dstack([np.full_like(a, 255)] * 3 + [a])
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, name + '.tga'))
    return a


# --- poison: bubbles, clustered, each a rim and a glint, over a faint ooze
def poison():
    rng = np.random.default_rng(7)
    a = np.clip(fbm(4, 3, 101) * 0.5 + 0.2, 0, 1) * 0.18
    for _ in range(26):
        cx, cy = rng.uniform(0, N, 2)
        r = rng.choice([rng.uniform(3, 6), rng.uniform(6, 11), rng.uniform(11, 16)], p=[0.5, 0.35, 0.15])
        dx, dy = wrapdist(cx, cy)
        d = np.sqrt(dx * dx + dy * dy)
        inside = smoothstep(r + 0.8, r - 0.8, d)
        rim = inside * smoothstep(r - 2.4, r - 0.6, d)
        body = inside * 0.16
        # the glint, up and to the left of the centre
        gx, gy = wrapdist(cx - r * 0.38, cy - r * 0.38)
        glint = smoothstep(r * 0.22 + 0.6, r * 0.22 - 0.6, np.sqrt(gx * gx + gy * gy)) * 0.95
        # a bubble in front hides what is behind it
        a = a * (1 - inside) + np.maximum(np.maximum(rim * 0.9, body), glint)
    return a


# --- bleed: blood running down from the top edge - a wavering line along the
# top, and drips of different lengths hanging from it, each ending in a bead.
# Only the top of the tile is ever seen (the band is 18 to 27 tall), so the
# drips are short and it is the top that is drawn.
def bleed():
    rng = np.random.default_rng(206)
    edge = 5.0 + fbm(4, 2, 207, py=np.zeros_like(yy)) * 3.0          # the line along the top
    a = smoothstep(edge + 1.0, edge - 1.0, yy)
    x = 0.0
    while x < N:
        w = rng.uniform(4.0, 8.0)
        length = rng.choice([rng.uniform(6, 12), rng.uniform(12, 22), rng.uniform(22, 30)], p=[0.45, 0.4, 0.15])
        cx = x + rng.uniform(1, 4)
        dx, _ = wrapdist(cx, 0)
        # the drip narrows as it runs, then swells into its bead
        taper = w * (1.0 - 0.45 * np.clip(yy / length, 0, 1))
        body = smoothstep(taper * 0.5 + 0.7, taper * 0.5 - 0.7, dx) * smoothstep(length + 0.8, length - 0.8, yy)
        br = w * 0.6
        bdx, bdy = wrapdist(cx, length)
        bead = smoothstep(br + 0.8, br - 0.8, np.sqrt(bdx * bdx + bdy * bdy))
        # a highlight down one side of the drip and on the bead
        hx, hy = wrapdist(cx - br * 0.35, length - br * 0.35)
        glint = smoothstep(br * 0.3 + 0.5, br * 0.3 - 0.5, np.sqrt(hx * hx + hy * hy)) * 0.9
        a = np.maximum(a, np.maximum(body, bead) * 0.85)
        a = np.maximum(a, glint)
        x = cx + w + rng.uniform(5, 16)
    return np.clip(a, 0, 1)


# --- curse: a smoke that folds in on itself (domain-warped noise)
def curse():
    q1 = fbm(2, 4, 301)
    q2 = fbm(2, 4, 302)
    r1 = fbm(2, 4, 303, px=(xx + 38 * q1) % N, py=(yy + 38 * q2) % N)
    r2 = fbm(2, 4, 304, px=(xx + 38 * q2) % N, py=(yy + 38 * q1) % N)
    v = fbm(3, 5, 305, px=(xx + 44 * r1) % N, py=(yy + 44 * r2) % N)
    smoke = smoothstep(-0.15, 0.55, v)
    wisps = smoothstep(0.35, 0.6, v) * 0.35
    return np.clip(smoke * 0.75 + wisps, 0, 1)


# --- magic: sparks - four-pointed, a bright core - over a faint arcane shimmer
def magic():
    f = fbm(2, 4, 401)
    ribbons = np.exp(-np.abs(np.sin(f * 9.0)) * 7.0) * 0.22
    a = ribbons
    rng = np.random.default_rng(402)
    for _ in range(22):
        cx, cy = rng.uniform(0, N, 2)
        s = rng.choice([rng.uniform(2, 3.5), rng.uniform(4, 7)], p=[0.65, 0.35])
        dx, dy = wrapdist(cx, cy)
        core = np.exp(-(dx * dx + dy * dy) / (2 * (s * 0.35) ** 2))
        rays = np.exp(-dy * dy / 0.9) * np.exp(-dx / (s * 1.6)) + np.exp(-dx * dx / 0.9) * np.exp(-dy / (s * 1.6))
        a = np.maximum(a, np.clip(core + rays * 0.8, 0, 1))
    return np.clip(a, 0, 1)


# --- disease: blotches of rot, ringed darker at the edge, and spores round them
def disease():
    rng = np.random.default_rng(501)
    pts = rng.uniform(0, N, (18, 2))
    f1 = np.full((N, N), 1e9)
    for cx, cy in pts:
        dx, dy = wrapdist(cx, cy)
        f1 = np.minimum(f1, np.sqrt(dx * dx + dy * dy))
    wobble = fbm(8, 3, 502) * 5
    radius = 9 + wobble
    blot = smoothstep(radius + 1.2, radius - 1.2, f1)
    ring = blot * smoothstep(radius - 3.5, radius - 0.5, f1)
    grime = np.clip(fbm(16, 2, 503) * 0.5 + 0.5, 0, 1)
    a = blot * (0.28 + grime * 0.2) + ring * 0.55
    for _ in range(70):
        cx, cy = rng.uniform(0, N, 2)
        r = rng.uniform(0.7, 1.8)
        dx, dy = wrapdist(cx, cy)
        a = np.maximum(a, smoothstep(r + 0.7, r - 0.7, np.sqrt(dx * dx + dy * dy)) * 0.85)
    return np.clip(a, 0, 1)


# --- shield (Josh 2026-10-04: "C: honeycomb"): a lattice of hexagons, the
# shape a shield takes in a hundred games, drawn as the dispel patterns are.
# Each line is bright with a dark line just inside it, over a faint fill, so
# the lattice reads on a white bar and on the empty dark alike. The bright and
# the fill are white and the dark is black: the client tints the white, and
# black under any tint stays black - so the drawing is in the colour as well
# as the alpha, unlike the others. It sat in Dander's Frames' cyan stripes for
# an afternoon first ("looks more like BeebMod instead of a Dander's Frames
# copy"). 64 square: seven hexagons across and four pairs of rows down, so
# the lattice comes round to meet itself at every edge.
# AND A FINER ONE (Josh 2026-10-04: "scale down the textures of the raid unit
# frames a bit? Doesn't read quite as well as player/target frames"): ten
# across and six pairs of rows, with thinner lines, for the frames whose bar
# is short - a raid cell showed two or three hexagons and read as a blur.
def shield(name='shield', across=7, pairs=4, lw=1.2):
    n = 64
    yy2, xx2 = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    w, r = n / float(across), n / float(pairs) / 3.0
    b1 = np.array((w, 0.0))
    b2 = np.array((w / 2.0, 1.5 * r))
    inv = np.linalg.inv(np.array([b1, b2]).T)
    u = inv[0, 0] * xx2 + inv[0, 1] * yy2
    v = inv[1, 0] * xx2 + inv[1, 1] * yy2
    best = np.full(xx2.shape, 1e9)
    bx = np.zeros_like(xx2)
    by = np.zeros_like(xx2)
    for du in (0, 1):
        for dv in (0, 1):
            cu, cv = np.floor(u) + du, np.floor(v) + dv
            dx = xx2 - (cu * b1[0] + cv * b2[0])
            dy = yy2 - (cu * b1[1] + cv * b2[1])
            d = dx * dx + dy * dy
            near = d < best
            best = np.where(near, d, best)
            bx = np.where(near, dx, bx)
            by = np.where(near, dy, by)
    norm = np.zeros_like(xx2)
    for ang in (0, 60, 120):
        a = np.radians(ang)
        norm = np.maximum(norm, np.abs(bx * np.cos(a) + by * np.sin(a)))
    edge = w / 2.0 - norm                       # inside a hexagon, how far from its edge
    line = np.clip(lw - np.abs(edge), 0, 1)
    shade = np.clip(lw - np.abs(edge - lw), 0, 1) * 0.55
    # laid one over another: the fill, the dark, the line
    col, alpha = np.zeros_like(xx2), np.zeros_like(xx2)
    for c, a in ((1.0, np.full_like(xx2, 0.16)), (0.0, shade), (1.0, line * 0.9)):
        col = c * a + col * (1 - a)
        alpha = a + alpha * (1 - a)
    grey = np.where(alpha > 0, col / np.maximum(alpha, 1e-6), 0)
    rgb = np.repeat((np.clip(grey, 0, 1) * 255).astype(np.uint8)[..., None], 3, axis=2)
    rgba = np.dstack([rgb, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)])
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, name + '.tga'))


COLOURS = {
    'magic': (0.20, 0.60, 1.00), 'curse': (0.60, 0.00, 1.00), 'disease': (0.60, 0.40, 0.00),
    'poison': (0.00, 0.60, 0.00), 'bleed': (0.80, 0.20, 0.20),
}
# --- each at half the size, for a short cell (Josh 2026-10-04: "Should we do
# the same for the debuff textures?"). A raid cell's band is 18 tall: it held
# part of one bubble or one drip, and the type read as a plain wash. Shrunk
# from three tiles by three and the middle one kept, so it still tiles.
def half(name, a):
    tile = Image.fromarray(np.tile(a, (3, 3)), 'L')
    small = np.array(tile.resize((3 * N // 2, 3 * N // 2), Image.LANCZOS)).astype(np.float64) / 255
    save(name + '-fine', small[N // 2:N, N // 2:N])


made = {}
for name, fn in (('magic', magic), ('curse', curse), ('poison', poison), ('disease', disease), ('bleed', bleed)):
    made[name] = save(name, fn())
    half(name, made[name])
shield()
shield('shield-fine', across=10, pairs=6, lw=0.9)

# --- the proof: each one tiled 2x2 on the cell's dark, and as it sits on a
# party cell: the class bar, the wash at 28%, the texture at 45% over it
W, H = 1400, 440
sheet = np.zeros((H, W, 3), dtype=np.float64)
sheet[:] = (0.07, 0.08, 0.06)
for i, name in enumerate(COLOURS):
    a = made[name].astype(np.float64) / 255
    col = np.array(COLOURS[name])
    tile = np.tile(a, (2, 2))
    x0 = 20 + i * 272
    block = sheet[20:20 + 2 * N, x0:x0 + 2 * N]
    block[:] = block * (1 - tile[..., None]) + col * tile[..., None]
    # a party cell: 160x60 at 1.4x, a priest's grey bar, the band over its top
    cw, ch = 224, 84
    cy0 = 300
    cell = sheet[cy0:cy0 + ch, x0:x0 + cw]
    cell[:] = (0.05, 0.06, 0.05)
    cell[3:ch - 10, 3:cw - 3] = (0.52, 0.52, 0.52)
    band = int(ch * 0.45)
    wash = 0.28
    cell[:band] = cell[:band] * (1 - wash) + col * wash
    pat = np.tile(a, (1, 2))[:band, :cw] * 0.45
    cell[:band] = cell[:band] * (1 - pat[..., None]) + col * pat[..., None]
    for t in (0, 1):
        cell[t, :] = col; cell[ch - 1 - t, :] = col; cell[:, t] = col; cell[:, cw - 1 - t] = col
Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8), 'RGB').save(PROOF)
print('ok', {k: int(v.mean()) for k, v in made.items()})
