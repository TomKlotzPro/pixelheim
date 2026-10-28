class_name LookoutScreen
extends Screen
## areas: travel night screen +mountain_road*
## The view from the lookout on the mountain road at night (PIX-363): the
## map screen's page of the Reach (its Painting: the ground the hero has
## seen, the village, the region names), drawn for the night, and over it
## every lit lamp shining in its kind's colour (RouteArt.light_of) with the
## ring of land it has healed (Lamps). Nothing here is a light: halos drawn
## on the screen's own canvas, so the night's light budget is the world's
## alone (test_night_light). The lamps breathe softly, still with Reduce
## motion. E or Esc closes it.

const MapScreen := preload("res://scripts/map_screen.gd")
## How big the page may be on the screen.
const BOX := Vector2(1040, 520)

var world: Node2D
var panorama: Panorama


func _open() -> void:
	closing_actions = [&"interact"]
	layer = 5
	dim()
	add_child(UiStyle.title(Text.t("The Reach by night")))
	var waits := LanternNight.waits(GameState.progression, GameState.settlement, Gathering.day_of(GameState.world.steps))
	var rings := Lamps.now(Routes.MAP)
	var lit := lamps(rings, waits)
	var on_page := Atlas.sheets(Atlas.REACH, GameState.world.discovered, world.map.id)
	var sizes := {}
	var reach: MapData = null
	for sheet: Dictionary in on_page:
		sheet["map"] = world.load_map(sheet["id"])
		sizes[sheet["id"]] = sheet["map"].size
		if sheet["id"] == Routes.MAP:
			reach = sheet["map"]
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.window(14))
	add_child(frame)
	panorama = Panorama.new()
	panorama.world = world
	panorama.clip_contents = true
	frame.add_child(panorama)
	panorama.paint(on_page, Atlas.tile_px(Atlas.page_size(on_page, sizes), BOX), false, {})
	panorama.light(lit, {} if waits else rings_healed(reach.grid, rings))
	frame.reset_size()
	frame.position = ((Vector2(1280, 720) - frame.size) / 2.0).floor() + Vector2(0, 16)
	var count := lit.size()
	var line := Text.t("No lamp burns on the Reach yet.") if count == 0 else Text.t("One lamp burns on the Reach.") if count == 1 else Text.t("%d lamps burn on the Reach.") % count
	add_child(UiStyle.label(line, 16, UiStyle.DUSK, Vector2(frame.position.x + 8, frame.position.y - 30)))
	add_child(UiStyle.screen_footer("{key:interact} / Esc  close"))


## The lamps the view shows among `rings` (Lamps.rings): every one lit, by
## place, its kind, its cell on the Reach and the colour it burns; none
## while Lantern Night's lamps wait dark for Fafnyr (`waits`).
static func lamps(rings: Array[Dictionary], waits := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if waits:
		return out
	for ring: Dictionary in rings:
		out.append({"place": ring["place"], "kind": ring["kind"], "cell": ring["cell"], "color": RouteArt.light_of(String(ring["kind"]))})
	return out


## The land `rings` have healed on the Reach's `grid`: cell -> its lamp's
## colour, stronger the further it has grown (Lamps.LOOKS: bare earth
## faint, saplings strongest); where two rings meet, the first's.
static func rings_healed(grid: Dictionary, rings: Array[Dictionary]) -> Dictionary:
	var out := {}
	for ring: Dictionary in rings:
		var own: Array[Dictionary] = [ring]
		var healed := Lamps.healed(grid, own)
		for cell: Vector2i in healed:
			if not out.has(cell):
				out[cell] = Color(RouteArt.light_of(String(ring["kind"])), 0.16 + 0.1 * Lamps.LOOKS.find(healed[cell]))
	return out


## The Reach's page drawn for the night: the ground seen dimmed, the
## healed rings and the lamps over it, the region names on top.
class Panorama extends MapScreen.Painting:
	## How much of the night is over the ground seen.
	const DARK := 0.75
	## A lamp's halo, in cells across, and its rings' strength, outer first.
	const HALO := 6.0
	const HALO_ALPHA := [0.1, 0.18, 0.32]
	## The lamps shown ({place, kind, cell, color}) and the healed land
	## (cell -> colour), on the Reach's own cells.
	var lamps: Array[Dictionary] = []
	var healed := {}

	func light(lit: Array[Dictionary], rings: Dictionary) -> void:
		lamps = lit
		healed = rings
		queue_redraw()

	## The halos breathe, unless motion is reduced.
	func _process(_delta: float) -> void:
		if not GameState.settings.reduce_motion and not lamps.is_empty():
			queue_redraw()

	func _draw() -> void:
		if map == null:
			return
		draw_rect(Rect2(Vector2.ZERO, Vector2(cells * tile_px)), UiStyle.NIGHT)
		var cell_size := Vector2(tile_px, tile_px)
		for cell: Vector2i in _ground:
			draw_rect(Rect2(Vector2(cell * tile_px), cell_size), (_ground[cell] as Color).lerp(UiStyle.NIGHT, DARK))
		var at := at_of(Routes.MAP)
		for cell: Vector2i in healed:
			draw_rect(Rect2(Vector2((cell + at) * tile_px), cell_size), healed[cell])
		_draw_labels()
		var still := GameState.settings.reduce_motion
		for i in lamps.size():
			var lamp: Dictionary = lamps[i]
			var color: Color = lamp["color"]
			var center := _center(lamp["cell"] + at)
			var breath := 1.0 if still else 0.85 + 0.15 * sin(GameClock.msec() / 600.0 + i * 1.7)
			for band in HALO_ALPHA.size():
				var reach := HALO * tile_px * (1.0 - band / float(HALO_ALPHA.size()))
				draw_circle(center, reach, Color(color, HALO_ALPHA[band] * breath))
			var core := maxf(tile_px, 3.0)
			draw_rect(Rect2(center - Vector2.ONE * (core / 2.0 + 1.0), Vector2.ONE * (core + 2.0)), Color(UiStyle.NIGHT, 0.8))
			draw_rect(Rect2(center - Vector2.ONE * core / 2.0, Vector2.ONE * core), color.lightened(0.35))
