class_name Story
## The Ember Seal told through play (PIX-153): the pages of Liane's journal
## found on the floors (one per floor's first clear, kept in the journal's
## Story tab), what Maren has to say as the hero learns more - the graves,
## the seal, her confession, and her last words - and how the hero chose to
## end it at Morvax's throne (PIX-157). Pure, over story.json's "lore" and
## "elderLines"; scenes and moments stay with Cutscene.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/story.json")))
	return _doc


static func lore() -> Array:
	return _data()["lore"]


## The page a floor's first clear turns up, or {}.
static func page_for(level: int) -> Dictionary:
	for page: Dictionary in lore():
		if int(page["floor"]) == level:
			return page
	return {}


## The pages a hero has found: one for each cleared floor that hides one.
static func found_pages(cleared_levels: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for page: Dictionary in lore():
		if int(page["floor"]) in cleared_levels:
			out.append(page)
	return out


## The dream a night's rest brings (PIX-154): the first one earned and not yet
## dreamt - the first night after the Night of Ash, then after the crypt,
## then after the forge - or "" when there's none.
static func next_dream(cleared_levels: Array, seen: Array) -> String:
	for dream: Dictionary in _data()["dreams"]:
		var earned := int(dream["after"]) == 0 or int(dream["after"]) in cleared_levels
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


## How the hero ended it at Morvax's throne (PIX-157): "rest", "destroy",
## or "" before. The ending played is in the story ledger; a hero who saw
## the old single ending destroyed him.
static func ending_of(seen: Array) -> String:
	if Cutscene.moment("victory:rest") in seen:
		return "rest"
	if Cutscene.moment("victory") in seen:
		return "destroy"
	return ""


## The ending scene for a choice.
static func ending_scene(choice: String) -> String:
	return Cutscene.moment("victory:rest" if choice == "rest" else "victory")


## Whether the hero knows enough of Morvax to lay him to rest: Maren's
## story of the five, and Liane's last page.
static func can_lay_to_rest(cleared_levels: Array, seen: Array) -> bool:
	var last_page: Dictionary = lore()[-1]
	return "maren_confession" in seen and int(last_page["floor"]) in cleared_levels
