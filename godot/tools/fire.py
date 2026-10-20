#!/usr/bin/env python3
"""The fires of a burning house (PIX-327): flames drawn in code, in Shade's
fire colours (the four of his Flame sheet: a red rim, an orange body, a
yellow heart and a white core), so they belong to his art and stand without
the paid packs. Our own art, CC0 like the rest of the repo's code.

A flame is one to three tongues side by side, each a teardrop that leans
with a slow sway and is eaten from the top by noise rising through it, so
its tip breaks into flicks that climb and go out. Every frame is whole art
pixels; the noise climbs RISE pixels a frame and wraps after FRAMES frames,
and the sway turns once in the same time, so the strip loops without a seam.

Each kind is one sheet, assets/fire/flame_<kind>.png: FRAMES frames across,
VARIANTS rows down (the same kind drawn from other noise, so flames side by
side never move together). FireArt (scripts/fire_art.gd) cuts them and says
where they burn; its KINDS, FRAMES and VARIANTS are these.

Run from godot/: python3 tools/fire.py
"""
import math
import os

from PIL import Image

OUT = "assets/fire"
FRAMES = 12
VARIANTS = 3
# How far the noise climbs a frame, in pixels (twelve frames a second: 24 px
# a second), and so the noise's period up the strip.
RISE = 2
PERIOD = FRAMES * RISE

# Shade's fire colours, hottest first, and the heat each starts at.
RAMP = [
    (0.86, (0xFF, 0xFF, 0xFF)),
    (0.55, (0xFB, 0xF2, 0x36)),
    (0.32, (0xDF, 0x71, 0x26)),
    (0.10, (0xAC, 0x32, 0x32)),
]

# Each kind: its size (width, height) and its tongues, each (offset from the
# middle as a share of the width, height as a share, its sway's phase,
# its width as a share): a lick on rubble, a tongue along a beam, a post's
# tall flame, and the blaze where a house fell in.
KINDS = {
    "lick": ((9, 13), [(0.0, 1.0, 0.0, 1.0)]),
    "tongue": ((12, 20), [(-0.18, 1.0, 0.0, 0.7), (0.24, 0.7, 0.37, 0.55)]),
    "post": ((10, 26), [(0.0, 1.0, 0.0, 0.75), (0.15, 0.6, 0.5, 0.5)]),
    "blaze": ((20, 34), [(0.0, 1.0, 0.0, 0.55), (-0.3, 0.72, 0.31, 0.45), (0.32, 0.62, 0.63, 0.42)]),
}


def _hash(ix: int, iy: int, seed: int) -> float:
    n = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n ^= n >> 16
    return (n & 0xFFFF) / 65536.0


def _smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def _noise(x: float, y: float, cells_y: int, seed: int) -> float:
    """Value noise that wraps every `cells_y` cells up the strip."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = _smooth(x - ix), _smooth(y - iy)

    def at(a: int, b: int) -> float:
        return _hash(a, b % cells_y, seed)

    top = at(ix, iy) * (1 - fx) + at(ix + 1, iy) * fx
    low = at(ix, iy + 1) * (1 - fx) + at(ix + 1, iy + 1) * fx
    return top * (1 - fy) + low * fy


def frame(kind: str, variant: int, f: int) -> Image.Image:
    (w, h), tongues = KINDS[kind]
    seed = variant * 101 + len(kind) * 7 + 3
    p = f / FRAMES
    scroll = f * RISE
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        b = h - 1 - y
        for x in range(w):
            # Noise rising through the flame: what a pixel samples climbs
            # RISE a frame, so what it eats climbs too.
            n = 0.6 * _noise(x / 4.0, (y + scroll) / 4.0, PERIOD // 4, seed)
            n += 0.4 * _noise(x / 2.0 + 7.3, (y + scroll) / 2.0, PERIOD // 2, seed + 1)
            heat = -1.0
            for offset, tall, phase, wide in tongues:
                turn = _hash(variant, int(phase * 100), 5) + phase
                up = (b + 0.5) / (h * tall)
                if up >= 1.0:
                    continue
                sway = w * 0.14 * up ** 1.5 * (math.sin(2 * math.pi * (p + turn)) + 0.45 * math.sin(4 * math.pi * (p + turn) + 1.3))
                middle = w / 2.0 + offset * w + sway
                foot = 0.72 + 0.28 * min(1.0, up / 0.22)
                half = w / 2.0 * wide * 2.0 * foot * max(0.0, 1.0 - up ** 1.3) ** 0.8 + 0.5
                body = max(0.0, 1.0 - abs(x + 0.5 - middle) / half)
                heat = max(heat, body ** 0.75 * (1.2 - up) * (0.85 + 0.15 * tall))
            heat -= n * (0.18 + 0.7 * (b + 0.5) / h)
            # The foot stays lit: a flame stands on what burns.
            if b < 1 and heat > 0.05:
                heat = max(heat, 0.32)
            for start, colour in RAMP:
                if heat > start:
                    image.putpixel((x, y), colour + (255,))
                    break
    return image


def sheet(kind: str) -> Image.Image:
    (w, h), _ = KINDS[kind]
    out = Image.new("RGBA", (w * FRAMES, h * VARIANTS), (0, 0, 0, 0))
    for variant in range(VARIANTS):
        for f in range(FRAMES):
            out.paste(frame(kind, variant, f), (f * w, variant * h))
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for kind in KINDS:
        path = os.path.join(OUT, "flame_%s.png" % kind)
        sheet(kind).save(path)
        print(path)


if __name__ == "__main__":
    main()
