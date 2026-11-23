extends GutTest
## What stands over a foe's head keeps off the hero and off what rises and
## flies (PIX-469, PIX-470): the level tag makes way for a hero under it,
## a blow's number is drawn over the tags and clear of them from its first
## frame, and a foe's shot flies over them, a few pixels of it.

const TILE := 16.0


class StubHud extends Hud:
	func plates_over() -> Array[Rect2]:
		return []


## What Foes' pass over the words asks of the world. The camera and the HUD
## stand out of the tree (the camera has no world to follow): the bare world
## frees them with itself.
class StubWorld extends "res://test/bare_world.gd":
	func _init() -> void:
		player = preload("res://test/bare_hero.gd").new()
		camera_rig = CameraRig.new()
		fx = WorldFx.new()
		hud = StubHud.new()
		for part: Node in [player, fx]:
			add_child(part)


## A real foe, its feet at `at` (as test_foes_rest's), its tag laid out.
func _foe(at: Vector2) -> Node:
	var foe: Node = Enemy.new()
	foe.fighter = Bestiary.spawn("slime")
	add_child_autofree(foe)
	foe.set_physics_process(false)
	foe.global_position = at
	foe.add_to_group("mobs")
	await wait_process_frames(2)
	return foe


## The real tag and bar over a real foe (PIX-469): gone with the hero in the
## cell above, back with the hero below.
func test_a_foes_tag_and_bar_make_way_for_the_hero_above_it() -> void:
	var foe: Node = await _foe(Vector2(200, 200))
	var over: Array = [foe.level_tag, foe.drawing.health_bar, foe.drawing.health_bar_back]
	assert_gt(foe.level_tag.get_global_rect().size.y, 0.0, "a tag laid out")
	for step in 3:
		foe.make_way(foe.global_position + Vector2(0, -TILE), 0.2)
	for words: CanvasItem in over:
		assert_eq(words.modulate.a, 0.0, "gone under the hero")
	for step in 3:
		foe.make_way(foe.global_position + Vector2(0, TILE), 0.2)
	for words: CanvasItem in over:
		assert_eq(words.modulate.a, 1.0, "back with the hero below")


## Foes' pass asks each foe to make way, and holds the hero's figure in the
## faded tag's place: a blow's number steps up clear of the hero.
func test_the_pass_fades_the_tag_and_keeps_numbers_off_the_hero() -> void:
	var world := StubWorld.new()
	add_child_autofree(world)
	autofree(world.camera_rig)
	var foes := Foes.new()
	foes.world = world
	foes.set_process(false)
	world.add_child(foes)
	var foe: Node = await _foe(Vector2(200, 200))
	foe.level_tag.visible = true
	world.player.global_position = foe.global_position + Vector2(0, -TILE)
	for step in 3:
		foes._process(0.2)
	assert_eq(foe.level_tag.modulate.a, 0.0, "the pass made the tag make way")
	var hero := Rect2(world.player.global_position + Foes.HERO.position, Foes.HERO.size)
	world.fx.float_number(14, foe.global_position + Vector2(0, -20), Color.WHITE)
	assert_eq(world.fx.shown().size(), 1)
	for word in world.fx.shown():
		assert_false(word.intersects(hero), "%s clear of the hero %s" % [word, hero])
		# PIX-515: stepped up over the hero's head, it read as damage taken.
		assert_gt(word.position.y, hero.position.y, "%s beside the hero %s, not over their head" % [word, hero])
	world.player.global_position = foe.global_position + Vector2(0, TILE)
	for step in 3:
		foes._process(0.2)
	assert_eq(foe.level_tag.modulate.a, 1.0, "and back")


## A foe's tag as Enemy lays it out, over its head: the foe's feet at `at`.
func _tag(at: Vector2) -> Rect2:
	return Rect2(at.x - 10.0, at.y - 18.0 - 9.0, 20.0, 9.0)


func test_a_tag_is_over_the_hero_in_the_cell_above_its_foe_only() -> void:
	var foe := Vector2(200, 200)
	assert_true(Foes.hero_under(_tag(foe), foe + Vector2(0, -TILE)), "the cell above: the playtest's rogue over the gunner")
	assert_true(Foes.hero_under(_tag(foe), foe + Vector2(8, -TILE)), "half a cell to the side of it")
	assert_false(Foes.hero_under(_tag(foe), foe + Vector2(0, TILE)), "below the foe")
	assert_false(Foes.hero_under(_tag(foe), foe + Vector2(TILE, 0)), "beside it")
	assert_false(Foes.hero_under(_tag(foe), foe + Vector2(0, -3 * TILE)), "well above")


