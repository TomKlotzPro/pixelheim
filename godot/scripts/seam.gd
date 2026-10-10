class_name Seam
## The lines between the Reach's maps (One Reach, PIX-269, steps 5 and 6).
## Tom found crossing a cut; the plane (ReachPlane) puts each map where its
## roads meet its neighbour's, and here is what joins two of them on screen:
## when the map past a road is drawn (Neighbours), when it is let go, where
## the hero lands across the line, what the ground looks like along it, and
## how often crossing saves. Pure: the drawing is MapView's, the walking the
## world's.
##
## Along a line both maps draw the same corner tiles, worked out from the
## cells on both sides: a road runs on into the road, a cliff stands in the
## sea. Each map draws the ground on past its edges (its pad, MapView
## .EDGE_PAD) as it lies there (KeptGround), the map beside it or the ridge
## (ReachPlane.RIDGE: rock, crowned, its cliffs standing in the sea where
## the sea meets it); where the other map is drawn its pad goes, and the
## forest that crowns a ridge stops where the rock under it meets something
## else across the line, so a cliff's rim faces open ground or the sea as it
## does inside a map.

## How near the hero must come to a road out, in cells either way, for the
## map past it to be drawn: about half a screen (at play zoom the world
## above the dock shows some 27 by 12 cells) and a few steps more, so a
## region (5 to 20 frames of 3 ms, PR #338) is drawn well before it shows.
const NEAR := Vector2i(20, 14)
## How far the hero walks from it before it's let go: a few seconds' walk
## past NEAR, so walking along the line doesn't draw and drop it again and
## again. It also stays while the view still shows any of it (Neighbours).
const FAR := Vector2i(30, 22)
## Crossing a line back and forth within this long saves once.
const SAVE_AGAIN_MS := 5000
## How many cells round a map its masks are laid with its neighbours'
## (the pad's four, and the region's soft edge reading two cells out). The
## ridge is never toned and holds no water.
const MASK_MARGIN := 6
## How far the ridge is drawn past what the camera may show, in cells.
const RIDGE_MARGIN := 16


