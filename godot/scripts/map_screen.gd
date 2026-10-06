extends CanvasLayer
## The map screen (M/Tab): paints the current map with fog over undiscovered
## tiles (mapColors.ts port), marks the hero and discovered waypoints, and
## offers fast travel to usable ones. Pauses the world while open.

var world: Node2D
var selected := 0
var painting: Control
var rows: Array[Label] = []
var usable: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.043, 0.047, 0.063)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := Label.new()
	title.text = Catalog.place_name(world.map.id)
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(80, 32)
	add_child(title)

	painting = Painting.new()
	painting.world = world
	var tile_px: int = clampi(mini(int(700.0 / world.map.size.x), int(520.0 / world.map.size.y)), 2, 10)
	painting.tile_px = tile_px
	painting.position = Vector2(80, 88)
	painting.custom_minimum_size = Vector2(world.map.size * tile_px)
	add_child(painting)

	var list_title := Label.new()
	list_title.text = "Waypoints"
	list_title.add_theme_font_size_override("font_size", 18)
	list_title.position = Vector2(860, 88)
	add_child(list_title)

	var y := 128.0
	for waypoint: Dictionary in Interactables.waypoints():
		if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
			continue
		var row := Label.new()
		var staffed := Interactables.waypoint_usable(
			waypoint, GameState.world.discovered, GameState.settlement.settlers
		)
		row.text = waypoint["name"] + ("" if staffed else "  (unstaffed)")
		row.position = Vector2(880, y)
		add_child(row)
		rows.append(row)
		if staffed:
			usable.append(waypoint)
		else:
			row.modulate = Color(1, 1, 1, 0.4)
		y += 28
	if rows.is_empty():
		var none := Label.new()
		none.text = "Nothing discovered yet."
		none.modulate = Color(1, 1, 1, 0.5)
		none.position = Vector2(880, y)
		add_child(none)

	var hint := Label.new()
	hint.text = "M  close      W/S  choose      E  travel"
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.position = Vector2(80, 660)
	add_child(hint)
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

func _highlight() -> void:
	var usable_index := 0
	for row in rows:
		var is_usable: bool = row.modulate.a > 0.9
		if is_usable:
			row.text = ("> " if usable_index == selected else "  ") + row.text.trim_prefix("> ").strip_edges()
			usable_index += 1

func _close() -> void:
	get_tree().paused = false
	queue_free()


class Painting extends Control:
	var world: Node2D
	var tile_px := 4

	func _draw() -> void:
		var seen: Dictionary = GameState.world.discovered.get(world.map.id, {})
		for cell: Vector2i in world.map.grid:
			var color: Color = (
				WorldTiles.map_color(world.map.grid[cell])
				if seen.has(cell) else WorldTiles.FOG_COLOR
			)
			draw_rect(Rect2(Vector2(cell * tile_px), Vector2(tile_px, tile_px)), color)
		for waypoint: Dictionary in Interactables.waypoints():
			if waypoint["mapId"] != world.map.id:
				continue
			if not Interactables.waypoint_discovered(waypoint, GameState.world.discovered):
				continue
			var at := Vector2(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
			draw_circle(at * tile_px + Vector2.ONE * tile_px / 2.0, tile_px * 0.9, Color(1, 0.85, 0.3))
		var hero := Vector2(world.player_cell) * tile_px + Vector2.ONE * tile_px / 2.0
		draw_circle(hero, tile_px * 0.8, Color.WHITE)
