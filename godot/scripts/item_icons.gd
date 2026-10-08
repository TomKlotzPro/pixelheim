class_name ItemIcons
## Every item's icon and the ailment marks, all Shade's (PIX-138), as mapped
## in assets/puny/icons.json:
## - "free/<sheet>@c,r": a cell of his CC0 icon sheets in assets/puny/icons/;
## - "medieval@<tile>": a tile of the Medieval Age atlas (food, furniture);
## - anything else: a file of his paid icon packs, which scripts/
##   fetch-private-art.sh copies from the private pixelheim-assets repo into
##   assets/puny/shade/ (git-ignored), "@c,r" picking a cell of a sheet.
## Skills map a skill's name to "<theme>/<n>" in the Puny Skills pack.
## Without the paid art a paid icon is missing (null): the slot stays empty,
## the dock shows a skill's initials.

const MAP := "res://assets/puny/icons.json"
const FREE := "res://assets/puny/icons/"
const PRIVATE := "res://assets/puny/shade/"

static var _doc := {}
static var _cache := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	return _doc


## The source an item maps to ("" when unmapped).
static func source(item_id: String) -> String:
	return _data()["items"].get(item_id, "")


## Where a source's art lives: {"path", "cell" (Vector2i, or -1s for a whole
## file), "tile" (-1 unless a Medieval tile)}.
static func resolve(src: String) -> Dictionary:
	if src.begins_with("medieval@"):
		return {"path": PunyTown.SHEET, "cell": Vector2i(-1, -1), "tile": int(src.get_slice("@", 1))}
	var file := src.get_slice("@", 0)
	var cell := Vector2i(-1, -1)
	if "@" in src:
		var at := src.get_slice("@", 1).split(",")
		cell = Vector2i(int(at[0]), int(at[1]))
	var path := FREE + file.trim_prefix("free/") if file.begins_with("free/") else PRIVATE + file
	return {"path": path, "cell": cell, "tile": -1}


## An item's icon, 16x16, or null (no paid art for it here).
static func texture(item_id: String) -> Texture2D:
	return _texture(source(item_id))


## The mark over the hero for an ailment (poison, burn, stun), or null.
static func ailment(kind: String) -> Texture2D:
	return _texture(_data()["ailments"].get(kind, ""))


## A skill's icon by its name, or null (no icon, or no paid art).
static func skill(skill_name: String) -> Texture2D:
	var code: String = _data()["skills"].get(skill_name, "")
	return _texture(skill_file(code)) if code != "" else null


## "Fire/9" -> its file in the Puny Skills pack, under retro-rpg/shade/.
static func skill_file(code: String) -> String:
	var theme := code.get_slice("/", 0)
	var prefix := "Buff" if theme == "Buffs&Debuffs" else theme
	return "puny-skills/Icons/Transparent Background/%s/%s-Icon-%03d.png" % [theme, prefix, int(code.get_slice("/", 1))]


static func _texture(src: String) -> Texture2D:
	if src == "":
		return null
	if _cache.has(src):
		return _cache[src]
	var where := resolve(src)
	if not ResourceLoader.exists(where["path"]):
		return null
	var art: Texture2D = load(where["path"])
	var icon := art
	var cell: Vector2i = where["cell"]
	if where["tile"] >= 0:
		icon = PunyProps.texture(where["tile"])
	elif cell.x >= 0:
		var region := AtlasTexture.new()
		region.atlas = art
		region.region = Rect2(cell * 16, Vector2(16, 16))
		icon = region
	_cache[src] = icon
	return icon


## One of Shade's animated effects (icons.json "effects": the flame, the
## embers, the smoke; PIX-151) as frames of 16 px cut along its strip, or
## null when the paid pack isn't installed (callers fall back).
static func effect(name: String, fps := 10.0, loop := true) -> SpriteFrames:
	var key := "effect:%s" % name
	if _cache.has(key):
		return _cache[key]
	var src: String = _data().get("effects", {}).get(name, "")
	var path := PRIVATE + src
	if src == "" or not ResourceLoader.exists(path):
		return null
	var strip: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", loop)
	for i in strip.get_width() / 16:
		var cell := AtlasTexture.new()
		cell.atlas = strip
		cell.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame("default", cell)
	_cache[key] = frames
	return frames


## Every file the paid packs must provide, relative to retro-rpg/shade/ (what
## the fetch script copies).
static func private_files() -> Array[String]:
	var files: Array[String] = []
	for group: String in ["items", "ailments", "effects"]:
		for src: String in _data().get(group, {}).values():
			if not src.begins_with("free/") and not src.begins_with("medieval@"):
				var file := src.get_slice("@", 0)
				if file not in files:
					files.append(file)
	for code: String in _data()["skills"].values():
		if skill_file(code) not in files:
			files.append(skill_file(code))
	return files
