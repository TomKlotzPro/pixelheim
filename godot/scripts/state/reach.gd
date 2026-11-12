class_name Reach
## areas: combat field
## How far every blow reaches (PIX-410, Tom: « je peux toucher les ennemis de
## loin mais ça fait pas sens si je suis un guerrier »): the hero's swing by
## the swing drawn, a skill by its kind, a foe's bite and its shot, from
## combat.json's "reach", in cells on the ground. Melee is contact, the cell
## in front and its corners, never two cells off; a bow, a staff, a spell or
## a foe's shot reaches from afar and is seen flying there. Pure; player.gd
## and enemy.gd ask it who a blow lands on.

const TILE := 16.0
## Where round its foe a step lands (PIX-455), in degrees off straight past
## it: behind first, then its back corners, then beside it.
const STEP_TURNS: Array[float] = [0.0, 45.0, -45.0, 90.0, -90.0]


static func rules() -> Dictionary:
	return Bestiary.reach_rules()


## The hero's swing with `attack` in hand, by the swing PunyArt draws
## (sword, bow or staff): {cells, arc, shot}.
static func swing(attack: String) -> Dictionary:
	var swings: Dictionary = rules()["swings"]
	return swings.get(attack, swings["sword"])


## A damage skill's reach, by the kind it names (melee, ranged or burst).
static func skill(entry: Dictionary) -> Dictionary:
	return rules()["skills"][String(entry["reach"])]


## A foe's shot (its kind's `shoots`: arrow, ball, flame), or {} for a foe
## that only bites.
static func shot(monster_id: String) -> Dictionary:
	var kind := String(Bestiary.monster(monster_id).get("shoots", ""))
	return {} if kind == "" else rules()["shots"][kind].merged({"look": kind})


## A reach's cells in pixels.
static func px(reach: Dictionary, key := "cells") -> float:
	return float(reach[key]) * TILE


## How near the hero a foe tells its bite, and how near they must still be
## for it to land, in pixels (kept: asked every tick by every hunting foe).
static var _bite := Vector2.ZERO


static func bite_tell() -> float:
	return _bite_px().x


static func bite_lands() -> float:
	return _bite_px().y


static func _bite_px() -> Vector2:
	if _bite == Vector2.ZERO:
		var bite: Dictionary = rules()["bite"]
		_bite = Vector2(px(bite, "tell"), px(bite))
	return _bite


## Whether a blow from `from`, facing `facing` (ZERO: whichever way), lands
## on a body `radius` wide either side of its feet at `to`: within the
## reach's cells of the body's near edge and, with an `arc`, within its
## degrees about the facing, widened by the body's own breadth (a body half
## in the arc is in it).
static func lands(from: Vector2, facing: Vector2, to: Vector2, radius: float, reach: Dictionary) -> bool:
	var offset := to - from
	var apart := offset.length()
	if apart - radius > px(reach):
		return false
	if facing == Vector2.ZERO or not reach.has("arc") or apart <= radius:
		return true
	var half := deg_to_rad(float(reach["arc"]) / 2.0) + asin(radius / apart)
	return absf(facing.angle_to(offset)) <= half


## Which of the foes standing at `spots` (their feet, each `radii` wide
## either side) a swing from `from` facing `facing` lands on, by index:
## every one a blade reaches, the nearest one a shot does.
static func struck(from: Vector2, facing: Vector2, spots: Array[Vector2], radii: Array[float], reach: Dictionary) -> Array[int]:
	var hit: Array[int] = []
	for i in spots.size():
		if lands(from, facing, spots[i], radii[i], reach):
			hit.append(i)
	if reach.get("shot", false) and hit.size() > 1:
		hit.sort_custom(func(a: int, b: int) -> bool: return from.distance_to(spots[a]) < from.distance_to(spots[b]))
		hit.resize(1)
	return hit


## Who a damage skill strikes among the foes at `spots`, by index: the
## nearest it reaches, those ahead of `facing` first; for an area skill
## every foe in its area as well (a melee one's or a burst's round the hero,
## a ranged one's round that foe). None when no foe is in reach.
static func targets(from: Vector2, facing: Vector2, spots: Array[Vector2], radii: Array[float], entry: Dictionary) -> Array[int]:
	var reach := skill(entry)
	var first := -1
	var best := INF
	for i in spots.size():
		if not lands(from, Vector2.ZERO, spots[i], radii[i], reach):
			continue
		var offset := spots[i] - from
		var score := offset.length() - (12.0 if offset.normalized().dot(facing) > 0.5 else 0.0)
		if score < best:
			best = score
			first = i
	if first < 0:
		return []
	if not entry.get("area", false):
		return [first]
	var around := {"cells": reach["around"]} if reach.has("around") else reach
	var centre := spots[first] if reach.has("around") else from
	var hit: Array[int] = []
	for i in spots.size():
		if i == first or lands(centre, Vector2.ZERO, spots[i], radii[i], around):
			hit.append(i)
	return hit


## Where a step from `from` to the foe at `to` lands (Shadowstep, PIX-455):
## `edge` past its feet, where it would stand by the hero (Enemy.edge_of),
## on its far side, else round it to beside it: the first spot `open` takes.
## `from` when it takes none, the blow struck from where the hero stands.
static func landing(from: Vector2, to: Vector2, edge: float, open: Callable) -> Vector2:
	var past := (to - from).normalized() if to != from else Vector2.RIGHT
	for turn in STEP_TURNS:
		var spot := to + past.rotated(deg_to_rad(turn)) * edge
		if open.call(spot):
			return spot
	return from
