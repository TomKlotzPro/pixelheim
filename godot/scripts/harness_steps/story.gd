extends RefCounted
## areas: all
## The harness's story steps (PIX-357): story scenes, the Night of Bells,
## quests, the Post, conversations, the town's tours, the ending.
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


## `--story <id>`: a story scene from assets/data/story.json, over the world.
func step_story() -> void:
	world.stage.play_story(flags.value("--story"))
	# `credits` (PIX-253 step 10): the scene moved on to its credits'
	# roll, before it begins to play.
	if flags.has("credits"):
		for node in world.get_children():
			if node is Cutscene:
				node.from_kind = "credits"
	await h.get_tree().create_timer(0.3).timeout


## `--bells N` (PIX-253 step 9): the Night of Bells, begun as the hero
## came home, moved on to beat N.
func step_bells() -> void:
	# Nothing bites the throwaway hero tonight unless `hurt` says so.
	world.player.invulnerable = not flags.has("hurt")
	world.night.jump_to(int(flags.value("--bells")))
	# What the beats skipped said isn't the shot's to show.
	world.messages.clear()
	await h.get_tree().create_timer(0.3).timeout


func step_light() -> void:
	world.night.light_all()
	await h.get_tree().create_timer(0.3).timeout


func step_douse() -> void:
	world.night.douse_all()
	await h.get_tree().create_timer(0.3).timeout


func step_daybreak() -> void:
	# The dawn clock run out: Fafnyr stands down, and after a breath the
	# dawn's scene opens over the square.
	world.night.daybreak()
	await h.get_tree().create_timer(2.2).timeout


func step_quest() -> void:
	# A conversation with the elder closes: a new hero's first is her
	# tin, its letters and her quest taken (PIX-253).
	GameState.questing.finish_dialogue("elder")
	await h.get_tree().create_timer(0.3).timeout


func step_brew() -> void:
	# A First Brew (PIX-231): a potion brewed before Vex's quest is taken;
	# then a word with her takes it, and another hands it in. Where she
	# stands now (PIX-283): in her room, brewed at its cauldron, or on the
	# square while her house is rubble, brewed at her stall's counter. The
	# words are had as a hero has them, facing her, so a Vex who isn't
	# there gives nothing.
	GameState.pack.add_item("forest_herb")
	GameState.pack.add_item("marsh_reed")
	var vex: Node = h._villager("alchemist_vex")
	if vex != null and world.map.id == "town":
		GameState.trade.stall_shop = Economy.station_shop("alchemy")
	GameState.trade.craft("brew_potion_hp")
	GameState.trade.stall_shop = ""
	if vex != null:
		await _word_with(vex)
		await _word_with(vex)
	await h.get_tree().create_timer(0.3).timeout


func step_post() -> void:
	await _post(flags.value("--post"))


func step_ready() -> void:
	# A quest accepted and its goal met (PIX-192): `--ready fenwick_locket`.
	var quest := Quests.by_id(flags.value("--ready"))
	var objective: Dictionary = quest["objective"]
	GameState.progression.quests[quest["id"]] = {"progress": int(objective["count"]), "done": false}
	# What's carried, in the pack: goods for a delivery, one of Maren's
	# letters for its recipient (PIX-253).
	if objective["kind"] in ["deliver", "deliverTo"]:
		GameState.pack.add_item(objective["itemId"], int(objective["count"]))


func step_talk_to() -> void:
	# A conversation with one villager by id, wherever they stand.
	world.interaction.talk(Npcs.by_id(flags.value("--talk-to"), GameState.settlement.settlers))
	await h.get_tree().create_timer(0.3).timeout
	await h._keys(flags)


func step_talk() -> void:
	await _below_first_villager()


## With `talk` too, that step has stood there.
func step_near() -> void:
	if not flags.has("talk"):
		await _below_first_villager()


