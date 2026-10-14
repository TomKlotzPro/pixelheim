class_name Scatter
## Puny World objects scattered on terrain (PIX-130), and which of them stand
## in the way (PIX-137). Pure: world.gd draws what these pick.

## Picked by cell hash: tile id -> [density %, [Puny World tile ids]].
## Forests grow pines and round trees, the blocked highlands carry pines and
## boulders, fields the odd stone or stump, and crops stand in rows of wheat.
const SCATTER := {
	"forest": [85, [197, 224, 251, 206, 233, 260, 705, 729, 732, 783, 810]],
	"mountain": [30, [197, 224, 251, 783, 810, 702]],
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
}


## The Puny World decor a cell grows, or -1.
static func choice(grid: Dictionary, cell: Vector2i) -> int:
	var tile: String = grid.get(cell, "")
	if not SCATTER.has(tile):
		return -1
	var h := absi(hash(cell))
	if h % 100 >= SCATTER[tile][0]:
		return -1
	var choices: Array = SCATTER[tile][1]
	return choices[(h >> 7) % choices.size()]


## The small detail a cell grows ("" for none): one of DETAIL's kinds for
## its tile (the mire's grass is the mire's, PunyTerrain.REGION_GRASS),
## never where choice grows something.
static func detail(grid: Dictionary, cell: Vector2i, region := "") -> String:
	var tile: String = grid.get(cell, "")
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
