extends GutTest
## Loot that pops (PIX-492): a kill's coins burst out and fly to the hero
## while its float counts up. Only the look takes its time: the win is paid
## and tallied whole at the kill, the coins are capped, their shares add up
## to the gold, and with motion reduced nothing flies.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## A world as LootPop reads it: the map shown and the hero.
class Place:
	extends "res://test/bare_world.gd"

	func _init() -> void:
		view = MapView.new(MapData.new(), self)


var _still: bool


func before_each() -> void:
	_still = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false


func after_each() -> void:
	GameState.settings.reduce_motion = _still


func _win(gold: int, xp: int) -> Dictionary:
	var win := Gains.none()
	win["gold"] = gold
	win["xp"] = xp
	return win


## The float's words now: its purse line as it reads.
func _purse(fx: WorldFx) -> String:
	for box: Node in fx.get_children():
		for row: Node in box.get_children():
			if not row.is_queued_for_deletion() and row.has_node("text"):
				return (row.get_node("text") as Label).text + (" " + (row.get_node("then") as Label).text if row.has_node("then") else "")
	return ""


func test_a_foes_coins_are_capped_and_never_more_than_its_gold() -> void:
	assert_eq(LootBurst.coins(0), 0, "no gold, no coin")
	assert_eq(LootBurst.coins(1), 1, "one gold is one coin")
	for gold in range(1, 2000, 7):
		assert_between(LootBurst.coins(gold), 1, mini(gold, LootBurst.COINS), "%d gold" % gold)
		assert_between(LootBurst.coins(gold, true), 1, mini(gold, LootBurst.BIG_COINS), "a boss's %d gold" % gold)
		assert_between(LootBurst.sparks(gold), 1, mini(gold, LootBurst.SPARKS), "%d XP" % gold)
		assert_between(LootBurst.sparks(gold, true), 1, mini(gold, LootBurst.BIG_SPARKS), "a boss's %d XP" % gold)
	assert_eq(LootBurst.coins(500), LootBurst.COINS, "a rich foe's at the cap")
	assert_gt(LootBurst.coins(500, true), LootBurst.COINS, "a boss's burst is bigger")


func test_the_coins_shares_add_up_to_the_gold() -> void:
	for gold in range(1, 400):
		for big: bool in [false, true]:
			var shares := LootBurst.shares(gold, LootBurst.coins(gold, big))
			var sum := 0
			for share in shares:
				sum += share
				assert_gt(share, 0, "no empty coin")
			assert_eq(sum, gold, "%d gold" % gold)


func test_a_drop_shines_by_its_rarity() -> void:
	assert_eq(["common", "fine", "epic"].map(LootBurst.shine), ["", "glow", "beam"])


## On the ground a drop is on the world's grid (review of PIX-492: never
## the float's icon, two screen pixels an art pixel): a pouch nine pixels
## square, rimmed in its rarity's colour.
func test_a_drop_on_the_ground_is_a_pouch_rimmed_in_its_rarity() -> void:
	var epic: Color = WorldFx.GAIN_TONES["epic"]
	var pouch := LootPop._pouch(epic).get_image()
	assert_eq(pouch.get_size(), Vector2i(9, 9))
	assert_eq(pouch.get_pixel(4, 0), epic, "the rim over its knot")
	assert_eq(pouch.get_pixel(0, 0).a, 0.0, "its corners clear")
	assert_eq(pouch.get_pixel(4, 1), UiStyle.NIGHT, "its own outline inside the rim")


## The kill pays whole and at once, whatever the look does after: the purse
## the same with motion or without, and nothing the burst does touches it.
func test_the_credit_is_the_kills_and_unchanged() -> void:
	var paid: Array[int] = []
	for still: bool in [false, true]:
		GameState.settings.reduce_motion = still
		var state: Node = autofree(GameStateScript.new())
		state.new_game("Robin", "warrior")
		state.roll = func() -> float: return 0.99
		var before: int = state.pack.gold
		var won: Dictionary = state.spoils.defeat_monster(Bestiary.spawn("goblin"), "", "", 1)
		assert_eq(state.pack.gold - before, int(won["gains"]["gold"]), "paid at the kill")
		paid.append(state.pack.gold)
	assert_eq(paid[0], paid[1], "the same purse with motion reduced")
	var gold: int = GameState.pack.gold
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.burst_gains(_win(9, 4), Vector2(100, 80))
	assert_eq(Gains.summary(fx.floated), "+9 gold · +4 XP", "tallied whole at the kill")
	await wait_seconds(1.8)
	assert_eq(GameState.pack.gold, gold, "the flight pays nothing")


func test_the_float_counts_up_to_the_gold_as_the_coins_land() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.burst_gains(_win(23, 7), Vector2(100, 80))
	assert_eq(fx.loot.coins, LootBurst.coins(23))
	assert_eq(_purse(fx), "", "nothing shows before the first one lands")
	# The sparks are in, the coins on the ground still.
	await wait_seconds(0.7)
	assert_eq(_purse(fx), "+7 XP", "the XP first")
	var seen := {}
	while fx.loot.gold_counted < 23 and seen.size() < 400:
		await wait_process_frames(1)
		seen[_purse(fx)] = true
	assert_gt(seen.size(), 3, "it counted up, coin by coin: %s" % [seen.keys()])
	assert_eq(_purse(fx), "+23 gold · +7 XP", "and ends on what the kill paid")
	assert_eq(fx.get_child_count(), 1, "one float, not one a coin")
	await wait_seconds(0.3)
	assert_string_ends_with(fx.loot.summary(), "flying 0 sparks 2 drops 0 counted 23/23")


