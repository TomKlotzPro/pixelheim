#!/usr/bin/env python3
# The loading screen (PIX-296): the title's night, drawn here pixel by pixel
# (no pack art, so it can live in this public repo): the sky deepening
# upward in the title's dithered bands, its stars, the moon in its halo, the
# far ranges and the Ashen Mountain smoking with Fafnyr's fire, the pine
# hills, the lake, the village asleep in silhouette with its windows lit,
# two torches on the bank, and PIXELHEIM cut in gold exactly where the title
# draws it (Press Start 2P, the font the game ships, at its own pixels).
# No other words: nothing to translate.
#
# It writes two files:
# - godot/assets/splash.png, 640x360 art pixels (the title's ART): the
#   desktop app's boot splash, shown 2x (project.godot's boot_splash), and the
#   web page's picture (the web export copies it beside index.html), which the
#   title rises out of on a launch;
# - the scene's live points in godot/web/shell.html, between its "splash.py"
#   markers: the stars that twinkle (with the sky behind each), the windows
#   that light one by one as the game loads, the chimneys that smoke, the
#   summit the embers rise from, and where the loading bar sits.
#
#   python3 godot/tools/splash.py           (needs Pillow)
#   python3 godot/tools/splash.py --check   (fails when either file is stale)
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PNG = os.path.join(ROOT, "assets", "splash.png")
SHELL = os.path.join(ROOT, "web", "shell.html")
FONT = os.path.join(ROOT, "assets", "fonts", "press-start-2p.woff2")
BEGIN, END = "/* splash.py: the scene's live points */", "/* splash.py: end */"

W, H = 640, 360


def hexc(code):
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


# The title's numbers (scripts/title_scene.gd, title_screen.gd).
SKY = [hexc(c) for c in ("04061a", "080c28", "0f1238", "1a1847", "2a1f55", "3d275c", "54305c")]
BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
MOON = (556, 58)
SUMMIT = (118, 112)
FAR_RANGE = [(0, 206), (70, 186), (140, 202), (230, 172), (300, 196), (372, 158), (446, 192), (520, 174), (590, 198), (640, 188)]
ASHEN = [(-60, 250), (10, 214), (64, 162), (104, 124), (111, 112), (118, 117), (125, 111), (138, 126), (184, 168), (262, 210), (350, 242), (420, 256)]
HILLS = [(0, 276), (90, 266), (190, 279), (300, 268), (410, 280), (520, 264), (640, 274)]
STREET = 320
LAKE = (277, 304)
# PIXELHEIM: each letter's cell 34 art pixels on (64 + 4 canvas pixels), a
# font pixel 4 art pixels, the face's top at art row 42 (canvas 84), its
# lighter top 15 rows deep (30 canvas pixels), the word's left at 168.
LOGO = {"left": 168, "top": 42, "advance": 34, "pixel": 4, "light": 15}
GOLD, GOLD_LIGHT = hexc("f2c14e"), hexc("ffe08f")
BRONZE, BRONZE_DARK, LOGO_OUTLINE = hexc("8a4f14"), hexc("4a2408"), hexc("140a03")
# Where the title's menu will rise: the loading bar sits there, the dock's
# pixel bar (a night outline, the fill lit along its top).
BAR = {"x": 272, "y": 146, "w": 96, "h": 5}
NIGHT_OUTLINE = hexc("1c120a")
WINDOW_GLASS, WINDOW_CORE, WINDOW_FRAME = hexc("f2b04e"), hexc("ffe3a0"), hexc("3a2214")
WINDOW_DARK = hexc("17142c")


class Dice:
    """A small fixed generator (mulberry32): the same scene every run."""

    def __init__(self, seed):
        self.state = seed & 0xFFFFFFFF

    def next(self):
        self.state = (self.state + 0x6D2B79F5) & 0xFFFFFFFF
        t = self.state
        t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
        t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

    def between(self, low, high):
        return low + (high - low) * self.next()

    def whole(self, low, high):
        return int(low + (high - low + 1) * self.next())


