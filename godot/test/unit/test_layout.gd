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


func test_words_on_the_dark_over_the_hud_are_found() -> void:
	# PIX-346: a footer's words over the dock, where the dock reads through
	# round them, are found; the same words on a window covering the spot (a
	# conversation over the dock) or clear of it are not.
	var layer := _screen()
	var dock: Array[Rect2] = [Rect2(252, 602, 776, 110)]
	var words := Label.new()
	words.text = "fermer"
	words.position = Vector2(400, 672)
	words.size = Vector2(80, 22)
	layer.add_child(words)
	assert_eq(Layout.over(get_tree().root, dock).size(), 1, "on the dark over the dock")
	var window := PanelContainer.new()
	window.position = Vector2(150, 520)
	window.size = Vector2(980, 180)
	layer.add_child(window)
	words.reparent(window, true)
	assert_eq(Layout.over(get_tree().root, dock).size(), 0, "on a window covering the spot")
	words.reparent(layer, true)
	words.position = Vector2(400, 300)
	assert_eq(Layout.over(get_tree().root, dock).size(), 0, "clear of the dock")


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


## PIX-298: a list laid out at a width that its rows push wider is found,
## though it stays on the canvas (the pack's rows ran 75 px past its page).
func test_a_list_pushed_wider_than_laid_out_is_found() -> void:
	var layer := _screen()
	var list := VBoxContainer.new()
	list.position = Vector2(100, 100)
	list.custom_minimum_size = Vector2(300, 0)
	layer.add_child(list)
	var row := Control.new()
	row.custom_minimum_size = Vector2(280, 40)
	list.add_child(row)
	await wait_process_frames(2)
	assert_eq(Layout.overflows(get_tree().root, VIEW).size(), 0, "rows inside the list's width")
	row.custom_minimum_size.x = 380
	await wait_process_frames(2)
	var found := Layout.overflows(get_tree().root, VIEW)
	assert_eq(found.size(), 1, "a row wider than the list: %s" % [found])


## PIX-298: a scrolling window its rows push wider is found; rows filling
## what its scrollbar leaves are not.
func test_rows_wider_than_their_scrolling_window_are_found() -> void:
	var layer := _screen()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.custom_minimum_size = Vector2(300, 200)
	scroll.size = scroll.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for i in 10:
		var row := Control.new()
		row.custom_minimum_size = Vector2(200, 40)
		rows.add_child(row)
	await wait_process_frames(3)
	assert_eq(Layout.overflows(get_tree().root, VIEW).size(), 0, "rows fill what the scrollbar leaves")
	rows.get_child(3).custom_minimum_size.x = 420
	await wait_process_frames(3)
	assert_eq(Layout.overflows(get_tree().root, VIEW).size(), 1, "one wide row widens the window")
	assert_string_ends_with(Layout.spills(scroll), "> 300", "wider than laid out")


## PIX-298: a name gives way to an ellipsis and says when it was cut; a
## note wraps only when it runs past its share.
func test_a_long_name_gives_way_and_a_long_note_wraps() -> void:
	var name: Label = autofree(UiStyle.strong("Grande hache d'acier cendré des forges profondes de perspicacité", 15, UiStyle.INK))
	assert_true(Layout.shortened(name, 300.0), "a 64-letter name doesn't fit 300 px")
	assert_true(name.clip_text and name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "it ends in an ellipsis")
	assert_false(Layout.shortened(autofree(UiStyle.strong("Bottes tisse-givre", 15, UiStyle.INK)), 300.0), "a short one is whole")
	var short: Label = autofree(Layout.narrowed(UiStyle.label("120 o", 16, UiStyle.LAMP), 200.0))
	assert_eq(short.autowrap_mode, TextServer.AUTOWRAP_OFF, "a short note keeps its line")
	assert_eq(short.custom_minimum_size.x, 0.0, "and its own width")
	var long: Label = autofree(Layout.narrowed(UiStyle.label("3 Lingot de fer, 2 Cuir épais, 1 Racine profonde", 16, UiStyle.LAMP), 200.0))
	assert_eq(long.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "a long one wraps")
	assert_eq(long.custom_minimum_size.x, 200.0, "within its share")
