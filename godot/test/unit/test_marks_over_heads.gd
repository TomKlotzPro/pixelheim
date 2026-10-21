extends GutTest
## The marks over heads sit centred on them (PIX-268: Tom found the "!" over
## a villager a pixel left of their head). A quest's talk mark (Marks,
## PIX-289) is centred by its glyph on the head of every villager sheet,
## whichever way they face, in whole pixels; a monster's danger and fright
## marks on its head; the words and numbers floating over the world on where
## they happened. The heads are read off the art here, apart from Ink, so the
## two check each other.

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


## The middle of the glyph (`i`) in a mark's rows, in its own pixels.
func _glyph_middle(rows: Array) -> float:
	var left := 1000
	var right := -1
	for row: String in rows:
		for x in row.length():
			if row[x] == "i":
				left = mini(left, x)
				right = maxi(right, x)
	return (left + right + 1) / 2.0


func test_a_villagers_mark_is_centred_on_their_head_every_way_they_face() -> void:
	for sprite: String in PunyArt.VILLAGERS:
		var art := PunyArt.villager(sprite)
		var size: float = art.get("scale", 1.0)
		var frames := PunyArt.frames(art)
		# As the villager's sprite stands (npc.gd).
		var at := Vector2(0, PunyArt.lift(art) * size)
		var crown := _crown(frames, at, size)
		for glyph: String in Marks.TALK:
			var mark := Marks.talk(glyph, "plain").get_size()
			var middle := _glyph_middle(Marks.TALK[glyph])
			for way: String in PunyArt.DIRS:
				var head := _head_middle(frames, PunyArt.pick(frames, "idle", way), at, size)
				for anim: String in [PunyArt.pick(frames, "idle", way), PunyArt.pick(frames, "walk", way)]:
					var spot: Vector2 = Npc.mark_spot(mark, frames, anim, at, Vector2.ONE * size)
					var who := "%s's %s, %s" % [sprite, glyph, anim]
					assert_eq(spot, spot.round(), "%s: on whole pixels" % who)
					assert_almost_eq(spot.x + middle, head, 0.5, "%s: its glyph centred on the head" % who)
					var gap := crown - (spot.y + mark.y)
					assert_true(gap >= 1.0 and gap < 2.0, "%s: its tail a pixel over the head's highest (%s)" % [who, gap])


func test_the_old_box_centring_missed_by_a_pixel() -> void:
	# What Tom saw (v0.193): the "!" box-centred sat its ink a pixel left of
	# a farmer's head; the "?" three. The talk mark that replaced the glyph
	# (PIX-289) centres its glyph on the head.
	var frames := PunyArt.frames(PunyArt.villager("villager"))
	var head := _head_middle(frames, "idle_down", Vector2(0, -3), 1.0)
	var fallback_box := {"!": 4.0, "?": 12.0}
	for text: String in fallback_box:
		var ink := Ink.of_text(text, _face(), UiStyle.BODY_PX)
		var old := roundf(-fallback_box[text] / 2.0) + ink.get_center().x
		assert_gt(absf(old - head), 0.5, "%s was off" % text)
		var spot: Vector2 = Npc.mark_spot(Marks.talk(text, "plain").get_size(), frames, "idle_down", Vector2(0, -3), Vector2.ONE)
		assert_eq(spot.x + _glyph_middle(Marks.TALK[text]), head, "%s is centred now" % text)


func test_the_danger_marks_bang_is_its_middle() -> void:
	var size := Marks.alert().get_size()
	assert_eq(_glyph_middle(Marks.BURST), size.x / 2.0, "the \"!\" in the burst's middle columns")
	for glyph: String in Marks.TALK:
		assert_eq(_glyph_middle(Marks.TALK[glyph]), Marks.talk(glyph, "plain").get_width() / 2.0, "the talk mark's %s in its middle" % glyph)


## Every monster's danger and fright mark, placed as in the world, every way
## it faces.
func test_a_monsters_marks_are_centred_on_its_head() -> void:
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
			# Its words over its head as drawn (PIX-314).
			foe._over_head = Enemy.over_head(frames, foe._rest_at, size)
			var head := _head_middle(frames, PunyArt.pick(frames, "idle", way), foe._rest_at, size)
			for tone: String in Marks.BURST_TONES:
				var burst: Sprite2D = autofree(Enemy.alert_mark(tone))
				foe._place_mark(burst)
				var who := "%s's %s facing %s" % [species, tone, way]
				assert_eq(burst.position, burst.position.round(), "%s: on whole pixels" % who)
				assert_almost_eq(burst.position.x + burst.texture.get_width() / 2.0, head, 0.5, "%s: centred on the head" % who)
				assert_lt(burst.position.y + burst.texture.get_height(), foe._over_head - Enemy.TAG_HEIGHT, "%s: its foot over the level tag" % who)


func test_words_over_the_world_are_centred_by_their_ink() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.float_text("dodged", Vector2(100, 50.4), UiStyle.CREAM)
	var word: Label = fx.get_child(0).get_child(0)
	assert_eq(word.position, word.position.round(), "on whole pixels")
	assert_almost_eq(word.position.x + Ink.of_text("dodged", _face(), UiStyle.BODY_PX).get_center().x, 100.0, 0.5)


func test_damage_numbers_land_about_the_foe_not_left_of_it() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var off := 0.0
	for i in 40:
		fx.float_number(12, Vector2(100, 50), Color.WHITE)
		var number: Label = fx.get_child(-1).get_child(0)
		var middle := number.position.x + Ink.of_text("12", _face(), UiStyle.BODY_PX).get_center().x
		assert_eq(number.position, number.position.round(), "on whole pixels")
		assert_almost_eq(middle, 100.0, 4.5, "a few pixels either way")
		off += middle - 100.0
	assert_almost_eq(off / 40.0, 0.0, 1.5, "about the foe on average (it sat five pixels left)")


