class_name PunyTerrain
## Shade's Puny World overworld (assets/puny/world, CC0, PIX-130) drawn over
## the web game's maps. The tile grid stays the truth for walking; Puny's
## corner wang tiles go on the dual grid: one tile on every cell corner, whose
## four quarters belong to the four cells meeting there. A terrain boundary
## therefore falls on the very cell edges the hero collides on.
##
## The wang tables come straight from Shade's Tiled tileset (.tsx) through
## PunySheet: which tile has which terrain in each corner, and how the water
## animates.

const SHEET := "res://assets/puny/world/punyworld-overworld-tileset.png"
const TSX := "res://assets/puny/world/punyworld-overworld-tiles.tsx"
const COLUMNS := 27
const TILE := 16

## Our tile id -> the overworld wang terrain its ground is drawn as; anything
## else stands on grass (forests, flowers, houses, props...).
const GROUND := {
	"water": "river", "bridge": "river", "mountain": "cliff",
	"path": "dirt", "ash": "dirt", "sand": "sand",
	# PIX-164: Shade's sea in three depths (it meets sand, then itself);
	# snow is his grass whitened, ice his sand frosted, stone his dirt greyed.
	"shore": "seawater-light", "dock": "seawater-light", "sea": "seawater-medium", "deep_sea": "seawater-deep",
	"snow": "grass", "ice": "sand", "stone": "dirt",
	# A cave mouth is the rock's own (PIX-269): the cliff runs on unbroken
	# over it, its dark mouth at the cliff's foot, not a notch of grass cut
	# in the ridge with a mound standing in it.
	"cave": "cliff",
	# The ash healed round a lamp to bare earth (PIX-323, Lamps): Shade's
	# dirt, toned as earth, not ash.
	"earth": "dirt",
}
## Shade pairs every terrain with grass only. Where two others meet at one
## corner, the first of these keeps its corners and the rest fall back to
## grass: cliffs stand over water, water over roads, roads over sand.
const STRENGTH := ["cliff", "seawater-deep", "seawater-medium", "seawater-light", "river", "dirt", "sand", "trees"]
## Regions Shade didn't paint, toned from his grass and dirt by
## shaders/region_tint.gdshader: tile id -> hue. Ash wastes go a burnt warm
## grey, the mire a murky green.
const TINTS := {
	"ash": Color(0.47, 0.45, 0.43),
	"marsh": Color(0.30, 0.42, 0.34),
	"snow": Color(0.8, 0.84, 0.9),
	"ice": Color(0.5, 0.66, 0.78),
	"stone": Color(0.56, 0.56, 0.58),
	# The mountain road's trodden way through the ash (REGION_PATHS).
	"trodden": Color(0.62, 0.52, 0.4),
	# Rock by the ash, burnt (PIX-308, AshLand.burnt): a sooty grey-brown,
	# its grassy top scorched (open_ground.gdshaderinc).
	"burnt_rock": Color(0.43, 0.4, 0.38),
	# The ash healed to bare earth round a lamp (PIX-323): dark, fresh soil,
	# neither the ash nor the road's dirt; never scorched.
	"earth": Color(0.5, 0.4, 0.31),
}
## What each cell of the tint mask asks of region_tint.gdshader, in its
## alpha (PIX-305): the region's tone over all its ground; the mire's, which
## lays its murk and puddles too (MIRES); or, in a cell of grass or rock
## beside a region toned from Shade's dirt, that tone over the cell's dirt
## alone (tint_fringe_rows). Each pixel takes one cell's tone, whole.
const KIND_TONE := 1.0
const KIND_MIRE := 0.75
const KIND_FRINGE := 0.375
## Tiles whose tone is the mire's.
const MIRES := ["marsh"]
## Regions whose grass takes another tone: the Mirefen's is the mire's own
## (PIX-305: its tussocks, two cells square, were Shade's bright lawn
## dithered into the murk in blobs that read as camouflage; the mire's
## murk, sedge and puddles are the shader's now, open_ground.gdshaderinc).
## Blackiron's few cells of grass are burnt (PIX-308): toned and dressed
## as the ash about them. (The verges of the Reach's road north stay the
## grass at the Ash's edge, its dirt alone toned.)
const REGION_GRASS := {"mire": "marsh", "mines": "ash"}
## The grounds a dirt-toned region's edge reaches into: the grass beside the
## ash, where Shade's dirt runs a few pixels past the cell's edge in tufts,
## and the rock, whose cliff stands in the ash at its foot.
const FRINGED := ["grass", "cliff"]
## Regions whose every ground cell takes a tone, trees' included (the pass's
## snow under its pines; the mountain road's ash over its ridges, PIX-253 step 8).
const REGION_TINTS := {"frost": "snow", "road": "ash"}
## And their roads, which would whiten to a glare: the pass's road is trodden
## grey; the mountain road's a trodden brown, to read in the ash.
const REGION_PATHS := {"frost": "stone", "road": "trodden"}
## What a bridge or a dock spans.
const WATERS := ["water", "shore", "sea", "deep_sea"]
## The tiles a span is laid in: a bridge from bank to bank, a dock out from
## one.
const SPANS := ["bridge", "dock"]
## Ground the hero can walk out onto; maps with none are interiors.
const OUTDOOR := ["grass", "forest", "marsh", "ash", "sand", "snow", "stone"]