def noise_1d(seed, frequency, octaves=4):
    """Fractal value noise along a line, -1..1: a ridge's roughness."""
    dice = Dice(seed)
    table = [dice.between(-1.0, 1.0) for _ in range(512)]

    def at(x):
        total, amp, freq, norm = 0.0, 1.0, frequency, 0.0
        for _ in range(octaves):
            f = x * freq
            i = math.floor(f)
            t = f - i
            t = t * t * (3 - 2 * t)
            a, b = table[i % 512], table[(i + 1) % 512]
            total += (a + (b - a) * t) * amp
            norm += amp
            amp *= 0.5
            freq *= 2.0
        return total / norm
    return at


class Canvas:
    def __init__(self):
        self.px = [[(0, 0, 0)] * W for _ in range(H)]

    def put(self, x, y, color, alpha=1.0):
        if 0 <= x < W and 0 <= y < H:
            if alpha >= 1.0:
                self.px[y][x] = color
            elif alpha > 0.0:
                base = self.px[y][x]
                self.px[y][x] = tuple(round(base[i] + (color[i] - base[i]) * alpha) for i in range(3))

    def add(self, x, y, color, alpha):
        if 0 <= x < W and 0 <= y < H:
            base = self.px[y][x]
            self.px[y][x] = tuple(min(255, round(base[i] + color[i] * alpha)) for i in range(3))

    def rect(self, x, y, w, h, color, alpha=1.0):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, color, alpha)

    def get(self, x, y):
        return self.px[y][x]

    def image(self):
        image = Image.new("RGB", (W, H))
        image.putdata([c for row in self.px for c in row])
        return image


def glow(canvas, center, radius, color, peak, steps, additive):
    """A light in stepped rings (TitleScene.glow_texture)."""
    cx, cy = center
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
            if d >= 1.0:
                continue
            level = math.ceil((1.0 - d) * steps) / steps
            alpha = peak * level * level
            if additive:
                canvas.add(x, y, color, alpha)
            else:
                canvas.put(x, y, color, alpha)


def sky(canvas):
    last = len(SKY) - 1
    for y in range(H):
        t = pow(y / (H - 1.0), 1.4) * last
        band = min(int(t), last - 1)
        into = min(1.0, max(0.0, (t - band - 0.55) / 0.45))
        for x in range(W):
            threshold = (BAYER[(y % 4) * 4 + x % 4] + 0.5) / 16.0
            canvas.put(x, y, SKY[band + 1] if into > threshold else SKY[band])


def stars(canvas, shine=True):
    """The title's field: faint pixels, the brightest few small crosses. A
    third of them twinkle on the web page: their places (drawn or not, so a
    scene without them gives the sky behind each)."""
    dice = Dice(1984)
    twinkling = []
    for i in range(110):
        x, y = dice.whole(0, W - 1), dice.whole(0, 200)
        bright = dice.next()
        if math.hypot(x - MOON[0], y - MOON[1]) < 30:
            continue
        color = (255, 242, 209)
        if shine:
            canvas.put(x, y, color, 0.2 + 0.65 * bright)
            if bright > 0.94:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    canvas.put(x + dx, y + dy, color, 0.35)
        if i % 3 == 0 and bright > 0.35:
            twinkling.append((x, y))
    return twinkling


def moon(canvas):
    glow(canvas, MOON, 56, hexc("f4ecd0"), 0.1, 4, False)
    seas = [(13, 12, 4.5), (22, 19, 3.5), (15, 23, 3.0), (24, 10, 2.0)]
    left, top = MOON[0] - 18, MOON[1] - 18
    for y in range(36):
        for x in range(36):
            dx, dy = x + 0.5 - 18, y + 0.5 - 18
            d = math.hypot(dx, dy)
            if d > 17.5:
                continue
            color = hexc("f1e8c8")
            for sx, sy, sr in seas:
                if math.hypot(x + 0.5 - sx, y + 0.5 - sy) < sr:
                    color = hexc("d9cca3")
            if d > 17.5 - 2.2 and dx - dy < -6:
                color = hexc("c9bb90")
            canvas.put(left + x, top + y, color)


