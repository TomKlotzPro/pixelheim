extends Node
## areas: all
## The one game state (autoload `GameState`): typed sections for the hero,
## the pack, the settlement, progression and the explored world. Mutations
## go through methods that keep the save's invariants; signals tell the world
## and the screens. Persistence is write-behind: changes mark the state
## dirty, the autosave flushes it within AUTOSAVE_SECONDS, and moments that
## matter (map change, loot) save at once, which the HUD's quill shows
## (`saved`, PIX-302 step 4).
## The methods live in eight modules, one per part of the game (PIX-261):
## `trade`, `holdings`, `household`, `questing`, `spoils`, `upkeep`,
## `training` and `posting`, and callers reach them there (`GameState.questing.choose()`,
## or `state.spoils.open_chest()` in a test). This core keeps the sections,
## the signals, the saves and the slots; the modules reach them through
## their `owner`, never the autoload.

signal loaded
signal gold_changed(gold: int)
signal inventory_changed
## A conversation ended: settlers (PIX-124) and quests (PIX-125) answer here.
signal dialogue_closed(npc_id: String)
## The letter is in Maren's hands: the world plays the dawn (PIX-152).
signal prologue_dawn
## One line of feedback for the world.
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
## A save was made (PIX-302 step 4), and how it shows: QUIET (the
## autosave's, every few seconds after a change; those on leaving), MOMENT
## (something worth keeping happened: the HUD's quill writes) or SLEPT (a
## night's sleep: the quill with "Saved" under it).
signal saved(how: int)
## The hero crossed into a new rank (useRankUp): the ascension scene plays.
signal ranked_up(title: String)
## Levels were gained (the level-up fanfare).
signal leveled_up(level: int)
## A skill the hero can now use (PIX-160: its first-time hint).
## `key`: the dock key (1-6) it took, 0 when all six were taken (PIX-190).
signal skill_learned(entry: Dictionary, key: int)

## Slot 0 never touches disk: harness runs and tests leave real saves alone.
const NO_SLOT := 0
## The dice a harness run throws (PIX-276): any number, the same every run.
const HARNESS_SEED := 276
const AUTOSAVE_SECONDS := 3.0
## How a save shows (`saved`, PIX-302 step 4).
const QUIET := 0
const MOMENT := 1
const SLEPT := 2
## The hero nobody named (the stand-ins: the title's, tests, harness runs),
## in the language they were made in, once (PIX-347): a name is never
## translated after, so the dock and the stats sheet say the same.
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
## The Pixelheim Post as this hero keeps it (PIX-320): the satchel's
## pieces, each thread's step, what's delivered.
var post: PostState
var slots := SaveSlots.new()
var settings := GameSettings.new()
var slot := NO_SLOT
var dirty := false
## Changes marked this session (mark_dirty counts them): a screen let go
## after one saves, even when the autosave kept it while it was open, so
## leaving it shows the quill (Screen, PIX-302 step 4).
var changes := 0
## The saves made this session, and when the last was, by the game's clock
## (GameClock.seconds(); -1 before the first): the pause menu's "Saved 12 s
## ago" and the harness's report.
var saves_made := 0
var saved_clock := -1.0
## Seconds played with this hero (PIX-302): counted past the title, saved
## whole; heroes from before v5 had none to count.
var play_seconds := 0.0
## Dice for chance rolls (double brews); tests swap in a loaded die.
var roll: Callable = func() -> float: return randf()
## The title has been passed this session (it greets the first load only).
var title_seen := false
## A plain launch found no hero in its slot: a stand-in plays behind the title
## and is never written, until a hero is made or brought in.
var standing_in := false
## A quiet word about the slot in hand (PIX-303), for whoever shows it first
## (the title's line, else the world's plate), then cleared: its hero came
## from the save before, or the slot a launch opened couldn't be read.
## Not saved.
var slot_note := ""
## The hero's latest deed, for the town's gossip (PIX-149): {kind: cleared |
## boss | project | settler, and the name to say}. Not saved.
var last_deed := {}
## What the town has to show the hero next time they're in it (PIX-147):
## "project:<id>" built, "age:<tier>" reached, "home:<floor>" a boss's floor
## cleared. Not saved: a reload simply skips the tour.
var reveals: Array[String] = []

## The methods, by part of the game (PIX-261; the Post, PIX-320). Built in
## _init before the first new_game(): apply() already has Questing measure
## the deliveries.
var trade: Trade
var holdings: Holdings
var household: Household
var questing: Questing
var spoils: Spoils
var upkeep: Upkeep
var training: Training
var posting: Posting

var _booted := false
var _unsaved_seconds := 0.0
## The play time the last save wrote: leaving writes the time since too.
var _saved_play := 0.0


func _init() -> void:
	trade = Trade.new(self)
	holdings = Holdings.new(self)
	household = Household.new(self)
	questing = Questing.new(self)
	spoils = Spoils.new(self)
	upkeep = Upkeep.new(self)
	training = Training.new(self)
	posting = Posting.new(self)
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
			save_now(QUIET))
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _page_hidden)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", _page_hidden)


