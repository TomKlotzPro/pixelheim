class_name KeptGround
extends RefCounted
## A map's ground as its first visit this session worked it out (One Reach,
## PIX-269, step 4): Shade's corner tiles on the dual grid, the forest's
## crowns on the ridges, the region tint and the water masks the shaders
## read, and where the map's wild patches may grow. Working those out was
## most of what entering a map cost (the Ashenreach's 60 ms of 110, the
## crowns alone 33), and none of it changes while the map doesn't: coming
## back takes it from here, and the tiles go down in one call from the
## layers the first visit filled.
## Step 5 draws the map beside the hero from the same kept rows, and works
## them out ahead a few rows a frame (`working`, on a Slicer): a cold
## Ashenreach is some sixty frames of 3 ms in the browser (PR #338), so the
## seven maps under the Reach's sky are worked out early in the session,
## long before the hero reaches an edge. The props, the village far off and
## the field's blocking scatter, the slow parts of planning a map, are kept
## the same way (props, skyline, solid).
## One per drawing of a map (a village that has grown since works its own
## out again and replaces it), a tile to an int: everything kept for the
## whole Reach, the village and its six regions is about a megabyte.

## The dual grid's first corner (`-pad`, `-pad`) and how many corners a row
## holds: corner i is `corner + Vector2i(i % width, i / width)`.
var corner := Vector2i.ZERO
var width := 0
## Shade's tile at each corner, row by row, the cliff standing on it where
## one stands in water, sand or a road (PunyTerrain.rimmed) and the crowns'
## (-1 where none).
var ground := PackedInt32Array()
var rims := PackedInt32Array()
var crowns := PackedInt32Array()
var tint_map: ImageTexture
var water_map: ImageTexture
## The masks' pixels, a cell each: a map drawn beside another reads the
## other's beside its own across the line (MapView.lay_masks).
var tint_image: Image
var water_image: Image
## Whether the region tones the pines on its ridges too (PIX-169: under
## snow), so a map beside it tones its own along the line alike.
var crowns_toned := false
## The layers as the first visit filled them (TileMapLayer.tile_map_data).
var ground_cells := PackedByteArray()
var rim_cells := PackedByteArray()
var crown_cells := PackedByteArray()
## What it was worked out from: the ground as drawn, the grid, the regions.
var _fingerprint := 0
## While it's worked out: the map, its ground as drawn, how far past its
## edges; the cells its corners read, its own and a ring round it `_ring`
## deep (`_across` a row, from (-_ring, -_ring)): each one's tile, ground
## terrain and whether the forest crowns it; and each column's water above
## the row reached.
var _data: MapData
var _look: Dictionary
var _pad := 0
var _ring := 0
var _across := 0
var _tiles := PackedStringArray()
var _terrain := PackedStringArray()
var _crowned := PackedByteArray()
var _above := PackedInt32Array()
## Whether the map lies in the Reach's plane: past its edges lies the map
## beside it there, or the ridge's rock (PIX-269). A map off the plane (the
## village, a cave) carries its own edge on past it.
var _plane := false

## How many rows of cells, or of corners, one slice works out.
const ROWS_A_SLICE := 4

## A drawing of a map (its id and variant) -> its KeptGround.
static var _kept := {}
## The same drawing -> where its patches may grow (Gathering.decks), and
## what that was worked out from.
static var _decks := {}
## The same drawing -> its props, its village far off, its blocking
## scatter: {"fingerprint", "value"} each (props, skyline, solid).
static var _props := {}
static var _skylines := {}
static var _solids := {}


## `data`'s ground as drawn (`look`: the village far off drawn in on the
## overworld), `pad` corners on past its edges: kept, or worked out now.
static func of(data: MapData, look: Dictionary, pad: int) -> KeptGround:
	var kept := kept_for(data, look, pad)
	if kept != null:
		return kept
	var slices := Slicer.new()
	kept = working(data, look, pad, slices)
	slices.finish()
	return kept


