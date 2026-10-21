class_name Delve
extends Node
## areas: dungeon +vault*
## The dungeons' floors as the hero walks them (Solid Ground, PIX-260: moved
## out of world.gd as they were): which floor of how many they've come to,
## and a boss's ways out opening where they can see them. The old
## mountain's numbered floors and the Deep Hunt under them left with
## PIX-257; every dungeon is a list of maps in depths.json now (Depths),
## the Kings' Vault among them.

## How long after a boss falls its way out chimes (PIX-292): past the
## fall's slow beat and its victory sting, so it's heard on its own.
const WAY_OUT_CHIME_S := 1.2
## A way out where a boss fell rises once its body has gone and its spoils
## have risen (PIX-339), looked for this often, and at the latest this long
## after the fall.
const SETTLE_STEP_S := 0.1
const SETTLE_MOST_S := 4.0
## The view's shake as its slabs give (none with Reduce motion).
const SINK_SHAKE := 3.0
const SINK_SHAKE_S := 0.3

var world: Node
## The way out rising where a boss fell (PIX-339), while this visit lasts;
## `waiting` from the fall until it begins.
var rise: StairRise
var waiting := false


## A region dungeon's boss has fallen (PIX-255) at `fell`: on its floor, the
## shortcut's door opens, the way straight out to the dungeon's way in; and
## when it fell more than a few steps from that door, a way out opens right
## where it fell as well (PIX-292, Tom: « Porte de sortie direct après un
## boss »), risen out of the floor once `boss` has finished falling
## (PIX-339: _rise). The door draws the eye as it opens: a burst of light
## and dust, a lamp left burning over it, the chime of a way opening a beat
## after the fall's own sounds, and the arrow points to the nearer (Hud).
## Nothing when there's no shortcut here, or it's open.
func open_shortcut(fell := Depths.NOWHERE, boss: Node = null) -> void:
	var map: MapData = world.map
	var door := Depths.shortcut_on(map.id)
	if door.is_empty() or map.portals.has(door["cell"]):
		return
	if not Depths.open_shortcut(map, GameState.progression.hunted):
		return
	world.view.reopen(door["cell"])
	_opened(door["cell"])
	Sound.play("door")
	world.messages.log_lines([String(door["opened"])])
	if Depths.way_out_cell(map, fell, world.player_cell) != Depths.NOWHERE:
		_rise(fell, door, boss)
	var visit: MapView = world.view
	get_tree().create_timer(WAY_OUT_CHIME_S).timeout.connect(func() -> void:
		if world.view == visit:
			Sound.play_ui("wayout")
	)


## The way out where a boss fell (PIX-339, Tom: « ça fait bizarre de tuer
## un boss et qu'un escalier pop »): once its body has gone and the spoils
## over it have risen and faded, so the two never fight, the floor where
## it fell (or beside it, never under the hero) cracks and gives into a
## stair up (StairRise), the view shaking and the dust rising as its slabs
## sink; once open it gets its plate and its words. Nothing if the hero has
## left the floor by then.
func _rise(fell: Vector2i, door: Dictionary, boss: Node) -> void:
	var visit: MapView = world.view
	waiting = true
	var waited := 0.0
	while waited < SETTLE_MOST_S and (is_instance_valid(boss) or world.fx.rising_now() > 0):
		await get_tree().create_timer(SETTLE_STEP_S).timeout
		waited += SETTLE_STEP_S
	waiting = false
	var cell := Depths.way_out_cell(world.map, fell, world.player_cell)
	if world.view != visit or cell == Depths.NOWHERE:
		return
	rise = StairRise.new()
	rise.map = world.map
	rise.cell = cell
	rise.sinking.connect(func() -> void:
		world.camera_rig.shake(SINK_SHAKE, SINK_SHAKE_S)
		if not rise.still:
			for across in [-6, 0, 6]:
				world.fx.dust(MapView.center(cell) + Vector2(across, 4)))
	rise.risen.connect(func() -> void:
		world.view.sign_way_out(cell)
		world.messages.log_lines([String(door["fell"])]))
	# Under the actors, over the floor and what stands on it.
	world.view.dungeon_objects.add_child(rise)
	# A rumble, stone giving, then a gust of air down the stair: timed to it.
	Sound.play("stairRise", false)


## Where the way out rising where a boss fell stands (PIX-339): "waiting"
## for the fall to end, then StairRise's phase; "" with none this visit.
func stair() -> String:
	if waiting:
		return "waiting"
	return rise.phase() if is_instance_valid(rise) else ""


## A way out opening (PIX-292): light bursts and dust rises off it, and
## a lamp stays lit over it (MapView.light_way_out).
func _opened(cell: Vector2i) -> void:
	var at := MapView.center(cell)
	world.fx.dust(at)
	world.fx.skill_flash(at, UiStyle.BRASS_LIGHT)
	world.view.light_way_out(cell)


## The floor of a region's dungeon come to (PIX-255): which one of how
## many, in the battle log.
func arrive(map: MapData) -> void:
	var line := Depths.floor_line(map.id)
	if line != "":
		world.messages.log_lines([line])

