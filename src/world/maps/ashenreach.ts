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
 * Pixelheim village, expanded: Main Street up top (Odo under his awning, the
 * inn, Hilda's slate-roofed smithy), the violet-roofed alchemist and a mossy
 * old house below, a shrine square in the middle, and an empty lot waiting
 * for the player's house (PIX-33). Every trade hangs its sign by the door;
 * lamps light the square after dark. The gate sits
 * in the NORTH wall so leaving town continues north onto the mountain road -
 * travel direction is preserved through the portal, no held-key ping-pong.
 */
const TOWN_BASE = `
  ################################D###############################################
  ################################.###############################################
  ##....xx..................................xx......................xx..........##
  ##....xx..................................xx......................xx..........##
  ##..333333333333....rrrrrrrrrrrr......111111111111......rrrrrrrrrr..44444444..##
  ##..333333333333....rrrrrrrrrrrr......111111111111......rrrrrrrrrr..44444444..##
  ##..333333333333....rrrrrrrrrrrr......111111111111......rrrrrrrrrr..44444444..##
  ##..333333333333....rrrrrrrrrrrr......111111111111......rrrrrrrrrr..44444444..##
  ##..33g3D3333333....rrmrDrrrrrrr......11h1D1111111......rrrrdrrrrr..44d44444..##
  ##..33.3.3333333....rr.r.rrrrrrr......11.1.1111111......rrrr.rrrrr..44.44444..##
  ##............................................................................##
  ##............................................................................##
  ##..................o.............c...........................................##
  ##..................=.............=...........................................##
  ##..........================================..................................##
  ##..........================================..................................##
  ##....L...................==W===................L.......n.n.....n.n...........##
  ##........................======..............................................##
  ##..........================================............o.c.....c.o...........##
  ##..........================================..................................##
  ##....................O.......................................................##
  ##............................................................................##
  ##..2222222222....................4444444444..xx........rrrrrrrrrr............##
  ##..2222222222....................4444444444..xx........rrrrrrrrrr............##
  ##..2222222222....................4444444444............rrrrrrrrrr....xx......##
  ##..2222222222....................4444444444............rrrrrrrrrr....xx......##
  ##..22p2D22222....................4444444444............rrrrdrrrrr............##
  ##..22.2.22222....................4444444444............rrrr.rrrrr............##
  ##............................................................................##
  ##............................................................................##
  ##..........................S...............FFFF........FFFFFFFF..............##
  ##..........................................FFFF........FFFFFFFF..............##
  ##......xx....................................xx........ffffffff....xx........##
  ##......xx....................................xx........ffffffff....xx........##
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

/** The city hall stands from the founding: slate-roofed, door on the south street. */
const CITY_HALL_STAMP = [
  {
    x: 45,
    y: 21,
    patch: ["1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111D11111"],
  },
];

/** Tier 2, Village: lamps on the square, market stalls, flower beds. */
const VILLAGE_STAMPS = [
  { x: 16, y: 12, patch: ["L"] },
  { x: 38, y: 12, patch: ["L"] },
  { x: 10, y: 20, patch: ["L"] },
  { x: 38, y: 20, patch: ["L"] },
  { x: 18, y: 16, patch: ["n n", "o c"] },
  { x: 24, y: 20, patch: ["xx"] },
  { x: 36, y: 20, patch: ["xx"] },
];

/** Tier 3, Town: the fountain plaza, a new house, lamps down the south street. */
const TOWN_STAMPS = [
  { x: 28, y: 11, patch: ["=====", "==O==", "====="] },
  { x: 24, y: 21, patch: ["22222222", "22222222", "222d2222"] },
  { x: 22, y: 24, patch: ["L"] },
  { x: 32, y: 24, patch: ["L"] },
];

/** Tier 4, City: paved avenues, two more houses, lamplight to the gate. */
const CITY_STAMPS = [
  { x: 4, y: 12, patch: ["33333333", "33333333", "33333333", "333d3333"] },
  { x: 68, y: 12, patch: ["11111111", "11111111", "11111111", "111d1111"] },
  { x: 30, y: 2, patch: ["L"] },
  { x: 34, y: 2, patch: ["L"] },
  { x: 14, y: 13, patch: ["======"] },
  { x: 33, y: 13, patch: ["="] },
  { x: 8, y: 16, patch: ["=========", "========="] },
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
