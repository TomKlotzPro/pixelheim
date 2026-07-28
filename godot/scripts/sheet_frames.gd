class_name SheetFrames
## Shared builders for SpriteFrames from horizontal strip sheets. Two sheet
## families exist:
## - Pixelheim generated sheets: uniform square frames (16px, or 64px hero)
## - Pixel Crawler mob sheets: mixed canvas sizes (32/48/64) that all anchor
##   the body's feet to the bottom edge — normalized to 48x48 so animations
##   don't jump when they switch.


static func add_strip(
	frames: SpriteFrames, anim: String, path: String, fps: float, loop: bool, frame_size := 16
) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var texture: Texture2D = load(path)
	for i in int(texture.get_width() / float(frame_size)):
		frames.add_frame(anim, frame_at(path, i, frame_size))


static func frame_at(path: String, index: int, frame_size := 16) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = load(path)
	frame.region = Rect2(index * frame_size, 0, frame_size, frame_size)
	return frame


static func add_normalized_strip(
	frames: SpriteFrames, anim: String, path: String, fps: float, loop: bool
) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var texture: Texture2D = load(path)
	var frame_size := texture.get_height()
	for i in int(texture.get_width() / float(frame_size)):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		match frame_size:
			32:
				frame.region = Rect2(i * 32, 0, 32, 32)
				frame.margin = Rect2(8, 16, 16, 16)
			48:
				frame.region = Rect2(i * 48, 0, 48, 48)
			_:
				frame.region = Rect2(i * frame_size + 8, frame_size - 48, 48, 48)
		frames.add_frame(anim, frame)
