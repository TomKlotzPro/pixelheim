# Shade's furnished corners for the interiors (PIX-163): reads the rectangles
# named in godot/assets/data/interiors.json "sources" out of his Medieval
# Age sample maps (in the private pixelheim-assets checkout) and writes each
# as a vignette of tile ids: its rug (ground tiles, when the source names a
# rug rectangle), its objects (they block), what stands on them (tops) and
# what sits on those, drawn 6 px up (lifted) - his own layers, without the
# villagers his samples stand about (they are tiles too). Rows of a
# source above `floorRow` hang on the back wall. Only tile ids are written:
# the art itself stays in the private repo.
#   python3 godot/tools/vignettes.py <pixelheim-assets checkout> [preview.png]
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(ROOT, "assets", "data", "interiors.json")
## Tile ids from here on are his characters, not furniture.
CHARACTERS = 27500
KIND = {
    "objects": "objects", "object": "objects", "wooden frame": "objects",
    "object top": "tops", "object top offset": "lifted",
}


def layers(group, path=""):
    for layer in group:
        if layer["type"] == "group":
            yield from layers(layer["layers"], path + layer["name"] + "/")
        elif layer["type"] == "tilelayer":
            yield path + layer["name"], layer


def extract(maps, source):
    doc = maps[source["map"]]
    width = doc["width"]
    x0, y0, w, h = source["rect"]
    out = {"size": [w, h], "floorRow": int(source.get("floorRow", 0)), "rug": [], "objects": [], "tops": [], "lifted": []}
    for name, layer in layers(doc["layers"]):
        parts = name.split("/")
        if source.get("group") and parts[0] != source["group"] and len(parts) > 1:
            continue
        kind = KIND.get(parts[-1].lower())
        if source.get("rugOnly"):
            kind = None
        rug = source.get("rug")
        if kind is None and rug is None:
            continue
        for dy in range(h):
            for dx in range(w):
                gid = layer["data"][(y0 + dy) * width + x0 + dx] & 0x1FFFFFFF
                if gid == 0:
                    continue
                # His sample villagers are tiles too: they stay out.
                if gid - 1 >= CHARACTERS:
                    continue
                if kind is not None:
                    out[kind].append([dx, dy, gid - 1])
                elif parts[-1].lower().startswith(("ground", "grass")) and rug[0] <= dx < rug[0] + rug[2] and rug[1] <= dy < rug[1] + rug[3]:
                    out["rug"].append([dx, dy, gid - 1])
    return out


def preview(vignettes, checkout, path):
    from PIL import Image, ImageDraw
    atlas = Image.open(os.path.join(checkout, "retro-rpg/shade/puny-world-medieval/punyworld-atlas.png")).convert("RGBA")
    tile = lambda t: atlas.crop(((t % 220) * 16, (t // 220) * 16, (t % 220) * 16 + 16, (t // 220) * 16 + 16))
    cards = []
    for name, v in vignettes.items():
        w, h = v["size"]
        card = Image.new("RGBA", (max(w * 16, 64), h * 16 + 10), (120, 96, 70, 255))
        for kind, lift in (("rug", 0), ("objects", 0), ("tops", 0), ("lifted", -6)):
            for dx, dy, t in v[kind]:
                card.alpha_composite(tile(t), (dx * 16, dy * 16 + 10 + lift))
        ImageDraw.Draw(card).text((1, 0), name, fill=(255, 255, 0, 255))
        cards.append(card)
    width = 900
    rows, row, x, height = [], [], 0, 0
    for card in cards:
        if x + card.width > width:
            rows.append(row)
            row, x = [], 0
        row.append(card)
        x += card.width + 6
    rows.append(row)
    total = sum(max(c.height for c in r) + 6 for r in rows if r)
    sheet = Image.new("RGBA", (width, total), (40, 40, 40, 255))
    y = 0
    for r in rows:
        x = 0
        for card in r:
            sheet.alpha_composite(card, (x, y))
            x += card.width + 6
        y += max(c.height for c in r) + 6
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)


def main():
    checkout = sys.argv[1]
    tiled = os.path.join(checkout, "retro-rpg/shade/puny-world-medieval/Tiled")
    data = json.load(open(DATA))
    maps = {}
    for source in data["sources"].values():
        if source["map"] not in maps:
            maps[source["map"]] = json.load(open(os.path.join(tiled, source["map"] + ".tmj")))
    data["vignettes"] = {name: extract(maps, source) for name, source in data["sources"].items()}
    # Pieces made by hand from single tiles (the furniture the hero places).
    data["vignettes"].update(data.get("custom", {}))
    open(DATA, "w").write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print("wrote %d vignettes" % len(data["vignettes"]))
    if len(sys.argv) > 2:
        preview(data["vignettes"], checkout, sys.argv[2])


if __name__ == "__main__":
    main()
