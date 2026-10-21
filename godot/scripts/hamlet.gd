class_name Hamlet
## areas: town travel field +blackiron* +saltmere* +greyhold* +frostgate* +mountain_road*
## Each settlement beyond Pixelheim its own (PIX-313, the audit's « bare and
## all alike »: Saltmere's long thatch slabs on an empty lawn, the same
## slate cottage at Greyhold, the Frostgate, Blackiron and the mountain, no
## fence, garden, net or boat, no smoke by day, and barrels as tall as the
## villagers beside them), and Morvax's smithy at the top of the mountain
## road (PIX-312: the stock cottage, no chimney, no fire). A settlement's
## look gives:
## - its houses' grammar (PunyTown.plan's style): their walls in the Medieval
##   Age's stone, plaster or planks, a chimney on every roof, the
##   Frostgate's roofs under snow;
## - its stores: the map's barrels and crates drawn at the Puny folk's
##   scale (HamletArt), as its trade keeps them (a quenching tub and coal
##   at the forge, a woodpile by the hermit's hut);
## - its set dressing, placed by hand (DRESSING): Saltmere's boats, drying
##   nets, creels, fish rack and stall and a washing line between two
##   houses; Greyhold's vegetable beds; Blackiron's ore, coal, a cart and a
##   lantern by each miner's door; Morvax's forge stack and the fire's light
##   under his door.
## Nothing moves a house, a door, a path or a villager: what stands blocks
## only open ground off the paths, never a villager's place or a door's
## step, and never so as to close a way (`fits`: the ground round it stays
## one); what lies flat, hangs on a wall, stands on a roof or floats on
## the water blocks nothing. Pure: MapView draws the plan.