## The same, kept already; null when it isn't (or was worked out from a
## different drawing).
static func kept_for(data: MapData, look: Dictionary, pad: int) -> KeptGround:
	var kept: KeptGround = _kept.get(data.id + data.variant)
	if kept != null and kept._fingerprint == _fingerprint_of(data, look, pad):
		return kept
	return null


## The same, kept already, or worked out by `slices` a few rows at a time
## (kept once its last slice has run; the ground isn't whole before).
static func working(data: MapData, look: Dictionary, pad: int, slices: Slicer) -> KeptGround:
	var kept := kept_for(data, look, pad)
	if kept != null:
		return kept
	kept = KeptGround.new()
	kept._fingerprint = _fingerprint_of(data, look, pad)
	kept._data = data
	kept._look = look
	kept._pad = pad
	kept.corner = Vector2i(-pad, -pad)
	kept.width = data.size.x + 1 + 2 * pad
	var corner_rows := data.size.y + 1 + 2 * pad
	# The corners read the cells one past the pad; whether the forest crowns
	# those reads one more.
	kept._ring = pad + 2
	kept._across = data.size.x + 2 * kept._ring
	var ring_rows := data.size.y + 2 * kept._ring
	kept._plane = ReachPlane.holds(data.id) and data.floor_level == 0
	kept.crowns_toned = PunyTerrain.region_toned(data.regions)
	kept._tiles.resize(kept._across * ring_rows)
	kept._terrain.resize(kept._across * ring_rows)
	kept._crowned.resize(kept._across * ring_rows)
	kept.ground.resize(kept.width * corner_rows)
	kept.rims.resize(kept.width * corner_rows)
	kept.crowns.resize(kept.width * corner_rows)
	kept.tint_image = Image.create(data.size.x, data.size.y, false, Image.FORMAT_RGBA8)
	kept.tint_image.fill(Color(0, 0, 0, 0))
	kept.water_image = Image.create(data.size.x, data.size.y, false, Image.FORMAT_RG8)
	kept._above.resize(data.size.x)
	var cell_slices := ceili(data.size.y / float(ROWS_A_SLICE))
	var ring_slices := ceili(ring_rows / float(ROWS_A_SLICE))
	slices.add_each("kept_terrain", cell_slices, func(i: int) -> void: kept._terrain_rows(i * ROWS_A_SLICE))
	slices.add_each("kept_ring", ring_slices, func(i: int) -> void: kept._ring_rows(i * ROWS_A_SLICE - kept._ring))
	slices.add_each("kept_crowned", ring_slices, func(i: int) -> void: kept._crowned_rows(i * ROWS_A_SLICE - kept._ring))
	slices.add_each("kept_corners", ceili(corner_rows / float(ROWS_A_SLICE)), func(i: int) -> void: kept._corner_rows(i * ROWS_A_SLICE - pad))
	slices.add_each("kept_tint", cell_slices, func(i: int) -> void:
		PunyTerrain.tint_rows(kept.tint_image, look, data.regions, i * ROWS_A_SLICE, mini((i + 1) * ROWS_A_SLICE, data.size.y)))
	slices.add_each("kept_tint_spill", 2, func(_ring: int) -> void: PunyTerrain.tint_spill(kept.tint_image, look))
	slices.add_each("kept_water", cell_slices, func(i: int) -> void:
		PunyTerrain.water_rows(kept.water_image, look, i * ROWS_A_SLICE, mini((i + 1) * ROWS_A_SLICE, data.size.y), kept._above))
	slices.add("kept_masks", func() -> void:
		kept.tint_map = ImageTexture.create_from_image(kept.tint_image)
		kept.water_map = ImageTexture.create_from_image(kept.water_image)
		# Done: kept, and what it was worked out from let go.
		kept._data = null
		kept._look = {}
		kept._tiles = PackedStringArray()
		kept._terrain = PackedStringArray()
		kept._crowned = PackedByteArray()
		_kept[data.id + data.variant] = kept)
	return kept


