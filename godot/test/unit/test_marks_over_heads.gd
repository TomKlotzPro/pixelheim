extends GutTest
## The marks over heads sit centred on them (PIX-268: Tom found the "!" over
## a villager a pixel left of their head). A quest's "!" and "?" are centred
## by the glyph's ink on the head of every villager sheet, whichever way they
## face, in whole pixels; a monster's alert and fright bubbles on its head;
## the words and numbers floating over the world on where they happened. The
## heads are read off the art here, apart from Ink, so the two check each
## other.

const Npc := preload("res://scripts/npc.gd")
const Enemy := preload("res://scripts/enemy.gd")


func _face() -> Font:
	return UiStyle.bold_font()


## The middle of the figure's top HEAD_ROWS drawn rows in `anim`'s first
## frame, as a centred sprite at `at` and `scale` draws it, read pixel by
## pixel.
func _head_middle(frames: SpriteFrames, anim: String, at: Vector2, scale: float) -> float:
	var image := _image(frames.get_frame_texture(anim, 0))
	var top := _top(image)
	var left := image.get_width()
	var right := -1
	for y in range(top, mini(top + PunyArt.HEAD_ROWS, image.get_height())):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				left = mini(left, x)
				right = maxi(right, x)
	return at.x + ((left + right + 1) / 2.0 - image.get_width() / 2.0) * scale


## The highest any frame of their idle and walk draws, every way they face.
func _crown(frames: SpriteFrames, at: Vector2, scale: float) -> float:
	var highest := INF
	for way: String in PunyArt.DIRS:
		for anim: String in [PunyArt.pick(frames, "idle", way), PunyArt.pick(frames, "walk", way)]:
			for i in frames.get_frame_count(anim):
				var image := _image(frames.get_frame_texture(anim, i))
				highest = minf(highest, at.y + (_top(image) - image.get_height() / 2.0) * scale)
	return highest


func _image(frame: Texture2D) -> Image:
	var cut := frame as AtlasTexture
	return cut.atlas.get_image().get_region(Rect2i(cut.region))


func _top(image: Image) -> int:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return y
	return 0


func test_a_glyph_is_measured_by_its_ink_not_its_box() -> void:
	# Pixeloid Bold's "!" is two pixels wide with a pixel of spacing after
	# it: centred on its box it leaned half a pixel left, and the box itself,
	# measured out of the tree, was the fallback face's at twice the size.
	assert_eq(Ink.of_text("!", _face(), UiStyle.BODY_PX), Rect2(0, 2, 2, 7))
	assert_eq(Ink.of_text("?", _face(), UiStyle.BODY_PX), Rect2(0, 2, 6, 7))
	assert_eq(_face().get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.BODY_PX).x, 3.0, "its box runs a pixel past its ink")
	assert_eq(Ink.of_text("!", _face(), UiStyle.TEXT), Rect2(0, 4, 4, 14), "at 2x, every pixel twice")
	assert_eq(Ink.of_text("12", _face(), UiStyle.BODY_PX), Rect2(0, 2, 13, 7), "a word's ink runs across its glyphs")
	assert_eq(Ink.of_text("", _face(), UiStyle.BODY_PX), Rect2(), "nothing drawn, no ink")


func test_a_head_is_the_figures_top_rows() -> void:
	var farmer := PunyArt.frames(PunyArt.villager("villager"))
	assert_eq(Ink.head(farmer, "idle_down"), Rect2(-5, -6, 10, 7), "a farmer's head, from the frame's middle")
	assert_eq(Ink.head(farmer, "idle_down", Vector2(0, -3), Vector2.ONE * 0.75), Rect2(-3.75, -7.5, 7.5, 5.25), "where the sprite draws it")
	# Rook's head isn't over his frame's middle, and it moves as he turns.
	var rook := PunyArt.frames(PunyArt.villager("smuggler"))
	assert_eq(Ink.head(rook, "idle_down").get_center().x, -1.0)
	assert_eq(Ink.head(rook, "idle_right").get_center().x, -2.0)
	assert_eq(Ink.rest_pose(rook, "walk_right"), "idle_right", "a step is measured at rest")
	assert_eq(Ink.crown(farmer, ["idle_down", "walk_down"]), -7.0, "the walk's rise reaches a pixel higher than the idle")


func test_whole_pixels_lean_the_same_way() -> void:
	assert_eq(Ink.centred(Rect2(0, 0, 2, 7), 0.0), -1.0)
	assert_eq(Ink.centred(Rect2(0, 0, 2, 7), 0.5), 0.0, "half a pixel over, to the right")
	assert_eq(Ink.centred(Rect2(0, 0, 2, 7), -0.5), -1.0, "and to the right on the left too")
	assert_eq(Ink.centred(Rect2(0, 0, 13, 7), 100.0), 94.0)


