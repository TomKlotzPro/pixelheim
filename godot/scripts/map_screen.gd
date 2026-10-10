extends Screen
## The map screen (M/Tab): a map in a window, painted with the tiles' map
## colours where the hero has been and night where they haven't
## (mapColors.ts port), the hero, the waypoints and the lairs the bounty
## board has posted (PIX-156) marked; beside it the waypoints, and fast
## travel to the open ones. Pauses the world.
## Every map the hero has found is a page (PIX-266, Atlas): left and right
## turn them in the world's order, the title names each, the page names its
## regions and its ways to other places, and the Ashenreach shows the
## village small inside its walls, as the overworld draws it.
## The waypoint chosen in the list is ringed on the map and named there with
## the region it sets you down in (PIX-241), so you see where you'd land
## before you go; one on another map turns the map to that map's page.
## The list holds every waypoint under the place it stands in (PIX-266):
## those not found yet, or with no one keeping them, greyed there and on
## their page; it scrolls to the one chosen (and with none open yet, up and
## down read down it).
## Up and down or the pad choose, and so does pointing at a card; E, the
## pad's A or a click on the chosen card travels.
## The Reach is one page (One Reach, PIX-269, step 7): the Ashenreach and
## each region found round it drawn together where the plane puts them, the
## ridge the hero has seen between them, every mark at its map's offset, and
## each region named over its ground; the village, the rooms and the caves
## keep their own pages (Atlas.sheets).

const MAP_BOX := Vector2(760, 540)
## The list's window inside the side panel: the panel ends with the map's
## tallest frame.
const LIST_BOX := Vector2(320, 500)
## How far up or down reads the list while there's nothing to choose.
const SCROLL_STEP := 60

var world: Node2D
## The chosen open waypoint, by its place in `usable`; -1 while none is
## (none on the page shown, and choosing one turns the page).
var selected := -1
## The pages of the maps the hero has found, in the order they turn
## (Atlas.pages), and the one shown, by its map's id (the Reach's goes by
## the Ashenreach's).
var pages: Array[String] = []
var page := ""
var painting: Painting
## The map's frame over its legend.
var page_column: VBoxContainer
var frame: PanelContainer
var title: Label
## "2 / 6" beside the title, between the planks that turn the page.
var pager: HBoxContainer
var counter: Label
var legend: HBoxContainer
var footer: Control
## Which keys the footer shows now: what's to choose, whether E travels and
## whether there are pages to turn.
var _footer_for := -1
var scroll: ScrollContainer
## Every card in the list, in its order: {card, usable, heading (the
## place's heading when it's the first under it, else null)}.
var cards: Array[Dictionary] = []
var usable: Array[Dictionary] = []
## Other maps drawn for a page, loaded once a visit, by id.
var _maps := {}
## The village's block as the Ashenreach's page draws it, worked out once.
var _village := {}
var _village_for := ""


## How wide a waypoint card's words run before they wrap: the list's width
## less the card's margins.
const CARD_TEXT := 300.0

