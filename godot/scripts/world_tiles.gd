class_name WorldTiles
## Tile tables ported verbatim from src/world/tiles.ts. The web game remains
## the source of truth until it is sunset — map grids arrive pre-parsed as
## tile ids via `pnpm godot:sync`, so no char table lives on this side.

## Tile id -> walkable. Every tile is drawn by Shade's art now (PunyTerrain,
## PunyTown, PunyInterior, PunyProps, PunyDungeon); this only says what the
## hero may walk on.
const TILE_INFO := {
	"grass": true, "forest": true, "mountain": false, "water": false, "path": true,
	"sand": true, "bridge": true, "marsh": true, "ash": true, "crops": true,
	"trophy_shelf": false, "garden": false, "wall": false, "floor": true,
	"roof": false, "roof_slate": false, "roof_thatch": false, "roof_awning": false, "roof_moss": false,
	"sign_goods": false, "sign_smith": false, "sign_potion": false, "sign_inn": false,
	"fence": false, "flowers": true, "barrel": false, "crate": false, "well": false,
	"lamp": false, "anvil": false, "forge": false, "shelf": false, "cauldron": false,
	"counter": false, "bed": false, "hearth": false, "door": true, "door_shut": false,
	"cave": true, "shrine": true,
	# The bigger Reach (PIX-164): the coast's shallows and sea, its docks;
	# snow and walkable ice on the pass; cobbled stone in the mines and the
	# castle.
	"shore": false, "sea": false, "deep_sea": false, "dock": true,
	"snow": true, "ice": true, "stone": true,
	# A stairwell cut in a room's floor (PIX-256): the way down to the
	# cellar under a house, walked onto (it asks first).
	"stairwell": true,
	# A region dungeon's floors (PIX-255): a wreck's beams, the sea's
	# boulders, and the shortcut's door in the rock while it's sealed; the
	# shafts' ore cage's winch.
	"wreck": false, "rock": false, "sealed": false, "winch": false,
}

## Terrain the Puny World ground draws (PunyTerrain, PIX-130).
const GROUND_TILES := {
	"grass": true, "forest": true, "path": true, "ash": true, "marsh": true,
	"sand": true, "crops": true, "water": true, "mountain": true,
	"bridge": true, "cave": true,
	"shore": true, "sea": true, "deep_sea": true, "dock": true, "snow": true, "ice": true, "stone": true,
}

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
	"shore": "5aa0c8", "sea": "2a6fa8", "deep_sea": "1d4a7a", "dock": "8a6238",
	"snow": "e8eef2", "ice": "a8d0e0", "stone": "8a8680",
	"stairwell": "16181e",
	"wreck": "6a4a2e", "rock": "6b6f7a", "sealed": "8a6238", "winch": "6b6f7a",
}
const ROOF_COLOR := "8a5638"
const FALLBACK_COLOR := "4a4e58"
const FOG_COLOR := Color("0b0c10")


static func map_color(tile: String) -> Color:
	if TILE_COLORS.has(tile):
		return Color(TILE_COLORS[tile])
	return Color(ROOF_COLOR if tile.begins_with("roof") else FALLBACK_COLOR)


static func is_walkable(tile: String) -> bool:
	return TILE_INFO.get(tile, false)
