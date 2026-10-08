class_name PunyProps
## What stands on the outdoor ground, in Shade's Puny World Medieval Age
## (PIX-137): the roofed well, the square's fountain, torches for the web's
## lamps, a stone knight for the shrine, barrels, crates, market crates for
## the stalls, chests, flowers, and log fences joined to their neighbours.
## Pure: each prop is its tiles and the box its foot takes, so world.gd can
## y-sort it among the actors and stop the hero where the art stands.
## The pack is paid and private (PunyTown); without it the old props stay.
##
## A foot always covers the middle of the bottom of each cell it blocks
## (x 4..12, y 7..15 of the cell): the hero's feet are a 10x8 box 3 px below
## their position, so that position, and the cell the world reads from it,
## can never be inside a blocked cell.

## Props by the web's tile. Offsets are cells from the prop's cell; a foot is
## in pixels from that cell's top-left corner.
const LAMP_FRAMES := [151, 152, 153, 154, 155, 156, 157]
## The same torch, cold: the lamps by day (PIX-149).
const LAMP_UNLIT := 150
const LAMP_FPS := 8.0
const WELL := [[Vector2i(0, -2), 3007], [Vector2i(1, -2), 3008], [Vector2i(0, -1), 3227], [Vector2i(1, -1), 3228], [Vector2i(0, 0), 3447], [Vector2i(1, 0), 3448]]
const SMALL_WELL := 3444
## The fountain's basin (2x2); world.gd fills it with water and a jet
## (fountain_frames).
const BASIN := [[Vector2i(0, 0), 3225], [Vector2i(1, 0), 3226], [Vector2i(0, 1), 3445], [Vector2i(1, 1), 3446]]
const BARREL := 136
const CRATE := 1024
## Market crates for the web's stalls (a counter and the crate or barrel
## beside it): [left end, right end] of a run, greens, reds or wheat; a
## lone counter gets one crate.
const STALLS := [[1241, 1243], [1461, 1463], [1681, 1683]]
const STALL_SINGLE := 1236
## The shrine's stone knight comes from the CC0 Puny Dungeon sheet.
const STATUE := 491
const FLOWERS := [2656, 2657, 2658, 2659]
const CHEST := 355
const CHEST_OPEN := 356
## Ground treasure: a dropped pouch on the road, wild herbs in the grass.
const POUCH := 2120
const HERB := 1689

## Log fence by which neighbours are fence too (N=1, E=2, S=4, W=8).
const FENCE := {
	0: 4303, 1: 4083, 2: 4304, 3: 4084, 4: 3643, 5: 3863, 6: 3644, 7: 3864,
	8: 4306, 9: 4086, 10: 4305, 11: 4085, 12: 3646, 13: 3866, 14: 3645, 15: 3865,
}

## Feet, in pixels from the cell's top-left.
const LAMP_FOOT := Rect2(4, 7, 8, 9)
const STATUE_FOOT := Rect2(3, 6, 10, 10)
const BARREL_FOOT := Rect2(2, 5, 12, 11)
const CRATE_FOOT := Rect2(1, 4, 14, 12)
const SMALL_WELL_FOOT := Rect2(1, 3, 14, 13)
const WELL_FOOT := Rect2(2, 0, 28, 16)
const BASIN_FOOT := Rect2(3, 4, 26, 28)
const STALL_FOOT := Rect2(0, 2, 32, 14)
const CHEST_FOOT := Rect2(1, 3, 14, 13)

const BLOCKS := ["lamp", "well", "shrine", "barrel", "crate", "counter", "fence"]


static func available() -> bool:
	return PunyTown.available()


## Every prop on an outdoor map, with what it covers:
## {"props": [{"kind", "cell", "tiles": [[offset, tile]], "sheet",
##   "frames", "foot": Rect2 (no size: walk through), "covers": [cells]}],
##  "flat": {cell: tile} (flowers, drawn on the ground under everyone),
##  "drawn": {cell: true} (web prop cells these replace)}.
## Empty when the pack is missing.
static func compose(grid: Dictionary) -> Dictionary:
	if not available():
		return {"props": [], "flat": {}, "drawn": {}}
	return plan(grid)


