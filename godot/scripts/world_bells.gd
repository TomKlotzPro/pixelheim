class_name Night
extends Node
## The Night of Bells on the town map (PIX-253 step 9): Bells holds its
## rules, this plays them. Home with the run home next, the bell rings and
## the night begins; everyone the story brought home is out at their place.
## 1. The five lanterns on the square, lit with E one by one; with the
##    fifth Aske puts out every other lamp in Pixelheim.
## 2. Embers come over the roofs (imps, as on the Night of Ash: Bram's
##    errand counts them) and three homes burn: the embers driven off and
##    the roofs doused with the well's water (or the fountain's).
## 3. Fafnyr lands on the square. He is held there until the sky turns:
##    the dawn clock runs while the hero holds the square, the sky greying
##    as it does; Teo's bell stuns him a breath each ring, Ulla's old guard
##    shoot from the walls, Bram rolls cheese down Upper Street, Loras plays
##    the marching song, Iva heals the hero whole at her tent, and Sela and
##    Wenna keep the inn as a shelter. At dawn, or worn down to the share he
##    yields at, he stands down (enemy.stand_down, Foes.stood_down).
## Then the dawn and the collar play over the square (Cutscene, story.json)
## and the day begins with Fafnyr's scale in the fountain. A hero who falls
## tonight wakes in the inn's doorway and the beat begins again. Every way
## out of town is shut till dawn. Nothing of the night is saved but its
## end: a save made tonight plays it again from the bell.

## How far a lit lantern's light reaches, in pixels.
const LANTERN_REACH := 64.0

var world: Node
## Tonight, while it runs: the lanterns lit and the roofs doused (their
## indices), the embers still standing, the bucket in hand.
var lit: Array[int] = []
var doused: Array[int] = []
var embers_left := 0
var bucket := false
## Fafnyr on the square, the dawn clock, and where the sky stood as the
## hold began.
var dragon: Node = null
var hold_left := 0.0
var night_steps := 0.0
## Each of the townsfolk's jobs: seconds until it next acts, by kind.
var _clocks := {}
## The jobs that have acted this night, by kind (the harness reports them).
var acted: Array[String] = []
## When Iva last healed at her tent.
var _healed_at := -100.0
## The roofs burning on this visit: roof index -> its index in the view's fires.
var _fires := {}
var _lanterns: Array[Node2D] = []
var _plate: PanelContainer
var _away_at := -100.0
var _dawning := false
var _said := {}
## Seconds until the next look for a hero in town with the run home next.
var _watch_left := 0.0
## What the scale in the fountain built, said once the day begins.
var _built := ""


## Whether the night runs.
func running() -> bool:
	return GameState.progression.bells != Bells.NONE


func beat() -> int:
	return GameState.progression.bells


## On arriving somewhere (world.enter_map): home with the run home next,
## the night begins; back on the town map while it runs (waking after a
## fall), its beat is set out again.
func arrive(next: MapData) -> void:
	if next.id != "town":
		return
	if Bells.due(GameState.progression, GameState.settlement):
		begin.call_deferred()
	elif running() and beat() != Bells.DAWN:
		_stage.call_deferred()


## The bell: the night begins, everyone at their places.
func begin() -> void:
	if world.map == null or world.map.id != "town" or running():
		return
	lit.clear()
	doused.clear()
	embers_left = 0
	bucket = false
	acted.clear()
	_said.clear()
	GameState.questing.bells_begin()
	world.folk.respawn()
	world.folk.keep_hours(true)
	_stage()
	var settlers := GameState.settlement.settlers
	if not Bells.job("bell", settlers, GameState.town_tier()).is_empty():
		Sound.play("bell", false)
	world.camera_rig.shake(3.0, 0.6)
	world.messages.flash(Bells.start_line(settlers, GameState.town_tier()))


## The night as it stands, set out on the town map: the lanterns, the lamps
## out once they're lit, the embers and burning roofs, Fafnyr on the square.
func _stage() -> void:
	if not running() or world.map == null or world.map.id != "town":
		return
	_draw_lanterns()
	_pitch_tent()
	if beat() >= Bells.EMBERS:
		world.view.lamps_out()
	_fires.clear()
	if beat() == Bells.EMBERS:
		var roofs := Bells.roofs()
		for i in roofs.size():
			if i not in doused:
				_fires[i] = world.view.burn(roofs[i])
		_spawn_embers()
	elif beat() == Bells.HOLD:
		_land()


