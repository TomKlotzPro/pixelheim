extends Control
## The boss bar (PIX-210): across the top of the screen while a boss - or a
## named monster - hunts the hero. Its name over a long health bar; what a
## blow takes stays a moment as a pale ghost before it drains, so a big hit
## reads as one. A boss's bar is notched where its next phase begins (the
## shares BossBrain roars at). It fades once the foe falls or gives up.

const SIZE := Vector2(420, 12)
## How long a blow's ghost holds before it drains, and how fast it drains
## (a share of the whole bar a second).
const GHOST_HOLD := 0.4
const GHOST_DRAIN := 0.6
const FILL := Color("d8433f")
const SHINE := Color("ff8a80")
const GHOST := Color("ffe08a")

var target: Node = null
var plate: PanelContainer
var name_label: Label
var fill: ColorRect
var shine: ColorRect
var ghost: ColorRect
var notches: Array[ColorRect] = []
## The health shown, its ghost, and how long the ghost still holds.
var share := 1.0
var ghost_share := 1.0
var hold := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate(14))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	name_label = UiStyle.strong("", 16, UiStyle.CREAM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var outline := ColorRect.new()
	outline.color = UiStyle.NIGHT
	outline.custom_minimum_size = SIZE
	column.add_child(outline)
	ghost = _strip(GHOST)
	outline.add_child(ghost)
	fill = _strip(FILL)
	outline.add_child(fill)
	shine = ColorRect.new()
	shine.color = SHINE
	shine.size = Vector2(fill.size.x, 2)
	fill.add_child(shine)
	for at: float in BossBrain.PHASES:
		var notch := ColorRect.new()
		notch.color = UiStyle.NIGHT
		notch.size = Vector2(2, SIZE.y)
		notch.position.x = 2 + _width(at)
		outline.add_child(notch)
		notches.append(notch)
	plate.resized.connect(func() -> void: plate.position = Vector2(roundf((1280 - plate.size.x) / 2.0), 14))


func _strip(color: Color) -> ColorRect:
	var strip := ColorRect.new()
	strip.color = color
	strip.position = Vector2(2, 2)
	strip.size = SIZE - Vector2(4, 4)
	return strip


## A share of the bar in whole art pixels (two canvas pixels each).
static func _width(at: float) -> float:
	return floorf((SIZE.x - 4) * clampf(at, 0.0, 1.0) / 2.0) * 2.0


## Where the bar ends, for what stands under it (a first-time hint).
func bottom() -> float:
	return plate.position.y + plate.size.y


## Whether a foe has the bar now (alive and hunting, or the bar still
## fading out after it).
func following() -> bool:
	return _live() or modulate.a > 0.0


## Whether the bar is on the screen at all, even fading (the report's
## `bossbar`, PIX-288).
func showing() -> bool:
	return modulate.a > 0.0


## What the bar reads (the report's `bossbar`): its foe's share of health,
## `fading` once that foe is out of the fight.
func reading() -> String:
	var shown := "%d%%" % roundi(maxf(share, ghost_share) * 100.0)
	return shown if _live() else "fading " + shown


## From now on the bar shows `enemy` (the world calls it as a boss hunts).
func follow(enemy: Node) -> void:
	target = enemy
	name_label.text = enemy.fighter["name"]
	var phased: bool = Bestiary._data()["bossPatterns"].has(enemy.fighter["id"])
	for notch in notches:
		notch.visible = phased
	share = _health()
	ghost_share = share
	hold = 0.0


## Off the screen at once, whatever it followed (PIX-288): the hero has
## left for another map, where that fight is over.
func let_go() -> void:
	target = null
	modulate.a = 0.0
	share = 0.0
	ghost_share = 0.0
	hold = 0.0


## Its foe still in the fight. A foe already freed reads as out of it:
## `is_instance_valid`, never `target != null`, which a freed foe passes.
func _live() -> bool:
	return is_instance_valid(target) and not target.dying and target.hunting


func _health() -> float:
	if not is_instance_valid(target) or target.dying:
		return 0.0
	return clampf(float(target.fighter["hp"]) / maxi(1, int(target.fighter["maxHp"])), 0.0, 1.0)


func _process(delta: float) -> void:
	# Out of the screen with nothing hunting: nothing to draw. This used to be
	# `target == null`, which a freed foe is too (Godot 4): a boss whose body
	# dissolved before its bar had faded left the bar frozen on the screen,
	# a blow's pale ghost on an empty bar, for good (PIX-288, PIX-232).
	if modulate.a == 0.0 and not _live():
		target = null
		return
	var now := _health()
	if now < share:
		hold = GHOST_HOLD
	share = now
	var trailed := trail(ghost_share, share, hold, delta)
	ghost_share = trailed[0]
	hold = trailed[1]
	fill.size.x = _width(share)
	shine.size.x = fill.size.x
	ghost.size.x = _width(ghost_share)
	# In while it hunts; once it falls, out after its ghost has drained.
	var wanted := 1.0 if _live() or ghost_share > share else 0.0
	modulate.a = move_toward(modulate.a, wanted, delta * 3.0)
	if modulate.a == 0.0 and not _live():
		target = null


## The ghost after `delta`: it holds, then drains toward the health shown,
## never below it. Returns [ghost, hold].
static func trail(ghost_at: float, health: float, held: float, delta: float) -> Array:
	if ghost_at <= health:
		return [health, 0.0]
	if held > 0.0:
		return [ghost_at, held - delta]
	return [maxf(health, ghost_at - GHOST_DRAIN * delta), 0.0]
