extends Node
## The one game state (autoload `GameState`), replacing the web's Zustand
## store: typed sections for the hero, the pack, the settlement, progression
## and the explored world. Mutations go through methods that keep the web
## reducers' invariants; signals replace store subscriptions. Persistence is
## write-behind: changes mark the state dirty, the autosave flushes it within
## AUTOSAVE_SECONDS, and moments that matter (map change, loot) save at once.

signal loaded
signal gold_changed(gold: int)
signal inventory_changed
## A conversation ended: settlers (PIX-124) and quests (PIX-125) answer here,
## like the web game resolves them when its dialogue closes.
signal dialogue_closed(npc_id: String)

## Slot 0 never touches disk: harness runs and tests leave real saves alone.
const NO_SLOT := 0
const AUTOSAVE_SECONDS := 3.0
## Until character creation lands (PIX-127), new games start this hero.
const DEFAULT_HERO_NAME := "Wanderer"
const DEFAULT_ROLE := "warrior"
## Starting kits (CREATE_HERO in reducers/meta.ts): rangers string a bow,
## everyone else begins with the humble rusty sword.
const STARTER_WEAPONS := {"ranger": "hunting_bow"}
const STARTER_ITEMS := {"potion_hp": 2, "bread": 2, "cheese_wheel": 1}
const STARTER_GOLD := 30

var hero: HeroState
var pack: InventoryState
var settlement: SettlementState
var progression: ProgressionState
var world: WorldState
var slots := SaveSlots.new()
var settings := GameSettings.new()
var slot := NO_SLOT
var dirty := false
## True when boot found no save in any slot: a first visit (offer the web hero).
var first_run := false
var _booted := false
var _unsaved_seconds := 0.0


func _init() -> void:
	new_game()
	dirty = false


## Picks the save to play: `--slot N` or the last slot played, else a new game
## written straight to that slot. Harness runs (`--screenshot`) play a fresh
## throwaway hero unless a slot is named explicitly. Runs once per session:
## the world scene reloads after a slot switch and must not undo it.
func boot(args: PackedStringArray) -> void:
	if _booted:
		return
	_booted = true
	settings.load_file()
	var slot_index := args.find("--slot")
	if slot_index >= 0 and slot_index + 1 < args.size():
		slot = clampi(int(args[slot_index + 1]), 1, SaveSlots.SLOT_COUNT)
	elif args.has("--screenshot"):
		slot = NO_SLOT
	else:
		slot = clampi(settings.last_slot, 1, SaveSlots.SLOT_COUNT)
	var saved := slots.read(slot) if slot != NO_SLOT else {}
	first_run = slot != NO_SLOT and range(1, SaveSlots.SLOT_COUNT + 1).all(
		func(n: int) -> bool: return slots.summary(n).is_empty()
	)
	if saved.is_empty():
		new_game()
		save_now()
	else:
		apply(saved)
	if slot != NO_SLOT and settings.last_slot != slot:
		settings.last_slot = slot
		settings.save_file()


## Switches play to another slot: the current one is saved first, an empty
## one starts a new hero. The caller reloads the world scene afterwards.
func play_slot(target: int) -> void:
	save_now()
	_use_slot(target)
	var saved := slots.read(target)
	if saved.is_empty():
		new_game()
		save_now()
	else:
		apply(saved)


## Writes a brand-new hero into a slot (replacing whatever was there) and plays it.
func new_hero_in(target: int) -> void:
	save_now()
	_use_slot(target)
	new_game()
	save_now()


## Brings a migrated save (the web game's, a pasted code) into a slot and plays it.
func import_into(target: int, state: Dictionary) -> void:
	save_now()
	_use_slot(target)
	apply(state)
	save_now()


## Empties a slot. The slot being played cannot be cleared from under the hero.
func clear_slot(target: int) -> bool:
	if target == slot:
		return false
	slots.erase(target)
	return true


## This hero as a PXH1 code: loads in the web game's Import too.
func save_code() -> String:
	return SaveCodec.encode_code(to_dict())


func _use_slot(target: int) -> void:
	slot = target
	first_run = false
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## A fresh level-1 hero waking in the village (CREATE_HERO).
func new_game(name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE) -> void:
	var state := SaveCodec.initial_state()
	state.merge(SaveCodec.RESUME_INTO, true)
	var weapon := InventoryState.create_gear(STARTER_WEAPONS.get(role_id, "rusty_sword"))
	state["hero"] = HeroState.create(name, role_id).to_dict()
	state["gold"] = STARTER_GOLD
	state["inventory"] = STARTER_ITEMS.duplicate()
	state["gear"] = [weapon]
	state["equipped"] = {"weapon": weapon["uid"]}
	state["introSeen"] = false
	state["world"] = SaveCodec.fresh_world()
	apply(state)


