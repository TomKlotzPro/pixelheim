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
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^D^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^=^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^aaaaaaaaaaaa==aaaaaaaaaaaa^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^aaaaaaaaaaaa==aaaaaaaaaaaa^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^Caaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaa^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^aaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaa^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaa^^^^aaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaa^^^^aaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^^
  ^^aaaaaaaaaaaa^^^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaa^^^^aaaaaaaaaaaa^^
  ^^aaaaaaaaaaaa^^^^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa==aaaaaaaaaaaaaaaaaaaaaaaaaaaa^^^^aaaaaaaaaaaa^^
  ^^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  ^^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  ^^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  ^^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  C...............................................==............................................C.
  ^...............................................==............................................^.
  ^^..wwwwwwwwww..................................==..................ffffffff..................^^
  ^^..wwwwwwwwww..................................==..................ffffffff..................^^
  ^^..wwwwwwwwww..................................==................ffffffffffff................^^
  ^^..wwwwwwwwww..................................==................ffffffffffff................^^
  ^^..............................................*.............................................^^
  ^^..............................................=.............................................^^
  ^^..............................................==............................................^^
  ^^..............................................==............................................^^
  ^^..................................############D#############................................^^
  ^^..................................############r#############................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##rrrrrrrrrrrrrrrrrrrrrr##................................^^
  ^^..................................##########################................................^^
  ^^..................................##########################................................^^
  ^^............................................................................................^^
  ^^............................................................................................^^
  ^^....wwwwww....................................ffffffffff....................................^^
  ^^....wwwwww....................................ffffffffff....................................^^
  ^^............................................................................................^^
  ^^............................................................................................^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  `,
  [
    { x: 48, y: 6, to: { kind: "dungeon", dungeon: "mountain" } },
    { x: 24, y: 10, to: { kind: "dungeon", dungeon: "undermountain" } },
    { x: 48, y: 42, to: { kind: "map", mapId: "town", x: 32, y: 2 } },
    { x: 0, y: 32, to: { kind: "map", mapId: "mirefen", x: 56, y: 24 } },
    { x: 94, y: 32, to: { kind: "map", mapId: "deepwood", x: 2, y: 24 } },
  ],
  {
    grid: `
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  --wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww----------------------------FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF--
  ------------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------------
  `,
    legend: { A: "ash", w: "marsh", F: "forest" },
  },
);

/**
 * Pixelheim village, the medieval pass (PIX-114): a dirt road runs from the
 * north gate down into a paved village square held by the shrine, with the
 * old well off its SW corner. Main Street strings together Odo's awninged
 * shop, the big two-story thatched inn, Hilda's slate smithy and two moss
 * cottages; the south lane serves the golden-thatch alchemist, a cottage,
 * a hut, the city hall and the player's house, with a fenced sheep pen,
 * flower meadows and a walled orchard along the southern edge. Every trade
 * hangs its sign by the door. Wheat fields, a winding stream with a pond,
 * and forest creeping past the walls keep the edges from reading square.
 * The gate sits in the NORTH wall so leaving
 * town continues north onto the mountain road - travel direction is
 * preserved through the portal, no held-key ping-pong.
 */
const TOWN_BASE = `
  ################################D###############################################
  ################################=###############################################
  ##...................22222222...=..kkkkkkkk.1111........x.x.x.x.x.x.x.x.x..~~.##
  ##f..rrrrrrr.........222222222..=..kkkkkkkk.1111...........................~~.##
  ##ffrrrrrrrrr.....2222222222222.=......111111111..........44444............~~.##
  ##f.rrrrrrrrr.....2222222222222.=.....1111111111.........4444444....rrrr..~~~.##
  ##f.rrrrrrrrr.....2222222222222.=.....1111111111.........4444444...rrrrrr.~~~.##
  ##.cr3333333r.....2222222222222.=.....1111111111oc.......4444444...rrrrrr.~~~.##
  ##..rrgrDrrrr.....2222m2D222222.=.....11h1D11111.........444d444...rrrdrr.~~~.##
  ##..=====================================================================..~~.##
  ##..=====================================================================..~~.##
  ##...x..=......x........=.....L.=.L.x.................x..........x........~~~.##
  ##......=.xx..xx......=============.......................................~~~.##
  ##f.....=.xx..xx.....====..===..====......................................~~~.##
  ##ff....=....x.......===============......................................~~~.##
  ##f.....=............=====x===x=====.....................................~~~~.##
  ##......=............=======W...====.....................................~~~~.##
  ##......=............========...====.....................................~~~~.##
  ##......=================xx==...====.....................................~~~~.##
  ##....................=============......................................~~~~.##
  ##f...................O.....=............................................~~~~~##
  ##ff2222222.................=............................rrrrrrr.........~~~~~##
  ##ff2222222.................=.....rrrrr.................rrrrrrrrr........~~~~~##
  ##f.2222222.................=.....rrrrr.444.............rrrrrrrrr........~~~~~##
  ##..222222222...............=.....rrrrr.444.............rrrrrrrrr........~~~~~##
  ##..222222222...............=.....rrrrr.444.............rrrrrrrrr.........~~~.##
  ##f.22p2D2222...............=.....rrdrr.4d4.............rrrrdrrrr.........~~~.##
  ##f...=========================================================...........~~~.##
  ##.kkkkkkkkkk...............=...............FFFFF=FFFFFFF...=.............~~~.##
  ##.kkkkkkkkkk...............=...............kkkkkkkkkkkkk.......FFFFF.FFF..~~.##
  ##.kkkkkkkkkk...........x...S....x..........kkkkkkkkkkkkk.........f..f..f..~~.##
  ##...FFFFFFF..........x........x....x.......kkkkkkkkkkkkk........f..f..f...~~.##
  ##...Foo......................ff............kkkkkkkkfkkkk....f..f..f..f..f.~~.##
  ##...FFFFFFF.f.f..f.f..f.f..f.f..f.f..f.f..f.f..f.ff.f.f..f.f.ff...........~~.##
  ################################################################################
  ################################################################################
  `;

/**
 * Stamp a patch onto town rows (PIX-91): space keeps the base character, any
 * other character must land on open grass or flowers - a collision with a
 * building, road or spawn throws at module load, so a bad tier layout fails
 * the suite immediately.
 */
function stamp(rows: string[], at: { x: number; y: number; patch: string[] }): string[] {
  const out = rows.slice();
  at.patch.forEach((line, dy) => {
    const row = out[at.y + dy].split("");
    for (let dx = 0; dx < line.length; dx++) {
      const ch = line[dx];
      if (ch === " ") continue;
      const base = row[at.x + dx];
      if (base !== "." && base !== "x") {
        throw new Error(`town tier stamp collides at ${at.x + dx},${at.y + dy} (over "${base}")`);
      }
      row[at.x + dx] = ch;
    }
    out[at.y + dy] = row.join("");
  });
  return out;
}

const applyStamps = (rows: string[], stamps: { x: number; y: number; patch: string[] }[]) => stamps.reduce(stamp, rows);

/** The city hall stands from the founding: T-shaped, slate, with a lamped forecourt. */
const CITY_HALL_STAMP = [
  { x: 44, y: 21, patch: ["11111111111", "11111111111", "11111111111", "11111111111", "L=1111111=L", "==111D111=="] },
];

/** Tier 2, Village: lamps at the square's corners, market stalls, flower beds. */
const VILLAGE_STAMPS = [
  { x: 21, y: 12, patch: ["L"] },
  { x: 35, y: 12, patch: ["L"] },
  { x: 21, y: 19, patch: ["L"] },
  { x: 35, y: 19, patch: ["L"] },
  { x: 25, y: 13, patch: ["nc"] },
  { x: 30, y: 13, patch: ["no"] },
  { x: 25, y: 18, patch: ["xx"] },
];

/** Tier 3, Town: the fountain beside the shrine, a thatched row-house, lamps on the spawn road. */
const TOWN_STAMPS = [
  { x: 29, y: 16, patch: ["===", "=O=", "==="] },
  { x: 22, y: 21, patch: ["222222", "222222", "22d222"] },
  { x: 21, y: 22, patch: ["L"] },
  { x: 29, y: 22, patch: ["L"] },
];

/** Tier 4, City: a slate townhouse by the player's, a moss farmhouse south, lamplight to the gate. */
const CITY_STAMPS = [
  { x: 67, y: 21, patch: ["111111", "111111", "111111", "111111", "11d111"] },
  { x: 14, y: 29, patch: ["444444", "444444", "444444", "44d444"] },
  { x: 30, y: 2, patch: ["L"] },
  { x: 34, y: 2, patch: ["L"] },
];

const TOWN_PORTALS = [
  { x: 8, y: 8, to: { kind: "map", mapId: "town_shop", x: 8, y: 8 } },
  { x: 24, y: 8, to: { kind: "map", mapId: "town_inn", x: 8, y: 8 } },
  { x: 42, y: 8, to: { kind: "map", mapId: "town_smith", x: 8, y: 8 } },
  { x: 8, y: 26, to: { kind: "map", mapId: "town_alchemist", x: 8, y: 8 } },
  { x: 49, y: 26, to: { kind: "map", mapId: "town_hall", x: 8, y: 8 } },
  { x: 32, y: 0, to: { kind: "map", mapId: "overworld", x: 48, y: 40 } },
] as const;

const TOWN_BASE_ROWS = TOWN_BASE.split("\n")
  .map((row) => row.trim())
  .filter((row) => row.length > 0);

/** The four ages of Pixelheim: Hamlet, Village, Town, City - cumulative redraws. */
const HAMLET_ROWS = applyStamps(TOWN_BASE_ROWS, CITY_HALL_STAMP);
const VILLAGE_ROWS = applyStamps(HAMLET_ROWS, VILLAGE_STAMPS);
const TOWN_ROWS = applyStamps(VILLAGE_ROWS, TOWN_STAMPS);
const CITY_ROWS = applyStamps(TOWN_ROWS, CITY_STAMPS);

export const TOWN_MAPS: WorldMap[] = [HAMLET_ROWS, VILLAGE_ROWS, TOWN_ROWS, CITY_ROWS].map((rows) =>
  parseMap("town", rows.join("\n"), structuredClone(TOWN_PORTALS) as never),
);

/** The founding town; the maps index serves the current tier via its mirror. */
export const TOWN_MAP: WorldMap = TOWN_MAPS[0];

/** The city hall: the ledger across the counter, the mayor behind it. */
export const TOWN_HALL_MAP: WorldMap = parseMap(
  "town_hall",
  `
  ####################
  ####################
  ##t#t_________c#c###
  ##_#_____________###
  ##________________##
  ##________________##
  ##n_n_________n_n###
  ##_______________###
  ##______$_________##
  ##________________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 49, y: 27 } }],
);

