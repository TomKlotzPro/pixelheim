class_name WorldTiles
## Tile tables ported verbatim from src/world/tiles.ts. The web game remains
## the source of truth until it is sunset — map grids arrive pre-parsed as
## tile ids via `pnpm godot:sync`, so no char table lives on this side.

## tile id -> [sprite basename, walkable]; "" where the Puny World ground
## draws the tile (GROUND_TILES).
const TILE_INFO := {
	"grass": ["", true], "forest": ["", true], "mountain": ["", false],
	"water": ["", false], "path": ["", true], "sand": ["", true],
	"bridge": ["", true], "marsh": ["", true], "ash": ["", true], "crops": ["", true],
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
	"cave": ["", true], "shrine": ["tile_shrine", true],
}

## Terrain that breathes: tile id -> its animation sheet in atlas.json
## (from TILE_ANIMATIONS in src/world/tiles.ts; ground terrains dropped —
## Puny World's water ripples on its own).
const TILE_ANIMATIONS := {"flowers": "flowers_sway"}

## Terrain the Puny World ground draws (PunyTerrain, PIX-130), so the tile
## layer leaves it alone, except for an invisible blocker where it's
## unwalkable (water, mountains).
const GROUND_TILES := {
	"grass": true, "forest": true, "path": true, "ash": true, "marsh": true,
	"sand": true, "crops": true, "water": true, "mountain": true,
	"bridge": true, "cave": true,
}

## Web props painted on the web's grass (generate-sprites.mjs palette G/L).
## Outdoors that grass is keyed out so they stand on Puny ground instead.
const GRASS_PROPS := ["flowers", "lamp", "well", "shrine", "barrel", "crate", "fence"]
const WEB_GRASS := ["3d7a35", "4a8f40"]

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


static var _cutouts := {}


## A web prop sprite (or animation strip) with its painted grass removed.
static func cutout(path: String) -> Texture2D:
	if not _cutouts.has(path):
		var image := (load(path) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).to_html(false) in WEB_GRASS:
					image.set_pixel(x, y, Color.TRANSPARENT)
		_cutouts[path] = ImageTexture.create_from_image(image)
	return _cutouts[path]
