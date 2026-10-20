class_name Routes
## The Post's routes (PIX-322, Something to Come Back To's step 3): the
## roads the courier carries the post along, and what they grow. Every
## piece handed over counts toward the route from Pixelheim to the place at
## each of its ends (the sender's and the addressee's, where they stand as
## it's delivered: the village is no route, nor the Reach's own road), by
## who wrote it. A route that has carried a few pieces has signposts at its
## forks, each named after whoever wrote most along it when it went up
## ("Bram's Corner"); one that has carried enough has its waystation offered
## on the town's board, a work like the river bridge (town.json's `works`,
## paid in gold and its place's material and an ember shard). Built, the
## waystation stands halfway along its route on the Ashenreach, on open
## ground beside the road: a hut, a bench that mends you, a post box that
## holds the day's post as the square's does, and an ember lamp, a shard of
## the mountain's warmth on a post, lit at night. It's a stage to travel to
## (the map's waypoints). The map draws your routes in gold.
## Pure, over post.json's `routes` (read with the Post's data); what the
## hero did is PostState's (`routes`: each route's pieces by who wrote them,
## `signs`: whom each fork's signpost is named after) and the settlement's
## (a waystation built is a work done). MapView draws what stands, the map
## screen the gold, and PIX-323 heals the land round each lit lamp
## (`lamps`).

## The map the routes run across: the Ashenreach, where every road out of
## Pixelheim's gate meets the others.
const MAP := "overworld"


static func _data() -> Dictionary:
	return Post._data()["routes"]


## Every route, in the data's order.
static func all() -> Array:
	return _data()["list"]


## Every route's place (a book page: saltmere, blackiron...).
static func places() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in all():
		out.append(String(entry["place"]))
	return out


## The route to `place`, {} for none.
static func route(place: String) -> Dictionary:
	for entry: Dictionary in all():
		if entry["place"] == place:
			return entry
	return {}


## Every fork a signpost may stand at, in the data's order.
static func forks() -> Array:
	return _data()["forks"]


static func fork(fork_id: String) -> Dictionary:
	for entry: Dictionary in forks():
		if entry["id"] == fork_id:
			return entry
	return {}