## Whether this browser keeps saves at all (a private window doesn't).
static func saves_kept() -> bool:
	return not OS.has_feature("web") or OS.is_userfs_persistent()


## Picks the save to play: slot `asked` (`--slot N`; -1 when none is) or
## the last slot played, else a new game written straight to that slot. Runs
## once per session: the world scene reloads after a slot switch and must not
## undo it. A harness run (`--screenshot`) boots through HarnessBoot.boot
## instead (PIX-357): a fresh throwaway hero, its own settings.
func boot(asked := -1) -> void:
	if not begin_boot():
		return
	settings.load_file()
	# The game speaks the player's language from the first screen (PIX-195).
	Text.apply(settings.language)
	slot = clampi(asked if asked >= 0 else settings.last_slot, 1, SaveSlots.SLOT_COUNT)
	wake(asked >= 0)


## Whether the session is yet to boot, which it now is: once only.
func begin_boot() -> bool:
	if _booted:
		return false
	_booted = true
	return true


## Plays the hero in `slot`, or `loaded` (a save read from elsewhere, when
## there's no slot), else a new game written straight to the slot. `named`:
## the slot was asked for (`--slot N`).
func wake(named: bool, loaded := {}) -> void:
	var seen := slots.look(slot) if slot != NO_SLOT else {"kind": SaveSlots.EMPTY}
	var saved: Dictionary = seen["state"] if seen["kind"] == SaveSlots.HERO else loaded
	if saved.is_empty():
		new_game()
		# A plain launch waits for the title's hero; a named slot starts at
		# once, unless what's in it can't be read: nothing is written over
		# that, and a hero made at the title goes to a free slot (PIX-303).
		standing_in = not named or seen["kind"] != SaveSlots.EMPTY
		slot_note = unread_note(slot, seen["kind"])
		save_now()
	else:
		apply(saved)
		slot_note = backup_note(seen)
	if slot != NO_SLOT and settings.last_slot != slot:
		settings.last_slot = slot
		settings.save_file()


## Switches play to another slot's hero (the current one is saved first) and
## says whether there was one. The caller reloads the world scene afterwards.
func play_slot(target: int) -> bool:
	# An empty slot holds no one to play (Tom: playing one skipped the hero's
	# making and the Night of Ash): a new hero is made, in creation.
	var seen := slots.look(target)
	if seen["kind"] != SaveSlots.HERO:
		return false
	save_now()
	_use_slot(target)
	apply(seen["state"])
	slot_note = backup_note(seen)
	return true


## What a hero read from the save before is told (PIX-303), or "".
static func backup_note(seen: Dictionary) -> String:
	if not seen.get("backup", false):
		return ""
	return Text.t("%s's last save couldn't be read, so the game loaded the one before it.") % seen["state"]["hero"]["name"]


## What a launch that couldn't read its slot says (PIX-303): it's kept as
## it was, and the saves screen shows it. "" for an empty slot.
static func unread_note(target: int, kind: String) -> String:
	match kind:
		SaveSlots.DAMAGED:
			return Text.t("Slot %d's save can't be read. It's kept as it is, in Saves.") % target
		SaveSlots.NEWER:
			return Text.t("Slot %d was saved by a newer version of Pixelheim. It's kept as it is, in Saves.") % target
		SaveSlots.OLDER:
			return Text.t("Slot %d was saved by an older version of Pixelheim. It's kept as it is, in Saves.") % target
	return ""


## Writes a brand-new hero into a slot (replacing whatever was there) and plays it.
## `night`: begin with the Night of Ash (a returning player may skip it).
func new_hero_in(target: int, name := "", role_id := DEFAULT_ROLE, look := 0, night := true) -> void:
	save_now()
	_use_slot(target)
	slot_note = ""
	new_game(name, role_id, look, night)
	save_now()
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## Where a new hero should live: the slot in hand while a stand-in holds it,
## else the first empty one; 0 when all are taken. A slot holding a save
## this version can't read is never free, the one in hand neither (PIX-303:
## a launch that couldn't read the last slot played made its next hero
## there, over the file).
func free_slot() -> int:
	if standing_in and (slot == NO_SLOT or slots.is_free(slot)):
		return slot
	for n in range(1, SaveSlots.SLOT_COUNT + 1):
		if slots.is_free(n):
			return n
	return 0


## Whether New Game has a slot for a new hero (PIX-316: with none free it
## says so, never writing over a hero or a save it can't read). A harness
## run's throwaway stand-in always has, and writes nowhere.
func room_for_hero() -> bool:
	return free_slot() != NO_SLOT or (standing_in and slot == NO_SLOT)


## Brings a save (a pasted code) into a slot and plays it.
func import_into(target: int, state: Dictionary) -> void:
	save_now()
	_use_slot(target)
	slot_note = ""
	apply(state)
	save_now()