func step_hunted() -> void:
	# `--hunted greymaw,cinderjaw`: named monsters already slain (PIX-156;
	# the world slays them before it draws the first map, PIX-254).
	for named_id: String in flags.list("--hunted"):
		if named_id not in GameState.progression.hunted:
			GameState.progression.hunted.append(named_id)


func step_reveal() -> void:
	# The town risen (PIX-147): pair with `--map town --town-tier 2`; the
	# lamps' stop, then the age's. With `--hunted`, the first one's
	# homecoming instead (PIX-156).
	if flags.has("--hunted"):
		var first := GameState.progression.hunted[0]
		GameState.reveals.assign(["hunt:" + first])
		# A keepsake that brings someone home (PIX-255: the Tidecaller,
		# Wenna) tours to their door instead.
		if not Hunts.named(first).has("homecoming"):
			GameState.reveals.assign(Npcs.recruits().filter(func(recruit: Dictionary) -> bool:
				return recruit.get("comesHome", {}).get("named", "") == first).map(func(recruit: Dictionary) -> String: return "settler:" + String(recruit["id"])))
	else:
		GameState.reveals.assign(["project:street_lamps", "age:2"])
	world.stage.play_reveals()
	await h.get_tree().create_timer(1.4).timeout


func step_rebuilt() -> void:
	# Back from the board with something built, the real way (PIX-238):
	# the town redrawn and faded in from the dark, then its tour. Pair
	# with `--map town --town-tier 2 fades`.
	GameState.reveals.assign(["project:street_lamps", "age:2"])
	world.stage.after_board()
	await h.get_tree().create_timer(1.4).timeout


func step_rise() -> void:
	# `--rise odos_store`: back from the board with that project built
	# (PIX-264), whatever age the run's town stands at: the town redrawn,
	# then its stop on the tour, the building rising out of its ruin.
	# The run waits for the camera to get there, so `--wait` counts from
	# the rise (the fight step's 0.2 s comes first).
	var project_id := flags.value("--rise")
	if Town.project(project_id).is_empty():
		push_error("--rise: no village project %s (assets/data/town.json)" % project_id)
	else:
		var done := Town.done_projects(GameState.settlement)
		if project_id not in done:
			done.append(project_id)
		GameState.settlement.projects.assign(done)
		GameState.reveals.assign(["project:" + project_id])
		world.stage.after_board()
		for frame in 300:
			var rise: RebuildRise = h._rise()
			if rise != null and rise.phase != "ruin":
				break
			await h.get_tree().process_frame


func step_ending() -> void:
	# The ending (PIX-150; PIX-253 step 10, Morvax's choice): "Come
	# home.", to the festival and the tour's first stop, his answer;
	# `stay` the lanterns ending, his going back up to the three.
	world.stage.play_ending(Homecoming.STAY if flags.has("stay") else Homecoming.HOME)
	await h.get_tree().create_timer(1.4).timeout


func step_seen() -> void:
	# `--seen maren_confession`: stories already told this hero.
	for story_id: String in flags.list("--seen"):
		GameState.mark_seen(story_id)


func step_choice() -> void:
	# Morvax's choice (PIX-253 step 10; the old throne's, PIX-157):
	# the courier's last word, asked outright.
	var choice := preload("res://scripts/throne_screen.gd").new()
	choice.on_choice = world.stage.play_ending
	world.add_child(choice)
	await h.get_tree().create_timer(0.3).timeout


## `chapter` (PIX-253 step 2): chapter cards turned on now that the story
## stands where the run set it, and the one it's at waited for as the
## world shows it - once it has been free a moment - with its entrance;
## the report shows chapter= and rose=.
func step_chapter() -> void:
	world.stage.cards = true
	var waited := 0.0
	while waited < 8.0 and not world.get_children().any(func(node: Node) -> bool: return node.has_method("rise_left")):
		await h.get_tree().create_timer(0.1).timeout
		waited += 0.1
	await h.get_tree().create_timer(1.0).timeout


