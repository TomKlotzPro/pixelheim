import { getMap } from "./maps/index";
import { isWalkable, portalAt } from "./parseMap";

/**
 * Villagers. Wanderers pace a small loop around their home tile; the loop is
 * derived from the player's step counter, so movement is deterministic and
 * needs no stored NPC state.
 */
export type Npc = {
  id: string;
  mapId: string;
  x: number;
  y: number;
  sprite: string;
  name: string;
  lines: string[];
  wander: boolean;
};

export const NPCS: Npc[] = [
  {
    id: "elder",
    mapId: "town",
    x: 32,
    y: 16,
    sprite: "elder",
    name: "Elder Maren",
    wander: false,
    lines: [
      "The mountain burned before you were born. We rebuilt the village; the monsters rebuilt too.",
      "The gate to the Ashen Mountain is north, past the bridge. Ten floors of teeth and worse manners.",
      "And if you beat the dragon... come see me. There are older things below. I hear them some nights.",
    ],
  },
  {
    id: "villager_ana",
    mapId: "town",
    x: 12,
    y: 12,
    sprite: "villager_woman",
    name: "Ana",
    wander: true,
    lines: [
      "The merchant waters down his elixirs, I swear it. Buy the cheese instead.",
      "Stay on the roads if you value your ankles. The tufty grass BITES.",
    ],
  },
  {
    id: "villager_bram",
    mapId: "town",
    x: 36,
    y: 28,
    sprite: "villager",
    name: "Bram",
    wander: true,
    lines: [
      "I saw a wolf take a whole cheese wheel off a traveler once. Rolled it away and everything.",
      "Me? Climb the mountain? I have a perfectly good fence to lean on right here.",
    ],
  },
  {
    id: "shopkeeper",
    mapId: "town_shop",
    x: 8,
    y: 2,
    sprite: "merchant",
    name: "Merchant Odo",
    wander: false,
    lines: ["Welcome, welcome! Finest goods this side of the mountain. The counter is always open."],
  },
  {
    id: "smith",
    mapId: "town_smith",
    x: 8,
    y: 2,
    sprite: "smith",
    name: "Smith Hilda",
    wander: false,
    lines: [
      "The forge takes gold, not promises. Bring me a blade and coin and I will make both sharper.",
      "Seven folds is the most any steel will take. After that it is the arm, not the iron.",
    ],
  },
  {
    id: "alchemist_vex",
    mapId: "town_alchemist",
    x: 8,
    y: 2,
    sprite: "alchemist",
    name: "Alchemist Vex",
    wander: false,
    lines: [
      "Herbs, reeds, shards - I pay full price for reagents. The wilds are a garden if you survive them.",
      "The elixir recipe? One of each, child. Nature likes a balanced potion.",
    ],
  },
  {
    id: "innkeeper",
    mapId: "town_inn",
    x: 8,
    y: 2,
    sprite: "innkeeper",
    name: "Innkeeper Sela",
    wander: false,
    lines: [
      "Ten gold for a bed and no questions. The bards say my stew brought a man back from the brink.",
      "It was the stew or the poultice. Probably the stew.",
    ],
  },
];

/** The pacing loop, clockwise around home. Filtered per NPC to walkable tiles. */
const LOOP: [number, number][] = [
  [0, 0],
  [1, 0],
  [1, 1],
  [0, 1],
];

const validOffsets = new Map<string, [number, number][]>();
for (const npc of NPCS) {
  const map = getMap(npc.mapId);
  const offsets = LOOP.filter(
    ([dx, dy]) => isWalkable(map, npc.x + dx, npc.y + dy) && !portalAt(map, npc.x + dx, npc.y + dy),
  );
  validOffsets.set(npc.id, offsets.length > 0 ? offsets : [[0, 0]]);
}

function idHash(id: string): number {
  let hash = 0;
  for (const char of id) hash = (hash * 31 + char.charCodeAt(0)) % 997;
  return hash;
}

export function npcsOn(mapId: string): Npc[] {
  return NPCS.filter((npc) => npc.mapId === mapId);
}

/** Where the NPC stands right now, given the player's total step count. */
export function npcPosition(npc: Npc, steps: number): { x: number; y: number } {
  if (!npc.wander) return { x: npc.x, y: npc.y };
  const offsets = validOffsets.get(npc.id)!;
  // one pace every four player steps keeps them ambling, not vibrating
  const index = Math.floor((steps + idHash(npc.id)) / 4) % offsets.length;
  const [dx, dy] = offsets[index];
  return { x: npc.x + dx, y: npc.y + dy };
}

export function npcAt(mapId: string, x: number, y: number, steps: number): Npc | null {
  return (
    npcsOn(mapId).find((npc) => {
      const pos = npcPosition(npc, steps);
      return pos.x === x && pos.y === y;
    }) ?? null
  );
}

/** Facing tile first, then the other neighbors: E means "the NPC I obviously mean". */
const BESIDE_ORDER: { facing: "up" | "down" | "left" | "right"; dx: number; dy: number }[] = [
  { facing: "up", dx: 0, dy: -1 },
  { facing: "down", dx: 0, dy: 1 },
  { facing: "left", dx: -1, dy: 0 },
  { facing: "right", dx: 1, dy: 0 },
];

/**
 * The NPC beside the hero: the faced tile wins, any adjacent tile follows.
 * Returns which way the hero should turn, so interacting also faces them.
 */
export function npcBeside(
  mapId: string,
  x: number,
  y: number,
  facing: "up" | "down" | "left" | "right",
  steps: number,
): { npc: Npc; facing: "up" | "down" | "left" | "right" } | null {
  const order = BESIDE_ORDER.toSorted((a, b) => (b.facing === facing ? 1 : 0) - (a.facing === facing ? 1 : 0));
  for (const side of order) {
    const npc = npcAt(mapId, x + side.dx, y + side.dy, steps);
    if (npc) return { npc, facing: side.facing };
  }
  return null;
}
