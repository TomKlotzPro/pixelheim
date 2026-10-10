extends GutTest
## A building rising on the town's tour (PIX-264): every project knows the
## ground it changes and the tour lifts all of it there, the camera stops
## where the project can be seen, and the stop says what it brings; an
## age's stop names who moved in with it.

const Lookbook := preload("res://scripts/lookbook.gd")


func _projects() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in Town.ages():
		for candidate: Dictionary in entry["projects"]:
			out.append(candidate["id"])
	return out


func _inside(footprint: Array[Rect2i], cell: Vector2i) -> bool:
	return footprint.any(func(rect: Rect2i) -> bool: return rect.has_point(cell))


func test_every_project_has_the_ground_it_changes() -> void:
	for project_id in _projects():
		var entry := Town.project(project_id)
		var footprint := Town.footprint(project_id)
		assert_false(footprint.is_empty(), "%s changes some ground" % project_id)
		for cell: Array in entry["tiles"]:
			assert_true(_inside(footprint, Vector2i(int(cell[0]), int(cell[1]))), "%s sets %s inside it" % [project_id, cell])
		for ruin: Dictionary in entry.get("ruins", []):
			var r: Array = ruin["rect"]
			assert_true(_inside(footprint, Vector2i(int(r[0]), int(r[1]))) and _inside(footprint, Vector2i(int(r[2]), int(r[3]))), "%s's ruin" % project_id)
	assert_eq(Town.footprint("the_inn").size(), 6, "the inn and its five homes")


## What the town draws differently once a project stands (its cells, its
## houses, its props and flowers) is all inside its footprint, so the tour
## shows the old ground there and lifts all of the new: nothing pops in
## elsewhere. The keepers' crates on the square go with them, not with the
## building, and the plots the next age stakes out come with the age.
func test_all_a_project_changes_is_lifted_at_its_stop() -> void:
	for project_id in _projects():
		var done := Town.projects_through(Town.age_of(project_id))
		var before_done := done.duplicate()
		before_done.erase(project_id)
		var after := MapData.load_tiered("town", done, 1)
		var before := MapData.load_tiered("town", before_done, 1)
		var footprint := Town.footprint(project_id)
		var elsewhere := Town.stall_crates(before_done)
		for site: Dictionary in Town.sites(done) + Town.sites(before_done):
			if site["project"] != project_id:
				for cell in _cells(site["rect"]):
					elsewhere[cell] = true
		for cell: Vector2i in after.grid:
			if after.grid[cell] != before.grid.get(cell) and not elsewhere.has(cell):
				assert_true(_inside(footprint, cell), "%s changes %s inside its footprint" % [project_id, cell])
		var houses_after := PunyTown.plan(after.grid)
		var houses_before := PunyTown.plan(before.grid)
		for part: String in ["pieces", "decor"]:
			var changed := {}
			for cell: Vector2i in houses_after[part]:
				if houses_after[part][cell] != houses_before[part].get(cell, -1):
					changed[cell] = true
			for cell: Vector2i in changed:
				assert_true(_inside(footprint, cell), "%s's house %s at %s is lifted" % [project_id, part, cell])
		var props_after := _props(PunyProps.plan(after.grid))
		var props_before := _props(PunyProps.plan(before.grid))
		for cell: Vector2i in props_after:
			if props_after[cell] != props_before.get(cell, "") and not elsewhere.has(cell):
				assert_true(_inside(footprint, cell), "%s's prop at %s springs up" % [project_id, cell])


func _cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


## A plan's props and flowers by cell, as what they draw.
func _props(plan: Dictionary) -> Dictionary:
	var out := {}
	for prop: Dictionary in plan["props"]:
		out[prop["cell"]] = "%s %s" % [prop["kind"], prop["tiles"]]
	for cell: Vector2i in plan["flat"]:
		out[cell] = "flowers %d" % plan["flat"][cell]
	return out


