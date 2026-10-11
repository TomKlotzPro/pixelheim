class_name PlaceTitle
## The card that names where the hero has come to (PIX-269, after Tom's "I
## still don't like the door between maps"). No signpost or nameplate stands
## by a way out any more: the cliffs part and the road runs on, and the
## place says its name once the hero is there - the map's place on entering
## it, a region of the Ashenreach (the ash, the woods, the marsh) on walking
## into it, with the place under it. Once: a name shown in the last AGAIN_MS
## stays quiet, so walking back and forth through a pass or along the edge
## of a region doesn't flash it again. A room is a door's short way in, not
## a place come to: rooms and dungeon floors name nothing and keep the place
## before them, so stepping into the inn and out again names nothing, and up
## out of a cave through the room over it names the land outside.
## Pure: the HUD shows the card (Hud.name_place), this decides.

## How long a name rests after it's shown, in real time.
const AGAIN_MS := 180000


## Where `cell` on `map` stands, as the card names it: {"place": the map's
## place ("The Ashenreach", "Saltmere"), "region": the region's own name
## where the map has several (`regions`: Atlas.names_regions, worked out once
## a visit), "" between them and on a map that is its one region}; {} in a
## room (Ways.indoors) or down a dungeon, where the place before holds.
static func at(map: MapData, cell: Vector2i, regions: bool) -> Dictionary:
	if Ways.indoors(map):
		return {}
	var region := map.region_at(cell) if regions else ""
	return {"place": Catalog.place_name(map.id), "region": Atlas.region_title(region) if region != "" else ""}


## The card as the hero stands `here` (at()), after `was` (the place and
## region named last, moved on to `here`), with `shown` (name -> when it was
## last shown, msec, marked for what this shows) at `now`: [title, line], or
## [] for none - nowhere new, a name shown in the last AGAIN_MS, or `quiet`
## (only noted). A new place is titled with its region under it; walking
## into another region of it, the region is, with the place under it. When
## the place has just been named, its region still may be. The ground
## between regions (the roads, the village's fields) names nothing and
## forgets nothing: from the ash onto the road and back is still the ash.
static func next(here: Dictionary, was: Dictionary, shown: Dictionary, now: int, quiet := false) -> Array:
	if here.is_empty():
		return []
	var place: String = here["place"]
	var region: String = here["region"]
	var cards: Array = []
	if place != String(was.get("place", "")):
		cards.append([place, region])
		if region != "":
			cards.append([region, place])
		was["place"] = place
		was["region"] = region
	elif region != "" and region != String(was.get("region", "")):
		cards.append([region, place])
		was["region"] = region
	if quiet:
		return []
	for card: Array in cards:
		if due(shown, card[0], now):
			# A place titled over its region names them both.
			for name: String in card:
				if name != "":
					shown[name] = now
			return card
	return []


## Whether `name` may show at `now`: never shown, or not for AGAIN_MS.
static func due(shown: Dictionary, name: String, now: int) -> bool:
	return not shown.has(name) or now - int(shown[name]) >= AGAIN_MS
