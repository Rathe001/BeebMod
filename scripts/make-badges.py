"""scripts/make-badges.py (Josh 2026-09-29): the journals' rank badges.

The badges are drawn in two pages, the same drawings as the mockups they were
chosen from: scripts/rank-badges.html for the Expedition, and
scripts/ravenholdt-badges.html for the Ledger (Josh 2026-10-05). This opens
each in headless Microsoft Edge at twice the size, so every edge is smoothed
when it is brought down, and cuts the picture into textures:

    python scripts/make-badges.py [proof.png]

writes Art/Ranks/rank1.tga (Greenhorn) to rank10.tga (Expedition Leader),
the dock's other shields in pieces - Art/Dock/field.tga, rim.tga,
banner.tga, swords.tga and level1.tga to level7.tga - and
Art/Ravenholdt/rank1.tga (Fledgling) to rank10.tga (Eye of Ravenholdt),
256 x 256 each, 32-bit with the ground clear. Needs Edge and Pillow (pip
install pillow). A proof, if named, is the two rows of ranks on the window's
own dark, to look at before starting the game.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# each page, and the file each picture on it becomes, in order
PAGES = [
    ("rank-badges.html",
     [("Ranks", f"rank{i}") for i in range(1, 11)]
     + [("Dock", "field"), ("Dock", "rim"), ("Dock", "banner"), ("Dock", "swords")]
     + [("Dock", f"level{i}") for i in range(1, 8)]),
    ("ravenholdt-badges.html", [("Ravenholdt", f"rank{i}") for i in range(1, 11)]),
]
SIZE, SCALE = 256, 2

EDGES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def edge():
    for path in EDGES:
        if os.path.exists(path):
            return path
    sys.exit("Microsoft Edge was not found; it draws the badges.")


def render(page, count, to):
    # a clear ground, the row at its size, and time for the page's script
    subprocess.run([
        edge(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--default-background-color=00000000",
        f"--force-device-scale-factor={SCALE}",
        f"--window-size={count * SIZE},{SIZE}",
        "--virtual-time-budget=3000",
        f"--screenshot={to}",
        "file:///" + os.path.join(HERE, page).replace("\\", "/"),
    ], check=True, capture_output=True)


def save_tga(img, path):
    # uncompressed 32-bit TGA, top row first: what the client reads
    w, h = img.size
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, "wb") as f:
        f.write(head)
        f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


def cut(page, names):
    count = len(names)
    for folder in {f for f, _ in names}:
        os.makedirs(os.path.join(ROOT, "Art", folder), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        shot = os.path.join(tmp, "badges.png")
        render(page, count, shot)
        row = Image.open(shot).convert("RGBA")
    big = SIZE * SCALE
    if row.size[0] < count * big:
        sys.exit(f"{page}: the picture is {row.size}, too small for {count} badges at {big}")
    cells = []
    for i in range(count):
        cell = row.crop((i * big, 0, (i + 1) * big, big))
        # brought down with the colour weighted by its alpha, so the clear
        # ground leaves no dark fringe round the edge
        cell = cell.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
        folder, name = names[i]
        save_tga(cell, os.path.join(ROOT, "Art", folder, name + ".tga"))
        cells.append(cell)
        print(f"wrote Art/{folder}/{name}.tga")
    return cells


def main():
    rows = []
    for page, names in PAGES:
        cells = cut(page, names)
        # the ranks for the proof: the pictures whose file is a rank
        rows.append([c for c, (_, name) in zip(cells, names) if name.startswith("rank")])
    if len(sys.argv) > 1:
        across = max(len(r) for r in rows)
        proof = Image.new("RGBA", (across * SIZE, len(rows) * SIZE), (10, 15, 13, 255))
        for y, cells in enumerate(rows):
            for x, cell in enumerate(cells):
                proof.alpha_composite(cell, (x * SIZE, y * SIZE))
        proof.save(sys.argv[1])
        print(f"wrote {sys.argv[1]}")


if __name__ == "__main__":
    main()
