extends GutTest
## A country road's ends and turns (PIX-404): the mask the ground's shader
## draws them from. A lane narrows over its last two cells where it ends in
## the open, and runs on whole into a door, water, stone or the map beside;
## on Shade's grass the ground is drawn again round an end or a turn, and a
## turn's inside may fill; on the ash the tone alone follows the road; a
## paved street and the grid never change.


## A meadow (or `ground`) with `roads` in it, 12 cells square.
func _field(roads: Array, ground := "grass") -> Dictionary:
	var grid := {}
	for y in 12:
		for x in 12:
			grid[Vector2i(x, y)] = ground
	for cell: Vector2i in roads:
		grid[cell] = "path"
	return grid


## Past the field's edges, more of the same ground; and west of it the
## road's `rows` running on.
func _past(ground := "grass", rows := []) -> Callable:
	return func(cell: Vector2i) -> String: return "path" if cell.x < 0 and cell.y in rows else ground


## Cells from `from` to `to`, both included.
func _rect(from: Vector2i, to: Vector2i) -> Array:
	var cells := []
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func _texel(image: Image, cell: Vector2i) -> Color:
	return image.get_pixelv(cell + Vector2i.ONE * RoadShape.RING)


func test_a_road_narrows_over_its_last_two_cells_where_it_ends_in_the_open() -> void:
	var grid := _field(_rect(Vector2i(0, 4), Vector2i(7, 5)))
	var before := grid.duplicate()
	var image := RoadShape.image_of(grid, _past("grass", [4, 5]), Vector2i(12, 12))
	for y in [4, 5]:
		assert_almost_eq(_texel(image, Vector2i(7, y)).r, 0.45, 0.01, "its last cell, both lanes")
		assert_almost_eq(_texel(image, Vector2i(6, y)).r, 0.8, 0.01, "the one before")
		assert_almost_eq(_texel(image, Vector2i(5, y)).r, 1.0, 0.01, "whole further back")
		assert_eq(_texel(image, Vector2i(0, y)).r, 1.0, "and where it runs on off the map")
	assert_eq(_texel(image, Vector2i(8, 4)).r, 0.0, "the meadow past it is no road")
	assert_eq(grid, before, "the grid is never touched")
	# A one-cell path's end, round already, barely gives; a three-wide road's
	# narrows most.
	var path := RoadShape.image_of(_field(_rect(Vector2i(0, 4), Vector2i(7, 4))), _past("grass", [4]), Vector2i(12, 12))
	assert_almost_eq(_texel(path, Vector2i(7, 4)).r, 0.8, 0.01)
	assert_almost_eq(_texel(path, Vector2i(6, 4)).r, 1.0, 0.01)
	var wide := RoadShape.image_of(_field(_rect(Vector2i(0, 4), Vector2i(7, 6))), _past("grass", [4, 5, 6]), Vector2i(12, 12))
	assert_almost_eq(_texel(wide, Vector2i(7, 5)).r, 0.4, 0.01)


func test_a_road_into_a_door_water_stone_or_the_map_beside_runs_on_whole() -> void:
	for end: String in ["door", "water", "stone", "bridge", "mountain"]:
		var grid := _field(_rect(Vector2i(0, 4), Vector2i(7, 5)))
		grid[Vector2i(8, 4)] = end
		grid[Vector2i(8, 5)] = end
		var image := RoadShape.image_of(grid, _past("grass", [4, 5]), Vector2i(12, 12))
		assert_eq(_texel(image, Vector2i(7, 4)).r, 1.0, "a road up to %s runs on" % end)
	# Off the map's edge the plane's road runs on: no end at the line.
	var off := RoadShape.image_of(_field(_rect(Vector2i(4, 4), Vector2i(11, 5))), func(cell: Vector2i) -> String:
		return "path" if cell.x >= 12 and (cell.y == 4 or cell.y == 5) else "grass", Vector2i(12, 12))
	assert_eq(_texel(off, Vector2i(11, 4)).r, 1.0, "the road runs on into the map beside")
	assert_almost_eq(_texel(off, Vector2i(4, 4)).r, 0.45, 0.01, "and ends in the meadow at its other end")
	assert_eq(_texel(off, Vector2i(13, 4)).r, 1.0, "the mask reaches past the edge, where the road goes on")


## Blackiron's lower road: a lane that ends beside one running on narrows the
## road into it; the other runs on whole, not pinched.
func test_a_lane_ending_beside_one_running_on_narrows_into_it() -> void:
	var grid := _field(_rect(Vector2i(0, 4), Vector2i(11, 4)) + _rect(Vector2i(0, 5), Vector2i(5, 5)))
	var image := RoadShape.image_of(grid, _past("grass", [4, 5]), Vector2i(12, 12))
	assert_almost_eq(_texel(image, Vector2i(5, 5)).r, 0.45, 0.01, "the lane that ends")
	assert_almost_eq(_texel(image, Vector2i(4, 5)).r, 0.8, 0.01)
	for x in range(0, 10):
		assert_eq(_texel(image, Vector2i(x, 4)).r, 1.0, "the lane running on, at %d" % x)


## An L on grass: drawn again round the turn, its inside corner free to fill;
## a straight edge far from any turn or end keeps Shade's own.
func test_a_turn_on_grass_is_drawn_again_and_fills_inside() -> void:
	var grid := _field(_rect(Vector2i(0, 2), Vector2i(7, 3)) + _rect(Vector2i(6, 4), Vector2i(7, 11)))
	var image := RoadShape.image_of(grid, _past("grass", [2, 3]), Vector2i(12, 12))
	assert_eq(_texel(image, Vector2i(5, 4)).b, RoadShape.FILLS, "the grass inside the turn may fill")
	assert_almost_eq(_texel(image, Vector2i(8, 1)).b, RoadShape.ZONE, 0.01, "the grass round its outside is drawn again")
	assert_almost_eq(_texel(image, Vector2i(7, 2)).b, RoadShape.ZONE, 0.01, "and the road's corner")
	assert_eq(_texel(image, Vector2i(1, 2)).b, 0.0, "a straight edge away from the turn keeps Shade's")
	assert_eq(_texel(image, Vector2i(1, 1)).b, 0.0)


