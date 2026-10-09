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
	"paladin": [["characters/Warrior-Blue.png", "characters/aligned/Human-Soldier-Cyan.png", "characters/aligned/Human-Soldier-Red.png"], "sword"],
	"rogue": [["characters/Soldier-Red.png", "characters/Soldier-Blue.png", "characters/Soldier-Yellow.png"], "sword"],
	"cleric": [["characters/Soldier-Yellow.png", "characters/Soldier-Blue.png"], "staff"],
	"mage": [["characters/Mage-Red.png", "characters/Mage-Cyan.png"], "staff"],
	"necromancer": [["characters/Mage-Red.png", "characters/Mage-Cyan.png"], "staff"],
	"ranger": [["characters/Archer-Green.png", "characters/Archer-Purple.png"], "bow"],
}
## Necromancers wear the mage's robe in grave colors.
const HERO_TINTS := {"necromancer": Color(0.72, 0.6, 1.0)}
## The attack a worn weapon swings (PIX-172), by its catalog sprite: blades,
## daggers and heads swing (Shade's throw columns draw no weapon, so a dagger
## slashes), bows draw, staves and wands cast. Bare hands keep the role's own.
const WEAPON_ATTACKS := {
	"sword": "sword", "axe": "sword", "hammer": "sword", "dagger": "sword",
	"bow": "bow", "staff": "staff", "wand": "staff",
}
## Where the weapons are drawn in the puny family's columns: sword 4-7, bow
## 8-11, staff 12-14. Shade drew the same weapon in every sheet.
const WEAPON_COLUMNS := [4, 15]

## Worn gear drawn on the hero (PIX-129). Shade drew every human on one
## template, so a helmet is another sheet's head and armour another sheet's
## body, cut at the neck: item id -> the sheet that draws it. Every piece has
## a colourway of its own (PIX-173, tools/outfits.py), none a hero's own
## sheet, so whatever goes on shows: leather browns, Saltmere's oilcloth,
## Blackiron soot, Greyhold slate, Frostgate ice, the City's gold.
const HEADS := {
	"leather_cap": "characters/Archer-Leather.png",
	"iron_helm": "characters/Guard-Iron.png",
	"wyrm_visor": "characters/Warrior-Wyrm.png",
	"greymaw_hood": "characters/Archer-Greymaw.png",
	"oilskin_hood": "characters/Archer-Oilskin.png",
	"blackiron_helm": "characters/Warrior-Blackiron.png",
	"warden_helm": "characters/Guard-Warden.png",
	"frost_hood": "characters/Mage-Frost.png",
}
const BODIES := {
	"leather_armor": "characters/Archer-Leather.png",
	"traveler_cloak": "characters/Archer-Traveler.png",
	"shadow_cloak": "characters/Archer-Shadow.png",
	"mage_robe": "characters/Mage-Midnight.png",
	"iron_armor": "characters/Soldier-Iron.png",
	"scaled_mail": "characters/Warrior-Scaled.png",
	"runic_armor": "characters/Guard-Runic.png",
	"city_plate": "characters/Warrior-Gilded.png",
	"oilskin_coat": "characters/Archer-Oilskin.png",
	"blackiron_plate": "characters/Warrior-Blackiron.png",
	"warden_hauberk": "characters/Guard-Warden.png",
	"frostweave_robe": "characters/Mage-Frost.png",
}
## Gloves and boots (PIX-174): Shade's hands are the skin below the neck,
## his boots the two leather browns along the figure's last rows. Worn ones
## take the item's colour over them, light to dark.
const SKIN_RAMP := ["f6a954", "d97f40", "aa5a33", "84482a"]
const BOOT_RAMP := ["5d4717", "3f3013"]
const BOOT_ROWS := 2
## Below the neck by this many rows, skin is hands, not a chin.
const HAND_FROM := 9
## Shields on the off hand (PIX-174), in Shade's 1px-outlined style: o the
## outline, r the lit rim, f the face, e the boss. Drawn in front of the
## figure facing down or left, behind it facing right or up, and put away
## while a bow is drawn, a staff cast or the hero falls.
const SHIELDS := {
	"buckler": [".ooo.", "orffo", "ofefo", "offfo", ".ooo."],
	"kite": ["ooooo", "orffo", "ofefo", "offfo", ".ofo.", "..o.."],
	"tower": ["ooooo", "orffo", "offfo", "ofefo", "offfo", "offfo", "ooooo"],
	"orb": [".oo.", "orfo", "offo", ".oo."],
}
## Where the shield hangs per direction row (down 0, right 2, up 4, left 6):
## [x from the figure's centre, y below its top, in front].
const SHIELD_AT := {0: [4, 8, true], 2: [1, 8, false], 4: [-5, 8, false], 6: [-4, 8, true]}
## Columns where both hands are busy or the hero lies down: no shield.
const SHIELD_HIDDEN := [[8, 15], [21, 24]]

