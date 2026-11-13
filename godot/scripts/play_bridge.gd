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
## touches the tree's pause itself. In a harness run it answers only once
## the run's steps are done (Harness.stepping): the first look is the start
## the presets set, not a step mid-way.

const Harness := preload("res://scripts/harness.gd")
## A tap is held this many ticks, and the keys of a step let go this many
## before the next, as harness.gd's _tap: a screen that ignores the press
## that opened it would miss the next.
const TAP_TICKS := 3
const AFTER_TICKS := 5
## Foes, folk and doors this many cells from the hero, either way, are listed.
const NEAR := 12

## window.pixelheimPlay, or a stand-in in the tests: `command` (a JSON
## string, or null), `state` (the answer, JSON) and `frozen`.
var page: Variant
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if _busy or page == null or page.command == null or Harness.stepping:
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
				# A whole word (PIX-468: `Aria` played nothing, and the name stayed empty).
				return "no key named " + str(key) + " (a word is typed a letter a key, as A,r,i,a)"
	return ""


## One step: its keys pressed together, held its time, let go.
func _step(step: Dictionary) -> void:
	var keys: Array[InputEventKey] = []
	# Shift held with a letter types its capital, as the keyboard does
	# (PIX-468: `shift+a` typed "a"). The event itself stays unshifted, so a
	# move held with Shift is still its action.
	var shifted: bool = step["keys"].any(func(held: String) -> bool: return OS.find_keycode_from_string(held) == KEY_SHIFT)
	for name: String in step["keys"]:
		var key := InputEventKey.new()
		key.keycode = OS.find_keycode_from_string(name)
		key.physical_keycode = key.keycode
		# A letter typed into a field (a hero's name) as the keyboard types it.
		if name.length() == 1:
			key.unicode = (name.to_upper() if shifted else name).unicode_at(0)
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
	# The keyboard's own (PIX-435): Godot's ui_text_* actions take no other
	# device, so the harness's left a name field's Backspace doing nothing.
	Harness.land(get_viewport(), event, InputEvent.DEVICE_ID_KEYBOARD)


func _ticks(count: int) -> void:
	for _tick in count:
		await get_tree().physics_frame


## What the game knows now, for play.py's look: the hero, the hour, and on
## a world its place, the screens open, the words on them and the chosen
## one's, the HUD's words, the quest it leads to, and the foes, folk and
## doors near.
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
	var focus: Array = []
	# The screens open, in the order they opened; the words of the one on
	# top, as the one taking the keys (a cutscene covers the title under it).
	for screen: Screen in Screen._shown:
		if is_instance_valid(screen) and screen.is_inside_tree():
			open.append(screen.get_script().resource_path.get_file().get_basename())
			if screen.on_top():
				words(screen, text)
				chosen(screen, focus)
	said["open"] = open
	said["text"] = text
	said["focus"] = focus
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
	# Who to talk to (PIX-435: finding a villager took 40 calls) and the
	# ways in and out, as near as the foes.
	var folk: Array = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		var at := Vector2i((npc.global_position / MapView.TILE).floor())
		if not npc.away and npc.visible and maxi(absi(at.x - cell.x), absi(at.y - cell.y)) <= NEAR:
			folk.append({"name": tr(String(npc.data.get("name", ""))), "cell": [at.x, at.y]})
	said["npcs"] = folk
	var doors: Array = []
	for door: Vector2i in world.map.portals:
		if maxi(absi(door.x - cell.x), absi(door.y - cell.y)) <= NEAR:
			doors.append({"cell": [door.x, door.y], "to": world.map.portals[door].get("mapId", "")})
	said["doors"] = doors
	return said


## The words a player reads under `node`, in order: its labels, buttons and
## fields as far as they're shown (not hidden, faded out or still typing),
## in the language they're shown in (a label's text is its English, which
## it translates as it draws), leaving out `skip`'s and another screen's
## opened inside it.
static func words(node: Node, out: PackedStringArray, skip: Array = []) -> void:
	if node == null or node in skip or not _shown(node):
		return
	var text := ""
	if node is Label or node is Button:
		text = node.atr(node.text)
	elif node is RichTextLabel:
		text = node.get_parsed_text()
	elif node is LineEdit:
		text = node.text
	# Still typing out (a cutscene's caption): said so, or it reads as cut (PIX-435).
	if (node is Label or node is RichTextLabel) and node.visible_characters >= 0 and node.visible_characters < text.length():
		text = text.left(node.visible_characters).strip_edges()
		text += " [still typing]" if text != "" else ""
	text = text.strip_edges()
	if text != "" and (out.is_empty() or out[-1] != text):
		out.append(text)
	for child in node.get_children():
		if not child is Screen:
			words(child, out, skip)


## The words of each thing under `node` drawn as chosen, in order, one list
## apiece, into `out` (PIX-435: a menu tester counted key presses blind): a
## plank `UiStyle.focus` lit, or a row framed in `UiStyle.box`'s gold rim.
## All of them, as the pack's and the counter's lit tab comes before their
## chosen row; one with no words is passed over.
static func chosen(node: Node, out: Array) -> void:
	if not _shown(node):
		return
	if node.get_meta("chosen", false) or (node is Control and node.has_theme_stylebox_override("panel")
			and node.get_theme_stylebox("panel").get_meta("chosen", false)):
		var said: PackedStringArray = []
		words(node, said)
		if not said.is_empty():
			out.append(said)
			return
	for child in node.get_children():
		if not child is Screen:
			chosen(child, out)


## Shown: not hidden or faded out.
static func _shown(node: Node) -> bool:
	return not ((node is CanvasItem and (not node.visible or node.modulate.a < 0.05)) or (node is CanvasLayer and not node.visible))
