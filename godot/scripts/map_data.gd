class_name MapData
## A world map loaded from the JSON the web game exports (pnpm godot:sync).
## Tiles arrive as tile ids already parsed and validated by src/world/maps —
## Godot never re-parses ASCII. Pure data, no scene nodes, unit-testable.

var id := ""
var grid := {}  # Vector2i -> tile id
var size := Vector2i.ZERO
var spawn := Vector2i.ZERO
var portals := {}  # Vector2i -> target Dictionary ({kind, ...})


static func load_by_id(map_id: String) -> MapData:
	return load_from("res://assets/maps/%s.json" % map_id)


## The map as the town has grown: the village redraws per town tier and the
## house per house tier (getMap's mirrors); tier variants export as id@tier.
static func load_tiered(map_id: String, town_tier: int, house_tier: int) -> MapData:
	var tier := town_tier if map_id == "town" else (house_tier if map_id == "town_house" else 1)
	if tier <= 1:
		return load_by_id(map_id)
	var data := load_from("res://assets/maps/%s@%d.json" % [map_id, tier])
	data.id = map_id
	return data


static func load_from(path: String) -> MapData:
	var data := MapData.new()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data.id = doc["id"]
	data.size = Vector2i(int(doc["width"]), int(doc["height"]))
	data.spawn = Vector2i(int(doc["spawn"]["x"]), int(doc["spawn"]["y"]))
	var tiles: Array = doc["tiles"]
	for y in tiles.size():
		var row: Array = tiles[y]
		for x in row.size():
			data.grid[Vector2i(x, y)] = row[x]
	for portal: Dictionary in doc["portals"]:
		data.portals[Vector2i(int(portal["x"]), int(portal["y"]))] = portal["to"]
	return data


func tile_at(cell: Vector2i) -> String:
	return grid.get(cell, "")


func is_walkable(cell: Vector2i) -> bool:
	return WorldTiles.is_walkable(tile_at(cell))
