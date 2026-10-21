class_name EntranceArt
## areas: travel story rooms +blackiron* +saltmere* +overworld* +mountain_road* +observatory*
## What a dungeon's way in looks like (PIX-290, Tom: « Pas super beau les
## entrées de donjon, porte du Fernoir et le premier »). The Blackiron
## shafts' mouth was Shade's little mound with a dark hole on a lone block
## of cliff, and the sea cave's the same on a ledge by the beach: a small
## black square on a block. Now each way in reads as what it is, in its
## setting, set into its rock:
## - the shafts: a mine's mouth in the cliff, its timber lintel and posts,
##   an ore cart standing at its foot on the rails that run out of it down
##   the road, the pithead's winch on its frame beside it (the ore cage
##   comes up there), ore and a barrel at the rock's foot;
## - the sea cave: a dark arch at the sea cliff's foot, rocks heaped either
##   side of it, a barrel of the smugglers' rum, driftwood on the sand;
## - the Ashen Mountain's gate (both its sides): a gatehouse in the rock, a
##   tower either side with its cone roof and the gate between them, its
##   portcullis down while the story bars it, a torch on each tower burning
##   at night (PIX-312);
## - the Kings' Vault (PIX-312: it was a pale grille tile): a door of black
##   iron, studded and banded, in an arch cut in the rock under the old
##   kings' carved crown, a stone king keeping it either side; open, its
##   leaves swung in on the dark and the hoard's gold glinting in it;
## - the ice cave's stair down through Liane's floor: frost creeping out
##   over the boards and the carpet round it, and the cold's pale light
##   coming up it (shaders/stair_frost.gdshader). The Greyhold cellars'
##   stair in the keep is Shade's royal stairwell already (PIX-256).
## No signpost, no name box (PIX-269): the land and what was built in it.
## The cliff round each cave mouth runs on unbroken in the map itself
## (blackiron, saltmere), so the mouth sits in the rock's face.
## Without the paid pack (PunyProps.available() false) every look keeps to
## Shade's CC0 sheets (the overworld's framed mine door, plain mouth and
## castle towers, the dungeon's winch, posts, barrels, boulders, kings and
## torches) and our own drawn in code (HamletArt: the Vault's door).
## Pure: MapView draws the pieces (GateArt's: a cell, a sheet, a tile, a
## pixel offset, a tone, flat on the ground or standing on its cell's foot),
## and a piece standing on open ground blocks that cell, as the art stands.

## A way in by where it leads (its portal's map): the look it's drawn in.
const LOOKS := {
	"shafts": "mine", "seacave": "sea_cave", "vault_1": "vault_door",
	"mountain_road": "mountain_gate", "overworld": "mountain_gate",
}
## Medieval Age tiles (PunyTown.COLUMNS a row): the mine's mouth - its rock
## and timber lintel over the dark, then its posts and the rails out with an
## ore cart standing at its foot - the rails running on, and their end; a
## rock with a vein of ore in it.
const MINE_TOP := 845
const MINE_MOUTH := 1065
const RAIL := 1083
const RAIL_END := 1303
const ORE := 1745
## A rock with a dark arch at its foot (the sea cave's mouth), and rocks.
const ARCH := 1963
const ROCKS := [1964, 2622]
## The Medieval Age's gate in a wall: its portcullis down, then raised (the
## towers and their roofs are Rampart's, Pixelheim's gatehouse).
const GATE_BARRED := 1499
const GATE_OPEN := 1501
## CC0 (Shade's overworld sheet): the mine door in its timber frame, the
## plain dark mouth in a mound, driftwood.
const MINE_DOOR := 127
const MOUTH := 128
const DRIFTWOOD := 703
## How dark the Vault's door was (a grille tile toned): black iron. Its own
## door is drawn black now (HamletArt, PIX-312).
const BLACK_IRON := Color(0.32, 0.31, 0.38)
## Where each tower's torch burns by the mountain's gate, from its tower's
## cell (west tower, east): on the face toward the gate.
const GATE_TORCH := [Vector2(5, -5), Vector2(-5, -5)]
## The dungeons whose stair down from a room breathes frost up it.
const FROSTED := ["icecave"]
## How far the frost creeps from such a stair, in cells, and how far the
## cold's light reaches, in pixels, and how strong it is at full dark.
const FROST_REACH := 3.0
const FROST_GLOW := 64.0
const FROST_ENERGY := 0.36
## Where the frost's rim wanders (PIX-317), shares of its reach: nearest
## and farthest. In from the carpet's sides round the stair and out past
## its corners, so the frost never follows the carpet's square.
const FROST_RIM := Vector2(0.5, 1.1)
## The frost's colours (PIX-317), the shader's in the screen's colours: the
## rime, its deeper blue in the grain and the shade, snow where it lies
## thick and in a crystal's heart, the stair's steps and the dark down it.
## Cold enough to stay blue under the room's warm light (Lights.INDOOR_DAY,
## a candle at night), lit as `on_frost` says.
const FROST_TONES := {
	"rime": Color(0.74, 0.86, 1.0),
	"rime_deep": Color(0.5, 0.64, 0.88),
	"snow": Color(0.9, 0.96, 1.0),
	"steps": Color(0.6, 0.72, 0.9),
	"depths": Color(0.06, 0.08, 0.2),
}
## How sharply on_frost tells a warm light from a cold one.
const WARM_SHARPNESS := 8.0


