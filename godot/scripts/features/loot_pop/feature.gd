extends Feature
## areas: combat
## Loot that pops, in the harness (PIX-492): `--loot` and the report's
## loot=, their rows beside this script and their flows in
## tools/flows.d/loot_pop.txt. The look is LootPop's (scripts/loot_pop.gd,
## WorldFx.burst_gains), the counts LootBurst's
## (scripts/state/loot_burst.gd). `--loot` stages a win with a drop of a
## rarity no run can be sure of; a run with `still` (Reduce motion) is the
## one where nothing flies. No map layer of its own.


## After `pack`, the fight's own flags.
func flags_after() -> String:
	return "pack"


## `--loot epic`: a staged win bursts beside the hero, as a kill's does,
## with an iron sword of that rarity (`big`: a boss's burst and no drop).
## Shown, never paid.
func step_loot(h: Node) -> void:
	var staged: String = h.flags.value("--loot")
	var win := Gains.none()
	win["gold"] = 120 if staged == "big" else 8
	win["xp"] = 60 if staged == "big" else 4
	if staged != "big":
		Gains.add_piece(win, InventoryState.create_gear("iron_sword", staged, func() -> float: return 0.0))
	h.world.fx.burst_gains(win, h.world.player.global_position + Vector2(MapView.TILE * 2, 0), staged == "big")


# --- The report's field -------------------------------------------------------

func field_loot(report: HarnessReport) -> String:
	return report.world.fx.loot.summary()
