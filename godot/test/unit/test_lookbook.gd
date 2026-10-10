extends GutTest
## The look book and the perf guard (PIX-220): every shot stands somewhere
## the hero can, goes by its name and its area (PIX-273), the sheet lays them
## out in order, and the probe's summary reads average and 95th percentile.

const Lookbook := preload("res://scripts/lookbook.gd")


func test_every_shot_stands_on_open_ground() -> void:
	for shot_name: String in Lookbook.SHOTS:
		var shot: Dictionary = Lookbook.SHOTS[shot_name]
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
	for shot_name: String in Lookbook.SHOTS:
		assert_not_null(word.search(shot_name), "%s is a name, no number" % shot_name)
		assert_false(Lookbook.SHOTS[shot_name].has("name"), "%s is named by its key alone" % shot_name)
		assert_has(Lookbook.AREAS, Lookbook.SHOTS[shot_name].get("area", ""), "%s's area is one of AREAS" % shot_name)
	for area: String in Lookbook.AREAS:
		assert_true(Lookbook.SHOTS.values().any(func(shot: Dictionary) -> bool: return shot["area"] == area), "%s has a shot" % area)


func test_the_sheet_goes_by_area() -> void:
	var order := Array(Lookbook.ordered())
	assert_eq(order.size(), Lookbook.SHOTS.size(), "every shot, once")
	var areas := order.map(func(shot_name: String) -> int: return Lookbook.AREAS.find(Lookbook.SHOTS[shot_name]["area"]))
	var by_area := areas.duplicate()
	by_area.sort()
	assert_eq(areas, by_area, "the sheet's shots grouped by area, in AREAS' order")
	assert_eq(order.slice(0, 3), ["town_day", "town_dusk", "town_night"], "SHOTS' order within an area")


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