func test_what_rises_and_flies_is_drawn_over_the_tags() -> void:
	assert_gt(Foes.OVER_TAGS, Foes.TAG_Z)
	var fx := WorldFx.new()
	add_child_autofree(fx)
	fx.float_number(14, Vector2(100, 100), Color.WHITE)
	fx.float_text("dodged", Vector2(100, 60), Color.WHITE)
	for stand: Node in fx.get_children():
		assert_gt((stand.get_meta("word") as Label).z_index, Foes.TAG_Z, "a word over the tags")
	var bolt := Firebolt.new()
	bolt.look = "ball"
	bolt.set_physics_process(false)
	add_child_autofree(bolt)
	assert_gt(bolt.z_index, Foes.TAG_Z, "a shot over the tags")
	assert_false(bolt.get_children().any(func(part: Node) -> bool: return part is Polygon2D), "no flash of its own: the gunner's sheet draws one")
	var plain := Firebolt.new()
	plain.look = "ball"
	plain.flash = true
	plain.set_physics_process(false)
	add_child_autofree(plain)
	assert_true(plain.get_children().any(func(part: Node) -> bool: return part is Polygon2D), "a flash for a shooter with no attack drawn")


## The number began behind the plate and stepped up a frame late: a blow
## landing after the frame's pass.
func test_a_number_is_clear_of_the_tag_from_its_first_frame() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	var tag := Rect2(90, 73, 20, 9)
	fx.keep_clear([tag] as Array[Rect2])
	fx.float_number(14, Vector2(100, 72), Color.WHITE)
	for word in fx.shown():
		assert_false(word.intersects(tag), "%s clear of the tag %s" % [word, tag])
	assert_eq(fx.shown().size(), 1)


## One cream pixel on the sand could not be seen: every shot drawn without
## the pack's strips is a few pixels of it, and all but the ember rimmed dark.
func test_no_shot_is_one_pixel() -> void:
	for along: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2(-1, -3).normalized()]:
		for kind: String in ["arrow", "ball", "flame"]:
			var shot := Firebolt.plain(kind, along)
			var drawn := Rect2()
			var rimmed := false
			for part: Node in shot.get_children():
				var rect := Rect2()
				if part is Line2D:
					var line := part as Line2D
					rect = Rect2(line.points[0], Vector2.ZERO).expand(line.points[1]).grow(line.width / 2.0)
					rimmed = rimmed or line.default_color == Firebolt.RIM
				else:
					rect = Rect2((part as ColorRect).position, (part as ColorRect).size)
					rimmed = rimmed or (part as ColorRect).color == Firebolt.RIM
				drawn = rect if drawn.size == Vector2.ZERO else drawn.merge(rect)
			assert_gte(maxf(drawn.size.x, drawn.size.y), 4.0, "%s along %s is %s" % [kind, along, drawn.size])
			assert_eq(rimmed, kind != "flame", "%s in a dark rim" % kind)
			shot.free()


## PIX-515: a blow's number on a foe under the hero stepped up clear of them
## and floated over the hero's head, where the damage they take is told. It
## comes up at the foe's side, its whole rise off the hero; the hero's own
## number stands over their head, off their face.
func test_a_blow_dealt_never_floats_over_the_heros_head() -> void:
	var world := StubWorld.new()
	add_child_autofree(world)
	autofree(world.camera_rig)
	world.fx.world = world
	var foe := Vector2(200, 200)
	world.player.global_position = foe + Vector2(0, -TILE)
	var hero := Rect2(world.player.global_position + Foes.HERO.position, Foes.HERO.size)
	world.fx.keep_clear([] as Array[Rect2], [] as Array[Rect2], [hero] as Array[Rect2])
	world.fx.float_number(14, foe + Vector2(0, -18), Color.WHITE, false, autofree(Node.new()))
	var dealt: Rect2 = world.fx.shown()[0]
	var rise := dealt.grow_individual(0.0, WorldFx.NUMBER_RISE, 0.0, 0.0)
	assert_false(rise.intersects(hero), "its whole rise %s off the hero %s" % [rise, hero])
	assert_gt(rise.position.y, hero.position.y, "never over their head")
	assert_true(dealt.position.x >= hero.end.x or dealt.end.x <= hero.position.x, "at the side")
	assert_lte(absf(dealt.get_center().x - foe.x), WorldFx.ASIDE_MOST + 4.5, "by its foe still")
	world.fx.float_number(6, world.player.global_position + Vector2(0, -22), Color.RED, false, world.player)
	var taken: Rect2 = world.fx.shown()[1]
	assert_almost_eq(taken.get_center().x, hero.get_center().x, 4.5, "the hero's own over them")
	assert_lte(taken.end.y, hero.position.y, "over their head, off their face")


