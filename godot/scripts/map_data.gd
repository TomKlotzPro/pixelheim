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
## A region dungeon's floor (PIX-255): its own dark under the ground (alpha
## 0: the usual), what the dungeon sheet draws over a cell (a wreck's beams,
## a door in the rock: cell -> tile), and the words E reads facing a cell.
var light := Color(0, 0, 0, 0)
var pieces := {}
var notes := {}


## A map by its id: its JSON, or a region dungeon's planned floor laid out
## (PIX-255); a floor of a dungeon dressed with its stairs (Depths).
static func load_by_id(map_id: String) -> MapData:
	if Depths.is_planned(map_id):
		return Depths.dress(Depths.generate(map_id))
	return Depths.dress(load_from("res://assets/maps/%s.json" % map_id))


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


## Each map file as parsed, once a session (One Reach, PIX-269): the maps
## under the Reach's sky are loaded again each time one is drawn beside the
## hero, and parsing the Ashenreach's file was most of its load. Only read.
static var _docs := {}


static func load_from(path: String) -> MapData:
	var data := MapData.new()
	var doc := _doc(path)
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
		data.portals[Vector2i(int(portal["x"]), int(portal["y"]))] = (portal["to"] as Dictionary).duplicate(true)
	var region_rows: Array = doc.get("regions", [])
	for y in region_rows.size():
		var row: Array = region_rows[y]
		for x in row.size():
			if row[x] != null:
				data.regions[Vector2i(x, y)] = row[x]
	return data


## A map file, parsed once a session.
static func _doc(path: String) -> Dictionary:
	if not _docs.has(path):
		_docs[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _docs[path]


## How big map `map_id` is, read from its file without building it.
static func size_by_id(map_id: String) -> Vector2i:
	var doc := _doc("res://assets/maps/%s.json" % map_id)
	return Vector2i(int(doc["width"]), int(doc["height"]))


## The tile at `cell` of map `map_id` as its file has it, without building
## the map: what a map under the Reach's sky draws past its edges where the
## map beside it lies (KeptGround, PIX-269). "" off the map.
static func tile_by_id(map_id: String, cell: Vector2i) -> String:
	var tiles: Array = _doc("res://assets/maps/%s.json" % map_id)["tiles"]
	if cell.y < 0 or cell.y >= tiles.size() or cell.x < 0 or cell.x >= (tiles[cell.y] as Array).size():
		return ""
	return tiles[cell.y][cell.x]


## Whether `cells` already run row by row, west to east (a map's grid and
## regions are read from its file that way): sorting them through a script
## comparison was most of what planning the Reach's props and patches cost,
## a slice of drawing the map beside the hero (PIX-269).
static func in_rows(cells: Array) -> bool:
	for i in range(1, cells.size()):
		var a: Vector2i = cells[i - 1]
		var b: Vector2i = cells[i]
		if a.y > b.y or (a.y == b.y and a.x >= b.x):
			return false
	return true


func tile_at(cell: Vector2i) -> String:
	return grid.get(cell, "")


## Where monsters lurk and which kind (regionAt); "" on safe ground.
func region_at(cell: Vector2i) -> String:
	return regions.get(cell, "")


func is_walkable(cell: Vector2i) -> bool:
	return WorldTiles.is_walkable(tile_at(cell)) and not covered.has(cell)
