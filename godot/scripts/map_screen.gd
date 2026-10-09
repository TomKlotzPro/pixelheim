extends Screen
## The map screen (M/Tab): the current map in a window, painted with the
## tiles' map colours where the hero has been and night where they haven't
## (mapColors.ts port), the hero, discovered waypoints and the lairs the
## bounty board has posted (PIX-156) marked; beside it
## the waypoints, and fast travel to the staffed ones. Pauses the world.
## The waypoint chosen in the list is ringed on the map and named there with
## the region it sets you down in (PIX-241), so you see where you'd land
## before you go; one on another map turns the map to that map's page.
## Arrows or the pad choose, and so does pointing at a card; E, the pad's A
## or a click on the chosen card travels.

const MAP_BOX := Vector2(760, 540)

var world: Node2D
## The chosen staffed waypoint, by its place in `usable`; -1 while none is
## (they're all on other maps, and choosing one turns the page).
var selected := -1
var painting: Painting
var frame: PanelContainer
var title: Label
var legend: HBoxContainer
var footer: Control
## Which keys the footer shows now: what's to choose and whether E travels.
var _footer_for := -2
var cards: Array[Dictionary] = []
var usable: Array[Dictionary] = []
## Other maps drawn for a waypoint there, loaded once a visit, by id.
var _maps := {}


## How wide a waypoint card's words run before they wrap: the side panel's
## width less its margins.
const CARD_TEXT := 300.0

func _open() -> void:
	closing_actions = [&"map"]
	layer = 5
	dim()
	title = UiStyle.title(Catalog.place_name(world.map.id), Vector2(64, UiStyle.TITLE_AT.y))
	add_child(title)

	frame = PanelContainer.new()
	frame.position = Vector2(56, 72)
	frame.add_theme_stylebox_override("panel", UiStyle.window(14))
	add_child(frame)
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
	for waypoint: Dictionary in Interactables.waypoints():
		if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
			continue
		var staffed := Interactables.waypoint_usable(
			waypoint, GameState.world.discovered, GameState.settlement.settlers
		)
		var card := PanelContainer.new()
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lines)
		# Wrapped to the panel (Solid Ground): a long line in French breaks
		# instead of pushing the panel off the screen.
		lines.add_child(Layout.wrapped(UiStyle.label(waypoint["name"], 16, UiStyle.INK if staffed else UiStyle.FADED), CARD_TEXT))
		lines.add_child(Layout.wrapped(UiStyle.label(
			Catalog.place_name(waypoint["mapId"]) if staffed else "Unstaffed: no one keeps this post yet",
			12, UiStyle.FADED
		), CARD_TEXT))
		column.add_child(card)
		cards.append({"card": card, "usable": staffed})
		if staffed:
			# Pointing at a card chooses it; clicking the chosen one travels.
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_entered.connect(_choose.bind(usable.size()))
			card.gui_input.connect(_on_card_input.bind(usable.size()))
			usable.append(waypoint)
	if cards.is_empty():
		var none := UiStyle.label("Nothing discovered yet. Waypoints you find on your travels show up here.", 12, UiStyle.FADED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(300, 0)
		column.add_child(none)

	legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	legend.position = Vector2(64, 630)
	add_child(legend)
	selected = Waypoints.first_on(usable, world.map.id)
	_show()


func _command(event: InputEvent) -> Callable:
	if usable.is_empty():
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
	_show()


func _travel() -> void:
	var destination := usable[selected]
	close()
	world.travel_to(destination)


## The chosen waypoint's id, "" while none is (the harness reports it).
func destination_id() -> String:
	return String(usable[selected]["id"]) if selected >= 0 else ""


## The list and the map agree on the choice: its card wears the red rim,
## and the map turns to the page it's on, ringed and named there; the title,
## the legend and the keys follow the page.
func _show() -> void:
	_highlight()
	var destination: Dictionary = usable[selected] if selected >= 0 else {}
	var map: MapData = world.map
	if not destination.is_empty() and destination["mapId"] != map.id:
		map = _map(destination["mapId"])
	var home: bool = map == world.map
	# Whole pixels per tile, as large as the window allows.
	var tile_px: int = clampi(mini(int(MAP_BOX.x / map.size.x), int(MAP_BOX.y / map.size.y)), 2, 12)
	painting.paint(map, tile_px, home, destination)
	# A smaller page shrinks the window round it.
	frame.reset_size()
	title.text = Catalog.place_name(map.id)
	_fill_legend(map, home)
	_set_footer()


## Another map's page, as the town has grown, loaded once.
func _map(map_id: String) -> MapData:
	if not _maps.has(map_id):
		_maps[map_id] = world.load_map(map_id)
	return _maps[map_id]


## The chosen staffed waypoint wears the red frame.
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


## What the marks on this page mean: "You" only where the hero is.
func _fill_legend(map: MapData, home: bool) -> void:
	Layout.clear(legend)
	var marks: Array = []
	if home:
		marks.append([Color.WHITE, "You"])
	marks.append([UiStyle.LAMP, "Waypoint"])
	if not Hunts.living_on(map.id, GameState.questing.board_floors(), GameState.progression.hunted).is_empty():
		marks.append([Painting.LAIR, "Lair"])
	if home and not Painting.givers(world).is_empty():
		marks.append([Painting.QUEST, "Quest"])
	if painting.goal_cell() != Bearing.NOWHERE:
		marks.append([Painting.GOAL, "Goal"])
	for mark: Array in marks:
		var swatch := ColorRect.new()
		swatch.color = mark[0]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(UiStyle.label(mark[1], 12, UiStyle.FADED))


## The keys as they stand: E travels only once a waypoint is chosen.
func _set_footer() -> void:
	var state := -1 if usable.is_empty() else (0 if selected < 0 else 1)
	if state == _footer_for:
		return
	_footer_for = state
	if footer != null:
		remove_child(footer)
		footer.queue_free()
	if state < 0:
		footer = UiStyle.screen_footer("{key:map} / Esc  close")
	elif state == 0:
		footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:map} / Esc  close")
	else:
		footer = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:interact}  travel      {key:map} / Esc  close")
	add_child(footer)



