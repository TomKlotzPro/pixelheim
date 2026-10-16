extends Screen
## The saves screen (Esc, and Saves on the title): the heroes you have, in
## three slots, one column that gets the whole window (PIX-302). Each card
## shows the hero as they left, dressed, with their class and level, where
## they are and the chapter, how long they've played and when they were last
## saved (SlotCard). A new hero starts from the title's New Game alone
## (PIX-316). On the chosen slot:
## - Continue (E) plays the hero;
## - Duplicate (D) copies them into the first empty slot, or says there's none;
## - Delete (X) asks with their name, level and hours, a second X deletes,
##   and R brings them back until another hero takes the slot;
## - Copy (C) puts them on the clipboard as a `PXH2.` save code, and Paste
##   (V) brings one in, asking first before it replaces a hero.
## Keyboard first, the same key twice confirms anything that loses a hero
## and Esc keeps them; every plank is clickable too, a card chosen with a
## click and played with a double click. Pauses the world while open;
## switching heroes reloads the world scene. A save the game can't read
## (damaged, a newer version's, or one from before this version's format)
## has its own card and takes nothing written over it; clearing it asks
## three times (PIX-303).

const PORTRAIT := Rect2(8, 6, 16, 20)  # hero body within a 32px Puny idle frame
## The window, set and never grown (PIX-230): its width whatever it holds, and
## everything in it wraps or flows at that width, so no line, however long,
## pushes it past the canvas.
const WINDOW := Vector2(1000, 0)
## How far down the canvas the screen's title stands.
const TOP := 28.0
## A card's padding inside its rim.
const CARD_PAD := 10
## A card's words: the window less its margins, the card's, the portrait and
## the gap after it.
const CARD_TEXT := WINDOW.x - 44.0 - CARD_PAD * 2 - PORTRAIT.size.x * 3 - 16.0
## The line under the planks: the window less its margins.
const LINE_TEXT := WINDOW.x - 44.0
## A browser hands its clipboard over a moment after it's asked (Godot's web
## clipboard answers with what it last heard, and asks again): Paste waits
## this long (s) for it.
const PASTE_WAIT := 0.25

var selected := 0
var cards: Array[PanelContainer] = []
## The window: WINDOW.x wide whatever it holds (what the tests measure).
var window: PanelContainer
var status: Label
## The planks by what they do: continue, duplicate, delete, copy, paste, restore.
var planks := {}
## The question waiting for its key a second time ("delete", "paste",
## "clear-unread", "clear-sure"), or "".
var pending := ""
## What the line under the planks last said, by kind (the tests read it):
## copied, full, deleted, back, pasted, code, ask, or "".
var said := ""
## What playing the hero already in hand means here: just closing (over the
## world), or the title's Continue (over the title).
var on_play_current: Callable
## Each slot as last read: its summary (SaveSlots.summary) and the hero
## deleted from it, waiting (`deleted`, {} when none).
var _slots: Array[Dictionary] = []
## The hero a pasted code holds, while Paste asks before replacing one.
var _pasting := {}


