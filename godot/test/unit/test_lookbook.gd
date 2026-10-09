extends GutTest
## The look book and the perf guard (PIX-220): every shot stands somewhere
## the hero can, the sheet lays them out in order, and the probe's summary
## reads average and 95th percentile.

const Lookbook := preload("res://scripts/lookbook.gd")


func test_every_shot_stands_on_open_ground() -> void:
	for shot: Dictionary in Lookbook.SHOTS:
		if shot.has("floor"):
			continue
		var map := MapData.load_by_id(shot["map"])
		var want := map.spawn
		if shot.get("at", "") == "street":
			want = Lookbook.STREET
		var cell := Lookbook.nearest_walkable(map, want)
		assert_true(map.is_walkable(cell), "%s stands on open ground" % shot["name"])
		assert_lte(Vector2(cell).distance_to(Vector2(want)), 12.0, "%s stands near where it asked" % shot["name"])


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
