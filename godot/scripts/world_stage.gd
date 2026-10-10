class_name Stage
extends Node
## The story played over the world (Solid Ground, PIX-260: moved out of
## world.gd as it was): story moments and dreams, the ascension, the Night
## of Ash's beats and its dawn, the ending with its festival or lanterns,
## the town's reveals after the board, an escort's wagon and the clock of a
## quest against time. The screens and scenes it plays stand on the world.

var world: Node
## An escort under way on this map (PIX-192): its wagon waits at the start
## of the route, or comes back there a few breaths after it was lost.
var escort: Node2D
var escort_lost_at := -100.0
## A quest against the clock (PIX-192): its time ticks while the world runs,
## shown top right, red in its last half minute; a lapse closes the chest the
## goods went back to.
var run_clock: PanelContainer


## How long the world must have been free before a chapter card comes
## (PIX-253 step 2): not over a word just said, a fight, a message.
const CARD_WAIT := 1.2
var _card_wait := 0.0
## Whether chapter cards come: always in play; in a harness run only once
## the run asks (its `chapter` step), so no other run's shot is a card and
## a run that sets the story up first shows the card of where it set it.
var cards := true


## A chapter card as a chapter of the main story opens (PIX-253 step 2):
## once the world has run a moment with no fight on and nothing on the
## message plate, the card of the chapter the story is in, if it hasn't been
## shown (MainQuest.card_due). The world runs only while no screen holds it,
## so a conversation, a menu or the dawn always comes first.
func watch_chapters(delta: float) -> void:
	if not cards:
		return
	var busy: bool = world.foes.in_fight() or world.messages.message_box.modulate.a > 0.05
	_card_wait = 0.0 if busy else _card_wait + delta
	if _card_wait < CARD_WAIT:
		return
	_card_wait = 0.0
	var number := MainQuest.card_due(GameState.progression, GameState.settlement)
	if number > 0:
		show_chapter(number)
		return
	watch_continued()


## Chapter `number`'s card over the world, kept in the story ledger as shown.
func show_chapter(number: int) -> void:
	GameState.mark_seen(MainQuest.card_id(number))
	var card := preload("res://scripts/chapter_screen.gd").new()
	card.number = number
	world.add_child(card)


## Arriving home with the story run out (PIX-253 step 8: "To be continued:
## the Night of Bells.", until step 9 writes it): the honest card, once a
## session, while the hero is in town. Asked with the chapter cards, once
## the world has been free a moment.
var _continued_shown := false


func watch_continued() -> void:
	if _continued_shown or world.map == null or world.map.id != "town":
		return
	var title := MainQuest.continued(GameState.progression, GameState.settlement)
	if title == "":
		return
	_continued_shown = true
	var card := preload("res://scripts/chapter_screen.gd").new()
	card.number = MainQuest.chapters().map(func(chapter: Dictionary) -> String: return chapter["title"]).find(title) + 1
	card.continued = true
	world.add_child(card)


## Morvax reads his letter, and the mountain shakes (PIX-253 step 8): the
## ground jumps under the forge and something roars far above; after a
## breath he says what it means (`lines`, his).
func mountain_shakes(npc: Dictionary, lines: Array) -> void:
	world.camera_rig.shake(8.0, 1.4)
	Sound.play("roar")
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	var said := npc.duplicate()
	said["lines"] = lines
	var box := preload("res://scripts/dialogue_box.gd").new()
	box.npc = said
	world.add_child(box)


## A story moment over the world (Cutscene, PIX-32), once per hero; "" or a
## moment already seen plays nothing.
func play_story(scene_id: String) -> void:
	if scene_id == "" or GameState.has_seen(scene_id):
		return
	GameState.mark_seen(scene_id)
	var scene := Cutscene.new()
	scene.scene_id = scene_id
	world.add_child(scene)


## The ascension scene: a new title, and at a fork the path cards.
func ascend(title: String) -> void:
	Sound.play("evolve")
	var scene := preload("res://scripts/rankup_screen.gd").new()
	scene.title = title
	world.add_child(scene)


## A night under Sela's roof (or canvas) brings Morvax's voice, once per
## dream, in the order the story earns them (PIX-154).
func dream() -> void:
	if GameState.progression.prologue != Prologue.DONE:
		return
	play_story(Story.next_dream(GameState.progression.cleared_levels, GameState.progression.story_seen, GameState.settlement.settlers))


