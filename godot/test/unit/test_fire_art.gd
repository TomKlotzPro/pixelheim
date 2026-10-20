extends GutTest
## The fires of a burning house (PIX-327). The Night of Ash's flames were
## Shade's status icon in a grid on the ash, each in a round glow: a field
## of lightbulbs. Now they are our own pixel art in his fire colours, on
## their feet and moving in whole pixels, a loop without a seam; they stand
## on what burns (the frame's rails and posts, the rubble, the fallen floor,
## a roof and its windows) and never float; the light flickers as a blaze
## does, still with Reduce motion; and the village burns so on the night.

var _saved := {}


func before_each() -> void:
	_saved = {
		"prologue": GameState.progression.prologue,
		"doused": GameState.progression.prologue_doused.duplicate(),
		"tier": GameState.settlement.town_tier,
		"projects": GameState.settlement.projects.duplicate(),
		"steps": GameState.world.steps,
		"still": GameState.settings.reduce_motion,
	}


func after_each() -> void:
	GameState.progression.prologue = _saved["prologue"]
	GameState.progression.prologue_doused.assign(_saved["doused"])
	GameState.settlement.town_tier = _saved["tier"]
	GameState.settlement.projects.assign(_saved["projects"])
	GameState.world.steps = _saved["steps"]
	GameState.settings.reduce_motion = _saved["still"]


