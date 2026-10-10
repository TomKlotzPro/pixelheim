#!/usr/bin/env bash
# The flows a release must not break (PIX-129), each driven through the
# screenshot harness on a throwaway hero: spawn, portal, chest, shop, craft
# (at the counter, and E at a cauldron or a forge: PIX-234), quest,
# rank-up, fight, death and the inn, saves, and leaving a conversation
# with real key presses (PIX-131), walking without the camera shake
# (PIX-135), a named monster's bounty and board (PIX-156), the choice at
# Morvax's throne (PIX-157), a festival's ring toss (PIX-159), the road to
# Saltmere (PIX-164), its sea cave (PIX-165), the Blackiron mines (PIX-167),
# the Mirefen and Deepwood passes open in the cliffs, each place named on a
# card as the hero comes to it (PIX-269),
# Greyhold with its cellars (PIX-168) and the Frostgate pass with its ice cave
# (PIX-169), each down the stair of the room behind a door, which asks first
# (PIX-256), the mountain's gate barred to a new hero (PIX-170) and a depth
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
#   godot/tools/flows.sh            # all of them, several at a time
#   godot/tools/flows.sh fight die  # just these
#   godot/tools/flows.sh --quiet    # no window, no sound, no pictures
#   godot/tools/flows.sh -j 1       # one at a time
#   godot/tools/flows.sh --boot     # every map booted headless, by day and at night
#   FLOWS_EXTRA="--lang fr" godot/tools/flows.sh --quiet   # every flow in French (PIX-196)
#
# --quiet runs every flow headless with the audio off: nothing opens on the
# screen or plays out loud, the report lines are still checked. The motion
# flow measures pixels, so it needs a window and is skipped. A windowed run
# is muted too: its window shows, nothing plays.
#
# The flows run side by side (PIX-270), -j at a time (the machine's cores
# less two by default); each prints, in the flows' order, as the ones before
# it are done, with its time, and the five slowest close the run. A flow is
# one Godot that boots and quits, so most of a lone run's time was the
# machine waiting on a single core. Each run keeps its picture, its output
# and its log in its own folder (godot/flows/runs/<name>/), so no two share a
# file: the harness saves its picture where `--shot` says, and Godot logs
# where `--log-file` says. A harness run reads the player's settings but
# never writes them (GameSettings.read_only) nor a save (slot 0), and only a
# windowed run uses Godot's shader cache, which once warm it only reads:
# there's nothing else they could race on. In a window, the motion flow
# walks alone after the rest (it times frames), and each window stands a
# little apart from the others: macOS stops drawing a window that another
# one covers.
#
# --boot boots every map the game can stand in (PIX-270): each map in
# assets/maps, the village at each of its ages, the house at each of its
# tiers, every floor of the dungeons and the Deep Hunt's first depths down
# to its first warden, each by day and at night, headless. GUT never loads
# the world's scripts, so a script that breaks only there fails here. Any
# run fails on a SCRIPT ERROR or a Parse Error in its output.
#
# Under GitHub Actions the results also go to the job's summary as a table,
# and each failure as an error on the run (PIX-271).
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p flows

quiet=0
boot=0
jobs=""
only=""
while [[ $# -gt 0 ]]; do
	case $1 in
		--quiet) quiet=1 ;;
		--boot) boot=1 quiet=1 ;;
		-j) jobs=${2:-} && shift ;;
		-j*) jobs=${1#-j} ;;
		*) only+=" $1" ;;
	esac
	shift
done
if [[ -z $jobs ]]; then
	cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 3)
	jobs=$((cores > 3 ? cores - 2 : 1))
fi
case $jobs in
	"" | *[!0-9]* | 0)
		echo "flows.sh: -j takes a number of flows to run at once" >&2
		exit 2
		;;
