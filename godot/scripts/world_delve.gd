class_name Delve
extends Node
## The dungeons' floors as the hero walks them (Solid Ground, PIX-260: moved
## out of world.gd as they were): which floor of how many they've come to,
## and a boss's ways out opening where they can see them. The old
## mountain's numbered floors and the Deep Hunt under them left with
## PIX-257; every dungeon is a list of maps in depths.json now (Depths),
## the Kings' Vault among them.

## How long after a boss falls its way out chimes (PIX-292): past the
## fall's slow beat and its victory sting, so it's heard on its own.
const WAY_OUT_CHIME_S := 1.2

var world: Node


## A region dungeon's boss has fallen (PIX-255) at `fell`: on its floor, the
## shortcut's door opens, the way straight out to the dungeon's way in; and
## when it fell more than a few steps from that door, a way out opens right
## where it fell as well (PIX-292, Tom: « Porte de sortie direct après un
## boss »). Each draws the eye as it opens: a burst of light and dust, a
## lamp left burning over it, the chime of a way opening a beat after the
## fall's own sounds, and the arrow points to the nearer (Hud). Nothing when
## there's no shortcut here, or it's open.
func open_shortcut(fell := Depths.NOWHERE) -> void:
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
	var beside := Depths.way_out_cell(map, fell, world.player_cell)
	if beside != Depths.NOWHERE:
		Depths.open_way_out(map, beside)
		world.view.reopen(beside)
		_opened(beside)
		world.messages.log_lines([String(door["fell"])])
	var visit: MapView = world.view
	get_tree().create_timer(WAY_OUT_CHIME_S).timeout.connect(func() -> void:
		if world.view == visit:
			Sound.play_ui("wayout")
	)


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

