extends Node
## areas: none
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, the Kings' Vault, a fight, the overworld at night, the
## village seen from its road (PIX-248), the ways between maps (PIX-269),
## the map screen (PIX-266), the rooms behind the Reach's doors with the
## stairs down in their floors (PIX-256) and the card naming a place come
## to - each saved
## as a picture, and all of them on one contact sheet, so a change to how the
## game looks is judged before and after, by eye. With `perf`, each shot also
## reports what its frames cost (PerfProbe); with `film`, each is filmed for
## a moment too, frame by frame, for what a still can't show (the wind, the
## water). With `--looks a,b`, the desktop renderer shoots each scene in each
## of the app's looks (PIX-227, DesktopLook.LOOKS), each look in its own
## folder with its own sheet. A shot that is a moment rather than a place (a
## clip: `rise`, PIX-264) is staged afresh for each look and kept as a strip
## of frames through it, <name>_strip.png; its last frame stands in the
## sheet. Each folder also gets shots.txt, the shots' names in the sheet's
## order, for tools/lookbook_compare.py. Run by tools/lookbook.sh.

## Where in the day a shot stands (DayNight's wheel, 0..1), by its `time`.
const TIMES := {"day": 0.2, "dusk": 0.53, "night": 0.75}
## The sheet's areas, in its order (PIX-273): the village and its rooms,
## the Reach around it, the regions beyond, the ways between them,
## underground, a fight, and the game's pages. A shot names its area, and
## the sheet groups them so, in the order shots() gives within an area.
const AREAS := ["town", "rooms", "reach", "regions", "ways", "dungeon", "combat", "screens"]
## Each shot, a line each (PIX-356: a shot a branch adds merges by union,
## where a table in this script made catch-up merges conflict), by
## its name (its picture's file, and `--only`'s word: never a
## number, which every branch adding a shot took the same next one of): its
## area; a map and where on it (Upper Street, a pack's home, a cell, or the
## map's arrival); the hour, or the first shower by day
## (`rain`); and a foe to face, for the fight, struck on a beat while it's
## filmed (`strike`), the third blow felling it, or caught as it notices the
## hero (`notice`, PIX-289). A `letter` of Maren's is carried for that shot
## alone (its recipient's mark), and the town stands at age `tier` for it
## alone (PIX-307; every age built otherwise), the Night of Ash burns for
## it alone with `ash` (PIX-327), and `post` opens the
## Pixelheim Post for it (PIX-320: its `box` faced, or its `tab` read;
## PIX-321: some weeks of it delivered, the courier's `book` or the
## Post page's newest `letters` read).
## Only a shot with `card` keeps
## the title card naming the place it enters (PIX-269). A new shot goes
## with its area's.
const SHOTS_FILE := "res://scripts/lookbook_shots.jsonl"
## SHOTS_FILE's shots by name, read once (`shots()`).
static var _shots := {}
## The post the book's shots deliver (PIX-321), in order, each thread's
## pieces in turn: from Pixelheim to Saltmere, the Reach's road, the
## Mirefen, Blackiron and Greyhold.
const POST_ROUND: Array[String] = [
	"club_ola", "club_ola_reply", "stew_salt", "rope_ask", "rope_ask_reply", "interest_mayor",
	"reagents_salt", "reagents_salt_reply", "shoes_ask", "shoes_ask_reply", "club_garrick", "smile_ore",
	"smile_ore_reply", "reagents_reeds", "reagents_reeds_reply", "club_mabel", "club_mabel_reply",
	"else_weather", "else_weather_reply", "else_joke",
]
## Filming the walk: slowed to a quarter, a picture every WALK_STEP of the
## game's time (thirty a second: two or three of each frame of the walk),
## cropped round the hero this far (art px) each way; the legs of the clip
## as [heading, pictures].
const WALK_SLOW := 0.25
const WALK_STEP := 1.0 / 30.0
const WALK_CROP := Vector2(22, 26)
const WALK_LEGS := [[Vector2.ZERO, 3], [Vector2.RIGHT, 20], [Vector2.LEFT, 12], [Vector2.ZERO, 9], [Vector2.UP, 12], [Vector2.ZERO, 9]]
## The turning walk's legs (PIX-293), keys as a player holds them: a
## diagonal is two keys at once.
const TURN_LEGS := [
	[Vector2.ZERO, 3], [Vector2.DOWN, 12], [Vector2(0.7071068, 0.7071068), 6], [Vector2.RIGHT, 12], [Vector2.ZERO, 9],
	[Vector2.UP, 12], [Vector2(-0.7071068, -0.7071068), 6], [Vector2.LEFT, 12], [Vector2.ZERO, 9],
	[Vector2.DOWN, 12], [Vector2.RIGHT, 12], [Vector2(0.7071068, -0.7071068), 12], [Vector2.UP, 12], [Vector2.ZERO, 9],
]
## Each filmed walk's legs, by the shot's `legs`.
const LEGS := {"walk": WALK_LEGS, "turn": TURN_LEGS}
## The strip of crops: this many across.
const STRIP_COLUMNS := 11
## A clip's frames, in seconds after the rise begins: the ruin, giving way
## in dust as the first courses drop, the roof going up, and standing with
## its confetti, its name and what it brings.
const CLIP_MARKS := [0.1, 0.55, 0.95, 2.1]
## Upper Street: the shop's and the inn's fronts, the street lamps, the hall.
const STREET := Vector2i(40, 13)
## The contact sheet: three across, each shot at half size.
const SHEET_COLUMNS := 3
const SETTLE_SECONDS := 1.2
## A stair's shot (`down`, PIX-256): this long facing it before it asks.
const ASK_AFTER := 0.5
## A foe noticing (`notice`, PIX-289): the picture this long after it does,
## its danger mark up and its hop under way.
const NOTICE_HOLD := 0.2
## Filming (`film`): this many frames, this far apart, into
## <out>/motion/<shot>/NN.png.
const MOTION_FRAMES := 24
const MOTION_STEP := 0.1
## The world's clock at each shot, so the clouds and the wind stand the same
## way every time.
const CLOCK := 40.0
## Frames drawn after a look is put on, before its shot: the canvas is remade
## and the glow's levels filled.
const LOOK_FRAMES := 4