## The Night of Ash on arriving somewhere (PIX-152): on the road, the
## scavenger feeding at the gate (and the night's first words); through the
## gate, the village is the next step.
func arrive(next: MapData) -> void:
	match GameState.progression.prologue:
		Prologue.SCAVENGER:
			if next.id == "overworld":
				var at: Dictionary = Prologue.data()["scavenger"]
				var foes: Foes = world.foes
				var scavenger := foes.spawn_enemy(at["monsterId"], Vector2i(at["x"], at["y"]), "forest", "", false, true)
				scavenger.set_meta("prologue", true)
				# It keeps to its meal until the hero walks up or strikes:
				# the night's first fight is the hero's to start.
				scavenger.feeding = true
				world.messages.flash.call_deferred(String(Prologue.data()["arrival"]))
		Prologue.GATE:
			if next.id == "town":
				GameState.questing.prologue_reached_town()
				prologue_wave.call_deferred()
		Prologue.HOUNDS, Prologue.EMBERS:
			if next.id == "town":
				prologue_wave.call_deferred()


## The night's foes for this beat (PIX-197): the ash hounds inside the gate,
## the embers on the square - below their kind's level, one told lunge
## among the hounds for the roll.
func prologue_wave() -> void:
	var wave := Prologue.wave(GameState.progression.prologue)
	if wave.is_empty() or world.map.id != "town":
		return
	var foes: Foes = world.foes
	var kind := Bestiary.monster(wave["monsterId"])
	for at: Array in wave["cells"]:
		var cell := Vector2i(int(at[0]), int(at[1]))
		var foe := foes.spawn_enemy(wave["monsterId"], cell, "", "", bool(wave.get("elite", false)), false, cell, int(wave["level"]) - int(kind["level"]))
		foe.fighter["name"] = wave["name"]
		foe.set_meta("prologue_wave", true)
		world.fx.appear(foe)


## Dawn after the Night of Ash (PIX-197): played on the town itself - the
## fires going out, the survivors on the square, the letter read, Fafnyr's
## shadow - and then the day.
func play_dawn() -> void:
	var dawn := preload("res://scripts/dawn_screen.gd").new()
	dawn.world = world
	dawn.on_done = func() -> void:
		GameState.questing.finish_prologue()
		world.map = world.load_map("town")
		# The day begins on the square, below the hall, whether the dawn
		# was watched or skipped.
		world.enter_map(world.map, Town.square() + Vector2i(0, 2))
	world.add_child(dawn)


## The ending (PIX-150): home to the square, the camera touring each age's
## landmark the hero built, then the square - and then the story's ending
## and credits. How Morvax ended (PIX-157) sets the evening: a festival
## with confetti for the one destroyed, five lanterns for the five who
## climbed for the one laid to rest.
func play_ending(choice := "destroy") -> void:
	var scene_id := Story.ending_scene(choice)
	GameState.mark_seen(scene_id)
	GameState.reveals.clear()
	world.map = world.load_map("town")
	# Below the fountain, facing the hall.
	var square := Town.square() + Vector2i(0, 3)
	world.enter_map(world.map, square)
	if choice == "rest":
		_lanterns()
	else:
		festival()
	Sound.play_track("victory")
	var stops: Array[Dictionary] = []
	var done := Town.done_projects(GameState.settlement)
	for entry: Dictionary in Town.ages():
		var built: Array = entry["projects"].filter(func(project_entry: Dictionary) -> bool: return project_entry["id"] in done)
		if built.is_empty():
			continue
		var landmark: Dictionary = built[-1]
		stops.append({
			"at": MapView.center(Town.project_center(landmark["id"])),
			"line": "%s - %s" % [landmark["name"], String(landmark["blurb"]).to_lower()],
		})
	var town_name := String(Town.tier(GameState.town_tier())["name"]).to_lower()
	stops.append({
		"at": MapView.center(square),
		"line": (Text.t("Five lanterns on the square, one for each of the five who climbed. Tonight the %s remembers them - and %s.")
			if choice == "rest" else Text.t("Pixelheim, a %s raised from the ashes. Tonight it celebrates %s.")) % [town_name, GameState.hero.hero_name],
	})
	var tour := preload("res://scripts/reveal_screen.gd").new()
	tour.world = world
	tour.stops = stops
	tour.on_done = func() -> void:
		var ending := Cutscene.new()
		ending.scene_id = scene_id
		world.add_child(ending)
	world.add_child(tour)


