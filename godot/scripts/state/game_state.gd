extends Node
## The one game state (autoload `GameState`), replacing the web's Zustand
## store: typed sections for the hero, the pack, the settlement, progression
## and the explored world. Mutations go through methods that keep the web
## reducers' invariants; signals replace store subscriptions. Persistence is
## write-behind: changes mark the state dirty, the autosave flushes it within
## AUTOSAVE_SECONDS, and moments that matter (map change, loot) save at once.
## The methods live in seven modules, one per part of the game (PIX-261):
## `trade`, `holdings`, `household`, `questing`, `spoils`, `upkeep` and
## `training`, and callers reach them there (`GameState.questing.choose()`,
## or `state.spoils.open_chest()` in a test). This core keeps the sections,
## the signals, the saves and the slots; the modules reach them through
## their `owner`, never the autoload.

signal loaded
signal gold_changed(gold: int)
signal inventory_changed
## A conversation ended: settlers (PIX-124) and quests (PIX-125) answer here,
## like the web game resolves them when its dialogue closes.
signal dialogue_closed(npc_id: String)
## The letter is in Maren's hands: the world plays the dawn (PIX-152).
signal prologue_dawn
## One line of feedback for the world (the web's worldMessage).
signal message(text: String)
## Lines for the battle log from outside a fight (PIX-206: a delivery's progress).
signal noted(lines: Array)
## Who lives where changed: a recruit left the wilds for town.
signal settlers_changed
## The hero was made whole (inn, healer): the live body refills too.
signal healed
## A monster fell (quest bounties hook here, PIX-125).
signal monster_slain(monster_id: String)
## The hero's HP changed (hits, rests, level-ups).
signal hp_changed(hp: int, max_hp: int)
## The hero crossed into a new rank (useRankUp): the ascension scene plays.
signal ranked_up(title: String)
## Levels were gained (the level-up fanfare).
signal leveled_up(level: int)
## A skill the hero can now use (PIX-160: its first-time hint).
## `key`: the dock key (1-6) it took, 0 when all six were taken (PIX-190).
signal skill_learned(entry: Dictionary, key: int)

## Slot 0 never touches disk: harness runs and tests leave real saves alone.
const NO_SLOT := 0
const AUTOSAVE_SECONDS := 3.0
## Until character creation lands (PIX-127), new games start this hero.
const DEFAULT_HERO_NAME := "Wanderer"
const DEFAULT_ROLE := "warrior"
## Starting kits (CREATE_HERO in reducers/meta.ts): rangers string a bow,
## casters carry a staff (PIX-172: the weapon you hold is the one you swing),
## everyone else begins with the humble rusty sword.
## Each class starts with a blade or a staff for its own best stat (PIX-205:
## the rogue's dagger is DEX, not a strength sword).
const STARTER_WEAPONS := {"ranger": "hunting_bow", "mage": "apprentice_staff", "cleric": "apprentice_staff", "necromancer": "apprentice_staff", "rogue": "worn_dagger"}
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
## Dice for chance rolls (double brews); tests swap in a loaded die.
var roll: Callable = func() -> float: return randf()
## True when boot found no save in any slot: a first visit (offer the web hero).
var first_run := false
## The title has been passed this session (it greets the first load only).
var title_seen := false
## A plain launch found no hero in its slot: a stand-in plays behind the title
## and is never written, until a hero is made or brought in.
var standing_in := false
## The hero's latest deed, for the town's gossip (PIX-149): {kind: cleared |
## boss | project | settler, and the name to say}. Not saved.
var last_deed := {}
## What the town has to show the hero next time they're in it (PIX-147):
## "project:<id>" built, "age:<tier>" reached, "home:<floor>" a boss's floor
## cleared. Not saved: a reload simply skips the tour.
var reveals: Array[String] = []

## The methods, by part of the game (PIX-261). Built in _init before the
## first new_game(): apply() already has Questing measure the deliveries.
var trade: Trade
var holdings: Holdings
var household: Household
var questing: Questing
var spoils: Spoils
var upkeep: Upkeep
var training: Training

var _booted := false
var _unsaved_seconds := 0.0