export const TOWN_SMITH_MAP: WorldMap = parseMap(
  "town_smith",
  `
  ####################
  ####################
  ##e#e_________A_A###
  ##_#_____________###
  ##________________##
  ##________________##
  ##n#n_________n_n###
  ##_#_____________###
  ##______$_________##
  ##________________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 42, y: 10 } }],
);

export const TOWN_ALCHEMIST_MAP: WorldMap = parseMap(
  "town_alchemist",
  `
  ####################
  ####################
  ##t#t_________u_u###
  ##_#_____________###
  ##________________##
  ##________________##
  ##t_____________t###
  ##_______________###
  ##______$_________##
  ##________________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 8, y: 28 } }],
);

/** The player's house: bought with the deed, entered through the shut door
 * at (30,13) in town (the reducer special-cases it - no portal until owned). */
export const TOWN_HOUSE_MAP: WorldMap = parseMap(
  "town_house",
  `
  ####################
  ####################
  ##B#B_________t_t###
  ##_#____________####
  ##______________H###
  ##_______________###
  ##______n_n_______##
  ##________________##
  ##o_____$_________##
  ###_______________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 60, y: 28 } }],
);

export const TOWN_SHOP_MAP: WorldMap = parseMap(
  "town_shop",
  `
  ####################
  ####################
  ##t#t_________n_n###
  ##_#_____________###
  ##________________##
  ##________________##
  ##n#n_____________##
  ##_#______________##
  ##______$_________##
  ##________________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 8, y: 10 } }],
);

export const TOWN_INN_MAP: WorldMap = parseMap(
  "town_inn",
  `
  ####################
  ####################
  ##B#B_________H_H###
  ##_#_____________###
  ##________________##
  ##________________##
  ##B___________n_n###
  ##_______________###
  ##______$_________##
  ##________________##
  ########D###########
  ####################
  `,
  [{ x: 8, y: 10, to: { kind: "map", mapId: "town", x: 24, y: 10 } }],
);
