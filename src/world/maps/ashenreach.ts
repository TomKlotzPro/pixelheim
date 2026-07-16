import { parseMap } from "../parseMap";
import type { WorldMap } from "../types";

/**
 * The Ashenreach: the overworld. Pixelheim village in the green south,
 * marshland west, forest east, and beyond the river the ash fields climb
 * to the Ashen Mountain. The gate in the mountain face leads to the
 * dungeon floors; the cave at its base descends to the Undermountain
 * (both exit to the hub until PIX-24 wires the floor select).
 */
export const OVERWORLD_MAP: WorldMap = parseMap(
  "overworld",
  `
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^D^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^aaaaaa=aaaaaa^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^Caaaaaaaaaaa=aaaaaaaaaaa^^^^^^^^^^^^
  ^^aaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaa^^aaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaa^
  ^aaaaaa^^aaaaaaaaaaaaaaa=aaaaaaaaaaaaaa^^aaaaaa^
  ^~~~~~~~~~~~~~~~~~~~~~~~b~~~~~~~~~~~~~~~~~~~~~~^
  ^~~~~~~~~~~~~~~~~~~~~~~~b~~~~~~~~~~~~~~~~~~~~~~^
  ^.......................=......................^
  ^.wwwww.................=.........ffff.........^
  ^.wwwww.................=........ffffff........^
  ^.......................*......................^
  ^.......................=......................^
  ^.................######D######................^
  ^.................#rrrrrrrrrrr#................^
  ^.................#rrrrrrrrrrr#................^
  ^.................#rrrrrrrrrrr#................^
  ^.................#rrrrrrrrrrr#................^
  ^.................#rrrrrrrrrrr#................^
  ^.................#############................^
  ^..............................................^
  ^..www..................fffff..................^
  ^..............................................^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  `,
  [
    { x: 24, y: 3, to: { kind: "dungeon", dungeon: "mountain" } },
    { x: 12, y: 5, to: { kind: "dungeon", dungeon: "undermountain" } },
    { x: 24, y: 21, to: { kind: "map", mapId: "town", x: 14, y: 16 } },
  ],
  {
    grid: `
  ------------------------------------------------
  ------------------------------------------------
  ------------------------------------------------
  ------------------------------------------------
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  -AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-
  ------------------------------------------------
  ------------------------------------------------
  ------------------------------------------------
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  -wwwwwwwwwwwwwwww--------------FFFFFFFFFFFFFFFF-
  ------------------------------------------------
  `,
    legend: { A: "ash", w: "marsh", F: "forest" },
  },
);

/**
 * Pixelheim village, expanded: Main Street up top (Odo under his awning, the
 * inn, Hilda's slate-roofed smithy), the violet-roofed alchemist and a mossy
 * old house below, a shrine square in the middle, and an empty lot waiting
 * for the player's house (PIX-33). Every trade hangs its sign by the door;
 * lamps light the square after dark.
 */
export const TOWN_MAP: WorldMap = parseMap(
  "town",
  `
  ########################################
  #..x.................x...........x.....#
  #.333333..rrrrrr...111111...rrrrr.4444.#
  #.333333..rrrrrr...111111...rrrrr.4444.#
  #.3gD333..rmDrrr...1hD111...rrdrr.4d44.#
  #......................................#
  #.........o......c.....................#
  #.....================.................#
  #..L.........=W=........L...nn..nn.....#
  #.....================......oc..co.....#
  #..........O...........................#
  #.22222..........44444.x....rrrrr......#
  #.22222..........44444......rrrrr..x...#
  #.2pD22..........44444......rrdrr......#
  #......................................#
  #.............S.......FF....FFFF.......#
  #...x..................x....ffff..x....#
  ##############D#########################
  `,
  [
    { x: 4, y: 4, to: { kind: "map", mapId: "town_shop", x: 4, y: 4 } },
    { x: 12, y: 4, to: { kind: "map", mapId: "town_inn", x: 4, y: 4 } },
    { x: 21, y: 4, to: { kind: "map", mapId: "town_smith", x: 4, y: 4 } },
    { x: 4, y: 13, to: { kind: "map", mapId: "town_alchemist", x: 4, y: 4 } },
    { x: 14, y: 17, to: { kind: "map", mapId: "overworld", x: 24, y: 20 } },
  ],
);

export const TOWN_SMITH_MAP: WorldMap = parseMap(
  "town_smith",
  `
  ##########
  #ee____AA#
  #________#
  #nn____nn#
  #___$____#
  ####D#####
  `,
  [{ x: 4, y: 5, to: { kind: "map", mapId: "town", x: 21, y: 5 } }],
);

export const TOWN_ALCHEMIST_MAP: WorldMap = parseMap(
  "town_alchemist",
  `
  ##########
  #tt____uu#
  #________#
  #t______t#
  #___$____#
  ####D#####
  `,
  [{ x: 4, y: 5, to: { kind: "map", mapId: "town", x: 4, y: 14 } }],
);

export const TOWN_SHOP_MAP: WorldMap = parseMap(
  "town_shop",
  `
  ##########
  #tt____nn#
  #________#
  #nn______#
  #___$____#
  ####D#####
  `,
  [{ x: 4, y: 5, to: { kind: "map", mapId: "town", x: 4, y: 5 } }],
);

export const TOWN_INN_MAP: WorldMap = parseMap(
  "town_inn",
  `
  ##########
  #BB____HH#
  #________#
  #B_____nn#
  #___$____#
  ####D#####
  `,
  [{ x: 4, y: 5, to: { kind: "map", mapId: "town", x: 12, y: 5 } }],
);
