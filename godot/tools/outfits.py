#!/usr/bin/env python3
"""Worn-gear looks that Shade's CC0 sheets don't have as drawn (PIX-129,
PIX-173), made from his own by swapping colours; everything else stays his
pixels.

First, the sheets drawn one frame out of step with his template: the Human
Soldier, Human Worker and Orc sheets carry an extra frame at column 3, so
from there every pose sits one column late. Their columns are put back in
step (column 3 dropped, the rest shifted left, the last repeated) into
characters/aligned/, so a head from one and a body from another always
share a pose.

Then the looks: every helm and body the hero can wear gets a colourway of
its own, none the same as another piece's and none the same as a hero's own
sheet, so whatever goes on shows.
- Archer-Leather: the green archer in leather browns (Leather Cap, Leather Armor).
- Archer-Oilskin: Saltmere's tarred sea-green oilcloth (the Oilskin hood and coat).
- Archer-Greymaw: a wolf-grey hood (Greymaw's Hood).
- Archer-Traveler: a dusty blue travelling cloak (Traveler's Cloak).
- Archer-Shadow: charcoal and violet (Shadow Cloak).
- Warrior-Wyrm: the horned warrior's helm blackened, horns gilded (Wyrm Visor).
- Warrior-Blackiron: soot-black iron, ember-hot trim (the Blackiron helm and plate).
- Warrior-Gilded: gold plate on royal blue (City Plate).
- Warrior-Scaled: copper scales on dragon green (Scaled Mail).
- Mage-Frost: ice white and pale blue (the Frostweave hood and robe).
- Mage-Midnight: a midnight-blue robe (Mage Robe).
- Soldier-Iron: plain steel (Iron Armor).
- Guard-Iron: the soldier's helm with a leather plume (Iron Helm).
- Guard-Runic: violet runes on steel (Runic Armor).
- Guard-Warden: Greyhold slate (the Warden's helm and hauberk).
Run from godot/: python3 tools/outfits.py
"""
import os

from PIL import Image

CHARACTERS = "assets/puny/characters"
## Sheets one frame late from column 3 on (checked against Character-Base's
## lower body, frame by frame).
## Only the ones the game draws are re-cut.
SHIFTED = ["Human-Soldier-Cyan", "Human-Soldier-Red", "Human-Worker-Cyan", "Human-Worker-Red", "Orc-Grunt", "Orc-Peon-Red"]
EXTRA_COLUMN = 3

# Shade's ramps, dark to light, shared across his sheets.
STEEL = ["363636", "4d4c4b", "7d7b76", "a29e96", "bebbb5"]
WARRIOR_RED = ["290505", "520c0c", "ae0000", "ff1515"]
ARCHER_GREEN = ["303600", "455000", "627105", "8b9e0f"]
MAGE_TEAL = ["002e27", "004f43", "007966", "00b49d"]
SOLDIER_BLUE = ["00332f", "005355", "007d89"]
GUARD_TEAL = ["002e27", "004f43", "00b49d"]


def ramp(source, target):
    return dict(zip(source, target))


LOOKS = {
    "Archer-Leather": ("Archer-Green", ramp(ARCHER_GREEN, ["3b2212", "5c371b", "7d4f27", "a36d38"])),
    "Archer-Oilskin": ("Archer-Green", ramp(ARCHER_GREEN, ["1c2a26", "2b4038", "3f5b4f", "5b7d6c"])),
    "Archer-Greymaw": ("Archer-Green", ramp(ARCHER_GREEN, ["2a2a2e", "45454b", "66666d", "8e8e96"])),
    "Archer-Traveler": ("Archer-Green", ramp(ARCHER_GREEN, ["1d2633", "2f3b4d", "48586e", "6b7d96"])),
    "Archer-Shadow": ("Archer-Green", ramp(ARCHER_GREEN, ["17141f", "25202f", "383047", "524662"])),
    "Warrior-Wyrm": ("Warrior-Red", {
        **ramp(STEEL, ["1c212c", "2b3242", "455168", "66748c", "8796ae"]),
        **ramp(WARRIOR_RED, ["3d2604", "7a4f0e", "c9952f", "f6dc8a"]),
    }),
    "Warrior-Blackiron": ("Warrior-Red", {
        **ramp(STEEL, ["1b1d24", "2a2d37", "40444f", "575c68", "707684"]),
        **ramp(WARRIOR_RED, ["2a0f02", "5a2405", "a8460a", "f07a1a"]),
    }),
    "Warrior-Gilded": ("Warrior-Red", {
        **ramp(STEEL, ["5c440f", "7a5a14", "a8842a", "c9a640", "ecd27a"]),
        **ramp(WARRIOR_RED, ["0a1030", "15225e", "2a44a8", "4a6ef0"]),
    }),
    "Warrior-Scaled": ("Warrior-Red", {
        **ramp(STEEL, ["3a2410", "5a3a1c", "8a5e32", "b07a45", "d3a06a"]),
        **ramp(WARRIOR_RED, ["06200f", "0f3d1c", "1d6b33", "2fa24d"]),
    }),
    "Mage-Frost": ("Mage-Cyan", ramp(MAGE_TEAL, ["4b5f78", "7f97b3", "b3cbe0", "e6f2ff"])),
    "Mage-Midnight": ("Mage-Cyan", ramp(MAGE_TEAL, ["0d1433", "182557", "2a3d8c", "4766c7"])),
    "Soldier-Iron": ("Soldier-Blue", ramp(SOLDIER_BLUE, ["2a2c30", "45484e", "6a6e76"])),
    "Guard-Iron": ("aligned/Human-Soldier-Cyan", ramp(GUARD_TEAL, ["3a2a10", "6a4a1a", "a87a2e"])),
    "Guard-Runic": ("aligned/Human-Soldier-Cyan", {
        **ramp(STEEL, ["2c2e38", "3b3e4c", "565a6e", "73788f", "9499b0"]),
        **ramp(GUARD_TEAL, ["2a1450", "4a2a8a", "8a6ae8"]),
    }),
    "Guard-Warden": ("aligned/Human-Soldier-Cyan", {
        **ramp(STEEL, ["2e3744", "3f4a5a", "5f6d82", "8090a6", "a6b3c6"]),
        **ramp(GUARD_TEAL, ["0f3a44", "1c5a66", "3a8a96"]),
    }),
}


def rgb(code: str) -> tuple:
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def align(name: str) -> None:
    sheet = Image.open(f"{CHARACTERS}/{name}.png").convert("RGBA")
    columns = sheet.width // 32
    fixed = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for column in range(columns):
        source = column if column < EXTRA_COLUMN else min(column + 1, columns - 1)
        fixed.paste(sheet.crop((source * 32, 0, source * 32 + 32, sheet.height)), (column * 32, 0))
    os.makedirs(f"{CHARACTERS}/aligned", exist_ok=True)
    fixed.save(f"{CHARACTERS}/aligned/{name}.png")
    print(f"{CHARACTERS}/aligned/{name}.png")


def recolour(name: str, source: str, swaps: dict) -> None:
    table = {rgb(a): rgb(b) for a, b in swaps.items()}
    sheet = Image.open(f"{CHARACTERS}/{source}.png").convert("RGBA")
    pixels = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in table:
                pixels[x, y] = table[(r, g, b)] + (a,)
    sheet.save(f"{CHARACTERS}/{name}.png")
    print(f"{CHARACTERS}/{name}.png")


for shifted in SHIFTED:
    align(shifted)
for look, (source, swaps) in LOOKS.items():
    recolour(look, source, swaps)