func test_with_motion_reduced_nothing_flies() -> void:
	GameState.settings.reduce_motion = true
	Sound._played_at.clear()
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.burst_gains(_win(23, 7), Vector2(100, 80), true)
	assert_eq(fx.loot.summary(), "", "no burst")
	assert_false(fx.loot.is_processing(), "nothing to move")
	assert_eq(_purse(fx), "+23 gold · +7 XP", "the float as it always was, at once")
	assert_eq(Gains.summary(fx.floated), "+23 gold · +7 XP")
	assert_false(Sound._played_at.is_empty(), "and the kill's held ring, once")


func test_reduce_motion_never_moves_the_games_dice() -> void:
	var next := []
	for still: bool in [false, true]:
		GameState.settings.reduce_motion = still
		var fx: WorldFx = add_child_autofree(WorldFx.new())
		seed(4920)
		fx.burst_gains(_win(23, 7), Vector2(100, 80))
		next.append(randf())
	assert_eq(next[0], next[1], "the same draw comes next whichever way the win shows")


## A crowd past the pool lands at once: every share is still counted.
func test_past_the_most_they_land_at_once() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	for i in 20:
		fx.burst_gains(_win(40, 30), Vector2(100, 80))
	assert_eq(fx.loot.gold_counted + fx.loot._bits.reduce(func(sum: int, bit: Dictionary) -> int: return sum + int(bit.get("win", {}).get("gold", 0)), 0), 800, "none lost")
	assert_lte(fx.loot._bits.size(), LootPop.MOST + LootBurst.COINS + LootBurst.SPARKS)


## A pack of five felled in one frame: under the pool's most, so every coin
## flies (none landed undrawn) and the one float counts them all.
func test_five_felled_at_once_all_fly() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	for i in 5:
		fx.burst_gains(_win(40, 30), Vector2(100 + i * 16, 80))
	assert_eq(fx.loot.gold_counted, 0, "none landed at once")
	assert_eq(fx.loot._bits.size(), 5 * (LootBurst.COINS + LootBurst.SPARKS))
	await wait_seconds(2.0)
	assert_string_ends_with(fx.loot.summary(), "flying 0 sparks 25 drops 0 counted 200/200")


## The first kill past a door (review of PIX-492): LootPop slept between the
## two, and the new map's burst is kept, its float counting to its gold;
## what was still in the air on the old map stays behind, uncounted.
func test_a_burst_on_the_next_map_counts_as_the_first_did() -> void:
	var stage: Place = add_child_autofree(Place.new())
	var fx := WorldFx.new()
	fx.world = stage
	stage.add_child(fx)
	fx.burst_gains(_win(10, 5), Vector2(100, 80))
	await wait_seconds(2.0)
	assert_eq(fx.loot.gold_counted, 10, "the first map's")
	assert_false(fx.loot.is_processing(), "asleep between kills")
	stage.view = MapView.new(MapData.new(), stage)
	fx.burst_gains(_win(10, 5), Vector2(100, 80))
	await wait_seconds(2.0)
	assert_eq(fx.loot.gold_counted, 20, "the next map's first kill counted too")
	# Through a door with coins in the air: they stay behind, the new
	# map's fly.
	fx.burst_gains(_win(10, 5), Vector2(100, 80))
	stage.view = MapView.new(MapData.new(), stage)
	fx.burst_gains(_win(7, 5), Vector2(100, 80))
	await wait_seconds(2.0)
	assert_eq(fx.loot.gold_counted, 27, "only the new map's landed")
	assert_string_contains(fx.loot.summary(), "flying 0 ")


## The purse rings as the coins land, not at the kill as well: gold paid
## while the soundscape is told to keep quiet is heard, never played.
func test_a_kills_gold_is_quiet_until_its_coins_land() -> void:
	var ears: Soundscape = autofree(Soundscape.new())
	Sound._played_at.clear()
	ears.quiet_gold = true
	ears.hear_gold(50)
	assert_eq(ears.heard_gold, 50, "heard")
	assert_true(Sound._played_at.is_empty(), "not rung")
	ears.quiet_gold = false
	ears.hear_gold(60)
	assert_false(Sound._played_at.is_empty(), "the purse rings as ever otherwise")


## A boss's coins land closer together than Sound lets one take through:
## only the heard ticks count, so the run still climbs a step a tick.
func test_a_run_of_ticks_counts_only_the_heard_ones() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var loot := fx.loot
	for i in 6:
		loot._clock = 1.0 + i * 0.025
		loot._land({"kind": LootPop.COIN, "at": Vector2.ZERO})
	assert_eq(loot._streak, 2, "three heard of six: the first, then two steps up")
