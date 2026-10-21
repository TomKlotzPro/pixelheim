class_name SaveCodec
## areas: save
## Pixelheim's own save format, v5 (PIX-302): one JSON file a slot, a
## section for each part of the game - `hero`, `pack`, `home`, `town`,
## `story`, `quests`, `world`, `post` (the Pixelheim Post's, PIX-320, once
## it holds anything) and `buffs` - under a `card` the Saves screen reads
## without the rest, the play time and the game's version. The fog of war is
## a bitmap per map (`WorldState.pack_fog`). `PXH2.` save codes are that
## file compressed, with a checksum, so a code cut short or changed is
## caught rather than loaded.
##
## No older save loads until the beta (Tom, 2026-10-16): a file or a code
## from before v5 (the first edition's v1-v4 envelope, `PXH1.` codes) is
## said to be older and plays no one, and nothing reads what only an old
## save held (PIX-319: the old mountain's floors, the Deep Hunt, the old
## throne's endings, the first edition's catch-ups). Until then a field
## that needs more than an empty default bumps VERSION, with no migration
## (said in the release note); from the beta, compatibility comes back.
##
## In play the state is one Dictionary in the game's own keys (`to_dict`
## and `apply` in GameState, the sections' from_dict/write_into): `to_file`
## sorts it into the file's sections and `from_file` takes it back, so the
## file's shape is its own.

const VERSION := 5
const CODE_PREFIX := "PXH2."
## The codes before v5: the first edition's base64 JSON.
const OLD_CODE_PREFIX := "PXH1."
## What a file or a code is (`age`, `pasted`'s `problem`): this version's,
## a newer one's, an older one's (before v5), cut short or changed, or no
## save at all.
const CURRENT := "current"
const NEWER := "newer"
const OLDER := "older"
const DAMAGED := "damaged"
const NOT_A_SAVE := "none"
## A code's file is never bigger than this (a fully explored hero's is a
## few tens of KB): a code claiming more is refused before it's unpacked.
const MAX_CODE_BYTES := 8 * 1024 * 1024
## The hero's numbers, the same name in the state and the file.
const HERO_NUMBERS := ["level", "xp", "xpToNext", "hp", "mp", "stats", "statPoints", "skillPoints"]
## The hero's skills: the state's key -> the file's (hero.skills).
const SKILLS := {"skillDock": "dock", "beyond": "beyond", "forgot": "forgot", "path": "path", "spec": "spec", "mastery": "mastery"}
## The town's purse (the state's `investments`): its key -> the file's
## (town); anything else in it rides along in town.invested.
const INVESTED := {"savings": "bank", "tills": "tills", "expansions": "expansions", "venture": "venture"}
## The quest records: the state's key -> the file's (quests).
const RECORDS := {"tracked": "tracked", "deeds": "deeds", "firsts": "firsts", "crafted": "crafted", "hunted": "named", "met": "met"}

static var _game := ""


## A new game's state before a hero is made.
static func initial_state() -> Dictionary:
	return {
		"hero": null, "gold": 0, "inventory": {}, "gear": [], "equipped": {},
		"house": {"owned": false, "storage": {}}, "properties": [], "townTier": 1, "settlers": [],
		"quests": {}, "world": null, "worldSteps": 0, "playSeconds": 0,
	}


## Silent JSON parse (null on garbage) with integers restored.
static func parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return intify(json.data)


## JSON numbers arrive as floats; a save's integers must stay integers (a
## level of 3.0 isn't 3 to an `in`, and Godot would write it back `3.0`).
static func intify(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) and absf(value) < 9.0e15 else value
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = intify(value[key])
			return out
		TYPE_ARRAY:
			var out := []
			for entry: Variant in value:
				out.append(intify(entry))
			return out
	return value


## A save file's text: keys in the order they were put (JSON.stringify sorts
## them by default), so the card and the hero come first.
static func serialize(doc: Dictionary) -> String:
	return JSON.stringify(doc, "", false)


## The game's version, the newest in the changelog (read once).
static func game_version() -> String:
	if _game == "":
		var log: Variant = parse_json(FileAccess.get_file_as_string("res://assets/data/changelog.json"))
		var releases: Array = log.get("releases", []) if log is Dictionary else []
		_game = String(releases[0].get("version", "")) if not releases.is_empty() else "?"
	return _game


