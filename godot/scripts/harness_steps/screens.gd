extends RefCounted
## areas: all
## The harness's screens (PIX-357): the sheets, the title and its menus, the
## pack, the codex, the journal, the counters and ledgers, the saves, and
## keys pressed at whatever opened.
##
## Each `step_<name>()` is the step a flag names in scripts/harness_flags.txt
## (`flag | takes | does | step | order`); harness.gd runs the steps of the
## flags it was given in their order, awaiting each.

## The harness (harness.gd): its tree, its key presses and what's open.
var h: Node
var world: Node
var flags: HarnessFlags
## The report line's fields; a value known only part-way through is noted
## as it's known.
var report: HarnessReport


func step_rankup() -> void:
	# Enough XP to cross into the next rank: the ascension plays.
	var hero := GameState.hero
	hero.level = (HeroRules.rank_index(hero.level) + 1) * 5 - 1
	hero.xp_to_next = HeroState.xp_to_next_for(hero.level)
	hero.xp = hero.xp_to_next
	GameState.spoils.grant_levels()
	if flags.has("--rank-beat"):
		# `--rank-beat flare` (PIX-244): the moment held at that beat.
		await _hold_rank_beat(flags.value("--rank-beat"))
	else:
		await h.get_tree().create_timer(1.6).timeout
	if flags.has("walk-path"):
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("_walk"))[0]._walk()
		await h.get_tree().create_timer(0.3).timeout


func step_path() -> void:
	# A path already walked: `--path juggernaut,bastion`.
	GameState.hero.path = Array(flags.list("--path"))
	Skills.place_on_dock(GameState.hero, "path")


func step_stats() -> void:
	await _sheet("stats_screen")


## With `stats` too, its sheet is the one shown.
func step_skills() -> void:
	if not flags.has("stats"):
		await _sheet("skills_screen")


func step_create() -> void:
	# Hero creation over the title, a role picked (`--role`, else the
	# ranger) and a name typed.
	var creation := preload("res://scripts/create_screen.gd").new()
	creation.world = world
	creation.role_index = maxi(0, creation.ROLES.find(flags.value("--role", "ranger")))
	world.add_child(creation)
	await h.get_tree().create_timer(0.1).timeout
	creation.name_field.text = "Robin"
	creation._refresh()
	await h.get_tree().create_timer(0.4).timeout


## `title --keys s,s,s`: walk the title's menu (with `talk`, the keys are
## the conversation's).
func step_title() -> void:
	if not flags.has("talk"):
		await h._keys(flags)


func step_whatsnew() -> void:
	if not flags.has("title"):
		return
	# What's new over the title, as the version line opens it.
	world.get_children().filter(func(node: Node) -> bool: return node.has_method("_whats_new"))[0]._whats_new()
	await h.get_tree().create_timer(0.3).timeout


## The pause menu; with `options`, that step opens it (or the title's).
func step_pause() -> void:
	if not flags.has("options"):
		await _pause_menu()


func step_options() -> void:
	if flags.has("title"):
		# Options over the title, before any hero is made.
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("_whats_new"))[0]._options()
		await h.get_tree().create_timer(0.3).timeout
	else:
		await _pause_menu()


func step_inventory() -> void:
	# A pack worth reading: a fine sword, armor worn, potions and an antidote.
	var sword := InventoryState.create_gear("iron_sword", "fine")
	var armor := InventoryState.create_gear("leather_armor")
	var ring := InventoryState.create_gear("band_of_grit")
	GameState.pack.gear.append_array([sword, armor, ring])
	GameState.upkeep.equip(armor["uid"])
	GameState.upkeep.equip(ring["uid"])
	GameState.pack.items.merge({"potion_hp": 3, "antidote": 1, "wolf_pelt": 2})
	world.open_inventory()
	# `--tab N` opens another tab (7 is Craft).
	if flags.has("--tab"):
		world.get_children().filter(func(node: Node) -> bool: return node.has_method("_craft_rows"))[-1]._switch(int(flags.value("--tab")))
	await h.get_tree().create_timer(0.3).timeout


func step_codex() -> void:
	# A record to read: twelve beasts (Slayer I) and a few undead.
	GameState.hero.mastery = {"beasts": 12, "undead": 3}
	var codex := preload("res://scripts/codex_screen.gd").new()
	codex.tab = 1 if flags.has("bestiary") else 0
	world.add_child(codex)
	await h.get_tree().create_timer(0.3).timeout


func step_journal() -> void:
	# A few promises in hand: slimes half done, the cheese ready, the troll
	# kept; Maren's relics asked for, the ladle won, the iron still out
	# there (PIX-171). Her tin opened, and the satchel's letters: Wenna's
	# answered with the ladle home, Pell's handed over, two still to
	# deliver (PIX-253 step 2). `--tab letters|feats` opens that page
	# (PIX-239); `--hunted seam_warden`, a second relic, posts the next
	# notice on the board for its bounties (PIX-170).
	GameState.progression.quests.merge({
		"slime_trouble": {"progress": 2, "done": false},
		"cheese_run": {"progress": 0, "done": false},
		"troll_toll": {"progress": 1, "done": true},
		"maren_relics": {"progress": 0, "done": false},
		"garrick_crew": {"progress": 4, "done": true},
		"garrick_seam": {"progress": 0, "done": false},
		"sela_rum": {"progress": 0, "done": false},
	})
	if "tidecaller" not in GameState.progression.hunted:
		GameState.progression.hunted.append("tidecaller")
	GameState.pack.add_item("cheese_wheel")
	GameState.pack.add_item("tams_ladle")
	GameState.questing.open_tin()
	GameState.questing.deliver("mines_pell")
	var journal := preload("res://scripts/journal_screen.gd").new()
	if flags.has("--tab"):
		journal.tab = flags.value("--tab")
	world.add_child(journal)
	await h.get_tree().create_timer(0.3).timeout


