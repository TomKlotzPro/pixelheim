class_name FireArt
## areas: story town night
## The fires of a burning house (PIX-327): the Night of Ash's ruins and the
## Night of Bells' roofs. They were Shade's status flame, a 16 px icon, a
## handful to a house in a grid on the ash, each in a round glow with his
## burn marks floating over it: a field of lightbulbs. Now the flames are
## our own pixel art in his four fire colours (tools/fire.py draws them into
## assets/fire/: a lick, a tongue, a post's tall flame and a blaze, each in
## VARIANTS loops of FRAMES frames, whole art pixels, the tips breaking into
## flicks that climb), and they stand on what burns: along the burnt frame's
## beams and up its corner posts, on the rubble, a blaze where the house fell
## in, and on a standing house up its roof and out of its windows. Smoke,
## sparks and coals are drawn by shaders (shaders/fire_*.gdshader), the light
## by Lights.blaze. Pure: the plan needs no art, the frames only our own.

const TILE := 16
## The sheets' layout, as tools/fire.py draws them.
const FRAMES := 12
const VARIANTS := 3
const SHEET := "res://assets/fire/flame_%s.png"
## Each kind's frame, in art pixels.
const KINDS := {
	"lick": Vector2i(9, 13),
	"tongue": Vector2i(12, 20),
	"post": Vector2i(10, 26),
	"blaze": Vector2i(20, 34),
}
## Shade's fire colours, hottest first: what a frame may hold besides the
## clear.
const COLOURS: Array[Color] = [Color("ffffff"), Color("fbf236"), Color("df7126"), Color("ac3232")]
## The frames a second a flame plays at, and with Reduce motion: calmer.
const FPS := 12.0
const STILL_FPS := 4.0
## How far a flame stands off its cell's middle, either way, in pixels.
const JITTER := 3
## Where each thing burns from, in pixels down from its cell's top: a rail's
## top (the rail in front hides the flame's foot, so it climbs out of the
## log), a post's head, a crate's or a barrel's lid, a roof, a window's
## sill, the ash.
const RAIL_TOP := 6
const POST_TOP := 5
const RUBBLE_TOP := 6
const ROOF_AT := 10
const SILL := 11
const ASH_AT := 12
## A blaze for so many cells of a fallen house's floor.
const HEART_CELLS := 14
## How hard a beam burns, by a die: [below this, that flame] in order ("":
## burnt out to charcoal). A rail now and then flares as tall as a post; a
## side's posts burn lower.
const RAIL_HEAT := [[0.2, ""], [0.5, "lick"], [0.88, "tongue"], [1.0, "post"]]
const SIDE_HEAT := [[0.35, ""], [0.7, "lick"], [1.0, "tongue"]]
## How high over a house its sparks climb and its smoke rises, in pixels.
const SPARKS_ABOVE := 56
const SMOKE_ABOVE := 120