## The state as the file holds it: the sections, the card, the play time,
## the version and when it was saved. {} for a state with no hero to play
## or nowhere to stand (a bug's: the slot's read-back refuses it).
static func to_file(state: Dictionary, saved_at := 0) -> Dictionary:
	if not valid_hero(state.get("hero")) or not state.get("world") is Dictionary:
		return {}
	var hero: Dictionary = state["hero"]
	var hero_out := {"name": hero["name"], "role": hero["roleId"]}
	_put(hero_out, "look", hero.get("look"))
	for key: String in HERO_NUMBERS:
		hero_out[key] = hero[key]
	var skills := {"nodes": hero["skillNodes"]}
	for key: String in SKILLS:
		_put(skills, SKILLS[key], hero.get(key))
	hero_out["skills"] = skills
	hero_out["jobs"] = hero["jobs"]

	# The rest the inn and the bed give, and the bard's song: borrowed fields
	# in the state (the house's record, the town's), buffs here.
	var home: Dictionary = state["house"].duplicate()
	var buffs := {}
	_put(buffs, "rested", home.get("rested"))
	home.erase("rested")
	_put(buffs, "song", state.get("bardSong"))

	var town := {"age": state["townTier"], "settlers": state["settlers"], "properties": state["properties"]}
	_put(town, "projects", state.get("projects"))
	_put(town, "festival", state.get("festival"))
	var invested: Variant = state.get("investments")
	if invested is Dictionary:
		var rest: Dictionary = invested.duplicate()
		for key: String in INVESTED:
			if rest.has(key):
				town[INVESTED[key]] = rest[key]
				rest.erase(key)
		# The purse kept whole, even with nothing in it yet.
		if not rest.is_empty() or not INVESTED.keys().any(func(key: String) -> bool: return invested.has(key)):
			town["invested"] = rest

	var story := {}
	_put(story, "seen", state.get("storySeen"))
	_put(story, "prologue", state.get("prologue"))
	_put(story, "doused", state.get("prologueDoused"))
	# The Night of Bells while it runs (PIX-302 step 4): its beat, the
	# lanterns lit, the roofs doused, the embers left.
	_put(story, "night", state.get("bells"))

	var quests := {"ledger": state["quests"]}
	for key: String in RECORDS:
		_put(quests, RECORDS[key], state.get(key))

	var world: Dictionary = state["world"]
	var at: Dictionary = world["position"]
	var world_out := {
		"at": {"map": at["mapId"], "x": at["x"], "y": at["y"], "facing": at.get("facing", "down")},
		"steps": state["worldSteps"],
		"fog": world["discovered"],
		"chests": world["openedChests"],
		"slain": world["slain"],
	}
	_put(world_out, "slainAt", world.get("slainAt"))
	_put(world_out, "gatheredAt", world.get("gatheredAt"))

	var doc := {
		"pixelheim": VERSION,
		"game": game_version(),
		"savedAt": saved_at,
		"playSeconds": int(state.get("playSeconds", 0)),
		"card": card(state),
		"hero": hero_out,
		"pack": {"gold": state["gold"], "items": state["inventory"], "gear": state["gear"], "worn": state["equipped"]},
		"home": home,
		"town": town,
		"story": story,
		"quests": quests,
		"world": world_out,
	}
	# The Pixelheim Post's own section (PIX-320: the satchel, each thread's
	# step, what's delivered, the day the box was emptied), once it holds
	# anything.
	_put(doc, "post", state.get("post"))
	doc["buffs"] = buffs
	return doc


## What the Saves screen shows of a hero, rewritten with every save so it
## reads three small headers rather than three whole games: name, class,
## look and what they wear (the portrait as they left, PIX-175), level,
## where, the chapter and the time played. `chapter` is the one the main
## quest's next step is in: 0 on the Night of Ash, past the last (the
## chapters' count + 1) once the story is told.
static func card(state: Dictionary) -> Dictionary:
	var hero: Dictionary = state["hero"]
	return {
		"name": hero["name"],
		"role": hero["roleId"],
		"look": hero.get("look", 0),
		"worn": InventoryState.from_dict(state).worn_items(),
		"level": hero["level"],
		"place": state["world"]["position"]["mapId"],
		"chapter": chapter_of(state),
		"playSeconds": int(state.get("playSeconds", 0)),
	}


## The chapter a state is in (the card's).
static func chapter_of(state: Dictionary) -> int:
	if int(state.get("prologue", 0)) > 0:
		return 0
	var next := MainQuest.next_step(ProgressionState.from_dict(state), SettlementState.from_dict(state))
	return int(next["chapter_number"]) if not next.is_empty() else MainQuest.chapters().size() + 1


