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
## A line of the moment (log_now: an ailment landed) shows within this long
## or not at all (PIX-476: poison's line came up 3 s on, its orc dead).
const NOW_S := 2.0
## A first-time hint a line of the moment cuts short has been read once it
## stood this long; cut sooner, it comes back after the line (PIX-476).
const HINT_READ_S := 1.5
## A first-time hint shows once: this long at least, or a short one is gone
## before it is read (PIX-433: the log's own floor of 2.5 s was too short
## for something shown once). Not the roll's, said as a fight starts
## (PIX-476): it reads as long as any line.
const HINT_SECONDS := 5.0
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

## A line of the moment (PIX-476: « Orc Raider is afflicted by burn! » first
## showed behind the roll's hint, its orc dead, and came back 10 s later):
## it shows as it lands, a first-time hint stepping aside for it and an
## older line of the moment giving it the place, and only while `holds`
## says its moment lasts (its foe alive) and within NOW_S of landing; past
## that it is dropped, never shown late (_drop_past).
func log_now(line: String, holds := Callable()) -> void:
	var entry := _log.add(line)
	entry["at"] = GameClock.seconds()
	entry["holds"] = holds
	for other: Dictionary in _log.showing.duplicate():
		if is_same(other, entry):
			continue
		if other.has("hint") and GameClock.seconds() - float(other["since"]) < HINT_READ_S:
			_step_aside([other])
		elif other.has("hint") or other.has("at"):
			_drop(other)
	if entry.has("chip"):
		_say(entry)
	else:
		_log.waiting.erase(entry)
		_log.waiting.push_front(entry)
	update()


## A first-time hint as a line of the log (PIX-433), by the id it's seen
## by: one short line at a time, stepping aside for the plate and coming
## back in full (one box at a time), while its moment lasts (PIX-462:
## _drop_past). Seen once it shows, not before. It holds no line of the
## fight back (PIX-476: log_now, log_lines), and stays HINT_SECONDS at
## least, but the roll's, which reads as long as any line.
func hint_line(id: String, text: String) -> void:
	_log.add(text)["hint"] = id
	update()


## The hint on the log, showing or waiting its turn, by its id, or "".
func hint_up() -> String:
	for entry: Dictionary in _log.showing + _log.waiting:
		if entry.has("hint"):
			return entry["hint"]
	return ""


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
		if not later:
			_roll_hint_after(entry)
		# Folded into one already up: its new words, and its time again.
		if entry.has("chip"):
			_say(entry)
	update()


## The roll's hint holds no line of the fight back (PIX-476: a named foe's
## « seen » line, said with it, waited 3 s behind it): read (HINT_READ_S),
## it goes; unread, it takes its turn after `line`.
func _roll_hint_after(line: Dictionary) -> void:
	for entry: Dictionary in _log.showing + _log.waiting:
		if entry.get("hint", "") != "dodge" or is_same(entry, line):
			continue
		var read := entry.has("chip") and GameClock.seconds() - float(entry["since"]) >= HINT_READ_S
		if entry.has("chip"):
			_step_aside([entry])
		_log.waiting.erase(entry)
		if not read:
			_log.waiting.append(entry)


## A line of the log on its own small plate, like the objective's (PIX-194),
## up as long as it takes to read; said again (folded), its words and its
## time anew.
func _say(entry: Dictionary) -> void:
	var chip: PanelContainer = entry.get("chip")
	if chip == null:
		# Counted once, though it may show again after the plate (_step_aside);
		# a first-time hint is no line of the fight's.
		if not entry.has("logged") and not entry.has("hint"):
			logged += 1
			entry["logged"] = true
		if entry.has("hint") and not entry["hint"] in GameState.settings.hints_seen:
			GameState.settings.hints_seen.append(entry["hint"])
			GameState.settings.save_file()
		entry["since"] = GameClock.seconds()
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
	var seconds := UiStyle.reading_seconds(text)
	fade.tween_interval(maxf(seconds, HINT_SECONDS) if entry.has("hint") and entry["hint"] != "dodge" else seconds)
	fade.tween_property(chip, "modulate:a", 0.0, 0.6)
	fade.tween_callback(func() -> void:
		_log.gone(entry)
		chip.queue_free()
		update()
	)
	chip.set_meta("fade", fade)


## Whether the words that can wait still do: a fight on, or only just over
## (Foes.CALM_S), or a title card up (PIX-378: a boss's fall ends the fight,
## and the level's plate came up under its Victory card, LEVEL UP rising
## over the hero already said it). No world (a test's): never.
func _fighting() -> bool:
	if world == null or world.get("foes") == null:
		return false
	return world.foes.in_fight(Foes.CALM_S) or _card_up()


