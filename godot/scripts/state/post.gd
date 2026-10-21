class_name Post
## areas: town story quest save
## The Pixelheim Post (PIX-320, Something to Come Back To's first step):
## once Maren's first letter reaches Saltmere, the Reach finds out it has a
## courier again, and a post box goes up on Pixelheim's square. Each game
## morning it holds a small bag of letters and parcels between the Reach's
## people, from threads that run on for days (twelve since PIX-321, every
## place in at least two: Bram's Cheese Club, Wenna and Pell, Pip and the
## dragon, Maren and Wenna's everything else, Rook's wet rope, Mirelle's
## gentle reminders, Vex's reagents, Wren's horses, Dagny's ore for Hilda,
## Fenwick in charge of Greyhold, the Cheese Club's song, and Maren and
## Morvax counting the lamps). E at the box takes them into the satchel; E
## beside a piece's addressee hands it over, for a line, a small tip,
## sometimes a thing to keep and sometimes a reply to carry back, and
## stamps the courier's book: a page per place, its postmark inked the day
## the first piece reached it. The calm rules hold throughout: nothing
## expires, there is no timer, and a day skipped costs nothing.
## Which pieces the box holds is worked out from the day (DayNight's, as
## the patches are dealt), the data's seed and the threads: each thread
## offers its next piece once the one before it is delivered (and, for one
## that says `after`, another thread's piece too), never a piece already
## in the satchel, and only between people who stand where the hero has
## been, past no gate still shut (Gates), with what it waits on in the
## story met. So only what the hero did is saved (PostState). Pure, over
## assets/data/post.json; GameState's `posting` takes and hands over,
## MapView draws the box, the journal's Post and Postmarks tabs and the map
## read it. The roads it's carried along grow signposts and waystations
## (PIX-322): Routes. Once one has a waystation the board offers the post
## house (PIX-325): built, the box holds a bigger bag, and Pip's loft
## writes a thread of its own. After the story (PIX-326) the Reach keeps writing:
## Maren to the families once a week, Morvax from his bench or his forge
## (a thread for each answer: `ending`), Fafnyr on cheese, and the Kings'
## Vault's heirlooms going home to the families whose marks they carry;
## and Fafnyr flies the furthest piece of each day's post himself (the
## Dragon Post).

static var _doc := {}
## Piece id -> {piece, thread (its id), index (its place in the thread)}.
static var _pieces := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/post.json")))
		_pieces = {}
		for thread: Dictionary in _doc["threads"]:
			var pieces: Array = thread["pieces"]
			for index in pieces.size():
				_pieces[pieces[index]["id"]] = {"piece": pieces[index], "thread": thread["id"], "index": index}
	return _doc


## Every thread, in the data's order.
static func threads() -> Array:
	return _data()["threads"]


static func thread(thread_id: String) -> Dictionary:
	for entry: Dictionary in threads():
		if entry["id"] == thread_id:
			return entry
	return {}


## A piece by its id, {} for none.
static func piece(piece_id: String) -> Dictionary:
	_data()
	return _pieces.get(piece_id, {}).get("piece", {})


## The thread a piece belongs to, by id ("" for none).
static func thread_of(piece_id: String) -> String:
	_data()
	return String(_pieces.get(piece_id, {}).get("thread", ""))


## Whether the Post is open for this hero: Maren's first letter has reached
## Saltmere (post.json's `opens`, as a main quest step asks it).
static func open(progression: ProgressionState, settlement: SettlementState) -> bool:
	return MainQuest.holds(_data()["opens"], progression, settlement)


## What the log says as the Post opens.
static func opened_line() -> String:
	return String(_data()["opened"])


## Where the post box stands: its map, and its cell there.
static func box_map() -> String:
	return String(_data()["box"]["mapId"])


static func box_cell() -> Vector2i:
	var at: Dictionary = _data()["box"]
	return Vector2i(int(at["x"]), int(at["y"]))


## Where the post house stands once built (PIX-325): the two cells behind
## the box, the box before its left half.
static func house_cells() -> Array[Vector2i]:
	var at := box_cell() + Vector2i.UP
	return [at, at + Vector2i.RIGHT]


## How many pieces the box holds at most of a morning: more once the post
## house stands (PIX-325: Wren's riders bring the post in at dawn).
static func bag_size(settlement: SettlementState) -> int:
	var house: Dictionary = _data()["house"]
	return int(house["bag"] if house_built(settlement) else _data()["bag"])


