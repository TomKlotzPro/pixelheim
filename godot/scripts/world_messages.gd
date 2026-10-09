class_name Messages
extends Node
## What the world tells the hero in words (Solid Ground, PIX-260: moved out
## of world.gd as it was): the message plate over the objective, where a
## quest taken or done, a level gained and the like wait their turn and hold
## long enough to read (PIX-194, PIX-211); and the battle log, recent lines
## stacking bottom-left and fading. The HUD calls build_log and build_plate
## where these always stood among its pieces; world.gd calls update() each
## frame.

var world: Node
## The battle log's lines (bottom-left, over the dock).
var log_box: VBoxContainer
## The message's plate and its tag (PIX-194): "Quest accepted", "Level up"...
var message_box: PanelContainer
var message_tag: Label
var message_label: Label
var message_fade: Tween
## How many lines the battle log keeps, and how long each stays.
const LOG_LINES := 6
const LOG_SECONDS := 4.0
## Tags a message may open with, set in gold on its plate.
const MESSAGE_TAGS := ["Quest accepted", "Quest complete", "Level up", "Mastery"]
## A plain message gives way to the next after this long; a tagged one
## (a quest, a level) is always read to its end (PIX-211).
const PLAIN_MESSAGE_S := 1.2
## The widest a message's words run before they wrap.
const MESSAGE_WIDTH := 860.0
## Lines the battle log has shown on this visit (the harness reports it: a
## kill's XP and gold float over the foe and add none, PIX-245).
var logged := 0


## The battle log, among the HUD's pieces where it always stood.
func build_log(hud: CanvasLayer) -> void:
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 3)
	log_box.position = Vector2(24, 506)
	log_box.custom_minimum_size = Vector2(700, 0)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(log_box)


## The message's plate, among the HUD's pieces where it always stood.
func build_plate(hud: CanvasLayer) -> void:
	# A message stands on the objective's plate, its tag in gold (PIX-194).
	message_box = PanelContainer.new()
	message_box.add_theme_stylebox_override("panel", UiStyle.plate())
	message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_box.modulate.a = 0.0
	var message_row := HBoxContainer.new()
	message_row.add_theme_constant_override("separation", 8)
	message_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_box.add_child(message_row)
	message_tag = UiStyle.plate_tag("")
	message_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	message_row.add_child(message_tag)
	message_label = UiStyle.plate_text("")
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_row.add_child(message_label)
	message_box.resized.connect(func() -> void: message_box.position.x = roundf((1280 - message_box.size.x) / 2.0))
	hud.add_child(message_box)


## Words and plates cleared away at once (the look book, between shots).
func clear() -> void:
	Layout.clear(log_box)
	_messages.clear()
	_message_now = ""
	if message_fade != null:
		message_fade.kill()
	message_box.modulate.a = 0.0


func log_line(line: String) -> void:
	log_lines([line])

## The battle log: recent lines stack bottom-left and fade. Only what the
## world doesn't show comes here (PIX-245): story beats, quests, levels, the
## boss slayer's edge, a pack scattered; what's won floats up where it was
## won (WorldFx.show_gains).
func log_lines(lines: Array) -> void:
	for line: String in lines:
		# A level gained goes on the plate, not among the kills (PIX-211).
		if tag_of(line, [Text.t("Level up")]) != "":
			flash(line)
			continue
		logged += 1
		# Each line on its own small plate, like the objective's (PIX-194).
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.plate(8))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.add_child(UiStyle.label(line, UiStyle.reading(12), UiStyle.CREAM))
		log_box.add_child(chip)
		var tween := chip.create_tween()
		tween.tween_interval(LOG_SECONDS)
		tween.tween_property(chip, "modulate:a", 0.0, 0.6)
		tween.tween_callback(chip.queue_free)
	while log_box.get_child_count() > LOG_LINES:
		var oldest := log_box.get_child(0)
		log_box.remove_child(oldest)
		oldest.queue_free()


