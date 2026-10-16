extends Node
## The look book (PIX-220): the same scenes, staged the same way every time -
## the town by day, at dusk and at night, the forest, the Ash, the Mire, the
## Frostgate, the Kings' Vault, a fight, the overworld at night, the
## village seen from its road (PIX-248), the ways between maps (PIX-269),
## the map screen (PIX-266), the rooms behind the Reach's doors with the
## stairs down in their floors (PIX-256) and the card naming a place come
## to - each saved
## as a picture, and all of them on one contact sheet, so a change to how the
## game looks is judged before and after, by eye. With `perf`, each shot also
## reports what its frames cost (PerfProbe); with `film`, each is filmed for
## a moment too, frame by frame, for what a still can't show (the wind, the
## water). With `--looks a,b`, the desktop renderer shoots each scene in each
## of the app's looks (PIX-227, DesktopLook.LOOKS), each look in its own
## folder with its own sheet. A shot that is a moment rather than a place (a
## clip: `rise`, PIX-264) is staged afresh for each look and kept as a strip
## of frames through it, <name>_strip.png; its last frame stands in the
## sheet. Each folder also gets shots.txt, the shots' names in the sheet's
## order, for tools/lookbook_compare.py. Run by tools/lookbook.sh.

## Where in the day a shot stands (DayNight's wheel, 0..1).
const DAY := 0.2
const DUSK := 0.53
const NIGHT := 0.75
## The sheet's areas, in its order (PIX-273): the village and its rooms,
## the Reach around it, the regions beyond, the ways between them,
## underground, a fight, and the game's pages. A shot names its area, and
## the sheet groups them so, in the order SHOTS gives within an area.
const AREAS := ["town", "rooms", "reach", "regions", "ways", "dungeon", "combat", "screens"]
## Each shot by its name (its picture's file, and `--only`'s word: never a
## number, which every branch adding a shot took the same next one of): its
## area; a map and where on it (Upper Street, a pack's home, a cell, or the
## map's arrival); the hour, or the first shower by day
## (`rain`); and a foe to face, for the fight, struck on a beat while it's
## filmed (`strike`), the third blow felling it, or caught as it notices the
## hero (`notice`, PIX-289). A `letter` of Maren's is carried for that shot
## alone (its recipient's mark), and the town stands at age `tier` for it
## alone (PIX-307; every age built otherwise), and `post` opens the
## Pixelheim Post for it (PIX-320: its `box` faced, or its `tab` read).
## Only a shot with `card` keeps
## the title card naming the place it enters (PIX-269). A new shot goes
## with its area's.
const SHOTS := {
	"town_day": {"area": "town", "map": "town", "at": "street", "time": DAY},
	"town_dusk": {"area": "town", "map": "town", "at": "street", "time": DUSK},
	"town_night": {"area": "town", "map": "town", "at": "street", "time": NIGHT},
	"riverside": {"area": "town", "map": "town", "cell": Vector2i(72, 8), "time": DAY},
	# The village's river where it turns west under the rampart (PIX-306):
	# deep down its middle, flowing, foam at its banks; by day and at night.
	"town_river": {"area": "town", "map": "town", "cell": Vector2i(60, 33), "time": DAY},
	"town_river_night": {"area": "town", "map": "town", "cell": Vector2i(60, 33), "time": NIGHT},
	# The village's gate from inside (PIX-248): one rampart, the gatehouse
	# three wide between its towers, the road running on out through the
	# fields; and its torches at night.
	"town_gate": {"area": "town", "map": "town", "cell": Vector2i(40, 5), "time": DAY},
	"town_gate_night": {"area": "town", "map": "town", "cell": Vector2i(40, 5), "time": NIGHT},
	# The hero's walk (PIX-243), filmed (`film`) setting off, striding, turning
	# right round and settling, then walking up the street.
	"walk": {"area": "town", "map": "town", "cell": Vector2i(38, 13), "time": DAY, "walk": true},
	# Turning in the walk (PIX-293), filmed: down, then right with both keys
	# held a moment on the way (the diagonal), up then left the same way,
	# and down then right with no overlap; then a diagonal held and one key
	# let go.
	"turn": {"area": "town", "map": "town", "cell": Vector2i(38, 13), "time": DAY, "walk": true, "legs": "turn"},
	# Odo's store rising out of its ruin on the town's tour (PIX-264).
	"rise": {"area": "town", "map": "town", "at": "street", "time": DAY, "rise": "odos_store"},
	# The streets by the town's age (PIX-307, `tier`): Upper Street trodden
	# and rutted in the Ashes, the square in gravel in the Village, Upper
	# Street cobbled in the Town, and the City's square in sandstone, brick
	# round its fountain, by day and at night.
	"streets_ashes": {"area": "town", "map": "town", "cell": Vector2i(40, 13), "time": DAY, "tier": 0},
	"streets_village": {"area": "town", "map": "town", "cell": Vector2i(40, 22), "time": DAY, "tier": 2},
	"streets_town": {"area": "town", "map": "town", "cell": Vector2i(40, 13), "time": DAY, "tier": 3},
	"streets_city": {"area": "town", "map": "town", "cell": Vector2i(40, 22), "time": DAY},
	"streets_city_night": {"area": "town", "map": "town", "cell": Vector2i(40, 22), "time": NIGHT},
	# The Pixelheim Post's box on the square past the bounty board (PIX-320,
	# `post`: the Post open for the shot alone), holding the day's post, its
	# pennant up; by day and at night.
	"post_box": {"area": "town", "map": "town", "cell": Vector2i(44, 23), "time": DAY, "post": "box"},
	"post_box_night": {"area": "town", "map": "town", "cell": Vector2i(44, 23), "time": NIGHT, "post": "box"},
	"inn_night": {"area": "rooms", "map": "town_inn", "time": NIGHT},
	# A room by day, the day through its windows lying on the floor, and
	# Odo's store's patterned rug (PIX-311, PIX-315).
	"inn_day": {"area": "rooms", "map": "town_inn", "time": DAY},
	"odos_store": {"area": "rooms", "map": "town_shop", "time": DAY},
	"smithy_day": {"area": "rooms", "map": "town_smith", "time": DAY},
	# A house opens onto a room, the cave down a stair in its floor (PIX-256):
	# Liane's room and Captain Hale's hall from beside the stairwell, then at
	# its top, the stairs asking.
	"lianes_room": {"area": "rooms", "map": "observatory", "cell": Vector2i(13, 7), "time": DAY},
	"lianes_stair": {"area": "rooms", "map": "observatory", "cell": Vector2i(13, 6), "time": DAY, "down": true},
	# Liane's observatory at night (PIX-311, PIX-315): her telescope at the
	# window, the chart of the sky on the wall, the globe of it by her desk,
	# her candles lit and the corners dark.
	"lianes_room_night": {"area": "rooms", "map": "observatory", "cell": Vector2i(10, 6), "time": NIGHT},
	# The frost round her stair at night (PIX-317): rime and crystals in cold
	# blues under her candles' warm light, and the stair's own cold light
	# keeping the way down seen.
	"lianes_frost_night": {"area": "rooms", "map": "observatory", "cell": Vector2i(13, 7), "time": NIGHT},
	"hales_hall": {"area": "rooms", "map": "keep", "cell": Vector2i(13, 7), "time": DAY},
	"hales_stair": {"area": "rooms", "map": "keep", "cell": Vector2i(13, 6), "time": DAY, "down": true},
	# Morvax's forge (PIX-253 step 8): the cot, the cold anvil, and fifty
	# years of tally marks on the back wall.
	"morvax_forge": {"area": "rooms", "map": "morvax_forge", "cell": Vector2i(11, 3), "time": DAY},
	"forest": {"area": "reach", "map": "overworld", "at": "forest_2", "time": DAY},
	"ash": {"area": "reach", "map": "overworld", "at": "ash_3", "time": DAY},
	# Open ground (PIX-305): the Reach's meadow south-east of the village, its
	# patches of lusher and drier grass, clover and the wind over it, by day
	# and at night; and the Ash's road, where the region's tone used to leave
	# wandering bands of dither either side of it.
	"meadow": {"area": "reach", "map": "overworld", "cell": Vector2i(70, 40), "time": DAY},
	"meadow_night": {"area": "reach", "map": "overworld", "cell": Vector2i(70, 40), "time": NIGHT},
	"ash_road": {"area": "reach", "map": "overworld", "cell": Vector2i(30, 15), "time": DAY},
	# The Ash scorched (PIX-308): its ground in patches of char and pale ash,
	# cracked, burnt tufts and cinders, its outcrops burnt rock with dead
	# trees on them, ash drifting; by day, and at night its cinders glowing.
	"ash_scorched": {"area": "reach", "map": "overworld", "cell": Vector2i(18, 22), "time": DAY},
	"ash_scorched_night": {"area": "reach", "map": "overworld", "cell": Vector2i(18, 22), "time": NIGHT},
	"overworld_night": {"area": "reach", "map": "overworld", "at": "forest_2", "time": NIGHT},
	# The ridge round the Reach (PIX-309): its rim and crown broken, pines
	# and rocks stepping out of it, by day and at night; and the pass up to
	# the Frostgate, its pines whitening toward the snow.
	"ridge": {"area": "reach", "map": "overworld", "cell": Vector2i(30, 58), "time": DAY},
	"ridge_night": {"area": "reach", "map": "overworld", "cell": Vector2i(30, 58), "time": NIGHT},
	"frost_pass": {"area": "reach", "map": "overworld", "cell": Vector2i(68, 3), "time": DAY},
	"rain": {"area": "reach", "map": "overworld", "at": "forest_1", "rain": true},
	# The village seen from outside (PIX-248): up the road to its gate by day
	# and at night, and its lit windows from the road along its west wall.
	"village_road": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 40), "time": DAY},
	"village_gate_night": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 41), "time": NIGHT},
	"village_west_night": {"area": "reach", "map": "overworld", "cell": Vector2i(34, 47), "time": NIGHT},
	# A country road's wear (PIX-307): the road south from the river to the
	# village, its ruts, the grass on its crown and at its edges, its stones.
	"country_road": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 36), "time": DAY},
	"country_road_night": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 36), "time": NIGHT},
	# The Reach's river at its bridge (PIX-306): its depth, its banks bent
	# off the grid, streaks drifting downstream and foam at the bridge's
	# piles; by day and at night.
	"reach_river": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 32), "time": DAY},
	"reach_river_night": {"area": "reach", "map": "overworld", "cell": Vector2i(48, 32), "time": NIGHT},
	# Things lying on the ground beside the hero (PIX-286): the pouch on the
	# road west of the village where it lies, and a patch of each kind laid
	# round it, half a cell each.
	"drops": {
		"area": "reach", "map": "overworld", "cell": Vector2i(42, 59), "time": DAY,
		"drops": {
			Vector2i(40, 60): "forest_herb", Vector2i(41, 61): "blackiron_ore", Vector2i(43, 61): "ember_shard",
			Vector2i(44, 59): "sea_glass", Vector2i(44, 57): "frost_lily", Vector2i(42, 57): "old_steel",
		},
	},
	"mire": {"area": "regions", "map": "mirefen", "time": DAY},
	# Open ground in the regions (PIX-305): the Mirefen's murk, sedge and
	# puddles, the Frostgate's drifts, Saltmere's and Greyhold's fields; by
	# day and at night.
	"mire_fen": {"area": "regions", "map": "mirefen", "cell": Vector2i(30, 20), "time": DAY},
	"mire_fen_night": {"area": "regions", "map": "mirefen", "cell": Vector2i(30, 20), "time": NIGHT},
	"frostgate": {"area": "regions", "map": "frostgate", "time": DAY},
	"frost_fields": {"area": "regions", "map": "frostgate", "cell": Vector2i(14, 40), "time": DAY},
	"frost_fields_night": {"area": "regions", "map": "frostgate", "cell": Vector2i(14, 40), "time": NIGHT},
	# Lamps by a door and a camp's torches on their stakes (PIX-311): Greyhold's
	# keep by day and at night, its windows lit; the Frostgate's observatory
	# at night.
	"greyhold_keep": {"area": "regions", "map": "greyhold", "cell": Vector2i(36, 15), "time": DAY},
	"greyhold_keep_night": {"area": "regions", "map": "greyhold", "cell": Vector2i(36, 15), "time": NIGHT},
	"frostgate_night": {"area": "regions", "map": "frostgate", "cell": Vector2i(28, 12), "time": NIGHT},
	"coast": {"area": "regions", "map": "saltmere", "cell": Vector2i(33, 27), "time": DAY},
	"saltmere_fields": {"area": "regions", "map": "saltmere", "cell": Vector2i(8, 8), "time": DAY},
	"saltmere_fields_night": {"area": "regions", "map": "saltmere", "cell": Vector2i(8, 8), "time": NIGHT},
	"greyhold_fields": {"area": "regions", "map": "greyhold", "cell": Vector2i(12, 30), "time": DAY},
	"deepwood": {"area": "regions", "map": "deepwood", "time": DAY},
	# The Deepwood's forest, its pines and round trees (PIX-304: from One
	# Land, v0.219, no map grew any).
	"deepwood_trees": {"area": "regions", "map": "deepwood", "cell": Vector2i(44, 10), "time": DAY},
	# The Deepwood as a forest (PIX-309): clumps of trees with their crowns
	# overlapping, undergrowth, the ground dark under the canopy, the light
	# through it by day and fireflies at night; from the glade at its heart.
	"deepwood_forest": {"area": "regions", "map": "deepwood", "cell": Vector2i(30, 20), "time": DAY},
	"deepwood_forest_night": {"area": "regions", "map": "deepwood", "cell": Vector2i(30, 20), "time": NIGHT},
	# Saltmere's sea running on off the map's south edge (PIX-309), from the
	# end of its pier, by day and at night.
	"saltmere_south": {"area": "regions", "map": "saltmere", "cell": Vector2i(31, 29), "time": DAY},
	"saltmere_south_night": {"area": "regions", "map": "saltmere", "cell": Vector2i(31, 29), "time": NIGHT},
	# Still water inland (PIX-306): the Deepwood's dark lake, and the
	# Mirefen's murky pools by a bridge, their lily pads and reeds; by day
	# and at night.
	"deepwood_lake": {"area": "regions", "map": "deepwood", "cell": Vector2i(18, 9), "time": DAY},
	"deepwood_lake_night": {"area": "regions", "map": "deepwood", "cell": Vector2i(18, 9), "time": NIGHT},
	"mire_pool": {"area": "regions", "map": "mirefen", "cell": Vector2i(21, 25), "time": DAY},
	"mire_pool_night": {"area": "regions", "map": "mirefen", "cell": Vector2i(21, 25), "time": NIGHT},
	# The mountain road (PIX-253 step 8): its switchbacks up the ash to the
	# forge in the rock, and the lamp by its door.
	"mountain_road": {"area": "regions", "map": "mountain_road", "cell": Vector2i(17, 8), "time": DAY},
	# Blackiron a mining country (PIX-308): its outcrops worked, timber at
	# their faces, a winch and carts, rails run between them over the
	# scorched ground, spoil heaped by them; by day and at night; and the
	# mountain road's flats scorched at night, their cinders glowing.
	"blackiron_mines": {"area": "regions", "map": "blackiron", "cell": Vector2i(20, 14), "time": DAY},
	"blackiron_mines_night": {"area": "regions", "map": "blackiron", "cell": Vector2i(20, 14), "time": NIGHT},
	"blackiron_rails": {"area": "regions", "map": "blackiron", "cell": Vector2i(38, 25), "time": DAY},
	"mountain_road_night": {"area": "regions", "map": "mountain_road", "cell": Vector2i(17, 8), "time": NIGHT},
	# Paving beyond the village (PIX-307): Greyhold's courtyard flagged, its
	# paths cobbled, by day and at night; the Frostgate's observatory in its
	# flagged yard at the end of a cobbled road.
	# Each settlement beyond Pixelheim its own (PIX-313): Saltmere's
	# fishing hamlet (gables, nets drying, a boat drawn up, the fish stall),
	# Greyhold's cottage in its yard below the keep, the Frostgate's hut
	# snowed in by its woodpile, Blackiron's miners' huts with their lamp,
	# and Morvax's smithy at the top of the mountain road (PIX-312): its
	# chimney smoking, its door aglow; by day and at night.
	"saltmere_hamlet": {"area": "regions", "map": "saltmere", "cell": Vector2i(31, 15), "time": DAY},
	"saltmere_hamlet_night": {"area": "regions", "map": "saltmere", "cell": Vector2i(31, 15), "time": NIGHT},
	"greyhold_cottage": {"area": "regions", "map": "greyhold", "cell": Vector2i(14, 25), "time": DAY},
	"greyhold_cottage_night": {"area": "regions", "map": "greyhold", "cell": Vector2i(14, 25), "time": NIGHT},
	"frost_camp": {"area": "regions", "map": "frostgate", "cell": Vector2i(14, 39), "time": DAY},
	"frost_camp_night": {"area": "regions", "map": "frostgate", "cell": Vector2i(14, 39), "time": NIGHT},
	"frost_caravan": {"area": "regions", "map": "frostgate", "cell": Vector2i(39, 39), "time": DAY},
	"blackiron_camp": {"area": "regions", "map": "blackiron", "cell": Vector2i(25, 18), "time": DAY},
	"blackiron_camp_night": {"area": "regions", "map": "blackiron", "cell": Vector2i(25, 18), "time": NIGHT},
	"morvax_smithy": {"area": "regions", "map": "mountain_road", "cell": Vector2i(17, 7), "time": DAY},
	"morvax_smithy_night": {"area": "regions", "map": "mountain_road", "cell": Vector2i(17, 7), "time": NIGHT},
	"courtyard": {"area": "regions", "map": "greyhold", "cell": Vector2i(36, 20), "time": DAY},
	"courtyard_night": {"area": "regions", "map": "greyhold", "cell": Vector2i(36, 20), "time": NIGHT},
	"frost_road": {"area": "regions", "map": "frostgate", "cell": Vector2i(28, 13), "time": DAY},
	# The marks over the world (PIX-284, PIX-289): on Saltmere's sand the
	# givers' parchment talk marks and Old Wenna's gold one, a letter of
	# Maren's carried to her (`letter`, only for the shot), and the arrow
	# toward the story at the view's edge; on the Frostgate's snow the same,
	# by day and at night.
	"coast_marks": {"area": "regions", "map": "saltmere", "cell": Vector2i(24, 19), "time": DAY, "letter": "letter_wenna"},
	"coast_marks_night": {"area": "regions", "map": "saltmere", "cell": Vector2i(24, 19), "time": NIGHT, "letter": "letter_wenna"},
	"snow_marks": {"area": "regions", "map": "frostgate", "cell": Vector2i(39, 36), "time": DAY},
	"snow_marks_night": {"area": "regions", "map": "frostgate", "cell": Vector2i(39, 36), "time": NIGHT},
	# The ways between maps (PIX-269): the river road running out through
	# the cliffs at the Deepwood pass by day and by night, the Mirefen's way
	# back (high on its east edge since the Reach became one plane), and the
	# road south out through the ridge - bare ground, no post.
	"deepwood_pass": {"area": "ways", "map": "overworld", "cell": Vector2i(91, 33), "time": DAY},
	"deepwood_pass_night": {"area": "ways", "map": "overworld", "cell": Vector2i(91, 33), "time": NIGHT},
	"mire_pass": {"area": "ways", "map": "mirefen", "cell": Vector2i(55, 5), "time": DAY},
	"road_south": {"area": "ways", "map": "overworld", "cell": Vector2i(16, 60), "time": DAY},
	# Come through the pass into the Mirefen: its name on a card, once.
	"place_card": {"area": "ways", "map": "mirefen", "cell": Vector2i(55, 5), "time": DAY, "card": true},
	# Each dungeon's way in, in its setting (PIX-290): the shafts' mine mouth
	# in the cliff, its rails and winch, by day and by night; the sea cave's
	# arch at the cliff's foot by the beach; the Ashen Mountain's gatehouse in
	# the rock; the Kings' Vault's black iron door between its stone kings.
	"mine_mouth": {"area": "ways", "map": "blackiron", "cell": Vector2i(26, 7), "time": DAY},
	"mine_mouth_night": {"area": "ways", "map": "blackiron", "cell": Vector2i(26, 7), "time": NIGHT},
	"sea_cave_mouth": {"area": "ways", "map": "saltmere", "cell": Vector2i(7, 26), "time": DAY},
	"mountain_gate": {"area": "ways", "map": "overworld", "cell": Vector2i(48, 10), "time": DAY},
	"vault_door": {"area": "ways", "map": "mountain_road", "cell": Vector2i(12, 5), "time": DAY},
	# The story's last set pieces (PIX-312), at night, and open (`open`: the
	# gate's promise kept and the dragon freed, for that shot alone): the
	# mountain's gatehouse, its gate up, from the Reach and from the road
	# inside; the Vault's door swung back, glinting.
	"mountain_gate_night": {"area": "ways", "map": "overworld", "cell": Vector2i(48, 10), "time": NIGHT},
	"mountain_gate_open": {"area": "ways", "map": "overworld", "cell": Vector2i(48, 10), "time": DAY, "open": true},
	"mountain_gate_inside": {"area": "ways", "map": "mountain_road", "cell": Vector2i(17, 26), "time": DAY, "open": true},
	"vault_door_night": {"area": "ways", "map": "mountain_road", "cell": Vector2i(12, 5), "time": NIGHT},
	"vault_door_open": {"area": "ways", "map": "mountain_road", "cell": Vector2i(12, 5), "time": DAY, "open": true},
	# The Kings' Vault (PIX-257): its first floor, laid from a seed in the
	# vault's gilded stone, and its last, the Hollow King's hoard.
	"vault": {"area": "dungeon", "map": "vault_1", "time": DAY},
	"vault_hoard": {"area": "dungeon", "map": "vault_5", "cell": Vector2i(46, 11), "time": DAY},
	# Torches on the walls (PIX-291): the shafts' first hall, handcrafted,
	# its torches on the north wall's face, their flames glowing over its top.
	"wall_torches": {"area": "dungeon", "map": "shafts", "cell": Vector2i(34, 5), "time": DAY},
	# The ice cave's frozen lake (PIX-255): ice over the stone, its cracks,
	# polish and glints, frost at its shore, and the cold light it gives.
	"frozen_lake": {"area": "dungeon", "map": "icecave_lake", "cell": Vector2i(30, 14), "time": DAY},
	# The arrow in the sea cave's dark (PIX-284), toward its way out.
	"cave_marks": {"area": "dungeon", "map": "seacave", "cell": Vector2i(24, 18), "time": DAY},
	# Each dungeon as its place (PIX-310), a room and a hall: the sea cave's
	# wet rock and pools of the sea, the shafts' rail line, timber and ore,
	# the cellars' crypt, the ice cave's frost, the Kings' Vault's rugs,
	# banners and gilded walls; and a planned floor's entrance, its own.
	"sea_cave_room": {"area": "dungeon", "map": "seacave", "cell": Vector2i(20, 12), "time": DAY},
	"sea_cave_hall": {"area": "dungeon", "map": "seacave_galleries", "cell": Vector2i(25, 9), "time": DAY},
	"shafts_room": {"area": "dungeon", "map": "shafts_gallery", "cell": Vector2i(19, 15), "time": DAY},
	"shafts_hall": {"area": "dungeon", "map": "shafts", "cell": Vector2i(19, 8), "time": DAY},
	"crypt_room": {"area": "dungeon", "map": "cellars_crypt", "cell": Vector2i(17, 12), "time": DAY},
	"crypt_hall": {"area": "dungeon", "map": "cellars", "cell": Vector2i(19, 17), "time": DAY},
	"ice_cave_room": {"area": "dungeon", "map": "icecave", "cell": Vector2i(20, 7), "time": DAY},
	"ice_cave_hall": {"area": "dungeon", "map": "icecave", "cell": Vector2i(19, 15), "time": DAY},
	"vault_room": {"area": "dungeon", "map": "vault_2", "cell": Vector2i(18, 12), "time": DAY},
	"vault_hall": {"area": "dungeon", "map": "vault_1", "cell": Vector2i(12, 11), "time": DAY},
	"gallery_entrance": {"area": "dungeon", "map": "shafts_gallery", "time": DAY},
	"fight": {"area": "combat", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc"},
	"strike": {"area": "combat", "map": "overworld", "at": "forest_1", "time": DAY, "foe": "orc", "strike": true},
	# A foe noticing the hero on the grass west of the village (PIX-289): its
	# danger mark, caught as it notices (`notice`), and the arrow toward the
	# village's gate (PIX-284); by day and at night.
	"notice": {"area": "combat", "map": "overworld", "cell": Vector2i(28, 47), "time": DAY, "foe": "orc", "notice": true},
	"notice_night": {"area": "combat", "map": "overworld", "cell": Vector2i(28, 47), "time": NIGHT, "foe": "orc", "notice": true},
	# Bosses on the art's own grid (PIX-314): every named monster and Fafnyr
	# as the Night of Bells sizes him in rows beside the hero, held still,
	# wider than play (`bosses`, `zoom`); the Tidecaller beside the hero in
	# its grotto (`named`, in its lair), its name and level over its head;
	# Old Greymaw in his corner of the forest at night; Fafnyr come down on
	# the square on the Night of Bells (`fafnyr`).
	"bosses": {"area": "combat", "map": "overworld", "cell": Vector2i(77, 44), "time": DAY, "bosses": true, "zoom": 2.0},
	"boss_lair": {"area": "combat", "map": "seacave_grotto", "cell": Vector2i(22, 12), "time": DAY, "named": "tidecaller"},
	"boss_night": {"area": "combat", "map": "overworld", "cell": Vector2i(87, 59), "time": NIGHT, "named": "greymaw"},
	"fafnyr_square": {"area": "combat", "map": "town", "cell": Vector2i(35, 28), "time": NIGHT, "fafnyr": true},
	# The map (PIX-266) of a hero who has walked the whole Reach, its list
	# scrolled down to the last waypoint, in Greyhold on the Reach's one page
	# (PIX-269 step 7).
	"map": {"area": "screens", "map": "town", "at": "street", "time": DAY, "chart": "greyhold_keep"},
	# The Saves screen (PIX-302) over the street: two heroes' cards, the
	# chapter and the hours each, and an empty slot (`slots`: the fixture
	# folder read, never written).
	"saves": {"area": "screens", "map": "town", "at": "street", "time": DAY, "slots": "res://test/fixtures/slots_room"},
	# The journal's Post tab (PIX-320): the day's post taken, one piece
	# handed over and its reply to carry back, the rest sealed; over the
	# square by day and at night.
	"post_tab": {"area": "screens", "map": "town", "cell": Vector2i(44, 23), "time": DAY, "post": "tab"},
	"post_tab_night": {"area": "screens", "map": "town", "cell": Vector2i(44, 23), "time": NIGHT, "post": "tab"},
}
## Filming the walk: slowed to a quarter, a picture every WALK_STEP of the
## game's time (thirty a second: two or three of each frame of the walk),
## cropped round the hero this far (art px) each way; the legs of the clip
## as [heading, pictures].
const WALK_SLOW := 0.25
const WALK_STEP := 1.0 / 30.0
const WALK_CROP := Vector2(22, 26)
const WALK_LEGS := [[Vector2.ZERO, 3], [Vector2.RIGHT, 20], [Vector2.LEFT, 12], [Vector2.ZERO, 9], [Vector2.UP, 12], [Vector2.ZERO, 9]]
## The turning walk's legs (PIX-293), keys as a player holds them: a
## diagonal is two keys at once.
const TURN_LEGS := [
	[Vector2.ZERO, 3], [Vector2.DOWN, 12], [Vector2(0.7071068, 0.7071068), 6], [Vector2.RIGHT, 12], [Vector2.ZERO, 9],
	[Vector2.UP, 12], [Vector2(-0.7071068, -0.7071068), 6], [Vector2.LEFT, 12], [Vector2.ZERO, 9],
	[Vector2.DOWN, 12], [Vector2.RIGHT, 12], [Vector2(0.7071068, -0.7071068), 12], [Vector2.UP, 12], [Vector2.ZERO, 9],
]
## Each filmed walk's legs, by the shot's `legs`.
const LEGS := {"walk": WALK_LEGS, "turn": TURN_LEGS}
## The strip of crops: this many across.
const STRIP_COLUMNS := 11
## A clip's frames, in seconds after the rise begins: the ruin, giving way
## in dust as the first courses drop, the roof going up, and standing with
## its confetti, its name and what it brings.
const CLIP_MARKS := [0.1, 0.55, 0.95, 2.1]
## Upper Street: the shop's and the inn's fronts, the street lamps, the hall.
const STREET := Vector2i(40, 13)
## The contact sheet: three across, each shot at half size.
const SHEET_COLUMNS := 3
const SETTLE_SECONDS := 1.2
## A stair's shot (`down`, PIX-256): this long facing it before it asks.
const ASK_AFTER := 0.5
## A foe noticing (`notice`, PIX-289): the picture this long after it does,
## its danger mark up and its hop under way.
const NOTICE_HOLD := 0.2
## Filming (`film`): this many frames, this far apart, into
## <out>/motion/<shot>/NN.png.
const MOTION_FRAMES := 24
const MOTION_STEP := 0.1
## The world's clock at each shot, so the clouds and the wind stand the same
## way every time.
const CLOCK := 40.0
## Frames drawn after a look is put on, before its shot: the canvas is remade
## and the glow's levels filled.
const LOOK_FRAMES := 4