static func _fingerprint_of(data: MapData, look: Dictionary, pad: int) -> int:
	return hash([look.hash() if not is_same(look, data.grid) else 0, data.grid.hash(), data.regions.hash(), data.size, pad])


## Each cell's tile and ground terrain (PunyTerrain.ground_at), rows
## [from, from + ROWS_A_SLICE) of the map's own.
func _terrain_rows(from: int) -> void:
	var size := _data.size
	for y in range(from, mini(from + ROWS_A_SLICE, size.y)):
		for x in size.x:
			var cell := Vector2i(x, y)
			var at := _index(cell)
			_tiles[at] = _look.get(cell, "")
			_terrain[at] = PunyTerrain.ground_at(_look, cell)


## The ring's cells in rows [from, from + ROWS_A_SLICE) (from -_ring): on the
## plane what lies there, the map beside this one or the ridge's rock (One
## Reach, PIX-269: the ground drawn past a map's edge is the ground there,
## a cliff where the ridge stands, not this map's edge carried on into it);
## off it, the nearest of the map's own cells.
func _ring_rows(from: int) -> void:
	var size := _data.size
	var origin := ReachPlane.origin(_data.id) if _plane else Vector2i.ZERO
	for y in range(from, mini(from + ROWS_A_SLICE, size.y + _ring)):
		for x in range(-_ring, size.x + _ring):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			var cell := Vector2i(x, y)
			var at := _index(cell)
			if _plane:
				_tiles[at] = ReachPlane.tile(origin + cell)
				_terrain[at] = PunyTerrain.ground_of(_tiles[at])
			else:
				var edge := _index(Vector2i(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1)))
				_tiles[at] = _tiles[edge]
				_terrain[at] = _terrain[edge]


## Whether the forest crowns each cell (PunyTerrain.forest_tiles: rock
## walled in by rock on all four sides), rows [from, from + ROWS_A_SLICE)
## (from -_ring). On the plane the cells past the edge are what lies there;
## off it the map's edge repeats, and a cell of the ring is crowned as the
## edge cell nearest it is.
func _crowned_rows(from: int) -> void:
	var size := _data.size
	for y in range(from, mini(from + ROWS_A_SLICE, size.y + _ring)):
		for x in range(-_ring, size.x + _ring):
			var cell := Vector2i(x, y)
			var own := x >= 0 and y >= 0 and x < size.x and y < size.y
			var looked := cell if own or _plane else Vector2i(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1))
			_crowned[_index(cell)] = 1 if _walled_in(looked) else 0