## Ramparts in Shade's castle pieces: towers on corners and every few steps
## along a run, crenellated runs across and down, a dark gate in the door.
const TOWER := 770
const TOWER_ACROSS := 797
const WALL_ACROSS := 721
const WALL_DOWN := 747
const GATE := 802
const TOWER_EVERY := 8
## A cave mouth: Shade's own dark hole in the rock, standing on the cliff
## the ground draws under it (GROUND), with no frame round it (Tom: the
## framed mouth and its torches looked stuck on, PIX-269).
const CAVE_MOUTH := 128
const RAMPART := ["wall", "door", "door_shut"]

## Maps that show the whole village as one block of roofs (the overworld):
## Skyline draws the village there, small (PIX-248).
const SKYLINE_MAPS := ["overworld"]

static var _sheet: PunySheet


## Shade's overworld sheet, read once, with every tile the open air draws
## on tile layers made in its tileset at once (prepare).
static func sheet() -> PunySheet:
	if _sheet == null:
		_sheet = PunySheet.new(SHEET, TSX, COLUMNS)
		_prepare(_sheet)
	return _sheet


## Bridges' and docks' planks (object_at), and the village far off's well,
## debris and roofs as icons (Skyline): tiles laid on the objects' layer.
const OBJECTS := [821, 876, 875, 877, 848, 847, 820, 874]


## Makes every tile the ground, the crowns and what stands on them may draw
## (Shade's corner tiles, the objects, the ramparts, the gates in the rock,
## the field's growth) before any layer is drawn with the tileset (One
## Reach, PIX-269). Made as first used, a tile new to the session changed
## the tileset under every layer drawn with it, and they all drew again in
## that frame: drawing the map beside the hero's redrew the hero's, some
## 10 ms. Two hundred tiles, a couple of milliseconds once.
static func _prepare(puny: PunySheet) -> void:
	var sorted := made_ahead(puny).keys()
	sorted.sort()
	for id: int in sorted:
		puny.slot(id)


## The tiles _prepare makes: id -> true.
static func made_ahead(puny: PunySheet) -> Dictionary:
	var ids := {}
	for wangset: String in puny.corners:
		for key: String in puny.corners[wangset]:
			for id: int in puny.corners[wangset][key]:
				ids[id] = true
	var more: Array = OBJECTS + [CAVE_MOUTH, TOWER, TOWER_ACROSS, WALL_ACROSS, WALL_DOWN, GATE, Ways.ROCK_GATE, Ways.ROCK_GATE_BARRED, Skyline.WELL]
	more.append_array(Skyline.DEBRIS)
	more.append_array(Skyline.ICONS.values())
	for tile: String in Scatter.SCATTER:
		more.append_array(Scatter.SCATTER[tile][1])
	for id: int in more:
		ids[id] = true
	return ids


static func _combos() -> Dictionary:
	return sheet().corners.get("overworld", {})


## The ground terrain a cell of ours is drawn as.
static func ground_of(tile: String) -> String:
	return GROUND.get(tile, "grass")


## The ground drawn under one cell of a map. A dock stands in the water
## around it: the coast's piers over their pale shallows, but one built out
## into a river (the village's had one, PIX-236, till it read as half a
## bridge, PIX-287) over the river, or a pale square of sea would show round
## its planks. A gate in a rampart stands on the road
## that runs through it (PIX-248), not on a strip of grass across it.
static func ground_at(grid: Dictionary, cell: Vector2i) -> String:
	var tile: String = grid.get(cell, "")
	if tile == "dock":
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.get(span_end(grid, cell, step), "") == "water":
				return ground_of("water")
	if tile == "door" and Rampart.on_road(grid, cell):
		return ground_of("path")
	return ground_of(tile)


