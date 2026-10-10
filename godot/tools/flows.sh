#!/usr/bin/env bash
# The flows a release must not break (PIX-129), each driven through the
# screenshot harness on a throwaway hero: spawn, portal, chest, shop, craft
# (at the counter, and E at a cauldron or a forge: PIX-234), quest,
# rank-up, fight, death and the inn, saves, and leaving a conversation
# with real key presses (PIX-131), walking without the camera shake
# (PIX-135), a named monster's bounty and board (PIX-156), the choice at
# Morvax's throne (PIX-157), a festival's ring toss (PIX-159), the road to
# Saltmere (PIX-164), its sea cave (PIX-165), the Blackiron mines (PIX-167),
# Greyhold with its cellars (PIX-168) and the Frostgate pass with its ice cave
# (PIX-169), the mountain's gate barred to a new hero (PIX-170) and a depth
# of the Deep Hunt cleared (PIX-161), and a potion brewed before Vex's quest
# was taken still finishing it (PIX-231), a named boss that falls as a
# boss does and holds the way out while it hunts (PIX-232), weak monsters
# running from a far stronger hero without the battle music (PIX-251), the
# same field holding other packs by day and at night (PIX-252), the
# map's waypoint list showing where a waypoint takes you before it does, then
# taking you there (PIX-241), every map found a page of the map and the list
# scrolled to the Reach's last waypoint (PIX-266), hero creation's first night skipped with
# Tab while the name field has the keys (PIX-228), a quest chosen in the
# journal and followed after it closes (PIX-239), what grows on the
# ground somewhere new each day, picked off as you step on it (PIX-250),
# a building rising out of its ruin on the town's tour, a cut with Reduce
# motion (PIX-264), a kill's XP and gold floating up over the foe, a
# chest's gold over the chest, with nothing said of them in the log
# (PIX-245), and the ascension's beats and each rank's look on the hero,
# still with Reduce motion (PIX-244). Every flow leaves its
# picture in godot/flows/<name>.png for a human to look at, and the
# harness's report line must match what the flow promises or the run fails.
#
#   godot/tools/flows.sh            # all of them
#   godot/tools/flows.sh fight die  # just these
#   godot/tools/flows.sh --quiet    # no window, no sound, no pictures
#   FLOWS_EXTRA="--lang fr" godot/tools/flows.sh --quiet   # every flow in French (PIX-196)
#
# --quiet runs every flow headless with the audio off: nothing opens on the
# screen or plays out loud, the report lines are still checked. The motion
# flow measures pixels, so it needs a window and is skipped. A windowed run
# is muted too: its window shows, nothing plays.
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p flows

quiet=0
if [[ ${1:-} == --quiet ]]; then
	quiet=1
	shift
fi