## The props as tile ids, whether or not the pack is here to draw them (what
## the tests check).
static func plan(grid: Dictionary) -> Dictionary:
	var props: Array = []
	var flat := {}
	var drawn := {}
	var taken := {}  # cells a bigger prop already stands on
	var cells: Array = grid.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		if taken.has(cell):
			continue
		var tile: String = grid[cell]
		var prop := {}
		match tile:
			"lamp":
				prop = _prop("lamp", cell, [[Vector2i.ZERO, LAMP_FRAMES[0]]], LAMP_FOOT)
				prop["frames"] = LAMP_FRAMES
			"shrine":
				prop = _prop("shrine", cell, [[Vector2i.ZERO, STATUE]], STATUE_FOOT)
				prop["sheet"] = "dungeon"
			"barrel":
				prop = _prop("barrel", cell, [[Vector2i.ZERO, BARREL]], BARREL_FOOT)
			"crate":
				prop = _prop("crate", cell, [[Vector2i.ZERO, CRATE]], CRATE_FOOT)
			"well":
				prop = _well(grid, cell)
			"counter":
				prop = _stall(grid, cell, props.filter(func(p: Dictionary) -> bool: return p["kind"] == "stall").size())
			"fence":
				prop = _prop("fence", cell, [[Vector2i.ZERO, FENCE[_mask(grid, cell, "fence")]]], _fence_foot(grid, cell))
			"flowers":
				flat[cell] = FLOWERS[absi(cell.x * 7 + cell.y * 13) % FLOWERS.size()]
				drawn[cell] = true
		if prop.is_empty():
			continue
		props.append(prop)
		for covered: Vector2i in prop["covers"]:
			taken[covered] = true
			drawn[covered] = true
	return {"props": props, "flat": flat, "drawn": drawn}


static func _prop(kind: String, cell: Vector2i, tiles: Array, foot: Rect2) -> Dictionary:
	return {"kind": kind, "cell": cell, "tiles": tiles, "sheet": "medieval", "frames": [], "foot": foot, "covers": [cell]}


## A well standing in paving all round is the square's fountain (tier 3's
## centrepiece): a 2x2 basin when the paving reaches round it. Elsewhere the
## roofed well, two cells wide when the cell to its right is free ground;
## else the small stone well.
static func _well(grid: Dictionary, cell: Vector2i) -> Dictionary:
	var paved := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].all(
		func(step: Vector2i) -> bool: return grid.get(cell + step, "") == "path"
	)
	var room := func(cells: Array, ground: Array) -> bool:
		return cells.all(func(c: Vector2i) -> bool: return grid.get(c, "") in ground)
	if paved and room.call([cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)], ["path"]):
		var fountain := _prop("fountain", cell, BASIN, BASIN_FOOT)
		fountain["covers"] = [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]
		return fountain
	if not paved and room.call([cell + Vector2i(1, 0)], ["grass"]):
		var well := _prop("well", cell, WELL, WELL_FOOT)
		well["covers"] = [cell, cell + Vector2i(1, 0)]
		return well
	return _prop("well", cell, [[Vector2i.ZERO, SMALL_WELL]], SMALL_WELL_FOOT)


## A stall: the counter and the crate or barrel beside it become one run of
## market crates; a lone counter, one crate. `index` turns the produce.
static func _stall(grid: Dictionary, cell: Vector2i, index: int) -> Dictionary:
	var beside: String = grid.get(cell + Vector2i.RIGHT, "")
	if beside == "crate" or beside == "barrel":
		var run: Array = STALLS[index % STALLS.size()]
		var stall := _prop("stall", cell, [[Vector2i.ZERO, run[0]], [Vector2i.RIGHT, run[1]]], STALL_FOOT)
		stall["covers"] = [cell, cell + Vector2i.RIGHT]
		return stall
	return _prop("stall", cell, [[Vector2i.ZERO, STALL_SINGLE]], CRATE_FOOT)


static func _mask(grid: Dictionary, cell: Vector2i, tile: String) -> int:
	var mask := 0
	for bit: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
		if grid.get(cell + bit[0], "") == tile:
			mask |= bit[1]
	return mask


