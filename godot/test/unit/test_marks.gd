extends GutTest
## The marks over the world (PIX-284, PIX-289: Tom found the arrow and the
## "!"s ugly): one family in the UI's palette, drawn a pixel per letter. The
## talk mark, the danger mark and the arrow are told apart by shape and
## colour; each is ringed in the night with a light inside, so it reads on
## grass and snow as in a cave; the arrow is drawn for eight ways (never
## turned, its pixels square), points the way it says, and is lit from the
## top left whichever way it points.


## Relative luminance (WCAG), for how far apart two inks stand.
func _luminance(color: Color) -> float:
	var lit := func(channel: float) -> float:
		return channel / 12.92 if channel <= 0.03928 else pow((channel + 0.055) / 1.055, 2.4)
	return 0.2126 * lit.call(color.r) + 0.7152 * lit.call(color.g) + 0.0722 * lit.call(color.b)


func _contrast(a: Color, b: Color) -> float:
	var hi := maxf(_luminance(a), _luminance(b))
	var lo := minf(_luminance(a), _luminance(b))
	return (hi + 0.05) / (lo + 0.05)


## Whether every drawn pixel on the picture's edge, or beside a clear one,
## is `line`: the mark is ringed all round.
func _ringed(art: Image, line: Color) -> bool:
	for y in art.get_height():
		for x in art.get_width():
			var here := art.get_pixel(x, y)
			if here.a < 1.0:
				continue
			var bare := false
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var at := Vector2i(x, y) + step
				if at.x < 0 or at.y < 0 or at.x >= art.get_width() or at.y >= art.get_height() or art.get_pixelv(at).a == 0.0:
					bare = true
			if bare and not here.is_equal_approx(line):
				return false
	return true


func test_the_marks_rows_are_whole_and_in_their_own_letters() -> void:
	var sets := {"talk": [Marks.TALK["!"], Marks.TALK["?"], "oLFSi"], "burst": [Marks.BURST, "oLRSi"], "arrow": [Marks.ARROW_RIGHT, Marks.ARROW_DOWN_RIGHT, "#"]}
	for name: String in sets:
		var letters: String = sets[name][-1]
		for rows: Array in sets[name].slice(0, -1):
			for row: String in rows:
				assert_eq(row.length(), String(rows[0]).length(), "%s: every row as wide" % name)
				for letter in row:
					assert_true(letter == "." or letters.contains(letter), "%s: %s is one of its letters" % [name, letter])
	for tones: Dictionary in [Marks.TALK_TONES, Marks.BURST_TONES]:
		for tone: String in tones:
			for letter: String in tones[tone]:
				assert_eq(tones[tone][letter].a, 1.0, "%s's %s is solid" % [tone, letter])


func test_every_mark_is_ringed_in_its_dark_line() -> void:
	for glyph: String in Marks.TALK:
		for tone: String in Marks.TALK_TONES:
			assert_true(_ringed(Marks.talk(glyph, tone).get_image(), UiStyle.NIGHT), "the talk mark %s, %s" % [glyph, tone])
	for tone: String in Marks.BURST_TONES:
		assert_true(_ringed(Marks.alert(tone).get_image(), Marks.BURST_TONES[tone]["o"]), "the %s mark" % tone)


func test_every_mark_reads_on_light_ground_and_dark() -> void:
	# The dark line stands off snow and sand, the fill off grass at night and
	# a cave's dark: each far from the other, and the glyph from its fill.
	for tone: String in Marks.TALK_TONES:
		var inks: Dictionary = Marks.TALK_TONES[tone]
		assert_gt(_contrast(inks["o"], inks["F"]), 7.0, "the talk mark's %s fill off its line" % tone)
		# A quest under way fades its "?" too, but not past reading.
		assert_gt(_contrast(inks["i"], inks["F"]), 2.5 if tone == "waiting" else 7.0, "its glyph off its fill (%s)" % tone)
	var danger: Dictionary = Marks.BURST_TONES["danger"]
	assert_gt(_contrast(danger["o"], danger["R"]), 3.0, "the burst's red off its line")
	assert_gt(_contrast(danger["i"], danger["R"]), 3.0, "its \"!\" off the red")
	for main: bool in [true, false]:
		var inks: Dictionary = Marks.ARROW_TONES["gold" if main else "cream"]
		assert_gt(_contrast(UiStyle.NIGHT, inks["F"]), 7.0, "the arrow's lit half off its line")
		assert_gt(_contrast(UiStyle.NIGHT, inks["S"]), 4.5, "and its shaded half")


func test_the_three_are_told_apart() -> void:
	# By colour: parchment and gold talk, red danger, gold or cream arrows.
	var red: Color = Marks.BURST_TONES["danger"]["R"]
	assert_gt(red.r - red.g, 0.4, "danger is red")
	for tone: String in ["plain", "gold"]:
		var fill: Color = Marks.TALK_TONES[tone]["F"]
		assert_lt(fill.r - fill.g, 0.25, "talk (%s) is no red" % tone)
	assert_ne(Marks.TALK_TONES["plain"]["F"], Marks.TALK_TONES["gold"]["F"], "the story's talk mark from a side quest's")
	# By shape: the talk mark narrows to its tail, the burst spikes out at its
	# sides and corners, the arrow's head is a right angle.
	var talk: Array = Marks.TALK["!"]
	var drawn := func(row: String) -> int: return row.length() - row.count(".")
	assert_lt(drawn.call(talk[-1]), drawn.call(talk[5]), "a pin's tail under the bubble")
	assert_eq(String(talk[-1]).find("o"), 4, "its tip under the middle")
	var burst: Array = Marks.BURST
	assert_eq([String(burst[6])[0], String(burst[0]).find("o"), String(burst[1])[2]], ["o", 6, "o"], "spikes left, up and at the corner")
	assert_ne(talk.size(), burst.size(), "not the same size either")


