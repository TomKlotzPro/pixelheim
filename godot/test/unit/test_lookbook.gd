extends GutTest
## The look book and the perf guard (PIX-220): every shot stands somewhere
## the hero can, goes by its name and its area (PIX-273), the sheet lays them
## out in order, and the probe's summary reads average and 95th percentile;
## its CPU clock times frames headless too (PIX-355).

const Lookbook := preload("res://scripts/lookbook.gd")


func test_every_shot_stands_on_open_ground() -> void:
	for shot_name: String in Lookbook.shots():
		var shot: Dictionary = Lookbook.shots()[shot_name]
		if shot.has("floor"):
			continue
		var map := MapData.load_by_id(shot["map"])
		var want := map.spawn
		if shot.get("at", "") == "street":
			want = Lookbook.STREET
		var cell := Lookbook.nearest_walkable(map, want)
		assert_true(map.is_walkable(cell), "%s stands on open ground" % shot_name)
		assert_lte(Vector2(cell).distance_to(Vector2(want)), 12.0, "%s stands near where it asked" % shot_name)


## Shots went by number (`17_strike`), and every branch adding one took the
## same next number: a name, and an area the sheet groups it by, instead.
func test_a_shot_goes_by_its_name_and_its_area() -> void:
	var word := RegEx.create_from_string("^[a-z][a-z_]*$")
	for shot_name: String in Lookbook.shots():
		assert_not_null(word.search(shot_name), "%s is a name, no number" % shot_name)
		assert_false(Lookbook.shots()[shot_name].has("name"), "%s is named by its key alone" % shot_name)
		assert_has(Lookbook.AREAS, Lookbook.shots()[shot_name].get("area", ""), "%s's area is one of AREAS" % shot_name)
	for area: String in Lookbook.AREAS:
		assert_true(Lookbook.shots().values().any(func(shot: Dictionary) -> bool: return shot["area"] == area), "%s has a shot" % area)


func test_the_sheet_goes_by_area() -> void:
	var order := Array(Lookbook.ordered())
	assert_eq(order.size(), Lookbook.shots().size(), "every shot, once")
	var areas := order.map(func(shot_name: String) -> int: return Lookbook.AREAS.find(Lookbook.shots()[shot_name]["area"]))
	var by_area := areas.duplicate()
	by_area.sort()
	assert_eq(areas, by_area, "the sheet's shots grouped by area, in AREAS' order")
	assert_eq(order.slice(0, 3), ["town_day", "town_dusk", "town_night"], "the shots' order within an area")


func test_the_sheet_holds_every_shot_at_half_size() -> void:
	var images: Array[Image] = []
	for i in 4:
		var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		image.fill(Color(i / 4.0, 0, 0))
		images.append(image)
	var sheet := Lookbook.sheet(images)
	assert_eq(sheet.get_size(), Vector2i(32 * Lookbook.SHEET_COLUMNS, 18 * 2), "three across, two rows")
	assert_almost_eq(sheet.get_pixel(32 + 16, 9).r, 0.25, 0.02, "the second shot second")


func test_the_probe_summarises_average_and_worst() -> void:
	assert_eq(PerfProbe.summary([]), "-")
	var values: Array = []
	for i in 100:
		values.append(1.0 if i < 95 else 10.0)
	assert_eq(PerfProbe.summary(values), "1.45/10.00")


func test_the_cpu_clock_times_frames_headless() -> void:
	assert_eq(PerfProbe.spread([]), "-")
	var values: Array = []
	for i in 100:
		values.append(10.0 if i % 10 == 0 else 1.0)
	assert_eq(PerfProbe.spread(values), "1.00/10.00", "the median, which frames the machine took elsewhere don't move, and the 95th percentile")
	var clock := PerfProbe.clock(get_tree())
	await wait_process_frames(5)
	var read := PerfProbe.cpu(get_tree(), clock)
	assert_not_null(RegEx.create_from_string("^\\d+\\.\\d\\d/\\d+\\.\\d\\d$").search(read), "frames timed with no renderer: %s" % read)
	assert_false(get_tree().process_frame.is_connected(clock["on_frame"]), "read, the clock stops")
