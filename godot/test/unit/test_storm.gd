extends GutTest
## Thunderstorms (PIX-491): which showers are storms and when (Weather's
## clock, nothing saved), the lightning's list and its cap, the flash's
## shape hard and soft, the thunder's delay, how the ground wets and dries
## and the puddles fill; the Storm node's strikes; where puddles may lie.

const Storm := preload("res://scripts/storm.gd")
const DAY := float(DayNight.DAY_CYCLE_STEPS)

var _flashes := true
var _still := false


func before_each() -> void:
	_flashes = GameState.settings.flashes
	_still = GameState.settings.reduce_motion
	GameState.settings.flashes = true
	GameState.settings.reduce_motion = false


func after_each() -> void:
	GameState.settings.flashes = _flashes
	GameState.settings.reduce_motion = _still


## Day `day`'s shower: [the step it starts, how long it lasts].
func _shower_on(storm: bool) -> Array:
	for day in 400:
		var shower := Weather._shower(day)
		if not shower.is_empty() and Weather.storms(day) == storm and Weather._shower(day - 1).is_empty():
			return shower
	return []


func test_some_showers_are_storms_and_no_day_rains_more_for_it() -> void:
	var showers := 0
	var storms := 0
	for day in 1000:
		var wet := not Weather._shower(day).is_empty()
		showers += int(wet)
		storms += int(Weather.storms(day))
		assert_true(wet or not Weather.storms(day), "a storm is one of the showers there were")
	assert_between(showers, 340, 460, "showers as often as before: %d days in a thousand" % showers)
	assert_between(storms, 80, 200, "about a third of them storms: %d" % storms)
	assert_eq(Weather.storms(12), Weather.storms(12), "the same every time: nothing to save")


func test_a_storm_blows_with_its_rain_and_a_shower_has_none() -> void:
	var storm := _shower_on(true)
	var heart := float(storm[0]) + float(storm[1]) / 2.0
	assert_eq(Weather.storm_at(heart), 1.0, "a storm's heart blows whole")
	assert_eq(Weather.storm_at(heart), Weather.rain_at(heart), "as hard as it rains")
	assert_between(Weather.storm_at(float(storm[0]) + Weather.SHOWER_RAMP / 2.0), 0.4, 0.6, "and comes on with it")
	assert_eq(Weather.storm_at(float(storm[0]) - 1.0), 0.0, "none before")
	var shower := _shower_on(false)
	heart = float(shower[0]) + float(shower[1]) / 2.0
	assert_eq(Weather.rain_at(heart), 1.0)
	assert_eq(Weather.storm_at(heart), 0.0, "a plain shower has no thunder")


func test_the_harness_finds_a_storm_by_day_and_at_night() -> void:
	var day := Weather.next_storm(0.0, false)
	assert_eq(Weather.storm_at(day), 1.0)
	assert_false(DayNight.is_night(day), "by day")
	var night := Weather.next_storm(0.0, true)
	assert_eq(Weather.storm_at(night), 1.0)
	assert_true(DayNight.is_night(night), "at night")
	assert_eq(Weather.puddles_at(night), 1.0, "its puddles full")
	# Where the harness's `night` leaves the clock (step_night).
	assert_almost_eq(night, (Gathering.day_of(night) + 0.7) * DAY, 0.001)


func test_the_ground_wets_with_the_rain_and_dries_in_an_hour() -> void:
	var storm := _shower_on(true)
	var start := float(storm[0])
	var end := start + float(storm[1])
	assert_eq(Weather.wet_at(start - 1.0), 0.0, "dry before the rain")
	assert_eq(Weather.wet_at(start + Weather.SHOWER_RAMP), 1.0, "soaked once it pours")
	assert_eq(Weather.wet_at(end - 1.0), 1.0, "to the shower's end")
	assert_almost_eq(Weather.wet_at(end + Weather.DRY_STEPS / 2.0), 0.5, 0.01, "half dry half an hour on")
	assert_eq(Weather.wet_at(end + Weather.DRY_STEPS), 0.0, "dry an hour after")
	assert_almost_eq(Weather.DRY_STEPS, DAY / 24.0, 0.001, "an hour of the day")
	var before := 1.0
	for step in range(0, int(Weather.DRY_STEPS) + 1, 5):
		var wet := Weather.wet_at(end + step)
		assert_lte(wet, before, "drying never wets")
		before = wet


func test_puddles_gather_through_the_rain_and_dry_slower() -> void:
	var storm := _shower_on(true)
	var start := float(storm[0])
	var end := start + float(storm[1])
	assert_eq(Weather.puddles_at(start), 0.0)
	assert_almost_eq(Weather.puddles_at(start + Weather.PUDDLE_FILL / 2.0), 0.5, 0.01, "they gather")
	assert_eq(Weather.puddles_at(start + Weather.PUDDLE_FILL), 1.0, "full under a storm")
	assert_gt(Weather.puddles_at(end + Weather.DRY_STEPS), 0.0, "still there when the ground has dried")
	assert_eq(Weather.puddles_at(end + Weather.PUDDLE_DRY), 0.0, "then gone")
	var shower := _shower_on(false)
	assert_eq(Weather.puddles_at(float(shower[0]) + float(shower[1]) - 1.0), Weather.SHOWER_PUDDLES, "a shower leaves smaller ones")