var world: Node
var out_dir := "res://lookbook"
var with_perf := false
var with_motion := false
## Only the shots of these names (none: all), to look at a few quickly: a
## before and after of a handful (PIX-314: the bosses).
var only: PackedStringArray = []
## The shot's foe, to strike while filming.
var _foe: Node
## The bosses' lineup (`bosses`, PIX-314): who stands in it, and how far
## apart, in world pixels: BOSS_ROW across, the hero in the first row's
## middle, the second row below it.
var _lined_up: Array[Node] = []
## The slots a shot with `slots` stood in for, given back after it.
var _slots_kept: SaveSlots
const BOSS_STEP := Vector2(60, 76)
const BOSS_ROW := 9
## Filming a strike: the frames the hero swings on (the second a crit, the
## last one felling it), and what each blow takes.
const STRIKES := [2, 8, 14]
const STAGED_BLOW := 12
## The looks to shoot each scene in (`--looks`); none: the look worn.
var looks: PackedStringArray = []


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Pictures to look at, not the game's: Godot leaves the folder alone.
	FileAccess.open("%s/.gdignore" % out_dir, FileAccess.WRITE)
	# The same picture every time: no first-time hints over the scene, and a
	# hero no foe can fell while a shot is taken or its frames are timed.
	GameState.settings.hints = false
	world.player.invulnerable = true
	# The town at its fullest: every age built, its lamps and roofs up.
	GameState.settlement.town_tier = Town.MAX_TIER
	GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	# Each look's folder ("" is the look worn, straight into out_dir) and its
	# shots so far.
	var folders := {}
	var images := {}
	for look in (looks if not looks.is_empty() else PackedStringArray([""])):
		folders[look] = out_dir if look == "" else "%s/%s" % [out_dir, look]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folders[look]))
		var shots: Array[Image] = []
		images[look] = shots
	# Developer output, not the player's: no words for the translators.
	print("%s %s=%s" % ["LOOK", "look", DesktopLook.look])
	for wanted in only:
		if not SHOTS.has(wanted):
			push_error("lookbook: no shot is called %s (%s)" % [wanted, ", ".join(ordered())])
			return
	var shot_names: PackedStringArray = []
	for shot_name in ordered():
		if not only.is_empty() and not only.has(shot_name):
			continue
		shot_names.append(shot_name)
		var shot: Dictionary = SHOTS[shot_name].duplicate()
		shot["name"] = shot_name
		if shot.has("rise"):
			await _clip(shot, folders, images)
			continue
		_stage(shot)
		if shot.get("down", false):
			await get_tree().create_timer(ASK_AFTER).timeout
			world.interaction.ask_down(world.player_cell + Vector2i.UP)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		if shot.get("notice", false) and is_instance_valid(_foe):
			_foe.notice()
			await get_tree().create_timer(NOTICE_HOLD).timeout
		await drawn()
		for look: String in folders:
			if look != "":
				world.lights.wear(look)
				for frame in LOOK_FRAMES:
					await drawn()
			var image: Image = await DesktopLook.snapshot(self)
			image.save_png("%s/%s.png" % [folders[look], shot["name"]])
			images[look].append(image)
		var line := "%s %s" % ["LOOK", shot["name"]]
		if with_perf:
			line += "  " + await PerfProbe.sample(self, 180)
		print(line)
		if with_motion and shot.get("walk", false):
			await _film_walk(shot["name"], LEGS[shot.get("legs", "walk")])
		elif with_motion:
			await _film(shot["name"], shot.get("strike", false))
		_unstage(shot)
		# A screen a shot opened goes, so the next finds the world its own:
		# gone from the tree before the next is staged, or the HUD it hid
		# came back over the next shot's journal or map (PIX-320).
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
		await get_tree().process_frame
	for look: String in folders:
		sheet(images[look]).save_png("%s/sheet.png" % folders[look])
		FileAccess.open("%s/shots.txt" % folders[look], FileAccess.WRITE).store_string("\n".join(shot_names) + "\n")
		print("%s %s/%s" % ["LOOK", ProjectSettings.globalize_path(folders[look]), "sheet.png"])


