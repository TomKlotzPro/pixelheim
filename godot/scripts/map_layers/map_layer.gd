class_name MapLayer
extends RefCounted
## areas: town rooms travel +town-age*
## One kind of what MapView draws, in a script of its own (PIX-359): its
## units in the plan and in the drawing, by the kinds `planning` and
## `building` always gave them (Slicer), and how it changes with the hour.
## A layer keeps nothing itself: what it plans and draws goes on the view
## (`view`), which the world and the harness read. MapView keeps the order
## the units run in, the roots (`under`, `actors`), what the art covers
## (`data.covered`) and what each part took (`took`).

const TILE := MapView.TILE


## Adds this layer's units to the plan (MapView.planning, where its kind
## stands in the order).
func plan(_view: MapView, _slices: Slicer) -> void:
	pass


## Adds this layer's units to the drawing (MapView.building, where its kind
## stands in the order).
func build(_view: MapView, _slices: Slicer) -> void:
	pass


## Lit from dusk's end to dawn, cold by day (MapView.set_night).
func set_night(_view: MapView, _night: bool) -> void:
	pass


# --- A prop's place, for every layer and feature (PIX-369) ---------------------

## `sprite` standing among the actors on the foot of `cell` (sorted on the
## bottom of its row), drawn `at` from the cell's top-left: its root.
static func stand_on(view: MapView, sprite: Node2D, cell: Vector2i, at: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(cell * TILE) + Vector2(0, TILE)
	root.add_to_group("decor")
	sprite.position = at - Vector2(0, TILE)
	root.add_child(sprite)
	view.actors.add_child(root)
	return root


## A box on `cell` (PIX-313's dressing): covering the middle of the bottom
## of the cell, as every prop's foot does (MapView.HAMLET_FOOT).
static func block(view: MapView, cell: Vector2i) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = MapView.HAMLET_FOOT.size
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(cell * TILE) + MapView.HAMLET_FOOT.get_center()
	body.add_to_group("decor")
	view.actors.add_child(body)
