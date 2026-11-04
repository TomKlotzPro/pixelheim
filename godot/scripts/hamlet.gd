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
##   houses; Greyhold's vegetable beds, and its fort's hay, racks, armour,
##   anvil, dummy, cart, lanterns and the colours of whoever holds it
##   (PIX-399, HELD); Blackiron's ore, coal, a cart and a
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
		{"art": "wall_net", "cell": Vector2i(23, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(36, 14), "wall": true},
		{"art": "wall_net", "cell": Vector2i(45, 14), "wall": true},
	],
	"greyhold": [
		{"art": "garden", "cell": Vector2i(17, 22), "flat": true},
		{"art": "garden", "cell": Vector2i(13, 24), "flat": true},
		{"art": "garden", "cell": Vector2i(14, 24), "flat": true},
		# The fort lived in (PIX-399): hay and a trough by the stable, stores
		# by the barracks and armour on its stand, racks along the walls, the
		# smithy's anvil and grindstone, a dummy in the drill yard, a
		# supply cart in from the west gate, a lantern by each new door.
		{"tile": Yards.HAY, "cell": Vector2i(25, 5)},
		{"tile": Yards.HAY, "cell": Vector2i(26, 5)},
		{"art": "tub", "cell": Vector2i(33, 6)},
		{"art": "lantern", "cell": Vector2i(31, 7), "wall": true},
		{"art": "keg", "cell": Vector2i(47, 5)},
		{"art": "box", "cell": Vector2i(47, 6)},
		{"art": "lantern", "cell": Vector2i(45, 7), "wall": true},
		{"tile": ARMOUR, "cell": Vector2i(42, 10)},
		{"tile": POLEARMS, "cell": Vector2i(49, 14)},
		{"tile": SPEARS, "cell": Vector2i(49, 15)},
		{"tile": SWORDS, "cell": Vector2i(49, 16)},
		{"tile": SWORDS, "cell": Vector2i(25, 20)},
		{"tile": POLEARMS, "cell": Vector2i(25, 21)},
		{"tile": Yards.ANVIL, "cell": Vector2i(38, 23)},
		{"tile": Yards.GRINDSTONE, "cell": Vector2i(42, 23)},
		{"art": "lantern", "cell": Vector2i(41, 22), "wall": true},
		{"tile": DUMMY, "cell": Vector2i(33, 21)},
		{"art": "handcart", "cell": Vector2i(26, 13)},
		{"tile": Yards.FLOUR, "cell": Vector2i(26, 13), "on": Vector2i(2, -6)},
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
## The Medieval Age's own pieces Greyhold's fort is dressed in (PIX-399):
## weapon racks (polearms, spears, swords), armour on its stand, the
## training dummy, and banners two tiles tall, the rod on top: the
## turncoats' red and the fort's own teal.
const POLEARMS := 1246
const SPEARS := 1247
const SWORDS := 1465
const ARMOUR := 1907
const DUMMY := 3006
const BANNERS := {"red": [9152, 9372], "teal": [11792, 12012]}
## Who holds a settlement, by map (PIX-399): `by` until the named foe
## `until` is down (GameState.progression.hunted), `then` after, and the
## dressing each lays under its name. Greyhold's keep hangs the turncoats'
## red while the Hollow Captain holds its cellars; once he stands down the
## fort's teal goes up on the keep and the barracks and its garrison's
## drill fills the yard. A `banner` hangs on the wall at its cell, its rod
## a cell above.
const HELD := {
	"greyhold": {
		"until": "hollow_captain", "by": "turncoats", "then": "garrison",
		"turncoats": [
			{"banner": "red", "cell": Vector2i(34, 12)},
			{"banner": "red", "cell": Vector2i(40, 12)},
		],
		"garrison": [
			{"banner": "teal", "cell": Vector2i(34, 12)},
			{"banner": "teal", "cell": Vector2i(40, 12)},
			{"banner": "teal", "cell": Vector2i(43, 7)},
			{"tile": DUMMY, "cell": Vector2i(35, 21)},
			{"tile": ARMOUR + 1, "cell": Vector2i(42, 12)},
			{"tile": SPEARS, "cell": Vector2i(25, 23)},
			{"tile": Yards.HAY, "cell": Vector2i(25, 6)},
		],
	},
}
## Ground a standing piece never blocks: the roads, the docks and bridges.
const WAYS := ["path", "dock", "bridge", "stone"]
## A look's yard: ground of WAYS that is no way there (PIX-399: Greyhold's
## courtyard is flagged all over; its ways are the paths across it).
const YARDS := {"fort": ["stone"]}
## Afloat: the water a moored boat rides on, and the shallows a boat is
## drawn up into.
const AFLOAT := ["sea", "shore", "water", "deep_sea"]


## The look of map `map_id` ("" for none: the town, the Reach, a room).
static func look_of(map_id: String) -> String:
	return LOOKS.get(map_id, "")


## Whether `tile` is a way on map `map_id`, which a standing piece never
## blocks (WAYS, but for its look's yard).
static func is_way(map_id: String, tile: String) -> bool:
	return tile in WAYS and tile not in YARDS.get(look_of(map_id), [])


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


## Who holds map `map_id` now, the named foes down being `hunted` (HELD):
## "" where no one does.
static func holder(map_id: String, hunted: Array) -> String:
	var held: Dictionary = HELD.get(map_id, {})
	if held.is_empty():
		return ""
	return held["then"] if held["until"] in hunted else held["by"]


## The dressing of whoever holds map `map_id` now (HELD), as Hamlet.plan's
## `grown` entries: a banner as its two tiles hung on the wall, the rod's
## a cell above its own.
static func held(map_id: String, hunted: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by := holder(map_id, hunted)
	if by == "":
		return out
	for entry: Dictionary in HELD[map_id][by]:
		if not entry.has("banner"):
			out.append(entry)
			continue
		var tiles: Array = BANNERS[entry["banner"]]
		out.append({"tile": tiles[0], "cell": entry["cell"] + Vector2i.UP, "wall": true, "banner": entry["banner"]})
		out.append({"tile": tiles[1], "cell": entry["cell"], "wall": true, "banner": entry["banner"]})
	return out


## The dressing `map` takes: {"look", "pieces": [piece], "blocks": [cells]}.
## Each piece is DRESSING's, with its "cells" and "kind" ("stand", "flat",
## "moored", "wall", "roof", "line", "glow", "on"); a standing piece that doesn't
## fit (`fits`) is left out. `kept`: cells a piece must leave open (where
## a villager stands, the hero arrives, a chest...). `grown`: what the
## place's hub has grown since (PIX-324, Hubs.dressing), laid after it.
## Without the paid pack (`paid` false) the pack's own pieces (`tile`) are
## left out: their sheet isn't there.
static func plan(map: MapData, kept: Dictionary, grown: Array[Dictionary] = [], paid := true) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var blocks: Array[Vector2i] = []
	var out := {"look": look_of(map.id), "pieces": pieces, "blocks": blocks}
	for entry: Dictionary in DRESSING.get(map.id, []) + grown:
		if entry.has("store") or (entry.has("tile") and not paid):
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
		if not map.is_walkable(cell) or is_way(map.id, tile) or map.portals.has(cell) or kept.has(cell) or cell in blocks:
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
		for tile: int in HOUSES[look]["walls"]:
			if tile not in out:
				out.append(tile)
	return out