## The tile for four corner terrains [tl, tr, br, bl]; `pick` chooses among
## equal tiles (grass has nine) so fields don't repeat.
static func corner_tile(corners: Array, pick: int) -> int:
	var key := ",".join(corners)
	if not _combos().has(key):
		key = ",".join(settle(corners))
	var tiles: Array = _combos()[key]
	return tiles[absi(pick) % tiles.size()]


## Corners Shade never drew together, reduced to ones he did: the strongest
## terrain keeps its corners, the others become grass; a pairing still
## missing (water touching only diagonally) floods with the strong terrain so
## no blocked cell ever looks walkable.
static func settle(corners: Array) -> Array:
	var strongest := "grass"
	for terrain: String in STRENGTH:
		if terrain in corners:
			strongest = terrain
			break
	var settled := corners.map(func(c: String) -> String: return c if c == strongest else "grass")
	if not _combos().has(",".join(settled)):
		settled = [strongest, strongest, strongest, strongest]
	return settled


## Grounds a cliff stands in, not over a strip of grass (One Reach, PIX-269).
## Shade drew his cliffs with grass alone, so where one met the sea, a river,
## a beach, a road or the ash, that ground settled to grass at its foot, and
## the grass ended in a straight edge where the ground's own tiles began: a
## block of grass along every cliff by the water and on the ash, the sea's
## corner cut square. His transparent cliffs stand on any ground: the water
## and the road run on under them.
const RIM_GROUNDS := ["dirt", "sand", "river", "seawater-light", "seawater-medium", "seawater-deep"]


## The tiles at a corner of four terrains [tl, tr, br, bl]: [the ground, the
## cliff standing on it (-1 for none)]. A cliff by the water, sand or a
## road stands on it (Shade's transparent cliff over it, its foot in it);
## by grass the ground is corner_tile's and no cliff stands on it.
static func rimmed(corners: Array, pick: int) -> Array:
	if "cliff" in corners:
		for terrain: String in STRENGTH:
			if terrain == "cliff" or terrain not in corners:
				continue
			if terrain not in RIM_GROUNDS:
				break
			var ground := corners.map(func(c: String) -> String: return terrain if c == "cliff" else c)
			var rim := corners.map(func(c: String) -> String: return "cliff-transparent" if c == "cliff" else "air")
			return [corner_tile(ground, pick), corner_tile(rim, pick)]
	return [corner_tile(corners, pick), -1]


## Every ground tile of a map, keyed by dual cell: dual cell (x, y) sits on
## the corner shared by cells (x-1, y-1) to (x, y), so the layer drawing them
## is shifted half a tile up-left. Off-map cells repeat the nearest edge, and
## `pad` more all round carry the ground on past the map's edges (PIX-269:
## the road runs on out of a way out, the ridge on past a corner, wherever
## the camera sees past the edge).
static func ground_tiles(grid: Dictionary, size: Vector2i, pad := 0) -> Dictionary:
	return _dual_tiles(size, func(cell: Vector2i) -> String: return ground_at(grid, cell), pad)


## The forest crowning a ridge keeps a ragged edge (PIX-309: every border
## was a straight planter, its rim then rows of pines): of the rock walled in
## on all four sides, this share (%) of the cells just behind the rim is left
## bare, and of the cells deeper in a few, rocky glades in the pines. Picked
## by the cell (in the Reach's plane, so two maps along a line agree).
const CROWN_GAPS := 35
const CROWN_GLADES := 3


## Whether the forest crowns rock `cell` walled in on all four sides, `deep`
## when its four neighbours are walled in too (CROWN_GAPS, CROWN_GLADES).
static func crown_kept(cell: Vector2i, deep: bool) -> bool:
	return absi(hash(Vector3i(cell.x, cell.y, 1309))) % 100 >= (CROWN_GLADES if deep else CROWN_GAPS)


## The pine forest crowning the mountains, on the same dual grid: it covers
## mountain cells walled in by mountains on all four sides, so the cliff rim
## at a range's edge stays in view, its edge ragged (crown_kept). Bare
## corners ("air") are left out; `pad` as for the ground.
static func forest_tiles(grid: Dictionary, size: Vector2i, pad := 0) -> Dictionary:
	var walled := func(cell: Vector2i) -> bool:
		for step: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var near := Vector2i(clampi(cell.x + step.x, 0, size.x - 1), clampi(cell.y + step.y, 0, size.y - 1))
			if grid.get(near, "") != "mountain":
				return false
		return true
	var crowned := func(cell: Vector2i) -> String:
		if not walled.call(cell):
			return "air"
		var deep := true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			deep = deep and walled.call(Vector2i(clampi(cell.x + step.x, 0, size.x - 1), clampi(cell.y + step.y, 0, size.y - 1)))
		return "trees" if crown_kept(cell, deep) else "air"
	var tiles := _dual_tiles(size, crowned, pad)
	for cell: Vector2i in tiles.keys():
		if tiles[cell] == corner_tile(["air", "air", "air", "air"], 0):
			tiles.erase(cell)
	return tiles


