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
## Each look's houses (PunyTown.plan's style): their wall rows in the
## Medieval Age, a set of [left end, middle, right end] per house in turn
## ([]: Shade's timber frame), and snow on the roofs. Every look puts a
## chimney on each roof but one carrying a stack of its own (DRESSING's
## `roof`: Morvax's forge, Blackiron's) or over a shed (SHEDS). Greyhold's and Morvax's of the fort's stone; at
## Saltmere a whitewashed cottage, a timbered one and one of planks, their
## roofs slate, thatch and moss (the map's roof kinds, PIX-400: they were
## one thatched cottage three times); Blackiron's forge of stone and its
## huts of planks and stone; at the Frostgate the observatory of stone, the
## hermit keeping his timber under the snow and his woodshed of planks.
const PLANKS := [5558, 5559, 5561]
const WHITEWASH := [723, 724, 725]
const FORT := [3799, 3800, 3801]
const HOUSES := {
	"fishing": {"walls": [WHITEWASH, [], PLANKS]},
	"fort": {"walls": [FORT]},
	"frost": {"walls": [FORT, [], PLANKS], "snow": true},
	"mine": {"walls": [FORT, PLANKS]},
	"smithy": {"walls": [[3802, 3803, 3805]]},
}
## Sheds, not homes, by their door: no chimney on the roof, no smoke from
## the door (PIX-400's review: the Frostgate's woodshed under a chimney
## stack read as a tiny cottage).
const SHEDS := {"frostgate": [Vector2i(17, 38)]}
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
## - `on`: laid on what already stands on its cell (a stall's counter, a
##   cart: PIX-382 step 4), that many pixels from the cell's top left;
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
		{"art": "wall_net", "cell": Vector2i(24, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(39, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(42, 14), "wall": true},
		# PIX-400: a lantern by each door, on bare wall as the nets are (never
		# over a window: test_wall_pieces_hang_on_bare_wall); the jetty's head a quay (a keg,
		# a handcart with the catch on it); fish racks down the beach
		# and a boat drawn up on the point's shore.
		{"art": "lantern", "cell": Vector2i(21, 14), "wall": true},
		{"art": "lantern", "cell": Vector2i(36, 14), "wall": true},
		{"art": "lantern", "cell": Vector2i(45, 14), "wall": true},
		{"art": "handcart", "cell": Vector2i(34, 23)},
		{"art": "fish_crate", "cell": Vector2i(34, 23), "on": Vector2i(11, -5)},
		{"art": "keg", "cell": Vector2i(33, 25)},
		{"art": "fish_rack", "cell": Vector2i(23, 21)},
		{"art": "fish_rack", "cell": Vector2i(29, 21)},
		{"art": "boat", "cell": Vector2i(40, 27), "moored": true},
	],
	"greyhold": [
		{"art": "garden", "cell": Vector2i(17, 22), "flat": true},
		{"art": "garden", "cell": Vector2i(13, 24), "flat": true},
		{"art": "garden", "cell": Vector2i(14, 24), "flat": true},
	],
	"frostgate": [
		{"store": "woodpile_snow", "cell": Vector2i(7, 38)},
		# PIX-400: lanterns by the hermit's and the observatory's doors,
		# firewood stacked by his hut and his woodshed, a sledge loaded with
		# it by the road and another at Gunnar's camp.
		{"art": "lantern", "cell": Vector2i(11, 38), "wall": true},
		{"art": "lantern", "cell": Vector2i(26, 6), "wall": true},
		{"art": "lantern", "cell": Vector2i(16, 38), "wall": true},
		{"art": "woodpile_snow", "cell": Vector2i(13, 38)},
		{"art": "woodpile_snow", "cell": Vector2i(19, 38)},
		{"art": "sledge_wood", "cell": Vector2i(20, 39)},
		{"art": "sledge", "cell": Vector2i(31, 38)},
		{"art": "woodpile_snow", "cell": Vector2i(34, 37)},
	],
	"blackiron": [
		{"art": "lantern", "cell": Vector2i(20, 15), "wall": true},
		{"art": "lantern", "cell": Vector2i(33, 23), "wall": true},
		{"art": "ore", "cell": Vector2i(16, 14)},
		{"art": "cart", "cell": Vector2i(22, 14)},
		{"art": "coal", "cell": Vector2i(35, 22)},
		{"art": "ore", "cell": Vector2i(29, 22)},
		# PIX-400: the forge west of the old face, its stack smoking and its
		# fire under the door, a quenching tub and coal by it; an ore cart up
		# at the shaft's path.
		{"art": "forge_stack", "cell": Vector2i(6, 14), "roof": true},
		{"glow": true, "cell": Vector2i(7, 15)},
		{"art": "tub", "cell": Vector2i(5, 15)},
		{"art": "coal", "cell": Vector2i(10, 15)},
		{"art": "cart", "cell": Vector2i(28, 15)},
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
	style["stacks"] = DRESSING.get(map_id, []).filter(func(piece: Dictionary) -> bool: return piece.has("roof")).map(func(piece: Dictionary) -> Vector2i: return piece["cell"]) + SHEDS.get(map_id, [])
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
## "moored", "wall", "roof", "line", "glow", "on"); a standing piece that doesn't
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
		elif not sits(map, piece, blocks):
			continue
		pieces.append(piece)
	return out


## How a dressing entry stands (DRESSING's keys).
static func kind_of(entry: Dictionary) -> String:
	for kind: String in ["flat", "moored", "wall", "roof", "line", "glow", "on"]:
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
## on a wall or a roof, on what a piece laid before it (`blocks`) or a prop
## already stands, over open ground.
static func sits(map: MapData, piece: Dictionary, blocks: Array[Vector2i] = []) -> bool:
	for cell: Vector2i in piece["cells"]:
		var tile := map.tile_at(cell)
		match String(piece["kind"]):
			"on":
				if not (cell in blocks or map.covered.has(cell)):
					return false
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
	for npc: Dictionary in Npcs.townsfolk():
		if npc["mapId"] == map.id:
			out[Vector2i(int(npc["x"]), int(npc["y"]))] = true
	for recruit: Dictionary in Npcs.recruits():
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
		for walls: Array in HOUSES[look]["walls"]:
			for tile: int in walls:
				if tile not in out:
					out.append(tile)
	return out


## Each house on `map` as it's built: its roof kind and its walls' middle
## tile (Shade's timber where its set is none), in PunyTown's order; what
## the report's `homes=` and the tests tell houses apart by (PIX-400).
static func homes(map: MapData) -> Array[String]:
	var out: Array[String] = []
	var walls: Array = house_style(map.id).get("walls", [])
	var houses := PunyTown.houses(map.grid)
	for i in houses.size():
		var own: Array = walls[i % walls.size()] if not walls.is_empty() else []
		out.append("%s/%d" % [houses[i]["kind"], own[1] if not own.is_empty() else PunyTown.WALL])
	return out