## `--dawn-beat N`: the Night of Ash's dawn (PIX-197) jumped to beat N.
func step_dawn_beat() -> void:
	for node in world.get_children():
		if node.has_method("jump_to"):
			node.jump_to(int(flags.value("--dawn-beat")))
	await h.get_tree().create_timer(0.6).timeout


## Stand below `villager`, facing them.
func _face(villager: Node) -> void:
	world.player.position = MapView.center(villager.cell + Vector2i.DOWN)
	world.camera_rig.cut()
	world.player_cell = villager.cell + Vector2i.DOWN
	world.player.face(Vector2.UP)


## A word with `villager`, as a hero has one (PIX-283): below them, facing
## them, E, and E again till the conversation closes.
func _word_with(villager: Node) -> void:
	_face(villager)
	world.interaction.interact()
	await h.get_tree().create_timer(0.3).timeout
	for press in 12:
		if not world.get_children().any(func(node: Node) -> bool: return node.has_method("_advance")):
			return
		await h._tap(KEY_E)


## The Pixelheim Post's step (PIX-320; world.gd opened the Post before the
## first map was drawn): `open` does nothing more (PIX-322: the run walks
## up to a waystation's box itself); `box` faces the post box on the square and presses
## E; `read` takes the day's post and hands the first piece over by the
## rules (the journal's Post tab then has both kinds to show); `book` takes
## it and delivers it all, replies too, stamping the courier's book
## (PIX-321); a piece's id
## delivers every piece before it in its thread by the rules, puts it in
## the satchel and has a word with its addressee where they stand on this
## map (`--keys` close it, and it's handed over).
func _post(step: String) -> void:
	var post := GameState.post
	match step:
		"open":
			pass
		"box":
			var cell := Post.box_cell() + Vector2i.DOWN
			world.player.position = MapView.center(cell)
			world.camera_rig.cut()
			world.player_cell = cell
			world.player.face(Vector2.UP)
			world.interaction.interact()
		"read":
			Post.take(post, GameState.posting.in_box(), GameState.posting.today())
			if not post.bag.is_empty():
				Post.hand_over(post, post.bag[0])
		"book":
			# PIX-321: the day's post taken and every piece handed over as a
			# word with its addressee would (Posting.deliver: tips, things
			# kept, the courier's book stamped), each reply carried back too.
			Post.take(post, GameState.posting.in_box(), GameState.posting.today())
			var handed := true
			while handed:
				handed = false
				for id: String in post.bag.duplicate():
					if GameState.posting.deliver(Post.addressee(Post.piece(id))) != "":
						handed = true
		_:
			var entry := Post.piece(step)
			if entry.is_empty():
				push_error("--post: no piece of the post is called %s (assets/data/post.json)" % step)
				return
			for before: Dictionary in Post.thread(Post.thread_of(step))["pieces"]:
				if before["id"] == step:
					break
				if String(before["id"]) not in post.bag:
					post.bag.append(String(before["id"]))
				Post.hand_over(post, String(before["id"]))
			if step not in post.bag:
				post.bag.append(step)
			var villager: Node = h._villager(Post.addressee(entry))
			if villager != null:
				_face(villager)
				world.interaction.interact()
	world.view.show_post_box()
	await h.get_tree().create_timer(0.3).timeout


## Stand below the map's first villager facing up; `talk` also presses E.
func _below_first_villager() -> void:
	var villager: Node = h.get_tree().get_first_node_in_group("npcs")
	world.player.position = MapView.center(villager.cell + Vector2i.DOWN)
	world.camera_rig.cut()
	world.player_cell = villager.cell + Vector2i.DOWN
	world.player.face(Vector2.UP)
	if flags.has("talk"):
		world.interaction.interact()
	await h.get_tree().create_timer(0.3).timeout
	# The way a player leaves it (the report lists what stays open).
	await h._keys(flags)