var world: Node
var out_dir := "res://lookbook"
var with_perf := false
var with_motion := false
## Only the shots of these names (none: all), to look at a few quickly: a
## before and after of a handful (PIX-314: the bosses).
var only: PackedStringArray = []
## The shot's foe, to strike while filming.
var _foe: Node
## The bosses' lineup (`bosses`, PIX-314): who stands in it, and how far
## apart, in world pixels: BOSS_ROW across, the hero in the first row's
## middle, the second row below it.
var _lined_up: Array[Node] = []
## The slots a shot with `slots` stood in for, given back after it.
var _slots_kept: SaveSlots
## The story ledger's entries a shot added for itself alone (`open`).
var _opened: Array[String] = []
const BOSS_STEP := Vector2(60, 76)
const BOSS_ROW := 9
## Filming a strike: the frames the hero swings on (the second a crit, the
## last one felling it), and what each blow takes.
const STRIKES := [2, 8, 14]
const STAGED_BLOW := 12
## The looks to shoot each scene in (`--looks`); none: the look worn.
var looks: PackedStringArray = []


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Pictures to look at, not the game's: Godot leaves the folder alone.
	FileAccess.open("%s/.gdignore" % out_dir, FileAccess.WRITE)
	# The same picture every time: no first-time hints over the scene, and a
	# hero no foe can fell while a shot is taken or its frames are timed.
	GameState.settings.hints = false
	world.player.invulnerable = true
	# The town at its fullest: every age built, its lamps and roofs up.
	GameState.settlement.town_tier = Town.MAX_TIER
	GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	# Each look's folder ("" is the look worn, straight into out_dir) and its
	# shots so far.
	var folders := {}
	var images := {}
	for look in (looks if not looks.is_empty() else PackedStringArray([""])):
		folders[look] = out_dir if look == "" else "%s/%s" % [out_dir, look]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folders[look]))
		var shots: Array[Image] = []
		images[look] = shots
	# Developer output, not the player's: no words for the translators.
	print("%s %s=%s" % ["LOOK", "look", DesktopLook.look])
	for wanted in only:
		if not shots().has(wanted):
			push_error("lookbook: no shot is called %s (%s)" % [wanted, ", ".join(ordered())])
			return
	var shot_names: PackedStringArray = []
	for shot_name in ordered():
		if not only.is_empty() and not only.has(shot_name):
			continue
		shot_names.append(shot_name)
		var shot: Dictionary = shots()[shot_name].duplicate()
		shot["name"] = shot_name
		if shot.has("rise"):
			await _clip(shot, folders, images)
			continue
		_stage(shot)
		if shot.get("down", false):
			await get_tree().create_timer(ASK_AFTER).timeout
			world.interaction.ask_down(world.player_cell + Vector2i.UP)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		if shot.get("notice", false) and is_instance_valid(_foe):
			_foe.notice()
			await get_tree().create_timer(NOTICE_HOLD).timeout
		await drawn()
		for look: String in folders:
			if look != "":
				world.lights.wear(look)
				for frame in LOOK_FRAMES:
					await drawn()
			var image: Image = await DesktopLook.snapshot(self)
			image.save_png("%s/%s.png" % [folders[look], shot["name"]])
			images[look].append(image)
		var line := "%s %s" % ["LOOK", shot["name"]]
		if with_perf:
			line += "  " + await PerfProbe.sample(self, 180)
		print(line)
		if with_motion and shot.get("walk", false):
			await _film_walk(shot["name"], LEGS[shot.get("legs", "walk")])
		elif with_motion:
			await _film(shot["name"], shot.get("strike", false))
		_unstage(shot)
		# A screen a shot opened goes, so the next finds the world its own:
		# gone from the tree before the next is staged, or the HUD it hid
		# came back over the next shot's journal or map (PIX-320).
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
		await get_tree().process_frame
	for look: String in folders:
		sheet(images[look]).save_png("%s/sheet.png" % folders[look])
		FileAccess.open("%s/shots.txt" % folders[look], FileAccess.WRITE).store_string("\n".join(shot_names) + "\n")
		print("%s %s/%s" % ["LOOK", ProjectSettings.globalize_path(folders[look]), "sheet.png"])


