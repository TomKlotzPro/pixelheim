class_name Layout
## Where a screen's pieces may go (Solid Ground, PIX-229/230): inside the
## canvas the player sees. Text grows (French runs a third longer than
## English), and a label that won't wrap widens its panel until the panel
## leaves the screen. Pure helpers: what runs past the view, for the harness
## and the tests.

## How far past the view's edge still counts as inside (a border's shadow).
const SLACK := 2.0
## Meta on a piece that moves past the edge on purpose (a shine sweeping in).
const DECOR := &"layout_decor"


## Every visible Control under the open screens of `root` whose rect runs
## past a `view`-sized canvas, or a list wider than it was laid out
## (`spills`): "screen path rect" lines, the outermost culprit of each branch
## only.
static func overflows(root: Node, view: Vector2) -> Array[String]:
	var out: Array[String] = []
	var bounds := Rect2(Vector2.ZERO, view).grow(SLACK)
	for layer in root.find_children("*", "", true, false):
		if layer is Screen and (layer as Screen).visible:
			_scan(layer, layer as CanvasLayer, bounds, out)
	return out


static func _scan(node: Node, layer: CanvasLayer, bounds: Rect2, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not control.is_visible_in_tree() or control.has_meta(DECOR):
				continue
			var rect := Rect2(control.get_global_rect().position + layer.offset, control.get_global_rect().size)
			if rect.size.x > 0.0 and rect.size.y > 0.0 and not bounds.encloses(rect):
				out.append("%s %s %s" % [layer.get_script().resource_path.get_file(), layer.get_path_to(control), rect])
				continue
			var spill := spills(control)
			if spill != "":
				out.append("%s %s %s" % [layer.get_script().resource_path.get_file(), layer.get_path_to(control), spill])
				continue
			# What scrolls may run long: its window is what must fit.
			if control is ScrollContainer:
				continue
		_scan(child, layer, bounds, out)


## Why `control` runs wider than its page, or "" (PIX-298): a scrolling
## window, or a list standing free on the screen, laid out at a width (its
## minimum's) that its rows pushed wider, or a scrolling window whose rows
## run under its scrollbar. The pack's rows, a long French name each, stood
## 75 px past its page, still well inside the canvas. A box inside another
## container is that container's to fit. Said as "<width> > <laid out>", or
## "<rows> > <room> |" beside a scrollbar: numbers only, no words for the
## catalogue to take for the player's.
static func spills(control: Control) -> String:
	var laid := control.custom_minimum_size.x
	var free := control is BoxContainer and not control.get_parent() is Container
	if (control is ScrollContainer or free) and laid > 0.0 and control.size.x > laid + SLACK:
		return "%d > %d" % [control.size.x, laid]
	if control is ScrollContainer:
		var scroll := control as ScrollContainer
		var bar := scroll.get_v_scroll_bar()
		var room := scroll.size.x - (bar.size.x if bar.visible else 0.0)
		for content in scroll.get_children():
			if content is Control and (content as Control).visible and (content as Control).size.x > room + SLACK:
				return "%d > %d |" % [(content as Control).size.x, room]
	return ""


## Empties `container` for a redraw: the old pieces leave at once, not at the
## frame's end, so for one frame the old and the new don't stand together
## (a menu twice its height for a blink).
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## `label` wrapping at `width`: a line too long for its panel breaks instead
## of widening the panel off the screen.
static func wrapped(label: Label, width: float) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label


## `label` on one line that gives way (PIX-298): it takes what its row
## leaves it, and words that run longer end in an ellipsis instead of
## widening the row past its page.
static func ellipsis(label: Label) -> Label:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## `label` as `ellipsis` makes it, in a row that leaves it `room`: true when
## its words will be cut, so the whole words can be shown elsewhere (the
## pack's strip under its list). Measured in the label's own font, so it
## holds before the label is in the tree.
static func shortened(label: Label, room: float) -> bool:
	ellipsis(label)
	return words_width(label) > room


## `label` no wider than `width` (PIX-298): words that run longer wrap onto
## a second line; shorter, it keeps its own width (unlike `wrapped`). For a
## row's note beside a name, so a long note (a salvage's materials, a
## trophy's power) never leaves the name no room.
static func narrowed(label: Label, width: float) -> Label:
	if words_width(label) > width:
		wrapped(label, width)
	return label


## How wide `label`'s words are on one line, in its font and size, in the
## player's language (a label translates what it's given as it draws it).
static func words_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	return font.get_string_size(label.tr(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


## `control`, standing free on a screen (placed, not in a container), kept
## to what it holds: a free Control grows with its content but never shrinks
## back, and a wrapped line measures itself tall for a frame before it knows
## its width, so the saves window's column stood 1366 px tall round a
## 530 px window, off the bottom of the canvas (PIX-230).
static func hugging(control: Control) -> Control:
	control.minimum_size_changed.connect(control.reset_size)
	return control


## A plank `button` no wider than `width` (PIX-230): its words, when they'd
## run longer ("Amener Aldegonde-Marie dans l'emplacement 3"), wrap onto a
## second line on the plank instead of widening its panel; shorter, it
## keeps its own width. A keyed plank (UiStyle.button_keyed) wraps the words
## beside its key. Call it once the button is in the tree (out of it, words
## measure in the fallback font), and again after the words change.
static func capped(button: Button, width: float) -> Button:
	var row := button.get_node_or_null("keyed") as Control
	if row == null:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 0.0
		if button.get_minimum_size().x > width:
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.x = width
		return button
	# The plank is its key and words and 24 px of wood (button_keyed).
	var words := row.get_child(1) as Label
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.custom_minimum_size.x = 0.0
	var room := width - 24.0 - (row.get_combined_minimum_size().x - words.get_minimum_size().x)
	if words.get_minimum_size().x > room:
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size.x = room
	button.custom_minimum_size = row.get_combined_minimum_size() + Vector2(24, 4)
	return button


## A row of buttons that flows onto a second line when the words are long
## (French), instead of widening its panel.
static func flow(separation := 10) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", separation)
	return row
