extends Screen
## The journal (Journal.tsx; PIX-171, redone for PIX-239 after Tom's
## playtest: « le journal c'est pas clair »). One page says what you're
## doing and lets you choose:
## - at the top, always, the quest you're on now - the main story's next
##   step, or a quest or bounty you chose to follow - in the words of the
##   line above the dock (Bearing): its title, the step, where to go, how far
##   along, and plainly which of the two it is;
## - below, every open thread, grouped: the main story (its chapter, then the
##   quests that carry it), the town and its people, the bounty board. Each
##   row says its next step in one line, its count, and READY once it can be
##   handed in. Choose a row (the arrows, the pad's D-pad, pointing) and E,
##   the pad's A or a click follows it: the top, the line above the dock, the
##   arrow at the view's edge and the map's goal all turn to it. Following
##   the main story follows nothing else.
## Liane's pages and the feats are reading, not doing: two more pages beside
## the quests (A/D), where the five chapters were before. Q or Esc closes it.
## The world holds still while it is open.

const BountyScreen := preload("res://scripts/bounty_screen.gd")
const TABS := ["quests", "pages", "feats"]
const TAB_NAMES := {"quests": "Quests", "pages": "Liane's pages", "feats": "Feats"}
## The chapters the journal had before (PIX-171), as the harness's --tab
## still names them.
const OLD_TABS := {"main": "quests", "side": "quests", "bounties": "quests", "story": "pages", "deeds": "feats"}
## Which thread the top is about, said plainly.
const KINDS := {"main": "Main story", "quest": "Quest you follow", "bounty": "Bounty you follow"}
## The pages' frame: from under the title to over the keys.
const AT := Vector2(80, 72)
const SIZE := Vector2(1120, 588)
## A window's margin inside its frame; how wide words run inside it, and in
## a row, its own margin and mark off too.
const PAD := 18
const TEXT_WIDTH := 1080.0
const ROW_TEXT := 1030.0

var tab := "quests"
var tabs_row: HBoxContainer
var content: VBoxContainer
var footer: Control
## The quests page: its rows (Journal.rows), the one chosen, the one
## followed (Journal.STORY for the main story), and their cards
## ({card, mark, tag, heading}).
var rows: Array[Dictionary] = []
var selected := 0
var followed := Journal.STORY
var cards: Array[Dictionary] = []
var scroll: ScrollContainer
## Whether the scroll to the chosen row shows its group's heading too.
var _reveal_heading := false
var now_box: VBoxContainer
## The top's step - the words of the line above the dock - and where to go
## (null once the story is told and nothing is followed).
var now_step: Label
var now_place: Label
## The chosen row's longer word, under the list.
var detail: Label
## Liane's pages: the first one in view, and each page's words.
var from := 0
var pages: Array[Control] = []


func _open() -> void:
	closing_actions = [&"journal"]
	layer = 5
	dim()
	# The HUD steps aside while the journal is open, as for the map (PIX-265):
	# its dock read through the dim under the keys.
	var hud: Variant = _hud()
	if hud != null and hud.root != null:
		hud.root.visible = false
		tree_exiting.connect(func() -> void: hud.root.visible = true)
	add_child(UiStyle.title("Journal"))
	tabs_row = HBoxContainer.new()
	tabs_row.position = Vector2(300, 26)
	tabs_row.add_theme_constant_override("separation", 10)
	add_child(tabs_row)
	content = VBoxContainer.new()
	content.position = AT
	content.custom_minimum_size = SIZE
	content.size = SIZE
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	tab = OLD_TABS.get(tab, tab)
	if tab not in TABS:
		tab = TABS[0]
	_show()


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		return _switch.bind(-1 if event.is_action_pressed("move_left") else 1)
	var by := -1 if event.is_action_pressed("move_up") else (1 if event.is_action_pressed("move_down") else 0)
	if tab == "quests" and not rows.is_empty():
		if by != 0:
			return _choose.bind(wrapi(selected + by, 0, rows.size()))
		if event.is_action_pressed("interact"):
			return _follow.bind(selected)
	if tab == "pages" and by != 0 and not pages.is_empty():
		return _turn.bind(by)
	return Callable()


func _switch(by: int) -> void:
	_switch_to(TABS[wrapi(TABS.find(tab) + by, 0, TABS.size())])


func _switch_to(id: String) -> void:
	tab = id
	from = 0
	_show()


## A click on a tab opens it.
func _on_tab_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_switch_to(id)