## Every shot by its name, in SHOTS_FILE's order: its line as it's staged,
## `cell` a Vector2i, `time` the wheel's, `drops` by Vector2i.
static func shots() -> Dictionary:
	if _shots.is_empty():
		# The core's shots, then every feature's (PIX-361).
		var lines := FileAccess.get_file_as_string(SHOTS_FILE).split("\n")
		for feature in Features.all():
			var own := feature.folder.path_join("lookbook_shots.jsonl")
			if FileAccess.file_exists(own):
				lines.append_array(FileAccess.get_file_as_string(own).split("\n"))
		for line in lines:
			if line.strip_edges() == "" or line.begins_with("#"):
				continue
			var shot: Variant = SaveCodec.parse_json(line)
			if not shot is Dictionary or not shot.has("shot"):
				push_error("a shot is a JSON object with its name in `shot`: %s" % line)
				continue
			if shot.has("cell"):
				shot["cell"] = Vector2i(shot["cell"][0], shot["cell"][1])
			if shot.has("time"):
				shot["time"] = TIMES[shot["time"]]
			if shot.has("drops"):
				var drops := {}
				for at: String in shot["drops"]:
					drops[Vector2i(int(at.get_slice(",", 0)), int(at.get_slice(",", 1)))] = shot["drops"][at]
				shot["drops"] = drops
			_shots[shot["shot"]] = shot
			shot.erase("shot")
	return _shots


