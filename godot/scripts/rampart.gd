class_name Rampart
## Pixelheim's rampart and its gate (PIX-248, Tom: "double rempart ça fait
## bizarre à l'intérieur du village et l'entrée est pas claire ni la
## sortie"). The village's wall was two bands of Shade's overworld castle
## pieces, one drawn above the other, and its way in and out a one-cell slot
## in them with nothing to mark it. Now it is one wall, drawn once, in the
## Medieval Age pack's stone: its walkway on top and its dark face to the
## south, each cell's piece chosen by which of its four neighbours are wall
## too. Where a road runs through it stands a gatehouse: the gate as wide as
## the road, its portcullis up and banners over it, a stout tower either
## side with its cone roof a cell above the wall (a tower stands taller than
## the wall it guards). The torches either side are the map's own lamps, lit
## at night as every lamp is. The town and the village seen small from the
## Reach (Skyline) draw the same gatehouse, so the two read as one place.
## While the Night of Ash's ruins still stand (the Ashes) the gatehouse is
## scorched and the west tower's roof burnt off; the Hamlet mends it.
## Without the paid pack the wall is Shade's CC0 castle pieces
## (PunyTerrain.wall_piece), the gatehouse his towers and dark archways.
## Pure: MapView draws the pieces; what the gatehouse covers past the wall
## (its towers' tops) blocks as the art stands, with or without the art.

## The maps whose walls are Pixelheim's rampart (the Reach's ring round the
## village far off is Skyline's).
const MAPS := ["town"]

## Shade's stone wall by which neighbours are wall too (N=1, E=2, S=4, W=8):
## a lone block, the ends and middles of a run across or down, the corners
## and the joins.
const WALL := {
	0: 2155, 1: 1935, 2: 2156, 3: 1936, 4: 1495, 5: 1715, 6: 1496, 7: 1716,
	8: 2158, 9: 1938, 10: 2157, 11: 1937, 12: 1498, 13: 1718, 14: 1497, 15: 1717,
}
## The gate: the portcullis raised, banners over the arch.
const GATE := 1501
## A gatehouse tower, west and east: its stone in the wall, its face to the
## road; its cone roof on the cell above; the roof burnt off.
const TOWER := [1268, 1270]
const ROOF := [825, 827]
const ROOF_BURNT := 828
## How the fire left the gatehouse, as a modulate: the stone and the gate's
## timbers darkened (GateArt.CHARRED is a burnt post, far darker).
const SCORCHED := Color(0.7, 0.6, 0.55)
const STEPS := {1: Vector2i.UP, 2: Vector2i.RIGHT, 4: Vector2i.DOWN, 8: Vector2i.LEFT}


## The rampart on `grid` (its cells of PunyTerrain.RAMPART), as drawn:
## {"pieces": {cell: Medieval Age tile}, "scorched": {cell: true} (pieces
## the fire darkened), "fallback": {cell: Shade's CC0 overworld tile},
## "covers": [cells past the wall the gatehouse stands on], "gates": [{"cells":
## the gate's, "towers": [west, east], "tops": [west, east]}]}. `ashen`: the
## town still lies in its ruins (Town.ruins).
static func plan(grid: Dictionary, ashen := false) -> Dictionary:
	var out := {"pieces": {}, "scorched": {}, "fallback": {}, "covers": [], "gates": []}
	var cells: Array = grid.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if not _rampart(grid, cell):
			continue
		var tile: String = grid[cell]
		out["pieces"][cell] = GATE if tile.begins_with("door") else WALL[mask(grid, cell)]
		var piece := PunyTerrain.wall_piece(grid, cell)
		if piece >= 0:
			out["fallback"][cell] = piece
	for gate: Dictionary in gates(grid):
		out["gates"].append(gate)
		for side in 2:
			var tower: Vector2i = gate["towers"][side]
			var top: Vector2i = gate["tops"][side]
			out["pieces"][tower] = TOWER[side]
			out["pieces"][top] = ROOF_BURNT if ashen and side == 0 else ROOF[side]
			out["fallback"][tower] = PunyTerrain.TOWER
			out["fallback"][top] = PunyTerrain.TOWER
			out["covers"].append(top)
			if ashen:
				out["scorched"][top] = true
		if ashen:
			for cell: Vector2i in gate["cells"]:
				out["scorched"][cell] = true
	return out


## Which of `cell`'s four neighbours are rampart too, as WALL's key.
static func mask(grid: Dictionary, cell: Vector2i) -> int:
	var bits := 0
	for bit: int in STEPS:
		if _rampart(grid, cell + STEPS[bit]):
			bits |= bit
	return bits


## Every gate in a wall running across: a run of doors side by side with
## wall at both its ends, the road going on through it on one side at least.
## Its towers are the wall at its ends, their tops the cells above them.
static func gates(grid: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = grid.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if not _door(grid, cell) or _door(grid, cell + Vector2i.LEFT):
			continue
		var run: Array[Vector2i] = [cell]
		while _door(grid, run[-1] + Vector2i.RIGHT):
			run.append(run[-1] + Vector2i.RIGHT)
		var west := cell + Vector2i.LEFT
		var east: Vector2i = run[-1] + Vector2i.RIGHT
		if grid.get(west, "") != "wall" or grid.get(east, "") != "wall":
			continue
		out.append({"cells": run, "towers": [west, east], "tops": [west + Vector2i.UP, east + Vector2i.UP]})
	return out


## Whether a road runs through `cell` (the ground the gate stands on):
## a door in a wall across, with a road before or behind it.
static func on_road(grid: Dictionary, cell: Vector2i) -> bool:
	if not _door(grid, cell):
		return false
	var walled := func(step: Vector2i) -> bool: return String(grid.get(cell + step, "")) in PunyTerrain.RAMPART
	if not (walled.call(Vector2i.LEFT) and walled.call(Vector2i.RIGHT)):
		return false
	return grid.get(cell + Vector2i.UP, "") == "path" or grid.get(cell + Vector2i.DOWN, "") == "path"


## Whether the town's gate stands as the fire left it: while any of the
## Night of Ash's ruins is still unbuilt.
static func ashen(done: Array) -> bool:
	return not Town.ruins(done).is_empty()


static func _rampart(grid: Dictionary, cell: Vector2i) -> bool:
	return String(grid.get(cell, "")) in PunyTerrain.RAMPART


static func _door(grid: Dictionary, cell: Vector2i) -> bool:
	return String(grid.get(cell, "")) == "door"
