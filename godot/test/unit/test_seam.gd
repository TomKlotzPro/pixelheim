extends GutTest
## The lines between the Reach's maps (One Reach, PIX-269, steps 5 and 6):
## which map is drawn beside which, where the hero lands walking over a
## line, how often crossing saves, and the ground both maps draw along it.

var _maps := {}


func _map(map_id: String) -> MapData:
	if not _maps.has(map_id):
		_maps[map_id] = MapData.load_by_id(map_id)
	return _maps[map_id]


func test_every_road_out_leads_to_the_map_beside_it_in_the_plane() -> void:
	var roads := 0
	for map_id: String in ReachPlane.maps():
		for road: Dictionary in Seam.roads_out(_map(map_id)):
			roads += 1
			assert_eq(road["offset"], ReachPlane.origin(road["to"]) - ReachPlane.origin(map_id), "%s to %s" % [map_id, road["to"]])
			assert_eq(road["way"]["kind"], "edge")
	assert_eq(roads, 12, "the six roads out of the Ashenreach and the six back")
	for elsewhere: String in ["town", "seacave", "keep"]:
		assert_eq(Seam.roads_out(MapData.load_by_id(elsewhere)).size(), 0, "%s is behind a door" % elsewhere)


## The hand-over: one step on past a road's last cell, the hero stands on
## the map beside it, on the cell the plane puts there - the road's own -
## and the world's origin moves by exactly where that map lies.
func test_walking_over_every_road_lands_on_the_matching_cell() -> void:
	var crossed := 0
	for map_id: String in ReachPlane.maps():
		var map := _map(map_id)
		for road: Dictionary in Seam.roads_out(map):
			var way: Dictionary = road["way"]
			for cell: Vector2i in way["cells"]:
				var past: Vector2i = cell + (way["out"] as Vector2i)
				var there := Seam.across(map_id, past)
				var said := "%s %s over into %s" % [map_id, cell, road["to"]]
				assert_eq(String(there.get("map", "")), road["to"], said)
				if there.is_empty():
					continue
				crossed += 1
				var landed: Vector2i = there["cell"]
				assert_eq(landed, past - road["offset"], "%s: the world moves back by where the map lies" % said)
				assert_true(_map(road["to"]).is_walkable(landed), "%s: onto open ground (%s)" % [said, landed])
				assert_eq(String(_map(road["to"]).portals.get(landed, {}).get("mapId", "")), map_id, "%s: the road's own last cell there, leading back" % said)
				# And straight back over: where the hero stood.
				var back := Seam.across(road["to"], landed - (way["out"] as Vector2i))
				assert_eq(back, {"map": map_id, "cell": cell}, "%s: and back" % said)
	assert_eq(crossed, 36, "three cells wide, twelve roads")


func test_inside_a_map_or_off_into_the_ridge_is_no_line() -> void:
	assert_eq(Seam.across("overworld", Vector2i(48, 40)), {}, "the hero's own map")
	assert_eq(Seam.across("overworld", Vector2i(97, 26)), {}, "between Greyhold and the Deepwood is ridge")
	assert_eq(Seam.across("town", Vector2i(-1, 5)), {}, "the village isn't on the plane")


func test_near_a_road_its_map_is_drawn_and_kept_further_out() -> void:
	var road: Dictionary = Seam.roads_out(_map("overworld")).filter(func(out: Dictionary) -> bool: return out["to"] == "deepwood")[0]
	assert_true(Seam.near(Vector2i(80, 33), road["way"], Seam.NEAR), "half a screen and more from the road")
	assert_false(Seam.near(Vector2i(70, 33), road["way"], Seam.NEAR), "but not from across the Reach")
	assert_true(Seam.near(Vector2i(70, 33), road["way"], Seam.FAR), "kept while the hero is still near")
	assert_false(Seam.near(Vector2i(60, 33), road["way"], Seam.FAR))
	assert_true(Seam.FAR.x > Seam.NEAR.x and Seam.FAR.y > Seam.NEAR.y, "walking along the line doesn't draw and drop it")


func test_crossing_back_and_forth_saves_once() -> void:
	var last := -100000
	var saved := 0
	for at: int in [0, 900, 2100, 3300, 4600]:
		if Seam.saves(at, last):
			saved += 1
			last = at
	assert_eq(saved, 1, "five crossings in under five seconds, one save")
	assert_true(Seam.saves(last + Seam.SAVE_AGAIN_MS, last), "and the next crossing after that saves again")


