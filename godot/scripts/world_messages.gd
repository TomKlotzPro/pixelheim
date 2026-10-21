class_name Messages
extends Node
## areas: combat story
## What the world tells the hero in words (Solid Ground, PIX-260: moved out
## of world.gd as it was): the message plate over the objective, where a
## quest taken or done, a level gained and the like wait their turn and hold
## long enough to read (PIX-194, PIX-211); and the battle log, a line at a
## time bottom-left, fading (PIX-343). The HUD calls build_log and build_plate
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
## How many lines the battle log shows at once (PIX-343: one, the rest wait
## their turn, TextBudget; four at once read as a wall of text), and the
## widest one runs before it wraps (French runs longer: a boss's words went
## off the screen). Each stays as long as it takes to read
## (UiStyle.reading_seconds).
const LOG_LINES := 1
const LOG_WIDTH := 700.0
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
## The log's lines and the plate's messages, showing and waiting their turn
## (PIX-334): the log one at a time (PIX-343), the plate one.
var _log := TextBudget.new(LOG_LINES)
var _plate := TextBudget.new(1)


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
	_log = TextBudget.new(LOG_LINES)
	_plate = TextBudget.new(1)
	_shown = {}
	_message_now = ""
	if message_fade != null:
		message_fade.kill()
	message_box.modulate.a = 0.0


func log_line(line: String) -> void:
	log_lines([line])

## The battle log: a line at a time, bottom-left, fading. Only what the
## world doesn't show comes here (PIX-245): story beats, quests, levels, the
## boss slayer's edge, a pack scattered; what's won floats up where it was
## won (WorldFx.show_gains). One at a time, the rest in their turn, the
## same line again folded into one (PIX-334: TextBudget); `later` lines (a
## kill's count, the Post) wait out a fight.
func log_lines(lines: Array, later := false) -> void:
	for line: String in lines:
		# A level gained goes on the plate, not among the kills (PIX-211).
		if tag_of(line, [Text.t("Level up")]) != "":
			flash(line)
			continue
		var entry := _log.add(line, later)
		# Folded into one already up: its new words, and its time again.
		if entry.has("chip"):
			_say(entry)
	update()


## A line of the log on its own small plate, like the objective's (PIX-194),
## up as long as it takes to read; said again (folded), its words and its
## time anew.
func _say(entry: Dictionary) -> void:
	var chip: PanelContainer = entry.get("chip")
	if chip == null:
		# Counted once, though it may show again after the plate (_step_aside).
		if not entry.has("logged"):
			logged += 1
			entry["logged"] = true
		chip = PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.plate(8))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var words := UiStyle.label("", UiStyle.reading(12), UiStyle.CREAM)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.add_child(words)
		log_box.add_child(chip)
		entry["chip"] = chip
	var words: Label = chip.get_child(0)
	var text: String = entry["text"]
	if int(entry["count"]) > 1:
		text = Text.t("%s x%d") % [text, int(entry["count"])]
	words.text = text
	# Wraps at LOG_WIDTH, never wider than it needs.
	var wide := UiStyle.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, words.get_theme_font_size("font_size")).x
	words.custom_minimum_size.x = minf(ceilf(wide) + 2, LOG_WIDTH)
	chip.modulate.a = 1.0
	if chip.has_meta("fade") and (chip.get_meta("fade") as Tween).is_valid():
		(chip.get_meta("fade") as Tween).kill()
	var fade := chip.create_tween()
	fade.tween_interval(UiStyle.reading_seconds(text))
	fade.tween_property(chip, "modulate:a", 0.0, 0.6)
	fade.tween_callback(func() -> void:
		_log.gone(entry)
		chip.queue_free()
		update()
	)
	chip.set_meta("fade", fade)


## Whether the words that can wait still do: a fight on, or only just over
## (Foes.CALM_S). No world (a test's): never.
func _fighting() -> bool:
	return world != null and world.get("foes") != null and world.foes.in_fight(Foes.CALM_S)


## The message's plate, shrunk round its words (a container only grows).
func fit() -> void:
	message_box.size = Vector2.ZERO
	message_box.reset_size()


## The message showing on the plate (its entry in _plate, PIX-334; the
## rest wait their turn there, PIX-211), its words, whether it carries a
## tag, and since when it shows.
var _shown := {}
var _message_now := ""
var _message_tagged := false
var _message_since := 0.0


## A message for the objective's plate (PIX-211): it waits behind the one
## showing instead of cutting it off. A quest's end and the level it brings
## go up one after the other; the same words twice are said once (two
## levels in one fight, once, at the higher: TextBudget.fold). A tagged one
## (a level, a quest) waits out a fight (PIX-334: the plate over the fight
## read « NIVEAU SUPÉRIEUR » as the pack's last fell). No words is no
## message (a chest whose loot floats up says nothing, PIX-245).
func flash(text: String) -> void:
	if text == "":
		return
	for part: String in split_messages(text, _tags()):
		var entry := _plate.add(part, tag_of(part, _tags()) != "")
		# Folded into the one showing: its new words.
		if is_same(entry, _shown) and entry["text"] != _message_now:
			_show_message(entry["text"])
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
## it has faded, a plain one after PLAIN_MESSAGE_S; and the log's lines
## waiting their turn. One box at a time (PIX-343, Tom's « trop d'infos
## qui pop d'un coup »): the plate goes first, the log's line stepping
## aside for it, and the log's next waits until the plate has faded.
func update() -> void:
	var fighting := _fighting()
	if _message_now != "" and not _message_tagged and GameClock.seconds() - _message_since >= PLAIN_MESSAGE_S:
		# A plain message gives way to whatever comes next.
		_plate.gone(_shown)
	var entry := _plate.next(fighting)
	if not entry.is_empty():
		_step_aside()
		_shown = entry
		_show_message(entry["text"])
	if _message_now != "":
		return
	var line := _log.next(fighting)
	while not line.is_empty():
		_say(line)
		line = _log.next(fighting)


## The log's line showing goes back to the head of the queue, to show again
## in full once the plate is done.
func _step_aside() -> void:
	for entry: Dictionary in _log.showing.duplicate():
		var chip: Node = entry.get("chip")
		entry.erase("chip")
		if is_instance_valid(chip):
			chip.queue_free()
		_log.gone(entry)
		_log.waiting.push_front(entry)


## On the objective's plate (PIX-194): a known tag before its first colon
## ("Quest accepted: ...") is set in gold, the rest wraps beside it. It holds
## long enough to read (UiStyle.reading_seconds).
func _show_message(text: String) -> void:
	_message_now = text
	_message_since = GameClock.seconds()
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
	var shown := _shown
	message_fade.tween_callback(func() -> void:
		_plate.gone(shown)
		_message_now = ""
		update()
	)