static func _sheet(kind: String) -> Image:
	var image := (load(FireArt.SHEET % kind) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _frame(sheet: Image, kind: String, variant: int, frame: int) -> Image:
	var size: Vector2i = FireArt.KINDS[kind]
	return sheet.get_region(Rect2i(Vector2i(frame * size.x, variant * size.y), size))


static func _lit(frame: Image, row: int) -> int:
	var lit := 0
	for x in frame.get_width():
		if frame.get_pixel(x, row).a > 0.5:
			lit += 1
	return lit


static func _changed(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func test_each_sheet_holds_its_kinds_frames_and_variants() -> void:
	for kind: String in FireArt.KINDS:
		var size: Vector2i = FireArt.KINDS[kind]
		assert_eq(_sheet(kind).get_size(), Vector2i(size.x * FireArt.FRAMES, size.y * FireArt.VARIANTS), "%s: tools/fire.py's layout" % kind)


func test_the_flames_are_drawn_in_shades_fire_colours() -> void:
	for kind: String in FireArt.KINDS:
		var sheet := _sheet(kind)
		var stray := 0
		for y in sheet.get_height():
			for x in sheet.get_width():
				var pixel := sheet.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				var known := pixel.a == 1.0 and FireArt.COLOURS.any(func(colour: Color) -> bool: return pixel.is_equal_approx(colour))
				if not known:
					stray += 1
		assert_eq(stray, 0, "%s: every pixel clear or one of Shade's four fire colours, whole" % kind)


func test_every_frame_stands_on_its_foot_tapers_and_moves() -> void:
	for kind: String in FireArt.KINDS:
		var sheet := _sheet(kind)
		var size: Vector2i = FireArt.KINDS[kind]
		for variant in FireArt.VARIANTS:
			for f in FireArt.FRAMES:
				var frame := _frame(sheet, kind, variant, f)
				var foot := _lit(frame, size.y - 1)
				assert_gte(foot, size.x / 3, "%s %d/%d stands on its foot" % [kind, variant, f])
				assert_lt(_lit(frame, 0), foot, "%s %d/%d tapers to its tips" % [kind, variant, f])
				var next := _frame(sheet, kind, variant, (f + 1) % FireArt.FRAMES)
				assert_gt(_changed(frame, next), 0, "%s %d/%d moves into the next" % [kind, variant, f])


## The last frame steps into the first about as any frame steps into the
## next (the noise wraps and the sway turns once a loop): no seam.
func test_the_loop_has_no_seam() -> void:
	for kind: String in FireArt.KINDS:
		var sheet := _sheet(kind)
		for variant in FireArt.VARIANTS:
			var most := 0
			for f in FireArt.FRAMES - 1:
				most = maxi(most, _changed(_frame(sheet, kind, variant, f), _frame(sheet, kind, variant, f + 1)))
			var seam := _changed(_frame(sheet, kind, variant, FireArt.FRAMES - 1), _frame(sheet, kind, variant, 0))
			assert_lte(float(seam), most * 1.25, "%s %d loops round" % [kind, variant])


func test_a_burning_ruin_burns_on_what_burns() -> void:
	var ruins := Town.ruins([])
	assert_gt(ruins.size(), 5, "the village burns")
	for ruin: Dictionary in ruins:
		var rect: Rect2i = ruin["rect"]
		var tiles := Town.ruin_tiles(ruin)
		var flames := FireArt.plan(rect, tiles)
		var sides := {"top": 0, "bottom": 0, "left": 0, "right": 0}
		var posts := 0
		var blazes := 0
		for flame: Dictionary in flames:
			var cell: Vector2i = flame["cell"]
			var foot: Vector2 = flame["at"]
			assert_true(rect.has_point(cell), "a flame in the house at %s" % rect)
			assert_ne(cell, ruin["door"], "the door stays open")
			assert_has(["fence", "crate", "barrel", "ash"], String(tiles[cell]), "a flame on what burns")
			# Its foot on its cell, or on the joint to the next, never in the air.
			assert_true(Rect2(Vector2(cell * FireArt.TILE), Vector2.ONE * FireArt.TILE).grow(1).has_point(foot), "%s's foot on its cell" % cell)
			assert_eq(foot, foot.floor(), "on the pixel grid")
			assert_eq(float(flame["sort"]), floorf(flame["sort"]), "sorted on the pixel grid")
			if flame["on"] == "heart":
				assert_true(rect.grow(-1).has_point(cell), "the fallen floor burns inside the frame")
			if flame["on"] in ["rail", "side", "post"]:
				sides["top"] += 1 if cell.y == rect.position.y else 0
				sides["bottom"] += 1 if cell.y == rect.end.y - 1 else 0
				sides["left"] += 1 if cell.x == rect.position.x else 0
				sides["right"] += 1 if cell.x == rect.end.x - 1 else 0
			posts += 1 if flame["on"] == "post" else 0
			blazes += 1 if flame["kind"] == "blaze" else 0
		for side: String in sides:
			assert_gt(sides[side], 0, "the %s of the frame at %s burns" % [side, rect])
		assert_eq(posts, 4, "each corner post burns tall at %s" % rect)
		assert_gt(blazes, 0, "a blaze where the house at %s fell in" % rect)


## A rail's flames climb out from behind it (sorted above its foot, so the
## rail hides theirs); a side's posts, the rubble and the corner posts burn
## in front of what they stand on.
func test_a_rail_hides_its_flames_feet() -> void:
	var seen := {}
	for ruin: Dictionary in Town.ruins([]):
		for flame: Dictionary in FireArt.plan(ruin["rect"], Town.ruin_tiles(ruin)):
			var bottom := float((flame["cell"] as Vector2i).y * FireArt.TILE + FireArt.TILE)
			seen[flame["on"]] = true
			match String(flame["on"]):
				"rail":
					assert_eq(float(flame["sort"]), (flame["at"] as Vector2).y, "a rail's flame sorts at its foot")
					assert_lt(float(flame["sort"]), bottom, "behind the rail")
				"side", "post", "rubble":
					assert_gt(float(flame["sort"]), bottom, "a %s's flame in front of what it stands on" % flame["on"])
				"heart":
					assert_eq(float(flame["sort"]), (flame["at"] as Vector2).y, "a blaze on the floor sorts at its foot")
	for on: String in ["rail", "side", "post", "rubble", "heart"]:
		assert_true(seen.has(on), "something burns on a %s" % on)


func test_a_roof_burns_along_its_ridge_and_out_of_its_windows() -> void:
	var rect := Rect2i(10, 4, 6, 4)
	var tiles := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			tiles[Vector2i(x, y)] = "roof" if y < rect.end.y - 1 else "wall"
	tiles[Vector2i(11, 7)] = "window"
	tiles[Vector2i(14, 7)] = "window"
	var flames := FireArt.plan(rect, tiles)
	for x in range(rect.position.x, rect.end.x):
		assert_true(flames.any(func(flame: Dictionary) -> bool: return flame["cell"] == Vector2i(x, rect.position.y)), "the ridge burns at %d" % x)
	for window: Vector2i in [Vector2i(11, 7), Vector2i(14, 7)]:
		assert_true(flames.any(func(flame: Dictionary) -> bool: return flame["cell"] == window and flame["on"] == "window"), "fire out of the window at %s" % window)
	for flame: Dictionary in flames:
		assert_gt(float(flame["sort"]), float(rect.end.y * FireArt.TILE), "drawn in front of the house")


func test_the_same_fire_every_time() -> void:
	var ruin: Dictionary = Town.ruins([])[1]
	assert_eq(FireArt.plan(ruin["rect"], Town.ruin_tiles(ruin)), FireArt.plan(ruin["rect"], Town.ruin_tiles(ruin)))


func test_a_blaze_flickers_harder_than_a_lamp() -> void:
	var swing := {false: [10.0, -10.0], true: [10.0, -10.0]}
	for step in 600:
		var t := step / 60.0
		for blaze: bool in [false, true]:
			var at := Lights.flicker(t, 1.3, blaze)
			swing[blaze] = [minf(swing[blaze][0], at), maxf(swing[blaze][1], at)]
	assert_gt(swing[true][1] - swing[true][0], (swing[false][1] - swing[false][0]) * 1.5, "a burning house flickers harder than a lamp")
	assert_gt(swing[true][0], 0.7, "and never near out")
	assert_lt(swing[true][1], 1.3, "nor near double")


func test_reduce_motion_calms_the_flames() -> void:
	var ruin: Dictionary = Town.ruins([])[0]
	for flame: Dictionary in FireArt.plan(ruin["rect"], Town.ruin_tiles(ruin)):
		assert_lte(FireArt.pace(flame, true) * FireArt.FPS, FireArt.STILL_FPS * 1.2, "a calm flame")
		assert_gte(FireArt.pace(flame, false) * FireArt.FPS, FireArt.FPS * 0.8, "a lively one")


## The town drawn on the Night of Ash, as a door draws it.
func _night_of_ash(still: bool) -> Node2D:
	GameState.progression.prologue = Prologue.FIRES
	GameState.progression.prologue_doused.clear()
	GameState.settlement.town_tier = 0
	GameState.settlement.projects.clear()
	GameState.world.steps = Prologue.night_steps()
	GameState.settings.reduce_motion = still
	var map := MapData.load_tiered("town", [], 1)
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	root.set_meta("view", view)
	return root


static func _parts(root: Node) -> Dictionary:
	var out := {"flames": [], "smoke": [], "sparks": [], "coals": []}
	for node in root.find_children("*", "", true, false):
		if node.has_meta("fire"):
			out[node.get_meta("fire")].append(node)
	return out


func test_the_night_of_ash_burns_with_our_flames() -> void:
	var root := _night_of_ash(false)
	var ruins := Town.ruins([])
	var parts := _parts(root)
	assert_eq((root.get_meta("view") as MapView).fires.size(), ruins.size(), "every ruin burns")
	assert_gt(parts["flames"].size(), ruins.size() * 12, "flames up every house")
	for part: String in ["smoke", "sparks", "coals"]:
		assert_eq(parts[part].size(), ruins.size(), "a house's %s" % part)
	for flame: AnimatedSprite2D in parts["flames"]:
		var frame := flame.sprite_frames.get_frame_texture("default", 0) as AtlasTexture
		assert_true(frame.atlas.resource_path.begins_with("res://assets/fire/"), "our own flames, not the paid pack's icon")
		assert_true(flame.get_parent().y_sort_enabled, "sorted with the actors")
		assert_true(flame.is_playing(), "burning")
	# No round glow on every flame any more: the light is the pools'.
	for node in root.find_children("*", "Sprite2D", true, false):
		if (node as Sprite2D).material != Lights.glow():
			continue
		for ruin: Dictionary in ruins:
			var house := Rect2(Vector2((ruin["rect"] as Rect2i).position * MapView.TILE), Vector2((ruin["rect"] as Rect2i).size * MapView.TILE))
			assert_false(house.has_point((node as Sprite2D).position), "no glow ball on the burning house at %s" % ruin["rect"])


func test_reduce_motion_keeps_the_fire_calm() -> void:
	var parts := _parts(_night_of_ash(true))
	assert_eq(parts["sparks"].size(), 0, "no sparks flying")
	assert_gt(parts["smoke"].size(), 0, "the smoke stands, still")
	for flame: AnimatedSprite2D in parts["flames"]:
		assert_lte(flame.speed_scale * FireArt.FPS, FireArt.STILL_FPS * 1.2, "the flames calm")


func test_a_fire_put_out_goes_and_its_ruin_smoulders() -> void:
	var root := _night_of_ash(false)
	var view: MapView = root.get_meta("view")
	var parts := _parts(root)
	var before: int = parts["flames"].size()
	view.douse_ruin(0, 0.01)
	await wait_seconds(0.2)
	var after := _parts(root)
	assert_lt(after["flames"].size(), before, "its flames gone")
	assert_eq(after["smoke"].size(), view.fires.size() - 1, "its smoke column gone")
	assert_true(view.fires[0]["out"], "out")