# ---- 1. The lanterns ----------------------------------------------------------

## The five lanterns on the square, each lit or not as tonight stands.
func _draw_lanterns() -> void:
	for lantern in _lanterns:
		if is_instance_valid(lantern):
			lantern.queue_free()
	_lanterns.clear()
	var spots := Bells.lanterns()
	for i in spots.size():
		var lantern := lantern_at(spots[i])
		world.actors.add_child(lantern)
		_lanterns.append(lantern)
		if i in lit:
			light(lantern, i)


## A lantern on the square: a post and its cap, unlit.
static func lantern_at(cell: Vector2i) -> Node2D:
	var lantern := Node2D.new()
	lantern.position = MapView.center(cell)
	lantern.add_to_group("decor")
	var post := ColorRect.new()
	post.color = Color("4a3426")
	post.size = Vector2(2, 9)
	post.position = Vector2(-1, -7)
	lantern.add_child(post)
	var cap := ColorRect.new()
	cap.color = Color("2a1d16")
	cap.size = Vector2(4, 2)
	cap.position = Vector2(-2, -9)
	lantern.add_child(cap)
	return lantern


## A lantern lit: Shade's flame on it (or a warm square) and its light.
static func light(lantern: Node2D, index: int) -> void:
	var frames := ItemIcons.effect("flame", 10.0)
	if frames != null:
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.scale = Vector2.ONE * 0.5
		flame.position = Vector2(0, -12)
		flame.frame = index
		flame.material = Lights.unshaded()
		flame.play()
		lantern.add_child(flame)
	else:
		var glow := ColorRect.new()
		glow.color = Color(1.0, 0.75, 0.35)
		glow.size = Vector2(4, 4)
		glow.position = Vector2(-2, -13)
		glow.material = Lights.unshaded()
		lantern.add_child(glow)
	lantern.add_child(Lights.make(Vector2(0, -10), LANTERN_REACH, Lights.LAMP, Lights.LAMP_ENERGY, true))


## The lantern faced, if it's one: lit now, or already. True when it was one.
func _lantern(faced: Vector2i) -> bool:
	var index := Bells.lanterns().find(faced)
	if index < 0:
		return false
	if index in lit:
		world.messages.flash(String(Bells.data()["lanterns"]["again"]))
		return true
	lit.append(index)
	if index < _lanterns.size() and is_instance_valid(_lanterns[index]):
		light(_lanterns[index], index)
	Sound.play_ui("confirm")
	if lit.size() < Bells.lanterns().size():
		world.messages.flash("%s (%d/%d)" % [Bells.data()["lanterns"]["lit"], lit.size(), Bells.lanterns().size()])
		return true
	# The fifth: every other lamp goes out, and the embers come.
	world.view.lamps_out()
	world.messages.flash(Bells.dark_line(GameState.settlement.settlers, GameState.town_tier()))
	GameState.questing.bells_on()
	_embers_come()
	return true


## Light every lantern still dark, one by one, as E would (the harness).
func light_all() -> void:
	for cell in Bells.lanterns():
		if beat() == Bells.LANTERNS:
			_lantern(cell)


# ---- 2. The embers and the roofs ----------------------------------------------

func _embers_come() -> void:
	embers_left = Bells.ember_cells().size()
	var roofs := Bells.roofs()
	for i in roofs.size():
		_fires[i] = world.view.burn(roofs[i])
	_spawn_embers()
	world.camera_rig.shake(4.0, 0.5)
	world.messages.log_lines([String(Bells.embers()["come"])])


## The embers still standing, at their places on the square.
func _spawn_embers() -> void:
	var wave := Bells.embers()
	var kind := Bestiary.monster(wave["monsterId"])
	var cells := Bells.ember_cells()
	for i in mini(embers_left, cells.size()):
		var foe: Node = world.foes.spawn_enemy(wave["monsterId"], cells[i], "", "", false, false, cells[i], int(wave["level"]) - int(kind["level"]))
		foe.fighter["name"] = wave["name"]
		foe.set_meta("bells_wave", true)
		world.fx.appear(foe)


