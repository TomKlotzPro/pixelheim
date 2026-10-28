extends SceneTree
## The prep pass that turns GegX's Pixel UI Kit into UiStyle's pieces (PIX-385).
## The kit can't be used raw: its buttons carry baked labels, few of its
## columns repeat cleanly and its palette (near-black, maroon, plum) isn't
## ours. For each piece assets/puny/ui_kit.json names, this remaps every
## colour onto UiStyle's ramps, cuts clean nine slices (which leaves the label
## out) and writes the piece at 1x. Its art is paid and may not be
## redistributed, modified or not: write it outside this repo and keep it in
## the private pixelheim-assets repo (retro-rpg/gegx/pixel-ui-kit/pixelheim/).
##
##   godot --headless --audio-driver Dummy --path godot -s tools/ui_kit_prep.gd -- <kit> <out>
##
## <kit> is retro-rpg/gegx/pixel-ui-kit/ in a checkout of the private repo.

const MANIFEST := "res://assets/puny/ui_kit.json"
## The families a kit colour can belong to, each a ramp from dark to light.
const FAMILIES: Array[String] = ["night", "wood", "brass", "page"]
## A run copied to at least this many pixels, so a piece's middle is wide
## enough to read.
const WIDEN := 8
## The longest run the cut tries.
const LONGEST := 48


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: godot --headless --path godot -s tools/ui_kit_prep.gd -- <kit> <out>")
		quit(2)
		return
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))["pieces"]
	DirAccess.make_dir_recursive_absolute(args[1])
	var sources := {}
	for piece: Dictionary in pieces.values():
		var img := Image.load_from_file(args[0].path_join(piece["source"]))
		if img == null:
			printerr("no %s in %s" % [piece["source"], args[0]])
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		if piece.has("crop"):
			var c := ints(piece["crop"])
			img = img.get_region(Rect2i(c[0], c[1], c[2], c[3]))
		sources[_key(piece)] = img
	# Each style's own spread of each family: its plum frame takes the whole
	# wood ramp as the wood style's maroon does.
	var by_style := {}
	for piece: Dictionary in pieces.values():
		var style: String = piece["source"].get_slice("/", 0)
		if not by_style.has(style):
			by_style[style] = []
		by_style[style].append(sources[_key(piece)])
	var spans := {}
	for style: String in by_style:
		spans[style] = spans_of(by_style[style])
	var failed := false
	for name: String in pieces:
		var piece: Dictionary = pieces[name]
		var img: Image = sources[_key(piece)]
		var span: Dictionary = spans[piece["source"].get_slice("/", 0)]
		var m := ints(piece["margins"])
		# A pressed piece's margins are the dropped face's: cut it as drawn.
		var drop := int(piece.get("drop", 0))
		var drawn := [m[0], m[1] - drop, m[2], m[3] + drop]
		# The runs come from the plain remap, so every state is cut alike.
		var runs := runs_of(remapped(img, span), drawn, ints(piece.get("label", [])), int(piece.get("shortest_run", 1)))
		var out := assemble(remapped(img, span, piece.get("ramps", {}), int(piece.get("shift", 0))), drawn, runs)
		out = dropped(out, drop)
		var stray := stray_in_middle(out, m)
		out.save_png(args[1].path_join(piece["file"]))
		print("%s: %dx%d from %s, columns %d+%d, rows %d+%d, %d colours%s" % [
			name, out.get_width(), out.get_height(), piece["source"], runs[0].x, runs[0].y,
			runs[1].x, runs[1].y, colours(out), "" if stray == 0 else ", %d pixels not page in the middle" % stray])
		failed = failed or stray > 0
	quit(1 if failed else 0)


## JSON's numbers as ints.
static func ints(values: Array) -> Array:
	return values.map(func(v: float) -> int: return int(v))


static func _key(piece: Dictionary) -> String:
	return "%s %s" % [piece["source"], piece.get("crop", [])]


