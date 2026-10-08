extends Node
## A boss that fights back (PIX-150): between bites, Fafnyr and Morvax cast
## their own attacks, each told first by a red mark on the ground so a hero
## who reads it can step out - a breath down a line, embers raining in
## circles, a death ring around the caster, the dead summoned to their side.
## Three phases (at two thirds and one third of their health) quicken them
## and add to the list; each new phase is roared. combat.json's
## "bossPatterns" and "bossAttacks" hold the numbers; the enemy it rides on
## (its parent) does the moving and the biting.

const TILE := 16.0
const TELL_COLOR := Color(1.0, 0.18, 0.08, 0.32)

var enemy: CharacterBody2D
var world: Node2D
var pattern: Dictionary
var phase := 0
var cooldown := 2.0
var turn := 0
## The marks on the ground now, freed when they strike.
var marks: Array[Node2D] = []


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	pattern = Bestiary._data()["bossPatterns"][enemy.fighter["id"]]


func _physics_process(delta: float) -> void:
	if enemy.dying or enemy.mode not in ["chase", "cast"]:
		return
	_check_phase()
	if enemy.mode == "cast":
		return
	cooldown -= delta
	if cooldown > 0:
		return
	var moves: Array = pattern["phases"][phase]
	_cast(moves[turn % moves.size()])
	turn += 1
	cooldown = float(pattern["every"][phase])


## Two thirds and one third of its health: a roar, a shake, a quicker fight.
func _check_phase() -> void:
	var share := float(enemy.fighter["hp"]) / float(enemy.fighter["maxHp"])
	var now := 2 if share <= 1.0 / 3.0 else (1 if share <= 2.0 / 3.0 else 0)
	if now <= phase:
		return
	phase = now
	cooldown = minf(cooldown, 1.0)
	world.log_line(pattern["roars"][phase - 1])
	Sound.play("bump")
	if world.has_method("shake"):
		world.shake(6.0, 0.5)


func _cast(move: String) -> void:
	var attack: Dictionary = Bestiary._data()["bossAttacks"][move]
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	var hero: Vector2 = world.player.global_position
	var at: Vector2 = enemy.global_position
	match String(attack["shape"]):
		"line":
			var toward := (hero - at).normalized()
			if toward == Vector2.ZERO:
				toward = Vector2.DOWN
			var along := toward * float(attack["length"]) * TILE
			var across := toward.orthogonal() * float(attack["width"]) * TILE / 2.0
			_tell(PackedVector2Array([at + across, at + along + across, at + along - across, at - across]), attack)
		"circle":
			_tell(_circle(at, float(attack["radius"]) * TILE), attack)
		"circles":
			for i in int(attack["count"]):
				var spot := hero if i == 0 else hero + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(attack["spread"]) * TILE
				_tell(_circle(spot, float(attack["radius"]) * TILE), attack)
		"summon":
			_summon(attack)


## A mark on the ground that pulses for the tell, then strikes whoever
## stands in it.
func _tell(shape: PackedVector2Array, attack: Dictionary) -> void:
	var mark := Polygon2D.new()
	mark.polygon = shape
	mark.color = TELL_COLOR
	# A bright edge so the mark reads on grass, stone and water alike.
	var edge := Line2D.new()
	edge.points = shape
	edge.closed = true
	edge.width = 1.5
	edge.default_color = Color(1.0, 0.62, 0.2, 0.95)
	mark.add_child(edge)
	world.add_child(mark)
	# Over the ground, under everyone standing on it.
	world.move_child(mark, 3)
	marks.append(mark)
	var tell := float(attack["tell"])
	var pulse := mark.create_tween()
	pulse.tween_property(mark, "color:a", 0.6, tell * 0.5)
	pulse.tween_property(mark, "color:a", 0.35, tell * 0.5)
	pulse.tween_callback(_strike.bind(mark, attack))


func _strike(mark: Polygon2D, attack: Dictionary) -> void:
	marks.erase(mark)
	if is_instance_valid(enemy) and not enemy.dying:
		var player: CharacterBody2D = world.player
		if not player.dead and Geometry2D.is_point_in_polygon(player.global_position, mark.polygon):
			var damage := roundi(Bestiary.monster_attack_damage(enemy.fighter, GameState.hero, GameState.pack, GameState.roll) * float(attack["power"]))
			player.take_hit(damage, mark.polygon[0], enemy.fighter.get("inflicts") if attack.get("inflicts", false) else null)
		if marks.is_empty():
			enemy.mode = "chase"
	var flash := mark.create_tween()
	flash.tween_property(mark, "color", Color(1.0, 0.75, 0.3, 0.7), 0.06)
	flash.tween_property(mark, "color:a", 0.0, 0.25)
	flash.tween_callback(mark.queue_free)


## The dead rise at the caster's side (never more than the attack's cap).
func _summon(attack: Dictionary) -> void:
	var alive := world.get_tree().get_nodes_in_group("summoned").filter(func(node: Node) -> bool: return not node.dying).size()
	var cell := Vector2i((enemy.global_position / TILE).floor())
	for i in mini(int(attack["count"]), int(attack["max"]) - alive):
		var offsets: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, -2)]
		var spot: Vector2i = cell + offsets[i % offsets.size()]
		if not world.map.is_walkable(spot):
			spot = cell
		var add: Node = world.spawn_enemy(pattern["summon"], spot, "", "", false, false, cell)
		add.add_to_group("summoned")
		world.appear(add)
		add.notice()
	enemy.mode = "chase"


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		points.append(center + Vector2.RIGHT.rotated(TAU * i / 20.0) * radius)
	return points


func _exit_tree() -> void:
	for mark in marks:
		if is_instance_valid(mark):
			mark.queue_free()