## A map's look, by its id.
const LOOKS := {
	"saltmere": "fishing", "greyhold": "fort", "frostgate": "frost", "blackiron": "mine", "mountain_road": "smithy",
}
## Each look's houses (PunyTown.plan's style): their wall row in the
## Medieval Age [left end, middle, right end] (none: Shade's timber
## frame), and snow on the roofs. Every look puts a chimney on each roof.
## Saltmere's cottages are whitewashed, Greyhold's and Morvax's of the
## fort's stone, Blackiron's huts of planks; the Frostgate's hermit keeps
## his timber under the snow.
const HOUSES := {
	"fishing": {"walls": [723, 724, 725]},
	"fort": {"walls": [3799, 3800, 3801]},
	"frost": {"walls": [], "snow": true},
	"mine": {"walls": [5558, 5559, 5561]},
	"smithy": {"walls": [3802, 3803, 3805], "stack": "forge_stack"},
}
## A barrel and a crate outdoors, at the Puny folk's scale (HamletArt): Shade's
## stood as tall as the villager beside them, a barrel on a crate a tower.
## By look, what a settlement keeps in them.
const STORES := {
	"": {"barrel": "keg", "crate": "box"},
	"smithy": {"barrel": "tub", "crate": "coal"},
	"mine": {"barrel": "keg", "crate": "coal"},
}
## Set dressing by map, placed by hand: each a HamletArt piece (`art`) at
## `cell` (its left cell; a piece wider than a cell stands on the cells to
## its right too), and how it stands:
## - (default) on open ground, blocking it (`fits`);
## - `flat`: lying on the ground, the hero walks over it;
## - `moored`: afloat (or drawn up in the shallows), on cells no one walks;
## - `wall`: hung on a house's wall (a net drying, a lantern lit at night);
## - `roof`: standing on a roof (Morvax's forge stack, smoking);
## - `line`: a washing line strung that many cells across, between walls;
## - `glow`: the fire's light under a door;
## - `store`: what a barrel's or a crate's cell is drawn as here.
const DRESSING := {
	"saltmere": [
		{"art": "boat", "cell": Vector2i(29, 26), "moored": true},
		{"art": "boat", "cell": Vector2i(32, 28), "moored": true},
		{"art": "nets", "cell": Vector2i(35, 20)},
		{"art": "fish_rack", "cell": Vector2i(37, 21)},
		{"art": "creels", "cell": Vector2i(44, 18)},
		{"art": "fish_stall", "cell": Vector2i(42, 17)},
		{"line": 2, "cell": Vector2i(40, 14)},
		{"art": "wall_net", "cell": Vector2i(23, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(36, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(45, 14), "wall": true},
	],
	"greyhold": [
		{"art": "garden", "cell": Vector2i(17, 22), "flat": true},
		{"art": "garden", "cell": Vector2i(13, 24), "flat": true},
		{"art": "garden", "cell": Vector2i(14, 24), "flat": true},
	],
	"frostgate": [
		{"store": "woodpile_snow", "cell": Vector2i(7, 38)},
	],
	"blackiron": [
		{"art": "lantern", "cell": Vector2i(20, 15), "wall": true},
		{"art": "lantern", "cell": Vector2i(33, 23), "wall": true},
		{"art": "ore", "cell": Vector2i(16, 14)},
		{"art": "cart", "cell": Vector2i(22, 14)},
		{"art": "coal", "cell": Vector2i(35, 22)},
		{"art": "ore", "cell": Vector2i(29, 22)},
	],
	"mountain_road": [
		{"art": "forge_stack", "cell": Vector2i(19, 3), "roof": true},
		{"glow": true, "cell": Vector2i(17, 5)},
	],
}
## Ground a standing piece never blocks: the roads, the docks and bridges.
const WAYS := ["path", "dock", "bridge", "stone"]
## Afloat: the water a moored boat rides on, and the shallows a boat is
## drawn up into.
const AFLOAT := ["sea", "shore", "water", "deep_sea"]


## The look of map `map_id` ("" for none: the town, the Reach, a room).
static func look_of(map_id: String) -> String:
	return LOOKS.get(map_id, "")


## The houses' style on map `map_id` (PunyTown.plan): {} where none is set.
static func house_style(map_id: String) -> Dictionary:
	var look := look_of(map_id)
	if look == "":
		return {}
	var style: Dictionary = HOUSES[look].duplicate()
	style["chimney"] = true
	return style


## What a barrel's or a crate's cell (`kind`) on map `map_id` is drawn as,
## at `cell`: a HamletArt piece.
static func store(map_id: String, kind: String, cell: Vector2i) -> String:
	for piece: Dictionary in DRESSING.get(map_id, []):
		if piece.has("store") and piece["cell"] == cell:
			return piece["store"]
	return STORES.get(look_of(map_id), STORES[""]).get(kind, STORES[""][kind])


## The dressing `map` takes: {"look", "pieces": [piece], "blocks": [cells]}.
## Each piece is DRESSING's, with its "cells" and "kind" ("stand", "flat",
## "moored", "wall", "roof", "line", "glow"); a standing piece that doesn't
## fit (`fits`) is left out. `kept`: cells a piece must leave open (where
## a villager stands, the hero arrives, a chest...). `grown`: what the
## place's hub has grown since (PIX-324, Hubs.dressing), laid after it.
static func plan(map: MapData, kept: Dictionary, grown: Array[Dictionary] = []) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var blocks: Array[Vector2i] = []
	var out := {"look": look_of(map.id), "pieces": pieces, "blocks": blocks}
	for entry: Dictionary in DRESSING.get(map.id, []) + grown:
		if entry.has("store"):
			continue
		var piece := entry.duplicate()
		piece["kind"] = kind_of(entry)
		piece["cells"] = cells_of(entry)
		if piece["kind"] == "stand":
			if not fits(map, piece["cells"], kept, blocks):
				continue
			blocks.append_array(piece["cells"])
		elif not sits(map, piece):
			continue
		pieces.append(piece)
	return out


## How a dressing entry stands (DRESSING's keys).
static func kind_of(entry: Dictionary) -> String:
	for kind: String in ["flat", "moored", "wall", "roof", "line", "glow"]:
		if entry.has(kind):
			return kind
	return "stand"


## The cells an entry takes: its cell and those its art spans to the right.
static func cells_of(entry: Dictionary) -> Array[Vector2i]:
	var wide := 1
	if entry.has("line"):
		wide = int(entry["line"])
	elif entry.has("art"):
		wide = HamletArt.cells_wide(entry["art"])
	var out: Array[Vector2i] = []
	for i in wide:
		out.append(entry["cell"] + Vector2i(i, 0))
	return out


## Whether a piece that blocks nothing sits where it says: afloat on water,
## on a wall or a roof, over open ground.
static func sits(map: MapData, piece: Dictionary) -> bool:
	for cell: Vector2i in piece["cells"]:
		var tile := map.tile_at(cell)
		match String(piece["kind"]):
			"moored":
				if tile not in AFLOAT:
					return false
			"wall", "roof", "glow":
				if not (tile.begins_with("roof") or tile.begins_with("door")):
					return false
			_:
				if not WorldTiles.is_walkable(tile):
					return false
	return true


## Whether a standing piece may block `cells`: each open ground off the
## roads, no portal, nothing standing there yet (`blocks`, the map's
## covered cells), not a `kept` cell nor the step before a door; and
## blocking them all leaves the open ground round them one, so no way is
## ever closed.
static func fits(map: MapData, cells: Array[Vector2i], kept: Dictionary, blocks: Array[Vector2i]) -> bool:
	var taken := {}
	for cell: Vector2i in cells:
		taken[cell] = true
	for cell: Vector2i in cells:
		var tile := map.tile_at(cell)
		if not map.is_walkable(cell) or tile in WAYS or map.portals.has(cell) or kept.has(cell) or cell in blocks:
			return false
		if map.tile_at(cell + Vector2i.UP).begins_with("door"):
			return false
	# The open cells round the piece, joined to one another round it.
	var ring: Array[Vector2i] = []
	var first: Vector2i = cells[0]
	var last: Vector2i = cells[-1]
	for x in range(first.x - 1, last.x + 2):
		ring.append(Vector2i(x, first.y - 1))
	ring.append(Vector2i(last.x + 1, first.y))
	for x in range(last.x + 1, first.x - 2, -1):
		ring.append(Vector2i(x, first.y + 1))
	ring.append(Vector2i(first.x - 1, first.y))
	var open := ring.filter(func(cell: Vector2i) -> bool:
		return map.is_walkable(cell) and not taken.has(cell) and cell not in blocks)
	if open.is_empty():
		return false
	var seen := {open[0]: true}
	var stack: Array = [open[0]]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not seen.has(next) and next in open:
				seen[next] = true
				stack.append(next)
	return seen.size() == open.size()


## The cells every piece of a map's dressing keeps open: where its
## villagers stand (whatever the story's hour), its portals, its spawn, its
## chests, the packs' homes and the cells round them, and wherever a day's
## patches may grow (`decks`, Gathering's; worked out here when not given).
static func kept_on(map: MapData, decks: Variant = null) -> Dictionary:
	var out := {map.spawn: true}
	var grown: Dictionary = decks if decks != null else Gathering.decks(map)
	for region: String in grown:
		for cell: Vector2i in grown[region]:
			out[cell] = true
	for cell: Vector2i in map.portals:
		out[cell] = true
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["mapId"] == map.id:
			out[Vector2i(int(npc["x"]), int(npc["y"]))] = true
	for recruit: Dictionary in Npcs._data()["recruits"]:
		var found: Dictionary = recruit.get("found", {})
		if found.get("mapId", "") == map.id:
			out[Vector2i(int(found["x"]), int(found["y"]))] = true
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				out[Vector2i(int(spawn["x"]) + dx, int(spawn["y"]) + dy)] = true
	for chest: Dictionary in Interactables.chests_on(map.id):
		out[Vector2i(int(chest["x"]), int(chest["y"]))] = true
	return out


## Every Medieval Age tile a look's houses add (their walls): made up
## front with the town's (PunyTown.pieces).
static func pieces() -> Array[int]:
	var out: Array[int] = []
	for look: String in HOUSES:
		for tile: int in HOUSES[look]["walls"]:
			if tile not in out:
				out.append(tile)
	return out