## A ramp of UiStyle's colours, dark to light, by name: the four families a
## kit colour falls in, and the accents a colourway draws a family on.
static func ramp(name: String) -> Array[Color]:
	var ui := palette()
	match name:
		"night":
			return [ui["NIGHT"]]
		"wood":
			return [ui["WOOD_DARK"], ui["WOOD"], ui["WOOD_LIGHT"]]
		"brass":
			return [ui["BRASS_DARK"], ui["BRASS"], ui["BRASS_LIGHT"]]
		"page":
			return [ui["RIM"], ui["CARD"], ui["WINDOW"], ui["CREAM"]]
		"lamp":
			return _around(ui["LAMP"])
		"fine":
			return _around(ui["FINE"])
		"epic":
			return _around(ui["EPIC"])
	push_error("no ramp %s" % name)
	return []


static var _palette := {}


## UiStyle's colour constants by name, read from its source: loading the
## script itself needs the GameState autoload, which a -s run compiles without.
static func palette() -> Dictionary:
	if _palette.is_empty():
		var constant := RegEx.create_from_string('const (\\w+) := Color\\("(\\w+)"\\)')
		for found in constant.search_all(FileAccess.get_file_as_string("res://scripts/ui_style.gd")):
			_palette[found.get_string(1)] = Color(found.get_string(2))
	return _palette


static func _around(accent: Color) -> Array[Color]:
	return [accent.darkened(0.4), accent, accent.lightened(0.3)]


## The family whose ramp holds the colour nearest `c`: the kit's maroon and
## plum land on wood, its near-black on night, its gold on brass, its cream on
## the page.
static func family_of(c: Color) -> String:
	var best := ""
	var nearest := INF
	for family in FAMILIES:
		for tone in ramp(family):
			var d := Vector3(c.r - tone.r, c.g - tone.g, c.b - tone.b).length_squared()
			if d < nearest:
				nearest = d
				best = family
	return best


## Each family's darkest and lightest luminance across `images`.
static func spans_of(images: Array) -> Dictionary:
	var spans := {}
	for img: Image in images:
		for c in colour_set(img):
			var family := family_of(c)
			var l: float = c.get_luminance()
			var span: Vector2 = spans.get(family, Vector2(l, l))
			spans[family] = Vector2(minf(span.x, l), maxf(span.y, l))
	return spans


## One colour on UiStyle's ramps: its family's ramp (or the one `ramps` draws
## that family on), the tone its luminance reaches within the family's span,
## `shift` tones lighter (or darker), clamped to the ramp. Alpha is kept.
static func on_ramps(c: Color, spans: Dictionary, ramps := {}, shift := 0) -> Color:
	if c.a == 0.0:
		return c
	var family := family_of(c)
	var tones := ramp(ramps.get(family, family))
	var span: Vector2 = spans.get(family, Vector2(0.0, 1.0))
	var t := 0.0 if span.y <= span.x else clampf((c.get_luminance() - span.x) / (span.y - span.x), 0.0, 1.0)
	var out := tones[clampi(roundi(t * (tones.size() - 1)) + shift, 0, tones.size() - 1)]
	out.a = c.a
	return out


static func remapped(img: Image, spans: Dictionary, ramps := {}, shift := 0) -> Image:
	var out := img.duplicate() as Image
	var done := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if not done.has(c):
				done[c] = on_ramps(c, spans, ramps, shift)
			out.set_pixel(x, y, done[c])
	return out


static func colour_set(img: Image) -> Array:
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				seen[c] = true
	return seen.keys()


static func colours(img: Image) -> int:
	return colour_set(img).size()


