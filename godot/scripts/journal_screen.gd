extends Screen
## areas: quest
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
## The main story's rows are the courier's satchel (PIX-253 step 2): Maren's
## letters by their address, each to deliver or delivered and answered (a
## delivered one's answer under the list when it's chosen).
## The letters and the feats are reading, not doing: two more pages beside
## the quests (A/D), where the five chapters were before. The Letters page
## reads Maren's letters once delivered - a courier never reads the post -
## with their answers. Once the Post is
## open (PIX-320) a Post page joins them: what the box on the square holds
## this morning, the pieces in the satchel, sealed, and those delivered, to
## read; and beside it the courier's book (PIX-321, Postmarks): a page per
## place, its postmark stamped the day the first piece reached it, who had
## post there and what the courier kept from it (W/S choose the page).
## Q or Esc closes it.
## The world holds still while it is open.

const BountyScreen := preload("res://scripts/bounty_screen.gd")
## The Post's tab (PIX-320) and the courier's book's (PIX-321) show once
## the Post is open (`_tabs`).
const TABS := ["quests", "letters", "post", "book", "feats"]
const TAB_NAMES := {"quests": "Quests", "letters": "Letters", "post": "Post", "book": "Postmarks", "feats": "Feats"}
## The courier's book's index, beside its page: how wide.
const BOOK_INDEX := 360.0
## How many of a page's pieces it lists, newest first.
const BOOK_LINES := 6
## The chapters the journal had before (PIX-171), and Liane's pages (until
## PIX-253 step 2), as the harness's --tab still names them.
const OLD_TABS := {"main": "quests", "side": "quests", "bounties": "quests", "story": "letters", "pages": "letters", "deeds": "feats"}
## Which thread the top is about, said plainly.
const KINDS := {"main": "Main story", "quest": "Quest you follow", "bounty": "Bounty you follow"}
## The pages' frame: from under the title and the tabs on its top edge (as
## the pack's) to over the keys, as far above them as every screen's pages
## (PIX-388).
const AT := Vector2(80, 96)
const SIZE := Vector2(1120, 552)
## A window's margin inside its frame, the screens' inset (PIX-388); how
## wide words run inside it, and in a row, its own margin and mark off too.
const PAD := UiStyle.INSET
const TEXT_WIDTH := SIZE.x - 2 * PAD
const ROW_TEXT := TEXT_WIDTH - 46

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
## The Letters page: what W/S turn to - each letter, then each of Liane's
## pages - and the first one in view.
var from := 0
var pages: Array[Control] = []
## The courier's book (PIX-321): its pages shown (places, Post.pages), the
## one open, and the index's rows.
var places: Array[String] = []
var place_at := 0
var place_rows: Array[PanelContainer] = []


func _open() -> void:
	closing_actions = [&"journal"]
	layer = 5
	dim()
	add_child(UiStyle.title("Journal"))
	tabs_row = HBoxContainer.new()
	# On the pages' top edge, INSET in from its corner, as every screen's
	# tabs (PIX-388).
	tabs_row.position = Vector2(AT.x + UiStyle.INSET, AT.y - 36)
	tabs_row.custom_minimum_size.y = 36
	tabs_row.add_theme_constant_override("separation", 4)
	add_child(tabs_row)
	content = VBoxContainer.new()
	content.position = AT
	content.custom_minimum_size = SIZE
	content.size = SIZE
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	tab = OLD_TABS.get(tab, tab)
	if tab not in _tabs():
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
	if tab in ["letters", "post", "feats"] and by != 0 and not pages.is_empty():
		return _turn.bind(by)
	if tab == "book" and by != 0 and places.size() > 1:
		return _open_place.bind(wrapi(place_at + by, 0, places.size()))
	return Callable()


func _switch(by: int) -> void:
	var shown := _tabs()
	_switch_to(shown[wrapi(shown.find(tab) + by, 0, shown.size())])


