extends CanvasLayer
## The journal (Journal.tsx): every promise made, how far along it stands
## and who to see about it; then the promises kept. Q or Esc closes it. The
## world holds still while it is open.

var body: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true
	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(UiStyle.heading("Journal", 20, UiStyle.CREAM, Vector2(80, 32)))
	var card := PanelContainer.new()
	card.position = Vector2(80, 80)
	card.custom_minimum_size = Vector2(1120, 540)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 18))
	add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	_fill()
	add_child(UiStyle.label("A promise is a route marked on the heart.", 14, UiStyle.DUSK, Vector2(80, 640)))
	add_child(UiStyle.footer("Esc / Q  close", Vector2(1060, 640)))


func _fill() -> void:
	var entries := GameState.progression.quests
	var known := Quests.all().filter(func(quest: Dictionary) -> bool: return entries.has(quest["id"]))
	if known.is_empty():
		body.add_child(UiStyle.label("No promises yet. Talk to the villagers.", 16, UiStyle.FADED))
		return
	var kept: Array = []
	for quest: Dictionary in known:
		if entries[quest["id"]]["done"]:
			kept.append(quest)
			continue
		body.add_child(_promise(quest, entries))
	if not kept.is_empty():
		body.add_child(UiStyle.label("Kept promises", 18, UiStyle.LAMP))
		for quest: Dictionary in kept:
			var line := HBoxContainer.new()
			var name := UiStyle.label(quest["name"], 16, UiStyle.FADED)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(name)
			line.add_child(UiStyle.label("DONE", 16, UiStyle.LAMP))
			body.add_child(line)


## One open quest: its name (READY when it can be turned in), the count, a
## bar, and the brief with the giver's name.
func _promise(quest: Dictionary, entries: Dictionary) -> Control:
	var giver: String = Npcs.by_id(quest["giver"], GameState.settlement.settlers).get("name", "")
	var goal := int(quest["objective"]["count"])
	var done := Quests.progress(quest, entries, GameState.pack.items)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var line := HBoxContainer.new()
	var ready := Quests.is_ready(quest, entries, GameState.pack.items)
	var name := UiStyle.label(
		"%s%s" % [quest["name"], "   READY - see %s" % giver if ready else ""], 16, UiStyle.LAMP if ready else UiStyle.INK
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(UiStyle.label("%d/%d" % [done, goal], 16, UiStyle.INK))
	block.add_child(line)
	var track := ColorRect.new()
	track.color = UiStyle.RIM
	track.custom_minimum_size = Vector2(1080, 6)
	var fill := ColorRect.new()
	fill.color = UiStyle.LAMP
	fill.size = Vector2(1080.0 * done / goal, 6)
	track.add_child(fill)
	block.add_child(track)
	block.add_child(UiStyle.label("%s (%s)" % [quest["brief"], giver], 14, UiStyle.FADED))
	return block


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()
