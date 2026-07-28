class_name WorldTiles
## Tile tables ported verbatim from src/world/tiles.ts. The web game remains
## the source of truth until it is sunset — map grids arrive pre-parsed as
## tile ids via `pnpm godot:sync`, so no char table lives on this side.

## tile id -> [sprite basename, walkable]
const TILE_INFO := {
	"grass": ["crawler/terrain/pc_grass", true],
	"forest": ["crawler/terrain/pc_grass", true],
	"mountain": ["crawler/terrain/pc_rock_top", false],
	"water": ["tile_water", false],
	"path": ["crawler/terrain/pc_dirt", true], "sand": ["tile_sand", true],
	"bridge": ["tile_bridge", true], "marsh": ["tile_marsh", true],
	"ash": ["crawler/terrain/pc_gravel", true], "crops": ["tile_crops", true],
	"trophy_shelf": ["tile_trophy_shelf", false], "garden": ["tile_garden", false],
	"wall": ["crawler/terrain/pc_brick", false],
	"floor": ["crawler/terrain/pc_floor_warm", true],
	"roof": ["crawler/terrain/pc_shingle", false],
	"roof_slate": ["crawler/terrain/pc_shingle", false],
	"roof_thatch": ["crawler/terrain/pc_shingle", false],
	"roof_awning": ["crawler/terrain/pc_shingle", false],
	"roof_moss": ["crawler/terrain/pc_shingle", false],
	"sign_goods": ["sign_goods", false],
	"sign_smith": ["sign_smith", false], "sign_potion": ["sign_potion", false],
	"sign_inn": ["sign_inn", false],
	"fence": ["crawler/terrain/pc_fence", false],
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
## (from TILE_ANIMATIONS in src/world/tiles.ts; ground terrains dropped —
## they render through the Voronoi ground shader now).
const TILE_ANIMATIONS := {
	"water": "water_shimmer", "flowers": "flowers_sway",
}

## Walkable ground rendered by the blending shader instead of tiles:
## tile id -> terrain index in shaders/ground.gdshader.
const GROUND_TILES := {
	"grass": 0, "forest": 0, "path": 1, "ash": 2, "marsh": 3, "sand": 4,
	"crops": 1,
}

## Roof tiles share one desaturated shingle texture, tinted per type so every
## roof keeps its color identity. The bottom row of a roof gets the eave tile.
const ROOF_TILES := {
	"roof": Color(0.98, 0.61, 0.40),
	"roof_slate": Color(0.79, 0.84, 0.93),
	"roof_thatch": Color(1.43, 0.95, 0.45),
	"roof_awning": Color(1.22, 0.53, 0.48),
	"roof_moss": Color(0.66, 0.98, 0.53),
}
const ROOF_EAVE := "crawler/terrain/pc_shingle_eave"

## Tiles whose bottom edge shows a face when open ground lies below —
## mountains become cliffs. tile id -> face sprite.
const FACE_TILES := {"mountain": "crawler/terrain/pc_rock_face"}

## Furniture and stations drawn as y-sorted Pixel Crawler sprites on a base
## tile instead of flat tile art. tile id -> [sheet, region, base tile].
## Sprites wider than one tile repeat along horizontal runs of the same tile.
const PROP_TILES := {
	"door": ["crawler/terrain/pc_door", Rect2(0, 0, 16, 32), "floor"],
	"door_shut": ["crawler/terrain/pc_door", Rect2(0, 0, 16, 32), "floor"],
	"bed": ["crawler/furniture", Rect2(16, 144, 48, 48), "floor"],
	"shelf": ["crawler/furniture", Rect2(0, 48, 32, 48), "floor"],
	"trophy_shelf": ["crawler/furniture", Rect2(48, 48, 48, 48), "floor"],
	"counter": ["crawler/furniture", Rect2(48, 96, 48, 40), "floor"],
	"anvil": ["crawler/station_anvil", Rect2(0, 16, 64, 56), "floor"],
	"forge": ["crawler/station_furnace", Rect2(0, 64, 48, 64), "floor"],
	"hearth": ["crawler/station_furnace", Rect2(0, 128, 48, 64), "floor"],
	"cauldron": ["crawler/station_alchemy", Rect2(0, 0, 64, 64), "floor"],
}

static var _atlas := {}


## Animation metadata generated alongside the sprites (frames, fps per sheet).
static func atlas_animations() -> Dictionary:
	if _atlas.is_empty():
		var raw := FileAccess.get_file_as_string("res://assets/sprites/atlas.json")
		_atlas = JSON.parse_string(raw)
	return _atlas["animations"]

## One color per tile for map paintings (ported from src/world/mapColors.ts);
## sprites are for the world itself.
const TILE_COLORS := {
	"grass": "3d7a35", "forest": "2a5f24", "mountain": "6b6f7a",
	"water": "2a4f8f", "path": "b89a6a", "sand": "d8c48a",
	"bridge": "8a6238", "marsh": "44603c", "ash": "66605a",
	"wall": "4a4e58", "floor": "9a713d", "door": "e8c34a",
	"door_shut": "8a6238", "cave": "16181e", "shrine": "4ae6c8",
	"flowers": "3d7a35", "crops": "c9a648", "trophy_shelf": "7a5230",
	"garden": "4a3524", "lamp": "3d7a35", "well": "8a8f9a",
}
const ROOF_COLOR := "8a5638"
const FALLBACK_COLOR := "4a4e58"
const FOG_COLOR := Color("0b0c10")


static func map_color(tile: String) -> Color:
	if TILE_COLORS.has(tile):
		return Color(TILE_COLORS[tile])
	return Color(ROOF_COLOR if tile.begins_with("roof") else FALLBACK_COLOR)


static func is_walkable(tile: String) -> bool:
	return TILE_INFO.has(tile) and TILE_INFO[tile][1]

static func sprite_path(tile: String) -> String:
	return sprite_file(TILE_INFO[tile][0])


## Generated sprites live in assets/sprites/; Pixel Crawler cuts carry their
## own path under assets/.
static func sprite_file(name: String) -> String:
	if "/" in name:
		return "res://assets/%s.png" % name
	return "res://assets/sprites/%s.png" % name