## The tabs this hero has: the Post's and the courier's book's once it's
## open (PIX-320, PIX-321).
func _tabs() -> Array:
	return TABS.filter(func(id: String) -> bool: return id not in ["post", "book"] or GameState.posting.is_open())


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
	for id: String in _tabs():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.tab(id == tab))
		chip.add_child(UiStyle.label(TAB_NAMES[id], 16, UiStyle.plank_ink(id == tab)))
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
		"letters":
			_letters()
		"post":
			_post()
		"book":
			_book()
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
		"letters", "post", "feats":
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  turn     {key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
		"book":
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
		_:
			footer = UiStyle.screen_footer("{key:move_left}/{key:move_right}  tabs      {key:journal} / Esc  close")
	add_child(footer)


## The quests: what you're on now at the top, then every thread open,
## grouped, and the chosen one's longer word under them.
func _quests() -> void:
	var progression := GameState.progression
	rows = Journal.rows(progression, GameState.settlement, GameState.pack.items, GameState.world.discovered)
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
			# The courier's satchel (PIX-253 step 2): named over the first
			# letter; under the last, the fifth that Maren keeps.
			var letter: bool = members[at]["letter"]
			if letter and (at == 0 or not members[at - 1]["letter"]):
				list.add_child(UiStyle.strong("The courier's satchel", 14, UiStyle.FADED))
			list.add_child(_card(index, heading if at == 0 else null))
			index += 1
			if letter and Letters.fifth_kept(progression) and (at == members.size() - 1 or not members[at + 1]["letter"]):
				var fifth := Letters.fifth()
				list.add_child(Layout.wrapped(UiStyle.label(Text.t("%s: %s") % [fifth["addressed"], fifth["note"]], 14, UiStyle.FADED), ROW_TEXT))
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
			var floors := Bearing.board_floors(GameState.progression, GameState.settlement)
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
	elif row["delivered"]:
		status = Text.t("DELIVERED")
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
## turn to it, and the save keeps it. A letter delivered is only chosen:
## its answer is there to read, there's nowhere left to take it.
func _follow(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	_choose(index, false)
	if not rows[index]["follows"] or not Journal.follow(GameState.progression, rows[index]["id"]):
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
		hud.look_again()


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
	var lead := Bearing.active(progression, GameState.settlement, items, GameState.world.discovered)
	if lead.is_empty():
		now_step = null
		now_place = null
		now_box.add_child(UiStyle.heading("The story is told", 18, UiStyle.LAMP))
		now_box.add_child(Layout.wrapped(UiStyle.label(MainQuest.hint(progression, GameState.settlement), 16, UiStyle.INK), TEXT_WIDTH))
		return
	# A thread that carries the story (a letter in the satchel, Maren's
	# relics) is the main story's too, as the arrow's gold says (PIX-253).
	var kind := "main" if Bearing.tells_story(lead) else ("bounty" if String(lead["named"]) != "" else "quest")
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
		place = Quests.where(quest, Town.done_projects(GameState.settlement))
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


## The Letters page (PIX-253 step 2): Maren's letters in the satchel's
## order, each sealed until it's delivered (a courier never reads the post),
## then her words and the answer that came back; the fifth, that she keeps.
## W/S turn from one to the next.
func _letters() -> void:
	var sheet := _sheet()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var satchel := Letters.satchel(GameState.progression)
	if satchel.is_empty():
		list.add_child(Layout.wrapped(UiStyle.label("Nothing in your satchel yet but the dust of the road.", 16, UiStyle.FADED), TEXT_WIDTH))
	else:
		var delivered := satchel.filter(func(carried: Dictionary) -> bool: return carried["delivered"]).size()
		list.add_child(UiStyle.strong(Text.t("Maren's letters - %d of %d delivered") % [delivered, satchel.size()], 18, UiStyle.LAMP))
		for carried: Dictionary in satchel:
			_letter_card(list, carried["quest"], carried["delivered"])
		# The fifth, while Maren keeps it (PIX-253 step 8: she gives it at
		# the shrine once she's told it all).
		if Letters.fifth_kept(GameState.progression):
			var fifth := Letters.fifth()
			_letter_card(list, {"addressed": fifth["addressed"], "note": fifth["note"]}, false)


## One letter on the Letters page, a card: its address and, delivered,
## Maren's words and the answer; sealed, the courier's rule (or for the
## fifth, Maren's own note).
func _letter_card(list: VBoxContainer, quest: Dictionary, delivered: bool) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.CARD, 0.5), UiStyle.RIM, 8))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	card.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var name := UiStyle.strong(String(quest["addressed"]), 18, UiStyle.INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UiStyle.strong(Text.t("DELIVERED") if delivered else Text.t("SEALED"), 18, UiStyle.LAMP if delivered else UiStyle.FADED))
	words.add_child(top)
	if not delivered:
		var note := String(quest.get("note", Text.t("A courier never reads the post.")))
		words.add_child(Layout.wrapped(UiStyle.label(note, 14, UiStyle.FADED), ROW_TEXT))
	else:
		for line: String in quest["letter"]:
			words.add_child(Layout.wrapped(UiStyle.label(line, 14, UiStyle.INK), ROW_TEXT))
		# A breath between her words and theirs.
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		words.add_child(gap)
		words.add_child(Layout.wrapped(UiStyle.strong(Homecoming.answered(quest, GameState.progression), 14, UiStyle.LAMP), ROW_TEXT))
		for line: String in Letters.answer(quest):
			words.add_child(Layout.wrapped(UiStyle.label(line, 14, UiStyle.INK), ROW_TEXT))
	pages.append(card)
	list.add_child(card)