func _open() -> void:
	layer = 5
	selected = clampi(GameState.slot - 1, 0, SaveSlots.SLOT_COUNT - 1)

	dim()

	# One window in the middle of the screen: the slots, the planks, what
	# just happened underneath.
	# Placed, not centred by a container: a wrapping line measures itself tall
	# before it knows its width, and a centring container would grow with it.
	# The window is WINDOW.x wide, so placed it is centred; it hugs its
	# content, shrinking back once those lines know their width.
	var stack := Layout.hugging(VBoxContainer.new())
	stack.position = Vector2((1280 - WINDOW.x) / 2, TOP)
	stack.add_theme_constant_override("separation", 14)
	add_child(stack)
	var title := UiStyle.heading("Saves", 20, UiStyle.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	window = PanelContainer.new()
	window.custom_minimum_size = Vector2(WINDOW.x, 0)
	window.add_theme_stylebox_override("panel", UiStyle.window(22))
	stack.add_child(window)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	window.add_child(body)

	for index in SaveSlots.SLOT_COUNT:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(LINE_TEXT, 0)
		card.gui_input.connect(_on_card_input.bind(index))
		body.add_child(card)
		cards.append(card)

	# Flowing onto a second line in a longer language, not past the window.
	var actions := Layout.flow()
	planks["continue"] = UiStyle.button(Text.t("Continue"), _continue, "{key:interact}")
	planks["duplicate"] = UiStyle.button(Text.t("Duplicate"), _duplicate, "D")
	planks["delete"] = UiStyle.button(Text.t("Delete"), _delete, "X")
	planks["copy"] = UiStyle.button(Text.t("Copy"), _copy, "C")
	planks["paste"] = UiStyle.button(Text.t("Paste"), _paste, "V")
	# Only while the chosen slot keeps a deleted hero.
	planks["restore"] = UiStyle.button(Text.t("Bring back"), _restore, "R")
	for plank: Button in planks.values():
		actions.add_child(plank)
	body.add_child(actions)

	status = Layout.wrapped(UiStyle.label("", 14, UiStyle.LAMP), LINE_TEXT)
	body.add_child(status)
	add_child(UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:interact}  continue      D  duplicate      X  delete      C  copy      V  paste      Esc  close"))
	_refresh()


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_up"):
		return _select.bind(selected - 1)
	if event.is_action_pressed("move_down"):
		return _select.bind(selected + 1)
	if event.is_action_pressed("interact"):
		return _continue
	# Esc (or the pad's B) keeps the hero a question is about; asked
	# nothing, it closes.
	if pending != "" and _closes_on(event):
		return _keep
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_D:
				return _duplicate
			KEY_X:
				return _delete
			KEY_R:
				return _restore
			KEY_C:
				return _copy
			KEY_V:
				return _paste
	return Callable()


func _select(index: int) -> void:
	selected = wrapi(index, 0, SaveSlots.SLOT_COUNT)
	_say("", "")
	_draw()


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click and index == selected:
			_continue()
		else:
			_select(index)


## Slot number shown to players: 1-based.
func _target() -> int:
	return selected + 1


## What the chosen slot holds (SaveSlots: empty, hero, damaged, newer, older).
func _kind() -> String:
	return _slots[selected]["kind"]


## Whether the chosen slot is the hero in hand (not a stand-in's slot).
func _in_hand() -> bool:
	return _target() == GameState.slot and not GameState.standing_in


## The chosen hero as a save holds them: the one in hand as they are now,
## their last steps too; another from their slot. {} when there's none.
func _hero() -> Dictionary:
	if _kind() != SaveSlots.HERO:
		return {}
	return GameState.to_dict() if _in_hand() else GameState.slots.read(_target())


func _continue() -> void:
	var kind := _kind()
	# An empty slot has no one to play, and makes no one here: a hero starts
	# from the title's New Game alone (PIX-316), as its card says.
	if kind == SaveSlots.EMPTY:
		return
	# Nor has a save this version can't read.
	if kind == SaveSlots.DAMAGED:
		_say("", Text.t("Slot %d's save can't be read, so there's no one to play. It's kept as it is.") % _target())
		return
	if kind == SaveSlots.NEWER:
		_say("", Text.t("Slot %d was saved by a newer version. Update Pixelheim to play this hero.") % _target())
		return
	if kind == SaveSlots.OLDER:
		_say("", Text.t("Slot %d was saved by an older version of Pixelheim, so there's no one to play. It's kept as it is.") % _target())
		return
	if _in_hand():
		close()
		if on_play_current.is_valid():
			on_play_current.call()
		return
	if GameState.play_slot(_target()):
		_reload()


## A copy of the chosen hero in the first empty slot (one where no deleted
## hero waits, if there is one), or a polite word that there's none.
func _duplicate() -> void:
	var state := _hero()
	if state.is_empty():
		_no_one()
		return
	var hero_name: String = _slots[selected]["name"]
	var room := _room()
	if room == 0:
		_say("full", Text.t("Sorry, there's no empty slot for a copy of %s. Delete a hero to make room.") % hero_name)
		return
	if not GameState.slots.write(room, state):
		_say("", Text.t("The save couldn't be written, so slot %d is as it was.") % room)
		return
	_refresh()
	_say("copied", Text.t("A copy of %s is in slot %d now.") % [hero_name, room])


## The first empty slot, one keeping no deleted hero first; 0 when none is.
func _room() -> int:
	var empty := range(SaveSlots.SLOT_COUNT).filter(func(index: int) -> bool: return _slots[index]["kind"] == SaveSlots.EMPTY)
	for index: int in empty:
		if _slots[index]["deleted"].is_empty():
			return index + 1
	return empty[0] + 1 if not empty.is_empty() else 0


## The hero asks first, by name, class, level and hours; the second X
## deletes them, kept aside until another hero takes the slot (R).
func _delete() -> void:
	var slot := _slots[selected]
	match slot["kind"]:
		SaveSlots.EMPTY:
			_say("", Text.t("Slot %d is already empty.") % _target())
		SaveSlots.HERO:
			var in_hand := _in_hand()
			var question := SlotCard.asking(slot, in_hand)
			if in_hand:
				question += " " + Text.t("You'll go back to the title.")
			if not _confirm("delete", "%s %s" % [question, Text.t("Press X again to delete. Esc: keep.")]):
				return
			if in_hand:
				# Their last steps go aside with them: R brings back the hero
				# as they left.
				GameState.save_now()
			GameState.clear_slot(_target())
			if in_hand:
				# No one in hand now: back to the title.
				GameState.title_seen = false
				_reload()
				return
			# Their card says it, and that R brings them back.
			_refresh()
			_say("deleted", "")
		_:
			_clear_unread(slot["kind"])


## "You deleted Hrafna. R brings them back, until another hero takes this slot."
static func _deleted_line(hero_name: String) -> String:
	return Text.t("You deleted %s. R brings them back, until another hero takes this slot.") % hero_name


## A save this version can't read asks twice before it goes (PIX-303): a
## newer Pixelheim may still play it, and nothing brings it back.
func _clear_unread(kind: String) -> void:
	if pending == "clear-sure":
		GameState.clear_slot(_target())
		_refresh()
		_say("", Text.t("Slot %d is empty now.") % _target())
	elif pending == "clear-unread":
		pending = "clear-sure"
		status.text = Text.t("Once cleared, it's gone for good: nothing brings it back. Press X once more to clear slot %d.") % _target()
	else:
		var question := Text.t("Clear slot %d's save from a newer version for good?")
		if kind == SaveSlots.DAMAGED:
			question = Text.t("Clear slot %d's damaged save for good?")
		elif kind == SaveSlots.OLDER:
			question = Text.t("Clear slot %d's save from an older version for good?")
		_confirm("clear-unread", "%s %s" % [question % _target(), _again("X")])


## The hero deleted from the chosen slot, back in it.
func _restore() -> void:
	var kept: Dictionary = _slots[selected]["deleted"]
	if kept.is_empty():
		_say("", Text.t("There's no deleted hero in slot %d to bring back.") % _target())
		return
	if GameState.slots.restore(_target()):
		_refresh()
		_say("back", Text.t("%s is back.") % kept["name"])


func _copy() -> void:
	var state := _hero()
	if state.is_empty():
		_no_one()
		return
	DisplayServer.clipboard_set(SaveCodec.encode_code(state))
	_say("code", Text.t("%s's save code is copied. On the other machine, choose a slot in Saves and press V.") % _slots[selected]["name"])


## Why there's no one to copy in the chosen slot.
func _no_one() -> void:
	if _kind() == SaveSlots.EMPTY:
		_say("", Text.t("Slot %d is empty: there's no one to copy.") % _target())
	else:
		_say("", Text.t("Slot %d holds no hero this version can play, so there's no one to copy.") % _target())


func _paste() -> void:
	if OS.has_feature("web"):
		DisplayServer.clipboard_get()
		await get_tree().create_timer(PASTE_WAIT).timeout
		if not is_inside_tree():
			return
	paste_text(DisplayServer.clipboard_get())


## What Paste found on the clipboard, brought into the chosen slot: an empty
## one takes it at once, a hero's asks first (the same key again replaces
## them, Esc keeps them), and a save this version can't read takes nothing.
func paste_text(text: String) -> void:
	if pending == "paste" and not _pasting.is_empty():
		var asked := _pasting
		_say("", "")
		_bring(asked)
		return
	var read := SaveCodec.pasted(text)
	match read["problem"]:
		SaveCodec.OLDER:
			_say("", "That code is from an older version of Pixelheim: heroes from before this update can't be brought in.")
			return
		SaveCodec.NEWER:
			_say("", "That code is from a newer version of Pixelheim. Update the game to bring this hero in.")
			return
		SaveCodec.DAMAGED:
			_say("", "That code is cut short or changed. Copy it again on the other machine (C in Saves), then press V here.")
			return
	var state: Dictionary = read["state"]
	if state.is_empty():
		_say("", "There's no save code to paste. On the other machine, choose the hero in Saves and press C, then press V here.")
		return
	var slot := _slots[selected]
	if slot["kind"] in [SaveSlots.DAMAGED, SaveSlots.NEWER, SaveSlots.OLDER]:
		_say("", Text.t("Slot %d holds a save this version can't read, so nothing is written there. X clears it, if you mean to.") % _target())
		return
	if slot["kind"] == SaveSlots.HERO:
		var question := Text.t("Replace %s in slot %d with %s %s? Their progress here would be lost.") % [
			slot["name"], _target(), describe(state), Text.t("from the code"),
		]
		_confirm("paste", "%s %s" % [question, _again("V")])
		_pasting = state
		return
	_bring(state)


## A pasted hero into the chosen slot: in hand, they're played at once (the
## autosave would write the one before back over them); elsewhere they wait
## in the slot.
func _bring(state: Dictionary) -> void:
	if _in_hand():
		GameState.import_into(_target(), state)
		_reload()
		return
	if not GameState.slots.write(_target(), state):
		_say("", Text.t("The save couldn't be written, so slot %d is as it was.") % _target())
		return
	_refresh()
	_say("pasted", Text.t("%s is in slot %d now.") % [state["hero"]["name"], _target()])


## "Brann, level 7 ranger"
static func describe(state: Dictionary) -> String:
	var hero: Dictionary = state["hero"]
	var role: String = Catalog.role(hero["roleId"]).get("name", hero["roleId"]).to_lower()
	return Text.t("%s, level %d %s") % [hero["name"], hero["level"], role]


## "Press V again to confirm. Esc: keep."
static func _again(key: String) -> String:
	return Text.t("Press %s again to confirm. Esc: keep.") % key


## Destructive actions take the same key twice: the first press asks
## (`question`, its key said in it), the second says true.
func _confirm(action: String, question: String) -> bool:
	if pending == action:
		pending = ""
		_pasting = {}
		return true
	pending = action
	said = "ask"
	status.text = question
	return false


## Esc on a question: nothing goes.
func _keep() -> void:
	_say("", "")


## A word under the planks (`kind` for the tests), any question dropped.
func _say(kind: String, text: String) -> void:
	pending = ""
	_pasting = {}
	said = kind
	status.text = text


## Every slot read again, then drawn.
func _refresh() -> void:
	_slots.clear()
	for index in SaveSlots.SLOT_COUNT:
		var slot := GameState.slots.summary(index + 1)
		slot["deleted"] = GameState.slots.deleted(index + 1) if slot["kind"] == SaveSlots.EMPTY else {}
		_slots.append(slot)
	_draw()


func _draw() -> void:
	for index in cards.size():
		_fill_card(cards[index], index)
	# The planks that can do something for the chosen slot stand lit; a key
	# pressed for one that can't says why.
	var kind := _kind()
	for action: String in ["continue", "duplicate", "copy"]:
		planks[action].disabled = kind != SaveSlots.HERO
	planks["delete"].disabled = kind == SaveSlots.EMPTY
	planks["restore"].visible = not _slots[selected]["deleted"].is_empty()


func _fill_card(card: PanelContainer, index: int) -> void:
	Layout.clear(card)
	var slot := _slots[index]
	var kind: String = slot["kind"]
	var empty := kind == SaveSlots.EMPTY
	var chosen := index == selected
	# A save the game can't read is no empty slot (PIX-303): its card is
	# inked like a hero's, named for what went wrong.
	card.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if not empty else Color(UiStyle.CARD, 0.4), UiStyle.LAMP if chosen else UiStyle.RIM, CARD_PAD
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# The slot's own hero as they left, dressed and coloured as the dock and
	# the doll show them (PIX-175), facing down; a deleted hero, waiting,
	# faintly.
	var kept: Dictionary = slot["deleted"]
	row.add_child(_portrait(slot, 1.0) if kind == SaveSlots.HERO else _portrait(kept, 0.35))

	# The card's words in CARD_TEXT (PIX-230): the slot's tag shares the
	# name's line, and the rest have the card's whole width, wrapping past it
	# rather than widening the card.
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.custom_minimum_size.x = CARD_TEXT
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(top)
	var name_line := UiStyle.strong(_card_name(slot), 20, UiStyle.FADED if empty else UiStyle.INK)
	name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_line)
	# The hero in hand plays here; a stand-in (no hero yet, or the slot a
	# launch couldn't read) plays no one's slot.
	var playing := index + 1 == GameState.slot and not GameState.standing_in
	var tag := UiStyle.label("Playing" if playing else Text.t("Slot %d") % (index + 1), 12,
		UiStyle.LAMP if playing else UiStyle.FADED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tag)
	# A name from a save code may run longer than creation allows: it wraps
	# before the tag (measured now it's in the tree and has its font).
	Layout.wrapped(name_line, CARD_TEXT - 16.0 - tag.get_minimum_size().x)
	match kind:
		SaveSlots.EMPTY:
			_line(lines, "New Game, on the title screen, starts a hero.")
			if not kept.is_empty():
				_line(lines, _deleted_line(kept["name"]), UiStyle.LAMP)
		SaveSlots.DAMAGED:
			_line(lines, "The game can't read this save, so it's kept as it is. X clears it, if you mean to.")
		SaveSlots.NEWER:
			_line(lines, "A newer Pixelheim wrote it: update the game to play this hero. It's kept as it is.")
		SaveSlots.OLDER:
			_line(lines, "An older Pixelheim wrote it, before saves changed, and this version can't play it. It's kept as it is. X clears it, if you mean to.")
		_:
			_line(lines, SlotCard.who(slot))
			_line(lines, SlotCard.where(slot))
			_line(lines, SlotCard.when(slot, int(Time.get_unix_time_from_system())))
			# Said, never silent (PIX-303): this hero is the save before.
			if slot["backup"]:
				_line(lines, "Its last save couldn't be read: this is the one before it.", UiStyle.LAMP)


## A line of a card, wrapping at its width.
static func _line(lines: VBoxContainer, text: String, color := UiStyle.FADED) -> void:
	lines.add_child(Layout.wrapped(UiStyle.label(text, 14, color), CARD_TEXT))


## A hero's portrait from their card (empty for none), at `alpha`.
static func _portrait(summary: Dictionary, alpha: float) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT.size * 3
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if summary.get("kind", "") != SaveSlots.HERO:
		return portrait
	var frame := AtlasTexture.new()
	var spec := PunyArt.dressed(summary["roleId"], summary.get("look", 0), summary.get("worn", {}))
	frame.atlas = PunyArt.sheet_texture(spec)
	frame.region = PORTRAIT
	portrait.texture = frame
	portrait.self_modulate = Color(spec["tint"], alpha)
	return portrait


## The card's first line: the hero's name, or what the slot holds instead.
static func _card_name(summary: Dictionary) -> String:
	match summary["kind"]:
		SaveSlots.EMPTY:
			return "Empty slot"
		SaveSlots.DAMAGED:
			return "Damaged save"
		SaveSlots.NEWER:
			return "Saved by a newer version"
		SaveSlots.OLDER:
			return "Saved by an older version"
	return summary["name"]


func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
