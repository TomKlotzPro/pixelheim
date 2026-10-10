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
