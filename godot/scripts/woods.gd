class_name Woods
## areas: travel field
## The woods as they stand (PIX-309). Tom's audit found the Deepwood an
## orchard - a single tree in each forest cell, evenly spaced, all of a size
## - and every ridge a straight planter, its rim lined with identical pines.
## A forest grows in clumps now: a slow noise over its cells (`thickness`)
## thins it to glades and thickens it to thickets, where two trees share a
## cell, their crowns overlapping those around them; trees are of mixed
## sizes and kinds by region (the Medieval Age's round, pine, autumn and
## snowy trees; with Shade's free pack alone his pines and round trees);
## undergrowth (bushes, saplings, stumps) grows between them; and the
## ground under the canopy lies darker (`shade_rows`, drawn by
## shaders/canopy_shade.gdshader). On the ridges a pine or a rock steps out
## onto the cliff's rim. In the Deepwood the sun comes down through the
## canopy's edge in shafts by day (`shafts`). Nothing here blocks: forests
## stay walk-through, and a ridge's rock blocked already. Pure: MapView
## draws what these pick.

## Shade's Medieval Age (paid): where its foliage lies, a cell of the atlas
## each (column, row), and each tree's size in cells.
const SHEET := PunyTown.SHEET
const PUNY := PunyTerrain.SHEET
## Trees by look, two cells tall (their foot on the lower one), one cell, or
## two cells square.
const TALL := {
	"round": [Vector2i(16, 1), Vector2i(18, 7), Vector2i(20, 7), Vector2i(23, 7)],
	"pine": [Vector2i(20, 1), Vector2i(22, 1), Vector2i(20, 4)],
	"autumn": [Vector2i(18, 1), Vector2i(16, 7), Vector2i(22, 4), Vector2i(22, 7)],
	"snowy": [Vector2i(16, 10), Vector2i(18, 10), Vector2i(20, 10)],
}
const SMALL := {
	"round": [Vector2i(16, 0), Vector2i(18, 6), Vector2i(20, 6), Vector2i(23, 6)],
	"pine": [Vector2i(20, 0), Vector2i(22, 0), Vector2i(20, 3)],
	"autumn": [Vector2i(18, 0), Vector2i(16, 6), Vector2i(22, 3), Vector2i(22, 6)],
	"snowy": [Vector2i(16, 9), Vector2i(18, 9), Vector2i(20, 9)],
}
const BIG := [Vector2i(16, 13), Vector2i(18, 13)]
## What grows under them: bushes, saplings and tall grass, stumps.
const UNDERGROWTH := [
	Vector2i(20, 12), Vector2i(21, 12), Vector2i(23, 12), Vector2i(22, 12),
	Vector2i(19, 3), Vector2i(19, 5), Vector2i(17, 2), Vector2i(21, 2), Vector2i(17, 0),
]
## Shade drew no big tree under snow and no bush in it (PIX-398: green
## bushes and big round trees stood bare among the Frostgate's snowy
## pines): the snowy woods grow a snowy tree for a big one, and small snowy
## pines and stumps for undergrowth.
const SNOWY := "snowy"
const SNOWY_UNDERGROWTH := [Vector2i(16, 9), Vector2i(18, 9), Vector2i(20, 9), Vector2i(17, 9), Vector2i(19, 9)]
## And with the free pack alone, Shade's Puny World: a log, a twig, a stump.
const UNDERGROWTH_FREE := [703, 838, 730]
## Each region's woods: its trees' looks, weighted by repeats, and the share
## (%) that turn autumn. A region not here (the Ash, the mines, the mire, the
## mountain road) keeps Shade's free trees as Scatter picks them.
const LOOKS := {
	"deep": [["pine", "pine", "round", "round", "round"], 8],
	"green": [["round", "round", "pine"], 6],
	"snowy": [["snowy"], 0],
}
const REGION_LOOKS := {"deepwood": "deep", "forest": "green", "castle": "green", "coast": "green", "frost": "snowy", "": "green"}
## The open ground a ridge's rim faces that keeps Shade's free trees on it:
## the Ash's and the mire's (theirs are their own looks).
const BARE_FACING := ["ash", "marsh", "stone"]

