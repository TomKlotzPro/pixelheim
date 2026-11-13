extends GutTest
## What stands over a foe's head keeps off the hero and off what rises and
## flies (PIX-469, PIX-470): the level tag makes way for a hero under it,
## a blow's number is drawn over the tags and clear of them from its first
## frame, and a foe's shot flies over them, a few pixels of it.

const TILE := 16.0


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