func test_a_villagers_mark_is_centred_on_their_head_every_way_they_face() -> void:
	for sprite: String in PunyArt.VILLAGERS:
		var art := PunyArt.villager(sprite)
		var size: float = art.get("scale", 1.0)
		var frames := PunyArt.frames(art)
		# As the villager's sprite stands (npc.gd).
		var at := Vector2(0, PunyArt.lift(art) * size)
		var crown := _crown(frames, at, size)
		for text: String in ["!", "?"]:
			var ink := Ink.of_text(text, _face(), UiStyle.BODY_PX)
			for way: String in PunyArt.DIRS:
				var head := _head_middle(frames, PunyArt.pick(frames, "idle", way), at, size)
				for anim: String in [PunyArt.pick(frames, "idle", way), PunyArt.pick(frames, "walk", way)]:
					var spot: Vector2 = Npc.mark_spot(text, frames, anim, at, Vector2.ONE * size)
					var who := "%s's %s, %s" % [sprite, text, anim]
					assert_eq(spot, spot.round(), "%s: on whole pixels" % who)
					assert_almost_eq(spot.x + ink.get_center().x, head, 0.5, "%s: centred on the head" % who)
					var gap := crown - (spot.y + ink.end.y)
					assert_true(gap >= 2.0 and gap < 3.0, "%s: two pixels over the head's highest (%s)" % [who, gap])


func test_the_old_box_centring_missed_by_a_pixel() -> void:
	# What Tom saw (v0.193): the "!" box-centred sat its ink a pixel left of
	# a farmer's head; the "?" three.
	var frames := PunyArt.frames(PunyArt.villager("villager"))
	var head := _head_middle(frames, "idle_down", Vector2(0, -3), 1.0)
	var fallback_box := {"!": 4.0, "?": 12.0}
	for text: String in fallback_box:
		var ink := Ink.of_text(text, _face(), UiStyle.BODY_PX)
		var old := roundf(-fallback_box[text] / 2.0) + ink.get_center().x
		assert_gt(absf(old - head), 0.5, "%s was off" % text)
		var spot: Vector2 = Npc.mark_spot(text, frames, "idle_down", Vector2(0, -3), Vector2.ONE)
		assert_eq(spot.x + ink.get_center().x, head, "%s is centred now" % text)


func test_the_alerts_bang_is_the_middle_of_its_bubble() -> void:
	var sides := Enemy.bubble_sides()
	var ink := Ink.of_text("!", _face(), UiStyle.TEXT)
	var box := _face().get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT).x
	var width := sides.x + box + sides.y
	assert_eq(sides.x + ink.get_center().x, width / 2.0, "the ink in the middle")
	assert_eq(width * Enemy.BUBBLE_SCALE, roundf(width * Enemy.BUBBLE_SCALE), "a whole number of art pixels wide")
	assert_eq(sides.x - ink.position.x, Enemy.BUBBLE_PAD, "its pad off the ink each side")


## Every monster's alert and fright bubble, laid out by their containers as
## in the world, every way it faces.
func test_a_monsters_bubbles_are_centred_on_its_head() -> void:
	var laid := []
	for species: String in PunyArt.MONSTERS:
		var art := PunyArt.monster(species)
		var size: float = art.get("scale", 1.0)
		var frames := PunyArt.frames(art)
		for way: String in PunyArt.DIRS:
			var foe: Enemy = autofree(Enemy.new())
			foe.fighter = Bestiary.spawn(species)
			foe.sprite = autofree(AnimatedSprite2D.new())
			foe.sprite.sprite_frames = frames
			foe.sprite.play(PunyArt.pick(frames, "walk", way))
			foe._rest_at = Vector2(0, PunyArt.lift(art) * size)
			foe._rest_scale = Vector2.ONE * size
			for ink_color: Color in [Color("d8433f"), Juice.FRIGHT_INK]:
				var bubble: PanelContainer = foe._bubble(ink_color)
				add_child_autofree(bubble)
				var head := _head_middle(frames, PunyArt.pick(frames, "idle", way), foe._rest_at, size)
				laid.append([bubble, head, "%s facing %s" % [species, way]])
	await wait_physics_frames(2)
	var ink := Ink.of_text("!", _face(), UiStyle.TEXT)
	for entry: Array in laid:
		var bubble: PanelContainer = entry[0]
		var bang: Label = bubble.get_child(0)
		var middle := bubble.position.x + (bang.position.x + ink.get_center().x) * Enemy.BUBBLE_SCALE
		assert_eq(bubble.position, bubble.position.round(), "%s: on whole pixels" % entry[2])
		assert_almost_eq(middle, float(entry[1]), 0.5, "%s: centred on the head" % entry[2])


func test_words_over_the_world_are_centred_by_their_ink() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.float_text("dodged", Vector2(100, 50.4), UiStyle.CREAM)
	var word: Label = fx.get_child(0)
	assert_eq(word.position, word.position.round(), "on whole pixels")
	assert_almost_eq(word.position.x + Ink.of_text("dodged", _face(), UiStyle.BODY_PX).get_center().x, 100.0, 0.5)


func test_damage_numbers_land_about_the_foe_not_left_of_it() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var off := 0.0
	for i in 40:
		fx.float_number(12, Vector2(100, 50), Color.WHITE)
		var number: Label = fx.get_child(-1)
		var middle := number.position.x + Ink.of_text("12", _face(), UiStyle.BODY_PX).get_center().x
		assert_eq(number.position, number.position.round(), "on whole pixels")
		assert_almost_eq(middle, 100.0, 4.5, "a few pixels either way")
		off += middle - 100.0
	assert_almost_eq(off / 40.0, 0.0, 1.5, "about the foe on average (it sat five pixels left)")


func test_a_wins_row_is_centred_by_its_ink() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 12
	fx.show_gains(win, Vector2(100, 50))
	var row: Node2D = fx.get_child(0).get_child(0)
	var words: Label = row.get_node("text")
	assert_almost_eq(words.position.x + Ink.of_text(words.text, _face(), UiStyle.BODY_PX).get_center().x, 0.0, 0.5)
