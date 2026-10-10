class_name Text
## The game in more than one language (PIX-195). English is the source and
## its own key (gettext's msgid): godot/locale/<lang>.po maps each English
## string to the language's, and tools/i18n.py keeps locale/messages.pot -
## every string there is to translate - current.
## - A label or button holding a fixed English string translates itself
##   (Godot's auto-translation).
## - A string built from a format goes through `Text.t` (or `tr` on a node)
##   before its values go in: "Quest accepted: %s." is translated, then filled.
## - The data's words (names, lines, descriptions...) are translated as they
##   load (`localize`); a language switch reloads them.

## Bumped each time the language changes, for caches kept outside these
## modules (the world's hints) to know they're stale.
static var generation := 0
## The languages the game speaks, by code.
const LANGUAGES := {"en": "English", "fr": "Français"}
## Keys whose strings are ids, file paths, colours or music, never words.
const NOT_WORDS := [
	"id", "sprite", "sheet", "mapId", "kind", "version", "date", "category", "itemId", "monsterId", "tiles",
	"pieces", "slot", "stat", "requires", "map", "giver", "from", "roleId", "branch", "species", "to", "look",
	"scaling", "sells", "set", "stage", "wave", "move", "shape", "color", "named", "phases", "opensAfter", "drop",
	"family", "anim", "dir", "questId", "who", "icon", "facing", "then", "ending", "sceneId", "region", "shop",
	"projectId", "settles", "upgrades", "hunted", "items", "summon", "prizeItem", "requiresSettler", "about",
	"rewardItemIds", "gearIds", "stackIds", "foes", "floorMaterials", "catches", "cures", "beds", "stingers",
	"bossIds", "resource", "rugs", "tile", "unlock", "inflicts", "effect",
]


## A place's name inside a sentence (PIX-196): its leading article in lower
## case - "the Frostgate Pass", « la Cave moussue » - not "The", « La ».
static func mid(name: String) -> String:
	for article: String in ["The ", "La ", "Le ", "Les ", "L’", "L'"]:
		if name.begins_with(article):
			return article.to_lower() + name.substr(article.length())
	return name


## `text` in the player's language (itself where there's no translation).
static func t(text: String) -> String:
	return TranslationServer.translate(text) if text != "" else text


## Items of a list inside a sentence, joined by semicolons: "the square; the
## rents", with French's narrow no-break space before each, « la place ; les
## loyers ».
static func listed(parts: PackedStringArray) -> String:
	var sep := "\u202f; " if TranslationServer.get_locale().begins_with("fr") else "; "
	return sep.join(parts)


## A compact gold amount, as costs show it: "55g", « 55 o ».
static func coins(amount: int) -> String:
	return t("%dg") % amount


## Whether a data string is words a player reads: it has a capital or a
## space (ids are lower_snake), and its key isn't one that holds ids.
static func is_words(key: String, value: String) -> bool:
	if key in NOT_WORDS:
		return false
	return value != value.to_lower() or " " in value


## The data's words translated in place, as a document loads.
static func localize(doc: Variant) -> Variant:
	if TranslationServer.get_locale().begins_with("en") and not TranslationServer.pseudolocalization_enabled:
		return doc
	_walk(doc, "")
	return doc


static func _walk(value: Variant, key: String) -> void:
	if value is Dictionary:
		for k: Variant in value:
			var v: Variant = value[k]
			var name := str(k)
			if v is String:
				if is_words(name, v):
					value[k] = t(v)
			else:
				_walk(v, name)
	elif value is Array:
		for i in value.size():
			var v: Variant = value[i]
			if v is String:
				if is_words(key, v):
					value[i] = t(v)
			else:
				_walk(v, key)


## The language a choice comes to: one the game speaks, or for "" the
## system's (a French browser plays in French), else English.
static func language_for(choice: String) -> String:
	if LANGUAGES.has(choice):
		return choice
	var system := OS.get_locale_language()
	return system if LANGUAGES.has(system) else "en"


## Speaks `choice` from now on; the data loaded in the old language is read
## again on its next use.
static func apply(choice: String) -> void:
	TranslationServer.set_locale(language_for(choice))
	forget()


## Every cached data document, dropped (they reload translated).
static func forget() -> void:
	Catalog._doc = {}
	Quests._doc = {}
	Npcs._doc = {}
	Bestiary._doc = {}
	Economy._doc = {}
	Town._doc = {}
	Story._doc = {}
	Interactables._doc = {}
	Depths._doc = {}
	Ranks._doc = {}
	Gates._doc = {}
	Bestiary._found = {}
	Dungeons._deep = {}
	Bestiary._found_floors = {}
	Bestiary._found_at_night = {}
	generation += 1
