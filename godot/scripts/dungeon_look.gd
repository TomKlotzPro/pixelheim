class_name DungeonLook
## areas: dungeon +seacave* +shafts* +cellars* +icecave* +vault*
## Each dungeon dressed as its place (PIX-310, the audit's "five dungeons,
## one brick look": the sea cave, the shafts, the cellars, the ice cave and
## the Kings' Vault were the same cut-brick halls in a different tint, on
## one floor tile). Now each reads as what it is:
## - the sea cave (`sea`): wet rock round shallow pools of the sea seeped
##   in, weed and barnacles at the walls' feet, drips;
## - the Blackiron shafts (`mine`): a rail line laid from the stair down
##   through every hall to the way on, ore carts parked and ore heaped,
##   timbered galleries (a cap beam along the walls on its props), ore
##   glinting in the rock, soot underfoot;
## - the Greyhold cellars (`crypt`): the garrison's niches in the walls, a
##   skull or an urn on each sill, cobwebs in the corners, bones and drains
##   on the flags, damp and dust;
## - the ice cave (`ice`): frost creeping out over the stone from every wall
##   as it does from the frozen lake, rime on the walls' tops and icicles
##   off their faces;
## - the Kings' Vault (`vault`): the old kings' red rugs down every hall
##   and room, their banners on the walls, the walls trimmed in gold.
## Every floor's stone has its own wear and cracks (shaders/dungeon.gdshader,
## which draws the look's light, water, frost and glints from `mask`).
## Nothing here changes the map: the plan only reads it. What it lays flat
## lies on open floor, walked over, never on a stair, a door, a chest or a
## set piece; what hangs on a wall hangs on a face of it beside open floor,
## never on a torch; what it swaps is drawn on a cell that already blocks (a
## barrel drawn as an ore cart). With the Medieval Age pack each look's
## floor is laid in its own ground (wet rubble, the mine's spoil, cracked
## flags, cold flags, dressed slabs), its carts and ore and the kings' rugs
## from the pack; without it Shade's CC0 dungeon floor and our own pieces
## (DungeonArt), the same plan otherwise. Pure.

## A dungeon's look by its id (Depths).
const LOOKS := {"seacave": "sea", "shafts": "mine", "cellars": "crypt", "icecave": "ice", "vault": "vault"}
## Each look as the shader numbers it (0: plain stone).
const SHADER := {"": 0, "sea": 1, "mine": 2, "crypt": 3, "ice": 4, "vault": 5}
## Each look's floor in the Medieval Age pack: [its first tile, columns,
## rows] of a block laid as the pack lays it, a cell's tile by where it
## stands in the block, so the ground runs on without a seam: the sea
## cave's dark wet rubble, the mine's brown spoil, the crypt's cracked grey
## flags, the ice cave's cold blue ones, the Vault's dressed slabs.
const FLOORS := {
	"sea": [18526, 4, 2], "mine": [22030, 4, 4], "crypt": [8830, 4, 8], "ice": [15886, 4, 8], "vault": [9267, 3, 3],
}
## The Medieval Age's ore carts on their rails (full, empty) and its rocks
## veined with ore; without the pack a pot in the mine is one of Shade's
## boulders and a barrel stays a barrel.
const CARTS := [1079, 853]
const ORE := [1743, 1744, 1745]
## The rug family the Vault's are cut from (interiors.json's rugFamilies,
## PunyInterior's rooms'), its nine parts row by row.
const RUG_FAMILY := "red"
## A drain in a crypt's flags (Shade's CC0 dungeon sheet).
const DRAIN := 42
## How far apart along a wall the mine's props stand, the crypt's niches
## and the Vault's banners, in cells.
const PROP_EVERY := 4
const NICHE_EVERY := 3
const BANNER_EVERY := 4
## How many of a sea cave's open cells lie under water (a share of its
## value noise, over this), the noise's scale in cells, and how many
## faces have weed at their foot.
const WATER_ABOVE := 0.63
const WATER_SCALE := 3.6
const WEED_SHARE := 0.45
## How many of a crypt's wall-side cells have bones on them, its cells a
## drain, and its corners a web.
const BONES_SHARE := 0.07
const DRAIN_SHARE := 0.018
const WEB_SHARE := 0.75
## What the mask says of a cell beside a wall (a wall itself is 1), and the
## least depth a pool's cell lies at, so every pool shows water inside its
## foam.
const NEAR := 0.45
const SHALLOWEST := 0.72
## A rail line turns only where it must: a turn costs this many steps, and
## a cell by a wall this many tenths of one more.
const TURN_COST := 5.0
const HUG := 3
## Cells a rug leaves bare round a room's edge.
const RUG_MARGIN := 1

