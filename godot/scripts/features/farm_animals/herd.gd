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
## feet, each with a body at its feet the hero bumps into (PIX-389): none
## steps into him or a villager, and one he stands facing steps aside, awake
## or asleep, so none ever shuts the way (a pig at the sty's gate by night).

## Each kind's pace, in pixels a second: a cell in two to three seconds.
const SPEED := {"hen": 7.0, "chick": 6.0, "sheep": 6.0, "pig": 6.0, "cow": 5.0, "bull": 5.0}
## Every kind drawn at two thirds of the pack's size, so an art pixel is two
## screen pixels at the play zoom for all of them (at half, three of them
## came out at one and a half: outlines a pixel, then two).
const SCALE := 2.0 / 3.0
## Seconds standing between two steps.
const STAND := Vector2(2.0, 7.0)
## Where in its cell an animal's feet stand.
const FOOT := Vector2(8, 13)
## How far past the screen's edge an animal still lives, as a foe
## (Enemy.REST_MARGIN).
const REST_MARGIN := 6.0 * MapView.TILE
## Each kind's body, in pixels: its feet, inside its cell with room
## between two side by side.
const BODY := {"hen": Vector2(8, 6), "chick": Vector2(6, 5), "sheep": Vector2(12, 6), "pig": Vector2(12, 6), "cow": Vector2(14, 6), "bull": Vector2(14, 6)}

## {sprite, body, kind, cell, area, dice, wait, goal (while it walks),
## shooed (walking off from the hero), resting}.
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
		sprite.scale = Vector2.ONE * SCALE
		sprite.position = foot(entry["cell"])
		sprite.add_to_group("decor")
		actors.add_child(sprite)
		var dice := RandomNumberGenerator.new()
		dice.seed = hash([index, entry["cell"]])
		sprite.flip_h = dice.randi() % 2 == 0
		# Moved by hand, never pushed: it holds rather than walk into anyone.
		var body := AnimatableBody2D.new()
		body.sync_to_physics = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = BODY[entry["kind"]]
		shape.shape = rect
		shape.position = Vector2(0, -rect.size.y / 2.0 + 1.0)
		body.add_child(shape)
		body.position = sprite.position
		body.add_to_group("decor")
		actors.add_child(body)
		_taken[entry["cell"]] = true
		animals.append({"sprite": sprite, "body": body, "kind": entry["kind"], "cell": entry["cell"], "area": entry["area"], "dice": dice, "wait": dice.randf_range(0.0, STAND.y), "resting": false})


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
		if not resting and (not asleep or animal.has("shooed")):
			_live(animal, delta)


## The hero on `hero` facing `cell`: an animal standing there, or bound
## there, steps aside to a free cell of its patch (or ends its step), awake
## or asleep, and lies down again there if it's night.
func shoo(hero: Vector2i, cell: Vector2i) -> void:
	for animal in animals:
		if animal.has("goal"):
			if animal["goal"] == cell or animal["cell"] == cell:
				animal["shooed"] = true
				(animal["sprite"] as AnimatedSprite2D).play("walk")
			continue
		if animal["cell"] != cell:
			continue
		var taken := _taken.duplicate()
		taken[hero] = true
		var next := FarmAnimals.step(animal["area"], cell, taken, animal["dice"])
		if next != cell:
			animal["shooed"] = true
			_set_off(animal, next)


## A frame of one animal's day: walking on to its goal, or standing until
## it steps again.
func _live(animal: Dictionary, delta: float) -> void:
	var sprite: AnimatedSprite2D = animal["sprite"]
	var body: AnimatableBody2D = animal["body"]
	if animal.has("goal"):
		var goal := foot(animal["goal"])
		var to := sprite.position.move_toward(goal, SPEED[animal["kind"]] * delta)
		# Held while the hero or a villager stands in its way.
		if body.test_move(body.global_transform, to - sprite.position):
			return
		sprite.position = to
		body.position = to
		if to.is_equal_approx(goal):
			_taken.erase(animal["cell"])
			animal["cell"] = animal["goal"]
			animal.erase("goal")
			animal.erase("shooed")
			animal["wait"] = (animal["dice"] as RandomNumberGenerator).randf_range(STAND.x, STAND.y)
			if asleep:
				sprite.play("sleep")
			else:
				sprite.stop()
		return
	animal["wait"] -= delta
	if animal["wait"] > 0.0:
		return
	var cell: Vector2i = animal["cell"]
	var next := FarmAnimals.step(animal["area"], cell, _taken, animal["dice"])
	if next == cell or body.test_move(body.global_transform, Vector2(next - cell) * MapView.TILE):
		animal["wait"] = STAND.x
		return
	_set_off(animal, next)


## An animal setting off for `next`, beside its cell.
func _set_off(animal: Dictionary, next: Vector2i) -> void:
	var sprite: AnimatedSprite2D = animal["sprite"]
	var cell: Vector2i = animal["cell"]
	_taken[next] = true
	animal["goal"] = next
	# The pack draws them facing left.
	if next.x != cell.x:
		sprite.flip_h = next.x > cell.x
	sprite.play("walk")