## How the forest clumps: its noise's two scales (cells) and their weights;
## below GLADE the wood thins to a glade, above THICKET two trees share a
## cell and one in BIG_ONES of those is a big one.
const CLUMP_CELLS := Vector2(4.5, 1.8)
const CLUMP_WEIGHTS := Vector2(0.7, 0.3)
const GLADE := 0.36
const THICKET := 0.6
const BIG_ONES := 6
## In a glade, the share (%) of cells that keep a small tree, and that grow
## undergrowth; under the trees, the share that grow undergrowth too.
const GLADE_TREES := 30
const GLADE_UNDERGROWTH := 40
const UNDER_TREES := 28
## How far a tree's foot strays from its cell's middle, in pixels, and where
## the second tree of a thicket stands from the first.
const STRAY := Vector2i(5, 3)
const PARTNER := Vector2i(7, -5)
## The foot of a tree in its cell, from the cell's top-left, before it strays.
const FOOT := Vector2(8, 13)

## The ground under the canopy (shaders/canopy_shade.gdshader): how much of
## the forest each cell holds, a cell a texel, as the forest's tiles say.
const FOREST := "forest"

## Sun shafts (Lights.daylight, Lights.shaft) through the canopy's edge into
## the Deepwood's glades: at most this many, this far apart (cells), this
## strong and this long.
const SHAFT_REGION := "deepwood"
const SHAFTS := 8
const SHAFT_APART := 10
const SHAFT_ENERGY := 0.38
const SHAFT_REACH := 60.0


## How thick the wood stands at `cell`, 0..1: a slow noise over the cells.
static func thickness(cell: Vector2i) -> float:
	return CLUMP_WEIGHTS.x * _noise(Vector2(cell) / CLUMP_CELLS.x, 309) + CLUMP_WEIGHTS.y * _noise(Vector2(cell) / CLUMP_CELLS.y, 311)


## The Puny World tree (or, in a glade, the undergrowth) a forest cell grows,
## -1 for none: Scatter.choice's pick for a forest.
static func forest_choice(cell: Vector2i, trees: Array) -> int:
	var h := _hash(cell, 1)
	if thickness(cell) < GLADE:
		if h % 100 < GLADE_TREES:
			return trees[(h >> 7) % trees.size()]
		if (h >> 3) % 100 < GLADE_UNDERGROWTH:
			return UNDERGROWTH_FREE[(h >> 9) % UNDERGROWTH_FREE.size()]
		return -1
	return trees[(h >> 7) % trees.size()]


## The look of the woods at `cell` of `map` ("deep", "green", "snowy"), or ""
## where Shade's free trees stand as Scatter picks them: by the cell's region,
## the pines a few cells off a snowfield snowy (PunyTerrain.snows_on), and on
## a ridge by the open ground its rim faces (the Ash's and the mire's keep
## their own).
static func look_at(map: MapData, cell: Vector2i) -> String:
	if PunyTerrain.snows_on(map.id, cell):
		return "snowy"
	var region: String = map.regions.get(cell, "")
	if not REGION_LOOKS.has(region):
		return ""
	if map.grid.get(cell, "") == "mountain":
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if map.grid.get(cell + step, "mountain") in BARE_FACING:
				return ""
	return REGION_LOOKS[region]


