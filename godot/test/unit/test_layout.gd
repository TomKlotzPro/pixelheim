extends GutTest
## Every screen fits (PIX-258): what runs past the canvas is found, what
## scrolls or sweeps in on purpose isn't, a redraw empties at once, and long
## words wrap or flow instead of widening their panel.

const VIEW := Vector2(1280, 720)


class Probe:
	extends Screen


func _screen() -> CanvasLayer:
	# A bare screen-like layer the scan recognises.
	var layer: CanvasLayer = autofree(Probe.new())
	add_child(layer)
	return layer


func test_a_panel_off_the_canvas_is_found() -> void:
	var layer := _screen()
	var inside := Panel.new()
	inside.position = Vector2(100, 100)
	inside.size = Vector2(200, 100)
	layer.add_child(inside)
	assert_eq(Layout.overflows(get_tree().root, VIEW).size(), 0, "a panel inside the canvas fits")
	var wide := Panel.new()
	wide.position = Vector2(1000, 100)
	wide.size = Vector2(400, 100)
	layer.add_child(wide)
	var found := Layout.overflows(get_tree().root, VIEW)
	assert_eq(found.size(), 1, "one that runs past the right edge is found")


func test_what_scrolls_or_sweeps_in_is_not_an_overflow() -> void:
	var layer := _screen()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 300)
	layer.add_child(scroll)
	var long := Control.new()
	long.custom_minimum_size = Vector2(280, 2000)
	scroll.add_child(long)
	var shine := ColorRect.new()
	shine.position = Vector2(-200, 50)
	shine.size = Vector2(18, 140)
	shine.set_meta(Layout.DECOR, true)
	layer.add_child(shine)
	assert_eq(Layout.overflows(get_tree().root, VIEW).size(), 0)


func test_a_redraw_empties_at_once() -> void:
	var box: VBoxContainer = autofree(VBoxContainer.new())
	for i in 3:
		box.add_child(Label.new())
	Layout.clear(box)
	assert_eq(box.get_child_count(), 0, "the old rows don't stand beside the new for a frame")


func test_long_words_wrap_or_flow() -> void:
	var label: Label = autofree(Layout.wrapped(Label.new(), 300.0))
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(label.custom_minimum_size.x, 300.0)
	var row: HFlowContainer = autofree(Layout.flow())
	assert_true(row is HFlowContainer, "buttons flow onto a second line")