# name | harness arguments | what the report line must show
FLOWS=(
	"spawn|--map town|map=town cell"
	"portal|--map town portal|map=town_"
	"chest|--map town chest|map=town cell=\(79, 4\) .*gold=90.* floats=\+60 [a-z]+ logged=0"
	"shop|--map town_shop shop|map=town_shop"
	"craft|--map town_alchemist shop --tab 2|map=town_alchemist"
	"sleep|--map town_inn night sleep|map=town_inn .*gold=20 .* clock=06:00"
	"station|--map town_alchemist station|open=shop_screen.*tab=Craft"
	"forge|--map town_smith station|open=shop_screen.*tab=Craft"
	"quest|--map town quest|map=town cell"
	"brew|--map town_alchemist brew|map=town_alchemist .*gold=100 "
	# The ascension (PIX-244): held as the old look burns away into the new,
	# its motes and sparks flying; with Reduce motion, held on the name with
	# nothing flying; a fifth rank's whole look on the hero; and a hero's
	# rank worn in the world.
	"rankup|rankup --rank-beat change|open=rankup_screen.* ascension=change motes=[1-9][0-9]* look=trim$"
	"rankup-still|rankup still --rank-beat named|open=rankup_screen.* ascension=named motes=0 look=trim$"
	"rankup-five|--level 17 rankup --rank-beat settled|open=rankup_screen.* ascension=settled motes=0 look=trim\+rim\+weapon\+trail$"
	"ranklook|--map town --level 10|look=trim\+rim$"
	"fight|fight kill|screenshot saved"
	# The kill's XP and gold float up over the fallen foe and the battle log
	# says nothing of them (PIX-245): floats= is what rose, logged= the lines.
	"spoils|fight kill|floats=\+[0-9]+ XP;\+[0-9]+ [a-z]+.* logged=0"
	"die|die|map=town_inn cell=\(2, 3\)"
	"saves|saves|screenshot saved"
	"decline|saves --web-save res://test/fixtures/web_save_v4.txt --keys esc|open=title_screen"
	"talk|--map town talk --keys e,e,e,e,e|open=none"
	"leave|--map town talk --keys e,esc|open=none"
	"mimic|--map mirefen mimic --wait 0.75|map=mirefen cell=\(42, 13\) hp=42"
	"mayor|--map town_hall talk --keys e,e,e|open=town_hall_screen"
	"board|--map town --at 37,22 --keys w,e|open=town_hall_screen"
	"stall|--map town --town-tier 0 --at 35,25 --keys a,e|open=shop_screen"
	"road|--prologue 1|map=overworld cell=\(48, 34\)"
	"dodge|--map town --keys shift --wait 0.4|map=town cell=\(40, 33\)"
	"hunt|--map overworld --at 70,40 fight slay --foe greymaw --wait 0.3|map=overworld .*gold=160"
	"rebuilt|--map town --town-tier 2 rebuilt fades|open=reveal_screen.* dark=0"
	# A building rises out of its ruin at its stop on the tour, never over a
	# dark screen (PIX-264); with Reduce motion the ruin simply cuts to it.
	"rise|--map town --rise odos_store fades --wait 1.6|open=reveal_screen.* dark=0 rise=built"
	"rise-still|--map town --rise odos_store still --wait 0.8|open=reveal_screen.* rise=built"
	"bossfell|--map icecave fight slay --foe rimefang --wait 0.3|map=icecave .* fell=1"
	"noescape|--map icecave fight --foe rimefang flee|map=icecave "
	# A hero far above the forest's slimes (PIX-251): they run instead of
	# charging, and the music stays the place's. At play zoom: a quiet run's
	# camera otherwise sees a few tiles, and a monster notices only on screen.
	"fright|--map overworld --at 59,34 --zoom 4 --level 20 --wait 3|map=overworld .* fled=[1-9][0-9]* music=world"
	# The same field by day and at night (PIX-252): the forest's slimes,
	# goblins and wolves by day; after dark the goblins asleep by their fire,
	# and a second wolf pack and the walking dead out among them.
	"field-day|--map overworld --at 67,46|map=overworld cell=\\(67, 46\\).* packs=slime,goblin,wolf$"
	"field-night|--map overworld --at 67,46 night|map=overworld cell=\\(67, 46\\).* packs=slime,goblin:asleep,wolf,wolf,skeleton$"
	# Night falling while the hero watches the goblins' camp: nothing changes
	# on the screen - the goblins stay up, the wolves whose home is in view
	# wait - and the dead come out off it.
	"nightfall|--map overworld --at 79,43 --zoom 4 nightfall|map=overworld cell=\\(79, 43\\).* packs=slime,goblin,wolf,skeleton$"
	"bounty|--map town --at 43,22 --cleared 4 --keys w,e|open=bounty_screen"
	"throne|--map town --cleared 15 --seen maren_confession throne --keys s,e --wait 0.5|open=reveal_screen"
	"festival|--map town --town-tier 2 --at 43,27 festival --keys w,e,e,e|open=ring_toss_screen"
	"coast|--map overworld --at 16,61 --walk d,d,d --wait 0.4|map=saltmere"
	# Up the path into the sea cave's mouth (PIX-269: its post stands beside it).
	"seacave|--map saltmere --at 6,24 --walk u --wait 0.4|map=seacave"
	"mines|--map overworld --at 2,20 --walk l,l,l --wait 0.4|map=blackiron"
	"shafts|--map blackiron --at 26,5 --walk u --wait 0.4|map=shafts"
	"castle|--map overworld --at 93,15 --walk r,r,r --wait 0.4|map=greyhold"
	"cellars|--map greyhold --at 37,13 --walk u --wait 0.4|map=cellars"
	"pass|--map overworld --at 68,2 --walk u,u,u --wait 0.4|map=frostgate"
	"icecave|--map frostgate --at 27,7 --walk u --wait 0.4|map=icecave"
	"gate|--map overworld --at 48,8 --walk u,u --wait 0.3|map=overworld cell=\\(48, 7\\).*open=none"
	"deep|--floor 16 clear --wait 0.3|map=floor_16"
	# What grows on the ground moves with the days (PIX-250): two days, two
	# sets of cells, and one of the first day's picked as the hero steps on it.
	# (The roads to the ways on, PIX-269, took some of the ash's and the
	# marsh's ground: patches never grow on a road.)
	"patches|--map overworld --day 2|day=2 patches=11,14;14,36;30,57;31,43;34,24;63,39;66,52;75,45$"
	"regrown|--map overworld --day 3|day=3 patches=17,41;18,34;24,51;29,12;50,16;77,44;79,53;86,36$"
	"forage|--map overworld --day 2 --at 75,46 --walk u|cell=\\(75, 45\\).* day=2 patches=11,14;14,36;30,57;31,43;34,24;63,39;66,52$"
	"dawn|--map town --prologue 5 --at 11,8 --keys w,e,e,e,e,e --wait 1.5|open=dawn_screen"
	"motion|--map town motion|backsteps=[01]$"
	"firstnight|create --keys tab|open=create_screen.*firstnight=skip"
	"hounds|--map town --prologue 6|night=6 mobs=2"
	"embers|--map town --prologue 9|night=9 mobs=3"
	# The waypoint chosen on the map is the one shown, and E goes there (PIX-241).
	"waypoint|--map town waypoints --keys m,s,s|open=map_screen.*dest=mountain_gate"
	"travel|--map town waypoints --keys m,s,e|map=overworld cell=\\(48, 40\\).*open=none"
	# Every map found is a page of the map, the next one round the Reach
	# turned to with its waypoint chosen (PIX-266).
	"atlas|--map town waypoints --keys m,d|open=map_screen.*dest=saltmere_hamlet page=saltmere"
	# The journal's fourth thread (the slimes, under the story's three) chosen,
	# E follows it, and it's still followed once the journal closes (PIX-239).
	"follow|--map town journal --keys s,s,s,e,esc|open=none .*tracked=slime_trouble"
	# Every screen fits the canvas in French, the longest language (PIX-258):
	# the harness's `overflow` counts pieces running off the screen.
	"fit-title|title overflow --lang fr|open=title_screen.*overflow=0"
	"fit-create|create overflow --lang fr|open=create_screen.*overflow=0"
	# Its English twin (PIX-228): the setting's card and Begin's row laid out
	# in the other words.
	"fit-create-en|create overflow --lang en|open=create_screen.*overflow=0"
	"fit-whatsnew|title whatsnew overflow --lang fr|overflow=0"
	"fit-saves|--map town --keys esc,s,e overflow --lang fr|open=saves_screen.*overflow=0"
	"fit-webhero|saves --web-save res://test/fixtures/web_save_v4.txt overflow --lang fr|open=saves_screen.*overflow=0"
	"fit-pause|--map town --keys esc overflow --lang fr|open=pause_screen.*overflow=0"
	"fit-options|--map town --keys esc,s,s,e overflow --lang fr|overflow=0"
	"fit-map|--map town waypoints worldmap overflow --lang fr|open=map_screen.*overflow=0"
	"fit-travel|--map town waypoints --keys m,s,s,s,s overflow --lang fr|open=map_screen.*overflow=0 dest=mirefen_pass"
	# The list scrolled to its last waypoint, on Greyhold's page (PIX-266).
	"fit-atlas|--map town charted --keys m,w overflow --lang fr|open=map_screen.*overflow=0 dest=greyhold_keep page=greyhold"
	"fit-pack|--map town --keys i overflow --lang fr|open=inventory_screen.*overflow=0"
	"fit-journal|--map town --keys q overflow --lang fr|open=journal_screen.*overflow=0"
	# A hero mid-game (PIX-239): every group, a bounty followed at the bottom
	# of the list; its English twin; Liane's ten pages; the feats.
	"fit-journal-full|--map town journal --cleared 4 --keys w,e overflow --lang fr|open=journal_screen.*overflow=0 tracked=drowned_knight"
	"fit-journal-en|--map town journal --cleared 4 --keys w,e overflow --lang en|open=journal_screen.*overflow=0 tracked=drowned_knight"
	"fit-journal-pages|--map town journal --tab pages --cleared 15 overflow --lang fr|open=journal_screen.*overflow=0"
	"fit-journal-feats|--map town journal --tab feats overflow --lang fr|open=journal_screen.*overflow=0"
	"fit-skills|--map town --keys k overflow --lang fr|open=skills_screen.*overflow=0"
	"fit-stats|--map town --keys c overflow --lang fr|open=stats_screen.*overflow=0"
	"fit-codex|--map town --keys b overflow --lang fr|open=codex_screen.*overflow=0"
	"fit-shop|--map town_shop shop overflow --lang fr|open=shop_screen.*overflow=0"
	"fit-craft|--map town_alchemist shop --tab 2 overflow --lang fr|open=shop_screen.*overflow=0"
	"fit-refusal|--map town_alchemist station --keys e overflow --lang fr|open=shop_screen.*tab=Craft.*overflow=0"
	"fit-rankup|--map town rankup --rank-beat unlocks overflow --lang fr|open=rankup_screen.*overflow=0"
	"fit-hall|--map town_hall talk --keys e,e,e overflow --lang fr|open=town_hall_screen.*overflow=0"
	"fit-bounty|--map town --at 43,22 --cleared 4 --keys w,e overflow --lang fr|open=bounty_screen.*overflow=0"
)

