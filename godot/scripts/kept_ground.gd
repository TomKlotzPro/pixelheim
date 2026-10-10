class_name KeptGround
extends RefCounted
## A map's ground as its first visit this session worked it out (One Reach,
## PIX-269, step 4): Shade's corner tiles on the dual grid, the forest's
## crowns on the ridges, the region tint and the water masks the shaders
## read, and where the map's wild patches may grow. Working those out was
## most of what entering a map cost (the Ashenreach's 60 ms of 110, the
## crowns alone 33), and none of it changes while the map doesn't: coming
## back takes it from here, and the tiles go down in one call from the
## layers the first visit filled. The next step builds the map beside the
## hero a strip at a time from the same kept rows.
## One per drawing of a map (a village that has grown since works its own
## out again and replaces it), a tile to an int: everything kept for the
## whole Reach is well under a megabyte.

## The dual grid's first corner (`-pad`, `-pad`) and how many corners a row
## holds: corner i is `corner + Vector2i(i % width, i / width)`.
var corner := Vector2i.ZERO
var width := 0
## Shade's tile at each corner, row by row, and the crowns' (-1 where bare).
var ground := PackedInt32Array()
var crowns := PackedInt32Array()
var tint_map: ImageTexture
var water_map: ImageTexture
## The layers as the first visit filled them (TileMapLayer.tile_map_data).
var ground_cells := PackedByteArray()
var crown_cells := PackedByteArray()
## What it was worked out from: the ground as drawn, the grid, the regions.
var _fingerprint := 0

## A drawing of a map (its id and variant) -> its KeptGround.
static var _kept := {}
## The same drawing -> where its patches may grow (Gathering.decks), and
## what that was worked out from.
static var _decks := {}


## `data`'s ground as drawn (`look`: the village far off drawn in on the
## overworld), `pad` corners on past its edges: kept, or worked out now.
static func of(data: MapData, look: Dictionary, pad: int) -> KeptGround:
	var fingerprint := hash([look.hash() if not is_same(look, data.grid) else 0, data.grid.hash(), data.regions.hash(), data.size, pad])
	var drawing := data.id + data.variant
	var kept: KeptGround = _kept.get(drawing)
	if kept != null and kept._fingerprint == fingerprint:
		return kept
	kept = KeptGround.new()
	kept._fingerprint = fingerprint
	kept.corner = Vector2i(-pad, -pad)
	kept.width = data.size.x + 1 + 2 * pad
	var rows := data.size.y + 1 + 2 * pad
	kept.ground = kept._packed(PunyTerrain.ground_tiles(look, data.size, pad), rows)
	kept.crowns = kept._packed(PunyTerrain.forest_tiles(data.grid, data.size, pad), rows)
	kept.tint_map = PunyTerrain.tint_map(look, data.size, data.regions)
	kept.water_map = PunyTerrain.water_map(look, data.size)
	_kept[drawing] = kept
	return kept


## Where `data`'s wild patches may grow (Gathering.decks, read from the map
## as it loads, before anything is drawn over it): kept, or dealt now. The
## decks are only read, never changed.
static func decks(data: MapData) -> Dictionary:
	var fingerprint := hash([data.grid.hash(), data.regions.hash(), data.portals.hash(), data.spawn])
	var drawing := data.id + data.variant
	var kept: Dictionary = _decks.get(drawing, {})
	if not kept.is_empty() and int(kept["fingerprint"]) == fingerprint:
		return kept["decks"]
	var dealt := Gathering.decks(data)
	_decks[drawing] = {"fingerprint": fingerprint, "decks": dealt}
	return dealt


## Lays the ground on `layer` (on PunyTerrain's tileset): from the first
## visit's layer when there was one, else tile by tile.
func lay_ground(layer: TileMapLayer) -> void:
	ground_cells = _lay(layer, ground, ground_cells)


func lay_crowns(layer: TileMapLayer) -> void:
	crown_cells = _lay(layer, crowns, crown_cells)


## The corner tile at dual cell `cell`, -1 off the kept grid.
func ground_at(cell: Vector2i) -> int:
	var at := cell - corner
	if at.x < 0 or at.y < 0 or at.x >= width or at.x + at.y * width >= ground.size():
		return -1
	return ground[at.x + at.y * width]


func _lay(layer: TileMapLayer, tiles: PackedInt32Array, laid: PackedByteArray) -> PackedByteArray:
	if not laid.is_empty():
		layer.tile_map_data = laid
		return laid
	for i in tiles.size():
		if tiles[i] >= 0:
			PunyTerrain.place(layer, corner + Vector2i(i % width, i / width), tiles[i])
	return layer.tile_map_data


func _packed(tiles: Dictionary, rows: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(width * rows)
	out.fill(-1)
	for cell: Vector2i in tiles:
		var at: Vector2i = cell - corner
		out[at.x + at.y * width] = tiles[cell]
	return out


## What the session keeps, in bytes: the tiles, the layers' cells, the masks'
## pixels and the decks' cells (a Vector2i in an Array is about 24 bytes).
static func bytes() -> int:
	var total := 0
	for drawing: String in _kept:
		var kept: KeptGround = _kept[drawing]
		total += (kept.ground.size() + kept.crowns.size()) * 4 + kept.ground_cells.size() + kept.crown_cells.size()
		# Eight bits a channel: the tint's four, the water's two.
		total += kept.tint_map.get_width() * kept.tint_map.get_height() * 4 + kept.water_map.get_width() * kept.water_map.get_height() * 2
	for drawing: String in _decks:
		for deck: Array in (_decks[drawing]["decks"] as Dictionary).values():
			total += deck.size() * 24
	return total


## Lets everything go (a test's clean slate).
static func forget() -> void:
	_kept.clear()
	_decks.clear()
