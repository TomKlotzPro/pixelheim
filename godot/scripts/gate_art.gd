class_name GateArt
## What a shut gate looks like (PIX-254, Gates), in art already in the game:
## the road still there and the land past it in sight, something drawn across
## it that blocks like any prop. The cliff road's rockfall is boulders off
## the mountains (Shade's overworld rock and the dungeon's round stones);
## the river bridge burnt on the Night of Ash is its planks gone in the
## middle, the ruins' charred posts standing in the water and a burnt log
## drifting; Ulla's barricade is a log fence and crates across the Greyhold
## road, one of her old guard in front of it; the avalanche on the Frostgate
## road is a bank of the pass's snow with its rocks. Without the paid pack
## (PunyProps) the fence and the crates are the dungeon's palisade; the
## rest is CC0.
## Pure: MapView draws the pieces, and its bodies stop the hero on the
## gate's cells.

## A piece: on `cell`, its 16 px sprite's top-left `at` px from the cell's,
## from `sheet` ("world": PunyTerrain's, "dungeon": PunyDungeon's,
## "props": the paid Medieval Age's, "villager": PunyArt's, `sprite` its
## id), `tone` ("snow", "charred" or ""), `flat` lying on the ground under
## everyone; sorted among the actors on its own foot otherwise.
const OVERWORLD_ROCK := 702
const DRIFTWOOD := 703
const BOULDERS := [354, 356, 358, 360]
## Shade's log fence down a run (PunyProps.FENCE by N=1, S=4): its top,
## middle and bottom posts; his crate; the CC0 dungeon's palisade.
const FENCE_TOP := 3643
const FENCE_RUN := 3863
const FENCE_END := 4083
const POST := 4303
const CRATE := 1024
const PALISADE := 460
const DUNGEON_POST := 512
## The pass's raised rocks (a small mesa, its rim on the row above).
const MESA := [[119, 120, 121], [146, 147, 148], [173, 174, 175]]
## How dark a burnt post is.
const CHARRED := Color(0.42, 0.34, 0.3)


## The pieces of `gate`'s look, and the cells whose own objects (a bridge's
## planks) aren't drawn while it's shut: {pieces: [piece], hides: [cell]}.
## `paid`: the Medieval Age pack is here (PunyProps.available()).
static func plan(gate: Dictionary, paid: bool) -> Dictionary:
	var cells := Gates.cells_of(gate)
	match String(gate["look"]):
		"rockfall":
			return {"pieces": _rockfall(cells), "hides": []}
		"burnt_bridge":
			return {"pieces": _burnt_bridge(cells, paid), "hides": cells}
		"barricade":
			return {"pieces": _barricade(cells, paid), "hides": []}
		"avalanche":
			return {"pieces": _avalanche(cells), "hides": []}
	return {"pieces": [], "hides": []}


static func _piece(cell: Vector2i, sheet: String, tile: int, at: Vector2, tone := "", flat := false) -> Dictionary:
	return {"cell": cell, "sheet": sheet, "tile": tile, "sprite": "", "at": at, "tone": tone, "flat": flat}


## Boulders heaped across the road and on down the pass behind it, the
## round stones behind and Shade's rocks in front, stones scattered on the
## road before it.
static func _rockfall(cells: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cells.size():
		var cell := cells[i]
		var h := absi(hash(cell))
		out.append(_piece(cell, "dungeon", BOULDERS[h % BOULDERS.size()], Vector2(-2 + (h >> 3) % 5, -7 + (h >> 5) % 3)))
		out.append(_piece(cell + Vector2i.DOWN, "dungeon", BOULDERS[(h >> 15) % BOULDERS.size()], Vector2(-3 + (h >> 17) % 7, -9 + (h >> 19) % 3)))
		out.append(_piece(cell, "world", OVERWORLD_ROCK, Vector2(-5 + (h >> 7) % 11, 2 + (h >> 9) % 2)))
		out.append(_piece(cell + Vector2i.UP, "world", DRIFTWOOD, Vector2(-3 + (h >> 11) % 7, 6 + (h >> 13) % 4), "", true))
	return out


## The middle of the span gone: charred posts where its planks were, a
## burnt log in the water.
static func _burnt_bridge(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var post_sheet := "props" if paid else "dungeon"
	var post := POST if paid else DUNGEON_POST
	var west := cells[0].x
	for cell: Vector2i in cells:
		var side := -6.0 if cell.x == west else 6.0
		out.append(_piece(cell, post_sheet, post, Vector2(side, -3 + (absi(hash(cell)) >> 4) % 6), "charred"))
	out.append(_piece(cells[-1], "world", DRIFTWOOD, Vector2(-9, -6), "charred", true))
	return out


## A log fence down the road's width, crates at its ends, and one of
## Ulla's old guard in front of it between them, facing whoever comes up
## the road.
static func _barricade(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cells.size():
		var cell := cells[i]
		var fence := FENCE_RUN if i > 0 and i < cells.size() - 1 else (FENCE_TOP if i == 0 else FENCE_END)
		out.append(_piece(cell, "props" if paid else "dungeon", fence if paid else PALISADE, Vector2(4, 0)))
		if i != cells.size() / 2:
			out.append(_piece(cell, "props" if paid else "dungeon", CRATE if paid else PALISADE, Vector2(-2, 1)))
	var guard := _piece(cells[cells.size() / 2], "villager", -1, Vector2(-1, 0))
	guard["sprite"] = "guard"
	out.append(guard)
	return out


## A bank of the pass's snow and rock across the road: the pass's raised
## rocks whitened, a snowed-under boulder or two in front.
static func _avalanche(cells: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var low := cells[0]
	var high := cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	# The mesa's three rows end on the gate's last row, its rim above it.
	for row in MESA.size():
		for column in MESA[row].size():
			var cell := Vector2i(low.x + column, high.y - (MESA.size() - 1) + row)
			out.append(_piece(cell, "world", MESA[row][column], Vector2.ZERO, "snow", row == 0))
	out.append(_piece(Vector2i(low.x, high.y), "world", OVERWORLD_ROCK, Vector2(1, 5), "snow"))
	out.append(_piece(Vector2i(high.x, high.y), "dungeon", BOULDERS[1], Vector2(-1, 3), "snow"))
	return out
