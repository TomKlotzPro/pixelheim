class_name Dissolve
extends TextureRect
## A door's dissolve (One Reach, PIX-269; Tom: "crossing is a cut"). The
## screen as it stood the moment the hero went through is held over the new
## map and fades out of it in a quarter of a second: the old place melts
## into the new one with no black between. The picture is the last frame
## drawn, read back once (on the desktop's linear canvas it stays in linear
## light, sixteen bits a channel, and is drawn back as it was read).
## It runs on while the world is paused (the town's tour pauses a frame
## after the town is redrawn), and the frame the new map is built in, a
## hitch of a tenth of a second or more, counts as one ordinary frame:
## otherwise the first half of the dissolve would pass unseen in the hitch.

const SECONDS := 0.25
## The longest frame the dissolve counts (a 30 Hz frame).
const LONGEST_FRAME := 1.0 / 30.0
## Its canvas layer: over the world and the HUD (the HUD is in the picture
## too, the same before and after), under conversations and screens opened
## on arrival.
const LAYER := 3

## A harness run's shot of a dissolve half done (`--dissolve-at`): every
## dissolve stops this many seconds in; -1 lets them run.
static var held_at := -1.0

var elapsed := 0.0


## How much of the old picture still shows `elapsed` seconds in: all of it
## at first, none at the end, easing out of the old and into the new.
static func shown(at: float, length := SECONDS) -> float:
	return 1.0 - smoothstep(0.0, length, at)


## The screen as it stands, on a layer of its own over `world`, ready to
## fade out over whatever is built under it; null where nothing is drawn (a
## quiet run has no picture to hold).
static func hold(world: Node) -> Dissolve:
	if DisplayServer.get_name() == "headless":
		return null
	var image := world.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var picture := Dissolve.new()
	picture.texture = ImageTexture.create_from_image(image)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = Touch.view_size(world)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(picture)
	world.add_child(layer)
	return picture


func _process(delta: float) -> void:
	elapsed += minf(delta, LONGEST_FRAME)
	if held_at >= 0.0:
		elapsed = minf(elapsed, held_at)
	modulate.a = shown(elapsed)
	if held_at >= 0.0:
		return
	if elapsed >= SECONDS:
		get_parent().queue_free()