## Every shot's name in the sheet's order: by area, as AREAS lists them, and
## in shots()' order within an area.
static func ordered() -> PackedStringArray:
	var out: PackedStringArray = []
	for area: String in AREAS:
		for shot_name: String in shots():
			if shots()[shot_name]["area"] == area:
				out.append(shot_name)
	return out


## Puts the hero where the shot stands, at its hour, with its foe - the last
## shot's words cleared away.
func _stage(shot: Dictionary) -> void:
	world.messages.clear()
	world.hud.forget_places()
	if shot.get("open", false):
		# The story's ways open, for this shot alone (_unstage): Maren
		# heard out opens the mountain's gate (Relics.gate_open), the
		# dragon freed the Vault's door (Vault.door_open).
		for story_id: String in [Letters.confession_id(), Bells.collar_id()]:
			if story_id not in GameState.progression.story_seen:
				GameState.progression.story_seen.append(story_id)
				_opened.append(story_id)
	if shot.has("tier"):
		# The town at an earlier age, for this shot alone (_unstage).
		GameState.settlement.town_tier = int(shot["tier"])
		GameState.settlement.projects.assign(Town.projects_through(int(shot["tier"])))
	if shot.get("ash", false):
		# The Night of Ash at its fires, none put out yet (_unstage).
		GameState.progression.prologue = Prologue.FIRES
		GameState.progression.prologue_doused.clear()
	GameState.world.steps = shower_by_day() if shot.get("rain", false) else float(shot["time"]) * DayNight.DAY_CYCLE_STEPS
	if shot.has("post"):
		_open_post()
	if shot.get("routes", false):
		_open_routes()
	world.map = world.load_map(shot["map"])
	var at: Vector2i = nearest_walkable(world.map, shot["cell"]) if shot.has("cell") else _cell(world.map, String(shot.get("at", "")))
	world.enter_map(world.map, at)
	# The card naming the place stands over its own shot only.
	if not shot.get("card", false):
		world.hud.forget_places()
	world.folk.keep_hours(true)
	world.lights.time = CLOCK
	if shot.has("foe"):
		var foe: Node = world.foes.spawn_enemy(shot["foe"], world.player_cell + Vector2i(2, 0), "", "", true, false)
		world.player.face(Vector2.RIGHT)
		# One caught as it notices does so just before its picture (run).
		if not shot.get("notice", false):
			foe.notice()
		_foe = foe
	if shot.has("named"):
		var lair := Hunts.lair(Hunts.named(shot["named"]))
		_foe = _named_at(String(shot["named"]), MapView.center(lair))
		world.player.face(Vector2.RIGHT)
	if shot.get("bosses", false):
		_line_up_bosses()
	if shot.get("fafnyr", false):
		_foe = _fafnyr_at(MapView.center(Bells.landing()))
		world.player.face(Vector2.RIGHT)
	if shot.has("zoom"):
		world.camera_rig.camera.zoom = Vector2.ONE * float(shot["zoom"])
	if shot.has("letter"):
		# A letter of Maren's carried, for this shot alone (_unstage).
		GameState.progression.quests[shot["letter"]] = {"progress": 0, "done": false}
		GameState.pack.add_item(shot["letter"])
	if shot.get("down", false):
		# At the top of a room's stair, facing it (PIX-256): the stairs ask
		# once the world has drawn the hero turned (run).
		world.player.face(Vector2.UP)
	for cell: Vector2i in shot.get("drops", {}):
		# Laid as the map lays a patch (PatchesLayer.pickup), gone with the visit.
		world.view.ground.add_child(PatchesLayer.pickup(ItemIcons.texture(shot["drops"][cell]), cell))
	if shot.get("post", "") == "box":
		world.player.face(Vector2.UP)
	if shot.get("post", "") == "tab":
		# The day's post taken, the first piece handed over (its reply in
		# the satchel), then the journal at its Post page.
		Post.take(GameState.post, GameState.posting.in_box(), GameState.posting.today())
		Post.hand_over(GameState.post, GameState.post.bag[0])
		var journal := preload("res://scripts/journal_screen.gd").new()
		journal.tab = "post"
		world.add_child(journal)
	if shot.get("post", "") in ["book", "letters"]:
		# Some weeks of post delivered across the Reach (PIX-321), each piece
		# stamped where its addressee lives, then the journal at the
		# courier's book or at the Post page's newest letters.
		for step in POST_ROUND.size():
			var id: String = POST_ROUND[step]
			if id not in GameState.post.bag:
				GameState.post.bag.append(id)
			Post.hand_over(GameState.post, id)
			var to := Npcs.by_id(Post.addressee(Post.piece(id)), [])
			Post.stamp(GameState.post, id, Post.place_of(String(to.get("mapId", ""))), floori(step / 3.0))
		var journal := preload("res://scripts/journal_screen.gd").new()
		journal.tab = "book" if shot["post"] == "book" else "post"
		world.add_child(journal)
	if shot.has("chart"):
		# The map over a hero who has walked it all, a waypoint chosen.
		Atlas.walk_all(GameState.world.discovered)
		world.open_screen("map")
		for node in world.get_children():
			if node.has_method("show_waypoint"):
				node.show_waypoint(shot["chart"])
	if shot.has("slots"):
		# The saves screen over a folder of fixture slots, for this shot alone.
		_slots_kept = GameState.slots
		GameState.slots = SaveSlots.new(shot["slots"], true)
		world.open_saves()


