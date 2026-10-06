class_name PunyArt
## Who wears which of Shade's CC0 sheets (assets/puny, PIX-130), and how each
## sheet family is laid out. Everyone is drawn at 1x on the 16px grid, so the
## hero, the villagers and the bestiary finally share one style.
##
## Families:
## - "puny": Puny Characters, 32px cells, 8 direction rows clockwise from down
##   (down 0, right 2, up 4, left 6), 24 columns of idle/walk/sword/bow/staff/
##   throw/hurt/death.
## - "beast": PunyMonsters, 32px cells, 8 rows turning the other way (down 0,
##   left 2, up 4, right 6); walk 0-5, bite 6-8, hurt 9-11.
## - "mini": Mini World, 16px cells (32 for dragons), rows down 0 / up 1 /
##   left 2 / right 3 for walking, the attack rows 4 below.
## (Row orders checked against a `--screenshot lineup` capture.)
## - "strip": one row of frames, no directions (the slime).

const DIRS := ["down", "right", "up", "left"]
const FAMILIES := {
	"puny": {
		"frame": 32, "rows": {"down": 0, "right": 2, "up": 4, "left": 6},
		"anims": {
			"idle": [0, 2, 4.0, true], "walk": [2, 2, 6.0, true], "sword": [4, 4, 14.0, false],
			"bow": [8, 4, 12.0, false], "staff": [12, 3, 10.0, false], "hurt": [18, 3, 12.0, false],
			"death": [21, 3, 6.0, false],
		},
	},
	"beast": {
		"frame": 32, "rows": {"down": 0, "left": 2, "up": 4, "right": 6},
		"anims": {
			"idle": [0, 2, 3.0, true], "walk": [0, 6, 10.0, true], "attack": [6, 3, 10.0, false],
			"hurt": [9, 3, 12.0, false],
		},
	},
	"mini": {
		"frame": 16, "rows": {"down": 0, "up": 1, "left": 2, "right": 3}, "attack_row_offset": 4,
		"anims": {"idle": [0, 2, 3.0, true], "walk": [0, 4, 8.0, true], "attack": [0, 3, 10.0, false]},
	},
	"strip": {"frame": 32, "anims": {"idle": [0, 4, 6.0, true], "walk": [0, 8, 10.0, true]}},
}

## Hero sheet and attack by role: blades swing, casters strike with the staff,
## rangers draw the bow.
const HEROES := {
	"warrior": ["characters/Warrior-Red.png", "sword"],
	"paladin": ["characters/Warrior-Blue.png", "sword"],
	"rogue": ["characters/Soldier-Red.png", "sword"],
	"cleric": ["characters/Soldier-Yellow.png", "staff"],
	"mage": ["characters/Mage-Red.png", "staff"],
	"necromancer": ["characters/Mage-Red.png", "staff"],
	"ranger": ["characters/Archer-Green.png", "bow"],
}
## Necromancers wear the mage's robe in grave colors.
const HERO_TINTS := {"necromancer": Color(0.72, 0.6, 1.0)}

## Villagers by the web's sprite id (npcs.ts / settlers.ts).
const VILLAGERS := {
	"elder": {"sheet": "mini/Okomo.png", "family": "mini"},
	"villager": {"sheet": "mini/FarmerRed.png", "family": "mini"},
	"villager_woman": {"sheet": "mini/FarmerPurple.png", "family": "mini"},
	"merchant": {"sheet": "characters/Human-Worker-Red.png", "family": "puny"},
	"smith": {"sheet": "characters/Human-Soldier-Red.png", "family": "puny"},
	"alchemist": {"sheet": "characters/Mage-Cyan.png", "family": "puny"},
	"innkeeper": {"sheet": "characters/Human-Worker-Cyan.png", "family": "puny"},
	"mayor": {"sheet": "characters/Human-Soldier-Cyan.png", "family": "puny"},
}

