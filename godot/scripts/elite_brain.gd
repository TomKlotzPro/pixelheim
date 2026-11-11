extends Node
## areas: combat field
## An elite's one trick (PIX-155), by its family, told before it lands: beasts
## lunge down a marked line, greenskins cleave the ground before them,
## constructs stamp a ring around themselves, fireborn spit a firebolt, the
## undead raise a guard that turns most of a blow. A named monster (PIX-156)
## has its family's trick and one of its own besides: Greymaw howls up
## wolves, the Drowned Knight's bog grasps and holds, Cinderjaw spits fire
## three ways, Mossback throws a stone, Grandmother Gulp leaps at you.
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
## What it is telling now, for a stun to break (interrupt, PIX-440): its
## marks on the ground, its glow, its raised guard.
var marks: Array[Node2D] = []
var _glow: Tween
var _shine: Tween


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	var family: Dictionary = Bestiary.elite_moves(Bestiary.family_of(enemy.fighter["id"]))
	if not family.is_empty():
		# A lunge or a bolt opens the fight from range; the rest come later.
		moves.append({"move": family, "cooldown": 0.5 if String(family["move"]) in ["lunge", "firebolt"] else 1.5})
	if not enemy.named.is_empty():
		moves.append({"move": enemy.named["move"], "cooldown": 2.5})


func _physics_process(delta: float) -> void:
	# Fallen, stood down or gone home, it calls no one: what it called fights
	# on as any wild foe, its bites giving the hero grace again (PIX-421).
	if enemy.dying or enemy.mode == "homeward":
		for wolf: Variant in called:
			if is_instance_valid(wolf):
				wolf.called = false
	# Stunned, it tries no trick (PIX-186).
	if enemy.dying or enemy.mode != "chase" or enemy.ailments.is_stunned():
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
	if not in_reach(move, at, hero, enemy.beyond):
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
			_tell(move, cleave_band(move, at, hero, enemy.beyond), "")
		"stamp":
			_tell(move, Telegraph.circle(at, float(move["radius"]) * TILE + enemy.beyond), "")
		"guard":
			_guard(move)
		"firebolt", "firefan":
			# Each bolt's way is marked on the ground while it is told
			# (PIX-377: Cinderjaw's fan flew unmarked, and a hero who
			# dodged was burned as often as one who stood).
			var ahead := (hero - at).normalized()
			var count := int(move.get("count", 1))
			var ways: Array[Vector2] = []
			for i in count:
				ways.append(ahead.rotated(float(move.get("spread", 0.0)) * (i - (count - 1) / 2.0)))
				_keep(Telegraph.mark(world, Telegraph.band(at, at + ways[i], Firebolt.RANGE, Firebolt.REACH * 2.0), float(move["tell"]), Callable(), i == 0))
			_flash(move, func() -> void:
				for way in ways:
					_bolt(move, way)
			)
		"grasp", "boulder":
			_tell(move, Telegraph.circle(hero, float(move["radius"]) * TILE), "")
		"leap":
			_tell(move, Telegraph.circle(hero, float(move["radius"]) * TILE), "leap")
		"howl":
			_flash(move, func() -> void: _howl(move))
	return true


## Whether a foe at `at` may start `move` on a hero at `hero`: within its
## range, in cells (PIX-422: the cleave within a cell and a quarter, as a
## hero's blade reaches only the cell in front since PIX-410), counted from
## `beyond` pixels nearer: a foe that stops that far past the ring's nearest
## (Enemy.edge_of, PIX-451) reaches as far from its edge, and its cleave's
## band and its stamp's ring run as much further.
static func in_reach(move: Dictionary, at: Vector2, hero: Vector2, beyond := 0.0) -> bool:
	var tiles := (at.distance_to(hero) - beyond) / TILE
	var reach: Array = move["range"]
	return tiles >= float(reach[0]) and tiles <= float(reach[1])


## The ground a cleave marks: a band from the foe toward the hero, its
## `length` reaching a little past where it may start (a hero who stands is
## struck) and no further (one who steps back is not).
static func cleave_band(move: Dictionary, at: Vector2, hero: Vector2, beyond := 0.0) -> PackedVector2Array:
	return Telegraph.band(at, hero, float(move["length"]) * TILE + beyond, float(move["width"]) * TILE)


## Stands still while its mark pulses, then strikes it; a lunge first leaps
## to the mark's far end, a leap to beside its middle.
func _tell(move: Dictionary, shape: PackedVector2Array, jump: String) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	_keep(Telegraph.mark(world, shape, float(move["tell"]), _strike.bind(move, jump)))


