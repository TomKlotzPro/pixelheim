extends CanvasLayer
## The map screen (M/Tab): the current map in a window, painted with the
## tiles' map colours where the hero has been and night where they haven't
## (mapColors.ts port), the hero and discovered waypoints marked; beside it
## the waypoints, and fast travel to the staffed ones. Pauses the world.

const MAP_BOX := Vector2(760, 540)

var world: Node2D
var selected := 0
var painting: Control
var cards: Array[Dictionary] = []
var usable: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true

	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(UiStyle.heading(Catalog.place_name(world.map.id), 20, UiStyle.INK, Vector2(64, 28)))

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
	for mark: Array in [[Color.WHITE, "You"], [UiStyle.LAMP, "Waypoint"]]:
		var swatch := ColorRect.new()
		swatch.color = mark[0]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(UiStyle.label(mark[1], 12, UiStyle.FADED))
	add_child(legend)
	add_child(UiStyle.footer("M  close      W/S  choose      E  travel", Vector2(64, 668)))
	_highlight()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("map") or Input.is_action_just_pressed("ui_cancel"):
		_close()
		return
	if usable.is_empty():
		return
	if Input.is_action_just_pressed("move_down"):
		selected = (selected + 1) % usable.size()
		_highlight()
	elif Input.is_action_just_pressed("move_up"):
		selected = (selected - 1 + usable.size()) % usable.size()
		_highlight()
	elif Input.is_action_just_pressed("interact"):
		var destination := usable[selected]
		_close()
		world.travel_to(destination)


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


func _close() -> void:
	get_tree().paused = false
	queue_free()


class Painting extends Control:
	var world: Node2D
	var tile_px := 4

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
		_marker(Vector2(world.player_cell) * tile_px + Vector2.ONE * tile_px / 2.0, mark, Color.WHITE)

	func _marker(center: Vector2, size: float, color: Color) -> void:
		var half := floorf(size / 2.0)
		draw_rect(Rect2(center - Vector2(half + 2, half + 2), Vector2(half * 2 + 4, half * 2 + 4)), UiStyle.NIGHT)
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2)), color)
