extends GutTest
## Everyone on screen has a Puny sheet (PIX-130): every role, every villager the
## web game names, every species in the bestiary, with the animations the
## scene scripts ask for in all four directions.

const DIRS := ["down", "right", "up", "left"]


func _assert_walks_everywhere(spec: Dictionary, who: String) -> void:
	assert_true(ResourceLoader.exists(PunyArt.path(spec["sheet"])), "%s: missing %s" % [who, spec["sheet"]])
	var frames := PunyArt.frames(spec)
	if spec["family"] == "strip":
		assert_true(frames.has_animation("walk"), "%s: no walk" % who)
		return
	for dir in DIRS:
		assert_true(frames.has_animation("walk_" + dir), "%s: no walk_%s" % [who, dir])
		assert_gt(frames.get_frame_count("walk_" + dir), 1, "%s: walk_%s doesn't move" % [who, dir])


func test_every_role_fights_in_four_directions() -> void:
	for role_id: String in Catalog._data()["roles"]:
		var spec := PunyArt.hero(role_id)
		assert_true(PunyArt.HEROES.has(role_id), "%s falls back to the warrior" % role_id)
		_assert_walks_everywhere(spec, role_id)
		var frames := PunyArt.frames(spec)
		for anim in ["idle", spec["attack"], "hurt", "death"]:
			for dir in DIRS:
				assert_true(frames.has_animation("%s_%s" % [anim, dir]), "%s: no %s_%s" % [role_id, anim, dir])


func test_every_villager_the_web_names_has_a_sheet() -> void:
	var sprites := {}
	for npc: Dictionary in Npcs._data()["npcs"]:
		sprites[npc["sprite"]] = true
	for recruit: Dictionary in Npcs._data()["recruits"]:
		sprites[recruit["sprite"]] = true
	for sprite: String in sprites:
		assert_true(PunyArt.VILLAGERS.has(sprite), "%s would fall back" % sprite)
		_assert_walks_everywhere(PunyArt.villager(sprite), sprite)


func test_every_species_has_a_sheet() -> void:
	for id: String in Bestiary._data()["monsters"]:
		assert_true(PunyArt.MONSTERS.has(id), "%s would fall back to the slime" % id)
		_assert_walks_everywhere(PunyArt.monster(id), id)


func test_pick_falls_back_to_what_the_sheet_draws() -> void:
	var slime := PunyArt.frames(PunyArt.monster("slime"))
	assert_eq(PunyArt.pick(slime, "attack", "left"), "walk", "a strip has one walk for every way")
	var hero := PunyArt.frames(PunyArt.hero("warrior"))
	assert_eq(PunyArt.pick(hero, "sword", "up"), "sword_up")
	assert_eq(PunyArt.pick(hero, "attack", "up"), "walk_up", "heroes swing their weapon instead")


func test_frames_are_shared_per_sheet() -> void:
	assert_same(PunyArt.frames(PunyArt.monster("skeleton")), PunyArt.frames(PunyArt.monster("skeleton")))
