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


func test_a_day_is_a_day_of_minutes() -> void:
	# A step walked is a minute (PIX-246): the day starts at six.
	assert_eq(DayNight.DAY_CYCLE_STEPS, 1440)
	assert_eq(DayNight.clock(0.0), Vector2i(6, 0))
	assert_eq(DayNight.clock(90.0), Vector2i(7, 30))
	assert_eq(DayNight.clock(18 * 60.0), Vector2i(0, 0), "midnight")
	assert_eq(DayNight.clock(DayNight.DAY_CYCLE_STEPS + 1.0), Vector2i(6, 1), "the next day")
	assert_true(DayNight.is_night(DayNight.DAY_CYCLE_STEPS * 0.7), "night by the evening's end")


func test_a_night_sleeps_till_the_next_morning() -> void:
	var evening := DayNight.DAY_CYCLE_STEPS * 2.6
	assert_eq(DayNight.next_morning(evening), DayNight.DAY_CYCLE_STEPS * 3.0)
	assert_eq(DayNight.clock(DayNight.next_morning(evening)), Vector2i(6, 0))
	assert_false(DayNight.is_night(DayNight.next_morning(evening)), "it's day")
	# Dozing off just after dawn still sleeps a whole day round.
	assert_eq(DayNight.next_morning(DayNight.DAY_CYCLE_STEPS * 3.0), DayNight.DAY_CYCLE_STEPS * 4.0)