## An ember down (Foes.on_enemy_died).
func ember_fell(_enemy: Node) -> void:
	if beat() != Bells.EMBERS:
		return
	embers_left = maxi(0, embers_left - 1)
	if embers_left == 0:
		world.messages.log_lines([String(Bells.embers()["cleared"])])
		_embers_done()


## The well's water (or the fountain's), or a burning roof faced with it.
## True when the cell was either.
func _water(faced: Vector2i) -> bool:
	var fires: Dictionary = Bells.data()["fires"]
	if world.map.tile_at(faced) == "well":
		bucket = true
		Sound.play("drop")
		world.messages.flash(String(fires["well"]))
		return true
	var roof := Bells.roof_at(faced)
	if roof < 0 or roof in doused:
		return false
	if not bucket:
		world.messages.flash(String(fires["empty"]))
		return true
	bucket = false
	_douse(roof)
	return true


func _douse(roof: int) -> void:
	doused.append(roof)
	if _fires.has(roof):
		world.view.douse(int(_fires[roof]))
	Sound.play("heal")
	var fires: Dictionary = Bells.data()["fires"]
	var all := Bells.roofs().size()
	world.messages.flash(String(fires["done"]) if doused.size() >= all else "%s (%d/%d)" % [fires["doused"], doused.size(), all])
	_embers_done()


## Every roof out as the hero would put it out (the harness): a bucket
## filled at the well, then carried to the roof's door.
func douse_all() -> void:
	var wells: Array = world.map.grid.keys().filter(func(cell: Vector2i) -> bool: return world.map.grid[cell] == "well")
	var roofs := Bells.roofs()
	for roof in roofs.size():
		if beat() != Bells.EMBERS or roof in doused or wells.is_empty():
			continue
		_water(wells[0])
		_water(Vector2i(roofs[roof].get_center().x, roofs[roof].end.y - 1))


## Both done - the embers gone, the roofs out - and the bell stops: wings.
func _embers_done() -> void:
	if beat() != Bells.EMBERS or embers_left > 0 or doused.size() < Bells.roofs().size():
		return
	GameState.questing.bells_on()
	world.messages.flash(String(Bells.data()["quiet"]))
	_land()


# ---- 3. Fafnyr on the square --------------------------------------------------

## He comes down on the square where the lanterns are: a roar, the ground
## shaking, his name over the world, and the dawn clock from the start.
func _land() -> void:
	if is_instance_valid(dragon) and not dragon.is_queued_for_deletion():
		dragon.queue_free()
	var spec := Bells.fafnyr_spec()
	var enemy: CharacterBody2D = preload("res://scripts/enemy.gd").new()
	enemy.world = world
	enemy.fighter = Bells.fafnyr()
	enemy.position = MapView.center(Bells.landing())
	enemy.home = enemy.position
	enemy.set_meta("bells", true)
	enemy.add_to_group("mobs")
	world.actors.add_child(enemy)
	dragon = enemy
	world.fx.appear(enemy)
	Sound.play("roar")
	world.camera_rig.shake(7.0, 0.9)
	world.hud.title_card(String(spec["card"]), String(spec["cardLine"]))
	enemy.notice()
	hold_left = Bells.dawn_seconds()
	night_steps = GameState.world.steps
	_clocks.clear()
	for entry in _jobs():
		# Each job's first turn comes a little after he lands, not all at once.
		_clocks[entry["job"]] = float(entry.get("every", 0.0)) * 0.5
	# Loras plays the marching song all through the fight.
	if not Bells.job("song", GameState.settlement.settlers, GameState.town_tier()).is_empty():
		GameState.settlement.bard_song = true
		_note("song", String(Bells.job("song", GameState.settlement.settlers, GameState.town_tier())["log"]))


## A hero in town with the run home next begins the night where they stand,
## not only coming in by the gate (PIX-297: a save loaded in town on that
## step stood there with nothing happening): looked at once a second while
## the world runs.
func _watch(delta: float) -> void:
	_watch_left -= delta
	if _watch_left > 0.0:
		return
	_watch_left = 1.0
	if Bells.due(GameState.progression, GameState.settlement):
		begin()


func _jobs() -> Array[Dictionary]:
	return Bells.jobs(GameState.settlement.settlers, GameState.town_tier())


