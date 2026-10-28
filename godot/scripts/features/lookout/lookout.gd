class_name Lookout
extends MapLayer
## areas: travel night screen +mountain_road*
## The lookout on the mountain road (PIX-363, the Post's step 6b): a brass
## spyglass on a tripod beside the road where it turns under Morvax's forge,
## over the drop. After dark E at it opens the view over the Reach (LookoutScreen), every
## lit lamp in its kind's colour with the ring it has healed; by day it says
## to come back at night. The mountain road is a walled map of its own, off
## the Reach's plane, so nothing of the Reach is drawn from it: the view is
## the map screen's page of the Reach, drawn for the night. The spyglass is
## drawn here in code in Shade's palette (HamletArt.INKS), as RouteArt's
## pieces are: our own, so CC0, the same with or without the paid pack.

const MAP := "mountain_road"
const CELL := Vector2i(16, 9)
## The spyglass on its tripod, a row a line, its foot the bottom row.
const PIECE := [
	"................",
	"................",
	".ooo............",
	"oYYYoooooooo....",
	"oYQQYYYYYYYYooo.",
	"oYsQ5QQQ5QQQhhho",
	"oQSQ5QQQ5QQQlllo",
	"oQQQ55555555ooo.",
	"o555oooiiooo....",
	".ooo..okko......",
	"......o42o......",
	"......o42o......",
	".....o4o24o.....",
	".....o4o24o.....",
	"....o4oo2o4o....",
	"....o4oo2o4o....",
	"....o4oo2o4o....",
	"...o4o.o2oo4o...",
	"...o4o.o2oo4o...",
	"..o4o..oio.o4o..",
	"..oio...o..oio..",
	"...o........o...",
]

static var _texture: Texture2D


## Its cell taken before anything is drawn.
func plan(view: MapView, slices: Slicer) -> void:
	if view.data.id == MAP:
		slices.add("plan_lookout", func() -> void: view.data.covered[CELL] = true)


## The spyglass standing on its cell among the actors, sorted by its foot,
## and its foot a blocker as every prop's (MapView.HAMLET_FOOT).
func build(view: MapView, slices: Slicer) -> void:
	if view.data.id != MAP:
		return
	slices.add("lookout", func() -> void:
		var root := Node2D.new()
		root.position = Vector2(CELL * TILE) + Vector2(0, TILE)
		root.add_to_group("decor")
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture()
		sprite.position = Vector2(0, -PIECE.size())
		root.add_child(sprite)
		view.actors.add_child(root)
		var shape := RectangleShape2D.new()
		shape.size = MapView.HAMLET_FOOT.size
		var foot := CollisionShape2D.new()
		foot.shape = shape
		var body := StaticBody2D.new()
		body.position = Vector2(CELL * TILE) + MapView.HAMLET_FOOT.get_center()
		body.add_to_group("decor")
		body.add_child(foot)
		view.actors.add_child(body))


## The spyglass in HamletArt's inks, drawn once a session.
static func texture() -> Texture2D:
	if _texture == null:
		var image := Image.create(String(PIECE[0]).length(), PIECE.size(), false, Image.FORMAT_RGBA8)
		for y in PIECE.size():
			var row := String(PIECE[y])
			for x in row.length():
				if row[x] != ".":
					image.set_pixel(x, y, HamletArt.INKS[row[x]])
		_texture = ImageTexture.create_from_image(image)
	return _texture


## Whether E facing `cell` on `map_id` meets the spyglass (the prompt).
static func at(map_id: String, cell: Vector2i) -> bool:
	return map_id == MAP and cell == CELL


## E at the spyglass: the Reach by night, or by day a word to come back
## after dark. True when E meant it.
static func use(world: Node2D, cell: Vector2i) -> bool:
	if not at(world.map.id, cell):
		return false
	if not DayNight.is_night(GameState.world.steps):
		world.messages.flash(Text.t("By day the Reach is only ash and roads from up here. Come back after dark, when the lamps are lit."))
		return true
	var screen := LookoutScreen.new()
	screen.world = world
	world.add_child(screen)
	return true
