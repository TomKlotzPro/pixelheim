class_name HarnessBoot
## areas: all
## The screenshot harness's boot (PIX-357): a `--screenshot` run's throwaway
## hero and settings, and the presets its flows ask for before the first map
## is drawn (`--town-tier`, `--built`, `--bells`...). world.gd and GameState
## used to read these flags themselves, and 11 of 23 edits to world.gd were
## presets; now world._ready calls `boot` in GameState.boot's place, then
## `before_first_map`, and only in a harness run.

## The level a harness run's hero comes home to the Night of Bells at
## (`--bells`, PIX-253 step 9): the story's, about 13.
const BELLS_LEVEL := 13


## A harness run's GameState.boot: `state` (GameState) plays a fresh
## throwaway hero, seeded, its settings read but never written, unless
## `--slot N` names a slot; once per session, as GameState.boot.
static func boot(flags: HarnessFlags, state: Node) -> void:
	if not state.begin_boot():
		return
	# A harness run throws the same dice every run (PIX-276): what a kill
	# drops, a crit, where a foe wanders, a sound's pitch (it draws from the
	# same dice), all as the run before; unseeded, a flow whose loot rolled
	# another way read differently on every run. With GameClock and the
	# stepped frames (tools/flows.sh), a flow is the same run each time.
	seed(GameState.HARNESS_SEED)
	state.settings.load_file()
	# `--lang xx` picks the run's language (PIX-195).
	Text.apply(flags.value("--lang", state.settings.language))
	# `--pseudo`: every string stretched a third longer and accented, to see
	# where a longer language would overflow (PIX-195).
	if flags.has("--pseudo"):
		ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.35)
		TranslationServer.pseudolocalization_enabled = true
		TranslationServer.set_locale("fr")
		Text.forget()
	var loaded := {}
	if flags.has("--slot"):
		state.slot = clampi(int(flags.value("--slot")), 1, SaveSlots.SLOT_COUNT)
	else:
		state.slot = GameState.NO_SLOT
		state.settings.read_only = true
		# `still`: the run with Reduce motion on, as a player can set it.
		if flags.has("still"):
			state.settings.reduce_motion = true
		# `hints`: a new player's first-time hints, none seen (PIX-341).
		if flags.has("hints"):
			state.settings.hints = true
			state.settings.hints_seen.clear()
		# `--slots <dir>`: the slots read from a folder of fixtures, never
		# written (PIX-230); `launch` opens its first slot as a plain launch
		# opens the last one played (PIX-303: one it can't read).
		if flags.has("--slots"):
			state.slots = SaveSlots.new(flags.value("--slots"), true)
			if flags.has("launch"):
				state.slot = 1
		else:
			# The player's own slots, read at most: no key a run presses (a
			# saves screen's, creation's Begin) writes or clears one.
			state.slots.read_only = true
		# `--load <file>`: a save played as it loads from a slot (a code or
		# a v5 file: the fixtures in test/fixtures), nothing written back
		# (PIX-302: where a save wakes).
		if state.slot == GameState.NO_SLOT and flags.has("--load"):
			loaded = SaveCodec.parse_any(FileAccess.get_file_as_string(flags.value("--load")))
	state.wake(flags.has("--slot"), loaded)


## Whether a batch (`--batch`, PIX-360) has a flow left, which then runs in
## this Godot: at the next physics tick, the scene is freed, everything a
## boot sets but a scene's reload doesn't is as a boot left it, and the main
## scene is ready again, as at a launch, before the tick's work.
static func next_flow(tree: SceneTree) -> bool:
	if HarnessFlags.batch.is_empty():
		return false
	tree.physics_frame.connect(_reboot.bind(tree), CONNECT_ONE_SHOT)
	return true


