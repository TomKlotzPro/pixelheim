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


static var _see_through: ShaderMaterial

## `sprite` (on its root, the root on its foot) turned see-through round the
## hero while it stands over them (PIX-429, shaders/see_through.gdshader):
## drawn where it was, its origin moved down onto the foot the root is
## sorted on, which the shader compares with the hero's. Trees see through
## in their own material (region_tint).
static func see_through(sprite: Sprite2D) -> void:
	if _see_through == null:
		_see_through = ShaderMaterial.new()
		_see_through.shader = preload("res://shaders/see_through.gdshader")
	sprite.offset.y += sprite.position.y
	sprite.position.y = 0.0
	sprite.material = _see_through


## A soft shadow on the ground under what stands with the middle of its foot
## at `foot` (the drawing's pixels, the bottom of its lowest row), `wide`
## pixels across and `tall` high (ShadowsLayer, PIX-449): a tree, a bush, a
## lamp. Not for Shade's Puny World pieces, which carry their own.
static func cast(view: MapView, foot: Vector2, wide: float, tall: float) -> void:
	view.casters.append(Vector4(foot.x, foot.y, wide, tall))


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