## The Post's page (PIX-320): what the box on the square holds this
## morning, then the pieces in the satchel, sealed (a courier never reads
## the post: where each goes, its thread and what its outside says), then
## the ones delivered, newest first, read as Maren's letters are: their
## words, and what was said as they were handed over. W/S turn from one to
## the next.
func _post() -> void:
	var sheet := _sheet()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var post := GameState.post
	var waiting := GameState.posting.in_box().size()
	var box_line := Text.t("Nothing in the post box today. Fresh post comes in the morning.")
	if waiting == 1:
		box_line = Text.t("The post box on the square holds one piece this morning.")
	elif waiting > 1:
		box_line = Text.t("The post box on the square holds %d pieces this morning.") % waiting
	elif post.taken >= GameState.posting.today():
		box_line = Text.t("You've taken today's post. The box fills again in the morning.")
	list.add_child(UiStyle.strong("The Pixelheim Post", 18, UiStyle.LAMP))
	list.add_child(Layout.wrapped(UiStyle.label(box_line, 14, UiStyle.FADED), TEXT_WIDTH))
	list.add_child(UiStyle.strong("In your satchel", 18, UiStyle.LAMP))
	if post.bag.is_empty():
		list.add_child(Layout.wrapped(UiStyle.label("Nothing to deliver just now.", 14, UiStyle.FADED), TEXT_WIDTH))
	for id: String in post.bag:
		_post_card(list, Post.piece(id), false)
	if post.delivered.is_empty():
		return
	list.add_child(UiStyle.strong(Text.t("Delivered: %d") % post.delivered.size(), 18, UiStyle.LAMP))
	for at in range(post.delivered.size()):
		_post_card(list, Post.piece(post.delivered[post.delivered.size() - 1 - at]), true)


## One piece of the post on its page, a card: its address and its tag (by
## what it is: a letter sealed, a parcel wrapped; Post.tags), then its
## thread and where it goes (where it went, once delivered); sealed, what
## its outside says; delivered, its words and what was said as it was
## handed over.
func _post_card(list: VBoxContainer, entry: Dictionary, delivered: bool) -> void:
	if entry.is_empty():
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.CARD, 0.5), UiStyle.RIM, 8))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	card.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var name := Layout.wrapped(UiStyle.strong(String(entry["addressed"]), 18, UiStyle.INK), ROW_TEXT - 180)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var sealed := UiStyle.strong(Post.tags(entry)[1 if delivered else 0], 18, UiStyle.LAMP if delivered else UiStyle.FADED)
	sealed.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(sealed)
	words.add_child(top)
	var title := String(Post.thread(Post.thread_of(String(entry["id"]))).get("title", ""))
	var where := Post.where(entry, GameState.progression, GameState.settlement)
	var went := String(GameState.post.places.get(entry["id"], ""))
	if delivered and went != "":
		where = Catalog.place_name(went)
	words.add_child(Layout.wrapped(UiStyle.label(Text.t("%s - %s") % [title, where] if where != "" else title, 14, UiStyle.FADED), ROW_TEXT))
	if not delivered:
		words.add_child(Layout.wrapped(UiStyle.label(String(entry["note"]), 14, UiStyle.FADED), ROW_TEXT))
	else:
		for line: String in entry["words"]:
			words.add_child(Layout.wrapped(UiStyle.label(line, 14, UiStyle.INK), ROW_TEXT))
		# A breath between the letter and what was said to it.
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		words.add_child(gap)
		words.add_child(Layout.wrapped(UiStyle.strong("As it was handed over:", 14, UiStyle.LAMP), ROW_TEXT))
		for line: String in entry["said"]:
			words.add_child(Layout.wrapped(UiStyle.label(line, 14, UiStyle.INK), ROW_TEXT))
	pages.append(card)
	list.add_child(card)