## Five lanterns in a row on the square (PIX-157), for Maren, Oskar,
## Liane, Tam and Morvax: Shade's flame on a post, or a warm square.
func _lanterns() -> void:
	var spots := Town.lanterns()
	for i in spots.size():
		var lantern := Node2D.new()
		lantern.position = MapView.center(spots[i])
		lantern.add_to_group("decor")
		var post := ColorRect.new()
		post.color = Color("4a3426")
		post.size = Vector2(2, 9)
		post.position = Vector2(-1, -7)
		lantern.add_child(post)
		var frames := ItemIcons.effect("flame", 10.0)
		if frames != null:
			var flame := AnimatedSprite2D.new()
			flame.sprite_frames = frames
			flame.scale = Vector2.ONE * 0.5
			flame.position = Vector2(0, -11)
			flame.frame = i
			flame.play()
			lantern.add_child(flame)
		else:
			var glow := ColorRect.new()
			glow.color = Color(1.0, 0.75, 0.35)
			glow.size = Vector2(4, 4)
			glow.position = Vector2(-2, -12)
			lantern.add_child(glow)
		world.actors.add_child(lantern)


## The festival's colours, and a building's as it stands (PIX-264).
const CONFETTI: Array[Color] = [Color("f2c14e"), Color("d8433f"), Color("4f7cff"), Color("5cbf4a")]
## A building's stop on the tour looks a little below its middle (PIX-264),
## so it stands above its name and what it brings rather than behind them.
const BUILDING_FRAMING := Vector2(0, 24)


## Confetti over the square: the town's festival, until the hero leaves.
func festival() -> void:
	if GameState.settings.reduce_motion:
		return
	for color: Color in CONFETTI:
		var confetti := CPUParticles2D.new()
		confetti.position = MapView.center(Town.square() + Vector2i(0, -4))
		confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		confetti.emission_rect_extents = Vector2(14 * MapView.TILE, MapView.TILE)
		confetti.amount = 18
		confetti.lifetime = 4.0
		confetti.direction = Vector2.DOWN
		confetti.spread = 25.0
		confetti.gravity = Vector2(0, 14)
		confetti.initial_velocity_min = 4.0
		confetti.initial_velocity_max = 10.0
		confetti.scale_amount_min = 1.0
		confetti.scale_amount_max = 2.0
		confetti.color = color
		confetti.z_index = 7
		confetti.add_to_group("decor")
		world.add_child(confetti)


## Back from the board with something built: the town redraws around the
## hero, then shows it.
func after_board() -> void:
	if GameState.reveals.is_empty() or world.map.id != "town":
		return
	world.map = world.load_map("town")
	world.enter_map(world.map, world.player_cell)