func test_lightning_comes_from_its_own_list() -> void:
	var flickers := 0
	for n in 200:
		var strike := Weather.strike(n)
		assert_eq(strike, Weather.strike(n), "the same list every storm")
		assert_between(float(strike["gap"]), Weather.STRIKE_GAP.x, Weather.STRIKE_GAP.y)
		assert_between(float(strike["far"]), 0.0, 1.0)
		assert_has([1, 2], strike["flashes"])
		assert_between(float(strike["from"]), -1.2, 1.2, "from above, at an angle")
		flickers += int(strike["flashes"] == 2)
	assert_between(flickers, 30, 130, "some flicker")


func test_never_more_than_three_flashes_in_any_five_seconds() -> void:
	assert_eq(Weather.FLASH_CAP, 3)
	assert_eq(Weather.FLASH_WINDOW, 5.0)
	assert_true(Weather.may_flash([], 10.0))
	assert_true(Weather.may_flash([8.0, 9.0], 10.0))
	assert_false(Weather.may_flash([6.0, 8.0, 9.0], 10.0), "a fourth must wait")
	assert_true(Weather.may_flash([5.0, 8.0, 9.0], 10.0), "until the first is five seconds old")
	# The whole list played at its quickest, flickers and all, through the
	# cap: no five seconds ever holds a fourth.
	var shown: Array[float] = []
	var now := 0.0
	for n in 400:
		var strike := Weather.strike(n)
		now += Weather.STRIKE_GAP.x * 0.2
		for i in int(strike["flashes"]):
			var at := now + i * Weather.FLICKER_S
			if Weather.may_flash(shown, at):
				shown.append(at)
	assert_gt(shown.size(), 100)
	for i in range(3, shown.size()):
		assert_gte(shown[i] - shown[i - 3], Weather.FLASH_WINDOW, "flash %d is the fourth in five seconds" % i)


func test_a_flash_is_a_few_frames_and_the_soft_one_never_a_strobe() -> void:
	assert_eq(Weather.flash_light(0.0, false), 1.0, "white at once")
	assert_eq(Weather.flash_light(Weather.FLASH_S, false), 0.0, "gone in a third of a second")
	assert_lt(Weather.FLASH_S, 0.5)
	assert_eq(Weather.flash_light(-0.1, false), 0.0, "a flicker still to come shows nothing")
	var top := 0.0
	var before := 0.0
	var turns := 0
	var rising := true
	for i in 240:
		var light := Weather.flash_light(i / 60.0, true)
		top = maxf(top, light)
		# A frame to the next never jumps: a swell, not a flash.
		assert_lt(absf(light - before), 0.02, "the soft one eases")
		if (light > before) != rising and light != before:
			rising = not rising
			turns += 1
		before = light
	assert_almost_eq(top, Weather.SOFT_LIGHT, 0.005, "a soft brightening")
	assert_lte(turns, 1, "up once and down once")


func test_thunder_follows_by_the_strikes_distance() -> void:
	assert_eq(Weather.thunder_delay(0.0), 0.0, "overhead it cracks at once")
	assert_eq(Weather.thunder_delay(1.0), Weather.THUNDER_FAR_S, "far off it rumbles seconds later")
	assert_lt(Weather.thunder_delay(0.3), Weather.thunder_delay(0.6))
	var audio := SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/audio.json")) as Dictionary
	for event: String in ["thunder_near", "thunder_far", "thunder_inside"]:
		assert_eq(audio["events"][event]["family"], "thunder")
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % audio["events"][event]["takes"][0]), event)
	assert_eq(audio["families"]["thunder"]["bus"], "Ambience", "on the weather's slider")
	assert_has(Sound.BUSES, "Ambience", "a bus the layout holds: none made at run time")


## A Storm on a bare world, not running by itself.
func _storm() -> Node:
	var world := Node2D.new()
	add_child_autofree(world)
	var storm: Node = Storm.new()
	storm.world = world
	storm.set_process(false)
	world.add_child(storm)
	return storm


func test_the_storm_holds_its_strikes_to_the_cap() -> void:
	var storm := _storm()
	for i in 6:
		storm.strike({"gap": 0.0, "far": 0.0, "flashes": 2, "from": 0.0})
	assert_eq(storm.flashes, Weather.FLASH_CAP, "six flickering strikes at once: three flashes")
	assert_eq(storm._thunder.size(), 2, "and a strike held back whole makes no thunder")
	assert_false(storm.soft)


