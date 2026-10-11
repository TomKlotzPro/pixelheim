extends GutTest
## The ways between maps (PIX-269: "it isn't clear where to walk to go
## on"). On every map a hero can stand on: each way on can be walked to from
## where the map starts you and a road runs right up to it; the map's edge
## is rock or a way on, never a strip of ground that leads nowhere, and an
## opening in it is three wide with the road running out through it; and
## through it the hero lands on open road, facing into the next map with
## open ground ahead. The way is the land itself (Tom, 2026-10-10): no
## signpost stands by it and nothing the world places closes it in.

## Every map a hero stands on: the village through its ages, the house's
## bigger drawings, the Reach, its caves and rooms.
const MAPS := [
	"overworld", "deepwood", "mirefen", "saltmere", "seacave", "blackiron", "shafts", "greyhold", "cellars",
	"frostgate", "icecave", "town", "town@2", "town@3", "town@4", "town_shop", "town_inn", "town_smith",
	"town_alchemist", "town_hall", "town_house", "town_house@2", "town_house@3", "demo", "demo_hut",
	"observatory", "keep",
]
## The ages of the village a way into it may land in.
const TOWNS := ["town", "town@2", "town@3", "town@4"]
## What a road is underfoot: where the hero arrives outdoors, and what runs
## up to a way on.
const ROADS := ["path", "stone", "bridge", "dock"]
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## A map by id: a village's age ("town@3"), a bigger house ("town_house@2").
func _load(id: String) -> MapData:
	if id.begins_with("town@"):
		return MapData.load_tiered("town", Town.projects_through(int(id.get_slice("@", 1))), 1)
	if id.begins_with("town_house@"):
		return MapData.load_tiered("town_house", [], int(id.get_slice("@", 1)))
	return MapData.load_by_id(id)


## The map as the world enters it: houses block and free their cells, a
## room's furniture blocks, and props cover their feet.
func _as_entered(id: String) -> MapData:
	var data := _load(id)
	if id.begins_with("town") and not PunyInterior.is_room(data.id):
		var houses := PunyTown.plan(data.grid)
		for cell: Vector2i in houses["pieces"]:
			if not String(data.grid[cell]).begins_with("door"):
				data.grid[cell] = "roof"
		for cell: Vector2i in houses["freed"]:
			data.grid[cell] = "grass"
	if PunyInterior.is_room(data.id):
		for cell: Vector2i in PunyInterior.plan(data.id, data.grid)["blocked"]:
			data.grid[cell] = "wall"
	if PunyTerrain.is_outdoor(data.grid):
		for prop: Dictionary in PunyProps.plan(data.grid)["props"]:
			if (prop["foot"] as Rect2).has_area():
				for cell: Vector2i in prop["covers"]:
					data.covered[cell] = true
	return data