## The bare template whose frames say where each head ends.
const BASE := "characters/Character-Base.png"
## A head is the figure's top seven rows, in every frame...
const HEAD_ROWS := 7
## ...but for the hero lying down (PIX-175): falling right, up or left, the
## figure lies across the cut, so those frames are the body sheet's whole
## (column, row) - no helmet on the fallen, but no two heroes in one either.
const LYING := [Vector2i(22, 2), Vector2i(23, 2), Vector2i(22, 4), Vector2i(23, 4), Vector2i(22, 6), Vector2i(23, 6)]

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
	"merchant": {"sheet": "characters/aligned/Human-Worker-Red.png", "family": "puny"},
	"smith": {"sheet": "characters/aligned/Human-Soldier-Red.png", "family": "puny"},
	"alchemist": {"sheet": "characters/Mage-Cyan.png", "family": "puny"},
	"innkeeper": {"sheet": "characters/aligned/Human-Worker-Cyan.png", "family": "puny"},
	"mayor": {"sheet": "characters/aligned/Human-Soldier-Cyan.png", "family": "puny"},
	# Saltmere's folk (PIX-165), and Rook, the smuggler who talks.
	"fisher": {"sheet": "mini/FarmerCyan.png", "family": "mini"},
	"fisher_alt": {"sheet": "mini/FarmerLime.png", "family": "mini"},
	"smuggler": {"sheet": "mini/PirateGrunt.png", "family": "mini"},
	# Greyhold's old guard in the fort's cyan, and the chapel's monk (PIX-168).
	"guard": {"sheet": "mini/SwordsmanCyan.png", "family": "mini"},
	"monk": {"sheet": "mini/MagePurple.png", "family": "mini"},
	# The Frostgate's hermit, in his big hat (PIX-169).
	"hermit": {"sheet": "mini/Gangblanc.png", "family": "mini"},
}