## What a shot set up for itself alone taken back, so the shots after it
## find the hero as they were: its letter, the town's age.
func _unstage(shot: Dictionary) -> void:
	for story_id: String in _opened:
		GameState.progression.story_seen.erase(story_id)
	_opened.clear()
	if shot.has("tier"):
		GameState.settlement.town_tier = Town.MAX_TIER
		GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	if shot.get("ash", false):
		GameState.progression.prologue = Prologue.DONE
	if shot.has("letter"):
		GameState.pack.remove_item(shot["letter"])
		GameState.progression.quests.erase(shot["letter"])
	if shot.has("post"):
		_close_post()
	if shot.get("routes", false):
		_close_routes()
	if shot.has("zoom"):
		world.camera_rig.camera.zoom = Vector2.ONE * CameraRig.ZOOM
	if shot.has("slots"):
		GameState.slots = _slots_kept
	for foe in _lined_up:
		if is_instance_valid(foe):
			foe.queue_free()
	_lined_up.clear()


## What the Post's shots changed (PIX-320), to put back: whether the tin
## was found, Maren's first letter's entry, and whether Saltmere was walked.
var _before_post := {}


## The Pixelheim Post open for a shot alone (PIX-320), as the harness's
## `--post` opens it: Maren's first letter in Wenna's hands and Saltmere
## walked, before the town is drawn (its box on the square).
func _open_post() -> void:
	var first: Dictionary = Letters.all()[0]
	var wenna := Npcs.by_id(String(first["objective"]["to"]), GameState.settlement.settlers)
	_before_post = {
		"tin": GameState.has_seen(Letters.scene_id()),
		"letter": GameState.progression.quests.get(first["id"], {}),
		"walked": GameState.world.discovered.has(String(wenna["mapId"])),
	}
	GameState.mark_seen(Letters.scene_id())
	GameState.progression.quests[first["id"]] = {"progress": 1, "done": true}
	Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(String(wenna["mapId"])), Vector2i(int(wenna["x"]), int(wenna["y"])))