## Whether the post house stands on the square (PIX-325): its work built.
static func house_built(settlement: SettlementState) -> bool:
	return String(_data()["house"]["work"]) in Town.done_projects(settlement)


## The day `steps` falls on (DayNight's, a night's sleep ending it): the
## morning the box fills again.
static func day_of(steps: float) -> int:
	return Gathering.day_of(steps)


## The villager a correspondent's post is handed to (Fafnyr's: Hilda, on
## whose chimney he warms himself).
static func npc_of(correspondent_id: String) -> String:
	return String(_data()["correspondents"].get(correspondent_id, {}).get("npc", ""))


## What a correspondent is called among friends ("Bram", "Fafnyr"): what a
## signpost on a post road is named after (PIX-322, Routes).
static func name_of(correspondent_id: String) -> String:
	return String(_data()["correspondents"].get(correspondent_id, {}).get("name", ""))


## Who a piece is handed to, by villager id.
static func addressee(entry: Dictionary) -> String:
	return npc_of(String(entry.get("to", "")))


## Who sent a piece, by villager id.
static func sender(entry: Dictionary) -> String:
	return npc_of(String(entry.get("from", "")))


## The piece a thread offers next (the one after those delivered), {} once
## it's told.
static func next_of(thread_id: String, post: PostState) -> Dictionary:
	var pieces: Array = thread(thread_id).get("pieces", [])
	var at := post.step(thread_id)
	return pieces[at] if at < pieces.size() else {}


## Where a villager stands now (`mapId`, `x`, `y`), the projects built
## deciding where a keeper trades, and Coming Home where Morvax is (his
## forge, or his bench by the fountain: Homecoming.place): {} for no one.
static func spot(npc_id: String, progression: ProgressionState, settlement: SettlementState) -> Dictionary:
	if npc_id == Homecoming.MORVAX:
		var at := Homecoming.place(progression)
		return {"id": npc_id, "mapId": at["mapId"], "x": at["x"], "y": at["y"]}
	return Npcs.by_id(npc_id, settlement.settlers, Town.done_projects(settlement))


## Whether a villager is where they live now, to post a letter or take one:
## on their map as the town's age and the settlers have it (Pip moves into
## the Village; a settler home in town, or still where they were found).
## Morvax is always somewhere (Homecoming.place).
static func present(npc_id: String, progression: ProgressionState, settlement: SettlementState) -> bool:
	if npc_id == Homecoming.MORVAX:
		return true
	var at := spot(npc_id, progression, settlement)
	if at.is_empty():
		return false
	for npc: Dictionary in Npcs.on_map(String(at["mapId"]), settlement.town_tier, settlement.settlers, Town.done_projects(settlement)):
		if npc["id"] == npc_id:
			return true
	return false


## Whether the hero has been to `map_id`: set foot there (the fog of war has
## it), or it's a room of a place they have (the village's always: they
## live there).
static func reached(map_id: String, discovered: Dictionary) -> bool:
	var place := Catalog.place_name(map_id)
	if place == Catalog.place_name("town"):
		return true
	for seen_id: String in discovered:
		if not (discovered[seen_id] as Dictionary).is_empty() and (seen_id == map_id or Catalog.place_name(seen_id) == place):
			return true
	return false