static func _dual_tiles(size: Vector2i, terrain_at: Callable, pad := 0) -> Dictionary:
	var at := func(x: int, y: int) -> String:
		return terrain_at.call(Vector2i(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1)))
	var tiles := {}
	for y in range(-pad, size.y + 1 + pad):
		for x in range(-pad, size.x + 1 + pad):
			var corners := [at.call(x - 1, y - 1), at.call(x, y - 1), at.call(x, y), at.call(x - 1, y)]
			tiles[Vector2i(x, y)] = corner_tile(corners, hash(Vector2i(x, y)))
	return tiles


## The grounds Shade draws as water: the river and the sea's three depths
## (under bridges and docks too).
const WATER_GROUNDS := ["river", "seawater-light", "seawater-medium", "seawater-deep"]


## Water inland (PIX-306): rivers, ponds, the Deepwood's lake, the Mirefen's
## pools. Shade drew them one flat colour, so the shaders give them what his
## sea has, from the water mask: how deep each cell lies, and what water it
## is - its tone, by the map it lies in (`WATER_TONES`: the mire's murk, the
## Deepwood's dark, the Frostgate's cold, clear elsewhere), whether it runs
## and which way, and whether a bridge stands in it. The sea keeps Shade's
## own three depths (tone 0).
const WATER_CLEAR := 1
const WATER_MIRE := 2
const WATER_DEEP := 3
const WATER_ICE := 4
const WATER_TONES := {"mirefen": WATER_MIRE, "deepwood": WATER_DEEP, "frostgate": WATER_ICE}
## The tones and the ways water runs by name (FLOWS' order), for the harness.
const TONE_NAMES := ["sea", "clear", "mire", "deep", "ice"]
const FLOW_NAMES := ["still", "west", "south"]
## Pools, a lake, a hole in the ice lie still; rivers run.
const STILL_WATERS := [WATER_MIRE, WATER_DEEP, WATER_ICE]
## Which way water runs, by its code: still; west along a river that runs
## across the map, south down one that runs down it (on toward the sea,
## south-west of the Reach). The village's river comes down from the north
## and turns west along the south wall.
const FLOWS := [Vector2i.ZERO, Vector2i.LEFT, Vector2i.DOWN]
const DIAGONALS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
## How many cells out from its bank water deepens.
const DEPTH_CELLS := 3
## How far a run of water is measured each way to tell which way it runs.
const RUN_CELLS := 8
## The code's bits (the mask's alpha, /255): the tone times TONE_BIT, a
## bridge or a dock standing in it SPAN_BIT, and the way it runs (FLOWS).
const TONE_BIT := 16
const SPAN_BIT := 8
## On the land by a bank the code's low bits say which ground it is, so
## where the bank bends back the shader draws Shade's own tile of it there:
## grass (the mire's and the snow's too, toned), dirt (a road, the ash, the
## rock's foot), sand (the beach, the ice).
const BANK_GROUNDS := {"grass": 0, "dirt": 1, "cliff": 1, "sand": 2}

static var _wet := {}


## Where the water lies, cell by cell, for the shaders (PIX-223). Red is 1 on
## water and 0 on land, for the foam region_tint.gdshader lays along the
## shore: filtered between cells it reads a half on the shore line, rising
## out into the water. Green counts the water cells straight above (/255), so
## reflections.gdshader finds the bank that a cell's water mirrors. Inland
## (PIX-306), blue is how far the bank lies (water_depth / DEPTH_CELLS) and
## alpha the water's code (water_code / 255); both 0 on the sea and the land.
static func water_map(grid: Dictionary, size: Vector2i, map_id := "") -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var above := PackedInt32Array()
	above.resize(size.x)
	water_rows(image, grid, 0, size.y, above, map_id)
	return ImageTexture.create_from_image(image)


