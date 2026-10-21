class_name Hubs
## areas: town travel field +blackiron* +saltmere* +greyhold* +frostgate* +mountain_road*
## The hubs grow (PIX-324, Something to Come Back To's step 5): the place
## at the end of each post road with a waystation grows in three small
## steps as its road carries the post, counted as Routes counts it, at the
## same marks for every road (post.json's routes `growsAt`, beside the
## signposts' 3 and the waystation's 6). Saltmere's lighthouse on the point
## is mended, glazed in sea glass, then lit; the miners' camp at Blackiron
## gets its goods, a trestle, then a stall; Mabel's tent goes up at
## Greyhold, a stall beside it, then a second: a market; Gunnar's camp on
## the Frostgate gets a lodge's frame, its walls, then its fire.
## Each step (a route's `grows`) says what's new as the post carries it
## there (`news`), what's said under it (`line`), and the pieces it puts up
## on the place's own map (HamletArt's or HubArt's, laid as Hamlet lays a
## settlement's dressing: a later step's piece on a cell stands in for the
## one before). The first time the hero is there after a step, the place
## has a tour of its own, as the town does after the board (Stage).
## Pure; saved: only the step each place was last toured at (PostState.hubs);
## the rest comes from the roads' counts.


## The pieces carried a road must carry for each step, in order.
static func marks() -> Array:
	return Routes._data()["growsAt"]


## The places whose hubs grow, in the routes' order.
static func places() -> Array[String]:
	var out: Array[String] = []
	for place: String in Routes.places():
		if not steps(place).is_empty():
			out.append(place)
	return out


## A place's steps (its route's `grows`), [] for none.
static func steps(place: String) -> Array:
	return Routes.route(place).get("grows", [])


## How far `place` has grown: the marks its road's count has reached.
static func step(post: PostState, place: String) -> int:
	if steps(place).is_empty():
		return 0
	var count := Routes.count(post, place)
	return marks().filter(func(mark: int) -> bool: return count >= mark).size()


## What stands at the hub on `map_id` (a hub's map is its place's own) as
## its steps stand: Hamlet's dressing entries ({art, cell, and `lit` for a
## piece with a light of its own at night}), a later step's piece on a cell
## in place of the one before, in the order they went up.
static func dressing(map_id: String, post: PostState) -> Array[Dictionary]:
	var at := {}
	var reached: Array = steps(map_id).slice(0, step(post, map_id))
	for grown: Dictionary in reached:
		for piece: Dictionary in grown["pieces"]:
			var entry := piece.duplicate()
			entry["cell"] = Routes.cell_of(piece["cell"])
			at[entry["cell"]] = entry
	var out: Array[Dictionary] = []
	out.assign(at.values())
	return out


## The steps `place` has grown since its last tour: [{step (1..3), news,
## line, and its last piece's art and cell (where the tour looks)}].
static func news(post: PostState, place: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all := steps(place)
	for i in range(int(post.hubs.get(place, 0)), step(post, place)):
		var grown: Dictionary = all[i]
		var piece: Dictionary = grown["pieces"][-1]
		out.append({"step": i + 1, "news": String(grown["news"]), "line": String(grown["line"]), "art": String(piece["art"]), "cell": Routes.cell_of(piece["cell"])})
	return out


## The tour's stops at `place`: its news, but where several steps grew on
## one spot since the last tour (the lighthouse mended, glazed and lit) only
## the newest, as that's what stands there now; the log said the others.
static func stops(post: PostState, place: String) -> Array[Dictionary]:
	var all := news(post, place)
	var out: Array[Dictionary] = []
	for i in all.size():
		if not all.slice(i + 1).any(func(later: Dictionary) -> bool: return later["cell"] == all[i]["cell"]):
			out.append(all[i])
	return out


## `place` toured as far as it has grown.
static func toured(post: PostState, place: String) -> void:
	post.hubs[place] = step(post, place)


## Each place's step now, to compare after a piece is carried.
static func now(post: PostState) -> Dictionary:
	var out := {}
	for place: String in places():
		out[place] = step(post, place)
	return out


## What's new at the hubs since `before` (Hubs.now): each step reached, as
## the log says it.
static func grown_since(before: Dictionary, post: PostState) -> Array[String]:
	var out: Array[String] = []
	for place: String in places():
		for i in range(int(before.get(place, 0)), step(post, place)):
			out.append(String(steps(place)[i]["news"]))
	return out
