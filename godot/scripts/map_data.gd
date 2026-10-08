class_name MapData
## A world map loaded from the JSON the web game exports (pnpm godot:sync).
## Tiles arrive as tile ids already parsed and validated by src/world/maps —
## Godot never re-parses ASCII. Pure data, no scene nodes, unit-testable.

var id := ""
var grid := {}  # Vector2i -> tile id
var size := Vector2i.ZERO
var spawn := Vector2i.ZERO
var portals := {}  # Vector2i -> target Dictionary ({kind, ...})
var regions := {}  # Vector2i -> encounter region id (forest, marsh, ash, ...)
## A dungeon floor's number (DungeonFloor); 0 for the web's own maps.
var floor_level := 0
## Cells something drawn stands on although the web's tile is open ground
## (a fountain's basin, a well's second half, a statue): they block too.
var covered := {}
## Which drawing of the map this is: "@2", "@3" for the bigger houses.
var variant := ""
## How a map is drawn when it isn't the open air: "cave" draws it in dungeon
## stone (the sea cave, PIX-165).
var style := ""
## A cast over the whole map's ground (the ice cave's frost, PIX-169).
var tint := Color.WHITE


static func load_by_id(map_id: String) -> MapData:
	return load_from("res://assets/maps/%s.json" % map_id)


## The map as the town has grown: the village is its base map with every
## finished project's cells laid over it (PIX-145), the house redraws per
## house tier (its variants export as town_house@tier).
static func load_tiered(map_id: String, projects: Array, house_tier: int) -> MapData:
	if map_id == "town":
		var town := load_by_id(map_id)
		var patches := Town.town_patches(projects)
		for cell: Vector2i in patches:
			town.grid[cell] = patches[cell]
		# A burnt house has no way in (PIX-146).
		for ruin: Dictionary in Town.ruins(projects):
			town.portals.erase(ruin["door"])
		return town
	if map_id != "town_house" or house_tier <= 1:
		return load_by_id(map_id)
	var data := load_from("res://assets/maps/%s@%d.json" % [map_id, house_tier])
	data.id = map_id
	data.variant = "@%d" % house_tier
	return data


static func load_from(path: String) -> MapData:
	var data := MapData.new()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data.id = doc["id"]
	data.size = Vector2i(int(doc["width"]), int(doc["height"]))
	data.spawn = Vector2i(int(doc["spawn"]["x"]), int(doc["spawn"]["y"]))
	data.style = String(doc.get("style", ""))
	if doc.has("tint"):
		var tint: Array = doc["tint"]
		data.tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var tiles: Array = doc["tiles"]
	for y in tiles.size():
		var row: Array = tiles[y]
		for x in row.size():
			data.grid[Vector2i(x, y)] = row[x]
	for portal: Dictionary in doc["portals"]:
		data.portals[Vector2i(int(portal["x"]), int(portal["y"]))] = portal["to"]
	var region_rows: Array = doc.get("regions", [])
	for y in region_rows.size():
		var row: Array = region_rows[y]
		for x in row.size():
			if row[x] != null:
				data.regions[Vector2i(x, y)] = row[x]
	return data


func tile_at(cell: Vector2i) -> String:
	return grid.get(cell, "")


## Where monsters lurk and which kind (regionAt); "" on safe ground.
func region_at(cell: Vector2i) -> String:
	return regions.get(cell, "")


func is_walkable(cell: Vector2i) -> bool:
	return WorldTiles.is_walkable(tile_at(cell)) and not covered.has(cell)
