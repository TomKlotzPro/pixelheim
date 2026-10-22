class_name PatchesLayer
extends MapLayer
## areas: town rooms travel +town-age*
## What lies on the ground to be picked, and the post boxes as they stand
## (PIX-143, PIX-250, PIX-286, PIX-320): MapView's `decor_patches` unit,
## the day's patches dealt and grown back, and how a pickup lies (PIX-359).
## The day's patches are dealt at the end of the gates' plan (`plan_gates`,
## GatesLayer), where they always were.

## Things lying on the ground to pick up (PIX-286): their icons at this
## scale, half a cell; their shadow this far below their middle; and the
## bob's beat, in seconds.
const PICKUP_SCALE := 0.5
const PICKUP_SHADOW := 3.0
const PICKUP_BOB := 0.6


## Today's patches on the ground.
func build(view: MapView, slices: Slicer) -> void:
	slices.add("decor_patches", func() -> void:
		view.patch_sprites = {}
		for cell: Vector2i in view.patches:
			_add_patch_sprite(view, cell))


## A patch on the ground: its material, hidden while it grows back.
static func _add_patch_sprite(view: MapView, cell: Vector2i) -> void:
	var patch: Dictionary = view.patches[cell]
	var root := pickup(ItemIcons.texture(patch["item"]), cell)
	view.ground.add_child(root)
	view.patch_sprites[patch["id"]] = root
	root.visible = Gathering.is_ready(GameState.world, patch["id"])


## Something lying on the ground to pick up (PIX-286): Shade's 16 px icon at
## half its size, half a cell and smaller than the hero's head (at full size
## a herb lay as big as the hero), on a small shadow, lifting a pixel off it
## and down again, with a glint that comes and goes, so it reads as
## something to pick by more than its size. In the middle of `cell`, its
## pixels on the art's grid; still with Reduce motion but for the glint.
static func pickup(texture: Texture2D, cell: Vector2i) -> Node2D:
	var root := Node2D.new()
	root.position = MapView.center(cell)
	root.add_to_group("decor")
	var beat := absf(sin(cell.x * 12.9 + cell.y * 78.2))
	# Without the paid icons only the glint shows, as before: no shadow of
	# nothing.
	if texture != null:
		var shadow := Sprite2D.new()
		shadow.texture = _pickup_shadow()
		shadow.position = Vector2(0, PICKUP_SHADOW)
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.name = "item"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * PICKUP_SCALE
	root.add_child(sprite)
	if not GameState.settings.reduce_motion:
		# A whole pixel of the art up, a while, and down: its own tween,
		# gone with it.
		var bob := sprite.create_tween().set_loops()
		bob.tween_interval(PICKUP_BOB * (0.5 + beat))
		bob.tween_property(sprite, "position:y", -1.0, 0.0)
		bob.tween_interval(PICKUP_BOB)
		bob.tween_property(sprite, "position:y", 0.0, 0.0)
		bob.tween_interval(PICKUP_BOB * (1.5 - beat))
	var glint := ColorRect.new()
	glint.color = Color(1, 1, 0.9)
	glint.size = Vector2(2, 2)
	glint.position = Vector2(4, -6)
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.add_child(glint)
	# The glint's own tween: it goes when the glint goes.
	var twinkle := glint.create_tween().set_loops()
	twinkle.tween_property(glint, "modulate:a", 0.0, 0.6).set_delay(beat * 1.5)
	twinkle.tween_property(glint, "modulate:a", 1.0, 0.25)
	return root


## The shadow a pickup lies on: a soft dark lozenge, a little narrower than
## the half-size icon, made once.
static var _shadow_texture: Texture2D


static func _pickup_shadow() -> Texture2D:
	if _shadow_texture == null:
		var image := Image.create(6, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0.28))
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 1), Vector2i(5, 1)]:
			image.set_pixelv(corner, Color(0, 0, 0, 0.12))
		_shadow_texture = ImageTexture.create_from_image(image)
	return _shadow_texture


## Deals day `day`'s wild patches (PIX-250), unless they're dealt already;
## whether they changed.
static func deal_patches(view: MapView, day: int) -> bool:
	if view.patch_decks.is_empty() or day == view.patch_day:
		return false
	view.patch_day = day
	view.patches = Gathering.patches_on(view.patch_decks, day)
	# Nothing grows under what the Post's routes put up (PIX-322).
	for cell: Vector2i in view.routes["blocks"]:
		view.patches.erase(cell)
	# A healed lamp's morning find, picked as a patch is (PIX-324).
	view.patches.merge(Lamps.finds(Lamps.now(view.data.id), day), true)
	return true


## Patches that have grown back show again; when the day turns while the
## hero is here, yesterday's go and the new day's grow elsewhere (PIX-250).
static func refresh_patches(view: MapView) -> void:
	if deal_patches(view, Gathering.day_of(GameState.world.steps)):
		for spot_id: String in view.patch_sprites:
			view.patch_sprites[spot_id].queue_free()
		view.patch_sprites = {}
		for cell: Vector2i in view.patches:
			_add_patch_sprite(view, cell)
	for spot_id: String in view.patch_sprites:
		view.patch_sprites[spot_id].visible = Gathering.is_ready(GameState.world, spot_id)


## The post box drawn as it stands (PIX-320): full, its pennant up and a
## letter in its slot, while it holds the day's post; empty once it's taken
## (or while the threads wait). Looked at again each second and as E takes
## the post. The waystations' boxes too (PIX-322), the same day's post in
## each. Nothing on a map without a box.
static func show_post_box(view: MapView) -> void:
	var boxes: Array[Sprite2D] = view.post_boxes.duplicate()
	boxes.append(view.post_box)
	var full := not GameState.posting.in_box().is_empty()
	for box: Sprite2D in boxes:
		if box != null and is_instance_valid(box):
			box.texture = HamletArt.texture("post_box_full" if full else "post_box")
