# The game's icon (the web build's favicon and home-screen icon, the desktop
# window's), drawn pixel by pixel on a 32x32 grid: the title's gold P in its
# pixel type with the brown drop shadow, on the title's night with its moon,
# a few stars and the grass. Writes godot/assets/icon.png at 16x (512 px), so
# Godot's 128 px favicon is an exact 4x.
#   python3 godot/tools/favicon.py        (needs Pillow)
import os
from PIL import Image
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
H = lambda h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
NIGHT, SKY, MOON, MOON_DIM, STAR = H("0b1026"), H("1b1d3f"), H("f4ecd0"), H("c9c0a3"), H("cfc8b0")
GOLD, GOLD_LIGHT, SHADOW = H("f2c14e"), H("ffe08a"), H("5e3b1d")
GRASS, GRASS_DARK = H("8aa84e"), H("5f7a32")
im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
px = im.load()
for y in range(32):
    for x in range(32):
        # Rounded corners: two pixels cut at each.
        corner = (x < 2 or x > 29) and (y < 2 or y > 29)
        if corner and (min(x, 31 - x) + min(y, 31 - y)) < 2:
            continue
        px[x, y] = NIGHT if y < 10 else SKY if y < 26 else GRASS
for x in range(32):
    if px[x, 26][3]:
        px[x, 26] = GRASS_DARK if x % 3 == 0 else GRASS
# The moon, top right, with a darker crater.
for y in range(3, 10):
    for x in range(21, 28):
        if (x - 24) ** 2 + (y - 6) ** 2 <= 10:
            px[x, y] = MOON
px[23, 5] = MOON_DIM; px[25, 7] = MOON_DIM
for x, y in [(4, 4), (11, 2), (16, 6), (8, 8), (28, 13)]:
    px[x, y] = STAR
# The title's P (Press Start 2P), twice size, shadowed two pixels down-right.
P = ["XXXXXX..", "XX...XX.", "XX...XX.", "XX...XX.", "XXXXXX..", "XX......", "XX......"]
ox, oy = 7, 10
for dx, dy, color in [(2, 2, SHADOW), (0, 0, GOLD)]:
    for r, row in enumerate(P):
        for c, ch in enumerate(row):
            if ch == "X":
                for sy in range(2):
                    for sx in range(2):
                        px[ox + c * 2 + sx + dx, oy + r * 2 + sy + dy] = color
# A lit edge along the top of each stroke.
for r, row in enumerate(P):
    for c, ch in enumerate(row):
        if ch == "X" and (r == 0 or P[r - 1][c] != "X"):
            px[ox + c * 2, oy + r * 2] = GOLD_LIGHT
            px[ox + c * 2 + 1, oy + r * 2] = GOLD_LIGHT
im.resize((512, 512), Image.NEAREST).save(os.path.join(out, "icon.png"))
