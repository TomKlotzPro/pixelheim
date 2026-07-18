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
export const TOWN_MAP: WorldMap = parseMap(
  "town",
  `
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
  `,
  [
    { x: 8, y: 8, to: { kind: "map", mapId: "town_shop", x: 8, y: 8 } },
    { x: 24, y: 8, to: { kind: "map", mapId: "town_inn", x: 8, y: 8 } },
    { x: 42, y: 8, to: { kind: "map", mapId: "town_smith", x: 8, y: 8 } },
    { x: 8, y: 26, to: { kind: "map", mapId: "town_alchemist", x: 8, y: 8 } },
    { x: 32, y: 0, to: { kind: "map", mapId: "overworld", x: 48, y: 40 } },
  ],
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