## Along the line from the Ashenreach to Saltmere both maps draw the same
## corners, worked out from the cells on both sides; each map's ground
## carried on past its edge goes where the other lies; and where the Reach's
## ridge meets Saltmere's sea (cols 50 to 59) its cliff stands in the water,
## no strip of grass at its foot, its forest's crown stopping at the rim,
## not running into the sea.
func test_a_line_is_drawn_the_same_from_both_sides() -> void:
	var reach := _map("overworld")
	var salt := _map("saltmere")
	var grids := {"overworld": reach.grid, "saltmere": salt.grid}
	var reach_kept := KeptGround.of(reach, reach.grid, MapView.EDGE_PAD)
	var salt_kept := KeptGround.of(salt, salt.grid, MapView.EDGE_PAD)
	var from_reach := Seam.stitch("overworld", "saltmere", grids, reach_kept, MapView.EDGE_PAD)
	var from_salt := Seam.stitch("saltmere", "overworld", grids, salt_kept, MapView.EDGE_PAD)
	# [ground, crown, rim] as drawn beside the other map.
	var drawn := func(changes: Dictionary, kept: KeptGround, cell: Vector2i) -> Array:
		return changes[cell] if changes.has(cell) else [kept.ground_at(cell), kept.crown_at(cell), kept.rim_at(cell)]
	for x in range(0, 61):
		var reach_corner := Vector2i(x, 64)
		var salt_corner := Vector2i(x, 0)
		assert_eq(drawn.call(from_reach, reach_kept, reach_corner), drawn.call(from_salt, salt_kept, salt_corner), "the corner at plane (%d, 64)" % x)
	for pad in range(1, MapView.EDGE_PAD + 1):
		assert_eq(from_reach.get(Vector2i(30, 64 + pad), []), [-1, -1, -1], "the Reach's ground carried on past its edge goes where Saltmere lies")
		assert_eq(from_salt.get(Vector2i(30, -pad), []), [-1, -1, -1], "and Saltmere's where the Reach lies")
	assert_false(from_reach.has(Vector2i(80, 66)), "past the Reach's edge where no map lies, its own ground stays")
	var sea := PunyTerrain.corner_tile(["seawater-medium", "seawater-medium", "seawater-medium", "seawater-medium"], 0)
	for x in range(51, 60):
		assert_eq(reach.tile_at(Vector2i(x, 63)), "mountain")
		assert_eq(salt.tile_at(Vector2i(x, 0)) in ["shore", "sea", "deep_sea"], true, "Saltmere's sea at %d" % x)
		var line: Array = drawn.call(from_reach, reach_kept, Vector2i(x, 64))
		assert_eq(line[1], -1, "beside the sea, the cliff's rim stands bare at %d" % x)
		assert_eq(drawn.call(from_reach, reach_kept, Vector2i(x, 63))[1], -1, "and its edge row isn't crowned either")
		assert_gte(line[2], 0, "the cliff stands in the sea at %d" % x)
		assert_false(line[0] in PunyTerrain._combos()["cliff,cliff,grass,grass"], "no strip of grass at its foot at %d" % x)
	assert_ne(PunyTerrain.rimmed(["cliff", "cliff", "seawater-medium", "seawater-medium"], 0)[0], PunyTerrain.corner_tile(["cliff", "cliff", "grass", "grass"], 0))
	assert_eq(PunyTerrain.rimmed(["cliff", "cliff", "seawater-medium", "seawater-medium"], 0)[0], sea, "the sea runs on under the cliff")


## Past every edge of the Reach's maps where no map lies stands the ridge's
## rock: the ground each map draws on past its edges is what lies there (the
## map beside it, or the ridge), never its own edge carried on into the
## ridge, and it ends the way the world does inside a map, at the cliff's
## rim - where the sea or a beach meets the rock the cliff stands in it, no
## straight-edged block of water or grass at its foot.
func test_the_ground_past_every_edge_meets_the_ridge_at_its_rim() -> void:
	var terrains_of := {}
	for key: String in PunyTerrain._combos():
		for tile: int in PunyTerrain._combos()[key]:
			terrains_of[tile] = key.split(",")
	var rimmed := 0
	for map_id: String in ReachPlane.maps():
		var map := _map(map_id)
		var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
		var origin := ReachPlane.origin(map_id)
		var corners := kept.corners()
		for y in range(corners.position.y, corners.end.y):
			for x in range(corners.position.x, corners.end.x):
				var corner := Vector2i(x, y)
				var four: Array[Vector2i] = [corner + Vector2i(-1, -1), corner + Vector2i(0, -1), corner, corner + Vector2i(-1, 0)]
				if not four.any(func(cell: Vector2i) -> bool: return ReachPlane.at(origin + cell).is_empty()):
					continue
				var lie: Array = four.map(func(cell: Vector2i) -> String: return PunyTerrain.ground_of(ReachPlane.tile(origin + cell)))
				var drawn: Array = terrains_of[kept.ground_at(corner)]
				var said := "%s's corner %s by the ridge, %s" % [map_id, corner, lie]
				if lie.any(func(terrain: String) -> bool: return terrain in PunyTerrain.RIM_GROUNDS):
					rimmed += 1
					assert_gte(kept.rim_at(corner), 0, said + ": the cliff stands in it")
					assert_false("grass" in drawn and "grass" not in lie, said + ": no grass at its foot")
					assert_false("cliff" in drawn, said + ": the water runs on under it")
				else:
					assert_true("cliff" in drawn, said + ": the cliff's own rim")
					assert_eq(kept.rim_at(corner), -1, said)
	assert_gt(rimmed, 100, "Saltmere's sea meets the ridge on three sides")