func _init() -> void:
	trade = Trade.new(self)
	holdings = Holdings.new(self)
	household = Household.new(self)
	questing = Questing.new(self)
	spoils = Spoils.new(self)
	upkeep = Upkeep.new(self)
	training = Training.new(self)
	new_game()
	dirty = false


func _ready() -> void:
	# The autosave runs under open screens too (PIX-200): a shop or the pack
	# holds the world still, not the saving.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_the_page()


## Every key pressed teaches the labels what this keyboard calls it (PIX-201);
## every input says whether the keycaps should show the pad's (PIX-215).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		Controls.learn(event)
	Controls.note_device(event)


## The web page going away or out of sight saves what's unsaved (PIX-200):
## the web runtime tells the game nothing when a tab closes.
var _page_hidden: Variant


func _watch_the_page() -> void:
	if not OS.has_feature("web"):
		return
	_page_hidden = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if dirty:
			save_now())
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _page_hidden)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", _page_hidden)


## Whether this browser keeps saves at all (a private window doesn't).
static func saves_kept() -> bool:
	return not OS.has_feature("web") or OS.is_userfs_persistent()


## Picks the save to play: `--slot N` or the last slot played, else a new game
## written straight to that slot. Harness runs (`--screenshot`) play a fresh
## throwaway hero unless a slot is named explicitly. Runs once per session:
## the world scene reloads after a slot switch and must not undo it.
func boot(args: PackedStringArray) -> void:
	if _booted:
		return
	_booted = true
	settings.load_file()
	# The game speaks the player's language from the first screen (PIX-195);
	# `--lang xx` (harness) picks one for the run.
	var lang_index := args.find("--lang")
	Text.apply(args[lang_index + 1] if lang_index >= 0 and lang_index + 1 < args.size() else settings.language)
	# `--pseudo` (harness): every string stretched a third longer and
	# accented, to see where a longer language would overflow (PIX-195).
	if args.has("--pseudo"):
		ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.35)
		TranslationServer.pseudolocalization_enabled = true
		TranslationServer.set_locale("fr")
		Text.forget()
	var slot_index := args.find("--slot")
	if slot_index >= 0 and slot_index + 1 < args.size():
		slot = clampi(int(args[slot_index + 1]), 1, SaveSlots.SLOT_COUNT)
	elif args.has("--screenshot"):
		slot = NO_SLOT
		settings.read_only = true
		# `still`: the run with Reduce motion on, as a player can set it.
		if args.has("still"):
			settings.reduce_motion = true
	else:
		slot = clampi(settings.last_slot, 1, SaveSlots.SLOT_COUNT)
	var saved := slots.read(slot) if slot != NO_SLOT else {}
	first_run = slot != NO_SLOT and range(1, SaveSlots.SLOT_COUNT + 1).all(
		func(n: int) -> bool: return slots.summary(n).is_empty()
	)
	if saved.is_empty():
		new_game()
		# A plain launch waits for the title's hero; a named slot starts at once.
		standing_in = slot_index < 0
		save_now()
	else:
		apply(saved)
	if slot != NO_SLOT and settings.last_slot != slot:
		settings.last_slot = slot
		settings.save_file()


## Switches play to another slot's hero (the current one is saved first) and
## says whether there was one. The caller reloads the world scene afterwards.
func play_slot(target: int) -> bool:
	# An empty slot holds no one to play (Tom: playing one skipped the hero's
	# making and the Night of Ash): a new hero is made, in creation.
	var saved := slots.read(target)
	if saved.is_empty():
		return false
	save_now()
	_use_slot(target)
	apply(saved)
	return true


## Writes a brand-new hero into a slot (replacing whatever was there) and plays it.
## `night`: begin with the Night of Ash (a returning player may skip it).
func new_hero_in(target: int, name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0, night := true) -> void:
	save_now()
	_use_slot(target)
	new_game(name, role_id, look, night)
	save_now()
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## Where a new hero should live: the slot in hand while a stand-in holds it,
## else the first empty one; 0 when all are taken.
func free_slot() -> int:
	if standing_in:
		return slot
	for n in range(1, SaveSlots.SLOT_COUNT + 1):
		if slots.summary(n).is_empty():
			return n
	return 0