## The courier's book (PIX-321): on the left its index, a row a page (the
## places stamped and those the hero has been to, in the book's order: a
## small postmark, the place, how many pieces it had), the page open lit;
## on the right that page: its postmark and the post office's cancellation,
## the place and the day it was first stamped, who had post there, and what
## the courier kept from it (a gift, a recipe written in). W/S turn the
## pages.
func _book() -> void:
	var post := GameState.post
	places = Post.pages(post, GameState.world.discovered)
	place_at = clampi(place_at, 0, maxi(places.size() - 1, 0))
	var sheet := _sheet()
	var stamped := post.stamps.size()
	sheet.add_child(UiStyle.strong("The courier's book", 18, UiStyle.LAMP))
	var count := Text.t("A page per place, stamped the day its first piece of post arrives. Stamped: %d of %d.") % [stamped, Post.book().size()]
	sheet.add_child(Layout.wrapped(UiStyle.label(count, 14, UiStyle.FADED), TEXT_WIDTH))
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 18)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(spread)
	var index := VBoxContainer.new()
	index.add_theme_constant_override("separation", 4)
	index.custom_minimum_size = Vector2(BOOK_INDEX, 0)
	spread.add_child(index)
	place_rows.clear()
	for place: String in places:
		place_rows.append(_place_row(index, place))
	var gutter := ColorRect.new()
	gutter.color = Color(UiStyle.RIM, 0.6)
	gutter.custom_minimum_size = Vector2(2, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(gutter)
	var leaf := VBoxContainer.new()
	leaf.name = "book_page"
	leaf.add_theme_constant_override("separation", 6)
	leaf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(leaf)
	_open_place(place_at)


## A row in the book's index: the page's small postmark, its place and how
## many pieces it had.
func _place_row(index: VBoxContainer, place: String) -> PanelContainer:
	var post := GameState.post
	var row := PanelContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	line.add_child(Postmark.view(Post.page(place), false, post.stamps.has(place)))
	var called := Layout.ellipsis(UiStyle.label(Catalog.place_name(place), 14, UiStyle.INK))
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(called)
	var count := Post.delivered_at(post, place).size()
	line.add_child(UiStyle.label(str(count) if count > 0 else "-", 14, UiStyle.FADED))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_open_place(places.find(place)))
	index.add_child(row)
	return row