## The Post as it was before its shot: shut, and nothing in it kept.
func _close_post() -> void:
	var first: Dictionary = Letters.all()[0]
	if not _before_post.get("tin", true):
		GameState.progression.story_seen.erase(Letters.scene_id())
	if (_before_post.get("letter", {}) as Dictionary).is_empty():
		GameState.progression.quests.erase(first["id"])
	else:
		GameState.progression.quests[first["id"]] = _before_post["letter"]
	if not _before_post.get("walked", true):
		GameState.world.discovered.erase(String(Npcs.by_id(String(first["objective"]["to"]), GameState.settlement.settlers)["mapId"]))
	GameState.post = PostState.new()


## Who the look book's roads are named after (PIX-322): each route's own
## writer, so the signposts read as a hero's would.
const ROUTE_WRITERS := {
	"saltmere": "bram", "blackiron": "dagny", "greyhold": "fenwick", "frostgate": "gunnar",
	"mirefen": "vex", "deepwood": "loras", "morvax_forge": "maren",
}


## Every one of the Post's roads carried as far as its waystation, each
## built, for a shot alone (PIX-322): its signposts up before the Reach is
## drawn.
func _open_routes() -> void:
	for place: String in Routes.places():
		var far := Routes.station_at(place) if not Routes.station(place).is_empty() else Routes.signs_at(place)
		Routes.tally(GameState.post, place, ROUTE_WRITERS.get(place, "bram"), far)
		var work := String(Routes.station(place).get("work", ""))
		if work != "" and work not in GameState.settlement.projects:
			GameState.settlement.projects.append(work)
	Routes.raise_signs(GameState.post)


## The roads as they were before their shot: nothing carried, no
## waystation standing.
func _close_routes() -> void:
	GameState.post.routes = {}
	GameState.post.signs = {}
	for place: String in Routes.places():
		GameState.settlement.projects.erase(String(Routes.station(place).get("work", "")))


## A named monster held still at `at` (PIX-314): the one in its lair on this
## map, or brought out of it, facing the camera, its level shown as the
## hero beside it would see it.
func _named_at(named_id: String, at: Vector2) -> Node:
	var foe: Node = null
	for mob in get_tree().get_nodes_in_group("mobs"):
		# Not one the last shot's map left going.
		if not mob.dying and not mob.is_queued_for_deletion() and mob.fighter.get("named", "") == named_id:
			foe = mob
	if foe == null:
		foe = world.foes.spawn_named(named_id, Vector2i((at / MapView.TILE).floor()))
	_hold(foe, at)
	return foe


## Still where it is put: no wandering, no noticing, no chase.
func _hold(foe: Node, at: Vector2) -> void:
	foe.position = at
	foe.home = at
	foe.reset_physics_interpolation()
	foe.set_physics_process(false)
	foe.level_tag.visible = true


## Every named monster, and Fafnyr as the Night of Bells sizes him, in rows
## beside the hero, held still facing the camera, their words hidden: how
## big each is drawn, side by side with the hero (PIX-314).
func _line_up_bosses() -> void:
	var origin: Vector2 = world.player.position - Vector2(BOSS_STEP.x * (BOSS_ROW / 2), 0)
	var slots: Array[Vector2] = []
	for slot in BOSS_ROW * 2:
		if slot != BOSS_ROW / 2:
			slots.append(origin + Vector2(BOSS_STEP.x * (slot % BOSS_ROW), BOSS_STEP.y * (slot / BOSS_ROW)))
	var named := Hunts.all()
	for i in named.size():
		var foe := _named_at(String(named[i]["id"]), slots[i])
		_quiet(foe)
		_lined_up.append(foe)
	# The last of the second row, and the room of the one after it.
	var fafnyr := _fafnyr_at((slots[named.size() + 1] + slots[named.size() + 2]) / 2.0)
	_quiet(fafnyr)


