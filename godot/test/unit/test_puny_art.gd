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


func test_looks_pick_the_roles_colourways() -> void:
	assert_eq(PunyArt.hero("ranger")["sheet"], "characters/Archer-Green.png", "look 0 is the classic")
	assert_eq(PunyArt.hero("ranger", 1)["sheet"], "characters/Archer-Purple.png")
	assert_eq(PunyArt.hero("ranger", 3)["sheet"], "characters/Archer-Purple.png", "the web's four looks wrap")
	assert_eq(PunyArt.hero("rogue", null)["sheet"], "characters/Soldier-Red.png", "older saves have no look")
	assert_eq(PunyArt.looks("rogue"), 3)
	for role_id: String in PunyArt.HEROES:
		for look in PunyArt.looks(role_id):
			assert_true(ResourceLoader.exists(PunyArt.path(PunyArt.hero(role_id, look)["sheet"])), "%s look %d" % [role_id, look])


## No loop holds a sheet's white hit flash (Slime.png keeps one in its strip
## at frame 6): walking monsters never blink white.
func test_no_loop_flashes_white() -> void:
	for monster_id: String in PunyArt.MONSTERS:
		var frames := PunyArt.frames(PunyArt.monster(monster_id))
		for anim: String in frames.get_animation_names():
			if not frames.get_animation_loop(anim):
				continue
			for i in frames.get_frame_count(anim):
				assert_false(_all_white(frames.get_frame_texture(anim, i)), "%s %s frame %d" % [monster_id, anim, i])


func _all_white(texture: Texture2D) -> bool:
	var image := texture.get_image()
	var opaque := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			opaque += 1
			if pixel.r < 0.85 or pixel.g < 0.85 or pixel.b < 0.85:
				return false
	return opaque > 0


## The columns a walk steps through, by its frames' place on the sheet.
func _columns(frames: SpriteFrames, anim: String, size: int) -> Array:
	var out := []
	for i in frames.get_frame_count(anim):
		out.append(int((frames.get_frame_texture(anim, i) as AtlasTexture).region.position.x) / size)
	return out


## PIX-243: the hero passes through Shade's rise between the two steps (his
## Mini World walks' order), a pixel up as the feet pass.
func test_the_hero_walks_four_beats() -> void:
	var frames := PunyArt.frames(PunyArt.plain("warrior", 0))
	for dir in DIRS:
		assert_eq(_columns(frames, "walk_" + dir, 32), [1, 2, 1, 3], dir)


## PIX-243: Mini World's walkers stand in column 0 and walk 1-4; the old
## walk (0-3) never put the second foot down.
func test_villagers_put_both_feet_down() -> void:
	var frames := PunyArt.frames(PunyArt.villager("villager"))
	assert_eq(_columns(frames, "walk_down", 16), [1, 2, 3, 4])
	var one := frames.get_frame_texture("walk_down", 1).get_image()
	var other := frames.get_frame_texture("walk_down", 3).get_image()
	assert_ne(one.get_data(), other.get_data(), "a step on each foot")
	var king := PunyArt.frames(PunyArt.monster("king_slime"))
	assert_eq(king.get_frame_count("walk_down"), 6, "the king slime's whole hop, not cut at the top")


func test_every_walk_frame_is_drawn() -> void:
	var specs := {}
	for role_id: String in PunyArt.HEROES:
		specs[role_id] = PunyArt.hero(role_id)
	for id: String in PunyArt.VILLAGERS:
		specs[id] = PunyArt.villager(id)
	for id: String in PunyArt.MONSTERS:
		specs[id] = PunyArt.monster(id)
	for who: String in specs:
		var frames := PunyArt.frames(specs[who])
		for anim: String in frames.get_animation_names():
			if not anim.begins_with("walk"):
				continue
			for i in frames.get_frame_count(anim):
				assert_true(frames.get_frame_texture(anim, i).get_image().get_used_rect().has_area(), "%s %s frame %d" % [who, anim, i])


## Which side of the cell `image`'s near-white pixels (a fang, a blade's arc)
## lie on, weighed by how many and how far: positive to the right.
func _white_side(image: Image) -> float:
	var middle := image.get_width() / 2.0
	var sum := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5 and pixel.r > 0.86 and pixel.g > 0.86 and pixel.b > 0.86:
				sum += x + 0.5 - middle
	return sum


## PIX-243: PunyMonsters turn clockwise like the characters - the wolf bites
## with its fangs to the right in row 2 (and walks in the bite's row), so the
## beasts no longer walk backwards.
func test_beasts_face_the_way_they_walk() -> void:
	var frames := PunyArt.frames(PunyArt.monster("wolf"))
	assert_gt(_white_side(frames.get_frame_texture("attack_right", 0).get_image()), 0.0, "fangs to the right")
	assert_lt(_white_side(frames.get_frame_texture("attack_left", 0).get_image()), 0.0, "fangs to the left")


## PIX-243: Mini World draws a side row's swing on the side it faces, and its
## walk the same way round: walking right is drawn like swinging right.
func test_mini_world_fighters_face_the_way_they_walk() -> void:
	for id in ["pirate", "goblin_digger", "imp", "iron_demon", "wendigo"]:
		var frames := PunyArt.frames(PunyArt.monster(id))
		# The whole swing in that row (the attack plays its wind-up), the
		# blade's arc on the side it faces.
		var first := frames.get_frame_texture("attack_right", 0) as AtlasTexture
		var sheet := first.atlas.get_image()
		var swing := 0.0
		for column in sheet.get_width() / 16:
			swing += _white_side(sheet.get_region(Rect2i(column * 16, int(first.region.position.y), 16, 16)))
		assert_gt(swing, 0.0, "%s swings right to the right" % id)
		var right := frames.get_frame_texture("attack_right", 0).get_image()
		assert_lt(_unlike(frames.get_frame_texture("walk_right", 0).get_image(), right), _unlike(frames.get_frame_texture("walk_left", 0).get_image(), right), "%s walks right facing right" % id)


## How many pixels differ between two frames of one size.
func _unlike(one: Image, other: Image) -> int:
	var count := 0
	for y in one.get_height():
		for x in one.get_width():
			if not one.get_pixel(x, y).is_equal_approx(other.get_pixel(x, y)):
				count += 1
	return count


## PIX-243: sheets laid out apart from their family (PunyArt.LAYOUTS).
func test_odd_sheets_walk_their_own_way() -> void:
	# The troll's sheet draws one side: walking left is its right, mirrored.
	var troll := PunyArt.frames(PunyArt.monster("troll"))
	for i in troll.get_frame_count("walk_right"):
		var mirrored := troll.get_frame_texture("walk_right", i).get_image()
		mirrored.flip_x()
		assert_eq(troll.get_frame_texture("walk_left", i).get_image().get_data(), mirrored.get_data(), "troll frame %d" % i)
	assert_eq(_columns(troll, "walk_right", 16), [0, 1, 2, 3], "not its swing")
	# The mammoth's first two rows are its sides, mirror images of each other.
	var mammoth := PunyArt.frames(PunyArt.monster("golem"))
	var side := mammoth.get_frame_texture("walk_right", 0).get_image()
	side.flip_x()
	assert_lt(_unlike(mammoth.get_frame_texture("walk_left", 0).get_image(), side), 40, "side on both ways")
	assert_gt(_unlike(mammoth.get_frame_texture("walk_down", 0).get_image(), side), 60, "and its front walking down")
