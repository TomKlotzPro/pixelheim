# Performance: what things cost, and how to measure them

Read before a change that adds work per frame, nodes to a map, lights, or time to CI. Numbers are from the PIX-329 audit (v0.263, 2026-10-21, Apple Silicon, 14 cores, Godot 4.7.1, headless, under load from other agents: trust the ratios more than the milliseconds) unless dated otherwise. Tom wants the game beautiful on a computer first: the desktop frame has room, spend it on lighting, shaders, particles and animation, not on phones or low resolutions.

## Which tools need a window

| Tool | Measures | Window? |
|---|---|---|
| `--screenshot perf` (`PerfProbe`, the perf guard) | physics, process, render per frame | **yes**: headless it prints `-`, the dummy renderer never emits `frame_pre_draw`/`frame_post_draw` |
| `--screenshot crossing` | a walk's frames over a line between maps | **yes**: headless it reports `frames 0` |
| `motion`, `line-motion` | steps back in the hero's walk, by pixels | **yes** (CI's windowed jobs walk them) |
| `lookbook.sh --perf`, `lookbook`, `film` | the GPU side: draws, shaders, lights | **yes** |
| `cpu=` (PIX-355) | each frame timed to the next once the Reach is worked out ahead, ms median/95th percentile; the `cpu-*` flows hold it to budgets with room for CI's runners, headless only and each alone after the rest (`flows.sh`: beside other runs, or a window's software drawing, a CI frame read 4-7x its cost) | no, and never beside other runs |
| `tools/web_perf.py` (PIX-361) | the web export in headless Chrome: `cpu=`, PerfProbe's sample and the crossing's frames, read off the page (`window.pixelheimPerf`) | no (headless Chrome draws) |
| `--screenshot reentry` | entering each outdoor map, first and again; BESIDE lines part by part | no |
| `godot --headless --fixed-fps 60 --print-fps -- --screenshot --map X --wait 240` | CPU per frame (frames run back to back) | no |
| `turning`, `overflow`, `--benchmark` | the turning walk, words off the canvas, boot phases | no |

## The frame (CPU, headless, one core)

| Map | Mobs | Decor | ms per frame |
|---|---|---|---|
| overworld | 30 | 312 | 0.90-0.92 |
| overworld, night | 45 | 312 | 1.03-1.10 |
| deepwood | 12 | 1427 | 0.49-0.55 |
| mirefen | 12 | 294 | 0.49-0.52 |
| seacave (dungeon) | 12 | – | 0.44-0.52 |
| town (day / night) | 0 | 675 | 0.25-0.38 / 0.22 |
| town_inn | 0 | – | 0.20 |