## Fafnyr as the Night of Bells brings him down, held still at `at`.
func _fafnyr_at(at: Vector2) -> Node:
	var fafnyr: Node = preload("res://scripts/enemy.gd").new()
	fafnyr.world = world
	fafnyr.fighter = Bells.fafnyr()
	fafnyr.add_to_group("mobs")
	world.actors.add_child(fafnyr)
	_hold(fafnyr, at)
	_lined_up.append(fafnyr)
	return fafnyr


## A lined-up foe's name, level and bars hidden: the lineup is about bodies.
func _quiet(foe: Node) -> void:
	for child in foe.get_children():
		if child is Control:
			(child as Control).visible = false
	foe.level_tag.visible = false


## Waits for a frame drawn and ready to save. While the window is hidden
## (another app full screen over it) the engine draws nothing of its own
## accord and a run would wait forever, so the look book draws the frame
## itself.
func drawn() -> void:
	await DesktopLook.drawn(self)


## The shot as it moves: MOTION_FRAMES frames, MOTION_STEP seconds apart;
## with `strike`, the hero swings at the foe on STRIKES' frames.
func _film(shot_name: String, strike := false) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in MOTION_FRAMES:
		if strike and frame in STRIKES and is_instance_valid(_foe):
			world.player.face(_foe.global_position - world.player.global_position)
			if frame == STRIKES[-1]:
				_foe.fighter["hp"] = 1
			world.player.attack_ready = true
			world.player.attack()
			# Staged: the blow lands on the beat, wherever the foe has stepped.
			_foe.take_hit(STAGED_BLOW, world.player.global_position, null, frame == STRIKES[1])
		await get_tree().create_timer(MOTION_STEP).timeout
		await drawn()
		(await DesktopLook.snapshot(self)).save_png("%s/%02d.png" % [folder, frame])


## The hero's walk (PIX-243), slowed to WALK_SLOW: standing, setting off to
## the right, a stride, turning right round, settling, then up the street
## and settling again (the back's four beats); or another walk's `legs`
## (the turns, PIX-293). Every picture is cropped round the hero into
## <out>/motion/<shot>/NN.png, and all of them, in order and STRIP_COLUMNS
## across, into walk_strip.png beside them.
func _film_walk(shot_name: String, legs: Array = WALK_LEGS) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var crops: Array[Image] = []
	Engine.time_scale = WALK_SLOW
	for leg: Array in legs:
		world.player.scripted_dir = leg[0]
		for picture in int(leg[1]):
			# The game's time, not drawn frames: a window drawing faster than
			# the clock would film the same tick over and over.
			await get_tree().create_timer(WALK_STEP).timeout
			await drawn()
			crops.append(_around_hero(await DesktopLook.snapshot(self)))
	world.player.scripted_dir = Vector2.ZERO
	Engine.time_scale = 1.0
	for index in crops.size():
		crops[index].save_png("%s/%02d.png" % [folder, index])
	_strip(crops).save_png("%s/walk_strip.png" % folder)
	print("%s %s" % ["LOOK", ProjectSettings.globalize_path("%s/walk_strip.png" % folder)])


## The part of `image` round the hero, WALK_CROP art px each way (a little
## more above, for the head).
func _around_hero(image: Image) -> Image:
	var view := get_viewport()
	var shown := image.get_width() / view.get_visible_rect().size.x
	var canvas := view.get_canvas_transform()
	var at: Vector2 = canvas * world.player.global_position * shown
	var half := WALK_CROP * canvas.get_scale().x * shown
	var box := Rect2i(Vector2i(at - Vector2(half.x, half.y * 1.25)), Vector2i(half * 2.0))
	box = box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.convert(Image.FORMAT_RGBA8)
	return crop


