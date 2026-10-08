# Maps from sketches (PIX-164): a region map is drawn as text, one character
# per tile, and this turns it into the game's map JSON (assets/maps/<id>.json,
# one row of tiles per line, with its regions layer, spawn and portals).
#
# A sketch (godot/maps-src/<id>.txt):
#   id saltmere
#   style cave                           (optional: drawn in dungeon stone)
#   tint 0.8 0.92 1.1                    (optional: a cast over the ground)
#   spawn 4 20
#   portal 0 20 map overworld 16 61      (x y map <mapId> <x> <y>)
#   portal 30 5 dungeon seacave          (x y dungeon <dungeonId>)
#   key . grass coast                    (char, tile, region or -)
#   key ~ shore -
#   map
#   ^^^^^^^^
#   ^..~~..^
#   ...
# Every row as long as the first; every character keyed.
#   python3 godot/tools/mapgen.py [ids...]    (all sketches by default)
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SKETCHES = os.path.join(ROOT, "maps-src")
MAPS = os.path.join(ROOT, "assets", "maps")


def parse(path):
    doc = {"keys": {}, "portals": [], "rows": []}
    reading = False
    for raw in open(path).read().splitlines():
        if reading:
            if raw.strip():
                doc["rows"].append(raw.rstrip())
            continue
        line = raw.split("#", 1)[0].strip() if not raw.startswith("key") else raw.strip()
        if not line:
            continue
        word = line.split()
        if word[0] == "id":
            doc["id"] = word[1]
        elif word[0] == "style":
            doc["style"] = word[1]
        elif word[0] == "tint":
            doc["tint"] = [float(w) for w in word[1:4]]
        elif word[0] == "spawn":
            doc["spawn"] = {"x": int(word[1]), "y": int(word[2])}
        elif word[0] == "portal":
            at = {"x": int(word[1]), "y": int(word[2])}
            if word[3] == "map":
                at["to"] = {"kind": "map", "mapId": word[4], "x": int(word[5]), "y": int(word[6])}
            else:
                at["to"] = {"kind": "dungeon", "dungeon": word[4]}
            doc["portals"].append(at)
        elif word[0] == "key":
            char = raw.split()[1]
            doc["keys"][char] = (word[2], None if word[3] == "-" else word[3])
        elif word[0] == "map":
            reading = True
    width = len(doc["rows"][0])
    for y, row in enumerate(doc["rows"]):
        if len(row) != width:
            raise SystemExit("%s: row %d is %d wide, not %d" % (path, y, len(row), width))
        for x, char in enumerate(row):
            if char not in doc["keys"]:
                raise SystemExit("%s: '%s' at %d,%d has no key" % (path, char, x, y))
    return doc


def write(doc):
    rows = doc["rows"]
    tiles = [[doc["keys"][c][0] for c in row] for row in rows]
    regions = [[doc["keys"][c][1] for c in row] for row in rows]
    out = ["{", '  "id": %s,' % json.dumps(doc["id"]), '  "width": %d,' % len(rows[0]), '  "height": %d,' % len(rows)]
    if doc.get("style"):
        out.append('  "style": %s,' % json.dumps(doc["style"]))
    if doc.get("tint"):
        out.append('  "tint": %s,' % json.dumps(doc["tint"]))
    out.append('  "spawn": %s,' % json.dumps(doc["spawn"], indent=2).replace("\n", "\n  "))
    out.append('  "portals": %s,' % json.dumps(doc["portals"], indent=2).replace("\n", "\n  "))
    out.append('  "tiles": [')
    out.append(",\n".join("    " + json.dumps(row) for row in tiles))
    out.append("  ],")
    out.append('  "regions": [')
    out.append(",\n".join("    " + json.dumps(row) for row in regions))
    out.append("  ]")
    out.append("}")
    path = os.path.join(MAPS, doc["id"] + ".json")
    open(path, "w").write("\n".join(out) + "\n")
    print("wrote %s (%dx%d)" % (path, len(rows[0]), len(rows)))


def main():
    names = sys.argv[1:] or [f[:-4] for f in sorted(os.listdir(SKETCHES)) if f.endswith(".txt")]
    for name in names:
        write(parse(os.path.join(SKETCHES, name + ".txt")))


if __name__ == "__main__":
    main()
