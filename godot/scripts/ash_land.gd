class_name AshLand
## areas: travel field +blackiron* +overworld* +mountain_road*
## The Ash and Blackiron as burnt land (PIX-308, the audit's "flat and
## empty": the whole north of the Reach, all of Blackiron and the mountain
## road's flats were Shade's dirt toned one grey-brown, their outcrops green
## grass mesas with green pines, and Blackiron a mining country with no
## mining in it). The ground's shader scorches the ash (patches of char and
## pale ash, cracks, cinders: shaders/open_ground.gdshaderinc); here, the
## rules for what stands on it:
## - the rock beside the ash is burnt (`burnt`): each rock cell takes the
##   burn of the open ground nearest it, through the rock, so an outcrop in
##   the ash and the ridge along it burn and a ridge by green land doesn't.
##   Burnt rock is toned as burnt rock (PunyTerrain.TINTS), no pines crown
##   it (KeptGround) and dead trees stand on it in place of the pines the
##   field grew there (`snag`, AshArt's drawings);
## - Blackiron's outcrops are worked (`workings`): timber shoring at their
##   faces, an ore cart, a winch or a rock veined with ore beside it, spoil
##   heaped at their feet and rails laid between them over the ash.
## Nothing here changes what anyone walks on: rails and spoil lie flat on
## open ground, never on a road, a way on or a cell something stands on
## (MapView.bare); what stands up stands on rock, which already blocks.
## Pure: MapView draws the pieces (EntranceArt's: a cell, a sheet, a tile, a
## pixel offset, a tone, flat or standing on its cell's foot).

## Regions whose ground is burnt: the Reach's Ash and Blackiron's mines. The
## mountain road's whole region is toned already, pines and all
## (PunyTerrain.REGION_TINTS), and keeps its grey ridges.
const BURNT_REGIONS := ["ash", "mines"]
## Dead trees stand on this share (%) of burnt rock: about as many as the
## pines the field grew there, which drew no forest's crowns between them.
const SNAGS := 34
## The Puny World boulder among a ridge's pines: it stays, toned.
const BOULDER := 702
## How many of the queue's cells a slice of the burn's spread takes.
const SPREAD_A_SLICE := 400

## Each map's workings: the rock face (an outcrop's bottom row, open ground
## below it) and the rails laid from its foot, as the corners of a line;
## `side` a winch ("winch") or a rock of ore ("ore") beside its shoring.
const WORKINGS := {
	"blackiron": [
		{"face": Vector2i(12, 12), "rails": [Vector2i(12, 13), Vector2i(12, 17), Vector2i(15, 17)], "side": "winch"},
		{"face": Vector2i(40, 10), "rails": [Vector2i(40, 11), Vector2i(29, 11)], "side": "ore"},
		{"face": Vector2i(33, 15), "rails": [], "side": "winch"},
		{"face": Vector2i(10, 28), "rails": [Vector2i(10, 29), Vector2i(10, 30), Vector2i(44, 30), Vector2i(44, 29)], "side": "ore"},
		{"face": Vector2i(44, 28), "rails": [], "side": "winch"},
	],
}
## The Medieval Age's ore carts (full, empty) and rocks veined with ore
## (DungeonLook's); without the pack a barrel stands for the cart and one
## of Shade's boulders for the ore.
const CARTS := [1079, 853]
const ORE := [1743, 1744, 1745]


## Whether open ground burns: in a burnt region, or the ash itself where
## the region doesn't tone all its ground.
static func scorched(tile: String, region: String) -> bool:
	if region in BURNT_REGIONS:
		return true
	return tile == "ash" and not PunyTerrain.REGION_TINTS.has(region)


## The rock cells of a map that burn: cell -> true. All at once (`burning`
## a slice at a time).
static func burnt(grid: Dictionary, size: Vector2i, regions: Dictionary) -> Dictionary:
	var burning := Burning.new(grid, size, regions)
	burning.rows(0, size.y)
	while not burning.spread(SPREAD_A_SLICE):
		pass
	return burning.out


## The burn worked out a few rows, then a few hundred cells, at a time
## (KeptGround slices it with the rest of a map's ground).
class Burning:
	extends RefCounted
	var out := {}
	var _grid: Dictionary
	var _size: Vector2i
	var _regions: Dictionary
	## Rock cells reached, in the order reached, each with its burn; and how
	## far along the queue the spread has come.
	var _queue: Array[Vector2i] = []
	var _burn := {}
	var _at := 0

	func _init(grid: Dictionary, size: Vector2i, regions: Dictionary) -> void:
		_grid = grid
		_size = size
		_regions = regions

	## Rows [from, to): each rock cell beside open ground takes its burn,
	## burnt when at least as many of the open cells beside it burn as don't.
	func rows(from: int, to: int) -> void:
		for y in range(from, mini(to, _size.y)):
			for x in _size.x:
				var cell := Vector2i(x, y)
				if _grid.get(cell, "") != "mountain" or PunyTerrain.REGION_TINTS.has(_regions.get(cell, "")):
					continue
				var hot := 0
				var cold := 0
				for side: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
					var next := cell + side
					var tile: String = _grid.get(next, "mountain")
					# Water burns or not as the land across it does.
					if tile == "mountain" or tile in PunyTerrain.WATERS:
						continue
					if AshLand.scorched(tile, _regions.get(next, "")):
						hot += 1
					else:
						cold += 1
				if hot + cold > 0:
					_burn[cell] = hot >= cold
					_queue.append(cell)

	## Spreads the burn on through the rock, `count` cells of the queue;
	## true once it has reached every rock cell it can.
	func spread(count: int) -> bool:
		var stop := _at + count
		while _at < stop and _at < _queue.size():
			var cell := _queue[_at]
			_at += 1
			var hot: bool = _burn[cell]
			if hot:
				out[cell] = true
			for side: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var next := cell + side
				if _burn.has(next) or _grid.get(next, "") != "mountain" or PunyTerrain.REGION_TINTS.has(_regions.get(next, "")):
					continue
				_burn[next] = hot
				_queue.append(next)
		return _at >= _queue.size()