func test_the_camera_stops_where_the_project_is_seen() -> void:
	for project_id in _projects():
		var at := Town.project_center(project_id)
		var seen := Town.footprint(project_id).any(func(rect: Rect2i) -> bool:
			var near := Vector2i(clampi(at.x, rect.position.x, rect.end.x - 1), clampi(at.y, rect.position.y, rect.end.y - 1))
			var off := (near - at).abs()
			return off.x <= Town.SEEN.x and off.y <= Town.SEEN.y)
		assert_true(seen, "%s is in sight from its stop %s" % [project_id, at])
	var inn: Rect2i = Town.footprint("the_inn")[0]
	assert_true(inn.has_point(Town.project_center("the_inn")), "the inn itself, not the street between its homes")
	assert_eq(Town.project_center("odos_store"), Vector2i(30, 7), "a single building's middle, as it was")


func test_a_project_says_what_it_brings() -> void:
	var store := Town.brings("odos_store")
	assert_eq(store.size(), 2)
	assert_string_contains(store[0], "Merchant Odo", "the keeper back indoors")
	assert_eq(store[1], "Odo pays a tenth more for what you sell him.", "and the perk")
	assert_string_contains(Town.brings("the_inn")[0], "Innkeeper Sela")
	var lamps := Town.brings("street_lamps")
	assert_eq(lamps.size(), 1)
	assert_eq(lamps[0], String(Town.project("street_lamps")["blurb"]), "the builders' promise")
	for project_id in _projects():
		assert_false(Town.brings(project_id).is_empty(), "%s brings something" % project_id)


func test_an_age_names_who_moved_in_with_it() -> void:
	assert_has(Npcs.newcomers(2), "Mira the Weaver")
	assert_eq(Npcs.newcomers(3), ["Old Tomas"] as Array[String])
	for tier in range(1, Town.MAX_TIER + 1):
		var now := Npcs.on_map("town", tier, []).map(func(npc: Dictionary) -> String: return npc["name"])
		var then := Npcs.on_map("town", tier - 1, []).map(func(npc: Dictionary) -> String: return npc["name"])
		var arrived: Array[String] = []
		arrived.assign(now.filter(func(person: String) -> bool: return person not in then))
		assert_eq(Npcs.newcomers(tier), arrived, "age %d: whoever stands in town now and didn't" % tier)


func test_a_house_goes_up_bottom_course_first() -> void:
	var rows := RebuildRise.courses([Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 3), Vector2i(5, 1)])
	assert_eq(rows, [[Vector2i(0, 3)], [Vector2i(0, 2), Vector2i(1, 2)], [Vector2i(5, 1)]] as Array[Array])
	assert_true(RebuildRise.courses([]).is_empty())


func test_reduce_motion_cuts_to_the_building_after_a_beat() -> void:
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = true
	assert_eq(RebuildRise.seconds(), RebuildRise.STILL_BEAT)
	GameState.settings.reduce_motion = false
	assert_gt(RebuildRise.seconds(), RebuildRise.HOLD + RebuildRise.GIVE_SECONDS, "it stands after the ruin has given way")
	GameState.settings.reduce_motion = was


func test_a_clip_is_a_strip_of_its_frames_at_half_size() -> void:
	var frames: Array[Image] = []
	for i in 4:
		var frame := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		frame.fill(Color(i / 4.0, 0, 0))
		frames.append(frame)
	var strip := Lookbook.strip(frames)
	assert_eq(strip.get_size(), Vector2i(32 * 4, 18), "four across, one row")
	assert_almost_eq(strip.get_pixel(32 * 2 + 16, 9).r, 0.5, 0.02, "the third frame third")
	for shot_name: String in Lookbook.SHOTS:
		if Lookbook.SHOTS[shot_name].has("rise"):
			assert_false(Town.project(Lookbook.SHOTS[shot_name]["rise"]).is_empty(), "%s raises a project" % shot_name)
	assert_eq(Lookbook.CLIP_MARKS.size(), 4)
