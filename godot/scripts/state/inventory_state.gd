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
	return total
