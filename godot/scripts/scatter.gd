class_name Scatter
## areas: travel field
## Puny World objects scattered on terrain (PIX-130), and which of them stand
## in the way (PIX-137). Pure: world.gd draws what these pick.

## Picked by cell hash: tile id -> [density %, [Puny World tile ids]].
## Forests grow pines and round trees (in clumps: their density is Woods'),
## the ridges' rims carry pines and boulders (RIM), fields the odd stone or
## stump, and crops stand in rows of wheat.
const SCATTER := {
	"forest": [0, [197, 224, 251, 206, 233, 260, 705, 729, 732, 783, 810]],
	"mountain": [0, [197, 224, 251, 783, 810, 702]],
	"grass": [3, [702, 703, 730, 784]],
	"ash": [6, [702, 703, 784, 811, 838]],
	"marsh": [10, [703, 732, 838]],
	"crops": [100, [756, 757]],
}
## Field decor that stands in the way (a bush, stumps, a marsh tree), and
## what lies flat to step over (a log, a twig). Forests and crops stay walk-
## through, as the web's are.
const SOLID := [702, 730, 732, 784, 811]
const FLAT := [703, 838]
const FIELDS := ["grass", "ash", "marsh"]
## What the wind moves (PIX-223): the trees, and the wheat in the fields.
const SWAYS := [197, 224, 251, 206, 233, 260, 705, 729, 732, 783, 810, 756, 757]
## A solid one's foot, in pixels from its cell's top-left: it covers the
## middle-bottom of the cell, as PunyProps' feet do.
const FOOT := Rect2(3, 6, 10, 10)
## The small things in open ground (PIX-305): tufts, clover, flowers and a
## few pebbles in the grass, pebbles and twigs in the snow, reeds and sedge
## in the mire. Tile -> [density %, [GroundDetail kinds]], picked by a hash
## of their own where no field decor grows (choice), so what stands where
## doesn't move; flat on the ground, never in the way. The fields grew the
## odd stone in 3% of their cells, and most of every outdoor screen was one
## grass tuft repeated.
const DETAIL := {
	"grass": [10, ["tuft", "tuft", "tuft_small", "tuft_small", "clover", "clover", "flowers_white", "flowers_yellow", "flowers_red", "flowers_blue", "pebbles"]],
	"snow": [7, ["pebbles", "pebbles", "twig", "tuft_small"]],
	"marsh": [12, ["reeds", "reeds", "sedge", "sedge", "tuft_small"]],
	# The Ash (PIX-308): burnt tufts, charcoal, pale stones of ash, and
	# cinders that glow (MapView lays them on a layer of their own).
	"ash": [11, ["burnt_tuft", "burnt_tuft", "charcoal", "ash_stones", "cinders", "cinders"]],
	# The ash healed round a lamp (PIX-323, Lamps.LOOKS): the bare earth's
	# first shoots; then, denser than any field on purpose, a few cells of
	# meadow in flower and a grove of saplings by the lamp.
	"earth": [12, ["tuft_small", "tuft_small", "pebbles", "twig"]],
	"meadow": [40, ["flowers_white", "flowers_yellow", "flowers_red", "flowers_blue", "clover", "tuft"]],
	"grove": [70, ["sapling", "sapling", "sapling", "sapling", "flowers_yellow", "flowers_white", "tuft"]],
	# The river's shallows along a grassy bank (PIX-390: `bank`), reeds at
	# the bank's foot, so a straight shore reads as a riverside.
	"bank": [45, ["reeds"]],
}


## The ridges' decor stands on their rim (PIX-309): this share (%) of the
## rock's cells facing open ground, and of those a row behind them, grow a
## pine or a boulder stepping out of the forest's crown; deeper in, the crown
## covers the rock and nothing stands over it.
const RIM := 45
const BEHIND_RIM := 18


## The Puny World decor a cell grows, or -1. A forest grows in clumps, glades
## and thickets (Woods.forest_choice, PIX-309); a ridge on its rim.
static func choice(grid: Dictionary, cell: Vector2i) -> int:
	var tile: String = grid.get(cell, "")
	if not SCATTER.has(tile):
		return -1
	if tile == "forest":
		return Woods.forest_choice(cell, SCATTER[tile][1])
	var h := absi(hash(cell))
	if tile == "mountain":
		var share := _rim_share(grid, cell)
		if h % 100 >= share:
			return -1
		var picks: Array = SCATTER[tile][1]
		return picks[(h >> 7) % picks.size()]
	if h % 100 >= SCATTER[tile][0]:
		return -1
	var choices: Array = SCATTER[tile][1]
	return choices[(h >> 7) % choices.size()]


## The share (%) of a ridge's cell that grows a pine or a rock: RIM on its
## rim (a neighbour is open ground), BEHIND_RIM a row behind, none deeper.
## Past the map's edges the rock goes on.
static func _rim_share(grid: Dictionary, cell: Vector2i) -> int:
	var behind := false
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if grid.get(cell + step, "mountain") != "mountain":
			return RIM
		for second: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if second != -step and grid.get(cell + step + second, "mountain") != "mountain":
				behind = true
	return BEHIND_RIM if behind else 0


## The small detail a cell grows ("" for none): one of DETAIL's kinds for
## its tile (the mire's grass is the mire's, PunyTerrain.REGION_GRASS; the
## river's water by grass is its bank's shallows), never where choice grows
## something.
static func detail(grid: Dictionary, cell: Vector2i, region := "") -> String:
	var tile: String = grid.get(cell, "")
	if tile == "water" and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(step: Vector2i) -> bool: return grid.get(cell + step, "") == "grass"):
		tile = "bank"
	if not DETAIL.has(tile) or choice(grid, cell) >= 0:
		return ""
	if tile == "grass" and PunyTerrain.REGION_GRASS.has(region):
		tile = PunyTerrain.REGION_GRASS[region]
	var h := _detail_hash(cell)
	if h % 100 >= DETAIL[tile][0]:
		return ""
	var kinds: Array = DETAIL[tile][1]
	return kinds[(h >> 7) % kinds.size()]


## Which of GroundDetail's spots in its cell a cell's detail stands on.
static func detail_variant(cell: Vector2i) -> int:
	return (_detail_hash(cell) >> 13) % GroundDetail.VARIANTS.size()


static func _detail_hash(cell: Vector2i) -> int:
	return absi(hash(Vector3i(cell.x, cell.y, 305)))


## The field decor that blocks on a map: cell -> tile. Only a bush, stump or
## tree on open ground whose every neighbour, corners too, stays open, so one
## never closes a way; never on a `kept` cell (where the hero arrives, a
## villager's home, a chest) or where a prop stands (`drawn`).
static func solid(data: MapData, kept: Dictionary, drawn: Dictionary) -> Dictionary:
	var out := {}
	var cells: Array = data.grid.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if data.grid[cell] not in FIELDS or kept.has(cell) or drawn.has(cell):
			continue
		if choice(data.grid, cell) not in SOLID:
			continue
		var open := true
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var next: Vector2i = cell + Vector2i(dx, dy)
				if next != cell and (not data.is_walkable(next) or data.portals.has(next) or out.has(next)):
					open = false
		if open:
			out[cell] = choice(data.grid, cell)
	return out
