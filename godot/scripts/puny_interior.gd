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
## ice cave, Captain Hale's hall in Greyhold's keep over its cellars; and
## Morvax's forge at the top of the mountain road (PIX-253 step 8).
const ROOMS := ["town_inn", "town_shop", "town_smith", "town_alchemist", "town_hall", "town_house", "observatory", "keep", "morvax_forge"]
## Rooms with a stone floor: the smithy, the keep of a fort, Morvax's forge.
const STONE_ROOMS := ["town_smith", "keep", "morvax_forge"]

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
## The candles and sconces in a room, by tile, and where each one's flame
## burns in its tile: at night each warms the floor round it (PIX-311).
const FLAMES := {
	145: Vector2(7.5, 10.5), 159: Vector2(7.5, 7.5), 585: Vector2(6.5, 6.5),
	588: Vector2(7.5, 2.5), 808: Vector2(7.5, 2.5),
}
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


## Without the paid pack (PIX-318: a fork, a build without the private art)
## a room is drawn from Shade's CC0 sheets in the repository instead of
## standing on grass, by the same rules: his Puny Dungeon's walls by its own
## grammar round the room (the dark beyond), floors of his Puny World's pier
## boards (his dungeon stone in the stone rooms), his dungeon's doorway, its
## stair down in a ring of rug, and the furniture that has a CC0 likeness. A
## piece is named "<sheet>:<tile>": "d" his Puny Dungeon, "w" his Puny World
## (tile ids), and the pieces drawn in code in his palette, "a" DungeonArt's,
## "h" HamletArt's and "r" RoomArt's (by name). What has no likeness (a bed,
## an anvil, a shelf of trophies) isn't drawn and still stands in the way.
const FREE_PLANKS := "w:752"
const FREE_DOOR := "d:434"
const FREE_DOOR_SHUT := "d:461"
const FREE_STAIRWELL := "d:462"
## The window: an arched recess in the back wall's face, the day in it
## (LampArt.recess_panes) until night.
const FREE_WINDOW := "a:window"
## Furniture by web tile; barrels roll one of the dungeon's two.
const FREE_FURNITURE := {
	"hearth": "h:forge_stack", "forge": "h:forge_stack", "cauldron": "d:517", "crate": "h:box",
	"counter": "w:844", "shelf": "w:846", "garden": "h:garden",
}
const FREE_BARRELS := ["d:515", "d:516"]
## The pieces a fire burns in (the hearth's warmth and embers, PIX-221), and
## where each light's flame burns in its cell: a torch's on the wall, a
## lantern's glass (the candles' rule, PIX-311).
const FREE_FIRES := ["h:forge_stack"]
const FREE_FLAMES := {"d:16": Vector2(8, 5), "h:lantern": Vector2(8, 9), "r:desk": Vector2(23.5, 2.5)}
## The furnished corners (interiors.json's vignettes) that have a likeness,
## as the vignettes are written: rows above `floorRow` hang on the back
## wall. Shade's dungeon torch for a wall lamp, a lantern for the candles,
## his barrels, chests, pots, stone knight and winch wheel, banners, crates,
## coal, a tub and creels drawn in code; Liane's stars as they are (a
## RoomArt piece takes as many cells as it is big, named at its top left).
const FREE_VIGNETTES := {
	"wall_lamp": {"floorRow": 1, "objects": [[0, 0, "d:16"]]},
	"candles": {"floorRow": 0, "objects": [[0, 0, "h:lantern"]]},
	"side_lamp": {"floorRow": 0, "objects": [[0, 0, "h:lantern"]]},
	"candelabra": {"floorRow": 0, "objects": [[0, 0, "h:lantern"]]},
	"banner": {"floorRow": 1, "objects": [[0, 0, "a:banner_red"]]},
	"barrels": {"floorRow": 0, "objects": [[0, 0, "d:515"], [1, 0, "d:516"], [1, 1, "d:515"]]},
	"barrels_tall": {"floorRow": 0, "objects": [[0, 0, "d:516"], [0, 1, "d:515"], [0, 2, "d:516"]]},
	"chest": {"floorRow": 0, "objects": [[0, 0, "d:489"]]},
	"treasure": {"floorRow": 0, "objects": [[0, 0, "d:489"], [1, 0, "d:458"], [2, 0, "d:489"]]},
	"crates": {"floorRow": 0, "objects": [[0, 0, "h:box"], [1, 0, "h:box"]]},
	"crate_stack": {"floorRow": 0, "objects": [[0, 0, "h:box"], [0, 1, "h:box"]]},
	"veg_crates": {"floorRow": 0, "objects": [[0, 0, "h:box"], [1, 0, "h:box"]]},
	"pots": {"floorRow": 0, "objects": [[0, 0, "d:517"], [1, 0, "d:517"]]},
	"coal_bins": {"floorRow": 0, "objects": [[0, 0, "h:coal"], [1, 0, "h:coal"]]},
	"bucket": {"floorRow": 0, "objects": [[0, 0, "h:tub"]]},
	"baskets": {"floorRow": 0, "objects": [[0, 0, "h:creels"], [1, 0, "h:creels"]]},
	"grindstone": {"floorRow": 0, "objects": [[0, 0, "d:466"]]},
	"knight_armor": {"floorRow": 0, "objects": [[0, 0, "d:491"]]},
	"armor_stand": {"floorRow": 0, "objects": [[0, 0, "d:491"]]},
	"telescope": {"floorRow": 0, "objects": [[0, 0, "r:telescope"]]},
	"star_chart": {"floorRow": 1, "objects": [[0, 0, "r:star_chart"]]},
	"star_globe": {"floorRow": 0, "objects": [[0, 0, "r:star_globe"]]},
	# The ledgers on their tables (PIX-338): Hale's order book under the
	# candle (his chair and stools have no likeness), the village's in the hall.
	"captain_table": {"floorRow": 0, "objects": [[0, 1, "r:desk+open_book+map_dagger"]]},
	"ledger_desk": {"floorRow": 0, "objects": [[0, 0, "r:desk+open_book+plans"]]},
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
## another piece. A vignette's `art` ([x, y, name]) is a piece drawn in code
## (RoomArt, PIX-315), taking as many cells as it is big, named at its top
## left; on the floor it blocks. {"rug", "objects", "tops", "lifted":
## {cell: tile}, "art": {cell: name}, "blocked": [cells], "skipped": [names]}.
static func furnish(room_key: String, grid: Dictionary, reserved: Dictionary) -> Dictionary:
	var out := {"rug": {}, "objects": {}, "tops": {}, "lifted": {}, "art": {}, "blocked": [], "skipped": []}
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
	# The floor the pieces drawn in code stand on.
	var art_floor := {}
	for placement: Array in layout.get("pieces", []):
		var piece: Dictionary = interiors()["vignettes"][placement[0]]
		var origin := Vector2i(int(placement[1]), int(placement[2]) - int(piece["floorRow"]))
		var cells := {}
		var fits := true
		# Every cell a part takes: [cell, its row in the vignette].
		var parts: Array = []
		for kind: String in ["rug", "objects", "tops", "lifted"]:
			for part: Array in piece[kind]:
				parts.append([origin + Vector2i(int(part[0]), int(part[1])), int(part[1])])
		var drawn: Array[Vector2i] = []
		for part: Array in piece.get("art", []):
			var big := RoomArt.cells(String(part[2]))
			for dy in big.y:
				for dx in big.x:
					var cell := origin + Vector2i(int(part[0]) + dx, int(part[1]) + dy)
					parts.append([cell, int(part[1]) + dy])
					drawn.append(cell)
		for part: Array in parts:
			var cell: Vector2i = part[0]
			var on_wall: bool = int(part[1]) < int(piece["floorRow"])
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
		for part: Array in piece.get("art", []):
			out["art"][origin + Vector2i(int(part[0]), int(part[1]))] = String(part[2])
		for cell: Vector2i in drawn:
			if not cells[cell]:
				art_floor[cell] = true
		for cell: Vector2i in cells:
			taken[cell] = true
	for cell: Vector2i in taken:
		if out["objects"].has(cell) or out["tops"].has(cell) or art_floor.has(cell):
			out["blocked"].append(cell)
	return out


## The cells the layout of `room_key` gives the vignette `name` (PIX-338:
## the village's ledger on its table in the hall, E reads it there), with or
## without the pack; empty when the room has none.
static func placed(room_key: String, name: String) -> Rect2i:
	for placement: Array in interiors()["rooms"].get(room_key, {}).get("pieces", []):
		if placement[0] == name:
			var piece: Dictionary = interiors()["vignettes"][name]
			return Rect2i(int(placement[1]), int(placement[2]) - int(piece["floorRow"]), int(piece["size"][0]), int(piece["size"][1]))
	return Rect2i()


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
	# A wall the story has written on keeps it whole, no window through it
	# (PIX-253 step 8: Morvax's tally marks, Letters.drawn_on).
	for piece: Dictionary in Letters.drawn_on(map_id):
		var rect: Rect2i = piece["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				leaning[Vector2i(x, y)] = true
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


# ---- without the paid pack (PIX-318) -----------------------------------------

## A room from Shade's CC0 sheets, as `plan` lays it with the pack: {"free":
## true, "floor", "walls", "rug", "pieces": {cell: piece} (FREE_ names),
## "windows": [cells] (their recess is drawn over the wall), "fires":
## [cells], "void": [cells], "blocked": [] (every piece keeps to its own
## cell), "over": {}}. The walls are the same cells as `plan`'s (those
## touching the room, the windows along the back wall's straight runs where
## nothing hangs), drawn by his dungeon's wall grammar (PunyDungeon): a wall
## with the room south of it shows its face, any other its top, its ends
## facing a door's gap.
static func plan_free(map_id: String, grid: Dictionary) -> Dictionary:
	var floor := {}
	var walls := {}
	var pieces := {}
	var rug := {}
	var beyond: Array[Vector2i] = []
	var windows: Array[Vector2i] = []
	var fires: Array[Vector2i] = []
	var stone: bool = map_id in STONE_ROOMS
	var inside := func(cell: Vector2i) -> bool:
		return grid.has(cell) and grid[cell] != "wall" and not String(grid[cell]).begins_with("door")
	for cell: Vector2i in grid:
		var tile: String = grid[cell]
		if inside.call(cell) or tile.begins_with("door"):
			floor[cell] = "d:%d" % PunyDungeon.floor_tile(cell) if stone else FREE_PLANKS
		match tile:
			"door":
				pieces[cell] = FREE_DOOR
			"door_shut":
				pieces[cell] = FREE_DOOR_SHUT
			"barrel":
				pieces[cell] = FREE_BARRELS[absi(hash(cell)) % FREE_BARRELS.size()]
			"stairwell":
				# The way down (PIX-256): the stair on stone, a rug round it.
				floor[cell] = "d:%d" % PunyDungeon.FLOOR
				pieces[cell] = FREE_STAIRWELL
				for step: Vector2i in STAIRWELL_RING:
					if grid.get(cell + step, "") == "floor":
						rug[cell + step] = "a:rug_%d" % ((step.y + 1) * 3 + step.x + 1)
			_:
				if FREE_FURNITURE.has(tile):
					pieces[cell] = FREE_FURNITURE[tile]
					if FREE_FURNITURE[tile] in FREE_FIRES:
						fires.append(cell)
	# A wall the story has written on keeps it whole (Letters.drawn_on).
	var leaning := {}
	for piece: Dictionary in Letters.drawn_on(map_id):
		var rect: Rect2i = piece["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				leaning[Vector2i(x, y)] = true
	var ring := {}
	for cell: Vector2i in grid:
		if grid[cell] != "wall":
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
		var east: bool = ring.has(cell + Vector2i.RIGHT)
		var west: bool = ring.has(cell + Vector2i.LEFT)
		var north: bool = ring.has(cell + Vector2i.UP)
		var column := (1 if east and not west else 0) + (2 if east and west else 0) + (3 if west and not east else 0)
		var tile: int
		if grid.get(cell + Vector2i.DOWN, "wall") != "wall":
			tile = PunyDungeon.COLUMN_FOOT if north and column == 0 else PunyDungeon.FACE[column]
		else:
			tile = PunyDungeon.TOP_RUN[column] if north else PunyDungeon.TOP_END[column]
		walls[cell] = "d:%d" % tile
		# The back wall's straight runs, as `plan` sets its windows.
		if cell.y == top and east and west and not north and not ring.has(cell + Vector2i.DOWN) \
				and cell.x % 4 == 1 and not leaning.has(cell):
			windows.append(cell)
	return {
		"free": true, "floor": floor, "walls": walls, "rug": rug, "pieces": pieces, "windows": windows,
		"fires": fires, "void": beyond, "blocked": [] as Array[Vector2i], "over": {},
	}


## A room dressed from the CC0 sheets (PIX-318), as `furnish` dresses it:
## its rugs in DungeonArt's rug, and each vignette of its layout that has a
## likeness (FREE_VIGNETTES), whole or not at all, by the same rules. {"rug",
## "objects": {cell: piece}, "flames": [where each burns, in pixels],
## "blocked": [cells], "skipped": [names]}.
static func furnish_free(room_key: String, grid: Dictionary, reserved: Dictionary) -> Dictionary:
	var out := {"rug": {}, "objects": {}, "flames": [], "blocked": [], "skipped": []}
	var layout: Dictionary = interiors()["rooms"].get(room_key, {})
	for rug: Array in layout.get("rugs", []):
		var w := int(rug[3])
		var h := int(rug[4])
		for dy in h:
			for dx in w:
				var cell := Vector2i(int(rug[1]) + dx, int(rug[2]) + dy)
				if grid.get(cell, "") != "floor":
					continue
				var col := 0 if dx == 0 else (2 if dx == w - 1 else 1)
				var row := 0 if dy == 0 else (2 if dy == h - 1 else 1)
				out["rug"][cell] = "a:rug_%d" % (row * 3 + col)
	var taken := {}
	for placement: Array in layout.get("pieces", []):
		if not FREE_VIGNETTES.has(placement[0]):
			out["skipped"].append(placement[0])
			continue
		var piece: Dictionary = FREE_VIGNETTES[placement[0]]
		var origin := Vector2i(int(placement[1]), int(placement[2]) - int(piece["floorRow"]))
		# Every cell each part takes, and whether it hangs on the wall.
		var cells := {}
		var fits := true
		for part: Array in piece["objects"]:
			var name := String(part[2])
			var big := RoomArt.cells(name.trim_prefix("r:")) if name.begins_with("r:") else Vector2i.ONE
			for dy in big.y:
				for dx in big.x:
					var row := int(part[1]) + dy
					var cell := origin + Vector2i(int(part[0]) + dx, row)
					var on_wall: bool = row < int(piece["floorRow"])
					var tile: String = grid.get(cell, "")
					if on_wall:
						fits = fits and tile == "wall" and grid.get(cell + Vector2i.DOWN, "") != "wall"
					else:
						fits = fits and tile == "floor" and not reserved.has(cell) and not taken.has(cell)
					cells[cell] = on_wall
		if not fits:
			out["skipped"].append(placement[0])
			continue
		for part: Array in piece["objects"]:
			var cell := origin + Vector2i(int(part[0]), int(part[1]))
			out["objects"][cell] = String(part[2])
			# A piece laid over a table burns where the table's candle does.
			var lit := String(part[2]).get_slice("+", 0)
			if FREE_FLAMES.has(lit):
				out["flames"].append(Vector2(cell * 16) + FREE_FLAMES[lit])
		for cell: Vector2i in cells:
			taken[cell] = true
			if not cells[cell]:
				out["blocked"].append(cell)
	return out


## Where a CC0 room's piece is drawn from: [its sheet's letter, its tile id
## (Shade's sheets) or name (the pieces drawn in code)].
static func free_piece(piece: String) -> Array:
	var sheet := piece.get_slice(":", 0)
	var tile := piece.get_slice(":", 1)
	return [sheet, int(tile) if sheet in ["d", "w"] else tile]
