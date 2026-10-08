extends Screen
## The journal (Journal.tsx), in chapters (PIX-171): the main quest - its
## chapter, its steps and the promises that carry it - the side promises
## made along the way, the bounty board's notices, and Liane's pages. Every
## promise says where to go; the map marks who is waiting. Q or Esc closes
## it. The world holds still while it is open.

const BountyScreen := preload("res://scripts/bounty_screen.gd")
const TABS := ["main", "side", "bounties", "story"]
const TAB_NAMES := {"main": "Main", "side": "Side", "bounties": "Bounties", "story": "Story"}
## Promises shown at once on the Side tab, and pages on the Story tab (W/S
## scroll either).
const SHOWN := 5
const WIDTH := 1080.0

var body: VBoxContainer
var tab := "main"
var tab_label: Label
## The first entry shown on a scrolling tab.
var from := 0


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
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)
	_fill()
	add_child(UiStyle.label("A promise is a route marked on the heart.", 14, UiStyle.DUSK, Vector2(80, 640)))
	add_child(UiStyle.footer("A/D  chapter      W/S  scroll      Esc / Q  close", Vector2(720, 640)))


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		return _switch.bind(-1 if event.is_action_pressed("move_left") else 1)
	if tab in ["side", "story"] and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
		return _scroll.bind(-1 if event.is_action_pressed("move_up") else 1)
	return Callable()


func _scroll(by: int) -> void:
	var count := _side_open().size() if tab == "side" else Story.found_pages(GameState.progression.cleared_levels).size()
	from = clampi(from + by, 0, maxi(0, count - SHOWN))
	_refill()


func _switch(by: int) -> void:
	tab = TABS[(TABS.find(tab) + by + TABS.size()) % TABS.size()]
	from = 0
	_refill()


func _refill() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_fill()


func _fill() -> void:
	var names: Array[String] = []
	for id: String in TABS:
		names.append("[ %s ]" % TAB_NAMES[id] if id == tab else TAB_NAMES[id])
	tab_label.text = "   |   ".join(names)
	match tab:
		"main":
			_main()
		"side":
			_side()
		"bounties":
			_bounties()
		"story":
			_story()


## The quests that carry the story: Maren's relics and each relic's hunt.
static func is_main_line(quest: Dictionary) -> bool:
	if quest["id"] == Relics.quest_id():
		return true
	var named: String = quest["objective"].get("named", "")
	return Relics.all().any(func(relic: Dictionary) -> bool: return relic["named"] == named)


## The main quest leads (PIX-144): its chapter, the next step, what the
## elder would say about it, the chapter's steps, then the promises that
## carry the story.
func _main() -> void:
	var step := MainQuest.next_step(GameState.progression, GameState.settlement)
	if step.is_empty():
		body.add_child(UiStyle.strong("The story is told", 18, UiStyle.LAMP))
		body.add_child(UiStyle.label(MainQuest.hint(GameState.progression, GameState.settlement), 16, UiStyle.INK))
		return
	body.add_child(UiStyle.strong(Text.t("Chapter %d: %s") % [step["chapter_number"], step["chapter"]], 18, UiStyle.LAMP))
	body.add_child(UiStyle.label(step["text"], 16, UiStyle.INK))
	body.add_child(_wrapped(step["hint"], 14, UiStyle.FADED))
	body.add_child(_rule())
	for entry: Dictionary in MainQuest.steps():
		if entry["chapter"] != step["chapter"]:
			continue
		var met := MainQuest.is_met(entry, GameState.progression, GameState.settlement)
		var line := HBoxContainer.new()
		var text := UiStyle.label((Text.t("%s (optional)") % entry["text"]) if entry.get("optional", false) else entry["text"], 14,
			UiStyle.FADED if met else (UiStyle.LAMP if entry["id"] == step["id"] else UiStyle.INK))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		line.add_child(UiStyle.label("DONE" if met else ("NEXT" if entry["id"] == step["id"] else ""), 14, UiStyle.LAMP))
		body.add_child(line)
	var entries := GameState.progression.quests
	var carried := Quests.all().filter(func(quest: Dictionary) -> bool:
		return is_main_line(quest) and entries.has(quest["id"]) and not entries[quest["id"]]["done"])
	if not carried.is_empty():
		body.add_child(_rule())
		for quest: Dictionary in carried:
			body.add_child(_promise(quest, entries))


## The open side promises, a few at a time, then how many are kept.
func _side_open() -> Array:
	var entries := GameState.progression.quests
	return Quests.all().filter(func(quest: Dictionary) -> bool:
		return not is_main_line(quest) and entries.has(quest["id"]) and not entries[quest["id"]]["done"])


