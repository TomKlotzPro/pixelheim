extends GutTest
## Two foes side by side showed both their level tags, one over the other
## ("Ni Niv. 7"): the nearest keeps its tag, an overlapping one hides.


func test_the_nearest_tag_stays_and_one_over_it_hides() -> void:
	var near := Rect2(100, 100, 40, 12)
	var beside := Rect2(120, 104, 40, 12)
	var apart_far := Rect2(300, 100, 40, 12)
	assert_eq(Foes.apart([near, beside, apart_far]), [true, false, true] as Array[bool])


func test_tags_apart_all_show() -> void:
	assert_eq(Foes.apart([Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10)]), [true, true] as Array[bool])


func test_a_tag_hidden_doesnt_hide_the_next() -> void:
	# The second overlaps the first and hides; the third touches only the
	# second, so it shows.
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(8, 0, 10, 10), Rect2(16, 0, 10, 10)]
	assert_eq(Foes.apart(rects), [true, false, true] as Array[bool])


## PIX-340: three tags stacked two or three pixels apart don't intersect,
## and read as one block over the pack; a margin keeps them apart.
func test_tags_that_nearly_touch_are_kept_apart_by_the_margin() -> void:
	var near := Rect2(100, 100, 40, 12)
	var just_above := Rect2(100, 85, 40, 12)
	assert_eq(Foes.apart([near, just_above]), [true, true] as Array[bool], "three pixels apart: no overlap")
	assert_eq(Foes.apart([near, just_above], Foes.TAG_MARGIN), [true, false] as Array[bool], "within the margin: it hides")
	assert_eq(Foes.apart([near, Rect2(100, 80, 40, 12)], Foes.TAG_MARGIN), [true, true] as Array[bool], "eight pixels off: both")


## In a fight a pack shows one tag (PIX-340): foes within reach of one
## another (a chain of them) are one pack, led by its nearest.
func test_foes_close_together_are_one_pack_led_by_the_nearest() -> void:
	var reach := Foes.PACK_REACH
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(reach, 0), Vector2(reach * 2, 0), Vector2(reach * 10, 0)]
	assert_eq(Foes.packs(points, reach), [0, 0, 0, 3] as Array[int], "a chain is one pack; one far off is its own")
	assert_eq(Foes.packs([] as Array[Vector2], reach), [] as Array[int])
	var boss: Array[Vector2] = [Vector2(0, 0), Vector2.INF, Vector2(reach, 0)]
	assert_eq(Foes.packs(boss, reach), [0, 1, 0] as Array[int], "a boss (set nowhere) keeps its own tag")