const NOWHERE := Vector2i(-1, -1)
const WAYS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## The cells that are ways on: the stairs up and down, the shortcut's door.
const WAYS_OUT := ["cave", "stairwell", "sealed"]


## The look of the dungeon `map_id` is a floor of ("" for any other map).
static func of(map_id: String) -> String:
	var entry := Depths.floor_of(map_id)
	return String(LOOKS.get(String(entry.get("dungeon", "")), "")) if not entry.is_empty() else ""


## How `map` is dressed: {look, floors: {cell: Medieval Age tile}, flats:
## {cell: piece} (on the floor, walked over), faces: {cell: piece} (on a
## wall's face), swaps: {cell: piece} (a blocker drawn as something else),
## water: {cell: depth 0..1}, counts: {kind: n}}. A piece is {sheet: "art"
## (DungeonArt), "props" (the Medieval Age) or "dungeon" (Shade's CC0
## sheet), tile: its name or number, kind}. `paid`: the Medieval Age pack
## is here.
static func plan(map: MapData, paid: bool) -> Dictionary:
	var look := of(map.id)
	var out := {"look": look, "floors": {}, "flats": {}, "faces": {}, "swaps": {}, "water": {}, "counts": {}}
	if look == "":
		return out
	if paid:
		var block: Array = FLOORS[look]
		for cell: Vector2i in map.grid:
			if not PunyDungeon._solid(map.grid, cell):
				var x := posmod(cell.x, int(block[1]))
				var y := posmod(cell.y, int(block[2]))
				out["floors"][cell] = int(block[0]) + x + y * PunyTown.COLUMNS
	var clear := _kept_clear(map)
	match look:
		"sea":
			_sea(map, clear, out)
		"mine":
			_mine(map, clear, paid, out)
		"crypt":
			_crypt(map, clear, out)
		"vault":
			_vault(map, paid, out)
	return out


static func _piece(sheet: String, tile: Variant, kind: String) -> Dictionary:
	return {"sheet": sheet, "tile": tile, "kind": kind}


static func _count(out: Dictionary, kind: String) -> void:
	out["counts"][kind] = int(out["counts"].get(kind, 0)) + 1


## Cells nothing is laid on: the ways in and out (portals, stairs, the
## shortcut's door), where a hero arrives, the chests, the set piece and
## anything drawn over a cell (`pieces`).
static func _kept_clear(map: MapData) -> Dictionary:
	var out := {map.spawn: true}
	for cell: Vector2i in map.portals:
		out[cell] = true
	for cell: Vector2i in map.pieces:
		out[cell] = true
	for cell: Vector2i in map.notes:
		out[cell] = true
	for chest: Dictionary in Interactables.chests_on(map.id):
		out[Vector2i(int(chest["x"]), int(chest["y"]))] = true
	for cell: Vector2i in map.grid:
		if String(map.grid[cell]) in WAYS_OUT:
			out[cell] = true
	return out


## Open floor a flat thing may lie on.
static func is_open(map: MapData, clear: Dictionary, cell: Vector2i) -> bool:
	return String(map.grid.get(cell, "")) == "floor" and not clear.has(cell)


## Whether `cell` is a wall's face a thing may hang on: a wall (never a
## torch) with open ground before it, seen.
static func is_face(map: MapData, cell: Vector2i) -> bool:
	return String(map.grid.get(cell, "")) == "wall" and PunyDungeon.on_face(map.grid, cell) \
		and PunyDungeon.is_visible_wall(map.grid, cell)


