class_name Story
## The Ember Seal told through play (PIX-153): the pages of Liane's journal
## found on the floors (one per floor's first clear, kept in the journal's
## Story tab), and what Maren has to say as the hero learns more - the
## graves, the seal, her confession, and peace. Pure, over story.json's
## "lore" and "elderLines"; scenes and moments stay with Cutscene.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/story.json"))
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


## What Maren has to tell now: the deepest of her stories the hero's floors
## have reached ({id, lines}), or {} before the crypt. Each is told once
## (its id goes in the story ledger); after that she talks as usual.
static func elder_story(cleared_levels: Array, seen: Array) -> Dictionary:
	var latest := {}
	for entry: Dictionary in _data()["elderLines"]:
		if int(entry["after"]) in cleared_levels:
			latest = entry
	if latest.is_empty() or latest["id"] in seen:
		return {}
	return latest
