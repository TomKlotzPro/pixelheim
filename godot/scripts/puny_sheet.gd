class_name PunySheet
extends RefCounted
## One of Shade's 16px tilesets with its Tiled tileset (.tsx): the animation
## and corner-wang tables read from the .tsx, and a TileSet over the sheet
## whose tiles are created on first use. PunyTerrain (Puny World) and
## PunyDungeon each hold one.

const TILE := 16

var path: String
var columns: int
## tile id -> [[frame tile id, seconds], ...]
var animations := {}
## wangset name -> {"tl,tr,br,bl" terrain names -> [tile ids]} (corner sets).
var corners := {}
var tileset: TileSet
## tile id -> [atlas source id, atlas coords] in tileset.
var _slots := {}


func _init(sheet_path: String, tsx_path: String, column_count: int) -> void:
	path = sheet_path
	columns = column_count
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var parser := XMLParser.new()
	if parser.open(tsx_path) != OK:
		push_error("PunySheet: cannot read %s" % tsx_path)
		return
	var tile_id := -1
	var wangset := ""
	var colors: Array[String] = []
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match parser.get_node_name():
			"tile":
				tile_id = int(parser.get_named_attribute_value("id"))
			"frame":
				var frames: Array = animations.get_or_add(tile_id, [])
				frames.append([
					int(parser.get_named_attribute_value("tileid")),
					float(parser.get_named_attribute_value("duration")) / 1000.0,
				])
			"wangset":
				wangset = parser.get_named_attribute_value("name")
				colors = []
			"wangcolor":
				colors.append(parser.get_named_attribute_value("name"))
			"wangtile":
				# Tiled's wangid runs clockwise from the top edge: top, top-right,
				# right, bottom-right, bottom, bottom-left, left, top-left.
				var ids := parser.get_named_attribute_value("wangid").split(",")
				if int(ids[1]) == 0:
					continue  # an edge set (paths), not corners
				var key := ",".join([
					colors[int(ids[7]) - 1], colors[int(ids[1]) - 1],
					colors[int(ids[3]) - 1], colors[int(ids[5]) - 1],
				])
				var tiles: Array = corners.get_or_add(wangset, {}).get_or_add(key, [])
				tiles.append(int(parser.get_named_attribute_value("tileid")))


## The frames a tile animates through, [] when it holds still.
func animation(tile_id: int) -> Array:
	return animations.get(tile_id, [])


## Sets `cell` of `layer` (built on this sheet's tileset) to `tile_id`.
func place(layer: TileMapLayer, cell: Vector2i, tile_id: int) -> void:
	var at := slot(tile_id)
	layer.set_cell(cell, at[0], at[1])


## A tile's rectangle on the sheet.
func region(tile_id: int) -> Rect2:
	return Rect2((tile_id % columns) * TILE, (tile_id / columns) * TILE, TILE, TILE)


## One tile as its own texture (for tile layers built on other sheets).
func tile_texture(tile_id: int) -> Texture2D:
	var image := (load(path) as Texture2D).get_image()
	return ImageTexture.create_from_image(image.get_region(Rect2i(region(tile_id))))


## Where a tile lives in the tileset. Frames must sit at one even stride for
## Godot to animate them (counted in whole tiles); Shade's water keeps its
## frames rows apart, so a strip can cross other tiles: a tile that doesn't fit
## an existing atlas source gets a fresh source on the same sheet. Sequences
## that loop back or pause hold their first frame.
func slot(tile_id: int) -> Array:
	if _slots.has(tile_id):
		return _slots[tile_id]
	var coords := Vector2i(tile_id % columns, tile_id / columns)
	var frames := _even_frames(tile_id)
	var count := maxi(1, frames.size())
	var layout_columns := 0
	var separation := Vector2i.ZERO
	if count > 1:
		var stride: int = frames[1][0] - frames[0][0]
		if stride >= columns:
			layout_columns = 1  # frames run down the sheet
			separation = Vector2i(0, stride / columns - 1)
		else:
			separation = Vector2i(stride - 1, 0)
	var source: TileSetAtlasSource = null
	var source_id := -1
	for i in tileset.get_source_count():
		var candidate := tileset.get_source(tileset.get_source_id(i)) as TileSetAtlasSource
		if candidate.has_room_for_tile(coords, Vector2i.ONE, layout_columns, separation, count):
			source = candidate
			source_id = tileset.get_source_id(i)
			break
	if source == null:
		source = TileSetAtlasSource.new()
		source.texture = load(path)
		source.texture_region_size = Vector2i(TILE, TILE)
		source_id = tileset.add_source(source)
	source.create_tile(coords)
	if count > 1:
		source.set_tile_animation_columns(coords, layout_columns)
		source.set_tile_animation_separation(coords, separation)
		source.set_tile_animation_frames_count(coords, count)
		for i in count:
			source.set_tile_animation_frame_duration(coords, i, frames[i][1])
	_slots[tile_id] = [source_id, coords]
	return _slots[tile_id]


## A tile's frames if they step evenly through the sheet (down a column or
## along a row, never wrapping), else none.
func _even_frames(tile_id: int) -> Array:
	var frames := animation(tile_id)
	if frames.size() < 2:
		return []
	var stride: int = frames[1][0] - frames[0][0]
	if stride <= 0 or (stride < columns and (tile_id % columns) + stride * (frames.size() - 1) >= columns):
		return []
	if stride >= columns and stride % columns != 0:
		return []
	for i in range(1, frames.size()):
		if frames[i][0] - frames[i - 1][0] != stride:
			return []
	return frames
