class_name Juice
## How a fight feels (PIX-226): a pure-white flash when a blow lands, a
## death that dissolves pixel by pixel into embers, a squash and stretch on
## the hero, and a slash's arc trailing every swing in the weapon's colour.
## Pure helpers and constants; the fighters and the world call them.

const FIGHTER_SHADER := preload("res://shaders/fighter.gdshader")
## How long a hit's flash and a death's dissolve take.
const FLASH_SECONDS := 0.1
const KILL_FLASH_SECONDS := 0.18
const DISSOLVE_SECONDS := 0.45
## The hero's shapes: setting off (taller), landing a roll (wider), a swing
## (wound up), each springing back to rest.
const SET_OFF := Vector2(0.9, 1.1)
const LAND := Vector2(1.18, 0.84)
const SWING := Vector2(1.12, 0.9)
const SPRING_SECONDS := 0.16
## How far below a sprite's centre its feet stand (Shade's 64px frames, feet
## at 48): a squash keeps them on the ground.
const FEET := 16.0
## The slash's arc: how far ahead of the hero, how long it lingers, and its
## colour by the weapon in hand (a staff's arcane, a blade's by its rarity).
const SLASH_REACH := 13.0
const SLASH_SECONDS := 0.14
## Over the fighters, under the world's words.
const SLASH_Z := 5
const STEEL := Color(0.86, 0.93, 1.0)
const ARCANE := Color(0.72, 0.56, 1.0)


## A fighter's own copy of the flash-and-dissolve material.
static func fighter_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIGHTER_SHADER
	return material


## Flashes `sprite` pure white and back over `seconds`.
static func flash(sprite: CanvasItem, seconds := FLASH_SECONDS) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("flash", 1.0)
	sprite.create_tween().tween_method(_setter(material, "flash"), 1.0, 0.0, seconds)


## Dissolves `sprite` into embers of `color` over `seconds`; the tween, to
## chain what follows.
static func dissolve(sprite: CanvasItem, color: Color, seconds := DISSOLVE_SECONDS) -> Tween:
	var material := sprite.material as ShaderMaterial
	var tween := sprite.create_tween()
	if material == null:
		tween.tween_property(sprite, "modulate:a", 0.0, seconds)
		return tween
	material.set_shader_parameter("ember", color)
	tween.tween_method(_setter(material, "dissolve"), 0.0, 1.0, seconds).set_ease(Tween.EASE_IN)
	return tween


## Sets `material`'s `parameter`: tweened through set_shader_parameter, as a
## fresh material doesn't answer to its shader_parameter/ paths until its
## property list has been read.
static func _setter(material: ShaderMaterial, parameter: String) -> Callable:
	return func(value: float) -> void: material.set_shader_parameter(parameter, value)


## What a fallen foe leaves as it goes: embers from the undead and the
## fireborn, dust from the rest.
static func remains_color(family: String) -> Color:
	match family:
		"undead":
			return Color(0.62, 0.86, 1.0)
		"fireborn":
			return Color(1.0, 0.55, 0.2)
	return Color(0.86, 0.78, 0.6)


## The slash's colour for the weapon in hand: a staff's arcane, a blade
## white steel, gold for fine and violet for epic.
static func slash_color(attack: String, rarity: String) -> Color:
	if attack == "staff":
		return ARCANE
	match rarity:
		"fine":
			return UiStyle.FINE
		"epic":
			return UiStyle.EPIC
	return STEEL


static var _arc: Texture2D


## A crescent of pixels sweeping across the way the hero faces (drawn facing
## down: the caller turns it by quarter turns, so the pixels stay square).
static func arc() -> Texture2D:
	if _arc == null:
		var size := Vector2i(24, 12)
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var middle := Vector2(size.x / 2.0, -4.0)
		for y in size.y:
			for x in size.x:
				var reach := (Vector2(x + 0.5, y + 0.5) - middle).length()
				# A band between two radii, thickest in the middle of the sweep.
				var thick := 2.6 - absf(x + 0.5 - size.x / 2.0) / size.x * 3.0
				if reach > 12.0 and reach < 12.0 + thick:
					image.set_pixel(x, y, Color(1, 1, 1, 1.0 if reach < 12.0 + thick - 1.0 else 0.55))
		_arc = ImageTexture.create_from_image(image)
	return _arc


## The quarter turn that points the arc (drawn facing down) along `facing`.
static func arc_turn(facing: Vector2) -> float:
	if facing == Vector2.UP:
		return PI
	if facing == Vector2.LEFT:
		return PI / 2.0
	if facing == Vector2.RIGHT:
		return -PI / 2.0
	return 0.0