class Painting extends Control:
	const LAIR := Color("c071ff")
	const QUEST := Color("5fdc7a")
	## Where the hero is headed (PIX-240): the quest marks' gold.
	const GOAL := Color("f2c14e")
	var world: Node2D
	## The page shown: the hero's map, or the chosen waypoint's.
	var map: MapData
	var tile_px := 4
	## Whether the hero is on this page (their marker, the quest givers).
	var home := true
	## The chosen waypoint, ringed and named; {} while none is.
	var destination := {}
	## When it was chosen (ms): its ring starts wide from there.
	var chosen_at := 0
	var tag: PanelContainer

	## The villagers here with a word for the hero (PIX-171): a quest to
	## offer, or one ready to turn in.
	static func givers(on: Node2D) -> Array[Node]:
		var out: Array[Node] = []
		for villager in on.get_tree().get_nodes_in_group("npcs"):
			if not villager.away and Quests.awaits_word(villager.data["id"], GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open):
				out.append(villager)
		return out

	## Turns to `page` at `px` pixels a tile, with `chosen` ringed on it.
	func paint(page: MapData, px: int, hero_here: bool, chosen: Dictionary) -> void:
		map = page
		tile_px = px
		home = hero_here
		destination = chosen
		chosen_at = Time.get_ticks_msec()
		custom_minimum_size = Vector2(map.size * tile_px)
		_name_destination()
		queue_redraw()

	## The ring breathes while a waypoint is chosen, unless motion is reduced.
	func _process(_delta: float) -> void:
		if not destination.is_empty() and not GameState.settings.reduce_motion:
			queue_redraw()

	## Markers are pixel squares with a dark rim, a little bigger than a tile.
	func _mark() -> float:
		return maxf(tile_px * 1.6, 6.0)

	## The ring's half-width round the chosen marker, grown by `grow`: at its
	## smallest it hugs the marker's dark rim, at its widest it takes in the
	## spot two steps off where travelling sets you down.
	func _ring_half(grow: int) -> float:
		return floorf(_mark() / 2.0) + 6.0 + grow

	func _center(cell: Vector2i) -> Vector2:
		return Vector2(cell) * tile_px + Vector2.ONE * tile_px / 2.0

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
		var region := Waypoints.region_name(destination, map)
		if region != "":
			lines.add_child(UiStyle.label(region, 12, UiStyle.FADED))
		add_child(tag)
		tag.reset_size()
		# Clear of the ring at its widest, dark line and all.
		var widest := _ring_half(Waypoints.PULSE_PX) + 2.0
		tag.position = Waypoints.tag_at(
			_center(Waypoints.cell(destination)).floor(), widest, tag.get_combined_minimum_size(), custom_minimum_size
		)

	func _draw() -> void:
		if map == null:
			return
		var seen: Dictionary = GameState.world.discovered.get(map.id, {})
		# The whole map is night until walked.
		draw_rect(Rect2(Vector2.ZERO, Vector2(map.size * tile_px)), UiStyle.NIGHT)
		for cell: Vector2i in map.grid:
			if seen.has(cell):
				draw_rect(Rect2(Vector2(cell * tile_px), Vector2(tile_px, tile_px)), WorldTiles.map_color(map.grid[cell]))
		var mark := _mark()
		for waypoint: Dictionary in Interactables.waypoints():
			if waypoint["mapId"] != map.id:
				continue
			if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
				continue
			_marker(_center(Waypoints.cell(waypoint)), mark, UiStyle.LAMP)
		# The lairs of the named monsters the board has posted (PIX-156).
		for entry in Hunts.living_on(map.id, GameState.questing.board_floors(), GameState.progression.hunted):
			_marker(_center(Hunts.lair(entry)), mark, LAIR)
		if home:
			for villager in givers(world):
				_marker(_center(Vector2i((villager.position / 16.0).floor())), mark, QUEST)
		# The chosen waypoint (PIX-241), under the hero's own mark.
		if not destination.is_empty():
			var grow := Waypoints.ring_grow(Time.get_ticks_msec() - chosen_at, GameState.settings.reduce_motion)
			_ring(_center(Waypoints.cell(destination)).floor(), _ring_half(grow))
		# Where the hero is headed (PIX-240), a diamond under the hero's mark.
		var goal := goal_cell()
		if goal != Bearing.NOWHERE:
			_diamond(_center(goal).floor(), mark + 6.0)
		if home:
			var hero: Vector2i = world.player_cell
			_marker(_center(hero), mark, Color.WHITE)

	## Where the hero is headed on this page (PIX-240): the person the bearing
	## is about where they stand now, its spot when it's on this map, or the
	## door here that starts the way to its map; NOWHERE when there's none,
	## or with the quest marks turned off.
	func goal_cell() -> Vector2i:
		var hud: Variant = world.get("hud") if world != null else null
		if hud == null or map == null or not GameState.settings.quest_marks:
			return Bearing.NOWHERE
		var bearing: Dictionary = hud.bearing
		if bearing.is_empty():
			return Bearing.NOWHERE
		if home and String(bearing["who"]) != "":
			for villager in world.get_tree().get_nodes_in_group("npcs"):
				if not villager.away and String(villager.data.get("id", "")) == bearing["who"]:
					return Vector2i((villager.position / 16.0).floor())
		if bearing["map_id"] == map.id:
			return bearing["cell"]
		return Bearing.way_out(map.id, String(bearing["map_id"]))

	## A gold diamond with a dark rim, `size` px across.
	func _diamond(center: Vector2, size: float) -> void:
		var half := floorf(size / 2.0)
		var rim := half + 3.0
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -rim), center + Vector2(rim, 0), center + Vector2(0, rim), center + Vector2(-rim, 0)]), UiStyle.NIGHT)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)]), GOAL)

	func _marker(center: Vector2, size: float, color: Color) -> void:
		var half := floorf(size / 2.0)
		draw_rect(Rect2(center - Vector2(half + 2, half + 2), Vector2(half * 2 + 4, half * 2 + 4)), UiStyle.NIGHT)
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2)), color)

	## A square ring `half` px out from `center`: two art pixels of gold
	## between dark lines, so it reads on night and on walked ground alike.
	func _ring(center: Vector2, half: float) -> void:
		var outer := Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2))
		_band(outer.grow(2), 8, UiStyle.NIGHT)
		_band(outer, 4, UiStyle.GOLD)

	## A rect's edge `width` px thick, inwards, as four whole-pixel strips.
	func _band(rect: Rect2, width: float, color: Color) -> void:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), color)
		draw_rect(Rect2(rect.position + Vector2(0, width), Vector2(width, rect.size.y - width * 2)), color)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - width, width), Vector2(width, rect.size.y - width * 2)), color)
