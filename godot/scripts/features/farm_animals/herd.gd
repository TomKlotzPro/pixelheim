class_name Herd
extends Node
## areas: town night
## The town's farm animals as they live (PIX-387): each stands a while, then
## steps to a cell beside it in its patch that no other stands on or is bound
## for (FarmAnimals.step), slowly, playing its walk, turned the way it goes;
## from dusk's end to dawn all sleep where they stand. Off the screen they
## rest as foes do (Enemy.rests, PIX-360): nothing moves or plays until its
## edge comes within REST_MARGIN. Each animal throws dice of its own, seeded by its place in
## the plan, so the herd draws none of the world's (a kill's loot is the
## same with or without it). Standing among the actors, sorted by their
## feet; nothing blocks.

## Each kind's pace, in pixels a second: a cell in two to three seconds.
const SPEED := {"hen": 7.0, "chick": 6.0, "sheep": 6.0, "pig": 6.0, "cow": 5.0, "bull": 5.0}
## Drawn at half the pack's size, a hen half a villager high; the cattle at
## two thirds, a cow nearly as tall as one and longer (an art pixel two
## screen pixels at the play zoom).
const SCALE := {"hen": 0.5, "chick": 0.5, "sheep": 0.5, "pig": 0.5, "cow": 2.0 / 3.0, "bull": 2.0 / 3.0}
## Seconds standing between two steps.
const STAND := Vector2(2.0, 7.0)
## Where in its cell an animal's feet stand.
const FOOT := Vector2(8, 13)
## How far past the screen's edge an animal still lives, as a foe
## (Enemy.REST_MARGIN).
const REST_MARGIN := 6.0 * MapView.TILE

## {sprite, kind, cell, area, dice, wait, goal (while it walks), resting}.
var animals: Array[Dictionary] = []
var asleep := false
## The cells stood on or walked to.
var _taken := {}


## The herd of `plan` (FarmAnimals.plan_herd), its sprites under `actors`.
func _init(plan: Array[Dictionary], actors: Node2D) -> void:
	add_to_group("decor")
	for index in plan.size():
		var entry := plan[index]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = FarmAnimals.frames(entry["sheet"])
		sprite.animation = "walk"
		var size := sprite.sprite_frames.get_frame_texture("walk", 0).get_size()
		sprite.centered = false
		sprite.offset = Vector2(-size.x / 2.0, -size.y)
		sprite.scale = Vector2.ONE * SCALE[entry["kind"]]
		sprite.position = foot(entry["cell"])
		sprite.add_to_group("decor")
		actors.add_child(sprite)
		var dice := RandomNumberGenerator.new()
		dice.seed = hash([index, entry["cell"]])
		sprite.flip_h = dice.randi() % 2 == 0
		_taken[entry["cell"]] = true
		animals.append({"sprite": sprite, "kind": entry["kind"], "cell": entry["cell"], "area": entry["area"], "dice": dice, "wait": dice.randf_range(0.0, STAND.y), "resting": false})


## A cell's spot for an animal's feet, in its map's pixels.
static func foot(cell: Vector2i) -> Vector2:
	return Vector2(cell * MapView.TILE) + FOOT


## Asleep (the night) or awake where they stand.
func sleep(night: bool) -> void:
	asleep = night
	for animal in animals:
		var sprite: AnimatedSprite2D = animal["sprite"]
		if night:
			sprite.play("sleep")
		elif animal.has("goal"):
			sprite.play("walk")
		else:
			sprite.animation = "walk"
			sprite.stop()
		if animal["resting"]:
			sprite.pause()


## The report's animals=: the town's age, how many of each kind, and
## `asleep` while they sleep (4:bull1,chick6,cow2,hen7,pig3,sheep5:asleep).
func describe() -> String:
	var counts := {}
	for animal in animals:
		counts[animal["kind"]] = int(counts.get(animal["kind"], 0)) + 1
	var kinds: PackedStringArray = []
	for kind: String in counts:
		kinds.append("%s%d" % [kind, counts[kind]])
	kinds.sort()
	return "%d:%s%s" % [GameState.town_tier(), ",".join(kinds), ":asleep" if asleep else ""]


func _process(delta: float) -> void:
	var viewport := get_viewport()
	var view := (viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()).grow(REST_MARGIN)
	for animal in animals:
		var sprite: AnimatedSprite2D = animal["sprite"]
		var resting := not view.has_point(sprite.global_position)
		if resting != animal["resting"]:
			animal["resting"] = resting
			if resting:
				sprite.pause()
			elif asleep or animal.has("goal"):
				sprite.play()
		if not resting and not asleep:
			_live(animal, delta)


## A frame of one animal's day: walking on to its goal, or standing until
## it steps again.
func _live(animal: Dictionary, delta: float) -> void:
	var sprite: AnimatedSprite2D = animal["sprite"]
	if animal.has("goal"):
		var goal := foot(animal["goal"])
		sprite.position = sprite.position.move_toward(goal, SPEED[animal["kind"]] * delta)
		if sprite.position.is_equal_approx(goal):
			_taken.erase(animal["cell"])
			animal["cell"] = animal["goal"]
			animal.erase("goal")
			animal["wait"] = (animal["dice"] as RandomNumberGenerator).randf_range(STAND.x, STAND.y)
			sprite.stop()
		return
	animal["wait"] -= delta
	if animal["wait"] > 0.0:
		return
	var cell: Vector2i = animal["cell"]
	var next := FarmAnimals.step(animal["area"], cell, _taken, animal["dice"])
	if next == cell:
		animal["wait"] = STAND.x
		return
	_taken[next] = true
	animal["goal"] = next
	# The pack draws them facing left.
	if next.x != cell.x:
		sprite.flip_h = next.x > cell.x
	sprite.play("walk")