def clouds(canvas):
    """Long low clouds, moonlit along their tops (TitleScene._cloud_texture)."""
    for width, (left, top), seed in ((150, (486, 66), 5), (110, (90, 34), 9), (190, (250, 128), 13)):
        dice = Dice(seed * 101)
        height = 20
        puffs = [(dice.between(12, width - 12), dice.between(10, 13), dice.between(7, 15), dice.between(3, 6)) for _ in range(width // 12)]

        def inside(x, y):
            if y < 0 or y >= height - 4:
                return False
            return any(((x + 0.5 - px) / rx) ** 2 + ((y + 0.5 - py) / ry) ** 2 <= 1.0 for px, py, rx, ry in puffs)
        for y in range(height):
            for x in range(width):
                if not inside(x, y):
                    continue
                color, alpha = (31, 28, 69), 0.92
                if not inside(x, y - 1):
                    color, alpha = (64, 61, 115), 0.95
                elif not inside(x, y + 1) or not inside(x, y + 2):
                    color, alpha = (20, 18, 51), 0.92
                canvas.put(left + x, top + y, color, alpha)


def ridge_tops(points, base, rough, seed, frequency=0.045, smooth=False):
    noise = noise_1d(seed, frequency)
    tops = []
    for x in range(W):
        y = float(base)
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            if ax <= x <= bx:
                t = (x - ax) / (bx - ax)
                if smooth:
                    t = t * t * (3 - 2 * t)
                y = ay + (by - ay) * t
        if x < points[0][0] or x > points[-1][0]:
            y = base
        tops.append(int(round(y + noise(x + 1000) * rough * 2.0)))
    return tops


def ridge(canvas, tops, base, fill, rim, crater=None):
    """A silhouette with moonlight on the slopes facing the moon (Ridge)."""
    for x, top in enumerate(tops):
        if top >= base:
            continue
        canvas.rect(x, top, 1, base - top, fill)
        after = tops[min(x + 1, W - 1)]
        before = tops[max(x - 1, 0)]
        if after >= top and before <= top + 1:
            canvas.rect(x, top, 1, 2 if after > top + 1 else 1, rim)
        if crater and crater[0] <= x <= crater[1]:
            canvas.put(x, top, hexc("ffb04a"))
            canvas.put(x, top + 1, hexc("c2401c"))


def smoke(canvas):
    """The plume off the summit, lit red from below, drifting west and
    thinning as it goes (the title's smoke, held still)."""
    dice = Dice(77)
    near, mid, far = (150, 60, 54), (70, 52, 92), (46, 40, 80)
    steps = 34
    for k in range(steps):
        t = k / (steps - 1.0)
        x = SUMMIT[0] - 2 - t * 112 + math.sin(t * 7.0) * 3.0
        y = SUMMIT[1] - 6 - t * 74 + t * t * 26
        radius = 1.6 + t * 5.5
        color = tuple(round(near[i] + (mid[i] - near[i]) * min(1.0, t * 3)) for i in range(3)) if t < 0.33 else \
            tuple(round(mid[i] + (far[i] - mid[i]) * (t - 0.33) / 0.67) for i in range(3))
        alpha = 0.5 * (1.0 - t) ** 1.3 + 0.06
        cx, cy = x + dice.between(-1.2, 1.2), y + dice.between(-0.8, 0.8)
        for yy in range(int(cy - radius) - 1, int(cy + radius) + 2):
            for xx in range(int(cx - radius) - 1, int(cx + radius) + 2):
                if math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) <= radius:
                    canvas.put(xx, yy, color, alpha)


def mist(canvas):
    shade = (107, 112, 179)
    for y in range(222, 292):
        t = (y - 222) / 70.0
        strength = 0.16 * (t / 0.6 if t < 0.6 else 1.0 - (t - 0.6) / 0.4 * 0.6)
        for x in range(W):
            wave = 0.5 + 0.5 * math.sin(x * 0.031 + y * 0.11) * math.sin(x * 0.013 - y * 0.05)
            canvas.put(x, y, shade, stepped(strength * wave, 0.04))


def pine(canvas, x, foot, color):
    """A small pixel pine, three tiers on a stub of trunk, its foot at `foot`."""
    tiers = [(1, 0), (2, 1), (1, 2), (3, 3), (2, 4), (4, 5), (3, 6), (5, 7), (4, 8), (6, 9), (5, 10)]
    top = foot - 13
    for half, row in tiers:
        canvas.rect(x - half, top + row, half * 2 + 1, 1, color)
    canvas.rect(x, top + 11, 1, 2, color)


def hills(canvas):
    tops = ridge_tops(HILLS, 330, 1.5, 5, 0.02, True)
    dice = Dice(7)
    rows = [((26, 31, 56), 0, (5, 11)), ((33, 43, 71), 5, (7, 15))]
    for index, (color, drop, gap) in enumerate(rows):
        x = -4.0 + index * 6
        while x < W + 8:
            top = tops[min(max(int(x), 0), W - 1)]
            pine(canvas, int(x), top + 3 + drop, color)
            x += dice.between(*gap)
        if index == 0:
            ridge(canvas, tops, 330, hexc("0d1222"), hexc("1a2240"))


def lake(canvas):
    """The water behind the street, the moon's light broken on it."""
    dice = Dice(31)
    for y in range(LAKE[0], LAKE[1]):
        depth = (y - LAKE[0]) / (LAKE[1] - LAKE[0])
        base = tuple(round(a + (b - a) * depth) for a, b in zip((20, 36, 84), (13, 24, 60)))
        for x in range(W):
            canvas.put(x, y, base)
    for _ in range(70):
        x, y = dice.whole(150, 470), dice.whole(LAKE[0] + 2, LAKE[1] - 3)
        length = dice.whole(2, 6)
        canvas.rect(x, y, length, 1, (92, 116, 176), 0.6)
    for _ in range(14):
        x, y = dice.whole(0, W - 1), dice.whole(LAKE[0] + 1, LAKE[1] - 2)
        canvas.put(x, y, (190, 200, 230), 0.7)
    canvas.rect(0, LAKE[0], W, 1, (8, 12, 30))


# The village, asleep: [left, wall top, width, roof peak, chimney x or None,
# window xs]. Two cottages on the left, two on the right, the lake between.
HOUSES = [
    (-6, 286, 98, 244, 60, [10, 34, 62]),
    (94, 292, 76, 258, 112, [108, 142]),
    (430, 290, 92, 250, 470, [446, 494]),
    (528, 284, 118, 238, 610, [544, 572, 604]),
]
ROOF, ROOF_LIT, ROOF_DARK = hexc("2b2244"), hexc("4a3d6e"), hexc("1a1530")
WALL, WALL_BEAM = hexc("1d1a33"), hexc("2a2545")


def village(canvas, lit=True):
    windows, chimneys = [], []
    for left, wall_top, width, peak, chimney, panes in HOUSES:
        right = left + width
        middle = left + width / 2.0
        # The roof: a gable from the eaves (2 px out each side) to its peak.
        eaves = wall_top + 2
        for y in range(peak, eaves + 1):
            t = (y - peak) / max(1, eaves - peak)
            half = 6 + t * (width / 2.0 - 6 + 3)
            x0, x1 = int(middle - half), int(middle + half)
            canvas.rect(x0, y, x1 - x0 + 1, 1, ROOF)
            # Moonlight on the roof's east slope, the eaves' shadow under it.
            canvas.put(x1, y, ROOF_LIT)
            canvas.put(x1 - 1, y, ROOF_LIT, 0.5)
            canvas.put(x0, y, ROOF_DARK)
        canvas.rect(int(middle - 6), peak - 1, 13, 1, ROOF_LIT)
        for y in range(peak + 6, eaves, 5):
            canvas.rect(int(middle - 6 - (y - peak) * (width / 2.0 - 3) / max(1, eaves - peak)), y, int(12 + (y - peak) * (width - 6) / max(1, eaves - peak)), 1, ROOF_DARK, 0.5)
        if chimney is not None:
            ctop = peak + 4 + abs(chimney - middle) * (eaves - peak) / (width / 2.0) - 14
            ctop = int(ctop)
            canvas.rect(chimney, ctop, 7, eaves - ctop, ROOF_DARK)
            canvas.rect(chimney - 1, ctop, 9, 2, ROOF)
            canvas.rect(chimney + 6, ctop + 2, 1, eaves - ctop - 2, ROOF_LIT, 0.6)
            chimneys.append([chimney + 3, ctop - 1])
        # The walls and their beams.
        canvas.rect(left, eaves + 1, width, STREET - eaves - 1, WALL)
        canvas.rect(left, eaves + 1, width, 1, ROOF_DARK)
        for x in range(left + 4, right - 2, 24):
            canvas.rect(x, eaves + 2, 2, STREET - eaves - 2, WALL_BEAM)
        canvas.rect(left, STREET - 9, width, 1, WALL_BEAM)
        # The door, dark, and the windows, lit.
        door = int(middle) - 4
        canvas.rect(door, STREET - 14, 9, 14, hexc("120f22"))
        canvas.rect(door, STREET - 15, 9, 1, WALL_BEAM)
        for x in panes:
            y = STREET - 20
            canvas.rect(x - 1, y - 1, 12, 10, WINDOW_FRAME)
            canvas.rect(x, y, 10, 8, WINDOW_GLASS if lit else WINDOW_DARK)
            canvas.rect(x + 1, y + 1, 3, 3, WINDOW_CORE if lit else WINDOW_DARK)
            canvas.rect(x + 6, y + 1, 3, 3, WINDOW_CORE if lit else WINDOW_DARK)
            canvas.rect(x + 4, y, 2, 8, WINDOW_FRAME)
            canvas.rect(x, y + 4, 10, 1, WINDOW_FRAME)
            windows.append([x, y, 10, 8])
    return sorted(windows), chimneys


def bank_and_street(canvas):
    canvas.rect(0, LAKE[1], W, STREET - LAKE[1], hexc("141a2c"))
    canvas.rect(0, LAKE[1], W, 1, hexc("222b44"))
    for y in range(STREET, H):
        for x in range(W):
            road = abs(x - 320) < 150 + (y - STREET) * 2
            base = hexc("1f2236") if road else hexc("172034")
            speck = hexc("262a42") if road else hexc("1c2840")
            canvas.put(x, y, speck if BAYER[(y % 4) * 4 + x % 4] < 3 else base)
    canvas.rect(0, STREET, W, 1, hexc("0e1222"))
    # Fence posts along the bank.
    for x in range(178, 462, 12):
        if 300 < x < 340:
            continue
        canvas.rect(x, STREET - 9, 2, 9, hexc("2a2440"))
        canvas.rect(x, STREET - 7, 12, 1, hexc("2a2440"))
    # The fountain's dark rim in the street.
    canvas.rect(308, 326, 24, 6, hexc("262642"))
    canvas.rect(310, 324, 20, 2, hexc("33335a"))
    canvas.rect(318, 316, 4, 8, hexc("33335a"))


def torches(canvas):
    for x in (200, 376):
        glow(canvas, (x + 1, STREET - 14), 30, hexc("ff8a30"), 0.32, 6, True)
        canvas.rect(x, STREET - 12, 2, 12, hexc("3a2a24"))
        canvas.rect(x - 1, STREET - 15, 4, 3, hexc("ff9a3a"))
        canvas.rect(x, STREET - 17, 2, 2, hexc("ffd27a"))


def stepped(alpha, step=0.05):
    """`alpha` in steps of `step`: a smooth fall in a few colours, as pixel
    art shades (and a picture that packs small)."""
    return round(alpha / step) * step


def vignette(canvas):
    shade = (5, 3, 13)
    cx, cy = W * 0.5, H * 0.45
    reach = W * 0.65
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / reach
            if d <= 0.55:
                a = 0.12 * d / 0.55
            else:
                a = 0.12 + (0.6 - 0.12) * min(1.0, (d - 0.55) / 0.45)
            canvas.put(x, y, shade, stepped(a))


def glyph(char):
    font = ImageFont.truetype(FONT, 8)
    image = Image.new("L", (8, 8), 0)
    ImageDraw.Draw(image).text((0, 0), char, font=font, fill=255)
    return [[image.getpixel((x, y)) > 127 for x in range(8)] for y in range(8)]


def logo(canvas):
    """PIXELHEIM as the title cuts it: a block of letters stepping back into
    dark bronze (the deepest outlined in near-black within each letter's
    cell), the gold face with its lighter top."""
    pixel = LOGO["pixel"]
    for index, char in enumerate("PIXELHEIM"):
        cells = glyph(char)
        left = LOGO["left"] + index * LOGO["advance"]
        lit = {(gx, gy) for gy in range(8) for gx in range(8) if cells[gy][gx]}

        def letter(drop, color, outline=None):
            if outline is not None:
                # 1.75 font pixels round the letter, kept inside its cell.
                for gy in range(8):
                    for gx in range(8):
                        near = any(math.hypot(gx - lx, gy - ly) <= 1.75 for lx, ly in lit)
                        if near and (gx, gy) not in lit:
                            canvas.rect(left + gx * pixel, LOGO["top"] + drop + gy * pixel, pixel, pixel, outline)
            for gx, gy in lit:
                canvas.rect(left + gx * pixel, LOGO["top"] + drop + gy * pixel, pixel, pixel, color)
        letter(4, BRONZE_DARK, LOGO_OUTLINE)
        letter(3, BRONZE_DARK)
        letter(2, BRONZE)
        letter(1, BRONZE)
        for gx, gy in lit:
            for yy in range(pixel):
                y = LOGO["top"] + gy * pixel + yy
                canvas.rect(left + gx * pixel, y, pixel, 1, GOLD_LIGHT if y < LOGO["top"] + LOGO["light"] else GOLD)


def draw(shine=True, lit=True):
    canvas = Canvas()
    sky(canvas)
    twinkling = stars(canvas, shine)
    moon(canvas)
    clouds(canvas)
    ridge(canvas, ridge_tops(FAR_RANGE, 268, 3.0, 11), 268, hexc("1d1a3f"), hexc("2f2b62"))
    glow(canvas, (SUMMIT[0], SUMMIT[1] + 6), 34, hexc("ff5a20"), 0.5, 6, True)
    # The mountain's foot runs on down into the hills, not off a step.
    ridge(canvas, ridge_tops(ASHEN + [(470, 268)], 268, 5.0, 23), 268, hexc("0a0918"), hexc("2a2654"), (SUMMIT[0] - 6, SUMMIT[0] + 6))
    smoke(canvas)
    mist(canvas)
    hills(canvas)
    lake(canvas)
    bank_and_street(canvas)
    windows, chimneys = village(canvas, lit)
    torches(canvas)
    vignette(canvas)
    logo(canvas)
    return canvas.image(), twinkling, windows, chimneys


def scene():
    """The picture and its live points, read off the scene drawn again: a
    twinkling star dims toward the picture without it, and an unlit window
    is the picture's own dark glass and frame (the vignette darkens each its
    own way), so nothing the page draws over the picture leaves a spot."""
    picture, twinkling, windows, chimneys = draw()
    starless = draw(shine=False)[0]
    unlit = draw(lit=False)[0]

    def ink(image, x, y):
        return "#%02x%02x%02x" % image.getpixel((x, y))
    live = {
        "stars": [[x, y, ink(starless, x, y)] for x, y in twinkling if picture.getpixel((x, y)) != starless.getpixel((x, y))],
        # [x, y, w, h, the dark glass, the frame's cross] left to right.
        "windows": [[x, y, w, h, ink(unlit, x + 1, y + 1), ink(picture, x + 4, y)] for x, y, w, h in windows],
        "chimneys": chimneys, "summit": [SUMMIT[0], SUMMIT[1] - 2], "bar": BAR,
        "outline": "#%02x%02x%02x" % NIGHT_OUTLINE,
        "gold": "#%02x%02x%02x" % hexc("e8b33a"), "goldLight": "#%02x%02x%02x" % hexc("ffe08a"),
    }
    return picture, live


def png_bytes(picture):
    import io
    out = io.BytesIO()
    picture.save(out, "PNG", optimize=True)
    return out.getvalue()


def shell_with(live, shell):
    head, rest = shell.split(BEGIN, 1)
    _, tail = rest.split(END, 1)
    return head + BEGIN + "\nconst SCENE = " + json.dumps(live, separators=(",", ":")) + ";\n" + END + tail


def main():
    image, live = scene()
    data = png_bytes(image)
    shell = open(SHELL, encoding="utf-8").read()
    wanted = shell_with(live, shell)
    if "--check" in sys.argv:
        stale = []
        # The pixels, not the bytes: another zlib packs the same picture
        # another way.
        if not os.path.exists(PNG) or Image.open(PNG).convert("RGB").tobytes() != image.tobytes():
            stale.append(os.path.relpath(PNG, ROOT))
        if wanted != shell:
            stale.append(os.path.relpath(SHELL, ROOT))
        if stale:
            print("stale: %s (run python3 godot/tools/splash.py)" % ", ".join(stale))
            return 1
        return 0
    with open(PNG, "wb") as out:
        out.write(data)
    with open(SHELL, "w", encoding="utf-8") as out:
        out.write(wanted)
    print("splash.png: %d bytes, %d windows, %d twinkling stars" % (len(data), len(live["windows"]), len(live["stars"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
