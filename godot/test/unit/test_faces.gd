extends GutTest
## Everyone who talks has a look of their own (PIX-405): thirty-eight people
## shared sixteen sheets, Mini World's faceless farmers among them, and Odo
## was the hero's twin. With the paid pack's sample folk and without it (a
## `cc0` build), no two people who can meet look alike, none wears the
## hero's starting clothes, and the conversation's portrait holds the face.

const DialogueBoxScript := preload("res://scripts/dialogue_box.gd")


func after_each() -> void:
	PunyTown.withheld = false


func test_everyone_who_talks_resolves_to_a_look() -> void:
	for person: Dictionary in Npcs.people():
		assert_true(PunyArt.VILLAGERS.has(person["sprite"]), "%s's %s would fall back to a farmer" % [person["id"], person["sprite"]])
		for paid: bool in [true, false]:
			PunyTown.withheld = not paid
			var frames := PunyArt.frames(PunyArt.villager(person["sprite"]))
			assert_true(frames.get_frame_texture("idle_down", 0).get_image().get_used_rect().has_area(), "%s is drawn" % person["id"])


func test_no_two_people_who_meet_look_alike() -> void:
	for paid: bool in [true, false]:
		PunyTown.withheld = not paid
		var seen := {}
		for person: Dictionary in Npcs.people():
			var art := PunyArt.villager(person["sprite"])
			for map_id: String in person["maps"]:
				var key := "%s|%s@%s" % [map_id, PunyArt.look_of(art), art.get("scale", 1.0)]
				assert_false(seen.has(key), "%s and %s look alike on %s (paid art: %s)" % [person["id"], seen.get(key, ""), map_id, paid])
				seen[key] = person["id"]


func test_no_one_wears_the_heros_starting_clothes() -> void:
	var plain := PunyArt.look_of(PunyArt.plain("warrior"))
	for paid: bool in [true, false]:
		PunyTown.withheld = not paid
		for person: Dictionary in Npcs.people():
			var art := PunyArt.villager(person["sprite"])
			assert_ne(PunyArt.look_of(art), plain, "%s is the hero's twin" % person["id"])
			if art["sheet"] == PunyArt.PLAIN:
				assert_true(art.get("dye", {}).has("cloth"), "%s: the hero's red shirt" % person["id"])


func test_a_dye_names_shades_its_sheet_takes() -> void:
	for sprite: String in PunyArt.VILLAGERS:
		var entry: Dictionary = PunyArt.VILLAGERS[sprite]
		for part: String in entry.get("dye", {}):
			assert_true(PunyArt.SHADES.has(entry["dye"][part]), "%s's %s" % [sprite, part])
			var takes: bool = PunyArt.DYED.get(entry["sheet"], {}).has(part) or PunyArt.DYED.get(entry.get("paid", ""), {}).has(part)
			assert_true(takes, "%s's %s is dyed on neither sheet" % [sprite, part])


func test_a_dye_recolours_only_its_part() -> void:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	# A figure: hair at its top, the same brown as trousers at its feet, a shirt between.
	image.set_pixel(10, 4, Color("a66e46"))
	image.set_pixel(10, 20, Color("a66e46"))
	image.set_pixel(10, 14, Color("e1c48b"))
	var parts := {"head": 8, "hair": ["a66e46"], "dress": ["a66e46"], "cloth": ["e1c48b"]}
	var out := PunyArt.dyed(image, 32, parts, {"hair": "blonde", "cloth": "green"})
	assert_ne(out.get_pixel(10, 4), Color("a66e46"), "the hair dyed")
	assert_eq(out.get_pixel(10, 20), Color("a66e46"), "the trousers below the head left brown")
	assert_ne(out.get_pixel(10, 14), Color("e1c48b"), "the shirt dyed")
	assert_eq(out.get_pixel(0, 0).a, 0.0, "clear stays clear")


func test_the_portrait_holds_the_face() -> void:
	for paid: bool in [true, false]:
		PunyTown.withheld = not paid
		for person: Dictionary in Npcs.people():
			var frames := PunyArt.frames(PunyArt.villager(person["sprite"]))
			var head := Ink.head(frames, "idle_down")
			var bust: Rect2 = DialogueBoxScript.bust(frames)
			assert_true(bust.encloses(head), "%s's head %s in the portrait %s (paid art: %s)" % [person["id"], head, bust, paid])
			assert_gt(bust.end.y, head.end.y + 2, "%s: and their shoulders" % person["id"])
