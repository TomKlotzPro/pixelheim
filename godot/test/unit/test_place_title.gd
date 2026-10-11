extends GutTest
## The card naming where the hero has come to (PIX-269, PlaceTitle): the
## map's place on entering it, a region of the Ashenreach on walking into
## it, once - not again for the same name within AGAIN_MS, so crossing back
## and forth through a pass stays quiet.

const SECOND := 1000


func _here(map_id: String, cell: Vector2i) -> Dictionary:
	var map := MapData.load_by_id(map_id)
	return PlaceTitle.at(map, cell, Atlas.names_regions(map))


func test_a_place_is_named_and_the_ashenreach_by_its_regions() -> void:
	assert_eq(_here("overworld", Vector2i(2, 19)), {"place": "The Ashenreach", "region": "The Ash Fields"})
	assert_eq(_here("overworld", Vector2i(2, 34)), {"place": "The Ashenreach", "region": "The Sunken Marsh"})
	assert_eq(_here("overworld", Vector2i(48, 40))["region"], "", "the road to the village is no region")
	assert_eq(_here("mirefen", Vector2i(30, 30)), {"place": "The Mirefen", "region": ""}, "a map that is one region is its place")
	assert_eq(_here("seacave", Vector2i(5, 25)), {"place": "The Sea Cave", "region": ""}, "a cave is a place come to")
	assert_eq(_here("town_inn", Vector2i(2, 3)), {}, "a room is a door's way in, not a place")


## Every floor of a dungeon is a place come to (PIX-257: the Kings' Vault's
## five, each its own, as a region dungeon's are).
func test_a_dungeon_floor_is_a_place_of_its_own() -> void:
	var names := []
	for i in range(1, 6):
		var here := _here("vault_%d" % i, Depths.plan("vault_%d" % i)["map"].spawn)
		assert_eq(here["region"], "", "floor %d is all one region" % i)
		assert_false(String(here["place"]) in names, "floor %d has a name of its own" % i)
		names.append(here["place"])
	assert_eq(names[0], "The Gilded Stair")
	assert_eq(PlaceTitle.next({}, {"place": "The Ashenreach"}, {}, 0), [])


func test_entering_a_place_names_it_with_its_region_under_it() -> void:
	var was := {}
	var shown := {}
	assert_eq(PlaceTitle.next({"place": "Saltmere", "region": ""}, was, shown, 0), ["Saltmere", ""])
	assert_eq(PlaceTitle.next({"place": "Saltmere", "region": ""}, was, shown, SECOND), [], "once")
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Ash Fields"}, was, shown, 2 * SECOND), ["The Ashenreach", "The Ash Fields"])
	assert_true(shown.has("The Ash Fields"), "the region under the place is named too")


func test_walking_into_a_region_names_it_once() -> void:
	var was := {}
	var shown := {}
	PlaceTitle.next({"place": "The Ashenreach", "region": ""}, was, shown, 0)
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Ash Fields"}, was, shown, SECOND), ["The Ash Fields", "The Ashenreach"])
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": ""}, was, shown, 2 * SECOND), [], "the road between names nothing")
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Ash Fields"}, was, shown, 3 * SECOND), [], "nor does the ash again")
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Whispering Forest"}, was, shown, 4 * SECOND), ["The Whispering Forest", "The Ashenreach"])
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Ash Fields"}, was, shown, 5 * SECOND), [], "back along the edge: quiet")


func test_back_and_forth_through_a_pass_stays_quiet_until_a_while_has_passed() -> void:
	var was := {}
	var shown := {}
	var reach := {"place": "The Ashenreach", "region": ""}
	var mire := {"place": "The Mirefen", "region": ""}
	PlaceTitle.next(reach, was, shown, 0, true)
	assert_eq(PlaceTitle.next(mire, was, shown, SECOND), ["The Mirefen", ""])
	assert_eq(PlaceTitle.next(reach, was, shown, 5 * SECOND), ["The Ashenreach", ""], "the Reach, never shown since the game opened")
	assert_eq(PlaceTitle.next(mire, was, shown, 9 * SECOND), [], "straight back: quiet")
	assert_eq(PlaceTitle.next(reach, was, shown, 12 * SECOND), [])
	assert_eq(PlaceTitle.next(mire, was, shown, SECOND + PlaceTitle.AGAIN_MS), ["The Mirefen", ""], "a while later, named again")


func test_the_game_opening_somewhere_only_notes_it() -> void:
	var was := {}
	var shown := {}
	assert_eq(PlaceTitle.next({"place": "Pixelheim", "region": ""}, was, shown, 0, true), [])
	assert_eq(was["place"], "Pixelheim")
	assert_true(shown.is_empty(), "nothing was shown")
	assert_eq(PlaceTitle.next({"place": "Pixelheim", "region": ""}, was, shown, SECOND), [], "still there: nothing new")


func test_a_place_named_lately_still_names_the_region_come_to() -> void:
	var was := {}
	var shown := {}
	PlaceTitle.next({"place": "The Ashenreach", "region": ""}, was, shown, 0)
	PlaceTitle.next({"place": "Saltmere", "region": ""}, was, shown, SECOND)
	# Off by a waypoint into the Reach's woods, a minute after leaving it.
	assert_eq(PlaceTitle.next({"place": "The Ashenreach", "region": "The Whispering Forest"}, was, shown, 60 * SECOND), ["The Whispering Forest", "The Ashenreach"])


func test_a_room_keeps_the_place_before_it() -> void:
	var was := {}
	var shown := {}
	assert_eq(PlaceTitle.next(_here("town", Vector2i(40, 30)), was, shown, 0), ["Pixelheim", ""])
	assert_eq(PlaceTitle.next(_here("town_inn", Vector2i(2, 3)), was, shown, PlaceTitle.AGAIN_MS * 2), [], "into the inn")
	assert_eq(PlaceTitle.next(_here("town", Vector2i(40, 30)), was, shown, PlaceTitle.AGAIN_MS * 3), [], "and out: still Pixelheim")