## The bestiary by monster id: the closest creature Shade drew, tinted or
## scaled where one sheet stands in for a kin (bone knights, ghosts, shades).
const MONSTERS := {
	"slime": {"sheet": "characters/Slime.png", "family": "strip"},
	"goblin": {"sheet": "characters/aligned/Orc-Peon-Red.png", "family": "puny", "attack": "sword"},
	"orc": {"sheet": "characters/aligned/Orc-Grunt.png", "family": "puny", "attack": "sword"},
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
	# Saltmere's coast (PIX-165): Mini World's crabs, smugglers and a slime king.
	"crab": {"sheet": "mini/GiantCrab.png", "family": "mini"},
	"pirate": {"sheet": "mini/PirateGrunt.png", "family": "mini"},
	"pirate_gunner": {"sheet": "mini/PirateGunner.png", "family": "mini"},
	"pirate_captain": {"sheet": "mini/PirateCaptain.png", "family": "mini", "scale": 1.15},
	"king_slime": {"sheet": "mini/KingSlimeBlue.png", "family": "mini", "scale": 1.3},
	# The Blackiron shafts (PIX-167).
	"goblin_digger": {"sheet": "mini/ClubGoblin.png", "family": "mini"},
	"goblin_spear": {"sheet": "mini/SpearGoblin.png", "family": "mini"},
	"iron_demon": {"sheet": "mini/ArmouredRedDemon.png", "family": "mini", "scale": 1.2},
	# Greyhold (PIX-168): turncoats in the red cloaks, and the fort's dead
	# garrison, the same cyan as the living guard, gone pale.
	"turncoat": {"sheet": "mini/SwordsmanRed.png", "family": "mini"},
	"turncoat_bowman": {"sheet": "mini/BowmanRed.png", "family": "mini"},
	"cutthroat": {"sheet": "mini/AssasinRed.png", "family": "mini"},
	"hollow_guard": {"sheet": "mini/SwordsmanCyan.png", "family": "mini", "tint": Color(0.72, 0.88, 1.0, 0.78)},
	# The Frostgate pass (PIX-169): Mini World's frostborn as themselves, a
	# wolf gone white, and the white dragon as a frost drake.
	"frost_wolf": {"sheet": "beasts/Gray-Wolf-32x32.png", "family": "beast", "tint": Color(0.9, 0.96, 1.12)},
	"yeti": {"sheet": "mini/Yeti.png", "family": "mini"},
	"wendigo": {"sheet": "mini/Wendigo.png", "family": "mini"},
	"frost_mammoth": {"sheet": "mini/Mammoth.png", "family": "mini", "scale": 1.2},
	"frost_drake": {"sheet": "mini/WhiteDragon.png", "family": "mini", "frame": 32, "scale": 0.85},
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
## look's own. A role's colour (the necromancer's grave violet) goes on its
## own head and body only, never on borrowed armour (PIX-175).
static func dressed(role_id: String, look: Variant, worn: Dictionary) -> Dictionary:
	var spec := hero(role_id, look)
	var head: String = HEADS.get(worn.get("head", ""), spec["sheet"])
	var body: String = BODIES.get(worn.get("body", ""), spec["sheet"])
	var role_tint: Color = spec["tint"]
	# The weapon in hand picks the swing and colours the blade (PIX-172).
	var tint := Color.WHITE
	var weapon: Dictionary = Catalog.item(worn.get("weapon", "")) if worn.get("weapon", "") != "" else {}
	if not weapon.is_empty():
		spec["attack"] = WEAPON_ATTACKS.get(weapon.get("sprite", ""), spec["attack"])
		tint = _tint_of(weapon, Color.WHITE)
	# Gloves, boots and the off hand show too (PIX-174).
	var gear := {
		"hands": _tint_of(Catalog.item(worn.get("hands", "")), Color.TRANSPARENT),
		"feet": _tint_of(Catalog.item(worn.get("feet", "")), Color.TRANSPARENT),
		"shield": String(Catalog.item(worn.get("offhand", "")).get("shape", "")),
		"shield_tint": _tint_of(Catalog.item(worn.get("offhand", "")), Color.WHITE),
	}
	var plain_gear: bool = gear["hands"].a == 0.0 and gear["feet"].a == 0.0 and gear["shield"] == ""
	if head == spec["sheet"] and body == spec["sheet"] and tint == Color.WHITE and plain_gear:
		return spec
	spec["head"] = head
	spec["body"] = body
	spec["weapon_tint"] = tint
	spec["gear"] = gear
	gear["head_tint"] = role_tint if head == spec["sheet"] else Color.WHITE
	gear["body_tint"] = role_tint if body == spec["sheet"] else Color.WHITE
	spec["tint"] = Color.WHITE
	spec["sheet"] = "outfit|%s" % outfit_key(head, body, tint, gear)
	return spec


## An item's colour from the catalogue ("tint"), or `fallback` without one.
static func _tint_of(item: Dictionary, fallback: Color) -> Color:
	if not item.has("tint"):
		return fallback
	var shade: Array = item["tint"]
	return Color(float(shade[0]), float(shade[1]), float(shade[2]))


static func outfit_key(head: String, body: String, weapon_tint: Color, gear: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		head, body, weapon_tint.to_html(false), Color(gear.get("hands", Color.TRANSPARENT)).to_html(),
		Color(gear.get("feet", Color.TRANSPARENT)).to_html(), gear.get("shield", ""), Color(gear.get("shield_tint", Color.WHITE)).to_html(false),
		Color(gear.get("head_tint", Color.WHITE)).to_html(false), Color(gear.get("body_tint", Color.WHITE)).to_html(false),
	]


## A dressed spec's sheet: every frame the body sheet's rows below the neck
## and the head sheet's rows to it. Built once per outfit.
static func outfit_texture(head: String, body: String, weapon_tint := Color.WHITE, gear := {}) -> Texture2D:
	var key := outfit_key(head, body, weapon_tint, gear)
	if not _outfits.has(key):
		var heads: Image = (load(path(head)) as Texture2D).get_image()
		var bodies: Image = (load(path(body)) as Texture2D).get_image()
		heads.convert(Image.FORMAT_RGBA8)
		bodies.convert(Image.FORMAT_RGBA8)
		_tint(heads, gear.get("head_tint", Color.WHITE))
		_tint(bodies, gear.get("body_tint", Color.WHITE))
		var sheet := Image.create(bodies.get_width(), bodies.get_height(), false, Image.FORMAT_RGBA8)
		var columns := bodies.get_width() / 32
		var rows := bodies.get_height() / 32
		var necks := _neck_rows()
		for row in rows:
			for column in columns:
				var at := Vector2i(column * 32, row * 32)
				var neck: int = 0 if Vector2i(column, row) in LYING else necks[row * columns + column]
				sheet.blit_rect(bodies, Rect2i(at + Vector2i(0, neck), Vector2i(32, 32 - neck)), at + Vector2i(0, neck))
				sheet.blit_rect(heads, Rect2i(at, Vector2i(32, neck)), at)
		if weapon_tint != Color.WHITE:
			_tint_weapon(sheet, weapon_tint)
		if not gear.is_empty():
			_wear(sheet, gear)
		_outfits[key] = ImageTexture.create_from_image(sheet)
	return _outfits[key]


## A whole sheet in a role's colour, multiplied as the sprite's modulate did.
static func _tint(image: Image, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	for y in image.get_height():
		for x in image.get_width():
			var here := image.get_pixel(x, y)
			if here.a > 0.0:
				image.set_pixel(x, y, Color(here.r * tint.r, here.g * tint.g, here.b * tint.b, here.a))


## A colour's ramp, light to dark, for recolouring Shade's ramps over it.
static func _ramp(tint: Color, steps: int) -> Array[Color]:
	var out: Array[Color] = []
	for i in steps:
		var amount := 0.22 - 0.5 * float(i) / maxf(1.0, steps - 1)
		out.append(tint.lightened(amount) if amount > 0.0 else tint.darkened(-amount))
	return out


## Gloves over the hands, boots over the boots and the shield on the off
## hand, in every frame of the sheet (PIX-174).
static func _wear(sheet: Image, gear: Dictionary) -> void:
	var hands: Color = gear.get("hands", Color.TRANSPARENT)
	var feet: Color = gear.get("feet", Color.TRANSPARENT)
	var shape: String = gear.get("shield", "")
	var hand_swap := {}
	if hands.a > 0.0:
		var ramp := _ramp(hands, SKIN_RAMP.size())
		for i in SKIN_RAMP.size():
			hand_swap[Color(SKIN_RAMP[i]).to_html(false)] = ramp[i]
	var boot_swap := {}
	if feet.a > 0.0:
		var ramp := _ramp(feet, BOOT_RAMP.size() + 1)
		for i in BOOT_RAMP.size():
			boot_swap[Color(BOOT_RAMP[i]).to_html(false)] = ramp[i + 1]
	var columns := sheet.get_width() / 32
	var rows := sheet.get_height() / 32
	var necks := _neck_rows()
	for row in rows:
		for column in columns:
			var cell := Rect2i(column * 32, row * 32, 32, 32)
			# A fallen hero's face lies where the hands would be: left alone.
			if Vector2i(column, row) in LYING:
				continue
			var used := _figure(row * columns + column)
			var neck: int = necks[row * columns + column]
			var bottom := used.end.y
			for y in range(neck + HAND_FROM - 7, bottom):
				for x in 32:
					var at := Vector2i(cell.position.x + x, cell.position.y + y)
					var here := sheet.get_pixelv(at)
					if here.a == 0.0:
						continue
					var code := here.to_html(false)
					if y >= bottom - BOOT_ROWS and boot_swap.has(code):
						sheet.set_pixelv(at, boot_swap[code])
					elif y < bottom - BOOT_ROWS and hand_swap.has(code):
						sheet.set_pixelv(at, hand_swap[code])
			if shape != "" and SHIELDS.has(shape):
				_shield(sheet, cell, used, row, column, shape, gear.get("shield_tint", Color.WHITE))


## One frame's shield: hung by the off hand per direction, behind the
## figure where the body would hide it.
static func _shield(sheet: Image, cell: Rect2i, used: Rect2i, row: int, column: int, shape: String, tint: Color) -> void:
	for span: Array in SHIELD_HIDDEN:
		if column >= int(span[0]) and column < int(span[1]):
			return
	var place: Array = SHIELD_AT.get(row - row % 2, SHIELD_AT[0])
	var grid: Array = SHIELDS[shape]
	var colours := {
		"o": Color("040404"), "r": tint.lightened(0.35), "f": tint, "e": tint.lightened(0.6),
	}
	var origin := cell.position + Vector2i(used.position.x + used.size.x / 2 + int(place[0]) - String(grid[0]).length() / 2, used.position.y + int(place[1]))
	var in_front: bool = place[2]
	for gy in grid.size():
		var line: String = grid[gy]
		for gx in line.length():
			var key := line[gx]
			if key == ".":
				continue
			var at := origin + Vector2i(gx, gy)
			if not cell.has_point(at):
				continue
			if not in_front and sheet.get_pixelv(at).a > 0.0:
				continue
			sheet.set_pixelv(at, colours[key])


static var _weapon_pixels := {}


## The weapon's pixels in the attack columns: the template's own colours
## there that its idle and walk frames never use (the blade, the bow, the
## staff and its gem), as cell -> template colour.
static func _weapon_mask() -> Dictionary:
	if _weapon_pixels.is_empty():
		var base: Image = (load(path(BASE)) as Texture2D).get_image()
		base.convert(Image.FORMAT_RGBA8)
		var body_colours := {}
		for y in base.get_height():
			for x in WEAPON_COLUMNS[0] * 32:
				var colour := base.get_pixel(x, y)
				if colour.a > 0.0:
					body_colours[colour.to_html()] = true
		for y in base.get_height():
			for x in range(WEAPON_COLUMNS[0] * 32, WEAPON_COLUMNS[1] * 32):
				var colour := base.get_pixel(x, y)
				if colour.a > 0.0 and not body_colours.has(colour.to_html()):
					_weapon_pixels[Vector2i(x, y)] = colour
	return _weapon_pixels


## The worn weapon's colour over Shade's generic one, wherever the sheet still
## shows the template's weapon pixel (an arm in front keeps its own).
static func _tint_weapon(sheet: Image, tint: Color) -> void:
	var mask := _weapon_mask()
	for cell: Vector2i in mask:
		if cell.x >= sheet.get_width() or cell.y >= sheet.get_height():
			continue
		var here := sheet.get_pixelv(cell)
		if here.is_equal_approx(mask[cell]):
			sheet.set_pixelv(cell, Color(here.r * tint.r, here.g * tint.g, here.b * tint.b, here.a).clamp())


## Per frame of the template, the first row below the head (frames bob).
static func _neck_rows() -> PackedInt32Array:
	if _necks.is_empty():
		var base: Image = (load(path(BASE)) as Texture2D).get_image()
		for row in base.get_height() / 32:
			for column in base.get_width() / 32:
				var frame := base.get_region(Rect2i(column * 32, row * 32, 32, 32))
				var used := frame.get_used_rect()
				_necks.append(used.position.y + HEAD_ROWS if used.has_area() else 16)
				_figures.append(used if used.has_area() else Rect2i(8, 8, 16, 20))
	return _necks


static var _figures: Array[Rect2i] = []


## The bare figure in each frame (the template's), so a plume or a swung
## blade never moves where gloves, boots and shields go.
static func _figure(index: int) -> Rect2i:
	_neck_rows()
	return _figures[index]


## How many looks a role offers (its colourways).
static func looks(role_id: String) -> int:
	return (HEROES.get(role_id, HEROES["warrior"])[0] as Array).size()


static func villager(sprite: String) -> Dictionary:
	return VILLAGERS.get(sprite, VILLAGERS["villager"])


static func monster(id: String) -> Dictionary:
	return MONSTERS.get(id, MONSTERS["slime"])


static func frame_size(spec: Dictionary) -> int:
	return int(spec.get("frame", FAMILIES[spec["family"]]["frame"]))


## A spec's whole sheet: the dressed outfit's, or the drawn one's.
static func sheet_texture(spec: Dictionary) -> Texture2D:
	if spec.has("head"):
		return outfit_texture(spec["head"], spec["body"], spec.get("weapon_tint", Color.WHITE), spec.get("gear", {}))
	return load(path(spec["sheet"]))


## SpriteFrames with "<anim>_<dir>" animations (or "<anim>" for strips) for a
## spec; cached per sheet so a pack of twelve shares one set of frames.
static func frames(spec: Dictionary) -> SpriteFrames:
	var key: String = "%s|%s|%d" % [spec["sheet"], spec["family"], frame_size(spec)]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var family: Dictionary = FAMILIES[spec["family"]]
	var size := frame_size(spec)
	var texture := sheet_texture(spec)
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
