#!/usr/bin/env python3
"""The look book side by side (PIX-227): each scene the browser and the desktop
app both shot, the browser's on the left and the app's on the right, one
picture per scene and all of them on one sheet, so the difference is seen at
a glance. No window, no Godot: Pillow only.

    python3 tools/lookbook_compare.py LEFT RIGHT OUT
    tools/lookbook.sh --compare      # lookbook/ | lookbook-desktop/ -> lookbook-compare/

LEFT and RIGHT are look book folders (tools/lookbook.sh writes them); a
look's own folder (lookbook-desktop/glow/) works too.
"""

import os
import sys

from PIL import Image, ImageDraw

# The gap between the two shots, and the sheet's scale (a pair per row).
GAP = 8
SHEET_SCALE = 0.5
BACK = (18, 13, 10)
INK = (240, 226, 196)


def shots(folder):
    """The scenes in a look book folder, by name (01_town_day.png ...)."""
    return sorted(
        name for name in os.listdir(folder)
        if name.endswith(".png") and name[:2].isdigit()
    )


def pair(left, right, labels):
    """Two shots side by side, each labelled in its top-left corner."""
    width = left.width + GAP + right.width
    height = max(left.height, right.height)
    out = Image.new("RGB", (width, height), BACK)
    out.paste(left.convert("RGB"), (0, 0))
    out.paste(right.convert("RGB"), (left.width + GAP, 0))
    draw = ImageDraw.Draw(out)
    for x, label in ((0, labels[0]), (left.width + GAP, labels[1])):
        box = draw.textbbox((0, 0), label)
        draw.rectangle((x, 0, x + box[2] + 12, box[3] + 10), fill=BACK)
        draw.text((x + 6, 4), label, fill=INK)
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    left_dir, right_dir, out_dir = sys.argv[1:]
    both = [name for name in shots(left_dir) if os.path.exists(os.path.join(right_dir, name))]
    if not both:
        sys.exit("no scene is in both %s and %s" % (left_dir, right_dir))
    os.makedirs(out_dir, exist_ok=True)
    # Pictures to look at, not the game's: Godot leaves the folder alone.
    open(os.path.join(out_dir, ".gdignore"), "a").close()
    labels = (os.path.basename(os.path.normpath(left_dir)), os.path.basename(os.path.normpath(right_dir)))
    rows = []
    for name in both:
        with Image.open(os.path.join(left_dir, name)) as left, Image.open(os.path.join(right_dir, name)) as right:
            row = pair(left, right, labels)
        row.save(os.path.join(out_dir, name))
        rows.append(row.resize((int(row.width * SHEET_SCALE), int(row.height * SHEET_SCALE)), Image.BILINEAR))
    sheet = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows) + GAP * (len(rows) - 1)), BACK)
    y = 0
    for row in rows:
        sheet.paste(row, (0, y))
        y += row.height + GAP
    sheet.save(os.path.join(out_dir, "sheet.png"))
    print("LOOK %s/sheet.png (%d scenes)" % (os.path.abspath(out_dir), len(rows)))


if __name__ == "__main__":
    main()