## Rows [from, to) of the water mask into `image` (One Reach, PIX-269: a
## map's masks are worked out a few rows a frame beside the hero), `above`
## carrying each column's count of water cells down from the rows before.
## A row's runs west and east are counted in two passes along it; only
## inland water looks down its column and along its diagonals, a few cells.
static func water_rows(image: Image, grid: Dictionary, from: int, to: int, above: PackedInt32Array, map_id := "") -> void:
	var size := Vector2i(image.get_width(), image.get_height())
	var tone: int = WATER_TONES.get(map_id, WATER_CLEAR)
	is_wet("")
	var tiles := PackedStringArray()
	tiles.resize(size.x)
	var west := PackedInt32Array()
	west.resize(size.x)
	for y in range(from, to):
		# Whether the row above was wet, column by column, before this row
		# counts on.
		var wet_above := above.duplicate()
		for x in size.x:
			tiles[x] = grid.get(Vector2i(x, y), "")
		# Past the map's edge its edge cell is carried on.
		var run := RUN_CELLS if _wet.has(tiles[0]) else 0
		for x in size.x:
			west[x] = run
			run = mini(run + 1, RUN_CELLS) if _wet.has(tiles[x]) else 0
		run = RUN_CELLS if _wet.has(tiles[size.x - 1]) else 0
		for x in range(size.x - 1, -1, -1):
			var east := run
			var tile := tiles[x]
			if not _wet.has(tile):
				run = 0
				above[x] = 0
				continue
			run = mini(run + 1, RUN_CELLS)
			var cell := Vector2i(x, y)
			var depth := 0.0
			var code := 0
			if tile == "water" or tile == "bridge" or (tile == "dock" and ground_at(grid, cell) == "river"):
				# Water up to the map's top edge runs on past it.
				var north := RUN_CELLS if above[x] >= y else mini(above[x], RUN_CELLS)
				var south := _run_down(grid, cell, size)
				var cells := water_depth(grid, cell, size, west[x], east, north, south)
				depth = cells / float(DEPTH_CELLS)
				code = water_code(tile, tone, west[x] + east, north + south)
				if cells == 1:
					_mark_bank(image, grid, cell, tone, tiles, wet_above)
			image.set_pixelv(cell, Color(1.0, mini(above[x], 255) / 255.0, depth, code / 255.0))
			above[x] += 1


## Whether our tile `tile` is drawn as water (WATER_GROUNDS).
static func is_wet(tile: String) -> bool:
	if _wet.is_empty():
		for kind: String in GROUND:
			if GROUND[kind] in WATER_GROUNDS:
				_wet[kind] = true
	return _wet.has(tile)


## How many cells from inland water's `cell` to the nearest bank, along the
## rows, the columns and the diagonals, up to DEPTH_CELLS: 1 by a bank.
## `west`, `east`, `north` and `south` count the wet cells straight that way.
static func water_depth(grid: Dictionary, cell: Vector2i, size: Vector2i, west: int, east: int, north: int, south: int) -> int:
	var depth := mini(mini(mini(west, east), mini(north, south)) + 1, DEPTH_CELLS)
	for reach in range(1, depth):
		for step: Vector2i in DIAGONALS:
			if not is_wet(grid.get(_inside(cell + step * reach, size), "")):
				return reach
	return depth


## Inland water's code (the mask's alpha) on a cell of tile `tile`: its
## tone, a bridge or a dock standing in it, and which way it runs (FLOWS):
## still in pools, lakes and the ice, else along its longer run, `across`
## (wet cells west and east of it) or `down` (north and south).
static func water_code(tile: String, tone: int, across: int, down: int) -> int:
	var code := tone * TONE_BIT
	if tile == "bridge" or tile == "dock":
		code += SPAN_BIT
	if tone not in STILL_WATERS:
		code += 1 if across >= down else 2
	return code


## The land round inland water's `cell` by its bank takes the water's tone
## in the mask's alpha (red still 0), and which ground it is (BANK_GROUNDS),
## so the shaders know to draw the bank that bends out over it, and the
## land's own ground where it bends back. The row above and this one are
## known dry by `wet_above` and this row's `tiles`; the row below is marked
## as it stands, and its water writes over the mark when its row comes.
static func _mark_bank(image: Image, grid: Dictionary, cell: Vector2i, tone: int, tiles: PackedStringArray, wet_above: PackedInt32Array) -> void:
	for dy in range(-1, 2):
		var y := cell.y + dy
		if y < 0 or y >= image.get_height():
			continue
		for dx in range(-1, 2):
			var x := cell.x + dx
			if x < 0 or x >= image.get_width() or (dx == 0 and dy == 0):
				continue
			if (dy < 0 and wet_above[x] > 0) or (dy == 0 and _wet.has(tiles[x])):
				continue
			var land: int = BANK_GROUNDS.get(ground_of(tiles[x] if dy == 0 else grid.get(Vector2i(x, y), "")), 0)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, (tone * TONE_BIT + land) / 255.0))