func test_a_maps_masks_are_laid_out_with_its_neighbours() -> void:
	var reach := _map("overworld")
	var salt := _map("saltmere")
	var reach_kept := KeptGround.of(reach, reach.grid, MapView.EDGE_PAD)
	var salt_kept := KeptGround.of(salt, salt.grid, MapView.EDGE_PAD)
	var laid := Seam.masks_beside("saltmere", salt_kept.water_image, {"overworld": reach_kept.water_image})
	var m := Seam.MASK_MARGIN
	assert_eq(laid.get_size(), salt.size + Vector2i.ONE * 2 * m)
	assert_eq(laid.get_pixel(m + 55, m), salt_kept.water_image.get_pixel(55, 0), "its own")
	assert_eq(laid.get_pixel(m + 55, m - 1).r, 0.0, "the Reach's rock over its sea, not the sea carried on")
	assert_eq(laid.get_pixel(m - 1, m + 30).r, 0.0, "the ridge: dry, so the sea foams at its cliffs")
	assert_eq(salt_kept.water_image.get_pixel(0, 30).r, 1.0, "where Saltmere's sea meets it")
	var mirror := Seam.water_beside({"overworld": reach_kept.water_image, "saltmere": salt_kept.water_image})
	assert_eq(mirror["origin"], Vector2i.ZERO)
	assert_eq((mirror["image"] as Image).get_size(), Vector2i(96, 98), "the reflections read both, laid out in the plane")


## A region's tone reads the same on both sides of a line: Frostgate's snow
## laid out beside the Reach's ground and the Reach's beside Frostgate's
## agree cell for cell, and the Reach's pines along the line whiten as
## Frostgate's do (only there: its own keep their green).
func test_a_regions_tone_reads_the_same_across_a_line() -> void:
	var reach := _map("overworld")
	var frost := _map("frostgate")
	var reach_kept := KeptGround.of(reach, reach.grid, MapView.EDGE_PAD)
	var frost_kept := KeptGround.of(frost, frost.grid, MapView.EDGE_PAD)
	assert_true(frost_kept.crowns_toned, "under snow the pines whiten")
	assert_false(reach_kept.crowns_toned)
	var m := Seam.MASK_MARGIN
	var from_reach := Seam.masks_beside("overworld", reach_kept.tint_image, {"frostgate": frost_kept.tint_image})
	var from_frost := Seam.masks_beside("frostgate", frost_kept.tint_image, {"overworld": reach_kept.tint_image})
	var crowns_reach := Seam.masks_beside("overworld", null, {"frostgate": frost_kept.tint_image}, reach.size)
	var crowns_frost := Seam.masks_beside("frostgate", frost_kept.tint_image, {}, frost.size)
	var toned := 0
	for y in range(-m, m):
		for x in range(40 - m, 96 + m):
			var plane := Vector2i(x, y)
			var at_reach := plane - ReachPlane.origin("overworld") + Vector2i(m, m)
			var at_frost := plane - ReachPlane.origin("frostgate") + Vector2i(m, m)
			assert_eq(from_reach.get_pixelv(at_reach), from_frost.get_pixelv(at_frost), "the tone at plane %s" % plane)
			assert_eq(crowns_reach.get_pixelv(at_reach), crowns_frost.get_pixelv(at_frost), "the pines' tone at plane %s" % plane)
			if y < 0 and x >= 40 and x < 96 and crowns_reach.get_pixelv(at_reach).a > 0.0:
				toned += 1
	assert_gt(toned, 100, "Frostgate's snow, read beside the Reach")
	assert_eq(from_reach.get_pixel(m + 30, m - 1).a, 0.0, "west of Frostgate the ridge, untoned")


func test_the_ridge_is_rock_under_forest() -> void:
	var ridge := Seam.ridge_texture()
	assert_eq(ridge.get_size(), Vector2(64, 64), "four cells square, tiled")
	assert_eq(Seam.bounds_of(["overworld", "saltmere"]), Rect2i(0, 0, 96, 98))
