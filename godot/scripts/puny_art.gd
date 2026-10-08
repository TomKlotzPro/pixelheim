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
	# The slime's strip: six frames of bounce, its white hit flash at 6 and 9
	# (never in a loop, or every hop flashes white), and a splat from 9.
	"strip": {"frame": 32, "anims": {"idle": [0, 3, 5.0, true], "walk": [0, 6, 10.0, true], "death": [9, 6, 12.0, false]}},
}

## Hero sheets and attack by role: blades swing, casters strike with the
## staff, rangers draw the bow. The web's looks (hero.look 0-3) pick among the
## role's colourways, first one the classic.
const HEROES := {
	"warrior": [["characters/Warrior-Red.png", "characters/Warrior-Blue.png"], "sword"],
	"paladin": [["characters/Warrior-Blue.png", "characters/Human-Soldier-Cyan.png", "characters/Human-Soldier-Red.png"], "sword"],
	"rogue": [["characters/Soldier-Red.png", "characters/Soldier-Blue.png", "characters/Soldier-Yellow.png"], "sword"],
	"cleric": [["characters/Soldier-Yellow.png", "characters/Soldier-Blue.png"], "staff"],
	"mage": [["characters/Mage-Red.png", "characters/Mage-Cyan.png"], "staff"],
	"necromancer": [["characters/Mage-Red.png", "characters/Mage-Cyan.png"], "staff"],
	"ranger": [["characters/Archer-Green.png", "characters/Archer-Purple.png"], "bow"],
}
## Necromancers wear the mage's robe in grave colors.
const HERO_TINTS := {"necromancer": Color(0.72, 0.6, 1.0)}

## Worn gear drawn on the hero (PIX-129). Shade drew every human on one
## template, so a helmet is another sheet's head and armour another sheet's
## body, cut at the neck: item id -> the sheet that draws it. Leather is his
## green archer in browns, the wyrm visor his warrior's helm blackened and
## gilded (tools/outfits.py).
const HEADS := {
	"leather_cap": "characters/Archer-Leather.png",
	"iron_helm": "characters/Human-Soldier-Cyan.png",
	"wyrm_visor": "characters/Warrior-Wyrm.png",
}
const BODIES := {
	"leather_armor": "characters/Archer-Leather.png",
	"traveler_cloak": "characters/Archer-Green.png",
	"shadow_cloak": "characters/Archer-Purple.png",
	"mage_robe": "characters/Mage-Cyan.png",
	"iron_armor": "characters/Soldier-Blue.png",
	"scaled_mail": "characters/Warrior-Red.png",
	"runic_armor": "characters/Human-Soldier-Cyan.png",
}
## The bare template whose frames say where each head ends.
const BASE := "characters/Character-Base.png"
## A head is the figure's top seven rows, in every frame.
const HEAD_ROWS := 7

## Villagers by the web's sprite id (npcs.ts / settlers.ts).
const VILLAGERS := {
	"elder": {"sheet": "mini/Okomo.png", "family": "mini"},
	"villager": {"sheet": "mini/FarmerRed.png", "family": "mini"},
	"villager_woman": {"sheet": "mini/FarmerPurple.png", "family": "mini"},
	# A living village (PIX-149): Shade's cat and dog, and the farmers drawn
	# small as children.
	"cat": {"sheet": "beasts/Orange-Cat-32x32.png", "family": "beast", "scale": 0.7},
	"dog": {"sheet": "beasts/Blonde-Dog-32x32.png", "family": "beast", "scale": 0.75},
	"child": {"sheet": "mini/FarmerRed.png", "family": "mini", "scale": 0.75},
	"child_alt": {"sheet": "mini/FarmerPurple.png", "family": "mini", "scale": 0.75},
	# The builders at the village's construction sites (PIX-147).
	"worker": {"sheet": "mini/FarmerLime.png", "family": "mini"},
	"worker_alt": {"sheet": "mini/FarmerCyan.png", "family": "mini"},
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
static var _outfits := {}
static var _necks := PackedInt32Array()


static func path(sheet: String) -> String:
	return "res://assets/puny/" + sheet


static func hero(role_id: String, look: Variant = 0) -> Dictionary:
	var entry: Array = HEROES.get(role_id, HEROES["warrior"])
	var sheets: Array = entry[0]
	var index := int(look) % sheets.size() if look != null else 0
	return {"sheet": sheets[index], "family": "puny", "attack": entry[1], "tint": HERO_TINTS.get(role_id, Color.WHITE)}


## The hero as dressed: the role's look, a worn helmet's head and a worn
## armour's body (`worn`: slot -> item id). Pieces without a drawing keep the
## look's own.
static func dressed(role_id: String, look: Variant, worn: Dictionary) -> Dictionary:
	var spec := hero(role_id, look)
	var head: String = HEADS.get(worn.get("head", ""), spec["sheet"])
	var body: String = BODIES.get(worn.get("body", ""), spec["sheet"])
	if head == spec["sheet"] and body == spec["sheet"]:
		return spec
	spec["head"] = head
	spec["body"] = body
	spec["sheet"] = "outfit|%s|%s" % [head, body]
	return spec


## A dressed spec's sheet: every frame the body sheet's rows below the neck
## and the head sheet's rows to it. Built once per outfit.
static func outfit_texture(head: String, body: String) -> Texture2D:
	var key := head + "|" + body
	if not _outfits.has(key):
		var heads: Image = (load(path(head)) as Texture2D).get_image()
		var bodies: Image = (load(path(body)) as Texture2D).get_image()
		heads.convert(Image.FORMAT_RGBA8)
		bodies.convert(Image.FORMAT_RGBA8)
		var sheet := Image.create(bodies.get_width(), bodies.get_height(), false, Image.FORMAT_RGBA8)
		var columns := bodies.get_width() / 32
		var rows := bodies.get_height() / 32
		var necks := _neck_rows()
		for row in rows:
			for column in columns:
				var at := Vector2i(column * 32, row * 32)
				var neck: int = necks[row * columns + column]
				sheet.blit_rect(bodies, Rect2i(at + Vector2i(0, neck), Vector2i(32, 32 - neck)), at + Vector2i(0, neck))
				sheet.blit_rect(heads, Rect2i(at, Vector2i(32, neck)), at)
		_outfits[key] = ImageTexture.create_from_image(sheet)
	return _outfits[key]


## Per frame of the template, the first row below the head (frames bob).
static func _neck_rows() -> PackedInt32Array:
	if _necks.is_empty():
		var base: Image = (load(path(BASE)) as Texture2D).get_image()
		for row in base.get_height() / 32:
			for column in base.get_width() / 32:
				var frame := base.get_region(Rect2i(column * 32, row * 32, 32, 32))
				var used := frame.get_used_rect()
				_necks.append(used.position.y + HEAD_ROWS if used.has_area() else 16)
	return _necks


## How many looks a role offers (its colourways).
static func looks(role_id: String) -> int:
	return (HEROES.get(role_id, HEROES["warrior"])[0] as Array).size()


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
	var texture: Texture2D = outfit_texture(spec["head"], spec["body"]) if spec.has("head") else load(path(spec["sheet"]))
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
