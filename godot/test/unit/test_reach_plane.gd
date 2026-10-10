extends GutTest
## The Reach as one plane (One Reach, PIX-269, step 3): the Ashenreach and
## its six regions each have a place in it, no two overlap, and wherever a
## map's edge meets another's the two agree cell for cell: a road out of
## one runs on into the other's road, a cliff faces a cliff (or the ridge
## between maps), and nothing walks off one map into rock or into nothing.
## Crossing is still a door until the neighbour is drawn beside the hero
## (steps 5 and 6), so each door lands where the plane says it should: on
## the road just past the line.

## Roads underfoot, as the ways between maps know them.
const ROADS := ["path", "stone", "bridge", "dock"]
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## How far past the line a door may set the hero down.
const LANDING := 3

var _maps := {}


func _map(map_id: String) -> MapData:
	if not _maps.has(map_id):
		_maps[map_id] = MapData.load_by_id(map_id)
	return _maps[map_id]


## The cells along `map`'s edge on `side`, each with the step across it.
func _edge(map: MapData, side: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in map.grid:
		var outside := cell + side
		if outside.x < 0 or outside.y < 0 or outside.x >= map.size.x or outside.y >= map.size.y:
			out.append(cell)
	return out


func test_the_reach_and_its_six_regions_are_in_it() -> void:
	var maps := ReachPlane.maps()
	assert_eq(maps[0], "overworld", "the Ashenreach first")
	for region: String in ["saltmere", "mirefen", "blackiron", "frostgate", "greyhold", "deepwood"]:
		assert_true(ReachPlane.holds(region), "%s has its place" % region)
	assert_eq(ReachPlane.origin("overworld"), Vector2i.ZERO, "the plane is the Ashenreach's own cells")
	for elsewhere: String in ["town", "seacave", "shafts", "cellars", "icecave", "keep", "observatory", "town_inn"]:
		assert_false(ReachPlane.holds(elsewhere), "%s is a place of its own, behind a door" % elsewhere)


func test_no_two_maps_overlap() -> void:
	var maps := ReachPlane.maps()
	for i in maps.size():
		assert_eq(ReachPlane.rect_of(maps[i]).size, _map(maps[i]).size, "%s's place is its size" % maps[i])
		for j in range(i + 1, maps.size()):
			var a := ReachPlane.rect_of(maps[i])
			var b := ReachPlane.rect_of(maps[j])
			assert_false(a.intersects(b), "%s %s and %s %s don't overlap" % [maps[i], a, maps[j], b])


func test_every_edge_meets_its_neighbour_cell_for_cell() -> void:
	var crossings := {}
	for map_id: String in ReachPlane.maps():
		var map := _map(map_id)
		for side: Vector2i in SIDES:
			for cell: Vector2i in _edge(map, side):
				var across := ReachPlane.beyond(map_id, cell, side)
				var said := "%s %s, across to the %s" % [map_id, cell, side]
				if not map.is_walkable(cell):
					# Rock against rock, or against the ridge between maps.
					if not across.is_empty():
						assert_false(_map(across["map"]).is_walkable(across["cell"]), "%s: a cliff faces a cliff (%s %s)" % [said, across["map"], across["cell"]])
					continue
				# Open ground at the edge: the way on, into the map beside it.
				assert_false(across.is_empty(), "%s: open ground runs on into a map, not the ridge" % said)
				if across.is_empty():
					continue
				var next := _map(across["map"])
				var there: Vector2i = across["cell"]
				assert_true(next.is_walkable(there), "%s: walks on into %s %s" % [said, next.id, there])
				assert_eq(map.tile_at(cell) in ROADS, next.tile_at(there) in ROADS, "%s: road meets road (%s, %s)" % [said, map.tile_at(cell), next.tile_at(there)])
				crossings["%s>%s" % [map_id, next.id]] = true
				assert_eq(String(map.portals.get(cell, {}).get("mapId", "")), next.id, "%s: its door leads to %s" % [said, next.id])
				assert_eq(String(next.portals.get(there, {}).get("mapId", "")), map_id, "%s: and %s %s leads back" % [said, next.id, there])
	# The six roads out of the Ashenreach and the six back in.
	assert_eq(crossings.size(), 12, "every road out meets one coming in")


func test_a_door_sets_the_hero_down_just_past_the_line() -> void:
	var doors := 0
	for map_id: String in ReachPlane.maps():
		var map := _map(map_id)
		for way: Dictionary in Ways.on(map):
			if way["kind"] != "edge":
				continue
			var target: Dictionary = way["to"]
			var across := ReachPlane.beyond(map_id, way["at"], way["out"])
			assert_eq(String(across.get("map", "")), String(target["mapId"]), "%s %s: the plane puts %s beyond it" % [map_id, way["at"], target["mapId"]])
			if across.is_empty():
				continue
			doors += 1
			var landing := Vector2i(int(target["x"]), int(target["y"]))
			var from: Vector2i = across["cell"]
			var off := maxi(absi(landing.x - from.x), absi(landing.y - from.y))
			assert_lte(off, LANDING, "%s %s -> %s %s: lands %d from where the road crosses (%s)" % [map_id, way["at"], target["mapId"], landing, off, from])
	assert_eq(doors, 12, "each road out and back")


## The roads out the regions had before they moved along their edges, the
## cliff closed over them now.
const OLD_WAYS := {
	"blackiron": [Vector2i(55, 17), Vector2i(55, 18), Vector2i(54, 19), Vector2i(55, 20)],
	"mirefen": [Vector2i(59, 24), Vector2i(58, 25), Vector2i(59, 26)],
	"deepwood": [Vector2i(0, 24), Vector2i(1, 25), Vector2i(0, 26)],
	"saltmere": [Vector2i(29, 0), Vector2i(30, 0), Vector2i(31, 1), Vector2i(32, 0)],
	"frostgate": [Vector2i(26, 47), Vector2i(26, 46)],
}


func test_a_hero_saved_on_an_old_road_out_wakes_on_open_ground_beside_it() -> void:
	for map_id: String in OLD_WAYS:
		var map := _map(map_id)
		for cell: Vector2i in OLD_WAYS[map_id]:
			assert_false(Ways.open_ground(map, cell), "%s %s is the cliff now" % [map_id, cell])
			var woke := Ways.standing(map, cell)
			assert_true(Ways.open_ground(map, woke), "%s %s: wakes on open ground (%s)" % [map_id, cell, woke])
			assert_lte(maxi(absi(woke.x - cell.x), absi(woke.y - cell.y)), 3, "%s %s: beside where the save stood (%s)" % [map_id, cell, woke])


func test_a_cell_of_the_plane_is_one_map_s_or_the_ridge() -> void:
	assert_eq(ReachPlane.at(Vector2i(48, 40)), {"map": "overworld", "cell": Vector2i(48, 40)})
	var west := ReachPlane.beyond("overworld", Vector2i(0, 20), Vector2i.LEFT)
	assert_eq(west["map"], "blackiron", "west of the Reach's road to the mines lie the mines")
	assert_eq(ReachPlane.to_plane(west["map"], west["cell"]), Vector2i(-1, 20))
	assert_eq(ReachPlane.at(Vector2i(-200, -200)), {}, "far out is ridge")
