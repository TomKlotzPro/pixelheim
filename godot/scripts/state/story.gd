class_name Story
## The Ember Seal told through play (PIX-153): the pages of Liane's journal
## found on the floors (one per floor's first clear; retired from play with
## Maren's letters, PIX-253 step 2, and kept for a hero who cleared their
## floors as the journal's older papers), what Maren has to say as the hero
## learns more - each relic's story, and her last words - and how the hero
## chose to end it: Morvax's choice (PIX-253 step 10, Homecoming), or for
## an old save at his throne (PIX-157). Her stories of the old
## mountain's floors (the graves, the seal) left play with them (PIX-257);
## her confession is told at the shrine once the four keepsakes are home
## (Letters, PIX-253 step 8). Pure, over story.json's "lore" and
## "elderLines"; scenes and moments stay with Cutscene.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/story.json")))
	return _doc


static func lore() -> Array:
	return _data()["lore"]


## The pages a hero has found: one for each cleared floor that hides one.
static func found_pages(cleared_levels: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for page: Dictionary in lore():
		if int(page["floor"]) in cleared_levels:
			out.append(page)
	return out


## The dream a night's rest brings (PIX-154): the first one earned and not yet
## dreamt - the first night after the Night of Ash (Morvax's voice by his
## lamp up the mountain, PIX-253 step 8) - or "" when there's none. Since
## the story's letters (PIX-253 step 5) a dream may come once someone is
## home instead (`home`, a settler's id among `settlers`): the old man
## counting lamps, after Old Pell moves in; the dragon on his corners,
## after Aske. (The two the old mountain's floors earned left play with
## them, PIX-257: `after` a floor still reads for any that would say so.)
static func next_dream(cleared_levels: Array, seen: Array, settlers := []) -> String:
	for dream: Dictionary in _data()["dreams"]:
		var earned := String(dream["home"]) in settlers if dream.has("home") else (
			int(dream["after"]) == 0 or int(dream["after"]) in cleared_levels)
		if earned and dream["id"] not in seen:
			return dream["id"]
	return ""


## What Maren has to tell now: a relic's story once its boss is laid low
## (PIX-170: Tam, the iron, Oskar, Liane - whichever came home first), else
## the oldest of her stories the hero's floors have earned and she hasn't
## told yet ({id, lines}), or {} before the crypt. One a visit, oldest first
## (PIX-279): she used to tell only the deepest, so a hero who went past the
## watchtower before calling on her never heard the graves, and the main
## quest's step that waits on them could never be met. Each is told once
## (its id goes in the story ledger); after that she talks as usual. Her
## last words depend on the ending the hero chose (PIX-157), and once it's
## played they're all she has left to say: the stories that sent the hero
## down would ring false after it.
static func elder_story(cleared_levels: Array, seen: Array, hunted := []) -> Dictionary:
	for entry: Dictionary in _data()["elderLines"]:
		if entry.has("hunted") and entry["hunted"] in hunted and entry["id"] not in seen:
			return entry
	var ending := ending_of(seen)
	for entry: Dictionary in _data()["elderLines"]:
		if not entry.has("after") or entry["id"] in seen or int(entry["after"]) not in cleared_levels:
			continue
		if String(entry.get("ending", "")) == ending:
			return entry
	return {}


## How the hero ended it: Morvax's choice (PIX-253 step 10), "home" or
## "stay"; the old game's, at his throne (PIX-157), "rest" or "destroy"; or
## "" before. The ending played is in the story ledger; a hero who saw the
## old single ending destroyed him. Asked whenever the main quest looks for
## its next step (twice a second, by the line above the dock), so it reads
## the moments from this class's own copy of story.json, not Cutscene's
## (parsed afresh each time).
static func ending_of(seen: Array) -> String:
	for choice: String in [Homecoming.HOME, Homecoming.STAY]:
		if _moment("ending:" + choice) in seen:
			return choice
	if _moment("victory:rest") in seen:
		return "rest"
	if _moment("victory") in seen:
		return "destroy"
	return ""


## The ending scene for a choice: Morvax's two (story.json's moments
## `ending:home`, `ending:stay`), and the old throne's for its own.
static func ending_scene(choice: String) -> String:
	match choice:
		Homecoming.HOME, Homecoming.STAY:
			return _moment("ending:" + choice)
		"rest":
			return _moment("victory:rest")
	return _moment("victory")


## The scene a moment of play calls for (Cutscene.moment's, read once).
static func _moment(key: String) -> String:
	return String(_data()["moments"].get(key, ""))