## The look of `way` ("" for none): a cave mouth, or a gate in the rock,
## leading to a dungeon or through the mountain.
static func look_of(way: Dictionary) -> String:
	var kind := String(way.get("kind", ""))
	if kind != "cave" and not (kind == "gate" and way.get("rock", false)):
		return ""
	return LOOKS.get(String((way.get("to", {}) as Dictionary).get("mapId", "")), "")


## The pieces of `way`'s look on `map`: {look, pieces: [piece], hides:
## [cells whose own object - the plain mouth, the castle gate - isn't
## drawn], blocks: [open cells the pieces stand on]}. `barred`: the story
## keeps the way shut. `paid`: the Medieval Age pack is here.
static func plan(map: MapData, way: Dictionary, barred: bool, paid: bool) -> Dictionary:
	var look := look_of(way)
	var pieces: Array[Dictionary] = []
	var hides: Array[Vector2i] = []
	var blocks: Array[Vector2i] = []
	var out := {"look": look, "pieces": pieces, "hides": hides, "blocks": blocks}
	if look == "":
		return out
	var at: Vector2i = way["at"]
	hides.append(at)
	match look:
		"mine":
			_mine(at, paid, pieces)
		"sea_cave":
			_sea_cave(at, paid, pieces)
		"mountain_gate":
			_mountain_gate(at, barred, paid, pieces)
		"vault_door":
			_vault_door(at, barred, pieces)
	for piece: Dictionary in pieces:
		var cell: Vector2i = piece["cell"]
		if not piece["flat"] and cell != at and cell not in blocks and WorldTiles.is_walkable(map.tile_at(cell)):
			blocks.append(cell)
	return out


static func _piece(cell: Vector2i, sheet: String, tile: int, at := Vector2.ZERO, tone := "", flat := false) -> Dictionary:
	return {"cell": cell, "sheet": sheet, "tile": tile, "sprite": "", "at": at, "tone": tone, "flat": flat}


## One of our own pieces drawn in code (HamletArt, PIX-312), by its name:
## sheet "hamlet"; or a moving one ("glint", "torch") MapView animates.
static func _art(cell: Vector2i, sheet: String, name: String, at := Vector2.ZERO) -> Dictionary:
	var piece := _piece(cell, sheet, -1, at)
	piece["sprite"] = name
	return piece


## The shafts' mouth at `at`, come at from below: the mouth in the cliff (its
## rock and lintel on the cell above), the rails out down the road, ore and
## a barrel at the rock's foot west, the winch at the pithead east.
static func _mine(at: Vector2i, paid: bool, pieces: Array[Dictionary]) -> void:
	if paid:
		pieces.append(_piece(at + Vector2i.UP, "props", MINE_TOP))
		pieces.append(_piece(at, "props", MINE_MOUTH))
		pieces.append(_piece(at + Vector2i.DOWN, "props", RAIL, Vector2.ZERO, "", true))
		pieces.append(_piece(at + Vector2i.DOWN * 2, "props", RAIL_END, Vector2.ZERO, "", true))
		pieces.append(_piece(at + Vector2i.LEFT, "props", ORE, Vector2(2, 1)))
		pieces.append(_piece(at + Vector2i.LEFT * 2, "dungeon", PunyDungeon.BARRELS[0], Vector2(9, 3)))
	else:
		pieces.append(_piece(at, "world", MINE_DOOR))
		pieces.append(_piece(at + Vector2i.LEFT, "dungeon", PunyDungeon.BARRELS[0], Vector2(3, 2)))
	# The pithead's winch on its frame: a post either side, the wheel up
	# between them.
	pieces.append(_piece(at + Vector2i.RIGHT, "dungeon", PunyDungeon.POST, Vector2(-2, 2)))
	pieces.append(_piece(at + Vector2i.RIGHT, "dungeon", PunyDungeon.POST, Vector2(10, 2)))
	pieces.append(_piece(at + Vector2i.RIGHT, "dungeon", PunyDungeon.WHEEL, Vector2(4, -3)))


