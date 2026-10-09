class_name BossBrain
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
## The shares of its health where each new phase begins (the boss bar's notches).
const PHASES: Array[float] = [2.0 / 3.0, 1.0 / 3.0]

var enemy: CharacterBody2D
var world: Node2D
var pattern: Dictionary
var phase := 0
var cooldown := 2.0
var turn := 0
## The marks on the ground now, freed when they strike.
var marks: Array[Node2D] = []
## Marks of this cast still to strike; at none the boss moves again.
var pending := 0


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	pattern = Bestiary._data()["bossPatterns"][enemy.fighter["id"]]


func _physics_process(delta: float) -> void:
	# Stunned, it casts nothing (PIX-186); marks already told still strike.
	if enemy.dying or enemy.mode not in ["chase", "cast"] or enemy.ailments.is_stunned():
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
	var now := phase_at(float(enemy.fighter["hp"]) / float(enemy.fighter["maxHp"]))
	if now <= phase:
		return
	phase = now
	cooldown = minf(cooldown, 1.0)
	world.messages.log_line(pattern["roars"][phase - 1])
	# A new phase is roared (PIX-210), not bumped.
	Sound.play("roar")
	world.camera_rig.shake(6.0, 0.5)


## The phase a boss is in at `share` of its health: 0, 1 or 2.
static func phase_at(share: float) -> int:
	var reached := 0
	for at: float in PHASES:
		if share <= at:
			reached += 1
	return reached


func _cast(move: String) -> void:
	var attack: Dictionary = Bestiary._data()["bossAttacks"][move]
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	var hero: Vector2 = world.player.global_position
	var at: Vector2 = enemy.global_position
	match String(attack["shape"]):
		"line":
			_tell(Telegraph.band(at, hero, float(attack["length"]) * TILE, float(attack["width"]) * TILE), attack)
		"circle":
			_tell(Telegraph.circle(at, float(attack["radius"]) * TILE), attack)
		"circles":
			for i in int(attack["count"]):
				var spot := hero if i == 0 else hero + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(attack["spread"]) * TILE
				_tell(Telegraph.circle(spot, float(attack["radius"]) * TILE), attack)
		"summon":
			_summon(attack)


## A mark on the ground (Telegraph) that strikes whoever still stands in it.
func _tell(shape: PackedVector2Array, attack: Dictionary) -> void:
	var shown := Telegraph.mark(world, shape, float(attack["tell"]), _strike.bind(attack))
	pending += 1
	marks.append(shown)
	shown.tree_exiting.connect(func() -> void: marks.erase(shown))


func _strike(shape: PackedVector2Array, attack: Dictionary) -> void:
	pending -= 1
	if not is_instance_valid(enemy) or enemy.dying:
		return
	if Telegraph.catches(world, shape):
		var damage := roundi(Bestiary.monster_attack_damage(enemy.fighter, GameState.hero, GameState.pack, GameState.roll) * float(attack["power"]))
		world.player.take_hit(damage, shape[0], enemy.fighter.get("inflicts") if attack.get("inflicts", false) else null)
		world.camera_rig.shake(5.0, 0.3)
	# The last mark of a cast lets the boss move again.
	if pending <= 0:
		enemy.mode = "chase"


## The dead rise at the caster's side (never more than the attack's cap).
func _summon(attack: Dictionary) -> void:
	var alive := world.get_tree().get_nodes_in_group("summoned").filter(func(node: Node) -> bool: return not node.dying).size()
	var cell := Vector2i((enemy.global_position / TILE).floor())
	for i in mini(int(attack["count"]), int(attack["max"]) - alive):
		var offsets: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, -2)]
		var spot: Vector2i = cell + offsets[i % offsets.size()]
		if not world.map.is_walkable(spot):
			spot = cell
		# The dead rise at their master's level (PIX-186), not the floor's lift.
		var add: Node = world.foes.spawn_enemy(pattern["summon"], spot, "", "", false, false, cell, Bestiary.lift_to(pattern["summon"], int(enemy.fighter.get("level", Bestiary.monster(enemy.fighter["id"])["level"]))))
		add.add_to_group("summoned")
		# The dead a boss raises pay nothing (PIX-180): no farm in a long fight.
		add.fighter["gold"] = 0
		add.fighter["xp"] = 0
		world.fx.appear(add)
		add.notice()
	enemy.mode = "chase"


func _exit_tree() -> void:
	for mark in marks:
		if is_instance_valid(mark):
			mark.queue_free()