## The town risen (PIX-147): what was built since the hero last saw the town,
## the age it reached, a homecoming - the camera tours them, then hands back.
## A project's stop raises it out of its ruin (PIX-264) and says what it
## brings; an age's names who moved in with it.
func play_reveals() -> void:
	if GameState.reveals.is_empty() or world.map.id != "town" or not world.is_inside_tree():
		return
	var stops: Array[Dictionary] = []
	for entry: String in GameState.reveals:
		var key := entry.get_slice(":", 1)
		match entry.get_slice(":", 0):
			"project":
				stops.append({
					"at": MapView.center(Town.project_center(key)) + BUILDING_FRAMING,
					"line": Text.t("%s: built.") % Town.project(key)["name"],
					"detail": "\n".join(Town.brings(key)), "project": key,
				})
			"age":
				var newcomers := Npcs.newcomers(int(key))
				stops.append({
					"at": MapView.center(Town.square()),
					"line": Text.t("Pixelheim is a %s now.") % String(Town.tier(int(key))["name"]).to_lower(),
					"detail": Text.t("New in town: %s.") % ", ".join(newcomers) if not newcomers.is_empty() else "",
					"sound": "evolve", "dust": true,
				})
				if GameState.holdings.festival_on():
					stops.append({
						"at": MapView.center(Vector2i(int(Town.festival("barker")["x"]), int(Town.festival("barker")["y"]))),
						"line": Text.t("And today it celebrates: stalls on the square, and a ring toss with a prize for the best throw."),
					})
			"home":
				stops.append({"at": MapView.center(Town.square()), "line": Town.homecoming(int(key))})
			"hunt":
				stops.append({"at": MapView.center(Town.bounty_board() + Vector2i(0, 3)), "line": Hunts.named(key)["homecoming"]})
			"settler":
				# Someone the story brought home, at their door (PIX-255: Wenna
				# at Sela's inn, and Maren in the doorway).
				var home: Dictionary = Town.recruit(key).get("homecoming", {})
				if not home.is_empty():
					stops.append({
						"at": MapView.center(Vector2i(int(home["x"]), int(home["y"]))) + BUILDING_FRAMING,
						"line": String(home["line"]), "detail": String(home.get("detail", "")),
					})
			"opens":
				# The next age stands open (PIX-253 step 5: the Village, as
				# Old Pell comes home): the board says what it asks.
				var opens: Dictionary = Town.age(int(key)).get("opens", {})
				if not opens.is_empty():
					stops.append({
						"at": MapView.center(Town.project_board()), "line": String(opens["line"]),
						"detail": String(opens.get("detail", "")),
					})
			"deep":
				# A Deep Hunt milestone (PIX-216): the town has heard.
				stops.append({"at": MapView.center(Town.square()), "line": Text.t(Dungeons.milestone(int(key))["homecoming"])})
	GameState.reveals.clear()
	var flags := HarnessFlags.given()
	var staged := flags.has("reveal") or flags.has("rebuilt") or flags.has("--rise") or flags.has("lookbook")
	if stops.is_empty() or (world.harness and not staged):
		return
	var tour := preload("res://scripts/reveal_screen.gd").new()
	tour.world = world
	tour.stops = stops
	world.add_child(tour)


## The escort's wagon on its map, unless it's there already or was lost a
## moment ago.
func tend_escort() -> void:
	var due := GameState.questing.escort_due()
	if due.is_empty() or world.map.id != due["def"]["mapId"]:
		return
	if escort != null and is_instance_valid(escort):
		return
	if GameClock.seconds() - escort_lost_at < 4.0:
		return
	var quest_id: String = due["quest"]["id"]
	escort = preload("res://scripts/escort.gd").new()
	escort.world = world
	escort.def = due["def"]
	escort.add_to_group("decor")
	escort.arrived.connect(func() -> void:
		GameState.questing.escort_arrived(quest_id)
		world.messages.flash(due["def"]["arrived"]))
	escort.lost.connect(func() -> void:
		world.messages.flash(due["def"]["lost"])
		escort_lost_at = GameClock.seconds()
		var gone := escort
		gone.create_tween().tween_property(gone, "modulate:a", 0.0, 1.0).finished.connect(gone.queue_free))
	world.actors.add_child(escort)


## The clocks of the quests against time tick, and the one running shows.
func run_clocks(delta: float) -> void:
	var ticked := GameState.questing.tick_runs(delta)
	if ticked["message"] != "":
		world.messages.flash(ticked["message"])
	for chest_id: String in ticked["rearmed"]:
		if world.view.chest_sprites.has(chest_id):
			for chest: Dictionary in Interactables._data()["chests"]:
				if chest["id"] == chest_id:
					world.view.chest_sprites[chest_id].texture = MapView.treasure_texture(chest, false)
	var running := GameState.questing.timed_run()
	if running.is_empty() or world.hud.root == null:
		if run_clock != null:
			run_clock.queue_free()
			run_clock = null
		return
	if run_clock == null:
		run_clock = PanelContainer.new()
		run_clock.add_theme_stylebox_override("panel", UiStyle.plate(12))
		run_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		run_clock.add_child(UiStyle.strong("", 16, UiStyle.CREAM))
		world.hud.root.add_child(run_clock)
	var left := ceili(float(running["left"]))
	var shown: Label = run_clock.get_child(0)
	shown.text = Text.t("%s  %d:%02d") % [running["quest"]["timed"]["clock"], left / 60, left % 60]
	shown.add_theme_color_override("font_color", Color("ff5a4a") if left <= 30 else UiStyle.CREAM)
	run_clock.reset_size()
	# Under the clock of the day (PIX-246).
	run_clock.position = Vector2(1280 - 24 - run_clock.size.x, 56)
