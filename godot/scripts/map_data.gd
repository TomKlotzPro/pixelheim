class_name MapData
## An ASCII map parsed into a tile grid — the Godot twin of parseMap.ts.
## Pure data, no scene nodes, so it is unit-testable headless.

var grid := {}  # Vector2i -> tile id
var size := Vector2i.ZERO
var spawn := Vector2i.ZERO

static func load_from(path: String) -> MapData:
	var data := MapData.new()
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	data.size = Vector2i(lines[0].length(), lines.size())
	data.spawn = data.size / 2
	var spawn_rank := SPAWN_UNSET
	for y in lines.size():
		for x in lines[y].length():
			var character := lines[y][x]
			data.grid[Vector2i(x, y)] = WorldTiles.tile_for_char(character)
			var rank := WorldTiles.SPAWN_CHARS.find(character)
			if rank != -1 and rank < spawn_rank:
				spawn_rank = rank
				data.spawn = Vector2i(x, y)
	return data

const SPAWN_UNSET := 99

func tile_at(cell: Vector2i) -> String:
	return grid.get(cell, "")

func is_walkable(cell: Vector2i) -> bool:
	return WorldTiles.is_walkable(tile_at(cell))