func _card_up() -> bool:
	return world != null and world.get("hud") != null and world.hud.card_up()


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
		if tag_of(part, [Text.t("Quest complete")]) != "":
			_quest_done(part)
		var entry := _plate.add(part, tag_of(part, _tags()) != "")
		# Folded into the one showing: its new words.
		if is_same(entry, _shown) and entry["text"] != _message_now:
			_show_message(entry["text"])
	update()


func _tags() -> Array:
	return MESSAGE_TAGS.map(func(known: String) -> String: return Text.t(known))


## A quest done: its "Quest accepted" leaves the plate at once, or never
## shows if it still waits (PIX-476: The Cheese Run's stayed 8 s after the
## cheese was handed over, « Quest complete » waiting behind it). Both
## start with the quest's name after their tag, the taken one's maybe with
## the journal's key after it (Quests.accepted).
func _quest_done(done: String) -> void:
	var taken := Text.t("Quest accepted")
	var quest := _untagged(done, tag_of(done, _tags())).get_slice(".", 0)
	for entry: Dictionary in _plate.showing + _plate.waiting:
		var text: String = entry["text"]
		var named := _untagged(text, taken)
		if tag_of(text, [taken]) != "" and (named.begins_with(quest + ".") or named.begins_with(quest + " (")):
			_plate.waiting.erase(entry)
			if is_same(entry, _shown):
				_take_down()


## A message's words without its tag and the colon after it.
static func _untagged(text: String, tag: String) -> String:
	return text.substr(tag.length()).lstrip(" \u202f:")


## The plate's message gone at once, its room free.
func _take_down() -> void:
	_plate.gone(_shown)
	_shown = {}
	_message_now = ""
	message_fade.kill()
	message_box.modulate.a = 0.0


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
	_drop_past()
	_hold_hint_for_card()
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


## A boss's fall, its card up: what can wait and already shows on the plate
## (the level its spoils brought, said as it fell, a fight or not) goes back
## to wait its turn after the card, in full (PIX-378).
func make_way() -> void:
	if _shown.is_empty() or not _shown["later"]:
		return
	_plate.gone(_shown)
	_plate.waiting.push_front(_shown)
	_shown = {}
	_message_now = ""
	message_fade.kill()
	message_box.modulate.a = 0.0


## Words the hero has just proved wrong leave the plate at once, or never
## show if they still wait (PIX-444: « No foe in reach for Shadowstep. »
## held on over the next cast, which struck).
func withdraw(text: String) -> void:
	for entry: Dictionary in _plate.waiting.duplicate():
		if entry["text"] == text:
			_plate.waiting.erase(entry)
	if text == "" or _message_now != text:
		return
	_take_down()
	update()


## A line whose moment has gone leaves the log, showing or waiting, never
## shown late. A first-time hint (PIX-462: the roll's came up after the
## hounds were dead, the board's in the town hall, back after its card): one
## never shown stays unseen, for the next time (Hud.hint_there); no world (a
## test's): kept. A line of the moment (PIX-476, log_now): once what it is
## about is gone (its foe dead), or still waiting NOW_S after it landed.
func _drop_past() -> void:
	for entry: Dictionary in _log.showing + _log.waiting:
		var past := false
		if entry.has("hint"):
			past = world != null and world.get("hud") != null and not world.hud.hint_there(entry["hint"])
		elif entry.has("at"):
			var holds: Callable = entry["holds"]
			past = (not holds.is_null() and not (holds.is_valid() and holds.call())) \
				or (not entry.has("chip") and GameClock.seconds() - float(entry["at"]) > NOW_S)
		if past:
			_drop(entry)


## A line of the log gone for good, showing or waiting.
func _drop(entry: Dictionary) -> void:
	var chip: Node = entry.get("chip")
	if is_instance_valid(chip):
		chip.queue_free()
	_log.gone(entry)
	_log.waiting.erase(entry)


## A title card up: a first-time hint's line waits it out, one box at a time
## (PIX-433; `later` is what waits while a card is up, _fighting), and one
## already up steps aside to come back in full.
func _hold_hint_for_card() -> void:
	var card := _card_up()
	for entry: Dictionary in _log.showing + _log.waiting:
		if entry.has("hint"):
			entry["later"] = card
			if card and entry.has("chip"):
				_step_aside([entry])


## The log's lines showing, or just those given, go back to the head of the
## queue, to show again in full once the plate or the card is done.
func _step_aside(entries := _log.showing.duplicate()) -> void:
	for entry: Dictionary in entries:
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
		text = _untagged(text, tag)
		text = text[0].to_upper() + text.substr(1)
	message_tag.text = tag
	message_tag.visible = tag != ""
	# The first quest taken introduces the journal (PIX-202).
	if tag == Text.t("Quest accepted"):
		world.hud.hint("journal")
	# A quest done is a victory, heard (PIX-211); one taken, a yes (PIX-212).
	if tag == Text.t("Quest complete"):
		Sound.play("quest_done")
	elif tag == Text.t("Quest accepted"):
		Sound.play("quest_taken")
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