failed=0
for flow in "${FLOWS[@]}"; do
	IFS="|" read -r name args expect <<<"$flow"
	if [[ $# -gt 0 && ! " $* " == *" $name "* ]]; then
		continue
	fi
	if [[ $quiet == 1 && $name == motion ]]; then
		printf "skip  %-7s needs a window\n" "$name"
		continue
	fi
	rm -f screenshot.png
	# shellcheck disable=SC2086 # the arguments are meant to split
	# A watchdog: a run that never quits fails instead of stalling the rest.
	if [[ $quiet == 1 ]]; then
		output=$(perl -e 'alarm 60; exec @ARGV' godot --headless --audio-driver Dummy --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
	else
		output=$(perl -e 'alarm 60; exec @ARGV' godot --audio-driver Dummy --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
	fi
	report=$(grep "screenshot saved" <<<"$output")
	# Smooth walking is timed frame by frame, and the festival's and the
	# board's conversations by the clock: a long run's load can hitch one,
	# so they get a second try and only a real regression fails.
	if [[ " motion festival board " == *" $name "* ]] && ! grep -qE "$expect" <<<"$report"; then
		rm -f screenshot.png
		# shellcheck disable=SC2086
		if [[ $quiet == 1 ]]; then
			output=$(perl -e 'alarm 60; exec @ARGV' godot --headless --audio-driver Dummy --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
		else
			output=$(perl -e 'alarm 60; exec @ARGV' godot --audio-driver Dummy --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
		fi
		report=$(grep "screenshot saved" <<<"$output")
	fi
	# A script error fails the flow even when the report looks right: a broken
	# map build once logged errors on every map but the town while the report
	# line stayed clean.
	errors=$(grep -m1 "SCRIPT ERROR" <<<"$output")
	if [[ -n "$errors" ]]; then
		failed=1
		printf "FAIL  %-7s %s\n" "$name" "$errors"
	elif [[ ( $quiet == 1 || -f screenshot.png ) ]] && grep -qE "$expect" <<<"$report"; then
		[[ -f screenshot.png ]] && mv screenshot.png "flows/$name.png"
		printf "ok    %-7s %s\n" "$name" "${report#screenshot saved; }"
	else
		failed=1
		printf "FAIL  %-7s expected /%s/, got: %s\n" "$name" "$expect" "${report:-no report}"
	fi
done
exit $failed
