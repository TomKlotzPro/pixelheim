extends GutTest
## Soft doors (One Reach, PIX-269, step 2): a door dissolves the old place
## into the new one in a quarter of a second, no black between; going under
## the ground keeps a brief dark, and coming back up dissolves.


func test_the_old_picture_eases_out_in_a_quarter_of_a_second() -> void:
	assert_eq(Dissolve.SECONDS, 0.25)
	assert_eq(Dissolve.shown(0.0), 1.0, "all of the old place at first")
	assert_almost_eq(Dissolve.shown(Dissolve.SECONDS / 2.0), 0.5, 0.001, "half way, half and half")
	assert_eq(Dissolve.shown(Dissolve.SECONDS), 0.0, "none of it at the end")
	var last := 1.0
	for step in 26:
		var now := Dissolve.shown(step * 0.01)
		assert_lte(now, last, "it only ever fades (%.2f s)" % (step * 0.01))
		last = now


func test_a_hitch_counts_as_one_ordinary_frame() -> void:
	# The frame the new map is built in can take a tenth of a second or more.
	var picture: Dissolve = autofree(Dissolve.new())
	picture._process(0.15)
	assert_almost_eq(picture.elapsed, Dissolve.LONGEST_FRAME, 0.0001, "not a sixth of a second gone in one go")
	assert_gt(picture.modulate.a, 0.9, "the old place still all but whole")


func _place(style := "", floor_level := 0) -> MapData:
	var map := MapData.new()
	map.style = style
	map.floor_level = floor_level
	return map


func test_going_under_the_ground_keeps_the_dark_and_coming_up_dissolves() -> void:
	var sky := _place()
	var cave := _place("cave")
	var floor_one := _place("", 1)
	var floor_two := _place("", 2)
	assert_true(Ways.goes_under(sky, cave), "into a cave or a cellar: the dark")
	assert_true(Ways.goes_under(sky, floor_one), "down to a dungeon's floor")
	assert_true(Ways.goes_under(floor_one, floor_two), "and the next one down")
	assert_true(Ways.goes_under(cave, floor_one), "from a cave down to a floor")
	assert_false(Ways.goes_under(cave, sky), "up out of the cave: a dissolve")
	assert_false(Ways.goes_under(floor_two, sky), "up the stairs to the gate")
	assert_false(Ways.goes_under(sky, _place()), "a door to a house, the town's gate: a dissolve")
	var room := MapData.load_by_id("keep")
	var cellars := MapData.load_by_id("cellars")
	assert_true(Ways.goes_under(room, cellars), "Captain Hale's stair down to the cellars")
	assert_false(Ways.goes_under(cellars, room), "and back up into his hall")