## A cell as the data writes it: [x, y].
static func cell_of(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


## How many pieces a route carries before its signposts go up.
static func signs_at(place: String) -> int:
	return int(route(place).get("signsAt", _data()["signsAt"]))


## How many before its waystation is offered on the board.
static func station_at(place: String) -> int:
	return int(route(place).get("stationAt", _data()["stationAt"]))


## A route's waystation, {} for a route with none (a waypoint stands
## halfway along it already: the passes, the mountain's gate).
static func station(place: String) -> Dictionary:
	return route(place).get("station", {})


# ---- What's carried ---------------------------------------------------------------

## How many pieces the route to `place` has carried.
static func count(post: PostState, place: String) -> int:
	var total := 0
	var by: Dictionary = post.routes.get(place, {})
	for writer: String in by:
		total += int(by[writer])
	return total


## Who wrote most along the route to `place` (a correspondent's id), the
## first to have written that many on a tie; "" before anything is carried.
static func writer(post: PostState, place: String) -> String:
	var best := ""
	var most := 0
	var by: Dictionary = post.routes.get(place, {})
	for who: String in by:
		if int(by[who]) > most:
			most = int(by[who])
			best = who
	return best


## The routes a piece travels: the place each of its ends stands in now
## that has a route (the sender's, then the addressee's), each once.
static func ends(entry: Dictionary, progression: ProgressionState, settlement: SettlementState) -> Array[String]:
	var out: Array[String] = []
	for npc_id: String in [Post.sender(entry), Post.addressee(entry)]:
		var place := Post.place_for(npc_id, progression, settlement)
		if place != "" and place not in out and not route(place).is_empty():
			out.append(place)
	return out


## A piece handed over (Posting.deliver): counted toward each route it
## travels, by who wrote it; then the signposts that go up and a waystation
## newly offered, as lines for the log.
static func carry(post: PostState, entry: Dictionary, progression: ProgressionState, settlement: SettlementState) -> Array[String]:
	var offered_before := {}
	for place: String in places():
		offered_before[place] = station_offered(post, place)
	var who := String(entry.get("from", ""))
	for place: String in ends(entry, progression, settlement):
		tally(post, place, who, 1)
	var notes: Array[String] = []
	var raised := raise_signs(post)
	if not raised.is_empty():
		var names: Array[String] = []
		for fork_id: String in raised:
			names.append(fork_name(fork_id, post))
		notes.append(Text.t("Signposts go up at the forks of your post roads: %s.") % ", ".join(names))
	for place: String in places():
		if station_offered(post, place) and not offered_before[place] and not built(settlement).has(place):
			notes.append(Text.t("The road to %s has carried enough post for a waystation: the board on the square has it.") % Text.mid(Catalog.place_name(place)))
	return notes


## `n` pieces counted toward the route to `place`, written by `who`.
static func tally(post: PostState, place: String, who: String, n: int) -> void:
	if not post.routes.has(place):
		post.routes[place] = {}
	post.routes[place][who] = int(post.routes[place].get(who, 0)) + n


# ---- Signposts ----------------------------------------------------------------------

## Whether the route to `place` has carried enough for its signposts.
static func signed(post: PostState, place: String) -> bool:
	return count(post, place) >= signs_at(place) and not route(place).is_empty()


## Every route that has carried enough puts up a signpost at each of its
## forks not signed yet, named after whoever wrote most along it; returns
## the forks newly signed, in the forks' order.
static func raise_signs(post: PostState) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in forks():
		var fork_id := String(entry["id"])
		if post.signs.has(fork_id):
			continue
		for place: String in places():
			if fork_id in route(place)["forks"] and signed(post, place) and writer(post, place) != "":
				post.signs[fork_id] = writer(post, place)
				out.append(fork_id)
				break
	return out


## The forks whose signposts stand, in the forks' order.
static func signposts(post: PostState) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in forks():
		if post.signs.has(entry["id"]):
			out.append(String(entry["id"]))
	return out


## A signpost's name: its fork's, with whom it's named after ("Bram's
## Corner", « Le Coin de Bram »).
static func fork_name(fork_id: String, post: PostState) -> String:
	return String(fork(fork_id)["name"]) % Post.name_of(String(post.signs.get(fork_id, "")))


## Where a signpost points: the places of the routes through its fork
## that have carried enough to be signed.
static func fork_ways(fork_id: String, post: PostState) -> Array[String]:
	var out: Array[String] = []
	for place: String in places():
		if fork_id in route(place)["forks"] and signed(post, place):
			out.append(place)
	return out


## What a signpost says under its name, on one line: the post roads it
## points down, or how many meet at it past two (the gate's corner takes
## all seven).
static func fork_about(fork_id: String, post: PostState) -> String:
	var names: Array[String] = []
	for place: String in fork_ways(fork_id, post):
		names.append(Text.mid(Catalog.place_name(place)))
	match names.size():
		0:
			return ""
		1:
			return Text.t("The post road to %s") % names[0]
		2:
			return Text.t("The post roads to %s and %s") % [names[0], names[1]]
	return Text.t("%d post roads meet here") % names.size()


# ---- Waystations ---------------------------------------------------------------------

## Whether the route to `place` has carried enough for its waystation.
static func station_offered(post: PostState, place: String) -> bool:
	return not station(place).is_empty() and count(post, place) >= station_at(place)


## The route a waystation's work stands on, "" for a work that isn't one.
static func route_of_work(work_id: String) -> String:
	for place: String in places():
		if String(station(place).get("work", "")) == work_id:
			return place
	return ""


## The places whose waystations stand: their works built.
static func built(settlement: SettlementState) -> Array[String]:
	var done := Town.done_projects(settlement)
	var out: Array[String] = []
	for place: String in places():
		var work := String(station(place).get("work", ""))
		if work != "" and work in done:
			out.append(place)
	return out


## A waystation's cell for `part` (hut, lamp, box, bench, arrival).
static func spot(place: String, part: String) -> Vector2i:
	return cell_of(station(place)[part])


## A built waystation as a waypoint (the map's fast travel): its marker on
## the hut, the hero set down before it.
static func waypoint(place: String) -> Dictionary:
	var hut := spot(place, "hut")
	var arrival := spot(place, "arrival")
	return {
		"id": String(station(place)["work"]), "name": String(station(place)["name"]), "mapId": MAP,
		"at": {"x": hut.x, "y": hut.y}, "arrival": {"x": arrival.x, "y": arrival.y}, "route": place,
	}


## The waystations built, as waypoints.
static func waypoints(settlement: SettlementState) -> Array:
	var out: Array = []
	for place: String in built(settlement):
		out.append(waypoint(place))
	return out


## Every waypoint the map lists: the data's (Interactables) and the
## waystations built.
static func every_waypoint(settlement: SettlementState) -> Array:
	return Interactables.waypoints() + waypoints(settlement)


## Where the ember lamps burn (PIX-323 heals the land round them): each
## built waystation's lamp, {place, mapId, cell}.
static func lamps(settlement: SettlementState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for place: String in built(settlement):
		out.append({"place": place, "mapId": MAP, "cell": spot(place, "lamp")})
	return out


## The waystation whose `part` (bench, box) stands at `cell` on `map_id`,
## by its route's place, "" for none.
static func station_with(part: String, map_id: String, cell: Vector2i, settlement: SettlementState) -> String:
	if map_id != MAP:
		return ""
	for place: String in built(settlement):
		if spot(place, part) == cell:
			return place
	return ""


## The signpost standing at `cell` on `map_id`, by its fork, "" for none.
static func signpost_at(map_id: String, cell: Vector2i, post: PostState) -> String:
	if map_id != MAP:
		return ""
	for fork_id: String in signposts(post):
		if cell_of(fork(fork_id)["at"]) == cell:
			return fork_id
	return ""


# ---- What stands, and the map's gold -----------------------------------------------

## What stands for the routes on `map`: the signposts up and the waystations
## built, each a piece on a cell of its own beside the road, and the cells
## they block. A piece is {kind (signpost, hut, lamp, box, bench), cell,
## cells, and its fork or place}; one that doesn't fit where the data puts
## it (Hamlet.fits: open ground off the roads, not `kept`, never closing a
## way) is left out. `open`: the cells where the hero is set down at each
## waystation, kept clear (nothing grows on them). Nothing anywhere but the
## Ashenreach.
static func plan(map: MapData, post: PostState, settlement: SettlementState, kept: Dictionary) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var blocks: Array[Vector2i] = []
	var open: Array[Vector2i] = []
	var out := {"pieces": pieces, "blocks": blocks, "open": open}
	if map.id != MAP:
		return out
	var wanted: Array[Dictionary] = []
	for fork_id: String in signposts(post):
		var at := cell_of(fork(fork_id)["at"])
		wanted.append({"kind": "signpost", "cell": at, "cells": [at], "fork": fork_id})
	for place: String in built(settlement):
		var hut := spot(place, "hut")
		wanted.append({"kind": "hut", "cell": hut, "cells": [hut, hut + Vector2i.RIGHT], "place": place})
		for part: String in ["lamp", "box", "bench"]:
			wanted.append({"kind": part, "cell": spot(place, part), "cells": [spot(place, part)], "place": place})
	var keep := kept.duplicate()
	for place: String in built(settlement):
		keep[spot(place, "arrival")] = true
		open.append(spot(place, "arrival"))
	for piece: Dictionary in wanted:
		var cells: Array[Vector2i] = []
		cells.assign(piece["cells"])
		if not Hamlet.fits(map, cells, keep, blocks):
			continue
		blocks.append_array(cells)
		pieces.append(piece)
	return out


## Every cell along the route to `place`'s road, from the gate's landing to
## where it leaves the Ashenreach, in order.
static func path_cells(place: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var corners: Array = route(place).get("path", [])
	if corners.is_empty():
		return out
	out.append(cell_of(corners[0]))
	for i in range(1, corners.size()):
		var to := cell_of(corners[i])
		var step := (to - out[-1]).sign()
		while out[-1] != to:
			out.append(out[-1] + step)
	return out


## The routes that have carried anything: the map draws them in gold.
static func carried(post: PostState) -> Array[String]:
	var out: Array[String] = []
	for place: String in places():
		if count(post, place) > 0:
			out.append(place)
	return out
