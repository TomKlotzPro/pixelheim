extends TextureRect
## areas: combat screen
## The faint red at the screen's edges when the hero is hurt (PIX-447): a
## hit flashes it, stronger for a bigger share of health lost, fading in a
## third of a second; below low health in a fight it breathes with the
## dock's beating bar, held still under reduced motion. The players watch
## the hero, not the bar. On the HUD's layer over the sky's tint, so it
## reads at night, and under the dock and every line, so it steps aside
## with the HUD for a screen or a cutscene. A code-made gradient: nothing
## to draw.

const Dock := preload("res://scripts/hud_dock.gd")
const RED := Color(0.8, 0.04, 0.12)
## A hit's flash at the very edge: the faintest scratch, and a fifth of
## health or more at once. Faint, as Tom wants the screen kept.
const LEAST := 0.12
const MOST := 0.25
## Real seconds: the hit-stop that comes with the blow doesn't stretch it.
const FADE_S := 0.35
## Low health's breath in a fight, low to high with the bar's beat; its
## middle, held, under reduced motion.
const BREATH := Vector2(0.06, 0.18)

var world: Node
## What's left of the last hit's flash.
var flash := 0.0
var _fade: Tween
## On the app's linear canvas, mixed into the screen in its own colours, so
## it reads there as in the browser (shaders/hurt_edge.gdshader).
var _screen_mix := ShaderMaterial.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Smooth across the screen, not in a 64-pixel texture's steps.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var red := Gradient.new()
	red.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	red.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	red.colors = PackedColorArray([Color(RED, 0.0), Color(RED, 0.0), RED])
	var shade := GradientTexture2D.new()
	shade.gradient = red
	shade.fill = GradientTexture2D.FILL_RADIAL
	shade.fill_from = Vector2(0.5, 0.5)
	shade.fill_to = Vector2(1.0, 0.5)
	texture = shade
	_screen_mix.shader = preload("res://shaders/hurt_edge.gdshader")
	visible = false


## A hit that took `share` of the hero's most health.
func struck(share: float) -> void:
	flash = flash_alpha(share)
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "flash", 0.0, FADE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func flash_alpha(share: float) -> float:
	return lerpf(LEAST, MOST, clampf(share * 5.0, 0.0, 1.0))


func _process(_delta: float) -> void:
	var breath := 0.0
	var hero := GameState.hero
	if Dock.low_hp(hero.hp, int(hero.stats["maxHp"])) and world != null and world.foes.in_fight():
		breath = lerpf(BREATH.x, BREATH.y, 0.5 if GameState.settings.reduce_motion else Dock.beat())
	var shown := maxf(flash, breath)
	# Nothing drawn while there's nothing to show.
	visible = shown > 0.0
	modulate.a = shown
	# Read each frame: the look book changes looks in a run.
	material = _screen_mix if DesktopLook.linear else null
