class_name InventoryState
extends Resource
## Gold and everything carried (web GameState: gold, inventory, gear,
## equipped). Stackables are item id -> count; weapons and apparel are gear
## instances ({uid, itemId, rarity, bonus}) so each piece keeps its rarity roll.

## Rarity name prefixes (RARITIES in rarity.ts); common pieces have none.
const RARITY_LABELS := {"common": "", "fine": "Fine", "epic": "Epic"}

static var _uid_counter := 0

var gold := 0
var items := {}
var gear: Array[Dictionary] = []
## equipped slot (weapon, body, ring1, ...) -> gear uid
var equipped := {}


## Unique within a save: millisecond clock + counter + entropy (gearUid).
static func gear_uid() -> String:
	_uid_counter += 1
	var millis := int(Time.get_unix_time_from_system() * 1000.0)
	return "g%s%d%s" % [String.num_int64(millis, 36), _uid_counter, String.num_int64(randi() % 1679616, 36)]


## A fresh piece (createGear): common pieces carry no bonus; fine and epic
## ones roll theirs from the rarity's range (weapon or armor) with `roll`.
static func create_gear(item_id: String, rarity := "common", roll: Callable = Callable()) -> Dictionary:
	var bonus := 0
	if rarity != "common":
		var def: Dictionary = Economy._data()["rarities"][rarity]
		var weapon: bool = Catalog.item(item_id).get("category", "") == "weapons"
		var bounds: Array = def["weaponBonus"] if weapon else def["armorBonus"]
		var value: float = roll.call() if roll.is_valid() else randf()
		bonus = int(bounds[0]) + floori(value * (int(bounds[1]) - int(bounds[0]) + 1))
	return {"uid": gear_uid(), "itemId": item_id, "rarity": rarity, "bonus": bonus}


static func gear_name(instance: Dictionary) -> String:
	var label: String = RARITY_LABELS.get(instance["rarity"], "")
	var name := Catalog.item_name(instance["itemId"])
	return "%s %s" % [label, name] if label != "" else name


static func from_dict(data: Dictionary) -> InventoryState:
	var pack := InventoryState.new()
	pack.gold = data["gold"]
	pack.items = data["inventory"].duplicate()
	pack.gear.assign(data["gear"].map(func(g: Dictionary) -> Dictionary: return g.duplicate()))
	pack.equipped = data["equipped"].duplicate()
	return pack


func write_into(state: Dictionary) -> void:
	state["gold"] = gold
	state["inventory"] = items.duplicate()
	state["gear"] = gear.map(func(g: Dictionary) -> Dictionary: return g.duplicate())
	state["equipped"] = equipped.duplicate()


func add_item(item_id: String, count := 1) -> void:
	items[item_id] = items.get(item_id, 0) + count


## Takes up to `count`; an emptied stack disappears (removeItem).
func remove_item(item_id: String, count := 1) -> void:
	var left: int = items.get(item_id, 0) - count
	if left > 0:
		items[item_id] = left
	else:
		items.erase(item_id)


## The orders the pack can list in (PIX-89): by kind (gear, then stacks, each
## by category and name), dearest first, heaviest first, or by name.
const SORTS := ["kind", "value", "weight", "name"]


## What the pack holds in a category ("all" for everything), in a SORTS
## order: rows {"kind": "gear", "piece", "item_id"} or {"kind": "stack",
## "item_id", "count"}.
func listing(category: String, sort := "kind") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece: Dictionary in gear:
		if category == "all" or Catalog.item(piece["itemId"])["category"] == category:
			out.append({"kind": "gear", "piece": piece, "item_id": piece["itemId"]})
	for item_id: String in items:
		if category == "all" or Catalog.item(item_id)["category"] == category:
			out.append({"kind": "stack", "item_id": item_id, "count": items[item_id]})
	var name_of := func(row: Dictionary) -> String:
		return gear_name(row["piece"]) if row["kind"] == "gear" else String(Catalog.item_name(row["item_id"]))
	var key_of := func(row: Dictionary) -> Variant:
		match sort:
			"value":
				return -(Economy.gear_value(row["piece"]) if row["kind"] == "gear" else int(Catalog.item(row["item_id"])["value"]))
			"weight":
				return -int(Catalog.item(row["item_id"]).get("weight", 0))
			"name":
				return 0
		return [0 if row["kind"] == "gear" else 1, String(Catalog.item(row["item_id"])["category"])]
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: Variant = key_of.call(a)
		var kb: Variant = key_of.call(b)
		if ka != kb:
			return ka < kb
		return name_of.call(a) < name_of.call(b)
	)
	return out


## What is worn where: slot -> item id (what the hero is drawn in).
func worn_items() -> Dictionary:
	var worn := {}
	for slot: String in equipped:
		var instance := gear_by_uid(equipped[slot])
		if not instance.is_empty():
			worn[slot] = instance["itemId"]
	return worn


func gear_by_uid(uid: String) -> Dictionary:
	for instance in gear:
		if instance["uid"] == uid:
			return instance
	return {}


func is_equipped(uid: String) -> bool:
	return uid in equipped.values()


## Stackables plus unequipped gear; what you wear does not weigh you down.
func carried_weight() -> int:
	var worn := equipped.values()
	var total := 0
	for item_id: String in items:
		total += int(Catalog.item(item_id).get("weight", 0)) * int(items[item_id])
	for instance in gear:
		if instance["uid"] not in worn:
			total += int(Catalog.item(instance["itemId"]).get("weight", 0))
	return total


## A stat granted by worn gear (jewelry, mostly).
func granted_stat(stat: String) -> int:
	var total := 0
	for instance in gear:
		if instance["uid"] in equipped.values():
			total += int(Catalog.item(instance["itemId"]).get("grants", {}).get(stat, 0))
	return total + int(set_bonus()["grants"].get(stat, 0))


## Pieces of each armour set worn now (PIX-166): set id -> count.
func set_counts() -> Dictionary:
	var counts := {}
	for instance in gear:
		if instance["uid"] in equipped.values():
			var set_id: String = Catalog.item(instance["itemId"]).get("set", "")
			if set_id != "":
				counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


## What the worn sets give together: every bonus a set's count has reached
## ("3", "5" pieces), {grants: {stat: n}, armor: n}.
func set_bonus() -> Dictionary:
	var out := {"grants": {}, "armor": 0}
	var counts := set_counts()
	for set_id: String in counts:
		var bonuses: Dictionary = Catalog.armour_set(set_id).get("bonuses", {})
		for at: String in bonuses:
			if int(counts[set_id]) < int(at):
				continue
			var bonus: Dictionary = bonuses[at]
			out["armor"] += int(bonus.get("armor", 0))
			for stat: String in bonus.get("grants", {}):
				out["grants"][stat] = int(out["grants"].get(stat, 0)) + int(bonus["grants"][stat])
	return out