- **Mobs drove the CPU frame**: about 0.25 ms plus 0.021 ms per mob. Since PIX-360 a foe at peace (`Enemy.at_peace`: no boss) more than `REST_MARGIN` (6 cells) past the screen's edge rests, its tick skipped but for its wander's dice until the edge nears (`Enemy.rest`, asked by `Foes._process`): `cpu=` medians on 2026-10-22 went overworld 0.83 -> 0.45, night 0.95 -> 0.47, deepwood 0.48 -> 0.24, the line 0.55 -> 0.27 ms (every flow's report the same), and the `cpu-*` flows hold them under 1.50, 1.00 and 1.00. Decor nodes cost almost nothing per frame once drawn; lights add little CPU.
- **Streaming** (`world_neighbours.gd`) adds up to `BUDGET_MS` 3 ms a frame while the Reach's maps beside are drawn in.
- **The GPU side was not measured headless.** The 2026-10-09 baseline: about 43 draws, physics 0.7 ms on the overworld, about 2 ms of a 16.7 ms desktop frame used.
- **The web build** (single-threaded wasm, Compatibility renderer) downloads 18.7 MB gzipped (wasm 10.25 MB, pck 8.37 MB) before PIX-351 took the tests out (about 1.4 MB less). Its frame is measured below.

## The web build (`tools/web_perf.py`, PIX-361)

The export (CC0 art) served as GitHub Pages serves it and opened in headless Chrome, the harness's command line handed over by the page (`window.pixelheimArgs`, read by `web/shell.html`, never from the URL), and the numbers read back off the page: `harness.gd` sets `window.pixelheimPerf` (map, `cpu`, `frames`, `perf`, the report line) on the web only. Chrome's frame rate is uncapped and the run stepped (`--fixed-fps 60`), so the frames run back to back, as headless on the desktop, but drawn. Two runs, the desktop's `cpu-night` with `perf` and `cpu-line` with `crossing`. On 2026-10-27, the laptop (its GPU), Chrome 156, three runs, ms median/95th percentile:

| Run | Web `cpu=` | Desktop headless `cpu=` (same day) |
|---|---|---|
| the overworld at night, 45 mobs | 2.70-3.10 / 3.20-3.80 | 0.49/0.90 |
| over the line into the Deepwood | 2.70-3.20 / 4.40-6.10 | 0.31/1.14 |

- The night's PerfProbe (averages): physics 0.29-0.36, process 1.08-1.19, render 1.19-1.35 ms; 81 draws, 1068 objects, 1818 nodes. The scripts (physics and process, 1.4-1.6 ms) cost about 3 times the desktop's, as assumed; the browser's drawing about as much again.
- The crossing's walk: 37 frames, the slowest 12.1-13.8 ms (the map beside handed over, streaming's 3 ms a frame): inside a 60 Hz frame, with little to spare there.
- So a web frame costs about 3 ms of 16.7 away from the lines: room to spend, on the web too. A page boots and runs in about 5 s (10 s the first time, the wasm compiled).
- Local only: on CI's GPU-less runners (WebGL drawn by SwiftShader) the page booted but didn't finish a run within 240 s (PR #419), so there is no CI job; run it on a Mac before and after a change that could slow the web build.

Run it on the laptop (Playwright for Python drives the installed Google Chrome; no browser download):

```
godot --headless --audio-driver Dummy --path godot --export-release Web export/web/index.html
python3 -m venv /tmp/pw && /tmp/pw/bin/pip install playwright==1.56.0
/tmp/pw/bin/python godot/tools/web_perf.py --out /tmp/web-perf.json
```

An export with the paid art installed measures that art too: keep its numbers, never the export.

## Entering a map (`reentry`, ms)

| Map | First visit | Again | Drawn beside (BESIDE total) | Nodes | of which decor |
|---|---|---|---|---|---|
| overworld | 150 | 39 | 33 | 1145 | 15.2 |
| deepwood | 89 | 36 | 33 | 2293 | 25.5 |
| frostgate | 70 | 18 | 14 | 548 | 7.2 |
| greyhold | 65 | 20 | 17 | 702 | 7.8 |
| mirefen | 65 | 16 | 13.6 | 475 | 5.7 |
| blackiron | 55 | 14 | 12 | 543 | 6.0 |
| saltmere | 50 | 13 | 10 | 330 | 3.9 |
| town | 32 | 32 | 30 | 1340 | 11.7 |

Decor (one node a piece) is the largest part of drawing a map. A first visit costs 2-4 times a return (`KeptGround` keeps the worked-out ground); the town gains nothing on return. Memory kept after both rounds: +9 MB, kept ground 1.34 MB.

Most of the Deepwood's decor was not its 2142 tree sprites (about 10 ms) but working out its clumps (`Woods.look_at` and `.pieces`, about 25 ms). Since PIX-360 a map's woods are kept for the session (`KeptGround.woods`, cell by cell as they are first drawn). On 2026-10-22, nodes the same, "again" went deepwood 56 -> 26 ms, town 36 -> 26, greyhold 23 -> 17 and frostgate 21 -> 15. BESIDE went deepwood 52.7 -> 23.1 ms, town 34.9 -> 25.0, greyhold 20.1 -> 13.4 and frostgate 17.4 -> 11.6. The cost is +2.7 MB of memory kept after both rounds (+12.7 MB in all).

The town's yards (PIX-382, `Yards`, 2026-10-28, `--town-tier 4`, with the paid pack): nodes 1366 -> 1733, BESIDE 27.2 -> 30.5 ms (plan 8.8 -> 10.2, decor 9.1 -> 10.9), "again" about 30 -> 33.5 ms. The data's villager spots are worked out once a session (`Yards.kept`); the rest is `Hamlet.plan` fitting about 60 standing pieces and a node or four each.

Greyhold's walls in stone (PIX-386, `StoneWalls`, 2026-10-28, with the paid pack, three runs interleaved with main's): nodes 703 -> 704 (the ruins' tile layer), BESIDE 16.5 -> 16.9 ms (plan 3.9 -> 4.5), "again" 19.6 -> 20.5 ms; other maps' plan +0.1-0.2 ms (the scan for walls). The ruins' atlas holds 120 tiles more: about 3 ms more, once a session, on the first map with ruins or walls (the Mirefen's first visit 75 -> 79 ms).

The town's farm animals (PIX-387, 2026-10-28, `--town-tier 4`, with the packs, two runs each): nodes 1734 -> 1759 (24 sprites and the herd), BESIDE 31.0-31.7 -> 32.6-33.2 ms (decor 10.5-11.2 -> 12.0-12.1), "again" 32.8-33.5 -> 33.9-36.3 ms. `cpu=` by the river field with every animal near the screen 0.28/0.60-0.66 -> 0.28-0.30/0.65 ms: noise. With the sty fenced (the review), the same build with and without the pack: nodes 1774 -> 1799, BESIDE 32.6-33.0 -> 33.0-33.3 ms (decor 11.2-11.3 -> 12.1-12.2); without it, nothing of the herd is planned.

