extends Node
## An elite's one trick (PIX-155), by its family, told before it lands: beasts
## lunge down a marked line, greenskins cleave the ground before them,
## constructs stamp a ring around themselves, fireborn spit a firebolt, the
## undead raise a guard that turns most of a blow. combat.json's
## "eliteMoves" holds the numbers; the enemy it rides on (its parent) does
## the walking and biting in between.

const TILE := 16.0

var enemy: CharacterBody2D
var world: Node2D
var move: Dictionary
var cooldown := 1.5


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	move = Bestiary._data()["eliteMoves"][Bestiary.family_of(enemy.fighter["id"])]
	# A lunge or a bolt opens the fight from range; the rest come later.
	if String(move["move"]) in ["lunge", "firebolt"]:
		cooldown = 0.5


func _physics_process(delta: float) -> void:
	if enemy.dying or enemy.mode != "chase":
		return
	cooldown -= delta
	if cooldown > 0:
		return
	var hero: Vector2 = world.player.global_position
	var at: Vector2 = enemy.global_position
	var tiles := at.distance_to(hero) / TILE
	var reach: Array = move["range"]
	if tiles < float(reach[0]) or tiles > float(reach[1]):
		return
	cooldown = float(move["every"])
	if world.harness:
		print("[elite] %s %s at %.1f tiles" % [enemy.fighter["id"], move["move"], tiles])
	match String(move["move"]):
		"lunge":
			var length := minf(float(move["length"]), tiles + 1.0) * TILE
			_tell(Telegraph.band(at, hero, length, float(move["width"]) * TILE), true)
		"cleave":
			_tell(Telegraph.band(at, hero, float(move["length"]) * TILE, float(move["width"]) * TILE), false)
		"stamp":
			_tell(Telegraph.circle(at, float(move["radius"]) * TILE), false)
		"guard":
			_guard()
		"firebolt":
			_firebolt(hero)


## Stands still while its mark pulses; a lunge then leaps to the mark's end.
func _tell(shape: PackedVector2Array, leap: bool) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	Telegraph.mark(world, shape, float(move["tell"]), _strike.bind(leap))


func _strike(shape: PackedVector2Array, leap: bool) -> void:
	if not is_instance_valid(enemy) or enemy.dying:
		return
	if leap:
		var tip := (shape[1] + shape[2]) / 2.0
		var cell := Vector2i((tip / TILE).floor())
		var from := Vector2i((enemy.global_position / TILE).floor())
		if world.map.is_walkable(cell) and Packs.can_see(world.map, from, cell):
			var jump := enemy.create_tween()
			jump.tween_property(enemy, "global_position", tip, 0.14).set_trans(Tween.TRANS_QUAD)
	if Telegraph.catches(world, shape):
		var damage := roundi(Bestiary.monster_attack_damage(enemy.fighter, GameState.hero, GameState.pack, GameState.roll) * float(move["power"]))
		world.player.take_hit(damage, enemy.global_position, enemy.fighter.get("inflicts"))
	enemy.mode = "chase"


## A guard raised for a moment: blows mostly glance off (enemy.take_hit).
func _guard() -> void:
	enemy.guarding = true
	var shine: Tween = enemy.sprite.create_tween()
	shine.tween_property(enemy.sprite, "modulate", Color(0.7, 0.85, 1.4), 0.12)
	shine.tween_interval(float(move["seconds"]))
	shine.tween_property(enemy.sprite, "modulate", Color.WHITE, 0.15)
	shine.tween_callback(func() -> void: enemy.guarding = false)


## A flash of the hands, then a bolt of fire flies where the hero stood.
func _firebolt(hero: Vector2) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	var flash: Tween = enemy.sprite.create_tween()
	flash.tween_property(enemy.sprite, "modulate", Color(1.8, 1.0, 0.5), float(move["tell"]))
	flash.tween_callback(func() -> void:
		enemy.sprite.modulate = Color.WHITE
		if enemy.dying:
			return
		var bolt := preload("res://scripts/firebolt.gd").new()
		bolt.world = world
		bolt.caster = enemy.fighter.duplicate()
		bolt.power = float(move["power"])
		bolt.position = enemy.global_position + Vector2(0, -6)
		bolt.heading = (hero - enemy.global_position).normalized()
		bolt.speed = float(move["speed"])
		world.add_child(bolt)
		enemy.mode = "chase"
	)
