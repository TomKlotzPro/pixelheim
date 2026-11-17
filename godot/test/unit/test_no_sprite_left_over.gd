extends GutTest
## Nothing a map's drawing makes is left outside the tree (PIX-504): a healed
## ash-field tree and an open gate's cell made their sprite before deciding
## to draw nothing, one node leaked a piece on every build without the paid
## pack, which `flows.sh` now fails a flow on.

var _withheld := false


func before_each() -> void:
	_withheld = PunyTown.withheld
	PunyTown.withheld = true


func after_each() -> void:
	PunyTown.withheld = _withheld


static func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func test_a_healed_ash_tree_and_floor_leave_no_sprite() -> void:
	var view := MapView.new(MapData.load_by_id(AshRuins.MAP), null)
	var before := _orphans()
	AshRuins._draw(view, {"kind": "tree", "cell": Vector2i(4, 4), "mended": true})
	AshRuins._draw(view, {"kind": "floor", "cell": Vector2i(4, 4), "mended": true, "size": Vector2i(3, 3)})
	assert_eq(_orphans(), before, "nothing to draw, nothing made")


func test_an_open_gate_leaves_no_sprite() -> void:
	var view := MapView.new(MapData.load_by_id("greyhold"), null)
	view.rampart = {"gates": [{"cells": [Vector2i(4, 4), Vector2i(5, 4)]}], "fallback": {}}
	var before := _orphans()
	GroundLayer._gate_arches(view)
	assert_eq(_orphans(), before, "no arch, nothing made")