func _physics_process(delta: float) -> void:
	if world.map == null or world.map.id != "town" or world.player == null or world.player.dead:
		return
	if not running():
		_watch(delta)
		return
	_tend_tent()
	if beat() != Bells.HOLD or not is_instance_valid(dragon) or dragon.dying:
		return
	if Bells.holding(world.player_cell):
		hold_left -= delta
	elif GameClock.seconds() - _away_at > 6.0:
		_away_at = GameClock.seconds()
		world.messages.flash(String(Bells.fafnyr_spec()["away"]))
	# The sky turns as the square is held.
	GameState.world.steps = Bells.sky_at(night_steps, 1.0 - hold_left / Bells.dawn_seconds())
	GameState.settlement.bard_song = GameState.settlement.bard_song or acted.has("song")
	for entry in _jobs():
		var kind := String(entry["job"])
		if not entry.has("every") or kind == "heal":
			continue
		_clocks[kind] = float(_clocks.get(kind, 0.0)) - delta
		if float(_clocks[kind]) > 0.0:
			continue
		_clocks[kind] = float(entry["every"])
		match kind:
			"bell":
				_ring(entry)
			"arrows":
				_volley(entry)
			"cheese":
				_roll(entry)
	if hold_left <= 0.0:
		dragon.stand_down()


func _process(_delta: float) -> void:
	_show_clock(running() and beat() == Bells.HOLD and is_instance_valid(dragon) and not dragon.dying)


## Iva heals the hero whole at her tent, whenever they reach it (at most
## every so often): any beat of the night.
func _tend_tent() -> void:
	var tent := Bells.job("heal", GameState.settlement.settlers, GameState.town_tier())
	if tent.is_empty() or GameState.hero.hp >= int(GameState.hero.stats["maxHp"]):
		return
	if Vector2(world.player_cell - Bells.cell(tent["at"])).length() > 1.5:
		return
	if not Bells.heal_ready(tent, _healed_at, GameClock.seconds()):
		return
	_healed_at = GameClock.seconds()
	GameState.make_whole()
	Sound.play("heal")
	world.messages.flash(String(tent["said"]))
	_note("heal")


## Teo's bell: a breath's stun on the dragon every ring.
func _ring(entry: Dictionary) -> void:
	dragon.ailments.stun_for(int(entry["stun"]))
	Sound.play("bell", false)
	world.camera_rig.shake(2.0, 0.3)
	world.fx.float_text(Text.t("Dong!"), MapView.center(Bells.cell(entry["at"])) + Vector2(0, -18), UiStyle.GOLD, true)
	if not _said.has("bell"):
		world.messages.flash(String(entry["first"]))
	_note("bell", String(entry["log"]))


## Ulla's old guard: arrows down off the walls at him.
func _volley(entry: Dictionary) -> void:
	Sound.play_ui("loose")
	for i in int(entry["count"]):
		var arrow := Shot.new()
		arrow.target = dragon
		arrow.damage = int(entry["damage"])
		arrow.position = dragon.global_position + Vector2(-24 + 24 * i, -190)
		world.actors.add_child(arrow)
	_note("arrows", String(entry["log"]))


## Bram's cheese: a wheel down Upper Street, at him.
func _roll(entry: Dictionary) -> void:
	var wheel := Wheel.new()
	wheel.target = dragon
	wheel.damage = int(entry["damage"])
	wheel.position = MapView.center(Bells.cell(entry["at"]) + Vector2i.DOWN)
	world.actors.add_child(wheel)
	if not _said.has("cheese"):
		world.messages.flash(String(entry["first"]))
	_note("cheese", String(entry["log"]))


## A job has acted: the log says so the first time.
func _note(kind: String, line := "") -> void:
	if not _said.has(kind) and line != "":
		world.messages.log_lines([line])
	_said[kind] = true
	if kind not in acted:
		acted.append(kind)


## The dawn clock, under the day's clock: "Dawn 1:23".
func _show_clock(on: bool) -> void:
	if not on or world.hud.root == null:
		if _plate != null:
			_plate.queue_free()
			_plate = null
		return
	if _plate == null:
		_plate = PanelContainer.new()
		_plate.add_theme_stylebox_override("panel", UiStyle.plate(12))
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_child(UiStyle.strong("", 16, UiStyle.GOLD))
		world.hud.root.add_child(_plate)
	var left := ceili(maxf(0.0, hold_left))
	var shown: Label = _plate.get_child(0)
	shown.text = "%s  %d:%02d" % [Bells.fafnyr_spec()["clock"], left / 60, left % 60]
	shown.add_theme_color_override("font_color", UiStyle.GOLD if Bells.holding(world.player_cell) else UiStyle.DUSK)
	_plate.reset_size()
	_plate.position = Vector2(1280 - 24 - _plate.size.x, 56)