## Blows on one foe close together add up into one number (PIX-334: a
## pack's flurry read as a heap of numbers); another foe's is its own.
func test_blows_on_one_foe_close_together_add_up() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var foe: Node = autofree(Node.new())
	fx.float_number(12, Vector2(100, 50), Color.WHITE, false, foe)
	fx.float_number(13, Vector2(100, 50), Color.WHITE, false, foe)
	fx.float_number(4, Vector2(140, 50), Color.WHITE, false, autofree(Node.new()))
	await wait_frames(2)
	var shown: Array = fx.get_children().filter(func(stand: Node) -> bool: return not stand.is_queued_for_deletion())
	assert_eq(shown.map(func(stand: Node) -> String: return (stand.get_child(0) as Label).text), ["25", "4"])


## A number stepping up clear of a level tag (PIX-340: they stacked onto
## the pack's tags): the pass a frame lifts its stand over the tag.
func test_a_number_rises_clear_of_a_tag() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.float_number(12, Vector2(100, 50), Color.WHITE)
	var stand: Node2D = fx.get_child(0)
	var number: Label = stand.get_child(0)
	var ink := Ink.of_text("12", _face(), UiStyle.BODY_PX)
	var tag := Rect2(number.global_position + ink.position, ink.size).grow(2.0)
	fx.keep_clear([tag] as Array[Rect2])
	assert_lt(stand.position.y, 0.0, "lifted")
	assert_eq(stand.position.y, roundf(stand.position.y), "on whole pixels")
	assert_false(Rect2(number.global_position + ink.position, ink.size).intersects(tag), "clear of the tag")
	var lifted := stand.position.y
	fx.keep_clear([] as Array[Rect2])
	assert_eq(stand.position.y, lifted, "and never back down")


## A kill's win rises in the fight again (PIX-343), among the pack's tags:
## it steps up whole, just clear of a tag on its words, and stays there.
func test_a_win_rises_clear_of_a_tag() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 7
	win["gold"] = 36
	Gains.add_item(win, "wolf_pelt")
	fx.show_gains(win, Vector2(100, 50))
	var rows: Array = fx.get_child(0).get_children()
	var words := func() -> Array[Rect2]:
		var out: Array[Rect2] = []
		for row: Node in rows:
			var label: Label = row.get_node("text")
			out.append(Rect2(label.global_position + Ink.of_text(label.text, _face(), UiStyle.BODY_PX).position, Ink.of_text(label.text, _face(), UiStyle.BODY_PX).size))
		return out
	var gap: float = words.call()[0].position.y - words.call()[1].position.y
	var tag: Rect2 = words.call()[0].grow(2.0)
	fx.keep_clear([tag] as Array[Rect2])
	for rect: Rect2 in words.call():
		assert_false(rect.intersects(tag), "clear of the tag")
	assert_eq(words.call()[0].position.y - words.call()[1].position.y, gap, "its rows together")
	var lifted: float = words.call()[0].position.y
	fx.keep_clear([] as Array[Rect2])
	assert_eq(words.call()[0].position.y, lifted, "and never back down")


## PIX-345: at a boss's fall LEVEL UP rose into the boss bar and was cut.
## A word stays under the HUD's plates over it - stepping down under one
## it stands in, never lifted into one by a tag - and a win too, whole.
func test_what_rises_stays_under_a_plate_over_it() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.float_text("LEVEL UP", Vector2(100, 50), Color.WHITE, true)
	var word: Label = fx.get_child(0).get_child(0)
	var ink := Ink.of_text("LEVEL UP", _face(), UiStyle.BODY_PX)
	var drawn := func() -> Rect2: return Rect2(word.global_position + ink.position, ink.size)
	var bar := Rect2(0, drawn.call().position.y - 20, 300, 24)
	fx.keep_clear([] as Array[Rect2], [bar] as Array[Rect2])
	assert_false(drawn.call().intersects(bar), "stepped down under the bar")
	var tag: Rect2 = drawn.call()
	fx.keep_clear([tag] as Array[Rect2], [bar] as Array[Rect2])
	assert_false(drawn.call().intersects(bar), "a tag under it doesn't lift it into the bar")
	var win := Gains.none()
	win["xp"] = 100
	Gains.add_item(win, "wolf_pelt")
	fx.show_gains(win, Vector2(400, 50))
	var rows: Array = fx.get_child(1).get_children()
	var words := func() -> Array[Rect2]:
		var out: Array[Rect2] = []
		for row: Node in rows:
			var label: Label = row.get_node("text")
			out.append(Rect2(label.global_position + Ink.of_text(label.text, _face(), UiStyle.BODY_PX).position, Ink.of_text(label.text, _face(), UiStyle.BODY_PX).size))
		return out
	var gap: float = words.call()[0].position.y - words.call()[1].position.y
	var card := Rect2(300, words.call()[1].position.y - 10, 300, 20)
	fx.keep_clear([] as Array[Rect2], [card] as Array[Rect2])
	for rect: Rect2 in words.call():
		assert_false(rect.intersects(card), "the win under the card")
	assert_eq(words.call()[0].position.y - words.call()[1].position.y, gap, "its rows together")


func test_a_wins_row_is_centred_by_its_ink() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 12
	fx.show_gains(win, Vector2(100, 50))
	var row: Node2D = fx.get_child(0).get_child(0)
	var words: Label = row.get_node("text")
	assert_almost_eq(words.position.x + Ink.of_text(words.text, _face(), UiStyle.BODY_PX).get_center().x, 0.0, 0.5)
