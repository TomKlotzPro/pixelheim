class_name Ink
## Where the pixels are (PIX-268): the ink a word draws in a pixel font and
## the head a figure's frame draws, measured on the pixels themselves, so a
## mark over a head is centred on the one by the other. A Label's box can't
## be trusted for it: it draws its words from its left edge with the face's
## spacing after them (a pixel past the "!"), and measured before the label is
## in the tree, the box is the fallback font's at twice the size (its theme
## overrides only apply in the tree). Centred on that box, Tom's "!" sat a
## pixel left of a villager's head, a "?" three, and a damage number five or
## so left of the foe.

## Each glyph's ink from its pen on the baseline, by font, size and glyph;
## each frame's head from the frame's centre; the sheets they were read off
## (fetched once each: a texture's image is a copy back from the screen).
static var _glyphs := {}
static var _heads := {}
static var _sheets := {}


## The pixels `text` draws in `font` at `size`, from where a Label draws it:
## x from its left edge, y from its top (the baseline at the line's ascent).
## Empty for text that draws nothing.
static func of_text(text: String, font: Font, size: int) -> Rect2:
	var server := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(text, font, size)
	var pen := Vector2(0.0, line.get_line_ascent())
	var drawn := Rect2()
	var found := false
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		for i in int(glyph["repeat"]):
			var ink := _glyph(glyph["font_rid"], int(glyph["font_size"]), int(glyph["index"]))
			if ink.has_area():
				var at := Rect2(ink.position + pen + (glyph["offset"] as Vector2), ink.size)
				drawn = drawn.merge(at) if found else at
				found = true
			pen.x += float(glyph["advance"])
	return drawn


## One glyph's ink from its pen on the baseline, read off the font's own
## rendering of it (the pixel faces are drawn at their size and scaled whole,
## so the cache's pixels scale to the quad drawn).
static func _glyph(font: RID, size: int, index: int) -> Rect2:
	var key := "%d %d %d" % [font.get_id(), size, index]
	if _glyphs.has(key):
		return _glyphs[key]
	var ink := Rect2()
	var server := TextServerManager.get_primary_interface()
	var at := Vector2i(size, 0)
	var page := server.font_get_glyph_texture_idx(font, at, index) if font.is_valid() else -1
	if page >= 0:
		var cut := Rect2i(server.font_get_glyph_uv_rect(font, at, index))
		var used := server.font_get_texture_image(font, at, page).get_region(cut).get_used_rect()
		if used.has_area():
			var scale := server.font_get_glyph_size(font, at, index) / Vector2(cut.size)
			ink = Rect2(server.font_get_glyph_offset(font, at, index) + Vector2(used.position) * scale, Vector2(used.size) * scale)
	_glyphs[key] = ink
	return ink


## The head `anim`'s first frame draws, as a centred sprite at `at` and
## `scale` draws it: the figure's top PunyArt.HEAD_ROWS drawn rows (a figure
## holding something out at its side is still centred by its head).
static func head(frames: SpriteFrames, anim: String, at := Vector2.ZERO, scale := Vector2.ONE) -> Rect2:
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		return Rect2(at, Vector2.ZERO)
	var drawn := _head(frames.get_frame_texture(anim, 0))
	return Rect2(at + drawn.position * scale, drawn.size * scale)


## The highest a figure's head reaches in any frame of `anims` (a breath in,
## a walk's rise), as a centred sprite at `at` and `scale` draws it: a mark
## standing over it never touches it.
static func crown(frames: SpriteFrames, anims: Array, at := Vector2.ZERO, scale := Vector2.ONE) -> float:
	var top := INF
	for anim: String in anims:
		if not frames.has_animation(anim):
			continue
		for i in frames.get_frame_count(anim):
			var drawn := _head(frames.get_frame_texture(anim, i))
			if drawn.has_area():
				top = minf(top, at.y + drawn.position.y * scale.y)
	return top if top != INF else at.y


## The head in one frame, from the frame's centre.
static func _head(frame: Texture2D) -> Rect2:
	if _heads.has(frame):
		return _heads[frame]
	var image: Image
	if frame is AtlasTexture:
		var cut := frame as AtlasTexture
		if not _sheets.has(cut.atlas):
			_sheets[cut.atlas] = cut.atlas.get_image()
		image = (_sheets[cut.atlas] as Image).get_region(Rect2i(cut.region))
	else:
		image = frame.get_image()
	var used := image.get_used_rect()
	var drawn := Rect2()
	if used.has_area():
		var rows := mini(PunyArt.HEAD_ROWS, used.size.y)
		var top := image.get_region(Rect2i(0, used.position.y, image.get_width(), rows)).get_used_rect()
		drawn = Rect2(Vector2(top.position.x, used.position.y + top.position.y) - frame.get_size() / 2.0, top.size)
	_heads[frame] = drawn
	return drawn


## The idle pose facing the way `anim` faces (a walk's frames bob and lean;
## its rest doesn't), or `anim` itself when it faces no way.
static func rest_pose(frames: SpriteFrames, anim: String) -> String:
	var way := anim.get_slice("_", anim.get_slice_count("_") - 1)
	return PunyArt.pick(frames, "idle", way) if way in PunyArt.DIRS else anim


## Where to put what draws `ink` (in its own space) so its ink is centred on
## `centre`, in whole pixels: a half pixel over when the two can't line up
## (an even mark on an odd head), always the same way.
static func centred(ink: Rect2, centre: float) -> float:
	return floorf(centre - ink.get_center().x + 0.5)
