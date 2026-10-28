extends GutTest
## Tooltips, scrollbars and the mouse in the game's own look (PIX-384), not
## Godot's grey theme and the OS arrow: on a screen's CanvasLayer, past the
## root's theme, as every screen stands.


func before_all() -> void:
	UiStyle.setup()


func _on_a_screen(control: Control) -> Control:
	var layer: CanvasLayer = add_child_autofree(CanvasLayer.new())
	layer.add_child(control)
	return control


func test_a_tooltip_is_parchment_in_brass_with_ink() -> void:
	var words: Label = _on_a_screen(Label.new())
	words.theme_type_variation = &"TooltipLabel"
	var panel := words.get_theme_stylebox("panel", &"TooltipPanel")
	assert_true(panel is StyleBoxTexture and (panel as StyleBoxTexture).texture == UiStyle.tooltip().texture, "the tooltip's slip")
	assert_eq(words.get_theme_color("font_color"), UiStyle.INK)
	assert_eq(words.get_theme_font_size("font_size"), UiStyle.TEXT, "never below 2x")


func test_a_scrollbar_is_slim_brass_on_dark_wood() -> void:
	var bar: VScrollBar = _on_a_screen(VScrollBar.new())
	for item: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		assert_true(bar.get_theme_stylebox(item) is StyleBoxTexture, item)
	assert_ne(bar.get_theme_stylebox("grabber"), bar.get_theme_stylebox("grabber_highlight"), "hover lights it")
	assert_ne(bar.get_theme_stylebox("grabber"), bar.get_theme_stylebox("grabber_pressed"), "a press sinks it")
	# The pack's list leaves its bar 14 px (inventory_screen's LIST.x - 14).
	assert_lte(bar.get_combined_minimum_size().x, 8.0, "slim")


## Input has no getter for a custom cursor: what setup() hands it is pinned
## here, the arrow and the hand, each clicking at its very tip.
func test_the_cursor_clicks_at_its_tip_and_a_button_takes_the_hand() -> void:
	for hand: bool in [false, true]:
		var art := UiStyle.cursor(hand)
		var tip: Vector2i = UiStyle.HAND_TIP if hand else UiStyle.ARROW_TIP
		assert_lte(maxi(art.get_width(), art.get_height()), 32, "a browser shows it")
		assert_eq(art.get_pixelv(tip).to_html(), UiStyle.NIGHT.to_html(), "the hotspot is on the tip's outline")
		# Its top row is the tip alone, one art pixel or two, round the hotspot.
		var top := range(art.get_width()).filter(func(x: int) -> bool: return art.get_pixel(x, 0).a > 0.0)
		assert_true(top.size() <= 2 * UiStyle.UI_SCALE and tip.x >= top.min() and tip.x <= top.max(), "the tip, %s" % [top])
	var button: Button = autofree(UiStyle.button("Go", func() -> void: pass))
	assert_eq(button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