func _open() -> void:
	closing_actions = [&"map"]
	layer = 5
	dim()
	# The HUD steps aside while the map is open (PIX-265): its dock read
	# through the dim under the legend and the keys.
	var hud: Variant = world.get("hud") if world != null else null
	if hud != null and hud.root != null:
		hud.root.visible = false
		tree_exiting.connect(func() -> void: hud.root.visible = true)
	var heading := HBoxContainer.new()
	heading.position = Vector2(64, UiStyle.TITLE_AT.y)
	heading.add_theme_constant_override("separation", 20)
	add_child(heading)
	title = UiStyle.title(Catalog.place_name(world.map.id))
	heading.add_child(title)
	pager = HBoxContainer.new()
	pager.add_theme_constant_override("separation", 10)
	pager.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(pager)
	pager.add_child(UiStyle.button("<", _turn.bind(-1)))
	counter = UiStyle.label("", 12, UiStyle.DUSK)
	pager.add_child(counter)
	pager.add_child(UiStyle.button(">", _turn.bind(1)))

	# The map's frame and its legend under it, wherever its page ends
	# (PIX-265: at y 630 the legend sat over the dock), laid out together:
	# set by hand, the legend was put back where the first page left it by
	# the screen's easing in when a page turned in its first fifth of a
	# second (PIX-266).
	page_column = VBoxContainer.new()
	page_column.position = Vector2(56, 72)
	page_column.add_theme_constant_override("separation", 10)
	add_child(page_column)
	frame = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", UiStyle.window(14))
	page_column.add_child(frame)
	painting = Painting.new()
	painting.world = world
	# A ring at the map's edge (the Mirefen Pass) runs off the page, not
	# over the frame.
	painting.clip_contents = true
	frame.add_child(painting)

	var side := PanelContainer.new()
	side.position = Vector2(872, 72)
	side.custom_minimum_size = Vector2(352, 0)
	side.add_theme_stylebox_override("panel", UiStyle.window(16))
	add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	side.add_child(column)
	column.add_child(UiStyle.strong("Waypoints", 16, UiStyle.LAMP))
	# The list scrolls (the wheel, or the choice moving); its window fits.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = LIST_BOX
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var group := ""
	for waypoint: Dictionary in Atlas.listed(Interactables.waypoints()):
		var place_heading: Label = null
		if waypoint["mapId"] != group:
			group = waypoint["mapId"]
			place_heading = UiStyle.strong(Catalog.place_name(group), 12, UiStyle.FADED)
			list.add_child(place_heading)
		var open := Interactables.waypoint_usable(
			waypoint, GameState.world.discovered, GameState.settlement.settlers
		)
		var card := PanelContainer.new()
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lines)
		# Wrapped to the panel (Solid Ground): a long line in French breaks
		# instead of pushing the panel off the screen.
		lines.add_child(Layout.wrapped(UiStyle.label(waypoint["name"], 16, UiStyle.INK if open else UiStyle.FADED), CARD_TEXT))
		var note := _note(waypoint, open)
		if note != "":
			lines.add_child(Layout.wrapped(UiStyle.label(note, 12, UiStyle.FADED), CARD_TEXT))
		list.add_child(card)
		cards.append({"card": card, "usable": open, "heading": place_heading})
		if open:
			# Pointing at a card chooses it; clicking the chosen one travels.
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_entered.connect(_choose.bind(usable.size()))
			card.gui_input.connect(_on_card_input.bind(usable.size()))
			usable.append(waypoint)

	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 8)
	page_column.add_child(indent)
	legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	indent.add_child(legend)
	pages = Atlas.pages(GameState.world.discovered, world.map.id)
	page = Atlas.page_of(world.map.id)
	selected = Waypoints.first_on(usable, world.map.id)
	_show()


## What a card says under the waypoint's name: where it sets you down when
## it's open (the region, where the map names its regions), else why it
## isn't - not found yet, or no one keeps the post.
func _note(waypoint: Dictionary, open: bool) -> String:
	if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
		return Text.t("Not found yet")
	if not open:
		return Text.t("Unstaffed: no one keeps this post yet")
	return Waypoints.region_name(waypoint, _map(waypoint["mapId"]))


func _command(event: InputEvent) -> Callable:
	if pages.size() > 1 and event.is_action_pressed("move_left"):
		return _turn.bind(-1)
	if pages.size() > 1 and event.is_action_pressed("move_right"):
		return _turn.bind(1)
	if usable.is_empty():
		# Nothing to choose yet: up and down read down the list of what's
		# to find.
		if event.is_action_pressed("move_down"):
			return func() -> void: scroll.scroll_vertical += SCROLL_STEP
		if event.is_action_pressed("move_up"):
			return func() -> void: scroll.scroll_vertical -= SCROLL_STEP
		return Callable()
	if event.is_action_pressed("move_down"):
		return _choose.bind(Waypoints.step(selected, 1, usable.size()))
	if event.is_action_pressed("move_up"):
		return _choose.bind(Waypoints.step(selected, -1, usable.size()))
	if event.is_action_pressed("interact"):
		# Nothing chosen yet: E shows the first before it takes you anywhere.
		return _travel if selected >= 0 else _choose.bind(0)
	return Callable()


## A click on the card already chosen (pointing at it chose it) travels;
## on another (a tap, with no pointer to hover) it chooses that one first.
func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if index == selected:
			_travel()
		else:
			_choose(index)


func _choose(index: int) -> void:
	if index == selected or index < 0 or index >= usable.size():
		return
	selected = index
	page = Atlas.page_of(usable[index]["mapId"])
	_show()


## Another page (left and right, the pad, the planks by the title): the
## list's choice moves to the first open waypoint on it, or to none.
func _turn(delta: int) -> void:
	if pages.size() < 2:
		return
	page = Atlas.turn(pages, page, delta)
	selected = Waypoints.first_on_page(usable, page)
	_show()


func _travel() -> void:
	var destination := usable[selected]
	close()
	world.travel_to(destination)