## Replaces the whole state with a normalized web-shaped save.
func apply(state: Dictionary) -> void:
	hero = HeroState.from_dict(state["hero"])
	pack = InventoryState.from_dict(state)
	settlement = SettlementState.from_dict(state)
	progression = ProgressionState.from_dict(state)
	world = WorldState.from_dict(state)
	mark_dirty()
	loaded.emit()
	gold_changed.emit(pack.gold)
	inventory_changed.emit()


## The full web GameState: what a slot file, a save code, or the web game reads.
func to_dict() -> Dictionary:
	var state := SaveCodec.initial_state()
	state.merge(SaveCodec.RESUME_INTO, true)
	state["hero"] = hero.to_dict()
	pack.write_into(state)
	settlement.write_into(state)
	progression.write_into(state)
	world.write_into(state)
	return state


func mark_dirty() -> void:
	dirty = true


func save_now() -> void:
	dirty = false
	_unsaved_seconds = 0.0
	if slot != NO_SLOT:
		slots.write(slot, to_dict())


func _process(delta: float) -> void:
	if not dirty:
		return
	_unsaved_seconds += delta
	if _unsaved_seconds >= AUTOSAVE_SECONDS:
		save_now()


func _notification(what: int) -> void:
	# Window closed, tab hidden, app backgrounded, or the tree shutting down.
	var leaving := (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_EXIT_TREE
	)
	if leaving and dirty:
		save_now()


## The hero stands on a new cell: remember it, see around it. Changing maps
## clears the slain ledger (it only ever describes the current map).
func move_to(map: MapData, cell: Vector2i, facing: Vector2) -> void:
	if map.id != world.map_id:
		world.slain.clear()
	world.map_id = map.id
	world.cell = cell
	world.facing = WorldState.facing_name(facing)
	Discovery.discover_around(world.discovered, map, cell)
	mark_dirty()


func walk(tiles: float) -> void:
	if tiles <= 0.0:
		return
	world.steps += tiles
	mark_dirty()


func owns_house() -> bool:
	return settlement.house.get("owned", false)


func is_opened(chest: Dictionary) -> bool:
	return chest["id"] in world.opened_chests


## 60 + 3 per point of strength (worn grants included) + carry passives.
func carry_capacity() -> int:
	var strength: int = hero.stats.get("strength", 0) + pack.granted_stat("strength")
	return 60 + strength * 3 + hero.carry_bonus()


## Grants a chest's payout (openChest in reducers/world.ts): gold, a stack, a
## gear piece, or a mimic's teeth. Loot that would overload the pack leaves the
## chest closed. Returns {opened, message, mimic}.
func open_chest(chest: Dictionary) -> Dictionary:
	if is_opened(chest):
		return {"opened": false, "message": "", "mimic": false}
	if chest.get("mimic", false):
		world.opened_chests.append(chest["id"])
		save_now()
		return {"opened": true, "message": "The chest bares its teeth — a mimic!", "mimic": true}
	var loot: Dictionary = chest["loot"]
	var message := ""
	if loot["kind"] == "gold":
		pack.gold += loot["amount"]
		message = (
			"Something glitters on the road: %dg." % loot["amount"] if chest["look"] == "glint"
			else "The chest holds %dg." % loot["amount"]
		)
		gold_changed.emit(pack.gold)
	else:
		var qty: int = loot["qty"] if loot["kind"] == "item" else 1
		var weight := int(Catalog.item(loot["itemId"]).get("weight", 0)) * qty
		if pack.carried_weight() + weight > carry_capacity():
			return {
				"opened": false,
				"message": "Too heavy to carry. Lighten the pack and come back.",
				"mimic": false,
			}
		if loot["kind"] == "gear":
			var instance := InventoryState.create_gear(loot["itemId"])
			pack.gear.append(instance)
			message = "The chest holds %s!" % InventoryState.gear_name(instance)
		else:
			pack.add_item(loot["itemId"], qty)
			var name := Catalog.item_name(loot["itemId"])
			message = (
				"You gather %dx %s." % [qty, name] if chest["look"] == "herb"
				else "The chest holds %dx %s." % [qty, name]
			)
		inventory_changed.emit()
	world.opened_chests.append(chest["id"])
	save_now()
	return {"opened": true, "message": message, "mimic": false}
