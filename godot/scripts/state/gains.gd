class_name Gains
extends RefCounted
## What the hero wins, as things the world shows rather than words in the
## log (PIX-245: Tom found it "beaucoup d'écrit"): the XP, the gold and the
## items a kill, a chest, a patch picked or a fish caught brings float up
## from where they were won, as the damage numbers do, and the log keeps
## only what the world doesn't show (story beats, quests, levels, the boss
## slayer's edge, a pack scattered).
##
## Pure, no nodes: Spoils fills a win as it pays, WorldFx draws it, and the
## rules (what a win holds, how two merge, what each row reads, when two
## wins rise as one) are tested without a world. A win is
## {"xp": int, "gold": int, "items": [{"id", "count", "rarity", "name"}]}.

## Wins this close together rise as one (PIX-245): a pack felled in a few
## blows shows "+36 XP" once, not three "+12 XP" over each other. Seconds
## since the last win joined, and pixels from where the first rose (three
## tiles: a pack stands within two of its home).
const JOIN_SECONDS := 1.5
const JOIN_PIXELS := 48.0


## A win of nothing yet.
static func none() -> Dictionary:
	return {"xp": 0, "gold": 0, "items": []}


## `count` of a stackable item won (a pelt, herbs, a fish).
static func add_item(gains: Dictionary, item_id: String, count := 1) -> void:
	_add(gains, {"id": item_id, "count": count, "rarity": "common", "name": Catalog.item_name(item_id)})


## A piece of gear won, named as the pack names it ("Fine Iron Sword"), in
## its rarity's colour when it floats.
static func add_piece(gains: Dictionary, piece: Dictionary) -> void:
	_add(gains, {
		"id": String(piece["itemId"]), "count": 1,
		"rarity": String(piece.get("rarity", "common")), "name": InventoryState.gear_name(piece),
	})


## An item into a win: the same thing again counts up rather than adding a
## row (two pelts read "Wolf Pelt x2"). A copy goes in, so a win merged into
## another never shares its rows.
static func _add(gains: Dictionary, item: Dictionary) -> void:
	for held: Dictionary in gains["items"]:
		if held["id"] == item["id"] and held["name"] == item["name"]:
			held["count"] = int(held["count"]) + int(item["count"])
			return
	gains["items"].append(item.duplicate())


## `more` added into `into`, which is changed and returned; `more` is left
## as it was.
static func merge(into: Dictionary, more: Dictionary) -> Dictionary:
	into["xp"] = int(into["xp"]) + int(more.get("xp", 0))
	into["gold"] = int(into["gold"]) + int(more.get("gold", 0))
	for item: Dictionary in more.get("items", []):
		_add(into, item)
	return into


## Whether a win holds nothing to show.
static func is_empty(gains: Dictionary) -> bool:
	return int(gains.get("xp", 0)) <= 0 and int(gains.get("gold", 0)) <= 0 and gains.get("items", []).is_empty()


## The rows a win floats as, from the bottom up: XP, gold, then each item.
## Each is {"key" (what a merged win updates in place), "text", "tone" (xp,
## gold, or the item's rarity: common, fine, epic) and "item" (the item's
## id, for its icon; "" for XP and gold)}. Nothing won is no row: never "+0
## gold".
static func rows(gains: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if int(gains["xp"]) > 0:
		out.append({"key": "xp", "text": Text.t("+%d XP") % int(gains["xp"]), "tone": "xp", "item": ""})
	if int(gains["gold"]) > 0:
		out.append({"key": "gold", "text": Text.t("+%d gold") % int(gains["gold"]), "tone": "gold", "item": ""})
	for item: Dictionary in gains["items"]:
		var count := int(item["count"])
		out.append({
			"key": "item:%s:%s" % [item["id"], item["name"]],
			"text": String(item["name"]) if count == 1 else Text.t("%s x%d") % [item["name"], count],
			"tone": String(item["rarity"]), "item": String(item["id"]),
		})
	return out


## Whether a win at `at`, `now`, joins the one already rising from
## `rising_at`, which a win last joined at `joined`: soon enough after it
## and near enough where it rose.
static func joins(rising_at: Vector2, joined: float, at: Vector2, now: float) -> bool:
	return now - joined <= JOIN_SECONDS and rising_at.distance_to(at) <= JOIN_PIXELS


## The rows' words, joined by ";": what the harness reports (floats=).
static func summary(gains: Dictionary) -> String:
	return ";".join(rows(gains).map(func(row: Dictionary) -> String: return row["text"]))