esac
# A run that never quits is killed after this many seconds (a watchdog).
watchdog=${FLOWS_WATCHDOG:-60}

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
	# Up the path into the sea cave's mouth (PIX-269).
	"seacave|--map saltmere --at 6,24 --walk u --wait 0.4|map=seacave"
	# Out through the parted cliffs (PIX-269: no cave mouth, no post), and the
	# place come to named on its card.
	"mirepass|--map overworld --at 2,32 --walk l,l,l --wait 0.4 --lang en|map=mirefen .*card=The Mirefen"
	"woodpass|--map overworld --at 93,33 --walk r,r,r --wait 0.4 --lang en|map=deepwood .*card=The Deepwood"
	"mines|--map overworld --at 2,20 --walk l,l,l --wait 0.4|map=blackiron"
	"shafts|--map blackiron --at 26,5 --walk u --wait 0.4|map=shafts"
	"castle|--map overworld --at 93,15 --walk r,r,r --wait 0.4|map=greyhold"
	# A house opens onto a room, and the cave is down its stair (PIX-256): the
	# keep's door into Captain Hale's hall; the stair asks, and the hero waits
	# at the top; going down takes them to the cellars, staying keeps them in
	# the hall; and the cellars' stairs lead back up into the hall.
	"keep|--map greyhold --at 37,13 --walk u --wait 0.4|map=keep "
	"keep-ask|--map keep --at 13,7 --walk u,u|map=keep cell=\\(13, 6\\).*open=dialogue_box"
	"cellars|--map keep --at 13,7 --walk u,u --keys s,e --wait 0.4|map=cellars cell=\\(4, 27\\).*open=none"
	"keep-stay|--map keep --at 13,7 --walk u,u --keys s,s,e --wait 0.3|map=keep cell=\\(13, 6\\).*open=none"
	"keep-up|--map cellars --at 4,28 --walk l --wait 0.4|map=keep "
	"pass|--map overworld --at 68,2 --walk u,u,u --wait 0.4|map=frostgate"
	# The observatory's door into Liane's room, down her stair to the ice
	# cave, and back up into her room (PIX-256).
	"observatory|--map frostgate --at 27,7 --walk u --wait 0.4|map=observatory "
	"icecave|--map observatory --at 13,7 --walk u,u --keys s,e --wait 0.4|map=icecave cell=\\(4, 25\\).*open=none"
	"observatory-up|--map icecave --at 4,26 --walk l --wait 0.4|map=observatory "
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
	# Every slot full (PIX-230): a full slot's line widened the window off
	# the right of the screen in French, which empty slots never showed; and
	# a web hero with a long name to bring across, in both languages.
	"fit-saves-full|--map town saves --slots res://test/fixtures/slots overflow --lang fr|open=saves_screen.*overflow=0"
	"fit-saves-full-en|--map town saves --slots res://test/fixtures/slots overflow --lang en|open=saves_screen.*overflow=0"
	"fit-webhero-full|saves --slots res://test/fixtures/slots --web-save res://test/fixtures/slots/slot_1.json overflow --lang fr|open=saves_screen.*overflow=0"
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

