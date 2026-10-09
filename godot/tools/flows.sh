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
# boss does and holds the way out while it hunts (PIX-232), the map's
# waypoint list showing where a waypoint takes you before it does, then
# taking you there (PIX-241), and hero creation's first night skipped with
# Tab while the name field has the keys (PIX-228). Every flow leaves its
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
# flow measures pixels, so it needs a window and is skipped.
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
	"chest|--map town chest|map=town cell=\(79, 4\) .*gold=90"
	"shop|--map town_shop shop|map=town_shop"
	"craft|--map town_alchemist shop --tab 2|map=town_alchemist"
	"station|--map town_alchemist station|open=shop_screen.*tab=Craft"
	"forge|--map town_smith station|open=shop_screen.*tab=Craft"
	"quest|--map town quest|map=town cell"
	"brew|--map town_alchemist brew|map=town_alchemist .*gold=100 "
	"rankup|rankup|screenshot saved"
	"fight|fight kill|screenshot saved"
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
	"bossfell|--map icecave fight slay --foe rimefang --wait 0.3|map=icecave .* fell=1"
	"noescape|--map icecave fight --foe rimefang flee|map=icecave "
	"bounty|--map town --at 43,22 --cleared 4 --keys w,e|open=bounty_screen"
	"throne|--map town --cleared 15 --seen maren_confession throne --keys s,e --wait 0.5|open=reveal_screen"
	"festival|--map town --town-tier 2 --at 43,27 festival --keys w,e,e,e|open=ring_toss_screen"
	"coast|--map overworld --at 16,61 --walk d,d,d --wait 0.4|map=saltmere"
	"seacave|--map saltmere --at 7,23 --walk l --wait 0.4|map=seacave"
	"mines|--map overworld --at 2,20 --walk l,l,l --wait 0.4|map=blackiron"
	"shafts|--map blackiron --at 26,5 --walk u --wait 0.4|map=shafts"
	"castle|--map overworld --at 93,15 --walk r,r,r --wait 0.4|map=greyhold"
	"cellars|--map greyhold --at 37,13 --walk u --wait 0.4|map=cellars"
	"pass|--map overworld --at 68,2 --walk u,u,u --wait 0.4|map=frostgate"
	"icecave|--map frostgate --at 27,7 --walk u --wait 0.4|map=icecave"
	"gate|--map overworld --at 48,8 --walk u,u --wait 0.3|map=overworld cell=\\(48, 7\\).*open=none"
	"deep|--floor 16 clear --wait 0.3|map=floor_16"
	"dawn|--map town --prologue 5 --at 11,8 --keys w,e,e,e,e,e --wait 1.5|open=dawn_screen"
	"motion|--map town motion|backsteps=[01]$"
	"firstnight|create --keys tab|open=create_screen.*firstnight=skip"
	"hounds|--map town --prologue 6|night=6 mobs=2"
	"embers|--map town --prologue 9|night=9 mobs=3"
	# The waypoint chosen on the map is the one shown, and E goes there (PIX-241).
	"waypoint|--map town waypoints --keys m,s,s|open=map_screen.*dest=mountain_gate"
	"travel|--map town waypoints --keys m,s,e|map=overworld cell=\\(48, 40\\).*open=none"
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
	"fit-pack|--map town --keys i overflow --lang fr|open=inventory_screen.*overflow=0"
	"fit-journal|--map town --keys q overflow --lang fr|open=journal_screen.*overflow=0"
	"fit-skills|--map town --keys k overflow --lang fr|open=skills_screen.*overflow=0"
	"fit-stats|--map town --keys c overflow --lang fr|open=stats_screen.*overflow=0"
	"fit-codex|--map town --keys b overflow --lang fr|open=codex_screen.*overflow=0"
	"fit-shop|--map town_shop shop overflow --lang fr|open=shop_screen.*overflow=0"
	"fit-craft|--map town_alchemist shop --tab 2 overflow --lang fr|open=shop_screen.*overflow=0"
	"fit-refusal|--map town_alchemist station --keys e overflow --lang fr|open=shop_screen.*tab=Craft.*overflow=0"
	"fit-rankup|--map town rankup overflow --lang fr|open=rankup_screen.*overflow=0"
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
		output=$(perl -e 'alarm 60; exec @ARGV' godot --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
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
			output=$(perl -e 'alarm 60; exec @ARGV' godot --path . -- --screenshot $args ${FLOWS_EXTRA:-} 2>&1)
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
