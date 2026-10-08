extends Screen
## The journal (Journal.tsx): every promise made, how far along it stands
## and who to see about it; then the promises kept. Q or Esc closes it. The
## world holds still while it is open.

var body: VBoxContainer


func _open() -> void:
	closing_actions = [&"journal"]
	layer = 5
	dim()
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
	_main_quest()
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


## The main quest leads (PIX-144): its chapter, the next step, and what the
## elder would say about it; then the promises made along the way.
func _main_quest() -> void:
	var step := MainQuest.next_step(GameState.progression, GameState.settlement)
	if step.is_empty():
		body.add_child(UiStyle.strong("The story is told", 18, UiStyle.LAMP))
		body.add_child(UiStyle.label(MainQuest.hint(GameState.progression, GameState.settlement), 16, UiStyle.INK))
	else:
		body.add_child(UiStyle.strong("Chapter %d: %s" % [step["chapter_number"], step["chapter"]], 18, UiStyle.LAMP))
		body.add_child(UiStyle.label(step["text"], 16, UiStyle.INK))
		var hint := UiStyle.label(step["hint"], 14, UiStyle.FADED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(1080, 0)
		body.add_child(hint)
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.RIM, 0.6)
	rule.custom_minimum_size = Vector2(1080, 2)
	body.add_child(rule)


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