## Every face of the map's walls in runs, west to east along each row: a
## run is broken by a torch, a corner or open ground. [[cells]].
static func face_runs(map: MapData) -> Array:
	var runs: Array = []
	for y in map.size.y:
		var run: Array[Vector2i] = []
		for x in map.size.x + 1:
			var cell := Vector2i(x, y)
			if x < map.size.x and is_face(map, cell):
				run.append(cell)
			elif not run.is_empty():
				runs.append(run)
				run = []
	return runs


## A value 0..1 that wanders smoothly over the cells, the same every visit:
## where the sea seeps in.
static func noise(at: Vector2, salt: int) -> float:
	var i := Vector2i(floori(at.x), floori(at.y))
	var f := at - Vector2(i)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _hash01(i, salt)
	var b := _hash01(i + Vector2i(1, 0), salt)
	var c := _hash01(i + Vector2i(0, 1), salt)
	var d := _hash01(i + Vector2i(1, 1), salt)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## A cell's own die, 0..1, the same every visit.
static func _hash01(cell: Vector2i, salt: int) -> float:
	return float(absi(hash(Vector3i(cell.x, cell.y, salt))) % 10007) / 10007.0


## The sea cave: pools where the sea seeps in (the noise), kept off the ways
## in and out and the cells beside them, and weed at the walls' feet.
static func _sea(map: MapData, clear: Dictionary, out: Dictionary) -> void:
	for cell: Vector2i in map.grid:
		if not is_open(map, clear, cell) or _by_kept(clear, cell):
			continue
		var wet := noise(Vector2(cell) / WATER_SCALE, 31)
		if wet > WATER_ABOVE:
			var depth := clampf((wet - WATER_ABOVE) / (1.0 - WATER_ABOVE) * 2.0, 0.0, 1.0)
			out["water"][cell] = lerpf(SHALLOWEST, 1.0, depth)
			_count(out, "water")
	for run: Array in face_runs(map):
		for cell: Vector2i in run:
			if _hash01(cell, 7) < WEED_SHARE:
				out["faces"][cell] = _piece("art", "weed_a" if _hash01(cell, 8) < 0.5 else "weed_b", "weed")
				_count(out, "weed")


