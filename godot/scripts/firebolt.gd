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
## The dark rim Shade draws round his figures: a shot reads on the pale
## path as on the grass (PIX-470: the ball was one cream pixel on the sand).
const RIM := Color("1a1410")
## A gun's flash, aimed the way its ball goes, and how long it shows.
const FLASH := Color("fff3c4")
const FLASH_S := 0.12

var world: Node2D
var caster: Dictionary
var power := 1.0
var heading := Vector2.RIGHT
var speed := 120.0
var flown := 0.0
## How far it flies, and what it looks like (flame, arrow or ball).
var flies := RANGE
var look := "flame"
## Whether a ball leaves a flash behind it (_flash): for a shooter whose
## sheet draws none of its own.
var flash := false


func _ready() -> void:
	# Over the foes' level tags: a shot is seen all the way (PIX-470).
	z_index = Foes.OVER_TAGS
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
				add_child(plain(look, heading))
		"ball":
			add_child(plain(look, heading))
			if flash:
				_flash()
		_:
			var frames := ItemIcons.effect("flame", 14.0)
			if frames != null:
				var flame := AnimatedSprite2D.new()
				flame.sprite_frames = frames
				flame.scale = Vector2.ONE * 0.75
				flame.play()
				add_child(flame)
			else:
				add_child(plain(look, heading))


## Its look drawn without the paid pack's strips, flying `along` a way:
## an arrow's shaft, a ball, an ember. The hero's arrow and bolt fly these
## too without the pack (SkillFx.swing).
static func plain(kind: String, along: Vector2) -> CanvasItem:
	var shot := Node2D.new()
	if kind == "arrow":
		# Its shaft in a dark rim, the head bright.
		for line: Array in [[RIM, 3.0, -5.0, 4.0], [SHAFT, 1.0, -4.0, 3.0], [BALL, 1.0, 1.0, 3.0]]:
			var shaft := Line2D.new()
			shaft.points = PackedVector2Array([along * line[2], along * line[3]])
			shaft.width = line[1]
			shaft.default_color = line[0]
			shot.add_child(shaft)
		return shot
	if kind == "ball":
		# A ball in a dark rim with its smoke behind it, a few pixels long:
		# on the grid, so it stays crisp whichever way it flies.
		for puff in 3:
			shot.add_child(_dot(Color(RIM, 0.55 - 0.15 * puff), Vector2(2, 2), (-along * (4.0 + 2.5 * puff)).round()))
		shot.add_child(_dot(RIM, Vector2(5, 3), Vector2.ZERO))
		shot.add_child(_dot(RIM, Vector2(3, 5), Vector2.ZERO))
		shot.add_child(_dot(BALL, Vector2(3, 3), Vector2.ZERO))
		return shot
	shot.add_child(_dot(EMBER, Vector2(4, 4), Vector2.ZERO))
	return shot


## A block of one colour, its middle `at`.
static func _dot(color: Color, size: Vector2, at: Vector2) -> ColorRect:
	var dot := ColorRect.new()
	dot.color = color
	dot.size = size
	dot.position = at - (size / 2.0).floor()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


## A gun's flash where the ball leaves it, pointing the way the ball goes
## (PIX-470), left behind as the ball flies and gone in a moment. Only for
## a shooter with no attack drawn (`flash`): the gunner's sheet has its own.
func _flash() -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(3, 0), Vector2(5, -3), Vector2(12, 0), Vector2(5, 3)])
	flash.color = FLASH
	flash.rotation = heading.angle()
	flash.top_level = true
	flash.position = position
	add_child(flash)
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, FLASH_S)


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