## The state a file holds, normalized; {} for anything but a v5 file with a
## hero this version plays.
static func from_file(raw: Variant) -> Dictionary:
	if age(raw) != CURRENT:
		return {}
	var doc: Dictionary = raw
	var hero_in := _section(doc, "hero")
	var skills := _section(hero_in, "skills")
	var hero := {"name": hero_in.get("name"), "roleId": hero_in.get("role")}
	_put(hero, "look", hero_in.get("look"))
	for key: String in HERO_NUMBERS:
		_put(hero, key, hero_in.get(key))
	hero["skillNodes"] = skills.get("nodes", [])
	for key: String in SKILLS:
		_put(hero, key, skills.get(SKILLS[key]))
	_put(hero, "jobs", hero_in.get("jobs"))
	if not valid_hero(hero):
		return {}
	var state := {"hero": hero, "playSeconds": int(doc.get("playSeconds", 0))}

	var pack := _section(doc, "pack")
	state["gold"] = pack.get("gold", 0)
	state["inventory"] = pack.get("items", {})
	state["gear"] = pack.get("gear", [])
	state["equipped"] = pack.get("worn", {})

	var buffs := _section(doc, "buffs")
	var house := _section(doc, "home")
	if house.is_empty():
		house = {"owned": false, "storage": {}}
	_put(house, "rested", buffs.get("rested"))
	state["house"] = house
	_put(state, "bardSong", buffs.get("song"))

	var town := _section(doc, "town")
	state["townTier"] = town.get("age", 1)
	state["settlers"] = town.get("settlers", [])
	state["properties"] = town.get("properties", [])
	_put(state, "projects", town.get("projects"))
	_put(state, "festival", town.get("festival"))
	if town.has("invested") or INVESTED.values().any(func(key: String) -> bool: return town.has(key)):
		var invested: Dictionary = town.get("invested", {}).duplicate()
		for key: String in INVESTED:
			_put(invested, key, town.get(INVESTED[key]))
		state["investments"] = invested

	var story := _section(doc, "story")
	_put(state, "storySeen", story.get("seen"))
	_put(state, "prologue", story.get("prologue"))
	_put(state, "prologueDoused", story.get("doused"))
	_put(state, "bells", story.get("night") if story.get("night") is Dictionary else null)

	var quests := _section(doc, "quests")
	state["quests"] = quests.get("ledger", {})
	for key: String in RECORDS:
		_put(state, key, quests.get(RECORDS[key]))

	var world := _section(doc, "world")
	var at := _section(world, "at")
	state["worldSteps"] = world.get("steps", 0)
	# A world with nowhere to stand wakes in town (normalize).
	state["world"] = null
	if at.get("map") is String:
		state["world"] = {
			"position": {"mapId": at["map"], "x": int(at.get("x", 0)), "y": int(at.get("y", 0)), "facing": at.get("facing", "down")},
			"discovered": world.get("fog", {}),
			"openedChests": world.get("chests", []),
			"slain": world.get("slain", []),
		}
		_put(state["world"], "slainAt", world.get("slainAt"))
		_put(state["world"], "gatheredAt", world.get("gatheredAt"))
	# The Post (PIX-320): a file without the section has none yet.
	_put(state, "post", doc.get("post") if doc.get("post") is Dictionary else null)
	return normalize(state)


## What `raw` (a parsed file) is: CURRENT (a v5 file), NEWER (a later
## version's), OLDER (the first edition's envelope or bare state, before
## v5), or "" (no save at all).
static func age(raw: Variant) -> String:
	if not raw is Dictionary:
		return ""
	var version: Variant = raw.get("pixelheim")
	if typeof(version) in [TYPE_INT, TYPE_FLOAT]:
		if int(version) == VERSION:
			return CURRENT
		return NEWER if int(version) > VERSION else OLDER
	if raw.get("state") is Dictionary and typeof(raw.get("version")) in [TYPE_INT, TYPE_FLOAT]:
		return OLDER
	if raw.get("hero") is Dictionary and raw["hero"].has("roleId"):
		return OLDER
	return ""


## Whether a slot file's text, just written, reads back as a hero this
## version plays (PIX-303): JSON that parses, a v5 file with its card, and a
## hero `from_file` would take (a bug that broke the state writes a save no
## one could load). Godot's own parse, without `parse_json`'s integers: the
## check needs none of them.
static func decodes(text: String) -> bool:
	var json := JSON.new()
	if json.parse(text) != OK or age(json.data) != CURRENT:
		return false
	var doc: Dictionary = json.data
	var hero := _section(doc, "hero")
	return (
		doc.get("card") is Dictionary and _section(hero, "skills").get("nodes") is Array
		and valid_hero({
			"name": hero.get("name"), "roleId": hero.get("role"), "level": hero.get("level"), "xp": hero.get("xp"),
			"xpToNext": hero.get("xpToNext"), "hp": hero.get("hp"), "mp": hero.get("mp"), "stats": hero.get("stats"),
			"statPoints": hero.get("statPoints"), "skillPoints": hero.get("skillPoints"), "jobs": hero.get("jobs"),
		})
		and _section(_section(doc, "world"), "at").get("map") is String
	)


## Rebases a state on the current defaults: a field with an empty default
## needs no version bump, it picks it up here. A save with nowhere to stand
## wakes up in town.
static func normalize(state: Dictionary) -> Dictionary:
	if not valid_hero(state.get("hero")):
		return {}
	var save := initial_state()
	save.merge(state, true)
	if not save["world"] is Dictionary:
		save["world"] = fresh_world()
	return save