## What stands on a forest or ridge cell `cell` that grows `choice` (Scatter
## .choice), in the woods' `look` (look_at; "" for Shade's free tree as
## picked), with the paid pack or not: [{"sheet", "rect" (on the sheet), "foot"
## (from the cell's top-left, in pixels), "own" (drawn in its own colours, not
## the region's tone)}], back to front.
static func pieces(tile: String, cell: Vector2i, choice: int, look: String, paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if choice < 0:
		return out
	var h := _hash(cell, 2)
	var foot := FOOT + Vector2((h % (2 * STRAY.x + 1)) - STRAY.x, ((h >> 5) % (2 * STRAY.y + 1)) - STRAY.y)
	var medieval := paid and look != ""
	if choice in UNDERGROWTH_FREE:
		out.append(_undergrowth(cell, foot, medieval, look))
		return out
	if choice == 702:
		# A rock stays a rock.
		out.append(_free(choice, foot))
		return out
	var stand := thickness(cell) if tile == FOREST else 0.5
	var thick := stand >= THICKET
	if thick:
		# Two trees share the cell, the second behind the first.
		var partner := foot + Vector2(PARTNER.x if (h >> 9) % 2 == 0 else -PARTNER.x, PARTNER.y)
		out.append(_tree(cell, 3, partner, look, medieval, choice, false))
	var glade := stand < GLADE
	out.append(_tree(cell, 4, foot, look, medieval, choice, thick and (h >> 11) % BIG_ONES == 0, glade))
	if tile == FOREST and not glade and (h >> 13) % 100 < UNDER_TREES:
		var front := foot + Vector2(-4 if (h >> 9) % 2 == 0 else 4, 3)
		out.append(_undergrowth(cell, front, medieval, look))
	return out


## A tree at `foot`: the Medieval Age's in `look` (a big one when `big`, a
## small one in a glade), or Shade's free one picked.
static func _tree(cell: Vector2i, salt: int, foot: Vector2, look: String, medieval: bool, choice: int, big: bool, small := false) -> Dictionary:
	if not medieval:
		return _free(choice, foot) if salt == 4 else _free(_free_partner(cell, choice), foot)
	var h := _hash(cell, salt)
	var kinds: Array = LOOKS[look][0]
	var kind: String = kinds[h % kinds.size()]
	if (h >> 4) % 100 < int(LOOKS[look][1]):
		kind = "autumn"
	if big and look != SNOWY:
		var at: Vector2i = BIG[(h >> 8) % BIG.size()]
		return {"sheet": SHEET, "rect": Rect2(at * 16, Vector2(32, 32)), "foot": foot, "own": true}
	var short := small or (h >> 12) % 100 < 22
	var from: Dictionary = SMALL if short else TALL
	var trees: Array = from[kind]
	var at: Vector2i = trees[(h >> 8) % trees.size()]
	return {"sheet": SHEET, "rect": Rect2(at * 16, Vector2(16, 16 if short else 32)), "foot": foot, "own": true}


## A second free tree for a thicket: another of Scatter's forest picks.
static func _free_partner(cell: Vector2i, choice: int) -> int:
	var trees: Array = Scatter.SCATTER["forest"][1]
	var other: int = trees[_hash(cell, 5) % trees.size()]
	return other if other != choice else trees[(trees.find(choice) + 1) % trees.size()]


static func _free(tile_id: int, foot: Vector2) -> Dictionary:
	return {"sheet": PUNY, "rect": PunyTerrain.region(tile_id), "foot": foot + Vector2(0, 2), "own": false}


static func _undergrowth(cell: Vector2i, foot: Vector2, medieval: bool, look: String) -> Dictionary:
	var h := _hash(cell, 6)
	if not medieval:
		return _free(UNDERGROWTH_FREE[h % UNDERGROWTH_FREE.size()], foot)
	var growth: Array = SNOWY_UNDERGROWTH if look == SNOWY else UNDERGROWTH
	var at: Vector2i = growth[h % growth.size()]
	return {"sheet": SHEET, "rect": Rect2(at * 16, Vector2(16, 16)), "foot": foot + Vector2(0, 2), "own": true}


## Rows [from, to) of the canopy's mask into `image` (a cell a texel): 1 in
## red under the forest, 0 elsewhere. Filtered between cells and bent by a
## noise in the shader, it darkens the ground under the trees with a ragged,
## dithered edge.
static func shade_rows(image: Image, grid: Dictionary, from: int, to: int) -> int:
	var count := 0
	for y in range(from, mini(to, image.get_height())):
		for x in image.get_width():
			if grid.get(Vector2i(x, y), "") == FOREST:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
				count += 1
	return count


## Where the sun comes down through the canopy's edge into the Deepwood's
## glades by day: open ground with the forest standing to its north-west
## (the light comes from the top left), spaced SHAFT_APART cells, at most
## SHAFTS of them.
static func shafts(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			if map.regions.get(cell, "") != SHAFT_REGION or not WorldTiles.is_walkable(map.grid.get(cell, "")) or map.grid[cell] == FOREST:
				continue
			if map.grid.get(cell + Vector2i(-1, -1), "") != FOREST or map.grid.get(cell + Vector2i.UP, "") != FOREST:
				continue
			if out.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - x), absi(other.y - y)) < SHAFT_APART):
				continue
			out.append(cell)
			if out.size() >= SHAFTS:
				return out
	return out


## Smooth value noise over the cells, 0..1, its lattice hashed with `salt`.
static func _noise(p: Vector2, salt: int) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(i)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _unit(i, salt)
	var b := _unit(i + Vector2i(1, 0), salt)
	var c := _unit(i + Vector2i(0, 1), salt)
	var d := _unit(i + Vector2i(1, 1), salt)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _unit(at: Vector2i, salt: int) -> float:
	return float(absi(hash(Vector3i(at.x, at.y, salt))) % 1000) / 1000.0


static func _hash(cell: Vector2i, salt: int) -> int:
	return absi(hash(Vector3i(cell.x, cell.y, 3090 + salt)))