## The book open at page `at`: its row lit, its page written out.
func _open_place(at: int) -> void:
	place_at = at
	for i in place_rows.size():
		place_rows[i].add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.CARD, 0.5), UiStyle.LAMP if i == at else Color(0, 0, 0, 0), 6))
	var leaf: VBoxContainer = content.find_child("book_page", true, false)
	if leaf == null:
		return
	Layout.clear(leaf)
	if places.is_empty():
		leaf.add_child(Layout.wrapped(UiStyle.label("No pages yet. Deliver a piece of post and its place gets a page.", 14, UiStyle.FADED), TEXT_WIDTH - BOOK_INDEX - 40))
		return
	var place := places[at]
	var post := GameState.post
	var stamped := post.stamps.has(place)
	var width := TEXT_WIDTH - BOOK_INDEX - 40
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	leaf.add_child(head)
	head.add_child(Postmark.view(Post.page(place), true, stamped))
	if stamped:
		head.add_child(Postmark.waves_view(Post.page(place)))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 4)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	titles.add_child(Layout.wrapped(UiStyle.heading(Catalog.place_name(place), 18, UiStyle.INK), width - 280))
	var dated := Text.t("First stamped on day %d.") % (int(post.stamps[place]) + 1) if stamped else Text.t("Not stamped yet: no post delivered here.")
	titles.add_child(Layout.wrapped(UiStyle.label(dated, 14, UiStyle.FADED), width - 280))
	var ids := Post.delivered_at(post, place)
	if ids.is_empty():
		return
	var who: Array[String] = []
	var kept: Array[String] = []
	for id: String in ids:
		var entry := Post.piece(id)
		var person := String(Npcs.by_id(Post.addressee(entry), []).get("name", ""))
		if String(entry.get("to", "")) == "fafnyr":
			person = Text.t("Fafnyr, care of Hilda")
		# Inside the sentence: « le maire Aldric », not « Le maire ».
		person = Text.mid(person)
		if person != "" and person not in who:
			who.append(person)
		var things := Post.kept(entry)
		if things["gift"] != "":
			kept.append(Catalog.item_name(things["gift"]))
		if things["recipe"] != "":
			kept.append(_recipe_line(things["recipe"]))
	leaf.add_child(Layout.wrapped(UiStyle.label(Text.t("Post for: %s") % ", ".join(who), 14, UiStyle.INK), width))
	if not kept.is_empty():
		leaf.add_child(Layout.wrapped(UiStyle.strong("Kept from here:", 14, UiStyle.LAMP), width))
		for line: String in kept:
			leaf.add_child(Layout.wrapped(UiStyle.label(line, 14, UiStyle.INK), width))
	# The page's ledger: what was delivered here, newest first, the oldest
	# beyond BOOK_LINES counted.
	leaf.add_child(Layout.wrapped(UiStyle.strong(Text.t("Delivered here: %d") % ids.size(), 14, UiStyle.LAMP), width))
	for back in mini(ids.size(), BOOK_LINES):
		var entry := Post.piece(ids[ids.size() - 1 - back])
		var title := String(Post.thread(Post.thread_of(String(entry["id"]))).get("title", ""))
		leaf.add_child(Layout.ellipsis(UiStyle.label(Text.t("%s - %s") % [entry["addressed"], title], 14, UiStyle.FADED)))
	if ids.size() > BOOK_LINES:
		leaf.add_child(UiStyle.label(Text.t("and %d more") % (ids.size() - BOOK_LINES), 14, UiStyle.FADED))


## A recipe the post wrote into the book: what it makes, from what, where
## and at what trade's level.
func _recipe_line(recipe_id: String) -> String:
	var recipe := Economy.recipe(recipe_id)
	if recipe.is_empty():
		return ""
	var needs: Array[String] = []
	var wants: Dictionary = recipe["needs"]
	for item_id: String in wants:
		needs.append(Text.count(int(wants[item_id]), Catalog.item_name(item_id)))
	var job: Dictionary = recipe["job"]
	var station := Text.t("Vex's cauldron, Alchemy %d") if job["id"] == "alchemy" else Text.t("Hilda's forge, Smithing %d")
	return Text.t("Recipe: %s, from %s (%s)") % [Catalog.item_name(String(recipe["itemId"])), ", ".join(needs), station % int(job["level"])]


## Turns the Letters page: the next or the last letter (or page) at the top,
## until the last is in view (then W turns back at once, not after the ones
## it couldn't).
func _turn(by: int) -> void:
	var bottom := int(pages[0].get_parent().size.y - scroll.size.y)
	if by > 0 and scroll.scroll_vertical >= bottom:
		return
	from = clampi(from + by, 0, pages.size() - 1)
	scroll.scroll_vertical = int(pages[from].position.y)


## Feats (PIX-219: Deeds in the code; the word was the shops' deeds'):
## every long goal, done or how far along, and its medal. W/S turn from one
## to the next (PIX-326: the Post's three ran off the page).
func _feats() -> void:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet().add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var state := GameState
	for deed: Dictionary in Deeds.all():
		var sheet := VBoxContainer.new()
		sheet.add_theme_constant_override("separation", 8)
		list.add_child(sheet)
		pages.append(sheet)
		var done: bool = deed["id"] in state.progression.deeds
		var counted := Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement, state.post)
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