## The roads out of `map` into the map beside it in the plane: [{"way" (a
## Ways.on way, kind "edge"), "to": the map's id, "offset": where that
## map's cell (0, 0) lies from this one's, in cells}]. None off the plane.
static func roads_out(map: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map.floor_level > 0 or not ReachPlane.holds(map.id):
		return out
	for way: Dictionary in Ways.on(map):
		var to := String(way["to"].get("mapId", ""))
		if way["kind"] != "edge" or not ReachPlane.holds(to):
			continue
		out.append({"way": way, "to": to, "offset": ReachPlane.origin(to) - ReachPlane.origin(map.id)})
	return out


## Whether `cell` is within `reach` cells (each way) of any of `way`'s cells.
static func near(cell: Vector2i, way: Dictionary, reach: Vector2i) -> bool:
	for at: Vector2i in way["cells"]:
		if absi(cell.x - at.x) <= reach.x and absi(cell.y - at.y) <= reach.y:
			return true
	return false


## Across the line from `map_id`: the map of the plane that holds `cell`
## (a cell of `map_id`'s, off its edge) and its cell there, {"map", "cell"};
## {} while it's still `map_id`'s own or the ridge's.
static func across(map_id: String, cell: Vector2i) -> Dictionary:
	if not ReachPlane.holds(map_id) or Rect2i(Vector2i.ZERO, ReachPlane.size_of(map_id)).has_point(cell):
		return {}
	var there := ReachPlane.at(ReachPlane.to_plane(map_id, cell))
	return there if there.get("map", map_id) != map_id else {}


## Whether a handover at `now` (ms) saves, the last one that did at `last`:
## crossing back and forth within SAVE_AGAIN_MS saves once (the autosave
## catches up with the rest).
static func saves(now: int, last: int) -> bool:
	return now - last >= SAVE_AGAIN_MS


## A cell of the plane's terrain, for the ground along a line: `grids` (map
## id -> its grid as drawn) looked up where a map lies, any other map's as
## its file has it, the ridge elsewhere.
static func tile_at(cell: Vector2i, grids: Dictionary) -> String:
	var at := ReachPlane.at(cell)
	if at.is_empty():
		return ReachPlane.RIDGE
	if not grids.has(at["map"]):
		return ReachPlane.tile(cell)
	return String((grids[at["map"]] as Dictionary).get(at["cell"], ReachPlane.RIDGE))


## What `map_id`'s ground and crowns change to beside `other_id` (both
## drawn), in `map_id`'s dual cells (corner (x, y) of its cells; `pad` past
## its edges): {cell: [ground, crown, rim]}, -1 none (the rim: a cliff
## standing in the water or a road, PunyTerrain.rimmed). A corner on the line both
## maps share is worked out from the cells on both sides, its variant picked
## by where it lies in the plane so both draw the same; the pad's corners
## inside the other map go; a corner inside the map near the line keeps its
## ground and has its crown worked out across the line. `grids`: map id ->
## its grid, for every map the line's corners touch (the ridge elsewhere);
## `kept`: `map_id`'s KeptGround. Only what differs from the kept ground.
static func stitch(map_id: String, other_id: String, grids: Dictionary, kept: KeptGround, pad: int) -> Dictionary:
	var out := {}
	var origin := ReachPlane.origin(map_id)
	var size := ReachPlane.size_of(map_id)
	var other := ReachPlane.rect_of(other_id)
	# The other map's corners, its edges' included (a rect of corners is one
	# wider than its cells).
	var other_corners := Rect2i(other.position, other.size + Vector2i.ONE)
	var own_corners := Rect2i(Vector2i.ZERO, size + Vector2i.ONE)
	# The zone: the other map's corners, and one more round them for the
	# crowns of this map's edge cells (rock is crowned by its four
	# neighbours, so only a cell on the edge sees across); within this map's
	# drawn corners.
	var zone := Rect2i(other_corners.position - origin, other_corners.size).grow(1) \
		.intersection(Rect2i(-Vector2i.ONE * pad, size + Vector2i.ONE * (1 + 2 * pad)))
	if not zone.has_area():
		return out
	# The plane's cells round the zone, their ground and whether the forest
	# crowns them, looked up once.
	var window := Rect2i(zone.position + origin, zone.size).grow(2)
	var tiles := {}
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			tiles[Vector2i(x, y)] = tile_at(Vector2i(x, y), grids)
	var terrain := {}
	var crowned := {}
	for cell: Vector2i in tiles:
		terrain[cell] = PunyTerrain.ground_of(tiles[cell])
		var rock: bool = tiles[cell] == "mountain"
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not rock:
				break
			rock = tiles.get(cell + step, ReachPlane.RIDGE) == "mountain"
		crowned[cell] = "trees" if rock else "air"
	var air := PunyTerrain.corner_tile(["air", "air", "air", "air"], 0)
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var cell := Vector2i(x, y)
			var plane := origin + cell
			var on_other := other_corners.has_point(plane)
			var own := own_corners.has_point(cell)
			var corner_tiles: Array
			if on_other and not own:
				corner_tiles = [-1, -1, -1]
			elif on_other:
				var rimmed := PunyTerrain.rimmed(_round(plane, terrain), hash(plane))
				corner_tiles = [rimmed[0], _crown(plane, crowned, hash(plane), air), rimmed[1]]
			elif own:
				corner_tiles = [kept.ground_at(cell), _crown(plane, crowned, hash(cell), air), kept.rim_at(cell)]
			else:
				continue
			if corner_tiles != [kept.ground_at(cell), kept.crown_at(cell), kept.rim_at(cell)]:
				out[cell] = corner_tiles
	return out


## What `cells` holds at the four cells round plane corner `corner`, top
## left first, clockwise (the order Shade's corner tiles read them in).
static func _round(corner: Vector2i, cells: Dictionary) -> Array:
	return [cells[corner + Vector2i(-1, -1)], cells[corner + Vector2i(0, -1)], cells[corner], cells[corner + Vector2i(-1, 0)]]


## The forest's crown at plane corner `corner` (-1 bare): rock walled in by
## rock on all four sides crowned, the ridge counting as rock.
static func _crown(corner: Vector2i, crowned: Dictionary, pick: int, air: int) -> int:
	var tile := PunyTerrain.corner_tile(_round(corner, crowned), pick)
	return -1 if tile == air else tile


## `image` (a map's mask, a cell a pixel) laid MASK_MARGIN cells out past
## its edges, and every map of `beside` (map id -> its mask) laid where it
## lies from `map_id` in the plane: the masks a map reads beside its
## neighbours. Where no map lies is the ridge, untoned, dry: a region's tone
## fades at its edge as it does inside a map, the same on both sides of a
## line, and the sea's foam laps at the ridge's cliffs. `image` null: a map
## of `size` with nothing in it (its pines never toned).
static func masks_beside(map_id: String, image: Image, beside: Dictionary, size := Vector2i.ZERO) -> Image:
	var m := MASK_MARGIN
	if image != null:
		size = image.get_size()
	var format := image.get_format() if image != null else (beside.values()[0] as Image).get_format()
	var out := Image.create(size.x + 2 * m, size.y + 2 * m, false, format)
	if image != null:
		out.blit_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i(m, m))
	for other_id: String in beside:
		var other: Image = beside[other_id]
		var at := ReachPlane.origin(other_id) - ReachPlane.origin(map_id) + Vector2i(m, m)
		var rect := Rect2i(at, other.get_size()).intersection(Rect2i(Vector2i.ZERO, out.get_size()))
		if rect.has_area():
			out.blit_rect(other, Rect2i(rect.position - at, rect.size), rect.position)
	return out