## The inland water nearest `cell` in a water mask `image` (water_map's),
## within `reach` cells: its tone and the way it runs, "clear west", "mire
## still"; "" when there's none (the harness's water=).
static func water_near(image: Image, cell: Vector2i, reach: int) -> String:
	var best := ""
	var nearest := reach * reach * 2 + 1
	for y in range(maxi(cell.y - reach, 0), mini(cell.y + reach + 1, image.get_height())):
		for x in range(maxi(cell.x - reach, 0), mini(cell.x + reach + 1, image.get_width())):
			var texel := image.get_pixel(x, y)
			var code := roundi(texel.a * 255.0)
			var away := (Vector2i(x, y) - cell).length_squared()
			if texel.r > 0.5 and code >= TONE_BIT and away < nearest:
				nearest = away
				best = "%s %s" % [TONE_NAMES[code / TONE_BIT], FLOW_NAMES[code % SPAN_BIT]]
	return best


## How many wet cells lie straight south of `cell`, up to RUN_CELLS (the
## map's bottom edge carried on).
static func _run_down(grid: Dictionary, cell: Vector2i, size: Vector2i) -> int:
	var count := 0
	while count < RUN_CELLS and _wet.has(grid.get(Vector2i(cell.x, mini(cell.y + count + 1, size.y - 1)), "")):
		count += 1
	return count


static func _inside(cell: Vector2i, size: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))


## The per-cell mask region_tint.gdshader reads: a region's hue, and what
## kind of toning the cell asks for in its alpha (KIND_*).
static func tint_map(grid: Dictionary, size: Vector2i, regions := {}) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	tint_rows(image, grid, regions, 0, size.y, AshLand.burnt(grid, size, regions))
	tint_fringe_rows(image, grid, 0, size.y)
	for ring in 2:
		tint_spill(image, grid)
	return ImageTexture.create_from_image(image)


## Rows [from, to) of the tint mask into `image`, a few rows a frame beside
## the hero (PIX-269); then the fringe's rows once every row is in, then two
## rings of tint_spill. The rock that burns (`burnt`, AshLand.burnt) is
## burnt rock (PIX-308).
static func tint_rows(image: Image, grid: Dictionary, regions: Dictionary, from: int, to: int, burnt := {}) -> void:
	for y in range(from, to):
		for x in image.get_width():
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			var tile := "burnt_rock" if burnt.has(cell) else toned_as(grid[cell], regions.get(cell, ""))
			if TINTS.has(tile):
				image.set_pixelv(cell, Color(TINTS[tile], KIND_MIRE if tile in MIRES else KIND_TONE))


## The TINTS entry a tile takes in a region ("" for none): a region's own
## road, grass or ground, or the tile's.
static func toned_as(tile: String, region: String) -> String:
	if tile == "path" and REGION_PATHS.has(region):
		return REGION_PATHS[region]
	if tile == "grass" and REGION_GRASS.has(region):
		return REGION_GRASS[region]
	if not TINTS.has(tile) and REGION_TINTS.has(region):
		return REGION_TINTS[region]
	return tile if TINTS.has(tile) else ""


## Rows [from, to) of the fringe (PIX-305): an untoned cell of grass or
## rock beside a cell toned from Shade's dirt takes its tone over its own
## dirt alone (KIND_FRINGE), so the ash's dirt reaching past its cells in
## tufts, or under a cliff's foot, isn't left a yellow rim round it. Read
## once every row of tint_rows is in; it writes untoned cells only.
static func tint_fringe_rows(image: Image, grid: Dictionary, from: int, to: int) -> void:
	var size := Vector2i(image.get_width(), image.get_height())
	for y in range(from, to):
		for x in size.x:
			var cell := Vector2i(x, y)
			if image.get_pixelv(cell).a > 0.0 or ground_of(grid.get(cell, "")) not in FRINGED:
				continue
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var next := cell + side
				if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
					continue
				var tone := image.get_pixelv(next)
				if tone.a > KIND_MIRE and ground_of(grid.get(next, "")) == "dirt":
					image.set_pixelv(cell, Color(tone, KIND_FRINGE))
					break


