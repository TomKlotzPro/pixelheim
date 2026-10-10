class_name Hud
extends Node
## The HUD over the world (Solid Ground, PIX-260: moved out of world.gd as
## it was): its layer and widgets - the sky's tint, the hero's dock, the
## boss bar, the nameplate over a signed door, the main quest's next step,
## the card naming where the hero has come to - laid out on the screen as it
## is; and the first-time hints. The message
## plate and the battle log stand on its layer too (Messages builds them).
## Which of GameState's signals reach it is still the world's wiring.

var world: Node
## The HUD's layer (over the glow's, PIX-222).
var root: CanvasLayer
## Day/night tint, under the HUD widgets and over the world.
var sky_overlay: ColorRect
## The hero panel: health, resource, xp, gold, the screens (HudPanel).
var dock: Control
var boss_bar: Control
## The first-time hint on it now (PIX-160).
var hint_card: PanelContainer
static var _hint_doc := {}
static var _hint_generation := 0
## The main quest's next step, quietly above the dock (PIX-144): a dark
## pill holding "Next" and the step.
var objective_box: PanelContainer
var objective_label: Label
## The nameplate over the signed door the hero walks up to (ShopSign).
var nameplate: PanelContainer
var nameplate_door := Vector2i(-1, -1)
## Where the hero has come to (PlaceTitle, PIX-269): the place and region
## named last, when each name was last shown, and the card showing it now.
var place_was := {}
var place_shown := {}
var place_card: PanelContainer
var _place_map: MapData
var _place_regions := false
## The boss slayer's edge while it lasts (PIX-232): a small plate at the top
## left, its time running down.
var edge_plate: PanelContainer
## Where the hero is headed (Bearing, PIX-239): the line above the dock, the
## map's goal and the arrow at the view's edge read it; looked at again
## twice a second.
const BEARING_SECONDS := 0.5
var bearing := {}
## The main story's lead while a side quest or a bounty leads (Bearing.behind,
## PIX-253 step 2): the map keeps it as a hollow gold diamond. {} while the
## story leads itself.
var story := {}
## Whether the bearing is the main story's, or a thread that carries it:
## the arrow is gold then (Bearing.tells_story).
var leads_story := true
var _bearing_left := 0.0
## The arrow at the view's edge (PIX-240): toward where the hero is headed
## while that's off screen; how far in from the edge it stands.
var arrow: Arrow
## The hour (PIX-246): a small plate at the top right, a dial (the sun by day,
## the moon by night) and the time. A quest's run clock stands under it.
var clock_plate: PanelContainer
var _clock_text: Label
var _clock_dial: Dial
const ARROW_INSET := 26.0


