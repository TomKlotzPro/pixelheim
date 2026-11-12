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


## The sun of the scenery's shadows (PIX-449): highest at noon, low and
## faint at dawn and dusk, gone through the lamps' night.
func test_the_sun_is_highest_at_noon_and_gone_at_night() -> void:
	var day := float(DayNight.DAY_CYCLE_STEPS)
	var noon := DayNight.sun(0.25 * day)
	assert_almost_eq(noon.z, 1.0, 0.001, "full strength at noon")
	assert_almost_eq(Vector2(noon.x, noon.y).length(), DayNight.SHADOW_NOON, 0.001, "and shortest")
	var dusk := DayNight.sun(0.5 * day)
	assert_between(dusk.z, 0.1, 0.9, "fainter at dusk")
	assert_gt(Vector2(dusk.x, dusk.y).length(), Vector2(noon.x, noon.y).length(), "and longer")
	assert_lte(Vector2(dusk.x, dusk.y).length(), DayNight.SHADOW_LONGEST + 0.001, "never past the longest")
	for night: float in [0.59, 0.7, 0.85, 0.91]:
		assert_eq(DayNight.sun(night * day), Vector3.ZERO, "none at %.2f of the day" % night)
		assert_true(DayNight.is_night(night * day), "%.2f is the lamps' night" % night)
	assert_gt(DayNight.sun(0.95 * day).z, 0.0, "up again after the night's end")
	assert_almost_eq(DayNight.sun(0.3 * day).z, DayNight.sun(3.3 * day).z, 0.001, "every day alike")


func test_every_shadow_falls_one_way() -> void:
	var way := DayNight.SHADOW_WAY.normalized()
	for share: float in [0.0, 0.1, 0.25, 0.4, 0.55, 0.95]:
		var sun := DayNight.sun(share * DayNight.DAY_CYCLE_STEPS)
		assert_almost_eq(Vector2(sun.x, sun.y).normalized().dot(way), 1.0, 0.001, "east and a little south at %.2f" % share)
	assert_gt(way.x, way.y, "mostly east")
	assert_gt(way.y, 0.0, "a little south, as the ruins' fall")
