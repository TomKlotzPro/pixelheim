class_name Hud
extends Node
## The HUD over the world (Solid Ground, PIX-260: moved out of world.gd as
## it was): its layer and widgets - the sky's tint, the hero's dock, the
## boss bar, the nameplate over a signed door, the main quest's next step -
## laid out on the screen as it is; and the first-time hints. The message
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
## The boss slayer's edge while it lasts (PIX-232): a small plate at the top
## left, its time running down.
var edge_plate: PanelContainer


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
## on the real clock, so the boss's slow motion doesn't hold it.
func title_card(title: String, line: String) -> void:
	if root == null:
		return
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
	var step := MainQuest.next_step(GameState.progression, GameState.settlement)
	var text: String = step.get("text", "")
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
