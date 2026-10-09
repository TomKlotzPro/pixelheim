extends GutTest
## Each region's air and the weather (PIX-224): which air a cell breathes,
## showers from the world's clock, where rain may fall, the colour moods,
## and what falls over the view.

const Atmosphere := preload("res://scripts/atmosphere.gd")
const Lookbook := preload("res://scripts/lookbook.gd")


func after_each() -> void:
	GameState.progression.prologue = Prologue.DONE


func _cell_in(map: MapData, region: String) -> Vector2i:
	for cell: Vector2i in map.regions:
		if map.regions[cell] == region:
			return cell
	return Vector2i(-1, -1)


func test_each_region_has_its_air() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Weather.air_at(overworld, _cell_in(overworld, "ash")), "ash", "heat over the Ash")
	assert_eq(Weather.air_at(overworld, _cell_in(overworld, "marsh")), "mire", "the marshes are misty too")
	assert_eq(Weather.air_at(overworld, _cell_in(overworld, "forest")), "", "the woods breathe plain air")
	var frostgate := MapData.load_by_id("frostgate")
	assert_eq(Weather.air_at(frostgate, frostgate.spawn), "frost")
	var mire := MapData.load_by_id("mirefen")
	assert_eq(Weather.air_at(mire, _cell_in(mire, "mire")), "mire")
	var coast := MapData.load_by_id("saltmere")
	assert_eq(Weather.air_at(coast, _cell_in(coast, "coast")), "coast")
	assert_eq(Weather.air_at(MapData.load_by_id("town_inn"), Vector2i(3, 3)), "", "no weather indoors")


func test_showers_come_and_go_with_the_clock() -> void:
	var wet_days := 0
	for day in 100:
		var most := 0.0
		for step in range(0, DayNight.DAY_CYCLE_STEPS, 4):
			var rain := Weather.rain_at(day * DayNight.DAY_CYCLE_STEPS + step)
			assert_between(rain, 0.0, 1.0)
			most = maxf(most, rain)
		if most > 0.0:
			wet_days += 1
	assert_between(wet_days, 20, 60, "some days bring a shower, most don't")
	var heart := Weather.next_shower(0.0)
	assert_eq(Weather.rain_at(heart), 1.0, "a shower's heart pours")
	assert_eq(Weather.rain_at(heart), Weather.rain_at(heart), "the same every time: nothing to save")
	assert_lt(Weather.rain_at(heart - Weather.SHOWER_MAX), 1.0, "and it came on slowly")


func test_rain_falls_on_the_open_land_only() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_true(Weather.rains_in(overworld, ""))
	assert_true(Weather.rains_in(MapData.load_by_id("saltmere"), "coast"), "the coast gets showers too")
	for dry: String in ["ash", "frost", "mire"]:
		assert_false(Weather.rains_in(overworld, dry), "%s keeps its own air" % dry)
	assert_false(Weather.rains_in(MapData.load_by_id("town_inn"), ""), "never indoors")
	var town := MapData.load_by_id("town")
	assert_true(Weather.rains_in(town, ""))
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_false(Weather.rains_in(town, ""), "not on the night the village burns")


func test_each_air_has_a_colour_mood_and_night_takes_colour() -> void:
	var plain := Weather.mood({}, 0.0)
	assert_eq(plain[0], Color(1, 1, 1), "the open land keeps Shade's colours")
	assert_eq(plain[1], 1.0)
	assert_eq(Weather.mood({}, 1.0)[1], Weather.NIGHT_SATURATION, "the night is greyer")
	var ash := Weather.mood({"ash": 1.0, "frost": 0.0}, 0.0)
	assert_eq(ash[0], Weather.MOODS["ash"][0], "the Ash is warm")
	assert_almost_eq(float(ash[1]), float(Weather.MOODS["ash"][1]), 0.0001)
	var halfway := Weather.mood({"frost": 0.5}, 0.0)
	assert_between(float(halfway[1]), float(Weather.MOODS["frost"][1]), 1.0, "crossing into the Frostgate fades its mood in")


func test_what_falls_over_the_view() -> void:
	var drop := Atmosphere.picture(["x", "."]).get_image()
	assert_eq(drop.get_pixel(0, 0).a, 1.0)
	assert_eq(drop.get_pixel(0, 1).a, 0.0)
	for node: CPUParticles2D in [Atmosphere._drops(), Atmosphere._splashes(), Atmosphere._snow(), Atmosphere._embers(), Atmosphere._spray()]:
		autofree(node)
		assert_eq(node.emission_shape, CPUParticles2D.EMISSION_SHAPE_RECTANGLE, "it covers the view")
		assert_eq(node.preprocess, node.lifetime, "it's already falling on arrival")
	var hour := fposmod(Lookbook.shower_by_day(), float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
	assert_lt(hour, 0.45, "the look book's rain falls by day")
	assert_eq(Weather.rain_at(Lookbook.shower_by_day()), 1.0)


func test_rain_has_its_own_sound() -> void:
	var audio := SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/audio.json")) as Dictionary
	assert_has(audio["beds"], "rain")
	assert_true(FileAccess.file_exists("res://assets/audio/ambience/bed_rain.wav"))