# Every map the game can stand in, as flows (--boot), from the game's own
# data, so a new map is checked without a line here: each map file (a house
# tier is its map's @n variant), the village at each age, the dungeons'
# floors, and the Deep Hunt's depths down to its first warden (its twists,
# its elites, the warden). Each one by day and at night; the report must
# name the map it booted on.
boot_flows() {
	python3 - <<'PY'
import glob, json, os


def boot(name, args, map_id):
    print(f"{name}|{args}|map={map_id} cell")
    print(f"{name}-night|{args} night|map={map_id} cell")


for path in sorted(glob.glob("assets/maps/*.json")):
    with open(path) as file:
        if "tiles" not in json.load(file):
            continue  # interactables.json: what stands on the maps
    map_id, _, tier = os.path.basename(path)[: -len(".json")].partition("@")
    if tier:
        boot(f"{map_id}-tier{tier}", f"--map {map_id} --house-tier {tier}", map_id)
    else:
        boot(map_id, f"--map {map_id}", map_id)
with open("assets/data/town.json") as file:
    for age in range(len(json.load(file)["tiers"])):
        boot(f"town-age{age}", f"--map town --town-tier {age}", "town")
with open("assets/data/combat.json") as file:
    combat = json.load(file)
floors = sorted({level for dungeon in combat["dungeons"].values() for level in dungeon["floors"]})
deep = [len(combat["levels"]) + depth for depth in range(1, combat["deepHunt"]["bossEvery"] + 1)]
for level in floors + deep:
    boot(f"floor{level}", f"--floor {level}", f"floor_{level}")
PY
}
if [[ $boot == 1 ]]; then
	FLOWS=()
	while IFS= read -r flow; do
		FLOWS+=("$flow")
	done < <(boot_flows)
	if [[ ${#FLOWS[@]} -lt 40 ]]; then
		echo "flows.sh: the maps weren't found in the data" >&2
		exit 2
	fi
fi

# Smooth walking is timed frame by frame, and the festival's and the board's
# conversations by the clock: a long run's load can hitch one, so they get a
# second try and only a real regression fails.
retried=" motion festival board "
# Walks alone, after the rest: frames timed while other runs share the
# machine would measure the machine.
alone=" motion "

# Each run's own folder: its picture, its output, its log and its result
# (the boot check's apart: its maps share names with flows).
runs="$PWD/flows/$([[ $boot == 1 ]] && echo boot || echo runs)"

# The time, and the seconds since one (to a tenth): bash 3.2 has no clock
# finer than a second.
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
since() { perl -MTime::HiRes=time -e 'printf "%.1f", time - $ARGV[0]' "$1"; }

# One Godot run of a flow, in job slot $3, its output in its folder's
# output.txt. A watchdog: a run that never quits fails instead of stalling
# the rest.
run_godot() {
	local dir=$1 args=$2 slot=$3 godot watcher ran
	local window=(--headless)
	if [[ $quiet == 0 ]]; then
		# Each slot's window a little down and right of the one before:
		# all of them on top, none of them covered whole.
		window=(--position "$((40 + slot * 48)),$((60 + slot * 36))")
	fi
	# shellcheck disable=SC2086 # the arguments are meant to split
	perl -e "alarm $watchdog; exec @ARGV" godot "${window[@]}" --audio-driver Dummy --log-file "$dir/godot.log" --path . -- --screenshot $args --shot "$dir/shot.png" ${FLOWS_EXTRA:-} >"$dir/output.txt" 2>&1 &
	godot=$!
	# A script that doesn't parse leaves Godot on an empty scene until the
	# watchdog: every run would wait out its minute. It has failed, so it
	# stops as soon as it says so.
	while sleep 0.5; do
		grep -q "Parse Error" "$dir/output.txt" && kill -9 "$godot"
	done >/dev/null 2>&1 &
	watcher=$!
	wait "$godot" 2>/dev/null
	ran=$?
	kill "$watcher" 2>/dev/null
	wait "$watcher" 2>/dev/null
	return $ran
}

# Runs flow $1 (its index in FLOWS) in job slot $2 and leaves its result in
# its folder: status|name|seconds|line, written whole as its last act.
run_flow() {
	local name args expect
	IFS="|" read -r name args expect <<<"${FLOWS[$1]}"
	local dir="$runs/$name" status=ok line start ran output report errors
	mkdir -p "$dir"
	start=$(now)
	run_godot "$dir" "$args" "$2"
	ran=$?
	output=$(<"$dir/output.txt")
	report=$(grep "screenshot saved" <<<"$output")
	if [[ $retried == *" $name "* ]] && ! grep -qE "$expect" <<<"$report"; then
		rm -f "$dir/shot.png"
		run_godot "$dir" "$args" "$2"
		ran=$?
		output=$(<"$dir/output.txt")
		report=$(grep "screenshot saved" <<<"$output")
	fi
	# 128 + SIGALRM: the watchdog's.
	if [[ $ran == 142 && -z $report ]]; then
		report="none: the watchdog stopped it after ${watchdog}s"
	fi
	# A script error fails the flow even when the report looks right: a broken
	# map build once logged errors on every map but the town while the report
	# line stayed clean.
	errors=$(grep -m1 -E "SCRIPT ERROR|Parse Error" <<<"$output")
	if [[ -n $errors ]]; then
		status=FAIL
		line=$errors
	elif [[ ($quiet == 1 || -f $dir/shot.png) ]] && grep -qE "$expect" <<<"$report"; then
		[[ -f $dir/shot.png ]] && mv "$dir/shot.png" "flows/$name.png"
		line=${report#screenshot saved; }
	else
		status=FAIL
		line="expected /$expect/, got: ${report:-no report}"
	fi
	printf "%s|%s|%s|%s\n" "$status" "$name" "$(since "$start")" "$line" >"$dir/result.part"
	mv "$dir/result.part" "$dir/result"
}

# The flows asked for, by index (all of them when none is named).
picked=()
for word in $only; do
	known=0
	for flow in "${FLOWS[@]}"; do
		[[ ${flow%%|*} == "$word" ]] && known=1
	done
	if [[ $known == 0 ]]; then
		echo "flows.sh: no flow is called $word" >&2
		exit 2
	fi
done
for i in "${!FLOWS[@]}"; do
	if [[ -z $only || "$only " == *" ${FLOWS[i]%%|*} "* ]]; then
		picked+=("$i")
	fi
done
count=${#picked[@]}
# The last run's results go first: a result in a flow's folder is this run's.
for i in ${picked[@]+"${picked[@]}"}; do
	rm -rf "${runs:?}/${FLOWS[i]%%|*}"
done

failed=0
printed=0
times=()
started=$(now)
rows=""
pid_of=()
slot_pid=()

# Prints the results that are in, in the flows' order: each waits for the
# ones before it.
flush() {
	local k name dir status took line
	while [[ $printed -lt $count ]]; do
		k=$printed
		name=${FLOWS[${picked[k]}]%%|*}
		dir="$runs/$name"
		if [[ ! -f $dir/result ]]; then
			# Still running, or never got to say: a run killed outright.
			if [[ -z ${pid_of[k]:-} ]] || kill -0 "${pid_of[k]}" 2>/dev/null || [[ -f $dir/result ]]; then
				return
			fi
			mkdir -p "$dir"
			printf "FAIL|%s|0|the run ended without a result\n" "$name" >"$dir/result"
		fi
		IFS="|" read -r status name took line <"$dir/result"
		printed=$((printed + 1))
		if [[ $status == skip ]]; then
			printf "skip  %-7s %s\n" "$name" "$line"
			continue
		fi
		printf "%-5s %-7s %5ss  %s\n" "$status" "$name" "$took" "$line"
		times+=("$took $name")
		rows+="| $status | $name | $took s | \`${line//|/\\|}\` |"$'\n'
		if [[ $status == FAIL ]]; then
			failed=1
			if [[ -n ${GITHUB_ACTIONS:-} ]]; then
				echo "::error title=flow $name failed::$line"
			fi
		fi
	done
}

# The first free job slot, in $slot, printing what finished while it waits.
free_slot() {
	local s
	while :; do
		for ((s = 0; s < jobs; s++)); do
			if [[ -z ${slot_pid[s]:-} ]] || ! kill -0 "${slot_pid[s]}" 2>/dev/null; then
				slot=$s
				return
			fi
		done
		flush
		sleep 0.1
	done
}

# Waits for every flow running, printing them as they finish.
drain() {
	local s busy=1
	while [[ $busy == 1 ]]; do
		flush
		busy=0
		for ((s = 0; s < jobs; s++)); do
			if [[ -n ${slot_pid[s]:-} ]] && kill -0 "${slot_pid[s]}" 2>/dev/null; then
				busy=1
			fi
		done
		[[ $busy == 1 ]] && sleep 0.1
	done
	wait
	flush
}

# Starts the flow at position $1 of the picked ones in a free slot.
launch() {
	local slot
	free_slot
	run_flow "${picked[$1]}" "$slot" &
	slot_pid[slot]=$!
	pid_of[$1]=$!
}

later=()
for ((k = 0; k < count; k++)); do
	name=${FLOWS[${picked[k]}]%%|*}
	if [[ $alone == *" $name "* ]]; then
		if [[ $quiet == 1 ]]; then
			mkdir -p "$runs/$name"
			printf "skip|%s|0|needs a window\n" "$name" >"$runs/$name/result"
		else
			later+=("$k")
		fi
		continue
	fi
	launch "$k"
done
drain
for k in ${later[@]+"${later[@]}"}; do
	launch "$k"
	drain
done

took=$(since "$started")
title=$([[ $boot == 1 ]] && echo "Boot check" || echo "Release flows")
verdict=$([[ $failed == 1 ]] && echo "FAILED" || echo "all ok")
echo "$title: ${#times[@]} in ${took}s, $jobs at a time: $verdict"
if [[ ${#times[@]} -gt 0 ]]; then
	echo "slowest:"
	printf "%s\n" "${times[@]}" | LC_ALL=C sort -rn | head -5 | while read -r seconds name; do
		printf "  %6ss  %s\n" "$seconds" "$name"
	done
fi
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
	{
		echo "### $title: $verdict"
		echo
		echo "${#times[@]} runs in ${took} s, $jobs at a time."
		echo
		failures=$(grep "^| FAIL " <<<"$rows")
		if [[ -n $failures ]]; then
			echo "| | Failed | Time | Why |"
			echo "|---|---|---|---|"
			echo "$failures"
			echo
		fi
		echo "<details><summary>Every run</summary>"
		echo
		echo "| | Run | Time | Report |"
		echo "|---|---|---|---|"
		printf "%s" "$rows"
		echo
		echo "</details>"
		echo
	} >>"$GITHUB_STEP_SUMMARY"
fi
exit $failed