## The water of every map in `maps` (map id -> its water mask) laid out in
## the plane over the cells they cover together: {"image", "origin" (the
## plane cell at its first pixel)}, for the reflections.
static func water_beside(maps: Dictionary) -> Dictionary:
	var bounds := Rect2i()
	for map_id: String in maps:
		var rect := ReachPlane.rect_of(map_id)
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	var out := Image.create(maxi(1, bounds.size.x), maxi(1, bounds.size.y), false, Image.FORMAT_RG8)
	for map_id: String in maps:
		var image: Image = maps[map_id]
		out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), ReachPlane.origin(map_id) - bounds.position)
	return {"image": out, "origin": bounds.position}


## The cells the camera may show round `maps` (map ids): every one of them,
## as one rect of the plane.
static func bounds_of(maps: Array) -> Rect2i:
	var bounds := Rect2i()
	for map_id: String in maps:
		var rect := ReachPlane.rect_of(map_id)
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	return bounds


static var _ridge: ImageTexture


## The ridge between the maps, as drawn where the camera may look past them
## and no map lies: Shade's cliffs under a forest's crowns, four cells
## square, tiled (a few of his variants, so it doesn't read as a stamp).
static func ridge_texture() -> ImageTexture:
	if _ridge != null:
		return _ridge
	var sheet := (load(PunyTerrain.SHEET) as Texture2D).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var image := Image.create(4 * PunyTerrain.TILE, 4 * PunyTerrain.TILE, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			var pick := hash(Vector2i(x, y))
			var at := Vector2i(x, y) * PunyTerrain.TILE
			var rock := Rect2i(PunyTerrain.region(PunyTerrain.corner_tile(["cliff", "cliff", "cliff", "cliff"], pick)))
			var crown := Rect2i(PunyTerrain.region(PunyTerrain.corner_tile(["trees", "trees", "trees", "trees"], pick)))
			image.blit_rect(sheet, rock, at)
			image.blend_rect(sheet, crown, at)
	_ridge = ImageTexture.create_from_image(image)
	return _ridge
