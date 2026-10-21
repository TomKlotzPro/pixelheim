class_name StairRise
extends Node2D
## A way out opening where a dungeon's boss fell (PIX-339, Tom: « ça fait
## bizarre de tuer un boss et qu'un escalier pop »). PIX-292 stamped its
## stair on the floor the moment the boss fell; now the fall opens it. Once
## the body has gone and its spoils have risen (Delve waits for both), the
## floor cracks under where it lay and a rumble comes up; a beat later the
## slabs give - a shake and dust (Delve) - and the stair forms out of the
## daylight falling through, pixel by pixel (the fighters' dissolve run
## backwards, its rim the way out's daylight) while that light grows round
## it; the cracks stay round it as broken slabs. Then the way is open
## (Depths.open_way_out) and a gust of air comes down it (Delve plays the
## stairRise sound, all three timed to this). Nothing waits on it: the hero
## walks on as it opens. With Reduce motion the cracks are there at once
## and the stair fades in, with no shake and no dust.
##
## It stays for the visit as the stair itself, its light the way out's
## lamp, breathing (the floor is laid afresh on the next visit, its door in
## the rock open).

const TILE := MapView.TILE
## The floor cracking, then the slabs sinking into steps: a second all told.
const CRACK_S := 0.3
const SINK_S := 0.8
## The cracks: so many out from the middle, each at most so many art
## pixels long (past the cell, into the floor round it).
const RAYS := 7
const REACH := 24
## A crack's dark, and the lit edge of the slab above it, over any
## dungeon's floor.
const CRACK := Color(0.03, 0.02, 0.04, 0.85)
const EDGE := Color(1.0, 0.95, 0.85, 0.3)
## The daylight flares as the stair opens, by this share of the way out's
## lamp at its height, and settles to it.
const FLARE := 1.2

## The slabs give (Delve shakes the view and raises the dust).
signal sinking
## The way is open.
signal risen

var map: MapData
var cell: Vector2i
var still: bool = GameState.settings.reduce_motion
var t := 0.0
var _cracks: Array[Vector2i] = []
var _shown := 0
var _stair: Sprite2D
var _glow: PointLight2D


func _ready() -> void:
	position = Vector2(cell * TILE)
	_cracks = cracks(map, cell)
	_stair = Sprite2D.new()
	_stair.centered = false
	_stair.texture = load(PunyDungeon.SHEET)
	_stair.region_enabled = true
	_stair.region_rect = PunyDungeon.sheet().region(PunyDungeon.STAIRS)
	_stair.material = Juice.fighter_material()
	_stair.material.set_shader_parameter("ember", Lights.WAY_OUT)
	_stair.material.set_shader_parameter("dissolve", 1.0)
	add_child(_stair)
	_glow = Lights.make(Vector2(TILE, TILE) / 2.0, MapView.WAY_OUT_GLOW, Lights.WAY_OUT, 0.0)
	_glow.set_meta("pulse", true)
	add_child(_glow)


## Where it stands: "cracking", "sinking", then "open".
func phase() -> String:
	if t < CRACK_S:
		return "cracking"
	return "sinking" if t < CRACK_S + SINK_S else "open"


func _process(delta: float) -> void:
	if phase() == "open":
		return
	var was := phase()
	t = minf(t + delta, CRACK_S + SINK_S)
	var shown := _cracks.size() if still else ceili(_cracks.size() * minf(t / CRACK_S, 1.0))
	if shown != _shown:
		_shown = shown
		queue_redraw()
	if was == "cracking" and phase() != "cracking":
		sinking.emit()
	var sunk := clampf((t - CRACK_S) / SINK_S, 0.0, 1.0)
	_stair.material.set_shader_parameter("dissolve", 1.0 - sunk)
	_glow.set_meta("energy", Lights.WAY_OUT_ENERGY * (sunk + FLARE * sin(PI * sunk)))
	if phase() == "open":
		Depths.open_way_out(map, cell)
		risen.emit()


## Each crack's dark pixel, and the slab's lit edge just above it.
func _draw() -> void:
	var shown := _cracks.slice(0, _shown)
	for pixel: Vector2i in shown:
		draw_rect(Rect2(pixel, Vector2.ONE), CRACK)
		if not shown.has(pixel + Vector2i.UP):
			draw_rect(Rect2(pixel + Vector2i.UP, Vector2.ONE), EDGE)


## The cracks a fall leaves round `cell`, in art pixels from its corner,
## nearest its middle first (they run outward as they show): RAYS jagged
## lines out from the middle, each stopping where the floor does - never
## over the rock, a portal or anything standing.
static func cracks(map: MapData, cell: Vector2i) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var middle := Vector2(TILE, TILE) / 2.0
	var out: Array[Vector2i] = []
	for ray in RAYS:
		var heading := TAU * (ray + rng.randf_range(-0.3, 0.3)) / RAYS
		var bend := 0.0
		var at := middle
		for i in rng.randi_range(REACH / 2, REACH):
			bend = clampf(bend + rng.randf_range(-0.5, 0.5), -0.7, 0.7)
			at += Vector2.from_angle(heading + bend)
			var pixel := Vector2i(at.floor())
			var on := cell + Vector2i((Vector2(pixel) / TILE).floor())
			if on != cell and (not map.is_walkable(on) or map.portals.has(on)):
				break
			if not out.has(pixel):
				out.append(pixel)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(middle) < Vector2(b).distance_squared_to(middle))
	return out
