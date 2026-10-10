class_name PunyInterior
## The rooms behind the town's doors in Shade's Puny World Medieval Age
## (PIX-133), the way his sample cottages and smithy are furnished: plank
## floors (stone in the smithy), his cream walls one tile thick
## around the room (the web's thicker walls beyond them are dark), windows
## along the back wall, his door, and his furniture on the web's furniture
## cells - and since PIX-163 his furnished corners and rugs (furnish).
## Pure: tile ids only; PunyTown draws them (same atlas).

## Interiors this restyles (the web's room maps; house tiers share an id),
## and since PIX-256 the rooms the Reach's buildings open onto, a stairwell
## down to the cellar under each: Liane's room in her observatory over the
## ice cave, Captain Hale's hall in Greyhold's keep over its cellars.
const ROOMS := ["town_inn", "town_shop", "town_smith", "town_alchemist", "town_hall", "town_house", "observatory", "keep"]
## Rooms with a stone floor: the smithy, and the keep of a fort.
const STONE_ROOMS := ["town_smith", "keep"]

const PLANKS := [5342, 5565, 3550]
const STONE := [1792, 2233, 2453]

## Cream walls by which neighbours are walls too (N=1, E=2, S=4, W=8), read
## off the sample villages' wall layers.
const WALLS := {
	0: 278, 1: 498, 2: 719, 3: 499, 4: 58, 5: 278, 6: 59, 7: 279,
	8: 721, 9: 501, 10: 720, 11: 720, 12: 61, 13: 281, 14: 60, 15: 720,
}
const WINDOW := 3659
## A hearth's and a forge's fire (their lower left), where a room's warm
## light comes from (PIX-221).
const FIRE_TILES := [2565, 2567]
const DOOR := 3875
## The way down (PIX-256): Shade's stairwell from his royal castle sample, a
## flight of stone steps going down into the dark (on his stone floor), in
## the hole of a red carpet laid round it, offset from the stairwell -> tile.
## Its carpet is his castle's, closed all round (his own runs on down the
## hall below it).
const STAIRWELL := 2247
const STAIRWELL_FLOOR := 1790
const STAIRWELL_RING := {
	Vector2i(-1, -1): 8040, Vector2i(0, -1): 8701, Vector2i(1, -1): 8042,
	Vector2i(-1, 0): 8259, Vector2i(1, 0): 8259,
	Vector2i(-1, 1): 8480, Vector2i(0, 1): 8701, Vector2i(1, 1): 8482,
}

## Furniture by web tile: [[offset from its cell, tile], ...]. Offsets above
## the cell lean on the back wall; offsets onto open floor block it (beds
## excepted).
const FURNITURE := {
	"bed": [[Vector2i(0, 0), 1262], [Vector2i(0, 1), 1482]],
	"hearth": [[Vector2i(0, -1), 2345], [Vector2i(1, -1), 2346], [Vector2i(0, 0), 2565], [Vector2i(1, 0), 2566]],
	"forge": [[Vector2i(0, -1), 2347], [Vector2i(1, -1), 2348], [Vector2i(0, 0), 2567], [Vector2i(1, 0), 2568]],
	"anvil": [[Vector2i(0, 0), 2125]],
	"cauldron": [[Vector2i(0, 0), 139]],
	"barrel": [[Vector2i(0, 0), 136]],
	"crate": [[Vector2i(0, 0), 1024]],
	"shelf": [[Vector2i(0, 0), 2996]],
	"trophy_shelf": [[Vector2i(0, 0), 1904]],
	"garden": [[Vector2i(0, 0), 1242]],
}
## The furniture the hero buys and places at home, by item: [[offset from
## its cell, tile]]. A bookshelf rises a cell above its own; the banner
## hangs from a post.
const PLACED := {
	"furn_rug": [[Vector2i(0, 0), 10248]],
	"furn_plant": [[Vector2i(0, 0), 1235]],
	"furn_bookshelf": [[Vector2i(0, -1), 3215], [Vector2i(0, 0), 3435]],
	"furn_banner": [[Vector2i(0, -1), 9373], [Vector2i(0, 0), 3199]],
	"furn_candles": [[Vector2i(0, 0), 808]],
	"furn_bench": [[Vector2i(0, 0), 1659]],
}
## Runs of these draw as one piece with ends: [left end, middle, right end].
const RUNS := {
	"counter": [5180, 5181, 5182],
	"shelf": [2995, 2996, 2998],
	"garden": [1241, 1242, 1243],
	"trophy_shelf": [1904, 1905, 1904],
}


