extends Screen
## What's new (the web's Changelog page): every release, newest first, its
## version, codename and date over its notes, in one scrolling window. Opened
## from the version line on the title. W/S or the wheel scroll; Esc closes.
## The notes come from assets/data/changelog.json, whose newest release is
## the game's version.

const SCROLL_STEP := 48

var scroll: ScrollContainer


static func releases() -> Array:
	return Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/changelog.json")))["releases"]


func _open() -> void:
	layer = 8
	dim(1.0)
	var title := UiStyle.heading("What's new", 20, UiStyle.CREAM, Vector2(0, 28))
	title.custom_minimum_size = Vector2(1280, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var window := PanelContainer.new()
	window.position = Vector2(140, 76)
	window.custom_minimum_size = Vector2(1000, 560)
	window.size = Vector2(1000, 560)
	window.add_theme_stylebox_override("panel", UiStyle.window(18))
	add_child(window)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	for release: Dictionary in releases():
		column.add_child(_release(release))

	add_child(UiStyle.screen_footer("{key:move_up}/{key:move_down}  scroll      Esc  close"))


## One release: "v0.70.0  Timber and Plaster" with its date, then its notes.
func _release(release: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	card.add_child(head)
	head.add_child(UiStyle.strong("v%s" % release["version"], 16, UiStyle.LAMP))
	var name := UiStyle.strong(release["codename"], 16, UiStyle.INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiStyle.label(release["date"], 12, UiStyle.FADED))
	for note: String in release["notes"]:
		var line := UiStyle.label("·  " + note, 12, UiStyle.INK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(940, 0)
		card.add_child(line)
	return card


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void: scroll.scroll_vertical += SCROLL_STEP
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void: scroll.scroll_vertical -= SCROLL_STEP
	return command