static func _reboot(tree: SceneTree) -> void:
	var main := tree.current_scene.scene_file_path
	tree.current_scene.free()
	HarnessFlags.next_in_batch()
	tree.paused = false
	Engine.time_scale = 1.0
	# The game's clock at nought as the scene is ready, as at a launch.
	GameClock.origin = Engine.get_physics_frames()
	# The statics that hold a run's state, not what the data or the art
	# work out the same each time (those stay): the kept ground (its woods
	# too), the healed count, the screens open, the keys learned.
	KeptGround.forget()
	Lamps._counted = {}
	InventoryState._uid_counter = 0
	Dissolve.held_at = -1.0
	preload("res://scripts/title_screen.gd")._risen = false
	Controls.pad = false
	Controls.learned = {}
	Screen._holds = 0
	Screen._changes_at = 0
	Screen._shown.clear()
	Screen._asides = 0
	Screen._hud_layer = null
	Screen._hud_showed = true
	# A launch has no tween running (the scene's went with it).
	for tween in tree.get_processed_tweens():
		tween.kill()
	# The autoloads (GameState, Sound) made again from their scripts: every
	# variable as its _init and _ready leave it, Sound's players new.
	for autoload: Node in [GameState, Sound]:
		var script: Script = autoload.get_script()
		for child in autoload.get_children():
			child.free()
		autoload.set_script(null)
		autoload.set_script(script)
		autoload.call("_ready")
	var scene: Node = load(main).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	# This tick is the launch's first: a tick on.
	GameClock.origin -= 1