func step_dockmenu() -> void:
	# The dock's menu of screens, opened as its button would.
	world.hud.dock.toggle_menu()
	await h.get_tree().create_timer(0.2).timeout


func step_shop() -> void:
	# Pair with `--map town_shop|town_smith|town_alchemist`; `--tab N` picks a tab.
	# A pack to sell (PIX-336): pelts, and junk - herbs past what crafting
	# keeps, old boots (`--wear iron_sword` leaves the rusty one as junk).
	GameState.pack.gold = 500
	GameState.pack.items.merge({"wolf_pelt": 3, "forest_herb": 10, "old_boot": 2})
	var screen: Node = preload("res://scripts/shop_screen.gd").new()
	world.add_child(screen)
	if flags.has("--tab"):
		screen._switch(int(flags.value("--tab")))
	await h.get_tree().create_timer(0.3).timeout


func step_home() -> void:
	# Pair with `--map town_house`; `--mode storage|workbench|trophies|nook|furniture`.
	GameState.settlement.house["owned"] = true
	GameState.pack.items.merge({"furn_plant": 1, "furn_rug": 1, "potion_hp": 4, "gem": 1})
	var screen := preload("res://scripts/home_screen.gd").new()
	screen.mode = flags.value("--mode", "storage")
	world.add_child(screen)
	await h.get_tree().create_timer(0.3).timeout


func step_hall() -> void:
	await _ledger("town_hall_screen")


## With `hall` too, the hall's ledger is the one shown.
func step_bank() -> void:
	if not flags.has("hall"):
		await _ledger("bank_screen")


func step_saves() -> void:
	# With `--slots <dir>`, GameState.boot has read the slots from that
	# folder (PIX-230: the cards' lines widened the window off the screen
	# only once heroes filled them; PIX-303: the cards of saves it can't
	# read), instead of the player's own.
	world.open_saves()
	await h.get_tree().create_timer(0.3).timeout


## `--keys` at whatever screen the run opened (talk, --talk-to and title
## press theirs earlier; --talk-to's were pressed twice until PIX-253):
## `inventory --keys esc` checks it closes and lets the world go.
func step_keys() -> void:
	if not flags.has("talk") and not flags.has("--talk-to") and not flags.has("title"):
		await h._keys(flags)


## How far into each of the ascension's beats `--rank-beat` holds it: the
## light up and the hero lifted, the hero half back out of the flare's
## white, the name landed, the lines shown, the hero down.
const RANK_BEAT_INTO := {"hush": 0.5, "lift": 0.8, "flare": 0.3, "named": 0.45, "unlocks": 0.7, "settled": 0.7}


## Stops the ascension at `beat`, waits for it and a moment into it (its own
## motion playing on), then holds it there for the picture. Asked as the
## moment opens, before its first beat.
func _hold_rank_beat(beat: String) -> void:
	var opened: Node = h._ascension()
	if opened == null:
		return
	opened.hold_at(beat)
	# In the game's time, a twentieth of a second at a time (PIX-276: every
	# wait here is, the run stepped by tools/flows.sh).
	for tick in 200:
		if not is_instance_valid(opened) or opened.phase == beat:
			break
		await h.get_tree().create_timer(0.05).timeout
	await h.get_tree().create_timer(float(RANK_BEAT_INTO.get(beat, 0.3))).timeout
	if is_instance_valid(opened):
		opened.hold_still()


## Points to spend, a few of each, and `sheet` (stats_screen,
## skills_screen) to spend them on.
func _sheet(sheet: String) -> void:
	# Points to spend: a few of each.
	GameState.hero.stat_points = 5
	GameState.hero.skill_points = 3
	world.add_child(load("res://scripts/%s.gd" % sheet).new())
	await h.get_tree().create_timer(0.3).timeout


## The pause menu (`scanlines` on first), its options open with `options`.
func _pause_menu() -> void:
	if flags.has("scanlines"):
		GameState.settings.scanlines = true
		world.apply_video()
	var pause := preload("res://scripts/pause_screen.gd").new()
	pause.world = world
	world.add_child(pause)
	if flags.has("options"):
		pause._options()
	await h.get_tree().create_timer(0.3).timeout


## `ledger` (town_hall_screen, bank_screen) with 20000g in hand.
func _ledger(ledger: String) -> void:
	GameState.pack.gold = 20000
	# `--own town_shop,town_smith`: deeds held, four days of rent waiting (PIX-178).
	if flags.has("--own"):
		for map_id in flags.list("--own"):
			GameState.settlement.properties.append(map_id)
			GameState.holdings.investments()["tills"] = GameState.holdings.investments().get("tills", {})
			GameState.holdings.investments()["tills"][map_id] = {"gold": 0, "earned": 900, "at": GameState.holdings.steps_now() - 480 * 4}
	world.add_child(load("res://scripts/%s.gd" % ledger).new())
	await h.get_tree().create_timer(0.3).timeout
