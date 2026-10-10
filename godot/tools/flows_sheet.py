#!/usr/bin/env python3
"""The release flows' pictures on one contact sheet (PIX-275), in the flows'
order, each named under its picture, a failed flow's picture (it stays in its
run's folder) named in red with why (its report differed, or a script
error): the whole run judged at a glance, the pictures themselves beside it
at full size. CI's pictures job links it on each pull request. No window, no
Godot: Pillow only.

    python3 godot/tools/flows_sheet.py              # godot/flows/ -> godot/flows/sheet.png
    python3 godot/tools/flows_sheet.py FLOWS OUT    # another flows folder, another sheet

Only the flows this run's results name (godot/flows/runs/<name>/result) are
on it, so an older run's pictures left in the folder aren't.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

from flows import read_flows

HERE = os.path.dirname(os.path.abspath(__file__))
# Each picture at a quarter of the canvas, this many across.
SCALE = 0.25
ACROSS = 4
GAP = 6
LABEL = 18
BACK = (18, 13, 10)
INK = (240, 226, 196)
FAILED = (232, 84, 64)


def order():
    """The flows' names as flows.txt lists them."""
    return [flow[0] for flow in read_flows()]


def pictures(folder):
    """(name, picture path, label) for every flow this run has a result for:
    the label is the flow's name, and why it failed when it did."""
    runs = os.path.join(folder, "runs")
    found = []
    for name in order():
        result = os.path.join(runs, name, "result")
        if not os.path.exists(result):
            continue
        with open(result) as file:
            status, _, line = file.read().partition("|")
        if status == "skip":
            continue
        if status == "ok":
            path, label = os.path.join(folder, name + ".png"), name
        else:
            broke = "SCRIPT ERROR" in line or "Parse Error" in line
            path, label = os.path.join(runs, name, "shot.png"), name + ("  (script error)" if broke else "  (report differs)")
        if os.path.exists(path):
            found.append((name, path, label))
    return found


def sheet(found):
    """The pictures, ACROSS to a row, each named below."""
    with Image.open(found[0][1]) as first:
        width, height = int(first.width * SCALE), int(first.height * SCALE)
    rows = (len(found) + ACROSS - 1) // ACROSS
    out = Image.new("RGB", (ACROSS * (width + GAP) + GAP, rows * (height + LABEL + GAP) + GAP), BACK)
    draw = ImageDraw.Draw(out)
    try:
        font = ImageFont.load_default(13)
    except TypeError:  # Pillow before 10.1: its one small bitmap font
        font = ImageFont.load_default()
    for index, (name, path, label) in enumerate(found):
        x = GAP + (index % ACROSS) * (width + GAP)
        y = GAP + (index // ACROSS) * (height + LABEL + GAP)
        with Image.open(path) as picture:
            out.paste(picture.convert("RGB").resize((width, height), Image.BOX), (x, y))
        draw.text((x + 2, y + height + 2), label, fill=INK if label == name else FAILED, font=font)
    return out


def main():
    args = sys.argv[1:]
    if len(args) not in (0, 2):
        sys.exit(__doc__)
    folder = args[0] if args else os.path.join(HERE, "..", "flows")
    out = args[1] if args else os.path.join(folder, "sheet.png")
    found = pictures(folder)
    if not found:
        sys.exit("no flow's picture in %s" % folder)
    sheet(found).save(out)
    print("FLOWS %s (%d pictures)" % (os.path.abspath(out), len(found)))


if __name__ == "__main__":
    main()
