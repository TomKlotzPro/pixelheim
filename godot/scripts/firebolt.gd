class_name Firebolt
extends Node2D
## areas: combat field
## A foe's shot in flight: a fireborn elite's firebolt (PIX-155), or a
## shooter's arrow, ball or flame (PIX-410, Reach.shot). It flies straight,
## strikes the hero it meets, and is spent against a wall or once it has
## flown its distance (eight tiles for a firebolt).

const TILE := 16.0
const RANGE := 8.0 * TILE
## It strikes a hero whose chest it passes this close to (the width of the
## way an elite marks for it: elite_brain.gd).
const REACH := 9.0
## Drawn without the paid pack's strips: an arrow's shaft, a ball, an ember.
const SHAFT := Color(0.85, 0.75, 0.55)
const BALL := Color(0.95, 0.92, 0.8)
const EMBER := Color(1.0, 0.55, 0.15)

var world: Node2D
var caster: Dictionary
var power := 1.0
var heading := Vector2.RIGHT
var speed := 120.0
var flown := 0.0
## How far it flies, and what it looks like (flame, arrow or ball).
var flies := RANGE
var look := "flame"


func _ready() -> void:
	z_index = 6
	match look:
		"arrow":
			# Shade draws the arrow pointing up; turned by quarter turns, as
			# the hero's (SkillFx).
			var frames := ItemIcons.effect("arrow", 12.0)
			if frames != null:
				var arrow := AnimatedSprite2D.new()
				arrow.sprite_frames = frames
				arrow.rotation = snappedf(heading.angle() + PI / 2.0, PI / 2.0)
				arrow.play()
				add_child(arrow)
			else:
				var shaft := Line2D.new()
				shaft.points = PackedVector2Array([-heading * 4.0, heading * 3.0])
				shaft.width = 1.0
				shaft.default_color = SHAFT
				add_child(shaft)
		"ball":
			_dot(BALL, 2.0)
		_:
			var frames := ItemIcons.effect("flame", 14.0)
			if frames != null:
				var flame := AnimatedSprite2D.new()
				flame.sprite_frames = frames
				flame.scale = Vector2.ONE * 0.75
				flame.play()
				add_child(flame)
			else:
				_dot(EMBER, 4.0)


## A square of `size` px on its middle.
func _dot(color: Color, size: float) -> void:
	var dot := ColorRect.new()
	dot.color = color
	dot.size = Vector2(size, size)
	dot.position = -dot.size / 2.0
	add_child(dot)


func _physics_process(delta: float) -> void:
	var step := heading * speed * delta
	position += step
	flown += step.length()
	var player: CharacterBody2D = world.player
	if not player.dead and position.distance_to(player.global_position + Vector2(0, -6)) < REACH:
		var damage := roundi(Bestiary.monster_attack_damage(caster, GameState.hero, GameState.pack, GameState.roll) * power)
		var before: int = GameState.hero.hp
		player.take_hit(damage, position, caster.get("inflicts"))
		# Dodged or warded, take_hit has its own sound: the strike only lands.
		if GameState.hero.hp < before:
			var fire := look == "flame"
			Sound.play("firebolt_hit" if fire else "hit_arrow")
		queue_free()
		return
	if flown > flies or not world.map.is_walkable(Vector2i((position / TILE).floor())):
		queue_free()