## The chosen waypoint's id, "" while none is (the harness reports it).
func destination_id() -> String:
	return String(usable[selected]["id"]) if selected >= 0 else ""


## The page shown, by map id (the harness reports it).
func page_id() -> String:
	return page


## Chooses the open waypoint `id`, as pointing at its card would (the look
## book's map, PIX-266): its page shown, the list scrolled to it.
func show_waypoint(id: String) -> void:
	for index in usable.size():
		if usable[index]["id"] == id:
			_choose(index)


## The list and the map agree on the choice: its card wears the red rim,
## and the map turns to the page it's on, ringed and named there; the title,
## the legend and the keys follow the page.
func _show() -> void:
	_highlight()
	var destination: Dictionary = usable[selected] if selected >= 0 else {}
	var on_page := Atlas.sheets(page, GameState.world.discovered, world.map.id)
	var sizes := {}
	var home := false
	for sheet: Dictionary in on_page:
		sheet["map"] = _map(sheet["id"])
		sizes[sheet["id"]] = sheet["map"].size
		home = home or sheet["map"] == world.map
	painting.village = _village_on(on_page)
	painting.paint(on_page, Atlas.tile_px(Atlas.page_size(on_page, sizes), MAP_BOX), home, destination)
	title.text = Catalog.place_name(page)
	pager.visible = pages.size() > 1
	counter.text = "%d / %d" % [pages.find(page) + 1, pages.size()]
	_fill_legend(home)
	# A smaller page shrinks the window round it, and the legend follows it.
	page_column.reset_size()
	_set_footer()


## Another map's page, as the town has grown, loaded once.
func _map(map_id: String) -> MapData:
	if map_id == world.map.id:
		return world.map
	if not _maps.has(map_id):
		_maps[map_id] = world.load_map(map_id)
	return _maps[map_id]


## The village on the Reach's page, as the overworld draws it now
## (Atlas.village: the town as it has grown, its burnt houses ash), once the
## hero knows the town, in the page's cells; {} on the other pages.
func _village_on(on_page: Array[Dictionary]) -> Dictionary:
	if not Atlas.found(GameState.world.discovered, "town"):
		return {}
	for sheet: Dictionary in on_page:
		var map: MapData = sheet["map"]
		if map.id not in PunyTerrain.SKYLINE_MAPS:
			continue
		if _village_for != map.id:
			var done := Town.done_projects(GameState.settlement)
			var ruins: Array = Town.ruins(done).map(func(ruin: Dictionary) -> Rect2i: return ruin["rect"])
			_village = Atlas.village(map, MapData.load_tiered("town", done, 1), ruins)
			_village_for = map.id
		var out := {}
		for cell: Vector2i in _village:
			out[cell + sheet["at"]] = _village[cell]
		return out
	return {}


## The chosen open waypoint wears the red frame, scrolled into view.
func _highlight() -> void:
	var usable_index := 0
	for entry: Dictionary in cards:
		var chosen := false
		if entry["usable"]:
			chosen = usable_index == selected
			usable_index += 1
		entry["card"].add_theme_stylebox_override("panel", UiStyle.box(
			UiStyle.CARD if entry["usable"] else Color(UiStyle.CARD, 0.4), UiStyle.LAMP if chosen else UiStyle.RIM, 8
		))
	if selected >= 0:
		_reveal()


## The chosen card's entry in `cards`, {} while none is chosen.
func _chosen_card() -> Dictionary:
	var usable_index := 0
	for entry: Dictionary in cards:
		if entry["usable"]:
			if usable_index == selected:
				return entry
			usable_index += 1
	return {}


## Scrolls the chosen card into the list's window, with its place's heading
## when it's the first under it, once the list is laid out: at the frame's
## end, and again just before the frame is drawn.
func _reveal() -> void:
	_reveal_now.call_deferred()
	if not RenderingServer.frame_pre_draw.is_connected(_reveal_now):
		RenderingServer.frame_pre_draw.connect(_reveal_now, CONNECT_ONE_SHOT)


func _reveal_now() -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree():
		return
	var entry := _chosen_card()
	if entry.is_empty():
		return
	if entry["heading"] != null:
		scroll.ensure_control_visible(entry["heading"])
	scroll.ensure_control_visible(entry["card"])