## PIX-515 (review): with a number, a win or a mark at both sides of the
## foe already, the number stayed over it and stepped up over the hero's
## head all the same. It takes the far side then, off the hero's column.
func test_a_blow_dealt_in_a_crowd_keeps_off_the_heros_head() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	var foe := Vector2(200, 200)
	var hero := Rect2(foe + Vector2(0, -TILE) + Foes.HERO.position, Foes.HERO.size)
	var sides: Array[Rect2] = [hero, Rect2(foe.x - 34.0, foe.y - 40.0, 26.0, 40.0), Rect2(foe.x + 8.0, foe.y - 40.0, 26.0, 40.0)]
	fx.keep_clear([] as Array[Rect2], [] as Array[Rect2], sides)
	fx.float_number(14, foe + Vector2(0, -18), Color.WHITE, false, autofree(Node.new()))
	var dealt: Rect2 = fx.shown()[0]
	assert_true(dealt.position.x >= hero.end.x or dealt.end.x <= hero.position.x, "%s beside the hero %s, not over their head" % [dealt, hero])


## PIX-515 (review): blows joined into one number (PIX-334) jumped from
## side to side, each stepping aside of the number it replaced, 18 px left
## then right and 6 px lower at every blow. The number counts up where it
## was: over its foe, or at the same side of a hero standing there.
func test_blows_joined_count_up_in_one_place() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	var foe := Vector2(100, 200)
	var who: Node = autofree(Node.new())
	for blow in 4:
		fx.float_number(3, foe + Vector2(0, -18), Color.WHITE, false, who)
		assert_eq(fx.shown().size(), 1, "one number, the last on its way out")
		assert_almost_eq(fx.shown()[0].get_center().x, foe.x, 4.5, "blow %s over its foe" % (blow + 1))
	# Another foe, the hero in the cell over it.
	foe.x = 300.0
	var hero := Rect2(foe + Vector2(0, -TILE) + Foes.HERO.position, Foes.HERO.size)
	fx.keep_clear([] as Array[Rect2], [] as Array[Rect2], [hero] as Array[Rect2])
	var other: Node = autofree(Node.new())
	var side := 0.0
	for blow in 4:
		fx.float_number(3, foe + Vector2(0, -18), Color.WHITE, false, other)
		assert_eq(fx.shown().size(), 2, "the first foe's number and this one's")
		var at: Rect2 = fx.shown()[1]
		if blow == 0:
			side = signf(at.get_center().x - foe.x)
		assert_eq(signf(at.get_center().x - foe.x), side, "blow %s at the side the first took" % (blow + 1))
		assert_almost_eq(absf(at.get_center().x - foe.x), WorldFx.ASIDE_NEAR, 4.5, "and as near")


## PIX-515: a hound's 14 stood between its tag and the last hound's gold,
## three rows on one spot. With a win over its foe a number comes up beside
## the tag, its rise ending under the win; alone it rises over the tag as it
## did (test_a_number_is_clear_of_the_tag_from_its_first_frame).
func test_a_number_steps_aside_of_a_win_over_its_foe() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	var foe := Vector2(100, 200)
	var tag := Rect2(foe.x - 9.0, foe.y - 27.0, 18.0, 9.0)
	var gold := Gains.none()
	gold["gold"] = 8
	gold["xp"] = 18
	fx.show_gains(gold, foe + WorldFx.OVER_FOE)
	fx.keep_clear([tag] as Array[Rect2])
	fx.float_number(14, foe + Vector2(0, -18), Color.WHITE, false, autofree(Node.new()))
	assert_eq(fx.shown().size(), 2)
	var win: Rect2 = fx.shown()[0]
	var number: Rect2 = fx.shown()[1]
	assert_true(number.position.x >= tag.end.x or number.end.x <= tag.position.x, "%s beside the tag %s" % [number, tag])
	assert_gt(number.position.y - WorldFx.NUMBER_RISE, win.end.y, "its rise ends under the win %s" % win)
	# The next blow, the first number still up: at the other side.
	fx.float_number(9, foe + Vector2(0, -18), Color.WHITE, false, autofree(Node.new()))
	var next: Rect2 = fx.shown()[2]
	assert_false(next.grow(WorldFx.SLOT_MARGIN).intersects(number), "%s off the first %s" % [next, number])
	assert_false(next.grow(WorldFx.SLOT_MARGIN).intersects(win), "and off the win")


