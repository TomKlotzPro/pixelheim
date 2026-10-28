class_name LanternPass
extends RefCounted
## areas: travel field night story +overworld*
## Fafnyr's pass on Lantern Night (PIX-362): the world's second-by-second
## watch (`watch`) begins the night's festival, and once the hero is on the
## Reach after dark plays story.json's `lantern_night` over it, Fafnyr
## crossing the sky as every lamp on the Reach catches, west to east, the
## ones on the screen as he passes over them (his crossing is the scene's,
## its cells counted from the hero's), his line said. Esc skips it, every lamp lit at once; with Reduce motion he
## doesn't fly and they're lit as it opens. Over, played or skipped, it is
## the night's one pass (LanternNight.fly).

## The Reach's drawing, its lamps' places in his order, the night's day
## and the town keeping it (GameState's).
var view: MapView
var places: Array[String] = []
var day := 0
var settlement: SettlementState
## The lamps lit so far, and whether the pass is over.
var lit := 0
var over := false


## Each second (world.gd): Lantern Night's festival begun, and his pass
## played once the hero is on the Reach after dark with a lamp built there
## to light. Harness runs skip it but with `--lantern fly`.
static func watch(world: Node) -> void:
	if world.harness and HarnessFlags.given().value("--lantern") != "fly":
		return
	var day := Gathering.day_of(GameState.world.steps)
	if LanternNight.begins(GameState.progression, GameState.settlement, day):
		LanternNight.begin(GameState.settlement, day, GameState.town_tier())
		# In town its stalls go up round the hero, as an age's festival's do
		# once the board shuts (WorldStage.after_board; PIX-367).
		if world.map.id == "town":
			world.map = world.load_map("town")
			world.enter_map(world.map, world.player_cell)
	if world.map.id == Routes.MAP and Screen.holds() == 0 and DayNight.is_night(GameState.world.steps) \
			and LanternNight.waits(GameState.progression, GameState.settlement, day) and not Routes.lamps(GameState.settlement).is_empty():
		play(world, day)


static func play(world: Node, day: int) -> void:
	var moment := LanternPass.new()
	moment.view = world.view
	moment.day = day
	moment.settlement = GameState.settlement
	moment.places = LanternNight.order(Routes.lamps(GameState.settlement))
	var scene := Cutscene.new()
	scene.scene_id = "lantern_night"
	# A lambda, so the scene keeps the pass alive to its end.
	scene.on_done = func() -> void: moment.finish()
	world.add_child(scene)
	# The scene's cells count from the hero's: he crosses the sky over
	# wherever the hero stands on the Reach.
	var at: Vector2i = world.player_cell
	var crossing := {}
	for step: Dictionary in scene.steps:
		for key: String in ["cell", "to_cell"]:
			if step.has(key):
				step[key] = [at.x + int(step[key][0]), at.y + int(step[key][1])]
		if step.has("to_cell"):
			crossing = step
	Sound.play("roar")
	if GameState.settings.reduce_motion:
		while moment.lit < moment.places.size():
			moment.step(false)
		return
	# Each lamp catches as he passes over it: those west of the screen as
	# he comes into it, those east of it as he leaves. Bound to the scene,
	# which runs while the world holds still.
	var sweep := scene.create_tween()
	var west := float(crossing["cell"][0])
	var span := float(crossing["to_cell"][0]) - west
	var passed := 0.0
	for place in moment.places:
		var due := clampf((Vector2i(Routes.lamp_of(place)["cell"]).x - west) / span, 0.0, 1.0) * float(crossing["seconds"])
		if due > passed:
			sweep.tween_interval(due - passed)
			passed = due
		sweep.tween_callback(moment.step)


## The next lamp in his way lit, a chime with it (`chime`).
func step(chime := true) -> void:
	if lit >= places.size():
		return
	if is_instance_valid(view):
		LanternLayer.light(view, places[lit], true)
	lit += 1
	if chime:
		Sound.play("learn")


## The pass over, played out or skipped: every lamp lit, the night's pass
## kept.
func finish() -> void:
	if over:
		return
	over = true
	while lit < places.size():
		step(false)
	LanternNight.fly(settlement, day, GameState.town_tier())
	GameState.save_now()