## The dead tree a burnt rock cell grows (one of AshArt.SNAGS), or -1: on
## its own hash, never where the field grew a boulder.
static func snag(grid: Dictionary, cell: Vector2i) -> int:
	if Scatter.choice(grid, cell) == BOULDER:
		return -1
	var h := absi(hash(Vector3i(cell.x, cell.y, 308)))
	if h % 100 >= SNAGS:
		return -1
	return (h >> 8) % AshArt.SNAGS.size()


## The workings dressing `map`: {pieces: [piece], rails: n, spoil: n,
## standing: n}, every piece on a cell not in `bare`; flat ones on open
## ground off the roads, standing ones on the rock. `paid`: the Medieval Age
## pack is here.
static func workings(map: MapData, bare: Dictionary, paid: bool) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var out := {"pieces": pieces, "rails": 0, "spoil": 0, "standing": 0}
	var laid := {}
	for working: Dictionary in WORKINGS.get(map.id, []):
		var face: Vector2i = working["face"]
		if not _rock(map, bare, face):
			continue
		# Its shoring at the face, and beside it a cart on one side and a
		# winch or ore on the other, where the rock runs on.
		_stand(out, _piece(face, "ash", "shoring"))
		var west := face + Vector2i.LEFT
		var east := face + Vector2i.RIGHT
		if _rock(map, bare, west):
			var full := absi(hash(face)) % 3 != 0
			if paid:
				_stand(out, _piece(west, "props", CARTS[0] if full else CARTS[1], Vector2(1, 1)))
			else:
				_stand(out, _piece(west, "dungeon", PunyDungeon.BARRELS[1], Vector2(2, 2)))
		if _rock(map, bare, east):
			if working["side"] == "winch":
				_stand(out, _piece(east, "dungeon", PunyDungeon.POST, Vector2(-2, 2)))
				_stand(out, _piece(east, "dungeon", PunyDungeon.POST, Vector2(10, 2)))
				_stand(out, _piece(east, "dungeon", PunyDungeon.WHEEL, Vector2(4, -3)))
			elif paid:
				_stand(out, _piece(east, "props", ORE[absi(hash(east)) % ORE.size()], Vector2(-1, 1)))
			else:
				_stand(out, _piece(east, "dungeon", PunyDungeon.BOULDERS[absi(hash(east)) % PunyDungeon.BOULDERS.size()], Vector2(-1, 1)))
		# The rails out from its foot.
		var line := rail_cells(working["rails"])
		for i in line.size():
			var cell := line[i]
			if not _open(map, bare, cell) or laid.has(cell):
				continue
			var ways := 0
			for j: int in [i - 1, i + 1]:
				if j < 0 or j >= line.size():
					continue
				var step := line[j] - cell
				ways |= {Vector2i.UP: DungeonArt.N, Vector2i.RIGHT: DungeonArt.E, Vector2i.DOWN: DungeonArt.S, Vector2i.LEFT: DungeonArt.W}[step]
			laid[cell] = true
			pieces.append(_piece(cell, "art", DungeonArt.rail(ways), Vector2.ZERO, true))
			out["rails"] += 1
		# Spoil heaped at its foot, either side of the rails.
		for side: Vector2i in [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-2, 2)]:
			var cell := face + side
			if _open(map, bare, cell) and not laid.has(cell):
				laid[cell] = true
				pieces.append(_piece(cell, "ash", "spoil_a" if (cell.x + cell.y) % 2 == 0 else "spoil_b", Vector2.ZERO, true))
				out["spoil"] += 1
	return out


## The cells of a rail line through `corners`, each step one cell, in order.
static func rail_cells(corners: Array) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	for i in corners.size():
		var to: Vector2i = corners[i]
		if line.is_empty():
			line.append(to)
			continue
		var at: Vector2i = line[-1]
		while at != to:
			at += Vector2i(signi(to.x - at.x), 0) if at.x != to.x else Vector2i(0, signi(to.y - at.y))
			line.append(at)
	return line


static func _piece(cell: Vector2i, sheet: String, tile: Variant, at := Vector2.ZERO, flat := false) -> Dictionary:
	return {"cell": cell, "sheet": sheet, "tile": tile, "sprite": "", "at": at, "tone": "", "flat": flat}


static func _stand(out: Dictionary, piece: Dictionary) -> void:
	out["pieces"].append(piece)
	out["standing"] += 1


## Rock a piece may stand against: a rock face with open ground below it,
## nothing standing there.
static func _rock(map: MapData, bare: Dictionary, cell: Vector2i) -> bool:
	return map.tile_at(cell) == "mountain" and not bare.has(cell) and WorldTiles.is_walkable(map.tile_at(cell + Vector2i.DOWN))


## Open ground a flat piece may lie on: walkable, off the roads and the ways
## on, nothing standing or lying there.
static func _open(map: MapData, bare: Dictionary, cell: Vector2i) -> bool:
	var tile := map.tile_at(cell)
	return tile in ["ash", "grass"] and map.is_walkable(cell) and not bare.has(cell) and not map.portals.has(cell)
