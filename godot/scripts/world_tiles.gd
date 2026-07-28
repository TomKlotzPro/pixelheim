class_name WorldTiles
## Tile tables ported verbatim from src/world/parseMap.ts and src/world/tiles.ts.
## The web game remains the source of truth for these until it is sunset —
## changes there must be mirrored here (PIX-120 wires an automated sync).

const SPAWN_CHARS := ["S", "$", "*"]

const CHAR_TILES := {
	".": "grass", "S": "grass", "f": "forest", "^": "mountain", "~": "water",
	"=": "path", "*": "path", "s": "sand", "b": "bridge", "w": "marsh",
	"a": "ash", "k": "crops", "T": "trophy_shelf", "G": "garden", "#": "wall",
	"_": "floor", "$": "floor", "r": "roof", "1": "roof_slate",
	"2": "roof_thatch", "3": "roof_awning", "4": "roof_moss",
	"h": "sign_smith", "m": "sign_inn", "p": "sign_potion", "g": "sign_goods",
	"F": "fence", "x": "flowers", "o": "barrel", "c": "crate", "O": "well",
	"L": "lamp", "A": "anvil", "e": "forge", "t": "shelf", "u": "cauldron",
	"n": "counter", "B": "bed", "H": "hearth", "D": "door", "d": "door_shut",
	"C": "cave", "W": "shrine",
}

## tile id -> [sprite basename, walkable]
const TILE_INFO := {
	"grass": ["tile_grass", true], "forest": ["tile_forest", true],
	"mountain": ["tile_mountain", false], "water": ["tile_water", false],
	"path": ["tile_path", true], "sand": ["tile_sand", true],
	"bridge": ["tile_bridge", true], "marsh": ["tile_marsh", true],
	"ash": ["tile_ash", true], "crops": ["tile_crops", true],
	"trophy_shelf": ["tile_trophy_shelf", false], "garden": ["tile_garden", false],
	"wall": ["tile_wall", false], "floor": ["tile_floor", true],
	"roof": ["tile_roof", false], "roof_slate": ["tile_roof_slate", false],
	"roof_thatch": ["tile_roof_thatch", false], "roof_awning": ["tile_roof_awning", false],
	"roof_moss": ["tile_roof_moss", false], "sign_goods": ["sign_goods", false],
	"sign_smith": ["sign_smith", false], "sign_potion": ["sign_potion", false],
	"sign_inn": ["sign_inn", false], "fence": ["tile_fence", false],
	"flowers": ["tile_flowers", true], "barrel": ["tile_barrel", false],
	"crate": ["tile_crate", false], "well": ["tile_well", false],
	"lamp": ["tile_lamp", false], "anvil": ["tile_anvil", false],
	"forge": ["tile_forge", false], "shelf": ["tile_shelf", false],
	"cauldron": ["tile_cauldron", false], "counter": ["tile_counter", false],
	"bed": ["tile_bed", false], "hearth": ["tile_hearth", false],
	"door": ["tile_door", true], "door_shut": ["tile_door_shut", false],
	"cave": ["tile_cave", true], "shrine": ["tile_shrine", true],
}

## tile id -> mob kind that roams there
const MOB_HABITATS := {
	"grass": "orc", "forest": "orc", "ash": "skeleton", "marsh": "skeleton",
}

## Terrain that breathes: tile id -> its animation sheet in atlas.json
## (ported from TILE_ANIMATIONS in src/world/tiles.ts).
const TILE_ANIMATIONS := {
	"water": "water_shimmer", "grass": "grass_sway", "forest": "forest_sway",
	"flowers": "flowers_sway", "marsh": "marsh_sway",
}

static var _atlas := {}


## Animation metadata generated alongside the sprites (frames, fps per sheet).
static func atlas_animations() -> Dictionary:
	if _atlas.is_empty():
		var raw := FileAccess.get_file_as_string("res://assets/sprites/atlas.json")
		_atlas = JSON.parse_string(raw)
	return _atlas["animations"]

static func tile_for_char(character: String) -> String:
	return CHAR_TILES.get(character, "grass")

static func is_walkable(tile: String) -> bool:
	return TILE_INFO.has(tile) and TILE_INFO[tile][1]

static func sprite_path(tile: String) -> String:
	return "res://assets/sprites/%s.png" % TILE_INFO[tile][0]
