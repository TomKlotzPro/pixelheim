extends Screen
## The journal (Journal.tsx): every promise made, how far along it stands
## and who to see about it; then the promises kept. Q or Esc closes it. The
## world holds still while it is open.

var body: VBoxContainer
## "promises", or "story": the pages of Liane's journal found so far (PIX-153).
var tab := "promises"
var tab_label: Label
## The first page shown on the Story tab (five fit; W/S scroll).
var page_from := 0
const PAGES_SHOWN := 5


func _open() -> void:
	closing_actions = [&"journal"]
	layer = 5
	dim()
	add_child(UiStyle.heading("Journal", 20, UiStyle.CREAM, Vector2(80, 32)))
	tab_label = UiStyle.label("", 16, UiStyle.GOLD, Vector2(300, 40))
	add_child(tab_label)
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
	add_child(UiStyle.footer("A/D  promises / story      Esc / Q  close", Vector2(820, 640)))


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		return _switch
	if tab == "story" and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
		return _scroll.bind(-1 if event.is_action_pressed("move_up") else 1)
	return Callable()


func _scroll(by: int) -> void:
	var found := Story.found_pages(GameState.progression.cleared_levels).size()
	page_from = clampi(page_from + by, 0, maxi(0, found - PAGES_SHOWN))
	_refill()


func _switch() -> void:
	tab = "story" if tab == "promises" else "promises"
	_refill()


func _refill() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_fill()


func _fill() -> void:
	tab_label.text = "Promises   |   [ Story ]" if tab == "story" else "[ Promises ]   |   Story"
	if tab == "story":
		_story()
		return
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


## The pages of Liane's journal the hero has found, in order (PIX-153).
func _story() -> void:
	var pages := Story.found_pages(GameState.progression.cleared_levels)
	if pages.is_empty():
		body.add_child(UiStyle.label("No pages yet. Someone climbed this mountain before you - and wrote it down.", 16, UiStyle.FADED))
		return
	var heading := "Liane's journal - %d of %d pages" % [pages.size(), Story.lore().size()]
	if pages.size() > PAGES_SHOWN:
		heading += "   (W/S to turn)"
	body.add_child(UiStyle.strong(heading, 18, UiStyle.LAMP))
	for page: Dictionary in pages.slice(page_from, page_from + PAGES_SHOWN):
		var line := UiStyle.label("%s.  %s" % [page["title"], page["text"]], 14, UiStyle.INK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(1080, 0)
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
