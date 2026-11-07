extends Node
## areas: none
## The bridge tools/play.py plays the web build through (PIX-423): an agent's
## keys in, what the game knows out, one command at a time. world.gd hangs
## it from the root on the web when the page asks (`play` in its
## window.pixelheimArgs), never otherwise.
##
## The page's window.pixelheimPlay hands it a command, a JSON list of steps
## (keys held so many seconds, a tap when `seconds` is null, or no keys: a
## wait), and it answers with the game's state and `frozen`, on which the
## page stops giving the engine frames (play.py's requestAnimationFrame
## shim). Between commands nothing runs at all - the clock, the timers, the
## tweens, the game's own pause menu stay as they were - so an agent's
## thinking costs the game nothing. The page runs stepped (`--fixed-fps
## 60`): a frame is a sixtieth of a second however long it took, and a hold
## counts physics ticks. It runs whether the game is paused or not and never
## touches the tree's pause itself.

const Harness := preload("res://scripts/harness.gd")
## A tap is held this many ticks, and the keys of a step let go this many
## before the next, as harness.gd's _tap: a screen that ignores the press
## that opened it would miss the next.
const TAP_TICKS := 3
const AFTER_TICKS := 5
## Foes this many cells from the hero, either way, are listed.
const NEAR := 12

## window.pixelheimPlay, or a stand-in in the tests: `command` (a JSON
## string, or null), `state` (the answer, JSON) and `frozen`.
var page: Variant
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if _busy or page == null or page.command == null:
		return
	var command := String(page.command)
	page.command = null
	run(command)


## Runs `command`'s steps in turn, then answers with the state and freezes
## the page; a step that can't be played plays nothing, and says why.
func run(command: String) -> void:
	_busy = true
	var steps: Variant = JSON.parse_string(command)
	var problem := _problem(steps)
	if problem == "":
		for step: Dictionary in steps:
			await _step(step)
	var said := state()
	if problem != "":
		said["error"] = problem
	page.state = JSON.stringify(said)
	page.frozen = true
	_busy = false


func _problem(steps: Variant) -> String:
	if not steps is Array:
		return "not a list of steps"
	for step: Variant in steps:
		if not step is Dictionary or not step.get("keys") is Array:
			return "a step is {keys, seconds}"
		for key: Variant in step["keys"]:
			if OS.find_keycode_from_string(str(key)) == KEY_NONE:
				return "no key named " + str(key)
	return ""


## One step: its keys pressed together, held its time, let go.
func _step(step: Dictionary) -> void:
	var keys: Array[InputEventKey] = []
	for name: String in step["keys"]:
		var key := InputEventKey.new()
		key.keycode = OS.find_keycode_from_string(name)
		key.physical_keycode = key.keycode
		# A letter typed into a field (a hero's name) as the keyboard types it.
		if name.length() == 1:
			key.unicode = name.unicode_at(0)
		keys.append(key)
	var seconds: Variant = step.get("seconds")
	for key in keys:
		_land(key, true)
	await _ticks(TAP_TICKS if seconds == null else roundi(float(seconds) * Engine.physics_ticks_per_second))
	for key in keys:
		_land(key, false)
	await _ticks(AFTER_TICKS if not keys.is_empty() else 0)


func _land(key: InputEventKey, pressed: bool) -> void:
	var event := key.duplicate() as InputEventKey
	event.pressed = pressed
	Harness.land(get_viewport(), event)


func _ticks(count: int) -> void:
	for _tick in count:
		await get_tree().physics_frame


## What the game knows now, for play.py's look: the hero, the hour, and on
## a world its place, the screens open and the words on them, the HUD's
## words, the quest it leads to and the foes near.
func state() -> Dictionary:
	var hero := GameState.hero
	var steps := GameState.world.steps
	var hour := DayNight.clock(steps)
	var said := {
		"level": hero.level, "hp": hero.hp, "maxHp": int(hero.stats.get("maxHp", 0)),
		"mana": hero.mp, "maxMana": int(hero.stats.get("maxMp", 0)), "gold": GameState.pack.gold,
		"hour": "%02d:%02d" % [hour.x, hour.y], "night": DayNight.is_night(steps),
		"paused": get_tree().paused, "seconds": snappedf(GameClock.seconds(), 0.01),
	}
	var world := get_tree().current_scene
	if world == null or world.get("hud") == null or world.map == null:
		return said
	var hud: Hud = world.hud
	var cell: Vector2i = world.player_cell
	said["map"] = world.map.id
	said["cell"] = [cell.x, cell.y]
	var open: PackedStringArray = []
	var text: PackedStringArray = []
	# The screens open, in the order they opened; the words of the one on
	# top, as the one taking the keys (a cutscene covers the title under it).
	for screen: Screen in Screen._shown:
		if is_instance_valid(screen) and screen.is_inside_tree():
			open.append(screen.get_script().resource_path.get_file().get_basename())
			if screen.on_top():
				words(screen, text)
	said["open"] = open
	said["text"] = text
	var on_hud: PackedStringArray = []
	words(hud.root, on_hud, [hud.dock, hud.clock_plate, hud.objective_box, hud.quill])
	said["hud"] = on_hud
	said["quest"] = hud.objective_label.text
	said["tracked"] = GameState.progression.tracked
	var foes: Array = []
	for mob in get_tree().get_nodes_in_group("mobs"):
		var at := Vector2i((mob.global_position / MapView.TILE).floor())
		if mob.dying or maxi(absi(at.x - cell.x), absi(at.y - cell.y)) > NEAR:
			continue
		var fighter: Dictionary = mob.fighter
		foes.append({"name": fighter.get("name", ""), "id": fighter.get("named", fighter["id"]), "level": Bestiary.level_of(fighter),
			"hp": int(fighter["hp"]), "maxHp": int(fighter["maxHp"]), "cell": [at.x, at.y], "mode": mob.mode})
	said["foes"] = foes
	return said


## The words a player reads under `node`, in order: its labels, buttons and
## fields as far as they're shown (not hidden, faded out or still typing),
## in the language they're shown in (a label's text is its English, which
## it translates as it draws), leaving out `skip`'s and another screen's
## opened inside it.
static func words(node: Node, out: PackedStringArray, skip: Array = []) -> void:
	if node == null or node in skip:
		return
	if (node is CanvasItem and (not node.visible or node.modulate.a < 0.05)) or (node is CanvasLayer and not node.visible):
		return
	var text := ""
	if node is Label or node is Button:
		text = node.atr(node.text)
	elif node is RichTextLabel:
		text = node.get_parsed_text()
	elif node is LineEdit:
		text = node.text
	if (node is Label or node is RichTextLabel) and node.visible_characters >= 0:
		text = text.left(node.visible_characters)
	text = text.strip_edges()
	if text != "" and (out.is_empty() or out[-1] != text):
		out.append(text)
	for child in node.get_children():
		if not child is Screen:
			words(child, out, skip)
