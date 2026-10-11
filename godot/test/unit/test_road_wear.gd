extends GutTest
## The roads' wear (PIX-307): a cart's ruts down the middle of every road up
## to three cells wide, which way it runs; crossings and squares worn but
## not rutted; grass creeping in only where a road meets grass; stones
## along a gravelled street's edge; and the ruts running on unbroken across
## the line into the map beside.


## A meadow with `roads` (cells) in it: a tile lookup and the grid.
func _meadow(roads: Array, size := Vector2i(12, 12)) -> Dictionary:
	var grid := {}
	for y in size.y:
		for x in size.x:
			grid[Vector2i(x, y)] = "grass"
	for cell: Vector2i in roads:
		grid[cell] = "path"
	return grid


## Past the meadow's edges, more meadow.
var _grass := func(_cell: Vector2i) -> String: return "grass"


func _at(grid: Dictionary) -> Dictionary:
	return grid


func _road_down(x0: int, width: int) -> Array:
	var cells := []
	for y in 12:
		for x in range(x0, x0 + width):
			cells.append(Vector2i(x, y))
	return cells


func test_a_road_runs_its_ruts_down_its_middle_whichever_way_it_runs() -> void:
	var grid := _meadow(_road_down(4, 3))
	var at := _at(grid)
	assert_eq(RoadWear.lane_of(at, _grass, Vector2i(5, 6)), [RoadWear.DOWN, 3, 1], "the middle of three")
	assert_eq(RoadWear.lane_of(at, _grass, Vector2i(4, 6)), [RoadWear.DOWN, 3, 0])
	assert_eq(RoadWear.lane_of(at, _grass, Vector2i(6, 6)), [RoadWear.DOWN, 3, 2])
	var across := {}
	for x in 12:
		across[Vector2i(x, 3)] = true
		across[Vector2i(x, 4)] = true
	var lane := RoadWear.lane_of(_meadow(across.keys()), _grass, Vector2i(6, 4))
	assert_eq(lane, [RoadWear.ACROSS, 2, 1], "the second of two, running across")
	assert_eq(RoadWear.lane_of(_meadow(_road_down(2, 1)), _grass, Vector2i(2, 5)), [RoadWear.DOWN, 1, 0], "a track one wide")


func test_crossings_and_squares_are_worn_not_rutted() -> void:
	var square := []
	for y in range(3, 8):
		for x in range(3, 8):
			square.append(Vector2i(x, y))
	var at := _at(_meadow(square))
	assert_eq(RoadWear.lane_of(at, _grass, Vector2i(5, 5)), [], "a square's middle")
	var tile := RoadWear.wear_tile(at, _grass, Vector2i(5, 5), Vector2i.ZERO, RoadWear.COUNTRY)
	assert_true(tile >= RoadWear.PATCHES and tile < RoadWear.VERGES, "a worn patch")
	var crossing := _road_down(5, 1)
	for x in 12:
		crossing.append(Vector2i(x, 6))
	assert_eq(RoadWear.lane_of(_meadow(crossing), _grass, Vector2i(5, 6)), [], "where two roads cross")


## A road's lanes pick the same variant at each point along it, so what one
## draws over its edge (a tuft on the crown, a pebble) carries on into the
## next; and the tile is the lane's, in the road's look.
func test_the_lanes_across_a_road_pick_alike() -> void:
	var at := _at(_meadow(_road_down(4, 3)))
	for y in 12:
		var tiles := []
		for x in range(4, 7):
			tiles.append(RoadWear.wear_tile(at, _grass, Vector2i(x, y), Vector2i(10, 20), RoadWear.TOWN))
		var variant: int = tiles[0] % RoadWear.VARIANTS
		for index in 3:
			assert_eq(tiles[index], RoadWear.lane_tile(RoadWear.TOWN, RoadWear.DOWN, 3, index, variant), "row %d, lane %d" % [y, index])