## Every cell the hero can walk to from `from` without being taken anywhere.
func _reachable(data: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next := cell + step
			if not seen.has(next) and Ways.open_ground(data, next):
				seen[next] = true
				queue.append(next)
	return seen


func test_every_way_on_can_be_walked_to_from_where_the_map_starts_you() -> void:
	var ways := 0
	for id: String in MAPS:
		var data := _as_entered(id)
		var reached := _reachable(data, data.spawn)
		for cell: Vector2i in data.portals:
			ways += 1
			var beside := STEPS.any(func(step: Vector2i) -> bool: return reached.has(cell + step))
			assert_true(beside, "%s: the way on at %s can be walked to from the spawn" % [id, cell])
	assert_gt(ways, 40, "every map's ways on were looked at")


func test_a_road_runs_up_to_every_way_on_outdoors() -> void:
	var roads := 0
	for id: String in MAPS:
		var data := _as_entered(id)
		if Ways.indoors(data):
			continue
		for way: Dictionary in Ways.on(data):
			# The stairs up out of a cave, or down a dungeon's floors (PIX-255),
			# stand on its stone, not at a road's end.
			if way["kind"] in ["stairs", "down"]:
				continue
			roads += 1
			assert_true(data.tile_at(way["from"]) in ROADS, "%s: a road runs up to the way on at %s" % [id, way["at"]])
	assert_gt(roads, 20, "the ways on outdoors were looked at")


## As the world plans a visit (MapView.plan: camps, field scatter, props),
## nothing stands in a way on or on the road up to it, and nothing is put
## beside an opening to mark it: its mouth is the map's own ground.
func test_nothing_the_world_places_stands_at_a_way_on() -> void:
	for id: String in ["overworld", "deepwood", "mirefen", "saltmere", "blackiron", "greyhold", "frostgate", "town"]:
		var data := MapData.load_by_id(id)
		var view := MapView.new(data, null)
		view.plan(data.spawn)
		# A gate the story keeps shut (PIX-254) stands across a way on, on
		# purpose: test_gates holds it.
		var shut := {}
		for gate: Dictionary in view.gates:
			for cell: Vector2i in Gates.cells_of(gate):
				shut[cell] = true
		for way: Dictionary in view.ways:
			var cells: Array = way["cells"] + [way["from"]]
			for cell: Vector2i in cells:
				if not shut.has(cell):
					assert_false(data.covered.has(cell), "%s: nothing stands in the way on at %s" % [id, cell])
			if way["kind"] != "edge":
				continue
			# Its whole mouth, a cell deep, is the map's own ground.
			for cell: Vector2i in way["cells"]:
				var inside: Vector2i = cell - (way["out"] as Vector2i)
				if WorldTiles.is_walkable(data.tile_at(inside)) and not shut.has(inside):
					assert_false(data.covered.has(inside), "%s: the opening at %s is clear" % [id, inside])


## Ground at the edge a hero can walk to leads on. The fields beyond
## Pixelheim's rampart (PIX-248) reach the map's edge, but no walk does: the
## gate takes the hero straight out onto the Reach.
func test_the_edge_of_a_map_is_rock_or_a_way_on() -> void:
	for id: String in MAPS:
		var data := _load(id)
		var walked := Ways._walked_from(data, data.spawn)
		for cell: Vector2i in data.grid:
			var border := cell.x == 0 or cell.y == 0 or cell.x == data.size.x - 1 or cell.y == data.size.y - 1
			if border and data.is_walkable(cell) and not data.portals.has(cell):
				assert_false(walked.has(cell), "%s: %s at the edge leads on (no strip of ground going nowhere)" % [id, cell])


func test_an_opening_at_the_edge_is_wide_and_its_road_runs_out_through_it() -> void:
	var openings := 0
	for id: String in MAPS:
		var data := _load(id)
		for way: Dictionary in Ways.on(data):
			if way["kind"] != "edge":
				continue
			openings += 1
			assert_gte((way["cells"] as Array).size(), 3, "%s: the way out at %s is three wide or more" % [id, way["at"]])
			assert_eq(data.tile_at(way["at"]), "path", "%s: the road runs out through %s" % [id, way["at"]])
			# Open ground on both sides of the road, inside the opening.
			var inward: Vector2i = -(way["out"] as Vector2i)
			assert_true(Ways.open_ground(data, (way["at"] as Vector2i) + inward), "%s: the road goes on in from %s" % [id, way["at"]])
	# The Ashenreach's six (the Mirefen and Deepwood passes open in the
	# cliffs since Tom's look on 2026-10-10, no longer framed cave mouths),
	# and one back from each region beyond them.
	assert_eq(openings, 12, "the Reach's roads out")


func test_through_every_way_the_hero_lands_on_open_road_facing_into_the_map() -> void:
	var landings := 0
	for id: String in MAPS:
		var data := _load(id)
		for cell: Vector2i in data.portals:
			var target: Dictionary = data.portals[cell]
			if target["kind"] != "map":
				continue
			var into: Array = TOWNS if target["mapId"] == "town" else [target["mapId"]]
			for next_id: String in into:
				var next := _as_entered(next_id)
				var arrival := Vector2i(int(target["x"]), int(target["y"]))
				var said := "%s %s -> %s %s" % [id, cell, next_id, arrival]
				landings += 1
				assert_true(Ways.open_ground(next, arrival), "%s: lands on open ground" % said)
				if PunyTerrain.is_outdoor(next.grid):
					assert_true(next.tile_at(arrival) in ROADS, "%s: lands on the road" % said)
				var facing := Vector2i(Ways.arrival_facing(next, arrival, data.id, Vector2.DOWN))
				assert_true(Ways.open_ground(next, arrival + facing), "%s: open ground ahead, facing %s" % [said, facing])
				var back := _way_back(next, arrival, data.id)
				if back != Ways.NOWHERE:
					var ahead := Vector2(arrival + facing - back).length()
					assert_gt(ahead, Vector2(arrival - back).length(), "%s: facing away from the way back" % said)
	assert_gt(landings, 40, "every way between maps was walked through")


func test_waypoints_land_on_open_ground() -> void:
	for waypoint: Dictionary in Interactables.waypoints():
		var data := _as_entered(String(waypoint["mapId"]))
		assert_true(Ways.open_ground(data, Waypoints.landing(waypoint)), "%s lands on open ground" % waypoint["id"])


func _way_back(map: MapData, arrival: Vector2i, from_id: String) -> Vector2i:
	var back := Ways.NOWHERE
	for cell: Vector2i in map.portals:
		if String(map.portals[cell].get("mapId", "")) == from_id and (back == Ways.NOWHERE or Vector2(cell - arrival).length() < Vector2(back - arrival).length()):
			back = cell
	return back


# ---- the rules on small maps --------------------------------------------------


## A little map from rows of characters: ^ rock, . grass, = road, C a cave,
## D a door, @ a portal on the road at the edge.
func _map(rows: Array, portals := {}) -> MapData:
	var keys := {"^": "mountain", ".": "grass", "=": "path", "C": "cave", "D": "door", "#": "wall", "_": "floor"}
	var data := MapData.new()
	data.id = "test_map"
	data.size = Vector2i(String(rows[0]).length(), rows.size())
	for y in rows.size():
		for x in String(rows[y]).length():
			data.grid[Vector2i(x, y)] = keys[String(rows[y])[x]]
	data.portals = portals
	data.spawn = Vector2i(2, 2)
	return data


func test_an_opening_at_the_edge_is_one_way() -> void:
	var to := {"kind": "map", "mapId": "saltmere", "x": 30, "y": 2}
	var data := _map([
		"^^^^^^^^",
		"^^......",
		"^^......",
		"........",
		"========",
		"........",
		"^^......",
		"^^......",
		"^^^^^^^^",
	], {Vector2i(0, 4): to, Vector2i(0, 3): to, Vector2i(0, 5): to})
	var ways := Ways.on(data)
	assert_eq(ways.size(), 1, "three portals side by side to one place are one way")
	var way: Dictionary = ways[0]
	assert_eq(way["kind"], "edge")
	assert_eq(way["at"], Vector2i(0, 4), "its middle is the road")
	assert_eq(way["out"], Vector2i.LEFT, "the road leaves west")
	assert_eq(way["from"], Vector2i(1, 4), "come at along the road")
	assert_eq((way["cells"] as Array).size(), 3)


func test_a_cave_mouth_is_come_at_from_its_road() -> void:
	var data := _map([
		"^^^^^^",
		"^^C^^^",
		"..=...",
		"..=...",
		"......",
	], {Vector2i(2, 1): {"kind": "map", "mapId": "seacave", "x": 5, "y": 25}})
	var way: Dictionary = Ways.on(data)[0]
	assert_eq(way["kind"], "cave")
	assert_eq(way["out"], Vector2i.UP, "in from the road below")
	assert_eq(way["from"], Vector2i(2, 2))
	assert_false(way["rock"], "a mouth, not a gate")


func test_a_door_in_the_rock_is_a_gate() -> void:
	var data := _map([
		"^^^^^",
		"^^D^^",
		"..=..",
		".....",
	], {Vector2i(2, 1): {"kind": "map", "mapId": "vault_1", "x": 3, "y": 9, "barred": "vault"}})
	var way: Dictionary = Ways.on(data)[0]
	assert_eq(way["kind"], "gate")
	assert_true(way["rock"], "set in the rock: drawn as Shade's castle gate, barred while the story bars it")


func test_arriving_faces_away_from_the_way_back_onto_open_ground() -> void:
	var data := _map([
		"^^^^^^",
		"C=....",
		"^.....",
		"^^^^^^",
	], {Vector2i(0, 1): {"kind": "map", "mapId": "overworld", "x": 1, "y": 1}})
	assert_eq(Ways.arrival_facing(data, Vector2i(1, 1), "overworld", Vector2.LEFT), Vector2.RIGHT, "away from the cave")
	assert_eq(Ways.arrival_facing(data, Vector2i(1, 1), "town", Vector2.UP), Vector2.RIGHT, "no way back: the way walked in is rock, so any open way")
	assert_eq(Ways.arrival_facing(data, Vector2i(1, 1), "town", Vector2.DOWN), Vector2.DOWN, "no way back: the way walked in")


func test_a_save_on_ground_that_is_rock_now_wakes_on_open_ground_nearby() -> void:
	# One Reach (PIX-269): a road moved, the cliff closed over the old one.
	var data := _map([
		"^^^^^^^^",
		"^.^.....",
		"^^^.....",
		"^^^^^^^^",
	])
	data.spawn = Vector2i(5, 1)
	assert_eq(Ways.standing(data, Vector2i(5, 2)), Vector2i(5, 2), "open ground: where the save stood")
	assert_eq(Ways.standing(data, Vector2i(2, 2)), Vector2i(3, 2), "rock: the open ground beside it")
	assert_eq(Ways.standing(data, Vector2i(1, 2)), Vector2i(3, 2), "not the pocket beside it the hero couldn't leave")
	assert_eq(Ways.standing(data, Vector2i(40, 40)), data.spawn, "nothing near: the way in")


func test_a_room_door_leads_out_facing_the_room() -> void:
	var data := _map([
		"######",
		"#____#",
		"#____#",
		"##D###",
	], {Vector2i(2, 3): {"kind": "map", "mapId": "town", "x": 1, "y": 1}})
	assert_eq(Ways.arrival_facing(data, Vector2i(2, 2), "town", Vector2.UP), Vector2.UP, "into the room, away from its door")


func test_the_ground_carries_on_past_the_edge() -> void:
	# A road down the middle of a little map: drawn on past its edges (where
	# the camera looks past the south edge, under the dock), the road runs on.
	var grid := {}
	for y in 3:
		for x in 3:
			grid[Vector2i(x, y)] = "path" if x == 1 else "grass"
	assert_eq(PunyTerrain.ground_tiles(grid, Vector2i(3, 3)).size(), 16, "the map's own corners")
	var tiles := PunyTerrain.ground_tiles(grid, Vector2i(3, 3), 2)
	assert_eq(tiles.size(), 64, "two more all round")
	var road: Array = PunyTerrain._combos()["grass,dirt,dirt,grass"]
	assert_true(tiles[Vector2i(1, 5)] in road, "the road goes on below the map")
	assert_true(tiles[Vector2i(1, -2)] in road, "and above it")


func test_a_cave_mouth_is_the_rock_s_own() -> void:
	# Shade's plain mound with its dark mouth (tile 128), not the mine
	# entrance in its timber frame (127) that looked stuck on.
	assert_eq(PunyTerrain.object_at({Vector2i.ZERO: "cave"}, Vector2i.ZERO), 128, "a dark mouth in the rock, unframed")