## Empties a slot, a save it couldn't read too; false when it already was.
func clear_slot(target: int) -> bool:
	if slots.is_free(target):
		return false
	slots.erase(target)
	# The hero in play goes too: what's left is the title's unsaved stand-in,
	# so no autosave can write them back.
	if target == slot:
		new_game()
		standing_in = true
		dirty = false
	return true


## This hero as a PXH2 code: pasted into another copy's Saves, it loads there.
func save_code() -> String:
	return SaveCodec.encode_code(to_dict())


func _use_slot(target: int) -> void:
	slot = target
	standing_in = false
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## A fresh level-1 hero waking in the village (CREATE_HERO).
## `prologue`: a hero made at the title begins with the Night of Ash
## (PIX-152); the stand-ins (no save yet, tests, harness runs) start in town.
func new_game(name := "", role_id := DEFAULT_ROLE, look := 0, prologue := false) -> void:
	var state := SaveCodec.initial_state()
	var weapon := InventoryState.create_gear(STARTER_WEAPONS.get(role_id, "rusty_sword"))
	state["hero"] = HeroState.create(name if name != "" else Text.t(DEFAULT_HERO_NAME), role_id, look).to_dict()
	state["gold"] = STARTER_GOLD
	state["inventory"] = STARTER_ITEMS.duplicate()
	state["gear"] = [weapon]
	state["equipped"] = {"weapon": weapon["uid"]}
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


## Replaces the whole state with a normalized save.
func apply(state: Dictionary) -> void:
	hero = HeroState.from_dict(state["hero"])
	pack = InventoryState.from_dict(state)
	settlement = SettlementState.from_dict(state)
	progression = ProgressionState.from_dict(state)
	world = WorldState.from_dict(state)
	post = PostState.from_dict(state.get("post", {}))
	play_seconds = float(state.get("playSeconds", 0))
	mark_dirty()
	questing.forget_deliveries()
	questing.note_deliveries(false)
	# A save that won a keepsake before its family could come home finds
	# them home (PIX-255: Wenna at Sela's inn, with the ladle won).
	holdings.come_home(true)
	# Another hero: the last one's boss slayer's edge isn't theirs.
	spoils.slayer_left = 0.0
	loaded.emit()
	gold_changed.emit(pack.gold)
	inventory_changed.emit()


## The whole state as a save holds it: what a slot file or a save code carries.
func to_dict() -> Dictionary:
	var state := SaveCodec.initial_state()
	state["hero"] = hero.to_dict()
	pack.write_into(state)
	settlement.write_into(state)
	progression.write_into(state)
	world.write_into(state)
	# The Post's own section (PIX-320), once there's anything in it.
	if not post.is_empty():
		state["post"] = post.to_dict()
	state["playSeconds"] = int(play_seconds)
	return state


func mark_dirty() -> void:
	dirty = true
	changes += 1


## Writes the hero to their slot now. `how` says how it shows (`saved`):
## a moment by default, as every save the game makes on purpose is (a door,
## a chest, a step of a quest, buying, funding, a skill learned, a screen
## left after a change, the title, the language); the autosave and the
## saves on leaving are QUIET, a night's sleep SLEPT.
func save_now(how := MOMENT) -> void:
	dirty = false
	_unsaved_seconds = 0.0
	_saved_play = play_seconds
	# The title's stand-in hero is never written; a made or brought hero is.
	if slot != NO_SLOT and not standing_in:
		slots.write(slot, to_dict())
	saves_made += 1
	saved_clock = GameClock.seconds()
	saved.emit(how)


func _process(delta: float) -> void:
	# Time played is the hero's in hand past the title, never a stand-in's.
	if title_seen and not standing_in:
		play_seconds += delta
	if not dirty:
		return
	_unsaved_seconds += delta
	if _unsaved_seconds >= AUTOSAVE_SECONDS:
		save_now(QUIET)


func _notification(what: int) -> void:
	# Window closed, tab hidden, app backgrounded, or the tree shutting down.
	var leaving := (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_EXIT_TREE
	)
	# Time played since the last save is kept too (it marks nothing dirty:
	# a hero standing still isn't saved every few seconds for it).
	if leaving and (dirty or play_seconds - _saved_play >= 1.0):
		save_now(QUIET)


## The hero stands on a new cell: remember it, see around it. The slain
## ledger outlives the door (PIX-142): packs come back on their own time.
func move_to(map: MapData, cell: Vector2i, facing: Vector2) -> void:
	world.map_id = map.id
	world.cell = cell
	world.facing = WorldState.facing_name(facing)
	Discovery.discover_around(world.discovered, map, cell)
	mark_dirty()


func walk(tiles: float) -> void:
	# The Night of Bells keeps its own clock (PIX-253 step 9): it holds at
	# the middle of the night, and turns toward dawn as the square is held.
	if tiles <= 0.0 or progression.bells != Bells.NONE:
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