## Every shot's name in the sheet's order: by area, as AREAS lists them, and
## in SHOTS' order within an area.
static func ordered() -> PackedStringArray:
	var out: PackedStringArray = []
	for area: String in AREAS:
		for shot_name: String in SHOTS:
			if SHOTS[shot_name]["area"] == area:
				out.append(shot_name)
	return out


## Puts the hero where the shot stands, at its hour, with its foe - the last
## shot's words cleared away.
func _stage(shot: Dictionary) -> void:
	world.messages.clear()
	world.hud.forget_places()
	if shot.get("open", false):
		# The story's ways open, for this shot alone (_unstage): an old
		# save's deepest floor cleared opens the mountain's gate and the
		# Vault's door both (Relics.gate_open, Vault.door_open).
		GameState.progression.cleared_levels.assign([15])
	if shot.has("tier"):
		# The town at an earlier age, for this shot alone (_unstage).
		GameState.settlement.town_tier = int(shot["tier"])
		GameState.settlement.projects.assign(Town.projects_through(int(shot["tier"])))
	GameState.world.steps = shower_by_day() if shot.get("rain", false) else float(shot["time"]) * DayNight.DAY_CYCLE_STEPS
	if shot.has("post"):
		_open_post()
	world.map = world.load_map(shot["map"])
	var at: Vector2i = nearest_walkable(world.map, shot["cell"]) if shot.has("cell") else _cell(world.map, String(shot.get("at", "")))
	world.enter_map(world.map, at)
	# The card naming the place stands over its own shot only.
	if not shot.get("card", false):
		world.hud.forget_places()
	world.folk.keep_hours(true)
	world.lights.time = CLOCK
	if shot.has("foe"):
		var foe: Node = world.foes.spawn_enemy(shot["foe"], world.player_cell + Vector2i(2, 0), "", "", true, false)
		world.player.face(Vector2.RIGHT)
		# One caught as it notices does so just before its picture (run).
		if not shot.get("notice", false):
			foe.notice()
		_foe = foe
	if shot.has("named"):
		var lair := Hunts.lair(Hunts.named(shot["named"]))
		_foe = _named_at(String(shot["named"]), MapView.center(lair))
		world.player.face(Vector2.RIGHT)
	if shot.get("bosses", false):
		_line_up_bosses()
	if shot.get("fafnyr", false):
		_foe = _fafnyr_at(MapView.center(Bells.landing()))
		world.player.face(Vector2.RIGHT)
	if shot.has("zoom"):
		world.camera_rig.camera.zoom = Vector2.ONE * float(shot["zoom"])
	if shot.has("letter"):
		# A letter of Maren's carried, for this shot alone (_unstage).
		GameState.progression.quests[shot["letter"]] = {"progress": 0, "done": false}
		GameState.pack.add_item(shot["letter"])
	if shot.get("down", false):
		# At the top of a room's stair, facing it (PIX-256): the stairs ask
		# once the world has drawn the hero turned (run).
		world.player.face(Vector2.UP)
	for cell: Vector2i in shot.get("drops", {}):
		# Laid as the map lays a patch (MapView.pickup), gone with the visit.
		world.view.ground.add_child(MapView.pickup(ItemIcons.texture(shot["drops"][cell]), cell))
	if shot.get("post", "") == "box":
		world.player.face(Vector2.UP)
	if shot.get("post", "") == "tab":
		# The day's post taken, the first piece handed over (its reply in
		# the satchel), then the journal at its Post page.
		Post.take(GameState.post, GameState.posting.in_box(), GameState.posting.today())
		Post.hand_over(GameState.post, GameState.post.bag[0])
		var journal := preload("res://scripts/journal_screen.gd").new()
		journal.tab = "post"
		world.add_child(journal)
	if shot.has("chart"):
		# The map over a hero who has walked it all, a waypoint chosen.
		Atlas.walk_all(GameState.world.discovered)
		world.open_screen("map")
		for node in world.get_children():
			if node.has_method("show_waypoint"):
				node.show_waypoint(shot["chart"])
	if shot.has("slots"):
		# The saves screen over a folder of fixture slots, for this shot alone.
		_slots_kept = GameState.slots
		GameState.slots = SaveSlots.new(shot["slots"], true)
		world.open_saves()


