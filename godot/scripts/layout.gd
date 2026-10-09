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
## past a `view`-sized canvas: "screen path rect" lines, the outermost
## culprit of each branch only.
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
			# What scrolls may run long: its window is what must fit.
			if control is ScrollContainer:
				continue
		_scan(child, layer, bounds, out)


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


## A row of buttons that flows onto a second line when the words are long
## (French), instead of widening its panel.
static func flow(separation := 10) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", separation)
	return row
