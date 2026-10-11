class_name PunyDungeon
## Shade's Puny Dungeon (assets/puny/dungeon, CC0, PIX-130): stone floors,
## one-tile walls and the dark beyond them, and the barrels, pots, torches,
## chests and stairs that furnish a floor. Also paves ruins under the open sky.
##
## Walls follow the grammar of Shade's sample maps: a wall with floor to its
## south shows its face (the bottom row of his wall block), any other wall its
## top; the top's row says whether the wall runs on northward, and the column
## which of its east and west neighbours are walls too.

const SHEET := "res://assets/puny/dungeon/punyworld-dungeon-tileset.png"
const TSX := "res://assets/puny/dungeon/puny-dungeon-tiles.tsx"
const COLUMNS := 26

const FLOORS := [4, 5, 6, 7, 30, 31, 32, 33, 56, 57, 58, 59, 82, 83, 84, 85]
## Plain stone, the floor under ruins.
const FLOOR := 4
const VOID := 289
## Wall top, wall running on north: [neither east nor west, east, both, west].
const TOP_END := [0, 1, 2, 3]
const TOP_RUN := [26, 27, 28, 29]
## Wall face (floor to the south); a lone column's foot when it runs north.
const FACE := [78, 79, 80, 81]
const COLUMN_FOOT := 52

## Our tile ids for a floor's furnishings -> Shade's pieces.
const BARRELS := [515, 516]
const POT := 517
const TORCH_BLOCK := 78
const TORCH := 16
const STAIRS := 514
const CHEST := 489
const CHEST_OPEN := 490
const STATUE := 491
## A region dungeon's pieces (PIX-255): the stair down into the dark, the
## sea's boulders, a wreck's hull beams (each two cells, left then right),
## mast and wheel, and a door in the rock shut (a barred wooden gate) and
## open (a dark doorway).
const STAIRS_DOWN := 462
const BOULDERS := [354, 355, 356, 357, 358, 359, 360, 361]
const BEAMS := [[328, 329], [330, 331], [332, 333], [334, 335]]
const MAST := 512
const WHEEL := 466
const GATE_SHUT := 461
const DOORWAY := 434
## The Blackiron shafts' pieces (PIX-255): a lever thrown, and the ore
## cage's barred gate in the rock (open, it is the doorway's dark).
const LEVER := 465
const CAGE := 459
## The Greyhold cellars' (PIX-255): the same iron bars as a crypt's grilles
## and the north stair while it's shut, and the stone knights over the
## garrison's dead (STATUE, the shrine's).
const GRILLE := CAGE
## The Kings' Vault's (PIX-257): the old kings' strongboxes, iron-bound and
## dented where a dragon slept on them for a hundred years (a set piece's;
## the floor's find is the plain chest).
const STRONGBOX := 458
## A shortcut's door by its look (depths.json `look`): [shut, open]; the
## cellars' north stair opens on a stair up, and the ice cave's slide is a
## chute plugged with a boulder of ice, then a run down into the dark.
const DOORS := {
	"gate": [GATE_SHUT, DOORWAY], "cage": [CAGE, DOORWAY], "stair": [GRILLE, STAIRS],
	"slide": [BOULDERS[2], STAIRS_DOWN],
}

static var _sheet: PunySheet


static func sheet() -> PunySheet:
	if _sheet == null:
		_sheet = PunySheet.new(SHEET, TSX, COLUMNS)
	return _sheet


## Cells that build walls: walls themselves and torch blocks set into a room.
static func _solid(grid: Dictionary, cell: Vector2i) -> bool:
	return grid.get(cell, "wall") == "wall"


## Whether the hero could ever see this wall: it touches open ground, even
## diagonally. Deeper rock is drawn as the dark.
static func is_visible_wall(grid: Dictionary, cell: Vector2i) -> bool:
	if not _solid(grid, cell):
		return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			if not _solid(grid, cell + Vector2i(x, y)):
				return true
	return false


## The piece a wall cell shows (VOID for rock nobody sees).
static func wall_tile(grid: Dictionary, cell: Vector2i) -> int:
	if not is_visible_wall(grid, cell):
		return VOID
	var east := is_visible_wall(grid, cell + Vector2i.RIGHT)
	var west := is_visible_wall(grid, cell + Vector2i.LEFT)
	var column := (1 if east and not west else 0) + (2 if east and west else 0) + (3 if west and not east else 0)
	var north := is_visible_wall(grid, cell + Vector2i.UP)
	if not _solid(grid, cell + Vector2i.DOWN):
		return COLUMN_FOOT if north and column == 0 else FACE[column]
	return TOP_RUN[column] if north else TOP_END[column]


## A floor tile, mostly plain stone with the odd worn slab.
static func floor_tile(cell: Vector2i) -> int:
	var h := absi(hash(cell))
	return FLOOR if h % 100 < 70 else FLOORS[(h >> 8) % FLOORS.size()]
