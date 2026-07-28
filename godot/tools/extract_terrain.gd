extends SceneTree
## Extracts terrain/prop tiles from the Pixel Crawler sheets into
## assets/crawler/terrain/ (committed). Re-run with:
## godot --headless --path godot -s res://tools/extract_terrain.gd

## name -> [sheet, origin, size, desaturate]
const CUTS := {
	"pc_grass": ["floors_tiles", Vector2i(16, 160), Vector2i(16, 16), false],
	"pc_dirt": ["floors_tiles", Vector2i(176, 160), Vector2i(16, 16), false],
	"pc_gravel": ["floors_tiles", Vector2i(96, 160), Vector2i(16, 16), false],
	"pc_brick": ["floors_tiles", Vector2i(256, 16), Vector2i(16, 16), false],
	"pc_floor_warm": ["floors_tiles", Vector2i(96, 368), Vector2i(16, 16), false],
	"pc_rock_top": ["wall_tiles", Vector2i(144, 32), Vector2i(16, 16), false],
	"pc_rock_face": ["wall_tiles", Vector2i(116, 264), Vector2i(16, 16), false],
	# Shingles are desaturated so roof tiles can tint them per roof type.
	"pc_shingle": ["roofs", Vector2i(160, 160), Vector2i(16, 16), true],
	"pc_shingle_eave": ["roofs", Vector2i(160, 192), Vector2i(16, 16), true],
	"pc_fence": ["building_props", Vector2i(32, 176), Vector2i(16, 16), false],
	"pc_door": ["furniture", Vector2i(128, 288), Vector2i(16, 32), false],
}


func _init() -> void:
	for name: String in CUTS:
		var spec: Array = CUTS[name]
		var sheet := Image.load_from_file("res://assets/crawler/%s.png" % spec[0])
		var tile := sheet.get_region(Rect2i(spec[1], spec[2]))
		if spec[3]:
			for y in tile.get_height():
				for x in tile.get_width():
					var color := tile.get_pixel(x, y)
					var gray := color.get_luminance()
					tile.set_pixel(x, y, Color(gray, gray, gray, color.a))
		tile.save_png("res://assets/crawler/terrain/%s.png" % name)
		print("extracted ", name)
	quit()