## The message's plate, shrunk round its words (a container only grows).
func fit() -> void:
	message_box.size = Vector2.ZERO
	message_box.reset_size()


## Messages waiting their turn on the plate (PIX-211), the one showing,
## whether it carries a tag, and since when it shows.
var _messages: Array[String] = []
var _message_now := ""
var _message_tagged := false
var _message_since := 0.0


## A message for the objective's plate (PIX-211): it waits behind the one
## showing instead of cutting it off. A quest's end and the level it brings
## go up one after the other; the same words twice are said once. No words
## is no message (a chest whose loot floats up says nothing, PIX-245).
func flash(text: String) -> void:
	if text == "":
		return
	for part: String in split_messages(text, _tags()):
		if part != _message_now and part not in _messages:
			_messages.append(part)
	update()


func _tags() -> Array:
	return MESSAGE_TAGS.map(func(known: String) -> String: return Text.t(known))


## A line that starts with a known tag begins a message of its own; any
## other line belongs to the message before it.
static func split_messages(text: String, tags: Array) -> Array[String]:
	var parts: Array[String] = []
	for line: String in text.split("\n"):
		if parts.is_empty() or tag_of(line, tags) != "":
			parts.append(line)
		else:
			parts[-1] += "\n" + line
	return parts


## The tag a message starts with ("Quest accepted: ..."), or "". In the
## player's language, French setting a narrow space before the colon.
static func tag_of(text: String, tags: Array) -> String:
	for said: String in tags:
		for colon: String in [": ", "\u202f: ", " : "]:
			if text.begins_with(said + colon):
				return said
	return ""


## The next message, once the one showing is done with: a tagged one when
## it has faded, a plain one after PLAIN_MESSAGE_S.
func update() -> void:
	if _messages.is_empty():
		return
	if _message_now != "" and (_message_tagged or Time.get_ticks_msec() / 1000.0 - _message_since < PLAIN_MESSAGE_S):
		return
	_show_message(_messages.pop_front())


## On the objective's plate (PIX-194): a known tag before its first colon
## ("Quest accepted: ...") is set in gold, the rest wraps beside it. It holds
## long enough to read (UiStyle.reading_seconds).
func _show_message(text: String) -> void:
	_message_now = text
	_message_since = Time.get_ticks_msec() / 1000.0
	var tag := tag_of(text, _tags())
	_message_tagged = tag != ""
	if tag != "":
		text = text.substr(tag.length()).lstrip(" \u202f:")
		text = text[0].to_upper() + text.substr(1)
	message_tag.text = tag
	message_tag.visible = tag != ""
	# The first quest taken introduces the journal (PIX-202).
	if tag == Text.t("Quest accepted"):
		world.hud.hint("journal")
	# A quest done is a victory, heard (PIX-211); one taken, a yes (PIX-212).
	if tag == Text.t("Quest complete"):
		Sound.play("victory")
	elif tag == Text.t("Quest accepted"):
		Sound.play_ui("confirm")
	message_label.text = text
	# Wraps at a reading width, never wider than it needs.
	var wide := 0.0
	for line in text.split("\n"):
		wide = maxf(wide, UiStyle.body_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, message_label.get_theme_font_size("font_size")).x)
	var width := minf(ceilf(wide) + 2, MESSAGE_WIDTH - (message_tag.get_minimum_size().x + 8 if tag != "" else 0))
	# A wrapping label measures its height at the width it has: give it the
	# width first, then fit the plate round it.
	message_label.custom_minimum_size.x = width
	message_label.size = Vector2(width, 0)
	fit()
	if message_fade != null:
		message_fade.kill()
	message_fade = create_tween()
	message_fade.tween_property(message_box, "modulate:a", 1.0, 0.15)
	message_fade.tween_interval(UiStyle.reading_seconds(text))
	message_fade.tween_property(message_box, "modulate:a", 0.0, 0.4)
	message_fade.tween_callback(func() -> void:
		_message_now = ""
		update()
	)