static func is_room(map_id: String) -> bool:
	return map_id in ROOMS


# ---- furnishing (PIX-163) ----------------------------------------------------

static var _doc := {}


## assets/data/interiors.json: Shade's furnished corners lifted from his
## sample maps (tools/vignettes.py), his rugs, and each room's layout.
static func interiors() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/interiors.json"))
	return _doc


## Where a room's dressing may not go: the keepers and the cells about
## them, the way in from each door and the spawn, and the furniture the
## hero has placed ([{x, y}]).
static func reserved(data: MapData, placed: Array) -> Dictionary:
	var out := {data.spawn: true}
	for cell: Vector2i in data.portals:
		for step in [Vector2i.ZERO, Vector2i.UP, Vector2i.UP * 2]:
			out[cell + step] = true
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc.get("mapId", "") == data.id:
			var at := Vector2i(int(npc["x"]), int(npc["y"]))
			for step in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				out[at + step] = true
	# A stairwell's carpet and the floor before it: the way down stays clear
	# to walk up to (PIX-256).
	for cell: Vector2i in data.grid:
		if data.grid[cell] == "stairwell":
			for dy in [-1, 0, 1, 2]:
				for dx in [-1, 0, 1]:
					out[cell + Vector2i(dx, dy)] = true
	for piece: Dictionary in placed:
		out[Vector2i(int(piece["x"]), int(piece["y"]))] = true
	return out


## A room dressed (PIX-163): each vignette of its layout ([name, x, y], x/y
## where its floor rows begin; rows above hang on the back wall) and each
## rug ([family, x, y, w, h], bordered). A vignette goes in whole or not at
## all: never off the floor, onto a wall that isn't the back wall's, onto
## `reserved` cells (keepers, the way in, the hero's own furniture) or onto
## another piece. {"rug", "objects", "tops", "lifted": {cell: tile},
## "blocked": [cells], "skipped": [names]}.
static func furnish(room_key: String, grid: Dictionary, reserved: Dictionary) -> Dictionary:
	var out := {"rug": {}, "objects": {}, "tops": {}, "lifted": {}, "blocked": [], "skipped": []}
	var layout: Dictionary = interiors()["rooms"].get(room_key, {})
	for rug: Array in layout.get("rugs", []):
		var tiles: Array = interiors()["rugFamilies"][rug[0]]
		var w := int(rug[3])
		var h := int(rug[4])
		for dy in h:
			for dx in w:
				var cell := Vector2i(int(rug[1]) + dx, int(rug[2]) + dy)
				if grid.get(cell, "") != "floor":
					continue
				var col := 0 if dx == 0 else (2 if dx == w - 1 else 1)
				var row := 0 if dy == 0 else (2 if dy == h - 1 else 1)
				out["rug"][cell] = int(tiles[row * 3 + col])
	var taken := {}
	for placement: Array in layout.get("pieces", []):
		var piece: Dictionary = interiors()["vignettes"][placement[0]]
		var origin := Vector2i(int(placement[1]), int(placement[2]) - int(piece["floorRow"]))
		var cells := {}
		var fits := true
		for kind: String in ["rug", "objects", "tops", "lifted"]:
			for part: Array in piece[kind]:
				var cell := origin + Vector2i(int(part[0]), int(part[1]))
				var on_wall := int(part[1]) < int(piece["floorRow"])
				var tile: String = grid.get(cell, "")
				if on_wall:
					fits = fits and tile == "wall" and grid.get(cell + Vector2i.DOWN, "") != "wall"
				else:
					fits = fits and tile == "floor" and not reserved.has(cell) and not taken.has(cell)
				cells[cell] = on_wall
		if not fits:
			out["skipped"].append(placement[0])
			continue
		for kind: String in ["rug", "objects", "tops", "lifted"]:
			for part: Array in piece[kind]:
				var cell := origin + Vector2i(int(part[0]), int(part[1]))
				out[kind][cell] = int(part[2])
				if kind in ["objects", "tops"] and not cells[cell]:
					taken[cell] = true
		for cell: Vector2i in cells:
			taken[cell] = true
	for cell: Vector2i in taken:
		if out["objects"].has(cell) or out["tops"].has(cell):
			out["blocked"].append(cell)
	return out


