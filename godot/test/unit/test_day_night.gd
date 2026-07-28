extends GutTest
## The day/night wheel must match dayNight.ts: clear sky through the day,
## warm dusk, a long blue night, and a wrap back to dawn-lit day.


func test_daytime_is_untinted() -> void:
	assert_eq(DayNight.sky_at(0).a, 0.0)
	assert_eq(DayNight.sky_at(0.3 * DayNight.DAY_CYCLE_STEPS).a, 0.0)


func test_night_reaches_full_tint() -> void:
	var night := DayNight.sky_at(0.7 * DayNight.DAY_CYCLE_STEPS)
	assert_almost_eq(night.a, 0.36, 0.001)
	assert_gt(night.b, night.r, "night leans blue")


func test_dusk_leans_warm() -> void:
	var dusk := DayNight.sky_at(0.55 * DayNight.DAY_CYCLE_STEPS)
	assert_gt(dusk.r, dusk.b, "dusk leans orange")
	assert_gt(dusk.a, 0.0)


func test_cycle_wraps() -> void:
	var day_one := DayNight.sky_at(100)
	var day_two := DayNight.sky_at(100 + DayNight.DAY_CYCLE_STEPS)
	assert_almost_eq(day_one.a, day_two.a, 0.001)