## The flames of a burning house over `rect` (cells), from what its cells
## are (`tiles`, cell -> the grid's tile: a ruin's "fence", "crate",
## "barrel" and "ash", a standing house's "roof", and "window" where its
## front has one): [{at, sort, kind, variant, frame, cell, on}]. `at` is the
## flame's foot in map pixels, `sort` the line it is drawn in front of
## (y-sorted with the actors), both whole pixels; `on` says what burns: a
## "rail", a "side"'s posts, a corner "post", "rubble", the "heart" where the
## house fell in, a "roof" or a "window".
static func plan(rect: Rect2i, tiles: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var front := float(rect.end.y * TILE + 1)
	var floor_cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var top := Vector2(cell * TILE)
			var below := top.y + TILE + 1
			match String(tiles.get(cell, "")):
				"fence":
					var across := _is(tiles, cell + Vector2i.LEFT, "fence") or _is(tiles, cell + Vector2i.RIGHT, "fence")
					var along := _is(tiles, cell + Vector2i.UP, "fence") or _is(tiles, cell + Vector2i.DOWN, "fence")
					if across and along:
						# A corner post: its own tall flame on its head.
						out.append(_flame(top + Vector2(8, POST_TOP), below, "post", cell, "post"))
					elif across:
						# Along a rail, the rail before their feet: here it
						# roars, there it licks, and here and there it has
						# burnt out to charcoal; now and then a lick at a
						# joint.
						var kind := _heat(cell, RAIL_HEAT)
						if kind != "":
							out.append(_flame(top + Vector2(8 + _jitter(cell, 1), RAIL_TOP), top.y + RAIL_TOP, kind, cell, "rail"))
						if _dice(cell, 2) < 0.3 and _is(tiles, cell + Vector2i.RIGHT, "fence"):
							out.append(_flame(top + Vector2(TILE, RAIL_TOP - 1), top.y + RAIL_TOP - 1, "lick", cell, "rail"))
					else:
						# Down a side: the posts burning, in front of them.
						var kind := _heat(cell, SIDE_HEAT)
						if kind != "":
							out.append(_flame(top + Vector2(8, ASH_AT - 2), below, kind, cell, "side"))
				"crate":
					out.append(_flame(top + Vector2(8, RUBBLE_TOP), below, "tongue", cell, "rubble"))
				"barrel":
					out.append(_flame(top + Vector2(8, RUBBLE_TOP + 1), below, "lick", cell, "rubble"))
				"roof":
					# Along the ridge it roars; down the slope it licks.
					var ridge := not _is(tiles, cell + Vector2i.UP, "roof")
					if ridge:
						var kind := "blaze" if _dice(cell, 5) < 0.35 else "tongue"
						out.append(_flame(top + Vector2(8 + _jitter(cell, 6), ROOF_AT), front, kind, cell, "roof"))
					elif _dice(cell, 7) < 0.45:
						var kind := "tongue" if _dice(cell, 8) < 0.5 else "lick"
						out.append(_flame(top + Vector2(8 + _jitter(cell, 9), ROOF_AT), front, kind, cell, "roof"))
				"window":
					out.append(_flame(top + Vector2(8, SILL), front, "tongue", cell, "window"))
				"ash":
					var edge := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
					if not edge:
						floor_cells.append(cell)
	# Where the house fell in: a blaze or two on its floor, spread across it
	# in the middle rows, and a lick here and there on the fallen timbers.
	if not floor_cells.is_empty():
		var hearts := maxi(1, floor_cells.size() / HEART_CELLS)
		var inner := rect.grow(-1)
		for i in hearts:
			var x := inner.position.x + int((i + 0.5) * inner.size.x / hearts)
			var y := inner.position.y + inner.size.y / 2
			var cell := _nearest(floor_cells, Vector2i(x, y))
			var foot := Vector2(cell * TILE) + Vector2(8 + _jitter(cell, 10), ASH_AT)
			out.append(_flame(foot, foot.y, "blaze", cell, "heart"))
		for cell: Vector2i in floor_cells:
			if _dice(cell, 11) < 0.14 and not out.any(func(flame: Dictionary) -> bool: return flame["cell"] == cell):
				var foot := Vector2(cell * TILE) + Vector2(8 + _jitter(cell, 12), ASH_AT)
				out.append(_flame(foot, foot.y, "lick", cell, "heart"))
	return out


## The animation of one kind of flame, cut from its sheet: FRAMES frames
## at FPS, looping. The same SpriteFrames for every flame of a kind and
## variant, so they draw from one texture.
static var _cache := {}


static func frames(kind: String, variant: int) -> SpriteFrames:
	var key := "%s:%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var sheet: Texture2D = load(SHEET % kind)
	var size: Vector2i = KINDS[kind]
	var out := SpriteFrames.new()
	out.set_animation_speed("default", FPS)
	out.set_animation_loop("default", true)
	for f in FRAMES:
		var cut := AtlasTexture.new()
		cut.atlas = sheet
		cut.region = Rect2(f * size.x, variant * size.y, size.x, size.y)
		out.add_frame("default", cut)
	_cache[key] = out
	return out


## How fast a flame plays against FPS: each a little its own, so flames side
## by side never beat together; with Reduce motion, calmer.
static func pace(flame: Dictionary, still: bool) -> float:
	var own := 0.85 + 0.3 * _dice(flame["cell"], 13 + int(flame["frame"]))
	return own * (STILL_FPS / FPS if still else 1.0)


## Where a fire's smoke and sparks stand over `rect` (cells), in map
## pixels: {smoke: Rect2, source: Vector2, sparks: Rect2, born: Vector2 (the
## sparks' first row and how deep they are born, in the quad), coals:
## Rect2}. Whole pixels; the smoke and the sparks lean downwind (east).
static func air(rect: Rect2i) -> Dictionary:
	var house := Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE))
	var smoke := Rect2(house.position + Vector2(-16, -SMOKE_ABOVE), Vector2(house.size.x + 64, SMOKE_ABOVE + house.size.y / 2.0))
	var sparks := Rect2(house.position + Vector2(-8, -SPARKS_ABOVE), Vector2(house.size.x + 32, SPARKS_ABOVE + house.size.y))
	return {
		"smoke": smoke,
		"source": Vector2(house.get_center().x, house.position.y + 4) - smoke.position,
		"sparks": sparks,
		"born": Vector2(SPARKS_ABOVE - 12, house.size.y - 4),
		"coals": house.grow(-TILE),
	}


static func _flame(at: Vector2, sort: float, kind: String, cell: Vector2i, on: String) -> Dictionary:
	return {
		"at": at.floor(), "sort": floorf(sort), "kind": kind, "cell": cell, "on": on,
		"variant": int(_dice(cell, 20) * VARIANTS) % VARIANTS,
		"frame": int(_dice(cell, 21) * FRAMES) % FRAMES,
	}


static func _is(tiles: Dictionary, cell: Vector2i, tile: String) -> bool:
	return String(tiles.get(cell, "")) == tile


static func _nearest(cells: Array[Vector2i], to: Vector2i) -> Vector2i:
	var best := cells[0]
	for cell in cells:
		if (cell - to).length_squared() < (best - to).length_squared():
			best = cell
	return best


## A fixed die for a cell (0..1), one for each `salt`: the same fire every
## time the map is drawn.
static func _dice(cell: Vector2i, salt: int) -> float:
	var n := (cell.x * 374761393 + cell.y * 668265263 + salt * 1442695041) & 0xFFFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65536.0


## The flame a beam's cell burns with, by HEAT's die ("" for none).
static func _heat(cell: Vector2i, heat: Array) -> String:
	var die := _dice(cell, 3)
	for step: Array in heat:
		if die < float(step[0]):
			return String(step[1])
	return String(heat[-1][1])


static func _jitter(cell: Vector2i, salt: int) -> int:
	return int(floorf(_dice(cell, salt) * (JITTER * 2 + 1))) - JITTER