## The dawn comes now (the harness): the clock run out.
func daybreak() -> void:
	if beat() == Bells.HOLD:
		hold_left = 0.0


## The night moved on to beat `target` as if played (the harness's `--bells`):
## begun, the lanterns lit, then the embers gone and the roofs out.
func jump_to(target: int) -> void:
	if not running() and Bells.due(GameState.progression, GameState.settlement):
		begin()
	if target >= Bells.EMBERS and beat() == Bells.LANTERNS:
		light_all()
	if target >= Bells.HOLD and beat() == Bells.EMBERS:
		for foe in get_tree().get_nodes_in_group("mobs"):
			if foe.has_meta("bells_wave"):
				foe.queue_free()
		embers_left = 0
		douse_all()


# ---- Dawn ---------------------------------------------------------------------

## Fafnyr stands down (Foes.stood_down): the night is won. The hush, the
## night's ends tied (the ledger, the fountain: Questing.bells_dawn), and
## after a breath the dawn over the square, then the collar, then the day.
func dragon_spent(enemy: Node) -> void:
	if _dawning:
		return
	_dawning = true
	var foes: Foes = world.foes
	foes.hunted_by_boss = false
	foes.stood += 1
	Sound.stop_music()
	world.soundscape.hush(Foes.BOSS_HUSH_S)
	_built = GameState.questing.bells_dawn()
	_slump(enemy)
	world.messages.flash(String(Bells.data()["won"]))
	var visit: MapView = world.view
	await get_tree().create_timer(Foes.STAND_DOWN_BEAT * 2.0).timeout
	if not is_instance_valid(enemy) or world.view != visit:
		_dawning = false
		return
	_frame_dawn(enemy)
	# The scenes play over the square itself: nothing of the HUD over it.
	world.hud.root.visible = false
	var dawn := Cutscene.new()
	dawn.scene_id = Bells.dawn_id()
	dawn.on_done = _collar.bind(enemy)
	world.add_child(dawn)


## Spent: he sinks, slow and grey, and the collar drags at him, north, as
## the scenes play over the held world.
func _slump(enemy: Node) -> void:
	var sprite: AnimatedSprite2D = enemy.sprite
	if enemy.level_tag != null:
		enemy.level_tag.visible = false
	sprite.speed_scale = 0.35
	sprite.modulate = Color(0.78, 0.74, 0.76)
	enemy.process_mode = Node.PROCESS_MODE_ALWAYS
	if GameState.settings.reduce_motion:
		return
	var rest: Vector2 = sprite.position
	var tug := sprite.create_tween().set_loops()
	tug.tween_interval(1.2)
	tug.tween_property(sprite, "position", rest + Vector2(0, -3), 0.12).set_ease(Tween.EASE_OUT)
	tug.tween_property(sprite, "position", rest, 0.6).set_ease(Tween.EASE_IN_OUT)


## The square at dawn for the scenes: he on the cell he landed on, the hero
## below him looking up, the camera on them both, the sky grey.
func _frame_dawn(enemy: Node) -> void:
	GameState.world.steps = Bells.sky_at(night_steps, 1.0)
	enemy.position = MapView.center(Bells.landing())
	enemy.reset_physics_interpolation()
	var stand := Bells.landing() + Vector2i(0, 2)
	world.player.position = MapView.center(stand)
	world.player.reset_physics_interpolation()
	world.player_cell = stand
	world.player.face(Vector2.UP)
	# The lanterns above him in the picture, the hero below.
	world.camera_rig.follows = false
	world.camera_rig.camera.global_position = MapView.center(Bells.landing() + Vector2i(0, -2))
	world.camera_rig.camera.reset_smoothing()