## The layer and its widgets, in the order they stand: the sky's tint, the
## dock, the boss bar, the battle log, the nameplate, the message plate and
## the objective line. Placed at once, and again as the window changes.
func build() -> void:
	var hud := CanvasLayer.new()
	# Over the glow's layer (PIX-222: LightRig.GLOW_LAYER), so it never blooms.
	hud.layer = 2
	world.add_child(hud)
	# Day/night tint sits under the HUD widgets, over the world.
	sky_overlay = ColorRect.new()
	sky_overlay.color = Color(0, 0, 0, 0)
	sky_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sky_overlay)
	# The hero's dock along the bottom; the battle log floats above its left.
	dock = preload("res://scripts/hud_dock.gd").new()
	dock.world = world
	hud.add_child(dock)
	boss_bar = preload("res://scripts/boss_bar.gd").new()
	hud.add_child(boss_bar)
	world.messages.build_log(hud)
	nameplate = PanelContainer.new()
	nameplate.add_theme_stylebox_override("panel", UiStyle.window(8))
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.visible = false
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_child(lines)
	var title := UiStyle.strong("", 16, UiStyle.LAMP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(title)
	var keeper := UiStyle.label("", 12, UiStyle.INK)
	keeper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(keeper)
	hud.add_child(nameplate)
	world.messages.build_plate(hud)
	objective_box = PanelContainer.new()
	objective_box.add_theme_stylebox_override("panel", UiStyle.plate())
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.modulate.a = 0.0
	var objective_row := HBoxContainer.new()
	objective_row.add_theme_constant_override("separation", 8)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.add_child(objective_row)
	objective_row.add_child(UiStyle.plate_tag("Next"))
	objective_label = UiStyle.plate_text("")
	objective_row.add_child(objective_label)
	# Centred over the dock whatever the step's length.
	objective_box.resized.connect(func() -> void: objective_box.position.x = roundf((1280 - objective_box.size.x) / 2.0))
	hud.add_child(objective_box)
	root = hud
	place()
	get_tree().root.size_changed.connect(place)


## The HUD's 1280x720 layout on the screen as it is (PIX-162): along the
## bottom, centred across, with the sky's tint edge to edge. On a desktop the
## canvas is 1280x720 and nothing moves.
func place() -> void:
	if root == null:
		return
	root.offset = Touch.hud_offset(world)
	sky_overlay.position = -root.offset
	sky_overlay.size = Touch.view_size(world)


## A first-time hint (PIX-160): a card under the top of the screen that
## says what something is, once per player (GameSettings.hints_seen, `key`
## when one hint has many, a skill each) and never with hints off. It doesn't
## stop the game, and fades by itself.
func hint(id: String, values := {}, key := "") -> void:
	var settings := GameState.settings
	var seen_id := key if key != "" else id
	if not settings.hints or seen_id in settings.hints_seen or root == null:
		return
	settings.hints_seen.append(seen_id)
	settings.save_file()
	if _hint_doc.is_empty() or _hint_generation != Text.generation:
		_hint_doc = Text.localize(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json")))
		_hint_generation = Text.generation
	var title := String(_hint_doc[id]["title"])
	var text := Controls.say(String(_hint_doc[id]["text"]))
	for name: String in values:
		title = title.replace("{%s}" % name, str(values[name]))
		text = text.replace("{%s}" % name, str(values[name]))
	if hint_card != null:
		hint_card.queue_free()
	hint_card = PanelContainer.new()
	hint_card.add_theme_stylebox_override("panel", UiStyle.window(12))
	hint_card.position = Vector2(340, boss_bar.bottom() + 6 if boss_bar.following() else 18.0)
	hint_card.custom_minimum_size = Vector2(600, 0)
	hint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	hint_card.add_child(lines)
	lines.add_child(UiStyle.strong(title, 16, UiStyle.LAMP))
	var body := UiStyle.label(text, UiStyle.reading(14), UiStyle.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(570, 0)
	lines.add_child(body)
	root.add_child(hint_card)
	hint_card.modulate.a = 0.0
	var show := hint_card.create_tween()
	show.tween_property(hint_card, "modulate:a", 1.0, 0.3)
	show.tween_interval(10.0 if settings.large_text else 7.0)
	show.tween_property(hint_card, "modulate:a", 0.0, 0.6)
	show.tween_callback(hint_card.queue_free)


## A first-time hint stands under the boss bar while one is up (PIX-210).
func keep_hint_clear() -> void:
	if hint_card != null and is_instance_valid(hint_card):
		hint_card.position.y = boss_bar.bottom() + 6 if boss_bar.following() else 18.0


## A title over the world for a moment (PIX-232: a boss's fall): the big
## word and a line under it on a dark plate, held a beat, then faded. It runs
## on the real clock, so the boss's slow motion doesn't hold it. An empty
## line leaves the title alone on its plate.
func title_card(title: String, line: String) -> PanelContainer:
	if root == null:
		return null
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.plate(16))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lines)
	var big := UiStyle.strong(title, 36, UiStyle.LAMP)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(big)
	var small := UiStyle.label(line, UiStyle.reading(16), UiStyle.CREAM)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.visible = line != ""
	lines.add_child(small)
	root.add_child(card)
	card.reset_size()
	card.position = Vector2(roundf((1280 - card.size.x) / 2.0), 140)
	card.modulate.a = 0.0
	var show := card.create_tween().set_ignore_time_scale(true)
	show.tween_property(card, "modulate:a", 1.0, 0.3)
	show.tween_interval(2.4)
	show.tween_property(card, "modulate:a", 0.0, 0.6)
	show.tween_callback(card.queue_free)
	return card


## Names where the hero has come to (PIX-269: the way between maps is the
## land itself, and the place says its name once you're there): the map's
## place on entering it, a region of the Ashenreach on walking into it, as
## a title card (PlaceTitle decides). `quiet` notes where they are without
## a card (the map the game opens on). A new card takes the last one's place.
func name_place(map: MapData, cell: Vector2i, quiet := false) -> void:
	# Whether the map names its regions, learned once a visit, not each step.
	if map != _place_map:
		_place_map = map
		_place_regions = Atlas.names_regions(map)
	var here := PlaceTitle.at(map, cell, _place_regions)
	var card := PlaceTitle.next(here, place_was, place_shown, GameClock.msec(), quiet)
	if card.is_empty():
		return
	_drop_place_card()
	place_card = title_card(card[0], card[1])


## Forgets where the hero has been named and takes its card down at once
## (the look book, between shots: a card over every scene would hide it).
func forget_places() -> void:
	place_was.clear()
	place_shown.clear()
	_drop_place_card()


func _drop_place_card() -> void:
	if is_instance_valid(place_card):
		place_card.queue_free()
	place_card = null


## The boss slayer's edge (PIX-232) at the top left while it lasts, its
## minutes and seconds running down; gone with it.
func update_edge() -> void:
	var left: float = GameState.spoils.slayer_left
	if left <= 0.0 or root == null:
		if edge_plate != null:
			edge_plate.queue_free()
			edge_plate = null
		return
	if edge_plate == null:
		edge_plate = PanelContainer.new()
		edge_plate.add_theme_stylebox_override("panel", UiStyle.plate(12))
		edge_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge_plate.add_child(UiStyle.strong("", 16, UiStyle.LAMP))
		edge_plate.position = Vector2(24, 16)
		root.add_child(edge_plate)
	var seconds := ceili(left)
	var shown: Label = edge_plate.get_child(0)
	shown.text = Text.t("Boss slayer +%d%%  %d:%02d") % [roundi(Spoils.SLAYER_DAMAGE * 100), seconds / 60, seconds % 60]
	edge_plate.reset_size()


## The boards on the square, explained the first time the hero walks up.
func hint_boards() -> void:
	if world.map.id != "town" or GameState.progression.prologue != Prologue.DONE:
		return
	var cell := Vector2(world.player_cell)
	if cell.distance_to(Vector2(Town.project_board())) <= 3.0:
		hint("board")
	if cell.distance_to(Vector2(Town.bounty_board())) <= 2.0 \
			and not Hunts.notices(GameState.questing.board_floors(), GameState.progression.hunted).is_empty():
		hint("bounty")


func on_hp_changed(hp: int, max_hp: int) -> void:
	dock.refresh()
	# Hurt on the first night: how to drink a potion, once (PIX-197).
	if GameState.progression.prologue != Prologue.DONE and hp * 2 < max_hp and hp > 0:
		hint("potion")


## The line above the dock (PIX-144): the main quest's next step, faded out
## in a fight, under a flashing message and once the story is done; hidden
## while the world is paused (menus, conversations, cutscenes: the world's
## _notification).
func update_objective() -> void:
	var messages: Messages = world.messages
	# Where the hero is headed (PIX-239): the followed quest or the story's
	# next step, with its place and count; looked at twice a second.
	_bearing_left -= get_process_delta_time()
	if _bearing_left <= 0.0:
		_bearing_left = BEARING_SECONDS
		look_again()
	var text := Bearing.line(bearing)
	if GameState.progression.prologue != Prologue.DONE:
		text = Prologue.objective(GameState.progression.prologue, GameState.progression.prologue_doused.size(), GameState.questing.first_skill_heals())
	if text != objective_label.text:
		objective_label.text = text
		objective_box.reset_size()
	objective_box.position.y = (dock.top() if dock != null and dock.top() > 0 else 690.0) - 38
	# A message stands where the objective line does and grows upward, so a
	# long one (a barred gate, a quest's words) never runs under the dock.
	if messages.message_box.modulate.a > 0.0:
		messages.fit()
	messages.message_box.position.y = objective_box.position.y + objective_box.size.y - messages.message_box.size.y
	# The battle log stands on the objective line, or on a taller message
	# (PIX-211), and grows upward, so a long kill never runs into either.
	var under := objective_box.position.y
	if messages.message_box.modulate.a > 0.0:
		under = minf(under, messages.message_box.position.y)
	messages.log_box.reset_size()
	messages.log_box.position.y = under - 6 - messages.log_box.size.y
	var show: bool = text != "" and not world.foes.in_fight() and messages.message_box.modulate.a < 0.05
	var target := 1.0 if show else 0.0
	if objective_box.get_meta("fading_to", -1.0) != target:
		objective_box.set_meta("fading_to", target)
		objective_box.create_tween().tween_property(objective_box, "modulate:a", target, 0.3)


## Where the hero is headed, looked at again now: the active lead, and the
## main story's behind it while something else leads.
func look_again() -> void:
	bearing = Bearing.active(GameState.progression, GameState.settlement, GameState.pack.items, GameState.world.discovered)
	story = Bearing.behind(bearing, GameState.progression, GameState.settlement, GameState.pack.items, GameState.world.discovered)
	leads_story = Bearing.tells_story(bearing)


## The clock as the steps stand (PIX-246); redrawn only when the minute turns.
func update_clock() -> void:
	if root == null:
		return
	if clock_plate == null:
		clock_plate = PanelContainer.new()
		clock_plate.add_theme_stylebox_override("panel", UiStyle.plate(10))
		clock_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clock_dial = Dial.new()
		row.add_child(_clock_dial)
		_clock_text = UiStyle.strong("", 16, UiStyle.CREAM)
		row.add_child(_clock_text)
		clock_plate.add_child(row)
		root.add_child(clock_plate)
	var time := DayNight.clock(GameState.world.steps)
	var text := "%02d:%02d" % [time.x, time.y]
	if _clock_text.text == text:
		return
	_clock_text.text = text
	_clock_dial.night = DayNight.is_night(GameState.world.steps)
	_clock_dial.queue_redraw()
	clock_plate.reset_size()
	clock_plate.position = Vector2(1280 - 24 - clock_plate.size.x, 16)


## The arrow at the view's edge (PIX-240): toward the bearing's spot on this
## map, or the door that starts the way to its map, while it's off screen;
## gone once it's in view, with nowhere to head for, on the first night
## (which has its own steps), or with the quest marks turned off. Gold while
## it leads the main story, cream for a side quest or a bounty (PIX-253
## step 2).
func update_arrow() -> void:
	if root == null:
		return
	if arrow == null:
		arrow = Arrow.new()
		root.add_child(arrow)
	arrow.main = leads_story
	var target := _bearing_point()
	# Above the line over the dock too (the objective's plate stands there),
	# never on its words.
	var bottom: float = minf(world.camera_rig.dock_top(), objective_box.position.y - 4.0) if objective_box != null else world.camera_rig.dock_top()
	var area := Rect2(Vector2(ARROW_INSET, ARROW_INSET), Vector2(1280.0 - 2.0 * ARROW_INSET, bottom - 2.0 * ARROW_INSET))
	var on_screen := Vector2.ZERO
	if target != Vector2.INF:
		on_screen = get_viewport().get_canvas_transform() * target
	arrow.visible = target != Vector2.INF and not area.has_point(on_screen)
	if not arrow.visible:
		return
	var from := area.get_center()
	var heading := (on_screen - from).normalized()
	arrow.position = Arrow.edge_point(area, from, heading).round()
	arrow.rotation = heading.angle()


## Where the arrow points in the world, or Vector2.INF for nowhere.
func _bearing_point() -> Vector2:
	if bearing.is_empty() or not GameState.settings.quest_marks or GameState.progression.prologue != Prologue.DONE:
		return Vector2.INF
	# A person is wherever they stand now: a keeper's tent on the square
	# before the inn is rebuilt, a wanderer on their round.
	if String(bearing["who"]) != "":
		for villager in get_tree().get_nodes_in_group("npcs"):
			if not villager.away and String(villager.data.get("id", "")) == bearing["who"]:
				return villager.global_position
	var here: String = world.map.id
	if bearing["map_id"] == here:
		return MapView.center(bearing["cell"]) if bearing["cell"] != Bearing.NOWHERE else Vector2.INF
	var door := Bearing.way_out(here, String(bearing["map_id"]))
	return MapView.center(door) if door != Bearing.NOWHERE else Vector2.INF


## The nameplate of the sign the hero stands near (two tiles or so): the
## place's name and who keeps it, over the board, in the UI's window style.
func update_nameplate() -> void:
	const TILE := MapView.TILE
	var near := {}
	var best := 2.6 * TILE
	for entry: Dictionary in world.view.door_signs:
		var at := Vector2(entry["door"] * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
		var distance: float = world.player.position.distance_to(at)
		if distance < best:
			best = distance
			near = entry
	if near.is_empty():
		if nameplate.visible and nameplate_door != Vector2i(-1, -1):
			nameplate_door = Vector2i(-1, -1)
			var fade := nameplate.create_tween()
			fade.tween_property(nameplate, "modulate:a", 0.0, 0.15)
			fade.tween_callback(nameplate.hide)
		return
	if near["door"] != nameplate_door:
		nameplate_door = near["door"]
		(nameplate.get_child(0).get_child(0) as Label).text = near["name"]
		(nameplate.get_child(0).get_child(1) as Label).text = near["about"]
		nameplate.get_child(0).get_child(1).visible = near["about"] != ""
		nameplate.reset_size()
		nameplate.show()
		nameplate.modulate.a = 1.0 if GameState.settings.reduce_motion else 0.0
		if not GameState.settings.reduce_motion:
			nameplate.create_tween().tween_property(nameplate, "modulate:a", 1.0, 0.15)
	# Over the board, wherever the camera has the door on screen.
	var top := Vector2(nameplate_door.x * TILE + TILE / 2.0, nameplate_door.y * TILE - ShopSign.BOARD.y - 10)
	var screen := get_viewport().get_canvas_transform() * top
	nameplate.position = (screen - Vector2(nameplate.size.x / 2.0, nameplate.size.y)).round()


## The arrow itself: a small head pointing right (the HUD turns it), rimmed
## in the night so it reads on any ground; gold for the main story, cream
## for anything else followed (PIX-253 step 2).
class Arrow extends Control:
	## Long and narrow, so it reads as pointing whichever way it's turned.
	const SHAPE := [Vector2(12, 0), Vector2(-7, -6), Vector2(-7, 6)]
	const RIM := [Vector2(16, 0), Vector2(-9, -8), Vector2(-9, 8)]

	## Whether it leads the main story.
	var main := true:
		set(value):
			if value != main:
				main = value
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Its colour: the main story's gold, or cream.
	func ink() -> Color:
		return UiStyle.GOLD if main else UiStyle.CREAM

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array(RIM), UiStyle.NIGHT)
		draw_colored_polygon(PackedVector2Array(SHAPE), ink())

	## Where a ray from `from` (inside `area`) along `heading` leaves it.
	static func edge_point(area: Rect2, from: Vector2, heading: Vector2) -> Vector2:
		var half := area.size / 2.0
		var reach := INF
		if absf(heading.x) > 0.0001:
			reach = minf(reach, half.x / absf(heading.x))
		if absf(heading.y) > 0.0001:
			reach = minf(reach, half.y / absf(heading.y))
		return from + heading * reach


## The clock's dial (PIX-246): a gold sun with four short rays by day, a pale
## crescent moon by night, rimmed in the night like the arrow.
class Dial extends Control:
	var night := false

	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size / 2.0
		if night:
			draw_circle(middle, 6.0, UiStyle.NIGHT)
			draw_circle(middle, 5.0, Color("e8e4d0"))
			draw_circle(middle + Vector2(2.5, -1.5), 4.0, UiStyle.NIGHT)
			return
		for ray: Vector2 in [Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)]:
			draw_line(middle, middle + ray, UiStyle.NIGHT, 3.0)
			draw_line(middle, middle + ray * 0.85, Color("f2c14e"), 1.0)
		draw_circle(middle, 4.5, UiStyle.NIGHT)
		draw_circle(middle, 3.5, Color("f2c14e"))