func _strike(shape: PackedVector2Array, move: Dictionary, jump: String) -> void:
	if not is_instance_valid(enemy) or enemy.dying:
		return
	if jump != "":
		var mid := Vector2.ZERO
		for point in shape:
			mid += point
		mid /= shape.size()
		# A leap lands its edge off the mark's middle (Enemy.edge_of, PIX-457:
		# it landed on a hero who stood), or stays put when already nearer.
		var land := (shape[1] + shape[2]) / 2.0 if jump == "lunge" else mid + (enemy.global_position - mid).limit_length(enemy.edge)
		var cell := Vector2i((land / TILE).floor())
		var from := Vector2i((enemy.global_position / TILE).floor())
		if world.map.is_walkable(cell) and Packs.can_see(world.map, from, cell):
			var hop := enemy.create_tween()
			hop.tween_property(enemy, "global_position", land, 0.14 if jump == "lunge" else 0.22).set_trans(Tween.TRANS_QUAD)
	if String(move["move"]) in ["boulder", "leap", "grasp"]:
		var mid := Vector2.ZERO
		for point in shape:
			mid += point
		world.fx.dust(mid / shape.size())
		world.camera_rig.shake(2.5, 0.15)
	if Telegraph.catches(world, shape):
		var damage := roundi(Bestiary.monster_attack_damage(enemy.fighter, GameState.hero, GameState.pack, GameState.roll) * float(move["power"]))
		world.player.take_hit(damage, enemy.global_position, move.get("inflicts", enemy.fighter.get("inflicts")))
	enemy.mode = "chase"


## A guard raised for a moment: blows mostly glance off (enemy.take_hit).
func _guard(move: Dictionary) -> void:
	enemy.guarding = true
	Sound.play("guard_raise")
	_shine = enemy.sprite.create_tween()
	_shine.tween_property(enemy.sprite, "modulate", Color(0.7, 0.85, 1.4), 0.12)
	_shine.tween_interval(float(move["seconds"]))
	_shine.tween_property(enemy.sprite, "modulate", Color.WHITE, 0.15)
	_shine.tween_callback(func() -> void: enemy.guarding = false)


## Stands still and glows for the tell, then does `then`.
func _flash(move: Dictionary, then: Callable) -> void:
	enemy.mode = "cast"
	enemy.velocity = Vector2.ZERO
	_glow = enemy.sprite.create_tween()
	_glow.tween_property(enemy.sprite, "modulate", Color(1.8, 1.0, 0.5), float(move["tell"]))
	_glow.tween_callback(func() -> void:
		enemy.sprite.modulate = Color.WHITE
		if enemy.dying:
			return
		then.call()
		enemy.mode = "chase"
	)


## Holds on to a mark till it goes, for a stun to take back.
func _keep(shown: Node2D) -> void:
	marks.append(shown)
	shown.tree_exiting.connect(func() -> void: marks.erase(shown))


## A stun broke what it was telling (PIX-440): marks taken back, the glow and
## the raised guard let go, the blow or the bolts never come. True if there
## was anything to break; the enemy goes back to chasing when its stun ends.
func interrupt() -> bool:
	var broke := false
	for shown: Variant in marks:
		broke = Telegraph.cancel(shown) or broke
	if _glow != null and _glow.is_running():
		_glow.kill()
		enemy.sprite.modulate = Color.WHITE
		broke = true
	if enemy.guarding:
		_shine.kill()
		enemy.sprite.modulate = Color.WHITE
		enemy.guarding = false
		broke = true
	return broke


## A bolt of fire flying `heading` from the caster; a move's "tint" turns
## the flame (Rimefang's frost, PIX-169).
func _bolt(move: Dictionary, heading: Vector2) -> void:
	var bolt := Firebolt.new()
	if move.has("tint"):
		var tint: Array = move["tint"]
		bolt.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	bolt.world = world
	bolt.caster = enemy.fighter.duplicate()
	bolt.power = float(move["power"])
	bolt.position = enemy.global_position + Vector2(0, -6)
	bolt.heading = heading
	bolt.speed = float(move["speed"])
	world.add_child(bolt)
	Sound.play("firebolt_cast")


## The forest answers a howl: wolves of its kind at its side.
func _howl(move: Dictionary) -> void:
	world.messages.log_line(Text.t("%s howls - the forest answers!") % enemy.fighter["name"])
	world.camera_rig.shake(3.0, 0.3)
	var cell := Vector2i((enemy.global_position / TILE).floor())
	var offsets: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, -2)]
	for i in mini(int(move["count"]), int(move["max"]) - _calling()):
		var spot: Vector2i = cell + offsets[i % offsets.size()]
		if not world.map.is_walkable(spot):
			spot = cell
		var wolf: Node = world.foes.spawn_enemy(move["monsterId"], spot, enemy.region, "", false, true, Vector2i((enemy.home / TILE).floor()))
		wolf.called = true
		called.append(wolf)
		world.fx.appear(wolf)
		wolf.notice()


func _calling() -> int:
	# A Variant: a freed wolf can't be passed as a Node to be checked (PIX-379).
	called.assign(called.filter(func(wolf: Variant) -> bool: return is_instance_valid(wolf) and not wolf.dying))
	return called.size()
