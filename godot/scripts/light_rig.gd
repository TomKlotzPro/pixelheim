extends Node
## The world's light, frame by frame (PIX-221): the darkness for the place
## and the hour (Lights' colours) on a CanvasModulate, and every light in the
## "lights" group brought up as it gets dark - fires flickering, the hero's
## lantern with them. With reduced motion, nothing flickers.

var world: Node
var darkness: CanvasModulate
var lantern: PointLight2D
## The glow (PIX-222): a screen pass between the world and the HUD.
var bloom: ColorRect
## The glow's canvas layer: over the world, under the HUD (layer 2).
const GLOW_LAYER := 1
## How strongly bright things bloom by day and at night: not in the sun
## (sunlit sand is bright too), a soft halo round every flame in the dark.
const GLOW_DAY := 0.0
const GLOW_NIGHT := 0.9
## The light now and how dark it is (0 by day, 1 at night).
var light := Color.WHITE
var dark := 0.0


func _ready() -> void:
	darkness = CanvasModulate.new()
	world.add_child(darkness)
	# Its own layer, under the HUD's: only the world blooms.
	var layer := CanvasLayer.new()
	layer.layer = GLOW_LAYER
	world.add_child(layer)
	bloom = ColorRect.new()
	bloom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://shaders/bloom.gdshader")
	bloom.material = glow
	layer.add_child(bloom)


## The hero carries a lantern: it only shows when it's dark.
func give_lantern(player: Node2D) -> void:
	lantern = Lights.make(Vector2(0, -6), 96.0, Lights.LANTERN, Lights.LANTERN_ENERGY, true)
	player.add_child(lantern)


## The light for the map the hero is on, at this hour.
func light_for(map: MapData) -> Color:
	if map == null:
		return Lights.DAY
	if map.floor_level > 0 or map.style == "cave":
		return Lights.UNDERGROUND
	if GameState.progression.prologue != Prologue.DONE and map.id == "town":
		return Lights.ASH_NIGHT
	if PunyInterior.is_room(map.id):
		return Lights.indoor(GameState.world.steps)
	return Lights.outdoor(GameState.world.steps)


func _process(_delta: float) -> void:
	light = light_for(world.map)
	darkness.color = light
	dark = Lights.darkness(light)
	bloom.visible = GameState.settings.glow
	if bloom.visible:
		(bloom.material as ShaderMaterial).set_shader_parameter("strength", lerpf(GLOW_DAY, GLOW_NIGHT, dark))
	var still: bool = GameState.settings.reduce_motion
	var t := Time.get_ticks_msec() / 1000.0
	for node in get_tree().get_nodes_in_group("lights"):
		var lamp := node as PointLight2D
		var energy := float(lamp.get_meta("energy", 1.0)) * dark
		if lamp.get_meta("flicker", false) and not still:
			var phase := float(lamp.get_meta("phase", 0.0))
			energy *= 1.0 + 0.07 * sin(t * 8.3 + phase) + 0.04 * sin(t * 21.7 + phase * 1.9)
		lamp.energy = energy
		lamp.visible = energy > 0.01