## Brings a migrated save (the web game's, a pasted code) into a slot and plays it.
func import_into(target: int, state: Dictionary) -> void:
	save_now()
	_use_slot(target)
	apply(state)
	save_now()


## Empties a slot; false when it already was.
func clear_slot(target: int) -> bool:
	if slots.summary(target).is_empty():
		return false
	slots.erase(target)
	# The hero in play goes too: what's left is the title's unsaved stand-in,
	# so no autosave can write them back.
	if target == slot:
		new_game()
		standing_in = true
		dirty = false
	return true


## This hero as a PXH1 code: loads in the web game's Import too.
func save_code() -> String:
	return SaveCodec.encode_code(to_dict())


func _use_slot(target: int) -> void:
	slot = target
	first_run = false
	standing_in = false
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## A fresh level-1 hero waking in the village (CREATE_HERO).
## `prologue`: a hero made at the title begins with the Night of Ash
## (PIX-152); the stand-ins (no save yet, tests, harness runs) start in town.
func new_game(name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0, prologue := false) -> void:
	var state := SaveCodec.initial_state()
	state.merge(SaveCodec.RESUME_INTO, true)
	var weapon := InventoryState.create_gear(STARTER_WEAPONS.get(role_id, "rusty_sword"))
	state["hero"] = HeroState.create(name, role_id, look).to_dict()
	state["gold"] = STARTER_GOLD
	state["inventory"] = STARTER_ITEMS.duplicate()
	state["gear"] = [weapon]
	state["equipped"] = {"weapon": weapon["uid"]}
	state["introSeen"] = false
	state["world"] = SaveCodec.fresh_world()
	# A new hero finds Pixelheim in ashes (PIX-146); heroes from before keep
	# the town they had.
	state["townTier"] = 0
	# ... and arrives on the road the night it burns, with the letter they
	# were paid to carry (the Night of Ash, PIX-152).
	if prologue:
		state["prologue"] = Prologue.SCAVENGER
		var start := Prologue.start()
		state["world"]["position"] = {"mapId": start["mapId"], "x": start["x"], "y": start["y"], "facing": start["facing"]}
		state["worldSteps"] = int(Prologue.night_steps())
		state["inventory"]["chancellors_letter"] = 1
	apply(state)


## Replaces the whole state with a normalized web-shaped save.
func apply(state: Dictionary) -> void:
	hero = HeroState.from_dict(state["hero"])
	pack = InventoryState.from_dict(state)
	settlement = SettlementState.from_dict(state)
	progression = ProgressionState.from_dict(state)
	world = WorldState.from_dict(state)
	mark_dirty()
	questing.forget_deliveries()
	questing.note_deliveries(false)
	# Another hero: the last one's boss slayer's edge isn't theirs.
	spoils.slayer_left = 0.0
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
	# The title's stand-in hero is never written; a made or brought hero is.
	if slot != NO_SLOT and not standing_in:
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


## The hero stands on a new cell: remember it, see around it. The slain
## ledger outlives the door (PIX-142): packs come back on their own time.
func move_to(map: MapData, cell: Vector2i, facing: Vector2) -> void:
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


func town_tier() -> int:
	return clampi(settlement.town_tier, 0, Town.MAX_TIER)


## Whether this hero has seen a story moment (Cutscene scenes, PIX-32).
func has_seen(scene_id: String) -> bool:
	return scene_id in progression.story_seen


## Marks a story moment seen, for good.
func mark_seen(scene_id: String) -> void:
	if not has_seen(scene_id):
		progression.story_seen.append(scene_id)
		mark_dirty()


## The hero whole again (inn, healer, their own bed): the live body
## refills too.
func make_whole() -> void:
	hero.hp = hero.stats.get("maxHp", hero.hp)
	hero.mp = hero.stats.get("maxMp", hero.mp)
	mark_dirty()
	healed.emit()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))


## The pack or the purse changed: saved soon, the dock told, and the
## deliveries and deeds it moves counted (Questing).
func pack_changed() -> void:
	mark_dirty()
	gold_changed.emit(pack.gold)
	inventory_changed.emit()
	questing.note_deliveries()
	questing.note_deeds()
