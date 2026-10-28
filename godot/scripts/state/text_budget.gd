class_name TextBudget
extends RefCounted
## areas: combat story
## One rule for the words on the screen (PIX-334: Tom, after a fight with a
## pack, « y'a aussi trop d'infos qui pop d'un coup sur l'écran en texte »).
## An area of the screen (the battle log, the message's plate) shows at most
## `room` things at a time; what comes past that waits its turn instead of
## pushing one off unread, so nothing is lost. The same thing again folds
## into the one showing or waiting rather than stacking under it (fold).
## And in a fight what can wait (`later`: a quest's count, a level, what the
## Post says) waits until the fight is over, so what matters now (a hit, an
## ailment, a boss's words) has the screen.
##
## Pure, no nodes: Messages keeps the log and the plate through it, and the
## rules are tested without a world. An entry is {"text", "count" (the same
## words said again), "later", "shape"}; a caller may keep its own keys on
## it (Messages, the chip it shows on).
##
## The field has its rule here too (rise): a word over the world steps up
## just clear of a level tag or a word already there (PIX-340), under the
## HUD's plates at the top (room_under); and a title card stands clear of
## what rises (spot, PIX-345).

## How many show at once.
var room := 1
## What shows now and what waits its turn, oldest first.
var showing: Array[Dictionary] = []
var waiting: Array[Dictionary] = []


func _init(at_once := 1) -> void:
	room = at_once


## `text` comes, `later` when it can wait out a fight. It folds into the
## one showing or waiting of the same shape, if any (its text the fold's: a
## caller redraws one showing), or waits its turn as its own. Returns its
## entry.
func add(text: String, later := false) -> Dictionary:
	var shape := shape_of(text)
	for entry: Dictionary in showing + waiting:
		if entry["shape"] == shape:
			var folded := fold(entry["text"], text)
			if folded == entry["text"]:
				entry["count"] = int(entry["count"]) + 1
			entry["text"] = folded
			# Now if either was: it waits no longer than the one that can't.
			entry["later"] = entry["later"] and later
			return entry
	var entry := {"text": text, "count": 1, "later": later, "shape": shape}
	waiting.append(entry)
	return entry


## The next to show, moved in among those showing: the oldest waiting that
## may show now (in a fight, not one that can wait), or {} while the area
## is full or nothing may.
func next(in_fight: bool) -> Dictionary:
	if showing.size() >= room:
		return {}
	for i in waiting.size():
		if not (in_fight and waiting[i]["later"]):
			var entry: Dictionary = waiting.pop_at(i)
			showing.append(entry)
			return entry
	return {}


## One shown has gone: its room is free, and what comes after it no longer
## folds into it.
func gone(entry: Dictionary) -> void:
	for i in showing.size():
		if is_same(showing[i], entry):
			showing.remove_at(i)
			return


## The words with their numbers taken out: two lines of one shape say the
## same thing ("Slime Trouble: 2/3." and "3/3.").
static func shape_of(text: String) -> String:
	return _numbers().sub(text, "#", true)


## Two lines of one shape as one: a "+N" adds up ("+3 gold" four times is
## "+12 gold"), any other number is the newest's (a quest's count, a
## level), and so is a "+N%" (the boss slayer's edge starts over, it
## doesn't stack). The same words with nothing to add come out as they were
## (add counts them).
static func fold(old: String, new: String) -> String:
	var before := _numbers().search_all(old)
	var out := ""
	var at := 0
	var found := _numbers().search_all(new)
	for i in found.size():
		var number: RegExMatch = found[i]
		out += new.substr(at, number.get_start() - at)
		var said := number.get_string()
		# French sets a narrow space before its "%".
		var percent := new.substr(number.get_end()).lstrip("   ").begins_with("%")
		if said.begins_with("+") and not percent and i < before.size():
			said = "+%d" % (before[i].get_string().to_int() + said.to_int())
		out += said
		at = number.get_end()
	return out + new.substr(at)


static var _numbers_rx: RegEx


static func _numbers() -> RegEx:
	if _numbers_rx == null:
		_numbers_rx = RegEx.create_from_string("\\+?\\d+")
	return _numbers_rx


## How far up a word over the world at `rect` stands (from `lifted`, never
## back down: it doesn't jump about as things move), in whole pixels, to be
## just clear of every one of `taken`, `margin` apart: over each it meets
## in turn. At most `most`: with no room over them all, it takes the lowest
## height under that which is clear, back down if it must (PIX-378: a blow's
## number on a foe beside a boss stood stepped up as far as it goes, on the
## boss's win risen past it); nowhere clear, as high as it may, shown anyway,
## never dropped.
static func rise(taken: Array[Rect2], rect: Rect2, margin: float, lifted := 0.0, most := 36.0) -> float:
	var lift := lifted
	for tries in taken.size() + 1:
		var there := Rect2(rect.position - Vector2(0, lift), rect.size).grow(margin)
		var hit := taken.filter(func(other: Rect2) -> bool: return other.intersects(there))
		if hit.is_empty():
			return lift
		# Its foot just over the lowest top it meets.
		var top: float = hit.map(func(other: Rect2) -> float: return other.position.y).max()
		lift = ceilf(rect.end.y + margin - top)
		if lift >= most:
			break
	var heights: Array[float] = [0.0]
	for other in taken:
		heights.append(ceilf(rect.end.y + margin - other.position.y))
	heights.sort()
	for height in heights:
		var there := Rect2(rect.position - Vector2(0, height), rect.size).grow(margin)
		if height >= 0.0 and height <= most and not taken.any(func(other: Rect2) -> bool: return other.intersects(there)):
			return height
	return maxf(lifted, minf(lift, most))


## How far up a word over the world at `rect` (where it stands unlifted) may
## stand and stay under each of `over` it would meet, `margin` apart
## (PIX-345: LEVEL UP rose into the boss bar and was cut): the HUD's plates
## at the top, the boss bar, a title card, a hint. A plate is over the word
## when the plate's foot is above the word's and they share a column; below
## zero, the word steps down under it. INF with none over it.
static func room_under(over: Array[Rect2], rect: Rect2, margin: float) -> float:
	var room := INF
	for plate in over:
		if plate.end.y < rect.end.y and plate.position.x < rect.end.x and rect.position.x < plate.end.x:
			room = minf(room, floorf(rect.position.y - plate.end.y - margin))
	return room


## Where a plate over the screen stands (PIX-345: the Victory card stood on
## what a boss's fall won, rising): at `rect`'s own height when it's clear of
## each of `taken`, `margin` apart, else at the nearest height that is, its
## top no higher than `top` and its foot no lower than `bottom`; nowhere
## clear, at its own.
static func spot(taken: Array[Rect2], rect: Rect2, top: float, bottom: float, margin: float) -> float:
	var tries: Array[float] = [clampf(rect.position.y, top, bottom - rect.size.y)]
	for other in taken:
		tries.append(ceilf(other.end.y + margin))
		tries.append(floorf(other.position.y - margin - rect.size.y))
	var inside := tries.filter(func(y: float) -> bool: return y >= top and y + rect.size.y <= bottom)
	inside.sort_custom(func(a: float, b: float) -> bool: return absf(a - rect.position.y) < absf(b - rect.position.y))
	for y: float in inside:
		var there := Rect2(rect.position.x, y, rect.size.x, rect.size.y).grow(margin)
		if not taken.any(func(other: Rect2) -> bool: return other.intersects(there)):
			return y
	return rect.position.y