func test_the_arrow_is_drawn_for_eight_ways_never_turned() -> void:
	var size := Marks.arrow(0, true).get_size()
	for way in 8:
		var shape := Marks.arrow_shape(way)
		var heading := Vector2.RIGHT.rotated(way * PI / 4.0)
		var middle := (Vector2(String(shape[0]).length(), shape.size()) - Vector2.ONE) / 2.0
		# Its tip is the pixel furthest along its way, on its line.
		var tip := Vector2.ZERO
		var furthest := -INF
		for y in shape.size():
			for x in String(shape[y]).length():
				if String(shape[y])[x] == "#" and (Vector2(x, y) - middle).dot(heading) > furthest + 0.01:
					furthest = (Vector2(x, y) - middle).dot(heading)
					tip = Vector2(x, y)
		assert_almost_eq((tip - middle).dot(heading.orthogonal()), 0.0, 0.01, "way %d: its tip on its line" % way)
		assert_gt(furthest, 4.0, "way %d: and well out" % way)
		# Mirrored across its line, it is itself.
		for y in shape.size():
			for x in String(shape[y]).length():
				var p := Vector2(x, y) - middle
				var across := heading.orthogonal()
				var mirrored := (p - 2.0 * p.dot(across) * across + middle).round()
				if String(shape[y])[x] == "#" and mirrored.y >= 0 and mirrored.y < shape.size():
					assert_eq(String(shape[int(mirrored.y)])[int(mirrored.x)], "#", "way %d: even either side of its line at %s" % [way, Vector2(x, y)])
		for main: bool in [true, false]:
			assert_eq(Marks.arrow(way, main).get_size(), size, "way %d: as big as the others" % way)
			assert_true(_ringed(_without_shadow(Marks.arrow_art(way, main)), UiStyle.NIGHT), "way %d: ringed in the night" % way)


## The arrow's picture without its shadow (the shadow's pixels are
## half-clear), so the ring can be checked.
func _without_shadow(art: Image) -> Image:
	for y in art.get_height():
		for x in art.get_width():
			if art.get_pixel(x, y).a < 1.0:
				art.set_pixel(x, y, Color(0, 0, 0, 0))
	return art


func test_the_arrow_is_lit_from_the_top_left_whichever_way_it_points() -> void:
	var inks: Dictionary = Marks.ARROW_TONES["gold"]
	for way in 8:
		var art := Marks.arrow_art(way, true)
		var lit := _middle_of(art, [inks["L"], inks["F"]])
		var shaded := _middle_of(art, [inks["S"], inks["D"]])
		assert_true(lit != Vector2.INF and shaded != Vector2.INF, "way %d: a lit half and a shaded half" % way)
		assert_gt((lit - shaded).dot(Marks.LIGHT), 0.0, "way %d: the lit half toward the light" % way)
		var edges := _middle_of(art, [inks["L"]]) - _middle_of(art, [inks["D"]])
		assert_gt(edges.dot(Marks.LIGHT), 0.0, "way %d: its lit edge toward the light, its dark edge away" % way)


## Where the pixels of `inks` are on average in `art`, or INF for none.
func _middle_of(art: Image, inks: Array) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for y in art.get_height():
		for x in art.get_width():
			var here := art.get_pixel(x, y)
			if inks.any(func(ink: Color) -> bool: return here.is_equal_approx(ink)):
				sum += Vector2(x, y)
				count += 1
	return sum / count if count > 0 else Vector2.INF


func test_a_heading_takes_the_nearest_way() -> void:
	assert_eq(Marks.way_of(Vector2.RIGHT), 0)
	assert_eq(Marks.way_of(Vector2(1, 0.3)), 0, "a little down of right is right")
	assert_eq(Marks.way_of(Vector2(1, 0.8)), 1, "down-right")
	assert_eq(Marks.way_of(Vector2.DOWN), 2)
	assert_eq(Marks.way_of(Vector2(-1, -1)), 5, "up-left")
	assert_eq(Marks.way_of(Vector2(0.1, -1)), 6, "up")
	assert_eq(Marks.way_of(Vector2(1, -0.1)), 0, "and a hair above right, right again")
	# The arrow stands on its middle, whichever way it points.
	assert_eq(Marks.arrow_middle(), Vector2(13, 13), "past its dark line, in the UI's pixels")


func test_the_hud_arrow_points_without_turning() -> void:
	var arrow: Control = autofree(Hud.Arrow.new())
	arrow.way = 3
	arrow.main = false
	assert_eq(arrow.rotation, 0.0, "never turned: its pixels stay square")
	assert_eq(arrow.ink(), UiStyle.CREAM, "cream for a side quest")
	arrow.main = true
	assert_eq(arrow.ink(), UiStyle.GOLD, "gold for the story")
