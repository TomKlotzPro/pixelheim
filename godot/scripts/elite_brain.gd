extends Node
## An elite's one trick (PIX-155), by its family, told before it lands: beasts
## lunge down a marked line, greenskins cleave the ground before them,
## constructs stamp a ring around themselves, fireborn spit a firebolt, the
## undead raise a guard that turns most of a blow. A named monster (PIX-156)
## has its family's trick and one of its own besides: Greymaw howls up
## wolves, the Drowned Knight's bog grasps and holds, Cinderjaw spits fire
## three ways, Mossback throws a stone, Grandmother Gulp leaps onto you.
## combat.json's "eliteMoves" and "named" hold the numbers; the enemy it
## rides on (its parent) does the walking and biting in between.

const TILE := 16.0
## After any move, the others wait at least this long: never two at once.
const BREATHER := 1.0

var enemy: CharacterBody2D
var world: Node2D
## [{move: Dictionary, cooldown: float}], tried in order.
var moves: Array[Dictionary] = []
## Wolves a howl called that still live.
var called: Array[Node] = []


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	var family: Dictionary = Bestiary._data()["eliteMoves"].get(Bestiary.family_of(enemy.fighter["id"]), {})
	if not family.is_empty():
		# A lunge or a bolt opens the fight from range; the rest come later.
		moves.append({"move": family, "cooldown": 0.5 if String(family["move"]) in ["lunge", "firebolt"] else 1.5})
	if not enemy.named.is_empty():
		moves.append({"move": enemy.named["move"], "cooldown": 2.5})


func _physics_process(delta: float) -> void:
	if enemy.dying or enemy.mode != "chase":
		return
	for slot in moves:
		slot["cooldown"] -= delta
	for slot in moves:
		if slot["cooldown"] <= 0 and _try(slot["move"]):
			slot["cooldown"] = float(slot["move"]["every"])
			for other in moves:
				other["cooldown"] = maxf(other["cooldown"], BREATHER)
			return


## Uses `move` if the hero is in its reach; true when it did.
func _try(move: Dictionary) -> bool:
	var hero: Vector2 = world.player.global_position
	var at: Vector2 = enemy.global_position
	var tiles := at.distance_to(hero) / TILE
	var reach: Array = move["range"]
	if tiles < float(reach[0]) or tiles > float(reach[1]):
		return false
	if String(move["move"]) == "howl" and _calling() >= int(move["max"]):
		return false
	if world.harness:
		print("[elite] %s %s at %.1f tiles" % [enemy.fighter["id"], move["move"], tiles])
	match String(move["move"]):
		"lunge":
			var length := minf(float(move["length"]), tiles + 1.0) * TILE
			_tell(move, Telegraph.band(at, hero, length, float(move["width"]) * TILE), "lunge")
		"cleave":
			_tell(move, Telegraph.band(at, hero, float(move["length"]) * TILE, float(move["width"]) * TILE), "")
		"stamp":
			_tell(move, Telegraph.circle(at, float(move["radius"]) * TILE), "")
		"guard":
			_guard(move)
		"firebolt":
			_flash(move, func() -> void: _bolt(move, (hero - enemy.global_position).normalized()))
		"firefan":
			_flash(move, func() -> void:
				var ahead := (hero - enemy.global_position).normalized()
				var count := int(move["count"])
				for i in count:
					_bolt(move, ahead.rotated(float(move["spread"]) * (i - (count - 1) / 2.0)))
			)
		"grasp", "boulder":
			_tell(move, Telegraph.circle(hero, float(move["radius"]) * TILE), "")
		"leap":
			_tell(move, Telegraph.circle(hero, float(move["radius"]) * TILE), "leap")
		"howl":
			_flash(move, func() -> void: _howl(move))
	return true