## What a shot set up for itself alone taken back, so the shots after it
## find the hero as they were: its letter, the town's age.
func _unstage(shot: Dictionary) -> void:
	if shot.get("open", false):
		GameState.progression.cleared_levels.clear()
	if shot.has("tier"):
		GameState.settlement.town_tier = Town.MAX_TIER
		GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	if shot.has("letter"):
		GameState.pack.remove_item(shot["letter"])
		GameState.progression.quests.erase(shot["letter"])
	if shot.has("post"):
		_close_post()
	if shot.has("zoom"):
		world.camera_rig.camera.zoom = Vector2.ONE * CameraRig.ZOOM
	if shot.has("slots"):
		GameState.slots = _slots_kept
	for foe in _lined_up:
		if is_instance_valid(foe):
			foe.queue_free()
	_lined_up.clear()


## What the Post's shots changed (PIX-320), to put back: whether the tin
## was found, Maren's first letter's entry, and whether Saltmere was walked.
var _before_post := {}


## The Pixelheim Post open for a shot alone (PIX-320), as the harness's
## `--post` opens it: Maren's first letter in Wenna's hands and Saltmere
## walked, before the town is drawn (its box on the square).
func _open_post() -> void:
	var first: Dictionary = Letters.all()[0]
	var wenna := Npcs.by_id(String(first["objective"]["to"]), GameState.settlement.settlers)
	_before_post = {
		"tin": GameState.has_seen(Letters.scene_id()),
		"letter": GameState.progression.quests.get(first["id"], {}),
		"walked": GameState.world.discovered.has(String(wenna["mapId"])),
	}
	GameState.mark_seen(Letters.scene_id())
	GameState.progression.quests[first["id"]] = {"progress": 1, "done": true}
	Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(String(wenna["mapId"])), Vector2i(int(wenna["x"]), int(wenna["y"])))


