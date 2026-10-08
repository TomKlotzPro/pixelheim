#!/usr/bin/env python3
"""Worn-gear looks that Shade's CC0 sheets don't have as drawn (PIX-129),
made from his own by swapping colours; everything else stays his pixels.
- Archer-Leather.png: the green archer in leather browns (Leather Cap,
  Leather Armor).
- Warrior-Wyrm.png: the horned warrior's helm in blackened steel with gilded
  horns (Wyrm Visor), so it differs from every warrior's own helm.
Run from godot/: python3 tools/outfits.py
"""
from PIL import Image

LOOKS = {
    "Archer-Leather": ("Archer-Green", {
        "303600": "3b2212", "455000": "5c371b", "627105": "7d4f27", "8b9e0f": "a36d38",
    }),
    "Warrior-Wyrm": ("Warrior-Red", {
        "363636": "1c212c", "4d4c4b": "2b3242", "7d7b76": "455168", "a29e96": "66748c", "bebbb5": "8796ae",
        "290505": "3d2604", "520c0c": "7a4f0e", "ae0000": "c9952f", "ff1515": "f6dc8a",
    }),
}


def rgb(code: str) -> tuple:
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


for name, (source, swaps) in LOOKS.items():
    table = {rgb(a): rgb(b) for a, b in swaps.items()}
    sheet = Image.open(f"assets/puny/characters/{source}.png").convert("RGBA")
    pixels = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in table:
                pixels[x, y] = table[(r, g, b)] + (a,)
    sheet.save(f"assets/puny/characters/{name}.png")
    print(f"assets/puny/characters/{name}.png")