## PIX-515: at a level-up the killing blow's grey number touched LEVEL UP's
## underside. A big word keeps its air, from a word born before it and from
## one born after.
func test_a_big_word_keeps_its_air() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	fx.float_number(16, Vector2(100, 100), Color.WHITE)
	fx.float_text("LEVEL UP", Vector2(100, 96), Color.GOLD, true)
	fx.float_text("dodged", Vector2(100, 90), Color.WHITE)
	var number: Rect2 = fx.shown()[0]
	var big: Rect2 = fx.shown()[1]
	var after: Rect2 = fx.shown()[2]
	assert_gte(number.position.y - big.end.y, WorldFx.BIG_MARGIN, "over the number %s: %s" % [number, big])
	assert_gte(big.position.y - after.end.y, WorldFx.BIG_MARGIN, "under the next word %s" % after)
	# And a word just beside another steps up: a space apart, or over it
	# (a foe's 11 beside the hero's red 4 read "114").
	fx.float_text("4", Vector2(number.end.x + 3.0, 100), Color.RED)
	var beside: Rect2 = fx.shown()[3]
	assert_true(beside.position.x - number.end.x >= WorldFx.SIDE_AIR or beside.end.y < number.position.y, "%s no digit of %s" % [beside, number])


## PIX-515: at a level-up the two bursts on the hero hid them whole. Given
## the hero, a burst is drawn behind them and goes where they go.
func test_a_levels_burst_is_drawn_behind_the_hero() -> void:
	var fx := WorldFx.new()
	add_child_autofree(fx)
	fx.world = autofree(preload("res://test/bare_world.gd").new())
	var hero: Node2D = add_child_autofree(Node2D.new())
	hero.position = Vector2(40, 40)
	fx.skill_flash(Vector2(40, 32), Color.GOLD, true, hero)
	var bursts := hero.get_children().filter(func(node: Node) -> bool: return node is Sprite2D)
	assert_eq(bursts.size(), 1, "the hero's own")
	assert_true((bursts[0] as Sprite2D).show_behind_parent, "behind them")
	assert_eq((bursts[0] as Sprite2D).z_index, 0, "not over the actors")
	assert_eq((bursts[0] as Sprite2D).global_position, Vector2(40, 32))


## PIX-515: a hound's "!" stood over its level tag, two cells from it, on
## the shoulder of a hero above. It stands right over its head, the tag
## waiting until it has gone, and makes way for a hero under it as the tag
## does.
func test_a_foes_mark_has_its_tags_place_and_makes_way_for_the_hero() -> void:
	var foe: Node = await _foe(Vector2(200, 200))
	foe.drawing.alert(0.5)
	var mark: Sprite2D = foe.drawing.mark
	assert_eq(mark.position.y + mark.texture.get_height(), floorf(foe.drawing.bar_at - EnemyDrawing.MARK_CLEAR), "right over its head")
	foe.drawing.tick()
	assert_false(foe.level_tag.visible, "the tag waits for it")
	# A blow's number comes up beside it, not on it.
	var fx := WorldFx.new()
	add_child_autofree(fx)
	var burst: Rect2 = foe.drawing.mark_rect()
	assert_eq(burst.size, mark.texture.get_size(), "the mark's place, while it shows")
	fx.keep_clear([] as Array[Rect2], [] as Array[Rect2], [Rect2(0, 0, 12, 22), burst] as Array[Rect2])
	fx.float_number(13, foe.global_position + Vector2(0, -18), Color.WHITE, false, foe)
	var number: Rect2 = fx.shown()[0]
	assert_false(number.grow_individual(0.0, WorldFx.NUMBER_RISE, 0.0, 0.0).intersects(burst), "%s and its rise off the mark %s" % [number, burst])
	assert_true(number.position.x >= burst.end.x or number.end.x <= burst.position.x, "beside it")
	foe.make_way(foe.global_position + Vector2(0, -TILE), 0.2)
	assert_eq(mark.self_modulate.a, 0.0, "gone under the hero")
	foe.make_way(foe.global_position + Vector2(0, TILE), 0.2)
	assert_eq(mark.self_modulate.a, 1.0, "back with the hero below")
	mark.modulate.a = 0.0
	assert_false(foe.drawing._marked(), "faded: the tag's turn")