## How the tint mask `image` asks a cell to be toned: "tone", "mire",
## "fringe" or "none" (KIND_*), as the shader reads its alpha.
static func tone_at(image: Image, cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height():
		return "none"
	var alpha := image.get_pixelv(cell).a
	if alpha < (KIND_FRINGE / 2.0):
		return "none"
	if alpha < (KIND_FRINGE + KIND_MIRE) / 2.0:
		return "fringe"
	return "mire" if alpha < (KIND_MIRE + KIND_TONE) / 2.0 else "tone"


## Water takes the tone of the land beside it, two cells out (PIX-247), a
## ring a call. Water is never toned itself (the shader keeps its colours),
## but the soft edge reads round each pixel, and an untoned shore thinned
## the land's tone to nothing along it.
static func tint_spill(image: Image, grid: Dictionary) -> void:
	var size := Vector2i(image.get_width(), image.get_height())
	var spilled := {}
	for cell: Vector2i in grid:
		if grid[cell] not in WATERS or image.get_pixelv(cell).a > 0.0:
			continue
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var next := cell + side
			if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and image.get_pixelv(next).a > 0.0:
				spilled[cell] = image.get_pixelv(next)
				break
	for cell: Vector2i in spilled:
		image.set_pixelv(cell, spilled[cell])


## Maps whose snow whitens the pines a few cells past their edges (PIX-309:
## where the Reach's ridge met the Frostgate's at its pass, green pines stood
## right up against the white). Past a snowfield's edge the snow reaches
## SNOW_SURE cells out for certain, and further along a ragged line, as far
## as SNOW_REACH: how far it comes wanders slowly along the edge (every
## SNOW_BENDS cells), so the white ends in drifts, not dots.
const SNOWFIELDS := ["frostgate"]
const SNOW_SURE := 2
const SNOW_REACH := 5
const SNOW_BENDS := 3.0


## Whether the snow off a snowfield whitens the pines on `cell` of `map_id`
## (a map of the Reach's plane, not a snowfield itself).
static func snows_on(map_id: String, cell: Vector2i) -> bool:
	if map_id in SNOWFIELDS or not ReachPlane.holds(map_id):
		return false
	var plane := ReachPlane.origin(map_id) + cell
	for field: String in SNOWFIELDS:
		var rect := ReachPlane.rect_of(field)
		var away := maxi(maxi(rect.position.x - plane.x, plane.x - rect.end.x + 1), maxi(rect.position.y - plane.y, plane.y - rect.end.y + 1))
		if away < 1 or away > SNOW_REACH:
			continue
		# Along the edge it faces: across a snowfield's north or south edge,
		# down its east or west.
		var along := float(plane.x if plane.x >= rect.position.x and plane.x < rect.end.x else plane.y) / SNOW_BENDS
		var at := floori(along)
		var t := along - at
		t = t * t * (3.0 - 2.0 * t)
		var bend := lerpf(_unit(at), _unit(at + 1), t)
		if away <= SNOW_SURE + floori(bend * (SNOW_REACH - SNOW_SURE + 1)):
			return true
	return false


static func _unit(at: int) -> float:
	return float(absi(hash(Vector2i(at, 169))) % 1000) / 1000.0


## The snow's tone on the pines of `map_id` near a snowfield (snows_on), a
## cell a texel as tint_map lays a region's: null when none lie near one.
static func snow_image(map_id: String, size: Vector2i) -> Image:
	if map_id in SNOWFIELDS or not ReachPlane.holds(map_id):
		return null
	var own := ReachPlane.rect_of(map_id)
	var image: Image = null
	for field: String in SNOWFIELDS:
		var near := ReachPlane.rect_of(field).grow(SNOW_REACH).intersection(own)
		for y in range(near.position.y, near.end.y):
			for x in range(near.position.x, near.end.x):
				var cell := Vector2i(x, y) - own.position
				if not snows_on(map_id, cell):
					continue
				if image == null:
					image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
					image.fill(Color(0, 0, 0, 0))
				image.set_pixelv(cell, Color(TINTS["snow"], KIND_TONE))
	return image


## Whether a region of the map tones every cell, the mountains' pines too.
static func region_toned(regions: Dictionary) -> bool:
	return regions.values().any(func(region: String) -> bool: return REGION_TINTS.has(region))


## Whether a map lies under the sky (any grass, forest, marsh, ash or sand).
static func is_outdoor(grid: Dictionary) -> bool:
	for tile: String in grid.values():
		if tile in OUTDOOR:
			return true
	return false


## The castle piece a rampart cell shows, -1 if the cell isn't one. Ramparts
## are bands of wall up to three thick: a cell whose band runs across shows
## a crenellated run, down a side run, both ways (a corner) a tower; a door
## set in a band is its gate.
static func wall_piece(grid: Dictionary, cell: Vector2i) -> int:
	var tile: String = grid.get(cell, "")
	var gate := tile == "door" or tile == "door_shut"
	if tile != "wall" and not gate:
		return -1
	var across := _run(grid, cell, Vector2i.LEFT, RAMPART) + _run(grid, cell, Vector2i.RIGHT, RAMPART) + 1
	var down := _run(grid, cell, Vector2i.UP, RAMPART) + _run(grid, cell, Vector2i.DOWN, RAMPART) + 1
	if gate:
		return GATE if across > 3 or down > 3 else -1
	if across > 3 and down > 3:
		return TOWER
	if across > 3:
		return TOWER_ACROSS if cell.x % TOWER_EVERY == 0 else WALL_ACROSS
	if down > 3:
		return WALL_DOWN
	return TOWER


## Cells of `tiles` in a row from `cell` toward `step`, up to 4.
static func _run(grid: Dictionary, cell: Vector2i, step: Vector2i, tiles: Array) -> int:
	var count := 0
	var next := cell + step
	while count < 4 and grid.get(next, "") in tiles:
		count += 1
		next += step
	return count


## Puny objects standing on our cells, -1 where none: bridges and docks as
## planks the way they span (span_axis: a single plank, or the ends and
## middles of a run) and cave mouths, every one a way on to somewhere: the
## dark mouth in the rock, bare (CAVE_MOUTH).
static func object_at(grid: Dictionary, cell: Vector2i) -> int:
	match grid.get(cell, ""):
		"bridge", "dock":
			if span_axis(grid, cell) == Vector2i.RIGHT:
				var west := _run(grid, cell, Vector2i.LEFT, SPANS) > 0
				var east := _run(grid, cell, Vector2i.RIGHT, SPANS) > 0
				if not west and not east:
					return 821
				return 876 if west and east else (875 if east else 877)
			var north := _run(grid, cell, Vector2i.UP, SPANS) > 0
			var south := _run(grid, cell, Vector2i.DOWN, SPANS) > 0
			if not north and not south:
				return 848
			return 847 if north and south else (820 if south else 874)
		"cave":
			return CAVE_MOUTH
	return -1


## Which way the planks of a bridge or dock run through `cell`:
## Vector2i.RIGHT west to east, Vector2i.DOWN north to south. A span runs
## between ground the hero walks on: the way whose two ends land wins, then
## the way with one (a dock is a pier out from its bank). The web drew a
## bridge as one sprite whatever lay round it, and its shape alone laid
## planks along a river (PIX-235); only a span landing both ways alike
## falls back on its longer side, a square one crossing the water.
static func span_axis(grid: Dictionary, cell: Vector2i) -> Vector2i:
	var lands_across := _lands(grid, cell, Vector2i.LEFT) + _lands(grid, cell, Vector2i.RIGHT)
	var lands_down := _lands(grid, cell, Vector2i.UP) + _lands(grid, cell, Vector2i.DOWN)
	if lands_across != lands_down:
		return Vector2i.RIGHT if lands_across > lands_down else Vector2i.DOWN
	var across := _run(grid, cell, Vector2i.LEFT, SPANS) + _run(grid, cell, Vector2i.RIGHT, SPANS) + 1
	var down := _run(grid, cell, Vector2i.UP, SPANS) + _run(grid, cell, Vector2i.DOWN, SPANS) + 1
	var water_runs_down: bool = (
		grid.get(cell + Vector2i.UP, "") in WATERS or grid.get(cell + Vector2i.DOWN, "") in WATERS
	)
	return Vector2i.RIGHT if across > down or (across == down and water_runs_down) else Vector2i.DOWN


## The first cell past the span through `cell`, going toward `step`.
static func span_end(grid: Dictionary, cell: Vector2i, step: Vector2i) -> Vector2i:
	var next := cell + step
	while grid.get(next, "") in SPANS:
		next += step
	return next


## 1 when the span through `cell` lands toward `step` on ground the hero
## walks on, 0 at water, a wall or the map's edge.
static func _lands(grid: Dictionary, cell: Vector2i, step: Vector2i) -> int:
	return 1 if WorldTiles.is_walkable(grid.get(span_end(grid, cell, step), "")) else 0


## A Puny tile's rectangle on the sheet, for sprites cut from it.
static func region(tile_id: int) -> Rect2:
	return sheet().region(tile_id)


## The animation frames of a tile ([] when it holds still).
static func animation(tile_id: int) -> Array:
	return sheet().animation(tile_id)


## One TileSet over the Puny sheet, its tiles created on first use.
static func tileset() -> TileSet:
	return sheet().tileset


## Sets `cell` of `layer` (built on tileset()) to Puny tile `tile_id`.
static func place(layer: TileMapLayer, cell: Vector2i, tile_id: int) -> void:
	sheet().place(layer, cell, tile_id)
