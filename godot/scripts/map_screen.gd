extends Screen
## The map screen (M/Tab): the current map in a window, painted with the
## tiles' map colours where the hero has been and night where they haven't
## (mapColors.ts port), the hero, discovered waypoints and the lairs the
## bounty board has posted (PIX-156) marked; beside it
## the waypoints, and fast travel to the staffed ones. Pauses the world.

const MAP_BOX := Vector2(760, 540)

var world: Node2D
var selected := 0
var painting: Control
var cards: Array[Dictionary] = []
var usable: Array[Dictionary] = []


func _open() -> void:
	closing_actions = [&"map"]
	layer = 5
	dim()
	add_child(UiStyle.heading(Catalog.place_name(world.map.id), 20, UiStyle.CREAM, Vector2(64, 28)))

	var frame := PanelContainer.new()
	frame.position = Vector2(56, 72)
	frame.add_theme_stylebox_override("panel", UiStyle.window(14))
	add_child(frame)
	painting = Painting.new()
	painting.world = world
	# Whole pixels per tile, as large as the window allows.
	var tile_px: int = clampi(mini(int(MAP_BOX.x / world.map.size.x), int(MAP_BOX.y / world.map.size.y)), 2, 12)
	painting.tile_px = tile_px
	painting.custom_minimum_size = Vector2(world.map.size * tile_px)
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
		card.add_child(lines)
		lines.add_child(UiStyle.label(waypoint["name"], 16, UiStyle.INK if staffed else UiStyle.FADED))
		lines.add_child(UiStyle.label(
			Catalog.place_name(waypoint["mapId"]) if staffed else "Unstaffed: no one keeps this post yet",
			12, UiStyle.FADED
		))
		column.add_child(card)
		cards.append({"card": card, "usable": staffed})
		if staffed:
			usable.append(waypoint)
	if cards.is_empty():
		var none := UiStyle.label("Nothing discovered yet. Waypoints you find on your travels show up here.", 12, UiStyle.FADED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(300, 0)
		column.add_child(none)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	legend.position = Vector2(64, 630)
	var marks: Array = [[Color.WHITE, "You"], [UiStyle.LAMP, "Waypoint"]]
	if not Hunts.living_on(world.map.id, GameState.board_floors(), GameState.progression.hunted).is_empty():
		marks.append([Painting.LAIR, "Lair"])
	if not Painting.givers(world).is_empty():
		marks.append([Painting.QUEST, "Quest"])
	for mark: Array in marks:
		var swatch := ColorRect.new()
		swatch.color = mark[0]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(UiStyle.label(mark[1], 12, UiStyle.FADED))
	add_child(legend)
	add_child(UiStyle.footer("{key:map}  close      {key:move_up}/{key:move_down}  choose      {key:interact}  travel", Vector2(64, 668)))
	_highlight()


func _command(event: InputEvent) -> Callable:
	if usable.is_empty():
		return Callable()
	if event.is_action_pressed("move_down"):
		return func() -> void:
			selected = (selected + 1) % usable.size()
			_highlight()
	if event.is_action_pressed("move_up"):
		return func() -> void:
			selected = (selected - 1 + usable.size()) % usable.size()
			_highlight()
	if event.is_action_pressed("interact"):
		return func() -> void:
			var destination := usable[selected]
			close()
			world.travel_to(destination)
	return Callable()


## The chosen staffed waypoint wears the gold frame.
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



class Painting extends Control:
	const LAIR := Color("c071ff")
	const QUEST := Color("5fdc7a")
	var world: Node2D
	var tile_px := 4

	## The villagers here with a word for the hero (PIX-171): a quest to
	## offer, or one ready to turn in.
	static func givers(on: Node2D) -> Array[Node]:
		var out: Array[Node] = []
		for villager in on.get_tree().get_nodes_in_group("npcs"):
			if not villager.away and Quests.awaits_word(villager.data["id"], GameState.progression.quests, GameState.pack.items, GameState.quest_open):
				out.append(villager)
		return out

	func _draw() -> void:
		var seen: Dictionary = GameState.world.discovered.get(world.map.id, {})
		# The whole map is night until walked.
		draw_rect(Rect2(Vector2.ZERO, Vector2(world.map.size * tile_px)), UiStyle.NIGHT)
		for cell: Vector2i in world.map.grid:
			if seen.has(cell):
				draw_rect(Rect2(Vector2(cell * tile_px), Vector2(tile_px, tile_px)), WorldTiles.map_color(world.map.grid[cell]))
		# Markers are pixel squares with a dark rim, a little bigger than a tile.
		var mark := maxf(tile_px * 1.6, 6.0)
		for waypoint: Dictionary in Interactables.waypoints():
			if waypoint["mapId"] != world.map.id:
				continue
			if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
				continue
			var at := Vector2(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
			_marker(at * tile_px + Vector2.ONE * tile_px / 2.0, mark, UiStyle.LAMP)
		# The lairs of the named monsters the board has posted (PIX-156).
		for entry in Hunts.living_on(world.map.id, GameState.board_floors(), GameState.progression.hunted):
			_marker(Vector2(Hunts.lair(entry)) * tile_px + Vector2.ONE * tile_px / 2.0, mark, LAIR)
		for villager in givers(world):
			var cell := Vector2i((villager.position / 16.0).floor())
			_marker(Vector2(cell) * tile_px + Vector2.ONE * tile_px / 2.0, mark, QUEST)
		_marker(Vector2(world.player_cell) * tile_px + Vector2.ONE * tile_px / 2.0, mark, Color.WHITE)

	func _marker(center: Vector2, size: float, color: Color) -> void:
		var half := floorf(size / 2.0)
		draw_rect(Rect2(center - Vector2(half + 2, half + 2), Vector2(half * 2 + 4, half * 2 + 4)), UiStyle.NIGHT)
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2)), color)