func test_grass_creeps_in_only_where_a_road_meets_grass() -> void:
	var grid := _meadow(_road_down(4, 1))
	for y in 12:
		grid[Vector2i(3, y)] = "water"
	var worn := RoadWear.rows(grid, _grass, Vector2i(12, 12), 0, 12, {}, Vector2i.ZERO, RoadWear.COUNTRY)
	assert_eq(worn["wear"].size(), 12, "every road cell worn")
	for cell: Vector2i in worn["verge"]:
		var sides: int = (worn["verge"][cell] - RoadWear.VERGES) / RoadWear.VERGE_VARIANTS + 1
		assert_eq(sides & 8, 0, "%s: no grass on the river side" % cell)
		assert_ne(sides & 2, 0, "%s: grass on the meadow side" % cell)
	var paved := {Vector2i(4, 5): "gravel"}
	worn = RoadWear.rows(grid, _grass, Vector2i(12, 12), 0, 12, paved, Vector2i.ZERO, RoadWear.COUNTRY)
	assert_false(worn["wear"].has(Vector2i(4, 5)), "a paved cell wears nothing")


func test_a_gravelled_street_sets_stones_where_it_ends() -> void:
	var street := {Vector2i(4, 4): "gravel", Vector2i(5, 4): "gravel"}
	var grid := _meadow([Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)])
	var kerbs := RoadWear.kerbs(street, street, grid, 0, 12)
	var sides := func(cell: Vector2i) -> int: return (kerbs[cell] - RoadWear.KERBS) / RoadWear.VERGE_VARIANTS + 1
	assert_eq(sides.call(Vector2i(4, 4)), 1 | 4, "grass above and below; the road goes on west, the gravel east")
	assert_eq(sides.call(Vector2i(5, 4)), 1 | 2 | 4, "and the gravel ends east")


## The wear is drawn in code, every tile of it, the same pixels each time.
func test_the_atlas_is_drawn_the_same_every_time() -> void:
	var atlas := RoadWear.atlas()
	var again := atlas.get_data()
	RoadWear._atlas = null
	assert_eq(RoadWear.atlas().get_data(), again)
	assert_eq(atlas.get_width() / RoadWear.TILE, RoadWear.COLUMNS)
	assert_gte(atlas.get_height() / RoadWear.TILE * RoadWear.COLUMNS, RoadWear.COUNT)
	var source := RoadWear.tileset().get_source(0) as TileSetAtlasSource
	assert_eq(source.get_tiles_count(), RoadWear.COUNT, "every tile made up front")
	# Every lane a rut runs through: one wide, both of two, the middle of three.
	for style in 2:
		for axis in 2:
			for variant in RoadWear.VARIANTS:
				for lane: Array in [[1, 0], [2, 0], [2, 1], [3, 1]]:
					var tile := RoadWear.lane_tile(style, axis, lane[0], lane[1], variant)
					var drawn := atlas.get_region(Rect2i(RoadWear.coords(tile) * RoadWear.TILE, Vector2i(RoadWear.TILE, RoadWear.TILE)))
					assert_false(drawn.is_invisible(), "lane %s of a road %d wide drawn" % [lane[1], lane[0]])


## A road running out over a map's edge into the map beside reads as the
## same road from both sides of the line (One Reach, PIX-269): the same
## lane, the same variant, so its ruts meet.
func test_the_ruts_run_on_across_the_line() -> void:
	var crossings := 0
	for map_id: String in ReachPlane.maps():
		var data := MapData.load_by_id(map_id)
		var origin := ReachPlane.origin(map_id)
		var at := _plane_at(data, origin)
		for cell: Vector2i in data.grid:
			if data.grid[cell] != "path":
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var beyond := ReachPlane.beyond(map_id, cell, step)
				if beyond.is_empty() or beyond["map"] == map_id:
					continue
				var other := MapData.load_by_id(beyond["map"])
				if other.grid.get(beyond["cell"], "") != "path":
					continue
				crossings += 1
				var there := _plane_at(other, ReachPlane.origin(beyond["map"]))
				assert_eq(RoadWear.lane_of(data.grid, at, cell), RoadWear.lane_of(other.grid, there, beyond["cell"]), "%s %s and %s %s" % [map_id, cell, beyond["map"], beyond["cell"]])
				assert_eq(
					RoadWear.wear_tile(data.grid, at, cell + step, origin, RoadWear.COUNTRY),
					RoadWear.wear_tile(other.grid, there, beyond["cell"], ReachPlane.origin(beyond["map"]), RoadWear.COUNTRY),
					"%s's road over its edge wears what %s's does" % [map_id, beyond["map"]],
				)
	assert_gt(crossings, 0, "roads cross the lines")


## Past a map's edges in the plane: the map beside, or the ridge.
static func _plane_at(_data: MapData, origin: Vector2i) -> Callable:
	return func(cell: Vector2i) -> String: return ReachPlane.tile(origin + cell)
