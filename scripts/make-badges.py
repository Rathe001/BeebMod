"""scripts/make-badges.py (Josh 2026-09-29): the Expedition's rank badges.

The badges are drawn in scripts/rank-badges.html, the same drawing as the
mockup they were chosen from. This opens that page in headless Microsoft Edge
at twice the size, so every edge is smoothed when it is brought down, and cuts
the picture into textures:

    python scripts/make-badges.py [proof.png]

writes Art/Ranks/rank1.tga (Greenhorn) to rank10.tga (Expedition Leader),
and the dock's other shields in pieces - Art/Dock/field.tga, rim.tga,
banner.tga and swords.tga - 256 x 256 each, 32-bit with the ground clear.
Needs Edge and Pillow (pip install pillow). A proof, if named, is the ten in a row on the window's
own dark, to look at before starting the game.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PAGE = os.path.join(HERE, "rank-badges.html")
# each picture on the page, in order, and the file it becomes
NAMES = [("Ranks", f"rank{i}") for i in range(1, 11)] + [("Dock", "field"), ("Dock", "rim"), ("Dock", "banner"), ("Dock", "swords")] + [("Dock", f"level{i}") for i in range(1, 8)]
COUNT, SIZE, SCALE = len(NAMES), 256, 2

EDGES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def edge():
    for path in EDGES:
        if os.path.exists(path):
            return path
    sys.exit("Microsoft Edge was not found; it draws the badges.")


def render(to):
    # a clear ground, the row at its size, and time for the page's script
    subprocess.run([
        edge(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--default-background-color=00000000",
        f"--force-device-scale-factor={SCALE}",
        f"--window-size={COUNT * SIZE},{SIZE}",
        "--virtual-time-budget=3000",
        f"--screenshot={to}",
        "file:///" + PAGE.replace("\\", "/"),
    ], check=True, capture_output=True)


def save_tga(img, path):
    # uncompressed 32-bit TGA, top row first: what the client reads
    w, h = img.size
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, "wb") as f:
        f.write(head)
        f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


def main():
    for folder in {f for f, _ in NAMES}:
        os.makedirs(os.path.join(ROOT, "Art", folder), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        shot = os.path.join(tmp, "badges.png")
        render(shot)
        row = Image.open(shot).convert("RGBA")
    big = SIZE * SCALE
    if row.size[0] < COUNT * big:
        sys.exit(f"the picture is {row.size}, too small for {COUNT} badges at {big}")
    badges = []
    for i in range(COUNT):
        cell = row.crop((i * big, 0, (i + 1) * big, big))
        # brought down with the colour weighted by its alpha, so the clear
        # ground leaves no dark fringe round the edge
        cell = cell.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
        folder, name = NAMES[i]
        save_tga(cell, os.path.join(ROOT, "Art", folder, name + ".tga"))
        badges.append(cell)
        print(f"wrote Art/{folder}/{name}.tga")
    if len(sys.argv) > 1:
        proof = Image.new("RGBA", (COUNT * SIZE, SIZE), (10, 15, 13, 255))
        for i, cell in enumerate(badges):
            proof.alpha_composite(cell, (i * SIZE, 0))
        proof.save(sys.argv[1])
        print(f"wrote {sys.argv[1]}")


if __name__ == "__main__":
    main()