## The Post as it was before its shot: shut, and nothing in it kept.
func _close_post() -> void:
	var first: Dictionary = Letters.all()[0]
	if not _before_post.get("tin", true):
		GameState.progression.story_seen.erase(Letters.scene_id())
	if (_before_post.get("letter", {}) as Dictionary).is_empty():
		GameState.progression.quests.erase(first["id"])
	else:
		GameState.progression.quests[first["id"]] = _before_post["letter"]
	if not _before_post.get("walked", true):
		GameState.world.discovered.erase(String(Npcs.by_id(String(first["objective"]["to"]), GameState.settlement.settlers)["mapId"]))
	GameState.post = PostState.new()


## A named monster held still at `at` (PIX-314): the one in its lair on this
## map, or brought out of it, facing the camera, its level shown as the
## hero beside it would see it.
func _named_at(named_id: String, at: Vector2) -> Node:
	var foe: Node = null
	for mob in get_tree().get_nodes_in_group("mobs"):
		# Not one the last shot's map left going.
		if not mob.dying and not mob.is_queued_for_deletion() and mob.fighter.get("named", "") == named_id:
			foe = mob
	if foe == null:
		foe = world.foes.spawn_named(named_id, Vector2i((at / MapView.TILE).floor()))
	_hold(foe, at)
	return foe


