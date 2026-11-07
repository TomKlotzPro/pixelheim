# The explorer

**Goal:** walk where few players look closely and find what's broken in the world itself. Seams, holes, wrong layering, places the hero walks through or gets stuck on. The bridge-foot glitch in front of the village (fixed in v0.319) is the kind of thing to find.

**Start:** one session per place, each with a level 10 hero standing there, so the wild doesn't kill you while you look. For example `--role warrior --level 10 --map overworld --at 93,33`, or `--map town --at 40,4` for the village gate. Add `--flags night` for the night, or `--flags "--town-tier 0"` for the village in its ashes. Stop each session before starting the next.

**Model:** Sonnet. A seam or a layering fault takes a careful eye on the picture.

## Route

Pick five or six of these and give each about 12 looks:

- **The village and its gate**: the bridge, the river banks, the walls, the gate out to the overworld.
- **The lines between maps**, which you walk over with no door:
  - overworld (93,33), walking right into the Deepwood;
  - overworld (16,58), walking down to the cliff gate and Saltmere;
  - Blackiron (48,29), walking right into the Ash Fields.
  Walk over each line slowly, then back.
- **The Ash Fields' burnt farmsteads**, around overworld (30,20): fences, carts, dead orchards.
- **A river or a lake's whole bank**: walk along it.
- **Doors**: go into each of the village's houses and come back out (the inn, the shop, the smithy, the hall, the alchemist).
- **Stairs down and back up** in a dungeon: the Blackiron shafts, the Greyhold cellars, the ice cave, the sea cave.
- **The edges of a map**: walk to each one.
- **Night**: one place at night (`--flags night`), with its lights.
- **The village in its ashes** (`--map town --flags "--town-tier 0"`), as a new hero first sees it.

## Check

- **Walking.** Does the hero walk through a wall, a house, a tree, a fence or water? Get stuck on nothing? Can they reach a place that looks open, and are they stopped where it looks closed?
- **Layering.** Is the hero drawn in front of something they should stand behind, such as a roof, a treetop or an arch? Or behind something they should be in front of?
- **Seams.** At a line between maps, or where a road, a river or a bank meets grass: a hard line, a jump in colour, a gap, a black band, a tile that repeats in a grid.
- **Doors.** You should arrive facing out, on open ground, not inside a wall. The room should fit the house you went into.
- **The camera.** Does it ever show the void past a map's edge?
- **Decor.** Anything floating, cut in half, popping in late, or standing on a road or in water.
- **Night.** Lights that sit where nothing lights them, or a lamp with no light.

For a seam or a layering fault, take the screenshot from as close as you can, and give the cell.
