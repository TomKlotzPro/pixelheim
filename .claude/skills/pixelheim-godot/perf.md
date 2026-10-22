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
- **The web build** (single-threaded wasm, Compatibility renderer) is unmeasured; on an assumed 2-3x GDScript slowdown the night overworld costs 2-3.5 ms of CPU, plus up to 3 ms while streaming. It downloads 18.7 MB gzipped (wasm 10.25 MB, pck 8.37 MB) before PIX-351 took the tests out (about 1.4 MB less).

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

## Saves (a hero who has seen every cell of 29 maps)

`to_dict` 0.04 ms (4.6 ms the first time, every map packed); `SaveSlots.write` (temp, read back, decode, rename) 0.85 ms; `SaveSlots.read` 0.27 ms; `GameState.apply` 5.6 ms (the fog unpacked, once per load); a `PXH2` code 0.3 ms either way. The file is 8.8 KB, the code 1.3 KB. Nothing to do.

## Boot

A bare `--quit` and the cheapest flow both take 1.7-1.9 s: autoloads 0.37 s, the main scene 0.9 s, and loading the other 173 scripts alone 1.1 s (GDScript compiling). Booting from an exported pack of binary-token scripts was tried and was no faster. So a flow is mostly a boot: about 78% of the headless flow time on CI.

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