func test_the_storm_keeps_its_own_time_and_dims_behind_a_screen() -> void:
	var storm := _storm()
	storm._now = 100.0
	storm.strike({"gap": 0.0, "far": 1.0, "flashes": 1, "from": 0.0})
	# By its own seconds, which stand still while a Screen holds the world:
	# GameClock's run on, and a strike and its thunder fell the moment a
	# menu shut.
	assert_eq(float(storm._showing[0]["at"]), 100.0, "the flash by the storm's own clock")
	assert_almost_eq(float(storm._thunder[0][0]), 100.0 + Weather.THUNDER_FAR_S, 0.001, "and its thunder")
	assert_false(storm.casts, "nothing laid to cast from: the strike still flashes")
	storm.sky.visible = true
	storm.bolt.visible = true
	storm.notification(Node.NOTIFICATION_PAUSED)
	assert_false(storm.sky.visible or storm.bolt.visible, "no flash left lit behind a menu")


func test_flashes_off_or_reduce_motion_is_one_soft_brightening() -> void:
	for setting: String in ["flashes", "reduce_motion"]:
		GameState.settings.flashes = setting != "flashes"
		GameState.settings.reduce_motion = setting == "reduce_motion"
		var storm := _storm()
		storm.strike({"gap": 0.0, "far": 0.0, "flashes": 2, "from": 0.0})
		assert_true(storm.soft, setting)
		assert_eq(storm.flashes, 1, "%s: the soft one never flickers" % setting)
		assert_true(storm._showing[0]["soft"])


func test_the_option_is_saved() -> void:
	var path := "user://test_storm_settings.cfg"
	var settings := GameSettings.new(path)
	assert_true(settings.flashes, "on by default")
	settings.flashes = false
	settings.save_file()
	var read := GameSettings.new(path)
	read.load_file()
	assert_false(read.flashes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_puddles_gather_on_paths_and_less_on_grass_never_on_water_or_under_a_roof() -> void:
	var town := MapData.load_by_id("town")
	var mask := PuddlesLayer.mask(town).get_image()
	assert_eq(mask.get_size(), town.size)
	var seen := {}
	for cell: Vector2i in town.grid:
		var tile: String = town.grid[cell]
		var gathers := mask.get_pixelv(cell).r
		seen[tile] = true
		if tile == "path":
			assert_almost_eq(gathers, 1.0, 0.01, "a path at %s" % cell)
		elif tile == "grass":
			assert_between(gathers, 0.3, 0.7, "grass at %s" % cell)
		elif tile in ["water", "roof", "wall", "mountain", "forest", "bridge"]:
			assert_eq(gathers, 0.0, "%s at %s" % [tile, cell])
		# Round a lamp's foot the ground is trodden hollow: its own mark, on
		# its cell and the open one before it, where the flame is mirrored.
		var before: bool = town.grid.get(cell + Vector2i.UP, "") == "lamp" and gathers > 0.0
		assert_eq(mask.get_pixelv(cell).g, float(tile == "lamp" or before), "%s at %s" % [tile, cell])
		# The wet ground's veil: never on open water or a house.
		if tile in ["path", "grass", "sand", "lamp"]:
			assert_eq(mask.get_pixelv(cell).b, 1.0, "%s at %s wets" % [tile, cell])
		elif tile == "water" or tile.begins_with("roof") or tile == "wall":
			assert_eq(mask.get_pixelv(cell).b, 0.0, "%s at %s stays dry" % [tile, cell])
	assert_true(seen.has("path") and seen.has("water") and seen.has("roof"))
	for tile: String in PuddlesLayer.GATHERS:
		assert_true(WorldTiles.TILE_INFO.has(tile), "%s is a tile" % tile)
	assert_false(PuddlesLayer.GATHERS.has("ash"), "no rain on the Ash")


func test_nothing_wets_where_no_rain_falls() -> void:
	var reach := MapData.load_by_id("overworld")
	var mask := PuddlesLayer.mask(reach).get_image()
	var dry := 0
	var wet := 0
	for cell: Vector2i in reach.grid:
		var air: String = Weather.AIRS.get(reach.regions.get(cell, ""), "")
		if air in Weather.DRY_AIRS or reach.grid[cell] in ["ash", "snow", "water"]:
			assert_eq(mask.get_pixelv(cell), Color(0, 0, 0), "%s in %s at %s: no veil, no puddle" % [reach.grid[cell], air, cell])
			dry += 1
		else:
			wet += int(mask.get_pixelv(cell).b == 1.0)
	assert_gt(dry, 0, "the Reach has land no rain falls on")
	assert_gt(wet, 0, "and land it does")
	for air: String in Weather.DRY_AIRS:
		assert_false(Weather.rains_in(reach, air), air)
	# The whole map's leavings follow the map, not the air the hero stands
	# in: Storm reads rains_in(map, "").
	assert_true(Weather.rains_in(reach, ""))