## {"floor": {cell: tile}, "walls": {cell: tile} (the room's walls and
## windows), "pieces": {cell: tile} (door, furniture), "void": [cells] (wall
## beyond the room), "blocked": [cells] (floor the furniture now covers),
## "over": {cell: web tile} (the furniture drawn over a cell beyond its own,
## a bed's foot included)}. Walls are drawn under the pieces (PIX-237):
## Shade's forges and hearths are ovens two tiles tall that reach into the
## wall line, and where their tops replaced the wall, the room's dark
## backdrop showed through their open pixels. A part above its cell leans
## on a plain wall (a window would show through it); a part on the ground
## that reaches into the wall line stands on floor, and the wall wraps
## round it.
static func plan(map_id: String, grid: Dictionary) -> Dictionary:
	var floor := {}
	var walls := {}
	var pieces := {}
	var beyond: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var over := {}
	var choices: Array = STONE if map_id in STONE_ROOMS else PLANKS
	# Wall cells furniture leans on, and wall cells it stands on.
	var leaning := {}
	var standing := {}
	# Doors set in the wall, and the furniture.
	for cell: Vector2i in grid:
		var tile: String = grid[cell]
		if tile == "door" or tile == "door_shut":
			pieces[cell] = DOOR
		elif RUNS.has(tile):
			# Side by side they join into one counter, shelf, planter; alone,
			# the middle piece.
			var run: Array = RUNS[tile]
			var left: bool = grid.get(cell + Vector2i.LEFT, "") == tile
			var right: bool = grid.get(cell + Vector2i.RIGHT, "") == tile
			pieces[cell] = run[1] if left == right else (run[2] if left else run[0])
		elif FURNITURE.has(tile):
			for part: Array in FURNITURE[tile]:
				var at: Vector2i = cell + part[0]
				pieces[at] = part[1]
				if at != cell:
					over[at] = tile
				# Furniture spreading onto open floor blocks it, but a bed's
				# foot stays walkable: the inn wakes its guests there.
				if at != cell and tile != "bed" and grid.get(at, "") == "floor":
					blocked.append(at)
				if grid.get(at, "") == "wall":
					if part[0].y < 0:
						leaning[at] = true
					else:
						standing[at] = true
	# The room: everything that isn't wall gets floor (furniture stands on
	# it), and so does the wall line where furniture stands in it. Doors
	# stand in the wall line, so they are not room.
	var inside := func(cell: Vector2i) -> bool:
		if standing.has(cell):
			return true
		return grid.has(cell) and grid[cell] != "wall" and not String(grid[cell]).begins_with("door")
	for cell: Vector2i in grid:
		if inside.call(cell) or String(grid[cell]).begins_with("door"):
			floor[cell] = choices[absi(cell.x * 7 + cell.y * 13) % choices.size()]
	# The way down (PIX-256): the steps on stone, the carpet round them on
	# the floor about it.
	for cell: Vector2i in grid:
		if grid[cell] != "stairwell":
			continue
		floor[cell] = STAIRWELL_FLOOR
		pieces[cell] = STAIRWELL
		for step: Vector2i in STAIRWELL_RING:
			if grid.get(cell + step, "") == "floor":
				floor[cell + step] = STAIRWELL_RING[step]
	# Walls touching the room are its walls; the rest is the dark beyond.
	var ring := {}
	for cell: Vector2i in grid:
		if grid[cell] != "wall" or standing.has(cell):
			continue
		var touches := false
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if inside.call(cell + Vector2i(dx, dy)):
					touches = true
		if touches:
			ring[cell] = true
		else:
			beyond.append(cell)
	var top := 1 << 20
	for cell: Vector2i in ring:
		top = mini(top, cell.y)
	for cell: Vector2i in ring:
		var mask := 0
		for bit: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
			var next: Vector2i = cell + bit[0]
			# A door continues the wall line on either side of it, but the
			# wall stops at the door (its ends face the gap).
			if ring.has(next) and not String(grid.get(next, "")).begins_with("door"):
				mask |= bit[1]
		var tile: int = WALLS[mask]
		# Windows along the back wall's straight runs, where nothing stands
		# in front of them.
		if cell.y == top and mask == 10 and cell.x % 4 == 1 and not leaning.has(cell):
			tile = WINDOW
		walls[cell] = tile
	return {"floor": floor, "walls": walls, "pieces": pieces, "void": beyond, "blocked": blocked, "over": over}
