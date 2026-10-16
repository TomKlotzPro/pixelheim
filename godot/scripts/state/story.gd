class_name Story
## The Ember Seal told through play (PIX-153): what Maren has to say as the
## hero learns more - each relic's story - and how the hero chose to end it:
## Morvax's choice (PIX-253 step 10, Homecoming). Her stories of the old
## mountain's floors (the graves, the seal) left play with them (PIX-257),
## and Liane's pages found there, her last words after the old throne and
## its endings with the old saves that held them (PIX-319); her confession
## is told at the shrine once the four keepsakes are home (Letters, PIX-253
## step 8). Pure, over story.json's "elderLines" and "dreams"; scenes and
## moments stay with Cutscene.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/story.json")))
	return _doc


## The dream a night's rest brings (PIX-154): the first one earned and not yet
## dreamt - the first night after the Night of Ash (Morvax's voice by his
## lamp up the mountain, PIX-253 step 8) - or "" when there's none. Since
## the story's letters (PIX-253 step 5) a dream may come once someone is
## home instead (`home`, a settler's id among `settlers`): the old man
## counting lamps, after Old Pell moves in; the dragon on his corners,
## after Aske. (The two the old mountain's floors earned left play with
## them, PIX-257.)
static func next_dream(seen: Array, settlers := []) -> String:
	for dream: Dictionary in _data()["dreams"]:
		var earned := String(dream["home"]) in settlers if dream.has("home") else true
		if earned and dream["id"] not in seen:
			return dream["id"]
	return ""


## What Maren has to tell now: a relic's story once its boss is laid low
## (PIX-170: Tam, the iron, Oskar, Liane - whichever came home first,
## {id, lines}), or {}. One a visit, oldest first (PIX-279). Each is told
## once (its id goes in the story ledger); after that she talks as usual.
static func elder_story(seen: Array, hunted := []) -> Dictionary:
	for entry: Dictionary in _data()["elderLines"]:
		if entry.has("hunted") and entry["hunted"] in hunted and entry["id"] not in seen:
			return entry
	return {}


## How the hero ended it: Morvax's choice (PIX-253 step 10), "home" or
## "stay", or "" before. The ending played is in the story ledger. Asked
## whenever the main quest looks for its next step (twice a second, by the
## line above the dock), so it reads the moments from this class's own copy
## of story.json, not Cutscene's (parsed afresh each time).
static func ending_of(seen: Array) -> String:
	for choice: String in [Homecoming.HOME, Homecoming.STAY]:
		if _moment("ending:" + choice) in seen:
			return choice
	return ""


## The ending scene for a choice: Morvax's two (story.json's moments
## `ending:home`, `ending:stay`).
static func ending_scene(choice: String) -> String:
	return _moment("ending:" + choice)


## The scene a moment of play calls for (Cutscene.moment's, read once).
static func _moment(key: String) -> String:
	return String(_data()["moments"].get(key, ""))