## Whether `cell` and its four neighbours are all rock (false at the ring's
## outer edge, which no corner reads).
func _walled_in(cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var near := cell + step
		if near.x < -_ring or near.y < -_ring or near.x >= _data.size.x + _ring or near.y >= _data.size.y + _ring:
			return false
		if _tiles[_index(near)] != "mountain":
			return false
	return true


## Where `cell` (of the map's, or its ring's) lies in the cell arrays.
func _index(cell: Vector2i) -> int:
	return (cell.y + _ring) * _across + cell.x + _ring


## The corner tiles of the ground, the cliffs standing in it and the
## crowns, corner rows [from, from + ROWS_A_SLICE), as PunyTerrain
## .ground_tiles and forest_tiles lay them, the ring past the edges read
## as it lies.
func _corner_rows(from: int) -> void:
	var last := _data.size.y + _pad
	var air := PunyTerrain.corner_tile(["air", "air", "air", "air"], 0)
	for y in range(from, mini(from + ROWS_A_SLICE, last + 1)):
		var up := _index(Vector2i(0, y - 1))
		var down := _index(Vector2i(0, y))
		for x in range(-_pad, _data.size.x + 1 + _pad):
			var cell := Vector2i(x, y)
			var at := (x + _pad) + (y + _pad) * width
			var tiles := PunyTerrain.rimmed([_terrain[up + x - 1], _terrain[up + x], _terrain[down + x], _terrain[down + x - 1]], hash(cell))
			ground[at] = tiles[0]
			rims[at] = tiles[1]
			var crown := PunyTerrain.corner_tile([
				"trees" if _crowned[up + x - 1] else "air", "trees" if _crowned[up + x] else "air",
				"trees" if _crowned[down + x] else "air", "trees" if _crowned[down + x - 1] else "air"], hash(cell))
			crowns[at] = -1 if crown == air else crown


## Where `data`'s wild patches may grow (Gathering.decks, read from the map
## as it loads, before anything is drawn over it): kept, or dealt now. The
## decks are only read, never changed.
static func decks(data: MapData) -> Dictionary:
	# A dungeon's floor is dealt its own patch (Delve), and drawn anew each time.
	if data.floor_level > 0:
		return Gathering.decks(data)
	var fingerprint := hash([data.grid.hash(), data.regions.hash(), data.portals.hash(), data.spawn])
	var drawing := data.id + data.variant
	var kept: Dictionary = _decks.get(drawing, {})
	if not kept.is_empty() and int(kept["fingerprint"]) == fingerprint:
		return kept["decks"]
	var dealt := Gathering.decks(data)
	_decks[drawing] = {"fingerprint": fingerprint, "decks": dealt}
	return dealt


## The same, kept already, or dealt by `slices` a few hundred cells at a
## time (kept once its last slice has run).
static func decks_working(data: MapData, slices: Slicer) -> void:
	if data.floor_level > 0:
		return
	var fingerprint := hash([data.grid.hash(), data.regions.hash(), data.portals.hash(), data.spawn])
	var kept: Dictionary = _decks.get(data.id + data.variant, {})
	if not kept.is_empty() and int(kept["fingerprint"]) == fingerprint:
		return
	var dealing := Gathering.dealing_decks(data)
	var cells: int = (dealing["cells"] as Array).size()
	slices.add_each("kept_decks", ceili(cells / float(DECK_CELLS)), func(_i: int) -> void:
		if Gathering.deal_cells(dealing, DECK_CELLS):
			_decks[data.id + data.variant] = {"fingerprint": fingerprint, "decks": Gathering.dealt_decks(dealing)})


## How many cells one slice of dealing the decks looks at.
const DECK_CELLS := 600


## The props Shade's pack stands on `data` as planned so far (PunyProps
## .compose): kept for the maps under the Reach's sky, read only.
static func props(data: MapData) -> Dictionary:
	if not ReachPlane.holds(data.id):
		return PunyProps.compose(data.grid)
	return _keep(_props, data.id + data.variant, hash([data.grid.hash(), PunyProps.available()]),
		func() -> Dictionary: return PunyProps.compose(data.grid))


## The village far off on `data` (Skyline.plan) for the town grown through
## `done`, with `ruins` still burnt: kept while the town doesn't change.
static func skyline(data: MapData, done: Array, ruins: Array) -> Dictionary:
	return _keep(_skylines, data.id + data.variant, hash([data.grid.hash(), done, ruins]),
		func() -> Dictionary: return Skyline.plan(data.grid, MapData.load_tiered("town", done, 1), ruins))


## The field decor that blocks on `data` (Scatter.solid), around the cells
## `kept` open and the props `drawn`: kept for the maps under the Reach's
## sky while those don't change, read only.
static func solid(data: MapData, kept: Dictionary, drawn: Dictionary) -> Dictionary:
	if not ReachPlane.holds(data.id):
		return Scatter.solid(data, kept, drawn)
	return _keep(_solids, data.id + data.variant, hash([data.grid.hash(), data.covered.hash(), data.portals.hash(), kept.keys(), drawn.hash()]),
		func() -> Dictionary: return Scatter.solid(data, kept, drawn))


static func _keep(store: Dictionary, drawing: String, fingerprint: int, work: Callable) -> Dictionary:
	var kept: Dictionary = store.get(drawing, {})
	if not kept.is_empty() and int(kept["fingerprint"]) == fingerprint:
		return kept["value"]
	var value: Dictionary = work.call()
	store[drawing] = {"fingerprint": fingerprint, "value": value}
	return value


## Lays the ground on `layer` (on PunyTerrain's tileset): from the first
## visit's layer when there was one, else tile by tile.
func lay_ground(layer: TileMapLayer) -> void:
	ground_cells = _lay(layer, ground, ground_cells)


func lay_rims(layer: TileMapLayer) -> void:
	rim_cells = _lay(layer, rims, rim_cells)


func lay_crowns(layer: TileMapLayer) -> void:
	crown_cells = _lay(layer, crowns, crown_cells)


## Lays one block of the ground, the cliffs standing in it and the crowns,
## corners `block` (a rect of dual cells), tile by tile: a map drawn beside
## the hero a block a slice, each block a rendering quadrant of the layers,
## drawn once.
func lay_block(ground_layer: TileMapLayer, rim_layer: TileMapLayer, crown_layer: TileMapLayer, block: Rect2i) -> void:
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			var at := (x - corner.x) + (y - corner.y) * width
			if ground[at] >= 0:
				PunyTerrain.place(ground_layer, Vector2i(x, y), ground[at])
			if rims[at] >= 0:
				PunyTerrain.place(rim_layer, Vector2i(x, y), rims[at])
			if crowns[at] >= 0:
				PunyTerrain.place(crown_layer, Vector2i(x, y), crowns[at])


## The dual grid's corners as a rect.
func corners() -> Rect2i:
	return Rect2i(corner, Vector2i(width, ground.size() / width))


## The corner tile at dual cell `cell`, -1 off the kept grid.
func ground_at(cell: Vector2i) -> int:
	return _at(ground, cell)


## The crown at dual cell `cell`, -1 where bare or off the kept grid.
func crown_at(cell: Vector2i) -> int:
	return _at(crowns, cell)


## The cliff standing in the water, sand or road at dual cell `cell`, -1 where
## none or off the kept grid.
func rim_at(cell: Vector2i) -> int:
	return _at(rims, cell)


func _at(tiles: PackedInt32Array, cell: Vector2i) -> int:
	var at := cell - corner
	if at.x < 0 or at.y < 0 or at.x >= width or at.x + at.y * width >= tiles.size():
		return -1
	return tiles[at.x + at.y * width]


func _lay(layer: TileMapLayer, tiles: PackedInt32Array, laid: PackedByteArray) -> PackedByteArray:
	if not laid.is_empty():
		layer.tile_map_data = laid
		return laid
	for i in tiles.size():
		if tiles[i] >= 0:
			PunyTerrain.place(layer, corner + Vector2i(i % width, i / width), tiles[i])
	return layer.tile_map_data


## What the session keeps, in bytes: the tiles, the layers' cells, the masks'
## pixels and the decks' cells (a Vector2i in an Array is about 24 bytes).
static func bytes() -> int:
	var total := 0
	for drawing: String in _kept:
		var kept: KeptGround = _kept[drawing]
		total += (kept.ground.size() + kept.rims.size() + kept.crowns.size()) * 4
		total += kept.ground_cells.size() + kept.rim_cells.size() + kept.crown_cells.size()
		# Eight bits a channel: the tint's four, the water's two, each once
		# as an image and once as a texture.
		total += 2 * (kept.tint_image.get_width() * kept.tint_image.get_height() * 4 + kept.water_image.get_width() * kept.water_image.get_height() * 2)
	for drawing: String in _decks:
		for deck: Array in (_decks[drawing]["decks"] as Dictionary).values():
			total += deck.size() * 24
	return total


## Whether `data`'s ground as drawn is kept (worked out ahead, PIX-269).
static func has(data: MapData, look: Dictionary, pad: int) -> bool:
	return kept_for(data, look, pad) != null


## Lets everything go (a test's clean slate).
static func forget() -> void:
	_kept.clear()
	_decks.clear()
	_props.clear()
	_skylines.clear()
	_solids.clear()