## Whether a piece can go out to `npc_id` now: they stand where they live,
## somewhere the hero has been, and no gate the story keeps shut stands
## between the Reach and them.
static func reachable(npc_id: String, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> bool:
	if not present(npc_id, progression, settlement):
		return false
	var at := spot(npc_id, progression, settlement)
	var map_id := String(at["mapId"])
	if not reached(map_id, discovered):
		return false
	return Gates.in_the_way(map_id, Vector2i(int(at["x"]), int(at["y"])), progression, settlement, discovered).is_empty()


## Whether what a piece waits on in the story is met (`when`: a main quest
## step's kinds of condition, all of them).
static func waits_over(entry: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	for when: Dictionary in entry.get("when", []):
		if not MainQuest.holds(when, progression, settlement):
			return false
	return true


## Whether the box may hold `entry` this morning: posted (not a reply,
## which comes back in the satchel as the piece before it is handed over),
## the piece it comes `after` delivered, what it waits on in the story met,
## and both ends reachable: the courier carries post between people where
## they have been (PIX-321: the Frostgate's caravan writes once the hero
## has walked the pass, never from behind the avalanche).
static func ready(entry: Dictionary, post: PostState, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> bool:
	if entry.is_empty() or entry.get("reply", false):
		return false
	if entry.has("after") and String(entry["after"]) not in post.delivered:
		return false
	if not waits_over(entry, progression, settlement):
		return false
	return reachable(sender(entry), progression, settlement, discovered) and reachable(addressee(entry), progression, settlement, discovered)


## The pieces the threads offer now, in the threads' order: each thread's
## next, when it's ready and not already in the satchel, from the threads
## this hero's story has (`for_hero`). Given a day, a thread that posts
## once a week (`every`, PIX-326: Maren's) offers only on its mornings.
static func offered(post: PostState, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary, day := -1) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in threads():
		if not for_hero(entry, progression) or (day >= 0 and posmod(day, int(entry.get("every", 1))) != 0):
			continue
		var next := next_of(String(entry["id"]), post)
		if not next.is_empty() and String(next["id"]) not in post.bag and ready(next, post, progression, settlement, discovered):
			out.append(String(next["id"]))
	return out


## Whether a thread is in this hero's story (PIX-326): one that says an
## `ending` is told only after that answer to Morvax (his letters from the
## bench by the fountain, or from his forge).
static func for_hero(entry: Dictionary, progression: ProgressionState) -> bool:
	return String(entry.get("ending", "")) in ["", Homecoming.chosen(progression)]


## Whether every piece of a thread is delivered.
static func told(thread_id: String, post: PostState) -> bool:
	return post.step(thread_id) >= (thread(thread_id).get("pieces", []) as Array).size()


## Up to `count` of `ids` for day `day`: the same day always draws the same,
## shuffled by the day and the seed, kept in the order they were offered.
static func pick(ids: Array[String], day: int, count: int) -> Array[String]:
	var deck := ids.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:post:%d" % [int(_data()["seed"]), day])
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: String = deck[i]
		deck[i] = deck[j]
		deck[j] = held
	var drawn := deck.slice(0, count)
	var out: Array[String] = []
	for id: String in ids:
		if id in drawn:
			out.append(id)
	return out


## What the post box holds on day `day`: nothing before the Post opens or
## once the day's post has been taken, else the day's pick of what the
## threads offer.
static func in_box(post: PostState, day: int, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> Array[String]:
	if not open(progression, settlement) or post.taken >= day:
		return []
	return pick(offered(post, progression, settlement, discovered, day), day, bag_size(settlement))


## The day's post taken from the box into the satchel (`ids`, what it
## held): the box is empty until the next morning.
static func take(post: PostState, ids: Array[String], day: int) -> void:
	for id: String in ids:
		if id not in post.bag:
			post.bag.append(id)
	post.taken = day


# ---- The Dragon Post (PIX-326) -----------------------------------------------------

## Whether Fafnyr carries post for this hero: the story over (post.json's
## dragon `opens`, Morvax's answer given).
static func dragon_open(progression: ProgressionState, settlement: SettlementState) -> bool:
	return MainQuest.holds(_data()["dragon"]["opens"], progression, settlement)


## Whom Fafnyr flies a piece of the day's post (`ids`) to, by villager id:
## the one going furthest, the latest page of the courier's book where
## they stand; never anyone in the village (it's a walk), "" for none.
static func dragon_pick(ids: Array[String], progression: ProgressionState, settlement: SettlementState) -> String:
	var places := book().map(func(entry: Dictionary) -> String: return entry["place"])
	var best := ""
	var furthest := 0
	for id: String in ids:
		var npc_id := addressee(piece(id))
		var at := places.find(place_for(npc_id, progression, settlement))
		if at > furthest:
			best = npc_id
			furthest = at
	return best


## Whether the day's dragon-borne piece arrives a little on fire: one day in
## three, the same day always the same.
static func on_fire(day: int) -> bool:
	return posmod(hash("%d:fire:%d" % [int(_data()["seed"]), day]), 3) == 0


## What the log says as Fafnyr takes a piece to `place` (a place's name),
## and on a day it's on fire, how it arrives.
static func flown_lines(place: String, day: int) -> Array[String]:
	var dragon: Dictionary = _data()["dragon"]
	var out: Array[String] = [String(dragon["flown"]) % place]
	if on_fire(day):
		var fire: Array = dragon["fire"]
		out.append(String(fire[posmod(day, fire.size())]))
	return out


## The piece in the satchel for `npc_id`, {} for none: the first taken
## that's its thread's next to hand over.
static func carried_for(post: PostState, npc_id: String) -> Dictionary:
	for id: String in post.bag:
		var entry := piece(id)
		if not entry.is_empty() and addressee(entry) == npc_id and String(next_of(thread_of(id), post).get("id", "")) == id:
			return entry
	return {}


## A piece handed over: out of the satchel, its thread on a step, kept to
## read; and the reply that follows it, if one does, into the satchel to
## carry back. Returns the reply ({} for none); nothing changes for a piece
## that isn't carried or isn't its thread's next.
static func hand_over(post: PostState, piece_id: String) -> Dictionary:
	var thread_id := thread_of(piece_id)
	if piece_id not in post.bag or thread_id == "" or String(next_of(thread_id, post).get("id", "")) != piece_id:
		return {}
	post.bag.erase(piece_id)
	post.threads[thread_id] = post.step(thread_id) + 1
	post.delivered.append(piece_id)
	var next := next_of(thread_id, post)
	if not next.is_empty() and next.get("reply", false):
		post.bag.append(String(next["id"]))
		return next
	return {}


## Where a piece goes now: the place its addressee stands in ("" for none).
static func where(entry: Dictionary, progression: ProgressionState, settlement: SettlementState) -> String:
	var at := spot(addressee(entry), progression, settlement)
	return Catalog.place_name(String(at["mapId"])) if not at.is_empty() else ""


## The villagers the satchel's pieces are for, by id, each once: the map
## marks them, faintly.
static func addressees(post: PostState) -> Array[String]:
	var out: Array[String] = []
	for id: String in post.bag:
		var npc_id := addressee(piece(id))
		if npc_id != "" and npc_id not in out:
			out.append(npc_id)
	return out


## The tags a piece wears on its card by what it is (PIX-321, post.json's
## `kinds`): [sealed, delivered]. A parcel is wrapped, not sealed, and in
## French a parcel's and a note's tags agree with them (EMBALLÉ, REMIS), a
## letter's with « lettre » (SCELLÉE, REMISE).
static func tags(entry: Dictionary) -> Array[String]:
	var kinds: Dictionary = _data()["kinds"]
	var kind: Dictionary = kinds.get(String(entry.get("kind", "letter")), kinds["letter"])
	return [String(kind["sealed"]), String(kind["delivered"])]


# ---- The courier's book (PIX-321) --------------------------------------------------

## The book's pages, in its order: {place (a map id), ink, emblem}.
static func book() -> Array:
	return _data()["book"]


## A page by its place, {} for none.
static func page(place: String) -> Dictionary:
	for entry: Dictionary in book():
		if entry["place"] == place:
			return entry
	return {}


## The page a map's post is stamped on: the map's own when the book has
## one, else the page of the place it's in (a room of Pixelheim stamps
## Pixelheim's), else the map itself (a page the book doesn't have).
static func place_of(map_id: String) -> String:
	if not page(map_id).is_empty():
		return map_id
	var name := Catalog.place_name(map_id)
	for entry: Dictionary in book():
		if Catalog.place_name(String(entry["place"])) == name:
			return String(entry["place"])
	return map_id


## The page a piece for `npc_id` is stamped on now: where they stand.
static func place_for(npc_id: String, progression: ProgressionState, settlement: SettlementState) -> String:
	var at := spot(npc_id, progression, settlement)
	return place_of(String(at["mapId"])) if not at.is_empty() else ""


## A piece delivered at `place` on day `day`: kept on that page, and the
## page stamped with the day the first time.
static func stamp(post: PostState, piece_id: String, place: String, day: int) -> void:
	if place == "":
		return
	post.places[piece_id] = place
	if not post.stamps.has(place):
		post.stamps[place] = day


## The pieces delivered at `place`, oldest first.
static func delivered_at(post: PostState, place: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in post.delivered:
		if String(post.places.get(id, "")) == place:
			out.append(id)
	return out


## The pages the book shows this hero, in its order: every place stamped,
## and every one they have been to (its page waits for its first piece).
static func pages(post: PostState, discovered: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in book():
		var place := String(entry["place"])
		if post.stamps.has(place) or reached(place, discovered):
			out.append(place)
	return out


## What a delivered piece left the courier: the item to keep (`gift`: a
## trophy for the shelf, a piece of furniture, a wheel of cheese) and the
## recipe it wrote into the book (`recipe`, economy.json's), "" for none.
static func kept(entry: Dictionary) -> Dictionary:
	return {"gift": String(entry.get("gift", "")), "recipe": String(entry.get("recipe", ""))}