## The presets, set before the first map is drawn so it's drawn with them.
static func before_first_map(flags: HarnessFlags) -> void:
	# `--town-tier N` previews the village at another age; without it
	# a run shows the Hamlet its flows were written for (`--town-tier 0` is a
	# new hero's Ashes).
	if flags.has("--town-tier"):
		GameState.settlement.town_tier = int(flags.value("--town-tier"))
	elif GameState.settlement.projects.is_empty():
		GameState.settlement.town_tier = maxi(1, GameState.settlement.town_tier)
	# `--built the_inn`: those projects standing too, whatever the age
	# (PIX-283: a keeper is in their building as soon as it stands).
	if flags.has("--built"):
		var done := Town.done_projects(GameState.settlement)
		for project_id: String in flags.list("--built"):
			if project_id not in done:
				done.append(project_id)
		GameState.settlement.projects.assign(done)
	# `--settlers iva,wren`: recruits already living in town, before the
	# first map is drawn (PIX-338: Mirelle's table stands by the hall).
	for short: String in flags.list("--settlers"):
		var id := "settler_" + short
		if id not in GameState.settlement.settlers:
			GameState.settlement.settlers.append(id)
	# Harness runs skip the Night of Ash (their flows were written for the
	# town by day) unless `--prologue N` puts them at its step N.
	if flags.has("--prologue"):
		GameState.progression.prologue = int(flags.value("--prologue"))
		GameState.settlement.town_tier = 0
		GameState.world.steps = Prologue.night_steps()
		if GameState.progression.prologue == Prologue.SCAVENGER:
			var start := Prologue.start()
			GameState.world.map_id = start["mapId"]
			GameState.world.cell = Vector2i(start["x"], start["y"])
	elif GameState.progression.prologue != Prologue.DONE:
		# A slot from a real run (--slot N) mid-night: start it by day.
		GameState.progression.prologue = Prologue.DONE
		GameState.world.steps = 0.0
		GameState.world.map_id = "town"
		var spawn: Dictionary = Catalog._data()["townSpawn"]
		GameState.world.cell = Vector2i(int(spawn["x"]), int(spawn["y"]))
		GameState.pack.remove_item("chancellors_letter")
	if flags.has("--house-tier"):
		GameState.settlement.house["tier"] = int(flags.value("--house-tier"))
	# `--day N`: the morning of day N, its patches grown (PIX-250).
	if flags.has("--day"):
		GameState.world.steps = float(int(flags.value("--day")) * DayNight.DAY_CYCLE_STEPS)
	# `--seen` and `--hunted`: stories told and named monsters slain before
	# the first map is drawn, so the gates they open stand open (PIX-254).
	for story_id: String in flags.list("--seen"):
		GameState.mark_seen(story_id)
	for named_id: String in flags.list("--hunted"):
		if named_id not in GameState.progression.hunted:
			GameState.progression.hunted.append(named_id)
	# `--delivered letter_hale`: one of Maren's letters handed over and
	# answered (PIX-255), before the first map is drawn, so Hale's order
	# book lies open on his table (PIX-348).
	if flags.has("--delivered"):
		GameState.progression.quests[flags.value("--delivered")] = {"progress": 1, "done": true}
	# `--post` (PIX-320): the Pixelheim Post open before the first map is
	# drawn, so its box stands on the square: Maren's tin found, her first
	# letter in Wenna's hands, and Saltmere walked, where it went, and the
	# Reach on the way (PIX-321: Mirelle and Wren write from its road).
	if flags.has("--post"):
		var first: Dictionary = Letters.all()[0]
		GameState.mark_seen(Letters.scene_id())
		GameState.progression.quests[first["id"]] = {"progress": 1, "done": true}
		var wenna := Npcs.by_id(String(first["objective"]["to"]), GameState.settlement.settlers)
		Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(String(wenna["mapId"])), Vector2i(int(wenna["x"]), int(wenna["y"])))
		var reach := MapData.load_by_id("overworld")
		Discovery.discover_around(GameState.world.discovered, reach, reach.spawn)
	# `--routes saltmere:6,blackiron:3:dagny` or `all` (PIX-322): the Post's
	# roads carried along before the first map is drawn, so the signposts
	# their forks earn stand on it (a waystation with `--built`).
	if flags.has("--routes"):
		var specs := flags.list("--routes")
		if flags.value("--routes") == "all":
			specs = PackedStringArray()
			for place: String in Routes.places():
				specs.append("%s:%d" % [place, Routes.station_at(place) if not Routes.station(place).is_empty() else Routes.signs_at(place)])
		for spec: String in specs:
			var parts := spec.split(":")
			Routes.tally(GameState.post, parts[0], parts[2] if parts.size() > 2 else "bram", int(parts[1]))
		Routes.raise_signs(GameState.post)
	# `--lit blackiron:3` (PIX-323): that waystation's ember lamp lit three
	# mornings ago (built with `--built`), its ring of healed land as far.
	for spec: String in flags.list("--lit"):
		var lit := spec.split(":")
		GameState.post.lit[lit[0]] = Gathering.day_of(GameState.world.steps) - int(lit[1])
	# `--bells N` (PIX-253 step 9): the story at the Night of Bells - the tin
	# found, the four keepsakes and their families home, Maren heard out,
	# the fifth letter delivered - in a Village building its Town (unless
	# `--town-tier` says otherwise); arriving home begins the night, and the
	# harness moves it on to beat N.
	if flags.has("--bells"):
		GameState.mark_seen(Letters.scene_id())
		GameState.mark_seen(Letters.confession_id())
		GameState.progression.quests[Relics.quest_id()] = {"progress": Relics.all().size(), "done": true}
		GameState.progression.quests[Letters.fifth_quest()["id"]] = {"progress": 1, "done": true}
		for relic: Dictionary in Relics.all():
			if relic["named"] not in GameState.progression.hunted:
				GameState.progression.hunted.append(relic["named"])
		if not flags.has("--town-tier"):
			GameState.settlement.town_tier = 2
		# A hero of the night's level, grown as levels grow them.
		while GameState.hero.level < BELLS_LEVEL:
			GameState.hero.xp = GameState.hero.xp_to_next
			HeroRules.apply_level_ups(GameState.hero)
		GameState.hero.xp = 0
		GameState.hero.hp = int(GameState.hero.stats["maxHp"])
	# The family a keepsake brings home is home already (PIX-255).
	if flags.has("--hunted") or flags.has("--bells"):
		GameState.holdings.come_home(true)