## Still where it is put: no wandering, no noticing, no chase.
func _hold(foe: Node, at: Vector2) -> void:
	foe.position = at
	foe.home = at
	foe.reset_physics_interpolation()
	foe.set_physics_process(false)
	foe.level_tag.visible = true


## Every named monster, and Fafnyr as the Night of Bells sizes him, in rows
## beside the hero, held still facing the camera, their words hidden: how
## big each is drawn, side by side with the hero (PIX-314).
func _line_up_bosses() -> void:
	var origin: Vector2 = world.player.position - Vector2(BOSS_STEP.x * (BOSS_ROW / 2), 0)
	var slots: Array[Vector2] = []
	for slot in BOSS_ROW * 2:
		if slot != BOSS_ROW / 2:
			slots.append(origin + Vector2(BOSS_STEP.x * (slot % BOSS_ROW), BOSS_STEP.y * (slot / BOSS_ROW)))
	var named := Hunts.all()
	for i in named.size():
		var foe := _named_at(String(named[i]["id"]), slots[i])
		_quiet(foe)
		_lined_up.append(foe)
	# The last of the second row, and the room of the one after it.
	var fafnyr := _fafnyr_at((slots[named.size() + 1] + slots[named.size() + 2]) / 2.0)
	_quiet(fafnyr)