The houses the ages raise and the fountain lit at night (PIX-382 step 3, 2026-10-29, with the packs): the City's town nodes 1852 -> 1763 (the woods and the orchard's trees under the new roofs went), BESIDE 32.5-33.8 -> 34.5-34.6 ms (plan 11.3-11.6 -> 12.2-12.6: the yards fit eight pieces more), "again" 34.7-35.3 -> 35.5-36.0 ms, three runs before and two after. The report's `decor=` by age, Ashes to City: 688, 675, 673 -> 652, 672 -> 639, 671 -> 564; lit windows at night (`panes`) 20, 22 -> 24, 25 -> 29, 25 -> 33 from the Hamlet, each with its light, plus the fountain's, within `test_night_light`. `cpu=` on the town at every age by day and at night, two rounds each, headless and alone: 0.20-0.28 / 0.42-0.77 ms before, 0.21-0.30 / 0.40-0.75 after (noise); `cpu-town` holds the City at night under 1.00.

The market, the trades' signs, the planters and the worn paving (PIX-382 step 4, 2026-10-29, with the packs, two runs each, headless and alone): the City's town nodes 1760 -> 1856, BESIDE 33.5-33.6 -> 36.8 ms (plan 12.2-12.5 -> 12.9-13.4, ground 7.4-7.5 -> 8.8-9.0: the worn paving's lanes, decor 11.5-11.8 -> 12.4-13.0), "again" 35.1-35.6 -> 38.0-39.5 ms. `decor=` by age, Ashes to City: 688, 675, 652 the same, the Town's 637 -> 636 and the City's 562 -> 561 (a planter's cell each); lit windows and lamps the same (no light added). `cpu=` on the town at every age by day and at night: 0.21-0.29 / 0.42-0.82 ms before, 0.21-0.29 / 0.41-0.68 after (noise). The review's round (the square worn only where its folk walk, the butcher's and the bookseller's stalls, each stall's awning drawn again over its wares; on a slower day, two runs each): nodes 1856 -> 1878, BESIDE 38.7-41.7 -> 40.4-41.9 ms (decor 13.2-14.6 -> 14.6-15.5), "again" 40.6-42.3 -> 41.6-43.3 ms; `decor=` and the night's lights the same at every age; `cpu=` 0.21-0.32 / 0.46-0.87 ms before, 0.22-0.32 / 0.46-0.92 after (noise).

## Saves (a hero who has seen every cell of 29 maps)

`to_dict` 0.04 ms (4.6 ms the first time, every map packed); `SaveSlots.write` (temp, read back, decode, rename) 0.85 ms; `SaveSlots.read` 0.27 ms; `GameState.apply` 5.6 ms (the fog unpacked, once per load); a `PXH2` code 0.3 ms either way. The file is 8.8 KB, the code 1.3 KB. Nothing to do.

## Boot

A bare `--quit` and the cheapest flow both take 1.7-1.9 s: autoloads 0.37 s, the main scene 0.9 s, and loading the other 173 scripts alone 1.1 s (GDScript compiling). Booting from an exported pack of binary-token scripts was tried and was no faster. So a flow is mostly a boot: about 78% of the headless flow time on CI. Since PIX-360 the look-only flows (77 of 406) and the boot check's 88 boots run ten to a Godot (`--batch`, `verify.md`), a flow after the first about 0.2 s instead of a boot's 2: on the laptop (12 at a time, 2026-10-22) every flow headless went 114.2 -> 101.3 s, the look-only ones alone 20.5 -> 5.6 s and `flows.sh --boot` 23.8 -> 4.6 s. CI's runners, fewer cores at 4.4 s a boot, should save more (about 77 + 88 boots less 17).

## GUT

1538 tests. Locally 33-40 s after PIX-354 (was 43-62 s; `test_fit` opens every screen in its five views side by side, `test_ascension` steps its tweens, `test_ash_land` shares one `KeptGround.of` per map). Time it with `-gjunit_xml_file=<file>`. Never wait real seconds in a test: step the clock or the tweens.

## CI

Three PR runs on 2026-10-21, after PIX-350 split the windowed flows into four shares: **13.1-13.5 min** from the first job's start to the last one's end (the median was 21 min before; Tom's figure is about 11 min).

| Job | Minutes | Its slow steps |
|---|---|---|
| `godot` | 8.4-13.5 | GUT 49-75 s, boot every map 76-119 s, **flows headless 346-584 s** |
| `windowed (1)`-`(4)` | 5.6-11.0 each | flows windowed 311-627 s |
| `windowed (look)` | 4.6 | look book 245-249 s |
| `pictures` | 0.5-0.6 | |

The critical path is now the `godot` job's headless flows beside the slowest windowed share. 405 flows run twice per PR (headless and windowed); a new flow costs about 5 s headless and 15 s windowed on CI.
