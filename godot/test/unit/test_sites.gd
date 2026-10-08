extends GutTest
## Progress you can see (PIX-147): the building age's plots staked out with a
## builder by each, the town walkable around them, and what was built queued
## for the camera to show.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1


func test_the_villages_plots_are_staked_with_a_builder_each() -> void:
	var done := Town.done_projects(state.settlement)
	var sites := Town.sites(done)
	assert_eq(sites.map(func(site: Dictionary) -> String: return site["project"]), ["thatch_cottage"])
	var map := MapData.load_tiered("town", done, 1)
	var rect: Rect2i = sites[0]["rect"]
	assert_eq(map.tile_at(rect.position), "fence")
	assert_eq(map.tile_at(rect.get_center()), "crate")
	var workers := Town.site_workers(done)
	assert_eq(workers.size(), 1)
	assert_eq(workers[0]["name"], "Builder Joss")
	assert_string_contains(workers[0]["lines"][1], "400g, 5 Marsh Reed")
	assert_has(Npcs.on_map("town", 1, [], done).map(func(npc: Dictionary) -> String: return npc["id"]), "worker_thatch_cottage")


func test_a_funded_plot_becomes_its_house_and_the_town_shows_it() -> void:
	state.progression.cleared_levels.append(5)
	state.settlement.settlers.append("settler_iva")
	state.pack.gold = 2000
	state.pack.items.merge({"marsh_reed": 8, "wolf_pelt": 2})
	state.fund_project("thatch_cottage")
	assert_eq(state.reveals, ["project:thatch_cottage"] as Array[String])
	assert_true(Town.sites(Town.done_projects(state.settlement)).is_empty(), "built, not staked")
	state.fund_project("street_lamps")
	state.fund_project("market_stalls")
	assert_eq(state.reveals.slice(-2), ["project:market_stalls", "age:2"] as Array[String])
	var next_sites := Town.sites(Town.done_projects(state.settlement)).map(func(site: Dictionary) -> String: return site["project"])
	assert_eq(next_sites, ["fountain", "slate_hall", "moss_cottage"], "the Town's plots come next")


func test_a_bosss_floor_is_a_homecoming() -> void:
	state.progression.unlocked_level = 10
	state.clear_floor(10)
	assert_has(state.reveals, "home:10")
	state.reveals.clear()
	state.clear_floor(10)
	assert_true(state.reveals.is_empty(), "once")


func test_every_age_with_its_plots_keeps_the_town_walkable() -> void:
	for tier in range(0, 4):
		var map := MapData.load_tiered("town", Town.projects_through(tier), 1)
		MapView.new(map, null).plan(map.spawn)
		var seen := {map.spawn: true}
		var queue: Array[Vector2i] = [map.spawn]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next := cell + step
				if not seen.has(next) and (map.is_walkable(next) or map.portals.has(next)):
					seen[next] = true
					if map.is_walkable(next):
						queue.append(next)
		for door: Vector2i in map.portals:
			assert_true(seen.has(door), "age %d: the door at %s" % [tier, door])
		for worker: Dictionary in Town.site_workers(Town.projects_through(tier)):
			assert_true(map.is_walkable(Vector2i(worker["x"], worker["y"])), "%s stands on open ground" % worker["name"])