## A fence's foot: the post in the middle, reaching each side it joins.
static func _fence_foot(grid: Dictionary, cell: Vector2i) -> Rect2:
	var mask := _mask(grid, cell, "fence")
	var left := 0.0 if mask & 8 else 4.0
	var right := 16.0 if mask & 2 else 12.0
	var top := 0.0 if mask & 1 else 6.0
	return Rect2(left, top, right - left, 16.0 - top)


## A chest or ground treasure, as the web draws it (chestSpriteName): the
## tile, or -1 when nothing is left to see.
static func treasure_tile(look: String, opened: bool) -> int:
	if look == "chest":
		return CHEST_OPEN if opened else CHEST
	if opened:
		return -1
	return POUCH if look == "glint" else HERB


## The fountain, drawn once from the basin: its pit filled with the pack's
## water, a stone pedestal in the middle and a jet in three frames, 32x40
## (the jet rises a half tile above the basin).
static func fountain_frames() -> Array[ImageTexture]:
	var atlas: Image = (load(PunyTown.SHEET) as Texture2D).get_image()
	atlas.convert(Image.FORMAT_RGBA8)
	var basin := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for piece: Array in BASIN:
		var tile: int = piece[1]
		var from := Vector2i((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16)
		basin.blit_rect(atlas, Rect2i(from, Vector2i(16, 16)), piece[0] * 16)
	# The pit's shades become the pack's water, deep to light.
	var water := {"2e2036": Color("0b7f96"), "443438": Color("04a0b4"), "4e463c": Color("23c0bf")}
	for y in range(9, 24):
		for x in range(5, 27):
			var shade := basin.get_pixel(x, y).to_html(false)
			if water.has(shade):
				basin.set_pixel(x, y, water[shade])
	var light := Color("ceb47f")
	var mid := Color("b49969")
	var edge := Color("4e463c")
	var foam := Color("e8fbff")
	var spray := Color("8fe3ec")
	var deep := Color("1dcccb")
	var frames: Array[ImageTexture] = []
	for f in 3:
		var image := Image.create(32, 40, false, Image.FORMAT_RGBA8)
		image.blit_rect(basin, Rect2i(0, 0, 32, 32), Vector2i(0, 8))
		for y in range(21, 27):  # the pedestal
			for x in range(14, 18):
				image.set_pixel(x, y, edge if x == 14 or x == 17 or y == 26 else (light if x == 15 else mid))
		for x in range(13, 19):  # its lip
			image.set_pixel(x, 20, edge if x == 13 or x == 18 else light)
		var top := 6 + f % 2
		for y in range(top, 20):  # the jet, foaming at the top
			image.set_pixel(15, y, spray)
			image.set_pixel(16, y, foam if y < top + 3 else spray)
		image.set_pixel(14, top + 1, spray)
		image.set_pixel(17, top + 1, spray)
		var drops := [Vector2i(-4, 3), Vector2i(4, 3), Vector2i(-6, 7), Vector2i(6, 7), Vector2i(-7, 11), Vector2i(7, 11)]
		for i in drops.size():
			if (i + f) % 3 == 2:
				continue
			var drop: Vector2i = drops[i]
			image.set_pixel(16 + drop.x - (1 if drop.x < 0 else 0), top + drop.y + f, deep if i >= 4 else spray)
		frames.append(ImageTexture.create_from_image(image))
	return frames


static var _textures := {}
static var _animations := {}
static var _fountain: SpriteFrames


## One tile of the Medieval Age atlas as a texture (cached).
static func texture(tile: int) -> AtlasTexture:
	if not _textures.has(tile):
		var region := AtlasTexture.new()
		region.atlas = load(PunyTown.SHEET)
		region.region = Rect2((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16, 16, 16)
		_textures[tile] = region
	return _textures[tile]


## Tiles played in a loop (the torches' flames), cached per strip.
static func animation(tiles: Array, fps: float) -> SpriteFrames:
	var key := str(tiles)
	if not _animations.has(key):
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", fps)
		for tile: int in tiles:
			frames.add_frame("default", texture(tile))
		_animations[key] = frames
	return _animations[key]


## The fountain's three frames as an animation.
static func fountain_sprite_frames() -> SpriteFrames:
	if _fountain == null:
		_fountain = SpriteFrames.new()
		_fountain.set_animation_speed("default", 6.0)
		for frame: ImageTexture in fountain_frames():
			_fountain.add_frame("default", frame)
	return _fountain