func _side() -> void:
	var entries := GameState.progression.quests
	var open := _side_open()
	if open.is_empty():
		body.add_child(UiStyle.label("No side promises open. The map marks who has something to ask.", 16, UiStyle.FADED))
	else:
		var heading := Text.t("Side promises - %d open") % open.size()
		if open.size() > SHOWN:
			heading += "   (W/S to scroll)"
		body.add_child(UiStyle.strong(heading, 18, UiStyle.LAMP))
		for quest: Dictionary in open.slice(from, from + SHOWN):
			body.add_child(_promise(quest, entries))
	var kept := Quests.all().filter(func(quest: Dictionary) -> bool:
		return not is_main_line(quest) and entries.get(quest["id"], {}).get("done", false))
	if not kept.is_empty():
		body.add_child(_rule())
		var last: Array[String] = []
		for quest: Dictionary in kept.slice(maxi(0, kept.size() - 3)):
			last.append(quest["name"])
		body.add_child(_wrapped(Text.t("Kept: %d promises, the latest %s.") % [kept.size(), ", ".join(last)], 14, UiStyle.FADED))


## The bounty board's notices (PIX-156) and where each one's lair is, and
## how deep the hero has hunted below the throne (PIX-161).
func _bounties() -> void:
	if GameState.progression.deepest > 0:
		body.add_child(UiStyle.strong(Text.t("The Deep Hunt: deepest depth %d") % GameState.progression.deepest, 18, UiStyle.LAMP))
	var notices := Hunts.notices(GameState.board_floors(), GameState.progression.hunted)
	if notices.is_empty():
		body.add_child(_wrapped(Text.t("No notices on the bounty board yet. The first goes up when %s.") % BountyScreen._when(Hunts.next_notice(GameState.board_floors())), 16, UiStyle.FADED))
		return
	for entry: Dictionary in notices:
		var slain: bool = entry["id"] in GameState.progression.hunted
		var line := HBoxContainer.new()
		var name := UiStyle.label(entry["name"], 16, UiStyle.FADED if slain else UiStyle.INK)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		line.add_child(UiStyle.label("SLAIN" if slain else "%dg" % int(entry["bounty"]), 16, UiStyle.LAMP))
		body.add_child(line)
		if not slain:
			body.add_child(_wrapped(Text.t("Its lair: %s. %s.") % [entry["where"], Hunts.reward_line(entry)], 14, UiStyle.FADED))
	var next := Hunts.next_notice(GameState.board_floors())
	if not next.is_empty():
		body.add_child(_rule())
		body.add_child(_wrapped(Text.t("Another notice goes up when %s.") % BountyScreen._when(next), 14, UiStyle.FADED))


## The pages of Liane's journal the hero has found, in order (PIX-153).
func _story() -> void:
	var pages := Story.found_pages(GameState.progression.cleared_levels)
	if pages.is_empty():
		body.add_child(UiStyle.label("No pages yet. Someone climbed this mountain before you - and wrote it down.", 16, UiStyle.FADED))
		return
	var heading := Text.t("Liane's journal - %d of %d pages") % [pages.size(), Story.lore().size()]
	if pages.size() > SHOWN:
		heading += "   (W/S to turn)"
	body.add_child(UiStyle.strong(heading, 18, UiStyle.LAMP))
	for page: Dictionary in pages.slice(from, from + SHOWN):
		body.add_child(_wrapped("%s.  %s" % [page["title"], page["text"]], 14, UiStyle.INK))


## One open quest: its name (READY when it can be turned in), the count, a
## bar, the brief with the giver and where they are, and where to go.
func _promise(quest: Dictionary, entries: Dictionary) -> Control:
	var npc: Dictionary = Npcs.by_id(quest["giver"], GameState.settlement.settlers)
	var giver: String = npc.get("name", "")
	var home := Catalog.place_name(npc.get("mapId", ""))
	var goal := int(quest["objective"]["count"])
	var done := Quests.progress(quest, entries, GameState.pack.items)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)
	var line := HBoxContainer.new()
	var ready := Quests.is_ready(quest, entries, GameState.pack.items)
	var name := UiStyle.label(
		"%s%s" % [quest["name"], Text.t("   READY - see %s") % giver if ready else ""], 16, UiStyle.LAMP if ready else UiStyle.INK
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(UiStyle.label("%d/%d" % [done, goal], 16, UiStyle.INK))
	block.add_child(line)
	var track := ColorRect.new()
	track.color = UiStyle.RIM
	track.custom_minimum_size = Vector2(WIDTH, 6)
	var fill := ColorRect.new()
	fill.color = UiStyle.LAMP
	fill.size = Vector2(WIDTH * done / goal, 6)
	track.add_child(fill)
	block.add_child(track)
	var where := "" if ready else Quests.where(quest)
	block.add_child(_wrapped("%s (%s, %s)%s" % [quest["brief"], giver, home, "  " + where if where != "" else ""], 14, UiStyle.FADED))
	return block


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := UiStyle.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.RIM, 0.6)
	rule.custom_minimum_size = Vector2(WIDTH, 2)
	return rule