## The Reach's long roads wander wider (PIX-397, RoadShape.WANDERS): on
## Shade's grass a straight edge far from any turn is drawn again too, the
## grass beside it free to take the road as it wanders out; on the ash the
## tone alone still.
func test_where_roads_wander_a_straight_edge_on_grass_is_drawn_again() -> void:
	var road := _rect(Vector2i(0, 4), Vector2i(11, 5))
	var image := RoadShape.image_of(_field(road), _past("grass", [4, 5]), Vector2i(12, 12), {}, true)
	for x in [1, 5, 9]:
		assert_almost_eq(_texel(image, Vector2i(x, 4)).b, RoadShape.ZONE, 0.01, "the road's edge at %d" % x)
		assert_eq(_texel(image, Vector2i(x, 3)).b, RoadShape.FILLS, "the grass above it at %d" % x)
		assert_eq(_texel(image, Vector2i(x, 6)).b, RoadShape.FILLS, "and below")
	var ash := RoadShape.image_of(_field(road, "ash"), _past("ash", [4, 5]), Vector2i(12, 12), {}, true)
	assert_eq(_texel(ash, Vector2i(5, 3)).b, 0.0, "on the ash nothing is drawn again")


func test_grass_between_two_roads_never_fills() -> void:
	for wanders: bool in [false, true]:
		_never_fills_between(wanders)


func _never_fills_between(wanders: bool) -> void:
	var grid := _field(_rect(Vector2i(2, 3), Vector2i(7, 3)) + _rect(Vector2i(4, 5), Vector2i(9, 5)))
	var image := RoadShape.image_of(grid, _past(), Vector2i(12, 12), {}, wanders)
	for x in range(4, 8):
		assert_ne(_texel(image, Vector2i(x, 4)).b, RoadShape.FILLS, "the strip at %d stays grass" % x)


## On the ash (Shade's dirt, as the road is) the ground isn't drawn again:
## the tone follows the road where it meets the ash.
func test_on_the_ash_the_tone_alone_follows_the_road() -> void:
	var grid := _field(_rect(Vector2i(0, 4), Vector2i(7, 5)), "ash")
	var image := RoadShape.image_of(grid, _past("ash"), Vector2i(12, 12))
	assert_almost_eq(_texel(image, Vector2i(7, 4)).r, 0.45, 0.01, "it narrows as on grass")
	for cell: Vector2i in [Vector2i(7, 4), Vector2i(8, 4), Vector2i(3, 6), Vector2i(3, 3)]:
		assert_eq(_texel(image, cell).b, 0.0, "no ground drawn again at %s" % cell)
		assert_eq(_texel(image, cell).a, 1.0, "the tone follows the road at %s" % cell)
	assert_eq(_texel(image, Vector2i(3, 8)).a, 0.0, "away from it the tone is the cell's")
	assert_eq(_texel(image, Vector2i(3, 8)).g, 1.0, "open ground")


## Greyhold's sand cross through its courtyard (PIX-399's): a road meeting
## stone keeps its cells' shape, ends, turns and tone.
func test_a_road_through_stone_keeps_its_cells() -> void:
	var grid := _field(_rect(Vector2i(2, 5), Vector2i(9, 5)) + _rect(Vector2i(5, 2), Vector2i(5, 9)), "stone")
	var image := RoadShape.image_of(grid, _past("stone"), Vector2i(12, 12))
	for y in 12:
		for x in 12:
			var texel := _texel(image, Vector2i(x, y))
			assert_eq([texel.b, texel.a], [0.0, 0.0], "nothing drawn again at %s" % Vector2i(x, y))
	assert_eq(_texel(image, Vector2i(2, 5)).r, 1.0, "its arm runs on whole into the stone")


## A street paved with the pack's stone (the Frostgate's cobbles) keeps its
## cells' shape: its stone is drawn to them.
func test_a_paved_street_keeps_its_cells() -> void:
	var road := _rect(Vector2i(0, 4), Vector2i(7, 5))
	var paved := {}
	for cell: Vector2i in road:
		paved[cell] = "cobbles"
	var image := RoadShape.image_of(_field(road), _past(), Vector2i(12, 12), paved)
	for cell: Vector2i in road + [Vector2i(8, 4), Vector2i(3, 3)]:
		assert_eq([_texel(image, cell).b, _texel(image, cell).a], [0.0, 0.0], "nothing drawn again at %s" % cell)
	assert_eq(_texel(image, Vector2i(7, 4)).r, 1.0, "whole to its end")


## Every country map's mask is worked out with its ground and kept; the
## village's streets keep their cells' shape.
func test_country_maps_keep_their_roads_shape_and_the_village_none() -> void:
	KeptGround.forget()
	var town := MapData.load_by_id("town")
	assert_null(KeptGround.of(town, town.grid, MapView.EDGE_PAD).road_map, "the village's streets")
	var map := MapData.load_by_id("deepwood")
	var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
	assert_not_null(kept.road_map)
	assert_eq(kept.road_image.get_size(), map.size + Vector2i.ONE * 2 * RoadShape.RING)
	assert_almost_eq(_texel(kept.road_image, Vector2i(25, 24)).r, 0.45, 0.01, "the glade's west stub ends narrowing")
	KeptGround.forget()
