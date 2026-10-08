extends Node2D
## A fireborn elite's firebolt (PIX-155): flies straight, burns the hero it
## meets, and gutters out against a wall or after eight tiles.

const TILE := 16.0
const RANGE := 8.0 * TILE

var world: Node2D
var caster: Dictionary
var power := 1.0
var heading := Vector2.RIGHT
var speed := 120.0
var flown := 0.0


func _ready() -> void:
	z_index = 6
	var frames := ItemIcons.effect("flame", 14.0)
	if frames != null:
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.scale = Vector2.ONE * 0.75
		flame.play()
		add_child(flame)
	else:
		var ember := ColorRect.new()
		ember.color = Color(1.0, 0.55, 0.15)
		ember.size = Vector2(4, 4)
		ember.position = Vector2(-2, -2)
		add_child(ember)


func _physics_process(delta: float) -> void:
	var step := heading * speed * delta
	position += step
	flown += step.length()
	var player: CharacterBody2D = world.player
	if not player.dead and position.distance_to(player.global_position + Vector2(0, -6)) < 9.0:
		var damage := roundi(Bestiary.monster_attack_damage(caster, GameState.hero, GameState.pack, GameState.roll) * power)
		player.take_hit(damage, position, caster.get("inflicts"))
		queue_free()
		return
	if flown > RANGE or not world.map.is_walkable(Vector2i((position / TILE).floor())):
		queue_free()