## A save's world record standing at the town spawn, its surroundings seen.
static func fresh_world() -> Dictionary:
	var spawn := Catalog.town_spawn()
	var discovered := {}
	Discovery.discover_around(discovered, MapData.load_by_id(spawn["mapId"]), Vector2i(spawn["x"], spawn["y"]))
	return {
		"position": spawn.duplicate(),
		"discovered": WorldState.pack_all(discovered),
		"openedChests": [],
		"slain": [],
	}


## A hero the game could not play (a field missing, an unknown role) is
## refused: nothing patches one up (PIX-319: the first edition's heroes
## caught up as they loaded; a v5 file has every field).
static func valid_hero(hero: Variant) -> bool:
	if not hero is Dictionary:
		return false
	for key in ["name", "roleId", "level", "xp", "xpToNext", "hp", "mp", "statPoints", "skillPoints"]:
		if hero.get(key) == null:
			return false
	return hero.get("stats") is Dictionary and hero.get("jobs") is Dictionary and not Catalog.role(str(hero["roleId"])).is_empty()


## A copy-pastable code, to carry a hero to another computer or browser:
## `PXH2.` and, in base64, a checksum (4 bytes of the SHA-256 of the rest),
## the file's size (4 bytes) and the file deflated.
static func encode_code(state: Dictionary) -> String:
	var raw := serialize(to_file(state, int(Time.get_unix_time_from_system()))).to_utf8_buffer()
	var body := PackedByteArray()
	body.resize(4)
	body.encode_u32(0, raw.size())
	body.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return CODE_PREFIX + Marshalls.raw_to_base64(_checksum(body) + body)


## What a player pasted, read: `{state, problem}`, the state normalized
## when it's a hero to play ({} otherwise) and `problem` "" or why not:
## OLDER (a `PXH1.` code or an old save's JSON: before this update), NEWER,
## DAMAGED (a code cut short or changed, which its checksum catches, or a
## file that won't play) or NOT_A_SAVE. Takes a `PXH2.` code, spaces and
## line breaks a chat put in it forgiven, or a v5 file's JSON.
static func pasted(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.begins_with("{"):
		var raw: Variant = parse_json(trimmed)
		return _read(raw)
	var squeezed := RegEx.create_from_string("\\s+").sub(trimmed, "", true)
	if squeezed.begins_with(OLD_CODE_PREFIX):
		return {"state": {}, "problem": OLDER}
	if not squeezed.begins_with(CODE_PREFIX):
		return {"state": {}, "problem": NOT_A_SAVE}
	var payload := squeezed.substr(CODE_PREFIX.length())
	# Checked first: Godot's decoders log engine errors on malformed input.
	var base64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if payload.length() % 4 != 0 or base64.search(payload) == null:
		return {"state": {}, "problem": DAMAGED}
	var bytes := Marshalls.base64_to_raw(payload)
	if bytes.size() < 9:
		return {"state": {}, "problem": DAMAGED}
	var body := bytes.slice(4)
	if bytes.slice(0, 4) != _checksum(body):
		return {"state": {}, "problem": DAMAGED}
	var size := body.decode_u32(0)
	if size == 0 or size > MAX_CODE_BYTES:
		return {"state": {}, "problem": DAMAGED}
	var raw := body.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return {"state": {}, "problem": DAMAGED}
	return _read(parse_json(raw.get_string_from_utf8()))


## A pasted code or a file's JSON as a state to play; {} when it's none
## (the harness's `--load`, the fixtures).
static func parse_any(text: String) -> Dictionary:
	return pasted(text)["state"]


## The state a save of `state` loads as: written as a file's text and read
## back, as a slot does without the disk (the tests' save and load).
static func reread(state: Dictionary) -> Dictionary:
	return from_file(parse_json(serialize(to_file(state))))


## A parsed file, read as `pasted` says it.
static func _read(raw: Variant) -> Dictionary:
	match age(raw):
		CURRENT:
			var state := from_file(raw)
			return {"state": state, "problem": "" if not state.is_empty() else DAMAGED}
		NEWER, OLDER:
			return {"state": {}, "problem": age(raw)}
	return {"state": {}, "problem": NOT_A_SAVE}


## A code's checksum: the first 4 bytes of the SHA-256 of `bytes`.
static func _checksum(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().slice(0, 4)


## `value` into `into[key]`, unless there's none (absent stays absent).
static func _put(into: Dictionary, key: String, value: Variant) -> void:
	if value != null:
		into[key] = value


## A section of the file, {} when it's missing or not a section.
static func _section(doc: Dictionary, key: String) -> Dictionary:
	var section: Variant = doc.get(key)
	return section if section is Dictionary else {}