## The collar: Morvax down the road, the keepsakes in the lanterns, and the
## dragon off home, free (the scene brings its own Fafnyr).
func _collar(enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
	var scene := Cutscene.new()
	scene.scene_id = Bells.collar_id()
	scene.on_done = _day
	world.add_child(scene)


## The day after: the night done, the town drawn again with its fountain,
## the hero on the square below it.
func _day() -> void:
	var said := GameState.questing.bells_day()
	_dawning = false
	dragon = null
	_show_clock(false)
	world.hud.root.visible = true
	world.camera_rig.follows = true
	world.map = world.load_map("town")
	world.enter_map(world.map, Town.square() + Vector2i(0, 4))
	world.messages.log_lines([said] + ([_built] if _built != "" else []))


## A hero who falls tonight wakes in the inn's doorway, whole, the beat
## set out again (Fafnyr anew, the dawn clock from the start): the night
## is a fight, not a toll.
func hero_fell() -> void:
	GameState.make_whole()
	var shelter := Bells.job("shelter", GameState.settlement.settlers, GameState.town_tier())
	var at := Bells.cell(shelter["at"]) + Vector2i(1, 1) if not shelter.is_empty() else Town.square() + Vector2i(0, 4)
	world.map = world.load_map("town")
	world.enter_map(world.map, at)
	world.player.respawn(MapView.center(at))
	world.last_player_position = world.player.position
	world.messages.flash(String(Bells.fafnyr_spec()["fallen"]))


## What bars the ways out of town tonight, "" when nothing does: everyone
## holds the square till dawn.
func barred() -> String:
	if not running() or world.map == null or world.map.id != "town":
		return ""
	return String(Bells.data()["barred"])


## What E does tonight, before anything else: a lantern lit, the well's
## water, a roof doused. True when it did something.
func interact(faced: Vector2i) -> bool:
	if not running() or world.map.id != "town":
		return false
	match beat():
		Bells.LANTERNS:
			return _lantern(faced)
		Bells.EMBERS:
			return _water(faced)
	return false


## Iva's tent on the square's edge.
func _pitch_tent() -> void:
	var tent := Bells.job("heal", GameState.settlement.settlers, GameState.town_tier())
	if not tent.is_empty() and tent.has("tent"):
		world.view.pitch_tent(Bells.cell(tent["tent"]))


## The line above the dock tonight.
func objective() -> String:
	return Bells.objective(beat(), lit.size(), embers_left, Bells.roofs().size() - doused.size(), hold_left)


## A volley's arrow: down off the walls at the dragon, a dark shaft drawn in
## code, and a chip off him where it lands.
class Shot:
	extends Node2D
	const SPEED := 420.0
	var target: Node
	var damage := 0

	func _ready() -> void:
		z_index = 6
		material = Lights.unshaded()

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or target.dying:
			queue_free()
			return
		var aim: Vector2 = target.global_position + Vector2(0, -10)
		var to := aim - position
		if to.length() < 8.0:
			target.chip(damage, Color(0.85, 0.9, 1.0))
			queue_free()
			return
		rotation = to.angle()
		position += to.normalized() * minf(SPEED * delta, to.length())

	func _draw() -> void:
		draw_line(Vector2(-7, 0), Vector2(0, 0), Color("6b4a2e"), 1.0)
		draw_rect(Rect2(0, -1, 2, 2), Color("c9c4b8"))


## Bram's cheese wheel: rolling, turning, at the dragon wherever he is.
class Wheel:
	extends Node2D
	const SPEED := 150.0
	var target: Node
	var damage := 0
	var _sprite: Sprite2D

	func _ready() -> void:
		z_index = 5
		var icon := ItemIcons.texture("cheese_wheel")
		if icon != null:
			_sprite = Sprite2D.new()
			_sprite.texture = icon
			_sprite.scale = Vector2.ONE * 0.75
			add_child(_sprite)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or target.dying:
			queue_free()
			return
		var to: Vector2 = target.global_position - position
		if to.length() < 10.0:
			target.chip(damage, Color(1.0, 0.86, 0.4))
			Sound.play_ui("slam")
			queue_free()
			return
		var step := minf(SPEED * delta, to.length())
		position += to.normalized() * step
		rotation += step / 6.0 * signf(to.x if absf(to.x) > 0.1 else 1.0)

	func _draw() -> void:
		if _sprite == null:
			draw_circle(Vector2.ZERO, 5.0, Color("e8c45a"))
			draw_circle(Vector2(1, -1), 1.5, Color("b89434"))