## Fafnyr as the Night of Bells brings him down, held still at `at`.
func _fafnyr_at(at: Vector2) -> Node:
	var fafnyr: Node = preload("res://scripts/enemy.gd").new()
	fafnyr.world = world
	fafnyr.fighter = Bells.fafnyr()
	fafnyr.add_to_group("mobs")
	world.actors.add_child(fafnyr)
	_hold(fafnyr, at)
	_lined_up.append(fafnyr)
	return fafnyr


## A lined-up foe's name, level and bars hidden: the lineup is about bodies.
func _quiet(foe: Node) -> void:
	for child in foe.get_children():
		if child is Control:
			(child as Control).visible = false
	foe.level_tag.visible = false


## Waits for a frame drawn and ready to save. While the window is hidden
## (another app full screen over it) the engine draws nothing of its own
## accord and a run would wait forever, so the look book draws the frame
## itself.
func drawn() -> void:
	await DesktopLook.drawn(self)


## The shot as it moves: MOTION_FRAMES frames, MOTION_STEP seconds apart;
## with `strike`, the hero swings at the foe on STRIKES' frames.
func _film(shot_name: String, strike := false) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in MOTION_FRAMES:
		if strike and frame in STRIKES and is_instance_valid(_foe):
			world.player.face(_foe.global_position - world.player.global_position)
			if frame == STRIKES[-1]:
				_foe.fighter["hp"] = 1
			world.player.attack_ready = true
			world.player.attack()
			# Staged: the blow lands on the beat, wherever the foe has stepped.
			_foe.take_hit(STAGED_BLOW, world.player.global_position, null, frame == STRIKES[1])
		await get_tree().create_timer(MOTION_STEP).timeout
		await drawn()
		(await DesktopLook.snapshot(self)).save_png("%s/%02d.png" % [folder, frame])