## What the marks on this page mean: "You" only where the hero is, the grey
## mark only where a waypoint isn't open yet.
func _fill_legend(home: bool) -> void:
	Layout.clear(legend)
	var marks: Array = []
	if home:
		marks.append([Color.WHITE, "You"])
	marks.append([UiStyle.LAMP, "Waypoint"])
	if painting.shows_closed():
		marks.append([Painting.CLOSED, "Not yet open"])
	if not painting.lairs().is_empty():
		marks.append([Painting.LAIR, "Lair"])
	if home and not Painting.givers(world).is_empty():
		marks.append([Painting.QUEST, "Quest"])
	# The goal and the main story behind it as the page draws them, diamonds
	# (PIX-253 step 2).
	if painting.goal_cell() != Bearing.NOWHERE:
		marks.append([Painting.GOAL, "Goal", Swatch.FILLED])
	if painting.story_cell() != Bearing.NOWHERE:
		marks.append([Painting.GOAL, "Story", Swatch.HOLLOW])
	# Each mark beside its word, the marks a little further apart: with the
	# story's the row is one longer, and in French it still ends before the
	# waypoints' panel.
	for mark: Array in marks:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)
		var swatch: Control = Swatch.new(mark[2]) if mark.size() > 2 else ColorRect.new()
		if swatch is ColorRect:
			(swatch as ColorRect).color = mark[0]
			swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(swatch)
		entry.add_child(UiStyle.label(mark[1], 12, UiStyle.FADED))
		legend.add_child(entry)


## The keys as they stand: up and down choose, or with nothing to choose
## read down the list; E travels only once a waypoint is chosen; left and
## right turn the page only when there is another.
func _set_footer() -> void:
	var choosing := 0 if usable.is_empty() else (1 if selected < 0 else 2)
	var state := choosing * 2 + (1 if pages.size() > 1 else 0)
	if state == _footer_for:
		return
	_footer_for = state
	if footer != null:
		remove_child(footer)
		footer.queue_free()
	match state:
		0:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  scroll      {key:map} / Esc  close")
		1:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  scroll      {key:move_left}/{key:move_right}  maps      {key:map} / Esc  close")
		2:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:map} / Esc  close")
		3:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:move_left}/{key:move_right}  maps      {key:map} / Esc  close")
		4:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:interact}  travel      {key:map} / Esc  close")
		_:
			footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:move_left}/{key:move_right}  maps      {key:interact}  travel      {key:map} / Esc  close")
	add_child(footer)



## The legend's diamonds (PIX-253 step 2): the goal's, filled, and the main
## story's, hollow, drawn as the page draws them.
class Swatch extends Control:
	const FILLED := "filled"
	const HOLLOW := "hollow"
	var shape := FILLED

	func _init(kind := FILLED) -> void:
		shape = kind
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var at := (size / 2.0).floor()
		draw_colored_polygon(Painting._points(at, 8.0), UiStyle.NIGHT)
		draw_colored_polygon(Painting._points(at, 6.0), Painting.GOAL)
		if shape == HOLLOW:
			draw_colored_polygon(Painting._points(at, 3.0), UiStyle.NIGHT)