## Whether a kept-clear cell (a way, a chest) stands beside `cell`.
static func _by_kept(clear: Dictionary, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if clear.has(cell + Vector2i(dx, dy)):
				return true
	return false


## The shafts: the rail line, the timbering, and the carts and ore.
static func _mine(map: MapData, clear: Dictionary, paid: bool, out: Dictionary) -> void:
	var line := rail_line(map, clear)
	for i in line.size():
		var ways := 0
		for other: int in [i - 1, i + 1]:
			if other >= 0 and other < line.size():
				ways |= _way_bit(line[other] - line[i])
		out["flats"][line[i]] = _piece("art", DungeonArt.rail(ways), "rail")
		_count(out, "rail")
	for run: Array in face_runs(map):
		if run.size() < 3:
			continue
		for i in run.size():
			var post := posmod(i - 1, PROP_EVERY) == 0 and i < run.size() - 1
			out["faces"][run[i]] = _piece("art", "timber_post" if post else "timber_beam", "timber")
			if post:
				_count(out, "props")
	for cell: Vector2i in map.grid:
		match String(map.grid[cell]):
			"barrel":
				# Every other barrel an ore cart, with the pack.
				if paid and _hash01(cell, 11) < 0.6:
					out["swaps"][cell] = _piece("props", CARTS[0] if _hash01(cell, 12) < 0.7 else CARTS[1], "cart")
					_count(out, "carts")
			"crate":
				if paid:
					out["swaps"][cell] = _piece("props", ORE[absi(hash(cell)) % ORE.size()], "ore")
				else:
					out["swaps"][cell] = _piece("dungeon", PunyDungeon.BOULDERS[absi(hash(cell)) % PunyDungeon.BOULDERS.size()], "ore")
				_count(out, "ore")


static func _way_bit(step: Vector2i) -> int:
	match step:
		Vector2i.UP:
			return DungeonArt.N
		Vector2i.RIGHT:
			return DungeonArt.E
		Vector2i.DOWN:
			return DungeonArt.S
		Vector2i.LEFT:
			return DungeonArt.W
	return 0


## The mine's rail line: from where a hero comes in to the way on (the
## landing by the stair down, or the shortcut's door on the bottom floor),
## over open floor, turning only where it must. [] when there's no way.
static func rail_line(map: MapData, clear: Dictionary) -> Array[Vector2i]:
	var goal := _way_on(map)
	var start := map.spawn
	var line: Array[Vector2i] = []
	if goal == NOWHERE or goal == start:
		return line
	# Cheapest way by (cell, heading), in tenths of a step: a step 10, a
	# turn TURN_COST steps more, a cell by a wall HUG more. Costs are whole,
	# so the frontier is a bucket a cost, taken in order.
	var cost := {}
	var came := {}
	var buckets := {0: [] as Array}
	for heading in WAYS.size():
		var key := Vector3i(start.x, start.y, heading)
		cost[key] = 0
		buckets[0].append(key)
	var reached := Vector3i(-1, -1, -1)
	var now := 0
	var last := 0
	while now <= last and reached.x < 0:
		for key: Vector3i in buckets.get(now, []):
			if int(cost[key]) != now:
				continue
			var cell := Vector2i(key.x, key.y)
			if cell == goal:
				reached = key
				break
			for heading in WAYS.size():
				var next: Vector2i = cell + WAYS[heading]
				if next != goal and not is_open(map, clear, next):
					continue
				var total := now + 10 + (int(TURN_COST * 10) if heading != key.z else 0) + _hugging(map, next)
				var next_key := Vector3i(next.x, next.y, heading)
				if total < int(cost.get(next_key, 1 << 30)):
					cost[next_key] = total
					came[next_key] = key
					buckets.get_or_add(total, []).append(next_key)
					last = maxi(last, total)
		buckets.erase(now)
		now += 1
	if reached.x < 0:
		return line
	var at := reached
	while true:
		line.push_front(Vector2i(at.x, at.y))
		if not came.has(at):
			break
		at = came[at]
	return line


## A little dearer by a wall (in tenths of a step), so the line keeps off a
## room's walls where it can.
static func _hugging(map: MapData, cell: Vector2i) -> int:
	for step: Vector2i in WAYS:
		if PunyDungeon._solid(map.grid, cell + step):
			return HUG
	return 0


## Where a dungeon floor's way on is: the cell a hero coming up the stair
## from below lands on, or before the shortcut's door on the bottom floor.
static func _way_on(map: MapData) -> Vector2i:
	var ways := Depths.stairs(map.id)
	if ways.has("down"):
		return ways["down"]["arrive"]
	var door := Depths.shortcut_on(map.id)
	if not door.is_empty():
		return Vector2i(door["cell"]) + Vector2i.DOWN
	return NOWHERE


## The cellars: a niche every few cells along a wall, a web in the room's
## corners, bones by the walls and a drain here and there in the flags.
static func _crypt(map: MapData, clear: Dictionary, out: Dictionary) -> void:
	for run: Array in face_runs(map):
		var first: Vector2i = run[0]
		var last: Vector2i = run[-1]
		# A corner: the wall turns down beside the run's end (not a torch).
		if _corner(map, first + Vector2i.LEFT) and _hash01(first, 21) < WEB_SHARE:
			out["faces"][first] = _piece("art", "web_l", "web")
			_count(out, "webs")
		if run.size() > 1 and _corner(map, last + Vector2i.RIGHT) and _hash01(last, 22) < WEB_SHARE:
			out["faces"][last] = _piece("art", "web_r", "web")
			_count(out, "webs")
		if run.size() < 4:
			continue
		for i in range(1, run.size() - 1):
			if posmod(i - 1, NICHE_EVERY) == 0 and not out["faces"].has(run[i]):
				out["faces"][run[i]] = _piece("art", "niche_skull" if _hash01(run[i], 23) < 0.6 else "niche_urn", "niche")
				_count(out, "niches")
	for cell: Vector2i in map.grid:
		if not is_open(map, clear, cell):
			continue
		var by_wall := false
		for step: Vector2i in WAYS:
			by_wall = by_wall or PunyDungeon._solid(map.grid, cell + step)
		if by_wall and _hash01(cell, 24) < BONES_SHARE:
			out["flats"][cell] = _piece("art", "bones_a" if _hash01(cell, 25) < 0.5 else "bones_b", "bones")
			_count(out, "bones")
		elif not by_wall and _hash01(cell, 26) < DRAIN_SHARE:
			out["flats"][cell] = _piece("dungeon", DRAIN, "drain")
			_count(out, "drains")


## Whether `cell` is a room's corner: a wall (never a torch) that runs on
## down beside the room.
static func _corner(map: MapData, cell: Vector2i) -> bool:
	return String(map.grid.get(cell, "")) == "wall" and PunyDungeon._solid(map.grid, cell + Vector2i.DOWN)


## The Kings' Vault: a rug over each room (its nine parts by where each cell
## stands in it, under where a hero comes in, a chest and the hoard too,
## never a way), banners along its walls.
static func _vault(map: MapData, paid: bool, out: Dictionary) -> void:
	var family: Array = PunyInterior.interiors()["rugFamilies"][RUG_FAMILY] if paid else []
	for room: Rect2i in rooms(map):
		var rug := room.grow(-RUG_MARGIN)
		if rug.size.x < 3 or rug.size.y < 2:
			continue
		var laid := false
		for y in range(rug.position.y, rug.end.y):
			for x in range(rug.position.x, rug.end.x):
				var cell := Vector2i(x, y)
				if PunyDungeon._solid(map.grid, cell) or map.portals.has(cell) or String(map.grid[cell]) in WAYS_OUT:
					continue
				var column := 0 if x == rug.position.x else (2 if x == rug.end.x - 1 else 1)
				var row := 0 if y == rug.position.y else (2 if y == rug.end.y - 1 else 1)
				var part := row * 3 + column
				out["flats"][cell] = _piece("props", int(family[part]), "rug") if paid else _piece("art", "rug_%d" % part, "rug")
				laid = true
		if laid:
			_count(out, "rugs")
	for run: Array in face_runs(map):
		if run.size() < 3:
			continue
		for i in range(1, run.size() - 1):
			if posmod(i - 1, BANNER_EVERY) == 0:
				var blue := _hash01(run[i], 41) < 0.4
				out["faces"][run[i]] = _piece("art", "banner_blue" if blue else "banner_red", "banner")
				_count(out, "banners")


## A planned floor's rooms (DungeonFloor's), [] for a handcrafted one.
static func rooms(map: MapData) -> Array:
	return Depths.plan(map.id)["rooms"] if Depths.is_planned(map.id) else []


## The cell mask the shader reads (shaders/dungeon.gdshader), a texel a
## cell: red what the cell is (0 the rock nobody sees, a third a wall's top,
## two thirds its face, full open ground), green how deep the sea lies
## there, blue how near a wall (full in one, NEAR beside one, corners too):
## read smoothly, it falls away from every wall over a cell or so.
static func mask(map: MapData, water: Dictionary) -> Image:
	var image := Image.create(maxi(map.size.x, 1), maxi(map.size.y, 1), false, Image.FORMAT_RGBA8)
	for cell: Vector2i in map.grid:
		var kind := 1.0
		var near := 1.0
		if PunyDungeon._solid(map.grid, cell):
			if not PunyDungeon.is_visible_wall(map.grid, cell):
				kind = 0.0
			elif PunyDungeon._solid(map.grid, cell + Vector2i.DOWN):
				kind = 1.0 / 3.0
			else:
				kind = 2.0 / 3.0
		else:
			near = NEAR if _by_wall(map, cell) else 0.0
		image.set_pixelv(cell, Color(kind, float(water.get(cell, 0.0)), near, 1.0))
	return image


## Whether a wall stands beside `cell`, corners too.
static func _by_wall(map: MapData, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and PunyDungeon._solid(map.grid, cell + Vector2i(dx, dy)):
				return true
	return false
