extends GutTest
## What stands over a foe's head keeps off the hero and off what rises and
## flies (PIX-469, PIX-470): the level tag makes way for a hero under it,
## a blow's number is drawn over the tags and clear of them from its first
## frame, and a foe's shot flies over them, a few pixels of it.

const TILE := 16.0
const Enemy := preload("res://scripts/enemy.gd")


class StubHud extends RefCounted:
	func plates_over() -> Array[Rect2]:
		return []


## What Foes' pass over the words asks of the world.
class StubWorld extends Node2D:
	var player := Node2D.new()
	var map: RefCounted = null
	## Out of the tree: it has no world to follow.
	var camera_rig := CameraRig.new()
	var fx := WorldFx.new()
	var hud := StubHud.new()

	func _init() -> void:
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
	var over: Array = [foe.level_tag, foe.health_bar, foe.health_bar_back]
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