class Painting extends Control:
	const LAIR := Color("c071ff")
	const QUEST := Color("5fdc7a")
	## Where the hero is headed (PIX-240): the quest marks' gold.
	const GOAL := Color("f2c14e")
	## How much wider than a marker the main story's hollow diamond is (the
	## goal's is 6): a hole that shows the page.
	const STORY_GROW := 10.0
	## A waypoint not open yet (PIX-266): not found, or no one keeps it.
	const CLOSED := Color("8e8880")
	## A gate the story keeps shut (PIX-254): the alarm's red.
	const SHUT := Color("d8433f")
	## The gates shut on this page whose ground was seen (PIX-254): [{gate,
	## cell}], `cell` its middle on the page.
	var _gates: Array[Dictionary] = []
	## The dark round a label's letters, and the shade under them (px each
	## way past the letters), so they read on any ground.
	const OUTLINE := 4
	const PLATE := Vector2(4, 1)
	var world: Node2D
	## The page shown, by the map it's named for: the hero's map, or another
	## the hero has found (the Ashenreach for the Reach's page).
	var map: MapData
	## The maps drawn on it, each where its cell (0, 0) lies on the page:
	## [{"id", "at", "map"}] (Atlas.sheets); `map` alone at (0, 0) while unset.
	var sheets: Array[Dictionary] = []
	## How big the page is, in cells.
	var cells := Vector2i.ZERO
	var tile_px := 4
	## Whether the hero is on this page (their marker, the quest givers).
	var home := true
	## The chosen waypoint, ringed and named; {} while none is.
	var destination := {}
	## When it was chosen (ms): its ring starts wide from there.
	var chosen_at := 0
	var tag: PanelContainer
	## The village's block on this page (Atlas.village) in the page's cells,
	## set before `paint`.
	var village := {}
	## What's drawn of the page: page cell -> colour (seen ground, the ridge
	## seen between maps, the village).
	var _ground := {}
	## What the page names, placed: [{text, at (px), size, way}].
	var _labels: Array[Dictionary] = []
	## The page's px to the screen's when it was last drawn (PIX-267): the
	## marks are snapped to the screen's pixels through it, so a move or a
	## new window draws them again.
	var _shown := Transform2D()

	## The villagers here with a word for the hero (PIX-171): a quest to
	## offer, or one ready to turn in.
	static func givers(on: Node2D) -> Array[Node]:
		var out: Array[Node] = []
		for villager in on.get_tree().get_nodes_in_group("npcs"):
			if not villager.away and Quests.awaits_word(villager.data["id"], GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open):
				out.append(villager)
		return out

	## Turns to the page of `on_page` (Atlas.sheets, each with its map) at
	## `px` pixels a tile, with `chosen` ringed on it.
	func paint(on_page: Array[Dictionary], px: int, hero_here: bool, chosen: Dictionary) -> void:
		sheets = on_page
		map = sheets[0]["map"]
		tile_px = px
		home = hero_here
		destination = chosen
		chosen_at = Time.get_ticks_msec()
		cells = Vector2i.ZERO
		for sheet: Dictionary in sheets:
			cells = cells.max(sheet["at"] + sheet["map"].size)
		custom_minimum_size = Vector2(cells * tile_px)
		var discovered: Dictionary = GameState.world.discovered
		_ground = {}
		# The ridge between the maps on the Reach's page, where the hero had
		# it in sight: the cliffs every map there is rimmed with.
		var ridge := Atlas.color(ReachPlane.RIDGE)
		for cell: Vector2i in Atlas.ridge(sheets, discovered):
			_ground[cell] = ridge
		for sheet: Dictionary in sheets:
			var grid: Dictionary = sheet["map"].grid
			var at: Vector2i = sheet["at"]
			for cell: Vector2i in discovered.get(sheet["id"], {}):
				if grid.has(cell):
					_ground[cell + at] = Atlas.color(grid[cell])
		for cell: Vector2i in village:
			_ground[cell] = Atlas.color(village[cell])
		_gates = _shut_gates()
		_name_destination()
		_place_labels()
		queue_redraw()

	## The maps on the page: `sheets`, or the page's map alone at (0, 0).
	func _on_page() -> Array[Dictionary]:
		if not sheets.is_empty() or map == null:
			return sheets
		return [{"id": map.id, "at": Vector2i.ZERO, "map": map}]

	## Whether `map_id` is drawn on this page.
	func holds(map_id: String) -> bool:
		return _on_page().any(func(sheet: Dictionary) -> bool: return sheet["id"] == map_id)

	## Where `map_id`'s cell (0, 0) lies on the page (it must be on it).
	func at_of(map_id: String) -> Vector2i:
		for sheet: Dictionary in _on_page():
			if sheet["id"] == map_id:
				return sheet["at"]
		return Vector2i.ZERO

	## The waypoints drawn on this page, each with its cell on the page:
	## [{waypoint, cell}].
	func _waypoints() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for waypoint: Dictionary in Interactables.waypoints():
			if holds(waypoint["mapId"]):
				out.append({"waypoint": waypoint, "cell": Waypoints.cell(waypoint) + at_of(waypoint["mapId"])})
		return out

	## The lairs of the named monsters the board has posted (PIX-156) on the
	## page's maps, each on the page.
	func lairs() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for sheet: Dictionary in _on_page():
			for entry in Hunts.living_on(sheet["id"], GameState.questing.board_floors(), GameState.progression.hunted):
				out.append(Hunts.lair(entry) + sheet["at"])
		return out

	## The gates the story keeps shut on this page (PIX-254), once the
	## ground they stand on has been seen: each marked and named where it
	## stands, [{gate, cell}].
	func _shut_gates() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for sheet: Dictionary in _on_page():
			var seen: Dictionary = GameState.world.discovered.get(sheet["id"], {})
			for gate: Dictionary in Gates.closed_on(sheet["id"], GameState.progression, GameState.settlement, GameState.world.discovered):
				if Gates.cells_of(gate).any(func(cell: Vector2i) -> bool: return seen.has(cell)):
					out.append({"gate": gate, "cell": Gates.middle(gate) + sheet["at"]})
		return out

	## The ring breathes while a waypoint is chosen, unless motion is
	## reduced; and the marks are drawn again on the screen's pixels when
	## the page has moved on the screen (the screen easing in, a new window).
	func _process(_delta: float) -> void:
		if (not destination.is_empty() and not GameState.settings.reduce_motion) or _on_screen() != _shown:
			queue_redraw()

	## The page's px to the screen's: its canvas layer and the window's
	## stretch, a browser's uneven one included.
	func _on_screen() -> Transform2D:
		return get_viewport().get_final_transform() * get_global_transform_with_canvas()

	## Markers are pixel squares with a dark rim, a little bigger than a tile.
	func _mark() -> float:
		return maxf(tile_px * 1.6, 6.0)

	func _center(cell: Vector2i) -> Vector2:
		return Waypoints.mark_at(cell, tile_px)

	## Whether a waypoint on this page isn't open yet (the legend's grey).
	func shows_closed() -> bool:
		return _waypoints().any(func(entry: Dictionary) -> bool: return not _open(entry["waypoint"]))

	func _open(waypoint: Dictionary) -> bool:
		return Interactables.waypoint_usable(waypoint, GameState.world.discovered, GameState.settlement.settlers)

	## The page's names (Atlas.page_labels) placed on it, in the labels'
	## type: a region's clear of the waypoints' marks, the hero's, the chosen
	## one's tag and the names placed before it, or left off.
	func _place_labels() -> void:
		_labels.clear()
		var font := UiStyle.body_font()
		var bounds := Vector2(cells * tile_px)
		var mark := _mark()
		var taken: Array[Rect2] = []
		var marked: Array[Vector2i] = []
		for entry: Dictionary in _waypoints():
			marked.append(entry["cell"])
		for gate: Dictionary in _gates:
			marked.append(gate["cell"])
		if home:
			marked.append(hero_cell())
		for cell in marked:
			taken.append(Rect2(_center(cell), Vector2.ZERO).grow(floorf(mark / 2.0) + 2.0))
		var goal := goal_cell()
		if goal != Bearing.NOWHERE:
			taken.append(Rect2(_center(goal), Vector2.ZERO).grow(floorf((mark + 6.0) / 2.0) + 3.0))
		var story := story_cell()
		if story != Bearing.NOWHERE:
			taken.append(Rect2(_center(story), Vector2.ZERO).grow(floorf((mark + STORY_GROW) / 2.0) + 3.0))
		# The chosen waypoint's ring at its widest, and its tag over the names.
		if tag != null:
			taken.append(Rect2(_center(destination_cell()), Vector2.ZERO).grow(Waypoints.ring_half(mark, Waypoints.PULSE_PX) + 2.0))
			taken.append(Rect2(tag.position, tag.get_combined_minimum_size()))
		# A shut gate's name first (PIX-254): it says why the way past it is shut.
		var named: Array[Dictionary] = []
		for gate: Dictionary in _gates:
			named.append({"text": Gates.mark(gate["gate"]), "at": Vector2(gate["cell"]) + Vector2(0.5, 0.5), "way": true})
		for label: Dictionary in named + Atlas.page_labels(_on_page(), GameState.world.discovered):
			var size := Vector2(font.get_string_size(label["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT).x, font.get_height(UiStyle.TEXT))
			var spot: Vector2 = label["at"] * tile_px
			var at := Atlas.label_at(spot, size, bounds, label["way"], mark, taken)
			if at == Atlas.NOWHERE:
				continue
			taken.append(Rect2(at, size).grow_individual(PLATE.x, PLATE.y, PLATE.x, PLATE.y))
			_labels.append({"text": label["text"], "at": at, "size": size, "way": label["way"]})

	## The chosen waypoint's tag: a card like the chosen one in the list, its
	## name and the region it sets you down in, over its ring.
	func _name_destination() -> void:
		if tag != null:
			remove_child(tag)
			tag.queue_free()
			tag = null
		if destination.is_empty():
			return
		tag = PanelContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP, 6))
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(lines)
		lines.add_child(UiStyle.strong(destination["name"], 16, UiStyle.INK))
		var region := Waypoints.region_name(destination, _map_of(destination["mapId"]))
		if region != "":
			lines.add_child(UiStyle.label(region, 12, UiStyle.FADED))
		add_child(tag)
		tag.reset_size()
		# Clear of the ring at its widest, dark line and all.
		var widest := Waypoints.ring_half(_mark(), Waypoints.PULSE_PX) + 2.0
		tag.position = Waypoints.tag_at(
			_center(destination_cell()).floor(), widest, tag.get_combined_minimum_size(), custom_minimum_size
		)

	## The map `map_id` drawn on the page.
	func _map_of(map_id: String) -> MapData:
		for sheet: Dictionary in _on_page():
			if sheet["id"] == map_id:
				return sheet["map"]
		return map

	## The chosen waypoint's cell on the page.
	func destination_cell() -> Vector2i:
		return Waypoints.cell(destination) + at_of(destination["mapId"])

	## Where the hero stands on the page (when it's theirs).
	func hero_cell() -> Vector2i:
		return world.player_cell + at_of(world.map.id)

	func _draw() -> void:
		if map == null:
			return
		_shown = _on_screen()
		# The whole page is night until walked.
		draw_rect(Rect2(Vector2.ZERO, Vector2(cells * tile_px)), UiStyle.NIGHT)
		for cell: Vector2i in _ground:
			draw_rect(Rect2(Vector2(cell * tile_px), Vector2(tile_px, tile_px)), _ground[cell])
		_draw_labels()
		var mark := _mark()
		# Every waypoint where it stands, greyed until it's open.
		for entry: Dictionary in _waypoints():
			_marker(_center(entry["cell"]), mark, UiStyle.LAMP if _open(entry["waypoint"]) else CLOSED)
		# The lairs of the named monsters the board has posted (PIX-156).
		for lair: Vector2i in lairs():
			_marker(_center(lair), mark, LAIR)
		# The gates the story keeps shut (PIX-254), a red cross named beside it.
		for gate: Dictionary in _gates:
			_cross(_center(gate["cell"]), mark)
		if home:
			var hero_at := at_of(world.map.id)
			for villager in givers(world):
				_marker(_center(Vector2i((villager.position / 16.0).floor()) + hero_at), mark, QUEST)
		# The chosen waypoint (PIX-241), under the hero's own mark.
		if not destination.is_empty():
			var grow := Waypoints.ring_grow(Time.get_ticks_msec() - chosen_at, GameState.settings.reduce_motion)
			_ring(_center(destination_cell()), mark, grow)
		# The main story's next place while something else leads (PIX-253
		# step 2), a hollow diamond; where the hero is headed (PIX-240), a
		# diamond; both under the hero's mark.
		var story := story_cell()
		if story != Bearing.NOWHERE:
			_diamond(_center(story), mark + STORY_GROW, true)
		var goal := goal_cell()
		if goal != Bearing.NOWHERE:
			_diamond(_center(goal), mark + 6.0)
		if home:
			_marker(_center(hero_cell()), mark, Color.WHITE)

	## The page's names in the type of the screen, in cream as on the dark
	## round windows, with a dark line round them on a shade of the night:
	## the line alone was lost on the Frostgate's snow.
	func _draw_labels() -> void:
		var font := UiStyle.body_font()
		var ascent := font.get_ascent(UiStyle.TEXT)
		for label: Dictionary in _labels:
			draw_rect(Rect2(label["at"], label["size"]).grow_individual(PLATE.x, PLATE.y, PLATE.x, PLATE.y), Color(UiStyle.NIGHT, 0.6))
			var base: Vector2 = label["at"] + Vector2(0, ascent)
			draw_string_outline(font, base, label["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT, OUTLINE, UiStyle.NIGHT)
			draw_string(font, base, label["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT, UiStyle.CREAM)

	## Where the hero is headed on this page (PIX-240): the person the bearing
	## is about where they stand now, its spot when it's on this map, or the
	## door here that starts the way to its map; NOWHERE when there's none,
	## or with the quest marks turned off.
	func goal_cell() -> Vector2i:
		return _cell_of(_lead("bearing"))

	## Where the main story goes next on this page while a side quest or a
	## bounty leads (PIX-253 step 2), found as the goal is: the hollow gold
	## diamond, so the main goal is never lost. NOWHERE while the story leads
	## (the goal is it), and where the two meet (the goal's diamond says it).
	func story_cell() -> Vector2i:
		var cell := _cell_of(_lead("story"))
		return Bearing.NOWHERE if cell == goal_cell() else cell

	## The HUD's lead `which` ("bearing", or "story" behind it), or {} where
	## there's no saying: no HUD, no page, the quest marks turned off.
	func _lead(which: String) -> Dictionary:
		var hud: Variant = world.get("hud") if world != null else null
		if hud == null or map == null or not GameState.settings.quest_marks:
			return {}
		var lead: Variant = hud.get(which)
		return lead if lead is Dictionary else {}

	## Where `lead` points on this page, in its cells: the person it's about
	## where they stand now, its spot when it's on a map drawn here, or the
	## door on the page where the way to its map leaves it (from where the
	## hero stands, on their page); NOWHERE for nowhere.
	func _cell_of(lead: Dictionary) -> Vector2i:
		if lead.is_empty():
			return Bearing.NOWHERE
		if home and String(lead["who"]) != "":
			for villager in world.get_tree().get_nodes_in_group("npcs"):
				if not villager.away and String(villager.data.get("id", "")) == lead["who"]:
					return Vector2i((villager.position / 16.0).floor()) + at_of(world.map.id)
		var to := String(lead["map_id"])
		if holds(to):
			var cell: Vector2i = lead["cell"]
			return cell + at_of(to) if cell != Bearing.NOWHERE else cell
		var ids: Array = _on_page().map(func(sheet: Dictionary) -> String: return sheet["id"])
		var exit := Atlas.way_off(ids, world.map.id if home else map.id, to)
		if exit.is_empty():
			return Bearing.NOWHERE
		return exit["cell"] + at_of(exit["map"])

	## A gold diamond with a dark rim, `size` px across, its points on the
	## screen's pixels; `hollow` (the main story's, behind the goal) a ring of
	## gold between dark lines, the page showing through.
	func _diamond(center: Vector2, size: float, hollow := false) -> void:
		var at := Waypoints.snap_point(center, _shown)
		for band: Array in Waypoints.diamond_bands(floorf(size / 2.0), hollow, _shown):
			var color := GOAL if band[2] else UiStyle.NIGHT
			var outer := _points(at, band[0])
			if band[1] <= 0.0:
				draw_colored_polygon(outer, color)
				continue
			# A band with a hole: its four sides, each from the outer edge in.
			var inner := _points(at, band[1])
			for side in 4:
				var next := (side + 1) % 4
				draw_colored_polygon(PackedVector2Array([outer[side], outer[next], inner[next], inner[side]]), color)

	## A diamond's four points, `reach` px from `at`: top, right, bottom, left.
	static func _points(at: Vector2, reach: float) -> PackedVector2Array:
		return PackedVector2Array([at + Vector2(0, -reach), at + Vector2(reach, 0), at + Vector2(0, reach), at + Vector2(-reach, 0)])

	## A shut gate's mark (PIX-254): a red cross in a dark rim, `size` px
	## across, its ends on the screen's pixels - no waypoint's square.
	func _cross(center: Vector2, size: float) -> void:
		var at := Waypoints.snap_point(center, _shown)
		var half := Waypoints.snap_length(floorf(size / 2.0), _shown)
		var reach := Vector2(half, half)
		var other := Vector2(half, -half)
		for stroke: Array in [[UiStyle.NIGHT, maxf(4.0, size * 0.55)], [SHUT, maxf(2.0, size * 0.3)]]:
			draw_line(at - reach, at + reach, stroke[0], stroke[1])
			draw_line(at - other, at + other, stroke[0], stroke[1])

	## A marker: a square of `color` in a dark rim, on the screen's pixels.
	func _marker(center: Vector2, size: float, color: Color) -> void:
		var squares := Waypoints.marker_squares(center, size, _shown)
		draw_rect(squares[0], UiStyle.NIGHT)
		draw_rect(squares[1], color)

	## The chosen waypoint's ring round its marker: two art pixels of gold
	## between dark lines, so it reads on night and on walked ground alike,
	## about the marker's own pixel (PIX-267).
	func _ring(center: Vector2, mark: float, grow: int) -> void:
		var squares := Waypoints.ring_squares(center, mark, grow, _shown)
		_band(squares[0], squares[3], UiStyle.NIGHT)
		_band(squares[1], squares[2], UiStyle.GOLD)

	## The frame between two squares about one middle, as four strips.
	func _band(outer: Rect2, inner: Rect2, color: Color) -> void:
		draw_rect(Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)), color)
		draw_rect(Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, outer.end.y - inner.end.y)), color)
		draw_rect(Rect2(Vector2(outer.position.x, inner.position.y), Vector2(inner.position.x - outer.position.x, inner.size.y)), color)
		draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(outer.end.x - inner.end.x, inner.size.y)), color)
