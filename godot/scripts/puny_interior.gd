class_name PunyInterior
## The rooms behind the town's doors in Shade's Puny World Medieval Age
## (PIX-133), the way his sample cottages and smithy are furnished: plank
## floors (stone in the smithy) with a rug, his cream walls one tile thick
## around the room (the web's thicker walls beyond them are dark), windows
## along the back wall, his door, and his furniture on the web's furniture
## cells. Pure: tile ids only; PunyTown draws them (same atlas).

## Interiors this restyles (the web's room maps; house tiers share an id).
const ROOMS := ["town_inn", "town_shop", "town_smith", "town_alchemist", "town_hall", "town_house"]

const PLANKS := [5342, 5565, 3550]
const STONE := [1792, 2233, 2453]
const RUGS := {"town_inn": 10248, "town_house": 6728, "town_hall": 11128}

## Cream walls by which neighbours are walls too (N=1, E=2, S=4, W=8), read
## off the sample villages' wall layers.
const WALLS := {
	0: 278, 1: 498, 2: 719, 3: 499, 4: 58, 5: 278, 6: 59, 7: 279,
	8: 721, 9: 501, 10: 720, 11: 720, 12: 61, 13: 281, 14: 60, 15: 720,
}
const WINDOW := 3659
const DOOR := 3875

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
## Runs of these draw as one piece with ends: [left end, middle, right end].
const RUNS := {
	"counter": [5180, 5181, 5182],
	"shelf": [2995, 2996, 2998],
	"garden": [1241, 1242, 1243],
	"trophy_shelf": [1904, 1905, 1904],
}


static func is_room(map_id: String) -> bool:
	return map_id in ROOMS


## {"floor": {cell: tile}, "pieces": {cell: tile} (walls, door, furniture),
## "void": [cells] (wall beyond the room), "blocked": [cells] (floor the
## furniture now covers)}.
static func plan(map_id: String, grid: Dictionary) -> Dictionary:
	var floor := {}
	var pieces := {}
	var beyond: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var stone := map_id == "town_smith"
	# Doors stand in the wall line, so they are not room.
	var inside := func(cell: Vector2i) -> bool:
		return grid.has(cell) and grid[cell] != "wall" and not String(grid[cell]).begins_with("door")
	# The room: everything that isn't wall gets floor (furniture stands on it).
	var room := []
	for cell: Vector2i in grid:
		if inside.call(cell) or String(grid[cell]).begins_with("door"):
			room.append(cell)
			var choices: Array = STONE if stone else PLANKS
			floor[cell] = choices[absi(cell.x * 7 + cell.y * 13) % choices.size()]
	_rug(map_id, grid, room, floor)
	# Walls touching the room are its walls; the rest is the dark beyond.
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
		var mask := 0
		for bit: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
			var next: Vector2i = cell + bit[0]
			# A door continues the wall line on either side of it, but the
			# wall stops at the door (its ends face the gap).
			if ring.has(next) and not String(grid.get(next, "")).begins_with("door"):
				mask |= bit[1]
		var tile: int = WALLS[mask]
		# Windows along the back wall's straight runs.
		if cell.y == top and mask == 10 and cell.x % 4 == 1:
			tile = WINDOW
		pieces[cell] = tile
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
				# Furniture spreading onto open floor blocks it, but a bed's
				# foot stays walkable: the inn wakes its guests there.
				if at != cell and tile != "bed" and grid.get(at, "") == "floor":
					blocked.append(at)
	return {"floor": floor, "pieces": pieces, "void": beyond, "blocked": blocked}


## A rug down the middle of the open floor in the inn, the house and the hall.
static func _rug(map_id: String, grid: Dictionary, room: Array, floor: Dictionary) -> void:
	if not RUGS.has(map_id) or room.is_empty():
		return
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-1, -1)
	for cell: Vector2i in room:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	var centre := (lo + hi) / 2
	for y in range(centre.y - 1, centre.y + 2):
		for x in range(centre.x - 3, centre.x + 3):
			var cell := Vector2i(x, y)
			if grid.get(cell, "") == "floor":
				floor[cell] = RUGS[map_id]