## The tabs, the page shown and its keys.
func _show() -> void:
	Layout.clear(tabs_row)
	for id: String in TABS:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.plank(id == tab, 6))
		chip.add_child(UiStyle.label(TAB_NAMES[id], 16, UiStyle.GOLD if id == tab else UiStyle.CREAM))
		chip.gui_input.connect(_on_tab_input.bind(id))
		tabs_row.add_child(chip)
	Layout.clear(content)
	rows.clear()
	cards.clear()
	pages.clear()
	now_step = null
	now_place = null
	match tab:
		"quests":
			_quests()
		"pages":
			_pages()
		"feats":
			_feats()
	_set_footer()


func _set_footer() -> void:
	if footer != null:
		remove_child(footer)
		footer.queue_free()
	match tab:
		"quests":
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:interact}  follow      {key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
		"pages":
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  turn      {key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
		_:
			footer = UiStyle.screen_footer("{key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
	add_child(footer)


## The quests: what you're on now at the top, then every thread open,
## grouped, and the chosen one's longer word under them.
func _quests() -> void:
	var progression := GameState.progression
	rows = Journal.rows(progression, GameState.settlement, GameState.pack.items)
	followed = Journal.followed(progression, GameState.settlement, GameState.pack.items)
	var now := PanelContainer.new()
	now.add_theme_stylebox_override("panel", UiStyle.window(PAD))
	now_box = VBoxContainer.new()
	now_box.add_theme_constant_override("separation", 4)
	now.add_child(now_box)
	content.add_child(now)
	_fill_now()

	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiStyle.window(PAD))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	sheet.add_child(column)
	# The list scrolls (the wheel, or the choice moving); its window fits.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var index := 0
	for group: String in Journal.GROUPS:
		var members := rows.filter(func(row: Dictionary) -> bool: return row["group"] == group)
		var notes := _notes(group, members.is_empty())
		if members.is_empty() and notes.is_empty():
			continue
		var heading := UiStyle.strong(Journal.GROUP_NAMES[group], 18, UiStyle.LAMP)
		list.add_child(heading)
		for at in members.size():
			list.add_child(_card(index, heading if at == 0 else null))
			index += 1
		for note: String in notes:
			list.add_child(Layout.wrapped(UiStyle.label(note, 14, UiStyle.FADED), ROW_TEXT))
	var kept := Journal.kept(progression)
	if not kept.is_empty():
		var last: Array[String] = []
		for quest: Dictionary in kept.slice(maxi(0, kept.size() - 3)):
			last.append(quest["name"])
		list.add_child(Layout.wrapped(UiStyle.label(Text.t("Done: %d quests, the latest %s.") % [kept.size(), ", ".join(last)], 14, UiStyle.FADED), ROW_TEXT))
	column.add_child(_rule())
	# Two lines, always: the list keeps its height as the choice moves, so
	# the row scrolled into view stays in view.
	detail = Layout.wrapped(UiStyle.label("", 14, UiStyle.FADED), TEXT_WIDTH)
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(detail)
	detail.custom_minimum_size.y = detail.get_line_height() * 2 + detail.get_theme_constant("line_spacing")
	# The choice starts on the thread followed.
	var ids := rows.map(func(row: Dictionary) -> String: return row["id"])
	_choose(maxi(0, ids.find(followed)))


## What a group says besides its rows: why it's empty, what's coming.
func _notes(group: String, empty: bool) -> Array[String]:
	var out: Array[String] = []
	match group:
		"story":
			if empty:
				out.append(Text.t("The story is told"))
		"people":
			if empty:
				out.append(Text.t("No quests taken yet. Someone with a ! over their head has one for you."))
		"bounties":
			var floors := Bearing.board_floors(GameState.progression)
			if GameState.progression.deepest > 0:
				out.append(Text.t("The Deep Hunt: deepest depth %d") % GameState.progression.deepest)
			var next := Hunts.next_notice(floors)
			if Hunts.notices(floors, GameState.progression.hunted).is_empty():
				if not next.is_empty():
					out.append(Text.t("No notices on the bounty board yet. The first goes up when %s.") % BountyScreen._when(next))
			elif not next.is_empty():
				out.append(Text.t("Another notice goes up when %s.") % BountyScreen._when(next))
	return out


## One thread: the gold diamond when it's followed, its title, FOLLOWING,
## READY or its count (a bounty's gold), and its next step and where.
func _card(index: int, heading: Control) -> Control:
	var row: Dictionary = rows[index]
	var card := PanelContainer.new()
	# Pointing chooses, a click follows; the wheel passes on to the list.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(_choose.bind(index, false))
	card.gui_input.connect(_on_row_input.bind(index))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)
	var mark := Diamond.new()
	mark.custom_minimum_size = Vector2(16, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(mark)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(top)
	var name := UiStyle.strong(row["title"], 18, UiStyle.INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var tag := UiStyle.strong(Text.t("FOLLOWING"), 14, UiStyle.LAMP)
	top.add_child(tag)
	var status: String = row["progress"]
	if row["ready"]:
		status = Text.t("READY")
	elif int(row["bounty"]) > 0:
		status = Text.coins(int(row["bounty"]))
	if status != "":
		top.add_child(UiStyle.strong(status, 18, UiStyle.LAMP if row["ready"] else UiStyle.INK))
	words.add_child(Layout.wrapped(UiStyle.label(row["line"], 14, UiStyle.FADED), ROW_TEXT))
	cards.append({"card": card, "mark": mark, "tag": tag, "heading": heading})
	return card


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_follow(index)


## Chooses a row: its card wears the red rim, its longer word shows under
## the list, and (by keys) the list scrolls to it - with its group's heading
## when it's the first.
func _choose(index: int, reveal := true) -> void:
	if index < 0 or index >= rows.size():
		return
	selected = index
	for at in cards.size():
		var chosen := at == selected
		cards[at]["card"].add_theme_stylebox_override("panel", UiStyle.box(
			UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 8
		))
	detail.text = rows[index]["detail"]
	_mark_rows()
	if reveal:
		_reveal(true)


## Scrolls the list to the chosen row (and its group's heading, `heading`)
## once the page is laid out again: containers sort at the frame's end, after
## a change of size above (a longer step at the top) has moved the list. So
## again just before the frame is drawn; at once too, for a run that draws
## nothing.
func _reveal(heading: bool) -> void:
	_reveal_heading = heading
	_reveal_now.call_deferred()
	if not RenderingServer.frame_pre_draw.is_connected(_reveal_now):
		RenderingServer.frame_pre_draw.connect(_reveal_now, CONNECT_ONE_SHOT)


func _reveal_now() -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree() or selected >= cards.size():
		return
	if _reveal_heading and cards[selected]["heading"] != null:
		scroll.ensure_control_visible(cards[selected]["heading"])
	scroll.ensure_control_visible(cards[selected]["card"])


## Follows a row (E, the pad's A, a click): the top, the marks and the HUD
## turn to it, and the save keeps it.
func _follow(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	_choose(index, false)
	if not Journal.follow(GameState.progression, rows[index]["id"]):
		return
	GameState.mark_dirty()
	followed = Journal.followed(GameState.progression, GameState.settlement, GameState.pack.items)
	_fill_now()
	_mark_rows()
	# A longer step at the top moves the list down: the row stays in view.
	_reveal(false)
	_tell_hud()
	Sound.play_ui("open")


## The followed row wears the diamond and FOLLOWING.
func _mark_rows() -> void:
	for at in cards.size():
		var on: bool = rows[at]["id"] == followed
		cards[at]["mark"].on = on
		cards[at]["tag"].visible = on


## The HUD looks again now - the line above the dock, the arrow, the map's
## goal - rather than at its next half-second.
func _tell_hud() -> void:
	var hud: Variant = _hud()
	if hud != null:
		hud.bearing = Bearing.active(GameState.progression, GameState.settlement, GameState.pack.items)


## The world's HUD (the journal stands on the world), or null where there's
## none (a test's stand-in).
func _hud() -> Variant:
	var world := get_parent()
	var hud: Variant = world.get("hud") if world != null else null
	return hud if hud is Object and (hud as Object).get("bearing") is Dictionary else null


## The top: what you're on now, as the line above the dock says it.
func _fill_now() -> void:
	Layout.clear(now_box)
	var progression := GameState.progression
	var items := GameState.pack.items
	var lead := Bearing.active(progression, GameState.settlement, items)
	if lead.is_empty():
		now_step = null
		now_place = null
		now_box.add_child(UiStyle.heading("The story is told", 18, UiStyle.LAMP))
		now_box.add_child(Layout.wrapped(UiStyle.label(MainQuest.hint(progression, GameState.settlement), 16, UiStyle.INK), TEXT_WIDTH))
		return
	var kind := "main" if lead["main"] else ("bounty" if String(lead["named"]) != "" else "quest")
	var step := String(lead["step"])
	var place := String(lead["place"])
	var progress := String(lead["progress"])
	# On the night of the fire the line above the dock is the night's.
	if progression.prologue != Prologue.DONE:
		step = Prologue.objective(progression.prologue, progression.prologue_doused.size(), GameState.questing.first_skill_heals())
		place = ""
		progress = ""
	var quest := Quests.by_id(String(lead["quest_id"]))
	var ready := not quest.is_empty() and Quests.is_ready(quest, progression.quests, items)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 12)
	# "Next", as the line above the dock is tagged, and whose thread it is.
	tags.add_child(UiStyle.strong("Next", 18, UiStyle.LAMP))
	tags.add_child(UiStyle.label("-", 18, UiStyle.FADED))
	var which := UiStyle.label(KINDS[kind], 18, UiStyle.FADED)
	which.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_child(which)
	if ready:
		tags.add_child(UiStyle.strong(Text.t("READY"), 18, UiStyle.LAMP))
	elif progress != "":
		tags.add_child(UiStyle.strong(progress, 18, UiStyle.INK))
	now_box.add_child(tags)
	var title := String(lead["title"])
	if lead["main"]:
		title = Journal.chapter_title(MainQuest.next_step(progression, GameState.settlement))
	now_box.add_child(Layout.wrapped(UiStyle.heading(title, 18, UiStyle.INK), TEXT_WIDTH))
	now_step = Layout.wrapped(UiStyle.label(step, 18, UiStyle.INK), TEXT_WIDTH)
	now_box.add_child(now_step)
	# Where to go: the place, or for a quest that roams, where it's found. The
	# line stays, empty, when there's no saying: the top keeps its height,
	# and the list under it its place, whatever is followed.
	if place == "" and not quest.is_empty() and progression.prologue == Prologue.DONE:
		place = Quests.where(quest, Relics.gate_open(progression), Town.done_projects(GameState.settlement))
	var where := HBoxContainer.new()
	where.add_theme_constant_override("separation", 10)
	var mark := Diamond.new()
	mark.on = place != ""
	mark.custom_minimum_size = Vector2(16, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	where.add_child(mark)
	now_place = Layout.wrapped(UiStyle.label(place, 18, UiStyle.FADED), TEXT_WIDTH - 26)
	where.add_child(now_place)
	now_box.add_child(where)


## Liane's journal (PIX-153): the pages found, in order; W/S turn them.
func _pages() -> void:
	var sheet := _sheet()
	var found := Story.found_pages(GameState.progression.cleared_levels)
	if found.is_empty():
		sheet.add_child(Layout.wrapped(UiStyle.label("No pages yet. Someone climbed this mountain before you - and wrote it down.", 16, UiStyle.FADED), TEXT_WIDTH))
		return
	sheet.add_child(UiStyle.strong(Text.t("Liane's journal - %d of %d pages") % [found.size(), Story.lore().size()], 18, UiStyle.LAMP))
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for page: Dictionary in found:
		var words := Layout.wrapped(UiStyle.label("%s.  %s" % [page["title"], page["text"]], 14, UiStyle.INK), TEXT_WIDTH)
		pages.append(words)
		list.add_child(words)


## Turns Liane's pages: the next or the last one at the top, until the last
## is in view (then W turns back at once, not after the pages it couldn't).
func _turn(by: int) -> void:
	var bottom := int(pages[0].get_parent().size.y - scroll.size.y)
	if by > 0 and scroll.scroll_vertical >= bottom:
		return
	from = clampi(from + by, 0, pages.size() - 1)
	scroll.scroll_vertical = int(pages[from].position.y)


## Feats (PIX-219: Deeds in the code; the word was the shops' deeds'):
## every long goal, done or how far along, and its medal.
func _feats() -> void:
	var sheet := _sheet()
	var state := GameState
	for deed: Dictionary in Deeds.all():
		var done: bool = deed["id"] in state.progression.deeds
		var counted := Deeds.count(deed, state.hero, state.pack, state.progression)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		# Columns that hold in French: a long name wraps rather than pushing
		# the count off its column.
		var name := Layout.wrapped(UiStyle.strong(Text.t(deed["name"]), 18, UiStyle.LAMP if done else UiStyle.INK), 320)
		name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(name)
		line.add_child(Layout.wrapped(UiStyle.label(Text.t(deed["line"]), 14, UiStyle.INK), 600))
		line.add_child(UiStyle.label(Text.t("Done") if done else "%d/%d" % [counted[0], counted[1]], 14, UiStyle.FADED))
		sheet.add_child(line)
		sheet.add_child(UiStyle.label(Text.t("Brings home: %s") % Catalog.item_name(deed["itemId"]), 13, UiStyle.FADED))


## A page that fills the frame, for reading.
func _sheet() -> VBoxContainer:
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", UiStyle.window(PAD))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	page.add_child(column)
	return column


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.RIM, 0.6)
	rule.custom_minimum_size = Vector2(TEXT_WIDTH, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## The gold diamond the map marks the goal with (PIX-240), dark-rimmed: on
## the followed row, and before where to go.
class Diamond extends Control:
	var on := true:
		set(value):
			on = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not on:
			return
		var center := (size / 2.0).floor()
		var half := floorf(minf(size.x, size.y) / 2.0) - 1.0
		draw_colored_polygon(_points(center, half), UiStyle.INK)
		draw_colored_polygon(_points(center, half - 3.0), UiStyle.GOLD)

	static func _points(center: Vector2, half: float) -> PackedVector2Array:
		return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)])
