extends GutTest
## A world that moves (PIX-223): what the wind sways and what stands still,
## where the water lies for the foam and the reflections, cloud shadows only
## under the sky, and the world's clock, which stops with reduced motion.

const LightRig := preload("res://scripts/light_rig.gd")

var _reduce_motion: bool


func before_each() -> void:
	_reduce_motion = GameState.settings.reduce_motion


func after_each() -> void:
	GameState.settings.reduce_motion = _reduce_motion


func test_the_wind_moves_trees_and_wheat_not_stones() -> void:
	for tile: int in Scatter.SWAYS:
		var grows := Scatter.SCATTER.values().any(func(entry: Array) -> bool: return tile in entry[1])
		assert_true(grows, "tile %d is scattered somewhere" % tile)
	for still: int in [702, 703, 730, 784, 811, 838]:
		assert_false(still in Scatter.SWAYS, "a boulder, a log, a twig or a stump stands still")


func test_the_water_map_finds_rivers_seas_and_what_spans_them() -> void:
	var grid := {
		Vector2i(0, 0): "grass", Vector2i(1, 0): "water", Vector2i(2, 0): "bridge",
		Vector2i(0, 1): "sea", Vector2i(1, 1): "dock", Vector2i(2, 1): "sand",
	}
	var mask := PunyTerrain.water_map(grid, Vector2i(3, 2)).get_image()
	assert_eq(mask.get_pixel(0, 0).r, 0.0, "grass is land")
	assert_eq(mask.get_pixel(1, 0).r, 1.0, "the river")
	assert_eq(mask.get_pixel(2, 0).r, 1.0, "water under a bridge")
	assert_eq(mask.get_pixel(0, 1).r, 1.0, "the sea")
	assert_eq(mask.get_pixel(1, 1).r, 1.0, "water under a dock")
	assert_eq(mask.get_pixel(2, 1).r, 0.0, "the beach is land")
	assert_eq(mask.get_pixel(1, 0).g, 0.0, "the river's first row lies under its bank")
	assert_almost_eq(mask.get_pixel(1, 1).g * 255.0, 1.0, 0.01, "one row of water above the dock's")
	assert_eq(mask.get_pixel(0, 1).g, 0.0, "the sea under the grass")


func test_clouds_pass_only_under_the_sky() -> void:
	assert_true(Lights.under_sky(MapData.load_by_id("overworld")))
	assert_true(Lights.under_sky(MapData.load_by_id("town")))
	assert_false(Lights.under_sky(MapData.load_by_id("town_inn")), "never indoors")
	assert_false(Lights.under_sky(MapData.load_by_id("vault_4")), "never under the mountain")
	assert_false(Lights.under_sky(null))


func test_the_worlds_clock_stops_with_reduced_motion() -> void:
	var rig: Node = autofree(LightRig.new())
	GameState.settings.reduce_motion = false
	rig.tick(0.5)
	rig.tick(0.25)
	assert_almost_eq(float(rig.time), 0.75, 0.0001, "the wind and the water keep the world's time")
	assert_eq(rig.wind, 1.0)
	GameState.settings.reduce_motion = true
	rig.tick(0.5)
	assert_almost_eq(float(rig.time), 0.75, 0.0001, "everything holds still")
	assert_eq(rig.wind, 0.0, "and the wind drops")


func test_the_shaders_share_one_clock() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/world_time"))
	assert_true(ProjectSettings.has_setting("shader_globals/world_wind"))
	var wind := FileAccess.get_file_as_string("res://shaders/wind.gdshaderinc")
	for path: String in ["res://shaders/region_tint.gdshader", "res://shaders/clouds.gdshader", "res://shaders/reflections.gdshader"]:
		assert_string_contains((load(path) as Shader).code, "wind.gdshaderinc")
	assert_string_contains(wind, "RENDERER_COMPATIBILITY", "the browser's renderer numbers a quad's corners its own way")