## The hero's walk (PIX-243), slowed to WALK_SLOW: standing, setting off to
## the right, a stride, turning right round, settling, then up the street
## and settling again (the back's four beats); or another walk's `legs`
## (the turns, PIX-293). Every picture is cropped round the hero into
## <out>/motion/<shot>/NN.png, and all of them, in order and STRIP_COLUMNS
## across, into walk_strip.png beside them.
func _film_walk(shot_name: String, legs: Array = WALK_LEGS) -> void:
	var folder := "%s/motion/%s" % [out_dir, shot_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var crops: Array[Image] = []
	Engine.time_scale = WALK_SLOW
	for leg: Array in legs:
		world.player.scripted_dir = leg[0]
		for picture in int(leg[1]):
			# The game's time, not drawn frames: a window drawing faster than
			# the clock would film the same tick over and over.
			await get_tree().create_timer(WALK_STEP).timeout
			await drawn()
			crops.append(_around_hero(await DesktopLook.snapshot(self)))
	world.player.scripted_dir = Vector2.ZERO
	Engine.time_scale = 1.0
	for index in crops.size():
		crops[index].save_png("%s/%02d.png" % [folder, index])
	_strip(crops).save_png("%s/walk_strip.png" % folder)
	print("%s %s" % ["LOOK", ProjectSettings.globalize_path("%s/walk_strip.png" % folder)])


## The part of `image` round the hero, WALK_CROP art px each way (a little
## more above, for the head).
func _around_hero(image: Image) -> Image:
	var view := get_viewport()
	var shown := image.get_width() / view.get_visible_rect().size.x
	var canvas := view.get_canvas_transform()
	var at: Vector2 = canvas * world.player.global_position * shown
	var half := WALK_CROP * canvas.get_scale().x * shown
	var box := Rect2i(Vector2i(at - Vector2(half.x, half.y * 1.25)), Vector2i(half * 2.0))
	box = box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.convert(Image.FORMAT_RGBA8)
	return crop


## The crops in order, STRIP_COLUMNS across, a dark line between them.
static func _strip(crops: Array[Image]) -> Image:
	var cell := crops[0].get_size() + Vector2i(2, 2)
	var rows := ceili(crops.size() / float(STRIP_COLUMNS))
	var out := Image.create(cell.x * STRIP_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in crops.size():
		var size := crops[index].get_size().min(cell - Vector2i(2, 2))
		out.blit_rect(crops[index], Rect2i(Vector2i.ZERO, size), Vector2i(index % STRIP_COLUMNS * cell.x + 1, index / STRIP_COLUMNS * cell.y + 1))
	return out


## A building rising on the town's tour (PIX-264), in each look: the town
## staged, back from the board with the shot's project built, the tour on
## its way; then CLIP_MARKS' frames from the moment it rises, side by side.
## The tour is closed after, so the next shot finds the world its own.
func _clip(shot: Dictionary, folders: Dictionary, images: Dictionary) -> void:
	for look: String in folders:
		if look != "":
			world.lights.wear(look)
		_stage(shot)
		GameState.reveals.assign(["project:" + String(shot["rise"])])
		world.stage.after_board()
		var rise: RebuildRise = null
		for frame in 600:
			rise = get_tree().get_first_node_in_group(RebuildRise.GROUP) as RebuildRise
			if rise != null and rise.phase != "ruin":
				break
			await drawn()
		var began := GameClock.msec()
		var frames: Array[Image] = []
		for mark: float in CLIP_MARKS:
			var left := mark - (GameClock.msec() - began) / 1000.0
			if left > 0.0:
				await get_tree().create_timer(left).timeout
			await drawn()
			frames.append(await DesktopLook.snapshot(self))
		strip(frames).save_png("%s/%s_strip.png" % [folders[look], shot["name"]])
		frames[-1].save_png("%s/%s.png" % [folders[look], shot["name"]])
		images[look].append(frames[-1])
		for node in world.get_children():
			if node is Screen:
				(node as Screen).close()
		print("%s %s" % ["LOOK", shot["name"]])


## A clip's frames side by side at half size.
static func strip(frames: Array[Image]) -> Image:
	var cell := Vector2i(frames[0].get_width() / 2, frames[0].get_height() / 2)
	var out := Image.create(cell.x * frames.size(), cell.y, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		var small := frames[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index * cell.x, 0))
	return out


## The looks `--looks a,b` names, those the app has (DesktopLook.LOOKS), in
## its order.
static func looks_from(flags: HarnessFlags) -> PackedStringArray:
	var out: PackedStringArray = []
	for look in flags.list("--looks"):
		if DesktopLook.LOOKS.has(look) and not out.has(look):
			out.append(look)
	return out


## The heart of the first shower that falls in full day (Weather).
static func shower_by_day() -> float:
	var steps := 0.0
	for tries in 40:
		steps = Weather.next_shower(steps)
		var hour := fposmod(steps, float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
		if hour > 0.05 and hour < 0.42:
			return steps
		steps += DayNight.DAY_CYCLE_STEPS / 2.0
	return steps


## Where on the map: the square, beside a pack's home, or the arrival.
func _cell(map: MapData, at: String) -> Vector2i:
	var want := map.spawn
	if at == "street":
		want = STREET
	elif at != "":
		for spawn: Dictionary in Bestiary.spawns_on(map.id):
			if spawn["id"] == at:
				want = Vector2i(int(spawn["x"]), int(spawn["y"])) + Vector2i(0, 3)
	return nearest_walkable(map, want)


## The closest cell to `want` the hero can stand on (outward in rings).
static func nearest_walkable(map: MapData, want: Vector2i) -> Vector2i:
	for reach in 12:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell := want + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == reach and map.is_walkable(cell):
					return cell
	return map.spawn


## Every shot at half size, SHEET_COLUMNS across, in order.
static func sheet(images: Array[Image]) -> Image:
	var cell := Vector2i(images[0].get_width() / 2, images[0].get_height() / 2)
	var rows := ceili(images.size() / float(SHEET_COLUMNS))
	var out := Image.create(cell.x * SHEET_COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.07, 0.05, 0.04))
	for index in images.size():
		var small := images[index].duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(index % SHEET_COLUMNS * cell.x, index / SHEET_COLUMNS * cell.y))
	return out