## The columns, then the rows, the cut repeats between the margins `m`
## (left, top, right, bottom): [Vector2i(first column, count), Vector2i(first
## row, count)]. The columns keep clear of `label` ([first, past last]).
static func runs_of(img: Image, m: Array, label: Array, shortest: int) -> Array[Vector2i]:
	var w := img.get_width()
	var h := img.get_height()
	var cols := best_run(lines(img, true, range(h)), m[0], w - m[2], label, shortest)
	var used := range(m[0]) + range(cols.x, cols.x + cols.y) + range(w - m[2], w)
	var rows := best_run(lines(img, false, used), m[1], h - m[3], [], shortest)
	return [cols, rows]


## Every column (or row) of `img` as colours, read at `across` only.
static func lines(img: Image, columns: bool, across: Array) -> Array[PackedColorArray]:
	var out: Array[PackedColorArray] = []
	for i in (img.get_width() if columns else img.get_height()):
		var line := PackedColorArray()
		for j: int in across:
			line.append(img.get_pixel(i, j) if columns else img.get_pixel(j, i))
		out.append(line)
	return out


## The run of `lines` in [lo, hi) that repeats most cleanly, as
## Vector2i(start, count): the line after it matches its first, so its copies
## join as the art did, and its lines change least from one to the next, so a
## speck doesn't come back every few pixels. Fewest mismatches wins, then the
## longest run, then the first; none overlaps `skip` ([first, past last]).
static func best_run(lines_in: Array[PackedColorArray], lo: int, hi: int, skip: Array, shortest: int) -> Vector2i:
	# changes[i]: how much the lines change from lo up to line i.
	var changes := PackedInt32Array([0])
	for i in range(lo, hi):
		changes.append(changes[-1] + differ(lines_in[i], lines_in[i + 1]))
	var best := Vector2i(lo, mini(shortest, hi - lo))
	var least := 1 << 30
	for count in range(mini(shortest, hi - lo), mini(LONGEST, hi - lo) + 1):
		for start in range(lo, hi - count + 1):
			if not skip.is_empty() and start < int(skip[1]) and start + count > int(skip[0]):
				continue
			var score := differ(lines_in[start], lines_in[start + count]) \
					+ changes[start + count - 1 - lo] - changes[start - lo]
			if score < least or (score == least and count > best.y):
				least = score
				best = Vector2i(start, count)
	return best


static func differ(a: PackedColorArray, b: PackedColorArray) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n


## The piece rebuilt from its corners and edges' ends as drawn, the runs
## copied between them to at least WIDEN pixels.
static func assemble(img: Image, m: Array, runs: Array[Vector2i]) -> Image:
	var mid := Vector2i(_widened(runs[0].y), _widened(runs[1].y))
	var size := Vector2i(int(m[0]) + mid.x + int(m[2]), int(m[1]) + mid.y + int(m[3]))
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var sy := _from(y, int(m[1]), mid.y, runs[1], img.get_height() - size.y)
		for x in size.x:
			out.set_pixel(x, y, img.get_pixel(_from(x, int(m[0]), mid.x, runs[0], img.get_width() - size.x), sy))
	return out


static func _widened(count: int) -> int:
	return count * ceili(float(WIDEN) / count) if count < WIDEN else count


## The source line for output line `i`: the first margin as drawn, then the
## run over and over, then the far margin as drawn (`grow` from source to out).
static func _from(i: int, margin: int, mid: int, run: Vector2i, grow: int) -> int:
	if i < margin:
		return i
	if i < margin + mid:
		return run.x + (i - margin) % run.y
	return i + grow


## The piece pressed: everything `by` pixels lower, its last rows gone.
static func dropped(img: Image, by: int) -> Image:
	if by <= 0:
		return img
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height() - by), Vector2i(0, by))
	return out


## Pixels between the margins that aren't the page's: a label left behind, a
## stain or a bolt the cut carried in. Zero for every clean piece.
static func stray_in_middle(img: Image, m: Array) -> int:
	var n := 0
	for y in range(int(m[1]), img.get_height() - int(m[3])):
		for x in range(int(m[0]), img.get_width() - int(m[2])):
			if family_of(img.get_pixel(x, y)) != "page":
				n += 1
	return n