## The sea cave's mouth at `at`: the arch in the cliff's foot, rocks heaped
## either side, a barrel of the smugglers' rum by it, and driftwood the tide
## left on the sand below.
static func _sea_cave(at: Vector2i, paid: bool, pieces: Array[Dictionary]) -> void:
	pieces.append(_piece(at, "props" if paid else "world", ARCH if paid else MOUTH))
	var rock_sheet := "props" if paid else "dungeon"
	var rocks: Array = ROCKS if paid else PunyDungeon.BOULDERS
	pieces.append(_piece(at + Vector2i.LEFT, rock_sheet, rocks[0], Vector2(5, 1)))
	pieces.append(_piece(at + Vector2i.RIGHT, rock_sheet, rocks[1], Vector2(-5, 2)))
	pieces.append(_piece(at + Vector2i.RIGHT, "dungeon", PunyDungeon.BARRELS[0], Vector2(6, 4)))
	pieces.append(_piece(at + Vector2i(3, 2), "world", DRIFTWOOD, Vector2(0, 3), "", true))
	pieces.append(_piece(at + Vector2i(1, 3), "world", DRIFTWOOD, Vector2(6, 1), "", true))


## A gatehouse in the rock at `at`: the gate, a tower on the rock either
## side, their roofs a cell above, and a torch on each tower's face by the
## gate (PIX-312), burning at night.
static func _mountain_gate(at: Vector2i, barred: bool, paid: bool, pieces: Array[Dictionary]) -> void:
	if paid:
		pieces.append(_piece(at, "props", GATE_BARRED if barred else GATE_OPEN))
	else:
		pieces.append(_piece(at, "world", Ways.ROCK_GATE_BARRED if barred else Ways.ROCK_GATE))
	for side in 2:
		var tower := at + (Vector2i.LEFT if side == 0 else Vector2i.RIGHT)
		if paid:
			pieces.append(_piece(tower, "props", Rampart.TOWER[side]))
			pieces.append(_piece(tower + Vector2i.UP, "props", Rampart.ROOF[side]))
		else:
			pieces.append(_piece(tower, "world", PunyTerrain.TOWER))
		pieces.append(_art(tower, "torch", "torch", GATE_TORCH[side]))


## The Kings' Vault's door at `at` (PIX-312: it was a pale grille tile): a
## door of black iron, studded and banded, its two leaves in an arch cut in
## the rock, the old kings' crown carved over it and a stone king keeping it
## either side; open, its leaves swung in on the dark, and the hoard's gold
## glinting in it.
static func _vault_door(at: Vector2i, barred: bool, pieces: Array[Dictionary]) -> void:
	pieces.append(_art(at, "hamlet", "vault_door" if barred else "vault_door_open"))
	pieces.append(_art(at + Vector2i.UP, "hamlet", "vault_lintel"))
	if not barred:
		pieces.append(_art(at, "glint", "glint"))
	pieces.append(_piece(at + Vector2i.LEFT, "dungeon", PunyDungeon.STATUE, Vector2(3, 0)))
	pieces.append(_piece(at + Vector2i.RIGHT, "dungeon", PunyDungeon.STATUE, Vector2(-3, 0)))


## How `light` falls on the frost (PIX-317, shaders/stair_frost.gdshader's
## light(), which does the same): a warm light - a candle, the sun through
## the window - comes back white, as bright but not as warm, so the frost
## stays cold under a lamplit room's light (it went pink); a cold one, the
## stair's own, stays itself.
static func on_frost(light: Color) -> Color:
	var grey := light.r * 0.299 + light.g * 0.587 + light.b * 0.114
	var warm := clampf((grey - light.b) / maxf(grey, 0.001) * WARM_SHARPNESS, 0.0, 1.0)
	return light.lerp(Color(grey, grey, grey, light.a), warm)


## The stairs down from a room into a frosted dungeon (FROSTED): the ice
## cave's under Liane's floor.
static func frosted_stairs(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in map.portals:
		if map.tile_at(cell) == "stairwell" and Depths.root(String(map.portals[cell].get("mapId", ""))) in FROSTED:
			out.append(cell)
	return out