## The crops in order, STRIP_COLUMNS across, a dark line between them.
static func _strip(crops: Array[Image]) -> Image:
	var cell := crops[0].get_size() + Vector2i(2, 2)
	var rows := ceili(crops.size() / float(STRIP_COLUMNS))
	var out := Image.create(cell.x * STRIP_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in crops.size():
		var size := crops[index].get_size().min(cell - Vector2i(2, 2))
		out.blit_rect(crops[index], Rect2i(Vector2i.ZERO, size), Vector2i(index % STRIP_COLUMNS * cell.x + 1, index / STRIP_COLUMNS * cell.y + 1))
	return out


## A building rising on the town's tour (PIX-264), in each look: the town
## staged, back from the board with the shot's project built, the tour on
## its way; then CLIP_MARKS' frames from the moment it rises, side by side.
## The tour is closed after, so the next shot finds the world its own.
func _clip(shot: Dictionary, folders: Dictionary, images: Dictionary) -> void:
	for look: String in folders:
		if look != "":
			world.lights.wear(look)
		_stage(shot)
		GameState.reveals.assign(["project:" + String(shot["rise"])])
		world.stage.after_board()
		var rise: RebuildRise = null
		for frame in 600:
			rise = get_tree().get_first_node_in_group(RebuildRise.GROUP) as RebuildRise
			if rise != null and rise.phase != "ruin":
				break
			await drawn()
		var began := GameClock.msec()
		var frames: Array[Image] = []
		for mark: float in CLIP_MARKS:
			var left := mark - (GameClock.msec() - began) / 1000.0
			if left > 0.0:
				await get_tree().create_timer(left).timeout
			await drawn()
			frames.append(await DesktopLook.snapshot(self))
		strip(frames).save_png("%s/%s_strip.png" % [folders[look], shot["name"]])
		frames[-1].save_png("%s/%s.png" % [folders[look], shot["name"]])
		images[look].append(frames[-1])
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
		print("%s %s" % ["LOOK", shot["name"]])


## A clip's frames side by side at half size.
static func strip(frames: Array[Image]) -> Image:
	var cell := Vector2i(frames[0].get_width() / 2, frames[0].get_height() / 2)
	var out := Image.create(cell.x * frames.size(), cell.y, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		var small := frames[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index * cell.x, 0))
	return out


## The looks `--looks a,b` names, those the app has (DesktopLook.LOOKS), in
## its order.
static func looks_from(flags: HarnessFlags) -> PackedStringArray:
	var out: PackedStringArray = []
	for look in flags.list("--looks"):
		if DesktopLook.LOOKS.has(look) and not out.has(look):
			out.append(look)
	return out


## The heart of the first shower that falls in full day (Weather).
static func shower_by_day() -> float:
	var steps := 0.0
	for tries in 40:
		steps = Weather.next_shower(steps)
		var hour := fposmod(steps, float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
		if hour > 0.05 and hour < 0.42:
			return steps
		steps += DayNight.DAY_CYCLE_STEPS / 2.0
	return steps


## Where on the map: the square, beside a pack's home, or the arrival.
func _cell(map: MapData, at: String) -> Vector2i:
	var want := map.spawn
	if at == "street":
		want = STREET
	elif at != "":
		for spawn: Dictionary in Bestiary.spawns_on(map.id):
			if spawn["id"] == at:
				want = Vector2i(int(spawn["x"]), int(spawn["y"])) + Vector2i(0, 3)
	return nearest_walkable(map, want)


## The closest cell to `want` the hero can stand on (outward in rings).
static func nearest_walkable(map: MapData, want: Vector2i) -> Vector2i:
	for reach in 12:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell := want + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == reach and map.is_walkable(cell):
					return cell
	return map.spawn


## Every shot at half size, SHEET_COLUMNS across, in order.
static func sheet(images: Array[Image]) -> Image:
	var cell := Vector2i(images[0].get_width() / 2, images[0].get_height() / 2)
	var rows := ceili(images.size() / float(SHEET_COLUMNS))
	var out := Image.create(cell.x * SHEET_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in images.size():
		var small := images[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index % SHEET_COLUMNS * cell.x, index / SHEET_COLUMNS * cell.y))
	return out