## Stands still while its mark pulses, then strikes it; a lunge first leaps
## to the mark's far end, a leap onto its middle.
func _tell(move: Dictionary, shape: PackedVector2Array, jump: String) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	Telegraph.mark(world, shape, float(move["tell"]), _strike.bind(move, jump))


func _strike(shape: PackedVector2Array, move: Dictionary, jump: String) -> void:
	if not is_instance_valid(enemy) or enemy.dying:
		return
	if jump != "":
		var mid := Vector2.ZERO
		for point in shape:
			mid += point
		mid /= shape.size()
		var land := (shape[1] + shape[2]) / 2.0 if jump == "lunge" else mid
		var cell := Vector2i((land / TILE).floor())
		var from := Vector2i((enemy.global_position / TILE).floor())
		if world.map.is_walkable(cell) and Packs.can_see(world.map, from, cell):
			var hop := enemy.create_tween()
			hop.tween_property(enemy, "global_position", land, 0.14 if jump == "lunge" else 0.22).set_trans(Tween.TRANS_QUAD)
	if String(move["move"]) in ["boulder", "leap", "grasp"]:
		var mid := Vector2.ZERO
		for point in shape:
			mid += point
		world.dust(mid / shape.size())
		world.shake(2.5, 0.15)
	if Telegraph.catches(world, shape):
		var damage := roundi(Bestiary.monster_attack_damage(enemy.fighter, GameState.hero, GameState.pack, GameState.roll) * float(move["power"]))
		world.player.take_hit(damage, enemy.global_position, move.get("inflicts", enemy.fighter.get("inflicts")))
	enemy.mode = "chase"


## A guard raised for a moment: blows mostly glance off (enemy.take_hit).
func _guard(move: Dictionary) -> void:
	enemy.guarding = true
	var shine: Tween = enemy.sprite.create_tween()
	shine.tween_property(enemy.sprite, "modulate", Color(0.7, 0.85, 1.4), 0.12)
	shine.tween_interval(float(move["seconds"]))
	shine.tween_property(enemy.sprite, "modulate", Color.WHITE, 0.15)
	shine.tween_callback(func() -> void: enemy.guarding = false)


## Stands still and glows for the tell, then does `then`.
func _flash(move: Dictionary, then: Callable) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	var flash: Tween = enemy.sprite.create_tween()
	flash.tween_property(enemy.sprite, "modulate", Color(1.8, 1.0, 0.5), float(move["tell"]))
	flash.tween_callback(func() -> void:
		enemy.sprite.modulate = Color.WHITE
		if enemy.dying:
			return
		then.call()
		enemy.mode = "chase"
	)


## A bolt of fire flying `heading` from the caster.
func _bolt(move: Dictionary, heading: Vector2) -> void:
	var bolt := preload("res://scripts/firebolt.gd").new()
	bolt.world = world
	bolt.caster = enemy.fighter.duplicate()
	bolt.power = float(move["power"])
	bolt.position = enemy.global_position + Vector2(0, -6)
	bolt.heading = heading
	bolt.speed = float(move["speed"])
	world.add_child(bolt)


## The forest answers a howl: wolves of its kind at its side.
func _howl(move: Dictionary) -> void:
	world.log_line("%s howls - the forest answers!" % enemy.fighter["name"])
	world.shake(3.0, 0.3)
	var cell := Vector2i((enemy.global_position / TILE).floor())
	var offsets: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, -2)]
	for i in mini(int(move["count"]), int(move["max"]) - _calling()):
		var spot: Vector2i = cell + offsets[i % offsets.size()]
		if not world.map.is_walkable(spot):
			spot = cell
		var wolf: Node = world.spawn_enemy(move["monsterId"], spot, enemy.region, "", false, true, Vector2i((enemy.home / TILE).floor()))
		called.append(wolf)
		world.appear(wolf)
		wolf.notice()


func _calling() -> int:
	called.assign(called.filter(func(wolf: Node) -> bool: return is_instance_valid(wolf) and not wolf.dying))
	return called.size()