## The bestiary by monster id: the closest creature Shade drew, tinted or
## scaled where one sheet stands in for a kin (bone knights, ghosts, shades).
const MONSTERS := {
	"slime": {"sheet": "characters/Slime.png", "family": "strip"},
	"goblin": {"sheet": "characters/Orc-Peon-Red.png", "family": "puny", "attack": "sword"},
	"orc": {"sheet": "characters/Orc-Grunt.png", "family": "puny", "attack": "sword"},
	"troll": {"sheet": "mini/Minotaur.png", "family": "mini", "scale": 1.25},
	"wolf": {"sheet": "beasts/Gray-Wolf-32x32.png", "family": "beast"},
	"skeleton": {"sheet": "mini/Skeleton-Soldier.png", "family": "mini"},
	"boneknight": {"sheet": "mini/Skeleton-Soldier.png", "family": "mini", "scale": 1.25, "tint": Color(0.7, 0.72, 0.85)},
	"lich": {"sheet": "mini/Necromancer.png", "family": "mini", "scale": 1.2},
	"ghost": {"sheet": "mini/Yeti.png", "family": "mini", "tint": Color(0.75, 0.9, 1.0, 0.72)},
	"shade": {"sheet": "mini/Wendigo.png", "family": "mini", "tint": Color(0.45, 0.38, 0.6)},
	"golem": {"sheet": "mini/Mammoth.png", "family": "mini", "tint": Color(0.75, 0.75, 0.72)},
	"imp": {"sheet": "mini/RedDemon.png", "family": "mini"},
	"wyvern": {"sheet": "mini/YellowDragon.png", "family": "mini", "frame": 32, "scale": 0.8},
	"dragon": {"sheet": "mini/RedDragon.png", "family": "mini", "frame": 32, "scale": 1.15},
	"mimic": {"sheet": "beasts/Purple-Spider-32x32.png", "family": "beast"},
}

static var _frames_cache := {}


static func path(sheet: String) -> String:
	return "res://assets/puny/" + sheet


static func hero(role_id: String) -> Dictionary:
	var entry: Array = HEROES.get(role_id, HEROES["warrior"])
	return {"sheet": entry[0], "family": "puny", "attack": entry[1], "tint": HERO_TINTS.get(role_id, Color.WHITE)}


static func villager(sprite: String) -> Dictionary:
	return VILLAGERS.get(sprite, VILLAGERS["villager"])


static func monster(id: String) -> Dictionary:
	return MONSTERS.get(id, MONSTERS["slime"])


static func frame_size(spec: Dictionary) -> int:
	return int(spec.get("frame", FAMILIES[spec["family"]]["frame"]))


## SpriteFrames with "<anim>_<dir>" animations (or "<anim>" for strips) for a
## spec; cached per sheet so a pack of twelve shares one set of frames.
static func frames(spec: Dictionary) -> SpriteFrames:
	var key: String = "%s|%s|%d" % [spec["sheet"], spec["family"], frame_size(spec)]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var family: Dictionary = FAMILIES[spec["family"]]
	var size := frame_size(spec)
	var texture: Texture2D = load(path(spec["sheet"]))
	var columns := texture.get_width() / size
	var sheet := SpriteFrames.new()
	sheet.remove_animation("default")
	for anim: String in family["anims"]:
		var def: Array = family["anims"][anim]
		if spec["family"] == "strip":
			_add(sheet, anim, texture, size, 0, def[0], mini(def[1], columns), def[2], def[3])
			continue
		for dir: String in DIRS:
			var row: int = family["rows"][dir]
			if anim == "attack" and family.has("attack_row_offset"):
				row += int(family["attack_row_offset"])
			if (row + 1) * size > texture.get_height():
				continue
			_add(sheet, "%s_%s" % [anim, dir], texture, size, row, def[0], mini(def[1], columns - def[0]), def[2], def[3])
	_frames_cache[key] = sheet
	return sheet


static func _add(sheet: SpriteFrames, anim: String, texture: Texture2D, size: int, row: int, first: int, count: int, fps: float, loop: bool) -> void:
	sheet.add_animation(anim)
	sheet.set_animation_speed(anim, fps)
	sheet.set_animation_loop(anim, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((first + i) * size, row * size, size, size)
		sheet.add_frame(anim, atlas)


## The animation to play for `anim` facing `dir`, falling back to walking and
## idling when a sheet doesn't draw that action.
static func pick(sheet: SpriteFrames, anim: String, dir: String) -> String:
	for candidate in ["%s_%s" % [anim, dir], anim, "walk_%s" % dir, "idle_%s" % dir, "walk", "idle"]:
		if sheet.has_animation(candidate):
			return candidate
	return sheet.get_animation_names()[0]


## How far to lift a sprite so its feet stand on the node: Shade's figures sit
## low in their cells (about 3/4 down in 32px cells, at the bottom of 16px ones).
static func lift(spec: Dictionary) -> float:
	return -4.0 if frame_size(spec) == 32 else -3.0
