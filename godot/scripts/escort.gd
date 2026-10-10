extends Node2D
## An escort (PIX-192): Gunnar's last wagon down the Frostgate - an old
## mammoth hauling the pass's last crates. It walks the route's waypoints
## while the hero keeps close and no foe is at it, so a fight is the hero's
## to win before it moves on. Ambushes rise as it reaches their waypoints and
## go for the wagon; their bites wear it down. Down at the end, the quest's
## goal is met; lost, Gunnar rigs another at the start (GameState and world
## decide; this only walks, takes bites and says how it went).

signal arrived
signal lost

## How close a foe must be to stop the wagon, and to bite it.
const THREAT := 3.0 * 16
const BITE_REACH := 16.0
const BITE_EVERY := 1.2

var world: Node
var def: Dictionary
var route: Array[Vector2] = []
var index := 1
var hp := 0
var max_hp := 0
var done := false
var sprite: AnimatedSprite2D
var crate: Sprite2D
var bar: ColorRect
var bitten_at := {}
## The mammoth's walk (PIX-243): its slow, heavy steps by the ground it
## covers, and the way it heads.
var gait: Gait
var _heading := "down"


func _ready() -> void:
	for cell: Array in def["route"]:
		route.append(MapView.center(Vector2i(int(cell[0]), int(cell[1]))))
	position = route[0]
	max_hp = int(def["hp"])
	hp = max_hp
	# The load rides behind the beast: one of the Frostgate's own crates.
	crate = Sprite2D.new()
	crate.texture = PunyProps.texture(PunyProps.CRATE)
	crate.position = Vector2(0, -14)
	add_child(crate)
	var art := {"sheet": "mini/Mammoth.png", "family": "mini", "scale": 1.5}
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.scale = Vector2.ONE * 1.5
	sprite.position = Vector2(0, PunyArt.lift(art) * 1.5)
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	add_child(sprite)
	gait = Gait.new(sprite, art, 1.5)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.06, 0.05, 0.8)
	back.size = Vector2(26, 3)
	back.position = Vector2(-13, -34)
	add_child(back)
	bar = ColorRect.new()
	bar.color = Color("8fd16a")
	bar.size = Vector2(26, 3)
	bar.position = back.position
	add_child(bar)
	# Readable at night (PIX-221).
	back.material = Lights.unshaded()
	bar.material = Lights.unshaded()


## The ambush foes still standing.
func _foes() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(enemy: Node) -> bool:
		return not enemy.dying and enemy.get("quarry") == self)


func _physics_process(delta: float) -> void:
	if done:
		return
	var near: Array = _foes()
	for foe: Node in near:
		var gap: float = (foe.global_position - global_position).length()
		var now := GameClock.seconds()
		if gap < BITE_REACH and now - float(bitten_at.get(foe.get_instance_id(), -99.0)) >= BITE_EVERY:
			bitten_at[foe.get_instance_id()] = now
			_hurt(ceili(int(foe.fighter["attack"]) * 0.5))
			if done:
				return
	var threatened: bool = near.any(func(foe: Node) -> bool: return (foe.global_position - global_position).length() < THREAT)
	var hero_near: bool = (world.player.global_position - global_position).length() <= float(def["near"]) * 16
	if threatened or not hero_near:
		# It holds its last step a breath, then stands.
		if gait.rest(delta) or not gait.walking:
			_idle()
		return
	var to := route[index] - global_position
	var step := float(def["speed"]) * delta
	if to.length() <= step:
		global_position = route[index]
		_reached(index)
		index += 1
		if index >= route.size():
			done = true
			_idle()
			arrived.emit()
		return
	global_position += to.normalized() * step
	_heading = Gait.steer(_heading, to)
	gait.walk(_heading, step, delta)
	# The crates trail behind the way it walks.
	crate.position = -to.normalized() * 12 + Vector2(0, -4)


## Standing, facing down the pass.
func _idle() -> void:
	gait.halt()
	var wanted := PunyArt.pick(sprite.sprite_frames, "idle", "down")
	if sprite.animation != wanted or not sprite.is_playing():
		sprite.play(wanted)


## A waypoint reached: the ambush waiting there rises.
func _reached(at: int) -> void:
	for ambush: Dictionary in def.get("ambushes", []):
		if int(ambush["at"]) == at:
			for i in ambush["foes"].size():
				var from: Array = ambush["from"][i]
				var foe: Node = world.foes.spawn_enemy(ambush["foes"][i], Vector2i(int(from[0]), int(from[1])), "", "", false, true)
				foe.quarry = self
				world.fx.appear(foe)
				foe.notice()
			world.messages.flash(ambush["line"])


func _hurt(amount: int) -> void:
	hp = maxi(0, hp - amount)
	bar.size.x = 26.0 * hp / max_hp
	bar.color = Color("8fd16a") if hp > max_hp / 3 else Color("ff5a4a")
	world.fx.float_number(amount, global_position + Vector2(0, -30), Color(1, 0.5, 0.4))
	if hp == 0:
		done = true
		lost.emit()
