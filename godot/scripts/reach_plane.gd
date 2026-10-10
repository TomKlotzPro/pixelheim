class_name ReachPlane
## The Reach as one plane (One Reach, PIX-269, step 3). Tom found the doors
## between maps wrong: crossing was a cut, the openings looked stuck on,
## there were too many small maps. The map files stay as they are; each map
## under the Reach's sky has its place in one plane (assets/data/plane.json):
## the Ashenreach in the middle, its six regions round its edges, each
## region's road out meeting the Reach's road in cell for cell, and no two
## maps overlapping (test_reach_plane holds it to that). What no map holds is ridge,
## the cliffs every map is rimmed with. A map keeps its own cells - saves,
## data, the fog of war and the waypoints still name them - and the plane
## only says where its cell (0, 0) lies. The next steps draw the neighbour
## beside the map the hero stands on and hand the hero over at the line,
## with no fade; until then crossing is a door that dissolves.
## The town is not in it: the Reach draws the village small inside its
## walls, and its own map is a closer look at that place, not more ground.
## Rooms and caves are other places too. Pure.

## What fills the plane where no map lies.
const RIDGE := "mountain"

static var _doc := {}
## map id -> its size in cells, read once from its map file.
static var _sizes := {}
## The maps and the cells each covers, worked out once: a line between two
## maps looks up a thousand cells at a time (Seam.stitch).
static var _maps: Array[String] = []
static var _rects: Array[Rect2i] = []


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/plane.json"))
	return _doc


## The maps in the plane, the Ashenreach first.
static func maps() -> Array[String]:
	if _maps.is_empty():
		for map_id: String in _data()["origins"]:
			_maps.append(map_id)
	return _maps.duplicate()


## Whether `map_id` has a place in the plane.
static func holds(map_id: String) -> bool:
	return _data()["origins"].has(map_id)


## Where `map_id`'s cell (0, 0) lies in the plane.
static func origin(map_id: String) -> Vector2i:
	var at: Array = _data()["origins"][map_id]
	return Vector2i(int(at[0]), int(at[1]))


## How big `map_id` is, in cells.
static func size_of(map_id: String) -> Vector2i:
	if not _sizes.has(map_id):
		_sizes[map_id] = MapData.size_by_id(map_id)
	return _sizes[map_id]


## The cells `map_id` covers in the plane.
static func rect_of(map_id: String) -> Rect2i:
	return Rect2i(origin(map_id), size_of(map_id))


## Where a cell of `map_id` lies in the plane.
static func to_plane(map_id: String, cell: Vector2i) -> Vector2i:
	return origin(map_id) + cell


## The map holding plane cell `cell` and its cell there: {"map", "cell"},
## or {} on the ridge between maps.
static func at(cell: Vector2i) -> Dictionary:
	if _rects.is_empty():
		for map_id: String in maps():
			_rects.append(rect_of(map_id))
	for i in _rects.size():
		if _rects[i].has_point(cell):
			return {"map": _maps[i], "cell": cell - _rects[i].position}
	return {}


## The tile at plane cell `cell`: the map's there, as its file has it, or
## the ridge's rock.
static func tile(cell: Vector2i) -> String:
	var there := at(cell)
	return RIDGE if there.is_empty() else MapData.tile_by_id(there["map"], there["cell"])


## What lies one `step` from `cell` of `map_id`: a cell of the same map, of
## the map beside it across its edge, or {} (the ridge).
static func beyond(map_id: String, cell: Vector2i, step: Vector2i) -> Dictionary:
	return at(to_plane(map_id, cell) + step)
